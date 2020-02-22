{
 /***************************************************************************
                            packagesystem.pas
                            -----------------


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

  Author: Mattias Gaertner

  Abstract:
    The package registration.
}
unit PackageSystem;

{$mode objfpc}{$H+}

interface

{off $DEFINE IDE_MEM_CHECK}

{$DEFINE StopOnRegError}

uses
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  // FPC
  Classes, SysUtils, contnrs, strutils, Laz_AVL_Tree,
  // LCL
  Forms, Controls, Dialogs, LCLProc,
  // LazUtils
  FileUtil, LazFileCache, LazLoggerBase, LazUtilities, LazFileUtils, LazUTF8,
  Laz2_XMLCfg, laz2_XMLRead, LazStringUtils, AvgLvlTree,
  // codetools
  FileProcs, DefineTemplates, CodeToolManager, CodeCache, DirectoryCacher,
  BasicCodeTools, NonPascalCodeTools, SourceChanger,
  // IDEIntf,
  IDEExternToolIntf, IDEDialogs, IDEMsgIntf, CompOptsIntf, LazIDEIntf,
  MacroDefIntf, ProjectIntf, FppkgIntf,
  PackageDependencyIntf, PackageLinkIntf, PackageIntf, LazarusPackageIntf,
  // IDE
  LazarusIDEStrConsts, IDECmdLine, EnvironmentOpts, IDEProcs, LazConf,
  TransferMacros, DialogProcs, IDETranslations, CompilerOptions, PackageLinks,
  PackageDefs, ComponentReg, FppkgHelper;

const
  MakefileCompileVersion = 2;
  // 2 : changed macro format from %() to $()

type
  TFindPackageFlag = (
    fpfSearchInInstalledPckgs,
    fpfSearchInAutoInstallPckgs,
    fpfSearchInPckgsWithEditor,
    fpfSearchInLoadedPkgs,
    fpfSearchInPkgLinks,
    fpfPkgLinkMustExist,  // check if .lpk file exists
    fpfIgnoreVersion
    );
  TFindPackageFlags = set of TFindPackageFlag;
  
const
  fpfSearchEverywhere =
    [fpfSearchInInstalledPckgs,fpfSearchInAutoInstallPckgs,
     fpfSearchInPckgsWithEditor,fpfSearchInPkgLinks,fpfSearchInLoadedPkgs];
  fpfSearchAllExisting = fpfSearchEverywhere+[fpfPkgLinkMustExist];

type
  TPkgUninstallFlag = (
    puifDoNotConfirm,
    puifDoNotBuildIDE
    );
  TPkgVerbosityFlag = (
   pvPkgSearch // write debug messsages what packages are searched and found
   );
  TPkgVerbosityFlags = set of TPkgVerbosityFlag;

  TPkgUninstallFlags = set of TPkgUninstallFlag;

  TPkgAddedEvent = procedure(APackage: TLazPackage) of object;
  TPkgDeleteEvent = procedure(APackage: TLazPackage) of object;
  TPkgUninstall = function(APackage: TLazPackage;
                    Flags: TPkgUninstallFlags; ShowAbort: boolean): TModalResult of object;
  TPkgTranslate = procedure(APackage: TLazPackage) of object;
  TDependencyModifiedEvent = procedure(ADependency: TPkgDependency) of object;
  TPkgGraphEndUpdateEvent = procedure(Sender: TObject; GraphChanged: boolean) of object;
  TFindFPCUnitEvent = procedure(const AUnitName, Directory: string;
                                var Filename: string) of object;
  TPkgDeleteAmbiguousFiles = function(const Filename: string): TModalResult of object;
  TOnBeforeCompilePackages = function(aPkgList: TFPList): TModalResult of object;
  TOnCheckInterPkgFiles = function(IDEObject: TObject; PkgList: TFPList;
    out FilesChanged: boolean): boolean of object;

  { TLazPkgGraphBuildItem }

  TLazPkgGraphBuildItem = class(TComponent)
  private
    FLazPackage: TLazPackage;
    fTools: TFPList; // list of TExternalTools
    function GetTools(Index: integer): TAbstractExternalTool;
    procedure SetLazPackage(AValue: TLazPackage);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation);
      override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function Add(Tool: TAbstractExternalTool): integer;
    function Count: integer; inline;
    function GetDummyTool: TAbstractExternalTool;
    function GetFirstOrDummy: TAbstractExternalTool;
    function GetLastOrDummy: TAbstractExternalTool;
    property Tools[Index: integer]: TAbstractExternalTool read GetTools; default;
    property LazPackage: TLazPackage read FLazPackage write SetLazPackage;
  end;

  TLazPkgGraphExtToolData = class(TIDEExternalToolData)
  public
    Pkg: TLazPackage;
    BuildItem: TLazPkgGraphBuildItem;
    SrcPPUFilename: string;
    CompilerFilename: string;
    CompilerParams: string;
    ErrorMessage: string;
  end;

  TLazPackageGraph = class;

  { TLazPackageGraphFileCachePackageInfo }

  TLazPackageGraphFileCachePackageInfo = record
    FileName: string;
    ChangeStamp: Integer;
  end;

  { TLazPackageGraphFileCache }

  TLazPackageGraphFileCache = class(TObject)
  private
    FGraph: TLazPackageGraph;
    FPackageInfo: array of TLazPackageGraphFileCachePackageInfo;
    FFilesList: TFilenameToPointerTree;
    FRemovedFilesList: TFilenameToPointerTree;
    function NeedsUpdate: Boolean;
    procedure Update;
  public
    constructor Create(AOwner: TLazPackageGraph);
    destructor Destroy; override;
  public
    function FindFileInAllPackages(TheFilename: string;
      IgnoreDeleted, FindVirtualFile: boolean): TPkgFile;
  end;

  { TLazPackageGraph }

  TLazPackageGraph = class(TPackageGraphInterface)
  private
    FAbortRegistration: boolean;
    fChanged: boolean;
    FCodeToolsPackage: TLazPackage;
    FErrorMsg: string;
    FFCLPackage: TLazPackage;
    FIDEIntfPackage: TLazPackage;
    FDebuggerIntfPackage: TLazPackage;
    FLazDebuggerGdbmiPackage: TLazPackage;
    FItems: TFPList;   // unsorted list of TLazPackage
    FLazarusBasePackages: TFPList;
    FLazUtilsPackage: TLazPackage;
    FLCLBasePackage: TLazPackage;
    FLCLPackage: TLazPackage;
    FOnAddPackage: TPkgAddedEvent;
    FOnBeforeCompilePackages: TOnBeforeCompilePackages;
    FOnBeginUpdate: TNotifyEvent;
    FOnChangePackageName: TPkgChangeNameEvent;
    FOnCheckInterPkgFiles: TOnCheckInterPkgFiles;
    FOnDeleteAmbiguousFiles: TPkgDeleteAmbiguousFiles;
    FOnDeletePackage: TPkgDeleteEvent;
    FOnDependencyModified: TDependencyModifiedEvent;
    FOnEndUpdate: TPkgGraphEndUpdateEvent;
    FOnTranslatePackage: TPkgTranslate;
    FOnUninstallPackage: TPkgUninstall;
    FQuietRegistration: boolean;
    FRegistrationFile: TPkgFile;
    FRegistrationPackage: TLazPackage;
    FRegistrationUnitName: string;
    FSynEditPackage: TLazPackage;
    FLazControlsPackage: TLazPackage;
    FTree: TAVLTree; // sorted tree of TLazPackage
    FUpdateLock: integer;
    FLockedChangeStamp: int64;
    FHasCompiledFpmakePackages: Boolean;
    FVerbosity: TPkgVerbosityFlags;
    FFindFileCache: TLazPackageGraphFileCache;
    function CreateDefaultPackage: TLazPackage;
    function GetCount: Integer;
    function GetPackages(Index: integer): TLazPackage;
    procedure DoDependencyChanged(Dependency: TPkgDependency);
    procedure SetRegistrationPackage(const AValue: TLazPackage);
    procedure UpdateBrokenDependenciesToPackage(APackage: TLazPackage);
    function OpenDependencyWithPackageLink(Dependency: TPkgDependency;
                       PkgLink: TPackageLink; ShowAbort: boolean): TModalResult;
    function DeleteAmbiguousFiles(const Filename: string): TModalResult;
    procedure AddMessage(TheUrgency: TMessageLineUrgency; const Msg, Filename: string);
    function OutputDirectoryIsWritable(APackage: TLazPackage; Directory: string;
                                       Verbose: boolean): boolean;
    function GetPackageCompilerParams(APackage: TLazPackage): string;
    function CheckIfCurPkgOutDirNeedsCompile(APackage: TLazPackage;
                    CheckDependencies, SkipDesignTimePackages, GroupCompile: boolean;
                    out NeedBuildAllFlag, ConfigChanged, DependenciesChanged: boolean;
                    var Note: string): TModalResult;
    procedure InvalidateStateFile(APackage: TLazPackage);
    procedure OnExtToolBuildStopped(Sender: TObject);
    procedure PkgModify(Sender: TObject);
  protected
    procedure IncChangeStamp; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Delete(Index: integer);
    function Count: integer; // number of Packages
    procedure BeginUpdate(Change: boolean);
    procedure EndUpdate;
    function Updating: boolean;
    procedure RebuildDefineTemplates;
    function MacroFunctionPkgDir(const s: string; const {%H-}Data: PtrInt;
                                 var {%H-}Abort: boolean): string;
    function MacroFunctionPkgSrcPath(const s: string; const {%H-}Data: PtrInt;
                                     var {%H-}Abort: boolean): string;
    function MacroFunctionPkgUnitPath(const s: string; const {%H-}Data: PtrInt;
                                      var {%H-}Abort: boolean): string;
    function MacroFunctionPkgIncPath(const s: string; const {%H-}Data: PtrInt;
                                     var {%H-}Abort: boolean): string;
    function MacroFunctionPkgName(const s: string; const {%H-}Data: PtrInt;
                                     var {%H-}Abort: boolean): string;
    function MacroFunctionPkgOutDir(const s: string; const {%H-}Data: PtrInt;
                                     var {%H-}Abort: boolean): string;
    function MacroFunctionCTPkgDir(Data: Pointer): boolean;
    function MacroFunctionCTPkgSrcPath(Data: Pointer): boolean;
    function MacroFunctionCTPkgUnitPath(Data: Pointer): boolean;
    function MacroFunctionCTPkgIncPath(Data: Pointer): boolean;
    function MacroFunctionCTPkgName(Data: Pointer): boolean;
    function MacroFunctionCTPkgOutDir(Data: Pointer): boolean;
    function GetPackageFromMacroParameter(const TheID: string;
                                          out APackage: TLazPackage): boolean;
  public
    // searching
    function CheckIfPackageCanBeClosed(APackage: TLazPackage): boolean;
    function CreateUniquePkgName(Prefix: string;
                                 IgnorePackage: TLazPackage): string;
    function CreateUniqueUnitName(const Prefix: string): string;
    function DependencyExists(Dependency: TPkgDependency;
                              Flags: TFindPackageFlags): boolean;
    function FindBrokenDependencyPath(APackage: TLazPackage;
                                      FirstDependency: TPkgDependency): TFPList;
    function FindAllBrokenDependencies(APackage: TLazPackage;
                                       FirstDependency: TPkgDependency): TFPList;
    function FindCycleDependencyPath(APackage: TLazPackage;
                                     FirstDependency: TPkgDependency): TFPList;
    function FindPath(StartPackage: TLazPackage; StartDependency: TPkgDependency;
                      const EndPackageName: string): TFPList;
    function FindPkgOutputInFPCSearchPath(APackage: TLazPackage;
                                      FirstDependency: TPkgDependency): TFPList; // find a package with auto compile and output dir is in FPC default search path
    function FindUnsavedDependencyPath(APackage: TLazPackage;
                                       FirstDependency: TPkgDependency): TFPList;
    function FindNotInstalledRegisterUnits(APackage: TLazPackage;
                                        FirstDependency: TPkgDependency): TFPList;
    function FindAutoInstallDependencyPath(ChildPackage: TLazPackage): TFPList;
    function FindAmbiguousUnits(APackage: TLazPackage;
                                FirstDependency: TPkgDependency;
                                out File1, File2: TPkgFile;
                                out ConflictPkg: TLazPackage): boolean;
    function FindFPCConflictUnit(APackage: TLazPackage;
                                FirstDependency: TPkgDependency;
                                const Directory: string;
                                OnFindFPCUnit: TFindFPCUnitEvent;
                                var File1: TPkgFile;
                                var ConflictPkg: TLazPackage): boolean;
    function FindFileInAllPackages(const TheFilename: string;
                                IgnoreDeleted, FindVirtualFile: boolean): TPkgFile;
    procedure FindPossibleOwnersOfUnit(const TheFilename: string;
                                       OwnerList: TFPList);
    function FindLowestPkgNodeByName(const PkgName: string): TAVLTreeNode;
    function FindNextSameName(ANode: TAVLTreeNode): TAVLTreeNode;
    function FindNodeOfDependency(Dependency: TPkgDependency;
                                  Flags: TFindPackageFlags): TAVLTreeNode;
    function FindOpenPackage(Dependency: TPkgDependency;
                             Flags: TFindPackageFlags): TLazPackage;
    function FindPackageWithName(const PkgName: string;
                                 IgnorePackage: TLazPackage): TLazPackage;
    function FindPackageWithFilename(const TheFilename: string): TLazPackage;
    function FindPackageWithID(PkgID: TLazPackageID): TLazPackage;
    function FindPackageWithIDMask(PkgIDMask: TLazPackageID): TLazPackage;
    function FindPackageProvidingName(FirstDependency: TPkgDependency;
                 const Name: string): TLazPackage;
    function FindDependencyRecursively(FirstDependency: TPkgDependency;
                                       PkgID: TLazPackageID): TPkgDependency;
    function FindDependencyRecursively(FirstDependency: TPkgDependency;
                                       const PkgName: string): TPkgDependency;
    function FindConflictRecursively(FirstDependency: TPkgDependency;
                                     PkgID: TLazPackageID): TPkgDependency;
    function FindRuntimePkgOnlyRecursively(FirstDependency: TPkgDependency
                                           ): TPkgDependency;
    function FindUnit(StartPackage: TLazPackage; const TheUnitName: string;
                      WithRequiredPackages, IgnoreDeleted: boolean): TPkgFile;
    function FindUnitInAllPackages(const TheUnitName: string;
                                   IgnoreDeleted: boolean): TPkgFile;
    function FindUnitInInstalledPackages(const TheUnitName: string;
                                   IgnoreDeleted: boolean): TPkgFile;
    function GetMapSourceDirectoryToPackage(IgnorePackage: TLazPackage = nil): TFilenameToPointerTree;
    function EstimateCompileLoad(APackage: TLazPackage): int64;
    function PackageCanBeReplaced(OldPackage, NewPackage: TLazPackage): boolean;
    function PackageIsNeeded(APackage: TLazPackage): boolean;
    function PackageNameExists(const PkgName: string;
                               IgnorePackage: TLazPackage): boolean;
    procedure GetConnectionsTree(FirstDependency: TPkgDependency;
                                 var PkgList: TFPList; var Tree: TPkgPairTree);
    function GetBrokenDependenciesWhenChangingPkgID(APackage: TLazPackage;
                         const NewName: string; NewVersion: TPkgVersion): TFPList;
    procedure GetPackagesChangedOnDisk(out ListOfPackages: TStringList; IgnoreModifiedFlag: boolean = False); // returns list of new filename and TLazPackage
    procedure GetAllRequiredPackages(APackage: TLazPackage; // if not nil then ignore FirstDependency and do not add APackage to Result
                                     FirstDependency: TPkgDependency;
                                     out List, FPMakeList: TFPList;
                                     Flags: TPkgIntfRequiredFlags = [];
                                     MinPolicy: TPackageUpdatePolicy = low(TPackageUpdatePolicy)
                                     ); overload; // for single search use FindDependencyRecursively
    procedure GetAllRequiredPackages(APackage: TLazPackage; // if not nil then ignore FirstDependency and do not add APackage to Result
                                     FirstDependency: TPkgDependency;
                                     out List: TFPList;
                                     Flags: TPkgIntfRequiredFlags = [];
                                     MinPolicy: TPackageUpdatePolicy = low(TPackageUpdatePolicy)
                                     ); overload;
    procedure SortDependencyListTopologicallyOld(
                   var FirstDependency: TPkgDependency; TopLevelFirst: boolean);
    procedure IterateAllComponentClasses(Event: TIterateComponentClassesEvent);
    procedure IterateComponentClasses(APackage: TLazPackage;
                               Event: TIterateComponentClassesEvent;
                               WithUsedPackages, WithRequiredPackages: boolean);
    procedure IteratePackages(Flags: TFindPackageFlags;
                              Event: TIteratePackagesEvent);
    procedure IteratePackagesSorted(Flags: TFindPackageFlags;
                                    Event: TIteratePackagesEvent);
    procedure MarkAllPackagesAsNotVisited;
    procedure MarkAllDependencies(MarkPackages: boolean;
                            AddMarkerFlags, RemoveMarkerFlags: TPkgMarkerFlags);
    procedure MarkAllRequiredPackages(FirstDependency: TPkgDependency);
    procedure MarkNeededPackages;
    procedure ConsistencyCheck;
  public
    // packages handling
    function CreateNewPackage(const Prefix: string): TLazPackage;
    procedure AddPackage(APackage: TLazPackage);
    procedure ReplacePackage(var OldPackage: TLazPackage; NewPackage: TLazPackage);
    procedure ClosePackage(APackage: TLazPackage);
    procedure CloseUnneededPackages;
    procedure ChangePackageID(APackage: TLazPackage;
                              const NewName: string; NewVersion: TPkgVersion;
                              RenameDependencies, RenameMacros: boolean);
    function SavePackageCompiledState(APackage: TLazPackage;
                  const CompilerFilename, CompilerParams: string;
                  Complete, MainPPUExists, ShowAbort: boolean): TModalResult;
    function LoadPackageCompiledState(APackage: TLazPackage;
                                IgnoreErrors, ShowAbort: boolean): TModalResult;
    procedure SetFlagDependenciesNeedBuild(Pkg: TLazPackage);
    function CheckCompileNeedDueToFPCUnits(TheOwner: TObject;
                          StateFileAge: longint; var Note: string): boolean;
    function CheckCompileNeedDueToDependencies(TheOwner: TObject;
                         FirstDependency: TPkgDependency;
                         SkipDesignTimePackages: boolean; StateFileAge: longint;
                         var Note: string): TModalResult;
    function CheckIfPackageNeedsCompilation(APackage: TLazPackage;
                    SkipDesignTimePackages, GroupCompile: boolean;
                    out NeedBuildAllFlag: boolean; var Note: string): TModalResult;
    function PreparePackageOutputDirectory(APackage: TLazPackage;
                                           CleanUp: boolean): TModalResult;
    function GetFallbackOutputDir(APackage: TLazPackage): string;
    function CheckAmbiguousPackageUnits(APackage: TLazPackage): TModalResult;
    function SavePackageMainSource(APackage: TLazPackage;
                     {%H-}Flags: TPkgCompileFlags; ShowAbort: boolean): TModalResult;
    function CompileRequiredPackages(APackage: TLazPackage;
                                FirstDependency: TPkgDependency;
                                SkipDesignTimePackages: boolean;
                                Policy: TPackageUpdatePolicy): TModalResult;
    function CompilePackage(APackage: TLazPackage; Flags: TPkgCompileFlags;
                            ShowAbort: boolean;
                            BuildItem: TLazPkgGraphBuildItem = nil): TModalResult;
    function CompilePackageUsingFPMake(APackageName: string; Flags: TPkgCompileFlags;
                                       ShowAbort: boolean;
                                       BuildItem: TLazPkgGraphBuildItem = nil): TModalResult;
    function ConvertPackageRSTFiles(APackage: TLazPackage): TModalResult;
    function WriteMakefileCompiled(APackage: TLazPackage;
      TargetCompiledFile, UnitPath, IncPath, OtherOptions: string): TModalResult;
    function WriteMakeFile(APackage: TLazPackage): TModalResult;
    function WriteFpmake(APackage: TLazPackage): TModalResult;
  public
    // installed packages
    FirstAutoInstallDependency: TPkgDependency;
    procedure LoadStaticBasePackages;
    procedure LoadAutoInstallPackages(PkgList: TStringList);
    procedure SortAutoInstallDependencies;
    function GetIDEInstallPackageOptions(
                 var InheritedOptionStrings: TInheritedCompOptsStrings): string;
    function SaveAutoInstallConfig: TModalResult;// for the uses section
    function IsStaticBasePackage(PackageName: string): boolean;
    procedure FreeAutoInstallDependencies;
  public
    // registration
    procedure RegisterUnitHandler(const TheUnitName: string;
                                  RegisterProc: TRegisterProc);
    procedure RegisterComponentsHandler(const Page: string;
                                    ComponentClasses: array of TComponentClass);
    procedure RegistrationError(const Msg: string);
    procedure RegisterStaticBasePackages;
    procedure RegisterStaticPackage(APackage: TLazPackage;
                                    RegisterProc: TRegisterProc);
    procedure CallRegisterProc(RegisterProc: TRegisterProc);
  public
    // dependency handling
    procedure AddDependencyToPackage(APackage: TLazPackage;
                                     Dependency: TPkgDependency);
    procedure AddDependencyToPackage(APackage, RequiredPackage: TLazPackage);
    procedure RemoveDependencyFromPackage(APackage: TLazPackage;
                         Dependency: TPkgDependency; AddToRemovedList: boolean);
    //procedure ChangeDependency(Dependency, NewDependency: TPkgDependency);
    function OpenDependency(Dependency: TPkgDependency;
                            ShowAbort: boolean): TLoadPackageResult;
    function FindAlternativeLPK(APackage: TLazPackage): string;
    procedure OpenInstalledDependency(Dependency: TPkgDependency;
                          InstallType: TPackageInstallType; var Quiet: boolean);
    procedure OpenRequiredDependencyList(FirstDependency: TPkgDependency);
    procedure MoveRequiredDependencyUp(ADependency: TPkgDependency);
    procedure MoveRequiredDependencyDown(ADependency: TPkgDependency);
  public
    // properties
    property AbortRegistration: boolean read FAbortRegistration
                                        write FAbortRegistration;
    property QuietRegistration: boolean read FQuietRegistration
                                        write FQuietRegistration;
    property ErrorMsg: string read FErrorMsg write FErrorMsg;
    property Packages[Index: integer]: TLazPackage read GetPackages; default; // see Count for the number
    property UpdateLock: integer read FUpdateLock;
    property Verbosity: TPkgVerbosityFlags read FVerbosity write FVerbosity;

    // base packages
    property FCLPackage: TLazPackage read FFCLPackage;
    property LCLBasePackage: TLazPackage read FLCLBasePackage;
    property LCLPackage: TLazPackage read FLCLPackage;
    property SynEditPackage: TLazPackage read FSynEditPackage;
    property LazControlsPackage: TLazPackage read FLazControlsPackage;
    property LazUtilsPackage: TLazPackage read FLazUtilsPackage;
    property CodeToolsPackage: TLazPackage read FCodeToolsPackage;
    property IDEIntfPackage: TLazPackage read FIDEIntfPackage;
    property DebuggerIntfPackage: TLazPackage read FDebuggerIntfPackage;
    property LazDebuggerGdbmiPackage: TLazPackage read FLazDebuggerGdbmiPackage;
    property LazarusBasePackages: TFPList read FLazarusBasePackages;

    // events
    property OnAddPackage: TPkgAddedEvent read FOnAddPackage write FOnAddPackage;
    property OnBeginUpdate: TNotifyEvent read FOnBeginUpdate write FOnBeginUpdate;
    property OnChangePackageName: TPkgChangeNameEvent read FOnChangePackageName
                                                     write FOnChangePackageName;
    property OnCheckInterPkgFiles: TOnCheckInterPkgFiles
                         read FOnCheckInterPkgFiles write FOnCheckInterPkgFiles;
    property OnDependencyModified: TDependencyModifiedEvent
                         read FOnDependencyModified write FOnDependencyModified;
    property OnDeletePackage: TPkgDeleteEvent read FOnDeletePackage
                                              write FOnDeletePackage;
    property OnEndUpdate: TPkgGraphEndUpdateEvent read FOnEndUpdate write FOnEndUpdate;
    property OnDeleteAmbiguousFiles: TPkgDeleteAmbiguousFiles
                     read FOnDeleteAmbiguousFiles write FOnDeleteAmbiguousFiles;
    property OnTranslatePackage: TPkgTranslate read FOnTranslatePackage
                                                   write FOnTranslatePackage;
    property OnUninstallPackage: TPkgUninstall read FOnUninstallPackage
                                               write FOnUninstallPackage;
    property OnBeforeCompilePackages: TOnBeforeCompilePackages read
                        FOnBeforeCompilePackages write FOnBeforeCompilePackages;

    // set during calling Register procedures
    property RegistrationFile: TPkgFile read FRegistrationFile;
    property RegistrationPackage: TLazPackage read FRegistrationPackage
                                              write SetRegistrationPackage;
    property RegistrationUnitName: string read FRegistrationUnitName;
  end;
  
var
  PackageGraph: TLazPackageGraph = nil;

function ExtractFPCParamsForBuildAll(const CompParams: string): string;
function ExtractMakefileCompiledParams(const CompParams: string;
  CreateReduced: boolean = false;
  BaseDir: string = ''; MakeRelative: boolean = false): TStringList;
function RemoveFPCVerbosityParams(const CompParams: string): string;
procedure WarnSuspiciousCompilerOptions(ViewCaption, Target, CompilerParams: string);

implementation

procedure RegisterComponentsGlobalHandler(const Page: string;
  ComponentClasses: array of TComponentClass);
begin
  PackageGraph.RegisterComponentsHandler(Page,ComponentClasses);
end;

procedure RegisterNoIconGlobalHandler(ComponentClasses: array of TComponentClass);
begin
  PackageGraph.RegisterComponentsHandler('',ComponentClasses);
end;

function ExtractFPCParamsForBuildAll(const CompParams: string): string;
{ Some compiler flags require a clean build -B, because the compiler
  does not recompile/update some ppu itself.
  Remove all flags that do not require build all:
  -l  logo
  -F  file name and paths
  -B  build all
  -e  executable
  -i  information
  -o  name of the executable
  -s  quick build option, do not call assembler and linker
  -T  target OS
  -v  verbosity
  -X  Executable
  -k  linker flags
  }
var
  EndPos: Integer;
  StartPos: integer;
begin
  Result:=CompParams;
  EndPos:=1;
  while ReadNextFPCParameter(Result,EndPos,StartPos) do begin
    if (Result[StartPos]='-') and (StartPos<length(Result)) then begin
      case Result[StartPos+1] of
      'l','F','B','e','i','o','s','T','v','X','k':
        begin
          while (StartPos>1) and (Result[StartPos-1] in [' ',#9]) do
            dec(StartPos);
          //DebugLn(['ExtractFPCParamsForBuildAll Removing: ',copy(Result,StartPos,EndPos-StartPos)]);
          System.Delete(Result,StartPos,EndPos-StartPos);
          EndPos:=StartPos;
        end;
      end;
    end;
  end;
  Result:=UTF8Trim(Result,[]);
end;

function ExtractMakefileCompiledParams(const CompParams: string;
  CreateReduced: boolean; BaseDir: string; MakeRelative: boolean): TStringList;
var
  AllPaths: TStringList;
  EndPos: Integer;
  StartPos: integer;
  Path: String;
  Reduced: String;
  i: Integer;

  procedure AddSearchPath(Typ: string);
  begin
    AllPaths.Values[Typ]:=MergeSearchPaths(AllPaths.Values[Typ],Path);
  end;

  procedure DeleteOption;
  begin
    while (EndPos<=length(Reduced)) and (Reduced[EndPos] in [' ',#9]) do
      inc(EndPos);
    //debugln(['DeleteOption "',copy(Reduced,StartPos,EndPos-StartPos),'"']);
    System.Delete(Reduced,StartPos,EndPos-StartPos);
    EndPos:=StartPos;
  end;

begin
  Result:=TStringList.Create;
  Reduced:='';
  AllPaths:=Result;
  EndPos:=1;
  while ReadNextFPCParameter(CompParams,EndPos,StartPos) do begin
    if (CompParams[StartPos]='-') and (StartPos<length(CompParams)) then begin
      case CompParams[StartPos+1] of
      'F':
        // search paths
        if StartPos<length(CompParams)-1 then begin
          Path:=copy(CompParams,StartPos+3,EndPos-StartPos-3);
          if (Path<>'') and (Path[1] in ['''','"']) then
            Path:=AnsiDequotedStr(Path,Path[1]);
          case CompParams[StartPos+2] of
          'u': begin AddSearchPath('UnitPath'); continue; end;
          'U': begin AllPaths.Values['UnitOutputDir']:=Path; continue; end;
          'i': begin AddSearchPath('IncPath'); continue; end;
          'o': begin AddSearchPath('ObjectPath'); continue; end;
          'l': begin AddSearchPath('LibPath'); continue; end;
          end;
        end;
      'v':
        // verbosity
        continue;
      'i','l':
        // information
        continue;
      'B':
        // build clean
        continue;
      'C':
        if (StartPos+2<=length(CompParams)) and (CompParams[StartPos+2]='g')
        and TargetNeedsFPCOptionCG(GetCompiledTargetOS,GetCompiledTargetCPU)
        then begin
          // the -Cg parameter is added automatically on Linux, but not in the
          // Makefile.compiled, because that is platform independent.
          // -> ignore
          continue;
        end;
      end;
    end;
    if Reduced<>'' then
      Reduced+=' ';
    Reduced+=copy(CompParams,StartPos,EndPos-StartPos);
  end;
  if BaseDir<>'' then begin
    for i:=0 to AllPaths.Count-1 do begin
      Path:=AllPaths.ValueFromIndex[i];
      if MakeRelative then
        AllPaths[i]:=AllPaths.Names[i]+'='+CreateRelativeSearchPath(Path,BaseDir)
      else
        AllPaths[i]:=AllPaths.Names[i]+'='+CreateAbsoluteSearchPath(Path,BaseDir);
    end;
  end;
  if CreateReduced then
    AllPaths.Values['Reduced']:=UTF8Trim(Reduced,[]);
end;

function RemoveFPCVerbosityParams(const CompParams: string): string;
{ Some compiler flags have no impact on the produced files.
  Remove all flags that do not require a rebuild:
  -l -B -i -v }
var
  EndPos: Integer;
  StartPos: integer;
begin
  Result:=CompParams;
  EndPos:=1;
  while ReadNextFPCParameter(Result,EndPos,StartPos) do begin
    if (Result[StartPos]='-') and (StartPos<length(Result)) then begin
      case Result[StartPos+1] of
      'l','B','i','v':
        begin
          while (StartPos>1) and (Result[StartPos-1] in [' ',#9]) do
            dec(StartPos);
          //DebugLn(['ExtractFPCVerbosityParams Removing: ',copy(Result,StartPos,EndPos-StartPos)]);
          System.Delete(Result,StartPos,EndPos-StartPos);
          EndPos:=StartPos;
        end;
      end;
    end;
  end;
  Result:=UTF8Trim(Result,[]);
end;

procedure WarnSuspiciousCompilerOptions(ViewCaption, Target,
  CompilerParams: string);
var
  ParsedParams: TObjectList;
  i: Integer;
  Param: TFPCParamValue;
  Msg: String;
begin
  if IDEMessagesWindow=nil then exit;
  ParsedParams:=TObjectList.Create(true);
  try
    ParseFPCParameters(CompilerParams,ParsedParams);
    for i:=0 to ParsedParams.Count-1 do begin
      Param:=TFPCParamValue(ParsedParams[i]);
      if fpfValueChanged in Param.Flags then begin
        Msg:='';
        if Param.Kind in [fpkBoolean,fpkValue] then
          Msg:=Format(lisPassingCompilerOptionTwiceWithDifferentValues, [Param.
            Name])
        else if Param.Kind=fpkDefine then
          Msg:=Format(lisPassingCompilerDefineTwiceWithDifferentValues, [Param.
            Name]);
        if Msg='' then continue;
        if Target<>'' then Msg:=Target+' '+Msg;
        IDEMessagesWindow.AddCustomMessage(mluNote,Msg,'',0,0,ViewCaption);
      end;
    end;
  finally
    ParsedParams.Free;
  end;
end;

{ TLazPackageGraphFileCache }

constructor TLazPackageGraphFileCache.Create(AOwner: TLazPackageGraph);
begin
  inherited Create;

  FGraph := AOwner;
  SetLength(FPackageInfo, 0);
  FFilesList := TFilenameToPointerTree.Create(true);
  FRemovedFilesList := TFilenameToPointerTree.Create(true);
end;

destructor TLazPackageGraphFileCache.Destroy;
begin
  SetLength(FPackageInfo, 0);
  FreeAndNil(FFilesList);
  FreeAndNil(FRemovedFilesList);

  inherited Destroy;
end;

function TLazPackageGraphFileCache.FindFileInAllPackages(
  TheFilename: string; IgnoreDeleted, FindVirtualFile: boolean): TPkgFile;

  procedure FindFileInStrList(const Files: TFilenameToPointerTree);
  begin
    Result:=TPkgFile(Files[TheFilename]);
    if (Result<>nil) and (not FindVirtualFile)
    and (not FilenameIsAbsolute(Result.Filename)) then
      Result := nil;
  end;

begin
  Result:=nil;

  if NeedsUpdate then
    Update;

  FindFileInStrList(FFilesList);
  if Result<>nil then Exit;
  if not IgnoreDeleted then
    FindFileInStrList(FRemovedFilesList);
end;

function TLazPackageGraphFileCache.NeedsUpdate: Boolean;
var
  I: Integer;
begin
  if FGraph.Count <> Length(FPackageInfo) then
    Exit(True);

  for I := 0 to FGraph.Count-1 do
    if (FPackageInfo[I].ChangeStamp <> FGraph[I].ChangeStamp)
      or (FPackageInfo[I].FileName<>FGraph[I].Filename)
    then
      Exit(True);

  Result := False;
end;

procedure TLazPackageGraphFileCache.Update;
var
  I, L: Integer;
  xPck: TLazPackage;
begin
  SetLength(FPackageInfo, FGraph.Count);
  FFilesList.Clear;
  FRemovedFilesList.Clear;
  for I := 0 to FGraph.Count-1 do
  begin
    xPck := FGraph[I];
    FPackageInfo[I].ChangeStamp := xPck.ChangeStamp;
    FPackageInfo[I].FileName := xPck.Filename;

    for L := 0 to xPck.FileCount-1 do
    begin
      FFilesList[xPck.Files[L].GetFullFilename]:=xPck.Files[L];
      FFilesList[xPck.Files[L].Filename]:=xPck.Files[L];
    end;
    for L := 0 to xPck.RemovedFilesCount-1 do
    begin
      FRemovedFilesList[xPck.RemovedFiles[L].GetFullFilename]:=xPck.RemovedFiles[L];
      FRemovedFilesList[xPck.RemovedFiles[L].Filename]:=xPck.RemovedFiles[L];
    end;
  end;
end;

{ TLazPkgGraphBuildItem }

// inline
function TLazPkgGraphBuildItem.Count: integer;
begin
  Result:=fTools.Count;
end;

function TLazPkgGraphBuildItem.GetDummyTool: TAbstractExternalTool;
begin
  Result:=ExternalToolList.AddDummy('Dummy tool for building package '+LazPackage.Name);
  Add(Result);
end;

function TLazPkgGraphBuildItem.GetFirstOrDummy: TAbstractExternalTool;
begin
  if Count>0 then
    Result:=TAbstractExternalTool(fTools[0])
  else
    Result:=GetDummyTool;
end;

function TLazPkgGraphBuildItem.GetLastOrDummy: TAbstractExternalTool;
begin
  if Count>0 then
    Result:=TAbstractExternalTool(fTools[Count-1])
  else
    Result:=GetDummyTool;
end;

function TLazPkgGraphBuildItem.GetTools(Index: integer): TAbstractExternalTool;
begin
  Result:=TAbstractExternalTool(fTools[Index]);
end;

procedure TLazPkgGraphBuildItem.SetLazPackage(AValue: TLazPackage);
begin
  if FLazPackage=AValue then Exit;
  if FLazPackage<>nil then
    FLazPackage.RemoveFreeNotification(Self);
  FLazPackage:=AValue;
  if FLazPackage<>nil then
    FLazPackage.FreeNotification(Self);
end;

procedure TLazPkgGraphBuildItem.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    if LazPackage=AComponent then
      LazPackage:=nil;
  end;
end;

constructor TLazPkgGraphBuildItem.Create(AOwner: TComponent);
begin
  inherited;
  fTools:=TFPList.Create;
end;

destructor TLazPkgGraphBuildItem.Destroy;
begin
  Clear;
  FreeAndNil(fTools);
  inherited Destroy;
end;

procedure TLazPkgGraphBuildItem.Clear;
var
  i: Integer;
  Tool: TAbstractExternalTool;
begin
  {$IFDEF VerboseCheckInterPkgFiles}
  debugln(['TLazPkgGraphBuildItem.Clear ',LazPackage.IDAsString]);
  {$ENDIF}
  for i:=Count-1 downto 0 do begin
    Tool:=Tools[i];
    if Tool.Data is TLazPkgGraphExtToolData then
      TLazPkgGraphExtToolData(Tool.Data).BuildItem:=nil;
    Tool.Release(Self);
  end;
  fTools.Clear;
end;

function TLazPkgGraphBuildItem.Add(Tool: TAbstractExternalTool): integer;
begin
  if Tool=nil then exit(-1);
  Tool.Reference(Self,'TLazPkgGraphBuildItem.Add');
  if Tool.Data is TLazPkgGraphExtToolData then
    TLazPkgGraphExtToolData(Tool.Data).BuildItem:=Self;
  Result:=fTools.Add(Tool);
end;

{ TLazPackageGraph }

procedure TLazPackageGraph.DoDependencyChanged(Dependency: TPkgDependency);
begin
  fChanged:=true;
  if Assigned(OnDependencyModified) then OnDependencyModified(Dependency);
end;

function TLazPackageGraph.GetPackages(Index: integer): TLazPackage;
begin
  Result:=TLazPackage(FItems[Index]);
end;

procedure TLazPackageGraph.SetRegistrationPackage(const AValue: TLazPackage);
begin
  if FRegistrationPackage=AValue then exit;
  FRegistrationPackage:=AValue;
  AbortRegistration:=false;
  LazarusPackageIntf.RegisterUnitProc:=@RegisterUnitHandler;
  RegisterComponentsProc:=@RegisterComponentsGlobalHandler;
  RegisterNoIconProc:=@RegisterNoIconGlobalHandler;
end;

procedure TLazPackageGraph.UpdateBrokenDependenciesToPackage(
  APackage: TLazPackage);
var
  ANode: TAVLTreeNode;
  Dependency: TPkgDependency;
begin
  BeginUpdate(false);
  ANode:=FindLowestPkgDependencyNodeWithName(APackage.Name);
  while ANode<>nil do begin
    Dependency:=TPkgDependency(ANode.Data);
    if (Dependency.LoadPackageResult<>lprSuccess)
    and Dependency.IsCompatible(APackage) then begin
      Dependency.LoadPackageResult:=lprUndefined;
      OpenDependency(Dependency,false);
    end;
    ANode:=FindNextPkgDependencyNodeWithSameName(ANode);
  end;
  EndUpdate;
end;

function TLazPackageGraph.OpenDependencyWithPackageLink(
  Dependency: TPkgDependency; PkgLink: TPackageLink; ShowAbort: boolean
  ): TModalResult;
var
  AFilename: String;
  NewPackage: TLazPackage;
  XMLConfig: TXMLConfig;
  Code: TCodeBuffer;
  OldPackage: TLazPackage;
begin
  NewPackage:=nil;
  XMLConfig:=nil;
  BeginUpdate(false);
  try
    AFilename:=PkgLink.GetEffectiveFilename;
    if pvPkgSearch in Verbosity then
      debugln(['Info: (lazarus) Open dependency: trying "'+Dependency.PackageName+'" in '+dbgs(PkgLink.Origin)+' links: "'+PkgLink.GetEffectiveFilename+'" ...']);
    //debugln(['TLazPackageGraph.OpenDependencyWithPackageLink AFilename=',AFilename,' ',PkgLink.Origin=ploGlobal]);
    if not FileExistsUTF8(AFilename) then begin
      DebugLn('Note: (lazarus) Invalid Package Link: file "'+AFilename+'" does not exist.');
      PkgLink.LPKFileDateValid:=false;
      exit(mrCancel);
    end;
    if DirectoryExistsUTF8(AFilename) then begin
      DebugLn('Note: (lazarus) Invalid Package Link: file "'+AFilename+'" is a directory.');
      PkgLink.LPKFileDateValid:=false;
      exit(mrCancel);
    end;
    if pvPkgSearch in Verbosity then
      debugln(['Info: (lazarus) Open dependency: package file found: "'+AFilename+'". Parsing lpk ...']);
    try
      PkgLink.LPKFileDate:=FileDateToDateTimeDef(FileAgeUTF8(AFilename));
      PkgLink.LPKFileDateValid:=true;
      XMLConfig:=TXMLConfig.Create(nil);
      NewPackage:=TLazPackage.Create;
      NewPackage.Filename:=AFilename;
      NewPackage.OnModifySilently := @PkgModify;
      Result:=LoadXMLConfigFromCodeBuffer(AFilename,XMLConfig,
                         Code,[lbfUpdateFromDisk,lbfRevert],ShowAbort);
      if Result<>mrOk then exit;
      NewPackage.LoadFromXMLConfig(XMLConfig,'Package/');
      NewPackage.LPKSource:=Code;
    except
      on E: Exception do begin
        DebugLn('Error: (lazarus) unable to read file "'+AFilename+'" ',E.Message);
        exit(mrCancel);
      end;
    end;
    if not NewPackage.IsMakingSense then begin
      DebugLn('Error: (lazarus) invalid package file "'+AFilename+'".');
      exit(mrCancel);
    end;
    if SysUtils.CompareText(PkgLink.Name,NewPackage.Name)<>0 then begin
      DebugLn('Error: (lazarus) package file "'+AFilename+'" and name "'+NewPackage.Name+'" mismatch.');
      exit(mrCancel);
    end;
    // ok
    if pvPkgSearch in Verbosity then
      debugln('Info: (lazarus) Open dependency ['+Dependency.PackageName+']: Success: "'+NewPackage.Filename+'"');
    Result:=mrOk;
    Dependency.RequiredPackage:=NewPackage;
    Dependency.LoadPackageResult:=lprSuccess;
    OldPackage:=FindPackageWithName(NewPackage.Name,NewPackage);
    if OldPackage=nil then
      AddPackage(NewPackage)
    else
      ReplacePackage(OldPackage,NewPackage);
  finally
    if Result<>mrOk then
      NewPackage.Free;
    EndUpdate;
    FreeAndNil(XMLConfig);
  end;
end;

function TLazPackageGraph.DeleteAmbiguousFiles(const Filename: string
  ): TModalResult;
begin
  if Assigned(OnDeleteAmbiguousFiles) then
    Result:=OnDeleteAmbiguousFiles(Filename)
  else
    Result:=mrOk;
end;

procedure TLazPackageGraph.AddMessage(TheUrgency: TMessageLineUrgency;
  const Msg, Filename: string);
begin
  if Assigned(IDEMessagesWindow) then
    IDEMessagesWindow.AddCustomMessage(TheUrgency,Msg,Filename)
  else
    DebugLn([MessageLineUrgencyNames[TheUrgency],': (lazarus) ',Msg,' Filename="',Filename,'"']);
end;

function TLazPackageGraph.OutputDirectoryIsWritable(APackage: TLazPackage;
  Directory: string; Verbose: boolean): boolean;
begin
  Result:=false;
  //debugln(['TLazPackageGraph.OutputDirectoryIsWritable ',Directory]);
  if not FilenameIsAbsolute(Directory) then
    exit;
  Directory:=ChompPathDelim(Directory);
  if not DirPathExistsCached(Directory) then begin
    // the directory does not exist => try creating it
    if not ForceDirectoriesUTF8(Directory) then begin
      if Verbose then begin
        IDEMessageDialog(lisPkgMangUnableToCreateDirectory,
          Format(lisPkgMangUnableToCreateOutputDirectoryForPackage,
                 [Directory, LineEnding, APackage.IDAsString]),
          mtError,[mbCancel]);
      end;
      debugln(['Error: (lazarus) unable to create package output directory "',Directory,'" of package "',APackage.IDAsString,'"']);
      exit;
    end;
    Result:=true;
  end else
    Result:=DirectoryIsWritableCached(Directory);
end;

function TLazPackageGraph.GetPackageCompilerParams(APackage: TLazPackage
  ): string;
begin
  Result:=APackage.CompilerOptions.MakeOptionsString(
          APackage.CompilerOptions.DefaultMakeOptionsFlags+[ccloAbsolutePaths])
          +' '+PrepareCmdLineOption(CreateRelativePath(APackage.GetSrcFilename,APackage.Directory));
end;

constructor TLazPackageGraph.Create;
begin
  OnGetAllRequiredPackages:=@GetAllRequiredPackages;
  FTree:=TAVLTree.Create(@CompareLazPackageID);
  FItems:=TFPList.Create;
  FLazarusBasePackages:=TFPList.Create;
  if GlobalMacroList<>nil then begin
    GlobalMacroList.Add(TTransferMacro.Create('PkgDir','',
      lisPkgMacroPackageDirectoryParameterIsPackageID, @MacroFunctionPkgDir, []));
    GlobalMacroList.Add(TTransferMacro.Create('PkgSrcPath','',
      lisPkgMacroPackageSourceSearchPathParameterIsPackageID,
      @MacroFunctionPkgSrcPath,[]));
    GlobalMacroList.Add(TTransferMacro.Create('PkgUnitPath','',
      lisPkgMacroPackageUnitSearchPathParameterIsPackageID,
      @MacroFunctionPkgUnitPath,[]));
    GlobalMacroList.Add(TTransferMacro.Create('PkgIncPath','',
      lisPkgMacroPackageIncludeFilesSearchPathParameterIsPackageID,
      @MacroFunctionPkgIncPath,[]));
    GlobalMacroList.Add(TTransferMacro.Create('PkgName','',
      lisPkgMacroPackageNameParameterIsPackageID,
      @MacroFunctionPkgName,[]));
    GlobalMacroList.Add(TTransferMacro.Create('PkgOutDir','',
      lisPkgMacroPackageOutputDirectoryParameterIsPackageID,
      @MacroFunctionPkgOutDir,[]));
  end;
end;

destructor TLazPackageGraph.Destroy;
begin
  if LazarusPackageIntf.RegisterUnitProc=@RegisterUnitHandler then
    LazarusPackageIntf.RegisterUnitProc:=nil;
  if RegisterComponentsProc=@RegisterComponentsGlobalHandler then
    RegisterComponentsProc:=nil;
  if RegisterNoIconProc=@RegisterNoIconGlobalHandler then
    RegisterNoIconProc:=nil;
  if OnGetAllRequiredPackages=@GetAllRequiredPackages then
    OnGetAllRequiredPackages:=nil;
  Clear;
  FreeAndNil(FLazarusBasePackages);
  FreeAndNil(FItems);
  FreeAndNil(FTree);
  FreeAndNil(FFindFileCache);
  inherited Destroy;
end;

procedure TLazPackageGraph.Clear;
var
  i: Integer;
begin
  FLazarusBasePackages.Clear;
  for i:=FItems.Count-1 downto 0 do Delete(i);
end;

procedure TLazPackageGraph.Delete(Index: integer);
var
  CurPkg: TLazPackage;
begin
  CurPkg:=Packages[Index];
  if lpfDestroying in CurPkg.Flags then exit;

  BeginUpdate(true);
  CurPkg.Flags:=CurPkg.Flags+[lpfDestroying];
  CurPkg.DefineTemplates.Active:=false;

  if Assigned(OnDeletePackage) then OnDeletePackage(CurPkg);

  if CurPkg=FCLPackage then
    FFCLPackage:=nil
  else if CurPkg=LCLBasePackage then
    FLCLBasePackage:=nil
  else if CurPkg=LCLPackage then
    FLCLPackage:=nil
  else if CurPkg=IDEIntfPackage then
    FIDEIntfPackage:=nil
  else if CurPkg=DebuggerIntfPackage then
    FDebuggerIntfPackage:=nil
  else if CurPkg=LazDebuggerGdbmiPackage then
    FLazDebuggerGdbmiPackage:=nil
  else if CurPkg=SynEditPackage then
    FSynEditPackage:=nil
  else if CurPkg=LazControlsPackage then
    FLazControlsPackage:=nil
  else if CurPkg=LazUtilsPackage then
    FLazUtilsPackage:=nil
  else if CurPkg=CodeToolsPackage then
    FCodeToolsPackage:=nil;
  FLazarusBasePackages.Remove(CurPkg);

  FItems.Delete(Index);
  FTree.Remove(CurPkg);
  CurPkg.Free;
  EndUpdate;
end;

function TLazPackageGraph.Count: integer;
begin
  Result:=FItems.Count;
end;

procedure TLazPackageGraph.BeginUpdate(Change: boolean);
begin
  inc(FUpdateLock);
  if FUpdateLock=1 then begin
    fChanged:=Change;
    FLockedChangeStamp:=0;
    FHasCompiledFpmakePackages := False;
    if Assigned(OnBeginUpdate) then OnBeginUpdate(Self);
  end else
    fChanged:=fChanged or Change;
end;

procedure TLazPackageGraph.EndUpdate;
begin
  if FUpdateLock<=0 then RaiseGDBException('TLazPackageGraph.EndUpdate');
  dec(FUpdateLock);
  if FUpdateLock=0 then begin
    if FLockedChangeStamp>0 then
      IncChangeStamp;
    if Assigned(OnEndUpdate) then OnEndUpdate(Self,fChanged);
  end;
end;

function TLazPackageGraph.Updating: boolean;
begin
  Result:=FUpdateLock>0;
end;

procedure TLazPackageGraph.RebuildDefineTemplates;
var
  i: Integer;
begin
  for i:=0 to Count-1 do
    Packages[i].DefineTemplates.AllChanged;
end;

function TLazPackageGraph.MacroFunctionPkgDir(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
var
  APackage: TLazPackage;
begin
  if GetPackageFromMacroParameter(s,APackage) then
    Result:=APackage.Directory
  else
    Result:='';
end;

function TLazPackageGraph.MacroFunctionPkgSrcPath(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
var
  APackage: TLazPackage;
begin
  if GetPackageFromMacroParameter(s,APackage) then
    Result:=APackage.SourceDirectories.CreateSearchPathFromAllFiles
  else
    Result:='';
end;

function TLazPackageGraph.MacroFunctionPkgUnitPath(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
var
  APackage: TLazPackage;
begin
  if GetPackageFromMacroParameter(s,APackage) then
    Result:=APackage.GetUnitPath(false)
  else
    Result:='';
end;

function TLazPackageGraph.MacroFunctionPkgIncPath(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
var
  APackage: TLazPackage;
begin
  if GetPackageFromMacroParameter(s,APackage) then
    Result:=APackage.GetIncludePath(false)
  else
    Result:='';
end;

function TLazPackageGraph.MacroFunctionPkgName(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
begin
  Result := s;
end;

function TLazPackageGraph.MacroFunctionPkgOutDir(const s: string;
  const Data: PtrInt; var Abort: boolean): string;
var
  APackage: TLazPackage;
begin
  if GetPackageFromMacroParameter(s,APackage) then
    Result:=APackage.GetOutputDirectory
  else
    Result:='';
end;

function TLazPackageGraph.MacroFunctionCTPkgDir(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  APackage: TLazPackage;
begin
  FuncData:=PReadFunctionData(Data);
  Result:=GetPackageFromMacroParameter(FuncData^.Param,APackage);
  if Result then
    FuncData^.Result:=APackage.Directory;
end;

function TLazPackageGraph.MacroFunctionCTPkgSrcPath(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  APackage: TLazPackage;
begin
  FuncData:=PReadFunctionData(Data);
  Result:=GetPackageFromMacroParameter(FuncData^.Param,APackage);
  if Result then
    FuncData^.Result:=APackage.GetUnitPath(false)+';'+APackage.GetSrcPath(false);
end;

function TLazPackageGraph.MacroFunctionCTPkgUnitPath(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  APackage: TLazPackage;
begin
  FuncData:=PReadFunctionData(Data);
  Result:=GetPackageFromMacroParameter(FuncData^.Param,APackage);
  if Result then
    FuncData^.Result:=APackage.GetUnitPath(false);
end;

function TLazPackageGraph.MacroFunctionCTPkgIncPath(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  APackage: TLazPackage;
begin
  FuncData:=PReadFunctionData(Data);
  Result:=GetPackageFromMacroParameter(FuncData^.Param,APackage);
  if Result then
    FuncData^.Result:=APackage.GetIncludePath(false);
end;

function TLazPackageGraph.MacroFunctionCTPkgName(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
begin
  FuncData:=PReadFunctionData(Data);
  FuncData^.Result:=GetIdentifier(PChar(FuncData^.Param));
  Result:=true;
end;

function TLazPackageGraph.MacroFunctionCTPkgOutDir(Data: Pointer): boolean;
var
  FuncData: PReadFunctionData;
  APackage: TLazPackage;
begin
  FuncData:=PReadFunctionData(Data);
  Result:=GetPackageFromMacroParameter(FuncData^.Param,APackage);
  if Result then
    FuncData^.Result:=APackage.GetOutputDirectory;
end;

function TLazPackageGraph.GetPackageFromMacroParameter(const TheID: string;
  out APackage: TLazPackage): boolean;
var
  PkgID: TLazPackageID;
begin
  PkgID:=TLazPackageID.Create;
  if PkgID.StringToID(TheID) then begin
    APackage:=FindPackageWithIDMask(PkgID);
    if APackage=nil then begin
      DebugLn('Warning: (lazarus) unknown macro package id "',TheID,'"');
    end;
  end else begin
    APackage:=nil;
    DebugLn('Warning: (lazarus) invalid macro package id "',TheID,'"');
  end;
  PkgID.Free;
  Result:=APackage<>nil;
end;

function TLazPackageGraph.FindLowestPkgNodeByName(const PkgName: string
  ): TAVLTreeNode;
var
  PriorNode: TAVLTreeNode;
begin
  Result:=nil;
  if PkgName='' then exit;
  Result:=FTree.FindKey(PChar(PkgName),@CompareNameWithPackageID);
  while Result<>nil do begin
    PriorNode:=FTree.FindPrecessor(Result);
    if (PriorNode=nil)
    or (SysUtils.CompareText(PkgName,TLazPackage(PriorNode.Data).Name)<>0) then
      break;
    Result:=PriorNode;
  end;
end;

function TLazPackageGraph.FindNextSameName(ANode: TAVLTreeNode): TAVLTreeNode;
var
  NextNode: TAVLTreeNode;
begin
  Result:=nil;
  if ANode=nil then exit;
  NextNode:=FTree.FindSuccessor(ANode);
  if (NextNode=nil)
  or (SysUtils.CompareText(TLazPackage(ANode.Data).Name,
                      TLazPackage(NextNode.Data).Name)<>0)
  then exit;
  Result:=NextNode;
end;

function TLazPackageGraph.FindNodeOfDependency(Dependency: TPkgDependency;
  Flags: TFindPackageFlags): TAVLTreeNode;
var
  CurPkg: TLazPackage;
begin
  // search in all packages with the same name
  Result:=FindLowestPkgNodeByName(Dependency.PackageName);
  while Result<>nil do begin
    CurPkg:=TLazPackage(Result.Data);
    // check version
    if (not (fpfIgnoreVersion in Flags))
    and (not Dependency.IsCompatible(CurPkg)) then begin
      Result:=FindNextSameName(Result);
      continue;
    end;
    // check loaded packages
    if (fpfSearchInLoadedPkgs in Flags) then exit;
    // check installed packages
    if (fpfSearchInInstalledPckgs in Flags)
    and (CurPkg.Installed<>pitNope) then exit;
    // check autoinstall packages
    if (fpfSearchInAutoInstallPckgs in Flags)
    and (CurPkg.AutoInstall<>pitNope) then exit;
    // check packages with opened editor
    if (fpfSearchInPckgsWithEditor in Flags) and (CurPkg.Editor<>nil) then exit;
    // search next package node with same name
    Result:=FindNextSameName(Result);
  end;
end;

function TLazPackageGraph.FindOpenPackage(Dependency: TPkgDependency;
  Flags: TFindPackageFlags): TLazPackage;
var
  ANode: TAVLTreeNode;
begin
  ANode:=FindNodeOfDependency(Dependency,Flags);
  if ANode<>nil then
    Result:=TLazPackage(ANode.Data)
  else
    Result:=nil;
end;

function TLazPackageGraph.FindPackageWithName(const PkgName: string;
  IgnorePackage: TLazPackage): TLazPackage;
var
  ANode: TAVLTreeNode;
begin
  Result:=nil;
  ANode:=FindLowestPkgNodeByName(PkgName);
  if ANode<>nil then begin
    Result:=TLazPackage(ANode.Data);
    if Result=IgnorePackage then begin
      Result:=nil;
      ANode:=FindNextSameName(ANode);
      if ANode<>nil then
        Result:=TLazPackage(ANode.Data);
    end;
  end;
end;

function TLazPackageGraph.FindPackageWithID(PkgID: TLazPackageID): TLazPackage;
var
  ANode: TAVLTreeNode;
begin
  ANode:=FTree.Find(PkgID);
  if ANode<>nil then
    Result:=TLazPackage(ANode.Data)
  else
    Result:=nil;
end;

function TLazPackageGraph.FindPackageWithIDMask(PkgIDMask: TLazPackageID
  ): TLazPackage;
var
  ANode: TAVLTreeNode;
begin
  ANode:=FTree.FindKey(PkgIDMask,@ComparePkgIDMaskWithPackageID);
  if ANode<>nil then
    Result:=TLazPackage(ANode.Data)
  else
    Result:=nil;
end;

function TLazPackageGraph.FindPackageProvidingName(
  FirstDependency: TPkgDependency;
  const Name: string): TLazPackage;
  
  function Search(ADependency: TPkgDependency; out Found: TLazPackage): boolean;
  begin
    Found:=nil;
    while ADependency<>nil do begin
      Found:=ADependency.RequiredPackage;
      //DebugLn(['Search ',Found.Name,' ',Found.ProvidesPackage(Name),' "',Found.Provides.Text,'"']);
      if (Found<>nil) and (not (lpfVisited in Found.Flags)) then begin
        Found.Flags:=Found.Flags+[lpfVisited];
        if Found.ProvidesPackage(Name)
        or Search(Found.FirstRequiredDependency,Found) then
          exit(true);
      end;
      ADependency:=ADependency.NextRequiresDependency;
    end;
    Found:=nil;
    Result:=false;
  end;
  
begin
  MarkAllPackagesAsNotVisited;
  Search(FirstDependency,Result);
end;

function TLazPackageGraph.FindDependencyRecursively(
  FirstDependency: TPkgDependency; PkgID: TLazPackageID): TPkgDependency;
// returns one compatible dependency for PkgID

  function Find(CurDependency: TPkgDependency): TPkgDependency;
  var
    RequiredPackage: TLazPackage;
  begin
    while CurDependency<>nil do begin
      if CurDependency.IsCompatible(PkgID) then begin
        Result:=CurDependency;
        exit;
      end;
      if (CurDependency.DependencyType=pdtLazarus) and (CurDependency.LoadPackageResult=lprSuccess) then begin
        RequiredPackage:=CurDependency.RequiredPackage;
        if (not (lpfVisited in RequiredPackage.Flags)) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          Result:=Find(RequiredPackage.FirstRequiredDependency);
          if Result<>nil then exit;
        end;
      end;
      CurDependency:=CurDependency.NextRequiresDependency;
    end;
    Result:=nil;
  end;

begin
  if FirstDependency=nil then exit(nil);
  MarkAllPackagesAsNotVisited;
  Result:=Find(FirstDependency);
end;

function TLazPackageGraph.FindDependencyRecursively(
  FirstDependency: TPkgDependency; const PkgName: string): TPkgDependency;
// returns one compatible dependency for PkgName

  function Find(CurDependency: TPkgDependency): TPkgDependency;
  var
    RequiredPackage: TLazPackage;
  begin
    while CurDependency<>nil do begin
      if SysUtils.CompareText(CurDependency.PackageName,PkgName)=0 then begin
        Result:=CurDependency;
        exit;
      end;
      if (CurDependency.DependencyType=pdtLazarus) and (CurDependency.LoadPackageResult=lprSuccess) then begin
        RequiredPackage:=CurDependency.RequiredPackage;
        if (not (lpfVisited in RequiredPackage.Flags)) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          Result:=Find(RequiredPackage.FirstRequiredDependency);
          if Result<>nil then exit;
        end;
      end;
      CurDependency:=CurDependency.NextRequiresDependency;
    end;
    Result:=nil;
  end;

begin
  if FirstDependency=nil then exit(nil);
  MarkAllPackagesAsNotVisited;
  Result:=Find(FirstDependency);
end;

function TLazPackageGraph.FindConflictRecursively(
  FirstDependency: TPkgDependency; PkgID: TLazPackageID): TPkgDependency;
// returns one conflicting dependency for PkgID

  function Find(CurDependency: TPkgDependency): TPkgDependency;
  var
    RequiredPackage: TLazPackage;
  begin
    while CurDependency<>nil do begin
      if (SysUtils.CompareText(CurDependency.PackageName,PkgID.Name)=0)
      and (not CurDependency.IsCompatible(PkgID)) then begin
        Result:=CurDependency;
        exit;
      end;
      if CurDependency.LoadPackageResult=lprSuccess then begin
        RequiredPackage:=CurDependency.RequiredPackage;
        if Assigned(RequiredPackage) and (not (lpfVisited in RequiredPackage.Flags)) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          Result:=Find(RequiredPackage.FirstRequiredDependency);
          if Result<>nil then exit;
        end;
      end;
      CurDependency:=CurDependency.NextRequiresDependency;
    end;
    Result:=nil;
  end;

begin
  if FirstDependency=nil then exit(nil);
  MarkAllPackagesAsNotVisited;
  Result:=Find(FirstDependency);
end;

function TLazPackageGraph.FindRuntimePkgOnlyRecursively(
  FirstDependency: TPkgDependency): TPkgDependency;
// returns one dependency using a runtime only package

  function Find(CurDependency: TPkgDependency): TPkgDependency;
  var
    RequiredPackage: TLazPackage;
  begin
    while CurDependency<>nil do begin
      if (CurDependency.LoadPackageResult=lprSuccess) and (CurDependency.DependencyType=pdtLazarus) then begin
        RequiredPackage:=CurDependency.RequiredPackage;
        if (not (lpfVisited in RequiredPackage.Flags)) then begin
          if RequiredPackage.PackageType=lptRunTimeOnly then
            exit(CurDependency);
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          Result:=Find(RequiredPackage.FirstRequiredDependency);
          if Result<>nil then exit;
        end;
      end;
      CurDependency:=CurDependency.NextRequiresDependency;
    end;
    Result:=nil;
  end;

begin
  if FirstDependency=nil then exit(nil);
  MarkAllPackagesAsNotVisited;
  Result:=Find(FirstDependency);
end;

function TLazPackageGraph.FindUnit(StartPackage: TLazPackage;
  const TheUnitName: string;
  WithRequiredPackages, IgnoreDeleted: boolean): TPkgFile;
var
  ADependency: TPkgDependency;
  ARequiredPackage: TLazPackage;
begin
  Result:=StartPackage.FindUnit(TheUnitName,IgnoreDeleted);
  if Result<>nil then exit;
  // search also in all required packages
  if WithRequiredPackages then begin
    ADependency:=StartPackage.FirstRequiredDependency;
    while ADependency<>nil do begin
      ARequiredPackage:=FindOpenPackage(ADependency,[fpfSearchInInstalledPckgs]);
      if ARequiredPackage<>nil then begin
        Result:=ARequiredPackage.FindUnit(TheUnitName,IgnoreDeleted);
        if Result<>nil then exit;
      end;
      ADependency:=ADependency.NextRequiresDependency;
    end;
  end;
end;

function TLazPackageGraph.FindUnitInAllPackages(
  const TheUnitName: string; IgnoreDeleted: boolean): TPkgFile;
var
  Cnt: Integer;
  i: Integer;
begin
  Cnt:=Count;
  for i:=0 to Cnt-1 do begin
    Result:=FindUnit(Packages[i],TheUnitName,false,IgnoreDeleted);
    if Result<>nil then exit;
  end;
  Result:=nil;
end;

function TLazPackageGraph.FindUnitInInstalledPackages(
  const TheUnitName: string; IgnoreDeleted: boolean): TPkgFile;
var
  Cnt: Integer;
  i: Integer;
  Pkg: TLazPackage;
begin
  Cnt:=Count;
  for i:=0 to Cnt-1 do begin
    Pkg:=Packages[i];
    if Pkg.Installed=pitNope then continue;
    Result:=FindUnit(Pkg,TheUnitName,false,IgnoreDeleted);
    if Result<>nil then exit;
  end;
  Result:=nil;
end;

function TLazPackageGraph.GetMapSourceDirectoryToPackage(
  IgnorePackage: TLazPackage): TFilenameToPointerTree;
var
  i: Integer;
  aPackage: TLazPackage;
  SearchPath: String;
  p: Integer;
  Dir: String;
begin
  Result:=TFilenameToPointerTree.Create(false);
  for i:=0 to Count-1 do begin
    aPackage:=Packages[i];
    if aPackage.IsVirtual then continue;
    if aPackage=IgnorePackage then continue;
    SearchPath:=aPackage.SourceDirectories.CreateSearchPathFromAllFiles;
    p:=1;
    repeat
      Dir:=GetNextDirectoryInSearchPath(SearchPath,p);
      if Dir='' then break;
      Dir:=ChompPathDelim(Dir);
      Result[Dir]:=aPackage;
    until false;
  end;
end;

function TLazPackageGraph.EstimateCompileLoad(APackage: TLazPackage): int64;
var
  PkgFile: TPkgFile;
  i: Integer;
begin
  Result:=1;
  for i:=0 to APackage.FileCount-1 do begin
    PkgFile:=APackage.Files[i];
    if PkgFile.FileType in [pftUnit,pftMainUnit,pftInclude,pftLFM] then begin
      inc(Result,CodeToolBoss.DirectoryCachePool.FileSize(PkgFile.Filename));
    end;
  end;
end;

function TLazPackageGraph.FindFileInAllPackages(const TheFilename: string;
  IgnoreDeleted, FindVirtualFile: boolean): TPkgFile;
begin
  if FFindFileCache=nil then
    FFindFileCache := TLazPackageGraphFileCache.Create(Self);

  Result := FFindFileCache.FindFileInAllPackages(TheFilename, IgnoreDeleted, FindVirtualFile);
end;

procedure TLazPackageGraph.FindPossibleOwnersOfUnit(const TheFilename: string;
  OwnerList: TFPList);
var
  Cnt: Integer;
  i: Integer;
  APackage: TLazPackage;
  SrcDir: String;

  function SrcDirInPath(Dirs: String): boolean;
  begin
    Result:=FindPathInSearchPath(PChar(SrcDir),length(SrcDir),
                                 PChar(Dirs),length(Dirs))<>nil;
  end;

begin
  if not FilenameIsAbsolute(TheFilename) then exit;
  Cnt:=Count;
  SrcDir:=ExtractFilePath(TheFilename);
  for i:=0 to Cnt-1 do begin
    APackage:=Packages[i];
    if APackage.IsVirtual then continue;
    // source directories + unit path without inherited paths + base directory + output directory
    if SrcDirInPath(APackage.CompilerOptions.GetParsedPath(pcosUnitPath,icoNone,false))
    or SrcDirInPath(APackage.SourceDirectories.CreateSearchPathFromAllFiles)
    or SrcDirInPath(APackage.GetOutputDirectory)
    or SrcDirInPath(APackage.Directory)
    then
      OwnerList.Add(APackage);
  end;
end;

function TLazPackageGraph.FindPackageWithFilename(const TheFilename: string
  ): TLazPackage;
var
  Cnt: Integer;
  i: Integer;
begin
  Cnt:=Count;
  for i:=0 to Cnt-1 do begin
    Result:=Packages[i];
    if Result.IsVirtual then continue;
    if CompareFilenames(TheFilename,Result.Filename)=0 then
      exit;
  end;
  Result:=nil;
end;

function TLazPackageGraph.CreateUniqueUnitName(const Prefix: string): string;
begin
  Result:=Prefix;
  while FindUnitInAllPackages(Result,false)<>nil do
    Result:=CreateNextIdentifier(Result);
end;

function TLazPackageGraph.PackageNameExists(const PkgName: string;
  IgnorePackage: TLazPackage): boolean;
var
  ANode: TAVLTreeNode;
begin
  Result:=false;
  if PkgName<>'' then begin
    ANode:=FindLowestPkgNodeByName(PkgName);
    if (ANode<>nil) and (IgnorePackage=TLazPackage(ANode.Data)) then
      ANode:=FindNextSameName(ANode);
    Result:=ANode<>nil;
  end;
end;

procedure TLazPackageGraph.PkgModify(Sender: TObject);
begin
  IncChangeStamp;
end;

function TLazPackageGraph.DependencyExists(Dependency: TPkgDependency;
  Flags: TFindPackageFlags): boolean;
begin
  Result:=true;
  if FindNodeOfDependency(Dependency,Flags)<>nil then exit;
  if FindPackageWithName(Dependency.PackageName,nil)=nil then begin
    // no package with same name open
    // -> try package links
    if fpfSearchInPkgLinks in Flags then
      if LazPackageLinks.FindLinkWithDependency(Dependency)<>nil then exit;
  end else begin
    // there is already a package with this name open, but the wrong version
  end;
  Result:=false;
end;

function TLazPackageGraph.CreateUniquePkgName(Prefix: string;
  IgnorePackage: TLazPackage): string;
var
  i: Integer;
begin
  if not IsValidPkgName(Prefix) then
    RaiseGDBException('invalid pkg name "'+Prefix+'"');
  // try Prefix alone
  if not PackageNameExists(Prefix,IgnorePackage) then begin
    Result:=Prefix;
  end else begin
    // try Prefix + number
    i:=1;
    while PackageNameExists(Prefix+IntToStr(i),IgnorePackage) do inc(i);
    Result:=Prefix+IntToStr(i);
  end;
end;

function TLazPackageGraph.CreateNewPackage(const Prefix: string): TLazPackage;
begin
  BeginUpdate(true);
  Result:=TLazPackage.Create;
  Result.OnModifySilently:=@PkgModify;
  Result.Name:=CreateUniquePkgName(Prefix,nil);
  AddPackage(Result);
  EndUpdate;
end;

procedure TLazPackageGraph.ConsistencyCheck;
begin
  CheckList(FItems,true,true,true);
end;

procedure TLazPackageGraph.RegisterUnitHandler(const TheUnitName: string;
  RegisterProc: TRegisterProc);
begin
  if AbortRegistration then exit;

  ErrorMsg:='';
  FRegistrationFile:=nil;
  FRegistrationUnitName:='';

  // check package
  if FRegistrationPackage=nil then begin
    RegistrationError('Unit: '+TheUnitName);
    exit;
  end;
  try
    // check unitname
    FRegistrationUnitName:=TheUnitName;
    if not IsValidUnitName(FRegistrationUnitName) then begin
      RegistrationError(Format(lisPkgSysInvalidUnitname, [FRegistrationUnitName]
        ));
      exit;
    end;
    // check unit file
    FRegistrationFile:=FindUnit(FRegistrationPackage,FRegistrationUnitName,true,true);
    if FRegistrationFile=nil then begin
      if not (FRegistrationPackage.Missing) then begin
        // lpk exists, but file is missing => warn
        FRegistrationFile:=
          FRegistrationPackage.FindUnit(FRegistrationUnitName,false);
        if FRegistrationFile=nil then begin
          RegistrationError(Format(
            lisPkgSysUnitWasNotFoundInTheLpkFileProbablyThisLpkFileWasN, [
            FRegistrationUnitName, LineEnding]));
        end else begin
          if not (pffReportedAsRemoved in FRegistrationFile.Flags) then begin
            RegistrationError(
              Format(lisPkgSysUnitWasRemovedFromPackageLpk, [
                FRegistrationUnitName]));
            FRegistrationFile.Flags:=FRegistrationFile.Flags+[pffReportedAsRemoved];
          end;
        end;
      end;
      exit;
    end;
    CallRegisterProc(RegisterProc);
    // clean up
  finally
    FRegistrationUnitName:='';
    FRegistrationFile:=nil;
  end;
end;

procedure TLazPackageGraph.RegisterComponentsHandler(const Page: string;
  ComponentClasses: array of TComponentClass);
var
  i: integer;
  CurComponent: TComponentClass;
  NewPkgComponent: TPkgComponent;
  CurClassname: string;
begin
  {$IFDEF IDE_MEM_CHECK}
  CheckHeap('TLazPackageGraph.RegisterComponentsHandler Page='+Page);
  {$ENDIF}
  if AbortRegistration or (Low(ComponentClasses)>High(ComponentClasses)) then
    exit;

  ErrorMsg:='';

  // check package
  if FRegistrationPackage=nil then begin
    RegistrationError('');
    exit;
  end;
  // check unit file
  if FRegistrationFile=nil then begin
    RegistrationError(lisPkgSysCanNotRegisterComponentsWithoutUnit);
    exit;
  end;
  // register components
  for i:=Low(ComponentClasses) to High(ComponentClasses) do begin
    CurComponent:=ComponentClasses[i];
    if (CurComponent=nil) then continue;
    {$IFNDEF StopOnRegError}
    try
    {$ENDIF}
      CurClassname:=CurComponent.Classname;
      if not IsValidIdent(CurClassname) then begin
        RegistrationError(lisPkgSysInvalidComponentClass);
        continue;
      end;
    {$IFNDEF StopOnRegError}
    except
      on E: Exception do begin
        RegistrationError(E.Message);
        continue;
      end;
    end;
    {$ENDIF}
    if (IDEComponentPalette<>nil)
    and (IDEComponentPalette.FindComponent(CurClassname)<>nil) then
      RegistrationError(Format(lisPkgSysComponentClassAlreadyDefined,[CurClassname]));
    if AbortRegistration then exit;
    // add the component to the package owning the file
    // (e.g. a designtime package can register units of a runtime packages)
    NewPkgComponent:=
      FRegistrationFile.LazPackage.AddComponent(FRegistrationFile,Page,CurComponent);
    //DebugLn('TLazPackageGraph.RegisterComponentsHandler Page="',Page,
    //        '" CurComponent=',CurClassname,' FRegistrationFile=',FRegistrationFile.Filename);
    if IDEComponentPalette<>nil then
      IDEComponentPalette.AddComponent(NewPkgComponent);
  end;
end;

procedure TLazPackageGraph.RegistrationError(const Msg: string);
var
  DlgResult: Integer;
  IgnoreAll: Integer;
begin
  // create nice and useful error message

  // current registration package
  if FRegistrationPackage=nil then begin
    ErrorMsg:=lisPkgSysRegisterUnitWasCalledButNoPackageIsRegistering;
  end else begin
    ErrorMsg:='Package: "'+FRegistrationPackage.IDAsString+'"';
    if FRegistrationPackage.Missing then
      ErrorMsg:=Format(lisPkgSysTheLpkFileWasNotFound, [ErrorMsg, LineEnding])
    else
      ErrorMsg:=Format(lisPkgSysLPKFilename, [ErrorMsg, LineEnding, FRegistrationPackage.Filename]);
    // current unitname
    if FRegistrationUnitName<>'' then
      ErrorMsg:=Format(lisPkgSysUnitName, [ErrorMsg, LineEnding, FRegistrationUnitName]);
    // current file
    if FRegistrationFile<>nil then
      ErrorMsg:=Format(lisPkgSysFileName, [ErrorMsg, LineEnding, FRegistrationFile.Filename]);
  end;
  // append message
  if Msg<>'' then
    ErrorMsg:=ErrorMsg+LineEnding+LineEnding+Msg;
  debugln(['Error: (lazarus) register failed: ',dbgstr(ErrorMsg)]);

  if AbortRegistration or QuietRegistration then exit;

  // tell user
  IgnoreAll:=mrLast+1;
  DlgResult:=IDEQuestionDialog(lisPkgSysPackageRegistrationError, ErrorMsg,
                     mtError, [mrIgnore,
                               IgnoreAll, lisIgnoreAll,
                               mrAbort]);
  if DlgResult=IgnoreAll then
    QuietRegistration:=true;
  if DlgResult=mrAbort then
    AbortRegistration:=true;
end;

procedure TLazPackageGraph.OnExtToolBuildStopped(Sender: TObject);
var
  PkgCompileTool: TAbstractExternalTool;
  Data: TLazPkgGraphExtToolData;
  aPackage: TLazPackage;
  SrcPPUFile: String;
  MsgResult: TModalResult;
  SrcPPUFileExists: Boolean;
begin
  PkgCompileTool:=Sender as TAbstractExternalTool;
  Data:=PkgCompileTool.Data as TLazPkgGraphExtToolData;
  aPackage:=Data.Pkg;
  //debugln(['TLazPackageGraph.OnExtToolBuildStopped aPackage=',aPackage.IDAsString]);

  // check if main ppu file was created
  SrcPPUFile:=Data.SrcPPUFilename;
  SrcPPUFileExists:=(SrcPPUFile<>'') and FileExistsUTF8(SrcPPUFile);
  // write state file
  MsgResult:=SavePackageCompiledState(APackage,
                    Data.CompilerFilename,Data.CompilerParams,
                    PkgCompileTool.ErrorMessage='',SrcPPUFileExists,false);
  if MsgResult<>mrOk then begin
    Data.ErrorMessage:='SavePackageCompiledState failed';
    PkgCompileTool.ErrorMessage:=Data.ErrorMessage;
    DebugLn(['Error: (lazarus) failed to write package .compiled file: ',APackage.IDAsString,' File=',aPackage.GetStateFilename]);
    exit;
  end;
  Data.ErrorMessage:=PkgCompileTool.ErrorMessage;

  if Data.ErrorMessage<>'' then exit;

  // update .po files
  if (APackage.POOutputDirectory<>'') then begin
    MsgResult:=ConvertPackageRSTFiles(APackage);
    if MsgResult<>mrOk then begin
      Data.ErrorMessage:='ConvertPackageRSTFiles failed';
      PkgCompileTool.ErrorMessage:=Data.ErrorMessage;
      DebugLn('Error: (lazarus) failed to update .po files: ',APackage.IDAsString);
      IDEMessagesWindow.AddCustomMessage(mluError,
        Format(lisUpdatingPoFilesFailedForPackage, [APackage.IDAsString]));
      exit;
    end;
  end;
end;

function TLazPackageGraph.CreateDefaultPackage: TLazPackage;
begin
  Result:=TLazPackage.Create;
  with Result do begin
    Missing:=true;
    UserReadOnly:=true;
    Name:='DefaultPackage';
    Filename:=GetForcedPathDelims('$(LazarusDir)/components/custom/customdummy.lpk');
    Version.SetValues(1,0,1,1);
    Author:='Anonymous';
    AutoInstall:=pitStatic;
    AutoUpdate:=pupManually;
    Description:=lisPkgSysThisIsTheDefaultPackageUsedOnlyForComponents;
    PackageType:=lptDesignTime;
    Installed:=pitStatic;
    CompilerOptions.UnitOutputDirectory:='';
    Translated:=SystemLanguageID1;

    // add unit paths
    UsageOptions.UnitPath:='$(PkgOutDir)';

    // add requirements
    AddRequiredDependency(LCLPackage.CreateDependencyWithOwner(Result));
    AddRequiredDependency(SynEditPackage.CreateDependencyWithOwner(Result));

    Modified:=false;
    OnModifySilently:=@PkgModify;
  end;
  IncChangeStamp;
end;

function TLazPackageGraph.GetCount: Integer;
begin
  Result:=FItems.Count;
end;

procedure TLazPackageGraph.AddPackage(APackage: TLazPackage);

  procedure SetBasePackage(var BasePackage: TLazPackage);
  begin
    if BasePackage=APackage then exit;
    if BasePackage<>nil then
      RaiseGDBException('TLazPackageGraph.AddPackage Pkg='+APackage.IDAsString+' conflicts with existing base package');
    BasePackage:=APackage;
  end;

var
  Dependency: TPkgDependency;
begin
  BeginUpdate(true);
  FTree.Add(APackage);
  FItems.Add(APackage);

  if IsStaticBasePackage(APackage.Name) then begin
    APackage.Installed:=pitStatic;
    APackage.AutoInstall:=pitStatic;
    if SysUtils.CompareText(APackage.Name,'FCL')=0 then begin
      SetBasePackage(FFCLPackage);
      APackage.SetAllComponentPriorities(FCLCompPriority);
    end
    else if SysUtils.CompareText(APackage.Name,'LazUtils')=0 then
      SetBasePackage(FLazUtilsPackage)
    else if SysUtils.CompareText(APackage.Name,'LCLBase')=0 then begin
      SetBasePackage(FLCLBasePackage);
      APackage.SetAllComponentPriorities(LCLCompPriority);
    end
    else if SysUtils.CompareText(APackage.Name,'LCL')=0 then begin
      SetBasePackage(FLCLPackage);
      APackage.SetAllComponentPriorities(LCLCompPriority);
    end
    else if SysUtils.CompareText(APackage.Name,'IDEIntf')=0 then begin
      SetBasePackage(FIDEIntfPackage);
      APackage.SetAllComponentPriorities(IDEIntfCompPriority);
    end
    else if SysUtils.CompareText(APackage.Name,'DebuggerIntf')=0 then
      SetBasePackage(FDebuggerIntfPackage)
    else if SysUtils.CompareText(APackage.Name,'LazDebuggerGdbmi')=0 then
      SetBasePackage(FLazDebuggerGdbmiPackage)
    else if SysUtils.CompareText(APackage.Name,'SynEdit')=0 then
      SetBasePackage(FSynEditPackage)
    else if SysUtils.CompareText(APackage.Name,'LazControls')=0 then
      SetBasePackage(FLazControlsPackage)
    else if SysUtils.CompareText(APackage.Name,'CodeTools')=0 then
      SetBasePackage(FCodeToolsPackage);
    if FLazarusBasePackages.IndexOf(APackage)<0 then
      FLazarusBasePackages.Add(APackage);
  end;

  // open all required dependencies
  Dependency:=APackage.FirstRequiredDependency;
  while Dependency<>nil do begin
    OpenDependency(Dependency,false);
    Dependency:=Dependency.NextRequiresDependency;
  end;
  
  // update all missing dependencies
  UpdateBrokenDependenciesToPackage(APackage);
  
  // activate define templates
  APackage.DefineTemplates.Active:=true;

  if Assigned(OnAddPackage) then OnAddPackage(APackage);
  EndUpdate;
end;

procedure TLazPackageGraph.ReplacePackage(var OldPackage: TLazPackage;
  NewPackage: TLazPackage);

  procedure MoveInstalledComponents(OldPkgFile: TPkgFile);
  var
    NewPkgFile: TPkgFile;
    OldUnitName: String;
    PkgComponent: TPkgComponent;
  begin
    if (OldPkgFile.ComponentCount>0) then begin
      OldUnitName:=OldPkgFile.Unit_Name;
      if OldUnitName='' then RaiseGDBException('MoveInstalledComponents');
      NewPkgFile:=NewPackage.FindUnit(OldUnitName,false);
      if NewPkgFile=nil then begin
        NewPkgFile:=NewPackage.AddRemovedFile(OldPkgFile.Filename,OldUnitName,
                                        OldPkgFile.FileType,OldPkgFile.Flags,
                                        OldPkgFile.ComponentPriority.Category);
      end;
      while OldPkgFile.ComponentCount>0 do begin
        PkgComponent:=OldPkgFile.Components[0];
        PkgComponent.PkgFile:=NewPkgFile;
      end;
    end;
  end;

var
  OldInstalled: TPackageInstallType;
  OldAutoInstall: TPackageInstallType;
  OldEditor: TBasePackageEditor;
  i: Integer;
begin
  if pvPkgSearch in Verbosity then
    debugln(['Info: (lazarus) replacing package "'+OldPackage.Filename+'" with "'+NewPackage.Filename+'"']);
  BeginUpdate(true);
  // save flags
  OldInstalled:=OldPackage.Installed;
  OldAutoInstall:=OldPackage.AutoInstall;
  OldEditor:=OldPackage.Editor;
  if OldEditor<>nil then begin
    OldEditor.LazPackage:=nil;
  end;
  // migrate components
  for i:=0 to OldPackage.FileCount-1 do
    MoveInstalledComponents(OldPackage.Files[i]);
  for i:=0 to OldPackage.RemovedFilesCount-1 do
    MoveInstalledComponents(OldPackage.RemovedFiles[i]);
  // delete old package
  Delete(fItems.IndexOf(OldPackage));
  OldPackage:=nil;
  // restore flags
  NewPackage.Installed:=OldInstalled;
  NewPackage.AutoInstall:=OldAutoInstall;
  // add package to graph
  AddPackage(NewPackage);
  if OldEditor<>nil then begin
    OldEditor.LazPackage:=NewPackage;
  end;
  EndUpdate;
end;

procedure TLazPackageGraph.LoadStaticBasePackages;

  procedure LoadLazarusBasePackage(PkgName: string);
  var
    Dependency: TPkgDependency;
    Quiet: Boolean;
  begin
    if FindDependencyByNameInList(FirstAutoInstallDependency,pdlRequires,
      PkgName)<>nil
    then
      exit;
    Dependency:=TPkgDependency.Create;
    Dependency.Owner:=Self;
    Dependency.PackageName:=PkgName;
    Dependency.DependencyType:=pdtLazarus;
    Dependency.AddToList(FirstAutoInstallDependency,pdlRequires);
    Quiet:=false;
    OpenInstalledDependency(Dependency,pitStatic,Quiet);
  end;

begin
  LoadLazarusBasePackage('FCL');
  LoadLazarusBasePackage('LazUtils');
  LoadLazarusBasePackage('LCLBase');
  LoadLazarusBasePackage('LCL');
  LoadLazarusBasePackage('SynEdit');
  LoadLazarusBasePackage('IDEIntf');
  LoadLazarusBasePackage('DebuggerIntf');
  LoadLazarusBasePackage('LazDebuggerGdbmi');
  LoadLazarusBasePackage('LazControls');
  LoadLazarusBasePackage('CodeTools');

  SortAutoInstallDependencies;

  // register them
  RegisterStaticBasePackages;
end;

procedure TLazPackageGraph.LoadAutoInstallPackages(PkgList: TStringList);
var
  i: Integer;
  PackageName: string;
  Dependency: TPkgDependency;
begin
  for i:=0 to PkgList.Count-1 do begin
    PackageName:=PkgList[i];
    if not IsValidPkgName(PackageName) then continue;
    Dependency:=FindDependencyByNameInList(FirstAutoInstallDependency,
                                           pdlRequires,PackageName);
    //DebugLn('TLazPackageGraph.LoadAutoInstallPackages ',dbgs(Dependency),' ',PackageName);
    if Dependency<>nil then continue;
    Dependency:=TPkgDependency.Create;
    Dependency.Owner:=Self;
    Dependency.DependencyType:=pdtLazarus;
    Dependency.PackageName:=PackageName;
    Dependency.AddToList(FirstAutoInstallDependency,pdlRequires);
    if OpenDependency(Dependency,false)<>lprSuccess then begin
      IDEMessageDialog(lisPkgMangUnableToLoadPackage,
        Format(lisPkgMangUnableToOpenThePackage, [PackageName, LineEnding]),
        mtWarning,[mbOk]);
      continue;
    end;
    if not Dependency.RequiredPackage.Missing then
      Dependency.RequiredPackage.AutoInstall:=pitStatic;
  end;
  SortAutoInstallDependencies;
end;

procedure TLazPackageGraph.SortAutoInstallDependencies;
begin
  // sort install dependencies, so that lower packages come first
  SortDependencyListTopologicallyOld(PackageGraph.FirstAutoInstallDependency,
                                               false);
end;

function TLazPackageGraph.GetIDEInstallPackageOptions(
  var InheritedOptionStrings: TInheritedCompOptsStrings): string;

  procedure AddOption(const s: string);
  begin
    if s='' then exit;
    if Result='' then
      Result:=s
    else
      Result:=Result+' '+s;
  end;

var
  PkgList: TFPList;
  AddOptionsList: TFPList;
  ConfigDir: String;
begin
  Result:='';
  // get all required packages
  PkgList:=nil;
  GetAllRequiredPackages(nil,FirstAutoInstallDependency,PkgList,[pirCompileOrder]);
  if PkgList=nil then exit;
  // get all usage options
  AddOptionsList:=GetUsageOptionsList(PkgList);
  PkgList.Free;
  if AddOptionsList<>nil then begin
    // combine options of same type
    GatherInheritedOptions(AddOptionsList,coptParsed,InheritedOptionStrings);
    AddOptionsList.Free;
  end;

  // convert options to compiler parameters
  Result:=InheritedOptionsToCompilerParameters(InheritedOptionStrings,[]);

  // add activate-static-packages option
  AddOption('-dAddStaticPkgs');

  // add include path to config directory
  ConfigDir:=AppendPathDelim(GetPrimaryConfigPath);
  AddOption(PrepareCmdLineOption('-Fi'+UTF8ToSys(ConfigDir)));
end;

function TLazPackageGraph.SaveAutoInstallConfig: TModalResult;
var
  ConfigDir: String;
  StaticPackagesInc: String;
  StaticPckIncludeFile: String;
  PkgList: TFPList;
  APackage: TLazPackage;
  i: Integer;
begin
  ConfigDir:=AppendPathDelim(GetPrimaryConfigPath);

  // create auto install package list for the Lazarus uses section
  PkgList:=nil;
  try
    GetAllRequiredPackages(nil,FirstAutoInstallDependency,PkgList,[pirCompileOrder]);
    StaticPackagesInc:='';
    if PkgList<>nil then begin
      for i:=0 to PkgList.Count-1 do begin
        APackage:=TLazPackage(PkgList[i]);
        if (APackage=nil)
        or APackage.Missing
        or IsStaticBasePackage(APackage.Name)
        or (APackage.PackageType in [lptRunTime,lptRunTimeOnly])
        then continue;
        StaticPackagesInc:=StaticPackagesInc
            +ExtractFileNameOnly(APackage.GetCompileSourceFilename)
            +','+LineEnding;
      end;
    end;
  finally
    PkgList.Free;
  end;
  StaticPckIncludeFile:=ConfigDir+'staticpackages.inc';
  Result:=SaveStringToFile(StaticPckIncludeFile,StaticPackagesInc,[],
                           lisPkgMangstaticPackagesConfigFile);
end;

function TLazPackageGraph.IsStaticBasePackage(PackageName: string): boolean;
begin
  PackageName:=lowercase(PackageName);
  Result:=(PackageName='fcl')
       or (PackageName='lazutils')
       or (PackageName='lclbase')
       or (PackageName='lcl')
       or (PackageName='synedit')
       or (PackageName='ideintf')
       or (PackageName='debuggerintf')
       or (PackageName='lazdebuggergdbmi')
       or (PackageName='codetools')
       or (PackageName='lazcontrols');
end;

procedure TLazPackageGraph.FreeAutoInstallDependencies;
var
  Dependency: TPkgDependency;
begin
  while Assigned(PackageGraph.FirstAutoInstallDependency) do
  begin
    Dependency:=PackageGraph.FirstAutoInstallDependency;
    Dependency.RequiredPackage:=nil;
    Dependency.RemoveFromList(PackageGraph.FirstAutoInstallDependency,pdlRequires);
    Dependency.Free;
  end;
end;

procedure TLazPackageGraph.ClosePackage(APackage: TLazPackage);
begin
  if (lpfDestroying in APackage.Flags) or PackageIsNeeded(APackage) then exit;
  CloseUnneededPackages;
end;

procedure TLazPackageGraph.MarkNeededPackages;
var
  StackPtr, i: Integer;
  Pkg, RequiredPackage: TLazPackage;
  Dependency: TPkgDependency;
  PkgStack: PLazPackage;
begin
  if Count=0 then exit;
  // create stack
  GetMem(PkgStack,SizeOf(Pointer)*Count);
  StackPtr:=0;
  // put all needed packages on stack and set lpfNeeded
  for i:=0 to FItems.Count-1 do begin
    Pkg:=TLazPackage(FItems[i]);
    if PackageIsNeeded(Pkg) then begin
      Pkg.Flags:=Pkg.Flags+[lpfNeeded];
      PkgStack[StackPtr]:=Pkg;
      inc(StackPtr);
    end else
      Pkg.Flags:=Pkg.Flags-[lpfNeeded];
  end;
  // mark all needed packages
  while StackPtr>0 do begin
    // get needed package from stack
    dec(StackPtr);
    Pkg:=PkgStack[StackPtr];
    // put all required packages on stack
    Dependency:=Pkg.FirstRequiredDependency;
    while Dependency<>nil do begin
      if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
        RequiredPackage:=Dependency.RequiredPackage;
        if (not (lpfNeeded in RequiredPackage.Flags)) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfNeeded];
          PkgStack[StackPtr]:=RequiredPackage;
          inc(StackPtr);
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;
  // clean up
  FreeMem(PkgStack);
end;

function TLazPackageGraph.FindBrokenDependencyPath(APackage: TLazPackage;
  FirstDependency: TPkgDependency): TFPList;
// returns the first broken dependency (broken = not loaded)
// the first items are TLazPackage, the last item is a TPkgDependency
  
  procedure FindBroken(Dependency: TPkgDependency; var PathList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if Dependency.DependencyType=pdtFPMake then begin
        // FPMake dependency have no RequiredPackage -> ignore
      end else if Dependency.LoadPackageResult=lprSuccess then begin
        // dependency ok
        if Dependency.DependencyType=pdtLazarus then begin
          RequiredPackage:=Dependency.RequiredPackage;
          if not (lpfVisited in RequiredPackage.Flags) then begin
            RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
            FindBroken(RequiredPackage.FirstRequiredDependency,PathList);
            if PathList<>nil then begin
              // broken dependency found
              // -> add current package to list
              PathList.Insert(0,RequiredPackage);
              exit;
            end;
          end;
        end;
      end else begin
        // broken dependency found
        PathList:=TFPList.Create;
        PathList.Add(Dependency);
        exit;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;
  
begin
  Result:=nil;
  if (Count=0) then exit;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then begin
    APackage.Flags:=APackage.Flags+[lpfVisited];
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  FindBroken(FirstDependency,Result);
  if (Result<>nil) and (APackage<>nil) then
    Result.Insert(0,APackage);
end;

function TLazPackageGraph.FindAllBrokenDependencies(APackage: TLazPackage;
  FirstDependency: TPkgDependency): TFPList;
// returns the list of broken dependencies (TPkgDependency)

  procedure FindBroken(Dependency: TPkgDependency; var DepList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if Dependency.DependencyType=pdtFPMake then begin
        // FPMake dependency have no RequiredPackage -> ignore
      end else if Dependency.LoadPackageResult=lprSuccess then begin
        // dependency ok
        RequiredPackage:=Dependency.RequiredPackage;
        if not (lpfVisited in RequiredPackage.Flags) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          FindBroken(RequiredPackage.FirstRequiredDependency,DepList);
        end;
      end else begin
        // broken dependency found
        if (DepList=nil) or (DepList.IndexOf(Dependency)<0) then begin
          if DepList=nil then
            DepList:=TFPList.Create;
          DepList.Add(Dependency);
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

begin
  Result:=nil;
  if (Count=0) then exit;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then begin
    APackage.Flags:=APackage.Flags+[lpfVisited];
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  FindBroken(FirstDependency,Result);
end;

function TLazPackageGraph.FindCycleDependencyPath(APackage: TLazPackage;
  FirstDependency: TPkgDependency): TFPList;

  procedure FindCycle(Dependency: TPkgDependency; var PathList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if Dependency.LoadPackageResult=lprSuccess then begin
        // dependency ok
        RequiredPackage:=Dependency.RequiredPackage;
        if Dependency.DependencyType=pdtLazarus then begin
          if lpfCycle in RequiredPackage.Flags then begin
            // cycle detected
            PathList:=TFPList.Create;
            PathList.Add(RequiredPackage);
            exit;
          end;
          if not (lpfVisited in RequiredPackage.Flags) then begin
            RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited,lpfCycle];
            FindCycle(RequiredPackage.FirstRequiredDependency,PathList);
            if PathList<>nil then begin
              // cycle detected
              // -> add current package to list
              PathList.Insert(0,RequiredPackage);
              exit;
            end;
            RequiredPackage.Flags:=RequiredPackage.Flags-[lpfCycle];
          end;
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

var
  i: Integer;
  Pkg: TLazPackage;
begin
  Result:=nil;
  if (Count=0) then exit;
  // mark all packages as not visited and cycle free
  for i:=FItems.Count-1 downto 0 do begin
    Pkg:=TLazPackage(FItems[i]);
    Pkg.Flags:=Pkg.Flags-[lpfVisited,lpfCycle];
  end;
  if APackage<>nil then begin
    APackage.Flags:=APackage.Flags+[lpfVisited];
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  FindCycle(FirstDependency,Result);
  if (Result<>nil) and (APackage<>nil) then
    Result.Insert(0,APackage);
end;

function TLazPackageGraph.FindPath(StartPackage: TLazPackage;
  StartDependency: TPkgDependency; const EndPackageName: string): TFPList;

  procedure Find(Dependency: TPkgDependency; var PathList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if SysUtils.CompareText(Dependency.PackageName,EndPackageName)=0 then begin
        // path found
        PathList:=TFPList.Create;
        if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
          PathList.Add(Dependency.RequiredPackage);
        end else begin
          PathList.Add(Dependency);
        end;
        exit;
      end;
      if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
        // dependency ok
        RequiredPackage:=Dependency.RequiredPackage;
        if not (lpfVisited in RequiredPackage.Flags) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          Find(RequiredPackage.FirstRequiredDependency,PathList);
          if PathList<>nil then begin
            // path found
            // -> add current package to list
            PathList.Insert(0,RequiredPackage);
            exit;
          end;
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

begin
  Result:=nil;
  if (Count=0) then exit;
  MarkAllPackagesAsNotVisited;
  if StartPackage<>nil then begin
    StartPackage.Flags:=StartPackage.Flags+[lpfVisited];
    StartDependency:=StartPackage.FirstRequiredDependency;
  end;
  Find(StartDependency,Result);
  if (Result<>nil) and (StartPackage<>nil) then
    Result.Insert(0,StartPackage);
end;

function TLazPackageGraph.FindPkgOutputInFPCSearchPath(APackage: TLazPackage;
  FirstDependency: TPkgDependency): TFPList;
var
  CfgCache: TPCTargetConfigCache;

  function CheckPkg(Pkg: TLazPackage; var PathList: TFPList): boolean;
  var
    OutputDir: String;
    i: Integer;
    Dir: String;
  begin
    Result:=true;
    if (Pkg=nil) then exit;
    Pkg.Flags:=Pkg.Flags+[lpfVisited];
    if (Pkg.FirstRequiredDependency=nil)
    or (Pkg.GetActiveBuildMethod=bmFPMake) // Packages compiled by FPMake almost always change units in the default fpc-search path. Checking of changed dependencies should be done using the mechanisms of fppkg.
    or Pkg.IsVirtual or (Pkg.AutoUpdate<>pupAsNeeded) then exit;
    // this package is compiled automatically and has dependencies
    OutputDir:=ChompPathDelim(Pkg.GetOutputDirectory);
    if OutputDir='' then exit;
    for i:=0 to CfgCache.UnitPaths.Count-1 do begin
      Dir:=ChompPathDelim(CfgCache.UnitPaths[i]);
      if CompareFilenames(Dir,OutputDir)=0 then begin
        // this package changes the units in the default FPC search path
        // => a cycle, because the dependencies use FPC search path too
        Result:=false;
        PathList:=TFPList.Create;
        PathList.Add(Pkg);
        exit;
      end;
    end;
  end;

  procedure CheckDependencyList(Dependency: TPkgDependency; var PathList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
        RequiredPackage:=Dependency.RequiredPackage;
        if not (lpfVisited in RequiredPackage.Flags) then begin
          if CheckPkg(RequiredPackage,PathList) then exit;
          CheckDependencyList(RequiredPackage.FirstRequiredDependency,PathList);
          if PathList<>nil then begin
            // cycle detected
            // -> add current package to list
            PathList.Insert(0,RequiredPackage);
            exit;
          end;
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

var
  UnitSet: TFPCUnitSetCache;
begin
  Result:=nil;
  MarkAllPackagesAsNotVisited;
  UnitSet:=CodeToolBoss.GetUnitSetForDirectory('');
  if UnitSet=nil then exit;
  CfgCache:=UnitSet.GetConfigCache(false);
  if (CfgCache=nil) or (CfgCache.UnitPaths=nil) then exit;
  if APackage<>nil then begin
    if not CheckPkg(APackage,Result) then exit;
    if FirstDependency=nil then
      FirstDependency:=APackage.FirstRequiredDependency;
  end;
  CheckDependencyList(FirstDependency,Result);
end;

function TLazPackageGraph.FindUnsavedDependencyPath(APackage: TLazPackage;
  FirstDependency: TPkgDependency): TFPList;

  procedure FindUnsaved(Dependency: TPkgDependency; var PathList: TFPList);
  var
    RequiredPackage: TLazPackage;
  begin
    while Dependency<>nil do begin
      if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
        // dependency ok
        RequiredPackage:=Dependency.RequiredPackage;
        if RequiredPackage.Modified then begin
          // unsaved package detected
          PathList:=TFPList.Create;
          PathList.Add(RequiredPackage);
          exit;
        end;
        if not (lpfVisited in RequiredPackage.Flags) then begin
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          FindUnsaved(RequiredPackage.FirstRequiredDependency,PathList);
          if PathList<>nil then begin
            // unsaved package detected
            // -> add current package to list
            PathList.Insert(0,RequiredPackage);
            exit;
          end;
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

begin
  Result:=nil;
  if (Count=0) or (APackage=nil) then exit;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then begin
    APackage.Flags:=APackage.Flags+[lpfVisited];
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  FindUnsaved(FirstDependency,Result);
  if (Result<>nil) and (APackage<>nil) then
    Result.Insert(0,APackage);
end;

function TLazPackageGraph.FindNotInstalledRegisterUnits(
  APackage: TLazPackage; FirstDependency: TPkgDependency): TFPList;
// returns the list of required units (TPkgFile) with a Register procedure,
// that are not installed in the IDE

  procedure FindNotInstalledRegisterUnit(Dependency: TPkgDependency;
    var UnitList: TFPList);
  var
    RequiredPackage: TLazPackage;
    i: Integer;
    APkgFile: TPkgFile;
  begin
    while Dependency<>nil do begin
      if (Dependency.DependencyType=pdtLazarus)
          and (Dependency.LoadPackageResult=lprSuccess) then begin
        // dependency ok
        RequiredPackage:=Dependency.RequiredPackage;
        if not (lpfVisited in RequiredPackage.Flags) then begin
          if (RequiredPackage.Installed=pitNope)
              and (RequiredPackage.PackageType in [lptDesignTime,lptRunAndDesignTime])
          then begin
            // package not installed and can be installed
            for i:=0 to RequiredPackage.FileCount-1 do begin
              APkgFile:=RequiredPackage.Files[i];
              if APkgFile.HasRegisterProc then begin
                // unit with register procedure -> add
                if UnitList=nil then
                  UnitList:=TFPList.Create;
                UnitList.Add(APkgFile);
              end;
            end;
          end;
          RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
          FindNotInstalledRegisterUnit(RequiredPackage.FirstRequiredDependency,UnitList);
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

begin
  Result:=nil;
  if (Count=0) then exit;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then begin
    APackage.Flags:=APackage.Flags+[lpfVisited];
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  FindNotInstalledRegisterUnit(FirstDependency,Result);
end;

function TLazPackageGraph.FindAutoInstallDependencyPath(
  ChildPackage: TLazPackage): TFPList;
  
  procedure FindAutoInstallParent(APackage: TLazPackage);
  var
    ParentPackage: TLazPackage;
    Dependency: TPkgDependency;
  begin
    Dependency:=APackage.FirstUsedByDependency;
    while Dependency<>nil do begin
      if Dependency.Owner is TLazPackage then begin
        ParentPackage:=TLazPackage(Dependency.Owner);
        if not (lpfVisited in ParentPackage.Flags) then begin
          ParentPackage.Flags:=ParentPackage.Flags+[lpfVisited];
          if ParentPackage.AutoInstall<>pitNope then begin
            // auto install parent found
            if Result=nil then Result:=TFPList.Create;
            Result.Add(ParentPackage);
            Result.Add(APackage);
            exit;
          end;
          FindAutoInstallParent(ParentPackage);
          if Result<>nil then begin
            // build path
            Result.Add(APackage);
            exit;
          end;
        end;
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

begin
  Result:=nil;
  MarkAllPackagesAsNotVisited;
  ChildPackage.Flags:=ChildPackage.Flags+[lpfVisited];
  FindAutoInstallParent(ChildPackage);
end;

function TLazPackageGraph.FindAmbiguousUnits(APackage: TLazPackage;
  FirstDependency: TPkgDependency; out File1, File2: TPkgFile; out
  ConflictPkg: TLazPackage): boolean;
// check if two connected packages have units with the same name
// Connected means here: a Package1 is directly required by a Package2
// or: a Package1 and a Package2 are directly required by a Package3
// returns true, if ambiguous units found
// There can either be a conflict between two files (File1,File2)
// or between a file and a package (File1,ConflictPkg)
var
  PackageTreeOfUnitTrees: TAVLTree; // tree of TPkgUnitsTree
  
  function GetUnitsTreeOfPackage(Pkg: TLazPackage): TPkgUnitsTree;
  var
    ANode: TAVLTreeNode;
    PkgFile: TPkgFile;
    i: Integer;
  begin
    // for first time: create PackageTreeOfUnitTrees
    if PackageTreeOfUnitTrees=nil then
      PackageTreeOfUnitTrees:=TAVLTree.Create(TListSortCompare(@CompareUnitsTree));
    // search UnitsTree for package
    ANode:=PackageTreeOfUnitTrees.FindKey(Pkg, TListSortCompare(@ComparePackageWithUnitsTree));
    if ANode<>nil then begin
      Result:=TPkgUnitsTree(ANode.Data);
      exit;
    end;
    // first time: create tree of units for Pkg
    Result:=TPkgUnitsTree.Create(Pkg);
    PackageTreeOfUnitTrees.Add(Result);
    for i:=0 to Pkg.FileCount-1 do begin
      PkgFile:=Pkg.Files[i];
      if (PkgFile.FileType in PkgFileRealUnitTypes) and (PkgFile.Unit_Name<>'') then
        Result.Add(PkgFile);
    end;
  end;
  
  function FindAmbiguousUnitsBetween2Packages(Pkg1,Pkg2: TLazPackage): boolean;
  var
    i: Integer;
    PkgFile1: TPkgFile;
    PkgFile2: TPkgFile;
    UnitsTreeOfPkg2: TPkgUnitsTree;
  begin
    Result:=false;
    if Pkg1=Pkg2 then exit;
    if (Pkg1.FileCount=0) or (Pkg2.FileCount=0) then exit;
    UnitsTreeOfPkg2:=GetUnitsTreeOfPackage(Pkg2);
    // check if a unit of Pkg2 has the same name as Pkg1
    PkgFile2:=UnitsTreeOfPkg2.FindPkgFileWithUnitName(Pkg1.Name);
    if PkgFile2<>nil then begin
      File1:=PkgFile2;
      ConflictPkg:=Pkg1;
      Result:=true;
      exit;
    end;
    for i:=0 to Pkg1.FileCount-1 do begin
      PkgFile1:=Pkg1.Files[i];
      if (PkgFile1.FileType in PkgFileRealUnitTypes)
      and (PkgFile1.Unit_Name<>'') then begin
        // check if a unit of Pkg1 exists in Pkg2
        PkgFile2:=UnitsTreeOfPkg2.FindPkgFileWithUnitName(PkgFile1.Unit_Name);
        if PkgFile2<>nil then begin
          File1:=PkgFile1;
          File2:=PkgFile2;
          Result:=true;
          exit;
        end;
        // check if a unit of Pkg1 has the same name as Pkg2
        if SysUtils.CompareText(PkgFile1.Unit_Name,Pkg2.Name)=0 then begin
          File1:=PkgFile1;
          ConflictPkg:=Pkg2;
          Result:=true;
          exit;
        end;
      end;
    end;
  end;

var
  PkgList: TFPList;
  ConnectionsTree: TPkgPairTree;
  ANode: TAVLTreeNode;
  Pair: TPkgPair;
begin
  Result:=false;
  if APackage<>nil then begin
    FirstDependency:=APackage.FirstRequiredDependency;
  end;
  File1:=nil;
  File2:=nil;
  ConflictPkg:=nil;
  ConnectionsTree:=nil;
  PkgList:=nil;
  PackageTreeOfUnitTrees:=nil;
  GetConnectionsTree(FirstDependency,PkgList,ConnectionsTree);
  try
    if ConnectionsTree=nil then exit;
    ANode:=ConnectionsTree.FindLowest;
    while ANode<>nil do begin
      Pair:=TPkgPair(ANode.Data);
      Result:=FindAmbiguousUnitsBetween2Packages(Pair.Package1,Pair.Package2);
      if Result then exit;
      ANode:=ConnectionsTree.FindSuccessor(ANode);
    end;
  finally
    if PackageTreeOfUnitTrees<>nil then begin
      PackageTreeOfUnitTrees.FreeAndClear;
      PackageTreeOfUnitTrees.Free;
    end;
    ConnectionsTree.Free;
    PkgList.Free;
  end;
  Result:=false;
end;

function TLazPackageGraph.FindFPCConflictUnit(APackage: TLazPackage;
  FirstDependency: TPkgDependency; const Directory: string;
  OnFindFPCUnit: TFindFPCUnitEvent;
  var File1: TPkgFile; var ConflictPkg: TLazPackage): boolean;
  
  function CheckUnitName(const AnUnitName: string): boolean;
  var Filename: string;
  begin
    Result:=false;
    if AnUnitName='' then exit;
    Filename:='';
    OnFindFPCUnit(AnUnitName,Directory,Filename);
    Result:=Filename<>'';
  end;
  
  function CheckDependencyList(ADependency: TPkgDependency): boolean; forward;

  function CheckPackage(Pkg1: TLazPackage): boolean;
  var
    Cnt: Integer;
    i: Integer;
    CurFile: TPkgFile;
  begin
    Result:=false;
    if (Pkg1=nil) or (lpfVisited in Pkg1.Flags)
    or (Pkg1=FFCLPackage) or (Pkg1=FLCLBasePackage) or (Pkg1=FLCLPackage) then exit;
    Pkg1.Flags:=Pkg1.Flags+[lpfVisited];
    Result:=CheckUnitName(Pkg1.Name);
    if Result then begin
      ConflictPkg:=Pkg1;
      exit;
    end;
    Cnt:=Pkg1.FileCount;
    for i:=0 to Cnt-1 do begin
      CurFile:=Pkg1.Files[i];
      if (CurFile.FileType in PkgFileRealUnitTypes)
      and (pffAddToPkgUsesSection in CurFile.Flags) then begin
        Result:=CheckUnitName(CurFile.Unit_Name);
        if Result then begin
          File1:=CurFile;
          exit;
        end;
      end;
    end;
    Result:=CheckDependencyList(Pkg1.FirstRequiredDependency);
  end;
  
  function CheckDependencyList(ADependency: TPkgDependency): boolean;
  begin
    Result:=false;
    while ADependency<>nil do begin
      Result:=CheckPackage(ADependency.RequiredPackage);
      if Result then exit;
      ADependency:=ADependency.NextDependency[pdlRequires];
    end;
  end;

begin
  Result:=false;
  if (Directory<>'') and not FilenameIsAbsolute(Directory) then
    RaiseGDBException(Directory);
  File1:=nil;
  ConflictPkg:=nil;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then
    Result:=CheckPackage(APackage)
  else
    Result:=CheckDependencyList(FirstDependency);
end;

procedure TLazPackageGraph.MarkAllPackagesAsNotVisited;
var
  i: Integer;
  Pkg: TLazPackage;
begin
  // mark all packages as not visited
  for i:=FItems.Count-1 downto 0 do begin
    Pkg:=TLazPackage(FItems[i]);
    Pkg.Flags:=Pkg.Flags-[lpfVisited];
  end;
end;

procedure TLazPackageGraph.MarkAllDependencies(
  MarkPackages: boolean; AddMarkerFlags, RemoveMarkerFlags: TPkgMarkerFlags);
var
  i: Integer;
  Pkg: TLazPackage;
  Dependency: TPkgDependency;
begin
  // mark all dependencies of all packages as not visited
  for i:=FItems.Count-1 downto 0 do begin
    Pkg:=TLazPackage(FItems[i]);
    if MarkPackages then
      Pkg.Flags:=Pkg.Flags-[lpfVisited];
    Dependency:=Pkg.FirstRequiredDependency;
    while Dependency<>nil do begin
      Dependency.MarkerFlags:=
                        Dependency.MarkerFlags+AddMarkerFlags-RemoveMarkerFlags;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;
end;

procedure TLazPackageGraph.MarkAllRequiredPackages(
  FirstDependency: TPkgDependency);
var
  Dependency: TPkgDependency;
  RequiredPackage: TLazPackage;
begin
  Dependency:=FirstDependency;
  while Dependency<>nil do begin
    if (Dependency.DependencyType=pdtLazarus) and (Dependency.LoadPackageResult=lprSuccess) then begin
      RequiredPackage:=Dependency.RequiredPackage;
      if not (lpfVisited in RequiredPackage.Flags) then begin
        RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
        MarkAllRequiredPackages(RequiredPackage.FirstRequiredDependency);
      end;
    end;
    Dependency:=Dependency.NextRequiresDependency;
  end;
end;

procedure TLazPackageGraph.CloseUnneededPackages;
var
  i: Integer;
begin
  BeginUpdate(false);
  MarkNeededPackages;
  for i:=FItems.Count-1 downto 0 do
    if not (lpfNeeded in Packages[i].Flags) then begin
      if ConsoleVerbosity>=0 then
        debugln(['Hint: closing unneeded package "',Packages[i].Name,'"']);
      Delete(i);
    end;
  EndUpdate;
end;

procedure TLazPackageGraph.ChangePackageID(APackage: TLazPackage;
  const NewName: string; NewVersion: TPkgVersion; RenameDependencies,
  RenameMacros: boolean);
var
  Dependency: TPkgDependency;
  NextDependency: TPkgDependency;
  OldPkgName: String;
  i: Integer;
  Macro: TLazBuildMacro;
  RenamedMacros: TStringList;
  OldMacroName: String;
  BaseCompOpts: TBaseCompilerOptions;
begin
  OldPkgName:=APackage.Name;
  if (OldPkgName=NewName) and (APackage.Version.Compare(NewVersion)=0) then
    exit; // fit exactly

  BeginUpdate(true);

  if RenameMacros then
  begin
    // rename macros
    RenamedMacros:=TStringList.Create;
    try
      for i:=0 to APackage.CompilerOptions.BuildMacros.Count-1 do
      begin
        Macro:=APackage.CompilerOptions.BuildMacros[i];
        if SysUtils.CompareText(OldPkgName,copy(Macro.Identifier,1,length(OldPkgName)))=0
        then begin
          OldMacroName:=Macro.Identifier;
          RenamedMacros.Add(OldMacroName);
          Macro.Identifier:=NewName+copy(OldMacroName,length(OldPkgName)+1,256);
          BaseCompOpts:=TBaseCompilerOptions(APackage.CompilerOptions);
          BaseCompOpts.RenameMacro(OldMacroName,Macro.Identifier,true);
        end;
      end;
    finally
      RenamedMacros.Free;
    end;
  end;

  // cut or fix all dependencies, that became incompatible
  Dependency:=APackage.FirstUsedByDependency;
  while Dependency<>nil do begin
    NextDependency:=Dependency.NextUsedByDependency;
    if not Dependency.IsCompatible(NewName,NewVersion) then begin
      if RenameDependencies then begin
        Dependency.MakeCompatible(NewName,NewVersion);
        if Assigned(OnDependencyModified) then OnDependencyModified(Dependency);
      end else begin
        // remove dependency from the used-by list of the required package
        Dependency.RequiredPackage:=nil;
      end;
    end;
    Dependency:=NextDependency;
  end;

  // change ID
  FTree.Remove(APackage);
  APackage.ChangeID(NewName,NewVersion);
  FTree.Add(APackage);

  // update old broken dependencies
  UpdateBrokenDependenciesToPackage(APackage);

  if Assigned(OnChangePackageName) then
    OnChangePackageName(APackage,OldPkgName);

  // no try-finally needed, because above fails only for fatal reasons
  EndUpdate;
end;

function TLazPackageGraph.SavePackageCompiledState(APackage: TLazPackage;
  const CompilerFilename, CompilerParams: string; Complete, MainPPUExists,
  ShowAbort: boolean): TModalResult;
var
  XMLConfig: TXMLConfig;
  StateFile: String;
  CompilerFileDate: Integer;
  o: TPkgOutputDir;
  stats: PPkgLastCompileStats;
begin
  Result:=mrCancel;
  StateFile:=APackage.GetStateFilename;
  try
    CompilerFileDate:=FileAgeCached(CompilerFilename);

    o:=APackage.GetOutputDirType;
    stats:=@APackage.LastCompile[o];
    stats^.CompilerFilename:=CompilerFilename;
    stats^.CompilerFileDate:=CompilerFileDate;
    stats^.Params:=CompilerParams;
    stats^.Complete:=Complete;
    stats^.ViaMakefile:=false;

    XMLConfig:=TXMLConfig.CreateClean(StateFile);
    try
      XMLConfig.SetValue('Compiler/Value',CompilerFilename);
      XMLConfig.SetValue('Compiler/Date',CompilerFileDate);
      XMLConfig.SetValue('Params/Value',CompilerParams);
      XMLConfig.SetDeleteValue('Complete/Value',Complete,true);
      XMLConfig.SetDeleteValue('Complete/MainPPUExists',MainPPUExists,true);
      InvalidateFileStateCache;
      XMLConfig.Flush;
    finally
      XMLConfig.Free;
    end;
    stats^.StateFileName:=StateFile;
    stats^.StateFileDate:=FileAgeCached(StateFile);
    APackage.LastCompile[o].StateFileLoaded:=true;
  except
    on E: Exception do begin
      Result:=IDEMessageDialogAb(lisPkgMangErrorWritingFile,
        Format(lisPkgMangUnableToWriteStateFileOfPackageError,
               [StateFile, LineEnding, APackage.IDAsString, LineEnding, E.Message]),
        mtError,[mbCancel],ShowAbort);
      exit;
    end;
  end;

  Result:=mrOk;
end;

function TLazPackageGraph.LoadPackageCompiledState(APackage: TLazPackage;
  IgnoreErrors, ShowAbort: boolean): TModalResult;
var
  XMLConfig: TXMLConfig;
  StateFile: String;
  StateFileAge: Integer;
  stats: PPkgLastCompileStats;
  o: TPkgOutputDir;
  MakefileValue: String;
  MakefileVersion: Integer;
begin
  o:=APackage.GetOutputDirType;
  stats:=@APackage.LastCompile[o];
  StateFile:=APackage.GetStateFilename;
  if not FileExistsCached(StateFile) then begin
    //DebugLn('TLazPackageGraph.LoadPackageCompiledState Statefile not found: ',StateFile);
    stats^.StateFileLoaded:=false;
    Result:=mrOk;
    exit;
  end;

  // read the state file
  StateFileAge:=FileAgeCached(StateFile);
  if (not stats^.StateFileLoaded)
  or (stats^.StateFileDate<>StateFileAge)
  or (stats^.StateFileName<>StateFile) then begin
    stats^.StateFileLoaded:=false;
    try
      XMLConfig:=TXMLConfig.Create(StateFile);
      try
        stats^.CompilerFilename:=XMLConfig.GetValue('Compiler/Value','');
        stats^.CompilerFileDate:=XMLConfig.GetValue('Compiler/Date',0);
        stats^.Params:=XMLConfig.GetValue('Params/Value','');
        stats^.Complete:=XMLConfig.GetValue('Complete/Value',true);
        stats^.MainPPUExists:=XMLConfig.GetValue('Complete/MainPPUExists',true);
        MakefileValue:=XMLConfig.GetValue('Makefile/Value','');
        if (MakefileValue='') then
          stats^.ViaMakefile:=false
        else begin
          stats^.ViaMakefile:=true;
          MakefileVersion:=StrToIntDef(MakefileValue,0);
          if MakefileVersion<2 then begin
            // old versions used %(
            stats^.CompilerFilename:=StringReplace(stats^.CompilerFilename,'%(','$(',[rfReplaceAll]);
            stats^.Params:=StringReplace(stats^.Params,'%(','$(',[rfReplaceAll]);
          end;
          ForcePathDelims(stats^.CompilerFilename);
          ForcePathDelims(stats^.Params);
        end;
      finally
        XMLConfig.Free;
      end;
      stats^.StateFileName:=StateFile;
      stats^.StateFileDate:=StateFileAge;
      stats^.StateFileLoaded:=true;
    except
      on E: EXMLReadError do begin
        // invalid XML
        debugln(['Warning: (lazarus) package "',APackage.IDAsString,'": syntax error in ',StateFile,' => need clean build.']);
        stats^.Complete:=false;
        stats^.CompilerFilename:='';
        stats^.StateFileName:=StateFile;
        stats^.StateFileDate:=StateFileAge;
        stats^.StateFileLoaded:=true;
      end;
      on E: Exception do begin
        if IgnoreErrors then begin
          Result:=mrOk;
        end else begin
          Result:=IDEMessageDialogAb(lisPkgMangErrorReadingFile,
            Format(lisPkgMangUnableToReadStateFileOfPackageError,
              [StateFile, LineEnding, APackage.IDAsString, LineEnding, E.Message]),
            mtError,[mbCancel],ShowAbort);
        end;
        exit;
      end;
    end;
  end;

  Result:=mrOk;
end;

function TLazPackageGraph.CheckCompileNeedDueToFPCUnits(TheOwner: TObject;
  StateFileAge: longint; var Note: string): boolean;
var
  AProject: TLazProject;
  Pkg: TLazPackage;
  ID: String;
  Dir: string;
  UnitSetID: String;
  HasChanged: boolean;
  Cache: TFPCUnitSetCache;
  CfgCache: TPCTargetConfigCache;
  Node: TAVLTreeNode;
  Item: PStringToStringItem;
  Filename: String;
  UnitToSrcTree: TStringToStringTree;
  CurUnitName: String;
  PkgOutDirs: TFilenameToStringTree;
  i: Integer;
begin
  Result:=false;
  if TheOwner=nil then exit;
  if TheOwner is TLazPackage then begin
    Pkg:=TLazPackage(TheOwner);
    if Pkg.IsVirtual then exit;
    Dir:=Pkg.DirectoryExpanded;
    ID:=Pkg.Name;
  end else if TheOwner is TLazProject then begin
    AProject:=TLazProject(TheOwner);
    Dir:=ExtractFilePath(AProject.ProjectInfoFile);
    ID:=ExtractFileName(AProject.ProjectInfoFile);
  end else
    exit;
  if (Dir='') or (not FilenameIsAbsolute(Dir)) then
    exit;
  UnitSetID:=CodeToolBoss.GetUnitSetIDForDirectory(Dir);
  if UnitSetID='' then exit;
  Cache:=CodeToolBoss.CompilerDefinesCache.FindUnitSetWithID(UnitSetID,HasChanged,false);
  if Cache=nil then exit;
  CfgCache:=Cache.GetConfigCache(false);
  if CfgCache=nil then exit;
  if CfgCache.Units=nil then exit;
  UnitToSrcTree:=Cache.GetUnitToSourceTree(false);
  PkgOutDirs:=TFilenameToStringTree.Create(false);
  try
    for i:=0 to Count-1 do
      PkgOutDirs[AppendPathDelim(Packages[i].CompilerOptions.GetUnitOutPath(false))]:='1';

    Node:=CfgCache.Units.Tree.FindLowest;
    while Node<>nil do begin
      Item:=PStringToStringItem(Node.Data);
      Node:=CfgCache.Units.Tree.FindSuccessor(Node);
      Filename:=Item^.Value;
      if PkgOutDirs.Contains(ExtractFilePath(Filename)) then begin
        // a package output directory is in the global search path
        // => ignore
        continue;
      end;
      CurUnitName:=Item^.Name;
      if (UnitToSrcTree<>nil) and (UnitToSrcTree.Count>0)
      and (not UnitToSrcTree.Contains(CurUnitName)) then begin
        // this unit has no source in the FPC source directory
        // probably an user unit reachable through a unit path in fpc.cfg
        continue;
      end;
      if FileAgeCached(Filename)>StateFileAge then begin
        if ConsoleVerbosity>=0 then
          debugln(['Hint: (lazarus) global unit "',Filename,'" is newer than state file of package ',ID]);
        Note+='Global unit "'+Filename+'" is newer than state file of '+ID+':'+LineEnding
          +'  Unit age='+FileAgeToStr(FileAgeCached(Filename))+LineEnding
          +'  State file age='+FileAgeToStr(StateFileAge)+LineEnding;
        exit(true);
      end;
    end;
  finally
    PkgOutDirs.Free;
  end;
end;

function TLazPackageGraph.CheckCompileNeedDueToDependencies(TheOwner: TObject;
  FirstDependency: TPkgDependency; SkipDesignTimePackages: boolean;
  StateFileAge: longint; var Note: string): TModalResult;

  function GetOwnerID: string;
  begin
    OnGetDependencyOwnerDescription(FirstDependency,Result);
  end;

var
  Dependency: TPkgDependency;
  RequiredPackage: TLazPackage;
  OtherStateFile: String;
  o: TPkgOutputDir;
begin
  Dependency:=FirstDependency;
  if Dependency=nil then begin
    // no dependencies
    // => check FPC units
    if CheckCompileNeedDueToFPCUnits(TheOwner,StateFileAge,Note) then
      exit(mrYes);
    Result:=mrNo;
    exit;
  end;

  while Dependency<>nil do begin
    if (Dependency.LoadPackageResult=lprSuccess) then begin
      RequiredPackage:=Dependency.RequiredPackage;
      if Dependency.DependencyType=pdtFPMake
      then begin
        // skip
      end else if SkipDesignTimePackages and (RequiredPackage.PackageType=lptDesignTime)
      then begin
        // skip
      end else begin
        // check compile state file of required package
        if (not RequiredPackage.IsVirtual) and (not RequiredPackage.Missing)
        then begin
          Result:=LoadPackageCompiledState(RequiredPackage,false,true);
          if Result<>mrOk then begin
            // file broken, user was told that file is broken and user had a
            // choice of cancel or cancel all (=mrAbort).
            // File broken means that the pkgname.compiled file has an invalid
            // format, syntax error. The user or some external tool has altered
            // the file. Maybe on purpose.
            // The IDE should not silently replace the file.
            // => pass the mrcancel/mrabort to the caller
            Note+='unable to load state file of '+RequiredPackage.IDAsString;
            exit;
          end;
          Result:=mrYes;
          o:=RequiredPackage.GetOutputDirType;
          if not RequiredPackage.LastCompile[o].StateFileLoaded then begin
            DebugLn('Hint: (lazarus) Missing state file for ',RequiredPackage.IDAsString,': ',RequiredPackage.GetStateFilename);
            Note+='Package '+RequiredPackage.IDAsString+' has no state file "'+RequiredPackage.GetStateFilename+'".'+LineEnding;
            exit;
          end;
          if StateFileAge<RequiredPackage.LastCompile[o].StateFileDate then begin
            DebugLn('Hint: (lazarus) State file of ',RequiredPackage.IDAsString,' is newer than state file of ',GetOwnerID);
            Note+='State file of '+RequiredPackage.IDAsString+' is newer than state file of '+GetOwnerID+LineEnding
              +'  '+RequiredPackage.IDAsString+'='+FileAgeToStr(RequiredPackage.LastCompile[o].StateFileDate)+LineEnding
              +'  '+GetOwnerID+'='+FileAgeToStr(StateFileAge)+LineEnding;
            exit;
          end;
          // check output state file of required package
          if RequiredPackage.OutputStateFile<>'' then begin
            OtherStateFile:=RequiredPackage.OutputStateFile;
            GlobalMacroList.SubstituteStr(OtherStateFile);
            if not FilenameIsAbsolute(OtherStateFile) then
              OtherStateFile:=AppendPathDelim(RequiredPackage.Directory)+OtherStateFile;
            if FilenameIsAbsolute(OtherStateFile)
            and FileExistsCached(OtherStateFile)
            and (FileAgeCached(OtherStateFile)>StateFileAge) then begin
              DebugLn('Hint: (lazarus) State file of ',RequiredPackage.IDAsString,' "',OtherStateFile,'" (',
                  FileAgeToStr(FileAgeCached(OtherStateFile)),')'
                ,' is newer than state file ',GetOwnerID,'(',FileAgeToStr(StateFileAge),')');
              Note+='State file of used package is newer than state file:'+LineEnding
                +'  Used package '+RequiredPackage.IDAsString+', file="'+OtherStateFile+'", '
                +' age='+FileAgeToStr(FileAgeCached(OtherStateFile))+LineEnding
                +'  package '+GetOwnerID+', age='+FileAgeToStr(StateFileAge)+LineEnding;
              Result:=mrYes;
              exit;
            end;
          end;
        end;
      end;
    end;
    Dependency:=Dependency.NextRequiresDependency;
  end;
  Result:=mrNo;
end;

function TLazPackageGraph.CheckIfPackageNeedsCompilation(APackage: TLazPackage;
  SkipDesignTimePackages, GroupCompile: boolean; out NeedBuildAllFlag: boolean;
  var Note: string): TModalResult;
var
  OutputDir: String;
  NewOutputDir: String;
  ConfigChanged: boolean;
  DependenciesChanged: boolean;
  DefResult: TModalResult;
  OldNeedBuildAllFlag: Boolean;
  OldOverride: String;
begin
  Result:=mrYes;
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.CheckIfPackageNeedsCompilation A ',APackage.IDAsString);
  {$ENDIF}
  NeedBuildAllFlag:=false;

  if APackage.AutoUpdate=pupManually then
    exit(mrNo);

  // check the current output directory
  Result:=CheckIfCurPkgOutDirNeedsCompile(APackage,
             true,SkipDesignTimePackages,GroupCompile,
             NeedBuildAllFlag,ConfigChanged,DependenciesChanged,Note);
  if Result=mrNo then begin
    // the current output is valid
    exit;
  end;

  // the current output directory needs compilation
  if APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride='' then
  begin
    // the last compile was put to the normal/default output directory
    OutputDir:=APackage.GetOutputDirectory(false);
    if OutputDirectoryIsWritable(APackage,OutputDir,false) then
    begin
      // the normal output directory is writable => keep using it
      exit;
    end;
    debugln(['Hint: (lazarus) normal output directory of package ',APackage.IDAsString,' is not writable: "',OutputDir,'"']);
    // the normal output directory is not writable
    // => try the fallback directory
    NewOutputDir:=GetFallbackOutputDir(APackage);
    if (NewOutputDir=OutputDir) or (NewOutputDir='') then begin
      Note+='Normal output directory is not writable. There is no fallback.'+LineEnding;
      exit;
    end;
    Note+='Normal output directory is not writable, switching to fallback.'+LineEnding;
    APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride:=NewOutputDir;
    Result:=CheckIfCurPkgOutDirNeedsCompile(APackage,
               true,SkipDesignTimePackages,GroupCompile,
               NeedBuildAllFlag,ConfigChanged,DependenciesChanged,Note);
  end else begin
    // the last compile was put to the fallback output directory
    if not ConfigChanged then begin
      // some source files have changed, not the compiler parameters
      // => keep using the fallback directory
      exit;
    end;
    if DependenciesChanged then begin
      // dependencies have changed
      // => switching to the not writable default output directory is not possible
      // => keep using the fallback directory
      exit;
    end;
    // maybe the user switched the settings back to default
    // => try using the default output directory
    OldOverride:=APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride;
    APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride:='';
    OldNeedBuildAllFlag:=NeedBuildAllFlag;
    DefResult:=CheckIfCurPkgOutDirNeedsCompile(APackage,
               true,SkipDesignTimePackages,GroupCompile,
               NeedBuildAllFlag,ConfigChanged,DependenciesChanged,Note);
    if DefResult=mrNo then begin
      // switching back to the not writable output directory requires no compile
      debugln(['Hint: (lazarus) switching back to the normal output directory: "',APackage.GetOutputDirectory,'" Package ',APackage.IDAsString]);
      Note+='Switching back to not writable output directory.'+LineEnding;
      exit(mrNo);
    end;
    // neither the default nor the fallback is valid
    // => switch back to the fallback
    APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride:=OldOverride;
    NeedBuildAllFlag:=OldNeedBuildAllFlag;
  end;
end;

function TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile(
  APackage: TLazPackage; CheckDependencies, SkipDesignTimePackages,
  GroupCompile: boolean; out NeedBuildAllFlag, ConfigChanged,
  DependenciesChanged: boolean; var Note: string): TModalResult;
// returns: mrYes, mrNo, mrCancel, mrAbort
var
  StateFilename: String;
  StateFileAge: Integer;
  i: Integer;
  CurFile: TPkgFile;
  LastParams: String;
  LastPaths: TStringList;
  CurPaths: TStringList;
  OldValue: string;
  NewValue: string;
  o: TPkgOutputDir;
  Stats: PPkgLastCompileStats;
  SrcPPUFile: String;
  AFilename: String;
  CompilerFilename, CompilerParams, SrcFilename: string;
  LFMFilename: String;
  ReducedParams: String;
  ReducedLastParams: String;
begin
  Result:=mrYes;
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile A ',APackage.IDAsString);
  {$ENDIF}
  NeedBuildAllFlag:=false;
  ConfigChanged:=false;
  DependenciesChanged:=false;
  
  if APackage.AutoUpdate=pupManually then exit(mrNo);

  SrcFilename:=APackage.GetSrcFilename;
  CompilerFilename:=APackage.GetCompilerFilename;
  // Note: use absolute paths, because some external tools resolve symlinked directories
  CompilerParams:=GetPackageCompilerParams(APackage);

  o:=APackage.GetOutputDirType;
  Stats:=@APackage.LastCompile[o];
  //debugln(['TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile  Last="',ExtractCompilerParamsForBuildAll(APackage.LastCompilerParams),'" Now="',ExtractCompilerParamsForBuildAll(CompilerParams),'"']);

  // check state file
  StateFilename:=APackage.GetStateFilename;
  Result:=LoadPackageCompiledState(APackage,false,true);
  if Result<>mrOk then exit; // read error and user aborted
  if not Stats^.StateFileLoaded then begin
    // package was not compiled via Lazarus nor via Makefile/fpmake
    DebugLn('Hint: (lazarus) Missing state file of ',APackage.IDAsString,': ',StateFilename);
    Note+='Missing state file "'+StateFilename+'".'+LineEnding;
    NeedBuildAllFlag:=true;
    ConfigChanged:=true;
    exit(mrYes);
  end;

  // check if build all (-B) is needed
  if (Stats^.CompilerFilename<>CompilerFilename)
  or (ExtractFPCParamsForBuildAll(Stats^.Params)
      <>ExtractFPCParamsForBuildAll(CompilerParams))
  or ((Stats^.CompilerFileDate>0)
      and FileExistsCached(CompilerFilename)
      and (FileAgeCached(CompilerFilename)<>Stats^.CompilerFileDate))
  then begin
    NeedBuildAllFlag:=true;
    ConfigChanged:=true;
  end;

  if GroupCompile and (lpfNeedGroupCompile in APackage.Flags) then begin
    //debugln(['TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile dependencies will be rebuilt']);
    Note+='Dependencies will be rebuilt';
    DependenciesChanged:=true;
    exit(mrYes);
  end;

  StateFileAge:=FileAgeUTF8(StateFilename);

  // check compiler and params
  LastParams:=APackage.GetLastCompilerParams(o);
  if Stats^.ViaMakefile then begin
    // the package was compiled via Makefile/fpmake
    if ConsoleVerbosity>=1 then
      debugln(['Hint: (lazarus) package ',APackage.IDAsString,' was compiled via "make" with parameters "',LastParams,'"']);

    CurPaths:=nil;
    LastPaths:=nil;
    try
      CurPaths:=ExtractMakefileCompiledParams(CompilerParams,true);
      LastPaths:=ExtractMakefileCompiledParams(LastParams,true);

      //debugln(['TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile CompilerParams="',CompilerParams,'" UnitPaths="',CurPaths.Values['UnitPath'],'"']);
      // compare custom options
      OldValue:=LastPaths.Values['Reduced'];
      NewValue:=CurPaths.Values['Reduced'];
      if NewValue<>OldValue then begin
        DebugLn('Hint: (lazarus) Compiler custom params changed for ',APackage.IDAsString);
        DebugLn('  Old="',OldValue,'"');
        DebugLn('  Now="',NewValue,'"');
        DebugLn('  State file="',Stats^.StateFileName,'"');
        Note+='Compiler custom parameters changed:'+LineEnding
           +'  Old="'+OldValue+'"'+LineEnding
           +'  Now="'+NewValue+'"'+LineEnding
           +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
        ConfigChanged:=true;
        exit(mrYes);
      end;
      // compare unit paths
      OldValue:=TrimSearchPath(LastPaths.Values['UnitPath'],APackage.Directory,true);
      NewValue:=TrimSearchPath(CurPaths.Values['UnitPath'],APackage.Directory,true);
      if NewValue<>OldValue then begin
        DebugLn('Hint: (lazarus) Compiler unit paths changed for ',APackage.IDAsString);
        DebugLn('  Old="',OldValue,'"');
        DebugLn('  Now="',NewValue,'"');
        DebugLn('  State file="',Stats^.StateFileName,'"');
        Note+='Compiler unit paths changed:'+LineEnding
           +'  Old="'+OldValue+'"'+LineEnding
           +'  Now="'+NewValue+'"'+LineEnding
           +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
        ConfigChanged:=true;
        exit(mrYes);
      end;
      // compare include paths
      OldValue:=TrimSearchPath(LastPaths.Values['IncPath'],APackage.Directory,true);
      NewValue:=TrimSearchPath(CurPaths.Values['IncPath'],APackage.Directory,true);
      if NewValue<>OldValue then begin
        DebugLn('Hint: (lazarus) Compiler include paths changed for ',APackage.IDAsString);
        DebugLn('  Old="',OldValue,'"');
        DebugLn('  Now="',NewValue,'"');
        DebugLn('  State file="',Stats^.StateFileName,'"');
        Note+='Compiler include paths changed:'+LineEnding
           +'  Old="'+OldValue+'"'+LineEnding
           +'  Now="'+NewValue+'"'+LineEnding
           +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
        ConfigChanged:=true;
        exit(mrYes);
      end;
    finally
      CurPaths.Free;
      LastPaths.Free;
    end;
  end else begin
    ReducedParams:=RemoveFPCVerbosityParams(CompilerParams);
    ReducedLastParams:=RemoveFPCVerbosityParams(LastParams);
    if ReducedParams<>ReducedLastParams then begin
      // package was compiled by Lazarus
      DebugLn('Hint: (lazarus) Compiler params changed for ',APackage.IDAsString);
      DebugLn('  Old="',dbgstr(ReducedLastParams),'"');
      DebugLn('  Now="',dbgstr(ReducedParams),'"');
      DebugLn('  State file="',Stats^.StateFileName,'"');
      Note+='Compiler parameters changed:'+LineEnding
         +'  Old="'+dbgstr(ReducedLastParams)+'"'+LineEnding
         +'  Now="'+dbgstr(ReducedParams)+'"'+LineEnding
         +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
      ConfigChanged:=true;
      exit(mrYes);
    end;
  end;
  if (not Stats^.ViaMakefile)
  and (CompilerFilename<>Stats^.CompilerFilename) then begin
    DebugLn('Hint: (lazarus) Compiler filename changed for ',APackage.IDAsString);
    DebugLn('  Old="',Stats^.CompilerFilename,'"');
    DebugLn('  Now="',CompilerFilename,'"');
    DebugLn('  State file="',Stats^.StateFileName,'"');
    Note+='Compiler filename changed:'+LineEnding
       +'  Old="'+Stats^.CompilerFilename+'"'+LineEnding
       +'  Now="'+CompilerFilename+'"'+LineEnding
       +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
    exit(mrYes);
  end;
  if not FileExistsCached(CompilerFilename) then begin
    DebugLn('Hint: (lazarus) Compiler filename not found for ',APackage.IDAsString);
    DebugLn('  File="',CompilerFilename,'"');
    DebugLn('  State file="',Stats^.StateFileName,'"');
    Note+='Compiler file "'+CompilerFilename+'" not found.'+LineEnding
       +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
    exit(mrYes);
  end;
  if (not Stats^.ViaMakefile)
  and (FileAgeCached(CompilerFilename)<>Stats^.CompilerFileDate) then begin
    DebugLn('Hint: (lazarus) Compiler file changed for ',APackage.IDAsString);
    DebugLn('  File="',CompilerFilename,'"');
    DebugLn('  State file="',Stats^.StateFileName,'"');
    Note+='Compiler file "'+CompilerFilename+'" changed:'+LineEnding
      +'  Old='+FileAgeToStr(Stats^.CompilerFileDate)+LineEnding
      +'  Now='+FileAgeToStr(FileAgeCached(CompilerFilename))+LineEnding
      +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
    exit(mrYes);
  end;

  // check main source file
  if (SrcFilename<>'') then
  begin
    if not FileExistsCached(SrcFilename) then begin
      DebugLn('Hint: (lazarus) source file missing of ',APackage.IDAsString,': ',SrcFilename);
      Note+='Source file "'+SrcFilename+'" missing.'+LineEnding;
      exit(mrYes);
    end;
    if StateFileAge<FileAgeCached(SrcFilename) then begin
      DebugLn('Hint: (lazarus) source file outdated of ',APackage.IDAsString,': ',SrcFilename);
      Note+='Source file "'+SrcFilename+'" outdated:'+LineEnding
        +'  Source file age='+FileAgeToStr(FileAgeCached(SrcFilename))+LineEnding
        +'  State file="'+Stats^.StateFileName+'"'+LineEnding
        +'  State file age='+FileAgeToStr(StateFileAge)+LineEnding;
      exit(mrYes);
    end;
    // check main source ppu file
    if Stats^.MainPPUExists then begin
      SrcPPUFile:=APackage.GetSrcPPUFilename;
      if not FileExistsCached(SrcPPUFile) then begin
        DebugLn('Hint: (lazarus) main ppu file missing of ',APackage.IDAsString,': ',SrcPPUFile);
        Note+='Main ppu file "'+SrcPPUFile+'" missing.'+LineEnding;
        exit(mrYes);
      end;
    end;
  end;


  //debugln(['TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile ',APackage.Name,' Last="',APackage.LastCompilerParams,'" Now="',CompilerParams,'"']);

  // compiler and parameters are the same
  // quick compile is possible
  NeedBuildAllFlag:=false;

  if not Stats^.Complete then begin
    DebugLn('Hint: (lazarus) Last compile was incomplete for ',APackage.IDAsString);
    DebugLn('  State file="',Stats^.StateFileName,'"');
    Note+='Last compile was incomplete.'+LineEnding
       +'  State file="'+Stats^.StateFileName+'"'+LineEnding;
    exit(mrYes);
  end;

  if CheckDependencies then begin
    // check all required packages
    Result:=CheckCompileNeedDueToDependencies(APackage,
          APackage.FirstRequiredDependency,SkipDesignTimePackages,StateFileAge,
          Note);
    if Result<>mrNo then begin
      DependenciesChanged:=true;
      exit(mrYes);
    end;
  end;

  // check package files
  if StateFileAge<FileAgeCached(APackage.Filename) then begin
    DebugLn('Hint: (lazarus) State file older than lpk ',APackage.IDAsString);
    DebugLn('  State file="',Stats^.StateFileName,'"');
    Note+='State file older than lpk:'+LineEnding
      +'  State file age='+FileAgeToStr(StateFileAge)+LineEnding
      +'  State file="'+Stats^.StateFileName+'"'+LineEnding
      +'  LPK age='+FileAgeToStr(FileAgeCached(APackage.Filename))+LineEnding;
    exit(mrYes);
  end;
  for i:=0 to APackage.FileCount-1 do begin
    CurFile:=APackage.Files[i];
    //debugln(['TLazPackageGraph.CheckIfPackageNeedsCompilation  CurFile.Filename="',CurFile.Filename,'" Exists=',FileExistsUTF8(CurFile.Filename),' NewerThanStateFile=',StateFileAge<FileAgeCached(CurFile.Filename)]);
    AFilename:=CurFile.GetFullFilename;
    if FileExistsCached(AFilename)
    and (StateFileAge<FileAgeCached(AFilename)) then begin
      DebugLn('Hint: (lazarus) Source file has changed ',APackage.IDAsString,' ',CurFile.Filename);
      DebugLn('  State file="',Stats^.StateFileName,'"');
      Note+='State file older than source "'+AFilename+'"'+LineEnding
        +'  State file age='+FileAgeToStr(StateFileAge)+LineEnding
        +'  State file="'+Stats^.StateFileName+'"'+LineEnding
        +'  Src file age='+FileAgeToStr(FileAgeCached(AFilename))+LineEnding;
      exit(mrYes);
    end;
    if FilenameIsPascalUnit(AFilename) then begin
      LFMFilename:=ChangeFileExt(AFilename,'.lfm');
      if FileExistsCached(LFMFilename)
      and (StateFileAge<FileAgeCached(LFMFilename)) then begin
        DebugLn('Hint: (lazarus) LFM has changed ',APackage.IDAsString,' ',LFMFilename);
        DebugLn('  State file="',Stats^.StateFileName,'"');
        Note+='State file older than resource "'+LFMFilename+'"'+LineEnding
          +'  State file age='+FileAgeToStr(StateFileAge)+LineEnding
          +'  State file="'+Stats^.StateFileName+'"'+LineEnding
          +'  Resource file age='+FileAgeToStr(FileAgeCached(LFMFilename))+LineEnding;
        exit(mrYes);
      end;
    end;
  end;
  
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.CheckIfCurPkgOutDirNeedsCompile END ',APackage.IDAsString);
  {$ENDIF}
  Result:=mrNo;
end;

procedure TLazPackageGraph.InvalidateStateFile(APackage: TLazPackage);
begin
  APackage.LastCompile[APackage.GetOutputDirType].StateFileLoaded:=false
end;

function TLazPackageGraph.CompileRequiredPackages(APackage: TLazPackage;
  FirstDependency: TPkgDependency; SkipDesignTimePackages: boolean;
  Policy: TPackageUpdatePolicy): TModalResult;
var
  BuildItems: TObjectList;

  function PkgToBuildItem(Pkg: TLazPackage): TLazPkgGraphBuildItem;
  var
    i: Integer;
  begin
    for i:=0 to BuildItems.Count-1 do begin
      Result:=TLazPkgGraphBuildItem(BuildItems[i]);
      if Result.LazPackage=Pkg then exit;
    end;
    Result:=nil;
  end;

var
  PkgList: TFPList;
  FPMakeList: TFPList;
  i: Integer;
  Flags: TPkgCompileFlags;
  ReqFlags: TPkgIntfRequiredFlags;
  CurPkg: TLazPackage;
  BuildItem: TLazPkgGraphBuildItem;
  j: Integer;
  aDependency: TPkgDependency;
  RequiredBuildItem: TLazPkgGraphBuildItem;
  Tool1: TAbstractExternalTool;
  Tool2: TAbstractExternalTool;
  ToolGroup: TExternalToolGroup;
  FilesChanged: boolean;
begin
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.CompileRequiredPackages A MinPolicy=',dbgs(Policy),' SkipDesignTimePackages=',SkipDesignTimePackages);
  {$ENDIF}
  ReqFlags:=[pirCompileOrder];
  if SkipDesignTimePackages then
    Include(ReqFlags,pirSkipDesignTimeOnly);
  GetAllRequiredPackages(APackage,FirstDependency,PkgList,FPMakeList,ReqFlags,Policy);
  if (PkgList<>nil) or (FPMakeList<>nil) then begin
    //DebugLn('TLazPackageGraph.CompileRequiredPackages B Count=',IntToStr(PkgList.Count));
    BuildItems:=nil;
    ToolGroup:=nil;
    BeginUpdate(false);
    try
      if (PkgList<>nil) then begin
        for i:=PkgList.Count-1 downto 0 do begin
          CurPkg:=TLazPackage(PkgList[i]);
          if SkipDesignTimePackages and (CurPkg.PackageType=lptDesignTime) then
            PkgList.Delete(i);
          CurPkg.Flags:=CurPkg.Flags-[lpfNeedGroupCompile];
        end;
        if Assigned(OnBeforeCompilePackages) then
        begin
          Result:=OnBeforeCompilePackages(PkgList);
          if Result<>mrOk then exit;
        end;

        // prepare output directories, basic checks
        Flags:=[pcfDoNotCompileDependencies,pcfDoNotSaveEditorFiles,pcfGroupCompile];
        if SkipDesignTimePackages then
          Include(Flags,pcfSkipDesignTimePackages);
        if Policy=pupAsNeeded then
          Include(Flags,pcfOnlyIfNeeded)
        else
          Include(Flags,pcfCleanCompile);
        repeat
          BuildItems:=TObjectList.Create(true);
          for i:=0 to PkgList.Count-1 do begin
            CurPkg:=TLazPackage(PkgList[i]);
            BuildItem:=TLazPkgGraphBuildItem.Create(nil);
            BuildItem.LazPackage:=CurPkg;
            BuildItems.Add(BuildItem);
            Result:=CompilePackage(CurPkg,Flags,false,BuildItem);
            if Result<>mrOk then exit;

            if (BuildItem<>nil) and (not (lpfNeedGroupCompile in CurPkg.Flags))
            then begin
              // package is up-to-date
              //debugln(['TLazPackageGraph.CompileRequiredPackages no build needed: pkg=',CurPkg.Name]);
              BuildItems.Remove(BuildItem);
            end;
          end;

          if FirstDependency<>nil then
          begin
            if not OnCheckInterPkgFiles(FirstDependency.Owner,PkgList,FilesChanged)
            then exit(mrCancel);
            if FilesChanged then
              FreeAndNil(BuildItems);
          end;
        until BuildItems<>nil;

        // add tool dependencies
        for i:=0 to BuildItems.Count-1 do begin
          BuildItem:=TLazPkgGraphBuildItem(BuildItems[i]);
          CurPkg:=BuildItem.LazPackage;
          if BuildItem.Count=0 then continue;

          // add tools to ToolGroup
          if ToolGroup=nil then
            ToolGroup:=TExternalToolGroup.Create(nil);
          for j:=0 to BuildItem.Count-1 do
            BuildItem[j].Group:=ToolGroup;

          // estimate load
          for j:=0 to BuildItem.Count-1 do begin
            Tool1:=BuildItem[j];
            if Tool1.Data is TLazPkgGraphExtToolData then begin
              Tool1.EstimatedLoad:=EstimateCompileLoad(CurPkg);
              //debugln(['TLazPackageGraph.CompileRequiredPackages ',CurPkg.Name,' EstimatedLoad=',Tool1.EstimatedLoad]);
            end;
          end;

          // add dependencies between tools of this package (execute before, compile, after)
          for j:=1 to BuildItem.Count-1 do begin
            Tool1:=BuildItem[j-1];
            Tool2:=BuildItem[j];
            Tool2.AddExecuteBefore(Tool1);
          end;

          // add dependencies between packages
          aDependency:=CurPkg.FirstRequiredDependency;
          // ToDo: Add fpmake-dependencies!
          while aDependency<>nil do begin
            RequiredBuildItem:=PkgToBuildItem(aDependency.RequiredPackage);
            aDependency:=aDependency.NextRequiresDependency;
            if RequiredBuildItem=nil then continue;
            if not (lpfNeedGroupCompile in RequiredBuildItem.LazPackage.Flags) then
              continue;
            Tool1:=BuildItem.GetFirstOrDummy;
            Tool2:=RequiredBuildItem.GetLastOrDummy;
            Tool1.AddExecuteBefore(Tool2);
          end;
        end;
      end;

      if Assigned(FppkgInterface) and (FppkgInterface.InstallFPMakeDependencies) and Assigned(FPMakeList) then begin
        Flags:=[pcfDoNotCompileDependencies,pcfDoNotSaveEditorFiles,pcfGroupCompile];
        if SkipDesignTimePackages then
          Include(Flags,pcfSkipDesignTimePackages);
        if Policy=pupAsNeeded then
          Include(Flags,pcfOnlyIfNeeded)
        else
          Include(Flags,pcfCleanCompile);

        BuildItems:=TObjectList.Create(true);
        for i:=0 to FPMakeList.Count-1 do begin
          aDependency:=TPkgDependency(FPMakeList[i]);
          BuildItem:=TLazPkgGraphBuildItem.Create(nil);
          BuildItems.Add(BuildItem);
          Result:=CompilePackageUsingFPMake(aDependency.PackageName,Flags,false,BuildItem);
          if Result<>mrOk then exit;
        end;

        // add tool dependencies
        for i:=0 to BuildItems.Count-1 do begin
          BuildItem:=TLazPkgGraphBuildItem(BuildItems[i]);

          if BuildItem.Count=0 then continue;

          // Make sure that all FPMake-buildtools are executed after each other
          // (It is not safe to run them simultaneously)
          if i > 0 then
            BuildItem.GetFirstOrDummy.AddExecuteBefore(TLazPkgGraphBuildItem(BuildItems[i-1]).GetFirstOrDummy);

          // add tools to ToolGroup
          if ToolGroup=nil then
            ToolGroup:=TExternalToolGroup.Create(nil);
          for j:=0 to BuildItem.Count-1 do
            BuildItem[j].Group:=ToolGroup;

          // add dependencies between tools of this package
          for j:=1 to BuildItem.Count-1 do begin
            Tool1:=BuildItem[j-1];
            Tool2:=BuildItem[j];
            Tool2.AddExecuteBefore(Tool1);
          end;
        end;
      end;

      if ToolGroup=nil then exit(mrOk);

      // execute
      ToolGroup.Execute;
      ToolGroup.WaitForExit;
      if ToolGroup.ErrorMessage<>'' then begin
        debugln(['Error: (lazarus) [TLazPackageGraph.CompileRequiredPackages] "',ToolGroup.ErrorMessage,'"']);
        exit(mrCancel);
      end;
    finally
      FreeAndNil(ToolGroup);
      FreeAndNil(BuildItems);
      FreeAndNil(PkgList);
      FreeAndNil(FPMakeList);
      EndUpdate;
    end;
  end;
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.CompileRequiredPackages END ');
  {$ENDIF}
  Result:=mrOk;
end;

procedure TLazPackageGraph.SetFlagDependenciesNeedBuild(Pkg: TLazPackage);
// set flag lpfNeedGroupCompile in all dependent packages
var
  ADependency: TPkgDependency;
begin
  if Pkg=nil then exit;
  if lpfNeedGroupCompile in Pkg.Flags then exit;
  Pkg.Flags:=Pkg.Flags+[lpfNeedGroupCompile];
  ADependency:=Pkg.FirstUsedByDependency;
  while ADependency<>nil do begin
    if ADependency.Owner is TLazPackage then
      SetFlagDependenciesNeedBuild(TLazPackage(ADependency.Owner));
    ADependency:=ADependency.NextUsedByDependency;
  end;
end;

function TLazPackageGraph.CompilePackage(APackage: TLazPackage;
  Flags: TPkgCompileFlags; ShowAbort: boolean; BuildItem: TLazPkgGraphBuildItem
  ): TModalResult;

  function GetIgnoreIdentifier: string;
  begin
    Result:='install_package_compile_failed:'+APackage.Filename;
  end;

var
  PkgCompileTool: TAbstractExternalTool;
  FPCParser: TFPCParser;
  CompilerFilename: String;
  EffectiveCompilerParams: String;
  CompilePolicy: TPackageUpdatePolicy;
  NeedBuildAllFlag: Boolean;
  CompilerParams: String;
  Note: String;
  WorkingDir: String;
  ToolTitle: String;
  ExtToolData: TLazPkgGraphExtToolData;
  BuildMethod: TBuildMethod;
begin
  Result:=mrCancel;

  //DebugLn('TLazPackageGraph.CompilePackage A ',APackage.IDAsString,' Flags=',PkgCompileFlagsToString(Flags));

  if APackage.IsVirtual then begin
    DebugLn(['Error: (lazarus) compile failed because virtual: ',APackage.Filename]);
    exit;
  end;

  BeginUpdate(false);
  try
    // automatically compile required packages
    if not (pcfDoNotCompileDependencies in Flags) then begin
      if pcfCompileDependenciesClean in Flags then
        CompilePolicy:=pupOnRebuildingAll
      else
        CompilePolicy:=pupAsNeeded;
      Result:=CompileRequiredPackages(APackage,nil,
                            pcfSkipDesignTimePackages in Flags,CompilePolicy);
      if Result<>mrOk then begin
        DebugLn(['Error: (lazarus) Compile required packages failed: ',APackage.IDAsString]);
        exit;
      end;
    end;

    if not APackage.CompilerOptions.HasCommands then begin
      // package provides no compilation
      Result:=mrOk;
      exit;
    end;

    // check if compilation is needed and if a clean build is needed
    NeedBuildAllFlag:=false;
    Note:='';
    Result:=CheckIfPackageNeedsCompilation(APackage,
                          pcfSkipDesignTimePackages in Flags,
                          pcfGroupCompile in Flags,
                          NeedBuildAllFlag,Note);
    if Note<>'' then
      Note:='Compile reason: '+Note;
    if (pcfOnlyIfNeeded in Flags) then begin
      if Result=mrNo then begin
        //DebugLn(['TLazPackageGraph.CompilePackage ',APackage.IDAsString,' does not need compilation.']);
        Result:=mrOk;
        exit;
      end;
      if Result<>mrYes then begin
        DebugLn(['Error: (lazarus) [CheckIfPackageNeedsCompilation] failed: ',APackage.IDAsString]);
        exit;
      end;
    end;

    try
      if (BuildItem=nil) and (LazarusIDE<>nil) then
        LazarusIDE.MainBarSubTitle:=APackage.Name;

      if pcfGroupCompile in Flags then
        SetFlagDependenciesNeedBuild(APackage);

      // auto increase version
      // ToDo

      Result:=PreparePackageOutputDirectory(APackage,pcfCleanCompile in Flags);
      if Result<>mrOk then begin
        DebugLn('Error: (lazarus) [TLazPackageGraph.CompilePackage] PreparePackageOutputDirectory failed: ',APackage.IDAsString);
        exit;
      end;

      // create package main source file
      Result:=SavePackageMainSource(APackage,Flags,ShowAbort);
      if Result<>mrOk then begin
        DebugLn('Error: (lazarus) [TLazPackageGraph.CompilePackage] SavePackageMainSource failed: ',APackage.IDAsString);
        exit;
      end;

      // check ambiguous units
      Result:=CheckAmbiguousPackageUnits(APackage);
      if Result<>mrOk then begin
        DebugLn('Error: (lazarus) [TLazPackageGraph.CompilePackage] CheckAmbiguousPackageUnits failed: ',APackage.IDAsString);
        exit;
      end;

      // create Makefile
      if ((pcfCreateMakefile in Flags)
      or (APackage.CompilerOptions.CreateMakefileOnBuild)) then begin
        Result:=WriteMakeFile(APackage);
        if Result<>mrOk then begin
          DebugLn('Error: (lazarus) [TLazPackageGraph.CompilePackage] DoWriteMakefile failed: ',APackage.IDAsString);
          exit;
        end;
      end;

      // create fpmake.pp
      if ((pcfCreateFpmakeFile in Flags)
      or (APackage.GetActiveBuildMethod = bmFPMake)
      or ((APackage.CompilerOptions.CreateMakefileOnBuild) and (APackage.BuildMethod in [bmBoth, bmFPMake]) and Assigned(FppkgInterface))) then begin
        Result:=WriteFpmake(APackage);
        if Result<>mrOk then begin
          DebugLn('Error: (lazarus) [TLazPackageGraph.CompilePackage] DoWriteFpmakeFile failed: ',APackage.IDAsString);
          exit;
        end;
      end;

      // run compilation tool 'Before'
      if not (pcfDoNotCompilePackage in Flags) then begin
        WorkingDir:=APackage.Directory;
        ToolTitle:='Package '+APackage.IDAsString+': '+lisExecutingCommandBefore;
        if BuildItem<>nil then
        begin
          // run later
          BuildItem.Add(APackage.CompilerOptions.ExecuteBefore.CreateExtTool(
                              WorkingDir,ToolTitle,Note));
        end else begin
          // run now
          Result:=APackage.CompilerOptions.ExecuteBefore.Execute(WorkingDir,
            ToolTitle,Note);
          if Result<>mrOk then begin
            DebugLn(['Error: (lazarus) [TLazPackageGraph.CompilePackage] ExecuteBefore failed: ',APackage.IDAsString]);
            exit;
          end;
        end;
      end;

      // create external tool to run the compiler
      //DebugLn('TLazPackageGraph.CompilePackage WorkingDir="',APackage.Directory,'"');

      if (not APackage.CompilerOptions.SkipCompiler)
      and (not (pcfDoNotCompilePackage in Flags)) then begin
        BuildMethod:=APackage.GetActiveBuildMethod;
        if BuildMethod=bmLazarus then begin
          CompilerFilename:=APackage.GetCompilerFilename;

          // change compiler parameters for compiling clean
          CompilerParams:=GetPackageCompilerParams(APackage);
          EffectiveCompilerParams:=CompilerParams;
          if (pcfCleanCompile in Flags) or NeedBuildAllFlag then begin
            if EffectiveCompilerParams<>'' then
              EffectiveCompilerParams:='-B '+EffectiveCompilerParams
            else
              EffectiveCompilerParams:='-B';
          end;

          WarnSuspiciousCompilerOptions('Compile checks','package '+APackage.IDAsString+':',CompilerParams);
        end else begin
          CompilerFilename:='fppkg';
          EffectiveCompilerParams:='install --skipbroken --broken';
          // Do not recompile all broken fppkg packages on each package that is
          // installed, but run 'fppkg fixbroken' once.
          FHasCompiledFpmakePackages := True;
        end;

        ExtToolData:=TLazPkgGraphExtToolData.Create(IDEToolCompilePackage,
          APackage.Name,APackage.Filename);

        PkgCompileTool:=ExternalToolList.Add(Format(lisPkgMangCompilePackage, [APackage.IDAsString]));
        PkgCompileTool.Data:=ExtToolData;
        PkgCompileTool.FreeData:=true;
        if BuildItem<>nil then
          BuildItem.Add(PkgCompileTool)
        else
          PkgCompileTool.Reference(Self,Classname);
        try
          FPCParser:=TFPCParser(PkgCompileTool.AddParsers(SubToolFPC));
          //debugln(['TLazPackageGraph.CompilePackage ',APackage.Name,' ',APackage.CompilerOptions.ShowHintsForUnusedUnitsInMainSrc,' ',APackage.MainUnit.Filename]);
          if (APackage.MainUnit<>nil)
          and (not APackage.CompilerOptions.ShowHintsForUnusedUnitsInMainSrc) then
            FPCParser.FilesToIgnoreUnitNotUsed.Add(APackage.MainUnit.Filename);
          FPCParser.HideHintsSenderNotUsed:=not APackage.CompilerOptions.ShowHintsForSenderNotUsed;
          FPCParser.HideHintsUnitNotUsedInMainSource:=not APackage.CompilerOptions.ShowHintsForUnusedUnitsInMainSrc;
          PkgCompileTool.AddParsers(SubToolMake);
          PkgCompileTool.Process.CurrentDirectory:=APackage.Directory;
          PkgCompileTool.Process.Executable:=CompilerFilename;
          PkgCompileTool.CmdLineParams:=EffectiveCompilerParams;
          PkgCompileTool.Hint:=Note;
          ExtToolData.Pkg:=APackage;
          ExtToolData.SrcPPUFilename:=APackage.GetSrcPPUFilename;
          ExtToolData.CompilerFilename:=CompilerFilename;
          ExtToolData.CompilerParams:=CompilerParams;
          PkgCompileTool.AddHandlerOnStopped(@OnExtToolBuildStopped);
          if BuildItem<>nil then
          begin
            // run later
          end else begin
            // run now
            PkgCompileTool.Execute;
            //debugln(['TLazPackageGraph.CompilePackage BEFORE WaitForExit: ',APackage.IDAsString]);
            PkgCompileTool.WaitForExit;
            //debugln(['TLazPackageGraph.CompilePackage AFTER WaitForExit: ',APackage.IDAsString,' ExtToolData.ErrorMessage=',ExtToolData.ErrorMessage]);
            if ExtToolData.ErrorMessage<>'' then
              exit(mrCancel);
          end;
        finally
          if BuildItem=nil then
            PkgCompileTool.Release(Self);
        end;
      end;

      if not (pcfDoNotCompilePackage in Flags) then begin
        if FHasCompiledFpmakePackages and (BuildItem = nil) then begin
          // Make sure all dependees of changed FPMake-packages are
          // recompiled

          PkgCompileTool := ExternalToolList.Add('Recompile and install broken Fppkg packages');
          PkgCompileTool.Reference(Self,Classname);

          FPCParser:=TFPCParser(PkgCompileTool.AddParsers(SubToolFPC));
          FPCParser.HideHintsSenderNotUsed:=not APackage.CompilerOptions.ShowHintsForSenderNotUsed;
          FPCParser.HideHintsUnitNotUsedInMainSource:=not APackage.CompilerOptions.ShowHintsForUnusedUnitsInMainSrc;
          PkgCompileTool.Process.CurrentDirectory:=APackage.Directory;
          PkgCompileTool.Process.Executable:='fppkg';
          PkgCompileTool.CmdLineParams:='fixbroken';
          PkgCompileTool.Hint:='Check for Fppkg packages that depend on just installed packages and recompile them';

          PkgCompileTool.Execute();
          PkgCompileTool.WaitForExit;
          if PkgCompileTool.ErrorMessage<>'' then begin
            DebugLn(['Error: (lazarus) [TLazPackageGraph.CompilePackage] Fppkg FixBroken failed']);
            // Note: messages window already contains error message
            exit(mrCancel);
          end;
        end;

        // run compilation tool 'After'
        WorkingDir:=APackage.Directory;
        ToolTitle:='Package '+APackage.IDAsString+': '+lisExecutingCommandAfter;
        if BuildItem<>nil then
        begin
          // run later
          BuildItem.Add(APackage.CompilerOptions.ExecuteAfter.CreateExtTool(
                              WorkingDir,ToolTitle,Note));
        end else begin
          // run now
          Result:=APackage.CompilerOptions.ExecuteAfter.Execute(WorkingDir,
                                       ToolTitle,Note);
          if Result<>mrOk then begin
            DebugLn(['Error: (lazarus) [TLazPackageGraph.CompilePackage] ExecuteAfter failed: ',APackage.IDAsString]);
            // Note: messages window already contains error message
            exit;
          end;
        end;
      end;
      Result:=mrOk;
    finally
      if (BuildItem=nil) and (LazarusIDE<>nil) then
        LazarusIDE.MainBarSubTitle:='';
    end;
  finally
    PackageGraph.EndUpdate;
  end;
end;

function TLazPackageGraph.CompilePackageUsingFPMake(APackageName: string; Flags: TPkgCompileFlags;
  ShowAbort: boolean; BuildItem: TLazPkgGraphBuildItem): TModalResult;

var
  PkgCompileTool: TAbstractExternalTool;
  CompilerFilename: String;
  EffectiveCompilerParams: String;
begin
  Result:=mrCancel;
  if ShowAbort then ;

  //DebugLn('TLazPackageGraph.CompilePackageAsFPMake A ',APackageName,' Flags=',PkgCompileFlagsToString(Flags));
  BeginUpdate(false);
  try
    try
      if (BuildItem=nil) and (LazarusIDE<>nil) then
        LazarusIDE.MainBarSubTitle:=APackageName;

      // create external tool to run the compiler
      //DebugLn('TLazPackageGraph.CompilePackageFPMake');

      if (not (pcfDoNotCompilePackage in Flags)) then begin
        CompilerFilename:='fppkg';
        EffectiveCompilerParams:='install -b '+APackageName;

        PkgCompileTool:=ExternalToolList.Add(Format(lisPkgMangCompilePackage, [APackageName]));
        if BuildItem<>nil then
          BuildItem.Add(PkgCompileTool)
        else
          PkgCompileTool.Reference(Self,Classname);
        try
          PkgCompileTool.AddParsers(SubToolFPC);
          PkgCompileTool.AddParsers(SubToolMake);
          PkgCompileTool.Process.Executable:=CompilerFilename;
          PkgCompileTool.CmdLineParams:=EffectiveCompilerParams;
          if BuildItem<>nil then
          begin
            // run later
          end else begin
            // run now
            PkgCompileTool.Execute;
            //debugln(['TLazPackageGraph.CompileFPMakePackage BEFORE WaitForExit: ',APackageName]);
            PkgCompileTool.WaitForExit;
            //debugln(['TLazPackageGraph.CompileFPMakePackage AFTER WaitForExit: ',APackageName,' ExtToolData.ErrorMessage=',ExtToolData.ErrorMessage]);
          end;
        finally
          if BuildItem=nil then
            PkgCompileTool.Release(Self);
        end;
      end;
      Result:=mrOk;
    finally
      if (BuildItem=nil) and (LazarusIDE<>nil) then
        LazarusIDE.MainBarSubTitle:='';
    end;
  finally
    PackageGraph.EndUpdate;
  end;
end;

function TLazPackageGraph.ConvertPackageRSTFiles(APackage: TLazPackage
  ): TModalResult;
var
  PkgOutputDirectory: String;
  POOutputDirectory: String;
begin
  Result:=mrOK;
  if (APackage.POOutputDirectory='') then exit;// nothing to do
  POOutputDirectory:=AppendPathDelim(APackage.GetPOOutDirectory);

  // create output directory if not exists
  if not DirectoryExistsUTF8(POOutputDirectory) then begin
    Result:=ForceDirectoryInteractive(POOutputDirectory,[mbRetry,mbIgnore]);
    if Result<>mrOk then begin
      if Result=mrIgnore then Result:=mrOk;
      DebugLn(['Note: (lazarus) [TLazPackageGraph.ConvertPackageRSTFiles] unable to create directory ',POOutputDirectory]);
      exit;
    end;
  end;
  
  // find all .rst files in package output directory
  if not DirectoryIsWritableCached(POOutputDirectory) then begin
    // this package is read only
    DebugLn(['Warning: (lazarus) [TLazPackageGraph.ConvertPackageRSTFiles] skipping read only directory '+POOutputDirectory]);
    exit(mrOK);
  end;

  PkgOutputDirectory:=AppendPathDelim(APackage.GetOutputDirectory);
  if not ConvertRSTFiles(PkgOutputDirectory,POOutputDirectory) then begin
    DebugLn(['Error: (lazarus) [TLazPackageGraph.ConvertPackageRSTFiles] unable to update .po files PkgOutputDirectory=',PkgOutputDirectory,' RSTOutputDirectory=',POOutputDirectory]);
    exit(mrCancel);
  end;
  Result:=mrOK;
end;

function TLazPackageGraph.WriteMakefileCompiled(APackage: TLazPackage;
  TargetCompiledFile, UnitPath, IncPath, OtherOptions: string): TModalResult;
var
  XMLConfig: TXMLConfig;
  s: String;
begin
  try
    XMLConfig:=TXMLConfig.Create(TargetCompiledFile);
    try
      XMLConfig.SetValue('Makefile/Value',MakefileCompileVersion);
      s:='';
      if UnitPath<>'' then
        s:=s+' -Fu'+SwitchPathDelims(UnitPath,pdsUnix);
      if IncPath<>'' then
        s:=s+' -Fi'+SwitchPathDelims(IncPath,pdsUnix);
      if OtherOptions<>'' then
        s:=s+' '+OtherOptions;
      // do no write the unit output directory
      // it is not needed because it is the location of the Makefile.compiled
      s:=s+' '+SwitchPathDelims(CreateRelativePath(APackage.GetSrcFilename,APackage.Directory),pdsUnix);
      if ConsoleVerbosity>1 then
        debugln(['Hint: (lazarus) writing ',TargetCompiledFile,' IncPath="',IncPath,'" UnitPath="',UnitPath,'" Custom="',OtherOptions,'" Makefile.compiled="',TargetCompiledFile,'"']);
      XMLConfig.SetValue('Params/Value',s);
      if XMLConfig.Modified then begin
        InvalidateFileStateCache;
        XMLConfig.Flush;
      end else begin
        if ConsoleVerbosity>1 then
          debugln(['Hint: (lazarus) not writing ',TargetCompiledFile,', because nothing changed']);
      end;
    finally
      XMLConfig.Free;
    end;
  except
    on E: Exception do begin
      Result:=IDEMessageDialog(lisPkgMangErrorWritingFile,
        Format(lisPkgMangUnableToWriteStateFileOfPackageError,
          [TargetCompiledFile, LineEnding, APackage.IDAsString, LineEnding, E.Message]),
        mtError,[mbCancel],'');
      exit;
    end;
  end;
  Result:=mrOk;
end;

function TLazPackageGraph.WriteMakeFile(APackage: TLazPackage): TModalResult;
var
  PathDelimNeedsReplace: Boolean;

  procedure Replace(var s: string; const SearchTxt, ReplaceTxt: string);
  var
    p: LongInt;
  begin
    repeat
      p:=Pos(SearchTxt,s);
      if p<=1 then break;
      ReplaceSubstring(s,p,length(SearchTxt),ReplaceTxt);
    until false;
  end;

  function ConvertPIMacrosToMakefileMacros(const s: string): string;
  begin
    Result:=s;
    Replace(Result,'%(','$(');
  end;

  function ConvertLazarusToMakefileSearchPath(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result:=CreateRelativeSearchPath(TrimSearchPath(Result,''),APackage.Directory);
    Replace(Result,';',' ');
    if PathDelimNeedsReplace then
      Replace(Result,PathDelim,'/');
  end;

  function ConvertLazarusToMakefileCompiledSearchPath(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result:=CreateRelativeSearchPath(TrimSearchPath(Result,''),APackage.Directory);
    if PathDelimNeedsReplace then
      Replace(Result,PathDelim,'/');
  end;

  function ConvertLazarusToMakefileDirectory(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result:=CreateRelativePath(TrimFilename(Result),APackage.Directory);
    if PathDelimNeedsReplace then
      Replace(Result,PathDelim,'/');
    // trim trailing PathDelim, as windows does not like it
    Result:=ChompPathDelim(Result);
  end;

  function ConvertLazarusOptionsToMakefileOptions(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    if PathDelimNeedsReplace then
      Replace(Result,PathDelim,'/');
  end;

var
  s, Last: String;
  e: string;
  SrcFilename: String;
  MainUnitName: String;
  MakefileFPCFilename: String;
  UnitOutputPath: String;
  UnitPath: String;
  FPCMakeTool: TAbstractExternalTool;
  CodeBuffer: TCodeBuffer;
  MainSrcFile: String;
  CustomOptions: String;
  IncPath: String;
  MakefileCompiledFilename: String;
  OtherOptions: String;
  FormUnitPath: String;
  FormIncPath: String;
  Executable: String;
  DistCleanDir: String;
  NeedFPCMake: Boolean;
begin
  Result:=mrCancel;
  PathDelimNeedsReplace:=PathDelim<>'/';

  if not DirectoryIsWritableCached(APackage.Directory) then begin
    // The Makefile.fpc is only needed for custom building.
    // If the package directory is not writable, then the user does not want to
    // custom build
    // => silently skip
    DebugLn(['Error: (lazarus) Skipping writing Makefile, because package directory is not writable: ',APackage.Directory]);
    Result:=mrOk;
    exit;
  end;
  MakefileFPCFilename:=AppendPathDelim(APackage.Directory)+'Makefile.fpc';
  MakefileCompiledFilename:=AppendPathDelim(APackage.Directory)+'Makefile.compiled';

  SrcFilename:=APackage.GetSrcFilename;
  MainUnitName:=lowercase(ExtractFileNameOnly((SrcFilename)));
  UnitPath:=APackage.CompilerOptions.GetUnitPath(true,
                                                 coptParsedPlatformIndependent);
  IncPath:=APackage.CompilerOptions.GetIncludePath(true,
                                                 coptParsedPlatformIndependent,false);
  UnitOutputPath:=APackage.CompilerOptions.GetUnitOutPath(true,
                                                 coptParsedPlatformIndependent);
  CustomOptions:=APackage.CompilerOptions.GetCustomOptions(
                                                 coptParsedPlatformIndependent);
  OtherOptions:=APackage.CompilerOptions.MakeOptionsString(
                              [ccloDoNotAppendOutFileOption,ccloNoMacroParams]);

  // remove path delimiter at the end, or else it will fail on windows
  UnitOutputPath:=ConvertLazarusToMakefileDirectory(
                                                ChompPathDelim(UnitOutputPath));

  // "make distclean" should delete all variable output directories
  // For example if output directory is units/$(CPU_TARGET)-$(OS_TARGET)/$(LCL_PLATFORM)
  // distclean should delete units/*
  // It uses deltree, so make sure, that it does not delete ./* or ../*
  DistCleanDir:=UnitOutputPath;
  while Pos('$(',ExtractFilename(DistCleanDir))>0 do begin
    Last:=DistCleanDir;
    DistCleanDir:=ChompPathDelim(ExtractFilePath(DistCleanDir));
    s:=ExtractFileName(DistCleanDir);
    if (s='') or (s='.') or (s='..') then begin
      DistCleanDir:=Last;
      break;
    end;
  end;
  s:=ExtractFileName(DistCleanDir);
  if (s='') or (s='.') or (s='..') then
    DistCleanDir:='' // do not delete potential source directories
  else
    DistCleanDir+='/*';

  MainSrcFile:=CreateRelativePath(SrcFilename,APackage.Directory);
  CustomOptions:=ConvertLazarusOptionsToMakefileOptions(CustomOptions);
  OtherOptions:=ConvertLazarusOptionsToMakefileOptions(OtherOptions);
  if ConsoleVerbosity>0 then
    debugln(['Hint: (lazarus) [TLazPackageGraph.WriteMakeFile] Custom="',CustomOptions,'" Other="',OtherOptions,'"']);
  if CustomOptions<>'' then
    if OtherOptions<>'' then
      OtherOptions:=OtherOptions+' '+CustomOptions
    else
      OtherOptions:=CustomOptions;
  if ConsoleVerbosity>0 then
    debugln(['Hint: (lazarus) [TLazPackageGraph.WriteMakeFile] Other="',OtherOptions,'"']);

  // ---- Makefile.compiled ----------------------------------------------------

  //DebugLn('TPkgManager.DoWriteMakefile ',APackage.Name,' makefile UnitPath="',UnitPath,'"');
  FormUnitPath:=ConvertLazarusToMakefileCompiledSearchPath(UnitPath);
  FormIncPath:=ConvertLazarusToMakefileCompiledSearchPath(IncPath);
  Result:=WriteMakefileCompiled(APackage,MakefileCompiledFilename,FormUnitPath,
    FormIncPath,OtherOptions);
  if Result<>mrOK then exit;

  // ---- Makefile.fpc ---------------------------------------------------------

  //DebugLn('TPkgManager.DoWriteMakefile ',APackage.Name,' makefile UnitPath="',UnitPath,'"');
  FormUnitPath:=ConvertLazarusToMakefileSearchPath(UnitPath);
  FormIncPath:=ConvertLazarusToMakefileSearchPath(IncPath);

  e:=LineEnding;
  s:='';
  s:=s+'#   File generated automatically by Lazarus Package Manager'+e;
  s:=s+'#'+e;
  s:=s+'#   Makefile.fpc for '+APackage.IDAsString+e;
  s:=s+'#'+e;
  s:=s+'#   This file was generated on '+DateToStr(Now)+''+e;
  s:=s+''+e;
  s:=s+'[package]'+e;
  s:=s+'name='+lowercase(APackage.Name)+e;
  s:=s+'version='+APackage.Version.AsString+e;
  s:=s+''+e;
  s:=s+'[compiler]'+e;
  s:=s+'unittargetdir='+UnitOutputPath+e;
  if UnitPath<>'' then
    s:=s+'unitdir='+FormUnitPath+e;
  if IncPath<>'' then
    s:=s+'includedir='+FormIncPath+e;
  s:=s+'options='+OtherOptions+' $(DBG_OPTIONS)'+e;
  s:=s+''+e;
  s:=s+'[target]'+e;
  s:=s+'units='+MainSrcFile+e;
  s:=s+''+e;
  s:=s+'[clean]'+e;
  s:=s+'files=$(wildcard $(COMPILER_UNITTARGETDIR)/*$(OEXT)) \'+e;
  s:=s+'      $(wildcard $(COMPILER_UNITTARGETDIR)/*$(PPUEXT)) \'+e;
  s:=s+'      $(wildcard $(COMPILER_UNITTARGETDIR)/*$(RSTEXT)) \'+e;
  if (TrimFilename(UnitOutputPath)<>'') and (TrimFilename(UnitOutputPath)<>'.')
  then begin
    s:=s+'      $(wildcard $(COMPILER_UNITTARGETDIR)/*.lfm) \'+e;
    s:=s+'      $(wildcard $(COMPILER_UNITTARGETDIR)/*.res) \'+e;
  end;
  s:=s+'      $(wildcard $(COMPILER_UNITTARGETDIR)/*.compiled) \'+e;
  s:=s+'      $(wildcard *$(OEXT)) $(wildcard *$(PPUEXT)) $(wildcard *$(RSTEXT))'+e;
  s:=s+''+e;
  s:=s+'[prerules]'+e;
  s:=s+'# LCL Platform'+e;
  s:=s+'ifndef LCL_PLATFORM'+e;
  s:=s+'ifeq ($(OS_TARGET),win32)'+e;
  s:=s+'LCL_PLATFORM=win32'+e;
  s:=s+'else'+e;
  s:=s+'ifeq ($(OS_TARGET),win64)'+e;
  s:=s+'LCL_PLATFORM=win32'+e;
  s:=s+'else'+e;
  s:=s+'ifeq ($(OS_TARGET),darwin)'+e;
  s:=s+'LCL_PLATFORM=carbon'+e;
  s:=s+'else'+e;
  s:=s+'LCL_PLATFORM=gtk2'+e;
  s:=s+'endif'+e;
  s:=s+'endif'+e;
  s:=s+'endif'+e;
  s:=s+'endif'+e;
  s:=s+'export LCL_PLATFORM'+e;
  s+=e;
  s:=s+'DBG_OPTIONS='+e;
  s:=s+'ifeq ($(OS_TARGET),darwin)'+e;
  s:=s+'DBG_OPTIONS=-gw'+e;
  s:=s+'endif'+e;

  s:=s+''+e;
  s:=s+'[rules]'+e;
  s:=s+'.PHONY: cleartarget compiled all'+e;
  s:=s+''+e;
  s:=s+'cleartarget:'+e;
  s:=s+'        -$(DEL) $(COMPILER_UNITTARGETDIR)/'+MainUnitName+'$(PPUEXT)'+e;
  s:=s+''+e;
  s:=s+'compiled:'+e;
  s:=s+'        $(CPPROG) -f Makefile.compiled $(COMPILER_UNITTARGETDIR)/'+APackage.Name+'.compiled'+e;
  s:=s+''+e;
  s:=s+'all: cleartarget $(COMPILER_UNITTARGETDIR) '+MainUnitName+'$(PPUEXT) compiled'+e;
  if DistCleanDir<>'' then begin
    s:=s+''+e;
    s:=s+'distclean: clean'+e;
    s:=s+'        ${DELTREE} '+DistCleanDir+e;
  end;

  //DebugLn('TPkgManager.DoWriteMakefile [',s,']');

  CodeBuffer:=CodeToolBoss.LoadFile(MakefileFPCFilename,true,true);
  if CodeBuffer=nil then begin
    CodeBuffer:=CodeToolBoss.CreateFile(MakefileFPCFilename);
    if CodeBuffer=nil then begin
      if not DirectoryIsWritableCached(ExtractFilePath(MakefileFPCFilename))
      then begin
        // the package source is read only => ignore
        exit(mrOk);
      end;
      debugln(['Error: (lazarus) [TLazPackageGraph.WriteMakeFile] unable to create file '+MakefileFPCFilename]);
      exit(mrCancel);
    end;
  end;

  NeedFPCMake:=false;
  if ExtractCodeFromMakefile(CodeBuffer.Source)<>ExtractCodeFromMakefile(s)
  then begin
    // Makefile.fpc changed
    CodeBuffer.Source:=s;

    //debugln('TPkgManager.DoWriteMakefile MakefileFPCFilename="',MakefileFPCFilename,'"');
    Result:=SaveCodeBufferToFile(CodeBuffer,MakefileFPCFilename);
    if Result<>mrOk then begin
      if not DirectoryIsWritableCached(ExtractFilePath(MakefileFPCFilename)) then
      begin
        // the package source is read only => no problem
        if ConsoleVerbosity>0 then
          debugln(['Note: (lazarus) [TLazPackageGraph.WriteMakeFile] not writing "',MakefileFPCFilename,'" because dir not writable, ignoring...']);
        Result:=mrOk;
      end;
      exit;
    end;
    NeedFPCMake:=true;
  end;

  Executable:=FindFPCTool('fpcmake'+GetExecutableExt,
                                  EnvironmentOptions.GetParsedCompilerFilename);
  if FileIsExecutableCached(Executable) then begin
    if (not NeedFPCMake)
    and (FileAgeUTF8(MakefileFPCFilename)<FileAgeCached(Executable)) then begin
      if ConsoleVerbosity>=0 then
        debugln(['Hint: (lazarus) [TLazPackageGraph.WriteMakeFile] "',Executable,'" is newer than "',MakefileFPCFilename,'"']);
      NeedFPCMake:=true;// fpcmake is newer than Makefile.fpc
    end;
    if not NeedFPCMake then
      exit(mrOk);
  end else
    Executable:='fpcmake'+GetExecutableExt;

  // call fpcmake to create the Makefile
  FPCMakeTool:=ExternalToolList.Add(
    Format(lisIDEInfoCreatingMakefileForPackage, [APackage.IDAsString]));
  FPCMakeTool.Process.CurrentDirectory:=APackage.Directory;
  FPCMakeTool.Process.Executable:=Executable;
  FPCMakeTool.CmdLineParams:='-q -TAll';
  FPCMakeTool.EnvironmentOverrides.Add(
                      'FPCDIR='+EnvironmentOptions.GetParsedFPCSourceDirectory);
  FPCMakeTool.Execute;
  FPCMakeTool.WaitForExit;
  Result:=mrOk;
end;

function TLazPackageGraph.WriteFpmake(APackage: TLazPackage): TModalResult;
var
  PathDelimNeedsReplace: Boolean;

  function ConvertPIMacrosToMakefileMacros(const s: string): string;
  begin
    result := StringsReplace(s, ['%(LCL_PLATFORM)', '%(CPU_TARGET)', '%(OS_TARGET)'],
                                ['$(LCLWidgetType)','$(CPU)',        '$(OS)'],[rfReplaceAll, rfIgnoreCase]);
    result := StringReplace(result,'%(','$(',[rfReplaceAll]);
  end;

  function ConvertLazarusToFpmakeSearchPath(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result:=CreateRelativeSearchPath(TrimSearchPath(Result,''),APackage.Directory);
    if PathDelimNeedsReplace then
      Result:=StringReplace(Result,PathDelim,'/',[rfReplaceAll]);
  end;

  function ConvertLazarusToMakefileDirectory(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result:=CreateRelativePath(TrimFilename(Result),APackage.Directory);
    if PathDelimNeedsReplace then
      Result:=StringReplace(Result,PathDelim,'/',[rfReplaceAll]);
    // trim trailing PathDelim, as windows does not like it
    Result:=ChompPathDelim(Result);
  end;

  function StringToFpmakeOptionGroup(const OptionName,Options:string; OptPrefix: string = ''): string;
  var
    sl: TStrings;
    i: Integer;
  begin
    result := '';
    sl := SplitString(Options,';');
    try
      for i := 0 to sl.Count-1 do
        result := result + OptionName+'('''+OptPrefix+sl.Strings[i]+''');'+LineEnding;
    finally
      sl.Free;
    end;
  end;

  function ConvertLazarusOptionsToFpmakeOptions(const s: string): string;
  begin
    Result:=ConvertPIMacrosToMakefileMacros(s);
    Result := StringReplace(Result,' ',';',[rfReplaceAll]);
    if PathDelimNeedsReplace then
      Result:=StringReplace(Result,PathDelim,'/',[rfReplaceAll]);
  end;

var
  s: String;
  e: string;
  SrcFilename: String;
  FpmakeFPCFilename: String;
  UnitPath: String;
  OriginalCode: String;
  CodeBuffer: TCodeBuffer;
  MainSrcFile: String;
  CustomOptions: String;
  IncPath: String;
  OtherOptions: String;
  i: Integer;
  ARequirement: TPkgDependency;
  FPmakeCompiledFilename: String;
begin
  Result:=mrCancel;
  PathDelimNeedsReplace:=PathDelim<>'/';

  if not DirectoryIsWritableCached(APackage.Directory) then begin
    // The fpmake.pp is only needed for custom building.
    // If the package directory is not writable, then the user does not want to
    // custom build
    // => silently skip
    DebugLn(['Note: (lazarus) Skipping writing fpmake.pp, because package directory is not writable: ',APackage.Directory]);
    Result:=mrOk;
    exit;
  end;
  FpmakeFPCFilename:=AppendPathDelim(APackage.Directory)+'fpmake.pp';
  FPmakeCompiledFilename:=AppendPathDelim(APackage.Directory)+APackage.Name+'.compiled';

  SrcFilename:=APackage.GetSrcFilename;

  UnitPath:=APackage.CompilerOptions.ParsedOpts.GetParsedPIValue(pcosUnitPath);
  UnitPath:=CreateRelativeSearchPath(UnitPath,APackage.CompilerOptions.BaseDirectory);
  UnitPath:=MergeSearchPaths(UnitPath, '.');

  IncPath:=APackage.CompilerOptions.GetIncludePath(true,
                                           coptParsedPlatformIndependent,false);
  CustomOptions:=APackage.CompilerOptions.GetCustomOptions(
                                                 coptParsedPlatformIndependent);
  if ConsoleVerbosity>0 then
    debugln('Hint: (lazarus) Writing fpmake.pp: CustomOptions (orig): ',CustomOptions);
  OtherOptions:=APackage.CompilerOptions.MakeOptionsString(
                              [ccloDoNotAppendOutFileOption,ccloNoMacroParams]);
  if ConsoleVerbosity>0 then
    debugln('Hint: (lazarus) Writing fpmake.pp: OtherOptions (orig): ',OtherOptions);

  // write compiled file
  Result:=WriteMakefileCompiled(APackage,FPmakeCompiledFilename,UnitPath,
    IncPath,OtherOptions);
  if Result<>mrOK then exit;

  //DebugLn('TPkgManager.DoWriteMakefile ',APackage.Name,' makefile UnitPath="',UnitPath,'"');
  UnitPath:=ConvertLazarusToFpmakeSearchPath(UnitPath);
  IncPath:=ConvertLazarusToFpmakeSearchPath(IncPath);
  // remove path delimiter at the end, or else it will fail on windows
  MainSrcFile:=CreateRelativePath(SrcFilename,APackage.Directory);
  CustomOptions:=ConvertLazarusOptionsToFpmakeOptions(CustomOptions);
  if ConsoleVerbosity>0 then
    debugln('Hint: (lazarus) Writing fpmake.pp: CustomOptions (fpmake format): ',CustomOptions);

  OtherOptions:=ConvertLazarusOptionsToFpmakeOptions(OtherOptions);
  if ConsoleVerbosity>0 then
    debugln('Hint: (lazarus) Writing fpmake.pp: OtherOptions (fpmake format): ',OtherOptions);

  e:=LineEnding;
  s:='';
  s:=s+'{'+e;
  s:=s+'   File generated automatically by Lazarus Package Manager'+e;
  if Assigned(FppkgInterface) then
    s := s + '   Created with the Fppkgpackagemanager package installed'+e;
  s:=s+''+e;
  s:=s+'   fpmake.pp for '+APackage.IDAsString+e;
  s:=s+''+e;
  s:=s+'   This file was generated on '+DateToStr(Now)+''+e;
  s:=s+'}'+e;
  s:=s+''+e;
  s:=s+'{$ifndef ALLPACKAGES} '+e;
  s:=s+'{$mode objfpc}{$H+}'+e;
  s:=s+'program fpmake;'+e;
  s:=s+''+e;
  s:=s+'uses fpmkunit;'+e;
  s:=s+'{$endif ALLPACKAGES}'+e;
  s:=s+''+e;
  s:=s+'procedure add_'+APackage.Name+'(const ADirectory: string);'+e;
  s:=s+''+e;
  s:=s+'var'+e;
  s:=s+'  P : TPackage;'+e;
  s:=s+'  T : TTarget;'+e;
  s:=s+'  D : TDependency;'+e;
  s:=s+''+e;

  if Assigned(FppkgInterface) then
    s := s + FppkgInterface.ConstructFpMakeInterfaceSection(APackage);

  s:=s+'begin'+e;
  s:=s+'  with Installer do'+e;
  s:=s+'    begin'+e;
  s:=s+'    P:=AddPackage('''+lowercase(APackage.Name)+''');'+e;
  s:=s+'    P.Version:='''+APackage.Version.AsString+''';'+e;
  s:=s+''+e;
  s:=s+'    P.Directory:=ADirectory;'+e;
  s:=s+''+e;
  if APackage.PackageType in [lptDesignTime, lptRunAndDesignTime] then
    s:=s+'    P.Flags.Add(''LazarusDsgnPkg'');'+e+e;

  ARequirement := APackage.FirstRequiredDependency;
  while assigned(ARequirement) do
  begin
    s:=s+'    D := P.Dependencies.Add('''+lowercase(ARequirement.PackageName)+''');'+e;
    ARequirement := ARequirement.NextRequiresDependency;
  end;

  s := s + StringToFpmakeOptionGroup('    P.Options.Add',OtherOptions);
  s := s + StringToFpmakeOptionGroup('    P.Options.Add',CustomOptions);
  s := s + StringToFpmakeOptionGroup('    P.IncludePath.Add',IncPath);
  s := s + StringToFpmakeOptionGroup('    P.UnitPath.Add', UnitPath);

  if Assigned(FppkgInterface) then
    s := s + FppkgInterface.ConstructFpMakeImplementationSection(APackage);

  s:=s+'    T:=P.Targets.AddUnit('''+MainSrcFile+''');'+e;
  if Assigned(FppkgInterface) then
    s := s + FppkgInterface.ConstructFpMakeDependenciesFileSection(APackage)
  else
  begin
    for i := 0 to APackage.FileCount-1 do
      if (APackage.Files[i].FileType=pftUnit) then
        s:=s+'    t.Dependencies.AddUnit('''+ExtractFileNameOnly(APackage.Files[i].Filename)+''');'+e;

    s:=s+''+e;

    for i := 0 to APackage.FileCount-1 do
      if (APackage.Files[i].FileType=pftUnit) then
      begin
        if (pffAddToPkgUsesSection in APackage.Files[i].Flags) then
          s:=s+'    T:=P.Targets.AddUnit('''+CreateRelativePath(APackage.Files[i].Filename,APackage.Directory)+''');'+e
        else
        begin
          s:=s+'    P.Targets.AddImplicitUnit('''+CreateRelativePath(APackage.Files[i].Filename,APackage.Directory)+''');'+e;
        end;
      end;
  end;

  s:=s+''+e;
  s:=s+'    // copy the compiled file, so the IDE knows how the package was compiled'+e;
  s:=s+'    P.InstallFiles.Add('''+ExtractFileName(FPmakeCompiledFilename)+''',AllOSes,''$(unitinstalldir)'');'+e;

  s:=s+''+e;
  s:=s+'    end;'+e;
  s:=s+'end;'+e;

  s:=s+''+e;
  s:=s+'{$ifndef ALLPACKAGES}'+e;
  s:=s+'begin'+e;
  s:=s+'  add_'+APackage.Name+'('''');'+e;
  s:=s+'  Installer.Run;'+e;
  s:=s+'end.'+e;
  s:=s+'{$endif ALLPACKAGES}'+e;

  CodeBuffer:=CodeToolBoss.LoadFile(FpmakeFPCFilename,true,true);
  if CodeBuffer=nil then begin
    CodeBuffer:=CodeToolBoss.CreateFile(FpmakeFPCFilename);
    if CodeBuffer=nil then begin
      if not DirectoryIsWritableCached(ExtractFilePath(FpmakeFPCFilename))
      then begin
        // the package source is read only => ignore
        exit(mrOk);
      end;
      debugln(['Error: (lazarus) unable to create fpmake.pp file '+FpmakeFPCFilename]);
      exit(mrCancel);
    end;
  end;

  OriginalCode:=CodeToolBoss.ExtractCodeWithoutComments(CodeBuffer);
  CodeBuffer.Source:=s;
  if OriginalCode=CodeToolBoss.ExtractCodeWithoutComments(CodeBuffer)
  then begin
    // nothing important has changed in fpmake.pp => do not write to disk
    Result:=mrOk;
    exit;
  end;
  CodeBuffer.Source:=s;

  //debugln('TPkgManager.DoWriteMakefile MakefileFPCFilename="',FpmakeFPCFilename,'"');
  Result:=SaveCodeBufferToFile(CodeBuffer,FpmakeFPCFilename);
  if Result<>mrOk then begin
    if not DirectoryIsWritableCached(ExtractFilePath(FpmakeFPCFilename)) then
    begin
      // the package source is read only => skip silently
      Result:=mrOk;
    end;
    exit;
  end;
  if ConsoleVerbosity>0 then
    debugln(['Hint: (lazarus) wrote fpmake.pp: ',FpmakeFPCFilename]);

  Result:=mrOk;
end;

function TLazPackageGraph.PreparePackageOutputDirectory(APackage: TLazPackage;
  CleanUp: boolean): TModalResult;
var
  OutputDir: String;
  StateFile: String;
  PkgSrcDir: String;
  i: Integer;
  CurFile: TPkgFile;
  OutputFileName: String;
  NewOutputDir: String;
  DeleteAllFilesInOutputDir: Boolean;
  DirCache: TCTDirectoryCache;
  CleanFiles: TStrings;
begin
  // get output directory
  OutputDir:=APackage.GetOutputDirectory;
  //debugln(['TLazPackageGraph.PreparePackageOutputDirectory OutputDir="',OutputDir,'"']);

  DeleteAllFilesInOutputDir:=false;
  if not OutputDirectoryIsWritable(APackage,OutputDir,false) then
  begin
    // the normal output directory is not writable
    // => use the fallback directory
    NewOutputDir:=GetFallbackOutputDir(APackage);
    if (NewOutputDir=OutputDir) or (NewOutputDir='') then begin
      debugln(['Error: (lazarus) [TLazPackageGraph.PreparePackageOutputDirectory] failed to create writable directory: ',OutputDir]);
      exit(mrCancel);
    end;
    APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride:=NewOutputDir;
    OutputDir:=APackage.GetOutputDirectory;
    if not OutputDirectoryIsWritable(APackage,OutputDir,true) then
    begin
      debugln(['Error: (lazarus) [TLazPackageGraph.PreparePackageOutputDirectory] failed to create writable directory: ',OutputDir]);
      Result:=mrCancel;
    end;
    DeleteAllFilesInOutputDir:=true;
  end else if APackage.CompilerOptions.ParsedOpts.OutputDirectoryOverride<>''
  then
    // package is already using the fallback directory
    DeleteAllFilesInOutputDir:=true
  else if CleanUp then begin
    // package is not using the fallback directory
    // check if the output directory contains sources
    DeleteAllFilesInOutputDir:=APackage.HasSeparateOutputDirectory;
  end;
  //debugln(['TLazPackageGraph.PreparePackageOutputDirectory ',APackage.Name,' DeleteAllFilesInOutputDir=',DeleteAllFilesInOutputDir]);

  StateFile:=APackage.GetStateFilename;
  PkgSrcDir:=ExtractFilePath(APackage.GetSrcFilename);

  // delete old Compile State file
  if FileExistsUTF8(StateFile) and not DeleteFileUTF8(StateFile) then begin
    Result:=IDEMessageDialog(lisPkgMangUnableToDeleteFilename,
      Format(lisPkgMangUnableToDeleteOldStateFileForPackage,
             [StateFile, LineEnding, APackage.IDAsString]),
      mtError,[mbCancel,mbAbort]);
    exit;
  end;
  InvalidateFileStateCache(StateFile);
  InvalidateStateFile(APackage);

  // create the package src directory
  if not ForceDirectoriesUTF8(PkgSrcDir) then begin
    Result:=IDEMessageDialog(lisPkgMangUnableToCreateDirectory,
      Format(lisPkgMangUnableToCreatePackageSourceDirectoryForPackage,
             [PkgSrcDir, LineEnding, APackage.IDAsString]),
      mtError,[mbCancel,mbAbort]);
    exit;
  end;

  // clean up if wanted
  if CleanUp then begin
    if DeleteAllFilesInOutputDir then begin
      // delete all files in output directory
      DirCache:=CodeToolBoss.DirectoryCachePool.GetCache(OutputDir,true,false);
      if DirCache<>nil then begin
        CleanFiles:=TStringList.Create;
        try
          DirCache.GetFiles(CleanFiles,false);
          for i:=0 to CleanFiles.Count-1 do begin
            OutputFileName:=AppendPathDelim(OutputDir)+CleanFiles[i];
            if ConsoleVerbosity>1 then
              debugln(['Hint: (lazarus) cleaning up package output directory of '+APackage.IDAsString+': '+OutputFileName]);
            Result:=DeleteFileInteractive(OutputFileName,[mbIgnore,mbAbort]);
            if Result in [mrCancel,mrAbort] then exit;
          end;
        finally
          CleanFiles.Free;
        end;
      end;
    end else begin
      // delete .ppu/.o file of each registered unit
      for i:=0 to APackage.FileCount-1 do begin
        CurFile:=APackage.Files[i];
        if not (CurFile.FileType in PkgFileUnitTypes) then continue;
        OutputFileName:=AppendPathDelim(OutputDir)+CurFile.Unit_Name+'.ppu';
        if ConsoleVerbosity>1 then
          debugln(['Hint: (lazarus) cleaning up package output directory of '+APackage.IDAsString+': '+OutputFileName]);
        Result:=DeleteFileInteractive(OutputFileName,[mbIgnore,mbAbort]);
        if Result in [mrCancel,mrAbort] then exit;
        OutputFileName:=ChangeFileExt(OutputFileName,'.o');
        if ConsoleVerbosity>1 then
          debugln(['Hint: (lazarus) cleaning up package output directory of '+APackage.IDAsString+': '+OutputFileName]);
        Result:=DeleteFileInteractive(OutputFileName,[mbIgnore,mbAbort]);
        if Result in [mrCancel,mrAbort] then exit;
      end;
    end;
    InvalidateFileStateCache;
  end;

  Result:=mrOk;
end;

function TLazPackageGraph.GetFallbackOutputDir(APackage: TLazPackage): string;
var
  Dir: String;
begin
  // use the default output directory, if it is relative
  // (this way the fallback creates the same amount of target directories)
  Dir:=APackage.CompilerOptions.ParsedOpts.Values[pcosOutputDir].UnparsedValue;
  Dir:=APackage.SubstitutePkgMacros(Dir,false);
  if FilenameIsAbsolute(Dir) then begin
    // it is not relative => create a default one
    Dir:='$(TargetOS)-$(TargetCPU)';
  end;
  Dir:='$(FallbackOutputRoot)'+PathDelim+APackage.Name+PathDelim+Dir;
  GlobalMacroList.SubstituteStr(Dir);
  Dir:=TrimFilename(Dir);
  if ConsoleVerbosity>=0 then
    debugln(['Hint: (lazarus) Fallback output directory of ',APackage.Name,': ',Dir]);
  Result:=Dir;
end;

function TLazPackageGraph.CheckAmbiguousPackageUnits(APackage: TLazPackage
  ): TModalResult;
var
  i: Integer;
  CurFile: TPkgFile;
  CurUnitName: String;
  SrcDirs: String;
  PkgDir: String;
  PkgOutputDir: String;
  YesToAll: Boolean;

  function CheckFile(const ShortFilename: string): TModalResult;
  var
    AmbiguousFilename: String;
    SearchFlags: TSearchFileInPathFlags;
  begin
    Result:=mrOk;
    SearchFlags:=[];
    if CompareFilenames(PkgDir,PkgOutputDir)=0 then
      Include(SearchFlags,sffDontSearchInBasePath);
    repeat
      AmbiguousFilename:=SearchFileInPath(ShortFilename,PkgDir,SrcDirs,';',
                                          SearchFlags);
      if (AmbiguousFilename='') then exit;
      if not YesToAll then
        Result:=IDEMessageDialog(lisAmbiguousUnitFound,
          Format(lisTheFileWasFoundInOneOfTheSourceDirectoriesOfThePac,
            [AmbiguousFilename, LineEnding, APackage.IDAsString, LineEnding+LineEnding]),
          mtWarning,[mbYes,mbYesToAll,mbNo,mbAbort])
      else
        Result:=mrYesToAll;
      if Result=mrNo then
        Result:=mrOk;
      if Result in [mrYes,mrYesToAll] then begin
        YesToAll:=Result=mrYesToAll;
        if (not DeleteFileUTF8(AmbiguousFilename))
        and (IDEMessageDialog(lisPkgMangDeleteFailed,
              Format(lisDeletingOfFileFailed, [AmbiguousFilename]),
              mtError, [mbIgnore, mbCancel])<>mrIgnore)
        then
          exit(mrCancel);
        Result:=mrOk;
      end else
        break;
    until false;
  end;

begin
  Result:=mrOk;
  case EnvironmentOptions.AmbiguousFileAction of
    afaIgnore: exit;
    afaAutoDelete: YesToAll:=true;
    else YesToAll:=false;
  end;
  // search in every source directory for compiled versions of the units
  // A source directory is a directory with a used unit and it is not the output
  // directory
  SrcDirs:=APackage.GetSourceDirs(true,true);
  PkgOutputDir:=AppendPathDelim(APackage.GetOutputDirectory);
  SrcDirs:=RemoveSearchPaths(SrcDirs,PkgOutputDir);
  if SrcDirs='' then exit;
  PkgDir:=AppendPathDelim(APackage.Directory);
  for i:=0 to APackage.FileCount-1 do begin
    CurFile:=APackage.Files[i];
    if CurFile.FileType<>pftUnit then continue;
    CurUnitName:=lowercase(CurFile.Unit_Name);
    if CurUnitName='' then continue;
    Result:=CheckFile(CurUnitName+'.ppu');
    if Result<>mrOk then exit;
    Result:=CheckFile(CurUnitName+'.ppl');
    if Result<>mrOk then exit;
  end;
  Result:=mrOk;
end;

function TLazPackageGraph.SavePackageMainSource(APackage: TLazPackage;
  Flags: TPkgCompileFlags; ShowAbort: boolean): TModalResult;
var
  PkgUnitName, SrcFilename, UsedUnits, Src: String;
  i: Integer;
  e: String;
  CurFile: TPkgFile;
  CodeBuffer: TCodeBuffer;
  CurUnitName: String;
  RegistrationCode: String;
  HeaderSrc: String;
  OldShortenSrc: String;
  NeedsRegisterProcCall: boolean;
  CurSrcUnitName: String;
  NewShortenSrc: String;
  BeautifyCodeOptions: TBeautifyCodeOptions;
  AddedUnitNames: TStringToStringTree;
  AFilename: String;

  procedure UseUnit(AnUnitName: string);
  begin
    if AddedUnitNames.Contains(AnUnitName) then exit;
    if CompareDottedIdentifiers(PChar(AnUnitName),PChar(PkgUnitName))=0 then exit;
    AddedUnitNames.Add(AnUnitName,'');
    if UsedUnits<>'' then
      UsedUnits:=UsedUnits+', ';
    UsedUnits:=UsedUnits+AnUnitName;
  end;

begin
  {$IFDEF VerbosePkgCompile}
  debugln('TLazPackageGraph.SavePackageMainSource A');
  {$ENDIF}
  SrcFilename:=APackage.GetSrcFilename;

  // delete ambiguous files
  Result:=DeleteAmbiguousFiles(SrcFilename);
  if Result=mrAbort then begin
    DebugLn('Error: (lazarus) [TLazPackageGraph.SavePackageMainSource] DoDeleteAmbiguousFiles failed');
    exit;
  end;

  // get unit name
  PkgUnitName := ExtractFileNameOnly(SrcFilename);
  if CompareDottedIdentifiers(PChar(APackage.Name), PChar(PkgUnitName))=0 then
    PkgUnitName := APackage.Name;

  // collect unitnames
  e:=LineEnding;
  UsedUnits:='';
  RegistrationCode:='';
  AddedUnitNames:=TStringToStringTree.Create(false);
  try
    for i:=0 to APackage.FileCount-1 do begin
      CurFile:=APackage.Files[i];
      if CurFile.FileType=pftMainUnit then continue;
      // update unitname
      AFilename:=CurFile.GetFullFilename;
      if FilenameIsPascalUnit(AFilename)
      and (CurFile.FileType in PkgFileUnitTypes) then begin
        NeedsRegisterProcCall:=CurFile.HasRegisterProc
          and (APackage.PackageType in [lptDesignTime,lptRunAndDesignTime]);

        AFilename:=CodeToolBoss.DirectoryCachePool.FindDiskFilename(AFilename,true);
        CurUnitName:=ExtractFileNameOnly(AFilename);

        if not (NeedsRegisterProcCall or CurFile.AddToUsesPkgSection) then
          continue;

        if CurUnitName=lowercase(CurUnitName) then begin
          // the filename is all lowercase, so we can use the nicer unitname from
          // the source.

          CodeBuffer:=CodeToolBoss.LoadFile(AFilename,false,false);
          if CodeBuffer<>nil then begin
            // if the unit is edited, the unitname is probably already cached
            CurSrcUnitName:=CodeToolBoss.GetCachedSourceName(CodeBuffer);
            // if not then parse it
            if SysUtils.CompareText(CurSrcUnitName,CurUnitName)<>0 then
              CurSrcUnitName:=CodeToolBoss.GetSourceName(CodeBuffer,false);
            // if it makes sense, update unitname
            if SysUtils.CompareText(CurSrcUnitName,CurFile.Unit_Name)=0 then
              CurFile.Unit_Name:=CurSrcUnitName;
          end;
          if SysUtils.CompareText(CurUnitName,CurFile.Unit_Name)=0 then
            CurUnitName:=CurFile.Unit_Name
          else
            CurFile.Unit_Name:=CurUnitName;
        end;

        if (CurUnitName='') or (not IsValidUnitName(CurUnitName)) then begin
          AddMessage(mluError,Format('invalid unit name in package %s',[APackage.IDAsString]),CurFile.Filename);
          continue;
        end;

        UseUnit(CurUnitName);
        if NeedsRegisterProcCall then begin
          RegistrationCode:=RegistrationCode+
            '  RegisterUnit('''+CurUnitName+''',@'+CurUnitName+'.Register);'+e;
        end;
      end;
    end;

    // append registration code only for design time packages
    if (APackage.PackageType in [lptDesignTime,lptRunAndDesignTime]) then begin
      RegistrationCode:=
        'procedure Register;'+e
        +'begin'+e
        +RegistrationCode
        +'end;'+e
        +e
        +'initialization'+e
        +'  RegisterPackage('''+APackage.Name+''',@Register);'
        +e;
      UseUnit('LazarusPackageIntf');
    end;

  finally
    AddedUnitNames.Free;
  end;
  // create source
  BeautifyCodeOptions:=CodeToolBoss.SourceChangeCache.BeautifyCodeOptions;
  // do not translate to avoid svn updates
  HeaderSrc:= '{ This file was automatically created by Lazarus. Do not edit!'+e
           +'  This source is only used to compile and install the package.'+e
           +' }'+e+e;
  // leave the unit case the same as the package name (e.g: package name LazReport, unit name lazreport)
  Src:='unit '+ PkgUnitName +';'+e
      +e
      +'{$warn 5023 off : no warning about unused units}'+e
      +'interface'+e
      +e;
  Src:=BeautifyCodeOptions.BeautifyStatement(Src,0);
  Src:=HeaderSrc+Src;
  if UsedUnits<>'' then
    Src:=Src
      +'uses'+e
      +BreakString(GetIndentStr(BeautifyCodeOptions.Indent)+UsedUnits+';',
                   BeautifyCodeOptions.LineLength,BeautifyCodeOptions.Indent)+e
      +e;
  Src:=Src+BeautifyCodeOptions.BeautifyStatement(
       'implementation'+e
      +e
      +RegistrationCode
      +'end.'+e,0);

  // check if old code is already uptodate
  Result:=LoadCodeBuffer(CodeBuffer,SrcFilename,[lbfQuiet,lbfCheckIfText,
                            lbfUpdateFromDisk,lbfCreateClearOnError],ShowAbort);
  if Result<>mrOk then begin
    DebugLn('Error: (lazarus) [TLazPackageGraph.SavePackageMainSource] LoadCodeBuffer ',SrcFilename,' failed');
    exit;
  end;
  // ignore comments
  OldShortenSrc:=CodeToolBoss.ExtractCodeWithoutComments(CodeBuffer,true);
  NewShortenSrc:=CleanCodeFromComments(Src,
           CodeToolBoss.GetNestedCommentsFlagForFile(CodeBuffer.Filename),true);
  // ignore case and spaces
  if CompareTextIgnoringSpace(OldShortenSrc,NewShortenSrc,false)=0 then begin
    Result:=mrOk;
    exit;
  end;
  if OldShortenSrc<>NewShortenSrc then begin
    {$IFDEF VerbosePkgCompile}
    DebugLn('TLazPackageGraph.SavePackageMainSource Src changed ',dbgs(length(OldShortenSrc)),' ',dbgs(length(NewShortenSrc)));
    {$ENDIF}
  end;

  // save source
  Result:=SaveStringToFile(SrcFilename,Src,[],lisPkgMangpackageMainSourceFile);
  if Result<>mrOk then begin
    DebugLn('Error: (lazarus) [TLazPackageGraph.SavePackageMainSource] SaveStringToFile ',SrcFilename,' failed');
    exit;
  end;

  Result:=mrOk;
end;

function TLazPackageGraph.GetBrokenDependenciesWhenChangingPkgID(
  APackage: TLazPackage; const NewName: string; NewVersion: TPkgVersion
    ): TFPList;
var
  Dependency: TPkgDependency;
begin
  Result:=TFPList.Create;
  // find all dependencies, that will become incompatible
  Dependency:=APackage.FirstUsedByDependency;
  while Dependency<>nil do begin
    if not Dependency.IsCompatible(NewName,NewVersion) then
      Result.Add(Dependency);
    Dependency:=Dependency.NextUsedByDependency;
  end;
end;

procedure TLazPackageGraph.GetPackagesChangedOnDisk(out
  ListOfPackages: TStringList; IgnoreModifiedFlag: boolean);
// if package source is changed in IDE (codetools)
// then changes on disk are ignored
var
  APackage: TLazPackage;
  i: Integer;
  NewFilename: String;
  HaveUpdatedGlobalPkgLinks: Boolean;

  procedure UpdateGlobalLinks;
  begin
    if not HaveUpdatedGlobalPkgLinks then
    begin
      LazPackageLinks.UpdateGlobalLinks;
      HaveUpdatedGlobalPkgLinks:=true;
    end;
  end;

begin
  ListOfPackages:=nil;
  MarkNeededPackages;
  HaveUpdatedGlobalPkgLinks:=false;
  for i:=FItems.Count-1 downto 0 do begin
    APackage:=TLazPackage(FItems[i]);
    if (not (lpfNeeded in APackage.Flags))
    or APackage.Modified
    or APackage.IsVirtual
    then
      continue;
    NewFilename:=APackage.Filename;
    if FileExistsCached(APackage.Filename) then begin
      if (APackage.LPKSource<>nil)
      and (not APackage.LPKSource.FileNeedsUpdate(IgnoreModifiedFlag)) then
        continue;
      // a lpk has changed, this might include dependencies => reload lpl files
      UpdateGlobalLinks;
    end else begin
      // lpk has vanished -> search alternative => reload lpl files
      UpdateGlobalLinks;
      NewFilename:=PackageGraph.FindAlternativeLPK(APackage);
      if (NewFilename='') and (APackage.Missing or (APackage.LPKSource=nil)) then
        continue; // no lpk found again => do not show again
    end;
    if ListOfPackages=nil then
      ListOfPackages:=TStringList.Create;
    ListOfPackages.AddObject(NewFilename,APackage);
  end;
end;

procedure TLazPackageGraph.IncChangeStamp;
begin
  {$push}{$R-}  // range check off
  if FUpdateLock = 0 then
    Inc(FChangeStamp)
  else
    Inc(FLockedChangeStamp)
  {$pop}
end;

procedure TLazPackageGraph.SortDependencyListTopologicallyOld(
  var FirstDependency: TPkgDependency; TopLevelFirst: boolean);
// Sort dependency list topologically.
// If TopLevelFirst is true then packages that need others come first
var
  Dependency: TPkgDependency;
  BucketStarts: PInteger;
  MaxLvl: Integer;
  BucketCount: Integer;
  DependencyCount: Integer;
  Dependencies: PPkgDependency;
  i: Integer;
  j: Integer;
  CurLvl: LongInt;
  List: TFPList;
begin
  GetAllRequiredPackages(nil,FirstDependency,List);
  List.Free;

  // Bucket sort dependencies
  MaxLvl:=0;
  Dependency:=FirstDependency;
  DependencyCount:=0;
  while Dependency<>nil do begin
    if Dependency.RequiredPackage<>nil then begin
      if MaxLvl<Dependency.RequiredPackage.TopologicalLevel then
        MaxLvl:=Dependency.RequiredPackage.TopologicalLevel;
    end;
    Dependency:=Dependency.NextRequiresDependency;
    inc(DependencyCount);
  end;
  if (MaxLvl=0) or (DependencyCount<=1) then exit;
  
  //debugln('TLazPackageGraph.SortDependencyListTopologically A MaxLvl=',dbgs(MaxLvl),' ',dbgs(DependencyCount));
  // compute BucketStarts
  BucketCount:=MaxLvl+1;
  GetMem(BucketStarts,SizeOf(Integer)*BucketCount);
  FillChar(BucketStarts^,SizeOf(Integer)*BucketCount,0);
  Dependency:=FirstDependency;
  while Dependency<>nil do begin
    if Dependency.RequiredPackage<>nil then
      CurLvl:=Dependency.RequiredPackage.TopologicalLevel
    else
      CurLvl:=0;
    if CurLvl+1<BucketCount then
      inc(BucketStarts[CurLvl+1]);
    Dependency:=Dependency.NextRequiresDependency;
  end;
  for i:=2 to MaxLvl do
    BucketStarts[i]:=BucketStarts[i]+BucketStarts[i-1];
  BucketStarts[0]:=0;

  // put Dependencies into buckets
  GetMem(Dependencies,SizeOf(Pointer)*DependencyCount);
  FillChar(Dependencies^,SizeOf(Pointer)*DependencyCount,0);
  Dependency:=FirstDependency;
  while Dependency<>nil do begin
    if Dependency.RequiredPackage<>nil then
      CurLvl:=Dependency.RequiredPackage.TopologicalLevel
    else
      CurLvl:=0;
    if Dependencies[BucketStarts[CurLvl]]<>nil then
      RaiseGDBException('');
    Dependencies[BucketStarts[CurLvl]]:=Dependency;
    inc(BucketStarts[CurLvl]);
    Dependency:=Dependency.NextRequiresDependency;
  end;

  // optional: reverse order
  if TopLevelFirst then begin
    i:=0;
    j:=DependencyCount-1;
    while (i<j) do begin
      Dependency:=Dependencies[i];
      Dependencies[i]:=Dependencies[j];
      Dependencies[j]:=Dependency;
      inc(i);
      dec(j);
    end;
  end;

  // commit order
  FirstDependency:=Dependencies[0];
  for i:=0 to DependencyCount-1 do begin
    Dependency:=Dependencies[i];
    //debugln('TLazPackageGraph.SortDependencyListTopologically A ',Dependency.AsString);
    if i=0 then
      Dependency.PrevDependency[pdlRequires]:=nil
    else
      Dependency.PrevDependency[pdlRequires]:=Dependencies[i-1];
    if i=DependencyCount-1 then
      Dependency.NextDependency[pdlRequires]:=nil
    else
      Dependency.NextDependency[pdlRequires]:=Dependencies[i+1];
  end;

  // clean up
  FreeMem(BucketStarts);
  FreeMem(Dependencies);
end;

function TLazPackageGraph.CheckIfPackageCanBeClosed(APackage: TLazPackage
  ): boolean;
begin
  MarkNeededPackages;
  Result:=lpfNeeded in APackage.Flags;
end;

function TLazPackageGraph.PackageIsNeeded(APackage: TLazPackage): boolean;
// check if package is currently in use (installed, autoinstall, editor open,
// or used by a project)
// !!! it does not check if any needed package needs this package
var
  ADependency: TPkgDependency;
begin
  Result:=true;
  // check if package is open, installed or will be installed
  if (APackage.Installed<>pitNope) or (APackage.AutoInstall<>pitNope)
  or APackage.Modified
  or (APackage.Editor<>nil)
  or (APackage.HoldPackageCount>0) then
  begin
    exit;
  end;
  // check if used by project
  ADependency:=APackage.FirstUsedByDependency;
  while ADependency<>nil do begin
    if ADependency.Owner is TLazProject then
      exit;
    ADependency:=ADependency.NextUsedByDependency;
  end;
  Result:=false;
end;

function TLazPackageGraph.PackageCanBeReplaced(
  OldPackage, NewPackage: TLazPackage): boolean;
begin
  if SysUtils.CompareText(OldPackage.Name,NewPackage.Name)<>0 then
    RaiseGDBException('TLazPackageGraph.PackageCanBeReplaced');

  Result:=true;
end;

procedure TLazPackageGraph.RegisterStaticBasePackages;
begin
  BeginUpdate(true);
  
  // IDE built-in packages
  if Assigned(OnTranslatePackage) then OnTranslatePackage(CodeToolsPackage);

  EndUpdate;
end;

procedure TLazPackageGraph.RegisterStaticPackage(APackage: TLazPackage;
  RegisterProc: TRegisterProc);
begin
  if AbortRegistration then exit;
  //DebugLn(['TLazPackageGraph.RegisterStaticPackage ',APackage.IDAsString]);
  RegistrationPackage:=APackage;
  if Assigned(OnTranslatePackage) then
    OnTranslatePackage(APackage);
  CallRegisterProc(RegisterProc);
  APackage.Registered:=true;
  RegistrationPackage:=nil;
end;

procedure TLazPackageGraph.CallRegisterProc(RegisterProc: TRegisterProc);
begin
  if AbortRegistration then exit;

  // check registration procedure
  if RegisterProc=nil then begin
    RegistrationError(lisPkgSysRegisterProcedureIsNil);
    exit;
  end;
  {$IFNDEF StopOnRegError}
  try
  {$ENDIF}
    // call the registration procedure
    RegisterProc();
  {$IFNDEF StopOnRegError}
  except
    on E: Exception do begin
      RegistrationError(E.Message);
    end;
  end;
  {$ENDIF}
end;

procedure TLazPackageGraph.AddDependencyToPackage(APackage: TLazPackage;
  Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  APackage.AddRequiredDependency(Dependency);
  Dependency.LoadPackageResult:=lprUndefined;
  OpenDependency(Dependency,false);
  EndUpdate;
end;

procedure TLazPackageGraph.AddDependencyToPackage(APackage,
  RequiredPackage: TLazPackage);
var
  NewDependency: TPkgDependency;
begin
  NewDependency:=TPkgDependency.Create;
  NewDependency.DependencyType:=pdtLazarus;
  NewDependency.PackageName:=RequiredPackage.Name;
  AddDependencyToPackage(APackage,NewDependency);
end;

procedure TLazPackageGraph.RemoveDependencyFromPackage(APackage: TLazPackage;
  Dependency: TPkgDependency; AddToRemovedList: boolean);
begin
  BeginUpdate(true);
  if AddToRemovedList then
    APackage.RemoveRequiredDependency(Dependency)
  else
    APackage.DeleteRequiredDependency(Dependency);
  IncreaseBuildMacroChangeStamp;
  EndUpdate;
end;
{
procedure TLazPackageGraph.ChangeDependency(Dependency, NewDependency: TPkgDependency);
begin
  if Dependency.Compare(NewDependency)=0 then exit;
  BeginUpdate(true);
  Dependency.Assign(NewDependency);
  Dependency.LoadPackageResult:=lprUndefined;
  IncreaseBuildMacroChangeStamp;
  OpenDependency(Dependency,false);
  DoDependencyChanged(Dependency);
  EndUpdate;
end;
}
function TLazPackageGraph.OpenDependency(Dependency: TPkgDependency;
  ShowAbort: boolean): TLoadPackageResult;

  procedure OpenFile(AFilename: string);
  var
    PkgLink: TPackageLink;
  begin
    PkgLink:=LazPackageLinks.AddUserLink(AFilename, Dependency.PackageName);
    if (PkgLink<>nil) then begin
      PkgLink.Reference;
      try
        if OpenDependencyWithPackageLink(Dependency,PkgLink,false)<>mrOk then
          LazPackageLinks.RemoveUserLink(PkgLink);
      finally
        PkgLink.Release;
      end;
    end;
  end;

var
  ANode: TAVLTreeNode;
  CurDir: String;
  AFilename: String;
  MsgResult: TModalResult;
  APackage: TLazPackage;
  PreferredFilename: string;
  PkgLink: TPackageLink;
  IgnoreFiles: TFilenameToStringTree;
  i: Integer;
begin
  if Dependency.LoadPackageResult=lprUndefined then begin
    if pvPkgSearch in Verbosity then
      debugln('Info: (lazarus) Open dependency '+Dependency.AsString(true,true)+' ...');
    //debugln(['TLazPackageGraph.OpenDependency ',Dependency.PackageName,' ',Dependency.DefaultFilename,' Prefer=',Dependency.PreferDefaultFilename]);
    BeginUpdate(false);
    // search compatible package in opened packages
    ANode:=FindNodeOfDependency(Dependency,fpfSearchEverywhere);
    if (ANode<>nil) then begin
      // there is already a package that fits name and version
      APackage:=TLazPackage(ANode.Data);
      Dependency.RequiredPackage:=APackage;
      Dependency.LoadPackageResult:=lprSuccess;
      if pvPkgSearch in Verbosity then
        debugln(['Info: (lazarus) Open dependency ['+Dependency.PackageName+']: Success: was already loaded']);
    end;
    // load preferred package
    if (Dependency.DefaultFilename<>'') and Dependency.PreferDefaultFilename
    then begin
      PreferredFilename:=Dependency.FindDefaultFilename;
      //debugln(['TLazPackageGraph.OpenDependency checking preferred Prefer=',PreferredFilename]);
      if (PreferredFilename<>'')
      and ((Dependency.RequiredPackage=nil)
        or ((Dependency.RequiredPackage.FindUsedByDepPrefer(Dependency)=nil)
            and (CompareFilenames(PreferredFilename,Dependency.RequiredPackage.Filename)<>0)))
      then begin
        if pvPkgSearch in Verbosity then
          debugln(['Info: (lazarus) Open dependency ['+Dependency.PackageName+']: trying resolved preferred filename: "'+PreferredFilename+'" ...']);
        OpenFile(PreferredFilename);
      end;
    end;
    if Dependency.LoadPackageResult=lprUndefined then begin
      // no compatible package yet open
      Dependency.RequiredPackage:=nil;
      Dependency.LoadPackageResult:=lprNotFound;
      APackage:=FindPackageWithName(Dependency.PackageName,nil);
      if APackage=nil then begin
        // no package with same name open
        if Dependency.DependencyType=pdtLazarus then begin
          // -> try package links
          IgnoreFiles:=nil;
          try
            repeat
              PkgLink:=LazPackageLinks.FindLinkWithDependencyWithIgnore(Dependency,IgnoreFiles);
              if (PkgLink=nil) then break;
              //debugln(['TLazPackageGraph.OpenDependency PkgLink=',PkgLink.GetEffectiveFilename,' global=',PkgLink.Origin=ploGlobal]);
              PkgLink.Reference;
              try
                MsgResult:=OpenDependencyWithPackageLink(Dependency,PkgLink,ShowAbort);
                if MsgResult=mrOk then break;
                if IgnoreFiles=nil then
                  IgnoreFiles:=TFilenameToStringTree.Create(false);
                IgnoreFiles[PkgLink.GetEffectiveFilename]:='1';
                LazPackageLinks.RemoveUserLink(PkgLink);
              finally
                PkgLink.Release;
              end;
            until MsgResult=mrAbort;
          finally
            IgnoreFiles.Free;
          end;
          // try defaultfilename
          if (Dependency.LoadPackageResult=lprNotFound)
          and (Dependency.DefaultFilename<>'') then begin
            AFilename:=Dependency.FindDefaultFilename;
            if AFilename<>'' then begin
              if pvPkgSearch in Verbosity then
                debugln(['Info: (lazarus) Open dependency ['+Dependency.PackageName+']: trying resolved default filename: "'+PreferredFilename+'" ...']);
              OpenFile(AFilename);
            end;
          end;
          // try in owner directory (some projects put all their packages into
          //   one directory)
          if Dependency.LoadPackageResult=lprNotFound then begin
            CurDir:=GetDependencyOwnerDirectory(Dependency);
            if (CurDir<>'') then begin
              if pvPkgSearch in Verbosity then
                debugln(['Info: (lazarus) Open dependency ['+Dependency.PackageName+']: trying in owner directory "'+AppendPathDelim(CurDir)+'" ...']);
              AFilename:=CodeToolBoss.DirectoryCachePool.FindDiskFilename(
                           AppendPathDelim(CurDir)+Dependency.PackageName+'.lpk');
              if FileExistsCached(AFilename) then begin
                OpenFile(AFilename);
              end;
            end;
          end;
          // try a package that provides this package
          if Dependency.LoadPackageResult=lprNotFound then begin
            for i:=0 to Count-1 do begin
              APackage:=Packages[i];
              if APackage=Dependency.Owner then continue;
              if APackage.ProvidesPackage(Dependency.PackageName) then begin
                Dependency.RequiredPackage:=APackage;
                Dependency.LoadPackageResult:=lprSuccess;
                if pvPkgSearch in Verbosity then
                  debugln(['Info: (lazarus) Open dependency ['+Dependency.PackageName+']: Success. Package "'+APackage.IDAsString+'" provides '+Dependency.AsString]);
                break;
              end;
            end;
          end;
        end else begin
          // FPMake-dependency
          if TFppkgHelper.Instance.HasPackage(Dependency.PackageName) then
            Dependency.LoadPackageResult:=lprSuccess
          else
            Dependency.LoadPackageResult:=lprNotFound;
        end;
      end else begin
        // there is already a package with this name, but wrong version open
        // -> unable to load this dependency due to conflict
        debugln('Error: (lazarus) Open dependency found incompatible package: searched for '+Dependency.AsString(true)+', but found '+APackage.IDAsString);
        if IsStaticBasePackage(APackage.Name) then
        begin
          debugln(['Note: (lazarus) LazarusDir="',EnvironmentOptions.GetParsedLazarusDirectory,'"']);
          // wrong base package
          if (EnvironmentOptions.LazarusDirectory='')
          or (not DirPathExistsCached(EnvironmentOptions.GetParsedLazarusDirectory))
          then begin
            // the lazarus directory is not set
            debugln(['Note: (lazarus) The Lazarus directory is not set. Pass parameter --lazarusdir.']);
          end else if not DirPathExistsCached(LazPackageLinks.GetGlobalLinkDirectory)
          then begin
            debugln(['Note: (lazarus) The lpl directory is missing. Check that the Lazarus (--lazarusdir) directory is correct.']);
          end;
        end;
        if APackage.Missing then
        begin
          debugln(['Note: (lazarus) The lpk (',APackage.Filename,') is missing for dependency=',Dependency.AsString])
        end;
        Dependency.LoadPackageResult:=lprLoadError;
      end;
    end;
    fChanged:=true;
    IncreaseBuildMacroChangeStamp;
    EndUpdate;
  end;
  Result:=Dependency.LoadPackageResult;
end;

function TLazPackageGraph.FindAlternativeLPK(APackage: TLazPackage): string;
var
  IgnoreFiles: TFilenameToStringTree;

  procedure IgnoreLPK(LPKFilename: string);
  begin
    IgnoreFiles[LPKFilename]:='1';
  end;

  function ParseLPK(var LPKFilename: string; Version: TPkgVersion): boolean;
  var
    Code: TCodeBuffer;
    XMLConfig: TXMLConfig;
    Path: String;
    FileVersion: Integer;
  begin
    Result:=false;
    LPKFilename:=TrimFilename(LPKFilename);
    if IgnoreFiles[LPKFilename]='1' then exit;
    IgnoreLPK(LPKFilename);
    if not FilenameIsAbsolute(LPKFilename) then exit;
    Code:=CodeToolBoss.LoadFile(LPKFilename,true,false);
    if Code=nil then exit;
    try
      XMLConfig:=TXMLConfig.CreateWithSource(LPKFilename,Code.Source);
      try
        Path:='Package/';
        FileVersion:=XMLConfig.GetValue(Path+'Version',0);
        PkgVersionLoadFromXMLConfig(Version,XMLConfig,Path+'Version/',FileVersion);
        Result:=true;
      finally
        XMLConfig.Free;
      end;
    except
      on E: Exception do begin
        debugln(['Error: (lazarus) error reading "'+LPKFilename+'": '+E.Message]);
      end;
    end;
  end;

var
  Dependency: TPkgDependency;
  Version: TPkgVersion;
  PkgLink: TPackageLink;
  Filename: String;
  BaseDir: String;
begin
  Version:=TPkgVersion.Create;
  IgnoreFiles:=TFilenameToStringTree.Create(false);
  try
    // first check for preferred filenames in dependencies
    Dependency:=APackage.FirstUsedByDependency;
    while Dependency<>nil do begin
      if (Dependency.DefaultFilename<>'') and Dependency.PreferDefaultFilename
      then begin
        Result:=Dependency.FindDefaultFilename;
        if ParseLPK(Result,Version) then
          exit;
      end;
      Dependency:=Dependency.NextUsedByDependency;
    end;

    // find nearest package link to old lpk
    // for example
    //   if old was /path/to/lazarus/comp/bla.lpk
    //   then a /path/to/lazarus/comp/design/bla.lpk
    //   is better than a /path/to/other/lazarus/comp/bla.lpk
    Dependency:=APackage.FirstUsedByDependency;
    if Dependency<>nil then begin
      Result:='';
      BaseDir:=TrimFilename(APackage.Directory);
      repeat
        PkgLink:=LazPackageLinks.FindLinkWithDependencyWithIgnore(Dependency,IgnoreFiles);
        if PkgLink=nil then break;
        Filename:=PkgLink.GetEffectiveFilename;
        if ParseLPK(Filename,Version) then begin
          // candidate found
          if (Result='')
          or (length(CreateRelativePath(Filename,BaseDir))<length(CreateRelativePath(Result,BaseDir)))
          then
            Result:=Filename;
        end;
      until false;
      if Result<>'' then exit;
    end;

    // last check for default filenames in dependencies
    Dependency:=APackage.FirstUsedByDependency;
    while Dependency<>nil do begin
      if (Dependency.DefaultFilename<>'')
      and (not Dependency.PreferDefaultFilename) then
      begin
        Result:=Dependency.FindDefaultFilename;
        if ParseLPK(Result,Version) then
          exit;
      end;
      Dependency:=Dependency.NextUsedByDependency;
    end;

    // nothing found via dependencies
    // search in links
    PkgLink:=LazPackageLinks.FindLinkWithPkgNameWithIgnore(APackage.Name,IgnoreFiles);
    if PkgLink<>nil then begin
      Result:=PkgLink.GetEffectiveFilename;
      exit;
    end;
  finally
    IgnoreFiles.Free;
    Version.Free;
  end;
  Result:='';
end;

procedure TLazPackageGraph.OpenInstalledDependency(Dependency: TPkgDependency;
  InstallType: TPackageInstallType; var Quiet: boolean);
var
  BrokenPackage: TLazPackage;
  CurResult: TModalResult;
  IsBasePkg: Boolean;
begin
  OpenDependency(Dependency,false);
  if Dependency.LoadPackageResult<>lprSuccess then begin
    // a valid lpk file of the installed package can not be found
    IsBasePkg:=IsStaticBasePackage(Dependency.PackageName);
    // -> create a broken package
    BrokenPackage:=TLazPackage.Create;
    with BrokenPackage do begin
      BeginUpdate;
      Missing:=true;
      UserReadOnly:=true;
      Name:=Dependency.PackageName;
      Filename:='';
      Version.SetValues(0,0,0,0);
      Author:='?';
      License:='?';
      AutoUpdate:=pupManually;
      Description:=lisPkgSysThisPackageIsInstalledButTheLpkFileWasNotFound;
      PackageType:=lptDesignTime;
      Installed:=pitStatic;
      AutoInstall:=pitNope;
      if IsBasePkg then
        AutoInstall:=pitStatic
      else
        AutoInstall:=pitNope;
      CompilerOptions.UnitOutputDirectory:='';

      // add lazarus registration unit path
      UsageOptions.UnitPath:='';

      Modified:=false;
      OnModifySilently:=@PkgModify;
      EndUpdate;
    end;
    AddPackage(BrokenPackage);
    //DebugLn('TLazPackageGraph.OpenInstalledDependency ',BrokenPackage.IDAsString,' ',dbgs(ord(BrokenPackage.AutoInstall)));
    if (not Quiet) and DirPathExistsCached(LazPackageLinks.GetGlobalLinkDirectory)
    then begin
      // tell the user
      CurResult:=IDEQuestionDialog(lisPkgSysPackageFileNotFound,
        Format(lisPkgSysThePackageIsInstalledButNoValidPackageFileWasFound,
               [BrokenPackage.Name, LineEnding]),
        mtError, [mrOk, mrYesToAll, lisSkipTheseWarnings]);
      if CurResult=mrYesToAll then
        Quiet:=true;
    end;

    // open it
    if OpenDependency(Dependency,false)<>lprSuccess then
      RaiseGDBException('TLazPackageGraph.OpenInstalledDependency');
  end;
  Dependency.RequiredPackage.Installed:=InstallType;
end;

procedure TLazPackageGraph.OpenRequiredDependencyList(
  FirstDependency: TPkgDependency);
var
  Dependency: TPkgDependency;
begin
  Dependency:=FirstDependency;
  while Dependency<>nil do begin
    OpenDependency(Dependency,false);
    Dependency:=Dependency.NextRequiresDependency;
  end;
end;

procedure TLazPackageGraph.MoveRequiredDependencyUp(ADependency: TPkgDependency);
begin
  if (ADependency=nil) or (ADependency.Removed) or (ADependency.Owner=nil)
  or (ADependency.PrevRequiresDependency=nil)
  or (not (ADependency.Owner is TLazPackage))
  then exit;
  BeginUpdate(true);
  TLazPackage(ADependency.Owner).MoveRequiredDependencyUp(ADependency);
  EndUpdate;
end;

procedure TLazPackageGraph.MoveRequiredDependencyDown(ADependency: TPkgDependency);
begin
  if (ADependency=nil) or (ADependency.Removed) or (ADependency.Owner=nil)
  or (ADependency.NextRequiresDependency=nil)
  or (not (ADependency.Owner is TLazPackage))
  then exit;
  BeginUpdate(true);
  TLazPackage(ADependency.Owner).MoveRequiredDependencyDown(ADependency);
  EndUpdate;
end;

procedure TLazPackageGraph.IterateComponentClasses(APackage: TLazPackage;
  Event: TIterateComponentClassesEvent; WithUsedPackages,
  WithRequiredPackages: boolean);
var
  ARequiredPackage: TLazPackage;
  ADependency: TPkgDependency;
begin
  APackage.IterateComponentClasses(Event,WithUsedPackages);
  // iterate through all required packages
  if WithRequiredPackages then begin
    ADependency:=APackage.FirstRequiredDependency;
    while ADependency<>nil do begin
      ARequiredPackage:=FindOpenPackage(ADependency,[fpfSearchInInstalledPckgs]);
      if ARequiredPackage<>nil then begin
        ARequiredPackage.IterateComponentClasses(Event,false);
      end;
      ADependency:=ADependency.NextRequiresDependency;
    end;
  end;
end;

procedure TLazPackageGraph.IterateAllComponentClasses(
  Event: TIterateComponentClassesEvent);
var
  Cnt: Integer;
  i: Integer;
begin
  Cnt:=Count;
  for i:=0 to Cnt-1 do
    IterateComponentClasses(Packages[i],Event,false,false);
end;

procedure TLazPackageGraph.IteratePackages(Flags: TFindPackageFlags;
  Event: TIteratePackagesEvent);
var
  CurPkg: TLazPackage;
  i: Integer;
begin
  // iterate opened packages
  for i:=0 to FItems.Count-1 do begin
    CurPkg:=Packages[i];
    // check installed packages
    if ((fpfSearchInInstalledPckgs in Flags) and (CurPkg.Installed<>pitNope))
    // check autoinstall packages
    or ((fpfSearchInAutoInstallPckgs in Flags) and (CurPkg.AutoInstall<>pitNope))
    // check packages with opened editor
    or ((fpfSearchInPckgsWithEditor in Flags) and (CurPkg.Editor<>nil))
    then begin
      Event(CurPkg);
    end;
  end;
  // iterate in package links
  if (fpfSearchInPkgLinks in Flags) then begin
    LazPackageLinks.IteratePackages(fpfPkgLinkMustExist in Flags,Event);
  end;
end;

procedure TLazPackageGraph.IteratePackagesSorted(Flags: TFindPackageFlags;
  Event: TIteratePackagesEvent);
var
  ANode: TAVLTreeNode;
  CurPkg: TLazPackage;
begin
  ANode:=FTree.FindLowest;
  while ANode<>nil do begin
    CurPkg:=TLazPackage(ANode.Data);
    // check installed packages
    if ((fpfSearchInInstalledPckgs in Flags) and (CurPkg.Installed<>pitNope))
    // check autoinstall packages
    or ((fpfSearchInAutoInstallPckgs in Flags) and (CurPkg.AutoInstall<>pitNope))
    // check packages with opened editor
    or ((fpfSearchInPckgsWithEditor in Flags) and (CurPkg.Editor<>nil))
    then
      Event(CurPkg);
    ANode:=FTree.FindSuccessor(ANode);
  end;
end;

procedure TLazPackageGraph.GetAllRequiredPackages(APackage: TLazPackage;
  FirstDependency: TPkgDependency; out List, FPMakeList: TFPList;
  Flags: TPkgIntfRequiredFlags; MinPolicy: TPackageUpdatePolicy);
// returns packages in topological order, beginning with the top level package

  procedure GetTopologicalOrder(CurDependency: TPkgDependency;
    out HighestLevel: integer);
  var
    RequiredPackage: TLazPackage;
    Dependency: TPkgDependency;
    DepLevel: integer;
  begin
    HighestLevel:=0;
    while CurDependency<>nil do begin
      Dependency:=CurDependency;
      CurDependency:=CurDependency.NextRequiresDependency;
      //debugln('TLazPackageGraph.GetAllRequiredPackages A ',Dependency.AsString,' ',dbgs(ord(Dependency.LoadPackageResult)),' ',dbgs(ord(lprSuccess)));
      if Dependency.LoadPackageResult<>lprSuccess then continue;
      //debugln('TLazPackageGraph.GetAllRequiredPackages B ',Dependency.AsString);
      if Dependency.DependencyType=pdtLazarus then begin
        RequiredPackage:=Dependency.RequiredPackage;
        if (lpfVisited in RequiredPackage.Flags) then begin
          // already visited
          if HighestLevel<RequiredPackage.TopologicalLevel then
            HighestLevel:=RequiredPackage.TopologicalLevel;
          continue;
        end;
        RequiredPackage.Flags:=RequiredPackage.Flags+[lpfVisited];
        if ord(RequiredPackage.AutoUpdate)<ord(MinPolicy) then
          continue; // skip manually updated packages
        if (pirSkipDesignTimeOnly in Flags)
        and (RequiredPackage.PackageType=lptDesignTime) then
          continue; // skip designtime (only) packages
        if not (pirNotRecursive in Flags) then begin
          GetTopologicalOrder(RequiredPackage.FirstRequiredDependency,DepLevel);
          RequiredPackage.TopologicalLevel:=DepLevel+1;
          if HighestLevel<RequiredPackage.TopologicalLevel then
            HighestLevel:=RequiredPackage.TopologicalLevel;
        end;
        if List=nil then List:=TFPList.Create;
        List.Add(RequiredPackage);
      end else begin
        // FPMake dependency
        // ToDo: Handle package-dependencies (or not?) and version-checks
        if FPMakeList=nil then FPMakeList := TFPList.Create;
        FPMakeList.Add(Dependency);
      end;
      // add package behind its requirements
    end;
  end;

var
  i: Integer;
  j: Integer;
  DepLevel: integer;
begin
  List:=nil;
  FPMakeList:=nil;
  MarkAllPackagesAsNotVisited;
  if APackage<>nil then begin
    FirstDependency:=APackage.FirstRequiredDependency;
    APackage.Flags:=APackage.Flags+[lpfVisited];
  end;
  // create topological list, beginning with the leaves
  GetTopologicalOrder(FirstDependency,DepLevel);
  if List=nil then exit;
  MergeSort(List,@CompareLazPackageTopologicallyAndName);
  if not (pirCompileOrder in Flags) then begin
    // reverse list order
    i:=0;
    j:=List.Count-1;
    while i<j do begin
      List.Exchange(i,j);
      inc(i);
      dec(j);
    end;
  end;
  //for i:=0 to List.Count-1 do
  //  debugln(['TLazPackageGraph.GetAllRequiredPackages ',i,'/',List.Count-1,' ',TLazPackage(List[i]).Name,' ',TLazPackage(List[i]).TopologicalLevel]);
end;

procedure TLazPackageGraph.GetAllRequiredPackages(APackage: TLazPackage;
  FirstDependency: TPkgDependency; out List: TFPList;
  Flags: TPkgIntfRequiredFlags; MinPolicy: TPackageUpdatePolicy);
var
  FPMakeList: TFPList;
begin
  FPMakeList := nil;
  try
    GetAllRequiredPackages(APackage, FirstDependency, List, FPMakeList, Flags, MinPolicy);
  finally
    FPMakeList.Free;
  end;
end;

procedure TLazPackageGraph.GetConnectionsTree(FirstDependency: TPkgDependency;
  var PkgList: TFPList; var Tree: TPkgPairTree);
  
  procedure AddConnection(Pkg1, Pkg2: TLazPackage);
  begin
    if Pkg1=Pkg2 then exit;
    if Tree=nil then
      Tree:=TPkgPairTree.Create;
    Tree.AddPairIfNotExists(Pkg1,Pkg2);
  end;
  
  procedure AddConnections(StartDependency: TPkgDependency);
  // add every connection between owner and required package
  // and between two children
  var
    OwnerPackage: TLazPackage;
    Dependency1: TPkgDependency;
    Dependency2: TPkgDependency;
    Pkg1: TLazPackage;
    Pkg2: TLazPackage;
  begin
    if StartDependency=nil then exit;
    if (StartDependency.Owner is TLazPackage) then
      OwnerPackage:=TLazPackage(StartDependency.Owner)
    else
      OwnerPackage:=nil;
    Dependency1:=StartDependency;
    while Dependency1<>nil do begin
      Pkg1:=Dependency1.RequiredPackage;
      if Pkg1<>nil then begin
        // add connection between owner and required package
        if OwnerPackage<>nil then
          AddConnection(OwnerPackage,Pkg1);
        // add connections between any two direct required packages
        Dependency2:=StartDependency;
        while Dependency2<>nil do begin
          Pkg2:=Dependency2.RequiredPackage;
          if Pkg2<>nil then
            AddConnection(Pkg1,Pkg2);
          Dependency2:=Dependency2.NextDependency[pdlRequires];
        end;
      end;
      Dependency1:=Dependency1.NextDependency[pdlRequires];
    end;
  end;
  
var
  i: Integer;
  Pkg: TLazPackage;
begin
  if Tree<>nil then Tree.FreeAndClear;
  GetAllRequiredPackages(nil,FirstDependency,PkgList);
  if PkgList=nil then exit;
  AddConnections(FirstDependency);
  for i:=0 to PkgList.Count-1 do begin
    Pkg:=TLazPackage(PkgList[i]);
    AddConnections(Pkg.FirstRequiredDependency);
  end;
end;

initialization
  PackageGraph:=nil;

end.



{
 /***************************************************************************
                  project.pp  -  project utility class file
                  -----------------------------------------
          TProject is responsible for managing a complete project.


              Initial Revision  : Sun Mar 28 23:15:32 CST 1999


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
unit Project;

{$mode objfpc}{$H+}

{$ifdef Trace}
  {$ASSERTIONS ON}
{$endif}

interface

{$I ide.inc}

uses
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  // RTL + FCL
  Classes, SysUtils, TypInfo,
  // LCL
  LCLProc, Forms, Controls, Dialogs,
  // CodeTools
  CodeToolsConfig, ExprEval, DefineTemplates, BasicCodeTools, CodeToolsCfgScript,
  LinkScanner, CodeToolManager, CodeCache, CodeTree, FileProcs, StdCodeTools,
  // LazUtils
  FPCAdds, LazUtilities, FileUtil, LazFileUtils, LazFileCache, LazMethodList,
  LazLoggerBase, FileReferenceList, LazUTF8, Laz2_XMLCfg, Maps,
  // IDEIntf
  PropEdits, UnitResources, EditorSyntaxHighlighterDef,
  CompOptsIntf, ProjectIntf, MacroIntf, MacroDefIntf, SrcEditorIntf,
  IDEOptionsIntf, IDEOptEditorIntf, IDEDialogs, LazIDEIntf, PackageIntf,
  // IDE
  CompOptsModes, ProjectResources, LazConf, ProjectIcon,
  IDECmdLine, IDEProcs, CompilerOptions, RunParamsOpts, ModeMatrixOpts,
  TransferMacros, ProjectDefs, EditDefineTree,
  LazarusIDEStrConsts, InputHistory, ProjPackCommon, PackageDefs, PackageSystem;

type
  TUnitInfo = class;
  TProject = class;

  TOnFileBackup = function(const FileToBackup: string):TModalResult of object;
  TOnUnitNameChange = procedure(AnUnitInfo: TUnitInfo;
       const OldUnitName, NewUnitName: string;
       CheckIfAllowed: boolean;
       var Allowed: boolean) of object;
  TOnLoadProjectInfo = procedure(TheProject: TProject; XMLConfig: TXMLConfig;
                                 Merge: boolean) of object;
  TOnSaveProjectInfo = procedure(TheProject: TProject;
               XMLConfig: TXMLConfig; WriteFlags: TProjectWriteFlags) of object;
  TOnChangeProjectInfoFile = procedure(TheProject: TProject) of object;

  TOnSaveUnitSessionInfoInfo = procedure(AUnitInfo: TUnitInfo) of object;

  TUnitInfoList = (
    uilPartOfProject,
    uilWithEditorIndex,
    uilWithComponent,
    uilLoaded,
    uilAutoRevertLocked
    );
    
  TUnitCompDependencyList = (
    ucdlRequires,
    ucdlUsedBy
    );
  TUnitCompDependencyType = (
    ucdtAncestor, // RequiresUnit is ancestor
    ucdtProperty, // a property references RequiresUnit's component or sub component
    ucdtOldProperty, // like ucdtProperty, but for the old state before the revert
    ucdtInlineClass // RequiresUnit is class of an inline component
    );
  TUnitCompDependencyTypes = set of TUnitCompDependencyType;

const
  AllUnitCompDependencyTypes = [low(TUnitCompDependencyType)..high(TUnitCompDependencyType)];
  // Names for extra buildmodes which may be created automatically.
  DebugModeName = 'Debug';
  ReleaseModeName = 'Release';

type

  { TUCDComponentProperty }

  TUCDComponentProperty = class
  public
    UsedByPropPath: string;
    RequiresPropPath: string;
    constructor Create(const SrcPath, DestPath: string);
  end;

  { TUnitComponentDependency }

  TUnitComponentDependency = class
  private
    FCompProps: TFPList;// list of TUCDComponentProperty
    FRequiresUnit: TUnitInfo;
    FTypes: TUnitCompDependencyTypes;
    FUsedByUnit: TUnitInfo;
    function GetCompPropCount: integer;
    function GetCompProps(Index: integer): TUCDComponentProperty;
    procedure SetRequiresUnit(const AValue: TUnitInfo);
    procedure SetTypes(const AValue: TUnitCompDependencyTypes);
    procedure SetUsedByUnit(const AValue: TUnitInfo);
  public
    NextDependency,PrevDependency: array[TUnitCompDependencyList] of TUnitComponentDependency;
    constructor Create;
    destructor Destroy; override;
    procedure ClearComponentProperties;
    function NextUsedByDependency: TUnitComponentDependency;
    function PrevUsedByDependency: TUnitComponentDependency;
    function NextRequiresDependency: TUnitComponentDependency;
    function PrevRequiresDependency: TUnitComponentDependency;
    procedure AddToList(var FirstDependency: TUnitComponentDependency;
                        ListType: TUnitCompDependencyList);
    procedure RemoveFromList(var FirstDependency: TUnitComponentDependency;
                             ListType: TUnitCompDependencyList);
    property RequiresUnit: TUnitInfo read FRequiresUnit write SetRequiresUnit;
    property UsedByUnit: TUnitInfo read FUsedByUnit write SetUsedByUnit;
    property Types: TUnitCompDependencyTypes read FTypes write SetTypes;
    property CompPropCount: integer read GetCompPropCount;
    property CompProps[Index: integer]: TUCDComponentProperty read GetCompProps;
    function FindUsedByPropPath(const UsedByPropPath: string): TUCDComponentProperty;
    function SetUsedByPropPath(const UsedByPropPath, RequiresPropPath: string
                               ): TUCDComponentProperty;
    function CreatePropPath(AComponent: TComponent;
                            const PropName: string = ''): string;
  end;

  //---------------------------------------------------------------------------

  TUnitInfoFlag = (
    uifComponentUsedByDesigner,
    uifComponentIndirectlyUsedByDesigner,
    uifMarked,
    uifInternalFile    // data from an internal source (e.g. an editor macro (pascal script) from memory)
    );
  TUnitInfoFlags = set of TUnitInfoFlag;

  { TUnitEditorInfo }

  TUnitEditorInfo = class
  private
    FEditorComponent: TSourceEditorInterface;
    FUnitInfo: TUnitInfo;
    procedure SetEditorComponent(const AValue: TSourceEditorInterface);
  private
    FIsLocked: Boolean;
    FIsVisibleTab: Boolean;
    FPageIndex: integer;
    FWindowID: integer;
    FTopLine: integer;
    FCursorPos: TPoint;  // physical (screen) position
    FFoldState: String;
    // Todo: FCustomHighlighter is only ever set to false, and not stored in XML
    FCustomHighlighter: boolean; // do not change highlighter on file extension change
    FSyntaxHighlighter: TLazSyntaxHighlighter;
    procedure SetCursorPos(const AValue: TPoint);
    procedure SetFoldState(AValue: String);
    procedure SetIsLocked(const AValue: Boolean);
    procedure SetPageIndex(const AValue: Integer);
    procedure SetIsVisibleTab(const AValue: Boolean);
    procedure SetSyntaxHighlighter(AValue: TLazSyntaxHighlighter);
    procedure SetTopLine(const AValue: Integer);
    procedure SetWindowIndex(const AValue: Integer);
  protected
    procedure Clear;
  public
    constructor Create(aUnitInfo: TUnitInfo);
    destructor Destroy; override;
    property UnitInfo: TUnitInfo read FUnitInfo;
    property EditorComponent: TSourceEditorInterface
             read FEditorComponent write SetEditorComponent;
    procedure LoadFromXMLConfig(XMLConfig: TXMLConfig; const Path: string);
    procedure SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string; SaveFold: Boolean);
  public
    property IsVisibleTab: Boolean read FIsVisibleTab write SetIsVisibleTab;
    property PageIndex: Integer read FPageIndex write SetPageIndex;
    property WindowID: Integer read FWindowID write SetWindowIndex;
    property TopLine: Integer read FTopLine write SetTopLine;
    property CursorPos: TPoint read FCursorPos write SetCursorPos;
    property FoldState: String read FFoldState write SetFoldState;
    property IsLocked: Boolean read FIsLocked  write SetIsLocked;
    property CustomHighlighter: Boolean read FCustomHighlighter write FCustomHighlighter; // SetCustomHighlighter
    property SyntaxHighlighter: TLazSyntaxHighlighter read FSyntaxHighlighter write SetSyntaxHighlighter; // SetSyntaxHighlighter
  end;

  { TUnitEditorInfoList }

  TUnitEditorInfoList = class
  private
    FList: TFPList;
    FUnitInfo: TUnitInfo;
    function GetClosedEditorInfos(Index: Integer): TUnitEditorInfo;
    function GetEditorInfos(Index: Integer): TUnitEditorInfo;
    function GetOpenEditorInfos(Index: Integer): TUnitEditorInfo;
  protected
    procedure ClearEachInfo;
    procedure SortByPageIndex;
    procedure SetLastUsedEditor(AEditor:TSourceEditorInterface);
    procedure MakeUsedEditorInfo(AEditorInfo: TUnitEditorInfo);
    procedure MakeUnUsedEditorInfo(AEditorInfo: TUnitEditorInfo);
    procedure Clear;
  public
    constructor Create(aUnitInfo: TUnitInfo);
    destructor Destroy; override;
    property EditorInfos[Index: Integer]: TUnitEditorInfo read GetEditorInfos; default;
    property OpenEditorInfos[Index: Integer]: TUnitEditorInfo read GetOpenEditorInfos;
    property ClosedEditorInfos[Index: Integer]: TUnitEditorInfo read GetClosedEditorInfos;
    function Count: Integer;
    function OpenCount: Integer;
    function ClosedCount: Integer;
    function IndexOfEditorComponent(anEditor: TSourceEditorInterface): Integer;
    function NewEditorInfo: TUnitEditorInfo;
    procedure Add(AEditorInfo: TUnitEditorInfo);
    procedure Delete(Index: Integer);
    procedure Remove(AEditorInfo: TUnitEditorInfo);
  end;

  { TUnitInfo }

  TUnitInfo = class(TLazProjectFile)
  private
    FComponentFallbackClasses: TStrings;
    FCustomDefaultHighlighter: boolean;
    FDefaultSyntaxHighlighter: TLazSyntaxHighlighter;
    FDisableI18NForLFM: boolean;
    FEditorInfoList: TUnitEditorInfoList;
    FAutoReferenceSourceDir: boolean;
    fAutoRevertLockCount: integer;// =0 means, codetools can auto update from disk
    fBookmarks: TFileBookmarks;
    FBuildFileIfActive: boolean;
    fComponent: TComponent;
    FComponentState: TWindowState; // state of component when we save it
    FResourceBaseClass: TPFComponentBaseClass;
    fComponentName: string; { classname is always T<ComponentName>
         this attribute contains the component name,
         even if the unit is not loaded, or the designer form is not created.
         A component can be for example a TForm or a TDataModule }
    fComponentLFMLoadDate: longint;  // Load time of associated LFM form file.
    fComponentResourceName: string;
    FComponentLastBinStreamSize: TStreamSeekType;
    FComponentLastLFMStreamSize: TStreamSeekType;
    FComponentLastLRSStreamSize: TStreamSeekType;
    FDirectives: TStrings;
    fFileName: string; // with path = saved, without path = not yet saved
    fFileReadOnly: Boolean;
    FFirstRequiredComponent: TUnitComponentDependency;
    FFirstUsedByComponent: TUnitComponentDependency;
    FFlags: TUnitInfoFlags;
    fHasResources: boolean; // source has resource file
    FIgnoreFileDateOnDiskValid: boolean;
    FIgnoreFileDateOnDisk: longint;
    fLoaded: Boolean; // loaded in the source editor, needed to restore open files
    fLoadedDesigner: Boolean; // has a visible designer, needed to restore open designers
    FLoadingComponent: boolean;
    fModified: boolean;
    fNext, fPrev: array[TUnitInfoList] of TUnitInfo;
    fOnFileBackup: TOnFileBackup;
    fOnLoadSaveFilename: TOnLoadSaveFilename;
    FOnUnitNameChange: TOnUnitNameChange;
    FProject: TProject;
    FRevertLockCount: integer;// >0 means IDE is currently reverting this unit
    FRunFileIfActive: boolean;
    FSessionModified: boolean;
    fSource: TCodeBuffer;
    fUsageCount: extended;
    fUserReadOnly: Boolean;
    fSourceChangeStep: LongInt;
    FSourceDirectoryReferenced: boolean;
    FSourceDirNeedReference: boolean;
    fLastDirectoryReferenced: string;
    FSetBookmarLock: Integer;
    FUnitResourceFileformat: TUnitResourcefileFormatClass;

    function ComponentLFMOnDiskHasChanged: boolean;
    function GetEditorInfo(Index: Integer): TUnitEditorInfo;
    function GetHasResources: boolean;
    function GetModified: boolean;
    function GetNextAutoRevertLockedUnit: TUnitInfo;
    function GetNextLoadedUnit: TUnitInfo;
    function GetNextPartOfProject: TUnitInfo;
    function GetNextUnitWithComponent: TUnitInfo;
    function GetNextUnitWithEditorIndex: TUnitInfo;
    function GetOpenEditorInfo(Index: Integer): TUnitEditorInfo;
    function GetPrevAutoRevertLockedUnit: TUnitInfo;
    function GetPrevLoadedUnit: TUnitInfo;
    function GetPrevPartOfProject: TUnitInfo;
    function GetPrevUnitWithComponent: TUnitInfo;
    function GetPrevUnitWithEditorIndex: TUnitInfo;
    function GetUnitResourceFileformat: TUnitResourcefileFormatClass;
    procedure SetAutoReferenceSourceDir(const AValue: boolean);
    procedure SetBuildFileIfActive(const AValue: boolean);
    procedure SetDefaultSyntaxHighlighter(const AValue: TLazSyntaxHighlighter);
    procedure SetDirectives(const AValue: TStrings);
    procedure SetDisableI18NForLFM(const AValue: boolean);
    procedure SetFileReadOnly(const AValue: Boolean);
    procedure SetComponent(const AValue: TComponent);
    procedure SetLoaded(const AValue: Boolean);
    procedure SetLoadedDesigner(const AValue: Boolean);
    procedure SetModified(const AValue: boolean);
    procedure SetProject(const AValue: TProject);
    procedure SetRunFileIfActive(const AValue: boolean);
    procedure SetSessionModified(const AValue: boolean);
    procedure SetSource(ABuffer: TCodeBuffer);
    procedure SetTimeStamps;
    procedure SetUserReadOnly(const NewValue: boolean);
  protected
    function GetFileName: string; override;
    procedure SetFilename(const AValue: string); override;
    procedure SetIsPartOfProject(const AValue: boolean); override;
    procedure UpdateList(ListType: TUnitInfoList; Add: boolean);
    procedure SetInternalFilename(const NewFilename: string);
    procedure SetUnitName(const AValue: string); override;

    procedure UpdateHasCustomHighlighter(aDefaultHighlighter: TLazSyntaxHighlighter);
    procedure UpdatePageIndex;
  public
    constructor Create(ACodeBuffer: TCodeBuffer);
    destructor Destroy; override;
    function GetFileOwner: TObject; override;
    function GetFileOwnerName: string; override;

    function ChangedOnDisk(CompareOnlyLoadSaveTime: boolean; IgnoreModifiedFlag: boolean = False): boolean;
    function IsAutoRevertLocked: boolean;
    function IsReverting: boolean;
    function IsMainUnit: boolean;
    function IsVirtual: boolean;
    function GetDirectory: string;
    function GetFullFilename: string; override;
    function GetShortFilename(UseUp: boolean): string; override;
    function NeedsSaveToDisk: boolean;
    function ReadOnly: boolean;
    function ReadUnitSource(ReadUnitName,Revert:boolean): TModalResult;
    function ShortFilename: string;
    function WriteUnitSource: TModalResult;
    function WriteUnitSourceToFile(const AFileName: string): TModalResult;
    procedure Clear;
    procedure ClearModifieds; override;
    procedure ClearComponentDependencies;
    procedure WriteDebugReportUnitComponentDependencies(Prefix: string);
    procedure IgnoreCurrentFileDateOnDisk;
    procedure IncreaseAutoRevertLock; // do not auto revert from disk
    procedure DecreaseAutoRevertLock;
    function ReadUnitNameFromSource(TryCache: boolean): string;// fetch unit name from source and update property UnitName
    function GetUsesUnitName: string;
    function CreateUnitName: string;
    procedure LoadFromXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                                Merge, IgnoreIsPartOfProject: boolean;
                                FileVersion: integer);
    procedure SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                              SaveData, SaveSession: boolean;
                              UsePathDelim: TPathDelimSwitch);
    procedure UpdateUsageCount(Min, IfBelowThis, IncIfBelow: extended);
    procedure UpdateUsageCount(TheUsage: TUnitUsage; const Factor: TDateTime);
    procedure UpdateSourceDirectoryReference;

    procedure SetSourceText(const SourceText: string; Beautify: boolean = false); override;
    function GetSourceText: string; override;

    // component dependencies
    function AddRequiresComponentDependency(RequiredUnit: TUnitInfo;
                    Types: TUnitCompDependencyTypes
                    ): TUnitComponentDependency;
    procedure RemoveRequiresComponentDependency(RequiredUnit: TUnitInfo;
                    Types: TUnitCompDependencyTypes);
    function FindComponentDependency(RequiredUnit: TUnitInfo
                                     ): TUnitComponentDependency;
    function FindRequiredComponentDependency(MinTypes: TUnitCompDependencyTypes
                                     ): TUnitComponentDependency;
    function FindUsedByComponentDependency(MinTypes: TUnitCompDependencyTypes
                                     ): TUnitComponentDependency;
    function FindAncestorUnit: TUnitInfo;
    procedure ClearUnitComponentDependencies(ClearTypes: TUnitCompDependencyTypes);
    // Bookmarks
    function  AddBookmark(X, Y, ID: integer):integer;
    procedure DeleteBookmark(ID: integer);
    // EditorInfo
    // At any time, any UnitInfo has at least one EditorInfo
    function EditorInfoCount: Integer;
    property EditorInfo[Index: Integer]: TUnitEditorInfo read GetEditorInfo;
    function OpenEditorInfoCount: Integer; // with EditorComponent assigned
    property OpenEditorInfo[Index: Integer]: TUnitEditorInfo read GetOpenEditorInfo;
    function GetClosedOrNewEditorInfo: TUnitEditorInfo;
    procedure SetLastUsedEditor(AEditor:TSourceEditorInterface);
    // Highlighter
    procedure UpdateDefaultHighlighter(aDefaultHighlighter: TLazSyntaxHighlighter);
  public
    { Properties }
    property UnitResourceFileformat: TUnitResourcefileFormatClass read GetUnitResourceFileformat;

    // Unit lists
    property NextUnitWithEditorIndex: TUnitInfo read GetNextUnitWithEditorIndex;
    property PrevUnitWithEditorIndex: TUnitInfo read GetPrevUnitWithEditorIndex;
    property NextUnitWithComponent: TUnitInfo read GetNextUnitWithComponent;
    property PrevUnitWithComponent: TUnitInfo read GetPrevUnitWithComponent;
    property NextLoadedUnit: TUnitInfo read GetNextLoadedUnit;
    property PrevLoadedUnit: TUnitInfo read GetPrevLoadedUnit;
    property NextAutoRevertLockedUnit: TUnitInfo read GetNextAutoRevertLockedUnit;
    property PrevAutoRevertLockedUnit: TUnitInfo read GetPrevAutoRevertLockedUnit;
    property NextPartOfProject: TUnitInfo read GetNextPartOfProject;
    property PrevPartOfProject: TUnitInfo read GetPrevPartOfProject;
  public
    property Bookmarks: TFileBookmarks read FBookmarks write FBookmarks;
    property BuildFileIfActive: boolean read FBuildFileIfActive
                                        write SetBuildFileIfActive;
    property Component: TComponent read fComponent write SetComponent;
    property ComponentName: string read fComponentName write fComponentName;
    property ComponentResourceName: string read fComponentResourceName
                                           write fComponentResourceName;
    property ComponentFallbackClasses: TStrings read FComponentFallbackClasses
      write FComponentFallbackClasses; // classname to componentclass, for not registered classes in lfm
    property ComponentState: TWindowState read FComponentState write FComponentState;
    property ResourceBaseClass: TPFComponentBaseClass read FResourceBaseClass
                                                      write FResourceBaseClass;
    property ComponentLastBinStreamSize: TStreamSeekType
             read FComponentLastBinStreamSize write FComponentLastBinStreamSize;
    property ComponentLastLRSStreamSize: TStreamSeekType
             read FComponentLastLRSStreamSize write FComponentLastLRSStreamSize;
    property ComponentLastLFMStreamSize: TStreamSeekType
             read FComponentLastLFMStreamSize write FComponentLastLFMStreamSize;
    property CustomDefaultHighlighter: boolean
                               read FCustomDefaultHighlighter write FCustomDefaultHighlighter;
    property Directives: TStrings read FDirectives write SetDirectives;
    property DisableI18NForLFM: boolean read FDisableI18NForLFM write SetDisableI18NForLFM;
    property FileReadOnly: Boolean read fFileReadOnly write SetFileReadOnly;
    property FirstRequiredComponent: TUnitComponentDependency
                                                   read FFirstRequiredComponent;
    property FirstUsedByComponent: TUnitComponentDependency
                                                     read FFirstUsedByComponent;
    property Flags: TUnitInfoFlags read FFlags write FFlags;
    property HasResources: boolean read GetHasResources write fHasResources;
    property Loaded: Boolean read fLoaded write SetLoaded;
    property LoadedDesigner: Boolean read fLoadedDesigner write SetLoadedDesigner;
    property LoadingComponent: boolean read FLoadingComponent write FLoadingComponent;
    property Modified: boolean read GetModified write SetModified;// not Session data
    property SessionModified: boolean read FSessionModified write SetSessionModified;
    property OnFileBackup: TOnFileBackup read fOnFileBackup write fOnFileBackup;
    property OnLoadSaveFilename: TOnLoadSaveFilename
                             read fOnLoadSaveFilename write fOnLoadSaveFilename;
    property OnUnitNameChange: TOnUnitNameChange
                                 read FOnUnitNameChange write FOnUnitNameChange;
    property Project: TProject read FProject write SetProject;
    property RunFileIfActive: boolean read FRunFileIfActive write SetRunFileIfActive;
    property Source: TCodeBuffer read fSource write SetSource;
    property DefaultSyntaxHighlighter: TLazSyntaxHighlighter
                               read FDefaultSyntaxHighlighter write SetDefaultSyntaxHighlighter;
    property UserReadOnly: Boolean read fUserReadOnly write SetUserReadOnly;
    property SourceDirectoryReferenced: boolean read FSourceDirectoryReferenced;
    property AutoReferenceSourceDir: boolean read FAutoReferenceSourceDir
                                             write SetAutoReferenceSourceDir;
  end;


  //---------------------------------------------------------------------------

  { TProjectCompilationToolOptions }

  TProjectCompilationToolOptions = class(TCompilationToolOptions)
  private
    FDefaultCompileReasons: TCompileReasons;
    procedure SetDefaultCompileReasons(const AValue: TCompileReasons);
  protected
    procedure SetCompileReasons(const AValue: TCompileReasons); override;
    procedure SubstituteMacros(var s: string); override;
  public
    constructor Create(TheOwner: TLazCompilerOptions); override;
    function CreateDiff(CompOpts: TCompilationToolOptions;
                        Tool: TCompilerDiffTool): boolean; override;
    procedure LoadFromXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                                DoSwitchPathDelims: boolean); override;
    procedure SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                              UsePathDelim: TPathDelimSwitch); override;
    function GetProject: TProject;
  public
    property DefaultCompileReasons: TCompileReasons read FDefaultCompileReasons write SetDefaultCompileReasons;
  end;

  TProjectBuildMode = class;
  
  { TProjectCompilerOptions }

  TProjectCompilerOptions = class(TBaseCompilerOptions)
  private
    FBuildMode: TProjectBuildMode;
    FProject: TProject;
    FCompileReasons: TCompileReasons;
    procedure BeforeReadExec(Sender: TObject);
    procedure AfterWriteExec(Sender: TObject; Restore: boolean);
  protected
    procedure SetTargetCPU(const AValue: string); override;
    procedure SetTargetOS(const AValue: string); override;
    procedure SetCustomOptions(const AValue: string); override;
    procedure SetIncludePaths(const AValue: string); override;
    procedure SetLibraryPaths(const AValue: string); override;
    procedure SetLinkerOptions(const AValue: string); override;
    procedure SetNamespaces(const AValue: string); override;
    procedure SetObjectPath(const AValue: string); override;
    procedure SetSrcPath(const AValue: string); override;
    procedure SetUnitPaths(const AValue: string); override;
    procedure SetUnitOutputDir(const AValue: string); override;
    procedure SetConditionals(AValue: string); override;
    function SubstituteProjectMacros(const s: string;
                                     PlatformIndependent: boolean): string;
  public
    constructor Create(const AOwner: TObject); override;
    destructor Destroy; override;
    function IsActive: boolean; override;
    class function GetInstance: TAbstractIDEOptions; override;
    class function GetGroupCaption: string; override;
    procedure Clear; override;
    procedure LoadFromXMLConfig(AXMLConfig: TXMLConfig; const Path: string); override;
    procedure SaveToXMLConfig(AXMLConfig: TXMLConfig; const Path: string); override;
    function CanBeDefaulForProject: boolean; override;
    function GetOwnerName: string; override;
    function GetDefaultMainSourceFileName: string; override;
    procedure GetInheritedCompilerOptions(var OptionsList: TFPList); override;
    procedure Assign(Source: TPersistent); override;
    function CreateDiff(CompOpts: TBaseCompilerOptions;
                        Tool: TCompilerDiffTool = nil): boolean; override; // true if differ
    procedure SetAlternativeCompile(const Command: string; ScanFPCMsgs: boolean); override;
  public
    property LazProject: TProject read FProject;
    property BuildMode: TProjectBuildMode read FBuildMode;
  published
    property CompileReasons: TCompileReasons read FCompileReasons write FCompileReasons;
  end;
  
  { TProjectDefineTemplates }

  TProjectDefineTemplates = class(TProjPackDefineTemplates)
  private
    procedure FixTemplateOrder;
  protected
    procedure UpdateMain; override;
    function UpdateSrcDirIfDef: Boolean; override;
    procedure UpdateSourceDirectories; override;
    procedure UpdateOutputDirectory; override;
    procedure UpdateDefinesForCustomDefines; override;
    procedure ClearFlags; override;
  public
    constructor Create(AOwner: IProjPack);
    destructor Destroy; override;
    procedure AllChanged(AActivating: boolean); override;
    procedure UpdateGlobalValues;
  end;

  { TProjectBuildMode }

  TProjectBuildMode = class(TLazProjectBuildMode)
  private
    FCompilerOptions: TProjectCompilerOptions;
  protected
    function GetLazCompilerOptions: TLazCompilerOptions; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function LazProject: TProject;
    procedure Clear;
    function Equals(Src: TProjectBuildMode): boolean; reintroduce;
    function CreateDiff(Other: TProjectBuildMode;
                        Tool: TCompilerDiffTool = nil): boolean;
    procedure Assign(Src: TProjectBuildMode); reintroduce;
    procedure LoadFromXMLConfig(XMLConfig: TXMLConfig; const Path: string);
    procedure SaveMacroValuesAtOldPlace(XMLConfig: TXMLConfig; const Path: string);
    procedure SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                              IsDefault, ALegacyList: Boolean; var Cnt: integer);
    function GetCaption: string; override;
    function GetIndex: integer; override;
  public
    // copied by Assign, compared by Equals, cleared by Clear
    property CompilerOptions: TProjectCompilerOptions read FCompilerOptions;
  end;

  { TProjectBuildModes }

  TProjectBuildModes = class(TLazProjectBuildModes)
  private
    FAssigning: Boolean;
    FSessionMatrixOptions: TBuildMatrixOptions;
    FSharedMatrixOptions: TBuildMatrixOptions;
    FManyBuildModes: TStringList;  // User selection of many modes.
    fSavedChangeStamp: int64;
    fItems: TFPList;
    FLazProject: TProject;
    fChangedHandlers: TMethodList;
    // Variables used by LoadFromXMLConfig and SaveToXMLConfig
    FXMLConfig: TXMLConfig;
    FGlobalMatrixOptions: TBuildMatrixOptions;
    function GetItems(Index: integer): TProjectBuildMode;
    function GetModified: boolean;
    procedure OnItemChanged(Sender: TObject);
    procedure SetModified(const AValue: boolean);
    // Used by LoadFromXMLConfig
    procedure AddMatrixMacro(const MacroName, MacroValue, ModeIdentifier: string; InSession: boolean);
    procedure LoadSessionEnabledNonSessionMatrixOptions(const Path: string);
    procedure LoadOtherCompilerOpts(const Path: string; FromIndex, ToIndex: Integer; InSession: boolean);
    procedure LoadMacroValues(const Path: string; CurMode: TProjectBuildMode);
    procedure LoadAllMacroValues(const Path: string; Cnt: Integer);
    procedure LoadOldFormat(const Path: string);
    procedure LoadActiveBuildMode(const Path: string);
    // Used by SaveToXMLConfig
    procedure SaveSessionData(const Path: string);
    procedure SaveSharedMatrixOptions(const Path: string);
  protected
    function GetLazBuildModes(Index: integer): TLazProjectBuildMode; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function IsEqual(OtherModes: TProjectBuildModes): boolean;
    procedure Assign(Source: TPersistent; WithModified: boolean); overload;
    procedure Delete(Index: integer);
    function IndexOf(Identifier: string): integer;
    function IndexOf(aMode: TProjectBuildMode): integer;
    function Find(Identifier: string): TProjectBuildMode;
    function Add(Identifier: string): TProjectBuildMode;
    procedure Move(FromIndex, ToIndex: integer);
    function Count: integer; override;
    procedure IncreaseChangeStamp;
    procedure AddOnChangedHandler(const Handler: TNotifyEvent);
    procedure RemoveOnChangedHandler(const Handler: TNotifyEvent);
    function IsModified(InSession: boolean): boolean;
    function GetSessionModes: TStringList;
    function IsSessionMode(const ModeIdentifier: string): boolean;
    function IsSharedMode(const ModeIdentifier: string): boolean;
    procedure RenameMatrixMode(const OldName, NewName: string);
    function CreateExtraModes(aCurMode: TProjectBuildMode): TProjectBuildMode;
    // load, save
    procedure LoadProjOptsFromXMLConfig(XMLConfig: TXMLConfig; const Path: string);
    procedure LoadSessionFromXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                                       LoadAllOptions: boolean);
    procedure SaveProjOptsToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                                      SaveSession, ALegacyList: boolean);
    procedure SaveSessionOptsToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
                                         SaveSession, ALegacyList: boolean);
  public
    property Items[Index: integer]: TProjectBuildMode read GetItems; default;
    property ChangeStamp: integer read FChangeStamp;
    property LazProject: TProject read FLazProject write FLazProject;
    property Assigning: Boolean read FAssigning;
    property Modified: boolean read GetModified write SetModified;
    property SharedMatrixOptions: TBuildMatrixOptions read FSharedMatrixOptions;
    property SessionMatrixOptions: TBuildMatrixOptions read FSessionMatrixOptions;
    property ManyBuildModes: TStringList read FManyBuildModes;
    property ChangedHandlers: TMethodList read fChangedHandlers;

  end;

  { TProjectIDEOptions }

  TProjectIDEOptions = class(TAbstractIDEProjectOptions)
  private
    FProject: TProject;
    FLclApp: Boolean;
  public
    constructor Create(AProject: TProject);
    destructor Destroy; override;
    function GetProject: TLazProject; override;
    function CheckLclApp: Boolean;
    class function GetInstance: TAbstractIDEOptions; override;
    class function GetGroupCaption: string; override;
    property Project: TProject read FProject;
    property LclApp: Boolean read FLclApp;
  end;

  { TProject }
  
  TEndUpdateProjectEvent =
    procedure(Sender: TObject; ProjectChanged: boolean) of object;
    
  TLazProjectStateFlag = (
    lpsfStateFileLoaded,
    lpsfPropertyDependenciesChanged,
    lpsfDesignerChanged
    );
  TLazProjectStateFlags = set of TLazProjectStateFlag;
    
  TOldProjectType = (ptApplication, ptProgram, ptCustomProgram);

  TProject = class(TLazProject, IProjPack)
  private
    FActiveBuildMode: TProjectBuildMode;
    FActiveBuildModeBackup: integer;
    FActiveWindowIndexAtStart: integer;
    FBuildModes: TProjectBuildModes;
    FBuildModesBackup: TProjectBuildModes;
    FAllEditorsInfoList: TUnitEditorInfoList;
    FAllEditorsInfoMap: TMap;
    FAutoCreateForms: boolean;
    FChangeStampSaved: integer;
    FDebuggerBackend: String;
    FEnableI18NForLFM: boolean;
    FHistoryLists: THistoryLists;
    FLastCompileComplete: boolean;
    FMacroEngine: TTransferMacroList;
    FTmpAutoCreatedForms: TStrings; // temporary, used to apply auto create forms changes
    FAutoOpenDesignerFormsDisabled: boolean;
    FBookmarks: TProjectBookmarkList;
    fChanged: boolean;
    fCurStorePathDelim: TPathDelimSwitch; // used by OnLoadSaveFilename
    FDefineTemplates: TProjectDefineTemplates;
    fDestroying: boolean;
    FEnableI18N: boolean;
    FI18NExcludedIdentifiers: TStrings;
    FI18NExcludedOriginals: TStrings;
    FForceUpdatePoFiles: Boolean;
    fFirst, fLast: array[TUnitInfoList] of TUnitInfo;
    FFirstRemovedDependency: TPkgDependency;
    FFirstRequiredDependency: TPkgDependency;
    FJumpHistory: TProjectJumpHistory;
    FLastCompilerFileDate: integer;
    FLastCompilerFilename: string;
    FLastCompilerParams: string;
    fLastReadLPIFileDate: TDateTime;
    fLastReadLPIFilename: string;
    FLockUnitComponentDependencies: integer;
    FMainProject: boolean;
    fMainUnitID: Integer;
    FOnBeginUpdate: TNotifyEvent;
    FOnChangeProjectInfoFile: TOnChangeProjectInfoFile;
    FOnEndUpdate: TEndUpdateProjectEvent;
    fOnFileBackup: TOnFileBackup;
    FOnLoadProjectInfo: TOnLoadProjectInfo;
    FOnSaveProjectInfo: TOnSaveProjectInfo;
    FOnSaveUnitSessionInfo: TOnSaveUnitSessionInfoInfo;
    fPathDelimChanged: boolean; // PathDelim in system and current config differ (see StorePathDelim and SessionStorePathDelim)
    FPOOutputDirectory: string;
    fProjectDirectory: string;
    fProjectDirectoryReferenced: string;
    fProjectInfoFile: String;  // the lpi filename
    fProjectInfoFileBuffer: TCodeBuffer;
    fProjectInfoFileBufChangeStamp: integer;
    fProjectInfoFileDate: LongInt;
    FPublishOptions: TPublishProjectOptions;
    FRevertLockCount: integer;
    FSessionModifiedBackup: boolean;
    FSessionStorePathDelim: TPathDelimSwitch;
    FSkipCheckLCLInterfaces: boolean;
    FSourceDirectories: TFileReferenceList;
    FStateFileDate: longint;
    FStateFlags: TLazProjectStateFlags;
    FStorePathDelim: TPathDelimSwitch;
    FUnitList: TFPList;  // list of _all_ units (TUnitInfo)
    FOtherDefines: TStrings; // list of user selectable defines for custom options
    FUpdateLock: integer;
    FUseAsDefault: Boolean;
    // Variables used by ReadProject / WriteProject
    FXMLConfig: TXMLConfig;
    FLoadAllOptions: Boolean; // All options / just options used as default for new projects
    FFileVersion: Integer;
    FNewMainUnitID: LongInt;
    FProjectWriteFlags: TProjectWriteFlags;
    FSaveSessionInLPI: Boolean;
    procedure ClearBuildModes;
    function GetAllEditorsInfo(Index: Integer): TUnitEditorInfo;
    function GetCompilerOptions: TProjectCompilerOptions;
    function GetBaseCompilerOptions: TBaseCompilerOptions;
    function GetFirstAutoRevertLockedUnit: TUnitInfo;
    function GetFirstLoadedUnit: TUnitInfo;
    function GetFirstPartOfProject: TUnitInfo;
    function GetFirstUnitWithComponent: TUnitInfo;
    function GetFirstUnitWithEditorIndex: TUnitInfo;
    function GetIDEOptions: TProjectIDEOptions;
    function GetMainFilename: String;
    function GetMainUnitInfo: TUnitInfo;
    function GetProjResources: TProjectResources;
    function GetRunParameterOptions: TRunParamsOptions;
    function GetSourceDirectories: TFileReferenceList;
    function GetTargetFilename: string;
    function GetUnits(Index: integer): TUnitInfo;
    function GetUseLegacyLists: Boolean;
    function JumpHistoryCheckPosition(
                                APosition:TProjectJumpHistoryPosition): boolean;
    procedure ClearSourceDirectories;
    procedure EmbeddedObjectModified(Sender: TObject);
    function FileBackupHandler(const Filename: string): TModalResult;
    procedure LoadSaveFilenameHandler(var AFilename: string; Load: boolean);
    procedure UnitNameChangeHandler(AnUnitInfo: TUnitInfo;
                               const OldUnitName, NewUnitName: string;
                               CheckIfAllowed: boolean; var Allowed: boolean);
    procedure SetActiveBuildMode(const AValue: TProjectBuildMode);
    procedure SetAutoOpenDesignerFormsDisabled(const AValue: boolean);
    procedure SetDebuggerBackend(AValue: String);
    procedure SetEnableI18N(const AValue: boolean);
    procedure SetEnableI18NForLFM(const AValue: boolean);
    procedure SetLastCompilerParams(AValue: string);
    procedure SetMainProject(const AValue: boolean);
    procedure SetMainUnitID(const AValue: Integer);
    procedure SetPOOutputDirectory(const AValue: string);
    procedure SetSkipCheckLCLInterfaces(const AValue: boolean);
    procedure SetStorePathDelim(const AValue: TPathDelimSwitch);
    procedure SetTargetFilename(const NewTargetFilename: string);
    procedure SourceDirectoriesChanged(Sender: TObject);
    procedure UpdateFileBuffer;
    procedure UpdateProjectDirectory;
    procedure UpdateSessionFilename;
    procedure UpdateSourceDirectories;
    procedure UpdateUsageCounts(const ConfigFilename: string);
    function UnitMustBeSaved(UnitInfo: TUnitInfo; WriteFlags: TProjectWriteFlags;
                             SaveSession: boolean): boolean;
    procedure UpdateVisibleEditor(PgIndex: integer);
    procedure LoadDefaultSession;
    procedure EditorInfoAdd(EdInfo: TUnitEditorInfo);
    procedure EditorInfoRemove(EdInfo: TUnitEditorInfo);
    procedure OnMacroEngineSubstitution({%H-}TheMacro: TTransferMacro;
      const MacroName: string; var s: string;
      const Data: PtrInt; var Handled, Abort: boolean; Depth: integer);
    // Methods for ReadProject
    function LoadOldProjectType(const Path: string): TOldProjectType;
    procedure LoadFlags(const Path: string);
    procedure LoadOtherDefines(const Path: string);
    procedure LoadSessionInfo(const Path: string; Merge: boolean);
    procedure LoadFromLPI;
    procedure LoadFromSession;
    function DoLoadLPI(Filename: String): TModalResult;
    function DoLoadSession(Filename: String): TModalResult;
    function DoLoadLPR(Revert: boolean): TModalResult;
    // Methods for WriteProject
    procedure SaveFlags(const Path: string);
    procedure SaveUnits(const Path: string; SaveSession: boolean);
    procedure SaveOtherDefines(const Path: string);
    procedure SaveSessionInfo(const Path: string);
    procedure SaveToLPI;
    procedure SaveToSession;
    function DoWrite(Filename: String; IsLpi: Boolean): TModalResult;
  protected
    function GetDirectory: string; override;
    function GetActiveBuildModeID: string; override;
    function GetDefineTemplates: TProjPackDefineTemplates;
    function GetFiles(Index: integer): TLazProjectFile; override;
    function GetLazBuildModes: TLazProjectBuildModes; override;
    function GetMainFile: TLazProjectFile; override;
    function GetMainFileID: Integer; override;
    function GetModified: boolean; override;
    function GetProjectInfoFile: string; override;
    function GetUseManifest: boolean; override;
    procedure SetActiveBuildModeID(aIdent: string); override;
    procedure SetExecutableType(const AValue: TProjectExecutableType); override;
    procedure SetFlags(const AValue: TProjectFlags); override;
    procedure SetMainFileID(const AValue: Integer); override;
    procedure SetModified(const AValue: boolean); override;
    procedure SetProjectInfoFile(const NewFilename: string); override;
    procedure SetSessionModified(const AValue: boolean); override;
    procedure SetSessionStorage(const AValue: TProjectSessionStorage); override;
    procedure SetUseManifest(AValue: boolean); override;
    function GetCurrentDebuggerBackend: String; override;
  protected
    // special unit lists
    procedure AddToList(AnUnitInfo: TUnitInfo; ListType: TUnitInfoList);
    procedure RemoveFromList(AnUnitInfo: TUnitInfo; ListType: TUnitInfoList);

    procedure AddToOrRemoveFromAutoRevertLockedList(AnUnitInfo: TUnitInfo);
    procedure AddToOrRemoveFromComponentList(AnUnitInfo: TUnitInfo);
    procedure AddToOrRemoveFromLoadedList(AnUnitInfo: TUnitInfo);
    procedure AddToOrRemoveFromPartOfProjectList(AnUnitInfo: TUnitInfo);
  public
    constructor Create(ProjectDescription: TProjectDescriptor); override;
    destructor Destroy; override;
    procedure Clear; override;
    procedure BeginUpdate(Change: boolean);
    procedure EndUpdate;
    procedure UnitModified(AnUnitInfo: TUnitInfo);
    function NeedsDefineTemplates: boolean;
    procedure BeginRevertUnit(AnUnitInfo: TUnitInfo);
    procedure EndRevertUnit(AnUnitInfo: TUnitInfo);
    function IsLclApplication: Boolean;
    function IsReverting(AnUnitInfo: TUnitInfo): boolean;
    function IsVirtual: boolean; override;
    // load/save
    function SomethingModified(CheckData, CheckSession: boolean; Verbose: boolean = false): boolean;
    function SomeDataModified(Verbose: boolean = false): boolean;
    function SomeSessionModified(Verbose: boolean = false): boolean;
    procedure MainSourceFilenameChanged;
    procedure GetUnitsChangedOnDisk(var AnUnitList: TFPList; IgnoreModifiedFlag: boolean = False);
    function HasProjectInfoFileChangedOnDisk: boolean;
    procedure IgnoreProjectInfoFileOnDisk;
    function ReadProject(const NewProjectInfoFile: string;
                         GlobalMatrixOptions: TBuildMatrixOptions;
                         LoadAllOptions: Boolean = True): TModalResult;
    function WriteProject(ProjectWriteFlags: TProjectWriteFlags;
                          const OverrideProjectInfoFile: string;
                          GlobalMatrixOptions: TBuildMatrixOptions): TModalResult;
    procedure UpdateExecutableType; override;
    procedure BackupSession;
    procedure RestoreSession;
    procedure BackupBuildModes;
    procedure RestoreBuildModes;

    // title
    function GetTitle: string; override;
    function TitleIsDefault(Fuzzy: boolean = false): boolean;
    function GetIDAsString: string;
    function GetIDAsWord: string;

    // units
    function UnitCount:integer;
    function GetFileCount: integer; override;
    function NewUniqueUnitName(const AnUnitName: string): string;
    function NewUniqueFilename(const Filename: string): string;
    procedure AddFile(ProjectFile: TLazProjectFile;
                      AddToProjectUsesClause: boolean); override;
    procedure RemoveUnit(Index: integer;
                         RemoveFromUsesSection: boolean = true); override;
    // true if something changed
    function RemoveNonExistingFiles(RemoveFromUsesSection: boolean = true): boolean;
    function CreateProjectFile(const Filename: string): TLazProjectFile; override;
    function GetAndUpdateVisibleUnit(AnEditor: TSourceEditorInterface;
                                     AWindowID: Integer): TUnitInfo;
    procedure UpdateAllVisibleUnits;
    // search
    function IndexOf(AUnitInfo: TUnitInfo): integer;
    function IndexOfUnitWithName(const AnUnitName: string;
                      OnlyProjectUnits:boolean; IgnoreUnit: TUnitInfo): integer;
    function IndexOfUnitWithComponent(AComponent: TComponent;
                      OnlyProjectUnits:boolean; IgnoreUnit: TUnitInfo): integer;
    function IndexOfUnitWithComponentName(const AComponentName: string;
                      OnlyProjectUnits:boolean; IgnoreUnit: TUnitInfo): integer;
    function IndexOfFilename(const AFilename: string): integer;
    function IndexOfFilename(const AFilename: string;
                             SearchFlags: TProjectFileSearchFlags): integer;
    function ProjectUnitWithFilename(const AFilename: string): TUnitInfo;
    function ProjectUnitWithShortFilename(const ShortFilename: string): TUnitInfo;
    function ProjectUnitWithUnitname(const AnUnitName: string): TUnitInfo;
    function UnitWithEditorComponent(AEditor:TSourceEditorInterface): TUnitInfo;
    function UnitWithComponent(AComponent: TComponent): TUnitInfo;
    function UnitWithComponentClass(AClass: TComponentClass): TUnitInfo;
    function UnitWithComponentClassName(const AClassName: string): TUnitInfo;
    function UnitWithComponentName(AComponentName: String;
                                   OnlyPartOfProject: boolean): TUnitInfo;
    function UnitComponentInheritingFrom(AClass: TComponentClass;
                                         Ignore: TUnitInfo): TUnitInfo;
    function UnitUsingComponentUnit(ComponentUnit: TUnitInfo;
                                    Types: TUnitCompDependencyTypes): TUnitInfo;
    function UnitComponentIsUsed(ComponentUnit: TUnitInfo;
                                 CheckHasDesigner: boolean): boolean;
    function UnitInfoWithFilename(const AFilename: string): TUnitInfo;
    function UnitInfoWithFilename(const AFilename: string;
                    SearchFlags: TProjectFileSearchFlags): TUnitInfo;
    function UnitWithUnitname(const AnUnitname: string): TUnitInfo;
    function AllEditorsInfoCount: Integer;
    property AllEditorsInfo[Index: Integer]: TUnitEditorInfo read GetAllEditorsInfo;
    function EditorInfoWithEditorComponent(AEditor:TSourceEditorInterface): TUnitEditorInfo;
    function SearchFile(const ShortFilename: string;
                        SearchFlags: TSearchIDEFileFlags): TUnitInfo;
    function FindFile(const AFilename: string;
                      SearchFlags: TProjectFileSearchFlags): TLazProjectFile; override;

    // used units with 'in' modifier
    function UpdateIsPartOfProjectFromMainUnit: TModalResult;

    // Application.CreateForm statements
    function AddCreateFormToProjectFile(const AClassName, AName:string): boolean;
    function RemoveCreateFormFromProjectFile(const AName: string): boolean;
    function FormIsCreatedInProjectFile(const AClassname, AName:string): boolean;
    function GetAutoCreatedFormsList: TStrings;
    property TmpAutoCreatedForms: TStrings read FTmpAutoCreatedForms write FTmpAutoCreatedForms;

    // resources
    function GetMainResourceFilename(AnUnitInfo: TUnitInfo): string;
    function GetResourceFile(AnUnitInfo: TUnitInfo; Index:integer):TCodeBuffer;
    procedure LoadDefaultIcon; override;

    // filenames and fileinfo
    function RemoveProjectPathFromFilename(const AFilename: string): string;
    function FileIsInProjectDir(const AFilename: string): boolean;
    procedure GetVirtualDefines(DefTree: TDefineTree; DirDef: TDirectoryDefines);
    function GetShortFilename(const Filename: string; UseUp: boolean): string; override;
    procedure ConvertToLPIFilename(var AFilename: string); override;
    procedure ConvertFromLPIFilename(var AFilename: string); override;

    // package dependencies
    function FindDependencyByName(const PackageName: string): TPkgDependency;
    function FindRemovedDependencyByName(const PkgName: string): TPkgDependency;
    function RequiredDepByIndex(Index: integer): TPkgDependency;
    function RemovedDepByIndex(Index: integer): TPkgDependency;
    procedure AddRequiredDependency(Dependency: TPkgDependency);
    procedure RemoveRequiredDependency(Dependency: TPkgDependency);
    procedure DeleteRequiredDependency(Dependency: TPkgDependency);
    procedure DeleteRemovedDependency(Dependency: TPkgDependency);
    procedure RemoveRemovedDependency(Dependency: TPkgDependency);
    procedure ReaddRemovedDependency(Dependency: TPkgDependency);
    procedure MoveRequiredDependencyUp(Dependency: TPkgDependency);
    procedure MoveRequiredDependencyDown(Dependency: TPkgDependency);
    function Requires(APackage: TLazPackage; SearchRecursively: boolean): boolean;
    procedure GetAllRequiredPackages(var List: TFPList;
               ReqFlags: TPkgIntfRequiredFlags = [];
               MinPolicy: TPackageUpdatePolicy = low(TPackageUpdatePolicy));
    procedure AddPackageDependency(const PackageName: string); override;
    function RemovePackageDependency(const PackageName: string): boolean;
      override;
    
    // unit dependencies
    procedure LockUnitComponentDependencies;
    procedure UnlockUnitComponentDependencies;
    procedure UpdateUnitComponentDependencies;
    procedure InvalidateUnitComponentDesignerDependencies;
    procedure ClearUnitComponentDependencies(ClearTypes: TUnitCompDependencyTypes);
    procedure FindUnitsUsingSubComponent(SubComponent: TComponent;
                     List: TFPList; IgnoreOwner: boolean);
    procedure WriteDebugReportUnitComponentDependencies(Prefix: string);

    // paths
    procedure AddSrcPath(const SrcPathAddition: string); override;
    function GetSourceDirs(WithProjectDir, WithoutOutputDir: boolean): string;
    function GetOutputDirectory: string;
    function GetCompilerFilename: string;
    function GetStateFilename: string;
    function GetCompileSourceFilename: string;
    procedure AutoAddOutputDirToIncPath;
    function ExtendUnitSearchPath(NewUnitPaths: string): boolean;
    function ExtendIncSearchPath(NewIncPaths: string): boolean;

    // compile state file
    function LoadStateFile(IgnoreErrors: boolean): TModalResult;
    function SaveStateFile(const CompilerFilename, CompilerParams: string;
                           Complete: boolean): TModalResult;
                           
    // source editor
    procedure UpdateAllCustomHighlighter;
    procedure UpdateAllSyntaxHighlighter;
    
    // i18n
    function GetPOOutDirectory: string;

    // bookmarks
    function  AddBookmark(X, Y, ID: Integer; AUnitInfo:TUnitInfo):integer;
    procedure DeleteBookmark(ID: Integer);
  public
    property ActiveBuildMode: TProjectBuildMode read FActiveBuildMode
                                                write SetActiveBuildMode;
    property ActiveWindowIndexAtStart: integer read FActiveWindowIndexAtStart
                                               write FActiveWindowIndexAtStart;
    property AutoCreateForms: boolean read FAutoCreateForms write FAutoCreateForms;
    property AutoOpenDesignerFormsDisabled: boolean read FAutoOpenDesignerFormsDisabled
                                                    write SetAutoOpenDesignerFormsDisabled;
    property Bookmarks: TProjectBookmarkList read FBookmarks write FBookmarks;
    property BuildModes: TProjectBuildModes read FBuildModes;
    property SkipCheckLCLInterfaces: boolean read FSkipCheckLCLInterfaces
                                             write SetSkipCheckLCLInterfaces;
    property CompilerOptions: TProjectCompilerOptions read GetCompilerOptions;
    property DefineTemplates: TProjectDefineTemplates read FDefineTemplates;
    property Destroying: boolean read fDestroying;
    property EnableI18N: boolean read FEnableI18N write SetEnableI18N;
    property EnableI18NForLFM: boolean read FEnableI18NForLFM write SetEnableI18NForLFM;
    property I18NExcludedIdentifiers: TStrings read FI18NExcludedIdentifiers;
    property I18NExcludedOriginals: TStrings read FI18NExcludedOriginals;
    property UseLegacyLists: Boolean read GetUseLegacyLists;
    property ForceUpdatePoFiles: Boolean read FForceUpdatePoFiles write FForceUpdatePoFiles;
    property FirstAutoRevertLockedUnit: TUnitInfo read GetFirstAutoRevertLockedUnit;
    property FirstLoadedUnit: TUnitInfo read GetFirstLoadedUnit;
    property FirstPartOfProject: TUnitInfo read GetFirstPartOfProject;
    property FirstRemovedDependency: TPkgDependency read FFirstRemovedDependency;
    property FirstRequiredDependency: TPkgDependency read FFirstRequiredDependency;
    property FirstUnitWithComponent: TUnitInfo read GetFirstUnitWithComponent;
    property FirstUnitWithEditorIndex: TUnitInfo read GetFirstUnitWithEditorIndex;
    property IDAsString: string read GetIDAsString;
    property IDAsWord: string read GetIDAsWord;
    property IDEOptions: TProjectIDEOptions read GetIDEOptions;
    property JumpHistory: TProjectJumpHistory read FJumpHistory write FJumpHistory;
    property LastCompilerFileDate: integer read FLastCompilerFileDate
                                          write FLastCompilerFileDate;
    property LastCompilerFilename: string read FLastCompilerFilename
                                          write FLastCompilerFilename;
    property LastCompilerParams: string read FLastCompilerParams
                                        write SetLastCompilerParams;
    property LastCompileComplete: boolean read FLastCompileComplete write FLastCompileComplete;
    property MacroEngine: TTransferMacroList read FMacroEngine;
    property MainFilename: String read GetMainFilename;
    property MainProject: boolean read FMainProject write SetMainProject;
    property MainUnitID: Integer read FMainUnitID write SetMainUnitID;
    property MainUnitInfo: TUnitInfo read GetMainUnitInfo;
    property OnBeginUpdate: TNotifyEvent read FOnBeginUpdate write FOnBeginUpdate;
    property OnChangeProjectInfoFile: TOnChangeProjectInfoFile read FOnChangeProjectInfoFile
                                                 write FOnChangeProjectInfoFile;
    property OnEndUpdate: TEndUpdateProjectEvent read FOnEndUpdate write FOnEndUpdate;
    property OnFileBackup: TOnFileBackup read fOnFileBackup write fOnFileBackup;
    property OnLoadProjectInfo: TOnLoadProjectInfo read FOnLoadProjectInfo
                                                   write FOnLoadProjectInfo;
    property OnSaveProjectInfo: TOnSaveProjectInfo read FOnSaveProjectInfo
                                                   write FOnSaveProjectInfo;
    property OnSaveUnitSessionInfo: TOnSaveUnitSessionInfoInfo
      read FOnSaveUnitSessionInfo write FOnSaveUnitSessionInfo;
    property POOutputDirectory: string read FPOOutputDirectory write SetPOOutputDirectory;
    property ProjectInfoFile: string read GetProjectInfoFile write SetProjectInfoFile;
    property PublishOptions: TPublishProjectOptions read FPublishOptions write FPublishOptions;
    property ProjResources: TProjectResources read GetProjResources;

    property RunParameterOptions: TRunParamsOptions read GetRunParameterOptions;
    property HistoryLists: THistoryLists read FHistoryLists;
    property SourceDirectories: TFileReferenceList read GetSourceDirectories;
    property StateFileDate: longint read FStateFileDate write FStateFileDate;
    property StateFlags: TLazProjectStateFlags read FStateFlags write FStateFlags;
    property SessionStorePathDelim: TPathDelimSwitch read FSessionStorePathDelim write FSessionStorePathDelim;
    property StorePathDelim: TPathDelimSwitch read FStorePathDelim write SetStorePathDelim;
    property TargetFilename: string read GetTargetFilename write SetTargetFilename;
    property Units[Index: integer]: TUnitInfo read GetUnits;
    property OtherDefines: TStrings read FOtherDefines;
    property UpdateLock: integer read FUpdateLock;
    property UseAsDefault: Boolean read FUseAsDefault write FUseAsDefault; // for dialog only (used to store options once)

    property DebuggerBackend: String read FDebuggerBackend write SetDebuggerBackend;
  end;


const
  ResourceFileExt = '.lrs';
  DefaultProjectOptionsFilename = 'projectoptions.xml';
  DefaultProjectCompilerOptionsFilename = 'compileroptions.xml'; // old way < 0.9.31
  OldProjectTypeNames : array[TOldProjectType] of string = (
      'Application', 'Program', 'Custom program'
    );

var
  Project1: TProject = nil;// the main project
  
function FilenameToLazSyntaxHighlighter(Filename: String): TLazSyntaxHighlighter;
function AddCompileReasonsDiff(const PropertyName: string;
       const Old, New: TCompileReasons; Tool: TCompilerDiffTool = nil): boolean;
function dbgs(aType: TUnitCompDependencyType): string; overload;
function dbgs(Types: TUnitCompDependencyTypes): string; overload;
function dbgs(Flag: TUnitInfoFlag): string; overload;
function dbgs(Flags: TUnitInfoFlags): string; overload;

implementation

const
  ProjectInfoFileVersion = 12;
  ProjOptionsPath = 'ProjectOptions/';


function FilenameToLazSyntaxHighlighter(Filename: String): TLazSyntaxHighlighter;
var
  CompilerMode: TCompilerMode;
begin
  Result:=IDEEditorOptions.ExtensionToLazSyntaxHighlighter(ExtractFileExt(Filename));
  if Result in [lshFreePascal,lshDelphi] then begin
    CompilerMode:=CodeToolBoss.GetCompilerModeForDirectory(ExtractFilePath(Filename));
    if CompilerMode in [cmDELPHI,cmTP] then
      Result:=lshDelphi
    else
      Result:=lshFreePascal;
  end;
end;

function AddCompileReasonsDiff(const PropertyName: string;
  const Old, New: TCompileReasons; Tool: TCompilerDiffTool): boolean;
begin
  if Old=New then exit(false);
  Result:=true;
  Tool.AddSetDiff(PropertyName,integer(Old),integer(New),
                  PString(@CompileReasonNames[Low(TCompileReasons)]));
end;

function dbgs(aType: TUnitCompDependencyType): string;
begin
  case aType of
  ucdtAncestor: Result:='Ancestor';
  ucdtProperty: Result:='Property';
  ucdtOldProperty: Result:='OldProperty';
  ucdtInlineClass: Result:='InlineClass';
  else Result:='?'
  end;
end;

function dbgs(Types: TUnitCompDependencyTypes): string;
var
  t: TUnitCompDependencyType;
begin
  Result:='';
  for t:=low(Types) to High(Types) do
    if t in Types then begin
      if Result<>'' then Result:=Result+';';
      Result:=Result+dbgs(t);
    end;
  Result:='['+Result+']';
end;

function dbgs(Flag: TUnitInfoFlag): string;
begin
  Result:='';
  WriteStr(Result, Flag);
end;

function dbgs(Flags: TUnitInfoFlags): string;
var
  f: TUnitInfoFlag;
begin
  Result:='';
  for f:=low(Flags) to High(Flags) do
    if f in Flags then begin
      if Result<>'' then Result:=Result+';';
      Result:=Result+dbgs(f);
    end;
  Result:='['+Result+']';
end;

{ TUnitEditorInfo }

procedure TUnitEditorInfo.SetEditorComponent(const AValue: TSourceEditorInterface);
begin
  if FEditorComponent = AValue then exit;
  if AValue = nil then begin
    fUnitInfo.Project.FAllEditorsInfoMap.Delete(FEditorComponent);
    FEditorComponent := AValue;
    UnitInfo.FEditorInfoList.MakeUnUsedEditorInfo(Self);
    PageIndex := -1; // calls UnitInfo.UpdatePageIndex
    IsLocked := False;
  end
  else begin
    PageIndex := -1;
    with fUnitInfo.Project do             // Map for lookup: Editor -> EditorInfo
      if not FAllEditorsInfoMap.HasId(AValue) then
        FAllEditorsInfoMap.Add(AValue, Self);
    FEditorComponent := AValue;
    UnitInfo.FEditorInfoList.MakeUsedEditorInfo(Self);
    AValue.UpdateProjectFile; // Set EditorIndex / calls UnitInfo.UpdatePageIndex
  end;
  FUnitInfo.SessionModified:=true;
end;

procedure TUnitEditorInfo.SetPageIndex(const AValue: Integer);
begin
  if FPageIndex = AValue then exit;
  FPageIndex := AValue;
  FUnitInfo.UpdatePageIndex;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetFoldState(AValue: String);
begin
  if FFoldState = AValue then Exit;
  FFoldState := AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetIsLocked(const AValue: Boolean);
begin
  if FIsLocked=AValue then Exit;
  FIsLocked:=AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetCursorPos(const AValue: TPoint);
begin
  if ComparePoints(FCursorPos,AValue)=0 then Exit;
  FCursorPos:=AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetIsVisibleTab(const AValue: Boolean);
begin
  if FIsVisibleTab = AValue then exit;
  FIsVisibleTab := AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetSyntaxHighlighter(AValue: TLazSyntaxHighlighter);
begin
  if FSyntaxHighlighter = AValue then Exit;
  FSyntaxHighlighter := AValue;
  FCustomHighlighter := FSyntaxHighlighter <> FUnitInfo.DefaultSyntaxHighlighter;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetTopLine(const AValue: Integer);
begin
  if FTopLine=AValue then Exit;
  FTopLine:=AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.SetWindowIndex(const AValue: Integer);
begin
  if FWindowID = AValue then exit;
  FWindowID := AValue;
  FUnitInfo.SessionModified := True;
end;

procedure TUnitEditorInfo.Clear;
begin
  FIsVisibleTab := False;
  FPageIndex := -1;
  FWindowID := -1;
  FTopLine := -1;
  FCursorPos.X := -1;
  FCursorPos.Y := -1;
  FFoldState := '';
  FSyntaxHighlighter := FUnitInfo.DefaultSyntaxHighlighter;
  FCustomHighlighter := FUnitInfo.CustomDefaultHighlighter;
end;

constructor TUnitEditorInfo.Create(aUnitInfo: TUnitInfo);
begin
  FUnitInfo := aUnitInfo;
  Clear;
  if FUnitInfo.Project <> nil then
    FUnitInfo.Project.EditorInfoAdd(Self);
end;

destructor TUnitEditorInfo.Destroy;
begin
  if FUnitInfo.Project <> nil then
    FUnitInfo.Project.EditorInfoRemove(Self);
  inherited Destroy;
end;

procedure TUnitEditorInfo.LoadFromXMLConfig(XMLConfig: TXMLConfig; const Path: string);
begin
  IsVisibleTab := XMLConfig.GetValue(Path+'IsVisibleTab/Value', False);
  FPageIndex    := XMLConfig.GetValue(Path+'EditorIndex/Value',0);
  WindowID  := XMLConfig.GetValue(Path+'WindowIndex/Value',0);
  // update old data
  if (FPageIndex >= 0) and (FWindowID < 0) then
    WindowID := 1;
  FTopLine  := XMLConfig.GetValue(Path+'TopLine/Value',1);
  FCursorPos := Point(XMLConfig.GetValue(Path+'CursorPos/X',1),
                     XMLConfig.GetValue(Path+'CursorPos/Y',1));
  FFoldState := XMLConfig.GetValue(Path+'FoldState/Value', '');
  FIsLocked := XMLConfig.GetValue(Path+'IsLocked/Value', False);
  FSyntaxHighlighter := StrToLazSyntaxHighlighter(
  XMLConfig.GetValue(Path+'SyntaxHighlighter/Value',
                     LazSyntaxHighlighterNames[UnitInfo.DefaultSyntaxHighlighter]));
end;

procedure TUnitEditorInfo.SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
  SaveFold: Boolean);
begin
  XMLConfig.SetDeleteValue(Path+'IsVisibleTab/Value', FIsVisibleTab, False);
  XMLConfig.SetDeleteValue(Path+'EditorIndex/Value', FPageIndex, 0);
  XMLConfig.SetDeleteValue(Path+'WindowIndex/Value', FWindowID, 0);
  XMLConfig.SetDeleteValue(Path+'TopLine/Value', FTopLine, 1);
  XMLConfig.SetDeleteValue(Path+'CursorPos/X', FCursorPos.X, 1);
  XMLConfig.SetDeleteValue(Path+'CursorPos/Y', FCursorPos.Y, 1);
  XMLConfig.SetDeleteValue(Path+'IsLocked/Value', FIsLocked, False);
  if SaveFold then
    XMLConfig.SetDeleteValue(Path+'FoldState/Value', FoldState, '')
  else
    XMLConfig.DeletePath(Path+'FoldState');
  XMLConfig.SetDeleteValue(Path+'SyntaxHighlighter/Value',
                           LazSyntaxHighlighterNames[fSyntaxHighlighter],
                           LazSyntaxHighlighterNames[UnitInfo.DefaultSyntaxHighlighter]);
end;

{ TUnitEditorInfoList }

function TUnitEditorInfoList.GetEditorInfos(Index: Integer): TUnitEditorInfo;
begin
  Result := TUnitEditorInfo(FList[Index]);
end;

function TUnitEditorInfoList.GetClosedEditorInfos(Index: Integer): TUnitEditorInfo;
var
  i: Integer;
begin
  i := 0;
  while (i < Count) and (Index >= 0) do begin
    Result := EditorInfos[i];
    if Result.EditorComponent = nil then dec(Index);
    inc(i);
  end;
  if Index >= 0 then
    Result := nil;
end;

function TUnitEditorInfoList.GetOpenEditorInfos(Index: Integer): TUnitEditorInfo;
var
  i: Integer;
begin
  i := 0;
  while (i < Count) and (Index >= 0) do begin
    Result := EditorInfos[i];
    if Result.EditorComponent <> nil then dec(Index);
    inc(i);
  end;
  if Index >= 0 then
    Result := nil;
end;

procedure TUnitEditorInfoList.ClearEachInfo;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    EditorInfos[i].Clear;
end;

function CompareEditorInfoByPageIndex(EditorInfo1, EditorInfo2: TUnitEditorInfo): integer;
begin
  Result := EditorInfo1.WindowID - EditorInfo2.WindowID;
  if Result = 0 then
    Result := EditorInfo1.PageIndex - EditorInfo2.PageIndex;
end;

procedure TUnitEditorInfoList.SortByPageIndex;
begin
  FList.Sort(TListSortCompare(@CompareEditorInfoByPageIndex));
end;

procedure TUnitEditorInfoList.SetLastUsedEditor(AEditor: TSourceEditorInterface);
var
  i: Integer;
begin
  i := IndexOfEditorComponent(AEditor);
  if i <> 0 then
    FList.Move(i, 0);
end;

procedure TUnitEditorInfoList.MakeUsedEditorInfo(AEditorInfo: TUnitEditorInfo);
var
  i, j: Integer;
begin
  i := FList.IndexOf(AEditorInfo);
  j := OpenCount;
  if (i > j) and (j < Count) then
    FList.Move(i, j);
end;

procedure TUnitEditorInfoList.MakeUnUsedEditorInfo(AEditorInfo: TUnitEditorInfo);
var
  i: Integer;
begin
  i := FList.IndexOf(AEditorInfo);
  if i <> FList.Count - 1 then
    FList.Move(i, FList.Count - 1);
end;

procedure TUnitEditorInfoList.Clear;
begin
  while Count > 0 do begin
    EditorInfos[0].Free;
    Delete(0);
  end;
end;

constructor TUnitEditorInfoList.Create(aUnitInfo: TUnitInfo);
begin
  FUnitInfo := aUnitInfo;
  FList := TFPList.Create;
end;

destructor TUnitEditorInfoList.Destroy;
begin
  Clear;
  FreeAndNil(FList);
  inherited Destroy;
end;

function TUnitEditorInfoList.Count: Integer;
begin
  Result := FList.Count;
end;

function TUnitEditorInfoList.OpenCount: Integer;
var
  i: Integer;
begin
  i := Count - 1;
  Result := 0;
  while i >= 0 do begin
    if EditorInfos[i].EditorComponent <> nil then inc(Result);
    dec(i);
  end;
end;

function TUnitEditorInfoList.ClosedCount: Integer;
var
  i: Integer;
begin
  i := Count - 1;
  Result := 0;
  while i >= 0 do begin
    if EditorInfos[i].EditorComponent = nil then inc(Result);
    dec(i);
  end;
end;

function TUnitEditorInfoList.IndexOfEditorComponent(anEditor: TSourceEditorInterface): Integer;
begin
  Result := Count - 1;
  while (Result >= 0) and (EditorInfos[Result].EditorComponent <> anEditor) do
    dec(Result);
end;

function TUnitEditorInfoList.NewEditorInfo: TUnitEditorInfo;
begin
  Result := TUnitEditorInfo.Create(FUnitInfo);
  FList.Add(Result);
end;

procedure TUnitEditorInfoList.Add(AEditorInfo: TUnitEditorInfo);
begin
  FList.Add(AEditorInfo);
end;

procedure TUnitEditorInfoList.Delete(Index: Integer);
begin
  Flist.Delete(Index);
end;

procedure TUnitEditorInfoList.Remove(AEditorInfo: TUnitEditorInfo);
var
  i: LongInt;
begin
  i := FList.IndexOf(AEditorInfo);
  if i >= 0 then
    Delete(i);
end;

{------------------------------------------------------------------------------
  TUnitInfo Constructor
 ------------------------------------------------------------------------------}
constructor TUnitInfo.Create(ACodeBuffer: TCodeBuffer);
begin
  inherited Create;
  //DebugLn('Trace:Project Unit Info Class Created');
  FEditorInfoList := TUnitEditorInfoList.Create(Self);
  FEditorInfoList.NewEditorInfo;
  FBookmarks:=TFileBookmarks.Create;
  Clear;
  Source := ACodeBuffer;
  if Source=nil then
    FFileName:='';
end;

{------------------------------------------------------------------------------
  TUnitInfo Destructor
 ------------------------------------------------------------------------------}
destructor TUnitInfo.Destroy;
begin
  Component:=nil;
  Source:=nil;
  FreeAndNil(FBookmarks);
  Project:=nil;
  FreeAndNil(FEditorInfoList);
  FreeAndNil(FComponentFallbackClasses);
  inherited Destroy;
end;

function TUnitInfo.GetFileOwner: TObject;
begin
  Result:=Project;
end;

function TUnitInfo.GetFileOwnerName: string;
begin
  if Project<>nil then
    Result:=ExtractFilename(Project.ProjectInfoFile)
  else
    Result:='';
end;

{------------------------------------------------------------------------------
  TUnitInfo WriteUnitSource
 ------------------------------------------------------------------------------}
function TUnitInfo.WriteUnitSource: TModalResult;
var
  ACaption:string;
  AText:string;
begin
  if fSource=nil then
    exit(mrOK);
  if Assigned(fOnFileBackup) then begin
    Result:=fOnFileBackup(Filename);
    if Result=mrAbort then exit;
  end;
  repeat
    if not fSource.Save then begin
      ACaption:=lisCodeToolsDefsWriteError;
      AText:=Format(lisUnableToWriteFile2, [Filename]);
      Result:=IDEMessageDialog(ACaption,AText,mtError,mbAbortRetryIgnore);
      if Result=mrAbort then exit;
      if Result=mrIgnore then Result:=mrOk;
    end else begin
      Result:=mrOk;
      FIgnoreFileDateOnDiskValid:=true;
    end;
  until Result<>mrRetry;
  Result:=mrOk;
end;

function TUnitInfo.WriteUnitSourceToFile(const AFileName: string): TModalResult;
var
  ACaption:string;
  AText:string;
begin
  if fSource=nil then
    exit(mrOK);
  if Assigned(fOnFileBackup) then begin
    Result:=fOnFileBackup(AFilename);
    if Result=mrAbort then exit;
  end;
  repeat
    if not fSource.SaveToFile(AFileName) then begin
      ACaption:=lisCodeToolsDefsWriteError;
      AText:=Format(lisUnableToWriteFile2, [AFilename]);
      Result:=IDEMessageDialog(ACaption,AText,mtError,mbAbortRetryIgnore);
      if Result=mrAbort then exit;
      if Result=mrIgnore then Result:=mrOk;
    end else
      Result:=mrOk;
  until Result<>mrRetry;
  Result:=mrOk;
end;

{------------------------------------------------------------------------------
  TUnitInfo ReadUnitSource
 ------------------------------------------------------------------------------}
function TUnitInfo.ReadUnitSource(ReadUnitName,Revert:boolean): TModalResult;
var 
  ACaption:string;
  AText:string;
  NewSource: TCodeBuffer;
begin
  repeat
    NewSource:=CodeToolBoss.LoadFile(Filename,true,Revert);
    if NewSource=nil then begin
      ACaption:=lisCodeToolsDefsReadError;
      AText:=Format(lisUnableToReadFile2, [Filename]);
      Result:=IDEMessageDialog(ACaption,AText,mtError,mbAbortRetryIgnore);
      if Result in [mrAbort,mrIgnore] then
        exit;
    end else begin
      Source:=NewSource;
      FIgnoreFileDateOnDiskValid:=true;
      Result:=mrOk;
    end;
  until Result<>mrRetry;
  if ReadUnitName then begin
    ReadUnitNameFromSource(false);
  end;
  Result:=mrOk;
end;

function TUnitInfo.ReadUnitNameFromSource(TryCache: boolean): string;
begin
  Result:='';
  if TryCache then
    Result:=CodeToolBoss.GetCachedSourceName(Source);
  if Result='' then
    Result:=CodeToolBoss.GetSourceName(fSource,false);
  if Result<>'' then begin
    // source can be parsed => update UnitName
    {$IFDEF VerboseIDESrcUnitName}
    if CompareFilenames(ExtractFileNameOnly(Filename),'interpkgconflictfiles')=0 then
      debugln(['TUnitInfo.ReadUnitNameFromSource ',Result]);
    {$ENDIF}
    FUnitName:=Result;
  end else begin
    // unable to parse the source
    if FilenameIsPascalSource(Filename) then begin
      // use default: the filename
      Result:=ExtractFileNameOnly(Filename);
      if CompareText(Result,FUnitName)=0 then begin
        // the last stored unitname has the better case
        Result:=FUnitName;
      end;
    end;
  end;
end;

function TUnitInfo.GetUsesUnitName: string;
begin
  if FilenameHasPascalExt(Filename) then
  begin
    if FUnitName<>'' then
      Result:=FUnitName
    else
      Result:=ExtractFileNameOnly(Filename);
  end
  else
    Result:='';
end;

function TUnitInfo.CreateUnitName: string;
begin
  Result:=FUnitName;
  if (Result='') and FilenameIsPascalSource(Filename) then
    Result:=ExtractFilenameOnly(Filename);
end;

{------------------------------------------------------------------------------
  TUnitInfo Clear
 ------------------------------------------------------------------------------}
procedure TUnitInfo.Clear;
begin
  FBookmarks.Clear;
  FSetBookmarLock := 0;
  FBuildFileIfActive:=false;
  fComponent := nil;
  fComponentName := '';
  fComponentResourceName := '';
  FComponentState := wsNormal;
  FDefaultSyntaxHighlighter := lshText;
  FDisableI18NForLFM:=false;
  FCustomDefaultHighlighter := False;
  FEditorInfoList.ClearEachInfo;
  fFilename := '';
  fFileReadOnly := false;
  fHasResources := false;
  FIgnoreFileDateOnDiskValid := false;
  fAutoReferenceSourceDir := true;
  inherited SetIsPartOfProject(false);
  Modified := false;
  SessionModified := false;
  FRunFileIfActive:=false;
  FUnitName := '';
  fUsageCount:=-1;
  fUserReadOnly := false;
  if fSource<>nil then fSource.Clear;
  Loaded := false;
  LoadedDesigner := false;
  ClearComponentDependencies;
end;

procedure TUnitInfo.ClearModifieds;
begin
  Modified:=false;
  SessionModified:=false;
end;

procedure TUnitInfo.ClearComponentDependencies;
begin
  while FFirstRequiredComponent<>nil do FFirstRequiredComponent.Free;
  while FFirstUsedByComponent<>nil do FFirstUsedByComponent.Free;
end;

procedure TUnitInfo.WriteDebugReportUnitComponentDependencies(Prefix: string);
var
  Dependency: TUnitComponentDependency;
begin
  DebugLn([Prefix+'TUnitInfo.WriteDebugReportUnitComponentDependencies ',Filename,' ',dbgs(Flags)]);
  Dependency:=FirstRequiredComponent;
  if Dependency<>nil then begin
    DebugLn([Prefix+'  Requires:  >>> ']);
    while Dependency<>nil do begin
      DebugLn([Prefix+'    '+Dependency.RequiresUnit.Filename+' '+dbgs(Dependency.Types)]);
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;
  Dependency:=FirstUsedByComponent;
  if Dependency<>nil then begin
    DebugLn([Prefix+'  UsedBy:    <<<']);
    while Dependency<>nil do begin
      DebugLn([Prefix+'    '+Dependency.UsedByUnit.Filename+' '+dbgs(Dependency.Types)]);
      Dependency:=Dependency.NextUsedByDependency;
    end;
  end;
end;


{------------------------------------------------------------------------------
  TUnitInfo SaveToXMLConfig
 ------------------------------------------------------------------------------}
procedure TUnitInfo.SaveToXMLConfig(XMLConfig: TXMLConfig; const Path: string;
  SaveData, SaveSession: boolean; UsePathDelim: TPathDelimSwitch);
var
  AFilename: String;
  i, X, Y: Integer;
  s: String;
  BM: TFileBookmark;
begin
  // global data
  AFilename:=Filename;
  if Assigned(fOnLoadSaveFilename) then
    fOnLoadSaveFilename(AFilename, False);
  XMLConfig.SetValue(Path+'Filename/Value',SwitchPathDelims(AFilename,UsePathDelim));

  if SaveData then
    XMLConfig.SetDeleteValue(Path+'IsPartOfProject/Value',IsPartOfProject,false);

  if SaveSession and Assigned(Project.OnSaveUnitSessionInfo) then
    Project.OnSaveUnitSessionInfo(Self);
  if IsPartOfProject and SaveData then
    XMLConfig.SetDeleteValue(Path+'DisableI18NForLFM/Value',FDisableI18NForLFM,false);

  // context data (project/session)
  if (IsPartOfProject and SaveData) or ((not IsPartOfProject) and SaveSession)
  then begin
    XMLConfig.SetDeleteValue(Path+'ComponentName/Value',fComponentName,'');
    XMLConfig.SetDeleteValue(Path+'HasResources/Value',fHasResources,false);
    XMLConfig.SetDeleteValue(Path+'ResourceBaseClass/Value',
                             PFComponentBaseClassNames[FResourceBaseClass],
                             PFComponentBaseClassNames[pfcbcNone]);
    s:=FUnitName;
    if (s<>'') and (ExtractFileNameOnly(Filename)=s) then s:=''; // only save if UnitName differs from filename
    XMLConfig.SetDeleteValue(Path+'UnitName/Value',s,'');
    // save custom data
    SaveStringToStringTree(XMLConfig,CustomData,Path+'CustomData/');
  end;

  // session data
  if SaveSession then 
  begin
    FEditorInfoList[0].SaveToXMLConfig(XMLConfig, Path, pfSaveFoldState in Project.Flags);
    XMLConfig.SetDeleteValue(Path+'ExtraEditorCount/Value', FEditorInfoList.Count-1, 0);
    for i := 1 to FEditorInfoList.Count - 1 do
      FEditorInfoList[i].SaveToXMLConfig(XMLConfig, Path + 'ExtraEditor'+IntToStr(i)+'/',
                                         pfSaveFoldState in Project.Flags);

    XMLConfig.SetDeleteValue(Path+'ComponentState/Value',Ord(FComponentState),0);

    XMLConfig.SetDeleteValue(Path+'UsageCount/Value',RoundToInt(fUsageCount),-1);
    if OpenEditorInfoCount > 0 then
      for i := Bookmarks.Count - 1 downto 0 do
      begin
        BM := Bookmarks[i];
        if (Project.Bookmarks.BookmarkWithID(BM.ID) = nil) or
           (Project.Bookmarks.BookmarkWithID(BM.ID).UnitInfo <> self)
        then
          Bookmarks.Delete(i)
        else
        if OpenEditorInfo[0].EditorComponent.GetBookMark(BM.ID, X, Y) then
          BM.CursorPos := Point(X, Y);
      end;
    FBookmarks.SaveToXMLConfig(XMLConfig,Path+'Bookmarks/');
    XMLConfig.SetDeleteValue(Path+'Loaded/Value',fLoaded,false);
    XMLConfig.SetDeleteValue(Path+'LoadedDesigner/Value',fLoadedDesigner,false);
    XMLConfig.SetDeleteValue(Path+'ReadOnly/Value',fUserReadOnly,false);
    XMLConfig.SetDeleteValue(Path+'BuildFileIfActive/Value',
                             FBuildFileIfActive,false);
    XMLConfig.SetDeleteValue(Path+'RunFileIfActive/Value',
                             FRunFileIfActive,false);
    // save custom session data
    SaveStringToStringTree(XMLConfig,CustomSessionData,Path+'CustomSessionData/');
    XMLConfig.SetDeleteValue(Path+'DefaultSyntaxHighlighter/Value',
                             LazSyntaxHighlighterNames[FDefaultSyntaxHighlighter],
                             LazSyntaxHighlighterNames[lshFreePascal]);
  end;
end;

{------------------------------------------------------------------------------
  TUnitInfo LoadFromXMLConfig
 ------------------------------------------------------------------------------}
procedure TUnitInfo.LoadFromXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; Merge, IgnoreIsPartOfProject: boolean;
  FileVersion: integer);
var
  AFilename: string;
  c, i: Integer;
begin
  // project data
  if not Merge then begin
  
    AFilename:=XMLConfig.GetValue(Path+'Filename/Value','');
    if Assigned(fOnLoadSaveFilename) then
      fOnLoadSaveFilename(AFilename,true);
    fFilename:=AFilename;

    fComponentName:=XMLConfig.GetValue(Path+'ComponentName/Value','');
    if fComponentName='' then
      fComponentName:=XMLConfig.GetValue(Path+'FormName/Value','');
    FComponentState := TWindowState(XMLConfig.GetValue(Path+'ComponentState/Value',0));
    FDisableI18NForLFM:=XMLConfig.GetValue(Path+'DisableI18NForLFM/Value',false);
    HasResources:=XMLConfig.GetValue(Path+'HasResources/Value',false);
    FResourceBaseClass:=StrToComponentBaseClass(
                         XMLConfig.GetValue(Path+'ResourceBaseClass/Value',''));
    if not IgnoreIsPartOfProject then
      IsPartOfProject:=XMLConfig.GetValue(Path+'IsPartOfProject/Value',false);
    AFilename:=XMLConfig.GetValue(Path+'ResourceFilename/Value','');
    if (AFilename<>'') and Assigned(fOnLoadSaveFilename) then
      fOnLoadSaveFilename(AFilename,true);
    if FilenameIsPascalSource(Filename) then begin
      FUnitName:=XMLConfig.GetValue(Path+'UnitName/Value','');
      if FUnitName='' then
        FUnitName:=ExtractFileNameOnly(Filename);
      {$IFDEF VerboseIDESrcUnitName}
      if CompareFilenames(ExtractFileNameOnly(Filename),'interpkgconflictfiles')=0 then
        debugln(['TUnitInfo.LoadFromXMLConfig ',FUnitName]);
      {$ENDIF}
    end else
      FUnitName:='';

    // save custom data
    LoadStringToStringTree(XMLConfig,CustomData,Path+'CustomData/');
  end;

  // session data
  FDefaultSyntaxHighlighter := StrToLazSyntaxHighlighter(
    XMLConfig.GetValue(Path+'DefaultSyntaxHighlighter/Value',
                       LazSyntaxHighlighterNames[lshFreePascal]));
  FEditorInfoList.Clear;
  FEditorInfoList.NewEditorInfo;
  FEditorInfoList[0].LoadFromXMLConfig(XMLConfig, Path);
  c := XMLConfig.GetValue(Path+'ExtraEditorCount/Value', 0);
  for i := 1 to c do
    FEditorInfoList.NewEditorInfo.LoadFromXMLConfig(XMLConfig, Path + 'ExtraEditor'+IntToStr(i)+'/');
  UpdatePageIndex;

  Loaded:=XMLConfig.GetValue(Path+'Loaded/Value',false);
  if Loaded then
    LoadedDesigner:=XMLConfig.GetValue(Path+'LoadedDesigner/Value',FileVersion<8)
  else
    LoadedDesigner:=false;
  fUserReadOnly:=XMLConfig.GetValue(Path+'ReadOnly/Value',false);
  FBuildFileIfActive:=XMLConfig.GetValue(Path+'BuildFileIfActive/Value',false);
  FRunFileIfActive:=XMLConfig.GetValue(Path+'RunFileIfActive/Value',false);
  fUsageCount:=XMLConfig.GetValue(Path+'UsageCount/Value',-1);
  if fUsageCount<1 then begin
    UpdateUsageCount(uuIsLoaded,1);
    if IsPartOfProject then
      UpdateUsageCount(uuIsPartOfProject,1);
  end;
  FBookmarks.LoadFromXMLConfig(XMLConfig,Path+'Bookmarks/');
  // load custom session data
  LoadStringToStringTree(XMLConfig,CustomSessionData,Path+'CustomSessionData/');
end;

procedure TUnitInfo.SetUnitName(const AValue: string);
var
  Allowed: boolean;
  OldUnitName: String;
begin
  if (FUnitName <> AValue) and (AValue <> '') then
  begin
    Allowed := true;
    OldUnitName := FUnitName;
    if OldUnitName = '' then
      OldUnitName := ExtractFileNameOnly(Filename);
    if Assigned(FOnUnitNameChange) then
      FOnUnitNameChange(Self, OldUnitName, AValue, false, Allowed);
    // (ignore Allowed)
    if (fSource <> nil) then
    begin
      CodeToolBoss.RenameSource(fSource,AValue);
    end;
    {$IFDEF VerboseIDESrcUnitName}
    if CompareFilenames(ExtractFileNameOnly(Filename),'interpkgconflictfiles')=0 then
      debugln(['TUnitInfo.SetSrcUnitName ',AValue]);
    {$ENDIF}
    FUnitName := AValue;
    Modified := true;
    if (Project <> nil) then Project.UnitModified(Self);
  end;
end;

procedure TUnitInfo.UpdateList(ListType: TUnitInfoList; Add: boolean);
begin
  if Project<>nil then begin
    if Add then
      Project.AddToList(Self,ListType)
    else
      Project.RemoveFromList(Self,ListType);
  end else begin
    fNext[ListType]:=nil;
    fPrev[ListType]:=nil;
  end;
end;

procedure TUnitInfo.SetInternalFilename(const NewFilename: string);
begin
  if fFileName=NewFilename then exit;
  //DebugLn('TUnitInfo.SetInternalFilename Old=',fFileName,' New=',NewFilename);
  
  // if directory changed then remove the old directory reference
  if SourceDirectoryReferenced
  and (Project<>nil)
  and (fLastDirectoryReferenced<>GetDirectory) then begin
    Project.SourceDirectories.RemoveFilename(fLastDirectoryReferenced);
    FSourceDirectoryReferenced:=false;
  end;
  
  fFileName:=NewFilename;
  if IDEEditorOptions<>nil then
    UpdateDefaultHighlighter(FilenameToLazSyntaxHighlighter(FFilename));
  UpdateSourceDirectoryReference;
end;

procedure TUnitInfo.UpdateHasCustomHighlighter(aDefaultHighlighter: TLazSyntaxHighlighter);
var
  i: Integer;
begin
  FCustomDefaultHighlighter := FDefaultSyntaxHighlighter <> aDefaultHighlighter;
  for i := 0 to FEditorInfoList.Count - 1 do
    FEditorInfoList[i].CustomHighlighter :=
      FEditorInfoList[i].SyntaxHighlighter <> aDefaultHighlighter;
end;

procedure TUnitInfo.UpdatePageIndex;
var
  HasPageIndex: Boolean;
  i, j: integer;
  BM: TFileBookmark;
begin
  HasPageIndex := False;
  i := FEditorInfoList.Count - 1;
  while (i >= 0) and not HasPageIndex do begin
    if EditorInfo[i].PageIndex >= 0 then
      HasPageIndex := True;
    dec(i);
  end;
  UpdateList(uilWithEditorIndex, HasPageIndex);

  if Assigned(Project1) and Assigned(Project1.Bookmarks) then
  begin
    if OpenEditorInfoCount > 0 then begin
      inc(FSetBookmarLock);
      try
        // Adjust bookmarks
        for i := Bookmarks.Count-1 downto 0 do
        begin
          BM := Bookmarks[i];
          j := Project1.Bookmarks.IndexOfID(BM.ID);
          if (j < 0) then
            OpenEditorInfo[0].EditorComponent.SetBookMark(BM.ID, BM.CursorPos.X, BM.CursorPos.Y);
        end;
      finally
        dec(FSetBookmarLock);
      end;
    end
    else // OpenEditorInfoCount = 0
      Project1.Bookmarks.DeleteAllWithUnitInfo(Self);
  end;
end;

procedure TUnitInfo.UpdateDefaultHighlighter(aDefaultHighlighter: TLazSyntaxHighlighter);
var
  i: Integer;
begin
  //debugln(['TUnitInfo.UpdateDefaultHighlighter ',Filename,' ',ord(aDefaultHighlighter)]);
  if not FCustomDefaultHighlighter then
    DefaultSyntaxHighlighter := aDefaultHighlighter
  else
    for i := 0 to FEditorInfoList.Count - 1 do
      if not FEditorInfoList[i].CustomHighlighter then
        FEditorInfoList[i].SyntaxHighlighter := aDefaultHighlighter;
end;

function TUnitInfo.GetFileName: string;
begin
  if fSource<>nil then
    Result:=fSource.Filename
  else
    Result:=fFileName;
end;

procedure TUnitInfo.SetFilename(const AValue: string);
begin
  if fSource<>nil then
    RaiseGDBException('TUnitInfo.SetFilename Source<>nil')
  else
    SetInternalFilename(AValue);
end;

function TUnitInfo.IsVirtual: boolean;
begin
  if fSource<>nil then
    Result:=fSource.IsVirtual
  else
    Result:=not FilenameIsAbsolute(fFileName);
end;

function TUnitInfo.GetDirectory: string;
begin
  if IsVirtual then begin
    if Project<>nil then
      Result:=Project.Directory
    else
      Result:='';
  end else  begin
    Result:=ExtractFilePath(Filename);
  end;
end;

function TUnitInfo.GetFullFilename: string;
begin
  Result:=fFilename;
  // not saved files have file names without path
  // they exist in the Codetools filename space
end;

function TUnitInfo.GetShortFilename(UseUp: boolean): string;
begin
  if Project<>nil then
    Result:=Project.GetShortFilename(Filename,UseUp)
  else
    Result:=Filename;
end;

function TUnitInfo.IsMainUnit: boolean;
begin
  Result:=(Project<>nil) and (Project.MainUnitInfo=Self);
end;

procedure TUnitInfo.IncreaseAutoRevertLock;
begin
  inc(fAutoRevertLockCount);
  if fAutoRevertLockCount=1 then begin
    // activate lock
    if Source<>nil then
      Source.LockAutoDiskRevert;
    if Project<>nil then
      Project.AddToOrRemoveFromAutoRevertLockedList(Self);
  end;
end;

procedure TUnitInfo.DecreaseAutoRevertLock;
begin
  dec(fAutoRevertLockCount);
  if fAutoRevertLockCount=0 then begin
    // deactivate lock
    if Source<>nil then
      Source.LockAutoDiskRevert;
    if Project<>nil then
      Project.AddToOrRemoveFromAutoRevertLockedList(Self);
  end;
end;

function TUnitInfo.IsAutoRevertLocked: boolean;
begin
  Result:=fAutoRevertLockCount>0;
end;

function TUnitInfo.IsReverting: boolean;
begin
  Result:=FRevertLockCount>0;
end;

function TUnitInfo.ComponentLFMOnDiskHasChanged: boolean;
// Associated LFM resource file on disk has changed since last load/save
var
  ResFilename: String;
begin
  if fComponentLFMLoadDate=0 then Exit(false);   // 0 means there is no LFM file.
  ResFilename:=UnitResourceFileformat.GetUnitResourceFilename(Filename,true);
  Result:=fComponentLFMLoadDate<>FileAgeCached(ResFilename);
  if Result then
    DebugLn(['TUnitInfo.ComponentLFMOnDiskHasChanged ', ResFilename, ' changed on disk.']);
end;

procedure TUnitInfo.SetTimeStamps;
var
  ResFilename: String;
begin
  if FSource<>nil then
    fSourceChangeStep:=FSource.ChangeStep  // Indicates any change is source
  else
    fSourceChangeStep:=CTInvalidChangeStamp;
  // Associated LFM resource file timestamp
  //if Component=nil then exit;  <- Component is here always nil for some reason.
  if UnitResourceFileformat=nil then exit;   // Happens with LazBuild
  ResFilename:=UnitResourceFileformat.GetUnitResourceFilename(Filename,true);
  if FileExistsCached(ResFilename) then
    fComponentLFMLoadDate:=FileAgeCached(ResFilename);
end;

function TUnitInfo.ChangedOnDisk(CompareOnlyLoadSaveTime: boolean;
  IgnoreModifiedFlag: boolean): boolean;
begin
  Result:=(Source<>nil) and Source.FileOnDiskHasChanged(IgnoreModifiedFlag);
  if not Result then
    Result:=ComponentLFMOnDiskHasChanged;
  if Result
  and (not CompareOnlyLoadSaveTime)
  and FIgnoreFileDateOnDiskValid
  and (FIgnoreFileDateOnDisk=Source.FileDateOnDisk) then
    Result:=false;
  FileReadOnly:=(not IsVirtual) and FileExistsCached(Filename)
                 and not FileIsWritableCached(Filename);
end;

procedure TUnitInfo.IgnoreCurrentFileDateOnDisk;
begin
  if Source<>nil then begin
    FIgnoreFileDateOnDiskValid:=true;
    FIgnoreFileDateOnDisk:=Source.FileDateOnDisk;
  end
end;

function TUnitInfo.ShortFilename: string;
begin
  if Project<>nil then
    Result:=Project.RemoveProjectPathFromFilename(Filename)
  else
    Result:=Filename;
end;

function TUnitInfo.NeedsSaveToDisk: boolean;
begin
  Result:=IsVirtual or Modified or ChangedOnDisk(true);
  //DebugLn(['TUnitInfo.NeedsSaveToDisk ',filename,' Result=',Result,' Modified=',Modified]);
  if Result then Exit;
  if Source<>nil then
    Result:=Source.FileOnDiskNeedsUpdate
  else
    Result:=not FileExistsUTF8(Filename);
end;

procedure TUnitInfo.UpdateUsageCount(Min, IfBelowThis, IncIfBelow: extended);
begin
  if fUsageCount<IfBelowThis then fUsageCount:=fUsageCount+IncIfBelow;
  if fUsageCount<Min then fUsageCount:=Min;
end;

procedure TUnitInfo.UpdateUsageCount(TheUsage: TUnitUsage; const Factor: TDateTime);
begin
  case TheUsage of
  uuIsPartOfProject: UpdateUsageCount(20,200,2*Factor);
  uuIsLoaded:        UpdateUsageCount(10,100,1*Factor);
  uuIsModified:      UpdateUsageCount(10,0,0);
  uuNotUsed:         fUsageCount:=fUsageCount-(Factor/5);
  end;
end;

procedure TUnitInfo.UpdateSourceDirectoryReference;
begin
  FSourceDirNeedReference:=IsPartOfProject and (FilenameIsPascalSource(Filename));
  if (not AutoReferenceSourceDir) or (FProject=nil) then exit;
  if FSourceDirNeedReference then begin
    if not SourceDirectoryReferenced then begin
      fLastDirectoryReferenced:=GetDirectory;
      //DebugLn('TUnitInfo.UpdateSourceDirectoryReference ADD File="',Filename,'" Project.SourceDirectories.TimeStamp=',dbgs(Project.SourceDirectories.TimeStamp));
      FSourceDirectoryReferenced:=true;
      Project.SourceDirectories.AddFilename(fLastDirectoryReferenced);
    end;
  end else begin
    if SourceDirectoryReferenced then begin
      //DebugLn('TUnitInfo.UpdateSourceDirectoryReference REMOVE File="',Filename,'" Project.SourceDirectories.TimeStamp=',dbgs(Project.SourceDirectories.TimeStamp));
      FSourceDirectoryReferenced:=false;
      Project.SourceDirectories.RemoveFilename(fLastDirectoryReferenced);
    end;
  end;
end;

procedure TUnitInfo.SetSourceText(const SourceText: string; Beautify: boolean);
var
  Src: String;
begin
  Src:=SourceText;
  if Beautify then
    Src:=SourceEditorManagerIntf.Beautify(Src);
  Source.Source:=Src;
end;

function TUnitInfo.GetSourceText: string;
begin
  Result:=Source.Source;
end;

function TUnitInfo.AddRequiresComponentDependency(RequiredUnit: TUnitInfo;
  Types: TUnitCompDependencyTypes): TUnitComponentDependency;
begin
  if RequiredUnit=nil then RaiseGDBException('inconsistency');
  if RequiredUnit=Self then RaiseGDBException('inconsistency');
  // search a dependency to this RequiredUnit
  Result:=FirstRequiredComponent;
  while Result<>nil do begin
    if Result.RequiresUnit=RequiredUnit then break;
    Result:=Result.NextRequiresDependency;
  end;
  // if none exists, then create one
  if Result=nil then begin
    Result:=TUnitComponentDependency.Create;
    Result.UsedByUnit:=Self;
    Result.RequiresUnit:=RequiredUnit;
  end;
  Result.Types:=Result.Types+Types;
end;

procedure TUnitInfo.RemoveRequiresComponentDependency(RequiredUnit: TUnitInfo;
  Types: TUnitCompDependencyTypes);
var
  Dependency: TUnitComponentDependency;
  NextDependency: TUnitComponentDependency;
begin
  Dependency:=FirstRequiredComponent;
  while Dependency<>nil do begin
    NextDependency:=Dependency.NextRequiresDependency;
    if (Dependency.RequiresUnit=RequiredUnit) then begin
      Dependency.Types:=Dependency.Types-Types;
      if Dependency.Types=[] then
        Dependency.Free;
    end;
    Dependency:=NextDependency;
  end;
end;

function TUnitInfo.FindComponentDependency(RequiredUnit: TUnitInfo
  ): TUnitComponentDependency;
begin
  Result:=FirstRequiredComponent;
  while Result<>nil do begin
    if Result.RequiresUnit=RequiredUnit then exit;
    Result:=Result.NextRequiresDependency;
  end;
end;

function TUnitInfo.FindRequiredComponentDependency(
  MinTypes: TUnitCompDependencyTypes): TUnitComponentDependency;
begin
  Result:=FirstRequiredComponent;
  while Result<>nil do begin
    if Result.Types*MinTypes=MinTypes then exit;
    Result:=Result.NextRequiresDependency;
  end;
end;

function TUnitInfo.FindUsedByComponentDependency(
  MinTypes: TUnitCompDependencyTypes): TUnitComponentDependency;
begin
  Result:=FirstUsedByComponent;
  while Result<>nil do begin
    if Result.Types*MinTypes=MinTypes then exit;
    Result:=Result.NextUsedByDependency;
  end;
end;

function TUnitInfo.FindAncestorUnit: TUnitInfo;
var
  Dependency: TUnitComponentDependency;
begin
  if Component<>nil then begin
    Dependency:=FirstRequiredComponent;
    while Dependency<>nil do begin
      Result:=Dependency.RequiresUnit;
      if (Result.Component<>nil)
      and (Component.ClassParent=Result.Component.ClassType) then
        exit;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;
  Result:=nil;
end;

procedure TUnitInfo.ClearUnitComponentDependencies(
  ClearTypes: TUnitCompDependencyTypes);
var
  Dep: TUnitComponentDependency;
  NextDep: TUnitComponentDependency;
begin
  Dep:=FirstRequiredComponent;
  while Dep<>nil do begin
    NextDep:=Dep.NextRequiresDependency;
    Dep.Types:=Dep.Types-ClearTypes;
    if Dep.Types=[] then
      Dep.Free;
    Dep:=NextDep;
  end;
end;

function TUnitInfo.AddBookmark(X, Y, ID: integer): integer;
begin
  if FSetBookmarLock = 0 then
    Result := Bookmarks.Add(X, Y, ID)
  else
    Result := -1;
  SessionModified := True;
  Project1.AddBookmark(X, Y, ID, Self);
end;

procedure TUnitInfo.DeleteBookmark(ID: integer);
var
  i: Integer;
begin
  i := Bookmarks.IndexOfID(ID);
  if i >= 0 then begin
    Bookmarks.Delete(i);
    SessionModified := True;
  end;
  Project1.DeleteBookmark(ID);
end;

function TUnitInfo.EditorInfoCount: Integer;
begin
  Result := FEditorInfoList.Count;
end;

function TUnitInfo.OpenEditorInfoCount: Integer;
begin
  Result := FEditorInfoList.OpenCount;
end;

function TUnitInfo.GetClosedOrNewEditorInfo: TUnitEditorInfo;
begin
  if FEditorInfoList.ClosedCount > 0 then
    Result := FEditorInfoList.ClosedEditorInfos[0]
  else
    Result := FEditorInfoList.NewEditorInfo;
end;

procedure TUnitInfo.SetLastUsedEditor(AEditor: TSourceEditorInterface);
begin
  FEditorInfoList.SetLastUsedEditor(AEditor);
end;

function TUnitInfo.ReadOnly: boolean;
begin
  Result:=UserReadOnly or FileReadOnly;
end;

procedure TUnitInfo.SetSource(ABuffer: TCodeBuffer);
begin
  if fSource=ABuffer then begin
    if fSource<>nil then
      SetTimeStamps;
    exit;
  end;
  if (fSource<>nil) and IsAutoRevertLocked then
    fSource.UnlockAutoDiskRevert;
  fSource:=ABuffer;
  FIgnoreFileDateOnDiskValid:=false;
  if (fSource<>nil) then begin
    SetTimeStamps;
    if IsAutoRevertLocked then
      fSource.LockAutoDiskRevert;
    SetInternalFilename(fSource.FileName);
    if (fProject<>nil) and (fProject.MainUnitInfo=Self) then
      fProject.MainSourceFilenameChanged;
  end;
end;

procedure TUnitInfo.SetUserReadOnly(const NewValue: boolean);
begin
  fUserReadOnly:=NewValue;
  if fSource<>nil then
    fSource.ReadOnly:=ReadOnly;
end;

function TUnitInfo.GetHasResources:boolean;
begin
  Result:=fHasResources or (ComponentName<>'');
end;

function TUnitInfo.GetEditorInfo(Index: Integer): TUnitEditorInfo;
begin
  Result := FEditorInfoList[Index];
end;

function TUnitInfo.GetModified: boolean;
begin
  Result:=fModified
    or ((Source<>nil) and (Source.ChangeStep<>fSourceChangeStep));
end;

function TUnitInfo.GetNextAutoRevertLockedUnit: TUnitInfo;
begin
  Result:=fNext[uilAutoRevertLocked];
end;

function TUnitInfo.GetNextLoadedUnit: TUnitInfo;
begin
  Result:=fNext[uilLoaded];
end;

function TUnitInfo.GetNextPartOfProject: TUnitInfo;
begin
  Result:=fNext[uilPartOfProject];
end;

function TUnitInfo.GetNextUnitWithComponent: TUnitInfo;
begin
  Result:=fNext[uilWithComponent];
end;

function TUnitInfo.GetNextUnitWithEditorIndex: TUnitInfo;
begin
  Result:=fNext[uilWithEditorIndex];
end;

function TUnitInfo.GetOpenEditorInfo(Index: Integer): TUnitEditorInfo;
begin
  Result := FEditorInfoList.OpenEditorInfos[Index];
end;

function TUnitInfo.GetPrevAutoRevertLockedUnit: TUnitInfo;
begin
  Result:=fPrev[uilAutoRevertLocked];
end;

function TUnitInfo.GetPrevLoadedUnit: TUnitInfo;
begin
  Result:=fPrev[uilLoaded];
end;

function TUnitInfo.GetPrevPartOfProject: TUnitInfo;
begin
  Result:=fPrev[uilPartOfProject];
end;

function TUnitInfo.GetPrevUnitWithComponent: TUnitInfo;
begin
  Result:=fPrev[uilWithComponent];
end;

function TUnitInfo.GetPrevUnitWithEditorIndex: TUnitInfo;
begin
  Result:=fPrev[uilWithEditorIndex];
end;

function TUnitInfo.GetUnitResourceFileformat: TUnitResourcefileFormatClass;
var
  ResourceFormats : TUnitResourcefileFormatArr;
  i: integer;
begin
  if not assigned(FUnitResourceFileformat) then
  begin
    if Source=nil then
      Source:=CodeToolBoss.LoadFile(Filename,true,false);
    if Source<>nil then
    begin
      ResourceFormats := GetUnitResourcefileFormats;
      for i := 0 to high(ResourceFormats) do
      begin
        if ResourceFormats[i].FindResourceDirective(Source) then
        begin
          FUnitResourceFileformat:=ResourceFormats[i];
          Result := FUnitResourceFileformat;
          Exit;
        end;
      end;
    end;
    FUnitResourceFileformat := LFMUnitResourcefileFormat;
  end;
  Result := FUnitResourceFileformat;
end;

procedure TUnitInfo.SetAutoReferenceSourceDir(const AValue: boolean);
begin
  if FAutoReferenceSourceDir=AValue then exit;
  FAutoReferenceSourceDir:=AValue;
  UpdateSourceDirectoryReference;
end;

procedure TUnitInfo.SetBuildFileIfActive(const AValue: boolean);
begin
  if FBuildFileIfActive=AValue then exit;
  FBuildFileIfActive:=AValue;
  SessionModified:=true;
end;

procedure TUnitInfo.SetDefaultSyntaxHighlighter(const AValue: TLazSyntaxHighlighter);
var
  i: Integer;
begin
  if FDefaultSyntaxHighlighter = AValue then exit;
  FDefaultSyntaxHighlighter := AValue;
  for i := 0 to FEditorInfoList.Count - 1 do
    if not FEditorInfoList[i].CustomHighlighter then
      FEditorInfoList[i].SyntaxHighlighter := AValue;
end;

procedure TUnitInfo.SetDirectives(const AValue: TStrings);
begin
  if FDirectives=AValue then exit;
  FDirectives:=AValue;
end;

procedure TUnitInfo.SetDisableI18NForLFM(const AValue: boolean);
begin
  if FDisableI18NForLFM=AValue then exit;
  FDisableI18NForLFM:=AValue;
  Modified:=true;
end;

procedure TUnitInfo.SetFileReadOnly(const AValue: Boolean);
begin
  if fFileReadOnly=AValue then exit;
  fFileReadOnly:=AValue;
  if fSource<>nil then
    fSource.ReadOnly:=ReadOnly;
  SessionModified:=true;
end;

procedure TUnitInfo.SetComponent(const AValue: TComponent);
begin
  if fComponent=AValue then exit;
  fComponent:=AValue;
  UpdateList(uilWithComponent,fComponent<>nil);
  if fComponent=nil then
    ClearComponentDependencies
  else
    FResourceBaseClass:=GetComponentBaseClass(fComponent.ClassType);
end;

procedure TUnitInfo.SetIsPartOfProject(const AValue: boolean);
begin
  if IsPartOfProject=AValue then exit;
  if Project<>nil then Project.BeginUpdate(true);
  inherited SetIsPartOfProject(AValue);
  Modified:=true;
  UpdateList(uilPartOfProject,IsPartOfProject);
  if IsPartOfProject then UpdateUsageCount(uuIsPartOfProject,0);
  UpdateSourceDirectoryReference;
  if Project<>nil then Project.EndUpdate;
end;

{-------------------------------------------------------------------------------
  procedure TUnitInfo.SetLoaded(const AValue: Boolean);

  Loaded is a flag, that is set, when a unit has finished loading into the
  editor. It is saved to the project session file and a loaded unit will be
  reloaded, when the project is opened.
-------------------------------------------------------------------------------}
procedure TUnitInfo.SetLoaded(const AValue: Boolean);
begin
  if fLoaded=AValue then exit;
  fLoaded:=AValue;
  if fLoaded then begin
    IncreaseAutoRevertLock;
    UpdateUsageCount(uuIsLoaded,0);
  end else begin
    DecreaseAutoRevertLock;
  end;
end;

{-------------------------------------------------------------------------------
  procedure TUnitInfo.SetLoadedDesigner(const AValue: Boolean);

  LoadedDesigner is a flag, that is set, when a visible designer form has
  finished opening. It is saved to the project session file and a designer
  is restored, when the project is opened and the IDE form editor option
  auto open designer forms is enabled.
-------------------------------------------------------------------------------}
procedure TUnitInfo.SetLoadedDesigner(const AValue: Boolean);
begin
  if fLoadedDesigner=AValue then exit;
  fLoadedDesigner:=AValue;
end;

procedure TUnitInfo.SetModified(const AValue: boolean);
begin
  if Modified=AValue then exit;
  {$IFDEF VerboseIDEModified}
  debugln(['TUnitInfo.SetModified ',Filename,' new Modified=',AValue]);
  {$ENDIF}
  fModified:=AValue;
  if (not fModified) and Assigned(Source) then
    SetTimeStamps;
end;

procedure TUnitInfo.SetProject(const AValue: TProject);
var
  ListType: TUnitInfoList;
  i: Integer;
begin
  if FProject=AValue then exit;
  if FProject<>nil then begin
    for ListType:=Low(TUnitInfoList) to High(TUnitInfoList) do
      Project.RemoveFromList(Self,ListType);
    for i := 0 to FEditorInfoList.Count - 1 do
      FProject.EditorInfoRemove(FEditorInfoList[i]);
  end;
  FProject:=AValue;
  if FProject<>nil then begin
    UpdatePageIndex;
    if Component<>nil then
      Project.AddToList(Self,uilWithComponent);
    if Loaded then
      Project.AddToList(Self,uilLoaded);
    if IsAutoRevertLocked then
      Project.AddToList(Self,uilAutoRevertLocked);
    if IsPartOfProject then
      Project.AddToList(Self,uilPartOfProject);
    for i := 0 to FEditorInfoList.Count - 1 do
      FProject.EditorInfoAdd(FEditorInfoList[i]);
  end;
  UpdateSourceDirectoryReference;
end;

procedure TUnitInfo.SetRunFileIfActive(const AValue: boolean);
begin
  if FRunFileIfActive=AValue then exit;
  FRunFileIfActive:=AValue;
  SessionModified:=true;
end;

procedure TUnitInfo.SetSessionModified(const AValue: boolean);
begin
  if FSessionModified=AValue then exit;
  {$IFDEF VerboseIDEModified}
  debugln(['TUnitInfo.SetSessionModified ',Filename,' new Modified=',AValue]);
  {$ENDIF}
  FSessionModified:=AValue;
end;


{ TProjectIDEOptions }

constructor TProjectIDEOptions.Create(AProject: TProject);
begin
  inherited Create;
  FProject := AProject;
end;

destructor TProjectIDEOptions.Destroy;
begin
  inherited Destroy;
end;

function TProjectIDEOptions.GetProject: TLazProject;
begin
  Result := FProject;
end;

function TProjectIDEOptions.CheckLclApp: Boolean;
begin
  FLclApp := FProject.IsLclApplication;
  Result := FLclApp;
end;

class function TProjectIDEOptions.GetInstance: TAbstractIDEOptions;
begin
  if Project1<>nil then
    Result := Project1.IDEOptions
  else
    Result := nil;
end;

class function TProjectIDEOptions.GetGroupCaption: string;
begin
  Result := dlgProjectOptions;
end;


{------------------------------------------------------------------------------
                              TProject Class
 ------------------------------------------------------------------------------}

{------------------------------------------------------------------------------
  TProject Constructor
 ------------------------------------------------------------------------------}
constructor TProject.Create(ProjectDescription: TProjectDescriptor);
begin
  inherited Create(ProjectDescription);

  FActiveWindowIndexAtStart := 0;
  FSkipCheckLCLInterfaces:=false;
  FAutoCreateForms := true;
  FAllEditorsInfoList := TUnitEditorInfoList.Create(nil);
  FAllEditorsInfoMap := TMap.Create(ituPtrSize, SizeOf(TObject));
  FBookmarks := TProjectBookmarkList.Create;

  FMacroEngine:=TTransferMacroList.Create;
  FMacroEngine.OnSubstitution:=@OnMacroEngineSubstitution;
  FBuildModes:=TProjectBuildModes.Create(nil);
  FBuildModes.LazProject:=Self;
  FBuildModesBackup:=TProjectBuildModes.Create(nil);
  FBuildModesBackup.LazProject:=Self;
  ActiveBuildMode:=FBuildModes.Add('Default');

  FDefineTemplates:=TProjectDefineTemplates.Create(Self);
  FFlags:=DefaultProjectFlags;
  FJumpHistory:=TProjectJumpHistory.Create;
  FJumpHistory.OnCheckPosition:=@JumpHistoryCheckPosition;
  FJumpHistory.OnLoadSaveFilename:=@LoadSaveFilenameHandler;
  fMainUnitID := -1;
  fProjectInfoFile := '';
  ProjectSessionFile:='';
  FSourceDirectories:=TFileReferenceList.Create;
  FSourceDirectories.OnChanged:=@SourceDirectoriesChanged;
  UpdateProjectDirectory;
  FIDEOptions:=TProjectIDEOptions.Create(Self);
  FPublishOptions:=TPublishProjectOptions.Create(Self);
  FRunParameters:=TRunParamsOptions.Create;
  Title := '';
  FUnitList := TFPList.Create;  // list of TUnitInfo
  FOtherDefines := TStringList.Create;
  FEnableI18N := False;
  FEnableI18NForLFM := True;
  FI18NExcludedIdentifiers := TStringList.Create;
  FI18NExcludedOriginals := TStringList.Create;

  FResources := TProjectResources.Create(Self);
  ProjResources.OnModified := @EmbeddedObjectModified;

  FHistoryLists := THistoryLists.Create;
end;

{------------------------------------------------------------------------------
  TProject Destructor
 ------------------------------------------------------------------------------}
destructor TProject.Destroy;
begin
  FDestroying := True;
  FDefineTemplates.Active := False;
  ActiveBuildMode:=nil;
  Clear;
  FreeThenNil(FIDEOptions);
  FreeAndNil(FBuildModesBackup);
  FreeAndNil(FBuildModes);
  FreeAndNil(FMacroEngine);
  FreeAndNil(FAllEditorsInfoMap);
  FreeAndNil(FAllEditorsInfoList);
  FreeThenNil(FResources);
  FreeThenNil(FBookmarks);
  FreeThenNil(FI18NExcludedOriginals);
  FreeThenNil(FI18NExcludedIdentifiers);
  FreeThenNil(FOtherDefines);
  FreeThenNil(FUnitList);
  FreeThenNil(FJumpHistory);
  FreeThenNil(FSourceDirectories);
  FreeThenNil(FPublishOptions);
  FreeThenNil(FRunParameters);
  FreeThenNil(FDefineTemplates);
  FreeThenNil(FHistoryLists);

  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Methods for ReadProject
 ------------------------------------------------------------------------------}

function TProject.LoadOldProjectType(const Path: string): TOldProjectType;

  function OldProjectTypeNameToType(const s: string): TOldProjectType;
  begin
    for Result:=Low(TOldProjectType) to High(TOldProjectType) do
      if (CompareText(OldProjectTypeNames[Result],s)=0) then exit;
    Result:=ptApplication;
  end;

begin
  if FFileVersion<=4 then
    Result:=OldProjectTypeNameToType(FXMLConfig.GetValue(Path+'General/ProjectType/Value', ''))
  else
    Result:=ptCustomProgram;
end;

procedure TProject.LoadFlags(const Path: string);

  procedure SetFlag(f: TProjectFlag; Value: boolean);
  begin
    if Value then Include(FFlags,f) else Exclude(FFlags,f);
  end;

var
  f: TProjectFlag;
  OldProjectType: TOldProjectType;
  DefFlags: TProjectFlags;
begin
  OldProjectType:=LoadOldProjectType(Path);
  DefFlags:=DefaultProjectFlags;
  if FFileVersion<7 then
    Exclude(DefFlags,pfLRSFilesInOutputDirectory);
  Flags:=[];
  for f:=Low(TProjectFlag) to High(TProjectFlag) do
    SetFlag(f,FXMLConfig.GetValue(Path+'General/Flags/'+ProjectFlagNames[f]+'/Value',f in DefFlags));
  if FFileVersion<=3 then begin
    // set new flags
    SetFlag(pfMainUnitIsPascalSource, OldProjectType in [ptProgram,ptApplication]);
    SetFlag(pfMainUnitHasUsesSectionForAllUnits, OldProjectType in [ptProgram,ptApplication]);
    SetFlag(pfMainUnitHasCreateFormStatements, OldProjectType in [ptApplication]);
    SetFlag(pfMainUnitHasTitleStatement,OldProjectType in [ptApplication]);
    SetFlag(pfMainUnitHasScaledStatement,OldProjectType in [ptApplication]);
    SetFlag(pfRunnable, OldProjectType in [ptProgram,ptApplication,ptCustomProgram]);
  end;
  if FFileVersion<=11 then begin
    // set CompatibilityMode flag for legacy projects (this flag was added in FFileVersion=12 that changed
    // item format so that LPI cannot be opened in legacy Lazarus unless pfCompatibilityMode is set)
    SetFlag(pfCompatibilityMode, True);
  end;
  Flags:=Flags-[pfUseDefaultCompilerOptions];
end;

procedure TProject.LoadOtherDefines(const Path: string);
var
  Cnt, i: Integer;
  SubPath, s: String;
begin
  SubPath := 'OtherDefines/';
  if not FXMLConfig.HasPath(Path+SubPath, False) then
    SubPath := 'CustomDefines/';    // Load from the old path name.
  Cnt := FXMLConfig.GetValue(Path+SubPath+'Count', 0);
  for i := 0 to Cnt-1 do
  begin
    s := FXMLConfig.GetValue(Path+SubPath+'Define'+IntToStr(i)+'/Value', '');
    if s <> '' then
      FOtherDefines.Add(s);
  end;
end;

procedure TProject.LoadSessionInfo(const Path: string; Merge: boolean);
// Note: the session can be stored in the lpi as well
// So this method is used for loading the lpi units as well
var
  NewUnitInfo: TUnitInfo;
  NewUnitCount, i: integer;
  SubPath: String;
  NewUnitFilename: String;
  OldUnitInfo: TUnitInfo;
  MergeUnitInfo, LegacyList: Boolean;
begin
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject D reading units');{$ENDIF}
  LegacyList:=(FFileVersion<=11) or FXMLConfig.IsLegacyList(Path+'Units/');
  NewUnitCount:=FXMLConfig.GetListItemCount(Path+'Units/', 'Unit', LegacyList);
  for i := 0 to NewUnitCount - 1 do begin
    SubPath:=Path+'Units/'+FXMLConfig.GetListItemXPath('Unit', i, LegacyList)+'/';
    NewUnitFilename:=FXMLConfig.GetValue(SubPath+'Filename/Value','');
    LoadSaveFilenameHandler(NewUnitFilename,true);
    // load unit and add it
    OldUnitInfo:=UnitInfoWithFilename(NewUnitFilename);
    if OldUnitInfo<>nil then begin
      // unit already exists
      if Merge then begin
        NewUnitInfo:=OldUnitInfo;
        MergeUnitInfo:=true;
      end else begin
        // Doppelganger -> inconsistency found, ignore this file
        debugln('TProject.ReadProject file exists twice in lpi file: ignoring "'+NewUnitFilename+'"');
        continue;
      end;
    end else begin
      NewUnitInfo:=TUnitInfo.Create(nil);
      AddFile(NewUnitInfo,false);
      MergeUnitInfo:=false;
    end;

    NewUnitInfo.LoadFromXMLConfig(FXMLConfig,SubPath,MergeUnitInfo,Merge,FFileVersion);
    if i=FNewMainUnitID then begin
      MainUnitID:=IndexOf(NewUnitInfo);
      FNewMainUnitID:=-1;
    end;
  end;

  // load editor info
  i := FXMLConfig.GetValue(Path+'General/ActiveEditorIndexAtStart/Value', -1);
  if (i >= 0) then
    UpdateVisibleEditor(i);     // Load old Config => No WindowIndex

  ActiveWindowIndexAtStart := FXMLConfig.GetValue(Path+'General/ActiveWindowIndexAtStart/Value', 0);
  FSkipCheckLCLInterfaces:=FXMLConfig.GetValue(Path+'SkipCheckLCLInterfaces/Value',false);
  FJumpHistory.LoadFromXMLConfig(FXMLConfig,Path+'');
  CleanOutputFileMask:=FXMLConfig.GetValue(Path+'Build/CleanOutputFileMask/Value',
               DefaultProjectCleanOutputFileMask);
  CleanSourcesFileMask:=FXMLConfig.GetValue(Path+'Build/CleanSourcesFileMask/Value',
               DefaultProjectCleanSourcesFileMask);

  // load custom session data
  LoadStringToStringTree(FXMLConfig,CustomSessionData,Path+'CustomSessionData/');
end;

procedure TProject.LoadFromLPI;
const
  Path = ProjOptionsPath;
begin
  if (FFileVersion=0) and (FXMLConfig.GetListItemCount(Path+'Units/', 'Unit', true)=0) then
    if IDEMessageDialog(lisStrangeLpiFile,
        Format(lisTheFileDoesNotLookLikeALpiFile, [ProjectInfoFile]),
        mtConfirmation,[mbIgnore,mbAbort])<>mrIgnore
    then exit;

  LoadFlags(Path);
  SessionStorage:=StrToProjectSessionStorage(
    FXMLConfig.GetValue(Path+'General/SessionStorage/Value',
                        ProjectSessionStorageNames[DefaultProjectSessionStorage]));
  //DebugLn('TProject.ReadProject SessionStorage=',dbgs(ord(SessionStorage)),' ProjectSessionFile=',ProjectSessionFile);

  // load properties
  // Note: in FFileVersion<9 the default value was -1
  //   Since almost all projects have a MainUnit the value 0 was always
  //   added to the lpi.
  //   Changing the default value to 0 avoids the redundancy and
  //   automatically fixes broken lpi files.
  FNewMainUnitID := FXMLConfig.GetValue(Path+'General/MainUnit/Value', 0);
  Title := FXMLConfig.GetValue(Path+'General/Title/Value', '');
  Scaled := FXMLConfig.GetValue(Path+'General/Scaled/Value', False);
  AutoCreateForms := FXMLConfig.GetValue(Path+'General/AutoCreateForms/Value', true);

  // fpdoc
  FPDocPaths:=SwitchPathDelims(FXMLConfig.GetValue(Path+'LazDoc/Paths',''),fPathDelimChanged);
  FPDocPackageName:=FXMLConfig.GetValue(Path+'LazDoc/PackageName','');

  // i18n
  if FFileVersion<6 then begin
    POOutputDirectory := SwitchPathDelims(
               FXMLConfig.GetValue(Path+'RST/OutDir', ''),fPathDelimChanged);
    EnableI18N := POOutputDirectory <> '';
  end else begin
    EnableI18N := FXMLConfig.GetValue(Path+'i18n/EnableI18N/Value', False);
    EnableI18NForLFM := FXMLConfig.GetValue(Path+'i18n/EnableI18N/LFM', True);
    POOutputDirectory := SwitchPathDelims(
         FXMLConfig.GetValue(Path+'i18n/OutDir/Value', ''),fPathDelimChanged);
    LoadStringList(FXMLConfig, FI18NExcludedIdentifiers, Path+'i18n/ExcludedIdentifiers/');
    LoadStringList(FXMLConfig, FI18NExcludedOriginals, Path+'i18n/ExcludedOriginals/');
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject E reading comp sets');{$ENDIF}

  // load custom data
  LoadStringToStringTree(FXMLConfig,CustomData,Path+'CustomData/');
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject update ct boss');{$ENDIF}
  CodeToolBoss.GlobalValues.Variables[ExternalMacroStart+'ProjPath']:=Directory;
  CodeToolBoss.DefineTree.ClearCache;
  // load the dependencies
  LoadPkgDependencyList(FXMLConfig,Path+'RequiredPackages/',
                        FFirstRequiredDependency,pddRequires,Self,true,false);
  // load the Run and Build parameter Options
  RunParameterOptions.Clear;
  if FFileVersion<11 then
    RunParameterOptions.LegacyLoad(FXMLConfig,Path,fPathDelimChanged)
  else
    RunParameterOptions.Load(FXMLConfig,Path+'RunParams/',fPathDelimChanged,rpsLPI);
  // load the Publish Options
  PublishOptions.LoadFromXMLConfig(FXMLConfig,Path+'PublishOptions/',fPathDelimChanged);
  // load defines used for custom options
  LoadOtherDefines(Path);
  // load session info
  LoadSessionInfo(Path,false);

  FDebuggerBackend := FXMLConfig.GetValue(Path+'Debugger/Backend/Value', '');

  // call hooks to read their info (e.g. DebugBoss)
  if Assigned(OnLoadProjectInfo) then
    OnLoadProjectInfo(Self, FXMLConfig, false);
end;

procedure TProject.LoadFromSession;
const
  Path = 'ProjectSession/';
var
  pds: TPathDelimSwitch;
begin
  pds:=CheckPathDelim(FXMLConfig.GetValue(Path+'PathDelim/Value', '/'),
                      fPathDelimChanged);
  SessionStorePathDelim:=pds;
  fCurStorePathDelim:=pds;

  FFileVersion:=FXMLConfig.GetValue(Path+'Version/Value',0);

  // load MacroValues and compiler options
  BuildModes.LoadSessionFromXMLConfig(FXMLConfig, Path, FLoadAllOptions);

  // load defines used for custom options
  LoadOtherDefines(Path);
  // load session info
  LoadSessionInfo(Path,true);

  if FFileVersion>=11 then
    RunParameterOptions.Load(FXMLConfig,Path+'RunParams/',fPathDelimChanged,rpsLPS);
  HistoryLists.Clear;
  if FFileVersion>=12 then
    HistoryLists.LoadFromXMLConfig(FXMLConfig,Path+'HistoryLists/');

  // call hooks to read their info (e.g. DebugBoss)
  if Assigned(OnLoadProjectInfo) then
    OnLoadProjectInfo(Self,FXMLConfig,true);
end;

function TProject.DoLoadLPI(Filename: String): TModalResult;
var
  PIFile: String;
begin
  Result:=mrOk;
  if FLoadAllOptions then
  begin
    // read the whole lpi, clear any old values
    Clear;
    ProjectInfoFile:=Filename;
    PIFile:=ProjectInfoFile;    // May be different from Filename, setter changed.
    fProjectInfoFileBuffer:=CodeToolBoss.LoadFile(PIFile,true,true);
    fProjectInfoFileBufChangeStamp:=CTInvalidChangeStamp;
    try
      fProjectInfoFileDate:=FileAgeCached(PIFile);
      {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject A reading lpi');{$ENDIF}
      if fProjectInfoFileBuffer=nil then
        FXMLConfig := TCodeBufXMLConfig.CreateWithCache(PIFile,false)
      else begin
        FXMLConfig := TCodeBufXMLConfig.CreateWithCache(PIFile,false,true,
                                                  fProjectInfoFileBuffer.Source);
        fProjectInfoFileBufChangeStamp:=fProjectInfoFileBuffer.ChangeStep;
      end;
      {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject B done lpi');{$ENDIF}
    except
      on E: Exception do begin
        IDEMessageDialog(lisUnableToReadLpi,
            Format(lisUnableToReadTheProjectInfoFile,[LineEnding,PIFile])+LineEnding+E.Message,
            mtError, [mbOk]);
        Result:=mrCancel;
        exit;
      end;
    end;
    fLastReadLPIFilename:=PIFile;
    fLastReadLPIFileDate:=Now;
    FNewMainUnitID:=-1;
  end
  else begin
    // read only parts of the lpi, keep other values
    try
      FXMLConfig := TCodeBufXMLConfig.CreateWithCache(Filename,true)
    except
      on E: Exception do begin
        IDEMessageDialog(lisUnableToReadLpi,
            Format(lisUnableToReadTheProjectInfoFile,[LineEnding,Filename])+LineEnding+E.Message,
            mtError, [mbOk]);
        Result:=mrCancel;
        exit;
      end;
    end;
  end;

  try
    // get format
    fStorePathDelim:=CheckPathDelim(FXMLConfig.GetValue(ProjOptionsPath+'PathDelim/Value','/'),
                                    fPathDelimChanged);
    fCurStorePathDelim:=StorePathDelim;
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject C reading values');{$ENDIF}
    FFileVersion:= FXMLConfig.GetValue(ProjOptionsPath+'Version/Value',0);
    UseAppBundle := FXMLConfig.GetValue(ProjOptionsPath+'General/UseAppBundle/Value', True);
    NSPrincipalClass := FXMLConfig.GetValue(ProjOptionsPath+'General/NSPrincipalClass/Value', '');
    if FLoadAllOptions then
      LoadFromLPI;
    // Resources
    ProjResources.ReadFromProjectFile(FXMLConfig, ProjOptionsPath, FLoadAllOptions);
    // load MacroValues and compiler options
    ClearBuildModes;
    BuildModes.LoadProjOptsFromXMLConfig(FXMLConfig, ProjOptionsPath);
    // load matrix options
    BuildModes.SharedMatrixOptions.LoadFromXMLConfig(FXMLConfig,
                              ProjOptionsPath+'BuildModes/SharedMatrixOptions/');
  finally
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject freeing xml');{$ENDIF}
    fPathDelimChanged:=false;
    try
      FXMLConfig.Modified:=false;
      FXMLConfig.Free;
    except
    end;
    FXMLConfig:=nil;
  end;
end;

function TProject.DoLoadSession(Filename: String): TModalResult;
begin
  Result:=mrOK;
  if FileExistsUTF8(Filename) then
  begin
    //DebugLn('TProject.ReadProject loading Session Filename=',Filename);
    try
      FXMLConfig := TCodeBufXMLConfig.CreateWithCache(Filename);
      LoadFromSession;
    except
      IDEMessageDialog(lisCCOErrorCaption,
        Format(lisUnableToReadTheProjectInfoFile, [LineEnding,Filename]),
        mtError,[mbOk]);
      Result:=mrCancel;
      exit;
    end;

    fPathDelimChanged:=false;
    try
      FXMLConfig.Modified:=false;
      FXMLConfig.Free;
    except
    end;
    fCurStorePathDelim:=StorePathDelim;
    FXMLConfig:=nil;
  end else
    // there is no .lps file -> create some defaults
    LoadDefaultSession;
end;

function TProject.DoLoadLPR(Revert: boolean): TModalResult;
// lpr is here the main module, it does not need to have the extension .lpr
var
  LPRUnitInfo: TUnitInfo;
begin
  Result:=mrOk;
  if (MainUnitID<0) or (not (pfMainUnitIsPascalSource in Flags)) then
    exit; // has no lpr
  LPRUnitInfo:=MainUnitInfo;
  if (LPRUnitInfo.Source=nil) then begin
    LPRUnitInfo.Source:=CodeToolBoss.LoadFile(LPRUnitInfo.Filename,true,Revert);
    if LPRUnitInfo.Source=nil then exit(mrCancel);
  end;

  UpdateIsPartOfProjectFromMainUnit;
end;

// Method ReadProject itself
function TProject.ReadProject(const NewProjectInfoFile: string;
  GlobalMatrixOptions: TBuildMatrixOptions; LoadAllOptions: Boolean): TModalResult;
begin
  Result := mrCancel;
  BeginUpdate(true);
  try
    BuildModes.FGlobalMatrixOptions := GlobalMatrixOptions;
    FLoadAllOptions := LoadAllOptions;

    // load project lpi file
    Result:=DoLoadLPI(NewProjectInfoFile);
    if Result<>mrOK then Exit;

    // load session file (if available)
    if (SessionStorage in pssHasSeparateSession)
    and (CompareFilenames(ProjectInfoFile,ProjectSessionFile)<>0)
    and FLoadAllOptions then
    begin
      Result:=DoLoadSession(ProjectSessionFile);
      if Result<>mrOK then Exit;
    end;

    // load lpr
    if (pfMainUnitIsPascalSource in Flags) and (MainUnitInfo<>nil) then
      DoLoadLPR(false); // ignore errors

  finally
    EndUpdate;
    FAllEditorsInfoList.SortByPageIndex;
  end;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TProject.ReadProject END');{$ENDIF}
  Result := mrOk;
end;

{------------------------------------------------------------------------------
  Methods for TProject WriteProject
 ------------------------------------------------------------------------------}

procedure TProject.SaveFlags(const Path: string);
var
  f: TProjectFlag;
begin
  for f:=Low(TProjectFlag) to High(TProjectFlag) do begin
    FXMLConfig.SetDeleteValue(Path+'General/Flags/'
        +ProjectFlagNames[f]+'/Value', f in Flags, f in DefaultProjectFlags);
  end;
end;

procedure TProject.SaveUnits(const Path: string; SaveSession: boolean);
var
  i, SaveUnitCount: integer;
begin
  SaveUnitCount:=0;
  for i:=0 to UnitCount-1 do
    if UnitMustBeSaved(Units[i],FProjectWriteFlags,SaveSession) then begin
      Units[i].SaveToXMLConfig(FXMLConfig,
        Path+'Units/'+FXMLConfig.GetListItemXPath('Unit', SaveUnitCount, UseLegacyLists)+'/',True,SaveSession,fCurStorePathDelim);
      inc(SaveUnitCount);
    end;
  FXMLConfig.SetListItemCount(Path+'Units/',SaveUnitCount,UseLegacyLists);
end;

procedure TProject.SaveOtherDefines(const Path: string);
var
  i: integer;
begin
  for i:=0 to FOtherDefines.Count-1 do
    FXMLConfig.SetDeleteValue(Path+'OtherDefines/Define'+IntToStr(i)+'/Value',
                              FOtherDefines[i],'');
  FXMLConfig.SetDeleteValue(Path+'OtherDefines/Count',FOtherDefines.Count,0);
end;

procedure TProject.SaveSessionInfo(const Path: string);
begin
  FXMLConfig.DeleteValue(Path+'General/ActiveEditorIndexAtStart/Value');
  FXMLConfig.SetDeleteValue(Path+'General/ActiveWindowIndexAtStart/Value',
                         ActiveWindowIndexAtStart,0);
  FXMLConfig.SetDeleteValue('SkipCheckLCLInterfaces/Value',
                         FSkipCheckLCLInterfaces,false);
  FXMLConfig.SetDeleteValue(Path+'Build/CleanOutputFileMask/Value',
               CleanOutputFileMask,DefaultProjectCleanOutputFileMask);
  FXMLConfig.SetDeleteValue(Path+'Build/CleanSourcesFileMask/Value',
               CleanSourcesFileMask,DefaultProjectCleanSourcesFileMask);

  if (not (pfSaveOnlyProjectUnits in Flags))
  and (not (pwfSkipJumpPoints in FProjectWriteFlags)) then begin
    if (pfSaveJumpHistory in Flags) then begin
      FJumpHistory.DeleteInvalidPositions;
      FJumpHistory.SaveToXMLConfig(FXMLConfig,Path,UseLegacyLists);
    end
    else
      FXMLConfig.DeletePath(Path+'JumpHistory');
  end;

  // save custom session data
  SaveStringToStringTree(FXMLConfig,CustomSessionData,Path+'CustomSessionData/');
end;

procedure TProject.SaveToLPI;
const
  Path = ProjOptionsPath;
var
  CurFlags: TProjectWriteFlags;
begin
  FFileVersion:=ProjectInfoFileVersion;
  // format
  FXMLConfig.SetValue(Path+'Version/Value',ProjectInfoFileVersion);
  FXMLConfig.SetDeleteValue(Path+'PathDelim/Value',PathDelimSwitchToDelim[fCurStorePathDelim],'/');
  SaveFlags(Path);
  FXMLConfig.SetDeleteValue(Path+'General/SessionStorage/Value',
                           ProjectSessionStorageNames[SessionStorage],
                           ProjectSessionStorageNames[DefaultProjectSessionStorage]);
  // general properties
  FXMLConfig.SetDeleteValue(Path+'General/MainUnit/Value', MainUnitID ,0);
  FXMLConfig.SetDeleteValue(Path+'General/AutoCreateForms/Value',
                           AutoCreateForms,true);
  FXMLConfig.SetDeleteValue(Path+'General/Title/Value', Title,'');
  FXMLConfig.SetDeleteValue(Path+'General/Scaled/Value', Scaled,False);
  FXMLConfig.SetDeleteValue(Path+'General/UseAppBundle/Value', UseAppBundle, True);
  FXMLConfig.SetDeleteValue(Path+'General/NSPrincipalClass/Value', NSPrincipalClass, '');

  // fpdoc
  FXMLConfig.SetDeleteValue(Path+'LazDoc/Paths',
     SwitchPathDelims(CreateRelativeSearchPath(FPDocPaths,Directory),
                      fCurStorePathDelim), '');
  FXMLConfig.SetDeleteValue(Path+'LazDoc/PackageName',FPDocPackageName,'');

  // i18n
  FXMLConfig.SetDeleteValue(Path+'i18n/EnableI18N/Value', EnableI18N, false);
  FXMLConfig.SetDeleteValue(Path+'i18n/EnableI18N/LFM', EnableI18NForLFM, true);
  FXMLConfig.SetDeleteValue(Path+'i18n/OutDir/Value',
     SwitchPathDelims(CreateRelativePath(POOutputDirectory,Directory),
                      fCurStorePathDelim), '');
  SaveStringList(FXMLConfig, FI18NExcludedIdentifiers, Path+'i18n/ExcludedIdentifiers/');
  SaveStringList(FXMLConfig, FI18NExcludedOriginals, Path+'i18n/ExcludedOriginals/');

  // Resources
  ProjResources.WriteToProjectFile(FXMLConfig, Path);
  // save custom data
  SaveStringToStringTree(FXMLConfig,CustomData,Path+'CustomData/');
  // Save the macro values and compiler options
  BuildModes.SaveProjOptsToXMLConfig(FXMLConfig, Path, FSaveSessionInLPI, UseLegacyLists);
  BuildModes.SaveSharedMatrixOptions(Path);
  if FSaveSessionInLPI then
    BuildModes.SaveSessionData(Path);
  // save the Publish Options
  PublishOptions.SaveToXMLConfig(FXMLConfig,Path+'PublishOptions/',fCurStorePathDelim);
  // save the Run and Build parameter options
  if pfCompatibilityMode in Flags then
    RunParameterOptions.LegacySave(FXMLConfig,Path,fCurStorePathDelim);
  RunParameterOptions.Save(FXMLConfig,Path+'RunParams/',fCurStorePathDelim,rpsLPI, UseLegacyLists);
  // save dependencies
  SavePkgDependencyList(FXMLConfig,Path+'RequiredPackages/',
    FFirstRequiredDependency,pddRequires,fCurStorePathDelim,pfCompatibilityMode in FFlags);
  // save units
  SaveUnits(Path,FSaveSessionInLPI);

  FXMLConfig.SetDeleteValue(Path+'Debugger/Backend/Value', DebuggerBackend, '');

  if FSaveSessionInLPI then begin
    // save defines used for custom options
    SaveOtherDefines(Path);
    // save session info
    SaveSessionInfo(Path);
  end;

  // Notifiy hooks
  if Assigned(OnSaveProjectInfo) then begin
    CurFlags:=FProjectWriteFlags;
    if not FSaveSessionInLPI then
      CurFlags:=CurFlags+[pwfSkipSeparateSessionInfo];
    if UseLegacyLists then
      CurFlags:=CurFlags+[pwfCompatibilityMode];
    OnSaveProjectInfo(Self,FXMLConfig,CurFlags);
  end;

  if FXMLConfig.Modified or (not FileExistsCached(FXMLConfig.Filename)) then
  begin
    // backup
    if Assigned(fOnFileBackup) then begin
      if fOnFileBackup(FXMLConfig.Filename)=mrAbort then begin
        debugln(['Error: (lazarus) [TProject.SaveToLPI] backup of "'+FXMLConfig.Filename+'" failed.']);
        exit;
      end;
    end;

    // save lpi to disk
    //debugln(['TProject.WriteProject ',DbgSName(FXMLConfig),' FCfgFilename=',FCfgFilename]);
    FXMLConfig.Flush;
  end;

  if not (pwfIgnoreModified in FProjectWriteFlags) then
    Modified:=false;
  if FSaveSessionInLPI then
    SessionModified:=false;
end;

procedure TProject.SaveToSession;
const
  Path = 'ProjectSession/';
begin
  FFileVersion:=ProjectInfoFileVersion;
  fCurStorePathDelim:=SessionStorePathDelim;
  FXMLConfig.SetDeleteValue(Path+'PathDelim/Value',
                          PathDelimSwitchToDelim[fCurStorePathDelim],'/');
  FXMLConfig.SetValue(Path+'Version/Value',ProjectInfoFileVersion);

  // Save the session build modes
  BuildModes.SaveSessionOptsToXMLConfig(FXMLConfig, Path, True, UseLegacyLists);
  BuildModes.SaveSessionData(Path);
  // save all units
  SaveUnits(Path,true);
  // save defines used for custom options
  SaveOtherDefines(Path);
  // save session info
  SaveSessionInfo(Path);
  // save the Run and Build parameter options
  RunParameterOptions.Save(FXMLConfig,Path+'RunParams/',fCurStorePathDelim,rpsLPS, UseLegacyLists);
  // save history lists
  HistoryLists.SaveToXMLConfig(FXMLConfig,Path+'HistoryLists/', UseLegacyLists);

  // Notifiy hooks
  if Assigned(OnSaveProjectInfo) then
    OnSaveProjectInfo(Self,FXMLConfig,FProjectWriteFlags+[pwfSkipProjectInfo]);
end;

function TProject.DoWrite(Filename: String; IsLpi: Boolean): TModalResult;
var
  Msg: String;
begin
  repeat
    Result := mrOK;
    try
      FXMLConfig := TCodeBufXMLConfig.CreateWithCache(Filename,false);
    except
      on E: Exception do begin
        DebugLn('ERROR: ',E.Message);
        if IsLpi then
          Msg:=lisUnableToWriteTheProjectInfoFileError
        else
          Msg:=lisUnableToWriteTheProjectSessionFileError;
        IDEMessageDialog(lisCodeToolsDefsWriteError,
          Format(Msg, [LineEnding, Filename, LineEnding, E.Message])
          ,mtError,[mbOk]);
        Result:=mrCancel;
        exit;
      end;
    end;
    try
      // Now actually write the data either to LPI file or to session file.
      if IsLpi then
        SaveToLPI
      else
        SaveToSession;
    except
      on E: Exception do begin
        Result:=IDEMessageDialog(lisCodeToolsDefsWriteError,
          Format(lisUnableToWriteToFile2, [Filename]), mtError,[mbRetry,mbAbort]);
      end;
    end;
    if IsLpi and (CompareFilenames(ProjectInfoFile,FXMLConfig.Filename)=0) then
      UpdateFileBuffer;
    try
      FXMLConfig.Free;
    except
    end;
    FXMLConfig:=nil;
  until Result<>mrRetry;
end;

function TProject.GetDirectory: string;
begin
  Result:=fProjectDirectory;
end;

// Method WriteProject itself
function TProject.WriteProject(ProjectWriteFlags: TProjectWriteFlags;
  const OverrideProjectInfoFile: string;
  GlobalMatrixOptions: TBuildMatrixOptions): TModalResult;
var
  CfgFilename: String;
  SessFilename: String; // only set if session should be saved to a separate file
  SessionResult: TModalResult;
  WriteLPI, WriteLPS: Boolean;
begin
  Result := mrCancel;
  fCurStorePathDelim:=StorePathDelim;

  if OverrideProjectInfoFile<>'' then
    CfgFilename := OverrideProjectInfoFile
  else
    CfgFilename := ProjectInfoFile;
  CfgFilename:=SetDirSeparators(CfgFilename);

  SessFilename := '';
  if (not (pwfSkipSeparateSessionInfo in ProjectWriteFlags))
  and (SessionStorage in pssHasSeparateSession) then begin
    // save session in separate file .lps
    if OverrideProjectInfoFile<>'' then
      SessFilename := ChangeFileExt(OverrideProjectInfoFile,'.lps')
    else
      SessFilename := ProjectSessionFile;
    if (CompareFilenames(SessFilename,CfgFilename)=0) then
      SessFilename:='';
  end;
  //DebugLn('TProject.WriteProject Write Session File="',SessFilename,'"');
  DoDirSeparators(SessFilename);

  FProjectWriteFlags := ProjectWriteFlags;
  BuildModes.FGlobalMatrixOptions := GlobalMatrixOptions;
  // first save the .lpi file
  if (pwfSkipSeparateSessionInfo in ProjectWriteFlags) or (SessionStorage=pssNone) then
    FSaveSessionInLPI:=false
  else
    FSaveSessionInLPI:=(SessFilename='') or (CompareFilenames(SessFilename,CfgFilename)=0);

  // check if modified
  if pwfIgnoreModified in ProjectWriteFlags then
  begin
    WriteLPI:=true;
    WriteLPS:=true;
  end
  else begin
    WriteLPI:=SomeDataModified or (not FileExistsUTF8(CfgFilename));
    if (CompareFilenames(ProjectInfoFile,CfgFilename)=0) then
      // save to default lpi
      WriteLPI:=WriteLPI or (fProjectInfoFileDate<>FileAgeCached(CfgFilename))
    else
      // save to another file
      WriteLPI:=true;
    if SessFilename='' then begin
      WriteLPS:=false;
      WriteLPI:=WriteLPI or SomeSessionModified;
    end else begin
      WriteLPS:=WriteLPI or SomeSessionModified or (not FileExistsUTF8(SessFilename));
    end;
    //debugln(['TProject.WriteProject WriteLPI=',WriteLPI,' WriteLPS=',WriteLPS]);
    if not (WriteLPI or WriteLPS) then exit(mrOk);
  end;
  //debugln(['TProject.WriteProject WriteLPI=',WriteLPI,' WriteLPS=',WriteLPS,' Modified=',Modified,' SessionModified=',SessionModified]);

  // increase usage counters
  UpdateUsageCounts(CfgFilename);
  if WriteLPI then
    // Write to LPI
    Result:=DoWrite(CfgFilename, True);

  if (SessFilename<>'') and WriteLPS then begin
    // save session in separate file .lps
    if Assigned(fOnFileBackup) then begin
      Result:=fOnFileBackup(SessFilename);
      if Result=mrAbort then exit;
    end;
    SessionResult:=DoWrite(SessFilename, False);
    if (Result=mrOk) and (SessionResult<>mrOk) then
      Result:=SessionResult;
  end;
end;

procedure TProject.UpdateExecutableType;

  function GetMainSourceType: string;
  var
    AnUnitInfo: TUnitInfo;
  begin
    Result:='';
    if MainUnitID<0 then exit;
    AnUnitInfo:=Units[MainUnitID];
    if AnUnitInfo.Source=nil then exit;
    Result:=CodeToolBoss.GetSourceType(AnUnitInfo.Source,false);
  end;

var
  SourceType: String;
begin
  SourceType:=GetMainSourceType;
  if SysUtils.CompareText(SourceType,'Program')=0 then
    ExecutableType:=petProgram
  else if SysUtils.CompareText(SourceType,'Library')=0 then
    ExecutableType:=petLibrary
  else if SysUtils.CompareText(SourceType,'Unit')=0 then
    ExecutableType:=petUnit
  else if SysUtils.CompareText(SourceType,'Package')=0 then
    ExecutableType:=petPackage
  else
    ExecutableType:=petNone;
end;

procedure TProject.BackupSession;
begin
  FSessionModifiedBackup:=SessionModified;
end;

procedure TProject.RestoreSession;
begin
  SessionModified:=FSessionModifiedBackup;
end;

procedure TProject.BackupBuildModes;
begin
  FActiveBuildModeBackup:=BuildModes.IndexOf(ActiveBuildMode);
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.BackupBuildModes START=====================']);
  {$ENDIF}
  FBuildModesBackup.Assign(BuildModes,true);
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.BackupBuildModes END===================== Modified=',Modified]);
  {$ENDIF}
end;

procedure TProject.RestoreBuildModes;
begin
  Assert(FBuildModesBackup.Count>0, 'TProject.RestoreBuildModes: FBuildModesBackup.Count=0');
  ActiveBuildMode:=nil;
  BuildModes.Assign(FBuildModesBackup,true);
  if (FActiveBuildModeBackup>=0) and (FActiveBuildModeBackup<BuildModes.Count)
  then
    ActiveBuildMode:=BuildModes[FActiveBuildModeBackup]
  else
    ActiveBuildMode:=BuildModes[0];
end;

function TProject.GetTitle: string;
begin
  Result:=Title;
  if not MacroEngine.SubstituteStr(Result) then
    debugln(['TProject.GetTitle failed Title="',Title,'"']);
end;

function TProject.TitleIsDefault(Fuzzy: boolean): boolean;
var
  t: String;
  p: Integer;
begin
  Result:=true;
  t:=Title;
  if (t='') or (t=GetDefaultTitle) then exit;
  if Fuzzy and (SysUtils.CompareText(t,GetDefaultTitle)=0) then exit;
  // check for project+number
  p:=length(t);
  while (p>0) and (t[p] in ['0'..'9']) do dec(p);
  if SysUtils.CompareText(copy(t,1,p),'project')=0 then exit;
  Result:=false;
end;

function TProject.GetIDAsString: string;
begin
  Result:='Project'; // TODO: see TLazPackage, when this is changed change also TProjectDefineTemplates.UpdateSrcDirIfDef
end;

function TProject.GetIDAsWord: string;
begin
  Result:='Project'; // TODO: see TLazPackage when this is changed change also TProjectDefineTemplates.UpdateSrcDirIfDef
end;

{------------------------------------------------------------------------------
  TProject AddFile
 ------------------------------------------------------------------------------}
procedure TProject.AddFile(ProjectFile: TLazProjectFile; AddToProjectUsesClause: boolean);
var
  NewIndex: integer;
  AnUnit: TUnitInfo;
  s: String;
begin
  AnUnit:=ProjectFile as TUnitInfo;
  //debugln('TProject.AddFile A ',AnUnit.Filename,' AddToProjectFile=',dbgs(AddToProjectFile));
  if (UnitInfoWithFilename(AnUnit.Filename)<>nil) and (AnUnit.FileName <> '') then
    debugln(['TProject.AddFile WARNING: file already in unit list: ',AnUnit.Filename]);
  BeginUpdate(true);
  NewIndex:=UnitCount;
  FUnitList.Add(AnUnit);
  AnUnit.Project:=Self;
  AnUnit.OnFileBackup:=@FileBackupHandler;
  AnUnit.OnLoadSaveFilename:=@LoadSaveFilenameHandler;
  AnUnit.OnUnitNameChange:=@UnitNameChangeHandler;

  // lock the main unit (when it is changed on disk it must *not* auto revert)
  if MainUnitID=NewIndex then
    MainUnitInfo.IncreaseAutoRevertLock;

  if AddToProjectUsesClause and (MainUnitID>=0) and (MainUnitID<>NewIndex) then
  begin
    s:=AnUnit.GetUsesUnitName;
    if s<>'' then // add unit to uses section
      CodeToolBoss.AddUnitToMainUsesSectionIfNeeded(MainUnitInfo.Source,s,'',[aufLast]);
  end;
  EndUpdate;
  UnitModified(AnUnit);
end;

{------------------------------------------------------------------------------
  TProject RemoveUnit
 ------------------------------------------------------------------------------}
procedure TProject.RemoveUnit(Index: integer; RemoveFromUsesSection: boolean);
var
  OldUnitInfo: TUnitInfo;
begin
  if (Index<0) or (Index>=UnitCount) then begin
    raise Exception.Create('ERROR: TProject.RemoveUnit index out of bounds');
  end;
  if (Index=MainUnitID) then begin
    raise Exception.Create('ERROR: TProject.RemoveUnit index = MainUnit');
  end;

  BeginUpdate(true);
  OldUnitInfo:=Units[Index];
  UnitModified(OldUnitInfo);

  if (MainUnitID>=0) then begin
    // remove unit from uses section and from createforms in program file
    if (OldUnitInfo.IsPartOfProject) then begin
      if RemoveFromUsesSection then begin
        if (OldUnitInfo.Unit_Name<>'') then begin
          CodeToolBoss.RemoveUnitFromAllUsesSections(MainUnitInfo.Source,
            OldUnitInfo.Unit_Name);
        end;
        if (OldUnitInfo.ComponentName<>'') then begin
          CodeToolBoss.RemoveCreateFormStatement(MainUnitInfo.Source,
            OldUnitInfo.ComponentName);
        end;
      end;
    end;
  end;

  // delete bookmarks of this unit
  Bookmarks.DeleteAllWithUnitInfo(OldUnitInfo);

  // adjust MainUnit
  if MainUnitID>=Index then dec(fMainUnitID);

  // delete unitinfo instance
  OldUnitInfo.Free;
  FUnitList.Delete(Index);
  EndUpdate;
end;

function TProject.CreateProjectFile(const Filename: string): TLazProjectFile;
var
  NewBuf: TCodeBuffer;
  AnUnitInfo: TUnitInfo;
begin
  NewBuf:=CodeToolBoss.CreateFile(Filename);
  AnUnitInfo:=TUnitInfo.Create(NewBuf);
  if IDEEditorOptions<>nil then
    AnUnitInfo.DefaultSyntaxHighlighter := FilenameToLazSyntaxHighlighter(NewBuf.Filename);
  Result:=AnUnitInfo;
end;

function TProject.GetAndUpdateVisibleUnit(AnEditor: TSourceEditorInterface;
  AWindowID: Integer): TUnitInfo;
var
  i: Integer;
  AnEditorInfo: TUnitEditorInfo;
begin
  for i := 0 to AllEditorsInfoCount - 1 do
    with AllEditorsInfo[i] do
      IsVisibleTab := (WindowID = AWindowID) and (EditorComponent = AnEditor);
  AnEditorInfo := EditorInfoWithEditorComponent(AnEditor);
  if AnEditorInfo = nil then Exit(nil);
  Result := AnEditorInfo.UnitInfo;
  if Assigned(Result) then
    Result.SetLastUsedEditor(AnEditor);
end;

procedure TProject.UpdateAllVisibleUnits;
var
  i, j: Integer;
  aWndId: LongInt;
  Info: TUnitEditorInfo;
begin
  for i := 0 to AllEditorsInfoCount - 1 do begin
    Info:=AllEditorsInfo[i];
    aWndId:=Info.WindowID;
    j := SourceEditorManagerIntf.IndexOfSourceWindowWithID(aWndId);
    Info.IsVisibleTab := (aWndId>=0) and (j >= 0)
      and (Info.EditorComponent = SourceEditorManagerIntf.SourceWindows[j].ActiveEditor);
  end;
end;

function TProject.RemoveNonExistingFiles(RemoveFromUsesSection: boolean): boolean;
var
  i: Integer;
  AnUnitInfo: TUnitInfo;
begin
  Result:=false;
  i:=UnitCount-1;
  while (i>=0) do begin
    if i<UnitCount then begin
      AnUnitInfo:=Units[i];
      if (not AnUnitInfo.IsVirtual) and (i<>MainUnitID) then begin
        if not FileExistsUTF8(AnUnitInfo.Filename) then begin
          RemoveUnit(i,RemoveFromUsesSection);
          Result:=true;
        end;
      end;
    end;
    dec(i);
  end;
end;

{------------------------------------------------------------------------------
  TProject Clear
 ------------------------------------------------------------------------------}
procedure TProject.Clear;
var i:integer;
begin
  BeginUpdate(true);
  inherited Clear;

  // break and free removed dependencies
  while FFirstRemovedDependency<>nil do
    DeleteRemovedDependency(FFirstRemovedDependency);
  // break and free required dependencies
  while FFirstRequiredDependency<>nil do
    DeleteRequiredDependency(FFirstRequiredDependency);

  // delete files
  for i:=0 to UnitCount-1 do Units[i].Free;
  FUnitList.Clear;
  
  RunParameters.Clear;

  FActiveWindowIndexAtStart := -1;
  FSkipCheckLCLInterfaces:=false;
  FAutoOpenDesignerFormsDisabled := false;
  FEnableI18N:=false;
  FEnableI18NForLFM:=true;
  FI18NExcludedOriginals.Clear;
  FI18NExcludedIdentifiers.Clear;
  FBookmarks.Clear;
  ClearBuildModes;
  FDefineTemplates.Clear;
  FJumpHistory.Clear;
  fMainUnitID := -1;
  fProjectInfoFile := '';
  ProjectSessionFile:='';
  FStateFileDate:=0;
  FStateFlags:=[];
  ClearSourceDirectories;
  UpdateProjectDirectory;
  FPublishOptions.Clear;
  Title := '';

  Modified := false;
  SessionModified := false;
  EndUpdate;
end;

procedure TProject.BeginUpdate(Change: boolean);
begin
  inc(FUpdateLock);
  FDefineTemplates.BeginUpdate;
  FSourceDirectories.BeginUpdate;
  if FUpdateLock=1 then begin
    fChanged:=Change;
    if Assigned(OnBeginUpdate) then OnBeginUpdate(Self);
  end else
    fChanged:=fChanged or Change;
end;

procedure TProject.EndUpdate;
begin
  if FUpdateLock<=0 then RaiseGDBException('TProject.EndUpdate');
  dec(FUpdateLock);
  FSourceDirectories.EndUpdate;
  FDefineTemplates.EndUpdate;
  if FUpdateLock=0 then begin
    if Assigned(OnEndUpdate) then OnEndUpdate(Self,fChanged);
  end;
end;

procedure TProject.UnitModified(AnUnitInfo: TUnitInfo);
begin
  if AnUnitInfo.IsPartOfProject then begin
    {$IFDEF VerboseIDEModified}
    debugln(['TProject.UnitModified ',AnUnitInfo.Filename]);
    {$ENDIF}
    Modified:=true;
  end else
    SessionModified:=true;
end;

function TProject.NeedsDefineTemplates: boolean;
begin
  Result:=not Destroying;
end;

procedure TProject.BeginRevertUnit(AnUnitInfo: TUnitInfo);
begin
  if AnUnitInfo<>nil then
    inc(AnUnitInfo.FRevertLockCount);
  inc(FRevertLockCount);
  if FRevertLockCount=1 then begin
    Include(FStateFlags,lpsfPropertyDependenciesChanged);
    ClearUnitComponentDependencies([ucdtOldProperty,ucdtProperty]);
    LockUnitComponentDependencies;
    UpdateUnitComponentDependencies;
  end;
end;

procedure TProject.EndRevertUnit(AnUnitInfo: TUnitInfo);
begin
  if FRevertLockCount<=0 then
    raise Exception.Create('TProject.EndRevertUnit Project');
  if (AnUnitInfo<>nil) and (AnUnitInfo.FRevertLockCount<=0) then
    raise Exception.Create('TProject.EndRevertUnit Filename='+AnUnitInfo.Filename);
  if AnUnitInfo<>nil then
    dec(AnUnitInfo.FRevertLockCount);
  dec(FRevertLockCount);
  if FRevertLockCount=0 then
    UnlockUnitComponentDependencies;
end;

function TProject.IsReverting(AnUnitInfo: TUnitInfo): boolean;
begin
  if AnUnitInfo=nil then
    Result:=FRevertLockCount>0
  else
    Result:=AnUnitInfo.FRevertLockCount>0;
end;

function TProject.GetUnits(Index:integer):TUnitInfo;
begin
  Result:=TUnitInfo(FUnitList[Index]);
end;

procedure TProject.SetFlags(const AValue: TProjectFlags);
begin
  inherited SetFlags(AValue);
end;

procedure TProject.SetMainUnitID(const AValue: Integer);
begin
  if AValue>=UnitCount then
    RaiseGDBException('');
    
  if MainUnitID=AValue then exit;
  if (MainUnitID>=0) and (MainUnitID<UnitCount) then
    MainUnitInfo.DecreaseAutoRevertLock;
  fMainUnitID:=AValue;
  if (MainUnitID>=0) and (MainUnitID<UnitCount) then
    MainUnitInfo.IncreaseAutoRevertLock;
end;

function TProject.GetFiles(Index: integer): TLazProjectFile;
begin
  Result:=Units[Index];
end;

function TProject.GetModified: boolean;
begin
  Result:=(FChangeStamp<>FChangeStampSaved)
    or ((BuildModes<>nil) and BuildModes.Modified);
end;

procedure TProject.SetModified(const AValue: boolean);
begin
  {$IFDEF VerboseIDEModified}
  if Modified<>AValue then begin
    debugln(['TProject.SetModified ================= ',AValue,' ',FChangeStamp]);
    CTDumpStack;
  end;
  {$ENDIF}
  if fDestroying then exit;
  if AValue then
    IncreaseChangeStamp
  else begin
    FChangeStampSaved:=FChangeStamp;
    PublishOptions.Modified := False;
    ProjResources.Modified := False;
    BuildModes.Modified:=false;
    SessionModified := False;
  end;
end;

procedure TProject.SetSessionModified(const AValue: boolean);
begin
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetSessionModified new Modified=',AValue]);
  {$ENDIF}
  inherited SetSessionModified(AValue);
  if AValue then
    IncreaseSessionChangeStamp;
end;

procedure TProject.SetExecutableType(const AValue: TProjectExecutableType);
begin
  inherited SetExecutableType(AValue);
  case ExecutableType of
  petLibrary: CompilerOptions.ExecutableType:=cetLibrary;
  else        CompilerOptions.ExecutableType:=cetProgram;
  end;
end;

function TProject.GetUseManifest: boolean;
begin
  Result:=ProjResources.XPManifest.UseManifest;
end;

procedure TProject.SetUseManifest(AValue: boolean);
begin
  ProjResources.XPManifest.UseManifest:=AValue;
end;

function TProject.GetCurrentDebuggerBackend: String;
begin
  Result := FDebuggerBackend;
end;

function TProject.UnitCount:integer;
begin
  Result:=FUnitList.Count;
end;

function TProject.GetFileCount: integer;
begin
  Result:=UnitCount;
end;

function TProject.NewUniqueUnitName(const AnUnitName: string):string;

  function ExpandedUnitname(const AnUnitName:string):string;
  begin
    Result:=uppercase(ExtractFileNameOnly(AnUnitName));
  end;

  function UnitNameExists(const AnUnitName:string):boolean;
  var i:integer;
    ExpName:string;
  begin
    Result:=true;
    ExpName:=ExpandedUnitName(AnUnitName);
    if ExtractFileNameOnly(fProjectInfoFile)=ExpName then exit;
    for i:=0 to UnitCount-1 do
      if (Units[i].IsPartOfProject) 
      and (ExpandedUnitName(Units[i].FileName)=ExpName) then
        exit;
    Result:=false;
  end;

var
  u:integer;
  Prefix: string;
begin
  Prefix:=AnUnitName;
  while (Prefix<>'') and (Prefix[length(Prefix)] in ['0'..'9']) do
    Prefix:=copy(Prefix,1,length(Prefix)-1);
  if not IsValidIdent(Prefix) then
    Prefix:='Unit';
  u:=0;
  repeat
    inc(u);
    Result:=Prefix+IntToStr(u);
  until (not UnitNameExists(Result));
end;

function TProject.NewUniqueFilename(const Filename: string): string;
var
  FileNameOnly: String;
  FileExt: String;
  i: Integer;
begin
  FileNameOnly:=ExtractFilenameOnly(Filename);
  while (FileNameOnly<>'')
  and (FileNameOnly[length(FileNameOnly)] in ['0'..'9']) do
    FileNameOnly:=copy(FileNameOnly,1,length(FileNameOnly)-1);
  FileExt:=ExtractFileExt(Filename);
  i:=0;
  repeat
    inc(i);
    Result:=FileNameOnly+IntToStr(i)+FileExt;
  until ProjectUnitWithShortFilename(Result)=nil;
end;

function TProject.AddCreateFormToProjectFile(const AClassName, AName: string): boolean;
begin
  Result:=CodeToolBoss.AddCreateFormStatement(MainUnitInfo.Source,AClassName,AName);
  if Result then
    MainUnitInfo.Modified:=true;
end;

function TProject.RemoveCreateFormFromProjectFile(const AName:string):boolean;
begin
  Result:=CodeToolBoss.RemoveCreateFormStatement(MainUnitInfo.Source,AName);
  if Result then
    MainUnitInfo.Modified:=true;
end;

function TProject.FormIsCreatedInProjectFile(const AClassname,AName:string): boolean;
var p: integer;
begin
  Result:=(CodeToolBoss.FindCreateFormStatement(MainUnitInfo.Source,
                                                1,AClassName,AName,p)=0);
  if p=0 then ;
end;

function TProject.IndexOfUnitWithName(const AnUnitName:string; 
  OnlyProjectUnits:boolean; IgnoreUnit: TUnitInfo):integer;
begin
  if AnUnitName='' then exit(-1);
  Result:=UnitCount-1;
  while (Result>=0) do begin
    if ((OnlyProjectUnits and Units[Result].IsPartOfProject)
    or (not OnlyProjectUnits))
    and (IgnoreUnit<>Units[Result])
    and (Units[Result].Unit_Name<>'')
    then begin
      if (CompareDottedIdentifiers(PChar(Units[Result].Unit_Name),PChar(AnUnitName))=0)
      then
        exit;
    end;
    dec(Result);
  end;
end;

function TProject.IndexOfUnitWithComponent(AComponent: TComponent;
  OnlyProjectUnits:boolean; IgnoreUnit: TUnitInfo):integer;
begin
  Result:=UnitCount-1;
  while (Result>=0) do begin
    if (OnlyProjectUnits and Units[Result].IsPartOfProject) 
    or (not OnlyProjectUnits)
    and (IgnoreUnit<>Units[Result]) then begin
      if Units[Result].Component=AComponent then
        exit;
    end;
    dec(Result);
  end;
end;

function TProject.IndexOfUnitWithComponentName(const AComponentName: string;
  OnlyProjectUnits: boolean; IgnoreUnit: TUnitInfo): integer;
begin
  Result:=UnitCount-1;
  while (Result>=0) do begin
    if ((OnlyProjectUnits and Units[Result].IsPartOfProject)
    or (not OnlyProjectUnits))
    and (IgnoreUnit<>Units[Result]) then begin
      if (CompareText(Units[Result].ComponentName,AComponentName)=0)
      or ((Units[Result].Component<>nil)
        and (CompareText(Units[Result].Component.Name,AComponentName)=0))
      then
        exit;
    end;
    dec(Result);
  end;
end;

function TProject.UnitWithEditorComponent(AEditor: TSourceEditorInterface): TUnitInfo;
var
  AnEditorInfo: TUnitEditorInfo;
begin
  if AEditor = nil then exit(nil);
  AnEditorInfo := EditorInfoWithEditorComponent(AEditor);
  if AnEditorInfo = nil then exit(nil);
  Result := AnEditorInfo.UnitInfo;
end;

function TProject.GetResourceFile(AnUnitInfo: TUnitInfo; Index:integer): TCodeBuffer;
var i, LinkIndex: integer;
begin
  LinkIndex:=-1;
  i:=0;
  Result:=nil;
  while (i<Index) do begin
    inc(i);
    Result:=CodeToolBoss.FindNextResourceFile(AnUnitInfo.Source,LinkIndex);
  end;
end;

procedure TProject.LoadDefaultIcon;
begin
  TProjectIcon(ProjResources[TProjectIcon]).LoadDefaultIcon;
end;

function TProject.GetShortFilename(const Filename: string; UseUp: boolean): string;
var
  BaseDir: String;
  CurPath: String;
begin
  Result:=Filename;
  BaseDir:=AppendPathDelim(Directory);
  if (BaseDir<>'') and FilenameIsAbsolute(BaseDir) and UseUp then
    Result:=CreateRelativePath(Result,BaseDir)
  else begin
    CurPath:=copy(ExtractFilePath(Result),1,length(BaseDir));
    if CompareFilenames(BaseDir,CurPath)=0 then
      delete(Result,1,length(CurPath));
  end;
end;

procedure TProject.ConvertToLPIFilename(var AFilename: string);
begin
  LoadSaveFilenameHandler(AFilename,false);
end;

procedure TProject.ConvertFromLPIFilename(var AFilename: string);
begin
  LoadSaveFilenameHandler(AFilename,true);
end;

function TProject.GetMainResourceFilename(AnUnitInfo: TUnitInfo):string;
var CodeBuf: TCodeBuffer;
begin
  CodeBuf:=GetResourceFile(AnUnitInfo,1);
  if CodeBuf=nil then begin
    if AnUnitInfo.Filename='' then exit('');
    Result:=ChangeFileExt(AnUnitInfo.Filename,ResourceFileExt);
    exit;
  end else
    Result:=CodeBuf.Filename;
end;

function TProject.IsLclApplication: Boolean;
var
  CodeTool: TCodeTool;
  UsesNode: TCodeTreeNode;
begin
  Result := False;
  // LCL dependency must be there.
  if FindDependencyByName('LCL') = Nil then Exit;
  //DebugLn(['IsLclApplication: Found LCL dependency.']);
  try
    // Check is uses section has "Forms" unit.
    if not CodeToolBoss.InitCurCodeTool(MainUnitInfo.Source) then Exit;
    CodeTool := CodeToolBoss.CurCodeTool;
    CodeTool.BuildTree(lsrMainUsesSectionEnd);
    UsesNode := CodeTool.FindMainUsesNode;
    if UsesNode = Nil then Exit;
    //DebugLn(['IsLclApplication: Found "uses" node.']);
    if CodeTool.FindNameInUsesSection(UsesNode, 'forms') = Nil then Exit;
    //DebugLn(['IsLclApplication: Found "Forms" unit.']);
    Result := True;
  except
    DebugLn(['IsLclApplication: Codetools could not parse the source.']);
  end;
end;

function TProject.IsVirtual: boolean;
begin
  Result:=((MainUnitID>=0) and MainUnitInfo.IsVirtual)
          or (ProjectInfoFile='') or (not FilenameIsAbsolute(ProjectInfoFile));
end;

function TProject.IndexOf(AUnitInfo: TUnitInfo):integer;
begin
  Result:=UnitCount-1;
  while (Result>=0) and (Units[Result]<>AUnitInfo) do dec(Result);
end;

procedure TProject.AddToOrRemoveFromComponentList(AnUnitInfo: TUnitInfo);
begin
  if AnUnitInfo.Component=nil then begin
    RemoveFromList(AnUnitInfo,uilWithComponent);
  end else begin
    AddToList(AnUnitInfo,uilWithComponent);
  end;
end;

procedure TProject.AddToOrRemoveFromLoadedList(AnUnitInfo: TUnitInfo);
begin
  if not AnUnitInfo.Loaded then begin
    RemoveFromList(AnUnitInfo,uilLoaded);
  end else begin
    AddToList(AnUnitInfo,uilLoaded);
  end;
end;

procedure TProject.AddToOrRemoveFromAutoRevertLockedList(AnUnitInfo: TUnitInfo);
begin
  if not AnUnitInfo.IsAutoRevertLocked then begin
    RemoveFromList(AnUnitInfo,uilAutoRevertLocked);
  end else begin
    AddToList(AnUnitInfo,uilAutoRevertLocked);
  end;
end;

procedure TProject.AddToOrRemoveFromPartOfProjectList(AnUnitInfo: TUnitInfo);
begin
  if not AnUnitInfo.IsPartOfProject then begin
    RemoveFromList(AnUnitInfo,uilPartOfProject);
  end else begin
    AddToList(AnUnitInfo,uilPartOfProject);
  end;
end;

function TProject.GetTargetFilename: string;
begin
  Result:=FLazCompilerOptions.TargetFilename;
end;

procedure TProject.SetTargetFilename(const NewTargetFilename: string);
begin
  FLazCompilerOptions.TargetFilename:=NewTargetFilename;
end;

procedure TProject.SetEnableI18N(const AValue: boolean);
begin
  if FEnableI18N=AValue then exit;
  FEnableI18N:=AValue;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetEnableI18N ',AValue]);
  {$ENDIF}
  Modified:=true;
end;

procedure TProject.SetPOOutputDirectory(const AValue: string);
var
  NewValue: String;
begin
  NewValue:=ChompPathDelim(TrimFilename(AValue));
  if FPOOutputDirectory=NewValue then exit;
  FPOOutputDirectory:=NewValue;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetPOOutputDirectory ',AValue]);
  {$ENDIF}
  Modified:=true;
end;

function TProject.GetMainFilename: String;
begin
  if MainUnitID>=0 then Result:=MainUnitInfo.Filename
  else Result:='';
end;

function TProject.GetFirstPartOfProject: TUnitInfo;
begin
  Result:=FFirst[uilPartOfProject];
end;

function TProject.GetFirstLoadedUnit: TUnitInfo;
begin
  Result:=fFirst[uilLoaded];
end;

procedure TProject.EmbeddedObjectModified(Sender: TObject);
begin
  if ProjResources.Modified then
    Modified := True;
end;

function TProject.GetFirstAutoRevertLockedUnit: TUnitInfo;
begin
  Result:=fFirst[uilAutoRevertLocked];
end;

function TProject.GetAllEditorsInfo(Index: Integer): TUnitEditorInfo;
begin
  Result := FAllEditorsInfoList[Index];
end;

function TProject.GetCompilerOptions: TProjectCompilerOptions;
begin
  Result := TProjectCompilerOptions(FLazCompilerOptions);
end;

function TProject.GetBaseCompilerOptions: TBaseCompilerOptions;
// This satisfies the IProjPack interface requirement.
begin
  Result := TBaseCompilerOptions(FLazCompilerOptions);
end;

procedure TProject.ClearBuildModes;
begin
  ActiveBuildMode:=nil;
  FBuildModes.Clear;
  if not fDestroying then
    ActiveBuildMode:=FBuildModes.Add('default');
end;

function TProject.GetActiveBuildModeID: string;
begin
  Result := ActiveBuildMode.Identifier;
end;

function TProject.GetFirstUnitWithComponent: TUnitInfo;
begin
  Result:=fFirst[uilWithComponent];
end;

function TProject.GetFirstUnitWithEditorIndex: TUnitInfo;
begin
  Result:=fFirst[uilWithEditorIndex];
end;

function TProject.GetIDEOptions: TProjectIDEOptions;
begin
  Result := TProjectIDEOptions(FIDEOptions);
end;

function TProject.GetMainUnitInfo: TUnitInfo;
begin
  if (MainUnitID>=0) and (MainUnitID<UnitCount) then
    Result:=Units[MainUnitID]
  else
    Result:=nil;
end;

function TProject.GetProjResources: TProjectResources;
begin
  Result:=TProjectResources(Resources);
end;

function TProject.GetRunParameterOptions: TRunParamsOptions;
begin
  Result:=TRunParamsOptions(FRunParameters);
end;

function TProject.GetSourceDirectories: TFileReferenceList;
begin
  Result:=FSourceDirectories;
end;

function TProject.GetProjectInfoFile:string;
begin
  Result:=fProjectInfoFile;
end;

procedure TProject.SetProjectInfoFile(const NewFilename:string);
var
  NewProjectInfoFile: String;
  TitleWasDefault: Boolean;
begin
  NewProjectInfoFile:=TrimFilename(NewFilename);
  if NewProjectInfoFile='' then exit;
  ForcePathDelims(NewProjectInfoFile);
  if fProjectInfoFile=NewProjectInfoFile then exit;
  BeginUpdate(true);
  TitleWasDefault:=(Title<>'') and TitleIsDefault(true);
  fProjectInfoFile:=NewProjectInfoFile;
  if TitleWasDefault then
    Title:=GetDefaultTitle;
  UpdateProjectDirectory;
  UpdateSessionFilename;
  if Assigned(OnChangeProjectInfoFile) then
    OnChangeProjectInfoFile(Self);
  FDefineTemplates.SourceDirectoriesChanged;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetProjectInfoFile ',NewFilename]);
  {$ENDIF}
  Modified:=true;
  EndUpdate;
  //DebugLn('TProject.SetProjectInfoFile FDefineTemplates.FUpdateLock=',dbgs(FDefineTemplates.FUpdateLock));
end;

procedure TProject.SetSessionStorage(const AValue: TProjectSessionStorage);
begin
  if SessionStorage=AValue then exit;
  inherited SetSessionStorage(AValue);
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetSessionStorage ']);
  {$ENDIF}
  Modified:=true;
  UpdateSessionFilename;
end;

function TProject.FileBackupHandler(const Filename: string): TModalResult;
begin
  if Assigned(fOnFileBackup) then
    Result:=fOnFileBackup(Filename)
  else
    Result:=mrOk;
end;

procedure TProject.LoadSaveFilenameHandler(var AFilename: string; Load:boolean);
{ This function is used after reading a filename from the config
  and before writing a filename to a config.
  The config can be the lpi or the session.
}
var
  ProjectPath: string;
  FileWasAbsolute: Boolean;
  
  function FileCanBeMadeRelative: boolean;
  begin
    Result:=false;
    if not FileWasAbsolute then exit;
    {$IFdef MSWindows}
    // check that the file is on the same drive / filesystem
    if CompareText(ExtractFileDrive(AFilename),ExtractFileDrive(ProjectPath))<>0
    then exit;
    {$ENDIF}
    Result:=true;
  end;
  
begin
  if AFileName='' then exit;
  //debugln(['TProject.OnLoadSaveFilename A "',AFilename,'" fPathDelimChanged=',fPathDelimChanged,' Load=',Load]);
  if Load and fPathDelimChanged then begin
    {$IFDEF MSWindows}
    // PathDelim changed from '/' to '\'
    FileWasAbsolute:=FilenameIsUnixAbsolute(AFileName);
    {$ELSE}
    // PathDelim changed from '\' to '/'
    FileWasAbsolute:=FilenameIsWinAbsolute(AFileName);
    {$ENDIF}
    ForcePathDelims(AFilename);
  end else begin
    FileWasAbsolute:=FilenameIsAbsolute(AFileName);
  end;
  AFilename:=TrimFilename(AFilename);
  
  ProjectPath:=AppendPathDelim(Directory);
  if ProjectPath<>'' then begin
    if Load then begin
      // make filename absolute
      if not FileWasAbsolute then
        AFilename:=TrimFilename(ProjectPath+AFilename);
    end else begin
      // try making filename relative to project file
      if FileCanBeMadeRelative then begin
        AFilename:=CreateRelativePath(AFilename,ProjectPath);
      end;
    end;
  end;

  if (not Load) then begin
    if (not IsCurrentPathDelim(fCurStorePathDelim))
    and (FilenameIsAbsolute(AFileName))
    and (ProjectPath<>'') then begin
      // the lpi file is saved with different pathdelims
      // this will destroy absolute paths
      // => force it relative
      AFileName:=ExtractRelativepath(ProjectPath,AFilename);
    end;
    AFilename:=SwitchPathDelims(AFileName,fCurStorePathDelim);
  end;
  //debugln('TProject.OnLoadSaveFilename END "',AFilename,'" FileWasAbsolute=',dbgs(FileWasAbsolute));
end;

function TProject.RemoveProjectPathFromFilename(const AFilename: string): string;
var
  ProjectPath:string;
begin
  ProjectPath:=Directory;
  if ProjectPath='' then ProjectPath:=GetCurrentDirUTF8;
  Result:=AFilename;
  ForcePathDelims(Result);
  // try making filename relative to project file
  if FilenameIsAbsolute(Result)
  and (CompareFileNames(copy(Result,1,length(ProjectPath)),ProjectPath)=0) then
    Result:=copy(Result,length(ProjectPath)+1,
         length(Result)-length(ProjectPath));
end;

function TProject.FileIsInProjectDir(const AFilename: string): boolean;
var
  ProjectDir, FilePath: string;
begin
  if FilenameIsAbsolute(AFilename) then
  begin
    if IsVirtual then
      Result:=false
    else begin
      ProjectDir:=Directory;
      FilePath:=LeftStr(AFilename,length(ProjectDir));
      Result:=CompareFileNames(ProjectDir,FilePath)=0;
    end;
  end else
    Result:=true;
end;

procedure TProject.GetVirtualDefines(DefTree: TDefineTree; DirDef: TDirectoryDefines);
  
  procedure ExtendPath(const AVariable, APath: string);
  var
    TempValue: string;
  begin
    if APath<>'' then begin
      DefTree.ReadValue(DirDef,APath+';','',TempValue);
      DirDef.Values.Prepend(AVariable,TempValue);
    end;
  end;
  
begin
  if (not IsVirtual) then exit;
  ExtendPath(NamespacesMacroName,CompilerOptions.Namespaces);
  ExtendPath(UnitPathMacroName,CompilerOptions.OtherUnitFiles);
  ExtendPath(IncludePathMacroName,CompilerOptions.IncludePath);
  ExtendPath(SrcPathMacroName,CompilerOptions.SrcPath);
end;

procedure TProject.GetUnitsChangedOnDisk(var AnUnitList: TFPList;
  IgnoreModifiedFlag: boolean);
var
  AnUnitInfo: TUnitInfo;
begin
  AnUnitList:=nil;
  AnUnitInfo:=fFirst[uilAutoRevertLocked];
  while (AnUnitInfo<>nil) do begin
    if (AnUnitInfo.Source<>nil)
    and AnUnitInfo.ChangedOnDisk(false, IgnoreModifiedFlag) then begin
      if AnUnitList=nil then
        AnUnitList:=TFPList.Create;
      AnUnitList.Add(AnUnitInfo);
    end;
    AnUnitInfo:=AnUnitInfo.fNext[uilAutoRevertLocked];
  end;
end;

function TProject.GetUseLegacyLists: Boolean;
begin
  Result:=pfCompatibilityMode in Flags;
end;

function TProject.HasProjectInfoFileChangedOnDisk: boolean;
var
  AnUnitInfo: TUnitInfo;
  Code: TCodeBuffer;
begin
  Result:=false;
  if IsVirtual or Modified then exit;
  AnUnitInfo:=UnitInfoWithFilename(ProjectInfoFile,[pfsfOnlyEditorFiles]);
  if (AnUnitInfo<>nil) then begin
    // user is editing the lpi file in source editor
    exit;
  end;
  AnUnitInfo:=fFirst[uilAutoRevertLocked];
  while (AnUnitInfo<>nil) do begin
    if CompareFilenames(AnUnitInfo.Filename,ProjectInfoFile)=0 then begin
      // revert is locked for this file
      exit;
    end;
    AnUnitInfo:=AnUnitInfo.fNext[uilAutoRevertLocked];
  end;

  if not FileExistsCached(ProjectInfoFile) then exit;
  if fProjectInfoFileDate=FileAgeCached(ProjectInfoFile) then exit;

  // file on disk has changed, check content
  Code:=CodeToolBoss.LoadFile(ProjectInfoFile,true,true);
  if (Code<>nil) and (Code=fProjectInfoFileBuffer)
    and (Code.ChangeStep=fProjectInfoFileBufChangeStamp)
  then exit;

  //DebugLn(['TProject.HasProjectInfoFileChangedOnDisk ',ProjectInfoFile,' fProjectInfoFileDate=',fProjectInfoFileDate,' ',FileAgeUTF8(ProjectInfoFile)]);
  Result:=true;
end;

procedure TProject.IgnoreProjectInfoFileOnDisk;
begin
  fProjectInfoFileDate:=FileAgeCached(ProjectInfoFile);
end;

function TProject.FindDependencyByName(const PackageName: string): TPkgDependency;
begin
  Result:=FindDependencyByNameInList(FFirstRequiredDependency,pddRequires,
                                     PackageName);
end;

function TProject.FindRemovedDependencyByName(const PkgName: string): TPkgDependency;
begin
  Result:=FindDependencyByNameInList(FFirstRemovedDependency,pddRequires,PkgName);
end;

function TProject.RequiredDepByIndex(Index: integer): TPkgDependency;
begin
  Result:=GetDependencyWithIndex(FFirstRequiredDependency,pddRequires,Index);
end;

function TProject.RemovedDepByIndex(Index: integer): TPkgDependency;
begin
  Result:=GetDependencyWithIndex(FFirstRemovedDependency,pddRequires,Index);
end;

procedure TProject.AddRequiredDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  Dependency.AddToList(FFirstRequiredDependency,pddRequires);
  Dependency.Owner:=Self;
  Dependency.HoldPackage:=true;
  FDefineTemplates.CustomDefinesChanged;
  {$IFDEF VerboseAddProjPkg}
  DebugLn(['TProject.AddRequiredDependency ']);
  {$ENDIF}
  IncreaseCompilerParseStamp;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.AddRequiredDependency ',Dependency.PackageName]);
  {$ENDIF}
  Modified:=true;
  EndUpdate;
end;

procedure TProject.RemoveRequiredDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  Dependency.RemoveFromList(FFirstRequiredDependency,pddRequires);
  Dependency.RequiredPackage:=nil;
  Dependency.AddToList(FFirstRemovedDependency,pddRequires);
  Dependency.Removed:=true;
  FDefineTemplates.CustomDefinesChanged;
  IncreaseCompilerParseStamp;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.RemoveRequiredDependency ',Dependency.PackageName]);
  {$ENDIF}
  Modified:=true;
  EndUpdate;
end;

procedure TProject.DeleteRequiredDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  Dependency.RequiredPackage:=nil;
  Dependency.RemoveFromList(FFirstRequiredDependency,pddRequires);
  Dependency.Free;
  FDefineTemplates.CustomDefinesChanged;
  IncreaseCompilerParseStamp;
  EndUpdate;
end;

procedure TProject.DeleteRemovedDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  Dependency.RequiredPackage:=nil;
  Dependency.RemoveFromList(FFirstRemovedDependency,pddRequires);
  Dependency.Free;
  EndUpdate;
end;

procedure TProject.RemoveRemovedDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  Dependency.RemoveFromList(FFirstRemovedDependency,pddRequires);
  Dependency.Removed:=false;
  EndUpdate;
end;

procedure TProject.ReaddRemovedDependency(Dependency: TPkgDependency);
begin
  BeginUpdate(true);
  RemoveRemovedDependency(Dependency);
  AddRequiredDependency(Dependency);
  EndUpdate;
end;

procedure TProject.MoveRequiredDependencyUp(Dependency: TPkgDependency);
begin
  if Dependency.PrevRequiresDependency=nil then exit;
  BeginUpdate(true);
  Dependency.MoveUpInList(FFirstRequiredDependency,pddRequires);
  FDefineTemplates.CustomDefinesChanged;
  IncreaseCompilerParseStamp;
  EndUpdate;
end;

procedure TProject.MoveRequiredDependencyDown(Dependency: TPkgDependency);
begin
  if Dependency.NextRequiresDependency=nil then exit;
  BeginUpdate(true);
  Dependency.MoveDownInList(FFirstRequiredDependency,pddRequires);
  FDefineTemplates.CustomDefinesChanged;
  IncreaseCompilerParseStamp;
  EndUpdate;
end;

function TProject.Requires(APackage: TLazPackage; SearchRecursively: boolean): boolean;
begin
  if SearchRecursively then
    Result:=PackageGraph.FindDependencyRecursively(FFirstRequiredDependency,
                                                   APackage)<>nil
  else
    Result:=FindCompatibleDependencyInList(FFirstRequiredDependency,pddRequires,
                                           APackage)<>nil;
end;

procedure TProject.GetAllRequiredPackages(var List: TFPList;
  ReqFlags: TPkgIntfRequiredFlags; MinPolicy: TPackageUpdatePolicy);
var
  FPMakeList: TFPList;
begin
  if Assigned(OnGetAllRequiredPackages) then begin
    OnGetAllRequiredPackages(nil,FirstRequiredDependency,List,FPMakeList,ReqFlags,MinPolicy);
    FPMakeList.Free;
  end;
end;

procedure TProject.AddPackageDependency(const PackageName: string);
var
  PkgDependency: TPkgDependency;
begin
  if FindDependencyByNameInList(FirstRequiredDependency,pddRequires,PackageName)
  <>nil then exit;
  PkgDependency:=TPkgDependency.Create;
  PkgDependency.DependencyType:=pdtLazarus;
  PkgDependency.PackageName:=PackageName;
  AddRequiredDependency(PkgDependency);
end;

function TProject.RemovePackageDependency(const PackageName: string): boolean;
var
  PkgDependency: TPkgDependency;
begin
  PkgDependency:=FindDependencyByNameInList(FirstRequiredDependency,pddRequires,PackageName);
  Result := Assigned(PkgDependency);
  if Result then
    RemoveRequiredDependency(PkgDependency);
end;

procedure TProject.LockUnitComponentDependencies;
begin
  inc(FLockUnitComponentDependencies);
  if FLockUnitComponentDependencies=1 then begin
    // update once
    Include(FStateFlags,lpsfPropertyDependenciesChanged);
    Include(FStateFlags,lpsfDesignerChanged);
  end;
end;

procedure TProject.UnlockUnitComponentDependencies;
begin
  if FLockUnitComponentDependencies=0 then
    raise Exception.Create('');
  dec(FLockUnitComponentDependencies);
end;

procedure TProject.UpdateUnitComponentDependencies;

  procedure Search(AnUnitInfo: TUnitInfo; AComponent: TComponent);
  // search the published properties of AComponent for references to other units
  var
    TypeInfo: PTypeInfo;
    TypeData: PTypeData;
    PropInfo: PPropInfo;
    PropList: PPropList;
    CurCount,i: integer;
    ReferenceComp: TObject;
    OwnerComponent: TComponent;
    ReferenceUnit: TUnitInfo;
    Dependency: TUnitComponentDependency;
  begin
    if AComponent<>AnUnitInfo.Component then begin
      ReferenceUnit:=UnitWithComponentClass(TComponentClass(AComponent.ClassType));
      {$ifdef VerboseFormEditor}
      DebugLn(['Search UnitComponent=',DbgSName(AnUnitInfo.Component),' AComponent=',DbgSName(AComponent),' ReferenceUnit=',ReferenceUnit<>nil]);
      {$endif}
      if (ReferenceUnit<>nil) then begin
        // component class references another unit
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['TProject.UpdateUnitComponentDependencies inline component found: ',DbgSName(AComponent),' ',AnUnitInfo.Filename,' -> ',ReferenceUnit.Filename]);
        {$ENDIF}
        AnUnitInfo.AddRequiresComponentDependency(
                             ReferenceUnit,[ucdtInlineClass]);
      end;
    end;
  
    // read all properties and remove doubles
    TypeInfo:=PTypeInfo(AComponent.ClassInfo);
    repeat
      // read all property infos of current class
      TypeData:=GetTypeData(TypeInfo);
      // read property count
      CurCount:=GetPropList(TypeInfo,PropList);
      try
         // read properties
        for i:=0 to CurCount-1 do begin
          PropInfo:=PropList^[i];
          if (PropInfo^.PropType^.Kind=tkClass) then begin
            // property of kind TObject
            ReferenceComp:=GetObjectProp(AComponent,PropInfo);
            //debugln('TProject.UpdateUnitComponentDependencies Property ',dbgsName(AComponent),' Name=',PropInfo^.Name,' Type=',PropInfo^.PropType^.Name,' Value=',dbgsName(ReferenceComp),' TypeInfo=',TypeInfo^.Name);
            if ReferenceComp is TComponent then begin
              // reference is a TComponent
              OwnerComponent:=TComponent(ReferenceComp);
              while OwnerComponent.Owner<>nil do
                OwnerComponent:=OwnerComponent.Owner;
              if OwnerComponent<>AnUnitInfo.Component then begin
                // property references a component that is not owned
                // by the current unit
                ReferenceUnit:=UnitWithComponent(OwnerComponent);
                if ReferenceUnit<>nil then begin
                  // property references another unit
                  {$IFDEF VerboseIDEMultiForm}
                  DebugLn(['TProject.UpdateUnitComponentDependencies multi form reference found: ',AnUnitInfo.Filename,' -> ',ReferenceUnit.Filename]);
                  {$ENDIF}
                  AnUnitInfo.AddRequiresComponentDependency(
                                       ReferenceUnit,[ucdtProperty]);
                  if FRevertLockCount>0 then begin
                    Dependency:=AnUnitInfo.AddRequiresComponentDependency(
                                         ReferenceUnit,[ucdtOldProperty]);
                    Dependency.SetUsedByPropPath(
                      Dependency.CreatePropPath(AComponent,PropInfo^.Name),
                      Dependency.CreatePropPath(TComponent(ReferenceComp)));
                  end;
                end;
              end;
            end;
          end;
        end;
      finally
        FreeMem(PropList);
      end;
      TypeInfo:=TypeData^.ParentInfo;
    until TypeInfo=nil;
  end;
  
  procedure DFSRequiredDesigner(AnUnitInfo, IgnoreUnitInfo: TUnitInfo);
  var
    Dependency: TUnitComponentDependency;
    UsingUnitInfo: TUnitInfo;
  begin
    if (AnUnitInfo=nil) or (AnUnitInfo.Component=nil)
    or (uifMarked in AnUnitInfo.FFlags) then
      exit;
    Include(AnUnitInfo.FFlags,uifMarked);
    Dependency:=AnUnitInfo.FirstRequiredComponent;
    while Dependency<>nil do begin
      UsingUnitInfo:=Dependency.RequiresUnit;
      if (UsingUnitInfo<>IgnoreUnitInfo)
      and (not (uifComponentIndirectlyUsedByDesigner in UsingUnitInfo.FFlags))
      then begin
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['TProject.UpdateUnitComponentDependencies.DFSRequiredDesigner designer of ',AnUnitInfo.Filename,' uses ',UsingUnitInfo.Filename]);
        {$ENDIF}
        Include(UsingUnitInfo.FFlags,uifComponentIndirectlyUsedByDesigner);
        DFSRequiredDesigner(UsingUnitInfo,IgnoreUnitInfo);
      end;
      Dependency:=Dependency.NextRequiresDependency;
    end;
  end;

var
  AnUnitInfo: TUnitInfo;
  i: Integer;
begin
  if (FLockUnitComponentDependencies=0)
  or (lpsfPropertyDependenciesChanged in FStateFlags) then begin
    Exclude(FStateFlags,lpsfPropertyDependenciesChanged);
    // clear dependencies
    ClearUnitComponentDependencies([ucdtProperty,ucdtInlineClass]);
    {$IFDEF VerboseIDEMultiForm}
    DebugLn(['TProject.UpdateUnitComponentDependencies checking properties ...']);
    {$ENDIF}
    // find property dependencies
    AnUnitInfo:=FirstUnitWithComponent;
    while AnUnitInfo<>nil do begin
      Search(AnUnitInfo,AnUnitInfo.Component);
      for i:=AnUnitInfo.Component.ComponentCount-1 downto 0 do
        Search(AnUnitInfo,AnUnitInfo.Component.Components[i]);
      AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
    end;
    //WriteDebugReportUnitComponentDependencies('P ');
  end;
  
  if (FLockUnitComponentDependencies=0)
  or (lpsfDesignerChanged in FStateFlags) then begin
    Exclude(FStateFlags,lpsfDesignerChanged);
    {$IFDEF VerboseIDEMultiForm}
    DebugLn(['TProject.UpdateUnitComponentDependencies checking designers ...']);
    {$ENDIF}
    // find designer dependencies
    AnUnitInfo:=FirstUnitWithComponent;
    while AnUnitInfo<>nil do begin
      AnUnitInfo.FFlags:=AnUnitInfo.FFlags-
        [uifMarked,uifComponentIndirectlyUsedByDesigner,uifComponentUsedByDesigner];
      if FindRootDesigner(AnUnitInfo.Component)<>nil then begin
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['TProject.UpdateUnitComponentDependencies used by designer: ',AnUnitInfo.Filename]);
        {$ENDIF}
        Include(AnUnitInfo.FFlags,uifComponentUsedByDesigner);
      end;
      AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
    end;
    // mark all units that are used indirectly by a designer
    AnUnitInfo:=FirstUnitWithComponent;
    while AnUnitInfo<>nil do begin
      if (uifComponentUsedByDesigner in AnUnitInfo.FFlags) then
      begin
        // mark all that use indirectly this designer
        Exclude(AnUnitInfo.FFlags,uifMarked);
        DFSRequiredDesigner(AnUnitInfo,AnUnitInfo);
      end;
      AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
    end;
    {$IFDEF VerboseTFrame}
    WriteDebugReportUnitComponentDependencies('UUCD ');
    {$ENDIF}
  end;
end;

procedure TProject.InvalidateUnitComponentDesignerDependencies;
begin
  Include(FStateFlags,lpsfDesignerChanged);
end;

procedure TProject.ClearUnitComponentDependencies(ClearTypes: TUnitCompDependencyTypes);
var
  i: Integer;
begin
  for i:=UnitCount-1 downto 0 do
    Units[i].ClearUnitComponentDependencies(ClearTypes);
end;

procedure TProject.FindUnitsUsingSubComponent(SubComponent: TComponent;
  List: TFPList; IgnoreOwner: boolean);

  procedure Search(AnUnitInfo: TUnitInfo; AComponent: TComponent);
  // search the published properties of AComponent for references to other units
  var
    TypeInfo: PTypeInfo;
    TypeData: PTypeData;
    PropInfo: PPropInfo;
    PropList: PPropList;
    CurCount,i: integer;
    ReferenceComponent: TComponent;
  begin
    if csDestroying in AComponent.ComponentState then exit;

    // read all properties and remove doubles
    TypeInfo:=PTypeInfo(AComponent.ClassInfo);
    repeat
      // read all property infos of current class
      TypeData:=GetTypeData(TypeInfo);
      // read property count
      CurCount:=GetPropList(TypeInfo,PropList);
      try
         // read properties
        for i:=0 to CurCount-1 do begin
          PropInfo:=PropList^[i];
          if PropInfo^.PropType^.Kind=tkClass then begin
            // property of kind TObject
            ReferenceComponent:=TComponent(GetObjectProp(AComponent,PropInfo));
            //debugln('TProject.FindUnitsUsingSubComponent Property ',dbgsName(AComponent),' Name=',PropInfo^.Name,' Type=',PropInfo^.PropType^.Name,' Value=',dbgsName(ReferenceComponent),' TypeInfo=',TypeInfo^.Name);
            if ReferenceComponent=SubComponent then begin
              if List.IndexOf(AnUnitInfo)<0 then
                List.Add(AnUnitInfo);
            end;
          end;
        end;
      finally
        FreeMem(PropList);
      end;
      TypeInfo:=TypeData^.ParentInfo;
    until TypeInfo=nil;
  end;

var
  AnUnitInfo: TUnitInfo;
  i: Integer;
  OwnerComponent: TComponent;
begin
  if SubComponent=nil then exit;
  if IgnoreOwner then begin
    OwnerComponent:=SubComponent;
    while OwnerComponent<>nil do
      OwnerComponent:=OwnerComponent.Owner;
  end else
    OwnerComponent:=nil;
  AnUnitInfo:=FirstUnitWithComponent;
  while AnUnitInfo<>nil do begin
    if csDestroying in AnUnitInfo.Component.ComponentState then continue;
    if AnUnitInfo.Component<>OwnerComponent then begin
      Search(AnUnitInfo,AnUnitInfo.Component);
      for i:=AnUnitInfo.Component.ComponentCount-1 downto 0 do
        Search(AnUnitInfo,AnUnitInfo.Component.Components[i]);
    end;
    AnUnitInfo:=AnUnitInfo.NextUnitWithComponent;
  end;
end;

procedure TProject.WriteDebugReportUnitComponentDependencies(Prefix: string);
var
  i: Integer;
  AnUnitInfo: TUnitInfo;
begin
  for i:=0 to UnitCount-1 do begin
    AnUnitInfo:=Units[i];
    if (AnUnitInfo.FirstUsedByComponent<>nil)
    or (AnUnitInfo.FirstRequiredComponent<>nil) then
      AnUnitInfo.WriteDebugReportUnitComponentDependencies(Prefix);
  end;
end;

procedure TProject.AddSrcPath(const SrcPathAddition: string);
begin
  CompilerOptions.MergeToSrcPath( GetForcedPathDelims(SrcPathAddition) );
end;

function TProject.GetSourceDirs(WithProjectDir, WithoutOutputDir: boolean): string;
begin
  Result:=SourceDirectories.CreateSearchPathFromAllFiles;
  if WithProjectDir then
    Result:=MergeSearchPaths(Result,Directory);
  if WithoutOutputDir then
    Result:=RemoveSearchPaths(Result,GetOutputDirectory);
end;

function TProject.GetOutputDirectory: string;
begin
  Result:=CompilerOptions.ParsedOpts.GetParsedValue(pcosOutputDir);
end;

function TProject.GetCompilerFilename: string;
begin
  Result:=CompilerOptions.ParsedOpts.GetParsedValue(pcosCompilerPath);
end;

function TProject.GetStateFilename: string;
begin
  Result:=GetOutputDirectory;
  if (not FilenameIsAbsolute(Result)) and (not IsVirtual) then
    Result:=Directory;
  Result:=AppendPathDelim(Result)+ChangeFileExt(GetCompileSourceFilename,'.compiled');
end;

function TProject.GetCompileSourceFilename: string;
begin
  if MainUnitID<0 then
    Result:=''
  else
    Result:=ExtractFilename(MainUnitInfo.Filename);
end;

procedure TProject.AutoAddOutputDirToIncPath;
begin
  if pfLRSFilesInOutputDirectory in Flags then begin
    // the .lrs files are auto created in the output directory
    // => make sure the project output directory is in the include path
    if SearchDirectoryInSearchPath(CompilerOptions.IncludePath,'$(ProjOutDir)')<1 then
      CompilerOptions.MergeToIncludePaths(';$(ProjOutDir)');
  end;
end;

function TProject.ExtendUnitSearchPath(NewUnitPaths: string): boolean;
var
  CurUnitPaths: String;
  r: TModalResult;
begin
  CurUnitPaths:=CompilerOptions.ParsedOpts.GetParsedValue(pcosUnitPath);
  NewUnitPaths:=RemoveSearchPaths(NewUnitPaths,CurUnitPaths);
  if NewUnitPaths<>'' then begin
    NewUnitPaths:=CreateRelativeSearchPath(NewUnitPaths,Directory);
    r:=IDEMessageDialog(lisExtendUnitPath,
      Format(lisExtendUnitSearchPathOfProjectWith, [#13, NewUnitPaths]),
      mtConfirmation, [mbYes, mbNo, mbCancel]);
    case r of
    mrYes: CompilerOptions.MergeToUnitPaths(NewUnitPaths);
    mrNo: ;
    else exit(false);
    end;
  end;
  Result:=true;
end;

function TProject.ExtendIncSearchPath(NewIncPaths: string): boolean;
var
  CurIncPaths: String;
  r: TModalResult;
begin
  CurIncPaths:=CompilerOptions.ParsedOpts.GetParsedValue(pcosIncludePath);
  NewIncPaths:=RemoveSearchPaths(NewIncPaths,CurIncPaths);
  if NewIncPaths<>'' then begin
    NewIncPaths:=CreateRelativeSearchPath(NewIncPaths,Directory);
    r:=IDEMessageDialog(lisExtendIncludePath,
      Format(lisExtendIncludeFilesSearchPathOfProjectWith, [#13, NewIncPaths]),
      mtConfirmation, [mbYes, mbNo, mbCancel]);
    case r of
    mrYes: CompilerOptions.MergeToIncludePaths(NewIncPaths);
    mrNo: ;
    else exit(false);
    end;
  end;
  Result:=true;
end;

function TProject.LoadStateFile(IgnoreErrors: boolean): TModalResult;
var
  XMLConfig: TXMLConfig;
  StateFile: String;
  CurStateFileAge: Integer;
begin
  StateFile:=GetStateFilename;
  if (not FilenameIsAbsolute(StateFile)) or (not FileExistsUTF8(StateFile)) then
  begin
    DebugLn('TProject.DoLoadStateFile Statefile not found: ',StateFile);
    StateFlags:=StateFlags-[lpsfStateFileLoaded];
    Result:=mrOk;
    exit;
  end;

  // read the state file
  CurStateFileAge:=FileAgeCached(StateFile);
  if (not (lpsfStateFileLoaded in StateFlags))
  or (StateFileDate<>CurStateFileAge) then
  begin
    StateFlags:=StateFlags-[lpsfStateFileLoaded];
    try
      XMLConfig:=TCodeBufXMLConfig.CreateWithCache(StateFile);
      try
        LastCompilerFilename:=XMLConfig.GetValue('Compiler/Value','');
        LastCompilerFileDate:=XMLConfig.GetValue('Compiler/Date',0);
        LastCompilerParams:=XMLConfig.GetValue('Params/Value','');
        LastCompileComplete:=XMLConfig.GetValue('Complete/Value',true);
      finally
        XMLConfig.Free;
      end;
      StateFileDate:=CurStateFileAge;
    except
      on E: Exception do begin
        if IgnoreErrors then begin
          Result:=mrOk;
        end else begin
          Result:=IDEMessageDialog(lisPkgMangErrorReadingFile,
            Format(lisProjMangUnableToReadStateFileOfProjectError,
                   [StateFile, IDAsString, LineEnding, E.Message]),
            mtError,[mbAbort]);
        end;
        exit;
      end;
    end;
    StateFlags:=StateFlags+[lpsfStateFileLoaded];
  end;

  Result:=mrOk;
end;

function TProject.SaveStateFile(const CompilerFilename, CompilerParams: string;
  Complete: boolean): TModalResult;
var
  XMLConfig: TXMLConfig;
  StateFile: String;
  CompilerFileDate: Integer;
begin
  StateFile:=GetStateFilename;
  if not FilenameIsAbsolute(StateFile) then exit(mrOk);
  try
    CompilerFileDate:=FileAgeCached(CompilerFilename);
    XMLConfig:=TCodeBufXMLConfig.CreateWithCache(StateFile,false);
    try
      // always write all values for easy use by other tools and other versions of IDE
      XMLConfig.SetValue('Compiler/Value',CompilerFilename);
      XMLConfig.SetValue('Compiler/Date',CompilerFileDate);
      XMLConfig.SetValue('Params/Value',CompilerParams);
      XMLConfig.SetDeleteValue('Complete/Value',Complete,true);
      InvalidateFileStateCache(StateFile);
      XMLConfig.Flush;
    finally
      XMLConfig.Free;
    end;
    LastCompilerFilename:=CompilerFilename;
    LastCompilerFileDate:=CompilerFileDate;
    LastCompilerParams:=CompilerParams;
    LastCompileComplete:=Complete;
    StateFileDate:=FileAgeCached(StateFile);
    StateFlags:=StateFlags+[lpsfStateFileLoaded];
  except
    on E: Exception do begin
      Result:=IDEMessageDialog(lisPkgMangErrorWritingFile,
        Format(lisProjMangUnableToWriteStateFileForProjectError,
               [IDAsString, LineEnding, E.Message]),
        mtError,[mbAbort,mbCancel]);
      exit;
    end;
  end;
  Result:=mrOk;
end;

procedure TProject.UpdateAllCustomHighlighter;
var
  i: Integer;
begin
  if IDEEditorOptions=nil then exit;
  for i:=0 to UnitCount-1 do
    Units[i].UpdateHasCustomHighlighter(FilenameToLazSyntaxHighlighter(Units[i].Filename));
end;

procedure TProject.UpdateAllSyntaxHighlighter;
var
  i: Integer;
begin
  if IDEEditorOptions=nil then exit;
  for i:=0 to UnitCount-1 do
    Units[i].UpdateDefaultHighlighter(FilenameToLazSyntaxHighlighter(Units[i].Filename));
end;

function TProject.GetPOOutDirectory: string;
begin
  Result:=POOutputDirectory;
  if not IDEMacros.SubstituteMacros(Result) then
    debugln(['TProject.GetPOOutDirectory failed POOutputDirectory="',POOutputDirectory,'"']);
  Result:=TrimFilename(Result);
  if not FilenameIsAbsolute(Result) then
    Result:=TrimFilename(AppendPathDelim(Directory)+Result);
end;

function TProject.GetAutoCreatedFormsList: TStrings;
var
  i, j: integer;
  S, StartS, EndS: String;
begin
  if (MainUnitID >= 0) then
  begin
    Result := CodeToolBoss.ListAllCreateFormStatements(MainUnitInfo.Source);
    if Result <> nil then
      for i := 0 to Result.Count - 1 do
      begin
        S := Result[i];
        j := Pos(':', S);
        if j > 0 then begin
          StartS := Copy(S, 1, j-1);
          EndS := Copy(S, j+1, Length(S)-j);
          if CompareText('t'+StartS, EndS) = 0 then
            Result[i] := StartS;
        end;
      end;// shorten lines of type 'FormName:TFormName' to simply 'FormName'
  end
  else
    Result := nil;
end;

function TProject.AddBookmark(X, Y, ID: Integer; AUnitInfo:TUnitInfo): integer;
begin
  Result := Bookmarks.Add(X, Y, ID, AUnitInfo);
  SessionModified := true;
end;

procedure TProject.DeleteBookmark(ID: Integer);
var
  i: Integer;
begin
  i := Bookmarks.IndexOfID(ID);
  if i < 0 then exit;
  Bookmarks.Delete(i);
  SessionModified := true;
end;

procedure TProject.UnitNameChangeHandler(AnUnitInfo: TUnitInfo;
  const OldUnitName, NewUnitName: string; CheckIfAllowed: boolean;
  var Allowed: boolean);
var
  i:integer;
begin
  if AnUnitInfo.IsPartOfProject then
  begin
    if CheckIfAllowed then begin
      // check if no other project unit has this name
      for i:=0 to UnitCount-1 do begin
        if (Units[i].IsPartOfProject)
        and (Units[i]<>AnUnitInfo) and (Units[i].Unit_Name<>'')
        and (CompareText(Units[i].Unit_Name,NewUnitName)=0) then begin
          Allowed:=false;
          exit;
        end;
      end;
    end;
    if (OldUnitName<>'') then
    begin
      if (pfMainUnitIsPascalSource in Flags) then
      begin
        // rename unit in program uses section
        CodeToolBoss.RenameUsedUnit(MainUnitInfo.Source, OldUnitName, NewUnitName, '');
      end;
      if MainUnitInfo = AnUnitInfo then
      begin
        // we are renaming a project => update resource directives
        ProjResources.RenameDirectives(OldUnitName, NewUnitName);
      end;
    end;
  end;
end;

procedure TProject.SetActiveBuildMode(const AValue: TProjectBuildMode);
begin
  // Must be set even if FActiveBuildMode=AValue. Modes may be added and deleted,
  //  the same old address can be used by a new mode.
  FActiveBuildMode:=AValue;
  if FActiveBuildMode<>nil then
    FLazCompilerOptions:=FActiveBuildMode.CompilerOptions
  else
    FLazCompilerOptions:=nil;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetActiveBuildMode ']);
  {$ENDIF}
  SessionModified:=true;
  if Self=Project1 then
    IncreaseBuildMacroChangeStamp;
end;

procedure TProject.SetActiveBuildModeID(aIdent: string);
var
  i: Integer;
begin
  for i:=0 to BuildModes.Count-1 do
  begin
    if BuildModes[i].Identifier=aIdent then
    begin
      ActiveBuildMode:=BuildModes[i];
      Break;
    end;
  end;
end;

procedure TProject.SetAutoOpenDesignerFormsDisabled(const AValue: boolean);
begin
  if FAutoOpenDesignerFormsDisabled=AValue then exit;
  FAutoOpenDesignerFormsDisabled:=AValue;
end;

procedure TProject.SetDebuggerBackend(AValue: String);
begin
  if FDebuggerBackend = AValue then Exit;
  FDebuggerBackend := AValue;
  Modified := True;
end;

procedure TProject.SetEnableI18NForLFM(const AValue: boolean);
begin
  if FEnableI18NForLFM=AValue then exit;
  FEnableI18NForLFM:=AValue;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetEnableI18NForLFM ',AValue]);
  {$ENDIF}
  Modified:=true;
end;

procedure TProject.SetLastCompilerParams(AValue: string);
begin
  if FLastCompilerParams=AValue then Exit;
  //debugln(['TProject.SetLastCompilerParams Old="',FLastCompilerParams,'"']);
  //debugln(['TProject.SetLastCompilerParams New="',AValue,'"']);
  FLastCompilerParams:=AValue;
end;

procedure TProject.SetMainProject(const AValue: boolean);
begin
  if MainProject=AValue then exit;
  FMainProject:=AValue;
  if MainProject then
    SourceDirectories.AddFilename(VirtualDirectory)
  else
    SourceDirectories.RemoveFilename(VirtualDirectory);
end;

procedure TProject.SetSkipCheckLCLInterfaces(const AValue: boolean);
begin
  if FSkipCheckLCLInterfaces=AValue then exit;
  FSkipCheckLCLInterfaces:=AValue;
  SessionModified:=true;
end;

procedure TProject.SetStorePathDelim(const AValue: TPathDelimSwitch);
begin
  if FStorePathDelim=AValue then exit;
  FStorePathDelim:=AValue;
  {$IFDEF VerboseIDEModified}
  debugln(['TProject.SetStorePathDelim ']);
  {$ENDIF}
  Modified:=true;
end;

function TProject.JumpHistoryCheckPosition(
  APosition: TProjectJumpHistoryPosition): boolean;
var i: integer;
begin
  i:=IndexOfFilename(APosition.Filename);
  Result:=(i>=0) and (Units[i].OpenEditorInfoCount > 0);
end;

function TProject.SomethingModified(CheckData, CheckSession: boolean;
  Verbose: boolean): boolean;
begin
  Result := True;
  if CheckData and SomeDataModified(Verbose) then exit;
  if CheckSession and SomeSessionModified(Verbose) then exit;
  Result := False;
end;

function TProject.SomeDataModified(Verbose: boolean): boolean;
var
  AnUnitInfo: TUnitInfo;
begin
  Result:=true;
  if Modified then
  begin
    if Verbose then
      DebugLn('TProject.SomeDataModified Modified');
    Exit;
  end;
  if BuildModes.IsModified(false) then
  begin
    if Verbose then
      DebugLn(['TProject.SomeDataModified CompilerOptions/BuildModes']);
    Exit;
  end;
  AnUnitInfo:=FirstPartOfProject;
  while AnUnitInfo<>nil do begin
    if AnUnitInfo.Modified then
    begin
      if Verbose then
        DebugLn('TProject.SomeDataModified PartOfProject ',AnUnitInfo.Filename);
      Exit;
    end;
    AnUnitInfo:=AnUnitInfo.NextPartOfProject;
  end;
  Result:=false;
end;

function TProject.SomeSessionModified(Verbose: boolean): boolean;
var
  i: Integer;
begin
  Result:=true;
  if SessionModified then
  begin
    if Verbose then
      DebugLn('TProject.SomeSessionModified SessionModified');
    Exit;
  end;
  if BuildModes.IsModified(true) then
  begin
    if Verbose then
      DebugLn(['TProject.SomeSessionModified CompilerOptions/BuildModes']);
    Exit;
  end;
  for i := 0 to UnitCount - 1 do
  begin
    if Units[i].SessionModified then
    begin
      if Verbose then
        DebugLn('TProject.SomeSessionModified Session of ',Units[i].Filename);
      exit;
    end;
    if (not Units[i].IsPartOfProject) and Units[i].Modified then
    begin
      if Verbose then
        DebugLn('TProject.SomeSessionModified Not PartOfProject ',Units[i].Filename);
      exit;
    end;
  end;
  Result:=false;
end;

procedure TProject.MainSourceFilenameChanged;
begin

end;

function TProject.UnitWithComponent(AComponent: TComponent): TUnitInfo;
begin
  Result:=fFirst[uilWithComponent];
  while (Result<>nil) and (Result.Component<>AComponent) do
    Result:=Result.fNext[uilWithComponent];
end;

function TProject.UnitWithComponentClass(AClass: TComponentClass): TUnitInfo;
begin
  Result:=fFirst[uilWithComponent];
  while (Result<>nil) and (Result.Component.ClassType<>AClass) do
    Result:=Result.fNext[uilWithComponent];
end;

function TProject.UnitWithComponentClassName(const AClassName: string): TUnitInfo;
begin
  Result := fFirst[uilWithComponent];
  while (Result<>nil)
  and (SysUtils.CompareText(Result.Component.ClassName, AClassName) <> 0) do
    Result := Result.fNext[uilWithComponent];
end;

function TProject.UnitWithComponentName(AComponentName: String;
  OnlyPartOfProject: boolean): TUnitInfo;
var
  i: Integer;
begin
  if OnlyPartOfProject then begin
    Result := fFirst[uilPartOfProject];
    while (Result<>nil)
    and (SysUtils.CompareText(Result.ComponentName, AComponentName) <> 0) do
      Result := Result.fNext[uilPartOfProject];
  end else begin
    Result:=nil;
    for i:=0 to UnitCount-1 do
      if SysUtils.CompareText(Units[i].ComponentName,AComponentName)=0 then
      begin
        Result:=Units[i];
        exit;
      end;
  end;
end;

function TProject.UnitComponentInheritingFrom(AClass: TComponentClass;
  Ignore: TUnitInfo): TUnitInfo;
begin
  Result:=fFirst[uilWithComponent];
  while (Result<>nil) do begin
    if (Result<>Ignore) and Result.Component.InheritsFrom(AClass) then exit;
    Result:=Result.fNext[uilWithComponent];
  end;
end;

function TProject.UnitUsingComponentUnit(ComponentUnit: TUnitInfo;
  Types: TUnitCompDependencyTypes): TUnitInfo;
var
  Dependency: TUnitComponentDependency;
begin
  Result:=nil;
  Dependency:=ComponentUnit.FindUsedByComponentDependency(Types);
  if Dependency=nil then exit;
  Result:=Dependency.UsedByUnit;
end;

function TProject.UnitComponentIsUsed(ComponentUnit: TUnitInfo;
  CheckHasDesigner: boolean): boolean;
begin
  if ComponentUnit.Component=nil then exit(false);
  if CheckHasDesigner
  and (uifComponentUsedByDesigner in ComponentUnit.Flags) then
    exit(true);
  if (uifComponentIndirectlyUsedByDesigner in ComponentUnit.Flags) then
    exit(true);
  if ComponentUnit.FindUsedByComponentDependency([ucdtAncestor])<>nil then
    exit(true);
  if ComponentUnit.FindUsedByComponentDependency([ucdtInlineClass])<>nil then
    exit(true);
  Result:=false;
end;

function TProject.UnitInfoWithFilename(const AFilename: string): TUnitInfo;
var
  i: Integer;
begin
  i:=IndexOfFilename(AFilename);
  if i>=0 then
    Result:=Units[i]
  else
    Result:=nil;
end;

function TProject.UnitInfoWithFilename(const AFilename: string;
  SearchFlags: TProjectFileSearchFlags): TUnitInfo;

  function MakeFilenameComparable(const TheFilename: string): string;
  begin
    Result:=TheFilename;
    if (pfsfResolveFileLinks in SearchFlags)
    and FilenameIsAbsolute(Result) then
      Result:=GetPhysicalFilenameCached(Result,false);
  end;

  function FindFileInList(ListType: TUnitInfoList): TUnitInfo;
  var
    BaseFilename: String;
    CurBaseFilename: String;
  begin
    BaseFilename:=MakeFilenameComparable(AFilename);
    Result:=fFirst[ListType];
    while Result<>nil do begin
      CurBaseFilename:=MakeFilenameComparable(Result.Filename);
      if CompareFilenames(BaseFilename,CurBaseFilename)=0 then exit;
      Result:=Result.fNext[ListType];
    end;
  end;

var
  i: Integer;
begin
  if (SearchFlags-[pfsfResolveFileLinks]=[pfsfOnlyEditorFiles]) then
    // search only in list of Files with EditorIndex
    // There is a list, so we can search much faster
    Result:=FindFileInList(uilWithEditorIndex)
  else if (SearchFlags-[pfsfResolveFileLinks]=[pfsfOnlyProjectFiles]) then
    // search only in list of project files
    // There is a list, so we can search much faster
    Result:=FindFileInList(uilPartOfProject)
  else begin
    // slow search
    i:=IndexOfFilename(AFilename,SearchFlags);
    if i>=0 then
      Result:=Units[i]
    else
      Result:=nil;
  end;
end;

function TProject.UnitWithUnitname(const AnUnitname: string): TUnitInfo;
var
  i: Integer;
begin
  i:=IndexOfUnitWithName(AnUnitName,true,nil);
  if i>=0 then
    Result:=Units[i]
  else
    Result:=nil;
end;

function TProject.AllEditorsInfoCount: Integer;
begin
  Result := FAllEditorsInfoList.Count;
end;

function TProject.EditorInfoWithEditorComponent(AEditor: TSourceEditorInterface): TUnitEditorInfo;
begin
  Result := Nil;
  FAllEditorsInfoMap.GetData(AEditor, Result);
end;

procedure TProject.EditorInfoAdd(EdInfo: TUnitEditorInfo);
begin
  FAllEditorsInfoList.Add(EdInfo);
  Assert(not Assigned(EdInfo.EditorComponent),
         'TUnitEditorInfo.EditorComponent should not be assigned. It is set later.');
end;

procedure TProject.EditorInfoRemove(EdInfo: TUnitEditorInfo);
begin
  FAllEditorsInfoList.Remove(EdInfo);
  if Assigned(EdInfo.EditorComponent) then
    FAllEditorsInfoMap.Delete(EdInfo.EditorComponent);
end;

procedure TProject.OnMacroEngineSubstitution(TheMacro: TTransferMacro;
  const MacroName: string; var s: string; const Data: PtrInt; var Handled,
  Abort: boolean; Depth: integer);
var
  Values: TCTCfgScriptVariables;
  Macro: PCTCfgScriptVariable;
var
  NewValue: String;
begin
  if Data=CompilerOptionMacroPlatformIndependent then
  begin
    NewValue:=GetMakefileMacroValue(MacroName);
    if NewValue<>'' then begin
      s:=NewValue;
      Handled:=true;
      exit;
    end;
  end;

  // check build macros
  if IsValidIdent(MacroName) then
  begin
    Values:=GetBuildMacroValues(CompilerOptions,true);
    if Values<>nil then begin
      Macro:=Values.GetVariable(PChar(MacroName));
      if Macro<>nil then
      begin
        s:=GetCTCSVariableAsString(Macro);
        //debugln(['TProject.OnMacroEngineSubstitution Macro=',MacroName,' Value="',s,'"']);
        Handled:=true;
        exit;
      end;
    end;
  end;

  // check local macros

  // check global macros
  GlobalMacroList.ExecuteMacro(MacroName,s,Data,Handled,Abort,Depth);
end;

function TProject.SearchFile(const ShortFilename: string;
  SearchFlags: TSearchIDEFileFlags): TUnitInfo;
var
  SearchedFilename: String;

  function FilenameFits(AFilename: string): boolean;
  begin
    if siffIgnoreExtension in SearchFlags then
      AFileName:=ExtractFilenameOnly(AFileName);
    if FilenameIsAbsolute(AFileName) then
      AFileName:=ExtractFilename(AFileName);
    if siffCaseSensitive in SearchFlags then
      Result:=SearchedFilename=AFilename
    else // check Pascal case insensitivity (CompareText, do not use CompareFilenamesIgnoreCase, because of Turkish I)
      Result:=CompareText(SearchedFilename,AFilename)=0;
  end;
  
begin
  SearchedFilename:=ShortFilename;
  if siffIgnoreExtension in SearchFlags then
    SearchedFilename:=ExtractFilenameOnly(SearchedFilename);

  // search in files which are part of the project
  Result:=FirstPartOfProject;
  while Result<>nil do begin
    if FilenameFits(Result.Filename) then exit;
    Result:=Result.NextPartOfProject;
  end;
  // search in files opened in editor
  if not (siffDoNotCheckOpenFiles in SearchFlags) then begin
    Result:=FirstUnitWithEditorIndex;
    while Result<>nil do begin
      if FilenameFits(Result.Filename) then exit;
      Result:=Result.NextUnitWithEditorIndex;
    end;
  end;
end;

function TProject.FindFile(const AFilename: string;
  SearchFlags: TProjectFileSearchFlags): TLazProjectFile;
begin
  Result:=UnitInfoWithFilename(AFilename, SearchFlags);
end;

function TProject.UpdateIsPartOfProjectFromMainUnit: TModalResult;
var
  FoundInUnits, MissingInUnits, NormalUnits: TStrings;
  i: Integer;
  Code: TCodeBuffer;
  CurFilename: String;
  AnUnitInfo, NewUnitInfo: TUnitInfo;
begin
  if (MainUnitID<0) or (MainUnitInfo.Source=nil)
  or ([pfMainUnitIsPascalSource,pfMainUnitHasUsesSectionForAllUnits]*Flags
    <>[pfMainUnitIsPascalSource,pfMainUnitHasUsesSectionForAllUnits])
  then
    exit(mrOk);
  try
    if CodeToolBoss.FindDelphiProjectUnits(MainUnitInfo.Source,FoundInUnits,
      MissingInUnits, NormalUnits, true)
    then
      Result:=mrOk
    else
      Result:=mrCancel;
    if FoundInUnits<>nil then begin
      for i:=0 to FoundInUnits.Count-1 do begin
        Code:=FoundInUnits.Objects[i] as TCodeBuffer;
        CurFilename:=Code.Filename;
        AnUnitInfo:=UnitInfoWithFilename(CurFilename);
        if (AnUnitInfo<>nil) and AnUnitInfo.IsPartOfProject then continue;
        if ConsoleVerbosity>=0 then
          debugln(['Note: (lazarus) [TProject.UpdateIsPartOfProjectFromMainUnit] used unit ',FoundInUnits[i],' not marked in lpi. Setting IsPartOfProject flag.']);
        if AnUnitInfo=nil then begin
          NewUnitInfo:=TUnitInfo.Create(nil);
          NewUnitInfo.Filename:=CurFilename;
          NewUnitInfo.IsPartOfProject:=true;
          NewUnitInfo.Source:=Code;
          AddFile(NewUnitInfo,false);
        end else
          AnUnitInfo.IsPartOfProject:=true;
      end;
    end;
  finally
    FoundInUnits.Free;
    MissingInUnits.Free;
    NormalUnits.Free;
  end;
end;

function TProject.IndexOfFilename(const AFilename: string): integer;
begin
  Result:=UnitCount-1;
  while (Result>=0) do begin
    if CompareFilenames(AFilename,Units[Result].Filename)=0 then exit;
    dec(Result);
  end;
end;

function TProject.IndexOfFilename(const AFilename: string;
  SearchFlags: TProjectFileSearchFlags): integer;

  function MakeFilenameComparable(const TheFilename: string): string;
  begin
    Result:=TheFilename;
    if (pfsfResolveFileLinks in SearchFlags)
    and (FilenameIsAbsolute(Result)) then
      Result:=GetPhysicalFilenameCached(Result,false);
  end;

var
  BaseFilename: String;
  CurBaseFilename: String;
begin
  BaseFilename:=MakeFilenameComparable(AFilename);
  Result:=UnitCount-1;
  while (Result>=0) do begin
    if (pfsfOnlyEditorFiles in SearchFlags)
    and (Units[Result].OpenEditorInfoCount = 0) then begin
      dec(Result);
      continue;
    end;
    if (pfsfOnlyVirtualFiles in SearchFlags)
    and (not Units[Result].IsVirtual) then begin
      dec(Result);
      continue;
    end;
    if (pfsfOnlyProjectFiles in SearchFlags)
    and (not Units[Result].IsPartOfProject) then begin
      dec(Result);
      continue;
    end;
    CurBaseFilename:=MakeFilenameComparable(Units[Result].Filename);
    if CompareFilenames(BaseFilename,CurBaseFilename)=0 then exit;
    dec(Result);
  end;
end;

function TProject.ProjectUnitWithFilename(const AFilename: string): TUnitInfo;
begin
  Result:=fFirst[uilPartOfProject];
  while Result<>nil do begin
    if CompareFileNames(AFilename,Result.Filename)=0 then exit;
    Result:=Result.fNext[uilPartOfProject];
  end;
end;

function TProject.ProjectUnitWithShortFilename(const ShortFilename: string): TUnitInfo;
begin
  Result:=fFirst[uilPartOfProject];
  while Result<>nil do begin
    if CompareFileNames(ShortFilename,ExtractFilename(Result.Filename))=0 then
      exit;
    Result:=Result.fNext[uilPartOfProject];
  end;
end;

function TProject.ProjectUnitWithUnitname(const AnUnitName: string): TUnitInfo;
begin
  Result:=fFirst[uilPartOfProject];
  while Result<>nil do begin
    if CompareText(AnUnitName,Result.Unit_Name)=0 then exit;
    Result:=Result.fNext[uilPartOfProject];
  end;
end;

procedure TProject.UpdateFileBuffer;
begin
  fProjectInfoFileBuffer:=CodeToolBoss.LoadFile(ProjectInfoFile,true,true);
  fProjectInfoFileDate:=FileAgeCached(ProjectInfoFile);
  if fProjectInfoFileBuffer<>nil then
    fProjectInfoFileBufChangeStamp:=fProjectInfoFileBuffer.ChangeStep
  else
    fProjectInfoFileBufChangeStamp:=CTInvalidChangeStamp;
end;

procedure TProject.UpdateProjectDirectory;
var
  i: Integer;
begin
  if fDestroying then exit;
  fProjectDirectory:=ExtractFilePath(fProjectInfoFile);
  if BuildModes<>nil then
    for i:=0 to BuildModes.Count-1 do
      BuildModes[i].CompilerOptions.BaseDirectory:=fProjectDirectory;
  if fProjectDirectory<>fProjectDirectoryReferenced then begin
    if fProjectDirectoryReferenced<>'' then
      FSourceDirectories.RemoveFilename(fProjectDirectoryReferenced);
    if fProjectDirectory<>'' then
      FSourceDirectories.AddFilename(fProjectDirectory);
    fProjectDirectoryReferenced:=fProjectDirectory;
  end;
end;

procedure TProject.UpdateSessionFilename;
begin
  case SessionStorage of
  pssInProjectInfo: ProjectSessionFile:=ProjectInfoFile;
  pssInProjectDir: ProjectSessionFile:=ChangeFileExt(ProjectInfoFile,'.lps');
  pssInIDEConfig: ProjectSessionFile:=AppendPathDelim(GetProjectSessionsConfigPath)
                                     +ExtractFileNameOnly(ProjectInfoFile)+'.lps';
  pssNone: ProjectSessionFile:='';
  end;
end;

procedure TProject.UpdateSourceDirectories;
var
  Cnt: Integer;
  i: Integer;
  AnUnitInfo: TUnitInfo;
begin
  Cnt:=FUnitList.Count;
  for i:=0 to Cnt-1 do begin
    AnUnitInfo:=Units[i];
    AnUnitInfo.FSourceDirectoryReferenced:=false;
  end;
  ClearSourceDirectories;
  for i:=0 to Cnt-1 do begin
    AnUnitInfo:=Units[i];
    AnUnitInfo.AutoReferenceSourceDir:=true;
    AnUnitInfo.UpdateSourceDirectoryReference;
  end;
  //DebugLn('TProject.UpdateSourceDirectories B ',UnitCount,' "',fSourceDirectories.CreateSearchPathFromAllFiles,'"');
end;

procedure TProject.UpdateUsageCounts(const ConfigFilename: string);
var
  UnitUsageCount: TDateTime;
  DiffTime: TDateTime;
  i: Integer;
begin
  UnitUsageCount:=0;
  if CompareFileNames(ConfigFilename,fLastReadLPIFilename)=0 then begin
    DiffTime:=Now-fLastReadLPIFileDate;
    if DiffTime>0 then
      UnitUsageCount:= DiffTime*24; // one step every hour
    fLastReadLPIFileDate:=Now;
  end;
  for i:=0 to UnitCount-1 do begin
    if Units[i].IsPartOfProject then
      Units[i].UpdateUsageCount(uuIsPartOfProject,UnitUsageCount)
    else if Units[i].Loaded then
      Units[i].UpdateUsageCount(uuIsLoaded,UnitUsageCount)
    else
      Units[i].UpdateUsageCount(uuNotUsed,UnitUsageCount);
  end;
end;

function TProject.UnitMustBeSaved(UnitInfo: TUnitInfo; WriteFlags: TProjectWriteFlags;
  SaveSession: boolean): boolean;
begin
  Result:=false;
  if not UnitInfo.IsPartOfProject then begin
    if not SaveSession then exit;
    if (pfSaveOnlyProjectUnits in Flags) then exit;
    if (pwfSaveOnlyProjectUnits in WriteFlags) then exit;
    if (not UnitInfo.Loaded) then begin
      if (not (pfSaveClosedUnits in Flags)) then exit;
      if (pwfSkipClosedUnits in WriteFlags) then exit;
      if UnitInfo.fUsageCount<=0 then exit;
    end;
  end;
  Result:=true;
end;

procedure TProject.UpdateVisibleEditor(PgIndex: integer);
var
  i: Integer;
begin
  i := AllEditorsInfoCount - 1;
  while i >= 0 do begin
    if (AllEditorsInfo[i].PageIndex = PgIndex) then
      AllEditorsInfo[i].IsVisibleTab := True;
    dec(i);
  end;
end;

procedure TProject.LoadDefaultSession;
var
  AnUnitInfo: TUnitInfo;
  BestUnitInfo: TUnitInfo;
begin
  BestUnitInfo:=FirstUnitWithEditorIndex;
  if (BestUnitInfo<>nil) and (BestUnitInfo.Loaded)
  and FileExistsCached(BestUnitInfo.Filename) then
    exit;
  BestUnitInfo:=nil;

  if (MainUnitID>=0) then begin
    if Requires(PackageGraph.LCLPackage,true)
    and (Flags*[pfMainUnitHasCreateFormStatements,pfMainUnitHasTitleStatement,pfMainUnitHasScaledStatement]<>[])
    then begin
      // this is a probably a LCL project where the main source only contains
      // automatic code
    end else
      BestUnitInfo:=MainUnitInfo;
  end;

  if BestUnitInfo=nil then begin
    AnUnitInfo:=FirstPartOfProject;
    while AnUnitInfo<>nil do begin
      if FileExistsCached(AnUnitInfo.Filename) then begin
        if (BestUnitInfo=nil)
        or (FilenameHasPascalExt(AnUnitInfo.Filename)
             and (not FilenameHasPascalExt(BestUnitInfo.Filename)))
        then begin
          BestUnitInfo:=AnUnitInfo;
        end;
      end;
      AnUnitInfo:=AnUnitInfo.NextPartOfProject;
    end;
  end;
  if BestUnitInfo<>nil then begin
    BestUnitInfo.EditorInfo[0].PageIndex := 0;
    BestUnitInfo.EditorInfo[0].WindowID := 0;
    BestUnitInfo.EditorInfo[0].IsVisibleTab := True;
    ActiveWindowIndexAtStart:=0;
    BestUnitInfo.Loaded:=true;
  end;
end;

procedure TProject.ClearSourceDirectories;
begin
  FSourceDirectories.Clear;
  fProjectDirectoryReferenced:='';
  if MainProject then
    FSourceDirectories.AddFilename(VirtualDirectory);
  if (fProjectDirectory<>'') then begin
    FSourceDirectories.AddFilename(fProjectDirectory);
    fProjectDirectoryReferenced:=fProjectDirectory;
  end;
end;

procedure TProject.SourceDirectoriesChanged(Sender: TObject);
begin
  FDefineTemplates.SourceDirectoriesChanged;
end;

function TProject.GetDefineTemplates: TProjPackDefineTemplates;
begin
  Result:=FDefineTemplates;
end;

function TProject.GetMainFile: TLazProjectFile;
begin
  Result:=MainUnitInfo;
end;

function TProject.GetMainFileID: Integer;
begin
  Result:=MainUnitID;
end;

procedure TProject.SetMainFileID(const AValue: Integer);
begin
  MainUnitID:=AValue;
end;

function TProject.GetLazBuildModes: TLazProjectBuildModes;
begin
  Result:=FBuildModes;
end;

procedure TProject.AddToList(AnUnitInfo: TUnitInfo; ListType: TUnitInfoList);
begin
  // add to list if AnUnitInfo is not in list
  if (fFirst[ListType]<>AnUnitInfo)
  and (AnUnitInfo.fNext[ListType]=nil)
  and (AnUnitInfo.fPrev[ListType]=nil) then begin
    AnUnitInfo.fPrev[ListType]:=fLast[ListType];
    AnUnitInfo.fNext[ListType]:=nil;
    if fFirst[ListType]=nil then
      fFirst[ListType]:=AnUnitInfo
    else
      fLast[ListType].fNext[ListType]:=AnUnitInfo;
    fLast[ListType]:=AnUnitInfo;
  end;
end;

procedure TProject.RemoveFromList(AnUnitInfo: TUnitInfo; ListType: TUnitInfoList);
begin
  // remove from list if AnUnitInfo is in list
  if fFirst[ListType]=AnUnitInfo then
    fFirst[ListType]:=AnUnitInfo.fNext[ListType];
  if fLast[ListType]=AnUnitInfo then
    fLast[ListType]:=AnUnitInfo.fPrev[ListType];
  if AnUnitInfo.fNext[ListType]<>nil then
    AnUnitInfo.fNext[ListType].fPrev[ListType]:=AnUnitInfo.fPrev[ListType];
  if AnUnitInfo.fPrev[ListType]<>nil then
    AnUnitInfo.fPrev[ListType].fNext[ListType]:=AnUnitInfo.fNext[ListType];
  AnUnitInfo.fNext[ListType]:=nil;
  AnUnitInfo.fPrev[ListType]:=nil;
end;

{ TProjectCompilationToolOptions }

constructor TProjectCompilationToolOptions.Create(TheOwner: TLazCompilerOptions);
begin
  inherited Create(TheOwner);
  FDefaultCompileReasons:=crAll;
end;

function TProjectCompilationToolOptions.CreateDiff(
  CompOpts: TCompilationToolOptions; Tool: TCompilerDiffTool): boolean;
begin
  Assert(Assigned(Tool),'TProjectCompilationToolOptions.CreateDiff: Tool=Nil.');
  Result:=AddCompileReasonsDiff('CompileReasons', CompileReasons,
                                CompOpts.CompileReasons, Tool);
  if Result then exit;
  if inherited CreateDiff(CompOpts, Tool) then Result:=true;
end;

procedure TProjectCompilationToolOptions.LoadFromXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; DoSwitchPathDelims: boolean);
begin
  inherited LoadFromXMLConfig(XMLConfig, Path, DoSwitchPathDelims);
  CompileReasons := LoadXMLCompileReasons(XMLConfig, Path+'CompileReasons/',
                                          DefaultCompileReasons);
  //debugln(['TProjectCompilationToolOptions.LoadFromXMLConfig ',Path,' ',crCompile in CompileReasons]);
end;

procedure TProjectCompilationToolOptions.SaveToXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; UsePathDelim: TPathDelimSwitch);
begin
  inherited SaveToXMLConfig(XMLConfig, Path, UsePathDelim);
  SaveXMLCompileReasons(XMLConfig, Path+'CompileReasons/', CompileReasons,
                        DefaultCompileReasons);
  //debugln(['TProjectCompilationToolOptions.SaveToXMLConfig ',Path,' ',crCompile in CompileReasons]);
end;

function TProjectCompilationToolOptions.GetProject: TProject;
begin
  if (Owner is TProjectCompilerOptions) then
    Result:=TProjectCompilerOptions(Owner).LazProject
  else
    Result:=nil;
end;

procedure TProjectCompilationToolOptions.SetCompileReasons(const AValue: TCompileReasons);
begin
  if FCompileReasons=AValue then exit;
  FCompileReasons:=AValue;
  Owner.IncreaseChangeStamp;
end;

procedure TProjectCompilationToolOptions.SetDefaultCompileReasons(const AValue: TCompileReasons);
begin
  if FDefaultCompileReasons=AValue then exit;
  FDefaultCompileReasons:=AValue;
  Owner.IncreaseChangeStamp;
end;

procedure TProjectCompilationToolOptions.SubstituteMacros(var s: string);
var
  CompOpts: TProjectCompilerOptions;
begin
  if Owner is TProjectCompilerOptions then begin
    CompOpts:=TProjectCompilerOptions(Owner);
    //debugln(['TProjectCompilationToolOptions.SubstituteMacros ',DbgSName(Owner),' ',CompOpts.LazProject<>nil]);
    s:=CompOpts.SubstituteProjectMacros(s,false);
  end else
    inherited SubstituteMacros(s);
end;

{ TProjectCompilerOptions }

procedure TProjectCompilerOptions.LoadFromXMLConfig(AXMLConfig: TXMLConfig;
  const Path: string);
begin
  inherited LoadFromXMLConfig(AXMLConfig,Path);
  //FileVersion:=aXMLConfig.GetValue(Path+'Version/Value', 0);
  FCompileReasons := LoadXMLCompileReasons(AXMLConfig,Path+'CompileReasons/',crAll);
end;

procedure TProjectCompilerOptions.SaveToXMLConfig(AXMLConfig: TXMLConfig;
  const Path: string);
begin
  inherited SaveToXMLConfig(AXMLConfig,Path);
  SaveXMLCompileReasons(AXMLConfig, Path+'CompileReasons/', FCompileReasons, crAll);
end;

procedure TProjectCompilerOptions.SetTargetCPU(const AValue: string);
begin
  inherited SetTargetCPU(AValue);
end;

procedure TProjectCompilerOptions.SetTargetOS(const AValue: string);
begin
  inherited SetTargetOS(AValue);
end;

procedure TProjectCompilerOptions.SetCustomOptions(const AValue: string);
begin
  if CustomOptions=AValue then exit;
  inherited SetCustomOptions(AValue);
  if IsActive then
    LazProject.DefineTemplates.CustomDefinesChanged;
end;

procedure TProjectCompilerOptions.SetIncludePaths(const AValue: string);
begin
  if IncludePath=AValue then exit;
  inherited SetIncludePaths(AValue);
end;

procedure TProjectCompilerOptions.SetLibraryPaths(const AValue: string);
begin
  if Libraries=AValue then exit;
  inherited SetLibraryPaths(AValue);
end;

procedure TProjectCompilerOptions.SetLinkerOptions(const AValue: string);
begin
  if LinkerOptions=AValue then exit;
  inherited SetLinkerOptions(AValue);
end;

procedure TProjectCompilerOptions.SetNamespaces(const AValue: string);
begin
  if Namespaces=AValue then exit;
  inherited SetNamespaces(AValue);
end;

procedure TProjectCompilerOptions.SetObjectPath(const AValue: string);
begin
  if ObjectPath=AValue then exit;
  inherited SetObjectPath(AValue);
end;

procedure TProjectCompilerOptions.SetSrcPath(const AValue: string);
begin
  if SrcPath=AValue then exit;
  inherited SetSrcPath(AValue);
end;

procedure TProjectCompilerOptions.SetUnitPaths(const AValue: string);
begin
  if OtherUnitFiles=AValue then exit;
  inherited SetUnitPaths(AValue);
end;

procedure TProjectCompilerOptions.SetUnitOutputDir(const AValue: string);
begin
  if UnitOutputDirectory=AValue then exit;
  inherited SetUnitOutputDir(AValue);
  if IsActive then
    LazProject.DefineTemplates.OutputDirectoryChanged;
end;

procedure TProjectCompilerOptions.SetConditionals(AValue: string);
begin
  AValue:=UTF8Trim(AValue,[]);
  if Conditionals=AValue then exit;
  inherited SetConditionals(AValue);
end;

function TProjectCompilerOptions.SubstituteProjectMacros(const s: string;
  PlatformIndependent: boolean): string;
begin
  Result:=s;
  if LazProject=nil then exit;
  //debugln(['TProjectCompilerOptions.SubstituteProjectMacros s="',s,'"']);
  if PlatformIndependent then begin
    if not LazProject.MacroEngine.SubstituteStr(Result,CompilerOptionMacroPlatformIndependent)
    then
      debugln(['TProjectCompilerOptions.SubstituteProjectMacros failed: "',CompilerOptionMacroPlatformIndependent,'"']);
  end
  else begin
    if not LazProject.MacroEngine.SubstituteStr(Result,CompilerOptionMacroNormal)
    then
      debugln(['TProjectCompilerOptions.SubstituteProjectMacros failed: "',CompilerOptionMacroNormal,'"']);
  end;
end;

procedure TProjectCompilerOptions.Assign(Source: TPersistent);
var
  ProjCompOptions: TProjectCompilerOptions;
begin
  inherited Assign(Source);
  if Source is TProjectCompilerOptions then begin
    ProjCompOptions:=TProjectCompilerOptions(Source);
    FCompileReasons:=ProjCompOptions.FCompileReasons;
  end else begin
    FCompileReasons:=[crCompile, crBuild, crRun];
    // keep BuildModes
  end;
end;

function TProjectCompilerOptions.CreateDiff(CompOpts: TBaseCompilerOptions;
  Tool: TCompilerDiffTool): boolean;
begin
  //if Tool<>nil then debugln(['TProjectCompilerOptions.CreateDiff ',DbgSName(Self)]);
  if (CompOpts is TProjectCompilerOptions) then begin
    Result:=AddCompileReasonsDiff('CompileReasons',FCompileReasons,
                        TProjectCompilerOptions(CompOpts).FCompileReasons,Tool);
  end else begin
    Result:=true;
    if Tool<>nil then Tool.Differ:=true;
  end;
  //if Tool<>nil then debugln(['TProjectCompilerOptions.CreateDiff Before inherited ',Result]);
  if (Tool=nil) and Result then exit;
  if (inherited CreateDiff(CompOpts, Tool)) then
    Result:=true;
end;

procedure TProjectCompilerOptions.BeforeReadExec(Sender: TObject);
begin
  if LazProject<>nil then
    LazProject.BackupBuildModes;
end;

procedure TProjectCompilerOptions.AfterWriteExec(Sender: TObject; Restore: boolean);
begin
  if Restore and (LazProject<>nil) then
    LazProject.RestoreBuildModes;
end;

procedure TProjectCompilerOptions.SetAlternativeCompile(const Command: string;
  ScanFPCMsgs: boolean);
begin
  inherited SetAlternativeCompile(Command, ScanFPCMsgs);
  CompileReasons:=[];
end;

class function TProjectCompilerOptions.GetInstance: TAbstractIDEOptions;
begin
  Result := Project1.CompilerOptions;
end;

class function TProjectCompilerOptions.GetGroupCaption: string;
begin
  Result := dlgCompilerOptions;
end;

constructor TProjectCompilerOptions.Create(const AOwner: TObject);
begin
  FCompileReasons := crAll;
  inherited Create(AOwner, TProjectCompilationToolOptions);
  if AOwner <> nil then
    FProject := AOwner as TProject;
  ParsedOpts.OnLocalSubstitute:=@SubstituteProjectMacros;
  OnAfterWrite:=@AfterWriteExec;
  OnBeforeRead:=@BeforeReadExec;
end;

destructor TProjectCompilerOptions.Destroy;
begin
  inherited Destroy;
end;

function TProjectCompilerOptions.IsActive: boolean;
begin
  Result:=(LazProject<>nil)
      and not LazProject.BuildModes.Assigning
      and (LazProject.CompilerOptions=Self);
end;

procedure TProjectCompilerOptions.Clear;
begin
  inherited Clear;
end;

function TProjectCompilerOptions.CanBeDefaulForProject: boolean;
begin
  Result:=true;
end;

function TProjectCompilerOptions.GetOwnerName: string;
begin
  Result:=LazProject.GetTitleOrName;
  if Result='' then Result:=ExtractFilename(LazProject.ProjectInfoFile);
end;

function TProjectCompilerOptions.GetDefaultMainSourceFileName: string;
var
  MainUnitInfo: TUnitInfo;
begin
  MainUnitInfo:=FProject.MainUnitInfo;
  if (MainUnitInfo<>nil) then
    Result:=ExtractFileName(MainUnitInfo.Filename)
  else
    Result:='';
  if Result='' then
    Result:=inherited GetDefaultMainSourceFileName;
end;

procedure TProjectCompilerOptions.GetInheritedCompilerOptions(
  var OptionsList: TFPList);
var
  PkgList: TFPList;
  ReqFlags: TPkgIntfRequiredFlags;
begin
  PkgList:=nil;
  try
    ReqFlags:=[];
    if not (pfUseDesignTimePackages in LazProject.Flags) then
      Include(ReqFlags,pirSkipDesignTimeOnly);
    LazProject.GetAllRequiredPackages(PkgList,ReqFlags);
    OptionsList:=GetUsageOptionsList(PkgList);
  finally
    PkgList.Free;
  end;
end;

{ TProjectDefineTemplates }

constructor TProjectDefineTemplates.Create(AOwner: IProjPack);
begin
  inherited Create(AOwner);
end;

destructor TProjectDefineTemplates.Destroy;
begin
  inherited Destroy;
end;

procedure TProjectDefineTemplates.UpdateMain;
begin
  if (Owner as TProject).Destroying then exit;
  // update the package block define template (the container for all other
  // define templates of the project)
  if FMain=nil then begin
    // create the main project template
    FMain:=CreateProjectTemplateWithID(Owner.IDAsWord);
    FMain.SetDefineOwner(Owner as TProject,false);
    FMain.SetFlags([dtfAutoGenerated],[],false);
  end else
    FMain.Name:=Owner.IDAsWord;
  // ClearCache is here unnessary, because it is only a block
end;

function TProjectDefineTemplates.UpdateSrcDirIfDef: Boolean;
// Returns the changed state
var
  NamespacesDefTempl: TDefineTemplate;
  UnitPathDefTempl: TDefineTemplate;
  IncPathDefTempl: TDefineTemplate;
  SrcPathDefTempl: TDefineTemplate;
  IfValue: String;
begin
  // The options are enclosed by an
  // IFDEF #ProjectSrcMark<PckId> template.
  // Each source directory defines this variable, so that the settings can be
  // activated for each source directory by a simple DEFINE.
  if (FMain=nil) then UpdateMain;
  if FSrcDirectories=nil then begin
    FSrcDirectories:=TDefineTemplate.Create('Source Directories',
      'Source Directories','','',
      da_Block);
    FMain.AddChild(FSrcDirectories);
  end;

  Result:=false;
  IfValue:='defined(#ProjectSrcMark'+Owner.IDAsWord+')';
  if (Owner as TProject) = Project1 then
    IfValue:=IfValue+' or defined('+UseDefaultsFlagName+')';
  if FSrcDirIf=nil then begin
    FSrcDirIf:=TDefineTemplate.Create('Source Directory Additions',
      'Additional defines for project source directories and all directories using defaults',
      '',IfValue,
      da_If);
    FMain.AddChild(FSrcDirIf);
    
    // create namespaces template for this directory
    NamespacesDefTempl:=TDefineTemplate.Create('Namespaces', lisPkgDefsNamespaces,
      NamespacesMacroName,NamespacesMacro+';$ProjectNamespaces('+Owner.IDAsString+')',
      da_Define);
    FSrcDirIf.AddChild(NamespacesDefTempl);

    // create unit path template for this directory
    UnitPathDefTempl:=TDefineTemplate.Create('UnitPath', lisPkgDefsUnitPath,
      UnitPathMacroName,UnitPathMacro+';$ProjectUnitPath('+Owner.IDAsString+')',
      da_Define);
    FSrcDirIf.AddChild(UnitPathDefTempl);

    // create include path template for this directory
    IncPathDefTempl:=TDefineTemplate.Create('IncPath','Include Path',
      IncludePathMacroName,IncludePathMacro+';$ProjectIncPath('+Owner.IDAsString+')',
      da_Define);
    FSrcDirIf.AddChild(IncPathDefTempl);

    // create src path template for this directory
    SrcPathDefTempl:=TDefineTemplate.Create('SrcPath','Src Path',
      SrcPathMacroName,SrcPathMacro+';$ProjectSrcPath('+Owner.IDAsString+')',
      da_Define);
    FSrcDirIf.AddChild(SrcPathDefTempl);

    Result:=true;
  end else begin
    if FSrcDirIf.Value<>IfValue then begin
      FSrcDirIf.Value:=IfValue;
      Result:=true;
    end;
  end;
end;

procedure TProjectDefineTemplates.UpdateOutputDirectory;
var
  Proj: TProject;
begin
  Proj := Owner as TProject;
  //DebugLn('TProjectDefineTemplates.UpdateDefinesForOutputDirectory ',Owner.IDAsString);
  if (not Owner.NeedsDefineTemplates) or (not Active) then exit;
  if FMain=nil then UpdateMain;

  if FOutputDir=nil then begin
    //DebugLn('TProjectDefineTemplates.UpdateDefinesForOutputDirectory ',Owner.IDAsString,' creating FOutputDir');
    FOutputDir:=TDefineTemplate.Create(ProjectOutputDirDefTemplName,
      'Output directory of proj', '', Proj.GetOutputDirectory, da_Directory);
    FOutputDir.SetDefineOwner(Proj,false);
    FOutputDir.SetFlags([dtfAutoGenerated],[],false);
    DisableDefaultsInDirectories(FOutputDir,false);
    FMain.AddChild(FOutputDir);
    FixTemplateOrder;
  end else begin
    FOutputDir.Value:=Proj.GetOutputDirectory;
  end;

  if (FOutPutSrcPath=nil)
  or (fLastOutputDirSrcPathIDAsString<>Owner.IDAsString) then begin
    fLastOutputDirSrcPathIDAsString:=Owner.IDAsString;
    FOutputSrcPath:=TDefineTemplate.Create('CompiledSrcPath',
      lisPkgDefsCompiledSrcPathAddition, CompiledSrcPathMacroName,
      '$ProjectSrcPath('+fLastOutputDirSrcPathIDAsString+');'
        +'$('+CompiledSrcPathMacroName+')',
      da_Define);
    FOutputSrcPath.SetDefineOwner(Proj,false);
    FOutputSrcPath.SetFlags([dtfAutoGenerated],[],false);
    CodeToolBoss.DefineTree.ReplaceChild(FOutputDir,FOutputSrcPath,FOutputSrcPath.Name);
  end;
end;

procedure TProjectDefineTemplates.UpdateSourceDirectories;
var
  NewSourceDirs: TStringList;
  i: Integer;
  SrcDirDefTempl: TDefineTemplate;
  IDHasChanged: Boolean;
  SrcDirMarkDefTempl: TDefineTemplate;
  CurUnitPath: String;
begin
  //DebugLn('TProjectDefineTemplates.UpdateDefinesForSourceDirectories ',Owner.IDAsString,' Active=',dbgs(Active),' TimeStamp=',dbgs(fLastSourceDirStamp),' Project.TimeStamp=',dbgs(Project.SourceDirectories.TimeStamp));
  if (not Owner.NeedsDefineTemplates) or (not Active) then exit;

  // quick check if something has changed
  IDHasChanged:=fLastSourceDirsIDAsString<>Owner.IDAsString;
  CurUnitPath:=Owner.BaseCompilerOptions.ParsedOpts.GetParsedValue(pcosUnitPath);
  CurUnitPath:=CreateAbsoluteSearchPath(CurUnitPath,
                                        Owner.BaseCompilerOptions.BaseDirectory);

  //DebugLn('TProjectDefineTemplates.UpdateDefinesForSourceDirectories A');
  if (fLastSourceDirectories<>nil)
  and (fLastSourceDirStamp=Owner.SourceDirectories.TimeStamp)
  and (not IDHasChanged)
  and (CurUnitPath=fLastUnitPath) then
    exit;
  fLastSourceDirStamp:=Owner.SourceDirectories.TimeStamp;
  fLastSourceDirsIDAsString:=Owner.IDAsString;
  fLastUnitPath:=CurUnitPath;

  NewSourceDirs:=Owner.SourceDirectories.CreateFileList;
  //DebugLn('TProjectDefineTemplates.UpdateDefinesForSourceDirectories B "',NewSourceDirs.Text,'"');
  try
    MergeSearchPaths(NewSourceDirs,CurUnitPath);
    
    // real check if something has changed
    if (fLastSourceDirectories<>nil)
    and (NewSourceDirs.Count=fLastSourceDirectories.Count)
    and (not IDHasChanged) then begin
      i:=NewSourceDirs.Count-1;
      while (i>=0)
      and (CompareFilenames(NewSourceDirs[i],fLastSourceDirectories[i])=0) do
        dec(i);
      if i<0 then exit;
    end;

    // clear old define templates
    if fLastSourceDirectories<>nil then begin
      for i:=0 to fLastSourceDirectories.Count-1 do begin
        SrcDirDefTempl:=TDefineTemplate(fLastSourceDirectories.Objects[i]);
        SrcDirDefTempl.Unbind;
        SrcDirDefTempl.Free;
      end;
      fLastSourceDirectories.Clear;
    end else
      fLastSourceDirectories:=TStringList.Create;

    // build source directory define templates
    fLastSourceDirectories.Assign(NewSourceDirs);
    if (FSrcDirIf=nil) and (fLastSourceDirectories.Count>0) then
      UpdateSrcDirIfDef;
    for i:=0 to fLastSourceDirectories.Count-1 do begin
      // create directory template
      SrcDirDefTempl:=TDefineTemplate.Create('Source Directory '+IntToStr(i+1),
        fLastSourceDirectories[i],'',fLastSourceDirectories[i],da_Directory);
      DisableDefaultsInDirectories(SrcDirDefTempl,false);
      fLastSourceDirectories.Objects[i]:=SrcDirDefTempl;
      // add proj source directory marker
      SrcDirMarkDefTempl:=TDefineTemplate.Create('ProjectSrcDirMark',
        lisProjProjectSourceDirectoryMark, '#ProjectSrcMark'+Owner.IDAsWord,
          '1', da_Define);
      SrcDirDefTempl.AddChild(SrcDirMarkDefTempl);

      SrcDirDefTempl.SetDefineOwner(Owner as TProject, false);
      SrcDirDefTempl.SetFlags([dtfAutoGenerated],[],false);
      // add directory
      FSrcDirectories.AddChild(SrcDirDefTempl);
    end;
    //DebugLn('TProjectDefineTemplates.UpdateSourceDirectories: Calling CodeToolBoss.DefineTree.ClearCache');
    CodeToolBoss.DefineTree.ClearCache;
  finally
    NewSourceDirs.Free;
  end;
end;

procedure TProjectDefineTemplates.UpdateDefinesForCustomDefines;
var
  OptionsDefTempl: TDefineTemplate;
  NewCustomOptions: String;
begin
  if (not Owner.NeedsDefineTemplates) or (not Active) then exit;

  // check if something has changed
  NewCustomOptions:=Owner.BaseCompilerOptions.GetOptionsForCTDefines;
  if (FLastCustomOptions=NewCustomOptions) then exit;

  FLastCustomOptions:=NewCustomOptions;
  OptionsDefTempl:=CodeToolBoss.DefinePool.CreateFPCCommandLineDefines(
                 'Custom Options', FLastCustomOptions, false, Owner as TProject);
  if OptionsDefTempl=nil then begin
    // no custom options -> delete old template
    if (FSrcDirIf<>nil) and FSrcDirIf.DeleteChild('Custom Options') then
    begin
      //DebugLn('TProjectDefineTemplates.UpdateDefinesForCustomDefines: Calling CodeToolBoss.DefineTree.ClearCache');
      CodeToolBoss.DefineTree.ClearCache;
    end;
  end else begin
    UpdateSrcDirIfDef;
    FSrcDirIf.ReplaceChild(OptionsDefTempl);
    //DebugLn('TProjectDefineTemplates.UpdateDefinesForCustomDefines: Calling CodeToolBoss.DefineTree.ClearCache');
    CodeToolBoss.DefineTree.ClearCache;
  end;
end;

procedure TProjectDefineTemplates.FixTemplateOrder;
begin
  if (FSrcDirIf<>nil) then
    FSrcDirIf.Parent.MoveToLast(FSrcDirIf);
end;

procedure TProjectDefineTemplates.ClearFlags;
begin
  FFlags:=FFlags+[ptfCustomDefinesChanged];
end;

procedure TProjectDefineTemplates.AllChanged(AActivating: boolean);
begin
  if AActivating then ;
  UpdateSrcDirIfDef;
  SourceDirectoriesChanged;
  CustomDefinesChanged;
  UpdateGlobalValues;
end;

procedure TProjectDefineTemplates.UpdateGlobalValues;
var
  NewProjectDir: String;
  Changed: Boolean;
begin
  Changed:=false;
  // the LCLWidgetType, TargetCPU and TargetOS is set by the TBuildManager
  if (Owner as TProject).IsVirtual then
    NewProjectDir:=VirtualDirectory
  else
    NewProjectDir:=(Owner as TProject).Directory;
  if CodeToolBoss.SetGlobalValue(ExternalMacroStart+'ProjPath',NewProjectDir)
  then
    Changed:=true;
  if Changed then
    IncreaseCompilerParseStamp;
end;

{ TUnitComponentDependency }

procedure TUnitComponentDependency.SetRequiresUnit(const AValue: TUnitInfo);
begin
  if FRequiresUnit=AValue then exit;
  if (AValue<>nil) and (FUsedByUnit=AValue) then
    raise Exception.Create('TUnitComponentDependency.SetRequiresUnit inconsistency');
  if FRequiresUnit<>nil then
    RemoveFromList(FRequiresUnit.FFirstUsedByComponent,ucdlUsedBy);
  FRequiresUnit:=AValue;
  if FRequiresUnit<>nil then
    AddToList(FRequiresUnit.FFirstUsedByComponent,ucdlUsedBy);
end;

procedure TUnitComponentDependency.SetTypes(const AValue: TUnitCompDependencyTypes);
begin
  if AValue=FTypes then exit;
  FTypes:=AValue;
  if (not (ucdtOldProperty in FTypes)) and (FCompProps<>nil) then
    ClearComponentProperties;
end;

function TUnitComponentDependency.GetCompPropCount: integer;
begin
  if FCompProps=nil then
    Result:=0
  else
    Result:=FCompProps.Count;
end;

function TUnitComponentDependency.GetCompProps(Index: integer): TUCDComponentProperty;
begin
  Result:=TUCDComponentProperty(FCompProps[Index]);
end;

procedure TUnitComponentDependency.SetUsedByUnit(const AValue: TUnitInfo);
begin
  if FUsedByUnit=AValue then exit;
  if (AValue<>nil) and (FRequiresUnit=AValue) then
    raise Exception.Create('TUnitComponentDependency.SetUsedByUnit inconsistency');
  if FUsedByUnit<>nil then
    RemoveFromList(FUsedByUnit.FFirstRequiredComponent,ucdlRequires);
  FUsedByUnit:=AValue;
  if FUsedByUnit<>nil then
    AddToList(FUsedByUnit.FFirstRequiredComponent,ucdlRequires);
end;

constructor TUnitComponentDependency.Create;
begin

end;

destructor TUnitComponentDependency.Destroy;
begin
  RequiresUnit:=nil;
  UsedByUnit:=nil;
  ClearComponentProperties;
  inherited Destroy;
end;

procedure TUnitComponentDependency.ClearComponentProperties;
var
  i: Integer;
begin
  if FCompProps=nil then exit;
  for i:=0 to FCompProps.Count-1 do TObject(FCompProps[i]).Free;
  FreeAndNil(FCompProps);
end;

function TUnitComponentDependency.NextUsedByDependency: TUnitComponentDependency;
begin
  Result:=NextDependency[ucdlUsedBy];
end;

function TUnitComponentDependency.PrevUsedByDependency: TUnitComponentDependency;
begin
  Result:=PrevDependency[ucdlUsedBy];
end;

function TUnitComponentDependency.NextRequiresDependency: TUnitComponentDependency;
begin
  Result:=NextDependency[ucdlRequires];
end;

function TUnitComponentDependency.PrevRequiresDependency: TUnitComponentDependency;
begin
  Result:=PrevDependency[ucdlRequires];
end;

procedure TUnitComponentDependency.AddToList(
  var FirstDependency: TUnitComponentDependency;
  ListType: TUnitCompDependencyList);
begin
  NextDependency[ListType]:=FirstDependency;
  FirstDependency:=Self;
  PrevDependency[ListType]:=nil;
  if NextDependency[ListType]<>nil then
    NextDependency[ListType].PrevDependency[ListType]:=Self;
end;

procedure TUnitComponentDependency.RemoveFromList(
  var FirstDependency: TUnitComponentDependency;
  ListType: TUnitCompDependencyList);
begin
  if FirstDependency=Self then FirstDependency:=NextDependency[ListType];
  if NextDependency[ListType]<>nil then
    NextDependency[ListType].PrevDependency[ListType]:=PrevDependency[ListType];
  if PrevDependency[ListType]<>nil then
    PrevDependency[ListType].NextDependency[ListType]:=NextDependency[ListType];
  NextDependency[ListType]:=nil;
  PrevDependency[ListType]:=nil;
end;

function TUnitComponentDependency.FindUsedByPropPath(
  const UsedByPropPath: string): TUCDComponentProperty;
var
  i: Integer;
begin
  if FCompProps=nil then exit(nil);
  for i:=FCompProps.Count-1 downto 0 do begin
    Result:=CompProps[i];
    if SysUtils.CompareText(Result.UsedByPropPath,UsedByPropPath)=0 then exit;
  end;
  Result:=nil;
end;

function TUnitComponentDependency.SetUsedByPropPath(const UsedByPropPath,
  RequiresPropPath: string): TUCDComponentProperty;
begin
  //DebugLn(['TUnitComponentDependency.SetUsedByPropPath ',UsedByPropPath,'=',RequiresPropPath]);
  if (not (ucdtOldProperty in FTypes)) then
    raise Exception.Create('TUnitComponentDependency.SetUsedByPropPath inconsistency');
  Result:=FindUsedByPropPath(UsedByPropPath);
  if Result=nil then begin
    if FCompProps=nil then
      FCompProps:=TFPList.Create;
    Result:=TUCDComponentProperty.Create(UsedByPropPath,RequiresPropPath);
    FCompProps.Add(Result);
  end else begin
    Result.UsedByPropPath:=UsedByPropPath;// update case
    Result.RequiresPropPath:=RequiresPropPath;
  end;
end;

function TUnitComponentDependency.CreatePropPath(AComponent: TComponent;
  const PropName: string): string;
begin
  Result:=PropName;
  while AComponent<>nil do begin
    if Result<>'' then
      Result:='.'+Result;
    Result:=AComponent.Name+Result;
    AComponent:=AComponent.Owner;
  end;
end;

{ TUCDComponentProperty }

constructor TUCDComponentProperty.Create(const SrcPath, DestPath: string);
begin
  UsedByPropPath:=SrcPath;
  RequiresPropPath:=DestPath;
end;

{ TProjectBuildMode }

function TProjectBuildMode.GetLazCompilerOptions: TLazCompilerOptions;
begin
  Result:=FCompilerOptions;
end;

constructor TProjectBuildMode.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCompilerOptions:=TProjectCompilerOptions.Create(LazProject);
  FCompilerOptions.AddOnChangedHandler(@OnItemChanged);
  FCompilerOptions.FBuildMode:=Self;
end;

destructor TProjectBuildMode.Destroy;
begin
  FreeAndNil(FCompilerOptions);
  inherited Destroy;
end;

function TProjectBuildMode.LazProject: TProject;
begin
  if Owner is TProjectBuildModes then
    Result:=TProjectBuildModes(Owner).LazProject
  else
    Result:=Nil;
end;

procedure TProjectBuildMode.Clear;
begin
  CompilerOptions.Clear;
end;

function TProjectBuildMode.Equals(Src: TProjectBuildMode): boolean;
begin
  Result:=CompilerOptions.IsEqual(Src.CompilerOptions);
end;

function TProjectBuildMode.CreateDiff(Other: TProjectBuildMode;
  Tool: TCompilerDiffTool): boolean;
begin
  // Note: if there is a Tool all steps must be evaluated, if not exit on first diff
  //if Tool<>nil then debugln(['TProjectBuildMode.CreateDiff ']);
  Result:=CompilerOptions.CreateDiff(Other.CompilerOptions,Tool);
  if (Tool=nil) and Result then exit;
end;

procedure TProjectBuildMode.Assign(Src: TProjectBuildMode);
begin
  if Equals(Src) then exit;
  InSession:=Src.InSession;
  CompilerOptions.Assign(Src.CompilerOptions);
end;

procedure TProjectBuildMode.LoadFromXMLConfig(XMLConfig: TXMLConfig;
  const Path: string);
begin
  FIdentifier:=XMLConfig.GetValue('Identifier','');
  FCompilerOptions.LoadFromXMLConfig(XMLConfig,Path+'CompilerOptions/');
end;

procedure TProjectBuildMode.SaveMacroValuesAtOldPlace(XMLConfig: TXMLConfig; const Path: string);
var
  Cnt: Integer;
  Modes: TProjectBuildModes;
begin
  // for older IDE (<1.1) save the macros at the old place
  Assert(Assigned(Owner), 'SaveMacroValuesAtOldPlace: Owner not assigned.');
  Modes := Owner as TProjectBuildModes;
  Cnt:=Modes.SessionMatrixOptions.SaveAtOldXMLConfig(XMLConfig, Path, Identifier);
  Cnt+=Modes.SharedMatrixOptions.SaveAtOldXMLConfig(XMLConfig, Path, Identifier);
  XMLConfig.SetDeleteValue(Path+'Count',Cnt,0);
end;

procedure TProjectBuildMode.SaveToXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; IsDefault, ALegacyList: Boolean; var Cnt: integer);
var
  SubPath: String;
begin
  SubPath:=Path+'BuildModes/'+XMLConfig.GetListItemXPath('Item', Cnt, ALegacyList, True)+'/';
  inc(Cnt);
  XMLConfig.SetDeleteValue(SubPath+'Name',Identifier,'');
  if IsDefault then
    XMLConfig.SetDeleteValue(SubPath+'Default',True,false)
  else begin
    SaveMacroValuesAtOldPlace(XMLConfig, SubPath+'MacroValues/');
    CompilerOptions.SaveToXMLConfig(XMLConfig,SubPath+'CompilerOptions/');
  end;
end;

function TProjectBuildMode.GetCaption: string;
var
  i: Integer;
begin
  Result:=Identifier;
  for i:=length(Result) downto 1 do
    if Result[i] in ['&',#0..#31,#127] then
      System.Delete(Result,i,1);
  if Result<>'' then exit;
  i:=GetIndex;
  if i>=0 then
    Result:='['+IntToStr(i)+']';
end;

function TProjectBuildMode.GetIndex: integer;
begin
  if LazProject<>nil then
    Result:=LazProject.BuildModes.IndexOf(Self)
  else
    Result:=-1;
end;

{ TProjectBuildModes }

function TProjectBuildModes.GetItems(Index: integer): TProjectBuildMode;
begin
  Result:=TProjectBuildMode(fItems[Index]);
end;

function TProjectBuildModes.GetModified: boolean;
begin
  Result:=fSavedChangeStamp<>FChangeStamp;
end;

procedure TProjectBuildModes.OnItemChanged(Sender: TObject);
begin
  {$IFDEF VerboseIDEModified}
  debugln(['TProjectBuildModes.OnItemChanged ',DbgSName(Sender)]);
  {$ENDIF}
  IncreaseChangeStamp;
end;

procedure TProjectBuildModes.SetModified(const AValue: boolean);
var
  i: Integer;
begin
  if AValue then
    IncreaseChangeStamp
  else begin
    for i:=0 to Count-1 do
      Items[i].Modified:=false;
    SharedMatrixOptions.Modified:=false;
    SessionMatrixOptions.Modified:=false;
    fSavedChangeStamp:=FChangeStamp;
  end;
end;

constructor TProjectBuildModes.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fChangedHandlers:=TMethodList.Create;
  fItems:=TFPList.Create;
  FChangeStamp:=CTInvalidChangeStamp;
  fSavedChangeStamp:=FChangeStamp;
  FSharedMatrixOptions:=TBuildMatrixOptions.Create;
  FSharedMatrixOptions.OnChanged:=@OnItemChanged;
  FSessionMatrixOptions:=TBuildMatrixOptions.Create;
  FSessionMatrixOptions.OnChanged:=@OnItemChanged;
  FManyBuildModes:=TStringList.Create;
end;

destructor TProjectBuildModes.Destroy;
begin
  FreeAndNil(fChangedHandlers);
  Clear;
  FreeAndNil(FManyBuildModes);
  FreeAndNil(FSharedMatrixOptions);
  FreeAndNil(FSessionMatrixOptions);
  FreeAndNil(fItems);
  inherited Destroy;
end;

procedure TProjectBuildModes.Clear;
begin
  while Count>0 do
    Delete(Count-1);
  SharedMatrixOptions.Clear;
  SessionMatrixOptions.Clear;
  //fChangedHandlers.Clear;
end;

function TProjectBuildModes.IsEqual(OtherModes: TProjectBuildModes): boolean;
var
  i: Integer;
begin
  Result:=true;
  if OtherModes.Count<>Count then exit;
  for i:=0 to Count-1 do
    if not Items[i].Equals(OtherModes[i]) then exit;
  if not SharedMatrixOptions.Equals(OtherModes.SharedMatrixOptions) then exit;
  if not SessionMatrixOptions.Equals(OtherModes.SessionMatrixOptions) then exit;
  Result:=false;
end;

procedure TProjectBuildModes.Assign(Source: TPersistent; WithModified: boolean);
var
  OtherModes: TProjectBuildModes;
  i: Integer;
  CurMode: TProjectBuildMode;
begin
  if Source is TProjectBuildModes then begin
    FAssigning:=True;
    OtherModes:=TProjectBuildModes(Source);
    Clear;
    for i:=0 to OtherModes.Count-1 do
    begin
      CurMode:=Add(OtherModes[i].Identifier);
      CurMode.Assign(OtherModes[i]);
      if WithModified then
        CurMode.Modified:=OtherModes[i].Modified;
    end;
    SharedMatrixOptions.Assign(OtherModes.SharedMatrixOptions);
    SessionMatrixOptions.Assign(OtherModes.SessionMatrixOptions);
    ManyBuildModes.Assign(OtherModes.ManyBuildModes);
    ChangedHandlers.Assign(OtherModes.ChangedHandlers);
    if WithModified then
      Modified:=OtherModes.Modified;
    FAssigning:=False;
  end else
    inherited Assign(Source);
end;

procedure TProjectBuildModes.Delete(Index: integer);
var
  Item: TProjectBuildMode;
begin
  Item:=Items[Index];
  fItems.Delete(Index);
  Item.Free;
  {$IFDEF VerboseIDEModified}
  debugln(['TProjectBuildModes.Delete ']);
  {$ENDIF}
  IncreaseChangeStamp;
end;

function TProjectBuildModes.IndexOf(Identifier: string): integer;
begin
  Result:=Count-1;
  while (Result>=0)
  and (SysUtils.CompareText(Identifier,Items[Result].Identifier)<>0) do
    dec(Result);
end;

function TProjectBuildModes.IndexOf(aMode: TProjectBuildMode): integer;
begin
  Result:=fItems.IndexOf(aMode);
end;

function TProjectBuildModes.Find(Identifier: string): TProjectBuildMode;
var
  i: LongInt;
begin
  i:=IndexOf(Identifier);
  if i>=0 then
    Result:=Items[i]
  else
    Result:=nil;
end;

function TProjectBuildModes.Add(Identifier: string): TProjectBuildMode;
begin
  Result:=TProjectBuildMode.Create(Self);
  Result.FIdentifier:=Identifier;
  if LazProject<>nil then
    Result.CompilerOptions.BaseDirectory:=LazProject.Directory;
  Result.AddOnChangedHandler(@OnItemChanged);
  fItems.Add(Result);
end;

procedure TProjectBuildModes.Move(FromIndex, ToIndex: integer);
begin
  fItems.Move(FromIndex,ToIndex);
end;

function TProjectBuildModes.Count: integer;
begin
  Result:=fItems.Count;
end;

procedure TProjectBuildModes.IncreaseChangeStamp;
begin
  CTIncreaseChangeStamp(FChangeStamp);
  if fChangedHandlers<>nil then fChangedHandlers.CallNotifyEvents(Self);
end;

procedure TProjectBuildModes.AddOnChangedHandler(const Handler: TNotifyEvent);
begin
  fChangedHandlers.Add(TMethod(Handler));
end;

procedure TProjectBuildModes.RemoveOnChangedHandler(const Handler: TNotifyEvent);
begin
  fChangedHandlers.Remove(TMethod(Handler));
end;

function TProjectBuildModes.IsModified(InSession: boolean): boolean;
var
  i: Integer;
begin
  Result:=true;
  if InSession then begin
    if SessionMatrixOptions.Modified then exit;
  end else begin
    if SharedMatrixOptions.Modified then exit;
  end;
  for i:=0 to Count-1 do
    if (Items[i].InSession=InSession) and Items[i].Modified then
      exit;
  Result:=false;
end;

function TProjectBuildModes.GetSessionModes: TStringList;
var
  i: Integer;
  BuildMode: TProjectBuildMode;
begin
  Result:=TStringList.Create;
  for i:=0 to Count-1 do begin
    BuildMode:=Items[i];
    if BuildMode.InSession then
      Result.Add(BuildMode.Identifier);
  end;
end;

function TProjectBuildModes.IsSessionMode(const ModeIdentifier: string): boolean;
var
  i: Integer;
  BuildMode: TProjectBuildMode;
begin
  for i:=0 to Count-1 do begin
    BuildMode:=Items[i];
    if SysUtils.CompareText(BuildMode.Identifier,ModeIdentifier)=0 then
      exit(BuildMode.InSession);
  end;
  Result:=false;
end;

function TProjectBuildModes.IsSharedMode(const ModeIdentifier: string): boolean;
var
  i: Integer;
  BuildMode: TProjectBuildMode;
begin
  for i:=0 to Count-1 do begin
    BuildMode:=Items[i];
    if SysUtils.CompareText(BuildMode.Identifier,ModeIdentifier)=0 then
      exit(not BuildMode.InSession);
  end;
  Result:=false;
end;

procedure TProjectBuildModes.RenameMatrixMode(const OldName, NewName: string);
begin
  SharedMatrixOptions.RenameMode(OldName,NewName);
  SessionMatrixOptions.RenameMode(OldName,NewName);
end;

function TProjectBuildModes.CreateExtraModes(aCurMode: TProjectBuildMode): TProjectBuildMode;
// Create Debug and Release buildmodes. Return the created debug mode.
// Params: aCurMode - existing mode to copy settings from.

  procedure AssignAndSetBooleans(aMode: TProjectBuildMode; IsDebug: Boolean);
  begin
    if Assigned(aCurMode) then
      aMode.Assign(aCurMode);              // clone from currently selected mode
    with aMode.CompilerOptions do
    begin
      // Smart linking
      SmartLinkUnit:=not IsDebug;
      LinkSmart:=not IsDebug;
      // Checks
      IOChecks:=IsDebug;
      RangeChecks:=IsDebug;
      OverflowChecks:=IsDebug;
      StackChecks:=IsDebug;
      IncludeAssertionCode:=IsDebug;
      VerifyObjMethodCall:=IsDebug;
      // Debug flags
      GenerateDebugInfo:=IsDebug;
      UseExternalDbgSyms:=IsDebug;
      UseHeaptrc:=IsDebug;
      TrashVariables:=IsDebug;
    end;
  end;

var
  RelMode: TProjectBuildMode;
begin
  // Create Debug mode
  Result:=Add(DebugModeName);
  AssignAndSetBooleans(Result, True);
  Result.CompilerOptions.OptimizationLevel:=1;    // Optimization
  Result.CompilerOptions.DebugInfoType:=dsDwarf3; // Debug
  // Create Release mode
  RelMode:=Add(ReleaseModeName);
  AssignAndSetBooleans(RelMode, False);
  RelMode.CompilerOptions.OptimizationLevel:=3; // Slow but safe optimization, -O4 is dangerous
  RelMode.CompilerOptions.DebugInfoType:=dsAuto;  // No Debug
end;

// Methods for LoadFromXMLConfig

procedure TProjectBuildModes.AddMatrixMacro(const MacroName, MacroValue, ModeIdentifier: string;
  InSession: boolean);
var
  MatrixOptions: TBuildMatrixOptions;
  MatrixOption: TBuildMatrixOption;
begin
  MatrixOption:=SharedMatrixOptions.FindMacro(MacroName,MacroValue);
  if MatrixOption=nil then
    MatrixOption:=SessionMatrixOptions.FindMacro(MacroName,MacroValue);
  if MatrixOption<>nil then begin
    // Macro already exists => enable mode for this macro
    MatrixOption.EnableMode(ModeIdentifier);
  end else begin
    // Macro does not yet exist => create
    if InSession then
      MatrixOptions:=SessionMatrixOptions
    else
      MatrixOptions:=SharedMatrixOptions;
    MatrixOption:=MatrixOptions.Add(bmotIDEMacro,'*');
    MatrixOption.MacroName:=MacroName;
    MatrixOption.Value:=MacroValue;
    MatrixOption.Modes:=ModeIdentifier;
  end;
end;

procedure TProjectBuildModes.LoadSessionEnabledNonSessionMatrixOptions(const Path: string);
var
  i, Cnt: integer;
  SubPath: String;
  ModeID, OptionID: String;
begin
  // disable all matrix options in session modes
  if FGlobalMatrixOptions<>nil then
    FGlobalMatrixOptions.DisableModes(@IsSessionMode);
  SharedMatrixOptions.DisableModes(@IsSessionMode);
  // load
  Cnt:=FXMLConfig.GetValue(Path+'Count',0);
  for i:=1 to Cnt do begin
    SubPath:=Path+'Item'+IntToStr(i)+'/';
    ModeID:=FXMLConfig.GetValue(SubPath+'Mode','');
    if (ModeID='') or (not IsSessionMode(ModeID)) then begin
      debugln(['LoadSessionEnabledNonSessionMatrixOptions not a session Mode="',dbgstr(ModeID),'" at ',SubPath]);
      continue;
    end;
    OptionID:=FXMLConfig.GetValue(SubPath+'Option','');
    if OptionID='' then begin
      debugln(['LoadSessionEnabledNonSessionMatrixOptions invalid option at ',SubPath]);
      continue;
    end;
    if Assigned(FGlobalMatrixOptions) then
      FGlobalMatrixOptions.EnableModeIfOptionFound(ModeID, OptionID);
    if Assigned(SharedMatrixOptions) then
      SharedMatrixOptions.EnableModeIfOptionFound(ModeID, OptionID);
  end;
end;

procedure TProjectBuildModes.LoadOtherCompilerOpts(const Path: string;
  FromIndex, ToIndex: Integer; InSession: boolean);
// Iterate rest of the modes.
var
  i: Integer;
  Ident, SubPath: String;
  CurMode: TProjectBuildMode;
  LegacyList: Boolean;
begin
  LegacyList := FXMLConfig.IsLegacyList(Path);
  for i:=FromIndex to ToIndex do
  begin
    SubPath:=Path+FXMLConfig.GetListItemXPath('Item', i-1, LegacyList, True)+'/';
    Ident:=FXMLConfig.GetValue(SubPath+'Name','');
    CurMode:=Add(Ident);                     // add another mode
    CurMode.InSession:=InSession;
    CurMode.CompilerOptions.LoadFromXMLConfig(FXMLConfig, SubPath+'CompilerOptions/');
  end;
end;

procedure TProjectBuildModes.LoadMacroValues(const Path: string; CurMode: TProjectBuildMode);
var
  i, Cnt: Integer;
  SubPath, MacroName, MacroValue: String;
begin
  // load macro values of old IDE (<1.1)
  Cnt:=FXMLConfig.GetValue(Path+'Count',0);
  //debugln(['LoadMacroValues Cnt=',Cnt]);
  for i:=1 to Cnt do begin
    SubPath:=Path+'Macro'+IntToStr(i)+'/';
    MacroName:=FXMLConfig.GetValue(SubPath+'Name','');
    if not IsValidIdent(MacroName) then continue;
    MacroValue:=FXMLConfig.GetValue(SubPath+'Value','');
    //debugln(['LoadMacroValues Mode="',CurMode.Identifier,'" ',MacroName,'="',MacroValue,'" session=',CurMode.InSession]);
    AddMatrixMacro(MacroName,MacroValue,CurMode.Identifier,CurMode.InSession);
  end;
end;

procedure TProjectBuildModes.LoadAllMacroValues(const Path: string; Cnt: Integer);
var
  i: Integer;
  SubPath: String;
  IsLegacyList: Boolean;
begin
  // First default mode.
  LoadMacroValues(Path+'MacroValues/', Items[0]);
  IsLegacyList := FXMLConfig.IsLegacyList(Path+'BuildModes/');
  // Iterate rest of the modes.
  for i:=2 to Cnt do
  begin
    SubPath:=Path+'BuildModes/'+FXMLConfig.GetListItemXPath('Item', i-1, IsLegacyList, True);
    LoadMacroValues(SubPath+'MacroValues/', Items[i-1]);
  end;
end;

procedure TProjectBuildModes.LoadOldFormat(const Path: string);
var
  Ident, CompOptsPath, MacroValsPath: String;
  CurMode: TProjectBuildMode;
begin
  // no build modes => an old file format
  CompOptsPath:='CompilerOptions/';
  // due to a bug in an old version, the XML path can be 'CompilerOptions/' or ''
  if (LazProject.FFileVersion<3)
  and (FXMLConfig.GetValue('SearchPaths/CompilerPath/Value','')<>'') then
    CompOptsPath:='';
  MacroValsPath:=Path+'MacroValues/';
  CurMode:=Items[0];
  LoadMacroValues(MacroValsPath,CurMode);
  if FXMLConfig.GetValue(CompOptsPath+'Version/Value', 0)<10 then begin
    // LCLWidgetType was not a macro but a property of its own
    Ident := FXMLConfig.GetValue(CompOptsPath+'LCLWidgetType/Value', '');
    if (Ident<>'') and (SysUtils.CompareText(Ident,'default')<>0) then
      AddMatrixMacro('LCLWidgetType',Ident,'default',false);
  end;
  CurMode.CompilerOptions.LoadFromXMLConfig(FXMLConfig,CompOptsPath);
end;

procedure TProjectBuildModes.LoadActiveBuildMode(const Path: string);
var
  CurMode: TProjectBuildMode;
begin
  CurMode:=Find(FXMLConfig.GetValue(Path+'BuildModes/Active','default'));
  if CurMode=nil then
    CurMode:=Items[0];
  LazProject.ActiveBuildMode:=CurMode;
  // Many BuildModes selection, a comma separated list.
  FManyBuildModes.CommaText:=FXMLConfig.GetValue(Path+'ManyBuildModesSelection/Value','');
end;

procedure TProjectBuildModes.LoadProjOptsFromXMLConfig(XMLConfig: TXMLConfig; const Path: string);
// Load for project
var
  Cnt: Integer;
  IsLegacyList: Boolean;
begin
  FXMLConfig := XMLConfig;

  IsLegacyList := FXMLConfig.IsLegacyList(Path+'BuildModes/');
  Cnt:=FXMLConfig.GetListItemCount(Path+'BuildModes/', 'Item', IsLegacyList);
  if Cnt>0 then begin
    // Project default mode is stored at the old XML path for backward compatibility.
    // Testing the 'Default' XML attribute is not needed because the first mode
    // is always default.
    Items[0].Identifier:=FXMLConfig.GetValue(Path+'BuildModes/'+XMLConfig.GetListItemXPath('Item', 0, IsLegacyList, True)+'/Name', '');
    Items[0].CompilerOptions.LoadFromXMLConfig(FXMLConfig, 'CompilerOptions/');
    LoadOtherCompilerOpts(Path+'BuildModes/', 2, Cnt, False);
    LoadAllMacroValues(Path+'MacroValues/', Cnt);
  end
  else
    LoadOldFormat(Path);

  LoadActiveBuildMode(Path);
end;

procedure TProjectBuildModes.LoadSessionFromXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; LoadAllOptions: boolean);
// Load for session
var
  Cnt: Integer;
  IsLegacyList: Boolean;
begin
  FXMLConfig := XMLConfig;

  if LoadAllOptions then
    // load matrix options
    SessionMatrixOptions.LoadFromXMLConfig(FXMLConfig, Path+'BuildModes/SessionMatrixOptions/');

  IsLegacyList := FXMLConfig.IsLegacyList(Path+'BuildModes/');
  Cnt:=FXMLConfig.GetListItemCount(Path+'BuildModes/', 'Item', IsLegacyList);
  if Cnt>0 then begin
    // Add a new mode for session compiler options.
    LoadOtherCompilerOpts(Path+'BuildModes/', 1, Cnt, True);
    LoadAllMacroValues(Path+'MacroValues/', Cnt);
  end;

  if LoadAllOptions then
    // load what matrix options are enabled in session build modes
    LoadSessionEnabledNonSessionMatrixOptions(Path+'BuildModes/SessionEnabledMatrixOptions/');

  LoadActiveBuildMode(Path);
end;

// Methods for SaveToXMLConfig

procedure TProjectBuildModes.SaveSessionData(const Path: string);
var
  SubPath: String;
  i, Cnt: Integer;
begin
  // Many BuildModes selection, a comma separated list.
  FXMLConfig.SetDeleteValue(Path+'ManyBuildModesSelection/Value', FManyBuildModes.CommaText, '');
  // save what mode is currently active in the session
  FXMLConfig.SetDeleteValue(Path+'BuildModes/Active',
                              LazProject.ActiveBuildMode.Identifier,'default');
  // save matrix options of session
  SessionMatrixOptions.SaveToXMLConfig(FXMLConfig, Path+'BuildModes/SessionMatrixOptions/',nil);

  // save what matrix options are enabled in session build modes
  Cnt:=0;
  SubPath:=Path+'BuildModes/SessionEnabledMatrixOptions/';
  for i:=0 to Count-1 do
    if Items[i].InSession then
      SharedMatrixOptions.SaveSessionEnabled(FXMLConfig, SubPath, Items[i].Identifier, Cnt);
  if Assigned(FGlobalMatrixOptions) then
    for i:=0 to Count-1 do
      if Items[i].InSession then
        FGlobalMatrixOptions.SaveSessionEnabled(FXMLConfig, SubPath, Items[i].Identifier, Cnt);
  FXMLConfig.SetDeleteValue(SubPath+'Count',Cnt,0);
end;

procedure TProjectBuildModes.SaveSharedMatrixOptions(const Path: string);
begin
  SharedMatrixOptions.SaveToXMLConfig(FXMLConfig, Path+'BuildModes/SharedMatrixOptions/',@IsSharedMode);
end;

function TProjectBuildModes.GetLazBuildModes(Index: integer): TLazProjectBuildMode;
begin
  Result:=TLazProjectBuildMode(fItems[Index]);
end;

// SaveToXMLConfig itself
procedure TProjectBuildModes.SaveProjOptsToXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; SaveSession, ALegacyList: boolean);
var
  i, Cnt: Integer;
begin
  FXMLConfig := XMLConfig;
  // Save the default mode under an old xml path to let old IDEs open new projects
  // Note: the 0.9.29 reader already supports fetching the default build
  //       mode from the BuildModes, so in one or two releases we can switch
  //Items[0].SaveDefaultCompilerOpts(FXMLConfig, Path);
  Items[0].SaveMacroValuesAtOldPlace(XMLConfig,Path+'MacroValues/');
  Items[0].CompilerOptions.SaveToXMLConfig(XMLConfig,'CompilerOptions/'); // no Path!

  Cnt:=0;
  for i:=0 to Count-1 do
    if SaveSession or not Items[i].InSession then
      Items[i].SaveToXMLConfig(FXMLConfig, Path, i=0, ALegacyList, Cnt);
  FXMLConfig.SetListItemCount(Path+'BuildModes/',Cnt,ALegacyList);
end;

procedure TProjectBuildModes.SaveSessionOptsToXMLConfig(XMLConfig: TXMLConfig;
  const Path: string; SaveSession, ALegacyList: boolean);
var
  i, Cnt: Integer;
begin
  FXMLConfig := XMLConfig;
  Cnt:=0;
  for i:=0 to Count-1 do
    if Items[i].InSession and SaveSession then
      Items[i].SaveToXMLConfig(FXMLConfig, Path, false, ALegacyList, Cnt);
  FXMLConfig.SetListItemCount(Path+'BuildModes/',Cnt,ALegacyList);
end;


initialization
  RegisterIDEOptionsGroup(GroupProject, TProjectIDEOptions);
  RegisterIDEOptionsGroup(GroupCompiler, TProjectCompilerOptions);

end.


{ Copyright (C) 2006

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
 
  Author: Mattias Gaertner
}
unit IDEExternToolIntf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Laz_AVL_Tree,
  // LazUtils
  UTF8Process, LazFileUtils, LazFileCache, LazMethodList, LazLoggerBase,
  // BuildIntf
  BuildStrConsts;

const
  SubToolFPC = 'FPC';
  SubToolFPCPriority = 100;
  SubToolFPCLinker = 'FPCLinker';
  SubToolFPCRes = 'FPCRes';
  SubToolFPCWindRes = 'FPCWindRes';
  SubToolFPCAssembler = 'FPCAssembler';

  SubToolPas2js = 'Pas2JS';
  SubToolPas2jsPriority = 99;

  SubToolMake = 'make';
  SubToolMakePriority = 1000; // higher than FPC

  SubToolDefault = 'Show all'; // this parser simply writes all output to Messages window
  SubToolDefaultPriority = 0;

  AbortedExitCode = 12321;

  MsgAttrDiskFilename = 'DiskFile';

const
  IDEToolCompilePackage = 'Package';
  IDEToolCompileProject = 'Project'; // the active project
  IDEToolCompileIDE     = 'IDE';

type

  { TIDEExternalToolData
    When the IDE compiles a package or a project it creates an instance and sets
    TAbstractExternalTool.Data. }

  TIDEExternalToolData = class
  public
    Kind: string; // e.g. IDEToolCompilePackage or IDEToolCompileProject
    ModuleName: string; // e.g. the package name
    Filename: string; // e.g. the lpi or lpk filename
    Flags: TStrings;
    constructor Create(aKind, aModuleName, aFilename: string);
    destructor Destroy; override;
  end;

type
  TETShareStringEvent = procedure(var s: string) of object;

  TMessageLineUrgency = (
    mluNone,
    mluProgress,  // time and statistics about the run
    mluDebug,     // extreme verbosity, only useful for tool authors
    mluVerbose3,  // all infos
    mluVerbose2,  // almost all infos
    mluVerbose,   // extra infos
    mluHint,      // tool found something unusual
    mluNote,      // maybe wrong or unnecessary
    mluWarning,   // probably something is wrong
    mluImportant, // message has no urgency level, but should be shown
    mluError,     // tool could not finish, some tools can still continue
    mluFatal,     // critical error in input, tool had to abort
    mluPanic      // bug in tool
    );
  TMessageLineUrgencies = set of TMessageLineUrgency;
const
  MessageLineUrgencyNames: array[TMessageLineUrgency] of string = (
    'None',
    'Progress',
    'Debug',
    'Verbose',
    'Verbose',
    'Verbose',
    'Hint',
    'Note',
    'Warning',
    'Misc',
    'Error',
    'Fatal',
    'Panic'
    );

type
  TMessageLines = class;
  TAbstractExternalTool = class;

  TMessageLineFlag = (
    mlfStdErr,
    mlfLeftToken, // position is about left token, otherwise right token
    mlfFixed, // reason for the messages was resolved, e.g. quick fixed
    mlfHiddenByIDEDirective,
    mlfHiddenByIDEDirectiveValid,
    mlfTestBuildFile // Filename is not absolute, the test filename on disk is in Attributes[MsgAttrDiskFilename]
    );
  TMessageLineFlags = set of TMessageLineFlag;

  { TMessageLine }

  TMessageLine = packed class
  private
    // pointers
    FLines: TMessageLines; // owner
    FMsg: string; // fixed/improved message
    FFilename: string;
    FOriginalLine: string;
    FSubTool: string;
    FTranslatedMsg: string; // translated message
    fAttributes: TStrings;
    // native types
    FSubType: PtrUInt;
    FChangeStamp: int64;
    // special types
    FOutputIndex: integer;
    FColumn: integer;
    FIndex: integer; // 0-based, position in Lines.Items
    FLine: integer;
    FMsgID: integer;
    FUrgency: TMessageLineUrgency;
    FFlags: TMessageLineFlags;
    function GetAttribute(const Identifier: string): string;
    procedure SetAttribute(const Identifier: string; const AValue: string);
    procedure SetColumn(const AValue: integer);
    procedure SetFilename(AValue: string);
    procedure SetFlags(AValue: TMessageLineFlags);
    procedure SetLine(const AValue: integer);
    procedure SetMsg(AValue: string);
    procedure SetMsgID(AValue: integer);
    procedure SetSubTool(AValue: string);
    procedure SetSubType(AValue: PtrUInt);
    procedure SetTranslatedMsg(AValue: string);
    procedure SetUrgency(AValue: TMessageLineUrgency);
    procedure SortedSrcPosBind;
    procedure SortedSrcPosUnbind;
  protected
    procedure SetLines(AValue: TMessageLines);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Assign(Source: TMessageLine);
    function Equals(Obj: TObject): boolean; override;
    procedure Clear;
    function GetShortFilename: string; inline;
    function GetRelativeFilename: string;
    function GetFullFilename: string; inline;
    procedure ShareStrings(const ShareStringEvent: TETShareStringEvent); virtual;
    procedure SetSourcePosition(NewFilename: string; NewLine, NewColumn: integer);
    procedure IncreaseChangeStamp;
    procedure MarkFixed;
    function HasSourcePosition: boolean;
    procedure GetAttributes(List: TStrings);
    function GetToolData: TIDEExternalToolData; virtual;
  public
    property Index: integer read FIndex; // index in Lines (Note: Lines can have more or less items than the raw output has text lines)
    property Urgency: TMessageLineUrgency read FUrgency write SetUrgency;
    property SubTool: string read FSubTool write SetSubTool; // e.g. SubToolFPC, SubToolMake, SubToolFPCLinker
    property SubType: PtrUInt read FSubType write SetSubType; // depends on SubTool
    property Msg: string read FMsg write SetMsg;     // improved message without filename, line, column, setting it clears TranslatedMsg
    property MsgID: integer read FMsgID write SetMsgID;  // message id (depends on parser, e.g. fpc writes them with -vq, MsgID<>0 if valid)
    property TranslatedMsg: string read FTranslatedMsg write SetTranslatedMsg; // translated Msg, set this after Msg
    property Filename: string read FFilename write SetFilename; // full file name, relative if not found or not yet searched
    property Line: integer read FLine write SetLine; // valid if >0
    property Column: integer read FColumn write SetColumn; // valid if >0
    property Flags: TMessageLineFlags read FFlags write SetFlags;
    property Attribute[const Identifier: string]: string read GetAttribute write SetAttribute; default; // arbitrary attributes
    property ChangeStamp: int64 read FChangeStamp;
    property OutputIndex: integer read FOutputIndex; // index in raw Output, there can be only one message per output line
    property Lines: TMessageLines read FLines write SetLines;
    property OriginalLine: string read FOriginalLine;
  end;
  TMessageLineClass = class of TMessageLine;

  { TMessageLineEnumerator }

  TMessageLineEnumerator = class
  private
    FFilename: string;
    FMaxLine: integer;
    FMinLine: integer;
  protected
    FTree: TAvlTree;
    FCurrent: TAvlTreeNode;
    function GetCurrent: TMessageLine; inline;
  public
    constructor Create(Tree: TAvlTree; const aFilename: string;
      aMinLine, aMaxLine: integer);
    function GetEnumerator: TMessageLineEnumerator;
    function MoveNext: boolean;
    property Current: TMessageLine read GetCurrent;
    property Filename: string read FFilename;
    property MinLine: integer read FMinLine;
    property MaxLine: integer read FMaxLine;
  end;

  { TMessageLines }

  TETMarksFixedEvent = procedure(ListOfTMessageLine: TFPList) of object;

  TMessageLines = class
  private
    FChangeStamp: int64;
    FCritSec: TRTLCriticalSection;
    FBaseDirectory: string;
    fItems: TFPList; // list of TMessageLine
    FMessageLineClass: TMessageLineClass;
    FOnMarksFixed: TETMarksFixedEvent;
    FOwner: TObject;
    FSortedForSrcPos: TAvlTree; // tree of TMessageLine sorted for Filename, Line, Column, OutputIndex, Index
    FUpdateSortedSrcPos: boolean;
    fChangedHandler: TMethodList;
    fMarkedFixed: TAvlTree; // list of TMessageLine
    function GetItems(Index: integer): TMessageLine;
    procedure SetBaseDirectory(const AValue: string);
    procedure LineChanged(Line: TMessageLine);
  public
    UrgencyCounts: array[TMessageLineUrgency] of integer;
    constructor Create(aOwner: TObject; aMsgLineClass: TMessageLineClass);
    destructor Destroy; override;
    property Owner: TObject read FOwner;
    procedure EnterCriticalSection; // always use before access
    procedure LeaveCriticalSection;
    function Count: integer; inline;
    procedure Clear;
    property Items[Index: integer]: TMessageLine read GetItems; default;
    function GetLastLine: TMessageLine;
    property BaseDirectory: string read FBaseDirectory write SetBaseDirectory; // always trimmed and with trailing /
    function CreateLine(OutputIndex: integer): TMessageLine; // create, but do not yet add it
    procedure Add(MsgLine: TMessageLine);
    procedure Remove(MsgLine: TMessageLine);
    procedure Delete(MsgLine: TMessageLine);
    procedure MarkFixed(MsgLine: TMessageLine); // (main thread) request to add mlfFixed, will be applied in ApplyFixedMarks
    procedure ApplyFixedMarks; virtual; // (main thread) apply mlfFixed to all messages added via MarkFixed
    procedure FetchAll(SrcLines: TMessageLines);
    procedure SourceLinesInserted(Filename: string; Line, InsertedCount: integer);
    procedure SourceLinesDeleted(Filename: string; FirstLine, DeletedCount: integer);
    property MessageLineClass: TMessageLineClass read FMessageLineClass;
    property OnMarksFixed: TETMarksFixedEvent read FOnMarksFixed write FOnMarksFixed;
    property ChangeStamp: int64 read FChangeStamp;
    procedure IncreaseChangeStamp; inline;
    function IndexOfOutputIndex(OutputIndex: integer): integer;
    function EnumerateFile(aFilename: string;
      MinLine: integer = 0; MaxLine: integer = High(integer)): TMessageLineEnumerator;
    property UpdateSortedSrcPos: boolean // disable this while updating many Filename,Line,Col without changes the order
      read FUpdateSortedSrcPos write FUpdateSortedSrcPos;
    procedure AddChangedHandler(const OnLineChanged: TNotifyEvent;
      AsFirst: boolean = false);
    procedure RemoveChangedHandler(const OnLineChanged: TNotifyEvent);
    procedure ConsistencyCheck;
  end;

  { The output is parsed in chunks (multiple lines) at a time.
    First every output line is passed to each parser via ReadLine.
    After the whole chunk was processed via ReadLine, each parser is called
    with ImproveMessages up to three times. During ImproveMessages the Tool
    is locked via its critical section.
    After ImproveMessages the chunk is passed to the Views.
  }
  TExtToolParserSyncPhase = (
    etpspAfterReadLine,  { (worker thread) after lines were created by parsers
      via ReadLine and added to Tool.WorkerMessages. In this phase parsers can
      look what other parsers have created and/or to decide if they need some
      data from the IDE (NeedSynchronize:=true) }
    etpspSynchronized,   { (main thread) parsers can collect data from the IDE.
                          If the data need processing set NeedAfterSync:=true }
    etpspAfterSync       { (worker thread) use the collected IDE data }
    );
  TExtToolParserSyncPhases = set of TExtToolParserSyncPhase;

  { TExtToolParser
    Read the output of a tool, for example the output of the Free Pascal compiler.
    It does not filter. Some parsers can work together, for example make and fpc.
    Usage: Tool.AddParsers('SubTool') or Tool.AddParser(ParseClass);
    }
  TExtToolParser = class(TComponent)
  private
    FNeedAfterSync: boolean;
    FNeedSynchronize: boolean;
    FTool: TAbstractExternalTool;
  public
    destructor Destroy; override; // (main thread)
    procedure Init; virtual; // called after macros resolved, before starting thread (main thread)
    procedure InitReading; virtual; // called if process started, before first line (worker thread)
    procedure Done; virtual; // called after process stopped (worker thread)
    procedure ReadLine(Line: string; OutputIndex: integer; IsStdErr: boolean; var Handled: boolean); virtual; abstract; // (worker thread)
    function CreateMsgLine(OutputIndex: integer): TMessageLine; // (worker thread)
    procedure AddMsgLine(MsgLine: TMessageLine); virtual; // (worker thread)
    property Tool: TAbstractExternalTool read FTool;// set when added to a tool
    property NeedSynchronize: boolean read FNeedSynchronize write FNeedSynchronize; // set this in ImproveMessages phase etpspAfterReadLine
    property NeedAfterSync: boolean read FNeedAfterSync write FNeedAfterSync; // set this in ImproveMessages phase etpspSynchronized
    procedure ImproveMessages({%H-}aPhase: TExtToolParserSyncPhase); virtual; // Tool.WorkerMessages, Tool is in Critical section
    procedure ConsistencyCheck; virtual;
    class function GetParserName: string; virtual;
    class function GetLocalizedParserName: string; virtual;
    class function IsSubTool(const SubTool: string): boolean; deprecated 'use CanParseSubTool';
    class function CanParseSubTool(const SubTool: string): boolean; virtual;
    class function GetMsgPattern({%H-}SubTool: string; {%H-}MsgID: integer;
      out Urgency: TMessageLineUrgency): string; virtual;
    class function GetMsgHint({%H-}SubTool: string; {%H-}MsgID: integer): string; virtual;
    class function GetMsgParser(Msg: TMessageLine; ParserClass: TClass): TExtToolParser;
    class function DefaultSubTool: string; virtual; abstract;
    class function Priority: integer; virtual; // higher comes first
  end;
  TExtToolParserClass = class of TExtToolParser;

  { TFPCParser - standard parser for Free Pascal messages, implemented by IDE }

  TFPCParser = class(TExtToolParser)
  private
    FHideHintsSenderNotUsed: boolean;
    FHideHintsUnitNotUsedInMainSource: boolean;
    FShowLinesCompiled: boolean;
  protected
    FFilesToIgnoreUnitNotUsed: TStrings;
  public
    class function GetFPCParser(Msg: TMessageLine): TFPCParser;
    function GetFPCMsgIDPattern(MsgID: integer): string; virtual; abstract;
    class function MsgLineIsId(Msg: TMessageLine; MsgId: integer;
      out Value1, Value2: string): boolean; virtual; abstract;
    class function GetFPCMsgPattern(Msg: TMessageLine): string; virtual; abstract;
    class function GetFPCMsgValue1(Msg: TMessageLine): string; virtual; abstract;
    class function GetFPCMsgValues(Msg: TMessageLine; out Value1, Value2: string): boolean; virtual; abstract;
    property FilesToIgnoreUnitNotUsed: TStrings read FFilesToIgnoreUnitNotUsed
                                                write FFilesToIgnoreUnitNotUsed;
    property ShowLinesCompiled: boolean read FShowLinesCompiled
                                     write FShowLinesCompiled default false;
    property HideHintsSenderNotUsed: boolean read FHideHintsSenderNotUsed
                                     write FHideHintsSenderNotUsed default true;
    property HideHintsUnitNotUsedInMainSource: boolean
                           read FHideHintsUnitNotUsedInMainSource
                           write FHideHintsUnitNotUsedInMainSource default true;
  end;
  TFPCParserClass = class of TFPCParser;
var
  IDEFPCParser: TFPCParserClass = nil;
  IDEPas2jsParser: TFPCParserClass = nil;

type
  { TMakeParser - standard parser for 'make' messages, implemented by IDE }

  TMakeParser = class(TExtToolParser)
  end;

  { TDefaultParser - simple parser for simple text output, no filtering }

  TDefaultParser = class(TExtToolParser)
  public
    procedure ReadLine(Line: string; OutputIndex: integer; IsStdErr: boolean;
      var Handled: boolean); override;
    class function DefaultSubTool: string; override;
    class function GetLocalizedParserName: string; override;
    class function Priority: integer; override;
  end;

const
  DefaultETViewMinUrgency = mluHint;
type
  { TExtToolView
    Implemented by the IDE.
    When a tool with a scanner but no View is started the IDE automatically
    creates a View.
    You can create a View with IDEMessagesWindow.CreateView(Title) }

  TExtToolView = class(TComponent)
  private
    FCaption: string;
    FExitCode: integer;
    FExitStatus: integer;
    FLines: TMessageLines;
    FMinUrgency: TMessageLineUrgency;
    FOnChanged: TNotifyEvent;
    FPendingLines: TMessageLines;
    FPendingProgressLine: TMessageLine;
    FProgressLine: TMessageLine;
    FRunning: boolean;
    FSummaryMsg: string;
    FTool: TAbstractExternalTool;
  protected
    FLastWorkerMessageCount: integer;
    FMessageLineClass: TMessageLineClass;
    procedure CreateLines; virtual;
    procedure FetchAllPending; virtual; // (main thread)
    procedure ToolExited; virtual;      // (main thread) called by InputClosed
    procedure QueueAsyncOnChanged; virtual;  // (worker thread)
    procedure RemoveAsyncOnChanged; virtual; // (main or worker thread)
  public
    constructor Create(AOwner: TComponent); override; // (main thread)
    destructor Destroy; override; // (main thread)
    procedure ProcessNewMessages({%H-}AThread: TThread); virtual; // (worker thread, Tool is in Critical section)
    procedure ClearLines; // (main thread)
    function ApplyPending: boolean; virtual; // true if something changed (main thread)
    procedure InputClosed; virtual; // called by Tool when source closed (main thread)
    function LineFits(Line: TMessageLine): boolean; virtual; // called by ProcessNewMessages (worker thread)
    procedure EnterCriticalSection; // Note: when using Tool and View: always lock Tool before View
    procedure LeaveCriticalSection;
    procedure ConsistencyCheck; virtual;
  public
    property Running: boolean read FRunning write FRunning;
    property SummaryMsg: string read FSummaryMsg write FSummaryMsg;
    property Tool: TAbstractExternalTool read FTool;
    property Caption: string read FCaption write FCaption;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged; // called in main thread
    property ExitCode: integer read FExitCode write FExitCode;
    property ExitStatus: integer read FExitStatus write FExitStatus;
    property MinUrgency: TMessageLineUrgency read FMinUrgency write FMinUrgency default DefaultETViewMinUrgency; // hide messages below this
    property MessageLineClass: TMessageLineClass read FMessageLineClass;
    function HasFinished: boolean; virtual; // not running, no pending messages
  public
    // needs critical section
    property PendingLines: TMessageLines read FPendingLines write FPendingLines;
    property PendingProgressLine: TMessageLine read FPendingProgressLine write FPendingProgressLine;
    property LastWorkerMessageCount: integer read FLastWorkerMessageCount;
  public
    // only main thread
    property Lines: TMessageLines read FLines;
    property ProgressLine: TMessageLine read FProgressLine; // valid if ProgressLine.Msg<>''
  end;
  TExtToolViewClass = class of TExtToolView;

  TExternalToolStage = (
    etsInit,            // just created, set your parameters, then call Execute
    etsInitializing,    // set in Execute, during resolving macros
    etsWaitingForStart, // waiting for a process slot
    etsStarting,        // creating the thread and process
    etsRunning,         // process started
    etsWaitingForStop,  // waiting for process to stop
    etsStopped,         // process has stopped
    etsDestroying       // during destructor
    );
  TExternalToolStages = set of TExternalToolStage;

  TExternalToolNewOutputEvent = procedure(Sender: TObject;
                                          FirstNewMsgLine: integer) of object;

  TExternalToolHandler = (
    ethNewOutput,
    ethStopped
    );

  TExternalToolsBase = class;

  TExternalToolGroup = class;

  { TAbstractExternalTool
    Implemented by the IDE.
    Create one with ExternalToolList.Add or AddDummy.
    Access needs Tool.Enter/LeaveCriticalSection. }

  TAbstractExternalTool = class(TComponent)
  private
    FData: TObject;
    FEnvironmentOverrides: TStrings;
    FEstimatedLoad: int64;
    FExitCode: integer;
    FExitStatus: integer;
    FFreeData: boolean;
    FGroup: TExternalToolGroup;
    FHint: string;
    FReadStdOutBeforeErr: boolean;
    FResolveMacrosOnExecute: boolean;
    FThread: TThread;
    FWorkerDirectory: string;
    FWorkerMessages: TMessageLines;
    FParsers: TFPList; // list of TExtToolParser
    FReferences: TStringList;
    FTitle: string;
    FTools: TExternalToolsBase;
    FViews: TFPList; // list of TExtToolView
    FCurrentDirectoryIsTestDir: boolean;
    function GetCmdLineParams: string;
    function GetParserCount: integer;
    function GetParsers(Index: integer): TExtToolParser;
    function GetReferences(Index: integer): string;
    function GetViews(Index: integer): TExtToolView;
    procedure SetCmdLineParams(aParams: string);
    procedure SetEnvironmentOverrides(AValue: TStrings);
    procedure SetGroup(AValue: TExternalToolGroup);
    procedure SetTitle(const AValue: string);
    procedure AddHandler(HandlerType: TExternalToolHandler;
                         const AMethod: TMethod; AsFirst: boolean = true);
    procedure RemoveHandler(HandlerType: TExternalToolHandler;
                            const AMethod: TMethod);
  protected
    FErrorMessage: string;
    FTerminated: boolean;
    FHandlers: array[TExternalToolHandler] of TMethodList;
    FStage: TExternalToolStage;
    FWorkerOutput: TStrings;
    FProcess: TProcessUTF8;
    FWorkerMessagesClass: TMessageLineClass;
    procedure DoCallNotifyHandler(HandlerType: TExternalToolHandler);
    function GetExecuteAfter(Index: integer): TAbstractExternalTool; virtual; abstract;
    function GetExecuteBefore(Index: integer): TAbstractExternalTool; virtual; abstract;
    procedure DoExecute; virtual; abstract;  // starts thread, returns immediately
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function CanFree: boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override; // (main thread)
    // always use before access, when using Tool and View: always lock Tool before View
    procedure EnterCriticalSection;
    procedure LeaveCriticalSection;
    property Thread: TThread read FThread write FThread;
    procedure ConsistencyCheck; virtual;
    procedure AutoFree; // (only main thread) free if not in use

    property Title: string read FTitle write SetTitle;
    property Hint: string read FHint write FHint; // this hint is shown in About dialog
    property Data: TObject read FData write FData; // free for user, e.g. the IDE uses TIDEExternalToolData
    property FreeData: boolean read FFreeData write FFreeData default false; // true = auto free Data on destroy
    property Tools: TExternalToolsBase read FTools;
    property Group: TExternalToolGroup read FGroup write SetGroup;
    property EstimatedLoad: int64 read FEstimatedLoad write FEstimatedLoad default 1; // used for deciding which tool to run next

    // handlers
    procedure RemoveAllHandlersOfObject(AnObject: TObject);
    procedure AddHandlerOnNewOutput(const OnNewOutput: TExternalToolNewOutputEvent;
                                    AsFirst: boolean = true); // called in main thread, Sender=Tool
    procedure RemoveHandlerOnNewOutput(const OnNewOutput: TExternalToolNewOutputEvent);
    procedure AddHandlerOnStopped(const OnStopped: TNotifyEvent;
                                  AsFirst: boolean = true);  // called in main thread, Sender=Tool
    procedure RemoveHandlerOnStopped(const OnStopped: TNotifyEvent);
    procedure Reference(Thing: TObject; const Note: string); // add a reference to delay auto freeing, use Release for free
    procedure Release(Thing: TObject);
    property References[Index: integer]: string read GetReferences;
    function ReferenceCount: integer;

    // process
    property Process: TProcessUTF8 read FProcess;
    property EnvironmentOverrides: TStrings read FEnvironmentOverrides
      write SetEnvironmentOverrides; // if not empty, then this and IDE's environment will be merged and replace Process.Environment
    property CmdLineParams: string read GetCmdLineParams write SetCmdLineParams;
    function ResolveMacros: boolean; virtual; abstract; // resolve macros in Process.Executable, Process.CurrentDirectory, Process.Params, Process.Environment on Execute
    property ResolveMacrosOnExecute: boolean read FResolveMacrosOnExecute
      write FResolveMacrosOnExecute;
    property CurrentDirectoryIsTestDir: boolean read FCurrentDirectoryIsTestDir
      write FCurrentDirectoryIsTestDir; // virtual files were written to test directory, parsers should reverse source filenames
    property Stage: TExternalToolStage read FStage;
    procedure Execute; virtual; abstract;
    procedure Terminate; virtual; abstract;
    procedure WaitForExit; virtual; abstract;
    property Terminated: boolean read FTerminated;
    property ExitCode: integer read FExitCode write FExitCode;
    property ExitStatus: integer read FExitStatus write FExitStatus;
    property ErrorMessage: string read FErrorMessage write FErrorMessage; // error executing tool
    property ReadStdOutBeforeErr: boolean read FReadStdOutBeforeErr write FReadStdOutBeforeErr;

    // output
    property WorkerOutput: TStrings read FWorkerOutput; // the raw output
    property WorkerDirectory: string read FWorkerDirectory write FWorkerDirectory; // changed by parsers, initialized from Process.CurrentDirectory
    property WorkerMessages: TMessageLines read FWorkerMessages; // created by parsers
    property WorkerMessagesClass: TMessageLineClass read FWorkerMessagesClass;

    // parsers
    property ParserCount: integer read GetParserCount;
    property Parsers[Index: integer]: TExtToolParser read GetParsers; // sorted for Priority
    function AddParsers(const SubTool: string): TExtToolParser; // will be freed on Destroy
    function AddParser(ParserClass: TExtToolParserClass): TExtToolParser; // will be freed on Destroy
    function AddParserByName(const ParserName: string): TExtToolParser; // will be freed on Destroy
    procedure DeleteParser(Parser: TExtToolParser); // disconnect and free
    procedure RemoveParser(Parser: TExtToolParser); // disconnect without free
    function IndexOfParser(Parser: TExtToolParser): integer;
    procedure ClearParsers(Delete: boolean = true);
    function FindParser(aParserClass: TExtToolParserClass): TExtToolParser;
    function FindParser(const SubTool: string): TExtToolParser;

    // viewers
    function ViewCount: integer;
    property Views[Index: integer]: TExtToolView read GetViews;
    function AddView(View: TExtToolView): integer; // (main thread) will *not* be freed on destroy
    procedure DeleteView(View: TExtToolView); // (main thread) disconnect and free, this might free the tool
    procedure RemoveView(View: TExtToolView); // (main thread) disconnect without free, this might free the tool
    function IndexOfView(View: TExtToolView): integer;
    procedure ClearViews(Delete: boolean = false); // (main thread), this might free the tool
    function FindUnfinishedView: TExtToolView;

    // dependencies
    procedure AddExecuteBefore(Tool: TAbstractExternalTool); virtual; abstract;
    function IsExecutedBefore(Tool: TAbstractExternalTool): Boolean; virtual; abstract;// search recursively
    procedure RemoveExecuteBefore(Tool: TAbstractExternalTool); virtual; abstract;
    function ExecuteBeforeCount: integer; virtual; abstract;
    property ExecuteBefore[Index: integer]: TAbstractExternalTool read GetExecuteBefore;
    function ExecuteAfterCount: integer; virtual; abstract;
    property ExecuteAfter[Index: integer]: TAbstractExternalTool read GetExecuteAfter;
  end;

  { TExternalToolGroup
    Hint: Add tools by setting Tool.Group:=Group.
    You can create your own descendant classes. }

  TExternalToolGroup = class(TComponent)
  private
    FAbortIfOneFails: boolean;
    FErrorMessage: string;
    FItems: TFPList; // list of TAbstractExternalTool
    function GetItems(Index: integer): TAbstractExternalTool;
    procedure InternalRemove(Tool: TAbstractExternalTool); virtual;
    procedure InternallAdd(Tool: TAbstractExternalTool); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear; virtual;
    function Count: integer;
    procedure Execute; virtual;
    procedure WaitForExit; virtual;
    procedure Terminate; virtual;
    function AllStopped: boolean;
    property Items[Index: integer]: TAbstractExternalTool read GetItems; default;
    property AbortIfOneFails: boolean read FAbortIfOneFails write FAbortIfOneFails;
    procedure ToolExited(Tool: TAbstractExternalTool); virtual;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
  end;

  { TExternalToolsBase
    Implemented by an application or the IDE. }

  TExternalToolsBase = class(TComponent)
  private
    function GetItems(Index: integer): TAbstractExternalTool; inline;
  protected
    fItems: TFPList; // list of TAbstractExternalTool
    function GetParsers(Index: integer): TExtToolParserClass; virtual; abstract; // (main thread)
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    function Count: integer; inline;
    procedure TerminateAll; virtual; abstract;
    procedure Clear; virtual; abstract; // terminate + free all tools
    property Items[Index: integer]: TAbstractExternalTool read GetItems; default;
    function Add(Title: string): TAbstractExternalTool; virtual; abstract;
    function AddDummy(Title: string): TAbstractExternalTool; // a tool, not run, usable for dependencies
    function IndexOf(Tool: TAbstractExternalTool): integer; virtual; abstract;
    procedure ConsistencyCheck;
    procedure EnterCriticalSection; virtual; abstract;
    procedure LeaveCriticalSection; virtual; abstract;
    function GetIDEObject(ToolData: TIDEExternalToolData): TObject; virtual; abstract;
    procedure HandleMessages; virtual; abstract;
    // parsers
    procedure RegisterParser(Parser: TExtToolParserClass); virtual; abstract; // (main thread)
    procedure UnregisterParser(Parser: TExtToolParserClass); virtual; abstract; // (main thread)
    function FindParserForTool(const SubTool: string): TExtToolParserClass; virtual; abstract; // (main thread)
    function FindParserWithName(const ParserName: string): TExtToolParserClass; virtual; abstract; // (main thread)
    function ParserCount: integer; virtual; abstract; // (main thread)
    property Parsers[Index: integer]: TExtToolParserClass read GetParsers; // (main thread)
    function GetMsgPattern(SubTool: string; MsgID: integer; out Urgency: TMessageLineUrgency): string; virtual; // (main thread)
    function GetMsgHint(SubTool: string; MsgID: integer): string; virtual; // (main thread)
    function GetMsgTool(Msg: TMessageLine): TAbstractExternalTool; virtual; abstract;
  end;

var
  ExternalToolList: TExternalToolsBase = nil; // will be set by the IDE

type
  { TIDEExternalToolOptions }

  TETMacroFunction = function(var aValue: string): boolean of object;

  TIDEExternalToolOptions = class
  private
    fCmdLineParams: string;
    FCustomMacroFunction: TETMacroFunction;
    FEnvironmentOverrides: TStringList;
    FExecutable: string;
    FHideWindow: boolean;
    FHint: string;
    FQuiet: boolean;
    FResolveMacros: boolean;
    FParserNames: TStrings;
    FShowConsole: boolean;
    fTitle: string;
    fWorkingDirectory: string;
    procedure SetEnvironmentOverrides(AValue: TStringList);
    procedure SetParserNames(AValue: TStrings);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TIDEExternalToolOptions);
    function Equals(Obj: TObject): boolean; override;
    procedure Clear;

    property Title: string read fTitle write fTitle;
    property Hint: string read FHint write FHint;
    property Executable: string read FExecutable write FExecutable;
    property Filename: string read FExecutable write FExecutable; deprecated; // use Executable instead
    property CmdLineParams: string read fCmdLineParams write fCmdLineParams;
    property WorkingDirectory: string read fWorkingDirectory write fWorkingDirectory;
    property EnvironmentOverrides: TStringList read FEnvironmentOverrides write SetEnvironmentOverrides;
    property Parsers: TStrings read FParserNames write SetParserNames;
    property ShowConsole: boolean read FShowConsole write FShowConsole default false; // sets poNoConsole/poNewConsole, works only on MSWindows
    property HideWindow: boolean read FHideWindow write FHideWindow default true; // sets/unsets swoHide/swoShow, works only on MSWindows
    property ResolveMacros: boolean read FResolveMacros write FResolveMacros default true;
    property CustomMacroFunction: TETMacroFunction read FCustomMacroFunction write FCustomMacroFunction;
    property Quiet: boolean read FQuiet write FQuiet; // no user dialogs about errors
  end;

type
  TRunExternalTool = function(Tool: TIDEExternalToolOptions): boolean of object;

var
  RunExternalTool: TRunExternalTool = nil;// set by the IDE
  DefaultMaxProcessCount: integer = 2;// set by the IDE

function CompareMsgLinesSrcPos(MsgLine1, MsgLine2: Pointer): integer;

function StrToMsgLineUrgency(const s: string): TMessageLineUrgency;

function dbgs(u: TMessageLineUrgency): string; overload;
function dbgs(f: TMessageLineFlag): string; overload;
function dbgs(Flags: TMessageLineFlags): string; overload;
function dbgs(s: TExternalToolStage): string; overload;

implementation

function CompareMsgLinesSrcPos(MsgLine1, MsgLine2: Pointer): integer;
var
  Line1: TMessageLine absolute MsgLine1;
  Line2: TMessageLine absolute MsgLine2;
begin
  Result:=CompareFilenames(Line1.Filename,Line2.Filename);
  if Result<>0 then exit;

  if Line1.Line<Line2.Line then exit(-1)
  else if Line1.Line>Line2.Line then exit(1);

  if Line1.Column<Line2.Column then exit(-1)
  else if Line1.Column>Line2.Column then exit(1);

  if Line1.OutputIndex<Line2.OutputIndex then exit(-1)
  else if Line1.OutputIndex>Line2.OutputIndex then exit(1);

  if Line1.Index<Line2.Index then exit(-1)
  else if Line1.Index>Line2.Index then exit(1);

  Result:=0;
end;

function StrToMsgLineUrgency(const s: string): TMessageLineUrgency;
begin
  for Result:=Low(TMessageLineUrgency) to high(TMessageLineUrgency) do
    if SysUtils.CompareText(s,MessageLineUrgencyNames[Result])=0 then exit;
  Result:=mluNone;
end;

function dbgs(u: TMessageLineUrgency): string;
begin
  Result:='';
  WriteStr(Result,u);
end;

function dbgs(f: TMessageLineFlag): string;
begin
  Result:='';
  WriteStr(Result,f);
end;

function dbgs(Flags: TMessageLineFlags): string;
var
  f: TMessageLineFlag;
begin
  Result:='';
  for f in Flags do begin
    if Result<>'' then Result+=',';
    Result+=dbgs(f);
  end;
  Result:='['+Result+']';
end;

function dbgs(s: TExternalToolStage): string;
begin
  Result:='';
  WriteStr(Result,s);
end;

{ TIDEExternalToolData }

constructor TIDEExternalToolData.Create(aKind, aModuleName, aFilename: string);
begin
  Kind:=aKind;
  ModuleName:=aModuleName;
  Filename:=aFilename;
  Flags:=TStringList.Create;
end;

destructor TIDEExternalToolData.Destroy;
begin
  FreeAndNil(Flags);
  inherited Destroy;
end;

{ TFPCParser }

class function TFPCParser.GetFPCParser(Msg: TMessageLine): TFPCParser;
begin
  Result:=TFPCParser(GetMsgParser(Msg,TFPCParser));
end;

{ TIDEExternalToolOptions }

procedure TIDEExternalToolOptions.SetEnvironmentOverrides(AValue: TStringList);
begin
  if FEnvironmentOverrides.Equals(AValue) then Exit;
  FEnvironmentOverrides.Assign(AValue);
end;

procedure TIDEExternalToolOptions.SetParserNames(AValue: TStrings);
begin
  if FParserNames.Equals(AValue) then Exit;
  FParserNames.Assign(AValue);
end;

constructor TIDEExternalToolOptions.Create;
begin
  ResolveMacros:=true;
  FEnvironmentOverrides:=TStringList.Create;
  FParserNames:=TStringList.Create;
  FHideWindow:=true;
end;

destructor TIDEExternalToolOptions.Destroy;
begin
  FreeAndNil(FEnvironmentOverrides);
  FreeAndNil(FParserNames);
  inherited Destroy;
end;

procedure TIDEExternalToolOptions.Assign(Source: TIDEExternalToolOptions);
begin
  Title:=Source.Title;
  Executable:=Source.Executable;
  CmdLineParams:=Source.CmdLineParams;
  WorkingDirectory:=Source.WorkingDirectory;
  EnvironmentOverrides:=Source.EnvironmentOverrides;
  Parsers:=Source.Parsers;
  ShowConsole:=Source.ShowConsole;
  HideWindow:=Source.HideWindow;
  ResolveMacros:=Source.ResolveMacros;
  CustomMacroFunction:=Source.CustomMacroFunction;
  Quiet:=Source.Quiet;
end;

function TIDEExternalToolOptions.Equals(Obj: TObject): boolean;
var
  Source: TIDEExternalToolOptions;
begin
  if Obj=Self then exit(true);
  if Obj is TIDEExternalToolOptions then begin
    Source:=TIDEExternalToolOptions(Obj);
    Result:=(Title=Source.Title)
      and (Executable=Source.Executable)
      and (CmdLineParams=Source.CmdLineParams)
      and (WorkingDirectory=Source.WorkingDirectory)
      and EnvironmentOverrides.Equals(Source.EnvironmentOverrides)
      and Parsers.Equals(Source.Parsers)
      and (ShowConsole=Source.ShowConsole)
      and (HideWindow=Source.HideWindow)
      and (ResolveMacros=Source.ResolveMacros)
      and CompareMethods(TMethod(CustomMacroFunction),TMethod(Source.CustomMacroFunction))
      and (Quiet=Source.Quiet);
  end else
    Result:=inherited Equals(Obj);
end;

procedure TIDEExternalToolOptions.Clear;
begin
  fCmdLineParams:='';
  FCustomMacroFunction:=nil;
  FEnvironmentOverrides.Clear;
  FExecutable:='';
  FShowConsole:=false;
  FHideWindow:=true;
  FResolveMacros:=true;
  FParserNames.Clear;
  fTitle:='';
  fWorkingDirectory:='';
  FQuiet:=false;
end;

{ TExternalToolGroup }

function TExternalToolGroup.GetItems(Index: integer): TAbstractExternalTool;
begin
  Result:=TAbstractExternalTool(FItems[Index]);
end;

constructor TExternalToolGroup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems:=TFPList.Create;
  FAbortIfOneFails:=true;
end;

destructor TExternalToolGroup.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TExternalToolGroup.Clear;
var
  i: Integer;
begin
  for i:=Count-1 downto 0 do
    Items[i].Group:=nil;
end;

function TExternalToolGroup.Count: integer;
begin
  Result:=FItems.Count;
end;

procedure TExternalToolGroup.Execute;
var
  i: Integer;
  Tool: TAbstractExternalTool;
begin
  for i:=0 to Count-1 do begin
    Tool:=Items[i];
    if Tool.Terminated then continue;
    //debugln(['TExternalToolGroup.Execute ',Tool.Title]);
    Tool.Execute;
  end;
end;

procedure TExternalToolGroup.WaitForExit;
begin
  repeat
    ExternalToolList.HandleMessages;
    if AllStopped then exit;
    Sleep(50);
    //debugln(['TExternalToolGroup.WaitForExit ',Now,'==========================']);
    //for i:=0 to Count-1 do
    //  debugln(['  Stage=',dbgs(Items[i].Stage),' "',Items[i].Title,'"']);
  until false;
end;

procedure TExternalToolGroup.Terminate;
var
  i: Integer;
begin
  for i:=Count-1 downto 0 do
    if i<Count then
      Items[i].Terminate;
end;

function TExternalToolGroup.AllStopped: boolean;
var
  i: Integer;
begin
  for i:=0 to Count-1 do
    if ord(Items[i].Stage)<ord(etsStopped) then exit(false);
  Result:=true;
end;

procedure TExternalToolGroup.InternalRemove(Tool: TAbstractExternalTool);
begin
  FItems.Remove(Tool);
  if FItems.Count>0 then exit;
  if csDestroying in ComponentState then exit;
  Free;
end;

procedure TExternalToolGroup.InternallAdd(Tool: TAbstractExternalTool);
begin
  if FItems.IndexOf(Tool)>=0 then
    raise Exception.Create('already in group');
  FItems.Add(Tool);
end;

procedure TExternalToolGroup.ToolExited(Tool: TAbstractExternalTool);
begin
  //debugln(['TExternalToolGroup.ToolExited START ',Tool.Title,' Error=',Tool.ErrorMessage,' AbortIfOneFails=',AbortIfOneFails]);
  if (Tool.ErrorMessage<>'') then begin
    if ErrorMessage='' then
      ErrorMessage:=Tool.ErrorMessage;
    if AbortIfOneFails then
      Terminate;
  end;
end;

{ TDefaultParser }

procedure TDefaultParser.ReadLine(Line: string; OutputIndex: integer;
  IsStdErr: boolean; var Handled: boolean);
var
  MsgLine: TMessageLine;
begin
  Handled:=true;
  //debugln(['TDefaultParser.ReadLine ',Line]);
  MsgLine:=CreateMsgLine(OutputIndex);
  MsgLine.Msg:=Line;
  MsgLine.Urgency:=mluImportant;
  if IsStdErr then
    MsgLine.Flags:=MsgLine.Flags+[mlfStdErr];
  AddMsgLine(MsgLine);
end;

class function TDefaultParser.DefaultSubTool: string;
begin
  Result:=SubToolDefault;
end;

class function TDefaultParser.GetLocalizedParserName: string;
begin
  Result:=lisShowAllOutputLines;
end;

class function TDefaultParser.Priority: integer;
begin
  Result:=SubToolDefaultPriority;
end;

{ TMessageLineEnumerator }

function TMessageLineEnumerator.GetCurrent: TMessageLine;
begin
  Result:=TMessageLine(FCurrent.Data);
end;

constructor TMessageLineEnumerator.Create(Tree: TAvlTree;
  const aFilename: string; aMinLine, aMaxLine: integer);
begin
  FTree:=Tree;
  FFilename:=aFilename;
  fMinLine:=aMinLine;
  FMaxLine:=aMaxLine;
end;

function TMessageLineEnumerator.GetEnumerator: TMessageLineEnumerator;
begin
  Result:=Self;
end;

function TMessageLineEnumerator.MoveNext: boolean;
var
  Line: TMessageLine;
  CmpLine: TMessageLine;
begin
  Result:=false;
  if FCurrent=nil then begin
    CmpLine:=TMessageLine.Create;
    try
      CmpLine.Filename:=FFilename;
      CmpLine.Line:=MinLine;
      CmpLine.Column:=Low(Integer);
      FCurrent:=FTree.FindNearest(CmpLine);
      if FCurrent=nil then exit;
      if FTree.Compare(FCurrent.Data,CmpLine)<0 then
        FCurrent:=FCurrent.Successor;
    finally
      CmpLine.Free;
    end;
  end else begin
    FCurrent:=FCurrent.Successor;
  end;
  if FCurrent=nil then
    exit;
  Line:=Current;
  if CompareFilenames(Line.Filename,FFilename)<>0 then exit;
  if Line.Line>MaxLine then exit;
  Result:=true;
end;

{ TAbstractExternalTool }

function TAbstractExternalTool.GetParserCount: integer;
begin
  Result:=FParsers.Count;
end;

function TAbstractExternalTool.GetCmdLineParams: string;
begin
  Result:=MergeCmdLineParams(Process.Parameters);
end;

function TAbstractExternalTool.GetParsers(Index: integer): TExtToolParser;
begin
  Result:=TExtToolParser(FParsers[Index]);
end;

function TAbstractExternalTool.GetReferences(Index: integer): string;
begin
  Result:=FReferences[Index];
end;

function TAbstractExternalTool.GetViews(Index: integer): TExtToolView;
begin
  Result:=TExtToolView(FViews[Index]);
end;

procedure TAbstractExternalTool.SetCmdLineParams(aParams: string);
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  try
    SplitCmdLineParams(aParams,sl);
    Process.Parameters:=sl;
  finally
    sl.Free;
  end;
end;

procedure TAbstractExternalTool.SetEnvironmentOverrides(AValue: TStrings);
begin
  if (FEnvironmentOverrides=AValue)
  or (FEnvironmentOverrides.Equals(AValue)) then Exit;
  FEnvironmentOverrides.Assign(AValue);
end;

procedure TAbstractExternalTool.SetGroup(AValue: TExternalToolGroup);
begin
  if FGroup=AValue then Exit;
  if Group<>nil then
    Group.InternalRemove(Self);
  FGroup:=AValue;
  if Group<>nil then
    Group.InternallAdd(Self);
end;

procedure TAbstractExternalTool.SetTitle(const AValue: string);
begin
  if FTitle=AValue then exit;
  FTitle:=AValue;
end;

procedure TAbstractExternalTool.AddHandler(HandlerType: TExternalToolHandler;
  const AMethod: TMethod; AsFirst: boolean);
begin
  if FHandlers[HandlerType]=nil then
    FHandlers[HandlerType]:=TMethodList.Create;
  FHandlers[HandlerType].Add(AMethod,not AsFirst);
end;

procedure TAbstractExternalTool.RemoveHandler(
  HandlerType: TExternalToolHandler; const AMethod: TMethod);
begin
  FHandlers[HandlerType].Remove(AMethod);
end;

procedure TAbstractExternalTool.DoCallNotifyHandler(HandlerType: TExternalToolHandler);
begin
  FHandlers[HandlerType].CallNotifyEvents(Self);
end;

procedure TAbstractExternalTool.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation=opRemove then begin
    EnterCriticalSection;
    try
      if FViews<>nil then
        FViews.Remove(AComponent);
    finally
      LeaveCriticalSection;
    end;
  end;
end;

function TAbstractExternalTool.CanFree: boolean;
begin
  Result:=false;
  if csDestroying in ComponentState then exit;
  if (FReferences.Count>0) or (ViewCount>0) then exit;
  if (Process<>nil) and (Process.Running) then exit;
  Result:=true;
end;

constructor TAbstractExternalTool.Create(AOwner: TComponent);
begin
  if AOwner is TExternalToolsBase then
    FTools:=TExternalToolsBase(AOwner);
  inherited Create(AOwner);
  if FWorkerMessagesClass=nil then
    FWorkerMessagesClass:=TMessageLine;
  FWorkerMessages:=TMessageLines.Create(Self,FWorkerMessagesClass);
  FParsers:=TFPList.Create;
  FViews:=TFPList.Create;
  FStage:=etsInit;
  FEstimatedLoad:=1;
  FEnvironmentOverrides:=TStringList.Create;
  FReferences:=TStringList.Create;
end;

destructor TAbstractExternalTool.Destroy;
var
  h: TExternalToolHandler;
begin
  EnterCriticalSection;
  try
    if FreeData then FreeAndNil(FData);
    ClearParsers;
    ClearViews;
    Group:=nil;
    FreeAndNil(FReferences);
    for h:=low(FHandlers) to high(FHandlers) do
      FreeAndNil(FHandlers[h]);
    FWorkerMessages.Clear;
    FreeAndNil(FParsers);
    FreeAndNil(FViews);
    FreeAndNil(FEnvironmentOverrides);
    inherited Destroy;
  finally
    LeaveCriticalsection;
  end;
  FreeAndNil(FWorkerMessages);
end;

procedure TAbstractExternalTool.EnterCriticalSection;
begin
  FWorkerMessages.EnterCriticalSection;
end;

procedure TAbstractExternalTool.LeaveCriticalSection;
begin
  Assert(Assigned(FWorkerMessages), 'TAbstractExternalTool.LeaveCriticalSection: FWorkerMessages=Nil.');
  FWorkerMessages.LeaveCriticalSection;
end;

procedure TAbstractExternalTool.ConsistencyCheck;
var
  i: Integer;
begin
  EnterCriticalSection;
  try
    for i:=0 to ParserCount-1 do
      Parsers[i].ConsistencyCheck;
  finally
    LeaveCriticalSection;
  end;
end;

procedure TAbstractExternalTool.AutoFree;
begin
  if MainThreadID<>GetCurrentThreadId then
    raise Exception.Create('AutoFree only via main thread');
  if CanFree then
    Free;
end;

procedure TAbstractExternalTool.RemoveAllHandlersOfObject(AnObject: TObject);
var
  HandlerType: TExternalToolHandler;
begin
  for HandlerType:=Low(HandlerType) to High(HandlerType) do
    FHandlers[HandlerType].RemoveAllMethodsOfObject(AnObject);
end;

procedure TAbstractExternalTool.AddHandlerOnStopped(
  const OnStopped: TNotifyEvent; AsFirst: boolean);
begin
  AddHandler(ethStopped,TMethod(OnStopped),AsFirst);
end;

procedure TAbstractExternalTool.RemoveHandlerOnStopped(
  const OnStopped: TNotifyEvent);
begin
  RemoveHandler(ethStopped,TMethod(OnStopped));
end;

procedure TAbstractExternalTool.Reference(Thing: TObject; const Note: string);
var
  i: Integer;
begin
  if csDestroying in ComponentState then
    raise Exception.Create('too late');
  if (Note='') or (Thing=nil) then
    raise Exception.Create('invalid parameters');
  for i:=0 to FReferences.Count-1 do
    if FReferences.Objects[i]=Thing then
      raise Exception.Create('already referenced');
  FReferences.AddObject(Note,Thing);
end;

procedure TAbstractExternalTool.Release(Thing: TObject);
var
  i: Integer;
begin
  for i:=0 to FReferences.Count-1 do
    if FReferences.Objects[i]=Thing then begin
      FReferences.Delete(i);
      AutoFree;
      exit;
    end;
  raise Exception.Create('reference not found');
end;

function TAbstractExternalTool.ReferenceCount: integer;
begin
  Result:=FReferences.Count;
end;

procedure TAbstractExternalTool.AddHandlerOnNewOutput(
  const OnNewOutput: TExternalToolNewOutputEvent; AsFirst: boolean);
begin
  AddHandler(ethNewOutput,TMethod(OnNewOutput),AsFirst);
end;

procedure TAbstractExternalTool.RemoveHandlerOnNewOutput(
  const OnNewOutput: TExternalToolNewOutputEvent);
begin
  RemoveHandler(ethNewOutput,TMethod(OnNewOutput));
end;

function TAbstractExternalTool.AddParsers(const SubTool: string): TExtToolParser;
var
  ParserClass: TExtToolParserClass;
  i: Integer;
begin
  Result:=nil;
  for i:=0 to ExternalToolList.ParserCount-1 do begin
    ParserClass:=ExternalToolList.Parsers[i];
    if not ParserClass.CanParseSubTool(SubTool) then continue;
    Result:=AddParser(ParserClass);
  end;
  if Result<>nil then exit;
  raise Exception.Create(Format(lisUnableToFindParserForTool, [SubTool]));
end;

function TAbstractExternalTool.AddParser(ParserClass: TExtToolParserClass): TExtToolParser;
var
  i: Integer;
begin
  for i:=0 to ParserCount-1 do begin
    Result:=Parsers[i];
    if Result.ClassType=ParserClass then
      exit;
  end;
  Result:=ParserClass.Create(nil);
  i:=0;
  while (i<FParsers.Count) and (Parsers[i].Priority>=ParserClass.Priority) do
    inc(i);
  FParsers.Insert(i,Result);
  Result.FTool:=Self;
end;

function TAbstractExternalTool.AddParserByName(const ParserName: string): TExtToolParser;
var
  aClass: TExtToolParserClass;
begin
  Result:=nil;
  aClass:=ExternalToolList.FindParserWithName(ParserName);
  if aClass=nil then
    raise Exception.Create(Format(lisUnableToFindParserWithName, [ParserName]));
  Result:=AddParser(aClass);
end;

procedure TAbstractExternalTool.RemoveParser(Parser: TExtToolParser);
begin
  FParsers.Remove(Parser);
  if Parser.Tool<>Self then exit;
  Parser.FTool:=nil;
end;

function TAbstractExternalTool.IndexOfParser(Parser: TExtToolParser): integer;
begin
  Result:=FParsers.IndexOf(Parser);
end;

procedure TAbstractExternalTool.DeleteParser(Parser: TExtToolParser);
begin
  Parser.Free;
end;

procedure TAbstractExternalTool.ClearParsers(Delete: boolean);
begin
  while ParserCount>0 do
    if Delete then
      DeleteParser(Parsers[ParserCount-1])
    else
      RemoveParser(Parsers[ParserCount-1]);
end;

function TAbstractExternalTool.FindParser(aParserClass: TExtToolParserClass
  ): TExtToolParser;
var
  i: Integer;
begin
  for i:=0 to ParserCount-1 do begin
    Result:=Parsers[i];
    if Result.InheritsFrom(aParserClass) then exit;
  end;
  Result:=nil;
end;

function TAbstractExternalTool.FindParser(const SubTool: string): TExtToolParser;
var
  i: Integer;
  ParserClass: TExtToolParserClass;
begin
  for i:=0 to ExternalToolList.ParserCount-1 do begin
    ParserClass:=ExternalToolList.Parsers[i];
    if not ParserClass.CanParseSubTool(SubTool) then continue;
    Result:=FindParser(ParserClass);
    if Result<>nil then exit;
  end;
  Result:=nil;
end;

function TAbstractExternalTool.ViewCount: integer;
begin
  Result:=FViews.Count;
end;

function TAbstractExternalTool.AddView(View: TExtToolView): integer;
begin
  View.EnterCriticalSection;
  try
    if View.Tool<>nil then
      raise Exception.Create('');
    Result:=FViews.Add(View);
    FreeNotification(View);
    View.FTool:=Self;
    View.Lines.BaseDirectory:=WorkerDirectory;
  finally
    View.LeaveCriticalSection;
  end;
end;

procedure TAbstractExternalTool.RemoveView(View: TExtToolView);
begin
  View.EnterCriticalSection;
  try
    View.fTool:=nil;
    FViews.Remove(View);
  finally
    View.LeaveCriticalSection;
  end;
  AutoFree;
end;

function TAbstractExternalTool.IndexOfView(View: TExtToolView): integer;
begin
  Result:=FViews.IndexOf(View);
end;

procedure TAbstractExternalTool.DeleteView(View: TExtToolView);
begin
  RemoveView(View);
  View.Free;
end;

procedure TAbstractExternalTool.ClearViews(Delete: boolean);
begin
  EnterCriticalSection;
  try
    while ViewCount>0 do
      if Delete then
        DeleteView(Views[ViewCount-1])
      else
        RemoveView(Views[ViewCount-1]);
  finally
    LeaveCriticalSection;
  end;
end;

function TAbstractExternalTool.FindUnfinishedView: TExtToolView;
var
  i: Integer;
begin
  for i:=0 to ViewCount-1 do begin
    Result:=Views[i];
    if not Result.HasFinished then exit;
  end;
  Result:=nil;
end;

{ TExtToolParser }

destructor TExtToolParser.Destroy;
begin
  if Tool<>nil then
    Tool.RemoveParser(Self);
  inherited Destroy;
end;

procedure TExtToolParser.Init;
begin

end;

procedure TExtToolParser.InitReading;
begin

end;

procedure TExtToolParser.Done;
begin

end;

function TExtToolParser.CreateMsgLine(OutputIndex: integer): TMessageLine;
begin
  Result:=Tool.WorkerMessages.CreateLine(OutputIndex);
  if OutputIndex>=0 then
    Result.Msg:=Tool.WorkerOutput[OutputIndex]; // use raw output as default msg
end;

procedure TExtToolParser.AddMsgLine(MsgLine: TMessageLine);
begin
  Tool.WorkerMessages.Add(MsgLine);
end;

procedure TExtToolParser.ImproveMessages(aPhase: TExtToolParserSyncPhase);
begin

end;

procedure TExtToolParser.ConsistencyCheck;
begin

end;

class function TExtToolParser.GetParserName: string;
begin
  Result:=DefaultSubTool;
end;

class function TExtToolParser.GetLocalizedParserName: string;
begin
  Result:=DefaultSubTool;
end;

class function TExtToolParser.IsSubTool(const SubTool: string): boolean;
begin
  Result:=CanParseSubTool(SubTool);
end;

class function TExtToolParser.CanParseSubTool(const SubTool: string): boolean;
begin
  Result:=CompareText(DefaultSubTool,SubTool)=0;
end;

class function TExtToolParser.GetMsgPattern(SubTool: string; MsgID: integer;
  out Urgency: TMessageLineUrgency): string;
begin
  Urgency:=mluNone;
  Result:='';
end;

class function TExtToolParser.GetMsgHint(SubTool: string; MsgID: integer): string;
begin
  Result:='';
end;

class function TExtToolParser.GetMsgParser(Msg: TMessageLine;
  ParserClass: TClass): TExtToolParser;
var
  aTool: TAbstractExternalTool;
begin
  Result:=nil;
  if ExternalToolList=nil then exit;
  aTool:=ExternalToolList.GetMsgTool(Msg);
  if aTool=nil then exit;
  Result:=aTool.FindParser(TExtToolParserClass(ParserClass));
end;

class function TExtToolParser.Priority: integer;
begin
  Result:=0;
end;

{ TExternalToolsBase }

// inline
function TExternalToolsBase.GetItems(Index: integer): TAbstractExternalTool;
begin
  Result:=TAbstractExternalTool(fItems[Index]);
end;

// inline
function TExternalToolsBase.Count: integer;
begin
  Result:=fItems.Count;
end;

function TExternalToolsBase.AddDummy(Title: string): TAbstractExternalTool;
begin
  Result:=Add(Title);
  Result.Terminate;
end;

constructor TExternalToolsBase.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fItems:=TFPList.Create;
  if ExternalToolList=nil then
    ExternalToolList:=Self;
end;

destructor TExternalToolsBase.Destroy;
begin
  FreeAndNil(fItems);
  if ExternalToolList=Self then
    ExternalToolList:=nil;
  inherited Destroy;
end;

procedure TExternalToolsBase.ConsistencyCheck;
var
  i: Integer;
begin
  for i:=0 to Count-1 do
    Items[i].ConsistencyCheck;
end;

function TExternalToolsBase.GetMsgPattern(SubTool: string; MsgID: integer; out
  Urgency: TMessageLineUrgency): string;
var
  Parser: TExtToolParserClass;
  i: Integer;
begin
  Result:='';
  Urgency:=mluNone;
  for i:=0 to ParserCount-1 do begin
    Parser:=Parsers[i];
    Result:=Parser.GetMsgPattern(SubTool,MsgID,Urgency);
    if Result<>'' then exit;
  end;
end;

function TExternalToolsBase.GetMsgHint(SubTool: string; MsgID: integer): string;
var
  Parser: TExtToolParserClass;
  i: Integer;
begin
  Result:='';
  for i:=0 to ParserCount-1 do begin
    Parser:=Parsers[i];
    Result:=Parser.GetMsgHint(SubTool,MsgID);
    if Result<>'' then exit;
  end;
end;

{ TMessageLines }

function TMessageLines.GetItems(Index: integer): TMessageLine;
begin
  Result:=TMessageLine(fItems[Index]);
end;

procedure TMessageLines.SetBaseDirectory(const AValue: string);
var
  NewValue: String;
begin
  NewValue:=CleanAndExpandDirectory(AValue);
  if FBaseDirectory=NewValue then exit;
  FBaseDirectory:=NewValue;
  IncreaseChangeStamp;
end;

procedure TMessageLines.LineChanged(Line: TMessageLine);
begin
  IncreaseChangeStamp;
  if fChangedHandler<>nil then
    fChangedHandler.CallNotifyEvents(Line);
end;

constructor TMessageLines.Create(aOwner: TObject; aMsgLineClass: TMessageLineClass);
begin
  FOwner:=aOwner;
  InitCriticalSection(FCritSec);
  FMessageLineClass:=aMsgLineClass;
  fItems:=TFPList.Create;
  FSortedForSrcPos:=TAvlTree.Create(@CompareMsgLinesSrcPos);
  FSortedForSrcPos.SetNodeManager(nil);
  FUpdateSortedSrcPos:=true;
  fChangedHandler:=TMethodList.Create;
end;

destructor TMessageLines.Destroy;
begin
  EnterCriticalSection;
  try
    Clear;
    FreeAndNil(FSortedForSrcPos);
    FreeAndNil(fItems);
    inherited Destroy;
    FreeAndNil(fChangedHandler);
  finally
    LeaveCriticalsection;
  end;
  DoneCriticalsection(FCritSec);
end;

procedure TMessageLines.EnterCriticalSection;
begin
  System.EnterCriticalsection(FCritSec);
end;

procedure TMessageLines.LeaveCriticalSection;
begin
  System.LeaveCriticalsection(FCritSec);
end;

function TMessageLines.Count: integer;
begin
  Result:=fItems.Count;
end;

procedure TMessageLines.Clear;
var
  i: Integer;
  c: TMessageLineUrgency;
begin
  if fItems.Count=0 then exit;
  FreeAndNil(fMarkedFixed);
  for i:=0 to fItems.Count-1 do
    TObject(fItems[i]).Free;
  fItems.Clear;
  FSortedForSrcPos.Clear;
  for c:=low(UrgencyCounts) to high(UrgencyCounts) do UrgencyCounts[c]:=0;
  IncreaseChangeStamp;
end;

function TMessageLines.GetLastLine: TMessageLine;
begin
  if Count>0 then
    Result:=Items[Count-1]
  else
    Result:=nil;
end;

function TMessageLines.CreateLine(OutputIndex: integer): TMessageLine;
begin
  Result:=MessageLineClass.Create;
  Result.FIndex:=-1;
  Result.FOutputIndex:=OutputIndex;
end;

procedure TMessageLines.Add(MsgLine: TMessageLine);
var
  Cnt: Integer;
  Prev: TMessageLine;
begin
  if MsgLine.Index>=0 then
    raise Exception.Create('TMessageLines.Add already added');
  MsgLine.FLines:=Self;
  MsgLine.FIndex:=fItems.Add(MsgLine);
  FSortedForSrcPos.Add(MsgLine);
  inc(UrgencyCounts[MsgLine.Urgency]);

  // save some memory by combining strings
  Cnt:=Count;
  if (Cnt>1) then begin
    Prev:=Items[Cnt-2];
    if MsgLine.Filename=Prev.Filename then
      MsgLine.fFilename:=Prev.Filename;
    if MsgLine.OriginalLine=Prev.OriginalLine then
      MsgLine.fOriginalLine:=Prev.OriginalLine;
  end;

  LineChanged(MsgLine);
end;

procedure TMessageLines.Remove(MsgLine: TMessageLine);
var
  i: Integer;
begin
  if MsgLine.FLines<>Self then
    raise Exception.Create('');
  FSortedForSrcPos.Remove(MsgLine);
  fItems.Delete(MsgLine.Index);
  for i:=MsgLine.Index to Count-1 do
    Items[i].FIndex:=i;
  MsgLine.FLines:=nil;
  dec(UrgencyCounts[MsgLine.Urgency]);
  IncreaseChangeStamp;
end;

procedure TMessageLines.Delete(MsgLine: TMessageLine);
begin
  Remove(MsgLine);
  MsgLine.Free;
end;

procedure TMessageLines.MarkFixed(MsgLine: TMessageLine);
begin
  if fMarkedFixed=nil then
    fMarkedFixed:=TAvlTree.Create;
  if fMarkedFixed.Find(MsgLine)=nil then
    fMarkedFixed.Add(MsgLine);
end;

procedure TMessageLines.ApplyFixedMarks;
var
  Node: TAvlTreeNode;
  Msg: TMessageLine;
  List: TFPList;
begin
  if fMarkedFixed=nil then exit;
  List:=TFPList.Create;
  try
    for Node in fMarkedFixed do begin
      Msg:=TMessageLine(Node.Data);
      if mlfFixed in Msg.Flags then Continue;
      Msg.Flags:=Msg.Flags+[mlfFixed];
      List.Add(Msg);
    end;
    if List.Count=0 then exit;
    if Assigned(OnMarksFixed) then
      OnMarksFixed(List);
  finally
    FreeAndNil(fMarkedFixed);
    List.Free;
  end;
end;

procedure TMessageLines.FetchAll(SrcLines: TMessageLines);
var
  i: Integer;
  u: TMessageLineUrgency;
  MsgLine: TMessageLine;
begin
  if (SrcLines=nil) or (SrcLines=Self) or (SrcLines.Count=0) then exit;
  SrcLines.FSortedForSrcPos.Clear;
  for i:=0 to SrcLines.Count-1 do begin
    MsgLine:=SrcLines[i];
    MsgLine.FLines:=Self;
    MsgLine.FIndex:=fItems.Add(MsgLine);
    FSortedForSrcPos.Add(MsgLine);
    inc(UrgencyCounts[MsgLine.Urgency]);
    LineChanged(MsgLine);
  end;
  SrcLines.fItems.Clear;
  for u:=low(TMessageLineUrgency) to high(TMessageLineUrgency) do
    SrcLines.UrgencyCounts[u]:=0;
  IncreaseChangeStamp;
end;

procedure TMessageLines.SourceLinesInserted(Filename: string; Line,
  InsertedCount: integer);
// adjust Line numbers in all messages
var
  CmpLine: TMessageLine;
  Node: TAvlTreeNode;
  MsgLine: TMessageLine;
begin
  if (Filename='') or (Count<=0) then exit;
  CmpLine:=TMessageLine.Create;
  try
    CmpLine.Filename:=Filename;
    CmpLine.Line:=Line;
    Node:=FSortedForSrcPos.FindNearest(CmpLine);
    if Node=nil then exit;
    Node:=FSortedForSrcPos.FindLeftMost(CmpLine);
    // Note: if no exact node was found, Node can be one too less or too high
    if FSortedForSrcPos.Compare(Node,CmpLine)<0 then
      Node:=FSortedForSrcPos.FindSuccessor(Node);
    // adjust line numbers behind (in same source)
    CmpLine.Line:=High(integer);
    while (Node<>nil) and (FSortedForSrcPos.Compare(Node,CmpLine)<0) do begin
      MsgLine:=TMessageLine(Node.Data);
      inc(MsgLine.FLine,InsertedCount);
      LineChanged(MsgLine);
      Node:=FSortedForSrcPos.FindSuccessor(Node);
    end;
  finally
    CmpLine.Free;
  end;
end;

procedure TMessageLines.SourceLinesDeleted(Filename: string; FirstLine,
  DeletedCount: integer);
// adjust Line numbers in all messages and mark lines in range as deleted
var
  CmpLine: TMessageLine;
  Node: TAvlTreeNode;
  MsgLine: TMessageLine;
begin
  if (Filename='') or (Count<=0) then exit;
  CmpLine:=TMessageLine.Create;
  try
    CmpLine.Filename:=Filename;
    CmpLine.Line:=FirstLine;
    Node:=FSortedForSrcPos.FindNearest(CmpLine);
    if Node=nil then exit;
    Node:=FSortedForSrcPos.FindLeftMost(CmpLine);
    // Note: if no exact node was found, Node can be one too less or too high
    if FSortedForSrcPos.Compare(Node,CmpLine)<0 then
      Node:=FSortedForSrcPos.FindSuccessor(Node);
    // mark lines as deleted
    CmpLine.Line:=FirstLine+DeletedCount;
    while (Node<>nil) and (FSortedForSrcPos.Compare(Node,CmpLine)<0) do begin
      MsgLine:=TMessageLine(Node.Data);
      MsgLine.Flags:=MsgLine.Flags+[mlfFixed];
      Node:=FSortedForSrcPos.FindSuccessor(Node);
    end;
    // adjust line numbers behind (in same source)
    CmpLine.Line:=High(integer);
    while (Node<>nil) and (FSortedForSrcPos.Compare(Node,CmpLine)<0) do begin
      MsgLine:=TMessageLine(Node.Data);
      dec(MsgLine.FLine,DeletedCount);
      LineChanged(MsgLine);
      Node:=FSortedForSrcPos.FindSuccessor(Node);
    end;
  finally
    CmpLine.Free;
  end;
end;

procedure TMessageLines.IncreaseChangeStamp;
begin
  LUIncreaseChangeStamp64(FChangeStamp);
end;

function TMessageLines.IndexOfOutputIndex(OutputIndex: integer): integer;
var
  l: Integer;
  r: Integer;
  CurOutputIndex: Integer;
begin
  l:=0;
  r:=Count-1;
  while (l<=r) do begin
    Result:=(l+r) div 2;
    CurOutputIndex:=Items[Result].OutputIndex;
    if CurOutputIndex>OutputIndex then
      r:=Result-1
    else if CurOutputIndex<OutputIndex then
      l:=Result+1
    else
      exit;
  end;
  Result:=-1;
end;

function TMessageLines.EnumerateFile(aFilename: string; MinLine: integer;
  MaxLine: integer): TMessageLineEnumerator;
begin
  Result:=TMessageLineEnumerator.Create(FSortedForSrcPos,aFilename,MinLine,MaxLine);
end;

procedure TMessageLines.AddChangedHandler(const OnLineChanged: TNotifyEvent;
  AsFirst: boolean);
begin
  fChangedHandler.Add(TMethod(OnLineChanged),not AsFirst);
end;

procedure TMessageLines.RemoveChangedHandler(const OnLineChanged: TNotifyEvent);
begin
  fChangedHandler.Remove(TMethod(OnLineChanged));
end;

procedure TMessageLines.ConsistencyCheck;
begin
  FSortedForSrcPos.ConsistencyCheck;
end;

{ TMessageLine }

//inline
function TMessageLine.GetShortFilename: string;
begin
  Result:=ExtractFileName(Filename);
end;

//inline
function TMessageLine.GetFullFilename: string;
begin
  Result:=Filename;
end;

function TMessageLine.GetAttribute(const Identifier: string): string;
begin
  if fAttributes=nil then
    Result:=''
  else
    Result:=fAttributes.Values[Identifier];
end;

procedure TMessageLine.SetAttribute(const Identifier: string;
  const AValue: string);
begin
  if GetAttribute(Identifier)=AValue then exit;
  if fAttributes=nil then
    fAttributes:=TStringList.Create;
  fAttributes.Values[Identifier]:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetColumn(const AValue: integer);
begin
  if FColumn=AValue then exit;
  SortedSrcPosUnbind;
  FColumn:=AValue;
  SortedSrcPosBind;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetFilename(AValue: string);
begin
  AValue:=TrimFilename(AValue);
  if not FilenameIsAbsolute(AValue) then begin
    if (FLines<>nil)
    and (FLines.BaseDirectory<>'') then
      AValue:=AppendPathDelim(FLines.BaseDirectory)+AValue;
  end;
  if FFilename=AValue then exit;
  SortedSrcPosUnbind;
  FFilename:=AValue;
  SortedSrcPosBind;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetFlags(AValue: TMessageLineFlags);
begin
  if FFlags=AValue then Exit;
  FFlags:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetLine(const AValue: integer);
begin
  if FLine=AValue then exit;
  SortedSrcPosUnbind;
  FLine:=AValue;
  SortedSrcPosBind;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SortedSrcPosBind;
begin
  if (Index>=0) and Lines.UpdateSortedSrcPos then
    Lines.FSortedForSrcPos.Add(Self);
end;

procedure TMessageLine.SortedSrcPosUnbind;
begin
  if (Index>=0) and Lines.UpdateSortedSrcPos then
    Lines.FSortedForSrcPos.Remove(Self);
end;

procedure TMessageLine.SetLines(AValue: TMessageLines);
begin
  if FLines=AValue then exit;
  if FLines<>nil then begin
    SortedSrcPosUnbind;
    FLines.Remove(Self);
  end;
  FLines:=AValue;
  if FLines<>nil then begin
    FLines.Add(Self);
    if (not FilenameIsAbsolute(FFilename))
    and (Lines.BaseDirectory<>'') then
      FFilename:=AppendPathDelim(Lines.BaseDirectory)+FFilename;
    SortedSrcPosBind;
  end else
    FLines:=nil;
end;

procedure TMessageLine.SetMsg(AValue: string);
begin
  if FMsg=AValue then Exit;
  FMsg:=AValue;
  FTranslatedMsg:='';
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetMsgID(AValue: integer);
begin
  if FMsgID=AValue then Exit;
  FMsgID:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetSubTool(AValue: string);
begin
  if FSubTool=AValue then Exit;
  FSubTool:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetSubType(AValue: PtrUInt);
begin
  if FSubType=AValue then Exit;
  FSubType:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetTranslatedMsg(AValue: string);
begin
  if FTranslatedMsg=AValue then Exit;
  FTranslatedMsg:=AValue;
  IncreaseChangeStamp;
end;

procedure TMessageLine.SetUrgency(AValue: TMessageLineUrgency);
begin
  if FUrgency=AValue then Exit;
  if Index>=0 then
    dec(Lines.UrgencyCounts[Urgency]);
  FUrgency:=AValue;
  if Index>=0 then
    inc(Lines.UrgencyCounts[Urgency]);
  IncreaseChangeStamp;
end;

constructor TMessageLine.Create;
begin
  inherited Create;
  FIndex:=-1;
  FOutputIndex:=-1;
  IncreaseChangeStamp;
end;

destructor TMessageLine.Destroy;
begin
  FreeAndNil(fAttributes);
  inherited Destroy;
end;

procedure TMessageLine.Assign(Source: TMessageLine);
begin
  if Source.fAttributes<>nil then begin
    if fAttributes=nil then
      fAttributes:=TStringList.Create;
    fAttributes.Assign(Source.fAttributes);
  end else begin
    FreeAndNil(fAttributes);
  end;
  Urgency:=Source.Urgency;
  Column:=Source.Column;
  Filename:=Source.Filename;
  Flags:=Source.Flags;
  Line:=Source.Line;
  Msg:=Source.Msg;
  MsgID:=Source.MsgID;
  fOutputIndex:=Source.OutputIndex;
  SubTool:=Source.SubTool;
  SubType:=Source.SubType;
  TranslatedMsg:=Source.TranslatedMsg;
  IncreaseChangeStamp;
end;

function TMessageLine.Equals(Obj: TObject): boolean;
var
  Source: TMessageLine;
begin
  if Obj is TMessageLine then begin
    Source:=TMessageLine(Obj);
    Result:=false;
    if Source.fAttributes<>nil then begin
      if fAttributes=nil then exit;
      if not fAttributes.Equals(Source.fAttributes) then exit;
    end else begin
      if (fAttributes<>nil) and (fAttributes.Count>0) then
        exit;
    end;
    Result:=(Urgency=Source.Urgency)
        and (Column=Source.Column)
        and (Filename=Source.Filename)
        and (Flags=Source.Flags)
        and (Line=Source.Line)
        and (Msg=Source.Msg)
        and (MsgID=Source.MsgID)
        and (fOutputIndex=Source.OutputIndex)
        and (SubTool=Source.SubTool)
        and (SubType=Source.SubType)
        and (TranslatedMsg=Source.TranslatedMsg);
  end else
    Result:=inherited Equals(Obj);
end;

procedure TMessageLine.Clear;
begin
  SubTool:='';
  Msg:='';
  TranslatedMsg:='';
  Filename:='';
  FreeAndNil(fAttributes);
end;

function TMessageLine.GetRelativeFilename: string;
begin
  Result:=FFilename;
  if (Lines<>nil) and (Lines.BaseDirectory<>'') then
    Result:=CreateRelativePath(Result,FLines.BaseDirectory);
end;

procedure TMessageLine.ShareStrings(const ShareStringEvent: TETShareStringEvent);
var
  i: Integer;
  s: String;
begin
  ShareStringEvent(FFilename);
  ShareStringEvent(FMsg);
  ShareStringEvent(FTranslatedMsg);
  ShareStringEvent(FSubTool);
  if fAttributes<>nil then begin
    for i:=0 to fAttributes.Count-1 do begin
      s:=fAttributes[i];
      ShareStringEvent(s);
      fAttributes[i]:=s;
    end;
  end;
end;

procedure TMessageLine.SetSourcePosition(NewFilename: string; NewLine,
  NewColumn: integer);
begin
  NewFilename:=TrimFilename(NewFilename);
  if (FFilename=NewFilename) and (NewLine=Line) and (NewColumn=Column) then exit;
  SortedSrcPosUnbind;
  FFilename:=NewFilename;
  FLine:=NewLine;
  FColumn:=NewColumn;
  SortedSrcPosBind;
  IncreaseChangeStamp;
end;

procedure TMessageLine.IncreaseChangeStamp;
begin
  if Lines<>nil then begin
    Lines.LineChanged(Self);
    FChangeStamp:=Lines.ChangeStamp;
  end else
    LUIncreaseChangeStamp64(FChangeStamp);
end;

procedure TMessageLine.MarkFixed;
begin
  Lines.MarkFixed(Self);
end;

function TMessageLine.HasSourcePosition: boolean;
begin
  Result:=(Line>0) and (Column>0) and (GetFullFilename<>'');
end;

procedure TMessageLine.GetAttributes(List: TStrings);
begin
  if fAttributes<>nil then
    List.Assign(fAttributes)
  else
    List.Clear;
  List.Values['Urgency']:=MessageLineUrgencyNames[Urgency];
  List.Values['SubTool']:=SubTool;
  List.Values['SubType']:=IntToStr(SubType);
  List.Values['File']:=Filename;
  List.Values['Line']:=IntToStr(Line);
  List.Values['Col']:=IntToStr(Column);
  List.Values['Msg']:=Msg;
  List.Values['MsgID']:=IntToStr(MsgID);
  List.Values['OriginalLine']:=OriginalLine;
end;

function TMessageLine.GetToolData: TIDEExternalToolData;
var
  Tool: TAbstractExternalTool;
begin
  Result:=nil;
  if Lines=nil then exit;
  if Lines.Owner is TAbstractExternalTool then
    Tool:=TAbstractExternalTool(Lines.Owner)
  else if Lines.Owner is TExtToolView then begin
    Tool:=TExtToolView(Lines.Owner).Tool;
    if Tool=nil then exit;
  end else
    exit;
  Result:=TIDEExternalToolData(Tool.Data);
  if not (Result is TIDEExternalToolData) then
    Result:=nil;
end;

{ TExtToolView }

procedure TExtToolView.FetchAllPending;
begin
  Lines.FetchAll(PendingLines);
end;

procedure TExtToolView.ToolExited;
begin
  ;
end;

procedure TExtToolView.QueueAsyncOnChanged;
begin
  raise Exception.Create('TExtToolView.QueueAsyncOnChanged should be overridden when needed.');
end;

procedure TExtToolView.RemoveAsyncOnChanged;
begin
  ;
end;

procedure TExtToolView.CreateLines;
begin
  FLines:=TMessageLines.Create(Self, FMessageLineClass);
  FProgressLine:=FMessageLineClass.Create;
  FPendingLines:=TMessageLines.Create(Self, FMessageLineClass);
  FPendingProgressLine:=FMessageLineClass.Create;
end;

constructor TExtToolView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  if FMessageLineClass=nil then
    FMessageLineClass:=TMessageLine;
  CreateLines;
  FRunning:=true;
  FMinUrgency:=DefaultETViewMinUrgency;
  FLastWorkerMessageCount:=-1;
end;

destructor TExtToolView.Destroy;
begin
  if (Tool<>nil) and (not (csDestroying in Tool.ComponentState)) then
    Tool.RemoveView(Self);
  // no need for EnterCriticalSection, issue 38959
  RemoveAsyncOnChanged;
  ClearLines;
  FreeAndNil(FProgressLine);
  FreeAndNil(FPendingLines);
  FreeAndNil(FPendingProgressLine);
  inherited Destroy;
  FreeAndNil(FLines);
end;

procedure TExtToolView.ProcessNewMessages(AThread: TThread);
{ Called by TExternalTool.AddOutputLines
  Tool is in Critical section
}
var
  i: Integer;
  SrcMsg: TMessageLine;
  NewMsg: TMessageLine;
  Changed: Boolean;
  NewProgressLine: TMessageLine;
begin
  if csDestroying in ComponentState then exit;
  Changed:=false;
  EnterCriticalSection; // Beware: Tool is already in critical section
  try
    if (FPendingLines=nil) or (FPendingProgressLine=nil) then exit;
    //DebugLn(['TExtToolView.ProcessNewMessages START From=',FirstMsgLine,' To=',Tool.WorkerMessages.Count-1]);
    NewProgressLine:=nil;
    for i:=FLastWorkerMessageCount+1 to Tool.WorkerMessages.Count-1 do begin
      SrcMsg:=Tool.WorkerMessages[i];
      //debugln(['TExtToolView.ProcessNewMessages Msg="',SrcMsg.Msg,'" Fits=',LineFits(SrcMsg)]);
      if LineFits(SrcMsg) then begin
        NewProgressLine:=nil;
        Changed:=true;
        NewMsg:=PendingLines.CreateLine(-1);
        NewMsg.Assign(SrcMsg);
        //debugln(['TExtToolView.ProcessNewMessages NewMsg=',Lines.Count,'="',NewMsg.Msg,'"']);
        PendingLines.Add(NewMsg);
      end else begin
        NewProgressLine:=SrcMsg;
      end;
    end;
    FLastWorkerMessageCount:=Tool.WorkerMessages.Count-1;
    if (NewProgressLine<>nil) and Running then begin
      Changed:=true;
      PendingProgressLine.Assign(NewProgressLine);
    end
    else if PendingProgressLine.Msg<>'' then begin
      Changed:=true;
      PendingProgressLine.Msg:='';
    end;
    //debugln(['TExtToolView.ProcessNewMessages END Changed=',Changed,' Progress="',ProgressLine.Msg,'"']);
  finally
    LeaveCriticalSection;
  end;

  if Changed and Assigned(OnChanged) then begin
    // wake up main thread
    QueueAsyncOnChanged;
  end;
end;

procedure TExtToolView.ClearLines;
var
  i: Integer;
begin
  EnterCriticalSection;
  try
    FLastWorkerMessageCount:=-1;
    if Lines<>nil then
      Lines.Clear;
    if ProgressLine<>nil then
      ProgressLine.Clear;
    if PendingLines<>nil then begin
      for i:=0 to PendingLines.Count-1 do
        TObject(PendingLines[i]).Free;
      PendingLines.Clear;
    end;
    if PendingProgressLine<>nil then
      PendingProgressLine.Clear;
  finally
    LeaveCriticalSection;
  end;
end;

function TExtToolView.ApplyPending: boolean;
// returns true if something changed
begin
  Result:=false;
  if csDestroying in ComponentState then exit;
  EnterCriticalSection;
  try
    if csDestroying in ComponentState then exit;
    if PendingLines.Count>0 then begin
      FetchAllPending;
      Result:=true;
    end;
    if not ProgressLine.Equals(PendingProgressLine) then begin
      ProgressLine.Assign(PendingProgressLine);
      Result:=true;
    end;
  finally
    LeaveCriticalSection;
  end;
end;

procedure TExtToolView.InputClosed;
begin
  if csDestroying in ComponentState then exit;
  if not Running then begin
    raise Exception.Create('TExtToolView.InputClosed already closed: '+Caption);
  end;
  FRunning:=false;
  EnterCriticalSection;
  try
    if csDestroying in ComponentState then exit;
    if PendingProgressLine.Msg<>'' then
      PendingProgressLine.Clear;
  finally
    LeaveCriticalSection;
  end;
  if Tool<>nil then begin
    ExitCode:=Tool.ExitCode;
    ExitStatus:=Tool.ExitStatus;
  end;
  ToolExited;
  if Assigned(OnChanged) then begin
    RemoveAsyncOnChanged;
    OnChanged(Self);
  end;
end;

function TExtToolView.LineFits(Line: TMessageLine): boolean;
begin
  Result:=(Line.Msg<>'') and (Line.Urgency>=MinUrgency);
end;

procedure TExtToolView.EnterCriticalSection;
begin
  FLines.EnterCriticalSection;
end;

procedure TExtToolView.LeaveCriticalSection;
begin
  FLines.LeaveCriticalSection;
end;

procedure TExtToolView.ConsistencyCheck;
begin
  EnterCriticalSection;
  try
    FLines.ConsistencyCheck;
    FPendingLines.ConsistencyCheck;
  finally
    LeaveCriticalSection;
  end;
end;

function TExtToolView.HasFinished: boolean;
begin
  Result:=false;
  EnterCriticalSection;
  try
    if Running then exit;
    if (Tool<>nil) and (Tool.Stage<>etsStopped) then exit;
    if PendingLines.Count>0 then exit;
    Result:=true;
  finally
    LeaveCriticalSection;
  end;
end;

initialization
  // on single cores there is delay due to file reads
  // => use 2 processes in parallel by default
  DefaultMaxProcessCount:=Max(2,GetSystemThreadCount);

end.


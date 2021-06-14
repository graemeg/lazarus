{
 ---------------------------------------------------------------------------
 FpDebugDebugger
 ---------------------------------------------------------------------------

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

unit FpDebugDebugger;

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}
{$ModeSwitch advancedrecords}

interface

uses
  Classes, SysUtils, fgl, math, process,
  Forms, Dialogs,
  Maps, LazLogger, LazUTF8,
  DbgIntfBaseTypes, DbgIntfDebuggerBase,
  FpDebugDebuggerUtils, FpDebugDebuggerWorkThreads,
  // FpDebug
  {$IFDEF FPDEBUG_THREAD_CHECK} FpDbgCommon, {$ENDIF}
  FpDbgClasses, FpDbgInfo, FpErrorMessages, FpPascalBuilder, FpdMemoryTools,
  FpPascalParser, FPDbgController, FpDbgDwarfDataClasses, FpDbgDwarfFreePascal,
  FpDbgDwarf, FpDbgUtil;

type

  TFpDebugDebugger = class;
  TFPBreakpoint = class;

  (* WorkerThreads:
     The below subclasses implement ONLY work that is done in the MAIN THREAD.
  *)

  { TFpDbgDebggerThreadWorkerItemHelper }

  TFpDbgDebggerThreadWorkerItemHelper = class helper for TFpDbgDebggerThreadWorkerItem
  protected
    function FpDebugger: TFpDebugDebugger; inline;
  end;

  { TFpThreadWorkerRunLoopUpdate }

  TFpThreadWorkerRunLoopUpdate = class(TFpThreadWorkerRunLoop)
  protected
     procedure LoopFinished_DecRef(Data: PtrInt = 0); override;
  end;

  { TFpThreadWorkerRunLoopAfterIdleUpdate }

  TFpThreadWorkerRunLoopAfterIdleUpdate = class(TFpThreadWorkerRunLoopAfterIdle)
  protected
    procedure CheckIdleOrRun_DecRef(Data: PtrInt = 0); override;
  end;

  { TFpThreadWorkerCallStackCountUpdate }

  TFpThreadWorkerCallStackCountUpdate = class(TFpThreadWorkerCallStackCount)
  private
    FCallstack: TCallStackBase;
    procedure DoCallstackFreed_DecRef(Sender: TObject);
  protected
    procedure UpdateCallstack_DecRef(Data: PtrInt = 0); override;
    procedure DoRemovedFromLinkedList; override;
  public
    constructor Create(ADebugger: TFpDebugDebugger; ACallstack: TCallStackBase; ARequiredMinCount: Integer);
    //procedure RemoveCallStack_DecRef;
  end;

  { TFpThreadWorkerCallEntryUpdate }

  TFpThreadWorkerCallEntryUpdate = class(TFpThreadWorkerCallEntry)
  private
    FCallstack: TCallStackBase;
    FCallstackEntry: TCallStackEntry;
    procedure DoCallstackFreed_DecRef(Sender: TObject);
    procedure DoCallstackEntryFreed_DecRef(Sender: TObject);
    procedure DoRemovedFromLinkedList; override;
  protected
    procedure UpdateCallstackEntry_DecRef(Data: PtrInt = 0); override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; AThread: TDbgThread; ACallstackEntry: TCallStackEntry; ACallstack: TCallStackBase = nil);
    //procedure RemoveCallStackEntry_DecRef;
  end;

  { TFpThreadWorkerThreadsUpdate }

  TFpThreadWorkerThreadsUpdate = class(TFpThreadWorkerThreads)
  protected
    procedure UpdateThreads_DecRef(Data: PtrInt = 0); override;
  end;

  { TFpThreadWorkerLocalsUpdate }

  TFpThreadWorkerLocalsUpdate = class(TFpThreadWorkerLocals)
  private
    FLocals: TLocals;
    procedure DoLocalsFreed_DecRef(Sender: TObject);
  protected
    procedure UpdateLocals_DecRef(Data: PtrInt = 0); override;
    procedure DoRemovedFromLinkedList; override; // _DecRef
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; ALocals: TLocals);
  end;

  { TFpThreadWorkerModifyUpdate }

  TFpThreadWorkerModifyUpdate = class(TFpThreadWorkerModify)
  protected
    procedure DoCallback_DecRef(Data: PtrInt = 0); override;
  end;

  { TFpThreadWorkerWatchValueEvalUpdate }

  TFpThreadWorkerWatchValueEvalUpdate = class(TFpThreadWorkerWatchValueEval)
  private
    FWatchValue: TWatchValue;
    procedure DoWatchFreed_DecRef(Sender: TObject);
  protected
    procedure UpdateWatch_DecRef(Data: PtrInt = 0); override;
    procedure DoRemovedFromLinkedList; override; // _DecRef
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; AWatchValue: TWatchValue);
  end;

  { TFpThreadWorkerBreakPointSetUpdate }

  TFpThreadWorkerBreakPointSetUpdate = class(TFpThreadWorkerBreakPointSet)
  private
    FDbgBreakPoint: TFPBreakpoint;
  protected
     procedure UpdateBrkPoint_DecRef(Data: PtrInt = 0); override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; ADbgBreakPoint: TFPBreakpoint); overload;
    procedure AbortSetBreak; override;
    procedure RemoveBreakPoint_DecRef; override;
  end;

  { TFpThreadWorkerBreakPointRemoveUpdate }

  TFpThreadWorkerBreakPointRemoveUpdate = class(TFpThreadWorkerBreakPointRemove)
  protected
    procedure DoUnQueued; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; ADbgBreakPoint: TFPBreakpoint); overload;
  end;

  { TDbgControllerStepOverOrFinallyCmd
    Step over with detection for finally blocks
  }

  TDbgControllerStepOverOrFinallyCmd = class(TDbgControllerStepOverLineCmd)
  private
    FFinState: (fsNone, fsMov, fsCall, fsInFin);
  protected
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread;
      out Finished: boolean); override;
  end;

  { TDbgControllerStepOverFirstFinallyLineCmd }

  TDbgControllerStepOverFirstFinallyLineCmd = class(TDbgControllerStepOverLineCmd)
  protected
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread;
      out Finished: boolean); override;
  end;

  { TDbgControllerStepThroughFpcSpecialHandler }

  TDbgControllerStepThroughFpcSpecialHandler = class(TDbgControllerStepOverInstructionCmd)
  private
    FAfterFinCallAddr: TDbgPtr;
    FDone: Boolean;
  protected
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
    procedure Init; override;
  public
    constructor Create(AController: TDbgController; AnAfterFinCallAddr: TDbgPtr); reintroduce;
  end;

  { TFpDebugExceptionStepping }

  TFpDebugExceptionStepping = class
  (* Methods in this class are either called:
     - by the debug-thread / in the context of the debug-thread
     - by the main-thread / But ONLY if the debug-thread is paused
     Starting the debug-thread uses "RTLeventSetEvent" which triggers a
     memory barrier. So memberfields can be used savely between all methods.
  *)
  private
  type
    TBreakPointLoc = (
      bplRaise, bplReRaise, bplBreakError, bplRunError,
      bplPopExcept, bplCatches,
      bplRtlUnwind, bplFpcSpecific,
      bplSehW64Finally, bplSehW64Except,
      bplStepOut  // Step out of Pop/Catches
    );
    TBreakPointLocs = set of TBreakPointLoc;
    TExceptStepState = (esNone,
      esStoppedAtRaise,  // Enter dsPause, next step is "stop to finally"
      esIgnoredRaise,    // Keep dsRun, stop at finally/except *IF* outside current stepping frame
      esStepToFinally,
      esStepSehFinallyProloque,
      esSteppingFpcSpecialHandler,
      esAtWSehExcept
    );
    TFrameList = class(specialize TFPGList<TDbgPtr>);

    { TAddressFrameList }

    TAddressFrameList = class(specialize TFPGMapObject<TDbgPtr, TFrameList>)
    public
      function Add(const AKey: TDbgPtr): TFrameList; inline;
    end;
  const
    DBGPTRSIZE: array[TFPDMode] of Integer = (4, 8);
  private
    FDebugger: TFpDebugDebugger;
    FBreakPoints: array[TBreakPointLoc] of TFpDbgBreakpoint;
    FBreakEnabled: TBreakPointLocs;
    FBreakNewEnabled: TBreakPointLocs;
    FAddressFrameList: TAddressFrameList;
    FState: TExceptStepState;
    function GetCurrentCommand: TDbgControllerCmd; inline;
    function GetCurrentProcess: TDbgProcess; inline;
    function GetCurrentThread: TDbgThread; inline;
    function GetDbgController: TDbgController; inline;
    function dbgs(st: TExceptStepState): string;
    function dbgs(loc: TBreakPointLoc): string;
    function dbgs(locs: TBreakPointLocs): string;
  protected
    property DbgController: TDbgController read GetDbgController;
    property CurrentProcess: TDbgProcess read GetCurrentProcess;
    property CurrentThread: TDbgThread read GetCurrentThread;
    property CurrentCommand: TDbgControllerCmd read GetCurrentCommand;

    procedure EnableBreaks(ALocs: TBreakPointLocs);
    procedure EnableBreaksDirect(ALocs: TBreakPointLocs); // only in dbg thread
    procedure DisableBreaks(ALocs: TBreakPointLocs);
    procedure DisableBreaksDirect(ALocs: TBreakPointLocs); // only in dbg thread
    procedure SetStepOutAddrDirect(AnAddr: TDBGPtr); // only in dbg thread

    procedure DoExceptionRaised(var &continue: boolean);
    //procedure DoPopExcptStack;
    procedure DoRtlUnwindEx;
  public
    constructor Create(ADebugger: TFpDebugDebugger);
    destructor Destroy; override;

    procedure DoProcessLoaded;
    procedure DoNtDllLoaded(ALib: TDbgLibrary);
    //procedure DoLibraryLoaded(ALib: TDbgLibrary);  // update breakpoints
    procedure DoDbgStopped;

    procedure ThreadBeforeLoop(Sender: TObject);
    procedure ThreadProcessLoopCycle(var AFinishLoopAndSendEvents: boolean;
      var AnEventType: TFPDEvent; var ACurCommand: TDbgControllerCmd; var AnIsFinished: boolean);
    function  BreakpointHit(var &continue: boolean; const Breakpoint: TFpDbgBreakpoint): boolean;
    procedure UserCommandRequested(var ACommand: TDBGCommand);

//    procedure ClearState;
  end;

  { TFpDebugDebugger }

  TFpDebugDebugger = class(TFpDebugDebuggerBase)
  private
    FIsIdle: Boolean;
    FPrettyPrinter: TFpPascalPrettyPrinter;
    FStartupCommand: TDBGCommand;
    FStartuRunToFile: string;
    FStartuRunToLine: LongInt;
    (* Each thread must only lock max one item at a time.
       This ensures the locking will be dead-lock free.
    *)
    FWorkerThreadId: TThreadID;
    FEvalWorkItem: TFpThreadWorkerCmdEval;
    FQuickPause, FPauseForEvent, FSendingEvents: boolean;
    FExceptionStepper: TFpDebugExceptionStepping;
    FConsoleOutputThread: TThread;
    // Helper vars to run in debug-thread
    FCacheLine, FCacheBytesRead: cardinal;
    FCacheFileName: string;
    FCacheLib: TDbgLibrary;
    FCacheBreakpoint: TFpDbgBreakpoint;
    FCacheLocation, FCacheLocation2: TDBGPtr;
    FCacheBoolean: boolean;
    FCachePointer: pointer;
    FCacheThreadId, FCacheStackFrame: Integer;
    FCacheContext: TFpDbgSymbolScope;
    //
    function GetClassInstanceName(AnAddr: TDBGPtr): string;
    function ReadAnsiString(AnAddr: TDbgPtr): string;
    procedure HandleSoftwareException(out AnExceptionLocation: TDBGLocationRec; var continue: boolean);
    // HandleBreakError: Default handler for range-check etc
    procedure HandleBreakError(var continue: boolean);
    // HandleRunError: Software called RuntimeError
    procedure HandleRunError(var continue: boolean);
    procedure FreeDebugThread;
    procedure FDbgControllerHitBreakpointEvent(var continue: boolean;
      const Breakpoint: TFpDbgBreakpoint; AnEventType: TFPDEvent; AMoreHitEventsPending: Boolean);
    procedure EnterPause(ALocationAddr: TDBGLocationRec; AnInternalPause: Boolean = False);
    procedure FDbgControllerCreateProcessEvent(var {%H-}continue: boolean);
    procedure FDbgControllerProcessExitEvent(AExitCode: DWord);
    procedure FDbgControllerExceptionEvent(var continue: boolean; const ExceptionClass, ExceptionMessage: string);
    procedure FDbgControllerDebugInfoLoaded(Sender: TObject);
    procedure FDbgControllerLibraryLoaded(var continue: boolean; ALib: TDbgLibrary);
    procedure FDbgControllerLibraryUnloaded(var continue: boolean; ALib: TDbgLibrary);
    function GetDebugInfo: TDbgInfo;
  protected
    procedure GetCurrentThreadAndStackFrame(out AThreadId, AStackFrame: Integer);
    function GetContextForEvaluate(const ThreadId, StackFrame: Integer): TFpDbgSymbolScope;

    function CreateLineInfo: TDBGLineInfo; override;
    function CreateWatches: TWatchesSupplier; override;
    function CreateThreads: TThreadsSupplier; override;
    function CreateLocals: TLocalsSupplier; override;
    function  CreateRegisters: TRegisterSupplier; override;
    function CreateCallStack: TCallStackSupplier; override;
    function CreateDisassembler: TDBGDisassembler; override;
    function CreateBreakPoints: TDBGBreakPoints; override;
    function  RequestCommand(const ACommand: TDBGCommand;
                             const AParams: array of const;
                             const ACallback: TMethod): Boolean; override;
    function ChangeFileName: Boolean; override;

    // On Linux, communication with the debuggee is only allowed from within
    // the thread that created the debuggee. So a method to execute functions
    // within the debug-thread is necessary.
    function  ExecuteInDebugThread(AMethod: TFpDbgAsyncMethod): boolean;
    procedure StartDebugLoop(AState: TDBGState = dsRun);
    procedure DebugLoopFinished({%H-}Data: PtrInt);
    (* Any item that requests a QuickPause must be called from RunQuickPauseTasks
       A QuickPause may skip changing the debugger.State.
    *)
    procedure QuickPause;
    procedure RunQuickPauseTasks(AForce: Boolean = False);
    procedure DoRelease; override;
    procedure CheckAndRunIdle;
    procedure DoBeforeState(const OldState: TDBGState); override;
    procedure DoState(const OldState: TDBGState); override;
    function GetIsIdle: Boolean; override;
    function GetCommands: TDBGCommands; override;

  protected
    // Helper vars to run in debug-thread
    FCallStackEntryListThread: TDbgThread;
    FCallStackEntryListFrameRequired: Integer;
    procedure DoAddBreakFuncLib;
    procedure DoAddBreakLocation;
    procedure DoReadData;
    procedure DoReadPartialData;
    procedure DoFindContext;
    procedure DoSetStackFrameForBasePtr;
    //
    function AddBreak(const ALocation: TDbgPtr; AnEnabled: Boolean = True): TFpDbgBreakpoint; overload;
    function AddBreak(const AFuncName: String; ALib: TDbgLibrary = nil; AnEnabled: Boolean = True): TFpDbgBreakpoint; overload;
    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean; inline;
    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData; out ABytesRead: Cardinal): Boolean; inline;
    function ReadAddress(const AAdress: TDbgPtr; out AData: TDBGPtr): Boolean;
    function SetStackFrameForBasePtr(ABasePtr: TDBGPtr; ASearchAssert: boolean = False;
      CurAddr: TDBGPtr = 0): TDBGPtr;
    function  FindSymbolScope(AThreadId, AStackFrame: Integer): TFpDbgSymbolScope; inline;
    procedure StopAllWorkers;
    function IsPausedAndValid: boolean; // ready for eval watches/stack....

    property DebugInfo: TDbgInfo read GetDebugInfo;
  public
    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
    procedure LockCommandProcessing; override;
    procedure UnLockCommandProcessing; override;
    function GetLocationRec(AnAddress: TDBGPtr=0; AnAddrOffset: Integer = 0): TDBGLocationRec;
    function GetLocation: TDBGLocationRec; override;
    class function Caption: String; override;
    class function NeedsExePath: boolean; override;
    class function RequiredCompilerOpts({%H-}ATargetCPU, {%H-}ATargetOS: String): TDebugCompilerRequirements; override;
    class function CreateProperties: TDebuggerProperties; override;
    class function  GetSupportedCommands: TDBGCommands; override;
    class function SupportedCommandsFor(AState: TDBGState): TDBGCommands; override;
    class function SupportedFeatures: TDBGFeatures; override;
  end;

  { TFpLineInfo }

  TFpLineInfo = class(TDBGLineInfo) //class(TGDBMILineInfo)
  private
    FRequestedSources: TStringListUTF8Fast;
  protected
    function  FpDebugger: TFpDebugDebugger;
    procedure DoStateChange(const {%H-}AOldState: TDBGState); override;
    procedure ClearSources;
    procedure DebugInfoChanged;
  public
    constructor Create(const ADebugger: TDebuggerIntf);
    destructor Destroy; override;
    function Count: Integer; override;
    function HasAddress(const AIndex: Integer; const ALine: Integer): Boolean; override;
    function GetInfo({%H-}AAddress: TDbgPtr; out {%H-}ASource, {%H-}ALine, {%H-}AOffset: Integer): Boolean; override;
    function IndexOf(const ASource: String): integer; override;
    procedure Request(const ASource: String); override;
    procedure Cancel(const {%H-}ASource: String); override;
  end;

  { TFPWatches }

  TFPWatches = class(TWatchesSupplier)
  protected
    FWatchEvalWorkers: TFpDbgDebggerThreadWorkerLinkedList;
    function  FpDebugger: TFpDebugDebugger;
    procedure StopWorkes;
    procedure DoStateLeavePause; override;
    procedure InternalRequestData(AWatchValue: TWatchValue); override;
  public
    destructor Destroy; override;
  end;

  { TFPCallStackSupplier }

  TFPCallStackSupplier = class(TCallStackSupplier)
  private
    FPrettyPrinter: TFpPascalPrettyPrinter;
    FInitialFrame: Integer;
    FThreadForInitialFrame: Integer;
    FCallStackWorkers: TFpDbgDebggerThreadWorkerLinkedList;
  protected
    function  FpDebugger: TFpDebugDebugger;
    procedure StopWorkes;
    procedure DoStateLeavePause; override;
  public
    constructor Create(const ADebugger: TDebuggerIntf);
    destructor Destroy; override;
    procedure RequestCount(ACallstack: TCallStackBase); override;
    procedure RequestAtLeastCount(ACallstack: TCallStackBase;
      ARequiredMinCount: Integer); override;
    procedure RequestEntries(ACallstack: TCallStackBase); override;
    procedure RequestCurrent(ACallstack: TCallStackBase); override;
    procedure UpdateCurrentIndex; override;
  end;

  { TFPLocals }

  TFPLocals = class(TLocalsSupplier)
  protected
    FLocalWorkers: TFpDbgDebggerThreadWorkerLinkedList;
    function  FpDebugger: TFpDebugDebugger;
    procedure StopWorkes;
    procedure DoStateLeavePause; override;
  public
    destructor Destroy; override;
    procedure RequestData(ALocals: TLocals); override;
  end;

  { TFPRegisters }

  TFPRegisters = class(TRegisterSupplier)
  public
    procedure RequestData(ARegisters: TRegisters); override;
  end;

  { TFPThreads }

  TFPThreads = class(TThreadsSupplier)
  protected
    FThreadWorkers: TFpDbgDebggerThreadWorkerLinkedList;
    procedure DoStateEnterPause; override;
    procedure DoStateChange(const AOldState: TDBGState); override;
    procedure StopWorkes;
    procedure DoStateLeavePause; override;
    procedure RequestEntries;  // Only fill the list, no data for entries yet
  public
    destructor Destroy; override;
    procedure RequestMasterData; override;
    procedure ChangeCurrentThread(ANewId: Integer); override;
  end;

  { TFPDBGDisassembler }

  TFPDBGDisassembler = class(TDBGDisassembler)
  protected
    function PrepareEntries(AnAddr: TDbgPtr; ALinesBefore, ALinesAfter: Integer): boolean; override;
  end;

  { TFPBreakpoint }

  TFPBreakpoint = class(TDBGBreakPoint)
  private
    FThreadWorker: TFpThreadWorkerBreakPoint;
    FSetBreakFlag: boolean;
    FResetBreakFlag: boolean;
    FInternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint;
    FIsSet: boolean;
    procedure SetBreak;
    procedure ResetBreak;
  protected
    procedure DoStateChange(const AOldState: TDBGState); override;
    procedure DoEnableChange; override;
    procedure DoChanged; override;
    property  Validity: TValidState write SetValid;
  public
    destructor Destroy; override;
  end;

  { TFPBreakpoints }

  TFPBreakpoints = class(TDBGBreakPoints)
  public
    function Find(AIntBReakpoint: FpDbgClasses.TFpDbgBreakpoint): TDBGBreakPoint;
  end;

procedure Register;

implementation

uses
  FpDbgDisasX86;

var
  DBG_VERBOSE, DBG_WARNINGS, DBG_BREAKPOINTS, FPDBG_COMMANDS: PLazLoggerLogGroup;

type

  { TFpDbgMemReader }

  TFpDbgMemReader = class(TDbgMemReader)
  private
    FFpDebugDebugger: TFpDebugDebugger;
    FRegNum: Cardinal;
    FRegValue: TDbgPtr;
    FRegContext: TFpDbgLocationContext;
    FRegResult: Boolean;
    procedure DoReadRegister;
  protected
    function GetDbgProcess: TDbgProcess; override;
    function GetDbgThread(AContext: TFpDbgLocationContext): TDbgThread; override;
  public
    constructor create(AFpDebugDebuger: TFpDebugDebugger);
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override; overload;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer;
      out ABytesRead: Cardinal): Boolean; override; overload;
    function ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    function ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr;
      AContext: TFpDbgLocationContext): Boolean; override;
    //WriteMemory is not overwritten. It must ONLY be called in the debug-thread
  end;

  { TFpWaitForConsoleOutputThread }

  TFpWaitForConsoleOutputThread = class(TThread)
  private
    FFpDebugDebugger: TFpDebugDebugger;
    FHasConsoleOutputQueued: PRTLEvent;
    procedure DoHasConsoleOutput(Data: PtrInt);
  public
    constructor Create(AFpDebugDebugger: TFpDebugDebugger);
    destructor Destroy; override;
    procedure Execute; override;
  end;


procedure Register;
begin
  RegisterDebugger(TFpDebugDebugger);
end;

{ TFpThreadWorkerModifyUpdate }

procedure TFpThreadWorkerModifyUpdate.DoCallback_DecRef(Data: PtrInt);
begin
  //
  FDebugger.Locals.CurrentLocalsList.Clear;
  FDebugger.Watches.CurrentWatches.ClearValues;
  FDebugger.CallStack.CurrentCallStackList.Clear;

  UnQueue_DecRef;
end;

{ TFpDbgDebggerThreadWorkerItemHelper }

function TFpDbgDebggerThreadWorkerItemHelper.FpDebugger: TFpDebugDebugger;
begin
  Result := TFpDebugDebugger(FDebugger);
end;

{ TFpThreadWorkerRunLoopUpdate }

procedure TFpThreadWorkerRunLoopUpdate.LoopFinished_DecRef(Data: PtrInt);
var
  dbg: TFpDebugDebugger;
begin
  dbg := FpDebugger;
  UnQueue_DecRef;
  // self may now be invalid
  dbg.DebugLoopFinished(0);
end;

{ TFpThreadWorkerRunLoopAfterIdleUpdate }

procedure TFpThreadWorkerRunLoopAfterIdleUpdate.CheckIdleOrRun_DecRef(
  Data: PtrInt);
var
  WorkItem: TFpThreadWorkerRunLoopAfterIdleUpdate;
  c: LongInt;
begin
  FpDebugger.FWorkQueue.Lock;
  FpDebugger.CheckAndRunIdle;
  c := FpDebugger.FWorkQueue.Count;
  FpDebugger.FWorkQueue.Unlock;

  if c = 0 then begin
    FpDebugger.StartDebugLoop;
  end
  else begin
    WorkItem := TFpThreadWorkerRunLoopAfterIdleUpdate.Create(FpDebugger);
    FpDebugger.FWorkQueue.PushItem(WorkItem);
    WorkItem.DecRef;
  end;
  UnQueue_DecRef;
end;

{ TFpThreadWorkerCallStackCountUpdate }

procedure TFpThreadWorkerCallStackCountUpdate.UpdateCallstack_DecRef(
  Data: PtrInt);
var
  CList: TDbgCallstackEntryList;
  dbg: TFpDebugDebugger;
begin
  // Runs in IDE thread (TThread.Queue)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallStackCount.UpdateCallstack_DecRef: system.ThreadID = classes.MainThreadID');

  if (FCallstack <> nil) then begin
    FCallstack.RemoveFreeNotification(@DoCallstackFreed_DecRef);

    if (FThread = nil) then
      CList := nil
    else
      CList := FThread.CallStackEntryList;

    if CList <> nil then begin
      if CList.HasReadAllAvailableFrames then begin
        FCallstack.Count := CList.Count;
        FCallstack.SetCountValidity(ddsValid);
      end
      else begin
        FCallstack.SetHasAtLeastCountInfo(ddsValid, CList.Count);
      end;
    end
    else begin
      FCallstack.SetCountValidity(ddsInvalid);
      FCallstack.SetHasAtLeastCountInfo(ddsInvalid);
    end;

    // save whatever we have to history // limit to reduce time
    if StopRequested and (CList <> nil) then
      FCallstack.PrepareRange(0, Min(CList.Count, 10));

    FCallstack := nil;
  end;

  dbg := FpDebugger;
  UnQueue_DecRef;
  TFPCallStackSupplier(dbg.CallStack).FCallStackWorkers.ClearFinishedWorkers;
end;

procedure TFpThreadWorkerCallStackCountUpdate.DoRemovedFromLinkedList;
begin
  UpdateCallstack_DecRef;  // This trigger PrepareRange => but that still needs to be exec in thread? (or wait for lock)
end;

procedure TFpThreadWorkerCallStackCountUpdate.DoCallstackFreed_DecRef(
  Sender: TObject);
begin
  // Runs in IDE thread (because it is called by FCallstack)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallStackCount.DoCallstackFreed_DecRef: system.ThreadID = classes.MainThreadID');
  FCallstack := nil;
  RequestStop;
  UnQueue_DecRef;
end;

constructor TFpThreadWorkerCallStackCountUpdate.Create(
  ADebugger: TFpDebugDebugger; ACallstack: TCallStackBase;
  ARequiredMinCount: Integer);
var
  AThread: TDbgThread;
begin
  // Runs in IDE thread (TThread.Queue)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallStackCount.Create: system.ThreadID = classes.MainThreadID');
  FCallstack := ACallstack;
  FCallstack.AddFreeNotification(@DoCallstackFreed_DecRef);
  if not ADebugger.FDbgController.CurrentProcess.GetThread(FCallstack.ThreadId, AThread) then
    ARequiredMinCount := -1;  // error
  inherited Create(ADebugger, ARequiredMinCount, AThread);
end;

//procedure TFpThreadWorkerCallStackCountUpdate.RemoveCallStack_DecRef;
//begin
//  // Runs in IDE thread (TThread.Queue)
//  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallStackCount.RemoveCallStack_DecRef: system.ThreadID = classes.MainThreadID');
//  RequestStop;
//  if (FCallstack <> nil) then begin
//    FCallstack.RemoveFreeNotification(@DoCallstackFreed_DecRef);
//    FCallstack := nil;
//  end;
//  UnQueue_DecRef;
//end;

{ TFpThreadWorkerCallEntryUpdate }

procedure TFpThreadWorkerCallEntryUpdate.DoCallstackFreed_DecRef(Sender: TObject
  );
begin
  // Runs in IDE thread (because it is called by FCallstack)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallEntry.DoCallstackFreed_DecRef: system.ThreadID = classes.MainThreadID');
  FCallstack := nil;
  DoCallstackEntryFreed_DecRef(nil);
end;

procedure TFpThreadWorkerCallEntryUpdate.DoCallstackEntryFreed_DecRef(
  Sender: TObject);
begin
  // Runs in IDE thread (because it is called by FCallstack)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallEntry.DoCallstackEntryFreed_DecRef: system.ThreadID = classes.MainThreadID');
  FCallstackEntry := nil;
  RequestStop;
  UnQueue_DecRef;
end;

procedure TFpThreadWorkerCallEntryUpdate.DoRemovedFromLinkedList;
begin
  UpdateCallstackEntry_DecRef;
end;

procedure TFpThreadWorkerCallEntryUpdate.UpdateCallstackEntry_DecRef(
  Data: PtrInt);
var
  dbg: TFpDebugDebugger;
  c: String;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallEntry.UpdateCallstackEntry_DecRef: system.ThreadID = classes.MainThreadID');

  if FCallstack <> nil then
    FCallstack.RemoveFreeNotification(@DoCallstackFreed_DecRef);

  if FCallstackEntry <> nil then begin
    FCallstackEntry.RemoveFreeNotification(@DoCallstackEntryFreed_DecRef);

    if FCallstackEntry.Validity = ddsRequested then begin
      if FDbgCallStack = nil then
        FCallstackEntry.Validity := ddsInvalid
      else begin
        c := FDbgCallStack.SrcClassName;
        if c <> '' then
          c := c + '.';
        FCallstackEntry.Init(FDbgCallStack.AnAddress, nil,
          c + FDbgCallStack.FunctionName + FParamAsString,
          FDbgCallStack.SourceFile, '', FDbgCallStack.Line, ddsValid);
      end;
    end;

    if FCallstack <> nil then
      FCallstack.DoEntriesUpdated;
  end;
  FCallstack := nil;
  FCallstackEntry := nil;

  dbg := FpDebugger;
  UnQueue_DecRef;
  TFPCallStackSupplier(dbg.CallStack).FCallStackWorkers.ClearFinishedWorkers;
end;

constructor TFpThreadWorkerCallEntryUpdate.Create(
  ADebugger: TFpDebugDebuggerBase; AThread: TDbgThread;
  ACallstackEntry: TCallStackEntry; ACallstack: TCallStackBase);
begin
  // Runs in IDE thread (TThread.Queue)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallEntry.Create: system.ThreadID = classes.MainThreadID');
  FCallstack := ACallstack;
  if FCallstack <> nil then
    FCallstack.AddFreeNotification(@DoCallstackFreed_DecRef);

  FCallstackEntry := ACallstackEntry;
  FCallstackEntry.AddFreeNotification(@DoCallstackEntryFreed_DecRef);
  FCallstackIndex := FCallstackEntry.Index;

  inherited Create(ADebugger, ACallstackEntry.Index+1, AThread);
end;

//procedure TFpThreadWorkerCallEntryUpdate.RemoveCallStackEntry_DecRef;
//begin
//  // Runs in IDE thread (TThread.Queue)
//  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCallEntry.RemoveCallStackEntry_DecRef: system.ThreadID = classes.MainThreadID');
//  RequestStop;
//  if FCallstack <> nil then begin
//    FCallstack.RemoveFreeNotification(@DoCallstackFreed_DecRef);
//    FCallstack := nil;
//  end;
//  if (FCallstackEntry <> nil) then begin
//    FCallstackEntry.RemoveFreeNotification(@DoCallstackEntryFreed_DecRef);
//    FCallstackEntry := nil;
//  end;
//  UnQueue_DecRef;
//end;

{ TFpThreadWorkerThreadsUpdate }

procedure TFpThreadWorkerThreadsUpdate.UpdateThreads_DecRef(Data: PtrInt);
var
  Threads: TThreadsSupplier;
  ThreadArray: TFPDThreadArray;
  i: Integer;
  CallStack: TDbgCallstackEntryList;
  t, n: TThreadEntry;
  FpThr: TDbgThread;
  c: TDbgCallstackEntry;
  dbg: TFpDebugDebuggerBase;
begin
  Threads := FDebugger.Threads;

  if (Threads.CurrentThreads <> nil) then begin
    ThreadArray := FpDebugger.FDbgController.CurrentProcess.GetThreadArray;
    for i := 0 to high(ThreadArray) do begin
      FpThr := ThreadArray[i];
      CallStack := FpThr.CallStackEntryList;
      t := Threads.CurrentThreads.EntryById[FpThr.ID];
      if Assigned(CallStack) and (CallStack.Count > 0) then begin
        c := CallStack.Items[0];
        if t = nil then begin
          n := Threads.CurrentThreads.CreateEntry(c.AnAddress, nil, c.FunctionName, c.SourceFile, '', c.Line, FpThr.ID, 'Thread ' + IntToStr(FpThr.ID), 'paused');
          Threads.CurrentThreads.Add(n);
          n.Free;
        end
        else
          t.Init(c.AnAddress, nil, c.FunctionName, c.SourceFile, '', c.Line, FpThr.ID, 'Thread ' + IntToStr(FpThr.ID), 'paused');
      end
      else begin
        if t = nil then begin
          n := Threads.CurrentThreads.CreateEntry(FpThr.GetInstructionPointerRegisterValue, nil, '', '', '', 0, FpThr.ID, 'Thread ' + IntToStr(FpThr.ID), 'paused');
          Threads.CurrentThreads.Add(n);
          n.Free;
        end
        else
          t.Init(FpThr.GetInstructionPointerRegisterValue, nil, '', '', '', 0, FpThr.ID, 'Thread ' + IntToStr(FpThr.ID), 'paused');
      end;
    end;

    Threads.CurrentThreads.SetValidity(ddsValid);
  end;

  dbg := FDebugger;
  UnQueue_DecRef;
  TFPThreads(dbg.Threads).FThreadWorkers.ClearFinishedWorkers;
end;

{ TFpThreadWorkerLocalsUpdate }

procedure TFpThreadWorkerLocalsUpdate.DoLocalsFreed_DecRef(Sender: TObject);
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerLocals.DoLocalsFreed_DecRef: system.ThreadID = classes.MainThreadID');
  FLocals := nil;
  RequestStop;
  UnQueue_DecRef;
end;

procedure TFpThreadWorkerLocalsUpdate.UpdateLocals_DecRef(Data: PtrInt);
var
  i: Integer;
  r: TResultEntry;
  dbg: TFpDebugDebugger;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerLocals.UpdateLocals_DecRef: system.ThreadID = classes.MainThreadID');

  if FLocals <> nil then begin
    FLocals.RemoveFreeNotification(@DoLocalsFreed_DecRef);
    FLocals.Clear;
    if FResults = nil then begin
      FLocals.SetDataValidity(ddsInvalid);
      FLocals := nil;
      UnQueue_DecRef;
      exit;
    end;

    for i := 0 to FResults.Count - 1 do begin
      r := FResults[i];
      FLocals.Add(r.Name, r.Value);
    end;
    FLocals.SetDataValidity(ddsValid);

    FLocals := nil;
  end;

  dbg := FpDebugger;
  UnQueue_DecRef;
  TFPLocals(dbg.Locals).FLocalWorkers.ClearFinishedWorkers;
end;

procedure TFpThreadWorkerLocalsUpdate.DoRemovedFromLinkedList;
begin
  if FLocals <> nil then begin
    if FHasQueued = hqQueued then begin
      UpdateLocals_DecRef;
      exit;
    end
    else begin
      FLocals.RemoveFreeNotification(@DoLocalsFreed_DecRef);
      FLocals.SetDataValidity(ddsInvalid);
    end;
    FLocals := nil;
  end;
  UnQueue_DecRef;
end;

constructor TFpThreadWorkerLocalsUpdate.Create(ADebugger: TFpDebugDebuggerBase;
  ALocals: TLocals);
begin
  // Runs in IDE thread (TThread.Queue)
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerLocals.Create: system.ThreadID = classes.MainThreadID');
  FLocals := ALocals;
  FLocals.AddFreeNotification(@DoLocalsFreed_DecRef);
  FThreadId := ALocals.ThreadId;
  FStackFrame := ALocals.StackFrame;
  inherited Create(ADebugger, twpLocal);
end;

{ TFpThreadWorkerWatchValueEvalUpdate }

procedure TFpThreadWorkerWatchValueEvalUpdate.DoWatchFreed_DecRef(
  Sender: TObject);
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerWatchValueEval.DoWatchFreed_DecRef: system.ThreadID = classes.MainThreadID');
  FWatchValue := nil;
  RequestStop;
  UnQueue_DecRef;
end;

procedure TFpThreadWorkerWatchValueEvalUpdate.UpdateWatch_DecRef(Data: PtrInt);
var
  dbg: TFpDebugDebuggerBase;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerWatchValueEval.UpdateWatch_DecRef: system.ThreadID = classes.MainThreadID');

  if FWatchValue <> nil then begin
    FWatchValue.RemoveFreeNotification(@DoWatchFreed_DecRef);

    FWatchValue.Value := FResText;
    FWatchValue.TypeInfo := FResDbgType;
    if not FRes then begin
      if FResText = '' then
        FWatchValue.Validity := ddsInvalid
      else
        FWatchValue.Validity := ddsError;
    end
    else begin
      FWatchValue.Validity := ddsValid;
    end;

    FWatchValue := nil;
  end;

  dbg := FDebugger;
  UnQueue_DecRef;
  TFPWatches(dbg.Watches).FWatchEvalWorkers.ClearFinishedWorkers;
end;

procedure TFpThreadWorkerWatchValueEvalUpdate.DoRemovedFromLinkedList;
begin
  if FWatchValue <> nil then begin
    FWatchValue.RemoveFreeNotification(@DoWatchFreed_DecRef);
    if FRes then begin
      UpdateWatch_DecRef;
    end
    else begin
      FWatchValue.Validity := ddsInvalid;
      FWatchValue := nil;
      UnQueue_DecRef;
    end;
  end
  else begin
    UnQueue_DecRef;
    FWatchValue := nil;
  end;
end;

constructor TFpThreadWorkerWatchValueEvalUpdate.Create(
  ADebugger: TFpDebugDebuggerBase; AWatchValue: TWatchValue);
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerWatchValueEval.Create: system.ThreadID = classes.MainThreadID');
  FWatchValue := AWatchValue;
  FWatchValue.AddFreeNotification(@DoWatchFreed_DecRef);
  inherited Create(ADebugger, twpWatch, FWatchValue.Expression, FWatchValue.StackFrame, FWatchValue.ThreadId,
    FWatchValue.DisplayFormat, FWatchValue.RepeatCount, FWatchValue.EvaluateFlags);
end;

{ TFpThreadWorkerBreakPointSetUpdate }

procedure TFpThreadWorkerBreakPointSetUpdate.UpdateBrkPoint_DecRef(Data: PtrInt
  );
var
  WorkItem: TFpThreadWorkerBreakPointRemoveUpdate;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerBreakPointSetUpdate.UpdateBrkPoint_DecRef: system.ThreadID = classes.MainThreadID');

  if FDbgBreakPoint <> nil then begin
    assert(FDbgBreakPoint.FThreadWorker = Self, 'TFpThreadWorkerBreakPointSetUpdate.UpdateBrkPoint_DecRef: FDbgBreakPoint.FThreadWorker = Self');
    FDbgBreakPoint.FThreadWorker := nil;
    DecRef;
  end
  else
    FResetBreakPoint := True;

  if FResetBreakPoint then begin
    if InternalBreakpoint <> nil then begin
      WorkItem := TFpThreadWorkerBreakPointRemoveUpdate.Create(FDebugger, InternalBreakpoint);
      FpDebugger.FWorkQueue.PushItem(WorkItem);
      WorkItem.DecRef;
    end;
  end
  else
  if FDbgBreakPoint <> nil then begin
    assert(FDbgBreakPoint.FInternalBreakpoint = nil, 'TFpThreadWorkerBreakPointSetUpdate.UpdateBrkPoint_DecRef: FDbgBreakPoint.FInternalBreakpoint = nil');
    FDbgBreakPoint.FInternalBreakpoint := InternalBreakpoint;
    if not assigned(InternalBreakpoint) then
      FDbgBreakPoint.Validity := vsInvalid // pending?
    else
      FDbgBreakPoint.Validity := vsValid;
  end;

  UnQueue_DecRef;
end;

constructor TFpThreadWorkerBreakPointSetUpdate.Create(
  ADebugger: TFpDebugDebuggerBase; ADbgBreakPoint: TFPBreakpoint);
var
  CurThreadId, CurStackFrame: Integer;
begin
  FDbgBreakPoint := ADbgBreakPoint;
  case ADbgBreakPoint.Kind of
    bpkAddress: inherited Create(ADebugger, ADbgBreakPoint.Address);
    bpkSource:  inherited Create(ADebugger, ADbgBreakPoint.Source, ADbgBreakPoint.Line);
    bpkData: begin
      TFpDebugDebugger(ADebugger).GetCurrentThreadAndStackFrame(CurThreadId, CurStackFrame);
      inherited Create(ADebugger, ADbgBreakPoint.WatchData, ADbgBreakPoint.WatchScope,
        ADbgBreakPoint.WatchKind, CurStackFrame, CurThreadId);
    end;
  end;
end;

procedure TFpThreadWorkerBreakPointSetUpdate.AbortSetBreak;
begin
  FResetBreakPoint := True;
  RequestStop;
end;

procedure TFpThreadWorkerBreakPointSetUpdate.RemoveBreakPoint_DecRef;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerBreakPointSetUpdate.RemoveBreakPoint_DecRef: system.ThreadID = classes.MainThreadID');
  FDbgBreakPoint := nil;
  UnQueue_DecRef;
end;

{ TFpThreadWorkerBreakPointRemoveUpdate }

procedure TFpThreadWorkerBreakPointRemoveUpdate.DoUnQueued;
begin
  if FInternalBreakpoint = nil then
    exit;
  FInternalBreakpoint.FreeByDbgProcess := True;
  inherited DoUnQueued;
end;

constructor TFpThreadWorkerBreakPointRemoveUpdate.Create(
  ADebugger: TFpDebugDebuggerBase; ADbgBreakPoint: TFPBreakpoint);
begin
  inherited Create(ADebugger, ADbgBreakPoint.FInternalBreakpoint);
end;

{ TDbgControllerStepOverFirstFinallyLineCmd }

procedure TDbgControllerStepOverFirstFinallyLineCmd.DoResolveEvent(
  var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
begin
  Finished := (FThread.CompareStepInfo(0, True) <> dcsiSameLine) or
              (NextInstruction.IsReturnInstruction) or IsSteppedOut;

  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent in [deFinishedStep] then
    AnEvent:=deInternalContinue;
end;

{ TDbgControllerStepOverOrFinallyCmd }

procedure TDbgControllerStepOverOrFinallyCmd.InternalContinue(
  AProcess: TDbgProcess; AThread: TDbgThread);
var
  Instr: TDbgAsmInstruction;
begin
{
00000001000374AE 4889C1                   mov rcx,rax
00000001000374B1 488D15D3FFFFFF           lea rdx,[rip-$0000002D]
00000001000374B8 4989E8                   mov rax,rbp
00000001000374BB E89022FEFF               call -$0001DD70

}
  if (AThread = FThread) then begin
    Instr := NextInstruction;
    if Instr is TX86AsmInstruction then begin
      case TX86AsmInstruction(Instr).X86OpCode of
        OPmov:
          if CompareText(TX86AsmInstruction(Instr).X86Instruction.Operand[2].Value, 'RBP') = 0 then
            FFinState := fsMov;
        OPcall:
          if FFinState = fsMov then begin
            CheckForCallAndSetBreak;
            FProcess.Continue(FProcess, FThread, True); // Step into
            FFinState := fsCall;
            exit;
          end;
        else
          FFinState := fsNone;
      end;
    end;
  end;
  inherited InternalContinue(AProcess, AThread);
end;

procedure TDbgControllerStepOverOrFinallyCmd.DoResolveEvent(
  var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
var
  sym: TFpSymbol;
begin
  if FFinState = fsCall then begin
    sym := FProcess.FindProcSymbol(FThread.GetInstructionPointerRegisterValue);
    if pos('fin$', sym.Name) > 0 then
      FFinState := fsInFin
    else
      FFinState := fsNone;
    sym.ReleaseReference;

    if FFinState = fsInFin then begin
      FThread.StoreStepInfo;
      Finished := False;
      RemoveHiddenBreak;
      if AnEvent = deFinishedStep then
        AnEvent := deInternalContinue;
      exit;
    end;
  end;
  inherited DoResolveEvent(AnEvent, AnEventThread, Finished);
end;

{ TDbgControllerStepThroughFpcSpecialHandler }

procedure TDbgControllerStepThroughFpcSpecialHandler.DoResolveEvent(
  var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
begin
  if IsAtOrOutOfHiddenBreakFrame then
    RemoveHiddenBreak;

  Finished := IsSteppedOut or FDone or ((not HasHiddenBreak) and (NextInstruction.IsReturnInstruction));
  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent = deFinishedStep then
    AnEvent := deInternalContinue;
end;

procedure TDbgControllerStepThroughFpcSpecialHandler.InternalContinue(
  AProcess: TDbgProcess; AThread: TDbgThread);
begin
  {$PUSH}{$Q-}{$R-}
  if (AThread = FThread) and
     (NextInstruction.IsCallInstruction) and
     (FThread.GetInstructionPointerRegisterValue + NextInstruction.InstructionLength = FAfterFinCallAddr)
  then begin
    RemoveHiddenBreak;
    FProcess.Continue(FProcess, FThread, True);
    FDone := True;
// TODO: last step => then single line step
    exit;
  end;
  {$POP}
  inherited InternalContinue(AProcess, AThread);
end;

procedure TDbgControllerStepThroughFpcSpecialHandler.Init;
begin
  InitStackFrameInfo;
  inherited Init;
end;

constructor TDbgControllerStepThroughFpcSpecialHandler.Create(
  AController: TDbgController; AnAfterFinCallAddr: TDbgPtr);
begin
  FAfterFinCallAddr := AnAfterFinCallAddr;
  inherited Create(AController);
end;

{ TFpDebugExceptionStepping.TAddressFrameList }

function TFpDebugExceptionStepping.TAddressFrameList.Add(const AKey: TDbgPtr): TFrameList;
begin
  Result := TFrameList.Create;
  inherited Add(AKey, Result);
end;

{ TFPThreads }

procedure TFPThreads.DoStateEnterPause;
begin
  inherited DoStateEnterPause;
  Changed;
end;

procedure TFPThreads.DoStateChange(const AOldState: TDBGState);
begin
  inherited DoStateChange(AOldState);
  if (Debugger.State in [dsPause, dsInternalPause]) then // Make sure we have threads first // this can be removed, once threads are KEPT between pauses
    RequestEntries;
end;

procedure TFPThreads.StopWorkes;
begin
  FThreadWorkers.RequestStopForWorkers;
end;

procedure TFPThreads.DoStateLeavePause;
begin
  inherited DoStateLeavePause;
  FThreadWorkers.WaitForWorkers(True);
end;

procedure TFPThreads.RequestEntries;
var
  ThreadArray: TFPDThreadArray;
  i: Integer;
  ThreadEntry: TThreadEntry;
begin
  if Monitor = nil then exit;
  if CurrentThreads = nil then exit;
  if Debugger = nil then Exit;
  if not TFpDebugDebugger(Debugger).IsPausedAndValid then exit;

  CurrentThreads.Clear;

  ThreadArray := TFpDebugDebugger(Debugger).FDbgController.CurrentProcess.GetThreadArray;
  for i := 0 to high(ThreadArray) do begin
    // TODO: Maybe get the address. If FpDebug has already read the ThreadState.
    ThreadEntry := CurrentThreads.CreateEntry(0, nil, '', '', '', 0, ThreadArray[i].ID, 'Thread ' + IntToStr(ThreadArray[i].ID), 'paused');
    try
      CurrentThreads.Add(ThreadEntry);
    finally
      ThreadEntry.Free;
    end;
  end;

  if TFpDebugDebugger(Debugger).FDbgController.CurrentThread = nil then
    CurrentThreads.CurrentThreadId := 0 // TODO: only until controller is guranteed to have a currentthread
  else
    CurrentThreads.CurrentThreadId := TFpDebugDebugger(Debugger).FDbgController.CurrentThread.ID;
  // Do NOT set validity // keep ddsUnknown;
end;

destructor TFPThreads.Destroy;
begin
  FThreadWorkers.WaitForWorkers(True);
  inherited Destroy;
end;

procedure TFPThreads.RequestMasterData;
var
  WorkItem: TFpThreadWorkerThreadsUpdate;
begin
  if Monitor = nil then exit;
  if CurrentThreads = nil then exit;
  if Debugger = nil then Exit;

  if not (Debugger.State in [dsPause, dsInternalPause {, dsRun}]) then begin  // Make sure we have threads first // this can be removed, once threads are KEPT between pauses
    CurrentThreads.Clear;
    Exit;
  end;

  WorkItem := TFpThreadWorkerThreadsUpdate.Create(TFpDebugDebugger(Debugger));
  TFpDebugDebugger(Debugger).FWorkQueue.PushItem(WorkItem);
  FThreadWorkers.Add(WorkItem);
end;

procedure TFPThreads.ChangeCurrentThread(ANewId: Integer);
begin
  inherited ChangeCurrentThread(ANewId);
  if not(Debugger.State in [dsPause, dsInternalPause]) then exit;

  TFpDebugDebugger(Debugger).FDbgController.CurrentThreadId := ANewId;
  if CurrentThreads <> nil then
    CurrentThreads.CurrentThreadId := ANewId;
  Changed;
end;

{ TFpWaitForConsoleOutputThread }

procedure TFpWaitForConsoleOutputThread.DoHasConsoleOutput(Data: PtrInt);
var
  s: string;
begin
  if (Data=0) or assigned(TFpDebugDebugger(Data).FConsoleOutputThread) then
  begin
    s := FFpDebugDebugger.FDbgController.CurrentProcess.GetConsoleOutput;
    RTLeventSetEvent(FHasConsoleOutputQueued);
    if Assigned(FFpDebugDebugger.OnConsoleOutput) then
      FFpDebugDebugger.OnConsoleOutput(self, s);
  end;
end;

constructor TFpWaitForConsoleOutputThread.Create(AFpDebugDebugger: TFpDebugDebugger);
begin
  Inherited create(false);
  FHasConsoleOutputQueued := RTLEventCreate;
  FFpDebugDebugger := AFpDebugDebugger;
end;

destructor TFpWaitForConsoleOutputThread.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  RTLeventdestroy(FHasConsoleOutputQueued);
  inherited Destroy;
end;

procedure TFpWaitForConsoleOutputThread.Execute;
var
  res: integer;
begin
  while not terminated do
  begin
    res := FFpDebugDebugger.FDbgController.CurrentProcess.CheckForConsoleOutput(100);
    if res<0 then
      Terminate
    else if res>0 then
    begin
      RTLeventResetEvent(FHasConsoleOutputQueued);
      Application.QueueAsyncCall(@DoHasConsoleOutput, PtrInt(FFpDebugDebugger));
      RTLeventWaitFor(FHasConsoleOutputQueued);
    end;
  end;
end;

{ TFpDbgMemReader }

function TFpDbgMemReader.GetDbgProcess: TDbgProcess;
begin
  result := FFpDebugDebugger.FDbgController.CurrentProcess;
end;

function TFpDbgMemReader.GetDbgThread(AContext: TFpDbgLocationContext): TDbgThread;
var
  Process: TDbgProcess;
begin
  Process := GetDbgProcess;
  if not Process.GetThread(AContext.ThreadId, Result) then
    Result := FFpDebugDebugger.FDbgController.CurrentThread;
end;

procedure TFpDbgMemReader.DoReadRegister;
begin
  FRegResult := inherited ReadRegister(FRegNum, FRegValue, FRegContext);
end;

constructor TFpDbgMemReader.create(AFpDebugDebuger: TFpDebugDebugger);
begin
  FFpDebugDebugger := AFpDebugDebuger;
end;

function TFpDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean;
begin
  result := FFpDebugDebugger.ReadData(AnAddress, ASize, ADest^);
end;

function TFpDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal;
  ADest: Pointer; out ABytesRead: Cardinal): Boolean;
begin
  result := FFpDebugDebugger.ReadData(AnAddress, ASize, ADest^, ABytesRead);
end;

function TFpDbgMemReader.ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean;
begin
  Assert(AnAddressSpace>0,'TFpDbgMemReader.ReadMemoryEx ignores AddressSpace');
  result := FFpDebugDebugger.ReadData(AnAddress, ASize, ADest^);
end;

function TFpDbgMemReader.ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr;
  AContext: TFpDbgLocationContext): Boolean;
begin
  // Shortcut, if in debug-thread / do not use Self.F*
  if ThreadID = FFpDebugDebugger.FWorkerThreadId then
    exit(inherited ReadRegister(ARegNum, AValue, AContext));

  FRegNum := ARegNum;
  FRegContext := AContext;
  FRegValue := 0; // TODO: error detection
  FFpDebugDebugger.ExecuteInDebugThread(@DoReadRegister);
  AValue := FRegValue;
  result := FRegResult;
end;

{ TFPCallStackSupplier }

function TFPCallStackSupplier.FpDebugger: TFpDebugDebugger;
begin
  Result := TFpDebugDebugger(Debugger);
end;

procedure TFPCallStackSupplier.StopWorkes;
begin
  FCallStackWorkers.RequestStopForWorkers;
end;

procedure TFPCallStackSupplier.DoStateLeavePause;
begin
  FCallStackWorkers.WaitForWorkers(True);
  FInitialFrame := 0;
  FThreadForInitialFrame := 0;
  if (TFpDebugDebugger(Debugger).FDbgController <> nil) and
     (TFpDebugDebugger(Debugger).FDbgController.CurrentProcess <> nil)
  then
    TFpDebugDebugger(Debugger).FDbgController.CurrentProcess.ThreadsClearCallStack;
  inherited DoStateLeavePause;
end;

constructor TFPCallStackSupplier.Create(const ADebugger: TDebuggerIntf);
begin
  inherited Create(ADebugger);
  FPrettyPrinter := TFpPascalPrettyPrinter.Create(sizeof(pointer));
end;

destructor TFPCallStackSupplier.Destroy;
begin
  FCallStackWorkers.WaitForWorkers(True);
  inherited Destroy;
  FPrettyPrinter.Free;
end;

procedure TFPCallStackSupplier.RequestCount(ACallstack: TCallStackBase);
begin
  RequestAtLeastCount(ACallstack, -1);
end;

procedure TFPCallStackSupplier.RequestAtLeastCount(ACallstack: TCallStackBase;
  ARequiredMinCount: Integer);
var
  WorkItem: TFpThreadWorkerCallStackCountUpdate;
begin
  if not FpDebugger.IsPausedAndValid then begin
    ACallstack.SetCountValidity(ddsInvalid);
    exit;
  end;

  WorkItem := TFpThreadWorkerCallStackCountUpdate.Create(FpDebugger, ACallstack, ARequiredMinCount);
  FpDebugger.FWorkQueue.PushItem(WorkItem);
  FCallStackWorkers.Add(WorkItem);
end;

procedure TFPCallStackSupplier.RequestEntries(ACallstack: TCallStackBase);
var
  e: TCallStackEntry;
  It: TMapIterator;
  t: TDbgThread;
  WorkItem: TFpThreadWorkerCallEntryUpdate;
  i: Integer;
begin
  It := TMapIterator.Create(ACallstack.RawEntries);
  if not It.Locate(ACallstack.LowestUnknown )
  then if not It.EOM
  then It.Next;

  if not FpDebugger.IsPausedAndValid then begin
    while (not IT.EOM) and (TCallStackEntry(It.DataPtr^).Index <= ACallstack.HighestUnknown) do begin
      TCallStackEntry(It.DataPtr^).Validity := ddsInvalid;
      IT.Next;
    end;
    It.Free;
    exit;
  end;

  if not FpDebugger.FDbgController.CurrentProcess.GetThread(ACallstack.ThreadId, t) then
    t := nil;

  i := 0;
  while (not IT.EOM) and (TCallStackEntry(It.DataPtr^).Index <= ACallstack.HighestUnknown)
  do begin
    e := TCallStackEntry(It.DataPtr^);
    It.Next;
    inc(i);
    if e.Validity = ddsRequested then
    begin
      if t = nil then
        e.Validity := ddsInvalid
      else
      begin
        if IT.EOM or ((i and 7) = 0) then
          WorkItem := TFpThreadWorkerCallEntryUpdate.Create(FpDebugger, t, e, ACallstack)
        else
          WorkItem := TFpThreadWorkerCallEntryUpdate.Create(FpDebugger, t, e);
        FpDebugger.FWorkQueue.PushItem(WorkItem);
        FCallStackWorkers.Add(WorkItem);
      end;
    end;
  end;
  It.Free;
end;

procedure TFPCallStackSupplier.RequestCurrent(ACallstack: TCallStackBase);
begin
  if (FThreadForInitialFrame <> 0) and (FThreadForInitialFrame = ACallstack.ThreadId) then begin
    ACallstack.CurrentIndex := FInitialFrame;
    FInitialFrame := 0;
    FThreadForInitialFrame := 0;
  end
  else
    ACallstack.CurrentIndex := 0;
  ACallstack.SetCurrentValidity(ddsValid);
end;

procedure TFPCallStackSupplier.UpdateCurrentIndex;
var
  tid, idx: Integer;
  cs: TCallStackBase;
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    exit;
  end;

  tid := Debugger.Threads.CurrentThreads.CurrentThreadId;
  cs := TCallStackBase(CurrentCallStackList.EntriesForThreads[tid]);
  idx := cs.NewCurrentIndex;  // NEW-CURRENT

  if cs <> nil then begin
    cs.CurrentIndex := idx;
    cs.SetCurrentValidity(ddsValid);
  end;
end;

{ TFPLocals }

function TFPLocals.FpDebugger: TFpDebugDebugger;
begin
  Result := TFpDebugDebugger(Debugger);
end;

procedure TFPLocals.StopWorkes;
begin
  FLocalWorkers.RequestStopForWorkers;
end;

procedure TFPLocals.DoStateLeavePause;
begin
  inherited DoStateLeavePause;
  FLocalWorkers.WaitForWorkers(True);
end;

destructor TFPLocals.Destroy;
begin
  FLocalWorkers.WaitForWorkers(True);
  inherited Destroy;
end;

procedure TFPLocals.RequestData(ALocals: TLocals);
var
  WorkItem: TFpThreadWorkerLocalsUpdate;
begin
  if not FpDebugger.IsPausedAndValid then begin
    ALocals.SetDataValidity(ddsInvalid);
    exit;
  end;

  WorkItem := TFpThreadWorkerLocalsUpdate.Create(FpDebugger, ALocals);
  FLocalWorkers.Add(WorkItem);
  FpDebugger.FWorkQueue.PushItem(WorkItem);
end;

{ TFPBreakpoints }

function TFPBreakpoints.Find(AIntBReakpoint: FpDbgClasses.TFpDbgBreakpoint): TDBGBreakPoint;
var
  i: integer;
begin
  for i := 0 to count-1 do
    if TFPBreakpoint(Items[i]).FInternalBreakpoint=AIntBReakpoint then
      begin
      result := TFPBreakpoint(Items[i]);
      Exit;
      end;
  result := nil;
end;

procedure TFPBreakpoint.SetBreak;
begin
  debuglnEnter(DBG_BREAKPOINTS, ['>> TFPBreakpoint.SetBreak  ADD ',FSource,':',FLine,'/',dbghex(Address),' ' ]);
  assert(FThreadWorker = nil, 'TFPBreakpoint.SetBreak: FThreadWorker = nil');
  assert(FInternalBreakpoint=nil);

  FThreadWorker := TFpThreadWorkerBreakPointSetUpdate.Create(TFpDebugDebugger(Debugger), Self);
  TFpDebugDebugger(Debugger).FWorkQueue.PushItem(FThreadWorker);

  FValid := vsUnknown;
  FIsSet:=true;
  debuglnExit(DBG_BREAKPOINTS, ['<< TFPBreakpoint.SetBreak ' ]);
end;

procedure TFPBreakpoint.ResetBreak;
var
  WorkItem: TFpThreadWorkerBreakPointRemoveUpdate;
begin
  FIsSet:=false;
  if FThreadWorker <> nil then begin
    debugln(DBG_BREAKPOINTS, ['>> TFPBreakpoint.ResetBreak  CANCEL / REMOVE ',FSource,':',FLine,'/',dbghex(Address),' ' ]);
    assert(FThreadWorker is TFpThreadWorkerBreakPointSetUpdate, 'TFPBreakpoint.ResetBreak: FThreadWorker is TFpThreadWorkerBreakPointSetUpdate');
    assert(FInternalBreakpoint = nil, 'TFPBreakpoint.ResetBreak: FInternalBreakpoint = nil');
    FThreadWorker.AbortSetBreak;
    FThreadWorker.RemoveBreakPoint_DecRef;
    FThreadWorker.DecRef;
    FThreadWorker := nil;
    exit;
  end;

  // If Debugger is not assigned, the Controller's currentprocess is already
  // freed. And so are the corresponding InternalBreakpoint's.
  if assigned(Debugger) and assigned(FInternalBreakpoint) then
    begin
    debuglnEnter(DBG_BREAKPOINTS, ['>> TFPBreakpoint.ResetBreak  REMOVE ',FSource,':',FLine,'/',dbghex(Address),' ' ]);
    WorkItem := TFpThreadWorkerBreakPointRemoveUpdate.Create(TFpDebugDebugger(Debugger), Self);
    TFpDebugDebugger(Debugger).FWorkQueue.PushItem(WorkItem);
    WorkItem.DecRef;
    FInternalBreakpoint := nil;
    debuglnExit(DBG_BREAKPOINTS, ['<< TFPBreakpoint.ResetBreak ' ]);
    end;
end;

destructor TFPBreakpoint.Destroy;
begin
  (* No need to request a pause. This will run, as soon as the debugger gets to the next pause.
     If the next pause is a hit on this breakpoint, then it will be ignored
  *)
  ResetBreak;

  if FThreadWorker <> nil then begin
    FThreadWorker.AbortSetBreak;
    FThreadWorker.RemoveBreakPoint_DecRef;
    FThreadWorker.DecRef;
    FThreadWorker := nil;
  end;
  inherited Destroy;
end;

procedure TFPBreakpoint.DoStateChange(const AOldState: TDBGState);
begin
  if (Debugger.State in [dsPause, dsInternalPause]) or
     (TFpDebugDebugger(Debugger).FSendingEvents and (Debugger.State in [dsRun, dsInit]))
  then
    begin
    if Enabled and not FIsSet then
      begin
      FSetBreakFlag:=true;
      Changed;
      end
    else if not enabled and FIsSet then
      begin
      FResetBreakFlag:=true;
      Changed;
      end;
    end
  else if Debugger.State = dsStop then
    begin
    ResetBreak;
    end;
  inherited DoStateChange(AOldState);
end;

procedure TFPBreakpoint.DoEnableChange;
var
  ADebugger: TFpDebugDebugger;
begin
  ADebugger := TFpDebugDebugger(Debugger);
  if (ADebugger.State in [dsPause, dsInternalPause, dsInit]) or TFpDebugDebugger(Debugger).FSendingEvents then
    begin
    if Enabled and not FIsSet then
      FSetBreakFlag := True
    else if not Enabled and FIsSet then
      FResetBreakFlag := True;
    end
  else if (ADebugger.State = dsRun) and (Enabled and not FIsSet) then
    ADebugger.QuickPause;
  inherited;
end;

procedure TFPBreakpoint.DoChanged;
begin
  if FResetBreakFlag and not FSetBreakFlag then
    ResetBreak
  else if FSetBreakFlag then
    SetBreak;

  FSetBreakFlag := false;
  FResetBreakFlag := false;

  inherited DoChanged;
end;

{ TFPDBGDisassembler }

function TFPDBGDisassembler.PrepareEntries(AnAddr: TDbgPtr; ALinesBefore, ALinesAfter: Integer): boolean;
var
  ARange, AReversedRange: TDBGDisassemblerEntryRange;
  AnEntry: TDisassemblerEntry;
  CodeBin: TBytes;
  p: pointer;
  ADump,
  AStatement,
  ASrcFileName: string;
  ASrcFileLine: integer;
  i,j, sz, bytesDisassembled, bufOffset: Integer;
  Sym: TFpSymbol;
  StatIndex: integer;
  FirstIndex: integer;
  ALastAddr, tmpAddr, tmpPointer, prevInstructionSize: TDBGPtr;
  ADisassembler: TDbgAsmDecoder;

begin
  Result := False;
  if (Debugger = nil) or not(Debugger.State = dsPause) then
    exit;

  ADisassembler := TFpDebugDebugger(Debugger).FDbgController.CurrentProcess.Disassembler;
  Sym:=nil;
  ASrcFileLine:=0;
  ASrcFileName:='';
  StatIndex:=0;
  FirstIndex:=0;
  ARange := TDBGDisassemblerEntryRange.Create;
  ARange.RangeStartAddr:=AnAddr;
  ALastAddr:=0;

  if (ALinesBefore > 0) and
    ADisassembler.CanReverseDisassemble then
   begin
     AReversedRange := TDBGDisassemblerEntryRange.Create;
     tmpAddr := AnAddr;  // do not modify AnAddr in this loop
     // Large enough block of memory for whole loop
     sz := ADisassembler.MaxInstructionSize * ALinesBefore;
     SetLength(CodeBin, sz);

     // TODO: Check if AnAddr is at lower address than length(CodeBin)
     //       and ensure ReadData size doesn't exceed available target memory.
     //       Fill out of bounds memory in buffer with "safe" value e.g. 0
     if sz + ADisassembler.MaxInstructionSize > AnAddr then
     begin
       FillByte(CodeBin[0], sz, 0);
       // offset into buffer where active memory should start
       bufOffset := sz - AnAddr;
       // size of active memory to read
       sz := integer(AnAddr);
     end
     else
     begin
       bufOffset := 0;
     end;

     // Everything now counts back from starting address...
     bytesDisassembled := 0;
     // Only read up to byte before this address
     if not TFpDebugDebugger(Debugger).ReadData(tmpAddr-sz, sz, CodeBin[bufOffset]) then
       DebugLn(Format('Reverse disassemble: Failed to read memory at %s.', [FormatAddress(tmpAddr)]))
     else
       for i := 0 to ALinesBefore-1 do
       begin
         if bytesDisassembled >= sz then
           break;

         tmpPointer := TDBGPtr(@CodeBin[bufOffset]) + TDBGPtr(sz) - TDBGPtr(bytesDisassembled);
         p := pointer(tmpPointer);
         ADisassembler.ReverseDisassemble(p, ADump, AStatement); // give statement before pointer p, pointer p points to decoded instruction on return
         prevInstructionSize := tmpPointer - PtrUInt(p);
         bytesDisassembled := bytesDisassembled + prevInstructionSize;
         DebugLn(DBG_VERBOSE, format('Disassembled: [%.8X:  %s] %s',[tmpAddr, ADump, Astatement]));

         Dec(tmpAddr, prevInstructionSize);
         Sym := TFpDebugDebugger(Debugger).FDbgController.CurrentProcess.FindProcSymbol(tmpAddr);
         // If this is the last statement for this source-code-line, fill the
         // SrcStatementCount from the prior statements.
         if (assigned(sym) and ((ASrcFileName<>sym.FileName) or (ASrcFileLine<>sym.Line))) or
           (not assigned(sym) and ((ASrcFileLine<>0) or (ASrcFileName<>''))) then
         begin
           for j := 0 to StatIndex-1 do
           begin
             with AReversedRange.EntriesPtr[FirstIndex+j]^ do
               SrcStatementCount := StatIndex;
           end;
           StatIndex := 0;
           FirstIndex := i;
         end;

         if assigned(sym) then
         begin
           ASrcFileName:=sym.FileName;
           ASrcFileLine:=sym.Line;
           sym.ReleaseReference;
         end
         else
         begin
           ASrcFileName:='';
           ASrcFileLine:=0;
         end;
         AnEntry.Addr := tmpAddr;
         AnEntry.Dump := ADump;
         AnEntry.Statement := AStatement;
         AnEntry.SrcFileLine:=ASrcFileLine;
         AnEntry.SrcFileName:=ASrcFileName;
         AnEntry.SrcStatementIndex:=StatIndex;  // should be inverted for reverse parsing
         AReversedRange.Append(@AnEntry);
         inc(StatIndex);
       end;

     if AReversedRange.Count>0 then
     begin
       // Update start of range
       ARange.RangeStartAddr := tmpAddr;
       // Copy range in revese order of entries
       for i := 0 to AReversedRange.Count-1 do
       begin
         // Reverse order of statements
         with AReversedRange.Entries[AReversedRange.Count-1 - i] do
         begin
           for j := 0 to SrcStatementCount-1 do
             SrcStatementIndex := SrcStatementCount - 1 - j;
         end;

         ARange.Append(AReversedRange.EntriesPtr[AReversedRange.Count-1 - i]);
       end;
     end;
     // Entries are all pointers, don't free entries
     FreeAndNil(AReversedRange);
   end;

  if ALinesAfter > 0 then
  begin
  sz := ALinesAfter * ADisassembler.MaxInstructionSize;
  SetLength(CodeBin, sz);
  bytesDisassembled := 0;
  if not TFpDebugDebugger(Debugger).ReadData(AnAddr, sz, CodeBin[0]) then
    begin
    DebugLn(Format('Disassemble: Failed to read memory at %s.', [FormatAddress(AnAddr)]));
    inc(AnAddr);
    end
  else
    for i := 0 to ALinesAfter-1 do
      begin
      p := @CodeBin[bytesDisassembled];
      ADisassembler.Disassemble(p, ADump, AStatement);

      prevInstructionSize := p - @CodeBin[bytesDisassembled];
      bytesDisassembled := bytesDisassembled + prevInstructionSize;
      Sym := TFpDebugDebugger(Debugger).FDbgController.CurrentProcess.FindProcSymbol(AnAddr);
      // If this is the last statement for this source-code-line, fill the
      // SrcStatementCount from the prior statements.
      if (assigned(sym) and ((ASrcFileName<>sym.FileName) or (ASrcFileLine<>sym.Line))) or
        (not assigned(sym) and ((ASrcFileLine<>0) or (ASrcFileName<>''))) then
        begin
        for j := 0 to StatIndex-1 do
          ARange.EntriesPtr[FirstIndex+j]^.SrcStatementCount:=StatIndex;
        StatIndex:=0;
        FirstIndex:=i;
        end;

      if assigned(sym) then
        begin
        ASrcFileName:=sym.FileName;
        ASrcFileLine:=sym.Line;
        sym.ReleaseReference;
        end
      else
        begin
        ASrcFileName:='';
        ASrcFileLine:=0;
        end;
      AnEntry.Addr := AnAddr;
      AnEntry.Dump := ADump;
      AnEntry.Statement := AStatement;
      AnEntry.SrcFileLine:=ASrcFileLine;
      AnEntry.SrcFileName:=ASrcFileName;
      AnEntry.SrcStatementIndex:=StatIndex;
      ARange.Append(@AnEntry);
      ALastAddr:=AnAddr;
      inc(StatIndex);
      Inc(AnAddr, prevInstructionSize);
      end;
  end
  else
    ALastAddr := AnAddr;

  if ARange.Count>0 then
    begin
    ARange.RangeEndAddr:=ALastAddr;
    ARange.LastEntryEndAddr:={%H-}TDBGPtr(p);
    EntryRanges.AddRange(ARange);
    result := true;
    end
  else
    begin
    result := false;
    ARange.Free;
    end;
end;

{ TFPRegisters }

procedure TFPRegisters.RequestData(ARegisters: TRegisters);
var
  ARegisterList: TDbgRegisterValueList;
  i: Integer;
  ARegisterValue: TRegisterValue;
  thr: TDbgThread;
  frm: TDbgCallstackEntry;
begin
  if not TFpDebugDebugger(Debugger).IsPausedAndValid then begin
    ARegisters.DataValidity:=ddsInvalid;
    exit;
  end;

  if not TFpDebugDebugger(Debugger).FDbgController.MainProcess.GetThread(ARegisters.ThreadId, thr) then begin
    ARegisters.DataValidity:=ddsError;
    exit;
  end;

  ARegisterList := nil;
  if ARegisters.StackFrame = 0 then begin
    ARegisterList :=  thr.RegisterValueList;
  end
  else begin
    frm := thr.CallStackEntryList[ARegisters.StackFrame];
    if frm <> nil then
      ARegisterList := frm.RegisterValueList;
  end;

  if ARegisterList = nil then begin
    ARegisters.DataValidity:=ddsError;
    exit;
  end;

  for i := 0 to ARegisterList.Count-1 do
    begin
    ARegisterValue := ARegisters.EntriesByName[ARegisterList[i].Name];
    ARegisterValue.ValueObj.SetAsNum(ARegisterList[i].NumValue, ARegisterList[i].Size);
    ARegisterValue.ValueObj.SetAsText(ARegisterList[i].StrValue);
    ARegisterValue.DataValidity:=ddsValid;
    end;
  ARegisters.DataValidity:=ddsValid;
end;

{ TFpLineInfo }

function TFpLineInfo.FpDebugger: TFpDebugDebugger;
begin
  Result := TFpDebugDebugger(Debugger);
end;

procedure TFpLineInfo.DoStateChange(const AOldState: TDBGState);
begin
  //inherited DoStateChange(AOldState);
  if not (Debugger.State in [dsPause, dsInternalPause, dsRun]) then
    ClearSources;
end;

procedure TFpLineInfo.ClearSources;
begin
  FRequestedSources.Clear;
end;

procedure TFpLineInfo.DebugInfoChanged;
var
  i: Integer;
  Src: String;
begin
  if (FpDebugger.DebugInfo = nil) or not(FpDebugger.DebugInfo is TFpDwarfInfo) then
    exit;

  for i := 0 to FRequestedSources.Count - 1 do begin
    if FRequestedSources.Objects[i] = nil then begin
      Src := FRequestedSources[i];
      FRequestedSources.Objects[i] := TObject(TFpDwarfInfo(FpDebugger.DebugInfo).GetLineAddressMap(Src));
      if FRequestedSources.Objects[i] <> nil then
        DoChange(Src);
    end;
  end;
end;

constructor TFpLineInfo.Create(const ADebugger: TDebuggerIntf);
begin
  FRequestedSources := TStringListUTF8Fast.Create;
  inherited Create(ADebugger);
end;

destructor TFpLineInfo.Destroy;
begin
  FreeAndNil(FRequestedSources);
  inherited Destroy;
end;

function TFpLineInfo.Count: Integer;
begin
  Result := FRequestedSources.Count;
end;

function TFpLineInfo.HasAddress(const AIndex: Integer; const ALine: Integer
  ): Boolean;
var
  Map: PDWarfLineMap;
  dummy: TDBGPtrArray;
begin
  Result := False;
  if not((FpDebugger.DebugInfo <> nil) and (FpDebugger.DebugInfo is TFpDwarfInfo)) then
    exit;
  Map := PDWarfLineMap(FRequestedSources.Objects[AIndex]);
  if Map <> nil then
  begin
    dummy:=nil;
    Result := Map^.GetAddressesForLine(ALine, dummy, True);
  end;
end;

function TFpLineInfo.GetInfo(AAddress: TDbgPtr; out ASource, ALine,
  AOffset: Integer): Boolean;
begin
  Result := False;
end;

function TFpLineInfo.IndexOf(const ASource: String): integer;
begin
  Result := FRequestedSources.IndexOf(ASource);
end;

procedure TFpLineInfo.Request(const ASource: String);
var
  i: Integer;
begin
  if (FpDebugger.DebugInfo = nil) or not(FpDebugger.DebugInfo is TFpDwarfInfo) then begin
    FRequestedSources.AddObject(ASource, nil);
    exit;
  end;
  i := FRequestedSources.AddObject(ASource, TObject(TFpDwarfInfo(FpDebugger.DebugInfo).GetLineAddressMap(ASource)));
  if FRequestedSources.Objects[i] <> nil then
    DoChange(ASource);
end;

procedure TFpLineInfo.Cancel(const ASource: String);
begin
  //
end;

{ TFPWatches }

function TFPWatches.FpDebugger: TFpDebugDebugger;
begin
  Result := TFpDebugDebugger(Debugger);
end;

procedure TFPWatches.StopWorkes;
begin
  FWatchEvalWorkers.RequestStopForWorkers;
end;

procedure TFPWatches.DoStateLeavePause;
begin
  inherited DoStateLeavePause;
  FWatchEvalWorkers.WaitForWorkers(True);
end;

procedure TFPWatches.InternalRequestData(AWatchValue: TWatchValue);
var
  WorkItem: TFpThreadWorkerWatchValueEvalUpdate;
begin
  if not FpDebugger.IsPausedAndValid then begin
    AWatchValue.Validity := ddsInvalid;
    exit;
  end;

  WorkItem := TFpThreadWorkerWatchValueEvalUpdate.Create(FpDebugger, AWatchValue);
  FpDebugger.FWorkQueue.PushItem(WorkItem);
  FWatchEvalWorkers.Add(WorkItem);
end;

destructor TFPWatches.Destroy;
begin
  FWatchEvalWorkers.WaitForWorkers(True);
  inherited Destroy;
end;

{ TFpDebugExceptionStepping }

function TFpDebugExceptionStepping.GetDbgController: TDbgController;
begin
  Result := FDebugger.FDbgController;
end;

function TFpDebugExceptionStepping.dbgs(st: TExceptStepState): string;
begin
  writestr(Result, st);
end;

function TFpDebugExceptionStepping.dbgs(loc: TBreakPointLoc): string;
begin
  writestr(Result, loc);
end;

function TFpDebugExceptionStepping.dbgs(locs: TBreakPointLocs): string;
var
  a: TBreakPointLoc;
begin
  Result := '';
  for a in locs do Result := Result + dbgs(a) +',';
end;

function TFpDebugExceptionStepping.GetCurrentProcess: TDbgProcess;
begin
  Result := FDebugger.FDbgController.CurrentProcess;
end;

function TFpDebugExceptionStepping.GetCurrentCommand: TDbgControllerCmd;
begin
  Result := FDebugger.FDbgController.CurrentCommand;
end;

function TFpDebugExceptionStepping.GetCurrentThread: TDbgThread;
begin
  Result := FDebugger.FDbgController.CurrentThread;
end;

procedure TFpDebugExceptionStepping.EnableBreaks(ALocs: TBreakPointLocs);
var
  a: TBreakPointLoc;
begin
  // Not in thread => only flag desired changes
  for a in ALocs do
    Include(FBreakNewEnabled, a);
end;

procedure TFpDebugExceptionStepping.EnableBreaksDirect(ALocs: TBreakPointLocs);
var
  a: TBreakPointLoc;
begin
  // Running in debug thread
  //debugln(['EnableBreaksDirect ', dbgs(ALocs)]);
  for a in ALocs do
    if FBreakPoints[a] <> nil then begin
      if not(a in FBreakEnabled) then
        FBreakPoints[a].SetBreak;
      Include(FBreakEnabled, a);
      Include(FBreakNewEnabled, a);
    end;
end;

procedure TFpDebugExceptionStepping.DisableBreaks(ALocs: TBreakPointLocs);
var
  a: TBreakPointLoc;
begin
  // Not in thread => only flag desired changes
  //debugln(['DisableBreaks ', dbgs(ALocs)]);
  for a in ALocs do
    Exclude(FBreakNewEnabled, a);
end;

procedure TFpDebugExceptionStepping.DisableBreaksDirect(ALocs: TBreakPointLocs);
var
  a: TBreakPointLoc;
begin
  // Running in debug thread
  //debugln(['DisableBreaksDirect ', dbgs(ALocs)]);
  for a in ALocs do
    if FBreakPoints[a] <> nil then begin
      if (a in FBreakEnabled) then
        FBreakPoints[a].ResetBreak;
      Exclude(FBreakEnabled, a);
      Exclude(FBreakNewEnabled, a);
    end;
end;

procedure TFpDebugExceptionStepping.SetStepOutAddrDirect(AnAddr: TDBGPtr);
begin
  FreeAndNil(FBreakPoints[bplStepOut]);
  FBreakPoints[bplStepOut] := CurrentProcess.AddBreak(AnAddr);
end;

procedure TFpDebugExceptionStepping.DoExceptionRaised(var &continue: boolean);
var
  AnExceptionLocation: TDBGLocationRec;
begin
  FDebugger.HandleSoftwareException(AnExceptionLocation, &continue);

  case &continue of
    True: begin
        if (CurrentCommand <> nil) and not(CurrentCommand is TDbgControllerContinueCmd) and
           (CurrentCommand.Thread = CurrentThread)
        then begin
          EnableBreaks([bplPopExcept, bplCatches, bplFpcSpecific]);
          FState := esIgnoredRaise; // currently stepping
        end;
      end;
    False:
      begin
        FDebugger.EnterPause(AnExceptionLocation);
        FState := esStoppedAtRaise;
      end;
  end;
end;

//procedure TFpDebugExceptionStepping.DoPopExcptStack;
//begin
//  // check if step over??
//  // clear breaks
//  DbgController.AbortCurrentCommand;
//  DbgController.StepOut;
//  FState := esNone;
//
//  DisableBreaks([bplPopExcept, bplCatches, bplFpcSpecific]);
//end;

procedure TFpDebugExceptionStepping.DoRtlUnwindEx;
begin

end;

constructor TFpDebugExceptionStepping.Create(ADebugger: TFpDebugDebugger);
begin
  FDebugger := ADebugger;
  FAddressFrameList := TAddressFrameList.Create(True);
end;

destructor TFpDebugExceptionStepping.Destroy;
begin
  DoDbgStopped;
  inherited Destroy;
  FAddressFrameList.Destroy;
end;

procedure TFpDebugExceptionStepping.DoProcessLoaded;
begin
  debuglnEnter(DBG_BREAKPOINTS, ['>> TFpDebugDebugger.SetSoftwareExceptionBreakpoint FPC_RAISEEXCEPTION' ]);
  FBreakPoints[bplRaise]         := FDebugger.AddBreak('FPC_RAISEEXCEPTION');
  FBreakPoints[bplBreakError]    := FDebugger.AddBreak('FPC_BREAK_ERROR');
  FBreakPoints[bplRunError]      := FDebugger.AddBreak('FPC_RUNERROR');
  FBreakPoints[bplReRaise]       := FDebugger.AddBreak('FPC_RERAISE', nil,            False);
  FBreakPoints[bplPopExcept]     := FDebugger.AddBreak('FPC_POPADDRSTACK', nil,       False);
  FBreakPoints[bplCatches]       := FDebugger.AddBreak('FPC_CATCHES', nil,            False);
  FBreakPoints[bplFpcSpecific]   := FDebugger.AddBreak('__FPC_specific_handler', nil, False);
  FBreakPoints[bplSehW64Except]  := FDebugger.AddBreak(0, False);
  FBreakPoints[bplSehW64Finally] := FDebugger.AddBreak(0, False);
  debuglnExit(DBG_BREAKPOINTS, ['<< TFpDebugDebugger.SetSoftwareExceptionBreakpoint ' ]);
end;

procedure TFpDebugExceptionStepping.DoNtDllLoaded(ALib: TDbgLibrary);
begin
  debugln(DBG_BREAKPOINTS, ['SetSoftwareExceptionBreakpoint RtlUnwind']);
  FBreakPoints[bplRtlUnwind].Free;
  FBreakPoints[bplRtlUnwind] := FDebugger.AddBreak('RtlUnwindEx', ALib, False);
end;

procedure TFpDebugExceptionStepping.DoDbgStopped;
var
  a: TBreakPointLoc;
begin
  debuglnEnter(DBG_BREAKPOINTS, ['>> TFpDebugDebugger.FDbgControllerProcessExitEvent fpc_Raiseexception' ]);
  for a in TBreakPointLoc do
    FreeAndNil(FBreakPoints[a]);
  debuglnExit(DBG_BREAKPOINTS, ['<< TFpDebugDebugger.FDbgControllerProcessExitEvent ' ]);
end;

procedure TFpDebugExceptionStepping.ThreadBeforeLoop(Sender: TObject);
begin
  // Running in debug thread
  EnableBreaksDirect(FBreakNewEnabled - FBreakEnabled);
  DisableBreaksDirect(FBreakEnabled - FBreakNewEnabled);
end;

procedure TFpDebugExceptionStepping.ThreadProcessLoopCycle(
  var AFinishLoopAndSendEvents: boolean; var AnEventType: TFPDEvent;
  var ACurCommand: TDbgControllerCmd; var AnIsFinished: boolean);

  function CheckCommandFinishesInFrame(AFrameAddr: TDBGPtr): Boolean;
  begin
    Result := (ACurCommand is TDbgControllerHiddenBreakStepBaseCmd) and
              (TDbgControllerHiddenBreakStepBaseCmd(CurrentCommand).StoredStackFrameInfo <> nil);
    if not Result then
      exit; // none stepping command, does not stop
    if ACurCommand is TDbgControllerStepOutCmd then
      Result := TDbgControllerHiddenBreakStepBaseCmd(CurrentCommand).StoredStackFrameInfo.StoredStackFrame < AFrameAddr
    else
      Result := TDbgControllerHiddenBreakStepBaseCmd(CurrentCommand).StoredStackFrameInfo.StoredStackFrame <= AFrameAddr;
  end;

  procedure CheckSteppedOutFromW64SehFinally;
  var
    sym: TFpSymbol;
    r: Boolean;
  begin
    if (FState <> esNone) or (not(ACurCommand is TDbgControllerLineStepBaseCmd)) or
       (ACurCommand.Thread <> CurrentThread)
    then
      exit;

    if (pos('fin$', TDbgControllerLineStepBaseCmd(ACurCommand).StartedInFuncName) < 1) then
      exit;

    if (not TDbgControllerLineStepBaseCmd(ACurCommand).IsSteppedOut) then begin
      EnableBreaksDirect([bplFpcSpecific]);
      exit;
    end;

    sym := CurrentProcess.FindProcSymbol(CurrentThread.GetInstructionPointerRegisterValue);
    r := (sym <> nil) and (CompareText(sym.Name, '__FPC_SPECIFIC_HANDLER') <> 0) and
         (sym.FileName <> '');
    sym.ReleaseReference;
    if r then
      exit;

    FState := esSteppingFpcSpecialHandler;
    AFinishLoopAndSendEvents := False;
    ACurCommand := TDbgControllerStepThroughFpcSpecialHandler.Create(DbgController, CurrentThread.GetInstructionPointerRegisterValue);
  end;

  procedure StepOutFromPopCatches;
  begin
    ACurCommand := TDbgControllerStepOutCmd.Create(DbgController);
    TDbgControllerStepOutCmd(ACurCommand).SetReturnAdressBreakpoint(CurrentProcess, True);
  end;

const
  MaxFinallyHandlerCnt = 256; // more finally in a single proc is not probable....
var
  StepOutStackPos, ReturnAddress, Base, HData, ImgBase, Addr: TDBGPtr;
  Rdx, Rcx, R8, R9, PC: TDBGPtr;
  o, i: Integer;
  EFlags, Cnt: Cardinal;
  Frames: TFrameList;
  FinallyData: Array of array [0..3] of DWORD;
  n: String;
begin
  case AnEventType of
    deExitProcess: begin
      FDebugger.FExceptionStepper.DoDbgStopped;
      exit;
    end;
    deLoadLibrary: begin
      if (CurrentProcess <> nil) and (CurrentProcess.LastLibraryLoaded <> nil) then begin
        n := ExtractFileName(CurrentProcess.LastLibraryLoaded.Name);
        if n = 'ntdll.dll' then
          FDebugger.FExceptionStepper.DoNtDllLoaded(CurrentProcess.LastLibraryLoaded);
      end;
      exit;
    end;
  end;

  if CurrentThread = nil then
    exit;
  if (FState = esSteppingFpcSpecialHandler) and AnIsFinished and
     (ACurCommand is TDbgControllerStepThroughFpcSpecialHandler)
  then begin
    if TDbgControllerStepThroughFpcSpecialHandler(ACurCommand).FDone then begin
      FState := esNone;
      if ACurCommand.Thread = CurrentThread then
        ACurCommand := TDbgControllerStepOverFirstFinallyLineCmd.Create(DbgController);
      // else thread has gone => finish old command
    end
    else begin
      FState := esStepToFinally;
      ACurCommand := nil; // run
      EnableBreaksDirect([bplFpcSpecific]);
    end;
    AFinishLoopAndSendEvents := False;
    exit;
  end
  else
  if CurrentProcess.CurrentBreakpoint = nil then begin
    CheckSteppedOutFromW64SehFinally;
    exit;
  end;
  DisableBreaksDirect([bplRtlUnwind, bplSehW64Finally]); // bplRtlUnwind must always be unset;

  PC := CurrentThread.GetInstructionPointerRegisterValue;
  // bplPopExcept / bplCatches
  if (assigned(FBreakPoints[bplPopExcept]) and FBreakPoints[bplPopExcept].HasLocation(PC)) or
     (assigned(FBreakPoints[bplCatches]) and FBreakPoints[bplCatches].HasLocation(PC))
  then begin
    debugln(FPDBG_COMMANDS, ['@ bplPop/bplCatches ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    // TODO: esStepToFinally has "CurrentCommand = nil" and is Running, not stepping => thread not avail
    if (CurrentCommand <> nil) and (CurrentCommand.Thread <> CurrentThread) then
      exit;

    //DebugLn(['THreadProcLoop ', dbgs(FState), ' ', DbgSName(CurrentCommand)]);
    DisableBreaksDirect([bplPopExcept, bplCatches, bplFpcSpecific]); // FpcSpecific was not needed -> not SEH based code
    case FState of
      esIgnoredRaise: begin
          // bplReRaise may set them again
          if not (CurrentCommand is TDbgControllerHiddenBreakStepBaseCmd) then
            exit; // wrong command type // should not happen

          if AnIsFinished then begin
// FORCE the breakpoint WITHoUT FRAME => known to be without frame // optimized fpc may not have expected asm
            StepOutFromPopCatches;
          end
          else begin
            o := 0;
            if (CurrentCommand is TDbgControllerStepOutCmd) then
              o := 1; // frame must be less, not equal

            {$PUSH}{$Q-}{$R-}
            // GetStackBasePointerRegisterValue is still on parent frame
            if CheckCommandFinishesInFrame(CurrentThread.GetStackBasePointerRegisterValue - o)
            then begin
              // Insert a "step out" breakpoint, but leave control to the running command.
              StepOutStackPos := CurrentThread.GetStackPointerRegisterValue;
              if CurrentProcess.ReadAddress(StepOutStackPos, ReturnAddress) then
                SetStepOutAddrDirect(ReturnAddress)
              else
                StepOutFromPopCatches; // error reading mem
            end;
            {$POP}
          end;
        end;
      esStepToFinally: begin
          StepOutFromPopCatches;
        end;
    end;
    FState := esNone;
  end
  else
  // bplStepOut => part of esIgnoredRaise
  if assigned(FBreakPoints[bplStepOut]) and FBreakPoints[bplStepOut].HasLocation(PC) then begin
    debugln(FPDBG_COMMANDS, ['@ bplStepOut ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    if (CurrentCommand = nil) or (CurrentCommand.Thread <> CurrentThread) then
      exit;
    AFinishLoopAndSendEvents := AnIsFinished;
    CurrentProcess.RemoveBreak(FBreakPoints[bplStepOut]);
    FreeAndNil(FBreakPoints[bplStepOut]);
  end
  else
  // bplReRaise
  if assigned(FBreakPoints[bplReRaise]) and FBreakPoints[bplReRaise].HasLocation(PC) then begin
    debugln(FPDBG_COMMANDS, ['@ bplReRaise ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    if (CurrentCommand = nil) or (CurrentCommand.Thread <> CurrentThread) then
      exit;
    EnableBreaksDirect([bplPopExcept, bplCatches, bplFpcSpecific]);
    // if not(FState = esStepToFinally) then
    FState := esIgnoredRaise;
  end
  else
  (* ***** Win64 SEH ***** *)
  // bplFpcSpecific
  if assigned(FBreakPoints[bplFpcSpecific]) and FBreakPoints[bplFpcSpecific].HasLocation(PC) then begin
    debugln(FPDBG_COMMANDS, ['@ bplFpcSpecific ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    // TODO: esStepToFinally has "CurrentCommand = nil" and is Running, not stepping => thread not avail
    if (CurrentCommand <> nil) and (CurrentCommand.Thread <> CurrentThread) then
      exit;
    EnableBreaksDirect([bplRtlUnwind]);
    FBreakPoints[bplSehW64Finally].RemoveAllAddresses;

    if (FState = esIgnoredRaise) and not(CurrentCommand is TDbgControllerHiddenBreakStepBaseCmd) then
      exit; // wrong command type // should not happen

    (* TODO: Look at using DW_TAG_try_block https://bugs.freepascal.org/view.php?id=34881 *)

    {$PUSH}{$Q-}{$R-}
    Rcx := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(2).NumValue; // rec: TExceptionRecord
    {$PUSH}{$Q-}{$R-}
    if (not CurrentProcess.ReadData(Rcx + 4, 4, EFlags)) or
       ((EFlags and 66) = 0) // rec.ExceptionFlags and EXCEPTION_UNWIND)=0
    then
      exit;
    {$POP}

    R8  := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(8).NumValue;
    if (not CurrentProcess.ReadAddress(R8 + 160, Base)) or (Base = 0) then // RPB at finally
      exit;
    if (FState = esIgnoredRaise) and
       not CheckCommandFinishesInFrame(Base)
    then
      exit;

    R9  := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(9).NumValue;
    //dispatch.HandlerData
    if (not CurrentProcess.ReadAddress(R9 + 56, HData)) or (HData = 0) then
      exit;
    if (not CurrentProcess.ReadData(HData, 4, Cnt)) or (Cnt = 0) or (Cnt > MaxFinallyHandlerCnt) then
      exit;

    if (not CurrentProcess.ReadAddress(R9 + 8, ImgBase)) or (ImgBase = 0) then
      exit;

    SetLength(FinallyData, Cnt);
    if (not CurrentProcess.ReadData(HData + 4, 16 * Cnt, FinallyData[0])) then
      exit;
    for i := 0 to Cnt - 1 do begin
      Addr := FinallyData[i][3];
      if (FinallyData[i][0] <> 0) or // scope^.Typ=SCOPE_FINALLY
         (Addr = 0)
      then
        Continue;
      FBreakPoints[bplSehW64Finally].AddAddress(ImgBase + Addr);
    end;
    {$POP}
    FBreakPoints[bplSehW64Finally].SetBreak;
  end
  else
  // bplRtlUnwind
  if assigned(FBreakPoints[bplRtlUnwind]) and FBreakPoints[bplRtlUnwind].HasLocation(PC) then begin
    debugln(FPDBG_COMMANDS, ['@ bplRtlUnwind ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    // This is Win64 bit only
    // Must run for any thread => the thread may stop at a break in a finally block, and then attempt to step to except
    // maybe store the thread-id with each breakpoint // though SP register values should be unique
    Rcx := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(2).NumValue; // rsp at target
    Rdx := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(1).NumValue;
    if (Rcx <> 0) and (Rdx <> 0) then begin
      o := FAddressFrameList.IndexOf(Rdx);
      if o >= 0 then
        Frames := FAddressFrameList.Data[o]
      else
        Frames := FAddressFrameList.Add(Rdx);
      if Frames.IndexOf(Rcx) >= 0 then
        exit;
      Frames.Add(Rcx);
      FBreakPoints[bplSehW64Except].AddAddress(Rdx);
      FBreakPoints[bplSehW64Except].SetBreak;
    end;
  end
  else
  // bplSehW64Except
  if assigned(FBreakPoints[bplSehW64Except]) and FBreakPoints[bplSehW64Except].HasLocation(PC) then begin // always assigned
    debugln(FPDBG_COMMANDS, ['@ bplSehW64Except ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    FBreakPoints[bplSehW64Finally].RemoveAllAddresses;
    o := FAddressFrameList.IndexOf(PC);
    Rdx := CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(1).NumValue;
    if o >= 0 then begin
      Frames := FAddressFrameList.Data[o];
      Frames.Remove(CurrentThread.GetStackPointerRegisterValue);
      if Frames.Count = 0 then begin
        FBreakPoints[bplSehW64Except].RemoveAddress(Rdx);
        FAddressFrameList.Delete(o);
      end;
    end
    else
      FBreakPoints[bplSehW64Except].RemoveAddress(Rdx);

    // TODO: esStepToFinally has "CurrentCommand = nil" and is Running, not stepping => thread not avail
    if (CurrentCommand <> nil) and (CurrentCommand.Thread <> CurrentThread) then
      exit;

    if (not (FState in [esStepToFinally, esSteppingFpcSpecialHandler])) and
       not(CurrentCommand is TDbgControllerHiddenBreakStepBaseCmd)
    then
      exit; // wrong command type / should not happen
    if (FState = esIgnoredRaise) and
       (not CheckCommandFinishesInFrame(CurrentThread.GetStackBasePointerRegisterValue))
    then
      exit;

    AFinishLoopAndSendEvents := True; // Stop at this address
    FState := esAtWSehExcept;
    AnIsFinished := True;
    AnEventType := deFinishedStep;
  end
  else
  // bplSehW64Finally
  if assigned(FBreakPoints[bplSehW64Finally]) and FBreakPoints[bplSehW64Finally].HasLocation(PC) then begin // always assigned
    debugln(FPDBG_COMMANDS, ['@ bplSehW64Finally ', DbgSName(CurrentCommand)]);
    AFinishLoopAndSendEvents := False;
    // TODO: esStepToFinally has "CurrentCommand = nil" and is Running, not stepping => thread not avail
    if (CurrentCommand <> nil) and (CurrentCommand.Thread <> CurrentThread) then
      exit;
    FBreakPoints[bplSehW64Finally].RemoveAllAddresses;
    // step over proloque
    ACurCommand := TDbgControllerStepOverFirstFinallyLineCmd.Create(DbgController);
    FState := esStepSehFinallyProloque;
  end
  else
    CheckSteppedOutFromW64SehFinally;

end;

function TFpDebugExceptionStepping.BreakpointHit(var &continue: boolean;
  const Breakpoint: TFpDbgBreakpoint): boolean;
begin
  if FState in [esAtWSehExcept] then begin
    FDebugger.EnterPause(FDebugger.GetLocation);
    FState := esNone;
    exit(True);
  end;

  Result := Assigned(Breakpoint);
  if not Result then begin
    exit;
  end;

  if BreakPoint = FBreakPoints[bplRaise] then begin
    debugln(FPDBG_COMMANDS, ['@ bplRaise']);
    DoExceptionRaised(&continue);
  end
  else
  if BreakPoint = FBreakPoints[bplBreakError] then begin
    debugln(FPDBG_COMMANDS, ['@ bplBreakError']);
    FDebugger.HandleBreakError(&continue);
    if not &continue then
      FState := esNone;
  end
  else
  if BreakPoint = FBreakPoints[bplRunError] then begin
    debugln(FPDBG_COMMANDS, ['@ bplRunError']);
    FDebugger.HandleRunError(&continue);
    if not &continue then
      FState := esNone;
  end
  else
    Result := False;
end;

procedure TFpDebugExceptionStepping.UserCommandRequested(
  var ACommand: TDBGCommand);
var
  st: TExceptStepState;
begin
  // This only runs if the debugloop is paused
  st := FState;
  FState := esNone;
  DisableBreaks([bplPopExcept, bplCatches, bplFpcSpecific,
    bplReRaise,
    bplRtlUnwind, bplStepOut]);

  if ACommand in [dcStepInto, dcStepOver, dcStepOut, dcStepTo, dcRunTo, dcStepOverInstr{, dcStepIntoInstr}] then
    EnableBreaks([bplReRaise]);
  if ACommand in [dcStepOut] then
    EnableBreaks([bplFpcSpecific]);

  case st of
    esStoppedAtRaise: begin
      if ACommand in [dcStepInto, dcStepOver, dcStepOut, dcStepTo, dcRunTo] then begin
        FState := esStepToFinally;
        ACommand := dcRun;
        EnableBreaks([bplPopExcept, bplCatches, bplFpcSpecific]);
      end
    end;
  end;
end;


{ TFpDebugDebugger }

procedure TFpDebugDebugger.FDbgControllerProcessExitEvent(AExitCode: DWord);
var
  AThread: TFpWaitForConsoleOutputThread;
begin
  if assigned(FConsoleOutputThread) then
    begin
    AThread := TFpWaitForConsoleOutputThread(FConsoleOutputThread);
    FConsoleOutputThread := nil;
    AThread.Terminate;
    AThread.DoHasConsoleOutput(0);
    AThread.WaitFor;
    AThread.Free;
    end;

  SetExitCode(Integer(AExitCode));
  {$PUSH}{$R-}
  DoDbgEvent(ecProcess, etProcessExit, Format('Process exited with exit-code %u',[AExitCode]));
  {$POP}
  LockRelease;
  try
    SetState(dsStop);
    StopAllWorkers;
    FreeDebugThread;
  finally
    UnlockRelease;
  end;
end;

procedure TFpDebugDebugger.FDbgControllerExceptionEvent(var continue: boolean;
  const ExceptionClass, ExceptionMessage: string);
begin
  DoException(deExternal, ExceptionClass, GetLocation, ExceptionMessage, continue);
  if not continue then
    begin
    SetState(dsPause);
    DoCurrent(GetLocation);
    end;
end;

function TFpDebugDebugger.GetDebugInfo: TDbgInfo;
begin
  Result := nil;
  if (FDbgController <> nil) and (FDbgController.CurrentProcess<> nil) then
    Result := FDbgController.CurrentProcess.DbgInfo;
end;

function TFpDebugDebugger.CreateLineInfo: TDBGLineInfo;
begin
  Result := TFpLineInfo.Create(Self);
end;

function TFpDebugDebugger.CreateWatches: TWatchesSupplier;
begin
  Result := TFPWatches.Create(Self);
end;

function TFpDebugDebugger.CreateThreads: TThreadsSupplier;
begin
  Result := TFPThreads.Create(Self);
end;

function TFpDebugDebugger.CreateLocals: TLocalsSupplier;
begin
  Result := TFPLocals.Create(Self);
end;

function TFpDebugDebugger.CreateRegisters: TRegisterSupplier;
begin
  Result := TFPRegisters.Create(Self);
end;

function TFpDebugDebugger.CreateCallStack: TCallStackSupplier;
begin
  Result:=TFPCallStackSupplier.Create(Self);
end;

function TFpDebugDebugger.CreateDisassembler: TDBGDisassembler;
begin
  Result:=TFPDBGDisassembler.Create(Self);
end;

function TFpDebugDebugger.CreateBreakPoints: TDBGBreakPoints;
begin
  Result := TFPBreakPoints.Create(Self, TFPBreakpoint);
end;

procedure TFpDebugDebugger.FDbgControllerDebugInfoLoaded(Sender: TObject);
begin
  if LineInfo <> nil then begin
    TFpLineInfo(LineInfo).DebugInfoChanged;
  end;
end;

procedure TFpDebugDebugger.FDbgControllerLibraryLoaded(var continue: boolean;
  ALib: TDbgLibrary);
var
  n: String;
begin
  n := ExtractFileName(ALib.Name);
  DoDbgEvent(ecModule, etModuleLoad, 'Loaded: ' + n + ' (' + ALib.Name +')');
end;

procedure TFpDebugDebugger.FDbgControllerLibraryUnloaded(var continue: boolean;
  ALib: TDbgLibrary);
var
  n: String;
begin
  n := ExtractFileName(ALib.Name);
  DoDbgEvent(ecModule, etModuleUnload, 'Unloaded: ' + n + ' (' + ALib.Name +')');
end;

procedure TFpDebugDebugger.GetCurrentThreadAndStackFrame(out AThreadId,
  AStackFrame: Integer);
var
  CurStackList: TCallStackBase;
begin
  AThreadId := Threads.CurrentThreads.CurrentThreadId;
  CurStackList := CallStack.CurrentCallStackList.EntriesForThreads[AThreadId];
  if CurStackList <> nil then begin
    AStackFrame := CurStackList.CurrentIndex;
    if AStackFrame < 0 then
      AStackFrame := 0;
  end
  else
    AStackFrame := 0;
end;

function TFpDebugDebugger.GetContextForEvaluate(const ThreadId,
  StackFrame: Integer): TFpDbgSymbolScope;
begin
  Result := FindSymbolScope(ThreadId, StackFrame);
end;

function TFpDebugDebugger.GetClassInstanceName(AnAddr: TDBGPtr): string;
var
  AnErr: TFpError;
begin
  Result := '';
  if (FDbgController.CurrentProcess <> nil) then
    TFpDwarfFreePascalSymbolClassMap.GetInstanceForDbgInfo(FDbgController.CurrentProcess.DbgInfo)
    .GetInstanceClassNameFromPVmt
      (AnAddr, FDbgController.DefaultContext, DBGPTRSIZE[FDbgController.CurrentProcess.Mode], Result, AnErr);
end;

function TFpDebugDebugger.ReadAnsiString(AnAddr: TDbgPtr): string;
var
  StrAddr: TDBGPtr;
  len: TDBGPtr;
begin
  result := '';
  if not ReadAddress(AnAddr, StrAddr) then
    Exit;
  if StrAddr = 0 then
    exit;
  ReadAddress(StrAddr-DBGPTRSIZE[FDbgController.CurrentProcess.Mode], len);
  setlength(result, len);
  if not ReadData(StrAddr, len, result[1]) then
    result := '';
end;

procedure TFpDebugDebugger.HandleSoftwareException(out
  AnExceptionLocation: TDBGLocationRec; var continue: boolean);
var
  AnExceptionObjectLocation, ExceptIP, ExceptFramePtr: TDBGPtr;
  ExceptionClass: string;
  ExceptionMessage: string;
  ExceptItem: TBaseException;
begin
  if not FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(1),
    SizeVal(SizeOf(ExceptIP)), ExceptIP)
  then
    ExceptIP := 0;
  AnExceptionLocation:=GetLocationRec(ExceptIP, -1);

  if not FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(0),
    SizeVal(SizeOf(AnExceptionObjectLocation)), AnExceptionObjectLocation)
  then
    AnExceptionObjectLocation := 0;
  ExceptionClass := '';
  ExceptionMessage := '';
  if AnExceptionObjectLocation <> 0 then begin
    ExceptionClass := GetClassInstanceName(AnExceptionObjectLocation);
    ExceptionMessage := ReadAnsiString(AnExceptionObjectLocation+DBGPTRSIZE[FDbgController.CurrentProcess.Mode]);
  end;

  ExceptItem := Exceptions.Find(ExceptionClass);
  if (ExceptItem <> nil) and (ExceptItem.Enabled)
  then begin
    continue := True;
    exit;
  end;

  DoException(deInternal, ExceptionClass, AnExceptionLocation, ExceptionMessage, continue);

  if not &continue then begin
    if FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(2),
      SizeVal(SizeOf(ExceptFramePtr)), ExceptFramePtr)
    then
      ExceptIP := SetStackFrameForBasePtr(ExceptFramePtr, True, ExceptIP);
      if ExceptIP <> 0 then
          AnExceptionLocation:=GetLocationRec(ExceptIP); // Assert was corrected
  end;
end;

procedure TFpDebugDebugger.HandleBreakError(var continue: boolean);
var
  ErrNo: QWord;
  ExceptIP, ExceptFramePtr: TDBGPtr;
  ExceptName: string;
  ExceptItem: TBaseException;
  ExceptionLocation: TDBGLocationRec;
begin
  if not FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(1),
    SizeVal(SizeOf(ExceptIP)), ExceptIP)
  then
    ExceptIP := 0;
  ExceptionLocation:=GetLocationRec(ExceptIP, -1);

  if FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(0),
    SizeVal(SizeOf(LongInt)), ErrNo)
  then
    ExceptName := Format('RunError(%d)', [ErrNo])
  else
    ExceptName := 'RunError(unknown)';

  ExceptItem := Exceptions.Find(ExceptName);
  if (ExceptItem <> nil) and (ExceptItem.Enabled)
  then begin
    continue := True;
    exit;
  end;

  DoException(deRunError, ExceptName, ExceptionLocation, RunErrorText[ErrNo], continue);

  if not &continue then begin
    if FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(2),
      SizeVal(SizeOf(ExceptFramePtr)), ExceptFramePtr)
    then
      SetStackFrameForBasePtr(ExceptFramePtr);

    EnterPause(ExceptionLocation);
  end;
end;

procedure TFpDebugDebugger.HandleRunError(var continue: boolean);
var
  ErrNo: QWord;
  ExceptName: string;
  ExceptItem: TBaseException;
  ExceptionLocation: TDBGLocationRec;
begin
  // NO Addr / No Frame
  ExceptionLocation:=GetLocationRec;

  if FDbgController.DefaultContext.ReadUnsignedInt(FDbgController.CurrentProcess.CallParamDefaultLocation(0),
    SizeVal(SizeOf(Word)), ErrNo)
  then
    ExceptName := Format('RunError(%d)', [ErrNo])
  else
    ExceptName := 'RunError(unknown)';

  ExceptItem := Exceptions.Find(ExceptName);
  if (ExceptItem <> nil) and (ExceptItem.Enabled)
  then begin
    continue := True;
    exit;
  end;

  DoException(deRunError, ExceptName, ExceptionLocation, RunErrorText[ErrNo], continue);

  if not &continue then begin
    EnterPause(ExceptionLocation);
  end;
end;

procedure TFpDebugDebugger.FreeDebugThread;
begin
  FWorkQueue.TerminateAllThreads(True);
  {$IFDEF FPDEBUG_THREAD_CHECK} CurrentFpDebugThreadIdForAssert := MainThreadID;{$ENDIF}
  Application.ProcessMessages; // run the AsyncMethods
end;

procedure TFpDebugDebugger.FDbgControllerHitBreakpointEvent(
  var continue: boolean; const Breakpoint: TFpDbgBreakpoint;
  AnEventType: TFPDEvent; AMoreHitEventsPending: Boolean);
var
  ABreakPoint: TDBGBreakPoint;
  ALocationAddr: TDBGLocationRec;
  Context: TFpDbgSymbolScope;
  PasExpr: TFpPascalExpression;
  Opts: TFpInt3DebugBreakOptions;
begin
  // If a user single steps to an excepiton handler, do not open the dialog (there is no continue possible)
  if AnEventType = deBreakpoint then
    if FExceptionStepper.BreakpointHit(&continue, Breakpoint) then
      exit;

  if assigned(Breakpoint) then begin
    ABreakPoint := TFPBreakpoints(BreakPoints).Find(Breakpoint);
    if (ABreakPoint <> nil) and (ABreakPoint.Enabled) then begin

      // TODO: parse expression when breakpoin is created / so invalid expressions do not need to be handled here
      if ABreakPoint.Expression <> '' then begin
        Context := GetContextForEvaluate(FDbgController.CurrentThreadId, 0);
        if Context <> nil then begin
          PasExpr := nil;
          try
            PasExpr := TFpPascalExpression.Create(ABreakPoint.Expression, Context);
            PasExpr.ResultValue; // trigger full validation
            if PasExpr.Valid and (svfBoolean in PasExpr.ResultValue.FieldFlags) and
               (not PasExpr.ResultValue.AsBool) // false => do not pause
            then
              &continue := True;
          finally
            PasExpr.Free;
            Context.ReleaseReference;
          end;

          if &continue then
            exit;
        end;
      end;

      ALocationAddr := GetLocation;
      if Assigned(EventLogHandler) then
        EventLogHandler.LogEventBreakPointHit(ABreakpoint, ALocationAddr);

      if assigned(ABreakPoint) then
        ABreakPoint.Hit(&continue);

      if (not &continue) and (ABreakPoint.Kind = bpkData) and (OnFeedback <> nil) then begin
        // For message use location(Address - 1)
        OnFeedback(self,
            Format('The Watchpoint for "%1:s" was triggered.%0:s%0:s', // 'Old value: %2:s%0:sNew value: %3:s',
                   [LineEnding, ABreakPoint.WatchData{, AOldVal, ANewVal}]),
            '', ftInformation, [frOk]);
      end;
    end
    else
      continue := True; // removed or disabled breakpoint
  end
  else
  if (AnEventType = deHardCodedBreakpoint) and (FDbgController.CurrentThread <> nil) then begin
    &continue:=true;
    Opts := TFpDebugDebuggerProperties(GetProperties).HandleDebugBreakInstruction;
    if not (dboIgnoreAll in Opts) then begin
      &continue:=False;
      if not AMoreHitEventsPending then
        ALocationAddr := GetLocation;
    end;
    if  continue then
      exit;
  end
  else if (AnEventType = deInternalContinue) and FQuickPause then
    begin
      &continue:=true;
      exit;
    end
  else
    // Debugger returned after a step/next/step-out etc..
  if not AMoreHitEventsPending then
    ALocationAddr := GetLocation;


  if not continue then
    FPauseForEvent := True;

  if not AMoreHitEventsPending then begin
    FQuickPause := False; // Ok, because we will SetState => RunQuickPauseTasks is not needed
    if FPauseForEvent then
      &continue := False; // Only continue, if ALL events did say to continue

    EnterPause(ALocationAddr, &continue);
  end;
end;

procedure TFpDebugDebugger.EnterPause(ALocationAddr: TDBGLocationRec;
  AnInternalPause: Boolean);
begin
  if AnInternalPause then begin
    if not (State in [dsPause, dsInternalPause]) then begin
      SetState(dsInternalPause);
    end;
  end
  else begin
    if State <> dsPause then begin
      SetState(dsPause);
      DoCurrent(ALocationAddr);
    end;
  end;
end;

procedure TFpDebugDebugger.FDbgControllerCreateProcessEvent(var continue: boolean);
var
  addr: TDBGPtrArray;
begin
  // This will trigger setting the breakpoints,
  // may also trigger the evaluation of the callstack or disassembler.
  FSendingEvents := True; // Let DoStateChange know that the debugger is paused
  RunQuickPauseTasks(True);
  FSendingEvents := False;

  FExceptionStepper.DoProcessLoaded;

  if assigned(OnConsoleOutput) then
    FConsoleOutputThread := TFpWaitForConsoleOutputThread.Create(self);

  case FStartupCommand of
    dcRunTo: begin
      &continue := False;
      if FDbgController.CurrentProcess.DbgInfo.HasInfo then begin
        addr:=nil;
        if FDbgController.CurrentProcess.DbgInfo.GetLineAddresses(FStartuRunToFile, FStartuRunToLine, addr)
        then begin
          &continue := true;
          FDbgController.InitializeCommand(TDbgControllerRunToCmd.Create(FDbgController, addr));
        end;
      end;
      if not &continue then
        EnterPause(GetLocation);
    end;
  end;
end;

function TFpDebugDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const; const ACallback: TMethod): Boolean;
var
  EvalFlags: TDBGEvaluateFlags;
  AConsoleTty, ResText: string;
  addr: TDBGPtrArray;
  Cmd: TDBGCommand;
  WorkItem: TFpThreadWorkerControllerRun;
  AThreadId, AStackFrame: Integer;
  EvalWorkItem: TFpThreadWorkerCmdEval;
  WorkItemModify: TFpThreadWorkerModifyUpdate;
begin
  result := False;
  if assigned(FDbgController) then
    FDbgController.NextOnlyStopOnStartLine := TFpDebugDebuggerProperties(GetProperties).NextOnlyStopOnStartLine;

  if (ACommand in [dcRun, dcStepOver, dcStepInto, dcStepOut, dcStepTo, dcRunTo, dcJumpto,
      dcStepOverInstr, dcStepIntoInstr, dcAttach]) and
     not assigned(FDbgController.MainProcess)
  then
  begin
    FDbgController.ExecutableFilename:=FileName;
    AConsoleTty:=TFpDebugDebuggerProperties(GetProperties).ConsoleTty;
    FDbgController.ConsoleTty:=AConsoleTty;
    FDbgController.RedirectConsoleOutput:=AConsoleTty='';
    FDbgController.Params.Clear;
    if Arguments<>'' then
      CommandToList(Arguments, FDbgController.Params);
    FDbgController.WorkingDirectory:=WorkingDir;
    FDbgController.Environment:=Environment;
    {$ifdef windows}
    FDbgController.ForceNewConsoleWin:=TFpDebugDebuggerProperties(GetProperties).ForceNewConsole;
    {$endif windows}
    FDbgController.AttachToPid := 0;
    if ACommand = dcAttach then begin
      FDbgController.AttachToPid := StrToIntDef(String(AParams[0].VAnsiString), 0);
      Result := FDbgController.AttachToPid <> 0;
      if not Result then begin
        FileName := '';
        Exit;
      end;
    end;
    FWorkQueue.Clear;
    FWorkQueue.ThreadCount := 1;
    {$IFDEF FPDEBUG_THREAD_CHECK} CurrentFpDebugThreadIdForAssert := FWorkQueue.Threads[0].ThreadID;{$ENDIF}
    WorkItem := TFpThreadWorkerControllerRun.Create(Self);
    FWorkQueue.PushItem(WorkItem);
    FWorkQueue.WaitForItem(WorkItem, True);
    Result := WorkItem.StartSuccesfull;
    FWorkerThreadId := WorkItem.WorkerThreadId;
    WorkItem.DecRef;
    if not result then begin
      // TDebuggerIntf.SetFileName has set the state to dsStop, to make sure
      // that dcRun could be requested. Reset the filename so that the state
      // is set to dsIdle again and is set to dsStop on the next try
      // to run.
      FileName := '';
      FreeDebugThread;

      if not IsError(FDbgController.LastError) then
        ResText := 'Error starting process in debugger'
      else
        ResText := GetFpErrorHandler.ErrorAsString(FDbgController.LastError);
      DoDbgEvent(ecProcess, etProcessExit, ResText); // or ecDebugger?
      OnFeedback(self, ResText, '', ftError, [frOk]);
      Exit;
    end;
    // TODO: any step commond should run to "main" or "pascalmain"
    // Currently disabled in TFpDebugDebugger.GetSupportedCommands
    FStartupCommand := ACommand;
    if ACommand = dcRunTo then begin
      FStartuRunToFile := AnsiString(AParams[0].VAnsiString);
      FStartuRunToLine := AParams[1].VInteger;
    end;
    StartDebugLoop(dsInit);
    exit;
  end;

  Cmd := ACommand;
  FExceptionStepper.UserCommandRequested(Cmd);
  case Cmd of
    dcRun:
      begin
        Result := True;
        StartDebugLoop;
      end;
    dcStop:
      begin
        FDbgController.Stop;
        if state=dsPause then
          begin
          StartDebugLoop;
          end;
        result := true;
      end;
    dcStepIntoInstr:
      begin
        FDbgController.StepIntoInstr;
        StartDebugLoop;
        result := true;
      end;
    dcStepOverInstr:
      begin
        FDbgController.StepOverInstr;
        StartDebugLoop;
        result := true;
      end;
    dcPause:
      begin
        Result := FDbgController.Pause;
      end;
    dcStepTo:
      begin
        result := false;
        if FDbgController.CurrentProcess.DbgInfo.HasInfo then
          begin
          addr:=nil;
          if FDbgController.CurrentProcess.DbgInfo.GetLineAddresses(AnsiString(AParams[0].VAnsiString), AParams[1].VInteger, addr)
          then begin
            result := true;
            FDbgController.InitializeCommand(TDbgControllerStepToCmd.Create(FDbgController, AnsiString(AParams[0].VAnsiString), AParams[1].VInteger));
            StartDebugLoop;
            end;
          end;
      end;
    dcRunTo:
      begin
        result := false;
        if FDbgController.CurrentProcess.DbgInfo.HasInfo then
          begin
          addr:=nil;
          if FDbgController.CurrentProcess.DbgInfo.GetLineAddresses(AnsiString(AParams[0].VAnsiString), AParams[1].VInteger, addr)
          then begin
            result := true;
            FDbgController.InitializeCommand(TDbgControllerRunToCmd.Create(FDbgController, addr));
            StartDebugLoop;
            end;
          end;
      end;
    dcStepOver:
      begin
        FDbgController.InitializeCommand(TDbgControllerStepOverOrFinallyCmd.Create(FDbgController));
        StartDebugLoop;
        result := true;
      end;
    dcStepInto:
      begin
        FDbgController.Step;
        StartDebugLoop;
        result := true;
      end;
    dcStepOut:
      begin
        FDbgController.StepOut(True);
        StartDebugLoop;
        result := true;
      end;
    dcDetach:
      begin
        Result := FDbgController.Detach;
        if Result and (State in [dsPause, dsInternalPause]) then
          StartDebugLoop(State); // Keep current State
      end;
    dcEvaluate:
      begin
        EvalFlags := TDBGEvaluateFlags(AParams[1].VInteger);
        GetCurrentThreadAndStackFrame(AThreadId, AStackFrame);
        if FEvalWorkItem <> nil then begin
          EvalWorkItem := FEvalWorkItem;
          FEvalWorkItem := nil;
          EvalWorkItem.Abort;
          EvalWorkItem.DecRef;
        end;
        if defFullTypeInfo in EvalFlags then
          FEvalWorkItem := TFpThreadWorkerCmdEval.Create(Self, twpInspect, String(AParams[0].VAnsiString),
            AStackFrame, AThreadId, EvalFlags, TDBGEvaluateResultCallback(ACallback))
        else
          FEvalWorkItem := TFpThreadWorkerCmdEval.Create(Self, twpUser, String(AParams[0].VAnsiString),
            AStackFrame, AThreadId, EvalFlags, TDBGEvaluateResultCallback(ACallback));
        FWorkQueue.PushItem(FEvalWorkItem);
        Result := True;
      end;
    dcModify:
      begin
        GetCurrentThreadAndStackFrame(AThreadId, AStackFrame);
        WorkItemModify := TFpThreadWorkerModifyUpdate.Create(Self, AnsiString(AParams[0].VAnsiString), AnsiString(AParams[1].VAnsiString),
          AStackFrame, AThreadId);
        FWorkQueue.PushItem(WorkItemModify);
        WorkItemModify.DecRef;
        Result := True;
      end;
    dcSendConsoleInput:
      begin
        FDbgController.CurrentProcess.SendConsoleInput(String(AParams[0].VAnsiString));
      end;
  end; {case}
end;

function TFpDebugDebugger.ChangeFileName: Boolean;
begin
  result := true;
end;

function TFpDebugDebugger.ExecuteInDebugThread(AMethod: TFpDbgAsyncMethod
  ): boolean;
var
  WorkItem: TFpThreadWorkerAsyncMeth;
begin
  assert(ThreadID <> FWorkerThreadId, 'TFpDebugDebugger.ExecuteInDebugThread: ThreadID <> FWorkerThreadId');
  //Result := True;
  //if ThreadID = FWorkerThreadId then begin
  //  AMethod();
  //  exit;
  //end;

  Result := False;

  WorkItem := TFpThreadWorkerAsyncMeth.Create(Self, AMethod);
  FWorkQueue.PushItem(WorkItem);
  FWorkQueue.WaitForItem(WorkItem, True);
  WorkItem.DecRef;
end;

procedure TFpDebugDebugger.StartDebugLoop(AState: TDBGState);
var
  WorkItem: TFpThreadWorkerRunLoopUpdate;
begin
  {$ifdef DBG_FPDEBUG_VERBOSE}
  DebugLn(DBG_VERBOSE, 'StartDebugLoop');
  {$endif DBG_FPDEBUG_VERBOSE}
  SetState(AState);
  WorkItem := TFpThreadWorkerRunLoopUpdate.Create(Self);
  FWorkQueue.PushItem(WorkItem);
  WorkItem.DecRef;
end;

procedure TFpDebugDebugger.DebugLoopFinished(Data: PtrInt);
var
  Cont: boolean;
  WorkItem: TFpThreadWorkerRunLoopAfterIdleUpdate;
  c: Integer;
begin
  LockRelease;
  try
    {$ifdef DBG_FPDEBUG_VERBOSE}
    DebugLn(DBG_VERBOSE, 'DebugLoopFinished');
    {$endif DBG_FPDEBUG_VERBOSE}

    (* Need to ensure CurrentThreadId is correct,
       because any callstack (never mind which to which IDE-thread object it belongs
       will always get the data for the current thread only
     TODO: callstacks need a field with the thread-id to which they belong *)
    if (Threads <> nil) and (Threads.CurrentThreads <> nil) and
       (FDbgController.CurrentThread <> nil)
    then
      Threads.CurrentThreads.CurrentThreadId := FDbgController.CurrentThreadId;

    FPauseForEvent := False;
    FSendingEvents := True;
    try
      FDbgController.SendEvents(Cont); // This may free the TFpDebugDebugger (self)
      if State = dsRun then
        RunQuickPauseTasks;
    finally
      FSendingEvents := False;
    end;

    FQuickPause:=false;

    if Cont then begin
      if State in [dsPause, dsInternalPause] then begin
        FWorkQueue.Lock;
        CheckAndRunIdle;
        c := FWorkQueue.Count;
        FWorkQueue.Unlock;
      end
      else
        c := 0;

      if c = 0 then begin
        StartDebugLoop;
      end
      else begin
        WorkItem := TFpThreadWorkerRunLoopAfterIdleUpdate.Create(Self);
        FWorkQueue.PushItem(WorkItem);
        WorkItem.DecRef;
      end;
    end;
  finally
    UnlockRelease;
  end;
end;

procedure TFpDebugDebugger.QuickPause;
begin
  FQuickPause:=FDbgController.Pause;
end;

procedure TFpDebugDebugger.RunQuickPauseTasks(AForce: Boolean);
begin
  if AForce or
     FQuickPause
  then
    TFPBreakpoints(Breakpoints).DoStateChange(dsRun);
end;

procedure TFpDebugDebugger.DoRelease;
begin
  DebugLn(DBG_VERBOSE, ['++++ dorelase  ', Dbgs(ptrint(FDbgController)), dbgs(state)]);
  if FWorkQueue <> nil then
    FWorkQueue.OnQueueIdle := nil;
//  SetState(dsDestroying);
  if (State <> dsDestroying) and //assigned(FFpDebugThread) and //???
     (FDbgController <> nil) and (FDbgController.MainProcess <> nil)
  then begin
    FDbgController.Stop;
    FDbgControllerProcessExitEvent(0); // Force exit;
  end;

  inherited DoRelease;
end;

procedure TFpDebugDebugger.CheckAndRunIdle;
begin
  if (State <> dsPause) or
     (not Assigned(OnIdle)) or
     (FWorkQueue.Count <> 0)
  then
    exit;

  DebugLnEnter(DBG_VERBOSE, ['>> TFpDebugDebugger.CheckAndRunIdle ']);
  FIsIdle := True;
  try
    OnIdle(Self);
  except
    on E: Exception do
      DebugLn(['exception during idle ', E.ClassName, ': ', E.Message]);
  end;
  FIsIdle := False;
  DebugLnExit(DBG_VERBOSE, ['<< TFpDebugDebugger.CheckAndRunIdle ']);
end;

procedure TFpDebugDebugger.DoBeforeState(const OldState: TDBGState);
var
  EvalWorkItem: TFpThreadWorkerCmdEval;
begin
  if not (State in [dsPause, dsInternalPause]) then begin
    TFPThreads(Threads).StopWorkes;
    TFPCallStackSupplier(CallStack).StopWorkes;
    TFPWatches(Watches).StopWorkes;
    TFPLocals(Locals).StopWorkes;

    if FEvalWorkItem <> nil then begin
      EvalWorkItem := FEvalWorkItem;
      FEvalWorkItem := nil;
      EvalWorkItem.Abort;
      EvalWorkItem.DecRef;
    end;
  end;

  inherited DoBeforeState(OldState);
end;

procedure TFpDebugDebugger.DoState(const OldState: TDBGState);
begin
  LockRelease;
  try
    inherited DoState(OldState);
  finally
    UnlockRelease;
  end;
end;

function TFpDebugDebugger.GetIsIdle: Boolean;
begin
  Result := (FWorkQueue.Count = 0) or FIsIdle;
end;

procedure TFpDebugDebugger.DoAddBreakFuncLib;
begin
  if FCacheLib <> nil then
    FCacheBreakpoint := FCacheLib.AddBreak(FCacheFileName, FCacheBoolean)
  else
    FCacheBreakpoint := TDbgInstance(FDbgController.CurrentProcess).AddBreak(FCacheFileName, FCacheBoolean);
end;

procedure TFpDebugDebugger.DoAddBreakLocation;
begin
  if FCacheLocation = 0 then
    FCacheBreakpoint := FDbgController.CurrentProcess.AddBreak(nil, FCacheBoolean)
  else
    FCacheBreakpoint := FDbgController.CurrentProcess.AddBreak(FCacheLocation, FCacheBoolean);
end;

procedure TFpDebugDebugger.DoReadData;
begin
  FCacheBoolean:=FDbgController.CurrentProcess.ReadData(FCacheLocation, FCacheLine, FCachePointer^);
end;

procedure TFpDebugDebugger.DoReadPartialData;
begin
  FCacheBoolean:=FDbgController.CurrentProcess.ReadData(FCacheLocation, FCacheLine, FCachePointer^, FCacheBytesRead);
end;

procedure TFpDebugDebugger.DoFindContext;
begin
  FCacheContext := FDbgController.CurrentProcess.FindSymbolScope(FCacheThreadId, FCacheStackFrame);
end;

procedure TFpDebugDebugger.DoSetStackFrameForBasePtr;
begin
  FDbgController.CurrentThread.PrepareCallStackEntryList(7);
  if (FCacheLocation = 0) and (FCacheLocation2 <> 0) then
    FCacheStackFrame := FDbgController.CurrentThread.FindCallStackEntryByInstructionPointer(FCacheLocation2, 15, 1)
  else
    FCacheStackFrame := FDbgController.CurrentThread.FindCallStackEntryByBasePointer(FCacheLocation, 30, 1);
end;

function TFpDebugDebugger.AddBreak(const ALocation: TDbgPtr; AnEnabled: Boolean
  ): TFpDbgBreakpoint;
begin
  // Shortcut, if in debug-thread / do not use Self.F*
  if ThreadID = FWorkerThreadId then
    if ALocation = 0 then exit(FDbgController.CurrentProcess.AddBreak(nil, AnEnabled))
                     else exit(FDbgController.CurrentProcess.AddBreak(ALocation, AnEnabled));

  FCacheLocation:=ALocation;
  FCacheBoolean:=AnEnabled;
  FCacheBreakpoint := nil;
  ExecuteInDebugThread(@DoAddBreakLocation);
  result := FCacheBreakpoint;
end;

function TFpDebugDebugger.AddBreak(const AFuncName: String; ALib: TDbgLibrary;
  AnEnabled: Boolean): TFpDbgBreakpoint;
begin
  // Shortcut, if in debug-thread / do not use Self.F*
  if ThreadID = FWorkerThreadId then
    if ALib <> nil then exit(ALib.AddBreak(AFuncName, AnEnabled))
                   else exit(TDbgInstance(FDbgController.CurrentProcess).AddBreak(AFuncName, AnEnabled));

  FCacheFileName:=AFuncName;
  FCacheLib:=ALib;
  FCacheBoolean:=AnEnabled;
  FCacheBreakpoint := nil;
  ExecuteInDebugThread(@DoAddBreakFuncLib);
  result := FCacheBreakpoint;
end;

function TFpDebugDebugger.ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean;
begin
  // Shortcut, if in debug-thread / do not use Self.F*
  if ThreadID = FWorkerThreadId then
    exit(FDbgController.CurrentProcess.ReadData(AAdress, ASize, AData));

  FCacheLocation := AAdress;
  FCacheLine:=ASize;
  FCachePointer := @AData;
  FCacheBoolean := False;
  ExecuteInDebugThread(@DoReadData);
  result := FCacheBoolean;
end;

function TFpDebugDebugger.ReadData(const AAdress: TDbgPtr;
  const ASize: Cardinal; out AData; out ABytesRead: Cardinal): Boolean;
begin
  // Shortcut, if in debug-thread / do not use Self.F*
  if ThreadID = FWorkerThreadId then
    exit(FDbgController.CurrentProcess.ReadData(AAdress, ASize, AData, ABytesRead));

  FCacheLocation := AAdress;
  FCacheLine:=ASize;
  FCachePointer := @AData;
  FCacheBoolean := False;
  FCacheBytesRead := 0;
  ExecuteInDebugThread(@DoReadPartialData);
  result := FCacheBoolean;
  ABytesRead := FCacheBytesRead;
end;

function TFpDebugDebugger.ReadAddress(const AAdress: TDbgPtr; out AData: TDBGPtr): Boolean;
var
  dw: DWord;
  qw: QWord;
begin
  case FDbgController.CurrentProcess.Mode of
    dm32:
      begin
        result := ReadData(AAdress, sizeof(dw), dw);
        AData:=dw;
      end;
    dm64:
      begin
        result := ReadData(AAdress, sizeof(qw), qw);
        AData:=qw;
      end;
  end;
end;

function TFpDebugDebugger.SetStackFrameForBasePtr(ABasePtr: TDBGPtr;
  ASearchAssert: boolean; CurAddr: TDBGPtr): TDBGPtr;
const
  SYS_ASSERT_NAME = 'SYSUTILS_$$_ASSERT'; // AssertErrorHandler, in case the assert is hidden in the stack
var
  f: Integer;
  CList: TDbgCallstackEntryList;
  P: TFpSymbol;
begin
  assert(GetCurrentThreadId=MainThreadID, 'TFpDebugDebugger.SetStackFrameForBasePtr: GetCurrentThreadId=MainThreadID');

  Result := 0;
  if FDbgController.CurrentThread = nil then
    exit;
  FCacheLocation:=ABasePtr;
  FCacheLocation2:=CurAddr;
  ExecuteInDebugThread(@DoSetStackFrameForBasePtr);
  f := FCacheStackFrame;

  if (f >= 2) and ASearchAssert and (ABasePtr <> 0) then begin
    // stack is already prepared / exe in thread not needed
    CList := FDbgController.CurrentThread.CallStackEntryList;
    if (CList[f].AnAddress = CurAddr) then begin
      P := CList[f-2].ProcSymbol;
      if (P <> nil) and
         ( (P.Name = 'FPC_ASSERT') or (P.Name = 'fpc_assert') or
           (P.Name = 'ASSERT') or (P.Name = 'assert') or
           (CompareText(copy(P.Name, 1, length(SYS_ASSERT_NAME)), SYS_ASSERT_NAME) = 0) )
      then begin
        dec(f);
        Result := CList[f].AnAddress - 1;
      end;
    end;
  end
  else
  if (ABasePtr = 0) and (CurAddr <> 0) and (f > 0) then begin
    Result := CurAddr - 1; // found address on stack, so this is return address
  end;

  if f > 0 then begin
    TFPCallStackSupplier(CallStack).FThreadForInitialFrame := FDbgController.CurrentThread.ID;
    TFPCallStackSupplier(CallStack).FInitialFrame := f;
  end;
end;

function TFpDebugDebugger.FindSymbolScope(AThreadId, AStackFrame: Integer): TFpDbgSymbolScope;
begin
  assert(GetCurrentThreadId=MainThreadID, 'TFpDebugDebugger.FindSymbolScope: GetCurrentThreadId=MainThreadID');
  FCacheThreadId := AThreadId;
  FCacheStackFrame := AStackFrame;
  FCacheContext := nil;
  ExecuteInDebugThread(@DoFindContext);
  Result := FCacheContext;
end;

procedure TFpDebugDebugger.StopAllWorkers;
begin
  TFPThreads(Threads).StopWorkes;
  TFPCallStackSupplier(CallStack).StopWorkes;
  TFPWatches(Watches).StopWorkes;
  TFPLocals(Locals).StopWorkes;
  if FEvalWorkItem <> nil then begin
    FEvalWorkItem.Abort;
    FEvalWorkItem.DecRef;
    FEvalWorkItem := nil;
  end;
end;

function TFpDebugDebugger.IsPausedAndValid: boolean;
begin
  Result := False;
  if self = nil then
    exit;
  Result := (State in [dsPause, dsInternalPause]) and
            (FDbgController <> nil) and
            (FDbgController.CurrentProcess <> nil);
end;

constructor TFpDebugDebugger.Create(const AExternalDebugger: String);
begin
  ProcessMessagesProc := @Application.ProcessMessages;
  inherited Create(AExternalDebugger);
  FLockList := TFpDbgLockList.Create;
  FWorkQueue := TFpThreadPriorityWorkerQueue.Create(100);
  FWorkQueue.OnQueueIdle := @CheckAndRunIdle;
  FExceptionStepper := TFpDebugExceptionStepping.Create(Self);
  FPrettyPrinter := TFpPascalPrettyPrinter.Create(sizeof(pointer));
  FMemReader := TFpDbgMemReader.Create(self);
  FMemConverter := TFpDbgMemConvertorLittleEndian.Create;
  FMemManager := TFpDbgMemManager.Create(FMemReader, FMemConverter);
  FMemManager.MemLimits.MaxMemReadSize := TFpDebugDebuggerProperties(GetProperties).MemLimits.MaxMemReadSize;
  FMemManager.MemLimits.MaxArrayLen := TFpDebugDebuggerProperties(GetProperties).MemLimits.MaxArrayLen;
  FMemManager.MemLimits.MaxStringLen := TFpDebugDebuggerProperties(GetProperties).MemLimits.MaxStringLen;
  FMemManager.MemLimits.MaxNullStringSearchLen := TFpDebugDebuggerProperties(GetProperties).MemLimits.MaxNullStringSearchLen;
  FDbgController := TDbgController.Create(FMemManager);
  FDbgController.OnCreateProcessEvent:=@FDbgControllerCreateProcessEvent;
  FDbgController.OnHitBreakpointEvent:=@FDbgControllerHitBreakpointEvent;
  FDbgController.OnProcessExitEvent:=@FDbgControllerProcessExitEvent;
  FDbgController.OnExceptionEvent:=@FDbgControllerExceptionEvent;
  FDbgController.OnDebugInfoLoaded := @FDbgControllerDebugInfoLoaded;
  FDbgController.OnLibraryLoadedEvent := @FDbgControllerLibraryLoaded;
  FDbgController.OnLibraryUnloadedEvent := @FDbgControllerLibraryUnloaded;
  FDbgController.NextOnlyStopOnStartLine := TFpDebugDebuggerProperties(GetProperties).NextOnlyStopOnStartLine;

  FDbgController.OnThreadProcessLoopCycleEvent:=@FExceptionStepper.ThreadProcessLoopCycle;
  FDbgController.OnThreadBeforeProcessLoop:=@FExceptionStepper.ThreadBeforeLoop;
end;

destructor TFpDebugDebugger.Destroy;
begin
  FWorkQueue.OnQueueIdle := nil;
  FWorkQueue.DoShutDown;
  StopAllWorkers;
  FWorkQueue.TerminateAllThreads(False);

  if state in [dsPause, dsInternalPause] then
    try
      SetState(dsStop);
    except
    end;
  FWorkQueue.TerminateAllThreads(True);
  Application.ProcessMessages; // run the AsyncMethods
  {$IFDEF FPDEBUG_THREAD_CHECK} CurrentFpDebugThreadIdForAssert := MainThreadID;{$ENDIF}

  Application.RemoveAsyncCalls(Self);
  FreeAndNil(FDbgController);
  FreeAndNil(FPrettyPrinter);
  FreeAndNil(FMemManager);
  FreeAndNil(FMemConverter);
  FreeAndNil(FMemReader);
  FreeAndNil(FExceptionStepper);
  inherited Destroy;
  FreeAndNil(FWorkQueue);
  FreeAndNil(FLockList);
end;

function TFpDebugDebugger.GetLocationRec(AnAddress: TDBGPtr;
  AnAddrOffset: Integer): TDBGLocationRec;
var
  sym, symproc: TFpSymbol;
begin
  if Assigned(FDbgController.CurrentProcess) then
    begin
    result.FuncName:='';
    result.SrcFile:='';
    result.SrcFullName:='';
    result.SrcLine:=0;

    if AnAddress=0 then
      result.Address := FDbgController.CurrentThread.GetInstructionPointerRegisterValue
    else
      result.Address := AnAddress;

    {$PUSH}{$R-}{$Q-}
    sym := FDbgController.CurrentProcess.FindProcSymbol(result.Address + AnAddrOffset);
    {$POP}
    if sym = nil then
      Exit;

    result.SrcFile := ExtractFileName(sym.FileName);
    result.SrcLine := sym.Line;
    result.SrcFullName := sym.FileName;

    symproc := sym;
    //while not (symproc.kind in [skProcedure, skFunction]) do
    //  symproc := symproc.Parent;

    if assigned(symproc) then
      result.FuncName:=symproc.Name;
    sym.ReleaseReference;
    end
end;

function TFpDebugDebugger.GetLocation: TDBGLocationRec;
begin
  Result:=GetLocationRec;
end;

class function TFpDebugDebugger.Caption: String;
begin
  Result:='FpDebug internal Dwarf-debugger';
end;

class function TFpDebugDebugger.NeedsExePath: boolean;
begin
  Result:=False;
end;

class function TFpDebugDebugger.RequiredCompilerOpts(ATargetCPU, ATargetOS: String): TDebugCompilerRequirements;
begin
  {$ifdef CD_Cocoa}{$DEFINE MacOS}
  if ATargetCPU = '' then ATargetCPU := 'x86_64';
  {$ENDIF}
  {$IFDEF Darwin}{$DEFINE MacOS}
  if ATargetCPU = '' then ATargetCPU := 'i386';
  {$ENDIF}
  {$IFDEF MacOs}
  if LowerCase(ATargetCPU) = 'i386' then
    Result:=[dcrDwarfOnly] // carbon
  else
    Result:=[dcrExternalDbgInfoOnly, dcrDwarfOnly]; // cocoa
  {$ELSE}
  Result:=[dcrNoExternalDbgInfo, dcrDwarfOnly];
  {$ENDIF}
end;

class function TFpDebugDebugger.CreateProperties: TDebuggerProperties;
begin
  Result := TFpDebugDebuggerProperties.Create;
end;

function TFpDebugDebugger.GetCommands: TDBGCommands;
begin
  Result := inherited GetCommands;
  if State = dsStop then
    Result := Result - [dcStepInto, dcStepOver, dcStepOut, dcStepIntoInstr, dcStepOverInstr];
end;

procedure TFpDebugDebugger.LockCommandProcessing;
begin
  //inherited LockCommandProcessing;
//  FWorkQueue.Lock;
end;

procedure TFpDebugDebugger.UnLockCommandProcessing;
begin
  //inherited UnLockCommandProcessing;
//  FWorkQueue.Unlock;
end;

class function TFpDebugDebugger.GetSupportedCommands: TDBGCommands;
begin
  Result:=[dcRun, dcStop, dcStepIntoInstr, dcStepOverInstr, dcStepOver,
           dcStepTo, dcRunTo, dcPause, dcStepOut, dcStepInto, dcEvaluate, dcModify,
           dcSendConsoleInput
           {$IFDEF windows} , dcAttach, dcDetach {$ENDIF}
           {$IFDEF linux} , dcAttach, dcDetach {$ENDIF}
          ];
end;

class function TFpDebugDebugger.SupportedCommandsFor(AState: TDBGState
  ): TDBGCommands;
begin
  Result := inherited SupportedCommandsFor(AState);
  if AState = dsStop then
    Result := Result - [dcStepInto, dcStepOver, dcStepOut, dcStepIntoInstr, dcStepOverInstr];
end;

class function TFpDebugDebugger.SupportedFeatures: TDBGFeatures;
begin
  Result := [dfEvalFunctionCalls];
end;

initialization
  DBG_VERBOSE     := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_WARNINGS    := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
  DBG_BREAKPOINTS := DebugLogger.FindOrRegisterLogGroup('DBG_BREAKPOINTS' {$IFDEF DBG_BREAKPOINTS} , True {$ENDIF} );
  FPDBG_COMMANDS  := DebugLogger.FindOrRegisterLogGroup('FPDBG_COMMANDS' {$IFDEF FPDBG_COMMANDS} , True {$ENDIF} );

end.


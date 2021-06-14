unit FPDbgController;

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}

interface

uses
  Classes,
  SysUtils,
  Maps,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazClasses,
  DbgIntfBaseTypes, DbgIntfDebuggerBase,
  FpDbgDisasX86,
  FpDbgClasses, FpDbgCallContextInfo, FpDbgUtil,
  {$ifdef windows}  FpDbgWinClasses,  {$endif}
  {$ifdef darwin}  FpDbgDarwinClasses,  {$endif}
  {$ifdef linux}  FpDbgLinuxClasses,  {$endif}
  FpDbgInfo, FpDbgDwarf, FpdMemoryTools, FpErrorMessages;

type

  TDbgController = class;
  TDbgControllerCmd = class;

  TOnCreateProcessEvent = procedure(var continue: boolean) of object;
  TOnHitBreakpointEvent = procedure(var continue: boolean; const Breakpoint: TFpDbgBreakpoint;
    AnEventType: TFPDEvent; AMoreHitEventsPending: Boolean) of object;
  TOnExceptionEvent = procedure(var continue: boolean; const ExceptionClass, ExceptionMessage: string) of object;
  TOnProcessExitEvent = procedure(ExitCode: DWord) of object;
  TOnLibraryLoadedEvent = procedure(var continue: boolean; ALib: TDbgLibrary) of object;
  TOnLibraryUnloadedEvent = procedure(var continue: boolean; ALib: TDbgLibrary) of object;
  TOnProcessLoopCycleEvent = procedure(var AFinishLoopAndSendEvents: boolean; var AnEventType: TFPDEvent;
    var ACurCommand: TDbgControllerCmd; var AnIsFinished: boolean) of object;

  { TDbgControllerCmd }

  TDbgControllerCmd = class
  private
    procedure SetThread(AValue: TDbgThread);
  protected
    FController: TDbgController;
    FThread: TDbgThread;
    FProcess: TDbgProcess;
    FThreadRemoved: boolean;
    FIsInitialized: Boolean;
    FNextInstruction: TDbgAsmInstruction;
    procedure Init; virtual;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); virtual; abstract;
  public
    constructor Create(AController: TDbgController); virtual;
    destructor Destroy; override;
    procedure DoBeforeLoopStart;
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); virtual; abstract;
    procedure ResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
    function NextInstruction: TDbgAsmInstruction; inline;
    property Thread: TDbgThread read FThread write SetThread;
  end;

  { TDbgControllerContinueCmd }

  TDbgControllerContinueCmd = class(TDbgControllerCmd)
  protected
    procedure Init; override;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
  public
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  end;

  { TDbgControllerStepIntoInstructionCmd }

  TDbgControllerStepIntoInstructionCmd = class(TDbgControllerCmd)
  protected
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
  public
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  end;

  { TDbgControllerHiddenBreakStepBaseCmd }

  TDbgControllerHiddenBreakStepBaseCmd = class(TDbgControllerCmd)
  private
    FStackFrameInfo: TDbgStackFrameInfo;
    FHiddenBreakpoint: TFpInternalBreakpoint;
    FHiddenBreakAddr, FHiddenBreakInstrPtr, FHiddenBreakFrameAddr, FHiddenBreakStackPtrAddr: TDBGPtr;
    function GetIsSteppedOut: Boolean;
  protected
    function IsAtHiddenBreak: Boolean; inline;
    function HasHiddenBreak: Boolean; inline;
    function IsAtLastHiddenBreakAddr: Boolean; inline;
    function IsAtOrOutOfHiddenBreakFrame: Boolean;  inline; // Stopped in/out-of the origin frame, maybe by a breakpoint after an exception
    procedure SetHiddenBreak(AnAddr: TDBGPtr);
    procedure RemoveHiddenBreak;
    function CheckForCallAndSetBreak: boolean; // True, if break is newly set

    procedure InitStackFrameInfo; inline;

    procedure CallProcessContinue(ASingleStep: boolean; ASkipCheckNextInstr: Boolean = False);
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); virtual; abstract;
  public
    destructor Destroy; override;
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;

    property StoredStackFrameInfo: TDbgStackFrameInfo read FStackFrameInfo;
    property IsSteppedOut: Boolean read GetIsSteppedOut;
  end;

  { TDbgControllerStepOverInstructionCmd }

  TDbgControllerStepOverInstructionCmd = class(TDbgControllerHiddenBreakStepBaseCmd)
  protected
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  end;

  { TDbgControllerLineStepBaseCmd }

  TDbgControllerLineStepBaseCmd = class(TDbgControllerHiddenBreakStepBaseCmd)
  private
    FWasAtJumpInstruction: Boolean;

    FStartedInFuncName: String;
    FStepInfoUpdatedForStepOut, FStepInfoUnavailAfterStepOut: Boolean;
    FStoreStepInfoAtInit: Boolean;
  protected
    procedure Init; override;
    procedure UpdateThreadStepInfoAfterStepOut(ANextOnlyStopOnStartLine: Boolean);
    function HasReachedEndLineForStep: boolean; virtual;
    function HasReachedEndLineOrSteppedOut(ANextOnlyStopOnStartLine: Boolean): boolean; // Call only, if in original frame (or updated frame)

    procedure StoreWasAtJumpInstruction;
    function  IsAtJumpPad: Boolean;

  public
    constructor Create(AController: TDbgController; AStoreStepInfoAtInit: Boolean = False);
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;

    property StartedInFuncName: String read FStartedInFuncName;
  end;

  { TDbgControllerStepIntoLineCmd }

  TDbgControllerStepIntoLineCmd = class(TDbgControllerLineStepBaseCmd)
  private
    FState: (siSteppingCurrent, siSteppingIn, siSteppingNested, siRunningStepOut);
    FStepCount, FNestDepth: Integer;
  protected
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  public
    constructor Create(AController: TDbgController);
  end;

  { TDbgControllerStepOverLineCmd }

  TDbgControllerStepOverLineCmd = class(TDbgControllerLineStepBaseCmd)
  protected
    procedure Init; override;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  public
    constructor Create(AController: TDbgController);
  end;


  { TDbgControllerCallRoutineCmd }

  // This command is used to call a function of the debugee.
  // First the state of the debugee is preserved, then the function is
  // called from the current location of the instruction pointer and afterwards
  // the debugee is restored into the original state.
  // The provided context is used to store the register values just after
  // the call has been made. This way it is possible to evaluate expressions to
  // gather the function-result, using this context.
  TDbgControllerCallRoutineCmd = class(TDbgControllerCmd)
  protected
    // Calling the function is done in two steps:
    //  - first execute one instruction so that the debugee jumps into the function (sSingleStep)
    //  - then run until the function has been completed (sRunRoutine)
    type TStep = (sSingleStep, sRunRoutine);
  protected
    FOriginalCode: array of byte;
    FOriginalInstructionPointer: TDBGPtr;
    FReturnAdress: TDBGPtr;
    FRoutineAddress: TDBGPtr;
    FStep: TStep;
    FHiddenBreakpoint: TFpInternalBreakpoint;
    FCallContext: TFpDbgInfoCallContext;
    procedure Init; override;

    procedure InsertCallInstructionCode;
    procedure RestoreOriginalCode;
    procedure SetHiddenBreakpointAtReturnAddress(AnAddress: TDBGPtr);
    procedure RemoveHiddenBreakpointAtReturnAddress();
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure StoreInstructionPointer;
    procedure RestoreInstructionPointer;
    procedure StoreRoutineResult;
    procedure StoreRegisters;
    procedure RestoreRegisters;
  public
    constructor Create(AController: TDbgController; ARoutineAddress: TFpDbgMemLocation; ACallContext:TFpDbgInfoCallContext);
    procedure DoContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  end;


  { TDbgControllerStepOutCmd }

  TDbgControllerStepOutCmd = class(TDbgControllerLineStepBaseCmd)
// TODO: do not store the initial line info
  private
    FStepCount: Integer;
    FWasOutsideFrame: boolean;
  protected
    function  GetOutsideFrame(var AnOutside: Boolean): Boolean;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  public
    procedure SetReturnAdressBreakpoint(AProcess: TDbgProcess; AnOutsideFrame: Boolean);
  end;

  { TDbgControllerRunToCmd }

  TDbgControllerRunToCmd = class(TDbgControllerHiddenBreakStepBaseCmd)
  private
    FLocation: TDBGPtrArray;
  protected
    procedure Init; override;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  public
    constructor Create(AController: TDbgController; ALocation: TDBGPtrArray);
  end;

  { TDbgControllerStepToCmd }

  TDbgControllerStepToCmd = class(TDbgControllerLineStepBaseCmd)
  private
    FTargetFilename: String;
    FTargetLineNumber: Integer;
    FTargetExists: Boolean;
    FStoreStepStartAddr, FStoreStepEndAddr: TDBGPtr;
  protected
    procedure Init; override;
    function HasReachedEndLineForStep: boolean; override;
    procedure DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean); override;
    procedure InternalContinue(AProcess: TDbgProcess; AThread: TDbgThread); override;
  public
    constructor Create(AController: TDbgController; const ATargetFilename: String; ATargetLineNumber: Integer);
  end;

  { TDbgController }

  TDbgController = class
  private
    FLastError: TFpError;
    FMemManager: TFpDbgMemManager;
    FDefaultContext: TFpDbgLocationContext;
    FOnLibraryLoadedEvent: TOnLibraryLoadedEvent;
    FOnLibraryUnloadedEvent: TOnLibraryUnloadedEvent;
    FOnThreadBeforeProcessLoop: TNotifyEvent;
    FOnThreadProcessLoopCycleEvent: TOnProcessLoopCycleEvent;
    FOsDbgClasses: TOSDbgClasses;
    FRunning, FPauseRequest: cardinal;
    FAttachToPid: Integer;
    FDetaching: cardinal;
    FEnvironment: TStrings;
    FExecutableFilename: string;
    FForceNewConsoleWin: boolean;
    FNextOnlyStopOnStartLine: boolean;
    FOnCreateProcessEvent: TOnCreateProcessEvent;
    FOnDebugInfoLoaded: TNotifyEvent;
    FOnExceptionEvent: TOnExceptionEvent;
    FOnHitBreakpointEvent: TOnHitBreakpointEvent;
    FOnProcessExitEvent: TOnProcessExitEvent;
    FProcessMap: TMap;
    FPDEvent: TFPDEvent;
    FParams: TStringList;
    FConsoleTty: string;
    FRedirectConsoleOutput: boolean;
    FWorkingDirectory: string;
    function GetCurrentThreadId: Integer;
    function GetDefaultContext: TFpDbgLocationContext;
    procedure SetCurrentThreadId(AValue: Integer);
    procedure SetEnvironment(AValue: TStrings);
    procedure SetExecutableFilename(const AValue: string);
    procedure DoOnDebugInfoLoaded(Sender: TObject);
    procedure SetParams(AValue: TStringList);

    procedure CheckExecutableAndLoadClasses;
  protected
    FMainProcess: TDbgProcess;
    FCurrentProcess: TDbgProcess;
    FCurrentThread: TDbgThread;
    FCommand, FCommandToBeFreed: TDbgControllerCmd;
    function GetProcess(const AProcessIdentifier: THandle; out AProcess: TDbgProcess): Boolean;
  public
    constructor Create(AMemManager: TFpDbgMemManager); virtual;
    destructor Destroy; override;
    (* InitializeCommand: set new command
       Not called if command is replaced by OnThreadProcessLoopCycleEvent  *)
    procedure InitializeCommand(ACommand: TDbgControllerCmd);
    procedure AbortCurrentCommand;
    function Run: boolean;
    procedure Stop;
    procedure StepIntoInstr;
    procedure StepOverInstr;
    procedure Next;
    procedure Step;
    function Call(const FunctionAddress: TFpDbgMemLocation; const ABaseContext: TFpDbgLocationContext; const AMemReader: TFpDbgMemReaderBase; const AMemConverter: TFpDbgMemConvertor): TFpDbgInfoCallContext;
    procedure StepOut(AForceStoreStepInfo: Boolean = False);
    function Pause: boolean;
    function Detach: boolean;
    procedure ProcessLoop;
    procedure SendEvents(out continue: boolean);
    property CurrentCommand: TDbgControllerCmd read FCommand;
    property OsDbgClasses: TOSDbgClasses read FOsDbgClasses;
    property MemManager: TFpDbgMemManager read FMemManager;
    property DefaultContext: TFpDbgLocationContext read GetDefaultContext; // CurrentThread, TopStackFrame
    property LastError: TFpError read FLastError;

    property ExecutableFilename: string read FExecutableFilename write SetExecutableFilename;
    property AttachToPid: Integer read FAttachToPid write FAttachToPid;
    property CurrentProcess: TDbgProcess read FCurrentProcess;
    property CurrentThread: TDbgThread read FCurrentThread;
    property CurrentThreadId: Integer read GetCurrentThreadId write SetCurrentThreadId;
    property MainProcess: TDbgProcess read FMainProcess;
    property Params: TStringList read FParams write SetParams;
    property Environment: TStrings read FEnvironment write SetEnvironment;
    property WorkingDirectory: string read FWorkingDirectory write FWorkingDirectory;
    property RedirectConsoleOutput: boolean read FRedirectConsoleOutput write FRedirectConsoleOutput;
    property ForceNewConsoleWin: boolean read FForceNewConsoleWin write FForceNewConsoleWin; // windows only
    property ConsoleTty: string read FConsoleTty write FConsoleTty;
    // With this parameter set a 'next' will only stop if the current
    // instruction is the first instruction of a line according to the
    // debuginfo.
    // Due to a bug in fpc's debug-info, the line info for the first instruction
    // of a line, sometimes points the the prior line. This setting hides the
    // results of that bug. It seems like it that GDB does something similar.
    property NextOnlyStopOnStartLine: boolean read FNextOnlyStopOnStartLine write FNextOnlyStopOnStartLine;

    property OnCreateProcessEvent: TOnCreateProcessEvent read FOnCreateProcessEvent write FOnCreateProcessEvent;
    (* OnHitBreakpointEvent(
         var continue: boolean;   // Passed in value always defaults to false.
                                  // Returned value indicated, if the debugger should continue running.
                                  // I.e., the current Command (e.g. Stepping) will be kept for continuation, if possible.
                                  // Returned value may be ignored (treated as "False") where indicated.
         const Breakpoint: TFpDbgBreakpoint; // Break or Watch, if avail
         AnEventType: TFPDEvent;             // reason: See below
         AMoreHitEventsPending: Boolean      // The debugger stopped for more than one reason.
                                             // There will be further calls to OnHitBreakpointEvent
                                             // This will NOT be set for the final "pause-requested" event.
      )
      will be called as follows.

      Currently only ONE watchpoint, and only ONE breakpoint can be reported.
      This may change.

      1) Step In/Over/Out ended.
         - Up to THREE calls may be made. (A 4th call for "pause-request" may also happen)
         - The value for "continue" will be ignored.
           (The value of "continue" from the final call will however affect,
            if a call for "pause-request" is made)
         * If the step ended at a breakpoint and/or triggered a watchpoint
           additional calls are made upfront.
           The debugger should handle the break/watchpoint, but not yet pause.
           => OnHitBreakpointEvent(Continue, WatchPoint, deFinishedStep, True);
           => OnHitBreakpointEvent(Continue, BreakPoint, deFinishedStep, True);
         * ALWAYS for the ended step
           => OnHitBreakpointEvent(Continue, nil, deFinishedStep, False);

      2) BreakPoint/WatchPoint/HardcodedBreakPoint was hit.
         - Up to THREE calls may be made. (A 4th call for "pause-request" may also happen)
         - The value for "continue" after each call will be be kept, and passed
           to each subsequent call.
         * For a hardcoded-BreakPoint (int3)
           => OnHitBreakpointEvent(Continue, nil, deHardCodedBreakpoint, True_If_More_events);
         * For a WatchPoint
           => OnHitBreakpointEvent(Continue, WatchPoint, deBreakpoint, True_If_More_events);
         * For a BreakPoint
           => OnHitBreakpointEvent(Continue, BreakPoint, deBreakpoint, False);

      3) If there was a pause request (TDbgController.Pause).
         This call to OnHitBreakpointEvent can happen after any event.
         That is this can happen, after a step or breakpoint was reported according to
           the above details. But it can also happen after an exceptedion or other event.
           (except deExitProcess).
         This call will only be made, if any prior call returned "continue = true".
         => OnHitBreakpointEvent(Continue, nil, deInternalContinue, False);
    *)
    property OnHitBreakpointEvent: TOnHitBreakpointEvent read FOnHitBreakpointEvent write FOnHitBreakpointEvent;
    property OnProcessExitEvent: TOnProcessExitEvent read FOnProcessExitEvent write FOnProcessExitEvent;
    property OnExceptionEvent: TOnExceptionEvent read FOnExceptionEvent write FOnExceptionEvent;
    property OnDebugInfoLoaded: TNotifyEvent read FOnDebugInfoLoaded write FOnDebugInfoLoaded;
    property OnLibraryLoadedEvent: TOnLibraryLoadedEvent read FOnLibraryLoadedEvent write FOnLibraryLoadedEvent;
    property OnLibraryUnloadedEvent: TOnLibraryUnloadedEvent read FOnLibraryUnloadedEvent write FOnLibraryUnloadedEvent;
    (* Events fired inside the debug thread.
       The "continue" param, is true by default. It is treated as: "continue to sent this event in procedure "SendEvents"
       By setting "continue" to false, the event can be hidden.
       That is, the debug thread will not interrupt for "SendEvents"
    *)

    property OnThreadBeforeProcessLoop: TNotifyEvent read FOnThreadBeforeProcessLoop write FOnThreadBeforeProcessLoop;
    property OnThreadProcessLoopCycleEvent: TOnProcessLoopCycleEvent read FOnThreadProcessLoopCycleEvent write FOnThreadProcessLoopCycleEvent;
  end;

implementation

uses
  FpImgReaderBase, FpDbgCommon;

var
  DBG_VERBOSE, DBG_WARNINGS, FPDBG_COMMANDS: PLazLoggerLogGroup;

{ TDbgControllerCallRoutineCmd }

constructor TDbgControllerCallRoutineCmd.Create(AController: TDbgController; ARoutineAddress: TFpDbgMemLocation; ACallContext: TFpDbgInfoCallContext);
begin
  inherited Create(AController);

  {$IFNDEF Linux}
  {$IFNDEF Windows}
  raise Exception.Create('Calling functions is only supported on Linux');
  {$ENDIF}
  {$ENDIF}

  {$IFDEF Linux}
  if FController.CurrentProcess.Mode <> dm64 then
    raise Exception.Create('Calling functions is only supported on 64-bits (x86_64)');
  {$ENDIF}

  FRoutineAddress := LocToAddr(ARoutineAddress);
  FCallContext := ACallContext;

  StoreRegisters;
end;

procedure TDbgControllerCallRoutineCmd.Init;
begin
  inherited Init;

  FStep := sSingleStep;
  StoreInstructionPointer;
  InsertCallInstructionCode;
end;

procedure TDbgControllerCallRoutineCmd.InsertCallInstructionCode;
var
  CurrentIP : TDBGPtr;
  Buf: array of Byte;
  RelAddr: Int32;
  DW: PInt32;
begin
  // Get the address of the current instruction.
  CurrentIP := FController.CurrentThread.GetInstructionPointerRegisterValue;

  // Store the original code of the current instruction
  SetLength(FOriginalCode, 5);
  if not FProcess.ReadData(CurrentIP, 5, FOriginalCode[0]) then
  raise Exception.Create('Failed to read the original code at the instruction pointer');

  // Calculate the relative offset between the address of the current instruction
  // and the address of the function we want to call.
  if Abs(Int64(FRoutineAddress)-Int64(CurrentIP))>=MaxSIntValue then
    raise Exception.Create('Calling this function is not supported. Offset to the function that is to be called is too high.');
  RelAddr := Int32(FRoutineAddress) - (Int32(CurrentIP) + 5); // 5 is the size of the instruction we are about to add.

  // Construct the code to call the function.
  SetLength(Buf, 5);
  Buf[0] := $e8; // CALL
  DW := pointer(@Buf[1]);
  DW^ := RelAddr;

  // Overwrite the current code with the new code to call the function
  FProcess.WriteInstructionCode(CurrentIP, 5, Buf[0]);

  // Store the address where the debugee should return at after the function
  // finished. It is used to determine if the call has been completed succesfully.
  FReturnAdress := CurrentIP + 5;
end;

procedure TDbgControllerCallRoutineCmd.DoContinue(AProcess: TDbgProcess; AThread: TDbgThread);
begin
  case FStep of
    sSingleStep: AProcess.Continue(AProcess, AThread, True);  // Single step into the function
    sRunRoutine: AProcess.Continue(AProcess, AThread, False); // Continue running the function
  end;
end;

procedure TDbgControllerCallRoutineCmd.DoResolveEvent(var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
var
  CurrentIP: TDBGPtr;
begin
  case FStep of
    sSingleStep: begin
      // The debugee is in the routine now. Restore the original code.
      // (Remove the code that made the debugee jump into this routine)
      RestoreOriginalCode;
      // Set a breakpoint at the return-adres, so the debugee stops when the
      // routine has been completed.
      if AnEvent=deBreakpoint then begin
        SetHiddenBreakpointAtReturnAddress(FReturnAdress);
        AnEvent := deInternalContinue;
        Finished := false;
        FStep := sRunRoutine;
      end else
        raise Exception.Create('Fatal debugger-result during function-call.');
    end;
    sRunRoutine: begin
      // Now the debugee has stopped while running the routine.

      if not (AnEvent in [deException, deBreakpoint]) then
        // Bail out. It can be anything, even deExitProcess. Maybe that handling
        // some events can be implemented somewhere in the future.
        raise Exception.Create('Fatal debugger-result during function-call.');

      CurrentIP := FController.CurrentThread.GetInstructionPointerRegisterValue;
      if CurrentIP<>FReturnAdress then
        begin
        // If we are not at the return-adres, the debugee has stopped due to some
        // unforeseen reason. Skip setting up the call-context, but assign an
        // error instead.
        if (AnEvent = deBreakpoint) then
          // Note that deBreakpoint does not necessarily mean that it it stopped
          // at an actual breakpoint.
          FCallContext.SetError('The function stopped unexpectedly. (Breakpoint, Exception, etc)')
        else
          begin
          // Clear any (pending) signals that were sent to the application during
          // the function-call.
          AnEventThread.ClearExceptionSignal;
          FCallContext.SetError('The function stopped due to an exception.')
          end;
        end
      else
        // We are at the return-adres. (Phew...)
        // Store the necessary data into the context to obtain the function-result
        // later
        StoreRoutineResult();

      //remove the hidden breakpoint.
      RemoveHiddenBreakpointAtReturnAddress;

      // Restore the debugee in the original state. So debugging can continue...
      RestoreInstructionPointer();
      RestoreRegisters();
      Finished := true;
    end
  else
    Finished := True;
  end;
end;

procedure TDbgControllerCallRoutineCmd.RestoreOriginalCode;
begin
  if not FProcess.WriteInstructionCode(FOriginalInstructionPointer, Length(FOriginalCode), FOriginalCode[0]) then
    raise Exception.Create('Failed to restore the original code at the instruction-pointer');
end;

procedure TDbgControllerCallRoutineCmd.SetHiddenBreakpointAtReturnAddress(AnAddress: TDBGPtr);
begin
  FHiddenBreakpoint := FProcess.AddInternalBreak(AnAddress);
end;

procedure TDbgControllerCallRoutineCmd.StoreInstructionPointer;
begin
  FOriginalInstructionPointer := FController.CurrentThread.GetInstructionPointerRegisterValue;
end;

procedure TDbgControllerCallRoutineCmd.RestoreInstructionPointer;
begin
  {$ifdef cpui386}
  FController.CurrentThread.SetRegisterValue('eip', FOriginalInstructionPointer);
  {$else}
  if FController.CurrentProcess.Mode <> dm64 then
    FController.CurrentThread.SetRegisterValue('eip', FOriginalInstructionPointer)
  else
    FController.CurrentThread.SetRegisterValue('rip', FOriginalInstructionPointer);
  {$endif}
end;

procedure TDbgControllerCallRoutineCmd.StoreRoutineResult;
begin
  FCallContext.SetRegisterValue(0, FController.CurrentThread.RegisterValueList.FindRegisterByDwarfIndex(0).NumValue);
end;

procedure TDbgControllerCallRoutineCmd.RestoreRegisters;
begin
  FController.CurrentThread.RestoreRegisters;
end;

procedure TDbgControllerCallRoutineCmd.RemoveHiddenBreakpointAtReturnAddress();
begin
  FHiddenBreakpoint.Free;
end;

procedure TDbgControllerCallRoutineCmd.StoreRegisters;
begin
  FController.CurrentThread.StoreRegisters;
end;

{ TDbgControllerCmd }

procedure TDbgControllerCmd.SetThread(AValue: TDbgThread);
begin
  if FThread = AValue then Exit;
  FThread := AValue;
  if AValue = nil then
    FThreadRemoved := True; // Only get here if FThread was <> nil;
end;

procedure TDbgControllerCmd.Init;
begin
  //
end;

constructor TDbgControllerCmd.Create(AController: TDbgController);
begin
  FController := AController;
  FProcess := FController.CurrentProcess;
  FThread := FController.CurrentThread;
end;

destructor TDbgControllerCmd.Destroy;
begin
  inherited Destroy;
  ReleaseRefAndNil(FNextInstruction);
end;

procedure TDbgControllerCmd.DoBeforeLoopStart;
begin
  if not FIsInitialized then
    Init;
  FIsInitialized := True;
end;

procedure TDbgControllerCmd.ResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
var
  dummy: TDbgThread;
begin
  ReleaseRefAndNil(FNextInstruction); // instruction from last pause
  Finished := FThreadRemoved;
  if Finished then
    exit;
  if AnEventThread = nil then
    exit;
  if FThread <> nil then begin
    // ResolveDebugEvent will have removed the thread, but not yet destroyed it
    // Finish, if the thread has gone.
    FThreadRemoved := (not FProcess.GetThread(FThread.ID, dummy)) or (FThread <> dummy);
    Finished := FThreadRemoved;
    if Finished then
      exit;
    // Only react to events for the correct thread. (Otherwise return Finished = False)
    if FThread <> AnEventThread then
      exit;
  end;
  DoResolveEvent(AnEvent, AnEventThread, Finished);
end;

function TDbgControllerCmd.NextInstruction: TDbgAsmInstruction;
begin
  if FNextInstruction = nil then begin
    FNextInstruction := FProcess.Disassembler.GetInstructionInfo(FThread.GetInstructionPointerRegisterValue);
    FNextInstruction.AddReference;
  end;
  Result := FNextInstruction;
end;

{ TDbgControllerContinueCmd }

procedure TDbgControllerContinueCmd.Init;
begin
  inherited Init;
  FThread := nil; // run until any thread has an event
end;

procedure TDbgControllerContinueCmd.DoContinue(AProcess: TDbgProcess; AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerContinueCmd.DoContinue: FProcess=AProcess');
  AProcess.Continue(AProcess, AThread, False);
end;

procedure TDbgControllerContinueCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
begin
  Finished := (AnEvent<>deInternalContinue); // TODO: always False? will be aborted, if another event terminates the ProcessLoop
end;

{ TDbgControllerStepIntoInstructionCmd }

procedure TDbgControllerStepIntoInstructionCmd.DoContinue(
  AProcess: TDbgProcess; AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerStepIntoInstructionCmd.DoContinue: FProcess=AProcess');
  FProcess.Continue(FProcess, FThread, True);
end;

procedure TDbgControllerStepIntoInstructionCmd.DoResolveEvent(
  var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
begin
  Finished := (AnEvent<>deInternalContinue);
  if Finished then
    AnEvent := deFinishedStep;
end;

{ TDbgControllerHiddenBreakStepBaseCmd }

function TDbgControllerHiddenBreakStepBaseCmd.GetIsSteppedOut: Boolean;
begin
  Result := (FStackFrameInfo <> nil) and FStackFrameInfo.HasSteppedOut;
end;

function TDbgControllerHiddenBreakStepBaseCmd.IsAtHiddenBreak: Boolean;
begin
  Result := (FHiddenBreakpoint <> nil) and
            (FThread.GetInstructionPointerRegisterValue = FHiddenBreakAddr) and // FHiddenBreakpoint.HasLocation()
            (FThread.GetStackPointerRegisterValue >= FHiddenBreakStackPtrAddr);
            // if SP > FStackPtrRegVal >> then the brk was hit stepped out (should not happen)
  debugln(FPDBG_COMMANDS and Result, ['BreakStepBaseCmd.IsAtHiddenBreak: At Hidden break = true']);
end;

function TDbgControllerHiddenBreakStepBaseCmd.HasHiddenBreak: Boolean;
begin
  Result := FHiddenBreakpoint <> nil;
end;

function TDbgControllerHiddenBreakStepBaseCmd.IsAtLastHiddenBreakAddr: Boolean;
begin
  Result := (FThread.GetInstructionPointerRegisterValue = FHiddenBreakAddr);
  debugln(FPDBG_COMMANDS and Result, ['BreakStepBaseCmd.IsAtLastHiddenBreakAddr : At LAST Hidden break ADDR = true']);
end;

function TDbgControllerHiddenBreakStepBaseCmd.IsAtOrOutOfHiddenBreakFrame: Boolean;
begin
  Result := HasHiddenBreak;
  if not Result then
    exit;
  if (FHiddenBreakInstrPtr = FThread.GetInstructionPointerRegisterValue) then
    Result := ((FHiddenBreakStackPtrAddr < FThread.GetStackPointerRegisterValue) or
               (FHiddenBreakFrameAddr < FThread.GetStackBasePointerRegisterValue))
  else
    // InstructPtr moved, so SP can be equal
    Result := ((FHiddenBreakStackPtrAddr <= FThread.GetStackPointerRegisterValue) or
               (FHiddenBreakFrameAddr < FThread.GetStackBasePointerRegisterValue));
  debugln(FPDBG_COMMANDS and Result and (FHiddenBreakpoint <> nil), ['BreakStepBaseCmd.IsAtOrOutOfHiddenBreakFrame: Gone past hidden break = true']);
end;

procedure TDbgControllerHiddenBreakStepBaseCmd.SetHiddenBreak(AnAddr: TDBGPtr);
begin
  // The callee may not setup a stackfram (StackBasePtr unchanged). So we use SP to detect recursive hits
  FHiddenBreakStackPtrAddr := FThread.GetStackPointerRegisterValue;
  FHiddenBreakFrameAddr := FThread.GetStackBasePointerRegisterValue;
  FHiddenBreakInstrPtr := FThread.GetInstructionPointerRegisterValue;
  FHiddenBreakAddr := AnAddr;
  FHiddenBreakpoint := FProcess.AddInternalBreak(AnAddr);
end;

procedure TDbgControllerHiddenBreakStepBaseCmd.RemoveHiddenBreak;
begin
  if assigned(FHiddenBreakpoint) then
    FreeAndNil(FHiddenBreakpoint);
end;

function TDbgControllerHiddenBreakStepBaseCmd.CheckForCallAndSetBreak: boolean;
begin
  Result := FHiddenBreakpoint = nil;
  if not Result then
    exit;
  Result := NextInstruction.IsCallInstruction;
  if Result then
    {$PUSH}{$Q-}{$R-}
    SetHiddenBreak(FThread.GetInstructionPointerRegisterValue + NextInstruction.InstructionLength);
    {$POP}
end;

procedure TDbgControllerHiddenBreakStepBaseCmd.InitStackFrameInfo;
begin
  FStackFrameInfo := FThread.GetCurrentStackFrameInfo;
end;

procedure TDbgControllerHiddenBreakStepBaseCmd.CallProcessContinue(
  ASingleStep: boolean; ASkipCheckNextInstr: Boolean);
begin
  if (FStackFrameInfo <> nil) and (not ASkipCheckNextInstr) then
    FStackFrameInfo.CheckNextInstruction(NextInstruction, ASingleStep);

  FProcess.Continue(FProcess, FThread, ASingleStep);
end;

destructor TDbgControllerHiddenBreakStepBaseCmd.Destroy;
begin
  RemoveHiddenBreak;
  FreeAndNil(FStackFrameInfo);
  inherited Destroy;
end;

procedure TDbgControllerHiddenBreakStepBaseCmd.DoContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  if (AThread <> FThread) then begin
    FProcess.Continue(FProcess, AThread, False);
    exit;
  end;

  InternalContinue(AProcess, AThread);
end;

{ TDbgControllerStepOverInstructionCmd }

procedure TDbgControllerStepOverInstructionCmd.InternalContinue(
  AProcess: TDbgProcess; AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerStepOverInstructionCmd.DoContinue: FProcess=AProcess');
  CheckForCallAndSetBreak;
  CallProcessContinue(FHiddenBreakpoint = nil);
end;

procedure TDbgControllerStepOverInstructionCmd.DoResolveEvent(
  var AnEvent: TFPDEvent; AnEventThread: TDbgThread; out Finished: boolean);
begin
  if FHiddenBreakpoint <> nil then
    Finished := IsAtOrOutOfHiddenBreakFrame
  else
    Finished := not (AnEvent in [deInternalContinue, deLoadLibrary]);
  if Finished then
  begin
    AnEvent := deFinishedStep;
    RemoveHiddenBreak;
  end
  else
  if AnEvent = deFinishedStep then
    AnEvent := deInternalContinue;
end;

{ TDbgControllerLineStepBaseCmd }

procedure TDbgControllerLineStepBaseCmd.Init;
begin
  InitStackFrameInfo;

  if FStoreStepInfoAtInit then begin
    FThread.StoreStepInfo;
    FStartedInFuncName := FThread.StoreStepFuncName;
  end;
  inherited Init;
end;

procedure TDbgControllerLineStepBaseCmd.UpdateThreadStepInfoAfterStepOut(
  ANextOnlyStopOnStartLine: Boolean);
begin
  if FStepInfoUpdatedForStepOut or not IsSteppedOut then
    exit;
  if not ANextOnlyStopOnStartLine then
    exit;

  FStepInfoUnavailAfterStepOut := not IsAtLastHiddenBreakAddr;
  if not FStepInfoUnavailAfterStepOut then begin
    {$PUSH}{$Q-}{$R-}
    FThread.StoreStepInfo(FThread.GetInstructionPointerRegisterValue +
      FThread.GetInstructionPointerRegisterValue - 1);
    {$POP}
  end;
  FStepInfoUpdatedForStepOut := True;
end;

function TDbgControllerLineStepBaseCmd.HasReachedEndLineForStep: boolean;
var
  CompRes: TFPDCompareStepInfo;
begin
  CompRes := FThread.CompareStepInfo;

  if CompRes in [dcsiSameLine, dcsiZeroLine] then begin
    DebugLn((DBG_VERBOSE or FPDBG_COMMANDS) and (CompRes=dcsiZeroLine), ['LineInfo with number=0']);
    Result := False;
    exit;
  end;

  if CompRes = dcsiNoLineInfo then begin
    // only get here, if the original did have line info, so no line info should not happen
    // check if the next asm is on the same line, otherwise treat as new line
    {$PUSH}{$Q-}{$R-}
    CompRes := FThread.CompareStepInfo(FThread.GetInstructionPointerRegisterValue +
      FThread.GetInstructionPointerRegisterValue - 1);
    {$POP}
    Result := not(CompRes in [dcsiNewLine, dcsiSameLine]); // Step once more, maybe we do a jmp....
    DebugLn(DBG_VERBOSE or FPDBG_COMMANDS, ['UNEXPECTED absence of debug info @',FThread.GetInstructionPointerRegisterValue,  ' Res:', Result]);
    exit;
  end;

  Result := True;
end;

function TDbgControllerLineStepBaseCmd.HasReachedEndLineOrSteppedOut(
  ANextOnlyStopOnStartLine: Boolean): boolean;
begin
  Result := IsSteppedOut;
  if Result then begin
    Result := (not ANextOnlyStopOnStartLine);
    if Result then
      exit;

    // If stepped out, do not step out again
    Result := NextInstruction.IsLeaveStackFrame or NextInstruction.IsReturnInstruction;
    if Result then
      exit;

    if FStepInfoUnavailAfterStepOut then begin
      Result := FController.FCurrentThread.IsAtStartOfLine;
      exit;
    end;
  end;

  Result := HasReachedEndLineForStep;
end;

procedure TDbgControllerLineStepBaseCmd.StoreWasAtJumpInstruction;
begin
  FWasAtJumpInstruction := NextInstruction.IsJumpInstruction;
end;

function TDbgControllerLineStepBaseCmd.IsAtJumpPad: Boolean;
begin
  Result := FWasAtJumpInstruction and
            NextInstruction.IsJumpInstruction(False) and
            not FController.FCurrentThread.IsAtStartOfLine; // TODO: check for lines with line=0
end;

constructor TDbgControllerLineStepBaseCmd.Create(AController: TDbgController;
  AStoreStepInfoAtInit: Boolean);
begin
  FStoreStepInfoAtInit := AStoreStepInfoAtInit;
  inherited Create(AController);
end;

procedure TDbgControllerLineStepBaseCmd.DoContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  if AThread = FThread then
    FWasAtJumpInstruction := False;
  inherited DoContinue(AProcess, AThread);
end;

{ TDbgControllerStepIntoLineCmd }

procedure TDbgControllerStepIntoLineCmd.InternalContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerStepIntoLineCmd.DoContinue: FProcess=AProcess');
  if (FState = siSteppingCurrent) then
  begin
    if CheckForCallAndSetBreak then begin
      FState := siSteppingIn;
      CallProcessContinue(true);
      exit;
    end;
  end;

  if (FState <> siRunningStepOut) then
    StoreWasAtJumpInstruction;
  CallProcessContinue(FState <> siRunningStepOut, FState = siSteppingNested);
end;

constructor TDbgControllerStepIntoLineCmd.Create(AController: TDbgController);
begin
  inherited Create(AController, True);
end;

procedure TDbgControllerStepIntoLineCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
var
  CompRes: TFPDCompareStepInfo;
begin
  UpdateThreadStepInfoAfterStepOut(True);

  if IsAtOrOutOfHiddenBreakFrame then begin
    RemoveHiddenBreak;
    FState := siSteppingCurrent;
  end;
  assert((FHiddenBreakpoint<>nil) xor (FState=siSteppingCurrent), 'TDbgControllerStepIntoLineCmd.DoResolveEvent: (FHiddenBreakpoint<>nil) xor (FState=siSteppingCurrent)');

  if (FState = siSteppingCurrent) then begin
    Finished := HasReachedEndLineOrSteppedOut(True);
    if Finished then
      Finished := not IsAtJumpPad;
  end
  else begin
    // we stepped into
    CompRes := FThread.CompareStepInfo;
    Finished := CompRes = dcsiNewLine;
  end;

  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent in [deFinishedStep] then
    AnEvent:=deInternalContinue;

  If (FState = siSteppingCurrent) or Finished then
    exit;

  // Currently stepped into some method
  assert(FHiddenBreakpoint <> nil, 'TDbgControllerStepIntoLineCmd.DoResolveEvent: Stepping: FHiddenBreakpoint <> nil');

  if FState = siSteppingIn then begin
    FState := siSteppingNested;
    FStepCount := 0;
    FNestDepth := 0;
  end;

  inc(FStepCount);
  if NextInstruction.IsCallInstruction then
    inc(FNestDepth);

  // FNestDepth = 2  => About to step into 3rd level nested
  if (FStepCount > 5) or (FNestDepth > 1) then begin
    FState := siRunningStepOut; // run to breakpoint
    exit;
  end;
  // Just step and see if we find line info
end;

{ TDbgControllerStepOverLineCmd }

procedure TDbgControllerStepOverLineCmd.InternalContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerStepOverLineCmd.DoContinue: FProcess=AProcess');
  CheckForCallAndSetBreak;

  if FHiddenBreakpoint = nil then
    StoreWasAtJumpInstruction;
  CallProcessContinue(FHiddenBreakpoint = nil);
end;

constructor TDbgControllerStepOverLineCmd.Create(AController: TDbgController);
begin
  inherited Create(AController, True);
end;

procedure TDbgControllerStepOverLineCmd.Init;
begin
  FThread.StoreStepInfo;
  inherited Init;
end;

procedure TDbgControllerStepOverLineCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
begin
  UpdateThreadStepInfoAfterStepOut(True);
  if IsAtOrOutOfHiddenBreakFrame then
      RemoveHiddenBreak;

  if FHiddenBreakpoint <> nil then begin
    Finished := False;
  end
  else begin
    Finished := HasReachedEndLineOrSteppedOut(True);
    if Finished then
      Finished := not IsAtJumpPad;
  end;

  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent in [deFinishedStep] then
    AnEvent:=deInternalContinue;
end;

{ TDbgControllerStepOutCmd }

function TDbgControllerStepOutCmd.GetOutsideFrame(var AnOutside: Boolean
  ): Boolean;
begin
  Result := FProcess.Disassembler.GetFunctionFrameInfo(FThread.GetInstructionPointerRegisterValue, AnOutside);
end;

procedure TDbgControllerStepOutCmd.SetReturnAdressBreakpoint(
  AProcess: TDbgProcess; AnOutsideFrame: Boolean);
var
  AStackPointerValue, StepOutStackPos, ReturnAddress: TDBGPtr;
begin
  FWasOutsideFrame := AnOutsideFrame;
  {$PUSH}{$Q-}{$R-}
  if AnOutsideFrame then begin
    StepOutStackPos:=FController.CurrentThread.GetStackPointerRegisterValue;
  end
  else begin
    AStackPointerValue:=FController.CurrentThread.GetStackBasePointerRegisterValue;
    StepOutStackPos:=AStackPointerValue+DBGPTRSIZE[FController.FCurrentProcess.Mode];
  end;
  {$POP}
    debugln(FPDBG_COMMANDS, ['StepOutCmd.SetReturnAdressBreakpoint NoFrame=',AnOutsideFrame,  ' ^RetIP=',dbghex(StepOutStackPos),' SP=',dbghex(FController.CurrentThread.GetStackPointerRegisterValue),' BP=',dbghex(FController.CurrentThread.GetStackBasePointerRegisterValue)]);

  if AProcess.ReadAddress(StepOutStackPos, ReturnAddress) then
    SetHiddenBreak(ReturnAddress)
  else
    debugln(DBG_WARNINGS or FPDBG_COMMANDS, ['Failed to read return-address from stack', ReturnAddress]);
end;

procedure TDbgControllerStepOutCmd.InternalContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
var
  Outside: Boolean;
begin
  assert(FProcess=AProcess, 'TDbgControllerStepOutCmd.DoContinue: FProcess=AProcess');

  if (AThread = FThread) then begin
  if IsSteppedOut then begin
    CheckForCallAndSetBreak;
  end
  else
  if not assigned(FHiddenBreakpoint) then begin
    if GetOutsideFrame(Outside) then begin
      SetReturnAdressBreakpoint(AProcess, Outside);
    end
    else
    if FStepCount < 12 then
    begin
      // During the prologue and epiloge of a procedure the call-stack might not been
      // setup already. To avoid problems in these cases, start with a few (max
      // 12) single steps.
      Inc(FStepCount);
      if NextInstruction.IsCallInstruction or NextInstruction.IsLeaveStackFrame then  // asm "call" // set break before "leave" or the frame becomes unavail
      begin
        SetReturnAdressBreakpoint(AProcess, False);
      end
      else
      if NextInstruction.IsReturnInstruction then  // asm "ret"
      begin
        FStepCount := MaxInt; // Do one more single-step, and we're finished.
        CallProcessContinue(True);
        exit;
      end;
    end
    else
    begin
      // Enough with the single-stepping
      SetReturnAdressBreakpoint(AProcess, False);
    end;
  end;
  end;

  CallProcessContinue(FHiddenBreakpoint = nil);
end;

procedure TDbgControllerStepOutCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
begin
  Finished := False;

  // If we stepped out, without a frame, then IsSteppedOut will not detect it
  // The Stack will be popped for the return address.
  if FWasOutsideFrame and (not IsSteppedOut) and
     (FHiddenBreakStackPtrAddr < FThread.GetStackPointerRegisterValue)
  then
    FStackFrameInfo.FlagAsSteppedOut;

  if IsSteppedOut or IsAtHiddenBreak then begin
    UpdateThreadStepInfoAfterStepOut(FController.NextOnlyStopOnStartLine);

    if IsAtOrOutOfHiddenBreakFrame then
        RemoveHiddenBreak;

    if FHiddenBreakpoint <> nil then
      Finished := False
    else
      Finished := HasReachedEndLineOrSteppedOut(FController.NextOnlyStopOnStartLine);
  end;

  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent in [deFinishedStep] then
    AnEvent:=deInternalContinue;
end;

{ TDbgControllerRunToCmd }

constructor TDbgControllerRunToCmd.Create(AController: TDbgController; ALocation: TDBGPtrArray);
begin
  FLocation:=ALocation;
  inherited create(AController);
end;

procedure TDbgControllerRunToCmd.InternalContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerRunToCmd.DoContinue: FProcess=AProcess');
  CallProcessContinue(False);
end;

procedure TDbgControllerRunToCmd.Init;
begin
  inherited Init;
  FHiddenBreakpoint := FProcess.AddInternalBreak(FLocation);
end;

procedure TDbgControllerRunToCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
begin
  Finished := (FHiddenBreakpoint = nil) or FHiddenBreakpoint.HasLocation(FThread.GetInstructionPointerRegisterValue);
  if Finished then begin
    RemoveHiddenBreak;
    AnEvent := deFinishedStep;
  end;
end;

{ TDbgControllerStepToCmd }

procedure TDbgControllerStepToCmd.Init;
var
  r: TDBGPtrArray;
begin
//  FThread.StoreStepInfo;
  FTargetExists := FProcess.DbgInfo.GetLineAddresses(FTargetFilename, FTargetLineNumber, r);
  FTargetExists := FTargetExists and (Length(r) > 0);
  FStepInfoUnavailAfterStepOut := True; // always check for IsAtStartOfLine
  inherited Init;
end;

function TDbgControllerStepToCmd.HasReachedEndLineForStep: boolean;
var
  AnAddr: TDBGPtr;
  sym: TFpSymbol;
begin
  Result := False;
  AnAddr := FThread.GetInstructionPointerRegisterValue;
  if (AnAddr >= FStoreStepStartAddr) and (AnAddr < FStoreStepEndAddr) then
    exit;

  sym := FProcess.FindProcSymbol(AnAddr);
  if not assigned(sym) then
    exit;

  if sym is TFpSymbolDwarfDataProc then begin
    FStoreStepStartAddr := TFpSymbolDwarfDataProc(sym).LineStartAddress;
    FStoreStepEndAddr := TFpSymbolDwarfDataProc(sym).LineEndAddress;
  end
  else begin
    FStoreStepStartAddr := AnAddr;
    FStoreStepEndAddr := AnAddr;
  end;

  Result := (sym.Line = FTargetLineNumber) and (ExtractFileName(sym.FileName) = FTargetFilename);

  sym.ReleaseReference;
end;

procedure TDbgControllerStepToCmd.DoResolveEvent(var AnEvent: TFPDEvent;
  AnEventThread: TDbgThread; out Finished: boolean);
begin
//  UpdateThreadStepInfoAfterStepOut(True);
  if IsAtOrOutOfHiddenBreakFrame then
      RemoveHiddenBreak;

  if not FTargetExists then begin
    Finished := True; // should not even have been started
  end
  else
  if FHiddenBreakpoint <> nil then begin
    Finished := False;
  end
  else begin
    Finished := HasReachedEndLineOrSteppedOut(True);
    //if Finished then
    //  Finished := not IsAtJumpPad;
  end;

  if Finished then
    AnEvent := deFinishedStep
  else
  if AnEvent in [deFinishedStep] then
    AnEvent:=deInternalContinue;
end;

procedure TDbgControllerStepToCmd.InternalContinue(AProcess: TDbgProcess;
  AThread: TDbgThread);
begin
  assert(FProcess=AProcess, 'TDbgControllerStepToCmd.DoContinue: FProcess=AProcess');
  CheckForCallAndSetBreak;

  if FHiddenBreakpoint = nil then
    StoreWasAtJumpInstruction;
  CallProcessContinue(FHiddenBreakpoint = nil);
end;

constructor TDbgControllerStepToCmd.Create(AController: TDbgController;
  const ATargetFilename: String; ATargetLineNumber: Integer);
begin
  FTargetFilename   := ExtractFileName(ATargetFilename);
  FTargetLineNumber := ATargetLineNumber;
  inherited Create(AController, False);
end;


{ TDbgController }

procedure TDbgController.DoOnDebugInfoLoaded(Sender: TObject);
begin
  if Assigned(FOnDebugInfoLoaded) then
    FOnDebugInfoLoaded(Self);
end;

procedure TDbgController.SetParams(AValue: TStringList);
begin
  if FParams=AValue then Exit;
  FParams.Assign(AValue);
end;

procedure TDbgController.CheckExecutableAndLoadClasses;
var
  source: TDbgFileLoader;
  imgReader: TDbgImageReader;
  ATargetInfo: TTargetDescriptor;
begin
  if (FExecutableFilename <> '') and FileExists(FExecutableFilename) then
  begin
    DebugLn(DBG_VERBOSE, 'TDbgController.CheckExecutableAndLoadClasses');
    source := nil;
    imgReader := nil;
    try
      source := TDbgFileLoader.Create(FExecutableFilename);
      imgReader := GetImageReader(source, nil, false);

      ATargetInfo := imgReader.TargetInfo;
    finally
      FreeAndNil(imgReader);  // TODO: Store object reference, it will be needed again
      FreeAndNil(source);
    end;
  end
  else
    ATargetInfo := hostDescriptor;

  FOsDbgClasses := FpDbgClasses.GetDbgProcessClass(ATargetInfo);
end;

procedure TDbgController.SetExecutableFilename(const AValue: string);
begin
  if FExecutableFilename=AValue then Exit;
  FExecutableFilename:=AValue;
end;

procedure TDbgController.SetEnvironment(AValue: TStrings);
begin
  if FEnvironment=AValue then Exit;
  FEnvironment.Assign(AValue);
end;

function TDbgController.GetCurrentThreadId: Integer;
begin
  Result := FCurrentThread.ID;
end;

function TDbgController.GetDefaultContext: TFpDbgLocationContext;
begin
  if FDefaultContext = nil then begin
    FDefaultContext := TFpDbgSimpleLocationContext.Create(MemManager,
      FCurrentThread.GetInstructionPointerRegisterValue,
      DBGPTRSIZE[CurrentProcess.Mode],
      CurrentThread.ID,
      0
      );
  end;
  Result := FDefaultContext;
end;

procedure TDbgController.SetCurrentThreadId(AValue: Integer);
var
  ExistingThread: TDbgThread;
begin
  if FCurrentThread.ID = AValue then Exit;

  if not FCurrentProcess.GetThread(AValue, ExistingThread) then begin
    debugln(DBG_WARNINGS, ['SetCurrentThread() unknown thread id: ', AValue]);
    // raise ...
    exit;
  end;
  FCurrentThread := ExistingThread;
end;

destructor TDbgController.Destroy;
var
  it: TMapIterator;
  p: TDbgProcess;
begin
  ReleaseRefAndNil(FDefaultContext);

  if FCommand <> nil then begin
    FCommand.FProcess := nil;
    FCommand.FThread := nil;
    FCommand.Free;
  end;
  if FCommandToBeFreed <> nil then begin
    FCommandToBeFreed.FProcess := nil;
    FCommandToBeFreed.FThread := nil;
    FCommandToBeFreed.Free;
  end;

  if Assigned(FMainProcess) then begin
    FProcessMap.Delete(FMainProcess.ProcessID);
    FMainProcess.Free;
  end;

  it := TMapIterator.Create(FProcessMap);
  while not it.EOM do begin
    it.GetData(p);
    p.Free;
    it.Next;
  end;
  it.Free;
  FProcessMap.Free;

  FParams.Free;
  FEnvironment.Free;
  inherited Destroy;
end;

procedure TDbgController.AbortCurrentCommand;
begin
  if FCommand = nil then
    exit;
  assert(FCommandToBeFreed=nil, 'TDbgController.AbortCurrentCommand: FCommandToBeFreed=nil');
  FCommandToBeFreed := FCommand;
  FCommand := nil;
end;

procedure TDbgController.InitializeCommand(ACommand: TDbgControllerCmd);
begin
  if assigned(FCommand) then
    raise exception.create('Prior command not finished yet.');
  DebugLn(FPDBG_COMMANDS, 'Initialized command '+ACommand.ClassName);
  FCommand := ACommand;
end;

function TDbgController.Run: boolean;
var
  Flags: TStartInstanceFlags;
begin
  result := False;
  FLastError := NoError;
  if assigned(FMainProcess) then
    begin
    DebugLn(DBG_WARNINGS, 'The debuggee is already running');
    Exit;
    end;

  if FExecutableFilename = '' then
    begin
    DebugLn(DBG_WARNINGS, 'No filename given to execute.');
    Exit;
    end;

  if not FileExists(FExecutableFilename) then
    begin
    DebugLn(DBG_WARNINGS, 'File %s does not exist.',[FExecutableFilename]);
    Exit;
    end;

  // Get exe info, load classes
  CheckExecutableAndLoadClasses;
  if not Assigned(OsDbgClasses) then
  begin
    result := false;
    DebugLn(DBG_WARNINGS, 'Error - No support registered for debug target');
    exit;
  end;

  Flags := [];
  if RedirectConsoleOutput then Include(Flags, siRediretOutput);
  if ForceNewConsoleWin then Include(Flags, siForceNewConsole);
  if AttachToPid <> 0 then
    FCurrentProcess := OSDbgClasses.DbgProcessClass.AttachToInstance(FExecutableFilename, AttachToPid, OsDbgClasses, MemManager, FLastError)
  else
    FCurrentProcess := OSDbgClasses.DbgProcessClass.StartInstance(FExecutableFilename, Params, Environment, WorkingDirectory, FConsoleTty, Flags, OsDbgClasses, MemManager, FLastError);
  if assigned(FCurrentProcess) then
    begin
    FProcessMap.Add(FCurrentProcess.ProcessID, FCurrentProcess);
    DebugLn(DBG_VERBOSE, 'Got PID: %d, TID: %d', [FCurrentProcess.ProcessID, FCurrentProcess.ThreadID]);
    result := true;
    end;
end;

procedure TDbgController.Stop;
begin
  if assigned(FMainProcess) then
    FMainProcess.TerminateProcess
  else
    raise Exception.Create('Failed to stop debugging. No main process.');
end;

procedure TDbgController.StepIntoInstr;
begin
  InitializeCommand(TDbgControllerStepIntoInstructionCmd.Create(self));
end;

procedure TDbgController.StepOverInstr;
begin
  InitializeCommand(TDbgControllerStepOverInstructionCmd.Create(self));
end;

procedure TDbgController.Next;
begin
  InitializeCommand(TDbgControllerStepOverLineCmd.Create(self));
end;

procedure TDbgController.Step;
begin
  InitializeCommand(TDbgControllerStepIntoLineCmd.Create(self));
end;

procedure TDbgController.StepOut(AForceStoreStepInfo: Boolean);
begin
  InitializeCommand(TDbgControllerStepOutCmd.Create(self, AForceStoreStepInfo));
end;

function TDbgController.Pause: boolean;
begin
  InterLockedExchange(FPauseRequest, 1);
  Result := InterLockedExchangeAdd(FRunning, 0) = 0; // not running
  if not Result then
    Result := FCurrentProcess.Pause;
end;

function TDbgController.Detach: boolean;
begin
  InterLockedExchange(FDetaching, 1);
  Result := Pause;
end;

procedure TDbgController.ProcessLoop;

  function MaybeDetach: boolean;
  begin
    Result := InterLockedExchange(FDetaching, 0) <> 0;
    if not Result then
      exit;

    if Assigned(FCommand) then
      FreeAndNil(FCommand);
    FPDEvent := deFinishedStep; // go to pause, if detach fails
    if FCurrentProcess.Detach(FCurrentProcess, FCurrentThread) then
      FPDEvent := deExitProcess;
  end;
var
  AProcessIdentifier: THandle;
  AThreadIdentifier: THandle;
  AExit: boolean;
  IsFinished, b: boolean;
  EventProcess: TDbgProcess;
  DummyThread: TDbgThread;
  CurCmd: TDbgControllerCmd;

begin
  AExit:=false;
  if FCurrentProcess = nil then begin
    DebugLn(DBG_WARNINGS, 'Error: Processloop has no process');
    exit;
  end;

  FreeAndNil(FCommandToBeFreed);
  if FCommand <> nil then
    FCommand.DoBeforeLoopStart;

  if MaybeDetach then
    exit;

  FCurrentProcess.ThreadsClearCallStack;

  if Assigned(FOnThreadBeforeProcessLoop) then
    FOnThreadBeforeProcessLoop(Self);

  repeat
    ReleaseRefAndNil(FDefaultContext);
    if assigned(FCurrentProcess) and not assigned(FMainProcess) then begin
      // IF there is a pause-request, we will hit a deCreateProcess.
      // No need to indicate FRunning
      FMainProcess:=FCurrentProcess;
    end
    else
    begin
      InterLockedExchange(FRunning, 1);
      // if Pause() is called right here, an Interrupt-Event is scheduled, even though we do not run (yet)
      if InterLockedExchangeAdd(FPauseRequest, 0) = 1 then begin
        FPDEvent := deBreakpoint;
        InterLockedExchange(FRunning, 0);
        break; // no event handling. Keep Process/Thread from last run
      end
      else begin
        if not assigned(FCommand) then
          begin
          DebugLnEnter(FPDBG_COMMANDS, 'Continue process without command.');
          FCurrentProcess.Continue(FCurrentProcess, FCurrentThread, False)
          end
        else
          begin
          DebugLnEnter(FPDBG_COMMANDS, 'Continue process with command '+FCommand.ClassName);
          FCommand.DoContinue(FCurrentProcess, FCurrentThread);
          end;

        // TODO: replace the dangling pointer with the next best value....
        // There is still a race condition, for another thread to access it...
        if (FCurrentThread <> nil) and not FCurrentProcess.GetThread(FCurrentThread.ID, DummyThread) then begin
          if (FCommand <> nil) and (FCommand.FThread = FCurrentThread) then
            FCommand.Thread := nil;
          FreeAndNil(FCurrentThread);
        end;
        DebugLnExit(FPDBG_COMMANDS);
      end;
    end;
    if not FCurrentProcess.WaitForDebugEvent(AProcessIdentifier, AThreadIdentifier) then
      Continue;
    InterLockedExchange(FRunning, 0);

    (* Do not change CurrentProcess/Thread,
       unless the debugger can actually controll/debug those processes
       - If FCurrentProcess is not set to FMainProcess then Pause will fail
          (because a process that is not debugged, can not be paused,
           and if it were debugged, *all* debugged processes may need to be paused)
       - The LazFpDebugger may try to access FCurrentThread. If that is nil, it may crash.
         e.g. TFPThreads.RequestMasterData

       This may need 3 threads: main, user-selected (thread win), current-event

       deExitProcess relies on only the main process receiving this.

    *)
    //FCurrentProcess := nil;
    //FCurrentThread := nil;
    EventProcess := nil;
//    if not GetProcess(AProcessIdentifier, FCurrentProcess) then
    if not GetProcess(AProcessIdentifier, EventProcess) then
      begin
      // A second/third etc process has been started.
      (* A process was created/forked
         However the debugger currently does not attach to it on all platforms
           so maybe other processes should be ignored?
           It seems on windows/linux it does NOT attach.
           On Mac, it may attempt to attach.
         If the process is not debugged, it may not receive an deExitProcess
      *)
      (* As above, currently do not change those variables,
         just continue the process-loop (as "FCurrentProcess<>FMainProcess" would do)
      *)
      //FCurrentProcess := OSDbgClasses.DbgProcessClass.Create('', AProcessIdentifier, AThreadIdentifier, OnLog);
      //FProcessMap.Add(AProcessIdentifier, FCurrentProcess);

      Continue; // ***** This will swallow all FPDEvent for unknow processes *****
      end;

    if EventProcess<>FMainProcess then
    //if FCurrentProcess<>FMainProcess then
      // Just continue the process. Only the main-process is being debugged.
      Continue;

    if not FCurrentProcess.GetThread(AThreadIdentifier, FCurrentThread) then
      FCurrentThread := FCurrentProcess.AddThread(AThreadIdentifier);

    (* TODO: ExitThread **********
       at least the winprocess handles exitthread in the next line.
       this will remove CurrentThread form the list of threads
       CurrentThread is then destroyed in the next call to continue....
    *)

    FPDEvent:=FCurrentProcess.ResolveDebugEvent(FCurrentThread);
    if FCurrentThread <> nil then DebugLn(DBG_VERBOSE, 'Process stopped with event %s. IP=%s, SP=%s, BSP=%s. HasBreak: %s',
                         [FPDEventNames[FPDEvent],
                         FCurrentProcess.FormatAddress(FCurrentThread.GetInstructionPointerRegisterValue),
                         FCurrentProcess.FormatAddress(FCurrentThread.GetStackPointerRegisterValue),
                         FCurrentProcess.FormatAddress(FCurrentThread.GetStackBasePointerRegisterValue),
                         dbgs(CurrentProcess.CurrentBreakpoint<>nil)]);

    if MaybeDetach then
      break;

    IsFinished:=false;
    if FPDEvent=deExitProcess then begin
      FreeAndNil(FCommand);
      if assigned(FOnThreadProcessLoopCycleEvent) then begin
        FOnThreadProcessLoopCycleEvent(AExit, FPDEvent, CurCmd, IsFinished);
        FPDEvent := deExitProcess;
      end;
      break;
    end
    else
    if assigned(FCommand) then
    begin
      FCommand.ResolveEvent(FPDEvent, FCurrentThread, IsFinished);
      DebugLn(FPDBG_COMMANDS, 'Command %s: IsFinished=%s', [FCommand.ClassName, dbgs(IsFinished)])
    end;

    AExit:=true;
    if not IsFinished then
    begin
     case FPDEvent of
       deInternalContinue: AExit := False;
       deBreakpoint: begin
           b := FCurrentProcess.GetAndClearPauseRequested;
           AExit := (FCurrentProcess.CurrentBreakpoint <> nil) or
                    ( (FCurrentProcess.CurrentWatchpoint <> nil) and (FCurrentProcess.CurrentWatchpoint <> Pointer(-1)) ) or
                    ( (FCurrentThread <> nil) and FCurrentThread.PausedAtHardcodeBreakPoint) or
                    (b and (InterLockedExchangeAdd(FPauseRequest, 0) = 1));
         end;
{        deLoadLibrary :
          begin
            if FCurrentProcess.GetLib(FCurrentProcess.LastEventProcessIdentifier, ALib)
            and (GImageInfo <> iiNone)
            then begin
              WriteLN('Name: ', ALib.Name);
              //if GImageInfo = iiDetail
              //then DumpPEImage(Proc.Handle, Lib.BaseAddr);
            end;
            if GBreakOnLibraryLoad
            then GState := dsPause;

          end; }
      end; {case}
    end;

    if assigned(FOnThreadProcessLoopCycleEvent) then begin
      CurCmd := FCommand;
      FOnThreadProcessLoopCycleEvent(AExit, FPDEvent, CurCmd, IsFinished);
      if CurCmd = FCommand then begin
        if IsFinished then
          FreeAndNil(FCommand);
      end
      else begin
        FreeAndNil(FCommand);
        FCommand := CurCmd;
        if FCommand <> nil then
          FCommand.DoBeforeLoopStart;
      end;
    end
    else
    if IsFinished then
      FreeAndNil(FCommand);

  until AExit or (InterLockedExchangeAdd(FPauseRequest, 0) = 1);
end;

procedure TDbgController.SendEvents(out continue: boolean);
var
  HasPauseRequest: Boolean;
  CurWatch: TFpInternalWatchpoint;
begin
  // reset pause request. If Pause() is called after this, it will be seen in the next loop
  HasPauseRequest := InterLockedExchange(FPauseRequest, 0) = 1;
  CurWatch := nil;
  if (FCurrentProcess.CurrentWatchpoint <> nil) and (FCurrentProcess.CurrentWatchpoint <> Pointer(-1)) then
    CurWatch := TFpInternalWatchpoint(FCurrentProcess.CurrentWatchpoint);

  case FPDEvent of
    deCreateProcess:
      begin
        (* Only events for the main process get here / See ProcessLoop *)
        if not Assigned(FCurrentProcess.DbgInfo) then
          FCurrentProcess.LoadInfo;

        DebugLn(DBG_WARNINGS and (not Assigned(FCurrentProcess.DbgInfo) or not(FCurrentProcess.DbgInfo.HasInfo)),
          ['TDbgController.SendEvents called - deCreateProcess - No debug info. [CurrentProcess=',dbgsname(FCurrentProcess),',DbgInfo=',dbgsname(FCurrentProcess.DbgInfo),']']);
        DebugLn(DBG_VERBOSE, Format('  Target.MachineType = %d', [FCurrentProcess.DbgInfo.TargetInfo.machineType]));
        DebugLn(DBG_VERBOSE, Format('  Target.Bitness     = %d', [FCurrentProcess.DbgInfo.TargetInfo.bitness]));
        DebugLn(DBG_VERBOSE, Format('  Target.byteOrder   = %d', [FCurrentProcess.DbgInfo.TargetInfo.byteOrder]));
        DebugLn(DBG_VERBOSE, Format('  Target.OS          = %d', [FCurrentProcess.DbgInfo.TargetInfo.OS]));

        DoOnDebugInfoLoaded(self);

        continue:=true;
        if assigned(OnCreateProcessEvent) then
          OnCreateProcessEvent(continue);
      end;
    deFinishedStep:
      begin
        if assigned(OnHitBreakpointEvent) then begin
          // if there is a breakpoint at the stepping end, execute its actions
          continue:=false;
          if (CurWatch <> nil) then
            OnHitBreakpointEvent(continue, CurWatch, deFinishedStep, True);

          continue:=false;
          if assigned(FCurrentProcess.CurrentBreakpoint) then
            OnHitBreakpointEvent(continue, FCurrentProcess.CurrentBreakpoint, deFinishedStep, True);

          continue:=false;
          OnHitBreakpointEvent(continue, nil, deFinishedStep, False);
          HasPauseRequest := False;
        end;
        continue:=false;
      end;
    deBreakpoint, deHardCodedBreakpoint:
      begin
        // If there is no breakpoint AND no pause-request then this is a deferred, allready handled pause request
        if assigned(OnHitBreakpointEvent) and (
          // If no break event of any kind is hit, then pause will be called further down. Keep HasPauseRequest=True
          ((FCurrentThread <> nil) and (FCurrentThread.PausedAtHardcodeBreakPoint)) or
          (CurWatch <> nil) or
          (FCurrentProcess.CurrentBreakpoint <> nil)
        )
        then begin
          continue := False;
          if (FCurrentThread <> nil) and (FCurrentThread.PausedAtHardcodeBreakPoint) then
            OnHitBreakpointEvent(continue, nil, deHardCodedBreakpoint, (CurWatch <> nil) or (FCurrentProcess.CurrentBreakpoint <> nil));

          if (CurWatch <> nil) then
            OnHitBreakpointEvent(continue, CurWatch, deBreakpoint, (FCurrentProcess.CurrentBreakpoint <> nil));

          if assigned(FCurrentProcess.CurrentBreakpoint) then
            OnHitBreakpointEvent(continue, FCurrentProcess.CurrentBreakpoint, deBreakpoint, False);

          if not continue then
            HasPauseRequest := False; // The debugger will enter Pause, so the internal-pause is handled.
        end;
      end;
    deExitProcess:
      begin
      (* Only events for the main process get here / See ProcessLoop *)
        if FCurrentProcess = FMainProcess then FMainProcess := nil;
        FCurrentProcess.GotExitProcess := True;

        if assigned(OnProcessExitEvent) then
          OnProcessExitEvent(FCurrentProcess.ExitCode);

        FProcessMap.Delete(FCurrentProcess.ProcessID);
        FCurrentProcess.Free;
        FCurrentProcess := nil;
        HasPauseRequest := False;
        continue := false;
      end;
    deException:
      begin
        continue:=false;
        if assigned(OnExceptionEvent) then
          OnExceptionEvent(continue, FCurrentProcess.ExceptionClass, FCurrentProcess.ExceptionMessage );
        if not continue then
          HasPauseRequest := False;
      end;
    deLoadLibrary:
      begin
        continue:=true;
        if assigned(OnLibraryLoadedEvent) and Assigned(FCurrentProcess.LastLibraryLoaded) then
          OnLibraryLoadedEvent(continue, FCurrentProcess.LastLibraryLoaded);
      end;
    deUnloadLibrary:
      begin
        continue:=true;
        if assigned(OnLibraryUnloadedEvent) and Assigned(FCurrentProcess.LastLibraryUnloaded) then
          OnLibraryUnloadedEvent(continue, FCurrentProcess.LastLibraryUnloaded);
        FCurrentProcess.LastLibraryUnloaded := nil;
      end;
    deInternalContinue:
      begin
        continue := true;
      end;
    else
      raise exception.create('Unknown debug controler state');
  end;
  if HasPauseRequest then begin
    continue := False;
    if assigned(OnHitBreakpointEvent) then
      OnHitBreakpointEvent(continue, nil, deInternalContinue, False);
  end;

  if (not &continue) and (FCommand <> nil) then begin
    assert(FCommandToBeFreed=nil, 'TDbgController.SendEvents: FCommandToBeFreed=nil');
    FCommandToBeFreed := FCommand;
    FCommand := nil;
  end;
end;

function TDbgController.GetProcess(const AProcessIdentifier: THandle; out AProcess: TDbgProcess): Boolean;
begin
  Result := FProcessMap.GetData(AProcessIdentifier, AProcess) and (AProcess <> nil);
end;

constructor TDbgController.Create(AMemManager: TFpDbgMemManager);
begin
  FMemManager := AMemManager;
  FParams := TStringList.Create;
  FEnvironment := TStringList.Create;
  FProcessMap := TMap.Create(itu4, SizeOf(TDbgProcess));
  FNextOnlyStopOnStartLine := true;
end;

function TDbgController.Call(const FunctionAddress: TFpDbgMemLocation;
  const ABaseContext: TFpDbgLocationContext;
  const AMemReader: TFpDbgMemReaderBase; const AMemConverter: TFpDbgMemConvertor
  ): TFpDbgInfoCallContext;
var
  Context: TFpDbgInfoCallContext;
begin
  Context := TFpDbgInfoCallContext.Create(ABaseContext, AMemReader, AMemConverter);
  Context.AddReference;
  InitializeCommand(TDbgControllerCallRoutineCmd.Create(self, FunctionAddress, Context));
  Result := Context;
end;

initialization
  DBG_VERBOSE := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
  FPDBG_COMMANDS := DebugLogger.FindOrRegisterLogGroup('FPDBG_COMMANDS' {$IFDEF FPDBG_COMMANDS} , True {$ENDIF} );

end.


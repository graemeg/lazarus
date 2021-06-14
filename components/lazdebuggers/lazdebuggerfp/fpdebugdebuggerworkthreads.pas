{
 ---------------------------------------------------------------------------
 FpDebugDebuggerWorkThreads
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

unit FpDebugDebuggerWorkThreads;

(*
  This unit contains the classes for executing work in the worker thread:
  - The general structure of the classes
  - The code that is to be executed in the worker thread
      procedure DoExecute;

  - The classes are extended in the main FpDebugDebugger unit with any code
    running in the main debugger thread.

  This split accross the units should help with identifying what may be accessed
  in the worker thread.
*)

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}
{$ModeSwitch advancedrecords}

interface

uses
  FpDebugDebuggerUtils, DbgIntfDebuggerBase, DbgIntfBaseTypes, FpDbgClasses,
  FpDbgUtil, FPDbgController, FpPascalBuilder, FpdMemoryTools, FpDbgInfo,
  FpPascalParser, FpErrorMessages, FpDbgCallContextInfo, FpDbgDwarf,
  FpDbgDwarfDataClasses, Forms, fgl, math, Classes, sysutils, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif};

type

  TFpDbgAsyncMethod = procedure() of object;

  TFpDebugDebuggerBase = class(TDebuggerIntf)
  protected
    FDbgController: TDbgController;
    FMemManager: TFpDbgMemManager;
    FMemReader: TDbgMemReader;
    FMemConverter: TFpDbgMemConvertorLittleEndian;
    FLockList: TFpDbgLockList;
    FWorkQueue: TFpThreadPriorityWorkerQueue;
  end;

  { TFpDbgDebggerThreadWorkerItem }

  TFpDbgDebggerThreadWorkerItem = class(TFpThreadPriorityWorkerItem)
  protected type
    THasQueued = (hqNotQueued, hqQueued, hqBlocked);
  protected
    FDebugger: TFpDebugDebuggerBase;
    FHasQueued: THasQueued;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; APriority: TFpThreadWorkerPriority);

    procedure Queue(aMethod: TDataEvent; Data: PtrInt = 0);
    (* Unqueue_DecRef also prevents new queuing
       Unqueue_DecRef allows for destruction (no more access to object)
       => therefor UnQueue_DecRef and ALL/most methods executing  unqueue_DecRef are named *_DecRef
    *)
    procedure UnQueue_DecRef(ABlockQueuing: Boolean = True);
  end;

  { TFpDbgDebggerThreadWorkerLinkedItem }

  TFpDbgDebggerThreadWorkerLinkedItem = class(TFpDbgDebggerThreadWorkerItem)
  protected
    FNextWorker: TFpDbgDebggerThreadWorkerLinkedItem; // linked list for use by TFPCallStackSupplier
    procedure DoRemovedFromLinkedList; virtual;
  end;

  { TFpDbgDebggerThreadWorkerLinkedList }

  TFpDbgDebggerThreadWorkerLinkedList = object
  private
    FNextWorker: TFpDbgDebggerThreadWorkerLinkedItem;
    FLocked: Boolean;
  public
    procedure Add(AWorkItem: TFpDbgDebggerThreadWorkerLinkedItem); // Does not add ref / uses existing ref
    procedure ClearFinishedWorkers;
    procedure RequestStopForWorkers;
    procedure WaitForWorkers(AStop: Boolean); // Only call in IDE thread (main thread)
  end;

  { TFpThreadWorkerControllerRun }

  TFpThreadWorkerControllerRun = class(TFpDbgDebggerThreadWorkerItem)
  private
    FWorkerThreadId: TThreadID;
  protected
    FStartSuccessfull: boolean;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase);
    property StartSuccesfull: boolean read FStartSuccessfull;
    property WorkerThreadId: TThreadID read FWorkerThreadId;
  end;

  { TFpThreadWorkerRunLoop }

  TFpThreadWorkerRunLoop = class(TFpDbgDebggerThreadWorkerItem)
  protected
    procedure LoopFinished_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase);
  end;

  { TFpThreadWorkerRunLoopAfterIdle }

  TFpThreadWorkerRunLoopAfterIdle = class(TFpDbgDebggerThreadWorkerItem)
  protected
    procedure CheckIdleOrRun_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase);
  end;

  { TFpThreadWorkerAsyncMeth }

  TFpThreadWorkerAsyncMeth = class(TFpDbgDebggerThreadWorkerItem)
  protected
    FAsyncMethod: TFpDbgAsyncMethod;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; AnAsyncMethod: TFpDbgAsyncMethod);
  end;

  { TFpThreadWorkerPrepareCallStackEntryList }

  TFpThreadWorkerPrepareCallStackEntryList = class(TFpDbgDebggerThreadWorkerLinkedItem)
  (* Do not accesss   CallStackEntryList.Items[]   while this is running *)
  protected
    FRequiredMinCount: Integer;
    FThread: TDbgThread;
    procedure PrepareCallStackEntryList(AFrameRequired: Integer; AThread: TDbgThread);
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; ARequiredMinCount: Integer; APriority: TFpThreadWorkerPriority = twpStack);
    constructor Create(ADebugger: TFpDebugDebuggerBase; ARequiredMinCount: Integer; AThread: TDbgThread);
  end;

  { TFpThreadWorkerCallStackCount }

  TFpThreadWorkerCallStackCount = class(TFpThreadWorkerPrepareCallStackEntryList)
  protected
    procedure UpdateCallstack_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  end;

  { TFpThreadWorkerCallEntry }

  TFpThreadWorkerCallEntry = class(TFpThreadWorkerPrepareCallStackEntryList)
  protected
    FCallstackIndex: Integer;
    FDbgCallStack: TDbgCallstackEntry;
    FParamAsString: String;
    procedure UpdateCallstackEntry_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  end;

  { TFpThreadWorkerThreads }

  TFpThreadWorkerThreads = class(TFpThreadWorkerPrepareCallStackEntryList)
  protected
    procedure UpdateThreads_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase);
  end;

  { TFpThreadWorkerLocals }

  TFpThreadWorkerLocals = class(TFpDbgDebggerThreadWorkerLinkedItem)
  protected type
    TResultEntry = record
      Name, Value: String;
      class operator = (a, b: TResultEntry): Boolean;
    end;
    TResultList = specialize TFPGList<TResultEntry>;
  protected
    FThreadId, FStackFrame: Integer;
    FResults: TResultList;
    procedure UpdateLocals_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  public
    destructor Destroy; override;
  end;

  { TFpThreadWorkerModify }

  TFpThreadWorkerModify = class(TFpDbgDebggerThreadWorkerLinkedItem)
  private
    FExpression, FNewVal: String;
    FStackFrame, FThreadId: Integer;
    FSuccess: Boolean;
  protected
    procedure DoCallback_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
    property Success: Boolean read FSuccess;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase;
                       //APriority: TFpThreadWorkerPriority;
                       const AnExpression, ANewValue: String;
                       AStackFrame, AThreadId: Integer
                      );
    function DebugText: String; override;
  end;

  { TFpThreadWorkerEvaluate }

  TFpThreadWorkerEvaluate = class(TFpDbgDebggerThreadWorkerLinkedItem)
  private
    FAllowFunctions: Boolean;
    FExpressionScope: TFpDbgSymbolScope;

    function DoWatchFunctionCall(AnExpressionPart: TFpPascalExpressionPart;
      AFunctionValue, ASelfValue: TFpValue; AParams: TFpPascalExpressionPartList;
      out AResult: TFpValue; var AnError: TFpError): boolean;
  protected
    function EvaluateExpression(const AnExpression: String;
                                AStackFrame, AThreadId: Integer;
                                ADispFormat: TWatchDisplayFormat;
                                ARepeatCnt: Integer;
                                AnEvalFlags: TDBGEvaluateFlags;
                                out AResText: String;
                                out ATypeInfo: TDBGType
                               ): Boolean;
  public
  end;

  { TFpThreadWorkerEvaluateExpr }

  TFpThreadWorkerEvaluateExpr = class(TFpThreadWorkerEvaluate)
  private
    FExpression: String;
    FStackFrame, FThreadId: Integer;
    FDispFormat: TWatchDisplayFormat;
    FRepeatCnt: Integer;
    FEvalFlags: TDBGEvaluateFlags;
  protected
    FRes: Boolean;
    FResText: String;
    FResDbgType: TDBGType;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase;
                       APriority: TFpThreadWorkerPriority;
                       const AnExpression: String;
                       AStackFrame, AThreadId: Integer;
                       ADispFormat: TWatchDisplayFormat;
                       ARepeatCnt: Integer;
                       AnEvalFlags: TDBGEvaluateFlags
                      );
    function DebugText: String; override;
  end;

  { TFpThreadWorkerCmdEval }

  TFpThreadWorkerCmdEval = class(TFpThreadWorkerEvaluateExpr)
  protected
    FCallback: TDBGEvaluateResultCallback;
    procedure DoCallback_DecRef(Data: PtrInt = 0);
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase;
                       APriority: TFpThreadWorkerPriority;
                       const AnExpression: String;
                       AStackFrame, AThreadId: Integer;
                       AnEvalFlags: TDBGEvaluateFlags;
                       ACallback: TDBGEvaluateResultCallback
                      );
    destructor Destroy; override;
    procedure Abort;
  end;

  { TFpThreadWorkerWatchValueEval }

  TFpThreadWorkerWatchValueEval = class(TFpThreadWorkerEvaluateExpr)
  protected
    procedure UpdateWatch_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  end;

  { TFpThreadWorkerBreakPoint }

  TFpThreadWorkerBreakPoint = class(TFpDbgDebggerThreadWorkerItem)
  public
    procedure RemoveBreakPoint_DecRef; virtual;
    procedure AbortSetBreak; virtual;
  end;

  { TFpThreadWorkerBreakPointSet }

  TFpThreadWorkerBreakPointSet = class(TFpThreadWorkerBreakPoint)
  private
    FInternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint;
    FKind: TDBGBreakPointKind;
    FAddress: TDBGPtr;
    FSource: String;
    FLine: Integer;
    FStackFrame, FThreadId: Integer;
    FWatchData: String;
    FWatchScope: TDBGWatchPointScope;
    FWatchKind: TDBGWatchPointKind;
  protected
    FResetBreakPoint: Boolean;
    procedure UpdateBrkPoint_DecRef(Data: PtrInt = 0); virtual; abstract;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; AnAddress: TDBGPtr);
    constructor Create(ADebugger: TFpDebugDebuggerBase; ASource: String; ALine: Integer);
    constructor Create(ADebugger: TFpDebugDebuggerBase;
      AWatchData: String; AWatchScope: TDBGWatchPointScope; AWatchKind: TDBGWatchPointKind;
      AStackFrame, AThreadId: Integer);
    property InternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint read FInternalBreakpoint;
  end;

  { TFpThreadWorkerBreakPointRemove }

  TFpThreadWorkerBreakPointRemove = class(TFpThreadWorkerBreakPoint)
  protected
    FInternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint;
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; AnInternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint);
    property InternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint read FInternalBreakpoint;
  end;

implementation

{ TFpDbgDebggerThreadWorkerItem }

constructor TFpDbgDebggerThreadWorkerItem.Create(ADebugger: TFpDebugDebuggerBase;
  APriority: TFpThreadWorkerPriority);
begin
  inherited Create(APriority);
  FDebugger := ADebugger;
  AddRef;
end;

procedure TFpDbgDebggerThreadWorkerItem.Queue(aMethod: TDataEvent; Data: PtrInt
  );
begin
  FDebugger.FLockList.Lock;
  try
    if (FHasQueued <> hqBlocked) then begin
      assert(FHasQueued = hqNotQueued, 'TFpDbgDebggerThreadWorkerItem.Queue: FHasQueued = hqNotQueued');
      FHasQueued := hqQueued;
      AddRef;
      Application.QueueAsyncCall(aMethod, 0);
    end;
  finally
    FDebugger.FLockList.UnLock;
  end;
end;

procedure TFpDbgDebggerThreadWorkerItem.UnQueue_DecRef(ABlockQueuing: Boolean);
var
  HasQ: THasQueued;
begin
  FDebugger.FLockList.Lock;
  HasQ := FHasQueued;
  if ABlockQueuing then begin
    FHasQueued := hqBlocked;
    FDebugger.FLockList.UnLock; // unlock first.
    Application.RemoveAsyncCalls(Self);
  end
  else begin
    FHasQueued := hqNotQueued;
    try
      Application.RemoveAsyncCalls(Self);
    finally
      FDebugger.FLockList.UnLock;
    end;
  end;

  if HasQ = hqQueued then
    DecRef; // may call destroy
end;

{ TFpDbgDebggerThreadWorkerLinkedItem }

procedure TFpDbgDebggerThreadWorkerLinkedItem.DoRemovedFromLinkedList;
begin
  UnQueue_DecRef;
end;

{ TFpDbgDebggerThreadWorkerLinkedList }

procedure TFpDbgDebggerThreadWorkerLinkedList.Add(
  AWorkItem: TFpDbgDebggerThreadWorkerLinkedItem);
begin
  AWorkItem.FNextWorker := FNextWorker;
  FNextWorker := AWorkItem;
end;

procedure TFpDbgDebggerThreadWorkerLinkedList.ClearFinishedWorkers;
var
  WorkItem, w: TFpDbgDebggerThreadWorkerLinkedItem;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpDbgDebggerThreadWorkerLinkedList.ClearFinishedCountWorkers: system.ThreadID = classes.MainThreadID');
  if FLocked then
    exit;
  FLocked := True;
  WorkItem := FNextWorker;
  while (WorkItem <> nil) and (WorkItem.RefCount = 1) do begin
    w := WorkItem;
    WorkItem := w.FNextWorker;
    w.DoRemovedFromLinkedList;
    w.DecRef;
  end;
  FNextWorker := WorkItem;
  FLocked := False;
end;

procedure TFpDbgDebggerThreadWorkerLinkedList.RequestStopForWorkers;
var
  WorkItem: TFpDbgDebggerThreadWorkerLinkedItem;
begin
  WorkItem := FNextWorker;
  while (WorkItem <> nil) do begin
    WorkItem.RequestStop;
    WorkItem := WorkItem.FNextWorker;
  end;
end;

procedure TFpDbgDebggerThreadWorkerLinkedList.WaitForWorkers(AStop: Boolean);
var
  WorkItem, w: TFpDbgDebggerThreadWorkerLinkedItem;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpDbgDebggerThreadWorkerLinkedList.WaitForWorkers: system.ThreadID = classes.MainThreadID');
  assert(not FLocked, 'TFpDbgDebggerThreadWorkerLinkedList.WaitForWorkers: not FLocked');
  if AStop then
    RequestStopForWorkers;

  FLocked := True;
  WorkItem := FNextWorker;
  FNextWorker := nil;
  while (WorkItem <> nil) do begin
    w := WorkItem;
    WorkItem := w.FNextWorker;
    if w.IsCancelled then
      w.FDebugger.FWorkQueue.RemoveItem(w)
    else
      w.FDebugger.FWorkQueue.WaitForItem(w);
    w.DoRemovedFromLinkedList;
    w.DecRef;
  end;
  FLocked := False;
end;

{ TFpThreadWorkerControllerRun }

procedure TFpThreadWorkerControllerRun.DoExecute;
begin
  FStartSuccessfull := FDebugger.FDbgController.Run;
  FWorkerThreadId := ThreadID;
end;

constructor TFpThreadWorkerControllerRun.Create(ADebugger: TFpDebugDebuggerBase);
begin
  inherited Create(ADebugger, twpContinue);
end;

{ TFpThreadWorkerRunLoop }

procedure TFpThreadWorkerRunLoop.DoExecute;
begin
  FDebugger.FDbgController.ProcessLoop;
  Queue(@LoopFinished_DecRef);
end;

constructor TFpThreadWorkerRunLoop.Create(ADebugger: TFpDebugDebuggerBase);
begin
  inherited Create(ADebugger, twpContinue);
end;

{ TFpThreadWorkerRunLoopAfterIdle }

procedure TFpThreadWorkerRunLoopAfterIdle.DoExecute;
begin
  Queue(@CheckIdleOrRun_DecRef);
end;

constructor TFpThreadWorkerRunLoopAfterIdle.Create(ADebugger: TFpDebugDebuggerBase);
begin
  inherited Create(ADebugger, twpContinue);
end;

{ TFpThreadWorkerAsyncMeth }

procedure TFpThreadWorkerAsyncMeth.DoExecute;
begin
  FAsyncMethod();
end;

constructor TFpThreadWorkerAsyncMeth.Create(ADebugger: TFpDebugDebuggerBase;
  AnAsyncMethod: TFpDbgAsyncMethod);
begin
  inherited Create(ADebugger, twpUser);
  FAsyncMethod := AnAsyncMethod;
end;

{ TFpThreadWorkerPrepareCallStackEntryList }

procedure TFpThreadWorkerPrepareCallStackEntryList.PrepareCallStackEntryList(
  AFrameRequired: Integer; AThread: TDbgThread);
var
  ThreadCallStack: TDbgCallstackEntryList;
  CurCnt, ReqCnt: Integer;
begin
  ThreadCallStack := AThread.CallStackEntryList;

  if ThreadCallStack = nil then begin
    AThread.PrepareCallStackEntryList(-2); // Only create the list
    ThreadCallStack := AThread.CallStackEntryList;
    if ThreadCallStack = nil then
      exit;
  end;

  FDebugger.FLockList.GetLockFor(ThreadCallStack);
  try
    CurCnt := ThreadCallStack.Count;
    while (not StopRequested) and (FRequiredMinCount > CurCnt) and
          (not ThreadCallStack.HasReadAllAvailableFrames)
    do begin
      ReqCnt := Min(CurCnt + 5, FRequiredMinCount);
      AThread.PrepareCallStackEntryList(ReqCnt);
      CurCnt := ThreadCallStack.Count;
      if CurCnt < ReqCnt then
        exit;
    end;
  finally
    FDebugger.FLockList.FreeLockFor(ThreadCallStack);
  end;
end;

procedure TFpThreadWorkerPrepareCallStackEntryList.DoExecute;
var
  t: TDbgThread;
begin
  if FRequiredMinCount < 0 then
    exit;
  if FThread = nil then begin
    for t in FDebugger.FDbgController.CurrentProcess.ThreadMap do begin
      PrepareCallStackEntryList(FRequiredMinCount, t);
      if StopRequested then
        break;
    end;
  end
  else
    PrepareCallStackEntryList(FRequiredMinCount, FThread);
end;

constructor TFpThreadWorkerPrepareCallStackEntryList.Create(
  ADebugger: TFpDebugDebuggerBase; ARequiredMinCount: Integer;
  APriority: TFpThreadWorkerPriority);
begin
  inherited Create(ADebugger, APriority);
  FRequiredMinCount := ARequiredMinCount;
  FThread := nil;
end;

constructor TFpThreadWorkerPrepareCallStackEntryList.Create(
  ADebugger: TFpDebugDebuggerBase; ARequiredMinCount: Integer; AThread: TDbgThread);
begin
  Create(ADebugger, ARequiredMinCount);
  FThread := AThread;
end;

{ TFpThreadWorkerCallStackCount }

procedure TFpThreadWorkerCallStackCount.DoExecute;
begin
  inherited DoExecute;
  Queue(@UpdateCallstack_DecRef);
end;

{ TFpThreadWorkerCallEntry }

procedure TFpThreadWorkerCallEntry.DoExecute;
var
  PrettyPrinter: TFpPascalPrettyPrinter;
  Prop: TFpDebugDebuggerProperties;
begin
  inherited DoExecute;

  FDbgCallStack := FThread.CallStackEntryList[FCallstackIndex];
  if (FDbgCallStack <> nil) and (not StopRequested) then begin
    Prop := TFpDebugDebuggerProperties(FDebugger.GetProperties);
    PrettyPrinter := TFpPascalPrettyPrinter.Create(DBGPTRSIZE[FDebugger.FDbgController.CurrentProcess.Mode]);
    PrettyPrinter.Context := FDebugger.FDbgController.DefaultContext;

    FDebugger.FMemManager.MemLimits.MaxArrayLen            := Prop.MemLimits.MaxStackArrayLen;
    FDebugger.FMemManager.MemLimits.MaxStringLen           := Prop.MemLimits.MaxStackStringLen;
    FDebugger.FMemManager.MemLimits.MaxNullStringSearchLen := Prop.MemLimits.MaxStackNullStringSearchLen;

    FParamAsString := FDbgCallStack.GetParamsAsString(PrettyPrinter);
    PrettyPrinter.Free;

    FDebugger.FMemManager.MemLimits.MaxArrayLen            := Prop.MemLimits.MaxArrayLen;
    FDebugger.FMemManager.MemLimits.MaxStringLen           := Prop.MemLimits.MaxStringLen;
    FDebugger.FMemManager.MemLimits.MaxNullStringSearchLen := Prop.MemLimits.MaxNullStringSearchLen;
  end;

  Queue(@UpdateCallstackEntry_DecRef);
end;

{ TFpThreadWorkerThreads }

procedure TFpThreadWorkerThreads.DoExecute;
begin
  inherited DoExecute;
  Queue(@UpdateThreads_DecRef);
end;

constructor TFpThreadWorkerThreads.Create(ADebugger: TFpDebugDebuggerBase);
begin
  inherited Create(ADebugger, 1, twpThread);
end;

{ TFpThreadWorkerLocals.TResultEntry }

class operator TFpThreadWorkerLocals.TResultEntry. = (a, b: TResultEntry
  ): Boolean;
begin
  Result := False;
  assert(False, 'TFpThreadWorkerLocals.TResultEntry.=: False');
end;

{ TFpThreadWorkerLocals }

procedure TFpThreadWorkerLocals.DoExecute;
var
  LocalScope: TFpDbgSymbolScope;
  ProcVal, m: TFpValue;
  PrettyPrinter: TFpPascalPrettyPrinter;
  i: Integer;
  r: TResultEntry;
begin
  LocalScope := FDebugger.FDbgController.CurrentProcess.FindSymbolScope(FThreadId, FStackFrame);
  if (LocalScope = nil) or (LocalScope.SymbolAtAddress = nil) then begin
    LocalScope.ReleaseReference;
    exit;
  end;

  ProcVal := LocalScope.ProcedureAtAddress;
  if (ProcVal = nil) then begin
    LocalScope.ReleaseReference;
    exit;
  end;

  PrettyPrinter := TFpPascalPrettyPrinter.Create(LocalScope.SizeOfAddress);
  PrettyPrinter.Context := LocalScope.LocationContext;
//  PrettyPrinter.MemManager.DefaultContext := LocalScope.LocationContext;

  FResults := TResultList.Create;
  for i := 0 to ProcVal.MemberCount - 1 do begin
    m := ProcVal.Member[i];
    if m <> nil then begin
      if m.DbgSymbol <> nil then
        r.Name := m.DbgSymbol.Name
      else
        r.Name := '';
      //if not StopRequested then // finish getting all names?
      PrettyPrinter.PrintValue(r.Value, m);
      m.ReleaseReference;
      FResults.Add(r);
    end;
    if StopRequested then
      Break;
  end;
  PrettyPrinter.Free;
  ProcVal.ReleaseReference;
  LocalScope.ReleaseReference;

  Queue(@UpdateLocals_DecRef);
end;

destructor TFpThreadWorkerLocals.Destroy;
begin
  FResults.Free;
  inherited Destroy;
end;

{ TFpThreadWorkerModify }

procedure TFpThreadWorkerModify.DoExecute;
var
  APasExpr: TFpPascalExpression;
  ResValue: TFpValue;
  ExpressionScope: TFpDbgSymbolScope;
  i64: int64;
  c64: QWord;
begin
  FSuccess := False;
  ExpressionScope := FDebugger.FDbgController.CurrentProcess.FindSymbolScope(FThreadId, FStackFrame);
  if ExpressionScope = nil then
    exit;

  APasExpr := TFpPascalExpression.Create(FExpression, ExpressionScope);
  try
    APasExpr.ResultValue; // trigger full validation
    if not APasExpr.Valid then
      exit;

    ResValue := APasExpr.ResultValue;
    if ResValue = nil then
      exit;

    case ResValue.Kind of
      skInteger:   if TryStrToInt64(FNewVal, i64) then ResValue.AsInteger := i64;
      skCardinal:  if TryStrToQWord(FNewVal, c64) then ResValue.AsCardinal := c64;
      skBoolean:   case LowerCase(trim(FNewVal)) of
          'true':  ResValue.AsBool := True;
          'false': ResValue.AsBool := False;
        end;
      skChar:      ResValue.AsString := FNewVal;
      skEnum:      ResValue.AsString := FNewVal;
      skSet:       ResValue.AsString := FNewVal;
      skPointer:   if TryStrToQWord(FNewVal, c64) then ResValue.AsCardinal := c64;
      skFloat: ;
      skCurrency: ;
      skVariant: ;
    end;


  finally
    APasExpr.Free;
    ExpressionScope.ReleaseReference;
    Queue(@DoCallback_DecRef);
  end;
end;

constructor TFpThreadWorkerModify.Create(ADebugger: TFpDebugDebuggerBase;
  const AnExpression, ANewValue: String; AStackFrame, AThreadId: Integer);
begin
  inherited Create(ADebugger, twpModify);
  FExpression := AnExpression;
  FNewVal := ANewValue;
  FStackFrame := AStackFrame;
  FThreadId := AThreadId;
end;

function TFpThreadWorkerModify.DebugText: String;
begin
  Result := inherited DebugText;
end;

{ TFpThreadWorkerEvaluate }

function TFpThreadWorkerEvaluate.DoWatchFunctionCall(
  AnExpressionPart: TFpPascalExpressionPart; AFunctionValue,
  ASelfValue: TFpValue; AParams: TFpPascalExpressionPartList; out
  AResult: TFpValue; var AnError: TFpError): boolean;
var
  FunctionSymbolData, FunctionSymbolType, FunctionResultSymbolType,
  TempSymbol: TFpSymbol;
  ParamSymbol, ExprParamVal: TFpValue;
  ProcAddress: TFpDbgMemLocation;
  FunctionResultDataSize: TFpDbgValueSize;
  ParameterSymbolArr: array of TFpSymbol;
  CallContext: TFpDbgInfoCallContext;
  PCnt, i, FoundIdx, ItemsOffs: Integer;
  rk: TDbgSymbolKind;
begin
  Result := False;
  if FExpressionScope = nil then
    exit;
(*
   AFunctionValue =>  TFpValueDwarfSubroutine  // gotten from <== TFpSymbolDwarfDataProc.GetValueObject;
                   .DataSympol = TFpSymbolDwarfDataProc  from which we were created
                   .TypeSymbol = TFpSymbolDwarfTypeProc.TypeInfo : TFpSymbolDwarfType

   AFunctionFpSymbol => TFpSymbolDwarfTypeProc;
   val
*)

  FunctionSymbolData := AFunctionValue.DbgSymbol;  // AFunctionValue . FDataSymbol
  FunctionSymbolType := FunctionSymbolData.TypeInfo;
  FunctionResultSymbolType := FunctionSymbolType.TypeInfo;

  if not (FunctionResultSymbolType.Kind in [skInteger, skCurrency, skPointer, skEnum,
      skCardinal, skBoolean, skChar, skClass])
  then begin
    DebugLn(['Error result kind  ', dbgs(FunctionSymbolType.Kind)]);
    AnError := CreateError(fpErrAnyError, ['Result type of function not supported']);
    exit;
  end;

  // TODO: pass a value object
  if (not FunctionResultSymbolType.ReadSize(nil, FunctionResultDataSize)) or
     (FunctionResultDataSize >  FDebugger.FMemManager.RegisterSize(0))
  then begin
    DebugLn(['Error result size', dbgs(FunctionResultDataSize)]);
    //ReturnMessage := 'Unable to call function. The size of the function-result exceeds the content-size of a register.';
    AnError := CreateError(fpErrAnyError, ['Result type of function not supported']);
    exit;
  end;

  // check params

  ProcAddress := AFunctionValue.DataAddress;
  if not IsReadableLoc(ProcAddress) then begin
    DebugLn(['Error proc addr']);
    AnError := CreateError(fpErrAnyError, ['Unable to calculate function address']);
    exit;
  end;

  PCnt := AParams.Count;
  ItemsOffs := 0;
  if ASelfValue <> nil then begin
    inc(PCnt);
    ItemsOffs := -1; // In the loop "i = 0" is the self object. So "i = 1" should be AParams[0]
  end;

  SetLength(ParameterSymbolArr, PCnt);
    for i := 0 to High(ParameterSymbolArr) do
      ParameterSymbolArr[i] := nil;
  FoundIdx := 0;
  try
    for i := 0 to FunctionSymbolType.NestedSymbolCount - 1 do begin
      TempSymbol := FunctionSymbolType.NestedSymbol[i];
      if sfParameter in TempSymbol.Flags then begin
        if FoundIdx >= PCnt then begin
          DebugLn(['Error param count']);
          AnError := CreateError(fpErrAnyError, ['wrong amount of parameters']);
          exit;
          //ReturnMessage := Format('Unable to call function%s. Not enough parameters supplied.', [OutputFunctionName]);
        end;
        // Type Compatibility
        // TODO: more checks for type compatibility
        if (ASelfValue <> nil) and (FoundIdx = 0) then begin
          // TODO: check self param
        end
        else begin
          ExprParamVal := AParams.Items[FoundIdx + ItemsOffs].ResultValue;
          if (ExprParamVal = nil) then begin
            DebugLn('Internal error for arg %d ', [FoundIdx]);
            AnError := AnExpressionPart.Expression.Error;
            if not IsError(AnError) then
              AnError := CreateError(fpErrAnyError, ['internal error, computing parameter']);
            exit;
          end;
          rk := ExprParamVal.Kind;
          if not (rk in [skInteger, {skCurrency,} skPointer, skEnum, skCardinal, skBoolean, skChar, skClass]) then begin
            DebugLn('Error not supported kind arg %d : %s ', [FoundIdx, dbgs(rk)]);
            AnError := CreateError(fpErrAnyError, ['parameter type not supported']);
            exit;
          end;
          if (TempSymbol.Kind <> rk) and
             ( (TempSymbol.Kind in [skInteger, skCardinal]) <> (rk in [skInteger, skCardinal]) )
          then begin
            DebugLn('Error kind mismatch for arg %d : %s <> %s', [FoundIdx, dbgs(TempSymbol.Kind), dbgs(rk)]);
            AnError := CreateError(fpErrAnyError, ['wrong type for parameter']);
            exit;
          end;
        end;
        if not IsTargetOrRegNotNil(FDebugger.FDbgController.CurrentProcess.CallParamDefaultLocation(FoundIdx)) then begin
          DebugLn('error to many args / not supported / arg > %d ', [FoundIdx]);
          AnError := CreateError(fpErrAnyError, ['too many parameter / not supported']);
          exit;
        end;
        TempSymbol.AddReference;
        ParameterSymbolArr[FoundIdx] := TempSymbol;
        inc(FoundIdx)
      end;
    end;
    if FoundIdx <> PCnt then begin
      DebugLn(['Error param count']);
      AnError := CreateError(fpErrAnyError, ['wrong amount of parameters']);
      exit;
    end;


    CallContext := FDebugger.FDbgController.Call(ProcAddress, FExpressionScope.LocationContext,
      FDebugger.FMemReader, FDebugger.FMemConverter);

    try
      for i := 0 to High(ParameterSymbolArr) do begin
        ParamSymbol := CallContext.CreateParamSymbol(i, ParameterSymbolArr[i], FDebugger.FDbgController.CurrentProcess);
        try
          if (ASelfValue <> nil) and (i = 0) then
            ParamSymbol.AsCardinal := ASelfValue.AsCardinal
          else
            ParamSymbol.AsCardinal := AParams.Items[i + ItemsOffs].ResultValue.AsCardinal;
          if IsError(ParamSymbol.LastError) then begin
            DebugLn('Internal error for arg %d ', [i]);
            AnError := ParamSymbol.LastError;
            exit;
          end;
        finally
          ParamSymbol.ReleaseReference;
        end;
      end;

      FDebugger.FDbgController.ProcessLoop;

      if not CallContext.IsValid then begin
        DebugLn(['Error in call ',CallContext.Message]);
        //ReturnMessage := CallContext.Message;
        exit;
      end;

      AResult := CallContext.CreateParamSymbol(-1, FunctionSymbolType,
        FDebugger.FDbgController.CurrentProcess, FunctionSymbolData.Name);
      Result := AResult <> nil;
    finally
      CallContext.ReleaseReference;
    end;
  finally
    for i := 0 to High(ParameterSymbolArr) do
      if ParameterSymbolArr[i] <> nil then
        ParameterSymbolArr[i].ReleaseReference;
  end;


end;

function TFpThreadWorkerEvaluate.EvaluateExpression(const AnExpression: String;
  AStackFrame, AThreadId: Integer; ADispFormat: TWatchDisplayFormat;
  ARepeatCnt: Integer; AnEvalFlags: TDBGEvaluateFlags; out AResText: String;
  out ATypeInfo: TDBGType): Boolean;
var
  APasExpr, PasExpr2: TFpPascalExpression;
  PrettyPrinter: TFpPascalPrettyPrinter;
  ResValue: TFpValue;
  CastName, ResText2: String;
begin
  Result := False;
  AResText := '';
  ATypeInfo := nil;

  FExpressionScope := FDebugger.FDbgController.CurrentProcess.FindSymbolScope(AThreadId, AStackFrame);
  if FExpressionScope = nil then
    exit;

  PrettyPrinter := nil;
  APasExpr := TFpPascalExpression.Create(AnExpression, FExpressionScope);
  try
    if FAllowFunctions and (dfEvalFunctionCalls in FDebugger.EnabledFeatures) then
      APasExpr.OnFunctionCall  := @DoWatchFunctionCall;
    APasExpr.ResultValue; // trigger full validation
    if not APasExpr.Valid then begin
      AResText := ErrorHandler.ErrorAsString(APasExpr.Error);
      exit;
    end;

    ResValue := APasExpr.ResultValue;
    if ResValue = nil then begin
      AResText := 'Error';
      exit;
    end;

    if StopRequested then
      exit;
    if (ResValue.Kind = skClass) and (ResValue.AsCardinal <> 0) and
       (not IsError(ResValue.LastError)) and (defClassAutoCast in AnEvalFlags)
    then begin
      if ResValue.GetInstanceClassName(CastName) then begin
        PasExpr2 := TFpPascalExpression.Create(CastName+'('+AnExpression+')', FExpressionScope);
        PasExpr2.ResultValue;
        if PasExpr2.Valid then begin
          APasExpr.Free;
          APasExpr := PasExpr2;
          ResValue := APasExpr.ResultValue;
        end
        else
          PasExpr2.Free;
      end
      else begin
        ResValue.ResetError; // in case GetInstanceClassName did set an error
        // TODO: indicate that typecasting to instance failed
      end;
    end;

    if StopRequested then
      exit;

    PrettyPrinter := TFpPascalPrettyPrinter.Create(FExpressionScope.SizeOfAddress);
    PrettyPrinter.Context := FExpressionScope.LocationContext;

    if defNoTypeInfo in AnEvalFlags then
      Result := PrettyPrinter.PrintValue(AResText, ResValue, ADispFormat, ARepeatCnt)
    else
      Result := PrettyPrinter.PrintValue(AResText, ATypeInfo, ResValue, ADispFormat, ARepeatCnt);

    // PCHAR/String
    if Result and APasExpr.HasPCharIndexAccess and not IsError(ResValue.LastError) then begin
    // TODO: Only dwarf 2
      APasExpr.FixPCharIndexAccess := True;
      APasExpr.ResetEvaluation;
      ResValue := APasExpr.ResultValue;
      if (ResValue=nil) or (not PrettyPrinter.PrintValue(ResText2, ResValue, ADispFormat, ARepeatCnt)) then
        ResText2 := 'Failed';
      AResText := 'PChar: '+AResText+ LineEnding + 'String: '+ResText2;
    end;

    if Result then
      Result := not IsError(ResValue.LastError) // AResText should be set from Prettyprinter
    else
      AResText := 'Error';

    if not Result then
      FreeAndNil(ATypeInfo);
  finally
    PrettyPrinter.Free;
    APasExpr.Free;
    FExpressionScope.ReleaseReference;
  end;
end;

{ TFpThreadWorkerEvaluateExpr }

procedure TFpThreadWorkerEvaluateExpr.DoExecute;
begin
  FRes := EvaluateExpression(FExpression, FStackFrame, FThreadId,
    FDispFormat, FRepeatCnt, FEvalFlags, FResText, FResDbgType);
end;

constructor TFpThreadWorkerEvaluateExpr.Create(ADebugger: TFpDebugDebuggerBase;
  APriority: TFpThreadWorkerPriority; const AnExpression: String; AStackFrame,
  AThreadId: Integer; ADispFormat: TWatchDisplayFormat; ARepeatCnt: Integer;
  AnEvalFlags: TDBGEvaluateFlags);
begin
  inherited Create(ADebugger, APriority);
  FExpression := AnExpression;
  FStackFrame := AStackFrame;
  FThreadId := AThreadId;
  FDispFormat := ADispFormat;
  FRepeatCnt := ARepeatCnt;
  FEvalFlags := AnEvalFlags;
  if (defAllowFunctionCall in AnEvalFlags) then
    FAllowFunctions := True;
  FRes := False;
end;

function TFpThreadWorkerEvaluateExpr.DebugText: String;
begin
  Result := inherited DebugText;
  if self = nil then exit;
  Result := Format('%s Expr: "%s" T: %s S: %s', [Result, FExpression, dbgs(FThreadId), dbgs(FStackFrame)]);
end;

{ TFpThreadWorkerCmdEval }

procedure TFpThreadWorkerCmdEval.DoCallback_DecRef(Data: PtrInt);
var
  CB: TDBGEvaluateResultCallback;
  Dbg: TFpDebugDebuggerBase;
  Res: Boolean;
  ResText: String;
  ResDbgType: TDBGType;
begin
  assert(system.ThreadID = classes.MainThreadID, 'TFpThreadWorkerCmdEval.DoCallback_DecRef: system.ThreadID = classes.MainThreadID');
  CB := nil;
  try
    if FEvalFlags * [defNoTypeInfo, defSimpleTypeInfo, defFullTypeInfo] = [defNoTypeInfo] then
      FreeAndNil(FResText);

    if (FCallback <> nil) then begin
      // All to local vars, because SELF may be destroyed before/while the callback happens
      CB := FCallback;
      Dbg := FDebugger;
      Res := FRes;
      ResText := FResText;
      ResDbgType := FResDbgType;
      FResDbgType := nil; // prevent from being freed => will be freed in callback
      FCallback := nil; // Ensure callback is never called a 2nd time (e.g. if Self.Abort is called, while in Callback)
      (* We cannot call Callback here, because ABORT can be called, and prematurely call UnQueue_DecRef,
         removing the last ref to this object *)
    end;
  except
  end;

  UnQueue_DecRef;

  // Self may now be invalid, unless FDebugger.FEvalWorkItem still has a reference.
  // Abort may be called (during CB), removing this refence.
  // Abort would be called, if a new Evaluate Request is made. FEvalWorkItem<>nil
  if CB <> nil then
    CB(Dbg, Res, ResText, ResDbgType);
end;

procedure TFpThreadWorkerCmdEval.DoExecute;
begin
  inherited DoExecute;
  Queue(@DoCallback_DecRef);
end;

constructor TFpThreadWorkerCmdEval.Create(ADebugger: TFpDebugDebuggerBase;
  APriority: TFpThreadWorkerPriority; const AnExpression: String; AStackFrame,
  AThreadId: Integer; AnEvalFlags: TDBGEvaluateFlags;
  ACallback: TDBGEvaluateResultCallback);
begin
  inherited Create(ADebugger, APriority, AnExpression, AStackFrame, AThreadId, wdfDefault, 0,
    AnEvalFlags);
  FCallback := ACallback;
end;

destructor TFpThreadWorkerCmdEval.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FResDbgType);
end;

procedure TFpThreadWorkerCmdEval.Abort;
begin
  RequestStop;
  FDebugger.FWorkQueue.RemoveItem(Self);
  DoCallback_DecRef;
end;

{ TFpThreadWorkerWatchValueEval }

procedure TFpThreadWorkerWatchValueEval.DoExecute;
begin
  inherited DoExecute;
  Queue(@UpdateWatch_DecRef);
end;

{ TFpThreadWorkerBreakPoint }

procedure TFpThreadWorkerBreakPoint.RemoveBreakPoint_DecRef;
begin
  //
end;

procedure TFpThreadWorkerBreakPoint.AbortSetBreak;
begin
  //
end;

{ TFpThreadWorkerBreakPointSet }

procedure TFpThreadWorkerBreakPointSet.DoExecute;
var
  CurContext: TFpDbgSymbolScope;
  WatchPasExpr: TFpPascalExpression;
  R: TFpValue;
  s: TFpDbgValueSize;
begin
  case FKind of
    bpkAddress:
      FInternalBreakpoint := FDebugger.FDbgController.CurrentProcess.AddBreak(FAddress, True);
    bpkSource:
      FInternalBreakpoint := FDebugger.FDbgController.CurrentProcess.AddBreak(FSource, FLine, True);
    bpkData: begin
      CurContext := FDebugger.FDbgController.CurrentProcess.FindSymbolScope(FThreadId, FStackFrame);
      if CurContext <> nil then begin
        WatchPasExpr := TFpPascalExpression.Create(FWatchData, CurContext);
        R := WatchPasExpr.ResultValue; // Address and Size
        // TODO: Cache current value
        if WatchPasExpr.Valid and IsTargetNotNil(R.Address) and R.GetSize(s) then begin
          // pass context
          FInternalBreakpoint := FDebugger.FDbgController.CurrentProcess.AddWatch(R.Address.Address, SizeToFullBytes(s), FWatchKind, FWatchScope);
        end;
        WatchPasExpr.Free;
        CurContext.ReleaseReference;
      end;
    end;
  end;
  if FResetBreakPoint then begin
    FDebugger.FDbgController.CurrentProcess.RemoveBreak(FInternalBreakpoint);
    FreeAndNil(FInternalBreakpoint);
  end;
  Queue(@UpdateBrkPoint_DecRef);
end;

constructor TFpThreadWorkerBreakPointSet.Create(ADebugger: TFpDebugDebuggerBase; AnAddress: TDBGPtr);
begin
  FKind := bpkAddress;
  FAddress := AnAddress;
  inherited Create(ADebugger, twpUser);
end;

constructor TFpThreadWorkerBreakPointSet.Create(
  ADebugger: TFpDebugDebuggerBase; ASource: String; ALine: Integer);
begin
  FKind := bpkSource;
  FSource := ASource;
  FLine   := ALine;
  inherited Create(ADebugger, twpUser);
end;

constructor TFpThreadWorkerBreakPointSet.Create(
  ADebugger: TFpDebugDebuggerBase; AWatchData: String;
  AWatchScope: TDBGWatchPointScope; AWatchKind: TDBGWatchPointKind;
  AStackFrame, AThreadId: Integer);
begin
  FKind := bpkData;
  FWatchData  := AWatchData;
  FWatchScope := AWatchScope;
  FWatchKind  := AWatchKind;
  FStackFrame := AStackFrame;
  FThreadId   := AThreadId;
  inherited Create(ADebugger, twpUser);
end;

{ TFpThreadWorkerBreakPointRemove }

procedure TFpThreadWorkerBreakPointRemove.DoExecute;
begin
  if (FDebugger.FDbgController <> nil) and (FDebugger.FDbgController.CurrentProcess <> nil) then
    FDebugger.FDbgController.CurrentProcess.RemoveBreak(FInternalBreakpoint);
  FreeAndNil(FInternalBreakpoint);
end;

constructor TFpThreadWorkerBreakPointRemove.Create(
  ADebugger: TFpDebugDebuggerBase;
  AnInternalBreakpoint: FpDbgClasses.TFpDbgBreakpoint);
begin
  FInternalBreakpoint := AnInternalBreakpoint;
  inherited Create(ADebugger, twpUser);
end;

end.


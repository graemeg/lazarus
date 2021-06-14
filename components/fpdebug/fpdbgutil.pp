{ $Id$ }
{
 ---------------------------------------------------------------------------
 fpdbgutil.pp  -  Native freepascal debugger - Utilities
 ---------------------------------------------------------------------------

 This unit contains utility functions

 ---------------------------------------------------------------------------

 @created(Mon Apr 10th WET 2006)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.nl>)

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
unit FpDbgUtil;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, math, LazUTF8, lazCollections,
  UTF8Process, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, syncobjs;

type
  TFPDMode = (dm32, dm64);

  THexValueFormatFlag = (hvfSigned, hvfPrefixPositive, hvfIncludeHexchar);
  THexValueFormatFlags = set of THexValueFormatFlag;

  TFpThreadWorkerQueue = class;
  TFpWorkerThread = class;

  { TFpThreadWorkerItem }

  TFpThreadWorkerItem = class
  private const
    TWSTATE_NEW         = cardinal(0);
    TWSTATE_RUNNING     = cardinal(1);
    TWSTATE_WAITING     = cardinal(2);
    TWSTATE_WAIT_WORKER = cardinal(3);
    TWSTATE_DONE        = cardinal(4);
    TWSTATE_CANCEL      = cardinal(5);
    EVENT_DONE_INDICATOR = Pointer(1);
  private
    FWorkerItemEventPtr: PPRTLEvent;
    FState: Cardinal;
    FError: Exception;
    FRefCnt: LongInt;
    FStopRequested: Boolean;
    FLogGroup: PLazLoggerLogGroup;
    function GetIsCancelled: Boolean;
    function GetIsDone: Boolean;
    function MaybeWaitForPreviousWait(AQueue: TFpThreadWorkerQueue; AnEvntPtr: PPRTLEvent): boolean;
    function MaybeWaitForEvent(AnEvnt: PRTLEvent): Boolean; inline;
  protected
    procedure DoExecute; virtual;
    procedure DoFinished; virtual;
    procedure DoUnQueued; virtual; // When queue shuts down / Not called when Item is Cancelled

    procedure ExecuteInThread(MyWorkerThread: TFpWorkerThread); // called by worker thread
    procedure WaitForFinish(AQueue: TFpThreadWorkerQueue; AWaitForExecInThread: Boolean); // called by main thread => calls DoExecute, if needed
    procedure WaitForCancel(AQueue: TFpThreadWorkerQueue); // called by main thread => calls DoExecute, if needed
  public
    procedure Execute; // Exec in main thread / Only if NOT queued
    procedure AddRef;
    procedure DecRef;
    function  RefCount: Integer;
    procedure RequestStop;
    function DebugText: String; virtual;
    property Error: Exception read FError;
    property IsDone: Boolean read GetIsDone;
    property IsCancelled: Boolean read GetIsCancelled;
    property StopRequested: Boolean read FStopRequested;  // Can be checeked by the worker / optional
  end;

  { TFpWorkerThread }

  TFpWorkerThread = class(TThread)
  private
    FQueue: TFpThreadWorkerQueue;
  public
    constructor Create(AQueue: TFpThreadWorkerQueue);
    procedure Execute; override;
    property Queue: TFpThreadWorkerQueue read FQueue;
  end;

  { TFpThreadWorkerQueue }

  TFpThreadWorkerQueue = class(specialize TLazThreadedQueue<TFpThreadWorkerItem>)
  private type
    TFpWorkerThreadList = specialize TFPGObjectList<TFpWorkerThread>;
  protected type
    TFpDbgTypedFifoQueue = class(TLazTypedFifoQueue)
      function PushItem(const AItem: TFpThreadWorkerItem): Boolean; override;
    end;
  strict private
    FWantedCount, FCurrentCount: Integer;
    FThreadMonitor: TLazMonitor;
    FWorkerThreadList: TFpWorkerThreadList;
    FMainWaitEvent: PRTLEvent;
    function GetCurrentCount: Integer;
    function GetIdleThreadCount: integer;
    function GetThreadCount: integer;
    function GetThreads(AnIndex: Integer): TThread;
    function GetWantedCount: Integer;
    procedure SetThreadCount(AValue: integer);
  protected
    FLogGroup: PLazLoggerLogGroup;

    FIdleThreadCount: integer;
    function  GetRtlEvent: PRTLEvent;
    procedure FreeRtrEvent(AnEvent: PRTLEvent);
    function RemoveThread(Item: TFpWorkerThread): Integer;
    property WantedCount: Integer read GetWantedCount;
    property CurrentCount: Integer read GetCurrentCount;
    property ThreadMonitor: TLazMonitor read FThreadMonitor;
    function CreateFifoQueue(AQueueDepth: Integer): TLazTypedFifoQueue; override;
  public
    constructor Create(AQueueDepth: Integer = 10; PushTimeout: cardinal = INFINITE; PopTimeout: cardinal = INFINITE);
    destructor Destroy; override; // Will not wait for the threads.

    procedure Clear; // Not thread safe // remove all none running items
    procedure TerminateAllThreads(AWait: Boolean = False);
    procedure DoProcessMessages; virtual;

    procedure PushItem(const AItem: TFpThreadWorkerItem);
    procedure PushItemIdleOrRun(const AItem: TFpThreadWorkerItem);

    procedure WaitForItem(const AItem: TFpThreadWorkerItem; AWaitForExecInThread: Boolean = False); // called by main thread => calls DoExecute, if needed
    procedure RemoveItem(const AItem: TFpThreadWorkerItem); // wait if already running

    property ThreadCount: integer read GetThreadCount write SetThreadCount; // Not thread safe
    property Threads[AnIndex: Integer]: TThread read GetThreads;
    property IdleThreadCount: integer read GetIdleThreadCount;
    property MainWaitEvent: PRTLEvent read FMainWaitEvent;
  end;

  { TFpGlobalThreadWorkerQueue }

  TFpGlobalThreadWorkerQueue = class(TFpThreadWorkerQueue)
  private
    FRefCnt: LongInt;
  public
    destructor Destroy; override;
    procedure AddRef;
    procedure DecRef;
  end;

  { TFpDbgLockList }

  TFpDbgLockList = class
  private type
    TEventList = specialize TFPGList<PRTLEvent>;
  private
    FMonitor: TLazMonitor;
    FCachedEvent: PRTLEvent;
    FWaitList: TEventList;
    FList: TFPList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Lock;
    procedure UnLock;
    procedure GetLockFor(AnId: Pointer);
    procedure GetLockFor(AnId: TObject);
    procedure FreeLockFor(AnId: Pointer);
    procedure FreeLockFor(AnId: TObject);
  end;

const
  DBGPTRSIZE: array[TFPDMode] of Integer = (4, 8);

var
  {$ifdef cpui386}
  GMode: TFPDMode = dm32 deprecated;
  {$else}
  GMode: TFPDMode = dm64; // deprecated;
  {$endif}

function CompareUtf8BothCase(AnUpper, AnLower, AnUnknown: PChar): Boolean;

// Optimistic upper/lower case. Attempt Ansi only, but if none ansi is found, do utf8
function QuickUtf8UpperCase(const AText: String): String;
function QuickUtf8LowerCase(const AText: String): String;

function AlignPtr(Src: Pointer; Alignment: Byte): Pointer;
function HexValue(const AValue; ASize: Byte; AFlags: THexValueFormatFlags): String;
procedure Log(const AText: String; const AParams: array of const); overload;
procedure Log(const AText: String); overload;
function FormatAddress(const AAddress): String;

function GetFpDbgGlobalWorkerQueue: TFpGlobalThreadWorkerQueue;

property FpDbgGlobalWorkerQueue: TFpGlobalThreadWorkerQueue read GetFpDbgGlobalWorkerQueue;

function dbgsThread: String;
function dbgsWorkItemState(AState: Integer): String;

var
  ProcessMessagesProc: procedure of object; // Application.ProcessMessages, if needed. To be called while waiting.

implementation


var
  FPDBG_THREADS, DBG_VERBOSE, DBG_ERRORS: PLazLoggerLogGroup;
  TheFpDbgGlobalWorkerQueue: TFpGlobalThreadWorkerQueue = nil;

function GetFpDbgGlobalWorkerQueue: TFpGlobalThreadWorkerQueue;
begin
  if TheFpDbgGlobalWorkerQueue = nil then
    TheFpDbgGlobalWorkerQueue := TFpGlobalThreadWorkerQueue.Create(50);

  Result := TheFpDbgGlobalWorkerQueue;
end;

function dbgsThread: String;
begin
  if system.ThreadID = Classes.MainThreadID then
    Result := '<MAIN>'
  else
    Result := DbgS(system.ThreadID);
end;

function dbgsWorkItemState(AState: Integer): String;
begin
  case AState of
    TFpThreadWorkerItem.TWSTATE_NEW         : Result := 'TWSTATE_NEW';
    TFpThreadWorkerItem.TWSTATE_RUNNING     : Result := 'TWSTATE_RUNNING';
    TFpThreadWorkerItem.TWSTATE_WAITING     : Result := 'TWSTATE_WAITING';
    TFpThreadWorkerItem.TWSTATE_WAIT_WORKER : Result := 'TWSTATE_WAIT_WORKER';
    TFpThreadWorkerItem.TWSTATE_DONE        : Result := 'TWSTATE_DONE';
    TFpThreadWorkerItem.TWSTATE_CANCEL      : Result := 'TWSTATE_CANCEL';
    else                  RESULT := dbgs(AState)+'???';
  end;
end;

function CompareUtf8BothCase(AnUpper, AnLower, AnUnknown: PChar): Boolean;
var
  p: PChar;
begin
  Result := False;
  while (AnUpper^ <> #0) and (AnUnknown^ <> #0) do begin
    p := AnUnknown;

    if (AnUpper^ = AnUnknown^) then begin
      // maybe uppercase
      inc(AnUpper);
      inc(AnUnknown);
      while ((byte(AnUpper^) and $C0) = $C0) and (AnUpper^ = AnUnknown^) do begin
        inc(AnUpper);
        inc(AnUnknown);
      end;

      if ((byte(AnUpper^) and $C0) <> $C0) then begin // equal to upper
        inc(AnLower);
        while ((byte(AnLower^) and $C0) = $C0) do
          inc(AnLower);
        Continue;
      end;
    end
    else begin
      // skip the first byte / continuation bytes are skipped if lower matches
      inc(AnUpper);
      inc(AnUnknown);
    end;

    // Not upper, try lower
    if (AnLower^ = p^) then begin
      inc(AnLower);
      inc(p);
      while ((byte(AnLower^) and $C0) = $C0) and (AnLower^ = p^) do begin
        inc(AnLower);
        inc(p);
      end;

      if ((byte(AnLower^) and $C0) <> $C0) then begin // equal to lower
        // adjust upper and unknown to codepoint
        while ((byte(AnUpper^) and $C0) = $C0) do
          inc(AnUnknown);
        while ((byte(AnUnknown^) and $C0) = $C0) do
          inc(AnUnknown);
        Continue;
      end;
    end;

    Result := False;
    exit;
  end;

  Result := AnUpper^ = AnUnknown^;  // both #0
end;

function QuickUtf8UpperCase(const AText: String): String;
var
  src, dst: PChar;
  c: Integer;
  t: Char;
begin
  SetLength(Result, Length(AText));
  if Result = '' then
    exit;

  src := @AText[1];
  dst := @Result[1];
  c := Length(Result);
  while c > 0 do begin
    t := src^;
    if (ord(t) and 128) <>  0 then
      exit(UTF8UpperCase(AText));
    if (t in ['a'..'z']) then
      t := chr(ord(t) - 32);
    dst^ := t;
    dec(c);
    inc(src);
    inc(dst);
  end;
end;

function QuickUtf8LowerCase(const AText: String): String;
var
  src, dst: PChar;
  c: Integer;
  t: Char;
begin
  SetLength(Result, Length(AText));
  if Result = '' then
    exit;

  src := @AText[1];
  dst := @Result[1];
  c := Length(Result);
  while c > 0 do begin
    t := src^;
    if (ord(t) and 128) <>  0 then
      exit(UTF8UpperCase(AText));
    if (t in ['A'..'Z']) then
      t := chr(ord(t) + 32);
    dst^ := t;
    dec(c);
    inc(src);
    inc(dst);
  end;
end;

function AlignPtr(Src: Pointer; Alignment: Byte): Pointer;
begin
  Result := Pointer(((PtrUInt(Src) + Alignment - 1) and not PtrUInt(Alignment - 1)));
end;

function FormatAddress(const AAddress): String;
begin
  Result := HexValue(AAddress, DBGPTRSIZE[GMode], [hvfIncludeHexchar]);
end;

function HexValue(const AValue; ASize: Byte; AFlags: THexValueFormatFlags): String;
var
  i: Int64;
  p: PByte;
begin
  Result := '';
  if ASize > 8
  then begin
    Result := 'HexValue: size to large';
    Exit;
  end;
  if ASize = 0
  then begin
    Exit;
  end;

  p := @AValue;
  if p[ASize - 1] < $80
  then Exclude(AFlags, hvfSigned);

  if hvfSigned in AFlags
  then i := -1
  else i := 0;

  Move(AValue, i, ASize);
  if hvfSigned in AFlags
  then begin
    i := not i + 1;
    Result := '-';
  end
  else begin
    if hvfPrefixPositive in AFlags
    then Result := '+';
  end;
  if hvfIncludeHexchar in AFlags
  then Result := Result + '$';

  Result := Result + HexStr(i, ASize * 2);
end;

procedure Log(const AText: String; const AParams: array of const); overload;
begin
  DebugLn(Format(AText, AParams));
end;

procedure Log(const AText: String); overload;
begin
  DebugLn(AText);
end;

type

  { TFpThreadWorkerTerminateItem }

  TFpThreadWorkerTerminateItem = class(TFpThreadWorkerItem)
  end;

{ TFpDbgLockList }

constructor TFpDbgLockList.Create;
begin
  FMonitor := TLazMonitor.create;
  FCachedEvent := RTLEventCreate;
  FWaitList := TEventList.Create;
  FList := TFPList.Create;
end;

destructor TFpDbgLockList.Destroy;
begin
  FMonitor.Free;
  if FCachedEvent <> nil then
    RTLeventdestroy(FCachedEvent);
  FWaitList.Free;
  FList.Free;
  inherited Destroy;
end;

procedure TFpDbgLockList.Lock;
begin
  FMonitor.Enter;
end;

procedure TFpDbgLockList.UnLock;
begin
  FMonitor.Leave;
end;

procedure TFpDbgLockList.GetLockFor(AnId: Pointer);
var
  WaitEvent: PRTLEvent;
begin
  WaitEvent := nil;
  while true do begin
    FMonitor.Enter;
    try
      if FList.IndexOf(AnId) < 0 then begin
        FList.Add(AnId);
        if WaitEvent <> nil then begin
          FWaitList.Remove(WaitEvent);
          if FCachedEvent = nil then begin
            RTLeventResetEvent(WaitEvent);
            FCachedEvent := WaitEvent;
          end
          else
            RTLeventdestroy(WaitEvent);
        end;
        break;
      end;
      if WaitEvent = nil then begin
        WaitEvent := FCachedEvent;
        FCachedEvent := nil;
        if WaitEvent = nil then
          WaitEvent := RTLEventCreate;
        FWaitList.Add(WaitEvent);
      end
      else
        RTLeventdestroy(WaitEvent);
    finally
      FMonitor.Leave;
    end;
    RTLeventWaitFor(WaitEvent);
  end;
end;

procedure TFpDbgLockList.GetLockFor(AnId: TObject);
begin
  GetLockFor(Pointer(AnId));
end;

procedure TFpDbgLockList.FreeLockFor(AnId: Pointer);
var
  i: Integer;
begin
  FMonitor.Enter;
  try
    FList.Remove(AnId);
    for i := 0 to FWaitList.Count - 1 do
      RTLeventSetEvent(FWaitList[i]);
  finally
    FMonitor.Leave;
  end;
end;

procedure TFpDbgLockList.FreeLockFor(AnId: TObject);
begin
  FreeLockFor(Pointer(AnId));
end;

{ TFpGlobalThreadWorkerQueue }

destructor TFpGlobalThreadWorkerQueue.Destroy;
begin
  Assert(InterLockedExchangeAdd(FRefCnt, 0) = 0);
  inherited Destroy;
end;

procedure TFpGlobalThreadWorkerQueue.AddRef;
begin
  (* There are
     - The current/fpdebug-main thread
     - Maybe the IDE/main thread (if used LazDebuggerFp)
       (however, fpdebug and IDE will rarely run both at high load => they can be counted as one)
     - At least one, maybe more threads in the debugged target app
     So no more than half the cpu-core count will be allocated for workers
  *)
  if InterLockedIncrement(FRefCnt) = 1 then
    ThreadCount := Min(Max(1, GetSystemThreadCount div 2), 10);
end;

procedure TFpGlobalThreadWorkerQueue.DecRef;
begin
  if InterLockedDecrement(FRefCnt) = 0 then
    ThreadCount := 0;
end;

{ TFpThreadWorkerItem }

function TFpThreadWorkerItem.GetIsDone: Boolean;
begin
  Result := InterLockedExchangeAdd(FState, 0) = TWSTATE_DONE;
end;

function TFpThreadWorkerItem.GetIsCancelled: Boolean;
begin
  Result := InterLockedExchangeAdd(FState, 0) = TWSTATE_CANCEL;
end;

procedure TFpThreadWorkerItem.DoExecute;
begin
  //
end;

procedure TFpThreadWorkerItem.DoFinished;
begin
  if InterLockedExchangeAdd(FRefCnt, 0) <= 0 then
    Destroy;
end;

procedure TFpThreadWorkerItem.DoUnQueued;
begin
  //
end;

procedure TFpThreadWorkerItem.ExecuteInThread(MyWorkerThread: TFpWorkerThread);
var
  OldState: Cardinal;
  Evnt: PPRTLEvent;
begin
  OldState := InterlockedCompareExchange(FState, TWSTATE_RUNNING, TWSTATE_NEW);
  DebugLn(FLogGroup, '%s!%s Executing WorkItem: %s "%s" StopRequested=%s', [dbgsThread, DbgSTime, dbgsWorkItemState(OldState), DebugText, dbgs(StopRequested)]);

  if (OldState in [TWSTATE_NEW, TWSTATE_WAIT_WORKER]) then begin
    (* State is now either TWSTATE_RUNNING or TWSTATE_WAIT_WORKER  *)
    try
      DebugLnEnter(FLogGroup);
      if not StopRequested then
        DoExecute;
    finally
      DebugLnExit(FLogGroup);
      OldState := InterLockedExchange(FState, TWSTATE_DONE);
      if (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER, TWSTATE_CANCEL]) then begin
        // The FState is in TWSTATE_WAIT___ or TWSTATE_CANCEL
        // => so the event will exist, until it returned from RTLEventWaitFor
        // It is save to access
        Evnt := InterlockedExchange(FWorkerItemEventPtr, EVENT_DONE_INDICATOR);
        if Evnt <> nil then
          RTLEventSetEvent(Evnt^);
      end
      else
      // If other threads have a ref, they may call WaitForFinish and read data from this.
      if (InterLockedExchangeAdd(FRefCnt, 0) > 1) then
        WriteBarrier;
      DebugLn(FLogGroup, '%s!%s Finished WorkItem: %s "%s" StopRequested=%s', [dbgsThread, DbgSTime, dbgsWorkItemState(OldState), DebugText, dbgs(StopRequested)]);
    end;
  end;
end;

function TFpThreadWorkerItem.MaybeWaitForPreviousWait(
  AQueue: TFpThreadWorkerQueue; AnEvntPtr: PPRTLEvent): boolean;
var
  ExistingEvnt: Pointer;
begin
  Result := False;
  (* - Set FWorkerItemEventPtr before changing the state.
     - Once the NewStateForWait is set to  TWSTATE_WAIT___ or TWSTATE_CANCEL the event
       belongs to the thread, until it has been waited for
     - If there is an ExistingEvnt, it must be SET once our event was waited for.
  *)
  ExistingEvnt := InterlockedExchange(FWorkerItemEventPtr, AnEvntPtr);

  if ExistingEvnt <> nil then begin
    // Someone is already waiting for this Item
    Result := True;

    (* EVENT_DONE_INDICATOR
       If we get EVENT_DONE_INDICATOR, then the WorkItem is done too => no need to wait
       Return our item. The WorkThread is not going to use it anymore.
    *)
    if ExistingEvnt <> EVENT_DONE_INDICATOR then begin
      (* - WorkItem may have advanced the FState to TWSTATE_DONE.
           But in that case, it will have set our Evnt.
         - If somebody else is waiting, their decission of "AWaitForExecInThread"
           will be honored
      *)
      DebugLnEnter(FLogGroup);
      RTLEventWaitFor(AnEvntPtr^);
      RTLEventSetEvent(ExistingEvnt);  // Signal the other waiting thread
      DebugLnExit(FLogGroup, '%s!%s DONE WaitForFinish (with existing waiting): "%s" StopRequested=%s', [dbgsThread, DbgSTime, DebugText, dbgs(StopRequested)]);
    end;

    assert(FState = TWSTATE_DONE, 'TFpThreadWorkerItem.WaitForFinish: FState = TWSTATE_DONE');
  end;
end;

function TFpThreadWorkerItem.MaybeWaitForEvent(AnEvnt: PRTLEvent): Boolean;
var
  ExistingEvntPtr: PPRTLEvent;
begin
  Result := False;
  ExistingEvntPtr := InterlockedExchange(FWorkerItemEventPtr, EVENT_DONE_INDICATOR);
  if (ExistingEvntPtr <> nil) and (ExistingEvntPtr^ <> nil) and (ExistingEvntPtr^ <> AnEvnt) then begin    // Some one else is waiting
    RTLEventSetEvent(ExistingEvntPtr^);
    RTLEventWaitFor(AnEvnt);
    Result := True;
  end;
end;

procedure TFpThreadWorkerItem.WaitForFinish(AQueue: TFpThreadWorkerQueue;
  AWaitForExecInThread: Boolean);
var
  OldState: Cardinal;
  Evnt: PRTLEvent;
begin
  (*                  | True (wait for run in work thread)  | False (run in caller thread)
  TWSTATE_NEW         : mark TWSTATE_WAIT_WORKER => wait    : ~
  TWSTATE_RUNNING     : mark TWSTATE_WAIT_WORKER => wait    : mark TWSTATE_WAITING => wait
  TWSTATE_WAITING     : 2ndary wait call, leave to primary  : ~
  TWSTATE_WAIT_WORKER : 2ndary wait call, leave to primary  : ~
  TWSTATE_DONE        : KEEP (will be restored at exit)     : ~
  TWSTATE_CANCEL      : not allowed                         : ~
  *)

  if FState = TWSTATE_DONE then
    exit;

  Evnt := AQueue.GetRtlEvent;
  if MaybeWaitForPreviousWait(AQueue, @Evnt) then begin
    AQueue.FreeRtrEvent(Evnt);
    exit;
  end;

  (* - There was no other thread waiting
     - MaybeWaitForPreviousWait has set FWorkerItemEventPtr, therefore:
       => *** NO OTHER THREAD WILL ENTER THE CODE BELOW ***

     - We must set FState to  TWSTATE_WAIT___ or TWSTATE_CANCEL
       => in order for the WorkerThread to trigger the event
       => if the WorkerThread has gone TWSTATE_DONE the event will NOT be triggered
  *)

  if AWaitForExecInThread then begin
    OldState := InterlockedExchange(FState, TWSTATE_WAIT_WORKER);
    DebugLn(FLogGroup, '%s!%s WaitForFinish (WITH exe): %s "%s" StopRequested=%s', [dbgsThread, DbgSTime, dbgsWorkItemState(OldState), DebugText, dbgs(StopRequested)]);
    assert(not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER, TWSTATE_CANCEL]), 'TFpThreadWorkerItem.WaitForFinish: not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER, TWSTATE_CANCEL])');
    if (OldState in [TWSTATE_NEW, TWSTATE_RUNNING]) then begin
      DebugLnEnter(FLogGroup);
      RTLEventWaitFor(Evnt);
      DebugLnExit(FLogGroup, '%s!%s DONE WaitForFinish (WITH exe): "%s" StopRequested=%s', [dbgsThread, DbgSTime, DebugText, dbgs(StopRequested)]);
    end
    else begin
      assert(OldState = TWSTATE_DONE, 'TFpThreadWorkerItem.WaitForFinish: OldState = TWSTATE_DONE');
      FState := TWSTATE_DONE;
      if not MaybeWaitForEvent(Evnt) then
        ReadBarrier; // State must have advanced to TWSTATE_DONE;
    end;
  end
  else
  begin
    OldState := InterlockedExchange(FState, TWSTATE_WAITING);
    DebugLn(FLogGroup, '%s!%s WaitForFinish (NO exe): %s "%s" StopRequested=%s', [dbgsThread, DbgSTime, dbgsWorkItemState(OldState), DebugText, dbgs(StopRequested)]);
    assert(not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER, TWSTATE_CANCEL]), 'TFpThreadWorkerItem.WaitForFinish: not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER, TWSTATE_CANCEL])');
    if OldState = TWSTATE_NEW then begin
      DoExecute;

      InterLockedExchange(FState, TWSTATE_DONE);
      MaybeWaitForEvent(Evnt);
    end
    else
    if OldState = TWSTATE_RUNNING then begin
      DebugLnEnter(FLogGroup);
      RTLEventWaitFor(Evnt);
      DebugLnExit(FLogGroup, '%s!%s DONE WaitForFinish (NO exe): "%s" StopRequested=%s', [dbgsThread, DbgSTime, DebugText, dbgs(StopRequested)]);
    end
    else begin
      assert(OldState = TWSTATE_DONE, 'TFpThreadWorkerItem.WaitForFinish: OldState = TWSTATE_DONE');
      FState := TWSTATE_DONE;
      if not MaybeWaitForEvent(Evnt) then
        ReadBarrier;
    end;
  end;
  AQueue.FreeRtrEvent(Evnt);
  assert(FState = TWSTATE_DONE, 'TFpThreadWorkerItem.WaitForFinish: FState = TWSTATE_DONE');
end;

procedure TFpThreadWorkerItem.WaitForCancel(AQueue: TFpThreadWorkerQueue);
var
  OldState: Cardinal;
  Evnt: PRTLEvent;
begin
  //  TWSTATE_NEW         : mark TWSTATE_CANCEL
  //  TWSTATE_RUNNING     : mark TWSTATE_CANCEL, wait
  //  TWSTATE_WAITING     : impossible
  //  TWSTATE_WAIT_WORKER : impossible
  //  TWSTATE_DONE        : KEEP (will be restored at exit)
  //  TWSTATE_CANCEL      : KEEP

  FStopRequested := True;
  //RequestStop; // Can not call RequestStop / might change the state => must first call MaybeWaitForPreviousWait

  if FState = TWSTATE_DONE then
    exit;

  Evnt := AQueue.GetRtlEvent;
  if MaybeWaitForPreviousWait(AQueue, @Evnt) then begin
    AQueue.FreeRtrEvent(Evnt);
    exit;
  end;
  (* - There was no other thread waiting
     - MaybeWaitForPreviousWait has set FWorkerItemEventPtr, therefore:
       => *** NO OTHER THREAD WILL ENTER THE CODE BELOW ***
  *)


  OldState := InterLockedExchange(FState, TWSTATE_CANCEL); // Prevent thread form executing this
  Debugln(FLogGroup, '%s!%s WaitForCancel: %s "%s"', [dbgsThread, DbgSTime, dbgsWorkItemState(OldState), DebugText]);
  assert(not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER]), 'TFpThreadWorkerItem.WaitForCancel: not (OldState in [TWSTATE_WAITING, TWSTATE_WAIT_WORKER])');
  if OldState = TWSTATE_RUNNING then begin
    DebugLnEnter(FLogGroup);
    RTLEventWaitFor(Evnt);
    DebugLnExit(FLogGroup, '%s!%s DONE WaitForCancel: "%s"', [dbgsThread, DbgSTime, DebugText]);
  end
  else begin
    if OldState = TWSTATE_DONE then begin
      FState := TWSTATE_DONE;
    end;
    MaybeWaitForEvent(Evnt);
  end;
  AQueue.FreeRtrEvent(Evnt);
end;

procedure TFpThreadWorkerItem.Execute;
begin
  DoExecute;
  FState := TWSTATE_DONE;
end;

procedure TFpThreadWorkerItem.AddRef;
begin
  InterLockedIncrement(FRefCnt);
end;

procedure TFpThreadWorkerItem.DecRef;
begin
  if Self = nil then
    exit;
  if InterLockedDecrement(FRefCnt) <= 0 then
    DoFinished;
end;

function TFpThreadWorkerItem.RefCount: Integer;
begin
  Result := InterLockedExchangeAdd(FRefCnt, 0);
end;

procedure TFpThreadWorkerItem.RequestStop;
begin
  FStopRequested := True;
  InterlockedCompareExchange(FState, TWSTATE_CANCEL, TWSTATE_NEW); // if not running, then WaitForcancel
end;

function TFpThreadWorkerItem.DebugText: String;
begin
  Result := DbgSName(Self);
end;

{ TFpWorkerThread }

constructor TFpWorkerThread.Create(AQueue: TFpThreadWorkerQueue);
begin
  FQueue := AQueue;
  FreeOnTerminate := True;
  inherited Create(False);
end;

procedure TFpWorkerThread.Execute;
var
  WorkItem: TFpThreadWorkerItem;
  IsMarkedIdle: Boolean;
begin
  IsMarkedIdle := False;
  while not (Terminated or FQueue.ShutDown) do begin
    if (FQueue.PopItemTimeout(WorkItem, 0) <> wrSignaled) or
       (WorkItem = nil)
    then begin
      if not IsMarkedIdle then begin
        InterLockedIncrement(FQueue.FIdleThreadCount);
        IsMarkedIdle := True;
      end;
      if (FQueue.PopItem(WorkItem) <> wrSignaled) or
         (WorkItem = nil)
      then
        Continue;
    end;

    if WorkItem is TFpThreadWorkerTerminateItem then begin
      WorkItem.DecRef;
      if Terminated then // no need to check
        break;

      if FQueue.CurrentCount > FQueue.WantedCount then begin
        FQueue.ThreadMonitor.Enter;
        try
          if FQueue.ThreadCount > FQueue.WantedCount then
            break;
        finally
          FQueue.ThreadMonitor.Leave;
        end;
      end;
      Continue;
    end;

    if IsMarkedIdle then begin
      InterLockedDecrement(FQueue.FIdleThreadCount);
      IsMarkedIdle := False;
    end;
    try
      WorkItem.ExecuteInThread(Self);
    except
      on E: Exception do begin
        WorkItem.FError := E;
        DebugLn(FQueue.FLogGroup or DBG_ERRORS, '%s!%s Thread-Workitem raised exception: "%s" => %s: "%s"', [dbgsThread, DbgSTime, WorkItem.DebugText, E.Classname, E.Message]);
      end;
    end;
    try
      WorkItem.DecRef;
    except
      on E: Exception do
        debugln(FQueue.FLogGroup or DBG_ERRORS, '%s!%s Exception in WorkItem.DecRef: %s', [dbgsThread, DbgSTime, E.Message]);
    end;
  end;
  if IsMarkedIdle then
    InterLockedDecrement(FQueue.FIdleThreadCount);
  FQueue.RemoveThread(Self);
  debugln(FQueue.FLogGroup, '%s!%s WorkerThread-Exit', [dbgsThread, DbgSTime]);
end;

{ TFpThreadWorkerQueue.TFpDbgTypedFifoQueue }

function TFpThreadWorkerQueue.TFpDbgTypedFifoQueue.PushItem(
  const AItem: TFpThreadWorkerItem): Boolean;
begin
  if IsFull then
    Grow(Min(QueueSize, 100));
  Result := inherited PushItem(AItem);
  assert(Result, 'TFpThreadWorkerQueue.TFpDbgTypedFifoQueue.PushItem: Result');
end;

{ TFpThreadWorkerQueue }

function TFpThreadWorkerQueue.GetThreadCount: integer;
begin
  FThreadMonitor.Enter;
  try
    Result := FWorkerThreadList.Count;
  finally
    FThreadMonitor.Leave;
  end;
end;

function TFpThreadWorkerQueue.GetThreads(AnIndex: Integer): TThread;
begin
  if AnIndex >= FWorkerThreadList.Count then
    Result := nil
  else
    Result := FWorkerThreadList[AnIndex];
end;

function TFpThreadWorkerQueue.GetCurrentCount: Integer;
begin
  Result := InterLockedExchangeAdd(FCurrentCount, 0);
end;

function TFpThreadWorkerQueue.GetIdleThreadCount: integer;
begin
  Result := InterLockedExchangeAdd(FIdleThreadCount, 0);
end;

function TFpThreadWorkerQueue.GetWantedCount: Integer;
begin
  Result := InterLockedExchangeAdd(FWantedCount, 0);
end;

procedure TFpThreadWorkerQueue.SetThreadCount(AValue: integer);
var
  c: Integer;
begin
  FThreadMonitor.Enter;
  try
    InterLockedExchange(FWantedCount, AValue);
    FWantedCount := AValue;

    c := FWorkerThreadList.Count;
    if c > AValue then begin
      while c > AValue do begin
        dec(c);
        PushItem(TFpThreadWorkerTerminateItem.Create); // will terminate one thread, if no more work is to be done
      end;
      InterLockedExchange(FCurrentCount, FWorkerThreadList.Count);
    end

    else
    begin
      // increase
      FWorkerThreadList.Count := AValue;
      InterLockedExchange(FCurrentCount, AValue);
      while c < AValue do begin
        FWorkerThreadList[c] := TFpWorkerThread.Create(Self);
        inc(c);
      end;
    end;
  finally
    FThreadMonitor.Leave;
  end;
end;

function TFpThreadWorkerQueue.GetRtlEvent: PRTLEvent;
begin
  Result := InterlockedExchange(FMainWaitEvent, nil);
  if Result = nil then
    Result := RTLEventCreate;
end;

procedure TFpThreadWorkerQueue.FreeRtrEvent(AnEvent: PRTLEvent);
begin
  assert(AnEvent <> nil, 'TFpThreadWorkerQueue.FreeRtrEvent: AnEvent <> nil');
  RTLEventResetEvent(AnEvent);
  AnEvent := InterlockedExchange(FMainWaitEvent, AnEvent);
  if AnEvent <> nil then
    RTLEventDestroy(AnEvent);
end;

function TFpThreadWorkerQueue.RemoveThread(Item: TFpWorkerThread): Integer;
begin
  FThreadMonitor.Enter;
  try
    FWorkerThreadList.Remove(Item);
    InterLockedExchange(FCurrentCount, FWorkerThreadList.Count);
  finally
    FThreadMonitor.Leave;
  end;
end;

function TFpThreadWorkerQueue.CreateFifoQueue(AQueueDepth: Integer
  ): TLazTypedFifoQueue;
begin
  Result := TFpDbgTypedFifoQueue.create(AQueueDepth);
end;

constructor TFpThreadWorkerQueue.Create(AQueueDepth: Integer;
  PushTimeout: cardinal; PopTimeout: cardinal);
begin
  FLogGroup := FPDBG_THREADS;
  FThreadMonitor:=TLazMonitor.create;
  inherited create(AQueueDepth, PushTimeout, PopTimeout);
  FMainWaitEvent := RTLEventCreate;
  FWorkerThreadList := TFpWorkerThreadList.Create(False);
end;

destructor TFpThreadWorkerQueue.Destroy;
begin
  DoShutDown;
  TerminateAllThreads(True);

  inherited Destroy;
  FWorkerThreadList.Free;
  RTLeventdestroy(FMainWaitEvent);
  FThreadMonitor.Free;
end;

procedure TFpThreadWorkerQueue.Clear;
var
  WorkItem: TFpThreadWorkerItem;
begin
  Lock;
  try
    while TryPopItemUnprotected(WorkItem) do begin
      WorkItem.DoUnQueued;
      WorkItem.DecRef;
    end;
  finally
    Unlock;
  end;
end;

procedure TFpThreadWorkerQueue.TerminateAllThreads(AWait: Boolean);
var
  WorkItem: TFpThreadWorkerItem;
  i: Integer;
  mt: Boolean;
begin
  FThreadMonitor.Enter;
  Lock;
  try
    ThreadCount := 0;

    for i := 0 to FWorkerThreadList.Count - 1 do
      FWorkerThreadList[i].Terminate; // also signals that the queue is no longer valid

    while TryPopItemUnprotected(WorkItem) do begin
      WorkItem.RequestStop;
      WorkItem.DoUnQueued;
      WorkItem.DecRef;
    end;
  finally
    Unlock;
    FThreadMonitor.Leave;
  end;

  ThreadCount := 0;

  if AWait then begin
    // Wait for threads.
    i := 0;
    mt := MainThreadID = ThreadID;
    while CurrentCount > 0 do begin
      sleep(1);
      if mt then begin
        CheckSynchronize(1);
        if (i and 15) = 0 then
          DoProcessMessages;
      end;
      if (not ShutDown) and (TotalItemsPushed = TotalItemsPopped) then
        ThreadCount := 0; // Add more TFpThreadWorkerTerminateItem      inc(i);
      inc(i);
    end;
    // Free any TFpThreadWorkerTerminateItem items that were not picked up
    Clear;
  end;
end;

procedure TFpThreadWorkerQueue.DoProcessMessages;
begin
  if ProcessMessagesProc <> nil then
    ProcessMessagesProc();
end;

procedure TFpThreadWorkerQueue.PushItem(const AItem: TFpThreadWorkerItem);
begin
  DebugLn(FLogGroup and DBG_VERBOSE, '%s!%s PUSH WorkItem: "%s"', [dbgsThread, DbgSTime, AItem.DebugText]);
  AItem.FLogGroup := FLogGroup;
  AItem.AddRef;
  if ShutDown or (ThreadCount = 0) then begin
    AItem.DoUnQueued;
    AItem.DecRef;
    exit;
  end;
  inherited PushItem(AItem);
end;

procedure TFpThreadWorkerQueue.PushItemIdleOrRun(
  const AItem: TFpThreadWorkerItem);
var
  q: Boolean;
begin
  DebugLn(FLogGroup and DBG_VERBOSE, '%s!%s PUSHorRUN WorkItem: "%s"', [dbgsThread, DbgSTime, AItem.DebugText]);
  AItem.FLogGroup := FLogGroup;
  AItem.AddRef;
  if ShutDown or (ThreadCount = 0) then begin
    AItem.DoUnQueued;
    AItem.DecRef;
    exit;
  end;
  Lock;
  try
    q := IdleThreadCount > 0;
    if q then
      inherited TryPushItemUnprotected(AItem);
  finally
    Unlock;
  end;
  if not q then begin
    AItem.DoExecute;
    AItem.DecRef;
  end;
end;

procedure TFpThreadWorkerQueue.RemoveItem(const AItem: TFpThreadWorkerItem);
begin
  if AItem <> nil then
    AItem.WaitForCancel(Self);
end;

procedure TFpThreadWorkerQueue.WaitForItem(const AItem: TFpThreadWorkerItem;
  AWaitForExecInThread: Boolean);
begin
  AItem.WaitForFinish(Self, AWaitForExecInThread);
end;

initialization
  FPDBG_THREADS := DebugLogger.FindOrRegisterLogGroup('FPDBG_THREADS' {$IFDEF FPDBG_THREADS} , True {$ENDIF} );
  DBG_VERBOSE   := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE'   {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_ERRORS    := DebugLogger.FindOrRegisterLogGroup('DBG_ERRORS'    {$IFDEF DBG_ERRORS} , True {$ENDIF} );

finalization
  TheFpDbgGlobalWorkerQueue.Free;
end.


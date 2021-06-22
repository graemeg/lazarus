{ $Id: fpdbgwinclasses.pp 43410 2013-11-09 20:34:31Z martin $ }
{
 ---------------------------------------------------------------------------
 fpdbgwinclasses.pp  -  Native freepascal debugger
 ---------------------------------------------------------------------------

 This unit contains debugger classes for a native freepascal debugger

 ---------------------------------------------------------------------------

 @created(Sun Feb 9th WET 2014)
 @lastmod($Date: 2013-11-09 21:34:31 +0100 (za, 09 nov 2013) $)
 @author(Joost van der Sluis <joost@@cnoc.nl>)

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

(* About Windows debug events and breakpoints

  In a multi-threaded app, several threads can all reach breakpoints (the same
  or different breakpoints) at the same time.
  Windows will report each such breakpoint in an event on its own.

  When the first Breakpoint event is received, it is not possible to tell which
  other threads have also hit breakpoints.
  - A thread that has hit a breakpoint will have its Instruction-Pointer exactly
    one after the int3 break instruction.
  - But a thread could also be in that location as a result of a jump. (If the
    int3 replaced another 1 byte instruction)
  As a consequence: While all threads are stopped due to the first thread having
  hit a breakpoint, the Instruction pointer for the other threads may be
  wrong/unusable. It may need correction by -1, if that other thread also already
  hit a breakpoint. [1]

  If the debugger resumes after a breakpoint, it must temporarily remove the
  breakpoint, so the original instruction can be executed. (There is an option
  to do "out of place execution", but that is not implemented, and may not always
  be available)
  In order to execute the original instruction (while the int3 is removed):
  - The thread must do a single-step. This ensures it can not loop back and
    execute the instruction again, when it should hit the breakpoint again (after
    looping back)
  - Other threads must be suspended, so they can not run to/through the location
    of the breakpoint. Otherwise they would miss the breakpoint, as the int3 is
    removed,
    Other threads may/should execute, if they previously started a single step.

  The debugger may also skip a breakpoint (for the current thread) that is next
  to be hit, even if it had no event yet.
  The controller should have seen that the thread was at the breakpoint location,
  and should have triggered the actions for the breakpoint.

  If several events (such a breakpoints) have been raised at the same time (e.g.
  several breakpoints hit), then those events will be reported.
  => They will be reported, even if their thread got suspended in the meantime.
     (Since the event had already happened, no code execution happens in such a
     suspended thread.)
  However that means, if the debugger want thread A to do a single step over a
  (temp removed) breakpoint, then the next event for the debugger could be an
  already pending signal (other breakpoint or other event).
  In that case, the single step, may not yet have been executed, and will only
  happen if the debugger calls ContinueDebugEvent for the current event.
  But the debugger is not allowed to run the current thread, because the int3
  for thread A is still temporary removed.
  The debugger can run the thread, if it single steps it. Otherwise it can
  suspend it before calling ContinueDebugEvent (TODO if that does not work, it
  must revert to single step).

  The pending single step thread will remember its single step flag. So it just
  needs to be kept un-suspended for the next ContinueDebugEvent.

  [1] TODO (may or may not work):
  It may be possible to get the other events using Win10 DBG_REPLY_LATER
  (or setting the IP back to the breakpoint, and hit it again).
  Then while *all* threads are suspended, events can be collected.
  If no more events are coming in, the original thread can be resumed, triggering
  its breakpoint event again.
  All the event, would need to be collected, and each would need to be answered
  with a ContinueDebugEvent to windows.
  And only when all events are known AND the debugger has not yet called
  ContinueDebugEvent for the last event (so the target app is paused), then they
  would be reported (one by one) to the user.

*)
unit FpDbgWinClasses;

{$mode objfpc}{$H+}
{off $DEFINE DebuglnWinDebugEvents}

interface

uses
  Classes,
  SysUtils,
  Windows,
  FpDbgUtil,
  FpDbgClasses,
  process,
  FpDbgWinExtra,
  strutils,
  FpDbgInfo,
  FpDbgLoader, FpDbgDisasX86,
  DbgIntfBaseTypes, DbgIntfDebuggerBase,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, UTF8Process,
  FpDbgCommon, FpdMemoryTools, FpErrorMessages;

type

  TFpWinCtxFlags = (cfSkip, cfControl, cfFull);
  TFpContextChangeFlag = (ccfControl, ccfInteger);
  TFpContextChangeFlags = set of TFpContextChangeFlag;

  { TDbgWinThread }

  TDbgWinThread = class(TDbgThread)
  private
    FIsSuspended: Boolean;
    FIsSkippingBreakPoint: Boolean;
    FIsSkippingBreakPointAddress: TDBGPtr;
  protected
    FThreadContextChanged: boolean;
    FThreadContextChangeFlags: TFpContextChangeFlags;
    FCurrentContext: PFpContext; // FCurrentContext := Pointer((PtrUInt(@_UnAligendContext) + 15) and not PtrUInt($F));
    _UnAligendContext: TFpContext;
    _StoredContext: TFpContext;
    procedure LoadRegisterValues; override;
    function GetFpThreadContext(var AStorage: TFpContext; out ACtxPtr: PFpContext; ACtxFlags: TFpWinCtxFlags): Boolean;
    function SetFpThreadContext(ACtxPtr: PFpContext; ACtxFlags: TFpWinCtxFlags = cfSkip): Boolean;
  public
    procedure Suspend;
    procedure SuspendForStepOverBreakPoint;
    procedure Resume;
    procedure SetSingleStepOverBreakPoint;
    procedure EndSingleStepOverBreakPoint;
    procedure SetSingleStep;
    procedure ApplyWatchPoints(AWatchPointData: TFpWatchPointData); override;
    function DetectHardwareWatchpoint: Pointer; override;
    procedure BeforeContinue; override;
    function ResetInstructionPointerAfterBreakpoint: boolean; override;
    function ReadThreadState: boolean;

    procedure SetRegisterValue(AName: string; AValue: QWord); override;
    procedure StoreRegisters; override;
    procedure RestoreRegisters; override;
    function GetInstructionPointerRegisterValue: TDbgPtr; override;
    function GetStackBasePointerRegisterValue: TDbgPtr; override;
    function GetStackPointerRegisterValue: TDbgPtr; override;
    property Process;
  end;

  { TDbgWinProcess }

  TDbgWinProcess = class(TDbgProcess)
  private
    FInfo: TCreateProcessDebugInfo;
    FProcProcess: TProcessUTF8;
    FJustStarted, FTerminated: boolean;
    FBitness: TBitness;
    function GetFullProcessImageName(AProcessHandle: THandle): string;
    function GetModuleFileName(AModuleHandle: THandle): string;
    function GetProcFilename(AProcess: TDbgProcess; lpImageName: LPVOID; fUnicode: word; hFile: handle): string;
    procedure LogLastError;
  protected
    procedure AfterChangingInstructionCode(const ALocation: TDBGPtr; ACount: Integer); override;
    function GetHandle: THandle; override;
    function GetLastEventProcessIdentifier: THandle; override;
    procedure InitializeLoaders; override;
    function CreateWatchPointData: TFpWatchPointData; override;
  public
    constructor Create(const AFileName: string; const AProcessID, AThreadID: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager); override;
    destructor Destroy; override;

    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean; override;
    function WriteData(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean; override;
    function ReadString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: String): Boolean; override;
    function ReadWString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: WideString): Boolean; override;
    function CallParamDefaultLocation(AParamIdx: Integer): TFpDbgMemLocation; override;

    procedure Interrupt; // required by app/fpd
    function  HandleDebugEvent(const ADebugEvent: TDebugEvent): Boolean;

    class function StartInstance(AFileName: string; AParams, AnEnvironment: TStrings;
      AWorkingDirectory, AConsoleTty: string; AFlags: TStartInstanceFlags; AnOsClasses: TOSDbgClasses;
      AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess; override;
    class function AttachToInstance(AFileName: string; APid: Integer;
      AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess; override;

    class function isSupported(ATargetInfo: TTargetDescriptor): boolean; override;

    function Continue(AProcess: TDbgProcess; AThread: TDbgThread; SingleStep: boolean): boolean; override;
    function Detach(AProcess: TDbgProcess; AThread: TDbgThread): boolean; override;
    function WaitForDebugEvent(out ProcessIdentifier, ThreadIdentifier: THandle): boolean; override;
    function AnalyseDebugEvent(AThread: TDbgThread): TFPDEvent; override;
    function CreateThread(AthreadIdentifier: THandle; out IsMainThread: boolean): TDbgThread; override;

    procedure StartProcess(const AThreadID: DWORD; const AInfo: TCreateProcessDebugInfo);

    function Pause: boolean; override;

    procedure TerminateProcess; override;

    function AddrOffset: TDBGPtr; override;
    function  AddLib(const AInfo: TLoadDLLDebugInfo): TDbgLibrary;
    procedure RemoveLib(const AInfo: TUnloadDLLDebugInfo);
  end;
  TDbgWinProcessClass = class of TDbgWinProcess;

  { tDbgWinLibrary }

  tDbgWinLibrary = class(TDbgLibrary)
  private
    FInfo: TLoadDLLDebugInfo;
  protected
    procedure InitializeLoaders; override;
  public
    constructor Create(const AProcess: TDbgProcess; const ADefaultName: String;
      const AModuleHandle: THandle; const ABaseAddr: TDbgPtr; AInfo: TLoadDLLDebugInfo);
  end;


implementation

var
  DBG_VERBOSE, DBG_WARNINGS: PLazLoggerLogGroup;

{$ifdef cpux86_64}
const
  FLAG_TRACE_BIT = $100;
{$endif}

function dbgs(AnDbgEvent: DEBUG_EVENT): String; overload;
begin
  case AnDbgEvent.dwDebugEventCode of
    CREATE_PROCESS_DEBUG_EVENT: result := '>> CREATE_PROCESS_DEBUG_EVENT'
      + ' htproc:' + IntToStr(AnDbgEvent.CreateProcessInfo.hProcess);
    CREATE_THREAD_DEBUG_EVENT:  result := '>> CREATE_THREAD_DEBUG_EVENT'
      + ' hthread:' + IntToStr(AnDbgEvent.CreateThread.hThread)
      + ' start:' + dbghex(PtrUInt(AnDbgEvent.CreateThread.lpStartAddress));
    EXCEPTION_DEBUG_EVENT: begin
                                result := 'EXCEPTION_DEBUG_EVENT'
        + ' Code:' + dbghex(AnDbgEvent.Exception.ExceptionRecord.ExceptionCode)
        + ' Flags:' + dbghex(AnDbgEvent.Exception.ExceptionRecord.ExceptionFlags)
        + ' NumParam:' + IntToStr(AnDbgEvent.Exception.ExceptionRecord.NumberParameters);
      case AnDbgEvent.Exception.ExceptionRecord.ExceptionCode of
         EXCEPTION_ACCESS_VIOLATION:         Result := Result + ' EXCEPTION_ACCESS_VIOLATION';
         EXCEPTION_BREAKPOINT:               Result := Result + ' EXCEPTION_BREAKPOINT';
         STATUS_WX86_BREAKPOINT:             Result := Result + ' STATUS_WX86_BREAKPOINT';
         EXCEPTION_DATATYPE_MISALIGNMENT:    Result := Result + ' EXCEPTION_DATATYPE_MISALIGNMENT';
         EXCEPTION_SINGLE_STEP:              Result := Result + ' EXCEPTION_SINGLE_STEP';
         STATUS_WX86_SINGLE_STEP:            Result := Result + ' STATUS_WX86_SINGLE_STEP';
         EXCEPTION_ARRAY_BOUNDS_EXCEEDED:    Result := Result + ' EXCEPTION_ARRAY_BOUNDS_EXCEEDED';
         EXCEPTION_FLT_DENORMAL_OPERAND:     Result := Result + ' EXCEPTION_FLT_DENORMAL_OPERAND';
         EXCEPTION_FLT_DIVIDE_BY_ZERO:       Result := Result + ' EXCEPTION_FLT_DIVIDE_BY_ZERO';
         EXCEPTION_FLT_INEXACT_RESULT:       Result := Result + ' EXCEPTION_FLT_INEXACT_RESULT';
         EXCEPTION_FLT_INVALID_OPERATION:    Result := Result + ' EXCEPTION_FLT_INVALID_OPERATION';
         EXCEPTION_FLT_OVERFLOW:             Result := Result + ' EXCEPTION_FLT_OVERFLOW';
         EXCEPTION_FLT_STACK_CHECK:          Result := Result + ' EXCEPTION_FLT_STACK_CHECK';
         EXCEPTION_FLT_UNDERFLOW:            Result := Result + ' EXCEPTION_FLT_UNDERFLOW';
         EXCEPTION_INT_DIVIDE_BY_ZERO:       Result := Result + ' EXCEPTION_INT_DIVIDE_BY_ZERO';
         EXCEPTION_INT_OVERFLOW:             Result := Result + ' EXCEPTION_INT_OVERFLOW';
         EXCEPTION_INVALID_HANDLE:           Result := Result + ' EXCEPTION_INVALID_HANDLE';
         EXCEPTION_PRIV_INSTRUCTION:         Result := Result + ' EXCEPTION_PRIV_INSTRUCTION';
         EXCEPTION_NONCONTINUABLE_EXCEPTION: Result := Result + ' EXCEPTION_NONCONTINUABLE_EXCEPTION';
         EXCEPTION_NONCONTINUABLE:           Result := Result + ' EXCEPTION_NONCONTINUABLE';
         EXCEPTION_STACK_OVERFLOW:           Result := Result + ' EXCEPTION_STACK_OVERFLOW';
         EXCEPTION_INVALID_DISPOSITION:      Result := Result + ' EXCEPTION_INVALID_DISPOSITION';
         EXCEPTION_IN_PAGE_ERROR:            Result := Result + ' EXCEPTION_IN_PAGE_ERROR';
         EXCEPTION_ILLEGAL_INSTRUCTION:      Result := Result + ' EXCEPTION_ILLEGAL_INSTRUCTION';
         EXCEPTION_POSSIBLE_DEADLOCK:        Result := Result + ' EXCEPTION_POSSIBLE_DEADLOCK';
      end;
    end;
    EXIT_PROCESS_DEBUG_EVENT:   result := '<< EXIT_PROCESS_DEBUG_EVENT'
      + ' exitcode:' + IntToStr(AnDbgEvent.ExitProcess.dwExitCode);
    EXIT_THREAD_DEBUG_EVENT:    result := '<< EXIT_THREAD_DEBUG_EVENT'
      + ' exitcode:' + IntToStr(AnDbgEvent.ExitThread.dwExitCode);
    LOAD_DLL_DEBUG_EVENT:       result := '> LOAD_DLL_DEBUG_EVENT';
    OUTPUT_DEBUG_STRING_EVENT:  result := 'OUTPUT_DEBUG_STRING_EVENT';
    UNLOAD_DLL_DEBUG_EVENT:     result := '< UNLOAD_DLL_DEBUG_EVENT';
    RIP_EVENT:                  result := 'RIP_EVENT'
      + ' type:' + IntToStr(AnDbgEvent.RipInfo.dwType)
      + ' err:' + IntToStr(AnDbgEvent.RipInfo.dwError);
    else                        result := 'Code='+inttostr(AnDbgEvent.dwDebugEventCode);
  end;
  Result := format('EVENT for Process %d Thread %d: %s', [AnDbgEvent.dwProcessId, AnDbgEvent.dwThreadId, Result]);
end;


var
  DebugBreakAddr: Pointer = nil;
  _CreateRemoteThread: function(hProcess: THandle; lpThreadAttributes: Pointer; dwStackSize: DWORD; lpStartAddress: TFNThreadStartRoutine; lpParameter: Pointer; dwCreationFlags: DWORD; var lpThreadId: DWORD): THandle; stdcall = nil;
  _GetFinalPathNameByHandle: function(hFile: HANDLE; lpFilename:LPWSTR; cchFilePath, dwFlags: DWORD):DWORD; stdcall = nil;
  _QueryFullProcessImageName: function (hProcess:HANDLE; dwFlags: DWord; lpExeName:LPWSTR; var lpdwSize:DWORD):BOOL; stdcall = nil;
  _DebugActiveProcessStop: function (ProcessId:DWORD):BOOL; stdcall = nil;
  _DebugActiveProcess: function (ProcessId:DWORD):BOOL; stdcall = nil;
  _IsWow64Process: function (hProcess:HANDLE; WoW64Process: PBOOL):BOOL; stdcall = nil;
  _Wow64GetThreadContext: function (hThread: THandle; var   lpContext: WOW64_CONTEXT): BOOL; stdcall = nil;
  _Wow64SetThreadContext: function (hThread: THandle; const lpContext: WOW64_CONTEXT): BOOL; stdcall = nil;
  _DebugBreakProcess: function(Process:HANDLE): WINBOOL; stdcall = nil;

procedure LoadKernelEntryPoints;
var
  hMod: THandle;
begin
  hMod := GetModuleHandle(kernel32);
  DebugLn(DBG_WARNINGS and (hMod = 0), ['ERROR: Failed to get kernel32 handle']);
  if hMod = 0 then
    exit; //????

  DebugBreakAddr := GetProcAddress(hMod, 'DebugBreak');
  Pointer(_CreateRemoteThread) := GetProcAddress(hMod, 'CreateRemoteThread');
  Pointer(_QueryFullProcessImageName) := GetProcAddress(hMod, 'QueryFullProcessImageNameW'); // requires Vista
  Pointer(_DebugActiveProcessStop) := GetProcAddress(hMod, 'DebugActiveProcessStop');
  Pointer(_DebugActiveProcess) := GetProcAddress(hMod, 'DebugActiveProcess');
  Pointer(_GetFinalPathNameByHandle) := GetProcAddress(hMod, 'GetFinalPathNameByHandleW');
  Pointer(_DebugBreakProcess) := GetProcAddress(hMod, 'DebugBreakProcess');
  {$ifdef cpux86_64}
  Pointer(_IsWow64Process) := GetProcAddress(hMod, 'IsWow64Process');
  Pointer(_Wow64GetThreadContext) := GetProcAddress(hMod, 'Wow64GetThreadContext');
  Pointer(_Wow64SetThreadContext) := GetProcAddress(hMod, 'Wow64SetThreadContext');
  {$endif}

  DebugLn(DBG_WARNINGS and (DebugBreakAddr = nil), ['WARNING: Failed to get DebugBreakAddr']);
  DebugLn(DBG_WARNINGS and (_CreateRemoteThread = nil), ['WARNING: Failed to get CreateRemoteThread']);
  DebugLn(DBG_WARNINGS and (_QueryFullProcessImageName = nil), ['WARNING: Failed to get QueryFullProcessImageName']);
  DebugLn(DBG_WARNINGS and (_DebugActiveProcessStop = nil), ['WARNING: Failed to get DebugActiveProcessStop']);
  DebugLn(DBG_WARNINGS and (_DebugActiveProcess = nil), ['WARNING: Failed to get DebugActiveProcess']);
  DebugLn(DBG_WARNINGS and (_GetFinalPathNameByHandle = nil), ['WARNING: Failed to get GetFinalPathNameByHandle']);
  DebugLn(DBG_WARNINGS and (_DebugBreakProcess = nil), ['WARNING: Failed to get DebugBreakProcess']);
  {$ifdef cpux86_64}
  DebugLn(DBG_WARNINGS and (_IsWow64Process = nil), ['WARNING: Failed to get IsWow64Process']);
  DebugLn(DBG_WARNINGS and (_Wow64GetThreadContext = nil), ['WARNING: Failed to get Wow64GetThreadContext']);
  DebugLn(DBG_WARNINGS and (_Wow64SetThreadContext = nil), ['WARNING: Failed to get Wow64SetThreadContext']);
  {$endif}
end;

procedure TDbgWinProcess.LogLastError;
begin
  if not GotExitProcess then
    DebugLn(DBG_WARNINGS, 'FpDbg-ERROR: %s', [GetLastErrorText]);
end;

procedure TDbgWinProcess.AfterChangingInstructionCode(const ALocation: TDBGPtr;
  ACount: Integer);
begin
  inherited AfterChangingInstructionCode(ALocation, ACount);
  FlushInstructionCache(Handle, Pointer(PtrUInt(ALocation)), 1);
end;

function TDbgWinProcess.GetFullProcessImageName(AProcessHandle: THandle): string;
var
  u: UnicodeString;
  len: DWORD;
begin
  Result := '';
  if _QueryFullProcessImageName = nil then
    exit;
  len := MAX_PATH;
  SetLength(u, len);
  if _QueryFullProcessImageName(AProcessHandle, 0, @u[1], len)
  then begin
    SetLength(u, len);
    Result:=UTF8Encode(u);
  end
  else begin
    LogLastError;
  end;
end;

function TDbgWinProcess.GetModuleFileName(AModuleHandle: THandle): string;
var
  u: UnicodeString;
  s: string;
  len: Integer;
begin
  result := '';

  // GetFinalPathNameByHandle is only available on Windows Vista / Server 2008
  if assigned(_GetFinalPathNameByHandle) then begin
    SetLength(u, MAX_PATH+1);

    len := _GetFinalPathNameByHandle(AModuleHandle, @u[1], MAX_PATH, 0);
    s:='';
    if len > 0
    then begin
      // On some older Windows versions there's a bug in GetFinalPathNameByHandleW,
      // which leads to a trailing #0.
      if (u[len]=#0) then
        dec(len);
      SetLength(u, len);
      s:=UTF8Encode(u);
    end else begin
      u := '';
      LogLastError;
    end;
    // Remove the \\?\ prefix
    Delete(S,1,4);
    result := S;
  end;
end;

function TDbgWinProcess.GetProcFilename(AProcess: TDbgProcess; lpImageName: LPVOID; fUnicode: word; hFile: handle): string;
var
  NamePtr: TDbgPtr;
  S: String;
  W: WideString;
begin
  S := '';
  if (lpImageName<>nil) and AProcess.ReadOrdinal(TDbgPtr(lpImageName), NamePtr)
  then begin
    if fUnicode <> 0
    then begin
      if AProcess.ReadWString(NamePtr, MAX_PATH, W)
      then S := W;
    end
    else begin
      AProcess.ReadString(NamePtr, MAX_PATH, S);
    end;
  end;

  if S = ''
  then begin
    if hFile=0 then
      S := GetFullProcessImageName(AProcess.Handle)
    else
      S := GetModuleFileName(hFile);
  end;
  result := S;
end;

{ tDbgWinLibrary }

procedure tDbgWinLibrary.InitializeLoaders;
begin
  TDbgImageLoaderLibrary.Create(FInfo.hFile, nil, TDBGPtr(FInfo.lpBaseOfDll)).AddToLoaderList(LoaderList);
end;

constructor tDbgWinLibrary.Create(const AProcess: TDbgProcess;
  const ADefaultName: String; const AModuleHandle: THandle;
  const ABaseAddr: TDbgPtr; AInfo: TLoadDLLDebugInfo);
var
  S: String;
begin
  inherited Create(AProcess, ADefaultName, AModuleHandle, ABaseAddr);
  FInfo := AInfo;

  s := TDbgWinProcess(AProcess).GetProcFilename(AProcess, AInfo.lpImageName, AInfo.fUnicode, AInfo.hFile);
  if s <> ''
  then SetFileName(s);

  LoadInfo;
end;

{ TDbgWinProcess }

function TDbgWinProcess.GetHandle: THandle;
begin
  Result:=FInfo.hProcess;
end;

function TDbgWinProcess.GetLastEventProcessIdentifier: THandle;
begin
  Result:= MDebugEvent.LoadDll.hFile;
end;

procedure TDbgWinProcess.InitializeLoaders;
begin
  TDbgImageLoader.Create(FInfo.hFile).AddToLoaderList(LoaderList);
end;

function TDbgWinProcess.CreateWatchPointData: TFpWatchPointData;
begin
  Result := TFpIntelWatchPointData.Create;
end;

constructor TDbgWinProcess.Create(const AFileName: string; const AProcessID,
  AThreadID: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager
  );
begin
  {$ifdef cpui386}
  FBitness := b32;
  {$else}
  FBitness := b64;
  {$endif}
  inherited Create(AFileName, AProcessID, AThreadID, AnOsClasses, AMemManager);
end;

destructor TDbgWinProcess.Destroy;
begin
  FInfo.hProcess:=0;
  FProcProcess.Free;
  inherited Destroy;
end;

function TDbgWinProcess.ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean;
var
  BytesRead: PtrUInt;
begin
  Result := ReadProcessMemory(Handle, Pointer(PtrUInt(AAdress)), @AData, ASize, BytesRead) and (BytesRead = ASize);

  if not Result then LogLastError;
  MaskBreakpointsInReadData(AAdress, ASize, AData);
end;

function TDbgWinProcess.WriteData(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean;
var
  BytesWritten: PtrUInt;
begin
  Result := WriteProcessMemory(Handle, Pointer(PtrUInt(AAdress)), @AData, ASize, BytesWritten) and (BytesWritten = ASize);

  if not Result then LogLastError;
end;

function TDbgWinProcess.ReadString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: String): Boolean;
var
  BytesRead: PtrUInt;
  buf: array of Char;
begin
  AData := '';
  SetLength(buf, AMaxSize + 1);
  Result := ReadProcessMemory(Handle, Pointer(PtrUInt(AAdress)), @Buf[0], AMaxSize, BytesRead);
  if not Result then Exit;
  if BytesRead < AMaxSize
  then Buf[BytesRead] := #0
  else Buf[AMaxSize] := #0;
  AData := PChar(@Buf[0]);
end;

function TDbgWinProcess.ReadWString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: WideString): Boolean;
var
  BytesRead: PtrUInt;
  buf: array of WChar;
begin
  AData := '';
  SetLength(buf, AMaxSize + 1);
  Result := ReadProcessMemory(Handle, Pointer(PtrUInt(AAdress)), @Buf[0], SizeOf(WChar) * AMaxSize, BytesRead);
  if not Result then Exit;
  BytesRead := BytesRead div SizeOf(WChar);
  if BytesRead < AMaxSize
  then Buf[BytesRead] := #0
  else Buf[AMaxSize] := #0;
  AData := PWChar(@Buf[0]);
end;

function TDbgWinProcess.CallParamDefaultLocation(AParamIdx: Integer
  ): TFpDbgMemLocation;
begin
  Result := InvalidLoc;
  case Mode of
    dm32: case AParamIdx of
       -1: Result := RegisterLoc(0); // EAX
        0: Result := RegisterLoc(0); // EAX
        1: Result := RegisterLoc(2); // EDX
        2: Result := RegisterLoc(1); // ECX
      end;
    dm64: case AParamIdx of
       -1: Result := RegisterLoc(0); // RAX
        0: Result := RegisterLoc(2); // RCX
        1: Result := RegisterLoc(1); // RDX
        2: Result := RegisterLoc(8); // R8
      end;
  end;
end;

procedure TDbgWinProcess.Interrupt;
var
  _UC: record
    C: TContext;
    D: array[1..16] of Byte;
  end;
  Context: PContext;
begin
  // Interrupting is implemented by suspending the thread and set DB0 to the
  // (to be) executed EIP. When the thread is resumed, it will generate a break
  // Single stepping doesn't work in all cases.

  // A context needs to be aligned to 16 bytes. Unfortunately, the compiler has
  // no directive for this, so align it somewhere in our "reserved" memory
  Context := AlignPtr(@_UC, $10);
  SuspendThread(FInfo.hThread);
  try
    Context^.ContextFlags := CONTEXT_CONTROL or CONTEXT_DEBUG_REGISTERS;
    if not GetThreadContext(FInfo.hThread, Context^)
    then begin
      DebugLn(DBG_WARNINGS, 'Proces %u interrupt: Unable to get context', [ProcessID]);
      Exit;
    end;

    Context^.ContextFlags := CONTEXT_DEBUG_REGISTERS;
    {$ifdef cpui386}
    Context^.Dr0 := Context^.Eip;
    {$else}
    Context^.Dr0 := Context^.Rip;
    {$endif}
    Context^.Dr7 := (Context^.Dr7 and $FFF0FFFF) or $1;

    if not SetThreadContext(FInfo.hThread, Context^)
    then begin
      DebugLn(DBG_WARNINGS, 'Proces %u interrupt: Unable to set context', [ProcessID]);
      Exit;
    end;
  finally
    ResumeTHread(FInfo.hThread);
  end;
end;

{ ------------------------------------------------------------------
  HandleDebugEvent

  Result: True if the event was triggered internally
          The callee should continue the process
  ------------------------------------------------------------------ }
function TDbgWinProcess.HandleDebugEvent(const ADebugEvent: TDebugEvent): Boolean;
begin
  Result := False;
  case ADebugEvent.dwDebugEventCode of
    EXIT_THREAD_DEBUG_EVENT: begin
      // The thread event will be freed later, may still be used
      // will be freed, in "TDbgWinProcess.Continue"
      // This relies on the thread being removed, to be the same as FCurrentThread in FPDbgController
      RemoveThread(ADebugEvent.dwThreadId);
    end;
    LOAD_DLL_DEBUG_EVENT: begin
      AddLib(ADebugEvent.LoadDll);
    end;
    UNLOAD_DLL_DEBUG_EVENT: begin
      RemoveLib(ADebugEvent.UnloadDll);
    end;
  end;
end;

class function TDbgWinProcess.StartInstance(AFileName: string; AParams,
  AnEnvironment: TStrings; AWorkingDirectory, AConsoleTty: string;
  AFlags: TStartInstanceFlags; AnOsClasses: TOSDbgClasses;
  AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess;
var
  AProcess: TProcessUTF8;
  LastErr: Integer;
begin
  result := nil;
  AProcess := TProcessUTF8.Create(nil);
  try
    // To debug sub-processes, this needs to be poDebugProcess
    AProcess.Options:=[poDebugProcess, poDebugOnlyThisProcess, poNewProcessGroup];
    if siForceNewConsole in AFlags then
      AProcess.Options:=AProcess.Options+[poNewConsole];
    AProcess.Executable:=AFilename;
    AProcess.Parameters:=AParams;
    AProcess.Environment:=AnEnvironment;
    AProcess.CurrentDirectory:=AWorkingDirectory;
    AProcess.Execute;

    result := TDbgWinProcess.Create(AFileName, AProcess.ProcessID, AProcess.ThreadID, AnOsClasses, AMemManager);
    TDbgWinProcess(result).FProcProcess := AProcess;
  except
    on E: Exception do
    begin
      LastErr := Integer(GetLastError);
      DebugLn(DBG_WARNINGS, 'Failed to start process "%s". Errormessage: "%s %d".',[AFileName, E.Message, LastErr]);
      {$ifdef cpui386}
      if (E is EProcess) and (GetLastError=50) then
      begin
        AnError := CreateError(fpErrCreateProcess, [AFileName, LastErr, E.Message, 'Note that on Windows it is not possible to debug a 64-bit application with a 32-bit debugger.'])
      end
      else
      {$endif i386}
      AnError := CreateError(fpErrCreateProcess, [AFileName, LastErr, E.Message, '']);
      AProcess.Free;
    end;
  end;
end;

class function TDbgWinProcess.AttachToInstance(AFileName: string;
  APid: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager; out
  AnError: TFpError): TDbgProcess;
var
  LastErr: Integer;
begin
  Result := nil;
  if _DebugActiveProcess = nil then begin
    AnError := CreateError(fpErrAttachProcess, [AFileName, 0, 'API unavailable', '']);
    exit;
  end;
  if not _DebugActiveProcess(APid) then begin
    LastErr := Integer(GetLastError);
    AnError := CreateError(fpErrAttachProcess, [AFileName, LastErr, GetLastErrorText(LastErr), '']);
    exit;
  end;

  result := TDbgWinProcess.Create(AFileName, APid, 0, AnOsClasses, AMemManager);
  // TODO: change the filename to the actual exe-filename. Load the correct dwarf info
end;

class function TDbgWinProcess.isSupported(ATargetInfo: TTargetDescriptor
  ): boolean;
begin
  result := (ATargetInfo.OS = osWindows) and
            (ATargetInfo.machineType in [mt386, mtX86_64]);
end;

function TDbgWinProcess.Continue(AProcess: TDbgProcess; AThread: TDbgThread;
  SingleStep: boolean): boolean;

  function HasThreadInSkippingBreak: Boolean;
  var
    t: TDbgThread;
  begin
    Result := False;
    for t in FThreadMap do
      if TDbgWinThread(t).FIsSkippingBreakPoint then begin
        Result := True;
        break;
      end;
  end;

var
  EventThread, t: TDbgThread;
begin
debugln(['TDbgWinProcess.Continue ',SingleStep]);
  if assigned(AThread) and not FThreadMap.HasId(AThread.ID) then begin
    AThread := nil;
  end;

  (* In case a thread needs to single-step over a (temp-removed) breakpoint,
     other events (from suspended threads, if the event is already triggered)
     can be received. THe single step must be continued until finished.
     This may mean suspending the current thread.
  *)

  if AProcess.GetThread(MDebugEvent.dwThreadId, EventThread) then begin
    if EventThread = AThread then
      EventThread.NextIsSingleStep := SingleStep;

    if HasInsertedBreakInstructionAtLocation(EventThread.GetInstructionPointerRegisterValue) then begin
debugln(['## skip brkpoint ',AThread= EventThread, '  iss ',EventThread.NextIsSingleStep]);
      TDbgWinThread(EventThread).SetSingleStepOverBreakPoint;

      for t in FThreadMap do
        TDbgWinThread(t).SuspendForStepOverBreakPoint;
    end
    else begin
      // EventThread does not need to skip a breakpoint;
      if (EventThread = AThread) and (SingleStep) then
        TDbgWinThread(EventThread).SetSingleStep;

      if HasThreadInSkippingBreak then begin
debugln(['## skip brkpoint (others only) ',AThread= EventThread, '  iss ',EventThread.NextIsSingleStep]);
        // But other threads are still skipping
        for t in FThreadMap do
          if not (SingleStep and (t = AThread) and   // allow athread to single-step
                  not TDbgWinThread(t).FIsSkippingBreakPoint  // already single stepping AND needs  TempRemoveBreakInstructionCode
                 )
          then
            TDbgWinThread(t).SuspendForStepOverBreakPoint;
      end;
    end;

    if (AThread = EventThread) or (assigned(AThread) and TDbgWinThread(AThread).FIsSuspended) then
      AThread := nil; // Already handled, or suspended
  end

  else begin // EventThread is gone
    if HasThreadInSkippingBreak then begin
debugln(['## skip brkpoint (others only) ']);
      for t in FThreadMap do
        if not (SingleStep and (t = AThread) and   // allow athread to single-step
                not TDbgWinThread(t).FIsSkippingBreakPoint  // already single stepping AND needs  TempRemoveBreakInstructionCode
               )
        then
          TDbgWinThread(t).SuspendForStepOverBreakPoint;
    end;

    if assigned(AThread) and (TDbgWinThread(AThread).FIsSuspended) then
      AThread := nil; // no need for singlestep yet
  end;

  if assigned(AThread) then
  begin
    AThread.NextIsSingleStep:=SingleStep;
    if SingleStep then
      TDbgWinThread(AThread).SetSingleStep;
  end;
  AProcess.ThreadsBeforeContinue;
if AThread<>nil then debugln(['## ath.iss ',AThread.NextIsSingleStep]);

  if MDebugEvent.dwDebugEventCode = EXCEPTION_DEBUG_EVENT then
    case MDebugEvent.Exception.ExceptionRecord.ExceptionCode of
     EXCEPTION_BREAKPOINT, STATUS_WX86_BREAKPOINT,
     EXCEPTION_SINGLE_STEP, STATUS_WX86_SINGLE_STEP: begin
       result := Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
     end
    else
      result := Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_EXCEPTION_NOT_HANDLED);
    end
  else
    result := Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
  DebugLn(not Result, 'ContinueDebugEvent failed: %d', [Windows.GetLastError]);
  result := true;
end;

function TDbgWinProcess.Detach(AProcess: TDbgProcess; AThread: TDbgThread
  ): boolean;
var
  t: TDbgWinThread;
  PendingDebugEvent: TDebugEvent;
begin
  Result := _DebugActiveProcessStop <> nil;
  if not Result then
    exit;

  RemoveAllBreakPoints;

  // Collect all pending events // Deal with any breakpoint/int3 hit
  if not GetThread(MDebugEvent.dwThreadId, TDbgThread(AThread)) then begin
    assert(False, 'TDbgWinProcess.Detach: Missing thread');
    TDbgThread(AThread) := AddThread(MDebugEvent.dwThreadId);
  end;

  for TDbgThread(t) in FThreadMap do
    if not t.ID = MDebugEvent.dwThreadId then
      t.Suspend;

  TDbgWinThread(AThread).SetSingleStep;
  Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
  while Windows.WaitForDebugEvent(PendingDebugEvent, 1) do begin
    if PendingDebugEvent.dwThreadId = MDebugEvent.dwThreadId then
      break;
    case PendingDebugEvent.dwDebugEventCode of
      CREATE_PROCESS_DEBUG_EVENT: begin
          if PendingDebugEvent.CreateProcessInfo.hFile <> 0 then
            CloseHandle(PendingDebugEvent.CreateProcessInfo.hFile);
          _DebugActiveProcessStop(PendingDebugEvent.dwProcessId);
        end;
      EXCEPTION_DEBUG_EVENT:
        case PendingDebugEvent.Exception.ExceptionRecord.ExceptionCode of
          EXCEPTION_BREAKPOINT, STATUS_WX86_BREAKPOINT: begin
            if not GetThread(PendingDebugEvent.dwThreadId, TDbgThread(t)) then
              TDbgThread(t) := AddThread(PendingDebugEvent.dwThreadId);
            t.CheckAndResetInstructionPointerAfterBreakpoint;
          end;
        end;
    end;
    Windows.ContinueDebugEvent(PendingDebugEvent.dwProcessId, PendingDebugEvent.dwThreadId, DBG_CONTINUE);
  end;

  for TDbgThread(t) in FThreadMap do
    t.Resume;

  Result := _DebugActiveProcessStop(ProcessID);
//  Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
end;

function TDbgWinProcess.WaitForDebugEvent(out ProcessIdentifier, ThreadIdentifier: THandle): boolean;
var
  t: TDbgWinThread;
  Done: Boolean;
begin
  repeat
    Done := True;
    result := Windows.WaitForDebugEvent(MDebugEvent, INFINITE);
    DebugLn(not Result, 'WaitForDebugEvent failed: %d', [Windows.GetLastError]);

    if Result and FTerminated and (MDebugEvent.dwDebugEventCode <> EXIT_PROCESS_DEBUG_EVENT)
       and (MDebugEvent.dwDebugEventCode <> EXIT_THREAD_DEBUG_EVENT)
    then begin
      // Wait for the terminate event // Do not report any queued breakpoints
      DebugLn(['Terimating... Skipping event: ', dbgs(MDebugEvent)]);
      for TDbgThread(t) in FThreadMap do
        t.Suspend;
      Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
      Done := False;
    end

    else
    if Result and (MDebugEvent.dwProcessId <> Self.ProcessID) then begin
      (* Some events are not processed yet anyway.
         They never reach AnalyseDebugEvent, so deal with them here
      *)
      case MDebugEvent.dwDebugEventCode of
        CREATE_PROCESS_DEBUG_EVENT: begin
            //child process: ignore
            // we currently do not use the file handle => close it
            if MDebugEvent.CreateProcessInfo.hFile <> 0 then
              if not CloseHandle(MDebugEvent.CreateProcessInfo.hFile) then
                debugln([DBG_WARNINGS, 'Failed to close new process file handle: ',GetLastErrorText]);
            if _DebugActiveProcessStop <> nil then
              if not _DebugActiveProcessStop(MDebugEvent.dwProcessId) then
                debugln([DBG_WARNINGS, 'Failed to detach: ',GetLastErrorText]);

            Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
            Done := False;
          end;
        EXIT_PROCESS_DEBUG_EVENT: begin
            // Should never be here, since it detached
            Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
            Done := False;
          end;
      end;
    end;
  until Done;

  ProcessIdentifier:=MDebugEvent.dwProcessId;
  ThreadIdentifier:=MDebugEvent.dwThreadId;
  {$IFDEF DebuglnWinDebugEvents}
  DebugLn([dbgs(MDebugEvent), ' ', Result]);
  for TDbgThread(t) in FThreadMap do begin
  if t.ReadThreadState then
    DebugLn('Thr.Id:%d %x  SSTep %s EF %s     DR6:%x  DR7:%x  WP:%x  RegAcc: %d,  SStep: %d  Task: %d, ExcBrk: %d', [t.ID, t.GetInstructionPointerRegisterValue, dbgs(t.FCurrentContext^.def.EFlags and FLAG_TRACE_BIT), dbghex(t.FCurrentContext^.def.EFlags), t.FCurrentContext^.def.Dr6, t.FCurrentContext^.def.Dr7, t.FCurrentContext^.def.Dr6 and 15, t.FCurrentContext^.def.Dr6 and (1<< 13), t.FCurrentContext^.def.Dr6 and (1<< 14), t.FCurrentContext^.def.Dr6 and (1<< 15), t.FCurrentContext^.def.Dr6 and (1<< 16)]);
  end;
  {$ENDIF}

  RestoreTempBreakInstructionCodes;
  if not FTerminated then
    for TDbgThread(t) in FThreadMap do
      t.Resume;

  // Should be done in AnalyseDebugEvent, but that is not called for forked processes
  if (MDebugEvent.dwDebugEventCode = CREATE_PROCESS_DEBUG_EVENT) and
     (MDebugEvent.dwProcessId <> ProcessID) and
     (MDebugEvent.CreateProcessInfo.hFile <> 0)
  then begin
    CloseHandle(MDebugEvent.CreateProcessInfo.hFile);
    MDebugEvent.CreateProcessInfo.hFile := 0;
  end;
end;

function TDbgWinProcess.AnalyseDebugEvent(AThread: TDbgThread): TFPDEvent;

  procedure HandleException(const AEvent: TDebugEvent; out InterceptAtFirstChance: Boolean);
  const
    PARAMCOLS = 12 - SizeOf(Pointer);
  var
    Info0: QWORD;
    Info1: QWORD;
    Info1Str: String;
    ExInfo32: TExceptionDebugInfo32 absolute AEvent.Exception;
    ExInfo64: TExceptionDebugInfo64 absolute AEvent.Exception;
  begin
    InterceptAtFirstChance := True;
    // Kept the debug-output as comments, since they provide deeper information
    // on how to interprete the exception-information.
    {
    if AEvent.Exception.dwFirstChance = 0
    then DebugLn(DBG_VERBOSE, 'Exception: ')
    else DebugLn(DBG_VERBOSE, 'First chance exception: ');
    }
    // in both 32 and 64 case is the exceptioncode the first, so no difference
    case AEvent.Exception.ExceptionRecord.ExceptionCode of
      EXCEPTION_ACCESS_VIOLATION         : ExceptionClass:='ACCESS VIOLATION';
      EXCEPTION_ARRAY_BOUNDS_EXCEEDED    : ExceptionClass:='ARRAY BOUNDS EXCEEDED';
      EXCEPTION_BREAKPOINT               : ExceptionClass:='BREAKPOINT';  // should never be here
      EXCEPTION_DATATYPE_MISALIGNMENT    : ExceptionClass:='DATATYPE MISALIGNMENT';
      EXCEPTION_FLT_DENORMAL_OPERAND     : ExceptionClass:='FLT DENORMAL OPERAND';
      EXCEPTION_FLT_DIVIDE_BY_ZERO       : ExceptionClass:='FLT DIVIDE BY ZERO';
      EXCEPTION_FLT_INEXACT_RESULT       : ExceptionClass:='FLT INEXACT RESULT';
      EXCEPTION_FLT_INVALID_OPERATION    : ExceptionClass:='FLT INVALID OPERATION';
      EXCEPTION_FLT_OVERFLOW             : ExceptionClass:='FLT OVERFLOW';
      EXCEPTION_FLT_STACK_CHECK          : ExceptionClass:='FLT STACK CHECK';
      EXCEPTION_FLT_UNDERFLOW            : ExceptionClass:='FLT UNDERFLOW';
      EXCEPTION_ILLEGAL_INSTRUCTION      : ExceptionClass:='ILLEGAL INSTRUCTION';
      EXCEPTION_IN_PAGE_ERROR            : ExceptionClass:='IN PAGE ERROR';
      EXCEPTION_INT_DIVIDE_BY_ZERO       : ExceptionClass:='INT DIVIDE BY ZERO';
      EXCEPTION_INT_OVERFLOW             : ExceptionClass:='INT OVERFLOW';
      EXCEPTION_INVALID_DISPOSITION      : ExceptionClass:='INVALID DISPOSITION';
      EXCEPTION_INVALID_HANDLE           : ExceptionClass:='INVALID HANDLE';
      EXCEPTION_NONCONTINUABLE_EXCEPTION : ExceptionClass:='NONCONTINUABLE EXCEPTION';
      EXCEPTION_POSSIBLE_DEADLOCK        : ExceptionClass:='POSSIBLE DEADLOCK';
      EXCEPTION_PRIV_INSTRUCTION         : ExceptionClass:='PRIV INSTRUCTION';
      EXCEPTION_SINGLE_STEP              : ExceptionClass:='SINGLE STEP';    // should never be here
      EXCEPTION_STACK_OVERFLOW           : ExceptionClass:='STACK OVERFLOW';

      // add some status - don't know if we can get them here
      {
      DBG_EXCEPTION_NOT_HANDLED          : DebugLn(DBG_VERBOSE, 'DBG_EXCEPTION_NOT_HANDLED');
      STATUS_GUARD_PAGE_VIOLATION        : DebugLn(DBG_VERBOSE, 'STATUS_GUARD_PAGE_VIOLATION');
      STATUS_NO_MEMORY                   : DebugLn(DBG_VERBOSE, 'STATUS_NO_MEMORY');
      STATUS_CONTROL_C_EXIT              : DebugLn(DBG_VERBOSE, 'STATUS_CONTROL_C_EXIT');
      STATUS_FLOAT_MULTIPLE_FAULTS       : DebugLn(DBG_VERBOSE, 'STATUS_FLOAT_MULTIPLE_FAULTS');
      STATUS_FLOAT_MULTIPLE_TRAPS        : DebugLn(DBG_VERBOSE, 'STATUS_FLOAT_MULTIPLE_TRAPS');
      STATUS_REG_NAT_CONSUMPTION         : DebugLn(DBG_VERBOSE, 'STATUS_REG_NAT_CONSUMPTION');
      STATUS_SXS_EARLY_DEACTIVATION      : DebugLn(DBG_VERBOSE, 'STATUS_SXS_EARLY_DEACTIVATION');
      STATUS_SXS_INVALID_DEACTIVATION    : DebugLn(DBG_VERBOSE, 'STATUS_SXS_INVALID_DEACTIVATION');
      }
    else
      InterceptAtFirstChance := False;
      ExceptionClass := 'Unknown exception code $' + IntToHex(ExInfo32.ExceptionRecord.ExceptionCode, 8);
      {
      DebugLn(DBG_VERBOSE, ' [');
      case ExInfo32.ExceptionRecord.ExceptionCode and $C0000000 of
        STATUS_SEVERITY_SUCCESS       : DebugLn(DBG_VERBOSE, 'SEVERITY_ERROR');
        STATUS_SEVERITY_INFORMATIONAL : DebugLn(DBG_VERBOSE, 'SEVERITY_ERROR');
        STATUS_SEVERITY_WARNING       : DebugLn(DBG_VERBOSE, 'SEVERITY_WARNING');
        STATUS_SEVERITY_ERROR         : DebugLn(DBG_VERBOSE, 'SEVERITY_ERROR');
      end;
      if ExInfo32.ExceptionRecord.ExceptionCode and $20000000 <> 0
      then DebugLn (DBG_VERBOSE, ' Customer');
      if ExInfo32.ExceptionRecord.ExceptionCode and $10000000 <> 0
      then DebugLn (DBG_VERBOSE, ' Reserved');
      case (ExInfo32.ExceptionRecord.ExceptionCode and $0FFF0000) shr 16 of
        FACILITY_DEBUGGER            : DebugLn(DBG_VERBOSE, 'FACILITY_DEBUGGER');
        FACILITY_RPC_RUNTIME         : DebugLn(DBG_VERBOSE, 'FACILITY_RPC_RUNTIME');
        FACILITY_RPC_STUBS           : DebugLn(DBG_VERBOSE, 'FACILITY_RPC_STUBS');
        FACILITY_IO_ERROR_CODE       : DebugLn(DBG_VERBOSE, 'FACILITY_IO_ERROR_CODE');
        FACILITY_TERMINAL_SERVER     : DebugLn(DBG_VERBOSE, 'FACILITY_TERMINAL_SERVER');
        FACILITY_USB_ERROR_CODE      : DebugLn(DBG_VERBOSE, 'FACILITY_USB_ERROR_CODE');
        FACILITY_HID_ERROR_CODE      : DebugLn(DBG_VERBOSE, 'FACILITY_HID_ERROR_CODE');
        FACILITY_FIREWIRE_ERROR_CODE : DebugLn(DBG_VERBOSE, 'FACILITY_FIREWIRE_ERROR_CODE');
        FACILITY_CLUSTER_ERROR_CODE  : DebugLn(DBG_VERBOSE, 'FACILITY_CLUSTER_ERROR_CODE');
        FACILITY_ACPI_ERROR_CODE     : DebugLn(DBG_VERBOSE, 'FACILITY_ACPI_ERROR_CODE');
        FACILITY_SXS_ERROR_CODE      : DebugLn(DBG_VERBOSE, 'FACILITY_SXS_ERROR_CODE');
      else
        DebugLn(DBG_VERBOSE, ' Facility: $', IntToHex((ExInfo32.ExceptionRecord.ExceptionCode and $0FFF0000) shr 16, 3));
      end;
      DebugLn(DBG_VERBOSE, ' Code: $', IntToHex((ExInfo32.ExceptionRecord.ExceptionCode and $0000FFFF), 4));
      }
    end;
    ExceptionClass:='External: '+ExceptionClass;
    ExceptionMessage:='';
    {
    if GMode = dm32
    then Info0 := PtrUInt(ExInfo32.ExceptionRecord.ExceptionAddress)
    else Info0 := PtrUInt(ExInfo64.ExceptionRecord.ExceptionAddress);
    DebugLn(DBG_VERBOSE, ' at: ', FormatAddress(Info0));
    DebugLn(DBG_VERBOSE, ' Flags:', Format('%x', [AEvent.Exception.ExceptionRecord.ExceptionFlags]), ' [');

    if AEvent.Exception.ExceptionRecord.ExceptionFlags = 0
    then DebugLn(DBG_VERBOSE, 'Continuable')
    else DebugLn(DBG_VERBOSE, 'Not continuable');
    DebugLn(DBG_VERBOSE, ']');
    if GMode = dm32
    then DebugLn(DBG_VERBOSE, ' ParamCount:', IntToStr(ExInfo32.ExceptionRecord.NumberParameters))
    else DebugLn(DBG_VERBOSE, ' ParamCount:', IntToStr(ExInfo64.ExceptionRecord.NumberParameters));
    }
    case AEvent.Exception.ExceptionRecord.ExceptionCode of
      EXCEPTION_ACCESS_VIOLATION: begin
        if GMode = dm32
        then begin
          Info0 := ExInfo32.ExceptionRecord.ExceptionInformation[0];
          Info1 := ExInfo32.ExceptionRecord.ExceptionInformation[1];
        end
        else begin
          Info0 := ExInfo64.ExceptionRecord.ExceptionInformation[0];
          Info1 := ExInfo64.ExceptionRecord.ExceptionInformation[1];
        end;
        Info1Str := FormatAddress(Info1);

        case Info0 of
          EXCEPTION_READ_FAULT:    ExceptionMessage := 'Access violation reading from address ' + Info1Str +'.';
          EXCEPTION_WRITE_FAULT:   ExceptionMessage := 'Access violation writing to address ' + Info1Str +'.';
          EXCEPTION_EXECUTE_FAULT: ExceptionMessage := 'Access violation executing address ' + Info1Str +'.';
        end;
      end;
    end;
    {
    DebugLn(DBG_VERBOSE, ' Info: ');
    for n := 0 to EXCEPTION_MAXIMUM_PARAMETERS - 1 do
    begin
      if GMode = dm32
      then Info0 := ExInfo32.ExceptionRecord.ExceptionInformation[n]
      else Info0 := ExInfo64.ExceptionRecord.ExceptionInformation[n];
      DebugLn(DBG_VERBOSE, IntToHex(Info0, DBGPTRSIZE[GMode] * 2), ' ');
      if n and (PARAMCOLS - 1) = (PARAMCOLS - 1)
      then begin
        DebugLn(DBG_VERBOSE, '');
        DebugLn(DBG_VERBOSE, '       ');
      end;
    end;
    DebugLn(DBG_VERBOSE, '');
    }
  end;

  procedure DumpEvent(const AEvent: String);
  var
    f: Cardinal;
    n: integer;
  begin
    if (DBG_VERBOSE = nil) or (not DBG_VERBOSE^.Enabled) then
      exit;
    DebugLn('===');
    DebugLn(AEvent);
    DebugLn('---');
    DebugLn('Process ID: '+ IntToSTr(MDebugEvent.dwProcessId));
    DebugLn('Thread ID: '+ IntToStr(MDebugEvent.dwThreadId));

    if AThread = nil then Exit;
    if TDbgWinThread(AThread).FCurrentContext = nil then Exit;

{$PUSH}{$R-}
    {$ifdef cpui386}
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('DS: 0x%x, ES: 0x%x, FS: 0x%x, GS: 0x%x', [SegDs, SegEs, SegFs, SegGs]));
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('EAX: 0x%x, EBX: 0x%x, ECX: 0x%x, EDX: 0x%x, EDI: 0x%x, ESI: 0x%x', [Eax, Ebx, Ecx, Edx, Edi, Esi]));
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('CS: 0x%x, SS: 0x%x, EBP: 0x%x, EIP: 0x%x, ESP: 0x%x, EFlags: 0x%x [', [SegCs, SegSs, Ebp, Eip, Esp, EFlags]));
    {$else}
// TODO: if bitness
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('SegDS: 0x%4.4x, SegES: 0x%4.4x, SegFS: 0x%4.4x, SegGS: 0x%4.4x', [SegDs, SegEs, SegFs, SegGs]));
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('RAX: 0x%16.16x, RBX: 0x%16.16x, RCX: 0x%16.16x, RDX: 0x%16.16x, RDI: 0x%16.16x, RSI: 0x%16.16x, R9: 0x%16.16x, R10: 0x%16.16x, R11: 0x%16.16x, R12: 0x%16.16x, R13: 0x%16.16x, R14: 0x%16.16x, R15: 0x%16.16x', [Rax, Rbx, Rcx, Rdx, Rdi, Rsi, R9, R10, R11, R12, R13, R14, R15]));
    with TDbgWinThread(AThread).FCurrentContext^.def do DebugLn(Format('SegCS: 0x%4.4x, SegSS: 0x%4.4x, RBP: 0x%16.16x, RIP: 0x%16.16x, RSP: 0x%16.16x, EFlags: 0x%8.8x [', [SegCs, SegSs, Rbp, Rip, Rsp, EFlags]));
    {$endif}
    // luckely flag and debug registers are named the same
    with TDbgWinThread(AThread).FCurrentContext^.def do
    begin
      if EFlags and (1 shl 0) <> 0 then DebugLn('CF ');
      if EFlags and (1 shl 2) <> 0 then DebugLn('PF ');
      if EFlags and (1 shl 4) <> 0 then DebugLn('AF ');
      if EFlags and (1 shl 6) <> 0 then DebugLn('ZF ');
      if EFlags and (1 shl 7) <> 0 then DebugLn('SF ');
      if EFlags and (1 shl 8) <> 0 then DebugLn('TF ');
      if EFlags and (1 shl 9) <> 0 then DebugLn('IF ');
      if EFlags and (1 shl 10) <> 0 then DebugLn('DF ');
      if EFlags and (1 shl 11) <> 0 then DebugLn('OF ');
      if (EFlags shr 12) and 3 <> 0 then DebugLn('IOPL=', IntToSTr((EFlags shr 12) and 3));
      if EFlags and (1 shl 14) <> 0 then DebugLn('NT ');
      if EFlags and (1 shl 16) <> 0 then DebugLn('RF ');
      if EFlags and (1 shl 17) <> 0 then DebugLn('VM ');
      if EFlags and (1 shl 18) <> 0 then DebugLn('AC ');
      if EFlags and (1 shl 19) <> 0 then DebugLn('VIF ');
      if EFlags and (1 shl 20) <> 0 then DebugLn('VIP ');
      if EFlags and (1 shl 21) <> 0 then DebugLn('ID ');
      DebugLn(']');

      DebugLn(Format('DR0: 0x%x, DR1: 0x%x, DR2: 0x%x, DR3: 0x%x', [Dr0, Dr1, Dr2, Dr3]));
      DebugLn(' DR6: 0x', IntToHex(Dr6, SizeOf(Pointer) * 2), ' [');
      if Dr6 and $0001 <> 0 then DebugLn('B0 ');
      if Dr6 and $0002 <> 0 then DebugLn('B1 ');
      if Dr6 and $0004 <> 0 then DebugLn('B2 ');
      if Dr6 and $0008 <> 0 then DebugLn('B3 ');
      if Dr6 and $2000 <> 0 then DebugLn('BD ');
      if Dr6 and $4000 <> 0 then DebugLn('BS ');
      if Dr6 and $8000 <> 0 then DebugLn('BT ');
      DebugLn('] DR7: 0x', IntToHex(Dr7, SizeOf(Pointer) * 2), ' [');
      if Dr7 and $01 <> 0 then DebugLn('L0 ');
      if Dr7 and $02 <> 0 then DebugLn('G0 ');
      if Dr7 and $04 <> 0 then DebugLn('L1 ');
      if Dr7 and $08 <> 0 then DebugLn('G1 ');
      if Dr7 and $10 <> 0 then DebugLn('L2 ');
      if Dr7 and $20 <> 0 then DebugLn('G2 ');
      if Dr7 and $40 <> 0 then DebugLn('L3 ');
      if Dr7 and $80 <> 0 then DebugLn('G3 ');
      if Dr7 and $100 <> 0 then DebugLn('LE ');
      if Dr7 and $200 <> 0 then DebugLn('GE ');
      if Dr7 and $2000 <> 0 then DebugLn('GD ');
      f := Dr7 shr 16;
      for n := 0 to 3 do
      begin
        DebugLn('R/W', IntToSTr(n),':');
        case f and 3 of
          0: DebugLn('ex');
          1: DebugLn('wo');
          2: DebugLn('IO');
          3: DebugLn('rw');
        end;
        f := f shr 2;
        DebugLn(' LEN', IntToSTr(n),':', IntToSTr(f and 3 + 1), ' ');
        f := f shr 2;
      end;
      DebugLn(']');
    end;
    DebugLn('---');
  {$POP}
  end;

  procedure HandleOutputDebug(const AEvent: TDebugEvent);
  var
    S: String;
    W: WideString;
  begin
    if AEvent.DebugString.fUnicode <> 0
    then begin
      if not ReadWString(TDbgPtr(AEvent.DebugString.lpDebugStringData), AEvent.DebugString.nDebugStringLength, W)
      then Exit;
      S := W;
    end
    else begin
      if not ReadString(TDbgPtr(AEvent.DebugString.lpDebugStringData), AEvent.DebugString.nDebugStringLength, S)
      then Exit;
    end;
    DebugLn(DBG_VERBOSE, '[%d:%d]: %s', [AEvent.dwProcessId, AEvent.dwThreadId, S]);
  end;

var
  InterceptAtFirst: Boolean;
begin
  if AThread <> nil then
    TDbgWinThread(AThread).EndSingleStepOverBreakPoint;

  if HandleDebugEvent(MDebugEvent)
  then result := deBreakpoint // unreachable
  else begin

    case MDebugEvent.dwDebugEventCode of
      EXCEPTION_DEBUG_EVENT: begin
        //DumpEvent('EXCEPTION_DEBUG_EVENT');
        case MDebugEvent.Exception.ExceptionRecord.ExceptionCode of
          EXCEPTION_BREAKPOINT, STATUS_WX86_BREAKPOINT: begin
            if FJustStarted and (MDebugEvent.Exception.dwFirstChance <> 0) and (MDebugEvent.Exception.ExceptionRecord.ExceptionFlags = 0) then
            begin
              FJustStarted:=false;
              result := deInternalContinue;
            end
            else begin
              result := deBreakpoint;
              if AThread <> nil then
                AThread.CheckAndResetInstructionPointerAfterBreakpoint;
            end;
          end;
          EXCEPTION_SINGLE_STEP, STATUS_WX86_SINGLE_STEP: begin
            result := deBreakpoint;
          end
        else begin
          HandleException(MDebugEvent, InterceptAtFirst);
          if (MDebugEvent.Exception.dwFirstChance = 1) and (not InterceptAtFirst) then
            result := deInternalContinue // might be an SEH exception
          else
            result := deException;
        end;
        end;
      end;
      CREATE_THREAD_DEBUG_EVENT: begin
        //DumpEvent('CREATE_THREAD_DEBUG_EVENT');
        result := deInternalContinue;
      end;
      CREATE_PROCESS_DEBUG_EVENT: begin
        //DumpEvent('CREATE_PROCESS_DEBUG_EVENT');
        if MDebugEvent.dwProcessId = TDbgWinThread(AThread).Process.ProcessID then begin
          //main process
          StartProcess(MDebugEvent.dwThreadId, MDebugEvent.CreateProcessInfo); // hfile will be closed by TDbgImageLoader
          FJustStarted := true;
          result := deCreateProcess;
        end
        else begin
          //child process: ignore
          // we currently do not use the file handle => close it
          if MDebugEvent.CreateProcessInfo.hFile <> 0 then
            CloseHandle(MDebugEvent.CreateProcessInfo.hFile);
          result := deInternalContinue;
        end;
      end;
      EXIT_THREAD_DEBUG_EVENT: begin
        //DumpEvent('EXIT_THREAD_DEBUG_EVENT');
        result := deInternalContinue;
      end;
      EXIT_PROCESS_DEBUG_EVENT: begin
        //DumpEvent('EXIT_PROCESS_DEBUG_EVENT');
        SetExitCode(MDebugEvent.ExitProcess.dwExitCode);
        // Let the kernel close all debug-handles and close-up the
        // debuggee.
        Windows.ContinueDebugEvent(MDebugEvent.dwProcessId, MDebugEvent.dwThreadId, DBG_CONTINUE);
        result := deExitProcess;
      end;
      LOAD_DLL_DEBUG_EVENT: begin
        //DumpEvent('LOAD_DLL_DEBUG_EVENT');
        result := deLoadLibrary;
      end;
      UNLOAD_DLL_DEBUG_EVENT: begin
        //DumpEvent('UNLOAD_DLL_DEBUG_EVENT');
        result := deUnloadLibrary;
      end;
      OUTPUT_DEBUG_STRING_EVENT: begin
        //DumpEvent('OUTPUT_DEBUG_STRING_EVENT');
        HandleOutputDebug(MDebugEvent);
        result := deInternalContinue;
      end;
      RIP_EVENT: begin
        //DumpEvent('RIP_EVENT');
        result := deInternalContinue;
      end
      else begin
        raise Exception.CreateFmt('Unknown dwDebugEventCode value %d',[MDebugEvent.dwDebugEventCode]);
      end;
    end;

  end;
end;

function TDbgWinProcess.CreateThread(AthreadIdentifier: THandle; out IsMainThread: boolean): TDbgThread;
begin
  case MDebugEvent.dwDebugEventCode of
    CREATE_THREAD_DEBUG_EVENT :
      begin
      result := OSDbgClasses.DbgThreadClass.Create(Self, AThreadIdentifier, MDebugEvent.CreateThread.hThread);
      IsMainThread := false;
      end;
    CREATE_PROCESS_DEBUG_EVENT :
      begin
      result := OSDbgClasses.DbgThreadClass.Create(Self, AThreadIdentifier, MDebugEvent.CreateProcessInfo.hThread);
      IsMainThread := true;
      end
  else
    result := nil;
  end; {case}
end;

procedure TDbgWinProcess.StartProcess(const AThreadID: DWORD;const AInfo: TCreateProcessDebugInfo);
var
  s: string;
  {$ifNdef cpui386}
  b: BOOL;
  {$endif}
begin
  FInfo := AInfo;
  if ThreadID = 0 then
    SetThreadId(AThreadID);
  {$ifdef cpui386}
  FBitness := b32; // only 32 bit supported
  {$else}
  if (_IsWow64Process <> nil) and _IsWow64Process(GetHandle, @b) then begin
    if b then
      FBitness := b32
    else
      FBitness := b64;
  end
  else
    FBitness := b64;
  {$endif}

  s := GetProcFilename(Self, AInfo.lpImageName, AInfo.fUnicode, 0);
  if s <> ''
  then SetFileName(s);
end;

function TDbgWinProcess.Pause: boolean;
var
  hndl: Handle;
  hThread: THandle;
  NewThreadId: Cardinal;
begin
  //hndl := OpenProcess(PROCESS_CREATE_THREAD or PROCESS_QUERY_INFORMATION or PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ, False, TargetPID);
  hndl := OpenProcess(PROCESS_ALL_ACCESS, false, ProcessID);
  PauseRequested:=true;
  Result := False;
  if _DebugBreakProcess <> nil then
    Result := _DebugBreakProcess(hndl);
  if not Result then begin
    DebugLn(DBG_WARNINGS, ['pause failed(1) ', GetLastError]);
    if (_CreateRemoteThread <> nil) and (DebugBreakAddr <> nil) then begin
      hThread := _CreateRemoteThread(hndl, nil, 0, DebugBreakAddr, nil, 0, NewThreadId);
      if hThread = 0 then begin
        DebugLn(DBG_WARNINGS, ['pause failed(2) ', GetLastError]);
      end
      else begin
        Result := True;
        CloseHandle(hThread);
      end;
    end;
  end;
  CloseHandle(hndl);
end;

procedure TDbgWinProcess.TerminateProcess;
begin
  Windows.TerminateProcess(Handle, 0);
  FTerminated := True;
end;

function TDbgWinProcess.AddrOffset: TDBGPtr;
begin
  Result:=0;//inherited AddrOffset - TDbgPtr(FInfo.lpBaseOfImage);
end;

function TDbgWinProcess.AddLib(const AInfo: TLoadDLLDebugInfo): TDbgLibrary;
var
  ID: TDbgPtr;
begin
  Result := TDbgWinLibrary.Create(Self, HexValue(AInfo.lpBaseOfDll, SizeOf(Pointer), [hvfIncludeHexchar]), AInfo.hFile, TDbgPtr(AInfo.lpBaseOfDll), AInfo);
  ID := TDbgPtr(AInfo.lpBaseOfDll);
  FLibMap.Add(ID, Result);
  if (Result.DbgInfo.HasInfo) or (Result.SymbolTableInfo.HasInfo)
  then FSymInstances.Add(Result);
end;

procedure TDbgWinProcess.RemoveLib(const AInfo: TUnloadDLLDebugInfo);
var
  Lib: TDbgLibrary;
  ID: TDbgPtr;
begin
  if FLibMap = nil then Exit;
  ID := TDbgPtr(AInfo.lpBaseOfDll);
  if not FLibMap.GetData(ID, Lib) then Exit;
  FSymInstances.Remove(Lib);
  FLibMap.Delete(ID);
  SetLastLibraryUnloaded(Lib);
end;

{ TDbgWinThread }

procedure TDbgWinThread.LoadRegisterValues;
begin
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
  {$ifdef cpui386}
  with FCurrentContext^.def do
  begin
    FRegisterValueList.DbgRegisterAutoCreate['eax'].SetValue(Eax, IntToStr(Eax),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ecx'].SetValue(Ecx, IntToStr(Ecx),4,1);
    FRegisterValueList.DbgRegisterAutoCreate['edx'].SetValue(Edx, IntToStr(Edx),4,2);
    FRegisterValueList.DbgRegisterAutoCreate['ebx'].SetValue(Ebx, IntToStr(Ebx),4,3);
    FRegisterValueList.DbgRegisterAutoCreate['esp'].SetValue(Esp, IntToStr(Esp),4,4);
    FRegisterValueList.DbgRegisterAutoCreate['ebp'].SetValue(Ebp, IntToStr(Ebp),4,5);
    FRegisterValueList.DbgRegisterAutoCreate['esi'].SetValue(Esi, IntToStr(Esi),4,6);
    FRegisterValueList.DbgRegisterAutoCreate['edi'].SetValue(Edi, IntToStr(Edi),4,7);
    FRegisterValueList.DbgRegisterAutoCreate['eip'].SetValue(Eip, IntToStr(Eip),4,8);

    FRegisterValueList.DbgRegisterAutoCreate['eflags'].Setx86EFlagsValue(EFlags);

    FRegisterValueList.DbgRegisterAutoCreate['cs'].SetValue(SegCs, IntToStr(SegCs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ss'].SetValue(SegSs, IntToStr(SegSs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ds'].SetValue(SegDs, IntToStr(SegDs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['es'].SetValue(SegEs, IntToStr(SegEs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['fs'].SetValue(SegFs, IntToStr(SegFs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['gs'].SetValue(SegGs, IntToStr(SegGs),4,0);
  end;
{$else}
  if (TDbgWinProcess(Process).FBitness = b32) then
  with FCurrentContext^.WOW do
  begin
    FRegisterValueList.DbgRegisterAutoCreate['eax'].SetValue(Eax, IntToStr(Eax),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ecx'].SetValue(Ecx, IntToStr(Ecx),4,1);
    FRegisterValueList.DbgRegisterAutoCreate['edx'].SetValue(Edx, IntToStr(Edx),4,2);
    FRegisterValueList.DbgRegisterAutoCreate['ebx'].SetValue(Ebx, IntToStr(Ebx),4,3);
    FRegisterValueList.DbgRegisterAutoCreate['esp'].SetValue(Esp, IntToStr(Esp),4,4);
    FRegisterValueList.DbgRegisterAutoCreate['ebp'].SetValue(Ebp, IntToStr(Ebp),4,5);
    FRegisterValueList.DbgRegisterAutoCreate['esi'].SetValue(Esi, IntToStr(Esi),4,6);
    FRegisterValueList.DbgRegisterAutoCreate['edi'].SetValue(Edi, IntToStr(Edi),4,7);
    FRegisterValueList.DbgRegisterAutoCreate['eip'].SetValue(Eip, IntToStr(Eip),4,8);

    FRegisterValueList.DbgRegisterAutoCreate['eflags'].Setx86EFlagsValue(EFlags);

    FRegisterValueList.DbgRegisterAutoCreate['cs'].SetValue(SegCs, IntToStr(SegCs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ss'].SetValue(SegSs, IntToStr(SegSs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['ds'].SetValue(SegDs, IntToStr(SegDs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['es'].SetValue(SegEs, IntToStr(SegEs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['fs'].SetValue(SegFs, IntToStr(SegFs),4,0);
    FRegisterValueList.DbgRegisterAutoCreate['gs'].SetValue(SegGs, IntToStr(SegGs),4,0);
  end
  else
  with FCurrentContext^.def do
  begin
    FRegisterValueList.DbgRegisterAutoCreate['rax'].SetValue(rax, IntToStr(rax),8,0);
    FRegisterValueList.DbgRegisterAutoCreate['rbx'].SetValue(rbx, IntToStr(rbx),8,3);
    FRegisterValueList.DbgRegisterAutoCreate['rcx'].SetValue(rcx, IntToStr(rcx),8,2);
    FRegisterValueList.DbgRegisterAutoCreate['rdx'].SetValue(rdx, IntToStr(rdx),8,1);
    FRegisterValueList.DbgRegisterAutoCreate['rsi'].SetValue(rsi, IntToStr(rsi),8,4);
    FRegisterValueList.DbgRegisterAutoCreate['rdi'].SetValue(rdi, IntToStr(rdi),8,5);
    FRegisterValueList.DbgRegisterAutoCreate['rbp'].SetValue(rbp, IntToStr(rbp),8,6);
    FRegisterValueList.DbgRegisterAutoCreate['rsp'].SetValue(rsp, IntToStr(rsp),8,7);

    FRegisterValueList.DbgRegisterAutoCreate['r8'].SetValue(r8, IntToStr(r8),8,8);
    FRegisterValueList.DbgRegisterAutoCreate['r9'].SetValue(r9, IntToStr(r9),8,9);
    FRegisterValueList.DbgRegisterAutoCreate['r10'].SetValue(r10, IntToStr(r10),8,10);
    FRegisterValueList.DbgRegisterAutoCreate['r11'].SetValue(r11, IntToStr(r11),8,11);
    FRegisterValueList.DbgRegisterAutoCreate['r12'].SetValue(r12, IntToStr(r12),8,12);
    FRegisterValueList.DbgRegisterAutoCreate['r13'].SetValue(r13, IntToStr(r13),8,13);
    FRegisterValueList.DbgRegisterAutoCreate['r14'].SetValue(r14, IntToStr(r14),8,14);
    FRegisterValueList.DbgRegisterAutoCreate['r15'].SetValue(r15, IntToStr(r15),8,15);

    FRegisterValueList.DbgRegisterAutoCreate['rip'].SetValue(rip, IntToStr(rip),8,16);
    FRegisterValueList.DbgRegisterAutoCreate['eflags'].Setx86EFlagsValue(EFlags);

    FRegisterValueList.DbgRegisterAutoCreate['cs'].SetValue(SegCs, IntToStr(SegCs),8,43);
    FRegisterValueList.DbgRegisterAutoCreate['ss'].SetValue(SegSs, IntToStr(SegSs),8,44);
    FRegisterValueList.DbgRegisterAutoCreate['ds'].SetValue(SegDs, IntToStr(SegDs),8,45);
    FRegisterValueList.DbgRegisterAutoCreate['es'].SetValue(SegEs, IntToStr(SegEs),8,42);
    FRegisterValueList.DbgRegisterAutoCreate['fs'].SetValue(SegFs, IntToStr(SegFs),8,46);
    FRegisterValueList.DbgRegisterAutoCreate['gs'].SetValue(SegGs, IntToStr(SegGs),8,47);
  end;
{$endif}
  FRegisterValueListValid:=true;
end;

function TDbgWinThread.GetFpThreadContext(var AStorage: TFpContext; out
  ACtxPtr: PFpContext; ACtxFlags: TFpWinCtxFlags): Boolean;
begin
  ACtxPtr := AlignPtr(@AStorage, $10);
  SetLastError(0);

  {$ifdef cpux86_64}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    case ACtxFlags of
      cfControl: ACtxPtr^.WOW.ContextFlags := WOW64_CONTEXT_CONTROL;
      cfFull:    ACtxPtr^.WOW.ContextFlags := WOW64_CONTEXT_SEGMENTS or WOW64_CONTEXT_INTEGER or WOW64_CONTEXT_CONTROL or WOW64_CONTEXT_DEBUG_REGISTERS;
    end;
    Result := (_Wow64GetThreadContext <> nil) and _Wow64GetThreadContext(Handle, ACtxPtr^.WOW);
  end
  else begin
  {$endif}
    case ACtxFlags of
      cfControl: ACtxPtr^.def.ContextFlags := CONTEXT_CONTROL;
      cfFull:    ACtxPtr^.def.ContextFlags := CONTEXT_SEGMENTS or CONTEXT_INTEGER or CONTEXT_CONTROL or CONTEXT_DEBUG_REGISTERS;
    end;
    Result := GetThreadContext(Handle, ACtxPtr^.def);
  {$ifdef cpux86_64}
  end;
  {$endif}
  DebugLn(DBG_WARNINGS and (not Result), ['Unable to get Context for ', ID, ': ', GetLastErrorText]);
end;

function TDbgWinThread.SetFpThreadContext(ACtxPtr: PFpContext;
  ACtxFlags: TFpWinCtxFlags): Boolean;
begin
  SetLastError(0);
  {$ifdef cpux86_64}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    case ACtxFlags of
      cfControl: ACtxPtr^.WOW.ContextFlags := WOW64_CONTEXT_CONTROL;
      cfFull:    ACtxPtr^.WOW.ContextFlags := WOW64_CONTEXT_SEGMENTS or WOW64_CONTEXT_INTEGER or WOW64_CONTEXT_CONTROL or WOW64_CONTEXT_DEBUG_REGISTERS;
    end;
    if ccfControl in FThreadContextChangeFlags then
      ACtxPtr^.def.ContextFlags := ACtxPtr^.def.ContextFlags or WOW64_CONTEXT_CONTROL;
    if ccfInteger in FThreadContextChangeFlags then
      ACtxPtr^.def.ContextFlags := ACtxPtr^.def.ContextFlags or WOW64_CONTEXT_INTEGER;
    Result := (_Wow64SetThreadContext <> nil) and _Wow64SetThreadContext(Handle, ACtxPtr^.WOW);
  end
  else begin
  {$endif}
    case ACtxFlags of
      cfControl: ACtxPtr^.def.ContextFlags := CONTEXT_CONTROL;
      cfFull:    ACtxPtr^.def.ContextFlags := CONTEXT_SEGMENTS or CONTEXT_INTEGER or CONTEXT_CONTROL or CONTEXT_DEBUG_REGISTERS;
    end;
    if ccfControl in FThreadContextChangeFlags then
      ACtxPtr^.def.ContextFlags := ACtxPtr^.def.ContextFlags or CONTEXT_CONTROL;
    if ccfInteger in FThreadContextChangeFlags then
      ACtxPtr^.def.ContextFlags := ACtxPtr^.def.ContextFlags or CONTEXT_INTEGER;
    Result := SetThreadContext(Handle, ACtxPtr^.def);
  {$ifdef cpux86_64}
  end;
  {$endif}
  DebugLn(DBG_WARNINGS and (not Result), ['Unable to set Context for ', ID, ': ', GetLastErrorText]);
end;

procedure TDbgWinThread.Suspend;
var
  r: DWORD;
begin
  if FIsSuspended then
    exit;
  r := SuspendThread(Handle);
  FIsSuspended := r <> DWORD(-1);
  debugln(DBG_WARNINGS and (r = DWORD(-1)), 'Failed to suspend Thread %d (handle: %d). Error: %s', [Id, Handle, GetLastErrorText]);
end;

procedure TDbgWinThread.SuspendForStepOverBreakPoint;
begin
  if FIsSkippingBreakPoint then begin
    if GetInstructionPointerRegisterValue = FIsSkippingBreakPointAddress then
      Process.TempRemoveBreakInstructionCode(FIsSkippingBreakPointAddress);
    // else the single step should be done, and the event should be received next
  end
  else
    Suspend;
end;

procedure TDbgWinThread.Resume;
var
  r: DWORD;
begin
  if not FIsSuspended then
    exit;
  r := ResumeThread(Handle);
  FIsSuspended := not(r <> DWORD(-1));
  debugln(DBG_WARNINGS and (r = DWORD(-1)), 'Failed to resume Thread %d (handle: %d). Error: %s', [Id, Handle, GetLastErrorText]);
end;

procedure TDbgWinThread.SetSingleStepOverBreakPoint;
begin
  SetSingleStep;
  FIsSkippingBreakPoint := True;
  FIsSkippingBreakPointAddress := GetInstructionPointerRegisterValue;
end;

procedure TDbgWinThread.EndSingleStepOverBreakPoint;
begin
  FIsSkippingBreakPoint := False;
end;

procedure TDbgWinThread.SetSingleStep;
begin
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
  {$ifdef cpux86_64}
  if (TDbgWinProcess(Process).FBitness = b32) then
    FCurrentContext^.WOW.EFlags := FCurrentContext^.WOW.EFlags or FLAG_TRACE_BIT // TODO WOW_FLAG....
  else
  {$endif}
    FCurrentContext^.def.EFlags := FCurrentContext^.def.EFlags or FLAG_TRACE_BIT;
  FThreadContextChanged:=true;
end;

procedure TDbgWinThread.ApplyWatchPoints(AWatchPointData: TFpWatchPointData);
begin
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
  {$ifdef cpux86_64}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    with FCurrentContext^.WOW do begin
      Dr0 := DWORD(TFpIntelWatchPointData(AWatchPointData).Dr03[0]);
      Dr1 := DWORD(TFpIntelWatchPointData(AWatchPointData).Dr03[1]);
      Dr2 := DWORD(TFpIntelWatchPointData(AWatchPointData).Dr03[2]);
      Dr3 := DWORD(TFpIntelWatchPointData(AWatchPointData).Dr03[3]);
      Dr7 := (Dr7 and $0000FF00) or DWORD(TFpIntelWatchPointData(AWatchPointData).Dr7);
DebugLn(DBG_VERBOSE, '### WATCH ADDED  dr0 %x  dr1 %x  dr2 %x  dr3 %x      dr7 %x', [ dr0,dr1,dr2,dr3, dr7]);
    end;
  end
  else begin
  {$endif}
    with FCurrentContext^.def do begin
      Dr0 := TFpIntelWatchPointData(AWatchPointData).Dr03[0];
      Dr1 := TFpIntelWatchPointData(AWatchPointData).Dr03[1];
      Dr2 := TFpIntelWatchPointData(AWatchPointData).Dr03[2];
      Dr3 := TFpIntelWatchPointData(AWatchPointData).Dr03[3];
      Dr7 := (Dr7 and $0000FF00) or TFpIntelWatchPointData(AWatchPointData).Dr7;
DebugLn(DBG_VERBOSE, '### WATCH ADDED   dr0 %x  dr1 %x  dr2 %x  dr3 %x      dr7 %x', [ dr0,dr1,dr2,dr3, dr7]);
    end;
  {$ifdef cpux86_64}
  end;
  {$endif}
  FThreadContextChanged:=true;
end;

function TDbgWinThread.DetectHardwareWatchpoint: Pointer;
var
  Dr6: DWORD64;
  wd: TFpIntelWatchPointData;
begin
  result := nil;
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;

  {$ifdef cpux86_64}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    Dr6 := DWORD64(FCurrentContext^.WOW.Dr6);
  end
  else begin
  {$endif}
    Dr6 := FCurrentContext^.def.Dr6;
  {$ifdef cpux86_64}
  end;
  {$endif}

  wd := TFpIntelWatchPointData(Process.WatchPointData);
  if dr6 and 1 = 1 then result := wd.Owner[0]
  else if dr6 and 2 = 2 then result := wd.Owner[1]
  else if dr6 and 4 = 4 then result := wd.Owner[2]
  else if dr6 and 8 = 8 then result := wd.Owner[3];
  if (Result = nil) and ((dr6 and 15) <> 0) then
    Result := Pointer(-1); // not owned watchpoint
end;

procedure TDbgWinThread.BeforeContinue;
begin
  if ID = MDebugEvent.dwThreadId then begin
    inherited;

    {$ifdef cpux86_64}
    if (TDbgWinProcess(Process).FBitness = b32) then begin
      if (FCurrentContext <> nil) and
         (FCurrentContext^.WOW.Dr6 <> $ffff0ff0) then
      begin
        FCurrentContext^.WOW.Dr6:=$ffff0ff0;
        FThreadContextChanged:=true;
      end;
    end
    else begin
    {$endif}
      if (FCurrentContext <> nil) and
         (FCurrentContext^.def.Dr6 <> $ffff0ff0) then
      begin
        FCurrentContext^.def.Dr6:=$ffff0ff0;
        FThreadContextChanged:=true;
      end;
    {$ifdef cpux86_64}
    end;
    {$endif}
  end;

  if FThreadContextChanged then
  begin
    Assert(FCurrentContext <> nil, 'TDbgWinThread.BeforeContinue: none existing context was changed');
    if not SetFpThreadContext(FCurrentContext) then
      debugln(['Failed to SetFpThreadContext()']);
  end;
  FThreadContextChanged := False;
  FThreadContextChangeFlags := [];
  FCurrentContext := nil;
end;

function TDbgWinThread.ResetInstructionPointerAfterBreakpoint: boolean;
begin
  Result := False;
  assert(MDebugEvent.Exception.ExceptionRecord.ExceptionCode <> EXCEPTION_SINGLE_STEP, 'dec(IP) EXCEPTION_SINGLE_STEP');

  if not ReadThreadState then
    exit;

  {$ifdef cpui386}
  dec(FCurrentContext^.def.Eip);
  {$else}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    dec(FCurrentContext^.WOW.Eip);
  end
  else begin
    dec(FCurrentContext^.def.Rip);
  end;
  {$endif}

  FThreadContextChanged := True;
  Result := True;
end;

function TDbgWinThread.ReadThreadState: boolean;
begin
  if Process.ProcessID <> MDebugEvent.dwProcessId then begin
    DebugLn(DBG_WARNINGS, 'ERROR: attempt to read threadstate, for wrong process. Thread: %u Thread-Process: %u Event-Process %u', [Id, Process.ProcessID, MDebugEvent.dwProcessId]);
    exit(False);
  end;

  Result := True;
  if FCurrentContext <> nil then
    exit;

  Result := GetFpThreadContext(_UnAligendContext, FCurrentContext, cfFull);
  //FThreadContextChanged := False; TODO: why was that not here?
  FThreadContextChangeFlags := [];
  FRegisterValueListValid:=False;
end;

procedure TDbgWinThread.SetRegisterValue(AName: string; AValue: QWord);
begin
  if not ReadThreadState then
    exit;

  {$ifdef cpui386}
    case AName of
      'eip': FCurrentContext^.def.Eip := AValue;
      'eax': FCurrentContext^.def.Eax := AValue;
      'ecx': FCurrentContext^.def.Ecx := AValue;
      'edx': FCurrentContext^.def.Edx := AValue;
    else
      raise Exception.CreateFmt('Setting the [%s] register is not supported', [AName]);
    end;
  {$else}
  if (TDbgWinProcess(Process).FBitness = b32) then begin
    case AName of
      'eip': FCurrentContext^.WOW.Eip := AValue;
      'eax': FCurrentContext^.WOW.Eax := AValue;
      'ecx': FCurrentContext^.WOW.Ecx := AValue;
      'edx': FCurrentContext^.WOW.Edx := AValue;
    else
      raise Exception.CreateFmt('Setting the [%s] register is not supported', [AName]);
    end;
  end
  else begin
    case AName of
      'rip': FCurrentContext^.def.Rip := AValue;
      'rax': FCurrentContext^.def.Rax := AValue;
      'rcx': FCurrentContext^.def.Rcx := AValue;
      'rdx': FCurrentContext^.def.Rdx := AValue;
    else
      raise Exception.CreateFmt('Setting the [%s] register is not supported', [AName]);
    end;
  end;
  {$endif}
  FThreadContextChanged:=True;
  case AName of
    'eip', 'rip': Include(FThreadContextChangeFlags, ccfControl);
    else          Include(FThreadContextChangeFlags, ccfInteger);
  end;
end;

procedure TDbgWinThread.StoreRegisters;
begin
  _StoredContext := _UnAligendContext;
end;

procedure TDbgWinThread.RestoreRegisters;
begin
  _UnAligendContext := _StoredContext;
end;

function TDbgWinThread.GetInstructionPointerRegisterValue: TDbgPtr;
begin
  Result := 0;
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
{$ifdef cpui386}
  Result := FCurrentContext^.def.Eip;
{$else}
  if (TDbgWinProcess(Process).FBitness = b32) then
    Result := FCurrentContext^.WOW.Eip
  else
    Result := FCurrentContext^.def.Rip;
{$endif}
end;

function TDbgWinThread.GetStackBasePointerRegisterValue: TDbgPtr;
begin
  Result := 0;
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
{$ifdef cpui386}
  Result := FCurrentContext^.def.Ebp;
{$else}
  if (TDbgWinProcess(Process).FBitness = b32) then
    Result := FCurrentContext^.WOW.Ebp
  else
    Result := FCurrentContext^.def.Rbp;
{$endif}
end;

function TDbgWinThread.GetStackPointerRegisterValue: TDbgPtr;
begin
  Result := 0;
  if FCurrentContext = nil then
    if not ReadThreadState then
      exit;
{$ifdef cpui386}
  Result := FCurrentContext^.def.Esp;
{$else}
  if (TDbgWinProcess(Process).FBitness = b32) then
    Result := FCurrentContext^.WOW.Esp
  else
    Result := FCurrentContext^.def.Rsp;
{$endif}
end;

initialization
  LoadKernelEntryPoints;

  DBG_VERBOSE := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );

  RegisterDbgOsClasses(TOSDbgClasses.Create(
    TDbgWinProcess,
    TDbgWinThread,
    TX86AsmDecoder
  ));

end.


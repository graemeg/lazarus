{
 ---------------------------------------------------------------------------
 FpDebugDebuggerUtils
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

unit FpDebugDebuggerUtils;

{$mode objfpc}{$H+}

interface

uses
  FpDbgUtil, FpdMemoryTools, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, DbgIntfDebuggerBase, sysutils,
  Classes, syncobjs, Forms;

type

  { TFpDebugDebuggerPropertiesMemLimits }

  TFpDebugDebuggerPropertiesMemLimits = class(TPersistent)
  private
  const
    DEF_MaxMemReadSize              = 512*1024*1024;
    DEF_MaxStringLen                = 10000;
    DEF_MaxArrayLen                 = 100*1024;
    DEF_MaxNullStringSearchLen      = 10000;
    DEF_MaxStackStringLen           = 512;
    DEF_MaxStackArrayLen            = 64;
    DEF_MaxStackNullStringSearchLen = 512;
  private
    FMaxArrayLen: QWord;
    FMaxMemReadSize: QWord;
    FMaxNullStringSearchLen: QWord;
    FMaxStackArrayLen: QWord;
    FMaxStackNullStringSearchLen: QWord;
    FMaxStackStringLen: QWord;
    FMaxStringLen: QWord;
    function MaxArrayLenIsStored: Boolean;
    function MaxMemReadSizeIsStored: Boolean;
    function MaxNullStringSearchLenIsStored: Boolean;
    function MaxStackArrayLenIsStored: Boolean;
    function MaxStackNullStringSearchLenIsStored: Boolean;
    function MaxStackStringLenIsStored: Boolean;
    function MaxStringLenIsStored: Boolean;
    procedure SetMaxArrayLen(AValue: QWord);
    procedure SetMaxMemReadSize(AValue: QWord);
    procedure SetMaxNullStringSearchLen(AValue: QWord);
    procedure SetMaxStackArrayLen(AValue: QWord);
    procedure SetMaxStackNullStringSearchLen(AValue: QWord);
    procedure SetMaxStackStringLen(AValue: QWord);
    procedure SetMaxStringLen(AValue: QWord);
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    property MaxMemReadSize: QWord read FMaxMemReadSize write SetMaxMemReadSize stored MaxMemReadSizeIsStored default DEF_MaxMemReadSize;

    property MaxStringLen:           QWord read FMaxStringLen write SetMaxStringLen stored MaxStringLenIsStored default DEF_MaxStringLen;
    property MaxArrayLen:            QWord read FMaxArrayLen write SetMaxArrayLen  stored MaxArrayLenIsStored default DEF_MaxArrayLen;
    property MaxNullStringSearchLen: QWord read FMaxNullStringSearchLen write SetMaxNullStringSearchLen stored MaxNullStringSearchLenIsStored default DEF_MaxNullStringSearchLen;

    property MaxStackStringLen:           QWord read FMaxStackStringLen write SetMaxStackStringLen stored MaxStackStringLenIsStored default DEF_MaxStackStringLen;
    property MaxStackArrayLen:            QWord read FMaxStackArrayLen write SetMaxStackArrayLen stored MaxStackArrayLenIsStored default DEF_MaxStackArrayLen;
    property MaxStackNullStringSearchLen: QWord read FMaxStackNullStringSearchLen write SetMaxStackNullStringSearchLen stored MaxStackNullStringSearchLenIsStored default DEF_MaxStackNullStringSearchLen;
  end;

  TFpInt3DebugBreakOption = (
    dboIgnoreAll //, dboIgnoreDLL, dboIgnoreNtdllNoneDebug, dboIgnoreNtdllDebug
  );
  TFpInt3DebugBreakOptions = set of TFpInt3DebugBreakOption;

  { TFpDebugDebuggerProperties }

  TFpDebugDebuggerProperties = class(TDebuggerProperties)
  private
    FConsoleTty: string;
    {$ifdef windows}
    FForceNewConsole: boolean;
    {$endif windows}
    FHandleDebugBreakInstruction: TFpInt3DebugBreakOptions;
    FMemLimits: TFpDebugDebuggerPropertiesMemLimits;
    FNextOnlyStopOnStartLine: boolean;
    procedure SetMemLimits(AValue: TFpDebugDebuggerPropertiesMemLimits);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    {$ifdef unix}
  published
    {$endif unix}
    property ConsoleTty: string read FConsoleTty write FConsoleTty;
  published
    property NextOnlyStopOnStartLine: boolean read FNextOnlyStopOnStartLine write FNextOnlyStopOnStartLine default False;
    {$ifdef windows}
    property ForceNewConsole: boolean read FForceNewConsole write FForceNewConsole default True;
    {$endif windows}

    property MemLimits: TFpDebugDebuggerPropertiesMemLimits read FMemLimits write SetMemLimits;
    property HandleDebugBreakInstruction: TFpInt3DebugBreakOptions read FHandleDebugBreakInstruction write FHandleDebugBreakInstruction default [dboIgnoreAll];
  end;


type

  TFpThreadWorkerPriority = (
    twpModify, // this is a user actions
    twpUser,
    twpThread, twpStack, twpLocal, twpWatch,
    twpContinue
  );

const
  twpInspect = twpWatch;
  twpDefault = twpUser;
type

  { TFpThreadPriorityWorkerItem }

  TFpThreadPriorityWorkerItem = class(TFpThreadWorkerItem)
  private
    FPriority: TFpThreadWorkerPriority;
  public
    constructor Create(APriority: TFpThreadWorkerPriority);
    function DebugText: String; override;
    property Priority: TFpThreadWorkerPriority read FPriority;
  end;

  { TFpThreadPriorityWorkerQueue }

  TFpThreadPriorityWorkerQueue = class(TFpThreadWorkerQueue)
  private
    function GetOnQueueIdle: TThreadMethod;
    procedure SetOnQueueIdle(AValue: TThreadMethod);
  protected type
    TFpDbgTypedFifoQueue2 = TFpDbgTypedFifoQueue;
    TFpDbgPriorytyFifoQueue = class(TFpDbgTypedFifoQueue2)
    private
      FOnQueueIdle: TThreadMethod;
      FQueues: array[TFpThreadWorkerPriority] of TFpDbgTypedFifoQueue2;
      FLowestAvail: TFpThreadWorkerPriority;
      procedure DoOnIdle(Data: PtrInt);
    public
      constructor create(AQueueDepth: Integer = 10);
      destructor Destroy; override;
      function PushItem(const AItem: TFpThreadWorkerItem): Boolean; override;
      function PopItem(out AItem: TFpThreadWorkerItem): Boolean; override;
    end;
  protected
    function CreateFifoQueue(AQueueDepth: Integer): TLazTypedFifoQueue; override;
  public
    constructor Create(AQueueDepth: Integer = 10; PushTimeout: cardinal = INFINITE; PopTimeout: cardinal = INFINITE);
    procedure Lock; inline;
    procedure Unlock; inline;
    function Count: Integer;
    property OnQueueIdle: TThreadMethod read GetOnQueueIdle write SetOnQueueIdle;
  end;


implementation

var
  FPDBG_QUEUE: PLazLoggerLogGroup;

{ TFpDebugDebuggerPropertiesMemLimits }

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxMemReadSize(AValue: QWord);
begin
  if (AValue <> 0) and (AValue < MINIMUM_MEMREAD_LIMIT) then
    AValue := MINIMUM_MEMREAD_LIMIT;
  if FMaxMemReadSize = AValue then Exit;
  FMaxMemReadSize := AValue;

  MaxStringLen                := MaxStringLen;
  MaxNullStringSearchLen      := MaxNullStringSearchLen;
  MaxArrayLen                 := MaxArrayLen;
  MaxStackStringLen           := MaxStackStringLen;
  MaxStackNullStringSearchLen := MaxStackNullStringSearchLen;
  MaxStackArrayLen            := MaxStackArrayLen;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxArrayLen(AValue: QWord);
begin
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxArrayLen = AValue then Exit;
  FMaxArrayLen := AValue;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxArrayLenIsStored: Boolean;
begin
  Result := FMaxArrayLen <> DEF_MaxArrayLen;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxMemReadSizeIsStored: Boolean;
begin
  Result := FMaxMemReadSize <> DEF_MaxMemReadSize;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxNullStringSearchLenIsStored: Boolean;
begin
  Result := FMaxNullStringSearchLen <> DEF_MaxNullStringSearchLen;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxStackArrayLenIsStored: Boolean;
begin
  Result := FMaxStackArrayLen <> DEF_MaxStackArrayLen;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxStackNullStringSearchLenIsStored: Boolean;
begin
  Result := FMaxStackNullStringSearchLen <> DEF_MaxStackNullStringSearchLen;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxStackStringLenIsStored: Boolean;
begin
  Result := FMaxStackStringLen <> DEF_MaxStackStringLen;
end;

function TFpDebugDebuggerPropertiesMemLimits.MaxStringLenIsStored: Boolean;
begin
  Result := FMaxStringLen <> DEF_MaxStringLen;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxNullStringSearchLen(AValue: QWord);
begin
  if (AValue > FMaxStringLen) then
    AValue := FMaxStringLen;
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxNullStringSearchLen = AValue then Exit;
  FMaxNullStringSearchLen := AValue;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxStackArrayLen(AValue: QWord
  );
begin
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxStackArrayLen = AValue then Exit;
  FMaxStackArrayLen := AValue;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxStackNullStringSearchLen(AValue: QWord);
begin
  if (AValue > FMaxStackStringLen) then
    AValue := FMaxStackStringLen;
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxStackNullStringSearchLen = AValue then Exit;
  FMaxStackNullStringSearchLen := AValue;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxStackStringLen(AValue: QWord);
begin
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxStackStringLen = AValue then Exit;
  FMaxStackStringLen := AValue;
  MaxStackNullStringSearchLen      := MaxStackNullStringSearchLen;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.SetMaxStringLen(AValue: QWord);
begin
  if (AValue > FMaxMemReadSize) then
    AValue := FMaxMemReadSize;
  if FMaxStringLen = AValue then Exit;
  FMaxStringLen := AValue;
  MaxNullStringSearchLen      := MaxNullStringSearchLen;
end;

constructor TFpDebugDebuggerPropertiesMemLimits.Create;
begin
  inherited Create;
  FMaxMemReadSize             := DEF_MaxMemReadSize;
  FMaxStringLen               := DEF_MaxStringLen;
  FMaxArrayLen                := DEF_MaxArrayLen;
  FMaxNullStringSearchLen     := DEF_MaxNullStringSearchLen ;
  FMaxStackStringLen          := DEF_MaxStackStringLen;
  FMaxStackArrayLen           := DEF_MaxStackArrayLen;
  FMaxStackNullStringSearchLen:= DEF_MaxStackNullStringSearchLen;
end;

procedure TFpDebugDebuggerPropertiesMemLimits.Assign(Source: TPersistent);
begin
  if Source is TFpDebugDebuggerPropertiesMemLimits then begin
    FMaxMemReadSize             := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxMemReadSize;
    FMaxStringLen               := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxStringLen;
    FMaxArrayLen                := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxArrayLen;
    FMaxNullStringSearchLen     := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxNullStringSearchLen;
    FMaxStackStringLen          := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxStackStringLen;
    FMaxStackArrayLen           := TFpDebugDebuggerPropertiesMemLimits(Source).FMaxStackArrayLen;
    FMaxStackNullStringSearchLen:= TFpDebugDebuggerPropertiesMemLimits(Source).FMaxStackNullStringSearchLen;
  end;
end;

{ TFpDebugDebuggerProperties }

procedure TFpDebugDebuggerProperties.SetMemLimits(AValue: TFpDebugDebuggerPropertiesMemLimits);
begin
  FMemLimits.Assign(AValue);
end;

constructor TFpDebugDebuggerProperties.Create;
begin
  inherited Create;
  FNextOnlyStopOnStartLine:=False;
  {$ifdef windows}
  FForceNewConsole            := True;
  {$endif windows}
  FMemLimits := TFpDebugDebuggerPropertiesMemLimits.Create;
  FHandleDebugBreakInstruction := [dboIgnoreAll];
end;

destructor TFpDebugDebuggerProperties.Destroy;
begin
  inherited Destroy;
  FMemLimits.Free;
end;

procedure TFpDebugDebuggerProperties.Assign(Source: TPersistent);
begin
  inherited Assign(Source);
  if Source is TFpDebugDebuggerProperties then begin
    FNextOnlyStopOnStartLine := TFpDebugDebuggerProperties(Source).NextOnlyStopOnStartLine;
    FConsoleTty:=TFpDebugDebuggerProperties(Source).ConsoleTty;
    {$ifdef windows}
    FForceNewConsole:=TFpDebugDebuggerProperties(Source).FForceNewConsole;
    {$endif windows}
    FMemLimits.Assign(TFpDebugDebuggerProperties(Source).MemLimits);
    FHandleDebugBreakInstruction:=TFpDebugDebuggerProperties(Source).FHandleDebugBreakInstruction;
  end;
end;

{ TFpThreadPriorityWorkerItem }

constructor TFpThreadPriorityWorkerItem.Create(
  APriority: TFpThreadWorkerPriority);
begin
  FPriority := APriority;
end;

function TFpThreadPriorityWorkerItem.DebugText: String;
begin
  WriteStr(Result, FPriority);
  Result := inherited DebugText + '[' + Result + ':' + IntToStr(ord(FPriority)) + ']';
end;

{ TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue }

procedure TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.DoOnIdle(
  Data: PtrInt);
begin
  if Assigned(FOnQueueIdle) then
    FOnQueueIdle();
end;

constructor TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.create(
  AQueueDepth: Integer);
var
  a: TFpThreadWorkerPriority;
begin
  inherited create(0);
  for a in TFpThreadWorkerPriority do
    FQueues[a] := TFpDbgTypedFifoQueue2.create(AQueueDepth);
end;

destructor TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.Destroy;
var
  a: TFpThreadWorkerPriority;
begin
  Application.RemoveAsyncCalls(Self);
  inherited Destroy;
  for a in TFpThreadWorkerPriority do
    FQueues[a].Free;
end;

function TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.PushItem(
  const AItem: TFpThreadWorkerItem): Boolean;
begin
  Application.RemoveAsyncCalls(Self);
  inc(FTotalItemsPushed);
  if not (AItem is TFpThreadPriorityWorkerItem) then begin
    Result := FQueues[twpDefault].PushItem(AItem);
    if twpDefault < FLowestAvail then
      FLowestAvail := twpDefault;
  end
  else begin
    Result := FQueues[TFpThreadPriorityWorkerItem(AItem).FPriority].PushItem(AItem);
    if TFpThreadPriorityWorkerItem(AItem).FPriority < FLowestAvail then
      FLowestAvail := TFpThreadPriorityWorkerItem(AItem).FPriority;
  end;
end;

function TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.PopItem(out
  AItem: TFpThreadWorkerItem): Boolean;
begin
  Result := FQueues[FLowestAvail].PopItem(AItem);
  while (not Result) and (FLowestAvail < high(FLowestAvail)) do begin
    inc(FLowestAvail);
    Result := FQueues[FLowestAvail].PopItem(AItem);
  end;
  if Result then begin
    inc(FTotalItemsPopped)
  end
  else begin
    // IDLE => there is only one worker thread, so no other items are running
    if Assigned(FOnQueueIdle) then
      Application.QueueAsyncCall(@DoOnIdle, 0);
  end;
  assert(result or (TotalItemsPushed=TotalItemsPopped), 'TFpThreadPriorityWorkerQueue.TFpDbgPriorytyFifoQueue.PopItem: result or (TotalItemsPushed=TotalItemsPopped)');
end;

{ TFpThreadPriorityWorkerQueue }

function TFpThreadPriorityWorkerQueue.GetOnQueueIdle: TThreadMethod;
begin
  Result := TFpDbgPriorytyFifoQueue(FifoQueue).FOnQueueIdle;
end;

procedure TFpThreadPriorityWorkerQueue.SetOnQueueIdle(AValue: TThreadMethod);
begin
  TFpDbgPriorytyFifoQueue(FifoQueue).FOnQueueIdle := AValue;
end;

function TFpThreadPriorityWorkerQueue.CreateFifoQueue(AQueueDepth: Integer
  ): TLazTypedFifoQueue;
begin
  Result := TFpDbgPriorytyFifoQueue.Create(AQueueDepth);
end;

constructor TFpThreadPriorityWorkerQueue.Create(AQueueDepth: Integer;
  PushTimeout: cardinal; PopTimeout: cardinal);
begin
  inherited Create(AQueueDepth, PushTimeout, PopTimeout);
  FLogGroup := FPDBG_QUEUE;
end;

procedure TFpThreadPriorityWorkerQueue.Lock;
begin
  inherited Lock;
end;

procedure TFpThreadPriorityWorkerQueue.Unlock;
begin
  inherited Unlock;
end;

function TFpThreadPriorityWorkerQueue.Count: Integer;
begin
  Result := TotalItemsPushed - TotalItemsPopped;
end;

initialization
  FPDBG_QUEUE := DebugLogger.FindOrRegisterLogGroup('FPDBG_QUEUE' {$IFDEF FPDBG_QUEUE} , True {$ENDIF} );
end.


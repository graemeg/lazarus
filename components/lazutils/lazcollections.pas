{
 *****************************************************************************
  This file is part of LazUtils.

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit lazCollections;

{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}

interface

uses
  sysutils, math, syncobjs,
  // LazUtils
  LazSysUtils;

type

  PPRTLEvent = ^PRTLEvent;

  { TWaitableSection }

  TWaitableSection = record
  strict private
    FEventPtr: PPRTLEvent;
    procedure WaitForLeave(AnEventCache: PPRTLEvent);
  private const
    SECTION_ENTERED_INDICATOR = Pointer(1);
  public
    function  GetCachedOrNewEvent(AnEventCache: PPRTLEvent): PRTLEvent; inline;
    procedure FreeOrCacheEvent(AnEventCache: PPRTLEvent; AnEvent: PRTLEvent); inline;
    function EnterOrWait(AnEventCache: PPRTLEvent = nil): Boolean; inline;
    procedure Leave;  // if enter returned true
  end;

  { TLazMonitor }

  TLazMonitor = class(TCriticalSection)
  private
    FSpinCount: integer;
    class var FDefaultSpinCount: integer;
    class function GetDefaultSpinCount: integer; static;
    class procedure SetDefaultSpinCount(AValue: integer); static;
    function GetSpinCount: integer;
    procedure SetSpinCount(AValue: integer);
  public
    constructor create;
    procedure Acquire; override;
    property SpinCount: integer read GetSpinCount write SetSpinCount;
    class property DefaultSpinCount: integer read GetDefaultSpinCount write SetDefaultSpinCount;
  end;

  { TLazFifoQueue }

  generic TLazFifoQueue<T> = class
  private
    FList: array of T;
    FQueueSize: integer;
  protected
    FTotalItemsPopped: QWord;
    FTotalItemsPushed: QWord;
    function GetIsEmpty: Boolean; virtual;
    function GetIsFull: Boolean; virtual;
  public
    constructor create(AQueueDepth: Integer = 10);
    procedure Grow(ADelta: integer);
    function PushItem(const AItem: T): Boolean; virtual;
    function PopItem(out AItem: T): Boolean; virtual;
    property QueueSize: integer read FQueueSize;
    property TotalItemsPopped: QWord read FTotalItemsPopped;
    property TotalItemsPushed: QWord read FTotalItemsPushed;
    property IsEmpty: Boolean read GetIsEmpty;
    property IsFull: Boolean read GetIsFull;
  end;

  { TLazThreadedQueue }

  generic TLazThreadedQueue<T> = class
  protected
  type
    TLazTypedFifoQueue = specialize TLazFifoQueue<T>;
  private
    FMonitor: TLazMonitor;
    FFifoQueue: TLazTypedFifoQueue;
    FPushTimeout: Cardinal;
    FPopTimeout: Cardinal;
    FHasRoomEvent: PRTLEvent;
    FHasItemEvent: PRTLEvent;
    FShutDown: boolean;
    function GetQueueSize: integer; inline;
    function GetTotalItemsPopped: QWord; inline;
    function GetTotalItemsPushed: QWord; inline;
    function TryPushItem(const AItem: T): boolean; inline;
    function TryPopItem(out AItem: T): boolean; inline;
  protected
    function TryPushItemUnprotected(const AItem: T): boolean;
    function TryPopItemUnprotected(out AItem: T): boolean;
    procedure Lock;
    procedure Unlock;
    function CreateFifoQueue(AQueueDepth: Integer): TLazTypedFifoQueue; virtual;
    property FifoQueue: TLazTypedFifoQueue read FFifoQueue;
  public
    constructor create(AQueueDepth: Integer = 10; PushTimeout: cardinal = INFINITE; PopTimeout: cardinal = INFINITE);
    destructor Destroy; override;
    procedure Grow(ADelta: integer);
    function PushItem(const AItem: T): TWaitResult;
    function PopItem(out AItem: T): TWaitResult;
    function PopItemTimeout(out AItem: T; Timeout: cardinal): TWaitResult;
    procedure DoShutDown;
    property QueueSize: integer read GetQueueSize;
    property TotalItemsPopped: QWord read GetTotalItemsPopped;
    property TotalItemsPushed: QWord read GetTotalItemsPushed;
    property ShutDown: boolean read FShutDown;
  end;


implementation

{ TWaitableSection }

procedure TWaitableSection.WaitForLeave(AnEventCache: PPRTLEvent);
var
  Evnt: PRTLEvent;
  ExistingEvntPtr: PPRTLEvent;
begin
  Evnt := GetCachedOrNewEvent(AnEventCache);
  ExistingEvntPtr := InterlockedExchange(FEventPtr, @Evnt);

  if ExistingEvntPtr = nil then begin
    // section has been left already
    ExistingEvntPtr := InterlockedExchange(FEventPtr, nil);
    if ExistingEvntPtr <> @Evnt then begin
      // An other thread has our event, and is waitig
      RTLEventSetEvent(ExistingEvntPtr^);
      RTLEventWaitFor(Evnt);
    end;
    FreeOrCacheEvent(AnEventCache, Evnt);
    exit;
  end;

  // wait for our signal
  RTLEventWaitFor(Evnt);

  if ExistingEvntPtr <> SECTION_ENTERED_INDICATOR then
    RTLEventSetEvent(ExistingEvntPtr^);
end;

function TWaitableSection.GetCachedOrNewEvent(AnEventCache: PPRTLEvent
  ): PRTLEvent;
begin
  Result := nil;
  if AnEventCache <> nil then
    Result := InterlockedExchange(AnEventCache^, nil);
  if Result = nil then
    Result := RTLEventCreate
  else
    RTLEventResetEvent(Result);
end;

procedure TWaitableSection.FreeOrCacheEvent(AnEventCache: PPRTLEvent;
  AnEvent: PRTLEvent);
begin
  if AnEventCache <> nil then
    AnEvent := InterlockedExchange(AnEventCache^, AnEvent);
  if AnEvent <> nil then
    RTLEventDestroy(AnEvent);
end;

function TWaitableSection.EnterOrWait(AnEventCache: PPRTLEvent): Boolean;
var
  ExistingEvntPtr: PPRTLEvent;
begin
  ExistingEvntPtr := InterlockedCompareExchange(FEventPtr, SECTION_ENTERED_INDICATOR, nil);
  Result := ExistingEvntPtr = nil;
  if Result then
    exit;

  WaitForLeave(AnEventCache);
end;

procedure TWaitableSection.Leave;
var
  ExistingEvntPtr: PPRTLEvent;
begin
  ExistingEvntPtr := InterlockedExchange(FEventPtr, nil);
  assert(ExistingEvntPtr <> nil);

  if ExistingEvntPtr <> SECTION_ENTERED_INDICATOR then
    RTLEventSetEvent(ExistingEvntPtr^);
end;

{ TLazMonitor }

function TLazMonitor.GetSpinCount: integer;
begin
  result := FSpinCount;
end;

procedure TLazMonitor.SetSpinCount(AValue: integer);
begin
  InterLockedExchange(FSpinCount, AValue);
end;

class function TLazMonitor.GetDefaultSpinCount: integer; static;
begin
  result := FDefaultSpinCount;
end;

class procedure TLazMonitor.SetDefaultSpinCount(AValue: integer); static;
begin
  InterLockedExchange(FDefaultSpinCount, AValue);
end;

constructor TLazMonitor.create;
begin
  FSpinCount:=FDefaultSpinCount;
  inherited;
end;

procedure TLazMonitor.Acquire;
const
  YieldTreshold = 10;
  Sleep1Treshold = 20;
  Sleep0Treshold = 5;
var
  i,j: integer;
  Waitcount: integer;
  ASpinCount: integer;
  Sp: integer;
begin
  ASpinCount:=FSpinCount;
  for Sp := 0 to ASpinCount-1 do
  begin
    Waitcount:=1;
    for i := 0 to YieldTreshold-1 do
      begin
      if TryEnter then
        Exit;
      {$PUSH}
      {$OPTIMIZATION OFF}
      for j := 0 to Waitcount-1 do
        begin
        end;
      {$POP}
      Waitcount:=Waitcount*2;
      end;

    for i := 0 to Sleep1Treshold-1 do
      begin
      if TryEnter then
        Exit;
      sleep(1);
      end;

    for i := 0 to Sleep0Treshold do
      begin
      if TryEnter then
        Exit;
      sleep(0);
      end;
  end;

  inherited Acquire;
end;

{ TLazFifoQueue }

function TLazFifoQueue.GetIsEmpty: Boolean;
begin
  result := FTotalItemsPushed = FTotalItemsPopped;
end;

function TLazFifoQueue.GetIsFull: Boolean;
begin
  result := FTotalItemsPushed - FTotalItemsPopped = FQueueSize;
end;

constructor TLazFifoQueue.create(AQueueDepth: Integer);
begin
  Grow(AQueueDepth);
end;

procedure TLazFifoQueue.Grow(ADelta: integer);
var
  NewList: array of T;
  c: Integer;
  i: QWord;
begin
  c:=Max(FQueueSize + ADelta, Integer(FTotalItemsPushed - FTotalItemsPopped));
  setlength(NewList{%H-}, c);
  i:=FTotalItemsPopped;
  while i < FTotalItemsPushed do begin
    NewList[i mod c] := FList[i mod FQueueSize];
    inc(i);
  end;

  FList := NewList;
  FQueueSize:=c;
end;

function TLazFifoQueue.PushItem(const AItem: T): Boolean;
begin
  result := FTotalItemsPushed-FTotalItemsPopped<FQueueSize;
  if result then
    begin
    FList[FTotalItemsPushed mod FQueueSize]:=AItem;
    inc(FTotalItemsPushed);
    end;
end;

function TLazFifoQueue.PopItem(out AItem: T): Boolean;
begin
  result := FTotalItemsPushed>FTotalItemsPopped;
  if result then
    begin
    AItem := FList[FTotalItemsPopped mod FQueueSize];
    inc(FTotalItemsPopped);
    end;
end;

{ TThreadedQueue }

function TLazThreadedQueue.TryPushItem(const AItem: T): boolean;
begin
  FMonitor.Enter;
  try
    result := TryPushItemUnprotected(AItem);
  finally
    FMonitor.Leave;
  end;
end;

function TLazThreadedQueue.GetQueueSize: integer;
begin
  Result := FFifoQueue.QueueSize;
end;

function TLazThreadedQueue.GetTotalItemsPopped: QWord;
begin
  Result := FFifoQueue.TotalItemsPopped;
end;

function TLazThreadedQueue.GetTotalItemsPushed: QWord;
begin
  Result := FFifoQueue.TotalItemsPushed;
end;

function TLazThreadedQueue.TryPopItem(out AItem: T): boolean;
begin
  FMonitor.Enter;
  try
    result := TryPopItemUnprotected(AItem);
  finally
    FMonitor.Leave;
  end;
end;

function TLazThreadedQueue.TryPushItemUnprotected(const AItem: T): boolean;
begin
  result := FFifoQueue.PushItem(AItem);
  if result then
    RTLeventSetEvent(FHasItemEvent);

  RTLeventResetEvent(FHasRoomEvent);
  if ShutDown or not FFifoQueue.IsFull then
    RTLeventSetEvent(FHasRoomEvent);
end;

function TLazThreadedQueue.TryPopItemUnprotected(out AItem: T): boolean;
begin
  result := FFifoQueue.PopItem(AItem);
  if result then
    RTLeventSetEvent(FHasRoomEvent);

  RTLeventResetEvent(FHasItemEvent);
  if ShutDown or not FFifoQueue.IsEmpty then
    RTLeventSetEvent(FHasItemEvent);
end;

procedure TLazThreadedQueue.Lock;
begin
  FMonitor.Enter;
end;

procedure TLazThreadedQueue.Unlock;
begin
  FMonitor.Leave;
end;

function TLazThreadedQueue.CreateFifoQueue(AQueueDepth: Integer
  ): TLazTypedFifoQueue;
begin
  result := TLazTypedFifoQueue.create(AQueueDepth);
end;

constructor TLazThreadedQueue.create(AQueueDepth: Integer; PushTimeout: cardinal; PopTimeout: cardinal);
begin
  FMonitor:=TLazMonitor.create;
  FFifoQueue := CreateFifoQueue(AQueueDepth);
  Grow(AQueueDepth);
  FHasRoomEvent:=RTLEventCreate;
  RTLeventSetEvent(FHasRoomEvent);
  FHasItemEvent:=RTLEventCreate;
  FPushTimeout:=PushTimeout;
  FPopTimeout:=PopTimeout;
end;

destructor TLazThreadedQueue.Destroy;
begin
  DoShutDown;
  RTLeventdestroy(FHasRoomEvent);
  RTLeventdestroy(FHasItemEvent);
  FMonitor.Free;
  FFifoQueue.Free;
  inherited Destroy;
end;

procedure TLazThreadedQueue.Grow(ADelta: integer);
var
  NewList: array of T;
  c: Integer;
  i: QWord;
begin
  FMonitor.Enter;
  try
    FFifoQueue.Grow(ADelta);
  finally
    FMonitor.Leave;
  end;
end;

function TLazThreadedQueue.PushItem(const AItem: T): TWaitResult;
var
  tc, ltc: int64;
begin
  if (FPushTimeout<>INFINITE) and (FPushTimeout<>0) then
    begin
    tc := GetTickCount64;
    ltc := 0;
    end;
  if TryPushItem(AItem) then
    result := wrSignaled
  else
    begin
    repeat
    if FPushTimeout=0 then
      begin
      result := wrTimeout;
      Exit;
      end
    else if FPushTimeout=INFINITE then
      RTLeventWaitFor(FHasRoomEvent)
    else
      begin
      RTLeventWaitFor(FHasRoomEvent, FPushTimeout - ltc);
    ltc := GetTickCount64-tc;
      if ltc > FPushTimeout then
        begin
        result := wrTimeout;
        Exit;
        end;
      end;
    if FShutDown then
      begin
      RTLeventResetEvent(FHasRoomEvent);
      RTLeventResetEvent(FHasItemEvent);
      RTLeventSetEvent(FHasRoomEvent);
      RTLeventSetEvent(FHasItemEvent);
      result := wrAbandoned;
      exit;
      end;
    until TryPushItem(AItem);
    result := wrSignaled;
    end;
end;

function TLazThreadedQueue.PopItem(out AItem: T): TWaitResult;
begin
  result := PopItemTimeout(AItem, FPopTimeout);
end;

function TLazThreadedQueue.PopItemTimeout(out AItem: T; Timeout: cardinal): TWaitResult;
var
  tc, ltc: int64;
begin
  if (Timeout<>INFINITE) and (Timeout<>0) then
    begin
    tc := GetTickCount64;
    ltc := 0;
    end;
  if TryPopItem(AItem) then
    result := wrSignaled
  else
    begin
    if Timeout=0 then
      begin
      result := wrTimeout;
      Exit;
      end;
    repeat
    if Timeout=INFINITE then
      RTLeventWaitFor(FHasItemEvent)
    else
      begin
      RTLeventWaitFor(FHasItemEvent, Timeout - ltc);
      ltc := GetTickCount64-tc;
      if ltc > Timeout then
        begin
        result := wrTimeout;
        Exit;
        end;
      end;
    if FShutDown then
      begin
      RTLeventResetEvent(FHasRoomEvent);
      RTLeventResetEvent(FHasItemEvent);
      RTLeventSetEvent(FHasRoomEvent);
      RTLeventSetEvent(FHasItemEvent);
      result := wrAbandoned;
      exit;
      end;
    until TryPopItem(AItem);
    result := wrSignaled;
    end;
end;

procedure TLazThreadedQueue.DoShutDown;
begin
  FShutDown:=true;
  RTLeventSetEvent(FHasRoomEvent);
  RTLeventSetEvent(FHasItemEvent);
end;

initialization
  TLazMonitor.DefaultSpinCount:=3;
end.


unit FpGdbmiDebugger;

{$mode objfpc}{$H+}

{$IFdef MSWindows}
{$DEFINE  WithWinMemReader}
{$ENDIF}

interface

uses
  {$IFdef WithWinMemReader}
  windows,
  {$ENDIF}
  Classes, sysutils, math, FpdMemoryTools, FpDbgInfo, FpDbgClasses,
  GDBMIDebugger, DbgIntfBaseTypes, DbgIntfDebuggerBase, GDBMIMiscClasses,
  GDBTypeInfo, LCLProc, Forms, FpDbgLoader, FpDbgDwarf, LazLoggerBase,
  LazLoggerProfiling, LazClasses, FpPascalParser, FpPascalBuilder,
  FpErrorMessages, FpDbgDwarfDataClasses, FpDbgDwarfFreePascal, FpDbgCommon,
  MenuIntf;

type

  TFpGDBMIDebugger = class;

  TGDBMIDebuggerCommandMemReader = class(TGDBMIDebuggerCommand)
  end;

  { TFpGDBMIDbgMemReader }

  TFpGDBMIDbgMemReader = class(TFpDbgMemReaderBase)
  private
// TODO
    //FThreadId: Integer;
    //FStackFrame: Integer;
    FDebugger: TFpGDBMIDebugger;
    FCmd: TGDBMIDebuggerCommandMemReader;
  protected
    // TODO: needs to be handled by memory manager
    //FThreadId, FStackFrame: Integer;
  public
    constructor Create(ADebugger: TFpGDBMIDebugger);
    destructor Destroy; override;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    function ReadMemoryEx({%H-}AnAddress, {%H-}AnAddressSpace:{%H-} TDbgPtr; ASize: {%H-}Cardinal; ADest: Pointer): Boolean; override;
    function ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr; AContext: TFpDbgLocationContext): Boolean; override;
    function RegisterSize({%H-}ARegNum: Cardinal): Integer; override;
  end;

  { TFpGDBMIAndWin32DbgMemReader }

  TFpGDBMIAndWin32DbgMemReader = class(TFpGDBMIDbgMemReader)
  private
    hProcess: THandle;
  public
    destructor Destroy; override;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    //function ReadRegister(ARegNum: Integer; out AValue: TDbgPtr): Boolean; override;
    procedure OpenProcess(APid: Cardinal);
    procedure CloseProcess;
  end;

const
  MAX_CTX_CACHE = 10;

type
  { TFpGDBMIDebugger }

  TFpGDBMIDebugger = class(TGDBMIDebugger)
  private
    FWatchEvalList: TList;
    FImageLoaderList: TDbgImageLoaderList;
    FDwarfInfo: TFpDwarfInfo;
    FPrettyPrinter: TFpPascalPrettyPrinter;
    FMemReader: TFpGDBMIDbgMemReader;
    FMemManager: TFpDbgMemManager;
    // cache last context
    FLastContext: array [0..MAX_CTX_CACHE-1] of TFpDbgSymbolScope;
    FLockUnLoadDwarf: integer;
    FUnLoadDwarfNeeded: Boolean;
  protected
    function CreateCommandStartDebugging(AContinueCommand: TGDBMIDebuggerCommand): TGDBMIDebuggerCommandStartDebugging; override;
    function CreateLineInfo: TDBGLineInfo; override;
    function  CreateWatches: TWatchesSupplier; override;
    function  CreateLocals: TLocalsSupplier; override;
    procedure DoState(const OldState: TDBGState); override;
    function  HasDwarf: Boolean;
    procedure LoadDwarf;
    procedure UnLoadDwarf;
    procedure LockUnLoadDwarf;
    procedure UnLockUnLoadDwarf;
    function  RequestCommand(const ACommand: TDBGCommand;
              const AParams: array of const;
              const ACallback: TMethod): Boolean; override;
    procedure QueueCommand(const ACommand: TGDBMIDebuggerCommand; ForceQueue: Boolean = False);

    procedure GetCurrentContext(out AThreadId, AStackFrame: Integer);
    function  GetLocationForContext(AThreadId, AStackFrame: Integer): TDBGPtr;
    function  GetInfoContextForContext(AThreadId, AStackFrame: Integer): TFpDbgSymbolScope;
    property CurrentCommand;
    property TargetPID;
  protected
    procedure ClearWatchEvalList;
    procedure DoWatchFreed(Sender: TObject);
    function EvaluateExpression(AWatchValue: TWatchValue;
                                AExpression: String;
                                out AResText: String;
                                out ATypeInfo: TDBGType;
                                EvalFlags: TDBGEvaluateFlags = []): Boolean;
    property CurrentThreadId;
    property CurrentStackFrame;
  public
    class function Caption: String; override;
  public
    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
  end;

procedure Register;

implementation

var
  DBG_VERBOSE, DBG_ERRORS: PLazLoggerLogGroup;

type

  { TFpGDBMIDebuggerCommandStartDebugging }

  TFpGDBMIDebuggerCommandStartDebugging = class(TGDBMIDebuggerCommandStartDebugging)
  protected
    function DoExecute: Boolean; override;
  end;

  TFPGDBMIWatches = class;

  { TFpGDBMIDebuggerCommandEvaluate }

  TFpGDBMIDebuggerCommandEvaluate = class(TGDBMIDebuggerCommand)
  private
    FOwner: TFPGDBMIWatches;
  protected
    function DoExecute: Boolean; override;
    procedure DoFree; override;
    procedure DoCancel; override;
    procedure DoLockQueueExecute; override;
    procedure DoUnLockQueueExecute; override;
  public
    constructor Create(AOwner: TFPGDBMIWatches);
  end;

  { TFPGDBMIWatches }

  TFPGDBMIWatches = class(TGDBMIWatches)
  private
    FWatchEvalLock: Integer;
    FNeedRegValues: Boolean;
    FEvaluationCmdObj: TFpGDBMIDebuggerCommandEvaluate;
  protected
    function  FpDebugger: TFpGDBMIDebugger;
    //procedure DoStateChange(const AOldState: TDBGState); override;
    procedure ProcessEvalList;
    procedure QueueCommand;
    procedure InternalRequestData(AWatchValue: TWatchValue); override;
  public
  end;

  TFPGDBMILocals = class;

  { TFpGDBMIDebuggerCommandLocals }

  TFpGDBMIDebuggerCommandLocals = class(TGDBMIDebuggerCommand)
  private
    FOwner: TFPGDBMILocals;
    FLocals: TLocals;
    procedure DoLocalsFreed(Sender: TObject);
  protected
    function DoExecute: Boolean; override;
    procedure DoLockQueueExecute; override;
    procedure DoUnLockQueueExecute; override;
  public
    constructor Create(AOwner: TFPGDBMILocals; ALocals: TLocals);
  end;

  { TFPGDBMILocals }

  TFPGDBMILocals = class(TGDBMILocals)
  private
    procedure ProcessLocals(ALocals: TLocals);
  protected
    function  FpDebugger: TFpGDBMIDebugger;
  public
    procedure RequestData(ALocals: TLocals); override;
  end;

  { TFpGDBMILineInfo }

  TFpGDBMILineInfo = class(TDBGLineInfo) //class(TGDBMILineInfo)
  private
    FRequestedSources: TStringList;
  protected
    function  FpDebugger: TFpGDBMIDebugger;
    procedure DoStateChange(const {%H-}AOldState: TDBGState); override;
    procedure ClearSources;
  public
    constructor Create(const ADebugger: TDebuggerIntf);
    destructor Destroy; override;
    function Count: Integer; override;
    function HasAddress(const AIndex: Integer; const ALine: Integer): Boolean; override;
    function GetInfo(AAdress: TDbgPtr; out ASource, ALine, AOffset: Integer): Boolean; override;
    function IndexOf(const ASource: String): integer; override;
    procedure Request(const ASource: String); override;
    procedure Cancel(const ASource: String); override;
  end;

var
  MenuCmd: TIDEMenuCommand;
  CurrentDebugger: TFpGDBMIDebugger;
  UseGDB: Boolean;

procedure IDEMenuClicked(Sender: TObject);
begin
  UseGDB := MenuCmd.Checked;
  if (CurrentDebugger <> nil) and (CurrentDebugger.Watches <> nil) then
    CurrentDebugger.Watches.CurrentWatches.ClearValues;
  if (CurrentDebugger <> nil) and (CurrentDebugger.Locals <> nil) then
    CurrentDebugger.Locals.CurrentLocalsList.Clear;
end;

// This Accessor hack is temporarilly needed / the final version will not show gdb data
type TWatchValueHack = class(TWatchValue) end;
procedure MarkWatchValueAsGdb(AWatchValue: TWatchValue);
begin
  AWatchValue.Value := '{GDB:}' + AWatchValue.Value;
  TWatchValueHack(AWatchValue).DoDataValidityChanged(ddsRequested);
end;

{ TFpGDBMIDebuggerCommandLocals }

procedure TFpGDBMIDebuggerCommandLocals.DoLocalsFreed(Sender: TObject);
begin
  FLocals := nil;
end;

function TFpGDBMIDebuggerCommandLocals.DoExecute: Boolean;
begin
  if FLocals <> nil then begin
    FOwner.ProcessLocals(FLocals);
    FLocals.RemoveFreeNotification(@DoLocalsFreed);
  end;
  Result := True;
end;

procedure TFpGDBMIDebuggerCommandLocals.DoLockQueueExecute;
begin
  //
end;

procedure TFpGDBMIDebuggerCommandLocals.DoUnLockQueueExecute;
begin
  //
end;

constructor TFpGDBMIDebuggerCommandLocals.Create(AOwner: TFPGDBMILocals; ALocals: TLocals);
begin
  inherited Create(AOwner.FpDebugger);
  FOwner := AOwner;
  FLocals := ALocals;
  FLocals.AddFreeNotification(@DoLocalsFreed);
  Priority := 1; // before watches
end;

{ TFPGDBMILocals }

procedure TFPGDBMILocals.ProcessLocals(ALocals: TLocals);
var
  Ctx: TFpDbgSymbolScope;
  ProcVal: TFpValue;
  i: Integer;
  m: TFpValue;
  n, v: String;
begin
  FpDebugger.LockUnLoadDwarf;
  try
    Ctx := FpDebugger.GetInfoContextForContext(ALocals.ThreadId, ALocals.StackFrame);
    if (Ctx = nil) or (Ctx.SymbolAtAddress = nil) then begin
      ALocals.SetDataValidity(ddsInvalid);
      exit;
    end;

    ProcVal := Ctx.ProcedureAtAddress;

    if (ProcVal = nil) then begin
      ALocals.SetDataValidity(ddsInvalid);
      exit;
    end;
    FpDebugger.FPrettyPrinter.AddressSize := ctx.SizeOfAddress;
    FpDebugger.FPrettyPrinter.Context := ctx.LocationContext;

    ALocals.Clear;
    for i := 0 to ProcVal.MemberCount - 1 do begin
      m := ProcVal.Member[i];
      if m <> nil then begin
        if m.DbgSymbol <> nil then
          n := m.DbgSymbol.Name
        else
          n := '';
        FpDebugger.FPrettyPrinter.PrintValue(v, m);
        m.ReleaseReference;
        ALocals.Add(n, v);
      end;
    end;
    ProcVal.ReleaseReference;
    ALocals.SetDataValidity(ddsValid);
  finally
    FpDebugger.UnLockUnLoadDwarf;
  end;
end;

function TFPGDBMILocals.FpDebugger: TFpGDBMIDebugger;
begin
  Result := TFpGDBMIDebugger(Debugger);
end;

procedure TFPGDBMILocals.RequestData(ALocals: TLocals);
var
  LocalsCmdObj: TFpGDBMIDebuggerCommandLocals;
begin
  if UseGDB then begin
    inherited RequestData(ALocals);
    exit;
  end;

  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    Exit;
  end;

  FpDebugger.Threads.CurrentThreads.Count; // trigger threads, in case

  // Join the queue, registers and threads are needed first
  LocalsCmdObj := TFpGDBMIDebuggerCommandLocals.Create(Self, ALocals);
  LocalsCmdObj.Properties := [dcpCancelOnRun];
  // If a ExecCmd is running, then defer exec until the exec cmd is done
  FpDebugger.QueueCommand(LocalsCmdObj, ForceQueuing);
end;

{ TFpGDBMIDebuggerCommandEvaluate }

function TFpGDBMIDebuggerCommandEvaluate.DoExecute: Boolean;
begin
  FOwner.FEvaluationCmdObj := nil;
  FOwner.ProcessEvalList;
  Result := True;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoFree;
begin
  FOwner.FEvaluationCmdObj := nil;
  inherited DoFree;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoCancel;
begin
  FOwner.FpDebugger.ClearWatchEvalList;
  FOwner.FEvaluationCmdObj := nil;
  inherited DoCancel;
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoLockQueueExecute;
begin
  //
end;

procedure TFpGDBMIDebuggerCommandEvaluate.DoUnLockQueueExecute;
begin
  //
end;

constructor TFpGDBMIDebuggerCommandEvaluate.Create(AOwner: TFPGDBMIWatches);
begin
  inherited Create(AOwner.FpDebugger);
  FOwner := AOwner;
  //Priority := 0;
end;

{ TFpGDBMIAndWin32DbgMemReader }

destructor TFpGDBMIAndWin32DbgMemReader.Destroy;
begin
  CloseProcess;
  inherited Destroy;
end;

function TFpGDBMIAndWin32DbgMemReader.ReadMemory(AnAddress: TDbgPtr;
  ASize: Cardinal; ADest: Pointer): Boolean;
var
  BytesRead: SizeUInt;
begin
  {$IFdef MSWindows}
  Result := ReadProcessMemory(
    hProcess,
    {%H-}Pointer(AnAddress),
    ADest, ASize,
    BytesRead) and
  (BytesRead = ASize);
//DebugLn(['*&*&*&*& ReadMem ', dbgs(Result), '  at ', AnAddress, ' Size ',ASize, ' br=',BytesRead, ' b1',PBYTE(ADest)^]);
  {$ELSE}
  Result := inherited ReadMemory(AnAddress, ASize, ADest);
  {$ENDIF}
end;

procedure TFpGDBMIAndWin32DbgMemReader.OpenProcess(APid: Cardinal);
begin
  {$IFdef MSWindows}
  debugln(DBG_VERBOSE, ['OPEN process ',APid]);
  if APid <> 0 then
    hProcess := windows.OpenProcess(PROCESS_CREATE_THREAD or PROCESS_QUERY_INFORMATION or PROCESS_VM_OPERATION or PROCESS_VM_WRITE or PROCESS_VM_READ, False, APid);
  {$ENDIF}
end;

procedure TFpGDBMIAndWin32DbgMemReader.CloseProcess;
begin
  {$IFdef MSWindows}
  if hProcess <> 0 then
    CloseHandle(hProcess);
  {$ENDIF}
end;

{ TFpGDBMIDbgMemReader }

constructor TFpGDBMIDbgMemReader.Create(ADebugger: TFpGDBMIDebugger);
begin
  FDebugger := ADebugger;
  FCmd := TGDBMIDebuggerCommandMemReader.Create(ADebugger);
end;

destructor TFpGDBMIDbgMemReader.Destroy;
begin
  FCmd.ReleaseReference;
  inherited Destroy;
end;

function TFpGDBMIDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal;
  ADest: Pointer): Boolean;
var
  R: TGDBMIExecResult;
  MemDump: TGDBMIMemoryDumpResultList;
  i: Integer;
begin
  Result := False;

  if not FCmd.ExecuteCommand('-data-read-memory %u x 1 1 %u', [AnAddress, ASize], R, [cfNoThreadContext, cfNoStackContext])
  then
    exit;
  if R.State = dsError then exit;

  MemDump := TGDBMIMemoryDumpResultList.Create(R);
  if MemDump.Count <> ASize then exit;

  for i := 0 to MemDump.Count - 1 do begin
    PByte(ADest + i)^ := Byte(MemDump.ItemNum[i]);
  end;

  MemDump.Free;
  Result := True;

debugln(DBG_VERBOSE, ['TFpGDBMIDbgMemReader.ReadMemory ', dbgs(AnAddress), '  ', dbgMemRange(ADest, ASize)]);
end;

function TFpGDBMIDbgMemReader.ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr;
  ASize: Cardinal; ADest: Pointer): Boolean;
begin
  Result := False;
end;

function TFpGDBMIDbgMemReader.ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr;
  AContext: TFpDbgLocationContext): Boolean;
var
  rname: String;
  v: String;
  i: Integer;
  Reg: TRegisters;
  RegVObj: TRegisterDisplayValue;
begin
  Result := False;
  // WINDOWS gdb dwarf names
  if FDebugger.TargetWidth = 64 then
    case ARegNum of
       0:  rname := 'RAX'; // RAX
       1:  rname := 'RDX'; // RDX
       2:  rname := 'RCX'; // RCX
       3:  rname := 'RBX'; // RBX
       4:  rname := 'RSI';
       5:  rname := 'RDI';
       6:  rname := 'RBP';
       7:  rname := 'RSP';
       8:  rname := 'R8'; // R8D , but gdb uses R8
       9:  rname := 'R9';
      10:  rname := 'R10';
      11:  rname := 'R11';
      12:  rname := 'R12';
      13:  rname := 'R13';
      14:  rname := 'R14';
      15:  rname := 'R15';
      16:  rname := 'RIP';
      else
        exit;
    end
  else
    case ARegNum of
       0:  rname := 'EAX'; // RAX
       1:  rname := 'ECX'; // RDX
       2:  rname := 'EDX'; // RCX
       3:  rname := 'EBX'; // RBX
       4:  rname := 'ESP';
       5:  rname := 'EBP';
       6:  rname := 'ESI';
       7:  rname := 'EDI';
       8:  rname := 'EIP';
      else
        exit;
    end;
  assert(AContext <> nil, 'TFpGDBMIDbgMemReader.ReadRegister: AContext <> nil');
  Reg := FDebugger.Registers.CurrentRegistersList[AContext.ThreadId, AContext.StackFrame];
  for i := 0 to Reg.Count - 1 do
    if UpperCase(Reg[i].Name) = rname then
      begin
        RegVObj := Reg[i].ValueObjFormat[rdDefault];
        if RegVObj <> nil then
          v := RegVObj.Value[rdDefault]
        else
          v := '';
        if pos(' ', v) > 1 then v := copy(v, 1, pos(' ', v)-1);
debugln(DBG_VERBOSE, ['TFpGDBMIDbgMemReader.ReadRegister ',rname, '  ', v]);
        Result := true;
        try
          AValue := StrToQWord(v);
        except
          Result := False;
        end;
        exit;
      end;
end;

function TFpGDBMIDbgMemReader.RegisterSize(ARegNum: Cardinal): Integer;
begin
  if FDebugger.TargetWidth = 64 then
    Result := 8 // for the very few supported...
  else
    Result := 4; // for the very few supported...
end;

{ TFPGDBMIWatches }

function TFPGDBMIWatches.FpDebugger: TFpGDBMIDebugger;
begin
  Result := TFpGDBMIDebugger(Debugger);
end;

procedure TFPGDBMIWatches.ProcessEvalList;
var
  WatchValue: TWatchValue;
  ResTypeInfo: TDBGType;
  ResText: String;

  function IsWatchValueAlive: Boolean;
  begin
    Result := (FpDebugger.FWatchEvalList.Count > 0) and (FpDebugger.FWatchEvalList[0] = Pointer(WatchValue));
  end;
begin
  if FNeedRegValues then begin
    FNeedRegValues := False;
    FpDebugger.Registers.CurrentRegistersList[FpDebugger.CurrentThreadId, FpDebugger.CurrentStackFrame].Count;
    QueueCommand;
    exit;
  end;

  if FWatchEvalLock > 0 then
    exit;
  inc(FWatchEvalLock);
  FpDebugger.LockUnLoadDwarf;
  try // TODO: if the stack/thread is changed, registers will be wrong
    while (FpDebugger.FWatchEvalList.Count > 0) and (FEvaluationCmdObj = nil) do begin
      try
        WatchValue := TWatchValue(FpDebugger.FWatchEvalList[0]);
        ResTypeInfo := nil;
        if UseGDB then begin
          inherited InternalRequestData(WatchValue);
          if IsWatchValueAlive then
            MarkWatchValueAsGdb(WatchValue);
        end
        else
        if not FpDebugger.EvaluateExpression(WatchValue, WatchValue.Expression, ResText, ResTypeInfo)
        then begin
          if IsWatchValueAlive then    debugln(['TFPGDBMIWatches.InternalRequestData FAILED ', WatchValue.Expression]);
          if IsWatchValueAlive then
            inherited InternalRequestData(WatchValue);
          if IsWatchValueAlive then
            MarkWatchValueAsGdb(WatchValue);
        end;
      finally
        if IsWatchValueAlive then begin
          WatchValue.RemoveFreeNotification(@FpDebugger.DoWatchFreed);
          FpDebugger.FWatchEvalList.Remove(pointer(WatchValue));
        end;
        Application.ProcessMessages;
      end;
    end;
  finally
    dec(FWatchEvalLock);
    FpDebugger.UnLockUnLoadDwarf;
  end;
end;

procedure TFPGDBMIWatches.QueueCommand;
begin
  FEvaluationCmdObj := TFpGDBMIDebuggerCommandEvaluate.Create(Self);
  FEvaluationCmdObj.Properties := [dcpCancelOnRun];
  // If a ExecCmd is running, then defer exec until the exec cmd is done
  FpDebugger.QueueCommand(FEvaluationCmdObj, ForceQueuing);
end;

procedure TFPGDBMIWatches.InternalRequestData(AWatchValue: TWatchValue);
begin
  if (Debugger = nil) or not(Debugger.State in [dsPause, dsInternalPause]) then begin
    AWatchValue.Validity := ddsInvalid;
    Exit;
  end;

  AWatchValue.AddFreeNotification(@FpDebugger.DoWatchFreed); // we may call gdb
  FpDebugger.FWatchEvalList.Add(pointer(AWatchValue));

  if FEvaluationCmdObj <> nil then exit;

  FpDebugger.Threads.CurrentThreads.Count; // trigger threads, in case
  if     FpDebugger.Registers.CurrentRegistersList[FpDebugger.CurrentThreadId, FpDebugger.CurrentStackFrame].Count = 0 then   // trigger register, in case
    FNeedRegValues := True
  else
  begin
    FNeedRegValues := False;
  end;

  // Join the queue, registers and threads are needed first
  QueueCommand;
end;

{ TFpGDBMILineInfo }

function TFpGDBMILineInfo.FpDebugger: TFpGDBMIDebugger;
begin
  Result := TFpGDBMIDebugger(Debugger);
end;

procedure TFpGDBMILineInfo.DoStateChange(const AOldState: TDBGState);
begin
  //inherited DoStateChange(AOldState);
  if not (Debugger.State in [dsPause, dsInternalPause, dsRun]) then
    ClearSources;
end;

procedure TFpGDBMILineInfo.ClearSources;
begin
  FRequestedSources.Clear;
end;

constructor TFpGDBMILineInfo.Create(const ADebugger: TDebuggerIntf);
begin
  FRequestedSources := TStringList.Create;
  inherited Create(ADebugger);
end;

destructor TFpGDBMILineInfo.Destroy;
begin
  FreeAndNil(FRequestedSources);
  inherited Destroy;
end;

function TFpGDBMILineInfo.Count: Integer;
begin
  Result := FRequestedSources.Count;
end;

function TFpGDBMILineInfo.HasAddress(const AIndex: Integer; const ALine: Integer
  ): Boolean;
var
  Map: PDWarfLineMap;
  dummy: TDBGPtrArray;
begin
  Result := False;
  if not FpDebugger.HasDwarf then
    exit;
  //Result := FpDebugger.FDwarfInfo.GetLineAddress(FRequestedSources[AIndex], ALine);
  Map := PDWarfLineMap(FRequestedSources.Objects[AIndex]);
  if Map <> nil then
    Result := Map^.GetAddressesForLine(ALine, dummy, True);
end;

function TFpGDBMILineInfo.GetInfo(AAdress: TDbgPtr; out ASource, ALine,
  AOffset: Integer): Boolean;
begin
  Result := False;
  //ASource := '';
  //ALine := 0;
  //if not FpDebugger.HasDwarf then
  //  exit(nil);
  //FpDebugger.FDwarfInfo.
end;

function TFpGDBMILineInfo.IndexOf(const ASource: String): integer;
begin
  Result := FRequestedSources.IndexOf(ASource);
end;

procedure TFpGDBMILineInfo.Request(const ASource: String);
begin
  if not FpDebugger.HasDwarf then
    exit;
  FRequestedSources.AddObject(ASource, TObject(FpDebugger.FDwarfInfo.GetLineAddressMap(ASource)));
  DoChange(ASource);
end;

procedure TFpGDBMILineInfo.Cancel(const ASource: String);
begin
  //
end;


{ TFpGDBMIDebuggerCommandStartDebugging }

function TFpGDBMIDebuggerCommandStartDebugging.DoExecute: Boolean;
begin
  TFpGDBMIDebugger(FTheDebugger).LoadDwarf;
  Result := inherited DoExecute;
{$IFdef WithWinMemReader}
  TFpGDBMIAndWin32DbgMemReader(TFpGDBMIDebugger(FTheDebugger).FMemReader).OpenProcess(
    TFpGDBMIDebugger(FTheDebugger).TargetPid
  );
{$ENDIF}
end;

{ TFpGDBMIDebugger }

procedure TFpGDBMIDebugger.DoState(const OldState: TDBGState);
var
  i: Integer;
begin
  inherited DoState(OldState);
  if State in [dsStop, dsError, dsNone] then
    UnLoadDwarf;

  if OldState in [dsPause, dsInternalPause] then begin
    for i := 0 to MAX_CTX_CACHE-1 do
      ReleaseRefAndNil(FLastContext[i]);
    if not(State in [dsPause, dsInternalPause]) then
      ClearWatchEvalList;
  end;
end;

function TFpGDBMIDebugger.HasDwarf: Boolean;
begin
  Result := FDwarfInfo <> nil;
end;

procedure TFpGDBMIDebugger.LoadDwarf;
var
  AnImageLoader: TDbgImageLoader;
begin
  UnLoadDwarf;
  debugln(DBG_VERBOSE, ['TFpGDBMIDebugger.LoadDwarf ']);
  AnImageLoader := TDbgImageLoader.Create(FileName);
  if not AnImageLoader.IsValid then begin
    FreeAndNil(AnImageLoader);
    exit;
  end;
  FImageLoaderList := TDbgImageLoaderList.Create(True);
  AnImageLoader.AddToLoaderList(FImageLoaderList);
{$IFdef WithWinMemReader}
  FMemReader := TFpGDBMIAndWin32DbgMemReader.Create(Self);
{$Else}
  FMemReader := TFpGDBMIDbgMemReader.Create(Self);
{$ENDIF}
  FMemManager := TFpDbgMemManager.Create(FMemReader, TFpDbgMemConvertorLittleEndian.Create);

  FDwarfInfo := TFpDwarfInfo.Create(FImageLoaderList, FMemManager);
  FDwarfInfo.LoadCompilationUnits;
  FPrettyPrinter := TFpPascalPrettyPrinter.Create(SizeOf(Pointer));
end;

procedure TFpGDBMIDebugger.UnLoadDwarf;
begin
  if FLockUnLoadDwarf > 0 then begin
    FUnLoadDwarfNeeded := True;
    exit;
  end;
  FUnLoadDwarfNeeded := False;
  debugln(DBG_VERBOSE, ['TFpGDBMIDebugger.UnLoadDwarf ']);
  FreeAndNil(FDwarfInfo);
  FreeAndNil(FImageLoaderList);
  FreeAndNil(FMemReader);
  if FMemManager <> nil then
    FMemManager.TargetMemConvertor.Free;
  FreeAndNil(FMemManager);
  FreeAndNil(FPrettyPrinter);
end;

procedure TFpGDBMIDebugger.LockUnLoadDwarf;
begin
  inc(FLockUnLoadDwarf);
end;

procedure TFpGDBMIDebugger.UnLockUnLoadDwarf;
begin
  dec(FLockUnLoadDwarf);
  if (FLockUnLoadDwarf <= 0) and FUnLoadDwarfNeeded then
    UnLoadDwarf;
end;

function TFpGDBMIDebugger.RequestCommand(const ACommand: TDBGCommand;
  const AParams: array of const; const ACallback: TMethod): Boolean;
var
  EvalFlags: TDBGEvaluateFlags;
  ResText: String;
  ResType: TDBGType;
begin
  if (ACommand = dcEvaluate) then begin
    EvalFlags := [];
    EvalFlags := TDBGEvaluateFlags(AParams[1].VInteger);
    Result := False;
    if (HasDwarf) and (not UseGDB) then begin
      Result := EvaluateExpression(nil, String(AParams[0].VAnsiString),
        ResText, ResType, EvalFlags);
      if EvalFlags * [defNoTypeInfo, defSimpleTypeInfo, defFullTypeInfo] = [defNoTypeInfo]
      then FreeAndNil(ResType);
      TDBGEvaluateResultCallback(ACallback)(Self, Result, ResText, ResType);
      Result := True;
    end;
    if not Result then begin
      Result := inherited RequestCommand(ACommand, AParams, ACallback);
      String(AParams[1].VPointer^) := '{GDB:}'+String(AParams[1].VPointer^);
    end;
  end
  else
    Result := inherited RequestCommand(ACommand, AParams, ACallback);
end;

procedure TFpGDBMIDebugger.QueueCommand(const ACommand: TGDBMIDebuggerCommand;
  ForceQueue: Boolean);
begin
  inherited QueueCommand(ACommand, ForceQueue);
end;

procedure TFpGDBMIDebugger.GetCurrentContext(out AThreadId, AStackFrame: Integer);
begin
  if CurrentThreadIdValid then begin
    AThreadId := CurrentThreadId;

    if CurrentStackFrameValid then
      AStackFrame := CurrentStackFrame
    else
      AStackFrame := 0;
  end
  else begin
    AThreadId := 1;
    AStackFrame := 0;
  end;
end;

function TFpGDBMIDebugger.GetLocationForContext(AThreadId, AStackFrame: Integer): TDBGPtr;
var
  t: TThreadEntry;
  s: TCallStackBase;
  f: TCallStackEntry;
  //Instr: TGDBMIDebuggerInstruction;
begin
(*
  Instr := TGDBMIDebuggerInstruction.Create(Format('-stack-list-frames %d %d', [AStackFrame, AStackFrame]), AThreadId, [], 0);
  Instr.AddReference;
  Instr.Cmd := TGDBMIDebuggerCommand.Create(Self);
  FTheDebugger.FInstructionQueue.RunInstruction(Instr);
  ok := Instr.IsSuccess and Instr.FHasResult;
  AResult := Instr.ResultData;
  Instr.Cmd.ReleaseReference;
  Instr.Cmd := nil;
  Instr.ReleaseReference;

  if ok then begin
    List := TGDBMINameValueList.Create(R, ['stack']);
    Result := List.Values['frame'];
    List.Free;
  end;
*)


  Result := 0;
  if (AThreadId <= 0) then begin
    GetCurrentContext(AThreadId, AStackFrame);
  end
  else
  if (AStackFrame < 0) then begin
    AStackFrame := 0;
  end;

  t := Threads.CurrentThreads.EntryById[AThreadId];
  if t = nil then begin
    DebugLn(DBG_ERRORS, ['NO Threads']);
    exit;
  end;
  if AStackFrame = 0 then begin
    Result := t.TopFrame.Address;
    //DebugLn(['Returning addr from Threads', dbgs(Result)]);
    exit;
  end;

  s := CallStack.CurrentCallStackList.EntriesForThreads[AThreadId];
  if (s = nil) or (AStackFrame >= s.Count) then begin
    DebugLn(DBG_ERRORS, ['NO Stackframe list for thread']);
    exit;
  end;
  f := s.Entries[AStackFrame];
  if f = nil then begin
    DebugLn(DBG_ERRORS, ['NO Stackframe']);
    exit;
  end;

  Result := f.Address;
  //DebugLn(['Returning addr from frame', dbgs(Result)]);

end;

function TFpGDBMIDebugger.GetInfoContextForContext(AThreadId,
  AStackFrame: Integer): TFpDbgSymbolScope;
var
  Addr: TDBGPtr;
  i, sa: Integer;
begin
  Result := nil;
  if FDwarfInfo = nil then
    exit;

  if (AThreadId <= 0) then begin
    GetCurrentContext(AThreadId, AStackFrame);
  end;

  Addr := GetLocationForContext(AThreadId, AStackFrame);

  if Addr = 0 then begin
    debugln(DBG_VERBOSE, ['GetInfoContextForContext ADDR NOT FOUND for ', AThreadId, ', ', AStackFrame]);
    Result := nil;
    exit;
  end;

  i := MAX_CTX_CACHE - 1;
  while (i >= 0) and
    ( (FLastContext[i] = nil) or
      (FLastContext[i].LocationContext.ThreadId <> AThreadId) or (FLastContext[i].LocationContext.StackFrame <> AStackFrame)
    )
  do
    dec(i);

  if i >= 0 then begin
    Result := FLastContext[i];
    // TODO Result.AddReference;
    exit;
  end;

  DebugLn(DBG_VERBOSE, ['* FDwarfInfo.FindSymbolScope ', dbgs(Addr)]);
  if FDwarfInfo.TargetInfo.bitness = b32 then
    sa := 4
  else
    sa := 8;
  Result := FDwarfInfo.FindSymbolScope(
    TFpDbgSimpleLocationContext.Create(FMemManager, Addr, sa, AThreadId, AStackFrame),
    Addr
  );

  if Result = nil then begin
    debugln(DBG_VERBOSE, ['GetInfoContextForContext CTX NOT FOUND for ', AThreadId, ', ', AStackFrame]);
    exit;
  end;

  ReleaseRefAndNil(FLastContext[MAX_CTX_CACHE-1]);
  move(FLastContext[0], FLastContext[1], (MAX_CTX_CACHE-1) + SizeOf(FLastContext[0]));
  FLastContext[0] := Result;
  // TODO Result.AddReference;
end;

procedure TFpGDBMIDebugger.ClearWatchEvalList;
var
  i: Integer;
begin
  for i := 0 to FWatchEvalList.Count - 1 do begin
    TWatchValue(FWatchEvalList[i]).RemoveFreeNotification(@DoWatchFreed);
    //TWatchValueBase(FWatchEvalList[i]).Validity := ddsInvalid;
  end;
  FWatchEvalList.Clear;
end;

type
  TGDBMIDwarfTypeIdentifier = class(TFpSymbolDwarfType)
  public
    property InformationEntry;
  end;

procedure TFpGDBMIDebugger.DoWatchFreed(Sender: TObject);
begin
  FWatchEvalList.Remove(pointer(Sender));
end;

function TFpGDBMIDebugger.EvaluateExpression(AWatchValue: TWatchValue; AExpression: String;
  out AResText: String; out ATypeInfo: TDBGType; EvalFlags: TDBGEvaluateFlags): Boolean;
var
  Ctx: TFpDbgSymbolScope;
  PasExpr, PasExpr2: TFpPascalExpression;
  ResValue: TFpValue;
  s: String;
  DispFormat: TWatchDisplayFormat;
  RepeatCnt: Integer;
  TiSym: TFpSymbol;

  function IsWatchValueAlive: Boolean;
  begin
    Result := (State in [dsPause, dsInternalPause]) and
              (  (AWatchValue = nil) or
                 ( (FWatchEvalList.Count > 0) and (FWatchEvalList[0] = Pointer(AWatchValue)) )
              );
  end;

var
  CastName: String;
begin
  Result := False;
  ATypeInfo := nil;
  AResText := '';
  if AWatchValue <> nil then begin
    EvalFlags := AWatchValue.EvaluateFlags;
    AExpression := AWatchValue.Expression;
    //FMemReader.FThreadId := AWatchValue.ThreadId;
    //FMemReader.FStackFrame := AWatchValue.StackFrame;
  //end
  //else begin
  //  FMemReader.FThreadId := CurrentThreadId;
  //  FMemReader.FStackFrame := CurrentStackFrame;
  end;

  if AWatchValue <> nil then begin
    Ctx := GetInfoContextForContext(AWatchValue.ThreadId, AWatchValue.StackFrame);
    DispFormat := AWatchValue.DisplayFormat;
    RepeatCnt := AWatchValue.RepeatCount;
  end
  else begin
    Ctx := GetInfoContextForContext(CurrentThreadId, CurrentStackFrame);
    DispFormat := wdfDefault;
    RepeatCnt := -1;
  end;
  if Ctx = nil then exit;

  FPrettyPrinter.AddressSize := ctx.SizeOfAddress;
  FPrettyPrinter.Context := ctx.LocationContext;

  LockUnLoadDwarf;
  PasExpr := TFpPascalExpression.Create(AExpression, Ctx);
  try
    if not IsWatchValueAlive then exit;
    PasExpr.ResultValue; // trigger evaluate // and check errors
    if not IsWatchValueAlive then exit;

    if not PasExpr.Valid then begin
DebugLn(DBG_VERBOSE, [ErrorHandler.ErrorAsString(PasExpr.Error)]);
      if ErrorCode(PasExpr.Error) <> fpErrAnyError then begin
        Result := True;
        AResText := ErrorHandler.ErrorAsString(PasExpr.Error);;
        if AWatchValue <> nil then begin;
          AWatchValue.Value    := AResText;
          AWatchValue.Validity := ddsError;
        end;
        exit;
      end;
    end;

    if not (PasExpr.Valid and (PasExpr.ResultValue <> nil)) then
      exit; // TODO handle error
    if not IsWatchValueAlive then exit;

    ResValue := PasExpr.ResultValue;
    if ResValue = nil then begin
      AResText := 'Error';
      if AWatchValue <> nil then
        AWatchValue.Validity := ddsInvalid;
      exit;
    end;

    if (ResValue.Kind = skClass) and (ResValue.AsCardinal <> 0) and (defClassAutoCast in EvalFlags)
    then begin
      if ResValue.GetInstanceClassName(CastName) then begin
        PasExpr2 := TFpPascalExpression.Create(CastName+'('+AExpression+')', Ctx);
        PasExpr2.ResultValue;
        if PasExpr2.Valid then begin
          PasExpr.Free;
          PasExpr := PasExpr2;
          ResValue := PasExpr.ResultValue;
        end
        else
          PasExpr2.Free;
      end;
    end;

    TiSym := ResValue.DbgSymbol;
    if (ResValue.Kind = skNone) and (TiSym <> nil) and (TiSym.SymbolType = stType) then begin
      if GetTypeAsDeclaration(AResText, TiSym) then
        AResText := Format('{Type=} %1s', [AResText])
      else
      if GetTypeName(AResText, TiSym) then
        AResText := Format('{Type=} %1s', [AResText])
      else
        AResText := '{Type=} unknown';
      Result := True;
      if AWatchValue <> nil then begin
        if not IsWatchValueAlive then exit;
        AWatchValue.Value    := AResText;
        AWatchValue.Validity := ddsValid; // TODO ddsError ?
      end;
      exit;
    end
    else begin
      if defNoTypeInfo in EvalFlags then
        FPrettyPrinter.PrintValue(AResText, ResValue, DispFormat, RepeatCnt)
      else
        FPrettyPrinter.PrintValue(AResText, ATypeInfo, ResValue, DispFormat, RepeatCnt);
    end;
    if not IsWatchValueAlive then exit;

    if PasExpr.HasPCharIndexAccess and not IsError(ResValue.LastError) then begin
      // TODO: Only dwarf 2
      PasExpr.FixPCharIndexAccess := True;
      PasExpr.ResetEvaluation;
      ResValue := PasExpr.ResultValue;
      if (ResValue=nil) or (not FPrettyPrinter.PrintValue(s, ResValue, DispFormat, RepeatCnt)) then
        s := 'Failed';
      AResText := 'PChar: '+AResText+ LineEnding + 'String: '+s;
    end
    else
    if CastName <> '' then
      AResText := CastName + AResText;

    if (ATypeInfo <> nil) or (AResText <> '') then begin
      Result := True;
      debugln(DBG_VERBOSE, ['TFPGDBMIWatches.InternalRequestData   GOOOOOOD ', AExpression]);
      if AWatchValue <> nil then begin
        AWatchValue.Value    := AResText;
        AWatchValue.TypeInfo := ATypeInfo;
        if IsError(ResValue.LastError) then
          AWatchValue.Validity := ddsError
        else
          AWatchValue.Validity := ddsValid;
      end;
    end;

  finally
    PasExpr.Free;
    UnLockUnLoadDwarf;
  end;
end;

function TFpGDBMIDebugger.CreateCommandStartDebugging(AContinueCommand: TGDBMIDebuggerCommand): TGDBMIDebuggerCommandStartDebugging;
begin
  Result := TFpGDBMIDebuggerCommandStartDebugging.Create(Self, AContinueCommand);
end;

function TFpGDBMIDebugger.CreateLineInfo: TDBGLineInfo;
begin
  Result := TFpGDBMILineInfo.Create(Self);
end;

function TFpGDBMIDebugger.CreateWatches: TWatchesSupplier;
begin
  Result := TFPGDBMIWatches.Create(Self);
end;

function TFpGDBMIDebugger.CreateLocals: TLocalsSupplier;
begin
  Result := TFPGDBMILocals.Create(Self);
end;

class function TFpGDBMIDebugger.Caption: String;
begin
  Result := 'GNU debugger (with fpdebug)';
end;

constructor TFpGDBMIDebugger.Create(const AExternalDebugger: String);
begin
  FWatchEvalList := TList.Create;
  inherited Create(AExternalDebugger);
  CurrentDebugger := self;
end;

destructor TFpGDBMIDebugger.Destroy;
begin
  CurrentDebugger := nil;
  UnLoadDwarf;
  ClearWatchEvalList;
  FWatchEvalList.Free;
  inherited Destroy;
end;

procedure Register;
begin
  RegisterDebugger(TFpGDBMIDebugger);

  MenuCmd := RegisterIDEMenuCommand(itmRunDebugging, 'fpGdbmiToggleGDB',
    fpgdbmiDisplayGDBInsteadOfFpDebugWatches, nil,
    @IDEMenuClicked);
  MenuCmd.AutoCheck := True;
  MenuCmd.Checked := False;

end;

initialization
  DBG_VERBOSE       := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_ERRORS         := DebugLogger.FindOrRegisterLogGroup('DBG_ERRORS' {$IFDEF DBG_ERRORS} , True {$ENDIF} );
end.


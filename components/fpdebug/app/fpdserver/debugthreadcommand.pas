unit DebugThreadCommand;

{$mode objfpc}{$H+}

{$ifndef VER2}
  {$define disassemblernestedproc}
{$endif VER2}

{$ifdef disassemblernestedproc}
  {$modeswitch nestedprocvars}
{$endif disassemblernestedproc}

interface

uses
  Classes,
  FPDbgController,
  FpDbgClasses,
  FpDbgUtil,
  FpDbgInfo,
  FpPascalParser,
  FpPascalBuilder,
  FpErrorMessages,
  DbgIntfDebuggerBase,
  DbgIntfBaseTypes,
  strutils,
  debugthread,
  CustApp,
  Maps, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif},
  SysUtils;

type

  { TFpDebugThreadCommandList }

  TFpDebugThreadCommandList = class(TFPList)
  public
    class function instance: TFpDebugThreadCommandList;
    function GetCommandByName(ATextName: string): TFpDebugThreadCommandClass;
  end;

  { TFpDebugThreadQuitDebugServerCommand }

  TFpDebugThreadQuitDebugServerCommand = class(TFpDebugThreadCommand)
  public
    function PreExecute(AController: TFpServerDbgController; out DoQueueCommand: boolean): boolean; override;
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadSetFilenameCommand }

  TFpDebugThreadSetFilenameCommand = class(TFpDebugThreadCommand)
  private
    FFileName: string;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  published
    property Filename: string read FFileName write FFileName;
  end;

   { TFpDebugThreadSetRedirectConsoleOutputCommand }

   TFpDebugThreadSetConsoleTtyCommand = class(TFpDebugThreadCommand)
  private
    FConsoleTty: String;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  published
    property ConsoleTty: String read FConsoleTty write FConsoleTty;
  end;

  { TFpDebugThreadRunCommand }

  TFpDebugThreadRunCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadContinueCommand }

  TFpDebugThreadContinueCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadNextCommand }

  TFpDebugThreadNextCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadStepCommand }

  TFpDebugThreadStepCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadStepOutCommand }

  TFpDebugThreadStepOutCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadStepIntoInstrCommand }

  TFpDebugThreadStepIntoInstrCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadStepOverInstrCommand }

  TFpDebugThreadStepOverInstrCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadStopCommand }

  TFpDebugThreadStopCommand = class(TFpDebugThreadCommand)
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  end;

  { TFpDebugThreadAddBreakpointCommand }

  TFpDebugThreadAddBreakpointCommand = class(TFpDebugThreadCommand)
  private
    FFileName: string;
    FLine: integer;
    FBreakPoint: TFpInternalBreakpoint;
    FBreakServerId: Integer;
  public
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  published
    property Filename: string read FFileName write FFileName;
    property Line: integer read FLine write FLine;
  end;

  { TFpDebugThreadRemoveBreakpointCommand }

  TFpDebugThreadRemoveBreakpointCommand = class(TFpDebugThreadCommand)
  private
    FBreakpointServerIdr: Integer;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  published
    property BreakpointServerIdr: Integer read FBreakpointServerIdr write FBreakpointServerIdr;
  end;

  { TFpDebugThreadGetLocationInfoCommand }

  TFpDebugThreadGetLocationInfoCommand = class(TFpDebugThreadCommand)
  private
    FLocationRec: TDBGLocationRec;
    FAddressValue: TDBGPtr;
    function GetAddress: string;
    procedure SetAddress(AValue: string);
  protected
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
  published
    property Address: string read GetAddress write SetAddress;
  end;

  { TFpDebugThreadEvaluateCommand }

  TFpDebugThreadEvaluateCommand = class(TFpDebugThreadCommand)
  private
    FExpression: string;
    FResText: string;
    FValidity: TDebuggerDataState;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  published
    property Expression: string read FExpression write FExpression;
  end;

  { TFpDebugThreadStackTraceCommand }

  TFpDebugThreadStackTraceCommand = class(TFpDebugThreadCommand)
  private
    FStackEntryArray: TFpDebugEventCallStackEntryArray;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  end;

  { TFpDebugThreadDisassembleCommand }

  TFpDebugThreadDisassembleCommand = class(TFpDebugThreadCommand)
  private
    FAddressValue: TDBGPtr;
    FLinesAfter: integer;
    FLinesBefore: integer;
    FDisassemblerEntryArray: TFpDebugEventDisassemblerEntryArray;
    FStartAddr: TDBGPtr;
    FEndAddr: TDBGPtr;
    FLastEntryEndAddr: TDBGPtr;
    function GetAddress: string;
    procedure SetAddress(AValue: string);
    {$ifndef disassemblernestedproc}
  private
    FController: TFpServerDbgController;
    function OnAdjustToKnowFunctionStart(var AStartAddr: TDisassemblerAddress): Boolean;
    function OnDoDisassembleRange(AnEntryRanges: TDBGDisassemblerEntryMap; AFirstAddr, ALastAddr: TDisassemblerAddress; AStopAfterAddress: TDBGPtr; AStopAfterNumLines: Integer): Boolean;
    {$endif}
  public
    constructor Create(AListenerIdentifier: integer; AnUID: variant; AOnLog: TOnLog); override;
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  published
    property Address: string read GetAddress write SetAddress;
    property LinesAfter: integer read FLinesAfter write FLinesAfter;
    property LinesBefore: integer read FLinesBefore write FLinesBefore;
  end;

  { TFpDebugLocalsCommand }

  TFpDebugLocalsCommand = class(TFpDebugThreadCommand)
  private
    FWatchEntryArray: TFpDebugEventWatchEntryArray;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  end;

  { TFpDebugRegistersCommand }

  TFpDebugRegistersCommand = class(TFpDebugThreadCommand)
  private
    FWatchEntryArray: TFpDebugEventWatchEntryArray;
  public
    function Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean; override;
    class function TextName: string; override;
    procedure ComposeSuccessEvent(var AnEvent: TFpDebugEvent); override;
  end;

implementation

uses
  FpDbgDisasX86;

{ TFpDebugRegistersCommand }

function TFpDebugRegistersCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  ARegisterList: TDbgRegisterValueList;
  i: Integer;
begin
  result := false;
  if (AController = nil) or (AController.CurrentProcess = nil) or
     (AController.CurrentProcess.DbgInfo = nil) then
    exit;

  ARegisterList := AController.CurrentProcess.MainThread.RegisterValueList;
  SetLength(FWatchEntryArray, ARegisterList.Count);
  for i := 0 to ARegisterList.Count-1 do
    begin
    FWatchEntryArray[i].Expression := ARegisterList[i].Name;
    FWatchEntryArray[i].TextValue := ARegisterList[i].StrValue;
    FWatchEntryArray[i].NumValue := ARegisterList[i].NumValue;
    FWatchEntryArray[i].Size := ARegisterList[i].Size;
    end;
  result := true;
  DoProcessLoop := false;
end;

class function TFpDebugRegistersCommand.TextName: string;
begin
  result := 'registers';
end;

procedure TFpDebugRegistersCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.WatchEntryArray := FWatchEntryArray;
end;

{ TFpDebugLocalsCommand }

function TFpDebugLocalsCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  AContext: TFpDbgSymbolScope;
  ProcVal: TFpValue;
  i: Integer;
  m: TFpValue;
  n, v: String;
  PrettyPrinter: TFpPascalPrettyPrinter;
begin
  result := false;
  if (AController = nil) or (AController.CurrentProcess = nil) or
     (AController.CurrentProcess.DbgInfo = nil) then
    exit;

  AContext := AController.CurrentProcess.FindSymbolScope(AController.CurrentThread.ID, 0);

  if (AContext = nil) or (AContext.SymbolAtAddress = nil) then
    exit;

  ProcVal := AContext.ProcedureAtAddress;

  if (ProcVal = nil) then
    exit;

  PrettyPrinter := TFpPascalPrettyPrinter.Create(sizeof(pointer));
  try
    PrettyPrinter.AddressSize := AContext.SizeOfAddress;

    SetLength(FWatchEntryArray, ProcVal.MemberCount);
    for i := 0 to ProcVal.MemberCount - 1 do
      begin
      m := ProcVal.Member[i];
      if m <> nil then
        begin
        if m.DbgSymbol <> nil then
          n := m.DbgSymbol.Name
        else
          n := '';
        PrettyPrinter.PrintValue(v, m);
        FWatchEntryArray[i].TextValue := v;
        FWatchEntryArray[i].Expression := n;
        m.ReleaseReference;
        end;
      end;
  finally
    PrettyPrinter.Free;
  end;

  AContext.ReleaseReference;
  ProcVal.ReleaseReference;
  DoProcessLoop:=false;
  result := true;
end;

class function TFpDebugLocalsCommand.TextName: string;
begin
  result := 'locals';
end;

procedure TFpDebugLocalsCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.WatchEntryArray := FWatchEntryArray;
end;

{ TFpDebugThreadDisassembleCommand }

function TFpDebugThreadDisassembleCommand.GetAddress: string;
begin
  result := FormatAddress(FAddressValue);
end;

procedure TFpDebugThreadDisassembleCommand.SetAddress(AValue: string);
begin
  FAddressValue := Hex2Dec(AValue);
end;

constructor TFpDebugThreadDisassembleCommand.Create(AListenerIdentifier: integer; AnUID: variant; AOnLog: TOnLog);
begin
  inherited Create(AListenerIdentifier, AnUID, AOnLog);
  FLinesAfter:=10;
  FLinesBefore:=5;
end;

{$ifdef disassemblernestedproc}
function TFpDebugThreadDisassembleCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
{$endif}

  function {$ifndef disassemblernestedproc}TFpDebugThreadDisassembleCommand.{$endif}OnAdjustToKnowFunctionStart(var AStartAddr: TDisassemblerAddress): Boolean;
  var
    Sym: TFpSymbol;
  begin
    Sym := {$ifndef disassemblernestedproc}FController{$else}AController{$endif}.CurrentProcess.FindProcSymbol(AStartAddr.GuessedValue);
    if assigned(Sym) and (Sym.Kind in [skProcedure, skFunction]) then
      begin
      AStartAddr.Value:=Sym.Address.Address;
      AStartAddr.Offset:=0;
      AStartAddr.Validity:=avFoundFunction;
      result := true;
      end
    else
      result := false;
  end;

  function {$ifndef disassemblernestedproc}TFpDebugThreadDisassembleCommand.{$endif}OnDoDisassembleRange(AnEntryRanges: TDBGDisassemblerEntryMap; AFirstAddr, ALastAddr: TDisassemblerAddress; AStopAfterAddress: TDBGPtr; AStopAfterNumLines: Integer): Boolean;

  var
    AnAddr: TDBGPtr;
    CodeBin: array[0..20] of byte;
    AnEntry: TDisassemblerEntry;
    p: pointer;
    ADump,
    AStatement,
    ASrcFileName: string;
    ASrcFileLine: cardinal;
    i,j: Integer;
    Sym: TFpSymbol;
    StatIndex: integer;
    FirstIndex: integer;
    AResultList: TDBGDisassemblerEntryRange;

  begin
    result := false;
    AResultList := TDBGDisassemblerEntryRange.Create;
    AResultList.RangeStartAddr := AFirstAddr.Value;

    Sym:=nil;
    ASrcFileLine:=0;
    ASrcFileName:='';
    StatIndex:=0;
    FirstIndex:=0;
    AnEntry.Offset:=-1;
    AnAddr:=AFirstAddr.Value;

    i := 0;
    while ((AStopAfterAddress=0) or (AStopAfterNumLines > -1)) and (AnAddr <= ALastAddr.Value) do
      begin
      AnEntry.Addr:=AnAddr;
      if not {$ifndef disassemblernestedproc}FController{$else}AController{$endif}.CurrentProcess.ReadData(AnAddr, sizeof(CodeBin),CodeBin) then
        begin
        DebugLn(Format('Disassemble: Failed to read memory at %s.', [FormatAddress(AnAddr)]));
        AnEntry.Statement := 'Failed to read memory';
        inc(AnAddr);
        end
      else
        begin
        p := @CodeBin;
        AController.CurrentProcess.Disassembler
          .Disassemble(p, ADump, AStatement);

        Sym := {$ifndef disassemblernestedproc}FController{$else}AController{$endif}.CurrentProcess.FindProcSymbol(AnAddr);

        // If this is the last statement for this source-code-line, fill the
        // SrcStatementCount from the prior statements.
        if (assigned(sym) and ((ASrcFileName<>sym.FileName) or (ASrcFileLine<>sym.Line))) or
          (not assigned(sym) and ((ASrcFileLine<>0) or (ASrcFileName<>''))) then
          begin
          for j := 0 to StatIndex-1 do
            AResultList.EntriesPtr[FirstIndex+j]^.SrcStatementCount:=StatIndex;
          StatIndex:=0;
          FirstIndex:=i;
          end;

        if assigned(sym) then
          begin
          ASrcFileName:=sym.FileName;
          ASrcFileLine:=sym.Line;
          end
        else
          begin
          ASrcFileName:='';
          ASrcFileLine:=0;
          end;
        AnEntry.Dump := ADump;
        AnEntry.Statement := AStatement;
        AnEntry.SrcFileLine:=ASrcFileLine;
        AnEntry.SrcFileName:=ASrcFileName;
        AnEntry.SrcStatementIndex:=StatIndex;
        inc(StatIndex);
        AResultList.RangeEndAddr:=AnAddr;
        Inc(AnAddr, {%H-}PtrUInt(p) - {%H-}PtrUInt(@CodeBin));
        end;
      AResultList.Append(@AnEntry);
      if (AnAddr>AStopAfterAddress) then
        dec(AStopAfterNumLines);
      inc(i);
      end;
    AResultList.LastEntryEndAddr:=AnAddr;

    if AResultList.Count>0 then
      AnEntryRanges.AddRange(AResultList)
    else
      AResultList.Free;

    result := true;
  end;

{$ifndef disassemblernestedproc}
function TFpDebugThreadDisassembleCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
{$endif disassemblernestedproc}

var
  i: Integer;
  DisassembleRangeExtender: TDBGDisassemblerRangeExtender;
  DisassemblerEntryRange: TDBGDisassemblerEntryRange;
  DisassemblerEntryRangeMap: TDBGDisassemblerEntryMap;
  RangeIterator: TDBGDisassemblerEntryMapIterator;
  ARange: TDBGDisassemblerEntryRange;

begin
  {$ifndef disassemblernestedproc}
  FController := AController;
  {$endif}

  result := false;
  DoProcessLoop:=false;
  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to dissasemble: No process');
    exit;
    end;

  if FAddressValue=0 then
    FStartAddr:=AController.CurrentThread.GetInstructionPointerRegisterValue
  else
    FStartAddr:=FAddressValue;

  DisassemblerEntryRangeMap := TDBGDisassemblerEntryMap.Create(itu8, SizeOf(TDBGDisassemblerEntryRange));
  try
    DisassembleRangeExtender := TDBGDisassemblerRangeExtender.Create(DisassemblerEntryRangeMap);
    try
      DisassembleRangeExtender.OnDoDisassembleRange:=@OnDoDisassembleRange;
      DisassembleRangeExtender.OnAdjustToKnowFunctionStart:=@OnAdjustToKnowFunctionStart;
      DisassembleRangeExtender.DisassembleRange(FLinesBefore, FLinesAfter, FStartAddr, FStartAddr);
    finally
      DisassembleRangeExtender.Free;
    end;

    // Convert the DisassemblerEntryRangeMap to the FDisassemblerEntryArray
    DisassemblerEntryRange := TDBGDisassemblerEntryRange.Create;
    try
      RangeIterator := TDBGDisassemblerEntryMapIterator.Create(DisassemblerEntryRangeMap);
      try
        RangeIterator.First;
        RangeIterator.GetData(ARange);
        repeat
          DisassemblerEntryRange.Merge(ARange);

          ARange := RangeIterator.NextRange;
        until RangeIterator.EOM;

        setlength(FDisassemblerEntryArray, DisassemblerEntryRange.Count);
        for i := 0 to DisassemblerEntryRange.Count-1 do
          begin
          FDisassemblerEntryArray[i] := DisassemblerEntryRange.Entries[i];
          end;
        FStartAddr:=DisassemblerEntryRange.RangeStartAddr;
        FEndAddr:=DisassemblerEntryRange.RangeEndAddr;
        FLastEntryEndAddr:=DisassemblerEntryRange.LastEntryEndAddr;
      finally
        RangeIterator.Free;
      end;
    finally
      DisassemblerEntryRange.Free;;
    end;
  finally
    DisassemblerEntryRangeMap.Free;
  end;

  result := true;
end;

class function TFpDebugThreadDisassembleCommand.TextName: string;
begin
  result := 'disassemble';
end;

procedure TFpDebugThreadDisassembleCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.DisassemblerEntryArray := FDisassemblerEntryArray;
  AnEvent.Addr1:=FStartAddr;
  AnEvent.Addr2:=FEndAddr;
  AnEvent.Addr3:=FLastEntryEndAddr;
end;

{ TFpDebugThreadSetConsoleTtyCommand }

function TFpDebugThreadSetConsoleTtyCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
begin
  AController.ConsoleTty:=FConsoleTty;
  AController.RedirectConsoleOutput:=(AController.ConsoleTty='');
  DoProcessLoop:=false;
  result:=true;
end;

class function TFpDebugThreadSetConsoleTtyCommand.TextName: string;
begin
  result := 'setconsoletty';
end;

{ TFpDebugThreadStackTraceCommand }

function TFpDebugThreadStackTraceCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  ThreadCallStack: TDbgCallstackEntryList;
  i: integer;
  PrettyPrinter: TFpPascalPrettyPrinter;
begin
  result := false;
  DoProcessLoop:=false;
  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to get call stack: No process');
    exit;
    end;

  AController.CurrentProcess.MainThread.PrepareCallStackEntryList;
  ThreadCallStack := AController.CurrentProcess.MainThread.CallStackEntryList;
  SetLength(FStackEntryArray, ThreadCallStack.Count);
  PrettyPrinter := TFpPascalPrettyPrinter.Create(sizeof(pointer));
  for i := 0 to ThreadCallStack.Count-1 do
    begin
    FStackEntryArray[i].AnAddress:=ThreadCallStack[i].AnAddress;
    FStackEntryArray[i].FrameAdress:=ThreadCallStack[i].FrameAdress;
    FStackEntryArray[i].FunctionName:=ThreadCallStack[i].FunctionName+ThreadCallStack[i].GetParamsAsString(PrettyPrinter);
    FStackEntryArray[i].Line:=ThreadCallStack[i].Line;
    FStackEntryArray[i].SourceFile:=ThreadCallStack[i].SourceFile;
    end;
  // Clear the callstack immediately. Doing this each time the process continous is
  // cumbersome. And the chances that this command is called twice, so that
  // caching the result is usefull, are slim.
  AController.CurrentProcess.MainThread.ClearCallStack;
  PrettyPrinter.Free;
  result := true;
end;


class function TFpDebugThreadStackTraceCommand.TextName: string;
begin
  result := 'stacktrace';
end;

procedure TFpDebugThreadStackTraceCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.StackEntryArray:=FStackEntryArray;
end;

{ TFpDebugThreadEvaluateCommand }

procedure TFpDebugThreadEvaluateCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.Message:=FResText;
  AnEvent.Validity:=FValidity;
end;

function TFpDebugThreadEvaluateCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  AContext: TFpDbgSymbolScope;
  APasExpr: TFpPascalExpression;
  Res: Boolean;
  APrettyPrinter: TFpPascalPrettyPrinter;
  ATypeInfo: TDBGType;

begin
  Result := False;
  DoProcessLoop:=false;
  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to evaluate expression: No process');
    exit;
    end;

  AContext := AController.CurrentProcess.FindSymbolScope(AController.CurrentThread.ID, 0);
  if AContext = nil then
    begin
    FValidity:=ddsInvalid;
    exit;
    end;

  Result := True;
  APasExpr := TFpPascalExpression.Create(FExpression, AContext);
  try
    APasExpr.ResultValue; // trigger full validation
    if not APasExpr.Valid then
      begin
      FResText := ErrorHandler.ErrorAsString(APasExpr.Error);
      FValidity := ddsError;
      end
    else
      begin
      APrettyPrinter := TFpPascalPrettyPrinter.Create(sizeof(pointer));
      try
        APrettyPrinter.AddressSize:=AContext.SizeOfAddress;
        APrettyPrinter.Context := AContext.LocationContext;
        Res := APrettyPrinter.PrintValue(FResText, ATypeInfo, APasExpr.ResultValue);
        if Res then
          begin
          FValidity:=ddsValid;
          end
        else
          begin
          FResText := 'Error';
          FValidity:=ddsValid;
          end;
      finally
        APrettyPrinter.Free;
      end;
      end;
  finally
    APasExpr.Free;
    AContext.ReleaseReference;
  end;
end;

class function TFpDebugThreadEvaluateCommand.TextName: string;
begin
  result := 'evaluate';
end;

{ TFpDebugThreadQuitDebugServerCommand }

function TFpDebugThreadQuitDebugServerCommand.PreExecute(AController: TFpServerDbgController; out DoQueueCommand: boolean): boolean;
begin
  DoQueueCommand:=false;
  CustomApplication.Terminate;
  result := true;
end;

function TFpDebugThreadQuitDebugServerCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
begin
  result := true;
  DoProcessLoop := false;
end;

class function TFpDebugThreadQuitDebugServerCommand.TextName: string;
begin
  result := 'quitdebugserver';
end;

{ TFpDebugThreadRemoveBreakpointCommand }

function TFpDebugThreadRemoveBreakpointCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  Brk: TFpDbgBreakpoint;
begin
  result := false;
  DoProcessLoop:=false;
  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to remove breakpoint: No process');
    exit;
    end;
  if (FBreakpointServerIdr<>0) then begin
    Brk := AController.GetInternalBreakPointFromId(FBreakpointServerIdr);
    result := true;
    AController.CurrentProcess.RemoveBreak(Brk);
    Brk.Free; // actually removes it from target process
    AController.RemoveInternalBreakPoint(FBreakpointServerIdr);
  end
  else
    debugln('Failed to remove breakpoint: No location given');
end;

class function TFpDebugThreadRemoveBreakpointCommand.TextName: string;
begin
  result := 'removebreakpoint';
end;

{ TFpDebugThreadStopCommand }

function TFpDebugThreadStopCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  AController.Stop;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadStopCommand.TextName: string;
begin
  result := 'stop';
end;

{ TFpDebugThreadStepOutCommand }

function TFpDebugThreadStepOutCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  AController.StepOut;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadStepOutCommand.TextName: string;
begin
  result := 'stepout';
end;

{ TFpDebugThreadStepOverInstrCommand }

function TFpDebugThreadStepOverInstrCommand.Execute(
  AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
begin
  AController.StepOverInstr;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadStepOverInstrCommand.TextName: string;
begin
  result := 'stepoverinstr';
end;

{ TFpDebugThreadStepIntoInstrCommand }

function TFpDebugThreadStepIntoInstrCommand.Execute(
  AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
begin
  AController.StepIntoInstr;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadStepIntoInstrCommand.TextName: string;
begin
  result := 'stepintoinstr';
end;

{ TFpDebugThreadStepCommand }

function TFpDebugThreadStepCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  AController.Step;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadStepCommand.TextName: string;
begin
  result := 'step';
end;

{ TFpDebugThreadNextCommand }

function TFpDebugThreadNextCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  AController.Next;
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadNextCommand.TextName: string;
begin
  result := 'next';
end;

{ TFpDebugThreadGetLocationInfoCommand }

function TFpDebugThreadGetLocationInfoCommand.GetAddress: string;
begin
  result := FormatAddress(FAddressValue);
end;

procedure TFpDebugThreadGetLocationInfoCommand.SetAddress(AValue: string);
begin
  FAddressValue := Hex2Dec(AValue);
end;

procedure TFpDebugThreadGetLocationInfoCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.LocationRec:=FLocationRec;
end;

function TFpDebugThreadGetLocationInfoCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
var
  sym, symproc: TFpSymbol;
begin
  DoProcessLoop:=false;
  result := false;

  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to get location info: No process');
    exit;
    end
  else
    begin
    FLocationRec.FuncName:='';
    FLocationRec.SrcFile:='';
    FLocationRec.SrcFullName:='';
    FLocationRec.SrcLine:=0;

    if FAddressValue=0 then
      FLocationRec.Address := AController.CurrentThread.GetInstructionPointerRegisterValue
    else
      FLocationRec.Address := FAddressValue;

    sym := AController.CurrentProcess.FindProcSymbol(FLocationRec.Address);
    if sym = nil then
      Exit;

    FLocationRec.SrcFile := ExtractFileName(sym.FileName);
    FLocationRec.SrcLine := sym.Line;
    FLocationRec.SrcFullName := sym.FileName;

    symproc := sym;
    while not (symproc.kind in [skProcedure, skFunction]) do
      symproc := symproc.Parent;

    if assigned(symproc) then
      FLocationRec.FuncName:=symproc.Name;
    sym.free;
    result := true;
    end;
end;

class function TFpDebugThreadGetLocationInfoCommand.TextName: string;
begin
  result := 'getlocationinfo'
end;

{ TFpDebugThreadAddBreakpointCommand }

procedure TFpDebugThreadAddBreakpointCommand.ComposeSuccessEvent(var AnEvent: TFpDebugEvent);
begin
  inherited ComposeSuccessEvent(AnEvent);
  AnEvent.BreakpointServerIdr:=FBreakServerId;
end;

function TFpDebugThreadAddBreakpointCommand.Execute(AController: TFpServerDbgController; out DoProcessLoop: boolean): boolean;
begin
  result := false;
  FBreakServerId := 0;
  DoProcessLoop:=false;
  if not assigned(AController.CurrentProcess) then
    begin
    debugln('Failed to add breakpoint: No process');
    exit;
    end;
  if (Filename<>'') and (line>-1) then
    begin
    FBreakPoint := AController.CurrentProcess.AddBreak(FileName, Line);
    result := assigned(FBreakPoint);
    if Result then
      FBreakServerId := AController.AddInternalBreakPointToId(FBreakPoint);
    end
  else
    debugln('Failed to add breakpoint: No filename and line-number given');
end;

class function TFpDebugThreadAddBreakpointCommand.TextName: string;
begin
  result := 'addbreakpoint';
end;

{ TFpDebugThreadCommandList }

var
  GFpDebugThreadCommandList: TFpDebugThreadCommandList = nil;

class function TFpDebugThreadCommandList.instance: TFpDebugThreadCommandList;
begin
  if not assigned(GFpDebugThreadCommandList) then
    GFpDebugThreadCommandList := TFpDebugThreadCommandList.Create;
  result := GFpDebugThreadCommandList;
end;

function TFpDebugThreadCommandList.GetCommandByName(ATextName: string): TFpDebugThreadCommandClass;
var
  i: Integer;
begin
  result := nil;
  for i := 0 to count -1 do
    begin
    if TFpDebugThreadCommandClass(Items[i]).TextName=ATextName then
      result := TFpDebugThreadCommandClass(Items[i]);
    end;
end;

{ TFpDebugThreadContinueCommand }

function TFpDebugThreadContinueCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  DoProcessLoop:=true;
  result := true;
end;

class function TFpDebugThreadContinueCommand.TextName: string;
begin
  result := 'continue';
end;

{ TFpDebugThreadRunCommand }

function TFpDebugThreadRunCommand.Execute(AController: TFpServerDbgController; out
  DoProcessLoop: boolean): boolean;
begin
  DoProcessLoop := AController.Run;
  result := DoProcessLoop;
end;

class function TFpDebugThreadRunCommand.TextName: string;
begin
  result := 'run';
end;

{ TFpDebugThreadSetFilenameCommand }

function TFpDebugThreadSetFilenameCommand.Execute(AController: TFpServerDbgController;
  out DoProcessLoop: boolean): boolean;
begin
  AController.ExecutableFilename:=FFileName;
  DoProcessLoop:=false;
  result:=true;
end;

class function TFpDebugThreadSetFilenameCommand.TextName: string;
begin
  result := 'filename'
end;

initialization
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadQuitDebugServerCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadSetFilenameCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadSetConsoleTtyCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadRunCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadContinueCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStepOverInstrCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStepIntoInstrCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadNextCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStepCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStepOutCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStopCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadAddBreakpointCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadRemoveBreakpointCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadGetLocationInfoCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadEvaluateCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadStackTraceCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugThreadDisassembleCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugLocalsCommand);
  TFpDebugThreadCommandList.instance.Add(TFpDebugRegistersCommand);
finalization
  GFpDebugThreadCommandList.Free;
end.


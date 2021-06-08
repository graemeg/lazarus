unit TTestDbgExecuteables;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, TestDbgConfig, TestDbgCompilerProcess,
  TestOutputLogger, TTestDebuggerClasses, TestCommonSources, LazFileUtils,
  LazLoggerBase, FileUtil, LazStringUtils, DbgIntfDebuggerBase, fpcunit;

type

  TUsesDir = record
    DirName, ExeId: String; // dirname = filename
    SymbolType: TSymbolType;
    ExtraOpts, NamePostFix: string;
  end;

  { TTestDbgExternalExe }

  TTestDbgExternalExe = class
  private
    FExternalExeInfo: TExternalExeInfo;
    function GetExeName: string;
    function GetExtraOpts: string;
    function GetName: string;
    function GetVersion: Integer;
  public
    constructor Create(AnExternalExeInfo: TExternalExeInfo);
    function FullName: String;
    function HasFlag(const f: string): boolean;
    function HasFlags(const f: array of string): boolean;

    property Name: string read GetName;
    property Version: Integer read GetVersion;
    property ExeName: string read GetExeName;
    property ExtraOpts: string read GetExtraOpts;
    property FullInfo: TExternalExeInfo read FExternalExeInfo;
  end;

  { TTestDbgCompiler }

  TTestDbgCompiler = class(TTestDbgExternalExe)
  private
    FLastCompileCommandLine: String; // last commandline
    FCompileProcess: TCompilerProcess;

    FSymbolType: TSymbolType;
    FCpuBitType: TCpuBitType;
    function GetCpuBitType: TCpuBitType;
    function GetLastCompileOutput: String;
    function GetSymbolType: TSymbolType;
  public
    constructor Create(AnExternalExeInfo: TExternalExeInfo;
      ASymbolType: TSymbolType; ACpuBitType: TCpuBitType);
    function FullName: String;
    property SymbolType: TSymbolType read GetSymbolType;
    property CpuBitType: TCpuBitType read GetCpuBitType;

    // Compile
    procedure TestCompileUses(UsesDir: TUsesDir; out UsesLibDir: String; out ExeID:string);
    Procedure TestCompile(const PascalPrgFile: string;
                          out AnExeName: string;
                          NamePostFix: String=''; ExtraArgs: String=''
                         ); overload;
    Procedure TestCompile(const PascalPrgFile: string;
                          out anExeName: string;
                          UsesDirs: array of TUsesDir;
                          NamePostFix: String=''; ExtraArgs: String=''
                         ); overload;
    property LastCompileCommandLine: String read FLastCompileCommandLine;
    property LastCompileOutput: String read GetLastCompileOutput;

  end;

  TTestDbgCompilerClass = class of TTestDbgCompiler;

  { TTestDbgDebugger }

  TTestDbgDebugger = class(TTestDbgExternalExe)
  private
    FCallStack: TTestCallStackMonitor;
    FDisassembler: TBaseDisassembler;
    FExceptions: TBaseExceptions;
    //FSignals: TBaseSignals;
    //FBreakPoints: TIDEBreakPoints;
    //FBreakPointGroups: TIDEBreakPointGroups;
    FLocals: TLocalsMonitor;
    FLineInfo: TBaseLineInfo;
    FWatches: TTestWatchesMonitor;
    FThreads: TTestThreadsMonitor;
    FRegisters: TTestRegistersMonitor;
    FTestBreakPoints: TStringList;

    function GetCpuBitTypes: TCpuBitTypes;
    function GetSymbolTypes: TSymbolTypes;
  protected
    FLazDebugger: TDebuggerIntf;

    procedure DoBetweenWaitForFinish; virtual;
  public
    function MatchesCompiler(ACompiler: TTestDbgCompiler): Boolean; virtual;
    property SymbolTypes: TSymbolTypes read GetSymbolTypes;
    property CpuBitTypes: TCpuBitTypes read GetCpuBitTypes;

  public
    procedure InitDebuggerMonitors(ADebugger: TDebuggerIntf); // TODO protected
    procedure ClearDebuggerMonitors;

  public
    function StartDebugger(AppDir, TestExeName: String): boolean; virtual;
    procedure FreeDebugger;
    function RunToNextPause(ACmd: TDBGCommand; ATimeOut: Integer = 5000; AWaitForInternal: Boolean = False): Boolean;
    function WaitForFinishRun(ATimeOut: Integer = 5000; AWaitForInternal: Boolean = False): Boolean;

    function SetBreakPoint(AFileName: String; ALine: Integer): TDBGBreakPoint;
    function SetBreakPoint(ACommonSource: TCommonSource; AName: String): TDBGBreakPoint;
    function SetBreakPoint(ACommonSource: TCommonSource; ASourceName, AName: String): TDBGBreakPoint;
    function BreakPointByName(AName: String): TDBGBreakPoint;

    procedure CleanAfterTestDone; virtual;

    property LazDebugger: TDebuggerIntf read FLazDebugger write FLazDebugger;

    property CallStack: TTestCallStackMonitor read FCallStack;
    property Disassembler: TBaseDisassembler read FDisassembler;
    property Exceptions: TBaseExceptions read FExceptions;
    //property Signals: TBaseSignals read FSignals;
    //property BreakPoints: TIDEBreakPoints read FBreakPoints;
    //property BreakPointGroups: TIDEBreakPointGroups read FBreakPointGroups;
    property Locals: TLocalsMonitor read FLocals;
    property LineInfo: TBaseLineInfo read FLineInfo;
    property Watches: TTestWatchesMonitor read FWatches;
    property Threads: TTestThreadsMonitor read FThreads;
    property Registers: TTestRegistersMonitor read FRegisters;
  end;

  TTestDbgDebuggerClass = Class of TTestDbgDebugger;

  TTestDbgCompilerList = specialize TFPGObjectList<TTestDbgCompiler>;
  TTestDbgDebuggerList = specialize TFPGObjectList<TTestDbgDebugger>;

var
  TestDbgCompilerList: TTestDbgCompilerList;
  TestDbgDebuggerList: TTestDbgDebuggerList;

procedure CreateCompilerList(ACompilerConfigsList: TBaseList; ACompilerClass: TTestDbgCompilerClass);
procedure CreateDebuggerList(ADebuggerConfigsList: TBaseList; ADebuggerClass: TTestDbgDebuggerClass);

function NameToFileName(AName: String; AForCompiler: Boolean = True): String;

implementation

function NameToFileName(AName: String; AForCompiler: Boolean): String;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to length(AName) do begin
    if AName[i] in ['a'..'z', 'A'..'Z', '0'..'9', '.'] then
      Result := Result + AName[i]
    else if (not AForCompiler) and (AName[i] in ['.', '-', ',', '(', ')', '[', ']', ' ', '_']) then
      Result := Result + AName[i]
    else if AName[i] = ' ' then
      Result := Result +  '__'
    else
      Result := Result + '_' + IntToHex(ord(AName[i]), 2);
  end;
end;

{ TTestDbgExternalExe }

function TTestDbgExternalExe.GetExeName: string;
begin
  Result := FExternalExeInfo.ExeName;
end;

function TTestDbgExternalExe.GetExtraOpts: string;
begin
  Result := FExternalExeInfo.ExtraOpts;
end;

function TTestDbgExternalExe.GetName: string;
begin
  Result := FExternalExeInfo.Name;
end;

function TTestDbgExternalExe.GetVersion: Integer;
begin
  Result := FExternalExeInfo.Version;
end;

constructor TTestDbgExternalExe.Create(AnExternalExeInfo: TExternalExeInfo);
begin
  FExternalExeInfo := AnExternalExeInfo;
end;

function TTestDbgExternalExe.FullName: String;
begin
  Result := Name;
end;

function TTestDbgExternalExe.HasFlag(const f: string): boolean;
begin
  Result := HasFlags([f]);
end;

function TTestDbgExternalExe.HasFlags(const f: array of string): boolean;
var
  s: String;
begin
  Result := True;
  for s in f do
    if PosI(','+s+',', FullInfo._CustomFlags) > 0 then
      exit;

  Result := False;
end;

{ TTestDbgCompiler }

function TTestDbgCompiler.GetCpuBitType: TCpuBitType;
begin
  Result := FCpuBitType;
end;

function TTestDbgCompiler.GetLastCompileOutput: String;
begin
  Result := FCompileProcess.CompilerOutput;
end;

function TTestDbgCompiler.GetSymbolType: TSymbolType;
begin
  Result := FSymbolType;
end;

constructor TTestDbgCompiler.Create(AnExternalExeInfo: TExternalExeInfo;
  ASymbolType: TSymbolType; ACpuBitType: TCpuBitType);
begin
  inherited Create(AnExternalExeInfo);
  FSymbolType := ASymbolType;
  FCpuBitType := ACpuBitType;
end;

function TTestDbgCompiler.FullName: String;
var
  b: String;
  t: String;
begin
  WriteStr(b, FCpuBitType);
  WriteStr(t, FSymbolType);
  Result := inherited + ' (' + b + ', ' + t + ')';
end;

procedure TTestDbgCompiler.TestCompileUses(UsesDir: TUsesDir; out
  UsesLibDir: String; out ExeID: string);
var
  Opts: String;
  DirPostFix: String;
begin
  DirPostFix := SymbolTypeNames[UsesDir.SymbolType] + '_' + NameToFileName(Name);
  UsesLibDir := AppendPathDelim(ExtractFilePath(UsesDir.DirName)) + 'lib__'
    + DirPostFix;
  if UsesDir.NamePostFix <> '' then
    UsesLibDir := UsesLibDir + '__' + UsesDir.NamePostFix;

  ExeID := '_U'+UsesDir.ExeId+'_'+DirPostFix+'__';

  Opts := SymbolTypeSwitches[UsesDir.SymbolType] + ' ' + UsesDir.ExtraOpts;
  if not FCompileProcess.TestCompileUnits(Self.ExeName, Opts, UsesDir.DirName, UsesLibDir)
  then
    raise EAssertionFailedError.Create('Compilation Failed: ' + UsesDir.DirName + LineEnding + FCompileProcess.CompilerOutput);
end;

procedure TTestDbgCompiler.TestCompile(const PascalPrgFile: string; out
  AnExeName: string; NamePostFix: String; ExtraArgs: String);
begin
  TestCompile(PascalPrgFile, anExeName, [], NamePostFix, ExtraArgs);
end;

procedure TTestDbgCompiler.TestCompile(const PascalPrgFile: string; out
  anExeName: string; UsesDirs: array of TUsesDir; NamePostFix: String;
  ExtraArgs: String);
var
  ExePath, ErrMsg, ExtraFUPath: String;
  i: Integer;
  NewLibDir, NewExeID: string;
  Force: Boolean;
begin
  FLastCompileCommandLine := '';
  ExePath := ExtractFileNameWithoutExt(PascalPrgFile);
  AnExeName := ExtractFileNameOnly(ExePath);
  ExePath := AppendPathDelim(copy(ExePath, 1, length(ExePath) - length(AnExeName)));
  if DirectoryExistsUTF8(ExePath + 'lib') then
    ExePath := AppendPathDelim(ExePath + 'lib');

  ExtraFUPath := '';
  Force := False;
  for i := low(UsesDirs) to high(UsesDirs) do begin
    TestCompileUses(UsesDirs[i], NewLibDir, NewExeID);
    Force := Force or FCompileProcess.DidRunCompiler; // recompiled => force compiling final exe
    ExtraFUPath := ExtraFUPath + ' -Fu'+NewLibDir;
    NamePostFix := NamePostFix + NewExeID;
  end;

  AnExeName := ExePath + AnExeName + NamePostFix + '_'+IntToStr(GetProcessID)+'_'+ SymbolTypeNames[SymbolType] + '_' + NameToFileName(Self.Name) + GetExeExt;

  {$IFDEF windows}
  ExtraArgs := ExtraArgs + ' -WG';
  {$ENDIF}
  ErrMsg := '';
  if not FCompileProcess.TestCompile(Self.ExeName,
    SymbolTypeSwitches[SymbolType] + ' ' + ExtraFUPath + ' ' + Self.ExtraOpts + ' ' + ExtraArgs,
    PascalPrgFile, AnExeName, Force)
  then
    ErrMsg := 'Error' + LineEnding + FCompileProcess.CompilerOutput;
  FLastCompileCommandLine := FCompileProcess.CommandLine;
  if ErrMsg <> '' then begin
    TestLogger.debugln(ErrMsg);
    raise EAssertionFailedError.Create('Compilation Failed: ' + AnExeName + LineEnding + ErrMsg);
  end;
end;

{ TTestDbgDebugger }

function TTestDbgDebugger.GetCpuBitTypes: TCpuBitTypes;
begin
  Result := FExternalExeInfo.CpuBitTypes;
end;

function TTestDbgDebugger.GetSymbolTypes: TSymbolTypes;
begin
  Result := FExternalExeInfo.SymbolTypes;
end;

procedure TTestDbgDebugger.DoBetweenWaitForFinish;
begin
  sleep(3);
end;

function TTestDbgDebugger.MatchesCompiler(ACompiler: TTestDbgCompiler): Boolean;
begin
  Result := (ACompiler.SymbolType in SymbolTypes) and
            (ACompiler.CpuBitType in CpuBitTypes);
end;

procedure TTestDbgDebugger.InitDebuggerMonitors(ADebugger: TDebuggerIntf);
begin
  FTestBreakPoints := TStringList.Create;

  //FBreakPoints := TManagedBreakPoints.Create(Self);
  //FBreakPointGroups := TIDEBreakPointGroups.Create;
  FWatches := TTestWatchesMonitor.Create;
  FThreads := TTestThreadsMonitor.Create;
  FExceptions := TBaseExceptions.Create(TBaseException);
  //FSignals := TBaseSignals.Create(TBaseSignal);
  FLocals := TLocalsMonitor.Create;
  FLineInfo := TBaseLineInfo.Create;
  FCallStack := TTestCallStackMonitor.Create;
  FDisassembler := TBaseDisassembler.Create;
  FRegisters := TTestRegistersMonitor.Create;

  //TManagedBreakpoints(FBreakpoints).Master := ADebugger.BreakPoints;
  FWatches.Supplier := ADebugger.Watches;
  FThreads.Supplier := ADebugger.Threads;
  FLocals.Supplier := ADebugger.Locals;
  //FLineInfo.Master := ADebugger.LineInfo;
  FCallStack.Supplier := ADebugger.CallStack;
  //FDisassembler.Master := ADebugger.Disassembler;
  //FSignals.Master := ADebugger.Signals;
  FRegisters.Supplier := ADebugger.Registers;
  ADebugger.Exceptions := FExceptions;
end;

procedure TTestDbgDebugger.ClearDebuggerMonitors;
begin
  //if FBreakPoints <> nil then TManagedBreakpoints(FBreakpoints).Master := nil;
  if FWatches <> nil then FWatches.Supplier := nil;
  if FThreads <> nil then FThreads.Supplier := nil;
  if FLocals <> nil then FLocals.Supplier := nil;
  //if FLineInfo <> nil then FLineInfo.Master := nil;
  if FCallStack <> nil then FCallStack.Supplier := nil;
  //if FDisassembler <> nil then FDisassembler.Master := nil;
  //if FExceptions <> nil then FExceptions.Master := nil;
  //if FSignals <> nil then FSignals.Master := nil;
  //if FRegisters <> nil then FRegisters.Master := nil;

  FreeAndNil(FWatches);
  FreeAndNil(FThreads);
  //FreeAndNil(FBreakPoints);
  //FreeAndNil(FBreakPointGroups);
  FreeAndNil(FCallStack);
  FreeAndNil(FDisassembler);
  FreeAndNil(FExceptions);
  //FreeAndNil(FSignals);
  FreeAndNil(FLocals);
  FreeAndNil(FLineInfo);
  FreeAndNil(FRegisters);

  FreeAndNil(FTestBreakPoints);
end;

function TTestDbgDebugger.StartDebugger(AppDir, TestExeName: String): boolean;
begin
  FLazDebugger := nil;
  Result := False;
end;

procedure TTestDbgDebugger.FreeDebugger;
begin
  if FLazDebugger <> nil then begin
    FLazDebugger.Stop;
    WaitForFinishRun();
  end;
  ClearDebuggerMonitors;
  FreeAndNil(FLazDebugger);
end;

function TTestDbgDebugger.RunToNextPause(ACmd: TDBGCommand; ATimeOut: Integer;
  AWaitForInternal: Boolean): Boolean;
begin
  Result := False;
  with LazDebugger.GetLocation do DebugLnEnter('>>> RunToNextPause Starting at %s %d @ %x', [SrcFile, SrcLine, Address]);
  case ACmd of
    dcRun:      LazDebugger.Run;
    dcStepOver: LazDebugger.StepOver;
    dcStepInto: LazDebugger.StepInto;
    dcStepOut:  LazDebugger.StepOut;
    dcStepOverInstr: LazDebugger.StepOverInstr;
    dcStepIntoInstr: LazDebugger.StepIntoInstr;
    dcStop:     LazDebugger.Stop;
    else
      exit;
  end;
  Result := WaitForFinishRun(ATimeOut, AWaitForInternal);
  if (LazDebugger.State = dsPause) and (ACmd <> dcStop) then
    with LazDebugger.GetLocation do begin
      DebugLnExit('<<< RunToNextPause Ending at %s %d @ %x %s', [SrcFile, SrcLine, Address, dbgs(LazDebugger.State)]);
      TestLogger.DebugLn('at %s %d @ %x %s', [SrcFile, SrcLine, Address, dbgs(LazDebugger.State)]);
    end
  else
    DebugLnExit(['<<< RunToNextPause - ERROR: not paused']);
end;

function TTestDbgDebugger.WaitForFinishRun(ATimeOut: Integer;
  AWaitForInternal: Boolean): Boolean;
var
  t, d: QWord;
begin
  t := GetTickCount64;
  repeat
    DoBetweenWaitForFinish;
    Result := (FLazDebugger.State in [dsStop, dsPause, dsError, dsDestroying]) or
              (AWaitForInternal and (FLazDebugger.State = dsInternalPause));
    if Result then
      break;

    d := GetTickCount64;
    if d >= t then
      d := d - t
    else
      d := high(d) - t + d;
  until d > ATimeOut;
end;

function TTestDbgDebugger.SetBreakPoint(AFileName: String; ALine: Integer
  ): TDBGBreakPoint;
begin
  Result := LazDebugger.BreakPoints.Add(AFileName, ALine);
  with Result do begin
    InitialEnabled := True;
    Enabled := True;
  end;
  DebugLn('Inserted breakpoint %s %d  id: %d', [AFileName, ALine, Result.ID]);
end;

function TTestDbgDebugger.SetBreakPoint(ACommonSource: TCommonSource;
  AName: String): TDBGBreakPoint;
begin
  Result := SetBreakPoint(ACommonSource.FileName, ACommonSource.BreakPoints[AName]);
  FTestBreakPoints.AddObject(AName, Result);
end;

function TTestDbgDebugger.SetBreakPoint(ACommonSource: TCommonSource;
  ASourceName, AName: String): TDBGBreakPoint;
begin
  ACommonSource := ACommonSource.OtherSrc[ASourceName];
  Result := SetBreakPoint(ACommonSource.FileName, ACommonSource.BreakPoints[AName]);
  FTestBreakPoints.AddObject(AName, Result);
end;

function TTestDbgDebugger.BreakPointByName(AName: String): TDBGBreakPoint;
begin
  Result := TDBGBreakPoint(FTestBreakPoints.Objects[FTestBreakPoints.IndexOf(AName)]);
end;

procedure TTestDbgDebugger.CleanAfterTestDone;
begin
  //
end;

procedure CreateCompilerList(ACompilerConfigsList: TBaseList;
  ACompilerClass: TTestDbgCompilerClass);
var
  i: Integer;
  b: TCpuBitType;
  t: TSymbolType;
  c: TExternalExeInfo;
begin
  for b := low(TCpuBitType) to high(TCpuBitType) do
  for i := 0 to ACompilerConfigsList.Count - 1 do
  for t := low(TSymbolType) to high(TSymbolType) do
    begin
      c := ACompilerConfigsList.FullInfo[i];
      if (b in c.CpuBitTypes) and (t in c.SymbolTypes) then
        TestDbgCompilerList.Add(ACompilerClass.Create(c, t, b));
    end;
end;

procedure CreateDebuggerList(ADebuggerConfigsList: TBaseList;
  ADebuggerClass: TTestDbgDebuggerClass);
var
  i: Integer;
  c: TExternalExeInfo;
begin
  for i := 0 to ADebuggerConfigsList.Count - 1 do
    begin
      c := ADebuggerConfigsList.FullInfo[i];
      TestDbgDebuggerList.Add(ADebuggerClass.Create(c));
    end;
end;

initialization
  TestDbgCompilerList := TTestDbgCompilerList.Create;
  TestDbgCompilerList.FreeObjects := True;
  TestDbgDebuggerList := TTestDbgDebuggerList.Create;
  TestDbgDebuggerList.FreeObjects := True;

finalization
  TestDbgCompilerList.Free;
  TestDbgDebuggerList.Free;

end.


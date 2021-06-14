unit TestStepping;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math, TestDbgControl, TestDbgTestSuites,
  TTestWatchUtilities, TestCommonSources, TestDbgConfig, TestOutputLogger,
  FpDebugDebugger, FpDebugDebuggerUtils, DbgIntfDebuggerBase, DbgIntfBaseTypes,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, Forms;

type

  { TTestStepping }

  TTestStepping = class(TDBGTestCase)
  protected
    Src: TCommonSource;
    Dbg: TDebuggerIntf;

    FGotExceptCount: Integer;
    FGotExceptClass: String;
    FGotExceptMsg: String;
    FGotExceptType: TDBGExceptionType;
    FGotExceptionLocation: TDBGLocationRec;
    FContinue: Boolean;

    procedure TestLocation(ATestName, ABrkName: String; ABreakHitCount: Integer = 1; AnAcceptLinesBefore: integer = 0); // only line-number
    function IsAtLocation(ABrkName: String; ATrueOnNoLine: Boolean = False): Boolean; // only line-number
    procedure DoDebuggerException(Sender: TObject;
                                  const AExceptionType: TDBGExceptionType;
                                  const AExceptionClass: String;
                                  const AExceptionLocation: TDBGLocationRec;
                                  const AExceptionText: String;
                                  out AContinue: Boolean);
    function StepOverToLine(ATestName, ABrkName: String; AnExitIfNoLineInfo: Boolean = False): Boolean;
    function StepIfAtLine(ATestName, ABrkName: String): Boolean;
    procedure DoTestStepOver(ANextOnlyStopOnStartLine: Boolean);
    procedure DoTestStepOverInstr(ANextOnlyStopOnStartLine: Boolean);
    procedure DoTestExceptionStepOutEx(ANextOnlyStopOnStartLine: Boolean);
    procedure DoTestExceptionStepOverEx(ANextOnlyStopOnStartLine: Boolean);
  published
    (* Step over to work with various events happening during the step
       - creation/exit of threads
       - ignored breakpoints (same thread / other thread)
       - TODO: ignored exception: caught inside the step
       - TODO: ignored exception: caught caught outside the step (step to except/finally)
    *)
    procedure TestStepOver;
    procedure TestStepOverInstr;
    procedure TestExceptionStepOutEx;
    procedure TestExceptionStepOverEx;

    procedure TestStepOver_NextOnlyFalse;
    procedure TestStepOverInstr_NextOnlyFalse;
    procedure TestExceptionStepOutEx_NextOnlyFalse;
    procedure TestExceptionStepOverEx_NextOnlyFalse;
  end;

implementation

var
  ControlTest,
  ControlTest_NextOnlyTrue, ControlTestStepOver, ControlTestStepOverInstr,
  ControlTestExceptionStepOutEx, ControlTestExceptionStepOverEx: Pointer;

  ControlTest_NextOnly, ControlTestStepOver_NextOnly, ControlTestStepOverInstr_NextOnly,
  ControlTestExceptionStepOutEx_NextOnly, ControlTestExceptionStepOverEx_NextOnly: Pointer;

procedure TTestStepping.TestLocation(ATestName, ABrkName: String;
  ABreakHitCount: Integer; AnAcceptLinesBefore: integer);
var
  lc: TDBGLocationRec;
  brk: LongInt;
begin
  AssertDebuggerState(dsPause);
  lc := Debugger.LazDebugger.GetLocation;
  brk := Src.BreakPoints[ABrkName];
  if (AnAcceptLinesBefore > 0) and (lc.SrcLine < brk) and (lc.SrcLine >= brk - AnAcceptLinesBefore)
  then
    TestEquals(ATestName+' '+ABrkName+' Loc', brk, lc.SrcLine, 0, 'Ignored - In AcceptLinesBefore range')
  else
    TestEquals(ATestName+' '+ABrkName+' Loc', brk, lc.SrcLine);
  if ABreakHitCount >= 0 then
    TestEquals(ATestName+' '+ABrkName+' HitCnt', Debugger.BreakPointByName(ABrkName).HitCount, ABreakHitCount);
end;

function TTestStepping.IsAtLocation(ABrkName: String; ATrueOnNoLine: Boolean
  ): Boolean;
var
  lc: TDBGLocationRec;
begin
  lc := Debugger.LazDebugger.GetLocation;
  if (lc.SrcFile = '') then
    exit(ATrueOnNoLine);
  Result := Src.BreakPoints[ABrkName] = lc.SrcLine;
end;

procedure TTestStepping.DoDebuggerException(Sender: TObject;
  const AExceptionType: TDBGExceptionType; const AExceptionClass: String;
  const AExceptionLocation: TDBGLocationRec; const AExceptionText: String; out
  AContinue: Boolean);
begin
  inc(FGotExceptCount);
  FGotExceptClass := AExceptionClass;
  FGotExceptMsg   := AExceptionText;
  FGotExceptType  := AExceptionType;
  FGotExceptionLocation := AExceptionLocation;
  AContinue := FContinue;
end;

function TTestStepping.StepOverToLine(ATestName, ABrkName: String;
  AnExitIfNoLineInfo: Boolean): Boolean;
var
  mx: Integer;
begin
  mx := 100; // max steps
  Result := True;
  while not IsAtLocation(ABrkName, AnExitIfNoLineInfo) do begin
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause, ATestName);
    dec(mx);
    if mx = 0 then begin
      TestTrue(ATestName+'reached step target '+ ABrkName, False);
      Result := False;
      break;
    end;
  end;
  debugln(['XXXXXXXXXXXXXXXXXXXXXXXX to ', ABrkName, '  ',ATestName]);
end;

function TTestStepping.StepIfAtLine(ATestName, ABrkName: String): Boolean;
begin
  Result := True;
  if not IsAtLocation(ABrkName) then
    exit;
  Debugger.RunToNextPause(dcStepOver);
  TestTrue(ATestName+' finally entered at begin (not end) / '+ ABrkName, False, 0, 'ignore');
  AssertDebuggerState(dsPause, ATestName);
  debugln(['XXXXXXXXXXXXXXXXXXXXXXXX STEPPED from END LINE to begin??? ', ABrkName, '  ',ATestName]);
end;

procedure TTestStepping.DoTestStepOver(ANextOnlyStopOnStartLine: Boolean);
var
  ExeName: String;
  MainBrk, BrkDis, BrkHitCnt: TDBGBreakPoint;
  ThreadIdMain: Integer;
begin
  Src := GetCommonSourceFor(AppDir + 'StepOverPrg.pas');
  TestCompile(Src, ExeName);

  TestTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));
  dbg := Debugger.LazDebugger;
  TFpDebugDebuggerProperties(dbg.GetProperties).NextOnlyStopOnStartLine := ANextOnlyStopOnStartLine;

  try
    MainBrk := Debugger.SetBreakPoint(Src, 'BrkStart');
    Debugger.SetBreakPoint(Src, 'BrkThreadCreateInStep');
    Debugger.SetBreakPoint(Src, 'BrkInterfereByThread');
    Debugger.SetBreakPoint(Src, 'BrkNested');
    Debugger.SetBreakPoint(Src, 'CallStepOverEnd');

    BrkDis    := Debugger.SetBreakPoint(Src, 'BrkDisabled');
    BrkHitCnt := Debugger.SetBreakPoint(Src, 'BrkHitCnt');
    BrkDis.Enabled := False;
    BrkHitCnt.BreakHitCount := 999;
    AssertDebuggerNotInErrorState;

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('Init', 'BrkStart');
    ThreadIdMain := dbg.Threads.CurrentThreads.CurrentThreadId;

    // Step over a line
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStep', 'AfterStep', -1);

    // Step over a longer line
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepLongLine', 'AfterStepLongLine', -1);

    // Step over a subroutine call
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepProc', 'AfterStepProc', -1);

    // Step over a several subroutine calls
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepProcLong', 'AfterStepProcLong', -1);

    // Step over a subroutine call, with sleep
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepSleepProc', 'AfterStepSleepProc', -1);

    // Step over a call to sleep
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepSleep', 'AfterStepSleep', -1);

    // Step over a subroutine call, with a disabled breakpoint
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepBrkDis', 'AfterStepBrkDis', -1);

    // Step over a subroutine call, with a breakpoint that continues
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepBrkHitCnt', 'AfterStepBrkHitCnt', -1);

    TestEquals('No Hit for disabled break', 0, BrkDis.HitCount);
    TestEquals('No Hit for skipped break',  1, BrkHitCnt.HitCount);

    BrkDis.Enabled := True;
    // Step over a subroutine call, BUT STOP at the breakpoint within it
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At BrkDisabled', 'BrkDisabled', -1);
    // And do another step
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);

    TestEquals('No Hit for disabled break', 1, BrkDis.HitCount);
    TestEquals('No Hit for skipped break',  1, BrkHitCnt.HitCount);


    // Step over a RECURSIVE subroutine call
    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('At BrkNested', 'BrkNested', -1);

    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterNested', 'AfterNested', -1);


    (* The debugger will encounter a thread create event, during the stepping
       This will mean the main-loop's FCurrentThread is the new thread
    *)
    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('At BrkThreadCreateInStep', 'BrkThreadCreateInStep', -1);

    // This test can take longer, as the new thread gets very little scheduler time
    // during the single stepping of the main thread.
    Debugger.RunToNextPause(dcStepOver, 25000);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterThreadCreateInStep', 'AfterThreadCreateInStep', -1);
    TestEquals('ThreadId AfterThreadCreateInStep', ThreadIdMain, dbg.Threads.CurrentThreads.CurrentThreadId);

    (* The debugger will step over a call.
       Other threads will hit the FHiddenBreakpoint
    *)
    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('At BrkInterfereByThread', 'BrkInterfereByThread', -1);

    Debugger.RunToNextPause(dcStepOver);
    Debugger.RunToNextPause(dcStepOver);
    AssertDebuggerState(dsPause);
    TestLocation('At AfterInterfereByThread', 'AfterInterfereByThread', -1);
    TestEquals('ThreadId AfterInterfereByThread', ThreadIdMain, dbg.Threads.CurrentThreads.CurrentThreadId);




    (* go to CallMyNested
       Step into, and step to endline
       => ensure "end" takes ONE step to leave
    *)
    Debugger.RunToNextPause(dcRun);
    TestLocation('At CallStepOverEnd', 'CallStepOverEnd', -1);
    Debugger.RunToNextPause(dcStepInto);
    Debugger.RunToNextPause(dcStepOver);
    if not IsAtLocation('StepOverEnd') then  // depends on "begin" was code or not
      Debugger.RunToNextPause(dcStepOver);

    Debugger.RunToNextPause(dcStepInto);
    Debugger.RunToNextPause(dcStepOver);
    if not IsAtLocation('StepOverEnd') then  // depends on "begin" was code or not
      Debugger.RunToNextPause(dcStepOver);

    TestLocation('At StepOverEnd', 'StepOverEnd', -1);
    Debugger.RunToNextPause(dcStepOver);
    Debugger.RunToNextPause(dcStepOver);
    TestLocation('At AfterCallStepOverEnd', 'AfterCallStepOverEnd', -1);


    dbg.Stop;
  finally
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestStepping.TestStepOver;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestStepOver) then exit;
  DoTestStepOver(True);
end;

procedure TTestStepping.TestStepOverInstr;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestStepOverInstr) then exit;
  DoTestStepOverInstr(True);
end;

procedure TTestStepping.TestExceptionStepOutEx;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestExceptionStepOutEx) then exit;
  DoTestExceptionStepOutEx(True);
end;

procedure TTestStepping.TestExceptionStepOverEx;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestExceptionStepOverEx) then exit;
  DoTestExceptionStepOverEx(True);
end;

procedure TTestStepping.TestStepOver_NextOnlyFalse;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestStepOver_NextOnly) then exit;
  DoTestStepOver(False);
end;

procedure TTestStepping.TestStepOverInstr_NextOnlyFalse;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestStepOverInstr_NextOnly) then exit;
  DoTestStepOverInstr(False);
end;

procedure TTestStepping.TestExceptionStepOutEx_NextOnlyFalse;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestExceptionStepOutEx_NextOnly) then exit;
  DoTestExceptionStepOutEx(False);
end;

procedure TTestStepping.TestExceptionStepOverEx_NextOnlyFalse;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestExceptionStepOverEx_NextOnly) then exit;
  DoTestExceptionStepOverEx(False);
end;

procedure TTestStepping.DoTestStepOverInstr(ANextOnlyStopOnStartLine: Boolean);
  procedure StepInstrToNextLine(AName: String; MaxSteps: integer = 50);
  var
    lc: TDBGLocationRec;
  begin
    lc := Debugger.LazDebugger.GetLocation;
    repeat
      Debugger.RunToNextPause(dcStepOverInstr);
      AssertDebuggerState(dsPause, 'step instr '+AName);
      dec(MaxSteps);
    until (lc.SrcLine <> Debugger.LazDebugger.GetLocation.SrcLine) or (MaxSteps <= 0);
  end;

var
  ExeName: String;
  MainBrk, BrkDis, BrkHitCnt: TDBGBreakPoint;
  ThreadIdMain: Integer;
begin
  Src := GetCommonSourceFor(AppDir + 'StepOverPrg.pas');
  TestCompile(Src, ExeName);

  TestTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));
  dbg := Debugger.LazDebugger;
  TFpDebugDebuggerProperties(dbg.GetProperties).NextOnlyStopOnStartLine := ANextOnlyStopOnStartLine;

  try
    MainBrk := Debugger.SetBreakPoint(Src, 'BrkStart');
    Debugger.SetBreakPoint(Src, 'BrkThreadCreateInStep');
    Debugger.SetBreakPoint(Src, 'BrkInterfereByThread');
    Debugger.SetBreakPoint(Src, 'BrkNested');

    BrkDis    := Debugger.SetBreakPoint(Src, 'BrkDisabled');
    BrkHitCnt := Debugger.SetBreakPoint(Src, 'BrkHitCnt');
    BrkDis.Enabled := False;
    BrkHitCnt.BreakHitCount := 999;
    AssertDebuggerNotInErrorState;

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('Init', 'BrkStart');
    ThreadIdMain := dbg.Threads.CurrentThreads.CurrentThreadId;

    StepInstrToNextLine('Go to AfterStep');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStep', 'AfterStep', -1);

    StepInstrToNextLine('Go to AfterStepLongLine');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepLongLine', 'AfterStepLongLine', -1);

    StepInstrToNextLine('Go to AfterStepProc');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepProc', 'AfterStepProc', -1);

    StepInstrToNextLine('Go to AfterStepProcLong');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepProcLong', 'AfterStepProcLong', -1);

    StepInstrToNextLine('Go to AfterStepSleepProc');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepSleepProc', 'AfterStepSleepProc', -1);

    StepInstrToNextLine('Go to AfterStepSleep');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepSleep', 'AfterStepSleep', -1);

    StepInstrToNextLine('Go to AfterStepBrkDis');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepBrkDis', 'AfterStepBrkDis', -1);

    StepInstrToNextLine('Go to AfterStepBrkHitCnt');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterStepBrkHitCnt', 'AfterStepBrkHitCnt', -1);

    TestEquals('No Hit for disabled break', 0, BrkDis.HitCount);
    TestEquals('No Hit for skipped break',  1, BrkHitCnt.HitCount);


    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    TestLocation('At BrkNested', 'BrkNested', -1);

    StepInstrToNextLine('Go to AfterNested 1');
    AssertDebuggerState(dsPause);
    StepInstrToNextLine('Go to AfterNested 2');
    AssertDebuggerState(dsPause);
    TestLocation('At AfterNested', 'AfterNested', -1);



    dbg.Stop;
  finally
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestStepping.DoTestExceptionStepOutEx(
  ANextOnlyStopOnStartLine: Boolean);
var
  ExeName, TstName: String;
begin
  ClearTestErrors;
  FGotExceptCount := 0;

  Src := GetCommonSourceFor(AppDir + 'ExceptTestPrg.pas');
  TestCompile(Src, ExeName);

  TestTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));
  dbg := Debugger.LazDebugger;
  TFpDebugDebuggerProperties(dbg.GetProperties).NextOnlyStopOnStartLine := ANextOnlyStopOnStartLine;
  try
    dbg.Exceptions.Add('MyExceptionIgnore').Enabled := False;
    dbg.OnException      := @DoDebuggerException;

    TstName := ' Run to Except';
    FContinue := False;
    Debugger.RunToNextPause(dcRun);
    TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
//    TestLocation(TstName+': CurLine ', 'BrkMyRaise', -1);
    FContinue := True;

    TstName := ' Step';
    Debugger.RunToNextPause(dcStepOver);
    TestLocation(TstName+': CurLine ', 'BrkStep3Fin_A', -1);

    Debugger.RunToNextPause(dcStepOut);
    TestLocation(TstName+': CurLine ', 'BrkStep3FinOuter_A', -1);

    Debugger.RunToNextPause(dcStepOut);
    TestLocation(TstName+': CurLine ', 'BrkStepMainExcept1', -1, 1);


    dbg.Stop;
  finally
    Debugger.FreeDebugger;
  end;

  AssertTestErrors;
end;

procedure TTestStepping.DoTestExceptionStepOverEx(
  ANextOnlyStopOnStartLine: Boolean);
  procedure ExpectEnterFinally(AName: String; ATestAppRecStep: Integer;
    ATestIgnoreRaise, ATestRaiseSkipped, ATestStepOverNested: Boolean;
    ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2: Boolean);
  var
    TstName: String;
    MyRaiseBrk: TDBGBreakPoint;
  begin
    TstName := AName + ' Run to raise';
    FGotExceptCount := 0;
    FContinue := ATestIgnoreRaise or ATestStepOverNested;

    if ATestStepOverNested then begin
      // step to call line, starting on:  Nop => TestVal => If ... then => call
      Debugger.RunToNextPause(dcStepOver);
      Debugger.RunToNextPause(dcStepOver);
      Debugger.RunToNextPause(dcStepOver);
// step is done by caller
//      Debugger.RunToNextPause(dcStepOver);  // Step over recurse
      //TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
      exit;
    end
    else
    if ATestIgnoreRaise then begin
      MyRaiseBrk := Debugger.SetBreakPoint(Src, 'BrkMyRaise');
      Debugger.RunToNextPause(dcRun);
      MyRaiseBrk.ReleaseReference;
      Debugger.RunToNextPause(dcStepOver);  // exception will be ignored => step to finally
      TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
    end
    else begin
      Debugger.RunToNextPause(dcRun);
      TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
// TODO: currently reports in except.inc
//      TestLocation(TstName+': CurLine ', 'BrkMyRaise', -1);
      Debugger.RunToNextPause(dcStepOver);
    end;

    TstName := AName + ' Run to Finally A';
    TestLocation(TstName+': CurLine ', 'BrkStep3Fin_A', -1);

    if (ATestAppRecStep = 1) and (not ATestRaiseSkipped) then
      ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    else
      StepOverToLine(TstName, 'BrkStep3Fin_A_END', True);

    TstName := AName + ' Run to Finally B';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStep3Fin_B', -1);

    //if (ATestAppRecStep = 2) and (not ATestRaiseSkipped) then
    //  ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    //else
      StepOverToLine(TstName, 'BrkStep3Fin_B_END', True);

    TstName := AName + ' Run to Finally C';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStep3Fin_C', -1);

    if (ATestAppRecStep = 2) and (not ATestRaiseSkipped) then
      ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    else
      StepOverToLine(TstName, 'BrkStep3Fin_C_END', True);

    TstName := AName + ' Run to Finally A(outer)';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    //StepIfAtLine(TstName, 'BrkStep3Fin_IMPLICIT'); // 32 bit
    //StepIfAtLine(TstName, 'BrkStep3Fin_IMPLICIT_1');
    TestLocation(TstName+': CurLine ', 'BrkStep3FinOuter_A', -1);

    if (ATestAppRecStep = 3) and (not ATestRaiseSkipped) then
      ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    else
      StepOverToLine(TstName, 'BrkStep3FinOuter_A_END', True);

    TstName := AName + ' Run to Finally B(outer)';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStep3FinOuter_B', -1);

    //if (ATestAppRecStep = 5) and (not ATestRaiseSkipped) then
    //  ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    //else
      StepOverToLine(TstName, 'BrkStep3FinOuter_B_END', True);

    TstName := AName + ' Run to Finally C(outer)';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStep3FinOuter_C', -1);

    if (ATestAppRecStep = 4) and (not ATestRaiseSkipped) then
      ExpectEnterFinally(TstName+' INNER ', 0, ATestIgnoreRaise_2, ATestRaiseSkipped_2, ATestStepOverNested_2, False, False, False)
    else
      StepOverToLine(TstName,'BrkStep3FinOuter_C_END', True);
  end;

  procedure ExpectNestedExcept(AName: String);
  var
    TstName: String;
  begin
    TstName := AName + ' Run to raise';
    FGotExceptCount := 0;
    FContinue := False;
    Debugger.RunToNextPause(dcRun);
    TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
//    TestLocation(TstName+': CurLine ', 'BrkMyRaise', -1);

    TstName := AName + ' Run to except fin';
    Debugger.RunToNextPause(dcStepOver);  // Step to fin
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept_Finally', -1);

    // NESTED
    TstName := AName + ' Run to raise nested';
    FGotExceptCount := 0;
    FContinue := False;
    Debugger.RunToNextPause(dcRun);
    TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
//    TestLocation(TstName+': CurLine ', 'BrkMyRaise', -1);

    TstName := AName + ' Run to except fin nested';
    Debugger.RunToNextPause(dcStepOver);  // Step to fin
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept_Finally', -1);

    StepOverToLine(TstName,'BrkStepNestedExcept_Finally_END', True);

    TstName := AName + ' Run to except nested';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept', -1, 1);

    StepOverToLine(TstName,'BrkStepNestedExcept_END', True);
    // END NESTED

    TstName := AName + ' Run back except fin';
    Debugger.RunToNextPause(dcStepOver);  // Step back to end
    StepIfAtLine(TstName, 'BrkStepNestedExcept_TRY'); // may step to "try"
    Debugger.RunToNextPause(dcStepOver);  // Step back to finaly
    //if not ANextOnlyStopOnStartLine then
    //  StepIfAtLine(TstName, 'BrkStepNestedExcept_Finally_BEFORE'); // TODO: XXXXX StepOver may stop at the step out line.
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept_Finally_AFTER', -1);

    StepOverToLine(TstName,'BrkStepNestedExcept_Finally_END', True);

    TstName := AName + ' Run to except';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept', -1, 1);

    Debugger.RunToNextPause(dcStepOut);  // Step out
  end;

  procedure ExpectNestedExcept_Ignore(AName: String);
  var
    TstName: String;
  begin
    TstName := AName + ' Run to raise';
    FGotExceptCount := 0;
    FContinue := False;
    Debugger.RunToNextPause(dcRun);
    TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
//    TestLocation(TstName+': CurLine ', 'BrkMyRaise', -1);

    TstName := AName + ' Run to except fin';
    Debugger.RunToNextPause(dcStepOver);  // Step to fin
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept_Finally', -1);

    // NESTED
    TstName := AName + ' Step over raise nested';
    FGotExceptCount := 0;
    FContinue := True;
    StepOverToLine(TstName,'BrkStepNestedExcept_Finally_BEFORE', True);
    Debugger.RunToNextPause(dcStepOver);
    TestEquals(TstName+': Got 1 exceptions: ', 1, FGotExceptCount);
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept_Finally_AFTER', -1);

    StepOverToLine(TstName,'BrkStepNestedExcept_Finally_END', True);

    TstName := AName + ' Run to except';
    Debugger.RunToNextPause(dcStepOver);  // Step to next finally
    TestLocation(TstName+': CurLine ', 'BrkStepNestedExcept', -1, 1);

    //StepOverToLine(TstName,'BrkStepNestedExcept_END', True);
    Debugger.RunToNextPause(dcStepOut);  // Step out

  end;

var
  ExeName, TstName, LName: String;
  TestAppRecRaise, TestAppRecStep: Integer;
begin
  ClearTestErrors;

  Src := GetCommonSourceFor(AppDir + 'ExceptTestPrg.pas');
  TestCompile(Src, ExeName);

  TestTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));
  dbg := Debugger.LazDebugger;
  TFpDebugDebuggerProperties(dbg.GetProperties).NextOnlyStopOnStartLine := ANextOnlyStopOnStartLine;
  try
    dbg.Exceptions.Add('MyExceptionIgnore').Enabled := False;
    dbg.OnException      := @DoDebuggerException;

    (* RecRaise
       0 : Step in => Raise nested except and debugger breaks at except, step to finally
       1 : Step in => Raise nested except but debugger continues at except, step ends in finally
       2 : Step in => do NOT raise nested except. Step through all the finally
       3 : Step over => Raise nested except but debugger continues at except => nested finally NOT paused by debugger
    *)
    for TestAppRecRaise := 0 to 3 do
    for TestAppRecStep := 0 to 4 do
    if (TestAppRecRaise = 0) or (TestAppRecStep in [0,1,4]) then
    begin
      LName := Format('[RecRaise=%d / RecStep=%d] ', [TestAppRecRaise, TestAppRecStep]);
      ExpectEnterFinally(LName, TestAppRecStep,
         False, False, False,
         TestAppRecRaise = 1, TestAppRecRaise = 2, TestAppRecRaise = 3);

      TstName := LName + ' Run to Except (Main)';
      Debugger.RunToNextPause(dcStepOver);  // Step to next finally
      //StepIfAtLine(TstName, 'BrkStep3FinOuter_IMPLICIT'); // 32 bit
      //StepIfAtLine(TstName, 'BrkStep3FinOuter_IMPLICIT_1');
      TestLocation(TstName+': CurLine ', 'BrkStepMainExcept1', -1, 1);

      TstName := LName + ' Step to After Except (Main)';
      Debugger.RunToNextPause(dcStepOver);
      StepOverToLine(TstName,'BrkStepMainAfterExcept1', True);
      TestLocation(TstName+': CurLine ', 'BrkStepMainAfterExcept1', -1);
    end;

    ExpectNestedExcept('Nested Except 1');

    ExpectNestedExcept_Ignore('Nested Except Ignore');

    dbg.Stop;
  finally
    Debugger.FreeDebugger;
  end;

  AssertTestErrors;
end;


initialization

  RegisterDbgTest(TTestStepping);

  ControlTest              := TestControlRegisterTest('TTestStepping');
  ControlTest_NextOnlyTrue := TestControlRegisterTest('TTestStepping_NextOnly=True', ControlTest);
  ControlTestStepOver      := TestControlRegisterTest('TTestStepOver', ControlTest_NextOnlyTrue);
  ControlTestStepOverInstr := TestControlRegisterTest('TTestStepOverInstr', ControlTest_NextOnlyTrue);
  ControlTestExceptionStepOutEx  := TestControlRegisterTest('TTestExceptionStepOutEx', ControlTest_NextOnlyTrue);
  ControlTestExceptionStepOverEx := TestControlRegisterTest('TTestExceptionStepOverEx', ControlTest_NextOnlyTrue);

  ControlTest_NextOnly              := TestControlRegisterTest('TTestStepping_NextOnly=False', ControlTest);
  ControlTestStepOver_NextOnly      := TestControlRegisterTest('TTestStepOver_NextOnly=False', ControlTest_NextOnly);
  ControlTestStepOverInstr_NextOnly := TestControlRegisterTest('TTestStepOverInstr_NextOnly=False', ControlTest_NextOnly);
  ControlTestExceptionStepOutEx_NextOnly  := TestControlRegisterTest('TTestExceptionStepOutEx_NextOnly=False', ControlTest_NextOnly);
  ControlTestExceptionStepOverEx_NextOnly := TestControlRegisterTest('TTestExceptionStepOverEx_NextOnly=False', ControlTest_NextOnly);
end.


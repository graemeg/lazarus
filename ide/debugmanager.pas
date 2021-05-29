{  $Id$  }
{
 /***************************************************************************
                             debugmanager.pp
                             ---------------
      TDebugManager controls all debugging related stuff in the IDE.


 ***************************************************************************/

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
unit DebugManager;

{$mode objfpc}{$H+}

interface

{$I ide.inc}
{off $define VerboseDebugger}

uses
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, math,
  // LCL
  LCLType, LCLIntf, Forms, Controls, Dialogs, ExtCtrls,
  // LazUtils
  LazFileUtils, LazFileCache, LazLoggerBase, Laz2_XMLCfg, LazUTF8, LazTracer,
  // codetools
  CodeCache, CodeToolManager, PascalParserTool, CodeTree,
  // IDEIntf
  IDEWindowIntf, SrcEditorIntf, MenuIntf, IDECommands, LazIDEIntf, ProjectIntf,
  CompOptsIntf, IDEDialogs, ToolBarIntf,
  // IDE
  CompilerOptions, EnvironmentOpts, SourceEditor, ProjectDefs, Project,
  InputHistory, Debugger, LazarusIDEStrConsts, TransferMacros,
  MainBar, MainIntf, MainBase, BaseBuildManager, SourceMarks, DebuggerDlg,
  Watchesdlg, BreakPointsdlg, BreakPropertyDlg, LocalsDlg, WatchPropertyDlg,
  CallStackDlg, EvaluateDlg, RegistersDlg, AssemblerDlg, DebugOutputForm,
  ExceptionDlg, InspectDlg, DebugEventsForm, PseudoTerminalDlg, FeedbackDlg,
  ThreadDlg, HistoryDlg, ProcessDebugger, DbgIntfBaseTypes, DbgIntfDebuggerBase,
  DbgIntfMiscClasses, DbgIntfPseudoTerminal, BaseDebugManager;


type

  { TDebugEventLogManager }

  TDebugEventLogManager = class(TObject, TDebuggerEventLogInterface)
  private
    FEventDialog: TDbgEventsForm;
    FHiddenDebugEventsLog: TStringList;
    FTargetWidth: Integer;
    procedure SetEventDialog(AValue: TDbgEventsForm);
    function  FormatBreakPointAddress(const ABreakpoint: TDBGBreakPoint;
                const ALocation: TDBGLocationRec): String;
  protected
    procedure DebuggerEvent(Sender: TObject; const ACategory: TDBGEventCategory; const AEventType: TDBGEventType; const AText: String);
  public
    procedure LogCustomEvent(const ACategory: TDBGEventCategory;
                const AEventType: TDBGEventType; const AText: String);
    procedure LogEventBreakPointHit(const ABreakpoint: TDBGBreakPoint; const ALocation: TDBGLocationRec);
    procedure LogEventWatchPointTriggered(const ABreakpoint: TDBGBreakPoint;
                const ALocation: TDBGLocationRec; const AOldWatchedVal, ANewWatchedVal: String);
    procedure LogEventWatchPointScope(const ABreakpoint: TDBGBreakPoint;
                const ALocation: TDBGLocationRec);
  public
    destructor Destroy; override;
    procedure ClearDebugEventsLog;
    property EventDialog: TDbgEventsForm read FEventDialog write SetEventDialog;
    property TargetWidth: Integer read FTargetWidth write FTargetWidth;
  end;

  { TDebugManager }

  TDebugManager = class(TBaseDebugManager)
    procedure DebuggerIdle(Sender: TObject);
    function DoProjectClose(Sender: TObject; AProject: TLazProject): TModalResult;
    procedure DoProjectModified(Sender: TObject);
  private
    FAsmWindowShouldAutoClose: Boolean;
    procedure BreakAutoContinueTimer(Sender: TObject);
    procedure OnRunTimer(Sender: TObject);
    // Menu events
    procedure mnuViewDebugDialogClick(Sender: TObject);
    procedure mnuResetDebuggerClicked(Sender: TObject);
    procedure mnuAddWatchClicked(Sender: TObject);
    procedure mnuAddBpAddress(Sender: TObject);
    procedure mnuAddBpSource(Sender: TObject);
    procedure mnuAddBpData(Sender: TObject);
    procedure mnuAddBpDataAtCursor(Sender: TObject);

    // Debugger events
    procedure DebuggerBreakPointHit({%H-}ADebugger: TDebuggerIntf; ABreakPoint: TBaseBreakPoint; var {%H-}ACanContinue: Boolean);
    procedure DebuggerBeforeChangeState(ADebugger: TDebuggerIntf; AOldState: TDBGState);
    procedure DebuggerChangeState(ADebugger: TDebuggerIntf; OldState: TDBGState);
    procedure DebuggerCurrentLine(Sender: TObject; const ALocation: TDBGLocationRec);
    procedure DebuggerOutput(Sender: TObject; const AText: String);
    procedure DebuggerConsoleOutput(Sender: TObject; const AText: String);
    function DebuggerFeedback(Sender: TObject; const AText, AInfo: String;
      AType: TDBGFeedbackType; AButtons: TDBGFeedbackResults): TDBGFeedbackResult;
    procedure DebuggerException(Sender: TObject;
      const AExceptionType: TDBGExceptionType;
      const AExceptionClass: String;
      const AExceptionLocation: TDBGLocationRec;
      const AExceptionText: String;
      out AContinue: Boolean);

    // Dialog events
    procedure DebugDialogDestroy(Sender: TObject);
  private
    FDebugger: TDebuggerIntf;
    FEventLogManager: TDebugEventLogManager;
    FUnitInfoProvider: TDebuggerUnitInfoProvider;
    FDialogs: array[TDebugDialogType] of TDebuggerDlg;
    FInStateChange: Boolean;
    FPrevShownWindow: HWND;
    FStepping: Boolean;
    // keep track of the last reported location
    FCurrentLocation: TDBGLocationRec;
    // last hit breakpoint
    FCurrentBreakpoint: TIDEBreakpoint;
    FAutoContinueTimer: TTimer;
    FIsInitializingDebugger: Boolean;

    // When a source file is not found, the user can choose one
    // here are all choices stored
    FUserSourceFiles: TStringList;

    // when the debug output log is not open, store the debug log internally
    FHiddenDebugOutputLog: TStringList;

    FRunTimer: TTimer;
    FAttachToID: String;

    procedure SetDebugger(const ADebugger: TDebuggerIntf);

    // Breakpoint routines
    procedure CreateSourceMarkForBreakPoint(const ABreakpoint: TIDEBreakPoint;
                                            ASrcEdit: TSourceEditor);
    procedure GetSourceEditorForBreakPoint(const ABreakpoint: TIDEBreakPoint;
                                           var ASrcEdit: TSourceEditor);

    // Dialog routines
    procedure DestroyDebugDialog(const ADialogType: TDebugDialogType);
    procedure InitDebugOutputDlg;
    procedure InitDebugEventsDlg;
    procedure InitBreakPointDlg;
    procedure InitWatchesDlg;
    procedure InitThreadsDlg;
    procedure InitPseudoTerminal;
    procedure InitLocalsDlg;
    procedure InitCallStackDlg;
    procedure InitEvaluateDlg;
    procedure InitRegistersDlg;
    procedure InitAssemblerDlg;
    procedure InitInspectDlg;
    procedure InitHistoryDlg;

    procedure FreeDebugger;
    procedure ResetDebugger;

    function GetLaunchPathAndExe(out LaunchingCmdLine, LaunchingApplication,
                                     LaunchingParams: String; PromptOnError: Boolean = True): Boolean;
  protected
    function  GetState: TDBGState; override;
    function  GetCommands: TDBGCommands; override;
    function GetPseudoTerminal: TPseudoTerminal; override;
    function GetDebuggerClass: TDebuggerClass;
    {$IFDEF DBG_WITH_DEBUGGER_DEBUG}
    function GetDebugger: TDebuggerIntf; override;
    {$ENDIF}
    function GetCurrentDebuggerClass: TDebuggerClass; override;    (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834   *)
    function AttachDebugger: TModalResult;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Reset; override;

    procedure ConnectMainBarEvents; override;
    procedure ConnectSourceNotebookEvents; override;
    procedure SetupMainBarShortCuts; override;
    procedure SetupSourceMenuShortCuts; override;
    procedure UpdateButtonsAndMenuItems; override;
    procedure UpdateToolStatus; override;
    procedure EnvironmentOptsChanged; override;

    procedure LoadProjectSpecificInfo(XMLConfig: TXMLConfig;
                                      Merge: boolean); override;
    procedure SaveProjectSpecificInfo(XMLConfig: TXMLConfig;
                                      Flags: TProjectWriteFlags); override;
    procedure DoRestoreDebuggerMarks(AnUnitInfo: TUnitInfo); override;
    procedure ClearDebugOutputLog;
    procedure ClearDebugEventsLog;

    function RequiredCompilerOpts(ATargetCPU, ATargetOS: String
      ): TDebugCompilerRequirements; override;
    function InitDebugger(AFlags: TDbgInitFlags = []): Boolean; override;
    function DoSetBreakkPointWarnIfNoDebugger: boolean;

    function DoPauseProject: TModalResult; override;
    function DoShowExecutionPoint: TModalResult; override;
    function DoStepIntoProject: TModalResult; override;
    function DoStepOverProject: TModalResult; override;
    function DoStepIntoInstrProject: TModalResult; override;
    function DoStepOverInstrProject: TModalResult; override;
    function DoStepOutProject: TModalResult; override;
    function DoStepToCursor: TModalResult; override;
    function DoRunToCursor: TModalResult; override;
    function DoStopProject: TModalResult; override;
    procedure DoToggleCallStack; override;
    procedure DoSendConsoleInput(AText: String); override;
    procedure ProcessCommand(Command: word; var Handled: boolean); override;

    //Some debuugers may do things like ProcessMessages while processing commands
    //and that can cause side-effects
    //The debugger may run it's queue either during UnLockCommandProcessing or later
    procedure LockCommandProcessing; override;
    procedure UnLockCommandProcessing; override;

    function StartDebugging: TModalResult; override; // returns immediately
    function RunDebugger: TModalResult; override; // waits till program ends
    procedure EndDebugging; override;

    procedure Attach(AProcessID: String); override;
    function FillProcessList(AList: TRunningProcessInfoList): boolean; override;
    procedure Detach; override;

    function Evaluate(const AExpression: String; ACallback: TDBGEvaluateResultCallback;
                      EvalFlags: TDBGEvaluateFlags = []): Boolean; override;
    function Modify(const AExpression, ANewValue: String): Boolean; override;

    procedure EvaluateModify(const AExpression: String); override;
    procedure Inspect(const AExpression: String); override;

    function GetFullFilename(const AUnitinfo: TDebuggerUnitInfo; out Filename: string;
                             AskUserIfNotFound: Boolean): Boolean; override;
    function GetFullFilename(var Filename: string; AskUserIfNotFound: Boolean): Boolean; override;

    function DoCreateBreakPoint(const AFilename: string; ALine: integer;
                                WarnIfNoDebugger: boolean): TModalResult; override;
    function DoCreateBreakPoint(const AFilename: string; ALine: integer;
                                WarnIfNoDebugger: boolean;
                                out ABrkPoint: TIDEBreakPoint;
                                AnUpdating: Boolean = False): TModalResult; override;
    function DoCreateBreakPoint(const AnAddr: TDBGPtr;
                                WarnIfNoDebugger: boolean;
                                out ABrkPoint: TIDEBreakPoint;
                                AnUpdating: Boolean = False): TModalResult; override;

    function DoDeleteBreakPoint(const AFilename: string;
                                ALine: integer): TModalResult; override;
    function DoDeleteBreakPointAtMark(
                        const ASourceMark: TSourceMark): TModalResult; override;

    function ShowBreakPointProperties(const ABreakpoint: TIDEBreakPoint): TModalresult; override;
    function ShowWatchProperties(const AWatch: TCurrentWatch; AWatchExpression: String = ''): TModalresult; override;

    // Dialog routines
    procedure CreateDebugDialog(Sender: TObject; aFormName: string;
                          var AForm: TCustomForm; DoDisableAutoSizing: boolean); override;
    procedure ViewDebugDialog(const ADialogType: TDebugDialogType; BringToFront: Boolean = true; Show: Boolean = true; DoDisableAutoSizing: boolean = false); override;
    procedure ViewDisassembler(AnAddr: TDBGPtr;
                              BringToFront: Boolean = True; Show: Boolean = true;
                              DoDisableAutoSizing: boolean = false); override;
  end;

function DBGDateTimeFormatter(const aValue: string): string;

implementation

var
  DBG_LOCATION_INFO: PLazLoggerLogGroup;

function DBGDateTimeFormatter(const aValue: string): string;
var
  FS: TFormatSettings;
  MyDate: Extended;
begin
  FillChar(FS{%H-}, SizeOf(TFormatSettings), 0);
  FS.DecimalSeparator := '.';
  if TryStrToFloat(aValue, MyDate, FS) then
  begin
    // it is important to know datetime for all TDate/TTime/TDateTime
    if SameValue(Frac(MyDate), 0) then
      Result := DateToStr(MyDate)
    else
    if SameValue(Int(MyDate), 0) then
      Result := TimeToStr(MyDate)
    else
      Result := DateTimeToStr(MyDate);
  end else
    Result := aValue;
end;

type

  { TManagedBreakPoint }

  TManagedBreakPoint = class(TIDEBreakPoint)
  private
    FSourceMark: TSourceMark;
    FCurrentDebugExeLine: Integer;
    procedure OnSourceMarkBeforeFree(Sender: TObject);
    procedure OnSourceMarkCreatePopupMenu(SenderMark: TSourceMark;
                                          const AddMenuItem: TAddMenuItemProc);
    procedure OnSourceMarkGetHint(SenderMark: TSourceMark; var Hint: string);
    procedure OnSourceMarkPositionChanged(Sender: TObject);
    procedure OnToggleEnableMenuItemClick(Sender: TObject);
    procedure OnDeleteMenuItemClick(Sender: TObject);
    procedure OnViewPropertiesMenuItemClick(Sender: TObject);
  protected
    procedure DoChanged; override;

    procedure SetSourceMark(const AValue: TSourceMark);
    procedure UpdateSourceMark;
    procedure UpdateSourceMarkImage;
    procedure UpdateSourceMarkLineColor;
    function  DebugExeLine: Integer; override; // If known, the line in the compiled exe
  public
    procedure CopySourcePositionToBreakPoint;
    procedure SetLocation(const ASource: String; const ALine: Integer); override;
    property SourceMark: TSourceMark read FSourceMark write SetSourceMark;
  end;

  { TManagedBreakPoints }

  TManagedBreakPoints = class(TIDEBreakPoints)
  private
    FManager: TDebugManager;
  protected
    procedure NotifyAdd(const ABreakPoint: TIDEBreakPoint); override;
    procedure NotifyRemove(const ABreakPoint: TIDEBreakPoint); override;
    procedure Update(Item: TCollectionItem); override;
  public
    constructor Create(const AManager: TDebugManager);
  end;

  { TProjectExceptions }

  TProjectExceptions = class(TIDEExceptions)
  protected
    procedure SetIgnoreAll(const AValue: Boolean); override;
    procedure Notify(Item: TCollectionItem; Action: TCollectionNotification); override;
    procedure Update(Item: TCollectionItem); override;
  end;

{ TDebugEventLogManager }

procedure TDebugEventLogManager.SetEventDialog(AValue: TDbgEventsForm);
begin
  if FEventDialog = AValue then Exit;

  If AValue = nil then begin
    if FHiddenDebugEventsLog=nil then
      FHiddenDebugEventsLog:=TStringList.Create;
    FEventDialog.GetEvents(FHiddenDebugEventsLog);
  end
  else
  if FHiddenDebugEventsLog <> nil then begin
    AValue.SetEvents(FHiddenDebugEventsLog);
    FreeAndNil(FHiddenDebugEventsLog);
  end;

  FEventDialog := AValue;
end;

function TDebugEventLogManager.FormatBreakPointAddress(
  const ABreakpoint: TDBGBreakPoint; const ALocation: TDBGLocationRec): String;
var
  SrcName: String;
begin
  SrcName := ALocation.SrcFullName;
  if SrcName = '' then
    SrcName := ALocation.SrcFile;

  if SrcName <> '' then
    Result := Format(dbgEventBreakAtAddressSourceLine,
                      [IntToHex(ALocation.Address, FTargetWidth), SrcName, ALocation.SrcLine])
  else
  if (ABreakpoint <> nil) and (ABreakPoint.Kind = bpkSource) then
    Result := Format(dbgEventBreakAtAddressOriginSourceOriginLine,
                      [IntToHex(ALocation.Address, FTargetWidth), ABreakpoint.Source, ABreakpoint.Line])
  else
    Result := Format(dbgEventBreakAtAddress, [IntToHex(ALocation.Address,
      FTargetWidth)]);
end;

procedure TDebugEventLogManager.DebuggerEvent(Sender: TObject;
  const ACategory: TDBGEventCategory; const AEventType: TDBGEventType;
  const AText: String);
var
  Rec: TDBGEventRec;
begin
  if EventDialog <> nil
  then begin
    EventDialog.AddEvent(ACategory, AEventType, AText)
  end
  else begin
    // store it internally, and copy it to the dialog, when the user opens it
    if FHiddenDebugEventsLog=nil
    then FHiddenDebugEventsLog := TStringList.Create;
    if EnvironmentOptions.DebuggerEventLogCheckLineLimit
    then begin
      while FHiddenDebugEventsLog.Count >= EnvironmentOptions.DebuggerEventLogLineLimit do
        FHiddenDebugEventsLog.Delete(0);
    end;
    Rec.Category := Ord(ACategory);
    Rec.EventType := Ord(AEventType);
    FHiddenDebugEventsLog.AddObject(AText, TObject(Rec.Ptr));
  end;
end;

procedure TDebugEventLogManager.LogCustomEvent(
  const ACategory: TDBGEventCategory; const AEventType: TDBGEventType;
  const AText: String);
begin
  DebuggerEvent(nil, ACategory, AEventType, AText);
end;

procedure TDebugEventLogManager.LogEventBreakPointHit(
  const ABreakpoint: TDBGBreakPoint; const ALocation: TDBGLocationRec);
var
  Msg: String;
begin
  if ABreakpoint = nil then
    Msg := dbgEventBreakUnknownBreakPoint
  else
  case ABreakPoint.Kind of
    bpkSource:  Msg := dbgEventBreakSourceBreakPoint;
    bpkAddress: Msg := dbgEventBreakAddressBreakPoint;
    bpkData:    Msg := dbgEventBreakWatchPoint; // should not be here, use LogEventWatchPointTriggered();
  end;

  LogCustomEvent(ecBreakpoint, etBreakpointHit,
    Format(Msg, [FormatBreakPointAddress(ABreakpoint, ALocation)]));
end;

procedure TDebugEventLogManager.LogEventWatchPointTriggered(
  const ABreakpoint: TDBGBreakPoint; const ALocation: TDBGLocationRec;
  const AOldWatchedVal, ANewWatchedVal: String);
var
  Msg, Loc: String;
begin
  Loc := FormatBreakPointAddress(ABreakpoint, ALocation);
  if ABreakpoint = nil then
    Msg := Format(dbgEventUnknownWatchPointTriggered, [Loc, AOldWatchedVal, ANewWatchedVal])
  else
  case ABreakPoint.Kind of
    bpkSource:  Msg := Format(dbgEventBreakSourceBreakPoint , [Loc]); // should not be here
    bpkAddress: Msg := Format(dbgEventBreakAddressBreakPoint, [Loc]); // should not be here
    bpkData:    Msg := Format(dbgEventWatchTriggered, [ABreakpoint.WatchData, Loc,
      AOldWatchedVal, ANewWatchedVal]);
  end;

  LogCustomEvent(ecBreakpoint, etBreakpointHit, Msg );
end;

procedure TDebugEventLogManager.LogEventWatchPointScope(
  const ABreakpoint: TDBGBreakPoint; const ALocation: TDBGLocationRec);
var
  Msg, Loc: String;
begin
  Loc := FormatBreakPointAddress(ABreakpoint, ALocation);
  if ABreakpoint = nil then
    Msg := Format(dbgEventUnknownWatchPointScopeEnded, [Loc])
  else
  case ABreakPoint.Kind of
    bpkSource:  Msg := Format(dbgEventBreakSourceBreakPoint , [Loc]); // should not be here
    bpkAddress: Msg := Format(dbgEventBreakAddressBreakPoint, [Loc]); // should not be here
    bpkData:    Format(dbgEventWatchScopeEnded, [ABreakpoint.WatchData, Loc])
  end;

  LogCustomEvent(ecBreakpoint, etBreakpointHit, Msg );
end;

destructor TDebugEventLogManager.Destroy;
begin
  FreeAndNil(FHiddenDebugEventsLog);
  inherited Destroy;
end;

procedure TDebugEventLogManager.ClearDebugEventsLog;
begin
  if EventDialog <> nil then
    EventDialog.Clear;
  FreeAndNil(FHiddenDebugEventsLog);
end;

{ TProjectExceptions }

procedure TProjectExceptions.SetIgnoreAll(const AValue: Boolean);
begin
  // Todo: move to Changed or Update, but they are called too often...
  if (IgnoreAll <> AValue) and (Project1 <> nil) then
    Project1.Modified := True;
  inherited SetIgnoreAll(AValue);
end;

procedure TProjectExceptions.Notify(Item: TCollectionItem; Action: TCollectionNotification);
begin
  inherited Notify(Item, Action);
  if Project1 <> nil then
    Project1.Modified := True;
end;

procedure TProjectExceptions.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if Project1 <> nil then
    Project1.Modified := True;
end;

{ TManagedBreakPoints }

constructor TManagedBreakPoints.Create(const AManager: TDebugManager);
begin
  FManager := AManager;
  inherited Create(TManagedBreakPoint);
end;

procedure TManagedBreakPoints.NotifyAdd(const ABreakPoint: TIDEBreakPoint);
begin
{$ifdef VerboseDebugger}
  debugln('TManagedBreakPoints.NotifyAdd A ',ABreakpoint.Source,' ',IntToStr(ABreakpoint.Line));
{$endif}
  inherited;

  FManager.CreateSourceMarkForBreakPoint(ABreakpoint,nil);
  Project1.Modified := True;
end;

procedure TManagedBreakPoints.NotifyRemove(const ABreakPoint: TIDEBreakPoint);
begin
{$ifdef VerboseDebugger}
  debugln(['TManagedBreakPoints.NotifyRemove A ',ABreakpoint.Source,' ',ABreakpoint.Line,' ',TManagedBreakPoint(ABreakpoint).SourceMark <> nil]);
{$endif}

  inherited;
  if FManager.FCurrentBreakpoint = ABreakPoint
  then FManager.FCurrentBreakpoint := nil;

  TManagedBreakPoint(ABreakpoint).SourceMark.Free;

  if Project1 <> nil
  then Project1.Modified := True;
end;

procedure TManagedBreakPoints.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  if (Project1 <> nil) and (Item is TIDEBreakPoint) and (TIDEBreakPoint(Item).UserModified)
  then begin
    Project1.Modified := True;
    TIDEBreakPoint(Item).UserModified := False;
  end;
end;


{ TManagedBreakPoint }

procedure TManagedBreakPoint.SetSourceMark(const AValue: TSourceMark);
begin
  if FSourceMark=AValue then exit;
  if FSourceMark<>nil then begin
    FSourceMark.RemoveAllHandlersForObject(Self);
    FSourceMark.Data:=nil;
  end;
  FSourceMark:=AValue;
  if FSourceMark<>nil then begin
    FSourceMark.IncChangeLock;
    FSourceMark.AddPositionChangedHandler(@OnSourceMarkPositionChanged);
    FSourceMark.AddBeforeFreeHandler(@OnSourceMarkBeforeFree);
    FSourceMark.Data:=Self;
    FSourceMark.IsBreakPoint:=true;
    FSourceMark.Line:=Line;
    FSourceMark.Visible:=true;
    FSourceMark.AddGetHintHandler(@OnSourceMarkGetHint);
    FSourceMark.AddCreatePopupMenuHandler(@OnSourceMarkCreatePopupMenu);
    UpdateSourceMark;
    FSourceMark.DecChangeLock;
  end;
end;

procedure TManagedBreakPoint.OnSourceMarkPositionChanged(Sender: TObject);
begin
  CopySourcePositionToBreakPoint;
end;

procedure TManagedBreakPoint.OnToggleEnableMenuItemClick(Sender: TObject);
begin
  Enabled:=not Enabled;
end;

procedure TManagedBreakPoint.OnDeleteMenuItemClick(Sender: TObject);
begin
  ReleaseReference;
end;

procedure TManagedBreakPoint.OnViewPropertiesMenuItemClick(Sender: TObject);
begin
  DebugBoss.ShowBreakPointProperties(Self);
end;

procedure TManagedBreakPoint.OnSourceMarkBeforeFree(Sender: TObject);
begin
  SourceMark:=nil;
end;

procedure TManagedBreakPoint.OnSourceMarkGetHint(SenderMark: TSourceMark;
  var Hint: string);
begin
  Hint := GetBreakPointStateDescription(Self) + LineEnding +
      Format('%s: %d' + LineEnding + '%s %s' + LineEnding + '%s: %s',
        [lisHitCount, Hitcount,
        lisAction, GetBreakPointActionsDescription(Self),
        lisCondition, Expression]);
  if SenderMark<>nil then ;
end;

procedure TManagedBreakPoint.OnSourceMarkCreatePopupMenu(
  SenderMark: TSourceMark; const AddMenuItem: TAddMenuItemProc);
begin
  if Enabled then
    AddMenuItem(lisDisableBreakPoint, True, @OnToggleEnableMenuItemClick)
  else
    AddMenuItem(lisEnableBreakPoint, True, @OnToggleEnableMenuItemClick);
  AddMenuItem(lisDeleteBreakPoint, True, @OnDeleteMenuItemClick);
  AddMenuItem(lisViewBreakPointProperties, True, @OnViewPropertiesMenuItemClick);
  if SenderMark<>nil then ;
end;

procedure TManagedBreakPoint.DoChanged;
begin
  inherited DoChanged;
  UpdateSourceMark;
end;

procedure TManagedBreakPoint.CopySourcePositionToBreakPoint;
begin
  if FSourceMark=nil then exit;
  SetLocation(Source,FSourceMark.Line);
end;

procedure TManagedBreakPoint.SetLocation(const ASource: String;
  const ALine: Integer);
var
  NewDebugExeLine: Integer;
begin
  NewDebugExeLine := DebugExeLine;
  if (Source = ASource) and (Line = ALine) and (FCurrentDebugExeLine = NewDebugExeLine)
  then exit;
  inherited SetLocation(ASource, ALine);
  FCurrentDebugExeLine := NewDebugExeLine;
  if Project1 <> nil
  then Project1.Modified := True;
end;

procedure TManagedBreakPoint.UpdateSourceMarkImage;
var
  Img: Integer;
begin
  if SourceMark = nil then Exit;
  case Valid of
    vsValid:
      if Enabled then
        Img := SourceEditorMarks.ActiveBreakPointImg
      else
        Img := SourceEditorMarks.InactiveBreakPointImg;
    vsInvalid:
      if Enabled then
        Img := SourceEditorMarks.InvalidBreakPointImg
      else
        Img := SourceEditorMarks.InvalidDisabledBreakPointImg;
    vsPending:
      if Enabled then
        Img := SourceEditorMarks.PendingBreakPointImg
      else
        Img := SourceEditorMarks.InactiveBreakPointImg;
    else
      if Enabled then
        Img := SourceEditorMarks.UnknownBreakPointImg
      else
        Img := SourceEditorMarks.UnknownDisabledBreakPointImg;
  end;
  SourceMark.ImageIndex := Img;
end;

procedure TManagedBreakPoint.UpdateSourceMarkLineColor;
var
  aha: TAdditionalHilightAttribute;
begin
  if SourceMark = nil then Exit;
  aha := ahaNone;
  case Valid of
    vsValid:
      if Enabled then
        aha := ahaEnabledBreakpoint
      else
        aha := ahaDisabledBreakpoint;
    vsInvalid:
    if Enabled then
        aha := ahaInvalidBreakpoint
      else
        aha := ahaDisabledBreakpoint;
    else
      if Enabled then
        aha := ahaUnknownBreakpoint
      else
        aha := ahaDisabledBreakpoint;
  end;
  SourceMark.LineColorAttrib := aha;
end;

function TManagedBreakPoint.DebugExeLine: Integer;
var
  se: TSourceEditor;
begin
  Result := Line;
  if (FSourceMark <> nil) and (FSourceMark.SourceEditor <> nil) then
    Result := TSourceEditor(FSourceMark.SourceEditor).SourceToDebugLine(Line)
  else begin
    se := SourceEditorManager.SourceEditorIntfWithFilename(Source);
    if se <> nil
    then Result := se.SourceToDebugLine(Line);
  end;
end;

procedure TManagedBreakPoint.UpdateSourceMark;
begin
  if SourceMark = nil then Exit;
  SourceMark.IncChangeLock;
  SourceMark.Line := Line;
  UpdateSourceMarkImage;
  UpdateSourceMarkLineColor;
  SourceMark.DecChangeLock;
end;


// Helper function for TDebugManager.GetFullFilename.
function FindFullFilenameSrc(const AUnitinfo: TDebuggerUnitInfo): boolean;
var
  SrcUnitName: String;
  SrcInFilename: String;
  SrcFilename: String;
  Code: TCodeBuffer;
  ProcDef: String;
  CurCodeTool: TCodeTool;
  CurCodeNode: TCodeTreeNode;
  CodePos: TCodeXYPosition;
begin
  Result:=false;
  // search unit in project unit path
  SrcUnitName := AUnitinfo.UnitName;
  SrcInFilename := '';
  with CodeToolBoss.DirectoryCachePool do
    SrcFilename := FindUnitSourceInCompletePath('', SrcUnitName, SrcInFilename);
  if SrcFilename='' then exit;
  // load unit
  Code := CodeToolBoss.LoadFile(SrcFilename,true,false);
  if Code=nil then exit; // read error
  // procedure declaration: classname.functionname
  ProcDef := '';
  if AUnitinfo.SrcClassName<>'' then
    ProcDef := AUnitinfo.SrcClassName+'.';
  ProcDef := ProcDef+AUnitinfo.FunctionName;
  // search proc in unit
  if not CodeToolBoss.FindProcDeclaration(Code,ProcDef,CurCodeTool,CurCodeNode,
    [phpWithoutParamList,phpWithoutBrackets,phpWithoutClassKeyword,phpWithoutSemicolon])
  then
    exit;
  // get file, line, column
  if CurCodeNode.Desc=ctnProcedure then
    CurCodeNode := CurCodeNode.FirstChild; // jump to Name instead of keyword 'procedure'
  if not CurCodeTool.CleanPosToCaret(CurCodeNode.StartPos,CodePos) then
    exit;
  AUnitinfo.LocationFullFile := CodePos.Code.Filename;
  AUnitinfo.SrcLine := CodePos.Y;
  //DumpStack;
  Result:=true;
end;

function TDebugManager.GetFullFilename(const AUnitinfo: TDebuggerUnitInfo;
  out Filename: string; AskUserIfNotFound: Boolean): Boolean;

  function ResolveFromDbg: Boolean;
  begin
    Filename := AUnitinfo.FileName;
    Result := (Filename<>'') and GetFullFilename(Filename, False) and FileExistsUTF8(Filename);
    if Result then Exit;
    Filename := AUnitinfo.DbgFullName;
    if Filename='' then
      Exit(False);
    Result := FileExistsUTF8(Filename);
    if not Result then
      Result := GetFullFilename(Filename, AskUserIfNotFound);
  end;

begin
  Result := False;
  if Destroying or (AUnitinfo = nil) then exit;
  Filename := AUnitinfo.LocationFullFile;
  Result := Filename <> '';

  if (dlfSearchByFunctionName in AUnitinfo.Flags) and (AUnitinfo.FunctionName<>'')
  and FindFullFilenameSrc(AUnitinfo) then
    exit;

  case AUnitinfo.LocationType of
    dltUnknown:      Result := ResolveFromDbg;
    dltUnresolvable: Result := False;
    dltProject:
      begin
        Filename := TrimFilename(AUnitinfo.LocationName);
        Filename := MainIDE.FindSourceFile(Filename, Project1.Directory,
                      [fsfSearchForProject, fsfUseIncludePaths, fsfUseDebugPath,
                       {fsfMapTempToVirtualFiles,} fsfSkipPackages]);
        Result := Filename <> '';
        if not Result then
          Result := ResolveFromDbg;
      end;
    dltPackage: Result := ResolveFromDbg;
  end;

  if Result then
    AUnitinfo.LocationFullFile := Filename
  else begin
    Filename := AUnitinfo.FileName;
    if AskUserIfNotFound then
      AUnitinfo.LocationType := dltUnresolvable;
  end;
end;

function TDebugManager.GetFullFilename(var Filename: string; AskUserIfNotFound: Boolean): Boolean;
var
  SrcFile, SrcFN, UserFilename: String;
  n: Integer;
  OpenDialog: TIDEOpenDialog;
  AnUnitInfo: TLazProjectFile;
begin
  Result := False;
  if Destroying or (Filename = '') then exit;
  (* The below currently does not work for unsaved projects *)
  //Result := FilenameIsAbsolute(Filename);
  //if Result then exit;

  // TODO, check for virtual file, and flag it
  // Project1.IsVirtual
  // Left(Filename,1, xxx) = LazarusIDE.GetTestBuildDirectory

  // some debuggers (e.g. gdb) sometimes returns linux path delims under windows
  // => fix that
  Filename := TrimFilename(Filename);
  SrcFile := MainIDE.FindSourceFile(Filename, Project1.Directory,
                      [fsfSearchForProject, fsfUseIncludePaths, fsfUseDebugPath{,
                       fsfMapTempToVirtualFiles}]);
  if (SrcFile <> '') and (not FilenameIsAbsolute(SrcFile)) and
     (Project1.IsVirtual) and
     FileExistsUTF8(AppendPathDelim(LazarusIDE.GetTestBuildDirectory)+SrcFile)
  then
    SrcFile := AppendPathDelim(LazarusIDE.GetTestBuildDirectory)+SrcFile;

  if SrcFile = '' then
    SrcFile := Filename;
  SrcFN := ExtractFilenameOnly(SrcFile);
  if not FilenameIsAbsolute(SrcFile) then
  begin
    // first attempt to get a longer name
    // short file, look in the user list
    for n := 0 to FUserSourceFiles.Count - 1 do
    begin
      UserFilename := FUserSourceFiles[n];
      if (CompareFileNames(SrcFN, ExtractFilenameOnly(UserFilename)) = 0)
      and FileExistsUTF8(UserFilename) then
      begin
        FUserSourceFiles.Move(n, 0); // move most recent first
        SrcFile := UserFilename;
        Break;
      end;
    end;
  end;

  if not FilenameIsAbsolute(SrcFile) then
  begin
    AnUnitInfo := Project1.FindFile(SrcFile, [pfsfOnlyEditorFiles]);
    if AnUnitInfo <> nil then
    begin
      // the file is an unsaved file -> can not be extended
      Result := True;
      Filename := SrcFile;
      Exit;
    end;
  end;

  if ((not FilenameIsAbsolute(SrcFile)) or (not FileExistsUTF8(SrcFile)))
  and AskUserIfNotFound then
  begin

    if IDEMessageDialog(lisFileNotFound,
      Format(lisTheFileWasNotFoundDoYouWantToLocateItYourself, [SrcFile, LineEnding]),
      mtConfirmation, [mbYes, mbNo]) <> mrYes
    then Exit;

    repeat
      OpenDialog:=IDEOpenDialogClass.Create(nil);
      try
        InputHistories.ApplyFileDialogSettings(OpenDialog);
        OpenDialog.Title:=lisOpenFile+' '+SrcFile;
        OpenDialog.Options:=OpenDialog.Options+[ofFileMustExist];
        OpenDialog.FileName := SrcFile;
        if not OpenDialog.Execute then
          exit;
        SrcFile:=CleanAndExpandFilename(OpenDialog.FileName);
        InputHistories.StoreFileDialogSettings(OpenDialog);
      finally
        OpenDialog.Free;
      end;
    until FilenameIsAbsolute(SrcFile) and FileExistsUTF8(SrcFile);

    FUserSourceFiles.Insert(0, SrcFile);
  end;

  if (SrcFile<>'')
  and ( (not FilenameIsAbsolute(SrcFile)) or FileExistsUTF8(SrcFile) )
  then begin
    Filename:=SrcFile;
    Result:=True;
  end;
end;

procedure TDebugManager.DebuggerConsoleOutput(Sender: TObject;
  const AText: String);
begin
  if not HasConsoleSupport then exit;;
  if FDialogs[ddtPseudoTerminal] = nil
  then ViewDebugDialog(ddtPseudoTerminal, False, False);
  TPseudoConsoleDlg(FDialogs[ddtPseudoTerminal]).AddOutput(AText);
end;

function TDebugManager.DebuggerFeedback(Sender: TObject; const AText, AInfo: String;
  AType: TDBGFeedbackType; AButtons: TDBGFeedbackResults): TDBGFeedbackResult;
begin
  Result := ExecuteFeedbackDialog(AText, AInfo, AType, AButtons);
end;

procedure TDebugManager.DebuggerIdle(Sender: TObject);
begin
  FSnapshots.DoDebuggerIdle;
end;

function TDebugManager.DoProjectClose(Sender: TObject; AProject: TLazProject): TModalResult;
begin
  if AProject<>Project1 then exit(mrCancel);
  ResetDebugger;
  Result := mrOK;
end;

procedure TDebugManager.DoProjectModified(Sender: TObject);
begin
  if Project1 <> nil then
    Project1.Modified := True;
end;

procedure TDebugManager.mnuAddBpAddress(Sender: TObject);
var
  NewBreakpoint: TIDEBreakPoint;
begin
  NewBreakpoint := BreakPoints.Add(0, True);
  if ShowBreakPointProperties(NewBreakpoint) <> mrOk then
    ReleaseRefAndNil(NewBreakpoint)
  else
    NewBreakpoint.EndUpdate;
end;

procedure TDebugManager.mnuAddBpSource(Sender: TObject);
var
  NewBreakpoint: TIDEBreakPoint;
  SrcEdit: TSourceEditor;
begin
  SrcEdit := SourceEditorManager.GetActiveSE;
  if SrcEdit <> nil then
    NewBreakpoint := BreakPoints.Add(SrcEdit.FileName, SrcEdit.CurrentCursorYLine, True)
  else
    NewBreakpoint := BreakPoints.Add('', 0, True);
  if DebugBoss.ShowBreakPointProperties(NewBreakpoint) <> mrOk then
    ReleaseRefAndNil(NewBreakpoint)
  else
    NewBreakpoint.EndUpdate;
end;

procedure TDebugManager.mnuAddBpData(Sender: TObject);
var
  NewBreakpoint: TIDEBreakPoint;
begin
  NewBreakpoint := BreakPoints.Add('', wpsGlobal, wpkWrite, True);
  if ShowBreakPointProperties(NewBreakpoint) = mrOk then begin
    NewBreakpoint.EndUpdate;
    ViewDebugDialog(ddtBreakpoints, False);
  end
  else
    ReleaseRefAndNil(NewBreakpoint);
end;

procedure TDebugManager.mnuAddBpDataAtCursor(Sender: TObject);
var
  SE: TSourceEditor;
  WatchVar: String;
  NewBreakpoint: TIDEBreakPoint;
begin
  SE := SourceEditorManager.GetActiveSE;

  if Assigned(SE) then
  begin
    if SE.SelectionAvailable then
      WatchVar := SE.Selection
    else
      WatchVar := SE.GetOperandAtCurrentCaret;

    if (WatchVar <> '') and SE.EditorComponent.Focused then
    begin
      // TODO: find existing?
      NewBreakpoint := BreakPoints.Add(WatchVar, wpsGlobal, wpkWrite, True);
      if ShowBreakPointProperties(NewBreakpoint) = mrOk then begin
        NewBreakpoint.EndUpdate;
        ViewDebugDialog(ddtBreakpoints, False);
      end
      else
        NewBreakpoint.ReleaseReference;
      exit;
    end;
  end;

  // watch was not added automatically => show a dialog
  mnuAddBpData(nil);
end;

procedure TDebugManager.BreakAutoContinueTimer(Sender: TObject);
begin
  FAutoContinueTimer.Enabled := False;
  FDebugger.Run;
end;

procedure TDebugManager.OnRunTimer(Sender: TObject);
begin
  FRunTimer.Enabled:=false;
  if dmsWaitForRun in FManagerStates then
    RunDebugger
  else
  if dmsWaitForAttach in FManagerStates then
    AttachDebugger;
end;

procedure TDebugManager.DebuggerBreakPointHit(ADebugger: TDebuggerIntf;
  ABreakPoint: TBaseBreakPoint; var ACanContinue: Boolean);
begin
  FCurrentBreakPoint := nil;
  if FBreakPoints = nil then Exit;
  if ABreakpoint = nil then Exit;

  FCurrentBreakpoint := nil;
  if (ABreakPoint is TDBGBreakPoint) and (TDBGBreakPoint(ABreakPoint).Slave is TIDEBreakPoint) then
    FCurrentBreakpoint := TIDEBreakPoint(TDBGBreakPoint(ABreakPoint).Slave)
  else
    DebugLn('ERROR: Breakpoint does not have correct class, or IDE slave breakpoint');
  // TODO: remove / fallback to old behaviour
  if FCurrentBreakpoint = nil then
    FCurrentBreakPoint := FBreakPoints.Find(ABreakPoint.Source, ABreakPoint.Line);
end;

procedure TDebugManager.mnuViewDebugDialogClick(Sender: TObject);
var
  xCommand: Integer;
begin
  if (Sender is TIDESpecialCommand) and (TIDESpecialCommand(Sender).Command<>nil) then
    xCommand := TIDESpecialCommand(Sender).Command.Command
  else
  if Sender is TIDECommand then
    xCommand := TIDECommand(Sender).Command
  else
    xCommand := -1;

  case xCommand of
    ecToggleWatches     : ViewDebugDialog(ddtWatches);
    ecToggleBreakPoints : ViewDebugDialog(ddtBreakpoints);
    ecToggleDebuggerOut : ViewDebugDialog(ddtOutput);
    ecToggleLocals      : ViewDebugDialog(ddtLocals);
    ecToggleCallStack   : ViewDebugDialog(ddtCallStack);
    ecToggleRegisters   : ViewDebugDialog(ddtRegisters);
    ecToggleAssembler   : ViewDebugDialog(ddtAssembler);
    ecToggleDebugEvents : ViewDebugDialog(ddtEvents);
    ecEvaluate          : ViewDebugDialog(ddtEvaluate);
    ecInspect           : ViewDebugDialog(ddtInspect);
    ecViewPseudoTerminal: ViewDebugDialog(ddtPseudoTerminal);
    ecViewThreads       : ViewDebugDialog(ddtThreads);
    ecViewHistory       : ViewDebugDialog(ddtHistory);
  else
    raise Exception.CreateFmt('IDE Internal error: TDebugManager.mnuViewDebugDialogClick, wrong command parameter %d.', [xCommand]);
  end;
end;

procedure TDebugManager.mnuResetDebuggerClicked(Sender: TObject);
begin
  ResetDebugger;
end;

procedure TDebugManager.mnuAddWatchClicked(Sender: TObject);
var
  SE: TSourceEditor;
  WatchVar: String;
  w: TCurrentWatch;
begin
  SE := SourceEditorManager.GetActiveSE;

  if Assigned(SE) then
  begin
    if SE.SelectionAvailable then
      WatchVar := SE.Selection
    else
      WatchVar := SE.GetOperandAtCurrentCaret;
    if (WatchVar <> '') and (SE.SourceNotebook.Active or SE.EditorComponent.Focused) then
    begin
      Watches.CurrentWatches.BeginUpdate;
      try
        w := Watches.CurrentWatches.Find(WatchVar);
        if w = nil
        then w := Watches.CurrentWatches.Add(WatchVar);
        if (w <> nil)
        then begin
          w.Enabled := True;
          if EnvironmentOptions.DebuggerAutoSetInstanceFromClass then
            w.EvaluateFlags := w.EvaluateFlags + [defClassAutoCast];
          ViewDebugDialog(ddtWatches, False);
          Exit;
        end;
      finally
        Watches.CurrentWatches.EndUpdate;
      end;
    end;
  end;

  // watch was not added automatically => show a dialog
  if ShowWatchProperties(nil, '') = mrOK then
    ViewDebugDialog(ddtWatches, False);
end;

//-----------------------------------------------------------------------------
// Debugger events
//-----------------------------------------------------------------------------

procedure TDebugManager.DebuggerException(Sender: TObject;
  const AExceptionType: TDBGExceptionType;
  const AExceptionClass: String;
  const AExceptionLocation: TDBGLocationRec;
  const AExceptionText: String;
  out AContinue: Boolean);

  function GetTitle: String;
  begin
    Result := Project1.GetTitle;
    if Result = '' then
      Result := ExtractFileName(FDebugger.FileName);
  end;

const
  MAX_CLASSNAME_LEN = 256; // shortstring
  MAX_MSG_DISPLAY_LEN = 2048; // just sanity
var
  ExpClassName, ExceptMsg: string;
  msg, SrcText: String;
  Ignore: Boolean;
  Editor: TSourceEditor;
  i: Integer;
begin
  if Destroying then
  begin
    AContinue := True;
    Exit;
  end
  else
    AContinue := False;

  ExpClassName := AExceptionClass;
  if Length(ExpClassName) > MAX_CLASSNAME_LEN then
    ExpClassName := copy(ExpClassName, 1, MAX_CLASSNAME_LEN) + '...';

  if AExceptionText = ''
  then
    msg := Format(lisProjectSRaisedExceptionClassS,
                  [GetTitle, ExpClassName])
  else begin
    ExceptMsg := AExceptionText;
    if Length(ExceptMsg) > MAX_MSG_DISPLAY_LEN then
      ExceptMsg := copy(ExceptMsg, 1, MAX_MSG_DISPLAY_LEN) + '...';
    // if AExceptionText is not a valid UTF8 string,
    // then assume it has the ansi encoding and convert it
    if FindInvalidUTF8Codepoint(pchar(ExceptMsg),length(ExceptMsg)) > 0 then
      ExceptMsg := AnsiToUtf8(ExceptMsg);
    msg := Format(lisProjectSRaisedExceptionClassSWithMessageSS,
                  [GetTitle, ExpClassName, LineEnding, ExceptMsg]);
  end;

  if AExceptionLocation.SrcFile <> '' then begin
    if AExceptionLocation.SrcLine <> 0 then begin
      SrcText := '';
      if (AExceptionLocation.SrcFullName <> '') then begin
        Editor := SourceEditorManager.SourceEditorIntfWithFilename(AExceptionLocation.SrcFullName);
        if Editor <> nil then begin
          try
            i := Editor.DebugToSourceLine(AExceptionLocation.SrcLine);
            if i > 0
            then SrcText := Trim(Editor.Lines[i-1]);
          except
          end;
    	end;
      end;
      if SrcText <> '' then
        msg := msg + Format(lisProjectSRaisedExceptionInFileLineSrc,
                      [LineEnding, AExceptionLocation.SrcFile, AExceptionLocation.SrcLine, SrcText])
      else
        msg := msg + Format(lisProjectSRaisedExceptionInFileLine,
                      [LineEnding, AExceptionLocation.SrcFile, AExceptionLocation.SrcLine]);
    end
    else
      msg := msg + Format(lisProjectSRaisedExceptionInFileAddress,
                    [LineEnding, AExceptionLocation.SrcFile, AExceptionLocation.Address]);
  end
  else if AExceptionLocation.Address <> 0 then begin
      msg := msg + Format(lisProjectSRaisedExceptionAtAddress,
                    [LineEnding, AExceptionLocation.Address]);
  end;

  if (AExceptionType in [deInternal, deRunError]) then begin
    AContinue := ExecuteExceptionDialog(msg, Ignore, AExceptionType in [deInternal, deRunError]) = mrCancel;
    if Ignore then begin
      Exceptions.AddIfNeeded(ExpClassName);
      Exceptions.Find(ExpClassName).Enabled := True;
    end;
  end
  else begin
    IDEMessageDialog(lisCCOErrorCaption, msg, mtError, [mbOk]);
  end;
end;

procedure TDebugManager.DebuggerOutput(Sender: TObject; const AText: String);
begin
  if Destroying then exit;
  if FDialogs[ddtOutput] <> nil then
    TDbgOutputForm(FDialogs[ddtOutput]).AddText(AText)
  else begin
    // store it internally, and copy it to the dialog, when the user opens it
    if fHiddenDebugOutputLog=nil then
      fHiddenDebugOutputLog:=TStringList.Create;
    fHiddenDebugOutputLog.Add(AText);
    while fHiddenDebugOutputLog.Count>100 do
      fHiddenDebugOutputLog.Delete(0);
  end;
end;

procedure TDebugManager.DebuggerBeforeChangeState(ADebugger: TDebuggerIntf;
  AOldState: TDBGState);
var
  DialogType: TDebugDialogType;
begin
  if Destroying or (MainIDE=nil) or (MainIDE.ToolStatus=itExiting)
  then exit;
  if AOldState=dsNone then ;
  assert((ADebugger=FDebugger) and (ADebugger<>nil), 'TDebugManager.OnDebuggerChangeState');

  FInStateChange := True;
  for DialogType := Low(TDebugDialogType) to High(TDebugDialogType) do
    if FDialogs[DialogType] <> nil then
      FDialogs[DialogType].BeginUpdate;

  if FDebugger.State = dsInternalPause then exit; // set debug windows to ignore / no updating
end;

procedure TDebugManager.DebuggerChangeState(ADebugger: TDebuggerIntf; OldState: TDBGState);

  procedure UnlockDialogs;
  var
    DialogType: TDebugDialogType;
  begin
    if not FInStateChange then exit;
    FInStateChange := False;
    for DialogType := Low(TDebugDialogType) to High(TDebugDialogType) do
      if FDialogs[DialogType] <> nil then
        FDialogs[DialogType].EndUpdate;
  end;

//const
  // dsNone, dsIdle, dsStop, dsPause, dsInit, dsRun, dsError
  //STATENAME: array[TDBGState] of string = (
  //  'dsNone', 'dsIdle', 'dsStop', 'dsPause', 'dsInit', 'dsRun', 'dsError'
  //);
var
  MsgResult: TModalResult;
  i: Integer;
begin
  if Destroying or (MainIDE=nil) or (MainIDE.ToolStatus=itExiting)
  then begin
    UnlockDialogs;
    exit;
  end;
  assert((ADebugger=FDebugger) and (ADebugger<>nil), 'TDebugManager.OnDebuggerChangeState');

  if (FDebugger.State in [dsRun])
  then FCurrentBreakpoint := nil;

  if not((OldState = dsInternalPause) and (State = dsPause)) then begin
    // OldState=dsInternalPause means we already have a snapshot
    // Notify FSnapshots of new state (while dialogs still in updating)
    // TODO: Maybe move to TIDEBreakPoint.DoHit
    if (FCurrentBreakpoint <> nil) and (bpaTakeSnapshot in FCurrentBreakpoint.Actions) and
       (State in [dsPause, dsInternalPause])
    then begin
      FSnapshots.DoStateChange(OldState);
      FSnapshots.Current.AddToSnapshots;
      FSnapshots.DoDebuggerIdle(True);
    end
    else
    if FDebugger.State <> dsInternalPause
    then FSnapshots.DoStateChange(OldState);
  end;

  UnlockDialogs;

  if FDebugger.State = dsInternalPause
  then exit;

  if FDebugger.State=dsError
  then begin
    Include(FManagerStates,dmsDebuggerObjectBroken);
    if dmsInitializingDebuggerObject in FManagerStates
    then Include(FManagerStates,dmsInitializingDebuggerObjectFailed);
  end;

  //DebugLn('[TDebugManager.OnDebuggerChangeState] state: ', STATENAME[FDebugger.State]);

  // All conmmands
  // -------------------
  // dcRun, dcPause, dcStop, dcStepOver, dcStepInto,  dcStepOverInstrcution, dcStepIntoInstrcution,
  // dcStepTo, dcJumpto, dcBreak, dcWatch
  // -------------------

  UpdateButtonsAndMenuItems;
  // Next may call ResetDebugger, then FDebugger is gone
  UpdateToolStatus;

  FAutoContinueTimer.Enabled := false;

  if FDebugger = nil then exit;

  if (FDebugger.State in [dsRun])
  then begin
    // hide IDE during run
    if EnvironmentOptions.Desktop.HideIDEOnRun and (MainIDE.ToolStatus=itDebugger) and not FStepping
    then MainIDE.HideIDE;

    if (FPrevShownWindow <> 0) and not FStepping then
    begin
      SetForegroundWindow(FPrevShownWindow);
      FPrevShownWindow := 0;
    end;
  end
  else
  if FDebugger.State <> dsInit then begin
    if (FCurrentBreakPoint <> nil) and (FCurrentBreakPoint.AutoContinueTime > 0) then
    begin
      FAutoContinueTimer.Enabled := True;
      FAutoContinueTimer.Interval := FCurrentBreakPoint.AutoContinueTime;
    end
    else if (OldState in [dsRun]) then
    begin
      if not FStepping then
      begin
        FPrevShownWindow := GetForegroundWindow;
        if EnvironmentOptions.Desktop.HideIDEOnRun then
          MainIDE.UnhideIDE;
        if not EnvironmentOptions.Desktop.SingleTaskBarButton and
          not EnvironmentOptions.Desktop.HideIDEOnRun then
            Application.BringToFront;
      end;
    end;
  end;

  // unmark execution line
  if (not (FDebugger.State in [dsInit, dsPause])) and (SourceEditorManager <> nil)
  then
    SourceEditorManager.ClearExecutionLines;

  if (FDebugger.State in [dsPause, dsInit]) and (SourceEditorManager <> nil)
  then
    SourceEditorManager.FillExecutionMarks;

  if not (FDebugger.State in [dsRun, dsPause, dsInit]) and (SourceEditorManager <> nil)
  then begin
    SourceEditorManager.ClearExecutionMarks;
    // Refresh DebugExeLine
    for i := 0 to FBreakPoints.Count - 1 do
      FBreakPoints[i].SetLocation(FBreakPoints[i].Source, FBreakPoints[i].Line);
  end;

  // update inspect
  // TODO: Move here from DebuggerCurrentLine / Only currently State change locks execution of gdb
  //if ( ((FDebugger.State in [dsPause]) and (OldState = dsRun)) or
  //     (OldState in [dsPause]) ) and
  if (OldState in [dsPause]) and (FDialogs[ddtInspect] <> nil)
  then TIDEInspectDlg(FDialogs[ddtInspect]).UpdateData;
  if (OldState in [dsPause]) and (FDialogs[ddtEvaluate] <> nil)
  then TEvaluateDlg(FDialogs[ddtEvaluate]).UpdateData;

  case FDebugger.State of
    dsError: begin
    {$ifdef VerboseDebugger}
      DebugLn('Ooops, the debugger entered the error state');
    {$endif}
      // shutting down lazarus may kill gdb, so we get an error
      if not Application.Terminated
      then FeedbackDlg.ExecuteFeedbackDialog
        (Format(lisDebuggerErrorOoopsTheDebuggerEnteredTheErrorState,
                [LineEnding+LineEnding, LineEnding, LineEnding+LineEnding])
         + LineEnding + LineEnding + FDebugger.ErrorStateMessage,
         FDebugger.ErrorStateInfo, ftError, [frStop]);
    end;
    dsStop: begin
      // TODO: TDebugger.SetFileName sets dsStop during startup (leading to  OldState=dsIdle)
      FPrevShownWindow:=0;
      if (OldState<>dsIdle)
      then begin
        MainIDE.DoCallRunFinishedHandler;
        if not FDebugger.SkipStopMessage then begin
          if (FDebugger.ExitCode <> 0) and EnvironmentOptions.DebuggerShowExitCodeMessage then begin
            i := 4;
            if FDebugger.ExitCode > 65535 then
            i := 8;
            {$PUSH}{$R-}
            MsgResult:=IDEQuestionDialog(lisExecutionStopped,
                Format(lisExecutionStoppedExitCode, [LineEnding+'', FDebugger.ExitCode, IntToHex(FDebugger.ExitCode, i)]),
                mtInformation, [mrOK, lisMenuOk,
                                mrYesToAll, lisDoNotShowThisMessageAgain], '');
            {$POP}
            if MsgResult=mrYesToAll then
              EnvironmentOptions.DebuggerShowExitCodeMessage:=false;
          end
          else
          if EnvironmentOptions.DebuggerShowStopMessage
          then begin
            MsgResult:=IDEQuestionDialog(lisExecutionStopped, lisExecutionStopped,
                mtInformation, [mrOK, lisMenuOk,
                                mrYesToAll, lisDoNotShowThisMessageAgain], '');
            if MsgResult=mrYesToAll then
              EnvironmentOptions.DebuggerShowStopMessage:=false;
          end;
        end;

        if EnvironmentOptions.DebuggerResetAfterRun or FDebugger.NeedReset then
          ResetDebugger
        else
          FDebugger.FileName := '';  // SetState(dsIdle) via ResetStateToIdle

        if FDialogs[ddtAssembler] <> nil
        then begin
          TAssemblerDlg(FDialogs[ddtAssembler]).SetLocation(nil, 0);
          if FAsmWindowShouldAutoClose then
            TAssemblerDlg(FDialogs[ddtAssembler]).Close;
        end;
      end;
    end;
    dsInit: begin
      if FDialogs[ddtPseudoTerminal] <> nil then
        TPseudoConsoleDlg(FDialogs[ddtPseudoTerminal]).Clear;
    end;
  end;
end;

procedure TDebugManager.DebuggerCurrentLine(Sender: TObject; const ALocation: TDBGLocationRec);
// debugger paused program due to pause or error
// -> show the current execution line in editor
// if SrcLine < 1 then no source is available

  function FileLocationToId(ALoc: TDBGLocationRec): string;
  begin
    Result := IntToStr(length(ALoc.SrcFile)) + ':' + ALoc.SrcFile + ':'
            + IntToStr(length(ALoc.SrcFullName)) + ':' + ALoc.SrcFullName;
  end;

var
  SrcFullName: String;
  NewSource: TCodeBuffer;
  Editor: TSourceEditor;
  SrcLine: Integer;
  c, i, TId: Integer;
  StackEntry: TIdeCallStackEntry;
  Flags: TJumpToCodePosFlags;
  CurrentSourceUnitInfo: TDebuggerUnitInfo;
  a: Boolean;
begin
  if (Sender<>FDebugger) or (Sender=nil) then exit;
  if FDebugger.State = dsInternalPause then exit;
  if Destroying then exit;

  FCurrentLocation := ALocation;
  SrcLine := ALocation.SrcLine;
  CurrentSourceUnitInfo := nil;

  if (SrcLine < 1) and (SrcLine <> -2) // TODO: this should move to the debugger
                                       // SrcLine will be -2 after stepping (gdbmi)
  then begin
    // jump to the deepest stack frame with debugging info
    // TODO: Only below the frame supplied by debugger
    i:=0;
    TId := Threads.CurrentThreads.CurrentThreadId;
    c := CallStack.CurrentCallStackList.EntriesForThreads[TId].CountLimited(30);
    while (i < c) do
    begin
      StackEntry := CallStack.CurrentCallStackList.EntriesForThreads[TId].Entries[i];
      if StackEntry.Validity = ddsRequested then // not yet available
        break;
      if StackEntry.Line > 0
      then begin
        CurrentSourceUnitInfo := StackEntry.UnitInfo;
        CurrentSourceUnitInfo.AddReference;
        SrcLine := StackEntry.Line;
        StackEntry.MakeCurrent;
        Break;
      end;
      Inc(i);
    end;
  end
  else begin
    CurrentSourceUnitInfo := FUnitInfoProvider.GetUnitInfoFor(ALocation.SrcFile, ALocation.SrcFullName);
    CurrentSourceUnitInfo.AddReference;
  end;

  // TODO: do in DebuggerChangeState / Only currently State change locks execution of gdb
  // Must be after stack frame selection (for inspect)
  if FDialogs[ddtAssembler] <> nil
  then TAssemblerDlg(FDialogs[ddtAssembler]).SetLocation(FDebugger, Alocation.Address);
  if (FDialogs[ddtInspect] <> nil)
  then TIDEInspectDlg(FDialogs[ddtInspect]).UpdateData;
  if (FDialogs[ddtEvaluate] <> nil)
  then TEvaluateDlg(FDialogs[ddtEvaluate]).UpdateData;

  if (SrcLine > 0) and (CurrentSourceUnitInfo <> nil) and
     GetFullFilename(CurrentSourceUnitInfo, SrcFullName, True)
  then begin
    // Load the file
    NewSource := CodeToolBoss.LoadFile(SrcFullName, true, false);
    if NewSource = nil
    then begin
      if not (dlfLoadError in CurrentSourceUnitInfo.Flags) then begin
        IDEMessageDialog(lisDebugUnableToLoadFile,
                   Format(lisDebugUnableToLoadFile2, [SrcFullName]),
                   mtError,[mbCancel]);
        CurrentSourceUnitInfo.Flags := CurrentSourceUnitInfo.Flags + [dlfLoadError];
      end;
      SrcLine := -1;
    end;
  end
  else begin
    NewSource := Nil;
    SrcLine := -1;
  end;

  ReleaseRefAndNil(CurrentSourceUnitInfo);

  // clear old error and execution lines
  if SourceEditorManager <> nil
  then begin
    SourceEditorManager.ClearExecutionLines;
    SourceEditorManager.ClearErrorLines;
  end;

  if SrcLine < 1
  then begin
    a := FAsmWindowShouldAutoClose or (FDialogs[ddtAssembler] = nil) or (not FDialogs[ddtAssembler].Visible);
    ViewDebugDialog(ddtAssembler);
    FAsmWindowShouldAutoClose := a and EnvironmentOptions.DebuggerAutoCloseAsm;
    exit;
  end;
  if (FDialogs[ddtAssembler] <> nil) and FAsmWindowShouldAutoClose then
    TAssemblerDlg(FDialogs[ddtAssembler]).Close;

  Editor := nil;
  if SourceEditorManager <> nil
  then Editor := SourceEditorManager.SourceEditorIntfWithFilename(NewSource.Filename);

  // jump editor to execution line
  Flags := [jfAddJumpPoint, jfSearchVirtualFullPath];
  if (FCurrentBreakPoint = nil) or (FCurrentBreakPoint.AutoContinueTime = 0)
  then include(Flags, jfFocusEditor);
  i := SrcLine;
  if (Editor <> nil) then
    i := Editor.DebugToSourceLine(i);
  if MainIDE.DoJumpToCodePosition(nil,nil,NewSource,1,i,-1,-1,-1,Flags)<>mrOk
  then exit;

  // mark execution line
  if (Editor = nil) and (SourceEditorManager <> nil) then
    Editor := SourceEditorManager.ActiveEditor;
  if Editor <> nil
  then begin
    if not Editor.HasExecutionMarks then
      Editor.FillExecutionMarks;
    Editor.ExecutionLine := i;
  end;
end;

//-----------------------------------------------------------------------------
// Debugger dialog routines
//-----------------------------------------------------------------------------

// Common handler
// The tag of the destroyed form contains the form variable pointing to it
procedure TDebugManager.DebugDialogDestroy(Sender: TObject);
var
  DlgType: TDebugDialogType;
begin
  for DlgType:=Low(TDebugDialogType) to High(TDebugDialogType) do begin
    if FDialogs[DlgType]<>Sender then continue;
    case DlgType of
    ddtOutput:
      begin
        if fHiddenDebugOutputLog=nil then
          fHiddenDebugOutputLog:=TStringList.Create;
        TDbgOutputForm(FDialogs[ddtOutput]).GetLogText(fHiddenDebugOutputLog);
      end;
    ddtEvents:
      begin
        FEventLogManager.EventDialog := nil;
      end;
    end;
    FDialogs[DlgType]:=nil;
    exit;
  end;
  RaiseGDBException('Invalid debug window '+Sender.ClassName);
end;

procedure TDebugManager.ViewDebugDialog(const ADialogType: TDebugDialogType;
  BringToFront: Boolean; Show: Boolean; DoDisableAutoSizing: boolean);
const
  DEBUGDIALOGCLASS: array[TDebugDialogType] of TDebuggerDlgClass = (
    TDbgOutputForm, TDbgEventsForm, TBreakPointsDlg, TWatchesDlg, TLocalsDlg,
    TCallStackDlg, TEvaluateDlg, TRegistersDlg, TAssemblerDlg, TIDEInspectDlg,
    TPseudoConsoleDlg, TThreadsDlg, THistoryDialog
  );
var
  CurDialog: TDebuggerDlg;
begin
  if Destroying then exit;
  if (ADialogType = ddtPseudoTerminal) and not HasConsoleSupport
  then exit;
  if ADialogType = ddtAssembler then
    FAsmWindowShouldAutoClose := False;
  if FDialogs[ADialogType] = nil
  then begin
    CurDialog := TDebuggerDlg(DEBUGDIALOGCLASS[ADialogType].NewInstance);
    if FInStateChange then CurDialog.BeginUpdate;
    CurDialog.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDebugManager.ViewDebugDialog'){$ENDIF};
    CurDialog.Create(Self);
    FDialogs[ADialogType]:=CurDialog;
    CurDialog.Name:= DebugDialogNames[ADialogType];
    CurDialog.Tag := Integer(ADialogType);
    CurDialog.OnDestroy := @DebugDialogDestroy;
    case ADialogType of
      ddtOutput:      InitDebugOutputDlg;
      ddtEvents:      InitDebugEventsDlg;
      ddtBreakpoints: InitBreakPointDlg;
      ddtWatches:     InitWatchesDlg;
      ddtLocals:      InitLocalsDlg;
      ddtRegisters:   InitRegistersDlg;
      ddtCallStack:   InitCallStackDlg;
      ddtEvaluate:    InitEvaluateDlg;
      ddtAssembler:   InitAssemblerDlg;
      ddtInspect:     InitInspectDlg;
      ddtPseudoTerminal: InitPseudoTerminal;
      ddtThreads:     InitThreadsDlg;
      ddtHistory:     InitHistoryDlg;
    end;
  end
  else begin
    CurDialog:=FDialogs[ADialogType];
    CurDialog.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDebugManager.ViewDebugDialog'){$ENDIF};
    if (CurDialog is TBreakPointsDlg)
    then begin
      if (Project1<>nil) then
        TBreakPointsDlg(CurDialog).BaseDirectory:=Project1.Directory;
    end;
    if (CurDialog is TAssemblerDlg)
    then begin
      TAssemblerDlg(CurDialog).SetLocation(FDebugger, FCurrentLocation.Address);
    end;
    if (CurDialog is TIDEInspectDlg) and (SourceEditorManager.GetActiveSE <> nil)
    then begin
      if SourceEditorManager.GetActiveSE.SelectionAvailable then
        TIDEInspectDlg(CurDialog).Execute(SourceEditorManager.GetActiveSE.Selection)
      else
        TIDEInspectDlg(CurDialog).Execute(SourceEditorManager.GetActiveSE.GetOperandAtCurrentCaret);
    end;
    if (CurDialog is TEvaluateDlg) and (SourceEditorManager.GetActiveSE <> nil)
    then begin
      if SourceEditorManager.GetActiveSE.SelectionAvailable then
        TEvaluateDlg(CurDialog).Execute(SourceEditorManager.GetActiveSE.Selection)
      else
        TEvaluateDlg(CurDialog).Execute(SourceEditorManager.GetActiveSE.GetOperandAtCurrentCaret);
    end;
  end;
  if not DoDisableAutoSizing then
    CurDialog.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TDebugManager.ViewDebugDialog'){$ENDIF};
  if Show then
  begin
    CurDialog.BeginUpdate;
    IDEWindowCreators.ShowForm(CurDialog,BringToFront,vmOnlyMoveOffScreenToVisible);
    CurDialog.EndUpdate;
  end;
end;

procedure TDebugManager.ViewDisassembler(AnAddr: TDBGPtr; BringToFront: Boolean;
  Show: Boolean; DoDisableAutoSizing: boolean);
begin
  ViewDebugDialog(ddtAssembler, BringToFront, Show, DoDisableAutoSizing);
  if FDialogs[ddtAssembler] <> nil
  then TAssemblerDlg(FDialogs[ddtAssembler]).SetLocation(FDebugger, FCurrentLocation.Address, AnAddr);
end;

procedure TDebugManager.DestroyDebugDialog(const ADialogType: TDebugDialogType);
begin
  if FDialogs[ADialogType] = nil then Exit;
  FDialogs[ADialogType].OnDestroy := nil;
  FDialogs[ADialogType].Free;
  FDialogs[ADialogType] := nil;
end;

procedure TDebugManager.InitDebugOutputDlg;
var
  TheDialog: TDbgOutputForm;
begin
  TheDialog := TDbgOutputForm(FDialogs[ddtOutput]);
  if FHiddenDebugOutputLog <> nil
  then begin
    TheDialog.SetLogText(FHiddenDebugOutputLog);
    FreeAndNil(FHiddenDebugOutputLog);
  end;
end;

procedure TDebugManager.InitDebugEventsDlg;
var
  TheDialog: TDbgEventsForm;
begin
  TheDialog := TDbgEventsForm(FDialogs[ddtEvents]);
  FEventLogManager.EventDialog := TheDialog;
end;

procedure TDebugManager.InitBreakPointDlg;
var
  TheDialog: TBreakPointsDlg;
begin
  TheDialog:=TBreakPointsDlg(FDialogs[ddtBreakpoints]);
  if Project1 <> nil
  then TheDialog.BaseDirectory := Project1.Directory;
  TheDialog.BreakPoints := FBreakPoints;
end;

procedure TDebugManager.InitWatchesDlg;
var
  TheDialog: TWatchesDlg;
begin
  TheDialog := TWatchesDlg(FDialogs[ddtWatches]);
  TheDialog.WatchesMonitor := FWatches;
  TheDialog.ThreadsMonitor := FThreads;
  TheDialog.CallStackMonitor := FCallStack;
  TheDialog.BreakPoints := FBreakPoints;
  TheDialog.SnapshotManager := FSnapshots;
end;

procedure TDebugManager.InitThreadsDlg;
var
  TheDialog: TThreadsDlg;
begin
  TheDialog := TThreadsDlg(FDialogs[ddtThreads]);
  TheDialog.ThreadsMonitor := FThreads;
  TheDialog.SnapshotManager := FSnapshots;
end;

procedure TDebugManager.InitPseudoTerminal;
//var
//  TheDialog: TPseudoConsoleDlg;
begin
  if not HasConsoleSupport then exit;
  //TheDialog := TPseudoConsoleDlg(FDialogs[ddtPseudoTerminal]);
end;

procedure TDebugManager.InitLocalsDlg;
var
  TheDialog: TLocalsDlg;
begin
  TheDialog := TLocalsDlg(FDialogs[ddtLocals]);
  TheDialog.LocalsMonitor := FLocals;
  TheDialog.ThreadsMonitor := FThreads;
  TheDialog.CallStackMonitor := FCallStack;
  TheDialog.SnapshotManager := FSnapshots;
end;

procedure TDebugManager.InitRegistersDlg;
var
  TheDialog: TRegistersDlg;
begin
  TheDialog := TRegistersDlg(FDialogs[ddtRegisters]);
  TheDialog.ThreadsMonitor := FThreads;
  TheDialog.CallStackMonitor := FCallStack;
  TheDialog.RegistersMonitor := FRegisters;
end;

procedure TDebugManager.InitAssemblerDlg;
var
  TheDialog: TAssemblerDlg;
begin
  TheDialog := TAssemblerDlg(FDialogs[ddtAssembler]);
  TheDialog.BreakPoints := FBreakPoints;
  TheDialog.Disassembler := FDisassembler;
  TheDialog.DebugManager := Self;
  TheDialog.SetLocation(FDebugger, FCurrentLocation.Address);
end;

procedure TDebugManager.InitInspectDlg;
var
  TheDialog: TIDEInspectDlg;
begin
  TheDialog := TIDEInspectDlg(FDialogs[ddtInspect]);
  if (SourceEditorManager.GetActiveSE = nil) then
    exit;
  if SourceEditorManager.GetActiveSE.SelectionAvailable then
    TheDialog.Execute(SourceEditorManager.GetActiveSE.Selection)
  else
    TheDialog.Execute(SourceEditorManager.GetActiveSE.GetOperandAtCurrentCaret);
end;

procedure TDebugManager.InitHistoryDlg;
var
  TheDialog: THistoryDialog;
begin
  TheDialog := THistoryDialog(FDialogs[ddtHistory]);
  TheDialog.SnapshotManager := FSnapshots;
end;

procedure TDebugManager.InitCallStackDlg;
var
  TheDialog: TCallStackDlg;
begin
  TheDialog := TCallStackDlg(FDialogs[ddtCallStack]);
  TheDialog.CallStackMonitor := FCallStack;
  TheDialog.BreakPoints := FBreakPoints;
  TheDialog.ThreadsMonitor := FThreads;
  TheDialog.SnapshotManager := FSnapshots;
end;

procedure TDebugManager.InitEvaluateDlg;
var
  TheDialog: TEvaluateDlg;
begin
  TheDialog := TEvaluateDlg(FDialogs[ddtEvaluate]);
  if (SourceEditorManager.GetActiveSE = nil) then
    exit;
  if SourceEditorManager.GetActiveSE.SelectionAvailable
  then
    TheDialog.FindText := SourceEditorManager.GetActiveSE.Selection
  else
    TheDialog.FindText := SourceEditorManager.GetActiveSE.GetOperandAtCurrentCaret;
end;

constructor TDebugManager.Create(TheOwner: TComponent);
var
  DialogType: TDebugDialogType;
begin
  FInStateChange := False;
  for DialogType := Low(TDebugDialogType) to High(TDebugDialogType) do
    FDialogs[DialogType] := nil;

  FDebugger := nil;
  FUnitInfoProvider := TDebuggerUnitInfoProvider.Create;
  FBreakPoints := TManagedBreakPoints.Create(Self);
  FBreakPointGroups := TIDEBreakPointGroups.Create;
  FWatches := TIdeWatchesMonitor.Create;
  FThreads := TIdeThreadsMonitor.Create;
  FExceptions := TProjectExceptions.Create;
  FSignals := TIDESignals.Create;
  FLocals := TIdeLocalsMonitor.Create;
  FLineInfo := TIDELineInfo.Create;
  FCallStack := TIdeCallStackMonitor.Create;
  FDisassembler := TIDEDisassembler.Create;
  FRegisters := TIdeRegistersMonitor.Create;

  FSnapshots := TSnapshotManager.Create;
  FSnapshots.Threads := FThreads;
  FSnapshots.CallStack := FCallStack;
  FSnapshots.Watches := FWatches;
  FSnapshots.Locals := FLocals;
  FSnapshots.UnitInfoProvider := FUnitInfoProvider;

  FUserSourceFiles := TStringList.Create;

  FAutoContinueTimer := TTimer.Create(Self);
  FAutoContinueTimer.Enabled := False;
  FAutoContinueTimer.OnTimer := @BreakAutoContinueTimer;
  FRunTimer := TTimer.Create(Self);
  FRunTimer.Interval := 1;
  FRunTimer.OnTimer := @OnRunTimer;

  FWatches.OnModified  := @DoProjectModified;

  FIsInitializingDebugger:= False;

  inherited Create(TheOwner);

  LazarusIDE.AddHandlerOnProjectClose(@DoProjectClose);

  RegisterValueFormatter(skSimple, 'TDate', @DBGDateTimeFormatter);
  RegisterValueFormatter(skFloat, 'TDate', @DBGDateTimeFormatter);
  RegisterValueFormatter(skSimple, 'TTime', @DBGDateTimeFormatter);
  RegisterValueFormatter(skFloat, 'TTime', @DBGDateTimeFormatter);
  RegisterValueFormatter(skSimple, 'TDateTime', @DBGDateTimeFormatter);
  RegisterValueFormatter(skFloat, 'TDateTime', @DBGDateTimeFormatter);

  FEventLogManager := TDebugEventLogManager.Create;
end;

destructor TDebugManager.Destroy;
var
  DialogType: TDebugDialogType;
begin
  FDestroying := true;

  LazarusIDE.RemoveHandlerOnProjectClose(@DoProjectClose);
  FreeAndNil(FAutoContinueTimer);

  for DialogType := Low(TDebugDialogType) to High(TDebugDialogType) do
    DestroyDebugDialog(DialogType);

  SetDebugger(nil);

  FreeAndNil(FEventLogManager);
  FreeAndNil(FSnapshots);
  FreeAndNil(FWatches);
  FreeAndNil(FThreads);
  FreeAndNil(FBreakPoints);
  FreeAndNil(FBreakPointGroups);
  FreeAndNil(FCallStack);
  FreeAndNil(FDisassembler);
  FreeAndNil(FExceptions);
  FreeAndNil(FSignals);
  FreeAndNil(FLocals);
  FreeAndNil(FLineInfo);
  FreeAndNil(FRegisters);

  FreeAndNil(FUserSourceFiles);
  FreeAndNil(FHiddenDebugOutputLog);
  FreeAndNil(FUnitInfoProvider);

  inherited Destroy;
end;

procedure TDebugManager.Reset;
begin
  FBreakPoints.Clear;
  FBreakPointGroups.Clear;
  FWatches.Clear;
  FThreads.Clear;
  FExceptions.Reset;
  FSignals.Reset;
  FUserSourceFiles.Clear;
  FUnitInfoProvider.Clear;
end;

procedure TDebugManager.ConnectMainBarEvents;
begin
  with MainIDEBar do begin
    itmViewWatches.OnClick := @mnuViewDebugDialogClick;
    itmViewWatches.Tag := Ord(ddtWatches);
    itmViewBreakPoints.OnClick := @mnuViewDebugDialogClick;
    itmViewBreakPoints.Tag := Ord(ddtBreakPoints);
    itmViewLocals.OnClick := @mnuViewDebugDialogClick;
    itmViewLocals.Tag := Ord(ddtLocals);
    itmViewRegisters.OnClick := @mnuViewDebugDialogClick;
    itmViewRegisters.Tag := Ord(ddtRegisters);
    itmViewCallStack.OnClick := @mnuViewDebugDialogClick;
    itmViewCallStack.Tag := Ord(ddtCallStack);
    itmViewThreads.OnClick := @mnuViewDebugDialogClick;
    itmViewThreads.Tag := Ord(ddtThreads);
    itmViewAssembler.OnClick := @mnuViewDebugDialogClick;
    itmViewAssembler.Tag := Ord(ddtAssembler);
    itmViewDebugOutput.OnClick := @mnuViewDebugDialogClick;
    itmViewDebugOutput.Tag := Ord(ddtOutput);
    itmViewDebugEvents.OnClick := @mnuViewDebugDialogClick;
    itmViewDebugEvents.Tag := Ord(ddtEvents);
    if itmViewPseudoTerminal <> nil then begin
      itmViewPseudoTerminal.OnClick := @mnuViewDebugDialogClick;
      itmViewPseudoTerminal.Tag := Ord(ddtPseudoTerminal);
    end;
    itmViewDbgHistory.OnClick := @mnuViewDebugDialogClick;
    itmViewDbgHistory.Tag := Ord(ddtHistory);

    itmRunMenuResetDebugger.OnClick := @mnuResetDebuggerClicked;

    itmRunMenuInspect.OnClick := @mnuViewDebugDialogClick;
    itmRunMenuInspect.Tag := Ord(ddtInspect);
    itmRunMenuEvaluate.OnClick := @mnuViewDebugDialogClick;
    itmRunMenuEvaluate.Tag := Ord(ddtEvaluate);
    itmRunMenuAddWatch.OnClick := @mnuAddWatchClicked;

    itmRunMenuAddBpSource.OnClick  := @mnuAddBpSource;
    itmRunMenuAddBpAddress.OnClick  := @mnuAddBpAddress;
    itmRunMenuAddBpWatchPoint.OnClick := @mnuAddBpData;

    // TODO: add capacibilities to DebuggerClass
    // and disable unsuported items
  end;
end;

procedure TDebugManager.ConnectSourceNotebookEvents;
begin
  SrcEditMenuAddWatchAtCursor.OnClick:=@mnuAddWatchClicked;
  SrcEditMenuAddWatchPointAtCursor.OnClick:=@mnuAddBpDataAtCursor;
  SrcEditMenuEvaluateModify.OnClick:=@mnuViewDebugDialogClick;
  SrcEditMenuEvaluateModify.Tag := Ord(ddtEvaluate);
  SrcEditMenuInspect.OnClick:=@mnuViewDebugDialogClick;
  SrcEditMenuInspect.Tag := Ord(ddtInspect);
end;

function GetCommand(ACommand: word): TIDECommand;
begin
  Result:=IDECommandList.FindIDECommand(ACommand);
  if Result<>nil then
    RegisterIDEButtonCommand(Result);
end;

procedure TDebugManager.SetupMainBarShortCuts;
begin
  with MainIDEBar do
  begin
    itmViewWatches.Command:=GetCommand(ecToggleWatches);
    itmViewBreakpoints.Command:=GetCommand(ecToggleBreakPoints);
    itmViewDebugOutput.Command:=GetCommand(ecToggleDebuggerOut);
    itmViewDebugEvents.Command:=GetCommand(ecToggleDebugEvents);
    itmViewLocals.Command:=GetCommand(ecToggleLocals);
    itmViewRegisters.Command:=GetCommand(ecToggleRegisters);
    itmViewCallStack.Command:=GetCommand(ecToggleCallStack);
    itmViewAssembler.Command:=GetCommand(ecToggleAssembler);
    itmViewThreads.Command:=GetCommand(ecViewThreads);
    if itmViewPseudoTerminal <> nil then
      itmViewPseudoTerminal.Command:=GetCommand(ecViewPseudoTerminal);
    itmViewDbgHistory.Command:=GetCommand(ecViewHistory);

    itmRunMenuInspect.Command:=GetCommand(ecInspect);
    itmRunMenuEvaluate.Command:=GetCommand(ecEvaluate);
    itmRunMenuAddWatch.Command:=GetCommand(ecAddWatch);
    itmRunMenuAddBpSource.Command:=GetCommand(ecAddBpSource);
    itmRunMenuAddBpAddress.Command:=GetCommand(ecAddBpAddress);
    itmRunMenuAddBpWatchPoint.Command:=GetCommand(ecAddBpDataWatch);
  end;
end;

procedure TDebugManager.SetupSourceMenuShortCuts;
begin
  SrcEditMenuToggleBreakpoint.Command:=GetCommand(ecToggleBreakPoint);
  SrcEditMenuStepToCursor.Command:=GetCommand(ecStepToCursor);
  SrcEditMenuRunToCursor.Command:=GetCommand(ecRunToCursor);
  SrcEditMenuEvaluateModify.Command:=GetCommand(ecEvaluate);
  SrcEditMenuAddWatchAtCursor.Command:=GetCommand(ecAddWatch);
  SrcEditMenuAddWatchPointAtCursor.Command:=GetCommand(ecAddBpDataWatch);
  SrcEditMenuInspect.Command:=GetCommand(ecInspect);
  SrcEditMenuViewCallStack.Command:=GetCommand(ecToggleCallStack);
end;

procedure TDebugManager.UpdateButtonsAndMenuItems;
var
  DebuggerIsValid: boolean;
  CanRun: Boolean;
  SrcEdit: TSourceEditorInterface;
  AnUnitInfo: TUnitInfo;
  AvailCommands: TDBGCommands;
  CurState: TDBGState;
begin
  if (MainIDE=nil) or (MainIDE.ToolStatus = itExiting) then exit;

  if FDebugger <> nil then begin
    AvailCommands := FDebugger.Commands;
    CurState := FDebugger.State;
    if CurState = dsError then begin
      CurState := dsStop;
      AvailCommands := GetDebuggerClass.SupportedCommandsFor(dsStop);
    end;
  end
  else begin
    AvailCommands := GetDebuggerClass.SupportedCommandsFor(dsStop);
    CurState := dsStop;
  end;
  DebuggerIsValid:=(MainIDE.ToolStatus in [itNone, itDebugger]);
  MainIDE.GetCurrentUnitInfo(SrcEdit,AnUnitInfo);
  with MainIDEBar do begin
    // For 'run' and 'step' bypass 'idle', so we can set the filename later
    CanRun:=false;
    if (Project1<>nil) and DebuggerIsValid then
      CanRun:=( (AnUnitInfo<>nil) and (AnUnitInfo.RunFileIfActive) ) or
              ( ((Project1.CompilerOptions.ExecutableType=cetProgram) or
                 ((Project1.RunParameterOptions.GetActiveMode<>nil) and (Project1.RunParameterOptions.GetActiveMode.HostApplicationFilename<>'')))
               and (pfRunnable in Project1.Flags)
              );
    // Run
    itmRunMenuRun.Enabled          := CanRun and (dcRun in AvailCommands);
    // Pause
    itmRunMenuPause.Enabled        := CanRun and ((dcPause in AvailCommands) or FAutoContinueTimer.Enabled);
    // Show execution point
    itmRunMenuShowExecutionPoint.Enabled := CanRun and (CurState = dsPause);
    // Step into
    itmRunMenuStepInto.Enabled     := CanRun and (dcStepInto in AvailCommands);
    // Step over
    itmRunMenuStepOver.Enabled     := CanRun and (dcStepOver in AvailCommands);
    // Step out
    itmRunMenuStepOut.Enabled      := CanRun and (dcStepOut in AvailCommands) and (CurState = dsPause);
    // Step to cursor
    itmRunMenuStepToCursor.Enabled := CanRun and (dcStepTo in AvailCommands);
    // Run to cursor
    itmRunMenuRunToCursor.Enabled  := CanRun and (dcRunTo in AvailCommands);
    // Stop
    itmRunMenuStop.Enabled         := (CanRun and (MainIDE.ToolStatus = itDebugger) and
      (CurState in [dsPause, dsInternalPause, dsInit, dsRun, dsError])) or
      (MainIDE.ToolStatus = itBuilder);

    //Attach / Detach
    itmRunMenuAttach.Enabled          := DebuggerIsValid and (dcAttach in AvailCommands);
    itmRunMenuDetach.Enabled          := DebuggerIsValid and (dcDetach in AvailCommands);

    // Evaluate
    itmRunMenuEvaluate.Enabled        := CanRun and (dcEvaluate in AvailCommands);
    // Evaluate / modify
    SrcEditMenuEvaluateModify.Enabled := CanRun and (dcEvaluate in AvailCommands);
    // Inspect
    SrcEditMenuInspect.Enabled        := CanRun and (dcEvaluate in AvailCommands);
    itmRunMenuInspect.Enabled         := CanRun and (dcEvaluate in AvailCommands);
    // Add watch
    itmRunMenuAddWatch.Enabled        := True; // always allow to add a watch

    // Add Breakpoint
    itmRunMenuAddBpSource.Enabled := True;
    itmRunMenuAddBpAddress.Enabled := True;
    itmRunMenuAddBpWatchPoint.Enabled := True;

    // TODO: add capacibilities to DebuggerClass
    // menu view
    //itmViewRegisters.Enabled := DebuggerIsValid;
    //itmViewAssembler.Enabled := DebuggerIsValid;
  end;
end;

procedure TDebugManager.UpdateToolStatus;
const
  TOOLSTATEMAP: array[TDBGState] of TIDEToolStatus = (
  //dsNone, dsIdle, dsStop,     dsPause,    dsInternalPause, dsInit,     dsRun,      dsError,    dsDestroying
    itNone, itNone, itNone, itDebugger, itDebugger,      itDebugger, itDebugger, itNone, itNone
  );
begin
  // Next may call ResetDebugger, then FDebugger is gone
  if MainIDE.ToolStatus in [itNone,itDebugger]
  then begin
    if FDebugger = nil then
      MainIDE.ToolStatus := itNone
    else
      MainIDE.ToolStatus := TOOLSTATEMAP[FDebugger.State];
  end;
end;

procedure TDebugManager.EnvironmentOptsChanged;
begin
  if FDebugger <> nil then begin
    if EnvironmentOptions.DebuggerAllowFunctionCalls then
      FDebugger.EnabledFeatures := FDebugger.EnabledFeatures + [dfEvalFunctionCalls]
    else
      FDebugger.EnabledFeatures := FDebugger.EnabledFeatures - [dfEvalFunctionCalls];
  end;
end;

{------------------------------------------------------------------------------
  procedure TDebugManager.LoadProjectSpecificInfo(XMLConfig: TXMLConfig;
                                  Merge: boolean);

  Called when the main project is loaded from the XMLConfig.
------------------------------------------------------------------------------}
procedure TDebugManager.LoadProjectSpecificInfo(XMLConfig: TXMLConfig;
  Merge: boolean);
begin
  if not Merge then
  begin
    FExceptions.LoadFromXMLConfig(XMLConfig,'Debugging/'+XMLExceptionsNode+'/');
  end;
  // keep it simple: just load from the session and don't merge
  FBreakPointGroups.LoadFromXMLConfig(XMLConfig,
                                     'Debugging/'+XMLBreakPointGroupsNode+'/');
  FBreakPoints.LoadFromXMLConfig(XMLConfig,'Debugging/'+XMLBreakPointsNode+'/',
                                 @Project1.ConvertFromLPIFilename,
                                 @FBreakPointGroups.GetGroupByName);
  FWatches.LoadFromXMLConfig(XMLConfig,'Debugging/'+XMLWatchesNode+'/');
end;

{------------------------------------------------------------------------------
  procedure TDebugManager.SaveProjectSpecificInfo(XMLConfig: TXMLConfig;
                                   Flags: TProjectWriteFlags);

  Called when the main project is saved to an XMLConfig.
------------------------------------------------------------------------------}
procedure TDebugManager.SaveProjectSpecificInfo(XMLConfig: TXMLConfig;
  Flags: TProjectWriteFlags);
begin
  if not (pwfSkipSeparateSessionInfo in Flags) then
  begin
    FBreakPointGroups.SaveToXMLConfig(XMLConfig,
                                      'Debugging/'+XMLBreakPointGroupsNode+'/', pwfCompatibilityMode in Flags);
    FBreakPoints.SaveToXMLConfig(XMLConfig,'Debugging/'+XMLBreakPointsNode+'/',
      pwfCompatibilityMode in Flags, @Project1.ConvertToLPIFilename);
    FWatches.SaveToXMLConfig(XMLConfig,'Debugging/'+XMLWatchesNode+'/', pwfCompatibilityMode in Flags);
  end;
  if not (pwfSkipProjectInfo in Flags) then
  begin
    // exceptions are not part of the project info (#0015256)
    FExceptions.SaveToXMLConfig(XMLConfig,'Debugging/'+XMLExceptionsNode+'/', pwfCompatibilityMode in Flags);
  end;
end;

procedure TDebugManager.DoRestoreDebuggerMarks(AnUnitInfo: TUnitInfo);
var
  ASrcEdit: TSourceEditor;
  i: Integer;
  CurBreakPoint: TIDEBreakPoint;
  SrcFilename: String;
begin
  if (AnUnitInfo.OpenEditorInfoCount = 0) or Destroying then exit;
  ASrcEdit := TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent);
  // set breakpoints for this unit
  SrcFilename:=AnUnitInfo.Filename;
  for i := 0 to FBreakpoints.Count-1 do
  begin
    CurBreakPoint := FBreakpoints[i];
    if CompareFileNames(CurBreakPoint.Source, SrcFilename) = 0 then
      CreateSourceMarkForBreakPoint(CurBreakPoint, ASrcEdit);
  end;
end;

procedure TDebugManager.CreateSourceMarkForBreakPoint(
  const ABreakpoint: TIDEBreakPoint; ASrcEdit: TSourceEditor);
var
  ManagedBreakPoint: TManagedBreakPoint;
  NewSrcMark: TSourceMark;
begin
  if not (ABreakpoint is TManagedBreakPoint) then
    RaiseGDBException('TDebugManager.CreateSourceMarkForBreakPoint');
  ManagedBreakPoint:=TManagedBreakPoint(ABreakpoint);

  if (ManagedBreakPoint.SourceMark<>nil) or Destroying then exit;
  if ASrcEdit=nil then
    GetSourceEditorForBreakPoint(ManagedBreakPoint,ASrcEdit);
  if ASrcEdit=nil then exit;
  NewSrcMark:=TSourceMark.Create(ASrcEdit, nil);
  ManagedBreakPoint.SourceMark:=NewSrcMark;
  SourceEditorMarks.Add(NewSrcMark);
end;

procedure TDebugManager.GetSourceEditorForBreakPoint(
  const ABreakpoint: TIDEBreakPoint; var ASrcEdit: TSourceEditor);
var
  Filename: String;
begin
  Filename:=ABreakpoint.Source;
  if Filename<>'' then
    ASrcEdit:=SourceEditorManager.SourceEditorIntfWithFilename(ABreakpoint.Source)
  else
    ASrcEdit:=nil;
end;

procedure TDebugManager.CreateDebugDialog(Sender: TObject; aFormName: string;
  var AForm: TCustomForm; DoDisableAutoSizing: boolean);

  function ItIs(Prefix: string): boolean;
  begin
    Result:=SysUtils.CompareText(copy(aFormName,1,length(Prefix)),Prefix)=0;
  end;

var
  DlgType: TDebugDialogType;
begin
  for DlgType:=Low(TDebugDialogType) to High(TDebugDialogType) do
    if ItIs(DebugDialogNames[DlgType]) then
    begin
      ViewDebugDialog(DlgType,false,false,DoDisableAutoSizing);
      AForm:=FDialogs[DlgType];
      exit;
    end;
  raise Exception.Create('TDebugManager.CreateDebugDialog invalid FormName "'+aFormName+'"');
end;

procedure TDebugManager.ClearDebugOutputLog;
begin
  if FDialogs[ddtOutput] <> nil then
    TDbgOutputForm(FDialogs[ddtOutput]).Clear
  else if fHiddenDebugOutputLog<>nil then
    fHiddenDebugOutputLog.Clear;
end;

procedure TDebugManager.ClearDebugEventsLog;
begin
  FEventLogManager.ClearDebugEventsLog;
end;

function TDebugManager.RequiredCompilerOpts(ATargetCPU, ATargetOS: String
  ): TDebugCompilerRequirements;
begin
  if DebuggerClass = nil then
    exit([]);
  Result := DebuggerClass.RequiredCompilerOpts(ATargetCPU, ATargetOS);
end;

//-----------------------------------------------------------------------------
// Debugger routines
//-----------------------------------------------------------------------------

procedure TDebugManager.FreeDebugger;
var
  dbg: TDebuggerIntf;
begin
  dbg := FDebugger;
  SetDebugger(nil);
  dbg.Release;
  FManagerStates := [];
  FIsInitializingDebugger:= False;

  if MainIDE.ToolStatus = itDebugger
  then MainIDE.ToolStatus := itNone;
end;

procedure TDebugManager.ResetDebugger;
var
  OldState: TDBGState;
begin
  OldState := State;
  if OldState = dsNone then Exit;

  FDebugger.BeginReset;
  EndDebugging;
//  OnDebuggerChangeState(FDebugger, OldState);
//  InitDebugger;
end;

function TDebugManager.GetLaunchPathAndExe(out LaunchingCmdLine,
  LaunchingApplication, LaunchingParams: String; PromptOnError: Boolean
  ): Boolean;

  procedure ClearPathAndExe;
  begin
    LaunchingApplication := '';
    LaunchingParams := '';
    LaunchingCmdLine := '';
  end;

var
  NewDebuggerClass: TDebuggerClass;
begin
  Result := False;
  NewDebuggerClass := GetDebuggerClass;
  LaunchingCmdLine := BuildBoss.GetRunCommandLine;
  SplitCmdLine(LaunchingCmdLine, LaunchingApplication, LaunchingParams);

  (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834
     Se Debugger.RequiresLocalExecutable
  *)
  if NewDebuggerClass.RequiresLocalExecutable then begin

    if BuildBoss.GetProjectUsesAppBundle then
    begin
      // it is Application Bundle (darwin only)

      if not DirectoryExistsUTF8(LaunchingApplication) then
      begin
        if not PromptOnError then
          ClearPathAndExe
        else begin
          BuildBoss.WriteDebug_RunCommandLine;
          if IDEMessageDialog(lisLaunchingApplicationInvalid,
            Format(lisTheLaunchingApplicationBundleDoesNotExists,
              [LaunchingApplication, LineEnding, LineEnding, LineEnding+LineEnding]),
            mtError, [mbYes, mbNo, mbCancel]) = mrYes then
          begin
            if not BuildBoss.CreateProjectApplicationBundle then Exit;
          end
          else
            Exit;
        end;
      end;

      if (NewDebuggerClass = TProcessDebugger) and (LaunchingApplication <> '') then
      begin // use executable path inside Application Bundle (darwin only)
        LaunchingApplication := LaunchingApplication + '/Contents/MacOS/' +
          ExtractFileNameOnly(LaunchingApplication);
      end;
    end
    else
      if not FileIsExecutable(LaunchingApplication)
      then begin
        BuildBoss.WriteDebug_RunCommandLine;
        if not PromptOnError then
          ClearPathAndExe
        else begin
          IDEMessageDialog(lisLaunchingApplicationInvalid,
            Format(lisTheLaunchingApplicationDoesNotExistsOrIsNotExecuta,
                   [LaunchingApplication, LineEnding, LineEnding+LineEnding]),
            mtError, [mbOK]);
          Exit;
        end;
      end;

    // check if debugger needs an Exe and the exe is there
    if (NewDebuggerClass.NeedsExePath)
    and not FileIsExecutable(EnvironmentOptions.GetParsedDebuggerFilename(Project1))
    then begin
      if not PromptOnError then
        ClearPathAndExe
      else begin
        debugln(['Info: (lazarus) [TDebugManager.GetLaunchPathAndExe] EnvironmentOptions.DebuggerFilename="',EnvironmentOptions.DebuggerFilename,'"']);
        IDEMessageDialog(lisDebuggerInvalid,
          Format(lisTheDebuggerDoesNotExistsOrIsNotExecutableSeeEnviro,
            [EnvironmentOptions.DebuggerFilename(Project1), LineEnding, LineEnding+LineEnding]),
          mtError,[mbOK]);
        Exit;
      end;
    end;

  end; // if NewDebuggerClass.RequiresLocalExecutable then
  Result := True;
end;

function TDebugManager.InitDebugger(AFlags: TDbgInitFlags): Boolean;
var
  LaunchingCmdLine, LaunchingApplication, LaunchingParams: String;
  NewWorkingDir: String;
  NewDebuggerClass: TDebuggerClass;
begin
{$ifdef VerboseDebugger}
  DebugLn('[TDebugManager.DoInitDebugger] A');
{$endif}

  Result := False;
  if FIsInitializingDebugger then begin
    DebugLn('[TDebugManager.DoInitDebugger] *** Re-Entered');
    exit;
  end;

  if Destroying or (Project1 = nil) then Exit;
  if not(difInitForAttach in AFlags) then begin
    if (Project1.MainUnitID < 0) then Exit;
    if not GetLaunchPathAndExe(LaunchingCmdLine, LaunchingApplication, LaunchingParams) then
      exit;
  end
  else
    GetLaunchPathAndExe(LaunchingCmdLine, LaunchingApplication, LaunchingParams, False);

  FUnitInfoProvider.Clear;
  FIsInitializingDebugger:= True;
  try
    NewDebuggerClass := GetDebuggerClass;

    if (dmsDebuggerObjectBroken in FManagerStates)
    then begin
      FreeDebugger;
      FIsInitializingDebugger:= True; // been reset by FreeDebuger
    end;

    // check if debugger is already created with the right type
    if (FDebugger <> nil)
    and (not (FDebugger.ClassType = NewDebuggerClass) // exact class match
          or (FDebugger.ExternalDebugger <> EnvironmentOptions.GetParsedDebuggerFilename(Project1))
          or (FDebugger.State in [dsError])
        )
    then begin
      // the current debugger is the wrong type -> free it
      FreeDebugger;
      FIsInitializingDebugger:= True; // been reset by FreeDebuger
    end;

    // create debugger object
    if FDebugger = nil
    then SetDebugger(NewDebuggerClass.Create(EnvironmentOptions.GetParsedDebuggerFilename(Project1)));

    if FDebugger = nil
    then begin
      // something went wrong
      Exit;
    end;

    if (EnvironmentOptions.CurrentDebuggerPropertiesConfigEx(Project1) <> nil) and
       (EnvironmentOptions.CurrentDebuggerPropertiesConfigEx(Project1).DebuggerProperties <> nil)
    then
      FDebugger.GetProperties.Assign(EnvironmentOptions.CurrentDebuggerPropertiesConfigEx(Project1).DebuggerProperties);

    ClearDebugOutputLog;
    if EnvironmentOptions.DebuggerEventLogClearOnRun then
      ClearDebugEventsLog;

    //ensure to unset all evemts in SetDebugger()
    FDebugger.OnBreakPointHit := @DebuggerBreakPointHit;
    FDebugger.OnBeforeState   := @DebuggerBeforeChangeState;
    FDebugger.OnState         := @DebuggerChangeState;
    FDebugger.OnCurrent       := @DebuggerCurrentLine;
    FDebugger.OnDbgOutput     := @DebuggerOutput;
    FDebugger.OnDbgEvent      := @FEventLogManager.DebuggerEvent;
    FDebugger.OnException     := @DebuggerException;
    FDebugger.OnConsoleOutput := @DebuggerConsoleOutput;
    FDebugger.OnFeedback      := @DebuggerFeedback;
    FDebugger.OnIdle          := @DebuggerIdle;
    FDebugger.EventLogHandler := FEventLogManager;

    FEventLogManager.TargetWidth := FDebugger.TargetWidth div 8;

    if FDebugger.State = dsNone
    then begin
      Include(FManagerStates,dmsInitializingDebuggerObject);
      Exclude(FManagerStates,dmsInitializingDebuggerObjectFailed);
      // The following commands may call ProcessMessages, and FDebugger can be nil after each
      FDebugger.Init;
      Exclude(FManagerStates,dmsInitializingDebuggerObject);
      if (FDebugger = nil) or (dmsInitializingDebuggerObjectFailed in FManagerStates)
      then begin
        FreeDebugger;
        Exit;
      end;
    end;

    if not(difInitForAttach in AFlags) then begin
      Project1.RunParameterOptions.AssignEnvironmentTo(FDebugger.Environment);
      if Project1.RunParameterOptions.GetActiveMode<>nil then
        NewWorkingDir:=Project1.RunParameterOptions.GetActiveMode.WorkingDirectory
      else
        NewWorkingDir:='';
      GlobalMacroList.SubstituteStr(NewWorkingDir);
      if NewDebuggerClass.RequiresLocalExecutable  and     (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834   *)
         (NewWorkingDir<>'') and (not DirectoryExistsUTF8(NewWorkingDir))
      then begin
        IDEMessageDialog(lisUnableToRun,
          Format(lisTheWorkingDirectoryDoesNotExistPleaseCheckTheWorki,
                 [NewWorkingDir, LineEnding]),
          mtError,[mbCancel]);
        exit;
      end;
      if NewWorkingDir='' then begin
        NewWorkingDir:=ExtractFilePath(BuildBoss.GetProjectTargetFilename(Project1));
        if NewDebuggerClass.RequiresLocalExecutable  and     (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834   *)
           (NewWorkingDir<>'') and (not DirectoryExistsUTF8(NewWorkingDir))
        then begin
          IDEMessageDialog(lisUnableToRun,
            Format(lisTheDestinationDirectoryDoesNotExistPleaseCheckTheP,
                   [NewWorkingDir, LineEnding]),
            mtError,[mbCancel]);
          exit;
        end;
      end;

      // The following commands may call ProcessMessages, and FDebugger can be nil after each

      if (FDebugger <> nil) and not NewDebuggerClass.RequiresLocalExecutable
      then FDebugger.WorkingDir:=NewWorkingDir;
      if (FDebugger <> nil) and NewDebuggerClass.RequiresLocalExecutable
      then FDebugger.WorkingDir:=CleanAndExpandDirectory(NewWorkingDir);
      // set filename after workingdir
      if FDebugger <> nil
      then FDebugger.FileName := LaunchingApplication;
      if FDebugger <> nil
      then FDebugger.Arguments := LaunchingParams;
      if FDebugger <> nil
      then FDebugger.ShowConsole := not Project1.CompilerOptions.Win32GraphicApp;
    end
    else begin
      // attach
      if (FDebugger <> nil) and (LaunchingApplication <> '')
      then FDebugger.FileName := LaunchingApplication;
    end;

    // check if debugging needs restart
    // mwe: can this still happen ?
    if (FDebugger = nil) or (dmsDebuggerObjectBroken in FManagerStates)
    then begin
      FreeDebugger;
      Exit;
    end;

    Result := True;
  finally
    // Since ProcessMessages has been called, debugger may have been reseted, even during initialization...
    if not FIsInitializingDebugger
    then begin
      Result := False;
      ResetDebugger;
    end;
    FIsInitializingDebugger:= False;
  end;
{$ifdef VerboseDebugger}
  DebugLn('[TDebugManager.DoInitDebugger] END');
{$endif}
end;

function TDebugManager.DoSetBreakkPointWarnIfNoDebugger: boolean;
var
  DbgClass: TDebuggerClass;
begin
  DbgClass:=EnvironmentOptions.CurrentDebuggerClass(Project1);
  if (DbgClass=nil)
  or (DbgClass.NeedsExePath
    and (not FileIsExecutableCached(EnvironmentOptions.GetParsedDebuggerFilename(Project1))))
  then begin
    if IDEQuestionDialog(lisDbgMangNoDebuggerSpecified,
      Format(lisDbgMangThereIsNoDebuggerSpecifiedSettingBreakpointsHaveNo,[LineEnding]),
      mtWarning, [mrCancel, mrIgnore, lisDbgMangSetTheBreakpointAnyway]) <> mrIgnore
    then
      exit(false);
  end;
  Result:=true;
end;

// still part of main, should go here when processdebugger is finished
//
//function TDebugManager.DoRunProject: TModalResult;

function TDebugManager.DoPauseProject: TModalResult;
begin
  Result := mrCancel;
  if (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then Exit;
  FAutoContinueTimer.Enabled := False;
  FDebugger.Pause;
  Result := mrOk;
end;

function TDebugManager.DoShowExecutionPoint: TModalResult;
begin
  Result := mrCancel;
  if (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then Exit;

  DebuggerCurrentLine(FDebugger, FCurrentLocation);
  Result := mrOk;
end;

function TDebugManager.DoStepIntoProject: TModalResult;
begin
  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  FStepping:=True;
  FDebugger.StepInto;
  Result := mrOk;
end;

function TDebugManager.DoStepOverProject: TModalResult;
begin
  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  FStepping:=True;
  FDebugger.StepOver;
  Result := mrOk;
end;

function TDebugManager.DoStepIntoInstrProject: TModalResult;
begin
  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  FStepping:=True;
  FDebugger.StepIntoInstr;
  Result := mrOk;
  // Todo: move to DebuggerChangeState (requires the last run-command-type to be avail)
  ViewDebugDialog(ddtAssembler);
end;

function TDebugManager.DoStepOverInstrProject: TModalResult;
begin
  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  FStepping:=True;
  FDebugger.StepOverInstr;
  Result := mrOk;
  // Todo: move to DebuggerChangeState (requires the last run-command-type to be avail)
  ViewDebugDialog(ddtAssembler);
end;

function TDebugManager.DoStepOutProject: TModalResult;
begin
  if (FDebugger = nil) or not(dcStepOut in FDebugger.Commands)
  then begin
    Result := mrAbort;
    Exit;
  end;

  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  FStepping:=True;
  FDebugger.StepOut;
  Result := mrOk;
end;

function TDebugManager.DoStopProject: TModalResult;
begin
  Result := mrCancel;

  FRunTimer.Enabled:=false;
  Exclude(FManagerStates,dmsWaitForRun);
  Exclude(FManagerStates,dmsWaitForAttach);

  SourceEditorManager.ClearExecutionLines;
  if (MainIDE.ToolStatus=itDebugger) and (FDebugger<>nil) and (not Destroying)
  then begin
    FDebugger.Stop;
  end;
  if (dmsDebuggerObjectBroken in FManagerStates) then begin
    if (MainIDE.ToolStatus=itDebugger) then
      MainIDE.ToolStatus:=itNone;
  end;

  FUnitInfoProvider.Clear; // Maybe keep locations? But clear "not found"/"not loadable" flags?
  Result := mrOk;
end;

procedure TDebugManager.DoToggleCallStack;
begin
  ViewDebugDialog(ddtCallStack);
end;

procedure TDebugManager.DoSendConsoleInput(AText: String);
begin
  if FDebugger <> nil then
    FDebugger.SendConsoleInput(AText);
end;

procedure TDebugManager.ProcessCommand(Command: word; var Handled: boolean);
begin
  //debugln('TDebugManager.ProcessCommand ',dbgs(Command));
  Handled := True;
  case Command of
    ecPause:             DoPauseProject;
    ecStepInto:          DoStepIntoProject;
    ecStepOver:          DoStepOverProject;
    ecStepIntoInstr:     DoStepIntoInstrProject;
    ecStepOverInstr:     DoStepOverInstrProject;
    ecStepIntoContext:   begin
                           if (FDialogs[ddtAssembler] <> nil) and FDialogs[ddtAssembler].Active
                           then DoStepIntoInstrProject
                           else DoStepIntoProject;
                         end;
    ecStepOverContext:   begin
                           if (FDialogs[ddtAssembler] <> nil) and FDialogs[ddtAssembler].Active
                           then DoStepOverInstrProject
                           else DoStepOverProject;
                         end;
    ecStepOut:           DoStepOutProject;
    ecStepToCursor:      DoStepToCursor;
    ecRunToCursor:       DoRunToCursor;
    ecStopProgram:       DoStopProject;
    ecResetDebugger:     ResetDebugger;
    ecToggleCallStack:   DoToggleCallStack;
    ecEvaluate:          ViewDebugDialog(ddtEvaluate);
    ecInspect:           ViewDebugDialog(ddtInspect);
    ecToggleWatches:     ViewDebugDialog(ddtWatches);
    ecToggleBreakPoints: ViewDebugDialog(ddtBreakpoints);
    ecToggleDebuggerOut: ViewDebugDialog(ddtOutput);
    ecToggleDebugEvents: ViewDebugDialog(ddtEvents);
    ecToggleLocals:      ViewDebugDialog(ddtLocals);
    ecViewPseudoTerminal: ViewDebugDialog(ddtPseudoTerminal);
    ecViewThreads:       ViewDebugDialog(ddtThreads);
    ecViewHistory:       ViewDebugDialog(ddtHistory);
  else
    Handled := False;
  end;
end;

procedure TDebugManager.LockCommandProcessing;
begin
  if assigned(FDebugger)
  then FDebugger.LockCommandProcessing;
end;

procedure TDebugManager.UnLockCommandProcessing;
begin
  if assigned(FDebugger)
  then FDebugger.UnLockCommandProcessing;
end;

function TDebugManager.StartDebugging: TModalResult;
begin
  {$ifdef VerboseDebugger}
  DebugLn('TDebugManager.StartDebugging A ',DbgS(FDebugger<>nil),' Destroying=',DbgS(Destroying));
  {$endif}
  Result:=mrCancel;
  if Destroying then exit;
  if FManagerStates*[dmsWaitForRun, dmsWaitForAttach] <> [] then exit;
  if (FDebugger <> nil) then
  begin
    // dmsRunning + dsPause => evaluating stack+watches after run
    if (dmsRunning in FManagerStates) then begin
      if (FDebugger.State = dsPause) then
        FDebugger.Run;

      exit;
    end;

    {$ifdef VerboseDebugger}
    DebugLn('TDebugManager.StartDebugging B ',FDebugger.ClassName);
    {$endif}
    // check if debugging needs restart
    if (dmsDebuggerObjectBroken in FManagerStates)
    and (MainIDE.ToolStatus=itDebugger) then begin
      MainIDE.ToolStatus:=itNone;
      Result:=mrCancel;
      exit;
    end;
    Include(FManagerStates,dmsWaitForRun);
    FRunTimer.Enabled:=true;
    Result:=mrOk;
  end;
end;

function TDebugManager.RunDebugger: TModalResult;
begin
  {$ifdef VerboseDebugger}
  DebugLn('TDebugManager.RunDebugger A ',DbgS(FDebugger<>nil),' Destroying=',DbgS(Destroying));
  {$endif}
  Result:=mrCancel;
  if Destroying then exit;
  Exclude(FManagerStates,dmsWaitForRun);
  if dmsRunning in FManagerStates then exit;
  if MainIDE.ToolStatus<>itDebugger then exit;
  if (FDebugger <> nil) then
  begin
    {$ifdef VerboseDebugger}
    DebugLn('TDebugManager.RunDebugger B ',FDebugger.ClassName);
    {$endif}
    // check if debugging needs restart
    if (dmsDebuggerObjectBroken in FManagerStates)
    and (MainIDE.ToolStatus=itDebugger) then begin
      MainIDE.ToolStatus:=itNone;
      Result:=mrCancel;
      exit;
    end;
    Include(FManagerStates,dmsRunning);
    FStepping:=False;
    try
      FDebugger.Run;
    finally
      Exclude(FManagerStates,dmsRunning);
    end;
    Result:=mrOk;
  end;
end;

procedure TDebugManager.EndDebugging;
begin
  FRunTimer.Enabled:=false;
  Exclude(FManagerStates,dmsWaitForRun);
  Exclude(FManagerStates,dmsWaitForAttach);
  if FDebugger <> nil then FDebugger.Done;
  // if not already freed
  FreeDebugger;
end;

procedure TDebugManager.Attach(AProcessID: String);
begin
  if Destroying then exit;
  if FManagerStates*[dmsWaitForRun, dmsWaitForAttach, dmsRunning] <> [] then exit;
  if (FDebugger <> nil) then
  begin
    // check if debugging needs restart
    if (dmsDebuggerObjectBroken in FManagerStates)
    and (MainIDE.ToolStatus=itDebugger) then begin
      MainIDE.ToolStatus:=itNone;
      exit;
    end;
    FAttachToID := AProcessID;
    Include(FManagerStates,dmsWaitForAttach);
    FRunTimer.Enabled:=true;
  end;
end;

function TDebugManager.FillProcessList(AList: TRunningProcessInfoList): boolean;
begin
  Result := (not Destroying)
        and (MainIDE.ToolStatus in [itDebugger, itNone])
        and (FDebugger <> nil)
        and FDebugger.GetProcessList(AList);
end;

procedure TDebugManager.Detach;
begin
  FRunTimer.Enabled:=false;  Exclude(FManagerStates,dmsWaitForRun);
  Exclude(FManagerStates,dmsWaitForAttach);

  SourceEditorManager.ClearExecutionLines;
  if (MainIDE.ToolStatus=itDebugger) and (FDebugger<>nil) and (not Destroying)
  then begin
    FDebugger.Detach;
  end;
  if (dmsDebuggerObjectBroken in FManagerStates) then begin
    if (MainIDE.ToolStatus=itDebugger) then
      MainIDE.ToolStatus:=itNone;
  end;

  FUnitInfoProvider.Clear; // Maybe keep locations? But clear "not found"/"not loadable" flags?
end;

function TDebugManager.Evaluate(const AExpression: String;
  ACallback: TDBGEvaluateResultCallback; EvalFlags: TDBGEvaluateFlags): Boolean;
begin
  Result := (not Destroying)
        and (MainIDE.ToolStatus = itDebugger)
        and (FDebugger <> nil)
        and (dcEvaluate in FDebugger.Commands)
        and FDebugger.Evaluate(AExpression, ACallback, EvalFlags);
end;

function TDebugManager.Modify(const AExpression, ANewValue: String): Boolean;
begin
  Result := (not Destroying)
        and (MainIDE.ToolStatus = itDebugger)
        and (FDebugger <> nil)
        and (dcModify in FDebugger.Commands)
        and FDebugger.Modify(AExpression, ANewValue);
end;

procedure TDebugManager.EvaluateModify(const AExpression: String);
begin
  if Destroying then Exit;
  ViewDebugDialog(ddtEvaluate);
  if FDialogs[ddtEvaluate] <> nil then
    TEvaluateDlg(FDialogs[ddtEvaluate]).FindText := AExpression;
end;

procedure TDebugManager.Inspect(const AExpression: String);
begin
  if Destroying then Exit;
  ViewDebugDialog(ddtInspect); // TODO: If not yet open, this will get Expression from SourceEdit, and trigger uneeded eval.
  if FDialogs[ddtInspect] <> nil then
  begin
    TIDEInspectDlg(FDialogs[ddtInspect]).Execute(AExpression);
  end;
end;

function TDebugManager.DoCreateBreakPoint(const AFilename: string;
  ALine: integer; WarnIfNoDebugger: boolean): TModalResult;
var
  ABrkPoint: TIDEBreakPoint;
begin
  Result := DoCreateBreakPoint(AFilename, ALine, WarnIfNoDebugger, ABrkPoint);
end;

function TDebugManager.DoCreateBreakPoint(const AFilename: string;
  ALine: integer; WarnIfNoDebugger: boolean; out ABrkPoint: TIDEBreakPoint;
  AnUpdating: Boolean): TModalResult;
begin
  ABrkPoint := nil;
  if WarnIfNoDebugger and not DoSetBreakkPointWarnIfNoDebugger then
    exit(mrCancel);

  ABrkPoint := FBreakPoints.Add(AFilename, ALine, AnUpdating);
  Result := mrOK;
end;

function TDebugManager.DoCreateBreakPoint(const AnAddr: TDBGPtr;
  WarnIfNoDebugger: boolean; out ABrkPoint: TIDEBreakPoint; AnUpdating: Boolean
  ): TModalResult;
begin
  ABrkPoint := nil;
  if WarnIfNoDebugger and not DoSetBreakkPointWarnIfNoDebugger then
    exit(mrCancel);

  ABrkPoint := FBreakPoints.Add(AnAddr, AnUpdating);
  Result := mrOK;
end;

function TDebugManager.DoDeleteBreakPoint(const AFilename: string;
  ALine: integer): TModalResult;
var
  OldBreakPoint: TIDEBreakPoint;
begin
  LockCommandProcessing;
  try
    OldBreakPoint:=FBreakPoints.Find(AFilename,ALine);
    if OldBreakPoint=nil then exit(mrOk);
    ReleaseRefAndNil(OldBreakPoint);
    Project1.Modified:=true;
    Result := mrOK;
  finally
    UnLockCommandProcessing;
  end;
end;

function TDebugManager.DoDeleteBreakPointAtMark(const ASourceMark: TSourceMark
  ): TModalResult;
var
  OldBreakPoint: TIDEBreakPoint;
begin
  LockCommandProcessing;
  try
    // consistency check
    if (ASourceMark=nil) or (not ASourceMark.IsBreakPoint)
    or (ASourceMark.Data=nil) or (not (ASourceMark.Data is TIDEBreakPoint)) then
      RaiseGDBException('TDebugManager.DoDeleteBreakPointAtMark');

  {$ifdef VerboseDebugger}
    DebugLn('TDebugManager.DoDeleteBreakPointAtMark A ',ASourceMark.GetFilename,
      ' ',IntToStr(ASourceMark.Line));
  {$endif}
    OldBreakPoint:=TIDEBreakPoint(ASourceMark.Data);
  {$ifdef VerboseDebugger}
    DebugLn('TDebugManager.DoDeleteBreakPointAtMark B ',OldBreakPoint.ClassName,
      ' ',OldBreakPoint.Source,' ',IntToStr(OldBreakPoint.Line));
  {$endif}
    ReleaseRefAndNil(OldBreakPoint);
    Project1.Modified:=true;
    Result := mrOK;
  finally
    UnLockCommandProcessing;
  end;
end;

function TDebugManager.DoStepToCursor: TModalResult;
var
  ActiveSrcEdit: TSourceEditorInterface;
  ActiveUnitInfo: TUnitInfo;
  UnitFilename: string;
begin
{$ifdef VerboseDebugger}
  DebugLn('TDebugManager.DoStepToCursor A');
{$endif}
  if (FDebugger = nil) or not(dcStepTo in FDebugger.Commands)
  then begin
    Result := mrAbort;
    Exit;
  end;

  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;
{$ifdef VerboseDebugger}
  DebugLn('TDebugManager.DoStepToCursor B');
{$endif}

  Result := mrCancel;

  MainIDE.GetCurrentUnitInfo(ActiveSrcEdit,ActiveUnitInfo);
  if (ActiveSrcEdit=nil) or (ActiveUnitInfo=nil)
  then begin
    IDEMessageDialog(lisRunToFailed, lisPleaseOpenAUnitBeforeRun, mtError,
      [mbCancel]);
    Result := mrCancel;
    Exit;
  end;

  if not ActiveUnitInfo.Source.IsVirtual
  then UnitFilename:=ActiveUnitInfo.Filename
  else UnitFilename:=BuildBoss.GetTestUnitFilename(ActiveUnitInfo);

{$ifdef VerboseDebugger}
  DebugLn('TDebugManager.DoStepToCursor C');
{$endif}
  FDebugger.StepTo(ExtractFilename(UnitFilename),
                  TSourceEditor(ActiveSrcEdit).EditorComponent.CaretY);

{$ifdef VerboseDebugger}
  DebugLn('TDebugManager.DoStepToCursor D');
{$endif}
  Result := mrOK;
end;

function TDebugManager.DoRunToCursor: TModalResult;
var
  ActiveSrcEdit: TSourceEditorInterface;
  ActiveUnitInfo: TUnitInfo;
  UnitFilename: string;
begin
  if (MainIDE.DoInitProjectRun <> mrOK)
  or (MainIDE.ToolStatus <> itDebugger)
  or (FDebugger = nil) or Destroying
  then begin
    Result := mrAbort;
    Exit;
  end;

  MainIDE.GetCurrentUnitInfo(ActiveSrcEdit,ActiveUnitInfo);
  if (ActiveSrcEdit=nil) or (ActiveUnitInfo=nil)
  then begin
    IDEMessageDialog(lisRunToFailed, lisPleaseOpenAUnitBeforeRun, mtError,
      [mbCancel]);
    Result := mrCancel;
    Exit;
  end;

  if not ActiveUnitInfo.Source.IsVirtual
  then UnitFilename:=ActiveUnitInfo.Filename
  else UnitFilename:=BuildBoss.GetTestUnitFilename(ActiveUnitInfo);

  FStepping:=True;
  FDebugger.RunTo(ExtractFilename(UnitFilename),
                  TSourceEditor(ActiveSrcEdit).EditorComponent.CaretY);

  Result := mrOK;
end;

function TDebugManager.GetState: TDBGState;
begin
  if FDebugger = nil
  then Result := dsNone
  else Result := FDebugger.State;
end;

function TDebugManager.GetCommands: TDBGCommands;
begin
  if FDebugger = nil
  then Result := []
  else Result := FDebugger.Commands;
end;

function TDebugManager.GetPseudoTerminal: TPseudoTerminal;
begin
  if FDebugger = nil then
    Result := nil
  else
    Result := FDebugger.PseudoTerminal;
end;

function TDebugManager.GetDebuggerClass: TDebuggerClass;
begin
  Result := EnvironmentOptions.CurrentDebuggerClass(Project1);
  if Result = nil then
    Result := TProcessDebugger;
end;

{$IFDEF DBG_WITH_DEBUGGER_DEBUG}
function TDebugManager.GetDebugger: TDebuggerIntf;
begin
  Result := FDebugger;
end;
{$ENDIF}

function TDebugManager.GetCurrentDebuggerClass: TDebuggerClass;
begin
  Result := GetDebuggerClass;
end;

function TDebugManager.AttachDebugger: TModalResult;
begin
  Result:=mrCancel;
  if Destroying then exit;
  Exclude(FManagerStates,dmsWaitForAttach);
  if dmsRunning in FManagerStates then exit;
  if MainIDE.ToolStatus<>itDebugger then exit;
  if (FDebugger <> nil) then
  begin
    // check if debugging needs restart
    if (dmsDebuggerObjectBroken in FManagerStates)
    and (MainIDE.ToolStatus=itDebugger) then begin
      MainIDE.ToolStatus:=itNone;
      Result:=mrCancel;
      exit;
    end;
    Include(FManagerStates,dmsRunning);
    FStepping:=False;
    try
      FDebugger.Attach(FAttachToID);
    finally
      Exclude(FManagerStates,dmsRunning);
    end;
    Result:=mrOk;
  end;
end;

function TDebugManager.ShowBreakPointProperties(const ABreakpoint: TIDEBreakPoint): TModalresult;
begin
  Result := TBreakPropertyDlg.Create(Self, ABreakpoint).ShowModal;
end;

function TDebugManager.ShowWatchProperties(const AWatch: TCurrentWatch; AWatchExpression: String = ''): TModalresult;
begin
  Result := TWatchPropertyDlg.Create(Self, AWatch, AWatchExpression).ShowModal;
end;

procedure TDebugManager.SetDebugger(const ADebugger: TDebuggerIntf);
begin
  if FDebugger = ADebugger then Exit;

  FRunTimer.Enabled:=false;
  Exclude(FManagerStates,dmsWaitForRun);
  Exclude(FManagerStates,dmsWaitForAttach);

  if FDebugger <> nil then begin
    FDebugger.OnBreakPointHit := nil;
    FDebugger.OnBeforeState   := nil;
    FDebugger.OnState         := nil;
    FDebugger.OnCurrent       := nil;
    FDebugger.OnDbgOutput     := nil;
    FDebugger.OnDbgEvent      := nil;
    FDebugger.OnException     := nil;
    FDebugger.OnConsoleOutput := nil;
    FDebugger.OnFeedback      := nil;
    FDebugger.OnIdle          := nil;
    FDebugger.Exceptions := nil;
    FDebugger.EventLogHandler := nil;
  end;

  FDebugger := ADebugger;
  if FDebugger = nil
  then begin
    TManagedBreakpoints(FBreakpoints).Master := nil;
    FWatches.Supplier := nil;
    FThreads.Supplier := nil;
    FLocals.Supplier := nil;
    FLineInfo.Master := nil;
    FCallStack.Supplier := nil;
    FDisassembler.Master := nil;
    FSignals.Master := nil;
    FRegisters.Supplier := nil;
    FSnapshots.Debugger := nil;
  end
  else begin
    TManagedBreakpoints(FBreakpoints).Master := FDebugger.BreakPoints;
    FWatches.Supplier := FDebugger.Watches;
    FThreads.Supplier := FDebugger.Threads;
    FThreads.UnitInfoProvider := FUnitInfoProvider;
    FLocals.Supplier := FDebugger.Locals;
    FLineInfo.Master := FDebugger.LineInfo;
    FCallStack.Supplier := FDebugger.CallStack;
    FCallStack.UnitInfoProvider := FUnitInfoProvider;
    FDisassembler.Master := FDebugger.Disassembler;
    FSignals.Master := FDebugger.Signals;
    FRegisters.Supplier := FDebugger.Registers;
    FSnapshots.Debugger := FDebugger;

    FDebugger.Exceptions := FExceptions;
  end;
end;

initialization
  DBG_LOCATION_INFO := DebugLogger.FindOrRegisterLogGroup('DBG_LOCATION_INFO' {$IFDEF DBG_LOCATION_INFO} , True {$ENDIF} );
  if DBG_LOCATION_INFO=nil then ;

end.



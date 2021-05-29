{  $Id$  }
{
 /***************************************************************************
                         basedebugmanager.pp
                         -------------------
 TBaseDebugManager is the base class for TDebugManager, which controls all
 debugging related stuff in the IDE. The base class is mostly abstract.


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
unit BaseDebugManager;

{$mode objfpc}{$H+}

interface

{$I ide.inc}

uses
{$IFDEF IDE_MEM_CHECK}
  MemCheck,
{$ENDIF}
  Classes, SysUtils,
  // LCL
  Forms,
  // LazUtils
  Laz2_XMLCfg,
  // IdeIntf
  IDEOptionsIntf, IDEOptEditorIntf,
  // DebuggerIntf
  DbgIntfBaseTypes, DbgIntfDebuggerBase, DbgIntfPseudoTerminal,
  // IDE
  Debugger, SourceMarks, Project, ProjectDefs, LazarusIDEStrConsts;

type
  TDebugDialogType = (
    ddtOutput,
    ddtEvents,
    ddtBreakpoints,
    ddtWatches,
    ddtLocals,
    ddtCallStack,
    ddtEvaluate,
    ddtRegisters,
    ddtAssembler,
    ddtInspect,
    ddtPseudoTerminal,
    ddtThreads,
    ddtHistory
    );

const
  // used as ID for layout storage.
  // Do not change. Do not translate
  DebugDialogNames: array [TDebugDialogType] of string = (
    'DbgOutput',
    'DbgEvents',
    'BreakPoints',
    'Watches',
    'Locals',
    'CallStack',
    'EvaluateModify',
    'Registers',
    'Assembler',
    'Inspect',
    'PseudoTerminal',
    'Threads',
    'DbgHistory'
    );

type

  { TBaseDebugManager }
  
  TDebugManagerState = (
    dmsInitializingDebuggerObject,
    dmsInitializingDebuggerObjectFailed,
    dmsDebuggerObjectBroken,  // the debugger entered the error state
    dmsWaitForRun, // waiting for call to RunDebugger, set by StartDebugging
    dmsWaitForAttach,
    dmsRunning  // set by RunDebugger
    );
  TDebugManagerStates = set of TDebugManagerState;

  TDbgInitFlag = (difInitForAttach);
  TDbgInitFlags = set of TDbgInitFlag;

  { TDebuggerOptions }

  TDebuggerOptions = class(TAbstractIDEEnvironmentOptions)
  public
    class function GetGroupCaption:string; override;
    class function GetInstance: TAbstractIDEOptions; override;
  end;

  TBaseDebugManager = class(TBaseDebugManagerIntf)
  protected
    FDestroying: boolean;
    FCallStack: TIdeCallStackMonitor;
    FDisassembler: TIDEDisassembler;
    FExceptions: TIDEExceptions;
    FSignals: TIDESignals;
    FBreakPoints: TIDEBreakPoints;
    FBreakPointGroups: TIDEBreakPointGroups;
    FLocals: TIdeLocalsMonitor;
    FLineInfo: TIDELineInfo;
    FWatches: TIdeWatchesMonitor;
    FThreads: TIdeThreadsMonitor;
    FRegisters: TIdeRegistersMonitor;
    FSnapshots: TSnapshotManager;
    FManagerStates: TDebugManagerStates;
    function  GetState: TDBGState; virtual; abstract;
    function  GetCommands: TDBGCommands; virtual; abstract;
    function GetPseudoTerminal: TPseudoTerminal; virtual; abstract;
    {$IFDEF DBG_WITH_DEBUGGER_DEBUG}
    function GetDebugger: TDebuggerIntf; virtual; abstract;
    {$ENDIF}
    function GetCurrentDebuggerClass: TDebuggerClass; virtual; abstract;    (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834   *)
  public
    procedure Reset; virtual; abstract;

    procedure ConnectMainBarEvents; virtual; abstract;
    procedure ConnectSourceNotebookEvents; virtual; abstract;
    procedure SetupMainBarShortCuts; virtual; abstract;
    procedure SetupSourceMenuShortCuts; virtual; abstract;
    procedure UpdateButtonsAndMenuItems; virtual; abstract;
    procedure UpdateToolStatus; virtual; abstract;
    procedure EnvironmentOptsChanged; virtual; abstract;

    procedure LoadProjectSpecificInfo(XMLConfig: TXMLConfig;
                                      Merge: boolean); virtual; abstract;
    procedure SaveProjectSpecificInfo(XMLConfig: TXMLConfig;
                                      Flags: TProjectWriteFlags); virtual; abstract;


    procedure DoRestoreDebuggerMarks(AnUnitInfo: TUnitInfo); virtual; abstract;

    function RequiredCompilerOpts(ATargetCPU, ATargetOS: String): TDebugCompilerRequirements; virtual; abstract;
    function InitDebugger(AFlags: TDbgInitFlags = []): Boolean; virtual; abstract;
    
    function DoPauseProject: TModalResult; virtual; abstract;
    function DoShowExecutionPoint: TModalResult; virtual; abstract;
    function DoStepIntoProject: TModalResult; virtual; abstract;
    function DoStepOverProject: TModalResult; virtual; abstract;
    function DoStepOutProject: TModalResult; virtual; abstract;
    function DoStepIntoInstrProject: TModalResult; virtual; abstract;
    function DoStepOverInstrProject: TModalResult; virtual; abstract;
    function DoStepToCursor: TModalResult; virtual; abstract;
    function DoRunToCursor: TModalResult; virtual; abstract;
    function DoStopProject: TModalResult; virtual; abstract;
    procedure DoToggleCallStack; virtual; abstract;
    procedure DoSendConsoleInput(AText: String); virtual; abstract;
    procedure ProcessCommand(Command: word; var Handled: boolean); virtual; abstract;

    procedure LockCommandProcessing; virtual; abstract;
    procedure UnLockCommandProcessing; virtual; abstract;

    function StartDebugging: TModalResult; virtual; abstract; // set ToolStatus to itDebugger, but do not run debugger yet
    function RunDebugger: TModalResult; virtual; abstract; // run program, wait until program ends
    procedure EndDebugging; virtual; abstract;

    procedure Attach(AProcessID: String); virtual; abstract;
    procedure Detach; virtual; abstract;
    function FillProcessList(AList: TRunningProcessInfoList): boolean; virtual; abstract;

    function Evaluate(const AExpression: String; ACallback: TDBGEvaluateResultCallback;
                      EvalFlags: TDBGEvaluateFlags = []): Boolean; virtual; abstract; // Evaluates the given expression, returns true if valid
    function Modify(const AExpression: String; const ANewValue: String): Boolean; virtual; abstract; // Modify the given expression, returns true if valid

    function GetFullFilename(const AUnitinfo: TDebuggerUnitInfo;
                             out Filename: string; AskUserIfNotFound: Boolean): Boolean; virtual; abstract;
    function GetFullFilename(var Filename: string; AskUserIfNotFound: Boolean): Boolean; virtual; abstract;

    procedure EvaluateModify(const AExpression: String); virtual; abstract;
    procedure Inspect(const AExpression: String); virtual; abstract;

    function DoCreateBreakPoint(const AFilename: string; ALine: integer;
                                WarnIfNoDebugger: boolean): TModalResult; virtual; abstract;
    function DoCreateBreakPoint(const AFilename: string; ALine: integer;
                                WarnIfNoDebugger: boolean;
                                out ABrkPoint: TIDEBreakPoint;
                                AnUpdating: Boolean = False): TModalResult; virtual; abstract;
    function DoCreateBreakPoint(const AnAddr: TDBGPtr;
                                WarnIfNoDebugger: boolean;
                                out ABrkPoint: TIDEBreakPoint;
                                AnUpdating: Boolean = False): TModalResult; virtual; abstract;
    function DoDeleteBreakPoint(const AFilename: string; ALine: integer
                                ): TModalResult; virtual; abstract;
    function DoDeleteBreakPointAtMark(const ASourceMark: TSourceMark
                                     ): TModalResult; virtual; abstract;

    function ShowBreakPointProperties(const ABreakpoint: TIDEBreakPoint): TModalresult; virtual; abstract;
    function ShowWatchProperties(const AWatch: TCurrentWatch; AWatchExpression: String = ''): TModalresult; virtual; abstract;

    // Dialog routines
    procedure CreateDebugDialog(Sender: TObject; aFormName: string;
                          var AForm: TCustomForm; DoDisableAutoSizing: boolean); virtual; abstract;
    procedure ViewDebugDialog(const ADialogType: TDebugDialogType;
                              BringToFront: Boolean = True; Show: Boolean = true;
                              DoDisableAutoSizing: boolean = false); virtual; abstract;
    procedure ViewDisassembler(AnAddr: TDBGPtr;
                              BringToFront: Boolean = True; Show: Boolean = true;
                              DoDisableAutoSizing: boolean = false); virtual; abstract;
  public
    property Commands: TDBGCommands read GetCommands;  // All current available commands of the debugger
    property Destroying: boolean read FDestroying;
    property State: TDBGState read GetState;           // The current state of the debugger

    property BreakPoints: TIDEBreakPoints read FBreakpoints;   // A list of breakpoints for the current project
    property BreakPointGroups: TIDEBreakPointGroups read FBreakPointGroups;
    property Exceptions: TIDEExceptions read FExceptions;      // A list of exceptions we should ignore
    property CallStack: TIdeCallStackMonitor read FCallStack;
    property Disassembler: TIDEDisassembler read FDisassembler;
    property Locals: TIdeLocalsMonitor read FLocals;
    property LineInfo: TIDELineInfo read FLineInfo;
    property Registers: TIdeRegistersMonitor read FRegisters;
    property Signals: TIDESignals read FSignals;               // A list of actions for signals we know of
    property Watches: TIdeWatchesMonitor read FWatches;
    property Threads: TIdeThreadsMonitor read FThreads;
    property Snapshots: TSnapshotManager read FSnapshots;
    property PseudoTerminal: TPseudoTerminal read GetPseudoTerminal; experimental; // 'may be replaced with a more general API';
    (* TODO: workaround for http://bugs.freepascal.org/view.php?id=21834   *)
    property DebuggerClass: TDebuggerClass read GetCurrentDebuggerClass;
    {$IFDEF DBG_WITH_DEBUGGER_DEBUG}
    property Debugger: TDebuggerIntf read GetDebugger;
    {$ENDIF}
  end;


var
  DebugBoss: TBaseDebugManager;
  DebuggerOptions: TDebuggerOptions = nil;

implementation

{ TDebuggerOptions }

class function TDebuggerOptions.GetGroupCaption: string;
begin
  Result := dlgGroupDebugger;
end;

class function TDebuggerOptions.GetInstance: TAbstractIDEOptions;
begin
  Result := DebuggerOptions;
end;

initialization
  RegisterIDEOptionsGroup(GroupDebugger, TDebuggerOptions);
  DebugBoss := nil;

end.




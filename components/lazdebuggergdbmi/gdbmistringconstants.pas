unit GdbmiStringConstants;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

resourcestring
  gdbmiErrorOnRunCommand = 'The debugger encountered an error when trying to '
    + 'run/step the application:%0:s%0:s%1:s%0:s%0:s'
    + 'Press "Ok" to continue debugging (paused), '
    + 'and correct the problem, or choose an alternative run command.%0:s'
    + 'Press "Stop" to end the debug session.';
  gdbmiErrorOnRunCommandWithWarning = '%0:s%0:sIn addition to the error the following '
    + 'warning was encountered:%0:s%0:s%1:s';
  gdbmiBreakPointErrorOnRunCommand = 'The debugger encountered an error when trying to '
    + 'run/step the application:%0:s%0:s%1:s%0:s%0:s'
    + 'Press "Ok" to remove the breakpoints and continue debugging (paused), '
    + 'and correct the problem, or choose an alternative run command.%0:s'
    + 'Press "Stop" to end the debug session.';
  gdbmiTimeOutForCmd = 'Time-out for command: "%s"';
  gdbmiFatalErrorOccurred = 'Unrecoverable error: "%s"';
  gdbmiErrorStateGenericInfo = 'Error in: %1:s %0:s';
  gdbmiErrorStateInfoCommandError =
      '%0:sThe GDB command:%0:s"%1:s"%0:sreturned the error:%0:s"%2:s"%0:s';
  gdbmiErrorStateInfoCommandNoResult =
      '%0:sThe GDB command:%0:s"%1:s"%0:sdid not return any result.%0:s';
  gdbmiErrorStateInfoFailedWrite = '%0:sCould not send a command to GDB.%0:s';
  gdbmiErrorStateInfoFailedRead = '%0:sCould not read output from GDB.%0:s';
  gdbmiErrorStateInfoGDBGone = '%0:sThe GDB process is no longer running.%0:s';
  gdbmiWarningUnknowBreakPoint = 'The debugger reached an unexpected %1:s%0:s%0:s'
    + 'Press "Ok" to continue debugging (paused).%0:s'
    + 'Press "Stop" to end the debug session.';
  gdbmiTheDebuggerExperiencedAnUnknownCondition = 'The debugger experienced an'
    +' unknown condition';
  gdbmiPressIgnoreToContinueDebuggingThisMayNOTBeSafePres = 'Press "Ignore" to'
    +' continue debugging. This may NOT be safe. Press "Abort" to stop the '
    +'debugger.%0:sException: %1:s with message "%2:s"%0:sContext: %4:s. State'
    +': %5:s %0:s%0:s%3:s';
  gdbmiCommandStartMainBreakError = 'The debugger could not set a breakpoint on'
    + ' the application''s entry point.%0:s'
    + 'This may be caused by missing debug info.';
  gdbmiCommandStartMainRunError = 'The debugger could not run the application.%0:s'
    + 'This may be caused by missing debug info.';
  gdbmiCommandStartMainRunToStopError = 'The debugger was unable to initialize itself.%0:s'
    + 'The application did run (and terminated) before the debugger could set'
    + ' any breakpoints. %0:s'
    + 'This may be caused by missing debug info.';
  gdbmiCommandStartMainRunNoPIDError = 'The debugger failed to get the application''s PID.%0:s'
    + 'This may be caused by missing debug info.';
  gdbmiGDBInternalError = 'GDB has encountered an internal error: %0:sPress "Ok" to continue '
    +'debugging. This may NOT be safe.%0:sPress "Stop" to end the debug session.';
  gdbmiGDBInternalErrorInfo = 'While executing the command: %0:s"%2:s"%0:sgdb reported:%0:s"%'
    +'1:s"%0:s';
  gdbmiEventLogGDBInternalError = 'GDB has encountered an internal error: %s';
  gdbmiEventLogNoSymbols = 'File ''%s'' has no debug symbols';
  gdbmiEventLogProcessStart = 'Process Start: %s';
  gdbmiEventLogDebugOutput = 'Debug Output: %s';
  gdbmiEventLogProcessExitNormally = 'Process Exit: normally';
  gdbmiEventLogProcessExitCode = 'Process Exit: %s';
  gdbmiFailedToLaunchExternalDbg = 'Failed to create process for GDB';
  gdbmiFailedToTerminateGDBTitle = 'GDB did not terminate';
  gdbmiFailedToTerminateGDB = 'The IDE was unable to terminate the GDB process. '
    + 'This process may be left running outside the control of IDE.%0:s'
    + 'To ensure the process is not affecting your System, you should locate '
    + 'and terminate it yourself.';


  lisNewTheGNUDebuggerThroughSshAllowsToRemoteDebugViaASsh =
      'The GNU debugger '
    +'through SSH allows to remote debug via a SSH connection. See docs/'
    +'RemoteDebugging.txt for details. The path must contain the SSH client. '
    +'Use SSH_Startup_Options for the hostname and optional username. '
    +'Use Remote_GDB_Exe for the filename of GDB on the remote computer.';
  lisUnexpectedResultTheDebuggerWillTerminate = 'Unexpected result:%sThe '
    +'debugger will terminate';
  lisResponseContinue = 'Response: %sContinue ?';
  dlgGroupDebugger = 'Debugger';
  synfFailedToLoadApplicationExecutable = 'Failed to load application executable';
  synfFailedToInitializeTheDebuggerSetPascalFailed = 'Failed to initialize the debugger (set '
    +'pascal failed)';
  synfFailedToInitializeDebugger = 'Failed to initialize debugger';

implementation

end.


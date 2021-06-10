{ $Id$ }
{                        ----------------------------------------------  
                         CMDLineDebugger.pp  -  Debugger class for 
                                                commandline debuggers
                         ---------------------------------------------- 
 
 @created(Wed Feb 28st WET 2001)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@lazarus.dommelstein.net>)                       

 This unit contains the Commandline debugger class for external commandline
 debuggers.
 
 
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
unit CmdLineDebugger;

{$mode objfpc}
{$H+}

interface

uses
  Classes, Types, process,
  // LCL
  Forms,
  // LazUtils
  LazLoggerBase, UTF8Process,
  // DebuggerIntf
  DbgIntfDebuggerBase,
  // LazDebuggerGdbmi
  DebugUtils;

type

  { TCmdLineDebugger }

  TCmdLineDebugger = class(TDebuggerIntf)
  private
    {$IFdef MSWindows}
    FAggressiveWaitTime: Cardinal;
    FLastWrite: QWord;
    {$EndIf}
    FDbgProcess: TProcessUTF8;   // The process used to call the debugger
    FLineEnds: TStringDynArray;  // List of strings considered as lineends
    FOutputBuf: String;
    FReading: Boolean;       // Set if we are in the ReadLine loop
    FFlushAfterRead: Boolean;// Set if we should flush after finished reading
    FPeekOffset: Integer;    // Count the number of lines we have peeked
    FReadLineTimedOut, FReadLineWasAbortedByNested: Boolean;
    FReadLineCallStamp: Int64;
    function WaitForHandles(const AHandles: array of Integer; var ATimeOut: Integer): Integer; overload;
    function WaitForHandles(const AHandles: array of Integer): Integer; overload;
  protected
    procedure DoReadError; virtual;
    procedure DoWriteError; virtual;
    function GetDebugProcessRunning: Boolean; virtual;
    procedure ProcessWhileWaitForHandles; virtual;
    function  CreateDebugProcess(const AOptions: String): Boolean; virtual;
    procedure Flush;                                   // Flushes output buffer
    function  GetWaiting: Boolean; override;
    function  LineEndPos(const {%H-}s: string; out LineEndLen: integer): integer; virtual;
    function  ReadLine(ATimeOut: Integer = -1): String; overload;
    function  ReadLine(const APeek: Boolean; ATimeOut: Integer = -1): String; virtual; overload;
    procedure SendCmdLn(const ACommand: String); virtual; overload;
    procedure SendCmdLn(const ACommand: String; Values: array of const); overload;
    procedure SetLineEnds(ALineEnds: TStringDynArray);
    function  ReadLineTimedOut: Boolean; virtual;
    property  ReadLineWasAbortedByNested: Boolean read FReadLineWasAbortedByNested;
    procedure AbortReadLine;
  public
    constructor Create(const AExternalDebugger: String); override;
    destructor Destroy; override;
    procedure TestCmd(const ACommand: String); override;// For internal debugging purposes
  public
    property DebugProcess: TProcessUTF8 read FDbgProcess;
    property DebugProcessRunning: Boolean read GetDebugProcessRunning;
    {$IFdef MSWindows}
    property AggressiveWaitTime: Cardinal read FAggressiveWaitTime write FAggressiveWaitTime;
    {$EndIf}
  end;


implementation

//////////////////////////////////////////////////
//       Needs to go to proper include
//          Platform dependent
//////////////////////////////////////////////////

uses
  LCLIntf,
{$IFdef MSWindows}
  Windows,
{$ENDIF}
{$IFDEF UNIX}
   Unix,BaseUnix,
{$ENDIF}
  SysUtils;

var
  DBG_CMD_ECHO, DBG_CMD_ECHO_FULL: PLazLoggerLogGroup;

{------------------------------------------------------------------------------
  Function: WaitForHandles
  Params:  AHandles:              A set of handles to wait for (max 32)
  TimeOut: Max Time in milli-secs => set to 0 if timeout occurred
  Returns: BitArray of handles set, 0 when an error occoured
 ------------------------------------------------------------------------------}
function TCmdLineDebugger.WaitForHandles(const AHandles: array of Integer; var ATimeOut: Integer): Integer;
{$IFDEF UNIX}
const
  IDLE_STEP_COUNT=50;
var
  n, R, Max, Count: Integer;
  TimeOut: Integer;
  FDSWait, FDS: TFDSet;
  Step: Integer;
  t, t2, t3: QWord;
  CurCallStamp: Int64;
begin
  Result := 0;
  CurCallStamp := FReadLineCallStamp;
  Max := 0;
  Count := High(AHandles);
  if Count < 0 then Exit;
  if Count > 31 then Count := 31;
  
  // zero the whole bit set of handles
  FpFD_ZERO(FDS);

  // set bits for all waiting handles
  for n := 0 to Count do   
  begin
    if AHandles[n] < 0 then
      continue;
    if Max < AHandles[n] + 1 then Max := AHandles[n] + 1;
    FpFD_Set(AHandles[n], FDS);
  end;
  if Max=0 then begin
    // no valid handle, so no change possible
    DebugLn('WaitForHandles: Error: no handles');
    exit;
  end;

  if ATimeOut > 0
  then t := GetTickCount64;

  // wait for all handles
  Step:=IDLE_STEP_COUNT-1;
  repeat
    FDSWait := FDS;
    TimeOut := 10;
    // Select:
    // R = -1 on error, 0 on timeout, >0 on success and is number of handles
    // FDSWait is changed, and indicates what descriptors have changed
    R := FpSelect(Max, @FDSWait, nil, nil, TimeOut);

    if CurCallStamp <> FReadLineCallStamp then
      exit;

    if (ATimeOut > 0) then begin
      t2 := GetTickCount64;
      if t2 < t
      then t3 := t2 + (High(t) - t)
      else t3 := t2 - t;
      if (t3 >= ATimeOut)
      then begin
        ATimeOut := 0;
        break;
      end
      else begin
        ATimeOut := ATimeOut - t3;
        t := t2;
      end;
    end;

    ProcessWhileWaitForHandles;
    inc(Step);
    if Step=IDLE_STEP_COUNT then begin
      Step:=0;
      Application.Idle(false);
    end;
    try
      Application.ProcessMessages;
    except
      Application.HandleException(Application);
    end;
    if Application.Terminated then Break;
  until R <> 0;

  // set bits for all changed handles
  if R > 0 
  then begin
    for n := 0 to Count do   
      if  (AHandles[n] >= 0)
      and (FpFD_ISSET(AHandles[n],FDSWait)=1)
      then begin
        Result := Result or 1 shl n;
        Dec(R);
        if R=0 then Break;
      end;
  end;
end;
{$ELSE linux}
{$IFdef MSWindows}
const
  IDLE_STEP_COUNT = 20;
var
  PipeHandle: Integer;
  TotalBytesAvailable: dword;
  R: LongBool;
  n: integer;
  Step, FullTimeOut: Integer;
  t, t2, t3: QWord;
  CurCallStamp: Int64;
begin
  Result := 0;
  CurCallStamp := FReadLineCallStamp;
  Step:=IDLE_STEP_COUNT-1;
  //if ATimeOut > 0
  //then
  t := GetTickCount64;
  FullTimeOut := ATimeOut;

  while Result=0 do
  begin
    for n:= 0 to High(AHandles) do
    begin
      PipeHandle := AHandles[n];
      R := Windows.PeekNamedPipe(PipeHandle, nil, 0, nil, @TotalBytesAvailable, nil);
      if not R then begin
        // PeekNamedPipe failed
        DebugLn('PeekNamedPipe failed, GetLastError is ', IntToStr(GetLastError));
        Exit;
      end;
      if R then begin
        // PeekNamedPipe successfull
        if (TotalBytesAvailable>0) then begin
          Result := 1 shl n;
          Break;
        end;
      end;
    end;

    if CurCallStamp <> FReadLineCallStamp then
      exit;

    t2 := GetTickCount64;
    if (FullTimeOut > 0) then begin
      if t2 < t
      then t3 := t2 + (High(t) - t)
      else t3 := t2 - t;
      if (t3 >= FullTimeOut)
      then begin
        ATimeOut := 0;
        break;
      end
      else begin
        ATimeOut := FullTimeOut - t3;
      end;
    end;

    {$IFdef MSWindows}
    if t2 < FLastWrite
    then t3 := t2 + (High(FLastWrite) - FLastWrite)
    else t3 := t2 - FLastWrite;
    if (t3 > FAggressiveWaitTime) or (FAggressiveWaitTime = 0) then begin
    {$EndIf}
      ProcessWhileWaitForHandles;
      // process messages
      inc(Step);
      if Step=IDLE_STEP_COUNT then begin
        Step:=0;
        Application.Idle(false);
      end;
      try
        Application.ProcessMessages;
      except
        Application.HandleException(Application);
      end;
      if Application.Terminated or not DebugProcessRunning then Break;
      // sleep a bit
      Sleep(10);
    {$IFdef MSWindows}
    end
    else
    if t3 div 64 > Step then begin
      ProcessWhileWaitForHandles;
      inc(Step);
      try
        Application.ProcessMessages;
      except
        Application.HandleException(Application);
      end;
    end;
    {$EndIf}

  end;
  {$IFdef MSWindows}
  if Step = IDLE_STEP_COUNT-1 then begin
    ProcessWhileWaitForHandles;
    Application.Idle(false);
    try
      Application.ProcessMessages;
    except
      Application.HandleException(Application);
    end;
  end;
  {$EndIf}
end;
{$ELSE win32}
begin
  DebugLn('ToDo: implement WaitForHandles for this OS');
  Result := 0;
end;
{$ENDIF win32}
{$ENDIF linux}

function TCmdLineDebugger.WaitForHandles(const AHandles: array of Integer): Integer; overload;
var
  t: Integer;
begin
  t := -1;
  Result := WaitForHandles(AHandles, t);
end;

procedure TCmdLineDebugger.DoReadError;
begin
  SetState(dsError);
end;

procedure TCmdLineDebugger.DoWriteError;
begin
  SetState(dsError);
end;

procedure TCmdLineDebugger.ProcessWhileWaitForHandles;
begin
  // nothing
end;

//////////////////////////////////////////////////

{ TCmdLineDebugger }

constructor TCmdLineDebugger.Create(const AExternalDebugger: String);
begin
  FDbgProcess := nil;
  SetLength(FLineEnds, 1);
  FLineEnds[0] := LineEnding;
  FReading := False;
  FFlushAfterRead := False;
  FPeekOffset := 0;
  inherited;
end;

function TCmdLineDebugger.CreateDebugProcess(const AOptions: String): Boolean;
begin
  Result := False;
  if FDbgProcess = nil
  then begin
    FDbgProcess := TProcessUTF8.Create(nil);
    try
      FDbgProcess.ParseCmdLine(ExternalDebugger + ' ' + AOptions);
      FDbgProcess.Options:= [poUsePipes, {$IF DECLARED(poDetached)}poDetached{$ELSE}poNoConsole{$ENDIF}, poStdErrToOutPut, poNewProcessGroup];
      {$if defined(windows) and not defined(wince)}
      // under win9x and winMe should be created with console,
      // otherwise no break can be sent.
      if Win32MajorVersion <= 4 then
        FDbgProcess.Options:= [poUsePipes, poNewConsole, poStdErrToOutPut, poNewProcessGroup];
      {$endif windows}
      FDbgProcess.ShowWindow := swoNone;
      FDbgProcess.Environment:=DebuggerEnvironment;
      FDbgProcess.PipeBufferSize:=64*1024;
    except
      FreeAndNil(FDbgProcess);
    end;
  end;
  if FDbgProcess = nil then exit;

  if not FDbgProcess.Running
  then begin
    try
      FDbgProcess.Execute;
      DebugLn('[TCmdLineDebugger] Debug PID: ', IntToStr(FDbgProcess.Handle));
      Result := FDbgProcess.Running;
    except
      on E: Exception do begin
        FOutputBuf := E.Message;
        DebugLn('Exception while executing debugger: ', FOutputBuf);
      end;
    end;
  end;
end;

destructor TCmdLineDebugger.Destroy;
begin
  if (FDbgProcess <> nil) and (FDbgProcess.Running)
  then FDbgProcess.Terminate(0); //TODO: set state ?
  
  inherited;
  
  try
    FreeAndNil(FDbgProcess);
  except
    on E: Exception do DebugLn('Exception while freeing debugger: ', E.Message);
  end;
end;

procedure TCmdLineDebugger.Flush;
begin
  if FReading
  then FFlushAfterRead := True
  else FOutputBuf := '';
end;

function TCmdLineDebugger.GetDebugProcessRunning: Boolean;
begin
  Result := (FDbgProcess <> nil) and FDbgProcess.Running;
end;

function TCmdLineDebugger.GetWaiting: Boolean;
begin
  Result := FReading;
end;

function TCmdLineDebugger.LineEndPos(const s: string; out LineEndLen: integer): integer;
var
  n, idx: Integer;
begin
  Result := 0;
  LineEndLen := 0;
  for n := Low(FLineEnds) to High(FLineEnds) do
  begin
    idx := Pos(FLineEnds[n], FOutputBuf);
    if (idx > 0) and ( (idx < Result) or (Result = 0) )
    then begin
      Result := idx;
      LineEndLen := length(FLineEnds[n]);
    end;
  end;
end;

function TCmdLineDebugger.ReadLine(ATimeOut: Integer = -1): String;
begin
  Result := ReadLine(False, ATimeOut);
end;

function TCmdLineDebugger.ReadLine(const APeek: Boolean; ATimeOut: Integer = -1): String;

  function ReadData(const AStream: TStream; var ABuffer: String): Integer;
  const READ_LEN = 32*1024;
  var
    S: String;
  begin
    SetLength(S, READ_LEN);
    Result := AStream.Read(S[1], READ_LEN);
    if Result > 0
    then begin
      SetLength(S, Result);
      ABuffer := ABuffer + S;
    end;
  end;

var   
  WaitSet: Integer;
  {%H-}LineEndMatch: String;
  LineEndIdx, LineEndLen, PeekCount: Integer;
  CurCallStamp: Int64;
begin
//  WriteLN('[TCmdLineDebugger.GetOutput] Enter');

// TODO: get extra handles to wait for
// TODO: Fix multiple peeks
  Result := '';
  if not DebugProcessRunning then begin
    if FOutputBuf <> '' then begin
      Result := FOutputBuf;
      FOutputBuf := '';
      exit;
    end;
    DoReadError;
    exit;
  end;

  FReadLineTimedOut := False;
  FReadLineWasAbortedByNested := False;
  if FReadLineCallStamp = high(FReadLineCallStamp) then
    FReadLineCallStamp := low(FReadLineCallStamp)
  else
    inc(FReadLineCallStamp);
  CurCallStamp := FReadLineCallStamp;

  if not APeek
  then FPeekOffset := 0;
  FReading := True;
  PeekCount := 0;
  repeat                       
    if FOutputBuf <> ''
    then begin
      LineEndIdx := LineEndPos(FOutputBuf, LineEndLen);

      if LineEndIdx > 0
      then begin
        Dec(LineEndIdx);
        Result := Copy(FOutputBuf, 1, LineEndIdx);
        if APeek 
        then begin
          if PeekCount = FPeekOffset
          then Inc(FPeekOffset)
          else begin
            Inc(PeekCount);
            Continue;
          end;
        end
        else Delete(FOutputBuf, 1, LineEndIdx + LineEndLen);
      
        DoDbgOutput(Result);
        Break;
      end;
    end;

    if FReadLineTimedOut
    then break;
    if FDbgProcess.Output = nil then begin
      DoReadError;
      break;
    end;

    WaitSet := WaitForHandles([FDbgProcess.Output.Handle], ATimeOut);

    if CurCallStamp <> FReadLineCallStamp then begin
      // nested call: return empty, even if data exists
      FReadLineWasAbortedByNested := True; // this is true for all outer calls too.
      break;
    end;

    if (ATimeOut = 0)
    then FReadLineTimedOut := True;


    if (WaitSet = 0) and not FReadLineTimedOut
    then begin
      SmartWriteln('[TCmdLineDebugger.Getoutput] Error waiting ');
      DoReadError;
      Break;
    end;

    if  ((WaitSet and 1) <> 0)
    and DebugProcessRunning
    and (ReadData(FDbgProcess.Output, FOutputBuf) > 0) 
    then Continue; // start lineend search

(*
    if ((WaitSet and 2) <> 0) and (FTargetProcess <> nil)
    then begin
      Count := ReadData(FTargetProcess.Output, FTargetOutputBuf);
      if Count > 0
      then while True do
      begin
        Line := StripLN(GetLine(FTargetOutputBuf));
        if Line = '' then Break;
        DoOutput(Line); 
      end;
    end;
*)
  {$IFDEF VerboseIDEToDo}{$message warning condition should also check end-of-file reached for process output stream}{$ENDIF}
  until not DebugProcessRunning and (Length(FOutputBuf) = 0); 

  FReading := False;
  if FFlushAfterRead 
  then FOutputBuf := '';
  FFlushAfterRead := False;

  if not( FReadLineTimedOut and (Result = '') ) then begin
    if ((DBG_CMD_ECHO_FULL <> nil) and (DBG_CMD_ECHO_FULL^. Enabled))
    then debugln(DBG_CMD_ECHO_FULL, '<< TCmdLineDebugger.ReadLn "',Result,'"')
    else if (length(Result) < 300)
    then debugln(DBG_CMD_ECHO, '<< TCmdLineDebugger.ReadLn "',Result,'"')
    else debugln(DBG_CMD_ECHO, ['<< TCmdLineDebugger.ReadLn "',copy(Result, 1, 200), '" ..(',length(Result)-250,').. "',copy(Result, length(Result)-99, 100),'"']);
  end;
end;

procedure TCmdLineDebugger.SendCmdLn(const ACommand: String); overload;
var
  LE: string[2];
begin
  if (DBG_CMD_ECHO_FULL <> nil) and (DBG_CMD_ECHO_FULL^.Enabled)
  then debugln(DBG_CMD_ECHO_FULL, '>> TCmdLineDebugger.SendCmdLn "',ACommand,'"')
  else debugln(DBG_CMD_ECHO,      '>> TCmdLineDebugger.SendCmdLn "',ACommand,'"');

  if DebugProcessRunning
  then begin
    DoDbgOutput('<' + ACommand + '>');
    if ACommand <> ''
    then FDbgProcess.Input.Write(ACommand[1], Length(ACommand));
    // store LineEnding in local variable, so the same statement can be used
    // for windows and *nix (1 or 2 character line ending)
    LE := LineEnding;
    FDbgProcess.Input.Write(LE[1], Length(LE));
    {$IFdef MSWindows}
    FLastWrite := GetTickCount64;
    {$EndIf}
  end
  else begin
    DebugLn('[TCmdLineDebugger.SendCmdLn] Unable to send <', ACommand, '>. No process running.');
    DoWriteError;
  end;
end;

procedure TCmdLineDebugger.SendCmdLn(const ACommand: String; Values: array of const);
begin
  SendCmdLn(Format(ACommand, Values));
end;

procedure TCmdLineDebugger.SetLineEnds(ALineEnds: TStringDynArray);
begin
  if Length(ALineEnds) = 0
  then begin
    SetLength(FLineEnds, 1);
    FLineEnds[0] := LineEnding;
  end
  else FLineEnds := ALineEnds;
end;

function TCmdLineDebugger.ReadLineTimedOut: Boolean;
begin
  Result := FReadLineTimedOut;
end;

procedure TCmdLineDebugger.AbortReadLine;
begin
  inc(FReadLineCallStamp);
end;

procedure TCmdLineDebugger.TestCmd(const ACommand: String);
begin
  SendCmdLn(ACommand);
end;

initialization
  DBG_CMD_ECHO      := DebugLogger.FindOrRegisterLogGroup('DBG_CMD_ECHO' {$IF defined(DBG_VERBOSE) or defined(DBG_CMD_ECHO)} , True {$ENDIF} );
  DBG_CMD_ECHO_FULL := DebugLogger.FindOrRegisterLogGroup('DBG_CMD_ECHO_FULL' {$IF defined(DBG_VERBOSE_FULL_DATA) or defined(DBG_CMD_ECHO_FULL)} , True {$ENDIF} );

end.

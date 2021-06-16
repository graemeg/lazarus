{
 *****************************************************************************
  This file is part of LazUtils.

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Initial Revision  : Tue Dec 06 09:00:00 CET 2005
}

unit UTF8Process;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process,
  FileUtil, LazFileUtils, LazUTF8, LazUtilsStrConsts;

  {$IF DEFINED(MSWINDOWS) AND NOT DECLARED(poDetached)} // we need to work around the poNoConsole->poDetached change
    // more info: issue #32055, #35991; FPC r45228, https://forum.lazarus.freepascal.org/index.php/topic,49631.0
    {$DEFINE UseTProcessW}
  {$ENDIF}

{ TProcessUTF8 }

{$IFDEF UseTProcessW}
{$Optimization -ORDERFIELDS }
const
  SNoCommandLine        = 'Cannot execute empty command-line';
  SErrCannotExecute     = 'Failed to execute %s : %d';
type
  TProcessUTF8 = class(TProcess)
  protected
    procedure SetProcessHandle(aProcessHandle : THandle);
    procedure SetThreadHandle(aThreadHandle : THandle);
    procedure SetProcessID(aProcessID : Integer);
  public
    procedure Execute; override;
    procedure ParseCmdLine(const CmdLine: string; ReadBackslash: boolean = false);
  end;

{$ELSE}

type
  TProcessUTF8 = class(TProcess)
  public
    procedure ParseCmdLine(const CmdLine: string; ReadBackslash: boolean = false);
  end;
{$ENDIF}

procedure RunCmdFromPath(const ProgramFilename, CmdLineParameters: string);
function FindFilenameOfCmd(ProgramFilename: string): string;

function GetSystemThreadCount: integer; // guess number of cores

procedure Register;

implementation

{$IF defined(windows)}
uses Windows
  {$IFDEF UseTProcessW}
  ,pipes
  {$ENDIF}
;
{$ELSEIF defined(freebsd) or defined(darwin)}
uses ctypes, sysctl;
{$ELSEIF defined(linux)}
{$linklib c}
uses ctypes;
{$ENDIF}

{$IFDEF Linux}
const _SC_NPROCESSORS_ONLN = 83;
function sysconf(i: cint): clong; cdecl; external name 'sysconf';
{$ENDIF}

function GetSystemThreadCount: integer;
// returns a good default for the number of threads on this system
{$IF defined(windows)}
//returns total number of processors available to system including logical hyperthreaded processors
var
  SystemInfo: SYSTEM_INFO;
  {$IFnDEF WinCE}
  i: Integer;
  ProcessAffinityMask, SystemAffinityMask: DWORD_PTR;
  Mask: DWORD;
  {$ENDIF}
begin
  {$IFnDEF WinCE}
  if GetProcessAffinityMask(GetCurrentProcess, ProcessAffinityMask{%H-}, SystemAffinityMask{%H-})
  then begin
    Result := 0;
    for i := 0 to 31 do begin
      Mask := DWord(1) shl i;
      if (ProcessAffinityMask and Mask)<>0 then
        inc(Result);
    end;
    exit;
  end;
  {$ENDIF}
  //can't get the affinity mask so we just report the total number of processors
  GetSystemInfo(SystemInfo{%H-});
  Result := SystemInfo.dwNumberOfProcessors;
end;
{$ELSEIF defined(UNTESTEDsolaris)}
  begin
    t = sysconf(_SC_NPROC_ONLN);
  end;
{$ELSEIF defined(freebsd) or defined(darwin)}
var
  mib: array[0..1] of cint;
  len: cint;
  t: cint;
begin
  mib[0] := CTL_HW;
  mib[1] := HW_NCPU;
  len := sizeof(t);
  {$if FPC_FULLVERSION >= 30101}
  fpsysctl(@mib, 2, @t, @len, Nil, 0);
  {$else}
  fpsysctl(pchar(@mib), 2, @t, @len, Nil, 0);
  {$endif}
  Result:=t;
end;
{$ELSEIF defined(linux)}
  begin
    Result:=sysconf(_SC_NPROCESSORS_ONLN);
  end;

{$ELSE}
  begin
    Result:=1;
  end;
{$ENDIF}

function FindFilenameOfCmd(ProgramFilename: string): string;
begin
  Result:=TrimFilename(ProgramFilename);
  if not FilenameIsAbsolute(Result) then begin
    if Pos(PathDelim,Result)>0 then begin
      // with sub directory => relative to current directory
      Result:=CleanAndExpandFilename(Result);
    end else begin
      // search in PATH
      Result:=FindDefaultExecutablePath(Result);
    end;
  end;
  if (Result<>'') and not FileExistsUTF8(Result) then
    Result:='';
end;

// Runs a short command which should point to an executable in
// the environment PATH
// For example: ProgramFilename='ls' CmdLineParameters='-l /home'
// Will locate and execute the file '/bin/ls'
// If the command isn't found, an exception will be raised
procedure RunCmdFromPath(const ProgramFilename, CmdLineParameters: string);
var
  NewProgramFilename: String;
  BrowserProcess: TProcessUTF8;
begin
  NewProgramFilename:=FindFilenameOfCmd(ProgramFilename);

  if NewProgramFilename='' then
    raise EFOpenError.Create(Format(lrsProgramFileNotFound, [ProgramFilename]));
  if not FileIsExecutable(NewProgramFilename) then
    raise EFOpenError.Create(Format(lrsCanNotExecute, [NewProgramFilename]));

  // run
  BrowserProcess := TProcessUTF8.Create(nil);
  try
    BrowserProcess.InheritHandles:=false;
    // Encloses the executable with "" if its name has spaces
    if Pos(' ',NewProgramFilename)>0 then
      NewProgramFilename:='"'+NewProgramFilename+'"';

    {$Push}
    {$WARN SYMBOL_DEPRECATED OFF}
    BrowserProcess.CommandLine := NewProgramFilename;
    if CmdLineParameters<>'' then
      BrowserProcess.CommandLine := BrowserProcess.CommandLine + ' ' + CmdLineParameters;
    {$Pop}
    BrowserProcess.Execute;
  finally
    BrowserProcess.Free;
  end;
end;

procedure Register;
begin
  RegisterComponents('System',[TProcessUTF8]);
end;

{$IFDEF UseTProcessW}
Const
  PriorityConstants : Array [TProcessPriority] of Cardinal =
                      (HIGH_PRIORITY_CLASS,IDLE_PRIORITY_CLASS,
                       NORMAL_PRIORITY_CLASS,REALTIME_PRIORITY_CLASS
                       {$if (FPC_FULLVERSION >= 30200) and not defined(WinCE)}
                       ,BELOW_NORMAL_PRIORITY_CLASS,ABOVE_NORMAL_PRIORITY_CLASS
                       {$endif}
                       );

function WStrAsUniquePWideChar(var s: UnicodeString): PWideChar; inline;
begin
  UniqueString(s);
  if s<>'' then
    Result:=PWideChar(s)
  else
    Result:=nil;
end;

Function GetStartupFlags (P : TProcessUTF8): Cardinal;

begin
  Result:=0;
  if poUsePipes in P.Options then
     Result:=Result or Startf_UseStdHandles;
  if suoUseShowWindow in P.StartupOptions then
    Result:=Result or startf_USESHOWWINDOW;
  if suoUSESIZE in P.StartupOptions then
    Result:=Result or startf_usesize;
  if suoUsePosition in P.StartupOptions then
    Result:=Result or startf_USEPOSITION;
  if suoUSECOUNTCHARS in P.Startupoptions then
    Result:=Result or startf_usecountchars;
  if suoUsefIllAttribute in P.StartupOptions then
    Result:=Result or startf_USEFILLATTRIBUTE;
end;

Function GetCreationFlags(P : TProcessUTF8) : Cardinal;

begin
  Result:=CREATE_UNICODE_ENVIRONMENT;
  {$IF DECLARED(poDetached)}
  if poNoConsole in P.Options then
    Result:=Result or CREATE_NO_WINDOW;
  if poDetached in P.Options then
    Result:=Result or Detached_Process;
  {$ELSE}
  if poNoConsole in P.Options then
    Result:=Result or Detached_Process;
  {$ENDIF}
  if poNewConsole in P.Options then
    Result:=Result or Create_new_console;
  if poNewProcessGroup in P.Options then
    Result:=Result or CREATE_NEW_PROCESS_GROUP;
  If poRunSuspended in P.Options Then
    Result:=Result or Create_Suspended;
  if poDebugProcess in P.Options Then
    Result:=Result or DEBUG_PROCESS;
  if poDebugOnlyThisProcess in P.Options Then
    Result:=Result or DEBUG_ONLY_THIS_PROCESS;
  if poDefaultErrorMode in P.Options Then
    Result:=Result or CREATE_DEFAULT_ERROR_MODE;
  result:=result or PriorityConstants[P.Priority];
end;

Function MaybeQuote(Const S : String) : String;

begin
  If (Pos(' ',S)<>0) then
    Result:='"'+S+'"'
  else
     Result:=S;
end;

Function MaybeQuoteIfNotQuoted(Const S : String) : String;

begin
  If (Pos(' ',S)<>0) and (pos('"',S)=0) then
    Result:='"'+S+'"'
  else
     Result:=S;
end;

Function StringsToWChars(List : TStrings): pointer;

var
  EnvBlock: UnicodeString;
  I: Integer;

begin
  EnvBlock := '';
  For I:=0 to List.Count-1 do
    EnvBlock := EnvBlock + UTF8Decode(List[i]) + #0;
  EnvBlock := EnvBlock + #0;
  GetMem(Result, Length(EnvBlock)*2);
  CopyMemory(Result, @EnvBlock[1], Length(EnvBlock)*2);
end;

Procedure InitProcessAttributes(Out PA : TSecurityAttributes);

begin
  FillChar(PA{%H-},SizeOf(PA),0);
  PA.nLength := SizeOf(PA);
end;

Procedure InitThreadAttributes(Out TA : TSecurityAttributes);

begin
  FillChar(TA{%H-},SizeOf(TA),0);
  TA.nLength := SizeOf(TA);
end;

Procedure InitStartupInfo(P : TProcessUTF8; Out SI : STARTUPINFOW);

Const
  SWC : Array [TShowWindowOptions] of Cardinal =
             (0,SW_HIDE,SW_Maximize,SW_Minimize,SW_Restore,SW_Show,
             SW_ShowDefault,SW_ShowMaximized,SW_ShowMinimized,
               SW_showMinNOActive,SW_ShowNA,SW_ShowNoActivate,SW_ShowNormal);

begin
  FillChar(SI{%H-},SizeOf(SI),0);
  SI.dwFlags:=GetStartupFlags(P);
  if P.ShowWindow<>swoNone then
   SI.dwFlags:=SI.dwFlags or Startf_UseShowWindow
  else
    SI.dwFlags:=SI.dwFlags and not Startf_UseShowWindow;
  SI.wShowWindow:=SWC[P.ShowWindow];
  if (poUsePipes in P.Options) then
    begin
    SI.dwFlags:=SI.dwFlags or Startf_UseStdHandles;
    end;
  if P.FillAttribute<>0 then
    begin
    SI.dwFlags:=SI.dwFlags or Startf_UseFillAttribute;
    SI.dwFillAttribute:=P.FillAttribute;
    end;
   SI.dwXCountChars:=P.WindowColumns;
   SI.dwYCountChars:=P.WindowRows;
   SI.dwYsize:=P.WindowHeight;
   SI.dwXsize:=P.WindowWidth;
   SI.dwy:=P.WindowTop;
   SI.dwX:=P.WindowLeft;
end;

{ The handles that are to be passed to the child process must be
  inheritable. On the other hand, only non-inheritable handles
  allow the sending of EOF when the write-end is closed. This
  function is used to duplicate the child process's ends of the
  handles into inheritable ones, leaving the parent-side handles
  non-inheritable.
}
function DuplicateHandleFP(var handle: THandle): Boolean;

var
  oldHandle: THandle;
begin
  oldHandle := handle;
  Result := DuplicateHandle
  ( GetCurrentProcess(),
    oldHandle,
    GetCurrentProcess(),
    @handle,
    0,
    true,
    DUPLICATE_SAME_ACCESS
  );
  if Result then
    Result := CloseHandle(oldHandle);
end;


Procedure CreatePipes(Var HI,HO,HE : Thandle; Var SI : TStartupInfoW; CE : Boolean; APipeBufferSize : Cardinal);

begin
  CreatePipeHandles(SI.hStdInput,HI, APipeBufferSize);
  DuplicateHandleFP(SI.hStdInput);
  CreatePipeHandles(HO,Si.hStdOutput, APipeBufferSize);
  DuplicateHandleFP(   Si.hStdOutput);
  if CE then begin
    CreatePipeHandles(HE,SI.hStdError, APipeBufferSize);
    DuplicateHandleFP(   SI.hStdError);
    end
  else
    begin
    SI.hStdError:=SI.hStdOutput;
    HE:=HO;
    end;
end;

{ TProcessUTF8 }

type
  PHandle = ^THandle;

procedure TProcessUTF8.SetProcessHandle(aProcessHandle: THandle);
var
  P: PHandle;
begin
  P := @Self.ProcessHandle;
  P^ := aProcessHandle;
  if aProcessHandle<>ProcessHandle then
    raise Exception.Create('TProcessUTF8.SetProcessHandle failed');
end;

procedure TProcessUTF8.SetThreadHandle(aThreadHandle: THandle);
var
  P: PHandle;
begin
  P := @Self.ThreadHandle;
  P^ := aThreadHandle;
  if aThreadHandle<>ThreadHandle then
    raise Exception.Create('TProcessUTF8.SetThreadHandle failed');
end;

procedure TProcessUTF8.SetProcessID(aProcessID: Integer);
var
  P: PInteger;
begin
  P := @Self.ProcessID;
  P^ := aProcessID;
  if aProcessID<>ProcessID then
    raise Exception.Create('TProcessUTF8.SetProcessID failed');
end;

procedure TProcessUTF8.Execute;
Var
  i : Integer;
  WName,WDir,WCommandLine : UnicodeString;
  PWName,PWDir,PWCommandLine : PWideChar;
  FEnv: pointer;
  FCreationFlags : Cardinal;
  FProcessAttributes : TSecurityAttributes;
  FThreadAttributes : TSecurityAttributes;
  FProcessInformation : TProcessInformation;
  FStartupInfo : STARTUPINFOW;
  HI,HO,HE : THandle;
  Cmd : String;

begin
  WName:='';
  WCommandLine:='';
  WDir:='';

  if (ApplicationName{%H-}='') and (CommandLine{%H-}='') and (Executable='') then
    Raise EProcess.Create(SNoCommandline);
  if (ApplicationName{%H-}<>'') then
    begin
    WName:=UTF8Decode(ApplicationName{%H-});
    WCommandLine:=UTF8Decode(CommandLine{%H-});
    end
  else If (CommandLine{%H-}<>'') then
    WCommandLine:=UTF8Decode(CommandLine{%H-})
  else if (Executable<>'') then
    begin
    Cmd:=MaybeQuoteIfNotQuoted(Executable);
    For I:=0 to Parameters.Count-1 do
      Cmd:=Cmd+' '+MaybeQuoteIfNotQuoted(Parameters[i]);
    WCommandLine:=UTF8Decode(Cmd);
    end;
  If CurrentDirectory<>'' then
    WDir:=UTF8Decode(CurrentDirectory);
  if Environment.Count<>0 then
    FEnv:=StringsToWChars(Environment)
  else
    FEnv:=Nil;
  Try
    FCreationFlags:=GetCreationFlags(Self);
    InitProcessAttributes(FProcessAttributes);
    InitThreadAttributes(FThreadAttributes);
    InitStartupInfo(Self,FStartupInfo);
    If poUsePipes in Options then
      CreatePipes(HI{%H-},HO{%H-},HE{%H-},FStartupInfo,Not(poStdErrToOutPut in Options), PipeBufferSize);
    Try
      // Beware: CreateProcess can alter the strings
      // Beware: nil is not the same as a pointer to a #0
      PWName:=WStrAsUniquePWideChar(WName);
      PWCommandLine:=WStrAsUniquePWideChar(WCommandLine);
      PWDir:=WStrAsUniquePWideChar(WDir);

      If Not CreateProcessW (PWName,PWCommandLine,@FProcessAttributes,@FThreadAttributes,
                   InheritHandles,FCreationFlags,FEnv,PWDir,FStartupInfo,
                   fProcessInformation{%H-}) then
        Raise EProcess.CreateFmt(SErrCannotExecute,[CommandLine{%H-},GetLastError]);
      SetProcessHandle(FProcessInformation.hProcess);
      SetThreadHandle(FProcessInformation.hThread);
      SetProcessID(FProcessINformation.dwProcessID);
    Finally
      if POUsePipes in Options then
        begin
        FileClose(FStartupInfo.hStdInput);
        FileClose(FStartupInfo.hStdOutput);
        if Not (poStdErrToOutPut in Options) then
          FileClose(FStartupInfo.hStdError);
        CreateStreams(HI,HO,HE);
        end;
    end;
    FRunning:=True;
  Finally
    If FEnv<>Nil then
      FreeMem(FEnv);
  end;
  if not (csDesigning in ComponentState) and // This would hang the IDE !
     (poWaitOnExit in Options) and
      not (poRunSuspended in Options) then
    WaitOnExit;
end;
{$ENDIF}

procedure TProcessUTF8.ParseCmdLine(const CmdLine: string; ReadBackslash: boolean);
var
  List: TStringList;
begin
  List:=TStringList.Create;
  try
    SplitCmdLineParams(CmdLine, List, ReadBackslash);
    if List.Count>0 then begin
      Executable:=List[0];
      List.Delete(0);
    end else begin
      Executable:='';
    end;
    Parameters.Assign(List);
  finally
    List.Free;
  end;
end;

end.

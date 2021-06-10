{
 /***************************************************************************
                              idecmdline.pas
                             --------------------
               A unit to manage command lines issue used inside the ide

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
 
 Author: Ido Kanner

  This unit manages the commandline utils that are used across Lazarus.
  It was created for avoding duplicates and easier access for commandline utils
  that are required by the IDE.
}
unit IDECmdLine;

{$mode objfpc}{$H+}

interface

uses 
  Classes, SysUtils,
  // LazUtils
  FileUtil, LazFileUtils, LazStringUtils, LazUTF8, LazLogger,
  // IDE
  LazConf;

const
  // IDE cmd line options
  ShowSetupDialogOptLong='--setup';
  PrimaryConfPathOptLong='--primary-config-path=';
  PrimaryConfPathOptShort='--pcp=';
  SecondaryConfPathOptLong='--secondary-config-path=';
  SecondaryConfPathOptShort='--scp=';
  NoSplashScreenOptLong='--no-splash-screen';
  NoSplashScreenOptShort='--nsc';
  StartedByStartLazarusOpt='--started-by-startlazarus';
  ForceNewInstanceOpt='--force-new-instance';
  SkipLastProjectOpt='--skip-last-project';
  DebugLogOpt='--debug-log=';
  DebugLogOptEnable='--debug-enable=';
  LanguageOpt='--language=';
  LazarusDirOpt ='--lazarusdir=';
const
  // startlazarus options
  StartLazarusPidOpt   = '--lazarus-pid=';
  StartLazarusDebugOpt = '--debug';

procedure ParseCommandLine(aCmdLineParams: TStrings; out IDEPid : Integer;
            out ShowSplashScreen: boolean);
function GetCommandLineParameters(aCmdLineParams: TStrings;
            isStartLazarus: Boolean = False) : string;
function ExtractPrimaryConfigPath(aCmdLineParams: TStrings): string;
function ExpandParamFile(const s: string): string;

function IsHelpRequested : Boolean;
function IsVersionRequested : boolean;
function GetLanguageSpecified : string;
function ParamIsOption(ParamIndex : integer; const Option : string) : boolean;
function ParamIsOptionPlusValue(ParamIndex : integer;
            const Option : string; out AValue : string) : boolean;

procedure ParseNoGuiCmdLineParams;

function ExtractCmdLineFilenames : TStrings;

// options from CFG file
function GetCfgFileContent: TStrings;
function GetParamsAndCfgFile: TStrings;
function ParamsAndCfgCount: Integer;
function ParamsAndCfgStr(Idx: Integer): String;
procedure ResetParamsAndCfg;

implementation

var
  CfgFileName: String = '';
  CfgFileDone: Boolean = False;
  CfgFileContent: TStrings = nil;
  ParamsAndCfgFileContent: TStrings = nil;

function GetCfgFileContent: TStrings;
begin
  Result := CfgFileContent;
  if CfgFileDone then
    exit;
  CfgFileDone := True;
  CfgFileName := AppendPathDelim(ProgramDirectory) + 'lazarus.cfg';
  if FileExistsUTF8(CfgFileName) then begin
    DebugLn(['using config file ', CfgFileName]);
    CfgFileContent := TStringList.Create;
    CfgFileContent.LoadFromFile(CfgFileName);
  end;
  Result := CfgFileContent;
end;

function GetParamsAndCfgFile: TStrings;
  procedure CleanDuplicates(ACurParam, AMatch, AClean: String);
  var
    i: Integer;
  begin
    if LazStartsText(AMatch, ACurParam) then begin
      i := ParamsAndCfgFileContent.Count - 1;
      while i >= 0 do begin
        if LazStartsText(AClean, ParamsAndCfgFileContent[i]) then
          ParamsAndCfgFileContent.Delete(i);
        dec(i);
      end;
    end;
  end;
var
  Cfg: TStrings;
  i: Integer;
  s: String;
  Warn: String;
begin
  Result := ParamsAndCfgFileContent;
  if Result <> nil then
    exit;
  ParamsAndCfgFileContent := TStringList.Create;
  ParamsAndCfgFileContent.Add(ParamStrUTF8(0));

  Cfg := GetCfgFileContent;
  if Cfg <> nil then begin
    Warn := '';
    // insert Cfg at start. For duplicates the latest occurrence takes precedence
    for i := 0 to Cfg.Count - 1 do begin
      s := Cfg[i];
      if (s <> '') and (s[1] = '-') then
        begin
          s := Trim(s);
          {$ifdef windows}
          //cfg file is made by Windows installer and probably is Windows default codepage
          if FindInvalidUTF8Codepoint(PChar(s), Length(s), True) > 0 then
            s := WinCPToUtf8(s);
          {$endif windows}
          ParamsAndCfgFileContent.Add(s)
        end
      else
      if (Trim(s) <> '') and (s[1] <> '#') then
        Warn := Warn + IntToStr(i)+': ' + s + LineEnding;
    end;
    if Warn<>'' then begin
      debugln('WARNING: invalid lines in lazarus.cfg:');
      debugln(Warn);
    end;
  end;

  for i := 1 to Paramcount do begin
    s := ParamStrUTF8(i);
    CleanDuplicates(s, PrimaryConfPathOptLong, PrimaryConfPathOptLong);
    CleanDuplicates(s, PrimaryConfPathOptLong, PrimaryConfPathOptShort);
    CleanDuplicates(s, PrimaryConfPathOptShort, PrimaryConfPathOptLong);
    CleanDuplicates(s, PrimaryConfPathOptShort, PrimaryConfPathOptShort);
    CleanDuplicates(s, SecondaryConfPathOptLong, SecondaryConfPathOptLong);
    CleanDuplicates(s, SecondaryConfPathOptLong, SecondaryConfPathOptShort);
    CleanDuplicates(s, SecondaryConfPathOptShort, SecondaryConfPathOptLong);
    CleanDuplicates(s, SecondaryConfPathOptShort, SecondaryConfPathOptShort);
    CleanDuplicates(s, LanguageOpt, LanguageOpt);
    CleanDuplicates(s, LazarusDirOpt, LazarusDirOpt);
    ParamsAndCfgFileContent.Add(s);
  end;

  Result := ParamsAndCfgFileContent;
end;

function ParamsAndCfgCount: Integer;
begin
  Result := GetParamsAndCfgFile.Count;
end;

function ParamsAndCfgStr(Idx: Integer): String;
begin
  if (Idx < 0) or (Idx >= GetParamsAndCfgFile.Count) then
    Result := ''
  else
    Result := GetParamsAndCfgFile[Idx];
end;

procedure ResetParamsAndCfg;
begin
  FreeAndNil(ParamsAndCfgFileContent);
end;

procedure ParseCommandLine(aCmdLineParams: TStrings; out IDEPid: Integer; out
  ShowSplashScreen: boolean);
var
  i     : Integer;
  Param : string;
  HasDebugLog: Boolean;
begin
  IDEPid := 0;
  HasDebugLog := False;
  for i := 1 to ParamsAndCfgCount do begin
    Param := ParamsAndCfgStr(i);
    if Param='' then continue;
    if SysUtils.CompareText(LeftStr(Param, length(DebugLogOpt)), DebugLogOpt) = 0 then
      HasDebugLog := HasDebugLog or (length(Param) > length(DebugLogOpt));
    if (Param=StartLazarusDebugOpt) and (not HasDebugLog) then begin
      aCmdLineParams.Add('--debug-log=' +
                         AppendPathDelim(UTF8ToSys(GetPrimaryConfigPath)) + 'debug.log');
    end;
    if LeftStr(Param,length(StartLazarusPidOpt))=StartLazarusPidOpt then begin
      try
        IDEPid :=
          StrToInt(RightStr(Param,Length(Param)-Length(StartLazarusPidOpt)));
      except
        DebugLn('Failed to parse %s',[Param]);
        IDEPid := 0;
      end;
    end
    else if ParamIsOption(i, NoSplashScreenOptLong) or
            ParamIsOption(i, NoSplashScreenOptShort) then
    begin
      ShowSplashScreen := false;
    end
    else begin
      // Do not add file to the parameter list
      if not (Copy(Param,1,1) = '-') and (FileExistsUTF8(ExpandFileNameUTF8(Param))) then
      begin
        DebugLn('%s is a file', [Param]);
        continue;
      end;

      // pass these parameters to Lazarus
      DebugLn('Adding "%s" as a parameter', [Param]);
      aCmdLineParams.Add(Param);
    end;
  end;
end;

function GetCommandLineParameters(aCmdLineParams : TStrings; isStartLazarus : Boolean = False) : String;
var
  i: Integer;
  s: String;
begin
  if isStartLazarus then
    Result := ' '+NoSplashScreenOptLong+' '+StartedByStartLazarusOpt
  else
    Result := '';
  for i := 0 to aCmdLineParams.Count - 1 do begin
    s := aCmdLineParams[i];
    // make sure that command line parameters are still
    // double quoted, if they contain spaces
    if pos(' ', s) > 0 then
      s := '"' + s + '"';
    Result := Result + ' ' + s;
  end;
end;

function ExtractPrimaryConfigPath(aCmdLineParams: TStrings): string;

  procedure GetParam(Param, Prefix: string; var Value: string);
  begin
    if LeftStr(Param,length(Prefix))=Prefix then
      Value:=copy(Param,length(Prefix)+1,length(Param));
  end;

var
  i: Integer;
begin
  Result:='';
  for i:=0 to aCmdLineParams.Count-1 do
  begin
    GetParam(aCmdLineParams[i],PrimaryConfPathOptLong,Result);
    GetParam(aCmdLineParams[i],PrimaryConfPathOptShort,Result);
  end;
end;

function ExpandParamFile(const s: string): string;
const
  a: array[1..5] of string = (
    PrimaryConfPathOptLong,PrimaryConfPathOptShort,
    SecondaryConfPathOptLong,SecondaryConfPathOptShort,
    LazarusDirOpt
  );
var
  p: string;
begin
  Result:=s;
  for p in a do
    if LeftStr(Result,length(p))=p then
    begin
    Result:=LeftStr(Result,length(p))+ExpandFileNameUTF8(copy(Result,length(p)+1,length(Result)));
    exit;
    end;
end;

function IsHelpRequested : Boolean;
var
  i: integer;
begin
  Result := false;
  i:=1;
  while (i <= ParamsAndCfgCount) and (Result = false) do
  begin
    Result := ParamIsOption(i, '--help') or
              ParamIsOption(i, '-help')  or
              ParamIsOption(i, '-?')     or
              ParamIsOption(i, '-h');
    inc(i);
  end;
end;

function IsVersionRequested: boolean;
begin
  //Don't use ParamsAndCfgCount here, because ATM (2019-03-24) GetParamsAndCfgFile adds
  //ParamStrUtf8(0) to it and may add more in the future
  Result := (ParamCount=1) and
            ((ParamStr(1)='--version') or
            (ParamStr(1)='-v'));
end;

function GetLanguageSpecified : string;
var
  i: integer;
  AValue: string;
begin
  // return language specified in command line (empty string if no language specified)
  Result := '';
  AValue := '';
  i := 1;
  while i <= ParamsAndCfgCount do
  begin
    if ParamIsOptionPlusValue(i, LanguageOpt, AValue) = true then
    begin
      Result := AValue;
      exit;
    end;
    inc(i);
  end;
end;

function ParamIsOption(ParamIndex : integer; const Option : string) : boolean;
begin
  Result:=SysUtils.CompareText(ParamsAndCfgStr(ParamIndex),Option) = 0;
end;

function ParamIsOptionPlusValue(ParamIndex : integer;
    const Option : string; out AValue : string) : boolean;
var
  p : String;
begin
 p      := ParamsAndCfgStr(ParamIndex);
 Result := SysUtils.CompareText(LeftStr(p, length(Option)), Option) = 0;
 if Result then
   AValue := copy(p, length(Option) + 1, length(p))
 else
   AValue := '';
end;

procedure ParseNoGuiCmdLineParams;
var
  i      : integer;
  AValue : String;
begin
  for i:=1 to ParamsAndCfgCount do
  begin
    //DebugLn(['ParseNoGuiCmdLineParams ',i,' "',ParamsAndCfgStr(i),'"']);
    if ParamIsOptionPlusValue(i, PrimaryConfPathOptLong, AValue) then
      SetPrimaryConfigPath(AValue)
    else if ParamIsOptionPlusValue(i, PrimaryConfPathOptShort, AValue) then
      SetPrimaryConfigPath(AValue)
    else if ParamIsOptionPlusValue(i, SecondaryConfPathOptLong, AValue) then
      SetSecondaryConfigPath(AValue)
    else if ParamIsOptionPlusValue(i, SecondaryConfPathOptShort, AValue) then
      SetSecondaryConfigPath(AValue);
  end;
end;

function ExtractCmdLineFilenames : TStrings;
var
  i        : LongInt;
  Filename : String;
  
begin
  Result := nil;
  for i := 1 to ParamsAndCfgCount do
   begin
     Filename := ParamsAndCfgStr(i);
     if (Filename = '') or (Filename[1] = '-') then
       continue;
     if Result = nil then
       Result := TStringList.Create;
     Result.Add(Filename);
    end;
end;

procedure InitLogger;
var
  i      : integer;
  AValue : String;
begin
  for i:= 1 to ParamsAndCfgCount do
  begin
    if ParamIsOptionPlusValue(i, DebugLogOpt, AValue) then
      LazLogger.DebugLogger.LogName := AValue;
  end;
end;

initialization
  InitLogger;
finalization
  FreeAndNil(CfgFileContent);
  FreeAndNil(ParamsAndCfgFileContent);
end.


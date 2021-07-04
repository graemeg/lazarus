{
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

  Author: Vincent Snijders

  Name:
       svn2revisioninc - creates an include file with the revision number

  Synopsis:
       svn2revisioninc sourcedir revision.inc

  Description:
       svn2revisioninc creates an include file with the current revision number
       coming from a version control repository.

       This tool supports Subversion (svn), git copies from and Mercurial (hg) repositories.

       1. If the source directory contains a .svn subdirectory, it tries to
       execute svnversion to get the revision number.
       If that fails - for example, because it can't find svnversion - it opens
       .svn/entries to get the revision number of the source directory.

       If it can't find revision information, it checks whether revision.inc
       exists. If it exists and seems to be created with svn2revisioninc, it
       will leave the file as is. Otherwise it will create a new revision.inc,
       indicating that the revision number is unknown.

       2. If the source directory doesn't contain a .svn subdirectory, it
       searches for a .git directory. If it exists, it tries to execute git to
       get the revision number.

       3. If the source directory doesn't contain a .svn or .git subdirectory,
       it tries to execute hg to get the revision id.
       Not checking for the .hg subdirectory allows getting the hg revision id
       even in subdirectories.
       Support for svn repos converted to hg with hgsubversion.
}
program Svn2RevisionInc;

{$mode objfpc}{$H+}

uses
  Classes, CustApp, SysUtils, Process, Dom, XmlRead,
  // LazUtils
  FileUtil, LazFileUtils, LazUTF8, UTF8Process, LazLogger, StrUtils;

type

  { TSvn2RevisionApplication }

  TSvn2RevisionApplication = class(TCustomApplication)
  private
    SourceDirectory,
    RevisionIncFileName: string;
    RevisionIncDirName: string;
    RevisionStr: string;
    MainBranch: string;
    ConstName: string;
    Verbose: boolean;
    UseStdOut: boolean;

    function FindRevision: boolean;
    function IsValidRevisionInc: boolean;
    procedure WriteRevisionInc;
    function ParamsValid: boolean;
    procedure ShowHelp;
    function CanCreateRevisionInc: boolean;
    function ConstStart: string;
    procedure Show(msg: string);
    function IsThisGitUpstreamBranch: boolean;
    function GetGitBranchPoint: string;
    function GitRevisionFromGitCommit: boolean;
    function GitDescribeCommit(KeepRevStr: Boolean): boolean;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    procedure Run;
  end;

var
  Application: TSvn2RevisionApplication = nil;

const
  RevisionIncComment = '// Created by Svn2RevisionInc';
  
function SvnInPath: Boolean;
var
  P: TProcessUTF8;
begin
  Result := True;
  P := TProcessUTF8.Create(nil);
  try
    P.Options := [poUsePipes, poWaitOnExit];
    P.CommandLine := 'svn --version';
    try
      P.Execute;
    except
      Result := False;
    end;
  finally
    P.Destroy;
  end;
end;

function GitInPath: Boolean;
var
  P: TProcessUTF8;
begin
  Result := True;
  P := TProcessUTF8.Create(nil);
  try
    P.Options := [poUsePipes, poWaitOnExit];
    P.CommandLine := 'git --version';
    try
      P.Execute;
    except
      Result := False;
    end;
  finally
    P.Destroy;
  end;
end;

function HgInPath: Boolean;
var
  P: TProcessUTF8;
begin
  Result := True;
  P := TProcessUTF8.Create(nil);
  try
    P.Options := [poUsePipes, poWaitOnExit];
    P.CommandLine := 'hg --version';
    try
      P.Execute;
    except
      Result := False;
    end;
  finally
    P.Destroy;
  end;
end;


function TSvn2RevisionApplication.FindRevision: boolean;
var
  GitDir: string;


  function GetRevisionFromGitVersion : boolean;
  var
    GitVersionProcess: TProcessUTF8;
    Buffer: string;
    n: LongInt;
  begin
    Result:=false;
    GitVersionProcess := TProcessUTF8.Create(nil);
    try
      with GitVersionProcess do begin
        CommandLine := 'git log -1 --pretty=format:"%b"';
        Options := [poUsePipes, poWaitOnExit];
        try
          CurrentDirectory:=GitDir;
          Execute;
          SetLength(Buffer, 80);
          n:=OutPut.Read(Buffer[1], 80);

          if (Pos('git-svn-id:', Buffer) > 0) then begin
            //Read version is OK
            Result:=true;
            RevisionStr := Copy(Buffer, 1, n);
            System.Delete(RevisionStr, 1, Pos('@', RevisionStr));
            System.Delete(RevisionStr, Pos(' ', RevisionStr), Length(RevisionStr));
          end;
        except
        // ignore error, default result is false
        end;
      end;
    finally
      GitVersionProcess.Free;
    end;
    if Result then
    begin
      Show('Success retrieving revision with git log.');
    end
    else
    begin
      Show('Failed retrieving revision with git log.');
      if n>0 then
      begin
        Show('');
        Show('git log error output:');
        Show(Copy(Buffer, 1, n));
      end;
    end;
    Show('');
  end;

  function GetRevisionFromHgVersion : boolean;
  var
    HgVersionProcess: TProcessUTF8;
    Buffer: string;
    n: LongInt;
    ScrapeResult: string;
  begin
    Result:=false;
    HgVersionProcess := TProcessUTF8.Create(nil);
    try
      with HgVersionProcess do begin
        // Get global revision ID (no need to worry about branches)
        CurrentDirectory:=SourceDirectory;
        CommandLine := 'hg parents --template="{svnrev}:{node|short}"';
        Options := [poUsePipes, poWaitOnExit];
        try
          Execute;
          SetLength(Buffer, 80);
          n:=OutPut.Read(Buffer[1], 80);

          Result:=true;
          // Just blindly copy results; check for errors below.
          ScrapeResult := Trim(Copy(Buffer, 1, n));
          System.Delete(ScrapeResult, 1, Pos(#13, ScrapeResult));
          System.Delete(ScrapeResult, 1, Pos(#10, ScrapeResult));
          System.Delete(ScrapeResult, Pos(' ', ScrapeResult), Length(ScrapeResult));
          if ScrapeResult[1]='"' then //linux returns "
            ScrapeResult:=copy(ScrapeResult,2,length(ScrapeResult)-2);
          if ScrapeResult[1]=':' then //no svn version found.
            //Indicate we're dealing with Mercurial to avoid confusing the user:
            ScrapeResult:='hg'+ScrapeResult
          else
            ScrapeResult:=copy(ScrapeResult,1,pos(':',ScrapeResult)-1);
        except
        // ignore error, default result is false
        end;
        // Check for errors returned by command (e.g. repository not found)
        if ExitStatus<>0 then
        begin
          show('GetRevisionFromHgRevision: non-zero exit status: no hg repo?');
          result:=false;
        end;
        if result then RevisionStr:=ScrapeResult;
      end;
    finally
      HgVersionProcess.Free;
    end;
    if Result then
    begin
      Show('Success retrieving revision with hg/mercurial.');
    end
    else
    begin
      Show('Failed retrieving revision with hg/mercurial.');
      if n>0 then
      begin
        Show('');
        Show('hg parents error output:');
        Show(Copy(Buffer, 1, n));
      end;
    end;
    Show('');
  end;

  function GetRevisionFromSvnVersion : boolean;
  var
    SvnVersionProcess: TProcessUTF8;
    Buffer: string;
    n: LongInt;
  begin
    Result:=false;
    SvnVersionProcess := TProcessUTF8.Create(nil);
    try
      with SvnVersionProcess do begin
        CommandLine := 'svnversion -n "' + SourceDirectory + '"';
        Options := [poUsePipes, poWaitOnExit];
        try
          Execute;
          SetLength(Buffer, 80);
          n:=OutPut.Read(Buffer[1], 80);
          RevisionStr := Copy(Buffer, 1, n);

          // If cannot determine svn version it will return localized message
          // "Unversioned directory" with no error result but svn revisions
          // always start with a number.
          Result:=(n > 0) and (RevisionStr[1] in ['0'..'9']);

          SetLength(Buffer, 1024);
          n:=Stderr.Read(Buffer[1], 1024);
        except
        // ignore error, default result is false
        end;
      end;
    finally
      SvnVersionProcess.Free;
    end;
    if Result then
    begin
      Show('Success retrieving revision with svnversion.');
    end
    else
    begin
      Show('Failed retrieving revision with svnversion.');
      if n>0 then
      begin
        Show('');
        Show('svnversion error output:');
        Show(Copy(Buffer, 1, n));
      end;
    end;
    Show('');
  end;

  function GetRevisionFromEntriesTxt: boolean;
  var
    EntriesFileName: string;
    Line: string;
    Lines: TStringList;
    i: Integer;
  begin
    Result:=false;
    EntriesFileName:=AppendPathDelim(SourceDirectory)+'.svn'+PathDelim+'entries';
    if FileExistsUTF8(EntriesFileName) then begin
      try
        Lines:=TStringList.Create;
        try
          Lines.LoadFromFile(EntriesFileName);
          // skip three lines
          i:=0;
          Line:=Lines[i];
          if line<>'<?xml version="1.0" encoding="utf-8"?>' then begin
            inc(i,3);
            RevisionStr:=Lines[i];
            Result := RevisionStr <> '';
          end;
        finally
          Lines.Free;
        end;
      except
        // ignore error, default result is false
      end;
    end;
    if Result then
      Show('Success retrieving revision with entries file: '+EntriesFileName)
    else
      Show('Failure retrieving revision with entries file: '+EntriesFileName);
    Show('');
  end;

  function GetRevisionFromEntriesXml: boolean;
  var
    EntriesFileName: string;
    EntriesDoc: TXMLDocument;
    EntryNode: TDomNode;
  begin
    Result := False;
    EntriesFileName:=AppendPathDelim(SourceDirectory)+'.svn'+PathDelim+'entries';
    if FileExistsUTF8(EntriesFileName) then
    begin
       try
         EntriesDoc := nil;
         try
           ReadXMLFile(EntriesDoc, EntriesFileName);
           EntryNode := EntriesDoc.FirstChild.FirstChild;
           while not Result and Assigned(EntryNode) do
           begin
             if EntryNode.Attributes.GetNamedItem('name').NodeValue='' then
             begin
               RevisionStr:=EntryNode.Attributes.GetNamedItem('revision').NodeValue;
               Result := True;
             end;
             EntryNode := EntryNode.NextSibling;
           end;
         finally
           EntriesDoc.Free;
         end;
       except
         // ignore error, default result is false
       end;
    end;
    if Result then
      Show('Success retrieving revision with entries XML file: '+EntriesFileName)
    else
      Show('Failure retrieving revision with entries XML file: '+EntriesFileName);
    Show('');
  end;

begin
  Show('Going to retrieve revision for source directory: '+SourceDirectory);
  // Try Subversion/svn
  // Use or's short circuiting to make sure only the last succesful function writes to RevisionStr
  Result := GetRevisionFromSvnVersion or GetRevisionFromEntriesTxt or
            GetRevisionFromEntriesXml;

  // Try git
  if not Result then
  begin
    GitDir:= AppendPathDelim(SourceDirectory)+'.git';
    if DirectoryExistsUTF8(GitDir) and GitInPath then
    begin
      if IsThisGitUpstreamBranch then
        Result := GetRevisionFromGitVersion
      else
        Result := GitRevisionFromGitCommit;

      if GitDescribeCommit(Result) then
        Result := True;
    end;
  end;

  // Try Mercurial/hg
  if not Result then
  begin
    if HgInPath then
      Result := GetRevisionFromHgVersion;
  end;
end;

constructor TSvn2RevisionApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  RevisionStr := 'Unknown';
end;

destructor TSvn2RevisionApplication.Destroy;
begin
  inherited Destroy;
end;

function TSvn2RevisionApplication.IsValidRevisionInc: boolean;
var
  Lines: TStringList;
begin
  Result := FileExistsUTF8(RevisionIncFileName);
  if Result then 
  begin
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(RevisionIncFileName);
      Result := (Lines.Count = 2) and
        (Lines[0] = RevisionIncComment) and
        (Copy(Lines[1], 1, Length(ConstStart)) = ConstStart);
    finally
      Lines.Free;
    end;
  end;
end;

procedure TSvn2RevisionApplication.WriteRevisionInc;
var
  RevisionIncText: Text;
begin
  AssignFile(RevisionIncText, RevisionIncFileName);
  Rewrite(RevisionIncText);
  writeln(RevisionIncText, RevisionIncComment);
  writeln(RevisionIncText, ConstStart, RevisionStr, ''';');
  CloseFile(RevisionIncText);
  DebugLn(format('Created %s for revision: %s', [RevisionIncFileName, RevisionStr]));
end;

procedure TSvn2RevisionApplication.ShowHelp;
  function ExtractFileBaseName(FileName: string): string;
  begin
    Result := ChangeFileExt(ExtractFileName(FileName), '');
  end;
begin
  debugln;
  debugln(ParamStrUTF8(0));
  debugln;
  debugln(ExtractFileBaseName(ParamStrUTF8(0)), ' <repository path> <output file> [Options]');
  debugln('or');
  debugln(ExtractFileBaseName(ParamStrUTF8(0)), ' [Options] <repository path> <output file>');
  debugln('or');
  debugln(ExtractFileBaseName(ParamStrUTF8(0)), ' <repository path> [Options] <output file>');
  debugln;
  debugln('Options:');
  debugln(' --o                  Output file');
  debugln(' --c=<name>           Name of constant (default RevisionStr)');
  debugln(' --s                  write revision to stdout, do not create inc file');
  debugln(' --v                  Be more verbose');
  debugln(' --h                  This help screen');
  debugln;
  debugln('Note: <repository path> default current directory');
  debugln('      <output file> default revision.inc');
  debugln('      --o overrides <output file>');
  debugln;
  debugln('      1st switchless parameter = <repository path>');
  debugln('      2nd switchless parameter = <output file>');
  halt(1);
end;

function TSvn2RevisionApplication.ParamsValid: boolean;
var
  i: integer;
  index: integer;
begin
  Result := False;

  //reset
  Verbose := False;
  ConstName := 'RevisionStr';
  SourceDirectory:=ChompPathDelim(ExtractFilePath(ParamStrUTF8(0)));
  RevisionIncFileName := ExpandFileNameUTF8('revision.inc');

  //find switchless parameters
  index := 1;
  for i := 1 to ParamCount do
  begin
    if Copy(ParamStrUTF8(i),1,1) <> '-' then
    begin
      case index of
        1: SourceDirectory:=ChompPathDelim(ParamStrUTF8(i));
        2: RevisionIncFileName := ExpandFileNameUTF8(ParamStrUTF8(i));
      end;
      Inc(index);
    end;
  end;

  //parse options
  if HasOption('h', 'help') or HasOption('?') then
    ShowHelp;

  if HasOption('v') then
    Verbose := True;

  if HasOption('s') then
    UseStdOut := True;

  if HasOption('c') then
    ConstName := GetOptionValue('c');

  if HasOption('o') then
    RevisionIncFileName := GetOptionValue('o');

  //show options
  Show('SourceDirectory:     ' + SourceDirectory);
  Show('RevisionIncFileName: ' + RevisionIncFileName);
  Show('ConstName:           ' + ConstName);
  Show('');

  //checks
  if not DirectoryExistsUTF8(SourceDirectory) then
  begin
    debugln('Error: Source directory "', SourceDirectory, '" doesn''t exist.');
    exit;
  end;

  RevisionIncDirName:=ExtractFilePath(ExpandFileNameUTF8(RevisionIncFileName));
  if (not UseStdOut) and (not DirectoryExistsUTF8(RevisionIncDirName)) then begin
    debugln('Error: Target Directory "', RevisionIncDirName, '" doesn''t exist.');
    exit;
  end;

  if ConstName[1] in ['0'..'9'] then
  begin
    debugln('Error: Invalid constant name ', ConstName, '.');
    exit;
  end;

  if not SvnInPath then
    debugln('Warning: svn not in path.');

  Result := True;
end;

function TSvn2RevisionApplication.CanCreateRevisionInc: boolean;
begin
  if (FileExistsUTF8(RevisionIncFileName)) then
    Result:= FileIsWritable(RevisionIncFileName)
  else
    Result := DirectoryIsWritable(RevisionIncDirName);
end;

function TSvn2RevisionApplication.ConstStart: string;
begin
  Result := Format('const %s = ''', [ConstName]);
end;

procedure TSvn2RevisionApplication.Show(msg: string);
begin
  if Verbose then
    debugln(msg);
end;

{
  Determine what branch we are in by looking at the 'git branch' output.
  Sample output:
    $ git branch
      custom-patches
      docs
      dubydebugger
      externtools
      filebrowser
    * filefilters
      fixes
      graeme
      upstream
      work

}
function TSvn2RevisionApplication.IsThisGitUpstreamBranch: boolean;
const
  cBufSize = 2048;
  MainBranchNames: array[0..1] of string = ('upstream', 'master');
var
  p: TProcessUTF8;
  Buffer: string;
  s: string;
  i, j: integer;
  n: LongInt;
  sl: TStringList;
begin
  Result := false;
  p := TProcessUTF8.Create(nil);
  sl := TStringList.Create;
  try
    p.CommandLine := 'git branch';
    p.Options := [poUsePipes, poWaitOnExit];
    p.Execute;
    // Now lets process the output
    SetLength(Buffer, cBufSize);
    s := '';
    repeat
      n := p.Output.Read(Buffer[1], cBufSize);
      s := s + Copy(Buffer, 1, n);
    until n < cBufSize;
    sl.Text := s;
    // Search for the active branch marker '*' symbol.
    // Guess the main branch name. Support 'master' and 'upstream'.
    MainBranch := '';
    for i := 0 to sl.Count-1 do begin
      for j := Low(MainBranchNames) to High(MainBranchNames) do begin
        if Pos(MainBranchNames[j], sl[i]) > 0 then begin
          MainBranch := MainBranchNames[j];
          if sl[i][1] = '*' then begin
            Result := True;
            exit;
          end;
        end;
      end;
    end;
  finally
    sl.Free;
    p.Free;
  end;
end;

{ Determine the commit at which we branched away from 'upstream'. Note the
  SHA1 commit we are looking for is always the last one in the list that has
  the '-' prefix added.
  Example output:
    $ git rev-list --boundary HEAD...upstream
    a39f9f70f96b9533377c2cad27155066a0b01411
    3874aa82b83fedaa19459fedaa30f4582251b9a1
    0379257d111d465bf28e879d6b87080d9e896648
    5dd8ca18ef06520a524bfac9648103d440fbe0bc
    -d1fba5c3f36a4816c933a8f7f361c585258b5b01
}
function TSvn2RevisionApplication.GetGitBranchPoint: string;
const
  READ_BYTES = 2048;
var
  p: TProcessUTF8;
  MemStream: TMemoryStream;
  n, i, NumBytes, BytesRead: integer;
  s: string;
  sl: TStringList;
begin
  Result := '';
  BytesRead := 0;
  sl := Nil;
  MemStream := TMemoryStream.Create;
  p := TProcessUTF8.Create(nil);
  try
    p.CommandLine := 'git rev-list --boundary HEAD...' + MainBranch;
    p.Options := [poUsePipes];
    p.Execute;
    // read while the process is running
    while p.Running do begin
      MemStream.SetSize(BytesRead + READ_BYTES); // make sure we have room
      // try reading it
      NumBytes := p.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
      if NumBytes > 0 then
        Inc(BytesRead, NumBytes)
      else                                       // no data, wait 100 ms
        Sleep(100);
    end;
    // read last part
    repeat
      MemStream.SetSize(BytesRead + READ_BYTES);
      NumBytes := p.Output.Read((MemStream.Memory + BytesRead)^, READ_BYTES);
      if NumBytes > 0 then
        Inc(BytesRead, NumBytes);
    until NumBytes <= 0;
    MemStream.SetSize(BytesRead);
    sl := TStringList.Create;
    sl.LoadFromStream(MemStream);
    { now search for the '-' marker. Should be the last one, so search in reverse. }
    for i := sl.Count-1 downto 0 do
    begin
      s := sl[i];
      n := Pos('-', s);
      if n > 0 then begin
        Result := Copy(s, 2, Length(s));
        exit;
      end;
    end;
  finally
    sl.Free;
    p.Free;
    MemStream.Free;
  end;
end;

{ Get the branch point, and exact the SVN revision from that commit log }
function TSvn2RevisionApplication.GitRevisionFromGitCommit: boolean;
const
  cBufSize = 80;
var
  sha1: string;
  p: TProcessUTF8;
  Buffer: string;
  n: LongInt;
  s: string;
begin
  Result := False;
  sha1 := GetGitBranchPoint;
  p := TProcessUTF8.Create(nil);
  try
    with p do begin
      CommandLine := 'git show --summary --pretty=format:"%b" ' + sha1;
      Options := [poUsePipes, poWaitOnExit];
      try
        Execute;
        { now process the output }
        SetLength(Buffer, cBufSize);
        s := '';
        repeat
          n := OutPut.Read(Buffer[1], cBufSize);
          s := s + Copy(Buffer, 1, n);
        until n < cBufSize;
        { now search for our marker }
        if (Pos('git-svn-id:', s) > 0) then
        begin
          Result := True;
          RevisionStr := s;
          System.Delete(RevisionStr, 1, Pos('@', RevisionStr));
          System.Delete(RevisionStr, Pos(' ', RevisionStr), Length(RevisionStr));
        end;
      except
        // ignore error, default result is false
      end;
    end;
  finally
    p.Free;
  end;
end;

function TSvn2RevisionApplication.GitDescribeCommit(KeepRevStr: Boolean
  ): boolean;
const
  cBufSize = 80;
var
  p: TProcessUTF8;
  Buffer: string;
  n: LongInt;
  s: string;
begin
  Result := False;
  p := TProcessUTF8.Create(nil);
  try
    with p do begin
      CommandLine := 'git describe --always ';
      //CommandLine := 'git describe --always --match ''main*'' --match ''fixes*'' --match ''release*'' --match ''b-*'' --match ''f-*'' ';
      Options := [poUsePipes, poWaitOnExit];
      try
        Execute;
        { now process the output }
        SetLength(Buffer, cBufSize);
        s := '';
        repeat
          n := OutPut.Read(Buffer[1], cBufSize);
          s := s + Copy(Buffer, 1, n);
        until n < cBufSize;
        { now search for our marker }
        if PosSet([#10,#13], s) > 0 then
          System.Delete(s, PosSet([#10,#13], s), Length(s));
        if (s <> '') then
        begin
          Result := True;
          if KeepRevStr and (RevisionStr <> '') then
            s := ' (' + RevisionStr + ')';
          RevisionStr := s;
        end;
      except
        // ignore error, default result is false
      end;
    end;
  finally
    p.Free;
  end;
end;

procedure TSvn2RevisionApplication.Run;
begin
  if not ParamsValid then
    ShowHelp;

  if not CanCreateRevisionInc then exit;

  if UseStdOut then begin
    if FindRevision then
      debugln(RevisionStr);
  end
  else if FindRevision or not IsValidRevisionInc then
    WriteRevisionInc;
end;

begin
  Application := TSvn2RevisionApplication.Create(nil);
  Application.Run;
  Application.Free;
end.

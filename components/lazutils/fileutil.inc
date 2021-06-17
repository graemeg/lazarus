{%MainUnit fileutil.pas}
{******************************************************************************
                                  Fileutil
 ******************************************************************************

 *****************************************************************************
  This file is part of LazUtils.

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

// ToDo: For ExpandUNCFileNameUTF8
//
// Don't convert to and from Sys, because this RTL routines
// simply work in simple string operations, without calling native
// APIs which would really require Ansi
//
// The Ansi conversion just ruins Unicode strings
//
// See bug http://bugs.freepascal.org/view.php?id=20229
// It needs fixing like we did for LazFileUtils.ExpandFileNameUtf8(Filename) on Windows

function ExpandUNCFileNameUTF8(const FileName: string): string;
begin
  Result:=SysUtils.ExpandUNCFileName(Filename);
end;

function FileSize(const Filename: string): int64;
begin
  Result := FileSizeUtf8(FileName);
end;

function ComparePhysicalFilenames(const Filename1, Filename2: string): integer;
var
  File1: String;
  File2: String;
begin
  File1:=GetPhysicalFilename(Filename1,pfeOriginal);
  File2:=GetPhysicalFilename(Filename2,pfeOriginal);
  Result:=LazFileUtils.CompareFilenames(File1,File2);
end;

function CompareFilenames(Filename1: PChar; Len1: integer;
  Filename2: PChar; Len2: integer; ResolveLinks: boolean): integer;
var
  File1: string;
  File2: string;
  {$IFNDEF NotLiteralFilenames}
  i: Integer;
  {$ENDIF}
begin
  if (Len1=0) or (Len2=0) then begin
    Result:=Len1-Len2;
    exit;
  end;
  if ResolveLinks then begin
    SetLength(File1{%H-},Len1);
    System.Move(Filename1^,File1[1],Len1);
    SetLength(File2{%H-},Len2);
    System.Move(Filename2^,File2[1],Len2);
    if ResolveLinks then
      Result:=ComparePhysicalFilenames(File1,File2)
    else
      Result:=LazFileUtils.CompareFilenames(File1,File2);
  end else begin
    {$IFDEF NotLiteralFilenames}
    SetLength(File1,Len1);
    System.Move(Filename1^,File1[1],Len1);
    SetLength(File2,Len2);
    System.Move(Filename2^,File2[1],Len2);
    Result:=LazFileUtils.CompareFilenames(File1,File2);
    {$ELSE}
    Result:=0;
    i:=0;
    while (Result=0) and ((i<Len1) and (i<Len2)) do begin
      Result:=Ord(Filename1[i])
             -Ord(Filename2[i]);
      Inc(i);
    end;
    if Result=0 Then
      Result:=Len1-Len2;
    {$ENDIF}
  end;
end;

function FilenameHasPascalExt(const Filename: string): boolean;
var
  i, FnPos: Integer;
  FnExt: String;
begin
  FnPos := length(Filename);
  while (FnPos>=1) and (Filename[FnPos]<>'.') do dec(FnPos);
  if FnPos < 1 then
    exit(false);          // no extension in filename
  FnExt := Copy(Filename, FnPos, length(FileName));
  for i:=Low(PascalFileExt) to High(PascalFileExt) do
    if CompareText(FnExt,PascalFileExt[i])=0 then
      exit(true);
  Result:=false;
end;

function DeleteDirectory(const DirectoryName: string; OnlyChildren: boolean): boolean;
const
  //Don't follow symlinks on *nix, just delete them
  DeleteMask = faAnyFile {$ifdef unix} or faSymLink{%H-} {$endif unix};
var
  FileInfo: TSearchRec;
  CurSrcDir: String;
  CurFilename: String;
begin
  Result:=false;
  CurSrcDir:=CleanAndExpandDirectory(DirectoryName);
  if FindFirstUTF8(CurSrcDir+GetAllFilesMask,DeleteMask,FileInfo)=0 then begin
    repeat
      // check if special file
      if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='') then
        continue;
      CurFilename:=CurSrcDir+FileInfo.Name;
      if ((FileInfo.Attr and faDirectory)>0)
         {$ifdef unix} and ((FileInfo.Attr and faSymLink{%H-})=0) {$endif unix} then begin
        if not DeleteDirectory(CurFilename,false) then exit;
      end else begin
        if not DeleteFileUTF8(CurFilename) then exit;
      end;
    until FindNextUTF8(FileInfo)<>0;
  end;
  FindCloseUTF8(FileInfo);
  if (not OnlyChildren) and (not RemoveDirUTF8(CurSrcDir)) then exit;
  Result:=true;
end;

function ProgramDirectory: string;
var
  Flags: TSearchFileInPathFlags;
begin
  Result:=ParamStrUTF8(0);
  if ExtractFilePath(Result)='' then begin
    // program was started via PATH
    {$IFDEF WINDOWS}
    Flags:=[];
    {$ELSE}
    Flags:=[sffDontSearchInBasePath];
    {$ENDIF}
    Result:=SearchFileInPath(Result,'',GetEnvironmentVariableUTF8('PATH'),PathSeparator,Flags);
  end;
  // resolve links
  Result:=GetPhysicalFilename(Result,pfeOriginal);
  // extract file path and expand to full name
  Result:=ExpandFileNameUTF8(ExtractFilePath(Result));
end;

function ProgramDirectoryWithBundle: string;
const
  BundlePostFix='.app/Contents/MacOS';
begin
  Result:=ProgramDirectory;
  if (RightStr(ChompPathDelim(Result),Length(BundlePostFix))=BundlePostFix) then
    Result:=ExtractFilePath(LeftStr(Result,Length(Result)-Length(BundlePostFix)));
end;

function FileIsInPath(const Filename, Path: string): boolean;
var
  ExpFile: String;
  ExpPath: String;
  l: integer;
begin
  ExpFile:=CleanAndExpandFilename(Filename);
  ExpPath:=CleanAndExpandDirectory(Path);
  l:=length(ExpPath);
  Result:=(l>0) and (length(ExpFile)>l) and (ExpFile[l] in AllowDirectorySeparators)
          and (CompareFilenames(ExpPath,LeftStr(ExpFile,l))=0);
end;

function FileIsInDirectory(const Filename, Directory: string): boolean;
var
  ExpFile: String;
  ExpDir: String;
  LenFile: Integer;
  LenDir: Integer;
  p: LongInt;
begin
  ExpFile:=CleanAndExpandFilename(Filename);
  ExpDir:=CleanAndExpandDirectory(Directory);
  LenFile:=length(ExpFile);
  LenDir:=length(ExpDir);
  p:=LenFile;
  while (p>0) and not (ExpFile[p] in AllowDirectorySeparators) do dec(p);
  Result:=(p=LenDir) and (p<LenFile)
          and (CompareFilenames(ExpDir,LeftStr(ExpFile,p))=0);
end;

function ExtractFileNameWithoutExt(const AFilename: string): string;
begin
  Result:=LazFileUtils.ExtractFileNameWithoutExt(AFilename);
end;

function CreateAbsoluteSearchPath(const SearchPath, BaseDirectory: string): string;
begin
  Result:=LazFileUtils.CreateAbsoluteSearchPath(SearchPath, BaseDirectory);
end;

function CreateAbsolutePath(const Filename, BaseDirectory: string): string;
begin
  Result:=LazFileUtils.CreateAbsolutePath(Filename, BaseDirectory);
end;

function CopyFile(const SrcFilename, DestFilename: string;
  Flags: TCopyFileFlags; ExceptionOnError: Boolean): boolean;
var
  SrcHandle: THandle;
  DestHandle: THandle;
  Buffer: array[1..4096] of byte;
  ReadCount, WriteCount, TryCount: LongInt;
begin
  Result := False;
  // check overwrite
  if (not (cffOverwriteFile in Flags)) and FileExistsUTF8(DestFileName) then
    exit;
  // check directory
  if (cffCreateDestDirectory in Flags)
  and (not DirectoryExistsUTF8(ExtractFilePath(DestFileName)))
  and (not ForceDirectoriesUTF8(ExtractFilePath(DestFileName))) then
    exit;
  TryCount := 0;
  While TryCount <> 3 Do Begin
    SrcHandle := FileOpenUTF8(SrcFilename, fmOpenRead or fmShareDenyWrite);
    if THandle(SrcHandle)=feInvalidHandle then Begin
      Inc(TryCount);
      Sleep(10);
    End
    Else Begin
      TryCount := 0;
      Break;
    End;
  End;
  If TryCount > 0 Then
  begin
    if ExceptionOnError then
      raise EFOpenError.CreateFmt({SFOpenError}'Unable to open file "%s"', [SrcFilename])
    else
      exit;
  end;
  try
    DestHandle := FileCreateUTF8(DestFileName);
    if (THandle(DestHandle)=feInvalidHandle) then
    begin
      if ExceptionOnError then
        raise EFCreateError.CreateFmt({SFCreateError}'Unable to create file "%s"',[DestFileName])
      else
        Exit;
    end;
    try
      repeat
        ReadCount:=FileRead(SrcHandle,Buffer[1],High(Buffer));
        if ReadCount<=0 then break;
        WriteCount:=FileWrite(DestHandle,Buffer[1],ReadCount);
        if WriteCount<ReadCount then
        begin
          if ExceptionOnError then
            raise EWriteError.CreateFmt({SFCreateError}'Unable to write to file "%s"',[DestFileName])
          else
            Exit;
        end;
      until false;
    finally
      FileClose(DestHandle);
    end;
    if (cffPreserveTime in Flags) then
      FileSetDateUTF8(DestFilename, FileGetDate(SrcHandle));
    Result := True;
  finally
    FileClose(SrcHandle);
  end;
end;

function CopyFile(const SrcFilename, DestFilename: string;
  PreserveTime: boolean; ExceptionOnError: Boolean): boolean;
// Flags parameter can be used for the same thing.
var
  Flags: TCopyFileFlags;
begin
  if PreserveTime then
    Flags:=[cffPreserveTime, cffOverwriteFile]
  else
    Flags:=[cffOverwriteFile];
  Result := CopyFile(SrcFilename, DestFilename, Flags, ExceptionOnError);
end;

{ TCopyDirTree for CopyDirTree function }
type
  TCopyDirTree = class(TFileSearcher)
  private
    FSourceDir: string;
    FTargetDir: string;
    FFlags: TCopyFileFlags;
    FCopyFailedCount: Integer;
  protected
    procedure DoFileFound; override;
    //procedure DoDirectoryFound; override;
  end;

procedure TCopyDirTree.DoFileFound;
var
  NewLoc: string;
begin
  // ToDo: make sure StringReplace works in all situations !
  NewLoc:=StringReplace(FileName, FSourceDir, FTargetDir, []);
  if not CopyFile(FileName, NewLoc, FFlags) then
    Inc(FCopyFailedCount);
end;
{
procedure TCopyDirTree.DoDirectoryFound;
begin
  // Directory is already created by the cffCreateDestDirectory flag.
end;
}
function CopyDirTree(const SourceDir, TargetDir: string; Flags: TCopyFileFlags=[]): Boolean;
var
  Searcher: TCopyDirTree;
begin
  Result:=False;
  Searcher:=TCopyDirTree.Create;
  try
    // Destination directories are always created. User setting has no effect!
    Searcher.FFlags:=Flags+[cffCreateDestDirectory];
    Searcher.FCopyFailedCount:=0;
    Searcher.FSourceDir:=TrimFilename(SetDirSeparators(SourceDir));
    Searcher.FTargetDir:=TrimFilename(SetDirSeparators(TargetDir));

    // Don't even try to copy to a subdirectory of SourceDir.
    //append a pathedelim, otherwise CopyDirTree('/home/user/foo','/home/user/foobar') will fail at this point. Issue #0038644
    {$ifdef CaseInsensitiveFilenames}
      if AnsiStartsText(AppendPathDelim(Searcher.FSourceDir), AppendPathDelim(Searcher.FTargetDir)) then Exit;
    {$ELSE}
      if AnsiStartsStr(AppendPathDelim(Searcher.FSourceDir), AppendPathDelim(Searcher.FTargetDir)) then Exit;
    {$ENDIF}
    Searcher.Search(SourceDir);
    Result:=Searcher.FCopyFailedCount=0;
  finally
    Searcher.Free;
  end;
end;

function GetAllFilesMask: string;
begin
  {$IFDEF WINDOWS}
  Result:='*.*';
  {$ELSE}
  Result:='*';
  {$ENDIF}
end;

function GetExeExt: string;
begin
  {$IFDEF WINDOWS}
  Result:='.exe';
  {$ELSE}
  Result:='';
  {$ENDIF}
end;

function ReadFileToString(const Filename: string): string;
// Read and return the contents of a text file in one slurp.
// Note: FileSize() returns 0 for virtual files at least in Unix like systems.
//       Then use different ways to read contents, eg. TStringList.LoadFromFile();
var
  SrcHandle: THandle;
  ReadCount: LongInt;
  s: String;
begin
  Result := '';
  s:='';
  try
    Setlength(s, FileSize(Filename));
    if s='' then exit;
    SrcHandle := FileOpenUTF8(Filename, fmOpenRead or fmShareDenyWrite);
    if THandle(SrcHandle)=feInvalidHandle then
      exit;
    try
      ReadCount:=FileRead(SrcHandle,s[1],length(s));
      if ReadCount<length(s) then
        exit;
    finally
      FileClose(SrcHandle);
    end;
    Result:=s;
  except
    // ignore errors, Result string will be empty
  end;
end;

function SearchFileInPath(const Filename, BasePath: string; SearchPath: string;
  const Delimiter: string; Flags: TSearchFileInPathFlags): string;
var
  p, StartPos, l, QuoteStart: integer;
  CurPath, Base: string;
begin
//debugln('[SearchFileInPath] Filename="',Filename,'" BasePath="',BasePath,'" SearchPath="',SearchPath,'" Delimiter="',Delimiter,'"');
  if (Filename='') then begin
    Result:='';
    exit;
  end;
  // check if filename absolute
  if FilenameIsAbsolute(Filename) then begin
    if FileExistsUTF8(Filename) then begin
      Result:=CleanAndExpandFilename(Filename);
      exit;
    end else begin
      Result:='';
      exit;
    end;
  end;
  Base:=CleanAndExpandDirectory(BasePath);
  // search in current directory
  if (not (sffDontSearchInBasePath in Flags)) and FileExistsUTF8(Base+Filename) then
    exit(CleanAndExpandFilename(Base+Filename));
  // search in search path
  StartPos:=1;
  l:=length(SearchPath);
  while StartPos<=l do begin
    p:=StartPos;
    while (p<=l) and (pos(SearchPath[p],Delimiter)<1) do
    begin
      if (SearchPath[p]='"') and (sffDequoteSearchPath in Flags) then
      begin
        // For example: Windows allows set path=C:\"a;b c"\d;%path%
        QuoteStart:=p;
        repeat
          inc(p);
        until (p>l) or (SearchPath[p]='"');
        if p<=l then
        begin
          system.delete(SearchPath,p,1);
          system.delete(SearchPath,QuoteStart,1);
          dec(l,2);
          dec(p,2);
        end;
      end;
      inc(p);
    end;
    CurPath:=copy(SearchPath,StartPos,p-StartPos);
    CurPath:=TrimFilename(CurPath);
    StartPos:=p+1;
    if CurPath='' then continue;
    if not FilenameIsAbsolute(CurPath) then
      CurPath:=Base+CurPath;
    Result:=CleanAndExpandFilename(AppendPathDelim(CurPath)+Filename);
    if not FileExistsUTF8(Result) then
      continue;
    if (sffFile in Flags) and DirectoryExistsUTF8(Result) then
      continue;
    if (sffExecutable in Flags) and not FileIsExecutable(Result) then
      continue;
    exit;
  end;
  Result:='';
end;

function SearchAllFilesInPath(const Filename, BasePath, SearchPath,
  Delimiter: string; Flags: TSearchFileInPathFlags): TStrings;
  
  procedure Add(NewFilename: string);
  var
    i: Integer;
  begin
    NewFilename:=TrimFilename(NewFilename);
    if Result<>nil then
      for i:=0 to Result.Count-1 do
        if CompareFilenames(Result[i],NewFilename)=0 then exit;
    if not FileExistsUTF8(NewFilename) then
      exit;
    if (sffFile in Flags) and DirectoryExistsUTF8(NewFilename) then
      exit;
    if (sffExecutable in Flags) and not FileIsExecutable(NewFilename) then
      exit;
    if Result=nil then
      Result:=TStringList.Create;
    Result.Add(NewFilename);
  end;
  
var
  p, StartPos, l: integer;
  CurPath, Base: string;
begin
  Result:=nil;
  if (Filename='') then exit;
  // check if filename absolute
  if FilenameIsAbsolute(Filename) then begin
    Add(CleanAndExpandFilename(Filename));
    exit;
  end;
  Base:=CleanAndExpandDirectory(BasePath);
  // search in current directory
  if (not (sffDontSearchInBasePath in Flags)) then begin
    Add(CleanAndExpandFilename(Base+Filename));
  end;
  // search in search path
  StartPos:=1;
  l:=length(SearchPath);
  while StartPos<=l do begin
    p:=StartPos;
    while (p<=l) and (pos(SearchPath[p],Delimiter)<1) do inc(p);
    CurPath:=TrimFilename(copy(SearchPath,StartPos,p-StartPos));
    if CurPath<>'' then begin
      if not FilenameIsAbsolute(CurPath) then
        CurPath:=Base+CurPath;
      Add(CleanAndExpandFilename(AppendPathDelim(CurPath)+Filename));
    end;
    StartPos:=p+1;
  end;
end;

function FindDiskFilename(const Filename: string): string;
// Searches for the filename case on disk.
// The file must exist.
// For example:
//   If Filename='file' and there is only a 'File' then 'File' will be returned.
var
  StartPos: Integer;
  EndPos: LongInt;
  FileInfo: TSearchRec;
  CurDir: String;
  CurFile: String;
  AliasFile: String;
  Ambiguous: Boolean;
begin
  Result:=Filename;
  if not FileExistsUTF8(Filename) then exit;
  //Sanitize result first (otherwise result can contain things like foo/\bar on Windows)
  Result := ResolveDots(Result);
  // check every directory and filename
  StartPos:=1;
  {$IFDEF WINDOWS}
  // uppercase Drive letter and skip it
  if ((length(Result)>=2) and (Result[1] in ['A'..'Z','a'..'z'])
  and (Result[2]=':')) then begin
    StartPos:=3;
    if Result[1] in ['a'..'z'] then
      Result[1]:=upcase(Result[1]);
  end;
  {$ENDIF}
  repeat
    // skip PathDelim
    while (StartPos<=length(Result)) and (Result[StartPos] in AllowDirectorySeparators) do
      inc(StartPos);
    // find end of filename part
    EndPos:=StartPos;
    while (EndPos<=length(Result)) and not (Result[EndPos] in AllowDirectorySeparators) do
      inc(EndPos);
    if EndPos>StartPos then begin
      // search file
      CurDir:=copy(Result,1,StartPos-1);
      CurFile:=copy(Result,StartPos,EndPos-StartPos);
      AliasFile:='';
      Ambiguous:=false;
      if FindFirstUTF8(CurDir+GetAllFilesMask,faAnyFile,FileInfo)=0 then
      begin
        repeat
          // check if special file
          if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='')
          then
            continue;
          if CompareFilenamesIgnoreCase(FileInfo.Name,CurFile)=0 then begin
            //debugln('FindDiskFilename ',FileInfo.Name,' ',CurFile);
            if FileInfo.Name=CurFile then begin
              // file found, has already the correct name
              AliasFile:='';
              break;
            end else begin
              // alias found, but has not the correct name
              if AliasFile='' then begin
                AliasFile:=FileInfo.Name;
              end else begin
                // there are more than one candidate
                Ambiguous:=true;
              end;
            end;
          end;
        until FindNextUTF8(FileInfo)<>0;
      end;
      FindCloseUTF8(FileInfo);
      if (AliasFile<>'') and (not Ambiguous) then begin
        // better filename found -> replace
        Result:=CurDir+AliasFile+copy(Result,EndPos,length(Result));
      end;
    end;
    StartPos:=EndPos+1;
  until StartPos>length(Result);
end;

function FindDiskFileCaseInsensitive(const Filename: string): string;
var
  FileInfo: TSearchRec;
  ShortFilename: String;
  CurDir: String;
begin
  Result:='';
  CurDir:=ExtractFilePath(ResolveDots(Filename));
  if FindFirstUTF8(CurDir+GetAllFilesMask,faAnyFile, FileInfo)=0 then begin
    ShortFilename:=ExtractFilename(Filename);
    repeat
      // check if special file
      if (FileInfo.Name='.') or (FileInfo.Name='..') or (FileInfo.Name='')
      then
        continue;
      if CompareFilenamesIgnoreCase(FileInfo.Name,ShortFilename)<>0 then
        continue;
      if FileInfo.Name=ShortFilename then begin
        // fits exactly
        //Don't return (unaltered) Filename: otherwise possible changes by ResolveDots get lost
        Result:=CurDir+FileInfo.Name;
        break;
      end;
      // fits case insensitive
      Result:=CurDir+FileInfo.Name;
    until FindNextUTF8(FileInfo)<>0;
  end;
  FindCloseUTF8(FileInfo);
end;

function FindDefaultExecutablePath(const Executable: string;
  const BaseDir: string): string;
var
  Env: string;
begin
  if FilenameIsAbsolute(Executable) then begin
    Result:=Executable;
    if FileExistsUTF8(Result) then exit;
    {$IFDEF Windows}
    if ExtractFileExt(Result)='' then begin
      Result:=Result+'.exe';
      if FileExistsUTF8(Result) then exit;
    end;
    {$ENDIF}
  end else begin
    Env:=GetEnvironmentVariableUTF8('PATH');
    Result:=SearchFileInPath(Executable, BaseDir, Env, PathSeparator, sffFindProgramInPath);
    if Result<>'' then exit;
    {$IFDEF Windows}
    if ExtractFileExt(Executable)='' then begin
      Result:=SearchFileInPath(Executable+'.exe', BaseDir, Env, PathSeparator, sffFindProgramInPath);
      if Result<>'' then exit;
    end;
    {$ENDIF}
  end;
  Result:='';
end;

{ TListFileSearcher }

procedure TListFileSearcher.DoFileFound;
begin
  FList.Add(FileName);
  inherited;
end;

constructor TListFileSearcher.Create(AList: TStrings);
begin
  inherited Create;
  FList := AList;
end;

procedure FindAllFiles(AList: TStrings; const SearchPath: String;
  const SearchMask: String; SearchSubDirs: Boolean; DirAttr: Word;
  MaskSeparator: char; PathSeparator: char);
var
  Searcher: TListFileSearcher;
begin
  Searcher := TListFileSearcher.Create(AList);
  Searcher.DirectoryAttribute := DirAttr;
  Searcher.MaskSeparator := MaskSeparator;
  Searcher.PathSeparator := PathSeparator;
  try
    Searcher.Search(SearchPath, SearchMask, SearchSubDirs);
  finally
    Searcher.Free;
  end;
end;

function FindAllFiles(const SearchPath: String; const SearchMask: String;
  SearchSubDirs: Boolean; DirAttr: Word;
  MaskSeparator: char; PathSeparator: char): TStringList;
begin
  Result := TStringList.Create;
  FindAllFiles(Result, SearchPath, SearchMask, SearchSubDirs, DirAttr, MaskSeparator, PathSeparator);
end;

{ TListDirectoriesSearcher }

constructor TListDirectoriesSearcher.Create(AList: TStrings);
begin
  inherited Create;
  FDirectoriesList := AList;
end;

procedure TListDirectoriesSearcher.DoDirectoryFound;
begin
  FDirectoriesList.Add(FileName);
  inherited;
end;

function FindAllDirectories(const SearchPath : string;
  SearchSubDirs: Boolean; PathSeparator: char): TStringList;
begin
  Result := TStringList.Create;
  FindAllDirectories(Result, SearchPath, SearchSubDirs, PathSeparator);
end;

procedure FindAllDirectories(AList: TStrings; const SearchPath: String;
  SearchSubDirs: Boolean; PathSeparator: char);
var
  Searcher :TFileSearcher;
begin
  Assert(AList <> nil);
  Searcher := TListDirectoriesSearcher.Create(AList);
  Searcher.PathSeparator := PathSeparator;
  try
    Searcher.Search(SearchPath, AllFilesMask, SearchSubDirs);
  finally
    Searcher.Free;
  end;
end;

{ TFileIterator }

function TFileIterator.GetFileName: String;
begin
  Result := FPath + FFileInfo.Name;
end;

procedure TFileIterator.Stop;
begin
  FSearching := False;
end;

function TFileIterator.IsDirectory: Boolean;
begin
  Result := (FFileInfo.Attr and faDirectory) <> 0;
end;

{ TFileSearcher }

procedure TFileSearcher.RaiseSearchingError;
begin
  raise Exception.Create('The file searcher is already searching!');
end;

procedure TFileSearcher.DoDirectoryEnter;
begin
  if Assigned(FonDirectoryEnter) then FOnDirectoryEnter(Self);
end;

procedure TFileSearcher.DoDirectoryFound;
begin
  if Assigned(FOnDirectoryFound) then OnDirectoryFound(Self);
end;

procedure TFileSearcher.DoFileFound;
begin
  if Assigned(FOnFileFound) then OnFileFound(Self);
end;

constructor TFileSearcher.Create;
begin
  inherited Create;
  FMaskSeparator := ';';
  FPathSeparator := ';';
  FFollowSymLink := True;
  FFileAttribute := faAnyFile;
  FDirectoryAttribute := faDirectory;
  FSearching := False;
end;

procedure TFileSearcher.Search(const ASearchPath: String; const ASearchMask: String;
  ASearchSubDirs: Boolean; CaseSensitive: Boolean = False);
var
  MaskList: TMaskList;
  SearchDirectories: TStringList;

  procedure DoSearch(const APath: String; const ALevel: Integer);
  var
    P: String;
    PathInfo: TSearchRec;
  begin
    P := APath + AllDirectoryEntriesMask;

    if FindFirstUTF8(P, FileAttribute, PathInfo) = 0 then
    try
      repeat
        // skip special files
        if (PathInfo.Name = '.') or (PathInfo.Name = '..') or
          (PathInfo.Name = '') then Continue;
        // Deal with both files and directories
        if (PathInfo.Attr and faDirectory) = 0 then
        begin             // File
          {$IFDEF Windows}
          if (MaskList = nil) or MaskList.MatchesWindowsMask(PathInfo.Name)
          {$ELSE}
          if (MaskList = nil) or MaskList.Matches(PathInfo.Name)
          {$ENDIF}
          then begin
            FPath := APath;
            FLevel := ALevel;
            FFileInfo := PathInfo;
            DoFileFound;
          end;
        end
        else begin        // Directory
          FPath := APath;
          FLevel := ALevel;
          FFileInfo := PathInfo;
          DoDirectoryFound;
        end;

      until (FindNextUTF8(PathInfo) <> 0) or not FSearching;
    finally
      FindCloseUTF8(PathInfo);
    end;

    if ASearchSubDirs or (ALevel > 0) then
      // search recursively in directories
      if FindFirstUTF8(P, DirectoryAttribute, PathInfo) = 0 then
      try
        repeat
          if (PathInfo.Name = '.') or (PathInfo.Name = '..') or
             (PathInfo.Name = '') or ((PathInfo.Attr and faDirectory) = 0) or
             (not FFollowSymLink and FileIsSymlink(APath + PathInfo.Name))
          then Continue;

          FPath := APath;
          FLevel := ALevel;
          FFileInfo := PathInfo;
          DoDirectoryEnter;
          if not FSearching then Break;

          DoSearch(AppendPathDelim(APath + PathInfo.Name), Succ(ALevel));

        until (FindNextUTF8(PathInfo) <> 0);
      finally
        FindCloseUTF8(PathInfo);
      end;
  end;

var
  p1, p2: SizeInt;
  i: Integer;
  Dir: String;
  OtherDir: String;
  MaskOptions: TMaskOptions;
begin
  if FSearching then RaiseSearchingError;
  if CaseSensitive then
    MaskOptions := [moCaseSensitive]
  else
    MaskOptions := [];
  MaskList := TMaskList.Create(ASearchMask, FMaskSeparator, MaskOptions);
  // empty mask = all files mask
  if MaskList.Count = 0 then
    FreeAndNil(MaskList);

  FSearching := True;
  SearchDirectories:=TStringList.Create;
  try
    p1:=1;
    while p1<=Length(ASearchPath) do
    begin
      p2:=PosEx(FPathSeparator,ASearchPath,p1);
      if p2<1 then
        p2:=length(ASearchPath)+1;
      Dir:=ResolveDots(Copy(ASearchPath,p1,p2-p1));
      p1:=p2+1;
      if Dir='' then continue;
      Dir:=ChompPathDelim(Dir);
      for i:=SearchDirectories.Count-1 downto 0 do
      begin
        OtherDir:=SearchDirectories[i];
        if (CompareFilenames(Dir,OtherDir)=0)
        or (ASearchSubDirs and (FileIsInPath(Dir,OtherDir))) then
        begin
          // directory Dir is already searched
          Dir:='';
          break;
        end;
        if ASearchSubDirs and FileIsInPath(OtherDir,Dir) then
          // directory Dir includes the old directory => delete
          SearchDirectories.Delete(i);
      end;
      if Dir<>'' then
        SearchDirectories.Add(Dir);
    end;
    //Search currentdirectory if ASearchPath = ''
    if (SearchDirectories.Count=0) then
      DoSearch('',0)
    else
    begin
      for i:=0 to SearchDirectories.Count-1 do
        DoSearch(AppendPathDelim(SearchDirectories[i]), 0);
    end;
  finally
    SearchDirectories.Free;
    FSearching := False;
    MaskList.Free;
  end;
end;


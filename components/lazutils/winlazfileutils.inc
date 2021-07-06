{%MainUnit lazfileutils.pas}


function ReadAllLinks(const Filename: string;
                      ExceptionOnError: boolean): string;
begin
  // not supported under Windows
  Result:=Filename;
end;

function GetPhysicalFilename(const Filename: string;
        OnError: TPhysicalFilenameOnError): string;
begin
  if OnError=pfeEmpty then ;
  Result:=Filename;
end;


// ******** Start of WideString specific implementations ************

function GetCurrentDirUtf8: String;
var
  U: UnicodeString;
begin
  System.GetDir(0, U{%H-});
  // Need to do an explicit encode to utf8, if compiled with "-dDisableUtf8RTL"
  Result := UTF8Encode(U);
end;

procedure GetDirUtf8(DriveNr: Byte; var Dir: String);
var
  U: UnicodeString;
begin
  {$PUSH}
  {$IOCHECKS OFF}
  GetDir(DriveNr, U{%H-});
  if IOResult <> 0 then
    U := UnicodeString(Chr(DriveNr + Ord('A') - 1) + ':\');
  {$POP}
  // Need to do an explicit encode to utf8, if compiled with "-dDisableUtf8RTL"
  Dir := UTF8Encode(U);
end;

function FileOpenUtf8(Const FileName : string; Mode : Integer) : THandle;
begin
  Result := SysUtils.FileOpen(FileName, Mode);
end;

function FileCreateUTF8(Const FileName : string) : THandle;
begin
  Result := FileCreateUtf8(FileName, fmShareExclusive, 0);
end;

function FileCreateUTF8(Const FileName : string; Rights: Cardinal) : THandle;
begin
  Result := FileCreateUtf8(FileName, fmShareExclusive, Rights);
end;

function FileCreateUtf8(Const FileName : string;  ShareMode: Integer; Rights: Cardinal) : THandle;
begin
  Result := SysUtils.FileCreate(FileName, ShareMode, Rights);
end;

function FileGetAttrUtf8(const FileName: String): Longint;
begin
  Result := SysUtils.FileGetAttr(FileName);
end;

function FileSetAttrUtf8(const Filename: String; Attr: longint): Longint;
begin
  Result := SysUtils.FileSetAttr(FileName, Attr);
end;

function FileAgeUtf8(const FileName: String): Longint;
begin
  Result := SysUtils.FileAge(FileName);
end;

function FileSetDateUtf8(const FileName: String; Age: Longint): Longint;
begin
  Result := SysUtils.FileSetDate(FileName, Age);
end;

function FileSizeUtf8(const Filename: string): int64;
var
  R: TSearchRec;
begin
  if SysUtils.FindFirst(FileName, faAnyFile, R) = 0 then
  begin
    Result := R.Size;
    SysUtils.FindClose(R);
  end
  else
    Result := -1;
end;

function CreateDirUtf8(const NewDir: String): Boolean;
begin
  Result := SysUtils.CreateDir(NewDir);
end;

function RemoveDirUtf8(const Dir: String): Boolean;
begin
  Result := SysUtils.RemoveDir(Dir);
end;

function DeleteFileUtf8(const FileName: String): Boolean;
begin
  Result := SysUtils.DeleteFile(FileName);
end;

function RenameFileUtf8(const OldName, NewName: String): Boolean;
begin
  Result := SysUtils.RenameFile(OldName, NewName);
end;

function SetCurrentDirUtf8(const NewDir: String): Boolean;
begin
  {$ifdef WinCE}
  raise Exception.Create('[SetCurrentDirWide] The concept of the current directory doesn''t exist in Windows CE');
  {$else}
  Result:=Windows.SetCurrentDirectoryW(PWidechar(UnicodeString(NewDir)));
  {$endif}
end;

function FindFirstUtf8(const Path: string; Attr: Longint; out Rslt: TSearchRec): Longint;
begin
  Result := SysUtils.FindFirst(Path, Attr, Rslt);
end;

function FindNextUtf8(var Rslt: TSearchRec): Longint;
begin
  Result := SysUtils.FindNext(Rslt);
end;

{$IFDEF WINCE}
// In WinCE these API calls are in Windows unit
function SHGetFolderPathUTF8(ID :  Integer) : String;
Var
  APath : Array[0..MAX_PATH] of WideChar;
  WS: WideString;
  Len: SizeInt;
begin
  Result := '';
  if SHGetSpecialFolderPath(0, APath, ID, True) then
  begin
    Len := StrLen(APath);
    SetLength(WS, Len);
    System.Move(APath[0], WS[1], Len * SizeOf(WideChar));
    Result := AppendPathDelim(Utf16ToUtf8(WS));
  end
  else
    Result:='';
end;
{$ELSE}

Type
  PFNSHGetFolderPathW = Function(Ahwnd: HWND; Csidl: Integer; Token: THandle; Flags: DWord; Path: PWChar): HRESULT; stdcall;

var
  SHGetFolderPathW : PFNSHGetFolderPathW = Nil;
  CFGDLLHandle : THandle = 0;

Procedure InitDLL;
Var
  pathBuf: array[0..MAX_PATH-1] of char;
  pathLength: Integer;
begin
  { Load shfolder.dll using a full path, in order to prevent spoofing (Mantis #18185)
    Don't bother loading shell32.dll because shfolder.dll itself redirects SHGetFolderPath
    to shell32.dll whenever possible. }
  pathLength:=GetSystemDirectory(pathBuf, MAX_PATH);
  if (pathLength>0) and (pathLength<MAX_PATH-14) then { 14=length('\shfolder.dll'#0) }
  begin
    StrLCopy(@pathBuf[pathLength],'\shfolder.dll',MAX_PATH-pathLength-1);
    CFGDLLHandle:=LoadLibrary(pathBuf);

    if (CFGDLLHandle<>0) then
    begin
      Pointer(ShGetFolderPathW):=GetProcAddress(CFGDLLHandle,'SHGetFolderPathW');
      If @ShGetFolderPathW=nil then
      begin
        FreeLibrary(CFGDLLHandle);
        CFGDllHandle:=0;
      end;
    end;
  end;
  If (@ShGetFolderPathW=Nil) then
    Raise Exception.Create('Could not determine SHGetFolderPathW Function');
end;

function SHGetFolderPathUTF8(ID :  Integer) : String;
Var
  APath : Array[0..MAX_PATH] of WideChar;
  WS: WideString;
  Len: SizeInt;
begin
  Result := '';
  if (CFGDLLHandle = 0) then
    InitDLL;
  If (SHGetFolderPathW <> Nil) then
  begin
    FillChar(APath{%H-}, SizeOf(APath), #0);
    if SHGetFolderPathW(0,ID or CSIDL_FLAG_CREATE,0,0,@APATH[0]) = S_OK then
    begin
      Len := StrLen(APath);
      SetLength(WS, Len);
      System.Move(APath[0], WS[1], Len * SizeOf(WideChar));
      Result := AppendPathDelim(Utf16ToUtf8(WS));
    end;
  end
  else
    Result := SysToUtf8(GetWindowsSpecialDir(ID));
end;

{$ENDIF WINCE}

function DGetAppConfigDir({%H-}Global : Boolean) : String;
begin
  Result := ChompPathDelim(ExtractFilePath(ParamStrUtf8(0)));
end;


function GetAppConfigDirUtf8(Global: Boolean; Create: boolean = false): string;
const
  CSIDL_GLOBAL = {$IFDEF WINCE}CSIDL_WINDOWS{$ELSE}CSIDL_COMMON_APPDATA{$ENDIF WINCE};
  CSIDL_LOCAL = {$IFDEF WINCE}CSIDL_APPDATA{$ELSE}CSIDL_LOCAL_APPDATA{$ENDIF};
begin
  If Global then
    Result := SHGetFolderPathUTF8(CSIDL_GLOBAL)
  else
    Result := SHGetFolderPathUTF8(CSIDL_LOCAL);
  If (Result <> '') then
    begin
      if VendorName <> '' then
        Result := AppendPathDelim(Result + VendorName);
      Result := AppendPathDelim(Result + ApplicationName);
    end
  else
    Result := AppendPathDelim(DGetAppConfigDir(Global));
  if Result = '' then exit;
  if Create and not ForceDirectoriesUtf8(Result) then
    raise EInOutError.Create(Format(lrsUnableToCreateConfigDirectoryS,[Result]));
end;

function GetAppConfigFileUtf8(Global: Boolean; SubDir: boolean;
  CreateDir: boolean): string;
var
  Dir: string;
begin
  Result := GetAppConfigDirUtf8(Global);
  if SubDir then
    Result := AppendPathDelim(Result + 'Config');
  Result := Result + ApplicationName + ConfigExtension;
  if not CreateDir then exit;
  Dir := ExtractFilePath(Result);
  if Dir = '' then exit;
  if not ForceDirectoriesUTF8(Dir) then
    raise EInOutError.Create(Format(lrsUnableToCreateConfigDirectoryS,[Dir]));
end;


function GetShellLinkTarget(const FileName: string): string;
{$IFnDEF WINCE}
var
  ShellLinkW: IShellLinkW;
  PersistFile: IPersistFile;
  WideFileName: WideString;
  WidePath: array [0 .. MAX_PATH] of WideChar;
  WinFindData: WIN32_FIND_DATAW;
  {$ENDIF WINCE}
begin
  Result := FileName;
  {$IFnDEF WINCE}
  if FilenameExtIs(FileName, '.lnk') then
  begin
    if (CoCreateInstance(CLSID_ShellLink, nil, CLSCTX_INPROC_SERVER,
                         IShellLinkW, ShellLinkW) = S_OK) then
    if (ShellLinkW.QueryInterface(IPersistFile, PersistFile) = S_OK) then
    begin
      WideFileName := Utf8ToUtf16(FileName);
      FillChar(WinFindData{%H-}, SizeOf(WinFindData), 0);
      if (PersistFile.Load(POleStr(WideFileName), STGM_READ) = S_OK) then
      begin
        if (ShellLinkW.GetPath(WidePath, Length(WidePath),
                               @WinFindData, SLGP_UNCPRIORITY) = S_OK) then
        begin
          Result := Utf16toUtf8(WidePath); // implicit conversion
        end;
      end;
    end;
  end;
  {$ENDIF WINCE}
end;

// ******** End of WideString specific implementations ************


function FilenameIsAbsolute(const TheFilename: string):boolean;
begin
  Result:=FilenameIsWinAbsolute(TheFilename);
end;


function ExpandFileNameUtf8(const FileName: string; {const} BaseDir: String = ''): String;
var
  IsAbs, StartsWithRoot, CanUseBaseDir : Boolean;
  {$ifndef WinCE}
  HasDrive: Boolean;
  FnDrive, CurDrive, BaseDirDrive: Char;
  {$endif}
  CurDir, Fn: String;
begin
  //writeln('LazFileUtils.ExpandFileNameUtf8');
  //writeln('FileName = "',FileName,'"');
  //writeln('BaseDir  = "',BaseDir,'"');

  Fn := FileName;
  //if Filename uses ExtendedLengthPath scheme then it cannot be expanded
  //AND it should not be altered by ForcePathDelims or ResolveDots
  //See: http://msdn.microsoft.com/en-us/library/windows/desktop/aa365247%28v=vs.85%29.aspx
  if (Length(Fn) > 3) and (Fn[1] = PathDelim) and (Fn[2] = PathDelim) and
     (Fn[3] = '?') and (Fn[4] = PathDelim) //Do NOT use AllowDirectorySeparators here!
     then Exit(Fn);
  ForcePathDelims(Fn);
  IsAbs := FileNameIsWinAbsolute(Fn);
  if not IsAbs then
  begin
    StartsWithRoot := (Fn = '\') or
                      ((Length(Fn) > 1) and
                      (Fn[1] = DirectorySeparator) and
                      (Fn[2] <> DirectorySeparator));
    {$ifndef WinCE}
    HasDrive := (Length(Fn) > 1) and
                (Fn[2] = ':') and
                (UpCase(Fn[1]) in ['A'..'Z']);

    if HasDrive then
    begin
      FnDrive := UpCase(Fn[1]);
      GetDirUtf8(Byte(FnDrive)-64, CurDir{%H-});
      CurDrive := UpCase(GetCurrentDirUtf8[1]);
    end
    else
    begin
      CurDir := GetCurrentDirUtf8;
      FnDrive := UpCase(CurDir[1]);
      CurDrive := FnDrive;
    end;

    //writeln('HasDrive = ',HasDrive,' Fn = ',Fn);
    //writeln('CurDir = ',CurDir);
    //writeln('CurDrive = ',CurDrive);
    //writeln('FnDrive  = ',FnDrive);

    if (Length(BaseDir) > 1) and (UpCase(BaseDir[1]) in ['A'..'Z']) and (BaseDir[2] = ':') then
    begin
      BaseDirDrive := BaseDir[1]
    end
    else
    begin
      if HasDrive then
        BaseDirDrive := CurDrive
      else
        BaseDirDrive := #0;
    end;

    //You cannot use BaseDir if both FileName and BaseDir includes a drive and they are not the same
    CanUseBaseDir := ((BaseDirDrive = #0) or
                     (not HasDrive) or
                     (HasDrive and (FnDrive = BaseDirDrive)))
                     and (BaseDir <> '');

    //writeln('CanUseBaseDir = ',CanUseBaseDir);

    if not HasDrive and StartsWithRoot and not CanUseBaseDir then
    begin
      //writeln('HasDrive and StartsWithRoot');
      Fn := Copy(CurDir,1,2) + Fn;
      HasDrive := True;
      IsAbs := True;
    end;
    //FileNames like C:foo, strip Driveletter + colon
    if HasDrive and not IsAbs then Delete(Fn,1,2);

    //writeln('HasDrive = ',Hasdrive,' Fn = ',Fn);
    {$else}
    CanUseBaseDir := True;
    {$endif WinCE}
  end;
  if IsAbs then
  begin
    //writeln('IsAbs = True -> Exit');
    Result := ResolveDots(Fn);
  end
  else
  begin
    if not CanUseBaseDir or (BaseDir = '') then
      Fn := IncludeTrailingPathDelimiter(CurDir) + Fn
    else
    begin
      if (Length(Fn) > 0) and (Fn[1] = DirectorySeparator) then Delete(Fn,1,1);
      Fn := IncludeTrailingPathDelimiter(BaseDir) + Fn;
    end;

    Fn := ResolveDots(Fn);
    //if BaseDir is something like 'z:foo\' or '\' then this needs to be expanded as well
    if not FileNameIsAbsolute(Fn) then
      Fn := ExpandFileNameUtf8(Fn, '');
    Result := Fn;
  end;
end;

function FileExistsUTF8(const Filename: string): boolean;
begin
  Result := SysUtils.FileExists(Filename);
end;

{$If FPC_FULLVERSION < 30301}
{ Note: temporary fix for issue #39120.
  DirectoryIsMountPoint() fixes mount points not being detected by SysUtils.DirectoryExists() which
  causes DirectoryExistsUTF8() to return an invalid value when applied to a mount point. This in
  turn causes the IDE to not being able to rebuild itself when installed inside a mount point.

  This patch should be removed when the minimum required FPC version contains the fixed
  DirectoryExists() function. (will be fixed in FPC 3.2.4?) }
function DirectoryIsMountPoint(const Directory: string): boolean;
{$ifndef wince}
const
  IO_REPARSE_TAG_MOUNT_POINT = $A0000003;
var
  Attr: Longint;
  Rec: TSearchRec;
{$endif}
begin
{$ifndef wince}
  Attr := FileGetAttrUTF8(Directory);
  if (Attr <> -1) and (Attr and FILE_ATTRIBUTE_REPARSE_POINT <> 0) then
  begin
    FindFirstUTF8(Directory, Attr, Rec);
    if Rec.FindHandle <> feInvalidHandle then
    begin
      Windows.FindClose(Rec.FindHandle);
      Result := Rec.FindData.dwReserved0 = IO_REPARSE_TAG_MOUNT_POINT;
    end
    else
      Result := False;
  end
  else
{$endif}
    Result := False;
end;
{$endIf}

function DirectoryExistsUTF8(const Directory: string): boolean;
begin
  Result := SysUtils.DirectoryExists(Directory)
  {$If FPC_FULLVERSION < 30301}
    or DirectoryIsMountPoint(Directory)
  {$endIf};
end;

function FileIsExecutable(const AFilename: string): boolean;
begin
  Result:=FileExistsUTF8(AFilename);
end;

procedure CheckIfFileIsExecutable(const AFilename: string);
begin
  // TProcess does not report, if a program can not be executed
  // to get good error messages consider the OS
  if not FileExistsUTF8(AFilename) then begin
    raise Exception.Create(Format(lrsFileDoesNotExist, [AFilename]));
  end;
  if DirPathExists(AFilename) then begin
    raise Exception.Create(Format(lrsFileIsADirectoryAndNotAnExecutable, [
      AFilename]));
  end;
end;

function FileIsSymlink(const AFilename: string): boolean;
{$ifndef wince}
const
  IO_REPARSE_TAG_MOUNT_POINT = $A0000003;
  IO_REPARSE_TAG_SYMLINK     = $A000000C;
var
  Attr: Longint;
  Rec: TSearchRec;
{$endif}
begin
{$ifndef wince}
  Attr := FileGetAttrUTF8(AFilename);
  if (Attr <> -1) and (Attr and FILE_ATTRIBUTE_REPARSE_POINT <> 0) then
  begin
    FindFirstUTF8(AFilename, Attr, Rec);
    if Rec.FindHandle <> feInvalidHandle then
    begin
      Windows.FindClose(Rec.FindHandle);
      Result := (Rec.FindData.dwReserved0 = IO_REPARSE_TAG_SYMLINK) or (Rec.FindData.dwReserved0 = IO_REPARSE_TAG_MOUNT_POINT);
    end
    else
      Result := False;
  end
  else
{$endif}
    Result := False;
end;

procedure CheckIfFileIsSymlink(const AFilename: string);
begin
  // to get good error messages consider the OS
  if not FileExistsUTF8(AFilename) then begin
    raise Exception.Create(Format(lrsFileDoesNotExist, [AFilename]));
  end;
  if not FileIsSymLink(AFilename) then
    raise Exception.Create(Format(lrsIsNotASymbolicLink, [AFilename]));
end;


function FileIsHardLink(const AFilename: string): boolean;
{$ifndef wince}
var
  H: THandle;
  FileInfo: BY_HANDLE_FILE_INFORMATION;
  {$endif}
begin
  Result := false;
  {$ifndef wince}
  //HardLinks are not supported in Win9x platform
  if (Win32Platform = VER_PLATFORM_WIN32_WINDOWS) then Exit;
  H := FileOpenUtf8(aFilename, fmOpenRead);
  if (H <> feInvalidHandle) then
  begin
    FillChar(FileInfo{%H-}, SizeOf(BY_HANDLE_FILE_INFORMATION),0);
    if GetFileInformationByHandle(H, FileInfo) then
      Result := (FileInfo.nNumberOfLinks > 1);
    FileClose(H);
  end;
  {$endif}
end;

function FileIsReadable(const AFilename: string): boolean;
begin
  Result:=FileExistsUTF8(AFilename);
end;

function FileIsWritable(const AFilename: string): boolean;
begin
  Result := ((FileGetAttrUTF8(AFilename) and faReadOnly) = 0);
end;


function IsUNCPath(const Path: String): Boolean;
begin
  Result := (Length(Path) > 2) and (Path[1] in AllowDirectorySeparators) and (Path[2] in AllowDirectorySeparators);
end;

function ExtractUNCVolume(const Path: String): String;
var
  I, Len: Integer;

  // the next function reuses Len variable
  function NextPathDelim(const Start: Integer): Integer;// inline;
  begin
    Result := Start;
    while (Result <= Len) and not (Path[Result] in AllowDirectorySeparators) do
      inc(Result);
  end;

begin
  if not IsUNCPath(Path) then
    Exit('');
  I := 3;
  Len := Length(Path);
  if Path[I] = '?' then
  begin
    // Long UNC path form like:
    // \\?\UNC\ComputerName\SharedFolder\Resource or
    // \\?\C:\Directory
    inc(I);
    if not (Path[I] in AllowDirectorySeparators) then
      Exit('');
    if CompareText(Copy(Path, I+1, 3), 'UNC') = 0 then
    begin
      inc(I, 4);
      if I < Len then
        I := NextPathDelim(I + 1);
      if I < Len then
        I := NextPathDelim(I + 1);
    end;
  end
  else
  begin
    I := NextPathDelim(I);
    if I < Len then
      I := NextPathDelim(I + 1);
  end;
  Result := Copy(Path, 1, I);
end;

function GetFileDescription(const AFilename: string): string;
begin
  // date + time
  Result:=lrsModified;
  try
    Result:=Result+FormatDateTime('DD/MM/YYYY hh:mm',
                           FileDateToDateTime(FileAgeUTF8(AFilename)));
  except
    Result:=Result+'?';
  end;
end;


procedure InitLazFileUtils;
begin
end;

procedure FinalizeLazFileUtils;
begin
  {$IFnDEF WINCE}
  if CFGDLLHandle <> 0 then
    FreeLibrary(CFGDllHandle);
  {$ENDIF WINCE}
end;

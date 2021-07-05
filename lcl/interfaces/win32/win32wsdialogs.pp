{ $Id$}
{
 *****************************************************************************
 *                             Win32WSDialogs.pp                             *
 *                             -----------------                             *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Win32WSDialogs;

{$mode objfpc}{$H+}
{$I win32defines.inc}

interface

uses
////////////////////////////////////////////////////
// I M P O R T A N T
////////////////////////////////////////////////////
// To get as little as posible circles,
// uncomment only when needed for registration
////////////////////////////////////////////////////
// rtl
  Windows, shlobj, ShellApi, ActiveX, SysUtils, Classes, CommDlg,
// lcl
  LCLProc, LCLType, Dialogs, Controls, Graphics, Forms, Masks,
  // LazUtils
  {$ifdef DebugCommonDialogEvents}
  UITypes,
  {$endif}
  LazFileUtils, LazUTF8,
// ws
  WSDialogs, WSLCLClasses, Win32Extra, Win32Int, InterfaceBase,
  Win32Proc;

type
  TApplicationState = record
    ActiveWindow: HWND;
    FocusedWindow: HWND;
    DisabledWindows: TList;
  end;

  TOpenFileDialogRec = record
    Dialog: TFileDialog;
    AnsiFolderName: string;
    AnsiFileNames: string;
    UnicodeFolderName: widestring;
    UnicodeFileNames: widestring
  end;
  POpenFileDialogRec = ^TOpenFileDialogRec;

  { TWin32WSCommonDialog }

  TWin32WSCommonDialog = class(TWSCommonDialog)
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class procedure DestroyHandle(const ACommonDialog: TCommonDialog); override;
  end;

  { TWin32WSFileDialog }

  TWin32WSFileDialog = class(TWSFileDialog)
  published
  end;

  { TWin32WSOpenDialog }

  TWin32WSOpenDialog = class(TWSOpenDialog)
  public
    class function GetVistaOptions(Options: TOpenOptions; SelectFolder: Boolean): FileOpenDialogOptions;

    class procedure SetupVistaFileDialog(ADialog: IFileDialog; const AOpenDialog: TOpenDialog);
    class function ProcessVistaDialogResult(ADialog: IFileDialog; const AOpenDialog: TOpenDialog): HResult;
    class procedure VistaDialogShowModal(ADialog: IFileDialog; const AOpenDialog: TOpenDialog);
    class function GetFileName(ShellItem: IShellItem): String;
    class function GetParentWnd: HWND;
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class procedure DestroyHandle(const ACommonDialog: TCommonDialog); override;
    class procedure ShowModal(const ACommonDialog: TCommonDialog); override;
    class function QueryWSEventCapabilities(const ACommonDialog: TCommonDialog): TCDWSEventCapabilities; override;
  end;

  { TWin32WSSaveDialog }

  TWin32WSSaveDialog = class(TWSSaveDialog)
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class procedure DestroyHandle(const ACommonDialog: TCommonDialog); override;
    class procedure ShowModal(const ACommonDialog: TCommonDialog); override;
    class function QueryWSEventCapabilities(const ACommonDialog: TCommonDialog): TCDWSEventCapabilities; override;
  end;

  { TWin32WSSelectDirectoryDialog }

  TWin32WSSelectDirectoryDialog = class(TWSSelectDirectoryDialog)
  public
    class function CreateOldHandle(const ACommonDialog: TCommonDialog): THandle;
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class function QueryWSEventCapabilities(const ACommonDialog: TCommonDialog): TCDWSEventCapabilities; override;
  end;

  { TWin32WSColorDialog }

  TWin32WSColorDialog = class(TWSColorDialog)
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class procedure ShowModal(const ACommonDialog: TCommonDialog); override;
    class procedure DestroyHandle(const ACommonDialog: TCommonDialog); override;
    class function QueryWSEventCapabilities(const ACommonDialog: TCommonDialog): TCDWSEventCapabilities; override;
  end;

  { TWin32WSColorButton }

  TWin32WSColorButton = class(TWSColorButton)
  published
  end;

  { TWin32WSFontDialog }

  TWin32WSFontDialog = class(TWSFontDialog)
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class function QueryWSEventCapabilities(const ACommonDialog: TCommonDialog): TCDWSEventCapabilities; override;
  end;


  { TFileDialogEvents }

  TFileDialogEvents = class(TInterfacedObject, IFileDialogEvents, IFileDialogControlEvents)
  private
    FDialog: TOpenDialog;
  protected
    // IFileDialogEvents
    function OnFileOk(pfd: IFileDialog): HResult; stdcall;
    function OnFolderChanging({%H-}pfd: IFileDialog; {%H-}psifolder: IShellItem): HResult; stdcall;
    function OnFolderChange({%H-}pfd: IFileDialog): HResult; stdcall;
    function OnSelectionChange(pfd: IFileDialog): HResult; stdcall;
    function OnShareViolation({%H-}pfd: IFileDialog; {%H-}psi: IShellItem; {%H-}pResponse: pFDE_SHAREVIOLATION_RESPONSE): HResult; stdcall;
    function OnTypeChange(pfd: IFileDialog): HResult; stdcall;
    function OnOverwrite({%H-}pfd: IFileDialog; {%H-}psi: IShellItem; {%H-}pResponse: pFDE_OVERWRITE_RESPONSE): HResult; stdcall;
    // IFileDialogControlEvents
    function OnItemSelected({%H-}pfdc: IFileDialogCustomize; {%H-}dwIDCtl: DWORD; {%H-}dwIDItem: DWORD): HResult; stdcall;
    function OnButtonClicked({%H-}pfdc: IFileDialogCustomize; {%H-}dwIDCtl: DWORD): HResult; stdcall;
    function OnCheckButtonToggled({%H-}pfdc: IFileDialogCustomize; {%H-}dwIDCtl: DWORD; {%H-}bChecked: BOOL): HResult; stdcall;
    function OnControlActivating({%H-}pfdc: IFileDialogCustomize; {%H-}dwIDCtl: DWORD): HResult; stdcall;
  public
    constructor Create(ADialog: TOpenDialog);
  end;

function OpenFileDialogCallBack(Wnd: HWND; uMsg: UINT; {%H-}wParam: WPARAM;
  lParam: LPARAM): UINT_PTR; stdcall;

function SaveApplicationState: TApplicationState;
procedure RestoreApplicationState(AState: TApplicationState);
function UTF8StringToPWideChar(const s: string) : PWideChar;
function UTF8StringToPAnsiChar(const s: string) : PAnsiChar;

function CanUseVistaDialogs(const AOpenDialog: TOpenDialog): Boolean;

var
  cOpenDialogAllFiles: string = 'All files';


implementation

function SaveApplicationState: TApplicationState;
begin
  Result.ActiveWindow := Windows.GetActiveWindow;
  Result.FocusedWindow := Windows.GetFocus;
  Result.DisabledWindows := Screen.DisableForms(nil);
  Application.ModalStarted;
end;

procedure RestoreApplicationState(AState: TApplicationState);
begin
  Screen.EnableForms(AState.DisabledWindows);
  Windows.SetActiveWindow(AState.ActiveWindow);
  Windows.SetFocus(AState.FocusedWindow);
  Application.ModalFinished;
end;

// The size of the OPENFILENAME record depends on the windows version
// In the initialization section the correct size is determined.
var
  OpenFileNameSize: integer = 0;

// Returns a new PWideChar containing the string UTF8 string s as widechars
function UTF8StringToPWideChar(const s: string) : PWideChar;
begin
  // a string of widechars will need at most twice the amount of bytes
  // as the corresponding UTF8 string
  Result := GetMem(length(s)*2+2);
  Utf8ToUnicode(Result,length(s)+1,pchar(s),length(s)+1);
end;

// Returns a new PChar containing the string UTF8 string s as ansichars
function UTF8StringToPAnsiChar(const s: string) : PAnsiChar;
var
  AnsiChars: string;
begin
  AnsiChars:= Utf8ToAnsi(s);
  Result := GetMem(length(AnsiChars)+1);
  Move(PChar(AnsiChars)^, Result^, length(AnsiChars)+1);
end;

procedure UpdateFileProperties(OpenFile: LPOPENFILENAME);
var
  DialogRec: POpenFileDialogRec;
  AOpenDialog: TOpenDialog;

  procedure SetFilesPropertyCustomFiles(AFiles:TStrings);

    procedure AddFile(FolderName, FileName: String); inline;
    begin
      if ExtractFilePath(FileName) = '' then
        AFiles.Add(FolderName + FileName)
      else
        AFiles.Add(FileName);
    end;

  var
    i, Start, len: integer;
    FolderName: string;
    FileNames: string;
  begin
    FolderName := UTF16ToUTF8(DialogRec^.UnicodeFolderName);
    FileNames := UTF16ToUTF8(DialogRec^.UnicodeFileNames);
    if FolderName='' then
    begin
      // On Windows 7, the SendMessageW(GetParent(Wnd), CDM_GETFOLDERPATH, 0, LPARAM(nil))
      // at UpdateStorage might fail (see #16797)
      // However, the valid directory is returned in OpenFile^.lpstrFile
      //
      // What was the reason not to use OpenFile^.lpstrFile, since it's list
      // of the selected files, without need of writting any callbacks!
      FolderName:=UTF16ToUTF8(PWidechar(OpenFile^.lpstrFile));
      // Check for DirectoryExistsUTF8(FolderName) is required, because Win 7
      // sometimes returns a single file name in OpenFile^.lpstrFile, while
      // OFN_ALLOWMULTISELECT is set
      // to reproduce.
      //   1. Allow mulitple files in OpenDialog options. Run the project.
      //   2. OpenDialog.Execute -> Library -> Documens. Select a single file!
      if (OpenFile^.Flags and OFN_ALLOWMULTISELECT=0) or not DirectoryExistsUTF8(FolderName) then
        FolderName:=ExtractFileDir(FolderName);
    end;
    FolderName := AppendPathDelim(FolderName);
    len := Length(FileNames);
    if (len > 0) and (FileNames[1] = '"') then
    begin
      Start := 1; // first quote is on pos 1
      while (start <= len) and (FileNames[Start] <> #0) do
      begin
        i := Start + 1;
        while FileNames[i] <> '"' do
          inc(i);
        AddFile(FolderName, Copy(FileNames, Start + 1, I - Start - 1));
        Start := i + 1;
        while (Start <= len) and (FileNames[Start] <> #0) and (FileNames[Start] <> '"') do
          inc(Start);
      end;
    end
    else
      AddFile(FolderName, FileNames);
  end;

  procedure SetFilesPropertyForOldStyle(AFiles:TStrings);
  var
    SelectedStr: string;
    FolderName: string;
    I,Start: integer;
  begin
    SelectedStr:=UTF16ToUTF8(widestring(PWideChar(OpenFile^.lpStrFile)));
    if not (ofAllowMultiSelect in AOpenDialog.Options) then
      AFiles.Add(SelectedStr)
    else begin
      Start:=Pos(' ',SelectedStr);
      FolderName := copy(SelectedStr,1,start-1);
      SelectedStr:=SelectedStr+' ';
      inc(start);
      for I:= Start to Length(SelectedStr) do
        if SelectedStr[I] =  ' ' then
        begin
          AFiles.Add(ExpandFileNameUTF8(FolderName+Copy(SelectedStr,Start,I - Start)));
          Start:=Succ(I);
        end;
    end;
  end;

begin
  DialogRec := POpenFileDialogRec(OpenFile^.lCustData);
  AOpenDialog := TOpenDialog(DialogRec^.Dialog);
  AOpenDialog.Files.Clear;
  AOpenDialog.FilterIndex := OpenFile^.nFilterIndex;
  if (ofOldStyleDialog in AOpenDialog.Options) then
    SetFilesPropertyForOldStyle(AOpenDialog.Files)
  else
    SetFilesPropertyCustomFiles(AOpenDialog.Files);
  AOpenDialog.FileName := AOpenDialog.Files[0];
end;

{------------------------------------------------------------------------------
  Method: GetOwnerHandle
  Params:  ADialog - dialog to get 'guiding parent' window handle for
  Returns: A window handle

  Returns window handle to be used as 'owner handle', ie. so that the user must
  finish the dialog before continuing
 ------------------------------------------------------------------------------}
function GetOwnerHandle(ADialog : TCommonDialog): HWND;
begin
  if (Screen.ActiveForm<>nil) and Screen.ActiveForm.HandleAllocated then
    Result := Screen.ActiveForm.Handle
  else
    Result := Application.MainFormHandle;
end;

procedure SetDialogResult(const ACommonDialog: TCommonDialog; Ret: WINBOOL);
begin
  if Ret then
    ACommonDialog.UserChoice := mrOK
  else
    ACommonDialog.UserChoice := mrCancel;
end;

function CanUseVistaDialogs(const AOpenDialog: TOpenDialog): Boolean;
begin
  {$IFnDEF DisableVistaDialogs}
  Result := (WindowsVersion >= wvVista) and not (ofOldStyleDialog in AOpenDialog.Options);

  {$ELSE}
  Result := False;
  {$ENDIF}
end;


{ TWin32WSColorDialog }

Function CCHookProc(H: THandle; msg: Cardinal; W: WParam; L: LParam): UintPtr; StdCall;
var
  ws: WideString;
begin
  if (H <> 0) and (Msg = WM_InitDialog) then
  begin
    ws := TColorDialog(PChooseColor(L)^.lCustData).Title;
    SetWindowTextW(H, PWideChar(ws));
  end;
  Result := 0;
end;

class function TWin32WSColorDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
var
  CC: PChooseColor;
  ColorDialog: TColorDialog absolute ACommonDialog;

  procedure FillCustomColors;
  var
    i, AIndex: integer;
    AColor: TColor;
  begin
    for i := 0 to ColorDialog.CustomColors.Count - 1 do
      if ExtractColorIndexAndColor(ColorDialog.CustomColors, i, AIndex, AColor) then
      begin
        if AIndex < 16 then
          CC^.lpCustColors[AIndex] := AColor;
      end;
  end;

begin
  CC := AllocMem(SizeOf(TChooseColor));
  with CC^ Do
  begin
    LStructSize := sizeof(TChooseColor);
    HWndOwner := GetOwnerHandle(ACommonDialog);
    RGBResult := ColorToRGB(ColorDialog.Color);
    LPCustColors := AllocMem(16 * SizeOf(DWord));
    FillCustomColors;
    lCustData := LParam(ACommonDialog);
    lpfnHook := @CCHookProc;
    Flags := CC_FULLOPEN or CC_RGBINIT or CC_ENABLEHOOK;
  end;
  Result := THandle(CC);
end;

class procedure TWin32WSColorDialog.ShowModal(const ACommonDialog: TCommonDialog);
var
  CC: PChooseColor;
  UserResult: WINBOOL;
  State: TApplicationState;
  i: Integer;
begin
  if ACommonDialog.Handle <> 0 then
  begin
    State := SaveApplicationState;
    try
      CC := PChooseColor(ACommonDialog.Handle);

      UserResult := ChooseColor(CC);
      SetDialogResult(ACommonDialog, UserResult);
      if UserResult then
      begin
        TColorDialog(ACommonDialog).Color := CC^.RGBResult;
        for i := 0 to 15 do
        if i < TColorDialog(ACommonDialog).CustomColors.Count then
          TColorDialog(ACommonDialog).CustomColors[i] := Format('Color%s=%x', [Chr(Ord('A')+i), CC^.lpCustColors[i]])
        else
          TColorDialog(ACommonDialog).CustomColors.Add (Format('Color%s=%x', [Chr(Ord('A')+i), CC^.lpCustColors[i]]));
      end;
    finally
      RestoreApplicationState(State);
    end;
  end;
end;

class procedure TWin32WSColorDialog.DestroyHandle(
  const ACommonDialog: TCommonDialog);
var
  CC: PChooseColor;
begin
  if ACommonDialog.Handle <> 0 then
  begin
    CC := PChooseColor(ACommonDialog.Handle);
    FreeMem(CC^.lpCustColors);
    FreeMem(CC);
  end;
end;

class function TWin32WSColorDialog.QueryWSEventCapabilities(
  const ACommonDialog: TCommonDialog): TCDWSEventCapabilities;
begin
  Result := [cdecWSNoCanCloseSupport];
end;

procedure UpdateStorage(Wnd: HWND; OpenFile: LPOPENFILENAME);
var
  FilesSize: SizeInt;
  FolderSize: SizeInt;
  DialogRec: POpenFileDialogRec;
begin
  DialogRec := POpenFileDialogRec(OpenFile^.lCustData);
  FolderSize := SendMessageW(GetParent(Wnd), CDM_GETFOLDERPATH, 0, LPARAM(nil));
  FilesSize := SendMessageW(GetParent(Wnd), CDM_GETSPEC, 0, LPARAM(nil));
  SetLength(DialogRec^.UnicodeFolderName, FolderSize - 1);
  SendMessageW(GetParent(Wnd), CDM_GETFOLDERPATH, FolderSize,
               LPARAM(PWideChar(DialogRec^.UnicodeFolderName)));

  SetLength(DialogRec^.UnicodeFileNames, FilesSize - 1);
  SendMessageW(GetParent(Wnd), CDM_GETSPEC, FilesSize,
               LPARAM(PWideChar(DialogRec^.UnicodeFileNames)));
end;

{Common code for OpenDialog and SaveDialog}

{The API of the multiselect open file dialog is a bit problematic.
 Before calling the OpenFile function you must create a buffer (lpStrFile) to
 hold the selected files.

 With a multiselect dialog there is no way to create a buffer with correct size:
 * either it is too small (for example 1 KB), if a lot a files are selected
 * or it wastes a lot of memory (for example 1 MB), and even than you have no
   guarantee, that is big enough.

 The OpenFile API call returns false, if an error has occurred or the user has
 pressed cancel. If there was an error CommDlgExtendedError returns
 FNERR_BUFFERTOOSMALL. But enlarging the buffer at that time is not useful
 anymore, unless you show the dialog again with a bigger buffer (Sorry, the
 buffer was too small, please select the files again). This is not acceptable.

 It is possible to hook the filedialog, so you get messages, when the selection
 changes. A naive aproach would be to see, if the buffer would be big enough for
 the selected files and create or enlarge the buffer (as described in KB131462).
 Unfortunately, this only works with win9x and the unicode versions of later
 windows versions.

 Therefore in the hook function, if the size of the initial buffer (lpStrFile)
 is not large enough, the selected files are copied into a string. A pointer to
 this string is kept in the lCustData field of the the OpenFileName struct.
 When dialog is closed with a FNERR_BUFFERTOOSMALL error, this string is used to
 get the selected files. If this error did not occur, the normal way of
 retrieving the files is used.
}

function OpenFileDialogCallBack(Wnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): UINT_PTR; stdcall;
var
  OpenFileNotify: LPOFNOTIFY;
  OpenFileName: Windows.POPENFILENAME;
  DlgRec: POpenFileDialogRec;
  CanClose: Boolean;
{
  procedure Reposition(ADialogWnd: Handle);
  var
    Left, Top: Integer;
    ABounds, DialogRect: TRect;
  begin
    // Btw, setting width and height of dialog doesnot reposition child controls :(
    // So no way to set another height and width at least here
    if (GetParent(ADialogWnd) = Win32WidgetSet.AppHandle) then
    begin
      if Screen.ActiveCustomForm <> nil then
        ABounds := Screen.ActiveCustomForm.Monitor.BoundsRect
      else
      if Application.MainForm <> nil then
        ABounds := Application.MainForm.Monitor.BoundsRect
      else
        ABounds := Screen.PrimaryMonitor.BoundsRect;
    end
    else
      ABounds := Screen.MonitorFromWindow(GetParent(ADialogWnd)).BoundsRect;
    GetWindowRect(ADialogWnd, @DialogRect);
    Left := (ABounds.Right - DialogRect.Right + DialogRect.Left) div 2;
    Top := (ABounds.Bottom - DialogRect.Bottom + DialogRect.Top) div 2;
    SetWindowPos(ADialogWnd, HWND_TOP, Left, Top, 0, 0, SWP_NOSIZE);
  end;
}
  procedure ExtractDataFromNotify;
  begin
    OpenFileName := OpenFileNotify^.lpOFN;
    DlgRec := POpenFileDialogRec(OpenFileName^.lCustData);
    UpdateStorage(Wnd, OpenFileName);
    UpdateFileProperties(OpenFileName);
  end;

begin
  Result := 0;
  if uMsg = WM_INITDIALOG then
  begin
    // Windows asks us to initialize dialog. At this moment controls are not
    // arranged and this is that moment when we should set bounds of our dialog
    //Reposition(GetParent(Wnd)); this causes active form to move out of position with old dialogs JP
  end
  else
  if uMsg = WM_NOTIFY then
  begin
    OpenFileNotify := LPOFNOTIFY(lParam);
    if OpenFileNotify = nil then
      Exit;

    case OpenFileNotify^.hdr.code of
      CDN_INITDONE:
      begin
        ExtractDataFromNotify;
        {$ifdef DebugCommonDialogEvents}
        debugln(['OpenFileDialogCallBack calling DoShow']);
        {$endif}
        TOpenDialog(DlgRec^.Dialog).DoShow;
      end;
      CDN_SELCHANGE:
      begin
        ExtractDataFromNotify;
        TOpenDialog(DlgRec^.Dialog).DoSelectionChange;
      end;
      CDN_FOLDERCHANGE:
      begin
        ExtractDataFromNotify;
        TOpenDialog(DlgRec^.Dialog).DoFolderChange;
      end;
      CDN_FILEOK:
      begin
        ExtractDataFromNotify;
        CanClose := True;
        TOpenDialog(DlgRec^.Dialog).UserChoice := mrOK;
        {$ifdef DebugCommonDialogEvents}
        debugln(['OpenFileDialogCallBack calling DoCanClose']);
        {$endif}
        TOpenDialog(DlgRec^.Dialog).DoCanClose(CanClose);
        {$ifdef DebugCommonDialogEvents}
        debugln(['OpenFileDialogCallBack CanClose=',CanClose]);
        {$endif}
        if not CanClose then
        begin
          //the dialog window will not process the click on OK button
          //as a result the dialog will not close
          SetWindowLong(Wnd, DWL_MSGRESULT, 1);
          Result := 1;
        end;
      end;
      CDN_TYPECHANGE:
      begin
        ExtractDataFromNotify;
        DlgRec^.Dialog.IntfFileTypeChanged(OpenFileNotify^.lpOFN^.nFilterIndex);
      end;
    end;
  end;
end;

function CreateFileDialogHandle(AOpenDialog: TOpenDialog): THandle;

  function GetFlagsFromOptions(Options: TOpenOptions): DWord;
  begin
    Result := OFN_ENABLEHOOK;
    if ofAllowMultiSelect in Options then Result := Result or OFN_ALLOWMULTISELECT;
    if ofCreatePrompt in Options then Result := Result or OFN_CREATEPROMPT;
    if not (ofOldStyleDialog in Options) then Result := Result or OFN_EXPLORER;
    if ofExtensionDifferent in Options then Result := Result or OFN_EXTENSIONDIFFERENT;
    if ofFileMustExist in Options then Result := Result or OFN_FILEMUSTEXIST;
    if ofHideReadOnly in Options then Result := Result or OFN_HIDEREADONLY;
    if ofNoChangeDir in Options then Result := Result or OFN_NOCHANGEDIR;
    if ofNoDereferenceLinks in Options then Result := Result or OFN_NODEREFERENCELINKS;
    if ofEnableSizing in Options then Result := Result or OFN_ENABLESIZING;
    if ofNoLongNames in Options then  Result := Result or OFN_NOLONGNAMES;
    if ofNoNetworkButton in Options then Result := Result or OFN_NONETWORKBUTTON;
    if ofNoReadOnlyReturn in  Options then Result := Result or OFN_NOREADONLYRETURN;
    if ofNoTestFileCreate in Options then Result := Result or OFN_NOTESTFILECREATE;
    if ofNoValidate in Options then Result := Result or OFN_NOVALIDATE;
    if ofOverwritePrompt in Options then Result := Result or OFN_OVERWRITEPROMPT;
    if ofPathMustExist in Options then Result := Result or OFN_PATHMUSTEXIST;
    if ofReadOnly in Options then Result := Result or OFN_READONLY;
    if ofShareAware in Options then Result := Result or OFN_SHAREAWARE;
    if ofShowHelp in Options then Result := Result or OFN_SHOWHELP;
    if ofDontAddToRecent in Options then Result := Result or OFN_DONTADDTORECENT;
    if ofForceShowHidden in Options then Result := Result or OFN_FORCESHOWHIDDEN;
  end;

  procedure ReplacePipe(var AFilter:string);
  var
    i: integer;
  begin
    for i := 1 to Length(AFilter) do
      if AFilter[i] = '|' then AFilter[i] := #0;
    AFilter := AFilter + #0;
  end;

  function GetDefaultExt: String;
  begin
    Result := AOpenDialog.DefaultExt;
    if (Result<>'') and (Result[1]='.') then
      System.Delete(Result, 1, 1);
  end;

const
  FileNameBufferLen = 1000;
var
  DialogRec: POpenFileDialogRec;
  OpenFile: LPOPENFILENAME;
  Filter, FileName, InitialDir, DefaultExt: String;
  FileNameWide: WideString;
  FileNameWideBuffer: PWideChar;
  FileNameBufferSize: Integer;
begin
  {$ifdef DebugCommonDialogEvents}
  debugln(['CreateFileDialogHandle A']);
  {$endif}
  FileName := AOpenDialog.FileName;
  InitialDir := AOpenDialog.InitialDir;
  if (FileName <> '') and (FileName[length(FileName)] = PathDelim) then
  begin
    // if the filename contains a directory, set the initial directory
    // and clear the filename
    InitialDir := Copy(FileName, 1, Length(FileName) - 1);
    FileName := '';
  end;

  DefaultExt := GetDefaultExt;

  FileNameWideBuffer := AllocMem(FileNameBufferLen * 2 + 2);
  FileNameWide := UTF8ToUTF16(FileName);

  if Length(FileNameWide) > FileNameBufferLen then
    FileNameBufferSize := FileNameBufferLen
  else
    FileNameBufferSize := Length(FileNameWide);

  Move(PWideChar(FileNameWide)^, FileNameWideBuffer^, FileNameBufferSize * 2);

  if AOpenDialog.Filter <> '' then
  begin
    Filter := AOpenDialog.Filter;
    ReplacePipe(Filter);
  end
  else
    Filter := cOpenDialogAllFiles+' (*.*)'+#0+'*.*'+#0; // Default -> avoid empty combobox

  OpenFile := AllocMem(SizeOf(OpenFileName));
  with OpenFile^ do
  begin
    lStructSize := OpenFileNameSize;
    hWndOwner := GetOwnerHandle(AOpenDialog);
    hInstance := System.hInstance;

    nFilterIndex := AOpenDialog.FilterIndex;

    lpStrFile := PChar(FileNameWideBuffer);
    lpstrFilter := PChar(UTF8StringToPWideChar(Filter));
    lpstrTitle := PChar(UTF8StringToPWideChar(AOpenDialog.Title));
    lpstrInitialDir := PChar(UTF8StringToPWideChar(InitialDir));
    lpstrDefExt := PChar(UTF8StringToPWideChar(DefaultExt));

    nMaxFile := FileNameBufferLen + 1; // Size in TCHARs
    lpfnHook := Windows.LPOFNHOOKPROC(@OpenFileDialogCallBack);
    Flags := GetFlagsFromOptions(AOpenDialog.Options);
    New(DialogRec);
    // new initializes the filename fields, because ansistring and widestring
    // are automated types.
    DialogRec^.Dialog := AOpenDialog;
    lCustData := LParam(DialogRec);
  end;
  Result := THandle(OpenFile);
  {$ifdef DebugCommonDialogEvents}
  debugln(['CreateFileDialogHandle End']);
  {$endif}
end;

procedure DestroyFileDialogHandle(AHandle: THandle);
var
  OPENFILE: LPOPENFILENAME;
begin
  OPENFILE := LPOPENFILENAME(AHandle);
  if OPENFILE^.lCustData <> 0 then
    Dispose(POpenFileDialogRec(OPENFILE^.lCustData));

  FreeMem(OpenFile^.lpStrFilter);
  FreeMem(OpenFile^.lpstrInitialDir);
  FreeMem(OpenFile^.lpStrFile);
  FreeMem(OpenFile^.lpStrTitle);
  FreeMem(OpenFile^.lpTemplateName);
  FreeMem(OpenFile^.lpstrDefExt);
  FreeMem(OpenFile);
end;

procedure ProcessFileDialogResult(AOpenDialog: TOpenDialog; UserResult: WordBool);
var
  OpenFile: LPOPENFILENAME;
begin
  OpenFile := LPOPENFILENAME(AOpenDialog.Handle);
  if not UserResult and (CommDlgExtendedError = FNERR_BUFFERTOOSMALL) then
    UserResult := True;
  SetDialogResult(AOpenDialog, UserResult);
  if UserResult then
  begin
    UpdateFileProperties(OpenFile);
    AOpenDialog.IntfSetOption(ofExtensionDifferent, OpenFile^.Flags and OFN_EXTENSIONDIFFERENT <> 0);
    AOpenDialog.IntfSetOption(ofReadOnly, OpenFile^.Flags and OFN_READONLY <> 0);
  end
  else
  begin
    AOpenDialog.Files.Clear;
    AOpenDialog.FileName := '';
  end;
end;

{ TWin32WSOpenDialog }


class procedure TWin32WSOpenDialog.SetupVistaFileDialog(ADialog: IFileDialog; const AOpenDialog: TOpenDialog);

  function GetDefaultExt: String;
  begin
    Result := AOpenDialog.DefaultExt;
    if (Result<>'') and (Result[1]='.') then
      System.Delete(Result, 1, 1);
  end;

var
  I: Integer;
  FileName, InitialDir: String;
  DefaultFolderItem: IShellItem;
  ParsedFilter: TParseStringList;
  FileTypesArray: PCOMDLG_FILTERSPEC;
begin
  FileName := AOpenDialog.FileName;
  InitialDir := AOpenDialog.InitialDir;
  if (FileName <> '') and (FileName[length(FileName)] = PathDelim) then
  begin
    // if the filename contains a directory, set the initial directory
    // and clear the filename
    InitialDir := Copy(FileName, 1, Length(FileName) - 1);
    FileName := '';
  end;
  ADialog.SetTitle(PWideChar(UTF8ToUTF16(AOpenDialog.Title)));
  ADialog.SetFileName(PWideChar(UTF8ToUTF16(FileName)));
  ADialog.SetDefaultExtension(PWideChar(UTF8ToUTF16(GetDefaultExt)));

  if InitialDir <> '' then
  begin
    if Succeeded(SHCreateItemFromParsingName(PWideChar(UTF8ToUTF16(InitialDir)), nil, IShellItem, DefaultFolderItem)) then
      ADialog.SetFolder(DefaultFolderItem);
  end;

  ParsedFilter := TParseStringList.Create(AOpenDialog.Filter, '|');
  if ParsedFilter.Count = 0 then
  begin
    ParsedFilter.Add(cOpenDialogAllFiles+' (*.*)');
    ParsedFilter.Add('*.*');
  end;
  try
    FileTypesArray := AllocMem((ParsedFilter.Count div 2) * SizeOf(TCOMDLG_FILTERSPEC));
    for I := 0 to ParsedFilter.Count div 2 - 1 do
    begin
      FileTypesArray[I].pszName := UTF8StringToPWideChar(ParsedFilter[I * 2]);
      FileTypesArray[I].pszSpec := UTF8StringToPWideChar(ParsedFilter[I * 2 + 1]);
    end;
    ADialog.SetFileTypes(ParsedFilter.Count div 2, FileTypesArray);
    ADialog.SetFileTypeIndex(AOpenDialog.FilterIndex);
    for I := 0 to ParsedFilter.Count div 2 - 1 do
    begin
      FreeMem(FileTypesArray[I].pszName);
      FreeMem(FileTypesArray[I].pszSpec);
    end;
    FreeMem(FileTypesArray);
  finally
    ParsedFilter.Free;
  end;

  ADialog.SetOptions(GetVistaOptions(AOpenDialog.Options, AOpenDialog is TSelectDirectoryDialog));
end;

class function TWin32WSOpenDialog.GetFileName(ShellItem: IShellItem): String;
var
  FilePath: LPWStr;
begin
  if Succeeded(ShellItem.GetDisplayName(SIGDN(SIGDN_FILESYSPATH), @FilePath)) then
  begin
    Result := UTF16ToUTF8(WideString(FilePath));
    CoTaskMemFree(FilePath);
  end
  else
    Result := '';
end;

class function TWin32WSOpenDialog.GetVistaOptions(Options: TOpenOptions;
  SelectFolder: Boolean): FileOpenDialogOptions;
{ non-used flags
FOS_FORCEFILESYSTEM
FOS_ALLNONSTORAGEITEMS
FOS_HIDEMRUPLACES
FOS_HIDEPINNEDPLACES
FOS_DEFAULTNOMINIMODE
FOS_FORCEPREVIEWPANEON}

begin
  Result := 0;
  if ofAllowMultiSelect in Options then Result := Result or FOS_ALLOWMULTISELECT;
  if ofCreatePrompt in Options then Result := Result or FOS_CREATEPROMPT;
  if ofExtensionDifferent in Options then Result := Result or FOS_STRICTFILETYPES;
  if ofFileMustExist in Options then Result := Result or FOS_FILEMUSTEXIST;
  if ofNoChangeDir in Options then Result := Result or FOS_NOCHANGEDIR;
  if ofNoDereferenceLinks in Options then Result := Result or FOS_NODEREFERENCELINKS;
  if ofNoReadOnlyReturn in  Options then Result := Result or FOS_NOREADONLYRETURN;
  if ofNoTestFileCreate in Options then Result := Result or FOS_NOTESTFILECREATE;
  if ofNoValidate in Options then Result := Result or FOS_NOVALIDATE;
  if ofOverwritePrompt in Options then Result := Result or FOS_OVERWRITEPROMPT;
  if ofPathMustExist in Options then Result := Result or FOS_PATHMUSTEXIST;
  if ofShareAware in Options then Result := Result or FOS_SHAREAWARE;
  if ofDontAddToRecent in Options then Result := Result or FOS_DONTADDTORECENT;
  if SelectFolder then Result := Result or FOS_PICKFOLDERS;
  if ofForceShowHidden in Options then Result := Result or FOS_FORCESHOWHIDDEN;
  { unavailable options:
    ofHideReadOnly
    ofEnableSizing
    ofNoLongNames
    ofNoNetworkButton
    ofReadOnly
    ofShowHelp
  }
end;

class function TWin32WSOpenDialog.ProcessVistaDialogResult(ADialog: IFileDialog; const AOpenDialog: TOpenDialog): HResult;
var
  ShellItems: IShellItemArray;
  ShellItem: IShellItem;
  I, Count: DWord;
begin
  // TODO: ofExtensionDifferent, ofReadOnly
  if not Supports(ADialog, IFileOpenDialog) then
    Result := E_FAIL
  else
    Result := (ADialog as IFileOpenDialog).GetResults(ShellItems{%H-});
  if Succeeded(Result) and Succeeded(ShellItems.GetCount(Count{%H-})) then
  begin
    AOpenDialog.Files.Clear;
    I := 0;
    while I < Count do
    begin
      if Succeeded(ShellItems.GetItemAt(I, ShellItem)) then
        AOpenDialog.Files.Add(GetFileName(ShellItem));
      inc(I);
    end;
    if AOpenDialog.Files.Count > 0 then
      AOpenDialog.FileName := AOpenDialog.Files[0]
    else
      AOpenDialog.FileName := '';
  end
  else
  begin
    Result := ADialog.GetResult(@ShellItem);
    if Succeeded(Result) then
    begin
      AOpenDialog.Files.Clear;
      AOpenDialog.FileName := GetFileName(ShellItem);
      AOpenDialog.Files.Add(AOpenDialog.FileName);
    end
    else
    begin
      AOpenDialog.Files.Clear;
      AOpenDialog.FileName := '';
    end;
  end;
end;

class procedure TWin32WSOpenDialog.VistaDialogShowModal(ADialog: IFileDialog; const AOpenDialog: TOpenDialog);
var
  FileDialogEvents: IFileDialogEvents;
  Cookie: DWord;
  //CanClose: Boolean;
begin
  {$ifdef DebugCommonDialogEvents}
  debugln('TWin32WSOpenDialog.VistaDialogShowModal A');
  {$endif}
  FileDialogEvents := TFileDialogEvents.Create(AOpenDialog);
  ADialog.Advise(FileDialogEvents, @Cookie);
  try
    {$ifdef DebugCommonDialogEvents}
    debugln('TWin32WSOpenDialog.VistaDialogShowModal calling DoShow');
    {$endif}
    AOpenDialog.DoShow;
    ADialog.Show(GetParentWnd);
    {$ifdef DebugCommonDialogEvents}
    debugln(['TWin32WSOpenDialog.VistaDialogShowModal: AOpenDialog.UserChoice = ',ModalResultStr[AOpenDialog.UserChoice]]);
    {$endif}
    //DoOnClose is called from TFileDialogEvents.OnFileOk if user pressed OK
    //Do NOT call DoCanClose if user cancels the dialog
    //see http://docwiki.embarcadero.com/Libraries/Berlin/en/Vcl.Dialogs.TOpenDialog_Events
    //so no need to call it here anymore
    if (AOpenDialog.UserChoice <> mrOk) then
    begin
      AOpenDialog.UserChoice := mrCancel;
    end;
  finally
    ADialog.unadvise(Cookie);
    FileDialogEvents := nil;
  end;
  {$ifdef DebugCommonDialogEvents}
  debugln('TWin32WSOpenDialog.VistaDialogShowModal End');
  {$endif}
end;

class function TWin32WSOpenDialog.GetParentWnd: HWND;
begin
  if Assigned(Screen.ActiveCustomForm) then
    Result := Screen.ActiveCustomForm.Handle
  else
  if Assigned(Application.MainForm) then
    Result := Application.MainFormHandle
  else
    Result := WidgetSet.AppHandle;
end;

class function TWin32WSOpenDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
var
  Dialog: IFileOpenDialog;
begin
  if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
  begin
    if Succeeded(CoCreateInstance(CLSID_FileOpenDialog, nil, CLSCTX_INPROC_SERVER, IFileOpenDialog, Dialog)) and Assigned(Dialog) then
    begin
      Dialog._AddRef;
      SetupVistaFileDialog(Dialog, TOpenDialog(ACommonDialog));
      Result := THandle(Dialog);
    end
    else
      Result := INVALID_HANDLE_VALUE;
  end
  else
    Result := CreateFileDialogHandle(TOpenDialog(ACommonDialog));
end;

class procedure TWin32WSOpenDialog.DestroyHandle(const ACommonDialog: TCommonDialog);
var
  Dialog: IFileDialog;
begin
  if ACommonDialog.Handle <> 0 then
    if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
    begin
      Dialog := IFileDialog(ACommonDialog.Handle);
      Dialog._Release;
      Dialog := nil;
    end
    else
      DestroyFileDialogHandle(ACommonDialog.Handle)
end;

class procedure TWin32WSOpenDialog.ShowModal(const ACommonDialog: TCommonDialog);
var
  State: TApplicationState;
  lOldWorkingDir, lInitialDir: string;
  Dialog: IFileOpenDialog;
begin
  if ACommonDialog.Handle <> 0 then
  begin
    State := SaveApplicationState;
    lOldWorkingDir := GetCurrentDirUTF8;
    try
      lInitialDir := TOpenDialog(ACommonDialog).InitialDir;
      if lInitialDir <> '' then
        SetCurrentDirUTF8(lInitialDir);
      if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
      begin
        Dialog := IFileOpenDialog(ACommonDialog.Handle);
        VistaDialogShowModal(Dialog, TOpenDialog(ACommonDialog));
      end
      else
      begin
        {$ifdef DebugCommonDialogEvents}
        debugln(['TWin32WSOpenDialog.ShowModal before ProcessFileDialogResults']);
        {$endif}
        ProcessFileDialogResult(TOpenDialog(ACommonDialog),
          GetOpenFileNameW(LPOPENFILENAME(ACommonDialog.Handle)));
        {$ifdef DebugCommonDialogEvents}
        debugln(['TWin32WSOpenDialog.ShowModal after ProcessFileDialogResults, UserChoice=',ModalResultStr[TOpenDialog(ACommonDialog).UserChoice]]);
        {$endif}
      end;
    finally
      SetCurrentDirUTF8(lOldWorkingDir);
      RestoreApplicationState(State);
    end;
  end;
end;

class function TWin32WSOpenDialog.QueryWSEventCapabilities(
  const ACommonDialog: TCommonDialog): TCDWSEventCapabilities;
begin
  Result := [cdecWSPerformsDoShow,cdecWSPerformsDoCanClose];
end;

{ TWin32WSSaveDialog }

class function TWin32WSSaveDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
var
  Dialog: IFileSaveDialog;
begin
  if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
  begin
    if Succeeded(CoCreateInstance(CLSID_FileSaveDialog, nil, CLSCTX_INPROC_SERVER, IFileSaveDialog, Dialog))
    and Assigned(Dialog) then
    begin
      Dialog._AddRef;
      TWin32WSOpenDialog.SetupVistaFileDialog(Dialog, TOpenDialog(ACommonDialog));
      Result := THandle(Dialog);
    end
    else
      Result := INVALID_HANDLE_VALUE;
  end
  else
    Result := CreateFileDialogHandle(TOpenDialog(ACommonDialog));
end;

class procedure TWin32WSSaveDialog.DestroyHandle(const ACommonDialog: TCommonDialog);
var
  Dialog: IFileDialog;
begin
  if ACommonDialog.Handle <> 0 then
    if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
    begin
      Dialog := IFileDialog(ACommonDialog.Handle);
      Dialog._Release;
      Dialog := nil;
    end
    else
      DestroyFileDialogHandle(ACommonDialog.Handle)
end;

class procedure TWin32WSSaveDialog.ShowModal(const ACommonDialog: TCommonDialog);
var
  State: TApplicationState;
  lOldWorkingDir, lInitialDir: string;
  Dialog: IFileSaveDialog;
begin
  if ACommonDialog.Handle <> 0 then
  begin
    State := SaveApplicationState;
    lOldWorkingDir := GetCurrentDirUTF8;
    try
      lInitialDir := TSaveDialog(ACommonDialog).InitialDir;
      if lInitialDir <> '' then
        SetCurrentDirUTF8(lInitialDir);
      if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
      begin
        Dialog := IFileSaveDialog(ACommonDialog.Handle);
        TWin32WSOpenDialog.VistaDialogShowModal(Dialog, TOpenDialog(ACommonDialog));
      end
      else
      begin
        ProcessFileDialogResult(TOpenDialog(ACommonDialog),
          GetSaveFileNameW(LPOPENFILENAME(ACommonDialog.Handle)));
      end;
    finally
      SetCurrentDirUTF8(lOldWorkingDir);
      RestoreApplicationState(State);
    end;
  end;
end;

class function TWin32WSSaveDialog.QueryWSEventCapabilities(
  const ACommonDialog: TCommonDialog): TCDWSEventCapabilities;
begin
  Result := [cdecWSPerformsDoShow,cdecWSPerformsDoCanClose];
end;

{ TWin32WSFontDialog }

function FontDialogCallBack(Wnd: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): UINT_PTR; stdcall;
const
  //These ID's can be seen as LoWord(wParam), when uMsg = WM_COMMAND
  ApplyBtnControlID = 1026;
  ColorComboBoxControlID = 1139; //see also: https://www.experts-exchange.com/questions/27267157/Font-Common-Dialog.html
  //don't use initialize "var", since that will be reset to nil at every callback
  Dlg: ^TFontDialog = nil;
var
  LFW: LogFontW;
  LFA: LogFontA absolute LFW;
  Res: LONG;
  AColor: TColor;
begin
  Result := 0;
  case uMsg of
    WM_INITDIALOG:
    begin
      //debugln(['FontDialogCallBack: WM_INITDIALOG']);
      //debugln(['  PChooseFontW(LParam)^.lCustData=',IntToHex(PChooseFontW(LParam)^.lCustData,8)]);
      PtrInt(Dlg) := PChooseFontW(LParam)^.lCustData;
    end;
    WM_COMMAND:
    begin
      //debugln(['FontDialogCallBack:']);
      //debugln(['  wParam=',wParam,' lParam=',lParam]);
      //debugln(['  HiWord(wParam)=',HiWord(wParam),' LoWord(wParam)',LoWord(wParam)]);
      //debugln(['  HiWord(lParam)=',HiWord(lParam),' LoWord(lParam)',LoWord(lParam)]);
      // LoWord(wParam) must be ApplyBtnControlID,
      // since HiWord(wParam) = 0 when button is clicked, wParam = LoWord(wParam) in this case
      if (wParam = ApplyBtnControlID) then
      begin
        //debugln(['FontDialogCallback calling OnApplyClicked']);
        if Assigned(Dlg) and Assigned(Dlg^) then
        begin
          if Assigned(Dlg^.OnApplyClicked) then
          begin
            //Query the dialog (Wnd) return a LogFont structure
            //https://msdn.microsoft.com/en-us/library/windows/desktop/ms646880(v=vs.85).aspx
            ZeroMemory(@LFW, SizeOf(LogFontW));
            SendMessage(Wnd, WM_CHOOSEFONT_GETLOGFONT, 0, PtrInt(@LFW));
            //Unfortunately this did NOT retrieve the Color information, so yet another query is necessary
            AColor := Dlg^.Font.Color;
            Res := SendDlgItemMessage(Wnd, ColorComboBoxControlID, CB_GETCURSEL, 0, 0);
            //debugln(['FontDialogCallBack SendDlgItemMessage = ',Res]);
            //if (Res=CB_ERR) then debugln('  = CB_ERR');
            if (Res <> CB_ERR) then
            begin
              AColor := TColor(SendDlgItemMessage(Wnd, ColorComboBoxControlID, CB_GETITEMDATA, Res, 0));
              //debugln(['FontDialogCallback SendDlgItemMessage =',AColor]);
            end;
            //Now finally update Dlg^.Font structure
            LFA.lfFaceName := Utf16ToUtf8(LFW.lfFaceName);
            Dlg^.Font.Assign(LFA);
            Dlg^.Font.Color := AColor;
            Dlg^.OnApplyClicked(Dlg^);
            Result := 1;
          end;
        end;
      end;
    end;
  end;
end;

class function TWin32WSFontDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;

  function GetFlagsFromOptions(Options : TFontDialogOptions): dword;
  begin
    Result := 0;
    if fdAnsiOnly in Options then Result := Result or CF_ANSIONLY;
    if fdTrueTypeOnly in Options then Result := Result or CF_TTONLY;
    if fdEffects in Options then Result := Result or CF_EFFECTS;
    if fdFixedPitchOnly in Options then Result := Result or CF_FIXEDPITCHONLY;
    if fdForceFontExist in Options then Result := Result or CF_FORCEFONTEXIST;
    if fdNoFaceSel in Options then Result := Result or CF_NOFACESEL;
    if fdNoOEMFonts in Options then Result := Result or CF_NOOEMFONTS;
    if fdNoSimulations in Options then Result := Result or CF_NOSIMULATIONS;
    if fdNoSizeSel in Options then Result := Result or CF_NOSIZESEL;
    if fdNoStyleSel in Options then Result := Result or CF_NOSTYLESEL;
    if fdNoVectorFonts in Options then Result := Result or CF_NOVECTORFONTS;
    if fdShowHelp in Options then Result := Result or CF_SHOWHELP;
    if fdWysiwyg in Options then Result := Result or CF_WYSIWYG;
    if fdLimitSize in Options then Result := Result or CF_LIMITSIZE;
    if fdScalableOnly in Options then Result := Result or CF_SCALABLEONLY;
    if fdApplyButton in Options then Result := Result or CF_APPLY;
  end;

var
  CFW: TChooseFontW;
  LFW: LogFontW;
  CF: TChooseFontA absolute CFW;
  LF: LogFontA absolute LFW;
  UserResult: WINBOOL;
begin
  with TFontDialog(ACommonDialog) do
  begin
    ZeroMemory(@CFW, sizeof(TChooseFontW));
    ZeroMemory(@LFW, sizeof(LogFontW));
    with LFW do
    begin
      LFHeight := Font.Height;
      LFFaceName := UTF8ToUTF16(Font.Name);
      if (fsBold in Font.Style) then LFWeight:= FW_BOLD;
      LFItalic := byte(fsItalic in Font.Style);
      LFStrikeOut := byte(fsStrikeOut in Font.Style);
      LFUnderline := byte(fsUnderline in Font.Style);
      LFCharSet := Font.CharSet;
    end;
    // Duplicate logic in CreateFontIndirect
    if not Win32WidgetSet.MetricsFailed and IsFontNameDefault(Font.Name) then
    begin
      LFW.lfFaceName := UTF8ToUTF16(Win32WidgetSet.Metrics.lfMessageFont.lfFaceName);
      if LFW.lfHeight = 0 then
        LFW.lfHeight := Win32WidgetSet.Metrics.lfMessageFont.lfHeight;
    end;
    with CFW do
    begin
      LStructSize := sizeof(TChooseFont);
      HWndOwner := GetOwnerHandle(ACommonDialog);
      LPLogFont := commdlg.PLOGFONTW(@LFW);
      Flags := GetFlagsFromOptions(Options);
      Flags := Flags or CF_INITTOLOGFONTSTRUCT or CF_BOTH;
      //setting CF_ENABLEHOOK shows an oldstyle dialog, unless lpTemplateName is set
      //and a template is linked in as a resource,
      //this also requires additional flas set:
      //https://msdn.microsoft.com/en-us/library/windows/desktop/ms646832(v=vs.85).aspx
      if (fdApplyButton in Options) then
      begin
        Flags := Flags or CF_ENABLEHOOK;
        lpfnHook := @FontDialogCallBack;
        lCustData := PtrInt(@ACommonDialog);
      end;
      RGBColors := ColorToRGB(Font.Color);
      if fdLimitSize in Options then
      begin
        nSizeMin := MinFontSize;
        nSizeMax := MaxFontSize;
      end;
    end;
    {$ifdef DebugCommonDialogEvents}
    debugln(['TWin32WSFontDialog.CreateHandle calling DoShow']);
    {$endif}
    TFontDialog(ACommonDialog).DoShow;
    UserResult := ChooseFontW(@CFW);
    // we need to update LF now
    LF.lfFaceName := UTF16ToUTF8(LFW.lfFaceName);
  end;

  SetDialogResult(ACommonDialog, UserResult);
  if UserResult then
  begin
    with TFontDialog(ACommonDialog).Font do
    begin
      if not Win32WidgetSet.MetricsFailed and IsFontNameDefault(Name) then
      begin
        if Sysutils.strlcomp(
          @Win32WidgetSet.Metrics.lfMessageFont.lfFaceName,
          @LF.lfFaceName,
          Length(LF.lfFaceName)) = 0 then
        begin
          Sysutils.StrLCopy(
            @LF.lfFaceName,
            PAnsiChar(Name), // Dialog.Font.Name
            Length(LF.lfFaceName));
        end;
        if LF.lfHeight = Win32WidgetSet.Metrics.lfMessageFont.lfHeight then
          LF.lfHeight := 0;
        if (CharSet = DEFAULT_CHARSET) and (Win32WidgetSet.Metrics.lfMessageFont.lfCharSet = LF.lfCharSet) then
          LF.lfCharSet := DEFAULT_CHARSET;
      end;
      Assign(LF);
      if (CF.rgbColors <> 0) or (Color <> clDefault) then
        Color := CF.RGBColors;
    end;
  end;
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSFontDialog.CreateHandle calling DoClose']);
  {$endif}
  TFontDialog(ACommonDialog).DoClose;
  Result := 0;
end;

class function TWin32WSFontDialog.QueryWSEventCapabilities(
  const ACommonDialog: TCommonDialog): TCDWSEventCapabilities;
begin
  Result := [cdecWSPerformsDoShow, cdecWSPerformsDoClose, cdecWSNoCanCloseSupport];
end;

{ TWin32WSCommonDialog }

class function TWin32WSCommonDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
begin
  Result := 0;
end;

class procedure TWin32WSCommonDialog.DestroyHandle(const ACommonDialog: TCommonDialog);
begin
  DestroyWindow(ACommonDialog.Handle);
end;

{ TWin32WSSelectDirectoryDialog }

{------------------------------------------------------------------------------
 Function: BrowseForFolderCallback
 Params: Window_hwnd - The window that receives a message for the window
         Msg         - The message received
         LParam      - Long-integer parameter
         lpData      - Data parameter, contains initial path.
  Returns: non-zero long-integer

  Handles the messages sent to the toolbar button by Windows
 ------------------------------------------------------------------------------}
function BrowseForFolderCallback(hwnd : Handle; uMsg : UINT;
  {%H-}lParam, lpData : LPARAM) : Integer; stdcall;
begin
  case uMsg of
    BFFM_INITIALIZED:
        // Setting root dir
        SendMessageW(hwnd, BFFM_SETSELECTIONW, WPARAM(True), lpData);
    //BFFM_SELCHANGED
    //  : begin
    //    if Assigned(FOnSelectionChange) then .....
    //    end;
  end;
  Result := 0;
end;

class function TWin32WSSelectDirectoryDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
var
  Dialog: IFileOpenDialog;
begin
  if CanUseVistaDialogs(TOpenDialog(ACommonDialog)) then
  begin
    if Succeeded(CoCreateInstance(CLSID_FileOpenDialog, nil, CLSCTX_INPROC_SERVER, IFileOpenDialog, Dialog)) and Assigned(Dialog) then
    begin
      Dialog._AddRef;
      TWin32WSOpenDialog.SetupVistaFileDialog(Dialog, TOpenDialog(ACommonDialog));
      Result := THandle(Dialog);
    end
    else
      Result := INVALID_HANDLE_VALUE;
  end
  else
    Result := CreateOldHandle(ACommonDialog);
end;

class function TWin32WSSelectDirectoryDialog.QueryWSEventCapabilities(
  const ACommonDialog: TCommonDialog): TCDWSEventCapabilities;
begin
  if CanUseVistaDialogs(TSelectDirectoryDialog(ACommonDialog)) then
    Result := [cdecWSPerformsDoShow,cdecWSPerformsDoCanClose]
  else
    Result := [cdecWSPerformsDoShow, cdecWSPerformsDoClose, cdecWSNoCanCloseSupport];
end;

class function TWin32WSSelectDirectoryDialog.CreateOldHandle(
  const ACommonDialog: TCommonDialog): THandle;
var
  Options : TOpenOptions;
  InitialDir : string;
  Buffer : PChar;
  iidl : PItemIDList;
  biw : TBROWSEINFOW;
  Bufferw : PWideChar absolute Buffer;
  InitialDirW: widestring;
  Title: widestring;
  DirName: string;
begin
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle A']);
  {$endif}
  DirName := '';
  InitialDir := TSelectDirectoryDialog(ACommonDialog).FileName;
  Options := TSelectDirectoryDialog(ACommonDialog).Options;

  if length(InitialDir)=0 then
    InitialDir := TSelectDirectoryDialog(ACommonDialog).InitialDir;
  if length(InitialDir)>0 then begin
    // remove the \ at the end.                                                                      
    if Copy(InitialDir,length(InitialDir),1)=PathDelim then
      InitialDir := copy(InitialDir,1, length(InitialDir)-1);
    // if it is a rootdirectory, then the InitialDir must have a \ at the end.
    if Copy(InitialDir,length(InitialDir),1)=DriveDelim then
      InitialDir := InitialDir + PathDelim;
  end;
  Buffer := CoTaskMemAlloc(MAX_PATH*2);
  InitialDirW:=UTF8ToUTF16(InitialDir);
  with biw do
  begin
    hwndOwner := GetOwnerHandle(ACommonDialog);
    pidlRoot := nil;
    pszDisplayName := BufferW;
    Title :=  UTF8ToUTF16(ACommonDialog.Title);
    lpszTitle := PWideChar(Title);
    ulFlags := BIF_RETURNONLYFSDIRS;
    if not (ofCreatePrompt in Options) then
      ulFlags := ulFlags + BIF_NONEWFOLDERBUTTON;
    if (ofEnableSizing in Options) then
      // better than flag BIF_USENEWUI, to hide editbox, it's not handy
      ulFlags := ulFlags + BIF_NEWDIALOGSTYLE;
    lpfn := @BrowseForFolderCallback;
    // this value will be passed to callback proc as lpData
    lParam := Windows.LParam(PWideChar(InitialDirW));
  end;
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle calling DoShow']);
  {$endif}
  TSelectDirectoryDialog(ACommonDialog).DoShow;
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle before SHBrowseForFolder']);
  {$endif}
  iidl := SHBrowseForFolderW(@biw);
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle after SHBrowseForFolder']);
  {$endif}

  if Assigned(iidl) then
  begin
    SHGetPathFromIDListW(iidl, BufferW);
    CoTaskMemFree(iidl);
    DirName := UTF16ToUTF8(widestring(BufferW));
  end;

  if Assigned(iidl) then
  begin
    TSelectDirectoryDialog(ACommonDialog).FileName := DirName;
    TSelectDirectoryDialog(ACommonDialog).Files.Text := DirName;
  end;
  SetDialogResult(ACommonDialog, assigned(iidl));

  CoTaskMemFree(Buffer);

  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle calling DoClose']);
  {$endif}
  TSelectDirectoryDialog(ACommonDialog).DoClose;
  Result := 0;
  {$ifdef DebugCommonDialogEvents}
  debugln(['TWin32WSSelectDirectoryDialog.CreateOldHandle End']);
  {$endif}
end;

{ TFileDialogEvents }

// Only gets called when user clicks OK in IFileDialog
function TFileDialogEvents.OnFileOk(pfd: IFileDialog): HResult; stdcall;
var
  CanClose: Boolean;
begin
  {$ifdef DebugCommonDialogEvents}
  debugln('TFileDialogEvents.OnFileOk A');
  {$endif}
  Result := TWin32WSOpenDialog.ProcessVistaDialogResult(pfd, FDialog);
  if Succeeded(Result) then
  begin
    FDialog.UserChoice := mrOK; //DoCanClose needs this
    CanClose := True;
    {$ifdef DebugCommonDialogEvents}
    debugln('TFileDialogEvents.OnFileOk: calling DoCanClose');
    {$endif}
    FDialog.DoCanClose(CanClose);
    if CanClose then
    begin
      Result := S_OK;
    end
    else
      Result := S_FALSE;
  end;
  {$ifdef DebugCommonDialogEvents}
  debugln('TFileDialogEvents.OnFileOk End');
  {$endif}
end;

function TFileDialogEvents.OnFolderChanging(pfd: IFileDialog; psifolder: IShellItem): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnFolderChange(pfd: IFileDialog): HResult; stdcall;
//var
//  ShellItem: IShellItem;
begin
  //Result := pfd.Getfolder(@ShellItem);
  //if Succeeded(Result) then
  //begin
  //  FDialog.Files.Clear;
 //   FDialog.FileName := TWin32WSOpenDialog.GetFileName(ShellItem);
 //   FDialog.Files.Add(FDialog.FileName);
 //   FDialog.DoFolderChange;
 // end;
  FDialog.DoFolderChange;
  Result := S_OK;
end;

function TFileDialogEvents.OnSelectionChange(pfd: IFileDialog): HResult; stdcall;
var
  ShellItem: IShellItem;
begin
  Result := pfd.GetCurrentSelection(@ShellItem);
  if Succeeded(Result) then
  begin
    FDialog.Files.Clear;
    FDialog.FileName := TWin32WSOpenDialog.GetFileName(ShellItem);
    FDialog.Files.Add(FDialog.FileName);
    FDialog.DoSelectionChange;
  end;
end;

function TFileDialogEvents.OnShareViolation(pfd: IFileDialog; psi: IShellItem; pResponse: pFDE_SHAREVIOLATION_RESPONSE): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnTypeChange(pfd: IFileDialog): HResult; stdcall;
var
  NewIndex: UINT;
begin
  Result := pfd.GetFileTypeIndex(@NewIndex);
  if Succeeded(Result) then
    FDialog.IntfFileTypeChanged(NewIndex);
end;

function TFileDialogEvents.OnOverwrite(pfd: IFileDialog; psi: IShellItem; pResponse: pFDE_OVERWRITE_RESPONSE): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnItemSelected(pfdc: IFileDialogCustomize; dwIDCtl: DWORD; dwIDItem: DWORD): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnButtonClicked(pfdc: IFileDialogCustomize; dwIDCtl: DWORD): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnCheckButtonToggled(pfdc: IFileDialogCustomize; dwIDCtl: DWORD; bChecked: BOOL): HResult; stdcall;
begin
  Result := S_OK;
end;

function TFileDialogEvents.OnControlActivating(pfdc: IFileDialogCustomize; dwIDCtl: DWORD): HResult; stdcall;
begin
  Result := S_OK;
end;

constructor TFileDialogEvents.Create(ADialog: TOpenDialog);
begin
  inherited Create;
  FDialog := ADialog;
end;

initialization
  if (Win32MajorVersion = 4) then
    OpenFileNameSize := SizeOf(OPENFILENAME_NT4)
  else
    OpenFileNameSize := SizeOf(OPENFILENAME);
end.

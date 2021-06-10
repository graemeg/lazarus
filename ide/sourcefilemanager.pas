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

  Abstract:
    Functions to deal with different kinds of source files like
     units, projects, packages and their related IDE features.
    The code is copied and refactored from the huge main.pp. The goal was to not
    call methods defined in TMainIDE but there are still some calls doing it.
}
unit SourceFileManager;

{$mode objfpc}{$H+}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  Classes, SysUtils, typinfo, math, fpjson, Laz_AVL_Tree,
  // LCL
  Controls, Forms, Dialogs, LCLIntf, LCLType, LclStrConsts,
  LResources, LCLMemManager,
  // LazUtils
  LConvEncoding, LazFileCache, FileUtil, LazFileUtils, LazLoggerBase,
  LazUtilities, LazStringUtils, LazUTF8, LazTracer, AvgLvlTree,
  // Codetools
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  BasicCodeTools, CodeToolsStructs, CodeToolManager, FileProcs, DefineTemplates,
  CodeCache, CodeTree, FindDeclarationTool, KeywordFuncLists,
  // BuildIntf
  NewItemIntf, ProjectIntf, PackageIntf, PackageDependencyIntf, IDEExternToolIntf,
  // IdeIntf
  IDEDialogs, PropEdits, IDEMsgIntf, LazIDEIntf, MenuIntf, IDEWindowIntf, FormEditingIntf,
  ObjectInspector, ComponentReg, SrcEditorIntf, EditorSyntaxHighlighterDef, UnitResources,
  // IDE
  IDEProcs, DialogProcs, IDEProtocol, LazarusIDEStrConsts, NewDialog, NewProjectDlg,
  MainBase, MainBar, MainIntf, Project, ProjectDefs, ProjectInspector, CompilerOptions,
  SourceSynEditor, SourceEditor, EditorOptions, EnvironmentOpts, CustomFormEditor,
  ControlSelection, FormEditor, EmptyMethodsDlg, BaseDebugManager, TransferMacros,
  BuildManager, EditorMacroListViewer, FindRenameIdentifier, BuildModesManager,
  ViewUnit_Dlg, InputHistory, CheckLFMDlg, etMessagesWnd,
  ConvCodeTool, BasePkgManager, PackageDefs, PackageSystem, Designer, DesignerProcs;

type

  TBookmarkCommandsStamp = record
  private
    FBookmarksStamp: Int64;
  public
    function Changed(ABookmarksStamp: Int64): Boolean;
  end;

  TFileCommandsStamp = record
  private
    FSrcEdit: TSourceEditor;
  public
    function Changed(ASrcEdit: TSourceEditor): Boolean;
  end;

  TProjectCommandsStamp = record
  private
    FUnitInfo: TUnitInfo;
    FProjectChangeStamp: Int64;
    FProjectSessionChangeStamp: Int64;
    FCompilerParseStamp: integer;
    FBuildMacroChangeStamp: integer;
  public
    function Changed(AUnitInfo: TUnitInfo): Boolean;
  end;

  TPackageCommandsStamp = record
  private
    FUnitInfo: TUnitInfo;
    FPackagesChangeStamp: Int64;
  public
    function Changed(AUnitInfo: TUnitInfo): Boolean;
  end;

  TSourceEditorTabCommandsStamp = record
  private
    FSrcEdit: TSourceEditor;
    FSrcEditLocked: Boolean;
    FSourceNotebook: TSourceNotebook;
    FPageIndex, FPageCount: Integer;
  public
    function Changed(ASrcEdit: TSourceEditor): Boolean;
  end;

  TSourceEditorCommandsStamp = record
  private
    FSrcEdit: TSourceEditor;
    FDisplayState: TDisplayState;
    FEditorComponentStamp: int64;
    FEditorCaretStamp: int64;

    FDesigner: TDesigner;
    FDesignerSelectionStamp: int64;
    FDesignerStamp: int64;
  public
    function Changed(ASrcEdit: TSourceEditor; ADesigner: TDesigner;
      ADisplayState: TDisplayState): Boolean;
  end;

  { TFileOpener }

  TFileOpener = class
  private
    FFileName: string;
    FUseWindowID: Boolean;
    FPageIndex: integer;
    FWindowIndex: integer;
    // Used by OpenEditorFile
    FUnitIndex: integer;
    FEditorInfo: TUnitEditorInfo;
    FNewEditorInfo: TUnitEditorInfo;
    FFlags: TOpenFlags;
    FUnknownFile: boolean;
    FNewUnitInfo: TUnitInfo;
    // Used by OpenFileAtCursor
    FActiveSrcEdit: TSourceEditor;
    FActiveUnitInfo: TUnitInfo;
    FIsIncludeDirective: boolean;
    function OpenFileInSourceEditor(AnEditorInfo: TUnitEditorInfo): TModalResult;
    // Used by GetAvailableUnitEditorInfo
    function AvailSrcWindowIndex(AnUnitInfo: TUnitInfo): Integer;
    // Used by OpenEditorFile
    function OpenResource: TModalResult;
    function ChangeEditorPage: TModalResult;
    procedure CheckInternalFile;
    function CheckRevert: TModalResult;
    function OpenKnown: TModalResult;
    function OpenUnknown: TModalResult;
    function OpenUnknownFile: TModalResult;
    function OpenNotExistingFile: TModalResult;
    function PrepareFile: TModalResult;
    function PrepareRevert(DiskFilename: String): TModalResult;
    function ResolvePossibleSymlink: TModalResult;
    // Used by OpenFileAtCursor
    function CheckIfIncludeDirectiveInFront(const Line: string; X: integer): boolean;
    function FindFile(SearchPath: String): Boolean;
    function GetFilenameAtRowCol(XY: TPoint): string;
  public
    // These methods have a global wrapper
    function GetAvailableUnitEditorInfo(AnUnitInfo: TUnitInfo;
      ACaretPoint: TPoint; WantedTopLine: integer = -1): TUnitEditorInfo;
    function OpenEditorFile(APageIndex, AWindowIndex: integer;
      AEditorInfo: TUnitEditorInfo; AFlags: TOpenFlags): TModalResult;
    function OpenFileAtCursor: TModalResult;
    function OpenMainUnit: TModalResult;
    function RevertMainUnit: TModalResult;
  end;


function CreateSrcEditPageName(const AnUnitName, AFilename: string;
  IgnoreEditor: TSourceEditor): string;
procedure UpdateDefaultPasFileExt;

// Wrappers for TFileOpener methods.
// WindowIndex is WindowID
function GetAvailableUnitEditorInfo(AnUnitInfo: TUnitInfo;
  ACaretPoint: TPoint; WantedTopLine: integer = -1): TUnitEditorInfo;
function OpenEditorFile(AFileName: string; PageIndex, WindowIndex: integer;
  AEditorInfo: TUnitEditorInfo; Flags: TOpenFlags; UseWindowID: Boolean = False): TModalResult;
function OpenFileAtCursor(ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo): TModalResult;
function OpenMainUnit(PageIndex, WindowIndex: integer;
  Flags: TOpenFlags; UseWindowID: Boolean = False): TModalResult;
function RevertMainUnit: TModalResult;
// recent
procedure AddRecentProjectFile(const AFilename: string);
procedure RemoveRecentProjectFile(const AFilename: string);
procedure UpdateSourceNames;
function CheckEditorNeedsSave(AEditor: TSourceEditorInterface;
    IgnoreSharedEdits: Boolean): Boolean;
procedure ArrangeSourceEditorAndMessageView(PutOnTop: boolean);
// files/units/projects
function SomethingOfProjectIsModified(Verbose: boolean = false): boolean;
function NewFile(NewFileDescriptor: TProjectFileDescriptor;
  var NewFilename: string; NewSource: string;
  NewFlags: TNewFlags; NewOwner: TObject): TModalResult;
function NewOther: TModalResult;
function NewUnitOrForm(Template: TNewIDEItemTemplate;
  DefaultDesc: TProjectFileDescriptor): TModalResult;
procedure CreateFileDialogFilterForSourceEditorFiles(Filter: string;
    out AllEditorMask, AllMask: string);
function SaveEditorFile(AEditor: TSourceEditorInterface; Flags: TSaveFlags): TModalResult;
function SaveEditorFile(const Filename: string; Flags: TSaveFlags): TModalResult;
function CloseEditorFile(AEditor: TSourceEditorInterface; Flags: TCloseFlags):TModalResult;
function CloseEditorFile(const Filename: string; Flags: TCloseFlags): TModalResult;
// interactive unit selection
function SelectProjectItems(ItemList: TViewUnitEntries; ItemType: TIDEProjectItem): TModalResult;
function SelectUnitComponents(DlgCaption: string; ItemType: TIDEProjectItem;
  Files: TStringList): TModalResult;
// unit search
function FindUnitFileImpl(const AFilename: string; TheOwner: TObject = nil;
                          Flags: TFindUnitFileFlags = []): string;
function FindSourceFileImpl(const AFilename, BaseDirectory: string;
                            Flags: TFindSourceFlags): string;
function FindUnitsOfOwnerImpl(TheOwner: TObject; Flags: TFindUnitsOfOwnerFlags): TStrings;
// project
function AddActiveUnitToProject: TModalResult;
function AddUnitToProject(const AEditor: TSourceEditorInterface): TModalResult;
function RemoveFromProjectDialog: TModalResult;
function InitNewProject(ProjectDesc: TProjectDescriptor): TModalResult;
function InitOpenedProjectFile(AFileName: string; Flags: TOpenFlags): TModalResult;
procedure NewProjectFromFile;
function CreateProjectForProgram(ProgramBuf: TCodeBuffer): TModalResult;
function InitProjectForProgram(ProgramBuf: TCodeBuffer): TModalResult;
function SaveProject(Flags: TSaveFlags): TModalResult;
function SaveProjectIfChanged: TModalResult;
function CloseProject: TModalResult;
procedure OpenProject(aMenuItem: TIDEMenuItem);
function CompleteLoadingProjectInfo: TModalResult;
procedure CloseAll;
procedure InvertedFileClose(PageIndex: LongInt; SrcNoteBook: TSourceNotebook; CloseOnRightSideOnly: Boolean = False);
function UpdateAppTitleInSource: Boolean;
function UpdateAppScaledInSource: Boolean;
function UpdateAppAutoCreateForms: boolean;
// designer
function DesignerUnitIsVirtual(aLookupRoot: TComponent): Boolean;
function CheckLFMInEditor(LFMUnitInfo: TUnitInfo; Quiet: boolean): TModalResult;
function LoadLFM(AnUnitInfo: TUnitInfo; OpenFlags: TOpenFlags;
                   CloseFlags: TCloseFlags): TModalResult;
function LoadLFM(AnUnitInfo: TUnitInfo; LFMBuf: TCodeBuffer;
                   OpenFlags: TOpenFlags;
                   CloseFlags: TCloseFlags): TModalResult;
function OpenComponent(const UnitFilename: string; OpenFlags: TOpenFlags;
    CloseFlags: TCloseFlags; out Component: TComponent): TModalResult;
function CloseUnitComponent(AnUnitInfo: TUnitInfo; Flags: TCloseFlags): TModalResult;
function CloseDependingUnitComponents(AnUnitInfo: TUnitInfo;
                                      Flags: TCloseFlags): TModalResult;
function UnitComponentIsUsed(AnUnitInfo: TUnitInfo;
                             CheckHasDesigner: boolean): boolean;
function RemoveFilesFromProject(UnitInfos: TFPList): TModalResult;
function AskSaveProject(const ContinueText, ContinueBtn: string): TModalResult;
function SaveEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean;


// These are local functions. Forward reference is needed for most of them.
//  function AskToSaveEditors(EditorList: TList): TModalResult;
//  function CheckMainSrcLCLInterfaces(Silent: boolean): TModalResult;
//  function FileExistsInIDE(const Filename: string;
//    SearchFlags: TProjectFileSearchFlags): boolean;
//new unit
  function CreateNewCodeBuffer(Descriptor: TProjectFileDescriptor;
      NewOwner: TObject; NewFilename: string; var NewCodeBuffer: TCodeBuffer;
      var NewUnitName: string): TModalResult;
  function CreateNewForm(NewUnitInfo: TUnitInfo;
      AncestorType: TPersistentClass; ResourceCode: TCodeBuffer;
      UseCreateFormStatements, DisableAutoSize: Boolean): TModalResult;
  function NewUniqueComponentName(Prefix: string): string;
//save unit
  function ShowSaveFileAsDialog(var AFilename: string; AnUnitInfo: TUnitInfo;
      var LFMCode, LRSCode: TCodeBuffer; CanAbort: boolean): TModalResult;
  function SaveUnitComponent(AnUnitInfo: TUnitInfo;
      LRSCode, LFMCode: TCodeBuffer; Flags: TSaveFlags): TModalResult;
  function RemoveLooseEvents(AnUnitInfo: TUnitInfo): TModalResult;
  function RenameUnit(AnUnitInfo: TUnitInfo; NewFilename, NewUnitName: string;
      var LFMCode, LRSCode: TCodeBuffer): TModalResult;
  function RenameUnitLowerCase(AnUnitInfo: TUnitInfo; AskUser: boolean): TModalresult;
  function ReplaceUnitUse(OldFilename, OldUnitName, NewFilename, NewUnitName: string;
                          IgnoreErrors, Quiet, Confirm: boolean): TModalResult;
//designer
  function LoadResourceFile(AnUnitInfo: TUnitInfo; var LFMCode, LRSCode: TCodeBuffer;
      AutoCreateResourceCode, ShowAbort: boolean): TModalResult;
//  function FindBaseComponentClass(AnUnitInfo: TUnitInfo; const AComponentClassName,
//      DescendantClassName: string; out AComponentClass: TComponentClass): boolean;
  function LoadAncestorDependencyHidden(AnUnitInfo: TUnitInfo;
      const aComponentClassName: string; OpenFlags: TOpenFlags;
      out AncestorClass: TComponentClass; out AncestorUnitInfo: TUnitInfo): TModalResult;
//  function FindComponentClass(AnUnitInfo: TUnitInfo; const AComponentClassName: string;
//      Quiet: boolean; out ComponentUnitInfo: TUnitInfo; out AComponentClass: TComponentClass;
//      out LFMFilename: string; out AncestorClass: TComponentClass): TModalResult;
  function LoadComponentDependencyHidden(AnUnitInfo: TUnitInfo;
      const AComponentClassName: string; Flags: TOpenFlags; MustHaveLFM: boolean;
      out AComponentClass: TComponentClass; out ComponentUnitInfo: TUnitInfo;
      out AncestorClass: TComponentClass; const IgnoreBtnText: string = ''): TModalResult;
  function LoadIDECodeBuffer(var ACodeBuffer: TCodeBuffer;
      const AFilename: string; Flags: TLoadBufferFlags; ShowAbort: boolean): TModalResult;
//save project
  function ShowSaveProjectAsDialog(UseMainSourceFile: boolean): TModalResult;
  function SaveProjectInfo(var Flags: TSaveFlags): TModalResult;
  procedure GetMainUnit(out MainUnitInfo: TUnitInfo; out MainUnitSrcEdit: TSourceEditor);
  procedure SaveSrcEditorProjectSpecificSettings(AnEditorInfo: TUnitEditorInfo);
  procedure SaveSourceEditorProjectSpecificSettings;
  procedure UpdateProjectResourceInfo;


implementation

function CreateSrcEditPageName(const AnUnitName, AFilename: string;
  IgnoreEditor: TSourceEditor): string;
begin
  Result:=AnUnitName;
  if Result='' then
    Result:=ExtractFileName(AFilename);
  Result:=SourceEditorManager.FindUniquePageName(Result,IgnoreEditor);
end;

procedure UpdateDefaultPasFileExt;
var
  DefPasExt: string;
begin
  // change default pascal file extensions
  DefPasExt:=PascalExtension[EnvironmentOptions.PascalFileExtension];
  if LazProjectFileDescriptors<>nil then
    LazProjectFileDescriptors.DefaultPascalFileExt:=DefPasExt;
end;

// Wrappers for TFileOpener methods.

function GetAvailableUnitEditorInfo(AnUnitInfo: TUnitInfo;
  ACaretPoint: TPoint; WantedTopLine: integer = -1): TUnitEditorInfo;
var
  Opener: TFileOpener;
begin
  Opener := TFileOpener.Create;
  try
    Result := Opener.GetAvailableUnitEditorInfo(AnUnitInfo,ACaretPoint,WantedTopLine);
  finally
    Opener.Free;
  end;
end;

function OpenEditorFile(AFileName: string; PageIndex, WindowIndex: integer;
  AEditorInfo: TUnitEditorInfo; Flags: TOpenFlags; UseWindowID: Boolean = False): TModalResult;
var
  Opener: TFileOpener;
begin
  Opener := TFileOpener.Create;
  try
    Opener.FFileName := AFileName;
    Opener.FUseWindowID := UseWindowID;
    Result := Opener.OpenEditorFile(PageIndex,WindowIndex,AEditorInfo,Flags);
  finally
    Opener.Free;
  end;
end;

function OpenFileAtCursor(ActiveSrcEdit: TSourceEditor; ActiveUnitInfo: TUnitInfo): TModalResult;
var
  Opener: TFileOpener;
begin
  Opener := TFileOpener.Create;
  try
    Opener.FActiveSrcEdit := ActiveSrcEdit;
    Opener.FActiveUnitInfo := ActiveUnitInfo;
    Result := Opener.OpenFileAtCursor;
  finally
    Opener.Free;
  end;
end;

function OpenMainUnit(PageIndex, WindowIndex: integer;
  Flags: TOpenFlags; UseWindowID: Boolean): TModalResult;
var
  Opener: TFileOpener;
begin
  Opener := TFileOpener.Create;
  try
    Opener.FPageIndex := PageIndex;
    Opener.FWindowIndex := WindowIndex;
    Opener.FFlags := Flags;
    Opener.FUseWindowID := UseWindowID;
    Result := Opener.OpenMainUnit;
  finally
    Opener.Free;
  end;
end;

function RevertMainUnit: TModalResult;
var
  Opener: TFileOpener;
begin
  Opener := TFileOpener.Create;
  try
    Result := Opener.RevertMainUnit;
  finally
    Opener.Free;
  end;
end;

{ TBookmarkCommandsStamp }

function TBookmarkCommandsStamp.Changed(ABookmarksStamp: Int64): Boolean;
begin
  Result := (FBookmarksStamp <> ABookmarksStamp);
  if Result then
    FBookmarksStamp := ABookmarksStamp;
end;

{ TFileCommandsStamp }

function TFileCommandsStamp.Changed(ASrcEdit: TSourceEditor): Boolean;
begin
  Result := not(
        (FSrcEdit = ASrcEdit)
    );

  if not Result then Exit;

  FSrcEdit := ASrcEdit;
end;

{ TProjectCommandsStamp }

function TProjectCommandsStamp.Changed(AUnitInfo: TUnitInfo): Boolean;
var
  CurProjectChangeStamp, CurProjectSessionChangeStamp: Integer;
begin
  if Project1=nil then
  begin
    CurProjectChangeStamp := LUInvalidChangeStamp;
    CurProjectSessionChangeStamp := LUInvalidChangeStamp;
  end else
  begin
    CurProjectChangeStamp := Project1.ChangeStamp;
    CurProjectSessionChangeStamp := Project1.SessionChangeStamp;
  end;
  Result := not(
        (FUnitInfo = AUnitInfo)
    and (FProjectChangeStamp = CurProjectChangeStamp)
    and (FProjectSessionChangeStamp = CurProjectSessionChangeStamp)
    and (FCompilerParseStamp = CompilerParseStamp)
    and (FBuildMacroChangeStamp = BuildMacroChangeStamp)
    );

  if not Result then Exit;

  FUnitInfo := AUnitInfo;
  FProjectChangeStamp := CurProjectChangeStamp;
  FProjectSessionChangeStamp := CurProjectSessionChangeStamp;
  FCompilerParseStamp := CompilerParseStamp;
  FBuildMacroChangeStamp := BuildMacroChangeStamp;
end;

{ TPackageCommandsStamp }

function TPackageCommandsStamp.Changed(AUnitInfo: TUnitInfo): Boolean;
begin
  Result := not(
        (FUnitInfo = AUnitInfo)
    and (FPackagesChangeStamp = PackageGraph.ChangeStamp)
    );

  if not Result then Exit;

  FUnitInfo := AUnitInfo;
  FPackagesChangeStamp := PackageGraph.ChangeStamp;
end;

{ TSourceEditorTabCommandsStamp }

function TSourceEditorTabCommandsStamp.Changed(ASrcEdit: TSourceEditor): Boolean;
begin
  Result := not(
        (FSrcEdit = ASrcEdit)
    and ((ASrcEdit = nil) or (
            (FSrcEditLocked = ASrcEdit.IsLocked)
        and (FSourceNotebook = ASrcEdit.SourceNotebook)
        and (FPageIndex = ASrcEdit.SourceNotebook.PageIndex)
        and (FPageCount = ASrcEdit.SourceNotebook.PageCount)))
    );

  if not Result then Exit;

  FSrcEdit := ASrcEdit;
  if ASrcEdit<>nil then
  begin
    FSrcEditLocked := ASrcEdit.IsLocked;
    FSourceNotebook := ASrcEdit.SourceNotebook;
    FPageIndex := ASrcEdit.SourceNotebook.PageIndex;
    FPageCount := ASrcEdit.SourceNotebook.PageCount;
  end;
end;

{ TSourceEditorCommandsStamp }

function TSourceEditorCommandsStamp.Changed(ASrcEdit: TSourceEditor;
  ADesigner: TDesigner; ADisplayState: TDisplayState): Boolean;
begin
  Result := not(
        (FSrcEdit = ASrcEdit)
    and (FDesigner = ADesigner)
    and (FDisplayState = ADisplayState)
    and ((ASrcEdit = nil) or (
            (FEditorComponentStamp = ASrcEdit.EditorComponent.ChangeStamp)
        and (FEditorCaretStamp = ASrcEdit.EditorComponent.CaretStamp)))
    and ((ADesigner = nil) or (
            (FDesignerSelectionStamp = ADesigner.Selection.ChangeStamp)
        and (FDesignerStamp = ADesigner.ChangeStamp)))
    );

  if not Result then Exit;

  FSrcEdit := ASrcEdit;
  FDesigner := ADesigner;
  FDisplayState := ADisplayState;
  if ASrcEdit<>nil then
  begin
    FEditorComponentStamp := ASrcEdit.EditorComponent.ChangeStamp;
    FEditorCaretStamp := ASrcEdit.EditorComponent.CaretStamp;
  end;
  if ADesigner<>nil then
  begin
    FDesignerSelectionStamp := ADesigner.Selection.ChangeStamp;
    FDesignerStamp := ADesigner.ChangeStamp;
  end;
end;

//==============================================================================

{ TFileOpener }

function TFileOpener.OpenFileInSourceEditor(AnEditorInfo: TUnitEditorInfo): TModalResult;
var
  NewSrcEdit: TSourceEditor;
  AFilename: string;
  NewCaretXY: TPoint;
  NewTopLine: LongInt;
  NewLeftChar: LongInt;
  NewErrorLine: LongInt;
  NewExecutionLine: LongInt;
  FoldState: String;
  SrcNotebook: TSourceNotebook;
  AnUnitInfo: TUnitInfo;
  AShareEditor: TSourceEditor;
begin
  //debugln(['TFileOpener.OpenFileInSourceEditor ',AnEditorInfo.UnitInfo.Filename,' Window=',WindowIndex,'/',SourceEditorManager.SourceWindowCount,' Page=',PageIndex]);
  AnUnitInfo := AnEditorInfo.UnitInfo;
  AFilename:=AnUnitInfo.Filename;
  if (FWindowIndex < 0) then
    SrcNotebook := SourceEditorManager.ActiveOrNewSourceWindow
  else
  if FUseWindowID then begin
    SrcNotebook := SourceEditorManager.SourceWindowWithID(FWindowIndex);
    FWindowIndex := SourceEditorManager.IndexOfSourceWindow(SrcNotebook);
  end
  else
  if (FWindowIndex >= SourceEditorManager.SourceWindowCount) then begin
    SrcNotebook := SourceEditorManager.NewSourceWindow;
  end
  else
    SrcNotebook := SourceEditorManager.SourceWindows[FWindowIndex];

  // get syntax highlighter type
  if (uifInternalFile in AnUnitInfo.Flags) then
    AnUnitInfo.UpdateDefaultHighlighter(lshFreePascal)
  else
    AnUnitInfo.UpdateDefaultHighlighter(FilenameToLazSyntaxHighlighter(AFilename));

  SrcNotebook.IncUpdateLock;
  try
    //DebugLn(['TFileOpener.OpenFileInSourceEditor Revert=',ofRevert in Flags,' ',AnUnitInfo.Filename,' PageIndex=',PageIndex]);
    if (not (ofRevert in FFlags)) or (FPageIndex<0) then begin
      // create a new source editor

      // update marks and cursor positions in Project1, so that merging the old
      // settings during restoration will work
      SaveSourceEditorProjectSpecificSettings;
      AShareEditor := nil;
      if AnUnitInfo.OpenEditorInfoCount > 0 then
        AShareEditor := TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent);
      NewSrcEdit:=SrcNotebook.NewFile(
        CreateSrcEditPageName(AnUnitInfo.Unit_Name, AFilename, AShareEditor),
        AnUnitInfo.Source, False, AShareEditor);
      NewSrcEdit.EditorComponent.BeginUpdate;
      MainIDEBar.itmFileClose.Enabled:=True;
      MainIDEBar.itmFileCloseAll.Enabled:=True;
      NewCaretXY := AnEditorInfo.CursorPos;
      NewTopLine := AnEditorInfo.TopLine;
      FoldState := AnEditorInfo.FoldState;
      NewLeftChar:=1;
      NewErrorLine:=-1;
      NewExecutionLine:=-1;
    end else begin
      // revert code in existing source editor
      NewSrcEdit:=SourceEditorManager.SourceEditorsByPage[FWindowIndex, FPageIndex];
      NewCaretXY:=NewSrcEdit.EditorComponent.CaretXY;
      NewTopLine:=NewSrcEdit.EditorComponent.TopLine;
      FoldState := NewSrcEdit.EditorComponent.FoldState;
      NewLeftChar:=NewSrcEdit.EditorComponent.LeftChar;
      NewErrorLine:=NewSrcEdit.ErrorLine;
      NewExecutionLine:=NewSrcEdit.ExecutionLine;
      NewSrcEdit.EditorComponent.BeginUpdate;
      if NewSrcEdit.CodeBuffer=AnUnitInfo.Source then begin
        AnUnitInfo.Source.AssignTo(NewSrcEdit.EditorComponent.Lines,true);
      end else
        NewSrcEdit.CodeBuffer:=AnUnitInfo.Source;
      AnUnitInfo.ClearModifieds;
      //DebugLn(['TFileOpener.OpenFileInSourceEditor NewCaretXY=',dbgs(NewCaretXY),' NewTopLine=',NewTopLine]);
    end;

    NewSrcEdit.IsLocked := AnEditorInfo.IsLocked;
    AnEditorInfo.EditorComponent := NewSrcEdit;
    //debugln(['TFileOpener.OpenFileInSourceEditor ',AnUnitInfo.Filename]);

    // restore source editor settings
    DebugBoss.DoRestoreDebuggerMarks(AnUnitInfo);
    NewSrcEdit.SyntaxHighlighterType := AnEditorInfo.SyntaxHighlighter;
    NewSrcEdit.EditorComponent.AfterLoadFromFile;
    try
      NewSrcEdit.EditorComponent.FoldState := FoldState;
    except
      IDEMessageDialog(lisError, lisFailedToLoadFoldStat, mtError, [mbOK]);
    end;

    NewSrcEdit.EditorComponent.CaretXY:=NewCaretXY;
    NewSrcEdit.EditorComponent.TopLine:=NewTopLine;
    NewSrcEdit.EditorComponent.LeftChar:=NewLeftChar;
    NewSrcEdit.ErrorLine:=NewErrorLine;
    NewSrcEdit.ExecutionLine:=NewExecutionLine;
    NewSrcEdit.ReadOnly:=AnUnitInfo.ReadOnly;
    NewSrcEdit.Modified:=false;

    // mark unit as loaded
    NewSrcEdit.EditorComponent.EndUpdate;
    AnUnitInfo.Loaded:=true;
  finally
    SrcNotebook.DecUpdateLock;
  end;

  // update statusbar and focus editor
  if (not (ofProjectLoading in FFlags)) then begin
    SourceEditorManager.ActiveEditor := NewSrcEdit;
    SourceEditorManager.ShowActiveWindowOnTop(True);
  end;
  SrcNoteBook.UpdateStatusBar;
  SrcNotebook.BringToFront;

  Result:=mrOk;
end;

function TFileOpener.AvailSrcWindowIndex(AnUnitInfo: TUnitInfo): Integer;
var
  i: Integer;
begin
  Result := -1;
  i := 0;
  if AnUnitInfo.OpenEditorInfoCount > 0 then
    while (i < SourceEditorManager.SourceWindowCount) and
          (SourceEditorManager.SourceWindowByLastFocused[i].IndexOfEditorInShareWith
             (TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent)) >= 0)
    do
      inc(i);
  if i < SourceEditorManager.SourceWindowCount then
    Result := SourceEditorManager.IndexOfSourceWindow(SourceEditorManager.SourceWindowByLastFocused[i]);
end;

function TFileOpener.GetAvailableUnitEditorInfo(AnUnitInfo: TUnitInfo;
  ACaretPoint: TPoint; WantedTopLine: integer): TUnitEditorInfo;

  function EditorMatches(AEditInfo: TUnitEditorInfo;
     AAccess: TEditorOptionsEditAccessOrderEntry; ALockRun: Integer = 0): Boolean;
  var
    AEdit: TSourceEditor;
  begin
    AEdit := TSourceEditor(AEditInfo.EditorComponent);
    Result := False;
    case AAccess.SearchLocked of
      eoeaIgnoreLock: ;
      eoeaLockedOnly:   if not AEdit.IsLocked then exit;
      eoeaUnlockedOnly: if AEdit.IsLocked then exit;
      eoeaLockedFirst:  if (not AEdit.IsLocked) and (ALockRun = 0) then exit;
      eoeaLockedLast:   if (AEdit.IsLocked) and (ALockRun = 0) then exit;
    end;
    case AAccess.SearchInView of
      eoeaIgnoreInView: ;
      eoeaInViewOnly:   if not AEdit.IsCaretOnScreen(ACaretPoint, False) then exit;
      eoeaInViewSoftCenterOnly: if not AEdit.IsCaretOnScreen(ACaretPoint, True) then exit;
    end;
    Result := True;
  end;

var
  i, j, w, LockRun: Integer;
  Access: TEditorOptionsEditAccessOrderEntry;
begin
  Result := nil;
  // Check for already open Editor. If there is none, then it must be opened in OpenEditorFile
  if AnUnitInfo.OpenEditorInfoCount = 0 then exit;
  for i := 0 to EditorOpts.MultiWinEditAccessOrder.Count - 1 do begin
    Access := EditorOpts.MultiWinEditAccessOrder[i];
    if not Access.Enabled then continue;
    LockRun := 1;
    if Access.SearchLocked in [eoeaLockedFirst, eoeaLockedLast] then LockRun := 0;
    repeat
      case Access.RealSearchOrder of
        eoeaOrderByEditFocus, eoeaOrderByListPref:
          begin
            for j := 0 to AnUnitInfo.OpenEditorInfoCount - 1 do
              if EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                Result := AnUnitInfo.OpenEditorInfo[j];
                break;
              end;
          end;
        eoeaOrderByWindowFocus:
          begin
            for w := 0 to SourceEditorManager.SourceWindowCount - 1 do begin
              for j := 0 to AnUnitInfo.OpenEditorInfoCount - 1 do
                if (TSourceEditor(AnUnitInfo.OpenEditorInfo[j].EditorComponent).SourceNotebook
                    = SourceEditorManager.SourceWindowByLastFocused[w])
                and EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                  Result := AnUnitInfo.OpenEditorInfo[j];
                  break;
                end;
              if Result <> nil then break;
            end;
          end;
        eoeaOrderByOldestEditFocus:
          begin
            for j := AnUnitInfo.OpenEditorInfoCount - 1 downto 0 do
              if EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                Result := AnUnitInfo.OpenEditorInfo[j];
                break;
              end;
          end;
        eoeaOrderByOldestWindowFocus:
          begin
            for w := SourceEditorManager.SourceWindowCount - 1 downto 0 do begin
              for j := 0 to AnUnitInfo.OpenEditorInfoCount - 1 do
                if (TSourceEditor(AnUnitInfo.OpenEditorInfo[j].EditorComponent).SourceNotebook
                    = SourceEditorManager.SourceWindowByLastFocused[w])
                and EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                  Result := AnUnitInfo.OpenEditorInfo[j];
                  break;
                end;
              if Result <> nil then break;
            end;
          end;
        eoeaOnlyCurrentEdit:
          begin
            LockRun := 1;
            for j := 0 to AnUnitInfo.OpenEditorInfoCount - 1 do
              if (AnUnitInfo.OpenEditorInfo[j].EditorComponent = SourceEditorManager.ActiveEditor)
              and EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                Result := AnUnitInfo.OpenEditorInfo[j];
                break;
              end;
          end;
        eoeaOnlyCurrentWindow:
          begin
            LockRun := 1;
            for j := 0 to AnUnitInfo.OpenEditorInfoCount - 1 do
              if (TSourceEditor(AnUnitInfo.OpenEditorInfo[j].EditorComponent).SourceNotebook
                  = SourceEditorManager.ActiveSourceWindow)
              and EditorMatches(AnUnitInfo.OpenEditorInfo[j], Access) then begin
                Result := AnUnitInfo.OpenEditorInfo[j];
                break;
              end;
          end;
      end;
      inc(LockRun);
    until (LockRun > 1) or (Result <> nil);
    FUseWindowID:=False;
    FFlags:=[];
    FPageIndex:=-1;
    if (Result = nil) then
      case Access.SearchOpenNew of
        eoeaNoNewTab: ;
        eoeaNewTabInExistingWindowOnly:
          begin
            FWindowIndex := AvailSrcWindowIndex(AnUnitInfo);
            if FWindowIndex >= 0 then
              if OpenFileInSourceEditor(AnUnitInfo.GetClosedOrNewEditorInfo) = mrOk then
                Result := AnUnitInfo.OpenEditorInfo[0]; // newly opened will be last focused
          end;
        eoeaNewTabInNewWindowOnly:
          begin
            FWindowIndex := SourceEditorManager.SourceWindowCount;
            if OpenFileInSourceEditor(AnUnitInfo.GetClosedOrNewEditorInfo) = mrOk then
              Result := AnUnitInfo.OpenEditorInfo[0]; // newly opened will be last focused
          end;
        eoeaNewTabInExistingOrNewWindow:
          begin
            FWindowIndex := AvailSrcWindowIndex(AnUnitInfo);
            if FWindowIndex < 0 then
              FWindowIndex := SourceEditorManager.SourceWindowCount;
            if OpenFileInSourceEditor(AnUnitInfo.GetClosedOrNewEditorInfo) = mrOk then
              Result := AnUnitInfo.OpenEditorInfo[0]; // newly opened will be last focused
          end;
      end;
    if Result <> nil then
      break;
  end;
  if Result = nil then
    // should never happen
    Result := AnUnitInfo.OpenEditorInfo[0];
  if Result<>nil then begin
    // WantedTopLine
    if (WantedTopLine>0)
    and (Result.EditorComponent<>nil) then
      Result.EditorComponent.TopLine:=WantedTopLine;
  end;
end;

function TFileOpener.OpenResource: TModalResult;
var
  CloseFlags: TCloseFlags;
begin
  // read form data
  if FilenameIsPascalUnit(FFilename) then begin
    // this could be a unit with a form
    //debugln('TFileOpener.OpenResource ',FFilename,' ',OpenFlagsToString(Flags));
    if ([ofDoNotLoadResource]*FFlags=[])
    and ( (ofDoLoadResource in FFlags)
       or ((ofProjectLoading in FFlags)
           and FNewUnitInfo.LoadedDesigner
           and (not Project1.AutoOpenDesignerFormsDisabled)
           and EnvironmentOptions.AutoCreateFormsOnOpen))
    then begin
      // -> try to (re)load the lfm file
      //debugln(['TFileOpener.OpenResource Loading LFM for ',FNewUnitInfo.Filename,' LoadedDesigner=',FNewUnitInfo.LoadedDesigner]);
      CloseFlags:=[cfSaveDependencies];
      if ofRevert in FFlags then
        Include(CloseFlags,cfCloseDependencies);
      Result:=LoadLFM(FNewUnitInfo,FFlags,CloseFlags);
      if Result<>mrOk then begin
        DebugLn(['TFileOpener.OpenResource LoadLFM failed']);
        exit;
      end;
    end else begin
      Result:=mrOk;
    end;
  end else if FNewUnitInfo.Component<>nil then begin
    // this is no pascal source and there is a designer form
    // This can be the case, when the file is renamed and/or reverted
    // -> close form
    Result:=CloseUnitComponent(FNewUnitInfo,[cfCloseDependencies,cfSaveDependencies]);
    if Result<>mrOk then begin
      DebugLn(['TFileOpener.OpenResource CloseUnitComponent failed']);
    end;
  end else begin
    Result:=mrOk;
  end;
  if FNewUnitInfo.Component=nil then
    FNewUnitInfo.LoadedDesigner:=false;
end;

procedure TFileOpener.CheckInternalFile;
var
  NewBuf: TCodeBuffer;
begin
  if LazStartsStr(EditorMacroVirtualDrive, FFileName) then
  begin
    FUnitIndex:=Project1.IndexOfFilename(FFilename);
    if (FUnitIndex < 0) then begin
      NewBuf := CodeToolBoss.SourceCache.CreateFile(FFileName);
      if MacroListViewer.MacroByFullName(FFileName) <> nil then
        NewBuf.Source := MacroListViewer.MacroByFullName(FFileName).GetAsSource;
      FNewUnitInfo:=TUnitInfo.Create(NewBuf);
      FNewUnitInfo.DefaultSyntaxHighlighter := lshFreePascal;
      Project1.AddFile(FNewUnitInfo,false);
    end
    else begin
      FNewUnitInfo:=Project1.Units[FUnitIndex];
    end;
    FNewUnitInfo.Flags := FNewUnitInfo.Flags + [uifInternalFile];

    if FNewUnitInfo.OpenEditorInfoCount > 0 then begin
      FNewEditorInfo := FNewUnitInfo.OpenEditorInfo[0];
      SourceEditorManager.SetWindowByIDAndPage(FNewEditorInfo.WindowID, FNewEditorInfo.PageIndex);
    end
    else begin
      FNewEditorInfo := FNewUnitInfo.GetClosedOrNewEditorInfo;
      OpenFileInSourceEditor(FNewEditorInfo);
    end;
  end;
end;

function TFileOpener.CheckRevert: TModalResult;
// revert: use source editor filename
begin
  if (FPageIndex>=0) then begin
    if FUseWindowID then                       // Revert must have a valid ID
      FWindowIndex := SourceEditorManager.IndexOfSourceWindowWithID(FWindowIndex);
    FUseWindowID := False;
    Assert((FWindowIndex >= 0) and (FWindowIndex < SourceEditorManager.SourceWindowCount), 'FWindowIndex for revert');
    FFilename := SourceEditorManager.SourceEditorsByPage[FWindowIndex, FPageIndex].FileName;
  end
  else
    FFlags := FFlags - [ofRevert];    // No editor exists yet, don't try to revert.
  FUnitIndex:=Project1.IndexOfFilename(FFilename);
  if (FUnitIndex > 0) then begin
    FNewUnitInfo:=Project1.Units[FUnitIndex];
    if (uifInternalFile in FNewUnitInfo.Flags) then
    begin
      if (FNewUnitInfo.OpenEditorInfoCount > 0) then begin
        FNewEditorInfo := FNewUnitInfo.OpenEditorInfo[0];
        if MacroListViewer.MacroByFullName(FFileName) <> nil then
          FNewUnitInfo.Source.Source := MacroListViewer.MacroByFullName(FFileName).GetAsSource;
        FUseWindowID:=True;
        FPageIndex := FNewEditorInfo.PageIndex;
        FWindowIndex := FNewEditorInfo.WindowID;
        OpenFileInSourceEditor(FNewEditorInfo);
      end;
      // else unknown internal file
      exit(mrIgnore);
    end;
  end;
  exit(mrOk);
end;

function TFileOpener.PrepareRevert(DiskFilename: String): TModalResult;
var
  WInd: integer;
  ed: TSourceEditor;
begin
  FUnknownFile := False;
  if FUseWindowID then
    WInd:=SourceEditorManager.IndexOfSourceWindowWithID(FWindowIndex)
  else
    WInd:=FWindowIndex;
  ed := SourceEditorManager.SourceEditorsByPage[WInd, FPageIndex];
  FNewEditorInfo := Project1.EditorInfoWithEditorComponent(ed);
  FNewUnitInfo := FNewEditorInfo.UnitInfo;
  FUnitIndex:=Project1.IndexOf(FNewUnitInfo);
  FFilename:=FNewUnitInfo.Filename;
  if CompareFilenames(FFileName,DiskFilename)=0 then
    FFileName:=DiskFilename;
  if FNewUnitInfo.IsVirtual then begin
    if (not (ofQuiet in FFlags)) then begin
      IDEMessageDialog(lisRevertFailed, Format(lisFileIsVirtual, [FFilename]),
        mtInformation,[mbCancel]);
    end;
    exit(mrCancel);
  end;
  exit(mrOK);
end;

function TFileOpener.PrepareFile: TModalResult;
begin
  FUnitIndex:=Project1.IndexOfFilename(FFilename);
  FUnknownFile := (FUnitIndex < 0);
  FNewEditorInfo := nil;
  if not FUnknownFile then begin
    FNewUnitInfo := Project1.Units[FUnitIndex];
    if FEditorInfo <> nil then
      FNewEditorInfo := FEditorInfo
    else if (ofProjectLoading in FFlags) then
      FNewEditorInfo := FNewUnitInfo.GetClosedOrNewEditorInfo
    else
      FNewEditorInfo := FNewUnitInfo.EditorInfo[0];
  end;
  Result := mrOK;
end;

function TFileOpener.ChangeEditorPage: TModalResult;
// file already open -> change source notebook page
begin
  //DebugLn(['TFileOpener.ChangeEditorPage file already open ',FNewUnitInfo.Filename,' WindowIndex=',FNewEditorInfo.WindowID,' PageIndex=',FNewEditorInfo.PageIndex]);
  SourceEditorManager.SetWindowByIDAndPage(FNewEditorInfo.WindowID, FNewEditorInfo.PageIndex);
  if ofDoLoadResource in FFlags then
    Result:=OpenResource
  else
    Result:=mrOk;
end;

function TFileOpener.OpenKnown: TModalResult;
// project knows this file => all the meta data is known -> just load the source
var
  LoadBufferFlags: TLoadBufferFlags;
  NewBuf: TCodeBuffer;
begin
  FNewUnitInfo:=Project1.Units[FUnitIndex];
  LoadBufferFlags:=[lbfCheckIfText];
  if FilenameIsAbsolute(FFilename) then begin
    if (not (ofUseCache in FFlags)) then
      Include(LoadBufferFlags,lbfUpdateFromDisk);
    if ofRevert in FFlags then
      Include(LoadBufferFlags,lbfRevert);
  end;
  Result:=LoadCodeBuffer(NewBuf,FFileName,LoadBufferFlags,
                         [ofProjectLoading,ofMultiOpen]*FFlags<>[]);
  if Result<>mrOk then begin
    DebugLn(['TFileOpener.OpenKnownFile failed LoadCodeBuffer: ',FFilename]);
    exit;
  end;
  FNewUnitInfo.Source:=NewBuf;
  if FilenameIsPascalUnit(FNewUnitInfo.Filename) then
    FNewUnitInfo.ReadUnitNameFromSource(false);
  FNewUnitInfo.Modified:=FNewUnitInfo.Source.FileOnDiskNeedsUpdate;
end;

function TFileOpener.OpenUnknown: TModalResult;
// open unknown file, Never happens if ofRevert
begin
  Result:=OpenUnknownFile;
  if Result<>mrOk then exit;
  // the file was previously unknown, use the default EditorInfo
  if FEditorInfo <> nil then
    FNewEditorInfo := FEditorInfo
  else
  if FNewUnitInfo <> nil then
    FNewEditorInfo := FNewUnitInfo.GetClosedOrNewEditorInfo
  else
    FNewEditorInfo := nil;
end;

function TFileOpener.OpenUnknownFile: TModalResult;
var
  NewProgramName, LPIFilename, ACaption, AText: string;
  PreReadBuf: TCodeBuffer;
  LoadFlags: TLoadBufferFlags;
  SourceType: String;
begin
  if ([ofProjectLoading,ofRegularFile]*FFlags=[]) and (MainIDE.ToolStatus=itNone)
  and FilenameExtIs(FFilename,'lpi',true) then begin
    // this is a project info file -> load whole project
    Result:=MainIDE.DoOpenProjectFile(FFilename,[ofAddToRecent]);
    if Result = mrOK then
      Result := mrIgnore;
    exit;
  end;

  // load the source
  LoadFlags := [lbfCheckIfText,lbfUpdateFromDisk,lbfRevert];
  if ofQuiet in FFlags then Include(LoadFlags, lbfQuiet);
  Result:=LoadCodeBuffer(PreReadBuf,FFileName,LoadFlags,true);
  if Result<>mrOk then exit;
  FNewUnitInfo:=nil;

  // check if unit is a program
  if ([ofProjectLoading,ofRegularFile]*FFlags=[])
  and FilenameIsPascalSource(FFilename) then begin
    SourceType:=CodeToolBoss.GetSourceType(PreReadBuf,false);
    if (SysUtils.CompareText(SourceType,'PROGRAM')=0)
    or (SysUtils.CompareText(SourceType,'LIBRARY')=0)
    then begin
      NewProgramName:=CodeToolBoss.GetSourceName(PreReadBuf,false);
      if NewProgramName<>'' then begin
        // source is a program
        // either this is a lazarus project or it is not yet a lazarus project ;)
        LPIFilename:=ChangeFileExt(FFilename,'.lpi');
        if FileExistsCached(LPIFilename) then begin
          case IDEQuestionDialog(lisProjectInfoFileDetected,
            Format(lisTheFileSeemsToBeTheProgramFileOfAnExistingLazarusP,
                   [FFilename]), mtConfirmation,
              [mrOk, lisOpenProject2, mrAbort, lisOpenTheFileAsNormalSource])
          of
            mrOk:
            begin
              Result:=MainIDE.DoOpenProjectFile(LPIFilename,[ofAddToRecent]);
              if Result = mrOK then
                Result := mrIgnore;
              exit;
            end;
            mrCancel: Exit(mrCancel);
          end;
        end else begin
          AText:=Format(lisTheFileSeemsToBeAProgramCloseCurrentProject,
                        [FFilename, LineEnding, LineEnding]);
          ACaption:=lisProgramDetected;
          if IDEMessageDialog(ACaption, AText, mtConfirmation, [mbYes,mbNo])=mrYes then
          begin
            Result:=CreateProjectForProgram(PreReadBuf);
            if Result = mrOK then
              Result := mrIgnore;
            exit;
          end;
        end;
      end;
    end;
  end;
  FNewUnitInfo:=TUnitInfo.Create(PreReadBuf);
  if FilenameIsPascalSource(FNewUnitInfo.Filename) then
    FNewUnitInfo.ReadUnitNameFromSource(true);
  Project1.AddFile(FNewUnitInfo,false);
  if (ofAddToProject in FFlags) and (not FNewUnitInfo.IsPartOfProject) then
  begin
    FNewUnitInfo.IsPartOfProject:=true;
    Project1.Modified:=true;
  end;
  Result:=mrOk;
end;

function TFileOpener.OpenNotExistingFile: TModalResult;
var
  NewFlags: TNewFlags;
begin
  if ofProjectLoading in FFlags then begin
    // this is a file that was loaded last time, but was removed from disk
    Result:=IDEQuestionDialog(lisFileNotFound,
      Format(lisTheFileWasNotFoundIgnoreWillGoOnLoadingTheProject,
             [FFilename, LineEnding, LineEnding]),
      mtError, [mrIgnore, lisSkipFileAndContinueLoading,
                mrAbort, lisAbortLoadingProject]);
    exit;
  end;

  // Default to cancel
  Result:=mrCancel;
  if ofQuiet in FFlags then Exit;

  if ofOnlyIfExists in FFlags then
  begin
    IDEMessageDialog(lisFileNotFound,
      Format(lisFileNotFound2, [FFilename])+LineEnding, mtInformation,[mbCancel]);
    // cancel loading file
    Exit;
  end;

  if IDEMessageDialog(lisFileNotFound,
      Format(lisFileNotFoundDoYouWantToCreateIt,[FFilename,LineEnding]),
      mtInformation,[mbYes,mbNo])=mrYes then
  begin
    // create new file
    NewFlags:=[nfOpenInEditor,nfCreateDefaultSrc];
    if ofAddToProject in FFlags then
      Include(NewFlags,nfIsPartOfProject);
    if FilenameIsPascalSource(FFilename) then
      Result:=MainIDE.DoNewEditorFile(FileDescriptorUnit,FFilename,'',NewFlags)
    else
      Result:=MainIDE.DoNewEditorFile(FileDescriptorText,FFilename,'',NewFlags);
  end;
end;

function TFileOpener.ResolvePossibleSymlink: TModalResult;
// Check if symlink and ask user if the real file should be opened instead.
// Compiler never resolves symlinks, files in compiler search path must not be resolved.
// If there already is an editor with a "physical" target of a symlink, use it.
var
  SPath, Target: String;  // Search path and target file for the symlink.
begin
  Result := mrOK;
  if ofProjectLoading in FFlags then Exit; // Use the given name when project loads.
  Target := GetPhysicalFilenameCached(FFileName,false);
  if Target = FFilename then Exit;  // Not a symlink, continue with FFilename.
  // ToDo: Check if there is an editor with a symlink for this "physical" file.

  SPath := CodeToolBoss.GetCompleteSrcPathForDirectory('');
  // Check if symlink is found in search path or in editor.
  if (SearchDirectoryInSearchPath(SPath, ExtractFilePath(FFileName)) > 0)
  or Assigned(SourceEditorManager.SourceEditorIntfWithFilename(FFileName))
  then
    Exit;       // Symlink found -> use it.
  // Check if "physical" target for a symlink is found in search path or in editor.
  if (SearchDirectoryInSearchPath(SPath, ExtractFilePath(Target)) > 0)
  or Assigned(SourceEditorManager.SourceEditorIntfWithFilename(Target))
  then          // Target found -> use Target name.
    FFileName := Target
  else          // Not found anywhere, ask user.
    Result := ChooseSymlink(FFileName, Target);
end;

function TFileOpener.OpenEditorFile(APageIndex, AWindowIndex: integer;
  AEditorInfo: TUnitEditorInfo; AFlags: TOpenFlags): TModalResult;
var
  s, DiskFilename: String;
  Reverting: Boolean;
begin
  {$IFDEF IDE_VERBOSE}
  DebugLn('');
  DebugLn(['*** TFileOpener.OpenEditorFile START "',AFilename,'" ',OpenFlagsToString(Flags),' Window=',WindowIndex,' Page=',PageIndex]);
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TFileOpener.OpenEditorFile START');{$ENDIF}
  FPageIndex := APageIndex;
  FWindowIndex := AWindowIndex;
  FEditorInfo := AEditorInfo;
  FFlags := AFlags;

  Result:=mrCancel;

  // replace macros
  if ofConvertMacros in FFlags then begin
    if not GlobalMacroList.SubstituteStr(FFilename) then exit;
    FFilename:=ExpandFileNameUTF8(FFilename);
  end;

  if (ofRevert in FFlags) then begin
    Result := CheckRevert;
    if Result = mrIgnore then exit(mrOK);
    Assert(Result = mrOK);
  end;

  if (ofInternalFile in FFlags) then begin
    CheckInternalFile;
    // unknown internal file => ignore
    exit(mrOK);
  end;

  // normalize filename
  FFilename:=TrimFilename(FFilename);
  DiskFilename:=CodeToolBoss.DirectoryCachePool.FindDiskFilename(FFilename);
  if DiskFilename<>FFilename then begin
    // the case is different
    DebugLn(['TFileOpener.OpenEditorFile Fixing file name: ',FFilename,' -> ',DiskFilename]);
    FFilename:=DiskFilename;
  end;
  if not (ofRegularFile in FFlags) then begin
    DiskFilename:=GetShellLinkTarget(FFileName);
    if DiskFilename<>FFilename then begin
      // not regular file
      DebugLn(['TFileOpener.OpenEditorFile Fixing file name: ',FFilename,' -> ',DiskFilename]);
      FFilename:=DiskFilename;
    end;
  end;

  if FilenameIsAbsolute(FFileName) then begin
    Result := ResolvePossibleSymlink;
    if Result <> mrOK then exit;
  end;

  // check to not open directories
  s:=ExtractFilename(FFilename);
  if (s='') or (s='.') or (s='..') then
  begin
    DebugLn(['TFileOpener.OpenEditorFile ignoring special file: ',FFilename]);
    exit;
  end;
  if DirectoryExistsUTF8(FFileName) then begin
    debugln(['TFileOpener.OpenEditorFile skipping directory ',FFileName]);
    exit(mrCancel);
  end;

  if ([ofAddToRecent,ofRevert,ofVirtualFile]*FFlags=[ofAddToRecent])
  and (FFilename<>'') and FilenameIsAbsolute(FFilename) then
    EnvironmentOptions.AddToRecentOpenFiles(FFilename);

  // check if this is a hidden unit:
  // if this is the main unit, it is already
  // loaded and needs only to be shown in the sourceeditor/formeditor
  if (not (ofRevert in FFlags)) and (CompareFilenames(Project1.MainFilename,FFilename)=0)
  then begin
    Result:=OpenMainUnit;
    exit;
  end;

  // check for special files
  if ([ofRegularFile,ofRevert,ofProjectLoading]*FFlags=[])
  and FilenameIsAbsolute(FFilename) and FileExistsCached(FFilename) then begin
    // check if file is a lazarus project (.lpi)
    if FilenameExtIs(FFilename,'lpi',true) then
    begin
      case
        IDEQuestionDialog(lisOpenProject, Format(lisOpenTheProject, [FFilename]),
            mtConfirmation, [mrYes, lisOpenProject2,
                             mrNoToAll, lisOpenAsXmlFile,
                             mrCancel])
      of
        mrYes: begin
          Result:=MainIDE.DoOpenProjectFile(FFilename,[ofAddToRecent]);
          exit;
        end;
        mrNoToAll: include(FFlags, ofRegularFile);
        mrCancel: exit(mrCancel);
      end;
    end;

    // check if file is a lazarus package (.lpk)
    if FilenameExtIs(FFilename,'lpk',true) then
    begin
      case
        IDEQuestionDialog(lisOpenPackage,
            Format(lisOpenThePackage, [FFilename]),
            mtConfirmation, [mrYes, lisCompPalOpenPackage,
                             mrNoToAll, lisOpenAsXmlFile,
                             mrCancel])
      of
        mrYes: begin
          Result:=PkgBoss.DoOpenPackageFile(FFilename,[pofAddToRecent],
                                       [ofProjectLoading,ofMultiOpen]*FFlags<>[]);
          exit;
        end;
        mrCancel: exit(mrCancel);
      end;
    end;
  end;

  // check if the project knows this file
  if (ofRevert in FFlags) then begin
    Result := PrepareRevert(DiskFilename);
    if Result <> mrOK then exit;
  end else begin
    Result := PrepareFile;
    if Result <> mrOK then exit;
  end;

  if (FNewEditorInfo <> nil) and (ofAddToProject in FFlags) and (not FNewUnitInfo.IsPartOfProject) then
  begin
    FNewUnitInfo.IsPartOfProject:=true;
    Project1.Modified:=true;
  end;

  if (FNewEditorInfo <> nil) and (FFlags * [ofProjectLoading, ofRevert] = [])
  and (FNewEditorInfo.EditorComponent <> nil) then
    exit(ChangeEditorPage);

  Reverting:=ofRevert in FFlags;
  if Reverting then
    Project1.BeginRevertUnit(FNewUnitInfo);
  try

    // check if file exists
    if FilenameIsAbsolute(FFilename) and (not FileExistsCached(FFilename)) then
    begin
      // file does not exist
      if (ofRevert in FFlags) then begin
        // PrepareRevert failed, due to missing file
        if not (ofQuiet in FFlags) then begin
          IDEMessageDialog(lisRevertFailed, Format(lisPkgMangFileNotFound, [FFilename]),
            mtError,[mbCancel]);
        end;
        Result:=mrCancel;
        exit;
      end else begin
        Result:=OpenNotExistingFile;
        exit;
      end;
    end;

    // load the source
    if FUnknownFile then
      Result := OpenUnknown
    else
      Result := OpenKnown;
    if Result=mrIgnore then exit(mrOK);
    if Result<>mrOk then exit;

    // check readonly
    FNewUnitInfo.FileReadOnly:=FileExistsCached(FNewUnitInfo.Filename)
                              and (not FileIsWritable(FNewUnitInfo.Filename));
    //debugln('[TFileOpener.OpenEditorFile] B');
    // open file in source notebook
    Result:=OpenFileInSourceEditor(FNewEditorInfo);
    if Result<>mrOk then begin
      DebugLn(['TFileOpener.OpenEditorFile failed OpenFileInSourceEditor: ',FFilename]);
      exit;
    end;
    // open resource component (designer, form, datamodule, ...)
    if FNewUnitInfo.OpenEditorInfoCount = 1 then
      Result:=OpenResource;
    if Result<>mrOk then begin
      DebugLn(['TFileOpener.OpenEditorFile failed OpenResource: ',FFilename]);
      exit;
    end;
  finally
    if Reverting then
      Project1.EndRevertUnit(FNewUnitInfo);
  end;

  Result:=mrOk;
  //debugln('TFileOpener.OpenEditorFile END "',FFilename,'"');
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('TFileOpener.OpenEditorFile END');{$ENDIF}
end;

function TFileOpener.FindFile(SearchPath: String): Boolean;
//  Searches for FileName in SearchPath
//  If FileName is not found, we'll check extensions pp and pas too
//  Returns true if found. FFileName contains the full file+path in that case
var TempFile,TempPath,CurPath: String;
    p,c: Integer;
    PasExt: TPascalExtType;

  function SetFileIfExists(const Ext: String): Boolean;
  var
    FinalFile: String;
  begin
    FinalFile:=ExpandFileNameUTF8(CurPath+TempFile+Ext);
    Result:=FileExistsCached(FinalFile);
    if Result then
      FFileName:=FinalFile;
  end;

begin
  if SearchPath='' then SearchPath:='.';
  Result:=true;
  TempPath:=SearchPath;
  while TempPath<>'' do begin
    p:=pos(';',TempPath);
    if p=0 then p:=length(TempPath)+1;
    CurPath:=copy(TempPath,1,p-1);
    Delete(TempPath,1,p);
    if CurPath='' then continue;
    CurPath:=AppendPathDelim(CurPath);
    if not FilenameIsAbsolute(CurPath) then begin
      if FActiveUnitInfo.IsVirtual then
        CurPath:=AppendPathDelim(Project1.Directory)+CurPath
      else
        CurPath:=AppendPathDelim(ExtractFilePath(FActiveUnitInfo.Filename))+CurPath;
    end;
    for c:=0 to 2 do begin
      TempFile:='';
      // FPC searches first lowercase, then keeping case, then uppercase
      case c of
        0: TempFile:=LowerCase(FFileName);
        1: TempFile:=FFileName;
        2: TempFile:=UpperCase(FFileName);
      end;
      if ExtractFileExt(TempFile)='' then begin
        for PasExt:=Low(TPascalExtType) to High(TPascalExtType) do
          if SetFileIfExists(PascalExtension[PasExt]) then exit;
      end
      else
        if SetFileIfExists('') then exit;
    end;
  end;
  Result:=false;
end;

function TFileOpener.CheckIfIncludeDirectiveInFront(const Line: string;
  X: integer): boolean;
var
  DirectiveEnd, DirectiveStart: integer;
  Directive: string;
begin
  Result:=false;
  DirectiveEnd:=X;
  while (DirectiveEnd>1) and (Line[DirectiveEnd-1] in [' ',#9]) do
    dec(DirectiveEnd);
  DirectiveStart:=DirectiveEnd-1;
  while (DirectiveStart>0) and (Line[DirectiveStart]<>'$') do
    dec(DirectiveStart);
  Directive:=uppercase(copy(Line,DirectiveStart,DirectiveEnd-DirectiveStart));
  if (Directive='$INCLUDE') or (Directive='$I') then begin
    if ((DirectiveStart>1) and (Line[DirectiveStart-1]='{'))
    or ((DirectiveStart>2)
      and (Line[DirectiveStart-2]='(') and (Line[DirectiveStart-1]='*'))
    then begin
      Result:=true;
    end;
  end;
end;

function TFileOpener.GetFilenameAtRowCol(XY: TPoint): string;
var
  Line: string;
  Len, Stop: integer;
  StopChars: set of char;
begin
  Result := '';
  FIsIncludeDirective:=false;
  if (XY.Y >= 1) and (XY.Y <= FActiveSrcEdit.EditorComponent.Lines.Count) then
  begin
    Line := FActiveSrcEdit.EditorComponent.Lines.Strings[XY.Y - 1];
    Len := Length(Line);
    if (XY.X >= 1) and (XY.X <= Len + 1) then begin
      StopChars := [',',';',':','[',']','{','}','(',')','''','"','`'
                   ,'#','%','=','>'];
      Stop := XY.X;
      if Stop>Len then Stop:=Len;
      while (Stop >= 1) and (not (Line[Stop] in ['''','"','`'])) do
        dec(Stop);
      if Stop<1 then
        StopChars:=StopChars+[' ',#9]; // no quotes in front => use spaces as boundaries
      Stop := XY.X;
      while (Stop <= Len) and (not (Line[Stop] in StopChars)) do
        Inc(Stop);
      while (XY.X > 1) and (not (Line[XY.X - 1] in StopChars)) do
        Dec(XY.X);
      if Stop > XY.X then begin
        Result := Copy(Line, XY.X, Stop - XY.X);
        FIsIncludeDirective:=CheckIfIncludeDirectiveInFront(Line,XY.X);
      end;
    end;
  end;
end;

function TFileOpener.OpenFileAtCursor: TModalResult;

  function ShowNotFound(aFilename: string): TModalResult;
  begin
    Result:=mrCancel;
    if aFilename<>'' then
      IDEMessageDialog(lisOpenFileAtCursor, lisFileNotFound+':'#13+aFileName,
        mtError, [mbOk]);
  end;

var
  Found: Boolean;
  BaseDir: String;
  NewFilename,InFilename: string;
  AUnitName: String;
  SearchPath, Line: String;
  Edit: TIDESynEditor;
  FoundType: TFindFileAtCursorFlag;
  XY: TPoint;
  Len: Integer;
begin
  Result:=mrCancel;

  {$IFDEF VerboseFindFileAtCursor}
  debugln(['TFileOpener.OpenFileAtCursor ',FActiveUnitInfo<>nil]);
  {$ENDIF}
  if (FActiveSrcEdit=nil) or (FActiveUnitInfo=nil) then exit;
  BaseDir:=ExtractFilePath(FActiveUnitInfo.Filename);
  {$IFDEF VerboseFindFileAtCursor}
  debugln(['TFileOpener.OpenFileAtCursor File="',FActiveUnitInfo.Filename,'"']);
  {$ENDIF}

  Found:=false;

  // check if a filename is selected
  Edit:=FActiveSrcEdit.EditorComponent;
  if Edit.SelAvail and (Edit.BlockBegin.Y=Edit.BlockBegin.X) then begin
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFileOpener.OpenFileAtCursor Edit.SelAvail Edit.SelText="',Edit.SelText,'"']);
    {$ENDIF}
    FFileName:=ResolveDots(Edit.SelText);
    if not FilenameIsAbsolute(FFileName) then
      FFileName:=ResolveDots(BaseDir+FFileName);
    if FilenameIsAbsolute(FFileName) then begin
      if FileExistsCached(FFileName) then
        Found:=true
      else
        exit(ShowNotFound(FFileName));
    end;
  end;


  XY:=Edit.LogicalCaretXY;
  if (XY.Y >= 1) and (XY.Y <= FActiveSrcEdit.EditorComponent.Lines.Count) then
  begin
    Line := FActiveSrcEdit.EditorComponent.Lines.Strings[XY.Y - 1];
    Len := Length(Line);
    if (XY.X>1) and (XY.X-1<=Len) and IsWordChar[Line[XY.X-1]]
    and ((XY.X>Len) or IsNonWordChar[Line[XY.X]]) then
      dec(XY.X);
  end;


  // in a Pascal file use codetools
  if FilenameIsPascalSource(FActiveUnitInfo.Filename) then begin
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFileOpener.OpenFileAtCursor FilenameIsPascalSource -> using codetools']);
    {$ENDIF}
    if MainIDE.BeginCodeTool(FActiveSrcEdit,FActiveUnitInfo,[]) then begin
      if CodeToolBoss.FindFileAtCursor(FActiveSrcEdit.CodeBuffer,
        XY.X,XY.Y,FoundType,FFileName) then
        Found:=true
      else begin
        FFileName:=FActiveSrcEdit.EditorComponent.GetWordAtRowCol(
          FActiveSrcEdit.EditorComponent.LogicalCaretXY);
        exit(ShowNotFound(FFileName));
      end;
    end;
  end;

  if not Found then begin
    // parse FFileName at cursor
    FFileName:=GetFilenameAtRowCol(FActiveSrcEdit.EditorComponent.LogicalCaretXY);
    if FFileName='' then exit;
    // check if absolute FFileName
    if FilenameIsAbsolute(FFileName) then begin
      if FileExistsCached(FFileName) then
        Found:=true
      else
        exit(ShowNotFound(FFileName));
    end;

    if FIsIncludeDirective then
    begin
      if (not Found) then begin
        // search include file
        SearchPath:='.;'+CodeToolBoss.DefineTree.GetIncludePathForDirectory(BaseDir);
        if FindFile(SearchPath) then // sets FFileName if result=true
          Found:=true;
      end;
    end else
    begin
      if (not Found) then
      begin
        // search pascal unit without extension
        AUnitName:=FFileName;
        InFilename:='';
        NewFilename:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                             BaseDir,AUnitName,InFilename,true);
        if NewFilename<>'' then begin
          Found:=true;
          FFileName:=NewFilename;
        end;
      end;

      if (not Found) and (ExtractFileExt(FFileName)<>'') then
      begin
        // search pascal unit with extension
        AUnitName:=ExtractFileNameOnly(FFileName);
        InFilename:=FFileName;
        NewFilename:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                             BaseDir,AUnitName,InFilename,true);
        if NewFilename<>'' then begin
          Found:=true;
          FFileName:=NewFilename;
        end;
      end;
    end;
  end;

  if (not Found) then begin
    // simple search relative to current unit
    InFilename:=AppendPathDelim(BaseDir)+FFileName;
    if FileExistsCached(InFilename) then begin
      Found:=true;
      FFileName:=InFilename;
    end;
  end;

  if (not Found) and (System.Pos('.',FFileName)>0) and (not FIsIncludeDirective) then
  begin
    // for example 'SysUtils.CompareText'
    FFileName:=FActiveSrcEdit.EditorComponent.GetWordAtRowCol(
      FActiveSrcEdit.EditorComponent.LogicalCaretXY);
    if IsValidIdent(FFileName) then begin
      // search pascal unit
      AUnitName:=FFileName;
      InFilename:='';
      NewFilename:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                           BaseDir,AUnitName,InFilename,true);
      if NewFilename<>'' then begin
        Found:=true;
        FFileName:=NewFilename;
      end;
    end;
  end;

  if Found then begin
    // open, FFileName is set earlier.
    InputHistories.SetFileDialogSettingsInitialDir(ExtractFilePath(FFileName));
    FUseWindowID:=False;
    Result:=OpenEditorFile(-1, -1, nil, [ofAddToRecent]);
  end else
    exit(ShowNotFound(FFileName));
end;

function TFileOpener.OpenMainUnit: TModalResult;
var
  MainUnitInfo: TUnitInfo;
begin
  {$IFDEF IDE_VERBOSE}
  debugln(['[TFileOpener.OpenMainUnit] A ProjectLoading=',ofProjectLoading in Flags,' MainUnitID=',Project1.MainUnitID]);
  {$ENDIF}
  Result:=mrCancel;
  if (Project1=nil) or (Project1.MainUnitID<0) then exit;
  MainUnitInfo:=Project1.MainUnitInfo;

  // check if main unit is already open in source editor
  if (MainUnitInfo.OpenEditorInfoCount > 0) and (not (ofProjectLoading in FFlags)) then
  begin
    // already loaded -> switch to source editor
    SourceEditorManager.ActiveEditor := TSourceEditor(MainUnitInfo.OpenEditorInfo[0].EditorComponent);
    SourceEditorManager.ShowActiveWindowOnTop(True);
    Result:=mrOk;
    exit;
  end;

  // open file in source notebook
  Result:=OpenFileInSourceEditor(MainUnitInfo.GetClosedOrNewEditorInfo);
  if Result<>mrOk then exit;

  Result:=mrOk;
  {$IFDEF IDE_VERBOSE}
  debugln('[TFileOpener.OpenMainUnit] END');
  {$ENDIF}
end;

function TFileOpener.RevertMainUnit: TModalResult;
begin
  Result:=mrOk;
  if Project1.MainUnitID<0 then exit;
  FFileName:='';
  FUseWindowID:=True;
  if Project1.MainUnitInfo.OpenEditorInfoCount > 0 then
    // main unit is loaded, so we can just revert
    Result:=OpenEditorFile(Project1.MainUnitInfo.EditorInfo[0].PageIndex,
                           Project1.MainUnitInfo.EditorInfo[0].WindowID, nil, [ofRevert])
  else begin
    // main unit is only loaded in background
    // -> just reload the source and update the source name
    Result:=Project1.MainUnitInfo.ReadUnitSource(true,true);
  end;
end;

function CheckMainSrcLCLInterfaces(Silent: boolean): TModalResult;
var
  MainUnitInfo: TUnitInfo;
  MainUsesSection,ImplementationUsesSection: TStrings;
  MsgResult: TModalResult;
begin
  Result:=mrOk;
  if (Project1=nil) then exit;
  if Project1.SkipCheckLCLInterfaces then exit;
  MainUnitInfo:=Project1.MainUnitInfo;
  if (MainUnitInfo=nil) or (MainUnitInfo.Source=nil) then exit;
  if PackageGraph.FindDependencyRecursively(Project1.FirstRequiredDependency,
    PackageGraph.LCLBasePackage)=nil
  then
    exit; // project does not use LCLBase
  // project uses LCLBase
  MainUsesSection:=nil;
  ImplementationUsesSection:=nil;
  try
    if not CodeToolBoss.FindUsedUnitNames(MainUnitInfo.Source,
      MainUsesSection,ImplementationUsesSection) then exit;
    if (SearchInStringListI(MainUsesSection,'forms')<0)
    and (SearchInStringListI(ImplementationUsesSection,'forms')<0) then
      exit;
    // project uses lcl unit Forms
    if (SearchInStringListI(MainUsesSection,'interfaces')>=0)
    or (SearchInStringListI(ImplementationUsesSection,'interfaces')>=0) then
      exit;
    // project uses lcl unit Forms, but not unit interfaces
    // this will result in strange linker error
    if not Silent then
    begin
      MsgResult:=IDEQuestionDialog(lisCCOWarningCaption,
        Format(lisTheProjectDoesNotUseTheLCLUnitInterfacesButItSeems, [LineEnding]),
        mtWarning, [mrYes, lisAddUnitInterfaces,
                    mrNo, lisIgnore,
                    mrNoToAll, lisAlwaysIgnore,
                    mrCancel]);
      case MsgResult of
        mrNo: exit;
        mrNoToAll: begin Project1.SkipCheckLCLInterfaces:=true; exit; end;
        mrCancel: exit(mrCancel);
      end;
    end;
    CodeToolBoss.AddUnitToMainUsesSection(MainUnitInfo.Source,'Interfaces','');
  finally
    MainUsesSection.Free;
    ImplementationUsesSection.Free;
  end;
end;

procedure AddRecentProjectFile(const AFilename: string);
begin
  EnvironmentOptions.AddToRecentProjectFiles(AFilename);
  MainIDE.SetRecentProjectFilesMenu;
  MainIDE.SaveEnvironment;
end;

procedure RemoveRecentProjectFile(const AFilename: string);
begin
  EnvironmentOptions.RemoveFromRecentProjectFiles(AFilename);
  MainIDE.SetRecentProjectFilesMenu;
  MainIDE.SaveEnvironment;
end;

function AddActiveUnitToProject: TModalResult;
begin
  Result := AddUnitToProject(nil);
end;

function AddUnitToProject(const AEditor: TSourceEditorInterface): TModalResult;
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  s, ShortUnitName: string;
  OkToAdd, IsPascal: boolean;
  Owners: TFPList;
  i: Integer;
  APackage: TLazPackage;
  MsgResult: TModalResult;
begin
  Result:=mrCancel;
  if AEditor<>nil then
  begin
    ActiveSourceEditor := AEditor as TSourceEditor;
    if not MainIDE.BeginCodeTool(ActiveSourceEditor,ActiveUnitInfo,[ctfUseGivenSourceEditor]) then exit;
  end else
  begin
    ActiveSourceEditor:=nil;
    if not MainIDE.BeginCodeTool(ActiveSourceEditor,ActiveUnitInfo,[]) then exit;
  end;
  if (ActiveUnitInfo=nil) then exit;
  if ActiveUnitInfo.IsPartOfProject then begin
    if not ActiveUnitInfo.IsVirtual then
      s:=Format(lisTheFile, [ActiveUnitInfo.Filename])
    else
      s:=Format(lisTheFile, [ActiveSourceEditor.PageName]);
    s:=Format(lisisAlreadyPartOfTheProject, [s]);
    IDEMessageDialog(lisInformation, s, mtInformation, [mbOk]);
    exit;
  end;
  if not ActiveUnitInfo.IsVirtual then
    s:='"'+ActiveUnitInfo.Filename+'"'
  else
    s:='"'+ActiveSourceEditor.PageName+'"';
  if (ActiveUnitInfo.Unit_Name<>'')
  and (Project1.IndexOfUnitWithName(ActiveUnitInfo.Unit_Name,true,ActiveUnitInfo)>=0) then
  begin
    IDEMessageDialog(lisInformation, Format(
      lisUnableToAddToProjectBecauseThereIsAlreadyAUnitWith, [s]),
      mtInformation, [mbOk]);
    exit;
  end;

  Owners:=PkgBoss.GetPossibleOwnersOfUnit(ActiveUnitInfo.Filename,[]);
  try
    if (Owners<>nil) then begin
      for i:=0 to Owners.Count-1 do begin
        if TObject(Owners[i]) is TLazPackage then begin
          APackage:=TLazPackage(Owners[i]);
          MsgResult:=IDEQuestionDialog(lisAddPackageRequirement,
            Format(lisTheUnitBelongsToPackage, [APackage.IDAsString]),
            mtConfirmation, [mrYes, lisAddPackageToProject2,
                             mrIgnore, lisAddUnitNotRecommended,
                             mrCancel],'');
          case MsgResult of
            mrYes:
              begin
                PkgBoss.AddProjectDependency(Project1,APackage);
                exit;
              end;
            mrIgnore: ;
          else
            exit;
          end;
        end;
      end;
    end;
  finally
    Owners.Free;
  end;

  IsPascal:=FilenameIsPascalUnit(ActiveUnitInfo.Filename);
  if IsPascal and (EnvironmentOptions.CharcaseFileAction<>ccfaIgnore) then
  begin
    // ask user to apply naming conventions
    Result:=RenameUnitLowerCase(ActiveUnitInfo,true);
    if Result=mrIgnore then Result:=mrOk;
    if Result<>mrOk then begin
      DebugLn('AddUnitToProject A RenameUnitLowerCase failed ',ActiveUnitInfo.Filename);
      exit;
    end;
  end;

  if IDEMessageDialog(lisConfirmation, Format(lisAddToProject, [s]),
    mtConfirmation, [mbYes, mbCancel]) in [mrOk, mrYes]
  then begin
    OkToAdd:=True;
    if IsPascal then
      OkToAdd:=CheckDirIsInSearchPath(ActiveUnitInfo,False)
    else if FilenameExtIs(ActiveUnitInfo.Filename,'inc') then
      OkToAdd:=CheckDirIsInSearchPath(ActiveUnitInfo,True);
    if OkToAdd then begin
      ActiveUnitInfo.IsPartOfProject:=true;
      Project1.Modified:=true;
      if IsPascal and (pfMainUnitHasUsesSectionForAllUnits in Project1.Flags) then
      begin
        ActiveUnitInfo.ReadUnitNameFromSource(false);
        ShortUnitName:=ActiveUnitInfo.CreateUnitName;
        if (ShortUnitName<>'') then begin
          if CodeToolBoss.AddUnitToMainUsesSection(Project1.MainUnitInfo.Source,ShortUnitName,'')
          then
            Project1.MainUnitInfo.Modified:=true;
        end;
      end;
    end;
  end;

  if Project1.AutoCreateForms and IsPascal
  and (pfMainUnitHasCreateFormStatements in Project1.Flags) then
    UpdateUnitInfoResourceBaseClass(ActiveUnitInfo,true);
end;

procedure UpdateSourceNames;
var
  i: integer;
  AnUnitInfo: TUnitInfo;
  SourceName, PageName: string;
  AEditor: TSourceEditor;
begin
  for i:=0 to SourceEditorManager.SourceEditorCount-1 do begin
    AEditor := SourceEditorManager.SourceEditors[i];
    AnUnitInfo := Project1.UnitWithEditorComponent(AEditor);
    if AnUnitInfo=nil then continue;
    if FilenameIsPascalUnit(AnUnitInfo.Filename) then begin
      SourceName:=CodeToolBoss.GetCachedSourceName(AnUnitInfo.Source);
      if SourceName<>'' then
        AnUnitInfo.ReadUnitNameFromSource(true);
    end else
      SourceName:='';
    PageName:=CreateSrcEditPageName(SourceName, AnUnitInfo.Filename, AEditor);
    AEditor.PageName := PageName;
  end;
end;

function CheckEditorNeedsSave(AEditor: TSourceEditorInterface;
  IgnoreSharedEdits: Boolean): Boolean;
var
  AnEditorInfo: TUnitEditorInfo;
  AnUnitInfo: TUnitInfo;
begin
  Result := False;
  if AEditor = nil then exit;
  AnEditorInfo := Project1.EditorInfoWithEditorComponent(AEditor);
  if AnEditorInfo = nil then exit;

  AnUnitInfo := AnEditorInfo.UnitInfo;
  if (AnUnitInfo.OpenEditorInfoCount > 1) and IgnoreSharedEdits then
    exit;

  // save some meta data of the source
  SaveSrcEditorProjectSpecificSettings(AnEditorInfo);

  Result := (AEditor.Modified) or (AnUnitInfo.Modified);
end;

procedure ArrangeSourceEditorAndMessageView(PutOnTop: boolean);
begin
  if SourceEditorManager.SourceWindowCount > 0 then
  begin
    if PutOnTop then
    begin
      IDEWindowCreators.ShowForm(MessagesView,true);
      SourceEditorManager.ShowActiveWindowOnTop(False);
      exit;
    end;
  end;
  MainIDE.DoShowMessagesView(PutOnTop);
end;

function SomethingOfProjectIsModified(Verbose: boolean): boolean;
begin
  Result:=(Project1<>nil)
      and (Project1.SomethingModified(true,true,Verbose)
           or SourceEditorManager.SomethingModified(Verbose));
end;

function FileExistsInIDE(const Filename: string;
  SearchFlags: TProjectFileSearchFlags): boolean;
begin
  Result:=FileExistsCached(Filename)
    or ((Project1<>nil) and (Project1.UnitInfoWithFilename(Filename,SearchFlags)<>nil));
end;

function BeautifySrc(const s: string): string;
begin
  Result:=CodeToolBoss.SourceChangeCache.BeautifyCodeOptions.BeautifyStatement(s,0);
end;

function NewFile(NewFileDescriptor: TProjectFileDescriptor;
  var NewFilename: string; NewSource: string;
  NewFlags: TNewFlags; NewOwner: TObject): TModalResult;
var
  NewUnitInfo: TUnitInfo;
  NewSrcEdit: TSourceEditor;
  NewUnitName: string;
  NewBuffer: TCodeBuffer;
  OldUnitIndex: Integer;
  AncestorType: TPersistentClass;
  LFMFilename: String;
  SearchFlags: TProjectFileSearchFlags;
  LFMSourceText: String;
  LFMCode: TCodeBuffer;
  AProject: TProject;
  LRSFilename: String;
  ResType: TResourceType;
  SrcNoteBook: TSourceNotebook;
  AShareEditor: TSourceEditor;
  DisableAutoSize: Boolean;
  APackage: TLazPackage;
  IsPartOfProject: Boolean;
  RequiredPackages: String;
  Src: String;
  i: Integer;
  LFindDesignerBaseClassByName: Boolean = True;
  PreventAutoSize: Boolean;  
begin
  //debugln('NewFile A NewFilename=',NewFilename);
  // empty NewFilename is ok, it will be auto generated
  SaveEditorChangesToCodeCache(nil);

  // convert macros in filename
  if nfConvertMacros in NewFlags then begin
    if not GlobalMacroList.SubstituteStr(NewFilename) then begin
      Result:=mrCancel;
      exit;
    end;
  end;

  Result:=NewFileDescriptor.Init(NewFilename,NewOwner,NewSource,nfQuiet in NewFlags);
  if Result<>mrOk then exit;

  if FilenameIsAbsolute(NewFilename) and DirectoryExistsUTF8(NewFilename) then
  begin
    IDEMessageDialog(lisFileIsDirectory,
      lisUnableToCreateNewFileBecauseThereIsAlreadyADirecto,
      mtError,[mbCancel]);
    exit(mrCancel);
  end;

  if NewOwner is TProject then
    AProject:=TProject(NewOwner)
  else
    AProject:=Project1;
  if NewOwner is TLazPackage then
    APackage:=TLazPackage(NewOwner)
  else
    APackage:=nil;

  OldUnitIndex:=AProject.IndexOfFilename(NewFilename);
  if OldUnitIndex>=0 then begin
    // the file is not really new
    // => close form
    Result:=CloseUnitComponent(AProject.Units[OldUnitIndex],
                               [cfCloseDependencies,cfSaveDependencies]);
    if Result<>mrOk then
    begin
      debugln(['NewFile CloseUnitComponent failed']);
      exit;
    end;
  end;

  IsPartOfProject:=(nfIsPartOfProject in NewFlags)
                   or (NewOwner is TProject)
                   or (AProject.FileIsInProjectDir(NewFilename)
                       and (not (nfIsNotPartOfProject in NewFlags)));

  // add required packages
  //debugln(['NewFile NewFileDescriptor.RequiredPackages="',NewFileDescriptor.RequiredPackages,'" ',DbgSName(NewFileDescriptor)]);
  RequiredPackages:=NewFileDescriptor.RequiredPackages;
  if (RequiredPackages='') and (NewFileDescriptor.ResourceClass<>nil) then
  begin
    if (NewFileDescriptor.ResourceClass.InheritsFrom(TForm))
    or (NewFileDescriptor.ResourceClass.InheritsFrom(TFrame)) then
      RequiredPackages:='LCL';
  end;
  if RequiredPackages<>'' then
  begin
    if IsPartOfProject then begin
      Result:=PkgBoss.AddProjectDependencies(Project1,RequiredPackages);
      if Result<>mrOk then
      begin
        debugln(['NewFile PkgBoss.AddProjectDependencies failed RequiredPackages="',RequiredPackages,'"']);
        exit;
      end;
    end;
    if APackage<>nil then
    begin
      Result:=PkgBoss.AddPackageDependency(APackage,RequiredPackages);
      if Result<>mrOk then
      begin
        debugln(['NewFile PkgBoss.AddPackageDependency failed RequiredPackages="',RequiredPackages,'"']);
        exit;
      end;
    end;
  end;

  // check if the new file fits
  Result:=NewFileDescriptor.CheckOwner(nfQuiet in NewFlags);
  if Result<>mrOk then
  begin
    debugln(['NewFile NewFileDescriptor.CheckOwner failed NewFilename="',NewFilename,'"']);
    exit;
  end;

  // create new codebuffer and apply naming conventions
  NewBuffer:=nil;
  NewUnitName:='';
  Result:=CreateNewCodeBuffer(NewFileDescriptor,NewOwner,NewFilename,NewBuffer,NewUnitName);
  if Result<>mrOk then
  begin
    debugln(['NewFile CreateNewCodeBuffer failed NewFilename="',NewFilename,'"']);
    exit;
  end;
  NewFilename:=NewBuffer.Filename;

  if OldUnitIndex>=0 then begin
    // the file is not really new
    NewUnitInfo:=AProject.Units[OldUnitIndex];
    // assign source
    NewUnitInfo.Source:=NewBuffer;
  end else
    NewUnitInfo:=TUnitInfo.Create(NewBuffer);
  //debugln(['NewFile ',NewUnitInfo.Filename,' ',NewFilename]);
  if (CompareText(NewUnitInfo.Unit_Name,NewUnitName)=0) then
    NewUnitInfo.Unit_Name:=NewUnitName;
  NewUnitInfo.BuildFileIfActive:=NewFileDescriptor.BuildFileIfActive;
  NewUnitInfo.RunFileIfActive:=NewFileDescriptor.RunFileIfActive;

  // create source code
  //debugln('NewFile A nfCreateDefaultSrc=',nfCreateDefaultSrc in NewFlags,' ResourceClass=',dbgs(NewFileDescriptor.ResourceClass));
  if nfCreateDefaultSrc in NewFlags then begin
    if (NewFileDescriptor.ResourceClass<>nil) then begin
      NewUnitInfo.ComponentName:=NewUniqueComponentName(NewFileDescriptor.DefaultResourceName);
      NewUnitInfo.ComponentResourceName:='';
    end;
    Src:=NewFileDescriptor.CreateSource(NewUnitInfo.Filename,NewUnitName,NewUnitInfo.ComponentName);
    Src:=SourceEditorManager.Beautify(Src,[sembfNotBreakDots]);
    //debugln(['NewFile ',dbgtext(Src)]);
    Src:=CodeToolBoss.SourceChangeCache.BeautifyCodeOptions.BeautifyStatement(Src,0);
    NewUnitInfo.Source.Source:=Src;
  end else begin
    if nfBeautifySrc in NewFlags then
      NewBuffer.Source:=BeautifySrc(NewSource)
    else
      NewBuffer.Source:=NewSource;
  end;
  NewUnitInfo.Modified:=true;

  // add to project
  NewUnitInfo.Loaded:=true;
  NewUnitInfo.IsPartOfProject:=IsPartOfProject;
  if OldUnitIndex<0 then begin
    AProject.AddFile(NewUnitInfo,
                     NewFileDescriptor.AddToProject
                     and NewFileDescriptor.IsPascalUnit
                     and NewUnitInfo.IsPartOfProject
                     and (pfMainUnitHasUsesSectionForAllUnits in AProject.Flags));
  end;
  NewSrcEdit := Nil;
  if nfOpenInEditor in NewFlags then begin
    // open a new sourceeditor
    SrcNoteBook := SourceEditorManager.ActiveOrNewSourceWindow;
    AShareEditor := nil;
    if NewUnitInfo.OpenEditorInfoCount > 0 then
      AShareEditor := TSourceEditor(NewUnitInfo.OpenEditorInfo[0].EditorComponent);
    NewSrcEdit := SrcNoteBook.NewFile(
      CreateSrcEditPageName(NewUnitInfo.Unit_Name, NewUnitInfo.Filename, AShareEditor),
      NewUnitInfo.Source, True, AShareEditor);
    MainIDEBar.itmFileClose.Enabled:=True;
    MainIDEBar.itmFileCloseAll.Enabled:=True;
    NewSrcEdit.SyntaxHighlighterType:=NewUnitInfo.EditorInfo[0].SyntaxHighlighter;
    NewUnitInfo.GetClosedOrNewEditorInfo.EditorComponent := NewSrcEdit;
    NewSrcEdit.EditorComponent.CaretXY := Point(1,1);

    // create component
    AncestorType:=NewFileDescriptor.ResourceClass;
    if AncestorType <> nil then
    begin
      // loop for Inherited Items
      for i:=0 to BaseFormEditor1.StandardDesignerBaseClassesCount - 1 do
        if AncestorType.InheritsFrom(BaseFormEditor1.StandardDesignerBaseClasses[i]) then
        begin
          LFindDesignerBaseClassByName := False;
          Break;
        end;
      if LFindDesignerBaseClassByName then
        AncestorType:=FormEditor1.FindDesignerBaseClassByName(AncestorType.ClassName, True);
    end;
    //DebugLn(['NewFile AncestorType=',dbgsName(AncestorType),' ComponentName',NewUnitInfo.ComponentName]);
    if AncestorType<>nil then begin
      ResType:=MainBuildBoss.GetResourceType(NewUnitInfo);
      LFMSourceText:=NewFileDescriptor.GetResourceSource(NewUnitInfo.ComponentName);
      //DebugLn(['NewFile LFMSourceText=',LFMSourceText]);
      if LFMSourceText<>'' then begin
        // the NewFileDescriptor provides a custom .lfm source
        // -> put it into a new .lfm buffer and load it
        LFMFilename:=ChangeFileExt(NewUnitInfo.Filename,'.lfm');
        LFMCode:=CodeToolBoss.CreateFile(LFMFilename);
        LFMCode.Source:=LFMSourceText;
        //debugln('NewFile A ',LFMFilename);
        Result:=LoadLFM(NewUnitInfo,LFMCode,[],[]);
        //DebugLn(['NewFile ',dbgsName(NewUnitInfo.Component),' ',dbgsName(NewUnitInfo.Component.ClassParent)]);
        // make sure the .lrs file exists
        if (ResType=rtLRS) and NewUnitInfo.IsVirtual then begin
          LRSFilename:=ChangeFileExt(NewUnitInfo.Filename,'.lrs');
          CodeToolBoss.CreateFile(LRSFilename);
        end;
        if ((NewUnitInfo.Component is TCustomForm) or (NewUnitInfo.Component is TDataModule))
        and NewFileDescriptor.UseCreateFormStatements
        and NewUnitInfo.IsPartOfProject
        and AProject.AutoCreateForms
        and (pfMainUnitHasCreateFormStatements in AProject.Flags) then
        begin
          AProject.AddCreateFormToProjectFile(NewUnitInfo.Component.ClassName,
                                              NewUnitInfo.Component.Name);
        end;
      end else begin
        // create a designer form for a form/datamodule/frame
        //DebugLn(['NewFile Name=',NewFileDescriptor.Name,' Class=',NewFileDescriptor.ClassName]);
        DisableAutoSize:=true;
        Result := CreateNewForm(NewUnitInfo, AncestorType, nil,
                                NewFileDescriptor.UseCreateFormStatements,
                                DisableAutoSize);
        if DisableAutoSize and (NewUnitInfo.Component<>nil)
        and (NewUnitInfo.Component is TControl) then
        begin
          // disable autosizing for docked form editor forms, see issue #32207
          PreventAutoSize := (IDETabMaster <> nil)
                             and (NewUnitInfo.Component is TCustomDesignControl)
                             and IDETabMaster.AutoSizeInShowDesigner(TControl(NewUnitInfo.Component));
          if not PreventAutoSize then
            TControl(NewUnitInfo.Component).EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster Delayed'){$ENDIF};
        end;
      end;
      if Result<>mrOk then
      begin
        debugln(['NewFile create designer form failed ',NewUnitInfo.Filename]);
        exit;
      end;
    end;

    // show form and select form
    if NewUnitInfo.Component<>nil then begin
      // show form
      MainIDE.DoShowDesignerFormOfCurrentSrc(False);
    end else begin
      MainIDE.DisplayState:= dsSource;
    end;
  end else begin
    // do not open in editor
  end;

  // Update HasResources property (if the .lfm file was created separately)
  if (not NewUnitInfo.HasResources)
  and FilenameIsPascalUnit(NewUnitInfo.Filename) then begin
    //debugln('NewFile no HasResources ',NewUnitInfo.Filename);
    LFMFilename:=ChangeFileExt(NewUnitInfo.Filename,'.lfm');
    SearchFlags:=[];
    if NewUnitInfo.IsPartOfProject then
      Include(SearchFlags,pfsfOnlyProjectFiles);
    if NewUnitInfo.IsVirtual then
      Include(SearchFlags,pfsfOnlyVirtualFiles);
    if (AProject.UnitInfoWithFilename(LFMFilename,SearchFlags)<>nil) then begin
      //debugln('NewFile no HasResources ',NewUnitInfo.Filename,' ResourceFile exists');
      NewUnitInfo.HasResources:=true;
    end;
  end;

  if (nfAskForFilename in NewFlags) then begin
    // save and ask for filename
    NewUnitInfo.Modified:=true;
    Result:=SaveEditorFile(NewSrcEdit,[sfCheckAmbiguousFiles,sfSaveAs]);
    if Result<>mrOk then
    begin
      debugln(['NewFile SaveEditorFile failed ',NewFilename]);
      exit;
    end;
  end else if nfSave in NewFlags then begin
    if (nfOpenInEditor in NewFlags) or NewBuffer.IsVirtual then begin
      // save and ask for filename if needed
      NewUnitInfo.Modified:=true;
      Result:=SaveEditorFile(NewSrcEdit,[sfCheckAmbiguousFiles]);
      if Result<>mrOk then
      begin
        debugln(['NewFile SaveEditorFile SaveAs failed ',NewFilename]);
        exit;
      end;
    end else begin
      // save quietly
      NewBuffer.Save;
    end;
  end;

  Result:=mrOk;
  //DebugLn('NewFile END ',NewUnitInfo.Filename);
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('NewUnit end');{$ENDIF}
end;

function NewOther: TModalResult;
var
  NewIDEItem: TNewIDEItemTemplate;
  NewProjFile: TNewItemProjectFile;
begin
  Result:=ShowNewIDEItemDialog(NewIDEItem);
  if Result<>mrOk then exit;
  if NewIDEItem is TNewItemProjectFile then begin
    // file
    NewProjFile:=TNewItemProjectFile(NewIDEItem);
    if NewProjFile.Descriptor<>nil then
      NewProjFile.Descriptor.Owner:=Project1;
    try
      Result:=MainIDE.DoNewEditorFile(NewProjFile.Descriptor,
                                      '','',[nfOpenInEditor,nfCreateDefaultSrc]);
    finally
      if NewProjFile.Descriptor<>nil then
        NewProjFile.Descriptor.Owner:=nil;
    end;
  end else if NewIDEItem is TNewItemProject then       // project
    Result:=MainIDE.DoNewProject(TNewItemProject(NewIDEItem).Descriptor)
  else if NewIDEItem is TNewItemPackage then           // packages
    PkgBoss.DoNewPackage
  else
    IDEMessageDialog(ueNotImplCap, lisSorryThisTypeIsNotYetImplemented, mtInformation,[mbOk]);
end;

function NewUnitOrForm(Template: TNewIDEItemTemplate;
  DefaultDesc: TProjectFileDescriptor): TModalResult;
var
  Desc: TProjectFileDescriptor;
  Flags: TNewFlags;
begin
  if (Template is TNewItemProjectFile) and Template.VisibleInNewDialog then
    Desc:=TNewItemProjectFile(Template).Descriptor
  else
    Desc:=DefaultDesc;
  Flags:=[nfOpenInEditor,nfCreateDefaultSrc];
  if (not Project1.IsVirtual) and EnvironmentOptions.AskForFilenameOnNewFile then
    Flags:=Flags+[nfAskForFilename,nfSave];
  Desc.Owner:=Project1;
  try
    Result := MainIDE.DoNewEditorFile(Desc,'','',Flags);
  finally
    Desc.Owner:=nil;
  end;
end;

procedure CreateFileDialogFilterForSourceEditorFiles(Filter: string;
  out AllEditorMask, AllMask: string);
// Filter: a TFileDialog filter, e.g. Pascal|*.pas;*.pp|Text|*.txt
// AllEditorExt: a mask for all open files in the source editor, that are not
//               in Filter, e.g. '*.txt;*.xml'
// AllFilter: all masks of Filter and AllEditorExt, e.g. '*.pas;*.pp;*.inc'
var
  i: Integer;
  SrcEdit: TSourceEditor;
  Ext: String;
begin
  AllMask:='|'+TFileDialog.ExtractAllFilterMasks(Filter);
  AllEditorMask:='|';
  for i:=0 to SourceEditorManager.SourceEditorCount-1 do begin
    SrcEdit:=SourceEditorManager.SourceEditors[i];
    Ext:=ExtractFileExt(SrcEdit.FileName);
    if Ext<>'' then begin
      Ext:='*'+Ext;
      if (TFileDialog.FindMaskInFilter(AllMask,Ext)>0)
      or (TFileDialog.FindMaskInFilter(AllEditorMask,Ext)>0) then continue;
      if AllEditorMask<>'|' then
        AllEditorMask:=AllEditorMask+';';
      AllEditorMask:=AllEditorMask+Ext;
    end;
  end;
  System.Delete(AllMask,1,1);
  System.Delete(AllEditorMask,1,1);
  if AllEditorMask<>'' then begin
    if AllMask<>'' then
      AllMask:=AllMask+';';
    AllMask:=AllMask+AllEditorMask;
  end;
end;

function SaveEditorFile(AEditor: TSourceEditorInterface; Flags: TSaveFlags): TModalResult;
var
  AnUnitInfo, MainUnitInfo: TUnitInfo;
  TestFilename, DestFilename: string;
  LRSCode, LFMCode: TCodeBuffer;
  OldUnitName, OldFilename: String;
  NewUnitName, NewFilename: String;
  WasVirtual, WasPascalSource, CanAbort, Confirm: Boolean;
  SaveProjectFlags: TSaveFlags;
  EMacro: TEditorMacro;
begin
  Result:=mrCancel;
  CanAbort:=[sfCanAbort,sfProjectSaving]*Flags<>[];
  //debugln('SaveEditorFile A PageIndex=',PageIndex,' Flags=',SaveFlagsToString(Flags));
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('SaveEditorFile A');{$ENDIF}
  if not (MainIDE.ToolStatus in [itNone,itDebugger]) then
    exit(mrAbort);
  if AEditor=nil then exit(mrCancel);
  AnUnitInfo := Project1.UnitWithEditorComponent(AEditor);
  if AnUnitInfo=nil then exit(mrCancel);

  // do not save a unit which is currently reverting
  if AnUnitInfo.IsReverting then
    exit(mrOk);

  WasVirtual:=AnUnitInfo.IsVirtual;
  WasPascalSource:=FilenameIsPascalSource(AnUnitInfo.Filename);

  // if this file is part of a virtual project then save the project first
  if (not (sfProjectSaving in Flags)) and Project1.IsVirtual and AnUnitInfo.IsPartOfProject then
  begin
    SaveProjectFlags:=Flags*[sfSaveToTestDir];
    if AnUnitInfo=Project1.MainUnitInfo then
      Include(SaveProjectFlags,sfSaveMainSourceAs);
    Result:=SaveProject(SaveProjectFlags);
    exit;
  end;

  // update codetools cache and collect Modified flags
  if not (sfProjectSaving in Flags) then
    SaveEditorChangesToCodeCache(nil);

  if (uifInternalFile in AnUnitInfo.Flags) then
  begin
    if LazStartsStr(EditorMacroVirtualDrive, AnUnitInfo.Filename) then
    begin
      // save to macros
      EMacro := MacroListViewer.MacroByFullName(AnUnitInfo.Filename);
      if EMacro <> nil then begin
        EMacro.SetFromSource(AEditor.SourceText);
        if EMacro.IsInvalid and (EMacro.ErrorMsg <> '') then
          IDEMessagesWindow.AddCustomMessage(mluError,EMacro.ErrorMsg);
      end;
      MacroListViewer.UpdateDisplay;
      AnUnitInfo.ClearModifieds;
      AEditor.Modified:=false;
    end;
    // otherwise unknown internal file => skip
    exit(mrOk);
  end;

  // if this is a new unit then a simple Save becomes a SaveAs
  if (not (sfSaveToTestDir in Flags)) and (AnUnitInfo.IsVirtual) then
    Include(Flags,sfSaveAs);

  // if this is the main source and has the same name as the lpi
  // rename the project
  // Note:
  //   Changing the main source file without the .lpi is possible only by
  //   manually editing the lpi file, because this is only needed in
  //   special cases (rare functions don't need front ends).
  MainUnitInfo:=AnUnitInfo.Project.MainUnitInfo;
  if (sfSaveAs in Flags) and (not (sfProjectSaving in Flags)) and (AnUnitInfo=MainUnitInfo)
  then begin
    Result:=SaveProject([sfSaveAs,sfSaveMainSourceAs]);
    exit;
  end;

  // if nothing modified then a simple Save can be skipped
  //debugln(['SaveEditorFile A ',AnUnitInfo.Filename,' ',AnUnitInfo.NeedsSaveToDisk]);
  if ([sfSaveToTestDir,sfSaveAs]*Flags=[]) and (not AnUnitInfo.NeedsSaveToDisk) then
  begin
    if AEditor.Modified then
    begin
      AnUnitInfo.SessionModified:=true;
      AEditor.Modified:=false;
    end;
    exit(mrOk);
  end;

  // check if file is writable on disk
  if (not AnUnitInfo.IsVirtual) and FileExistsUTF8(AnUnitInfo.Filename) then
    AnUnitInfo.FileReadOnly:=not FileIsWritable(AnUnitInfo.Filename)
  else
    AnUnitInfo.FileReadOnly:=false;

  // if file is readonly then a simple Save is skipped
  if (AnUnitInfo.ReadOnly) and ([sfSaveToTestDir,sfSaveAs]*Flags=[]) then
    exit(mrOk);

  // load old resource file
  LFMCode:=nil;
  LRSCode:=nil;
  if WasPascalSource then
  begin
    Result:=LoadResourceFile(AnUnitInfo,LFMCode,LRSCode,true,CanAbort);
    if not (Result in [mrIgnore,mrOk]) then
      exit;
  end;

  OldUnitName:='';
  if WasPascalSource then
    OldUnitName:=AnUnitInfo.ReadUnitNameFromSource(true);
  OldFilename:=AnUnitInfo.Filename;

  if [sfSaveAs,sfSaveToTestDir]*Flags=[sfSaveAs] then begin
    // let user choose a filename
    NewFilename:=OldFilename;
    Result:=ShowSaveFileAsDialog(NewFilename,AnUnitInfo,LFMCode,LRSCode,CanAbort);
    if not (Result in [mrIgnore,mrOk]) then
      exit;
  end;

  // save source

  // a) do before save events
  if EditorOpts.AutoRemoveEmptyMethods and (AnUnitInfo.Component<>nil) then begin
    // Note: When removing published methods, the source, the lfm, the lrs
    //       and the form must be changed. At the moment editing the lfm without
    //       the component is not yet implemented.
    Result:=RemoveEmptyMethodsInUnit(AnUnitInfo.Source, AnUnitInfo.Component.ClassName,
                                     0,0,[pcsPublished]);
    if Result=mrAbort then exit;
  end;

  // b) do actual save
  DestFilename := '';
  if (sfSaveToTestDir in Flags) or AnUnitInfo.IsVirtual then
  begin
    // save source to test directory
    TestFilename := MainBuildBoss.GetTestUnitFilename(AnUnitInfo);
    if TestFilename <> '' then
    begin
      DestFilename := TestFilename;
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,
                                                  sefsBeforeWrite,DestFilename);
      if Result<>mrOk then exit;
      // actual write
      //DebugLn(['SaveEditorFile TestFilename="',TestFilename,'" Size=',AnUnitInfo.Source.SourceLength]);
      Result := AnUnitInfo.WriteUnitSourceToFile(DestFilename);
      if Result <> mrOk then
        Exit;
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,
                                                   sefsAfterWrite,DestFilename);
      if Result<>mrOk then exit;
    end
    else
      exit(mrCancel);
  end else
  begin
    if AnUnitInfo.Modified or (MainIDE.CheckFilesOnDiskEnabled and AnUnitInfo.NeedsSaveToDisk) then
    begin
      // save source to file
      DestFilename := AnUnitInfo.Filename;
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,
        AnUnitInfo,sefsBeforeWrite,DestFilename);
      if Result<>mrOk then exit;
      // actual write
      Result := AnUnitInfo.WriteUnitSource;
      if Result <> mrOK then
        exit;
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,
        AnUnitInfo,sefsAfterWrite,DestFilename);
      if Result<>mrOk then exit;
    end;
  end;

  if sfCheckAmbiguousFiles in Flags then
    MainBuildBoss.CheckAmbiguousSources(DestFilename,false);

  {$IFDEF IDE_DEBUG}
  debugln(['*** HasResources=',AnUnitInfo.HasResources]);
  {$ENDIF}
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('SaveEditorFile B');{$ENDIF}
  // save resource file and lfm file
  if (LRSCode<>nil) or (AnUnitInfo.Component<>nil) then begin
    Result:=SaveUnitComponent(AnUnitInfo,LRSCode,LFMCode,Flags);
    if not (Result in [mrIgnore, mrOk]) then
      exit;
  end;

  // unset all modified flags
  if not (sfSaveToTestDir in Flags) then begin
    AnUnitInfo.ClearModifieds;
    AEditor.Modified:=false;
    MainIDE.UpdateSaveMenuItemsAndButtons(not (sfProjectSaving in Flags));
  end;
  TSourceEditor(AEditor).SourceNotebook.UpdateStatusBar;

  // fix all references
  NewUnitName:='';
  if FilenameIsPascalSource(AnUnitInfo.Filename) then
    NewUnitName:=AnUnitInfo.ReadUnitNameFromSource(true);
  NewFilename:=AnUnitInfo.Filename;
  if (NewUnitName<>'')
  and ((OldUnitName<>NewUnitName) or (CompareFilenames(OldFilename,NewFilename)<>0))
  then begin
    if EnvironmentOptions.UnitRenameReferencesAction<>urraNever then
    begin
      // silently update references of new units (references were auto created
      // and keeping old references makes no sense)
      Confirm:=(EnvironmentOptions.UnitRenameReferencesAction=urraAsk)
               and (not WasVirtual);
      Result:=ReplaceUnitUse(OldFilename,OldUnitName,NewFilename,NewUnitName,
               true,true,Confirm);
      if Result<>mrOk then exit;
    end;
  end;

  {$IFDEF IDE_VERBOSE}
  debugln(['SaveEditorFile END ',NewFilename,' AnUnitInfo.Modified=',AnUnitInfo.Modified,' AEditor.Modified=',AEditor.Modified]);
  {$ENDIF}
  Result:=mrOk;
end;

function SaveEditorFile(const Filename: string; Flags: TSaveFlags): TModalResult;
var
  UnitIndex: Integer;
  AnUnitInfo: TUnitInfo;
  i: Integer;
begin
  Result:=mrOk;
  if Filename='' then exit;
  UnitIndex:=Project1.IndexOfFilename(TrimFilename(Filename),[pfsfOnlyEditorFiles]);
  if UnitIndex<0 then exit;
  AnUnitInfo:=Project1.Units[UnitIndex];
  for i := 0 to AnUnitInfo.OpenEditorInfoCount-1 do begin
    Result:=SaveEditorFile(AnUnitInfo.OpenEditorInfo[i].EditorComponent, Flags);
    if Result <> mrOK then Break;
    Flags:=Flags-[sfSaveAs,sfCheckAmbiguousFiles];
  end;
end;

function CloseEditorFile(AEditor: TSourceEditorInterface; Flags: TCloseFlags): TModalResult;
var
  AnUnitInfo: TUnitInfo;
  ACaption, AText: string;
  i: integer;
  AnEditorInfo: TUnitEditorInfo;
  SrcEditWasFocused: Boolean;
  SrcEdit: TSourceEditor;
begin
  {$IFDEF IDE_DEBUG}
  //debugln('CloseEditorFile A PageIndex=',IntToStr(AnUnitInfo.PageIndex));
  {$ENDIF}
  Result:=mrCancel;
  if AEditor = nil then exit;
  AnEditorInfo := Project1.EditorInfoWithEditorComponent(AEditor);
  //AnUnitInfo := Project1.UnitWithEditorComponent(AEditor);
  if AnEditorInfo = nil then begin
    // we need to close the page anyway or else we might enter a loop
    DebugLn('CloseEditorFile INCONSISTENCY: NO AnUnitInfo');
    SourceEditorManager.CloseFile(AEditor);
    Result:=mrOk;
    exit;
  end;
  AnUnitInfo := AnEditorInfo.UnitInfo;
  AnUnitInfo.SessionModified:=true;
  SrcEditWasFocused:=(AnEditorInfo.EditorComponent<>nil)
     and (AnEditorInfo.EditorComponent.EditorControl<>nil)
     and AnEditorInfo.EditorComponent.EditorControl.Focused;
  //debugln(['CloseEditorFile File=',AnUnitInfo.Filename,' WasFocused=',SrcEditWasFocused]);
  try
    //debugln(['CloseEditorFile File=',AnUnitInfo.Filename,' UnitSession=',AnUnitInfo.SessionModified,' ProjSession=',project1.SessionModified]);
    if AnUnitInfo.OpenEditorInfoCount > 1 then begin
      // opened multiple times => close one instance
      SourceEditorManager.CloseFile(AEditor);
      Result:=mrOk;
      exit;
    end;

    if (AnUnitInfo.Component<>nil) and (MainIDE.LastFormActivated<>nil)
    and (MainIDE.LastFormActivated.Designer.LookupRoot=AnUnitInfo.Component) then
      MainIDE.LastFormActivated:=nil;

    // save some meta data of the source
    SaveSrcEditorProjectSpecificSettings(AnEditorInfo);

    // if SaveFirst then save the source
    if (cfSaveFirst in Flags) and (not AnUnitInfo.ReadOnly)
    and ((AEditor.Modified) or (AnUnitInfo.Modified)) then begin
      if not (cfQuiet in Flags) then begin
        // ask user
        if AnUnitInfo.Filename<>'' then
          AText:=Format(lisFileHasChangedSave, [AnUnitInfo.Filename])
        else if AnUnitInfo.Unit_Name<>'' then
          AText:=Format(lisUnitHasChangedSave, [AnUnitInfo.Unit_Name])
        else
          AText:=Format(lisSourceOfPageHasChangedSave, [TSourceEditor(AEditor).PageName]);
        ACaption:=lisSourceModified;
        Result:=IDEQuestionDialog(ACaption, AText,
            mtConfirmation, [mrYes, lisMenuSave,
                             mrNo, lisDiscardChanges,
                             mrAbort]);
      end else
        Result:=mrYes;
      if Result=mrYes then begin
        Result:=SaveEditorFile(AnEditorInfo.EditorComponent,[sfCheckAmbiguousFiles]);
      end;
      if Result in [mrAbort,mrCancel] then exit;
      Result:=mrOk;
    end;
    // mark file as unmodified
    if (AnUnitInfo.Source<>nil) and AnUnitInfo.Source.Modified then
      AnUnitInfo.Source.Clear;

    // add to recent file list
    if (not AnUnitInfo.IsVirtual) and (not (cfProjectClosing in Flags)) then
    begin
      EnvironmentOptions.AddToRecentOpenFiles(AnUnitInfo.Filename);
      MainIDE.SetRecentFilesMenu;
    end;

    // close form soft (keep it if used by another component)
    CloseUnitComponent(AnUnitInfo,[]);

    // close source editor
    SourceEditorManager.CloseFile(AnEditorInfo.EditorComponent);
    MainIDEBar.itmFileClose.Enabled:=SourceEditorManager.SourceEditorCount > 0;
    MainIDEBar.itmFileCloseAll.Enabled:=MainIDEBar.itmFileClose.Enabled;

    // free sources, forget changes
    if (AnUnitInfo.Source<>nil) then begin
      if (Project1.MainUnitInfo=AnUnitInfo)
      and (not (cfProjectClosing in Flags)) then begin
        AnUnitInfo.Source.Revert;
      end else begin
        AnUnitInfo.Source.IsDeleted:=true;
      end;
    end;

    // close file in project
    AnUnitInfo.Loaded:=false;
    if AnUnitInfo<>Project1.MainUnitInfo then
      AnUnitInfo.Source:=nil;
    if not (cfProjectClosing in Flags) then begin
      i:=Project1.IndexOf(AnUnitInfo);
      if (i<>Project1.MainUnitID) and AnUnitInfo.IsVirtual then begin
        Project1.RemoveUnit(i);
      end;
    end;

  finally
    if SrcEditWasFocused then begin
      // before closing the syendit was focused. Focus the current synedit.
      SrcEdit := SourceEditorManager.ActiveEditor;
      if (SrcEdit<>nil)
      and (SrcEdit.EditorControl<>nil)
      and (SrcEdit.EditorControl.CanFocus) then
        SrcEdit.EditorControl.SetFocus;
      //debugln(['CloseEditorFile Focus=',SrcEdit.FileName,' Editor=',DbgSName(SrcEdit.EditorControl),' Focused=',(SrcEdit.EditorControl<>nil) and (SrcEdit.EditorControl.Focused)]);
    end;
  end;
  {$IFDEF IDE_DEBUG}
  DebugLn('CloseEditorFile end');
  {$ENDIF}
  Result:=mrOk;
end;

function CloseEditorFile(const Filename: string; Flags: TCloseFlags): TModalResult;
var
  UnitIndex: Integer;
  AnUnitInfo: TUnitInfo;
begin
  Result:=mrOk;
  if Filename='' then exit;
  UnitIndex:=Project1.IndexOfFilename(TrimFilename(Filename),[pfsfOnlyEditorFiles]);
  if UnitIndex<0 then exit;
  AnUnitInfo:=Project1.Units[UnitIndex];
  while (AnUnitInfo.OpenEditorInfoCount > 0) and (Result = mrOK) do
    Result:=CloseEditorFile(AnUnitInfo.OpenEditorInfo[0].EditorComponent, Flags);
end;

function FindUnitFileImpl(const AFilename: string; TheOwner: TObject;
  Flags: TFindUnitFileFlags): string;

  function FindInBaseIDE: string;
  var
    AnUnitName: String;
    BaseDir: String;
    UnitInFilename: String;
  begin
    AnUnitName:=ExtractFileNameOnly(AFilename);
    BaseDir:=EnvironmentOptions.GetParsedLazarusDirectory+PathDelim+'ide';
    UnitInFilename:='';
    Result:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                                       BaseDir,AnUnitName,UnitInFilename,true);
  end;

  function FindInProject(AProject: TProject): string;
  var
    AnUnitInfo: TUnitInfo;
    AnUnitName: String;
    BaseDir: String;
    UnitInFilename: String;
  begin
    // search in virtual (unsaved) files
    AnUnitInfo:=AProject.UnitInfoWithFilename(AFilename,
                                     [pfsfOnlyProjectFiles,pfsfOnlyVirtualFiles]);
    if AnUnitInfo<>nil then begin
      Result:=AnUnitInfo.Filename;
      exit;
    end;

    // search in search path of project
    AnUnitName:=ExtractFileNameOnly(AFilename);
    BaseDir:=AProject.Directory;
    UnitInFilename:='';
    Result:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                                       BaseDir,AnUnitName,UnitInFilename,true);
  end;

  function FindInPackage(APackage: TLazPackage): string;
  var
    BaseDir: String;
    AnUnitName: String;
    UnitInFilename: String;
  begin
    Result:='';
    BaseDir:=APackage.Directory;
    if not FilenameIsAbsolute(BaseDir) then exit;
    // search in search path of package
    AnUnitName:=ExtractFileNameOnly(AFilename);
    UnitInFilename:='';
    Result:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
                                       BaseDir,AnUnitName,UnitInFilename,true);
  end;

var
  AProject: TProject;
  i: Integer;
begin
  if FilenameIsAbsolute(AFilename) then begin
    Result:=AFilename;
    exit;
  end;
  Result:='';

  // project
  AProject:=nil;
  if TheOwner=nil then begin
    AProject:=Project1;
  end else if (TheOwner is TProject) then
    AProject:=TProject(TheOwner);

  if AProject<>nil then
  begin
    Result:=FindInProject(AProject);
    if Result<>'' then exit;
  end;

  // package
  if TheOwner is TLazPackage then begin
    Result:=FindInPackage(TLazPackage(TheOwner));
    if Result<>'' then exit;
  end;

  if TheOwner=LazarusIDE then begin
    // search in base IDE
    Result:=FindInBaseIDE;
    if Result<>'' then exit;

    // search in installed packages
    for i:=0 to PackageGraph.Count-1 do
      if (PackageGraph[i].Installed<>pitNope)
      and ((not (fuffIgnoreUninstallPackages in Flags))
           or (PackageGraph[i].AutoInstall<>pitNope))
      then begin
        Result:=FindInPackage(PackageGraph[i]);
        if Result<>'' then exit;
      end;
    // search in auto install packages
    for i:=0 to PackageGraph.Count-1 do
      if (PackageGraph[i].Installed=pitNope)
      and (PackageGraph[i].AutoInstall<>pitNope) then begin
        Result:=FindInPackage(PackageGraph[i]);
        if Result<>'' then exit;
      end;
    // then search in all other open packages
    for i:=0 to PackageGraph.Count-1 do
      if (PackageGraph[i].Installed=pitNope)
      and (PackageGraph[i].AutoInstall=pitNope) then begin
        Result:=FindInPackage(PackageGraph[i]);
        if Result<>'' then exit;
      end;
  end;
  Result:='';
end;

function FindSourceFileImpl(const AFilename, BaseDirectory: string;
  Flags: TFindSourceFlags): string;
// AFilename can be an absolute or relative filename, of a source file or a
// compiled unit (.ppu).
// Find the source filename (pascal source or include file) and returns
// the absolute path.
// With fsfMapTempToVirtualFiles files in the temp directory are stripped off
// the temporary files resulting in the virtual file name of the CodeTools.
//
// First it searches in the current projects src path, then its unit path, then
// its include path. Then all used package source directories are searched.
// Finally the fpc sources are searched.
var
  CompiledSrcExt: String;
  BaseDir: String;
  AlreadySearchedPaths: string;
  StartUnitPath: String;

  procedure MarkPathAsSearched(const AddSearchPath: string);
  begin
    AlreadySearchedPaths:=MergeSearchPaths(AlreadySearchedPaths,AddSearchPath);
  end;

  function SearchIndirectIncludeFile: string;
  var
    UnitPath: String;
    CurDir: String;
    AlreadySearchedUnitDirs: String;
    CompiledUnitPath: String;
    AllSrcPaths: String;
    CurSrcPath: String;
    CurIncPath: String;
    PathPos: Integer;
    AllIncPaths: String;
    SearchPath: String;
    SearchFile: String;
  begin
    if CompiledSrcExt='' then exit('');
    // get unit path for compiled units
    UnitPath:=BaseDir+';'+StartUnitPath;
    UnitPath:=TrimSearchPath(UnitPath,BaseDir);

    // Extract all directories with compiled units
    CompiledUnitPath:='';
    AlreadySearchedUnitDirs:='';
    PathPos:=1;
    while PathPos<=length(UnitPath) do begin
      CurDir:=GetNextDirectoryInSearchPath(UnitPath,PathPos);
      // check if directory is already tested
      if SearchDirectoryInSearchPath(AlreadySearchedUnitDirs,CurDir,1)>0 then
        continue;
      AlreadySearchedUnitDirs:=MergeSearchPaths(AlreadySearchedUnitDirs,CurDir);
      // check if directory contains a compiled unit
      if FindFirstFileWithExt(CurDir,CompiledSrcExt)<>'' then
        CompiledUnitPath:=CompiledUnitPath+';'+CurDir;
    end;
    {$IFDEF VerboseFindSourceFile}
    debugln(['SearchIndirectIncludeFile CompiledUnitPath="',CompiledUnitPath,'"']);
    {$ENDIF}

    // collect all src paths for the compiled units
    AllSrcPaths:=CompiledUnitPath;
    PathPos:=1;
    while PathPos<=length(CompiledUnitPath) do begin
      CurDir:=GetNextDirectoryInSearchPath(CompiledUnitPath,PathPos);
      CurSrcPath:=CodeToolBoss.GetCompiledSrcPathForDirectory(CurDir);
      CurSrcPath:=TrimSearchPath(CurSrcPath,CurDir);
      AllSrcPaths:=MergeSearchPaths(AllSrcPaths,CurSrcPath);
    end;
    {$IFDEF VerboseFindSourceFile}
    debugln(['SearchIndirectIncludeFile AllSrcPaths="',AllSrcPaths,'"']);
    {$ENDIF}

    // add fpc src directories
    // ToDo

    // collect all include paths
    AllIncPaths:=AllSrcPaths;
    PathPos:=1;
    while PathPos<=length(AllSrcPaths) do begin
      CurDir:=GetNextDirectoryInSearchPath(AllSrcPaths,PathPos);
      CurIncPath:=CodeToolBoss.GetIncludePathForDirectory(CurDir);
      CurIncPath:=TrimSearchPath(CurIncPath,CurDir);
      AllIncPaths:=MergeSearchPaths(AllIncPaths,CurIncPath);
    end;
    {$IFDEF VerboseFindSourceFile}
    debugln(['SearchIndirectIncludeFile AllIncPaths="',AllIncPaths,'"']);
    {$ENDIF}

    SearchFile:=AFilename;
    SearchPath:=AllIncPaths;
    Result:=FileUtil.SearchFileInPath(SearchFile,BaseDir,SearchPath,';',[]);
    {$IFDEF VerboseFindSourceFile}
    debugln(['SearchIndirectIncludeFile Result="',Result,'"']);
    {$ENDIF}
    MarkPathAsSearched(SearchPath);
  end;

  function SearchInPath(const TheSearchPath, SearchFile: string;
    var Filename: string): boolean;
  var
    SearchPath: String;
  begin
    Filename:='';
    SearchPath:=RemoveSearchPaths(TheSearchPath,AlreadySearchedPaths);
    if SearchPath<>'' then begin
      Filename:=FileUtil.SearchFileInPath(SearchFile,BaseDir,SearchPath,';',[]);
      {$IFDEF VerboseFindSourceFile}
      debugln(['FindSourceFile trying "',SearchPath,'" Filename="',Filename,'"']);
      {$ENDIF}
      MarkPathAsSearched(SearchPath);
    end;
    Result:=Filename<>'';
  end;

var
  SearchPath: String;
  SearchFile: String;
  ProjFile: TLazProjectFile;
begin
  {$IFDEF VerboseFindSourceFile}
  debugln(['FindSourceFile Filename="',AFilename,'" BaseDirectory="',BaseDirectory,'"']);
  {$ENDIF}
  if AFilename='' then exit('');

  if fsfMapTempToVirtualFiles in Flags then
  begin
    BaseDir:=MainBuildBoss.GetTestBuildDirectory;
    if FilenameIsAbsolute(AFilename)
    and FileIsInPath(AFilename,BaseDir) then
    begin
      Result:=CreateRelativePath(AFilename,BaseDir);
      if (Project1<>nil) and (Project1.UnitInfoWithFilename(Result)<>nil) then
        exit;
    end;
  end;

  if FilenameIsAbsolute(AFilename) then
  begin
    Result := AFilename;
    if not FileExistsCached(Result) then
      Result := '';
    Exit;
  end;

  AlreadySearchedPaths:='';
  BaseDir:=BaseDirectory;
  GlobalMacroList.SubstituteStr(BaseDir);
  BaseDir:=AppendPathDelim(TrimFilename(BaseDir));

  // search file in base directory
  if FilenameIsAbsolute(BaseDir) then begin
    Result:=TrimFilename(BaseDir+AFilename);
    {$IFDEF VerboseFindSourceFile}
    debugln(['FindSourceFile trying Base "',Result,'"']);
    {$ENDIF}
    if FileExistsCached(Result) then exit;
    MarkPathAsSearched(BaseDir);
  end else if Project1<>nil then begin
    // search in virtual files
    Result:=TrimFilename(BaseDir+AFilename);
    ProjFile:=Project1.FindFile(Result,[pfsfOnlyVirtualFiles]);
    if ProjFile<>nil then
      exit;
  end;

  // search file in debug path
  if (fsfUseDebugPath in Flags) and (Project1<>nil) then begin
    SearchPath:=EnvironmentOptions.GetParsedDebuggerSearchPath;
    SearchPath:=MergeSearchPaths(Project1.CompilerOptions.GetDebugPath(false),
                                 SearchPath);
    SearchPath:=TrimSearchPath(SearchPath,BaseDir);
    if SearchInPath(SearchPath,AFilename,Result) then exit;
  end;

  CompiledSrcExt:=CodeToolBoss.GetCompiledSrcExtForDirectory(BaseDir);
  StartUnitPath:=CodeToolBoss.GetCompleteSrcPathForDirectory(BaseDir);
  StartUnitPath:=TrimSearchPath(StartUnitPath,BaseDir);

  // if file is a pascal unit, search via unit and src paths
  if FilenameIsPascalUnit(AFilename) then begin
    // first search file in unit path
    if SearchInPath(StartUnitPath,AFilename,Result) then exit;

    // search unit in fpc source directory
    Result:=CodeToolBoss.FindUnitInUnitSet(BaseDir,
                                           ExtractFilenameOnly(AFilename));
    {$IFDEF VerboseFindSourceFile}
    debugln(['FindSourceFile tried unitset Result=',Result]);
    {$ENDIF}
    if Result<>'' then exit;
  end;

  if fsfUseIncludePaths in Flags then begin
    // search in include path
    if (fsfSearchForProject in Flags) then
      SearchPath:=Project1.CompilerOptions.GetIncludePath(false)
    else
      SearchPath:=CodeToolBoss.GetIncludePathForDirectory(BaseDir);
    SearchPath:=TrimSearchPath(SearchPath,BaseDir);
    if SearchInPath(StartUnitPath,AFilename,Result) then exit;

    if not(fsfSkipPackages in Flags) then begin
      // search include file in source directories of all required packages
      SearchFile:=AFilename;
      Result:=PkgBoss.FindIncludeFileInProjectDependencies(Project1,SearchFile);
      {$IFDEF VerboseFindSourceFile}
      debugln(['FindSourceFile trying packages "',SearchPath,'" Result=',Result]);
      {$ENDIF}
    end;
    if Result<>'' then exit;

    Result:=SearchIndirectIncludeFile;
    if Result<>'' then exit;
  end;

  Result:='';
end;

function FindUnitsOfOwnerImpl(TheOwner: TObject; Flags: TFindUnitsOfOwnerFlags): TStrings;
var
  Files: TFilenameToStringTree;
  UnitPath: string; // only if not AddPackages:
                    // owner unitpath without unitpaths of required packages

  function Add(const aFilename: string): boolean;
  begin
    if Files.Contains(aFilename) then exit(false);
    //debugln(['  Add ',aFilename]);
    Files[aFilename]:='';
    FindUnitsOfOwnerImpl.Add(aFilename);
    Result := True;
  end;

  procedure AddListedPackageUnits(aPackage: TLazPackage);
  // add listed units of aPackage
  var
    i: Integer;
    PkgFile: TPkgFile;
  begin
    //debugln([' AddListedPackageUnits ',aPackage.IDAsString]);
    for i:=0 to aPackage.FileCount-1 do
    begin
      PkgFile:=aPackage.Files[i];
      if not (PkgFile.FileType in PkgFileRealUnitTypes) then continue;
      if not PkgFile.InUses then continue;
      Add(PkgFile.Filename);
    end;
  end;

  procedure AddUsedUnit(const aFilename: string);
  // add recursively all units

    procedure AddUses(UsesSection: TStrings);
    var
      i: Integer;
      Code: TCodeBuffer;
    begin
      if UsesSection=nil then exit;
      for i:=0 to UsesSection.Count-1 do begin
        //debugln(['AddUses ',UsesSection[i]]);
        Code:=TCodeBuffer(UsesSection.Objects[i]);
        if Code=nil then exit;
        AddUsedUnit(Code.Filename);
      end;
    end;

  var
    Code: TCodeBuffer;
    MainUsesSection, ImplementationUsesSection: TStrings;
  begin
    //debugln(['  AddUsedUnit START ',aFilename]);
    if not (fuooPackages in Flags) then
    begin
      if FilenameIsAbsolute(aFilename) then
      begin
        if SearchDirectoryInSearchPath(UnitPath,ExtractFilePath(aFilename))<0 then
          exit; // not in exclusive unitpath
      end else begin
        if (not (TheOwner is TProject)) or (not TProject(TheOwner).IsVirtual) then
          exit;
      end;
    end;
    //debugln(['  AddUsedUnit OK ',aFilename]);
    if not Add(aFilename) then exit;
    Code:=CodeToolBoss.LoadFile(aFilename,true,false);
    if Code=nil then exit;
    MainUsesSection:=nil;
    ImplementationUsesSection:=nil;
    try
      CodeToolBoss.FindUsedUnitFiles(Code,MainUsesSection,ImplementationUsesSection);
      AddUses(MainUsesSection);
      AddUses(ImplementationUsesSection);
    finally
      MainUsesSection.Free;
      ImplementationUsesSection.Free;
    end;
  end;

var
  aProject: TProject;
  aPackage, ReqPackage: TLazPackage;
  MainFile, CurFilename: String;
  AnUnitInfo: TUnitInfo;
  i: Integer;
  Code: TCodeBuffer;
  FoundInUnits, MissingUnits, NormalUnits: TStrings;
  PkgList: TFPList;
  PkgListFlags: TPkgIntfRequiredFlags;
begin
  Result:=TStringList.Create;
  MainFile:='';
  FoundInUnits:=nil;
  MissingUnits:=nil;
  NormalUnits:=nil;
  aProject:=nil;
  aPackage:=nil;
  PkgList:=nil;
  Files:=TFilenameToStringTree.Create(false);
  try
    //debugln(['FindUnitsOfOwner ',DbgSName(TheOwner)]);
    if TheOwner is TProject then
    begin
      aProject:=TProject(TheOwner);
      // add main project source (e.g. .lpr)
      if (aProject.MainFile<>nil) and (pfMainUnitIsPascalSource in aProject.Flags)
      then begin
        MainFile:=aProject.MainFile.Filename;
        Add(MainFile);
      end;
      if (fuooListed in Flags) then begin
        // add listed units (i.e. units in project inspector)
        AnUnitInfo:=aProject.FirstPartOfProject;
        while AnUnitInfo<>nil do
        begin
          if FilenameIsPascalUnit(AnUnitInfo.Filename) then
            Add(AnUnitInfo.Filename);
          AnUnitInfo:=AnUnitInfo.NextPartOfProject;
        end;
      end;
      if (fuooListed in Flags) and (fuooPackages in Flags) then
      begin
        // get required packages
        if pfUseDesignTimePackages in aProject.Flags then
          PkgListFlags:=[]
        else
          PkgListFlags:=[pirSkipDesignTimeOnly];
        PackageGraph.GetAllRequiredPackages(nil,aProject.FirstRequiredDependency,
          PkgList,PkgListFlags);
      end;
    end else if TheOwner is TLazPackage then begin
      aPackage:=TLazPackage(TheOwner);
      if (fuooListed in Flags) then
      begin
        // add listed units (i.e. units in package editor)
        AddListedPackageUnits(aPackage);
      end;
      if (fuooUsed in Flags) then
        MainFile:=aPackage.GetSrcFilename;
      if (fuooListed in Flags) and (fuooPackages in Flags) then
      begin
        // get required packages
        PackageGraph.GetAllRequiredPackages(aPackage,nil,PkgList,[]);
      end;
    end else begin
      FreeAndNil(Result);
      raise Exception.Create('FindUnitsOfOwner: invalid owner '+DbgSName(TheOwner));
    end;

    if (fuooListed in Flags) and (fuooPackages in Flags) and (PkgList<>nil) then begin
      // add package units (listed in their package editors)
      for i:=0 to PkgList.Count-1 do begin
        ReqPackage:=TLazPackage(PkgList[i]);
        AddListedPackageUnits(ReqPackage);
      end;
    end;

    if (fuooUsed in Flags) and (MainFile<>'') then
    begin
      // add all used units with 'in' files
      Code:=CodeToolBoss.LoadFile(MainFile,true,false);
      if Code<>nil then begin
        UnitPath:='';
        if aProject<>nil then begin
          CodeToolBoss.FindDelphiProjectUnits(Code,FoundInUnits,MissingUnits,NormalUnits);
          if not (fuooPackages in Flags) then
          begin
            // only project units wanted -> create unitpath excluding unitpaths from packages
            // Note: even if the project contains an unitpath to the source
            //       folder of a package, the units are not project units.
            UnitPath:=aProject.CompilerOptions.GetUnitPath(false);
            RemoveSearchPaths(UnitPath,aProject.CompilerOptions.GetInheritedOption(icoUnitPath,false));
          end;
        end
        else if aPackage<>nil then begin
          CodeToolBoss.FindDelphiPackageUnits(Code,FoundInUnits,MissingUnits,NormalUnits);
          if not (fuooPackages in Flags) then
          begin
            // only units of this package wanted
            // -> create unitpath excluding unitpaths from used packages
            // Note: even if the package contains an unitpath to the source
            //       folder of a sub package, the units belong to the sub package
            UnitPath:=aPackage.CompilerOptions.GetUnitPath(false);
            RemoveSearchPaths(UnitPath,aPackage.CompilerOptions.GetInheritedOption(icoUnitPath,false));
          end;
        end;
        //debugln(['FindUnitsOfOwner UnitPath="',UnitPath,'"']);
        if FoundInUnits<>nil then
          for i:=0 to FoundInUnits.Count-1 do
          begin
            CurFilename:=TCodeBuffer(FoundInUnits.Objects[i]).Filename;
            Add(CurFilename); // units with 'in' filename always belong to the
                // project, that's the Delphi way
            AddUsedUnit(CurFilename);
          end;
        if NormalUnits<>nil then
          for i:=0 to NormalUnits.Count-1 do
            AddUsedUnit(TCodeBuffer(NormalUnits.Objects[i]).Filename);
      end;
    end;
    if (fuooSourceEditor in Flags) then
      for i := 0 to pred(SourceEditorManager.SourceEditorCount) do
      begin
        CurFilename := SourceEditorManager.SourceEditors[i].FileName;
        if FilenameIsPascalUnit(CurFilename) then
          Add(CurFilename);
      end;
  finally
    FoundInUnits.Free;
    MissingUnits.Free;
    NormalUnits.Free;
    PkgList.Free;
    Files.Free;
  end;
end;

function SelectProjectItems(ItemList: TViewUnitEntries; ItemType: TIDEProjectItem): TModalResult;
var
  i: integer;
  AUnitName, DlgCaption: string;
  MainUnitInfo: TUnitInfo;
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  CurUnitInfo: TUnitInfo;
  LFMFilename: String;
  LFMType: String;
  LFMComponentName: String;
  LFMClassName: String;
  anUnitName: String;
  LFMCode: TCodeBuffer;
begin
  if Project1=nil then exit(mrCancel);
  MainIDE.GetCurrentUnit(ActiveSourceEditor, ActiveUnitInfo);
  for i := 0 to Project1.UnitCount - 1 do
  begin
    CurUnitInfo:=Project1.Units[i];
    if not CurUnitInfo.IsPartOfProject then
      Continue;
    if ItemType in [piComponent, piFrame] then
    begin
      // add all form names of project
      if CurUnitInfo.ComponentName <> '' then
      begin
        if (ItemType = piComponent) or
           ((ItemType = piFrame) and (CurUnitInfo.ResourceBaseClass = pfcbcFrame)) then
          ItemList.Add(CurUnitInfo.ComponentName,
                       CurUnitInfo.Filename, i, CurUnitInfo = ActiveUnitInfo);
      end else if FilenameIsAbsolute(CurUnitInfo.Filename)
      and FilenameIsPascalSource(CurUnitInfo.Filename)
      and FileExistsCached(CurUnitInfo.Filename) then
      begin
        // this unit has a lfm, but the lpi does not know a ComponentName
        // => maybe this component was added without the IDE
        LFMFilename:=ChangeFileExt(CurUnitInfo.Filename,'.lfm');
        LFMCode:=CodeToolBoss.LoadFile(LFMFilename,true,false);
        if LFMCode<>nil then
        begin
          ReadLFMHeader(LFMCode.Source,LFMType,LFMComponentName,LFMClassName);
          if LFMComponentName<>'' then begin
            anUnitName:=CurUnitInfo.Unit_Name;
            if anUnitName='' then
              anUnitName:=ExtractFileNameOnly(LFMFilename);
            ItemList.Add(LFMComponentName, CurUnitInfo.Filename,
              i, CurUnitInfo = ActiveUnitInfo);
          end;
        end;
      end;
    end else
    begin
      // add all unit names of project
      if (CurUnitInfo.FileName <> '') then
      begin
        AUnitName := ExtractFileName(CurUnitInfo.Filename);
        if ItemList.Find(AUnitName) = nil then
          ItemList.Add(AUnitName, CurUnitInfo.Filename,
                       i, CurUnitInfo = ActiveUnitInfo);
      end
      else
      if Project1.MainUnitID = i then
      begin
        MainUnitInfo := Project1.MainUnitInfo;
        if pfMainUnitIsPascalSource in Project1.Flags then
        begin
          AUnitName := ExtractFileName(MainUnitInfo.Filename);
          if (AUnitName <> '') and (ItemList.Find(AUnitName) = nil) then
          begin
            ItemList.Add(AUnitName, MainUnitInfo.Filename,
                         i, MainUnitInfo = ActiveUnitInfo);
          end;
        end;
      end;
    end;
  end;
  case ItemType of
    piUnit:      DlgCaption := dlgMainViewUnits;
    piComponent: DlgCaption := dlgMainViewForms;
    piFrame:     DlgCaption := dlgMainViewFrames;
    else         DlgCaption := '';
  end;
  Result := ShowViewUnitsDlg(ItemList, true, DlgCaption, ItemType);
end;

function SelectUnitComponents(DlgCaption: string; ItemType: TIDEProjectItem;
  Files: TStringList): TModalResult;
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
  UnitToFilename: TStringToStringTree;
  UnitPath: String;

  function ResourceFits(ResourceBaseClass: TPFComponentBaseClass): boolean;
  begin
    case ItemType of
    piUnit: Result:=true;
    piComponent: Result:=ResourceBaseClass<>pfcbcNone;
    piFrame: Result:=ResourceBaseClass=pfcbcFrame;
    else Result:=false;
    end;
  end;

  procedure AddUnit(AnUnitName,AFilename: string);
  var
    LFMFilename: String;
  begin
    //debugln(['AddUnit ',AFilename]);
    if not FilenameIsPascalUnit(AFilename) then exit;
    if CompareFilenames(AFilename,ActiveUnitInfo.Filename)=0 then exit;
    if (AnUnitName='') then
      AnUnitName:=ExtractFileNameOnly(AFilename);
    if (not FilenameIsAbsolute(AFilename)) then begin
      if (not ActiveUnitInfo.IsVirtual) then
        exit; // virtual UnitToFilename can not be accessed from disk UnitToFilename
    end else begin
      //debugln(['AddUnit unitpath=',UnitPath]);
      if SearchDirectoryInSearchPath(UnitPath,ExtractFilePath(AFilename))<1 then
        exit; // not reachable
    end;
    if UnitToFilename.Contains(AnUnitName) then exit; // duplicate unit
    if not FileExistsCached(AFilename) then exit;
    LFMFilename:=ChangeFileExt(aFilename,'.lfm');
    if not FileExistsCached(LFMFilename) then exit;
    UnitToFilename[AnUnitName]:=AFilename;
  end;

  procedure AddPackage(Pkg: TLazPackage);
  var
    i: Integer;
    PkgFile: TPkgFile;
  begin
    //debugln(['AddPackage ',pkg.Name]);
    for i:=0 to Pkg.FileCount-1 do begin
      PkgFile:=TPkgFile(Pkg.Files[i]);
      if not (PkgFile.FileType in PkgFileRealUnitTypes) then continue;
      if not FilenameIsAbsolute(PkgFile.Filename) then continue;
      if not ResourceFits(PkgFile.ResourceBaseClass) then begin
        if PkgFile.ResourceBaseClass<>pfcbcNone then continue;
        // unknown resource class => check file
        PkgFile.ResourceBaseClass:=FindLFMBaseClass(PkgFile.Filename);
        if not ResourceFits(PkgFile.ResourceBaseClass) then continue;
      end;
      AddUnit(PkgFile.Unit_Name,PkgFile.Filename);
    end;
  end;

var
  Owners: TFPList;
  APackage: TLazPackage;
  AProject: TProject;
  AnUnitInfo: TUnitInfo;
  FirstDependency: TPkgDependency;
  PkgList: TFPList;
  i: Integer;
  S2SItem: PStringToStringItem;
  AnUnitName: String;
  AFilename: String;
  UnitList: TViewUnitEntries;
  Entry: TViewUnitsEntry;
begin
  Result:=mrCancel;
  MainIDE.GetCurrentUnit(ActiveSourceEditor, ActiveUnitInfo);
  if ActiveUnitInfo=nil then exit;
  Owners:=PkgBoss.GetPossibleOwnersOfUnit(ActiveUnitInfo.Filename,[]);
  UnitPath:=CodeToolBoss.GetCompleteSrcPathForDirectory(ExtractFilePath(ActiveUnitInfo.Filename));
  PkgList:=nil;
  UnitToFilename:=TStringToStringTree.Create(false);
  UnitList:=TViewUnitEntries.Create;
  try
    // fetch owner of active unit
    AProject:=nil;
    APackage:=nil;
    if (Owners<>nil) then begin
      for i:=0 to Owners.Count-1 do begin
        if TObject(Owners[i]) is TProject then begin
          AProject:=TProject(Owners[i]);
          break;
        end else if TObject(Owners[i]) is TLazPackage then begin
          APackage:=TLazPackage(Owners[i]);
        end;
      end;
    end;
    if AProject<>nil then begin
      // add project units
      //debugln(['SelectUnitComponents Project=',AProject.ProjectInfoFile]);
      FirstDependency:=AProject.FirstRequiredDependency;
      for i:=0 to AProject.UnitCount-1 do begin
        AnUnitInfo:=AProject.Units[i];
        if (not AnUnitInfo.IsPartOfProject)
        or (AnUnitInfo.ComponentName='')
        then continue;
        if not ResourceFits(AnUnitInfo.ResourceBaseClass) then begin
          if AnUnitInfo.ResourceBaseClass<>pfcbcNone then continue;
          // unknown resource class => check file
          AnUnitInfo.ResourceBaseClass:=FindLFMBaseClass(AnUnitInfo.Filename);
          if not ResourceFits(AnUnitInfo.ResourceBaseClass) then continue;
        end;
        AddUnit(AnUnitInfo.Unit_Name,AnUnitInfo.Filename);
      end;
    end else if APackage<>nil then begin
      // add package units
      FirstDependency:=APackage.FirstRequiredDependency;
      AddPackage(APackage);
    end else
      FirstDependency:=nil;
    // add all units of all used packages
    PackageGraph.GetAllRequiredPackages(nil,FirstDependency,PkgList);
    if PkgList<>nil then
      for i:=0 to PkgList.Count-1 do
        AddPackage(TLazPackage(PkgList[i]));

    // create Files
    i:=0;
    for S2SItem in UnitToFilename do begin
      AnUnitName:=S2SItem^.Name;
      AFilename:=S2SItem^.Value;
      UnitList.Add(AnUnitName,AFilename,i,false);
      inc(i);
    end;
    // show dialog
    Result := ShowViewUnitsDlg(UnitList, false,
                               DlgCaption, ItemType, ActiveUnitInfo.Filename);
    // create list of selected files
    for Entry in UnitList do
      if Entry.Selected then
        Files.Add(Entry.Filename);

  finally
    UnitList.Free;
    PkgList.Free;
    Owners.Free;
    UnitToFilename.Free;
  end;
end;

function RemoveFromProjectDialog: TModalResult;
var
  ViewUnitEntries: TViewUnitEntries;
  i:integer;
  AName: string;
  AnUnitInfo: TUnitInfo;
  UnitInfos: TFPList;
  UEntry: TViewUnitsEntry;
Begin
  if Project1=nil then exit(mrCancel);
  Project1.UpdateIsPartOfProjectFromMainUnit;
  ViewUnitEntries := TViewUnitEntries.Create;
  UnitInfos:=nil;
  try
    for i := 0 to Project1.UnitCount-1 do
    begin
      AnUnitInfo:=Project1.Units[i];
      if (AnUnitInfo.IsPartOfProject) and (i<>Project1.MainUnitID) then
      begin
        AName := Project1.RemoveProjectPathFromFilename(AnUnitInfo.FileName);
        ViewUnitEntries.Add(AName,AnUnitInfo.FileName,i,false);
      end;
    end;
    if ShowViewUnitsDlg(ViewUnitEntries,true,lisRemoveFromProject,piUnit) <> mrOk then
      exit(mrOk);
    { This is where we check what the user selected. }
    UnitInfos:=TFPList.Create;
    for UEntry in ViewUnitEntries do
    begin
      if UEntry.Selected then
      begin
        if UEntry.ID<0 then continue;
        AnUnitInfo:=Project1.Units[UEntry.ID];
        if AnUnitInfo.IsPartOfProject then
          UnitInfos.Add(AnUnitInfo);
      end;
    end;
    if UnitInfos.Count>0 then
      Result:=RemoveFilesFromProject(UnitInfos)
    else
      Result:=mrOk;
  finally
    UnitInfos.Free;
    ViewUnitEntries.Free;
  end;
end;

function InitNewProject(ProjectDesc: TProjectDescriptor): TModalResult;
var
  i:integer;
  HandlerResult: TModalResult;
begin
  try
    Project1.BeginUpdate(true);
    try
      if Project1.CompilerOptions.CompilerPath='' then
        Project1.CompilerOptions.CompilerPath:=DefaultCompilerPath;
      if pfUseDefaultCompilerOptions in Project1.Flags then begin
        MainIDE.DoMergeDefaultProjectOptions;
        Project1.Flags:=Project1.Flags-[pfUseDefaultCompilerOptions];
      end;
      Project1.AutoAddOutputDirToIncPath;
      // call ProjectOpening handlers
      HandlerResult:=MainIDE.DoCallProjectChangedHandler(lihtProjectOpening, Project1);
      MainIDE.UpdateCaption;
      if ProjInspector<>nil then
        ProjInspector.LazProject:=Project1;
      // add and load default required packages
      PkgBoss.OpenProjectDependencies(Project1,true);
      // rebuild codetools defines
      MainBuildBoss.SetBuildTargetProject1(false);
      // (i.e. remove old project specific things and create new)
      IncreaseCompilerParseStamp;
      Project1.DefineTemplates.Active:=true;
      DebugBoss.Reset;
    finally
      Project1.EndUpdate;
    end;
    Project1.BeginUpdate(true);
    try
      // create files
      if ProjectDesc.CreateStartFiles(Project1)<>mrOk then begin
        debugln('InitNewProject ProjectDesc.CreateStartFiles failed');
      end;
      if (Project1.MainUnitInfo<>nil)
      and ((Project1.FirstUnitWithEditorIndex=nil)
       or ([pfMainUnitHasCreateFormStatements,pfMainUnitHasTitleStatement,pfMainUnitHasScaledStatement]*Project1.Flags=[]))
      then begin
        // the project has not created any secondary files
        // or the project main source is not auto updated by the IDE
        OpenMainUnit(-1,-1,[]);
      end;

      // init resource files
      if not Project1.ProjResources.Regenerate(Project1.MainFilename, True, False,'') then
        DebugLn('InitNewProject Project1.Resources.Regenerate failed');
    finally
      Project1.EndUpdate;
    end;
    Result:=mrOk;
  finally
    // set all modified to false
    Project1.UpdateAllVisibleUnits;
    for i:=0 to Project1.UnitCount-1 do
      Project1.Units[i].ClearModifieds;
    Project1.Modified:=false;
    // call ProjectOpened handlers
    HandlerResult:=MainIDE.DoCallProjectChangedHandler(lihtProjectOpened, Project1);
    if not (HandlerResult in [mrOk,mrCancel,mrAbort]) then
      HandlerResult:=mrCancel;
    if (Result=mrOk) then
      Result:=HandlerResult;
  end;
end;

function InitOpenedProjectFile(AFileName: string; Flags: TOpenFlags): TModalResult;
var
  EditorInfoIndex, i, j: Integer;
  NewBuf: TCodeBuffer;
  LastDesigner: TIDesigner;
  AnUnitInfo: TUnitInfo;
  HandlerResult: TModalResult;
  AnEditorInfo: TUnitEditorInfo;
begin
  EditorInfoIndex := 0;
  SourceEditorManager.IncUpdateLock;
  Project1.BeginUpdate(true);
  try
    // call ProjectOpening handlers
    HandlerResult:=MainIDE.DoCallProjectChangedHandler(lihtProjectOpening, Project1);
    if ProjInspector<>nil then
      ProjInspector.LazProject:=Project1;

    // read project info file
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('InitOpenedProjectFile B3');{$ENDIF}
    Project1.ReadProject(AFilename, EnvironmentOptions.BuildMatrixOptions, True);
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('InitOpenedProjectFile B4');{$ENDIF}
    Result:=CompleteLoadingProjectInfo;
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('InitOpenedProjectFile B5');{$ENDIF}
    if Result<>mrOk then exit;

    if Project1.MainUnitID>=0 then begin
      // read MainUnit Source
      Result:=LoadCodeBuffer(NewBuf,Project1.MainFilename,
                             [lbfUpdateFromDisk,lbfRevert],false);// do not check if source is text
      case Result of
      mrOk: Project1.MainUnitInfo.Source:=NewBuf;
      mrIgnore: Project1.MainUnitInfo.Source:=CodeToolBoss.CreateFile(Project1.MainFilename);
      else exit(mrCancel);
      end;
    end;
    //debugln('InitOpenedProjectFile C');
    {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('InitOpenedProjectFile C');{$ENDIF}
    IncreaseCompilerParseStamp;

    // restore files
    while EditorInfoIndex < Project1.AllEditorsInfoCount do begin
      // TProject.ReadProject sorts all UnitEditorInfos
      AnEditorInfo := Project1.AllEditorsInfo[EditorInfoIndex];
      AnUnitInfo := AnEditorInfo.UnitInfo;
      if (not AnUnitInfo.Loaded) or (AnEditorInfo.PageIndex < 0) then begin
        inc(EditorInfoIndex);
        Continue;
      end;

      // reopen file
      if (not AnUnitInfo.IsPartOfProject)
      and (not FileExistsCached(AnUnitInfo.Filename)) then begin
        // this file does not exist, but is not important => silently ignore
      end
      else begin
        // reopen file
        // This will adjust Page/WindowIndex if they are not continous
        Result:=OpenEditorFile(AnUnitInfo.Filename, -1, AnEditorInfo.WindowID,
                      AnEditorInfo, [ofProjectLoading,ofMultiOpen,ofOnlyIfExists], True);
        if Result=mrAbort then
          exit;
      end;
      if not ((AnUnitInfo.Filename<>'') and (AnEditorInfo.EditorComponent <> nil))
      then begin
        // failed to open
        AnEditorInfo.PageIndex := -1;
        // if failed entirely -> mark as unloaded, so that next time it will not be tried again
        if AnUnitInfo.OpenEditorInfoCount = 0 then
          AnUnitInfo.Loaded := False;
      end;
      inc(EditorInfoIndex);
    end; // while EditorInfoIndex < Project1.AllEditorsInfoCount
    Result:=mrCancel;
    //debugln('InitOpenedProjectFile D');

    // set active editor source editor
    for i := 0 to Project1.AllEditorsInfoCount - 1 do begin
      AnEditorInfo := Project1.AllEditorsInfo[i];
      if AnEditorInfo.IsVisibleTab then
      begin
        if (AnEditorInfo.WindowID < 0) then continue;
        j := SourceEditorManager.IndexOfSourceWindowWithID(AnEditorInfo.WindowID);
        if j < 0
        then begin
          // session info is invalid (buggy lps file?) => auto fix
          AnEditorInfo.IsVisibleTab:=false;
          AnEditorInfo.WindowID:=-1;
          Continue;
        end;
        if (SourceEditorManager.SourceWindows[j] <> nil) then
          SourceEditorManager.SourceWindows[j].PageIndex := AnEditorInfo.PageIndex;
      end;
    end;
    if (Project1.ActiveWindowIndexAtStart<0)
    or (Project1.ActiveWindowIndexAtStart >= SourceEditorManager.SourceWindowCount)
    then begin
      // session info is invalid (buggy lps file?) => auto fix
      Project1.ActiveWindowIndexAtStart := 0;
    end;
    if (Project1.ActiveWindowIndexAtStart >= 0) and
       (Project1.ActiveWindowIndexAtStart < SourceEditorManager.SourceWindowCount)
    then begin
      SourceEditorManager.ActiveSourceWindow :=
        SourceEditorManager.SourceWindows[Project1.ActiveWindowIndexAtStart];
      SourceEditorManager.ShowActiveWindowOnTop(True);
    end;

    if ([ofDoNotLoadResource]*Flags=[])
    and ( (not Project1.AutoOpenDesignerFormsDisabled)
           and EnvironmentOptions.AutoCreateFormsOnOpen
           and (SourceEditorManager.ActiveEditor<>nil) )
    then begin
      // auto open form of active unit
      AnUnitInfo:=Project1.UnitWithEditorComponent(SourceEditorManager.ActiveEditor);
      if AnUnitInfo<>nil then
        Result:=LoadLFM(AnUnitInfo,[ofProjectLoading,ofMultiOpen,ofOnlyIfExists],
                          [cfSaveDependencies]);
    end;

    // select a form (object inspector, formeditor, control selection)
    if MainIDE.LastFormActivated<>nil then begin
      LastDesigner:=MainIDE.LastFormActivated.Designer;
      debugln(['InitOpenedProjectFile select form in designer: ',
               DbgSName(MainIDE.LastFormActivated),' ',DbgSName(MainIDE.LastFormActivated.Designer)]);
      LastDesigner.SelectOnlyThisComponent(LastDesigner.LookupRoot);
    end;

    Project1.UpdateAllVisibleUnits;
    IncreaseCompilerParseStamp;
    IDEProtocolOpts.LastProjectLoadingCrashed := False;
    Result:=mrOk;
  finally
    Project1.EndUpdate;
    SourceEditorManager.DecUpdateLock;
    if (Result<>mrOk) and (Project1<>nil) then begin
      // mark all files, that are left to open as unloaded:
      for i := EditorInfoIndex to Project1.AllEditorsInfoCount - 1 do begin
        AnEditorInfo := Project1.AllEditorsInfo[i];
        AnEditorInfo.PageIndex := -1;
        AnUnitInfo := AnEditorInfo.UnitInfo;
        if AnUnitInfo.Loaded and (AnUnitInfo.OpenEditorInfoCount = 0) then
          AnUnitInfo.Loaded := false;
      end;
    end;

    // set all modified to false
    Project1.ClearModifieds(true);

    // call ProjectOpened handlers
    HandlerResult:=MainIDE.DoCallProjectChangedHandler(lihtProjectOpened, Project1);
    if not (HandlerResult in [mrOk,mrCancel,mrAbort]) then
      HandlerResult:=mrCancel;
    if (Result=mrOk) then
      Result:=HandlerResult;
  end;
  if Result=mrAbort then exit;
  //debugln('InitOpenedProjectFile end  CodeToolBoss.ConsistencyCheck=',IntToStr(CodeToolBoss.ConsistencyCheck));
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('InitOpenedProjectFile end');{$ENDIF}
end;

procedure NewProjectFromFile;
var
  OpenDialog:TOpenDialog;
  AFilename: string;
  PreReadBuf: TCodeBuffer;
  Filter: String;
Begin
  OpenDialog:=IDEOpenDialogClass.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(OpenDialog);
    OpenDialog.Title:=lisChooseProgramSourcePpPasLpr;
    OpenDialog.Options:=OpenDialog.Options+[ofPathMustExist,ofFileMustExist];
    Filter := dlgFilterLazarusUnit + ' (*.pas;*.pp;*.p)|*.pas;*.pp;*.p'
      + '|' + dlgFilterLazarusProjectSource + ' (*.lpr)|*.lpr';
    Filter:=Filter+ '|' + dlgFilterAll + ' (' + GetAllFilesMask + ')|' + GetAllFilesMask;
    OpenDialog.Filter := Filter;
    if OpenDialog.Execute then begin
      AFilename:=ExpandFileNameUTF8(OpenDialog.Filename);
      if not FilenameIsPascalSource(AFilename) then begin
        IDEMessageDialog(lisPkgMangInvalidFileExtension,
          lisProgramSourceMustHaveAPascalExtensionLikePasPpOrLp,
          mtError,[mbOk],'');
        exit;
      end;
      if (LoadCodeBuffer(PreReadBuf,AFileName,
                       [lbfCheckIfText,lbfUpdateFromDisk,lbfRevert],false)<>mrOk)
      or (CreateProjectForProgram(PreReadBuf)=mrOk) then
        exit;
    end;
  finally
    InputHistories.StoreFileDialogSettings(OpenDialog);
    OpenDialog.Free;
  end;
end;

function CreateProjectForProgram(ProgramBuf: TCodeBuffer): TModalResult;
var
  NewProjectDesc: TProjectDescriptor;
begin
  //debugln('[CreateProjectForProgram] A ',ProgramBuf.Filename);
  if (Project1 <> nil)
  and (not MainIDE.DoResetToolStatus([rfInteractive, rfSuccessOnTrigger])) then exit(mrAbort);

  Result:=SaveProjectIfChanged;
  if Result=mrAbort then exit;

  // let user choose the program type
  NewProjectDesc:=nil;
  if ChooseNewProject(NewProjectDesc)<>mrOk then exit;

  // close old project
  If Project1<>nil then begin
    if CloseProject=mrAbort then begin
      Result:=mrAbort;
      exit;
    end;
  end;

  // reload file (if the file was open in the IDE, closeproject unloaded it)
  ProgramBuf.Reload;

  // switch codetools to new project directory
  CodeToolBoss.GlobalValues.Variables[ExternalMacroStart+'ProjPath']:=
    ExpandFileNameUTF8(ExtractFilePath(ProgramBuf.Filename));

  // create a new project
  Project1:=MainIDE.CreateProjectObject(NewProjectDesc,ProjectDescriptorProgram);
  Result:=InitProjectForProgram(ProgramBuf);
  //debugln('[CreateProjectForProgram] END');
end;

function InitProjectForProgram(ProgramBuf: TCodeBuffer): TModalResult;
var
  MainUnitInfo: TUnitInfo;
begin
  Project1.BeginUpdate(true);
  try
    if ProjInspector<>nil then
      ProjInspector.LazProject:=Project1;
    MainUnitInfo:=Project1.MainUnitInfo;
    MainUnitInfo.Source:=ProgramBuf;
    Project1.ProjectInfoFile:=ChangeFileExt(ProgramBuf.Filename,'.lpi');
    Project1.CompilerOptions.TargetFilename:=ExtractFileNameOnly(ProgramBuf.Filename);
    MainIDE.DoMergeDefaultProjectOptions;
    MainIDE.UpdateCaption;
    IncreaseCompilerParseStamp;
    // add and load default required packages
    PkgBoss.OpenProjectDependencies(Project1,true);
    Result:=CompleteLoadingProjectInfo;
    if Result<>mrOk then exit;
  finally
    Project1.EndUpdate;
  end;
  // show program unit
  Result:=OpenEditorFile(ProgramBuf.Filename,-1,-1, nil, [ofAddToRecent,ofRegularFile]);
  if Result=mrAbort then exit;
  Result:=mrOk;
end;

function SaveProject(Flags: TSaveFlags):TModalResult;
var
  i, j: integer;
  AnUnitInfo: TUnitInfo;
  SaveFileFlags: TSaveFlags;
  SrcEdit: TSourceEditor;
begin
  Result:=mrCancel;
  if not (MainIDE.ToolStatus in [itNone,itDebugger]) then begin
    Result:=mrAbort;
    exit;
  end;
  SaveEditorChangesToCodeCache(nil);
  //DebugLn('SaveProject A SaveAs=',dbgs(sfSaveAs in Flags),' SaveToTestDir=',dbgs(sfSaveToTestDir in Flags),' ProjectInfoFile=',Project1.ProjectInfoFile);
  Result:=MainIDE.DoCheckFilesOnDisk(true);
  if Result in [mrCancel,mrAbort] then begin
    debugln(['Info: (lazarus) [SaveProject] MainIDE.DoCheckFilesOnDisk failed']);
    exit;
  end;

  if CheckMainSrcLCLInterfaces(sfQuietUnitCheck in Flags)<>mrOk then begin
    debugln(['Info: (lazarus) [SaveProject] CheckMainSrcLCLInterfaces failed']);
    exit(mrCancel);
  end;

  // if this is a virtual project then save first the project info file
  // to get a project directory
  if Project1.IsVirtual and ([sfSaveToTestDir,sfDoNotSaveVirtualFiles]*Flags=[])
  then begin
    Result:=SaveProjectInfo(Flags);
    if Result in [mrCancel,mrAbort] then begin
      debugln(['Info: (lazarus) [SaveProject] SaveProjectInfo failed']);
      exit;
    end;
  end;

  // save virtual files
  if (not (sfDoNotSaveVirtualFiles in Flags)) then
  begin
    // check that all new units are saved first to get valid filenames
    // Note: this can alter the mainunit: e.g. used unit names
    for i:=0 to Project1.UnitCount-1 do begin
      AnUnitInfo:=Project1.Units[i];
      if (AnUnitInfo.Loaded) and AnUnitInfo.IsVirtual
      and AnUnitInfo.IsPartOfProject
      and (Project1.MainUnitID<>i)
      and (AnUnitInfo.OpenEditorInfoCount > 0) then begin
        SaveFileFlags:=[sfSaveAs,sfProjectSaving]+[sfCheckAmbiguousFiles]*Flags;
        if sfSaveToTestDir in Flags then begin
          Assert(AnUnitInfo.IsPartOfProject or AnUnitInfo.IsVirtual, 'SaveProject: Not IsPartOfProject or IsVirtual');
          Include(SaveFileFlags,sfSaveToTestDir);
        end;
        Result:=SaveEditorFile(AnUnitInfo.OpenEditorInfo[0].EditorComponent, SaveFileFlags);
        if Result in [mrCancel,mrAbort] then begin
          debugln(['Info: (lazarus) [SaveProject] SaveEditorFile "',AnUnitInfo.Filename,'" failed']);
          exit;
        end;
      end;
    end;
  end;

  Result:=SaveProjectInfo(Flags);
  if Result in [mrCancel,mrAbort] then begin
    debugln(['Info: (lazarus) [SaveProject] SaveProjectInfo failed']);
    exit;
  end;

  // save all editor files
  for i:=0 to SourceEditorManager.SourceEditorCount-1 do begin
    SrcEdit:=SourceEditorManager.SourceEditors[i];
    AnUnitInfo:=Project1.UnitWithEditorComponent(SrcEdit);
    if (Project1.MainUnitID>=0) and (Project1.MainUnitInfo = AnUnitInfo) then
      continue;
    SaveFileFlags:=[sfProjectSaving]+Flags*[sfCheckAmbiguousFiles];
    if AnUnitInfo = nil
    then begin
      // inconsistency detected, write debug info
      DebugLn(['SaveProject - unit not found for page ',i,' File="',SrcEdit.FileName,'" SrcEdit=',dbgsname(SrcEdit),'=',dbgs(Pointer(SrcEdit))]);
      DumpStack;
      debugln(['SaveProject Project1 has the following information about the source editor:']);
      AnUnitInfo:=Project1.FirstUnitWithEditorIndex;
      while AnUnitInfo<>nil do begin
        for j:=0 to AnUnitInfo.EditorInfoCount-1 do begin
          dbgout(['  ',AnUnitInfo.Filename,' ',j,'/',AnUnitInfo.EditorInfoCount,' Component=',dbgsname(AnUnitInfo.EditorInfo[j].EditorComponent),'=',dbgs(Pointer(AnUnitInfo.EditorInfo[j].EditorComponent))]);
          if AnUnitInfo.EditorInfo[j].EditorComponent<>nil then
            dbgout(AnUnitInfo.EditorInfo[j].EditorComponent.FileName);
          debugln;
        end;
        debugln(['  ',AnUnitInfo.EditorInfoCount]);
        AnUnitInfo:=AnUnitInfo.NextUnitWithEditorIndex;
      end;
    end else begin
      if AnUnitInfo.IsVirtual then begin
        if (sfSaveToTestDir in Flags) then
          Include(SaveFileFlags,sfSaveToTestDir)
        else
          continue;
      end;
    end;
    Result:=SaveEditorFile(SrcEdit, SaveFileFlags);
    if Result=mrAbort then begin
      debugln(['Info: (lazarus) [SaveProject] SaveEditorFile "',SrcEdit.FileName,'" failed']);
      exit;
    end;
    // mrCancel: continue saving other files
  end;

  // update all lrs files
  if sfSaveToTestDir in Flags then
    MainBuildBoss.UpdateProjectAutomaticFiles(EnvironmentOptions.GetParsedTestBuildDirectory)
  else
    MainBuildBoss.UpdateProjectAutomaticFiles('');

  // everything went well => clear all modified flags
  Project1.ClearModifieds(true);
  // update menu and buttons state
  MainIDE.UpdateSaveMenuItemsAndButtons(true);
  //DebugLn('SaveProject End');
  Result:=mrOk;
end;

function SaveProjectIfChanged: TModalResult;
begin
  if SomethingOfProjectIsModified then begin
    if IDEMessageDialog(lisProjectChanged, Format(lisSaveChangesToProject,
      [Project1.GetTitleOrName]),
      mtconfirmation, [mbYes, mbNo, mbCancel])=mrYes then
    begin
      if SaveProject([])=mrAbort then begin
        Result:=mrAbort;
        exit;
      end;
    end;
  end;
  Result:=mrOk;
end;

function CloseProject: TModalResult;
var
  SrcEdit: TSourceEditor;
begin
  if Project1=nil then exit(mrOk);

  //debugln('CloseProject A');
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('CloseProject A');{$ENDIF}
  Result:=DebugBoss.DoStopProject;
  if Result<>mrOk then begin
    debugln('CloseProject DebugBoss.DoStopProject failed');
    exit;
  end;

  // call handlers
  Result:=MainIDE.DoCallProjectChangedHandler(lihtProjectClose, Project1);
  if Result=mrAbort then exit;

    // close all loaded files
  SourceEditorManager.IncUpdateLock;
  try
    while SourceEditorManager.SourceEditorCount > 0 do begin
      SrcEdit:=SourceEditorManager.SourceEditors[SourceEditorManager.SourceEditorCount-1];
      Result:=CloseEditorFile(SrcEdit,[cfProjectClosing]);
      if Result=mrAbort then exit;
    end;
  finally
    SourceEditorManager.DecUpdateLock;
  end;
  // remove all source modifications
  CodeToolBoss.SourceCache.ClearAllModified;

  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('CloseProject B');{$ENDIF}
  IncreaseCompilerParseStamp;

  // close Project
  if ProjInspector<>nil then
    ProjInspector.LazProject:=nil;
  FreeThenNil(Project1);
  if IDEMessagesWindow<>nil then IDEMessagesWindow.Clear;

  MainIDE.UpdateCaption;
  {$IFDEF IDE_MEM_CHECK}CheckHeapWrtMemCnt('CloseProject C');{$ENDIF}
  Result:=mrOk;
  //debugln('CloseProject end ',CodeToolBoss.ConsistencyCheck);
end;

procedure OpenProject(aMenuItem: TIDEMenuItem);
var
  OpenDialog: TOpenDialog;
  AFileName: string;
  LoadFlags: TLoadBufferFlags;
  PreReadBuf: TCodeBuffer;
  SourceType: String;
  LPIFilename: String;
begin
  if Assigned(aMenuItem) and (aMenuItem.Section=itmProjectRecentOpen) then
  begin
    // Hint holds the full filename, Caption may have a shortened form.
    AFileName:=aMenuItem.Hint;
    Assert(AFileName = ExpandFileNameUTF8(AFileName),'OpenProject: AFileName is not absolute.');
    if MainIDE.DoOpenProjectFile(AFilename,[ofAddToRecent])=mrOk then begin
      AddRecentProjectFile(AFilename);
    end else begin
      // open failed
      if not FileExistsCached(AFilename) then begin
        EnvironmentOptions.RemoveFromRecentProjectFiles(AFilename);
      end else
        AddRecentProjectFile(AFilename);
    end;
  end
  else begin
    OpenDialog:=IDEOpenDialogClass.Create(nil);
    try
      InputHistories.ApplyFileDialogSettings(OpenDialog);
      OpenDialog.Title:=lisOpenProjectFile+' (*.lpi)';
      OpenDialog.Filter := dlgFilterLazarusProject+' (*.lpi)|*.lpi|'
                          +dlgFilterAll+'|'+GetAllFilesMask;
      if OpenDialog.Execute then begin
        AFilename:=GetPhysicalFilenameCached(ExpandFileNameUTF8(OpenDialog.Filename),false);
        if not FilenameExtIs(AFilename,'lpi',true) then begin
          // not a lpi file
          // check if it is a program source

          // load the source
          LoadFlags := [lbfCheckIfText,lbfUpdateFromDisk,lbfRevert];
          if LoadCodeBuffer(PreReadBuf,AFileName,LoadFlags,true)<>mrOk then exit;

          // check if unit is a program
          SourceType:=CodeToolBoss.GetSourceType(PreReadBuf,false);
          if (SysUtils.CompareText(SourceType,'PROGRAM')=0)
          or (SysUtils.CompareText(SourceType,'LIBRARY')=0)
          then begin
            // source is a program
            // either this is a lazarus project
            // or it is not yet a lazarus project ;)
            LPIFilename:=ChangeFileExt(AFilename,'.lpi');
            if FileExistsCached(LPIFilename) then begin
              if IDEQuestionDialog(lisProjectInfoFileDetected,
                  Format(lisTheFileSeemsToBeTheProgramFileOfAnExistingLazarusP, [AFilename]),
                  mtConfirmation, [mrOk,lisOpenProject2,
                                   mrCancel]) <> mrOk
              then
                exit;
              AFilename:=LPIFilename;
            end else begin
              if IDEQuestionDialog(lisFileHasNoProject,
                Format(lisTheFileIsNotALazarusProjectCreateANewProjectForThi,
                       [AFilename, LineEnding, lowercase(SourceType)]),
                mtConfirmation, [mrYes, lisCreateProject,
                                 mrCancel]) <> mrYes
              then
                exit;
              CreateProjectForProgram(PreReadBuf);
              exit;
            end;
          end;
        end;
        MainIDE.DoOpenProjectFile(AFilename,[ofAddToRecent]);
      end;
      InputHistories.StoreFileDialogSettings(OpenDialog);
    finally
      OpenDialog.Free;
    end;
  end;
end;

function AskToSaveEditors(EditorList: TList): TModalResult;
// Ask from user about saving the changed SourceEditors in EditorList.
var
  Ed: TSourceEditor;
  r: TModalResult;
  i, Remain: Integer;
begin
  Result := mrOK;
  if EditorList.Count = 1 then begin
    Ed := TSourceEditor(EditorList[0]);
    r := IDEQuestionDialog(lisSourceModified,
           Format(lisSourceOfPageHasChangedSave, [Ed.PageName]),
           mtConfirmation, [mrYes, lisMenuSave,
                            mrNo, lisDiscardChanges,
                            mrAbort]);
    case r of
      mrYes: SaveEditorFile(Ed, [sfCheckAmbiguousFiles]);
      mrNo: ; // don't save
      mrAbort, mrCancel:  Result := mrAbort;
    end;
  end
  else if EditorList.Count > 1 then
    for i := 0 to EditorList.Count - 1 do begin
      Ed := TSourceEditor(EditorList[i]);
      Remain := EditorList.Count-i-1;    // Remaining number of files to go.
      r := IDEQuestionDialog(lisSourceModified,
            Format(lisSourceOfPageHasChangedSaveEx, [Ed.PageName,Remain]),
            mtConfirmation, [mrYes, lisMenuSave,
                             mrAll, lisSaveAll,
                             mrNo, lisDiscardChanges,
                             mrIgnore, lisDiscardChangesAll,
                             mrAbort]);
      case r of
        mrYes: SaveEditorFile(Ed, [sfCheckAmbiguousFiles]);
        mrNo: ; // don't save
        mrAll: begin
            MainIDE.DoSaveAll([]);
            break;
          end;
        mrIgnore: break; // don't save anymore
        mrAbort, mrCancel: begin
            Result := mrAbort;
            break;
          end;
      end;
    end;
end;

procedure CloseAll;
// Close editor files
var
  Ed: TSourceEditor;
  EditorList: TList;
  i: Integer;
begin
  EditorList := TList.Create;
  try
    // Collect changed editors into a list and save them after asking from user.
    for i := 0 to SourceEditorManager.UniqueSourceEditorCount - 1 do
    begin
      Ed := TSourceEditor(SourceEditorManager.UniqueSourceEditors[i]);
      if CheckEditorNeedsSave(Ed, False) then
        EditorList.Add(Ed);
    end;
    if AskToSaveEditors(EditorList) <> mrOK then Exit;
  finally
    EditorList.Free;
  end;
  // Now close them all.
  SourceEditorManager.IncUpdateLock;
  try
    while (SourceEditorManager.SourceEditorCount > 0) and
      (CloseEditorFile(SourceEditorManager.SourceEditors[0], []) = mrOk)
    do ;
  finally
    SourceEditorManager.DecUpdateLock;
  end;

  // Close packages
  PkgBoss.DoCloseAllPackageEditors;
end;

procedure InvertedFileClose(PageIndex: LongInt; SrcNoteBook: TSourceNotebook;
  CloseOnRightSideOnly: Boolean);
// close all source editors except the clicked
var
  Ed: TSourceEditor;
  EditorList: TList;
  i: Integer;
begin
  EditorList := TList.Create;
  try
    // Collect changed editors, except the active one, into a list and maybe save them.
    for i := 0 to SrcNoteBook.EditorCount - 1 do begin
      Ed := SrcNoteBook.Editors[i];
      if ( (i > PageIndex) or // to right
           ( (i <> PageIndex) and not CloseOnRightSideOnly )
         ) and
         CheckEditorNeedsSave(Ed, True)
      then
        EditorList.Add(Ed);
    end;
    if AskToSaveEditors(EditorList) <> mrOK then Exit;
  finally
    EditorList.Free;
  end;
  // Now close all editors except the active one.
  SourceEditorManager.IncUpdateLock;
  try
    repeat
      i:=SrcNoteBook.PageCount-1;
      if i=PageIndex then
        if CloseOnRightSideOnly then
          break
        else
          dec(i);
      if i<0 then break;
      if CloseEditorFile(SrcNoteBook.FindSourceEditorWithPageIndex(i),[])<>mrOk then exit;
      if i<PageIndex then PageIndex:=i;
    until false;
  finally
    SourceEditorManager.DecUpdateLock;
  end;
end;

function UpdateAppTitleInSource: Boolean;
var
  TitleProject, ErrMsg: String;
begin
  Result := True;
  if not (pfMainUnitHasTitleStatement in Project1.Flags) then Exit;
  TitleProject := Project1.GetTitle;
  //DebugLn(['UpdateAppTitleInSource: Project title=',TitleProject,', Default=',Project1.GetDefaultTitle]);
  if (TitleProject <> Project1.GetDefaultTitle) then
  begin        // Add or update Title statement.
    //DebugLn(['UpdateAppTitleInSource: Setting Title to ',TitleProject]);
    Result := CodeToolBoss.SetApplicationTitleStatement(Project1.MainUnitInfo.Source, TitleProject);
    ErrMsg := lisUnableToChangeProjectTitleInSource; // Used in case of error.
  end
  else begin   // Remove Title statement if it's not needed.
    //DebugLn(['UpdateAppTitleInSource: Removing Title']);
    Result := CodeToolBoss.RemoveApplicationTitleStatement(Project1.MainUnitInfo.Source);
    ErrMsg := lisUnableToRemoveProjectTitleFromSource;
  end;
  if not Result then
    IDEMessageDialog(lisProjOptsError,
                     Format(ErrMsg, [LineEnding, CodeToolBoss.ErrorMessage]),
                     mtWarning, [mbOk]);
end;

function UpdateAppScaledInSource: Boolean;
var
  ErrMsg: String;
begin
  Result := True;
  if not (pfMainUnitHasScaledStatement in Project1.Flags) then Exit;
  //DebugLn(['UpdateAppScaledInSource: Project Scaled=',Project1.Scaled]);
  if Project1.Scaled then
  begin        // Add or update Scaled statement.
    //DebugLn(['UpdateAppScaledInSource: Setting Scaled to ',Project1.Scaled]);
    Result := CodeToolBoss.SetApplicationScaledStatement(Project1.MainUnitInfo.Source, Project1.Scaled);
    ErrMsg := lisUnableToChangeProjectScaledInSource; // Used in case of error.
  end
  else begin   // Remove Scaled statement if it's not needed.
    //DebugLn(['UpdateAppScaledInSource: Removing Scaled']);
    Result := CodeToolBoss.RemoveApplicationScaledStatement(Project1.MainUnitInfo.Source);
    ErrMsg := lisUnableToRemoveProjectScaledFromSource;
  end;
  if not Result then
    IDEMessageDialog(lisProjOptsError,
                     Format(ErrMsg, [LineEnding, CodeToolBoss.ErrorMessage]),
                     mtWarning, [mbOk]);
end;

function UpdateAppAutoCreateForms: boolean;
var
  i: integer;
  OldList: TStrings;
begin
  Result := True;
  if not (pfMainUnitHasCreateFormStatements in Project1.Flags) then Exit;
  OldList := Project1.GetAutoCreatedFormsList;
  if OldList = nil then Exit;
  try
    if OldList.Count = Project1.TmpAutoCreatedForms.Count then
    begin
      i := OldList.Count - 1;
      while (i >= 0)
      and (CompareText(OldList[i], Project1.TmpAutoCreatedForms[i]) = 0) do
        Dec(i);
      if i < 0 then
        Exit;                  // Just exit if the form list is the same
    end;
    if not CodeToolBoss.SetAllCreateFromStatements(Project1.MainUnitInfo.Source,
      Project1.TmpAutoCreatedForms) then
    begin
      IDEMessageDialog(lisProjOptsError,
        Format(lisProjOptsUnableToChangeTheAutoCreateFormList, [LineEnding]),
        mtWarning, [mbOK]);
      Result := False;
      Exit;
    end;
  finally
    OldList.Free;
  end;
end;

function CreateNewCodeBuffer(Descriptor: TProjectFileDescriptor;
  NewOwner: TObject; NewFilename: string;
  var NewCodeBuffer: TCodeBuffer; var NewUnitName: string): TModalResult;
var
  NewShortFilename: String;
  NewFileExt: String;
  SearchFlags: TSearchIDEFileFlags;
begin
  //debugln('CreateNewCodeBuffer START NewFilename=',NewFilename,' ',Descriptor.DefaultFilename,' ',Descriptor.ClassName);
  NewUnitName:='';
  NewCodeBuffer:=nil;
  if NewFilename='' then begin
    // create a new unique filename
    SearchFlags:=[siffCheckAllProjects];
    if Descriptor.IsPascalUnit then begin
      if NewUnitName='' then
        NewUnitName:=Descriptor.DefaultSourceName;
      NewShortFilename:=lowercase(NewUnitName);
      NewFileExt:=Descriptor.DefaultFileExt;
      SearchFlags:=SearchFlags+[siffIgnoreExtension];
    end else begin
      NewFilename:=ExtractFilename(Descriptor.DefaultFilename);
      NewShortFilename:=ExtractFilenameOnly(NewFilename);
      NewFileExt:=ExtractFileExt(NewFilename);
      SearchFlags:=[];
    end;
    NewFilename:=MainIDE.CreateNewUniqueFilename(NewShortFilename,
                                           NewFileExt,NewOwner,SearchFlags,true);
    if NewFilename='' then
      RaiseGDBException('');
    NewShortFilename:=ExtractFilenameOnly(NewFilename);
    // use as unitname the NewShortFilename, but with the case of the
    // original unitname. e.g. 'unit12.pas' becomes 'Unit12.pas'
    if Descriptor.IsPascalUnit then begin
      NewUnitName:=ChompEndNumber(NewUnitName);
      NewUnitName:=NewUnitName+copy(NewShortFilename,length(NewUnitName)+1,
                                    length(NewShortFilename));
    end;
  end;
  //debugln('CreateNewCodeBuffer NewFilename=',NewFilename,' NewUnitName=',NewUnitName);

  if FilenameIsPascalUnit(NewFilename) then begin
    if NewUnitName='' then
      NewUnitName:=ExtractFileNameOnly(NewFilename);
    if EnvironmentOptions.CharcaseFileAction in [ccfaAsk, ccfaAutoRename] then
      NewFilename:=ExtractFilePath(NewFilename)+lowercase(ExtractFileName(NewFilename));
  end;

  NewCodeBuffer:=CodeToolBoss.CreateFile(NewFilename);
  if NewCodeBuffer=nil then
    exit(mrCancel);
  Result:=mrOk;
end;

function CreateNewForm(NewUnitInfo: TUnitInfo;
  AncestorType: TPersistentClass; ResourceCode: TCodeBuffer;
  UseCreateFormStatements, DisableAutoSize: Boolean): TModalResult;
var
  NewComponent: TComponent;
  new_x, new_y: integer;
  MainIDEBarBottom: integer;
  r: TRect;
begin
  if not AncestorType.InheritsFrom(TComponent) then
    RaiseGDBException('CreateNewForm invalid AncestorType');

  //debugln('CreateNewForm START ',NewUnitInfo.Filename,' ',AncestorType.ClassName,' ',dbgs(ResourceCode<>nil));
  // create a buffer for the new resource file and for the LFM file
  if ResourceCode=nil then
    ResourceCode:=CodeToolBoss.CreateFile(ChangeFileExt(NewUnitInfo.Filename,
                                                        ResourceFileExt));
  //debugln('CreateNewForm B ',ResourceCode.Filename);
  ResourceCode.Source:='{ '+LRSComment+' }';
  CodeToolBoss.CreateFile(ChangeFileExt(NewUnitInfo.Filename,'.lfm'));

  // clear formeditor
  FormEditor1.ClearSelection;

  // Figure out where we want to put the new form
  // if there is more place left of the OI put it left, otherwise right
  if ObjectInspector1<>nil then begin
    new_x:=ObjectInspector1.Left+10;
    new_y:=ObjectInspector1.Top+10;
  end else begin
    new_x:=200;
    new_y:=100;
  end;
  if new_x>Screen.Width div 2 then
    new_x:=new_x-500
  else if ObjectInspector1<>nil then
    new_x:=new_x + ObjectInspector1.Width + GetSystemMetrics(SM_CXFRAME) shl 1;
  if Assigned(MainIDEBar) then
  begin
    MainIDEBarBottom:=MainIDEBar.Top+MainIDEBar.Height+GetSystemMetrics(SM_CYFRAME) shl 1
                                                      +GetSystemMetrics(SM_CYCAPTION);
    if MainIDEBarBottom < Screen.Height div 2 then
      new_y:=Max(new_y,MainIDEBarBottom+10);
  end;
  r:=Screen.PrimaryMonitor.WorkareaRect;
  new_x:=Max(r.Left,Min(new_x,r.Right-400));
  new_y:=Max(r.Top,Min(new_y,r.Bottom-400));

  // create jit component
  NewComponent := FormEditor1.CreateComponent(nil,TComponentClass(AncestorType),
      NewUnitInfo.CreateUnitName, new_x, new_y, 0,0,DisableAutoSize);
  if NewComponent=nil then begin
    DebugLn(['CreateNewForm FormEditor1.CreateComponent failed ',dbgsName(TComponentClass(AncestorType))]);
    exit(mrCancel);
  end;
  FormEditor1.SetComponentNameAndClass(NewComponent,
    NewUnitInfo.ComponentName,'T'+NewUnitInfo.ComponentName);
  if NewComponent is TCustomForm then
    TControl(NewComponent).Visible := False;
  if (NewComponent is TControl)
  and (csSetCaption in TControl(NewComponent).ControlStyle) then
    TControl(NewComponent).Caption:=NewComponent.Name;
  NewUnitInfo.Component := NewComponent;
  MainIDE.CreateDesignerForComponent(NewUnitInfo,NewComponent);
  if NewComponent is TCustomDesignControl then
  begin
    TCustomDesignControl(NewComponent).DesignTimePPI := Screen.PixelsPerInch;
    TCustomDesignControl(NewComponent).PixelsPerInch := Screen.PixelsPerInch;
  end;

  NewUnitInfo.ComponentName:=NewComponent.Name;
  NewUnitInfo.ComponentResourceName:=NewUnitInfo.ComponentName;
  if UseCreateFormStatements
  and ((NewComponent is TCustomForm) or (NewComponent is TDataModule))
  and NewUnitInfo.IsPartOfProject
  and Project1.AutoCreateForms
  and (pfMainUnitHasCreateFormStatements in Project1.Flags) then
  begin
    Project1.AddCreateFormToProjectFile(NewComponent.ClassName,
                                        NewComponent.Name);
  end;
  Result:=mrOk;
end;

function NewUniqueComponentName(Prefix: string): string;

  function SearchProject(AProject: TProject; const Identifier: string): boolean;
  var
    i: Integer;
    AnUnitInfo: TUnitInfo;
  begin
    if AProject=nil then exit(false);
    Result:=true;
    for i:=0 to AProject.UnitCount-1 do
    begin
      AnUnitInfo:=AProject.Units[i];
      if (AnUnitInfo.Component<>nil) then begin
        if CompareText(AnUnitInfo.Component.Name,Identifier)=0 then exit;
        if CompareText(AnUnitInfo.Component.ClassName,Identifier)=0 then exit;
      end else if (AnUnitInfo.ComponentName<>'')
      and ((AnUnitInfo.IsPartOfProject) or AnUnitInfo.Loaded) then begin
        if SysUtils.CompareText(AnUnitInfo.Unit_Name,Identifier)=0 then exit;
        if SysUtils.CompareText(AnUnitInfo.ComponentName,Identifier)=0 then exit;
      end;
    end;
    Result:=false;
  end;

  function SearchPackage(APackage: TLazPackage; const Identifier: string): boolean;
  var
    i: Integer;
    PkgFile: TPkgFile;
  begin
    if APackage=nil then exit(false);
    Result:=true;
    if SysUtils.CompareText(APackage.Name,Identifier)=0 then exit;
    for i:=0 to APackage.FileCount-1 do
    begin
      PkgFile:=APackage.Files[i];
      if SysUtils.CompareText(PkgFile.Unit_Name,Identifier)=0 then exit;
    end;
    Result:=false;
  end;

  function IdentifierExists(Identifier: string): boolean;
  var
    i: Integer;
  begin
    Result:=true;
    if GetClass(Identifier)<>nil then exit;
    if SearchProject(Project1,Identifier) then exit;
    for i:=0 to PackageGraph.Count-1 do
      if SearchPackage(PackageGraph[i],Identifier) then exit;
    Result:=false;
  end;

  function IdentifierIsOk(Identifier: string): boolean;
  begin
    Result:=false;
    if not IsValidIdent(Identifier) then exit;
    if AllKeyWords.DoIdentifier(PChar(Identifier)) then exit;
    if IdentifierExists(Identifier) then exit;
    if IdentifierExists('T'+Identifier) then exit;
    Result:=true;
  end;

var
  i: Integer;
begin
  if IdentifierIsOk(Prefix) then
    exit(Prefix);
  while (Prefix<>'') and (Prefix[length(Prefix)] in ['0'..'9']) do
    System.Delete(Prefix,length(Prefix),1);
  if not IsValidIdent(Prefix) then
    Prefix:='Resource';
  i:=0;
  repeat
    inc(i);
    Result:=Prefix+IntToStr(i);
  until IdentifierIsOk(Result);
end;

function ShowSaveFileAsDialog(var AFilename: string; AnUnitInfo: TUnitInfo;
  var LFMCode, LRSCode: TCodeBuffer; CanAbort: boolean): TModalResult;
var
  SaveDialog: TSaveDialog;
  SrcEdit: TSourceEditor;
  SaveAsFilename, SaveAsFileExt: string;
  NewFilename, NewFileExt: string;
  OldUnitName, NewUnitName: string;
  ACaption, AText, APath: string;
  Filter, AllEditorExt, AllFilter: string;
begin
  if (AnUnitInfo<>nil) and (AnUnitInfo.OpenEditorInfoCount>0) then
    SrcEdit := TSourceEditor(AnUnitInfo.OpenEditorInfo[0].EditorComponent)
  else
    SrcEdit:=nil;
  //debugln('ShowSaveFileAsDialog ',AnUnitInfo.Filename);

  // try to keep the old filename and extension
  SaveAsFileExt:=ExtractFileExt(AFileName);
  if (SaveAsFileExt='') and (SrcEdit<>nil) then begin
    if (SrcEdit.SyntaxHighlighterType in [lshFreePascal, lshDelphi]) then
      SaveAsFileExt:=PascalExtension[EnvironmentOptions.PascalFileExtension]
    else
      SaveAsFileExt:=EditorOpts.HighlighterList.GetDefaultFilextension(
                         SrcEdit.SyntaxHighlighterType);
  end;
  if FilenameIsPascalSource(AFilename) then begin
    if AnUnitInfo<>nil then
      OldUnitName:=AnUnitInfo.ReadUnitNameFromSource(false)
    else
      OldUnitName:=ExtractFileNameOnly(AFilename);
  end else
    OldUnitName:='';
  //debugln('ShowSaveFileAsDialog sourceunitname=',OldUnitName);
  SaveAsFilename:=OldUnitName;
  if SaveAsFilename='' then
    SaveAsFilename:=ExtractFileNameOnly(AFilename);
  if SaveAsFilename='' then
    SaveAsFilename:=lisnoname;

  //suggest lowercased name if user wants so
  if EnvironmentOptions.LowercaseDefaultFilename = true then
    SaveAsFilename:=LowerCase(SaveAsFilename);

  // let user choose a filename
  SaveDialog:=IDESaveDialogClass.Create(nil);
  try
    InputHistories.ApplyFileDialogSettings(SaveDialog);
    SaveDialog.Title:=lisSaveSpace+SaveAsFilename+' (*'+SaveAsFileExt+')';
    SaveDialog.FileName:=SaveAsFilename+SaveAsFileExt;

    Filter := dlgFilterLazarusUnit + ' (*.pas;*.pp)|*.pas;*.pp';
    if (SaveAsFileExt='.lpi') then
      Filter:=Filter+ '|' + dlgFilterLazarusProject + ' (*.lpi)|*.lpi';
    if (SaveAsFileExt='.lfm') or (SaveAsFileExt='.dfm') then
      Filter:=Filter+ '|' + dlgFilterLazarusForm + ' (*.lfm;*.dfm)|*.lfm;*.dfm';
    if (SaveAsFileExt='.lpk') then
      Filter:=Filter+ '|' + dlgFilterLazarusPackage + ' (*.lpk)|*.lpk';
    if (SaveAsFileExt='.lpr') then
      Filter:=Filter+ '|' + dlgFilterLazarusProjectSource + ' (*.lpr)|*.lpr';
    // append a filter for all editor files
    CreateFileDialogFilterForSourceEditorFiles(Filter,AllEditorExt,AllFilter);
    if AllEditorExt<>'' then
      Filter:=Filter+ '|' + dlgFilterLazarusEditorFile + ' (' + AllEditorExt + ')|' + AllEditorExt;

    // append an any file filter *.*
    Filter:=Filter+ '|' + dlgFilterAll + ' (' + GetAllFilesMask + ')|' + GetAllFilesMask;

    // prepend an all filter
    Filter:=  dlgFilterLazarusFile + ' ('+AllFilter+')|' + AllFilter + '|' + Filter;
    SaveDialog.Filter := Filter;

    // if this is a project file, start in project directory
    if (AnUnitInfo=nil)
    or (AnUnitInfo.IsPartOfProject and (not Project1.IsVirtual)
        and (not PathIsInPath(SaveDialog.InitialDir,Project1.Directory)))
    then begin
      SaveDialog.InitialDir:=Project1.Directory;
    end;
    // if this is a package file, then start in package directory
    APath:=PkgBoss.GetDefaultSaveDirectoryForFile(AFilename);
    if (APath<>'') and (not PathIsInPath(SaveDialog.InitialDir,APath)) then
      SaveDialog.InitialDir:=APath;

    repeat
      Result:=mrCancel;
      // show save dialog
      if (not SaveDialog.Execute) or (ExtractFileName(SaveDialog.Filename)='') then
        exit;  // user cancels
      NewFilename:=ExpandFileNameUTF8(SaveDialog.Filename);

      // check file extension
      NewFileExt:=ExtractFileExt(NewFilename);
      if NewFileExt='' then begin
        NewFileExt:=SaveAsFileExt;
        NewFilename:=NewFilename+SaveAsFileExt;
      end;

      // check file path
      APath:=ExtractFilePath(NewFilename);
      if not DirPathExists(APath) then begin
        ACaption:=lisEnvOptDlgDirectoryNotFound;
        AText:=Format(lisTheDestinationDirectoryDoesNotExist, [LineEnding, APath]);
        Result:=IDEMessageDialogAb(ACaption, AText, mtConfirmation,[mbCancel],CanAbort);
        exit;
      end;

      // check unitname
      if (NewFileExt<>'') and IsPascalUnitExt(PChar(NewFileExt)) then begin
        NewUnitName:=ExtractFileNameOnly(NewFilename);
        // Do not rename the unit if new filename differs from its name only in case
        if LowerCase(OldUnitName)=NewUnitName then
          NewUnitName:=OldUnitName;
        if NewUnitName='' then
          exit(mrCancel);
        // Is it a valid name? Ask user.
        if not IsValidUnitName(NewUnitName) then
        begin
          Result:=IDEQuestionDialogAb(lisInvalidPascalIdentifierCap,
              Format(lisInvalidPascalIdentifierName,[NewUnitName,LineEnding]),
              mtConfirmation, [mrIgnore, lisSave,
                               mrCancel, lisCancel,
                               mrRetry, lisChooseADifferentName,
                               mrAbort, lisAbort], not CanAbort);
          if Result=mrRetry then
            continue;
          if Result in [mrCancel,mrAbort] then
            exit;
        end;
        // Does the project already have such unit?
        if Project1.IndexOfUnitWithName(NewUnitName,true,AnUnitInfo)>=0 then
        begin
          Result:=IDEQuestionDialogAb(lisUnitNameAlreadyExistsCap,
              Format(lisTheUnitAlreadyExists, [NewUnitName]),
              mtConfirmation, [mrIgnore, lisForceRenaming,
                               mrCancel, lisCancelRenaming,
                               mrAbort, lisAbort], not CanAbort);
          if Result<>mrIgnore then
            exit;
        end;
      end;
    until Result<>mrRetry;
  finally
    InputHistories.StoreFileDialogSettings(SaveDialog);
    SaveDialog.Free;
  end;

  // check filename
  if FilenameIsPascalUnit(NewFilename) then begin
    AText:=ExtractFileName(NewFilename);
    // check if file should be auto renamed
    case EnvironmentOptions.CharcaseFileAction of
    ccfaAsk:
      if LowerCase(AText)<>AText then begin
        Result:=IDEQuestionDialogAb(lisRenameFile,
            Format(lisThisLooksLikeAPascalFileItIsRecommendedToUseLowerC,
                   [LineEnding, LineEnding]),
            mtWarning, [mrYes, lisRenameToLowercase,
                        mrNo, lisKeepName,
                        mrAbort, lisAbort], not CanAbort);
        case Result of
        mrYes: NewFileName:=ExtractFilePath(NewFilename)+lowercase(AText);
        mrAbort, mrCancel: exit;
        end;
        Result:=mrOk;
      end;
    ccfaAutoRename:
      NewFileName:=ExtractFilePath(NewFilename)+LowerCase(AText);
    ccfaIgnore: ;
    end;
  end;

  // check overwrite existing file
  if IDESaveDialogClass.NeedOverwritePrompt
      and ((not FilenameIsAbsolute(AFilename))
          or (CompareFilenames(NewFilename,AFilename)<>0))
      and FileExistsUTF8(NewFilename) then
  begin
    ACaption:=lisOverwriteFile;
    AText:=Format(lisAFileAlreadyExistsReplaceIt, [NewFilename, LineEnding]);
    Result:=IDEQuestionDialogAb(ACaption, AText, mtConfirmation,
                                [mrYes, lisOverwriteFileOnDisk,
                                 mrCancel,
                                 mrAbort, lisAbort], not CanAbort);
    if Result=mrCancel then exit;
  end;

  // check overwrite directory
  if DirectoryExistsUTF8(NewFilename) then
  begin
    Result:=IDEQuestionDialogAb(lisFileIsDirectory,
        lisUnableToCreateNewFileBecauseThereIsAlreadyADirecto,
        mtError,
        [mrCancel,
         mrAbort, lisAbort], not CanAbort);
    exit;
  end;

  if AnUnitInfo<>nil then begin
    // rename unit
    Result:=RenameUnit(AnUnitInfo,NewFilename,NewUnitName,LFMCode,LRSCode);
    AFilename:=AnUnitInfo.Filename;
    if Result<>mrOk then exit;
  end else begin
    Result:=mrOk;
    AFilename:=NewFilename;
  end;
end;

type
  TTranslateStringItem = record
    Name: String;
    Value: String;
  end;

  TTranslateStrings = class
  private
    FList: array of TTranslateStringItem;
    function CalcHash(const S: string): Cardinal;
    function GetSourceBytes(const S: string): string;
    function GetValue(const S: string): string;
  public
    destructor Destroy; override;
    procedure Add(const AName, AValue: String);
    function Count: Integer;
    function Text: String;
  end;

  TLRJGrubber = class(TObject)
  private
    FGrubbed: TTranslateStrings;
    FWriter: TWriter;
  public
    constructor Create(TheWriter: TWriter);
    destructor Destroy; override;
    procedure Grub(Sender: TObject; const Instance: TPersistent;
                   PropInfo: PPropInfo; var Content: string);
    property Grubbed: TTranslateStrings read FGrubbed;
    property Writer: TWriter read FWriter write FWriter;
  end;

function TTranslateStrings.CalcHash(const S: string): Cardinal;
var
  g: Cardinal;
  i: Longint;
begin
  Result:=0;
  for i:=1 to Length(s) do
  begin
    Result:=Result shl 4;
    inc(Result,Ord(S[i]));
    g:=Result and ($f shl 28);
    if g<>0 then
     begin
       Result:=Result xor (g shr 24);
       Result:=Result xor g;
     end;
  end;
  If Result=0 then
    Result:=$ffffffff;
end;

function TTranslateStrings.GetSourceBytes(const S: string): string;
var
  i, l: Integer;
begin
  Result:='';
  l:=Length(S);
  for i:=1 to l do
  begin
    Result:=Result+IntToStr(Ord(S[i]));
    if i<>l then
     Result:=Result+',';
  end;
end;

function TTranslateStrings.GetValue(const S: string): string;
var
  i, l: Integer;
  jsonstr: unicodestring;
begin
  Result:='';
  //input string is assumed to be in UTF-8 encoding
  jsonstr:=UTF8ToUTF16(StringToJSONString(S));
  l:=Length(jsonstr);
  for i:=1 to l do
  begin
    if (Ord(jsonstr[i])<32) or (Ord(jsonstr[i])>=127) then
      Result:=Result+'\u'+HexStr(Ord(jsonstr[i]), 4)
    else
      Result:=Result+Char(jsonstr[i]);
  end;
end;

destructor TTranslateStrings.Destroy;
begin
  SetLength(FList,0);
end;

procedure TTranslateStrings.Add(const AName, AValue: String);
begin
  SetLength(FList,Length(FList)+1);
  with FList[High(FList)] do
  begin
    Name:=AName;
    Value:=AValue;
  end;
end;

function TTranslateStrings.Count: Integer;
begin
  Result:=Length(FList);
end;

function TTranslateStrings.Text: String;
var
  i: Integer;
  R: TTranslateStringItem;
begin
  Result:='';
  if Length(FList)=0 then Exit;
  Result:='{"version":1,"strings":['+LineEnding;
  for i:=Low(FList) to High(FList) do
  begin
    R:=TTranslateStringItem(FList[i]);
    Result:=Result+'{"hash":'+IntToStr(CalcHash(R.Value))+',"name":"'+R.Name+
      '","sourcebytes":['+GetSourceBytes(R.Value)+
      '],"value":"'+GetValue(R.Value)+'"}';
    if i<High(FList) then
      Result:=Result+','+LineEnding
    else
      Result:=Result+LineEnding;
  end;
  Result:=Result+']}'+LineEnding;
end;

constructor TLRJGrubber.Create(TheWriter: TWriter);
begin
  inherited Create;
  FGrubbed:=TTranslateStrings.Create;
  FWriter:=TheWriter;
  FWriter.OnWriteStringProperty:=@Grub;
end;

destructor TLRJGrubber.Destroy;
begin
  FGrubbed.Free;
  inherited Destroy;
end;

procedure TLRJGrubber.Grub(Sender: TObject; const Instance: TPersistent;
  PropInfo: PPropInfo; var Content: string);
var
  LRSWriter: TLRSObjectWriter;
  Path: String;
begin
  if not Assigned(Instance) then exit;
  if not Assigned(PropInfo) then exit;
  if SysUtils.CompareText(PropInfo^.PropType^.Name,'TTRANSLATESTRING')<>0 then exit;
  if (SysUtils.CompareText(Instance.ClassName,'TMENUITEM')=0) and (Content='-') then exit;
  if Writer.Driver is TLRSObjectWriter then begin
    LRSWriter:=TLRSObjectWriter(Writer.Driver);
    Path:=LRSWriter.GetStackPath;
  end else begin
    Path:=Instance.ClassName+'.'+PropInfo^.Name;
  end;
  FGrubbed.Add(LowerCase(Path),Content);
end;

function SaveUnitComponent(AnUnitInfo: TUnitInfo;
  LRSCode, LFMCode: TCodeBuffer; Flags: TSaveFlags): TModalResult;

  function IsI18NEnabled(UnitOwners: TFPList): boolean;
  var
    i: Integer;
    APackage: TLazPackage;
    PkgFile: TPkgFile;
  begin
    if AnUnitInfo.IsPartOfProject then begin
      // a project unit
      Result:=AnUnitInfo.Project.EnableI18N and AnUnitInfo.Project.EnableI18NForLFM
         and (not AnUnitInfo.DisableI18NForLFM);
      exit;
    end;
    if (UnitOwners<>nil) then begin
      for i:=0 to UnitOwners.Count-1 do begin
        if TObject(UnitOwners[i]) is TLazPackage then begin
          // a package unit
          APackage:=TLazPackage(UnitOwners[i]);
          Result:=false;
          if APackage.EnableI18N and APackage.EnableI18NForLFM then begin
            PkgFile:=APackage.FindPkgFile(AnUnitInfo.Filename,true,true);
            Result:=(PkgFile<>nil) and (not PkgFile.DisableI18NForLFM);
          end;
          exit;
        end;
      end;
    end;
    // a rogue unit
    Result:=false;
  end;

var
  ComponentSavingOk: boolean;
  MemStream, BinCompStream, TxtCompStream: TExtMemoryStream;
  DestroyDriver: Boolean;
  Writer: TWriter;
  ACaption, AText: string;
  CompResourceCode, LFMFilename, TestFilename: string;
  ADesigner: TIDesigner;
  Grubber: TLRJGrubber;
  LRJFilename: String;
  AncestorUnit: TUnitInfo;
  Ancestor: TComponent;
  HasI18N: Boolean;
  UnitOwners: TFPList;
  LRSFilename: String;
  PropPath: String;
  ResType: TResourceType;
begin
  Result:=mrCancel;

  // save lrs - lazarus resource file and lfm - lazarus form text file
  // Note: When there is a bug in the source, the include directive of the
  //       resource code can not be found, therefore the LFM file should always
  //       be saved first.
  //       And therefore each TUnitInfo stores the resource filename (.lrs).

  // the lfm file is saved before the lrs file, because the IDE only needs the
  // lfm file to recreate the lrs file.
  // by VVI - now a LRT file is saved in addition to LFM and LRS
  // LRT file format (in present) are lines
  // <ClassName>.<PropertyName>=<PropertyValue>
  LRSFilename:='';
  ResType:=MainBuildBoss.GetResourceType(AnUnitInfo);
  LRSCode:=nil;

  if (AnUnitInfo.Component<>nil) then begin
    // stream component to resource code and to lfm file
    ComponentSavingOk:=true;

    // clean up component
    Result:=RemoveLooseEvents(AnUnitInfo);
    if Result<>mrOk then exit;

    // save designer form properties to the component
    FormEditor1.SaveHiddenDesignerFormProperties(AnUnitInfo.Component);

    if ResType=rtLRS then begin
      if (sfSaveToTestDir in Flags) then
        LRSFilename:=MainBuildBoss.GetDefaultLRSFilename(AnUnitInfo)
      else
        LRSFilename:=MainBuildBoss.FindLRSFilename(AnUnitInfo,true);
    end;

    // stream component to binary stream
    BinCompStream:=TExtMemoryStream.Create;
    if AnUnitInfo.ComponentLastBinStreamSize>0 then
      BinCompStream.Capacity:=AnUnitInfo.ComponentLastBinStreamSize+LRSStreamChunkSize;
    Writer:=nil;
    DestroyDriver:=false;
    Grubber:=nil;
    UnitOwners:=nil;
    try
      UnitOwners:=PkgBoss.GetOwnersOfUnit(AnUnitInfo.Filename);
      Result:=mrOk;
      repeat
        try
          BinCompStream.Position:=0;
          Writer:=AnUnitInfo.UnitResourceFileformat.CreateWriter(BinCompStream,DestroyDriver);
          // used to save lrj files
          HasI18N:=IsI18NEnabled(UnitOwners);
          if HasI18N then
            Grubber:=TLRJGrubber.Create(Writer);
          Writer.OnWriteMethodProperty:=@FormEditor1.WriteMethodPropertyEvent;
          //DebugLn(['SaveUnitComponent AncestorInstance=',dbgsName(AncestorInstance)]);
          Writer.OnFindAncestor:=@FormEditor1.WriterFindAncestor;
          AncestorUnit:=AnUnitInfo.FindAncestorUnit;
          Ancestor:=nil;
          if AncestorUnit<>nil then
            Ancestor:=AncestorUnit.Component;
          //DebugLn(['SaveUnitComponent Writer.WriteDescendent ARoot=',AnUnitInfo.Component,' Ancestor=',DbgSName(Ancestor)]);
          if AnUnitInfo.Component is TCustomDesignControl then // set DesignTimePPI on save
            TCustomDesignControl(AnUnitInfo.Component).DesignTimePPI := TCustomDesignControl(AnUnitInfo.Component).PixelsPerInch;
          Writer.WriteDescendent(AnUnitInfo.Component,Ancestor);
          if DestroyDriver then
            Writer.Driver.Free;
          FreeAndNil(Writer);
          AnUnitInfo.ComponentLastBinStreamSize:=BinCompStream.Size;
        except
          on E: Exception do begin
            PropPath:='';
            if Writer.Driver is TLRSObjectWriter then
              PropPath:=TLRSObjectWriter(Writer.Driver).GetStackPath;
            DumpExceptionBackTrace;
            ACaption:=lisStreamingError;
            AText:=Format(lisUnableToStreamT, [AnUnitInfo.ComponentName,
                          AnUnitInfo.ComponentName]) + LineEnding + E.Message;
            if PropPath<>'' then
              AText := Atext + LineEnding + LineEnding + lisPathToInstance
                     + LineEnding + PropPath;
            Result:=IDEMessageDialog(ACaption, AText, mtError,
                       [mbAbort, mbRetry, mbIgnore]);
            if Result=mrAbort then exit;
            if Result=mrIgnore then Result:=mrOk;
            ComponentSavingOk:=false;
          end;
        end;
      until Result<>mrRetry;

      // create lazarus form resource code
      if ComponentSavingOk and (LRSFilename<>'') then begin
        if LRSCode=nil then begin
          LRSCode:=CodeToolBoss.CreateFile(LRSFilename);
          ComponentSavingOk:=(LRSCode<>nil);
        end;
        if ComponentSavingOk then begin
          // there is no bug in the source, so the resource code should be changed too
          MemStream:=TExtMemoryStream.Create;
          if AnUnitInfo.ComponentLastLRSStreamSize>0 then
            MemStream.Capacity:=AnUnitInfo.ComponentLastLRSStreamSize+LRSStreamChunkSize;
          try
            BinCompStream.Position:=0;
            BinaryToLazarusResourceCode(BinCompStream,MemStream
              ,'T'+AnUnitInfo.ComponentName,'FORMDATA');
            AnUnitInfo.ComponentLastLRSStreamSize:=MemStream.Size;
            MemStream.Position:=0;
            SetLength(CompResourceCode{%H-},MemStream.Size);
            MemStream.Read(CompResourceCode[1],length(CompResourceCode));
          finally
            MemStream.Free;
          end;
        end;
        if ComponentSavingOk then begin
          {$IFDEF IDE_DEBUG}
          debugln('SaveUnitComponent E ',CompResourceCode);
          {$ENDIF}
          // replace lazarus form resource code in include file (.lrs)
          if not (sfSaveToTestDir in Flags) then begin
            // if resource name has changed, delete old resource
            if (AnUnitInfo.ComponentName<>AnUnitInfo.ComponentResourceName)
            and (AnUnitInfo.ComponentResourceName<>'') then begin
              CodeToolBoss.RemoveLazarusResource(LRSCode,
                                          'T'+AnUnitInfo.ComponentResourceName);
            end;
            // add comment to resource file (if not already exists)
            if (not CodeToolBoss.AddLazarusResourceHeaderComment(LRSCode,LRSComment)) then
            begin
              ACaption:=lisResourceSaveError;
              AText:=Format(lisUnableToAddResourceHeaderCommentToResourceFile, [
                LineEnding, LRSCode.FileName, LineEnding]);
              Result:=IDEMessageDialog(ACaption,AText,mtError,[mbIgnore,mbAbort]);
              if Result<>mrIgnore then exit;
            end;
            // add resource to resource file
            if (not CodeToolBoss.AddLazarusResource(LRSCode,
               'T'+AnUnitInfo.ComponentName,CompResourceCode)) then
            begin
              ACaption:=lisResourceSaveError;
              AText:=Format(lisUnableToAddResourceTFORMDATAToResourceFileProbably,
                [AnUnitInfo.ComponentName, LineEnding, LRSCode.FileName, LineEnding] );
              Result:=IDEMessageDialog(ACaption, AText, mtError, [mbIgnore, mbAbort]);
              if Result<>mrIgnore then exit;
            end else begin
              AnUnitInfo.ComponentResourceName:=AnUnitInfo.ComponentName;
            end;
          end else begin
            LRSCode.Source:=CompResourceCode;
          end;
        end;
      end;
      if ComponentSavingOk then begin
        if (not AnUnitInfo.IsVirtual) or (sfSaveToTestDir in Flags) then
        begin
          // save lfm file
          LFMFilename:=AnUnitInfo.UnitResourceFileformat.GetUnitResourceFilename(AnUnitInfo.Filename,false);
          if AnUnitInfo.IsVirtual then
            LFMFilename:=AppendPathDelim(MainBuildBoss.GetTestBuildDirectory)+LFMFilename;
          if LFMCode=nil then begin
            LFMCode:=CodeToolBoss.CreateFile(LFMFilename);
            if LFMCode=nil then begin
              Result:=IDEQuestionDialog(lisUnableToCreateFile,
                Format(lisUnableToCreateFile2, [LFMFilename]),
                mtWarning, [mrIgnore, lisContinueWithoutLoadingForm,
                           mrCancel, lisCancelLoadingUnit,
                           mrAbort, lisAbortAllLoading]);
              if Result<>mrIgnore then exit;
            end;
          end;
          if (LFMCode<>nil) then begin
            {$IFDEF IDE_DEBUG}
            debugln('SaveUnitComponent E2 LFM=',LFMCode.Filename);
            {$ENDIF}
            if (ResType=rtRes) and (LFMCode.DiskEncoding<>EncodingUTF8) then
            begin
              // the .lfm file is used by fpcres, which only supports UTF8 without BOM
              DebugLn(['SaveUnitComponent fixing encoding of ',LFMCode.Filename,' from ',LFMCode.DiskEncoding,' to ',EncodingUTF8]);
              LFMCode.DiskEncoding:=EncodingUTF8;
            end;

            Result:=mrOk;
            repeat
              try
                // transform binary to text
                TxtCompStream:=TExtMemoryStream.Create;
                if AnUnitInfo.ComponentLastLFMStreamSize>0 then
                  TxtCompStream.Capacity:=AnUnitInfo.ComponentLastLFMStreamSize
                                          +LRSStreamChunkSize;
                try
                  BinCompStream.Position:=0;
                  AnUnitInfo.UnitResourceFileformat.BinStreamToTextStream(BinCompStream,TxtCompStream);
                  AnUnitInfo.ComponentLastLFMStreamSize:=TxtCompStream.Size;
                  // stream text to file
                  TxtCompStream.Position:=0;
                  LFMCode.LoadFromStream(TxtCompStream);
                  Result:=SaveCodeBufferToFile(LFMCode,LFMCode.Filename,true);
                  if not Result=mrOk then exit;
                  Result:=mrCancel;
                finally
                  TxtCompStream.Free;
                end;
              except
                on E: Exception do begin
                  // added to get more feedback on issue 7009
                  Debugln('SaveFileResources E3: ', E.Message);
                  DumpExceptionBackTrace;
                  ACaption:=lisStreamingError;
                  AText:=Format(
                    lisUnableToTransformBinaryComponentStreamOfTIntoText, [
                    AnUnitInfo.ComponentName, AnUnitInfo.ComponentName])
                    +LineEnding+E.Message;
                  Result:=IDEMessageDialog(ACaption, AText, mtError,
                                     [mbAbort, mbRetry, mbIgnore]);
                  if Result=mrAbort then exit;
                  if Result=mrIgnore then Result:=mrOk;
                end;
              end;
            until Result<>mrRetry;
          end;
        end;
      end;
      // Now the most important file (.lfm) is saved.
      // Now save the secondary files

      // save the .lrj file containing the list of all translatable strings of
      // the component
      if ComponentSavingOk
      and (Grubber<>nil) and (Grubber.Grubbed.Count>0)
      and (not (sfSaveToTestDir in Flags))
      and (not AnUnitInfo.IsVirtual) then begin
        LRJFilename:=ChangeFileExt(AnUnitInfo.Filename,'.lrj');
        DebugLn(['SaveUnitComponent save lrj: ',LRJFilename]);
        Result:=SaveStringToFile(LRJFilename,Grubber.Grubbed.Text,
                                 [mbIgnore,mbAbort],AnUnitInfo.Filename);
        if (Result<>mrOk) and (Result<>mrIgnore) then exit;
      end;

    finally
      try
        FreeAndNil(BinCompStream);
        if DestroyDriver and (Writer<>nil) then Writer.Driver.Free;
        FreeAndNil(Writer);
        FreeAndNil(Grubber);
        FreeAndNil(UnitOwners);
      except
        on E: Exception do begin
          debugln('SaveUnitComponent Error cleaning up: ',E.Message);
        end;
      end;
    end;
  end;
  {$IFDEF IDE_DEBUG}
  if ResourceCode<>nil then
    debugln('SaveUnitComponent F ',ResourceCode.Modified);
  {$ENDIF}
  // save binary stream (.lrs)
  if LRSCode<>nil then begin
    if (not (sfSaveToTestDir in Flags)) then
    begin
      if (LRSCode.Modified) then begin
        if FilenameIsAbsolute(LRSCode.Filename) then
          LRSFilename:=LRSCode.Filename
        else if LRSFilename='' then
          LRSFilename:=MainBuildBoss.FindLRSFilename(AnUnitInfo,true);
        if (LRSFilename<>'') and FilenameIsAbsolute(LRSFilename) then
        begin
          Result:=ForceDirectoryInteractive(ExtractFilePath(LRSFilename),[mbRetry]);
          if not Result=mrOk then exit;
          Result:=SaveCodeBufferToFile(LRSCode,LRSFilename);
          if not Result=mrOk then exit;
        end;
      end;
    end else begin
      TestFilename:=MainBuildBoss.GetTestUnitFilename(AnUnitInfo);
      LRSFilename:=ChangeFileExt(TestFilename,ExtractFileExt(LRSCode.Filename));
      Result:=SaveCodeBufferToFile(LRSCode,LRSFilename);
      if not Result=mrOk then exit;
    end;
  end;
  // mark designer unmodified
  ADesigner:=FindRootDesigner(AnUnitInfo.Component);
  if ADesigner<>nil then
    ADesigner.DefaultFormBoundsValid:=false;

  Result:=mrOk;
  {$IFDEF IDE_DEBUG}
  debugln('SaveUnitComponent G ',LFMCode<>nil);
  {$ENDIF}
end;

function RemoveLooseEvents(AnUnitInfo: TUnitInfo): TModalResult;
var
  ComponentModified: boolean;
  ActiveSrcEdit: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  Result:=mrOk;
  if (AnUnitInfo.Component=nil) then exit;
  ActiveSrcEdit:=nil;
  if not MainIDE.BeginCodeTool(ActiveSrcEdit,ActiveUnitInfo,[]) then exit;
  // unselect methods in ObjectInspector1
  if (ObjectInspector1<>nil)
  and (ObjectInspector1.PropertyEditorHook.LookupRoot=AnUnitInfo.Component) then
  begin
    ObjectInspector1.EventGrid.ItemIndex:=-1;
    ObjectInspector1.FavoriteGrid.ItemIndex:=-1;
  end;
  //debugln('RemoveLooseEvents ',AnUnitInfo.Filename,' ',dbgsName(AnUnitInfo.Component));
  // remove dangling methods
  Result:=RemoveDanglingEvents(AnUnitInfo.Component, AnUnitInfo.Source, True,
                               ComponentModified);
  // update ObjectInspector1
  if ComponentModified
  and (ObjectInspector1<>nil)
  and (ObjectInspector1.PropertyEditorHook.LookupRoot=AnUnitInfo.Component) then
  begin
    ObjectInspector1.EventGrid.RefreshPropertyValues;
    ObjectInspector1.FavoriteGrid.RefreshPropertyValues;
  end;
end;

function RenameUnit(AnUnitInfo: TUnitInfo; NewFilename, NewUnitName: string;
  var LFMCode, LRSCode: TCodeBuffer): TModalResult;
var
  NewSource: TCodeBuffer;
  NewLFMFilename, NewLRSFilename: String;
  NewFilePath, NewLRSFilePath: String;
  OldFilename, OldLFMFilename, OldLRSFilename, OldPPUFilename: String;
  OldFilePath, OldLRSFilePath: String;
  OldSourceCode, OldUnitPath: String;
  AmbiguousFilename, OutDir, S: string;
  NewHighlighter: TLazSyntaxHighlighter;
  AmbiguousFiles: TStringList;
  i: Integer;
  Owners: TFPList;
  OldFileExisted: Boolean;
  ConvTool: TConvDelphiCodeTool;
  AEditor: TSourceEditor;
begin
  // Project is marked as changed already here.
  Project1.BeginUpdate(true);
  try
    // notify IDE addons
    Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,
                                                       sefsSaveAs,NewFilename);
    if Result<>mrOk then exit;

    OldFilename:=AnUnitInfo.Filename;
    OldFilePath:=ExtractFilePath(OldFilename);
    OldLFMFilename:='';
    // ToDo: use UnitResources
    if FilenameHasPascalExt(OldFilename) then begin
      OldLFMFilename:=ChangeFileExt(OldFilename,'.lfm');
      if not FileExistsUTF8(OldLFMFilename) then
        OldLFMFilename:=ChangeFileExt(OldFilename,'.dfm');
    end;
    if NewUnitName='' then
      NewUnitName:=AnUnitInfo.Unit_Name;
    debugln(['Hint: (lazarus) RenameUnit ',AnUnitInfo.Filename,' NewUnitName=',NewUnitName,' OldUnitName=',AnUnitInfo.Unit_Name,' LFMCode=',LFMCode<>nil,' LRSCode=',LRSCode<>nil,' NewFilename="',NewFilename,'"']);

    // check new resource file
    NewLFMFilename:='';
    if FilenameHasPascalExt(NewFilename) then
       NewLFMFilename:=ChangeFileExt(NewFilename,'.lfm');
    if AnUnitInfo.ComponentName='' then begin
      // unit has no component
      // -> remove lfm file, so that it will not be auto loaded on next open
      if (FileExistsUTF8(NewLFMFilename))
      and (not DeleteFileUTF8(NewLFMFilename))
      and (IDEMessageDialog(lisPkgMangDeleteFailed,
            Format(lisDeletingOfFileFailed, [NewLFMFilename]),
            mtError, [mbIgnore, mbCancel])=mrCancel)
      then
        exit(mrCancel);
    end;

    // create new source with the new filename
    OldSourceCode:=AnUnitInfo.Source.Source;
    NewSource:=CodeToolBoss.CreateFile(NewFilename);
    if NewSource=nil then begin
      Result:=IDEMessageDialog(lisUnableToCreateFile,
        Format(lisCanNotCreateFile, [NewFilename]),
        mtError,[mbCancel,mbAbort]);
      exit;
    end;
    NewSource.Source:=OldSourceCode;
    if (AnUnitInfo.Source.DiskEncoding<>'') and (AnUnitInfo.Source.DiskEncoding<>EncodingUTF8)
    then begin
      NewSource.DiskEncoding:=AnUnitInfo.Source.DiskEncoding;
      InputHistories.FileEncodings[NewFilename]:=NewSource.DiskEncoding;
    end else
      InputHistories.FileEncodings.Remove(NewFilename);

    // get final filename
    NewFilename:=NewSource.Filename;
    NewFilePath:=ExtractFilePath(NewFilename);
    EnvironmentOptions.RemoveFromRecentOpenFiles(OldFilename);
    EnvironmentOptions.AddToRecentOpenFiles(NewFilename);
    MainIDE.SetRecentFilesMenu;

    // add new path to unit path
    if AnUnitInfo.IsPartOfProject and FilenameHasPascalExt(NewFilename)
    and (CompareFilenames(NewFilePath,Project1.Directory)<>0) then begin
      OldUnitPath:=Project1.CompilerOptions.GetUnitPath(false);
      if SearchDirectoryInSearchPath(OldUnitPath,NewFilePath,1)<1 then
        AddPathToBuildModes(NewFilePath, False);
    end;

    // rename lfm file
    if FilenameIsAbsolute(NewLFMFilename) then begin
      if (LFMCode=nil)
      and (OldLFMFilename<>'')
      and FilenameIsAbsolute(OldLFMFilename) and FileExistsUTF8(OldLFMFilename) then
        LFMCode:=CodeToolBoss.LoadFile(OldLFMFilename,false,false);
      if (LFMCode<>nil) then begin
        Result:=SaveCodeBufferToFile(LFMCode,NewLFMFilename,true);
        if not (Result in [mrOk,mrIgnore]) then begin
          DebugLn(['RenameUnit SaveCodeBufferToFile failed for "',NewLFMFilename,'"']);
          exit;
        end;
        LFMCode:=CodeToolBoss.LoadFile(NewLFMFilename,true,false);
        if LFMCode<>nil then
          NewLFMFilename:=LFMCode.Filename;
        ConvTool:=TConvDelphiCodeTool.Create(NewSource);
        try
          if not ConvTool.RenameResourceDirectives then
            debugln(['RenameUnit WARNING: unable to rename resource directive in "',NewSource.Filename,'"']);
        finally
          ConvTool.Free;
        end;
      end;
    end;

    // rename Resource file (.lrs)
    if (LRSCode<>nil) then begin
      // the resource include line in the code will be changed later after
      // changing the unitname
      if AnUnitInfo.IsPartOfProject
      and (not Project1.IsVirtual)
      and (pfLRSFilesInOutputDirectory in Project1.Flags) then begin
        NewLRSFilename:=MainBuildBoss.GetDefaultLRSFilename(AnUnitInfo);
        NewLRSFilename:=AppendPathDelim(ExtractFilePath(NewLRSFilename))
          +ExtractFileNameOnly(NewFilename)+ResourceFileExt;
      end else begin
        OldLRSFilePath:=ExtractFilePath(LRSCode.Filename);
        NewLRSFilePath:=OldLRSFilePath;
        if FilenameIsAbsolute(OldFilePath)
        and PathIsInPath(OldLRSFilePath,OldFilePath) then begin
          // resource code was in the same or in a sub directory of source
          // -> try to keep this relationship
          NewLRSFilePath:=NewFilePath
            +copy(LRSCode.Filename,length(OldFilePath)+1,length(LRSCode.Filename));
          if not DirPathExists(NewLRSFilePath) then
            NewLRSFilePath:=NewFilePath;
        end else begin
          // resource code was not in the same or in a sub directory of source
          // copy resource into the same directory as the source
          NewLRSFilePath:=NewFilePath;
        end;
        NewLRSFilename:=NewLRSFilePath+ExtractFileNameOnly(NewFilename)+ResourceFileExt;
      end;
      Result:=ForceDirectoryInteractive(ExtractFilePath(NewLRSFilename),[mbRetry,mbIgnore]);
      if Result=mrCancel then exit;
      if Result=mrOk then begin
        if not CodeToolBoss.SaveBufferAs(LRSCode,NewLRSFilename,LRSCode) then
          DebugLn(['RenameUnit CodeToolBoss.SaveBufferAs failed: NewResFilename="',NewLRSFilename,'"']);
      end;

      {$IFDEF IDE_DEBUG}
      debugln(['RenameUnit C ',ResourceCode<>nil]);
      debugln(['   NewResFilePath="',NewResFilePath,'" NewResFilename="',NewResFilename,'"']);
      if ResourceCode<>nil then debugln('*** ResourceFileName ',ResourceCode.Filename);
      {$ENDIF}
    end else begin
      NewLRSFilename:='';
    end;
    // rename unit name of jit class
    if (AnUnitInfo.Component<>nil) then
      FormEditor1.RenameJITComponentUnitname(AnUnitInfo.Component,NewUnitName);
    {$IFDEF IDE_DEBUG}
    if AnUnitInfo.Component<>nil then debugln('*** AnUnitInfo.Component ',dbgsName(AnUnitInfo.Component),' ClassUnitname=',GetClassUnitName(AnUnitInfo.Component.ClassType));
    debugln(['RenameUnit D ',ResourceCode<>nil]);
    {$ENDIF}

    // set new codebuffer in unitinfo and sourceeditor
    AnUnitInfo.Source:=NewSource;
    if AnUnitInfo.IsPartOfProject then
      Project1.Modified:=true
    else
      Project1.SessionModified:=true;
    AnUnitInfo.ClearModifieds;
    for i := 0 to AnUnitInfo.EditorInfoCount -1 do begin
      AEditor := TSourceEditor(AnUnitInfo.EditorInfo[i].EditorComponent);
      if AEditor <> nil then begin
        // the code is not changed, therefore the marks are kept
        AEditor.CodeBuffer := NewSource;
        // change unitname on SourceNotebook
        S := CreateSrcEditPageName(NewUnitName, AnUnitInfo.Filename, AEditor);
        AEditor.PageName := S;
      end;
    end;

    // change unitname in lpi and in main source file
    AnUnitInfo.Unit_Name:=NewUnitName;
    if LRSCode<>nil then begin
      // change resource filename in the source include directive
      if not CodeToolBoss.RenameMainInclude(AnUnitInfo.Source,
        ExtractFilename(LRSCode.Filename),false)
      then
        DebugLn(['RenameUnit CodeToolBoss.RenameMainInclude failed: AnUnitInfo.Source="',AnUnitInfo.Source,'" ResourceCode="',ExtractFilename(LRSCode.Filename),'"']);
    end;

    // change syntax highlighter
    NewHighlighter:=FilenameToLazSyntaxHighlighter(NewFilename);
    AnUnitInfo.UpdateDefaultHighlighter(NewHighlighter);
    for i := 0 to AnUnitInfo.EditorInfoCount - 1 do
      if (AnUnitInfo.EditorInfo[i].EditorComponent <> nil) and
         (not AnUnitInfo.EditorInfo[i].CustomHighlighter)
      then
        TSourceEditor(AnUnitInfo.EditorInfo[i].EditorComponent).SyntaxHighlighterType :=
          AnUnitInfo.EditorInfo[i].SyntaxHighlighter;

    // save file
    if not NewSource.IsVirtual then begin
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,sefsBeforeWrite);
      if Result<>mrOk then exit;
      // actual write
      Result:=AnUnitInfo.WriteUnitSource;
      if Result<>mrOk then exit;
      AnUnitInfo.Modified:=false;
      // notify packages
      Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,sefsAfterWrite);
      if Result<>mrOk then exit;
    end;

    // change lpks containing the file
    Result:=PkgBoss.OnRenameFile(OldFilename,AnUnitInfo.Filename,
                                 AnUnitInfo.IsPartOfProject);
    if Result=mrAbort then exit;

    OldFileExisted:=FilenameIsAbsolute(OldFilename) and FileExistsUTF8(OldFilename);

    // delete ambiguous files
    AmbiguousFiles:=
      FindFilesCaseInsensitive(NewFilePath,ExtractFilename(NewFilename),true);
    if AmbiguousFiles<>nil then begin
      try
        if (AmbiguousFiles.Count=1)
        and (CompareFilenames(OldFilePath,NewFilePath)=0)
        and (CompareFilenames(AmbiguousFiles[0],ExtractFilename(OldFilename))=0)
        then
          S:=Format(lisDeleteOldFile, [ExtractFilename(OldFilename)])
        else
          S:=Format(lisThereAreOtherFilesInTheDirectoryWithTheSameName,
                          [LineEnding, LineEnding, AmbiguousFiles.Text, LineEnding]);
        Result:=IDEMessageDialog(lisAmbiguousFilesFound, S,
          mtWarning,[mbYes,mbNo,mbAbort]);
        if Result=mrAbort then exit;
        if Result=mrYes then begin
          NewFilePath:=AppendPathDelim(ExtractFilePath(NewFilename));
          for i:=0 to AmbiguousFiles.Count-1 do begin
            AmbiguousFilename:=NewFilePath+AmbiguousFiles[i];
            if (FileExistsUTF8(AmbiguousFilename))
            and (not DeleteFileUTF8(AmbiguousFilename))
            and (IDEMessageDialog(lisPkgMangDeleteFailed,
                  Format(lisDeletingOfFileFailed, [AmbiguousFilename]),
                  mtError, [mbIgnore, mbCancel])=mrCancel)
            then
              exit(mrCancel);
          end;
        end;
      finally
        AmbiguousFiles.Free;
      end;
    end;

    // remove old path from unit path
    if AnUnitInfo.IsPartOfProject and FilenameHasPascalExt(OldFilename)
    and (OldFilePath<>'') then begin
      //DebugLn('RenameUnit OldFilePath="',OldFilePath,'" SourceDirs="',Project1.SourceDirectories.CreateSearchPathFromAllFiles,'"');
      if (SearchDirectoryInSearchPath(
        Project1.SourceDirectories.CreateSearchPathFromAllFiles,OldFilePath,1)<1)
      then
        //DebugLn('RenameUnit OldFilePath="',OldFilePath,'" UnitPath="',Project1.CompilerOptions.GetUnitPath(false),'"');
        if (SearchDirectoryInSearchPath(Project1.CompilerOptions.GetUnitPath(false),OldFilePath,1)<1)
        then
          if IDEMessageDialog(lisCleanUpUnitPath,
              Format(lisTheDirectoryIsNoLongerNeededInTheUnitPathRemoveIt,[OldFilePath,LineEnding]),
              mtConfirmation,[mbYes,mbNo])=mrYes
          then
            Project1.CompilerOptions.RemoveFromUnitPaths(OldUnitPath);
    end;

    // delete old pas, .pp, .ppu
    if (CompareFilenames(NewFilename,OldFilename)<>0)
    and OldFileExisted then begin
      if IDEMessageDialog(lisDeleteOldFile2, Format(lisDeleteOldFile,[OldFilename]),
        mtConfirmation,[mbYes,mbNo])=mrYes then
      begin
        Result:=DeleteFileInteractive(OldFilename,[mbAbort]);
        if Result=mrAbort then exit;
        // delete old lfm
        //debugln(['RenameUnit NewLFMFilename=',NewLFMFilename,' exists=',FileExistsUTF8(NewLFMFilename),' Old=',OldLFMFilename,' exists=',FileExistsUTF8(OldLFMFilename)]);
        if FileExistsUTF8(NewLFMFilename) then begin
          // the new file has a lfm, so it is safe to delete the old
          // (if NewLFMFilename does not exist, it didn't belong to the unit
          //  or there was an error during delete. Never delete files in doubt.)
          OldLFMFilename:=ChangeFileExt(OldFilename,'.lfm');
          if FileExistsUTF8(OldLFMFilename) then begin
            Result:=DeleteFileInteractive(OldLFMFilename,[mbAbort]);
            if Result=mrAbort then exit;
          end;
        end;
        // delete old lrs
        if (LRSCode<>nil) and FileExistsUTF8(LRSCode.Filename) then begin
          // the new file has a lrs, so it is safe to delete the old
          // (if the new lrs does not exist, it didn't belong to the unit
          //  or there was an error during delete. Never delete files in doubt.)
          OldLRSFilename:=ChangeFileExt(OldFilename,ResourceFileExt);
          if FileExistsUTF8(OldLRSFilename) then begin
            Result:=DeleteFileInteractive(OldLRSFilename,[mbAbort]);
            if Result=mrAbort then exit;
          end;
        end;
        // delete ppu in source directory
        OldPPUFilename:=ChangeFileExt(OldFilename,'.ppu');
        if FileExistsUTF8(OldPPUFilename) then begin
          Result:=DeleteFileInteractive(OldPPUFilename,[mbAbort]);
          if Result=mrAbort then exit;
        end;
        OldPPUFilename:=ChangeFileExt(OldPPUFilename,'.o');
        if FileExistsUTF8(OldPPUFilename) then begin
          Result:=DeleteFileInteractive(OldPPUFilename,[mbAbort]);
          if Result=mrAbort then exit;
        end;
        Owners:=PkgBoss.GetOwnersOfUnit(NewFilename);
        try
          if Owners<>nil then begin
            for i:=0 to Owners.Count-1 do begin
              OutDir:='';
              if TObject(Owners[i]) is TProject then begin
                // delete old files in project output directory
                OutDir:=TProject(Owners[i]).CompilerOptions.GetUnitOutPath(false);
              end else if TObject(Owners[i]) is TLazPackage then begin
                // delete old files in package output directory
                OutDir:=TLazPackage(Owners[i]).CompilerOptions.GetUnitOutPath(false);
              end;
              if (OutDir<>'') and FilenameIsAbsolute(OutDir) then begin
                OldPPUFilename:=AppendPathDelim(OutDir)+ChangeFileExt(ExtractFilename(OldFilename),'.ppu');
                if FileExistsUTF8(OldPPUFilename) then begin
                  Result:=DeleteFileInteractive(OldPPUFilename,[mbAbort]);
                  if Result=mrAbort then exit;
                end;
                OldPPUFilename:=ChangeFileExt(OldPPUFilename,'.o');
                if FileExistsUTF8(OldPPUFilename) then begin
                  Result:=DeleteFileInteractive(OldPPUFilename,[mbAbort]);
                  if Result=mrAbort then exit;
                end;
                OldLRSFilename:=ChangeFileExt(OldPPUFilename,ResourceFileExt);
                if FileExistsUTF8(OldLRSFilename) then begin
                  Result:=DeleteFileInteractive(OldLRSFilename,[mbAbort]);
                  if Result=mrAbort then exit;
                end;
              end;
            end;
          end;
        finally
          Owners.Free;
        end;
      end;
    end;

    // notify IDE addons
    Result:=MainIDEInterface.CallSaveEditorFileHandler(LazarusIDE,AnUnitInfo,
                                                       sefsSavedAs,OldFilename);
    if Result<>mrOk then exit;
  finally
    Project1.EndUpdate;
  end;
  Result:=mrOk;
end;

function RenameUnitLowerCase(AnUnitInfo: TUnitInfo; AskUser: boolean): TModalresult;
var
  OldFilename: String;
  OldShortFilename: String;
  NewFilename: String;
  NewShortFilename: String;
  LFMCode, LRSCode: TCodeBuffer;
  NewUnitName: String;
begin
  Result:=mrOk;
  OldFilename:=AnUnitInfo.Filename;
  // check if file is unit
  if not FilenameIsPascalUnit(OldFilename) then exit;
  // check if file is already lowercase (or it does not matter in current OS)
  OldShortFilename:=ExtractFilename(OldFilename);
  NewShortFilename:=lowercase(OldShortFilename);
  if CompareFilenames(OldShortFilename,NewShortFilename)=0 then exit;
  // create new filename
  NewFilename:=ExtractFilePath(OldFilename)+NewShortFilename;

  // rename unit
  if AskUser then begin
    Result:=IDEQuestionDialog(lisFileNotLowercase,
      Format(lisTheUnitIsNotLowercaseTheFreePascalCompiler,
             [OldFilename, LineEnding, LineEnding+LineEnding]),
      mtConfirmation,[mrYes,mrIgnore,rsmbNo,mrAbort],'');
    if Result<>mrYes then exit;
  end;
  NewUnitName:=AnUnitInfo.Unit_Name;
  if NewUnitName='' then begin
    AnUnitInfo.ReadUnitNameFromSource(false);
    NewUnitName:=AnUnitInfo.CreateUnitName;
  end;
  LFMCode:=nil;
  LRSCode:=nil;
  Result:=RenameUnit(AnUnitInfo,NewFilename,NewUnitName,LFMCode,LRSCode);
end;

function CheckLFMInEditor(LFMUnitInfo: TUnitInfo; Quiet: boolean): TModalResult;
var
  LFMChecker: TLFMChecker;
  UnitFilename: String;
  PascalBuf: TCodeBuffer;
  i: integer;
  LFMFilename: String;
  SrcEdit: TSourceEditor;
begin
  if (LFMUnitInfo<>nil)
  and FilenameHasPascalExt(LFMUnitInfo.Filename) then begin
    LFMFilename:=ChangeFileExt(LFMUnitInfo.Filename,'.lfm');
    if FileExistsInIDE(LFMFilename,[])
    and (OpenEditorFile(LFMFilename,-1,-1,nil,[])=mrOk)
    and (SourceEditorManager.ActiveEditor<>nil)
    then begin
      SrcEdit:=SourceEditorManager.ActiveEditor;
      LFMUnitInfo:=Project1.UnitInfoWithFilename(SrcEdit.FileName);
    end;
  end;

  // check, if a .lfm file is opened in the source editor
  if (LFMUnitInfo=nil)
  or not ( FilenameExtIs(LFMUnitInfo.Filename,'lfm',true) or
           FilenameExtIs(LFMUnitInfo.Filename,'dfm') ) then
  begin
    if not Quiet then
    begin
      IDEMessageDialog(lisNoLFMFile,
        lisThisFunctionNeedsAnOpenLfmFileInTheSourceEditor,
        mtError,[mbCancel]);
    end;
    Result:=mrCancel;
    exit;
  end;
  // try to find the pascal unit
  for i:=Low(PascalFileExt) to High(PascalFileExt) do begin
    UnitFilename:=ChangeFileExt(LFMUnitInfo.Filename,PascalFileExt[i]);
    if FileExistsCached(UnitFilename) then
      break
    else
      UnitFilename:='';
  end;
  if UnitFilename='' then begin
    IDEMessageDialog(lisNoPascalFile,
      Format(lisUnableToFindPascalUnitPasPpForLfmFile,[LineEnding, LFMUnitInfo.Filename]),
      mtError,[mbCancel]);
    Result:=mrCancel;
    exit;
  end;

  if MainIDE.ToolStatus<>itNone then begin
    DebugLn(['CheckLFMInEditor ToolStatus<>itNone']);
    Result:=mrCancel;
    exit;
  end;
  // load the pascal unit
  SaveEditorChangesToCodeCache(nil);
  Result:=LoadCodeBuffer(PascalBuf,UnitFilename,[],false);
  if Result<>mrOk then exit;

  // open messages window
  SourceEditorManager.ClearErrorLines;
  if MessagesView<>nil then
    MessagesView.Clear;
  ArrangeSourceEditorAndMessageView(false);

  // parse the LFM file and the pascal unit
  LFMChecker:=TLFMChecker.Create(PascalBuf,LFMUnitInfo.Source);
  try
    LFMChecker.ShowMessages:=true;
    LFMChecker.RootMustBeClassInUnit:=true;
    LFMChecker.RootMustBeClassInIntf:=true;
    LFMChecker.ObjectsMustExist:=true;
    if LFMChecker.Repair=mrOk then begin
      if not Quiet then begin
        IDEMessageDialog(lisLFMIsOk,
          lisClassesAndPropertiesExistValuesWereNotChecked,
          mtInformation,[mbOk],'');
      end;
    end else begin
      MainIDE.DoJumpToCompilerMessage(true);
      Result:=mrAbort;
      exit;
    end;
  finally
    LFMChecker.Free;
  end;
  Result:=mrOk;
end;

function LoadResourceFile(AnUnitInfo: TUnitInfo; var LFMCode, LRSCode: TCodeBuffer;
  AutoCreateResourceCode, ShowAbort: boolean): TModalResult;
var
  LFMFilename: string;
  LRSFilename: String;
  ResType: TResourceType;
begin
  LFMCode:=nil;
  LRSCode:=nil;
  //DebugLn(['LoadResourceFile ',AnUnitInfo.Filename,' HasResources=',AnUnitInfo.HasResources,' IgnoreSourceErrors=',IgnoreSourceErrors,' AutoCreateResourceCode=',AutoCreateResourceCode]);
  // Load the lfm file (without parsing)
  if not AnUnitInfo.IsVirtual then begin  // and (AnUnitInfo.Component<>nil)
    LFMFilename:=AnUnitInfo.UnitResourceFileformat.GetUnitResourceFilename(AnUnitInfo.Filename,true);
    if (FileExistsCached(LFMFilename)) then begin
      Result:=LoadCodeBuffer(LFMCode,LFMFilename,[lbfCheckIfText],ShowAbort);
      if not (Result in [mrOk,mrIgnore]) then
        exit;
    end;
  end;
  if AnUnitInfo.HasResources then begin
    //debugln('LoadResourceFile A "',AnUnitInfo.Filename,'" "',AnUnitInfo.ResourceFileName,'"');
    ResType:=MainBuildBoss.GetResourceType(AnUnitInfo);
    if ResType=rtLRS then begin
      LRSFilename:=MainBuildBoss.FindLRSFilename(AnUnitInfo,false);
      if LRSFilename<>'' then begin
        Result:=LoadCodeBuffer(LRSCode,LRSFilename,[lbfUpdateFromDisk],ShowAbort);
        if Result<>mrOk then exit;
      end else begin
        LRSFilename:=MainBuildBoss.GetDefaultLRSFilename(AnUnitInfo);
        if AutoCreateResourceCode then begin
          LRSCode:=CodeToolBoss.CreateFile(LRSFilename);
        end else begin
          DebugLn(['LoadResourceFile .lrs file not found of unit ',AnUnitInfo.Filename]);
          exit(mrCancel);
        end;
      end;
    end else begin
      LRSFilename:='';
      LRSCode:=nil;
    end;
  end;
  Result:=mrOk;
end;

function LoadLFM(AnUnitInfo: TUnitInfo; OpenFlags: TOpenFlags;
  CloseFlags: TCloseFlags): TModalResult;
// if there is a .lfm file, open the resource
var
  ResFilename: string;
  LFMBuf: TCodeBuffer;
  CanAbort: boolean;
begin
  CanAbort:=[ofProjectLoading,ofMultiOpen]*OpenFlags<>[];
  // Note: think about virtual and normal .lfm files.
  with AnUnitInfo.UnitResourceFileformat do
    ResFilename:=GetUnitResourceFilename(AnUnitInfo.Filename,true);
  LFMBuf:=nil;
  if not FileExistsInIDE(ResFilename,[pfsfOnlyEditorFiles]) then begin
    {$IFDEF IDE_DEBUG}
    debugln('LoadLFM there is no LFM file for "',AnUnitInfo.Filename,'"');
    {$ENDIF}
    exit(mrOk);       // there is no LFM file -> ok
  end;
  // there is a lazarus form text file -> load it
  Result:=LoadIDECodeBuffer(LFMBuf,ResFilename,[lbfUpdateFromDisk],CanAbort);
  if Result<>mrOk then begin
    DebugLn(['LoadLFM LoadIDECodeBuffer failed']);
    exit;
  end;
  Result:=LoadLFM(AnUnitInfo,LFMBuf,OpenFlags,CloseFlags);
end;

function LoadLFM(AnUnitInfo: TUnitInfo; LFMBuf: TCodeBuffer;
  OpenFlags: TOpenFlags; CloseFlags: TCloseFlags): TModalResult;
const
  BufSize = 4096; // allocating mem in 4k chunks helps many mem managers

  ShowCommands: array[TWindowState] of Integer =
    (SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED, SW_SHOWFULLSCREEN);

var
  TxtLFMStream, BinStream: TExtMemoryStream;
  NewComponent: TComponent;
  AncestorType: TComponentClass;
  DesignerForm: TCustomForm;
  NewClassName: String;
  LFMType: String;
  ACaption, AText: String;
  NewUnitName: String;
  AncestorUnitInfo, NestedUnitInfo, LFMUnitInfo: TUnitInfo;
  ReferencesLocked: Boolean;
  LCLVersion: string;
  MissingClasses: TStrings;
  LFMComponentName: string;
  i: Integer;
  NestedClassName: string;
  NestedClass: TComponentClass;
  DisableAutoSize: Boolean;
  PreventAutoSize: Boolean;
  NewControl: TControl;
  ARestoreVisible: Boolean;
  AncestorClass: TComponentClass;
  DsgControl: TCustomDesignControl;
  {$IF (FPC_FULLVERSION >= 30003)}
  DsgDataModule: TDataModule;
  {$ENDIF}
begin
  {$IFDEF IDE_DEBUG}
  debugln('LoadLFM A ',AnUnitInfo.Filename,' IsPartOfProject=',dbgs(AnUnitInfo.IsPartOfProject),' ');
  {$ENDIF}

  ReferencesLocked:=false;
  MissingClasses:=nil;
  NewComponent:=nil;
  try
    if (ofRevert in OpenFlags) and (AnUnitInfo.Component<>nil) then begin
      // the component must be destroyed and recreated => store references
      ReferencesLocked:=true;
      Project1.LockUnitComponentDependencies;
      Project1.UpdateUnitComponentDependencies;

      // close old designer form
      Result:=CloseUnitComponent(AnUnitInfo,CloseFlags);
      if Result<>mrOk then begin
        DebugLn(['LoadLFM CloseUnitComponent failed']);
        exit;
      end;
    end;

    // check installed packages
    if EnvironmentOptions.CheckPackagesOnFormCreate and
       (AnUnitInfo.Component = nil) and
        AnUnitInfo.IsPartOfProject and
       (not (ofProjectLoading in OpenFlags)) then
    begin
      // opening a form of the project -> check installed packages
      Result := PkgBoss.CheckProjectHasInstalledPackages(Project1,
                                       OpenFlags * [ofProjectLoading, ofQuiet] = []);
      if not (Result in [mrOk, mrIgnore]) then
      begin
        DebugLn(['LoadLFM PkgBoss.CheckProjectHasInstalledPackages failed']);
        exit;
      end;
    end;
    {$IFDEF VerboseLFMSearch}
    debugln('LoadLFM LFM file loaded, parsing "',LFMBuf.Filename,'" ...');
    {$ENDIF}

    // someone created a .lfm file -> Update HasResources
    AnUnitInfo.HasResources:=true;

    // find the classname of the LFM, and check for inherited form
    AnUnitInfo.UnitResourceFileformat.QuickCheckResourceBuffer(
      AnUnitInfo.Source,LFMBuf,LFMType,LFMComponentName,
      NewClassName,LCLVersion,MissingClasses);

    {$IFDEF VerboseLFMSearch}
    debugln('LoadLFM LFM="',LFMBuf.Source,'"');
    {$ENDIF}
    if AnUnitInfo.Component=nil then begin
      // load/create new instance

      if (NewClassName='') or (LFMType='') then begin
        DebugLn(['LoadLFM LFM file corrupt']);
        Result:=IDEMessageDialog(lisLFMFileCorrupt,
          Format(lisUnableToFindAValidClassnameIn, [LFMBuf.Filename]),
          mtError,[mbIgnore,mbCancel,mbAbort]);
        exit;
      end;

      // load missing component classes (e.g. ancestor and frames)
      Result:=LoadAncestorDependencyHidden(AnUnitInfo,NewClassName,OpenFlags,
                                           AncestorType,AncestorUnitInfo);
      if Result<>mrOk then begin
        DebugLn(['LoadLFM DoLoadAncestorDependencyHidden failed for ',AnUnitInfo.Filename]);
        exit;
      end;

      if MissingClasses<>nil then begin
        {$IFDEF VerboseLFMSearch}
        DebugLn(['LoadLFM has nested: ',AnUnitInfo.Filename]);
        {$ENDIF}
        for i:=MissingClasses.Count-1 downto 0 do begin
          NestedClassName:=MissingClasses[i];
          {$IFDEF VerboseLFMSearch}
          DebugLn(['LoadLFM nested ',i,' ',MissingClasses.Count,': ',NestedClassName]);
          {$ENDIF}
          if SysUtils.CompareText(NestedClassName,AncestorType.ClassName)=0 then
          begin
            MissingClasses.Delete(i);
          end else begin
            DebugLn(['LoadLFM loading nested class ',NestedClassName,' needed by ',AnUnitInfo.Filename]);
            NestedClass:=nil;
            NestedUnitInfo:=nil;
            Result:=LoadComponentDependencyHidden(AnUnitInfo,NestedClassName,
                      OpenFlags,
                      {$IFDEF EnableNestedComponentsWithoutLFM}
                      false,
                      {$ELSE}
                      true,
                      {$ENDIF}
                      NestedClass,NestedUnitInfo,AncestorClass);
            if Result<>mrOk then begin
              DebugLn(['LoadLFM DoLoadComponentDependencyHidden NestedClassName=',NestedClassName,' failed for ',AnUnitInfo.Filename]);
              exit;
            end;
            if NestedClass<>nil then
              MissingClasses.Objects[i]:=TObject(Pointer(NestedClass))
            else if AncestorClass<>nil then
              MissingClasses.Objects[i]:=TObject(Pointer(AncestorClass));
          end;
        end;
        //DebugLn(['LoadLFM had nested: ',AnUnitInfo.Filename]);
        if AnUnitInfo.ComponentFallbackClasses<>nil then begin
          AnUnitInfo.ComponentFallbackClasses.Free;
          AnUnitInfo.ComponentFallbackClasses:=nil;
        end;
        AnUnitInfo.ComponentFallbackClasses:=MissingClasses;
        MissingClasses:=nil;
      end;

      BinStream:=nil;
      try
        // convert text to binary format
        BinStream:=TExtMemoryStream.Create;
        TxtLFMStream:=TExtMemoryStream.Create;
        try
          {$IFDEF VerboseIDELFMConversion}
          DebugLn(['LoadLFM LFMBuf START =======================================']);
          DebugLn(LFMBuf.Source);
          DebugLn(['LoadLFM LFMBuf END   =======================================']);
          {$ENDIF}
          LFMBuf.SaveToStream(TxtLFMStream);
          AnUnitInfo.ComponentLastLFMStreamSize:=TxtLFMStream.Size;
          TxtLFMStream.Position:=0;

          try
            if AnUnitInfo.ComponentLastBinStreamSize>0 then
              BinStream.Capacity:=AnUnitInfo.ComponentLastBinStreamSize+BufSize;
            AnUnitInfo.UnitResourceFileformat.TextStreamToBinStream(TxtLFMStream, BinStream);
            AnUnitInfo.ComponentLastBinStreamSize:=BinStream.Size;
            BinStream.Position:=0;

            {$IFDEF VerboseIDELFMConversion}
            DebugLn(['LoadLFM Binary START =======================================']);
            debugln(dbgMemStream(BinStream,BinStream.Size));
            DebugLn(['LoadLFM Binary END   =======================================']);
            BinStream.Position:=0;
            {$ENDIF}

            Result:=mrOk;
          except
            on E: Exception do begin
              DumpExceptionBackTrace;
              ACaption:=lisFormatError;
              AText:=Format(lisUnableToConvertTextFormDataOfFileIntoBinaryStream,
                [LineEnding, LFMBuf.Filename, LineEnding, E.Message]);
              Result:=IDEMessageDialog(ACaption, AText, mtError, [mbOk, mbCancel]);
              if Result=mrCancel then Result:=mrAbort;
              exit;
            end;
          end;
        finally
          TxtLFMStream.Free;
        end;
        if ([ofProjectLoading,ofLoadHiddenResource]*OpenFlags=[]) then
          FormEditor1.ClearSelection;

        // create JIT component
        NewUnitName:=AnUnitInfo.Unit_Name;
        if NewUnitName='' then
          NewUnitName:=ExtractFileNameOnly(AnUnitInfo.Filename);
        DisableAutoSize:=true;
        NewComponent:=FormEditor1.CreateRawComponentFromStream(BinStream,
          AnUnitInfo.UnitResourceFileformat,
          AncestorType,copy(NewUnitName,1,255),true,true,DisableAutoSize,AnUnitInfo);
        if (NewComponent is TControl) then begin
          NewControl:=TControl(NewComponent);
          if ofLoadHiddenResource in OpenFlags then
            NewControl.ControlStyle:=NewControl.ControlStyle+[csNoDesignVisible];
          if DisableAutoSize then
          begin
            PreventAutoSize := (IDETabMaster <> nil)
                               and (NewControl is TCustomDesignControl)
                               and IDETabMaster.AutoSizeInShowDesigner(NewControl);
            if not PreventAutoSize then
              NewControl.EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster Delayed'){$ENDIF};
          end;
        end;

        if NewComponent is TCustomDesignControl then
        begin
          DsgControl := TCustomDesignControl(NewComponent);
          if (Project1.Scaled or EnvironmentOptions.ForceDPIScalingInDesignTime)
          and DsgControl.Scaled and (DsgControl.DesignTimePPI<>Screen.PixelsPerInch) then
          begin
            DsgControl.AutoAdjustLayout(lapAutoAdjustForDPI, DsgControl.DesignTimePPI, Screen.PixelsPerInch, 0, 0);
            DesignerProcs.ScaleNonVisual(DsgControl, DsgControl.DesignTimePPI, Screen.PixelsPerInch);
            DsgControl.DesignTimePPI := Screen.PixelsPerInch;
          end;
          DsgControl.PixelsPerInch := Screen.PixelsPerInch;
        end;
        {$IF (FPC_FULLVERSION >= 30003)} // TDataModule.DesignPPI was added in FPC 3.0.3
        if NewComponent is TDataModule then
        begin
          DsgDataModule := TDataModule(NewComponent);
          if (DsgDataModule.DesignPPI<>Screen.PixelsPerInch) then
          begin
            DesignerProcs.ScaleNonVisual(DsgDataModule, DsgDataModule.DesignPPI, Screen.PixelsPerInch);
            DsgDataModule.DesignOffset := Point(
              MulDiv(DsgDataModule.DesignOffset.x, Screen.PixelsPerInch, DsgDataModule.DesignPPI),
              MulDiv(DsgDataModule.DesignOffset.y, Screen.PixelsPerInch, DsgDataModule.DesignPPI));
            DsgDataModule.DesignSize := Point(
              MulDiv(DsgDataModule.DesignSize.x, Screen.PixelsPerInch, DsgDataModule.DesignPPI),
              MulDiv(DsgDataModule.DesignSize.y, Screen.PixelsPerInch, DsgDataModule.DesignPPI));
            DsgDataModule.DesignPPI := Screen.PixelsPerInch;
          end;
        end;
        {$ENDIF}

        if NewComponent<>nil then
          AnUnitInfo.ResourceBaseClass:=GetComponentBaseClass(NewComponent.ClassType);

        Project1.InvalidateUnitComponentDesignerDependencies;
        AnUnitInfo.Component:=NewComponent;
        if (AncestorUnitInfo<>nil) then
          AnUnitInfo.AddRequiresComponentDependency(AncestorUnitInfo,[ucdtAncestor]);
        if NewComponent<>nil then begin
          // component loaded, now load the referenced units
          Result:=MainIDE.DoFixupComponentReferences(AnUnitInfo.Component,OpenFlags);
          if Result<>mrOk then begin
            DebugLn(['LoadLFM DoFixupComponentReferences failed']);
            exit;
          end;
        end else begin
          // error streaming component -> examine lfm file
          DebugLn('ERROR: streaming failed lfm="',LFMBuf.Filename,'"');
          // open lfm file in editor
          if AnUnitInfo.OpenEditorInfoCount > 0 then
            Result:=OpenEditorFile(LFMBuf.Filename,
              AnUnitInfo.OpenEditorInfo[0].PageIndex+1,
              AnUnitInfo.OpenEditorInfo[0].WindowID, Nil,
              OpenFlags+[ofOnlyIfExists,ofQuiet,ofRegularFile], True)
          else
            Result:=OpenEditorFile(LFMBuf.Filename, -1, -1, nil,
              OpenFlags+[ofOnlyIfExists,ofQuiet,ofRegularFile]);
          if Result<>mrOk then begin
            DebugLn(['LoadLFM DoOpenEditorFile failed']);
            exit;
          end;
          LFMUnitInfo:=Project1.UnitWithEditorComponent(SourceEditorManager.ActiveEditor);
          Result:=CheckLFMInEditor(LFMUnitInfo, true);
          if Result=mrOk then Result:=mrCancel;
          exit;
        end;
      finally
        BinStream.Free;
      end;
    end else if SysUtils.CompareText(AnUnitInfo.Component.ClassName,NewClassName)<>0
    then begin
      // lfm and current designer are about different classes
      debugln(['LoadLFM unit="',AnUnitInfo.Filename,'": loaded component has class "',AnUnitInfo.Component.ClassName,'", lfm has class "',NewClassName,'"']);
      // keep old instance, add a designer, so user can see current component
    end else begin
      // make hidden component visible, keep old instance, add a designer
      DebugLn(['LoadLFM Creating designer for hidden component of ',AnUnitInfo.Filename]);
    end;
  finally
    MissingClasses.Free;
    if ReferencesLocked then begin
      if Project1<>nil then
        Project1.UnlockUnitComponentDependencies;
    end;
  end;

  NewComponent:=AnUnitInfo.Component;
  // create the designer (if not already done)
  if ([ofProjectLoading,ofLoadHiddenResource]*OpenFlags=[]) then
    FormEditor1.ClearSelection;
  {$IFDEF IDE_DEBUG}
  DebugLn('SUCCESS: streaming lfm="',LFMBuf.Filename,'"');
  {$ENDIF}
  AnUnitInfo.ComponentName:=NewComponent.Name;
  AnUnitInfo.ComponentResourceName:=AnUnitInfo.ComponentName;
  DesignerForm := nil;
  MainIDE.LastFormActivated := nil;
  if not (ofLoadHiddenResource in OpenFlags) then
  begin
    DesignerForm := FormEditor1.GetDesignerForm(NewComponent);
    if (DesignerForm=nil) or (DesignerForm.Designer=nil) then
      DesignerForm := MainIDE.CreateDesignerForComponent(AnUnitInfo,NewComponent);
  end;

  // select the new form (object inspector, formeditor, control selection)
  if (DesignerForm <> nil)
  and ([ofProjectLoading,ofLoadHiddenResource] * OpenFlags=[]) then
  begin
    MainIDE.DisplayState := dsForm;
    GlobalDesignHook.LookupRoot := NewComponent;
    TheControlSelection.AssignPersistent(NewComponent);
  end;

  // show new form
  if DesignerForm <> nil then
  begin
    DesignerForm.ControlStyle := DesignerForm.ControlStyle - [csNoDesignVisible];
    if NewComponent is TControl then
      TControl(NewComponent).ControlStyle:= TControl(NewComponent).ControlStyle - [csNoDesignVisible];
    if (DesignerForm.WindowState in [wsMinimized]) then
    begin
      ARestoreVisible := DesignerForm.Visible;
      DesignerForm.Visible := False;
      DesignerForm.ShowOnTop;
      DesignerForm.Visible := ARestoreVisible;
      DesignerForm.WindowState := wsMinimized;
    end else
      if IDETabMaster = nil then
        LCLIntf.ShowWindow(DesignerForm.Handle, ShowCommands[AnUnitInfo.ComponentState]);
    MainIDE.LastFormActivated := DesignerForm;
  end;

  {$IFDEF IDE_DEBUG}
  debugln('[LoadLFM] LFM end');
  {$ENDIF}
  Result:=mrOk;
end;

function OpenComponent(const UnitFilename: string;
  OpenFlags: TOpenFlags; CloseFlags: TCloseFlags; out Component: TComponent): TModalResult;
var
  AnUnitInfo: TUnitInfo;
  AFilename, LFMFilename: String;
  UnitCode, LFMCode: TCodeBuffer;
begin
  if Project1=nil then exit(mrCancel);
  // try to find a unit name without expaning the path. this is required if unit is virtual
  // in other case file name will be expanded with the wrong path
  AFilename:=UnitFilename;
  AnUnitInfo:=Project1.UnitInfoWithFilename(AFilename);
  if AnUnitInfo = nil then
  begin
    AFilename:=TrimAndExpandFilename(UnitFilename);
    if (AFilename='') or (not FileExistsInIDE(AFilename,[])) then begin
      DebugLn(['OpenComponent file not found ',AFilename]);
      exit(mrCancel);
    end;
    AnUnitInfo:=Project1.UnitInfoWithFilename(AFilename);
  end;
  if (not (ofRevert in OpenFlags))
  and (AnUnitInfo<>nil) and (AnUnitInfo.Component<>nil) then begin
    // already open
    Component:=AnUnitInfo.Component;
    exit(mrOk);
  end;

  // ToDo: use UnitResources
  LFMFilename:=ChangeFileExt(AFilename,'.lfm');
  if not FileExistsInIDE(LFMFilename,[]) then
    LFMFilename:=ChangeFileExt(AFilename,'.dfm');
  if not FileExistsInIDE(LFMFilename,[]) then begin
    DebugLn(['OpenComponent file not found ',LFMFilename]);
    exit(mrCancel);
  end;

  // load unit source
  Result:=LoadCodeBuffer(UnitCode,AFilename,[lbfCheckIfText],true);
  if Result<>mrOk then begin
    debugln('OpenComponent Failed loading ',AFilename);
    exit;
  end;

  // create unit info
  if AnUnitInfo=nil then begin
    AnUnitInfo:=TUnitInfo.Create(UnitCode);
    AnUnitInfo.ReadUnitNameFromSource(true);
    Project1.AddFile(AnUnitInfo,false);
  end;

  // load lfm source
  Result:=LoadCodeBuffer(LFMCode,LFMFilename,[lbfCheckIfText],true);
  if Result<>mrOk then begin
    debugln('OpenComponent Failed loading ',LFMFilename);
    exit;
  end;

  // load resource
  Result:=LoadLFM(AnUnitInfo,LFMCode,OpenFlags,CloseFlags);
  if Result<>mrOk then begin
    debugln('OpenComponent DoLoadLFM failed ',LFMFilename);
    exit;
  end;

  Component:=AnUnitInfo.Component;
  if Component<>nil then
    Result:=mrOk
  else
    Result:=mrCancel;
end;

function FindBaseComponentClass(AnUnitInfo: TUnitInfo; const AComponentClassName,
  DescendantClassName: string; out AComponentClass: TComponentClass): boolean;
// returns false if an error occurred
// Important: returns true even if AComponentClass=nil
var
  ResFormat: TUnitResourcefileFormatClass;
begin
  AComponentClass:=nil;
  // find the ancestor class
  ResFormat:=AnUnitInfo.UnitResourceFileformat;
  if ResFormat<>nil then
  begin
    AComponentClass:=ResFormat.FindComponentClass(AComponentClassName);
    if AComponentClass<>nil then
      exit(true);
  end;
  if AComponentClassName<>'' then
  begin
    if DescendantClassName<>'' then begin
      if CompareText(AComponentClassName,'TCustomForm')=0 then begin
        // this is a common user mistake
        IDEMessageDialog(lisCodeTemplError,
                      Format(lisTheResourceClassDescendsFromProbablyThisIsATypoFor,
                             [DescendantClassName, AComponentClassName]),
                      mtError,[mbCancel]);
        exit(false);
      end
      else if CompareText(AComponentClassName,'TComponent')=0 then begin
        // this is not yet implemented
        IDEMessageDialog(lisCodeTemplError,
                      Format(lisUnableToOpenDesignerTheClassDoesNotDescendFromADes,
                             [LineEnding, DescendantClassName]),
                      mtError,[mbCancel]);
        exit(false);
      end;
    end;
    // search in the registered base classes
    AComponentClass:=FormEditor1.FindDesignerBaseClassByName(AComponentClassName,true);
  end else begin
    // default is TForm
    AComponentClass:=BaseFormEditor1.StandardDesignerBaseClasses[DesignerBaseClassId_TForm];
  end;
  Result:=true;
end;

function LoadAncestorDependencyHidden(AnUnitInfo: TUnitInfo;
  const aComponentClassName: string; OpenFlags: TOpenFlags;
  out AncestorClass: TComponentClass;
  out AncestorUnitInfo: TUnitInfo): TModalResult;
var
  AncestorClsName, IgnoreBtnText, ClsName: String;
  CodeBuf: TCodeBuffer;
  GrandAncestorClass, DefAncestorClass: TComponentClass;
  ResFormat: TUnitResourcefileFormatClass;
  ClsUnitInfo: TUnitInfo;
begin
  AncestorClass:=nil;
  AncestorUnitInfo:=nil;

  // fallback ancestor is defined by the resource file format of the form/frame/component being loaded
  // this is offered to the user in case a lookup fails
  ResFormat:= AnUnitInfo.UnitResourceFileformat;
  if ResFormat<>nil then
    DefAncestorClass:=ResFormat.DefaultComponentClass
  else
    DefAncestorClass:=nil;
  // use TForm as default ancestor
  if DefAncestorClass=nil then
    DefAncestorClass:=BaseFormEditor1.StandardDesignerBaseClasses[DesignerBaseClassId_TForm];
  IgnoreBtnText:='';
  if DefAncestorClass<>nil then
    IgnoreBtnText:=Format(lisIgnoreUseAsAncestor, [DefAncestorClass.ClassName]);

  // traverse the chain of ancestors until either:
  //   - an error occurs
  //   - FindBaseComponentClass locates an editor class
  //   - LoadComponentDependencyHidden loads a full LFM
  //   - no further class parents exist
  ClsName:=aComponentClassName;
  ClsUnitInfo:=AnUnitInfo;
  repeat
    // if Source is not already loaded, load from Filename
    if not Assigned(ClsUnitInfo.Source) then begin
      Result:=LoadCodeBuffer(CodeBuf,ClsUnitInfo.Filename,
                             [lbfUpdateFromDisk,lbfCheckIfText],true);
      if Result<>mrOk then exit;
      ClsUnitInfo.Source:=CodeBuf;
      if FilenameIsPascalSource(ClsUnitInfo.Filename) then
        ClsUnitInfo.ReadUnitNameFromSource(true);
    end;

    // get ancestor of ClsName from current ClsUnitInfo
    if CodeToolBoss.FindFormAncestor(ClsUnitInfo.Source,ClsName,AncestorClsName,true) then begin
      // is this ancestor a designer class?
      if not FindBaseComponentClass(ClsUnitInfo,AncestorClsName,ClsName,AncestorClass) then
      begin
        DebugLn(['LoadAncestorDependencyHidden FindUnitComponentClass failed for AncsClsName=',AncestorClsName]);
        exit(mrCancel);
      end;

      if Assigned(AncestorClass) then
        break
      else begin
        // immediately go to next ancestor
        ClsName:=AncestorClsName;
        continue;
      end;
    end;
    // -> the declaration of ClsName is not in ClsUnitInfo, let LoadComponentDependencyHidden locate it

    // try loading the ancestor (unit, lfm and component instance)
    Result:=LoadComponentDependencyHidden(ClsUnitInfo,ClsName,
             OpenFlags,false,AncestorClass,AncestorUnitInfo,GrandAncestorClass,
             IgnoreBtnText);
    if Result<>mrOk then begin
      DebugLn(['LoadAncestorDependencyHidden DoLoadComponentDependencyHidden failed ClsUnitInfo=',ClsUnitInfo.Filename]);
    end;
    case Result of
    mrAbort: exit;
    mrOk: ;
    mrIgnore: break;
    else
      // cancel
      exit(mrCancel);
    end;

    // possible outcomes of LoadComponentDependencyHidden:
    if Assigned(AncestorClass) then
      // loaded something and got a component class for it -> done, everything is set
      break
    else if Assigned(AncestorUnitInfo) then
      // loaded the unit containing ClsName, but it does not have the ComponentClass -> let FindFormAncestor/FindBaseComponentClass try again
      ClsUnitInfo:= AncestorUnitInfo
    else begin
      // likely a bug: declaration is nowhere and was not caught by user interaction in LoadComponentDependencyHidden
      DebugLn(['LoadAncestorDependencyHidden DoLoadComponentDependencyHidden empty returns for ClsName=',ClsName, ' ClsUnitInfo=',ClsUnitInfo.Filename]);
      exit(mrCancel);
    end;
  until Assigned(AncestorClass) or (ClsName = '') or not Assigned(ClsUnitInfo);

  if AncestorClass=nil then begin
    // nothing was found, clear any attempted references
    AncestorUnitInfo:= nil;

    //DebugLn('LoadAncestorDependencyHidden Filename="',ClsUnitInfo.Filename,'" AncsClsName=',AncestorClsName,' AncestorClass=',dbgsName(AncestorClass));
    AncestorClass:=DefAncestorClass;
  end;
  Result:=mrOk;
end;

function FindComponentClass(AnUnitInfo: TUnitInfo; const AComponentClassName: string;
  Quiet: boolean; out ComponentUnitInfo: TUnitInfo; out AComponentClass: TComponentClass;
  out LFMFilename: string; out AncestorClass: TComponentClass): TModalResult;
{ Possible results:
  mrOk:
   - AComponentClass<>nil and ComponentUnitInfo<>nil
      designer component
   - AComponentClass<>nil and ComponentUnitInfo=nil
      registered componentclass
   - AComponentClass=nil and ComponentUnitInfo<>nil
      componentclass does not exist, but the unit declaring AComponentClassName was found
   - LFMFilename<>''
      lfm of an used unit
   - AncestorClass<>nil
      componentclass does not exist, but the ancestor is a registered class
  mrCancel:
    not found
  mrAbort:
    not found, error already shown
}
var
  CTErrorMsg: String;
  CTErrorCode: TCodeBuffer;
  CTErrorLine: Integer;
  CTErrorCol: Integer;

  procedure StoreCodetoolsError;
  begin
    {$IFDEF VerboseLFMSearch}
    debugln(['  StoreCodetoolsError: ',CodeToolBoss.ErrorMessage]);
    {$ENDIF}
    if CTErrorMsg<>'' then exit;
    if CodeToolBoss.ErrorMessage<>'' then begin
      CTErrorMsg:=CodeToolBoss.ErrorMessage;
      CTErrorCode:=CodeToolBoss.ErrorCode;
      CTErrorLine:=CodeToolBoss.ErrorLine;
      CTErrorCol:=CodeToolBoss.ErrorColumn;
    end;
  end;

  function TryUnitComponent(const UnitFilename: string;
    out TheModalResult: TModalResult): boolean;
  // returns true if the unit contains the component class and sets
  // TheModalResult to the result of the loading
  var
    CurUnitInfo: TUnitInfo;
  begin
    {$IFDEF VerboseLFMSearch}
    debugln(['  TryUnitComponent UnitFilename="',UnitFilename,'"']);
    {$ENDIF}
    Result:=false;
    TheModalResult:=mrCancel;
    if not FilenameIsPascalUnit(UnitFilename) then exit;

    CurUnitInfo:=Project1.UnitInfoWithFilename(UnitFilename);
    if (CurUnitInfo=nil) or (CurUnitInfo.Component=nil) then exit;
    // unit with loaded component found -> check if it is the right one
    //DebugLn(['FindComponentClass unit with a component found CurUnitInfo=',CurUnitInfo.Filename,' ',dbgsName(CurUnitInfo.Component)]);
    if SysUtils.CompareText(CurUnitInfo.Component.ClassName,AComponentClassName)<>0
    then exit;
    // component found (it was already loaded)
    ComponentUnitInfo:=CurUnitInfo;
    AComponentClass:=TComponentClass(ComponentUnitInfo.Component.ClassType);
    TheModalResult:=mrOk;
    Result:=true;
  end;

  function TryRegisteredClasses(aClassName: string;
    out FoundComponentClass: TComponentClass;
    out TheModalResult: TModalResult): boolean;
  var
    RegComp: TRegisteredComponent;
  begin
    {$IFDEF VerboseLFMSearch}
    debugln(['  TryRegisteredClasses aClassName="',aClassName,'"']);
    {$ENDIF}
    Result:=false;
    TheModalResult:=mrCancel;
    FoundComponentClass:=nil;
    if AnUnitInfo.UnitResourceFileformat<>nil then
      FoundComponentClass:=AnUnitInfo.UnitResourceFileformat.FindComponentClass(aClassName);
    if FoundComponentClass=nil then
    begin
      RegComp:=IDEComponentPalette.FindRegComponent(aClassName);
      if RegComp<>nil then
        FoundComponentClass:=RegComp.ComponentClass;
    end;
    if FoundComponentClass=nil then
      FoundComponentClass:=FormEditor1.FindDesignerBaseClassByName(aClassName,true);
    if FoundComponentClass<>nil then begin
      DebugLn(['FindComponentClass.TryRegisteredClasses found: ',FoundComponentClass.ClassName]);
      TheModalResult:=mrOk;
      Result:=true;
    end;
  end;

  function TryLFM(const UnitFilename, AClassName: string;
    out TheModalResult: TModalResult): boolean;
  var
    CurLFMFilename: String;
    LFMCode: TCodeBuffer;
    LFMClassName: String;
    LFMType: String;
  begin
    {$IFDEF VerboseLFMSearch}
    debugln(['  TryLFM UnitFilename="',UnitFilename,'" AClassName=',AClassName]);
    {$ENDIF}
    Result:=false;
    TheModalResult:=mrCancel;
    if not FilenameIsPascalSource(UnitFilename) then
    begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryLFM UnitFilename="',UnitFilename,'" is not a unit']);
      {$ENDIF}
      exit;
    end;
    // ToDo: use UnitResources
    CurLFMFilename:=ChangeFileExt(UnitFilename,'.lfm');
    if not FileExistsCached(CurLFMFilename) then
    begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryLFM CurLFMFilename="',CurLFMFilename,'" does not exist']);
      {$ENDIF}
      CurLFMFilename:=ChangeFileExt(UnitFilename,'.dfm');
      if not FileExistsCached(CurLFMFilename) then
      begin
        {$IFDEF VerboseLFMSearch}
        debugln(['  TryLFM CurLFMFilename="',CurLFMFilename,'" does not exist']);
        {$ENDIF}
        exit;
      end;
    end;
    // load the lfm file
    TheModalResult:=LoadCodeBuffer(LFMCode,CurLFMFilename,[lbfCheckIfText],true);
    if TheModalResult<>mrOk then
    begin
      debugln('FindComponentClass Failed loading ',CurLFMFilename);
      exit;
    end;
    // read the LFM classname
    ReadLFMHeader(LFMCode.Source,LFMClassName,LFMType);
    if LFMType='' then ;
    if SysUtils.CompareText(LFMClassName,AClassName)<>0 then
    begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryLFM CurLFMFilename="',CurLFMFilename,'" LFMClassName="',LFMClassName,'" does not match']);
      {$ENDIF}
      exit;
    end;

    // .lfm found
    LFMFilename:=CurLFMFilename;
    Result:=true;
  end;

  procedure StoreComponentClassDeclaration(UnitFilename: string);
  begin
    // The Unit declaring AComponentClassName was located, save UnitInfo for return regardless of AComponentClass instance
    ComponentUnitInfo:= Project1.UnitInfoWithFilename(UnitFilename);
    if not Assigned(ComponentUnitInfo) then begin
      // File was not previously loaded, add reference to project (without loading source for now)
      ComponentUnitInfo:=TUnitInfo.Create(nil);
      ComponentUnitInfo.Filename:=UnitFilename;
      ComponentUnitInfo.IsPartOfProject:=false;
      Project1.AddFile(ComponentUnitInfo,false);
    end;
  end;

  function TryFindDeclaration(out TheModalResult: TModalResult): boolean;
  var
    Tool: TCodeTool;

    function FindTypeNode(Node: TCodeTreeNode; Level: integer): TCodeTreeNode;
    var
      TypeNode: TCodeTreeNode;
      Child: TCodeTreeNode;
    begin
      Result:=nil;
      if Node=nil then exit;
      if Node.Desc=ctnVarDefinition then begin
        TypeNode:=Tool.FindTypeNodeOfDefinition(Node);
        if (TypeNode=nil) or (TypeNode.Desc<>ctnIdentifier) then exit;
        if Tool.CompareSrcIdentifiers(TypeNode.StartPos,PChar(AComponentClassName))
        then exit(TypeNode);
      end else if Node.Desc=ctnTypeDefinition then begin
        if Tool.CompareSrcIdentifiers(Node.StartPos,PChar(AComponentClassName))
        then exit(Node);
      end;
      // increase level on identifier nodes
      if Node.Desc in AllIdentifierDefinitions then begin
        if Level=1 then exit; // ignore nested vars
        inc(Level);
      end;
      Child:=Node.FirstChild;
      while Child<>nil do begin
        Result:=FindTypeNode(Child,Level);
        if Result<>nil then exit;
        Child:=Child.NextBrother;
      end;
    end;

  var
    Code: TCodeBuffer;
    Params: TFindDeclarationParams;
    NewNode: TCodeTreeNode;
    NewTool: TFindDeclarationTool;
    InheritedNode: TCodeTreeNode;
    ClassNode: TCodeTreeNode;
    AncestorNode: TCodeTreeNode;
    AncestorClassName: String;
    Node: TCodeTreeNode;
    ok: Boolean;
  begin
    Result:=false;
    TheModalResult:=mrCancel;
    // parse interface current unit
    Code:=CodeToolBoss.LoadFile(AnUnitInfo.Filename,false,false);
    if Code=nil then begin
      debugln(['FindComponentClass unable to load ',AnUnitInfo.Filename]);
      exit;
    end;
    if not CodeToolBoss.Explore(Code,Tool,false,true) then begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  CodeToolBoss.Explore failed: ',Code.Filename]);
      {$ENDIF}
      StoreCodetoolsError;
      exit;
    end;
    Params:=TFindDeclarationParams.Create;
    try
      ok:=false;
      try
        // search a class reference in the unit
        Node:=Tool.FindInterfaceNode;
        if Node=nil then
          Node:=Tool.Tree.Root;
        Node:=FindTypeNode(Node,0);
        if Node=nil then begin
          debugln('FindComponentClass Failed finding reference of ',AComponentClassName,' in ',Code.Filename);
          exit;
        end;
        if Node.Desc=ctnIdentifier then begin
          //debugln(['TryFindDeclaration found reference of ',AComponentClassName,' at ',Tool.CleanPosToStr(Node.StartPos)]);
          Params.ContextNode:=Node;
          Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound,
                         fdfExceptionOnPredefinedIdent,
                         fdfTopLvlResolving,fdfSearchInAncestors,
                         fdfIgnoreCurContextNode];
          Params.SetIdentifier(Tool,@Tool.Src[Node.StartPos],nil);
          if not Tool.FindIdentifierInContext(Params) then begin
            debugln(['FindComponentClass find declaration failed at ',Tool.CleanPosToStr(Node.StartPos,true)]);
            exit;
          end;
          NewNode:=Params.NewNode;
          NewTool:=Params.NewCodeTool;
        end else begin
          NewNode:=Node;
          NewTool:=Tool;
        end;
        ok:=true;
      except
        on E: Exception do
          CodeToolBoss.HandleException(E);
      end;
      if not ok then begin
        {$IFDEF VerboseLFMSearch}
        debugln(['  find declaration failed.']);
        {$ENDIF}
        StoreCodetoolsError;
        exit;
      end;
      // declaration found
      ClassNode:=NewNode.FirstChild;
      if (NewNode.Desc<>ctnTypeDefinition)
      or (ClassNode=nil) or (ClassNode.Desc<>ctnClass) then
      begin
        debugln(['FindComponentClass ',AComponentClassName,' is not a class at ',NewTool.CleanPosToStr(NewNode.StartPos,true)]);
        exit;
      end;
      // find inheritance list
      InheritedNode:=ClassNode.FirstChild;
      while (InheritedNode<>nil) and (InheritedNode.Desc<>ctnClassInheritance) do
        InheritedNode:=InheritedNode.NextBrother;
      if (InheritedNode=nil) or (InheritedNode.FirstChild=nil) then begin
        debugln(['FindComponentClass ',AComponentClassName,' is not a TComponent at ',NewTool.CleanPosToStr(NewNode.StartPos,true)]);
        exit;
      end;
      StoreComponentClassDeclaration(NewTool.MainFilename);
      AncestorNode:=InheritedNode.FirstChild;
      AncestorClassName:=GetIdentifier(@NewTool.Src[AncestorNode.StartPos]);
      //debugln(['TryFindDeclaration declaration of ',AComponentClassName,' found at ',NewTool.CleanPosToStr(NewNode.StartPos),' ancestor="',AncestorClassName,'"']);

      // try unit component
      if TryUnitComponent(NewTool.MainFilename,TheModalResult) then
        exit(true);

      // try lfm
      if TryLFM(NewTool.MainFilename,AComponentClassName,TheModalResult) then
        exit(true);

      // search ancestor in registered classes
      if TryRegisteredClasses(AncestorClassName,AncestorClass,TheModalResult) then
        exit(true);

      {$IFDEF VerboseLFMSearch}
      debugln(['TryFindDeclaration declaration of ',AComponentClassName,' found at ',NewTool.CleanPosToStr(NewNode.StartPos),' Ancestor="',AncestorClassName,'", but no lfm and no registered class found']);
      {$ENDIF}
    finally
      Params.Free;
    end;
  end;

  function TryUsedUnitInterface(UnitFilename: string; out TheModalResult: TModalResult): boolean;
  var
    Code: TCodeBuffer;
    AncestorClassName: string;
  begin
    {$IFDEF VerboseLFMSearch}
    debugln(['  TryUsedUnitInterface UnitFilename="',UnitFilename,'"']);
    {$ENDIF}
    Result:=false;
    TheModalResult:=mrCancel;
    if not FilenameIsPascalSource(UnitFilename) then
    begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryUsedUnitInterface UnitFilename="',UnitFilename,'" is not a unit']);
      {$ENDIF}
      exit;
    end;
    Code:=CodeToolBoss.LoadFile(UnitFilename,true,false);
    if Code=nil then begin
      debugln(['FindComponentClass unable to load ',AnUnitInfo.Filename]);
      exit;
    end;
    if not CodeToolBoss.FindFormAncestor(Code,AComponentClassName,AncestorClassName,true) then
    begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryUsedUnitInterface FindFormAncestor failed for "',AComponentClassName,'"']);
      {$ENDIF}
      StoreCodetoolsError;
      exit;
    end;
    if AncestorClassName='' then begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryUsedUnitInterface FindFormAncestor failed silently for "',AComponentClassName,'"']);
      {$ENDIF}
      exit;
    end;
    StoreComponentClassDeclaration(UnitFilename);
    if TryRegisteredClasses(AncestorClassName,AncestorClass,TheModalResult) then
      exit(true);
  end;

var
  UsedUnitFilenames: TStrings;
  i: Integer;
begin
  Result:=mrCancel;
  AComponentClass:=nil;
  ComponentUnitInfo:=nil;
  AncestorClass:=nil;
  LFMFilename:='';
  CTErrorMsg:='';
  CTErrorCode:=nil;
  CTErrorLine:=0;
  CTErrorCol:=0;

  if not IsValidIdent(AComponentClassName) then
  begin
    DebugLn(['FindComponentClass invalid component class name "',AComponentClassName,'"']);
    exit(mrCancel);
  end;

  // search component lfm
  {$ifdef VerboseFormEditor}
  debugln('FindComponentClass START ',AnUnitInfo.Filename,' AComponentClassName=',AComponentClassName);
  {$endif}
  // first search the resource of AnUnitInfo
  if AnUnitInfo<>nil then begin
    if TryUnitComponent(AnUnitInfo.Filename,Result) then exit;
  end;

  // then try registered global classes
  if TryRegisteredClasses(AComponentClassName,AComponentClass,Result) then exit;

  // search in used units
  UsedUnitFilenames:=nil;
  try
    if not CodeToolBoss.FindUsedUnitFiles(AnUnitInfo.Source,UsedUnitFilenames)
    then begin
      MainIDE.DoJumpToCodeToolBossError;
      exit(mrCancel);
    end;

    {$IFDEF VerboseLFMSearch}
    if (UsedUnitFilenames=nil) or (UsedUnitFilenames.Count=0) then
      debugln(['FindComponentClass unit has no main uses']);
    {$ENDIF}

    if (UsedUnitFilenames<>nil) then begin
      // search for every used unit the .lfm file
      for i:=UsedUnitFilenames.Count-1 downto 0 do begin
        if TryLFM(UsedUnitFilenames[i],AComponentClassName,Result) then exit;
      end;
      // search class via codetools
      if TryFindDeclaration(Result) then exit;
      // search the class in every used unit
      for i:=UsedUnitFilenames.Count-1 downto 0 do begin
        if TryUsedUnitInterface(UsedUnitFilenames[i],Result) then exit;
      end;
    end;
  finally
    UsedUnitFilenames.Free;
  end;

  // no 100% loadable match found, did we at least get a ComponentUnitInfo?
  if Assigned(ComponentUnitInfo) then
    // Return "located, but not loaded" information
    Result:= mrOK
  else
    Result:= mrCancel;

  // not found
  if Quiet then exit;

  // show codetool error
  if CTErrorMsg<>'' then begin
    CodeToolBoss.SetError(20170421203251,CTErrorCode,CTErrorLine,CTErrorCol,CTErrorMsg);
    MainIDE.DoJumpToCodeToolBossError;
    Result:=mrAbort;
  end;
end;

function LoadComponentDependencyHidden(AnUnitInfo: TUnitInfo;
  const AComponentClassName: string; Flags: TOpenFlags; MustHaveLFM: boolean;
  out AComponentClass: TComponentClass; out ComponentUnitInfo: TUnitInfo;
  out AncestorClass: TComponentClass; const IgnoreBtnText: string): TModalResult;
{ Possible results:
  mrOk:
   - AComponentClass<>nil and ComponentUnitInfo<>nil
      designer component
   - AComponentClass<>nil and ComponentUnitInfo=nil
      registered componentclass
   - AComponentClass=nil and ComponentUnitInfo<>nil
      componentclass does not exist, but the unit declaring AComponentClassName was found
   - Only for MustHaveLFM=false: AncestorClass<>nil
      componentclass does not exist, but the ancestor is a registered class
  mrCancel:
    not found, skip this form
  mrAbort:
    not found, user wants to stop all pending operations
  mrIgnore:
    not found, user wants to skip this step and continue
}

  function TryLFM(LFMFilename: string): TModalResult;
  var
    UnitFilename: String;
    CurUnitInfo: TUnitInfo;
    LFMCode: TCodeBuffer;
    LFMClassName: String;
    LFMType: String;
    UnitCode: TCodeBuffer;
  begin
    // load lfm
    Result:=LoadCodeBuffer(LFMCode,LFMFilename,[lbfCheckIfText],true);
    if Result<>mrOk then begin
      {$IFDEF VerboseLFMSearch}
      debugln(['  TryLFM LoadCodeBuffer failed ',LFMFilename]);
      {$ENDIF}
      exit;
    end;
    // check if the unit component is already loaded
    UnitFilename:=ChangeFileExt(LFMFilename,'.pas');
    CurUnitInfo:=Project1.UnitInfoWithFilename(UnitFilename);
    if CurUnitInfo=nil then begin
      UnitFilename:=ChangeFileExt(LFMFilename,'.pp');
      CurUnitInfo:=Project1.UnitInfoWithFilename(UnitFilename);
    end;
    ReadLFMHeader(LFMCode.Source,LFMClassName,LFMType);
    if CurUnitInfo=nil then
    begin
      // load unit source
      UnitFilename:=ChangeFileExt(LFMFilename,'.pas');
      if not FileExistsCached(UnitFilename) then
        UnitFilename:=ChangeFileExt(LFMFilename,'.pp');
      Result:=LoadCodeBuffer(UnitCode,UnitFilename,[lbfCheckIfText],true);
      if Result<>mrOk then
        exit;
      // create unit info
      CurUnitInfo:=TUnitInfo.Create(UnitCode);
      CurUnitInfo.ReadUnitNameFromSource(true);
      Project1.AddFile(CurUnitInfo,false);
    end
    else if (CurUnitInfo.Component<>nil) then
    begin
      // component already loaded
      if SysUtils.CompareText(CurUnitInfo.Component.ClassName,LFMClassName)<>0
      then begin
        {$IFDEF VerboseLFMSearch}
        debugln(['  TryLFM ERROR lfmclass=',LFMClassName,' unit.component=',DbgSName(CurUnitInfo.Component)]);
        {$ENDIF}
        IDEMessageDialog('Error','Unable to load "'+LFMFilename+'".'
          +' The component '+DbgSName(CurUnitInfo.Component)
          +' is already loaded for unit "'+CurUnitInfo.Filename+'"'#13
          +'LFM contains a different class name "'+LFMClassName+'".',
          mtError,[mbCancel]);
        exit(mrAbort);
      end;
      ComponentUnitInfo:=CurUnitInfo;
      AComponentClass:=TComponentClass(ComponentUnitInfo.Component.ClassType);
      exit(mrOK);
    end;

    // load resource hidden
    Result:=LoadLFM(CurUnitInfo,LFMCode,Flags+[ofLoadHiddenResource],[]);
    if Result=mrOk then
    begin
      ComponentUnitInfo:=CurUnitInfo;
      AComponentClass:=TComponentClass(ComponentUnitInfo.Component.ClassType);
      {$if defined(VerboseFormEditor) or defined(VerboseLFMSearch)}
      debugln('LoadComponentDependencyHidden Wanted=',AComponentClassName,' Class=',AComponentClass.ClassName);
      {$endif}
    end else begin
      debugln('LoadComponentDependencyHidden Failed to load component ',AComponentClassName);
      Result:=mrCancel;
    end;
  end;

var
  Quiet, HideAbort: Boolean;
  LFMFilename, MsgText: string;
begin
  Result:=mrCancel;
  AComponentClass:=nil;
  Quiet:=([ofProjectLoading,ofQuiet]*Flags<>[]);
  HideAbort:=not (ofProjectLoading in Flags);

{  Will be checked in FindComponentClass()
  if not IsValidIdent(AComponentClassName) then
  begin
    DebugLn(['LoadComponentDependencyHidden invalid component class name "',AComponentClassName,'"']);
    exit(mrCancel);
  end;
}

  // check for cycles
  if AnUnitInfo.LoadingComponent then begin
    Result:=IDEQuestionDialogAb(lisCodeTemplError,
      Format(lisUnableToLoadTheComponentClassBecauseItDependsOnIts, [AComponentClassName]),
      mtError, [mrCancel, lisCancelLoadingThisComponent], HideAbort);
    exit;
  end;

  AnUnitInfo.LoadingComponent:=true;
  try
    // search component lfm
    {$if defined(VerboseFormEditor) or defined(VerboseLFMSearch)}
    debugln('LoadComponentDependencyHidden ',AnUnitInfo.Filename,' AComponentClassName=',AComponentClassName,
      ' AComponentClass=',dbgsName(AComponentClass));
    {$endif}
    Result:=FindComponentClass(AnUnitInfo,AComponentClassName,Quiet,
      ComponentUnitInfo,AComponentClass,LFMFilename,AncestorClass);
    { $if defined(VerboseFormEditor) or defined(VerboseLFMSearch)}
    debugln('LoadComponentDependencyHidden ',AnUnitInfo.Filename,' AComponentClassName=',AComponentClassName,
      ' AComponentClass=',dbgsName(AComponentClass),' AncestorClass=',DbgSName(AncestorClass),' LFMFilename=',LFMFilename);
    { $endif}

    //- AComponentClass<>nil and ComponentUnitInfo<>nil
    //   designer component
    //- AComponentClass<>nil and ComponentUnitInfo=nil
    //   registered componentclass
    //- AComponentClass=nil and ComponentUnitInfo<>nil
    //   componentclass does not exist, but the unit declaring AComponentClassName was found
    //- LFMFilename<>''
    //   lfm of an used unit
    //- AncestorClass<>nil
    //   componentclass does not exist, but the ancestor is a registered class

    if (Result=mrOk) and (AComponentClass=nil) and (LFMFilename<>'') then
      exit(TryLFM(LFMFilename));

    if MustHaveLFM and (AComponentClass=nil) then
      Result:=mrCancel;
    if Result=mrAbort then exit;
    if Result<>mrOk then begin
      MsgText:=Format(lisUnableToFindTheComponentClassItIsNotRegisteredViaR, [
          AComponentClassName, LineEnding, LineEnding, LineEnding, AnUnitInfo.Filename]);
      if IgnoreBtnText<>'' then
        Result:=IDEQuestionDialogAb(lisCodeTemplError, MsgText, mtError,
                  [mrCancel, lisCancelLoadingThisComponent,
                   mrIgnore, IgnoreBtnText], HideAbort)
      else
        Result:=IDEQuestionDialogAb(lisCodeTemplError, MsgText, mtError,
                  [mrCancel, lisCancelLoadingThisComponent], HideAbort);
    end;
  finally
    AnUnitInfo.LoadingComponent:=false;
  end;
end;

function LoadIDECodeBuffer(var ACodeBuffer: TCodeBuffer;
  const AFilename: string; Flags: TLoadBufferFlags; ShowAbort: boolean): TModalResult;
begin
  if (Project1<>nil)
  and (Project1.UnitInfoWithFilename(AFilename,[pfsfOnlyEditorFiles])<>nil) then
    Exclude(Flags,lbfUpdateFromDisk);
  Result:=LoadCodeBuffer(ACodeBuffer,AFilename,Flags,ShowAbort);
end;

function CloseUnitComponent(AnUnitInfo: TUnitInfo; Flags: TCloseFlags): TModalResult;

  procedure FreeUnusedComponents;
  var
    CompUnitInfo: TUnitInfo;
  begin
    CompUnitInfo:=Project1.FirstUnitWithComponent;
    Project1.UpdateUnitComponentDependencies;
    while CompUnitInfo<>nil do begin
      //DebugLn(['FreeUnusedComponents ',CompUnitInfo.Filename,' ',dbgsName(CompUnitInfo.Component),' UnitComponentIsUsed=',UnitComponentIsUsed(CompUnitInfo,true)]);
      if not UnitComponentIsUsed(CompUnitInfo,true) then begin
        // close the unit component
        CloseUnitComponent(CompUnitInfo,Flags);
        // this has recursively freed all components, so exit here
        exit;
      end;
      CompUnitInfo:=CompUnitInfo.NextUnitWithComponent;
    end;
  end;

var
  OldDesigner: TIDesigner;
  AForm: TCustomForm;
  LookupRoot: TComponent;
  ComponentStillUsed: Boolean;
begin
  LookupRoot:=AnUnitInfo.Component;
  if LookupRoot=nil then exit(mrOk);
  {$IFDEF VerboseIDEMultiForm}
  DebugLn(['CloseUnitComponent ',AnUnitInfo.Filename,' ',dbgsName(LookupRoot)]);
  {$ENDIF}

  Project1.LockUnitComponentDependencies; // avoid circles
  try
    // save
    if (cfSaveFirst in Flags) and (AnUnitInfo.OpenEditorInfoCount > 0)
    and (not AnUnitInfo.IsReverting) then begin
      Result:=SaveEditorFile(AnUnitInfo.OpenEditorInfo[0].EditorComponent,[sfCheckAmbiguousFiles]);
      if Result<>mrOk then begin
        DebugLn(['CloseUnitComponent DoSaveEditorFile failed']);
        exit;
      end;
    end;

    // close dependencies
    if cfCloseDependencies in Flags then begin
      {$IFDEF VerboseIDEMultiForm}
      DebugLn(['CloseUnitComponent cfCloseDependencies ',AnUnitInfo.Filename,' ',dbgsName(LookupRoot)]);
      {$ENDIF}
      Result:=CloseDependingUnitComponents(AnUnitInfo,Flags);
      if Result<>mrOk then begin
        DebugLn(['CloseUnitComponent CloseDependingUnitComponents failed']);
        exit;
      end;
      // now only soft dependencies are left. The component can be freed.
    end;

    AForm:=FormEditor1.GetDesignerForm(LookupRoot);
    if AForm<>nil then
      OldDesigner:=AForm.Designer
    else
      OldDesigner:=nil;
    if MainIDE.LastFormActivated=AForm then
      MainIDE.LastFormActivated:=nil;
    ComponentStillUsed:=(not (cfCloseDependencies in Flags))
                        and UnitComponentIsUsed(AnUnitInfo,false);
    {$IFDEF VerboseTFrame}
    DebugLn(['CloseUnitComponent ',AnUnitInfo.Filename,' ComponentStillUsed=',ComponentStillUsed,' UnitComponentIsUsed=',UnitComponentIsUsed(AnUnitInfo,false),' ',dbgs(AnUnitInfo.Flags),' DepAncestor=',AnUnitInfo.FindUsedByComponentDependency([ucdtAncestor])<>nil,' DepInline=',AnUnitInfo.FindUsedByComponentDependency([ucdtInlineClass])<>nil]);
    {$ENDIF}
    if (OldDesigner=nil) then begin
      // hidden component
      //DebugLn(['CloseUnitComponent freeing hidden component without designer: ',AnUnitInfo.Filename,' ',DbgSName(AnUnitInfo.Component)]);
      if ComponentStillUsed then begin
        // hidden component is still used => keep it
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['CloseUnitComponent hidden component is still used => keep it ',AnUnitInfo.Filename,' ',DbgSName(AnUnitInfo.Component)]);
        {$ENDIF}
      end else begin
        // hidden component is not used => free it
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['CloseUnitComponent hidden component is not used => free it ',AnUnitInfo.Filename,' ',DbgSName(AnUnitInfo.Component)]);
        {$ENDIF}
        try
          FormEditor1.DeleteComponent(LookupRoot,true);
        finally
          AnUnitInfo.Component:=nil;
        end;
        FreeUnusedComponents;
      end;
    end else begin
      // component with designer
      AnUnitInfo.LoadedDesigner:=false;
      if ComponentStillUsed then begin
        // free designer, keep component hidden
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['CloseUnitComponent hiding component and freeing designer: ',AnUnitInfo.Filename,' ',DbgSName(AnUnitInfo.Component)]);
        {$ENDIF}
        OldDesigner.PrepareFreeDesigner(false);
      end else begin
        // free designer and design form
        {$IFDEF VerboseIDEMultiForm}
        DebugLn(['CloseUnitComponent freeing component and designer: ',AnUnitInfo.Filename,' ',DbgSName(AnUnitInfo.Component)]);
        {$ENDIF}
        try
          OldDesigner.PrepareFreeDesigner(true);
        finally
          AnUnitInfo.Component:=nil;
        end;
      end;
      Project1.InvalidateUnitComponentDesignerDependencies;
      FreeUnusedComponents;
    end;
  finally
    Project1.UnlockUnitComponentDependencies;
  end;
  Result:=mrOk;
end;

function CloseDependingUnitComponents(AnUnitInfo: TUnitInfo; Flags: TCloseFlags): TModalResult;
var
  UserAsked: Boolean;

  function CloseNext(var ModResult: TModalresult;
    Types: TUnitCompDependencyTypes): boolean;
  var
    DependingUnitInfo: TUnitInfo;
    DependenciesFlags: TCloseFlags;
  begin
    ModResult:=mrOk;
repeat
      DependingUnitInfo:=Project1.UnitUsingComponentUnit(AnUnitInfo,Types);
      if DependingUnitInfo=nil then break;
      if (not UserAsked) and (not (cfQuiet in Flags))
      and (not DependingUnitInfo.IsReverting) then begin
        // ToDo: collect in advance all components to close and show user the list
        ModResult:=IDEQuestionDialog('Close component?',
          'Close component '+dbgsName(DependingUnitInfo.Component)+'?',
          mtConfirmation,[mrYes,mrAbort]);
        if ModResult<>mrYes then exit(false);
        UserAsked:=true;
      end;
      // close recursively
      DependenciesFlags:=Flags+[cfCloseDependencies];
      if cfSaveDependencies in Flags then
        Include(DependenciesFlags,cfSaveFirst);
      ModResult:=CloseUnitComponent(DependingUnitInfo,DependenciesFlags);
      if ModResult<>mrOk then exit(false);
    until false;
    ModResult:=mrOk;
    Result:=true;
  end;

begin
  Result:=mrOk;
  UserAsked:=false;
  Project1.LockUnitComponentDependencies;
  try
    // Important:
    // This function is called recursively.
    // It is important that first the hard, non cyclic dependencies
    // are freed in the correct order.
    // After that the soft, cyclic dependencies can be freed in any order.

    // first close all descendants recursively
    // This must happen in the right order (descendants before ancestor)
    if not CloseNext(Result,[ucdtAncestor]) then exit;

    // then close all nested descendants recursively
    // This must happen in the right order (nested descendants before ancestor)
    if not CloseNext(Result,[ucdtInlineClass]) then exit;

    // then close all referring components
    // These can build cycles and can be freed in any order.
    if not CloseNext(Result,[ucdtProperty]) then exit;
  finally
    Project1.UnlockUnitComponentDependencies;
  end;
  Result:=mrOk;
end;

function UnitComponentIsUsed(AnUnitInfo: TUnitInfo;
  CheckHasDesigner: boolean): boolean;
// if CheckHasDesigner=true and AnUnitInfo has a designer (visible) return true
// otherwise check if another unit needs AnUnitInfo
var
  LookupRoot: TComponent;
begin
  Result:=false;
  LookupRoot:=AnUnitInfo.Component;
  if LookupRoot=nil then exit;
  // check if a designer or another component uses this component
  Project1.UpdateUnitComponentDependencies;
  if Project1.UnitComponentIsUsed(AnUnitInfo,CheckHasDesigner) then
    exit(true);
  //DebugLn(['UnitComponentIsUsed ',AnUnitInfo.Filename,' ',dbgs(AnUnitInfo.Flags)]);
end;

function RemoveFilesFromProject(UnitInfos: TFPList): TModalResult;
var
  AnUnitInfo: TUnitInfo;
  ShortUnitName, UnitPath: String;
  ObsoleteUnitPaths, ObsoleteIncPaths: String;
  i: Integer;
  SomeRemoved: Boolean;
begin
  Result:=mrOk;
  Assert(Assigned(UnitInfos));
  // check ToolStatus
  if (MainIDE.ToolStatus in [itCodeTools,itCodeToolAborting]) then begin
    debugln('RemoveUnitsFromProject wrong ToolStatus ',dbgs(ord(MainIDE.ToolStatus)));
    exit;
  end;
  // commit changes from source editor to codetools
  SaveEditorChangesToCodeCache(nil);
  SomeRemoved:=false;
  ObsoleteUnitPaths:='';
  ObsoleteIncPaths:='';
  Project1.BeginUpdate(true);
  try
    for i:=0 to UnitInfos.Count-1 do
    begin
      AnUnitInfo:=TUnitInfo(UnitInfos[i]);
      if not AnUnitInfo.IsPartOfProject then continue;
      UnitPath:=ChompPathDelim(ExtractFilePath(AnUnitInfo.Filename));
      AnUnitInfo.IsPartOfProject:=false;
      SomeRemoved:=true;
      Project1.Modified:=true;
      if FilenameIsPascalUnit(AnUnitInfo.Filename) then
      begin
        if FilenameIsAbsolute(AnUnitInfo.Filename) then
          ObsoleteUnitPaths:=MergeSearchPaths(ObsoleteUnitPaths,UnitPath);
        // remove from project's unit section
        if (Project1.MainUnitID>=0)
        and (pfMainUnitIsPascalSource in Project1.Flags)
        then begin
          ShortUnitName:=ExtractFileNameOnly(AnUnitInfo.Filename);
          if (ShortUnitName<>'') then begin
            if not CodeToolBoss.RemoveUnitFromAllUsesSections(
                                 Project1.MainUnitInfo.Source,ShortUnitName) then
            begin
              MainIDE.DoJumpToCodeToolBossError;
              exit(mrCancel);
            end;
          end;
        end;
        // remove CreateForm statement from project
        if (Project1.MainUnitID>=0) and (AnUnitInfo.ComponentName<>'')
        and (pfMainUnitHasCreateFormStatements in Project1.Flags) then
          // Do not care if this fails. A user may have removed the line from source.
          Project1.RemoveCreateFormFromProjectFile(AnUnitInfo.ComponentName);
      end;
      if FilenameExtIs(AnUnitInfo.Filename,'inc') then
        // include file
        if FilenameIsAbsolute(AnUnitInfo.Filename) then
          ObsoleteIncPaths:=MergeSearchPaths(ObsoleteIncPaths,UnitPath);
    end;
    if not SomeRemoved then exit;  // No units were actually removed.

    // removed directories still used for ObsoleteUnitPaths, ObsoleteIncPaths
    AnUnitInfo:=Project1.FirstPartOfProject;
    while AnUnitInfo<>nil do begin
      if FilenameIsAbsolute(AnUnitInfo.Filename) then begin
        UnitPath:=ChompPathDelim(ExtractFilePath(AnUnitInfo.Filename));
        if FilenameIsPascalUnit(AnUnitInfo.Filename) then
          ObsoleteUnitPaths:=RemoveSearchPaths(ObsoleteUnitPaths,UnitPath);
        if FilenameExtIs(AnUnitInfo.Filename,'inc') then
          ObsoleteIncPaths:=RemoveSearchPaths(ObsoleteIncPaths,UnitPath);
      end;
      AnUnitInfo:=AnUnitInfo.NextPartOfProject;
    end;

    // check if compiler options contain paths of ObsoleteUnitPaths
    if ObsoleteUnitPaths<>'' then
      RemovePathFromBuildModes(ObsoleteUnitPaths, pcosUnitPath);
    // or paths of ObsoleteIncPaths
    if ObsoleteIncPaths<>'' then
      RemovePathFromBuildModes(ObsoleteIncPaths, pcosIncludePath);

  finally
    // all changes were handled automatically by events, just clear the logs
    if SomeRemoved then
      CodeToolBoss.SourceCache.ClearAllSourceLogEntries;
    Project1.EndUpdate;
  end;
end;

// methods for open project, create project from source

function CompleteLoadingProjectInfo: TModalResult;
begin
  MainIDE.UpdateCaption;
  EnvironmentOptions.LastSavedProjectFile:=Project1.ProjectInfoFile;
  MainIDE.SaveEnvironment;

  MainBuildBoss.SetBuildTargetProject1(false);

  // load required packages
  PkgBoss.OpenProjectDependencies(Project1, MainIDE.IDEStarted);
  Project1.DefineTemplates.Active:=true;
  MainIDE.UpdateDefineTemplates;
  Result:=mrOk;
end;

// Methods for 'save project'

function SaveProjectInfo(var Flags: TSaveFlags): TModalResult;
var
  MainUnitInfo: TUnitInfo;
  MainUnitSrcEdit: TSourceEditor;
  DestFilename: String;
  SkipSavingMainSource: Boolean;
begin
  Result:=mrOk;
  Project1.ActiveWindowIndexAtStart := SourceEditorManager.ActiveSourceWindowIndex;

  // update source notebook page names
  UpdateSourceNames;

  // find mainunit
  GetMainUnit(MainUnitInfo, MainUnitSrcEdit);

  // save project specific settings of the source editor
  SaveSourceEditorProjectSpecificSettings;

  if Project1.IsVirtual
  and (not (sfDoNotSaveVirtualFiles in Flags)) then
    Include(Flags,sfSaveAs);
  if ([sfSaveAs,sfSaveToTestDir]*Flags=[sfSaveAs]) then begin
    // let user choose a filename
    Result:=ShowSaveProjectAsDialog(sfSaveMainSourceAs in Flags);
    if Result<>mrOk then begin
      debugln(['Info: (lazarus) [SaveProjectInfo] ShowSaveProjectAsDialog failed']);
      exit;
    end;
    Flags:=Flags-[sfSaveAs,sfSaveMainSourceAs];
  end;

  // update HasResources information
  UpdateProjectResourceInfo;

  // save project info file
  //debugln(['SaveProjectInfo ',Project1.ProjectInfoFile,' Test=',sfSaveToTestDir in Flags,' Virt=',Project1.IsVirtual]);
  if (not (sfSaveToTestDir in Flags))
  and (not Project1.IsVirtual) then begin
    Result:=Project1.WriteProject([],'',EnvironmentOptions.BuildMatrixOptions);
    if Result=mrAbort then begin
      debugln(['Info: (lazarus) [SaveProjectInfo] Project1.WriteProject failed']);
      exit;
    end;
    EnvironmentOptions.LastSavedProjectFile:=Project1.ProjectInfoFile;
    IDEProtocolOpts.LastProjectLoadingCrashed := False;
    AddRecentProjectFile(Project1.ProjectInfoFile);
    MainIDE.SaveIncludeLinks;
    MainIDE.UpdateCaption;
  end;

  // save main source
  if (MainUnitInfo<>nil) and (not (sfDoNotSaveVirtualFiles in flags)) then
  begin
    if not (sfSaveToTestDir in Flags) then
      DestFilename := MainUnitInfo.Filename
    else
      DestFilename := MainBuildBoss.GetTestUnitFilename(MainUnitInfo);

    if MainUnitInfo.OpenEditorInfoCount > 0 then
    begin
      // loaded in source editor
      Result:=SaveEditorFile(MainUnitInfo.OpenEditorInfo[0].EditorComponent,
               [sfProjectSaving]+[sfSaveToTestDir,sfCheckAmbiguousFiles]*Flags);
      if Result=mrAbort then begin
        debugln(['Info: (lazarus) [SaveProjectInfo] SaveEditorFile MainUnitInfo failed "',DestFilename,'"']);
        exit;
      end;
    end else
    begin
      // not loaded in source editor (hidden)
      SkipSavingMainSource := false;
      if not (sfSaveToTestDir in Flags) and not MainUnitInfo.NeedsSaveToDisk then
        SkipSavingMainSource := true;
      if (not SkipSavingMainSource) and (MainUnitInfo.Source<>nil) then
      begin
        Result:=SaveCodeBufferToFile(MainUnitInfo.Source, DestFilename);
        if Result=mrAbort then begin
          debugln(['Info: (lazarus) [SaveProjectInfo] SaveEditorFile failed "',DestFilename,'"']);
          exit;
        end;
      end;
    end;

    // clear modified flags
    if not (sfSaveToTestDir in Flags) then
    begin
      if (Result=mrOk) then begin
        if MainUnitInfo<>nil then MainUnitInfo.ClearModifieds;
        if MainUnitSrcEdit<>nil then MainUnitSrcEdit.Modified:=false;
      end;
    end;
  end;
end;

procedure GetMainUnit(out MainUnitInfo: TUnitInfo; out MainUnitSrcEdit: TSourceEditor);
begin
  MainUnitSrcEdit:=nil;
  if Project1.MainUnitID>=0 then begin
    MainUnitInfo:=Project1.MainUnitInfo;
    if MainUnitInfo.OpenEditorInfoCount > 0 then begin
      MainUnitSrcEdit := TSourceEditor(MainUnitInfo.OpenEditorInfo[0].EditorComponent);
      if MainUnitSrcEdit.Modified then
        MainUnitSrcEdit.UpdateCodeBuffer;
    end;
  end else
    MainUnitInfo:=nil;
end;

procedure SaveSrcEditorProjectSpecificSettings(AnEditorInfo: TUnitEditorInfo);
var
  ASrcEdit: TSourceEditor;
begin
  ASrcEdit := TSourceEditor(AnEditorInfo.EditorComponent);
  if ASrcEdit=nil then exit;
  AnEditorInfo.TopLine:=ASrcEdit.EditorComponent.TopLine;
  AnEditorInfo.CursorPos:=ASrcEdit.EditorComponent.CaretXY;
  AnEditorInfo.FoldState := ASrcEdit.EditorComponent.FoldState;
end;

procedure SaveSourceEditorProjectSpecificSettings;
var
  i: Integer;
begin
  for i := 0 to Project1.AllEditorsInfoCount - 1 do
    SaveSrcEditorProjectSpecificSettings(Project1.AllEditorsInfo[i]);
end;

procedure UpdateProjectResourceInfo;
var
  AnUnitInfo: TUnitInfo;
  LFMFilename: String;
begin
  AnUnitInfo:=Project1.FirstPartOfProject;
  while AnUnitInfo<>nil do begin
    if (not AnUnitInfo.HasResources)
    and (not AnUnitInfo.IsVirtual) and FilenameHasPascalExt(AnUnitInfo.Filename)
    then begin
      LFMFilename:=ChangeFileExt(AnUnitInfo.Filename,'.lfm');
      if not FileExistsCached(LFMFilename) then
        LFMFilename:=ChangeFileExt(AnUnitInfo.Filename,'.dfm');
      AnUnitInfo.HasResources:=FileExistsCached(LFMFilename);
    end;
    AnUnitInfo:=AnUnitInfo.NextPartOfProject;
  end;
end;

function ShowSaveProjectAsDialog(UseMainSourceFile: boolean): TModalResult;
var
  MainUnitSrcEdit: TSourceEditor;
  MainUnitInfo: TUnitInfo;
  SaveDialog: TSaveDialog;
  NewBuf, OldBuf: TCodeBuffer;
  TitleWasDefault: Boolean;
  NewLPIFilename, NewProgramFN, NewProgramName, AFilename: String;
  AText, ACaption, Ext: string;
  OldSourceCode, OldProjectDir, prDir: string;
begin
  Project1.BeginUpdate(false);
  try
    OldProjectDir:=Project1.Directory;

    if Project1.MainUnitInfo = nil then
      UseMainSourceFile := False;

    SaveDialog:=IDESaveDialogClass.Create(nil);
    try
      InputHistories.ApplyFileDialogSettings(SaveDialog);
      AFilename:='';
      // build a nice project info filename suggestion
      if UseMainSourceFile and (Project1.MainUnitID>=0) then
        AFilename:=Project1.MainUnitInfo.Unit_Name;
      if AFilename='' then
        AFilename:=ExtractFileName(Project1.ProjectInfoFile);
      if AFilename='' then
        AFilename:=ExtractFileName(Project1.MainFilename);
      if AFilename='' then
        AFilename:=Trim(Project1.GetTitle);
      if AFilename='' then
        AFilename:='project1';
      Ext := ExtractFileExt(AFilename);
      if UseMainSourceFile then
      begin
        if (Ext = '') or (not FilenameIsPascalSource(AFilename)) then
          AFilename := ChangeFileExt(AFilename, '.pas');
      end else
      begin
        if (Ext = '') or FilenameIsPascalSource(AFilename) then
          AFilename := ChangeFileExt(AFilename, '.lpi');
      end;
      Ext := ExtractFileExt(AFilename);
      SaveDialog.Title := Format(lisSaveProject, [Project1.GetTitleOrName, Ext]);
      SaveDialog.FileName := AFilename;
      // Note: add *.* filter, so users can see the files in the target directory
      SaveDialog.Filter := '*' + Ext + '|' + '*' + Ext
         + '|' + dlgFilterAll + ' (' + GetAllFilesMask + ')|' + GetAllFilesMask;
      SaveDialog.DefaultExt := Ext;
      if not Project1.IsVirtual then
        SaveDialog.InitialDir := Project1.Directory;

      repeat
        Result:=mrCancel;
        NewLPIFilename:='';     // the project info file name
        NewProgramName:='';     // the pascal program identifier
        NewProgramFN:='';       // the program source filename

        if not SaveDialog.Execute then
          exit;   // user cancels
        AFilename:=ExpandFileNameUTF8(SaveDialog.FileName);
        Assert(FilenameIsAbsolute(AFilename),'ShowSaveProjectAsDialog: buggy ExpandFileNameUTF8');

        // check program name
        NewProgramName:=ExtractFileNameOnly(AFilename);
        if (NewProgramName='') or (not IsValidUnitName(NewProgramName)) then begin
          Result:=IDEMessageDialog(lisInvalidProjectFilename,
            Format(lisisAnInvalidProjectNamePleaseChooseAnotherEGProject,[SaveDialog.Filename,LineEnding]),
            mtInformation,[mbRetry,mbAbort]);
          if Result=mrAbort then exit;
          continue; // try again
        end;

        // append default extension
        if UseMainSourceFile then
          NewLPIFilename:=ChangeFileExt(AFilename,'.lpi')
        else
        begin
          NewLPIFilename:=AFilename;
          if ExtractFileExt(NewLPIFilename)='' then
            NewLPIFilename:=NewLPIFilename+'.lpi';
        end;

        // apply naming conventions
        // rename to lowercase is not needed for main source

        if Project1.MainUnitID >= 0 then
        begin
          // check mainunit filename
          Ext := ExtractFileExt(Project1.MainUnitInfo.Filename);
          if Ext = '' then Ext := '.pas';
          if UseMainSourceFile then
            NewProgramFN := ExtractFileName(AFilename)
          else
            NewProgramFN := NewProgramName + Ext;
          NewProgramFN := ExtractFilePath(NewLPIFilename) + NewProgramFN;
          if (CompareFilenames(NewLPIFilename, NewProgramFN) = 0) then
          begin
            ACaption:=lisChooseADifferentName;
            AText:=Format(lisTheProjectInfoFileIsEqualToTheProjectMainSource,[NewLPIFilename,LineEnding]);
            Result:=IDEMessageDialog(ACaption, AText, mtError, [mbAbort,mbRetry]);
            if Result=mrAbort then exit;
            continue; // try again
          end;
          // check program name
          if (Project1.IndexOfUnitWithName(NewProgramName,true,
                                           Project1.MainUnitInfo)>=0) then
          begin
            ACaption:=lisUnitIdentifierExists;
            AText:=Format(lisThereIsAUnitWithTheNameInTheProjectPleaseChoose,[NewProgramName,LineEnding]);
            Result:=IDEMessageDialog(ACaption,AText,mtError,[mbRetry,mbAbort]);
            if Result=mrAbort then exit;
            continue; // try again
          end;
          Result:=mrOk;
        end else begin
          NewProgramFN:='';
          Result:=mrOk;
        end;
      until Result<>mrRetry;
    finally
      InputHistories.StoreFileDialogSettings(SaveDialog);
      SaveDialog.Free;
    end;

    //DebugLn(['ShowSaveProjectAsDialog NewLPI=',NewLPIFilename,' NewProgramName=',NewProgramName,' NewMainSource=',NewProgramFN]);

    // check if info file or source file already exists
    // Note: if user confirms overwriting .lpi do not ask for overwriting .lpr
    if FileExistsUTF8(NewLPIFilename) then
    begin
      if IDESaveDialogClass.NeedOverwritePrompt then
      begin
        ACaption:=lisOverwriteFile;
        AText:=Format(lisAFileAlreadyExistsReplaceIt, [NewLPIFilename, LineEnding]);
        Result:=IDEMessageDialog(ACaption, AText, mtConfirmation, [mbOk, mbCancel]);
        if Result=mrCancel then exit;
      end;
    end
    else begin
      if FileExistsUTF8(NewProgramFN) then
      begin
        ACaption:=lisOverwriteFile;
        AText:=Format(lisAFileAlreadyExistsReplaceIt, [NewProgramFN, LineEnding]);
        Result:=IDEMessageDialog(ACaption, AText, mtConfirmation,[mbOk,mbCancel]);
        if Result=mrCancel then exit;
      end;
    end;

    TitleWasDefault := Project1.TitleIsDefault(true);
    UpdateTargetFilename(NewProgramFN);   // set new project target filename

    // set new project filename
    Project1.ProjectInfoFile:=NewLPIFilename;
    EnvironmentOptions.AddToRecentProjectFiles(NewLPIFilename);
    MainIDE.SetRecentProjectFilesMenu;

    // change main source
    if (Project1.MainUnitID >= 0) then
    begin
      GetMainUnit(MainUnitInfo, MainUnitSrcEdit);
      if not Project1.ProjResources.RenameDirectives(MainUnitInfo.Filename,NewProgramFN)
      then begin
        DebugLn(['ShowSaveProjectAsDialog failed renaming directives Old="',MainUnitInfo.Filename,'" New="',NewProgramFN,'"']);
        // silently ignore
      end;

      // Save old source code, to prevent overwriting it,
      // if the file name didn't actually change.
      OldBuf := MainUnitInfo.Source;
      OldSourceCode := OldBuf.Source;

      // switch MainUnitInfo.Source to new code
      NewBuf := CodeToolBoss.CreateFile(NewProgramFN);
      if NewBuf=nil then begin
        Result:=IDEMessageDialog(lisErrorCreatingFile,
          Format(lisUnableToCreateFile3, [LineEnding, NewProgramFN]),
          mtError, [mbCancel]);
        exit;
      end;

      // copy the source to the new buffer
      NewBuf.Source:=OldSourceCode;
      if (OldBuf.DiskEncoding<>'') and (OldBuf.DiskEncoding<>EncodingUTF8) then
      begin
        NewBuf.DiskEncoding:=OldBuf.DiskEncoding;
        InputHistories.FileEncodings[NewProgramFN]:=NewBuf.DiskEncoding;
      end else
        InputHistories.FileEncodings[NewProgramFN]:='';

      // assign the new buffer to the MainUnit
      MainUnitInfo.Source:=NewBuf;
      if MainUnitSrcEdit<>nil then
        MainUnitSrcEdit.CodeBuffer:=NewBuf;

      // change program name
      MainUnitInfo.Unit_Name:=NewProgramName;
      MainUnitInfo.Modified:=true;

      // update source notebook page names
      UpdateSourceNames;
    end;

    // update paths
    prDir := Project1.Directory;
    with Project1.CompilerOptions do begin
      OtherUnitFiles:=RebaseSearchPath(OtherUnitFiles,OldProjectDir,prDir,true);
      IncludePath   :=RebaseSearchPath(IncludePath,OldProjectDir,prDir,true);
      Libraries     :=RebaseSearchPath(Libraries,OldProjectDir,prDir,true);
      ObjectPath    :=RebaseSearchPath(ObjectPath,OldProjectDir,prDir,true);
      SrcPath       :=RebaseSearchPath(SrcPath,OldProjectDir,prDir,true);
      DebugPath     :=RebaseSearchPath(DebugPath,OldProjectDir,prDir,true);
    end;
    // change title
    if TitleWasDefault then begin
      Project1.Title:=Project1.GetDefaultTitle;
      // title does not need to be removed from source, because it was default
    end;

    // invalidate cached substituted macros
    IncreaseCompilerParseStamp;
  finally
    Project1.EndUpdate;
  end;
  Result:=mrOk;
  //DebugLn(['ShowSaveProjectAsDialog END OK']);
end;

function AskSaveProject(const ContinueText, ContinueBtn: string): TModalResult;
var
  DataModified: Boolean;
  SrcModified: Boolean;
begin
  if Project1=nil then exit(mrOk);
  if not SomethingOfProjectIsModified then exit(mrOk);

  DataModified:=Project1.SomeDataModified(false) or Project1.HasProjectInfoFileChangedOnDisk;
  SrcModified:=SourceEditorManager.SomethingModified(false);

  if Project1.IsVirtual
  and (not DataModified)
  and (not SrcModified) then begin
    // only session changed of a new project => ignore
    exit(mrOk)
  end;

  if (Project1.SessionStorage=pssInProjectInfo)
  or DataModified
  then begin
    // lpi file will change => ask
    Result:=IDEQuestionDialog(lisProjectChanged,
        Format(lisSaveChangesToProject, [Project1.GetTitleOrName]),
        mtConfirmation, [mrYes,
                         mrNoToAll, rsmbNo,
                         mrCancel], '');
    if Result=mrNoToAll then exit(mrOk);
    if Result<>mrYes then exit(mrCancel);
  end
  else if SrcModified then
  begin
    // some non project files were changes in the source editor
    Result:=IDEQuestionDialog(lisSaveChangedFiles,lisSaveChangedFiles,
        mtConfirmation, [mrYes,
                         mrNoToAll, rsmbNo,
                         mrCancel], '');
    if Result=mrNoToAll then exit(mrOk);
    if Result<>mrYes then exit(mrCancel);
  end
  else begin
    // only session data changed
    if Project1.SessionStorage=pssNone then
      // session is not saved => skip
      exit(mrOk)
    else if not SomethingOfProjectIsModified then
      // no change
      exit(mrOk)
    else begin
      // session is saved separately
      if EnvironmentOptions.AskSaveSessionOnly then begin
        Result:=IDEQuestionDialog(lisProjectSessionChanged,
            Format(lisSaveSessionChangesToProject, [Project1.GetTitleOrName]),
            mtConfirmation, [mrYes,
                             mrNoToAll, rsmbNo,
                             mrCancel], '');
        if Result=mrNoToAll then exit(mrOk);
        if Result<>mrYes then exit(mrCancel);
      end;
    end;
  end;
  Result:=SaveProject([sfCanAbort]);
  if Result=mrAbort then exit;
  if Result<>mrOk then begin
    Result:=IDEQuestionDialog(lisChangesWereNotSaved, ContinueText,
      mtConfirmation, [mrOk, ContinueBtn, mrAbort]);
    if Result<>mrOk then exit(mrCancel);
  end;
end;

function SaveEditorChangesToCodeCache(AEditor: TSourceEditorInterface): boolean;
// save all open sources to code tools cache

  procedure SaveChanges(SaveEditor: TSourceEditorInterface);
  var
    AnUnitInfo: TUnitInfo;
  begin
    AnUnitInfo := Project1.UnitWithEditorComponent(SaveEditor);
    if (AnUnitInfo<>nil) then
    begin
      //debugln(['SaveChanges ',AnUnitInfo.Filename,' ',SaveEditor.NeedsUpdateCodeBuffer]);
      if SaveEditor.NeedsUpdateCodeBuffer then
      begin
        SaveEditorChangesToCodeCache:=true;
        SaveEditor.UpdateCodeBuffer;
        //debugln(['SaveEditorChangesToCodeCache.SaveChanges ',AnUnitInfo.Filename,' Step=',TCodeBuffer(SaveEditor.CodeToolsBuffer).ChangeStep]);
      end;
    end;
  end;

var
  i: integer;
begin
  Result:=false;
  //debugln(['SaveEditorChangesToCodeCache ']);
  if AEditor = nil then begin
    for i:=0 to SourceEditorManager.SourceEditorCount - 1 do
      SaveChanges(SourceEditorManager.SourceEditors[i]);
  end else begin
    SaveChanges(AEditor);
  end;
end;

function ReplaceUnitUse(OldFilename, OldUnitName, NewFilename, NewUnitName: string;
  IgnoreErrors, Quiet, Confirm: boolean): TModalResult;
// Replaces all references to a unit
var
  OwnerList: TFPList;
  ExtraFiles: TStrings;
  Files: TStringList;
  OldCode: TCodeBuffer;
  OldCodeCreated: Boolean;
  PascalReferences: TAVLTree;
  i: Integer;
  MsgResult: TModalResult;
  OnlyEditorFiles: Boolean;
  aFilename: String;
begin
  // compare unitnames case sensitive, maybe only the case changed
  if (CompareFilenames(OldFilename,NewFilename)=0) and (OldUnitName=NewUnitName) then
    exit(mrOk);
  // this was a new file, files on disk can not refer to it
  OnlyEditorFiles:=not FilenameIsAbsolute(OldFilename);

  OwnerList:=nil;
  OldCode:=nil;
  OldCodeCreated:=false;
  PascalReferences:=nil;
  Files:=TStringList.Create;
  try
    if OnlyEditorFiles then begin
      // search only in open files
      for i:=0 to SourceEditorManagerIntf.UniqueSourceEditorCount-1 do begin
        aFilename:=SourceEditorManagerIntf.UniqueSourceEditors[i].FileName;
        if not FilenameIsPascalSource(aFilename) then continue;
        Files.Add(aFileName);
      end;
      // add project's main source file
      if (Project1<>nil) and (Project1.MainUnitID>=0) then
        Files.Add(Project1.MainFilename);
    end else begin
      // get owners of unit
      OwnerList:=PkgBoss.GetOwnersOfUnit(NewFilename);
      if OwnerList=nil then exit(mrOk);
      PkgBoss.ExtendOwnerListWithUsedByOwners(OwnerList);
      ReverseList(OwnerList);

      // get source files of packages and projects
      ExtraFiles:=PkgBoss.GetSourceFilesOfOwners(OwnerList);
      try
        if ExtraFiles<>nil then
          Files.AddStrings(ExtraFiles);
      finally
        ExtraFiles.Free;
      end;
    end;
    for i:=Files.Count-1 downto 0 do begin
      if (CompareFilenames(Files[i],OldFilename)=0)
      or (CompareFilenames(Files[i],NewFilename)=0) then
        Files.Delete(i);
    end;
    //DebugLn(['ReplaceUnitUse ',Files.Text]);

    // commit source editor to codetools
    SaveEditorChangesToCodeCache(nil);

    // load or create old unit
    OldCode:=CodeToolBoss.LoadFile(OldFilename,true,false);
    if OldCode=nil then begin
      // create old file in memory so that unit search can find it
      OldCode:=CodeToolBoss.CreateFile(OldFilename);
      OldCodeCreated:=true;
    end;

    // search pascal source references
    Result:=GatherUnitReferences(Files,OldCode,false,IgnoreErrors,true,PascalReferences);
    if (not IgnoreErrors) and (not Quiet) and (CodeToolBoss.ErrorMessage<>'') then
      MainIDE.DoJumpToCodeToolBossError;
    if Result<>mrOk then begin
      debugln('ReplaceUnitUse GatherUnitReferences failed');
      exit;
    end;

    // replace
    if (PascalReferences<>nil) and (PascalReferences.Count>0) then begin
      if Confirm then begin
        MsgResult:=IDEQuestionDialog(lisUpdateReferences,
          Format(lisTheUnitIsUsedByOtherFilesUpdateReferencesAutomatic,
                 [OldUnitName, LineEnding]),
          mtConfirmation, [mrYes,mrNo,mrYesToAll,mrNoToAll],'');
        case MsgResult of
        mrYes: ;
        mrYesToAll: EnvironmentOptions.UnitRenameReferencesAction:=urraAlways;
        mrNoToAll:
          begin
            EnvironmentOptions.UnitRenameReferencesAction:=urraNever;
            Result:=mrOk;
            exit;
          end;
        else
          Result:=mrOk;
          exit;
        end;
      end;
      if not CodeToolBoss.RenameIdentifier(PascalReferences,OldUnitName,NewUnitName)
      then begin
        if (not IgnoreErrors) and (not Quiet) then
          MainIDE.DoJumpToCodeToolBossError;
        debugln('ReplaceUnitUse unable to commit');
        if not IgnoreErrors then begin
          Result:=mrCancel;
          exit;
        end;
      end;
    end;

  finally
    if OldCodeCreated then
      OldCode.IsDeleted:=true;
    CodeToolBoss.FreeTreeOfPCodeXYPosition(PascalReferences);
    OwnerList.Free;
    Files.Free;
  end;
  //PkgBoss.GetOwnersOfUnit(NewFilename);
  Result:=mrOk;
end;

function DesignerUnitIsVirtual(aLookupRoot: TComponent): Boolean;
var
  ActiveSourceEditor: TSourceEditor;
  ActiveUnitInfo: TUnitInfo;
begin
  Assert(Assigned(aLookupRoot),'DesignerUnitIsVirtual: aLookupRoot is not assigned');
  MainIDE.GetUnitWithPersistent(aLookupRoot, ActiveSourceEditor, ActiveUnitInfo);
  Result := ActiveUnitInfo.IsVirtual;
end;

end.


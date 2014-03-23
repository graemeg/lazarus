{
 /***************************************************************************
                          patheditordlg.pp
                          ----------------

 ***************************************************************************/

 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Abstract:
   Defines the TPathEditorDialog, which is a form to edit search paths
 
}
unit PathEditorDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Buttons, StdCtrls, Dialogs,
  FileUtil, ButtonPanel, ExtCtrls, EditBtn, MacroIntf, LCLType, Graphics,
  types, TransferMacros, LazarusIDEStrConsts, shortpathedit;

type

  { TPathEditorDialog }

  TPathEditorDialog = class(TForm)
    AddTemplateButton: TBitBtn;
    ButtonPanel1: TButtonPanel;
    ImportPathsButton: TBitBtn;
    OpenDialogPathsImport: TOpenDialog;
    ReplaceButton: TBitBtn;
    AddButton: TBitBtn;
    DeleteInvalidPathsButton: TBitBtn;
    DirectoryEdit: TShortPathEdit;
    Splitter1: TSplitter;
    DeleteButton: TBitBtn;
    PathListBox: TListBox;
    MoveDownButton: TBitBtn;
    MoveUpButton: TBitBtn;
    TemplatesListBox: TListBox;
    TemplateGroupBox: TGroupBox;
    PathGroupBox: TGroupBox;
    BrowseDialog: TSelectDirectoryDialog;
    procedure AddButtonClick(Sender: TObject);
    procedure AddTemplateButtonClick(Sender: TObject);
    procedure DeleteInvalidPathsButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure DirectoryEditAcceptDirectory(Sender: TObject; var Value: String);
    procedure DirectoryEditChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure ImportPathsButtonClick(Sender: TObject);    
    procedure MoveDownButtonClick(Sender: TObject);
    procedure MoveUpButtonClick(Sender: TObject);
    procedure PathListBoxDrawItem(Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure PathListBoxKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure PathListBoxSelectionChange(Sender: TObject; User: boolean);
    procedure ReplaceButtonClick(Sender: TObject);
    procedure TemplatesListBoxDblClick(Sender: TObject);
    procedure TemplatesListBoxSelectionChange(Sender: TObject; User: boolean);
  private
    FBaseDirectory: string;
    FEffectiveBaseDirectory: string;
    function GetPath: string;
    function GetTemplates: string;
    function PathToText(const APath: string): string;
    function BaseRelative(const APath: string): String;
    function PathAsAbsolute(const APath: string): String;
    function PathMayExist(APath: string): TObject;
    procedure SetBaseDirectory(const AValue: string);
    procedure SetPath(const AValue: string);
    procedure SetTemplates(const AValue: string);
    function TextToPath(const AText: string): string;
    procedure UpdateButtons;
  public
    property BaseDirectory: string read FBaseDirectory write SetBaseDirectory;
    property EffectiveBaseDirectory: string read FEffectiveBaseDirectory;
    property Path: string read GetPath write SetPath;
    property Templates: string read GetTemplates write SetTemplates;
  end;

  TOnPathEditorExecuted = TNotifyEvent;

  TPathEditorButton = class(TButton)
  private
    FCurrentPathEditor: TPathEditorDialog;
    FOnExecuted: TOnPathEditorExecuted;
  protected
    procedure DoOnPathEditorExecuted;
  public
    procedure Click; override;
    property CurrentPathEditor: TPathEditorDialog read FCurrentPathEditor;
    property OnExecuted: TOnPathEditorExecuted
      read FOnExecuted write FOnExecuted;
  end;

function PathEditorDialog: TPathEditorDialog;


implementation

{$R *.lfm}

var PathEditor: TPathEditorDialog;

function PathEditorDialog: TPathEditorDialog;
begin
  if PathEditor=nil then
    PathEditor:=TPathEditorDialog.Create(Application);
  Result:=PathEditor;
end;

{ TPathEditorDialog }

function TPathEditorDialog.BaseRelative(const APath: string): String;
begin
  Result:=Trim(APath);
  if (FEffectiveBaseDirectory<>'') and FilenameIsAbsolute(FEffectiveBaseDirectory) then
    Result:=CreateRelativePath(Result, FEffectiveBaseDirectory);
end;

function TPathEditorDialog.PathAsAbsolute(const APath: string): String;
begin
  Result:=APath;
  if not TTransferMacroList.StrHasMacros(Result)  // not a template
  and (FEffectiveBaseDirectory<>'') and FilenameIsAbsolute(FEffectiveBaseDirectory) then
    Result:=CreateAbsolutePath(Result, FEffectiveBaseDirectory);
end;

function TPathEditorDialog.PathMayExist(APath: string): TObject;
// Returns 1 if path exists or contains a macro, 0 otherwise.
// Result is casted to TObject to be used for Strings.Objects.
begin
  if TTransferMacroList.StrHasMacros(APath) then
    Exit(TObject(1));
  Result:=TObject(0);
  if (FEffectiveBaseDirectory<>'') and FilenameIsAbsolute(FEffectiveBaseDirectory) then
    APath:=CreateAbsolutePath(APath, FEffectiveBaseDirectory);
  if DirectoryExists(APath) then
    Result:=TObject(1);
end;

procedure TPathEditorDialog.AddButtonClick(Sender: TObject);
var
  y: integer;
  RelPath: String;
begin
  with PathListBox do begin
    y:=ItemIndex+1;
    if y=0 then
      y:=Count;
    RelPath:=BaseRelative(DirectoryEdit.Text);
    Items.InsertObject(y, RelPath, PathMayExist(DirectoryEdit.Text));
    ItemIndex:=y;
    UpdateButtons;
  end;
end;

procedure TPathEditorDialog.ReplaceButtonClick(Sender: TObject);
var
  RelPath: String;
begin
  with PathListBox do begin
    RelPath:=BaseRelative(DirectoryEdit.Text);
    Items[ItemIndex]:=RelPath;
    Items.Objects[ItemIndex]:=PathMayExist(DirectoryEdit.Text);
    UpdateButtons;
  end;
end;

procedure TPathEditorDialog.DeleteButtonClick(Sender: TObject);
begin
  PathListBox.Items.Delete(PathListBox.ItemIndex);
  UpdateButtons;
end;

procedure TPathEditorDialog.DirectoryEditAcceptDirectory(Sender: TObject;
  var Value: String);
begin
  DirectoryEdit.Text := BaseRelative(Value);
end;

procedure TPathEditorDialog.DeleteInvalidPathsButtonClick(Sender: TObject);
var
  i: Integer;
begin
  with PathListBox do
    for i:=Items.Count-1 downto 0 do
      if PtrInt(Items.Objects[i])=0 then
        Items.Delete(i);
end;

procedure TPathEditorDialog.AddTemplateButtonClick(Sender: TObject);
var
  i, y: integer;
begin
  y:=-1;
  for i:=0 to TemplatesListBox.Items.Count-1 do begin
    if TemplatesListBox.Selected[i]
    and (PathListBox.Items.IndexOf(TemplatesListBox.Items[i])=-1) then begin
      PathListBox.Items.AddObject(TemplatesListBox.Items[i], TObject(1));
      y:=PathListBox.Count-1;
    end;
  end;
  if y>=1 then begin
    PathListBox.ItemIndex:=y;
    UpdateButtons;
  end;
end;

procedure TPathEditorDialog.DirectoryEditChange(Sender: TObject);
begin
  UpdateButtons;
end;

procedure TPathEditorDialog.PathListBoxSelectionChange(Sender: TObject; User: boolean);
Var
  FullPath : String;
begin
  with PathListBox do
    if ItemIndex>-1 then begin
      DirectoryEdit.Text:=BaseRelative(Items[ItemIndex]);
      FullPath := Items[ItemIndex];
      IDEMacros.SubstituteMacros(FullPath);
      DirectoryEdit.Directory:=PathAsAbsolute(FullPath);
    end;
  UpdateButtons;
end;

procedure TPathEditorDialog.TemplatesListBoxSelectionChange(Sender: TObject; User: boolean);
begin
  UpdateButtons;
end;

procedure TPathEditorDialog.TemplatesListBoxDblClick(Sender: TObject);
begin
  AddTemplateButtonClick(Nil);
end;

procedure TPathEditorDialog.FormCreate(Sender: TObject);
begin
  Caption:=dlgDebugOptionsPathEditorDlgCaption;

  PathGroupBox.Caption:=lisPathEditSearchPaths;
  MoveUpButton.Hint:=lisPathEditMovePathUp;
  MoveDownButton.Hint:=lisPathEditMovePathDown;

  ReplaceButton.Caption:=lisReplace;
  ReplaceButton.Hint:=lisPathEditorReplaceHint;
  AddButton.Caption:=lisAdd;
  AddButton.Hint:=lisPathEditorAddHint;
  DeleteButton.Caption:=lisDelete;
  DeleteButton.Hint:=lisPathEditorDeleteHint;
  DeleteInvalidPathsButton.Caption:=lisPathEditDeleteInvalidPaths;
  DeleteInvalidPathsButton.Hint:=lisPathEditorDeleteInvalidHint;
  ImportPathsButton.Caption:=lisPathEditImportPaths;  

  TemplateGroupBox.Caption:=lisPathEditPathTemplates;
  AddTemplateButton.Caption:=lisCodeTemplAdd;
  AddTemplateButton.Hint:=lisPathEditorTemplAddHint;

  MoveUpButton.LoadGlyphFromResourceName(HInstance, 'arrow_up');
  MoveDownButton.LoadGlyphFromResourceName(HInstance, 'arrow_down');
  ReplaceButton.LoadGlyphFromResourceName(HInstance, 'menu_reportingbug');
  AddButton.LoadGlyphFromResourceName(HInstance, 'laz_add');
  DeleteButton.LoadGlyphFromResourceName(HInstance, 'laz_delete');
  DeleteInvalidPathsButton.LoadGlyphFromResourceName(HInstance, 'menu_clean');
  AddTemplateButton.LoadGlyphFromResourceName(HInstance, 'laz_add');
end;

procedure TPathEditorDialog.FormResize(Sender: TObject);
var
  PathGroupBoxHeight: integer;
begin
  PathGroupBoxHeight:=((ClientHeight-70)*2) div 3;
  if PathGroupBoxHeight<10 then
    PathGroupBoxHeight:=10;
  PathGroupBox.Height:=PathGroupBoxHeight;
end;

procedure TPathEditorDialog.FormShow(Sender: TObject);
begin
  PathListBox.ItemIndex:=-1;
  TemplatesListBox.ItemIndex:=-1;
  UpdateButtons;
end;

procedure TPathEditorDialog.MoveDownButtonClick(Sender: TObject);
var
  y: integer;
begin
  y:=PathListBox.ItemIndex;
  if (y>-1) and (y<PathListBox.Count-1) then begin
    PathListBox.Items.Move(y,y+1);
    PathListBox.ItemIndex:=y+1;
    UpdateButtons;
  end;
end;


procedure TPathEditorDialog.ImportPathsButtonClick(Sender: TObject);
var paths:TStringList;
    y:integer;
    c:integer;
    RelPath:string;
begin
  if not OpenDialogPathsImport.Execute then exit;

  paths:=TStringList.Create();

  try
    paths.LoadFromFile(OpenDialogPathsImport.FileName);

    with PathListBox do
    begin
      y:=ItemIndex+1;

      if y=0 then
      begin
        y:=Count;
      end;

      for c:=0 to paths.Count-1 do
      begin
        if Trim(paths[c])<>'' then
        begin
          RelPath:=BaseRelative(paths[c]);
          Items.InsertObject(y, RelPath, PathMayExist(paths[c]));
          ItemIndex:=y;
        end;
      end;

      UpdateButtons;
    end;

  finally
    FreeAndNil(paths);
  end;
end;


procedure TPathEditorDialog.MoveUpButtonClick(Sender: TObject);
var
  y: integer;
begin
  y:=PathListBox.ItemIndex;
  if (y>0) and (y<PathListBox.Count) then begin
    PathListBox.Items.Move(y,y-1);
    PathListBox.ItemIndex:=y-1;
    UpdateButtons;
  end;
end;

procedure TPathEditorDialog.PathListBoxDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
begin
  if Index < 0 then Exit;
  with PathListBox do begin
    Canvas.FillRect(ARect);
    if PtrInt(Items.Objects[Index]) = 0 then
      Canvas.Font.Color := clGray;
    Canvas.TextRect(ARect, ARect.Left, ARect.Top, Items[Index]);
  end;
end;

procedure TPathEditorDialog.PathListBoxKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (ssCtrl in shift ) and ((Key = VK_UP) or (Key = VK_DOWN)) then begin
    if Key = VK_UP then
      MoveUpButtonClick(Nil)
    else
      MoveDownButtonClick(Nil);
    Key:=VK_UNKNOWN;
  end;
end;

function TPathEditorDialog.GetPath: string;
begin
  Result:=TextToPath(PathListBox.Items.Text);
end;

function TPathEditorDialog.GetTemplates: string;
begin
  Result:=TextToPath(TemplatesListBox.Items.Text);
end;

procedure TPathEditorDialog.SetPath(const AValue: string);
var
  sl: TStringList;
  i: Integer;
begin
  DirectoryEdit.Text:='';
  PathListBox.Items.Clear;
  sl:=TstringList.Create();
  try
    sl.Text:=PathToText(AValue);
    for i:=0 to sl.Count-1 do
      PathListBox.Items.AddObject(sl[i], PathMayExist(sl[i]));
    PathListBox.ItemIndex:=-1;
  finally
    sl.Free;
  end;
end;

procedure TPathEditorDialog.SetTemplates(const AValue: string);
begin
  TemplatesListBox.Items.Text:=PathToText(AValue);
  TemplateGroupBox.Visible:=TemplatesListBox.Count>0;
end;

function TPathEditorDialog.TextToPath(const AText: string): string;
var
  i, j: integer;
  PathAsText: string;
begin
  PathAsText:=AText;
  Result:=PathAsText;
  // convert all line ends to semicolons, remove empty paths and trailing spaces
  i:=1;
  j:=1;
  while i<=length(PathAsText) do begin
    if PathAsText[i] in [#10,#13] then begin
      // new line -> new path
      inc(i);
      if (i<=length(PathAsText)) and (PathAsText[i] in [#10,#13])
      and (PathAsText[i]<>PathAsText[i-1]) then
        inc(i);
      // skip spaces at end of path
      while (j>1) and (Result[j-1]=' ') do
        dec(j);
      // skip empty paths
      if (j=1) or (Result[j-1]<>';') then begin
        Result[j]:=';';
        inc(j);
      end;
    end else if ord(PathAsText[i])<32 then begin
      // skip trailing spaces
      inc(i)
    end else if PathAsText[i]=' ' then begin
      // space -> skip spaces at beginning of path
      if (j>1) and (Result[j-1]<>';') then begin
        Result[j]:=PathAsText[i];
        inc(j);
      end;
      inc(i);
    end else begin
      // path char -> just copy
      Result[j]:=PathAsText[i];
      inc(j);
      inc(i);
    end;
  end;
  if (j>1) and (Result[j-1]=';') then dec(j);
  SetLength(Result,j-1);
end;

function TPathEditorDialog.PathToText(const APath: string): string;
var
  i: integer;
  NewPath: string;
begin
  NewPath:=APath;
  for i:=1 to length(NewPath) do
    if NewPath[i]=';' then
      NewPath[i]:=#13;
  Result:=NewPath;
end;

procedure TPathEditorDialog.UpdateButtons;
var
  i: integer;
  InValidPathsExist: Boolean;
begin
  // Replace / add / delete / Delete Invalid Paths
  ReplaceButton.Enabled:=(DirectoryEdit.Text<>'') and (DirectoryEdit.Text<>FEffectiveBaseDirectory)
      and (PathListBox.Items.IndexOf(BaseRelative(DirectoryEdit.Text))=-1);
  AddButton.Enabled:=ReplaceButton.Enabled;
  DeleteButton.Enabled:=PathListBox.SelCount=1; // or ItemIndex>-1; ?
  AddTemplateButton.Enabled:=(TemplatesListBox.SelCount>1) or ((TemplatesListBox.ItemIndex>-1)
      and (PathListBox.Items.IndexOf(TemplatesListBox.Items[TemplatesListBox.ItemIndex])=-1));
  // Delete non-existent paths button. Check if there are any.
  InValidPathsExist:=False;
  for i:=0 to PathListBox.Items.Count-1 do
    if PtrInt(PathListBox.Items.Objects[i])=0 then begin
      InValidPathsExist:=True;
      Break;
    end;
  DeleteInvalidPathsButton.Enabled:=InValidPathsExist;
  // Move up / down buttons
  i := PathListBox.ItemIndex;
  MoveUpButton.Enabled := i > 0;
  MoveDownButton.Enabled := (i > -1) and (i < PathListBox.Count-1);
  ImportPathsButton.Enabled:=true;
end;

procedure TPathEditorDialog.SetBaseDirectory(const AValue: string);
begin
  if FBaseDirectory=AValue then exit;
  FBaseDirectory:=AValue;
  FEffectiveBaseDirectory:=FBaseDirectory;
  IDEMacros.SubstituteMacros(FEffectiveBaseDirectory);
  DirectoryEdit.Directory:=FEffectiveBaseDirectory;
end;

{ TPathEditorButton }

procedure TPathEditorButton.Click;
begin
  FCurrentPathEditor:=PathEditorDialog;
  try
    inherited Click;
    FCurrentPathEditor.ShowModal;
    DoOnPathEditorExecuted;
  finally
    FCurrentPathEditor:=nil;
  end;
end;

procedure TPathEditorButton.DoOnPathEditorExecuted;
begin
  if Assigned(OnExecuted) then OnExecuted(Self);
end;

end.


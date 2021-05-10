{
 *****************************************************************************
 *                             Gtk3WSDialogs.pp                              *
 *                             ----------------                              * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Gtk3WSDialogs;

{$I gtk3defines.inc}
{$mode objfpc}{$H+}

interface

uses
  // Bindings
  LazGtk3, LazGlib2, LazGdk3, LazGObject2, LazPango1,
  // RTL, FCL and LCL
  SysUtils, Classes, Graphics, Controls, Dialogs, ExtDlgs, LCLType,
  LazFileUtils, LCLStrConsts, LCLProc,
  // Widgetset
  gtk3int, gtk3widgets,
  WSDialogs;
  
type
  { TGtk3WSCommonDialog }

  TGtk3WSCommonDialog = class(TWSCommonDialog)
  private
    class procedure SetColorDialogColor(ColorSelection: PGtkColorSelectionDialog; Color: TColor);
    class procedure SetColorDialogPalette(ColorSelection: PGtkColorSelectionDialog; Palette: TStrings);
  protected
    class procedure SetCallbacks(const AGtkWidget: PGtkWidget; const AWidgetInfo: TGtk3Dialog); virtual;
    class procedure SetSizes(const AGtkWidget: PGtkWidget; const AWidgetInfo: TGtk3Dialog); virtual;
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
    class procedure ShowModal(const ACommonDialog: TCommonDialog); override;
    class procedure DestroyHandle(const ACommonDialog: TCommonDialog); override;
  end;

  { TGtk3WSFileDialog }

  TGtk3WSFileDialog = class(TWSFileDialog)
  protected
    class procedure SetCallbacks(const AGtkWidget: PGtkWidget; const AWidgetInfo: TGtk3Dialog); virtual;
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
  end;

  { TGtk3WSOpenDialog }

  TGtk3WSOpenDialog = class(TWSOpenDialog)
  protected
    class function CreateOpenDialogFilter(OpenDialog: TOpenDialog;
      Chooser: PGtkFileChooser): string; virtual;
    class procedure CreateOpenDialogHistory(OpenDialog: TOpenDialog;
      SelWidget: PGtkWidget); virtual;
    class procedure CreatePreviewDialogControl(PreviewDialog: TPreviewFileDialog;
      Chooser: PGtkFileChooser); virtual;
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
  end;

  { TGtk3WSSaveDialog }

  TGtk3WSSaveDialog = class(TWSSaveDialog)
  published
  end;

  { TGtk3WSSelectDirectoryDialog }

  TGtk3WSSelectDirectoryDialog = class(TWSSelectDirectoryDialog)
  published
  end;

  { TGtk3WSColorDialog }

  TGtk3WSColorDialog = class(TWSColorDialog)
  protected
  published
    class function CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
  end;

  { TGtk3WSColorButton }

  TGtk3WSColorButton = class(TWSColorButton)
  published
  end;

  { TGtk3WSFontDialog }

  TGtk3WSFontDialog = class(TWSFontDialog)
  protected
  published
    class function  CreateHandle(const ACommonDialog: TCommonDialog): THandle; override;
  end;

// forward declarations

procedure UpdateDetailView(OpenDialog: TOpenDialog);

implementation
uses gtk3procs;

  { file dialog }

type
  PFileSelHistoryEntry = ^TFileSelHistoryEntry;
  TFileSelHistoryEntry = record
      Filename: PChar;
      MenuItem: PGtkWidget;
    end;

  { TFileSelFilterEntry }

  TFileSelFilterEntry = class
  public
    Description: String;
    Mask: String;
    FilterIndex: integer;
    MenuItem: PGtkWidget;
    constructor Create(const ADescription, AMask: string);
    destructor Destroy; override;
  end;

constructor TFileSelFilterEntry.Create(const ADescription, AMask: string);
begin
  Description := ADescription;
  Mask := AMask;
  FilterIndex := 1;
  MenuItem := nil;
end;

destructor TFileSelFilterEntry.Destroy;
begin
  inherited Destroy;
end;


{------------------------------------------------------------------------------
  Function: ExtractFilterList
  Params: const Filter: string; var FilterIndex: integer;
          var ListOfPFileSelFilterEntry: TStringList
  Returns: -

  Converts a Delphi file filter of the form
  'description1|mask1|description2|mask2|...'
  into a TFPList of PFileSelFilterEntry(s).
  Multi masks:
    - multi masks like '*.pas;*.pp' are converted into multiple entries.
    - if the masks are found in the description they are adjusted
    - if the mask is not included in the description it will be concatenated
    For example:
      'Pascal files (*.pas;*.pp)|*.pas;*.lpr;*.pp;
      is converted to three filter entries:
        'Pascal files (*.pas)' + '*.pas'
        'Pascal files (*.pp)'  + '*.pp'
        'Pascal files (*.lpr)' + '*.lpr'
 ------------------------------------------------------------------------------}
procedure ExtractFilterList(const Filter: string;
  out ListOfFileSelFilterEntry: TFPList;
  SplitMultiMask: boolean);
var
  Masks: TStringList;
  CurFilterIndex: integer;

  procedure ExtractMasks(const MultiMask: string);
  var CurMaskStart, CurMaskEnd: integer;
    s: string;
  begin
    if Masks=nil then
      Masks:=TStringList.Create
    else
      Masks.Clear;
    CurMaskStart:=1;
    while CurMaskStart<=length(MultiMask) do begin
      CurMaskEnd:=CurMaskStart;
      if SplitMultiMask then begin
        while (CurMaskEnd<=length(MultiMask)) and (MultiMask[CurMaskEnd]<>';')
        do
          inc(CurMaskEnd);
      end else begin
        CurMaskEnd:=length(MultiMask)+1;
      end;
      s:=Trim(copy(MultiMask,CurMaskStart,CurMaskEnd-CurMaskStart));
      Masks.Add(s);
      CurMaskStart:=CurMaskEnd+1;
    end;
  end;

  procedure AddEntry(const Desc, Mask: string);
  var NewFilterEntry: TFileSelFilterEntry;
  begin
    NewFilterEntry:=TFileSelFilterEntry.Create(Desc,Mask);
    NewFilterEntry.FilterIndex:=CurFilterIndex;
    ListOfFileSelFilterEntry.Add(NewFilterEntry);
  end;

  // remove all but one masks from description string
  function RemoveOtherMasks(const Desc: string; MaskIndex: integer): string;
  var i, StartPos, EndPos: integer;
  begin
    Result:=Desc;
    for i:=0 to Masks.Count-1 do begin
      if i=MaskIndex then continue;
      StartPos:=Pos(Masks[i],Result);
      EndPos:=StartPos+length(Masks[i]);
      if StartPos<1 then continue;
      while (StartPos>1) and (Result[StartPos-1] in [' ',#9,';']) do
        dec(StartPos);
      while (EndPos<=length(Result)) and (Result[EndPos] in [' ',#9]) do
        inc(EndPos);
      if (StartPos>1) and (Result[StartPos-1]='(')
      and (EndPos<=length(Result)) then begin
        if (Result[EndPos]=')') then begin
          dec(StartPos);
          inc(EndPos);
        end else if Result[EndPos]=';' then begin
          inc(EndPos);
        end;
      end;
      System.Delete(Result,StartPos,EndPos-StartPos);
    end;
  end;

  procedure AddEntries(const Desc: string; const MultiMask: string);
  var i: integer;
    CurDesc: string;
  begin
    ExtractMasks(MultiMask);
    for i:=0 to Masks.Count-1 do begin
      CurDesc:=RemoveOtherMasks(Desc,i);
      if (Masks.Count>1) and (Pos(Masks[i],CurDesc)<1) then begin
        if (CurDesc='') or (CurDesc[length(CurDesc)]<>' ') then
          CurDesc:=CurDesc+' ';
        CurDesc:=CurDesc+'('+Masks[i]+')';
      end;
      //debugln('AddEntries ',CurDesc,' ',Masks[i]);
      AddEntry(CurDesc,Masks[i]);
    end;
    inc(CurFilterIndex);
  end;

var
  CurDescStart, CurDescEnd, CurMultiMaskStart, CurMultiMaskEnd: integer;
  CurDesc, CurMultiMask: string;
begin
  ListOfFileSelFilterEntry:=TFPList.Create;
  Masks:=nil;
  CurFilterIndex:=0;
  CurDescStart:=1;
  while CurDescStart<=length(Filter) do
  begin
    // extract next filter description
    CurDescEnd:=CurDescStart;
    while (CurDescEnd<=length(Filter)) and (Filter[CurDescEnd]<>'|') do
      inc(CurDescEnd);
    CurDesc:=copy(Filter,CurDescStart,CurDescEnd-CurDescStart);
    // extract next filter multi mask
    CurMultiMaskStart:=CurDescEnd+1;
    CurMultiMaskEnd:=CurMultiMaskStart;
    while (CurMultiMaskEnd<=length(Filter)) and (Filter[CurMultiMaskEnd]<>'|') do
      inc(CurMultiMaskEnd);
    CurMultiMask:=copy(Filter,CurMultiMaskStart,CurMultiMaskEnd-CurMultiMaskStart);
    if CurDesc='' then CurDesc:=CurMultiMask;
    // add filter(s)
    if (CurMultiMask<>'') or (CurDesc<>'') then
      AddEntries(CurDesc,CurMultiMask);
    // next filter
    CurDescStart:=CurMultiMaskEnd+1;
  end;
  Masks.Free;
end;

procedure FreeListOfFileSelFilterEntry(ListOfFileSelFilterEntry: TFPList);
var
  i: Integer;
begin
  if ListOfFileSelFilterEntry=nil then exit;
  for i:=0 to ListOfFileSelFilterEntry.Count-1 do
    TObject(ListOfFileSelFilterEntry[i]).Free;
  ListOfFileSelFilterEntry.Free;
end;

{-------------------------------------------------------------------------------
  procedure UpdateDetailView
  Params: OpenDialog: TOpenDialog
  Result: none

  Shows some OS dependent information about the current file
-------------------------------------------------------------------------------}
procedure UpdateDetailView(OpenDialog: TOpenDialog);
var
  FileDetailLabel: PGtkWidget;
  Filename, OldFilename, Details: String;
  Widget: PGtkWidget;
begin
  //DebugLn(['UpdateDetailView ']);
  Widget := TGtk3Dialog(OpenDialog.Handle).Widget;

  FileName := gtk_file_chooser_get_filename(PGtkFileChooser(Widget));

  OldFilename := OpenDialog.Filename;
  if Filename = OldFilename then
    Exit;
  OpenDialog.Filename := Filename;
  // tell application, that selection has changed
  OpenDialog.DoSelectionChange;
  if (OpenDialog.OnFolderChange <> nil) and
     (ExtractFilePath(Filename) <> ExtractFilePath(OldFilename)) then
    OpenDialog.DoFolderChange;
  // show some information
  FileDetailLabel := g_object_get_data({%H-}TGtk3Dialog(OpenDialog.Handle).Widget, 'FileDetailLabel');
  if FileDetailLabel = nil then
    Exit;
  if FileExistsUTF8(Filename) then
    Details := GetFileDescription(Filename)
  else
    Details := Format(rsFileInfoFileNotFound, [Filename]);
  gtk_label_set_text(PGtkLabel(FileDetailLabel), PChar(Details));
end;


{------------------------------------------------------------------------------
  Procedure: StoreCommonDialogSetup
  Params:    ADialog: TCommonDialog
  Returns:   none

  Stores the size of a TCommonDialog.
 ------------------------------------------------------------------------------}
procedure StoreCommonDialogSetup(ADialog: TCommonDialog);
var
  DlgWindow: PGtkWidget;
begin
  if (ADialog=nil) or not ADialog.HandleAllocated then exit;
  DlgWindow := TGtk3Dialog(ADialog.Handle).Widget;
  if DlgWindow^.get_allocated_width > 0 then
    ADialog.Width := DlgWindow^.get_allocated_width;
  if DlgWindow^.get_allocated_height > 0 then
    ADialog.Height := DlgWindow^.get_allocated_height;
end;

{------------------------------------------------------------------------------
  Procedure: DestroyCommonDialogAddOns
  Params:    ADialog: TCommonDialog
  Returns:   none

  Free the memory of additional data of a TCommonDialog
 ------------------------------------------------------------------------------}
procedure DestroyCommonDialogAddOns(ADialog: TCommonDialog);
var
  DlgWindow: PGtkWidget;
  HistoryList: TFPList; // list of TFileSelHistoryListEntry
  AHistoryEntry: PFileSelHistoryEntry;
  i: integer;
  // FileSelWidget: PGtkFileSelection;
  LCLHistoryMenu: PGTKWidget;
begin
  if (ADialog=nil) or (not ADialog.HandleAllocated) then exit;
  (*TODO: PGtkFileSelection is deprecated in gtk3
  DlgWindow:={%H-}PGtkWidget(ADialog.Handle);

  gtk_window_set_transient_for(PGtkWindow(DlgWindow),nil);
  if ADialog is TOpenDialog then begin
    FileSelWidget:=GTK_FILE_CHOOSER(DlgWindow);
    LCLHistoryMenu:=PGTKWidget(g_object_get_data(PGObject(FileSelWidget),
                                       'LCLHistoryMenu'));
    if LCLHistoryMenu<>nil then FreeWidgetInfo(LCLHistoryMenu);

    // free history
    HistoryList:=TFPList(g_object_get_data(PGObject(DlgWindow),
                                             'LCLHistoryList'));
    if HistoryList<>nil then begin
      for i:=0 to HistoryList.Count-1 do begin
        AHistoryEntry:=PFileSelHistoryEntry(HistoryList[i]);
        StrDispose(AHistoryEntry^.Filename);
        AHistoryEntry^.Filename:=nil;
        Dispose(AHistoryEntry);
      end;
      HistoryList.Free;
      g_object_set_data(PGObject(DlgWindow),'LCLHistoryList',nil);
    end;

    // free preview handle
    if ADialog is TPreviewFileDialog then begin
      if TPreviewFileDialog(ADialog).PreviewFileControl<>nil then
        TPreviewFileDialog(ADialog).PreviewFileControl.Handle:=0;
    end;
  end;
  *)
end;

// ---------------------- signals ----------------------------------------------

procedure gtkFileChooserSelectionChangedCB(Chooser: PGtkFileChooser;
  Data: Pointer); cdecl;
var
  cFilename: Pgchar;
  theDialog: TFileDialog;
begin
  //DebugLn(['gtkFileChooserSelectionChangedCB ']);
  cFilename := gtk_file_chooser_get_filename(Chooser);
  theDialog := TFileDialog(TGtk3Dialog(Data).CommonDialog);
  try
    if theDialog is TOpenDialog then
      UpdateDetailView(TOpenDialog(theDialog));
  finally
    if Assigned(cFilename) then
      g_free(cFilename);
  end;
end;

procedure Gtk2FileChooserResponseCB(widget: PGtkFileChooser; arg1: gint;
  data: gpointer); cdecl;

  procedure AddFile(List: TStrings; const NewFile: string);
  var
    i: Integer;
  begin
    for i := 0 to List.Count-1 do
      if List[i] = NewFile then
        Exit;
    List.Add(NewFile);
  end;

  function SkipDirectory(const AName: String): Boolean;
  // gtk2-2.20 have problems.
  // issue http://bugs.freepascal.org/view.php?id=17278
  begin
    Result := (gtk_file_chooser_get_action(Widget) =  GTK_FILE_CHOOSER_ACTION_OPEN) and
      DirectoryExists(AName);
  end;

var
  TheDialog: TFileDialog;
  cFilename: PChar;
  cFilenames: PGSList;
  cFilenames1: PGSList;
  Files: TStringList;
begin
  //DebugLn(['Gtk3FileChooserResponseCB ']);
  theDialog := TFileDialog(TGtk3Dialog(Data).CommonDialog);

  if arg1 = GTK_RESPONSE_CANCEL then
  begin
    TheDialog.UserChoice := mrCancel;
    Exit;
  end;

  if theDialog is TOpenDialog then
  begin
    if ofAllowMultiSelect in TOpenDialog(theDialog).Options then
    begin
      TheDialog.FileName := '';
      Files := TStringList(TheDialog.Files);
      Files.Clear;
      cFilenames := gtk_file_chooser_get_filenames(widget);
      if Assigned(cFilenames) then
      begin
        cFilenames1 := cFilenames;
        while Assigned(cFilenames1) do
        begin
          cFilename := PChar(cFilenames1^.data);
          if Assigned(cFilename) then
          begin
            if not SkipDirectory(cFileName) then
              AddFile(Files, cFilename);
            g_free(cFilename);
          end;
          cFilenames1 := cFilenames1^.next;
        end;
        g_slist_free(cFilenames);
      end;
    end
    else
      TheDialog.Files.Clear;
  end;

  cFilename := gtk_file_chooser_get_filename(widget);

  if Assigned(cFilename) then
  begin
    if SkipDirectory(cFileName) then
      TheDialog.FileName := ''
    else
      TheDialog.FileName := cFilename;
    g_free(cFilename);
    if (TheDialog is TOpenDialog) and (not (ofAllowMultiSelect in TOpenDialog(theDialog).Options)) then
      TheDialog.Files.Add(TheDialog.FileName);
  end;

  //?? StoreCommonDialogSetup(theDialog);
  theDialog.UserChoice := mrOK;
end;

procedure Gtk2FileChooserNotifyCB(dialog: PGObject; pspec: PGParamSpec;
  user_data: gpointer); cdecl;
var
  TheDialog: TFileDialog;
  GtkFilter: PGtkFileFilter;
  GtkFilterList: PGSList;
  NewFilterIndex: Integer;
begin
  //DebugLn(['Gtk2FileChooserNotifyCB ']);
  if pspec^.name = 'filter' then
  begin // filter changed
    theDialog := TFileDialog(TGtk3Dialog(user_data).CommonDialog);
    GtkFilter := gtk_file_chooser_get_filter(PGtkFileChooser(dialog));
    GtkFilterList := gtk_file_chooser_list_filters(PGtkFileChooser(dialog));
    if (GtkFilter = nil) and (theDialog.Filter <> '') then
    begin
      // Either we don't have filter or gtk reset it.
      // Gtk resets filter if we set both filename and filter but filename
      // does not fit into filter. Gtk comparision has bug - it compares only by
      // mime-type, not by pattern. LCL set all filters by pattern.
      GtkFilter := g_slist_nth_data(GtkFilterList, theDialog.FilterIndex - 1);
      gtk_file_chooser_set_filter(PGtkFileChooser(dialog), GtkFilter);
    end
    else
    begin
      NewFilterIndex := g_slist_index(GtkFilterList, Pgpointer(GtkFilter));
      theDialog.IntfFileTypeChanged(NewFilterIndex + 1);
    end;
    g_slist_free(GtkFilterList);
  end;
end;

// ------------------------ Signals --------------------------------------------

{-------------------------------------------------------------------------------
  function GTKDialogSelectRowCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, whenever a row is selected in a commondialog
-------------------------------------------------------------------------------}
function gtkDialogSelectRowCB({%H-}widget: PGtkWidget; {%H-}Row, {%H-}Column: gInt;
  {%H-}bevent: pgdkEventButton; {%H-}data: gPointer): GBoolean; cdecl;
(*
var
  theDialog: TCommonDialog;
  MenuWidget: PGtkWidget;
  AFilterEntry: TFileSelFilterEntry;
  FileSelWidget: PGtkFileSelection;
  ShiftState: TShiftState;
  loop : gint;
  startRow : gint;
  endRow : gint;
  *)
begin
  Result := False;
  DebugLn('Gtk3WSDialogs: WARNING gtkDialogSelectRowCB is not implemented since PGtkFileSelection is deprecated.');
  (*
  //debugln('GTKDialogSelectRowCB A ');
  Result:=CallBackDefaultReturn;
  if (Data=nil) or (BEvent=nil) or (Column=0) or (Row=0) then ;
  theDialog:=TCommonDialog(GetLCLObject(Widget));
  if (theDialog is TOpenDialog) then begin
    // only process the callback if there is event data. If there isn't any
    // event data that means it was called due to a direct function call of the
    // widget and not an actual mouse click on the widget.
    FileSelWidget:={%H-}PGtkFileSelection(theDialog.Handle);
    if (bevent <> nil) and (gdk_event_get_type(bevent) = GDK_2BUTTON_PRESS)
    and (FileSelWidget^.dir_list = widget) then begin
      MenuWidget := g_object_get_data(PGObject(FileSelWidget),
                                        'LCLFilterMenu');
      if MenuWidget <> nil then begin
        AFilterEntry := TFileSelFilterEntry(g_object_get_data(PGObject(
            gtk_menu_get_active(PGtkMenu(MenuWidget))), 'LCLIsFilterMenuItem'));
        if (AFilterEntry<>nil) and (AFilterEntry.Mask<>nil) then
          PopulateFileAndDirectoryLists(FileSelWidget,AFilterEntry.Mask);
      end;
    end
    else if (bevent <> nil)
    and (ofAllowMultiSelect in TOpenDialog(theDialog).Options)
    and (FileSelWidget^.file_list=widget) then begin
      // multi selection
      ShiftState := GTKEventStateToShiftState(BEvent^.State);
      if ssShift in ShiftState then begin
        if LastFileSelectRow <> -1 then begin
          startRow := LastFileSelectRow;
          endRow := row;
          if LastFileSelectRow > row then begin
            startRow := row;
            endRow := LastFileSelectRow;
          end;
          for loop := startRow to endRow do begin
            gtk_clist_select_row(PGtkCList(widget), loop, column);
          end;
        end;
      end
      else if not (ssCtrl in ShiftState) then begin
        gtk_clist_unselect_all(PGtkCList(widget));
        gtk_clist_select_row(PGtkCList(widget), row, column);
      end;
      LastFileSelectRow := row;
    end;
    UpdateDetailView(TOpenDialog(theDialog));
  end;
  *)
end;

{-------------------------------------------------------------------------------
  function gtkDialogHelpclickedCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, whenever the user clicks the help button in a
  commondialog
-------------------------------------------------------------------------------}
function gtkDialogHelpclickedCB(widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
var
  theDialog : TCommonDialog;
begin
  Result := False;
  if (Widget=nil) then ;
  theDialog := TCommonDialog(TGtk3Dialog(data).CommonDialog);
  if theDialog is TOpenDialog then begin
    if TOpenDialog(theDialog).OnHelpClicked<>nil then
      TOpenDialog(theDialog).OnHelpClicked(theDialog);
  end;
end;

{-------------------------------------------------------------------------------
  function gtkDialogApplyclickedCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, whenever the user clicks the Apply button in a
  commondialog
-------------------------------------------------------------------------------}
function gtkDialogApplyclickedCB(widget: PGtkWidget; data: gPointer): GBoolean;
  cdecl;
var
  theDialog : TCommonDialog;
  FontName: string;
  ALogFont: TLogFont;
  FontChooser: PGtkFontChooser;
  FontDesc: PPangoFontDescription;
  APangoFontFamily: PPangoFontFamily;
begin
  Result := False;

  if (Widget=nil) then ;
  theDialog := TCommonDialog(TGtk3Dialog(data).CommonDialog);
  if (theDialog is TFontDialog)
  and (fdApplyButton in TFontDialog(theDialog).Options)
  and (Assigned(TFontDialog(theDialog).OnApplyClicked)) then
  begin
    FontChooser := PGtkFontChooser(TGtk3Dialog(data).Widget);
    APangoFontFamily := gtk_font_chooser_get_font_family(FontChooser);
    FontName := APangoFontFamily^.get_name;
    //gtk_font_selection_dialog_get_font_name(
    // {%H-}pgtkfontselectiondialog(theDialog.Handle));
    if IsFontNameXLogicalFontDesc(FontName) then
    begin
      // extract basic font attributes from the font name in XLFD format
      ALogFont:=XLFDNameToLogFont(FontName);
      TFontDialog(theDialog).Font.Assign(ALogFont);
      // set the font name in XLFD format
      // a font name in XLFD format overrides in the gtk interface all other font
      // settings.
      TFontDialog(theDialog).Font.Name := FontName;
    end else begin
      FontDesc := pango_font_description_from_string(PChar(FontName));
      with TFontDialog(theDialog).Font do
      begin
        BeginUpdate;
        Size := pango_font_description_get_size(FontDesc) div PANGO_SCALE;
        if pango_font_description_get_weight(FontDesc) >= PANGO_WEIGHT_BOLD then
          Style := Style + [fsBold]
        else
          Style := Style - [fsBold];
        if pango_font_description_get_style(FontDesc) > PANGO_STYLE_NORMAL then
          Style := Style + [fsItalic]
        else
          Style := Style - [fsItalic];
        Name := pango_font_description_get_family(FontDesc);
        EndUpdate;
      end;
      pango_font_description_free(FontDesc);
    end;
    TFontDialog(theDialog).OnApplyClicked(theDialog);
  end;
end;

function gtkDialogOKclickedCB( widget: PGtkWidget; data: gPointer) : GBoolean; cdecl;
var
  theDialog : TCommonDialog;
  Fpointer : Pointer;
  // colordialog
  colorsel : PGtkColorSelection;
  newColor : TGdkColor;
  // fontdialog
  FontName : String;
  ALogFont  : TLogFont;
  // filedialog
  rowNum   : gint;
  fileInfo : PGChar;

  fileList : PGSList;
  FontDesc: PPangoFontDescription;

  DirName  : string;
  FileName : string;
  Files: TStringList;
  CurFilename: string;
  //SelectedFont: PGdkFont;
  x: Integer;
  Argba: TGdkRGBA;
  ARed: Byte;
  AGreen: Byte;
  ABlue: Byte;

  function CheckOpenedFilename(var AFilename: string): boolean;
  begin
    Result:=true;

    // maybe file already exists
    if (ofOverwritePrompt in TOpenDialog(theDialog).Options) and
      FileExistsUTF8(AFilename) then
    begin
      Result := MessageDlg(rsfdOverwriteFile,
                         Format(rsfdFileAlreadyExists,[AFileName]),
                         mtConfirmation,[mbOk,mbCancel],0)=mrOk;
      if not Result then exit;
    end;
  end;

  procedure AddFile(List: TStrings; const NewFile: string);
  var
    i: Integer;
  begin
    for i:=0 to List.Count-1 do
      if List[i]=NewFile then exit;
    List.Add(NewFile);
  end;

begin
  Result := True;
  if (Widget=nil) then ;
  theDialog := TCommonDialog(TGtk3Dialog(data).CommonDialog);
  FPointer := Pointer(TGtk3Dialog(theDialog.Handle).Widget);

  if theDialog is TFileDialog then
  begin
    FileName := gtk_file_chooser_get_filename(PGtkFileChooser(FPointer));

    if theDialog is TOpenDialog then
    begin
      // check extra options
      if ofAllowMultiSelect in TOpenDialog(theDialog).Options then
      begin
        DirName:=ExtractFilePath(FileName);
        TFileDialog(data).FileName := '';
        Files:=TStringList(TFileDialog(theDialog).Files);
        Files.Clear;
        if (Filename<>'') then
        begin
          Result:=CheckOpenedFilename(Filename);
          if not Result then exit;
          AddFile(Files,FileName);
        end;
        // fileList := gtk_file_selection_get_selections(PGtkFileSelection(FPointer));
        FileList := gtk_file_chooser_get_filenames(PGtkFileChooser(FPointer));
        rowNum := 0;
        for x := 0 to g_slist_length(FileList) - 1 do
        // while FileList^ <> nil do
        begin
          fileInfo := g_slist_nth_data(FileList, x);
          // FileList^;
          CurFilename := FileInfo; // convert PChar to AnsiString (not typecast)
          if (CurFilename<>'') and (Files.IndexOf(CurFilename)<0) then
          begin
            CurFilename:=DirName+fileInfo;
            Result:=CheckOpenedFilename(CurFilename);
            if not Result then exit;
            Files.Add(CurFilename);
          end;
          // inc(FileList);
          inc(rowNum);
        end;
        // Dec(FileList, rowNum);
        g_slist_free(FileList);
        // g_strfreev(fileList);
      end
      else
      begin
        Result:=CheckOpenedFilename(Filename);
        if not Result then exit;
        TFileDialog(TGtk3Dialog(data).CommonDialog).FileName := Filename;
      end;
    end else
      TFileDialog(TGtk3Dialog(data).CommonDialog).FileName := Filename;
  end else
  if theDialog is TColorDialog then
  begin
    colorSel := PGtkColorSelection(PGtkColorSelectionDialog(FPointer)^.color_selection);
    gtk_color_selection_get_current_rgba(ColorSel, @Argba);
    // gtk_color_selection_get_current_color(colorsel, @newColor);
    // ARed := (AColor and $FF) / 255;
    // AGreen := ((AColor shr 8) and $FF) / 255;
    // ABlue := ((AColor shr 16) and $FF) / 255;
    ARed := Byte(Round(Argba.red * 255));
    AGreen := Byte(Round(Argba.green * 255));
    ABlue := Byte(Round(Argba.blue * 255));
    TColorDialog(theDialog).Color := RGBToColor(ARed, AGreen, ABlue);
    {$IFDEF VerboseColorDialog}
    DebugLn('gtkDialogOKclickedCB ',DbgS(TColorDialog(theDialog).Color));
    {$ENDIF}
  end else
  if theDialog is TFontDialog then
  begin
    //DebugLn('Trace:Pressed OK in FontDialog');
    FontName := gtk_font_chooser_get_font(PGtkFontChooser(FPointer));
    // FontName := gtk_font_selection_dialog_get_font_name(
    //                                         pgtkfontselectiondialog(FPointer));
    //debugln('gtkDialogOKclickedCB FontName=',FontName);
    //SelectedFont:=gdk_font_load(PChar(FontName));
    //debugln('gtkDialogOKclickedCB ',dbgs(SelectedFont));

    if IsFontNameXLogicalFontDesc(FontName) then
    begin
      // extract basic font attributes from the font name in XLFD format
      ALogFont:=XLFDNameToLogFont(FontName);
      TFontDialog(theDialog).Font.Assign(ALogFont);
      // set the font name in XLFD format
      // a font name in XLFD format overrides in the gtk interface all other font
      // settings.
      TFontDialog(theDialog).Font.Name := FontName;
    end else
    begin
      FontDesc := pango_font_description_from_string(PChar(FontName));
      with TFontDialog(theDialog).Font do
      begin
        BeginUpdate;
        Size := pango_font_description_get_size(FontDesc) div PANGO_SCALE;
        if pango_font_description_get_weight(FontDesc) >= PANGO_WEIGHT_BOLD then
          Style := Style + [fsBold]
        else
          Style := Style - [fsBold];
        if pango_font_description_get_style(FontDesc) > PANGO_STYLE_NORMAL then
          Style := Style + [fsItalic]
        else
          Style := Style - [fsItalic];
        Name := pango_font_description_get_family(FontDesc);
        EndUpdate;
      end;
      pango_font_description_free(FontDesc);
    end;

    //DebugLn('Trace:-----'+TFontDialog(theDialog).Font.Name+'----');
  end;

  StoreCommonDialogSetup(theDialog);
  theDialog.UserChoice := mrOK;

end;

{-------------------------------------------------------------------------------
  function gtkDialogCancelclickedCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, whenever the user clicks the cancel button in a
  commondialog
-------------------------------------------------------------------------------}
function gtkDialogCancelclickedCB(widget: PGtkWidget; data: gPointer): GBoolean;
  cdecl;
var
  theDialog : TCommonDialog;
begin
  Result := False;
  if (Widget=nil) then ;
  theDialog := TCommonDialog(data);
  if theDialog is TFileDialog then
  begin
    TFileDialog(data).FileName := '';
  end;
  StoreCommonDialogSetup(theDialog);
  theDialog.UserChoice := mrCancel;
end;

{-------------------------------------------------------------------------------
  function GTKDialogRealizeCB
  Params: Widget: PGtkWidget; Data: Pointer
  Result: GBoolean

  This function is called, whenever a commondialog window is realized
-------------------------------------------------------------------------------}
function GTKDialogRealizeCB(Widget: PGtkWidget; Data: Pointer): GBoolean; cdecl;
var
  LCLComponent: TObject;
  AHandle: HWND;
begin
  Result := False;
  if (Data=nil) then ;
  if Widget^.get_has_window and Gtk3IsGdkWindow(Widget^.window) then
  begin
    gdk_window_set_events(Widget^.window,
      gdk_window_get_events(Widget^.window)
        or GDK_KEY_RELEASE_MASK or GDK_KEY_PRESS_MASK);

  end;
  AHandle := HwndFromGtkWidget(Widget);
  if (AHandle <> 0) and (wtDialog in TGtk3Widget(AHandle).WidgetType) then
  begin
    LCLComponent := TGtk3Dialog(AHandle).CommonDialog;
    if LCLComponent is TCommonDialog then
      TCommonDialog(LCLComponent).DoShow;
  end;
  Result := True;
end;

{-------------------------------------------------------------------------------
  function gtkDialogCloseQueryCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, before a commondialog is destroyed
-------------------------------------------------------------------------------}
function gtkDialogCloseQueryCB(widget: PGtkWidget; data: gPointer): GBoolean;
  cdecl;
var
  theDialog : TCommonDialog;
  CanClose: boolean;
  AHandle: HWND;
begin
  Result := False; // true = do nothing, false = destroy or hide window
  if (Data=nil) then ;
  // data is not the commondialog. Get it manually.
  AHandle := HwndFromGtkWidget(Widget);
  if (AHandle <> 0) and (wtDialog in TGtk3Widget(AHandle).WidgetType) then
  begin
    theDialog := TGtk3Dialog(AHandle).CommonDialog;
    if theDialog = nil then exit;
    if theDialog.OnCanClose<>nil then
    begin
      CanClose:=True;
      theDialog.DoCanClose(CanClose);
      Result := not CanClose;
    end;
    if not Result then
    begin
      StoreCommonDialogSetup(theDialog);
      DestroyCommonDialogAddOns(theDialog);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  function gtkDialogDestroyCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, when a commondialog is destroyed
-------------------------------------------------------------------------------}
function gtkDialogDestroyCB(widget: PGtkWidget; data: gPointer): GBoolean; cdecl;
begin
  Result := True;
  if (Widget=nil) then ;
  TCommonDialog(data).UserChoice := mrCancel;
  TCommonDialog(data).Close;
end;

{-------------------------------------------------------------------------------
  function GTKDialogKeyUpDownCB
  Params: Widget: PGtkWidget; Event : pgdkeventkey; Data: gPointer
  Result: GBoolean

  This function is called, whenever a key is pressed or released in a common
  dialog window
-------------------------------------------------------------------------------}
function GTKDialogKeyUpDownCB(Widget: PGtkWidget; Event : pgdkeventkey;
  Data: gPointer) : GBoolean; cdecl;
begin
  //debugln('GTKDialogKeyUpDownCB A ');
  Result := False;
  (*
  if (Widget=nil) then ;
  case gdk_event_get_type(Event) of

  GDK_KEY_RELEASE, GDK_KEY_PRESS:
    begin
      if Event^.KeyVal = GDK_KEY_Escape
      then begin
        StoreCommonDialogSetup(TCommonDialog(data));
        TCommonDialog(data).UserChoice:=mrCancel;
      end;
      if (TCommonDialog(data) is TOpenDialog) then begin
        UpdateDetailView(TOpenDialog(data));
      end;
    end;

  end;
  *)
end;

{-------------------------------------------------------------------------------
  function GTKDialogFocusInCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, when a widget of a commondialog gets focus
-------------------------------------------------------------------------------}
function GTKDialogFocusInCB(widget: PGtkWidget; data: gPointer): GBoolean;
  cdecl;
var
  theDialog: TCommonDialog;
begin
  //debugln('GTKDialogFocusInCB A ');
  Result := False;
  if (Data=nil) then ;
  (*
  theDialog:=TCommonDialog(GetLCLObject(Widget));
  if (theDialog is TOpenDialog) then begin
    UpdateDetailView(TOpenDialog(theDialog));
  end;
  *)
end;

{-------------------------------------------------------------------------------
  function GTKDialogMenuActivateCB
  Params: widget: PGtkWidget; data: gPointer
  Result: GBoolean

  This function is called, whenever a menu of a commondialog is activated
-------------------------------------------------------------------------------}
function GTKDialogMenuActivateCB(widget: PGtkWidget; data: gPointer): GBoolean;
  cdecl;
var
  theDialog: TCommonDialog;
  (*
  procedure CheckFilterActivated(FilterWidget: PGtkWidget);
  var
    AFilterEntry: TFileSelFilterEntry;
  begin
    if FilterWidget=nil then exit;
    AFilterEntry:=TFileSelFilterEntry(g_object_get_data(PGObject(FilterWidget),
                                      'LCLIsFilterMenuItem'));
    if (AFilterEntry<>nil) and (AFilterEntry.Mask<>nil) then
    begin
      PopulateFileAndDirectoryLists({%H-}PGtkFileSelection(theDialog.Handle),
                                    AFilterEntry.Mask);
      TFileDialog(TheDialog).IntfFileTypeChanged(AFilterEntry.FilterIndex + 1);
      UpdateDetailView(TOpenDialog(theDialog));
    end;
  end;

var
  AHistoryEntry: PFileSelHistoryEntry;
    *)
begin
  Result:=false;
  (*
  if (Data=nil) then ;
  theDialog:=TCommonDialog(GetNearestLCLObject(Widget));
  if (theDialog is TOpenDialog) then begin
    // check if history activated
    AHistoryEntry:=g_object_get_data(PGObject(Widget),
                                       'LCLIsHistoryMenuItem');
    if (AHistoryEntry<>nil) and (AHistoryEntry^.Filename<>nil) then begin
      // user has choosen a history file
      // -> select it in the filedialog
      gtk_file_chooser_set_current_folder({%H-}PGtkFileChooser(theDialog.Handle),AHistoryEntry^.Filename);

      UpdateDetailView(TOpenDialog(theDialog));
    end;
  end;
  *)
end;

// ---------------------- END OF signals ---------------------------------------

{ TGtk3WSOpenDialog }

class function TGtk3WSOpenDialog.CreateOpenDialogFilter(
  OpenDialog: TOpenDialog; Chooser: PGtkFileChooser): string;
var
  ListOfFileSelFilterEntry: TFPList;
  i, j, k: integer;
  GtkFilter, GtkSelFilter: PGtkFileFilter;
  MaskList: TStringList;
  FilterEntry: TFileSelFilterEntry;
  FilterIndex: Integer;
begin
  FilterIndex := OpenDialog.FilterIndex;
  ExtractFilterList(OpenDialog.Filter, ListOfFileSelFilterEntry, false);
  GtkSelFilter := nil;
  if ListOfFileSelFilterEntry.Count > 0 then
  begin
    j := 1;
    MaskList := TStringList.Create;
    MaskList.Delimiter := ';';
    for i := 0 to ListOfFileSelFilterEntry.Count-1 do
    begin
      GtkFilter := gtk_file_filter_new();

      FilterEntry := TFileSelFilterEntry(ListOfFileSelFilterEntry[i]);
      MaskList.DelimitedText := FilterEntry.Mask;

      for k := 0 to MaskList.Count - 1 do
        gtk_file_filter_add_pattern(GtkFilter, PgChar(MaskList.Strings[k]));
      gtk_file_filter_set_name(GtkFilter, PgChar(FilterEntry.Description));

      gtk_file_chooser_add_filter(Chooser, GtkFilter);

      if j = FilterIndex then
        GtkSelFilter := GtkFilter;

      Inc(j);
      GtkFilter := nil;
    end;
    MaskList.Free;
  end;

  FreeListOfFileSelFilterEntry(ListOfFileSelFilterEntry);
  //g_object_set_data(PGObject(Chooser), 'LCLFilterList', ListOfFileSelFilterEntry);

  if GtkSelFilter <> nil then
    gtk_file_chooser_set_filter(Chooser, GtkSelFilter);

  Result := 'hm'; { Don't use '' as null return as this is used for *.* }
end;

class procedure TGtk3WSOpenDialog.CreateOpenDialogHistory(
  OpenDialog: TOpenDialog; SelWidget: PGtkWidget);
(*
var
  HistoryList: TFPList; // list of THistoryListEntry
  AHistoryEntry: PFileSelHistoryEntry;
  i: integer;
  s: string;
  HBox, LabelWidget, HistoryPullDownWidget,
  MenuWidget, MenuItemWidget: PGtkWidget;
  *)
begin
  (*
  if OpenDialog.HistoryList.Count>0 then begin

    // create the HistoryList where the current state of the history is stored
    HistoryList:=TFPList.Create;
    for i:=0 to OpenDialog.HistoryList.Count-1 do begin
      s:=OpenDialog.HistoryList[i];
      if s<>'' then begin
        New(AHistoryEntry);
        HistoryList.Add(AHistoryEntry);
        AHistoryEntry^.Filename := StrAlloc(length(s)+1);
        StrPCopy(AHistoryEntry^.Filename, s);
        AHistoryEntry^.MenuItem:=nil;
      end;
    end;

    // create a HBox so that the history is left justified
    HBox:=gtk_hbox_new(false,0);
    g_object_set_data(PGObject(SelWidget), 'LCLHistoryHBox', HBox);
    gtk_file_chooser_set_extra_widget(PGtkDialog(SelWidget),HBox);

    // create the label 'History:'
    s:=rsgtkHistory;
    LabelWidget:=gtk_label_new(PChar(s));
    gtk_box_pack_start(GTK_BOX(HBox),LabelWidget,false,false,5);
    gtk_widget_show(LabelWidget);

    // create the pull down
    HistoryPullDownWidget:=gtk_option_menu_new;
    g_object_set_data(PGObject(SelWidget), 'LCLHistoryPullDown',
      HistoryPullDownWidget);
    gtk_box_pack_start(GTK_BOX(HBox),HistoryPullDownWidget,false,false,5);
    gtk_widget_show(HistoryPullDownWidget);
    gtk_widget_show_all(HBox);

    // create the menu (the content of the pull down)
    MenuWidget:=gtk_menu_new;
    SetLCLObject(MenuWidget,OpenDialog);
    for i:=0 to HistoryList.Count-1 do begin
      // create the menu items in the history menu
      MenuItemWidget:=gtk_menu_item_new_with_label(
                                PFileSelHistoryEntry(HistoryList[i])^.Filename);
      // connect the new MenuItem to the HistoryList entry
      g_object_set_data(PGObject(MenuItemWidget), 'LCLIsHistoryMenuItem',
        HistoryList[i]);
      // add activation signal and add to menu
      g_signal_connect(GTK_OBJECT(MenuItemWidget), 'activate',
                         gtk_signal_func(@GTKDialogMenuActivateCB),
                         OpenDialog);
      gtk_menu_append(MenuWidget, MenuItemWidget);
      gtk_widget_show(MenuItemWidget);
    end;
    gtk_widget_show(MenuWidget);
    gtk_option_menu_set_menu(GTK_OPTION_MENU(HistoryPullDownWidget),
                             MenuWidget);
  end else begin
    MenuWidget:=nil;
    HistoryList:=nil
  end;
  g_object_set_data(PGObject(SelWidget), 'LCLHistoryMenu', MenuWidget);
  g_object_set_data(PGObject(SelWidget), 'LCLHistoryList', HistoryList);
  *)
end;

class procedure TGtk3WSOpenDialog.CreatePreviewDialogControl(
  PreviewDialog: TPreviewFileDialog; Chooser: PGtkFileChooser);
var
  PreviewWidget: PGtkWidget;
  AControl: TPreviewFileControl;
  alloc:TGtkAllocation;
begin
  AControl := PreviewDialog.PreviewFileControl;
  if AControl = nil then Exit;
  PreviewWidget := TGtk3CustomControl(AControl.Handle).Widget;
  g_object_set_data(PGObject(PreviewWidget),'LCLPreviewFixed',PreviewWidget);
  gtk_widget_set_size_request(PreviewWidget,AControl.Width,AControl.Height);
  {alloc.height:=AControl.Height;
  alloc.width:=AControl.Width;
  alloc.x:=0;
  alloc.y:=0;
  PreviewWidget^.size_allocate(@alloc);
  PreviewWidget^.queue_resize;}
  gtk_file_chooser_set_preview_widget(Chooser, PreviewWidget);
  gtk_widget_show(PreviewWidget);
end;

{
  Adds some functionality to a gtk file selection dialog.
  - multiselection
  - range selection
  - close on escape
  - file information
  - history pulldown
  - filter pulldown
  - preview control

  requires: gtk+ 2.6
}
class function TGtk3WSOpenDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
var
  OpenDialog: TOpenDialog absolute ACommonDialog;
  HelpButton: PGtkWidget;
  InitialFilename: String;
  Dlg: TGtk3Dialog;
  Chooser: PGtkFileChooser;
  //FrameWidget: PGtkWidget;
  //HBox: PGtkWidget;
  //FileDetailLabel: PGtkWidget;
begin
  Dlg := TGtk3FileDialog.Create(ACommonDialog);
  Result := THandle(Dlg);
  Chooser := PGtkFileChooser(Dlg.Widget);
  TGtk3WSFileDialog.SetCallbacks(Dlg.Widget, Dlg);

  if OpenDialog.InheritsFrom(TSaveDialog) then
    if OpenDialog.InitialDir <> '' then
      gtk_file_chooser_set_current_folder(Chooser, Pgchar(OpenDialog.InitialDir));

  // Help button
  if (ofShowHelp in OpenDialog.Options) then
  begin
    HelpButton := gtk_dialog_add_button(PGtkDialog(Dlg.Widget), GTK_STOCK_HELP, GTK_RESPONSE_NONE);
    g_signal_connect_data(HelpButton, 'clicked', TGCallback(@gtkDialogHelpclickedCB), Dlg, nil, 0);
  end;

  if ofAllowMultiSelect in OpenDialog.Options then
    gtk_file_chooser_set_select_multiple(Chooser, True);

  // History List - a frame with an option menu
  CreateOpenDialogHistory(OpenDialog, Dlg.Widget);

  // Filter
  CreateOpenDialogFilter(OpenDialog, Chooser);

  // connect change event
  g_signal_connect_data(Dlg.Widget,
    'selection-changed', TGCallback(@gtkFileChooserSelectionChangedCB), Dlg, nil, 0);

  // Sets the dialog options

  // ofForceShowHidden
  if (ofForceShowHidden in OpenDialog.Options) then
    gtk_file_chooser_set_show_hidden(Chooser, True);

  (*  TODO
  // Details - a frame with a label
  if (ofViewDetail in OpenDialog.Options) then begin

    // create the frame around the information
    FrameWidget:=gtk_frame_new(PChar(rsFileInformation));
    //gtk_box_pack_start(GTK_BOX(Dlg.Widget^.main_vbox),
    //                   FrameWidget,false,false,0);
    gtk_box_pack_start(GTK_BOX(gtk_file_chooser_get_extra_widget(Chooser)),
                       FrameWidget,false,false,0);
    gtk_widget_show(FrameWidget);
    // create a HBox, so that the information is left justified
    HBox:=gtk_hbox_new(false,0);
    gtk_container_add(GTK_CONTAINER(FrameWidget), HBox);
    // create the label for the file information
    FileDetailLabel:=gtk_label_new(PChar(rsDefaultFileInfoValue));
    gtk_box_pack_start(GTK_BOX(HBox),FileDetailLabel,false,false,5);
    gtk_widget_show_all(HBox);
  end else
    FileDetailLabel:=nil;
  g_object_set_data(PGObject(SelWidget), 'FileDetailLabel', FileDetailLabel);
  *)
  // preview
  if (OpenDialog is TPreviewFileDialog) then
    CreatePreviewDialogControl(TPreviewFileDialog(OpenDialog), Chooser);

  // set initial filename (gtk expects an absolute filename)
  InitialFilename := TrimFilename(OpenDialog.FileName);
  if InitialFilename <> '' then
  begin
    if not FilenameIsAbsolute(InitialFilename) and (OpenDialog.InitialDir <> '') then
      InitialFilename := TrimFilename(OpenDialog.InitialDir + PathDelim + InitialFilename);
    if not FilenameIsAbsolute(InitialFilename) then
      InitialFilename := CleanAndExpandFilename(InitialFilename);
    gtk_file_chooser_set_filename(Chooser, PChar(InitialFilename));
  end;

  //if InitialFilter <> 'none' then
  //  PopulateFileAndDirectoryLists(Dlg.Widget, InitialFilter);

end;

{ TGtk3WSFileDialog }


class procedure TGtk3WSFileDialog.SetCallbacks(const AGtkWidget: PGtkWidget;
  const AWidgetInfo: TGtk3Dialog);
begin
  TGtk3WSCommonDialog.SetCallbacks(AGtkWidget, AWidgetInfo);
  g_signal_connect_data(AGtkWidget, 'response', TGCallback(@Gtk2FileChooserResponseCB), AWidgetInfo, nil, 0);
  g_signal_connect_data(AGtkWidget, 'notify', TGCallback(@Gtk2FileChooserNotifyCB), AWidgetInfo, nil, 0);
end;

{
  Creates a new TFile/Open/SaveDialog
}
class function TGtk3WSFileDialog.CreateHandle(const ACommonDialog: TCommonDialog
  ): THandle;
var
  FileDialog: TFileDialog absolute ACommonDialog;
  Action: TGtkFileChooserAction;
  Button1: String;
  Widget: PGtkWidget;
  ADialog: TGtk3FileDialog;
  AFileDialog: PGtkFileChooserDialog;
  AParams: TCreateParams;
begin
  // Defines an action for the dialog and creates it
  Action := GTK_FILE_CHOOSER_ACTION_OPEN;
  Button1 := GTK_STOCK_OPEN;

  if (FileDialog is TSaveDialog) or (FileDialog is TSavePictureDialog) then
  begin
    Action := GTK_FILE_CHOOSER_ACTION_SAVE;
    Button1 := GTK_STOCK_SAVE;
  end
  else
  if FileDialog is TSelectDirectoryDialog then
  begin
    Action := GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER;
    Button1 := GTK_STOCK_OPEN;
  end;

  if Button1<>'' then ;
  if Action=0 then ;

  Result := THandle(TGtk3FileDialog.Create(ACommonDialog));
  // AFileDialog := PGtkFileChooserDialog(ADialog.Widget);
  // AFileDialog^.set_title(PChar(FileDialog.Title));
  // AFileDialog^.set_r
  (*
  Widget := gtk_file_chooser_dialog_new(PChar(FileDialog.Title), nil, Action,
    PChar(GTK_STOCK_CANCEL), [GTK_RESPONSE_CANCEL, PChar(Button1), GTK_RESPONSE_OK, nil]);

  {$ifdef GTK_2_8}
  if FileDialog is TSaveDialog then
  begin
    gtk_file_chooser_set_do_overwrite_confirmation(Widget,
      ofOverwritePrompt in TOpenDialog(FileDialog).Options);
  end;
  {$endif}

  if FileDialog.InitialDir <> '' then
    gtk_file_chooser_set_current_folder(Widget, Pgchar(FileDialog.InitialDir));

  if gtk_file_chooser_get_action(Widget) in
    [GTK_FILE_CHOOSER_ACTION_SAVE, GTK_FILE_CHOOSER_ACTION_CREATE_FOLDER]
  then
    gtk_file_chooser_set_current_name(Widget, Pgchar(FileDialog.FileName));

  Result := THandle({%H-}PtrUInt(Widget));
  WidgetInfo := CreateWidgetInfo(Widget);
  WidgetInfo^.LCLObject := ACommonDialog;
  TGtk3WSCommonDialog.SetSizes(Widget, WidgetInfo);
  // SetCallbacks(Widget, WidgetInfo);
  *)
end;

{ TGtk3WSCommonDialog }

{------------------------------------------------------------------------------
  Method: SetColorDialogColor
  Params:  ColorSelection : a gtk color selection dialog;
           Color          : the color to select
  Returns: nothing

  Set the color of the color selection dialog
 ------------------------------------------------------------------------------}
class procedure TGtk3WSCommonDialog.SetColorDialogColor(ColorSelection: PGtkColorSelectionDialog;
  Color: TColor);
var
  SelectionColor: TGDKColor;
  colorSel: PGtkColorSelection;
begin
  (*
  Color := TColor(ColorToRGB(Color));
  SelectionColor := TColorToTGDKColor(Color);
  colorSel := PGtkColorSelection(ColorSelection^.colorsel);
  gtk_color_selection_set_current_color(colorSel, @SelectionColor);
  gtk_color_selection_set_previous_color(colorSel, @SelectionColor);
  *)
end;

class procedure TGtk3WSCommonDialog.SetColorDialogPalette(
  ColorSelection: PGtkColorSelectionDialog; Palette: TStrings);
const
  PaletteSetting = 'gtk-color-palette';
(*
var
  colorSel: PGtkColorSelection;
  settings: PGtkSettings;
  new_palette: Pgchar;
  colors: PGdkColor;
  colors_len: gint;

  procedure FillCustomColors;
  var
    i, AIndex: integer;
    AColor: TColor;
  begin
    for i := 0 to Palette.Count - 1 do
      if ExtractColorIndexAndColor(Palette, i, AIndex, AColor) then
        if AIndex < colors_len then
          colors[AIndex] := TColorToTGDKColor(AColor);
  end;
  *)
begin
  (*
  colorSel := PGtkColorSelection(ColorSelection^.colorsel);
  // show palette
  gtk_color_selection_set_has_palette(colorSel, True);

  // replace palette. it is stored in 'gtk-color-palette' settings
  // 1. get original palette => we will know colors and replace only part of it
  settings := gtk_widget_get_settings(PGtkWidget(colorSel));
  new_palette := nil;
  g_object_get(settings, PaletteSetting, [@new_palette, nil]);
  gtk_color_selection_palette_from_string(new_palette, colors, @colors_len);
  g_free(new_palette);

  // 2. fill original palette with our custom colors
  FillCustomColors;

  // 3. set new palette back to settings
  new_palette := gtk_color_selection_palette_to_string(colors, colors_len);
  g_free(colors);
  gtk_settings_set_string_property(settings, PaletteSetting, new_palette, 'gtk_color_selection_palette_to_string');
  g_free(new_palette);
  *)
end;


class procedure TGtk3WSCommonDialog.SetCallbacks(const AGtkWidget: PGtkWidget;
  const AWidgetInfo: TGtk3Dialog);
begin
  g_signal_connect_data(AGtkWidget,
    'destroy', TGCallback(@gtkDialogDestroyCB), AWidgetInfo, nil, 0);
  g_signal_connect_data(AGtkWidget,
    'delete-event', TGCallback(@gtkDialogCloseQueryCB), AWidgetInfo, nil, 0);
  g_signal_connect_data(AGtkWidget,
    'key-press-event', TGCallback(@GTKDialogKeyUpDownCB), AWidgetInfo, nil, 0);
  g_signal_connect_data(AGtkWidget,
    'key-release-event', TGCallback(@GTKDialogKeyUpDownCB), AWidgetInfo, nil, 0);
  g_signal_connect_data(AGtkWidget,
    'realize', TGCallback(@GTKDialogRealizeCB), AWidgetInfo, nil, 0);
end;

class procedure TGtk3WSCommonDialog.SetSizes(const AGtkWidget: PGtkWidget;
  const AWidgetInfo: TGtk3Dialog);
var
  NewWidth, NewHeight: integer;
begin
  // set default size
  NewWidth := TCommonDialog(AWidgetInfo.CommonDialog).Width;
  if NewWidth <= 0 then
    NewWidth := -2; // -2 = let the window manager decide
  NewHeight := TCommonDialog(AWidgetInfo.CommonDialog).Height;
  if NewHeight<=0 then
    NewHeight := -2; // -2 = let the window manager decide
  if (NewWidth > 0) or (NewHeight > 0) then
    gtk_window_set_default_size(PGtkWindow(AGtkWidget), NewWidth, NewHeight);
end;

class function TGtk3WSCommonDialog.CreateHandle(
  const ACommonDialog: TCommonDialog): THandle;
begin
  Result := 0;
end;

class procedure TGtk3WSCommonDialog.ShowModal(const ACommonDialog: TCommonDialog);
var
  AGtkWindow: PGtkWidget;
begin
  if not ACommonDialog.HandleAllocated then
    exit;
  AGtkWindow := TGtk3Dialog(ACommonDialog.Handle).Widget;
  DebugLn('TGtk3WSCommonDialog.ShowModal widget ',dbgHex({%H-}PtrUInt(AGtkWindow)));
  if not Gtk3IsWidget(AGtkWindow) then
    raise Exception.Create('TGtk3WSCommonDialog.ShowModal error');
  // ReleaseMouseCapture;
  // GtkWindow^.set_title(PChar(ACommonDialog.Title));
  PGtkDialog(AGtkWindow)^.set_position(GTK_WIN_POS_CENTER);
  PGtkDialog(AGtkWindow)^.set_application(GTK3WidgetSet.Gtk3Application);
  PGtkDialog(AGtkWindow)^.set_modal(True);
  PGtkDialog(AGtkWindow)^.show_all;
  PGtkDialog(AGtkWindow)^.present;
  (*
  GtkWindow:={%H-}PGtkWindow(ACommonDialog.Handle);
  gtk_window_set_title(GtkWindow,PChar(ACommonDialog.Title));
  if ACommonDialog is TColorDialog then
  begin
    SetColorDialogColor(PGtkColorSelectionDialog(GtkWindow),
                        TColorDialog(ACommonDialog).Color);
    SetColorDialogPalette(PGtkColorSelectionDialog(GtkWindow),
      TColorDialog(ACommonDialog).CustomColors);
  end;

  gtk_window_set_position(GtkWindow, GTK_WIN_POS_CENTER);
  GtkWindowShowModal(nil, GtkWindow);
  *)
end;

class procedure TGtk3WSCommonDialog.DestroyHandle(
  const ACommonDialog: TCommonDialog);
begin
  { TODO: cleanup }
  DebugLn('TGtk3WSCommonDialog.DestroyHandle ');
  if ACommonDialog.HandleAllocated then
    TGtk3Dialog(ACommonDialog.Handle).Free;
  // TGtk3WidgetSet(WidgetSet).DestroyLCLComponent(ACommonDialog);
end;

{ TGtk3WSColorDialog }

class function TGtk3WSColorDialog.CreateHandle(
  const ACommonDialog: TCommonDialog): THandle;
begin
  Result:=THandle(TGtk3newColorSelectionDialog.Create(ACommonDialog));
end;

{ TGtk3WSFontDialog }

class function TGtk3WSFontDialog.CreateHandle(const ACommonDialog: TCommonDialog): THandle;
begin
  Result:=THandle(TGtk3FontSelectionDialog.Create(ACommonDialog));
end;

end.

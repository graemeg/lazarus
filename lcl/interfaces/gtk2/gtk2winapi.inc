{%MainUnit gtk2int.pas}

{******************************************************************************
                         All GTK Winapi implementations.
                   Initial Revision  : Sat Nov 13 12:53:53 1999


  !! Keep alphabetical !!

  Support routines go to gtk2proc.pp

 ******************************************************************************
 Implementation
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
{$IFOPT C-}
// Uncomment for local trace
//  {$C+}
//  {$DEFINE ASSERT_IS_ON}
{$EndIf}

{off $define VerboseScrollWindowEx}


//##apiwiz##sps##   // Do not remove

{------------------------------------------------------------------------------
  Method:   Arc
  Params:   left, top, right, bottom, angle1, angle2
  Returns:  Nothing

  Use Arc to draw an elliptically curved line with the current Pen.
  The angles angle1 and angle2 are 1/16th of a degree. For example, a full
  circle equals 5760 (16*360). Positive values of Angle and AngleLength mean
  counter-clockwise while negative values mean clockwise direction.
  Zero degrees is at the 3'o clock position.
  Angle1 is the starting angle. Angle2 is relative to Angle1 (added).
  Example:
    Angle1 = 10*16, Angle2 = 30*16 will draw an arc from 10 to 40 degree.

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.Arc(DC: HDC; Left, top, right, bottom, angle1,
  angle2: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  DCOrigin: TPoint;
  Angle: Integer;
begin
  Result := IsValidDC(DC);
  if not Result then Exit;
  
    // Draw outline
  DevCtx.SelectPenProps;

  if not (dcfPenSelected in DevCtx.Flags)
  then begin
    Result := False;
    Exit;
  end;
  if DevCtx.IsNullPen then Exit;

  if DevCtx.HasTransf then
  begin
    DevCtx.TransfRect(Left, Top, Right, Bottom);
    DevCtx.TransfNormalize(Left, Right);
    DevCtx.TransfNormalize(Top, Bottom);
    // we must convert angles too because of possible negative axis orientations
    Angle := Angle1 + Angle2;
    DevCtx.TransfAngles(Angle1, Angle);
    Angle2 := Angle - Angle1;
  end;

  DCOrigin := DevCtx.Offset;
  inc(Left, DCOrigin.X);
  inc(Top, DCOrigin.Y);
  inc(Right, DCOrigin.X);
  inc(Bottom, DCOrigin.Y);

  {$IFDEF DebugGDKTraps}BeginGDKErrorTrap;{$ENDIF}
  DevCtx.RemovePixbuf;
  gdk_draw_arc(DevCtx.Drawable, DevCtx.GC, 0, left, top, right - left, bottom - top,
                   Angle1*4, Angle2*4);
  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
end;

 {------------------------------------------------------------------------------
  Method:   AngleChord
  Params:   DC, x1, y1, x2, y2, angle1, angle2
  Returns:  Nothing

  Use AngleChord to draw a filled Chord-shape on the canvas. The angles angle1
  and angle2 are 1/16th of a degree. For example, a full circle equals 5760
  16*360). Positive values of Angle and AngleLength mean counter-clockwise while
  negative values mean clockwise direction. Zero degrees is at the 3'o clock
  position.

------------------------------------------------------------------------------}
function TGtk2WidgetSet.AngleChord(DC: HDC;
  x1, y1, x2, y2, angle1, angle2: Integer): Boolean;
begin
  Result := inherited AngleChord(DC, x1, y1, x2, y2, angle1, angle2);
end;

{------------------------------------------------------------------------------
  Function: BeginPaint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.BeginPaint(Handle: hWnd; var PS : TPaintStruct) : hdc;
var
  Widget: PGtkWidget;
  Info: PWidgetInfo;
  DC: TGtkDeviceContext;
  paintrect : TGDKRectangle;
  Control: TWinControl;

begin
  Widget:={%H-}PGtkWidget(Handle);
  Info:=GetWidgetInfo(Widget);
  if Info<>nil then
    Inc(Info^.PaintDepth);
  PS.hDC:=GetDC(Handle);
  DC:=TGtkDeviceContext(PS.hDC);
  DC.PaintRectangle:=PS.rcPaint;

  Result := PS.hDC;
  
  if Handle <> 0
  then Control := TWinControl(GetLCLObject({%H-}Pointer(Handle)))
  else Control := nil;

  if (Control <> nil)
  and TWSWinControlClass(Control.WidgetSetClass).GetDoubleBuffered(Control)
  and not GTK_WIDGET_DOUBLE_BUFFERED({%H-}PGTKWidget(Handle))
  then begin
    //DebugLn(['TGtk2WidgetSet.BeginPaint ',DbgSName(Control)]);
    paintrect.x := PS.rcPaint.Left;
    paintrect.y := PS.rcPaint.Top;
    paintrect.width := PS.rcPaint.Right- PS.rcPaint.Left;
    paintrect.height := PS.rcPaint.Bottom - PS.rcPaint.Top;
    if (paintrect.width <= 0) or (paintrect.height <=0)
    then begin
      paintrect.x := 0;
      paintrect.y := 0;
      gdk_drawable_get_size(TGtkDeviceContext(Result).Drawable,
                            @paintrect.width, @paintrect.height);
    end;
    gdk_window_freeze_updates(TGtkDeviceContext(Result).Drawable);
    gdk_window_begin_paint_rect (TGtkDeviceContext(Result).Drawable, @paintrect);
  end;
  
end;

{------------------------------------------------------------------------------
  Function: BitBlt
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           Rop:                   The raster operation to be performed
  Returns: True if succesful

  The BitBlt function copies a bitmap from a source context into a destination
  context using the specified raster operation.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc: Integer; Rop: DWORD): Boolean;
begin
  Result := StretchBlt(DestDC, X, Y, Width, Height, SrcDC, XSrc, YSrc, Width,
                       Height, ROP);
end;

{------------------------------------------------------------------------------
  Function: CallNextHookEx
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CallNextHookEx(hHk: HHOOK; ncode: Integer;
  wParam: WParam; lParam: LParam): Integer;
begin
  Result := 0;
  // TODO: TGtk2WidgetSet.CallNextHookEx: Does anything need to be done here?
end;

{------------------------------------------------------------------------------
  Function: CallWindowProc
  Params: lpPrevWndFunc:
          Handle:
          Msg:
          wParam:
          lParam:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CallWindowProc(lpPrevWndFunc: TFarProc; Handle: HWND;
  Msg: UINT; wParam: WParam; lParam: lParam): Integer;
var
  Proc : TWndMethod;
  Mess : TLMessage;
  P : Pointer;
begin
  Result := -1;
  if Handle = 0 then Exit;
  P := g_object_get_data({%H-}PGObject(Handle),'WNDPROC');
  if P <> nil then
    Proc := TWndMethod(P^)
  else
    Exit;
  Mess.msg := msg;
  Mess.LParam := LParam;
  Mess.WParam := WParam;
  Proc(Mess);
  Result := Mess.Result;
end;

{------------------------------------------------------------------------------
  Function: ClientToScreen
  Params:  Handle : HWND; var P : TPoint
  Returns: true on success

  Converts the client-area coordinates of P to screen coordinates.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClientToScreen(Handle : HWND; var P : TPoint) : Boolean;
var
  Position: TPoint;
Begin
  if Handle = 0
  then begin
    Position.X := 0;
    Position.Y := 0;
  end
  else begin
    Position:=GetWidgetClientOrigin({%H-}PGtkWidget(Handle));
  end;

  Inc(P.X, Position.X);
  Inc(P.Y, Position.Y);

  //DebugLn(Format('Trace:  [GTKObject.ClientToScreen] Handle: 0x%x --> (%d, %d)', [Integer(Handle), P.X, P.y]));
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: ClipboardFormatToMimeType
  Params:  FormatID - a registered format identifier (0 is invalid)
  Returns: the corresponding mime type as string
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClipboardFormatToMimeType(
  FormatID: TClipboardFormat): string;
var p: PChar;
begin
  if FormatID<>0 then begin
    p:=gdk_atom_name(FormatID);
    Result:=StrPas(p);
    g_free(p);
  end else
    Result:='';
end;

{------------------------------------------------------------------------------
  Function: ClipboardGetData
  Params:  ClipboardType
           FormatID - a registered format identifier (0 is invalid)
           Stream - If format is available, it will be appended to this stream
  Returns: true on success
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
var
  FormatAtom: TGdkAtom;
  SupportedCnt, i: integer;
  SupportedFormats: PGdkAtom;
  SelData: TGtkSelectionData;
  CompoundTextList: PPGChar;
  CompoundTextCount: integer;

  function IsFormatSupported(CurFormat: TGdkAtom): boolean;
  var
    i: integer;
    AllID: TGdkAtom;
  begin
    //DebugLn('IsFormatSupported CurFormat=',dbgs(CurFormat),' SupportedCnt=',dbgs(SupportedCnt));
    if CurFormat=0 then begin
      Result:=false;
      exit;
    end;
    if SupportedCnt<0 then begin
      Result:=false;
      AllID:=gdk_atom_intern('TARGETS',GdkFalse);
      SelData:=RequestSelectionData(ClipboardWidget,ClipboardType,AllID);
      {$IFDEF DEBUG_CLIPBOARD}
      DebugLn('IsFormatSupported A ',Dbgs(SelData.Selection),
      ' ',HexStr(Cardinal(ClipboardTypeAtoms[ClipboardType]),8),
      ' SelData.Target='+dbgs(SelData.Target),' AllID='+dbgs(AllID),
      ' SelData.TheType='+dbgs(SelData._type)+' ATOM='+dbgs(gdk_atom_intern('ATOM',GdkTrue))+' Name="'+GdkAtomToStr(SelData._type)+'"',
      ' SelData.Length='+dbgs(SelData.Length),
      ' SelData.Format='+dbgs(SelData.Format)
      );
      {$ENDIF}
      if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
      or (SelData.Target<>AllID)
      or (SelData._Type<>gdk_atom_intern('ATOM',GdkFalse))
      or ((SelData.Format shr 3)<=0) then begin
        SupportedCnt:=0;
        exit;
      end;
      SupportedCnt:=SelData.Length div (SelData.Format shr 3);
      SupportedFormats:=PGdkAtom(SelData.Data);
      //DebugLn('IsFormatSupported SupportedCnt=',dbgs(SupportedCnt));

      {$IFDEF DEBUG_CLIPBOARD}
      i:=SupportedCnt-1;
      while (i>=0) do begin
        debugln(' ',dbgs(i),' "',GdkAtomToStr(SupportedFormats[i]),'"');
        dec(i);
      end;
      {$ENDIF}
    end;
    i:=SupportedCnt-1;
    while (i>=0) and (SupportedFormats[i]<>CurFormat) do dec(i);
    Result:=(i>=0);
  end;

  procedure CheckAtomFormat(const atom_name: Pgchar; only_if_exists:gboolean);
  var
    FormatTry: TGdkAtom;
  begin
    if FormatAtom<>0 then exit;
    FormatTry:=gdk_atom_intern(atom_name,only_if_exists);
    if IsFormatSupported(FormatTry) then
      FormatAtom:=FormatTry;
  end;

begin
  {$IfDef DEBUG_CLIPBOARD}
  DebugLn('[TGtk2WidgetSet.ClipboardGetData] A ClipboardWidget=',Dbgs(ClipboardWidget),' FormatID=',ClipboardFormatToMimeType(FormatID),' Now=',dbgs(Now));
  {$EndIf}
  Result:=false;
  if (FormatID=0) or (Stream=nil) then exit;
  if not (ClipboardType in [ctPrimarySelection,ctSecondarySelection,ctClipboard])
  then exit;
  // request the data from the selection owner
  SupportedCnt:=-1;
  SupportedFormats:=nil;
  FillChar(SelData,SizeOf(TGtkSelectionData),0);
  try

    FormatAtom:=FormatID;
    if (FormatAtom=gdk_atom_intern('text/plain',GdkTrue)) then begin
      // text/plain is supported in various formats in gtk
      FormatAtom:=0;
      // check for UTF8 text format 'UTF8_STRING'
      CheckAtomFormat('UTF8_STRING',GdkFalse);
      // The COMPOUND_TEXT format can be converted and is therefore
      // used as default for 'text/plain'
      if (SupportedCnt=0) then
        FormatAtom:=gdk_atom_intern('COMPOUND_TEXT',GdkFalse)
      else begin
        CheckAtomFormat('COMPOUND_TEXT',GdkFalse);
        // then check for simple text format 'text/plain'
        CheckAtomFormat('text/plain',GdkFalse);
        // then check for simple text format STRING
        CheckAtomFormat('STRING',GdkFalse);
        // check for some other formats that can be interpreted as text
        CheckAtomFormat('FILE_NAME',GdkTrue);
        CheckAtomFormat('HOST_NAME',GdkTrue);
        CheckAtomFormat('USER',GdkTrue);
        // the TEXT format is not reliable, but it should be supported
        CheckAtomFormat('TEXT',GdkFalse);
      end;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetData] B  Format=',ClipboardFormatToMimeType(FormatAtom),' FormatAtom=',dbgs(FormatAtom),' Now=',dbgs(Now));
    {$EndIf}
    if FormatAtom=0 then exit;

    // request data from owner
    SelData:=RequestSelectionData(ClipboardWidget,ClipboardType,FormatAtom);
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetData] C  Length=',dbgs(SelData.Length),' Now=',dbgs(Now),' ',
      ' SelData.Selection=',dbgs(SelData.Selection),' SelData.Length=',dbgs(SelData.Length));
    {$EndIf}
    if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
    or (SelData.Target<>FormatAtom) then begin
      {$IfDef DEBUG_CLIPBOARD}
      DebugLn('[TGtk2WidgetSet.ClipboardGetData] REQUESTED FORMAT NOT SUPPORTED  Length=',dbgs(SelData.Length));
      {$ENDIF}
      exit;
    end;

    // write data to stream
    if (SelData.Data<>nil) and (SelData.Length>0) then begin
      if (FormatID=gdk_atom_intern('text/plain',GdkTrue)) then begin
        // the lcl expects the return format as simple text
        // transform if necessary
        if FormatAtom=gdk_atom_intern('COMPOUND_TEXT',GdkTrue) then begin
          CompoundTextList:=nil;
          CompoundTextCount:=gdk_text_property_to_text_list(SelData._Type,
            SelData.Format,SelData.Data,SelData.Length,CompoundTextList);
          try
            {$IfDef DEBUG_CLIPBOARD}
            DebugLn('[TGtk2WidgetSet.ClipboardGetData] D  CompoundTextCount=',dbgs(CompoundTextCount),' Now=',dbgs(Now));
            {$EndIf}
            for i:=0 to CompoundTextCount-1 do
              if (CompoundTextList[i]<>nil) then
                Stream.Write(CompoundTextList[i]^,StrLen(CompoundTextList[i]));
          finally
            gdk_free_text_list(CompoundTextList);
          end;
        end else
          Stream.Write(SelData.Data^,SelData.Length);
      end else begin
        Stream.Write(SelData.Data^,SelData.Length);
      end;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetData] END ',' Now=',dbgs(Now));
    {$EndIf}
    Result:=true;
  finally
    if SupportedFormats<>nil then
      FreeMem(SupportedFormats);
    if (SelData.Data<>nil) and (PGdkAtom(SelData.Data)<>SupportedFormats) then
      FreeMem(SelData.Data);
  end;
end;

{------------------------------------------------------------------------------
  Function: ClipboardGetFormats
  Params:  ClipboardType
  Returns: true on success
           Count contains the number of supported formats
           List is an array of TClipboardType

  ! List will be created. You must free it yourself with FreeMem(List) !
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean;
var
  AllID: TGdkAtom;
  FormatAtoms: PGdkAtom;
  Cnt, i: integer;
  AddTextPlain: boolean;
  SelData: TGtkSelectionData;

  function IsFormatSupported(CurFormat: TGdkAtom): boolean;
  var a: integer;
  begin
    if CurFormat<>0 then begin
      for a:=0 to Cnt-1 do begin
        {$IfDef DEBUG_CLIPBOARD}
        DebugLn('  IsFormatSupported ',dbgs(CurFormat),'  ',dbgs(FormatAtoms[a]));
        {$EndIf}
        if FormatAtoms[a]=CurFormat then begin
          Result:=true;
          exit;
        end;
      end;
    end;
    Result:=false;
  end;

  function IsFormatSupported(Formats: TGtkClipboardFormats): boolean;
  var Format: TGtkClipboardFormat;
  begin
    for Format:=Low(TGtkClipboardFormat) to High(TGtkClipboardFormat) do
      if (Format in Formats)
      and (IsFormatSupported(
               gdk_atom_intern(PGChar(GtkClipboardFormatName[Format]),GdkTrue)))
      then begin
        Result:=true;
        exit;
      end;
    Result:=false;
  end;


begin
  {$IfDef DEBUG_CLIPBOARD}
  DebugLn('[TGtk2WidgetSet.ClipboardGetFormats] A ClipboardWidget=',Dbgs(ClipboardWidget),' Now=',dbgs(Now));
  {$EndIf}
  Result:=false;
  Count:=0;
  List:=nil;
  if not (ClipboardType in [ctPrimarySelection,ctSecondarySelection,ctClipboard])
  then exit;
  // request the list of supported formats from the selection owner
  AllID:=gdk_atom_intern('TARGETS',GdkFalse);

  SelData:=RequestSelectionData(ClipboardWidget,ClipboardType,AllID);

  try
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetFormats] Checking TARGETS answer ',
      ' selection: '+dbgs(SelData.Selection)+'='+dbgs(ClipboardTypeAtoms[ClipboardType])+
                ' "'+GdkAtomToStr(SelData.Selection)+'"',
      ' target: '+dbgs(SelData.Target),'=',dbgs(AllID),
                ' "'+GdkAtomToStr(SelData.Target),'"',
      ' theType: '+dbgs(SelData._type)+'='+dbgs(gdk_atom_intern('ATOM',GdkFalse))+
                ' "'+GdkAtomToStr(SelData._type)+'"',
      ' Length='+dbgs(SelData.Length),
      ' Format='+dbgs(SelData.Format),
      ' Data='+Dbgs(SelData.Data),
      ' Now='+dbgs(Now)
      );
    {$EndIf}
    if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
    or (SelData.Target<>AllID)
    or (SelData.Format<=0)
    or ((SelData._Type<>gdk_atom_intern('ATOM',GdkFalse))
         and (SelData._Type<>AllID))
    then
      exit;
    Cnt:=SelData.Length div (SelData.Format shr 3);
    if (SelData.Data<>nil) and (Cnt>0) then begin
      Count:=Cnt;
      FormatAtoms:=PGdkAtom(SelData.Data);
      // add transformable lcl formats
      // for example: the lcl expects text as 'text/plain', but gtk applications
      // also know 'TEXT' and 'STRING'. These formats can automagically
      // transformed into the lcl format, so the lcl format is also supported
      // and will be added to the list

      AddTextPlain:=false;
      if (not IsFormatSupported(gdk_atom_intern('text/plain',GdkTrue)))
      and (IsFormatSupported([gfCOMPOUND_TEXT,gfTEXT,gfSTRING,gfFILE_NAME,
        gfHOST_NAME,gfUSER]))
      then begin
        AddTextPlain:=true;
        inc(Count);
      end;

      // copy normal supported formats
      GetMem(List,SizeOf(TClipboardFormat)*Count);
      i:=0;
      while (i<Cnt) do begin
        {$IfDef DEBUG_CLIPBOARD}
        DebugLn('[TGtk2WidgetSet.ClipboardGetFormats] Supported formats: ',
                dbgs(i)+'/'+dbgs(Cnt),':  ',dbgs(FormatAtoms[i]));
        DebugLn('  MimeType="',ClipboardFormatToMimeType(FormatAtoms[i]),'"');
        {$EndIf}
        List[i]:=FormatAtoms[i];
        inc(i);
      end;

      // add all lcl formats that the gtk-interface can transform from the
      // supported formats
      if AddTextPlain then begin
        List[i]:=gdk_atom_intern('text/plain',GdkFalse);
        inc(i);
      end;
    end;
  finally
    if SelData.Data<>nil then FreeMem(SelData.Data);
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  Function: ClipboardGetOwnerShip
  Params:  ClipboardType
           OnRequestProc - TClipboardRequestEvent is defined in LCLIntf.pp
                           If OnRequestProc is nil the onwership will end.
           FormatCount - number of formats
           Formats - array of TClipboardFormat. The supported formats the owner
                      provides.

  Returns: true on success

  Sets the supported formats and requests ownership for the clipboard.
  Each time the clipboard is read the OnRequestProc will be executed.
  If someone else requests the ownership, the OnRequestProc will be executed
  with the invalid FormatID 0 to notify the old owner of the lost of ownership.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent;  FormatCount: integer;
  Formats: PClipboardFormat): boolean;
var TargetEntries: PGtkTargetEntry;

  function IsFormatSupported(FormatID: TGdkAtom): boolean;
  var i: integer;
  begin
    if FormatID=0 then begin
      Result:=false;
      exit;
    end;
    i:=FormatCount-1;
    while (i>=0) and (Formats[i]<>FormatID) do dec(i);
    Result:=(i>=0);
  end;

  procedure AddTargetEntry(var Index: integer; const FormatName: string);
  begin
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('  AddTargetEntry ',FormatName);
    {$EndIf}
    TargetEntries[Index].Target := StrAlloc(Length(FormatName) + 1);
    StrPCopy(TargetEntries[Index].Target, FormatName);
    TargetEntries[Index].flags:=0;
    TargetEntries[Index].Info:=Index;
    inc(Index);
  end;

{function TGtk2WidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
  OnRequestProc: TClipboardRequestEvent;  FormatCount: integer;
  Formats: PClipboardFormat): boolean;}
var
  TargetEntriesSize, i: integer;
  gtkFormat: TGtkClipboardFormat;
  ExpFormatCnt: integer;
  OldClipboardWidget: PGtkWidget;
begin
  if ClipboardType in [ctPrimarySelection, ctSecondarySelection, ctClipboard] then
  begin
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetOwnerShip] A');
    {$EndIf}
    ClipboardHandler[ClipboardType]:=nil;
    Result:=false;
    if (ClipboardWidget=nil) or (FormatCount=0) or (Formats=nil) then
    begin
      // end ownership
      if (ClipBoardWidget <> nil)
      and (GetControlWindow(ClipboardWidget)<>nil)
      and (gdk_selection_owner_get(ClipboardTypeAtoms[ClipboardType]) =
           GetControlWindow(ClipboardWidget))
      then begin
        gtk_selection_owner_set(nil,ClipboardTypeAtoms[ClipboardType],0);
      end;
      Result:=true;
      exit;
    end;

    // registering targets
    FreeClipboardTargetEntries(ClipboardType);

    // the gtk-interface adds automatically some gtk formats unknown to the lcl
    ExpFormatCnt:=FormatCount;
    for gtkFormat:=Low(TGtkClipboardFormat) to High(TGtkClipboardFormat) do
      ClipboardExtraGtkFormats[ClipboardType][gtkFormat]:=false;
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetOwnerShip] B');
    {$EndIf}
    if IsFormatSupported(gdk_atom_intern('text/plain',GdkTrue)) then
    begin
      // lcl provides 'text/plain' and the gtk-interface will automatically
      // provide some more text formats
      ClipboardExtraGtkFormats[ClipboardType][gfUTF8_STRING]:=not IsFormatSupported(
                gdk_atom_intern(PGChar(GtkClipboardFormatName[gfUTF8_STRING]),GdkFalse));
      ClipboardExtraGtkFormats[ClipboardType][gfCOMPOUND_TEXT]:=
          not IsFormatSupported(
                gdk_atom_intern(PGChar(GtkClipboardFormatName[gfCOMPOUND_TEXT]),GdkFalse));
      ClipboardExtraGtkFormats[ClipboardType][gfSTRING]:=not IsFormatSupported(
                gdk_atom_intern(PGChar(GtkClipboardFormatName[gfSTRING]),GdkFalse));
      ClipboardExtraGtkFormats[ClipboardType][gfTEXT]:=not IsFormatSupported(
                gdk_atom_intern(PGChar(GtkClipboardFormatName[gfTEXT]),GdkFalse));
    end;

    for gtkFormat:=Low(TGtkClipboardFormat) to High(TGtkClipboardFormat) do
      if ClipboardExtraGtkFormats[ClipboardType][gtkFormat] then
        inc(ExpFormatCnt);

    // build TargetEntries
    TargetEntriesSize:=SizeOf(TGtkTargetEntry) * ExpFormatCnt;
    GetMem(TargetEntries,TargetEntriesSize);
    FillChar(TargetEntries^,TargetEntriesSize,0);
    i:=0;
    while i<FormatCount do
      AddTargetEntry(i,ClipboardFormatToMimeType(Formats[i]));
    for gtkFormat:=Low(TGtkClipboardFormat) to High(TGtkClipboardFormat) do
      if ClipboardExtraGtkFormats[ClipboardType][gtkFormat] then
        AddTargetEntry(i,GtkClipboardFormatName[gtkFormat]);

    // set the supported formats
    ClipboardTargetEntries[ClipboardType]:=TargetEntries;
    ClipboardTargetEntryCnt[ClipboardType]:=ExpFormatCnt;

    // reset the clipboard widget (this will set the new target list)
    OldClipboardWidget:=ClipboardWidget;
    SetClipboardWidget(nil);
    SetClipboardWidget(OldClipboardWidget);

    // taking the ownership
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetOwnerShip] C');
    {$EndIf}
    if gtk_selection_owner_set(ClipboardWidget,
      ClipboardTypeAtoms[ClipboardType],0)=GdkFalse
    then begin
      {$IfDef DEBUG_CLIPBOARD}
      DebugLn('[TGtk2WidgetSet.ClipboardGetOwnerShip] D FAILED');
      {$EndIf}
      exit;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtk2WidgetSet.ClipboardGetOwnerShip] YEAH, got it!');
    {$EndIf}
    ClipboardHandler[ClipboardType]:=OnRequestProc;

    Result:=true;
  end else
    { the gtk does not support this kind of clipboard, so the application can
     have the ownership at any time. The TClipboard in clipbrd.pp has an
     internal cache system, so that an application can use all types of
     clipboards even if the underlying platform does not support it.
     Of course this will only be a local clipboard, invisible to other
     applications. }
    Result:=true;
end;

function TGtk2WidgetSet.ClipboardFormatNeedsNullByte(
  const AFormat: TPredefinedClipboardFormat): Boolean;
begin
  Result := False;
end;

{------------------------------------------------------------------------------
  Function: ClipboardRegisterFormat
  Params:  AMimeType
  Returns: the registered Format identifier (TClipboardFormat)
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ClipboardRegisterFormat(const AMimeType: string
  ): TClipboardFormat;
var AtomName: PChar;
begin
  if Assigned(Application) then begin
    AtomName:=PChar(AMimeType);
    Result:=gdk_atom_intern(AtomName,GdkFalse);
  end else
    RaiseGDBException(
      'ERROR: TGtk2WidgetSet.ClipboardRegisterFormat gdk not initialized');
end;


{------------------------------------------------------------------------------
  Function: CreateBitmap
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateBitmap(Width, Height: Integer; Planes, BitCount: Longint; BitmapBits: Pointer): HBITMAP;


const
  MIN_LOADER_HEADER_SIZE = 128;
  
type
  // the loader internally used starts decoding the header after 128 bytes.
  // by adding dummy bytes and adjusting the data offset, we make sure that we
  // we write atleast 128 bytes
  
  TBitmapHeader = packed record
    FileHeader: tagBitmapFileHeader;
    InfoHeader: tagBitmapInfoHeader;
    Dummy: array[1..MIN_LOADER_HEADER_SIZE] of Byte;
  end;

var
  GdiObject: PGdiObject;

  procedure FillBitmapInfo(out Header: TBitmapHeader);
  begin
    FillChar(Header{%H-}, SizeOf(Header), 0);
    
    Header.InfoHeader.biSize := SizeOf(Header.InfoHeader);
    Header.InfoHeader.biWidth := Width;
    Header.InfoHeader.biHeight := Height;
    Header.InfoHeader.biPlanes := Planes;
    Header.InfoHeader.biBitCount := Bitcount;
    Header.InfoHeader.biCompression := BI_RGB;
    Header.InfoHeader.biSizeImage := (((BitCount * Width + 31) shr 5) shl 2) * Height;
    Header.InfoHeader.biXPelsPerMeter := GetDeviceCaps(0, LOGPIXELSX);
    Header.InfoHeader.biYPelsPerMeter := GetDeviceCaps(0, LOGPIXELSY);

    Header.FileHeader.bfType      := LeToN($4D42);
    Header.FileHeader.bfSize      := MIN_LOADER_HEADER_SIZE + Header.InfoHeader.biSizeImage;
    Header.FileHeader.bfOffBits   := MIN_LOADER_HEADER_SIZE;
  end;

  procedure LoadDataByPixbufLoader;
  const
    ALIGNDATA: Word = 0;
  var
    Header: TBitmapHeader;
    Loader: PGdkPixbufLoader;
    Src: PGDKPixbuf;
    res: Boolean;
    LineSize, Count: Integer;
    BitsPtr: PByte;
  begin
    Loader := gdk_pixbuf_loader_new;
    if Loader = nil then Exit;


    FillBitmapInfo(Header);
    Src := nil;
    try
      if not gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(@Header), MIN_LOADER_HEADER_SIZE,nil)
      then begin
        DebugLn('WARNING: [TGtk2WidgetSet.CreateBitmap] Error loading Bitmap Header!');
        Exit;
      end;
      
      LineSize := (((BitCount * Width + 15) shr 4) shl 1);
      if (LineSize and 2) <> 0
      then begin
        // bitmapdata needs to be DWord aligned, while CreateBitmap is Word aligned
        // so "feed" the loader line by line :(
        Count := Height;
        res := True;
        BitsPtr := BitmapBits;
        while res and (Count > 0) do
        begin
          res := gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(BitsPtr), LineSize,nil)
             and gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(@ALIGNDATA), 2,nil);
          Inc(BitsPtr, LineSize);
          Dec(Count);
        end;
      end
      else begin
        // data is DWord aligned :)
        res := gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(BitmapBits), Header.InfoHeader.biSizeImage,nil);
      end;
    
      if not res
      then begin
        DebugLn('WARNING: [TGtk2WidgetSet.CreateBitmap] Error loading Image!');
        Exit;
      end;

      Src := gdk_pixbuf_loader_get_pixbuf(loader);
      if Src = nil
      then begin
        DebugLn('WARNING: [TGtk2WidgetSet.CreateBitmap] Error loading Pixbuf!');
        Exit;
      end;

    finally
      gdk_pixbuf_loader_close(Loader,nil);
    end;

    if GdiObject^.GDIPixmapObject.Image<>nil then
    begin
      gdk_pixmap_unref(GdiObject^.GDIPixmapObject.Image);
      GdiObject^.GDIPixmapObject.Image:=nil;
    end;
    if GdiObject^.GDIPixmapObject.Mask<>nil then
    begin
      gdk_bitmap_unref(GdiObject^.GDIPixmapObject.Mask);
      GdiObject^.GDIPixmapObject.Mask:=nil;
    end;
    gdk_pixbuf_render_pixmap_and_mask(Src,
      GdiObject^.GDIPixmapObject.Image, GdiObject^.GDIPixmapObject.Mask, $80);
    gdk_pixbuf_unref(Src);

    GdiObject^.Depth := gdk_drawable_get_depth(GdiObject^.GDIPixmapObject.Image);
    if GdiObject^.Depth = 1
    then begin
      if GdiObject^.GDIPixmapObject.Mask <> nil
      then gdk_pixmap_unref(GdiObject^.GDIPixmapObject.Mask);
      GdiObject^.GDIPixmapObject.Mask := nil;
      GdiObject^.GDIBitmapType := gbBitmap;
    end
    else begin
      GdiObject^.GDIBitmapType := gbPixmap;
    end;
    

    GdiObject^.Visual := gdk_window_get_visual(GDIObject^.GDIPixmapObject.Image);
    if GdiObject^.Visual = nil
    then GdiObject^.Visual := gdk_visual_get_best_with_depth(GdiObject^.Depth)
    else gdk_visual_ref(GdiObject^.Visual);

    GdiObject^.Colormap := gdk_colormap_new(GdiObject^.Visual, GdkTrue);
  end;
  
  procedure LoadBitmapData;
  var
    LineSize, n: Integer;
    BitsPtr: Pointer;
    Src, Dst: PByte;
  begin
    LineSize := (Width + 7) shr 3;
    if (LineSize and 1) <> 0
    then begin
      // the gdk_bitmap_create_from_data expects data byte aligned while
      // Createbitmap is word aligned. adjust data
      BitsPtr := GetMem(LineSize * Height);
      Dst := BitsPtr;
      Src := BitmapBits;
      for n := 1 to height do
      begin
        Move(Src^, Dst^, LineSize);
        Inc(Src, LineSize + 1);
        Inc(Dst, LineSize);
      end;
    end
    else begin
      BitsPtr := BitmapBits;
    end;

    GdiObject^.GDIBitmapType := gbBitmap;
    GdiObject^.GDIBitmapObject := gdk_bitmap_create_from_data(nil, BitsPtr, Width, Height);
    GdiObject^.Visual := nil; // bitmaps don't have a visual
    GdiObject^.SystemVisual := False;
    
    if BitsPtr <> BitmapBits
    then FreeMem(BitsPtr);
  end;

begin
  //DebugLn(Format('Trace:> [TGtk2WidgetSet.CreateBitmap] Width: %d, Height: %d, Planes: %d, BitCount: %d, BitmapBits: 0x%x', [Width, Height, Planes, BitCount, PtrUInt(BitmapBits)]));

  if (BitCount < 1) or (Bitcount > 32)
  then begin
    Result := 0;
    DebugLn(Format('ERROR: [TGtk2WidgetSet.CreateBitmap] Illegal depth %d', [BitCount]));
    Exit;
  end;

  GdiObject := NewGDIObject(gdiBitmap);

  if BitmapBits = nil
  then begin
    if BitCount = 1
    then begin
      GdiObject^.GDIBitmapType := gbBitmap;
      GdiObject^.GDIBitmapObject := gdk_pixmap_new(nil, Width, Height, 1);
      GdiObject^.Visual := nil; // bitmaps don't have a visual
    end
    else begin
      GdiObject^.GDIBitmapType := gbPixmap;
      GdiObject^.GDIPixmapObject.Image := gdk_pixmap_new(nil, Width, Height, BitCount);
      GdiObject^.Visual := gdk_window_get_visual(GdiObject^.GDIPixmapObject.Image);
      gdk_visual_ref(GdiObject^.Visual);
    end;
    GdiObject^.SystemVisual := False;
  end
  else begin
    if BitCount = 1
    then begin
      LoadBitmapData;
    end
    else begin
      // Load the data by faking it as a windows bitmap stream (this handles all conversion)
      // Problem with his method is that it doesn't result in the bitmap requested.
      // it is always a device compatible bitmap
      // maybe we should add a gdPixBuf type the the GDIObject for formats not compatible
      // with a native pixmap format
      LoadDataByPixbufLoader;
    end;
  end;

  Result := HBITMAP({%H-}PtrUInt(GdiObject));

  //DebugLn(Format('Trace:< [TGtk2WidgetSet.CreateBitmap] --> 0x%x', [Integer(Result)]));
end;


{------------------------------------------------------------------------------
  Function:  CreateBrushIndirect
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
const
  HATCH_BDIAGONAL : array[0..7] of Byte = ($80, $40, $20, $10, $08, $04, $02, $01);
  HATCH_CROSS     : array[0..7] of Byte = ($08, $08, $08, $FF, $08, $08, $08, $08);
  HATCH_DIAGCROSS : array[0..7] of Byte = ($81, $42, $24, $18, $18, $24, $42, $81);
  HATCH_FDIAGONAL : array[0..7] of Byte = ($01, $02, $04, $08, $10, $20, $40, $80);
  HATCH_HORIZONTAL: array[0..7] of Byte = ($00, $00, $00, $FF, $00, $00, $00, $00);
  HATCH_VERTICAL  : array[0..7] of Byte = ($08, $08, $08, $08, $08, $08, $08, $08);
var
  GObject: PGdiObject;
  TmpMask: PGdkBitmap;
begin
  //DebugLn(Format('Trace:> [TGtk2WidgetSet.CreateBrushIndirect]  Style: %d, Color: %8x', [LogBrush.lbStyle, LogBrush.lbColor]));

  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}

  GObject := NewGDIObject(gdiBrush);
  try
    {$IFDEF DebugGDIBrush}
    DebugLn('[TGtk2WidgetSet.CreateBrushIndirect] ',DbgS(GObject));
    {$ENDIF}
    GObject^.IsNullBrush := False;
    with LogBrush do
    begin
      case lbStyle of
        BS_NULL {BS_HOLLOW}: // Same as BS_HOLLOW.
          GObject^.IsNullBrush := True;
        BS_SOLID:          // Solid brush.
          GObject^.GDIBrushFill := GDK_SOLID;
        BS_HATCHED:        // Hatched brush.
          begin
            GObject^.GDIBrushFill := GDK_STIPPLED;
            case lbHatch of
              HS_BDIAGONAL:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_BDIAGONAL[0]), 8, 8);
              HS_CROSS:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_CROSS[0]), 8, 8);
              HS_DIAGCROSS:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_DIAGCROSS[0]), 8, 8);
              HS_FDIAGONAL:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_FDIAGONAL[0]), 8, 8);
              HS_HORIZONTAL:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_HORIZONTAL[0]), 8, 8);
              HS_VERTICAL:
                GObject^.GDIBrushPixmap := gdk_bitmap_create_from_data(
                   nil, pgchar(@HATCH_VERTICAL[0]), 8, 8);
              else
                GObject^.GDIBrushFill := GDK_SOLID;
            end;
          end;

        BS_DIBPATTERN,     // A pattern brush defined by a device-independent
             // bitmap (DIB) specification. If lbStyle is BS_DIBPATTERN, the
             // lbHatch member contains a handle to a packed DIB.Windows 95:
             // Creating brushes from bitmaps or DIBs larger than 8x8 pixels
             // is not supported. If a larger bitmap is given, only a portion
             // of the bitmap is used.
        BS_DIBPATTERN8X8,  // Same as BS_DIBPATTERN.
        BS_DIBPATTERNPT,   // A pattern brush defined by a device-independent
             // bitmap (DIB) specification. If lbStyle is BS_DIBPATTERNPT, the
             // lbHatch member contains a pointer to a packed DIB.
        BS_PATTERN,        // Pattern brush defined by a memory bitmap.
        BS_PATTERN8X8:     // Same as BS_PATTERN.
          begin
            GObject^.GDIBrushPixmap := nil;
            if IsValidGDIObject(lbHatch) and ({%H-}PGdiObject(lbHatch)^.GDIType = gdiBitmap) then
            begin
              case {%H-}PGdiObject(lbHatch)^.GDIBitmapType of
                gbBitmap:
                begin
                  GObject^.GDIBrushPixmap := {%H-}PGdiObject(lbHatch)^.GDIBitmapObject;
                  GObject^.GDIBrushFill := GDK_STIPPLED;
                end;
                gbPixmap:
                begin
                  GObject^.GDIBrushPixmap := {%H-}PGdiObject(lbHatch)^.GDIPixmapObject.Image;
                  GObject^.GDIBrushFill := GDK_TILED;
                end;
                gbPixbuf:
                begin
                  GObject^.GDIBrushPixmap := nil;
                  TmpMask := nil;
                  gdk_pixbuf_render_pixmap_and_mask({%H-}PGdiObject(lbHatch)^.GDIPixbufObject,
                    GObject^.GDIBrushPixmap, TmpMask, $80);
                  gdk_pixmap_unref(TmpMask);
                end;
                else
                begin
                  DebugLn('TGtk2WidgetSet.CreateBrushIndirect: Unsupported GDIBitmapType')
                end;
              end
            end
            else
              RaiseGDBException('unsupported bitmap');
            if GObject^.GDIBrushPixmap <> nil then
              gdk_pixmap_ref(GObject^.GDIBrushPixmap);
          end;
        else
          RaiseGDBException(Format('unsupported Style %d',[lbStyle]));
      end;

      {$IFDEF DebugGDKTraps}
      EndGDKErrorTrap;
      {$ENDIF}

      if not GObject^.IsNullBrush then
        SetGDIColorRef(GObject^.GDIBrushColor, lbColor);
    end;
    Result := HBRUSH({%H-}PtrUInt(GObject));
  except
    Result:=0;
    DisposeGDIObject(GObject);
    DebugLn('TGtk2WidgetSet.CreateBrushIndirect failed');
  end;
  //DebugLn(Format('Trace:< [TGtk2WidgetSet.CreateBrushIndirect] Got --> %x', [Result]));
end;

{------------------------------------------------------------------------------
  Function: CreateCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap; width,
  Height: Integer): Boolean;
var
  GTKObject: PGTKObject;
  BMP: PGDKPixmap;
begin
  //DebugLn('Trace:TODO: [TGtk2WidgetSet.CreateCaret] Finish');

  GTKObject := {%H-}PGTKObject(Handle);
  Result := GTKObject <> nil;

  if Result then begin
    if gtk_type_is_a(g_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      if IsValidGDIObjectType(Bitmap, gdiBitmap) then
        BMP := {%H-}PGdiObject(Bitmap)^.GDIBitmapObject
      else
        BMP := nil;
      GTKAPIWidget_CreateCaret(PGTKAPIWidget(GTKObject), Width, Height, BMP);
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: CreateCompatibleBitmap
  Params: DC:
          Width:
          Height:
  Returns:

  Creates a bitmap compatible with the specified device context.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
var
  DevCtx: TGtkDeviceContext absolute DC;
  
  GDIObject: PGdiObject;
  Depth : Longint;
  Drawable, DefDrawable: PGDkDrawable;
begin
  //DebugLn(Format('Trace:> [TGtk2WidgetSet.CreateCompatibleBitmap] DC: 0x%x, W: %d, H: %d', [DC, Width, Height]));

  if IsValidDC(DC) and (DevCtx.Drawable <> nil)
  then begin
    DefDrawable := DevCtx.Drawable;
    Depth := gdk_drawable_get_depth(DevCtx.Drawable);
  end
  else begin
    DefDrawable := nil;
    Depth := gdk_visual_get_system^.Depth;
  end;
  

  if (Depth < 1) or (Depth > 32)
  then begin
    Result := 0;
    DebugLn(Format('ERROR: [TGtk2WidgetSet.CreateCompatibleBitmap] Illegal depth %d', [Depth]));
    Exit;
  end;

  GdiObject := NewGDIObject(gdiBitmap);

  Drawable := gdk_pixmap_new(DefDrawable, Width, Height, Depth);
  GdiObject^.Visual := gdk_window_get_visual(Drawable);
  if Depth = 1
  then begin
    GdiObject^.GDIBitmapType := gbBitmap;
    GdiObject^.GDIBitmapObject := Drawable;
  end
  else begin
    GdiObject^.GDIBitmapType := gbPixmap;
    GdiObject^.GDIPixmapObject.Image := Drawable;
  end;

  if GdiObject^.Visual = nil
  then begin
    GdiObject^.Visual := gdk_visual_get_best_with_depth(Depth);
    if GdiObject^.Visual = nil
    then GdiObject^.Visual := gdk_visual_get_system;
    GdiObject^.SystemVisual := True;
  end
  else begin
    gdk_visual_ref(GdiObject^.Visual);
    GdiObject^.SystemVisual := False;
  end;

  GdiObject^.Colormap := gdk_colormap_new(GdiObject^.Visual, GdkTrue);

  Result := HBITMAP({%H-}PtrUInt(GdiObject));

  //DebugLn(Format('Trace:< [TGtk2WidgetSet.CreateCompatibleBitmap] DC: 0x%x --> 0x%x', [DC, Result]));
end;

{------------------------------------------------------------------------------
  Function: CreateCompatibleDC
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateCompatibleDC(DC: HDC): HDC;
var
  pNewDC: TGtkDeviceContext;
begin
  Result := 0;
  pNewDC := NewDC;

  // ToDo: TGtk2WidgetSet.CreateCompatibleDC: when is a DC compatible?

  // do not copy
  // In a compatible DC you have to select a bitmap into it
(*
  if IsValidDC(DC) then
    with TGtkDeviceContext(DC)^ do
    begin
      pNewDC^.hWnd := hWnd;
      pNewDC^.Drawable := Drawable;
      pNewDC^.GC := gdk_gc_new(Drawable);
    end
  else begin
    // We can't do anything yet
    // Wait till a bitmap get selected
  end;
*)
  with pNewDC do
  begin
    gdk_color_black(gdk_colormap_get_system, @CurrentTextColor.Color);
    BuildColorRefFromGDKColor(CurrentTextColor);
    gdk_color_white(gdk_colormap_get_system, @CurrentBackColor.Color);
    BuildColorRefFromGDKColor(CurrentBackColor);
  end;
  Result := HDC(pNewDC);

  //DebugLn(Format('trace:  [TGtk2WidgetSet.CreateCompatibleDC] DC: 0x%x --> 0x%x', [Integer(DC), Integer(Result)]));
end;

function TGtk2WidgetSet.DestroyCursor(Handle: HCURSOR): Boolean;
begin
  Result := Handle <> 0;
  if Result then
    gdk_cursor_destroy({%H-}PGdkCursor(Handle));
end;

function TGtk2WidgetSet.DestroyIcon(Handle: HICON): Boolean;
begin
  Result := (Handle <> 0) and
            (
              GDK_IS_PIXBUF({%H-}Pointer(Handle)) or
              // todo: replace with GDK_IS_CURSOR when fpc will have it
              G_TYPE_CHECK_INSTANCE_TYPE({%H-}Pointer(Handle),GDK_TYPE_CURSOR)
            );
  if Result then
    if GDK_IS_PIXBUF({%H-}Pointer(Handle)) then
      gdk_pixbuf_unref({%H-}PGdkPixbuf(Handle))
    else
      gdk_cursor_unref({%H-}PGdkCursor(Handle));
end;

function TGtk2WidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
var
  DevCtx: TGtkDeviceContext absolute DC;
  P: PPoint;
begin
  Result := False;

  if not IsValidDC(DC) then Exit(False);

  if not DevCtx.HasTransf then Exit(True);

  P := @Points;
  while Count > 0 do
  begin
    Dec(Count);
    DevCtx.InvTransfPoint(P^.X, P^.Y);
    Inc(P);
  end;

  Result := True;
end;

{
  Gtk2 has no function to build an elliptical region so we approximate it to a
  polygon. Our Ellipse is axis-aligned, so it's parametrization is:

  X(t) = Xc + a * cos(t)
  Y(t) = Yc + b * sin(t)

  (Xc,Yc) is the center of the ellipse
}
function TGtk2WidgetSet.CreateEllipticRgn(X1, Y1, X2, Y2: Integer): HRGN;
var
  points: array of TGdkPoint;
  n_points: Integer;
  i, Xc, Yc, a, b: Integer;
  t: Double;
  GObject: PGdiObject;
  RegionObj: PGdkRegion;
begin
  a := (X2 - X1) div 2;
  b := (Y2 - Y1) div 2;
  Xc := X1 + a;
  Yc := Y1 + b;

  // Choose a large enough amount of points
  n_points := Max(X2-X1,Y2-Y1) * 4;
  SetLength(points{%H-}, n_points);
  // And fill them iterating through the ellipse
  for i := 0 to n_points - 1 do
  begin
    t := (i / n_points) * 2 * Pi;
    points[i].X := Round(Xc + a * cos(t));
    points[i].Y := Round(Yc + b * sin(t));
  end;

  GObject := NewGDIObject(gdiRegion);
  RegionObj := gdk2.gdk_region_polygon(@points[0], n_points, GDK_WINDING_RULE);
  GObject^.GDIRegionObject := RegionObj;

  Result := HRGN({%H-}PtrUInt(GObject));

  // Free the allocated array
  SetLength(points, 0);
  //DebugLn('TGtk2WidgetSet.CreateRectRgn A ',GDKRegionAsString(RegionObj));
end;

{------------------------------------------------------------------------------
  Function: CreateFontIndirect
  Params:  const LogFont: TLogFont
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  Result := CreateFontIndirectEx(LogFont,'');
end;

{------------------------------------------------------------------------------
  Function: CreateFontIndirectEx
  Params:  const LogFont: TLogFont; const LongFontName: string
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateFontIndirectEx(const LogFont: TLogFont;
  const LongFontName: string): HFONT;
{off $DEFINE VerboseFonts}
var
  GdiObject: PGdiObject;
  FullString, aFamily, aStyle, ALongFontName: String;
  aSize: Integer;
  aSizeInPixels: Boolean;
  PangoDesc: PPangoFontDescription;
  CachedFont: TGtkFontCacheDescriptor;
  AttrList: PPangoAttrList;
  AttrListTemporary: Boolean;
  Attr: PPangoAttribute;
  CurFont: PPangoLayout;
  TmpStr: PChar;
begin
  {$IFDEF VerboseFonts}
  DebugLn('TGtk2WidgetSet.CreateFontIndirectEx A Name=',LogFont.lfFaceName,' Height=',dbgs(LogFont.lfHeight),' LongName=',LongFontName);
  {$ENDIF}
  Result := 0;
  PangoDesc := nil;
  GdiObject := nil;
  if LongFontName = '' then
    ALongFontName := LogFont.lfFaceName
  else
    ALongFontName := LongFontName;
  try
    // first search in cache
    CachedFont:=FontCache.FindGTkFontDesc(LogFont, ALongFontName);
    if CachedFont<>nil then begin
      CachedFont.Item.IncreaseRefCount;
      GdiObject := NewGdiObject(gdiFont);
      GdiObject^.UntransfFontHeight := 0;
      GdiObject^.GDIFontObject := TGtkFontCacheItem(CachedFont.Item).GtkFont;
      {$IFDEF VerboseFonts}
      WriteLn('Was already in cache');
      {$ENDIF}
      exit;
    end;

    with LogFont do
    begin
      if lfFaceName[0] = #0
      then begin
        //DebugLn('ERROR: [Tgt2kObject.CreateFontIndirectEx] No fontname');
        Exit;
      end;

      // if we have really default font
      if (lfHeight = 0) and
         (lfWeight = FW_NORMAL) and
         (lfItalic = 0) and
         (lfUnderline = 0) and
         (lfStrikeOut = 0) and
         (lfOrientation = 0) and
         IsFontNameDefault(lfFacename) then
      begin
        // use default font
        {$IFDEF VerboseFonts}
        DebugLn(['TGtk2WidgetSet.CreateFontIndirectEx Creating default font']);
        {$ENDIF}
        GdiObject := CreateDefaultFont;
        exit;
      end;

      FontNameToPangoFontDescStr(ALongFontname, aFamily, aStyle, aSize, aSizeInPixels);

      // if font specified size, prefer this instead of 'possibly' inaccurate
      // lfHeight note that lfHeight may actually have a most accurate value
      // but there is no way to know this at this point.
      
      // setting the size, this could be done in two ways
      // method 1: fontdesc using fontname like "helvetica 12"
      // method 2: fontdesc using fontname like "helvetica" and later modify size
      
      // to obtain consistent font sizes method 2 should be used
      // for method 1 converting lfheight to fontsize can lead to rounding errors
      //   for example, font size=12, lfheight=-12 (75dpi), at 75 dpi aSize=11
      //   so we would get a font "helvetica 11" instead of "helvetica 12"
      // size information, and later modify font size
      
      // using method 2

      if IsFontNameDefault(aFamily) then
      begin
        CurFont := GetDefaultGtkFont(False);
        if PANGO_IS_LAYOUT(CurFont) then
        begin
          PangoDesc := pango_layout_get_font_description(CurFont);
          if PangoDesc = nil then
            PangoDesc := pango_context_get_font_description(pango_layout_get_context(CurFont));
          aFamily := StrPas(pango_font_description_get_family(PangoDesc));
          if (aSize = 0) and (lfHeight = 0) then
          begin
            aSize := pango_font_description_get_size(PangoDesc);
            if not pango_font_description_get_size_is_absolute(PangoDesc) then
              aSize := aSize div PANGO_SCALE;
          end;
        end;
      end;

      if (aSize = 0) and (lfHeight = 0) then
        FullString := '10' // use some default: TODO: find out the default size of the widget
      else
      if aSize > 0 then
      begin
        FullString := IntToStr(aSize);
        if aSizeInPixels then
          FullString := FullString + 'px';
      end
      else
        FullString := '';

      if Pos(',', AFamily) > 0 then
        FullString := AFamily + ' ' + aStyle + ' ' + FullString
      else
        FullString := AFamily + ', ' + aStyle + ' ' + FullString;
      PangoDesc := pango_font_description_from_string(PChar(FullString));

      if (pango_font_description_get_weight(PangoDesc) = PANGO_WEIGHT_NORMAL)
        and (lfWeight <> FW_DONTCARE) then
        pango_font_description_set_weight(PangoDesc, lfWeight);

      if (pango_font_description_get_style (PangoDesc) = PANGO_STYLE_NORMAL)
          and (lfItalic <> 0) then
        pango_font_description_set_style(PangoDesc, PANGO_STYLE_ITALIC);
      TmpStr := pango_font_description_to_string(PangoDesc);
      aStyle := TmpStr;
      g_free(TmpStr);
      if (aSize=0) and (lfHeight<>0) then
      begin
        // a size is not specified, try to calculate one based on lfHeight
        // and use this value not in the font name but set this value appart
        // NOTE: in gtk2.8 is possible to use pango_font_description_set_absolute_size
        // which would be great with the given lfheight value, but older gtk2 version
        // doesn't have this function
        if lfHeight < 0 then
          aSize := -lfHeight * PANGO_SCALE
        else
          aSize := lfHeight * PANGO_SCALE;
        pango_font_description_set_absolute_size(PangoDesc, aSize);
      end;
      
      // create font
      // TODO: use context widget (CreateFontIndirectEx needs a parameter for this: Context: HWnd)
      GdiObject := NewGdiObject(gdiFont);
      GdiObject^.UntransfFontHeight := 0;
      GdiObject^.GDIFontObject:=gtk_widget_create_pango_layout(
                                               GetStyleWidget(lgsdefault), nil);
      CurFont:=GdiObject^.GDIFontObject;

      pango_layout_set_font_description(CurFont,PangoDesc);

      if (LogFont.lfUnderline<>0) or (LogFont.lfStrikeOut<>0) then
      begin
        AttrListTemporary := false;
        AttrList := pango_layout_get_attributes(CurFont);
        if (AttrList = nil) then
        begin
          AttrList := pango_attr_list_new();
          AttrListTemporary := True;
        end;

        if LogFont.lfUnderline<>0 then
        begin
          Attr := pango_attr_underline_new(PANGO_UNDERLINE_SINGLE);
          pango_attr_list_change(AttrList, Attr);
        end;

        if LogFont.lfStrikeOut<>0 then
        begin
          Attr := pango_attr_strikethrough_new(True);
          pango_attr_list_change(AttrList, Attr);
        end;

        pango_layout_set_attributes(CurFont, AttrList);
        
        if AttrListTemporary then
          pango_attr_list_unref(AttrList);
      end;

      pango_layout_set_single_paragraph_mode(CurFont, True);
      pango_layout_set_width(CurFont, -1);
      pango_layout_set_alignment(CurFont, PANGO_ALIGN_LEFT);

      if (lfEscapement <> 0) then
      begin
        // the rotation is done via the pango matrix of the context
        // it must be set by the device context
      end;
    end;
  finally
    if (CachedFont = nil) and (GdiObject<>nil) and (GdiObject^.GDIFontObject <> nil) then
    begin
      // add to cache
      CachedFont := FontCache.Add(GdiObject^.GDIFontObject, LogFont, ALongFontName);
      //decrement refcount for GdiObject^.GDIFontObject so that object gets
      //released when removing from FontCache.
      g_object_unref(GdiObject^.GDIFontObject);
      if CachedFont <> nil then
      begin
        CachedFont.PangoFontDescription := PangoDesc;
        PangoDesc := nil;
      end;
    end;
    {$IFDEF VerboseFonts}
    if (GdiObject<>nil) and (GdiObject^.GDIFontObject <> nil) then begin
      DebugLn(['TGtk2WidgetSet.CreateFontIndirectEx New pangolayout=',dbgs(GdiObject^.GDIFontObject),' Cached=',FontCache.FindGTKFont(GdiObject^.GDIFontObject)<>nil]);
    end;
    {$ENDIF}
    // clean up helper objects
    if PangoDesc<>nil then
      pango_font_description_free(PangoDesc);
      
    if (GdiObject<>nil) then begin
      if (GdiObject^.GDIFontObject = nil) then begin
        DebugLn(['TGtk2WidgetSet.CreateFontIndirectEx Unable to create font A']);
        DisposeGDIObject(GdiObject);
        Result := 0;
      end else begin
        // return the new font
        GdiObject^.LogFont:=LogFont;
        Result := HFONT({%H-}PtrUInt(GdiObject));
      end;
    end else begin
      {$IFDEF VerboseFonts}
      DebugLn(['TGtk2WidgetSet.CreateFontIndirectEx Unable to create font B']);
      {$ENDIF}
    end;
    {$IFDEF VerboseFonts}
    DebugLn(['TGtk2WidgetSet.CreateFontIndirectEx END Result=',dbgs(Pointer(PtrInt(Result)))]);
    {$ENDIF}
  end;
end;

function TGtk2WidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
var
  bitmap: PGdkBitmap;
  pixmap: PGdkPixmap;
  pixbuf: PGdkPixbuf;
  Width, Height: integer;
  MaxWidth, MaxHeight: guint;
begin
  Result := 0;
  if not IsValidGDIObject(IconInfo^.hbmColor) then Exit;

  if {%H-}PGDIObject(IconInfo^.hbmColor)^.GDIBitmapType = gbPixbuf then
  begin
    pixbuf := gdk_pixbuf_copy({%H-}PGDIObject(IconInfo^.hbmColor)^.GDIPixbufObject);
  end
  else
  begin
    pixmap := {%H-}PGDIObject(IconInfo^.hbmColor)^.GDIPixmapObject.Image;
    //DbgDumpPixmap(pixmap, '');

    gdk_drawable_get_size(pixmap, @Width, @Height);

    if not IconInfo^.fIcon then
    begin
      gdk_display_get_maximal_cursor_size(gdk_display_get_default,
                                          @MaxWidth, @MaxHeight);

      if (Width > integer(MaxWidth))
      or (Height > integer(MaxHeight)) then Exit;
    end;

    bitmap := CreateGdkMaskBitmap(IconInfo^.hbmColor, IconInfo^.hbmMask);
    pixbuf := CreatePixbufFromImageAndMask(pixmap, 0, 0, Width, Height, nil, bitmap);
    if bitmap <> nil then
      gdk_bitmap_unref(bitmap);
  end;

  if IconInfo^.fIcon then
  begin
    Result := HICON({%H-}PtrUInt(pixbuf));
  end
  else
  begin
    // create cursor from pixbuf
    Result := HCURSOR({%H-}PtrUInt(gdk_cursor_new_from_pixbuf(gdk_display_get_default,
      pixbuf, IconInfo^.xHotSpot, IconInfo^.yHotSpot)));
    if pixbuf <> nil then
      gdk_pixbuf_unref(pixbuf);
  end;
end;

{------------------------------------------------------------------------------
  Function: CreatePalette
  Params:  LogPalette
  Returns: a handle to the Palette created


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreatePalette(const LogPalette: TLogPalette): HPALETTE;
var
  GObject: PGdiObject;
begin
  //DebugLn('trace:[TGtk2WidgetSet.CreatePalette]');

  GObject := NewGDIObject(gdiPalette);
  GObject^.SystemPalette := False;
  GObject^.PaletteRealized := False;
  GObject^.VisualType := GDK_VISUAL_PSEUDO_COLOR;
  GObject^.PaletteVisual := nil;

  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}

  GObject^.PaletteVisual := gdk_visual_get_best_with_type(GObject^.VisualType);
  if GObject^.PaletteVisual = nil
  then begin
    GObject^.PaletteVisual := GDK_Visual_Get_System;
    GDK_Visual_Ref(GObject^.PaletteVisual);
  end;
  GObject^.PaletteColormap := GDK_Colormap_new(GObject^.PaletteVisual, GdkTrue);

  {$IFDEF DebugGDKTraps}
  EndGDKErrorTrap;
  {$ENDIF}

  GObject^.RGBTable := TDynHashArray.Create(-1);
  GObject^.RGBTable.OnGetKeyForHashItem:=@GetRGBAsKey;
  GObject^.IndexTable := TDynHashArray.Create(-1);
  GObject^.IndexTable.OnGetKeyForHashItem:=@GetIndexAsKey;
  InitializePalette(GObject, LogPalette.palPalEntry, LogPalette.palNumEntries);

  Result := HPALETTE({%H-}PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Function: CreatePenIndirect
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
var
  GObject: PGdiObject;
begin
  //DebugLn('trace:[TGtk2WidgetSet.CreatePenIndirect]');
//write('CreatePenIndirect->');
  GObject := NewGDIObject(gdiPen);
  GObject^.UnTransfPenWidth := 0;
  GObject^.GDIPenDashes := nil;

  GObject^.IsExtPen := False;
  with LogPen do
  begin
    GObject^.GDIPenStyle := lopnStyle;
    GObject^.GDIPenWidth := lopnWidth.X;
    SetGDIColorRef(GObject^.GDIPenColor,lopnColor);
  end;

  Result := HPEN({%H-}PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Method:  CreatePolygonRgn
  Params:  Points, NumPts, FillMode
  Returns: the handle to the region

  Creates a Polygon, a closed many-sided shaped region. The Points parameter is
  an array of points that give the vertices of the polygon. FillMode=Winding
  determines what points are going to be included in the region. When Winding
  is True, points are selected by using the Winding fill algorithm. When Winding
  is False, points are selected by using using the even-odd (alternative) fill
  algorithm. NumPts indicates the number of points to use.
  The first point is always connected to the last point.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer;
  FillMode: integer): HRGN;
var
  i: integer;
  PointArray: PGDKPoint;
  GObject: PGdiObject;
  fr : TGDKFillRule;
begin
  Result := 0;
  if NumPts<=1 then exit; // gdk_region_polygon will crash on a polygon with 1 point
  GObject := NewGDIObject(gdiRegion);

  GetMem(PointArray,SizeOf(TGdkPoint)*NumPts);
  for i:=0 to NumPts-1 do begin
    PointArray[i].x:=Points[i].x;
    PointArray[i].y:=Points[i].y;
  end;

  If FillMode=Winding then
    fr := GDK_WINDING_RULE
  else
    fr := GDK_EVEN_ODD_RULE;

  GObject^.GDIRegionObject := gdk_region_polygon(PointArray, NumPts, fr);

  FreeMem(PointArray);

  Result := HRGN({%H-}PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Function: CreateRectRgn
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CreateRectRgn(X1,Y1,X2,Y2 : Integer): HRGN;
var
  R: TGDKRectangle;
  RRGN: PGDKRegion;
  GObject: PGdiObject;
  RegionObj: PGdkRegion;
begin
  GObject := NewGDIObject(gdiRegion);
  if X1<=X2 then begin
    R.X := gint16(X1);
    R.Width := X2 - X1;
  end else begin
    R.X := gint16(X2);
    R.Width := X1 - X2;
  end;
  if Y1<=Y2 then begin
    R.Y := gint16(Y1);
    R.Height := Y2 - Y1;
  end else begin
    R.Y := gint16(Y2);
    R.Height := Y1 - Y1;
  end;

  RRGN := gdk_region_new;
  RegionObj:=PGdkRegion(gdk_region_union_with_rect(RRGN,@R));
  GObject^.GDIRegionObject := RegionObj;
  gdk_region_destroy(RRGN);

  Result := HRGN({%H-}PtrUInt(GObject));
  //DebugLn('TGtk2WidgetSet.CreateRectRgn A ',GDKRegionAsString(RegionObj));
end;

{------------------------------------------------------------------------------
  Function: CombineRgn
  Params:  Dest, Src1, Src2, fnCombineMode
  Returns: longint

  Combine the 2 Source Regions into the Destination Region using the specified
  Combine Mode. The Destination must already be initialized. The Return value
  is the Destination's Region type, or ERROR.

  The Combine Mode can be one of the following:
      RGN_AND  : Gets a region of all points which are in both source regions

      RGN_COPY : Gets an exact copy of the first source region

      RGN_DIFF : Gets a region of all points which are in the first source
                 region but not in the second.(Source1 - Source2)

      RGN_OR   : Gets a region of all points which are in either the first
                 source region or in the second.(Source1 + Source2)

      RGN_XOR  : Gets all points which are in either the first Source Region
                 or in the second, but not in both.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.CombineRgn(Dest, Src1, Src2: HRGN;
  fnCombineMode: Longint): Longint;
var
  Continue: Boolean;
  D, S1, S2: PGDKRegion;
  DObj, S1Obj, S2Obj: PGDIObject;
begin
  Result := SIMPLEREGION;
  DObj := {%H-}PGdiObject(Dest);
  S1Obj := {%H-}PGdiObject(Src1);
  S2Obj := {%H-}PGdiObject(Src2);
  Continue := IsValidGDIObject(Dest) and IsValidGDIObject(Src1)
              and IsValidGDIObject(Src2);
  if not Continue then begin
    DebugLn('WARNING: [TGtk2WidgetSet.CombineRgn] Invalid HRGN');
    exit(Error);
  end;
  if DObj^.RefCount>1 then
  begin
    DebugLn('WARNING: [TGtk2WidgetSet.CombineRgn] Invalid Dest');
    exit(RegionType(DObj^.GDIRegionObject));
  end;

  S1 := S1Obj^.GDIRegionObject;
  S2 := S2Obj^.GDIRegionObject;
  //DebugLn('TGtk2WidgetSet.CombineRgn A fnCombineMode=',Dbgs(fnCombineMode));
  case fnCombineMode of
    RGN_AND :
      D := PGDKRegion(gdk_region_intersect(S1, S2));
    RGN_COPY :
      D := gdk_region_copy(S1);
    RGN_DIFF :
      D := PGDKRegion(gdk_region_subtract(S1, S2));
    RGN_OR :
      D := PGDKRegion(gdk_region_union(S1, S2));
    RGN_XOR :
      D := PGDKRegion(gdk_region_xor(S1, S2));
    else begin
      Result:= ERROR;
      D := nil;
    end;
  end;
  if Assigned(DObj^.GDIRegionObject) then
    gdk_region_destroy(DObj^.GDIRegionObject);
  DObj^.GDIRegionObject := D;
  Result := RegionType(D);
  //DebugLn('TGtk2WidgetSet.CombineRgn B Mode=',dbgs(fnCombineMode),
  //  ' S1=',GDKRegionAsString(S1),' S2=',GDKRegionAsString(S2),' D=',GDKRegionAsString(D),'');
end;

{------------------------------------------------------------------------------
  Function: DeleteDC
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.DeleteDC(hDC: HDC): Boolean;
begin
  // TODO:
  // for now it's just the same, however CreateDC/FreeDC
  // and GetDC/ReleaseDC are couples
  // we should use gdk_new_gc for create and gtk_new_gc for Get
  Result:= (ReleaseDC(0, hDC) = 1);
end;

{------------------------------------------------------------------------------
  Function: DeleteObject
  Params:  none
  Returns: Nothing

  DeleteObject is allowed while the object is still selected. The msdn docs
  are misleading. Marc tested with resource profiler under win XP.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;

  procedure RaiseInvalidGDIObject;
  begin
    {$ifdef TraceGdiCalls}
    DebugLn();
    DebugLn('TGtk2WidgetSet.DeleteObject: TraceCall for invalid object: ');
    DumpBackTrace(PgdiObject(GdiObject)^.StackAddrs);
    DebugLn();
    DebugLn('Exception will follow:');
    DebugLn();
    {$endif}
    RaiseGDBException('TGtk2WidgetSet.DeleteObject invalid GdiObject='+dbgs(GdiObject));
  end;

var
  GDIObjectExists: boolean;
begin
  if GDIObject = 0 then
  begin
    Result := True;
    Exit;
  end;
  {$IFDEF DebugLCLComponents}
  if DebugGdiObjects.IsDestroyed(Pointer(GDIObject)) then
  begin
    DebugLn(['TGtk2WidgetSet.DeleteObject object already deleted ',GDIObject]);
    debugln(DebugGdiObjects.GetInfo(PGdiObject(GDIObject),true));
    Halt;
  end;
  {$ENDIF}

  // Find out if we want to release internal GDI object
  GDIObjectExists := FGDIObjects.Contains({%H-}PGdiObject(GDIObject));
  Result := GDIObjectExists;
  if not GDIObjectExists then
  begin
    RaiseInvalidGDIObject;
  end;

  Result := ReleaseGDIObject({%H-}PGdiObject(GDIObject));
end;

function TGtk2WidgetSet.DestroyCaret(Handle: HWND): Boolean;
var
  GTKObject: PGTKObject;
begin
  GTKObject := {%H-}PGTKObject(Handle);
  Result := true;

  if GTKObject<>nil then begin
    if gtk_type_is_a(g_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_DestroyCaret(PGTKAPIWidget(GTKObject));
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end;
end;

function TGtk2WidgetSet.DrawFrameControl(DC: HDC; const Rect : TRect;
  uType, uState : Cardinal) : Boolean;
{const
  ADJUST_FLAG: array[Boolean] of Integer = (0, BF_ADJUST);
  PUSH_EDGE_FLAG: array[Boolean] of Integer = (EDGE_RAISED, EDGE_SUNKEN);
  PUSH_EDGE_FLAG2: array[Boolean] of Integer = (0, BF_FLAT);}
var
  DevCtx: TGtkDeviceContext absolute DC;
  Widget: PGtkWidget;
  R: TRect;
  ClipArea: TGdkRectangle;

  procedure DrawButtonPush;
  var
    State: TGtkStateType;
    Shadow: TGtkShadowType;
    aStyle : PGTKStyle;
    aDC: TGtkDeviceContext;
    DCOrigin: TPoint;
  begin
    //if Widget<>nil then begin

    // use the gtk paint functions to draw a widget style dependent button

    //writeln('DrawButtonPush ',
    //  ' DFCS_BUTTONPUSH=',uState and DFCS_BUTTONPUSH,
    //  ' DFCS_PUSHED=',uState and DFCS_PUSHED,
    //  ' DFCS_INACTIVE=',uState and DFCS_INACTIVE,
    //  ' DFCS_FLAT=',uState and DFCS_FLAT,
    //  '');
    // set State (the interior filling style)
    if (DFCS_PUSHED and uState)<>0 then
      State := GTK_STATE_ACTIVE //button pressed(GTK ignores disabled)
    else if (DFCS_INACTIVE and uState)<>0 then
      State := GTK_STATE_INSENSITIVE //button disabled
    else if (DFCS_HOT and uState)<>0 then
      State := GTK_STATE_PRELIGHT // button enabled, special (e.g. mouse over)
    else
      State := GTK_STATE_NORMAL; // button enabled, normal

    // set Shadow (the border style)
    if (DFCS_PUSHED and uState)<>0 then begin
      // button down
      Shadow:=GTK_SHADOW_IN;
    end else begin
      if (((DFCS_FLAT+DFCS_CHECKED) and uState)=DFCS_FLAT) then begin
        // button up, flat, no special
        Shadow:=GTK_SHADOW_ETCHED_OUT;
        //Shadow:=GTK_SHADOW_NONE;
      end else begin
        // button up
        Shadow:=GTK_SHADOW_OUT;
      end;
    end;

    aDC:=TGtkDeviceContext(DC);
    DCOrigin:= aDC.Offset;

    If Widget <> nil then
      aStyle := gtk_widget_get_style(Widget)
    else
      aStyle := GetStyle(lgsButton);
    if aStyle = nil then
      aStyle := GetStyle(lgsGTK_Default);

      // MG: You can't assign a style to any window. Why it is needed anyway?
      //aStyle := gtk_style_attach(gtk_style_ref(aStyle),aDC.Drawable);

    if aStyle<>nil then
    begin
      aDC.RemovePixbuf;
      if (Shadow=GTK_SHADOW_NONE) then
        gtk_paint_flat_box(aStyle,aDC.Drawable,
           State,
           Shadow,
           @ClipArea,
           GetStyleWidget(lgsButton),
           'button',
           R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
           R.Right-R.Left,R.Bottom-R.Top)
      else
        gtk_paint_box(aStyle,aDC.Drawable,
           State,
           Shadow,
           @ClipArea,
           GetStyleWidget(lgsButton),
           'button',
           R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
           R.Right-R.Left,R.Bottom-R.Top);
    end;
    Result := True;
  end;

  procedure DrawCheckOrRadioButton(IsRadioButton: Boolean);
  const
    LazGtkStyleMap: array[Boolean] of TLazGtkStyle = (lgsCheckbox, lgsRadiobutton);
  var
    State: TGtkStateType;
    Shadow: TGtkShadowType;
    aDC: TGtkDeviceContext;
    DCOrigin: TPoint;
    Style : PGTKStyle;
    Widget : PGTKWidget;
  begin
    // use the gtk paint functions to draw a widget style dependent check/radio button
    if (DFCS_BUTTON3STATE and uState)<>0 then
      Shadow := GTK_SHADOW_ETCHED_IN //3state style
    else if (DFCS_CHECKED and uState)<>0 then
      Shadow := GTK_SHADOW_IN //checked style
    else
      Shadow := GTK_SHADOW_OUT; //unchecked style

    if (DFCS_PUSHED and uState)<>0 then
      State := GTK_STATE_ACTIVE //button pressed(GTK ignores disabled)
    else if (DFCS_INACTIVE and uState)<>0 then
      State := GTK_STATE_INSENSITIVE //button disabled
    else if (DFCS_HOT and uState)<>0 then
      State := GTK_STATE_PRELIGHT // button enabled, special (e.g. mouse over)
    else
      State := GTK_STATE_NORMAL; // button enabled, normal

    aDC:=TGtkDeviceContext(DC);
    DCOrigin := aDC.Offset;

    Style := GetStyle(LazGtkStyleMap[IsRadioButton]);

    if Style = nil then
    begin
      Style := GetStyle(lgsGTK_Default);
      if Style <> nil then
        Style := gtk_style_attach(gtk_style_ref(Style),aDC.Drawable);
    end;

    Widget := GetStyleWidget(LazGtkStyleMap[IsRadioButton]);

    if Widget = nil then
      Widget := GetStyleWidget(lgsDefault);
    if Widget <> nil then
      Widget^.Window := aDC.Drawable;
    Result := Style <> nil;
    if Result then
    begin
      aDC.RemovePixbuf;
      if IsRadioButton then
        gtk_paint_option(Style,aDC.Drawable, State,
          Shadow, @ClipArea, Widget, 'radiobutton',
          R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
          R.Right-R.Left, R.Bottom-R.Top)
      else
        gtk_paint_check(Style,aDC.Drawable, State,
          Shadow, @ClipArea, Widget, 'checkbutton',
          R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
          R.Right-R.Left, R.Bottom-R.Top);
    end;
  end;

var 
  ClientWidget: PGtkWidget;
begin
  Result := False;
  if IsValidDC(DC) then 
  begin
    if DevCtx.HasTransf then
    begin
      R := DevCtx.TransfRectIndirect(Rect);
      DevCtx.TransfNormalize(R.Left, R.Right);
      DevCtx.TransfNormalize(R.Top, R.Bottom);
    end else
      R := Rect;

    Widget:=TGtkDeviceContext(DC).Widget;
    //It's possible to draw in a DC without a widget, e.g., a Bitmap
    if Widget <> nil then
    begin
      ClientWidget:=GetFixedWidget(Widget);
      if ClientWidget<>nil then
        Widget:=ClientWidget;
    end;
  end else
    Widget:=nil;

  ClipArea := DevCtx.ClipRect;
  case uType of
    DFC_CAPTION:
      begin  //all draw CAPTION commands here
      end;
    DFC_MENU:
      begin

      end;
    DFC_SCROLL:
      begin
      end;
    DFC_BUTTON:
      begin
        //DebugLn(Format('Trace:  [TGtk2WidgetSet.DrawFrameControl] DFC_BUTTON --> draw rect = %d,%d,%d,%d',[R.Left,R.Top,R.Right,R.Bottom]));
        //figure out the style first
        if (uState and $1F) in [DFCS_BUTTONCHECK, DFCS_BUTTON3STATE] then
         begin
           //DebugLn('Trace:State ButtonCheck');
           DrawCheckOrRadioButton(False);
         end
         else if (DFCS_BUTTONRADIO and uState) <> 0 then
         begin
           //DebugLn('Trace:State ButtonRadio');
           DrawCheckOrRadioButton(True);
         end
         else if (DFCS_BUTTONPUSH and uState) <> 0 then
         begin
           //DebugLn('Trace:State ButtonPush');
           DrawButtonPush;
         end
         else if (DFCS_BUTTONRADIOIMAGE and uState) <> 0 then
         begin
           //DebugLn('Trace:State ButtonRadioImage');
         end
         else if (DFCS_BUTTONRADIOMASK and uState) <> 0 then
         begin
           //DebugLn('Trace:State ButtonRadioMask');
         end
         else
           DebugLn(Format('ERROR: [TGtk2WidgetSet.DrawFrameControl] Unknown State 0x%x', [uState]));
      end;
  else
    DebugLn(Format('ERROR: [TGtk2WidgetSet.DrawFrameControl] Unknown type %d', [uType]));
  end;
end;

function TGtk2WidgetSet.DrawFocusRect(DC: HDC; const Rect: TRect): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  Origin: TPoint;

  procedure DrawPixel(X1,Y1: Integer);
  begin
    inc(X1,Origin.X);
    inc(Y1,Origin.Y);
    TGtkDeviceContext(DC).RemovePixbuf;
    gdk_draw_point(TGtkDeviceContext(DC).Drawable, TGtkDeviceContext(DC).GC, X1, Y1);
  end;
  
  procedure DrawVertLine(X1,Y1,Y2: integer);
  begin
    if Y2<Y1 then
      while Y2<Y1 do begin
        DrawPixel(X1, Y1);
        dec(Y1, 2);
      end
    else
      while Y1<Y2 do begin
        DrawPixel(X1, Y1);
        inc(Y1, 2);
      end;
  end;

  procedure DrawHorzLine(X1,Y1,X2: integer);
  begin
    if X2<X1 then
      while X2<X1 do begin
        DrawPixel(X1, Y1);
        dec(X1, 2);
      end
    else
      while X1<X2 do begin
        DrawPixel(X1, Y1);
        inc(X1, 2);
      end;
  end;
  
var
  OldROP: Integer;
  APen, TempPen: HPEN;
  LogPen : TLogPen;
  R: TRect;
begin
  Result := False;
  if IsValidDC(DC) then
  begin
    with LogPen do
    begin
      lopnStyle   := PS_DOT;
      lopnWidth.X := 2;
      lopnColor   := clWhite;
    end;
    if DevCtx.HasTransf then
      R := DevCtx.TransfRectIndirect(Rect)
    else
      R := Rect;

    APen := CreatePenIndirect(LogPen);
    TempPen := SelectObject(DC, APen);
    OldRop := SetROP2(DC, R2_XORPEN);
    
    Origin := DevCtx.Offset;
    try
      DrawHorzLine(R.Left, R.Top, R.Right-1);
      DrawVertLine(R.Right-1, R.Top, R.Bottom-1);
      DrawHorzLine(R.Right-1, R.Bottom-1, R.Left);
      DrawVertLine(R.Left, R.Bottom-1, R.Top);

      Result := True;
    finally
      SelectObject(DC, TempPen);
      DeleteObject(APen);
      SetROP2(DC, OldROP);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: DrawEdge
  Params:   DC: HDC; var Rect: TRect; edge: Cardinal; grfFlags: Cardinal
  Returns:  Boolean

  Draws one or more edges of a rectangle. The rectangle is the area
  Left to Right-1 and Top to Bottom-1.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.DrawEdge(DC: HDC; var ARect: TRect; Edge: Cardinal;
  grfFlags: Cardinal): Boolean;

  procedure DrawEdges(var R: TRect; GC: pgdkGC; Drawable:PGdkDrawable;
    const TopLeftColor, BottomRightColor: TGDKColor);
  begin
    gdk_gc_set_foreground(GC, @TopLeftColor);
    if (grfFlags and BF_TOP) = BF_TOP then begin
      gdk_draw_line(Drawable, GC, R.Left, R.Top, R.Right, R.Top);
      inc(R.Top);
    end;
    if (grfFlags and BF_LEFT) = BF_LEFT then begin
      gdk_draw_line(Drawable, GC, R.Left, R.Top, R.Left, R.Bottom);
      inc(R.Left);
    end;

    gdk_gc_set_foreground(GC, @BottomRightColor);
    if (grfFlags and BF_BOTTOM) = BF_BOTTOM then begin
      gdk_draw_line(Drawable, GC, R.Left, R.Bottom-1, R.Right, R.Bottom-1);
      dec(R.Bottom);
    end;
    if (grfFlags and BF_RIGHT) = BF_RIGHT then begin
      gdk_draw_line(Drawable, GC, R.Right-1, R.Top, R.Right-1, R.Bottom);
      dec(R.Right);
    end;
  end;

var
  InnerTL, OuterTL,
  InnerBR, OuterBR, MiddleColor: TGDKColor;
  BInner, BOuter: Boolean;
  R: TRect;
  DCOrigin: TPoint;
begin
  //DebugLn('TGtk2WidgetSet.DrawEdge Edge=',DbgS(Edge),8),' grfFlags=',DbgS(Cardinal(grfFlags));
  Result := IsValidDC(DC);
  if Result then
    with TGtkDeviceContext(DC) do
    begin
      R := ARect;

      LPtoDP(DC, R, 2);

      DCOrigin := Offset;
      OffsetRect(R, DCOrigin.X, DCOrigin.Y);

      // try to use the gdk functions, so that the current theme is used
      BInner := False;
      BOuter := False;

      // TODO: change this to real colors
      if (edge and BDR_RAISEDINNER) = BDR_RAISEDINNER
      then begin
        InnerTL := AllocGDKColor(GetSysColor(COLOR_BTNHIGHLIGHT));
        InnerBR := AllocGDKColor(GetSysColor(COLOR_BTNSHADOW));
        BInner := True;
      end;
      if (edge and BDR_SUNKENINNER) = BDR_SUNKENINNER
      then begin
        InnerTL := AllocGDKColor(GetSysColor(COLOR_BTNSHADOW));
        InnerBR := AllocGDKColor(GetSysColor(COLOR_BTNHIGHLIGHT));
        BInner := True;
      end;
      if (edge and BDR_RAISEDOUTER) = BDR_RAISEDOUTER
      then begin
        OuterTL := AllocGDKColor(GetSysColor(COLOR_BTNHIGHLIGHT));
        OuterBR := AllocGDKColor(GetSysColor(COLOR_BTNSHADOW));
        BOuter := True;
      end;
      if (edge and BDR_SUNKENOUTER) = BDR_SUNKENOUTER
      then begin
        OuterTL := AllocGDKColor(GetSysColor(COLOR_BTNSHADOW));
        OuterBR := AllocGDKColor(GetSysColor(COLOR_BTNHIGHLIGHT));
        BOuter := True;
      end;

      gdk_gc_set_fill(GC, GDK_SOLID);
      SelectedColors := dcscCustom;

      // Draw outer rect
      if BOuter then
      begin
        RemovePixbuf;
        DrawEdges(R, GC,Drawable,OuterTL,OuterBR);
      end;

      // Draw inner rect
      if BInner then
      begin
        RemovePixbuf;
        DrawEdges(R,GC,Drawable,InnerTL,InnerBR);
      end;

  //      gdk_colormap_free_colors(gdk_colormap_get_system, @OuterTL, 1);
  //      gdk_colormap_free_colors(gdk_colormap_get_system, @OuterBR, 1);
  //      gdk_colormap_free_colors(gdk_colormap_get_system, @InnerTL, 1);
  //      gdk_colormap_free_colors(gdk_colormap_get_system, @InnerBR, 1);

      //Draw interiour
      if ((grfFlags and BF_MIDDLE) = BF_MIDDLE) then
      begin
        RemovePixbuf;
        MiddleColor := AllocGDKColor(GetSysColor(COLOR_BTNFACE));
        gdk_gc_set_foreground(GC, @MiddleColor);
        gdk_draw_rectangle(Drawable, GC, 1, R.Left, R.Top,
          R.Right - R.Left, R.Bottom - R.Top);
      end;

      // adjust rect if needed
      if (grfFlags and BF_ADJUST) = BF_ADJUST then
      begin
        ARect := R;
        OffsetRect(ARect, -DCOrigin.X, -DCOrigin.Y);
        DPtoLP(DC, ARect, 2);
      end;
      Result := True;
    end;
end;

{------------------------------------------------------------------------------
  Method:  DrawText
  Params:  DC, Str, Count, Rect, Flags
  Returns: If the string was drawn, or CalcRect run

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.DrawText(DC: HDC; Str: PChar; Count: Integer;
  var Rect: TRect; Flags: Cardinal): Integer;
const
  TabString = '        ';
var
  pIndex: Longint;
  AStr: String;

  TM: TTextmetric;
  theRect: TRect;
  Lines: PPChar;
  I, NumLines: Longint;
  TempDC: HDC;
  TempPen: HPEN;
  TempBrush: HBRUSH;
  l: LongInt;
  Pt: TPoint;
  SavedRect: TRect; // if font orientation <> 0
  LineHeight: Integer;
  Size: TSize;

  function LeftOffset: Longint;
  begin
    if (Flags and DT_RIGHT) = DT_RIGHT then
      Result := DT_RIGHT
    else
      if (Flags and DT_CENTER) = DT_CENTER then
        Result := DT_CENTER
    else
      Result := DT_LEFT;
  end;

  function TopOffset: Longint;
  begin
    if (Flags and DT_BOTTOM) = DT_BOTTOM then
      Result := DT_BOTTOM
    else
      if (Flags and DT_VCENTER) = DT_VCENTER then
        Result := DT_VCENTER
    else
      Result := DT_TOP;
  end;

  function CalcRect: Boolean;
  begin
    Result := (Flags and DT_CALCRECT) = DT_CALCRECT;
  end;

  function TextExtentPoint(Str: PChar; Count: Integer; var Sz: TSize): Boolean;
  var
    NewStr: String;
  begin
    if (Flags and DT_EXPANDTABS) <> 0 then
    begin
      NewStr := StringReplace(Str, #9, TabString, [rfReplaceAll]);
      Result := GetTextExtentPoint(DC, PChar(NewStr), Length(NewStr), Sz);
    end
    else
      Result := GetTextExtentPoint(Dc, Str, Count, Sz);
  end;

  procedure DoCalcRect;
  var
    AP: TSize;
    J, MaxWidth,
    LineWidth, ActualHeight: Integer;
  begin
    theRect := Rect;

    MaxWidth := theRect.Right - theRect.Left;

    if (Flags and DT_SINGLELINE) > 0 then
    begin
      // ignore word and line breaks
      TextExtentPoint(PChar(AStr), length(AStr), AP{%H-});
      theRect.Bottom := theRect.Top + TM.tmHeight;
      if (Flags and DT_CALCRECT)<>0 then
      begin
        theRect.Right := theRect.Left +  AP.cX;
        theRect.Bottom := theRect.Top +  AP.cY;
      end
      else
      begin
        theRect.Right := theRect.Left + Min(MaxWidth, AP.cX);
        theRect.Bottom := theRect.Top +  AP.cY;
        if (Flags and DT_VCENTER) > 0 then
        begin
          OffsetRect(theRect, 0, ((Rect.Bottom - Rect.Top) - (theRect.Bottom - theRect.Top)) div 2);
        end
        else
        if (Flags and DT_BOTTOM) > 0 then
        begin
          OffsetRect(theRect, 0, (Rect.Bottom - Rect.Top) - (theRect.Bottom - theRect.Top));
        end;

      end;
    end
    else
    begin
      // consider line breaks
      if (Flags and DT_WORDBREAK) = 0 then
      begin
        // do not break at word boundaries
        TextExtentPoint(PChar(AStr), length(AStr), AP);
        MaxWidth := AP.cX;
      end;
      Self.WordWrap(DC, PChar(AStr), MaxWidth, Lines, NumLines);

      if (Flags and DT_CALCRECT)<>0 then
      begin
        LineWidth := 0;
        ActualHeight := 0;
        if (Lines <> nil) then
        begin
          for J := 0 to NumLines - 1 do
          begin
            TextExtentPoint(Lines[J], StrLen(Lines[J]), AP);
            LineWidth := Max(LineWidth, AP.cX);
            Inc(ActualHeight, AP.cY);
          end;
        end;
        LineWidth := Min(MaxWidth, LineWidth);
      end else
      begin
        LineWidth := MaxWidth;
        ActualHeight := NumLines*TM.tmHeight;
      end;

      theRect.Right := theRect.Left + LineWidth;
      theRect.Bottom := theRect.Top + ActualHeight;
      if NumLines>1 then
        Inc(theRect.Bottom, (NumLines-1)*TM.tmExternalLeading);// space between lines

      //debugln('TGtk2WidgetSet.DrawText A ',dbgs(theRect),' TM.tmHeight=',dbgs(TM.tmHeight),' LineWidth=',dbgs(LineWidth),' NumLines=',dbgs(NumLines));
    end;

    if not CalcRect then
      case LeftOffset of
        DT_CENTER:
          OffsetRect(theRect, (Rect.Right - theRect.Right) div 2, 0);
        DT_RIGHT:
          OffsetRect(theRect, Rect.Right - theRect.Right, 0);
      end;
  end;

  // if our Font.Orientation <> 0 we must recalculate X,Y offset
  // also it works only with DT_TOP DT_LEFT. Gtk2 can handle multiline
  // text in this case too.
  procedure CalculateOffsetWithAngle(const AFontAngle: Integer;
    var TextLeft,TextTop: Integer);
  var
    OffsX, OffsY: integer;
    Angle: Double;
    Size: TSize;
    R: TRect;
  begin
    R := SavedRect;
    OffsX := R.Right - R.Left;
    OffsY := R.Bottom - R.Top;
    Size.cx := OffsX;
    Size.cy := OffsY;
    Angle := AFontAngle / 10;
    if Angle < 0 then
      Angle := 360 + Angle;

    if Angle <= 90 then
    begin
      OffsX := 0;
      OffsY := Trunc(Size.cx * sin(Angle * Pi / 180));
    end else
    if Angle <= 180 then
    begin
      OffsX := Trunc(Size.cx * -cos(Angle * Pi / 180));
      OffsY := Trunc(Size.cx * sin(Angle * Pi / 180) +
         Size.cy * cos((180 - Angle) * Pi / 180));
    end else
    if Angle <= 270 then
    begin
      OffsX := Trunc(Size.cx * -cos(Angle * Pi / 180) +
        Size.cy * sin((Angle - 180) * Pi / 180));
      OffsY := Trunc(Size.cy * sin((270 - Angle) * Pi / 180));
    end else
    if Angle <= 360 then
    begin
      OffsX := Trunc(Size.cy * sin((360 - Angle) * Pi / 180));
      OffsY := 0;
    end;
    TextTop := OffsY;
    TextLeft := OffsX;
  end;

  function NeedOffsetCalc: Boolean;
  var
    AClipRect: TRect;
  begin
    {see issue #27547}
    AClipRect := RectFromGdkRect(TGtkDeviceContext(DC).ClipRect);
    OffsetRect(AClipRect, -AClipRect.Left, -AClipRect.Top);
    Result := (TGtkDeviceContext(DC).CurrentFont^.LogFont.lfOrientation <> 0) and
        (Flags and DT_SINGLELINE <> 0) and
        (Flags and DT_VCENTER = 0) and (Flags and DT_CENTER = 0) and
        (Flags and DT_RIGHT = 0) and (Flags and  DT_BOTTOM = 0) and
        (Flags and DT_CALCRECT = 0) and not IsRectEmpty(SavedRect) and
        EqualRect(AClipRect, Rect);
  end;


  procedure DrawLineRaw(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LeftPos: Longint;
  begin
    if LeftOffset <> DT_LEFT then
      GetTextExtentPoint(DC, theLine, LineLength, {%H-}Points[0]);

    if TempBrush = HBRUSH(-1) then
      TempBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));
    case LeftOffset of
      DT_LEFT:
        LeftPos := theRect.Left;
      DT_CENTER:
        LeftPos := theRect.Left + (theRect.Right - theRect.Left) div 2
                 - Points[0].cX div 2;
      DT_RIGHT:
        LeftPos := theRect.Right - Points[0].cX;
    end;

    Pt := Point(0, 0);
    // Draw line of Text
    if NeedOffsetCalc then
    begin
      Pt.X := SavedRect.Left;
      Pt.Y := SavedRect.Top;
      CalculateOffsetWithAngle(TGtkDeviceContext(DC).CurrentFont^.LogFont.lfOrientation, Pt.X, Pt.Y);
    end;
    TextUtf8Out(DC, LeftPos + Pt.X, TopPos + Pt.Y, theLine, lineLength);
  end;

  procedure DrawLine(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LogP: TLogPen;
    LeftPos: Longint;
  begin
    if TempBrush = HBRUSH(-1) then
      TempBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));

    FillByte({%H-}Points[0],SizeOf(Points[0])*2,0);
    if LeftOffset <> DT_Left then
      GetTextExtentPoint(DC, theLine, LineLength, Points[0]);

    case LeftOffset of
      DT_LEFT:
        LeftPos := theRect.Left;
      DT_CENTER:
        LeftPos := theRect.Left + (theRect.Right - theRect.Left) div 2
                 - Points[0].cX div 2;
      DT_RIGHT:
        LeftPos := theRect.Right - Points[0].cX;
    end;

    Pt := Point(0, 0);
    if NeedOffsetCalc then
    begin
      Pt.X := SavedRect.Left;
      Pt.Y := SavedRect.Top;
      CalculateOffsetWithAngle(TGtkDeviceContext(DC).CurrentFont^.LogFont.lfOrientation, Pt.X, Pt.Y);
    end;
    // Draw line of Text
    TextUtf8Out(DC, LeftPos + Pt.X, TopPos + Pt.Y, theLine, LineLength);

    // Draw Prefix
    if (pIndex > 0) and (pIndex<=LineLength) then
    begin
      // Create & select pen of font color
      if TempPen = HPEN(-1) then
      begin
        LogP.lopnStyle := PS_SOLID;
        LogP.lopnWidth.X := 1;
        LogP.lopnColor := GetTextColor(DC);
        TempPen := SelectObject(DC, CreatePenIndirect(LogP));
      end;

      {Get prefix line position}
      GetTextExtentPoint(DC, theLine, pIndex - 1, Points[0]);
      Points[0].cX := LeftPos + Points[0].cX;
      Points[0].cY := TopPos + tm.tmHeight - TM.tmDescent + 1;

      GetTextExtentPoint(DC, @aStr[pIndex], UTF8CodepointSize(@aStr[pIndex]), Points[1]);
      Points[1].cX := Points[0].cX + Points[1].cX;
      Points[1].cY := Points[0].cY;

      {Draw prefix line}
      Polyline(DC, PPoint(@Points[0]), 2);
    end;
  end;

begin
  if (Str=nil) or (Str[0]=#0) then Exit(0);

  //DebugLn(Format('trace:> [TGtk2WidgetSet.DrawText] DC:0x%x, Str:''%s'', Count: %d, Rect = %d,%d,%d,%d, Flags:%d',
  //  [DC, Str, Count, Rect.Left, Rect.Top, Rect.Right, Rect.Bottom, Flags]));

  if not IsValidDC(DC) then Exit(0);
  if (Count < -1) or (IsRectEmpty(Rect) and
    ((Flags and DT_CALCRECT = 0) and (Flags and DT_NOCLIP = 0))) then Exit(0);

  // Don't try to use StrLen(Str) in cases count >= 0
  // In those cases str is NOT required to have a null terminator !
  if Count = -1 then Count := StrLen(Str);

  Lines := nil;
  NumLines := 0;
  TempDC := HDC(-1);
  TempPen := HPEN(-1);
  TempBrush := HBRUSH(-1);

  try
    if (Flags and (DT_SINGLELINE or DT_CALCRECT or DT_NOPREFIX or DT_NOCLIP or DT_EXPANDTABS)) =
       (DT_SINGLELINE or DT_NOPREFIX or DT_NOCLIP)
    then begin
      //DebugLn(['TGtk2WidgetSet.DrawText Calc single line']);
      CopyRect(theRect, Rect);
      SavedRect := Rect;
      DrawLineRaw(Str, Count, Rect.Top);
      Result := Rect.Bottom - Rect.Top;
      Exit;
    end;

    SetLength(AStr{%H-},Count);
    if Count>0 then
      System.Move(Str^,AStr[1],Count);

    if (Flags and DT_EXPANDTABS) <> 0 then
      AStr := StringReplace(AStr, #9, TabString, [rfReplaceAll]);

    if (Flags and DT_NOPREFIX) <> DT_NOPREFIX then
      pIndex := DeleteAmpersands(AStr)
    else
      pIndex := -1;

    GetTextMetrics(DC, TM{%H-});
    DoCalcRect;
    Result := theRect.Bottom - theRect.Top;
    if (Flags and DT_CALCRECT) = DT_CALCRECT
    then begin
      //DebugLn(['TGtk2WidgetSet.DrawText Complex Calc']);
      CopyRect(Rect, theRect);
      exit;
    end;

    TempDC := SaveDC(DC);

    if (Flags and DT_NOCLIP) <> DT_NOCLIP then
    begin
      if theRect.Right > Rect.Right then
        theRect.Right := Rect.Right;
      if theRect.Bottom > Rect.Bottom then
        theRect.Bottom := Rect.Bottom;
      IntersectClipRect(DC, theRect.Left, theRect.Top,
        theRect.Right, theRect.Bottom);
    end;

    if (Flags and DT_SINGLELINE) = DT_SINGLELINE
    then begin
      // DebugLn(['TGtk2WidgetSet.DrawText Draw single line']);
      SavedRect := TheRect;
      DrawLine(PChar(AStr), length(AStr), theRect.Top);
      Exit; //we're ready
    end;
    
    // multiple lines
    if Lines = nil then Exit;  // nothing to do
    if NumLines = 0 then Exit; //
    
    
    //DebugLn(['TGtk2WidgetSet.DrawText Draw multiline']);
    SavedRect := Classes.Rect(0, 0, 0, 0); // no font orientation change if multilined text
    for i := 0 to NumLines - 1 do
    begin
      if theRect.Top > theRect.Bottom then Break;

      if  ((Flags and DT_EDITCONTROL) = DT_EDITCONTROL)
      and (tm.tmHeight > (theRect.Bottom - theRect.Top))
      then Break;

      if Lines[i] <> nil then
      begin
        l:=StrLen(Lines[i]);
        DrawLine(Lines[i], l, theRect.Top);
        dec(pIndex,l+length(LineEnding));
        GetTextExtentPoint(DC, Lines[i], l, Size{%H-});
        LineHeight := Size.cY;
      end
      else
        LineHeight := TM.tmHeight;
      Inc(theRect.Top, LineHeight + TM.tmExternalLeading);// space between lines
    end;

  finally
    Reallocmem(Lines, 0);
    if TempBrush <> HBRUSH(-1) then
      SelectObject(DC, TempBrush);// DeleteObject not needed here, because it was a default Brush
    if TempPen <> HPEN(-1) then
      DeleteObject(SelectObject(DC, TempPen));
    if TempDC <> HDC(-1) then
      RestoreDC(DC, TempDC);
  end;
end;

{------------------------------------------------------------------------------
  Function: EnableScrollBar
  Params:  Wnd, wSBflags, wArrows
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.EnableScrollBar(Wnd: HWND; wSBflags, wArrows: Cardinal): Boolean;
begin
  // TODO: implement TGtk2WidgetSet.EnableScrollBar
  Result := False;
end;

{------------------------------------------------------------------------------
  Function: EnableWindow
  Params: hWnd:
          bEnable:
  Returns:
  If the window was previously disabled, the return value is TRUE.
  If the window was not previously disabled, the return value is FALSE.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
begin
  Result := False;
  if hWnd <> 0 then
  begin
    Result := not GTK_WIDGET_SENSITIVE({%H-}PGtkWidget(HWND));
    gtk_widget_set_sensitive({%H-}PGtkWidget(hWnd), bEnable);
    InvalidateLastWFPResult(nil, RectFromGdkRect({%H-}PGtkWidget(HWND)^.allocation));
  end;
end;

{------------------------------------------------------------------------------
  Function: EndPaint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct): Integer;
var
  Widget: PGtkWidget;
  Info: PWidgetInfo;
  Control: TWinControl;

begin
  Result:=1;
  if PS.HDC = 0 then Exit;

  if Handle <> 0 
  then Control := TWinControl(GetLCLObject({%H-}Pointer(Handle)))
  else Control := nil;

  if (Control <> nil)
  and TWSWinControlClass(Control.WidgetSetClass).GetDoubleBuffered(Control)
  and not GTK_WIDGET_DOUBLE_BUFFERED({%H-}PGTKWidget(Handle))
  then begin
    gdk_window_thaw_updates(TGtkDeviceContext(PS.HDC).Drawable);
    gdk_window_end_paint (TGtkDeviceContext(PS.HDC).Drawable);
  end;

  Widget := {%H-}PGtkWidget(Handle);
  Info:=GetWidgetInfo(Widget);
  if Info<>nil then
    dec(Info^.PaintDepth);

  ReleaseDC(Handle, PS.HDC);
end;

function TGtk2WidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
var
  i: integer;
begin
  Result := True;
  for i := 0 to gdk_screen_get_n_monitors(gdk_screen_get_default) - 1 do
  begin
    Result := Result and lpfnEnum(i + 1, 0, nil, dwData);
    if not Result then break;
  end;
end;

{.$define VerboseEnumFonts}
{$IFDEF GTK2OLDENUMFONTFAMILIES}
function TGtk2WidgetSet.EnumFontFamilies(DC: HDC; Family: Pchar;
  EnumFontFamProc: FontEnumProc; LParam:Lparam):longint;
var
  xFonts: PPChar;
  FontList: TStringList;
  EnumLogFont: TEnumLogFont;
  Metric: TNewTextMetric;
  I,N: Integer;
  tmp: String;
  FontType: Integer;
begin
  result := 0;
  if not Assigned(EnumFontFamProc) then begin
    result := 2;
    DebugLn('EnumFontFamProc Callback not set');
    // todo: raise exception?
    exit;
  end;
  FontList := TStringlist.Create;
  try
    if Family<>'' then
      Tmp := '-*-'+Family+'-*-*-*-*-*-*-*-*-*-*-*-*'
    else
      Tmp := '-*'; // get rid of aliases
    {$ifdef VerboseEnumFonts}
    WriteLn('Looking for fonts matching: ', tmp);
    {$endif}
    {$ifdef HasX}
    XFonts := XListFonts(gdk_display, pchar(Tmp), 10000, @N);
    {$else}
    {$IFDEF VerboseGtkToDos}{$warning implement getting XFonts for this OS}{$ENDIF}
    XFonts := nil;
    N:=0;
    {$endif}
    try
      for I := 0 to N - 1 do
        if XFonts[I] <> nil then begin
          Tmp := ExtractFamilyFromXLFDName(XFonts[I]);
          {$ifdef VerboseEnumFonts}
          WriteLn(I:5,' [', tmp, '] Font=',XFonts[i]);
          {$endif}
          if Tmp <> '' then begin
            if family='' then begin
              // get just the font names
              if FontList.IndexOf(Tmp) < 0 then begin
                EnumLogFont.elfLogFont := XLFDNameToLogFont(XFonts[i]);
                FillChar(Metric, SizeOf(Metric), #0);
                FontType := 0; // todo: GetFontTypeFromXLDF or FontId
                EnumLogFont.elfFullName := '';
                EnumFontFamProc(EnumLogFont, Metric, FontType, Lparam);
                FontList.Append(Tmp);
              end;
            end else begin
              EnumLogFont.elfLogFont := XLFDNameToLogFont(XFonts[i]);
              EnumlogFont.elfFullname := '';
              EnumLogFont.elfStyle := '';
              FillChar(Metric, SizeOf(Metric), #0);
              FontType := 0; // todo: GetFontTypeFromXLDF or FontId
              EnumFontFamProc(EnumLogFont, Metric, FontType, Lparam);
            end;
          end;
        end;
    finally
      {$ifdef HasX}
      XFreeFontNames(XFonts);
      {$endif}
    end;
  finally
    Fontlist.Free;
  end;
end;

function TGtk2WidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; Lparam:LParam; Flags: dword): longint;
type
  TXLFD=record
    Foundry: string[15];
    Family, CharsetReg, CharsetCod: string[32];
    WeightName,widthName,StyleName: string[20];
    Slant: string[5];
    PixelSize,PointSize,ResX,ResY: Integer;
  end;

var
  Xlfd: TXLFD;
  CharsetFilter: TStringList;
  PitchFilter: TStringList;
  EnumLogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;

  function ParseXLFDFont(const font: string): boolean;
    function MyStrToIntDef(const s: string; def: integer): integer;
    begin
      result := StrToIntDef(s, Def);
      if result=0 then
        result := def
    end;
  begin
    result := IsFontNameXLogicalFontDesc(font);
    fillchar(Xlfd, SizeOf(Xlfd), 0);
    if result then with Xlfd do begin
      Foundry     := ExtractXLFDItem(Font, XLFD_FOUNDRY);
      Family      := ExtractXLFDItem(Font, XLFD_FAMILY);
      CharsetReg  := ExtractXLFDItem(Font, XLFD_CHARSET_REG);
      CharSetCod  := ExtractXLFDItem(Font, XLFD_CHARSET_COD);
      WeightName  := ExtractXLFDItem(Font, XLFD_WEIGHTNAME);
      Slant       := ExtractXLFDItem(Font, XLFD_SLANT);
      WidthName   := ExtractXLFDItem(Font, XLFD_WIDTHNAME);
      StyleName   := ExtractXLFDItem(Font, XLFD_STYLENAME);
      ResX        := MyStrToIntDef(ExtractXLFDItem(Font, XLFD_RESX), 72);
      ResY        := MyStrToIntDef(ExtractXLFDItem(Font, XLFD_RESX), 72);
      PixelSize   := StrToIntDef(ExtractXLFDItem(Font, XLFD_PIXELSIZE), 0);
      PointSize   := StrToIntDef(ExtractXLFDItem(Font, XLFD_POINTSIZE), 0);
    end;
  end;
  
  function XLFDToFontStyle: string;
  var
    s: string;
  begin
    result := xlfd.WeightName;
    s :=lowercase(xlfd.Slant);
    if s='i'  then result := result + ' '+ 'italic' else
    if s='o'  then result := result + ' '+ 'oblique' else
    if s='ri' then result := result + ' '+ 'reverse italic' else
    if s='ro' then result := result + ' '+ 'reverse oblique'
    else begin
      if (S<>'r')and(S<>'') then
        result := result + ' ' + S;
    end;
  end;
  
  procedure QueueCharsetFilter(Charset: byte);
  var
    i: integer;
    rec: PCharsetEncodingRec;
    s: string;
  begin
    for i:=0 to CharsetEncodingList.count-1 do begin
      Rec := CharsetEncodingList[i];
      if (Rec=nil) or (Rec^.CharSet<>Charset) or (not Rec^.EnumMap) then
        continue;
      s := Rec^.CharSetReg;
      if Rec^.CharsetRegPart then
        s := s + '*';
      s := s + '-' + Rec^.CharSetCod;
      if Rec^.CharsetCodPart then
        s := s + '*';
      CharsetFilter.Add(s);
    end;
  end;
  
  procedure QueuePitchFilter(Pitch: byte);
  begin
  
    if pitch and FIXED_PITCH = FIXED_PITCH then begin
      PitchFilter.Add('m');
      PitchFilter.Add('c'); // character cell it's also fixed pitch
    end;

    if pitch and VARIABLE_PITCH = VARIABLE_PITCH then
      PitchFilter.Add('p');

    if pitch and MONO_FONT = MONO_FONT then
      PitchFilter.Add('m');
      
    if PitchFilter.Count=0 then
      PitchFilter.Add('*');
  end;

  function XLFDToCharset: byte;
  const
    CharsetPriority: array[1..19] of byte =
    (
      SYMBOL_CHARSET,       MAC_CHARSET,      SHIFTJIS_CHARSET,
      HANGEUL_CHARSET,      JOHAB_CHARSET,    GB2312_CHARSET,
      CHINESEBIG5_CHARSET,  GREEK_CHARSET,    TURKISH_CHARSET,
      VIETNAMESE_CHARSET,   HEBREW_CHARSET,   ARABIC_CHARSET,
      BALTIC_CHARSET,       RUSSIAN_CHARSET,  THAI_CHARSET,
      EASTEUROPE_CHARSET,   OEM_CHARSET,      FCS_ISO_10646_1,
      ANSI_CHARSET
    );
  var
    i,n: integer;
    rec: PCharsetEncodingRec;
  begin
    for i := Low(CharsetPriority) to High(CharsetPriority) do
      for n:= 0 to CharsetEncodingList.count-1 do begin
        rec := CharsetEncodingList[n];
        if (rec=nil) or (rec^.CharSet<>CharsetPriority[i]) then
          continue;
        // try to match registry part
        if rec^.CharSetReg<>'*' then begin
          if rec^.CharsetRegPart then begin
            if pos(rec^.CharSetReg, xlfd.CharsetReg)=0 then
              continue;
          end else begin
            if AnsiCompareText(Rec^.CharSetReg, xlfd.CharsetReg) <> 0 then
              continue;
          end;
        end;
        // try to match coding part
        if rec^.CharSetCod<>'*' then begin
          if rec^.CharsetCodPart then begin
            if pos(rec^.CharSetCod, xlfd.CharsetCod)=0 then
              continue;
          end else begin
            if AnsiCompareText(Rec^.CharSetCod, xlfd.CharsetCod) <> 0 then
              continue;
          end;
        end;
        // this one is good enought to match bot registry and encondig part
        result := CharsetPriority[i];
        exit;
      end;
    result := DEFAULT_CHARSET;
  end;

  function XLFDCharsetToScript: string;
  begin
    result := xlfd.CharsetReg + '-' + xlfd.CharsetCod;
  end;
  
  function FoundryAndFamilyFilter(const FaceName: string): string;
  var
    foundry,family: string;
    i: LongInt;
  begin
    if FaceName='' then begin
      family := '*';
      foundry := '*';
    end else begin
      family := FaceName;
      // look for foundry encoded in family name
      i := pos(FOUNDRYCHAR_OPEN, family);
      if i<>0 then begin
        Foundry := copy(Family, i+1, Length(Family));
        family := trim(copy(family, 1, i-1));
        i := pos(FOUNDRYCHAR_CLOSE, Foundry);
        if i<>0 then
          Delete(Foundry, i, Length(Foundry))
        else
          ; // ill formed but it's ok.
      end else
        Foundry := '*';
    end;
    result := Foundry+'-'+Family;
  end;
  
  function XLFDFamilyFace: string;
  begin
    with xlfd do
    if (Length(Foundry)>0) and (Length(Family) + length(Foundry) + 3 < 31) then
      result := Family + ' '+ FOUNDRYCHAR_OPEN + Foundry + FOUNDRYCHAR_CLOSE
    else
      result := Family;
  end;
  
  function XLFDToFontType: integer;
  begin
    if ((xlfd.PointSize=0) and (xlfd.PixelSize=0))
         or ((xlfd.PointSize=120) and (xlfd.PixelSize=17)) // see bug 16298
    then
      result := TRUETYPE_FONTTYPE
    else
      result := RASTER_FONTTYPE or DEVICE_FONTTYPE;
  end;

  // process the current xlfd font, if user returns 0 from callback finish
  function ProcessXFont(const index: integer; const font: string;
    FontList: TStringList): boolean;
  var
    FontType: Integer;
    tmp: string;
    FullSearch: boolean;
  begin
    FullSearch := ( lpLogFont^.lfFaceName = '');
    result := false;
    with xlfd, EnumLogFont do
    if FullSearch then begin
      //
      // quick enumeration of fonts, make sure this is
      // documented because only some fields are filled !!!
      //
      Foundry    := ExtractXLFDItem(Font, XLFD_FOUNDRY);
      Family     := ExtractXLFDItem(Font, XLFD_FAMILY);
      tmp := XLFDFamilyFace();
      
      if FontList.IndexOf(tmp) < 0 then begin
        PixelSize  := StrToIntDef(ExtractXLFDItem(Font, XLFD_PIXELSIZE), 0);
        PointSize  := StrToIntDef(ExtractXLFDItem(Font, XLFD_POINTSIZE), 0);
        CharsetReg := ExtractXLFDItem(Font, XLFD_CHARSET_REG);
        CharsetCod := ExtractXLFDItem(Font, XLFD_CHARSET_COD);
        FontType := XLFDToFontType();
        elfLogFont.lfCharSet := XLFDToCharset();
        elfLogFont.lfFaceName := tmp;
        result := Callback(EnumLogFont, Metric, FontType, LParam)=0;
        FontList.Append(tmp);
      end;
    end else
    if ParseXLFDFont(Font) then begin
      //
      // slow enumeration of fonts, only if face is present
      //
      // family
      tmp := XLFDFamilyFace();
      {$ifdef verboseEnumFonts}
      DebugLn(dbgs(index),' face=', tmp, ' Font=', Font);
      {$endif}

      //if FontList.IndexOf(tmp) < 0 then begin

        // Fonttype
        FontType := XLFDToFontType();
        // LogFont
        elfLogFont := XLFDNameToLogFont(Font);
        elfLogFont.lfFaceName := tmp;
        elfLogFont.lfCharSet := XLFDToCharset();
        // from logfont

        elfStyle := XLFDToFontStyle();

        elfScript := XLFDCharsetToScript();
        // tempted to feed here full xlfd, but 63 chars might be to small
        if Foundry = '' then
          elfFullName := Family
        else
          elfFullName := Foundry + ' ' + Family ;

        // Metric
        //
        fillchar(metric.ntmeFontSignature,
          sizeOf(metric.ntmeFontSignature), 0);
        with metric.ntmentm do begin
          tmheight := elfLogFont.lfHeight;
          tmAveCharWidth := elfLogFont.lfWidth;
          tmWeight :=  elfLogFont.lfWeight;
          tmDigitizedAspectX := ResX;
          tmDigitizedAspectY := ResY;
          tmItalic := elfLogFont.lfItalic;
          tmUnderlined := elfLogFont.lfUnderline;
          tmStruckOut := elfLogFont.lfStrikeOut;
          tmPitchAndFamily := elfLogFont.lfPitchAndFamily;
          tmCharSet := elfLogFont.lfCharSet;
          // todo fields
          tmMaxCharWidth := elfLogFont.lfWidth; // todo
          tmAscent  := 0;           // todo
          tmDescent := 0;           // todo
          tmInternalLeading := 0;   // todo
          tmExternalLeading := 0;   // todo
          tmOverhang := 0;          // todo;
          tmFirstChar := ' ';       // todo, atm ascii
          tmLastChar  := #255;      // todo, atm ascii
          tmDefaultChar := '.';     // todo, atm dot
          tmBreakChar := ' ';       // todo, atm space
          ntmFlags := 0;                // todo combination of NTM_XXXX constants
          ntmSizeEM := tmHeight;        // todo
          ntmCellHeight :=  ntmSizeEM;  // todo
          ntmAvgWidth :=  ntmSizeEM;    // todo
        end; // with metric.ntmentm do ...

        // do callback
        result := Callback(EnumLogFont, Metric, FontType, LParam) = 0;
        FontList.Append(tmp);
      //end; // if not FullSearch or (FontList.IndexOf(tmp) < 0 then ...
    end; // with xlfd, EnumLogFont do ...
  end;
var
  xFonts: PPChar;
  FontList: TStringList;
  I,J,K,N: Integer;
  Tmp,FandF: String;
begin
  result := 0;
  // initial checks
  if not Assigned(Callback) then begin
    result := 2;
    DebugLn('EnumFontFamiliesEx: EnumFontFamProcEx Callback not set');
    // todo: raise exception?
    exit;
  end;
  if not Assigned(lpLogFont) then begin
    result := 3;
    DebugLn('EnumFontFamiliesEx: lpLogFont not set');
    // todo: enumerate all fonts?
    exit;
  end;
  
  // foundry and family filter
  FandF := FoundryAndFamilyFilter(lpLogFont^.lfFaceName);
  
  FontList := TStringlist.Create;
  CharSetFilter := TStringList.Create;
  PitchFilter := TStringList.Create;
  PitchFilter.Duplicates := dupIgnore;
  try
    QueueCharSetFilter(lpLogFont^.lfCharSet);
    QueuePitchFilter(lpLogFont^.lfPitchAndFamily);
    
    {$ifdef verboseEnumFonts}
    for j:=0 to CharSetFilter.Count-1 do begin
      // pitch filter is guaranteed to have at least one element
      for k:=0 to PitchFilter.Count-1 do begin
        tmp := '-'+FAndF+'-*-*-*-*-*-*-*-*-'+PitchFilter[k]+'-*-'+CharSetFilter[j];
        DebugLn('EnumFontFamiliesEx: will enumerate fonts matching: ', tmp);
      end;
    end;
    {$endif}
    for j:=0 to CharSetFilter.Count-1 do begin
      for k:=0 to PitchFilter.Count-1 do begin
        tmp := '-'+FAndF+'-*-*-*-*-*-*-*-*-'+PitchFilter[k]+'-*-'+CharSetFilter[j];
        {$ifdef HasX}
        XFonts := XListFonts(gdk_display, pchar(Tmp), 10000, @N);
        {$else}
        {$IFDEF VerboseGtkToDos}{$warning implement getting XFonts for this OS}{$ENDIF}
        XFonts := nil;
        N:=0;
        {$endif}
        try
          {$ifdef VerboseEnumFonts}
          DebugLn('EnumFontFamiliesEx: found ',dbgs(N),' fonts matching: ', tmp);
          {$endif}
          for i:=0 to N-1 do
            if XFonts[i]<>nil then
              if ProcessXFont(i, XFonts[i], FontList) then
                break;
        finally
          {$ifdef HasX}
          XFreeFontNames(XFonts);
          {$endif}
        end;
      end;
    end;
  finally
    PitchFilter.Free;
    Fontlist.Free;
    CharSetFilter.Free;
  end;
end;

{$ELSE} //  pure pango font families

function TGtk2WidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; Lparam:LParam; Flags: dword): longint;

type
  TPangoFontFaces = packed record
    FamilyName: String;
    Faces: Array of String;
  end;
  PPangoFontFaces = Array of TPangoFontFaces;

var
  i: Integer;
  FontType: Integer;
  EnumLogFont: TEnumLogFontEx;
  Metric: TNewTextMetricEx;
  FontList: TStringList;
  Faces: PPangoFontFaces;

  AStyle: String;
  StylesCount: Integer;
  StylesList: TStringList;
  y: Integer;
  CharsetList: TByteList;
  CS: Byte;

  function Gtk2GetFontFamiliesDefault(var AList: TStringList): Integer;
  var
    i, j: Integer;
    AFamilies: PPPangoFontFamily;
    AFaces: PPPangoFontFace;
    ANumFaces: Integer;
    PContext: PPangoContext;
  begin
    AList.Clear;
    SetLength(Faces, 0);
    Result := -1;
    AFamilies := nil;

    PContext := gdk_pango_context_get;
    pango_context_list_families(PContext, @AFamilies, @Result);
    SetLength(Faces, Result);
    for i := 0 to Result - 1 do
    begin
      j := AList.Add(StrPas(pango_font_family_get_name(AFamilies[i])));
      AList.Objects[j] := TObject(PtrUInt(pango_font_family_is_monospace(AFamilies[i])));
      Faces[i].FamilyName := AList[j];
      AFaces := nil;
      pango_font_family_list_faces(AFamilies[i], @AFaces, @ANumFaces);
      SetLength(Faces[i].Faces, ANumFaces);
      for j := 0 to ANumFaces - 1 do
        Faces[i].Faces[j] := StrPas(pango_font_face_get_face_name(AFaces[j]));
      g_free(AFaces);
    end;
    g_free(AFamilies);
    g_object_unref(PContext);
  end;

  function Gtk2GetFontFamilies(var List: TStringList;
    const APitch: Byte;
    const AFamilyName: String;
    const {%H-}AWritingSystem: Byte): Integer;
  var
    StrLst: TStringList;
    NewList: TStringList;
    S: String;
    j: integer;
  begin
    Result := -1;
    StrLst := TStringList.Create;
    NewList := TStringList.Create;

    try
      Gtk2GetFontFamiliesDefault(StrLst);
      for j := 0 to StrLst.Count - 1 do
      begin
        S := StrLst[j];
        if APitch <> DEFAULT_PITCH then
        begin
          case APitch of
            FIXED_PITCH, MONO_FONT:
            begin
              if StrLst.Objects[j] <> nil then
                NewList.Add(S);
            end;
            VARIABLE_PITCH:
            begin
              if StrLst.Objects[j] = nil then
                NewList.Add(S);
            end;
          end;
        end else
          NewList.Add(S);
      end;

      if AFamilyName <> '' then
      begin
        for j := NewList.Count - 1 downto 0 do
        begin
          S := NewList[j];;
          if S <> AFamilyName then
            NewList.Delete(J);
        end;
      end;
      for j := 0 to NewList.Count - 1 do
      begin
        S := NewList[j];
        List.Add(S);
      end;
      Result := List.Count;
    finally
      StrLst.Free;
      NewList.Free;
    end;
  end;

  function GetStyleAt(AIndex: Integer): String;
  var
    S: String;
  begin
    Result := '';
    if (AIndex >= 0) and (AIndex < StylesList.Count) then
    begin
      S := StylesList[AIndex];
      Result := S;
    end;
  end;

  function FillLogFontA(const AIndex: Integer; var ALogFontA: TLogFontA;
    var {%H-}AMetric: TNewTextMetricEx; var {%H-}AFontType: Integer;
    out AStyle: String): Integer;
  var
    Font: PPangoFontDescription;
    FontStyle: TPangoStyle;
    FontWeight: TPangoWeight;
    S: String;
    i: Integer;
  begin
    S := FontList[AIndex];
    Font := pango_font_description_from_string(PChar(S));

    FontStyle := pango_font_description_get_style(Font);
    FontWeight := pango_font_description_get_weight(Font);

    ALogFontA.lfItalic := Byte(FontStyle = PANGO_STYLE_ITALIC);

    // keep newer pango compat to LCL
    if FontWeight = 380 {PANGO_WEIGHT_BOOK as of pango 1.24} then
      FontWeight := PANGO_WEIGHT_NORMAL
    else
    if FontWeight = 1000 {PANGO_WEIGHT_ULTRAHEAVY as of pango 1.24} then
      FontWeight := PANGO_WEIGHT_HEAVY;

    ALogFontA.lfWeight := FontWeight;

    ALogFontA.lfHeight := pango_font_description_get_size(Font);
    if not pango_font_description_get_size_is_absolute(Font) then
      ALogFontA.lfHeight := ALogFontA.lfHeight div PANGO_SCALE;

    // pango does not have underline and strikeout params for font
    // ALogFontA.lfUnderline := ;
    // ALogFontA.lfStrikeOut := ;

    StylesList.Clear;
    for i := High(Faces[AIndex].Faces) downto 0 do
      StylesList.Add(Faces[AIndex].Faces[i]);

    AStyle := '';
    Result := StylesList.Count;

    if StylesList.Count > 0  then
      AStyle := GetStyleAt(0);

    // current pango support in fpc is really poor, we cannot
    // get PangoScript since it's in pango >= 1.4
    // FillCharsetListForFont()
  end;

begin
  Result := 0;
  {$ifdef VerboseEnumFonts}
  WriteLn('[TGtk2WidgetSet.EnumFontFamiliesEx] Charset=',lpLogFont^.lfCharSet,
  ' face ',lpLogFont^.lfFaceName,' pitchAndFamily=',lpLogFont^.lfPitchAndFamily);
  {$endif}
  Result := 0;
  Metric.ntmentm.ntmAvgWidth := 0; // just to shutup compiler
  if (lpLogFont^.lfCharSet = DEFAULT_CHARSET) and
     (lpLogFont^.lfFaceName= '') and
     (lpLogFont^.lfPitchAndFamily = 0) then
  begin
    FontType := 0;
    FontList := TStringList.create;
    try
      if Gtk2GetFontFamiliesDefault(FontList) > 0 then
      begin
        for i := 0 to FontList.Count - 1 do
        begin
          EnumLogFont.elfLogFont.lfFaceName := FontList[i];
          Result := Callback(EnumLogFont, Metric, FontType, LParam);
        end;
      end;
    finally
      FontList.free;
    end;
  end else
  begin
    Result := 0;
    FontType := TRUETYPE_FONTTYPE;
    FontList := TStringList.Create;
    StylesList := TStringList.Create;
    CharsetList := TByteList.Create;
    for i := 0 to CharsetEncodingList.Count - 1 do
    begin
      CS := TCharSetEncodingRec(CharsetEncodingList.Items[i]^).CharSet;
      if CharsetList.IndexOf(CS) = -1 then
        CharsetList.Add(CS);
    end;
    try
      if Gtk2GetFontFamilies(FontList, lpLogFont^.lfPitchAndFamily,
        lpLogFont^.lfFaceName, lpLogFont^.lfCharSet) > 0 then
      begin
        for i := 0 to FontList.Count - 1 do
        begin
          EnumLogFont.elfLogFont.lfFaceName := FontList[i];
          EnumLogFont.elfLogFont.lfPitchAndFamily := lpLogFont^.lfPitchAndFamily;
          EnumLogFont.elfFullName := FontList[i];

          StylesCount := FillLogFontA(i, EnumLogFont.elfLogFont, Metric, FontType,
            AStyle);
          EnumLogFont.elfStyle := AStyle;

          if CharSetList.Count > 0 then
            EnumLogFont.elfLogFont.lfCharSet := CharsetList.Items[0];

          Result := Callback(EnumLogFont, Metric, FontType, LParam);
          for y := 1 to StylesCount - 1 do
          begin
            AStyle := GetStyleAt(y);
            EnumLogFont.elfStyle := AStyle;
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
          end;
          for y := 1 to CharSetList.Count - 1 do
          begin
            EnumLogFont.elfLogFont.lfCharSet := CharsetList.Items[y];
            Result := Callback(EnumLogFont, Metric, FontType, LParam);
          end;
        end;
      end;
    finally
      CharSetList.Free;
      StylesList.Free;
      FontList.Free;
    end;
  end;
end;
{$ENDIF}


{------------------------------------------------------------------------------
  Method:   Ellipse
  Params:   X1, Y1, X2, Y2
  Returns:  Nothing

  Use Ellipse to draw a filled circle or ellipse.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.Ellipse(DC: HDC; x1, y1, x2, y2: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  Left, Top, Width, Height: Integer;
  DCOrigin: TPoint;
begin
  Result := IsValidDC(DC);
  if not Result then Exit;

  if DevCtx.HasTransf then
    DevCtx.TransfRect(X1, Y1, X2, Y2);

  CalculateLeftTopWidthHeight(X1, Y1, X2, Y2, Left, Top, Width, Height);
  if (Width = 0) or (Height = 0) then Exit(True);
  // X2, Y2 is not part of the rectangle
  dec(Width);
  dec(Height);

  // first draw interior in brush color
  DCOrigin := DevCtx.Offset;

  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}

  if not DevCtx.IsNullBrush then
  begin
    DevCtx.SelectBrushProps;
    DevCtx.RemovePixbuf;
    gdk_draw_arc(DevCtx.Drawable, DevCtx.GC, 1,
                 Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height, 0, 360 shl 6);
  end;

  // Draw outline

  DevCtx.SelectPenProps;
  if (dcfPenSelected in DevCtx.Flags) then
  begin
    Result := True;
    if not DevCtx.IsNullPen then
    begin
      DevCtx.RemovePixbuf;
      gdk_draw_arc(DevCtx.Drawable, DevCtx.GC, 0,
                   Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height, 0, 360 shl 6);
    end;
  end
  else
    Result := False;

  {$IFDEF DebugGDKTraps}
  EndGDKErrorTrap;
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method: EqualRgn
  Params:  Rgn1: HRGN; Rgn2: HRGN
  Returns: True if the two regions are equal

  Checks the two specified regions to determine whether they are identical. The
  function considers two regions identical if they are equal in size and shape.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.EqualRgn(Rgn1: HRGN; Rgn2: HRGN): Boolean;
var
  AGdiObject: PGdiObject absolute Rgn1;
  BGdiObject: PGdiObject absolute Rgn2;
begin
  Result := IsValidGDIObject(Rgn1) and IsValidGDIObject(Rgn2);
  if Result then
    Result := gdk_region_equal(AGdiObject^.GDIRegionObject,
                               BGdiObject^.GDIRegionObject);
end;

{------------------------------------------------------------------------------
  Function: ExcludeClipRect
  Params:  dc: hdc; Left, Top, Right, Bottom : Integer
  Returns: integer

  Subtracts all intersecting points of the passed bounding rectangle
  (Left, Top, Right, Bottom) from the Current clipping region in the
  device context (dc).

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ExcludeClipRect(dc: hdc;
  Left, Top, Right, Bottom : Integer) : Integer;
begin
  Result := Inherited ExcludeClipRect(DC, Left, Top, Right, Bottom);
end;

function TGtk2WidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
  const lplb: TLogBrush; dwStyleCount: DWord; lpStyle: PDWord): HPEN;
var
  GObject: PGdiObject;
  i: integer;
begin
  GObject := NewGDIObject(gdiPen);
  GObject^.UnTransfPenWidth := 0;
  GObject^.IsExtPen := True;
  GObject^.GDIPenStyle := dwPenStyle;
  GObject^.GDIPenWidth := dwWidth;
  SetGDIColorRef(GObject^.GDIPenColor, lplb.lbColor);
  GObject^.GDIPenDashesCount := dwStyleCount;

  if dwStyleCount > 0 then
  begin
    GetMem(GObject^.GDIPenDashes, dwStyleCount * SizeOf(gint8));
    for i := 0 to dwStyleCount - 1 do
      GObject^.GDIPenDashes[i] := lpStyle[i];
  end;

  Result := HPEN({%H-}PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Function: ExtSelectClipRGN
  Params:  dc, RGN, Mode
  Returns: integer

  Combines the passed Region with the current clipping region in the device
  context (dc), using the specified mode.

  The Combine Mode can be one of the following:
      RGN_AND  : all points which are in both regions

      RGN_COPY : an exact copy of the source region, same as SelectClipRGN

      RGN_DIFF : all points which are in the Clipping Region but
                 not in the Source.(Clip - RGN)

      RGN_OR   : all points which are in either the Clip Region or
                 in the Source.(Clip + RGN)

      RGN_XOR  : all points which are in either the Clip Region
                 or in the Source, but not in both.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ExtSelectClipRGN(dc: hdc; rgn : hrgn;
  Mode : Longint) : Integer;
var
  Clip,
  Tmp : hRGN;
  X, Y : Longint;
begin
  Result := SIMPLEREGION;
  if not IsValidDC(DC) then
    Result := ERROR
  else with TGtkDeviceContext(DC) do
  begin
    //DebugLn('TGtk2WidgetSet.ExtSelectClipRGN A ClipRegValid=',dbgs(DCClipRegionValid(DC)),
    //  ' Mode=',dbgs(Mode),' RGN=',GDKRegionAsString(PGdiObject(RGN)^.GDIRegionObject));
    if ClipRegion = nil then
    begin
      // there is no clipping region in the DC
      case Mode of
        RGN_COPY:
          begin
            Result := RegionType({%H-}PGdiObject(RGN)^.GDIRegionObject);
            If Result <> ERROR then
              Result := SelectClipRGN(DC, RGN);
          end;
        RGN_OR,
        RGN_XOR,
        RGN_AND,
        RGN_DIFF:
          begin
            // get existing clip
            if Drawable=nil then
              Clip:=CreateEmptyRegion
            else begin
              GDK_Window_Get_Size(Drawable, @X, @Y);
              Clip := CreateRectRGN(-Offset.X, -Offset.Y, X - Offset.X, Y - Offset.Y);
            end;
            // create target clip
            Tmp := CreateEmptyRegion;
            // combine
            Result := CombineRGN(Tmp, Clip, RGN, Mode);
            // commit
            //DebugLn('TGtk2WidgetSet.ExtSelectClipRGN B ClipRegValid=',dbgs(ClipRegion),' TmpRGN=',GDKRegionAsString(PGdiObject(Tmp)^.GDIRegionObject));
            SelectClipRGN(DC, Tmp);
            // clean up
            DeleteObject(Clip);
            DeleteObject(Tmp);
          end;
        end;
      end
    else
      Result := inherited ExtSelectClipRGN(dc, rgn, mode);
  end;
end;

{------------------------------------------------------------------------------
  Function: ExtTextOut
  Params:  none
  Returns: Nothing

    gdk_drawable_get_size(pixmap, @Width, @Height);

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  
  LineStart, LineEnd, StrEnd: PChar;
  Width, Height: Integer;
  TopY, LineLen, LineHeight, SavedDC: Integer;
  TxtPt: TPoint;
  DCOrigin: TPoint;
  Foreground, BackgroundColor: PGDKColor;
  CurDx: PInteger;
  CurStr: PChar;
  R: TRect;

  procedure DoTextOut(X,Y : Integer; Str: Pchar; CurCount: Integer);
  var
    CurScreenX: LongInt;
    CharLen: LongInt;
  begin
    if (Dx <> nil) then
    begin
      CurScreenX := X;
      while CurCount > 0 do
      begin
        CharLen := UTF8CodepointSize(CurStr);
        DevCtx.DrawTextWithColors(CurStr, CharLen, CurScreenX, Y, Foreground, BackgroundColor);
        inc(CurScreenX, CurDx^);
        inc(CurDx);
        inc(CurStr, CharLen);
        dec(CurCount, CharLen);
      end;
    end
    else
      DevCtx.DrawTextWithColors(Str, Count, X, Y, Foreground, BackgroundColor);
  end;

begin
  //DebugLn(['TGtk2WidgetSet.ExtTextOut X=',X,' Y=',Y,' Str="',copy(Str,1,Count),'" Count=',Count,' DX=',dbgs(DX)]);
  //DebugLn(Format('trace:> [TGtk2WidgetSet.ExtTextOut] DC:0x%x, X:%d, Y:%d, Options:%d, Str:''%s'', Count: %d', [DC, X, Y, Options, Str, Count]));
  Result := IsValidDC(DC);
  if not Result then Exit;
  
  if DevCtx.GC <> nil then; // create GC

  if ((Options and (ETO_OPAQUE + ETO_CLIPPED)) <> 0) and (Rect = nil) then
  begin
    R := RectFromGdkRect(DevCtx.ClipRect);
    OffsetRect(R, -R.Left, -R.Top);
    OffsetRect(R, X, Y);
    DrawText(DC, Str, Count, R, DT_SINGLELINE or DT_CALCRECT);
    Rect := @R;
  end;

  BackgroundColor := nil;

  // to reduce flickering calculate first and then paint

  DCOrigin := DevCtx.Offset;

  if (Options and ETO_CLIPPED) <> 0 then
  begin
    SavedDC := SaveDC(DC);
    IntersectClipRect(DC, Rect^.Left, Rect^.Top, Rect^.Right, Rect^.Bottom);
  end;

  if DevCtx.HasTransf then
  begin
    if Assigned(Rect) then
      Rect^ := DevCtx.TransfRectIndirect(Rect^);
    DevCtx.TransfPoint(X, Y);
  end;

  LineLen := FindLineLen(Str,Count);
  TopY := Y;
  UpdateDCTextMetric(DevCtx);
  TxtPt.X := X + DCOrigin.X;
  LineHeight := DevCtx.DCTextMetric.TextMetric.tmHeight;
  TxtPt.Y := TopY + DCOrigin.Y;

  DevCtx.SelectedColors := dcscCustom;

  if ((Options and ETO_OPAQUE) <> 0) then
  begin
    Width := Rect^.Right - Rect^.Left;
    Height := Rect^.Bottom - Rect^.Top;
    EnsureGCColor(DC, dccCurrentBackColor, True, False);
    DevCtx.RemovePixbuf;
    gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 1,
                       Rect^.Left+DCOrigin.X, Rect^.Top+DCOrigin.Y,
                       Width, Height);
  end;


  if (DevCtx.BkMode = OPAQUE) then
  begin
    AllocGDIColor(DC, @DevCtx.CurrentBackColor);
    BackGroundColor := @DevCtx.CurrentBackColor.Color;
  end;

  EnsureGCColor(DC, dccCurrentTextColor, True, False);
  Foreground := nil;//StyleForegroundColor(CurrentTextColor.ColorRef, nil);

  CurDx:=Dx;
  CurStr:=Str;
  LineStart:=Str;
  if LineLen < 0 then
  begin
    LineLen:=Count;
    if Count> 0 then
      DoTextOut(TxtPt.X, TxtPt.Y, LineStart, LineLen);
  end else
  begin  //write multiple lines
    StrEnd := Str + Count;
    while LineStart < StrEnd do
    begin
      LineEnd := LineStart + LineLen;
      if LineLen>0 then
        DoTextOut(TxtPt.X, TxtPt.Y, LineStart, LineLen);
      inc(TxtPt.Y, LineHeight);
      //writeln('TGtk2WidgetSet.ExtTextOut ',LineHeight,' ',DevCtx.DCTextMetric.TextMetric.tmAscent,' ',DevCtx.DCTextMetric.TextMetric.tmDescent);
      LineStart := LineEnd + 1; // skip #13
      if (LineStart<StrEnd) and (LineStart^ in [#10,#13])
      and (LineStart^ <> LineEnd^) then
        inc(LineStart); // skip #10
      Count := StrEnd - LineStart;
      LineLen := FindLineLen(LineStart, Count);
      if LineLen < 0 then
        LineLen := Count;
    end;
  end;

  if (Options and ETO_CLIPPED) <> 0 then
    RestoreDC(DC, SavedDC);
  Result := True;
  //DebugLn(Format('trace:< [TGtk2WidgetSet.ExtTextOut] DC:0x%x, X:%d, Y:%d, Options:%d, Str:''%s'', Count: %d', [DC, X, Y, Options, Str, Count]));
end;

{------------------------------------------------------------------------------
  Function: FillRect
  Params: none
  Returns: Nothing

  The FillRect function fills a rectangle by using the specified brush.
  This function includes the left and top borders, but excludes the right and
  bottom borders of the rectangle.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH): Boolean;
var
  TempBr: HBrush;
begin
  Result := IsValidDC(DC) and IsValidGDIObject(Brush);
  if not Result or IsRectEmpty(Rect) then
    Exit;
  if ({%H-}PGdiObject(Brush)^.GDIBrushFill = GDK_TILED) and (TGtkDeviceContext(DC).BkMode = OPAQUE) then
  begin
    // fill a rectangle with a solid back color first
    TempBr := CreateSolidBrush(TGtkDeviceContext(DC).CurrentBackColor.ColorRef);
    TGtkDeviceContext(DC).FillRect(Rect, TempBr, True);
    DeleteObject(TempBr);
  end;
  Result := TGtkDeviceContext(DC).FillRect(Rect, Brush, True);
  //DebugLn(Format('trace:< [TGtk2WidgetSet.FillRect] DC:0x%x; Rect: ((%d,%d)(%d,%d)); brush: %x', [Integer(DC), Rect.left, rect.top, rect.right, rect.bottom, brush]));
end;

{------------------------------------------------------------------------------
  Function: FillRgn
  Params:  DC: HDC; RegionHnd: HRGN; hbr: HBRUSH
  Returns: True if the function succeeds

  Fills a region by using the specified brush
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool;
var
  GtkDC: Integer;
  OldRgn: PGdkRegion;
  DevCtx: TGtkDeviceContext absolute DC;
  ARect: TRect;
  CRect : TGDKRectangle;
  hasClipping: Boolean;
begin

  Result := IsValidDC(DC) and IsValidGDIObject(hbr) and IsValidGDIObject(RegionHnd);
  if not Result then Exit;
  GtkDC := SaveDC(DC);
  if (DevCtx.ClipRegion <> nil) and (DevCtx.ClipRegion^.GDIRegionObject <> nil) then
    OldRgn := gdk_region_copy(DevCtx.ClipRegion^.GDIRegionObject)
  else
    OldRgn := nil;
  hasClipping := Assigned(OldRgn);
  try
    if SelectClipRGN(DC, RegionHnd) <> ERROR then
    begin
      gdk_region_get_clipbox({%H-}PGDIObject(RegionHnd)^.GDIRegionObject, @CRect);
      ARect := RectFromGdkRect(CRect);
      DevCtx.FillRect(ARect, hbr, True);
      // revert clip (whatever it is - null or valid region)
      SelectClipRGN(DC, {%H-}HRGN(OldRgn));
      Result := True;
    end;
  finally
    if hasClipping then
      gdk_region_destroy(OldRgn);
    RestoreDC(DC, GtkDC);
  end;
end;

{------------------------------------------------------------------------------
  Function: Frame3d
  Params: -
  Returns: Nothing

  Draws a 3d border in GTK native style.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.Frame3d(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  TheStyle: PGtkStyle;
  i, AWidth: integer;
  P: TPoint;
  gc1, gc2: PGdkGC;
  OldGC1Values, OldGC2Values: TGdkGCValues;
begin
  Result := IsValidDC(DC);
  if not Result or (FrameWidth = 0) then Exit;
  TheStyle := gtk_widget_get_style(GetStyleWidget(lgsButton));
  if TheStyle = nil then exit;

  if DevCtx.HasTransf then
  begin
    ARect := DevCtx.TransfRectIndirect(ARect);
    DevCtx.TransfNormalize(ARect.Left, ARect.Right);
    DevCtx.TransfNormalize(ARect.Top, ARect.Bottom);
    P.X := FrameWidth;
    P.Y := FrameWidth;
    P := DevCtx.TransfExtentIndirect(P);
    AWidth := Abs(Min(P.X, P.Y));
  end else
    AWidth := FrameWidth;

  case Style of
    bvNone:
      begin
        InflateRect(ARect, -AWidth, -AWidth);
        Exit;
      end;
    bvLowered:
      begin
        gc1 := TheStyle^.dark_gc[GTK_STATE_NORMAL];
        gc2 := TheStyle^.light_gc[GTK_STATE_NORMAL];
      end;
    bvRaised:
     begin
        gc1 := TheStyle^.light_gc[GTK_STATE_NORMAL];
        gc2 := TheStyle^.dark_gc[GTK_STATE_NORMAL];
     end;
    bvSpace:
     begin
        InflateRect(ARect, -AWidth, -AWidth);
        Exit;
     end;
  end;

  with DevCtx do
  begin
    if WithChildWindows then
    begin
      gdk_gc_get_values(gc1, @OldGC1Values);
      gdk_gc_get_values(gc2, @OldGC2Values);
      gdk_gc_set_subwindow(gc1, GDK_INCLUDE_INFERIORS);
      gdk_gc_set_subwindow(gc2, GDK_INCLUDE_INFERIORS);
    end;

    DevCtx.RemovePixbuf;
    for i := 1 to AWidth do
    begin
      gdk_draw_line(Drawable, gc1, ARect.Left + Offset.x, ARect.Top + Offset.y,
        ARect.Right + Offset.x - 2, ARect.Top + Offset.y);
      gdk_draw_line(Drawable, gc1, ARect.Left + Offset.x, ARect.Top + Offset.y,
        ARect.Left + Offset.x, ARect.Bottom + Offset.y - 2);
      gdk_draw_line(Drawable, gc2, ARect.Left + Offset.x, ARect.Bottom + Offset.y - 1,
        ARect.Right + Offset.x - 1, ARect.Bottom + Offset.y - 1);
      gdk_draw_line(Drawable, gc2, ARect.Right + Offset.x - 1, ARect.Top + Offset.y,
        ARect.Right + Offset.x - 1, ARect.Bottom + Offset.y - 1);
      // inflate the rectangle (! ARect will be returned to the user with this)
      InflateRect(ARect, -1, -1);
    end;

    if WithChildWindows then
    begin
      gdk_gc_set_subwindow(gc1, OldGC1Values.subwindow_mode);
      gdk_gc_set_subwindow(gc2, OldGC2Values.subwindow_mode);
    end;

  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.FrameRect(DC: HDC; const ARect: TRect;
    hBr: HBRUSH): Integer;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.FrameRect(DC: HDC; const ARect: TRect;
  hBr: HBRUSH): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
  DCOrigin: TPoint;
  R: TRect;
  OldBrush: HBrush;
begin
  Result:=0;
  if not IsValidDC(DC) then Exit;
  if not IsValidGDIObject(hBr) then Exit;

  // Draw outline
  Result := 1;
  if {%H-}PGdiObject(hBr)^.IsNullBrush then Exit;

  OldBrush := SelectObject(DC, hBr);
  DevCtx.SelectedColors := dcscCustom;
  EnsureGCColor(DC, dccGDIBrushColor, True, False);//Brush Color

  R := ARect;
  LPtoDP(DC, R, 2);

  DCOrigin := DevCtx.Offset;
  DevCtx.RemovePixbuf;
  gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 0,
                     R.Left + DCOrigin.X, R.Top + DCOrigin.Y,
                     R.Right-R.Left-1, R.Bottom-R.Top-1);
  SelectObject(DC, OldBrush);
end;

{------------------------------------------------------------------------------
  Function: GetActiveWindow
  Params: none
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetActiveWindow : HWND;
var
  TopList, List: PGList;
  Widget: PGTKWidget;
  Window: PGTKWindow;
begin
  // Default to 0
  Result := 0;

  TopList := gdk_window_get_toplevels;
  List := TopList;
  while List <> nil do
  begin
    if (List^.Data <> nil) then
    begin
      gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
      if GDK_IS_WINDOW(PGDKWindow(List^.Data)) and
        gdk_window_is_visible(PGDKWindow(List^.Data)) and
        gtk_is_window(Window) then
      begin
        Widget := Window^.focus_widget;
        if Widget=nil then Widget:=PGtkWidget(Window);
        //DebugLn('TGtk2WidgetSet.GetActiveWindow Window=',GetWidgetDebugReport(PgtkWidget(Window)),' Window^.focus_widget= ',GetWidgetDebugReport(Window^.focus_widget));

        if (Widget <> nil) and gtk_widget_has_focus(Widget) then
        begin
          // return the window
          Result := HWND({%H-}PtrUInt(GetMainWidget(PGtkWidget(Window))));
          //DebugLn('TGtk2WidgetSet.GetActiveWindow Result=',GetWidgetDebugReport(PgtkWidget(Result)));
          Break;
        end;
      end;
    end;
    list := g_list_next(list);
  end;
  if TopList <> nil
  then g_list_free(TopList);
end;

function TGtk2WidgetSet.GetForegroundWindow: HWND;
begin
  Result:=0;
  {$IFDEF HASX}
  Result:=X11GetActiveWindow;
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Function: GetDIBits
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan, NumScans: UINT;
  Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT): Integer;
begin
  Result := 0;
  if IsValidGDIObject(Bitmap)
  then begin
    case {%H-}PGDIObject(Bitmap)^.GDIType of
      gdiBitmap:
        Result := InternalGetDIBits(DC, Bitmap, StartScan, NumScans, -1, Bits,
                                      BitInfo, Usage, True);
      else
        DebugLn('WARNING: [TGtk2WidgetSet.GetDIBits] not a Bitmap!');
    end;
  end
  else
    DebugLn('WARNING: [TGtk2WidgetSet.GetDIBits] invalid Bitmap!');
end;

{------------------------------------------------------------------------------
  Function: GetBitmapBits
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetBitmapBits(Bitmap: HBITMAP; Count: Longint;  Bits: Pointer): Longint;
var
  BitInfo : tagBitmapInfo;
begin
  Result := 0;
  if IsValidGDIObject(Bitmap)
  then begin
    case {%H-}PGDIObject(Bitmap)^.GDIType of
      gdiBitmap:
        Result := InternalGetDIBits(0, Bitmap, 0, 0, Count, Bits, BitInfo, 0, False);
      else
        DebugLn('WARNING: [TGtk2WidgetSet.GetBitmapBits] not a Bitmap!');
    end;
  end
  else
    DebugLn('WARNING: [TGtk2WidgetSet.GetBitmapBits] invalid Bitmap!');
end;

function TGtk2WidgetSet.GetBkColor(DC: HDC): TColorRef;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := CLR_INVALID;
  if IsValidDC(DC) then
    Result := DevCtx.CurrentBackColor.ColorRef;
end;

{------------------------------------------------------------------------------
  Function: GetCapture
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCapture: HWND;
var
  Widget: PGtkWidget;
  AWindow: PGtkWindow;
  IsModal: gboolean;
begin
  Widget:=gtk_grab_get_current;
  // for the LCL a modal window is not capturing
  if Widget<>nil then begin
    if GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then begin
      AWindow:=PGtkWindow(Widget);
      IsModal:=gtk_window_get_modal(AWindow);
      if IsModal then
        Widget:=nil;
    end;
  end;
  Result := HWnd({%H-}PtrUInt(Widget));
end;

{------------------------------------------------------------------------------
  Function: GetCaretPos
  Params:  lpPoint: The caretposition
  Returns: True if succesful

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
var
  //FocusObject: PGTKObject;
  modmask : TGDKModifierType;
begin
  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}
  gdk_window_get_pointer(nil,@lpPoint.X,@lpPoint.y,@modmask);
  {$IFDEF DebugGDKTraps}
  EndGDKErrorTrap;
  {$ENDIF}
  Result := True;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetCaretRespondToFocus(handle: HWND;
    var ShowHideOnFocus: boolean): Boolean;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCaretRespondToFocus(handle: HWND;
  var ShowHideOnFocus: boolean): Boolean;
begin
  if handle<>0 then begin
    if gtk_type_is_a({%H-}g_object_type({%H-}PGTKObject(handle)), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_GetCaretRespondToFocus({%H-}PGTKAPIWidget(handle),
        ShowHideOnFocus);
      Result:=true;
    end
    else begin
      Result := False;
    end;
  end else
    Result:=false;
end;

{------------------------------------------------------------------------------
  Function: GetCharABCWidths        pbd
  Params:  Don't care yet
  Returns: False so that the font cache in the newest mwEdit will use
           TextMetrics info which is working already
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCharABCWidths(DC: HDC; p2, p3: UINT;
  const ABCStructs): Boolean;
begin
  Result := False;
end;

{------------------------------------------------------------------------------
  Function: GetClientBounds
  Params: handle:
          Result:
  Returns: true on success

  Returns the client bounds of a control. The client bounds is the rectangle of
  the inner area of a control, where the child controls are visible. The
  coordinates are relative to the control's left and top.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetClientBounds(handle : HWND; var ARect : TRect) : Boolean;
var
  Widget, ClientWidget: PGtkWidget;
  CurGDKWindow: PGdkWindow;
  ClientOrigin: TPoint;
  ClientWindow, MainWindow: PGdkWindow;
begin
  Result := False;
  if Handle = 0 then Exit;
  Widget := {%H-}pgtkwidget(Handle);
  ClientWidget := GetFixedWidget(Widget);
  if (ClientWidget <> Widget) then begin
    ClientWindow:=GetControlWindow(ClientWidget);
    MainWindow:=GetControlWindow(Widget);
    if MainWindow<>ClientWindow then begin
      // widget and client are on different gdk windows
      if (GTK_WIDGET_NO_WINDOW(ClientWidget)) then begin
        // ClientWidget is a sub widget
        ARect.Left:=ClientWidget^.allocation.x;
        ARect.Top:=ClientWidget^.allocation.y;
      end else begin
        // ClientWidget owns the gdkwindow
        ARect.Left:=0;
        ARect.Top:=0;
      end;
      CurGDKWindow:=ClientWindow;
      while (CurGDKWindow<>MainWindow) do
      begin
        if not GDK_IS_WINDOW(CurGDKWindow) then
          break;
        gdk_window_get_position(CurGDKWindow,@ClientOrigin.x,@ClientOrigin.y);
        inc(ARect.Left,ClientOrigin.x);
        inc(ARect.Top,ClientOrigin.y);
        CurGDKWindow:=gdk_window_get_parent(CurGDKWindow);
      end;
      if GTK_WIDGET_NO_WINDOW(Widget) then begin
        // Widget is a sub widget
        dec(ARect.Left,Widget^.allocation.x);
        dec(ARect.Top,Widget^.allocation.y);
      end;
      ARect.Right:=ARect.Left+ClientWidget^.Allocation.Width;
      ARect.Bottom:=ARect.Top+ClientWidget^.Allocation.Height;

      Result:=true;
    end else if MainWindow<>nil then begin
      // both are on the same gdkwindow
      ARect.Left:=ClientWidget^.allocation.X-Widget^.allocation.X;
      ARect.Top:=ClientWidget^.allocation.Y-Widget^.allocation.Y;
      ARect.Right:=ARect.Left+ClientWidget^.allocation.Width;
      ARect.Bottom:=ARect.Top+ClientWidget^.allocation.Height;
      Result:=true;
    end;
  end;
  if not Result then begin
    with Widget^.Allocation do
      ARect := Rect(0,0,Width,Height);
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  Function: GetClientRect
  Params: handle:
          Result:
  Returns: true on success

  Returns the client rectangle of a control. Left and Top are always 0.
  The client rectangle is the size of the inner area of a control, where the
  child controls are visible.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetClientRect(handle : HWND; var ARect : TRect) : Boolean;
begin
  Result := false;
  if Handle = 0 then Exit;
  ARect := GetWidgetClientRect({%H-}PGtkWidget(Handle));
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetClipBox
  Params: dc, lprect
  Returns: Integer

  Returns the smallest rectangle which includes the entire current
  Clipping Region, or if no Clipping Region is set, the current
  dimensions of the Drawable.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetClipBox(DC : hDC; lpRect : PRect) : Longint;
var
  DevCtx: TGtkDeviceContext absolute DC;
  
  CRect : TGDKRectangle;
  X, Y : Longint;
  DCOrigin: Tpoint;
begin
  // set default values
  Result := SIMPLEREGION;
  if lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);

  if not IsValidDC(DC)
  then begin
    Result := ERROR;
    Exit;
  end;
  
  DCOrigin := DevCtx.Offset;
  if DevCtx.ClipRegion = nil then
  begin
    if (DevCtx.PaintRectangle.Left<>0)
    or (DevCtx.PaintRectangle.Top<>0)
    or (DevCtx.PaintRectangle.Right<>0)
    or (DevCtx.PaintRectangle.Bottom<>0) then
      lpRect^ := DevCtx.PaintRectangle
    else
    begin
      gdk_window_get_size(DevCtx.Drawable, @X, @Y);
      lpRect^ := Rect(0,0,X,Y);
    end;
    Result := SIMPLEREGION;
  end
  else
  begin
    Result := RegionType(DevCtx.ClipRegion^.GDIRegionObject);
    gdk_region_get_clipbox(DevCtx.ClipRegion^.GDIRegionObject, @CRect);
    lpRect^.Left   := CRect.X;
    lpRect^.Top    := CRect.Y;
    lpRect^.Right  := lpRect^.Left + CRect.Width;
    lpRect^.Bottom := lpRect^.Top + CRect.Height;
  end;
  DPtoLP(DC, lpRect^, 2);
  OffsetRect(lpRect^, -DCOrigin.X, -DCOrigin.Y);
end;

{------------------------------------------------------------------------------
  Function: GetRGNBox
  Params: rgn, lprect
  Returns: Integer

  Returns the smallest rectangle which includes the entire passed
  Region, if lprect is null then just returns RegionType.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetRgnBox(RGN : HRGN; lpRect : PRect) : Longint;
var
  ClipR : TGDKRectangle;
begin
  Result := SIMPLEREGION;
  If lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);
  If Not IsValidGDIObject(RGN) then
    Result := ERROR
  else begin
    Result := RegionType({%H-}PGDIObject(RGN)^.GDIRegionObject);
    If lpRect <> nil then begin
      gdk_region_get_clipbox({%H-}PGDIObject(RGN)^.GDIRegionObject,
        @ClipR);
      With lpRect^ do begin
        Left   := ClipR.X;
        Top    := ClipR.Y;
        Right  := ClipR.X + ClipR.Width;
        Bottom := ClipR.Y + ClipR.Height;
      end;
    end;
  end;
end;

function TGtk2WidgetSet.GetROP2(DC: HDC): Integer;
begin
  if IsValidDC(DC)
  then Result := TGtkDeviceContext(DC).ROP2
  else Result := 0;
end;

{------------------------------------------------------------------------------
  Function: GetClipRGN
  Params: dc, rgn
  Returns: Integer

  Returns a copy of the current Clipping Region.

  The result can be one of the following constants
     0 = no clipping set
     1 = ok
    -1 = error
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetClipRGN(DC: hDC; RGN: hRGN): Longint;
var
  DCOrigin: TPoint;
  ClipRegionWithDCOffset: PGdkRegion;
  CurRegionObject: PGdkRegion;
  ARect: TRect;
begin
  Result := SIMPLEREGION;
  If (not IsValidDC(DC)) then
    Result := ERROR
  else
  if Not IsValidGDIObject(RGN) then
  begin
    Result := ERROR;
    DebugLn('WARNING: [TGtk2WidgetSet.GetClipRGN] Invalid HRGN');
  end
  else
  if Assigned(TGtkDeviceContext(DC).ClipRegion) and
    not IsValidGDIObject(HGDIOBJ({%H-}PtrUInt(TGtkDeviceContext(DC).ClipRegion))) then
    Result := ERROR
  else with TGtkDeviceContext(DC) do
  begin
    CurRegionObject := nil;
    if Assigned(ClipRegion) then
      CurRegionObject := ClipRegion^.GDIRegionObject;
    ARect := Rect(0, 0, 0, 0);
    //debugln(['TGtk2WidgetSet.GetClipRGN ',GetWidgetDebugReport(Widget),' CurRegionObject=',Assigned(CurRegionObject),' DC=',dbgs(DC)]);

    if Assigned(CurRegionObject) then begin
      // create a copy of the current clipregion
      ClipRegionWithDCOffset := gdk_region_copy(CurRegionObject);
      // move it to the DC offset
      // Example: if the ClipRegion is at 10,10 and the DCOrigin is at 10,10,
      //          then the ClipRegion must be moved to 0,0
      DCOrigin := Offset;
      gdk_region_offset(ClipRegionWithDCOffset, -DCOrigin.x, -DCOrigin.Y);
    end
    else
    begin
      // create a default clipregion
      GetClipBox(DC, @ARect);
      LPtoDP(DC, ARect, 2);
      ClipRegionWithDCOffset := CreateRectGDKRegion(ARect);
    end;

    // free the old region in RGN
    if Assigned({%H-}PGdiObject(RGN)^.GDIRegionObject) then
      gdk_region_destroy({%H-}PGdiObject(RGN)^.GDIRegionObject);
    // set the new region in RGN
    {%H-}PGdiObject(RGN)^.GDIRegionObject := ClipRegionWithDCOffset;

    Result := RegionType(ClipRegionWithDCOffset);
    //DebugLn('TGtk2WidgetSet.GetClipRGN B DC=',DbgS(DC),
    //  ' DCOrigin=',dbgs(DCOrigin),' RGN=',GDKRegionAsString(ClipRegionWithDCOffset),' Result=',dbgs(Result));
    If Result = NULLREGION then
      Result := 0
    else If Result <> ERROR then
      Result := 1;
  end;
  If Result = ERROR then
    Result := -1;
end;

{------------------------------------------------------------------------------
  Function: GetCmdLineParamDescForInterface
  Params: none
  Returns: ansistring

  Returns a description of the command line parameters, that are understood by
  the interface.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCmdLineParamDescForInterface: string;
  function b(const s: string): string;
  begin
    Result:=BreakString(s,75,22)+LineEnding+LineEnding;
  end;

begin
  Result:=
     b(rsgtkOptionNoTransient)
    +b(rsgtkOptionModule)
    +b(rsgOptionFatalWarnings)
    +b(rsgtkOptionDebug)
    +b(rsgtkOptionNoDebug)
    +b(rsgdkOptionDebug)
    +b(rsgdkOptionNoDebug)
    +b(rsgtkOptionDisplay)
    +b(rsgtkOptionSync)
    +b(rsgtkOptionNoXshm)
    +b(rsgtkOptionName)
    +b(rsgtkOptionClass)
    +b(rsqtOptionDisableAccurateFrame);
end;

{------------------------------------------------------------------------------
  Method: GetCurrentObject
  Params:
    DC - A handle to the DC
    uObjectType - The object type to be queried
  Returns: If the function succeeds, the return value is a handle to the specified object.
    If the function fails, the return value is NULL.
 ------------------------------------------------------------------------------}

function TGtk2WidgetSet.GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ;
var
  Gtk2DC: TGtkDeviceContext absolute DC;
begin
  Result := 0;
  if not GTK2WidgetSet.IsValidDC(DC) then
    Exit;
  case uObjectType of
    OBJ_BITMAP: Result := {%H-}HGDIOBJ(Gtk2DC.CurrentBitmap);
    OBJ_BRUSH: Result := {%H-}HGDIOBJ(Gtk2DC.CurrentBrush);
    OBJ_FONT: Result := {%H-}HGDIOBJ(Gtk2DC.CurrentFont);
    OBJ_PEN: Result := {%H-}HGDIOBJ(Gtk2DC.CurrentPen);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetCursorPos
  Params:  lpPoint: The cursorposition
  Returns: True if succesful

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetCursorPos(var lpPoint: TPoint ): Boolean;
begin
  gdk_display_get_pointer(gdk_display_get_default(), nil, @lpPoint.X, @lpPoint.Y, nil);
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: GetDC
  Params:  none
  Returns: Nothing

  hWnd is any widget.
  The DC will be created for the client area and without the child areas
  (they are clipped away). Child areas are all child gdkwindows
  (e.g. not TControls).
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDC(hWnd: HWND): HDC;
begin
  Result:=CreateDCForWidget({%H-}PGtkWidget(hWnd),nil,false);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
var
  Visual: PGdkVisual;

  function GetVisual: boolean;
  begin
    Visual:=nil;
    with TGtkDeviceContext(DC) do begin
      If Drawable <> nil then
        Visual:=gdk_window_get_visual(PGdkWindow(Drawable));
      if Visual = nil then
        Visual := GDK_Visual_Get_System;
    end;
    Result:=Visual<>nil;
  end;

begin
  Result := -1;
  If DC = 0 then begin
    DC := GetDC(0);
    If DC = 0 then
      exit;
    Result := GetDeviceCaps(DC, Index);
    ReleaseDC(0, DC);
    exit;
  end;
  if not IsValidDC(DC) then exit;
  with TGtkDeviceContext(DC) do
  Case Index of
  HORZRES : { Horizontal width in pixels }
    If Drawable = nil then
      Result := GetSystemMetrics(SM_CXSCREEN)
    else
      gdk_drawable_get_size(Drawable, @Result, nil);

  VERTRES : { Vertical height in pixels }
    If Drawable = nil then
      Result := GetSystemMetrics(SM_CYSCREEN)
    else
      gdk_drawable_get_size(Drawable, nil, @Result);

  BITSPIXEL : { Number of used bits per pixel = depth }
    If Drawable = nil then
      Result := GDK_Visual_Get_System^.Depth
    else
      Result := gdk_drawable_get_depth(Drawable);

  PLANES : { Number of planes }
    // ToDo
    Result := 1;

  //For Size in MM, MM = (Pixels*100)/(PPI*25.4)

  HORZSIZE : { Horizontal size in millimeters }
    Result := RoundToInt((GetDeviceCaps(DC, HORZRES) * 100) /
                    (GetDeviceCaps(DC, LOGPIXELSX) * 25.4));

  VERTSIZE : { Vertical size in millimeters }
    Result := RoundToInt((GetDeviceCaps(DC, VERTRES) * 100) /
                    (GetDeviceCaps(DC, LOGPIXELSY) * 25.4));

  //So long as gdk_screen_width_mm is acurate, these should be
  //acurate for Screen GDKDrawables. Once we get Metafiles
  //we will also have to add internal support for Papersizes etc..

  LOGPIXELSX : { Logical pixels per inch in X }
    Result := ScreenInfo.PixelsPerInchX;

  LOGPIXELSY : { Logical pixels per inch in Y }
    Result := ScreenInfo.PixelsPerInchY;

  SIZEPALETTE: { number of entries in color palette }
    if GetVisual then
      Result:=Visual^.colormap_size
    else
      Result:=0;

  NUMRESERVED: { number of reserverd colors in color palette }
    Result:=0;

  else
    DebugLn('TGtk2WidgetSet.GetDeviceCaps not supported: Type=',dbgs(Index));
  end;
end;

{------------------------------------------------------------------------------
  function GetDeviceSize(DC: HDC; var p: TPoint): boolean;

  Retrieves the width and height of the device context in pixels.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDeviceSize(DC: HDC; var p: TPoint): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if not IsValidDC(DC) then Exit(False);

  if DevCtx.Drawable <> nil
  then begin
    P := Point(0,0);
    gdk_window_get_size(PGdkWindow(DevCtx.Drawable), @P.X, @P.Y);
    Exit(True);
  end;
  
  {$IFDEF RaiseExceptionOnNilPointers}
  RaiseGDBException('TGtk2WidgetSet.GetDeviceSize Window=nil');
  {$ENDIF}
  DebugLn('TGtk2WidgetSet.GetDeviceSize:', ' WARNING: DC ',DbgS(DC),' without gdkwindow.',
          ' Widget=',DbgS(DevCtx.Widget));
  Result := False;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
    WindowHandle: HWND; var OriginDiff: TPoint): boolean;

  Returns the origin of PaintDC relative to the window handle.
  Example:
    A PaintDC of a TButton at 20,10 with a DC Offset of 0,0 on a form and the
    WindowHandle is the form.
    Then OriginDiff is the difference between the Forms client origin
    and the PaintDC: 20,10.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
  WindowHandle: HWND; var OriginDiff: TPoint): boolean;

var
  DevCtx: TGtkDeviceContext absolute PaintDC;

  DCOrigin: TPoint;
  DCScreenOrigin: TPoint;
  WindowScreenOrigin: TPoint;
  Widget: PGtkWidget;
  DCWindow: PGdkWindow;
begin
  Result := false;
  OriginDiff := Point(0, 0);
  if not IsValidDC(PaintDC) then exit;
  
  DCOrigin := DevCtx.Offset;

  DCWindow := PGdkWindow(DevCtx.Drawable);
  gdk_window_get_origin(DCWindow, @(DCScreenOrigin.X), @(DCScreenOrigin.Y));
  inc(DCScreenOrigin.X, DCOrigin.X);
  inc(DCScreenOrigin.Y, DCOrigin.Y);

  Widget := GetFixedWidget({%H-}PGtkWidget(WindowHandle));
  if Widget = nil then
    Widget := {%H-}PGtkWidget(WindowHandle);
  
  gdk_window_get_origin(PGdkWindow(Widget^.window), @(WindowScreenOrigin.X), @(WindowScreenOrigin.Y));

  OriginDiff.X := DCScreenOrigin.X - WindowScreenOrigin.X;
  OriginDiff.Y := DCScreenOrigin.Y - WindowScreenOrigin.Y;
  Result := True;
  //DebugLn(['TGtk2WidgetSet.GetDCOriginRelativeToWindow DCScreenOrigin=',dbgs(DCScreenOrigin),' WindowScreenOrigin=',dbgs(WindowScreenOrigin),' OriginDiff=',dbgs(OriginDiff)]);
end;

{------------------------------------------------------------------------------
  Function: GetDesignerDC
  Params:  none
  Returns: Nothing

  WindowHandle is any widget.
  The DC will be created for the client area including the child areas.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetDesignerDC(WindowHandle: HWND): HDC;
begin
  //DebugLn('TGtk2WidgetSet.GetDesignerDC A');
  Result:=CreateDCForWidget({%H-}PGtkWidget(WindowHandle),nil,true);
end;

{------------------------------------------------------------------------------
  Function: GetFocus
  Params:  none
  Returns: The handle of the window with focus

  The GetFocus function retrieves the handle of the window that has the focus.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetFocus: HWND;
var
  TopList, List: PGList;
  Widget: PGTKWidget;
  Window: PGTKWindow;
  Info: PWidgetInfo;
begin
  // Default to 0
  Result := 0;

  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}

  TopList := gdk_window_get_toplevels;
  List := TopList;
  while List <> nil do
  begin
    if (List^.Data <> nil)
    then begin
      gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
      
      if gtk_is_window(Window)
      then begin
        Widget := Window^.focus_widget;
        {$IFDEF DebugLCLComponents}
        if DebugGtkWidgets.IsDestroyed(Widget) then begin
          DebugLn(['TGtk2WidgetSet.GetFocus Window^.focus_widget was already destroyed:']);
          DebugLn(DebugGtkWidgets.GetInfo(Widget,true));
        end;
        {$ENDIF}
        
        if (Widget <> nil) and gtk_widget_has_focus(Widget)
        then begin
          Info:=GetWidgetInfo(PGtkWidget(Window));
          if (Info=nil) or (not (wwiDeactivating in Info^.Flags)) then
            Result := HWND({%H-}PtrUInt(GetMainWidget(Widget)));
          Break;
        end;
      end;
    end;
    list := g_list_next(list);
  end;

  if TopList <> nil
  then g_list_free(TopList);
  {$IFDEF VerboseFocus}
  DebugLn('TGtk2WidgetSet.GetFocus: Result=',dbgHex(Result));
  {$ENDIF}

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
end;

{------------------------------------------------------------------------------
  function GetFontLanguageInfo(DC: HDC): DWord; override;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetFontLanguageInfo(DC: HDC): DWord;
begin
  Result := 0;
  If IsValidDC(DC) then
  with TGtkDeviceContext(DC) do begin
    UpdateDCTextMetric(TGtkDeviceContext(DC));
    if TGtkDeviceContext(DC).DCTextMetric.IsDoubleByteChar then
      inc(Result,GCP_DBCS);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetKeyState
  Params:  nVirtKey: The requested key
  Returns: If the function succeeds, the return value specifies the status of
           the given virtual key. If the high-order bit is 1, the key is down;
           otherwise, it is up. If the low-order bit is 1, the key is toggled.

  The GetKeyState function retrieves the status of the specified virtual key.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
const
  StateDown    = -128; // $FF80
  StateToggled = 1;
  KEYSTATE: array[Boolean] of Smallint = (0, StateDown);
  TOGGLESTATE: array[Boolean] of Smallint = (0, StateToggled);
  GDK_BUTTON_MASKS: array[VK_LBUTTON..VK_XBUTTON2] of guint32 =
  (
{ VK_LBUTTON  } GDK_BUTTON1_MASK,
{ VK_RBUTTON  } GDK_BUTTON3_MASK,
{ VK_CANCEL   } 0,
{ VK_MBUTTON  } GDK_BUTTON2_MASK,
{ VK_XBUTTON1 } GDK_BUTTON4_MASK,
{ VK_XBUTTON2 } GDK_BUTTON5_MASK
  );
var
  GdkModMask: TGdkModifierType;
  x, y: gint;
begin
  case nVirtKey of
    // remap
    VK_LSHIFT:   nVirtKey := VK_SHIFT;
    VK_LCONTROL: nVirtKey := VK_CONTROL;
    VK_LMENU:    nVirtKey := VK_MENU;
  end;
  
  {$IFDEF Use_KeyStateList}
  Result := KEYSTATE[FKeyStateList_.IndexOf({%H-}Pointer(PtrUInt(nVirtKey))) >=0];
  {$ELSE}
  Implement this
  {$ENDIF}

  // try extended keys
  if Result = 0
  then begin
    {$IFDEF Use_KeyStateList}
    Result := KEYSTATE[FKeyStateList_.IndexOf({%H-}Pointer(PtrUInt(nVirtKey or KEYMAP_EXTENDED))) >=0];
    {$ELSE}
    Implement this
    {$ENDIF}
  end;

  {$IFDEF Use_KeyStateList}
  // add toggle
  Result := Result or TOGGLESTATE[FKeyStateList_.IndexOf({%H-}Pointer(
                                  PtrUInt(nVirtKey or KEYMAP_TOGGLE))) >=0];
  // If there are tons of new keyboard errors this is probably the cause
  GdkModMask := gtk_accelerator_get_default_mod_mask;
  if (Result and StateDown) <> 0 then
  begin
    if (nVirtKey = VK_CONTROL) and (GdkModMask and GDK_CONTROL_MASK = 0) then
      Result := Result and not StateDown;
    //if (nVirtKey = VK_SHIFT) and (GtkModMask and GDK_SHIFT_MASK = 0 then
    //  Result := Result and not StateDown;
  end;
  {$ENDIF}

  // Mouse buttons. Toggle state is not tracked
  if nVirtKey in [VK_LBUTTON, VK_RBUTTON, VK_MBUTTON..VK_XBUTTON2] then
  begin
    gdk_display_get_pointer(gdk_display_get_default, nil,
      @x, @y, @GdkModMask);
    Result := Result or KEYSTATE[GdkModMask and GDK_BUTTON_MASKS[nVirtKey] <> 0]
  end;
end;

function TGtk2WidgetSet.GetMapMode(DC: HDC): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if IsValidDC(DC) then
    Result := DevCtx.MapMode
  else
    Result := 0;
end;

function TGtk2WidgetSet.GetMonitorInfo(Monitor: HMONITOR; lpmi: PMonitorInfo): Boolean;
var
  MonitorRect: TGdkRectangle;
  {$IFDEF HasX}
  x, y, w, h: gint;
  {$ENDIF}
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo)) or (Monitor = 0);
  if not Result then Exit;
  Dec(Monitor);
  gdk_screen_get_monitor_geometry(gdk_screen_get_default, Monitor, @MonitorRect);
  with MonitorRect do
    lpmi^.rcMonitor := Bounds(x, y, width, height);
  // there is no way to determine workarea in gtk
  {$IFDEF HasX}
  if XGetWorkarea(x, y, w, h) <> -1 then
    lpmi^.rcWork := Bounds(Max(MonitorRect.x, x), Max(MonitorRect.y, y),
                  Min(MonitorRect.Width, w), Min(MonitorRect.Height, h))
  else
  {$ENDIF}
  lpmi^.rcWork := lpmi^.rcMonitor;
  // since gtk-2.20 we have correct api to get primary monitor. issue #32464
  if Assigned(gdk_screen_get_primary_monitor) then
  begin
    if (Monitor = gdk_screen_get_primary_monitor(gdk_screen_get_default)) then
      lpmi^.dwFlags := MONITORINFOF_PRIMARY
    else
      lpmi^.dwFlags := 0;
  end else
  begin
    // gtk2 below 2.20
    if Monitor = 0 then
      lpmi^.dwFlags := MONITORINFOF_PRIMARY
    else
      lpmi^.dwFlags := 0;
  end;
end;

{------------------------------------------------------------------------------
  Function: GetObject
  Params:  GDIObj - handle, BufSize - size of Buf argument, Buf - buffer
  Returns: Size of buffer
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer; Buf: Pointer): Integer;
  function GetObject_Bitmap: Integer;
  var
    NumColors, ImageDepth: Longint;
    BitmapSection : TDIBSECTION;
  begin
    if Buf = nil
    then begin
      Result := SizeOf(TDIBSECTION);
      Exit;
    end;

    Result := 0;

    FillChar(BitmapSection{%H-}, SizeOf(TDIBSECTION), 0);
    with {%H-}PGDIObject(GDIObj)^, BitmapSection,
      BitmapSection.dsBm, BitmapSection.dsBmih
    do begin
      {dsBM - BITMAP}
      bmType := LeToN($4D42);
      bmWidth := 0 ;
      bmHeight := 0;
      {bmWidthBytes: Longint;}
      bmPlanes := 1;//Does Bitmap Format support more?
      bmBitsPixel := 1;
      bmBits := nil;

      {dsBmih - BITMAPINFOHEADER}
      biSize := 40;
      biWidth := 0;
      biHeight := 0;
      biPlanes := bmPlanes;
      biBitCount := 1;

      biCompression := 0;
      biSizeImage := 0;

      biXPelsPerMeter := 0;
      biYPelsPerMeter := 0;

      biClrUsed   := 0;
      biClrImportant := 0;

      {dsBitfields: array[0..2] of DWORD;
      dshSection: THandle;
      dsOffset: DWORD;}
      
      {$ifdef DebugGDKTraps}BeginGDKErrorTrap;{$endif}
      case GDIBitmapType of
        gbBitmap:
          if GDIBitmapObject <> nil
          then begin
            gdk_window_get_size(GDIBitmapObject, @biWidth, @biHeight);
            NumColors := 2;
            biBitCount := 1;
          end;
        gbPixmap:
          if GDIPixmapObject.Image <> nil
          then begin
            gdk_drawable_get_size(GDIPixmapObject.Image, @biWidth, @biHeight);
            ImageDepth := gdk_drawable_get_depth(GDIPixmapObject.Image);
            biBitCount := ImageDepth;
          end;
        gbPixbuf:
          if GDIPixbufObject <> nil
          then begin
            biWidth := gdk_pixbuf_get_width(GDIPixbufObject);
            biHeight := gdk_pixbuf_get_height(GDIPixbufObject);
            biBitCount := gdk_pixbuf_get_bits_per_sample(GDIPixbufObject) * gdk_pixbuf_get_n_channels(GDIPixbufObject);
          end;
      end;

      if Visual = nil
      then begin
        Visual := gdk_visual_get_best_with_depth(biBitCount);
        if Visual = nil
        then  { Depth not supported }
          Visual := gdk_visual_get_system;
        SystemVisual := True; { This visual should not be referenced }

        if Colormap <> nil then
          gdk_colormap_unref(Colormap);
        ColorMap := gdk_colormap_new(Visual, GdkTrue);
      end
      else
        biBitCount := Visual^.Depth;

      {$ifdef DebugGDKTraps}EndGDKErrorTrap;{$enDIF}
      
      if biBitCount < 16 then
        NumColors := Colormap^.Size;

      biSizeImage := (((biBitCount*biWidth+31) shr 5) shl 2)*biHeight;

      if GetSystemMetrics(SM_CXSCREEN) >= biWidth then
        biXPelsPerMeter := GetDeviceCaps(0, LOGPIXELSX)
      else
        biXPelsPerMeter :=
          RoundToInt((single(biWidth) / GetSystemMetrics(SM_CXSCREEN)) *
                GetDeviceCaps(0, LOGPIXELSX));

      if GetSystemMetrics(SM_CYSCREEN) >= biHeight then
        biYPelsPerMeter := GetDeviceCaps(0, LOGPIXELSY)
      else
        biYPelsPerMeter :=
          RoundToInt((Single(biHeight) / GetSystemMetrics(SM_CYSCREEN))*
                GetDeviceCaps(0, LOGPIXELSY));

      bmWidth := biWidth;
      bmHeight := biHeight;
      bmBitsPixel := biBitCount;

      //Need to retrieve actual Number of Colors if Indexed Image
      if bmBitsPixel < 16
      then begin
        biClrUsed   := NumColors;
        biClrImportant := biClrUsed;
      end;
    end;
    
    if BufSize >= SizeOf(BitmapSection)
    then begin
      PDIBSECTION(Buf)^ := BitmapSection;
      Result := SizeOf(TDIBSECTION);
    end
    else if BufSize>0
    then begin
      Move(BitmapSection,Buf^,BufSize);
      Result := BufSize;
    end;
  end;
  
var
  GDIObject: PGDIObject absolute GDIObj;
  ALogPen: PLogPen absolute Buf;
  AExtLogPen: PExtLogPen absolute Buf;
  AFont: PPangoLayout;
  AFontName: String;
  PangoDesc: PPangoFontDescription;
  i, RequiredSize: Integer;
  AFontSize: gint;
begin
  Result := 0;
  if not IsValidGDIObject(GDIObj) then Exit;
  
  case GDIObject^.GDIType of
    gdiBitmap:
      Result := GetObject_Bitmap;
    gdiBrush:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetObject] gdiBrush');
      end;
    gdiFont:
      begin
        if Buf = nil
        then begin
          Result := SizeOf(GDIObject^.LogFont);
          Exit;
        end;
        if BufSize >= SizeOf(GDIObject^.LogFont) then
        begin
          PLogfont(Buf)^ := GDIObject^.LogFont;
          Result:= SizeOf(TLogFont);
          if IsFontNameDefault(GDIObject^.LogFont.lfFaceName) then
          begin
            AFontName := GetDefaultFontName;

            if (AFontName = '') or IsFontNameDefault(AFontName) then
            begin
              AFont := GetDefaultGtkFont(False);
              if PANGO_IS_LAYOUT(AFont) then
              begin
                PangoDesc := pango_layout_get_font_description(AFont);
                if PangoDesc = nil then
                  PangoDesc := pango_context_get_font_description(pango_layout_get_context(AFont));
                AFontName := StrPas(pango_font_description_get_family(PangoDesc));
              end;
            end;

            if AFontName <> '' then
              PLogfont(Buf)^.lfFaceName := AFontName;
          end;

          if (GDIObject^.GDIFontObject <> nil) then
          begin
            AFont := GDIObject^.GDIFontObject;
            if PANGO_IS_LAYOUT(AFont) then
            begin
              PangoDesc := pango_layout_get_font_description(GDIObject^.GDIFontObject);
              if PangoDesc = nil then
                PangoDesc := pango_context_get_font_description(pango_layout_get_context(AFont));

              AFontSize := pango_font_description_get_size(PangoDesc);
              if not pango_font_description_get_size_is_absolute(PangoDesc) then
                AFontSize := MulDiv(AFontSize, Screen.PixelsPerInch, 72 * PANGO_SCALE)
              else
                AFontSize := AFontSize div PANGO_SCALE;;

              PLogfont(Buf)^.lfHeight := AFontSize;
            end;
          end;
        end else
        if BufSize > 0 then
        begin
          Move(GDIObject^.LogFont,Buf^,BufSize);
          Result:=BufSize;
        end;
      end;
    gdiPen:
      begin
        if GDIObject^.IsExtPen then
        begin
          RequiredSize := SizeOf(TExtLogPen);
          if GDIObject^.GDIPenDashesCount > 1 then
            RequiredSize := RequiredSize + (GDIObject^.GDIPenDashesCount - 1) * SizeOf(DWord);

          if Buf = nil then
            Result := RequiredSize
          else
          if BufSize >= RequiredSize then
          begin
            Result := RequiredSize;

            AExtLogPen^.elpPenStyle := GDIObject^.GDIPenStyle;
            AExtLogPen^.elpWidth := GDIObject^.GDIPenWidth;
            AExtLogPen^.elpBrushStyle := BS_SOLID;
            AExtLogPen^.elpColor := GDIObject^.GDIPenColor.ColorRef;
            AExtLogPen^.elpHatch := 0;
            AExtLogPen^.elpNumEntries := GDIObject^.GDIPenDashesCount;
            if GDIObject^.GDIPenDashesCount > 0 then
            begin
              for i := 0 to GDIObject^.GDIPenDashesCount - 1 do
                PDWord(@AExtLogPen^.elpStyleEntry)[i] := GDIObject^.GDIPenDashes[i];
            end
            else
              AExtLogPen^.elpStyleEntry[0] := 0;
          end;
        end
        else
        begin
          if Buf = nil then
            Result := SizeOf(TLogPen)
          else
          if BufSize >= SizeOf(TLogPen) then
          begin
            Result := SizeOf(TLogPen);
            ALogPen^.lopnColor := GDIObject^.GDIPenColor.ColorRef;
            ALogPen^.lopnWidth := Point(GDIObject^.GDIPenWidth, 0);
            ALogPen^.lopnStyle := GDIObject^.GDIPenStyle;
          end;
        end;
      end;
    gdiRegion:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetObject] gdiRegion');
      end;
  else
    DebugLn('WARNING: [TGtk2WidgetSet.GetObject] Unknown type %d', [Integer(GDIObject^.GDIType)]);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetParent
  Params: Handle:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetParent(Handle : HWND): HWND;
begin
  if Handle <> 0 then
    Result := {%H-}HWnd({%H-}PGtkWidget(Handle)^.Parent)
  else
    Result := 0;
end;


{------------------------------------------------------------------------------
  Function: GetProp
  Params: Handle: Str
  Returns: Pointer

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetProp(Handle : hwnd; Str : PChar): Pointer;
Begin
  Result := g_object_get_data({%H-}PGObject(Handle),Str);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;

  Returns the current width of the scrollbar of the widget.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;
var
  Widget, ScrollWidget, BarWidget: PGtkWidget;
begin
  Result:=0;
  Widget:={%H-}PGtkWidget(Handle);
  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLED_WINDOW) then begin
    ScrollWidget:=Widget;
  end else begin
    ScrollWidget:=PGtkWidget(g_object_get_data(PGObject(Widget),odnScrollArea));
  end;
  if ScrollWidget=nil then exit;
  if BarKind=SM_CYVSCROLL then begin
    BarWidget:=PGtkScrolledWindow(ScrollWidget)^.vscrollbar;
    if BarWidget<>nil then
      Result:=BarWidget^.Requisition.Width;
  end else begin
    BarWidget:=PGtkScrolledWindow(ScrollWidget)^.hscrollbar;
    if BarWidget<>nil then
      Result:=BarWidget^.Requisition.Height;
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.GetScrollbarVisible(Handle: HWND;
    SBStyle: Integer): boolean;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer): boolean;
var
  Widget, ScrollWidget, BarWidget: PGtkWidget;
begin
  Result:=false;
  if Handle=0 then exit;
  Widget:={%H-}PGtkWidget(Handle);
  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLED_WINDOW) then begin
    ScrollWidget:=Widget;
  end else begin
    ScrollWidget:=PGtkWidget(g_object_get_data(PGObject(Widget),odnScrollArea));
  end;
  if ScrollWidget=nil then exit;
  if SBStyle=SB_VERT then begin
    BarWidget:=PGtkScrolledWindow(ScrollWidget)^.vscrollbar;
  end else begin
    BarWidget:=PGtkScrolledWindow(ScrollWidget)^.hscrollbar;
  end;
  if BarWidget<>nil then
    Result:=GTK_WIDGET_VISIBLE(BarWidget);
end;

{------------------------------------------------------------------------------
  Function: GetScrollInfo
  Params:  Handle, BarFlag, ScrollInfo
  Returns: Nothing

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetScrollInfo(Handle: HWND; SBStyle: Integer;
  var ScrollInfo: TScrollInfo): Boolean;
var
  Adjustment: PGtkAdjustment;
  Scroll : PGTKWidget;
  IsScrollWindow: Boolean;
begin
  Result := false;
  if (Handle = 0) then exit;


  Scroll := g_object_get_data({%H-}PGObject(Handle), odnScrollArea);
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := {%H-}PGTKWidget(Handle);
    IsScrollWindow := GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type);
  end;

  Adjustment := nil;

  case SBStyle of
    SB_HORZ:
      if IsScrollWindow
      then begin
        Adjustment := gtk_scrolled_window_get_hadjustment(
                         PGTKScrolledWindow(Scroll));
      end
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_clist_get_type)
      then begin
        //clist
        {TODO check is this is needed for listviews}
        DebugLn('[GetScrollInfo] Possible obsolete get use of CList (Listview ?)');
        Adjustment := gtk_clist_get_hadjustment(PgtkCList(Scroll));
      end
      // obsolete stuff
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_hscrollbar_get_type)
      then begin
        // this one shouldn't be possible, scrolbar messages are sent to the CTL
        DebugLN('!!! direct SB_HORZ get call to scrollbar');
        Adjustment :=  PgtkhScrollBar(Scroll)^.Scrollbar.Range.Adjustment;
      end;

    SB_VERT:
      if GtkWidgetIsA(PGtkWidget(Scroll),gtk_scrolled_window_get_type)
      then begin
        Adjustment := gtk_scrolled_window_get_vadjustment(
                         PGTKScrolledWindow(Scroll));
      end
      else if GtkWidgetIsA(PGtkWidget(Scroll), gtk_clist_get_type)
      then begin
        //clist
        //TODO: check is this is needed for listviews
        DebugLn('[GetScrollInfo] Possible obsolete get use of CList (Listview ?)');
        Adjustment := gtk_clist_get_vadjustment(PgtkCList(Scroll));
      end
      // obsolete stuff
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_vscrollbar_get_type)
      then begin
        // this one shouldn't be possible, scrolbar messages are sent to the CTL
        DebugLN('!!! direct SB_HORZ get call to scrollbar');
        Adjustment :=  PgtkvScrollBar(Scroll)^.Scrollbar.Range.Adjustment;
      end;
      
    SB_CTL:
      if GtkWidgetIsA(PGtkWidget(Scroll),gtk_vscrollbar_get_type) then
        Adjustment :=  PgtkvScrollBar(Scroll)^.Scrollbar.Range.Adjustment
      else
      if GtkWidgetIsA(PGtkWidget(Scroll),gtk_hscrollbar_get_type) then
        Adjustment :=  PgtkhScrollBar(Scroll)^.Scrollbar.Range.Adjustment
      else
      if GtkWidgetIsA(PGtkWidget(Scroll), gtk_range_get_type) then
        Adjustment := gtk_range_get_adjustment(PGTKRange(Scroll));

    SB_BOTH:
       DebugLn('[GetScrollInfo] Got SB_BOTH ???');
  end;

  if Adjustment = nil then Exit;
  
  // POS
  if (ScrollInfo.fMask and SIF_POS) <> 0
  then begin
    ScrollInfo.nPos := Round(Adjustment^.Value);
  end;
  // RANGE
  if (ScrollInfo.fMask and SIF_RANGE) <> 0
  then begin
    ScrollInfo.nMin:= Round(Adjustment^.Lower);
    ScrollInfo.nMax:= Round(Adjustment^.Upper);
  end;
  // PAGE
  if (ScrollInfo.fMask and SIF_PAGE) <> 0
  then begin
    ScrollInfo.nPage := Round(Adjustment^.Page_Size);
  end;
  // TRACKPOS
  if (ScrollInfo.fMask and SIF_TRACKPOS) <> 0
  then begin
    ScrollInfo.nTrackPos := Round(Adjustment^.Value);
  end;

  Result := true;
end;

{------------------------------------------------------------------------------
  Function: GetStockObject
  Params:
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetStockObject(Value: Integer): THandle;
begin
  Result := 0;
  case Value of
    BLACK_BRUSH:         // Black brush.
      Result := FStockBlackBrush;
    DKGRAY_BRUSH:        // Dark gray brush.
      Result := FStockDKGrayBrush;
    GRAY_BRUSH:          // Gray brush.
      Result := FStockGrayBrush;
    LTGRAY_BRUSH:        // Light gray brush.
      Result := FStockLtGrayBrush;
    NULL_BRUSH:          // Null brush (equivalent to HOLLOW_BRUSH).
      Result := FStockNullBrush;
    WHITE_BRUSH:         // White brush.
      Result := FStockWhiteBrush;

    BLACK_PEN:           // Black pen.
      Result := FStockBlackPen;
    NULL_PEN:            // Null pen.
      Result := FStockNullPen;
    WHITE_PEN:           // White pen.
      Result := FStockWhitePen;

   (* ANSI_FIXED_FONT:     // Fixed-pitch (monospace) system font.
      begin
        {If FStockFixedFont = 0 then
          FStockFixedFont := GetStockFixedFont;
        Result := FStockFixedFont;}
      end;
    ANSI_VAR_FONT:       // Variable-pitch (proportional space) system font.
      begin
      end;
    DEVICE_DEFAULT_FONT: // Device-dependent font.
      begin
      end;  *)
(*    OEM_FIXED_FONT:      // Original equipment manufacturer (OEM) dependent fixed-pitch (monospace) font.
      begin
      end;
*)
    DEFAULT_GUI_FONT, SYSTEM_FONT:         // System font. By default, Windows uses the system font to draw menus, dialog box controls, and text. In Windows versions 3.0 and later, the system font is a proportionally spaced font; earlier versions of Windows used a monospace system font.
      begin
        // MG: this should only be done, when theme changed:
        {If FStockSystemFont <> 0 then begin //This is a Temporary Hack!!! This
          DeleteObject(FStockSystemFont);   //should really only be done on
          FStockSystemFont := 0;            //theme change.
        end;}

        If FStockSystemFont = 0 then
          FStockSystemFont := HFont({%H-}PtrUInt(CreateDefaultFont));
        Result := FStockSystemFont;
      end;
(*    SYSTEM_FIXED_FONT:   // Fixed-pitch (monospace) system font used in Windows versions earlier than 3.0. This stock object is provided for compatibility with earlier versions of Windows.
      begin
        Result := GetStockObject(ANSI_FIXED_FONT);
      end;
    DEFAULT_PALETTE:     // Default palette. This palette consists of the static colors in the system palette.
      begin
      end;
*)
  end;
end;

{------------------------------------------------------------------------------
  Function: GetSysColor
  Params:   index to the syscolors array
  Returns:  RGB value

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetSysColor(nIndex: Integer): DWORD;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS)
  then begin
    Result := 0;
    DumpStack;
    DebugLn(Format('ERROR: [TGtk2WidgetSet.GetSysColor] Bad Value: %d. Valid Range between 0 and %d', [nIndex, MAX_SYS_COLORS]));
  end
  else
    Result := SysColorMap[nIndex];
end;

function TGtk2WidgetSet.GetSysColorBrush(nIndex: Integer): HBrush;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS)
  then begin
    Result := 0;
    DumpStack;
    DebugLn(Format('ERROR: [TGtk2WidgetSet.GetSysColorBrush] Bad Value: %d. Valid Range between 0 and %d', [nIndex, MAX_SYS_COLORS]));
  end
  else
    Result := FSysColorBrushes[nIndex];
end;

{------------------------------------------------------------------------------
  Function: GetSystemMetrics
  Params:
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetSystemMetrics(nIndex: Integer): Integer;
var
  P: Pointer;
{$ifdef HasX}
  ax,ay,ah,aw: gint;
{$endif}
{$IFDEF Win32}
  auw, auh: guint;
{$ENDIF}
  screen: PGdkScreen;
  ARect: TGdkRectangle;
  AValue: TGValue;
begin
  Result := 0;
  case nIndex of
    SM_ARRANGE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_ARRANGE          ');
      end;
    SM_CLEANBOOT:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CLEANBOOT        ');
      end;
    SM_CMOUSEBUTTONS:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CMOUSEBUTTONS    ');
      end;
    SM_CXBORDER:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXBORDER         ');
        Result := Max(FCachedBorderSize, 0);
      end;
    SM_CYBORDER:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYBORDER         ');
        Result := Max(FCachedBorderSize, 0);
      end;
    SM_CXCURSOR,
    SM_CYCURSOR:
      begin
        {$IFDEF Win32}
          // Width and height of a cursor, in pixels. For win32 system cannot create cursors of other sizes.
          // For gtk this should be maximal cursor sizes
          gdk_display_get_maximal_cursor_size(gdk_display_get_default, @auw, @auh);
          if nIndex = SM_CXCURSOR
          then Result := auw // return width
          else Result := auh; // return height
        {$ELSE}
          // At least on Linux, the default size should be taken: Issue #32385
          Result := gdk_display_get_default_cursor_size(gdk_display_get_default);
        {$ENDIF}
      end;
    SM_CXDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXDOUBLECLK      ');
      end;
    SM_CYDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYDOUBLECLK      ');
      end;
    SM_CXDRAG:
      begin
        Result := 2;
      end;
    SM_CYDRAG:
      begin
        Result := 2;
      end;
    SM_CXEDGE:
      begin
        Result := 2;
      end;
    SM_CYEDGE:
      begin
        Result := 2;
      end;
    SM_CXFIXEDFRAME:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXFIXEDFRAME     ');
      end;
    SM_CYFIXEDFRAME:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYFIXEDFRAME     ');
      end;
    SM_CXHSCROLL:
      begin
        P := GetStyleWidget(lgsVerticalScrollbar);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Width;
      end;
    SM_CYHSCROLL:
      begin
        P := GetStyleWidget(lgsHorizontalScrollbar);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Height;
      end;
    SM_CXHTHUMB,
    SM_CYVTHUMB:
      begin
        P := GetStyleWidget(lgsHorizontalScrollbar);
        if P <> nil then
        begin
          FillChar(AValue{%H-}, SizeOf(AValue), 0);
          g_value_init(@AValue, G_TYPE_INT);
          gtk_widget_style_get_property(P, 'slider-width', @AValue);
          Result := AValue.data[0].v_int;
        end;
      end;
    SM_CXICON,
    SM_CYICON:
      // big icon size
      // gtk recommends sizes 16,32,48. optional: 64 and 128
      Result := 128;
    SM_CXICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXICONSPACING    ');
      end;
    SM_CYICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYICONSPACING    ');
      end;
    SM_CXMAXIMIZED:
      begin
        {$IFDEF HasX}
        if XGetWorkarea(ax,ay,aw,ah)>=0 then
          Result := aw
        else
          Result := getSystemMetrics(SM_CXSCREEN);
        {$ENDIF}
      end;
    SM_CYMAXIMIZED:
      begin
        {$IFDEF HasX}
        if XGetWorkarea(ax,ay,aw,ah)>=0 then
          Result := ah
        else
          Result := getSystemMetrics(SM_CYSCREEN);
        {$ENDIF}
      end;
    SM_CXMAXTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXMAXTRACK       ');
      end;
    SM_CYMAXTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYMAXTRACK       ');
      end;
    SM_CXMENUCHECK:
      begin
        Result := 19;
        P := GetStyleWidget(lgsCheckbox);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Width;
      end;
    SM_CYMENUCHECK:
      begin
        Result := 19;
        P := GetStyleWidget(lgsCheckbox);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Height;
      end;
    SM_CXMENUSIZE,
    SM_CYMENUSIZE:
      begin
        Result := GetTitleBarHeight - (FCachedBorderSize * 2);
      end;
    SM_CXMIN:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXMIN            ');
      end;
    SM_CYMIN:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYMIN            ');
      end;
    SM_CXMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXMINIMIZED      ');
      end;
    SM_CYMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYMINIMIZED      ');
      end;
    SM_CXMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXMINSPACING     ');
      end;
    SM_CYMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYMINSPACING     ');
      end;
    SM_CXMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXMINTRACK       ');
      end;
    SM_CYMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYMINTRACK       ');
      end;
    SM_CXFULLSCREEN,
    SM_CXSCREEN:
      begin
        screen := gdk_screen_get_default();
        gdk_screen_get_monitor_geometry(screen, 0, @ARect);
        Result := ARect.width;
      end;
    SM_CXVIRTUALSCREEN:
      begin
        Result := gdk_Screen_Width;
      end;
    SM_CYFULLSCREEN,
    SM_CYSCREEN:
      begin
        screen := gdk_screen_get_default();
        gdk_screen_get_monitor_geometry(screen, 0, @ARect);
        Result := ARect.height;
      end;
    SM_CYVIRTUALSCREEN:
      begin
        result := gdk_Screen_Height;
      end;
    SM_CXSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXSIZE           ');
      end;
    SM_CYSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYSIZE           ');
      end;
    SM_CXSIZEFRAME,
    SM_CYSIZEFRAME:
      begin
        Result := FCachedBorderSize;
      end;
    SM_CXSMICON,
    SM_CYSMICON:
      // small icon size
      // gtk recommends sizes 16,32,48. optional: 64 and 128
      Result := 16;
    SM_CXSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CXSMSIZE         ');
      end;
    SM_CYSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYSMSIZE         ');
      end;
    SM_CXVSCROLL:
      begin
        P := GetStyleWidget(lgsVerticalScrollbar);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Width;
      end;
    SM_CYVSCROLL:
      begin
        P := GetStyleWidget(lgsHorizontalScrollbar);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Height;
      end;
    SM_CYCAPTION:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYCAPTION        ');
        Result := GetTitleBarHeight;
      end;
    SM_CYKANJIWINDOW:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYKANJIWINDOW    ');
      end;
    SM_CYMENU:
      begin
        Result := 24; // default gtk2 menusize inside menubar.
        P := GetStyleWidget(lgsMenu);
        if P <> nil then
          Result := GTK_Widget(P)^.requisition.Height;
      end;
    SM_CYSMCAPTION:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_CYSMCAPTION      ');
      end;
    SM_DBCSENABLED:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_DBCSENABLED      ');
      end;
    SM_DEBUG:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_DEBUG            ');
      end;
    SM_MENUDROPALIGNMENT:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_MENUDROPALIGNMENT');
      end;
    SM_MIDEASTENABLED:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_MIDEASTENABLED   ');
      end;
    SM_MOUSEPRESENT:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_MOUSEPRESENT     ');
      end;
    SM_MOUSEWHEELPRESENT:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_MOUSEWHEELPRESENT');
      end;
    SM_NETWORK:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_NETWORK          ');
      end;
    SM_PENWINDOWS:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_PENWINDOWS       ');
      end;
    SM_SECURE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_SECURE           ');
      end;
    SM_SHOWSOUNDS:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_SHOWSOUNDS       ');
      end;
    SM_SLOWMACHINE:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_SLOWMACHINE      ');
      end;
    SM_SWAPBUTTON:
      begin
        //DebugLn('Trace:TODO: [TGtk2WidgetSet.GetSystemMetrics] --> SM_SWAPBUTTON       ');
      end;
    SM_SWSCROLLBARSPACING:
      begin
        P := GetStyleWidget(lgsScrolledWindow);
        if P <> nil then begin
          result := GTK_SCROLLED_WINDOW_CLASS(gtk_widget_get_class(P))^.scrollbar_spacing;
          if result<0 then
            gtk_widget_style_get(P, 'scrollbar-spacing', @result, nil);
        end;
      end;

    SM_LCLMAXIMIZEDWIDTH:
      begin
        Result := GetSystemMetrics(SM_CXMAXIMIZED);
      end;
    SM_LCLMAXIMIZEDHEIGHT:
      begin
        Result := GetSystemMetrics(SM_CYMAXIMIZED) - 1 -
          (GetSystemMetrics(SM_CYCAPTION) - (GetSystemMetrics(SM_CYSIZEFRAME) * 2));
      end;
    SM_LCLHasFormAlphaBlend:
      begin
        Result:=1;
      end;
  end;
end;

{------------------------------------------------------------------------------
  Function: GetTextColor
  Params:  DC
  Returns: TColorRef

  Gets the Font Color currently assigned to the Device Context
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetTextColor(DC: HDC) : TColorRef;
begin
  Result := 0;
  if IsValidDC(DC) then
    with TGtkDeviceContext(DC) do
    begin
      Result := CurrentTextColor.ColorRef;
    end;
end;

{------------------------------------------------------------------------------
  Function: GetTextExtentExPoint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetTextExtentExPoint(DC: HDC; Str: PChar;
  Count, MaxWidth: Integer; MaxCount, PartialWidths: PInteger;
  var Size: TSize): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  UseFont : TGtkIntfFont;
  Utf8Len, Accu, I: PtrInt;
  Iter: PPangoLayoutIter;
  CharRect: TPangoRectangle;
begin
  if not IsValidDC(DC) then
    Exit(False);

  Size.cx := 0;
  Size.cy := 0;
  if MaxCount <> nil then
    MaxCount^ := 0;

  if Count = 0 then
    Exit(True);
  if (Count < -1) or (Str = nil) then
    Exit(False);

  if Count = -1 then
    Count := Length(Str);
  Utf8Len := UTF8Length(Str, Count);
  if Utf8Len = 0 then
    Exit(True);

  UseFont := GetGtkFont(DevCtx);
  UpdateDCTextMetric(DevCtx);
  SetLayoutText(UseFont, Str, Count);
  pango_layout_get_pixel_size(UseFont, @Size.cx, @Size.cy);
  if DevCtx.HasTransf then
  begin
    DevCtx.InvTransfExtent(Size.cx, Size.cy);
    Size.cx := Abs(Size.cx);
    Size.cy := Abs(Size.cy);
  end;

  if PartialWidths = nil then
  begin
    if MaxCount = nil then
      Exit(True);
    if Size.cx <= MaxWidth then
    begin
      MaxCount^ := Utf8Len;
      Exit(True);
    end;
  end;

  I := 1;
  Accu := 0;
  Iter := pango_layout_get_iter(UseFont);
  repeat
    pango_layout_iter_get_char_extents(Iter, @CharRect);
    Inc(Accu, CharRect.Width);

    CharRect.Width := Accu;
    pango_extents_to_pixels(nil, @CharRect);
    if DevCtx.HasTransf then
    begin
      DevCtx.InvTransfExtent(CharRect.Width, CharRect.Height);
      CharRect.Width := Abs(CharRect.Width);
    end;

    if MaxCount <> nil then
    begin
      if CharRect.Width > MaxWidth then
        Break;
      MaxCount^ := I;
    end;
    if PartialWidths <> nil then
      PartialWidths[I - 1] := CharRect.Width;

    Inc(I);
  until not pango_layout_iter_next_char(Iter);
  pango_layout_iter_free(Iter);

  Exit(True);
end;

{------------------------------------------------------------------------------
  Function: GetTextExtentPoint
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer;
  var Size: TSize): Boolean;
begin
  Result := GetTextExtentExPoint(DC, Str, Count, 0, nil, nil, Size);
end;

{------------------------------------------------------------------------------
  Function: GetTextMetrics
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := IsValidDC(DC);
  if Result then
  begin
    UpdateDCTextMetric(DevCtx);
    TM := DevCtx.DCTextMetric.TextMetric;
  end;
end;

function TGtk2WidgetSet.GetViewPortExtEx(DC: HDC; Size: PSize): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if IsValidDC(DC) and (Size <> nil) then
  begin
    Size^.cx := DevCtx.ViewPortExt.x;
    Size^.cy := DevCtx.ViewPortExt.y;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TGtk2WidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if IsValidDC(DC) and (P <> nil) then
  begin
    P^.x := DevCtx.ViewPortOrg.x;
    P^.y := DevCtx.ViewPortOrg.y;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

function TGtk2WidgetSet.GetWindowExtEx(DC: HDC; Size: PSize): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if IsValidDC(DC) and (Size <> nil) then
  begin
    Size^.cx := DevCtx.WindowExt.x;
    Size^.cy := DevCtx.WindowExt.y;
    Result := Integer(True);
  end else
    Result := Integer(False);
end;

{------------------------------------------------------------------------------
  Function: GetWindowLong
  Params:  none
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetWindowLong(Handle: HWND; int: Integer): PtrInt;

  function GetObjectData(Name: PChar): PtrInt;
  begin
    Result := PtrInt({%H-}PtrUInt({%H-}g_object_get_data({%H-}PGObject(Handle),Name)));
  end;
var
  WidgetInfo: PWidgetInfo;
begin
  //TODO:Started but not finished

  case int of
    GWL_WNDPROC :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          Result := WidgetInfo^.WndProc
        else
          Result := 0;
      end;
    GWL_HINSTANCE :
      begin
        Result := GetObjectData('HINSTANCE');
      end;
    GWL_HWNDPARENT :
      begin
        Result := GetObjectData('HWNDPARENT');
      end;

{    GWL_WNDPROC :
      begin
        Data := GetLCLObject(Pointer(Handle));
        if Data is TControl
        then Result := PtrInt(@(TControl(Data).WindowProc));
        // TODO fix this, a method pointer (2 pointers) can not be casted to a longint
      end;
}
{    GWL_HWNDPARENT :
      begin
        Data := GetLCLObject(Pointer(Handle));
        if (Data is TWinControl)
        then Result := PtrInt(TWincontrol(Data).Handle)
        else Result := 0;
      end;
 }
    GWL_STYLE :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          Result := WidgetInfo^.Style
        else
          Result := 0;
      end;
    GWL_EXSTYLE :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          Result := WidgetInfo^.ExStyle
        else
          Result := 0;
      end;
    GWL_USERDATA :
      begin
        Result := GetObjectData('Userdata');
      end;
    GWL_ID :
      begin
        Result := GetObjectData('ID');
      end;
    else Result := 0;
  end; //case
end;

{------------------------------------------------------------------------------
  Function: GetWindowOrgEx
  Params:  none
  Returns: Nothing

  Returns the current offset of the DC.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetWindowOrgEx(dc: hdc; P: PPoint): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if P = nil then Exit(0);
  P^ := Point(0,0);
  if not IsValidDC(DC) then exit(0);
  
  P^ := DevCtx.WindowOrg;
  Result := 1;
end;

{------------------------------------------------------------------------------
  Function: GetWindowRect
  Params:  none
  Returns: 0

  After the call, ARect will be the control area in screen coordinates.
  That means, Left and Top will be the screen coordinate of the TopLeft pixel
  of the Handle object and Right and Bottom will be the screen coordinate of
  the BottomRight pixel.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
var
  Widget: PGTKWidget;
  GRect: TGdkRectangle;
  P: TPoint;
  AInfo: PWidgetInfo;
  AForm: TCustomForm;
  R, AFrame: TRect;
begin
  Result := 0; // error
  if Handle = 0 then
    Exit;

  Widget := {%H-}PGtkWidget(Handle);

  if GTK_IS_WINDOW(Widget) and Assigned(Widget^.window)
  and GTK_WIDGET_VISIBLE(Widget) // Gtk2 returns invalid origin/frame for invisible widgets
  then
  begin
    P := GetWidgetOrigin(Widget);
    gdk_window_get_frame_extents(Widget^.window, @GRect);
    ARect := Bounds(P.X,P.Y,GRect.width,GRect.height);
    // writeln('Frame extents are: ',dbgs(R),' ARECT=',dbgs(ARect));
    Result := 1; // success
  end else
  begin
    {$IFDEF HASX}
    AInfo := GetWidgetInfo(Widget);
    if (AInfo^.LCLObject is TCustomForm) and not AInfo^.FirstPaint then
    begin
      AForm := TCustomForm(AInfo^.LCLObject);
      if not IsFormDesign(AForm) and (AForm.BorderStyle <> bsNone) and
        not (AForm.FormStyle in [fsMDIChild, fsSplash])
      and (Gtk2WidgetSet.GetDummyWidgetFrame <> Rect(0, 0, 0, 0)) then
      begin
        R := AForm.BoundsRect;
        AFrame := Gtk2WidgetSet.GetDummyWidgetFrame;
        // apply frame size to lcl form.
        R.Right += AFrame.Left + AFrame.Right;
        R.Bottom += AFrame.Top + AFrame.Bottom;
        ARect := R; //this is now real size under x11 even on unmapped window :)
        exit(-1);
      end;
    end;
    {$ENDIF}
    ARect.TopLeft := GetWidgetOrigin(Widget);
    if (ARect.Top <> -1) or (ARect.Left <> -1)
    or (Widget^.allocation.width <> 1) or (Widget^.allocation.height <> 1) then
    begin
      ARect.BottomRight := Point(
        ARect.Left + Widget^.allocation.width,
        ARect.Top + Widget^.allocation.height);
      Result := 1; // success
    end;
  end;
end;
{------------------------------------------------------------------------------
  Function: GetWindowRelativePosition
  Params:  Handle : hwnd;
  Returns: true on success

  Returns the Left, Top, relative to the client origin of its parent
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetWindowRelativePosition(Handle : hwnd;
  var Left, Top: integer): boolean;
var
  aWidget: PGtkWidget;
begin
  aWidget := {%H-}PGtkWidget(Handle);
  if GtkWidgetIsA(aWidget, GTK_TYPE_WIDGET) then
  begin
    Result := true;
    GetWidgetRelativePosition(aWidget, Left, Top);
  end else
    Result := false;
end;

{------------------------------------------------------------------------------
  Function: GetWindowSize
  Params:  Handle : hwnd;
  Returns: true on success

  Returns the current widget Width and Height
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.GetWindowSize(Handle : hwnd;
  var Width, Height: integer): boolean;
begin
  if GtkWidgetIsA({%H-}PGtkWidget(Handle),GTK_TYPE_WIDGET) then begin
    Result:=true;
    Width:=Max(0,{%H-}PGtkWidget(Handle)^.Allocation.Width);
    Height:=Max(0,{%H-}PGtkWidget(Handle)^.Allocation.Height);
    //DebugLn(['TGtk2WidgetSet.GetWindowSize ',DbgSName(GetLCLOwnerObject(Handle)),' Allocation=',Width,'x',Height]);
  end else
    Result:=false;
end;

{------------------------------------------------------------------------------
  Function: HideCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.HideCaret(hWnd: HWND): Boolean;
var
  GTKObject: PGTKObject;
  WasVisible: boolean;
begin
  GTKObject := {%H-}PGTKObject(HWND);
  Result := GTKObject <> nil;

  if Result
  then begin
    if gtk_type_is_a(g_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      WasVisible:=false;
      GTKAPIWidget_HideCaret(PGTKAPIWidget(GTKObject),WasVisible);
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end
  else DebugLn('WARNING: [TGtk2WidgetSet.HideCaret] Got null HWND');

end;

{------------------------------------------------------------------------------
  Function: InvalidateRect
  Params: aHandle:
          Rect:
          bErase:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.InvalidateRect(aHandle : HWND; Rect : pRect;
  bErase : Boolean) : Boolean;
var
  gdkRect : TGDKRectangle;
  Widget, PaintWidget: PGtkWidget;
  LCLObject: TObject;
  WidgetInfo: PWidgetInfo;
  r: TRect;
  Adjustment: PGtkAdjustment;
  Pt: TPoint;
begin
  //  DebugLn(format('Rect = %d,%d,%d,%d',[rect^.left,rect^.top,rect^.Right,rect^.Bottom]));
  Widget:={%H-}PGtkWidget(aHandle);
  LCLObject:=GetLCLObject(Widget);
  if (LCLObject<>nil) then
  begin
    if (LCLObject=CurrentSentPaintMessageTarget) then
    begin
      DebugLn('WARNING: TGtk2WidgetSet.InvalidateRect refused invalidating during paint message: ',
        LCLObject.ClassName);
      exit(False);
    end;
    {$IFDEF VerboseDsgnPaintMsg}
    if (LCLObject is TComponent)
    and (csDesigning in TComponent(LCLObject).ComponentState) then begin
      write('TGtk2WidgetSet.InvalidateRect A ');
      write(TComponent(LCLObject).Name,':');
      write(LCLObject.ClassName);
      with Rect^ do
        write(' Rect=',Left,',',Top,',',Right,',',Bottom);
      DebugLn(' Erase=',bErase);
    end;
    {$ENDIF}
  end;
  Result := True;
  PaintWidget:=GetFixedWidget(Widget);
  if PaintWidget=nil then PaintWidget:=Widget;

  if Rect = nil then
  begin
    Rect := @r;
    Rect^.Left := 0;//PaintWidget^.Allocation.X;
    Rect^.Top := 0;//PaintWidget^.Allocation.Y;
    Rect^.Right := PaintWidget^.Allocation.Width;
    Rect^.Bottom := PaintWidget^.Allocation.Height;
  end else
  begin
    // normalize rect
    r := Rect^;
    if r.Left>r.Right then
    begin
      r.Left := r.Right;
      r.Right := Rect^.Left;
    end;
    if r.Top>r.Bottom then
    begin
      r.Top := r.Bottom;
      r.Bottom := Rect^.Top;
    end;
    Rect := @r;
  end;

  gdkRect.X := Rect^.Left;
  gdkRect.Y := Rect^.Top;
  gdkRect.Width := (Rect^.Right - Rect^.Left);
  gdkRect.Height := (Rect^.Bottom - Rect^.Top);

  if (PaintWidget<>nil) and GTK_WIDGET_NO_WINDOW(PaintWidget) and (Rect<>nil) and
    (not GtkWidgetIsA(PGTKWidget(PaintWidget),GTKAPIWidget_GetType)) then
  begin
    Inc(gdkRect.X, PaintWidget^.Allocation.x);
    Inc(gdkRect.Y, PaintWidget^.Allocation.y);
    // issue #25572
    if GTK_IS_FIXED(PaintWidget) and GTK_IS_EVENT_BOX(PaintWidget^.parent) then
    begin
      Inc(gdkRect.Width, PaintWidget^.Allocation.x);
      Inc(gdkRect.Height, PaintWidget^.Allocation.y);
      // DebugLn('#25572 PATCH FOR ',dbgsName(LCLObject),' GdkRect=',dbgs(gdkRect),' Alloc=',dbgs(TGdkRectangle(PaintWidget^.allocation)));
      {GtkWidget isn't yet allocated to LCL size, do not call invalid area update - update complete gtkwidget}
      if (gdkRect.Width > PaintWidget^.allocation.width) or (gdkRect.Height > PaintWidget^.allocation.Height) then
      begin
        // DebugLn('*** WARNING: Rect to paint is bigger than widget Width diff=',dbgs(gdkRect.Width - PaintWidget^.allocation.width),
        //  ' Height diff=',dbgs(gdkRect.Height - PaintWidget^.allocation.height));
        if bErase then
          gtk_widget_queue_clear(PaintWidget);
        gtk_widget_queue_draw(PaintWidget);
        exit;
      end;
    end;
  end;
  if (LCLObject is TScrollingWinControl) and GTK_IS_SCROLLED_WINDOW(Widget) then
  begin
    Pt := Point(0, 0);
    Adjustment := gtk_scrolled_window_get_vadjustment(PGtkScrolledWindow(Widget));
    if Adjustment <> nil then
      Pt.Y := Round(Adjustment^.value);
    Adjustment := gtk_scrolled_window_get_hadjustment(PGtkScrolledWindow(Widget));
    if Adjustment <> nil then
      Pt.X := Round(Adjustment^.value);
    dec(gdkRect.x, Pt.X);
    dec(gdkRect.y, Pt.Y);
    OffsetRect(Rect^, -Pt.X, -Pt.Y);
  end;
  WidgetInfo := GetWidgetInfo(Widget); // GetOrCreateWidgetInfo() ??
  if WidgetInfo <> nil then
    UnionRect(WidgetInfo^.UpdateRect, WidgetInfo^.UpdateRect, Rect^);

  if bErase then
    gtk_widget_queue_clear_area(PaintWidget,
      gdkRect.X,gdkRect.Y,gdkRect.Width,gdkRect.Height);

  gtk_widget_queue_draw_area(PaintWidget,
    gdkRect.X,gdkRect.Y,gdkRect.Width,gdkRect.Height);

  //DebugLn(['TGtk2WidgetSet.InvalidateRect ',GetWidgetDebugReport(Widget),' IsAPI=',GtkWidgetIsA(PGTKWidget(Widget),GTKAPIWidget_GetType)]);
  if GtkWidgetIsA(PGTKWidget(Widget),GTKAPIWidget_GetType) then
    GTKAPIWidget_InvalidateCaret(PGTKAPIWidget(Widget));
end;

function TGtk2WidgetSet.InvalidateRgn(Handle: HWND; Rgn: HRGN; Erase: Boolean
  ): Boolean;
var
  R: TRect;
begin
  // TODO: use gdk_window_invalidate_region to implement this function
  Result:=GetRgnBox(Rgn, @R)=0;
  InvalidateRect(Handle, @R, Erase);
end;

function TGtk2WidgetSet.IsIconic(handle: HWND): boolean;
var
  GtkWindow: PGtkWindow absolute handle;
begin
  Result := False;
  if GtkWindow = nil then
    Exit;

  Result := (PGtkWidget(GtkWindow)^.Window<>nil)
      and (gdk_window_get_state(PGtkWidget(GtkWindow)^.Window)
           and GDK_WINDOW_STATE_ICONIFIED <> 0);
end;

function TGtk2WidgetSet.IsWindow(handle: HWND): boolean;
begin
  if Handle = 0 then
    Exit(False);

  Result := GtkWidgetIsA({%H-}PGtkWidget(Handle), GTK_TYPE_WIDGET);
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.IsWindowEnabled(handle: HWND): boolean;

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.IsWindowEnabled(handle: HWND): boolean;
var
  LCLObject: TObject;
  Widget: PGtkWidget;
  AForm: TCustomForm;
  //i: Integer;
begin
  Widget:={%H-}PGtkWidget(handle);
  Result:=(Widget<>nil) and GTK_WIDGET_SENSITIVE(Widget)
          and GTK_WIDGET_PARENT_SENSITIVE(Widget) and GTK_WIDGET_VISIBLE(Widget);
  LCLObject:=GetLCLObject({%H-}PGtkWidget(Handle));
  //debugln('TGtk2WidgetSet.IsWindowEnabled A ',DbgSName(LCLObject),' Result=',dbgs(Result),
  //  ' SENSITIVE=',dbgs(GTK_WIDGET_SENSITIVE(Widget)),
  //  ' PARENT_SENSITIVE=',dbgs(GTK_WIDGET_PARENT_SENSITIVE(Widget)),
  //  ' TOPLEVEL=',dbgs(GTK_WIDGET_TOPLEVEL(Widget)),
  //  '');
  if Result and GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then begin
    LCLObject:=GetLCLObject(Widget);
    if (LCLObject is TCustomForm) then begin
      AForm:=TCustomForm(LCLObject);
      if not Screen.CustomFormBelongsToActiveGroup(AForm) then
        Result:=false;
      //debugln('TGtk2WidgetSet.IsWindowEnabled B ',dbgs(Screen.CustomFormBelongsToActiveGroup(AForm)));
      //for i:=0 to Screen.CustomFormCount-1 do begin
      //  debugln('  ',dbgs(i),' ',DbgSName(Screen.CustomFormsZOrdered[i]));
      //end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.IsWindowVisible(handle: HWND): boolean;

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.IsWindowVisible(handle: HWND): boolean;
begin
  Result := (handle <> 0) and GTK_WIDGET_VISIBLE({%H-}PGtkWidget(handle));
end;

function TGtk2WidgetSet.IsZoomed(handle: HWND): boolean;
var
  GtkWindow: PGtkWindow absolute handle;
begin
  Result := False;
  if GtkWindow = nil then
    Exit;

  Result := gdk_window_get_state(PGtkWidget(GtkWindow)^.Window) and GDK_WINDOW_STATE_MAXIMIZED <> 0;
end;

{------------------------------------------------------------------------------
  Function: LineTo
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  FromPt: TPoint;
  ToPt: TPoint;
begin
  if not IsValidDC(DC) then Exit(False);

  DevCtx.SelectPenProps;
  if not (dcfPenSelected in DevCtx.Flags) then Exit(False);
  
  if DevCtx.IsNullPen then Exit(True);

  FromPt := Point(DevCtx.PenPos.X + DevCtx.Offset.X, DevCtx.PenPos.Y + DevCtx.Offset.Y);
  LPtoDP(DC, FromPt, 1);
  ToPt := Point(X+DevCtx.Offset.X, Y+DevCtx.Offset.Y);
  LPToDP(DC, ToPt, 1);
  
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  DevCtx.RemovePixbuf;
  gdk_draw_line(DevCtx.Drawable, DevCtx.GC, FromPt.X, FromPt.Y, ToPt.X, ToPt.Y);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}

  DevCtx.PenPos := Point(X, Y);

  Result := True;
end;

function TGtk2WidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
var
  DevCtx: TGtkDeviceContext absolute DC;
  P: PPoint;
begin
  Result := False;

  if not IsValidDC(DC) then Exit(False);

  if not DevCtx.HasTransf then Exit(True);

  P := @Points;
  while Count > 0 do
  begin
    Dec(Count);
    DevCtx.TransfPoint(P^.X, P^.Y);
    Inc(P);
  end;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: MessageBox
  Params:  hWnd:                  The handle of parent window
  Returns: 0 if not successful (out of memory), otherwise one of the defined value :
      IDABORT, IDCANCEL, IDIGNORE, IDNO, IDOK, IDRETRY, IDYES

 The MessageBox function displays a modal dialog, with text and caption defined,
 and includes buttons.
 ------------------------------------------------------------------------------}

function MessageButtonClicked(Widget : PGtkWidget; data: gPointer) : GBoolean; cdecl;
begin
  //DebugLn('[MessageButtonClicked] ',dbgs(data),' ',dbgs(g_object_get_data(PGtkObject(Widget), 'modal_result')));
  if PInteger(data)^ = 0 then
    PInteger(data)^:={%H-}PtrUInt(g_object_get_data(PGObject(Widget), 'modal_result'));
  Result:=false;
end;

function MessageBoxClosed(Widget : PGtkWidget; {%H-}Event : PGdkEvent;
  data: gPointer) : GBoolean; cdecl;
var ModalResult : PtrUInt;
begin
  { We were requested by window manager to close }
  if PInteger(data)^ = 0 then begin
    ModalResult:= {%H-}PtrUInt(g_object_get_data(PGObject(Widget), 'modal_result'));
    { Don't allow to close if we don't have a default return value }
    Result:= (ModalResult = 0);
    if not Result then PInteger(data)^:= ModalResult
    else DebugLn('Do not close !!!');
  end else Result:= false;
end;

function TGtk2WidgetSet.MessageBox(hWnd: HWND; lpText, lpCaption: PChar;
  uType : Cardinal): integer;
var Dialog, ALabel : PGtkWidget;
    ButtonCount, DefButton, ADialogResult : Integer;

    procedure CreateButton(const ALabel : PChar; const RetValue : integer);
    var AButton : PGtkWidget;
    begin
      AButton:= gtk_button_new_with_mnemonic(Ampersands2Underscore(ALabel));
      Inc(ButtonCount);
      if ButtonCount = DefButton then begin
        gtk_window_set_focus(PGtkWindow(Dialog), AButton);
      end;
      { If there is the Cancel button, allow the dialog to close }
      if RetValue = IDCANCEL then begin
        g_object_set_data(PGObject(Dialog), 'modal_result', Pointer(IDCANCEL));
      end;
      g_object_set_data(PGObject(AButton), 'modal_result',
                          {%H-}Pointer(PtrInt(RetValue)));
      g_signal_connect(PGtkObject(AButton), 'clicked',
                       TGtkSignalFunc(@MessageButtonClicked), @ADialogResult);
      gtk_container_add (PGtkContainer(PGtkDialog(Dialog)^.action_area), AButton);
    end;

begin
  ButtonCount:= 0;
  { Determine which is the default button }
  DefButton:= ((uType and $00000300) shr 8) + 1;
  //DebugLn('Trace:Default button is ' + IntToStr(DefButton));

  ADialogResult:= 0;
  Dialog:= gtk_dialog_new;
  {$IFDEF DebugLCLComponents}
  DebugGtkWidgets.MarkCreated(Dialog,'TGtk2WidgetSet.MessageBox');
  {$ENDIF}
  g_signal_connect(PGtkObject(Dialog), 'delete-event', TGtkSignalFunc(@MessageBoxClosed), @ADialogResult);
  gtk_window_set_default_size(PGtkWindow(Dialog), 100, 100);
  ALabel:= gtk_label_new(lpText);
  gtk_container_add (PGtkContainer(PGtkDialog(Dialog)^.vbox), ALabel);
  case (uType and $0000000F) of
    MB_OKCANCEL:
      begin
        CreateButton(PChar(rsMbOK), IDOK);
        CreateButton(PChar(rsMbCancel), IDCANCEL);
      end;
    MB_ABORTRETRYIGNORE:
      begin
        CreateButton(PChar(rsMbAbort), IDABORT);
        CreateButton(PChar(rsMbRetry), IDRETRY);
        CreateButton(PChar(rsMbIgnore), IDIGNORE);
      end;
    MB_YESNOCANCEL:
      begin
        CreateButton(PChar(rsMbYes), IDYES);
        CreateButton(PChar(rsMbNo), IDNO);
        CreateButton(PChar(rsMbCancel), IDCANCEL);
      end;
    MB_YESNO:
      begin
        CreateButton(PChar(rsMbYes), IDYES);
        CreateButton(PChar(rsMbNo), IDNO);
      end;
    MB_RETRYCANCEL:
      begin
        CreateButton(PChar(rsMbRetry), IDRETRY);
        CreateButton(PChar(rsMbCancel), IDCANCEL);
      end;
    else
      begin
        { We have no buttons to show. Create the default of OK button }
        CreateButton(PChar(rsMbOK), IDOK);
      end;
  end;
  gtk_window_set_title(PGtkWindow(Dialog), lpCaption);
  gtk_window_set_position(PGtkWindow(Dialog), GTK_WIN_POS_CENTER);
  gtk_window_set_modal(PGtkWindow(Dialog), true);
  gtk_widget_show_all(Dialog);
  while ADialogResult = 0 do begin
    Application.HandleMessage;
  end;
  DestroyConnectedWidget(Dialog,true);
  Result:= ADialogResult;
end;

{------------------------------------------------------------------------------
  Function: MoveToEx
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.MoveToEx(DC: HDC; X, Y: Integer; OldPoint: PPoint): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := IsValidDC(DC);
  if Result then
    with DevCtx do
    begin
      if Assigned(OldPoint) then
        OldPoint^ := PenPos;
      PenPos := Point(X, Y)
    end;
end;

function TGtk2WidgetSet.OffsetRgn(RGN: HRGN; nXOffset, nYOffset: Integer): Integer;
var
  GdkRGN: PGDKRegion;
begin
  if not IsValidGDIObject(RGN) then
    Exit(Error);

  GdkRGN := {%H-}PGdiObject(RGN)^.GDIRegionObject;
  gdk_region_offset(GdkRGN, nXOffset, nYOffset);
  Result := RegionType(GdkRGN);
end;

{------------------------------------------------------------------------------
  Method:  PaintRgn
  Params:  DC: HDC; RGN: HRGN
  Returns: if the function succeeds

  Paints the specified region by using the brush currently selected into the
  device context.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.PaintRgn(DC: HDC; RGN: HRGN): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  CurGdiBrush: PGdiObject;
  CurHBrush: HBRUSH absolute CurGdiBrush;
begin
  CurGdiBrush := DevCtx.CurrentBrush;
  Result := IsValidDC(DC) and IsValidGDIObject(RGN) and IsValidGDIObject(CurHBrush);
  if Result then
    Result := FillRgn(DC, RGN, CurHBrush);
end;

{------------------------------------------------------------------------------
  Function: PeekMessage
  Params:  lpMsg        - Where it should put the message
           Handle       - Handle of the window (thread)
           wMsgFilterMin- Lowest MSG to grab
           wMsgFilterMax- Highest MSG to grab
           wRemoveMsg   - Should message be pulled out of the queue

  Returns: Boolean if an event was there
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.PeekMessage(var lpMsg: TMsg; Handle : HWND;
  wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): Boolean;
var
  vlItem : TGtkMessageQueueItem;
begin
  //TODO Filtering
  fMessageQueue.Lock;
  try
    vlItem := fMessageQueue.FirstMessageItem;
    Result := vlItem <> nil;
    if Result then begin
      lpMsg := vlItem.Msg^;
      if (wRemoveMsg and PM_REMOVE) = PM_REMOVE then
        fMessageQueue.RemoveMessage(vlItem,FPMF_Internal,true);
    end;
  finally
    fMessageQueue.UnLock;
  end;
end;

{------------------------------------------------------------------------------
  Method:  PolyBezier
  Params:  DC, Points, NumPts, Filled, Continous
  Returns: Boolean

  Use Polybezier to draw cubic Bézier curves. The first curve is drawn from the
  first point to the fourth point with the second and third points being the
  control points. If the Continuous flag is TRUE then each subsequent curve
  requires three more points, using the end-point of the previous Curve as its
  starting point, the first and second points being used as its control points,
  and the third point its end-point. If the continous flag is set to FALSE,
  then each subsequent Curve requires 4 additional points, which are used
  excatly as in the first curve. Any additonal points which do not add up to
  a full bezier(4 for Continuous, 3 otherwise) are ingored. There must be at
  least 4 points for an drawing to occur. If the Filled Flag is set to TRUE
  then the resulting Poly-Bézier will be drawn as a Polygon.

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer;
  Filled, Continuous: boolean): boolean;
begin
  Result := inherited PolyBezier(DC, Points, NumPts, Filled, Continuous);
end;

{------------------------------------------------------------------------------
  Method:   TGtk2WidgetSet.Polygon
  Params:   DC: HDC; Points: ^TPoint; NumPts: integer; Winding: Boolean;
  Returns:  Nothing

  Use Polygon to draw a closed, many-sided shape on the canvas, using the value
  of Pen. After drawing the complete shape, Polygon fills the shape using the
  value of Brush.
  The Points parameter is an array of points that give the vertices of the
  polygon.
  Winding determines how the polygon is filled. When Winding is True, Polygon
  fills the shape using the Winding fill algorithm. When Winding is False,
  Polygon uses the even-odd (alternative) fill algorithm.
  NumPts indicates the number of points to use.
  The first point is always connected to the last point.
  To draw a polygon on the canvas, without filling it, use the Polyline method,
  specifying the first point a second time at the end.
}
function TGtk2WidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer;
  Winding: boolean): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  i: integer;
  PointArray: PGDKPoint;
  Tmp, RGN : hRGN;
  ClipRect : TRect;
  DCOrigin: TPoint;
  OldNumPts: integer;
  ThePoints: array of types.TPoint;
  PThePoints: PPoint;
begin
  if not IsValidDC(DC) then Exit(False);

  if NumPts <= 0 then Exit(True);

  //Create a copy of the points so we can freely alter them
  SetLength(ThePoints{%H-}, NumPts);
  for i := 0 to NumPts - 1 do ThePoints[i] := Points[i];
  PThePoints := @ThePoints[0];

  DCOrigin := DevCtx.Offset;
  OldNumPts := NumPts;

  // create the PointsArray, which is a copy of Points moved by the DCOrigin
  // only if needed
  if DevCtx.IsNullPen and DevCtx.IsNullBrush then
    PointArray := nil
  else
  begin
    GetMem(PointArray, SizeOf(TGdkPoint) * (NumPts + 1)); // +1 for return line
    for i := 0 to NumPts - 1 do
    begin
      if DevCtx.HasTransf then
        ThePoints[I] := DevCtx.TransfPointIndirect(ThePoints[I]);
      PointArray[i].x := ThePoints[I].x + DCOrigin.X;
      PointArray[i].y := ThePoints[I].y + DCOrigin.Y;
    end;

    if (Points[NumPts-1].X <> Points[0].X) or
       (Points[NumPts-1].Y <> Points[0].Y) then
    begin
      // add last point to return to first
      PointArray[NumPts].x := PointArray[0].x;
      PointArray[NumPts].y := PointArray[0].y;
      Inc(NumPts);
    end;
  end;

  // first draw interior in brush color

  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  if not DevCtx.IsNullBrush then
  begin
    if Winding then
    begin
      // store old clipping
      Tmp := CreateEmptyRegion;
      GetClipRGN(DC, Tmp);
      // apply new clipping
      RGN := CreatePolygonRgn(PThePoints, OldNumPts, LCLType.Winding);
      ExtSelectClipRGN(DC, RGN, RGN_AND);
      DeleteObject(RGN);
      GetClipBox(DC, @ClipRect);

      // draw polygon area
      DevCtx.FillRect(ClipRect, HBrush({%H-}PtrUInt(DevCtx.GetBrush)), False);
      // restore old clipping
      SelectClipRGN(DC, Tmp);
      DeleteObject(Tmp);
    end else
    begin
      DevCtx.SelectBrushProps;
      DevCtx.RemovePixbuf;
      gdk_draw_polygon(DevCtx.Drawable, DevCtx.GC, 1, PointArray, NumPts);
    end;
  end;

  // draw outline
  if not DevCtx.IsNullPen
  then begin
    DevCtx.SelectPenProps;
    DevCtx.RemovePixbuf;
    gdk_draw_polygon(DevCtx.Drawable, DevCtx.GC, 0, PointArray, NumPts);
  end;

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}

  if PointArray <> nil then FreeMem(PointArray);
  SetLength(ThePoints,0);
  Result := True;
end;


function TGtk2WidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  i: integer;
  PointArray: PGDKPoint;
  DCOrigin, P: TPoint;
begin
  if not IsValidDC(DC) then Exit(False);
  
  if NumPts <= 0 then Exit(True);
  if DevCtx.IsNullPen then Exit(True);

  DCOrigin := DevCtx.Offset;

  GetMem(PointArray, SizeOf(TGdkPoint)*NumPts);
  for i:=0 to NumPts-1 do
  begin
    if DevCtx.HasTransf then
      P := DevCtx.TransfPointIndirect(Points[I])
    else
      P := Points[i];
    PointArray[i].x := P.x + DCOrigin.X;
    PointArray[i].y := P.y + DCOrigin.Y;
  end;

  // draw line
  DevCtx.SelectPenProps;
  Result := dcfPenSelected in DevCtx.Flags;
  if Result and not DevCtx.IsNullPen
  then begin
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    DevCtx.RemovePixbuf;
    gdk_draw_lines(DevCtx.Drawable, DevCtx.GC, PointArray, NumPts);
    {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
  end;

  FreeMem(PointArray);
end;

{------------------------------------------------------------------------------
  Function: PostMessage
  Params: Handle:
          Msg:
          wParam:
          lParam:
  Returns: True if succesful

  The PostMessage function places (posts) a message in the message queue and
  then returns without waiting.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.PostMessage(Handle: HWND; Msg: Cardinal; wParam: WParam;
  lParam: LParam): Boolean;

  function ParentPaintMessageInQueue: boolean;
  var
    Target: TControl;
    Parent: TWinControl;
    ParentHandle: hWnd;
  begin
    Result:=false;
    Target:=TControl(GetLCLObject({%H-}Pointer(Handle)));
    if not (Target is TControl) then exit;
    Parent:=Target.Parent;
    if (Target is TControl) then begin
      Parent:=Target.Parent;
      while Parent<>nil do begin
        ParentHandle:=Parent.Handle;
        if fMessageQueue.FindPaintMessage(ParentHandle)<>nil then begin
          Result:=true;
        end;
        Parent:=Parent.Parent;
      end;
    end;
  end;

  procedure CombinePaintMessages(NewMsg:PMsg);
  // combine NewMsg and OldMsg paint message into NewMsg and free OldMsg
  var
    vlItem : TGtkMessageQueueItem;
    NewData: TLMGtkPaintData;
    OldData: TLMGtkPaintData;
    OldMsg : PMsg;
  begin
    vlItem := fMessageQueue.FindPaintMessage(NewMsg^.Hwnd);
    if vlItem = nil then exit;
    OldMsg := vlItem.Msg;
    if OldMsg = nil then exit;
    if (NewMsg^.Message = LM_PAINT) or (OldMsg^.Message = LM_PAINT) then
    begin
      // LM_PAINT means: repaint all
      // convert NewMsg into a LM_PAINT if not already done
      if NewMsg^.Message <> LM_PAINT then
      begin
        FinalizePaintTagMsg(NewMsg);
        NewMsg^.Message:=LM_PAINT;
      end;
    end
    else
    if (NewMsg^.Message <> LM_GTKPAINT) then
      RaiseGDBException('CombinePaintMessages A unknown paint message')
    else
    if (OldMsg^.Message<>LM_GtkPAINT) then
      RaiseGDBException('CombinePaintMessages B unknown paint message')
    else
    begin
      // combine the two LM_GtkPAINT messages
      NewData := TLMGtkPaintData(NewMsg^.WParam);
      OldData := TLMGtkPaintData(OldMsg^.WParam);
      NewData.RepaintAll := NewData.RepaintAll or OldData.RepaintAll;
      if not NewData.RepaintAll then
      begin
        NewData.Rect.Left := Min(NewData.Rect.Left, OldData.Rect.Left);
        NewData.Rect.Top := Min(NewData.Rect.Top, OldData.Rect.Top);
        NewData.Rect.Right := Max(NewData.Rect.Right, OldData.Rect.Right);
        NewData.Rect.Bottom := Max(NewData.Rect.Bottom, OldData.Rect.Bottom);
      end;
    end;
    fMessageQueue.RemoveMessage(vlItem, FPMF_All, True);
  end;

var
  AMessage: PMsg;
begin
  Result := True;

  //debugln(['TGtk2WidgetSet.PostMessage ',dbgsname(GetLCLObject(Pointer(Handle)))]);
  New(AMessage);
  FillByte(AMessage^,SizeOf(TMsg),0);
  AMessage^.HWnd := Handle; // this is normally the main gtk widget
  AMessage^.Message := Msg;
  AMessage^.WParam := WParam;
  AMessage^.LParam := LParam;

  FMessageQueue.Lock;
  try
    if (AMessage^.Message = LM_PAINT) or (AMessage^.Message = LM_GTKPAINT) then
    begin
      { Obsolete, because InvalidateRectangle now works.

      // paint messages are the most expensive messages in the LCL
      // A paint message to a control will also repaint all child controls.
      // -> check if there is already a paint message for one of its parents
      // if yes, then skip this message
      if ParentPaintMessageInQueue then begin
        FinalizePaintTagMsg(AMessage^);
        exit;
      end;}

      // delete old paint message to this widget,
      // so that the widget repaints only once

      CombinePaintMessages(AMessage);
    end;

    FMessageQueue.AddMessage(AMessage);

    {$IFDEF USE_GTK_MAIN_OLD_ITERATION}
    if GetCurrentThreadId <> MainThreadID then
    begin
      // awake gtk loop
      // when the main thread is currently processing messages it will process
      // fMessageQueue.
      // But when the main thread is waiting for the next gtk message it will
      // wait for the next external event before processing fMessageQueue.
      // A g_idle_add can only be used if glib multithreading has been enabled
      // ToDo: Find out what we loose when enabling multithreading
      //       or find another way to wake up the gtk loop
      {$IFDEF EnabledGtkThreading}
        gdk_flush();
        g_main_context_wakeup(nil);
      {$ELSE}
        DebugLn(['TGtk2WidgetSet.PostMessage ToDo: wake up gtk']);
      {$ENDIF}
    end;
    {$ENDIF}
  finally
    FMessageQueue.UnLock;
  end;

  {$IFNDEF USE_GTK_MAIN_OLD_ITERATION}
  if GetCurrentThreadId <> MainThreadID then
  begin
    // old glib versions needs another way to wake up.
    if (glib_major_version = 2) and
      (glib_minor_version < 24) and (FMainPoll <> nil) then
      FMainPoll^.revents := 1;
    g_main_context_wakeup(g_main_context_default);
  end;
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Function: PtInRegion
  Params:   RGN: HRGN; X, Y: Integer
  Returns:  True if the specified point is in the region.

  Determines whether the specified point is inside the specified region.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.PtInRegion(RGN: HRGN; X, Y: Integer): Boolean;
begin
  Result := False;
  if not IsValidGDIObject(RGN) then
    exit;
  if ({%H-}PGdiObject(RGN)^.GDIBitmapObject <> nil) or
    ({%H-}PGdiObject(RGN)^.GDIPixbufObject <> nil) or
    ({%H-}PGdiObject(RGN)^.GDIPixmapObject.Image <> nil) then
  begin
    // issue #27080
    Result := False;
  end else
    Result := gdk_region_point_in({%H-}PGdiObject(RGN)^.GDIRegionObject, X, Y);
end;

{------------------------------------------------------------------------------
  Method:   RadialArc
  Params:   DC, left, top, right, bottom, sx, sy, ex, ey
  Returns:  Nothing

  Use RadialArc to draw an elliptically curved line with the current Pen. The
  values sx,sy, and ex,ey represent the starting and ending radial-points
  between which the Arc is drawn.
------------------------------------------------------------------------------}
function TGtk2WidgetSet.RadialArc(DC: HDC; left, top, right, bottom,
  sx, sy, ex, ey: Integer): Boolean;
begin
  Result := inherited RadialArc(DC, left, top, right, bottom, sx, sy, ex, ey);
end;

{------------------------------------------------------------------------------
  Method:   RadialChord
  Params:   DC, x1, y1, x2, y2, sx, sy, ex, ey
  Returns:  Nothing

  Use RadialChord to draw a filled Chord-shape on the canvas. The values sx,sy,
  and ex,ey represent the starting and ending radial-points between which
  the bounding-Arc is drawn.
------------------------------------------------------------------------------}
function TGtk2WidgetSet.RadialChord(DC: HDC; x1, y1, x2, y2,
  sx, sy, ex, ey: Integer): Boolean;
begin
  Result := inherited RadialChord(DC, x1, y1, x2, y2, sx, sy, ex, ey);
end;

{------------------------------------------------------------------------------
  Function: RealizePalette
  Params:  DC: HDC
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RealizePalette(DC: HDC): Cardinal;
begin
  Result := 0;
  if IsValidDC(DC)
  then with TGtkDeviceContext(DC) do
  begin

  end;
end;

{------------------------------------------------------------------------------
  Function: Rectangle
  Params:  DC: HDC; X1, Y1, X2, Y2: Integer
  Returns: Nothing
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  Left, Top, Width, Height: Integer;
  DCOrigin: TPoint;
  Brush: PGdiObject;
  ClipArea: TGdkRectangle;
begin
  if not IsValidDC(DC) then Exit(False);

  if DevCtx.HasTransf then
    DevCtx.TransfRect(X1, Y1, X2, Y2);

  CalculateLeftTopWidthHeight(X1, Y1, X2, Y2, Left, Top, Width, Height);
  if (Width = 0) or (Height = 0) then Exit(True);
  // X2, Y2 is not part of the rectangle
  dec(Width);
  dec(Height);

  // first draw interior in brush color
  DevCtx.SelectBrushProps;
  DCOrigin := DevCtx.Offset;

  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
    
  if not DevCtx.IsNullBrush then
  begin
    ClipArea := DevCtx.ClipRect;
    Brush := DevCtx.GetBrush;
    DevCtx.RemovePixbuf;
    if  (Brush^.GDIBrushFill = GDK_SOLID) and
      (IsBackgroundColor(TColor(Brush^.GDIBrushColor.ColorRef)))
    then
      StyleFillRectangle(DevCtx.Drawable, DevCtx.GC, Brush^.GDIBrushColor.ColorRef,
                         Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height, @ClipArea)
    else
      gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 1,
                         Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height);
  end;

  // Draw outline
  DevCtx.SelectPenProps;
  Result := dcfPenSelected in DevCtx.Flags;
  if Result and not DevCtx.IsNullPen
  then begin
    DevCtx.RemovePixbuf;
    gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 0,
                       Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height);
  end;

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
end;

{------------------------------------------------------------------------------
  Function: RectInRegion
  Params:   RGN: HRGN; ARect: TRect
  Returns:  True if any part of the specified rectangle lies within the
            boundaries of the region.

  Determines whether any part of the specified rectangle is within the boundaries
  of a region.

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RectInRegion(RGN: HRGN; ARect: TRect): Boolean;
var
  AGdkRect: TGdkRectangle;
begin
  //todo: sanity checks for valid handle etc.
  AGdkRect := GdkRectFromRect(ARect);
  Result := gdk_region_rect_in({%H-}PGdiObject(RGN)^.GDIRegionObject, @AGdkRect)
             <> GDK_OVERLAP_RECTANGLE_OUT;
end;

{------------------------------------------------------------------------------
  Function: RectVisible
  Params:  dc : hdc; ARect: TRect
  Returns: True if ARect is not completely clipped away.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RectVisible(dc: hdc; const ARect: TRect): Boolean;
begin
  Result := inherited RectVisible(dc,ARect);
end;

{------------------------------------------------------------------------------
  Function: RegroupMenuItem
  Params:  hndMenu: HMENU; GroupIndex: integer
  Returns: Nothing

  Move a menuitem into its group
  This function is called by the LCL, after some menuitems were regrouped to
  GroupIndex. The hndMenu is one of them.
  Update all radio groups.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RegroupMenuItem(hndMenu: HMENU; GroupIndex: integer
  ): Boolean;

const
  GROUPIDX_DATANAME = 'GroupIndex';

  function GetGroup: PGSList;
  var
    Item, orgList: PGList;
    parent : PGTKWidget;
  begin
    Result := nil;
    parent := gtk_widget_get_parent({%H-}Pointer(hndMenu));
    if parent = nil then Exit;

    Item := gtk_container_get_children(PGTKContainer(parent));
    orgList := Item;
    while Item <> nil do
    begin
      if (Item^.Data <> {%H-}Pointer(hndMenu)) // exclude ourself
      and gtk_is_radio_menu_item(Item^.Data)
      and (GroupIndex = Integer({%H-}PtrUInt(g_object_get_data(Item^.Data, GROUPIDX_DATANAME))))
      then begin
        Result := gtk_radio_menu_item_get_group (PGtkRadioMenuItem(Item^.Data));
        Exit;
      end;
      Item := Item^.Next;
    end;
    if Assigned(orgList) then
      g_list_free(orgList);
  end;

var
  RadioGroup: PGSList;
  //CurrentGroupIndex: Integer;
begin
  Result := False;

  if not gtk_is_radio_menu_item({%H-}Pointer(hndMenu))
  then begin
    DebugLn('WARNING: TGtk2WidgetSet.RegroupMenuItem: handle is not a GTK_RADIO_MENU_ITEM');
    Exit;
  end;

  //CurrentGroupIndex := integer({%H-}PtrUInt(g_object_get_data({%H-}Pointer(hndMenu), GROUPIDX_DATANAME)));

  // Update needed ?
 { if GroupIndex = CurrentGroupIndex
  then begin
    Result := True;
    Exit;
  end;}

  // Remove current group
  gtk_radio_menu_item_set_group({%H-}PGtkRadioMenuItem(hndMenu), nil);
  g_object_set_data({%H-}Pointer(hndMenu), GROUPIDX_DATANAME, nil);

  // Check remove only
 { if GroupIndex = 0
  then begin
    Result := True;
    Exit;
  end;  }

  // Try to find new group
  RadioGroup := GetGroup;

  // Set new group
  g_object_set_data({%H-}Pointer(hndMenu), GROUPIDX_DATANAME, {%H-}Pointer(PtrInt(GroupIndex)));
  if RadioGroup = nil
  then begin
    // We're the only member, get a group
    RadioGroup := gtk_radio_menu_item_group({%H-}PGtkRadioMenuItem(hndMenu))
  end
  else begin
    gtk_radio_menu_item_set_group({%H-}PGtkRadioMenuItem(hndMenu), RadioGroup);
  end;
                                                                    //radiogroup^.data
                                                                    //radiogroup^.next
  // Refetch newgroup list
  RadioGroup := gtk_radio_menu_item_group({%H-}PGtkRadioMenuItem(hndMenu));
  // Update checks
  UpdateRadioGroupChecks(RadioGroup);
  Result := True;
end;


{------------------------------------------------------------------------------
  Function: ReleaseCapture
  Params:  none
  Returns: True if succesful

  The ReleaseCapture function releases the mouse capture from a window
  and restores normal mouse input processing.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ReleaseCapture: Boolean;
begin
  SetCapture(0);
  Result := True;
end;

function TGtk2WidgetSet.ReleaseDC(hWnd: HWND; DC: HDC): Integer;
var
  aDC, pSavedDC: TGtkDeviceContext;
  g: TGDIType;
  CurGDIObject: PGDIObject;
begin
  //DebugLn(['[TGtk2WidgetSet.ReleaseDC] ',DC,'  ',FDeviceContexts.Count]);
  Result := 0;

  if (DC <> 0)
  then begin
    if FDeviceContexts.Contains({%H-}Pointer(DC))
    then begin
      aDC := TGtkDeviceContext(DC);

      // clear references to all GDI objects
      for g:=Low(TGDIType) to high(TGDIType) do begin
        {if aDC.GDIObjects[g]<>nil then
          if FindDCWithGDIObject(aDC.GDIObjects[g])=nil then
            RaiseGDBException('');}
        aDC.GDIObjects[g]:=nil; // clear the reference, decrease DCCount
      end;

      // Release all saved device contexts (the owned GDI objects will be freed)
      pSavedDC:=aDC.SavedContext;
      if pSavedDC<>nil then begin
        ReleaseDC(0,HDC(pSavedDC));
        aDC.SavedContext:=nil;
      end;

      //DebugLn(['TGtk2WidgetSet.ReleaseDC DC=',dbgs(TGtkDeviceContext(aDC)),' ClipRegion=',dbgs(aDC.ClipRegion)]);
      // free all owned GDI objects
      for g:=Low(TGDIType) to high(TGDIType) do begin
        CurGDIObject:=aDC.OwnedGDIObjects[g];
        if CurGDIObject<>nil then begin
          if CurGDIObject^.Owner<>aDC then
            RaiseGDBException('');
          DeleteObject(HGDIOBJ({%H-}PtrUInt(CurGDIObject)));
          if aDC.OwnedGDIObjects[g]<>nil then
            RaiseGDBException('');
        end;
      end;

      //DebugLn(['TGtk2WidgetSet.ReleaseDC DC=',dbghex(PtrInt(DC)),' Font=',dbghex(PtrInt(aDC.CurrentFont))]);

      {FreeGDIColor(aDC.CurrentTextColor);
      FreeGDIColor(aDC.CurrentBackColor);}

      try
        { On root window, we don't allocate a graphics context and so we do not free}
        if aDC.HasGC then
        begin
          gdk_gc_unref(aDC.GC);
          aDC.GC:=nil;
        end;
      except
        on E:Exception do begin
          // Nothing, just try to unref it
          // (it segfaults if the window doesnt exist anymore :-)
          DebugLn('TGtk2WidgetSet.ReleaseDC: ',E.Message);
        end;
      end;

      DisposeDC(aDC);
      Result := 1;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: RemoveProp
  Params: Handle: Handle of the object
          Str: Name of the property to remove
  Returns: The handle of the property (0=failure)

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RemoveProp(Handle: hwnd; Str: PChar): THandle;
begin
  g_object_set_data({%H-}PGObject(handle), Str, nil);
  Result := 1;
end;

{------------------------------------------------------------------------------
  Function: RestoreDC
  Params:  none
  Returns: Nothing


-------------------------------------------------------------------------------}
function TGtk2WidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  SavedDevCtx: TGtkDeviceContext;
begin
  if not IsValidDC(DC) then Exit(False);
  if SavedDC <= 0 then Exit(False);
  repeat
    SavedDevCtx := DevCtx.SavedContext;
    Dec(SavedDC);

    // TODO copy bitmap too
    // clear the GDIObjects in pSavedDC, so they are not freed by DeleteDC
    Result := DevCtx.CopyDataFrom(SavedDevCtx, True, True, True);
    DevCtx.SavedContext := SavedDevCtx.SavedContext;
    SavedDevCtx.SavedContext := nil;
    DevCtx.SelectRegion;

    // free saved DC
    DeleteDC(HDC(SavedDevCtx));
  until SavedDC <= 0;
end;

{------------------------------------------------------------------------------
  Method:   RoundRect
  Params:   X1, Y1, X2, Y2, RX, RY
  Returns:  If succesfull

  Draws a Rectangle with optional rounded corners. RY is the radial height
  of the corner arcs, RX is the radial width. If either is less than or equal to
  0, the routine simly calls to standard Rectangle.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.RoundRect(DC : hDC; X1, Y1, X2, Y2: Integer;
  RX,RY : Integer): Boolean;
begin
  Result := inherited RoundRect(DC, X1, Y1, X2, Y2, RX, RY);
end;

{------------------------------------------------------------------------------
  Function: SaveDc
  Params:  DC: a DC to save
  Returns: 0 if the functions fails otherwise a positive integer identifing
           the saved DC

  The SaveDC function saves the current state of the specified device
  context (DC) by copying its elements to a context stack.
-------------------------------------------------------------------------------}
function TGtk2WidgetSet.SaveDC(DC: HDC): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
  aSavedDC: TGtkDeviceContext;
begin
  Result := 0;
  if IsValidDC(DC) then
  begin
    aSavedDC := NewDC;
    aSavedDC.CopyDataFrom(DevCtx, False, True, False);
    aSavedDC.SavedContext := DevCtx.SavedContext;
    DevCtx.SavedContext:= aSavedDC;
    Result := 1;
  end;
end;

{------------------------------------------------------------------------------
  Function: ScreenToClient
  Params: Handle:
          P:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ScreenToClient(Handle : HWND; var P : TPoint) : Integer;
var
  X, Y: Integer;
  Widget: PGTKWidget;
  Window: PGdkWindow;
Begin
  if Handle = 0 then
  begin
    X := 0;
    Y := 0;
  end else
  begin
    Widget := GetFixedWidget({%H-}pgtkwidget(Handle));
    if Widget = nil then
      Widget := {%H-}pgtkwidget(Handle);
    if Widget = nil then
    begin
      X := 0;
      Y := 0;
    end else
    begin
      Window := GetControlWindow(Widget);
      {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
      if Window <> nil then
      begin
        gdk_window_get_origin(Window, @X, @Y);
        // set pos to client coords. issue #21366
        if GTK_WIDGET_NO_WINDOW(Widget) and (gtk_widget_get_parent(Widget) <> nil) then
        begin
          P.X := P.X - X - Widget^.allocation.x;
          P.Y := P.Y - Y - Widget^.allocation.y;
          Result := -1;
          exit;
        end;

      end else
      begin
        X:=0;
        Y:=0;
      end;
      {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
    end;
  end;

  //DebugLn('[TGtk2WidgetSet.ScreenToClient] ',x,',',y,' P=',P.X,',',P.Y);
  dec(P.X, X);
  dec(P.Y, Y);
  Result := -1;
end;

{------------------------------------------------------------------------------
  Function: ScrollWindowEx
  Params:  hWnd:       handle of window to scroll
           dx:         horizontal amount to scroll
           dy:         vertical amount to scroll
           prcScroll:  pointer to scroll rectangle
           prcClip:    pointer to clip rectangle
           hrgnUpdate: handle of update region
           prcUpdate:  pointer to update rectangle
           flags:      scrolling flags

  Returns: True if succesfull;

  The ScrollWindowEx function scrolls the content of the specified window's
  client area
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer; prcScroll, prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT): Boolean;
var
  Widget: PGtkWidget;
  Window: PGdkWindow;
  {$ifdef GTK_2_8}
  Region: PGdkRegion;
  RClient, RFullSource, RUsableSource, RTarget, RUsableTarget: TRect;
  Rect1: TGdkRectangle;
  Rect2: TRect; // area to invalidate
  WidgetInfo: PWidgetInfo;
  {$ENDIF}
begin
  Result := False;
  if (dy = 0) and (dx = 0) then exit;
  {$IFDEF DisableGtk2ScrollWindow}
  exit;
  {$ENDIF}
  // prcScroll, prcClip are not supported under gdk yet
  if (hWnd = 0) then
    exit;
  // or (prcScroll <> nil) or (prcClip <> nil) then Exit;

  Widget := {%H-}pgtkwidget(hWnd);
  Widget := GetFixedWidget(Widget);
  if Widget = nil then exit;
  Window:=GetControlWindow(Widget);
  if Window = nil then exit;

  Result := true;

  {$ifdef GTK_2_8}
  RClient.Left := 0;//Widget^.Allocation.Left;
  RClient.Top := 0; //Widget^.Allocation.Top;
  RClient.Right := Widget^.Allocation.width;
  RClient.Bottom := Widget^.Allocation.height;
  RFullSource := RClient;
  {$ifdef VerboseScrollWindowEx}
  DebugLn(['ScrollWindowEx A RClient=', dbgs(RClient),' dy=',dy, ' scroll=',dbgs(prcScroll^), ' clip=',dbgs(prcClip^)]);
  {$ENDIF}

  // Any part of RFullSource, that is not targeted by the move must later be invalidated
  if PrcScroll <> nil then
  begin
    RFullSource.Left   := Max(RClient.Left,   PrcScroll^.Left);
    RFullSource.Top    := Max(RClient.Top,    PrcScroll^.Top);
    RFullSource.Right  := Min(RClient.Right,  PrcScroll^.Right);
    RFullSource.Bottom := Min(RClient.Bottom, PrcScroll^.Bottom);
  end;

  // Target is expected to be completly filled with valid content by move,
  // any part that can not be filled must be invalidated
  RTarget.Left   := Max(RClient.Left,   RFullSource.Left + dx);
  RTarget.Top    := Max(RClient.Top,    RFullSource.Top + dy);
  RTarget.Right  := Min(RClient.Right,  RFullSource.Right + dx);
  RTarget.Bottom := Min(RClient.Bottom, RFullSource.Bottom + dy);
  if (PrcClip <> nil) then begin
    RTarget.Left   := Max(RTarget.Left,   prcClip^.Left);
    RTarget.Top    := Max(RTarget.Top,    prcClip^.Top);
    RTarget.Right  := Min(RTarget.Right,  prcClip^.Right);
    RTarget.Bottom := Min(RTarget.Bottom, prcClip^.Bottom);
  end;

  // Only Source that will fit into target
  RUsableSource.Left   := Max(RTarget.Left - dx,   RFullSource.Left);
  RUsableSource.Top    := Max(RTarget.Top - dy,    RFullSource.Top);
  RUsableSource.Right  := Min(RTarget.Right - dx,  RFullSource.Right);
  RUsableSource.Bottom := Min(RTarget.Bottom - dy, RFullSource.Bottom);
  {$ifdef VerboseScrollWindowEx}
  DebugLn(['ScrollWindowEx B RFullSource=', dbgs(RFullSource), ' RUsableSource=', dbgs(RUsableSource)]);
  {$ENDIF}

  // And also, only Source that is valid
  WidgetInfo := GetWidgetInfo(Widget);
  if WidgetInfo <> nil then begin
    {$ifdef VerboseScrollWindowEx}
    DebugLn(['ScrollWindowEx C ', dbgs(WidgetInfo^.UpdateRect)]);
    {$ENDIF}
    // exclude allready invalidated area
    // "UpdateRect.Bottom > 0" => there is an UpdateRect / Top is valid
    if (dy < 0) and (WidgetInfo^.UpdateRect.Bottom > 0) then
      RUsableSource.Bottom := Min(RUsableSource.Bottom, WidgetInfo^.UpdateRect.Top);
    if (dy > 0) and (RUsableSource.Top < WidgetInfo^.UpdateRect.Bottom) then
      RUsableSource.Top := WidgetInfo^.UpdateRect.Bottom;

    if (dx < 0) and (WidgetInfo^.UpdateRect.Right > 0) then
      RUsableSource.Right := Min(RUsableSource.Right, WidgetInfo^.UpdateRect.Left);
    if (dx > 0) and (RUsableSource.Left < WidgetInfo^.UpdateRect.Right) then
      RUsableSource.Left := WidgetInfo^.UpdateRect.Right;
  end;
  {$ifdef VerboseScrollWindowEx}
  DebugLn(['ScrollWindowEx D RUsableSource=', dbgs(RUsableSource)]);
  {$ENDIF}

  // TODO: content moved into currently invalidated space, may reduce the inval rect
  // All of RUsableTarget should be validated;
  RUsableTarget.Left   := Max(RTarget.Left,   RUsableSource.Left + dx);
  RUsableTarget.Top    := Max(RTarget.Top,    RUsableSource.Top + dy);
  RUsableTarget.Right  := Min(RTarget.Right,  RUsableSource.Right + dx);
  RUsableTarget.Bottom := Min(RTarget.Bottom, RUsableSource.Bottom + dy);
  {$ifdef VerboseScrollWindowEx}
  DebugLn(['ScrollWindowEx D RUsableTarget=', dbgs(RUsableTarget)]);
  {$ENDIF}

  Rect1 := GdkRectFromRect(RUsableSource);

  if (Rect1.height > 0) and (Rect1.width > 0) then begin
    Region := gdk_region_rectangle(@Rect1);
    gdk_window_move_region(Window, Region, dx, dy);
    gdk_region_destroy(Region);

    if (flags and SW_INVALIDATE) <> 0 then begin
      //invalidate
      If RUsableTarget.Left > RFullSource.Left then begin
        Rect2 := RFullSource;
        Rect2.Right:= RUsableTarget.Left;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate Src Left', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
        if (prcUpdate <> nil) and (dx > 0) then prcUpdate^ := Rect2;
      end;

      If RUsableTarget.Right < RFullSource.Right then begin
        Rect2 := RFullSource;
        Rect2.Left:= RUsableTarget.Right;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate Src Right', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
        if (prcUpdate <> nil) and (dx < 0) then prcUpdate^ := Rect2;
      end;

      If RUsableTarget.Top > RFullSource.Top then begin
        Rect2 := RFullSource;
        Rect2.Bottom:= RUsableTarget.Top;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate Src Top', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
        if (prcUpdate <> nil) and (dy > 0) then prcUpdate^ := Rect2;
      end;

      If RUsableTarget.Bottom < RFullSource.Bottom then begin
        Rect2 := RFullSource;
        Rect2.Top:= RUsableTarget.Bottom;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate Src Bottom', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
        if (prcUpdate <> nil) and (dy < 0) then prcUpdate^ := Rect2;
      end;


      If RUsableTarget.Left > RTarget.Left then begin
        Rect2 := RTarget;
        Rect2.Right:= RUsableTarget.Left;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate TARGET Left', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
      end;

      If RUsableTarget.Right < RTarget.Right then begin
        Rect2 := RTarget;
        Rect2.Left:= RUsableTarget.Right;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate TARGET Right', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
      end;

      If RUsableTarget.Top > RTarget.Top then begin
        Rect2 := RTarget;
        Rect2.Bottom:= RUsableTarget.Top;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate TARGET Top', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
      end;

      If RUsableTarget.Bottom < RTarget.Bottom then begin
        Rect2 := RTarget;
        Rect2.Top:= RUsableTarget.Bottom;
        {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate TARGET Bottom', dbgs(Rect2)]);{$ENDIF}
        InvalidateRect(hWnd, @Rect2, false);
      end;
    end;
  end
  else begin
    if (flags and SW_INVALIDATE) <> 0 then begin
      // invalidate, nothing to scroll
      {$ifdef VerboseScrollWindowEx}DebugLn(['ScrollWindowEx Invalidate all', dbgs(RUsableSource)]);{$ENDIF}
      InvalidateRect(hWnd, @RFullSource, false);
      InvalidateRect(hWnd, @RTarget, false);
    end
    else
      Result := False;
  end;
  {$ELSE}
  gdk_window_scroll(Window, dx, dy);
  Result := true;
  {$ENDIF}
end;


{------------------------------------------------------------------------------
  Function: SelectClipRGN
  Params:  DC, RGN
  Returns: longint

  Sets the DeviceContext's ClipRegion. The Return value
  is the new clip regions type, or ERROR.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SelectClipRGN(DC: hDC; RGN: HRGN): Longint;
var
  DevCtx: TGtkDeviceContext absolute DC;

  RegObj: PGdkRegion;
  DCOrigin: TPoint;
  OldClipRegion: PGDIObject;
begin
  if not IsValidDC(DC) then Exit(ERROR);

  // clear old clipregion
  if Assigned(DevCtx.ClipRegion) then
  begin
    OldClipRegion := DevCtx.ClipRegion;
    DevCtx.ClipRegion := nil;// decrease DCCount
    if OldClipRegion = DevCtx.OwnedGDIObjects[gdiRegion] then
      DeleteObject(HGDIOBJ({%H-}PtrUInt(OldClipRegion)));
  end;

  if RGN = 0 then
  begin
    DevCtx.SelectRegion;
    Exit(NULLREGION);
  end;

  if IsValidGDIObject(RGN) then
  begin
    DevCtx.ClipRegion := {%H-}PGdiObject(CreateRegionCopy(RGN));
    DevCtx.OwnedGDIObjects[gdiRegion] := DevCtx.ClipRegion;
    RegObj := DevCtx.ClipRegion^.GDIRegionObject;
    DCOrigin := DevCtx.Offset;

    gdk_region_offset(RegObj, DCOrigin.x, DCOrigin.Y);
    DevCtx.SelectRegion;

    Exit(RegionType(RegObj));
  end;
  
  // error handling
  Result := ERROR;
  DebugLn('WARNING: [TGtk2WidgetSet.SelectClipRGN] Invalid RGN');
  {$ifdef TraceGdiCalls}
  DebugLn();
  DebugLn('TraceCall for invalid object: ');
  DumpBackTrace(PgdiObject(RGN)^.StackAddrs);
  DebugLn();
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: SelectObject
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;

var
  DevCtx: TGtkDeviceContext absolute DC;
  GDIObject: PGdiObject absolute GDIObj;
  ResultObj: PGdiObject absolute Result;
  

  procedure RaiseInvalidGDIType;
  begin
    RaiseGDBException('TGtk2WidgetSet.SelectObject Invalid GDIType '+IntToStr(ord({%H-}PGdiObject(GDIObj)^.GDIType)));
  end;
  
  {$ifdef DebugLCLComponents}
  procedure DebugInvalidDC;
  begin
    DebugLn(['TGtk2WidgetSet.SelectObject DC=',dbghex(DC),' IsValidDC(DC)=',IsValidDC(DC),' GDIObj=',dbghex(GDIObj)]);
    DumpStack;
    DebugLn(['DebugInvalidGDIObject DC:']);
    Debugln(DebugDeviceContexts.GetInfo(Pointer(DC),true));
  end;

  procedure DebugInvalidGDIObject;
  begin
    DebugLn(['TGtk2WidgetSet.SelectObject DC=',dbghex(DC),' GDIObj=',dbghex(GDIObj),' IsValidGDIObject(GDIObj)=',IsValidGDIObject(GDIObj)]);
    DumpStack;
    DebugLn(['DebugInvalidGDIObject GDIObj:']);
    Debugln(DebugGdiObjects.GetInfo(Pointer(GDIObj),true));
  end;
  {$endif}
  
begin
  Result := 0;

  if not IsValidDC(DC)
  then begin
    {$ifdef DebugLCLComponents}
    DebugInvalidDC;
    {$endif}
    Exit;
  end;

  if not IsValidGDIObject(GDIObj)
  then begin
    {$ifdef DebugLCLComponents}
    DebugInvalidGDIObject;
    {$endif}
    Exit;
  end;
  case GDIObject^.GDIType of
    gdiPen,
    gdiBitmap:
      ResultObj := DevCtx.SelectObject(GDIObject);

    gdiBrush: begin
      ResultObj := DevCtx.GetBrush;// always create, because a valid GDIObject is needed to restore
      if DevCtx.CurrentBrush = GDIObject then Exit;
      
      DevCtx.CurrentBrush := GDIObject;
      DevCtx.SelectedColors := dcscCustom;
    end;

    gdiFont: begin
      ResultObj := DevCtx.GetFont;// always create, because a valid GDIObject is needed to restore
      if (DevCtx.CurrentFont = GDIObject) and not DevCtx.HasTransf then Exit;
      
      DevCtx.CurrentFont := GDIObject;

      DevCtx.SetTextMetricsValid(False);
      DevCtx.SelectedColors := dcscCustom;
    end;

    gdiRegion: begin
      ResultObj := DevCtx.ClipRegion;
      if DevCtx.GC <> nil
      then SelectClipRGN(DC, GDIObj)
      else DevCtx.ClipRegion := nil;
    end;

  else
    RaiseInvalidGDIType;
  end;
end;

{------------------------------------------------------------------------------
  Function: SelectPalette
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SelectPalette(DC: HDC; Palette: HPALETTE; ForceBackground: Boolean): HPALETTE;
begin
  //TODO: Implement this;
  Result := 0;
end;

{------------------------------------------------------------------------------
  Function: SendMessage
  Params: hWnd:
          Msg:
          wParam:
          lParam:
  Returns:

  The SendMessage function sends the specified message to a window or windows.
  The function calls the window procedure for the specified window and does
  not return until the window procedure has processed the message.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SendMessage(HandleWnd: HWND; Msg: Cardinal; wParam: WParam;
  lParam: LParam): LResult;
var
  OldMsg: Cardinal;

  procedure PreparePaintMessage({%H-}TargetObject: TObject; var AMessage: TLMessage);
  var
    GtkPaintData: TLMGtkPaintData;
    OldGtkPaintMsg: TLMGtkPaint;
  begin
    (* MG: old trick. Not used anymore, but it might be, that someday there
           will be component, that works better with this, so it is kept.
    { The LCL repaints controls in a top-down hierachy. But the gtk sends
      gtkdraw events bottom-up. So, controls at the bottom are repainted
      many times. To avoid this the queue is checked for LM_PAINT messages
      for the parent control. If there is a parent LM_PAINT, this message
      is ignored.}
    if (Target is TControl) then begin
      ParentControl:=TControl(Target).Parent;
      while ParentControl<>nil do begin
        ParentHandle:=TWinControl(ParentControl).Handle;
        if FindPaintMessage(ParentHandle)<>nil then begin
          {$IFDEF VerboseDsgnPaintMsg}
          if (csDesigning in TComponent(Target).ComponentState) then begin
            DebugLn('TGtk2WidgetSet.SendMessage A ',
              TComponent(Target).Name,':',Target.ClassName,
              ' Parent Message found: ',ParentControl.Name,':',ParentControl.ClassName
              );
          end;
          {$ENDIF}
          if Msg=LM_PAINT then
            ReleaseDC(0,AMessage.WParam);
          //exit;
        end;
        ParentControl:=ParentControl.Parent;
      end;
    end; *)
    {$IFDEF VerboseDsgnPaintMsg}
    if (csDesigning in TComponent(TargetObject).ComponentState) then begin
      write('TGtk2WidgetSet.SendMessage B ',
        TComponent(TargetObject).Name,':',TargetObject.ClassName,
        ' GtkPaint=',AMessage.Msg=LM_GtkPAINT);
      if AMessage.Msg=LM_GtkPAINT then begin
        if AMessage.wParam<>0 then begin
          with TLMGtkPaintData(AMessage.wParam) do begin
            write(' GtkPaintData(',
              ' Widget=',DbgS(Widget),'=',GetWidgetClassName(Widget),
              ' State=',State,
              ' Rect=',Rect.Left,',',Rect.Top,',',Rect.Right,',',Rect.Bottom,
              ' RepaintAll=',RepaintAll,
              ')');
          end;
        end else begin
          write(' GtkPaintData=nil');
        end;
      end;
      DebugLn('');
    end;
    {$ENDIF}
    
    if AMessage.Msg = LM_GTKPAINT
    then begin
      OldGtkPaintMsg := TLMGtkPaint(AMessage);
      GtkPaintData := OldGtkPaintMsg.Data;
      // convert LM_GTKPAINT to LM_PAINT
      AMessage := TLMessage(GtkPaintMessageToPaintMessage(
                                                TLMGtkPaint(AMessage), False));
      GtkPaintData.Free;
    end;
  end;

  procedure DisposePaintMessage({%H-}TargetObject: TObject; var AMessage: TLMessage);
  begin
    if OldMsg = LM_GTKPAINT then
    begin
      FinalizePaintMessage(@AMessage);
    end
    else
    if (AMessage.Msg = LM_PAINT) and (AMessage.WParam <> 0) then
    begin
      // free DC
      ReleaseDC(0, AMessage.WParam);
      AMessage.WParam := 0;
    end;
  end;

var
  AMessage: TLMessage;
  Target: TObject;
begin
  OldMsg := Msg;

  AMessage.Msg := Msg;
  AMessage.WParam := WParam;
  AMessage.LParam := LParam;
  AMessage.Result := 0;

  Target := GetLCLObject({%H-}Pointer(HandleWnd));

  if Target <> nil then
  begin
    if (Msg = LM_PAINT) or (Msg = LM_GTKPAINT) then
    begin
      PreparePaintMessage(Target,AMessage);
      Result := DoDeliverPaintMessage(Target, TLMPaint(AMessage));
    end
    else
      Result := DeliverMessage(Target, AMessage); // deliver it

    if (Msg = LM_PAINT) or (Msg = LM_GTKPAINT) then
      DisposePaintMessage(Target, AMessage);
  end;
end;

{------------------------------------------------------------------------------
  function SetActiveWindow(Handle: HWND): HWND;


------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetActiveWindow(Handle: HWND): HWND;
begin
  // ToDo
  Result := GetActiveWindow;
  if (Handle <> 0) and GtkWidgetIsA({%H-}PGtkWidget(Handle),GTK_TYPE_WINDOW) then
  begin
    if GTK_WIDGET_VISIBLE({%H-}PGtkWidget(Handle)) then
      gtk_window_present({%H-}PGtkWindow(Handle));
  end else
    Result := 0; // if not active window return error
end;

{------------------------------------------------------------------------------
  Function: SetBkColor        pbd
  Params:  DC:    Device context to change the text background color
           Color: RGB Tuple
  Returns: Old Background color


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetBkColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  Result := CLR_INVALID;
  if IsValidDC(DC)
  then begin
    with TGtkDeviceContext(DC) do
    begin
      Result := CurrentBackColor.ColorRef;
      SetGDIColorRef(CurrentBackColor,Color);
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: SetBkMode
  Params: DC:
          bkMode:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetBkMode(DC: HDC; bkMode: Integer) : Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  // Your code here
  Result := DevCtx.BkMode;
  DevCtx.BkMode := bkMode;
end;

{------------------------------------------------------------------------------
  Function: SetCapture
  Params:  Value: Handle of window to capture
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCapture(AHandle: HWND): HWND;
var
  Widget: PGtkWidget;
  CaptureWidget: PGtkWidget;
  {$IfDef VerboseMouseCapture}
  toplevel: PGtkWidget;
  WndGroup: PGtkWindowGroup;
  DefWndGroup: PGtkWindowGroup;
  {$EndIf}
begin
  Widget := {%H-}PGtkWidget(AHandle);
  {$IfDef VerboseMouseCapture}
  DebugLn('TGtk2WidgetSet.SetCapture Widget=[',GetWidgetDebugReport(Widget),'] gtk=[',GetWidgetDebugReport(gtk_grab_get_current),'] MouseCaptureWidget=[',GetWidgetDebugReport(MouseCaptureWidget),']');
  {$EndIf}

  // return old capture handle
  Result := GetCapture;

  if (Result <> 0) then begin
    {$IfDef VerboseMouseCapture}
    DebugLn('TGtk2WidgetSet.SetCapture gtk_grab_remove=[',GetWidgetDebugReport(gtk_grab_get_current),']');
    {$EndIf}
    gtk_grab_remove(gtk_grab_get_current);
  end;
  if (MouseCaptureWidget<>nil) and (gtk_grab_get_current=nil)
  and (GTK_WIDGET_HAS_GRAB(MouseCaptureWidget))
  then begin
    {$IfDef VerboseMouseCapture}
    DebugLn('TGtk2WidgetSet.SetCapture gtk_grab_get_current=nil, but GTK_WIDGET_HAS_GRAB(MouseCaptureWidget)=true =>  gtk_grab_remove=[',GetWidgetDebugReport(MouseCaptureWidget),']');
    {$EndIf}
    gtk_grab_remove(MouseCaptureWidget);
  end;

  MouseCaptureWidget := nil;

  if Widget = nil then
    exit;

  CaptureWidget := GetDefaultMouseCaptureWidget(Widget);
  if CaptureWidget = nil then begin
    {$IfDef VerboseMouseCapture}
    DebugLn('TGtk2WidgetSet.SetCapture GetDefaultMouseCaptureWidget failed for widget=[',GetWidgetDebugReport(Widget),']');
    {$EndIf}
    exit;
  end;
  {$IfDef VerboseMouseCapture}
  // ubuntu liboverlay intercepts gtk_grab_add for LCLWinapiClient
  // ToDo: find out how to grab LCLWinapiClient with ubuntu liboverlay
  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLED_WINDOW) then
  begin
    debugln(['TGtk2WidgetSet.SetCapture is api widget ',
      ' widget=',GetWidgetClassName(Widget),
      ' container.container.focus_child=',GetWidgetClassName(PGtkScrolledWindow(Widget)^.container.container.focus_child),
      ' container.child=',GetWidgetClassName(PGtkScrolledWindow(Widget)^.container.child),
      '']);
    //CaptureWidget:=PGtkScrolledWindow(Widget)^.container;
  end;
  {$EndIf}

  {$IfDef VerboseMouseCapture}
  DebugLn(['TGtk2WidgetSet.SetCapture gtk_grab_add=[',GetWidgetDebugReport(CaptureWidget),'] has_grab=',gtk_widget_has_grab(CaptureWidget),' is_sensitive=',gtk_widget_is_sensitive(CaptureWidget)]);
  toplevel := gtk_widget_get_toplevel(CaptureWidget);
  if (toplevel<>nil)
  and (ord(gdk_window_get_window_type (toplevel^.window)) = GDK_WINDOW_OFFSCREEN_lcl)
  then begin
    debugln(['WARNING: TGtk2WidgetSet.SetCapture capturewidget is offscreen']);
  end;
  WndGroup := GetGtkWindowGroup(CaptureWidget);
  DefWndGroup:=GetGtkWindowGroup(CaptureWidget);
  debugln(['TGtk2WidgetSet.SetCapture WndGroup=',dbgs(WndGroup),' DefWndGroup=',dbgs(DefWndGroup),' same=',WndGroup=DefWndGroup]);
  // Note: liboverlay: gtk_grab_add sets gtk_widget_has_grab, but gtk_grab_get_current returns nil
  // ToDo: check window group
  {$EndIf}
  MouseCaptureWidget := CaptureWidget;
  gtk_grab_add(CaptureWidget);
  if gtk_grab_get_current=CaptureWidget then
  begin
    {$IfDef VerboseMouseCapture}
    DebugLn('TGtk2WidgetSet.SetCapture gtk_grab_add success: gtk_grab_get_current=[',GetWidgetDebugReport(gtk_grab_get_current),']')
    {$EndIf}
  end
  else begin
    {$IfDef VerboseMouseCapture}
    if gtk_widget_has_grab(CaptureWidget) then
      DebugLn('WARNING: TGtk2WidgetSet.SetCapture gtk_grab_add failed (partial success): gtk_grab_get_current=[',GetWidgetDebugReport(gtk_grab_get_current),'] has_grab=true')
    else
      DebugLn('WARNING: TGtk2WidgetSet.SetCapture gtk_grab_add failed (complete): gtk_grab_get_current=[',GetWidgetDebugReport(gtk_grab_get_current),'] has_grab=false');
    {$EndIf}
  end;

  if MouseCaptureWidget<>nil then
    SendMessage(HWnd({%H-}PtrUInt(MouseCaptureWidget)), LM_CAPTURECHANGED, 0, Result);
end;

{------------------------------------------------------------------------------
  Function: SetCaretPos
  Params:  new position x, y
  Returns: true on success

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCaretPos(X, Y: Integer): Boolean;
var
  FocusObject: PGTKObject;
begin
  FocusObject := {%H-}PGTKObject(GetFocus);
  Result:=SetCaretPosEx({%H-}PtrUInt(FocusObject),X,Y);
end;

{------------------------------------------------------------------------------
  Function: SetCaretPos
  Params:  new position x, y
  Returns: true on success

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCaretPosEx(Handle: HWnd; X, Y: Integer): Boolean;
var
  GtkObject: PGTKObject;
begin
  GtkObject := {%H-}PGTKObject(Handle);
  Result := GtkObject <> nil;

  if Result then begin
    if gtk_type_is_a(g_object_type(GtkObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_SetCaretPos(PGTKAPIWidget(GtkObject), X, Y);
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end;
end;

{------------------------------------------------------------------------------
  Function: SetCaretRespondToFocus
  Params:  handle : Handle of a TWinControl
           ShowHideOnFocus: true = caret is hidden on focus lost
  Returns: true on success

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  if handle<>0 then begin
    if gtk_type_is_a(g_object_type({%H-}PGTKObject(handle)), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_SetCaretRespondToFocus({%H-}PGTKAPIWidget(handle),
        ShowHideOnFocus);
      Result:=true;
    end
    else begin
      Result := False;
    end;
  end else
    Result:=false;
end;

{------------------------------------------------------------------------------
  Function: SetCursor
  Params  : hCursor - cursor handle
  Returns : current cursor
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
begin
  // set global gtk cursor
  Result := FGlobalCursor;
  if ACursor = FGlobalCursor then Exit;
  if ACursor = Screen.Cursors[crDefault]
  then SetGlobalCursor(0)
  else SetGlobalCursor(ACursor);
  FGlobalCursor := ACursor;
end;

{------------------------------------------------------------------------------
  Function: SetCursorPos
  Params: X:
          Y:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetCursorPos(X, Y: Integer): Boolean;
{$ifdef GTK_2_8}
begin
  gdk_display_warp_pointer(gdk_display_get_default(), gdk_screen_get_default(), X, Y);
  Result := True;
end;
{$else GTK_2_8}
{$IFDEF HasX}
var
  dpy: PDisplay;
begin
  Result := False;
  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}
  try
    dpy := gdk_display;
    XWarpPointer(dpy, 0, RootWindow(dpy, DefaultScreen(dpy)), 0, 0, 0, 0, X, Y);
    Result := True;
    XFlush(dpy);
  finally
    {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
  end;
end;
{$ELSE HasX}
begin
  Result := False;
  DebugLn('TGtk2WidgetSet.SetCursorPos not implemented for this platform');
  // Can this call TWin32WidgetSet.SetCursorPos?
end;
{$ENDIF HasX}
{$endif GTK_2_8}

{------------------------------------------------------------------------------
  Function: SetFocus
  Params:  hWnd: Handle of new focus window
  Returns: The old focus window

  The SetFocus function sets the keyboard focus to the specified window
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetFocus(hWnd: HWND): HWND;
{off $DEFINE VerboseFocus}
var
  Widget, TopLevel, NewFocusWidget: PGtkWidget;
  Info: PWidgetInfo;
  {$IfDef VerboseFocus}
  AWinControl: TWinControl;
  {$EndIf}
  NewTopLevelWidget: PGtkWidget;
  NewTopLevelObject: TObject;
  NewForm: TCustomForm;
begin
  if hwnd = 0 then
  begin
    Result:=0;
    exit;
  end;
  Widget:={%H-}PGtkWidget(hWnd);
  {$IfDef VerboseFocus}
  DebugLn('');
  DebuglnEnter('TGtk2WidgetSet.SetFocus INIT');
  DebugLn('A hWnd=',GetWidgetDebugReport(Widget));
  //DebugLn(getStackTrace(true));
  //if GtkWidgetIsA(Widget,GTK_TYPE_NOTEBOOK) then DumpStack;
  {$EndIf}

  // return the old focus handle
  Result := GetFocus;
  NewFocusWidget := nil;

  TopLevel := gtk_widget_get_toplevel(Widget);
  {$IfDef VerboseFocus}
  Debugln('B  TopLevel=',DbgS(TopLevel),' OldFocus=',GetWidgetDebugReport(PGtkWidget(Result)));
  if not GTK_WIDGET_VISIBLE(Widget) then begin
    DebugLnExit('TGtk2WidgetSet.SetFocus EXIT: Widget is not visible');
    raise Exception.Create('TGtk2WidgetSet.SetFocus: Widget is not visible');
  end;
  {$EndIf}

  if Result=hWnd then begin
    {$IfDef VerboseFocus}
    DebugLnExit('TGtk2WidgetSet.SetFocus EXIT: focusing same control');
    {$EndIf}
    exit;
  end;

  if GtkWidgetIsA(TopLevel, gtk_window_get_type) then
  begin
    // TopLevel is a gtkwindow
    {$IfDef VerboseFocus}
    AWinControl:=TWinControl(GetNearestLCLObject(PGtkWindow(TopLevel)^.focus_widget));
    DbgOut('C  TopLevel is a gtkwindow ');
    DbgOut(' focus_widget=',DbgS(PGtkWindow(TopLevel)^.focus_widget));
    DebugLn(' LCLParent=',dbgsName(AWinControl));
    {$EndIf}

    NewTopLevelObject:=GetNearestLCLObject(TopLevel);
    if (NewTopLevelObject is TCustomForm) then
    begin
      NewForm := TCustomForm(NewTopLevelObject);
      if Screen.GetCurrentModalFormZIndex > Screen.CustomFormZIndex(NewForm) then
      begin
        // there is a modal form above -> focus forbidden
        {$IfDef VerboseFocus}
        DebugLn('  there is a modal form above -> focus forbidden');
        {$EndIf}
        exit;
      end;
    end;

    NewFocusWidget := FindFocusWidget(Widget);

    {$IfDef VerboseFocus}
    DbgOut('G NewFocusWidget=',DbgS(NewFocusWidget),' ',DbgSName(GetNearestLCLObject(NewFocusWidget)));
    DbgOut([' WidVisible=',GTK_WIDGET_VISIBLE(PGtkWidget(NewFocusWidget))]);
    DbgOut([' WidRealized=',GTK_WIDGET_REALIZED(PGtkWidget(NewFocusWidget))]);
    DbgOut([' WidMapped=',GTK_WIDGET_MAPPED(PGtkWidget(NewFocusWidget))]);
    DbgOut([' WidCanfocus=',GTK_WIDGET_CAN_FOCUS(PGtkWidget(NewFocusWidget))]);
    DbgOut([' TopLvlVisible=',GTK_WIDGET_VISIBLE(PGtkWidget(TopLevel))]);
    DebugLn('');
    {$EndIf}
    if (NewFocusWidget<>nil) and GTK_WIDGET_CAN_FOCUS(NewFocusWidget) then
    begin
      if (PGtkWindow(TopLevel)^.Focus_Widget<>NewFocusWidget) then
      begin
        {$IfDef VerboseFocus}
        DebugLn('H SETTING NewFocusWidget=',dbgs(NewFocusWidget),' ',DbgSName(GetNearestLCLObject(NewFocusWidget)));
        //DebugLn('TGtk2WidgetSet.SetFocus TopLevel[',DebugGtkWidgets.GetInfo(TopLevel,false),'] NewFocusWidget=[',DebugGtkWidgets.GetInfo(NewFocusWidget,false),']');
        DebugLnEnter('Recursive focus INIT');
        {$EndIf}
        gtk_window_set_focus(PGtkWindow(TopLevel), NewFocusWidget);
        {$IfDef VerboseFocus}
        DebugLnExit('Recursive focus DONE');
        DebugLn('I NewTopLevel FocusWidget=',DbgS(PGtkWindow(TopLevel)^.Focus_Widget),' Success=',dbgs(PGtkWindow(TopLevel)^.Focus_Widget=NewFocusWidget));
        {$EndIf}
      end;
    end;
  end
  else begin
    NewFocusWidget:=Widget;
  end;

  if (NewFocusWidget <> nil) and not gtk_widget_has_focus(NewFocusWidget) then
  begin
    // grab the focus to the parent window
    NewTopLevelWidget := gtk_widget_get_toplevel(NewFocusWidget);
    NewTopLevelObject := GetNearestLCLObject(NewTopLevelWidget);
    if (Screen<>nil) and (Screen.GetCurrentModalForm<>nil) and (NewTopLevelObject <>Screen.GetCurrentModalForm) then
    begin
      {$IFDEF VerboseFocus}
      DebugLn('There is a modal form -> not grabbing');
      {$ENDIF}
    end
    else
    begin
      {$IfDef VerboseFocus}
      DebugLn('J Grabbing focus ',GetWidgetDebugReport(NewFocusWidget));
      {$EndIf}
      if NewTopLevelObject is TCustomForm then
      begin
        Info := GetWidgetInfo(NewTopLevelWidget);
        if (Info <> nil) and not (wwiActivating in  Info^.Flags) then
          SetForegroundWindow(TCustomForm(NewTopLevelObject).Handle);
      end;
      gtk_widget_grab_focus(NewFocusWidget);
    end;
  end;

  {$IfDef VerboseFocus}
  AWinControl:=TWinControl(GetNearestLCLObject(NewFocusWidget));
  NewFocusWidget:=PGtkWidget(GetFocus);
  DebugLnExit('TGtk2WidgetSet.SetFocus END hWnd=',DbgS(hWnd),
    ' NewFocus=',DbgS(NewFocusWidget),
    ' NewLCLParent=',dbgsName(AWinControl));
  {$EndIf}
end;

{------------------------------------------------------------------------------
  Function: SetForegroundWindow
  Params: hWnd:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetForegroundWindow(hWnd : HWND): boolean;
var
  {$IFDEF VerboseFocus}
  LCLObject: TControl;
  {$ENDIF}
  GdkWindow: PGdkWindow;
  AForm: TCustomForm;
begin
  {$IFDEF VerboseFocus}
  DbgOut('TGtk2WidgetSet.SetForegroundWindow hWnd=',DbgS(hWnd));
  LCLObject:=TControl(GetLCLObject(Pointer(hWnd)));
  if LCLObject<>nil then
    DebugLn(' LCLObject=',LCLObject.Name,':',LCLObject.ClassName)
  else
    DebugLn(' LCLObject=nil');
  {$ENDIF}
  Result := GtkWidgetIsA({%H-}PGtkWidget(hWnd),GTK_TYPE_WINDOW);
  if Result then
  begin
    GdkWindow := GetControlWindow({%H-}PgtkWidget(hwnd));
    if GdkWindow <> nil then
    begin
      if not gdk_window_is_visible(GdkWindow) then
      begin
        Result := False;
        Exit;
      end;
      AForm := TCustomForm(GetLCLObject({%H-}PgtkWidget(hwnd)));
      if (AForm is TCustomForm) and (AForm.Parent=nil) then
      begin
        if Screen.CustomFormZIndex(AForm) < Screen.GetCurrentModalFormZIndex then
        begin
          debugln('TGtk2WidgetSet.SetForegroundWindow Form=',DbgSName(AForm),
                  ' can not be raised, because ',
                  DbgSName(Screen.GetCurrentModalForm),
                  ' is modal and above.');
          Result := False;
          exit;
        end;
        Screen.MoveFormToZFront(AForm);
      end;
      {$IFDEF DebugGDKTraps}
      BeginGDKErrorTrap;
      {$ENDIF}
      gdk_window_show(GdkWindow);
      gdk_window_raise(GdkWindow);
      gdk_window_focus(GdkWindow, gtk_get_current_event_time);
      {$IFDEF DebugGDKTraps}
      EndGDKErrorTrap;
      {$ENDIF}
      // this currently will bring the window to the current desktop and focus it
      gtk_window_present({%H-}PGtkWindow(hWnd));
    end;
  end;
end;

function TGtk2WidgetSet.SetMapMode(DC: HDC; fnMapMode : Integer): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := Integer(False);
  if not IsValidDC(DC) then Exit(0);
  DevCtx.MapMode := fnMapMode;
  Result := Integer(True);
end;

function TGtk2WidgetSet.SetParent(hWndChild: HWND; hWndParent: HWND): HWND;
var
  Fixed: PGtkWidget;
  LCLObject: TObject;
begin
  Result := GetParent(hWndChild);

  if Result = hWndParent then
    Exit;

  // for window we need to move it content to HBox
  if GTK_IS_WINDOW({%H-}PGtkWidget(hWndChild)) then
  begin
    LCLObject := GetLCLObject({%H-}PGtkWidget(hWndChild));
    if LCLObject <> nil then
      Controls.RecreateWnd(TWinControl(LCLObject));
    Exit;
  end;

  if Result <> 0 then
  begin
    // unparent first
    gtk_widget_ref({%H-}PGtkWidget(hWndChild));
    if GTK_IS_CONTAINER({%H-}Pointer(Result)) then
      gtk_container_remove({%H-}PGtkContainer(Result), {%H-}PGtkWidget(hWndChild))
    else
      gtk_widget_unparent({%H-}PGtkWidget(hWndChild));
  end;

  Fixed := GetFixedWidget({%H-}PGtkWidget(hWndParent));
  if Fixed <> nil then
  begin
    FixedPutControl(Fixed, {%H-}PGtkWidget(hWndChild), {%H-}PGtkWidget(hWndChild)^.allocation.x, {%H-}PGtkWidget(hWndChild)^.allocation.y);
    RegroupAccelerator({%H-}PGtkWidget(hWndChild));
  end
  else
    gtk_widget_set_parent({%H-}PGtkWidget(hWndChild), {%H-}PGtkWidget(hWndParent));

  if Result <> 0 then
    gtk_widget_unref({%H-}PGtkWidget(hWndChild));
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.SetProp(Handle: hwnd; Str : PChar;
                              Data : Pointer) : Boolean;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetProp(Handle: hwnd; Str : PChar; Data : Pointer) : Boolean;
begin
  g_object_set_data({%H-}pGObject(handle),Str,data);
  Result:=true;
end;

{------------------------------------------------------------------------------
  Method: SetRectRgn
  Params:  aRGN: HRGN; X1, Y1, X2, Y2 : Integer
  Returns: True if the function succeeds

  Converts a region into a rectangular region with the specified coordinates.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetRectRgn(aRGN: HRGN; X1, Y1, X2, Y2 : Integer): Boolean;

  procedure Swap(var A, B: Integer);
  var
    Tmp: Integer;
  begin
    Tmp := A;
    A := B;
    B := Tmp;
  end;

var
  AGdiObject: PGdiObject absolute aRGN;
begin
  Result := IsValidGDIObject(aRGN);
  if Result then begin
    if (X1 > X2) then swap(X1, X2);
    if (Y1 > Y2) then swap(Y1, Y2);
    AGdiObject^.GDIRegionObject := CreateRectGDKRegion(Rect(X1,Y1,X2,Y2));
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.SetROPMode(Handle: hwnd; Str : PChar;
                              Data : Pointer) : Boolean;
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetROP2(DC: HDC; Mode: Integer) : Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if not IsValidDC(DC) then Exit(0);
  
  Result := DevCtx.ROP2;
  DevCtx.ROP2 := Mode;
end;

{------------------------------------------------------------------------------
  Function: SetScrollInfo
  Params:  none
  Returns: The new position value

  nPage >= 0
  nPage <= nMax-nMin+1
  nPos >= nMin
  nPos <= nMax - Max(nPage-1,0)
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetScrollInfo(Handle : HWND; SBStyle : Integer;
  ScrollInfo: TScrollInfo; bRedraw : Boolean): Integer;
var
  HasChanged: boolean;

  procedure SetRangeUpdatePolicy(Range: PGtkRange);
  var
    UpdPolicy: TGTKUpdateType;
  begin
    case ScrollInfo.nTrackPos of
      SB_POLICY_DISCONTINUOUS: UpdPolicy := GTK_UPDATE_DISCONTINUOUS;
      SB_POLICY_DELAYED:       UpdPolicy := GTK_UPDATE_DELAYED;
      else                     UpdPolicy := GTK_UPDATE_CONTINUOUS;
    end;
    if gtk_range_get_update_policy(Range)=UpdPolicy then exit;
    gtk_range_set_update_policy(Range, UpdPolicy);
    HasChanged:=true;
  end;

  procedure SetScrolledWindowUpdatePolicy(ScrolledWindow:PGTKScrolledWindow);
  var
    Range: PGtkRange;
  begin
    case SBStyle of
      SB_VERT: Range := PGtkRange(ScrolledWindow^.vscrollbar);
      SB_HORZ: Range := PGtkRange(ScrolledWindow^.hscrollbar);
      else exit;
    end;
    SetRangeUpdatePolicy(Range);
  end;

  procedure SetLayoutSize(layout:PGtkLayout; width:guint; height:guint);
  var
    OldWidth: guint;
    OldHeight: guint;
  begin
    gtk_layout_get_size(layout,@OldWidth,@OldHeight);
    if (OldWidth=width) and (OldHeight=height) then exit;
    HasChanged:=true;
    gtk_layout_set_size(layout,width,height);
  end;

  procedure SetGDouble(var v: gdouble; NewValue: gdouble);
  begin
    if v=NewValue then exit;
    v:=NewValue;
    HasChanged:=true;
  end;

const
  POLICY: array[BOOLEAN] of TGTKPolicyType = (GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);
var
  Layout: PgtkLayout;
  Scroll: PGTKWidget;
  IsScrollWindow: Boolean;
  IsScrollbarVis: boolean;
  Adjustment: PGtkAdjustment;
begin
  Result := 0;
  if (Handle = 0) then exit;
  HasChanged:=false;

  {DebugLn(['TGtk2WidgetSet.SetScrollInfo A Widget=',GetWidgetDebugReport(PGtkWidget(Handle)),' SBStyle=',SBStyle,
    ' ScrollInfo=[',
      'cbSize=',ScrollInfo.cbSize,
      ',fMask=',ScrollInfo.fMask,
      ',nMin=',ScrollInfo.nMin,
      ',nMax=',ScrollInfo.nMax,
      ',nPage=',ScrollInfo.nPage,
      ',nPos=',ScrollInfo.nPos,
      ',nTrackPos=',ScrollInfo.nTrackPos,
      ']']);}

  Scroll := g_object_get_data({%H-}PGObject(Handle), odnScrollArea);
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := {%H-}PGTKWidget(Handle);
    IsScrollWindow := GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type);
  end;

  if IsScrollWindow
  then begin
    Layout := GetFixedWidget({%H-}PGTKObject(Handle));
    if not GtkWidgetIsA(PGtkWidget(Layout), gtk_layout_get_type)
    then Layout := nil;
  end
  else begin
    Layout := nil;
  end;
  

  // scrollbar update policy
  if (Scrollinfo.fmask and SIF_UPDATEPOLICY <> 0) then begin
    if IsScrollWindow then
      SetScrolledWindowUpdatePolicy(PGTKScrolledWindow(Scroll))
    else if GtkWidgetIsA(PgtkWidget(Scroll), gtk_clist_get_type) then
      SetScrolledWindowUpdatePolicy(PGTKScrolledWindow(@PgtkCList(Scroll)^.container))
    else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_hscrollbar_get_type) then
      SetRangeUpdatePolicy(PgtkRange(Scroll))
    else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_vscrollbar_get_type) then
      SetRangeUpdatePolicy(PgtkRange(Scroll))
    else if GtkWidgetIsA(PGtkWidget(Scroll), gtk_range_get_type) then
      SetRangeUpdatePolicy(PGTKRange(Scroll));
  end;


  Adjustment:=nil;
  case SBStyle of
    SB_HORZ:
      if IsScrollWindow
      then begin
        Adjustment := gtk_scrolled_window_get_hadjustment(PGTKScrolledWindow(Scroll));
        if Layout <> nil
        then begin
          if (ScrollInfo.fMask and SIF_RANGE) <> 0 then
            SetLayoutSize(Layout, ScrollInfo.nMax - ScrollInfo.nMin, Layout^.height);
          Result := round(Layout^.hadjustment^.value);
        end;
      end
      // obsolete stuff
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_hscrollbar_get_type)
      then begin
        // this one shouldn't be possible, scrollbar messages are sent to the CTL
        DebugLN('!!! direct SB_HORZ set call to scrollbar');
        Adjustment :=  PgtkhScrollBar(Scroll)^.Scrollbar.Range.Adjustment
      end
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_clist_get_type)
      then begin
        //clist
        //TODO: check if this is needed for listviews
        DebugLn('[SetScrollInfo] Possible obsolete set use of CList (Listview ?)');
        Adjustment := gtk_clist_get_hadjustment(PgtkCList(Scroll));
      end;

    SB_VERT:
      if IsScrollWindow
      then begin
        Adjustment := gtk_scrolled_window_get_vadjustment(PGTKScrolledWindow(Scroll));
        if Layout <> nil
        then begin
          if (ScrollInfo.fMask and SIF_RANGE) <> 0 then
            SetLayoutSize(Layout, Layout^.Width, ScrollInfo.nMax - ScrollInfo.nMin);
          Result := round(Layout^.vadjustment^.value);
        end;
      end
      // obsolete stuff
      else if GtkWidgetIsA(PGtkWidget(Scroll),gtk_vscrollbar_get_type)
      then begin
        // this one shouldn't be possible, scrollbar messages are sent to the CTL
        DebugLN('!!! direct SB_VERT call to scrollbar');
        Adjustment :=  PgtkvScrollBar(Scroll)^.Scrollbar.Range.Adjustment;
      end
      else if GtkWidgetIsA(PGtkWidget(Scroll), gtk_clist_get_type)
      then begin
        //TODO: check is this is needed for listviews
        DebugLn('[SetScrollInfo] Possible obsolete set use of CList (Listview ?)');
        Adjustment := gtk_clist_get_vadjustment(PgtkCList(Scroll));
      end;

    SB_CTL:
      if GtkWidgetIsA(PGtkWidget(Scroll),gtk_vscrollbar_get_type) then
        Adjustment :=  PgtkvScrollBar(Scroll)^.Scrollbar.Range.Adjustment
      else
      if GtkWidgetIsA(PGtkWidget(Scroll),gtk_hscrollbar_get_type) then
        Adjustment :=  PgtkhScrollBar(Scroll)^.Scrollbar.Range.Adjustment
      else
      if GtkWidgetIsA(PGtkWidget(Scroll), gtk_range_get_type) then
        Adjustment := gtk_range_get_adjustment(PGTKRange(Scroll));
    SB_BOTH:
       DebugLn('[SetScrollInfo] Got SB_BOTH ???');
  end;
  

  if Adjustment = nil then
    exit;

  if (ScrollInfo.fMask and SIF_RANGE) <> 0
  then begin
    SetGDouble(Adjustment^.lower,ScrollInfo.nMin);
    SetGDouble(Adjustment^.upper,ScrollInfo.nMax);
  end;
  if (ScrollInfo.fMask and SIF_PAGE) <> 0
  then begin
    // 0 <= nPage <= nMax-nMin+1
    SetGDouble(Adjustment^.page_size, ScrollInfo.nPage);
    SetGDouble(Adjustment^.page_size, Min(Max(Adjustment^.page_size,0),
                                 Adjustment^.upper-Adjustment^.lower+1));
    SetGDouble(Adjustment^.page_increment, (Adjustment^.page_size/6)+1);
  end;
  if (ScrollInfo.fMask and SIF_POS) <> 0
  then begin
    // nMin <= nPos <= nMax - Max(nPage-1,0)
    SetGDouble(Adjustment^.value, ScrollInfo.nPos);
    SetGDouble(Adjustment^.value, Max(Adjustment^.value,Adjustment^.lower));
    SetGDouble(Adjustment^.value, Min(Adjustment^.value,
                              Adjustment^.upper-Max(Adjustment^.page_size-1,0)));
  end;

  // check if scrollbar should be hidden
  IsScrollbarVis := true;
  if ((ScrollInfo.fMask and (SIF_RANGE or SIF_PAGE)) <> 0) and
     ((SBStyle=SB_HORZ) or (SBStyle=SB_VERT))
  then begin
    if (Adjustment^.lower >= (Adjustment^.upper-Max(adjustment^.page_size-1,0)))
    then begin
      if (ScrollInfo.fMask and SIF_DISABLENOSCROLL) = 0 then
        IsScrollbarVis := false
      else
        ;// scrollbar should look disabled (no thumbbar and grayed appearance)
         // maybe not possible in gtk
    end;
  end;

  Result := Round(Adjustment^.value);

  if not HasChanged then exit;

  {DebugLn('');
  DebugLn('[TGtk2WidgetSet.SetScrollInfo] Result=',Result,
  ' Lower=',RoundToInt(Lower),
  ' Upper=',RoundToInt(Upper),
  ' Page_Size=',RoundToInt(Page_Size),
  ' Page_Increment=',RoundToInt(Page_Increment),
  ' bRedraw=',bRedraw,
  ' Handle=',DbgS(Handle));}

  // do we have to set this always ?
  // ??? what is this for code ????
  // why not change adjustment if we don't do a redraw ???
  if bRedraw then
  begin
    // immediate draw

    if IsScrollWindow
    then begin
      case SBStyle of
        SB_HORZ:
          g_object_set(PGTKObject(Scroll),'hscrollbar_policy',[POLICY[IsScrollbarVis],nil]);
        SB_VERT:
          g_object_set(PGTKObject(Scroll),'vscrollbar_policy',[POLICY[IsScrollbarVis],nil]);
      end;
    end
    else
      gtk_widget_queue_draw(PGTKWidget(Scroll));

(*
    DebugLn('TGtk2WidgetSet.SetScrollInfo:' +
     ' lower=%d/%d upper=%d/%d value=%d/%d' +
     ' step_increment=%d/1 page_increment=%d/%d page_size=%d/%d', [
     Round(lower),nMin, Round(upper),nMax, Round(value),nPos,
     Round(step_increment), Round(page_increment),nPage, Round(page_size),nPage]
    );
*)
    gtk_adjustment_changed(Adjustment);
  end;
end;

{------------------------------------------------------------------------------
  Function: SetSysColors
  Params:  cElements: the number of elements
           lpaElements: array with element numbers
           lpaRgbValues: array with colors
  Returns: 0 if unsuccesful

  The SetSysColors function sets the colors for one or more display elements.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetSysColors(cElements: Integer; const lpaElements;
  const lpaRgbValues): Boolean;
var
  n: Integer;
  Element: LongInt;
begin
  Result := False;
  if cElements > MAX_SYS_COLORS then Exit;

  for n := 0 to cElements - 1 do
  begin
    Element := PInteger(lpaElements)[n];
    if (Element > MAX_SYS_COLORS) or (Element < 0) then 
      Exit;
    SysColorMap[Element] := PDword(@lpaRgbValues)[n];
    //DebugLn(Format('Trace:[TGtk2WidgetSet.SetSysColor] Index %d (%8x) --> %8x', [PLongArray(lpaElements)^[n], SysColorMap[PLongArray(lpaElements)^[n]], PLongArray(lpaRgbValues)^[n]]));
  end;

  //TODO send WM_SYSCOLORCHANGE
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: SetTextCharacterExtra
  Params: _hdc:
          nCharExtra:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetTextCharacterExtra(DC : hdc; nCharExtra : Integer):Integer;
begin
  // Your code here
  Result:=0;
end;

{------------------------------------------------------------------------------
  Function: SetTextColor
  Params:  hdc: Identifies the device context.
           Color: Specifies the color of the text.
  Returns: The previous color if succesful, CLR_INVALID otherwise

  The SetTextColor function sets the text color for the specified device
  context to the specified color.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
begin
  Result := CLR_INVALID;
  if IsValidDC(DC)
  then begin
    with TGtkDeviceContext(DC) do
    begin
      Result := CurrentTextColor.ColorRef;
      SetGDIColorRef(CurrentTextColor,Color);
      if Result<>Color then
        SelectedColors := dcscCustom; // force SelectGDKTextProps to ensure text color
    end;
  end;
end;

function TGtk2WidgetSet.SetViewPortExtEx(DC: HDC; XExtent, YExtent : Integer; OldSize: PSize): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := False;
  if not IsValidDC(DC) then Exit;
  if OldSize <> nil then
  begin
    OldSize^.cx := DevCtx.ViewPortExt.x;
    OldSize^.cy := DevCtx.ViewPortExt.y;
  end;
  if (XExtent <> DevCtx.ViewPortExt.x) or (YExtent <> DevCtx.ViewPortExt.y) then
  begin
    case DevCtx.MapMode of
      MM_ANISOTROPIC, MM_ISOTROPIC:
      begin
        DevCtx.ViewPortExt := Point(XExtent, YExtent);
        Result := True;
      end;
    end;
  end;
end;

function TGtk2WidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer; OldPoint: PPoint): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := False;
  if not IsValidDC(DC) then Exit;
  if OldPoint <> nil then
  begin
    OldPoint^.x := DevCtx.ViewPortOrg.x;
    OldPoint^.y := DevCtx.ViewPortOrg.y;
  end;
  if (NewX <> DevCtx.ViewPortOrg.x) or (NewY <> DevCtx.ViewPortOrg.y) then
  begin
    DevCtx.ViewPortOrg := Point(NewX, NewY);
    Result := True;
  end;
end;

function TGtk2WidgetSet.SetWindowExtEx(DC: HDC; XExtent, YExtent: Integer; OldSize: PSize): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := False;
  if not IsValidDC(DC) then Exit;
  if OldSize <> nil then
  begin
    OldSize^.cx := DevCtx.WindowExt.x;
    OldSize^.cy := DevCtx.WindowExt.y;
  end;
  if (XExtent <> DevCtx.WindowExt.x) or (YExtent <> DevCtx.WindowExt.y) then
  begin
    case DevCtx.MapMode of
      MM_ANISOTROPIC, MM_ISOTROPIC:
      begin
        DevCtx.WindowExt := Point(XExtent, YExtent);
        Result := True;
      end;
    end;
  end;
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: TextOut
  Params: DC:
          X:
          Y:
          Str:
          Count:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetWindowLong(Handle: HWND; Idx: Integer;
  NewLong: PtrInt): PtrInt;
var
  Data: Pointer;
  WidgetInfo: PWidgetInfo;
begin
  //TODO: Finish this;
  Result:=0;
  Data := {%H-}Pointer(NewLong);

  case idx of
    GWL_WNDPROC :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.WndProc := NewLong;
      end;
    GWL_HINSTANCE :
      begin
        g_object_set_data({%H-}pgobject(Handle),'HINSTANCE',Data);
      end;
    GWL_HWNDPARENT :
      begin
        g_object_set_data({%H-}pgobject(Handle),'HWNDPARENT',Data);
      end;
    GWL_STYLE :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.Style := NewLong;
      end;
    GWL_EXSTYLE :
      begin
        WidgetInfo := GetWidgetInfo({%H-}Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.ExStyle := NewLong;
      end;
    GWL_USERDATA :
      begin
        g_object_set_data({%H-}pgobject(Handle),'Userdata',Data);
      end;
    GWL_ID :
      begin
        g_object_set_data({%H-}pgobject(Handle),'ID',Data);
      end;
  end; //case
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.SetWindowOrgEx(DC : HDC; NewX, NewY : Integer;
    OldPoint: PPoint) : Boolean;

  Sets the DC offset for the specified device context.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetWindowOrgEx(dc: hdc; NewX, NewY: Integer;
  OldPoint: PPoint): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if Assigned(OldPoint) then
    GetWindowOrgEx(DC, OldPoint);

  if not IsValidDC(DC) then exit(False);

  DevCtx.WindowOrg := Point(NewX, NewY);
  Result := True;
end;

{------------------------------------------------------------------------------
  function TGtk2WidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND;
    X, Y, cx, cy: Integer; uFlags: UINT): Boolean;

  hWnd: Widget to move
  hWndInsertAfter:
    HWND_BOTTOM to move bottommost
    HWND_TOP to move topmost
    the Widget, that should lie just on top of hWnd
  uFlags:
    SWP_NOMOVE: ignore X, Y
    SWP_NOSIZE: ignore cx, cy
    SWP_NOZORDER: ignore hWndInsertAfter
    SWP_NOREDRAW: skip instant redraw
    SWP_NOACTIVATE: skip switching focus

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND;
  X, Y, cx, cy: Integer; uFlags: UINT): Boolean;

  procedure SetZOrderOnFixedWidget(Widget, FixedWidget: PGtkWidget);
  var
    OldListItem: PGList;
    AfterWidget: PGtkWidget;
    AfterListItem: PGList;
  begin
    OldListItem:=FindFixedChildListItem(PGtkFixed(FixedWidget),Widget);
    if OldListItem=nil then begin
      DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: Widget not on parents fixed widget');
      exit;
    end;
    AfterWidget:=nil;
    AfterListItem:=nil;
    if hWndInsertAfter=HWND_BOTTOM then begin
      //debugln('HWND_BOTTOM');
      // HWND_BOTTOM
    end else if hWndInsertAfter=HWND_TOP then begin
      //debugln('HWND_TOP');
      // HWND_TOP
      AfterListItem:=FindFixedLastChildListItem(PGtkFixed(FixedWidget));
    end else if hWndInsertAfter=0 then begin
      DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: hWndInsertAfter=0');
      exit;
    end else begin
      // hWndInsertAfter
      AfterWidget:={%H-}PGtkWidget(hWndInsertAfter);
      AfterListItem:=FindFixedChildListItem(PGtkFixed(FixedWidget),AfterWidget);
      //debugln('AfterWidget=',GetWidgetDebugReport(AfterWidget));
    end;
    if (AfterListItem=nil) and (AfterWidget<>nil) then begin
      DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: AfterWidget not on parents fixed widget');
      exit;
    end;
    if (OldListItem=AfterListItem) or (OldListItem^.next=AfterListItem) then
    begin
      {$IFDEF EnableGtkZReordering}
      DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget Hint: Already there');
      {$ENDIF}
      exit;
    end;
    //DebugLn('TGtk2WidgetSet.SetWindowPos Moving GList entry');

    // reorder
    {$IFDEF EnableGtkZReordering}
    // MG: This trick does not work properly
    debugln('SetZOrderOnFixedWidget FixedWidget=['+GetWidgetDebugReport(FixedWidget)+']',
      ' Widget=['+GetWidgetDebugReport(Widget)+']',
      ' AfterWidget=['+GetWidgetDebugReport(AfterWidget)+']');
    MoveGListLinkBehind(PGtkFixed(FixedWidget)^.children,
                        OldListItem,AfterListItem);
    if GTK_WIDGET_VISIBLE(FixedWidget) and GTK_WIDGET_VISIBLE(Widget)
    and GTK_WIDGET_MAPPED(Widget) then begin
      DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget resize ..');
      gtk_widget_queue_resize(FixedWidget);
      AfterListItem:=PGtkFixed(FixedWidget)^.children;
      while AfterListItem<>nil do begin
        AfterWidget:=GetFixedChildListWidget(AfterListItem);
        DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnFixedWidget A ',GetWidgetDebugReport(AfterWidget));
        AfterListItem:=AfterListItem^.next;
      end;
    end;
    {$ENDIF}
  end;

  procedure SetZOrderOnLayoutWidget({%H-}Widget, {%H-}LayoutWidget: PGtkWidget);
  begin
    //DebugLn('TGtk2WidgetSet.SetWindowPos.SetZOrderOnLayoutWidget Not implemented: ZOrdering .. on ',GetWidgetDebugReport(LayoutWidget));
  end;

var
  Widget: PGTKWidget;
  FixedWidget: PGtkWidget;
  Allocation: TGTKAllocation;
begin
  Result:=false;
  Widget:={%H-}PGtkWidget(hWnd);
  {DebugLn('[TGtk2WidgetSet.SetWindowPos] ',GetWidgetDebugReport(Widget),
    ' Top=',hWndInsertAfter=HWND_TOP,
    ' SWP_NOZORDER=',(SWP_NOZORDER and uFlags)<>0,
    ' SWP_NOSIZE=',(SWP_NOSIZE and uFlags)<>0,
    ' SWP_NOMOVE=',(SWP_NOMOVE and uFlags)<>0,
    '');}
  if GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then
  begin
    Result := True;
    exit;
    { case hWndInsertAfter of
        HWND_BOTTOM: ;  //gdk_window_lower(Widget^.Window);
        HWND_TOP:    gtk_window_set_position(PGtkWindow(hWnd),GTK_WIN_POS_CENTER);
                    //gdk_window_raise(Widget^.Window);
      end;
    }
  end;

  if (SWP_NOMOVE and uFlags = 0) and (SWP_NOSIZE and uFlags = 0) then
  begin
    // optimize if pos & size needed, so we allocate in one shot.
    Allocation.X := X;
    Allocation.Y := Y;
    Allocation.Width := cx;
    Allocation.Height := cy;
    gtk_widget_size_allocate(Widget, @Allocation);
  end else
  begin
    if (SWP_NOMOVE and uFlags = 0) then
    begin
      Allocation.X := X;
      Allocation.Y := Y;
      Allocation.Width := Widget^.Allocation.Width;
      Allocation.Height := Widget^.Allocation.Height;
      gtk_widget_size_allocate(Widget, @Allocation);
    end;

    if (SWP_NOSIZE and uFlags = 0) then
    begin
      Allocation.X := Widget^.Allocation.x;
      Allocation.Y := Widget^.Allocation.y;
      Allocation.Width := cx;
      Allocation.Height := cy;
      gtk_widget_size_allocate(Widget, @Allocation);
    end;
  end;

  if (SWP_NOZORDER and uFlags)=0 then
  begin
    FixedWidget:=Widget^.Parent;
    if FixedWidget=nil then exit;

    //DebugLn('TGtk2WidgetSet.SetWindowPos ZOrdering .. on ',GetWidgetDebugReport(FixedWidget));
    if GtkWidgetIsA(FixedWidget,GTK_Fixed_Get_Type) then begin
      // parent's client area is a gtk_fixed widget
      SetZOrderOnFixedWidget(Widget,FixedWidget);
    end else if GtkWidgetIsA(FixedWidget,GTK_Layout_Get_Type) then begin
      // parent's client area is a gtk_layout widget
      SetZOrderOnLayoutWidget(Widget,FixedWidget);
    end else begin
      //DebugLn('TGtk2WidgetSet.SetWindowPos Not implemented: ZOrdering .. on ',GetWidgetDebugReport(FixedWidget));
      exit;
    end;
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  Function SetWindowRgn
  Params: hWnd: HWND;  hRgn: HRGN; bRedraw: Boolean
  Returns: 0 - fails, in other case success
------------------------------------------------------------------------------}
function TGtk2WidgetSet.SetWindowRgn(hWnd: HWND; hRgn: HRGN; bRedraw: Boolean): longint;
var
  Widget: PGtkWidget;
  Window: PGdkWindow;
  ShapeRegion: PGdkRegion;
  LCLObject: TObject;
begin
  // For normal widgets we should use GetFixedWidget,
  // but for TForm we should apply the region in the raw hWnd
  LCLObject := GetLCLObject({%H-}PGtkWidget(hWnd));
  if LCLObject is TCustomForm then
  begin
    Widget := {%H-}PGtkWidget(hWnd);
  end
  else
  begin
    Widget := GetFixedWidget({%H-}PGtkWidget(hWnd));
    if Widget = nil then
      Widget := {%H-}PGtkWidget(hWnd);
  end;
  if Widget = nil then
    Exit(0);
  if GtkWidgetIsA(gtk_widget_get_toplevel(Widget), gtk_window_get_type)
      and not gtk_widget_realized(Widget) then
    gtk_widget_realize(Widget); // associate with window
  Window := GetControlWindow(Widget);
  if Window = nil then
    Exit(0);
  if hRgn = 0 then
    ShapeRegion := nil
  else
    ShapeRegion := {%H-}PGDIObject(hRgn)^.GDIRegionObject;
  gdk_window_shape_combine_region(Window, ShapeRegion, 0, 0);
  if bRedraw then
    gdk_window_invalidate_region(Window, ShapeRegion, True);
  Result := 1;
end;

{------------------------------------------------------------------------------
  Function: ShowCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ShowCaret(hWnd: HWND): Boolean;
var
  GTKObject: PGTKObject;
begin
  GTKObject := {%H-}PGTKObject(HWND);
  Result := GTKObject <> nil;

  if Result
  then begin
    if gtk_type_is_a(g_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_ShowCaret(PGTKAPIWidget(GTKObject));
    end
    else begin
      Result := False;
    end;
  end
  else DebugLn('WARNING: [TGtk2WidgetSet.ShowCaret] Got null HWND');
end;

{------------------------------------------------------------------------------
  Function:  ShowScrollBar
  Params:  Wnd, wBar, bShow
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer;
  bShow: Boolean): Boolean;
var
  NewPolicy: Integer;
  Scroll: PGtkWidget;
  IsScrollWindow: Boolean;
begin
  Result := (Handle <> 0);
  if not Result then exit;
  
  Scroll := PGtkWidget(g_object_get_data({%H-}PGObject(Handle), odnScrollArea));
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := {%H-}PGTKWidget(Handle);
    IsScrollWindow := GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type);
  end;

  //DebugLn(['TGtk2WidgetSet.ShowScrollBar ',GetWidgetDebugReport(Scroll),' wBar=',wBar,' bShow=',bShow]);
  if IsScrollWindow then begin
    if wBar in [SB_BOTH, SB_HORZ] then begin
      //DebugLn(['TGtk2WidgetSet.ShowScrollBar ',GetWidgetDebugReport(Widget),' bShow=',bShow]);
      if bShow then
        NewPolicy:=GTK_POLICY_ALWAYS
      else
        NewPolicy:=GTK_POLICY_NEVER;
      g_object_set(PGTKObject(Scroll), 'hscrollbar_policy', [NewPolicy,nil]);
    end;
    if wBar in [SB_BOTH, SB_VERT] then begin
      if bShow then
        NewPolicy:=GTK_POLICY_ALWAYS
      else
        NewPolicy:=GTK_POLICY_NEVER;
      g_object_set(PGTKObject(Scroll), 'vscrollbar_policy', [NewPolicy,nil]);
    end;
  end
  else begin
    if (wBar = SB_CTL)
    and gtk_type_is_a(g_object_type({%H-}PGTKObject(Handle)),gtk_widget_get_type)
    then begin
      if bShow
      then gtk_widget_show(Scroll)
      else gtk_widget_hide(Scroll);
    end;
  end;
end;

{------------------------------------------------------------------------------
  function ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;

  nCmdShow:
    SW_SHOWNORMAL, SW_MINIMIZE, SW_SHOWMAXIMIZED
------------------------------------------------------------------------------}
function TGtk2WidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
var
  GtkWindow: PGtkWindow;
  B: Boolean;
  Widget: PGtkWidget;
  AFlags: TGdkWindowState;
  AWindow: PGdkWindow;
begin
  Result := False;

  Widget := {%H-}PGtkWidget(HWND);

  if Widget = nil then
    RaiseGDBException('TGtk2WidgetSet.ShowWindow  hWnd is nil');

  if GTK_IS_WINDOW(Widget) then
    GtkWindow := {%H-}PGtkWindow(hWnd)
  else
  begin
    // we are pure gtkwidget so only SW_SHOW AND SW_HIDE CAN GO
    case nCmdShow of
      SW_SHOWNORMAL,
      SW_SHOW: gtk_widget_show(Widget);
      SW_HIDE: gtk_widget_hide(Widget);
    end;
    Result := nCmdShow in [SW_SHOW, SW_HIDE];
    exit;
  end;


  B := (PGtkWidget(GtkWindow)^.parent <> nil) and
    (PGtkWidget(GtkWindow)^.parent^.window <> nil) and
    (PGtkWidget(GtkWindow)^.parent^.window = PGtkWidget(GtkWindow)^.window);

  if not B and not GTK_IS_WINDOW(PGtkWidget(GtkWindow)) then
  begin
    DebugLn(['TGtk2WidgetSet.ShowWindow ',GetWidgetDebugReport(PGTKWidget(GtkWindow))]);
    RaiseGDBException('TGtk2WidgetSet.ShowWindow  hWnd is not a gtkwindow');
  end;

  //debugln('TGtk2WidgetSet.ShowWindow A ',GetWidgetDebugReport(PGtkWidget(GtkWindow)),' nCmdShow=',dbgs(nCmdShow),' SW_MINIMIZE=',dbgs(SW_MINIMIZE=nCmdShow));

  case nCmdShow of

  SW_SHOWNORMAL:
    begin
      if B then
        gtk_widget_show(PGtkWidget(GtkWindow))
      else
      begin
        if not GTK_WIDGET_VISIBLE(PGtkWidget(GtkWindow)) then
          gtk_widget_show(PGtkWidget(GtkWindow));
        AWindow := PGtkWidget(GtkWindow)^.window;
        if GDK_IS_WINDOW(AWindow) then
        begin
          AFlags := gdk_window_get_state(AWindow);
          if AFlags and GDK_WINDOW_STATE_ICONIFIED <> 0 then
            gtk_window_deiconify(GtkWindow);
          if AFlags and GDK_WINDOW_STATE_MAXIMIZED <> 0 then
            gtk_window_unmaximize(GtkWindow);
          if AFlags and GDK_WINDOW_STATE_FULLSCREEN <> 0 then
            gtk_window_unfullscreen(GtkWindow);
        end;
      end;
    end;

  SW_HIDE:
      gtk_widget_hide(PGtkWidget(GtkWindow));

  SW_MINIMIZE:
    if not B then
      gtk_window_iconify(GtkWindow);

  SW_SHOWMAXIMIZED:
    if B then
      gtk_widget_show(PGtkWidget(GtkWindow))
    else
    begin
      AWindow := PGtkWidget(GtkWindow)^.window;
      if GDK_IS_WINDOW(AWindow) then
      begin
        AFlags := gdk_window_get_state(AWindow);
        if AFlags and GDK_WINDOW_STATE_ICONIFIED <> 0 then
          gtk_window_deiconify(GtkWindow);
        if AFlags and GDK_WINDOW_STATE_FULLSCREEN <> 0 then
          gtk_window_unfullscreen(GtkWindow);
        gtk_window_maximize(GtkWindow);
      end;
    end;

  SW_SHOWFULLSCREEN:
    if B then
      gtk_widget_show(PGtkWidget(GtkWindow))
    else
      gtk_window_fullscreen(GtkWindow);

  SW_RESTORE:
    begin
      AWindow := PGtkWidget(GtkWindow)^.window;
      if GDK_IS_WINDOW(AWindow) then
      begin
        AFlags := gdk_window_get_state(AWindow);
        if AFlags and GDK_WINDOW_STATE_ICONIFIED <> 0 then
          gtk_window_deiconify(GtkWindow);
        if AFlags and GDK_WINDOW_STATE_MAXIMIZED <> 0 then
          gtk_window_unmaximize(GtkWindow);
        if AFlags and GDK_WINDOW_STATE_FULLSCREEN <> 0 then
          gtk_window_unfullscreen(GtkWindow);
      end;
    end;
  end;

  Result := True;
end;

{------------------------------------------------------------------------------
  Function: StretchBlt
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           SrcWidth, SrcHeight:   The size of the source rectangle
           ROp:                   The raster operation to be performed
  Returns: True if succesful

  The StretchBlt function copies a bitmap from a source rectangle into a
  destination rectangle using the specified raster operation. If needed it
  resizes the bitmap to fit the dimensions of the destination rectangle.
  Sizing is done according to the stretching mode currently set in the
  destination device context.
  If SrcDC contains a mask the pixmap will be copied with this transparency.

  ToDo: Mirroring, extended NonDrawable support (Image, Bitmap, etc)
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; ROp: Cardinal): Boolean;
begin
  Result:=StretchCopyArea(DestDC,X,Y,Width,Height,
                          SrcDC,XSrc,YSrc,SrcWidth,SrcHeight,
                          0,0,0,
                          ROp);
end;

{------------------------------------------------------------------------------
  Function: StretchMaskBlt
  Params:  DestDC:                The destination devicecontext
           X, Y:                  The left/top corner of the destination rectangle
           Width, Height:         The size of the destination rectangle
           SrcDC:                 The source devicecontext
           XSrc, YSrc:            The left/top corner of the source rectangle
           SrcWidth, SrcHeight:   The size of the source rectangle
           Mask:                  The handle of a monochrome bitmap
           XMask, YMask:          The left/top corner of the mask rectangle
           ROp:                   The raster operation to be performed
  Returns: True if succesful

  The StretchMaskBlt function copies a bitmap from a source rectangle into a
  destination rectangle using the specified mask and raster operation. If needed
  it resizes the bitmap to fit the dimensions of the destination rectangle.
  Sizing is done according to the stretching mode currently set in the
  destination device context.
 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; Mask: HBITMAP;
  XMask, YMask: Integer; Rop: DWORD): Boolean;
begin
  Result:=StretchCopyArea(DestDC,X,Y,Width,Height,
                          SrcDC,XSrc,YSrc,SrcWidth,SrcHeight,
                          Mask,XMask,YMask,
                          Rop);
end;

function TGtk2WidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord;
  pvParam: Pointer; fWinIni: DWord): LongBool;
{$IFDEF HASX}
var
  ax, ay, awidth, aheight: gint;
{$ENDIF}
begin
  Result:=True;
  Case uiAction of
    SPI_GETWHEELSCROLLLINES: PDword(pvParam)^ := 3;
    SPI_GETWORKAREA:
    begin
      {$IFDEF HASX}
      if XGetWorkarea(ax, ay, awidth, aheight) <> -1 then
        TRect(pvParam^) := Bounds(ax, ay, awidth, aheight)
      else
      {$ENDIF}
      TRect(pvParam^):=Bounds(GetSystemMetrics(SM_XVIRTUALSCREEN),
                              GetSystemMetrics(SM_YVIRTUALSCREEN),
                              GetSystemMetrics(SM_CXVIRTUALSCREEN),
                              GetSystemMetrics(SM_CYVIRTUALSCREEN));
    end;
  else
    Result:=False;
  end;
end;

{------------------------------------------------------------------------------
  Function: TextOut
  Params: DC:
          X:
          Y:
          Str:
          Count:
  Returns:

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.TextOut(DC: HDC; X, Y: Integer; Str: Pchar;
  Count: Integer) : Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  DCOrigin: TPoint;
  yOffset: integer;
  BackGroundColor: PGdkColor;
begin
  Result := IsValidDC(DC);
  if not Result then Exit;
  if Count <= 0 then Exit;

  if DevCtx.HasTransf then
    DevCtx.TransfPoint(X, Y);

  UpdateDCTextMetric(DevCtx);
  DCOrigin := DevCtx.Offset;
  
  with DevCtx.DCTextMetric.TextMetric do
    yOffset := tmHeight-tmDescent-tmAscent;
  if yOffset < 0 then
    yOffset := 0;
    
  DevCtx.SelectedColors := dcscCustom;
  EnsureGCColor(DC, dccCurrentTextColor, True, False);

  BackGroundColor := nil;
  if DevCtx.BkMode = OPAQUE then
  begin
    AllocGDIColor(DC, @DevCtx.CurrentBackColor);
    BackGroundColor := @DevCtx.CurrentBackColor.Color;
  end;

  DevCtx.DrawTextWithColors(Str, Count,
    X + DCOrigin.X, Y + DCOrigin.Y + yOffset,
    nil, BackGroundColor);
end;

function TGtk2WidgetSet.UpdateWindow(Handle: HWND): Boolean;
var
  CurWidget: PGtkWidget;
begin
  CurWidget:={%H-}PGTKWidget(Handle);
  //DebugLn(['TGtk2WidgetSet.UpdateWindow ',GetWidgetDebugReport(CurWidget)]);
  if GTK_WIDGET_DRAWABLE(CurWidget) then begin
    //DebugLn(['TGtk2WidgetSet.UpdateWindow DRAWING']);
    gtk_widget_queue_draw(CurWidget);
    if GDK_IS_WINDOW(CurWidget^.Window) then
      gdk_window_process_updates(CurWidget^.window,TRUE);
    Result:=true;
  end else
    Result:=false;
end;


{------------------------------------------------------------------------------
  Function: WindowFromPoint
  Params: Point: Specifies the x and y Coords
  Returns: The handle of the gtkwidget.  If none exist, then NULL is returned.

 ------------------------------------------------------------------------------}
function TGtk2WidgetSet.WindowFromPoint(APoint: TPoint): HWND;
var
  ev: TgdkEvent;
  Window: PgdkWindow;
  Widget: PgtkWidget;
  p: TPoint;
  WidgetInfo: PWidgetInfo;
begin
  // return cached value to prevent heavy gdk_display_get_window_at_pointer call
  if (APoint = LastWFPMousePos) and GTK_IS_OBJECT({%H-}Pointer(LastWFPResult)) and
    GTK_WIDGET_VISIBLE({%H-}PGtkWidget(LastWFPResult)) and
    GTK_WIDGET_IS_SENSITIVE({%H-}PGtkWidget(LastWFPResult)) then
    Exit(LastWFPResult);
  Result := 0;

  WidgetInfo := nil;
  // we are using gdk_display_get_window_at_pointer instead of
  // gdk_window_at_pointer because of multihead support.
  // !! changes the coordinates !! -> using local variable p
  p := APoint;
  Window := gdk_display_get_window_at_pointer(gdk_display_get_default,
    @p.x, @p.y);
  if window <> nil then
  begin
    FillChar(ev{%H-}, SizeOf(ev), 0);
    ev.any.window := Window;
    Widget := gtk_get_event_widget(@ev);
    Result := {%H-}PtrUInt(Widget);
    if Result <> 0 then
    begin
      WidgetInfo := GetWidgetInfo(Widget);
      if WidgetInfo = nil then
      begin
        // complex controls eg. ScrollBar of TTreeView
        WidgetInfo := GetWidgetInfo(Widget^.parent);
        if WidgetInfo <> nil then
          Result := {%H-}PtrUInt(Widget^.parent);
      end;
    end;
  end;
  // disconnect old handler
  if GTK_IS_OBJECT({%H-}Pointer(LastWFPResult)) then
  begin
    g_signal_handlers_disconnect_by_func({%H-}GPointer(LastWFPResult),
      TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
  end;

  // see issue #17389
  if (WidgetInfo <> nil) and (WidgetInfo^.LCLObject <> nil)
  and (WidgetInfo^.LCLObject is TWinControl) then
    Result := TWinControl(WidgetInfo^.LCLObject).Handle;

  // now we must check if we are visible and enabled
  if Result <> 0 then
  begin
    if not GTK_WIDGET_VISIBLE({%H-}PGtkWidget(Result)) or
      not GTK_WIDGET_IS_SENSITIVE({%H-}PGtkWidget(Result)) then
        Result := 0;
  end;

  LastWFPMousePos := APoint;
  LastWFPResult := Result;
  // connect handler
  if LastWFPResult <> 0 then
  begin
    g_signal_connect({%H-}GPointer(LastWFPResult), 'destroy',
      TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
  end;
end;

//##apiwiz##eps##   // Do not remove

// Placed CriticalSectionSupport outside the API wizard bounds
// so it won't affect sorting etc.

{$IfNDef DisableCriticalSections}

  {$IfDef Unix}

    {$Define pthread}

    {Type
      _pthread_fastlock = packed record
        __status: Longint;
        __spinlock: Integer;
      end;

      pthread_mutex_t = packed record
        __m_reserved: Integer;
        __m_count: Integer;
        __m_owner: Pointer;
        __m_kind: Integer;
        __m_lock: _pthread_fastlock;
      end;
      ppthread_mutex_t = ^pthread_mutex_t;

      pthread_mutexattr_t = packed record
        __mutexkind: Integer;
      end;}

    {$linklib pthread}

    {function pthread_mutex_init(var Mutex: pthread_mutex_t;
      var Attr: pthread_mutexattr_t): Integer; cdecl;external;
    function pthread_mutexattr_settype(var Attr: pthread_mutexattr_t;
      Kind: Integer): Integer; cdecl;external;
    function pthread_mutex_lock(var Mutex: pthread_mutex_t):
      Integer; cdecl; external;
    function pthread_mutex_unlock(var Mutex: pthread_mutex_t):
      Integer; cdecl; external;
    function pthread_mutex_destroy(var Mutex: pthread_mutex_t):
      Integer; cdecl; external;}
  {$EndIf}

{$EndIf}

procedure TGtk2WidgetSet.InitializeCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  New(ACritSec);
  System.InitCriticalSection(ACritSec^);
  CritSection:={%H-}TCriticalSection(ACritSec);
end;
{var
  Crit : ppthread_mutex_t;
  Attribute: pthread_mutexattr_t;
begin
  if pthread_mutexattr_settype(Attribute, 1) <> 0 then
    Exit;
  If CritSection <> 0 then
    Try
      Crit := ppthread_mutex_t(CritSection);
      Dispose(Crit);
    except
      CritSection := 0;
    end;
  New(Crit);
  pthread_mutex_init(Crit^, Attribute);
  CritSection := Longint(Crit);
end;}
{$Else}
begin
end;
{$EndIf}

procedure TGtk2WidgetSet.EnterCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:={%H-}System.PRTLCriticalSection(CritSection);
  System.EnterCriticalsection(ACritSec^);
end;
{$Else}
begin
end;
{$EndIf}

procedure TGtk2WidgetSet.LeaveCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:={%H-}System.PRTLCriticalSection(CritSection);
  System.LeaveCriticalsection(ACritSec^);
end;
{$Else}
begin
end;
{$EndIf}

procedure TGtk2WidgetSet.DeleteCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:={%H-}System.PRTLCriticalSection(CritSection);
  System.DoneCriticalsection(ACritSec^);
  Dispose(ACritSec);
  CritSection:=0;
end;
{$Else}
begin
end;
{$EndIf}

{$IfDef ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$EndIf}




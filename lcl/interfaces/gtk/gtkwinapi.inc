{%MainUnit gtkint.pp}
{ $Id$ }

{******************************************************************************
                         All GTK Winapi implementations.
                   Initial Revision  : Sat Nov 13 12:53:53 1999


  !! Keep alphabetical !!

  Support routines go to gtkproc.pp

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

const
  BOOL_TEXT: array[Boolean] of string = ('False', 'True');

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
function TGtkWidgetSet.Arc(DC: HDC;
  left, top, right, bottom, angle1, angle2: Integer): Boolean;
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
function TGtkWidgetSet.AngleChord(DC: HDC;
  x1, y1, x2, y2, angle1, angle2: Integer): Boolean;
begin
  Result := inherited AngleChord(DC, x1, y1, x2, y2, angle1, angle2);
end;

{------------------------------------------------------------------------------
  Function: BeginPaint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.BeginPaint(Handle: hWnd; var PS : TPaintStruct) : hdc;
var
  Widget: PGtkWidget;
  Info: PWidgetInfo;
{$IFDEF Gtk1}
  IsDoubleBuffered: Boolean;
  TargetObject: TObject;
  PaintWidget: Pointer;
{$ELSE}
  DC: TGtkDeviceContext;
{$ENDIF}
begin
  Widget:=PGtkWidget(Handle);
  Info:=GetWidgetInfo(Widget,false);
  if Info<>nil then
    Inc(Info^.PaintDepth);
  {$IFDEF Gtk1}
  TargetObject:=GetNearestLCLObject(Widget);
  IsDoubleBuffered:=(TargetObject is TWinControl)
                    and TWinControl(TargetObject).DoubleBuffered;
  // check if Handle is the paint widget of the LCL component
  if IsDoubleBuffered then begin
    PaintWidget:=GetFixedWidget(PGtkWidget(TWinControl(TargetObject).Handle));
    IsDoubleBuffered:=(PaintWidget=Widget);
    //if not IsDoubleBuffered then begin
    //  DebugLn('TGtkWidgetSet.BeginPaint Not the paint widget: ',
    //    TWinControl(TargetObject).Name,':',TWinControl(TargetObject).ClassName,
    //    ' PaintWidget=',GetWidgetClassName(PaintWidget),
    //    ' Widget=',GetWidgetClassName(Widget));
    //end;
  end;
  {$IFNDEF UseGTKDoubleBuf}
  IsDoubleBuffered:=false;
  {$ENDIF}
  if IsDoubleBuffered then
    PS.hDC:=GetDoubleBufferedDC(Handle)
  else
    PS.hDC:=GetDC(Handle);
  {$ELSE  below: not GTK1}
  PS.hDC:=GetDC(Handle);
  DC:=TGtkDeviceContext(PS.hDC);
  DC.PaintRectangle:=PS.rcPaint;
  {$ENDIF}

  Result := PS.hDC;
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
function TGtkWidgetSet.BitBlt(DestDC: HDC; X, Y, Width, Height: Integer;
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
function TGtkWidgetSet.CallNextHookEx(hhk : HHOOK; ncode : Integer; wParam: WParam; lParam : LParam) : Integer;
begin
  Result := 0;
  //TODO: Does anything need to be done here?
  //DebugLn('Trace:!!!!!!!!!!!!!!!!!!');
  //DebugLn('Trace:!!!!!!!!!!!!!!!!!!');
  //DebugLn('Trace:TODO: CALLNEXTHOOKEX in gtkwinapi.inc');
  //DebugLn('Trace:!!!!!!!!!!!!!!!!!!');
  //DebugLn('Trace:!!!!!!!!!!!!!!!!!!');
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
function TGtkWidgetSet.CallWindowProc(lpPrevWndFunc : TFarProc; Handle : HWND;
  Msg : UINT; wParam: WParam; lParam : LParam) : Integer;
var
  Proc : TWndMethod;
  Mess : TLMessage;
  P : Pointer;
begin
  Result := -1;
  if Handle = 0 then Exit;
  Result := -1;
  P := nil;
  P := gtk_object_get_data(pgtkobject(Handle),'WNDPROC');
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
function TGtkWidgetSet.ClientToScreen(Handle : HWND; var P : TPoint) : Boolean;
var
  Position: TPoint;
  LCLObject: TObject;
  List: PGList;
  i: Integer;
  Pt: TPoint;
  Adjustment: PGtkAdjustment;
  Scrolled: PGtkScrolledWindow;
begin
  if Handle = 0 then
  begin
    Position.X := 0;
    Position.Y := 0;
  end else
  begin
    Position := GetWidgetClientOrigin(PGtkWidget(Handle));
    LCLObject:=GetLCLObject(PGtkWidget(Handle));
    if (LCLObject <> nil) and (LCLObject is TScrollingWinControl) then
    begin
      List := gtk_container_children(PGtkContainer(PGtkWidget(Handle)));
      if (g_list_length(List) > 0) and
        GTK_IS_SCROLLED_WINDOW(g_list_nth_data(List, 0)) then
      begin
        Scrolled := PGtkScrolledWindow(g_list_nth_data(List, 0));
        Pt := Point(0, 0);
        Adjustment := gtk_scrolled_window_get_vadjustment(Scrolled);
        if Adjustment <> nil then
          Pt.Y := Round(Adjustment^.value);

        Adjustment := gtk_scrolled_window_get_hadjustment(Scrolled);
        if Adjustment <> nil then
          Pt.X := Round(Adjustment^.value);
        dec(Position.X, Pt.X);
        dec(Position.Y, Pt.Y);
      end;
      glib.g_list_free(List);
    end;
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
function TGtkWidgetSet.ClipboardFormatToMimeType(
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
function TGtkWidgetSet.ClipboardGetData(ClipboardType: TClipboardType;
  FormatID: TClipboardFormat; Stream: TStream): boolean;
type
  PGdkAtom = ^TGdkAtom;
var
  FormatAtom, FormatTry: TGdkAtom;
  SupportedCnt, i: integer;
  SupportedFormats: PGdkAtom;
  SelData: TGtkSelectionData;
  CompoundTextList: PPGChar;
  CompoundTextCount: integer;

  function IsFormatSupported(CurFormat: TGdkAtom): boolean;
  var a: integer;
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
      {DebugLn('IsFormatSupported A ',Dbgs(SelData.Selection),
      ' ',HexStr(Cardinal(ClipboardTypeAtoms[ClipboardType]),8),
      ' SelData.Target='+dbgs(SelData.Target),' AllID='+dbgs(AllID),
      ' SelData.TheType='+dbgs(SelData.TheType)+' ATOM='+dbgs(gdk_atom_intern('ATOM',0))+' Name="'+GdkAtomToStr(SelData.TheType)+'"',
      ' SelData.Length='+dbgs(SelData.Length),
      ' SelData.Format='+dbgs(SelData.Format)
      );}
      if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
      or (SelData.Target<>AllID)
      or (SelData.{$IfDef GTK2}_Type{$Else}theType{$EndIf}<>gdk_atom_intern('ATOM',GdkFalse)) then begin
        SupportedCnt:=0;
        exit;
      end;
      SupportedCnt:=SelData.Length div (SelData.Format shr 3);
      SupportedFormats:=PGdkAtom(SelData.Data);
      //DebugLn('IsFormatSupported SupportedCnt=',dbgs(SupportedCnt));

      {a:=SupportedCnt-1;
      while (a>=0) do begin
        debugln(' ',dbgs(a),' ',GdkAtomToStr(SupportedFormats[a]),' "',p,'"');
        dec(a);
      end;}
    end;
    a:=SupportedCnt-1;
    while (a>=0) and (SupportedFormats[a]<>CurFormat) do dec(a);
    Result:=(a>=0);
  end;

begin
  {$IfDef DEBUG_CLIPBOARD}
  DebugLn('[TGtkWidgetSet.ClipboardGetData] A ClipboardWidget=',Dbgs(ClipboardWidget),' FormatID=',ClipboardFormatToMimeType(FormatID),' Now=',dbgs(Now));
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
      FormatAtom:=0;
      // text/plain is supported in various formats in gtk
      FormatTry:=gdk_atom_intern('COMPOUND_TEXT',GdkFalse);
      if IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      // The COMPOUND_TEXT format can be converted and is therefore
      // used as default for 'text/plain'
      if (SupportedCnt=0) then
        FormatAtom:=gdk_atom_intern('COMPOUND_TEXT',GdkFalse);
      // then check for UTF8 text format 'UTF8_STRING'
      FormatTry:=gdk_atom_intern('UTF8_STRING',GdkFalse);
      if IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      // then check for simple text format 'text/plain'
      FormatTry:=gdk_atom_intern('text/plain',GdkFalse);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      // then check for simple text format STRING
      FormatTry:=gdk_atom_intern('STRING',GdkFalse);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      // check for some other formats that can be interpreted as text
      FormatTry:=gdk_atom_intern('FILE_NAME',GdkTrue);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      FormatTry:=gdk_atom_intern('HOST_NAME',GdkTrue);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      FormatTry:=gdk_atom_intern('USER',GdkTrue);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
      // the TEXT format is not reliable, but it should be supported
      FormatTry:=gdk_atom_intern('TEXT',GdkFalse);
      if (FormatAtom=0) and IsFormatSupported(FormatTry) then
        FormatAtom:=FormatTry;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtkWidgetSet.ClipboardGetData] B  Format=',ClipboardFormatToMimeType(FormatAtom),' FormatAtom=',dbgs(FormatAtom),' Now=',dbgs(Now));
    {$EndIf}
    if FormatAtom=0 then exit;

    // request data from owner
    SelData:=RequestSelectionData(ClipboardWidget,ClipboardType,FormatAtom);
    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtkWidgetSet.ClipboardGetData] C  Length=',dbgs(SelData.Length),' Now=',dbgs(Now),' ',
      ' SelData.Selection=',dbgs(SelData.Selection),' SelData.Length=',dbgs(SelData.Length));
    {$EndIf}
    if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
    or (SelData.Target<>FormatAtom) then begin
      {$IfDef DEBUG_CLIPBOARD}
      DebugLn('[TGtkWidgetSet.ClipboardGetData] REQUESTED FORMAT NOT SUPPORTED  Length=',dbgs(SelData.Length));
      {$ENDIF}
      exit;
    end;

    // write data to stream
    if (SelData.Data<>nil) and (SelData.Length>0) then begin
      if (FormatID=gdk_atom_intern('text/plain',GdkTrue)) then begin
        // the lcl expects the return format as simple text
        // transform if necessary
        if FormatAtom=gdk_atom_intern('COMPOUND_TEXT',GdkTrue) then begin
          CompoundTextCount:=gdk_text_property_to_text_list(SelData.{$IfDef GTK2}_Type{$Else}theType{$EndIf},
            SelData.Format,SelData.Data,SelData.Length,{$IfDef GTK1}@{$EndIf}CompoundTextList);
          {$IfDef DEBUG_CLIPBOARD}
          DebugLn('[TGtkWidgetSet.ClipboardGetData] D  CompoundTextCount=',dbgs(CompoundTextCount),' Now=',dbgs(Now));
          {$EndIf}
          for i:=0 to CompoundTextCount-1 do
            if (CompoundTextList[i]<>nil) then
              Stream.Write(CompoundTextList[i]^,StrLen(CompoundTextList[i]));
          gdk_free_text_list(CompoundTextList);
        end else
          Stream.Write(SelData.Data^,SelData.Length);
      end else begin
        Stream.Write(SelData.Data^,SelData.Length);
      end;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtkWidgetSet.ClipboardGetData] END ',' Now=',dbgs(Now));
    {$EndIf}
    Result:=true;
  finally
    if SupportedFormats<>nil then FreeMem(SupportedFormats);
    if SelData.Data<>nil then FreeMem(SelData.Data);
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
function TGtkWidgetSet.ClipboardGetFormats(ClipboardType: TClipboardType;
  var Count: integer; var List: PClipboardFormat): boolean;
type
  PGdkAtom = ^TGdkAtom;
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
  DebugLn('[TGtkWidgetSet.ClipboardGetFormats] A ClipboardWidget=',Dbgs(ClipboardWidget),' Now=',dbgs(Now));
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
    DebugLn('[TGtkWidgetSet.ClipboardGetFormats] Checking TARGETS answer ',
      ' selection: '+dbgs(SelData.Selection)+'='+dbgs(ClipboardTypeAtoms[ClipboardType])+
                ' "'+GdkAtomToStr(SelData.Selection)+'"',
      ' target: '+dbgs(SelData.Target),'=',dbgs(AllID),
                ' "'+GdkAtomToStr(SelData.Target),'"',
      ' theType: '+dbgs(SelData.{$IFDEF Gtk1}theType{$ELSE}_type{$ENDIF})+'='+dbgs(gdk_atom_intern('ATOM',GdkFalse))+
                ' "'+GdkAtomToStr(SelData.{$IFDEF Gtk1}theType{$ELSE}_type{$ENDIF})+'"',
      ' Length='+dbgs(SelData.Length),
      ' Format='+dbgs(SelData.Format),
      ' Data='+Dbgs(SelData.Data),
      ' Now='+dbgs(Now)
      );
    {$EndIf}
    if (SelData.Selection<>ClipboardTypeAtoms[ClipboardType])
    or (SelData.Target<>AllID)
    or (SelData.Format<=0)
    or ((SelData.{$IfDef GTK2}_Type{$Else}TheType{$EndIf}<>gdk_atom_intern('ATOM',GdkFalse))
         and (SelData.{$IfDef GTK2}_Type{$Else}TheType{$EndIf}<>AllID))
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
        DebugLn('[TGtkWidgetSet.ClipboardGetFormats] Supported formats: ',
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
function TGtkWidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
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

{function TGtkWidgetSet.ClipboardGetOwnerShip(ClipboardType: TClipboardType;
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
    DebugLn('[TGtkWidgetSet.ClipboardGetOwnerShip] A');
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
    DebugLn('[TGtkWidgetSet.ClipboardGetOwnerShip] B');
    {$EndIf}
    if IsFormatSupported(gdk_atom_intern('text/plain',GdkTrue)) then
    begin
      // lcl provides 'text/plain' and the gtk-interface will automatically
      // provide some more text formats
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
    DebugLn('[TGtkWidgetSet.ClipboardGetOwnerShip] C');
    {$EndIf}
    if gtk_selection_owner_set(ClipboardWidget,
      ClipboardTypeAtoms[ClipboardType],0)=GdkFalse
    then begin
      {$IfDef DEBUG_CLIPBOARD}
      DebugLn('[TGtkWidgetSet.ClipboardGetOwnerShip] D FAILED');
      {$EndIf}
      exit;
    end;

    {$IfDef DEBUG_CLIPBOARD}
    DebugLn('[TGtkWidgetSet.ClipboardGetOwnerShip] YEAH, got it!');
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

{------------------------------------------------------------------------------
  Function: ClipboardRegisterFormat
  Params:  AMimeType
  Returns: the registered Format identifier (TClipboardFormat)
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ClipboardRegisterFormat(
  const AMimeType:String): TClipboardFormat;
var AtomName: PChar;
begin
  if Assigned(Application) then begin
    AtomName:=PChar(AMimeType);
    Result:=gdk_atom_intern(AtomName,GdkFalse);
  end else
    RaiseGDBException(
      'ERROR: TGtkWidgetSet.ClipboardRegisterFormat gdk not initialized');
end;


{------------------------------------------------------------------------------
  Function: CreateBitmap
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateBitmap(Width, Height: Integer; Planes, BitCount: Longint; BitmapBits: Pointer): HBITMAP;


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
    FillChar(Header, SizeOf(Header), 0);
    
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
      if not gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(@Header), MIN_LOADER_HEADER_SIZE {$ifdef gtk2},nil{$endif})
      then begin
        DebugLn('WARNING: [TGtkWidgetSet.CreateBitmap] Error loading Bitmap Header!');
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
          res := gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(BitsPtr), LineSize {$ifdef gtk2},nil{$endif})
             and gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(@ALIGNDATA), 2 {$ifdef gtk2},nil{$endif});
          Inc(BitsPtr, LineSize);
          Dec(Count);
        end;
      end
      else begin
        // data is DWord aligned :)
        res := gdk_pixbuf_loader_write(Loader, TGdkPixBufBuffer(BitmapBits), Header.InfoHeader.biSizeImage {$ifdef gtk2},nil{$endif});
      end;
    
      if not res
      then begin
        DebugLn('WARNING: [TGtkWidgetSet.CreateBitmap] Error loading Image!');
        Exit;
      end;

      Src := gdk_pixbuf_loader_get_pixbuf(loader);
      if Src = nil
      then begin
        DebugLn('WARNING: [TGtkWidgetSet.CreateBitmap] Error loading Pixbuf!');
        Exit;
      end;

    finally
      gdk_pixbuf_loader_close(Loader {$ifdef gtk2},nil {$endif});
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
  //DebugLn(Format('Trace:> [TGtkWidgetSet.CreateBitmap] Width: %d, Height: %d, Planes: %d, BitCount: %d, BitmapBits: 0x%x', [Width, Height, Planes, BitCount, PtrUInt(BitmapBits)]));

  if (BitCount < 1) or (Bitcount > 32)
  then begin
    Result := 0;
    DebugLn(Format('ERROR: [TGtkWidgetSet.CreateBitmap] Illegal depth %d', [BitCount]));
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

  Result := HBITMAP(PtrUInt(GdiObject));

  //DebugLn(Format('Trace:< [TGtkWidgetSet.CreateBitmap] --> 0x%x', [Integer(Result)]));
end;


{------------------------------------------------------------------------------
  Function:  CreateBrushIndirect
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateBrushIndirect(const LogBrush: TLogBrush): HBRUSH;
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
  //DebugLn(Format('Trace:> [TGtkWidgetSet.CreateBrushIndirect]  Style: %d, Color: %8x', [LogBrush.lbStyle, LogBrush.lbColor]));

  {$IFDEF DebugGDKTraps}
  BeginGDKErrorTrap;
  {$ENDIF}

  GObject := NewGDIObject(gdiBrush);
  try
    {$IFDEF DebugGDIBrush}
    DebugLn('[TGtkWidgetSet.CreateBrushIndirect] ',DbgS(GObject));
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
            if IsValidGDIObject(lbHatch) and (PGdiObject(lbHatch)^.GDIType = gdiBitmap) then
            begin
              case PGdiObject(lbHatch)^.GDIBitmapType of
                gbBitmap:
                begin
                  GObject^.GDIBrushPixmap := PGdiObject(lbHatch)^.GDIBitmapObject;
                  GObject^.GDIBrushFill := GDK_STIPPLED;
                end;
                gbPixmap:
                begin
                  GObject^.GDIBrushPixmap := PGdiObject(lbHatch)^.GDIPixmapObject.Image;
                  GObject^.GDIBrushFill := GDK_TILED;
                end;
                gbPixbuf:
                begin
                  GObject^.GDIBrushPixmap := nil;
                  TmpMask := nil;
                  gdk_pixbuf_render_pixmap_and_mask(PGdiObject(lbHatch)^.GDIPixbufObject,
                    GObject^.GDIBrushPixmap, TmpMask, $80);
                  gdk_pixmap_unref(TmpMask);
                end;
                else
                begin
                  DebugLn('TGtkWidgetSet.CreateBrushIndirect: Unsupported GDIBitmapType')
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
    Result := HBRUSH(PtrUInt(GObject));
  except
    Result:=0;
    DisposeGDIObject(GObject);
    DebugLn('TGtkWidgetSet.CreateBrushIndirect failed');
  end;
  //DebugLn(Format('Trace:< [TGtkWidgetSet.CreateBrushIndirect] Got --> %x', [Result]));
end;

{------------------------------------------------------------------------------
  Function: CreateCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateCaret(Handle: HWND; Bitmap: hBitmap;
  Width, Height: Integer): Boolean;
var
  GTKObject: PGTKObject;
  BMP: PGDKPixmap;
begin
  //DebugLn('Trace:TODO: [TGtkWidgetSet.CreateCaret] Finish');

  GTKObject := PGTKObject(Handle);
  Result := GTKObject <> nil;

  if Result then begin
    if gtk_type_is_a(gtk_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      if IsValidGDIObjectType(Bitmap, gdiBitmap) then
        BMP := PGdiObject(Bitmap)^.GDIBitmapObject
      else
        BMP := nil;
      GTKAPIWidget_CreateCaret(PGTKAPIWidget(GTKObject), Width, Height, BMP);
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end
  else begin
    //DebugLn('Trace:WARNING: [TGtkWidgetSet.CreateCaret] Got null HWND');
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
function TGtkWidgetSet.CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
var
  DevCtx: TGtkDeviceContext absolute DC;
  
  GDIObject: PGdiObject;
  Depth : Longint;
  Drawable, DefDrawable: PGDkDrawable;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.CreateCompatibleBitmap] DC: 0x%x, W: %d, H: %d', [DC, Width, Height]));

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
    DebugLn(Format('ERROR: [TGtkWidgetSet.CreateCompatibleBitmap] Illegal depth %d', [Depth]));
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

  Result := HBITMAP(PtrUInt(GdiObject));

  //DebugLn(Format('Trace:< [TGtkWidgetSet.CreateCompatibleBitmap] DC: 0x%x --> 0x%x', [DC, Result]));
end;

{------------------------------------------------------------------------------
  Function: CreateCompatibleDC
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateCompatibleDC(DC: HDC): HDC;
var
  pNewDC: TGtkDeviceContext;
begin
  Result := 0;
  pNewDC := NewDC;

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

  {$IFDEF Gtk1}
  pNewDC.GetFont;
  pNewDC.GetBrush;
  pNewDC.GetPen;
  {$ENDIF}

  Result := HDC(pNewDC);

  //DebugLn(Format('trace:  [TGtkWidgetSet.CreateCompatibleDC] DC: 0x%x --> 0x%x', [Integer(DC), Integer(Result)]));
end;

function TGtkWidgetSet.DestroyCursor(Handle: hCursor): Boolean;
begin
  Result := Handle <> 0;
  if Result then
    gdk_cursor_destroy(PGdkCursor(Handle));
end;

function TGTKWidgetSet.DestroyIcon(Handle: HICON): Boolean;
begin
  // todo: handle cursors here, but how to check whether it is a cursor or an icon?
  Result := Handle <> 0;
  if Result then
    gdk_pixbuf_unref(PGdkPixbuf(Handle));
end;

function TGTKWidgetSet.DPtoLP(DC: HDC; var Points; Count: Integer): BOOL;
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

{------------------------------------------------------------------------------
  Function: CreateFontIndirect
  Params:  const LogFont: TLogFont
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateFontIndirect(const LogFont: TLogFont): HFONT;
begin
  Result := CreateFontIndirectEx(LogFont,'');
end;

{------------------------------------------------------------------------------
  Function: CreateFontIndirectEx
  Params:  const LogFont: TLogFont; const LongFontName: string
  Returns: HFONT

  Creates a font GDIObject.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateFontIndirectEx(const LogFont: TLogFont;
  const LongFontName: string): HFONT;
{$IfDef GTK2}
begin
  DebugLn('ToDo: TGtkWidgetSet.CreateFontIndirectEx');
  Result:=0;
end;
{$Else Gtk1}

{off $DEFINE VerboseFonts}
var
  GdiObject: PGdiObject;
  FontNameRegistry, Foundry, FamilyName, WeightName,
  Slant, SetwidthName, AddStyleName, PixelSize,
  PointSize, ResolutionX, ResolutionY, Spacing, AverageWidth,
  CharSetRegistry, CharSetCoding: string;
  n: Integer;
  sn, cs: Float;
  CachedFont: TGtkFontCacheDescriptor;
  CharsetRec: PCharSetEncodingRec;
  Weightlist: TStringlist;
  CalcPixelSize: boolean;


  function LoadFontXLFD(aXLFD: string): boolean;
  var
    Desc: TGtkFontCacheDescriptor;
  begin
    GdiObject^.GDIFontObject := gdk_font_load(PChar(aXLFD));
    Result:=GdiObject^.GDIFontObject<>nil;
    {$ifdef VerboseFonts}
    DebugLn('LoadFontXLFD: Trying ',aXLFD,' Matched=',dbgs(Result));
    {$endif}
    if Result then begin
      Desc:=FontCache.Add(GdiObject^.GDIFontObject,LogFont,LongFontName);
      if Desc<>nil then
        Desc.xlfd:=aXLFD;
    end;
  end;

  function LoadFont: boolean;
  var
    S: string;
  begin
    S:=FontNameRegistry+'-'+Foundry+'-'+FamilyName+'-'+WeightName
       +'-'+Slant+'-'+SetwidthName+'-'+AddStyleName+'-'+PixelSize
       +'-'+PointSize+'-'+ResolutionX+'-'+ResolutionY+'-'+Spacing+'-'+AverageWidth
       +'-'+CharSetRegistry+'-'+CharSetCoding;
    { MG: heaptrc gets corrupted heap using the construction below:
    S := Format('%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s-%s',
      [FontNameRegistry, Foundry, FamilyName, WeightName,
       Slant, SetwidthName, AddStyleName, PixelSize,
       PointSize, ResolutionX, ResolutionY, Spacing, AverageWidth,
       CharSetRegistry, CharSetCoding
      ]);}

    //DebugLn('  Trying Font "',S,'"');
    result := LoadFontXLFD(S);
  end;

  function LoadFontExCharset: boolean;
  var
    i: Integer;
    aSlant, aSpacing,head, mid, tail: string;
  begin
    Result := False;
    Head := FontNameRegistry+'-'+Foundry+'-'+FamilyName+'-';
    Mid  := '-'+SetwidthName+'-'+AddStyleName+'-'+PixelSize
           +'-'+PointSize+'-'+ResolutionX+'-'+ResolutionY+'-';
    Tail := '-'+AverageWidth+'-'+CharSetRegistry+'-'+CharSetCoding;
    //debugln('LoadFontExCharset Head=',Head,' Tail=',Tail);
    for i:=0 to WeightList.Count-1 do begin
      aSlant := Slant;
      repeat
        aSpacing:=Spacing;
        repeat
          result := LoadFontXLFD(Head+WeightList[i]+'-'+aSlant+Mid+aSpacing+Tail);
          if result then
            exit;

          if aSpacing = 'm' then
            aSpacing := 'c'
          else
            break;
        until false;

        if aSlant='i' then
          aSlant:='o'
        else
          break;
      until false;
    end;
    //debugln('LoadFontExCharset END');
  end;

  function LoadFontEx: boolean;
  var
    j: integer;
  begin
    Result := false;
    //debugln('LoadFontEx START CharSetRegistry=',CharSetRegistry);
    if CharSetRegistry<>'*' then
      result := LoadFontExCharset
    else
      for j:=0 to CharSetEncodingList.Count-1 do begin
        CharSetRec := CharsetEncodingList[j];
        if (CharsetRec = nil) or (CharSetRec^.CharSet<>LogFont.lfCharset) then
          continue;
        CharSetCoding := CharsetRec^.CharSetCod;
        CharSetRegistry := CharSetRec^.CharSetReg;
        result := LoadFontExCharset;
        if result then
          break;
      end;
    //debugln('LoadFontEx END');
  end;

  procedure LoadDefaultFont;
  begin
    ReleaseGdiObject(GdiObject);
    GdiObject:=CreateDefaultFont;
    {$IFDEF VerboseFonts}
    DebugLn('TGtkWidgetSet.CreateFontIndirectEx.LoadDefaultFont');
    {$ENDIF}
  end;

  function GetDefaultFontFamilyName: string;
  begin
    Result:=GetDefaultFontName;
    if IsFontNameXLogicalFontDesc(Result) then
      Result := ExtractXLFDItem(Result,2);
    if Result='' then Result:='*';
  end;

  function ExtractXLFDItemMask(const ALongFontName: string;
    Index: Integer): string;
  begin
    Result:=ExtractXLFDItem(ALongFontName,Index);
    if Result='' then Result:='*';
  end;

  function FamilyNameExists: boolean;
  var
    AFont: PGdkFont;
    S: String;
  begin
    //S := '*-*-'+FamilyName+'*-*-*-*-*-*-*-*-*-*-*-*-*';
    S := '-'+Foundry+'-'+FamilyName+'-*-*-*-*-*-*-*-*-*-*-*-*';
    AFont:=gdk_font_load(PChar(s));
    Result:=AFont<>nil;
    if Result then gdk_font_unref(AFont);
  end;

  function CheckFontNameIsMangledXLogicalFontDesc(const ALongFontName: string
    ): boolean;
  var
    c: Integer;
    i: Integer;
  begin
    c:=0;
    for i:=1 to length(ALongFontName) do
      if ALongFontName[i]='-' then inc(c);
    Result:=(c>5) and (c<>14);
    if Result then
      debugln('WARNING: Fontnamt "',ALongFontName,'" seems to be a XLFD fontname, but has 14<>',dbgs(c),' minus signs');
  end;
  
  function GetPixelSize(Offset: Integer): string;
  begin
    with LogFont do begin
      result := IntToStr(Abs(lfHeight)+Offset);
      {$IFNDEF OLD_ROTATION}
      if lfOrientation <> 0 then begin
        SinCos(lfOrientation/1800.*Pi, sn, cs);
        cs := cs*(Abs(lfHeight)+Offset);
        sn := sn*(Abs(lfHeight)+Offset);
        Result := Format('[%.3f %.3f %.3f %.3f]', [cs, sn, -sn, cs]);
        repeat
          n := Pos('-', Result);
          if n > 0 then
            Result[n] := '~';
        until n <= 0;
      end;
    end;
    {$ENDIF}
  end;
  
begin
  // For info about xlfd see:
  //    http://wwwinfo.cern.ch/umtf/working-groups/X11/fonts/hp_xlfd.html
  // Lets fill in all the xlfd parts. Assume we have scalable fonts.
  {$IFDEF VerboseFonts}
  DebugLn('TGtkWidgetSet.CreateFontIndirectEx A Name=',LogFont.lfFaceName,' Height=',dbgs(LogFont.lfHeight),' LongName=',LongFontName);
  {$ENDIF}
  Result := 0;
  GDIObject := NewGDIObject(gdiFont);
  try
    GdiObject^.UntransfFontHeight := 0;
    GdiObject^.LogFont := LogFont;

    CachedFont:=FontCache.FindGTkFontDesc(LogFont,LongFontName);
    if CachedFont<>nil then begin
      CachedFont.Item.IncreaseRefCount;
      GdiObject^.GDIFontObject := TGtkFontCacheItem(CachedFont.Item).GtkFont;
      {$IFDEF VerboseFonts}
      WriteLn('Was in cache: ', Integer(CachedFont));
      {$ENDIF}
      exit;
    end;

    // set default values
    FontNameRegistry := '*';
    Foundry := '*';
    FamilyName := '*';
    WeightName := '*';
    Slant := '*';
    SetwidthName := '*';
    AddStyleName := '*';
    PixelSize := '*';
    PointSize := '*';
    ResolutionX := '*';
    ResolutionY := '*';
    Spacing := '*';
    AverageWidth := '*';
    CharSetRegistry := '*';
    CharSetCoding := '*';

    // check if LongFontName is in XLFD format and get nicer defaults
    // This way, the user can set X fonts that are not supported by TFont.

    {$IFDEF VerboseFonts}
    DebugLn('TGtkWidgetSet.CreateFontIndirectEx Name="',LogFont.lfFaceName,'"',
    ' Long="',LongFontName,'" IsXLFD=',dbgs(IsFontNameXLogicalFontDesc(LongFontName))
    ,' ',dbgs(ord(LogFont.lfFaceName[0])));
    {$ENDIF}
    
    
    if IsFontNameXLogicalFontDesc(LongFontName) then begin
      FontNameRegistry := ExtractXLFDItemMask(LongFontName,0);
      Foundry          := ExtractXLFDItemMask(LongFontName,1);
      FamilyName       := ExtractXLFDItemMask(LongFontName,2);
      WeightName       := ExtractXLFDItemMask(LongFontName,3);
      Slant            := ExtractXLFDItemMask(LongFontName,4);
      SetWidthName     := ExtractXLFDItemMask(LongFontName,5);
      AddStyleName     := ExtractXLFDItemMask(LongFontName,6);
      PixelSize        := ExtractXLFDItemMask(LongFontName,7);
      PointSize        := ExtractXLFDItemMask(LongFontName,8);
      ResolutionX      := ExtractXLFDItemMask(LongFontName,9);
      ResolutionY      := ExtractXLFDItemMask(LongFontName,10);
      Spacing          := ExtractXLFDItemMask(LongFontName,11);
      AverageWidth     := ExtractXLFDItemMask(LongFontName,12);
      CharSetRegistry  := ExtractXLFDItemMask(LongFontName,13);
      CharSetCoding    := ExtractXLFDItemMask(LongFontName,14);
    end else if CheckFontNameIsMangledXLogicalFontDesc(LongFontName) then begin
      // warned
    end;
    
    with LogFont do
    begin

      if lfFaceName[0] = #0
      then begin
        //DebugLn('ERROR: [TGtkWidgetSet.CreateFontIndirectEx] No fontname');
        Exit;
      end;

      FamilyName := StrPas(lfFaceName);

      if not IsFontNameDefault(FamilyName) then begin
      
        // check if we have foundry encoded in family name
        n := pos(FOUNDRYCHAR_OPEN, FamilyName);
        if n<>0 then begin
          Foundry := copy(FamilyName, n+1, Length(FamilyName));
          familyName := trim(copy(familyName, 1, n-1));
          n := pos(FOUNDRYCHAR_CLOSE, Foundry);
          if n<>0 then
            Delete(Foundry, n, Length(Foundry));
        end;

        if not FamilyNameExists then
          FamilyName:='default';
        
      end;

      if IsFontNameDefault(FamilyName) then begin
        {$IFDEF VerboseFonts}
        DebugLn('TGtkWidgetSet.CreateFontIndirectEx FamilyName="',FamilyName,'" PixelSize=',PixelSize,' LogFont.lfHeight=',dbgs(LogFont.lfHeight));
        {$ENDIF}
        if (LogFont.lfHeight=0) then begin
          LoadDefaultFont;
          exit;
        end else begin
          FamilyName:=GetDefaultFontFamilyName;
          Foundry:='*';
        end;
      end;

      //DebugLn(Format('trace:  [TGtkWidgetSet.CreateFontIndirectEx] Name: %s, Height: %d', [FamilyName, lfHeight]));

      // calculate weight offset.
      //        API                 XLFD
      // --------------------- --------------
      // Weight=400 --> normal normal
      // Weight=700 --> bold   normal+4000 (or bold in non scalable fonts)
      //
      // So in API the offset for normal = 400 and an increase of 300 equals to
      // an offset of 4000
      if WeightName='*' then begin
        case lfWeight of
          FW_DONTCARE   : WeightName := '*';
          FW_LIGHT      : WeightName := 'light';
          FW_NORMAL     : ; // try several later
          FW_MEDIUM     : WeightName := 'medium';
          FW_SEMIBOLD   : WeightName := 'demi bold';
          FW_BOLD       : ; // try several later
          else begin
            n := ((lfWeight - FW_NORMAL) * 4000) div (FW_BOLD - FW_NORMAL);
            if n = 0
            then WeightName := 'normal'
            else if n > 0
            then WeightName := Format('normal+%d', [n])
            else WeightName := Format('normal%d', [n]);
          end;
        end;
      end;

      if Slant='*' then begin
        // TODO: find out if escapement has something to do with slant
        if lfItalic = 0 then Slant := 'r' else Slant := 'i';
      end;

      // SetWidthName := '*';
      {$IFDEF OLD_ROTATION}
      if AddStyleName='*' then begin
        // calculate Style name extensions (=rotation)
        //        API                 XLFD
        // --------------------- --------------
        // Orientation 1/10 deg  1/64 deg
        if lfOrientation = 0
        then AddStyleName := '*'
        else begin
          n := (lfOrientation * 64) div 10;
          if n >= 0
          then AddStyleName := Format('+%d', [n])
          else AddStyleName := Format('+%d', [n]);
        end;
      end;
      {$ENDIF}

      CalcPixelSize:= (PixelSize='*') and (PointSize='*');
      if CalcPixelSize then begin
        // TODO: make more accurate (implement the meaning of
        //       positive and negative height values.
        PixelSize := GetPixelSize(0);
        // Since we use pixelsize, it isn't allowed to give a value here
        PointSize := '*';

        // Use the default
        ResolutionX := '*';
        ResolutionY := '*';
      end;

      if Spacing='*' then begin
        // spacing
        if (FIXED_PITCH and lfPitchAndFamily)>0 then
          Spacing := 'm'   // mono spaced
        else if (VARIABLE_PITCH and lfPitchAndFamily)>0 then
          Spacing := 'p'   // proportional spaced
        else
          Spacing := '*';
      end;

      if AverageWidth='*' then begin
        // calculate AverageWidth
        //        API                 XLFD
        // --------------------- --------------
        // Width pixel             1/10 pixel
        if lfWidth = 0
        then AverageWidth := '*'
        else AverageWidth := InttoStr(lfWidth * 10);
      end;
      
      // this section tries several combinations of charset-weightname-slant
      //
      WeightList := TStringList.Create;
      if LogFOnt.LfWeight = FW_BOLD then
        // bold appears most times
        WeightList.CommaText := 'bold,semibold,demibold,black,*'
      else
        // medium appears most times but if there is normal, use it
        WeightList.CommaText := 'normal,medium,regular,light,*';
      if WeightName<>'*' then
        WeightList.Insert(0, WeightName);

      try
        if LoadFontEx then
          exit;
          
        // not found yet, before doing a generic fall over
        // try to do a more specific guess.
        if CalcPixelSize then
        repeat

          // try one pixel smaller
          {$IFDEF VerboseFonts}
          debugln('TGtkWidgetSet.CreateFontIndirectEx, LoadFontEx: try one pixel smaller');
          {$ENDIF}
          PixelSize:=GetPixelSize(-1);
          if LoadFontEx then
            exit;
            
          // try one pixel bigger
          {$IFDEF VerboseFonts}
          debugln('TGtkWidgetSet.CreateFontIndirectEx, LoadFontEx: try one pixel bigger');
          {$ENDIF}
          PixelSize:=GetPixelSize(1); // try
           if LoadFontEx then
            exit;
            
          // not found yet
          // if font was slanted try with any within font face.
          if Slant<>'*' then begin
            Slant := '*';
            continue;
          end;
          
          break;
          
        until false;
        
      finally
        WeightList.Free;
      end;
    end;

    // next checks are fall over

    {$IFDEF VerboseFonts}
    debugln('TGtkWidgetSet.CreateFontIndirectEx ');
    {$ENDIF}
    {
    if LoadFont then exit;
    
    // try all weights
    WeightName := '*';
    if LoadFont then exit;
    }
    // try one height smaller
    {$IFDEF VerboseFonts}
    debugln('TGtkWidgetSet.CreateFontIndirectEx try one height smaller');
    {$ENDIF}
    PixelSize := IntToStr(Abs(LogFont.lfHeight)-1);
    // Since we use pixelsize, it isn't allowed to give a value here
    PointSize := '*';

    // Use the default
    ResolutionX := '*';
    ResolutionY := '*';

    if LoadFont then exit;

    // try one height bigger
    {$IFDEF VerboseFonts}
    debugln('TGtkWidgetSet.CreateFontIndirectEx try one height bigger');
    {$ENDIF}
    PixelSize := IntToStr(Abs(LogFont.lfHeight)+1);
    if LoadFont then exit;

    PixelSize := IntToStr(Abs(LogFont.lfHeight));

    // try instead of mono spaced -> character cell spaced
    if (Spacing='m') then begin
      {$IFDEF VerboseFonts}
      debugln('TGtkWidgetSet.CreateFontIndirectEx try instead of mono spaced -> character cell spaced');
      {$ENDIF}
      Spacing:='c';
      if LoadFont then exit;
    end;
    {
    // try instead of italic -> oblique
    if (Slant='i') then begin
      Slant := 'o';
      if LoadFont then exit;
    end;

    // try all slants
    Slant := '*';
    if LoadFont then exit;
    }
    // try all spacings
    if spacing<>'*' then begin
      {$IFDEF VerboseFonts}
      debugln('TGtkWidgetSet.CreateFontIndirectEx try all spacings');
      {$ENDIF}
      Spacing := '*';
      if LoadFont then exit;
    end;

    if charSetCoding<>'*' then begin
      {$IFDEF VerboseFonts}
      debugln('TGtkWidgetSet.CreateFontIndirectEx try all charsets');
      {$ENDIF}
      charsetCoding := '*';
      charSetRegistry:= '*';
      if LoadFont then exit;
    end;

    if (Foundry<>'*') then begin
      // try all Families
      {$IFDEF VerboseFonts}
      debugln('TGtkWidgetSet.CreateFontIndirectEx try all families');
      {$ENDIF}
      PixelSize := IntToStr(Abs(LogFont.lfHeight));
      FamilyName := '*';
      if LoadFont then exit;
    end;

    // nothing exists -> use default
    LoadDefaultFont;

  finally
    if GdiObject^.GDIFontObject = nil
    then begin
      {$IFDEF VerboseFonts}
      DebugLn('[TGtkWidgetSet.CreateFontIndirect] ',DbgS(GdiObject),'  ',dbgs(FGDIObjects.Count));
      {$ENDIF}
      DisposeGDIObject(GdiObject);
      Result := 0;
    end
    else begin
      Result := HFONT(PtrUInt(GdiObject));
    end;

    if Result = 0
    then
      DebugLn('WARNING: [TGtkWidgetSet.CreateFontIndirectEx] NOT found XLFD: <'+LongFontName+'> Fontname="'+LogFont.lfFaceName+'"')
    else begin
      //DebugLn(Format('Trace:  [TGtkWidgetSet.CreateFontIndirectEx] found XLFD: <%s>', [LongFontName]));
    end;
  end;
end;
{$EndIf}

function TGTKWidgetSet.CreateIconIndirect(IconInfo: PIconInfo): HICON;
  procedure GetColorMask(AImage, AMask: PGDKPixmap; AImgBits, AMskBits: PByte; AWidth, AHeight: integer);
  var
    i, j: integer;
    colormap: PGDKColormap;
    Image, MaskImage: PGDKImage;
    GDKColor: TGDKColor;
    Pixel, MaskPixel: LongWord;
    offset: byte;

    procedure SetColorAndMaskPixmap(c: TGdkColor; MaskPixel: LongWord);
    var
      c_bit, m_bit: byte;
    begin
      // c_bit := Ord(0.222 * c.red + 0.707 * c.green + 0.071 * c.blue >= $8000);
      // do some int math
      c_bit := Ord(cardinal(222) * c.red
                 + cardinal(707) * c.green
                 + cardinal(071) * c.blue
                 >= $8000 * 1000);
      m_bit := ord(MaskPixel = 1);

      AImgBits^ := AImgBits^ or (c_bit shl offset);
      AMskBits^ := AMskBits^ or (m_bit shl offset);

      inc(offset);
      if offset > 7 then
      begin
        inc(AImgBits);
        inc(AMskBits);
        offset := 0;
      end;
    end;
    
    procedure SetColorAndMaskBitmap(ColorPixel, MaskPixel: LongWord);
    begin
      AImgBits^ := AImgBits^ or (ColorPixel shl offset);
      AMskBits^ := AMskBits^ or (MaskPixel shl offset);

      inc(offset);
      if offset > 7 then
      begin
        inc(AImgBits);
        inc(AMskBits);
        offset := 0;
      end;
    end;

  begin
    // most of this code was taken from TGtkWidgetSet.DCGetPixel

    Image := gdk_drawable_get_image(AImage, 0, 0, AWidth, AHeight);
    if AMask = nil
    then MaskImage := nil
    else MaskImage := gdk_drawable_get_image(AMask, 0, 0, AWidth, AHeight);

    offset := 0;

    if gdk_drawable_get_depth(AImage) = 1 then
    begin
      for j := 0 to AHeight - 1 do
        for i := 0 to AWidth - 1 do
        begin
          Pixel := gdk_image_get_pixel(Image, i, j);
          if MaskImage = nil
          then MaskPixel := 1
          else MaskPixel := gdk_image_get_pixel(MaskImage, i, j);
          SetColorAndMaskBitmap(Pixel, MaskPixel);
        end;
    end
    else
    begin
      {$ifdef Gtk1}
      // previously gdk_image_get_colormap(image) was used, implementation
      // was casting GdkImage to GdkWindow which is not valid and cause AVs
      if gdk_window_get_type(PGdkWindow(AImage))= GDK_WINDOW_PIXMAP then
        colormap := nil // pixmaps are created with null colormap, get system one instead
      else
        colormap := gdk_window_get_colormap(PGdkWindow(AImage));
      {$else}
      colormap := gdk_image_get_colormap(image);
      {$endif}
      if colormap = nil then
        colormap := gdk_colormap_get_system;
        
      for j := 0 to AHeight - 1 do
        for i := 0 to AWidth - 1 do
        begin
          Pixel := gdk_image_get_pixel(Image, i, j);
          if MaskImage = nil
          then MaskPixel := 1
          else MaskPixel := gdk_image_get_pixel(MaskImage, i, j);
          FillChar(GDKColor,SizeOf(GDKColor), 0);
          gdk_colormap_query_color(colormap, Pixel, @GDKColor);
          SetColorAndMaskPixmap(GDKColor, MaskPixel);
        end;
    end;
    
    gdk_image_unref(Image);
    if MaskImage <> nil
    then gdk_image_unref(MaskImage);
  end;

var
  FG, BG: TGDKColor;
  Img, Msk: PGdkPixmap;
  Pixbuf: PGdkPixbuf;
  srcbitmap, mskbitmap: PGdkBitmap;
  W, H, bitlen: integer;
  ImgBits, MskBits: array of byte;
begin
  Result := 0;
  if not IsValidGDIObject(IconInfo^.hbmColor) then Exit;

  if PGDIObject(IconInfo^.hbmColor)^.GDIBitmapType = gbPixbuf then
  begin
    Pixbuf := PGDIObject(IconInfo^.hbmColor)^.GDIPixbufObject;
    if IconInfo^.fIcon then
    begin
      // Creating PixBuf from pixmap and mask
      Result := HICON(PtrUInt(gdk_pixbuf_copy(pixbuf)));
      Exit;
    end;
    W := gdk_pixbuf_get_width(Pixbuf);
    H := gdk_pixbuf_get_height(Pixbuf);
    Img := nil;
    Msk := nil;
    gdk_pixbuf_render_pixmap_and_mask(Pixbuf, Img, Msk, $80);
  end
  else
  begin
    Img := PGDIObject(IconInfo^.hbmColor)^.GDIBitmapObject;
    gdk_drawable_get_size(Img, @W, @H);

    Msk := CreateGdkMaskBitmap(IconInfo^.hbmColor, IconInfo^.hbmMask);
    //DbgDumpPixmap(Img, 'Image');
    //DbgDumpPixmap(Msk, 'Mask');
    if IconInfo^.fIcon then
    begin
      // Creating PixBuf from pixmap and mask
      Result := HICON(PtrUInt(CreatePixbufFromImageAndMask(Img, 0, 0, W, H, nil, Msk)));
      if Msk <> nil then
        gdk_bitmap_unref(Msk);
      Exit;
    end;
  end;

  try
    // Create cursor

    bitlen := (W * H) shr 3;
    SetLength(ImgBits, bitlen);
    SetLength(MskBits, bitlen);
    FillChar(ImgBits[0], bitlen, 0);
    FillChar(MskBits[0], bitlen, 0);

    GetColorMask(Img, Msk, @ImgBits[0], @MskBits[0], W, H);

    srcbitmap := gdk_bitmap_create_from_data(nil, @ImgBits[0], W, H);
    mskbitmap := gdk_bitmap_create_from_data(nil, @MskBits[0], W, H);

    // white
    fg.red := $FFFF;
    fg.green := $FFFF;
    fg.blue := $FFFF;
    fg.pixel := 0;

    // black
    bg.red := 0;
    bg.green := 0;
    bg.blue := 0;
    bg.pixel := 0;

    Result := HCURSOR(PtrUInt(gdk_cursor_new_from_pixmap(srcbitmap, mskbitmap,
      @fg, @bg, IconInfo^.xHotspot, IconInfo^.yHotspot)));

    gdk_pixmap_unref(srcbitmap);
    gdk_pixmap_unref(mskbitmap);
  finally
    if msk <> nil
    then gdk_bitmap_unref(msk);
    if Img <> PGDIObject(IconInfo^.hbmColor)^.GDIBitmapObject
    then gdk_pixmap_unref(Img);
  end;
end;

{------------------------------------------------------------------------------
  Function: CreatePalette
  Params:  LogPalette
  Returns: a handle to the Palette created


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreatePalette(const LogPalette: TLogPalette): HPALETTE;
var
  GObject: PGdiObject;
begin
  //DebugLn('trace:[TGtkWidgetSet.CreatePalette]');

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

  Result := HPALETTE(PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Function: CreatePenIndirect
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreatePenIndirect(const LogPen: TLogPen): HPEN;
var
  GObject: PGdiObject;
begin
  //DebugLn('trace:[TGtkWidgetSet.CreatePenIndirect]');
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

  Result := HPEN(PtrUInt(GObject));
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
function TGtkWidgetSet.CreatePolygonRgn(Points: PPoint; NumPts: Integer;
  FillMode: integer): HRGN;
var
  i: integer;
  PointArray: PGDKPoint;
  GObject: PGdiObject;
  fr : TGDKFillRule;
begin
  Result := 0;
  if NumPts<=0 then exit;
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

  Result := HRGN(PtrUInt(GObject));
end;

{------------------------------------------------------------------------------
  Function: CreateRectRgn
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.CreateRectRgn(X1,Y1,X2,Y2 : Integer): HRGN;
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

  Result := HRGN(PtrUInt(GObject));
  //DebugLn('TGtkWidgetSet.CreateRectRgn A ',GDKRegionAsString(RegionObj));
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
function TGtkWidgetSet.CombineRgn(Dest, Src1, Src2 : HRGN;
  fnCombineMode : Longint) : Longint;
var
  Continue : Boolean;
  D, S1, S2 : PGDKRegion;
  DObj, S1Obj, S2Obj : PGDIObject;
begin
  Result := SIMPLEREGION;
  DObj := PGdiObject(Dest);
  S1Obj := PGdiObject(Src1);
  S2Obj := PGdiObject(Src2);
  Continue := IsValidGDIObject(Dest) and IsValidGDIObject(Src1)
              and IsValidGDIObject(Src2);
  If Not Continue then begin
    DebugLn('WARNING: [TGtkWidgetSet.CombineRgn] Invalid HRGN');
    Result := Error;
  end
  else begin
    S1 := S1Obj^.GDIRegionObject;
    S2 := S2Obj^.GDIRegionObject;
    //DebugLn('TGtkWidgetSet.CombineRgn A fnCombineMode=',Dbgs(fnCombineMode));
    Case fnCombineMode of
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
    if DObj^.GDIRegionObject <> nil then
      gdk_region_destroy(DObj^.GDIRegionObject);
    DObj^.GDIRegionObject := D;
    Result := RegionType(D);
    //DebugLn('TGtkWidgetSet.CombineRgn B Mode=',dbgs(fnCombineMode),
    //  ' S1=',GDKRegionAsString(S1),' S2=',GDKRegionAsString(S2),' D=',GDKRegionAsString(D),'');
  end;
end;

{------------------------------------------------------------------------------
  Function: DeleteDC
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.DeleteDC(hDC: HDC): Boolean;
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
function TGtkWidgetSet.DeleteObject(GDIObject: HGDIOBJ): Boolean;

  procedure RaiseInvalidGDIObject;
  begin
    {$ifdef TraceGdiCalls}
    DebugLn();
    DebugLn('TGtkWidgetSet.DeleteObject: TraceCall for invalid object: ');
    DumpBackTrace(PgdiObject(GdiObject)^.StackAddrs);
    DebugLn();
    DebugLn('Exception will follow:');
    DebugLn();
    {$endif}
    RaiseGDBException('TGtkWidgetSet.DeleteObject invalid GdiObject='+dbgs(GdiObject));
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
  if DebugGdiObjects.IsDestroyed(GDIObject) then
  begin
    DebugLn(['TGtkWidgetSet.DeleteObject object already deleted ',GDIObject]);
    debugln(DebugGdiObjects.GetInfo(PGdiObject(GDIObject),true));
    Halt;
  end;
  {$ENDIF}

  // Find out if we want to release internal GDI object
  GDIObjectExists := FGDIObjects.Contains(PGdiObject(GDIObject));
  Result := GDIObjectExists;
  if not GDIObjectExists then
  begin
    RaiseInvalidGDIObject;
  end;

  Result := ReleaseGDIObject(PGdiObject(GDIObject));
end;

{------------------------------------------------------------------------------
  Function: DestroyCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.DestroyCaret(Handle: HWND): Boolean;
var
  GTKObject: PGTKObject;
begin
  GTKObject := PGTKObject(Handle);
  Result := true;

  if GTKObject<>nil then begin
    if gtk_type_is_a(gtk_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_DestroyCaret(PGTKAPIWidget(GTKObject));
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end
  else begin
    //DebugLn('Trace:WARNING: [TGtkWidgetSet.DestroyCaret] Got null HWND');
  end;
end;

{------------------------------------------------------------------------------
  Function: DrawFrameControl
  Params:
  Returns:


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.DrawFrameControl(DC: HDC; const Rect : TRect;
  uType, uState : Cardinal) : Boolean;
{const
  ADJUST_FLAG: array[Boolean] of Integer = (0, BF_ADJUST);
  PUSH_EDGE_FLAG: array[Boolean] of Integer = (EDGE_RAISED, EDGE_SUNKEN);
  PUSH_EDGE_FLAG2: array[Boolean] of Integer = (0, BF_FLAT);}
var
  DevCtx: TGtkDeviceContext absolute DC;
  Widget: PGtkWidget;
  R: TRect;

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
    If aStyle = nil then
      aStyle := GetStyle(lgsGTK_Default);

      // MG: You can't assign a style to any window. Why it is needed anyway?
      //aStyle := gtk_style_attach(gtk_style_ref(aStyle),aDC.Drawable);

    if aStyle<>nil then begin
      If (Shadow=GTK_SHADOW_NONE) then
        gtk_paint_flat_box(aStyle,aDC.Drawable,
           State,
           Shadow,
           nil,
           GetStyleWidget(lgsButton),
           'button',
           R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
           R.Right-R.Left,R.Bottom-R.Top)
      else
        gtk_paint_box(aStyle,aDC.Drawable,
           State,
           Shadow,
           nil,
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

    If Style = nil then begin
      Style := GetStyle(lgsGTK_Default);
      If Style <> nil then
        Style := gtk_style_attach(gtk_style_ref(Style),aDC.Drawable);
    end;

    Widget := GetStyleWidget(LazGtkStyleMap[IsRadioButton]);

    If Widget = nil then
      Widget := GetStyleWidget(lgsDefault);
    If Widget <> nil then
      Widget^.Window := aDC.Drawable;
    Result := Style <> nil;
    If Result then begin
      if IsRadioButton then
        gtk_paint_option(Style,aDC.Drawable, State,
          Shadow, nil, Widget, 'radiobutton',
          R.Left+DCOrigin.X,R.Top+DCOrigin.Y,
          R.Right-R.Left, R.Bottom-R.Top)
      else
        gtk_paint_check(Style,aDC.Drawable, State,
          Shadow, nil, Widget, 'checkbutton',
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
        //DebugLn(Format('Trace:  [TGtkWidgetSet.DrawFrameControl] DFC_BUTTON --> draw rect = %d,%d,%d,%d',[R.Left,R.Top,R.Right,R.Bottom]));
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
           DebugLn(Format('ERROR: [TGtkWidgetSet.DrawFrameControl] Unknown State 0x%x', [uState]));
      end;
  else
    DebugLn(Format('ERROR: [TGtkWidgetSet.DrawFrameControl] Unknown type %d', [uType]));
  end;
end;

function TGTKWidgetSet.DrawFocusRect(DC: HDC; const Rect: TRect): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  Origin: TPoint;

  procedure DrawPixel(X1,Y1: Integer);
  begin
    inc(X1,Origin.X);
    inc(Y1,Origin.Y);
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
  if IsValidDC(DC) then begin
    with LogPen do begin
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

      with R do begin
        DrawHorzLine(Left, Top, Right-1);
        DrawVertLine(Right-1, Top, Bottom-1);
        DrawHorzLine(Right-1, Bottom-1, Left);
        DrawVertLine(Left, Bottom-1, Top);
      end;

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
function TGtkWidgetSet.DrawEdge(DC: HDC; var ARect: TRect; Edge: Cardinal;
  grfFlags: Cardinal): Boolean;

var
  DevCtx: TGtkDeviceContext absolute DC;

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
  //DebugLn('TGtkWidgetSet.DrawEdge Edge=',DbgS(Edge),8),' grfFlags=',DbgS(Cardinal(grfFlags));
  Result := IsValidDC(DC);
  if Result
  then with TGtkDeviceContext(DC) do
  begin
    R := ARect;

    if DevCtx.HasTransf then
    begin
      R := DevCtx.TransfRectIndirect(R);
      TransfNormalize(R.Left, R.Right);
      TransfNormalize(R.Top, R.Bottom);
    end;

    DCOrigin := Offset;
    OffsetRect(R,DCOrigin.X,DCOrigin.Y);


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
      DrawEdges(R, GC,Drawable,OuterTL,OuterBR);

    // Draw inner rect
    if BInner then
      DrawEdges(R,GC,Drawable,InnerTL,InnerBR);

//      gdk_colormap_free_colors(gdk_colormap_get_system, @OuterTL, 1);
//      gdk_colormap_free_colors(gdk_colormap_get_system, @OuterBR, 1);
//      gdk_colormap_free_colors(gdk_colormap_get_system, @InnerTL, 1);
//      gdk_colormap_free_colors(gdk_colormap_get_system, @InnerBR, 1);

    //Draw interiour
    if ((grfFlags and BF_MIDDLE) = BF_MIDDLE) then
    begin
      MiddleColor := AllocGDKColor(GetSysColor(COLOR_BTNFACE));
      gdk_gc_set_foreground(GC, @MiddleColor);
      gdk_draw_rectangle(Drawable, GC, 1, R.Left, R.Top,
        R.Right - R.Left, R.Bottom - R.Top);
    end;

    // adjust rect if needed
    if (grfFlags and BF_ADJUST) = BF_ADJUST then
    begin
      OffsetRect(R, -DCOrigin.X, -DCOrigin.Y);
      ARect := R;
    end;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Method:  DrawText
  Params:  DC, Str, Count, Rect, Flags
  Returns: If the string was drawn, or CalcRect run

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.DrawText(DC: HDC; Str: PChar; Count: Integer;
  var Rect: TRect; Flags: Cardinal): Integer;
const
  TabString = '        ';
var
  DevCtx: TGtkDeviceContext absolute DC;
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
    LineWidth: Integer;
  begin
    theRect := Rect;

    MaxWidth := theRect.Right - theRect.Left;

    if (Flags and DT_SINGLELINE) > 0 then
    begin
      // ignore word and line breaks
      TextExtentPoint(PChar(AStr), length(AStr), AP);
      theRect.Bottom := theRect.Top + TM.tmHeight;
      if (Flags and DT_CALCRECT)<>0 then
        theRect.Right := theRect.Left +  AP.cX
      else
      begin
        theRect.Right := theRect.Left + Min(MaxWidth, AP.cX);
        if (Flags and DT_VCENTER) > 0 then
        begin
          OffsetRect(theRect, 0, ((Rect.Bottom - Rect.Top) - (theRect.Bottom - theRect.Top)) div 2);
          {$ifdef Gtk1}
          //gtk1 overestimate TM.tmHeight leading to wrong calculation of the center offset
          OffsetRect(theRect, 0, 1);
          {$endif}
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
        if (Lines <> nil) then
        begin
          for J := 0 to NumLines - 1 do
          begin
            TextExtentPoint(Lines[J], StrLen(Lines[J]), AP);
            LineWidth := Max(LineWidth, AP.cX);
          end;
        end;
        LineWidth := Min(MaxWidth, LineWidth);
      end else
        LineWidth := MaxWidth;

      theRect.Right := theRect.Left + LineWidth;
      theRect.Bottom := theRect.Top + NumLines*TM.tmHeight;
      if NumLines>1 then
        Inc(theRect.Bottom, (NumLines-1)*TM.tmDescent);// space between lines

      //debugln('TGtkWidgetSet.DrawText A ',dbgs(theRect),' TM.tmHeight=',dbgs(TM.tmHeight),' LineWidth=',dbgs(LineWidth),' NumLines=',dbgs(NumLines));
    end;

    if not CalcRect then
      case LeftOffset of
        DT_CENTER:
          OffsetRect(theRect, (Rect.Right - theRect.Right) div 2, 0);
        DT_RIGHT:
          OffsetRect(theRect, Rect.Right - theRect.Right, 0);
      end;
  end;

  procedure DrawLineRaw(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LeftPos: Longint;
  begin
    if LeftOffset <> DT_LEFT then
      GetTextExtentPoint(DC, theLine, LineLength, Points[0]);

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

    // Draw line of Text
    TextUtf8Out(DC, LeftPos, TopPos, theLine, lineLength);
  end;

  procedure DrawLine(theLine: PChar; LineLength, TopPos: Longint);
  var
    Points: array[0..1] of TSize;
    LogP: TLogPen;
    LeftPos: Longint;
  begin
    if TempBrush = HBRUSH(-1) then
      TempBrush := SelectObject(DC, GetStockObject(NULL_BRUSH));

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

    // Draw line of Text
    TextUtf8Out(DC, LeftPos, TopPos, theLine, LineLength);

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

      GetTextExtentPoint(DC, @aStr[pIndex], 1, Points[1]);
      Points[1].cX := Points[0].cX + Points[1].cX;
      Points[1].cY := Points[0].cY;

      {Draw prefix line}
      Polyline(DC, PPoint(@Points[0]), 2);
    end;
  end;

begin
  if (Str=nil) or (Str[0]=#0) then Exit(0);

  //DebugLn(Format('trace:> [TGtkWidgetSet.DrawText] DC:0x%x, Str:''%s'', Count: %d, Rect = %d,%d,%d,%d, Flags:%d',
  //  [DC, Str, Count, Rect.Left, Rect.Top, Rect.Right, Rect.Bottom, Flags]));

  if not IsValidDC(DC) then Exit(0);
  if (Count < -1) or (IsRectEmpty(Rect) and ((Flags and DT_CALCRECT) = 0)) then Exit(0);

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
      //DebugLn(['TGtkWidgetSet.DrawText Calc single line']);
      CopyRect(theRect, Rect);
      DrawLineRaw(Str, Count, Rect.Top);
      Result := Rect.Bottom - Rect.Top;
      Exit;
    end;

    SetLength(AStr,Count);
    if Count>0 then
      System.Move(Str^,AStr[1],Count);

    if (Flags and DT_EXPANDTABS) <> 0 then
      AStr := StringReplace(AStr, #9, TabString, [rfReplaceAll]);

    if (Flags and DT_NOPREFIX) <> DT_NOPREFIX then
      pIndex := DeleteAmpersands(AStr)
    else
      pIndex := -1;

    GetTextMetrics(DC, TM);
    DoCalcRect;
    Result := theRect.Bottom - theRect.Top;
    if (Flags and DT_CALCRECT) = DT_CALCRECT
    then begin
      //DebugLn(['TGtkWidgetSet.DrawText Complex Calc']);
      CopyRect(Rect, theRect);
      exit;
    end;

    TempDC := SaveDC(DC);

    if (Flags and DT_NOCLIP) <> DT_NOCLIP
    then begin
      if theRect.Right > Rect.Right then
        theRect.Right := Rect.Right;
      if theRect.Bottom > Rect.Bottom then
        theRect.Bottom := Rect.Bottom;
      IntersectClipRect(DC, theRect.Left, theRect.Top,
        theRect.Right, theRect.Bottom);
    end;

    if (Flags and DT_SINGLELINE) = DT_SINGLELINE
    then begin
      //DebugLn(['TGtkWidgetSet.DrawText Draw single line']);
      DrawLine(PChar(AStr), length(AStr), theRect.Top);
      Exit; //we're ready
    end;
    
    // multiple lines
    if Lines = nil then Exit;  // nothing to do
    if NumLines = 0 then Exit; //
    
    
    //DebugLn(['TGtkWidgetSet.DrawText Draw multiline']);
    for i := 0 to NumLines - 1 do
    begin
      if theRect.Top > theRect.Bottom then Break;

      if  ((Flags and DT_EDITCONTROL) = DT_EDITCONTROL)
      and (tm.tmHeight > (theRect.Bottom - theRect.Top))
      then Break;

      if Lines[i] <> nil then begin
        l:=StrLen(Lines[i]);
        DrawLine(Lines[i], l, theRect.Top);
        dec(pIndex,l+length(LineEnding));
      end;
      Inc(theRect.Top, TM.tmDescent + TM.tmHeight);// space between lines
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
function TGtkWidgetSet.EnableScrollBar(Wnd: HWND; wSBflags, wArrows: Cardinal): Boolean;
begin
  //DebugLn('Trace:TODO: [TGtkWidgetSet.EnableScrollBar]');
  //TODO: Implement this;
  Result := False;
end;

{------------------------------------------------------------------------------
  Function: EnableWindow
  Params: hWnd:
          bEnable:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.EnableWindow(hWnd: HWND; bEnable: Boolean): Boolean;
begin
  //DebugLn(Format('Trace:  [TGtkWidgetSet.EnableWindow] hWnd: 0x%x, Enable: %s', [hwnd, BOOL_TEXT[bEnable]]));

  if hWnd <> 0 then
    gtk_widget_set_sensitive(pgtkwidget(hWnd), bEnable);
  Result:=true;
end;

{------------------------------------------------------------------------------
  Function: EndPaint
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.EndPaint(Handle: hwnd; var PS: TPaintStruct): Integer;
var
  Widget: PGtkWidget;
  Info: PWidgetInfo;
{$IFDEF Gtk1}
  DevCtx: TGtkDeviceContext;
  DCDrawable: PGdkDrawable;
  Width, Height: integer;
  CaretWasVisible: Boolean;
  MainWidget: PGtkWidget;
{$ENDIF}
begin
  Result:=1;
  if PS.HDC = 0 then Exit;

  Widget := PGtkWidget(Handle);
  Info:=GetWidgetInfo(Widget,false);
  if Info<>nil then
    dec(Info^.PaintDepth);

  {$IFDEF Gtk1}
  DevCtx := TGtkDeviceContext(PS.HDC);
  if Widget <> DevCtx.Widget then
    RaiseGDBException('Gtk paint event for other than our window');
    
  DCDrawable := DevCtx.Drawable;

  if dcfDoubleBuffer in DevCtx.Flags
  then begin
    // copy
    gdk_window_get_size(DCDrawable, @Width, @Height);
    {$IFDEF VerboseDoubleBuffer}
    DebugLn('TGtkWidgetSet.EndPaint Copying from buffer to window: ',Width,' ',Height);
    {$ENDIF}
    gdk_gc_set_clip_region(DevCtx.GC, nil);
    gdk_gc_set_clip_rectangle(DevCtx.GC, nil);

    // hide caret
    // mwe: note that this call is just a bunch of code to see if widget is our winapiwidget
    HideCaretOfWidgetGroup(Widget, MainWidget, CaretWasVisible);
    // draw
    gdk_window_copy_area(Widget^.Window, DevCtx.GC, 0,0, DCDrawable, 0, 0, Width, Height);

    // restore caret
    if CaretWasVisible then
      GTKAPIWidget_ShowCaret(PGTKAPIWidget(MainWidget));
  end;
  {$ENDIF}
  ReleaseDC(Handle, PS.HDC);
end;

function TGTKWidgetSet.EnumDisplayMonitors(hdc: HDC; lprcClip: PRect;
  lpfnEnum: MonitorEnumProc; dwData: LPARAM): LongBool;
begin
  Result := lpfnEnum(1, 0, nil, dwData);
end;

{.$define VerboseEnumFonts}  
{$IFDEF VerboseGtkToDos}{$note: compare TGtkWidgetSet.EnumFontFamilies with gtkproc.FillScreenFonts}{$ENDIF}
function TGtkWidgetSet.EnumFontFamilies(DC: HDC; Family: Pchar;
  EnumFontFamProc: FontEnumProc; LParam:Lparam):longint;
var
  DevCtx: TGtkDeviceContext absolute DC;

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

function TGtkWidgetSet.EnumFontFamiliesEx(DC: HDC; lpLogFont: PLogFont;
  Callback: FontEnumExProc; Lparam:LParam; Flags: dword): longint;
  
var
  DevCtx: TGtkDeviceContext absolute DC;
  
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

{------------------------------------------------------------------------------
  Method:   Ellipse
  Params:   X1, Y1, X2, Y2
  Returns:  Nothing

  Use Ellipse to draw a filled circle or ellipse.

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.Ellipse(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
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
function TGtkWidgetSet.EqualRgn(Rgn1: HRGN; Rgn2: HRGN): Boolean;
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
function TGtkWidgetSet.ExcludeClipRect(dc: hdc;
  Left, Top, Right, Bottom : Integer) : Integer;
begin
  Result := Inherited ExcludeClipRect(DC, Left, Top, Right, Bottom);
end;

function TGTKWidgetSet.ExtCreatePen(dwPenStyle, dwWidth: DWord;
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

  Result := HPEN(PtrUInt(GObject));
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
function TGtkWidgetSet.ExtSelectClipRGN(dc: hdc; rgn : hrgn;
  Mode : Longint) : Integer;
var
  Clip,
  Tmp : hRGN;
  X, Y : Longint;
  DCOrigin: TPoint;
begin
  Result := SIMPLEREGION;
  If not IsValidDC(DC) then
    Result := ERROR
  else with TGtkDeviceContext(DC) do
  begin
    //DebugLn('TGtkWidgetSet.ExtSelectClipRGN A ClipRegValid=',dbgs(DCClipRegionValid(DC)),
    //  ' Mode=',dbgs(Mode),' RGN=',GDKRegionAsString(PGdiObject(RGN)^.GDIRegionObject));
    If ClipRegion=nil then begin
      // there is no clipping region in the DC
      Case Mode of
        RGN_COPY:
          begin
            Result := RegionType(PGdiObject(RGN)^.GDIRegionObject);
            If Result <> ERROR then
              Result := SelectClipRGN(DC, RGN);
          end;
        RGN_OR,
        RGN_XOR,
        RGN_AND,
        RGN_DIFF:
          begin
            // get existing clip
            GDK_Window_Get_Size(Drawable, @X, @Y);
            DCOrigin:= Offset;
            Clip := CreateRectRGN(-DCOrigin.X,-DCOrigin.Y,X-DCOrigin.X,Y-DCOrigin.Y);
            // create target clip
            Tmp := CreateEmptyRegion;
            // combine
            Result := CombineRGN(Tmp, Clip, RGN, Mode);
            // commit
            //DebugLn('TGtkWidgetSet.ExtSelectClipRGN B ClipRegValid=',dbgs(ClipRegion),' TmpRGN=',GDKRegionAsString(PGdiObject(Tmp)^.GDIRegionObject));
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


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint;
  Rect: PRect; Str: PChar; Count: Longint; Dx: PInteger): Boolean;
{$Ifdef GTK2}
begin
  DebugLn('ToDo: TGtkWidgetSet.ExtTextOut');
  Result:=false;
end;
{$Else}
var
  DevCtx: TGtkDeviceContext absolute DC;

  LineStart, LineEnd, StrEnd: PChar;
  Left, Top, Width, Height: Integer;
  TopY, LineLen, LineHeight : Integer;
  TxtPt : TPoint;
  UseFont : PGDKFont;
  DCOrigin: TPoint;
  UnderLine: boolean;
  buffer: PGdkDrawable;
  buffered: Boolean;

  procedure DrawTextLine;
  var
    UnderLineLen, Y: integer;
    CurDistX: PInteger;
    CharsWritten, CurX, i: integer;
    LinePos: PChar;
    CharLen: LongInt;
  begin
    {$IFDEF DebugGDKTraps}BeginGDKErrorTrap;{$ENDIF}

    if Dx = nil
    then begin
      // no dist array -> write as one block
      gdk_draw_text(Buffer, UseFont, DevCtx.GC, TxtPt.X, TxtPt.Y, LineStart, LineLen);
    end
    else begin
      // dist array -> write each char separately
      CharsWritten := Integer(LineStart-Str);
      if DevCtx.DCTextMetric.IsDoubleByteChar
      then begin
        CharLen := 2;
        CharsWritten := CharsWritten div 2;
      end
      else CharLen := 1;

      CurDistX := Dx+CharsWritten*SizeOf(Integer);
      CurX := TxtPt.X;
      LinePos := LineStart;

      i:=1;
      while i <= LineLen do
      begin
        gdk_draw_text(Buffer, UseFont, DevCtx.GC, CurX, TxtPt.Y, LinePos, CharLen);
        inc(LinePos,CharLen);
        inc(CurX,CurDistX^);
        inc(CurDistX);
        inc(i,CharLen);
      end;
    end;

    if UnderLine
    then begin
      if Rect <> nil
      then
        UnderLineLen := Rect^.Right-Rect^.Left
      else
        UnderLineLen := gdk_text_width(UseFont,LineStart, LineLen);
      Y := TxtPt.Y + 1;
      gdk_draw_line(Buffer, DevCtx.GC, TxtPt.X, Y, TxtPt.X+UnderLineLen, Y);
    end;
    {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
  end;

begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.ExtTextOut] DC:0x%x, X:%d, Y:%d, Options:%d, Str:''%s'', Count: %d', [DC, X, Y, Options, Str, Count]));

  if not IsValidDC(DC) then Exit(False);

  if DevCtx.HasTransf then
  begin
    DevCtx.TransfPoint(X, Y);
    if Rect <> nil then
    begin
      Rect^ := DevCtx.TransfRectIndirect(Rect^);
      DevCtx.TransfNormalize(Rect^.Left, Rect^.Right);
      DevCtx.TransfNormalize(Rect^.Top, Rect^.Bottom);
    end;
  end;

  if ((Options and (ETO_OPAQUE or ETO_CLIPPED)) <> 0)
  and (Rect=nil)
  then begin
    DebugLn('WARNING: [TGtkWidgetSet.ExtTextOut] Rect=nil');
    exit(False);
  end;

  // TODO: implement other parameters.

  // to reduce flickering calculate first and then paint
  DCOrigin := DevCtx.Offset;
  buffered := false;
  UseFont := nil;
  buffer := DevCtx.Drawable;
  UnderLine := false;

  if (Str <> nil) and (Count>0)
  then begin
    Usefont := GetGtkFont(DevCtx);
    if UseFont = nil
    then begin
      DebugLn('WARNING: [TGtkWidgetSet.ExtTextOut] Missing Font');
      Exit(False);
    end;

    if (DevCtx.CurrentFont <> nil) and (DevCtx.CurrentFont^.GDIFontObject <> nil)
    then UnderLine := (DevCtx.CurrentFont^.LogFont.lfUnderline <> 0);

    if (Options and ETO_CLIPPED) <> 0
    then begin
      X := Rect^.Left;
      Y := Rect^.Top;
      IntersectClipRect(DC, Rect^.Left, Rect^.Top, Rect^.Right, Rect^.Bottom);
    end;
  end;
  
  if ((Options and ETO_OPAQUE) <> 0)
  then begin
    Width := Rect^.Right - Rect^.Left;
    Height := Rect^.Bottom - Rect^.Top;
    DevCtx.SelectedColors := dcscCustom;
    EnsureGCColor(DC, dccCurrentBackColor, True, False);

    if buffered
    then begin
      Left:=0;
      Top:=0;
    end
    else begin
      Left:=Rect^.Left+DCOrigin.X;
      Top:=Rect^.Top+DCOrigin.Y;
    end;

    {$IFDEF DebugGDKTraps}BeginGDKErrorTrap;{$ENDIF}
    if IsBackgroundColor(TColor(DevCtx.CurrentBackColor.ColorRef))
    then
      StyleFillRectangle(buffer, DevCtx.GC, DevCtx.CurrentBackColor.ColorRef,
        Left, Top, Width, Height)
    else
      gdk_draw_rectangle(buffer, DevCtx.GC, 1, Left, Top, Width, Height);
    {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
  end;

  if UseFont = nil then Exit(True);

  UpdateDCTextMetric(DevCtx);
  LineHeight := GetTextHeight(DevCtx.DCTextMetric);
  if Buffered
  then begin
    TxtPt.X := 0;
    TxtPt.Y := LineHeight;
  end
  else begin
    TopY := Y;
    TxtPt.X := X + DCOrigin.X;
    TxtPt.Y := TopY + LineHeight + DCOrigin.Y;
  end;

  DevCtx.SelectTextProps;
  LineStart:= Str;
  LineLen := FindChar(#10,Str,Count);
  if LineLen < 0
  then begin
    LineLen:=Count;
    if Count > 0 then DrawTextLine;
    Exit(True);
  end;
  
  //write multiple lines
  StrEnd := Str+Count;
  repeat
    LineEnd := LineStart + LineLen;
    if LineLen > 0 then DrawTextLine;
    inc(TxtPt.Y, LineHeight);
    LineStart := LineEnd + 1; // skip #10
    if (LineStart<StrEnd) and (LineStart^=#13)
    then Inc(LineStart); // skip #13

    Count := StrEnd-LineStart;
    LineLen:=FindChar(#10,LineStart,Count);
    if LineLen < 0
    then LineLen := Count;
  until LineStart >= StrEnd;

  //DebugLn(Format('trace:< [TGtkWidgetSet.ExtTextOut] DC:0x%x, X:%d, Y:%d, Options:%d, Str:''%s'', Count: %d', [DC, X, Y, Options, Str, Count]));
end;
{$EndIf}
{------------------------------------------------------------------------------
  Function: FillRect
  Params: none
  Returns: Nothing

  The FillRect function fills a rectangle by using the specified brush.
  This function includes the left and top borders, but excludes the right and
  bottom borders of the rectangle.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.FillRect(DC: HDC; const Rect: TRect; Brush: HBRUSH): Boolean;
begin
  Result := IsValidDC(DC) and IsValidGDIObject(Brush);
  if not Result or IsRectEmpty(Rect) then
    exit;
  Result := TGtkDeviceContext(DC).FillRect(Rect, Brush, True);
  //DebugLn(Format('trace:< [TGtkWidgetSet.FillRect] DC:0x%x; Rect: ((%d,%d)(%d,%d)); brush: %x', [Integer(DC), Rect.left, rect.top, rect.right, rect.bottom, brush]));
end;

{------------------------------------------------------------------------------
  Function: FillRgn
  Params:  DC: HDC; RegionHnd: HRGN; hbr: HBRUSH
  Returns: True if the function succeeds

  Fills a region by using the specified brush
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.FillRgn(DC: HDC; RegionHnd: HRGN; hbr: HBRUSH): Bool;
var
  GtkDC: Integer;
  OldRgn: PGdkRegion;
  DevCtx: TGtkDeviceContext absolute DC;
  ARect: TRect;
  CRect : TGDKRectangle;
  hasClipping: Boolean;
begin
  //todo: sanity checks for valid handle etc.
  Result := IsValidDC(DC) and IsValidGDIObject(hbr) and IsValidGDIObject(RegionHnd);
  if not Result then Exit;

  GtkDC := SaveDC(DC);
  DevCtx.ClipRegion := PGdiObject(CreateRegionCopy(RegionHnd));
  OldRgn:= DevCtx.ClipRegion^.GDIRegionObject;

  hasClipping := Assigned(OldRgn); //todo: Check a better way
  try
    if hasClipping then
      if SelectClipRGN(DC, RegionHnd) <> ERROR then
      begin
        gdk_region_get_clipbox(PGDIObject(RegionHnd)^.GDIRegionObject, @CRect);
        ARect := RectFromGdkRect(CRect);
        DevCtx.FillRect(ARect, hbr, True);
        if hasClipping then
          SelectClipRGN(DC, HRGN(OldRgn));
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
function TGtkWidgetSet.Frame3d(DC: HDC; var ARect: TRect;
  const FrameWidth: integer; const Style: TBevelCut): boolean;
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
  function TGtkWidgetSet.FrameRect(DC: HDC; const ARect: TRect;
    hBr: HBRUSH): Integer;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.FrameRect(DC: HDC; const ARect: TRect;
  hBr: HBRUSH): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
  DCOrigin: TPoint;
  R: TRect;
begin
  Result:=0;
  if not IsValidDC(DC) then Exit;
  if not IsValidGDIObject(hBr) then Exit;

  // Draw outline
  Result := 1;
  if PGdiObject(hBr)^.IsNullBrush then Exit;

  DevCtx.SelectedColors:= dcscCustom;
  EnsureGCColor(DC, dccGDIBrushColor, True, False);//Brush Color

  if DevCtx.HasTransf then
  begin
    R := DevCtx.TransfRectIndirect(ARect);
    DevCtx.TransfNormalize(R.Left, R.Right);
    DevCtx.TransfNormalize(R.Top, R.Bottom);
  end else
    R := ARect;

  DCOrigin := DevCtx.Offset;
  gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 0,
                     R.Left+DCOrigin.X, R.Top+DCOrigin.Y,
                     R.Right-R.Left-1, R.Bottom-R.Top-1);
end;

{------------------------------------------------------------------------------
  Function: GetActiveWindow
  Params: none
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetActiveWindow : HWND;
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
    if (List^.Data <> nil)
    then begin
      gdk_window_get_user_data(PGDKWindow(List^.Data), Pgpointer(@Window));
      if gtk_is_window(Window)
      then begin
        Widget := Window^.focus_widget;
        if Widget=nil then Widget:=PGtkWidget(Window);
        //DebugLn('TGtkWidgetSet.GetActiveWindow Window=',GetWidgetDebugReport(PgtkWidget(Window)),' Window^.focus_widget= ',GetWidgetDebugReport(Window^.focus_widget));

        if (Widget <> nil) and gtk_widget_has_focus(Widget)
        then begin
          // return the window
          Result := HWND(PtrUInt(GetMainWidget(PGtkWidget(Window))));
          //DebugLn('TGtkWidgetSet.GetActiveWindow Result=',GetWidgetDebugReport(PgtkWidget(Result)));
          Break;
        end;
      end;
    end;
    list := g_list_next(list);
  end;
  if TopList <> nil
  then g_list_free(TopList);
end;

{------------------------------------------------------------------------------
  Function: GetDIBits
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetDIBits(DC: HDC; Bitmap: HBitmap; StartScan, NumScans: UINT;
  Bits: Pointer; var BitInfo: BitmapInfo; Usage: UINT): Integer;
begin
  //DebugLn('trace:[TGtkWidgetSet.GetDIBits]');
  Result := 0;
  if IsValidGDIObject(Bitmap)
  then begin
    case PGDIObject(Bitmap)^.GDIType of
      gdiBitmap:
        Result := InternalGetDIBits(DC, Bitmap, StartScan, NumScans, -1, Bits,
                                      BitInfo, Usage, True);
      else
        DebugLn('WARNING: [TGtkWidgetSet.GetDIBits] not a Bitmap!');
    end;
  end
  else
    DebugLn('WARNING: [TGtkWidgetSet.GetDIBits] invalid Bitmap!');
end;

{------------------------------------------------------------------------------
  Function: GetBitmapBits
  Params:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetBitmapBits(Bitmap: HBITMAP; Count: Longint;  Bits: Pointer): Longint;
var
  BitInfo : tagBitmapInfo;
begin
  //DebugLn('trace:[TGtkWidgetSet.GetBitmapBits]');
  Result := 0;
  if IsValidGDIObject(Bitmap)
  then begin
    case PGDIObject(Bitmap)^.GDIType of
      gdiBitmap:
        Result := InternalGetDIBits(0, Bitmap, 0, 0, Count, Bits, BitInfo, 0, False);
      else
        DebugLn('WARNING: [TGtkWidgetSet.GetBitmapBits] not a Bitmap!');
    end;
  end
  else
    DebugLn('WARNING: [TGtkWidgetSet.GetBitmapBits] invalid Bitmap!');
end;

{------------------------------------------------------------------------------
  Function: GetCapture
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetCapture: HWND;
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
  Result := HWnd(PtrUInt(Widget));
end;

{------------------------------------------------------------------------------
  Function: GetCaretPos
  Params:  lpPoint: The caretposition
  Returns: True if succesful

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetCaretPos(var lpPoint: TPoint): Boolean;
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
  function TGtkWidgetSet.GetCaretRespondToFocus(handle: HWND;
    var ShowHideOnFocus: boolean): Boolean;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetCaretRespondToFocus(handle: HWND;
  var ShowHideOnFocus: boolean): Boolean;
begin
  if handle<>0 then begin
    if gtk_type_is_a(gtk_object_type(PGTKObject(handle)), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_GetCaretRespondToFocus(PGTKAPIWidget(handle),
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
function TGtkWidgetSet.GetCharABCWidths(DC: HDC; p2, p3: UINT;
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
function TGtkWidgetSet.GetClientBounds(handle : HWND; var ARect : TRect) : Boolean;
var
  Widget, ClientWidget: PGtkWidget;
  {$IFDEF Gtk1}
  MainOrigin: TPoint;
  {$ELSE}
  CurGDKWindow: PGdkWindow;
  {$ENDIF}
  ClientOrigin: TPoint;
  ClientWindow, MainWindow: PGdkWindow;
begin
  Result := False;
  if Handle = 0 then Exit;
  Widget := pgtkwidget(Handle);
  ClientWidget := GetFixedWidget(Widget);
  if (ClientWidget <> Widget) then begin
    ClientWindow:=GetControlWindow(ClientWidget);
    MainWindow:=GetControlWindow(Widget);
    if MainWindow<>ClientWindow then begin
      // widget and client are on different gdk windows
      {$IFDEF Gtk1}
      if MainWindow<>nil then begin
        gdk_window_get_origin(MainWindow,@MainOrigin.X,@MainOrigin.Y);
      end else begin
        // widget not realized
        MainOrigin.X:=0;
        MainOrigin.Y:=0;
      end;
      // check if the main gdkwindow is the clientwindow of the parent
      if (Widget^.Parent<>nil)
      and (MainWindow=gtk_widget_get_parent_window(Widget)) then begin
        // the widget is using its parent window
        // -> adjust the coordinates
        inc(MainOrigin.X,Widget^.Allocation.X);
        inc(MainOrigin.Y,Widget^.Allocation.Y);
      end;
      if ClientWindow<>nil then begin
        gdk_window_get_origin(ClientWindow,@ClientOrigin.X,@ClientOrigin.Y);
      end else begin
        // client widget not realized
        ClientOrigin:=MainOrigin;
      end;
      ARect.Left:=ClientOrigin.X-MainOrigin.X;
      ARect.Top:=ClientOrigin.Y-MainOrigin.Y;
      {$ELSE}
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
      while (CurGDKWindow<>MainWindow) do begin
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
      {$ENDIF}
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
function TGtkWidgetSet.GetClientRect(handle : HWND; var ARect : TRect) : Boolean;
var
  Widget, ClientWidget: PGtkWidget;
  
  procedure GetNoteBookClientRect(NBWidget: PGtkNotebook);
  var
    PageIndex: LongInt;
    PageWidget: PGtkWidget;
    FrameBorders: TRect;
    aWidth: LongInt;
    aHeight: LongInt;
  begin
    // get current page
    PageIndex:=gtk_notebook_get_current_page(NBWidget);
    if PageIndex>=0 then
      PageWidget:=gtk_notebook_get_nth_page(NBWidget,PageIndex)
    else
      PageWidget:=nil;
    if (PageWidget<>nil) and GTK_WIDGET_RC_STYLE(PageWidget)
    and ((PageWidget^.Allocation.Width>1) or (PageWidget^.Allocation.Height>1))
    then begin
      // get the size of the current page
      ARect.Right:=PageWidget^.Allocation.Width;
      ARect.Bottom:=PageWidget^.Allocation.Height;
      //DebugLn(['GetNoteBookClientRect using pagewidget: ',GetWidgetDebugReport(Widget),' ARect=',dbgs(aRect)]);
    end else begin
      // use defaults
      FrameBorders:=GetStyleNotebookFrameBorders;
      aWidth:=Widget^.allocation.width;
      aHeight:=Widget^.allocation.height;
      ARect:=Rect(0,0,
         Max(0,AWidth-FrameBorders.Left-FrameBorders.Right),
         Max(0,aHeight-FrameBorders.Top-FrameBorders.Bottom));
      //DebugLn(['GetNoteBookClientRect using defaults: ',GetWidgetDebugReport(Widget),' ARect=',dbgs(aRect)]);
    end;
  end;

begin
  Result := false;
  if Handle = 0 then Exit;
  ARect.Left := 0;
  ARect.Top := 0;
  Widget := PGtkWidget(Handle);
  ClientWidget := GetFixedWidget(Widget);
  if (ClientWidget <> nil) then
    Widget := ClientWidget;
  if (Widget <> nil) then begin
    ARect.Right:=Widget^.Allocation.Width;
    ARect.Bottom:=Widget^.Allocation.Height;
    if GtkWidgetIsA(Widget,gtk_notebook_get_type) then
      GetNoteBookClientRect(PGtkNoteBook(Widget));
  end else begin
    ARect.Right:=0;
    ARect.Bottom:=0;
  end;
  {$IfDef VerboseGetClientRect}
  if ClientWidget<>nil then begin
    DebugLn('GetClientRect  Widget=',GetWidgetDebugReport(PgtkWidget(Handle)),
       ' Client=',DbgS(ClientWidget),WidgetFlagsToString(ClientWidget),
       ' WindowSize=',dbgs(ARect.Right),',',dbgs(ARect.Bottom),
       ' Allocation=',dbgs(ClientWidget^.Allocation.Width),',',dbgs(ClientWidget^.Allocation.Height)
       );
  end else begin
    DebugLn('GetClientRect  Widget=',GetWidgetDebugReport(PgtkWidget(Handle)),
       ' Client=',DbgS(ClientWidget),WidgetFlagsToString(ClientWidget),
       ' WindowSize=',dbgs(ARect.Right),',',dbgs(ARect.Bottom),
       ' Allocation=',dbgs(Widget^.Allocation.Width),',',dbgs(Widget^.Allocation.Height)
       );
  end;
  if GetLCLObject(Widget) is TCustomPage then begin
    DebugLn(['TGtkWidgetSet.GetClientRect Rect=',dbgs(aRect),' ',GetWidgetDebugReport(Widget)]);
  end;
  {$EndIf}
  Result:=true;
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
function TGtkWidgetSet.GetClipBox(DC : hDC; lpRect : PRect) : Longint;
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
  if DevCtx.ClipRegion = nil
  then begin
    if (DevCtx.PaintRectangle.Left<>0)
    or (DevCtx.PaintRectangle.Top<>0)
    or (DevCtx.PaintRectangle.Right<>0)
    or (DevCtx.PaintRectangle.Bottom<>0) then begin
      lpRect^:=DevCtx.PaintRectangle;
    end else begin
      gdk_window_get_size(DevCtx.Drawable, @X, @Y);
      lpRect^ := Rect(0,0,X,Y);
    end;
    OffsetRect(lpRect^,-DCOrigin.X, -DCOrigin.Y);
    Result := SIMPLEREGION;
  end
  else begin
    Result := RegionType(DevCtx.ClipRegion^.GDIRegionObject);
    gdk_region_get_clipbox(DevCtx.ClipRegion^.GDIRegionObject, @CRect);
    lpRect^.Left   := CRect.X-DCOrigin.X;
    lpRect^.Top    := CRect.Y-DCOrigin.Y;
    lpRect^.Right  := lpRect^.Left + CRect.Width;
    lpRect^.Bottom := lpRect^.Top + CRect.Height;
  end;
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
function TGtkWidgetSet.GetRgnBox(RGN : HRGN; lpRect : PRect) : Longint;
var
  CRect : TGDKRectangle;
begin
  Result := SIMPLEREGION;
  If lpRect <> nil then
    lpRect^ := Rect(0,0,0,0);
  If Not IsValidGDIObject(RGN) then
    Result := ERROR
  else begin
    Result := RegionType(PGDIObject(RGN)^.GDIRegionObject);
    If lpRect <> nil then begin
      gdk_region_get_clipbox(PGDIObject(RGN)^.GDIRegionObject,
        @CRect);
      With lpRect^ do begin
        Left   := CRect.X;
        Top    := CRect.Y;
        Right  := CRect.X + CRect.Width;
        Bottom := CRect.Y + CRect.Height;
      end;
    end;
  end;
end;

function TGtkWidgetSet.GetROP2(DC: HDC): Integer;
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
function TGtkWidgetSet.GetClipRGN(DC : hDC; RGN : hRGN) : longint;
var
  DCOrigin: TPoint;
  ClipRegionWithDCOffset: PGdkRegion;
  CurRegionObject: PGdkRegion;
  ARect: TRect;
begin
  Result := SIMPLEREGION;
  If (not IsValidDC(DC)) then
    Result := ERROR
  else If Not IsValidGDIObject(RGN) then begin
    Result := ERROR;
    DebugLn('WARNING: [TGtkWidgetSet.GetClipRGN] Invalid HRGN');
  end
  else if (TGtkDeviceContext(DC).ClipRegion<>nil)
  and (not IsValidGDIObject(HGDIOBJ(PtrUInt(TGtkDeviceContext(DC).ClipRegion)))) then
    Result := ERROR
  else with TGtkDeviceContext(DC) do
  begin
    CurRegionObject:=nil;
    if ClipRegion<>nil then
      CurRegionObject:=ClipRegion^.GDIRegionObject;
    ARect:=Rect(0,0,0,0);
    if CurRegionObject<>nil then begin
      // create a copy of the current clipregion
      ClipRegionWithDCOffset:=gdk_region_copy(CurRegionObject);
      // move it to the DC offset
      // Example: if the ClipRegion is at 10,10 and the DCOrigin is at 10,10,
      //          then the ClipRegion must be moved to 0,0
      DCOrigin := Offset;
      //debugln('TGtkWidgetSet.GetClipRGN DCOrigin=',dbgs(DCOrigin),' CurRegionObject=',dbgs(CurRegionObject),' ',dbgs(ARect));
      gdk_region_offset(ClipRegionWithDCOffset,-DCOrigin.x,-DCOrigin.Y);
    end else begin
      // create a default clipregion
      GetClipBox(DC,@ARect);
      ClipRegionWithDCOffset:=CreateRectGDKRegion(ARect);
    end;
    // free the old region in RGN
    if PGdiObject(RGN)^.GDIRegionObject<>nil then
      gdk_region_destroy(PGdiObject(RGN)^.GDIRegionObject);
    // set the new region in RGN
    PGdiObject(RGN)^.GDIRegionObject := ClipRegionWithDCOffset;

    Result := RegionType(ClipRegionWithDCOffset);
    //DebugLn('TGtkWidgetSet.GetClipRGN B DC=',DbgS(DC),
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
function TGtkWidgetSet.GetCmdLineParamDescForInterface: string;
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
    +b(rsgtkOptionClass);
end;

{------------------------------------------------------------------------------
  Function: GetCursorPos
  Params:  lpPoint: The cursorposition
  Returns: True if succesful

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetCursorPos(var lpPoint: TPoint): Boolean;
{$IFDEF HasX}
var
  dpy: PDisplay;
  root, child: twindow;
  winx, winy: Integer;
  xmask: Cardinal;
begin
  Result := true;
  if (not MousePositionValid) or (Abs(MousePositionTime-Now)>1/864000) then
  begin
    // querying the X cursor is expensive (especially on network connections)
    // => use a lazy query
    {$IFDEF DebugGDKTraps}
    BeginGDKErrorTrap;
    try
    {$ENDIF}
      dpy := gdk_display;
      XQueryPointer(dpy, RootWindow(dpy, DefaultScreen(dpy)), @root, @child,
                          @MousePosition.X,@MousePosition.Y,@winx,@winy,@xmask);
    {$IFDEF DebugGDKTraps}
    finally
      EndGDKErrorTrap;
    end;
    {$ENDIF}
    MousePositionTime:=Now;
    MousePositionValid:=true;
  end;
  lpPoint:=MousePosition;
end;
{$ELSE}
begin
  // TODO: GTK1-win32 GetCursorPos
  Result := False;
end;
{$ENDIF HasX}

function TGTKWidgetSet.GetCurrentObject(DC: HDC; uObjectType: UINT): HGDIOBJ;
var
  GtkDC: TGtkDeviceContext absolute DC;
begin
  Result := 0;
  if not GTKWidgetSet.IsValidDC(DC) then
    Exit;
  case uObjectType of
    OBJ_BITMAP: Result := HGDIOBJ(GtkDC.CurrentBitmap);
    OBJ_BRUSH: Result := HGDIOBJ(GtkDC.CurrentBrush);
    OBJ_FONT: Result := HGDIOBJ(GtkDC.CurrentFont);
    OBJ_PEN: Result := HGDIOBJ(GtkDC.CurrentPen);
  end;
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
function TGtkWidgetSet.GetDC(hWnd: HWND): HDC;
begin
  Result:=CreateDCForWidget(PGtkWidget(hWnd),nil,false);
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetDeviceCaps(DC: HDC; Index: Integer): Integer;
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
    Result := RoundToInt(gdk_screen_width / (GetScreenWidthMM / 25.4));

  LOGPIXELSY : { Logical pixels per inch in Y }
    Result := RoundToInt(gdk_screen_height / (GetScreenHeightMM / 25.4));

  SIZEPALETTE: { number of entries in color palette }
    if GetVisual then
      Result:=Visual^.colormap_size
    else
      Result:=0;

  NUMRESERVED: { number of reserverd colors in color palette }
    Result:=0;

  else
    DebugLn('TGtkWidgetSet.GetDeviceCaps not supported: Type=',dbgs(Index));
  end;
end;

{------------------------------------------------------------------------------
  function GetDeviceSize(DC: HDC; var p: TPoint): boolean;

  Retrieves the width and height of the device context in pixels.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetDeviceSize(DC: HDC; var p: TPoint): boolean;
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
  
  {$ifdef gtk1}
  if DevCtx.Widget = nil
  then begin
    // either empty or gtk1screen
    p.x:=gdk_screen_width;
    p.y:=gdk_screen_height;
    Exit(True);
  end;
  {$endif}

  {$IFDEF RaiseExceptionOnNilPointers}
  RaiseException('TGtkWidgetSet.GetDeviceSize Window=nil');
  {$ENDIF}
  DebugLn('TGtkWidgetSet.GetDeviceSize:', ' WARNING: DC ',DbgS(DC),' without gdkwindow.',
          ' Widget=',DbgS(DevCtx.Widget));
  Result := False;
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
    WindowHandle: HWND; var OriginDiff: TPoint): boolean;

  Returns the origin of PaintDC relative to the window handle.
  Example:
    A PaintDC of a TButton at 20,10 with a DC Offset of 0,0 on a form and the
    WindowHandle is the form.
    Then OriginDiff is the difference between the Forms client origin
    and the PaintDC: 20,10.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetDCOriginRelativeToWindow(PaintDC: HDC;
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
  OriginDiff := Point(0,0);
  if not IsValidDC(PaintDC) then exit;
  
  DCOrigin := DevCtx.Offset;

  DCWindow:=PGdkWindow(DevCtx.Drawable);
  gdk_window_get_origin(DCWindow, @(DCScreenOrigin.X), @(DCScreenOrigin.Y));
  inc(DCScreenOrigin.X, DCOrigin.X);
  inc(DCScreenOrigin.Y, DCOrigin.Y);

  Widget := GetFixedWidget(PGtkWidget(WindowHandle));
  if Widget = nil
  then Widget := PGtkWidget(WindowHandle);
  
  gdk_window_get_origin(PGdkWindow(Widget^.window), @(WindowScreenOrigin.X), @(WindowScreenOrigin.Y));

  OriginDiff.X := DCScreenOrigin.X-WindowScreenOrigin.X;
  OriginDiff.Y := DCScreenOrigin.Y-WindowScreenOrigin.Y;
  Result := true;
  //DebugLn(['TGtkWidgetSet.GetDCOriginRelativeToWindow DCScreenOrigin=',dbgs(DCScreenOrigin),' WindowScreenOrigin=',dbgs(WindowScreenOrigin),' OriginDiff=',dbgs(OriginDiff)]);
end;

{------------------------------------------------------------------------------
  Function: GetDesignerDC
  Params:  none
  Returns: Nothing

  WindowHandle is any widget.
  The DC will be created for the client area including the child areas.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetDesignerDC(WindowHandle: HWND): HDC;
begin
  //DebugLn('TGtkWidgetSet.GetDesignerDC A');
  Result:=CreateDCForWidget(PGtkWidget(WindowHandle),nil,true);
end;

{------------------------------------------------------------------------------
  Function: GetFocus
  Params:  none
  Returns: The handle of the window with focus

  The GetFocus function retrieves the handle of the window that has the focus.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetFocus: HWND;
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
          DebugLn(['TGtkWidgetSet.GetFocus Window^.focus_widget was already destroyed:']);
          DebugLn(DebugGtkWidgets.GetInfo(Widget,true));
        end;
        {$ENDIF}
        
        if (Widget <> nil) and gtk_widget_has_focus(Widget)
        then begin
          Info:=GetWidgetInfo(PGtkWidget(Window),false);
          if (Info=nil) or (not (wwiDeactivating in Info^.Flags)) then
            Result := HWND(PtrUInt(GetMainWidget(Widget)));
          Break;
        end;
      end;
    end;
    list := g_list_next(list);
  end;

  if TopList <> nil
  then g_list_free(TopList);

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
end;

{------------------------------------------------------------------------------
  function GetFontLanguageInfo(DC: HDC): DWord; override;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetFontLanguageInfo(DC: HDC): DWord;
var
  DevCtx: TGtkDeviceContext absolute DC;
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
function TGtkWidgetSet.GetKeyState(nVirtKey: Integer): Smallint;
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
{$IFDEF GTK1}
  List: PGList;
{$ENDIF}
begin
  case nVirtKey of
    // remap
    VK_LSHIFT:   nVirtKey := VK_SHIFT;
    VK_LCONTROL: nVirtKey := VK_CONTROL;
    VK_LMENU:    nVirtKey := VK_MENU;
  end;
  
  {$IFDEF Use_KeyStateList}
  Result := KEYSTATE[FKeyStateList_.IndexOf(Pointer(PtrInt(nVirtKey))) >=0];
  {$ELSE}
  Implement this
  {$ENDIF}

  // try extended keys
  if Result = 0
  then begin
    {$IFDEF Use_KeyStateList}
    Result := KEYSTATE[FKeyStateList_.IndexOf(Pointer(PtrInt(nVirtKey or KEYMAP_EXTENDED))) >=0];
    {$ELSE}
    Implement this
    {$ENDIF}
  end;

  {$IFDEF Use_KeyStateList}
  // add toggle
  Result := Result or TOGGLESTATE[FKeyStateList_.IndexOf(Pointer(
                                  PtrInt(nVirtKey or KEYMAP_TOGGLE))) >=0];
  {$IFDEF GTK2}
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
  {$ENDIF}

  // Mouse buttons. Toggle state is not tracked
  if nVirtKey in [VK_LBUTTON, VK_RBUTTON, VK_MBUTTON..VK_XBUTTON2] then
  begin
    {$ifdef gtk1}
    List := gdk_window_get_toplevels;
    if g_list_length(List) > 0 then
      gdk_window_get_pointer(g_list_nth_data(List, 0), @x, @y, @GdkModMask)
    else
      GdkModMask := 0;
    g_list_free(List);
    {$else}
    gdk_display_get_pointer(gdk_display_get_default, nil,
      @x, @y, @GdkModMask);
    {$endif}
    Result := Result or KEYSTATE[GdkModMask and GDK_BUTTON_MASKS[nVirtKey] <> 0]
  end;

  //DebugLn(Format('Trace:[TGtkWidgetSet.GetKeyState] %d -> 0x%x', [nVirtKey, Result]));
end;

function TGtkWidgetSet.GetMapMode(DC: HDC): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if IsValidDC(DC) then
    Result := DevCtx.MapMode
  else
    Result := 0;
end;

function TGTKWidgetSet.GetMonitorInfo(Monitor: HMONITOR; lpmi: PMonitorInfo): Boolean;
{$IFDEF HasX}
var
  x, y, w, h: gint;
{$ENDIF}
begin
  Result := (lpmi <> nil) and (lpmi^.cbSize >= SizeOf(TMonitorInfo)) and (Monitor = 1);
  if not Result then Exit;
  lpmi^.rcMonitor := Bounds(0, 0, gdk_screen_width, gdk_screen_height);
  {$IFDEF HasX}
  if XGetWorkarea(x, y, w, h) <> -1 then
    lpmi^.rcWork := Bounds(x, y, w, h)
  else
  {$ENDIF}
  lpmi^.rcWork := lpmi^.rcMonitor;
  lpmi^.dwFlags := MONITORINFOF_PRIMARY
end;

{------------------------------------------------------------------------------
  Function: GetObject
  Params:  GDIObj - handle, BufSize - size of Buf argument, Buf - buffer
  Returns: Size of buffer
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetObject(GDIObj: HGDIOBJ; BufSize: Integer; Buf: Pointer): Integer;
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

    FillChar(BitmapSection, SizeOf(TDIBSECTION), 0);
    with PGDIObject(GDIObj)^, BitmapSection,
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
            {$ifdef gtk1}
            gdk_window_get_geometry(GDIPixmapObject.Image, nil, nil, @biWidth, @biHeight, @ImageDepth);
            {$else}
            gdk_drawable_get_size(GDIPixmapObject.Image, @biWidth, @biHeight);
            ImageDepth := gdk_drawable_get_depth(GDIPixmapObject.Image);
            {$endif}
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
  i, RequiredSize: Integer;
begin
  //DebugLn('trace:[TGtkWidgetSet.GetObject]');
  Result := 0;
  if not IsValidGDIObject(GDIObj) then Exit;
  
  case GDIObject^.GDIType of
    gdiBitmap:
      Result := GetObject_Bitmap;
    gdiBrush:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetObject] gdiBrush');
      end;
    gdiFont:
      begin
        if Buf = nil
        then begin
          Result := SizeOf(GDIObject^.LogFont);
          Exit;
        end;
        if BufSize >= SizeOf(GDIObject^.LogFont)
        then begin
          PLogfont(Buf)^ := GDIObject^.LogFont;
          Result:= SizeOf(TLogFont);
        end
        else if BufSize > 0
        then begin
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
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetObject] gdiRegion');
      end;
  else
    DebugLn('WARNING: [TGtkWidgetSet.GetObject] Unknown type %d', [Integer(GDIObject^.GDIType)]);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetParent
  Params: Handle:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetParent(Handle : HWND): HWND;
begin
  if Handle <> 0 then
    Result := HWnd(PGtkWidget(Handle)^.Parent)
  else
    Result := 0;
end;


{------------------------------------------------------------------------------
  Function: GetProp
  Params: Handle: Str
  Returns: Pointer

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetProp(Handle : hwnd; Str : PChar): Pointer;
Begin
  Result := gtk_object_get_data(pgtkobject(Handle),Str);
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;

  Returns the current width of the scrollbar of the widget.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetScrollBarSize(Handle: HWND; BarKind: Integer): integer;
var
  Widget, ScrollWidget, BarWidget: PGtkWidget;
begin
  Result:=0;
  Widget:=PGtkWidget(Handle);
  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLED_WINDOW) then begin
    ScrollWidget:=Widget;
  end else begin
    ScrollWidget:=PGtkWidget(gtk_object_get_data(
                                             PGtkObject(Widget),odnScrollArea));
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
  function TGtkWidgetSet.GetScrollbarVisible(Handle: HWND;
    SBStyle: Integer): boolean;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetScrollbarVisible(Handle: HWND; SBStyle: Integer): boolean;
var
  Widget, ScrollWidget, BarWidget: PGtkWidget;
begin
  Result:=false;
  if Handle=0 then exit;
  Widget:=PGtkWidget(Handle);
  if GtkWidgetIsA(Widget,GTK_TYPE_SCROLLED_WINDOW) then begin
    ScrollWidget:=Widget;
  end else begin
    ScrollWidget:=PGtkWidget(gtk_object_get_data(
                                             PGtkObject(Widget),odnScrollArea));
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
function TGtkWidgetSet.GetScrollInfo(Handle: HWND; SBStyle: Integer;
  var ScrollInfo: TScrollInfo): Boolean;
var
  Adjustment: PGtkAdjustment;
  Scroll : PGTKWidget;
  IsScrollWindow: Boolean;
begin
  Result := false;
  if (Handle = 0) then exit;


  Scroll := gtk_object_get_data(PGTKObject(Handle), odnScrollArea);
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := PGTKWidget(Handle);
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
function TGtkWidgetSet.GetStockObject(Value: Integer): THandle;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.GetStockObject] %d', [Value]));
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
          FStockSystemFont := HFont(PtrUInt(CreateDefaultFont));
        Result := FStockSystemFont;
      end;
(*    SYSTEM_FIXED_FONT:   // Fixed-pitch (monospace) system font used in Windows versions earlier than 3.0. This stock object is provided for compatibility with earlier versions of Windows.
      begin
        Result := GetStockObject(ANSI_FIXED_FONT);
      end;
    DEFAULT_PALETTE:     // Default palette. This palette consists of the static colors in the system palette.
      begin
      end;
*)  else
    //DebugLn(Format('Trace:TODO: [TGtkWidgetSet.GetStockObject] Implement value: %d', [Value]));
  end;
  //DebugLn(Format('Trace:< [TGtkWidgetSet.GetStockObject] %d --> 0x%x', [Value, Result]));
end;

{------------------------------------------------------------------------------
  Function: GetSysColor
  Params:   index to the syscolors array
  Returns:  RGB value

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetSysColor(nIndex: Integer): DWORD;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS)
  then begin
    Result := 0;
    DumpStack;
    DebugLn(Format('ERROR: [TGtkWidgetSet.GetSysColor] Bad Value: %d. Valid Range between 0 and %d', [nIndex, MAX_SYS_COLORS]));
  end
  else
    Result := SysColorMap[nIndex];
end;

function TGTKWidgetSet.GetSysColorBrush(nIndex: Integer): HBrush;
begin
  if (nIndex < 0) or (nIndex > MAX_SYS_COLORS)
  then begin
    Result := 0;
    DumpStack;
    DebugLn(Format('ERROR: [TGtkWidgetSet.GetSysColorBrush] Bad Value: %d. Valid Range between 0 and %d', [nIndex, MAX_SYS_COLORS]));
  end
  else
    Result := FSysColorBrushes[nIndex];
end;

{------------------------------------------------------------------------------
  Function: GetSystemMetrics
  Params:
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetSystemMetrics(nIndex: Integer): Integer;
var
  P: Pointer;
{$ifdef HasX}
  ax,ay,ah,aw: gint;
{$endif}
  auw, auh: guint;
 {$ifdef GTK2}
  screen: PGdkScreen;
  ARect: TGdkRectangle;
  AValue: TGValue;
 {$else}
 {$ifdef HasX}
   XDisplay: PDisplay;
   XScreen: PScreen;
   XWindow: TWindow;
 {$endif}
 {$endif}
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.GetSystemMetrics] %d', [nIndex]));
  Result := 0;
  case nIndex of
    SM_ARRANGE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_ARRANGE          ');
      end;
    SM_CLEANBOOT:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CLEANBOOT        ');
      end;
    SM_CMOUSEBUTTONS:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CMOUSEBUTTONS    ');
      end;
    SM_CXBORDER:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXBORDER         ');
      end;
    SM_CYBORDER:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYBORDER         ');
      end;
    SM_CXCURSOR,
    SM_CYCURSOR:
      begin
      {$IFDEF GTK2}
        // Width and height of a cursor, in pixels. For win32 system cannot create cursors of other sizes.
        // For gtk this should be maximal cursor sizes
        gdk_display_get_maximal_cursor_size(gdk_display_get_default, @auw, @auh);
      {$ELSE}
        {$IFDEF HasX}
          // same code used in gtk2 library
          XDisplay := gdk_display;
          XScreen := XDefaultScreenOfDisplay(XDisplay);
          XWindow := XRootWindowOfScreen(XScreen);
          XQueryBestCursor(XDisplay, XWindow, 128, 128, @auw, @auh);
        {$ELSE}
          Result := 32; // Default windows size
        {$ENDIF}
      {$ENDIF}
        if nIndex = SM_CXCURSOR
        then Result := auw // return width
        else Result := auh; // return height
      end;
    SM_CXDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXDOUBLECLK      ');
      end;
    SM_CYDOUBLECLK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYDOUBLECLK      ');
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
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXFIXEDFRAME     ');
      end;
    SM_CYFIXEDFRAME:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYFIXEDFRAME     ');
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
      {$ifdef gtk1}
        _gtk_range_get_props(P, nil, nil, @Result, nil);
      {$else}
          FillChar(AValue, SizeOf(AValue), 0);
          g_value_init(@AValue, G_TYPE_INT);
          gtk_widget_style_get_property(P, 'slider-width', @AValue);
          Result := AValue.data[0].v_int;
      {$endif}
        end;
      end;
    SM_CXICON,
    SM_CYICON:
      Result := 32;
    SM_CXICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXICONSPACING    ');
      end;
    SM_CYICONSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYICONSPACING    ');
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
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMAXTRACK       ');
      end;
    SM_CYMAXTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMAXTRACK       ');
      end;
    SM_CXMENUCHECK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMENUCHECK      ');
      end;
    SM_CYMENUCHECK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMENUCHECK      ');
      end;
    SM_CXMENUSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMENUSIZE       ');
      end;
    SM_CYMENUSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMENUSIZE       ');
      end;
    SM_CXMIN:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMIN            ');
      end;
    SM_CYMIN:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMIN            ');
      end;
    SM_CXMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMINIMIZED      ');
      end;
    SM_CYMINIMIZED:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMINIMIZED      ');
      end;
    SM_CXMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMINSPACING     ');
      end;
    SM_CYMINSPACING:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMINSPACING     ');
      end;
    SM_CXMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXMINTRACK       ');
      end;
    SM_CYMINTRACK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMINTRACK       ');
      end;
    SM_CXFULLSCREEN,
    SM_CXSCREEN:
      begin
        { Partial fix for multi monitor systems - force use of first one }
        {$ifdef UseXinerama}
        if GetFirstScreen then
          result := FirstScreen.x
        else
        {$endif}
          result := gdk_Screen_Width;
      end;
    SM_CXVIRTUALSCREEN:
      begin
        Result := gdk_Screen_Width;
      end;
    SM_CYFULLSCREEN,
    SM_CYSCREEN:
      begin
        {$ifdef UseXinerama}
        if GetFirstScreen then
          result := FirstScreen.y
        else
        {$endif}
        result := gdk_Screen_Height;
      end;
    SM_CYVIRTUALSCREEN:
      begin
        result := gdk_Screen_Height;
      end;
    SM_CXSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXSIZE           ');
      end;
    SM_CYSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYSIZE           ');
      end;
    SM_CXSIZEFRAME,
    SM_CYSIZEFRAME:
      begin
        Result := 4;
      end;
    SM_CXSMICON,
    SM_CYSMICON:
      Result := 16;
    SM_CXSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CXSMSIZE         ');
      end;
    SM_CYSMSIZE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYSMSIZE         ');
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
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYCAPTION        ');
      end;
    SM_CYKANJIWINDOW:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYKANJIWINDOW    ');
      end;
    SM_CYMENU:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYMENU           ');
      end;
    SM_CYSMCAPTION:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_CYSMCAPTION      ');
      end;
    SM_DBCSENABLED:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_DBCSENABLED      ');
      end;
    SM_DEBUG:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_DEBUG            ');
      end;
    SM_MENUDROPALIGNMENT:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_MENUDROPALIGNMENT');
      end;
    SM_MIDEASTENABLED:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_MIDEASTENABLED   ');
      end;
    SM_MOUSEPRESENT:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_MOUSEPRESENT     ');
      end;
    SM_MOUSEWHEELPRESENT:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_MOUSEWHEELPRESENT');
      end;
    SM_NETWORK:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_NETWORK          ');
      end;
    SM_PENWINDOWS:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_PENWINDOWS       ');
      end;
    SM_SECURE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_SECURE           ');
      end;
    SM_SHOWSOUNDS:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_SHOWSOUNDS       ');
      end;
    SM_SLOWMACHINE:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_SLOWMACHINE      ');
      end;
    SM_SWAPBUTTON:
      begin
        //DebugLn('Trace:TODO: [TGtkWidgetSet.GetSystemMetrics] --> SM_SWAPBUTTON       ');
      end;
    SM_SWSCROLLBARSPACING:
      begin
        P := GetStyleWidget(lgsScrolledWindow);
        if P <> nil then begin
          {$IFDEF GTK2}
          result := GTK_SCROLLED_WINDOW_CLASS(gtk_widget_get_class(P))^.scrollbar_spacing;
          if result<0 then
            gtk_widget_style_get(P, 'scrollbar-spacing', @result, nil);
          {$ELSE}
          result := PGtkScrolledWindowClass(PGtkTypeObject(P)^.klass)^.scrollbar_spacing;
          if result<0 then
            result := 3;
          {$ENDIF}
        end;
      end;
  end;
  //DebugLn(Format('Trace:< [TGtkWidgetSet.GetSystemMetrics] %d --> 0x%x (%d)', [nIndex, Result, Result]));
end;

{------------------------------------------------------------------------------
  Function: GetTextColor
  Params:  DC
  Returns: TColorRef

  Gets the Font Color currently assigned to the Device Context
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetTextColor(DC: HDC) : TColorRef;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := 0;
  if IsValidDC(DC) then
    with TGtkDeviceContext(DC) do
    begin
      Result := CurrentTextColor.ColorRef;
    end;
end;

{------------------------------------------------------------------------------
  Function: GetTextExtentPoint
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetTextExtentPoint(DC: HDC; Str: PChar; Count: Integer;
  var Size: TSize): Boolean;
{$IfDef GTK2}
begin
  DebugLn('TGtkWidgetSet.GetTextExtentPoint ToDo');
  Result:=false;
end;
{$Else}
var
  DevCtx: TGtkDeviceContext absolute DC;

  lbearing, rbearing, width, ascent,descent: LongInt;
  UseFont : PGDKFont;
  IsDBCSFont: Boolean;
  NewCount: Integer;
begin
  Result := IsValidDC(DC);
  if Result
  then with TGtkDeviceContext(DC) do
  begin
    UseFont:=GetGtkFont(TGtkDeviceContext(DC));
    descent:=0;
    UpdateDCTextMetric(TGtkDeviceContext(DC));
    IsDBCSFont:=TGtkDeviceContext(DC).DCTextMetric.IsDoubleByteChar;
    if IsDBCSFont then begin
      NewCount:=Count*2;
      if FExtUTF8OutCacheSize<NewCount then begin
        ReAllocMem(FExtUTF8OutCache,NewCount);
        FExtUTF8OutCacheSize:=NewCount;
      end;
      NewCount:=UTF8ToDoubleByte(Str,Count,FExtUTF8OutCache)*2;
      gdk_text_extents(UseFont, FExtUTF8OutCache, NewCount,
                       @lbearing, @rBearing, @width, @ascent, @descent);
    end else begin
      gdk_text_extents(UseFont, Str, Count,
                       @lbearing, @rBearing, @width, @ascent, @descent);
    end;
    Size.cX := Width;
    // I THINK this is accurate...
    Size.cY :={$IFDEF Win32}
              GDK_String_Height(UseFont, Str)
              {$ELSE}
              ascent+descent;
              {$ENDIF}
    //debugln('TGtkWidgetSet.GetTextExtentPoint END Str="'+DbgStr(Str)+'" Size=',dbgs(Size.cX),'x',dbgs(Size.cY),' ascent=',dbgs(ascent),' descent=',dbgs(descent),' tmDescent=',dbgs(TGtkDeviceContext(DC).DCTextMetric.TextMetric.tmDescent));

    if DevCtx.HasTransf then
    begin
      DevCtx.InvTransfExtent(Size.cx, Size.cy);
      Size.cx := Abs(Size.cx);
      Size.cy := Abs(Size.cy);
    end;

  end;
  //DebugLn('trace:< [TGtkWidgetSet.GetTextExtentPoint]');

end;
{$EndIf}

{------------------------------------------------------------------------------
  Function: GetTextMetrics
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetTextMetrics(DC: HDC; var TM: TTextMetric): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn(Format('Trace:> TODO FINISH[TGtkWidgetSet.GetTextMetrics] DC: 0x%x', [DC]));

  Result := IsValidDC(DC);
  if Result then
  begin
    UpdateDCTextMetric(DevCtx);
    TM := DevCtx.DCTextMetric.TextMetric;
  end;

  //DebugLn(Format('Trace:< TODO FINISH[TGtkWidgetSet.GetTextMetrics] DC: 0x%x', [DC]));
end;

function TGtkWidgetSet.GetViewPortExtEx(DC: HDC; Size: PSize): Integer;
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

function TGtkWidgetSet.GetViewPortOrgEx(DC: HDC; P: PPoint): Integer;
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

function TGtkWidgetSet.GetWindowExtEx(DC: HDC; Size: PSize): Integer;
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
function TGtkWidgetSet.GetWindowLong(Handle: HWND; int: Integer): PtrInt;

  function GetObjectData(Name: PChar): PtrInt;
  begin
    Result := PtrInt(PtrUInt(gtk_object_get_data(pgtkobject(Handle),Name)));
  end;
var
  WidgetInfo: PWidgetInfo;
begin
  //TODO:Started but not finished
  //DebugLn(Format('Trace:> [TGtkWidgetSet.GETWINDOWLONG] HWND: 0x%x, int: 0x%x (%d)', [Handle, int, int]));

  case int of
    GWL_WNDPROC :
      begin
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
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
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
        if WidgetInfo <> nil then
          Result := WidgetInfo^.Style
        else
          Result := 0;
      end;
    GWL_EXSTYLE :
      begin
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
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

  //DebugLn(Format('Trace:< [TGtkWidgetSet.GETWINDOWLONG] HWND: 0x%x, int: 0x%x (%d) --> 0x%x (%d)', [Handle, int, int, Result, Result]));
end;

{------------------------------------------------------------------------------
  Function: GetWindowOrgEx
  Params:  none
  Returns: Nothing

  Returns the current offset of the DC.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetWindowOrgEx(dc : hdc; P : PPoint): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if P = nil then Exit(0);
  P^ := Point(0,0);
  if not IsValidDC(DC) then exit(0);
  
  P^ := DevCtx.Offset;
  Result:=1;
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
function TGtkWidgetSet.GetWindowRect(Handle: hwnd; var ARect: TRect): Integer;
var
  Widget: PGTKWidget;
begin
  //DebugLn('GetWindowRect');
  Result := 0; //default
  if Handle <> 0 then
  begin
    Widget := PGtkWidget(Handle);
    ARect.TopLeft := GetWidgetOrigin(Widget);
    ARect.BottomRight := Point(ARect.Left + Widget^.allocation.width,
                               ARect.Top + Widget^.allocation.height);
  end;
end;

{------------------------------------------------------------------------------
  Function: GetWindowRelativePosition
  Params:  Handle : hwnd;
  Returns: true on success

  Returns the Left, Top, relative to the client origin of its parent
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GetWindowRelativePosition(Handle : hwnd;
  var Left, Top: integer): boolean;
var
  aWidget: PGtkWidget;
begin
  aWidget := PGtkWidget(Handle);
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
function TGtkWidgetSet.GetWindowSize(Handle : hwnd;
  var Width, Height: integer): boolean;
begin
  if GtkWidgetIsA(PGtkWidget(Handle),GTK_TYPE_WIDGET) then begin
    Result:=true;
    Width:=Max(0,PGtkWidget(Handle)^.Allocation.Width);
    Height:=Max(0,PGtkWidget(Handle)^.Allocation.Height);
    //DebugLn(['TGtkWidgetSet.GetWindowSize ',DbgSName(GetLCLOwnerObject(Handle)),' Allocation=',Width,'x',Height]);
  end else
    Result:=false;
end;

{------------------------------------------------------------------------------
  Function: GradientFill
  Params: DC - DeviceContext to perform on
          Vertices - array of Points W/Color & Alpha
          NumVertices - Number of Vertices
          Meshes - array of Triangle or Rectangle Meshes,
                   each mesh representing one Gradient Fill
          NumMeshes - Number of Meshes
          Mode - Gradient Type, either Triangle,
                 Vertical Rect, Horizontal Rect

  Returns: true on success

  Performs multiple Gradient Fills, either a Three way Triangle Gradient,
  or a two way Rectangle Gradient, each Vertex point also supports optional
  Alpha/Transparency for more advanced Gradients.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.GradientFill(DC: HDC; Vertices: PTriVertex;
  NumVertices : Longint; Meshes: Pointer; NumMeshes : Longint; Mode : Longint
  ): Boolean;

var
  DevCtx: TGtkDeviceContext absolute DC;

  function DoFillTriangle : Boolean;
  begin
    Result := (Mode and GRADIENT_FILL_TRIANGLE) = GRADIENT_FILL_TRIANGLE;
  end;

  function DoFillVRect : Boolean;
  begin
    Result := (Mode and GRADIENT_FILL_RECT_V) = GRADIENT_FILL_RECT_V;
  end;

  procedure GetGradientBrush(BeginColor, EndColor : TColorRef; Position,
    TotalSteps : Longint; var GradientBrush : hBrush);
  var
    R1, G1, B1 : Integer;
    R2, G2, B2 : Integer;
    NewBrush : TLogBrush;
  begin
    GetRGBIntValues(BeginColor,R1,G1,B1);
    GetRGBIntValues(EndColor,R2,G2,B2);

    R1 := R1 + (Position*(R2 - R1) div TotalSteps);
    G1 := G1 + (Position*(G2 - G1) div TotalSteps);
    B1 := B1 + (Position*(B2 - B1) div TotalSteps);

    with NewBrush do
    begin
      lbStyle := BS_SOLID;
      lbColor := RGB(R1,G1,B1);
    end;

    If GradientBrush <> 0 then
      LCLIntf.DeleteObject(GradientBrush);
    GradientBrush := LCLIntf.CreateBrushIndirect(NewBrush);
  end;

  function FillTriMesh(Mesh : tagGradientTriangle) : Boolean;
  {var
    V1, V2, V3 : tagTRIVERTEX;
    C1, C2, C3 : TColorRef;
  begin
    With Mesh do begin
      Result := (Vertex1 < NumVertices) and (Vertex2 >= 0) and
        (Vertex2 < NumVertices) and (Vertex2 >= 0) and
        (Vertex3 < NumVertices) and (Vertex3 >= 0);

      If (Vertex1 = Vertex2) or (Vertex1 = Vertex3) or
        (Vertex2 = Vertex3) or not Result
      then
        exit;

      V1 := Vertices[Vertex1];
      V2 := Vertices[Vertex2];
      V3 := Vertices[Vertex3];

      //Check to make sure they are in reasonable positions..

      //then what??
    end;}
  begin
    Result := False;
  end;

  function FillRectMesh(Mesh : tagGradientRect) : Boolean;
  var
    TL, BR: tagTRIVERTEX;
    StartColor, EndColor: TColorRef;
    I, Swap: Longint;
    SwapColors: Boolean;
    UseBrush: hBrush;
    Steps, MaxSteps: Int64;
  begin
    with Mesh do
    begin
      Result := (UpperLeft < NumVertices) and (UpperLeft >= 0) and
        (LowerRight < NumVertices) and (LowerRight >= 0);
      if (LowerRight = UpperLeft) or not Result then
        exit;
      TL := Vertices[UpperLeft];
      BR := Vertices[LowerRight];
      SwapColors := (BR.Y < TL.Y) and (BR.X < TL.X);
      if BR.X < TL.X then
      begin
        Swap := BR.X;
        BR.X := TL.X;
        TL.X := Swap;
      end;
      if BR.Y < TL.Y then
      begin
        Swap := BR.Y;
        BR.Y := TL.Y;
        TL.Y := Swap;
      end;
      StartColor := RGB(TL.Red shr 8, TL.Green shr 8, TL.Blue shr 8);
      EndColor := RGB(BR.Red shr 8, BR.Green shr 8, BR.Blue shr 8);
      if SwapColors then
      begin
        Swap := StartColor;
        StartColor := EndColor;
        EndColor := Swap;
      end;
      UseBrush := 0;
      MaxSteps := GetDeviceCaps(DC, BITSPIXEL);
      if MaxSteps >= 32 then
        MaxSteps := $FFFFFFFF
      else
      if MaxSteps >= 4 then
        MaxSteps := 1 shl MaxSteps
      else
        MaxSteps := 256;
      if DoFillVRect then
      begin
        Steps := Min(BR.Y - TL.Y, MaxSteps);
        for I := 0 to Steps - 1 do
        begin
          GetGradientBrush(StartColor, EndColor, I, Steps, UseBrush);
            LCLIntf.FillRect(DC, Rect(TL.X, TL.Y + I, BR.X, TL.Y + I + 1),
              UseBrush)
        end
      end
      else begin
        Steps := Min(BR.X - TL.X, MaxSteps);
        for I := 0 to  Steps - 1 do
        begin
          GetGradientBrush(StartColor, EndColor, I, Steps, UseBrush);
          LCLIntf.FillRect(DC, Rect(TL.X + I, TL.Y, TL.X + I + 1, BR.Y),
            UseBrush);
        end;
      end;
      If UseBrush <> 0 then
        LCLIntf.DeleteObject(UseBrush);
    end;
  end;

const
  MeshSize: Array[Boolean] of Integer = (
    SizeOf(tagGradientRect), SizeOf(tagGradientTriangle));
var
  I : Integer;
begin
  //Currently Alpha blending is ignored... Ideas anyone?
  Result := (Meshes <> nil) and (NumMeshes >= 1) and (NumVertices >= 2)
            and (Vertices <> nil);
  if Result and DoFillTriangle then
    Result := NumVertices >= 3;
  if Result then
  begin
    Result := False;

    //Sanity Checks For Vertices Size vs. Count
    if MemSize(Vertices) < PtrInt(SizeOf(tagTRIVERTEX)*NumVertices) then
      exit;

    //Sanity Checks For Meshes Size vs. Count
    if MemSize(Meshes) < PtrInt(MeshSize[DoFillTriangle]*NumMeshes) then
      exit;

    for I := 0 to NumMeshes - 1 do
    begin
      if DoFillTriangle then
      begin
        If not FillTriMesh(PGradientTriangle(Meshes)[I]) then
          exit;
      end
      else
      begin
        if not FillRectMesh(PGradientRect(Meshes)[I]) then
          exit;
      end;
    end;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  Function: HideCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.HideCaret(hWnd: HWND): Boolean;
var
  GTKObject: PGTKObject;
  WasVisible: boolean;
begin
//DebugLn('[TGtkWidgetSet.HideCaret] A');
  //DebugLn(Format('Trace:  [TGtkWidgetSet.HideCaret] HWND: 0x%x', [hWnd]));
//TODO: [TGtkWidgetSet.HideCaret] Finish (in gtkwinapi.inc)

  GTKObject := PGTKObject(HWND);
  Result := GTKObject <> nil;

  if Result
  then begin
    if gtk_type_is_a(gtk_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_HideCaret(PGTKAPIWidget(GTKObject),WasVisible);
    end
//    else if // TODO: other widgettypes
    else begin
      Result := False;
    end;
  end
  else DebugLn('WARNING: [TGtkWidgetSet.HideCaret] Got null HWND');

end;

{------------------------------------------------------------------------------
  Function: IntersectClipRect
  Params:  dc: hdc; Left, Top, Right, Bottom: Integer
  Returns: Integer

  Shrinks the clipping region in the device context dc to a region of all
  intersecting points between the boundary defined by Left, Top, Right,
  Bottom , and the Current clipping region.

  The result can be one of the following constants
      Error
      NullRegion
      SimpleRegion
      ComplexRegion

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.IntersectClipRect(dc: hdc;
  Left, Top, Right, Bottom: Integer): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  if not IsValidDC(DC) then Exit;

  if DevCtx.HasTransf then
  begin
    DevCtx.TransfRect(Left, Top, Right, Bottom);
    DevCtx.TransfNormalize(Left, Right);
    DevCtx.TransfNormalize(Top, Bottom);
  end;

  Result := inherited IntersectClipRect(DC, Left, Top, Right, Bottom);
end;

{------------------------------------------------------------------------------
  Function: InvalidateRect
  Params: aHandle:
          Rect:
          bErase:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.InvalidateRect(aHandle : HWND; Rect : pRect;
  bErase : Boolean) : Boolean;
var
  gdkRect : TGDKRectangle;
  Widget, PaintWidget: PGtkWidget;
  LCLObject: TObject;
  r: TRect;
  List: PGList;
  i: Integer;
  Pt: TPoint;
  Adjustment: PGtkAdjustment;
  Scrolled: PGtkScrolledWindow;
begin
  //  DebugLn(format('Rect = %d,%d,%d,%d',[rect^.left,rect^.top,rect^.Right,rect^.Bottom]));
  Widget:=PGtkWidget(aHandle);
  LCLObject:=GetLCLObject(Widget);
  if (LCLObject<>nil) then begin
    if (LCLObject=CurrentSentPaintMessageTarget) then begin
      DebugLn('NOTE: TGtkWidgetSet.InvalidateRect during paint message: ',
        LCLObject.ClassName);
      //DumpStack;
      //RaiseGDBException('Double paint');
    end;
    {$IFDEF VerboseDsgnPaintMsg}
    if (LCLObject is TComponent)
    and (csDesigning in TComponent(LCLObject).ComponentState) then begin
      write('TGtkWidgetSet.InvalidateRect A ');
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

  if Rect = nil then begin
    Rect := @r;
    Rect^.Left := 0;//PaintWidget^.Allocation.X;
    Rect^.Top := 0;//PaintWidget^.Allocation.Y;
    Rect^.Right := PaintWidget^.Allocation.Width;
    Rect^.Bottom := PaintWidget^.Allocation.Height;
   end;
  gdkRect.X := Rect^.Left;
  gdkRect.Y := Rect^.Top;
  gdkRect.Width := (Rect^.Right - Rect^.Left);
  gdkRect.Height := (Rect^.Bottom - Rect^.Top);

  if LCLObject is TScrollingWinControl then
  begin
    List := gtk_container_children(PGtkContainer(Widget));
    if (g_list_length(List) > 0) and
      GTK_IS_SCROLLED_WINDOW(g_list_nth_data(List, 0)) then
    begin
      Scrolled := PGtkScrolledWindow(g_list_nth_data(List, 0));
      Pt := Point(0, 0);
      Adjustment := gtk_scrolled_window_get_vadjustment(Scrolled);
      if Adjustment <> nil then
        Pt.Y := Round(Adjustment^.value);

      Adjustment := gtk_scrolled_window_get_hadjustment(Scrolled);
      if Adjustment <> nil then
        Pt.X := Round(Adjustment^.value);
      dec(gdkRect.X, Pt.X);
      dec(gdkRect.Y, Pt.Y);
    end;
    g_list_free(List);
  end;
  if bErase then
    gtk_widget_queue_clear_area(PaintWidget,
                              gdkRect.X,gdkRect.Y,gdkRect.Width,gdkRect.Height);

  gtk_widget_queue_draw_area(PaintWidget,
                             gdkRect.X,gdkRect.Y,gdkRect.Width,gdkRect.Height);
  {$IfNDef GTK1}
  //DebugLn(['TGtkWidgetSet.InvalidateRect ',GetWidgetDebugReport(Widget),' IsAPI=',GtkWidgetIsA(PGTKWidget(Widget),GTKAPIWidget_GetType)]);
  if GtkWidgetIsA(PGTKWidget(Widget),GTKAPIWidget_GetType) then
    GTKAPIWidget_InvalidateCaret(PGTKAPIWidget(Widget));
  {$EndIf}
end;

function TGTKWidgetSet.IsIconic(handle: HWND): boolean;
var
  GtkWindow: PGtkWindow absolute handle;
begin
  Result := False;
  if GtkWindow = nil then
    Exit;

  {$ifdef gtk1}
  Result := GDK_WINDOW_GET_MINIMIZED(PGdkWindowPrivate(PgtkWidget(GtkWindow)^.Window));
  {$else}
  Result := (PGtkWidget(GtkWindow)^.Window<>nil)
      and (gdk_window_get_state(PGtkWidget(GtkWindow)^.Window)
           and GDK_WINDOW_STATE_ICONIFIED <> 0);
  {$endif}
end;

function TGTKWidgetSet.IsWindow(handle: HWND): boolean;
begin
  if Handle = 0 then
    Exit(False);

  Result := GtkWidgetIsA(PGtkWidget(Handle), GTK_TYPE_WIDGET);
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.IsWindowEnabled(handle: HWND): boolean;

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.IsWindowEnabled(handle: HWND): boolean;
var
  LCLObject: TObject;
  Widget: PGtkWidget;
  AForm: TCustomForm;
  //i: Integer;
begin
  Widget:=PGtkWidget(handle);
  Result:=(Widget<>nil) and GTK_WIDGET_SENSITIVE(Widget)
          and GTK_WIDGET_PARENT_SENSITIVE(Widget);
  LCLObject:=GetLCLObject(PGtkWidget(Handle));
  //debugln('TGtkWidgetSet.IsWindowEnabled A ',DbgSName(LCLObject),' Result=',dbgs(Result),
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
      //debugln('TGtkWidgetSet.IsWindowEnabled B ',dbgs(Screen.CustomFormBelongsToActiveGroup(AForm)));
      //for i:=0 to Screen.CustomFormCount-1 do begin
      //  debugln('  ',dbgs(i),' ',DbgSName(Screen.CustomFormsZOrdered[i]));
      //end;
    end;
  end;
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.IsWindowVisible(handle: HWND): boolean;

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.IsWindowVisible(handle: HWND): boolean;
begin
  Result:=(handle<>0) and GTK_WIDGET_VISIBLE(PGtkWidget(handle));
end;

function TGTKWidgetSet.IsZoomed(handle: HWND): boolean;
var
  GtkWindow: PGtkWindow absolute handle;
begin
  Result := False;
  if GtkWindow = nil then
    Exit;

  {$ifdef gtk1}
  Result := GDK_WINDOW_GET_MAXIMIZED(PGdkWindowPrivate(PgtkWidget(GtkWindow)^.Window));
  {$else}
  Result := gdk_window_get_state(PGtkWidget(GtkWindow)^.Window) and GDK_WINDOW_STATE_MAXIMIZED <> 0;
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: LineTo
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.LineTo(DC: HDC; X, Y: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  DCOrigin: TPoint;
  FromX: Integer;
  FromY: Integer;
  ToX: Integer;
  ToY: Integer;
begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.LineTo] DC:0x%x, X:%d, Y:%d', [DC, X, Y]));

  if not IsValidDC(DC) then Exit(False);

  DevCtx.SelectPenProps;
  if not (dcfPenSelected in DevCtx.Flags) then Exit(False);
  
  if DevCtx.IsNullPen then Exit(True);

  if DevCtx.HasTransf then
    DevCtx.TransfPoint(X, Y);

  DCOrigin := DevCtx.Offset;

  FromX:=DevCtx.PenPos.X+DCOrigin.X;
  FromY:=DevCtx.PenPos.Y+DCOrigin.Y;
  ToX:=X+DCOrigin.X;
  ToY:=Y+DCOrigin.Y;
  
  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  gdk_draw_line(DevCtx.Drawable, DevCtx.GC, FromX, FromY, ToX, ToY);
  {$IFDEF DebugGDK}EndGDKErrorTrap;{$ENDIF}

  DevCtx.PenPos:= Point(X, Y);

  Result := True;
  
  //DebugLn(Format('trace:< [TGtkWidgetSet.LineTo] DC:0x%x, X:%d, Y:%d', [DC, X, Y]));
end;

function TGTKWidgetSet.LPtoDP(DC: HDC; var Points; Count: Integer): BOOL;
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
  //DebugLn('[MessageButtonClicked] ',dbgs(data),' ',dbgs(gtk_object_get_data(PGtkObject(Widget), 'modal_result')));
  if PInteger(data)^ = 0 then
    PInteger(data)^:=PtrUInt(gtk_object_get_data(PGtkObject(Widget), 'modal_result'));
  Result:=false;
end;

function MessageBoxClosed(Widget : PGtkWidget; Event : PGdkEvent;
  data: gPointer) : GBoolean; cdecl;
var ModalResult : PtrUInt;
begin
  { We were requested by window manager to close }
  if PInteger(data)^ = 0 then begin
    ModalResult:= PtrUInt(gtk_object_get_data(PGtkObject(Widget), 'modal_result'));
    { Don't allow to close if we don't have a default return value }
    Result:= (ModalResult = 0);
    if not Result then PInteger(data)^:= ModalResult
    else DebugLn('Do not close !!!');
  end else Result:= false;
end;

function TGtkWidgetSet.MessageBox(hWnd: HWND; lpText, lpCaption: PChar;
  uType : Cardinal): integer;
var Dialog, ALabel : PGtkWidget;
    ButtonCount, DefButton, ADialogResult : Integer;
    DialogType : Cardinal;

    procedure CreateButton(const ALabel : PChar; const RetValue : integer);
    var AButton : PGtkWidget;
    begin
      AButton:= gtk_button_new_with_label(ALabel);
      Inc(ButtonCount);
      if ButtonCount = DefButton then begin
        gtk_window_set_focus(PGtkWindow(Dialog), AButton);
      end;
      { If there is the Cancel button, allow the dialog to close }
      if RetValue = IDCANCEL then begin
        gtk_object_set_data(PGtkObject(Dialog), 'modal_result', Pointer(IDCANCEL));
      end;
      gtk_object_set_data(PGtkObject(AButton), 'modal_result',
                          Pointer(PtrInt(RetValue)));
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
  DebugGtkWidgets.MarkCreated(Dialog,'TGtkWidgetSet.MessageBox');
  {$ENDIF}
  g_signal_connect(PGtkObject(Dialog), 'delete-event', TGtkSignalFunc(@MessageBoxClosed), @ADialogResult);
  gtk_window_set_default_size(PGtkWindow(Dialog), 100, 100);
  ALabel:= gtk_label_new(lpText);
  gtk_container_add (PGtkContainer(PGtkDialog(Dialog)^.vbox), ALabel);
  DialogType:= (uType and $0000000F);
  if DialogType = MB_OKCANCEL
  then begin
    CreateButton(PChar(rsMbOK), IDOK);
    CreateButton(PChar(rsMbCancel), IDCANCEL);
  end
  else begin
    if DialogType = MB_ABORTRETRYIGNORE
    then begin
      CreateButton(PChar(rsMbAbort), IDABORT);
      CreateButton(PChar(rsMbRetry), IDRETRY);
      CreateButton(PChar(rsMbIgnore), IDIGNORE);
    end
    else begin
      if DialogType = MB_YESNOCANCEL
      then begin
        CreateButton(PChar(rsMbYes), IDYES);
        CreateButton(PChar(rsMbNo), IDNO);
        CreateButton(PChar(rsMbCancel), IDCANCEL);
      end
      else begin
        if DialogType = MB_YESNO
        then begin
          CreateButton(PChar(rsMbYes), IDYES);
          CreateButton(PChar(rsMbNo), IDNO);
        end
        else begin
          if DialogType = MB_RETRYCANCEL
          then begin
            CreateButton(PChar(rsMbRetry), IDRETRY);
            CreateButton(PChar(rsMbCancel), IDCANCEL);
          end
          else begin
            { We have no buttons to show. Create the default of OK button }
            CreateButton(PChar(rsMbOK), IDOK);
          end;
        end;
      end;
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
function TGtkWidgetSet.MoveToEx(DC: HDC; X, Y: Integer;
  OldPoint: PPoint): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.MoveToEx] DC:0x%x, X:%d, Y:%d', [DC, X, Y]));
  Result := IsValidDC(DC);
  if Result
  then with TGtkDeviceContext(DC) do
  begin
    if OldPoint <> nil then OldPoint^ := PenPos;

    if DevCtx.HasTransf then
      DevCtx.TransfPoint(X, Y);

    PenPos := Point(X, Y);
  end;
  //DebugLn(Format('trace:< [TGtkWidgetSet.MoveToEx] DC:0x%x, X:%d, Y:%d', [DC, X, Y]));
end;

{------------------------------------------------------------------------------
  function MoveWindowOrgEx(DC: HDC; dX, dY: Integer): Boolean; override;

  Move the origin of all operations of a DeviceContext.
  For example:
  Moving the Origin to 10,20 and drawing a point to 50,50, results in
  drawing a point to 60,70.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.MoveWindowOrgEx(DC: HDC; dX, dY: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  NewOrigin: TPoint;
begin
  Result:=IsValidDC(DC);
  if Result then
  with TGtkDeviceContext(DC) do begin
    //DebugLn(['[TGtkWidgetSet.MoveWindowOrgEx] B DC=',DbgS(DC),
    //  ' Old=',Origin.X,',',Origin.Y,' d=',dX,',',dY,' ']);
    NewOrigin:=Origin;
    inc(NewOrigin.X,dX);
    inc(NewOrigin.Y,dY);
    Origin:=NewOrigin;
  end;
end;

{------------------------------------------------------------------------------
  Method:  PaintRgn
  Params:  DC: HDC; RGN: HRGN
  Returns: if the function succeeds

  Paints the specified region by using the brush currently selected into the
  device context.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.PaintRgn(DC: HDC; RGN: HRGN): Boolean;
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
function TGtkWidgetSet.PeekMessage(var lpMsg: TMsg; Handle : HWND;
  wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): Boolean;
var
  vlItem : TGtkMessageQueueItem;
begin
  //TODO Filtering
  DebugLn('Peek !!!' );
  fMessageQueue.Lock;
  try
    vlItem := fMessageQueue.FirstMessageItem;
    Result := vlItem <> nil;

    if Result  then begin
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
function TGtkWidgetSet.PolyBezier(DC: HDC; Points: PPoint; NumPts: Integer;
  Filled, Continuous: Boolean): Boolean;
begin
  Result := inherited PolyBezier(DC, Points, NumPts, Filled, Continuous);
end;

{------------------------------------------------------------------------------
  Method:   TGtkWidgetSet.Polygon
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
function TGtkWidgetSet.Polygon(DC: HDC; Points: PPoint; NumPts: Integer;
  Winding: Boolean): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  i: integer;
  PointArray: PGDKPoint;
  Tmp, RGN : hRGN;
  ClipRect : TRect;
  DCOrigin: TPoint;
  OldNumPts: integer;
begin
  if not IsValidDC(DC) then Exit(False);

  if NumPts <= 0 then Exit(True);
  
  DCOrigin := DevCtx.Offset;
  OldNumPts := NumPts;

  // create the PointsArray, which is a copy of Points moved by the DCOrigin
  // only if needed
  if (DevCtx.IsNullPen and (DevCtx.IsNullBrush or Winding)) then
    PointArray := nil
  else
  begin
    GetMem(PointArray, SizeOf(TGdkPoint) * (NumPts + 1)); // +1 for return line
    for i := 0 to NumPts - 1 do
    begin
      if DevCtx.HasTransf then
        Points[I] := DevCtx.TransfPointIndirect(Points[I]);
      PointArray[i].x := Points[i].x + DCOrigin.X;
      PointArray[i].y := Points[i].y + DCOrigin.Y;
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
      RGN := CreatePolygonRgn(Points, OldNumPts, LCLType.Winding);
      ExtSelectClipRGN(DC, RGN, RGN_AND);
      DeleteObject(RGN);
      GetClipBox(DC, @ClipRect);
      if DevCtx.HasTransf then
      begin
        ClipRect := DevCtx.InvTransfRectIndirect(ClipRect);
        DevCtx.TransfNormalize(ClipRect.Left, ClipRect.Right);
        DevCtx.TransfNormalize(ClipRect.Top, ClipRect.Bottom);
      end;
      // draw polygon area
      DevCtx.FillRect(ClipRect, HBrush(PtrUInt(DevCtx.GetBrush)), False);
      // restore old clipping
      SelectClipRGN(DC, Tmp);
      DeleteObject(Tmp);
    end
    else
    begin
      DevCtx.SelectBrushProps;
      gdk_draw_polygon(DevCtx.Drawable, DevCtx.GC, 1, PointArray, NumPts);
    end;
  end;
    
  // draw outline
  if not DevCtx.IsNullPen
  then begin
    DevCtx.SelectPenProps;
    gdk_draw_polygon(DevCtx.Drawable, DevCtx.GC, 0, PointArray, NumPts);
  end;

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}

  if PointArray <> nil then FreeMem(PointArray);

  Result := True;
end;

function TGtkWidgetSet.Polyline(DC: HDC; Points: PPoint; NumPts: Integer): boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  i: integer;
  PointArray: PGDKPoint;
  DCOrigin: TPoint;
begin
  if not IsValidDC(DC) then Exit(False);
  
  if NumPts <= 0 then Exit(True);
  if DevCtx.IsNullPen then Exit(True);

  DCOrigin := DevCtx.Offset;

  GetMem(PointArray, SizeOf(TGdkPoint)*NumPts);
  for i:=0 to NumPts-1 do
  begin
    if DevCtx.HasTransf then
      Points[I] := DevCtx.TransfPointIndirect(Points[I]);
    PointArray[i].x:=Points[i].x+DCOrigin.X;
    PointArray[i].y:=Points[i].y+DCOrigin.Y;
  end;

  // draw line
  DevCtx.SelectPenProps;
  Result := dcfPenSelected in DevCtx.Flags;
  if Result and not DevCtx.IsNullPen
  then begin
    {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
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
function TGtkWidgetSet.PostMessage(Handle: HWND; Msg: Cardinal; wParam: WParam;
  lParam: LParam): Boolean;

  function ParentPaintMessageInQueue: boolean;
  var
    Target: TControl;
    Parent: TWinControl;
    ParentHandle: hWnd;
  begin
    Result:=false;
    Target:=TControl(GetLCLObject(Pointer(Handle)));
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

  New(AMessage);
  FillByte(AMessage^,SizeOf(TMsg),0);
  AMessage^.HWnd := Handle; // this is normally the main gtk widget
  AMessage^.Message := Msg;
  AMessage^.WParam := WParam;
  AMessage^.LParam := LParam;

  fMessageQueue.Lock;
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
        DebugLn(['TGtkWidgetSet.PostMessage ToDo: wake up gtk']);
      {$ENDIF}
    end;
  finally
    fMessageQueue.UnLock;
  end;
end;

{------------------------------------------------------------------------------
  Method:   RadialArc
  Params:   DC, left, top, right, bottom, sx, sy, ex, ey
  Returns:  Nothing

  Use RadialArc to draw an elliptically curved line with the current Pen. The
  values sx,sy, and ex,ey represent the starting and ending radial-points
  between which the Arc is drawn.

------------------------------------------------------------------------------}
function TGtkWidgetSet.RadialArc(DC: HDC; left, top, right, bottom,
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
function TGtkWidgetSet.RadialChord(DC: HDC; x1, y1, x2, y2,
  sx, sy, ex, ey: Integer): Boolean;
begin
  Result := inherited RadialChord(DC, x1, y1, x2, y2, sx, sy, ex, ey);
end;

{------------------------------------------------------------------------------
  Function: RealizePalette
  Params:  DC: HDC
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.RealizePalette(DC: HDC): Cardinal;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn('Trace:FINISH: [TGtkWidgetSet.RealizePalette]');
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

  The Rectangle function draws a rectangle. The rectangle is outlined by using
  the current pen and filled by using the current brush.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  Left, Top, Width, Height: Integer;
  DCOrigin: TPoint;
  Brush: PGdiObject;
begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.Rectangle] DC:0x%x, X1:%d, Y1:%d, X2:%d, Y2:%d', [DC, X1, Y1, X2, Y2]));
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
    
  if not DevCtx.IsNullBrush
  then begin
    Brush := DevCtx.GetBrush;
    if  (Brush^.GDIBrushFill = GDK_SOLID)
    and (IsBackgroundColor(TColor(Brush^.GDIBrushColor.ColorRef)))
    then
      StyleFillRectangle(DevCtx.Drawable, DevCtx.GC, Brush^.GDIBrushColor.ColorRef,
                         Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height)
    else
      gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 1,
                         Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height);
  end;

  // Draw outline
  DevCtx.SelectPenProps;
  Result := dcfPenSelected in DevCtx.Flags;
  if Result and not DevCtx.IsNullPen
  then gdk_draw_rectangle(DevCtx.Drawable, DevCtx.GC, 0,
                          Left+DCOrigin.X, Top+DCOrigin.Y, Width, Height);

  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
  
  //DebugLn(Format('trace:< [TGtkWidgetSet.Rectangle] DC:0x%x, X1:%d, Y1:%d, X2:%d, Y2:%d', [DC, X1, Y1, X2, Y2]));
end;

{------------------------------------------------------------------------------
  Function: RectInRegion
  Params:   RGN: HRGN; ARect: TRect
  Returns:  True if any part of the specified rectangle lies within the
            boundaries of the region.

  Determines whether any part of the specified rectangle is within the boundaries
  of a region.

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.RectInRegion(RGN: HRGN; ARect: TRect): Boolean;
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
function TGtkWidgetSet.RectVisible(DC: HDC; const ARect: TRect): Boolean;
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
function TGtkWidgetSet.RegroupMenuItem(hndMenu: HMENU;
  GroupIndex: Integer): Boolean;

const
  GROUPIDX_DATANAME = 'GroupIndex';

  function GetGroup: PGSList;
  {$IfDef GTK1}
  var
    Item: PGList;
    Arg: TGTKArg;
  begin
    Result := nil;
    Arg.theType := GTK_TYPE_OBJECT;
    Arg.Name := 'parent';
    gtk_widget_get(Pointer(hndMenu), @Arg);
    if Arg.d.object_data = nil then Exit;

    Item := gtk_container_children(PGTKContainer(Arg.d.object_data));
    while Item <> nil do
    begin
      if (Item^.Data <> Pointer(hndMenu)) // exclude ourself
      and gtk_is_radio_menu_item(Item^.Data)
      and (PtrUInt(GroupIndex) = PtrUInt(gtk_object_get_data(Item^.Data, GROUPIDX_DATANAME)))
      then begin
        Result := gtk_radio_menu_item_group(PGtkRadioMenuItem(Item^.Data));
        Exit;
      end;
      Item := Item^.Next;
    end;
  {$Else}
  var
    Item: PGList;
    parent : PGTKWidget;
  begin
    Result := nil;
    parent := gtk_widget_get_parent(Pointer(hndMenu));
    if parent = nil then Exit;

    Item := gtk_container_children(PGTKContainer(parent));
    while Item <> nil do
    begin
      if (Item^.Data <> Pointer(hndMenu)) // exclude ourself
      and gtk_is_radio_menu_item(Item^.Data)
      and (GroupIndex = Integer(PtrUInt(gtk_object_get_data(Item^.Data, GROUPIDX_DATANAME))))
      then begin
        Result := gtk_radio_menu_item_get_group (PGtkRadioMenuItem(Item^.Data));
        Exit;
      end;
      Item := Item^.Next;
    end;
  {$EndIf}
  end;

var
  RadioGroup: PGSList;
  CurrentGroupIndex: Integer;
begin
  Result := False;

  if not gtk_is_radio_menu_item(Pointer(hndMenu))
  then begin
    DebugLn('WARNING: TGtkWidgetSet.RegroupMenuItem: handle is not a GTK_RADIO_MENU_ITEM');
    Exit;
  end;

  CurrentGroupIndex := integer(PtrUInt(gtk_object_get_data(Pointer(hndMenu), GROUPIDX_DATANAME)));

  // Update needed ?
  if GroupIndex = CurrentGroupIndex
  then begin
    Result := True;
    Exit;
  end;

  // Remove current group
  gtk_radio_menu_item_set_group(PGtkRadioMenuItem(hndMenu), nil);
  gtk_object_set_data(Pointer(hndMenu), GROUPIDX_DATANAME, nil);

  // Check remove only
  if GroupIndex = 0
  then begin
    Result := True;
    Exit;
  end;

  // Try to find new group
  RadioGroup := GetGroup;

  // Set new group
  gtk_object_set_data(Pointer(hndMenu), GROUPIDX_DATANAME, Pointer(PtrInt(GroupIndex)));
  if RadioGroup = nil
  then begin
    // We're the only member, get a group
    RadioGroup := gtk_radio_menu_item_group(PGtkRadioMenuItem(hndMenu))
  end
  else begin
    gtk_radio_menu_item_set_group(PGtkRadioMenuItem(hndMenu), RadioGroup);
  end;
                                                                    //radiogroup^.data
                                                                    //radiogroup^.next
  // Refetch newgroup list
  RadioGroup := gtk_radio_menu_item_group(PGtkRadioMenuItem(hndMenu));
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
function TGtkWidgetSet.ReleaseCapture: Boolean;
begin
  SetCapture(0);
  Result := True;
end;

{------------------------------------------------------------------------------
  Function: ReleaseDC
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ReleaseDC(hWnd: HWND; DC: HDC): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;

  aDC, pSavedDC: TGtkDeviceContext;
  g: TGDIType;
  CurGDIObject: PGDIObject;
begin
  //DebugLn(['[TGtkWidgetSet.ReleaseDC] ',DC,'  ',FDeviceContexts.Count]);
  //DebugLn(Format('trace:> [TGtkWidgetSet.ReleaseDC] DC:0x%x', [DC]));
  Result := 0;

  if (DC <> 0)
  then begin
    if FDeviceContexts.Contains(Pointer(DC))
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

      //DebugLn(['TGtkWidgetSet.ReleaseDC DC=',dbgs(TGtkDeviceContext(aDC)),' ClipRegion=',dbgs(aDC.ClipRegion)]);
      // free all owned GDI objects
      for g:=Low(TGDIType) to high(TGDIType) do begin
        CurGDIObject:=aDC.OwnedGDIObjects[g];
        if CurGDIObject<>nil then begin
          if CurGDIObject^.Owner<>aDC then
            RaiseGDBException('');
          DeleteObject(HGDIOBJ(PtrUInt(CurGDIObject)));
          if aDC.OwnedGDIObjects[g]<>nil then
            RaiseGDBException('');
        end;
      end;

      //DebugLn(['TGtkWidgetSet.ReleaseDC DC=',dbghex(PtrInt(DC)),' Font=',dbghex(PtrInt(aDC.CurrentFont))]);

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
          DebugLn('TGtkWidgetSet.ReleaseDC: ',E.Message);
        end;
      end;

      DisposeDC(aDC);
      Result := 1;
    end;
  end;
  //DebugLn(Format('trace:< [TGtkWidgetSet.ReleaseDC] FDeviceContexts DC:0x%x', [DC]));
end;

{------------------------------------------------------------------------------
  Function: RemoveProp
  Params: Handle: Handle of the object
          Str: Name of the property to remove
  Returns: The handle of the property (0=failure)

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.RemoveProp(Handle: hwnd; Str: PChar): THandle;
begin
  gtk_object_remove_data(pGTKObject(handle), Str);
  Result := 1;
end;

{------------------------------------------------------------------------------
  Function: RestoreDC
  Params:  none
  Returns: Nothing


-------------------------------------------------------------------------------}
function TGtkWidgetSet.RestoreDC(DC: HDC; SavedDC: Integer): Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;

  SavedDevCtx: TGtkDeviceContext;
  ClipRegionChanged: Boolean;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.RestoreDC] DC:0x%x, SavedDC: %d', [DC, SavedDC]));

  if not IsValidDC(DC) then Exit(False);
  if SavedDC <= 0 then Exit(False);

  repeat
    SavedDevCtx := DevCtx.SavedContext;
    Dec(SavedDC);

    // TODO copy bitmap too

    ClipRegionChanged := DevCtx.ClipRegion <> SavedDevCtx.ClipRegion;
    
    // clear the GDIObjects in pSavedDC, so they are not freed by DeleteDC
    Result := DevCtx.CopyDataFrom(SavedDevCtx, True, True, True);
    DevCtx.SavedContext := SavedDevCtx.SavedContext;
    SavedDevCtx.SavedContext := nil;

    if ClipRegionChanged then
      DevCtx.SelectRegion;

    // free saved DC
    DeleteDC(HDC(SavedDevCtx));
  until SavedDC <= 0;
  
  //DebugLn(Format('Trace:< [TGtkWidgetSet.RestoreDC] DC:0x%x, Saved: %d --> %s', [Integer(DC), SavedDC, BOOL_TEXT[Result]]));
end;

{------------------------------------------------------------------------------
  Method:   RoundRect
  Params:   X1, Y1, X2, Y2, RX, RY
  Returns:  If succesfull

  Draws a Rectangle with optional rounded corners. RY is the radial height
  of the corner arcs, RX is the radial width. If either is less than or equal to
  0, the routine simly calls to standard Rectangle.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.RoundRect(DC : hDC; X1, Y1, X2, Y2: Integer;
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
function TGtkWidgetSet.SaveDC(DC: HDC): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
  aSavedDC: TGtkDeviceContext;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.SaveDC]  0x%x', [Integer(DC)]));

  Result := 0;
  if IsValidDC(DC) then
  begin
    aSavedDC := NewDC;
    aSavedDC.CopyDataFrom(DevCtx, False, True, False);
    aSavedDC.SavedContext := DevCtx.SavedContext;
    DevCtx.SavedContext:= aSavedDC;
    Result := 1;
  end;

  //DebugLn(Format('Trace:< [TGtkWidgetSet.SaveDC]  0x%x --> %d', [Integer(DC), Result]));
end;

{------------------------------------------------------------------------------
  Function: ScreenToClient
  Params: Handle:
          P:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ScreenToClient(Handle : HWND; var P : TPoint) : Integer;
var
  X, Y: Integer;
  Widget: PGTKWidget;
  Window: PgdkWindow;
Begin

  if Handle = 0
  then begin
    X := 0;
    Y := 0;
  end
  else
   begin
    Widget := GetFixedWidget(pgtkwidget(Handle));
    if Widget = nil then
      Widget := pgtkwidget(Handle);
    if Widget = nil then
    begin
      X := 0;
      Y := 0;
    end
    else begin
      Window:=GetControlWindow(Widget);
      {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
      if Window<>nil then
        gdk_window_get_origin(Window, @X, @Y)
      else begin
        X:=0;
        Y:=0;
      end;
      {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
    end;
  end;

  //DebugLn('[TGtkWidgetSet.ScreenToClient] ',x,',',y,' P=',P.X,',',P.Y);
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
function TGtkWidgetSet.ScrollWindowEx(hWnd: HWND; dx, dy: Integer; prcScroll, prcClip: PRect; hrgnUpdate: HRGN; prcUpdate: PRect; flags: UINT): Boolean;
begin
  Result := False;
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
function TGtkWidgetSet.SelectClipRGN(DC : hDC; RGN : HRGN) : Longint;
var
  DevCtx: TGtkDeviceContext absolute DC;

  RegObj: PGdkRegion;
  DCOrigin: TPoint;
  OldClipRegion: PGDIObject;
begin
  if not IsValidDC(DC) then Exit(ERROR);


  // clear old clipregion
  if DevCtx.ClipRegion <> nil
  then begin
    OldClipRegion := DevCtx.ClipRegion;
    DevCtx.ClipRegion := nil;// decrease DCCount
    if OldClipRegion = DevCtx.OwnedGDIObjects[gdiRegion]
    then DeleteObject(HGDIOBJ(PtrUInt(OldClipRegion)));
  end;

  if RGN = 0
  then begin
    DevCtx.SelectRegion;
    Exit(NULLREGION);
  end;

  if IsValidGDIObject(RGN)
  then begin
    DevCtx.ClipRegion := PGdiObject(CreateRegionCopy(RGN));
    DevCtx.OwnedGDIObjects[gdiRegion] := DevCtx.ClipRegion;
    RegObj := DevCtx.ClipRegion^.GDIRegionObject;
    DCOrigin := DevCtx.Offset;
    gdk_region_offset(RegObj, DCOrigin.x, DCOrigin.Y);
    DevCtx.SelectRegion;

    Exit(RegionType(RegObj));
  end;
  
  // error handling
  Result := ERROR;
  DebugLn('WARNING: [TGtkWidgetSet.SelectClipRGN] Invalid RGN');
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
function TGtkWidgetSet.SelectObject(DC: HDC; GDIObj: HGDIOBJ): HGDIOBJ;

var
  DevCtx: TGtkDeviceContext absolute DC;
  GDIObject: PGdiObject absolute GDIObj;
  ResultObj: PGdiObject absolute Result;
  

  procedure RaiseInvalidGDIType;
  begin
    RaiseGDBException('TGtkWidgetSet.SelectObject Invalid GDIType '+IntToStr(ord(PGdiObject(GDIObj)^.GDIType)));
  end;
  
  {$ifdef DebugLCLComponents}
  procedure DebugInvalidDC;
  begin
    DebugLn(['TGtkWidgetSet.SelectObject DC=',dbghex(DC),' IsValidDC(DC)=',IsValidDC(DC),' GDIObj=',dbghex(GDIObj)]);
    DumpStack;
    DebugLn(['DebugInvalidGDIObject DC:']);
    Debugln(DebugDeviceContexts.GetInfo(Pointer(DC),true));
  end;

  procedure DebugInvalidGDIObject;
  begin
    DebugLn(['TGtkWidgetSet.SelectObject DC=',dbghex(DC),' GDIObj=',dbghex(GDIObj),' IsValidGDIObject(GDIObj)=',IsValidGDIObject(GDIObj)]);
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
      //DebugLn(Format('trace:  [TGtkWidgetSet.SelectObject] DC: 0x%x, Type: Brush', [DC]));

      ResultObj := DevCtx.GetBrush;// always create, because a valid GDIObject is needed to restore
      if DevCtx.CurrentBrush = GDIObject then Exit;
      
      DevCtx.CurrentBrush := GDIObject;
      DevCtx.SelectedColors := dcscCustom;
      if DevCtx.GC = nil then Exit;

      gdk_gc_set_fill(DevCtx.GC, GDIObject^.GDIBrushFill);
      case GDIObject^.GDIBrushFill of
        GDK_STIPPLED: gdk_gc_set_stipple(DevCtx.GC, GDIObject^.GDIBrushPixMap);
        GDK_TILED:    gdk_gc_set_tile(DevCtx.GC, GDIObject^.GDIBrushPixMap);
      end;
    end;

    gdiFont: begin
      //DebugLn(Format('trace:  [TGtkWidgetSet.SelectObject] DC: 0x%x, Type: Font', [DC]));
        
      ResultObj := DevCtx.GetFont;// always create, because a valid GDIObject is needed to restore
      if (DevCtx.CurrentFont = GDIObject) and not DevCtx.HasTransf then Exit;
      
      DevCtx.CurrentFont := GDIObject;

      {$ifdef GTK1}
      if DevCtx.GC <> nil then
        gdk_gc_set_font(DevCtx.GC, GdiObject^.GDIFontObject);
      {$endif}
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
function TGtkWidgetSet.SelectPalette(DC: HDC; Palette: HPALETTE; ForceBackground: Boolean): HPALETTE;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn('Trace:TODO: [TGtkWidgetSet.SelectPalette]');
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
function TGtkWidgetSet.SendMessage(HandleWnd: HWND; Msg: Cardinal; wParam: WParam;
  lParam: LParam): LResult;
var
  OldMsg: Cardinal;

  procedure PreparePaintMessage(TargetObject: TObject; var AMessage: TLMessage);
  var
    GtkPaintData: TLMGtkPaintData;
    OldGtkPaintMsg: TLMGtkPaint;
    {$IFNDEF Gtk2}
    PaintDC: HDC;
    DCOrigin: TPoint;
    R: TRect;
    {$ENDIF}
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
            DebugLn('TGtkWidgetSet.SendMessage A ',
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
      write('TGtkWidgetSet.SendMessage B ',
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
      {$IfNDef GTK2}
      if (GtkPaintData <> nil) and (not GtkPaintData.RepaintAll)
      then begin
        PaintDC := TLMPaint(AMessage).DC;
        DCOrigin := TGtkDeviceContext(PaintDC).Offset;
        R:=GtkPaintData.Rect;
        IntersectClipRect(PaintDC,
                          R.Left - DCOrigin.X, R.Top - DCOrigin.Y,
                          R.Right - DCOrigin.X, R.Bottom - DCOrigin.Y);
      end;
      {$EndIf}
      GtkPaintData.Free;
    end;
  end;

  procedure DisposePaintMessage(TargetObject: TObject; var AMessage: TLMessage);
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

  Target := GetLCLObject(Pointer(HandleWnd));

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
function TGtkWidgetSet.SetActiveWindow(Handle: HWND): HWND;
begin
  // ToDo
  Result := GetActiveWindow;
  {$ifdef gtk2}
  if (Handle <> 0) and GtkWidgetIsA(PGtkWidget(Handle),GTK_TYPE_WINDOW) then
  begin
    if GTK_WIDGET_VISIBLE(PGtkWidget(Handle)) then
      gtk_window_present(PGtkWindow(Handle));
  end else
    Result := 0; // if not active window return error
  {$endif}
end;

{------------------------------------------------------------------------------
  Function: SetBkColor        pbd
  Params:  DC:    Device context to change the text background color
           Color: RGB Tuple
  Returns: Old Background color


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetBKColor(DC: HDC; Color: TColorRef): TColorRef;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.SetBKColor] DC: 0x%x Color: %8x', [Integer(DC), Color]));
  Result := CLR_INVALID;
  if IsValidDC(DC)
  then begin
    with TGtkDeviceContext(DC) do
    begin
      Result := CurrentBackColor.ColorRef;
      SetGDIColorRef(CurrentBackColor,Color);
    end;

  end;
  //DebugLn(Format('trace:< [TGtkWidgetSet.SetBKColor] DC: 0x%x Color: %8x --> %8x', [Integer(DC), Color, Result]));
end;

{------------------------------------------------------------------------------
  Function: SetBkMode
  Params: DC:
          bkMode:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetBkMode(DC: HDC; bkMode : Integer) : Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  // Your code here
  Result:=0;
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.SetComboMinDropDownSize(Handle: HWND;
    MinItemsWidth, MinItemsHeight: integer): boolean;

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetComboMinDropDownSize(Handle: HWND;
  MinItemsWidth, MinItemsHeight, MinItemCount: integer): boolean;
var
  ComboWidget: PGtkCombo;
  DropDownWidget, ListWidget, FirstChildWidget: PGtkWidget;
  FirstChild: PGList;
  CurX, CurY, CurWidth, CurHeight, CurItemHeight, BorderX, BorderY,
  OldWidth, OldHeight,
  NewWidth, NewHeight: integer;
  ComboPopup: PGtkScrolledWindow;
  item_requisition: TGtkRequisition;
begin
  Result:=true;
  if not (GtkWidgetIsA(PgtkWidget(Handle),GTK_TYPE_COMBO)) then
    RaiseGDBException('TGtkWidgetSet.SetComboMinDropDownSize invalid handle');

  // get current items width and height
  ComboWidget:=PGtkCombo(Handle);
  ListWidget:=ComboWidget^.List;
  if ListWidget=nil then exit;
  CurWidth:=ListWidget^.Allocation.Width;
//  CurHeight:=ListWidget^.Allocation.Height;
  CurHeight:=ListWidget^.requisition.Height;
  if MinItemCount>0 then begin
    FirstChild:=PGTkList(ListWidget)^.children;
    if FirstChild<>nil then begin
      FirstChildWidget:=PGtkWidget(FirstChild^.Data);
      if FirstChildWidget<>nil then begin
        gtk_widget_size_request(FirstChildWidget,@item_requisition);
        CurItemHeight:=Max(FirstChildWidget^.Allocation.Height,
                           item_requisition.Height);
      end else begin
        CurItemHeight:=1;
      end;
      if MinItemsHeight<CurItemHeight*MinItemCount then
        MinItemsHeight:=CurItemHeight*MinItemCount;
    end;
  end;

  // calculate new width and height
  DropDownWidget:=ComboWidget^.popwin;
  if DropDownWidget=nil then exit;
  ComboPopup:=PGtkScrolledWindow(ComboWidget^.popup);
  if ComboPopup=nil then exit;
  
  CurX:=DropDownWidget^.Allocation.x;
  CurY:=DropDownWidget^.Allocation.y;
  CurWidth:=pGtkWidget(ComboPopup)^.allocation.Width;
  CurHeight:=pGtkWidget(ComboPopup)^.allocation.Height;

  OldWidth:=DropDownWidget^.allocation.Width;
  OldHeight:=DropDownWidget^.allocation.Height;
  BorderX:=2*(OldWidth-CurWidth);
  if BorderX<0 then BorderX:=0;
  BorderY:=2*(OldHeight-CurHeight);
  if BorderY<0 then BorderY:=0;

  if Gtk_Widget_visible(ComboPopup^.hscrollbar) then
    inc(BorderY, ComboPopup^.hscrollbar^.requisition.height
     +GTK_SCROLLED_WINDOW_CLASS(gtk_object_get_class(comboWidget^.popup))^.scrollbar_spacing);
  if Gtk_Widget_visible(ComboPopup^.vscrollbar) then
    inc(BorderX,ComboPopup^.vscrollbar^.requisition.width
     +GTK_SCROLLED_WINDOW_CLASS(gtk_object_get_class(comboWidget^.popup))^.scrollbar_spacing);
  if minItemsWidth <>0 then NewWidth := MinItemsWidth+BorderX
                       else NewWidth := OldWidth;
  
  if minItemsHeight<>0 then NewHeight := MinItemsHeight+BorderY
                       else NewHeight := OldHeight;

  if (NewWidth=OldWidth) and (NewHeight=OldHeight) then exit;

  NewWidth:=Min(NewWidth, Screen.Width - CurX);
  NewHeight:=Min(NewHeight, Screen.Height - CurY);
  if assigned(dropdownWidget^.Window) then
    // widget is realized, resize gdkwindow directly
    gdk_window_resize(dropdownwidget^.Window,newWidth,newHeight)
  else
    // widget is not yet realized, force resize needed for shrinking under gtk1)
    gtk_widget_set_usize(PGtkWidget(dropDownWidget), -1,-1);
end;

{------------------------------------------------------------------------------
  Function: SetCapture
  Params:  Value: Handle of window to capture
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetCapture(AHandle: HWND): HWND;
var
  Widget: PGtkWidget;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.SetCapture] 0x%x', [AHandle]));
  Widget := PGtkWidget(AHandle);
  {$IfDef VerboseMouseCapture}
  DebugLn('TGtkWidgetSet.SetCapture NewValue=[',GetWidgetDebugReport(Widget),']');
  {$EndIf}

  // return old capture handle
  Result := GetCapture;

  // capture
  CaptureMouseForWidget(Widget, mctLCL);
end;

{------------------------------------------------------------------------------
  Function: SetCaretPos
  Params:  new position x, y
  Returns: true on success

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetCaretPos(X, Y: Integer): Boolean;
var
  FocusObject: PGTKObject;
begin
  FocusObject := PGTKObject(GetFocus);
  Result:=SetCaretPosEx(PtrUInt(FocusObject),X,Y);
end;

{------------------------------------------------------------------------------
  Function: SetCaretPos
  Params:  new position x, y
  Returns: true on success

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetCaretPosEx(Handle: HWNd; X, Y: Integer): Boolean;
var
  GtkObject: PGTKObject;
begin
  GtkObject := PGTKObject(Handle);
  Result := GtkObject <> nil;

  if Result then begin
    if gtk_type_is_a(gtk_object_type(GtkObject), GTKAPIWidget_GetType)
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
function TGtkWidgetSet.SetCaretRespondToFocus(handle: HWND;
  ShowHideOnFocus: boolean): Boolean;
begin
  if handle<>0 then begin
    if gtk_type_is_a(gtk_object_type(PGTKObject(handle)), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_SetCaretRespondToFocus(PGTKAPIWidget(handle),
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
function TGtkWidgetSet.SetCursor(ACursor: HCURSOR): HCURSOR;
var
  DefaultCursor: HCursor;


  procedure SetGlobalCursor;
  var
    TopList, List: PGList;
  begin
    TopList := gdk_window_get_toplevels;
    List := TopList;
    while List <> nil do
    begin
      if (List^.Data <> nil) then
        SetWindowCursor(PGDKWindow(List^.Data), ACursor, True);
      list := g_list_next(list);
    end;

    if TopList <> nil then
      g_list_free(TopList);
  end;

  procedure ResetGlobalCursor;
    procedure SetToWindow(AWindow: PGDKWindow);
    var
      data: gpointer;
      Widget: PGTKWidget absolute data;
      WidgetInfo: PWidgetInfo;
      WSPrivate: TWSPrivateClass;
    begin
      gdk_window_get_user_data(AWindow, @data);

      if GtkWidgetIsA(Widget, gtk_widget_get_type)
      then begin
        WidgetInfo := GetWidgetInfo(Widget);
        if  (WidgetInfo <> nil)
        and (WidgetInfo^.LCLObject <> nil)
        and (WidgetInfo^.LCLObject is TWinControl)
        then begin
          WSPrivate := TWinControl(WidgetInfo^.LCLObject).WidgetSetClass.WSPrivate;
          TGtkPrivateWidgetClass(WSPrivate).UpdateCursor(WidgetInfo);
          Exit;
        end;
      end;
      
      // no lcl cursor, so reset to default
      //gdk_window_set_cursor(AWindow, PGdkCursor(DefaultCursor));
      SetWindowCursor(AWindow, DefaultCursor, True);
    end;

    procedure Traverse(AWindow: PGDKWindow);
    var
      ChildWindows, ListEntry: PGList;
    begin
      SetToWindow(AWindow);

      ChildWindows := gdk_window_get_children(AWindow);

      ListEntry := ChildWindows;
      while ListEntry <> nil do
      begin
        Traverse(PGdkWindow(ListEntry^.Data));
        ListEntry := ListEntry^.Next;
      end;
      g_list_free(ChildWindows);
    end;
  var
    TopList, List: PGList;
  begin
    TopList := gdk_window_get_toplevels;
    List := TopList;
    while List <> nil do
    begin
      if (List^.Data <> nil) then
        Traverse(PGDKWindow(List^.Data));
      list := g_list_next(list);
    end;

    if TopList <> nil then
      g_list_free(TopList);
  end;


begin
  // set global gtk cursor
  Result := FGlobalCursor;
  if ACursor = FGlobalCursor then Exit;
  
  DefaultCursor := Screen.Cursors[crDefault];
  if ACursor <> DefaultCursor
  then SetGlobalCursor
  else ResetGlobalCursor;
  FGlobalCursor := ACursor;
end;

{------------------------------------------------------------------------------
  Function: SetCursorPos
  Params: X:
          Y:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetCursorPos(X, Y: Integer): Boolean;
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
  DebugLn('TGtkWidgetSet.SetCursorPos not implemented for this platform');
  // Can this call TWin32WidgetSet.SetCursorPos?
end;
{$ENDIF HasX}

{------------------------------------------------------------------------------
  Function: SetFocus
  Params:  hWnd: Handle of new focus window
  Returns: The old focus window

  The SetFocus function sets the keyboard focus to the specified window
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetFocus(hWnd: HWND): HWND;
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
  Widget:=PGtkWidget(hWnd);
  {$IfDef VerboseFocus}
  DebugLn('');
  debugln('[TGtkWidgetSet.SetFocus] A hWnd=',GetWidgetDebugReport(Widget));
  //DebugLn(getStackTrace(true));
  {$EndIf}

  // return the old focus handle
  Result := GetFocus;
  NewFocusWidget := nil;

  TopLevel := gtk_widget_get_toplevel(Widget);
  {$IfDef VerboseFocus}
  Debugln('[TGtkWidgetSet.SetFocus] B');
  DbgOut('   TopLevel=',DbgS(TopLevel));
  DbgOut(' OldFocus=',GetWidgetDebugReport(PGtkWidget(Result)));
  DebugLn('');
  if not GTK_WIDGET_VISIBLE(Widget) then
    raise Exception.Create('TGtkWidgetSet.SetFocus: Widget is not visible');
  {$EndIf}

  if Result=hWnd then exit;

  if GtkWidgetIsA(TopLevel, gtk_window_get_type) then
  begin
    // TopLevel is a gtkwindow
    {$IfDef VerboseFocus}
    AWinControl:=TWinControl(GetNearestLCLObject(PGtkWindow(TopLevel)^.focus_widget));
    write('  C  TopLevel is a gtkwindow ');
    write(' focus_widget=',DbgS(PGtkWindow(TopLevel)^.focus_widget));
    if AWinControl<>nil then
      write(' LCLParent=',AWinControl.Name,':',AWinControl.ClassName)
    else
      write(' LCLParent=nil');
    DebugLn('');
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
    write('  G NewFocusWidget=',DbgS(NewFocusWidget),' ',DbgSName(GetNearestLCLObject(NewFocusWidget)));
    write(' WidVisible=',GTK_WIDGET_VISIBLE(PGtkWidget(NewFocusWidget)));
    write(' WidRealized=',GTK_WIDGET_REALIZED(PGtkWidget(NewFocusWidget)));
    write(' WidMapped=',GTK_WIDGET_MAPPED(PGtkWidget(NewFocusWidget)));
    write(' WidCanfocus=',GTK_WIDGET_CAN_FOCUS(PGtkWidget(NewFocusWidget)));
    write(' TopLvlVisible=',GTK_WIDGET_VISIBLE(PGtkWidget(TopLevel)));
    DebugLn('');
    {$EndIf}
    if (NewFocusWidget<>nil) and GTK_WIDGET_CAN_FOCUS(NewFocusWidget) then
    begin
      if (PGtkWindow(TopLevel)^.Focus_Widget<>NewFocusWidget) then
      begin
        {$IfDef VerboseFocus}
        DebugLn('  H SETTING NewFocusWidget=',dbgs(NewFocusWidget),' ',DbgSName(GetNearestLCLObject(NewFocusWidget)));
        {$EndIf}
        //DebugLn('TGtkWidgetSet.SetFocus TopLevel[',DebugGtkWidgets.GetInfo(TopLevel,false),'] NewFocusWidget=[',DebugGtkWidgets.GetInfo(NewFocusWidget,false),']');
        gtk_window_set_focus(PGtkWindow(TopLevel), NewFocusWidget);
        {$IfDef VerboseFocus}
        DebugLn('  I NewTopLevel FocusWidget=',DbgS(PGtkWindow(TopLevel)^.Focus_Widget),' Success=',dbgs(PGtkWindow(TopLevel)^.Focus_Widget=NewFocusWidget));
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
      DebugLn('[TGtkWidgetSet.SetFocus] there is a modal form -> not grabbing');
      {$ENDIF}
    end
    else
    begin
      {$IfDef VerboseFocus}
      DebugLn('  J Grabbing focus ',GetWidgetDebugReport(NewFocusWidget));
      {$EndIf}
      if NewTopLevelObject is TCustomForm then
      begin
        Info := GetWidgetInfo(NewTopLevelWidget, False);
        if (Info <> nil) and not (wwiActivating in  Info^.Flags) then
          SetForegroundWindow(TCustomForm(NewTopLevelObject).Handle);
      end;
      gtk_widget_grab_focus(NewFocusWidget);
    end;
  end;

  {$IfDef VerboseFocus}
  write('[TGtkWidgetSet.SetFocus] END hWnd=',DbgS(hWnd));
  NewFocusWidget:=PGtkWidget(GetFocus);
  write(' NewFocus=',DbgS(NewFocusWidget));
  AWinControl:=TWinControl(GetNearestLCLObject(NewFocusWidget));
  if AWinControl<>nil then
    write(' NewLCLParent=',AWinControl.Name,':',AWinControl.ClassName)
  else
    write(' NewLCLParent=nil');
  DebugLn('');
  {$EndIf}
end;

{------------------------------------------------------------------------------
  Function: SetForegroundWindow
  Params: hWnd:
  Returns:

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetForegroundWindow(hWnd : HWND): boolean;
var
  {$IFDEF VerboseFocus}
  LCLObject: TControl;
  {$ENDIF}
  GdkWindow: PGdkWindow;
  AForm: TCustomForm;
  {$IFDEF GTK1}
  FormWidget: PGtkWidget;
  FormWindow: PGdkWindowPrivate;
  WindowDesktop: Integer;
  {$ENDIF}
begin
  {$IFDEF VerboseFocus}
  DbgOut('TGtkWidgetSet.SetForegroundWindow hWnd=',DbgS(hWnd));
  LCLObject:=TControl(GetLCLObject(Pointer(hWnd)));
  if LCLObject<>nil then
    DebugLn(' LCLObject=',LCLObject.Name,':',LCLObject.ClassName)
  else
    DebugLn(' LCLObject=nil');
  {$ENDIF}
  Result := GtkWidgetIsA(PGtkWidget(hWnd),GTK_TYPE_WINDOW);
  if Result then
  begin
    GdkWindow := GetControlWindow(PgtkWidget(hwnd));
    if GdkWindow <> nil then
    begin
      if not gdk_window_is_visible(GdkWindow) then
      begin
        Result := False;
        Exit;
      end;
      AForm := TCustomForm(GetLCLObject(PgtkWidget(hwnd)));
      if (AForm <> nil) and (AForm is TCustomForm) and (AForm.Parent=nil) then
      begin
        if Screen.CustomFormZIndex(AForm) < Screen.GetCurrentModalFormZIndex then
        begin
          debugln('TGtkWidgetSet.SetForegroundWindow Form=',DbgSName(AForm),
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
      {$IFDEF DebugGDKTraps}
      EndGDKErrorTrap;
      {$ENDIF}
{$IFDEF GTK1}
      FormWidget:=PGtkWidget(AForm.Handle);
      FormWindow:=PGdkWindowPrivate(FormWidget^.window);
      if FormWindow<>nil then begin
        WindowDesktop := GDK_WINDOW_GET_DESKTOP(FormWindow);
        // this prevents the window from appearing on a different desktop
        // which could be undesirable.

        // check if the window is on all desktops or is on the current desktop
        if (WindowDesktop < 0) or (WindowDesktop = GDK_GET_CURRENT_DESKTOP) then
        begin
          GDK_WINDOW_ACTIVATE(FormWindow);
        end
        else begin
          // TODO: Figure out how to set the focus on an inactive desktop without
          //       bringing the window to the current desktop
        end;
      end;
{$ELSE}
      // this currently will bring the window to the current desktop and focus it
      gtk_window_present(PGtkWindow(hWnd));
{$ENDIF}
    end;
  end;
end;

function TGtkWidgetSet.SetMapMode(DC: HDC; fnMapMode : Integer): Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  Result := Integer(False);
  if not IsValidDC(DC) then Exit(0);
  DevCtx.MapMode := fnMapMode;
  Result := Integer(True);
end;

function TGTKWidgetSet.SetParent(hWndChild: HWND; hWndParent: HWND): HWND;
var
  Fixed: PGtkWidget;
  LCLObject: TObject;
begin
  Result := GetParent(hWndChild);

  if Result = hWndParent then
    Exit;

  // for window we need to move it content to HBox
  if GTK_IS_WINDOW(PGtkWidget(hWndChild)) then
  begin
    LCLObject := GetLCLObject(PGtkWidget(hWndChild));
    if LCLObject <> nil then
      Controls.RecreateWnd(TWinControl(LCLObject));
    Exit;
  end;

  if Result <> 0 then
  begin
    // unparent first
    gtk_widget_ref(PGtkWidget(hWndChild));
    if GTK_IS_CONTAINER(Pointer(Result)) then
      gtk_container_remove(PGtkContainer(Result), PGtkWidget(hWndChild))
    else
      gtk_widget_unparent(PGtkWidget(hWndChild));
  end;

  Fixed := GetFixedWidget(PGtkWidget(hWndParent));
  if Fixed <> nil then
  begin
    FixedPutControl(Fixed, PGtkWidget(hWndChild), PGtkWidget(hWndChild)^.allocation.x, PGtkWidget(hWndChild)^.allocation.y);
    RegroupAccelerator(PGtkWidget(hWndChild));
  end
  else
    gtk_widget_set_parent(PGtkWidget(hWndChild), PGtkWidget(hWndParent));

  if Result <> 0 then
    gtk_widget_unref(PGtkWidget(hWndChild));
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.SetProp(Handle: hwnd; Str : PChar;
                              Data : Pointer) : Boolean;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetProp(Handle: hwnd; Str : PChar; Data : Pointer) : Boolean;
begin
  gtk_object_set_data(pGTKObject(handle),Str,data);
  Result:=true;
end;

{------------------------------------------------------------------------------
  Method: SetRectRgn
  Params:  aRGN: HRGN; X1, Y1, X2, Y2 : Integer
  Returns: True if the function succeeds

  Converts a region into a rectangular region with the specified coordinates.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetRectRgn(aRGN: HRGN; X1, Y1, X2, Y2 : Integer): Boolean;

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
  function TGtkWidgetSet.SetROPMode(Handle: hwnd; Str : PChar;
                              Data : Pointer) : Boolean;
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetROP2(DC: HDC; Mode: Integer) : Integer;
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
function TGtkWidgetSet.SetScrollInfo(Handle : HWND; SBStyle : Integer;
  ScrollInfo: TScrollInfo; bRedraw : Boolean): Integer;

  procedure SetRangeUpdatePolicy(Range: PGtkRange);
  var
    UpdPolicy: TGTKUpdateType;
  begin
    case ScrollInfo.nTrackPos of
      SB_POLICY_DISCONTINUOUS: UpdPolicy := GTK_UPDATE_DISCONTINUOUS;
      SB_POLICY_DELAYED:       UpdPolicy := GTK_UPDATE_DELAYED;
      else                     UpdPolicy := GTK_UPDATE_CONTINUOUS;
    end;
    gtk_range_set_update_policy(Range, UpdPolicy);
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

const
  POLICY: array[BOOLEAN] of TGTKPolicyType = (GTK_POLICY_NEVER, GTK_POLICY_ALWAYS);
var
  Adjustment: PGtkAdjustment;
  Layout: PgtkLayout;
  Scroll: PGTKWidget;
  IsScrollWindow: Boolean;
  IsScrollbarVis: boolean;
begin
  Result := 0;
  if (Handle = 0) then exit;

  {DebugLn(['TGtkWidgetSet.SetScrollInfo A Widget=',GetWidgetDebugReport(PGtkWidget(Handle)),' SBStyle=',SBStyle,
    ' ScrollInfo=[',
      'cbSize=',ScrollInfo.cbSize,
      ',fMask=',ScrollInfo.fMask,
      ',nMin=',ScrollInfo.nMin,
      ',nMax=',ScrollInfo.nMax,
      ',nPage=',ScrollInfo.nPage,
      ',nPos=',ScrollInfo.nPos,
      ',nTrackPos=',ScrollInfo.nTrackPos,
      ']']);}

  Scroll := gtk_object_get_data(PGTKObject(Handle), odnScrollArea);
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := PGTKWidget(Handle);
    IsScrollWindow := GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type);
  end;

  if IsScrollWindow
  then begin
    Layout := GetFixedWidget(PGTKObject(Handle));
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
          if (ScrollInfo.fMask and SIF_RANGE) <> 0
          then gtk_layout_set_size(Layout, ScrollInfo.nMax - ScrollInfo.nMin, Layout^.height);
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
          if (ScrollInfo.fMask and SIF_RANGE) <> 0
          then gtk_layout_set_size(Layout, Layout^.Width, ScrollInfo.nMax - ScrollInfo.nMin);
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
    Adjustment^.lower := ScrollInfo.nMin;
    Adjustment^.upper := ScrollInfo.nMax;
  end;
  if (ScrollInfo.fMask and SIF_PAGE) <> 0
  then begin
    // 0 <= nPage <= nMax-nMin+1
    Adjustment^.page_size := ScrollInfo.nPage;
    Adjustment^.page_size := Min(Max(Adjustment^.page_size,0),
                                 Adjustment^.upper-Adjustment^.lower+1);
    Adjustment^.page_increment := (Adjustment^.page_size/6)+1;
  end;
  if (ScrollInfo.fMask and SIF_POS) <> 0
  then begin
    // nMin <= nPos <= nMax - Max(nPage-1,0)
    Adjustment^.value := ScrollInfo.nPos;
    Adjustment^.value := Max(Adjustment^.value,Adjustment^.lower);
    Adjustment^.value := Min(Adjustment^.value,
                              Adjustment^.upper-Max(Adjustment^.page_size-1,0));
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

  {DebugLn('');
  DebugLn('[TGtkWidgetSet.SetScrollInfo] Result=',Result,
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
    if IsScrollWindow
    then begin
      case SBStyle of
        SB_HORZ:
          gtk_object_set(PGTKObject(Scroll),'hscrollbar_policy',[POLICY[IsScrollbarVis],nil]);
        SB_VERT:
          gtk_object_set(PGTKObject(Scroll),'vscrollbar_policy',[POLICY[IsScrollbarVis],nil]);
      end;
    end
    else
      gtk_widget_queue_draw(PGTKWidget(Scroll));

(*
    DebugLn('TGtkWidgetSet.SetScrollInfo:' +
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
function TGtkWidgetSet.SetSysColors(cElements: Integer; const lpaElements;
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
    //DebugLn(Format('Trace:[TGtkWidgetSet.SetSysColor] Index %d (%8x) --> %8x', [PLongArray(lpaElements)^[n], SysColorMap[PLongArray(lpaElements)^[n]], PLongArray(lpaRgbValues)^[n]]));
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
function TGtkWidgetSet.SetTextCharacterExtra(DC : hdc; nCharExtra : Integer):Integer;
var
  DevCtx: TGtkDeviceContext absolute DC;
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
function TGtkWidgetSet.SetTextColor(DC: HDC; Color: TColorRef): TColorRef;
var
  DevCtx: TGtkDeviceContext absolute DC;
begin
  //DebugLn(Format('trace:> [TGtkWidgetSet.SetTextColor] DC: 0x%x Color: %8x', [Integer(DC), Color]));
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
  //DebugLn(Format('trace:< [TGtkWidgetSet.SetTextColor] DC: 0x%x Color: %8x --> %8x', [Integer(DC), Color, Result]));
end;

function TGtkWidgetSet.SetViewPortExtEx(DC: HDC; XExtent, YExtent : Integer; OldSize: PSize): Boolean;
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

function TGtkWidgetSet.SetViewPortOrgEx(DC: HDC; NewX, NewY: Integer; OldPoint: PPoint): Boolean;
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

function TGtkWidgetSet.SetWindowExtEx(DC: HDC; XExtent, YExtent: Integer; OldSize: PSize): Boolean;
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
end;

{------------------------------------------------------------------------------
  Procedure: SetWindowLong
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetWindowLong(Handle: HWND; Idx: Integer;
  NewLong: PtrInt): PtrInt;
var
  Data: Pointer;
  WidgetInfo: PWidgetInfo;
begin
  //TODO: Finish this;
  //DebugLn(Format('Trace:> [TGtkWidgetSet.SETWINDOWLONG] HWND: 0x%x, idx: 0x%x(%d), Value: 0x%x(%d)', [Handle, idx, idx, newlong, newlong]));
  Result:=0;
  Data := Pointer(NewLong);

  case idx of
    GWL_WNDPROC :
      begin
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.WndProc := NewLong;
      end;
    GWL_HINSTANCE :
      begin
        gtk_object_set_data(pgtkobject(Handle),'HINSTANCE',Data);
      end;
    GWL_HWNDPARENT :
      begin
        gtk_object_set_data(pgtkobject(Handle),'HWNDPARENT',Data);
      end;
    GWL_STYLE :
      begin
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.Style := NewLong;
      end;
    GWL_EXSTYLE :
      begin
        WidgetInfo := GetWidgetInfo(Pointer(Handle));
        if WidgetInfo <> nil then
          WidgetInfo^.ExStyle := NewLong;
      end;
    GWL_USERDATA :
      begin
        gtk_object_set_data(pgtkobject(Handle),'Userdata',Data);
      end;
    GWL_ID :
      begin
        gtk_object_set_data(pgtkobject(Handle),'ID',Data);
      end;
  end; //case
  //DebugLn(Format('Trace:< [TGtkWidgetSet.SETWINDOWLONG] HWND: 0x%x, idx: 0x%x(%d), Value: 0x%x(%d) --> 0x%x(%d)', [Handle, idx, idx, newlong, newlong, Result, Result]));
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.SetWindowOrgEx(DC : HDC; NewX, NewY : Integer;
    OldPoint: PPoint) : Boolean;

  Sets the DC offset for the specified device context.
 ------------------------------------------------------------------------------}
function TGtkWidgetSet.SetWindowOrgEx(DC : HDC; NewX, NewY : Integer;
  OldPoint: PPoint) : Boolean;
var
  DevCtx: TGtkDeviceContext absolute DC;
  OldP: TPoint;
begin
  //DebugLn('[TGtkWidgetSet.SetWindowOrgEx] ',NewX,' ',NewY);
  GetWindowOrgEx(DC, @OldP);
  Result := MoveWindowOrgEx(DC, -NewX - OldP.X, -NewY - OldP.Y);
  if OldPoint <> nil then
    OldPoint^ := OldP;
end;

{------------------------------------------------------------------------------
  function TGtkWidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND;
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
function TGtkWidgetSet.SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND;
  X, Y, cx, cy: Integer; uFlags: UINT): Boolean;

  procedure SetZOrderOnFixedWidget(Widget, FixedWidget: PGtkWidget);
  var
    OldListItem: PGList;
    AfterWidget: PGtkWidget;
    AfterListItem: PGList;
  begin
    OldListItem:=FindFixedChildListItem(PGtkFixed(FixedWidget),Widget);
    if OldListItem=nil then begin
      DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: Widget not on parents fixed widget');
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
      DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: hWndInsertAfter=0');
      exit;
    end else begin
      // hWndInsertAfter
      AfterWidget:=PGtkWidget(hWndInsertAfter);
      AfterListItem:=FindFixedChildListItem(PGtkFixed(FixedWidget),AfterWidget);
      //debugln('AfterWidget=',GetWidgetDebugReport(AfterWidget));
    end;
    if (AfterListItem=nil) and (AfterWidget<>nil) then begin
      DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget WARNING: AfterWidget not on parents fixed widget');
      exit;
    end;
    if (OldListItem=AfterListItem) or (OldListItem^.next=AfterListItem) then
    begin
      {$IFDEF EnableGtkZReordering}
      DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget Hint: Already there');
      {$ENDIF}
      exit;
    end;
    //DebugLn('TGtkWidgetSet.SetWindowPos Moving GList entry');

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
      DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget resize ..');
      gtk_widget_queue_resize(FixedWidget);
      AfterListItem:=PGtkFixed(FixedWidget)^.children;
      while AfterListItem<>nil do begin
        AfterWidget:=GetFixedChildListWidget(AfterListItem);
        DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnFixedWidget A ',GetWidgetDebugReport(AfterWidget));
        AfterListItem:=AfterListItem^.next;
      end;
    end;
    {$ENDIF}
  end;

  procedure SetZOrderOnLayoutWidget(Widget, LayoutWidget: PGtkWidget);
  begin
    //DebugLn('TGtkWidgetSet.SetWindowPos.SetZOrderOnLayoutWidget Not implemented: ZOrdering .. on ',GetWidgetDebugReport(LayoutWidget));
  end;

var
  Widget: PGTKWidget;
  FixedWidget: PGtkWidget;
begin
  Result:=false;
  Widget:=PGtkWidget(hWnd);
  {DebugLn('[TGtkWidgetSet.SetWindowPos] ',GetWidgetDebugReport(Widget),
    ' Top=',hWndInsertAfter=HWND_TOP,
    ' SWP_NOZORDER=',(SWP_NOZORDER and uFlags)<>0,
    ' SWP_NOSIZE=',(SWP_NOSIZE and uFlags)<>0,
    ' SWP_NOMOVE=',(SWP_NOMOVE and uFlags)<>0,
    '');}
  if GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then begin
    { case hWndInsertAfter of
        HWND_BOTTOM: ;  //gdk_window_lower(Widget^.Window);
        HWND_TOP:    gtk_window_set_position(PGtkWindow(hWnd),GTK_WIN_POS_CENTER);
                    //gdk_window_raise(Widget^.Window);
      end;
    }
  end else if (SWP_NOZORDER and uFlags)=0 then begin
    FixedWidget:=Widget^.Parent;
    if FixedWidget=nil then exit;

    //DebugLn('TGtkWidgetSet.SetWindowPos ZOrdering .. on ',GetWidgetDebugReport(FixedWidget));
    if GtkWidgetIsA(FixedWidget,GTK_Fixed_Get_Type) then begin
      // parent's client area is a gtk_fixed widget
      SetZOrderOnFixedWidget(Widget,FixedWidget);
    end else if GtkWidgetIsA(FixedWidget,GTK_Layout_Get_Type) then begin
      // parent's client area is a gtk_layout widget
      SetZOrderOnLayoutWidget(Widget,FixedWidget);
    end else begin
      //DebugLn('TGtkWidgetSet.SetWindowPos Not implemented: ZOrdering .. on ',GetWidgetDebugReport(FixedWidget));
      exit;
    end;
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  Function: ShowCaret
  Params:  none
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ShowCaret(hWnd: HWND): Boolean;
var
  GTKObject: PGTKObject;
begin
  //DebugLn(Format('Trace:> [TGtkWidgetSet.ShowCaret] HWND: 0x%x', [hWnd]));

  GTKObject := PGTKObject(HWND);
  Result := GTKObject <> nil;

  if Result
  then begin
    if gtk_type_is_a(gtk_object_type(GTKObject), GTKAPIWidget_GetType)
    then begin
      GTKAPIWidget_ShowCaret(PGTKAPIWidget(GTKObject));
    end
    else begin
      Result := False;
    end;
  end
  else DebugLn('WARNING: [TGtkWidgetSet.ShowCaret] Got null HWND');

  //DebugLn(Format('Trace:< [TGtkWidgetSet.ShowCaret] HWND: 0x%x --> %s', [hWnd, BOOL_TEXT[Result]]));
end;

{------------------------------------------------------------------------------
  Function:  ShowScrollBar
  Params:  Wnd, wBar, bShow
  Returns: Nothing


 ------------------------------------------------------------------------------}
function TGtkWidgetSet.ShowScrollBar(Handle: HWND; wBar: Integer;
  bShow: Boolean): Boolean;
var
  NewPolicy: Integer;
  Scroll: PGtkWidget;
  IsScrollWindow: Boolean;
begin
  //DebugLn('trace:[TGtkWidgetSet.ShowScrollBar]');
  Result := (Handle <> 0);
  if not Result then exit;
  
  Scroll := PGtkWidget(gtk_object_get_data(PGTKObject(Handle), odnScrollArea));
  if GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type)
  then begin
    IsScrollWindow := True;
  end
  else begin
    Scroll := PGTKWidget(Handle);
    IsScrollWindow := GtkWidgetIsA(Scroll, gtk_scrolled_window_get_type);
  end;

  //DebugLn(['TGtkWidgetSet.ShowScrollBar ',GetWidgetDebugReport(Scroll),' wBar=',wBar,' bShow=',bShow]);
  if IsScrollWindow then begin
    if wBar in [SB_BOTH, SB_HORZ] then begin
      //DebugLn(['TGtkWidgetSet.ShowScrollBar ',GetWidgetDebugReport(Widget),' bShow=',bShow]);
      if bShow then
        NewPolicy:=GTK_POLICY_ALWAYS
      else
        NewPolicy:=GTK_POLICY_NEVER;
      gtk_object_set(PGTKObject(Scroll), 'hscrollbar_policy', [NewPolicy,nil]);
    end;
    if wBar in [SB_BOTH, SB_VERT] then begin
      if bShow then
        NewPolicy:=GTK_POLICY_ALWAYS
      else
        NewPolicy:=GTK_POLICY_NEVER;
      gtk_object_set(PGTKObject(Scroll), 'vscrollbar_policy', [NewPolicy,nil]);
    end;
  end
  else begin
    if (wBar = SB_CTL)
    and gtk_type_is_a(gtk_object_type(PGTKObject(Handle)),gtk_widget_get_type)
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
function TGtkWidgetSet.ShowWindow(hWnd: HWND; nCmdShow: Integer): Boolean;
var
  GtkWindow: PGtkWindow;
  Widget: PGtkWidget;
begin
  Result:=false;
  Widget := PGtkWidget(hWND);
  if Widget = nil then
    RaiseGDBException('TGtkWidgetSet.ShowWindow  hWnd is nil');

  if not GtkWidgetIsA(Widget,GTK_TYPE_WINDOW) then
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

  GtkWindow:=PGtkWindow(hWnd);
  if GtkWindow=nil then
    RaiseGDBException('TGtkWidgetSet.ShowWindow  hWnd is nil');
  if not GtkWidgetIsA(PGtkWidget(GtkWindow),GTK_TYPE_WINDOW) then
    RaiseGDBException('TGtkWidgetSet.ShowWindow  hWnd is not a gtkwindow');

  {$IFDEF Gtk2}
    // Implemented on gtk2winapi.inc
    // This ifdef is necessary otherwise the gtk2 interface wont compile
  {$ELSE}
  case nCmdShow of

  SW_SHOWNORMAL:
    begin
      {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
      gdk_window_show(PgtkWidget(GtkWindow)^.Window);
      {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}
    end;

  SW_HIDE:
    begin
      gdk_window_hide(PgtkWidget(GtkWindow)^.Window);
    end;

  SW_MINIMIZE:
    begin
      GDK_WINDOW_MINIMIZE(PGdkWindowPrivate(PgtkWidget(GtkWindow)^.Window));
    end;
  SW_SHOWMAXIMIZED:
    begin
      GDK_WINDOW_MAXIMIZE(PGdkWindowPrivate(PgtkWidget(GtkWindow)^.Window));
    end;

  end;
  {$ENDIF}
  
  Result:=true;
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
function TGtkWidgetSet.StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer;
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
function TGtkWidgetSet.StretchMaskBlt(DestDC: HDC; X, Y, Width, Height: Integer;
  SrcDC: HDC; XSrc, YSrc, SrcWidth, SrcHeight: Integer; Mask: HBITMAP;
  XMask, YMask: Integer; Rop: DWORD): Boolean;
begin
  Result:=StretchCopyArea(DestDC,X,Y,Width,Height,
                          SrcDC,XSrc,YSrc,SrcWidth,SrcHeight,
                          Mask,XMask,YMask,
                          Rop);
end;

function TGTKWidgetSet.SystemParametersInfo(uiAction: DWord; uiParam: DWord;
  pvParam: Pointer; fWinIni: DWord): LongBool;
begin
  Result:=False;
  Case uiAction of
    SPI_GETWORKAREA: begin
      TRect(pvParam^):=Bounds(GetSystemMetrics(SM_XVIRTUALSCREEN),
                              GetSystemMetrics(SM_YVIRTUALSCREEN),
                              GetSystemMetrics(SM_CXVIRTUALSCREEN),
                              GetSystemMetrics(SM_CYVIRTUALSCREEN));
      Result:=True;
    end;
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
function TGtkWidgetSet.TextOut(DC: HDC; X,Y : Integer; Str : Pchar;
  Count: Integer) : Boolean;
{$IfDef GTK2}
begin
  DebugLn('TGtkWidgetSet.TextOut ToDo');
  Result:=false;
end;
{$ELSE}
var
  DevCtx: TGtkDeviceContext absolute DC;

  aRect : TRect;
  txtpt : TPoint;
  sz : TSize;
  UseFont : PGDKFont;
  Underline,
  StrikeOut : Boolean;
  DCOrigin: TPoint;

  TempPen : hPen;
  LogP : TLogPen;
  Points : array[0..1] of TSize;
  
  lbearing, rbearing, width, ascent,descent: LongInt;

begin
  if not IsValidDC(DC) then Exit(False);
  
  if Count <= 0 then Exit(True);

  UseFont := GetGtkFont(DevCtx);

  if (DevCtx.CurrentFont = nil) or (DevCtx.CurrentFont^.GDIFontObject = nil)
  then begin
    Underline := False;
    StrikeOut := False;
  end
  else begin
    Underline := DevCtx.CurrentFont^.LogFont.lfUnderline <> 0;
    StrikeOut := DevCtx.CurrentFont^.LogFont.lfStrikeOut <> 0;
  end;

  if DevCtx.HasTransf then
    DevCtx.TransfPoint(X, Y);

  DCOrigin := DevCtx.Offset;
  descent:=0;
  gdk_text_extents(UseFont, Str, Count, @lbearing, @rBearing, @width, @ascent, @descent);
  sz.cx := width;
  Sz.cY := ascent+descent;
  aRect := Rect(X+DCOrigin.X,Y+DCOrigin.Y,X + Sz.CX, Sz.CY);

  FillRect(DC, aRect, hBrush(PtrUInt(DevCtx.GetBrush)));
  UpdateDCTextMetric(DevCtx);
  TxtPt.X := X;
  TxtPt.Y := Y + DevCtx.DCTextMetric.TextMetric.tmAscent;
  DevCtx.SelectTextProps;

  {$IFDEF DebugGDK}BeginGDKErrorTrap;{$ENDIF}
  gdk_draw_text(DevCtx.Drawable, UseFont, DevCtx.GC, TxtPt.X+DCOrigin.X, TxtPt.Y+DCOrigin.Y, Str, Count);
  {$IFDEF DebugGDKTraps}EndGDKErrorTrap;{$ENDIF}

  if not(Underline or StrikeOut) then Exit(True);

  {Create & select pen of font color}
  LogP.lopnStyle := PS_SOLID;
  LogP.lopnWidth.X := 1;
  LogP.lopnColor := GetTextColor(DC);
  TempPen := SelectObject(DC, CreatePenIndirect(LogP));

  {Get line(s) horizontal position(s)}
  Points[0].cX := X;
  Points[1].cX := X + sz.cX;

  {Draw line(s)}
  if Underline
  then begin
    with DevCtx.DCTextMetric.TextMetric do
      Points[0].cY := Y + 2 + tmHeight - tmDescent;
      
    Points[1].cY := Points[0].cY;
    Polyline(DC, PPoint(@Points[0]), 2);
  end;

  if StrikeOut
  then begin
    Points[0].cY := Y + 2 + (TxtPt.Y - Y) div 2;
    Points[1].cY := Points[0].cY;
    Polyline(DC, PPoint(@Points[0]), 2);
  end;

  DeleteObject(SelectObject(DC, TempPen));

  Result := True;
end;
{$EndIf}

{------------------------------------------------------------------------------
  Function: WindowFromPoint
  Params: Point: Specifies the x and y Coords
  Returns: The handle of the gtkwidget.  If none exist, then NULL is returned.

 ------------------------------------------------------------------------------}
function TGtkWidgetSet.WindowFromPoint(APoint: TPoint): HWND;
var
  ev: TgdkEvent;
  Window: PgdkWindow;
  Widget: PgtkWidget;
  p: TPoint;
begin
  // return cached value to prevent heavy gdk_window_at_pointer call
  if (APoint = LastWFPMousePos) and GTK_IS_OBJECT(Pointer(LastWFPResult)) then
    Exit(LastWFPResult);
  Result := 0;

  // !!!gdk_window_at_pointer changes the coordinates!!!
  // -> using local variable p
  p := APoint;
  Window := gdk_window_at_pointer(@p.x, @p.Y);
  if window <> nil then
  begin
    FillChar(ev, SizeOf(ev), 0);
    ev.any.window := Window;
    Widget := gtk_get_event_widget(@ev);
    Result := PtrUInt(Widget);
  end;
  // disconnect old handler
  if GTK_IS_OBJECT(Pointer(LastWFPResult)) then
  begin
    {$IFDEF gtk1}
    gtk_signal_disconnect_by_func(GPointer(LastWFPResult),
                     TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
    {$ELSE}
    g_signal_handlers_disconnect_by_func(GPointer(LastWFPResult),
                     TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
    {$ENDIF}
  end;
  LastWFPMousePos := APoint;
  LastWFPResult := Result;
  // connect handler
  if LastWFPResult <> 0 then
    {$IFDEF gtk1}
    gtk_signal_connect(PGtkObject(LastWFPResult), 'destroy',
      TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
    {$else}
    g_signal_connect(GPointer(LastWFPResult), 'destroy',
                     TGTKSignalFunc(@DestroyWindowFromPointCB), nil);
    {$endif}
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

procedure TGtkWidgetSet.InitializeCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  New(ACritSec);
  System.InitCriticalSection(ACritSec^);
  CritSection:=TCriticalSection(ACritSec);
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

procedure TGtkWidgetSet.EnterCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.EnterCriticalsection(ACritSec^);
end;

{var
  Crit,
  tmp : ppthread_mutex_t;
begin
  New(Crit);
  If CritSection <> 0 then
    Try
      Crit^ := ppthread_mutex_t(CritSection)^;
    except
      begin
        CritSection := Longint(Crit);
        exit;
      end;
    end;
  pthread_mutex_lock(Crit^);
  tmp := ppthread_mutex_t(CritSection);
  CritSection := Longint(Crit);
  Dispose(Tmp);
end;}
{$Else}
begin
end;
{$EndIf}

procedure TGtkWidgetSet.LeaveCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.LeaveCriticalsection(ACritSec^);
end;
{var
  Crit,
  tmp : ppthread_mutex_t;
begin
  New(Crit);
  If CritSection <> 0 then
    Try
      Crit^ := ppthread_mutex_t(CritSection)^;
    except
      begin
        CritSection := Longint(Crit);
        exit;
      end;
    end;
  pthread_mutex_unlock(Crit^);
  tmp := ppthread_mutex_t(CritSection);
  CritSection := Longint(Crit);
  Dispose(Tmp);
end;}
{$Else}
begin
end;
{$EndIf}

procedure TGtkWidgetSet.DeleteCriticalSection(var CritSection: TCriticalSection);
{$IfDef pthread}
var
  ACritSec: System.PRTLCriticalSection;
begin
  ACritSec:=System.PRTLCriticalSection(CritSection);
  System.DoneCriticalsection(ACritSec^);
  Dispose(ACritSec);
  CritSection:=0;
end;
{var
  Crit,
  tmp : ppthread_mutex_t;
begin
  New(Crit);
  If CritSection <> 0 then
    Try
      Crit^ := ppthread_mutex_t(CritSection)^;
    except
      begin
        CritSection := Longint(Crit);
        exit;
      end;
    end;
  pthread_mutex_destroy(Crit^);
  Dispose(Crit);
  tmp := ppthread_mutex_t(CritSection);
  CritSection := 0;
  Dispose(Tmp);
end;}
{$Else}
begin
end;
{$EndIf}

{$IfDef ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$EndIf}




{%MainUnit ../osprinters.pas}
{
  Implementation for qtlcl printing
  Author: Zeljan Rikalo

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
 }
Uses InterfaceBase, LCLIntf;

{.$DEFINE UsePrinterSupportedPapers}

const
  DEFAULT_PAPER_NAME = 'A4';

{ TQtPrinters }

function TQtPrinters.GetPaperSize(const Str: String): QtLCLPrinterPageSize;
var
  i: Integer;
begin
  DoInitializeCachePapers;
  i := IndexOfPaper(Str);
  if i>=0 then
    result := FPapers[i].PageSize
  else
    Result := {$IFDEF LCLQt5}QPagedPaintDeviceA4{$ELSE}QPrinterA4{$ENDIF};
end;

procedure TQtPrinters.BeginPage;
begin
  if Assigned(Canvas) then
    Canvas.Handle := HDC(QtDefaultPrinter.PrinterContext);
end;

procedure TQtPrinters.EndPage;
begin
  QtDefaultPrinter.PrinterContext;

  if Assigned(Canvas) then Canvas.Handle := 0;
  QtDefaultPrinter.endDoc;
end;

procedure TQtPrinters.EnumQPrinters(Lst: TStrings);
var
  i: Integer;
  PrnInfo: QPrinterInfoH;
  {$IFDEF LCLQt5}
  AList: QStringListH;
  DefaultPrn: WideString;
  {$ELSE}
  Prntr: QPrinterInfoH;
  PrnList: TPtrIntArray;
  {$ENDIF}
  PrnName: WideString;
begin
  inherited DoEnumPrinters(Lst);
  {$IFDEF LCLQt5}
  Lst.Clear;
  AList := QStringList_create();
  PrnInfo := QPrinterInfo_create();
  try
    QPrinterInfo_availablePrinterNames(AList);
    QPrinterInfo_defaultPrinter(PrnInfo);
    QPrinterInfo_printerName(PrnInfo, @DefaultPrn);
    for i := 0 to QStringList_size(AList) - 1 do
    begin
      QStringList_at(AList, @PrnName, I);
      if DefaultPrn = PrnName then
        Lst.InsertObject(0, PrnName{%H-}, nil)
      else
        Lst.AddObject(PrnName{%H-}, nil);
    end;
  finally
    QPrinterInfo_destroy(PrnInfo);
    QStringList_destroy(AList);
  end;
  {$ELSE}
  PrnInfo := QPrinterInfo_create();
  try
    PrnInfo := QPrinterInfo_create();
    Lst.Clear;
    QPrinterInfo_availablePrinters(@PrnList);
    for i := Low(PrnList) to High(PrnList) do
    begin
      Prntr := QPrinterInfoH(PrnList[i]);
      if Assigned(Prntr) and not QPrinterInfo_isNull(Prntr) then
      begin
        QPrinterInfo_printerName(Prntr, @PrnName);
        if QPrinterInfo_isDefault(Prntr) then
          Lst.InsertObject(0, PrnName{%H-}, Prntr)
        else
          Lst.AddObject(PrnName{%H-}, Prntr);
      end;
    end;
  finally
    QPrinterInfo_destroy(PrnInfo);
  end;
  {$ENDIF}
end;

function TQtPrinters.GetColorMode: QPrinterColorMode;
begin
  Result := QtDefaultPrinter.ColorMode;
end;

function TQtPrinters.GetFullPage: Boolean;
begin
  Result := QtDefaultPrinter.FullPage;
end;

function TQtPrinters.GetPageOrder: QPrinterPageOrder;
begin
  Result := QtDefaultPrinter.PageOrder;
end;

procedure TQtPrinters.SetColorMode(const AValue: QPrinterColorMode);
begin
  QtDefaultPrinter.ColorMode := AValue;
end;

procedure TQtPrinters.SetFullPage(const AValue: Boolean);
begin
  QtDefaultPrinter.FullPage := AValue;
end;

procedure TQtPrinters.SetPageOrder(const AValue: QPrinterPageOrder);
begin
  QtDefaultPrinter.PageOrder := AValue;
end;

procedure TQtPrinters.CachePapers(OnlySupportedByPrinter: boolean);
const
  {$IFDEF LCLQt5}
  ArrPapers: array[0..QPagedPaintDeviceCustom] of string[12] = (
  {$ELSE}
  ArrPapers: array[QPrinterA4..QPrinterCustom] of string[12] = (
  {$ENDIF}
    'A4',       'B5',         'Letter',     'Legal',      'Executive',
    'A0',       'A1',         'A2',         'A3',         'A5',
    'A6',       'A7',         'A8',         'A9',         'B0',
    'B1',       'B10',        'B2',         'B3',         'B4',
    'B6',       'B7',         'B8',         'B9',         'C5E',
    'Comm10E',  'DLE',        'Folio',      'Ledger',     'Tabloid',
    'Custom');
var
  PrinterList: TStringList;
  Info: QPrinterInfoH;
  Arr: TPtrIntArray;
  {$IFDEF LCLQt5}
  APrnName: WideString;
  {$ENDIF}
  CurrentPageSize, PageSize: QtLCLPrinterPageSize;
  Index: Integer;
  customPaperAdded: boolean;

  procedure Add(PaperName: string; PgSize: QtLCLPrinterPageSize);
  var
    i: Integer;
  begin
    {$ifdef UsePrinterSupportedPapers}
    // Apparently when Qt retrieve the papers from the printer source engine
    // any printer supported paper that does not match a Qt known paper it is
    // assigned a PageSize of 30 (Custom/Unknown).
    //
    // TODO: Find out if it is possible to get the dimensions of such custom
    //       papers, in such case assign to every custom paper a number and
    //       report them.
    //
    // In the mean time, in order to not present the user with multiple
    // custom papers, just one is allowed.
    {$endif}
    if (pgSize=30) and customPaperAdded then
      exit;
    i := Length(FPapers);
    SetLength(FPapers, i+1);
    FPapers[i].PaperName := PaperName;

    //CustomPageSize should be automatically set by setting different paper size
    //than known paper size. Qt4 asserts when CustomPageSize is directly setted up.
    {$IFDEF LCLQt}
    if (pgSize > 30) then
    {$ENDIF}
      QtDefaultPrinter.PageSize := PgSize;
    FPapers[i].PageRect := QtDefaultPrinter.PageRect;
    FPapers[i].PaperRect := QtDefaultPrinter.PaperRect;
    if PaperName=DEFAULT_PAPER_NAME then
      FDefaultPaperIndex := i;
    if pgSize=30 then
      customPaperAdded := true;
    //DebugLn('Cached: %20s PaperRect=%s PageRect=%s',[PaperName, dbgs(FPapers[i].PaperRect), dbgs(FPapers[i].PageRect)]);
  end;

  procedure AddAll;
  var
    i: Integer;
    {$IFDEF LCLQt5}
    oldPageSize: QPagedPaintDevicePageSize;
    {$ENDIF}
  begin
    {$IFDEF LCLQt5}
    oldPageSize := QtDefaultPrinter.PageSize;
    for i:=QPagedPaintDeviceA4 to QPagedPaintDeviceCustom do
      Add(ArrPapers[i], i);
    QtDefaultPrinter.PageSize := oldPageSize;
    {$ELSE}
    for i:=QPrinterA4 to QPrinterCustom do
      Add(ArrPapers[i], i);
    {$ENDIF}
  end;

begin
  customPaperAdded := false;
  SetLength(FPapers, 0);
  if not OnlySupportedByPrinter then
  begin
    AddAll;
    exit;
  end;

  PrinterList := TStringList.Create;
  try
    CurrentPageSize := QtDefaultPrinter.PageSize;

    EnumQPrinters(PrinterList);
    Index := PrinterList.IndexOf(UTF8Encode(QtDefaultPrinter.PrinterName));
    if Index>=0 then
    begin
      {$IFDEF LCLQt5}
      Info := QPrinterInfo_create();
      APrnName := PrinterList{%H-}[Index];
      QPrinterInfo_printerInfo(Info, @APrnName);
      {$ELSE}
      Info := QPrinterInfoH(PrinterList.Objects[Index]);
      {$ENDIF}
      QPrinterInfo_supportedPaperSizes(Info, @Arr);
      {$IFDEF LCLQt5}
      QPrinterInfo_destroy(Info);
      {$ENDIF}
      for PageSize in Arr do
        {$IFDEF LCLQt5}
        for Index := QPagedPaintDeviceA4 to QPagedPaintDeviceCustom do
        {$ELSE}
        for Index := QPrinterA4 to QPrinterCustom do
        {$ENDIF}
        begin
          if Index=PageSize then
            Add(ArrPapers[Index], PageSize);
        end;
    end else
      AddAll;
  finally
    QtDefaultPrinter.PageSize := CurrentPageSize;
    PrinterList.Free;
  end;
end;

function TQtPrinters.IndexOfPaper(const Paper: string; RetDefault: boolean): Integer;
var
  i: Integer;
begin
  result := -1;
  DoInitializeCachePapers;
  for i:=0 to Length(FPapers)-1 do
  begin
    if FPapers[i].PaperName=Paper then begin
      result := i;
      exit;
    end;
  end;
  if RetDefault and (Length(FPapers)>0) then
    result := FDefaultPaperIndex;
end;

function TQtPrinters.IndexOfPageSize(const PageSize: QtLCLPrinterPageSize): Integer;
var
  i: Integer;
begin
  result := -1;
  DoInitializeCachePapers;
  for i:=0 to Length(FPapers)-1 do begin
    if FPapers[i].PageSize=PageSize then begin
      result := i;
      exit;
    end;
  end;
  if Length(FPapers)>0 then
    result := FDefaultPaperIndex;
end;

constructor TQtPrinters.Create;
begin
  inherited Create;
  FCachePapersInitialized := False;
end;

procedure TQtPrinters.DoDestroy;
begin
  FPapers := nil;
  QtDefaultPrinter.endDoc;
  inherited DoDestroy;
end;

procedure TQtPrinters.DoInitializeCachePapers;
begin
  if not FCachePapersInitialized then
  begin
    FCachePapersInitialized := True;
    CachePapers(false);
  end;
end;

function TQtPrinters.Write(const Buffer; Count: Integer; out Written: Integer): Boolean;
begin
  Result := False;
  CheckRawMode(True);
  Written := 0;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.Write(): Raw mode is not yet supported');
  {$ENDIF}
end;

procedure TQtPrinters.RawModeChanging;
begin
  inherited RawModeChanging;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.RawModeChanging(): Raw mode is not yet supported');
  {$ENDIF}
end;

procedure TQtPrinters.Validate;
var
  P: String;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.Validate()');
  {$ENDIF}
  DoInitializeCachePapers;
  // if target paper is not supported, use the default
  P := DoGetPaperName;
  if PaperSize.SupportedPapers.IndexOf(P) = -1 then
    DoSetPaperName(DoGetDefaultPaperName);
end;

function TQtPrinters.GetXDPI: Integer;
begin
  Result :=  QtDefaultPrinter.Resolution;
  
  {DO NOT INITIALIZE PRINTERCONTEXT HERE , ASK DIRECTLY QPAINTDEVICE !}
  if (Printers.Count>0) and not RawMode then
    Result := QPaintDevice_logicalDpiX(QtDefaultPrinter.Handle);
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.GetXDPI() Result=',IntToStr(Result));
  {$ENDIF}
end;

function TQtPrinters.GetYDPI: Integer;
begin
  Result := QtDefaultPrinter.Resolution;
  
  {DO NOT INITIALIZE PRINTERCONTEXT HERE , ASK DIRECTLY QPAINTDEVICE !}
  if (Printers.Count>0) and not RawMode then
     Result := QPaintDevice_logicalDpiY(QtDefaultPrinter.Handle);
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.GetYDPI() Result=',IntToStr(Result));
  {$ENDIF}
end;

procedure TQtPrinters.DoBeginDoc;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoBeginDoc()');
  {$ENDIF}
  QtDefaultPrinter.DocName := UTF8ToUTF16(Title);
  BeginPage;
end;

procedure TQtPrinters.DoNewPage;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoNewPage()');
  {$ENDIF}
  QtDefaultPrinter.PrinterContext;
  QtDefaultPrinter.NewPage;
end;

procedure TQtPrinters.DoEndDoc(aAborted: Boolean);
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoEndDoc()');
  {$ENDIF}
  inherited DoEndDoc(aAborted);
  EndPage;
end;

procedure TQtPrinters.DoAbort;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoAbort()');
  {$ENDIF}
  inherited DoAbort;
  if QtDefaultPrinter.Abort then
    QtDefaultPrinter.endDoc;
end;

procedure TQtPrinters.DoEnumPrinters(Lst: TStrings);
var
  Str: WideString;
  i: Integer;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoEnumPrinters()');
  {$ENDIF}
  DoInitializeCachePapers;
  Str := QtDefaultPrinter.PrinterName;
  EnumQPrinters(Lst);
  i := Lst.IndexOf(Str{%H-});
  if i > 0 then
    Lst.Move(i, 0);
end;

procedure TQtPrinters.DoResetPrintersList;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoResetPrintersList()');
  {$ENDIF}
  inherited DoResetPrintersList;
end;

procedure TQtPrinters.DoEnumPapers(Lst: TStrings);
var
  Paper: TPaperRec;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoEnumPapers()');
  {$ENDIF}
  DoInitializeCachePapers;
  Lst.Clear;
  for Paper in FPapers do
    Lst.Add(Paper.PaperName);
end;

function TQtPrinters.DoGetPaperName: string;
var
  i: Integer;
begin
  DoInitializeCachePapers;
  i := IndexOfPageSize(QtDefaultPrinter.PageSize);
  if i>=0 then
    result := FPapers[i].PaperName
  else
    result := DEFAULT_PAPER_NAME;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetPaperName() Result=',Result);
  {$ENDIF}
end;

function TQtPrinters.DoGetDefaultPaperName: string;
begin
  DoInitializeCachePapers;
  if Length(FPapers)>0 then
    result := FPapers[FDefaultPaperIndex].PaperName
  else
    result := DEFAULT_PAPER_NAME;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetDefaultPaperName() Result=',Result);
  {$ENDIF}
end;

procedure TQtPrinters.DoSetPaperName(aName: string);
var
  O: TPrinterOrientation;
  i: Integer;
begin
  DoInitializeCachePapers;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoSetPaperName() AName=',AName);
  {$ENDIF}
  O := DoGetOrientation;
  i := IndexOfPaper(aName, false);
  if i >= 0 then
  begin
    QtDefaultPrinter.PageSize := FPapers[i].PageSize;
    DoSetOrientation(O);
  end else
    raise Exception.Create('TQtPrinters: Paper '+AName+' not supported.');
end;

function TQtPrinters.DoGetPaperRect(aName: string; var aPaperRc: TPaperRect
  ): Integer;
var
  i: Integer;
begin
  DoInitializeCachePapers;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetPaperRect() AName=', AName);
  {$ENDIF}
  Result := inherited DoGetPaperRect(aName,aPaperRc);
  i := IndexOfPaper(aName);
  if i >= 0 then
  begin
    {When we set QPrinter into FullPage, rect is not same
     on all platforms, this is fixed with qt-4.4}
    APaperRC.WorkRect := FPapers[i].PageRect;
    APaperRC.PhysicalRect := FPapers[i].PaperRect;
    Result := 1;
  end;
end;

function TQtPrinters.DoSetPrinter(aName: string): Integer;
var
  StrList: TStringList;
begin
  DoInitializeCachePapers;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoSetPrinter() aName=', aName);
  {$ENDIF}
  StrList := TStringList.Create;
  if (Printers.Count = 0) or (Printers.IndexOf(aName) = -1) then
    EnumQPrinters(StrList)
  else
    StrList.Assign(Printers);
  try
    Result := StrList.IndexOf(AName);
    if Result >= 0 then
    begin
      if not QtDefaultPrinter.PrinterActive then
      begin
        QtDefaultPrinter.PrinterName := UTF8Decode(aName);
        {$ifdef UsePrinterSupportedPapers}
        CachePapers(true);
        {$endif}
      end
      else
        raise Exception.Create('TQtPrinters: Cannot change printer while printing active !');
    end;
  finally
    StrList.Free;
  end;
end;

function TQtPrinters.DoGetCopies: Integer;
begin
  DoInitializeCachePapers;
  inherited DoGetCopies;
  Result := QtDefaultPrinter.NumCopies;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetCopies() Result=', IntToStr(Result));
  {$ENDIF}
end;

procedure TQtPrinters.DoSetCopies(aValue: Integer);
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoSetCopies() AValue=', IntToStr(AValue));
  {$ENDIF}
  DoInitializeCachePapers;
  inherited DoSetCopies(AValue);
  QtDefaultPrinter.NumCopies := AValue;
end;

function TQtPrinters.DoGetOrientation: TPrinterOrientation;
var
  O: QPrinterOrientation;
begin
  DoInitializeCachePapers;
  Result := inherited DoGetOrientation;
  O := QtDefaultPrinter.Orientation;
  case O of
    QPrinterPortrait: Result := poPortrait;
    QPrinterLandscape: Result := poLandscape;
  end;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetOrientation() Result=', IntToStr(Ord(Result)));
  {$ENDIF}
end;

procedure TQtPrinters.DoSetOrientation(aValue: TPrinterOrientation);
var
  O: QPrinterOrientation;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoSetOrientation() AValue=', IntToStr(Ord(AValue)));
  {$ENDIF}
  DoInitializeCachePapers;
  inherited DoSetOrientation(aValue);

  case AValue of
    poPortrait: O := QPrinterPortrait;
    poLandscape: O := QPrinterLandscape;
    poReversePortrait: O := QPrinterPortrait;
    poReverseLandscape: O := QPrinterLandscape;
  end;
  if QtDefaultPrinter.Orientation <> O then
    QtDefaultPrinter.Orientation := O;
end;

function TQtPrinters.GetPrinterType: TPrinterType;
begin
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.GetPrinterType() Result=', IntToStr(Ord(Result)));
  {$ENDIF}
  DoInitializeCachePapers;
  Result := inherited GetPrinterType;
  {no type at this moment, QPrinterInfo (qt-4.4) should have this}
  Result := ptLocal;
end;

function TQtPrinters.DoGetPrinterState: TPrinterState;
var
  State: QPrinterPrinterState;
begin
  DoInitializeCachePapers;
  Result := inherited DoGetPrinterState;
  Result := psNoDefine;
  
  State := QtDefaultPrinter.PrinterState;
  case State of
    QPrinterIdle: Result := psReady;
    QPrinterActive: Result := psPrinting;
    QPrinterAborted,
    QPrinterError: Result := psStopped;
  end;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.DoGetPrinterState() Result=', IntToStr(Ord(Result)));
  {$ENDIF}
end;

function TQtPrinters.GetCanPrint: Boolean;
begin
  DoInitializeCachePapers;
  Result := inherited GetCanPrint;
  Result := (DoGetPrinterState <> psStopped);
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.GetCanPrint() Result=',BoolToStr(Result));
  {$ENDIF}
end;

function TQtPrinters.GetCanRenderCopies: Boolean;
begin
  DoInitializeCachePapers;
  Result := inherited GetCanRenderCopies;
  Result := True;
  {$IFDEF VERBOSE_QT_PRINTING}
  DebugLn('TQtPrinters.GetCanRenderCopies() Result=',BoolToStr(Result));
  {$ENDIF}
end;

initialization
  Printer := TQtPrinters.Create;
  
finalization
  FreeAndNil(Printer);

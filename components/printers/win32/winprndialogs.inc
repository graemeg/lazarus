{%MainUnit ../printersdlgs.pp}

// update from win32wsdialogs.pp
procedure Reposition(ADialogWnd: Handle);
var
  Left, Top: Integer;
  ABounds, DialogRect: TRect;
begin
  // Btw, setting width and height of dialog does not reposition child controls :(
  // So no way to set another height and width at least here

  if (GetParent(ADialogWnd) = Widgetset.AppHandle) then
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
  GetWindowRect(ADialogWnd, DialogRect);
  Left := (ABounds.Right - DialogRect.Right + DialogRect.Left) div 2;
  Top := (ABounds.Bottom - DialogRect.Bottom + DialogRect.Top) div 2;
  SetWindowPos(ADialogWnd, HWND_TOP, Left, Top, 0, 0, SWP_NOSIZE);
end;

function PrintHookProc(hdlg: HWND; uiMsg: UINT; {%H-}wParam: WPARAM; lParam: LPARAM): UINT_PTR; stdcall;
var
  lpp: PtagPD;
begin
  if uiMsg = WM_INITDIALOG then
  begin
    lpp := PtagPD(lParam);
    if (lParam<>0) and (lpp^.lCustData<>0) then
      SetWindowTextW(hdlg, pwidechar(lpp^.lCustData));
    Reposition(hdlg);
  end;
  Result := 0;
end;

function PageSetupHookProc(hdlg: HWND; uiMsg: UINT; {%H-}wParam: WPARAM; lParam: LPARAM): PtrUInt; stdcall;
var
 lpp : PtagPSD;
begin
  if uiMsg = WM_INITDIALOG then
  begin
    lpp := PtagPSD(lParam);
    if (lParam<>0) and (lpp^.lCustData<>0) then
      SetWindowTextW(hdlg, pwidechar(lpp^.lCustData));
    Reposition(hdlg);
  end;
  Result := 0;
end;

function GetOwnerHandle(ADialog : TCommonDialog): HWND;
begin
  with ADialog do
   if Owner is TWinControl then
     Result := TWinControl(Owner).Handle
   else
     Result := WidgetSet.AppHandle;
end;


{ TPageSetupDialog }

function TPageSetupDialog.DoExecute: Boolean;
const
  PSD_NONETWORKBUTTON = $00200000; //constant is missed in FPC 3.2
var
  lpp        : tagPSD;
  PDev       : TPrinterDevice;
  DeviceMode : THandle;
  DevNames   : PDevNames;
  DevModeW   : PDeviceModeW;
  StW        : PWidechar;
  BoolRes: BOOL;
begin
  Result := False;
  if not Assigned(Printer) then Exit;
  if Printer.Printers.Count > 0 then
  begin
    FillChar(lpp, SizeOf(lpp), 0);
    with lpp do
    begin
      lStructSize := SizeOf(lpp);
      hInstance := System.HInstance;
      lpfnPageSetupHook := @PageSetupHookProc;
      if Title<>'' then
      begin
        lCustData := LPARAM(pWideChar(UTF8Decode(Title)));
      end
      else
        lCustData := 0;
      Flags := PSD_MARGINS or PSD_ENABLEPAGESETUPHOOK;
      hWndOwner := GetOwnerHandle(Self);
      //pmDefault corresponds to PSD_INWININIINTLMEASURE which is 0;
      if Units=pmMillimeters then
        Flags := Flags or PSD_INHUNDREDTHSOFMILLIMETERS
      else
      if units=pmInches      then
        Flags := Flags or PSD_INTHOUSANDTHSOFINCHES;
      // while the gui uses units millimeters or inches, in code the margins
      // should be specified in hundreds of mms or thoudsands of inches
      rtMargin.Left := MarginLeft;
      rtMargin.Top := MarginTop;
      rtMargin.Right := MarginRight;
      rtMargin.Bottom := MarginBottom;
      PDev := TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);

      if psoDisableMargins in FOptions then
        Flags := Flags or PSD_DISABLEMARGINS;
      if psoDisableOrientation in FOptions then
        Flags := Flags or PSD_DISABLEORIENTATION;
      if psoDisablePagePainting in FOptions then
        Flags := Flags or PSD_DISABLEPAGEPAINTING;
      if psoDisablePaper in FOptions then
        Flags := Flags or PSD_DISABLEPAPER;
      if psoDisablePrinter in FOptions then
        Flags := Flags or PSD_DISABLEPRINTER;
      if psoNoNetworkButton in FOptions then
        Flags := Flags or PSD_NONETWORKBUTTON;

      // Pdev.DevMode has the required size, just copy to the global memory
      DeviceMode := GLobalAlloc(GHND, PDev.DevModeSize);
      try
        DevModeW := PDeviceModeW(GlobalLock(DeviceMode));
        try
          CopyMemory(DevModeW, PDev.DevModeW, Pdev.DevModeSize);
        finally
          GlobalUnlock(DeviceMode);
        end;
        hDevMode := DeviceMode;
        BoolRes := PageSetupDlgW(@Lpp);
        if BoolRes then
        begin
          StW := '';
          if Lpp.HdevNames <> 0 then
          begin
            DevNames := PDevNames(GlobalLock(lpp.hDevNames));
            try
              StW := PWidechar(DEVNames) + DevNames^.wDeviceOffset;
              Printer.SetPrinter(UTF8Encode(widestring(StW)));
            finally
              GlobalUnlock(lpp.hDevNames);
              GlobalFree(lpp.hDevNames);
            end;
          end;
          
          Result:=True;
          if (Flags and PSD_INHUNDREDTHSOFMILLIMETERS)>0 then
            fUnits := pmMillimeters
          else
            fUnits := pmInches;

          MarginLeft := rtMargin.Left;
          MarginTop := rtMargin.Top;
          MarginRight := rtMargin.Right;
          MarginBottom := rtMargin.Bottom;

          if lpp.hDevMode <> 0 then
          begin
            DevModeW := PDeviceModeW(GlobalLock(lpp.hDevMode));
            try
              //Set the properties for the selected printer
              PDev := TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);
              CopyMemory(PDev.DevModeW, DevModeW, PDev.DevModeSize);
            finally
              GlobalUnlock(lpp.hDevMode);
           end;
          end;
        end;
      finally
        GlobalFree(DeviceMode);
      end;
    end;
  end;
end;


{ TPrinterSetupDialog }

function TPrinterSetupDialog.DoExecute: Boolean;
var
  lpp        : tagPD;
  PDev       : TPrinterDevice;
  DeviceMode : THandle;
  DevNames   : PDevNames;
  DevModeW   : PDeviceModeW;
  StW        : PWidechar;
  BoolRes: BOOL;
begin
  Result:=False;
  if not Assigned(Printer) then Exit;
  if Printer.Printers.Count>0 then
  begin
    FillChar(lpp, SizeOf(lpp), 0);
    with lpp do
    begin
      lStructSize := SizeOf(lpp);
      hInstance := System.HInstance;
      lpfnSetupHook := @PrintHookProc;
      if Title<>'' then
        lCustData := LPARAM(pWideChar(UTF8Decode(Title)))
      else
        lCustData := 0;
      Flags := PD_PRINTSETUP or PD_RETURNDC or PD_ENABLESETUPHOOK;
      hWndOwner := GetOwnerHandle(self);
      PDev := TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);
      // Pdev.DevMode has the required size, just copy to the global memory
      DeviceMode := GlobalAlloc(GHND, PDev.DevModeSize);
      try
        DevModeW := PDeviceModeW(GlobalLock(DeviceMode));
        try
          CopyMemory(DevModeW, Pdev.DevModeW, Pdev.DevModeSize);
        finally
          GlobalUnlock(DeviceMode);
        end;
        hDevMode := DeviceMode;
        BoolRes := PrintDlgW(@lpp);
        if BoolRes then
        begin
          StW := '';
          //Change Selected printer
          if lpp.hDevNames <> 0 then
          begin
            DevNames := PDevNames(GlobalLock(lpp.hDevNames));
            try
              StW := PWidechar(DevNames) + DevNames^.wDeviceOffset;
              Printer.SetPrinter(UTF8Encode(widestring(StW)));
            finally
              GlobalUnlock(lpp.hDevNames);
              GlobalFree(lpp.hDevNames);
            end;
          end;

          Result := True;

          if lpp.hDevMode <> 0 then
          begin
            DevModeW := PDeviceModeW(GlobalLock(lpp.hDevMode));
            try
              //Set the properties for the selected printer
              PDev := TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);
              CopyMemory(PDev.DevModeW, DevModeW, PDev.DevModeSize);
              TWinPrinter(Printer).Handle := hDC;
            finally
              GlobalUnlock(lpp.hDevMode);
           end;
          end;
        end;
      finally
        GlobalFree(DeviceMode);
      end;
    end;
  end;
end;


{ TPrintDialog }

function TPrintDialog.DoExecute: Boolean;
var
  lpp        : tagPD;
  PDev       : TPrinterDevice;
  DeviceMode : THandle;
  DevNames   : PDevNames;
  DevModeW   : PDeviceModeW;
  StW        : PWidechar;
  BoolRes: BOOL;
  Index: Integer;
begin
  Result := False;
  if not Assigned(Printer) then Exit;
  if Printer.Printers.Count > 0 then
  begin
    FillChar(lpp, SizeOf(lpp), 0);
    with lpp do
    begin
      lStructSize := SizeOf(lpp);
      hInstance := System.HInstance;
      lpfnPrintHook := @PrintHookProc;
      lpfnSetupHook := @PrintHookProc;
      if Title<>'' then
      begin
        lCustData := LPARAM(pWideChar(UTF8Decode(Title)));
      end
      else
        lCustData := 0;
      Flags := PD_ENABLEPRINTHOOK or PD_ENABLESETUPHOOK;
      if not Printer.RawMode then
        Flags := Flags or PD_RETURNDC;
      if Collate then
        Flags := Flags or PD_COLLATE;
      case PrintRange of
        prPageNums: Flags := Flags or PD_PAGENUMS;
        prSelection: Flags := Flags or PD_SELECTION;
      end;

      if PrintToFile  then Flags := Flags or PD_PRINTTOFILE;
      if not (poPrintToFile in Options) then Flags :=  Flags or PD_HIDEPRINTTOFILE;
      if not (poPageNums in Options) then Flags := Flags or PD_NOPAGENUMS;
      if not (poSelection in Options) then Flags := Flags or PD_NOSELECTION;
      if (poPrintToFile in Options ) and (poDisablePrintToFile in Options) then Flags := Flags or PD_DISABLEPRINTTOFILE;
      if (poHelp in Options) then Flags := Flags or PD_SHOWHELP;
      if not (poWarning in Options) then Flags := Flags or PD_NOWARNING;
      
      hWndOwner := GetOwnerHandle(self);
      PDev := TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);
      // Pdev.DevMode has the required size, just copy to the global memory
      DeviceMode := GlobalAlloc(GHND, PDEV.DevModeSize);
      try
        DevModeW := PDeviceModeW(GlobalLock(DeviceMode));
        try
          CopyMemory(DevModeW, PDev.DevModeW, PDev.DevModeSize);
        finally
          GlobalUnlock(DeviceMode);
        end;
        
        hDevMode := DeviceMode;
        nCopies := Word(Copies);
        nFromPage := Word(FromPage);
        nToPage := Word(ToPage);
        nMinPage := Word(MinPage);
        nMaxPage := Word(MaxPage);
        DevModeW^.dmCopies := nCopies;
        BoolRes := PrintDlgW(@lpp);
        if BoolRes then
        begin
          StW := '';
          //Change Selected printer
          if lpp.hDevNames <> 0 then
          begin
            DevNames := PDevNames(GlobalLock(lpp.hDevNames));
            try
              StW := PWidechar(DevNames) + DevNames^.wDeviceOffset;
              Printer.SetPrinter(UTF8Encode(widestring(stW)));
            finally
              GlobalUnlock(lpp.hDevNames);
              GlobalFree(lpp.hDevNames);
            end;
          end;

          Result:=True;
          
          // printer might have changed, check if new printer
          // support extended device modes
          PDev:=TPrinterDevice(Printer.Printers.Objects[Printer.PrinterIndex]);

          if (lpp.hDevMode<>0) and (Pdev.DevModeW<>nil) then

          begin
            DevModeW := PDeviceModeW(GlobalLock(lpp.hDevMode));
            try
              CopyMemory(PDev.DevModeW,DevModeW,PDev.DevModeSize);
              Index := Printer.PaperSize.SupportedPapers.IndexOfObject(TObject(ptrint(DevModeW^.dmPaperSize)));
              if Index <> -1 then
              begin
                PDev.DevModeW^.dmPaperSize := DevModeW^.dmPaperSize;
              end
              else
              begin
                PDev.DevModeW^.dmPaperSize := PDev.DefaultPaper;
              end;
              if nCopies=1 then
              begin
                Copies := DevModeW^.dmCopies;
              end
              else
                Copies := nCopies;
              Printer.Copies := Copies;
              
              if not Printer.RawMode then
                TWinPrinter(Printer).Handle := hDC;
                
            finally
              GlobalUnlock(lpp.hDevMode);
            end;
          end;
          
          PrintRange := prAllPages;
          PrintToFile := false;
          Collate := false;
          if (Flags and PD_SELECTION)>0 then PrintRange := prSelection;
          if (Flags and PD_PAGENUMS)>0 then PrintRange := prPageNums;
          if (Flags and PD_PRINTTOFILE)>0 then PrintToFile := true;
          if (Flags and PD_COLLATE)>0 then Collate := true;
          FromPage := Integer(nFromPage);
          ToPage := Integer(nToPage);
          MinPage := Integer(nMinPage);
          MaxPage := Integer(nMaxPage);
        end;
      finally
        GlobalFree(DeviceMode);
      end;
    end;
  end;
end;


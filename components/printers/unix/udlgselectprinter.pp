(*
                              udlgSelectPrinter.pp
                                ------------
 *****************************************************************************
  This file is part of the Printer4Lazarus package

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Author: Olivier Guilbaud (OG)

 Abstract:
   Printer select and configure dialog. This dialog box allows one to choose
   a printer and to modify some options to print a file.
   
 history
   oct 24 2003 OG - Job hold and priority options.
                  - Add few function for convert Date time Local <-> GMT
                    for job-hold-until option with time specification
   nov 04 2003 OG - First release
   apr 19 2004 OG - Implemented More and Less button with Lazarus #212 bug
                    Fixed (thanks)
   sep 12 2004 OG - Fix bug num copies by replace IntToStr(Trunc(edCopies.Value)))
                    with edCopies.Text. Idem for priority of job
   sep 29 2004 OG - Modify for use new CUPSPrinters unit
   dec 20 2004 OG - TPrintRange and PrintRange property from Darek
   mar 08 2005 OG - Dynamique CUPS link
                  - Some bug compile fix
   mar 08 2005 OG - Modifications for Printer4Lazarus pakage
   oct 2015       - property BigMode, refactor, anchors fix
------------------------------------------------------------------------------*)
unit uDlgSelectPrinter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types,
  // LCL
  LResources, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons, ExtCtrls,
  Spin, ComCtrls, LCLType, LCLPlatformDef, InterfaceBase, Printers, LCLProc,
  // Printers
  Printer4LazStrConst, OsPrinters, CUPSDyn;

type

  { TdlgSelectPrinter }

  TdlgSelectPrinter = class(TForm)
    Bevel1: TBEVEL;
    btnProp: TBUTTON;
    btnCancel: TBUTTON;
    btnPrint: TBUTTON;
    btnReduc: TBUTTON;
    btnPreview: TBUTTON;
    cbPrinters: TCOMBOBOX;
    cbCollate: TCHECKBOX;
    cbReverse: TCHECKBOX;
    cbPrintToFile: TCheckBox;
    edPageSet: TCOMBOBOX;
    cbTasktime: TCOMBOBOX;
    edRange: TEDIT;
    Label2: TLabel;
    panLabels: TPanel;
    PrinterGroupbox: TGroupbox;
    gbPages: TGROUPBOX;
    gbCopies: TGROUPBOX;
    imgCollate: TIMAGE;
    Label1: TLabel;
    PrinterStateLabel: TLabel;
    PrinterLocationLabel: TLabel;
    PrinterDescriptionLabel: TLabel;
    labComment: TLABEL;
    labCUPS: TLABEL;
    PrinterNameLabel: TLabel;
    PrioLabel: TLabel;
    labCUPSServer: TLABEL;
    labTask: TLABEL;
    lanNumCopies: TLABEL;
    labPage: TLABEL;
    labLocation: TLABEL;
    labState: TLABEL;
    edTimeTask: TEDIT;
    NbOpts: TPageControl;
    pgAdvance: TTabSheet;
    pgCopies: TTabSheet;
    BtnPanel: TPanel;
    rbSelection: TRadioButton;
    rbRange: TRADIOBUTTON;
    rbCurrentPage: TRADIOBUTTON;
    rbAllPage: TRADIOBUTTON;
    edCopies: TSPINEDIT;
    edPriority: TSPINEDIT;
    tkbPriority: TTRACKBAR;
    procedure btnPrintCLICK(Sender: TObject);
    procedure btnPropCLICK(Sender: TObject);
    procedure btnReducCLICK(Sender: TObject);
    procedure cbPrintersCHANGE(Sender: TObject);
    procedure cbPrintersDrawItem({%H-}Control: TWinControl; Index: Integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure cbPrintersKEYPRESS(Sender: TObject; var {%H-}Key: Char);
    procedure cbReverseCLICK(Sender: TObject);
    procedure cbTasktimeCHANGE(Sender: TObject);
    procedure dlgSelectPrinterCREATE(Sender: TObject);
    procedure dlgSelectPrinterSHOW(Sender: TObject);
    procedure edCopiesChange(Sender: TObject);
    procedure edRangeEnter(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure tkbPriorityCHANGE(Sender: TObject);
  private
    { private declarations }
    fPropertiesSetting : Boolean;
    FOptions: TPrintDialogOptions;
    FBig: boolean;
    fPrinterImgs: TImageList;
    FSavedPrinterIndex: Integer;
    function GetPrintRange: TPrintRange;
    procedure RefreshInfos;
    procedure InitPrinterOptions;
    procedure SetBigMode(AValue: boolean);
    procedure SetPrintRange(const AValue: TPrintRange);
    procedure InitPrinterList;
    property BigMode: boolean read FBig write SetBigMode;
  public
    { public declaration}
    constructor Create(aOwner : TComponent); override;
    
    property PrintRange: TPrintRange read GetPrintRange write SetPrintRange;
    property Options: TPrintDialogOptions read FOptions write FOptions;
  end; 

var
  dlgSelectPrinter: TdlgSelectPrinter;
  
implementation

{$R udlgselectprinter.lfm}
{$R selectprinter.res}

uses
  uDlgPropertiesPrinter;

Type
  THackCUPSPrinter = Class(TCUPSPrinter);

//Convert an local date & time to a GMT(UTC) Date & Time
function LocalToGMTDateTime(aDate : TDateTime) : TDateTime;
begin
  //TODO: Adjust for time zone and DayLight saving time
  result := aDate;
end;

//Convert an GMT(UTC) Date & Time to local date & time
function GMTToLocalDateTime(aDate : TDateTime) : TDateTime;
begin
  //TODO: Adjust for time zone and DayLight saving time
  result := aDate;
end;

{ TdlgSelectPrinter }

constructor TdlgSelectPrinter.Create(aOwner : TComponent);
begin
  inherited Create(aOwner);
  btnReduc.Caption := p4lrsButtonMoreArrow;

  if WidgetSet.LCLPlatform = lpCarbon then
  begin  //Can't hide tabs with button on Carbon, so just expand dialog.
    BigMode:=true;
    btnReduc.Visible:=false;
  end
  else
    BigMode:=false;
end;


procedure TdlgSelectPrinter.tkbPriorityCHANGE(Sender: TObject);
begin
  if Sender=nil then ;
  edPriority.Value:=tkbPriority.Position;
end;

//Initialization
procedure TdlgSelectPrinter.RefreshInfos;
var St  : string;
    Stp : string;
    n   : Integer;

  //Convert an GMT hour to Local hour
  function GetTimeHold : string;
  Var Dt       : TDateTime;
  begin
    try
      Dt:=Date+StrToTime(St);
      DT:=GMTToLocalDatetime(Dt);
      Result:=FormatDateTime('HH:NN:SS',Dt);
    Except
      Result:='00:00:00';
    end;
  end;

begin
  try

    cbPrintToFile.Visible := (poPrintToFile in FOptions);
    cbPrintToFile.Enabled := not (poDisablePrintToFile in FOptions);
    rbSelection.Enabled := (poSelection in FOptions);
    rbCurrentPage.Enabled := (poPageNums in FOptions);

    //State
    St:='';
    StP:='printer';
    if Printer.PrinterType=ptNetWork then
      StP:=StP+'_remote';

    BtnPrint.Enabled:=True;
    Case Printer.PrinterState of
      psReady     : St:=p4lrsJobStateReady;
      psPrinting  : St:=p4lrsJobStatePrinting;
      psStopped   : begin
                      St:=p4lrsJobStateStopped;
                      StP:=StP+'_stopped';
                      BtnPrint.Enabled:=False;
                    end;
    end;

    if Printer.CanPrint then
      St:=St+' '+p4lrsJobStateAccepting
    else
    begin
      St:=St+' '+p4lrsJobStateRejecting;
      BtnPrint.Enabled:=False;
    end;

    btnPreview.Enabled := btnPrint.Enabled;

    labState.Caption:=St;

    //cups server
    labCUPSServer.Caption:=cupsServer()+':'+IntToStr(ippPort());
    //
    labLocation.Caption:=THackCUPSPrinter(Printer).GetAttributeString('printer-location','');
    labComment.Caption :=THackCUPSPrinter(Printer).GetAttributeString('printer-info','');

    cbReverseCLICK(cbCollate);  // update collate image
    edCopiesChange(edCopies);   // update collate/reverse states

    //Range setting
    edRange.Enabled:=
      (poPageNums in FOptions) and
      THackCUPSPrinter(Printer).GetAttributeBoolean('page-ranges-supported',False);
    rbRange.Enabled:=edRange.Enabled;

    //Job priority
    n:=THackCUPSPrinter(Printer).GetAttributeInteger('job-priority-supported',0);
    edPriority.MaxValue:=n;
    tkbPriority.Max:=n;
    n:=THackCUPSPrinter(Printer).GetAttributeInteger('job-priority-default',0);
    edPriority.Value:=n;
    edPriority.Tag  :=n; //Save default priority
    tkbPriority.Position:=n;
  
    //Job-Hold
    edTimeTask.Enabled:=False;
    edTimeTask.Text:=FormatDateTime('hh:nn:ss',Now);
    St:=THackCUPSPrinter(Printer).cupsGetOption('job-hold-until');
    n:=0;
    if St='indefinite' then n:=1;
    if St='day-time'   then n:=2;
    if st='evening'    then n:=3;
    if st='night'      then n:=4;
    if st='weekend'    then n:=5;
    if St='second-shift' then n:=6;
    if St='third-shift'  then n:=7;
    if Pos(':',St)<>0 then
    begin
      n:=8;
      edTimeTask.Enabled:=True;
      edTimeTask.Text:=St;
    end;

    cbTasktime.ItemIndex:=n;
  Except
  end;
end;

function TdlgSelectPrinter.GetPrintRange: TPrintRange;
begin
  Result:=prAllPages;

  if rbCurrentPage.checked then
     Result:=prCurrentPage
  else
    if rbRange.checked then
       Result:=prPageNums
    else
      if rbSelection.checked then
        Result:=prSelection;
end;

//Initialization of selected Printer options
procedure TdlgSelectPrinter.InitPrinterOptions;
Var St    : string;
    pOr   : TPrinterOrientation;

  //Convert an Local hour to GMT hour
  function GetTimeHold : string;
  Var Dt       : TDateTime;
  begin
    try
      Dt:=Date+StrToTime(edTimeTask.Text);
      DT:=LocalToGMTDateTime(Dt);
      Result:=FormatDateTime('HH:NN:SS',Dt);
    Except
      Result:='indefinite';
    end;
  end;

begin
  if not fPropertiesSetting then
  begin
    //Preserve selected orientation - isn't stored in cups options
    pOr:=Printer.Orientation;
    //Free current options if exists
    THackCUPSPrinter(Printer).FreeOptions;
    //Initialize default Options
    THackCUPSPrinter(Printer).SetOptionsOfPrinter;
    Printer.Orientation := pOr;
  end;
  
  //Copies
  THackCUPSPrinter(Printer).cupsAddOption('copies',edCopies.Text);
  if rbRange.Checked then
    THackCUPSPrinter(Printer).cupsAddOption('page-ranges',edRange.Text);
  if edPageSet.ItemIndex>0 then
  begin
    if edPageSet.ItemIndex=1 then
      St:='Odd'
    else
      St:='Even';
    THackCUPSPrinter(Printer).cupsAddOption('page-set',St);
  end;
  if cbCollate.Checked then
    st:='separate-documents-collated-copies'
  else
    St:='separate-documents-uncollated-copies';
  THackCUPSPrinter(Printer).cupsAddOption('multiple-document-handling',St);
  if cbReverse.Checked then
    THackCUPSPrinter(Printer).cupsAddOption('OutputOrder','Reverse');

  //Priority job
  if edPriority.Tag<>edPriority.Value then
    THackCUPSPrinter(Printer).cupsAddOption('job-priority',edPriority.Text);

  //Job-Hold
  Case cbTasktime.ItemIndex of
    1 : St:='indefinite';
    2 : St:='day-time';
    3 : st:='evening';
    4 : st:='night';
    5 : st:='weekend';
    6 : St:='second-shift';
    7 : St:='third-shift';
    8 : St:=GetTimeHold;
    else St:='no-hold';
  end;
  THackCUPSPrinter(Printer).cupsAddOption('job-hold-until',St);
end;

procedure TdlgSelectPrinter.SetPrintRange(const AValue: TPrintRange);
begin
  case aValue of
    prAllPages    : rbAllPage.checked:=True;
    prCurrentPage : rbCurrentPage.checked:=True;
    prSelection   : rbSelection.checked:=True;
    prPageNums    : rbRange.checked:=True;
  end;
end;

procedure TdlgSelectPrinter.InitPrinterList;
var
  i, FImgIndex, FSavedIndex: Integer;
begin
  // load printer images from resource
  fPrinterImgs.AddResourceName(HInstance, 'printer');
  fPrinterImgs.AddResourceName(HInstance, 'printer_remote');
  fPrinterImgs.AddResourceName(HInstance, 'printer_remote_stopped');
  fPrinterImgs.AddResourceName(HInstance, 'printer_stopped');

  // add printer names to cbPrinters, with image index
  FSavedIndex := Printer.PrinterIndex;
  try
    for i := 0 to Printer.Printers.Count - 1 do
    begin
      Printer.PrinterIndex := i;
      // determine printer type and state
      FImgIndex := 0;
      if Printer.PrinterType = ptNetWork then
      begin
        if Printer.PrinterState = psStopped then
          FImgIndex := 2
        else
          FImgIndex := 1;
      end
      else
        if Printer.PrinterState = psStopped then
          FImgIndex := 3;
      cbPrinters.Items.AddObject(Printer.PrinterName, TObject(IntPtr(FImgIndex)));
    end;
  finally
    Printer.PrinterIndex := FSavedIndex;
  end;
  if cbPrinters.Items.Count > 0 then
    cbPrinters.ItemIndex := Printer.PrinterIndex;
end;

//Initialization of screen
procedure TdlgSelectPrinter.dlgSelectPrinterSHOW(Sender: TObject);
begin
  if Sender=nil then ;
  NbOpts.PageIndex:=0;
  InitPrinterList;
  RefreshInfos;
  {$IFDEF UNIX}
  btnCancel.Left := btnPreview.Left;
  {$ENDIF}
end;

procedure TdlgSelectPrinter.edCopiesChange(Sender: TObject);
begin
  if Sender=nil then ;
  cbCollate.Enabled := edCopies.Value > 1;
  cbReverse.Enabled := cbCollate.Enabled;
end;

procedure TdlgSelectPrinter.edRangeEnter(Sender: TObject);
begin
  rbRange.Checked := True;
end;

procedure TdlgSelectPrinter.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if ModalResult = mrCancel then
    Printer.PrinterIndex := FSavedPrinterIndex;
end;

procedure TdlgSelectPrinter.FormDestroy(Sender: TObject);
begin
  fPrinterImgs.Free;
end;

procedure TdlgSelectPrinter.cbTasktimeCHANGE(Sender: TObject);
begin
  if Sender=nil then ;
  //Time is active if last item is selected
  edTimeTask.Enabled:=(cbTaskTime.ItemIndex=cbTaskTime.Items.Count-1);
  edTimeTask.Text:=FormatDateTime('hh:nn:ss',Now);
end;

procedure TdlgSelectPrinter.dlgSelectPrinterCREATE(Sender: TObject);
begin
  if Sender=nil then ;
  FBig := False;
  fPropertiesSetting:=False;
  NbOpts.AutoSize := True;
  NbOpts.PageIndex:=0;
  edPageSet.Items[0]:=p4lrsAllPages;
  edPageSet.Items[1]:=p4lrsPageOdd;
  edPageSet.Items[2]:=p4lrsPageEven;
  fPrinterImgs := TImageList.Create(Self);
  FSavedPrinterIndex := Printer.PrinterIndex;
end;

//Show corresponding image
procedure TdlgSelectPrinter.cbReverseCLICK(Sender: TObject);
Var St : string;
begin
  if Sender=nil then ;
  St:='collate';
  If not cbCollate.Checked then
   St:='un'+St;
  if cbReverse.Checked then
    St:=St+'_rev';

  imgCollate.Picture.PixMap.TransparentColor:=clNone;
  imgCollate.Picture.PixMap.LoadFromResourceName(HInstance, St);
  imgCollate.Picture.BitMap.Transparent:=True;
end;

procedure TdlgSelectPrinter.cbPrintersKEYPRESS(Sender: TObject; var Key: Char);
begin
  if Sender=nil then ;
//  Key:=#0;
end;

procedure TdlgSelectPrinter.btnReducCLICK(Sender: TObject);
begin
  if Sender=nil then ;
  BigMode:=not BigMode;
end;

procedure TdlgSelectPrinter.SetBigMode(AValue: boolean);
begin
  if FBig = AValue then
    Exit;
  FBig:= AValue;
  NbOpts.Visible:= FBig;

  AutoSize := False;
  AutoSize := True;

  if not FBig then
    btnReduc.Caption:=p4lrsButtonMoreArrow
  else
    btnReduc.Caption:=p4lrsButtonLessArrow;

  Application.ProcessMessages;
  NbOpts.AutoSize := False;
end;

procedure TdlgSelectPrinter.btnPrintCLICK(Sender: TObject);
begin
  if Sender=nil then ;
  InitPrinterOptions;
end;

//Show the printer properties dialog
procedure TdlgSelectPrinter.btnPropCLICK(Sender: TObject);
var Dlg : Tdlgpropertiesprinter;
begin
  if Sender=nil then ;
  //Set default printer
  THackCUPSPrinter(Printer).SelectCurrentPrinterOrDefault;

  Dlg:=Tdlgpropertiesprinter.Create(self);
  try
    if Dlg.ShowModal=mrOk then
    begin
      Dlg.InitProperties;
      fPropertiesSetting:=True;
    end;
  finally
    Dlg.free;
  end;
end;

procedure TdlgSelectPrinter.cbPrintersCHANGE(Sender: TObject);
var
  tmpn: Integer;
  tmpOptions: Pcups_option_t;
begin
  if Sender=nil then ;

  tmpn := THackCupsPrinter(Printer).CopyOptions(tmpOptions);

  Printer.SetPrinter(cbPrinters.Text);
  fPropertiesSetting:=False;

  THackCupsPrinter(Printer).MergeOptions(tmpOptions, tmpn);

  RefreshInfos;
end;

procedure TdlgSelectPrinter.cbPrintersDrawItem(Control: TWinControl;
  Index: Integer; ARect: TRect; State: TOwnerDrawState);
var
  ts: TTextStyle;
begin
  // setup dropdown colors
  if cbPrinters.DroppedDown and not (odSelected in State) then
  begin
    cbPrinters.Canvas.Brush.Color := clMenu;
    cbPrinters.Canvas.Font.Color := clMenuText;
    cbPrinters.Canvas.FillRect(ARect);
  end;
  // draw image
  fPrinterImgs.Draw(cbPrinters.Canvas, ARect.Left + 4,
                    (ARect.Top + ARect.Bottom - fPrinterImgs.Height) div 2,
                    IntPtr(cbPrinters.Items.Objects[Index]));
  // draw text
  ts.Layout := tlCenter;
  ts.Alignment := taLeftJustify;
  ts.Opaque := False;
  ts.Clipping := True;
  ts.Wordbreak := False;
  ARect.Left := ARect.Left + (fPrinterImgs.Width + 8);
  cbPrinters.Canvas.TextRect(ARect, ARect.Left, 0, cbPrinters.Items[Index], ts);
end;

end.

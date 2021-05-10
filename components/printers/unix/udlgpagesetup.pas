{
 *****************************************************************************
  This file is part of the Printer4Lazarus package

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit udlgpagesetup;

{$mode objfpc}{$H+}

interface

uses
  // LCL
  Classes, Forms, ExtCtrls, StdCtrls, Menus, Controls,
  // Printers
  Printers, framePageSetup;

type

  { TDlgPageSetup }

  TDlgPageSetup = class(TForm)
    btnCancel: TButton;
    btnPrinter: TButton;
    btnOk: TButton;
    frmPageSetup: TframePageSetup;
    PanelButtons: TPanel;
    procedure btnPrinterClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var {%H-}CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FMenu: TPopupMenu;
    FSavedPaperName: string;
    FSavedOrientation: TPrinterOrientation;
    FSavedPrinterIndex: Integer;
    procedure MenuPrinterClick(Sender: TObject);
  public
    procedure SetControls(AEnablePreview, AEnableMargins, AEnablePapers,
      AEnableOrientation: boolean);
  end; 

var
  dlgPageSetup: TDlgPageSetup;

implementation

{$R udlgpagesetup.lfm}

{ TDlgPageSetup }

procedure TDlgPageSetup.btnPrinterClick(Sender: TObject);
var
  mi: TMenuItem;
  pnt: TPoint;
  i: integer;
begin
  if not Assigned(FMenu) then
    FMenu:= TPopupMenu.Create(Self);
  FMenu.Items.Clear;

  if Printer.Printers.Count=0 then exit;
  for i:= 0 to Printer.Printers.Count-1 do
  begin
    mi:= TMenuItem.Create(Self);
    mi.Caption:= Printer.Printers[i];
    mi.Checked:= i=Printer.PrinterIndex;
    mi.RadioItem:= true;
    mi.OnClick:= @MenuPrinterClick;
    FMenu.Items.Add(mi);
  end;

  pnt:= btnPrinter.ClientToScreen(Point(0, 0));
  FMenu.PopUp(pnt.X, pnt.Y);
end;

procedure TDlgPageSetup.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if ModalResult = mrCancel then
  begin
    Printer.PaperSize.PaperName := FSavedPaperName;
    Printer.Orientation := FSavedOrientation;
    Printer.PrinterIndex := FSavedPrinterIndex;
  end;
end;

procedure TDlgPageSetup.FormCreate(Sender: TObject);
begin
  // Save selected printer and paper, to be restore if dialog is cancelled
  FSavedPaperName := Printer.PaperSize.PaperName;
  FSavedOrientation := Printer.Orientation;
  FSavedPrinterIndex := Printer.PrinterIndex;
  AutoSize := False;
  AutoSize := True;
end;

procedure TDlgPageSetup.FormShow(Sender: TObject);
begin
  // adjust height for themes
  with frmPageSetup do
    if not EnablePreview then
      Height := panSetup.Height
    else
      Height := panSetup.Height + panPreview.Height;
  MoveToDefaultPosition;
end;

procedure TDlgPageSetup.MenuPrinterClick(Sender: TObject);
begin
  if Sender is TMenuItem then
  begin
    Printer.SetPrinter((Sender as TMenuItem).Caption);
    frmPageSetup.Initialize(
      frmPageSetup.EnablePreview,
      frmPageSetup.EnableMargins,
      frmPageSetup.EnablePapers,
      frmPageSetup.EnableOrientation
      );
    frmPageSetup.UpdatePageSize;
  end;
end;

procedure TDlgPageSetup.SetControls(AEnablePreview, AEnableMargins, AEnablePapers,
  AEnableOrientation: boolean);
begin
  frmPageSetup.Initialize(AEnablePreview, AEnableMargins, AEnablePapers, AEnableOrientation);
{  with frmPageSetup do
    if not EnablePreview then
      Height := panSetup.Height
    else
      Height := panSetup.Height + panPreview.Height;}
end;

end.


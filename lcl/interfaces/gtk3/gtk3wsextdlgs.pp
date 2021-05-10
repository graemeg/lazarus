{
 *****************************************************************************
 *                              Gtk3WSExtDlgs.pp                             *
 *                              ----------------                             *
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Gtk3WSExtDlgs;

{$mode objfpc}{$H+}

interface

uses
////////////////////////////////////////////////////
// I M P O R T A N T                                
////////////////////////////////////////////////////
// To get as little as posible circles,
// uncomment only when needed for registration
////////////////////////////////////////////////////
//  ExtDlgs,
////////////////////////////////////////////////////
  Controls, LCLType,
  gtk3widgets,
  WSExtDlgs, WSLCLClasses;

type

  { TGtk3WSPreviewFileControl }

  TGtk3WSPreviewFileControl = class(TWSPreviewFileControl)
  published
    class function  CreateHandle(const AWinControl: TWinControl;
      const AParams: TCreateParams): TLCLIntfHandle; override;
  end;

  { TGtk3WSPreviewFileDialog }

  TGtk3WSPreviewFileDialog = class(TWSPreviewFileDialog)
  published
  end;

  { TGtk3WSOpenPictureDialog }

  TGtk3WSOpenPictureDialog = class(TWSOpenPictureDialog)
  published
  end;

  { TGtk3WSSavePictureDialog }

  TGtk3WSSavePictureDialog = class(TWSSavePictureDialog)
  published
  end;

  { TGtk3WSCalculatorDialog }

  TGtk3WSCalculatorDialog = class(TWSCalculatorDialog)
  published
  end;

  { TGtk3WSCalculatorForm }

  TGtk3WSCalculatorForm = class(TWSCalculatorForm)
  published
  end;

  { TGtk3WSCalendarDialogForm }

  TGtk3WSCalendarDialogForm = class(TWSCalendarDialogForm)
  published
  end;

  { TGtk3WSCalendarDialog }

  TGtk3WSCalendarDialog = class(TWSCalendarDialog)
  published
  end;


implementation

{ TGtk3WSPreviewFileControl }

class function TGtk3WSPreviewFileControl.CreateHandle(
  const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle;
var
  Gtk3CustomControl: TGtk3CustomControl;
begin
  Gtk3CustomControl := TGtk3CustomControl.Create(AWinControl, AParams);
  Result := TLCLIntfHandle(Gtk3CustomControl);
end;

end.

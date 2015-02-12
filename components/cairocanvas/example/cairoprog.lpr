program cairoprog;

{$mode objfpc}{$H+}

uses
  Classes, CairoCanvas;

var // This could also be TCairoSvgCanvas, TCairoPngCanvas or TCairoPsCanvas
  PrinterCanvas: TCairoPdfCanvas;
begin
  PrinterCanvas := TCairoPdfCanvas.Create;
  try
    PrinterCanvas.OutputFileName := 'CairoCanvas.pdf';
    PrinterCanvas.Ellipse(20, 20, 170, 120);
    //PrinterCanvas.XDPI := 75; // These have valid default values.
    //PrinterCanvas.YDPI := 75;
    //PrinterCanvas.PaperWidth := 250;
    //PrinterCanvas.PaperHeight := 500;
    PrinterCanvas.Font.Name := 'Arial'; // Font properties must be set, does not work otherwise.
    PrinterCanvas.Font.Height := 24;
    PrinterCanvas.TextOut(50, 150, 'abcdefghijklmnopqrstuvwxyzåäö');
    WriteLn('Written file ' + PrinterCanvas.OutputFileName);
  finally
    PrinterCanvas.Free;
  end;
end.


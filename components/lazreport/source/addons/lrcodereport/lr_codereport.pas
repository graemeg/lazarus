{ LR_CodeReport

  Copyright (C) 2012 Julio Jiménez Borreguero
  Contact: jujibo at gmail dot com

  This library is free software; you can redistribute it and/or modify it
  under the same terms as the Lazarus Component Library (LCL)

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

}

unit LR_CodeReport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Graphics, LR_Const, LR_Class, ExtCtrls, LR_Shape,
  LR_BarC, Barcode, Printers{$IFDEF LCLNOGUI}, lr_ngcanvas{$ENDIF};

type

  TlrPageMargin = record
    Left, Right, Top, Bottom: double;
  end;

  TlrCursor = record
    XTop, YTop, XBottom, YBottom: double;
    Left, Top: double
  end;

  TlrLineStyle = record
    LColor: TColor;
    LStyle: TfrFrameStyle;
    LWidth: double;
  end;

  TlrTextRectStyle = record
    FontName: string;
    FontColor: TColor;
    FontSize: integer;
    FontStyle: TFontStyles;
    Angle: integer;
    FillColor: TColor;
    Line: TlrLineStyle;
    BorderLines: TfrFrameBorders;       // border lines
    Alignment: TAlignment;
    Layout: TTextLayout;
    Autosize, Stretched, WordBreak, WordWrap: boolean
  end;

  TlrShapeStyle = record
    FillColor: TColor;
    FrameColor: TColor;
    FrameWith: double;
    FrameStyle: TfrFrameStyle;
    ShapeType: TfrShapeType;
  end;

  TlrBarCodeStyle = record
    CheckSum: boolean;
    ShowCode: boolean;
    BarType: TBarcodeType;
    Zoom: double;
    Angle: double;
    FrameColor: TColor;
    BorderLines: TfrFrameBorders;
    FrameWidth: double;
  end;

  { TlrCodeReport }

  TlrCodeReport = class(TComponent)
  private
    ActivePage: integer;
    XRatio, YRatio: double;
    PaperSize, PaperWidth, PaperHeight: integer;
    PaperOrientation: TPrinterOrientation;
    FReport, FOwnedReport: TfrReport;
    ABitmap: TLazreportBitmap;
    SavedLineStyle: TlrLineStyle;
    SavedTextRectStyle: TlrTextRectStyle;
    SavedFrameStyle: TlrTextRectStyle;
    SavedShapeStyle: TlrShapeStyle;
    SavedBarCodeStyle: TlrBarCodeStyle;
    FOnBeginReport: TNotifyEvent;


    function GetReport: TfrReport;
    procedure SetReport(AValue: TfrReport);
    function TextWidth(AText: string): double;
    function TextHeight: double;

  public
    PageMargin: TlrPageMargin;
    Cursor: TlrCursor;
    LineStyle: TlrLineStyle;
    TextRectStyle: TlrTextRectStyle;
    FrameStyle: TlrTextRectStyle;
    ShapeStyle: TlrShapeStyle;
    BarCodeStyle: TlrBarCodeStyle;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetPaper(ASize: integer; AOr: TPrinterOrientation = poPortrait;
      AWidth: integer = 0; AHeight: integer = 0);
    procedure SetRatio(X, Y: double);
    procedure RunReport(aShowPreview: boolean = true);
    procedure SetFont(AName: string; ASize: integer; AStyle: TFontStyles = []);
    procedure NewLine(i: word = 1);
    procedure NewPage;
    procedure SetActivePage(APage: integer);
    procedure EnableMillimeters;     // set units (x, y, w, h..) in millimeters
    function GetTextHeight: double;
    function GetTextWidth(AText: string): double;
    function GetPageWidth: integer;  // returning value in enabled units
    function GetPageHeight: integer;
    function GetPageWidthMM: double;
    function GetPageHeightMM: double;
    function GetActivePage: integer;

    {* Styles *}
    procedure ResetLineStyle;
    procedure ResetTextRectStyle;
    procedure ResetFrameStyle;
    procedure ResetShapeStyle;
    procedure ResetBarCodeStyle;
    procedure SaveTextRectStyle;
    procedure SaveLineStyle;
    procedure SaveFrameStyle;
    procedure SaveShapeStyle;
    procedure SaveBarCodeStyle;
    procedure RestoreTextRectStyle;
    procedure RestoreLineStyle;
    procedure RestoreFrameStyle;
    procedure RestoreShapeStyle;
    procedure RestoreBarCodeStyle;
    function GetDefaultTextRectStyle: TlrTextRectStyle;
    function GetDefaultLineStyle: TlrLineStyle;
    function GetDefaultFrameStyle: TlrTextRectStyle;
    function GetDefaultShapeStyle: TlrShapeStyle;
    function GetDefaultBarCodeStyle: TlrBarCodeStyle;

    function PageCount: integer;

    {* Drawing lines and frames*}
    procedure DrawLine(X, Y, W, H: double; const Style: TlrLineStyle);
    procedure DrawHLine(X, Y, W: double);
    procedure DrawVLine(X, Y, H: double);
    procedure DrawFrame(X, Y, W, H: double; Style: TlrTextRectStyle);
    procedure DrawFrame(X, Y, W, H: double);

    {* Drawing text *}
    procedure DrawText(X, Y, W, H: double; Text: string; Style: TlrTextRectStyle);
    procedure TextOut(AText: string);
    procedure TextOutLn(AText: string);
    procedure TextOutXY(X, Y: double; AText: string;
      Alignment: TAlignment = taLeftJustify);
    procedure TextOutRectXY(X, Y, W, H: double; AText: string;
      Alignment: TAlignment = taLeftJustify; Clipping: boolean = True);
    procedure TextOutXYUp(X, Y: double; AText: string;
      Alignment: TAlignment = taLeftJustify);

    {* Drawing images *}
    procedure DrawImage(X, Y, W, H: double; AImage: TImage;
      ASharedName: string = ''; AStretched: boolean = True;
      AKeepAspect: boolean = True; ACentered: boolean = False); overload;
    procedure DrawImage(X, Y, W, H: double; APicture: TPicture;
      ASharedName: string = ''; AStretched: boolean = True;
      AKeepAspect: boolean = True; ACentered: boolean = False); overload;

    {* Drawing shapes *}
    procedure DrawShape(X, Y, W, H: double; Style: TlrShapeStyle);
    procedure DrawRectangle(X, Y, W, H: double);
    procedure DrawRoundRectangle(X, Y, W, H: double);
    procedure DrawDiagonalDownRight(X, Y, W, H: double);
    procedure DrawDiagonalUpRight(X, Y, W, H: double);
    procedure DrawEllipse(X, Y, W, H: double);
    procedure DrawTriangle(X, Y, W, H: double);

    {* Drawring BarCode *}
    procedure DrawBarCode(X, Y, W, H: double; Code: string; Style: TlrBarCodeStyle);

  published
    property OnBeginReport: TNotifyEvent read FOnBeginReport write FOnBeginReport;
    property Report: TfrReport read GetReport write SetReport;
  end;

  procedure register;

implementation

{$R lr_codereport.res}

const
  DPIX = 93 / 1.022;      // 91 DPI default (used by lazreport)
  DPIY = 93 / 1.015;


procedure register;
begin
  RegisterComponents('LazReport',[TLrCodeReport]);
end;

{ TlrCodeReport }

constructor TlrCodeReport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetRatio(1, 1); // pixels
  ResetLineStyle;
  ResetTextRectStyle;
  ResetFrameStyle;
  ResetShapeStyle;
  ResetBarCodeStyle;
  // Init cursor
  Cursor.XTop := 0.0;
  Cursor.YTop := 0.0;
  Cursor.XBottom := 0.0;
  Cursor.YBottom := 0.0;
  // Init margins
  PageMargin.Left := 0.0;
  PageMargin.Right := 0.0;
  PageMargin.Top := 0.0;
  PageMargin.Bottom := 0.0;
  ABitmap := TLazreportBitmap.create;
  // Set default paper
  PaperSize := 9;  // A4   check LR_Prntr unit for a list
  PaperWidth := 0;
  PaperHeight := 0;
  PaperOrientation := poPortrait;
end;

destructor TlrCodeReport.Destroy;
begin
  // TODO, free only if FReport is owned
  FOwnedReport.Free;
  ABitMap.Free;
  inherited Destroy;
end;

procedure TlrCodeReport.SetPaper(ASize: integer; AOr: TPrinterOrientation;
  AWidth: integer; AHeight: integer);
begin
  PaperSize := ASize;
  PaperWidth := AWidth;
  PaperHeight := AHeight;
  PaperOrientation := AOr;
  // Update current page
  Report.Pages[ActivePage].ChangePaper(PaperSize, PaperWidth,
    PaperHeight, PaperOrientation);
end;

procedure TlrCodeReport.SetRatio(X, Y: double);
begin
  XRatio := X;
  YRatio := Y;
end;

procedure TlrCodeReport.RunReport(aShowPreview: boolean = true);
begin
  if Assigned(OnBeginReport) then
    OnBeginReport(Self);
  if aShowPreview then
    Report.ShowReport;
end;

procedure TlrCodeReport.SetFont(AName: string; ASize: integer;
  AStyle: TFontStyles);
begin
  TextRectStyle.FontName:= AName;
  TextRectStyle.FontSize:= ASize;
  TextRectStyle.FontStyle:= AStyle;
end;

procedure TlrCodeReport.NewPage;
begin
  Report.Pages.Add;
  ActivePage := PageCount - 1;
  // Set Page Size and orientation
  Report.Pages[ActivePage].ChangePaper(PaperSize, PaperWidth,
    PaperHeight, PaperOrientation);
  // Set initial cursor position
  Cursor.XTop := PageMargin.Left;
  Cursor.XBottom := PageMargin.Left;
  Cursor.YTop := PageMargin.Top;
  Cursor.YBottom := PageMargin.Top;
  Cursor.Top := 0;
  Cursor.Left := 0;
end;

procedure TlrCodeReport.SetActivePage(APage: integer);
begin
  if (APage >= 1) and (APage <= PageCount) then
    ActivePage := APage - 1
  else
    raise Exception.CreateFmt(sErrorOccurred, [self.ClassName]);
end;

procedure TlrCodeReport.EnableMillimeters;
begin
  // Set X and Y axes ratio
  XRatio := Report.Pages[ActivePage].PrnInfo.Pgw / GetPageWidthMM;
  YRatio := Report.Pages[ActivePage].PrnInfo.Pgh / GetPageHeightMM;
end;

function TlrCodeReport.GetTextHeight: double;
begin
 Result := round(TextHeight / XRatio);
end;

function TlrCodeReport.GetTextWidth(AText: string): double;
begin
 Result := round(TextWidth(AText) / XRatio);
end;

function TlrCodeReport.GetPageWidth: integer;
begin
  Result := round(Report.Pages[ActivePage].PrnInfo.Pgw / XRatio);
end;

function TlrCodeReport.GetPageHeight: integer;
begin
  Result := round(Report.Pages[ActivePage].PrnInfo.PgH / YRatio);
end;

function TlrCodeReport.GetPageWidthMM: double;
begin
  Result := Report.Pages[ActivePage].PrnInfo.Pgw / DPIX * 25.4; // inches to mm
end;

function TlrCodeReport.GetPageHeightMM: double;
begin
  Result := Report.Pages[ActivePage].PrnInfo.PgH / DPIY * 25.4; // inches to mm
end;

function TlrCodeReport.GetActivePage: integer;
begin
  Result := ActivePage + 1;
end;

procedure TlrCodeReport.ResetLineStyle;
begin
  LineStyle := GetDefaultLineStyle;
end;

procedure TlrCodeReport.ResetTextRectStyle;
begin
  TextRectStyle := GetDefaultTextRectStyle;
end;

procedure TlrCodeReport.ResetFrameStyle;
begin
  FrameStyle := GetDefaultFrameStyle;
end;

procedure TlrCodeReport.ResetShapeStyle;
begin
  ShapeStyle := GetDefaultShapeStyle;
end;

procedure TlrCodeReport.ResetBarCodeStyle;
begin
  BarCodeStyle := GetDefaultBarCodeStyle;
end;

procedure TlrCodeReport.SaveTextRectStyle;
begin
  SavedTextRectStyle := TextRectStyle;
end;

procedure TlrCodeReport.SaveLineStyle;
begin
  SavedLineStyle := LineStyle;
end;

procedure TlrCodeReport.SaveFrameStyle;
begin
  SavedFrameStyle := FrameStyle;
end;

procedure TlrCodeReport.SaveShapeStyle;
begin
  SavedShapeStyle := ShapeStyle;
end;

procedure TlrCodeReport.SaveBarCodeStyle;
begin
  SavedBarCodeStyle := BarCodeStyle;
end;

procedure TlrCodeReport.RestoreTextRectStyle;
begin
  TextRectStyle := SavedTextRectStyle;
end;

procedure TlrCodeReport.RestoreLineStyle;
begin
  LineStyle := SavedLineStyle;
end;

procedure TlrCodeReport.RestoreFrameStyle;
begin
  FrameStyle := SavedFrameStyle;
end;

procedure TlrCodeReport.RestoreShapeStyle;
begin
  ShapeStyle := SavedShapeStyle;
end;

procedure TlrCodeReport.RestoreBarCodeStyle;
begin
  BarCodeStyle := SavedBarCodeStyle;
end;

function TlrCodeReport.GetDefaultTextRectStyle: TlrTextRectStyle;
var
  Textstyle: TlrTextRectStyle;
begin
  with Textstyle do
  begin
    FontName := 'Arial';
    FontColor := clBlack;
    FontSize := 8;
    FontStyle := [];
    Angle := 0;
    FillColor := clNone;
    Line := GetDefaultLineStyle;
    BorderLines := [];
    Alignment := taLeftJustify;
    Layout := tlTop;
    Autosize := False;
    Stretched := True;
    WordBreak := False;
    WordWrap := False;   // cut text
  end;
  Result := Textstyle;
end;

function TlrCodeReport.GetDefaultLineStyle: TlrLineStyle;
var
  Lstyle: TlrLineStyle;
begin
  with Lstyle do
  begin
    LWidth := 1.0;
    LColor := clBlack;
    LStyle := frsSolid;
  end;
  Result := Lstyle;
end;

function TlrCodeReport.GetDefaultFrameStyle: TlrTextRectStyle;
var
  AFramestyle: TlrTextRectStyle;
begin
  AFramestyle := GetDefaultTextRectStyle;
  AFramestyle.BorderLines := [frbLeft, frbTop, frbRight, frbBottom];
  Result := AFramestyle;
end;

function TlrCodeReport.GetDefaultShapeStyle: TlrShapeStyle;
begin
  with Result do
  begin
    FillColor := clNone;
    FrameColor := clBlack;
    FrameWith := 1;
    FrameStyle := frsSolid;
    ShapeType := frstRectangle;
  end;
end;

function TlrCodeReport.GetDefaultBarCodeStyle: TlrBarCodeStyle;
begin
  Result.CheckSum := True;
  Result.ShowCode := True;
  Result.BarType := bcCode39;
  Result.Zoom := 1.0;
  Result.Angle := 0;
  Result.FrameColor := clBlack;
  Result.BorderLines := [];
  Result.FrameWidth := 1;
end;

function TlrCodeReport.PageCount: integer;
begin
  Result := Report.Pages.Count;
end;

function TlrCodeReport.TextWidth(AText: string): double;
begin
  ABitMap.Canvas.Font.Name := TextRectStyle.FontName;
  ABitMap.Canvas.Font.Size := TextRectStyle.FontSize;
  ABitMap.Canvas.Font.Style := TextRectStyle.FontStyle;
  Result := ABitMap.Canvas.TextWidth(AText);
end;

function TlrCodeReport.GetReport: TfrReport;
begin
  if FReport=nil then begin
    if FOwnedReport=nil then
      FOwnedReport := TFrReport.Create(nil);
    FReport := FOwnedReport;
  end;

  result := FReport;
end;

procedure TlrCodeReport.SetReport(AValue: TfrReport);
begin
  FReport := AValue;
end;

function TlrCodeReport.TextHeight: double;
begin
  ABitMap.Canvas.Font.Name := TextRectStyle.FontName;
  ABitMap.Canvas.Font.Size := TextRectStyle.FontSize;
  ABitMap.Canvas.Font.Style := TextRectStyle.FontStyle;
  Result := ABitMap.Canvas.TextHeight(' '); // assume all glyphs have same height
end;

procedure TlrCodeReport.DrawLine(X, Y, W, H: double; const Style: TlrLineStyle);
var
  aLine: TfrLineView;
begin
  aLine := TfrLineView.Create(nil);
  aLine.Left := X * XRatio;
  aLine.Top := Y * YRatio;
  aLine.Width := W * XRatio;
  aLine.Height := H * YRatio;
  aLine.FrameColor := Style.LColor;
  aLine.FrameWidth := Style.LWidth;
  aLine.FrameStyle := Style.LStyle;
  Report.Pages[ActivePage].Objects.Add(aLine);
end;

procedure TlrCodeReport.DrawHLine(X, Y, W: double);
begin
  DrawLine(X, Y, W, 0, LineStyle);
end;

procedure TlrCodeReport.DrawVLine(X, Y, H: double);
begin
  DrawLine(X, Y, 0, H, LineStyle);
end;

procedure TlrCodeReport.DrawFrame(X, Y, W, H: double; Style: TlrTextRectStyle);
begin
  DrawText(X, Y, W, H, '', Style);
end;

procedure TlrCodeReport.DrawFrame(X, Y, W, H: double);
begin
  DrawText(X, Y, W, H, '', FrameStyle);
end;

procedure TlrCodeReport.DrawText(X, Y, W, H: double; Text: string;
  Style: TlrTextRectStyle);
var
  AText: TfrMemoview;
begin
  AText := TfrMemoView.Create(nil);
  AText.Left := X * XRatio;
  AText.Top := Y * YRatio;
  AText.Width := W * XRatio;
  AText.Height := H * YRatio;
  AText.Angle := Style.Angle;

  AText.AutoSize := Style.Autosize;
  AText.Stretched := Style.Stretched;
  AText.WordWrap := Style.WordWrap;
  AText.WordBreak := Style.WordBreak;

  AText.FrameWidth := Style.Line.LWidth;
  AText.FrameColor := Style.Line.LColor;
  AText.FrameStyle := Style.Line.LStyle;

  AText.FillColor := Style.FillColor;
  AText.Frames := Style.BorderLines;

  AText.Font.Name := Style.FontName;
  AText.Font.Color := Style.FontColor;
  AText.Font.Size := Style.FontSize;
  AText.Font.Style := Style.FontStyle;

  AText.Alignment := Style.Alignment;
  AText.Layout := Style.Layout;

  AText.Memo.Add(Text);
  AText.CalcGaps;
  Report.Pages[ActivePage].Objects.Add(AText);
  // Update Cursor
  Cursor.YTop := AText.Top / YRatio; // adjust to ratio used
  Cursor.XTop := AText.Left / XRatio;
  Cursor.YBottom := (AText.Top + AText.Height) / YRatio; // adjust to ratio used
  Cursor.XBottom := (AText.Left + AText.Width) / XRatio;
end;

procedure TlrCodeReport.TextOut(AText: string);
begin
  DrawText(Cursor.Left + PageMargin.Left, Cursor.Top + PageMargin.Top,
    TextWidth(AText), TextHeight, AText, TextRectStyle);
  Cursor.Left += TextWidth(AText) / XRatio;
end;

procedure TlrCodeReport.TextOutLn(AText: string);
var
  ATop, ATextHeight: double;
begin
  ATextHeight := TextHeight / YRatio;
  ATop := Cursor.Top + ATextHeight;
  if ATop >= (GetPageHeight - PageMargin.Bottom - (2*ATextHeight)) then
    NewPage;
  TextOut(AText);
  Cursor.Left := 0;
  Cursor.Top += ATextHeight;

end;

procedure TlrCodeReport.TextOutXY(X, Y: double; AText: string; Alignment: TAlignment);
var
  Style: TlrTextRectStyle;
  Pos: double;
begin
  Style := TextRectStyle;
  Style.Alignment := Alignment;
  case Alignment of
    taLeftJustify: Pos := X;
    taRightJustify:
    begin
      Pos := X - TextWidth(AText) / XRatio;
    end;
    taCenter:
    begin
      Pos := X - (TextWidth(AText) / 2 / XRatio);
    end;
  end;
  DrawText(Pos, Y, TextWidth(AText) / XRatio + 2, TextHeight / YRatio, AText, Style);
  Cursor.Left += TextWidth(AText) / XRatio;
end;

procedure TlrCodeReport.TextOutRectXY(X, Y, W, H: double; AText: string;
  Alignment: TAlignment; Clipping: boolean);
var
  Style: TlrTextRectStyle;
begin
  Style := TextRectStyle;
  Style.Alignment := Alignment;
  Style.WordWrap := not Clipping;
  Style.Stretched := True;

  DrawText(X, Y, W, H, AText, Style);
end;

procedure TlrCodeReport.TextOutXYUp(X, Y: double; AText: string; Alignment: TAlignment);
var
  Style: TlrTextRectStyle;
  Pos: double;
begin
  Style := TextRectStyle;
  Style.Alignment := Alignment;
  Style.Angle := 90;
  case Alignment of
    taRightJustify: Pos := Y;
    taLeftJustify:
    begin
      Pos := Y - TextWidth(AText);
    end;
    taCenter:
    begin
      Pos := Y - (TextWidth(AText) / 2);
    end;
  end;
  DrawText(X, Pos, TextHeight, TextWidth(AText), AText, Style);
end;

procedure TlrCodeReport.DrawImage(X, Y, W, H: double; AImage: TImage;
  ASharedName: string; AStretched: boolean; AKeepAspect: boolean; ACentered: boolean);
begin
  DrawImage(X, Y, W, H, AImage.Picture, ASharedName, AStretched, AKeepAspect, ACentered);
end;

procedure TlrCodeReport.DrawImage(X, Y, W, H: double; APicture: TPicture;
  ASharedName: string; AStretched: boolean; AKeepAspect: boolean;
  ACentered: boolean);
var
  frPicture: TfrPictureView;
begin
  frPicture := TfrPictureView.Create(nil);
  frPicture.Left := X * XRatio;
  frPicture.Top := Y * YRatio;
  frPicture.Width := W * XRatio;
  frPicture.Height := H * YRatio;
  frPicture.SharedName := ASharedName;
  frPicture.Stretched := AStretched;
  frPicture.KeepAspect := AKeepAspect;
  frPicture.Centered := ACentered;
  frPicture.Picture.Assign(APicture);
  Report.Pages[ActivePage].Objects.Add(frPicture);
end;

procedure TlrCodeReport.DrawShape(X, Y, W, H: double; Style: TlrShapeStyle);
var
  AShape: TfrShapeView;
begin
  AShape := TfrShapeView.Create(nil);
  AShape.Left := X * XRatio;
  AShape.Top := Y * YRatio;
  AShape.Width := W * XRatio;
  AShape.Height := H * YRatio;
  AShape.FillColor := ShapeStyle.FillColor;
  AShape.FrameColor := ShapeStyle.FrameColor;
  AShape.FrameWidth := ShapeStyle.FrameWith;
  AShape.FrameStyle := ShapeStyle.FrameStyle;
  AShape.ShapeType := ShapeStyle.ShapeType;
  Report.Pages[ActivePage].Objects.Add(AShape);
end;

procedure TlrCodeReport.DrawRectangle(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstRectangle;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawRoundRectangle(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstRoundRect;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawDiagonalDownRight(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstDiagonal1;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawDiagonalUpRight(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstDiagonal2;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawEllipse(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstEllipse;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawTriangle(X, Y, W, H: double);
begin
  SaveShapeStyle;
  ShapeStyle.ShapeType := frstTriangle;
  DrawShape(X, Y, W, H, ShapeStyle);
  RestoreShapeStyle;
end;

procedure TlrCodeReport.DrawBarCode(X, Y, W, H: double; Code: string;
  Style: TlrBarCodeStyle);
var
  ABarCode: TfrBarcodeView;
begin
  ABarCode := TfrBarcodeView.Create(nil);
  ABarCode.Left := X * XRatio;
  ABarCode.Top := Y * YRatio;
  ABarCode.Width := W * XRatio;
  ABarCode.Height := H * YRatio;
  // Bar code
  ABarCode.Memo.Text := Code;
  ABarCode.CheckSum := Style.CheckSum;
  ABarCode.ShowText := Style.ShowCode;
  ABarCode.BarType := Style.BarType;
  ABarCode.Zoom := Style.Zoom;
  ABarCode.Param.cAngle := Style.Angle;
  ABarCode.FrameColor := Style.FrameColor;
  ABarCode.Frames := Style.BorderLines;
  ABarCode.FrameWidth := Style.FrameWidth;
  Report.Pages[ActivePage].Objects.Add(ABarCode);
end;

procedure TlrCodeReport.NewLine(i: word);
begin
  for i := 0 to i - 1 do
  begin
    TextOutLn('');
  end;
end;

end.

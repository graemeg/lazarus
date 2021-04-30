{
 *****************************************************************************
 *                               Gtk3WSButtons.pp                            *
 *                               ------------                                * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit Gtk3WSButtons;

{$mode objfpc}{$H+}
{$I gtk3defines.inc}

interface
////////////////////////////////////////////////////
// I M P O R T A N T                                
////////////////////////////////////////////////////
// 1) Only class methods allowed
// 2) Class methods have to be published and virtual
// 3) To get as little as posible circles, the uses
//    clause should contain only those LCL units 
//    needed for registration. WSxxx units are OK
// 4) To improve speed, register only classes in the 
//    initialization section which actually 
//    implement something
// 5) To enable your XXX widgetset units, look at
//    the uses clause of the XXXintf.pp
////////////////////////////////////////////////////
uses
////////////////////////////////////////////////////
// To get as little as posible circles,
// uncomment only when needed for registration
////////////////////////////////////////////////////
  Classes, Controls, Buttons, Graphics,
////////////////////////////////////////////////////
  WSLCLClasses, WSButtons, WSProc,
  Gtk3WSControls, LCLType, LCLIntf, LCLProc,
  gtk3widgets, LazGtk3, LazGdk3, LazGdkPixbuf2, LazGObject2;

type

  { TGtk3WSBitBtn }

  TGtk3WSBitBtn = class(TWSBitBtn)
  published
    class function CreateHandle(const AWinControl: TWinControl; const AParams: TCreateParams): TLCLIntfHandle; override;
    class procedure GetPreferredSize(const AWinControl: TWinControl;
                        var PreferredWidth, PreferredHeight: integer;
                        WithThemeSpace: Boolean); override;
    class procedure SetGlyph(const ABitBtn: TCustomBitBtn; const AValue: TButtonGlyph); override;
    class procedure SetLayout(const ABitBtn: TCustomBitBtn; const AValue: TButtonLayout); override;
    class procedure SetMargin(const ABitBtn: TCustomBitBtn; const AValue: Integer); override;
    class procedure SetSpacing(const ABitBtn: TCustomBitBtn; const AValue: Integer); override;
  end;
  TGtk3WSBitBtnClass = class of TGtk3WSBitBtn;

  { TGtk3WSSpeedButton }

  TGtk3WSSpeedButton = class(TWSSpeedButton)
  private
  protected
  public
  end;

implementation

uses
  graphtype,imglist,LResources, gtk3objects, gtk3procs;


{ TGtk3WSCustomBitBtn }

class function TGtk3WSBitBtn.CreateHandle(const AWinControl: TWinControl;
  const AParams: TCreateParams): TLCLIntfHandle;
var
  ABitBtn: TGtk3Button;
  ARect: TGdkRectangle;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.CreateHandle');
  {$ENDIF}
  ABitBtn := TGtk3Button.Create(AWinControl, AParams);
{  with ARect do
  begin
    x := AWinControl.Left;
    y := AWinControl.Top;
    width := AWinControl.Width;
    height := AWinControl.Height;
  end;

  ABitBtn.Widget^.set_allocation(@ARect);}

  Result := TLCLIntfHandle(ABitBtn);
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.CreateHandle Handle=',dbgs(Result));
  {$ENDIF}
end;

class procedure TGtk3WSBitBtn.GetPreferredSize(const AWinControl: TWinControl;
  var PreferredWidth, PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  if not WSCheckHandleAllocated(AWinControl, 'GetPreferredSize') then
    Exit;
  TGtk3Button(AWinControl.Handle).preferredSize(PreferredWidth, PreferredHeight, WithThemeSpace);
end;

class procedure TGtk3WSBitBtn.SetGlyph(const ABitBtn: TCustomBitBtn;
  const AValue: TButtonGlyph);
var
  AImage: PGtkImage;
  AGlyph: TBitmap;
  resolution:TCustomImageListResolution;
  ScaleFactor: Double;
  raw:TRawImage;
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.SetGlyph');
  {$ENDIF}
  if not WSCheckHandleAllocated(ABitBtn, 'SetGlyph') then
    Exit;
  if ABitBtn.CanShowGlyph(True) then
  begin
    { allocate image which would be cached in TGtk3Button instance }
    AGlyph := TBitmap.Create;
    ScaleFactor := ABitBtn.GetCanvasScaleFactor;
    if (ABitBtn.ImageIndex>=0) and Assigned(ABitBtn.Images) then
    begin
      { find imagelist scaled}
      resolution:=ABitBtn.Images.Resolution[round(AbitBtn.Images.Width*ScaleFactor)];
      resolution.GetRawImage(ABitBtn.ImageIndex,raw);
      { convice the bitmap it has actually another format }
      AGlyph.BeginUpdate();
     // raw.Description.Init_BPP32_R8G8B8A8_BIO_TTB(resolution.Width,resolution.Height);
      AGlyph.LoadFromRawImage(raw,false);
      AGlyph.EndUpdate();
    end else
      AGlyph.Assign(AValue.Glyph);

    if not AGlyph.Empty then
      AImage := gtk_image_new_from_pixbuf(TGtk3Image(AGlyph.Handle).Handle)
    else
      AImage := nil;
    if Assigned(AImage) then
      gtk_button_set_image(PGtkButton(TGtk3Button(ABitBtn.Handle).Widget), AImage)
    else
      PGtkButton(TGtk3Button(ABitBtn.Handle).Widget)^.always_show_image:=false;

    { store glyph to prevent leaks }
    TGtk3Button(ABitBtn.Handle).Image:=AGlyph;
  end;
end;

class procedure TGtk3WSBitBtn.SetLayout(const ABitBtn: TCustomBitBtn;
  const AValue: TButtonLayout);
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.SetLayout');
  {$ENDIF}
  if not WSCheckHandleAllocated(ABitBtn, 'SetLayout') then
    Exit;
  TGtk3Button(ABitBtn.Handle).Layout := Ord(AValue);
end;

class procedure TGtk3WSBitBtn.SetMargin(const ABitBtn: TCustomBitBtn;
  const AValue: Integer);
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.SetMargin');
  {$ENDIF}
  if not WSCheckHandleAllocated(ABitBtn, 'SetMargin') then
    Exit;
  TGtk3Button(ABitBtn.Handle).Margin := AValue;
end;

class procedure TGtk3WSBitBtn.SetSpacing(const ABitBtn: TCustomBitBtn;
  const AValue: Integer);
begin
  {$IFDEF GTK3DEBUGCORE}
  DebugLn('TGtk3WSBitBtn.SetSpacing');
  {$ENDIF}
  if not WSCheckHandleAllocated(ABitBtn, 'SetSpacing') then
    Exit;
  TGtk3Button(ABitBtn.Handle).Spacing := AValue;
end;

end.

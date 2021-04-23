{%MainUnit ../controls.pp}

{******************************************************************************
                                  TDragImageList
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

const
  // bad window handle. 0 is reserverd by DesktopWindow
  NoLockedWindow: HWND = High(PtrInt);
  
{ TDragImageList }

{
   TDragImageList.SetDragCursor
   sets drag cursor that is associated with drag image list
}
procedure TDragImageList.SetDragCursor(const AValue: TCursor);
begin
  if FDragCursor = AValue then exit;
  if Dragging then
  begin
    Screen.BeginTempCursor(AValue);
    Screen.EndTempCursor(DragCursor);
  end;
  FDragCursor := AValue;
end;

procedure TDragImageList.SetDragHotspot(const aDragHotspot: TPoint);
var
  R: TCustomImageListResolution;
begin
  Resolution[Width]; // create default resolution if needed
  for R in Resolutions do
    TDragImageListResolution(R).DragHotspot := Point(
      MulDiv(aDragHotspot.X, R.Width, Width),
      MulDiv(aDragHotspot.Y, R.Width, Width));
end;

{
  TDragImageList.Initialize
  set default values for properties
}
procedure TDragImageList.Initialize;
begin
  inherited Initialize;
  FDragCursor := crNone;
  FImageIndex := 0;
end;

{
  TDragImageList.BeginDrag
  Start dragging of drag image list
}
function TDragImageList.BeginDrag(Window: HWND; X, Y: Integer): Boolean;
begin
  Result := Resolution[Width].BeginDrag(Window, X, Y);
end;

{
  TDragImageList.DragLock
  Show drag image and locks updates of Window during drag operation
}
function TDragImageList.DragLock(Window: HWND; XPos, YPos: Integer): Boolean;
begin
  Result := GetDraggingResolution.DragLock(Window, XPos, YPos);
end;

{
  TDragImageList.DragMove
  Move dragging image to position X, Y
}
function TDragImageList.DragMove(X, Y: Integer): Boolean;
begin
  Result := GetDraggingResolution.DragMove(X, Y);
end;

{
  TDragImageList.DragUnlock
  Hide drag image and stop lock updates of Window during drag operation
}
procedure TDragImageList.DragUnlock;
begin
  GetDraggingResolution.DragUnlock;
end;

{
  Finish dragging of drag image list
}
function TDragImageList.EndDrag: Boolean;
begin
  Result := Resolution[Width].EndDrag;
end;

function TDragImageList.GetDragging: Boolean;
begin
  Result := GetDraggingResolution<>nil;
end;

function TDragImageList.GetDraggingResolution: TDragImageListResolution;
var
  R: TCustomImageListResolution;
begin
  for R in Resolutions do
  begin
    Result := TDragImageListResolution(R);
    if Result.Dragging then
      Exit;
  end;
  Result := nil;
end;

function TDragImageList.GetDragHotspot: TPoint;
begin
  Result := GetResolution(Width).DragHotspot;
end;

function TDragImageList.GetResolution(
  AImageWidth: Integer): TDragImageListResolution;
begin
  Result := TDragImageListResolution(inherited GetResolution(AImageWidth));
end;

function TDragImageList.GetResolutionClass: TCustomImageListResolutionClass;
begin
  Result := TDragImageListResolution;
end;

{
  TDragImageList.HideDragImage
  Hide dragging image without unlocking of window
}
procedure TDragImageList.HideDragImage;
var
  DragImageListResolution: TDragImageListResolution;
begin
  DragImageListResolution := GetDraggingResolution;
  if DragImageListResolution <> nil then
    DragImageListResolution.HideDragImage;
end;

{
  TDragImageList.SetDragImage
  Set index of dragging image and hotspot
}
function TDragImageList.SetDragImage(Index, HotSpotX, HotSpotY: Integer): Boolean;
var
  CurLockedWindow: HWND;
  CurDragPos: TPoint;
  R: TDragImageListResolution;
begin
  Result := True;
  R := GetDraggingResolution;
  if R<>nil then
  begin
    if (FImageIndex <> Index) or (R.DragHotSpot.X <> HotSpotX) or
       (R.DragHotSpot.Y <> HotSpotY) then
    begin
      FImageIndex := Index;
      R.DragHotSpot := Point(HotSpotX, HotSpotY);

      // restart dragging with new params
      CurLockedWindow := R.FLockedWindow;
      CurDragPos := R.FLastDragPos;
      R.EndDrag;
      R.BeginDrag(CurLockedWindow, CurDragPos.X, CurDragPos.Y);
    end;
  end;
end;

{
  TDragImageList.ShowDragImage
  Show dragging image
}
procedure TDragImageList.ShowDragImage;
var
  DragImageListResolution: TDragImageListResolution;
begin
  DragImageListResolution := GetDraggingResolution;
  if DragImageListResolution <> nil then
    DragImageListResolution.ShowDragImage;
end;

{ TDragImageListResolution }

constructor TDragImageListResolution.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  FLastDragPos := Point(0, 0);
  FLockedWindow := NoLockedWindow;
end;

function TDragImageListResolution.BeginDrag(Window: HWND; X,
  Y: Integer): Boolean;
begin
  Result := TWSDragImageListResolutionClass(WidgetSetClass).BeginDrag(Self, Window,
    ImageList.FImageIndex, FDragHotspot.X, FDragHotspot.Y);
  FDragging := Result;
  if Result then
  begin
    DragLock(Window, X, Y);
    Screen.BeginTempCursor(ImageList.DragCursor);
  end;
end;

function TDragImageListResolution.DragLock(Window: HWND; XPos,
  YPos: Integer): Boolean;
begin
  Result := ImageList.Dragging;
  if not Result then
  begin
    Result := BeginDrag(Window, XPos, YPos);
    Exit;
  end;

  if Window <> FLockedWindow then
  begin
    if FLockedWindow <> NoLockedWindow then
      DragUnlock;
    FLockedWindow := Window;
    Result := TWSDragImageListResolutionClass(WidgetSetClass).ShowDragImage(Self, Window,
      XPos, YPos, True);
    if Result then
      FLastDragPos := Point(XPos, YPos);
  end;
end;

function TDragImageListResolution.DragMove(X, Y: Integer): Boolean;
begin
  Result := Dragging and TWSDragImageListResolutionClass(WidgetSetClass).DragMove(Self, X, Y);
  if Result then
    FLastDragPos := Point(X, Y);
end;

procedure TDragImageListResolution.DragUnlock;
begin
  if Dragging then
  begin
    TWSDragImageListResolutionClass(WidgetSetClass).HideDragImage(Self, FLockedWindow, True);
    FLockedWindow := NoLockedWindow;
    FLastDragPos := Point(0, 0);
  end;
end;

function TDragImageListResolution.EndDrag: Boolean;
begin
  Result := Dragging;
  if not Result then
    Exit;

  DragUnlock;
  TWSDragImageListResolutionClass(WidgetSetClass).EndDrag(Self);
  FDragging := False;
  Screen.EndTempCursor(ImageList.DragCursor);
end;

function TDragImageListResolution.GetHotSpot: TPoint;
begin
  Result := FDragHotspot;
end;

function TDragImageListResolution.GetImageList: TDragImageList;
begin
  Result := TDragImageList(inherited ImageList);
end;

procedure TDragImageListResolution.HideDragImage;
begin
  if Dragging then
    TWSDragImageListResolutionClass(WidgetSetClass).HideDragImage(Self, 0, False);
end;

procedure TDragImageListResolution.ShowDragImage;
begin
  if Dragging then
    TWSDragImageListResolutionClass(WidgetSetClass).ShowDragImage(Self, 0, 0, 0, False);
end;

class procedure TDragImageListResolution.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterDragImageListResolution;
end;

{ TImageListHelper }

procedure TImageListHelper.DrawForControl(ACanvas: TCanvas; AX, AY, AIndex,
  AImageWidthAt96PPI: Integer; AControl: TControl; AEnabled: Boolean);
begin
  DrawForPPI(ACanvas, AX, AY, AIndex, AImageWidthAt96PPI,
    AControl.Font.PixelsPerInch, AControl.GetCanvasScaleFactor, AEnabled);
end;

procedure TImageListHelper.DrawForControl(ACanvas: TCanvas; AX, AY, AIndex,
  AImageWidthAt96PPI: Integer; AControl: TControl;
  ADrawEffect: TGraphicsDrawEffect);
begin
  DrawForPPI(ACanvas, AX, AY, AIndex, AImageWidthAt96PPI,
    AControl.Font.PixelsPerInch, AControl.GetCanvasScaleFactor, ADrawEffect);
end;

function TImageListHelper.GetResolutionForControl(AImageWidth: Integer;
  AControl: TControl): TScaledImageListResolution;
begin
  Result := ResolutionForPPI[AImageWidth, AControl.Font.PixelsPerInch, AControl.GetCanvasScaleFactor];
end;

// included by controls.pp

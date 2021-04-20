{%MainUnit ../stdctrls.pp}
{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

class procedure TCustomGroupBox.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomGroupBox;
end;

class function TCustomGroupBox.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 185;
  Result.CY := 105;
end;

procedure TCustomGroupBox.SetParentBackground(const AParentBackground: Boolean);
begin
  inherited SetParentBackground(AParentBackground);

  if AParentBackground then
    if (ParentColor) and Assigned(Parent) then
      Color := Parent.Color
    else
      Color := clDefault;

  UpdateOpaque;
end;

procedure TCustomGroupBox.UpdateOpaque;
begin
  if ParentBackground then
    ControlStyle := ControlStyle - [csOpaque]
  else
    ControlStyle := ControlStyle + [csOpaque];
end;

procedure TCustomGroupBox.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or BS_GROUPBOX;
end;

procedure TCustomGroupBox.SetColor(Value: TColor);
begin
  inherited SetColor(Value);
  if Color = clDefault then Exit;
  if Assigned(Parent) and (Value = Parent.Color) then Exit;
  ParentBackground := False;
end;

{------------------------------------------------------------------------------
  function TCustomGroupBox.Create
------------------------------------------------------------------------------}
constructor TCustomGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fCompStyle := csGroupBox;
  ControlStyle := ControlStyle + [csAcceptsControls, csParentBackground];
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
end;

procedure TCustomGroupBox.CMParentColorChanged(var Message: TLMessage);
begin
  inherited;

  if csLoading in ComponentState then Exit;

  UpdateOpaque;
end;

// included by stdctrls.pp

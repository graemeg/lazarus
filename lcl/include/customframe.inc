{%MainUnit ../forms.pp}

{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{ TCustomFrame }

procedure TCustomFrame.AddActionList(ActionList: TCustomActionList);
var
  ParentForm: TCustomForm;
begin
  ParentForm := GetParentForm(Self);
  if ParentForm <> nil then
    ParentForm.DoAddActionList(ActionList);
end;

procedure TCustomFrame.RemoveActionList(ActionList: TCustomActionList);
var
  ParentForm: TCustomForm;
begin
  ParentForm:=GetParentForm(Self);
  if (ParentForm<>nil) then
    ParentForm.DoRemoveActionList(ActionList);
end;

procedure TCustomFrame.ReadDesignLeft(Reader: TReader);
var
  Temp: LongInt;
begin
  Temp:=DesignInfo;
  LazLongRec(Temp).Lo:=Reader.ReadInteger;
  DesignInfo:=Temp;
end;

procedure TCustomFrame.ReadDesignTop(Reader: TReader);
var
  Temp: LongInt;
begin
  Temp:=DesignInfo;
  LazLongRec(Temp).Hi:=Reader.ReadInteger;
  DesignInfo:=Temp;
end;

procedure TCustomFrame.WriteDesignLeft(Writer: TWriter);
begin
  Writer.WriteInteger(LazLongRec(DesignInfo).Lo);
end;

procedure TCustomFrame.WriteDesignTop(Writer: TWriter);
begin
  Writer.WriteInteger(LazLongRec(DesignInfo).Hi);
end;

class procedure TCustomFrame.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterCustomFrame;
end;

procedure TCustomFrame.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
  OwnedComponent: TComponent;
begin
  // behave as TCustomForm

  inherited GetChildren(Proc, Root);
  if Root = Self then
    for I := 0 to ComponentCount - 1 do
    begin
      OwnedComponent := Components[I];
      if not OwnedComponent.HasParent then
        Proc(OwnedComponent);
    end;
end;

procedure TCustomFrame.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);

  case Operation of
    opInsert:
      if AComponent is TCustomActionList then
        AddActionList(TCustomActionList(AComponent));
    opRemove:
      if AComponent is TCustomActionList then
        RemoveActionList(TCustomActionList(AComponent));
  end;
end;

procedure TCustomFrame.SetColor(Value: TColor);
begin
  inherited SetColor(Value);
  if Color = clDefault then Exit;
  if Assigned(Parent) and (Value = Parent.Color) then Exit;
  ParentBackground := False;
end;

procedure TCustomFrame.SetParent(AParent: TWinControl);

  procedure UpdateActionLists(Root: TComponent; Operation: TOperation);
  var
    i: Integer;
    AComponent: TComponent;
  begin
    for i := 0 to Root.ComponentCount - 1 do
    begin
      AComponent := Root.Components[i];
      if AComponent is TCustomActionList then
        case Operation of
          opInsert: AddActionList(TCustomActionList(AComponent));
          opRemove: RemoveActionList(TCustomActionList(AComponent));
        end;
      // update nested frames
      if csInline in AComponent.ComponentState then
        UpdateActionLists(AComponent,Operation);
    end;
  end;

var
  ParentForm: TCustomForm;
begin
  if Parent=AParent then exit;
  if Parent<>nil then
    UpdateActionLists(Self,opRemove);

  if (Parent=nil) and HandleAllocated then
    DestroyHandle;
  inherited SetParent(AParent);
  if Parent <> nil then
  begin
    UpdateActionLists(Self,opInsert);

    ParentForm := GetParentForm(Self);
    if Application.Scaled and (ParentForm<>nil) and ParentForm.Scaled
    and (ParentForm.PixelsPerInch<>PixelsPerInch) then
      AutoAdjustLayout(lapAutoAdjustForDPI, PixelsPerInch, ParentForm.PixelsPerInch, 0, 0);
  end;
end;

procedure TCustomFrame.SetParentBackground(const AParentBackground: Boolean);
begin
  inherited SetParentBackground(AParentBackground);

  if AParentBackground then
    if (ParentColor) and Assigned(Parent) then
      Color := Parent.Color
    else
      Color := clDefault;

  UpdateOpaque;
end;

procedure TCustomFrame.CMParentColorChanged(var Message: TLMessage);
begin
  inherited;
  if csLoading in ComponentState then Exit;
  UpdateOpaque;
end;

class function TCustomFrame.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 320;
  Result.CY := 240;
end;

procedure TCustomFrame.DefineProperties(Filer: TFiler);
Var
  Ancestor: TComponent;
  Temp: LongInt;
begin
  Temp:=0;
  Ancestor:=TComponent(Filer.Ancestor);
  if Assigned(Ancestor) then Temp:=Ancestor.DesignInfo;
  Filer.Defineproperty('DesignLeft',@ReadDesignLeft,@WriteDesignLeft,
                       (LazLongRec(DesignInfo).Lo<>LazLongrec(Temp).Lo));
  Filer.Defineproperty('DesignTop',@ReadDesignTop,@WriteDesignTop,
                       (LazLongRec(DesignInfo).Hi<>LazLongrec(Temp).Hi));
end;

procedure TCustomFrame.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);
begin
  if (csDesigning in ComponentState) and (Owner=nil) then begin
    // frame is root component at designtime
    // => keep it free resiable
    exit;
  end;
  inherited CalculatePreferredSize(PreferredWidth, PreferredHeight,
    WithThemeSpace);
end;

procedure TCustomFrame.UpdateOpaque;
begin
  if ParentBackground then
    ControlStyle := ControlStyle - [csOpaque]
  else
    ControlStyle := ControlStyle + [csOpaque];
end;

constructor TCustomFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption,
                   csDoubleClicks, csParentBackground];
  if (ClassType<>TFrame) and ([csDesignInstance, csDesigning]*ComponentState=[]) then
  begin
    if not InitInheritedComponent(Self, TFrame) then
      raise EResNotFound.CreateFmt(rsResourceNotFound, [ClassName]);
  end
  else
    with GetControlClassDefaultSize do
      SetInitialBounds(0, 0, CX, CY);
end;

{ TFrame }

function TFrame.LCLVersionIsStored: boolean;
begin
  Result := Parent = nil;
end;

constructor TFrame.Create(TheOwner: TComponent);
begin
  FLCLVersion := lcl_version;
  inherited Create(TheOwner);
end;

// included by forms.pp

{%MainUnit spinex.pp}

{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

}

const
  NvbStrings: Array[TNullValueBehaviour] of string = (
    'nvbShowTextHint',
    'nvbLimitedNullValue',
    'nvbMinValue',
    'nvbMaxValue',
    'nvbInitialValue'
  );

  Digits = ['0'..'9'];
  AllowedControlChars = [#8,#9,^C,^X,^V,^Z];

function DbgS(ANvb: TNullValueBehaviour): String;
begin
  Result := NvbStrings[ANvb];
end;

{ TSpinEditEx }


procedure TSpinEditExBase.UpdateControl;
var
  ANumber: T;
begin
  //if (MaxValue < MinValue) then FMaxValue := MinValue;
  if (FNullValueBehaviour <> nvbShowTextHint) then
    FValue := GetLimitedValue(FValue);
  if (not HandleAllocated) then Exit;

  if ([csLoading, csDestroying] * ComponentState <> []) then
    FUpdatePending := True
  else
  begin
    FUpdatePending := False;
    //Update the Text
    if (FNullValueBehaviour = nvbShowTextHint) then
    begin
      if not FSettingValue then
      begin
        if TextIsNumber(Text, ANumber) then
          Text := ValueToStr(GetLimitedValue(ANumber))
        else
          Text := EmptyStr;
      end
      else
      begin
        if IsOutOfLimits(FValue) then
          Text := EmptyStr
        else
          Text := ValueToStr(FValue);
      end;
    end
    else
      Text := ValueToStr(GetLimitedValue(FValue));
  end;
end;

procedure TSpinEditExBase.UpDownChangingEx(Sender: TObject;
  var AllowChange: Boolean; NewValue: SmallInt; Direction: TUpDownDirection);
begin
  if ReadOnly then Exit;
  Case Direction of
    updUp: SpinUpDown(True);
    updDown: SpinUpDown(False);
  end;
end;

procedure TSpinEditExBase.UpDownClick(Sender: TObject; {%H-}Button: TUDBtnType);
begin
  BuddyClick;
end;

function TSpinEditExBase.GetBuddyClassType: TControlClass;
begin
  Result := TUpDown;
end;

procedure TSpinEditExBase.DoEnter;
begin
  inherited DoEnter;
  FInitialValue := GetValue;
end;

function TSpinEditExBase.RealGetText: TCaption;
begin
  if HandleAllocated then
    Result := inherited RealGetText
  else
    Result := ValueToStr(FValue);
end;

procedure TSpinEditExBase.Reset;
begin
  if IsMasked then
    inherited Reset
  else
    Value := FInitialValue;
end;

procedure TSpinEditExBase.EditEditingDone;
begin
  inherited EditEditingDone;
  GetValue;
  {$ifdef debugspinex}
  debugln(['TSpinEditExBase.EditingDone:']);
  debugln(['  FValue = ',FValue,' Text = "',Text,'"']);
  {$endif}
  UpdateControl;
end;

procedure TSpinEditExBase.EditKeyPress(var Key: Char);
begin
  inherited EditKeyPress(Key);
  if not KeyAllowed(Key) then
    Key := #0;
end;

procedure TSpinEditExBase.EditUtf8KeyPress(var UTF8Key: TUTF8Char);
begin
  inherited EditUtf8KeyPress(UTF8Key);
  if not Utf8KeyAllowed(Utf8Key) then
    Utf8Key := '';
end;

procedure TSpinEditExBase.EditChange;
begin
  {$ifdef debugspinex}
  debugln('TSpinEditExBase.EditChange');
  {$endif}
  inherited EditChange;
end;

procedure TSpinEditExBase.EditKeyDown(var Key: word; Shift: TShiftState);
begin
  inherited EditKeyDown(Key, Shift);
  if (Key = VK_Escape) and (Shift = []) then
  begin
    Key := 0;
    Reset;
  end
  else
  if FArrowKeys and (Key = VK_UP) and (Shift = []) then
  begin
    //disable the key also if ReadOnly = True, so it won;t suddenly start moving the caret (which it doesn't if ArroKeys = True)
    Key := 0;
    if not ReadOnly then
      SpinUpDown(True);
  end
  else
  if FArrowKeys and (Key = VK_Down) and (Shift = []) then
  begin
    Key := 0;
    if not ReadOnly then
      SpinUpDown(False);
  end
end;

procedure TSpinEditExBase.SetMaxValue(const AValue: T);
begin
  if FMaxValue = AValue then Exit;
  FMaxValue := AValue;
  UpdateControl;
end;

procedure TSpinEditExBase.SetMinValue(const AValue: T);
begin
  if FMinValue = AValue then Exit;
  FMinValue := AValue;
  UpdateControl;
end;

procedure TSpinEditExBase.SetIncrement(const AIncrement: T);
begin
  if AIncrement = FIncrement then Exit;
  if AIncrement > 0 then
    FIncrement := AIncrement
  else
    FIncrement := -AIncrement;
end;

procedure TSpinEditExBase.InitializeWnd;
begin
  inherited InitializeWnd;
  UpdateControl;
end;

procedure TSpinEditExBase.Loaded;
begin
  inherited Loaded;
  UpDown.MinRepeatInterval := FMinRepeatValue;
  if FUpdatePending then UpdateControl;
end;

function TSpinEditExBase.MaxValueStored: Boolean;
begin
  Result := not SameValue(FMaxValue, DefMaxValue);
end;

function TSpinEditExBase.MinValueStored: Boolean;
begin
  Result := not SameValue(FMinValue, DefMinValue);
end;

procedure TSpinEditExBase.EditMouseWheelUp(Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  inherited EditMouseWheelUp(Shift, MousePos, Handled);
  if not Handled then
    SpinUpDown(True);
end;

procedure TSpinEditExBase.EditMouseWheelDown(Shift: TShiftState;
  MousePos: TPoint; var Handled: Boolean);
begin
  inherited EditMouseWheelDown(Shift, MousePos, Handled);
  if not Handled then
    SpinUpDown(False);
end;

procedure TSpinEditExBase.SetValue(const AValue: T);
var
  ValueFromText: T;
begin
  {$ifdef debugspinex}
  debugln(['TSpinEditExBase.SetValue: AValue = ',AValue, ' , FValue=',FValue,' Text="',Text,'"']);
  {$endif}
  if (FValue = AValue)
    //if you set text by code (or paste it) and text is not a valid float, then FValue will hold the previous value
    //and in that case we should not exit here...
    and ({TryStrToFloat(Text, ValueFromText, FFS)} TextIsNumber(Text, ValueFromText) and (ValueFromText = FValue)) then Exit;
  FSettingValue := True;
  FValue := AValue;

  FUpdatePending := True;
  UpdateControl;
  FSettingValue := False;
end;

function TSpinEditExBase.GetValue: T;
begin
  if HandleAllocated
    and not (wcfCreatingHandle in FWinControlFlags) then
  begin
    FValue := StrToValue(Text);
  end;
  Result := FValue;
end;

function TSpinEditExBase.IncrementStored: Boolean;
begin
  Result := not SameValue(FIncrement, DefIncrement);
end;

function TSpinEditExBase.IsLimited: Boolean;
begin
  Result := MaxValue > MinValue;
end;

function TSpinEditExBase.IsOutOfLimits(AValue: T): Boolean;
begin
  Result := IsLimited and ((AValue < MinValue) or (AValue > MaxValue));
end;

function TSpinEditExBase.GetEdit: TGEEdit;
begin
  Result := BaseEditor;
end;

procedure TSpinEditExBase.SetMinRepeatValue(AValue: Byte);
begin
  if FMinRepeatValue = AValue then Exit;
  FMinRepeatValue := AValue;
  if not (csLoading in ComponentState) then
    UpDown.MinRepeatInterval := FMinRepeatValue;
end;

procedure TSpinEditExBase.SpinUpDown(Up: Boolean);
var
  OldValue, NewValue: T;
begin
  if not TextIsNumber(Text, OldValue) then
    NewValue := MinValue
  else
  begin
    if IsOutOfLimits(OldValue) then
      NewValue := GetLimitedValue(OldValue)
    else
    begin
      if Up then
        NewValue := GetLimitedValue(SafeInc(OldValue))
      else
        NewValue := GetLimitedValue(SafeDec(OldValue));
    end;
  end;
  SetValue(NewValue);
end;

function TSpinEditExBase.GetNullValue: T;
begin
  Result := FNullValue;
end;

function TSpinEditExBase.GetUpDown: TUpDown;
begin
  Result := TUpDown(Buddy);
end;

procedure TSpinEditExBase.SetNullValue(AValue: T);
begin
  if (FNullValue = AValue) then Exit;
  FNullValue := AValue;
  UpdateControl;
end;

constructor TSpinEditExBase.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  FArrowKeys := True;
  FIncrement := DefIncrement;
  FMaxValue := DefMaxValue;
  FMinValue := DefMinValue;
  FUpdatePending := True;
  FSettingValue := False;
  FNullValueBehaviour := nvbMinValue;
  FMinRepeatValue := DefMinRepeatValue;

  UpDown.ControlStyle := UpDown.ControlStyle + [csNoDesignVisible];
  Edit.Alignment := taRightJustify;

  {
    A note regarding the Updown control.
    It is by design that UpDown is not set to associate with the Edit.
    Amongst others, it would make it impossible to use with floats,
    nor have a NullValue.
    It also does align as it should when associated.
  }
  UpDown.OnChangingEx := @UpDownChangingEx;
  //OnCick signature of TUpDown differs from TControl.OnClick,
  //Yhe assigning of OnClick in inherited constructor
  //sets TControl(Buddy).OnClick to fire BuddyClick, and that won't do
  //since TUpDown does not fire a regular TControl.OnClick event
  UpDown.OnClick := @UpDownClick;

  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
end;

function TSpinEditExBase.GetLimitedValue(const AValue: T): T;
begin
  Result := AValue;
  //Delphi does not constrain when MinValue = MaxValue, and does if MaxValue < MinValue,
  //but the latter makes absolutely no sense at all.
  if FMaxValue > FMinValue then
  begin
    if Result < FMinValue then Result := FMinValue;
    if Result > FMaxValue then Result := FMaxValue;
  end;
end;

function TSpinEditExBase.StrToValue(const S: String): T;
var
  Def, N: T;
begin
  {$ifdef debugspinex}
  debugln(['TSpinEditExBase.StrToValue: S="',S,'"']);
  {$endif}
  case FNullValueBehaviour of
    nvbShowTextHint: Def := FNullValue;
    nvbLimitedNullValue: Def := GetLimitedValue(FNullValue);
    nvbMinValue: Def := FMinValue;
    nvbMaxValue: Def := MaxValue;
    nvbInitialValue: Def := FInitialValue;
  end;
  try
    if TextIsNumber(S, N) then
      Result := N
    else
      Result := Def;
    if not (FNullValueBehaviour = nvbShowTextHint) then
      Result := GetLimitedValue(Result);
  except
    Result := Def;
  end;
  {$ifdef debugspinex}
  debugln(['  Result=',(Result)]);
  {$endif}
end;

function TSpinEditExBase.KeyAllowed(Key: Char): Boolean;
begin
  Result := True;
end;

function TSpinEditExBase.Utf8KeyAllowed(Key: TUTF8Char): Boolean;
begin
  Result := True;
end;

procedure TSpinEditExBase.FinalizeWnd;
begin
  GetValue;
  inherited FinalizeWnd;
end;


{ TCustomFloatSpinEditEx }

function TCustomFloatSpinEditEx.GetDecimalSeparator: Char;
begin
  Result := FFS.DecimalSeparator;
end;

procedure TCustomFloatSpinEditEx.SetDecimalSeparator(AValue: Char);
begin
  if (AValue = FFS.DecimalSeparator) then Exit;
  FFS.DecimalSeparator := AValue;
  UpdateControl;
end;

procedure TCustomFloatSpinEditEx.SetDisplayMode(AValue: TDisplayMode);
begin
  if FDisplayMode = AValue then Exit;
  GetValue;
  FDisplayMode := AValue;
  UpdateControl;
end;

procedure TCustomFloatSpinEditEx.SetExponentDigits(AValue: Integer);
begin
  if FExponentDigits = AValue then Exit;
  GetValue;
  FExponentDigits := AValue;
  UpdateControl;
end;

procedure TCustomFloatSpinEditEx.SetExponentialFormatLimitNeg(AValue: Integer);
begin
  if (FExponentialFormatLimitNeg = AValue) or (AValue > -1) then Exit;
  GetValue;
  FExponentialFormatLimitNeg := AValue;
  UpdateControl;
end;

procedure TCustomFloatSpinEditEx.SetExponentialFormatLimitPos(AValue: Integer);
begin
  if (FExponentialFormatLimitPos = AValue) or (AValue < 0) then Exit;
  GetValue;
  FExponentialFormatLimitPos := AValue;
  UpdateControl;
end;

procedure TCustomFloatSpinEditEx.SetPrecision(AValue: Integer);
begin
  if FPrecision = AValue then Exit;
  GetValue;
  FPrecision := AValue;
  UpdateControl;
end;

function TCustomFloatSpinEditEx.GetFormatsettings: TFormatSettings;
begin
  Result := FFS;
end;

procedure TCustomFloatSpinEditEx.EditKeyPress(var Key: char);
begin
  if (Key in ['.',',']) then Key := FFS.Decimalseparator;
  inherited EditKeyPress(Key);
end;

function TCustomFloatSpinEditEx.TextIsNumber(const S: String; out ANumber: Double
  ): Boolean;
begin
  {$ifdef debugspinex}
  DbgOut(['TextIsNumber, S ="',S,'": Result = ']);
  {$endif}
  try
    Result := TryStrToFloat(S, ANumber, FFS);
  except
    Result := False;
  end;
  {$ifdef debugspinex}
  debugln([Result]);
  {$endif}
end;

function TCustomFloatSpinEditEx.SafeInc(AValue: Double): Double;
begin
  if ((AValue > 0) and (AValue > (MaxDouble-FIncrement))) then
    Result := MaxDouble
  else
    Result := AValue + FIncrement;
end;

function TCustomFloatSpinEditEx.SafeDec(AValue: Double): Double;
begin
  if (AValue < 0) and ((-MaxDouble + FIncrement) > AValue) then
    Result := -MaxDouble
  else
    Result := AValue - FIncrement;
end;

procedure TCustomFloatSpinEditEx.SetDecimals(ADecimals: Integer);
begin
  if (FDecimals = ADecimals) or (ADecimals < 0) then Exit;
  //if we increment DecimalPlaces first set FValue to correctly have the current DecimalPlaces decimals,
  //and only then do the increment (GetValue will update FValue to have FDecimalPlaces decimals)
  //Issue #0034370
  if (ADecimals > FDecimals) then GetValue;
  FDecimals := ADecimals;
  UpdateControl;
end;


function TCustomFloatSpinEditEx.ValueToStr(const AValue: Double): String;
var
  LValue: Double;
begin
  LValue := GetLimitedValue(AValue);
  case FDisplayMode of
    dmFixed:
    begin
      Result := FloatToStrF(LValue, ffFixed, 20, DecimalPlaces, FFS)
    end;
    dmScientific:
    begin
      Result := FloatToStrF(LValue, ffExponent, FPrecision, FExponentDigits, FFS)
    end;
    dmAuto,dmAutoZeroFixed:
    begin
      //it is safe to use (LValue=0.0) and not SameValue, since this is about text input
      //and '0.0000' as text will be converted to a bitpattern of all zero's
      if not ((FDisplayMode = dmAutoZeroFixed) and (LValue = 0.0)) and
         (
           (Abs(LValue) > Power(10,FExponentialFormatLimitPos)) or
           (Abs(LValue) < Power(10,FExponentialFormatLimitNeg))
         ) then
        Result := FloatToStrF(LValue, ffExponent, FPrecision, FExponentDigits, FFS)
      else
        Result := FloatToStrF(LValue, ffFixed, 20, DecimalPlaces, FFS)
    end;
  end;
end;

function TCustomFloatSpinEditEx.KeyAllowed(Key: Char): Boolean;
begin
  {
   Disallow any key that is not a digit, decimalseparator or '+', '-' or 'E/e'
   For ease of use translate any decimalpoint or comma to DecimalSeparator
   Tab, BackSpace, Cut, Paste, Copy, Undo of course should be passed onto inherited KeyPress
   If FDecimals = 0, disallow decimalseparator also
  }
  Result := (Key in (Digits + AllowedControlChars + [FFS.DecimalSeparator,'-','+','e','E']));
  if Result and (Key = FFS.DecimalSeparator) and (FDecimals = 0) then
    Result := False;
end;


constructor TCustomFloatSpinEditEx.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FFS := DefaultFormatSettings;
  FFS.DecimalSeparator := DefDecimalSeparator;
  FDecimals := DefDecimals;
  FExponentialFormatLimitPos := 6;
  FExponentialFormatLimitNeg := -6;
  FPrecision := 6;
  FExponentDigits := 2;
  FDisplayMode := dmFixed;
end;



{ TCustomSpinEditEx }

function InsertThousandSeparator(const ValueS, AThousandSep: String): String;
// A bit more complicated, but 3 times faster than repeated Insert() calls
var
  ResLen, ResPos, SLen, i, j: Integer;
begin
  if (AThousandSep = '') then
    Exit(ValueS);
  Result := '';
  SLen := Length(ValueS);
  //Needed separators = ((SLen - 1) div 3)
  ResLen := SLen + ((SLen - 1) div 3) * Length(AThousandSep);
  SetLength(Result, ResLen);
  ResPos := ResLen;
  for i := Length(ValueS) downto 1 do
  begin
    if (SLen <> i) and ((SLen-i) mod 3 = 0) then
    begin
      for j := Length(AThousandSep) downto 1 do
      begin
        Result[ResPos] := AThousandSep[j];
        Dec(ResPos);
      end;
    end;
    Result[ResPos] := ValueS[i];
    Dec(ResPos);
  end;
end;

function RemoveThousandSeparator(const ValueS: String; AThousandSeparator: String): String;
begin
  if (AThousandSeparator = '') then
    Result := ValueS
  else
    Result := StringReplace(ValueS, AThousandSeparator, '', [rfReplaceAll]);
end;

procedure TCustomSpinEditEx.SetThousandSeparator(AValue: String);
begin
  if FThousandSeparator = AValue then Exit;
  FThousandSeparator := AValue;
  UpdateControl;
end;


function TCustomSpinEditEx.SafeInc(AValue: Int64): Int64;
begin
  if ((AValue > 0) and (AValue > (High(Int64)-FIncrement))) then
    Result := High(Int64)
  else
    Result := AValue + FIncrement;
end;

function TCustomSpinEditEx.SafeDec(AValue: Int64): Int64;
begin
  if (AValue < 0) and ((Low(Int64) + FIncrement) > AValue) then
    Result := Low(Int64)
  else
    Result := AValue - FIncrement;
end;

function TCustomSpinEditEx.TextIsNumber(const S: String; out ANumber: Int64
  ): Boolean;
var
  N: Int64;
begin
  {$ifdef debugspinex}
  DbgOut(['TCustomSpinEditEx.TextIsNumber: S = "',S,'" Result = ']);
  {$endif}

  try
    Result := TryStrToInt64(RemoveThousandSeparator(S, FThousandSeparator), N);
    ANumber := N;
  except
    Result := False;
  end;
  {$ifdef debugspinex}
  debugln([Result]);
  {$endif}
end;


function TCustomSpinEditEx.ValueToStr(const AValue: Int64): String;
begin
  Result := IntToStr(AValue);
  if (FThousandSeparator <> '') then
    Result := InsertThousandSeparator(Result, FThousandSeparator);
end;

function TCustomSpinEditEx.KeyAllowed(Key: Char): Boolean;
begin
  {Disallow any key that is not a digit or - or (part of) FThousandSeparator
   Tab, BackSpace, Cut, Paste, Copy, Undo of course should be passed onto inherited KeyPress
  }
  Result := ((Key in (Digits + AllowedControlChars + ['-'])) or (Pos(Key, FThousandSeparator) > 0));
  if Result and (Key = '-') and IsLimited and (MinValue >= 0) then
    Result := False;
end;

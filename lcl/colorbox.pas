{
  TColorBox is component that displays colors in a combobox
  TColorListBox is component that displays colors in a listbox

  Copyright (C) 2005 Darius Blaszijk

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

unit ColorBox;

{$mode objfpc}
{$H+}

interface

uses
  LResources, SysUtils, Types, Classes,
  LCLProc, LCLType, LCLStrConsts, Graphics, Controls, Forms, Dialogs, StdCtrls,
  LazStringUtils;

const
  cDefaultColorRectWidth = 14;
  cDefaultColorRectOffset = 3;

type
  { TCustomColorBox }

  TCustomColorBox = class;
  TColorBoxStyles = (cbStandardColors, // 16 standard colors (look at graphics.pp)
                     cbExtendedColors, // 4 extended colors (look at graphics.pp)
                     cbSystemColors,   // system colors (look at graphics.pp)
                     cbIncludeNone,    // include clNone
                     cbIncludeDefault, // include clDefault
                     cbCustomColor,    // first color is customizable
                     cbPrettyNames,    // use good looking color names - like Red for clRed
                     cbCustomColors);  // call OnGetColors after all other colors processing
  TColorBoxStyle = set of TColorBoxStyles;
  TGetColorsEvent = procedure(Sender: TCustomColorBox; Items: TStrings) of object;

  TCustomColorBox = class(TCustomComboBox)
  private
    FColorRectWidth: Integer;
    FColorRectOffset: Integer;
    FDefaultColorColor: TColor;
    FNoneColorColor: TColor;
    FcolorDialog:TColorDialog;
    FOnGetColors: TGetColorsEvent;
    FStyle: TColorBoxStyle;
    FSelected: TColor;
    function GetColor(Index : Integer): TColor;
    function GetColorName(Index: Integer): string;
    function GetColorRectWidth: Integer;
    function GetSelected: TColor;
    procedure SetColorRectWidth(AValue: Integer);
    procedure SetColorRectOffset(AValue: Integer);
    procedure SetDefaultColorColor(const AValue: TColor);
    procedure SetNoneColorColor(const AValue: TColor);
    procedure SetSelected(Value: TColor);
    procedure SetStyle(const AValue: TColorBoxStyle); reintroduce;
    procedure ColorProc(const s: AnsiString);
    procedure UpdateCombo;
  protected
    function ColorRectWidthStored: Boolean;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure SetColorList;
    procedure Loaded; override;
    procedure InitializeWnd; override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure DoGetColors; virtual;
    procedure CloseUp; override;
    function PickCustomColor: Boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    property ColorRectWidth: Integer read GetColorRectWidth write SetColorRectWidth stored ColorRectWidthStored;
    property ColorRectOffset: Integer read FColorRectOffset write SetColorRectOffset default cDefaultColorRectOffset;
    property Style: TColorBoxStyle read FStyle write SetStyle
      default [cbStandardColors, cbExtendedColors, cbSystemColors];
    property Colors[Index: Integer]: TColor read GetColor;
    property ColorNames[Index: Integer]: string read GetColorName;
    property Selected: TColor read GetSelected write SetSelected default clBlack;
    property DefaultColorColor: TColor read FDefaultColorColor write SetDefaultColorColor default clBlack;
    property NoneColorColor: TColor read FNoneColorColor write SetNoneColorColor default clBlack;
    property OnGetColors: TGetColorsEvent read FOnGetColors write FOnGetColors;
    property ColorDialog:TcolorDialog read FColorDialog write FcolorDialog;
  end;

  { TColorBox }

  TColorBox = class(TCustomColorBox)
  published
    property ColorRectWidth;
    property ColorRectOffset;
    property DefaultColorColor;
    property NoneColorColor;
    property Selected;
    property Style;
    property OnGetColors;
    property ColorDialog;
    property Align;
    property Anchors;
    property ArrowKeysTraverseList;
    property AutoComplete;
    property AutoCompleteText;
    property AutoDropDown;
    property AutoSelect;
    property AutoSize;
    property BidiMode;
    property BorderSpacing;
    property Color;
    property Constraints;
    property DragCursor;
    property DragMode;
    property DropDownCount;
    property Enabled;
    property Font;
    property ItemHeight;
    property ItemWidth;
    property OnChange;
    property OnChangeBounds;
    property OnClick;
    property OnCloseUp;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnDropDown;
    property OnEditingDone;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnStartDrag;
    property OnSelect;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  { TCustomColorListBox }

  TCustomColorListBox = class;
  TLBGetColorsEvent = procedure(Sender: TCustomColorListBox; Items: TStrings) of object;

  TCustomColorListBox = class(TCustomListBox)
  private
    FColorRectWidth: Integer;
    FColorRectOffset: Integer;
    FDefaultColorColor: TColor;
    FNoneColorColor: TColor;
    FOnGetColors: TLBGetColorsEvent;
    FColorDialog:TColorDialog;
    FSelected: TColor;
    FStyle: TColorBoxStyle;
    function GetColorRectWidth: Integer;
    function GetColors(Index : Integer): TColor;
    function GetColorName(Index: Integer): string;
    function GetSelected: TColor;
    procedure SetColorRectOffset(AValue: Integer);
    procedure SetColorRectWidth(AValue: Integer);
    procedure SetColors(Index: Integer; AValue: TColor);
    procedure SetDefaultColorColor(const AValue: TColor);
    procedure SetNoneColorColor(const AValue: TColor);
    procedure SetSelected(Value: TColor);
    procedure SetStyle(const AValue: TColorBoxStyle); reintroduce;
    procedure ColorProc(const s: AnsiString);
  protected
    function ColorRectWidthStored: Boolean;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure SetColorList;
    procedure Loaded; override;
    procedure InitializeWnd; override;
    procedure DoAutoAdjustLayout(const AMode: TLayoutAdjustmentPolicy;
      const AXProportion, AYProportion: Double); override;
    procedure DoGetColors; virtual;
    procedure DoSelectionChange(User: Boolean); override;
    function PickCustomColor: Boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    property ColorRectWidth: Integer read GetColorRectWidth write SetColorRectWidth stored ColorRectWidthStored;
    property ColorRectOffset: Integer read FColorRectOffset write SetColorRectOffset default cDefaultColorRectOffset;
    property Style: TColorBoxStyle read FStyle write SetStyle
      default [cbStandardColors, cbExtendedColors, cbSystemColors];
    property Colors[Index: Integer]: TColor read GetColors write SetColors;
    property ColorNames[Index: Integer]: string read GetColorName;
    property Selected: TColor read GetSelected write SetSelected default clBlack;
    property DefaultColorColor: TColor read FDefaultColorColor write SetDefaultColorColor default clBlack;
    property NoneColorColor: TColor read FNoneColorColor write SetNoneColorColor default clBlack;
    property OnGetColors: TLBGetColorsEvent read FOnGetColors write FOnGetColors;
    property ColorDialog:TColorDialog read fcolorDialog write FColorDialog;
  end;

  { TColorListBox }

  TColorListBox = class(TCustomColorListBox)
  published
    property ColorRectWidth;
    property ColorRectOffset;
    property DefaultColorColor;
    property NoneColorColor;
    property Selected;
    property Style;
    property OnGetColors;
    property ColorDialog;
    property Align;
    property Anchors;
    property BidiMode;
    property BorderSpacing;
    property BorderStyle;
    property ClickOnSelChange;
    property Color;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property ExtendedSelect;
    property Enabled;
    property Font;
    property IntegralHeight;
    property ItemHeight;
    property OnChangeBounds;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEnter;
    property OnEndDrag;
    property OnExit;
    property OnKeyPress;
    property OnKeyDown;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseLeave;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnMouseWheelHorz;
    property OnMouseWheelLeft;
    property OnMouseWheelRight;
    property OnResize;
    property OnSelectionChange;
    property OnShowHint;
    property OnStartDrag;
    property OnUTF8KeyPress;
    property ParentBidiMode;
    property ParentColor;
    property ParentShowHint;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property TopIndex;
    property Visible;
  end;

procedure Register;

implementation

{------------------------------------------------------------------------------}
procedure Register;
begin
  RegisterComponents('Additional', [TColorBox, TColorListBox]);
end;

function GetPrettyColorName(ColorName: String): String;

  function FindInMap(ColorName: String; out NewColorName: String): Boolean;
  var
    Color: TColor;
  begin
    Result := IdentToColor(ColorName, Color);
    if Result then
    begin
      { workaround for a bug in fpc 2.2.2 }
      if Color=clScrollBar then
        NewColorName := rsScrollBarColorCaption
      else
        case Color of
          clBlack                   : NewColorName := rsBlackColorCaption;
          clMaroon                  : NewColorName := rsMaroonColorCaption;
          clGreen                   : NewColorName := rsGreenColorCaption;
          clOlive                   : NewColorName := rsOliveColorCaption;
          clNavy                    : NewColorName := rsNavyColorCaption;
          clPurple                  : NewColorName := rsPurpleColorCaption;
          clTeal                    : NewColorName := rsTealColorCaption;
          clGray                    : NewColorName := rsGrayColorCaption;
          clSilver                  : NewColorName := rsSilverColorCaption;
          clRed                     : NewColorName := rsRedColorCaption;
          clLime                    : NewColorName := rsLimeColorCaption;
          clYellow                  : NewColorName := rsYellowColorCaption;
          clBlue                    : NewColorName := rsBlueColorCaption;
          clFuchsia                 : NewColorName := rsFuchsiaColorCaption;
          clAqua                    : NewColorName := rsAquaColorCaption;
          clWhite                   : NewColorName := rsWhiteColorCaption;
          clMoneyGreen              : NewColorName := rsMoneyGreenColorCaption;
          clSkyBlue                 : NewColorName := rsSkyBlueColorCaption;
          clCream                   : NewColorName := rsCreamColorCaption;
          clMedGray                 : NewColorName := rsMedGrayColorCaption;
          clNone                    : NewColorName := rsNoneColorCaption;
          clDefault                 : NewColorName := rsDefaultColorCaption;
          clBackground              : NewColorName := rsBackgroundColorCaption;
          clActiveCaption           : NewColorName := rsActiveCaptionColorCaption;
          clInactiveCaption         : NewColorName := rsInactiveCaptionColorCaption;
          clMenu                    : NewColorName := rsMenuColorCaption;
          clWindow                  : NewColorName := rsWindowColorCaption;
          clWindowFrame             : NewColorName := rsWindowFrameColorCaption;
          clMenuText                : NewColorName := rsMenuTextColorCaption;
          clWindowText              : NewColorName := rsWindowTextColorCaption;
          clCaptionText             : NewColorName := rsCaptionTextColorCaption;
          clActiveBorder            : NewColorName := rsActiveBorderColorCaption;
          clInactiveBorder          : NewColorName := rsInactiveBorderColorCaption;
          clAppWorkspace            : NewColorName := rsAppWorkspaceColorCaption;
          clHighlight               : NewColorName := rsHighlightColorCaption;
          clHighlightText           : NewColorName := rsHighlightTextColorCaption;
          clBtnFace                 : NewColorName := rsBtnFaceColorCaption;
          clBtnShadow               : NewColorName := rsBtnShadowColorCaption;
          clGrayText                : NewColorName := rsGrayTextColorCaption;
          clBtnText                 : NewColorName := rsBtnTextColorCaption;
          clInactiveCaptionText     : NewColorName := rsInactiveCaptionText;
          clBtnHighlight            : NewColorName := rsBtnHighlightColorCaption;
          cl3DDkShadow              : NewColorName := rs3DDkShadowColorCaption;
          cl3DLight                 : NewColorName := rs3DLightColorCaption;
          clInfoText                : NewColorName := rsInfoTextColorCaption;
          clInfoBk                  : NewColorName := rsInfoBkColorCaption;
          clHotLight                : NewColorName := rsHotLightColorCaption;
          clGradientActiveCaption   : NewColorName := rsGradientActiveCaptionColorCaption;
          clGradientInactiveCaption : NewColorName := rsGradientInactiveCaptionColorCaption;
          clMenuHighlight           : NewColorName := rsMenuHighlightColorCaption;
          clMenuBar                 : NewColorName := rsMenuBarColorCaption;
          clForm                    : NewColorName := rsFormColorCaption;
        else
          Result := False;
        end;
    end;
  end;

begin
  // check in color map
  if not FindInMap(ColorName, Result) then
  begin
    Result := ColorName;
    if LazStartsStr('cl', Result) then
      Delete(Result, 1, 2);
  end;
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorBox.Create
  Params:   AOwner
  Returns:  Nothing

  Use Create to create an instance of TCustomColorBox and initialize all properties
  and variables.

 ------------------------------------------------------------------------------}
constructor TCustomColorBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  inherited Style := csOwnerDrawFixed;

  FColorRectWidth := -1;
  FColorRectOffset := cDefaultColorRectOffset;
  FStyle := [cbStandardColors, cbExtendedColors, cbSystemColors];
  FNoneColorColor := clBlack;
  FDefaultColorColor := clBlack;
  FSelected := clBlack;
  SetColorList;
end;
{------------------------------------------------------------------------------
  Method:   TCustomColorBox.GetSelected
  Params:   None
  Returns:  TColor

  Use GetSelected to convert the item selected into a system color.

 ------------------------------------------------------------------------------}
function TCustomColorBox.GetSelected: TColor;
begin
  if HandleAllocated then
  begin
    if ItemIndex <> -1 then
    begin
      Result := Colors[ItemIndex];
      // keep FSelected in sync
      if FSelected <> Result then
      begin
        // DebugLn('WARNING TCustomColorBox: FSelected out of sync with Colors[0]');
        FSelected := Result;
      end;
    end else
      Result := FSelected;
  end
  else
    Result := FSelected;
end;

procedure TCustomColorBox.SetColorRectWidth(AValue: Integer);
begin
  if FColorRectWidth = AValue then Exit;
  FColorRectWidth := AValue;
  Invalidate;
end;

procedure TCustomColorBox.SetColorRectOffset(AValue: Integer);
begin
  if FColorRectOffset = AValue then Exit;
  FColorRectOffset := AValue;
  Invalidate;
end;

procedure TCustomColorBox.SetDefaultColorColor(const AValue: TColor);
begin
  if FDefaultColorColor <> AValue then
  begin
    FDefaultColorColor := AValue;
    invalidate;
  end;
end;

procedure TCustomColorBox.SetNoneColorColor(const AValue: TColor);
begin
  if FNoneColorColor <> AValue then
  begin
    FNoneColorColor := AValue;
    invalidate;
  end;
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorBox.GetColor
  Params:   Index
  Returns:  Color at position Index

  Used as read procedure from Colors property.

 ------------------------------------------------------------------------------}

function TCustomColorBox.GetColor(Index : Integer): TColor;
begin
  Result := PtrInt(Items.Objects[Index])
end;

function TCustomColorBox.GetColorName(Index: Integer): string;
begin
  Result := Items[Index];
end;

function TCustomColorBox.GetColorRectWidth: Integer;
begin
  if ColorRectWidthStored then
    Result := FColorRectWidth
  else
    Result := Scale96ToFont(cDefaultColorRectWidth);
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorBox.SetSelected
  Params:   Value
  Returns:  Nothing

  Use SetSelected to set the item in the ColorBox when appointed a color
  from code.

 ------------------------------------------------------------------------------}
procedure TCustomColorBox.SetSelected(Value: TColor);
begin
  if FSelected = Value then
    Exit;

  FSelected := Value;
  UpdateCombo;
  inherited Change;
end;

procedure TCustomColorBox.SetStyle(const AValue: TColorBoxStyle);
begin
  if FStyle <> AValue then
  begin
    FStyle := AValue;
    SetColorList;
  end;
end;

procedure TCustomColorBox.ColorProc(const s: AnsiString);
var
  AColor: TColor;
  Index: Integer;
  ColorCaption: String;
begin
  if IdentToColor(s, AColor) then
  begin
    if AColor = clWhite then
      AColor := AColor;
    // check clDefault
    if not (cbIncludeDefault in Style) and (AColor = clDefault) then
      Exit;
    // check clNone
    if not (cbIncludeNone in Style) and (AColor = clNone) then
      Exit;
    // check System colors
    if not (cbSystemColors in Style) and ((AColor and SYS_COLOR_BASE) <> 0) then
      Exit;
    // check Standard, Extended colors
    if ([cbStandardColors, cbExtendedColors] * Style <> [cbStandardColors, cbExtendedColors]) and
        ColorIndex(AColor, Index) then
    begin
      if not (cbStandardColors in Style) and (Index < StandardColorsCount) then
        Exit;
      if not (cbExtendedColors in Style) and
          (Index < StandardColorsCount + ExtendedColorCount) and
          (Index >= StandardColorsCount) then
        Exit;
    end;

    if cbPrettyNames in Style then
      ColorCaption := GetPrettyColorName(s)
    else
      ColorCaption := s;

    Items.AddObject(ColorCaption, TObject(PtrInt(AColor)));
  end;
end;

function TCustomColorBox.ColorRectWidthStored: Boolean;
begin
  Result := FColorRectWidth >= 0;
end;

procedure TCustomColorBox.DoAutoAdjustLayout(
  const AMode: TLayoutAdjustmentPolicy; const AXProportion, AYProportion: Double
  );
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);

  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if ColorRectWidthStored then
      FColorRectWidth := Round(FColorRectWidth * AXProportion);
    Invalidate;
  end;
end;

procedure TCustomColorBox.UpdateCombo;
var
  c: integer;
begin
  if HandleAllocated then
  begin
    for c := Ord(cbCustomColor in Style) to Items.Count - 1 do
    begin
      if Colors[c] = FSelected then
      begin
        ItemIndex := c;
        Exit;
      end;
    end;
    if cbCustomColor in Style then
    begin
      Items.Objects[0] := TObject(PtrInt(FSelected));
      ItemIndex := 0;
      Invalidate;
    end
    else
      ItemIndex := -1;
  end;
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorBox.DrawItem
  Params:   Index, Rect, State
  Returns:  Nothing

  Use DrawItem to customdraw an item in the ColorBox. A color preview is drawn
  and the item rectangle is made smaller and given to the inherited method to
  draw the corresponding text. The Brush color and Pen color where changed and
  reset to their original values.

 ------------------------------------------------------------------------------}
procedure TCustomColorBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  r: TRect;
  BrushColor, PenColor, NewColor: TColor;
  noFill: Boolean;
begin
  if Index = -1 then
    Exit;

  r.top := Rect.top + ColorRectOffset;
  r.bottom := Rect.bottom - ColorRectOffset;
  r.left := Rect.left + ColorRectOffset;
  r.right := r.left + ColorRectWidth;

  if not(odBackgroundPainted in State) then
    Canvas.FillRect(Rect);

  BrushColor := Canvas.Brush.Color;
  PenColor := Canvas.Pen.Color;

  NewColor := Colors[Index];
  noFill := NewColor = clNone;
  if noFill then
    NewColor := NoneColorColor
  else
  if NewColor = clDefault then
    NewColor := DefaultColorColor;

  Canvas.Brush.Color := NewColor;
  Canvas.Pen.Color := clBlack;

  r := BiDiFlipRect(r, Rect, UseRightToLeftAlignment);
  Canvas.Rectangle(r);

  if noFill then
  begin
    Canvas.Line(r.Left, r.Top, r.Right-1, r.Bottom-1);
    Canvas.Line(r.Left, r.Bottom-1, r.Right-1, r.Top);
  end;

  Canvas.Brush.Color := BrushColor;
  Canvas.Pen.Color := PenColor;

  r := Rect;
  r.left := r.left + ColorRectWidth + ColorRectOffset + 1;

  Include(State, odBackgroundPainted);
  inherited DrawItem(Index, BidiFlipRect(r, Rect, UseRightToLeftAlignment), State);
end;
{------------------------------------------------------------------------------
  Method:   TCustomColorBox.SetColorList
  Params:   None
  Returns:  Nothing

  Use SetColorList to fill the itemlist in the ColorBox with the right color
  entries. Based on the value of the Palette property.

 ------------------------------------------------------------------------------}
procedure TCustomColorBox.SetColorList;
var
  OldSelected: Integer;
begin
  // we need to wait while we finish loading since we depend on style and OnGetColors event
  if (csLoading in ComponentState) then
    Exit;

  OldSelected := FSelected;
  with Items do
  begin
    Clear;
    if cbCustomColor in Style then
      Items.AddObject(rsCustomColorCaption, TObject(PtrInt(clBlack)));
    GetColorValues(@ColorProc);
    if (cbCustomColors in Style) then
      DoGetColors;
  end;
  Selected := OldSelected;
end;

procedure TCustomColorBox.Loaded;
begin
  inherited Loaded;
  SetColorList;
end;

procedure TCustomColorBox.InitializeWnd;
begin
  inherited InitializeWnd;
  UpdateCombo;
end;

procedure TCustomColorBox.DoGetColors;
begin
  if Assigned(OnGetColors) then
    OnGetColors(Self, Items)
end;

procedure TCustomColorBox.CloseUp;
begin
  if (cbCustomColor in Style) and (ItemIndex = 0) then // custom color has been selected
    PickCustomColor;
  if ItemIndex <> -1 then
    Selected := Colors[ItemIndex];
  inherited CloseUp;
end;

function TCustomColorBox.PickCustomColor: Boolean;
Var
  FreeDialog:Boolean;
begin
  if csDesigning in ComponentState then
  begin
    Result := False;
    Exit;
  end;
  FreeDialog := FcolorDialog = NIL;
  If FColorDialog = Nil Then FcolorDialog := TcolorDialog.Create(GetTopParent);
  Try
    With FColorDialog do
    Begin
      Color := Colors[0];
      Result := Execute;
      If Result Then
       Begin
         items.objects[0]:= TObject(PtrInt(COlor));
         Invalidate;
       end;
    end;
  finally
    If FreeDialog Then FreeAndNil(FcolorDialog);
  end;
end;

{------------------------------------------------------------------------------}
{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.Create
  Params:   AOwner
  Returns:  Nothing

  Use Create to create an instance of TCustomColorListBox and initialize all properties
  and variables.

 ------------------------------------------------------------------------------}
constructor TCustomColorListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  inherited Style := lbOwnerDrawFixed;
  FColorRectWidth := -1;
  FColorRectOffset := cDefaultColorRectOffset;
  FStyle := [cbStandardColors, cbExtendedColors, cbSystemColors];
  FNoneColorColor := clBlack;
  FDefaultColorColor := clBlack;
  FSelected := clBlack;

  SetColorList;
end;
{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.GetSelected
  Params:   None
  Returns:  TColor

  Use GetSelected to convert the item selected into a system color.

 ------------------------------------------------------------------------------}
function TCustomColorListBox.GetSelected: TColor;
begin
  if HandleAllocated then
  begin
    if ItemIndex <> -1 then
      Result := Colors[ItemIndex]
    else
      Result := FSelected
  end
  else
    Result := FSelected;
end;

procedure TCustomColorListBox.SetColorRectOffset(AValue: Integer);
begin
  if FColorRectOffset = AValue then Exit;
  FColorRectOffset := AValue;
  Invalidate;
end;

procedure TCustomColorListBox.SetColorRectWidth(AValue: Integer);
begin
  if FColorRectWidth = AValue then Exit;
  FColorRectWidth := AValue;
  Invalidate;
end;

procedure TCustomColorListBox.SetColors(Index: Integer; AValue: TColor);
begin
  if Colors[Index]=AValue then exit;
  Items.Objects[Index]:=TObject(PtrInt(AValue));
  Invalidate;
end;

procedure TCustomColorListBox.SetDefaultColorColor(const AValue: TColor);
begin
  if FDefaultColorColor <> AValue then
  begin
    FDefaultColorColor := AValue;
    invalidate;
  end;
end;

procedure TCustomColorListBox.SetNoneColorColor(const AValue: TColor);
begin
  if FNoneColorColor <> AValue then
  begin
    FNoneColorColor := AValue;
    invalidate;
  end;
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.GetColors
  Params:   Index
  Returns:  Color at position Index

  Used as read procedure from Colors property.

 ------------------------------------------------------------------------------}
function TCustomColorListBox.GetColors(Index : Integer): TColor;
begin
  Result := PtrInt(Items.Objects[Index]);
end;

function TCustomColorListBox.GetColorName(Index: Integer): string;
begin
  Result := Items[Index];
end;

function TCustomColorListBox.GetColorRectWidth: Integer;
begin
  if ColorRectWidthStored then
    Result := FColorRectWidth
  else
    Result := Scale96ToFont(cDefaultColorRectWidth);
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.SetSelected
  Params:   Value
  Returns:  Nothing

  Use SetSelected to set the item in the ColorListBox when appointed a color
  from code.

 ------------------------------------------------------------------------------}
procedure TCustomColorListBox.SetSelected(Value: TColor);
var
  c: integer;
begin
  if HandleAllocated then
  begin
    FSelected := Value;
    for c := Ord(cbCustomColor in Style) to Items.Count - 1 do
    begin
      if Colors[c] = Value then
      begin
        ItemIndex := c;
        Exit;
      end;
    end;
    if cbCustomColor in Style then
    begin
      Items.Objects[0] := TObject(PtrInt(Value));
      ItemIndex := 0;
      invalidate;
    end
    else
      ItemIndex := -1;
  end
  else
    FSelected := Value;
end;

procedure TCustomColorListBox.SetStyle(const AValue: TColorBoxStyle);
begin
  if FStyle <> AValue then
  begin
    FStyle := AValue;
    SetColorList;
  end;
end;

procedure TCustomColorListBox.ColorProc(const s: AnsiString);
var
  AColor: TColor;
  Index: Integer;
  ColorCaption: String;
begin
  if IdentToColor(s, AColor) then
  begin
    // check clDefault
    if not (cbIncludeDefault in Style) and (AColor = clDefault) then
      Exit;
    // check clNone
    if not (cbIncludeNone in Style) and (AColor = clNone) then
      Exit;
    // check System colors
    if not (cbSystemColors in Style) and ((AColor and SYS_COLOR_BASE) <> 0) then
      Exit;
    // check Standard, Extended colors
    if ([cbStandardColors, cbExtendedColors] * Style <> [cbStandardColors, cbExtendedColors]) and
        ColorIndex(AColor, Index) then
    begin
      if not (cbStandardColors in Style) and (Index < StandardColorsCount) then
        Exit;
      if not (cbExtendedColors in Style) and
          (Index < StandardColorsCount + ExtendedColorCount) and
          (Index >= StandardColorsCount) then
        Exit;
    end;

    if cbPrettyNames in Style then
      ColorCaption := GetPrettyColorName(s)
    else
      ColorCaption := s;

    Items.AddObject(ColorCaption, TObject(PtrInt(AColor)));
  end;
end;

function TCustomColorListBox.ColorRectWidthStored: Boolean;
begin
  Result := FColorRectWidth >= 0;
end;

procedure TCustomColorListBox.DoAutoAdjustLayout(
  const AMode: TLayoutAdjustmentPolicy; const AXProportion, AYProportion: Double
  );
begin
  inherited DoAutoAdjustLayout(AMode, AXProportion, AYProportion);

  if AMode in [lapAutoAdjustWithoutHorizontalScrolling, lapAutoAdjustForDPI] then
  begin
    if ColorRectWidthStored then
      FColorRectWidth := Round(FColorRectWidth * AXProportion);
    Invalidate;
  end;
end;

{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.DrawItem
  Params:   Index, Rect, State
  Returns:  Nothing

  Use DrawItem to customdraw an item in the ColorListBox. A color preview is drawn
  and the item rectangle is made smaller and given to the inherited method to
  draw the corresponding text. The Brush color and Pen color where changed and
  reset to their original values.

 ------------------------------------------------------------------------------}
procedure TCustomColorListBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  r: TRect;
  BrushColor, PenColor, NewColor: TColor;
  noFill: boolean;
begin
  if Index < 0 then
    Exit;

  r.top := Rect.top + ColorRectOffset;
  r.bottom := Rect.bottom - ColorRectOffset;
  r.left := Rect.left + ColorRectOffset;
  r.right := r.left + ColorRectWidth;

  if not(odBackgroundPainted in State) then
    Canvas.FillRect(Rect);

  BrushColor := Canvas.Brush.Color;
  PenColor := Canvas.Pen.Color;

  NewColor := Colors[Index];
  noFill := NewColor = clNone;
  if noFill then
    NewColor := NoneColorColor
  else
  if NewColor = clDefault then
    NewColor := DefaultColorColor;

  Canvas.Brush.Color := NewColor;
  Canvas.Pen.Color := clBlack;

  Canvas.Rectangle(BidiFlipRect(r, Rect, UseRightToLeftAlignment));

  if noFill then
  begin
    Canvas.Line(r.Left, r.Top, r.Right-1, r.Bottom-1);
    Canvas.Line(r.Left, r.Bottom-1, r.Right-1, r.Top);
  end;

  Canvas.Brush.Color := BrushColor;
  Canvas.Pen.Color := PenColor;

  r := Rect;
  r.left := r.left + ColorRectWidth + ColorRectOffset + 1;

  Include(State,odBackgroundPainted);
  inherited DrawItem(Index, BidiFlipRect(r, Rect, UseRightToLeftAlignment), State);
end;
{------------------------------------------------------------------------------
  Method:   TCustomColorListBox.SetColorList
  Params:   None
  Returns:  Nothing

  Use SetColorList to fill the itemlist in the ColorListBox with the right color
  entries. Based on the value of the Palette property.

 ------------------------------------------------------------------------------}
procedure TCustomColorListBox.SetColorList;
var
  OldSelected: Integer;
begin
  // we need to wait while we finish loading since we depend on style and OnGetColors event
  if (csLoading in ComponentState) then
    Exit;
  OldSelected := FSelected;
  with Items do
  begin
    Clear;
    if cbCustomColor in Style then
      Items.AddObject(rsCustomColorCaption, TObject(PtrInt(clBlack)));
    GetColorValues(@ColorProc);
    if (cbCustomColors in Style) then
      DoGetColors;
  end;
  Selected := OldSelected;
end;

procedure TCustomColorListBox.Loaded;
begin
  inherited Loaded;
  SetColorList;
end;

procedure TCustomColorListBox.InitializeWnd;
begin
  inherited InitializeWnd;
  Selected := FSelected;
end;

procedure TCustomColorListBox.DoGetColors;
begin
  if Assigned(OnGetColors) then
    OnGetColors(Self, Items)
end;

procedure TCustomColorListBox.DoSelectionChange(User: Boolean);
begin
  if User then
  begin
    if (cbCustomColor in Style) and (ItemIndex = 0) then // custom color has been selected
      PickCustomColor;
    if ItemIndex <> -1 then
      FSelected := Colors[ItemIndex];
  end;
  inherited DoSelectionChange(User);
end;

function TCustomColorListBox.PickCustomColor: Boolean;
Var
  FreeDialog:Boolean;
begin
  if csDesigning in ComponentState then
  begin
    Result := False;
    Exit;
  end;
  FreeDialog := FcolorDialog = NIL;
  If FColorDialog = Nil Then FcolorDialog := TcolorDialog.Create(GetTopParent);
  Try
    With FColorDialog do
    Begin
      Color := Colors[0];
      Result := Execute;
      If Result Then
       Begin
         items.objects[0]:= TObject(PtrInt(COlor));
         Invalidate;
       end;
    end;
  finally
    If FreeDialog Then FreeAndNil(FcolorDialog);
  end;
end;

{------------------------------------------------------------------------------}
end.

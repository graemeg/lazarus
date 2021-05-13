{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Author: Michael W. Vogel
}

unit DockedAnchorControl;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$modeswitch typehelpers}

interface

uses
  // RTL, FCL
  Classes, SysUtils, fgl, FPCanvas,
  // LCL
  Controls, ExtCtrls, Graphics, LCLProc, Dialogs, PairSplitter, ComCtrls,
  LCLType, IDEDialogs,
  // DockedFormEditor
  DockedOptionsIDE, DockedStrConsts, DockedTools;

type

  { TAnchorsHelper }

  TAnchorsHelper = type helper for TAnchors
    function ToString: String;
  end;

const
  AnchorSideReferenceStr: array[TAnchorSideReference] of String =
    ('Top', 'Bottom', 'Center');

type
  TAttachDetach = (adAttachControl, adDetachControl, adAttachPoint, adDetachPoint, adAttachSide, adDetachSide);

const
  AttachDetachStr: array[TAttachDetach] of String =
    (SAttachControl, SDetachControl, SAttachPoint, SDetachPoint, SAttachSide, SDetachSide);

type

  TAnchorControlState = (acsNone, acsInvalid, acsSelected, acsUpdating);
  TAnchorControlStates = set of TAnchorControlState;
  TAnchorState = (asMouseDown, asMoving, asAnchorLeft, asAnchorTop, asAnchorRight,
                  asAnchorBottom, asBordering);
  TAnchorStates = set of TAnchorState;

  { TAnchorStatesHelper }

  TAnchorStatesHelper = type helper for TAnchorStates
    function IsAnchoring: Boolean;
    function IsAnchoringBottom: Boolean;
    function IsAnchoringHorz: Boolean;
    function IsAnchoringLeft: Boolean;
    function IsAnchoringRight: Boolean;
    function IsAnchoringTop: Boolean;
    function IsAnchoringVert: Boolean;
    function IsBordering: Boolean;
    function IsMouseDown: Boolean;
    function IsMoving: Boolean;
  end;

  { TTargetAnchorSide }

  TTargetAnchorSide = record
    Kind: TAnchorKind;
    Side: TAnchorSideReference;
    class operator = (Item1, Item2: TTargetAnchorSide): Boolean;
  end;

  { TTargetAnchorSides }

  TTargetAnchorSides = class(specialize TFPGList<TTargetAnchorSide>)
  public
    procedure Add(AKind: TAnchorKind; ASide: TAnchorSideReference); overload;
  end;

  { TAnchorControl }

  TAnchorControl = class(TPanel)
  private
    FIsChildControl: Boolean;
    FRootControl: TControl;
    FState: TAnchorControlStates;
    FTargetAnchorSides: TTargetAnchorSides;
    procedure AnchorControlShowHint(Sender: TObject; HintInfo: PHintInfo);
    function  BorderSpacingStr: String;
    function  BoundsString: String;
    procedure CheckIsChildControl;
    procedure CreateCaption;
  public
    constructor Create(AParent: TWinControl; ARootControl: TControl); reintroduce;
    destructor Destroy; override;
    function  AnchorSideStr(AKind: TAnchorKind): String;
    function  AnchorsString: String;
    function  AnchorValid(AKind: TAnchorKind; AControl: TControl; ASide: TAnchorSideReference): Boolean;
    function  AnchorsValid: Boolean;
    procedure AssignAnchor(ASource: TAnchorControl; AKind: TAnchorKind);
    procedure AssignAnchors(ASource: TAnchorControl);
    procedure AssignBounds(ASource: TAnchorControl);
    procedure AssignFull(ASource: TAnchorControl);
    procedure AssignToRoot_Anchor(AKind: TAnchorKind);
    procedure AssignToRoot_Anchors;
    procedure AssignToRoot_Bounds;
    procedure AssignToRoot_ControlsBounds(SelfBoundsToRoot: Boolean);
    procedure AssignToRoot_Full;
    procedure Invalid;
    function  IsInvalid: Boolean;
    procedure Paint; override;
    procedure RemoveAnchorSide(AAnchorKind: TAnchorKind);
    procedure RemoveAnchorSides;
    procedure SetNewParent(AParent: TWinControl);
    procedure TargetAnchorSidesGet(AAnchorControl: TAnchorControl);
    procedure Validate;
  public
    property IsChildControl: Boolean read FIsChildControl;
    property RootControl: TControl read FRootControl;
    property State: TAnchorControlStates read FState write FState;
  end;

  { TAnchorControls }

  TAnchorControls = class(specialize TFPGObjectList<TAnchorControl>)
    // on Index[0], there is FBackGround
  public
    destructor Destroy; override;
    procedure BeginUpdate;
    procedure EndUpdate;
    procedure CheckAnchors;
    procedure CheckParents;
    procedure CheckProperties;
    procedure DeleteIndexAndAbove(AIndex: Integer);
    function  IndexOf(AControl: TControl): Integer; overload;
    procedure Invalid;
    function  RemoveInvalid: Boolean;
  end;

  { TBorderControl }

  TBorderControl = class(TPanel)
    FBitmap: TBitmap;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
  end;

implementation

{ TAnchorsHelper }

function TAnchorsHelper.ToString: String;
begin
  Result := EmptyStr;
  if akLeft   in Self then Result := EnumerationString(Result, STabPositionLeft);
  if akTop    in Self then Result := EnumerationString(Result, STabPositionTop);
  if akRight  in Self then Result := EnumerationString(Result, STabPositionRight);
  if akBottom in Self then Result := EnumerationString(Result, STabPositionBottom);
  Result := '[' + Result + ']';
end;

{ TAnchorStatesHelper }

function TAnchorStatesHelper.IsAnchoring: Boolean;
begin
  Result := Self * [asAnchorLeft, asAnchorRight, asAnchorTop, asAnchorBottom] <> [];
end;

function TAnchorStatesHelper.IsAnchoringBottom: Boolean;
begin
  Result := asAnchorBottom in Self;
end;

function TAnchorStatesHelper.IsAnchoringHorz: Boolean;
begin
  Result := Self * [asAnchorLeft, asAnchorRight] <> [];
end;

function TAnchorStatesHelper.IsAnchoringLeft: Boolean;
begin
  Result := asAnchorLeft in Self;
end;

function TAnchorStatesHelper.IsAnchoringRight: Boolean;
begin
  Result := asAnchorRight in Self;
end;

function TAnchorStatesHelper.IsAnchoringTop: Boolean;
begin
  Result := asAnchorTop in Self;
end;

function TAnchorStatesHelper.IsAnchoringVert: Boolean;
begin
  Result := Self * [asAnchorTop, asAnchorBottom] <> [];
end;

function TAnchorStatesHelper.IsBordering: Boolean;
begin
  Result := asBordering in Self;
end;

function TAnchorStatesHelper.IsMouseDown: Boolean;
begin
  Result := asMouseDown in Self;
end;

function TAnchorStatesHelper.IsMoving: Boolean;
begin
  Result := asMoving in Self;
end;

{ TTargetAnchorSide }

class operator TTargetAnchorSide. = (Item1, Item2: TTargetAnchorSide): Boolean;
begin
  Result := (Item1.Kind = Item2.Kind) and
            (Item1.Side = Item2.Side);
end;

{ TTargetAnchorSides }

procedure TTargetAnchorSides.Add(AKind: TAnchorKind; ASide: TAnchorSideReference);
var
  LTargetAnchorSide: TTargetAnchorSide;
begin
  LTargetAnchorSide.Kind := AKind;
  LTargetAnchorSide.Side := ASide;
  Add(LTargetAnchorSide);
end;

{ TAnchorControl }

procedure TAnchorControl.AnchorControlShowHint(Sender: TObject; HintInfo: PHintInfo);
begin
  HintInfo^.HintStr := 'Name [' + DbgSName(RootControl) + ']' + LineEnding +
                       'Bounds [' + BoundsString + ']' + LineEnding +
                       'Align [' + DbgS(Align) + ']' + LineEnding +
                       AnchorsString +
                       'Borderspacing [' + BorderSpacingStr + ']';
  HintInfo^.HideTimeout := 5000;
end;

function TAnchorControl.BorderSpacingStr: String;
begin
  Result := 'Around: ' + BorderSpacing.Around.ToString +
            ', Left: ' + BorderSpacing.Left.ToString +
            ', Top: ' + BorderSpacing.Top.ToString +
            ', Right: ' + BorderSpacing.Right.ToString +
            ', Bottom: ' + BorderSpacing.Bottom.ToString;
end;

function TAnchorControl.BoundsString: String;
begin
  Result := 'Left: ' + Left.ToString +
            ', Top: ' + Top.ToString +
            ', Width: ' + Width.ToString +
            ', Height: ' + Height.ToString;
end;

procedure TAnchorControl.CheckIsChildControl;
begin
  FIsChildControl :=
    (FRootControl is TPairSplitterSide) or
    ((FRootControl is TSplitter) and (FRootControl.Parent is TPairSplitter)) or
    (FRootControl is TToolButton) or
    (FRootControl is TPage) or
    (FRootControl is TTabSheet);
end;

procedure TAnchorControl.CreateCaption;
begin
  if not FRootControl.Name.IsEmpty then
    Caption := FRootControl.Name
  else
    Caption := FRootControl.ClassName;
end;

constructor TAnchorControl.Create(AParent: TWinControl; ARootControl: TControl);
begin
  inherited Create(nil);
  FTargetAnchorSides := TTargetAnchorSides.Create;
  FRootControl := ARootControl;
  CreateCaption;
  CheckIsChildControl;
  SetBounds(ARootControl.Left, ARootControl.Top, ARootControl.Width, ARootControl.Height);
  BorderSpacing := ARootControl.BorderSpacing;
  Align := ARootControl.Align;
  Parent := AParent;
  Color := DockedOptions.AnchorControlColor;
  ParentColor := False;
  FState := [acsNone];
  ParentShowHint := False;
  ShowHint := True;
  OnShowHint := @AnchorControlShowHint;
end;

destructor TAnchorControl.Destroy;
begin
  FTargetAnchorSides.Free;
  inherited Destroy;
end;

function TAnchorControl.AnchorSideStr(AKind: TAnchorKind): String;
begin
  case AKind of
    akLeft:   Result := 'Anchor Left [';
    akTop:    Result := 'Anchor Top [';
    akRight:  Result := 'Anchor Right [';
    akBottom: Result := 'Anchor Bottom [';
  end;
  if not Assigned(AnchorSide[AKind].Control) or not (AnchorSide[AKind].Control is TAnchorControl) then
    Result := Result +
              'Control: nil]'
  else
    Result := Result +
              'Control: ' + TAnchorControl(AnchorSide[AKind].Control).Caption +
              ', Side: ' + AnchorSideReferenceStr[AnchorSide[AKind].Side] + ']';
end;

function TAnchorControl.AnchorsString: String;
var
  LKind: TAnchorKind;
begin
  Result := '';
  for LKind := akTop to akBottom do
    if LKind in Anchors then
      Result := LinedString(Result, AnchorSideStr(LKind));
  if not Result.IsEmpty then
    Result := Result + LineEnding;
end;

function TAnchorControl.AnchorValid(AKind: TAnchorKind; AControl: TControl; ASide: TAnchorSideReference): Boolean;
var
  LReferenceControl: TControl;
  LReferenceSide: TAnchorSideReference;
  LPosition: Integer;
begin
  Result := AnchorSide[AKind].CheckSidePosition(AControl,
                                                ASide,
                                                LReferenceControl,
                                                LReferenceSide,
                                                LPosition);
end;

function TAnchorControl.AnchorsValid: Boolean;
var
  LKind: TAnchorKind;
begin
  for LKind := akTop to akBottom do
  begin
    if not (LKind in Anchors) then Continue;
    if not AnchorValid(LKind,
                       AnchorSide[LKind].Control,
                       AnchorSide[LKind].Side)
    then
      if IDEMessageDialog(
        SWarningCaption,
        SCircularDependency,
        mtWarning,
        [mbIgnore, mbCancel]) = mrIgnore
      then Exit(True)
      else Exit(False);
  end;
  Result := True;
end;

procedure TAnchorControl.AssignAnchor(ASource: TAnchorControl; AKind: TAnchorKind);
begin
  AnchorSide[AKind].Control := ASource.AnchorSide[AKind].Control;
  AnchorSide[AKind].Side    := ASource.AnchorSide[AKind].Side;
  if AKind in ASource.Anchors then
    Anchors := Anchors + [AKind]
  else
    Anchors := Anchors - [AKind];

  if not DockedOptions.TreatAlign then Exit;
  case ASource.Align of
    alNone, alCustom: Exit;
    alTop:    if AKind = akBottom then Exit;
    alLeft:   if AKind = akRight  then Exit;
    alRight:  if AKind = akLeft   then Exit;
    alBottom: if AKind = akTop    then Exit;
  end;
  AnchorSide[AKind].Control := ASource.Parent;
  case AKind of
    akTop:    AnchorSide[AKind].Side := asrTop;
    akLeft:   AnchorSide[AKind].Side := asrTop;
    akRight:  AnchorSide[AKind].Side := asrBottom;
    akBottom: AnchorSide[AKind].Side := asrBottom;
  end;
end;

procedure TAnchorControl.AssignAnchors(ASource: TAnchorControl);
var
  LKind: TAnchorKind;
begin
  for LKind := akTop to akBottom do
    AssignAnchor(ASource, LKind);
  Anchors := ASource.Anchors;
end;

procedure TAnchorControl.AssignBounds(ASource: TAnchorControl);
var
  LRect: TRect;
begin
  LRect := ASource.BoundsRect;
  SetBounds(LRect.Left, LRect.Top, LRect.Width, LRect.Height);
  BorderSpacing := ASource.BorderSpacing;
end;

procedure TAnchorControl.AssignFull(ASource: TAnchorControl);
begin
  Align := ASource.Align;
  AssignAnchors(ASource);
  AssignBounds(ASource);
end;

procedure TAnchorControl.AssignToRoot_Anchor(AKind: TAnchorKind);
var
  LAnchorSideControl: TControl;
begin
  LAnchorSideControl := AnchorSide[AKind].Control;
  if LAnchorSideControl is TAnchorControl then
    RootControl.AnchorSide[AKind].Control := TAnchorControl(LAnchorSideControl).RootControl
  else
    RootControl.AnchorSide[AKind].Control := nil;
  RootControl.AnchorSide[AKind].Side := AnchorSide[AKind].Side;
end;

procedure TAnchorControl.AssignToRoot_Anchors;
var
  LKind: TAnchorKind;
begin
  if DockedOptions.TreatAlign then
    RootControl.Align := alNone;
  for LKind := akTop to akBottom do
    AssignToRoot_Anchor(LKind);
  RootControl.Anchors := Anchors;
end;

procedure TAnchorControl.AssignToRoot_Bounds;
var
  LRect: TRect;
begin
  LRect := BoundsRect;
  RootControl.SetBounds(LRect.Left, LRect.Top, LRect.Width, LRect.Height);
  RootControl.BorderSpacing := BorderSpacing;
end;

procedure TAnchorControl.AssignToRoot_ControlsBounds(SelfBoundsToRoot: Boolean);
var
  i: Integer;
begin
  if SelfBoundsToRoot then
    AssignToRoot_Bounds;

  for i := 0 to ControlCount - 1 do
    if Controls[i] is TAnchorControl then
      TAnchorControl(Controls[i]).AssignToRoot_ControlsBounds(True);
end;

procedure TAnchorControl.AssignToRoot_Full;
begin
  AssignToRoot_Anchors;
  AssignToRoot_Bounds;
end;

procedure TAnchorControl.Invalid;
begin
  FState := [acsInvalid];
end;

function TAnchorControl.IsInvalid: Boolean;
begin
  Result := acsInvalid in State;
end;

procedure TAnchorControl.Paint;
var
  LKind: TAnchorKind;
  LColor: TColor;
  LTargetAnchorSide: TTargetAnchorSide;
begin
  inherited Paint;
  if acsInvalid in State then Exit;
  if acsUpdating in State then Exit;

  for LTargetAnchorSide in FTargetAnchorSides do
  begin
    case LTargetAnchorSide.Kind of
      akBottom: Canvas.Pen.Color := DockedOptions.AnchorBottomColor;
      akLeft:   Canvas.Pen.Color := DockedOptions.AnchorLeftColor;
      akRight:  Canvas.Pen.Color := DockedOptions.AnchorRightColor;
      akTop:    Canvas.Pen.Color := DockedOptions.AnchorTopColor;
    end;
    if LTargetAnchorSide.Kind in [akLeft, akRight] then
      case LTargetAnchorSide.Side of
        asrLeft:   Canvas.Line(0, 0, 0, Height - 1);
        asrCenter: Canvas.Line((Width - 1) div 2, 0, (Width - 1) div 2, Height - 1);
        asrRight:  Canvas.Line(Width - 1, 0, Width - 1, Height - 1);
      end
    else
      case LTargetAnchorSide.Side of
        asrTop:    Canvas.Line(0, 0, Width - 1, 0);
        asrCenter: Canvas.Line(0, (Height - 1) div 2, Width - 1, (Height - 1) div 2);
        asrBottom: Canvas.Line(0, Height - 1, Width - 1, Height - 1);
      end;
  end;

  if acsSelected in State then
    for LKind := akTop to akBottom do
    begin
      LColor := clBlack;
      if (LKind in Anchors) and Assigned(AnchorSide[LKind].Control) then
      case LKind of
        akBottom: LColor := DockedOptions.AnchorBottomColor;
        akLeft:   LColor := DockedOptions.AnchorLeftColor;
        akRight:  LColor := DockedOptions.AnchorRightColor;
        akTop:    LColor := DockedOptions.AnchorTopColor;
      end;
      Canvas.Pen.Color := LColor;
      case LKind of
        akBottom: Canvas.Line(0, Height - 1, Width - 1, Height - 1);
        akLeft:   Canvas.Line(0, 0, 0, Height - 1);
        akRight:  Canvas.Line(Width - 1, 0, Width - 1, Height - 1);
        akTop:    Canvas.Line(0, 0, Width - 1, 0);
      end;
    end;
end;

procedure TAnchorControl.RemoveAnchorSide(AAnchorKind: TAnchorKind);
begin
  AnchorSide[AAnchorKind].Control := nil;
  AnchorSide[AAnchorKind].Side := asrTop;
  Anchors := Anchors - [AAnchorKind];
end;

procedure TAnchorControl.RemoveAnchorSides;
var
  LKind: TAnchorKind;
begin
  if DockedOptions.TreatAlign then
    Align := alNone;
  for LKind := akTop to akBottom do
    RemoveAnchorSide(LKind);
end;

procedure TAnchorControl.SetNewParent(AParent: TWinControl);
begin
  Parent := AParent;
end;

procedure TAnchorControl.TargetAnchorSidesGet(AAnchorControl: TAnchorControl);
var
  LKind: TAnchorKind;
begin
  FTargetAnchorSides.Clear;
  if not Assigned(AAnchorControl) then Exit;
  for LKind := akTop to akBottom do
    if (LKind in AAnchorControl.Anchors) and (AAnchorControl.AnchorSide[LKind].Control = Self) then
      FTargetAnchorSides.Add(LKind, AAnchorControl.AnchorSide[LKind].Side);
end;

procedure TAnchorControl.Validate;
begin
  FState := [acsNone];
end;

{ TAnchorControls }

destructor TAnchorControls.Destroy;
begin
  while Count > 0 do
    Delete(Count - 1);
  inherited Destroy;
end;

procedure TAnchorControls.BeginUpdate;
var
  i: Integer;
begin
  for i := 1 to Count - 1 do
    if Self[i].IsInvalid then
      Continue
    else
      Self[i].State := Self[i].State + [acsUpdating];
end;

procedure TAnchorControls.EndUpdate;
var
  i: Integer;
begin
  for i := 1 to Count - 1 do
    if Self[i].IsInvalid then
      Continue
    else
      Self[i].State := Self[i].State - [acsUpdating];
end;

procedure TAnchorControls.CheckAnchors;
var
  i: Integer;
  LKind: TAnchorKind;
  LIndex: Integer;
begin
  for i := 1 to Count - 1 do
    if Self[i].IsInvalid then
      Continue
    else
    begin
      for LKind := akTop to akBottom do
      begin
        Self[i].AnchorSide[LKind].Side := Self[i].RootControl.AnchorSide[LKind].Side;
        if Self[i].RootControl.AnchorSide[LKind].Control = nil then
        begin
          Self[i].AnchorSide[LKind].Control := nil;
          Continue;
        end;
        LIndex := IndexOf(Self[i].RootControl.AnchorSide[LKind].Control);
        if LIndex >= 0 then
          Self[i].AnchorSide[LKind].Control := Self[LIndex]
        else
          Self[i].AnchorSide[LKind].Control := nil;
      end;
      Self[i].Anchors := Self[i].RootControl.Anchors;
    end;
end;

procedure TAnchorControls.CheckParents;
var
  LIndex, i: Integer;
begin
  for i := 1 to Count - 1 do
    if Self[i].IsInvalid then
      Continue
    else
    begin
      LIndex := IndexOf(Self[i].RootControl.Parent);
      if LIndex >= 0 then
        Self[i].SetNewParent(Self[LIndex])
      else
        // use BackGround
        Self[i].SetNewParent(Self[0]);
    end;
end;

procedure TAnchorControls.CheckProperties;
var
  i, LLeft, LTop, LWidth, LHeight: Integer;
begin
  for i := 1 to Count - 1 do
    if Self[i].IsInvalid or Self[i].IsChildControl then
      Continue
    else
    begin
      LLeft   := Self[i].RootControl.Left;
      LTop    := Self[i].RootControl.Top;
      LWidth  := Self[i].RootControl.Width;
      LHeight := Self[i].RootControl.Height;
      if (LLeft   <> Self[i].Left)
      or (LTop    <> Self[i].Top)
      or (LWidth  <> Self[i].Width)
      or (LHeight <> Self[i].Height) then
        Self[i].SetBounds(LLeft, LTop, LWidth, LHeight);

      Self[i].Align := Self[i].RootControl.Align;
      Self[i].BorderSpacing := Self[i].RootControl.BorderSpacing;
      Self[i].CreateCaption;
    end;
end;

procedure TAnchorControls.DeleteIndexAndAbove(AIndex: Integer);
begin
  while Count > AIndex do
    Delete(Count - 1);
end;

function TAnchorControls.IndexOf(AControl: TControl): Integer;
var
  i: Integer;
begin
  Result := - 1;
  for i := 0 to Count - 1 do
    if Self[i].RootControl = AControl then
      Exit(i);
end;

procedure TAnchorControls.Invalid;
var
  i: Integer;
begin
  for i := 1 to Count - 1 do
    Self[i].Invalid;
end;

function TAnchorControls.RemoveInvalid: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := Count - 1 downto 1 do
    if Self[i].IsInvalid then
    begin
      Delete(i);
      Result := True;
    end;
end;

{ TBorderControl }

constructor TBorderControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FBitmap := TBitmap.Create;
  FBitmap.SetSize(2, 2);
  FBitmap.Canvas.Pixels[0, 0] := DockedOptions.AnchorBorderColor;
  FBitmap.Canvas.Pixels[0, 1] := DockedOptions.AnchorControlColor;
  FBitmap.Canvas.Pixels[1, 0] := DockedOptions.AnchorControlColor;
  FBitmap.Canvas.Pixels[1, 1] := DockedOptions.AnchorBorderColor;
  BevelOuter := bvNone;
end;

destructor TBorderControl.Destroy;
begin
  FBitmap.Free;
  inherited Destroy;
end;

procedure TBorderControl.Paint;
begin
  Canvas.Brush.Style := bsImage;
  Canvas.Brush.Bitmap := FBitmap;
  Canvas.FillRect(0, 0, ClientWidth, ClientHeight);
end;

end.


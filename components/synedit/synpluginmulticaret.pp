unit SynPluginMultiCaret;

{$mode objfpc}{$H+}

{$DEFINE SynMultiCaretAssert}
{off $DEFINE SynMultiCaretDebug}

{$IfDef SynMultiCaretAssert}
  {$ASSERTIONS on}
{$ENDIF}

interface

uses
  Classes, SysUtils, SynEdit, SynEditPointClasses, SynEditKeyCmds, SynEditTypes,
  LazSynTextArea, SynEditMiscProcs, LazSynEditText, SynEditMiscClasses, SynEditMouseCmds,
  {$IfDef SynMultiCaretDebug} LazLoggerBase, {$ELSE} LazLoggerDummy, {$ENDIF}
  LCLType, Controls, Graphics, Clipbrd;

const

  emcPluginMultiCaretToggleCaret = emcPluginFirstMultiCaret;

type

  TSynPluginMultiCaretVisualList = class;

  { TSynPluginMultiCaretVisual }

  TSynPluginMultiCaretVisual = class(TSynEditScreenCaret)
  private
    FListIndex: Integer;
    FUsedList: TSynPluginMultiCaretVisualList;
    FUnUsedList: TSynPluginMultiCaretVisualList;
    {$IfDef SynMultiCaretAssert}
    FIsUsed: Boolean;
    {$ENDIF}
  public
    constructor Create(AHandleOwner: TWinControl;
      APainterClass: TSynEditScreenCaretPainterClass;
      AnUsedList, AnUnUsedList: TSynPluginMultiCaretVisualList);
    procedure MoveToUsed;
    procedure MoveToUnUsed;
    property ListIndex: Integer read FListIndex;
    property UsedList: TSynPluginMultiCaretVisualList read FUsedList;
    property UnUsedList: TSynPluginMultiCaretVisualList read FUnUsedList;
  end;

  { TSynPluginMultiCaretVisualList }

  TSynPluginMultiCaretVisualList = class
  private
    FList: Array of TSynPluginMultiCaretVisual;
    FCount: Integer;
    function GetScreenCaret(Index: Integer): TSynPluginMultiCaretVisual;
  public
    destructor Destroy; override;
    procedure Add(AScreenCaret: TSynPluginMultiCaretVisual);
    procedure Remove(AScreenCaret: TSynPluginMultiCaretVisual);
    procedure Clear; // free visuals
    function  Count: Integer;
    property  ScreenCaret[Index: Integer]: TSynPluginMultiCaretVisual read GetScreenCaret; default;
  end;

  TCaretFlag = (cfMainCaret, cfNoneVisual, cfAddDuplicate);
  TCaretFlags = set of TCaretFlag;

  { TSynPluginMultiCaretList }

  TSynPluginMultiCaretList = class
  private type
    //TCaretFlag = (cfMainCaret, cfNoneVisual);
    //TCaretFlags = set of TCaretFlag;
    TCaretData = record
      x, y: Integer; // logical
      Flags: TCaretFlags;
      Visual: TSynPluginMultiCaretVisual;
    end;
  private
    FLowIndex, FHighIndex: Integer;
    FMainCaretIndex: Integer;
    FCarets: Array of TCaretData;
    function FindEqOrNextCaretRawIdx(X, Y: Integer; LowIdx: integer = -1; HighIdx: integer = -1): Integer;
    function GetCaret(Index: Integer): TPoint; inline;
    function GetCaretX(Index: Integer): Integer; inline;
    function GetCaretY(Index: Integer): Integer; inline;
    function GetFlags(Index: Integer): TCaretFlags;
    function GetMainCaretIndex: Integer;
    function GetVisual(Index: Integer): TSynPluginMultiCaretVisual; inline;
    procedure SetCaret(Index: Integer; AValue: TPoint); inline;
    procedure SetCaretX(Index: Integer; AValue: Integer); inline;
    procedure SetCaretY(Index: Integer; AValue: Integer); inline;
    procedure SetVisual(Index: Integer; AValue: TSynPluginMultiCaretVisual); inline;

    function  InternalRemoveCaretEx(RawIndex: Integer; AlternativeRawIndex: Integer = -1): Integer;
    function  InternalRemoveCaret(RawIndex: Integer): integer;
    procedure AdjustAfterChange(RawIndex: Integer);
  public
    constructor Create;
    function  AddCaret(X, Y: Integer; flags: TCaretFlags = []): Integer;
    procedure RemoveCaret(Index: Integer);
    procedure Clear(AFreeVisual: Boolean = False);
    function  Count: Integer;
    function  FindCaretIdx(X, Y: Integer): Integer;
    procedure AdjustAllAfterEdit(aLinePos, aBytePos, aCount, aLineBrkCnt: Integer);
    procedure FindAndRemoveMergedCarets;

    property Caret[Index: Integer]: TPoint read GetCaret write SetCaret;
    property CaretX[Index: Integer]: Integer read GetCaretX write SetCaretX;
    property CaretY[Index: Integer]: Integer read GetCaretY write SetCaretY;
    property Visual[Index: Integer]: TSynPluginMultiCaretVisual read GetVisual write SetVisual;
    property Flags[Index: Integer]: TCaretFlags read GetFlags;
    property MainCaretIndex: Integer read GetMainCaretIndex;
  end;

  { TSynPluginMultiCaretBase }

  TSynPluginMultiCaretBase = class(TLazSynEditPlugin)
  private
    FCarets: TSynPluginMultiCaretList;
    FColor: TColor;
    FUsedList: TSynPluginMultiCaretVisualList;
    FUnUsedList: TSynPluginMultiCaretVisualList;
    FInPaint: Boolean;
    FPaintClip: TRect;

    FCustomPixelWidth, FCustomPixelHeight: Array [TSynCaretType] of Integer;
    FCustomOffsetX, FCustomOffsetY: Array [TSynCaretType] of Integer;
    FCustomFlags: Array [TSynCaretType] of TSynCustomCaretSizeFlags;

    FPaintLock: Integer;
    FPaintLockFlags: set of
      (plfUpdateCaretsPos, plfDeferUpdateCaretsPos,
       plfBoundsChanged, plfTextSizeChanged);

    function  GetTextArea: TLazSynTextArea;
    procedure DoTextSizeChanged(Sender: TObject);
    procedure DoBoundsChanged(Sender: TObject);
    procedure DoEditorPaintEvent(Sender: TObject; EventType: TSynPaintEvent;
      const prcClip: TRect);
    procedure DoEditorScrollEvent(Sender: TObject; EventType: TSynScrollEvent; dx,
      dy: Integer; const prcScroll, prcClip: TRect);
    procedure DoEditorStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure DoAfterDecPaintLock(Sender: TObject); virtual;
    procedure DoBeforeIncPaintLock(Sender: TObject); virtual;
    procedure DoBufferChanged(Sender: TObject);
    procedure DoLinesEdited(Sender: TSynEditStrings; aLinePos, aBytePos, aCount,
                            aLineBrkCnt: Integer; aText: String);
    procedure SetColor(AValue: TColor);
    property TextArea: TLazSynTextArea read GetTextArea;
    function CreateVisual: TSynPluginMultiCaretVisual; virtual;
    function GetVisual: TSynPluginMultiCaretVisual;
  protected
    function  AddCaret(X, Y: Integer; flags: TCaretFlags = []): Integer;
    procedure RemoveCaret(Index: Integer);
    procedure UpdateCaretsPos;
    procedure ClearCarets;
    function  CaretsCount: Integer;

    procedure DoEditorRemoving(AValue: TCustomSynEdit); override;
    procedure DoEditorAdded(AValue: TCustomSynEdit); override;

    property Carets: TSynPluginMultiCaretList read FCarets;
    property PaintLock: Integer read FPaintLock;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetCaretTypeSize(AType: TSynCaretType; AWidth, AHeight, AXOffs, AYOffs: Integer; AFlags: TSynCustomCaretSizeFlags);
    property Color: TColor read FColor write SetColor;
  end;

  { TSynPluginMultiCaretMouseActions }

  TSynPluginMultiCaretMouseActions = class(TSynEditMouseActions)
  public
    procedure ResetDefaults; override;
  end;

  { TSynPluginMultiCaret }

  TSynPluginMultiCaretStateFlag = (
    sfProcessingCmd, sfProcessingMain,
    sfExtendingColumnSel
  );
  TSynPluginMultiCaretStateFlags = set of TSynPluginMultiCaretStateFlag;

  TSynPluginMultiCaret = class(TSynPluginMultiCaretBase)
  private
    FStateFlags: TSynPluginMultiCaretStateFlags;
    FMouseActions: TSynPluginMultiCaretMouseActions;
  protected
    procedure DoEditorRemoving(AValue: TCustomSynEdit); override;
    procedure DoEditorAdded(AValue: TCustomSynEdit); override;

    procedure DoAfterDecPaintLock(Sender: TObject); override;

    procedure DoCaretChanged(Sender: TObject);
    procedure DoSelectionChanged(Sender: TObject);
    procedure DoBeforeSetSelText(Sender: TObject; AMode: TSynSelectionMode; ANewText: PChar);
    procedure ProcessSynCommand(Sender: TObject; AfterProcessing: boolean;
              var Handled: boolean; var Command: TSynEditorCommand;
              var AChar: TUTF8Char; Data: pointer; HandlerData: pointer);
    function MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
                         HandleActionProc: TSynEditMouseActionHandler): Boolean;
    function DoHandleMouseAction(AnAction: TSynEditMouseAction;
                                 var AnInfo: TSynEditMouseActionInfo): Boolean;

    function CreateVisual: TSynPluginMultiCaretVisual; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property MouseActions: TSynPluginMultiCaretMouseActions read FMouseActions;
  end;

implementation

var
  SynMCaretDebug: PLazLoggerLogGroup;

const
  EMPTY_LIST_LEN = 8;

{ TSynPluginMultiCaretVisual }

constructor TSynPluginMultiCaretVisual.Create(AHandleOwner: TWinControl;
  APainterClass: TSynEditScreenCaretPainterClass; AnUsedList,
  AnUnUsedList: TSynPluginMultiCaretVisualList);
begin
  FListIndex := -1;
  FUsedList := AnUsedList;
  FUnUsedList := AnUnUsedList;
  inherited Create(AHandleOwner, APainterClass);
end;

procedure TSynPluginMultiCaretVisual.MoveToUsed;
begin
  {$IfDef SynMultiCaretAssert}
  assert((FListIndex < 0) or (not FIsUsed), 'TSynPluginMultiCaretVisual.MoveToUsed: not yet on list');
  FIsUsed := True;
  {$ENDIF}
  if FListIndex >= 0 then
    FUnUsedList.Remove(Self);
  FUsedList.Add(Self);
end;

procedure TSynPluginMultiCaretVisual.MoveToUnUsed;
begin
  {$IfDef SynMultiCaretAssert}
  assert((FListIndex < 0) or FIsUsed, 'TSynPluginMultiCaretVisual.MoveToUnUsed: not yet on list');
  FIsUsed := False;
  {$ENDIF}
  if FListIndex >= 0 then
    FUsedList.Remove(Self);
  FUnUsedList.Add(Self);
  Visible := False;
end;

{ TSynPluginMultiCaretVisualList }

function TSynPluginMultiCaretVisualList.GetScreenCaret(Index: Integer): TSynPluginMultiCaretVisual;
begin
  Result := FList[Index];
end;

destructor TSynPluginMultiCaretVisualList.Destroy;
begin
  inherited Destroy;
  Clear;
end;

procedure TSynPluginMultiCaretVisualList.Add(AScreenCaret: TSynPluginMultiCaretVisual);
begin
  if (AScreenCaret.ListIndex >= 0) and (AScreenCaret.ListIndex < FCount) and
     (FList[AScreenCaret.ListIndex] = AScreenCaret)
  then begin
    assert(False, 'TSynPluginMultiCaretVisualList.Add: not on list');
    exit;
  end;

if FCount = Length(FList) then debugln(SynMCaretDebug, ['TSynPluginMultiCaretVisualList.Add ', FCount + max(16, FCount div 16)]);
  if FCount = Length(FList) then
    SetLength(FList, FCount + max(16, FCount div 16));

  FList[FCount] := AScreenCaret;
  AScreenCaret.FListIndex := FCount;
  inc(FCount);
end;

procedure TSynPluginMultiCaretVisualList.Remove(AScreenCaret: TSynPluginMultiCaretVisual);
var
  t: TSynPluginMultiCaretVisual;
begin
  if (AScreenCaret.ListIndex < 0) or (AScreenCaret.ListIndex >= FCount) or
     (FList[AScreenCaret.ListIndex] <> AScreenCaret)
  then begin
    assert(False, 'TSynPluginMultiCaretVisualList.Remove: not on list');
    exit;
  end;
  if AScreenCaret.ListIndex < FCount then begin
    t := FList[FCount - 1];
    FList[AScreenCaret.ListIndex] := t;
    t.FListIndex := AScreenCaret.ListIndex;
  end;
  AScreenCaret.FListIndex := -1;
  dec(FCount);
end;

procedure TSynPluginMultiCaretVisualList.Clear;
var
  i: Integer;
begin
  for i := 0 to FCount - 1 do
    FList[i].Free;
  FCount := 0;
  SetLength(FList, EMPTY_LIST_LEN);
end;

function TSynPluginMultiCaretVisualList.Count: Integer;
begin
  Result := FCount;
end;

{ TSynPluginMultiCaretList }

function TSynPluginMultiCaretList.FindEqOrNextCaretRawIdx(X, Y: Integer; LowIdx: integer;
  HighIdx: integer): Integer;
var
  l, h: Integer;
begin
  if LowIdx < 0
  then l := FLowIndex
  else l := LowIdx;
  if HighIdx < 0
  then h := FHighIndex
  else h := HighIdx;

  if h < l then begin
    Result := h;
    exit;
  end;

  Result := (l + h) div 2;
  while (h > l) do begin
    if (FCarets[Result].y > y) or ((FCarets[Result].y = y) and (FCarets[Result].x >= x)) then
      h := Result
    else
      l := Result + 1;
    Result := (l + h) div 2;
  end;
  if (FCarets[Result].y < y) or ((FCarets[Result].y = y) and (FCarets[Result].x < x)) then
    inc(Result);
end;

function TSynPluginMultiCaretList.GetCaret(Index: Integer): TPoint;
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.GetCaret: (Index>=FLowIndex) and (Index <= FHighIndex)');
  Result.x := FCarets[Index].x;
  Result.y := FCarets[Index].y;
end;

function TSynPluginMultiCaretList.GetCaretX(Index: Integer): Integer;
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.GetCaretX: (Index>=FLowIndex) and (Index <= FHighIndex)');
  Result := FCarets[Index].x;
end;

function TSynPluginMultiCaretList.GetCaretY(Index: Integer): Integer;
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.GetCaretY: (Index>=FLowIndex) and (Index <= FHighIndex)');
  Result := FCarets[Index].y;
end;

function TSynPluginMultiCaretList.GetFlags(Index: Integer): TCaretFlags;
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.GetFlags: (Index>=FLowIndex) and (Index <= FHighIndex)');
  Result := FCarets[Index].Flags;
end;

function TSynPluginMultiCaretList.GetMainCaretIndex: Integer;
begin
  if FMainCaretIndex >= FLowIndex then
    Result := FMainCaretIndex - FLowIndex
  else
    Result := -1;
end;

function TSynPluginMultiCaretList.GetVisual(Index: Integer): TSynPluginMultiCaretVisual;
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.GetVisual: (Index>=FLowIndex) and (Index <= FHighIndex)');
  Result := FCarets[Index].Visual;
end;

procedure TSynPluginMultiCaretList.SetCaret(Index: Integer; AValue: TPoint);
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.SetCaret: (Index>=FLowIndex) and (Index <= FHighIndex)');
  if (FCarets[Index].x = AValue.x) and (FCarets[Index].y = AValue.y) then exit;
  FCarets[Index].x := AValue.x;
  FCarets[Index].y := AValue.y;
  AdjustAfterChange(Index);
end;

procedure TSynPluginMultiCaretList.SetCaretX(Index: Integer; AValue: Integer);
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.SetCaretX: (Index>=FLowIndex) and (Index <= FHighIndex)');
  if FCarets[Index].x = AValue then exit;
  FCarets[Index].x := AValue;
  AdjustAfterChange(Index);
end;

procedure TSynPluginMultiCaretList.SetCaretY(Index: Integer; AValue: Integer);
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.SetCaretY: (Index>=FLowIndex) and (Index <= FHighIndex)');
  if FCarets[Index].y = AValue then exit;
  FCarets[Index].y := AValue;
  AdjustAfterChange(Index);
end;

procedure TSynPluginMultiCaretList.SetVisual(Index: Integer; AValue: TSynPluginMultiCaretVisual);
begin
  Index := Index + FLowIndex;
  assert((Index>=FLowIndex) and (Index <= FHighIndex), 'TSynPluginMultiCaretList.SetVisual: (Index>=FLowIndex) and (Index <= FHighIndex)');
  if FCarets[Index].Visual <> nil then
    FCarets[Index].Visual.MoveToUnUsed;
  FCarets[Index].Visual := AValue;
  if AValue <> nil then
    AValue.MoveToUsed;
end;

function TSynPluginMultiCaretList.InternalRemoveCaretEx(RawIndex: Integer;
  AlternativeRawIndex: Integer): Integer;
begin
  assert((RawIndex>=FLowIndex) and (RawIndex <= FHighIndex), 'TSynPluginMultiCaretList.InternalRemoveCaretEx: (Index>=FLowIndex) and (Index <= FHighIndex)');
  if (RawIndex = FMainCaretIndex) and (AlternativeRawIndex >= FLowIndex) then
    Result := InternalRemoveCaret(AlternativeRawIndex)
  else
    Result := InternalRemoveCaret(RawIndex);
end;

function TSynPluginMultiCaretList.InternalRemoveCaret(RawIndex: Integer): integer;
begin
  assert((RawIndex>=FLowIndex) and (RawIndex <= FHighIndex), 'TSynPluginMultiCaretList.InternalRemoveCaret: (RawIndex>=FLowIndex) and (RawIndex <= FHighIndex)');
  Result := 0; // change to LowCaret .. RawIndex

  if FCarets[RawIndex].Visual <> nil then
    FCarets[RawIndex].Visual.MoveToUnUsed;
  if RawIndex = FMainCaretIndex then
    FMainCaretIndex := -1;

  if RawIndex > (FHighIndex + FLowIndex) div 2 then begin
    if (RawIndex < FHighIndex) then
      Move(FCarets[RawIndex+1], FCarets[RawIndex], (FHighIndex - RawIndex) * SizeOf(FCarets[0]));
    dec(FHighIndex);
    if RawIndex < FMainCaretIndex then
      dec(FMainCaretIndex);
  end
  else begin
    if (RawIndex > FLowIndex) then
      Move(FCarets[FLowIndex], FCarets[FLowIndex+1], (RawIndex - FLowIndex) * SizeOf(FCarets[0]));
    inc(FLowIndex);
    if RawIndex > FMainCaretIndex then
      inc(FMainCaretIndex);
    Result := 1;
  end;

  //debugln(SynMCaretDebug, ['TSynPluginMultiCaretList.InternalRemoveCaret ', RawIndex, ' , ', count]);
end;

procedure TSynPluginMultiCaretList.AdjustAfterChange(RawIndex: Integer);
var
  NewIdx, y, x: Integer;
  v: TCaretData;
begin
  assert((RawIndex>=FLowIndex) and (RawIndex <= FHighIndex), 'TSynPluginMultiCaretList.AdjustAfterChange: (Index>=FLowIndex) and (Index <= FHighIndex)');
  NewIdx := RawIndex;
  y := FCarets[RawIndex].y;
  x := FCarets[RawIndex].x;
  if (RawIndex > FLowIndex) and
     ((y < FCarets[RawIndex-1].y) or ((y = FCarets[RawIndex-1].y) and (x <= FCarets[RawIndex-1].x)))
  then begin
    if (RawIndex-1 > FLowIndex) and
       ((y < FCarets[RawIndex-2].y) or ((y = FCarets[RawIndex-2].y) and (x < FCarets[RawIndex-2].x)))
    then
      NewIdx := FindEqOrNextCaretRawIdx(x,y, FLowIndex, RawIndex - 2)
    else
      NewIdx := RawIndex-1;

    if (y = FCarets[NewIdx].y) and (x = FCarets[NewIdx].x) then begin
      InternalRemoveCaretEx(RawIndex, NewIdx);
      exit;
    end;
    v := FCarets[RawIndex];
debugln(SynMCaretDebug, ['TSynPluginMultiCaretList.AdjustAfterChange ', NewIdx, ' ',RawIndex]);
    Move(FCarets[NewIdx], FCarets[NewIdx+1], (RawIndex-NewIdx) * SizeOf(FCarets[0]));
    FCarets[NewIdx] := v;
  end
  else
  if (RawIndex < FHighIndex) and
     ((y > FCarets[RawIndex+1].y) or ((y = FCarets[RawIndex+1].y) and (x >= FCarets[RawIndex+1].x)))
  then begin
    if (RawIndex+1 < FHighIndex) and
       ((y > FCarets[RawIndex+2].y) or ((y = FCarets[RawIndex+2].y) and (x > FCarets[RawIndex+2].x)))
    then
      NewIdx := FindEqOrNextCaretRawIdx(x,y, RawIndex + 2, FHighIndex)
    else
      NewIdx := RawIndex+1;

    if (y = FCarets[NewIdx].y) and (x = FCarets[NewIdx].x) then begin
      InternalRemoveCaretEx(RawIndex, NewIdx);
      exit;
    end;
    v := FCarets[RawIndex];
debugln(SynMCaretDebug, ['TSynPluginMultiCaretList.AdjustAfterChange ', NewIdx, ' ',RawIndex]);
    Move(FCarets[RawIndex+1], FCarets[RawIndex], (NewIdx-RawIndex) * SizeOf(FCarets[0]));
    FCarets[NewIdx] := v;
  end;
end;

constructor TSynPluginMultiCaretList.Create;
begin
  FLowIndex := 0;
  FHighIndex := -1;
  FMainCaretIndex := -1;
end;

function TSynPluginMultiCaretList.AddCaret(X, Y: Integer; flags: TCaretFlags): Integer;
var
  NewCarets: Array of TCaretData;
  Len, AddLen, i, Middle: Integer;
begin
  Result := FindEqOrNextCaretRawIdx(x, y);
  if Result < FLowIndex then
    Result := FLowIndex;
  if ((Result <= FHighIndex) and (FCarets[Result].x = x) and (FCarets[Result].y = y)) and
     not(cfAddDuplicate in flags)
  then begin
    FCarets[Result].Flags := flags - [cfMainCaret];
    if cfMainCaret in flags then
      FMainCaretIndex := Result;
    Result := Result - FLowIndex;
    exit;
  end;

  Len := length(FCarets) - 1;
  Middle := (FLowIndex + FHighIndex) div 2;
  if (FLowIndex > 0) and ((Result < Middle) or (FHighIndex = len))
  then begin
    // use space in front of list
    if (Result > FHighIndex) and (FHighIndex = High(FCarets))   // moving all entries
    then i := max(FLowIndex div 2 - 1, 0)                       // Make some room at the end of the list
    else i := 0;
    if Result > FLowIndex then
      Move(FCarets[FLowIndex], FCarets[FLowIndex-1-i], (Result-FLowIndex) * SizeOf(FCarets[0]));
    FLowIndex  := FLowIndex - 1 - i;
    FHighIndex := FHighIndex - i;
    Result     := Result - 1 - i;
    if Result > FMainCaretIndex
    then FMainCaretIndex := FMainCaretIndex - 1 - i
    else FMainCaretIndex := FMainCaretIndex - i;
  end
  else
  if FHighIndex < Len then begin
    // use space at end of list
    if (Result = FLowIndex) and (FLowIndex = 0)              // moving all entries
    then i := max((High(FCarets)-FHighIndex) div 2 - 1, 0)   // Make some room at the start of the list
    else i := 0;
    if Result <= FHighIndex then
      Move(FCarets[Result], FCarets[Result+1+i], (FHighIndex-Result+1) * SizeOf(FCarets[0]));
    FHighIndex := FHighIndex + 1 + i;
    FLowIndex  := FLowIndex + i;
    Result     := Result + i;
    if Result <= FMainCaretIndex
    then FMainCaretIndex := FMainCaretIndex + 1 + i
    else FMainCaretIndex := FMainCaretIndex + i;
  end
  else begin
    // realloc all
    AddLen := Max(32, Len div 8);
    SetLength(NewCarets, Len + 2 * AddLen);
    i := Result-FLowIndex;
    if i > 0 then
      Move(FCarets[FLowIndex], NewCarets[AddLen], (i) * SizeOf(FCarets[0]));
    if Result <= FHighIndex then
      Move(FCarets[Result], NewCarets[AddLen+i+1], (FHighIndex-Result+1) * SizeOf(FCarets[0]));

    if Result <= FMainCaretIndex
    then FMainCaretIndex := FMainCaretIndex - FLowIndex + AddLen + 1
    else FMainCaretIndex := FMainCaretIndex - FLowIndex + AddLen;

    FLowIndex := AddLen;
    FHighIndex := AddLen + Len + 1;
    Result := i + AddLen;
    FCarets := NewCarets;
  end;

  FCarets[Result].x := x;
  FCarets[Result].y := y;
  FCarets[Result].Visual := nil;
  FCarets[Result].Flags := flags - [cfMainCaret, cfAddDuplicate];

  if cfMainCaret in flags then
    FMainCaretIndex := Result;

  Result := Result - FLowIndex;
end;

procedure TSynPluginMultiCaretList.RemoveCaret(Index: Integer);
begin
  InternalRemoveCaret(Index+FLowIndex);
end;

procedure TSynPluginMultiCaretList.Clear(AFreeVisual: Boolean);
var
  i: Integer;
begin
  if AFreeVisual then
  begin
    for i := FLowIndex to FHighIndex do
      if FCarets[i].Visual <> nil then begin
        FCarets[i].Visual.UsedList.Remove(FCarets[i].Visual);
        FCarets[i].Visual.Free;
      end
  end
  else
    for i := FLowIndex to FHighIndex do
      if FCarets[i].Visual <> nil then
        FCarets[i].Visual.MoveToUnUsed;
  SetLength(FCarets, EMPTY_LIST_LEN);
  FLowIndex := 4;
  FHighIndex := 3;
  FMainCaretIndex := -1;
end;

function TSynPluginMultiCaretList.Count: Integer;
begin
  Result := FHighIndex - FLowIndex + 1;
end;

function TSynPluginMultiCaretList.FindCaretIdx(X, Y: Integer): Integer;
begin
  Result := FindEqOrNextCaretRawIdx(x, y);
  if (Result > FHighIndex) or (FCarets[Result].x <> x) or (FCarets[Result].y <> y)
  then
    Result := -1
  else
    Result := Result - FLowIndex;
end;

procedure TSynPluginMultiCaretList.AdjustAllAfterEdit(aLinePos, aBytePos, aCount,
  aLineBrkCnt: Integer);
var
  i, j, lowest: Integer;
begin
  if Count = 0 then exit;
  lowest := FindEqOrNextCaretRawIdx(aBytePos, aLinePos);

  if aLineBrkCnt = 0 then begin
    if aCount < 0 then begin
      i := lowest;
      while i <= FHighIndex do begin
        if (FCarets[i].y = aLinePos) and (FCarets[i].x >= aBytePos) then
          FCarets[i].x := Max(aBytePos, FCarets[i].x + aCount)
        else
          break;
        inc(i);
      end;
    end
    else begin // aCount >= 0
      for i := lowest to FHighIndex do begin
        if (FCarets[i].y = aLinePos) and (FCarets[i].x >= aBytePos) then
          FCarets[i].x := FCarets[i].x + aCount
        else
          break;
      end;
    end;
  end
  else // aLineBrkCnt = 0
  begin // aCount is always 0 (aBytePos:=max(1,aBytePos+aCount)) // aBytePos is the end of line
    if aLineBrkCnt < 0 then begin
      j := aLinePos+(-aLineBrkCnt);
      i := lowest;
      while i <= FHighIndex do begin
        if (FCarets[i].y < j) then
          FCarets[i].x := aBytePos;
        if (FCarets[i].y = j) then
          FCarets[i].x := FCarets[i].x - 1 + aBytePos
        else
          break;
        FCarets[i].y := aLinePos;
        inc(i);
      end;
      while i <= FHighIndex do begin
        FCarets[i].y := FCarets[i].y + aLineBrkCnt;
        inc(i);
      end;
    end
    else begin // aLineBrkCnt >= 0
      i := lowest;
      while i <= FHighIndex do begin
        if (FCarets[i].y = aLinePos) then
          FCarets[i].x := FCarets[i].x + 1 - aBytePos
        else
          break;
        FCarets[i].y := FCarets[i].y + aLineBrkCnt;
        inc(i);
      end;
      while i <= FHighIndex do begin
        FCarets[i].y := FCarets[i].y + aLineBrkCnt;
        inc(i);
      end;
    end;
  end;
end;

procedure TSynPluginMultiCaretList.FindAndRemoveMergedCarets;
var
  i, i2: Integer;
  c: TCaretData;
begin
  i := FLowIndex + 1;
  while i <= FHighIndex do begin
    if (FCarets[i].y = FCarets[i-1].y) and (FCarets[i].x = FCarets[i-1].x) then begin
      i := i + InternalRemoveCaretEx(i, i-1);
      continue;
    end;
    if (FCarets[i].y < FCarets[i-1].y) or
       ((FCarets[i].y = FCarets[i-1].y) and (FCarets[i].x < FCarets[i-1].x))
    then begin
      // should not happen
      debugln(SynMCaretDebug, ['TSynPluginMultiCaretList.FindAndRemoveMergedCarets BUBBLE SORTING']);
      i2 := i;
      c := FCarets[i2];
      repeat
        FCarets[i2] := FCarets[i2-1];
        dec(i2);
      until (i2 = FLowIndex) or (FCarets[i2].y > FCarets[i2-1].y) or
            ((FCarets[i2].y = FCarets[i2-1].y) and (FCarets[i2].x > FCarets[i2-1].x));
      FCarets[i2] := c;
      if FMainCaretIndex = i then
        FMainCaretIndex := i2;
      if (FMainCaretIndex < i) and (FMainCaretIndex >= i2) then
        inc(FMainCaretIndex);
    end;
    inc(i);
  end;
end;

{ TSynPluginMultiCaretBase }

procedure TSynPluginMultiCaretBase.DoBoundsChanged(Sender: TObject);
var
  i: Integer;
  ta: TLazSynTextArea;
begin
  if FPaintLock > 0 then begin
    include(FPaintLockFlags, plfBoundsChanged);
    exit;
  end;

  ta := TextArea;
  for i := 0 to FUsedList.Count - 1 do
    FUsedList[i].ClipRect := ta.Bounds;
  UpdateCaretsPos;
end;

procedure TSynPluginMultiCaretBase.DoLinesEdited(Sender: TSynEditStrings; aLinePos, aBytePos,
  aCount, aLineBrkCnt: Integer; aText: String);
begin
  Carets.AdjustAllAfterEdit(aLinePos, aBytePos, aCount, aLineBrkCnt);
end;

procedure TSynPluginMultiCaretBase.SetColor(AValue: TColor);
var
  i: Integer;
begin
  if FColor = AValue then Exit;
  FColor := AValue;
  for i := 0 to FUsedList.Count - 1 do
    TSynEditScreenCaretPainterInternal(FUsedList[i].Painter).Color := FColor;
end;

function TSynPluginMultiCaretBase.CreateVisual: TSynPluginMultiCaretVisual;
begin
  Result := TSynPluginMultiCaretVisual.Create(Editor,
    TSynEditScreenCaretPainterInternal,
    FUsedList, FUnUsedList);
  Result.PaintTimer:= ScreenCaret.PaintTimer;
end;

function TSynPluginMultiCaretBase.GetVisual: TSynPluginMultiCaretVisual;
var
  ta: TLazSynTextArea;
  i: TSynCaretType;
begin
  if FUnUsedList.Count > 0 then
    Result := FUnUsedList[FUnUsedList.Count-1]
  else
    Result := CreateVisual;

  ta := TextArea;
  Result.ClipRect   := ta.Bounds;
  Result.CharHeight := ta.LineHeight  - Max(0, ta.ExtraLineSpacing);
  Result.CharWidth  := ta.CharWidth;
  if Editor.InsertMode then
    Result.DisplayType := Editor.InsertCaret
  else
    Result.DisplayType := Editor.OverwriteCaret;
  for i := low(TSynCaretType) to high(TSynCaretType) do
    Result.SetCaretTypeSize(i, FCustomPixelWidth[i], FCustomPixelHeight[i], FCustomOffsetX[i], FCustomOffsetY[i], FCustomFlags[i]);
  TSynEditScreenCaretPainterInternal(Result.Painter).Color := FColor;
end;

procedure TSynPluginMultiCaretBase.DoTextSizeChanged(Sender: TObject);
var
  i: Integer;
  ta: TLazSynTextArea;
begin
  if FPaintLock > 0 then begin
    include(FPaintLockFlags, plfTextSizeChanged);
    exit;
  end;

  ta := TextArea;
  for i := 0 to FUsedList.Count - 1 do begin
    FUsedList[i].CharHeight := ta.LineHeight  - Max(0, ta.ExtraLineSpacing);
    FUsedList[i].CharWidth  := ta.CharWidth;
  end;
  UpdateCaretsPos;
end;

procedure TSynPluginMultiCaretBase.DoEditorPaintEvent(Sender: TObject;
  EventType: TSynPaintEvent; const prcClip: TRect);
var
  i: Integer;
begin
  if EventType = peAfterPaint then
    UpdateCaretsPos;

  case EventType of
    peBeforePaint:
      begin
        FInPaint := True;
        FPaintClip := prcClip;
        for i := 0 to FUsedList.Count - 1 do
          FUsedList[i].BeginPaint(prcClip);
        for i := 0 to FUnUsedList.Count - 1 do
          FUnUsedList[i].BeginPaint(prcClip);
      end;
    peAfterPaint:
      begin
        FInPaint := False;
        for i := 0 to FUsedList.Count - 1 do
          FUsedList[i].FinishPaint(prcClip);
        for i := 0 to FUnUsedList.Count - 1 do
          FUnUsedList[i].FinishPaint(prcClip);
      end;
  end;
end;

procedure TSynPluginMultiCaretBase.DoEditorScrollEvent(Sender: TObject;
  EventType: TSynScrollEvent; dx, dy: Integer; const prcScroll, prcClip: TRect);
var
  i: Integer;
begin
  case EventType of
    peBeforeScroll:
      for i := 0 to FUsedList.Count - 1 do
        FUsedList[i].BeginScroll(dx, dy, prcScroll, prcClip);
    peAfterScroll:
      for i := 0 to FUsedList.Count - 1 do
        FUsedList[i].FinishScroll(dx, dy, prcScroll, prcClip, True);
    peAfterScrollFailed:
      for i := 0 to FUsedList.Count - 1 do
        FUsedList[i].FinishScroll(dx, dy, prcScroll, prcClip, False);
  end;

  if EventType = peAfterScroll then
    UpdateCaretsPos;
end;

procedure TSynPluginMultiCaretBase.DoEditorStatusChanged(Sender: TObject;
  Changes: TSynStatusChanges);
var
  i: Integer;
  v: Boolean;
begin
  if scFocus in Changes then begin
    v := (Editor.Focused or (eoPersistentCaret in Editor.Options)) and not (eoNoCaret in Editor.Options);
    for i := 0 to FUsedList.Count - 1 do
      FUsedList[i].Visible := v;
  end;
  if scInsertMode in Changes then
    for i := 0 to FUsedList.Count - 1 do
      if Editor.InsertMode
      then FUsedList[i].DisplayType := Editor.InsertCaret
      else FUsedList[i].DisplayType := Editor.OverwriteCaret;
  if scOptions in Changes then begin
    for i := 0 to FUsedList.Count - 1 do begin
      if Editor.InsertMode
      then FUsedList[i].DisplayType := Editor.InsertCaret
      else FUsedList[i].DisplayType := Editor.OverwriteCaret;
      UpdateCaretsPos;
    end;
  end;
end;

procedure TSynPluginMultiCaretBase.DoAfterDecPaintLock(Sender: TObject);
begin
  if FPaintLock > 0 then
    Dec(FPaintLock);
  if FPaintLock > 0 then
    exit;

  Include(FPaintLockFlags, plfDeferUpdateCaretsPos);
  if plfBoundsChanged in FPaintLockFlags then
    DoBoundsChanged(nil);
  if plfTextSizeChanged in FPaintLockFlags then
    DoTextSizeChanged(nil);
  Exclude(FPaintLockFlags, plfDeferUpdateCaretsPos);
  if plfUpdateCaretsPos in FPaintLockFlags then
    UpdateCaretsPos;
  FPaintLockFlags := [];

  ScreenCaret.UnLock; // unlock timer
end;

procedure TSynPluginMultiCaretBase.DoBeforeIncPaintLock(Sender: TObject);
begin
  inc(FPaintLock);

  if FPaintLock = 1 then
    ScreenCaret.Lock; // lock timer
end;

function TSynPluginMultiCaretBase.GetTextArea: TLazSynTextArea;
begin
  Result := TLazSynSurfaceManager(PaintArea).TextArea;
end;

function TSynPluginMultiCaretBase.AddCaret(X, Y: Integer; flags: TCaretFlags): Integer;
var
  y1, y2: Integer;
begin
  Result := Carets.AddCaret(x,y, flags);
  if cfNoneVisual in flags then
    exit;

  if (eoNoCaret in Editor.Options) or
     not((eoPersistentCaret in Editor.Options) or Editor.Focused)
  then begin
    Carets.Visual[Result] := nil;
    exit;
  end;

  y1 := Editor.RowToScreenRow(y);
  if (y1 < 0) or (y1 > Editor.LinesInWindow + 1) then
    y := -1; // not visible
  if y > 1 then
    y2 := Editor.RowToScreenRow(y-1);

  if (y > 0) and (y1 <> y2) or (y=1) then begin
    if Carets.Visual[Result] = nil then
      Carets.Visual[Result] := GetVisual;
    x := Editor.LogicalToPhysicalPos(Point(x, y)).x;
    Carets.Visual[Result].DisplayPos := TextArea.RowColumnToPixels(Point(x, y1));
    Carets.Visual[Result].Visible := True;
  end
  else
    Carets.Visual[Result] := nil;
end;

procedure TSynPluginMultiCaretBase.RemoveCaret(Index: Integer);
begin
  Carets.RemoveCaret(Index);
end;

procedure TSynPluginMultiCaretBase.UpdateCaretsPos;
var
  i, x, y, w: Integer;
  y1, y2: Integer;
begin
  if plfDeferUpdateCaretsPos in FPaintLockFlags then exit;
  if FPaintLock > 0 then begin
    include(FPaintLockFlags, plfUpdateCaretsPos);
    exit;
  end;
  if (eoNoCaret in Editor.Options) or
     not((eoPersistentCaret in Editor.Options) or Editor.Focused)
  then begin
    for i := 0 to FUsedList.Count - 1 do
      FUsedList[i].Visible := False;
    exit;
  end;

  w := Editor.LinesInWindow + 1;
  for i := 0 to CaretsCount - 1 do begin
    if cfNoneVisual in Carets.Flags[i] then continue;

    x := Carets.CaretX[i];
    y := Carets.CaretY[i];
    y1 := Editor.RowToScreenRow(y);
    if (y1 < 0) or (y1 > w) then begin
      Carets.Visual[i] := nil;
      continue;
    end;

    if y > 1 then
      y2 := Editor.RowToScreenRow(y-1);

    if (y1 <> y2) or (y=1) then begin
      if Carets.Visual[i] = nil then
        Carets.Visual[i] := GetVisual;
      x := Editor.LogicalToPhysicalPos(Point(x, y)).x;
      Carets.Visual[i].DisplayPos := TextArea.RowColumnToPixels(Point(x, y1));
      Carets.Visual[i].Visible := True;
    end
    else
      Carets.Visual[i] := nil;
  end;
end;

procedure TSynPluginMultiCaretBase.ClearCarets;
begin
  Carets.Clear(True);
  FUsedList.Clear;
  FUnUsedList.Clear;
end;

function TSynPluginMultiCaretBase.CaretsCount: Integer;
begin
  Result := Carets.Count;
end;

procedure TSynPluginMultiCaretBase.DoBufferChanged(Sender: TObject);
begin
  TSynEditStrings(Sender).RemoveNotifyHandler(senrAfterDecPaintLock, @DoAfterDecPaintLock);
  TSynEditStrings(Sender).RemoveNotifyHandler(senrBeforeIncPaintLock, @DoBeforeIncPaintLock);
  TSynEditStrings(Sender).RemoveEditHandler(@DoLinesEdited);
  ViewedTextBuffer.AddEditHandler(@DoLinesEdited);
  ViewedTextBuffer.AddNotifyHandler(senrBeforeIncPaintLock, @DoBeforeIncPaintLock);
  ViewedTextBuffer.AddNotifyHandler(senrAfterDecPaintLock, @DoAfterDecPaintLock);
end;

procedure TSynPluginMultiCaretBase.DoEditorRemoving(AValue: TCustomSynEdit);
begin
  inherited DoEditorRemoving(AValue);
  if Editor <> nil then begin
    ClearCarets;
    TextArea.RemoveBoundsChangeHandler(@DoBoundsChanged);
    TextArea.RemoveTextSizeChangeHandler(@DoTextSizeChanged);
    Editor.UnRegisterStatusChangedHandler(@DoEditorStatusChanged);
    Editor.UnRegisterScrollEventHandler(@DoEditorScrollEvent);
    Editor.UnRegisterPaintEventHandler(@DoEditorPaintEvent);
    ViewedTextBuffer.RemoveNotifyHandler(senrAfterDecPaintLock, @DoAfterDecPaintLock);
    ViewedTextBuffer.RemoveNotifyHandler(senrBeforeIncPaintLock, @DoBeforeIncPaintLock);
    ViewedTextBuffer.RemoveEditHandler(@DoLinesEdited);
    ViewedTextBuffer.RemoveGenericHandler(senrTextBufferChanged, TMethod(@DoBufferChanged));
  end;
end;

procedure TSynPluginMultiCaretBase.DoEditorAdded(AValue: TCustomSynEdit);
begin
  if Editor <> nil then begin
    ViewedTextBuffer.AddGenericHandler(senrTextBufferChanged, TMethod(@DoBufferChanged));
    ViewedTextBuffer.AddEditHandler(@DoLinesEdited);
    ViewedTextBuffer.AddNotifyHandler(senrBeforeIncPaintLock, @DoBeforeIncPaintLock);
    ViewedTextBuffer.AddNotifyHandler(senrAfterDecPaintLock, @DoAfterDecPaintLock);
    Editor.RegisterPaintEventHandler(@DoEditorPaintEvent, [peBeforePaint, peAfterPaint]);
    Editor.RegisterScrollEventHandler(@DoEditorScrollEvent, [peBeforeScroll, peAfterScroll, peAfterScrollFailed]);
    Editor.RegisterStatusChangedHandler(@DoEditorStatusChanged, [scInsertMode, scFocus, scOptions]);
    TextArea.AddTextSizeChangeHandler(@DoTextSizeChanged);
    TextArea.AddBoundsChangeHandler(@DoBoundsChanged);

    if ScreenCaret.Painter.ClassType = TSynEditScreenCaretPainterSystem then
      ScreenCaret.ChangePainter(TSynEditScreenCaretPainterInternal);
  end;
  inherited DoEditorAdded(AValue);
end;

constructor TSynPluginMultiCaretBase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FColor := clBlack;
  FCarets := TSynPluginMultiCaretList.Create;
  FUsedList := TSynPluginMultiCaretVisualList.Create;
  FUnUsedList := TSynPluginMultiCaretVisualList.Create;
end;

destructor TSynPluginMultiCaretBase.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FCarets);
  FreeAndNil(FUsedList);
  FreeAndNil(FUnUsedList);
end;

procedure TSynPluginMultiCaretBase.SetCaretTypeSize(AType: TSynCaretType; AWidth, AHeight,
  AXOffs, AYOffs: Integer; AFlags: TSynCustomCaretSizeFlags);
var
  i: Integer;
begin
  FCustomPixelWidth[AType] := AWidth;
  FCustomPixelHeight[AType] := AHeight;
  FCustomOffsetX[AType] := AXOffs;
  FCustomOffsetY[AType] := AYOffs;
  FCustomFlags[AType] := AFlags;

  for i := 0 to FUsedList.Count - 1 do
    FUsedList[i].SetCaretTypeSize(AType, AWidth, AHeight, AXOffs, AYOffs, AFlags)
end;

{ TSynPluginMultiCaretMouseActions }

procedure TSynPluginMultiCaretMouseActions.ResetDefaults;
begin
  Clear; // todo left button
  AddCommand(emcPluginMultiCaretToggleCaret, False, mbXMiddle, ccAny, cdDown, [ssShift], [ssShift,ssCtrl,ssAlt]);
end;

{ TSynPluginMultiCaret }

procedure TSynPluginMultiCaret.DoEditorRemoving(AValue: TCustomSynEdit);
begin
  if Editor <> nil then begin
    CaretObj.RemoveChangeHandler(@DoCaretChanged);
    SelectionObj.RemoveChangeHandler(@DoSelectionChanged);
    Editor.UnregisterCommandHandler(@ProcessSynCommand);
    //Editor.UnRegisterKeyTranslationHandler(@TranslateKey);
    Editor.UnregisterMouseActionSearchHandler(@MaybeHandleMouseAction);
    Editor.UnregisterMouseActionExecHandler(@DoHandleMouseAction);
  end;
  inherited DoEditorRemoving(AValue);
end;

procedure TSynPluginMultiCaret.DoEditorAdded(AValue: TCustomSynEdit);
begin
  inherited DoEditorAdded(AValue);
  if Editor <> nil then begin
    Editor.RegisterMouseActionSearchHandler(@MaybeHandleMouseAction);
    Editor.RegisterMouseActionExecHandler(@DoHandleMouseAction);
    Editor.RegisterCommandHandler(@ProcessSynCommand, nil, [hcfInit, hcfFinish]);
    //Editor.RegisterKeyTranslationHandler(@TranslateKey);
    SelectionObj.AddChangeHandler(@DoSelectionChanged);
    CaretObj.AddChangeHandler(@DoCaretChanged);
  end;
end;

procedure TSynPluginMultiCaret.DoAfterDecPaintLock(Sender: TObject);
begin
  if FPaintLock > 1 then begin
    inherited DoAfterDecPaintLock(Sender);
    exit;
  end;

  UpdateCaretsPos;
  inherited DoAfterDecPaintLock(Sender);
  FStateFlags := FStateFlags - [sfProcessingCmd, sfExtendingColumnSel];
end;

procedure TSynPluginMultiCaret.DoCaretChanged(Sender: TObject);
begin
  if (FStateFlags * [sfProcessingCmd, sfExtendingColumnSel] <> []) then
    exit;
  ClearCarets;
end;

procedure TSynPluginMultiCaret.DoSelectionChanged(Sender: TObject);
var
  i, x, y1, y2, y3: Integer;
  c: TPoint;
begin
  if (sfProcessingCmd in FStateFlags) then exit;
  y1 := Editor.BlockBegin.y;
  y2 := Editor.BlockEnd.y;
  If not ((y1 <> y2) and (Editor.SelectionMode = smColumn)) then begin
    ClearCarets;
    exit;
  end;

  x := Editor.LogicalCaretXY.x;
  y3 := Editor.CaretY;
  i := CaretsCount;
  while i > 0 do begin
    dec(i);
    c := Carets.Caret[i];
    if (c.x <> x) or
       (c.y < y1) or (c.y > y2) or (c.y = y3)
    then
      RemoveCaret(i);
  end;

  for i := y1 to y2 do begin
    if i= y3 then continue;
    AddCaret(x, i);
  end;

end;

procedure TSynPluginMultiCaret.DoBeforeSetSelText(Sender: TObject; AMode: TSynSelectionMode;
  ANewText: PChar);
begin
  SelectionObj.RemoveBeforeSetSelTextHandler(@DoBeforeSetSelText);

  SelectionObj.SelText := '';
  if Carets.MainCaretIndex >= 0 then begin
    Editor.LogicalCaretXY := Carets.Caret[Carets.MainCaretIndex];
  end
  else
    assert(False, 'TSynPluginMultiCaret.ProcessSynCommand: Maincaret index not found');
end;

procedure TSynPluginMultiCaret.ProcessSynCommand(Sender: TObject; AfterProcessing: boolean;
  var Handled: boolean; var Command: TSynEditorCommand; var AChar: TUTF8Char; Data: pointer;
  HandlerData: pointer);

  procedure ExecCommandRepeated;
  var
    c, i: Integer;
  begin
    Handled := True;
    Editor.BeginUpdate(True);
    try
      c := AddCaret(Editor.LogicalCaretXY.x, Editor.CaretY, [cfMainCaret, cfNoneVisual, cfAddDuplicate]);

      // Execute Command at current caret pos
      Include(FStateFlags, sfProcessingMain);
      if Editor.SelAvail and (SelectionObj.ActiveSelectionMode = smColumn) then
        SelectionObj.AddBeforeSetSelTextHandler(@DoBeforeSetSelText);
      Editor.CommandProcessor(Command, AChar, data, [hcfInit, hcfFinish]);
      SelectionObj.RemoveBeforeSetSelTextHandler(@DoBeforeSetSelText);
      Exclude(FStateFlags, sfProcessingMain);
// if there was no change, then do not re-exec ?

      // Repeat command
      CaretObj.IncForcePastEOL;
      for i := 0 to CaretsCount - 1 do begin
        if i = c then continue;
        Editor.LogicalCaretXY := Carets.Caret[i];
        Editor.CommandProcessor(Command, AChar, nil, [hcfInit, hcfFinish]);
      end;
      CaretObj.DecForcePastEOL;

      Carets.FindAndRemoveMergedCarets;
      if Carets.MainCaretIndex >= 0 then begin
        Editor.LogicalCaretXY := Carets.Caret[Carets.MainCaretIndex];
        RemoveCaret(Carets.MainCaretIndex);
      end
      else
        assert(False, 'TSynPluginMultiCaret.ProcessSynCommand: Maincaret index not found');
    finally
      Editor.EndUpdate;
    end;
  end;

  procedure HandleNewColSelection;
  begin
  end;

var
  ClipHelper: TSynClipboardStream;
begin
  if (sfProcessingCmd in FStateFlags) or (CaretsCount = 0) then
    exit;
  if AfterProcessing then begin
    if sfExtendingColumnSel in FStateFlags then
      HandleNewColSelection;
    UpdateCaretsPos;
    exit;
  end;
  if Handled then exit;


  (* use Editor.CommandProcessor(... SkipInit=[hcfInit, hcfFinish])
     command is already initialized / prevent macro recorder from recording again.
  *)

  case Command of
  // TODO: delete and smColumn -- only delete once
    ecDeleteLastChar..ecDeleteLine,
    ecLineBreak..ecChar:
      begin
        Include(FStateFlags, sfProcessingCmd);
        if Editor.ReadOnly then exit;
        ExecCommandRepeated;
      end;
    ecPaste:
      begin
        Include(FStateFlags, sfProcessingCmd);
        if Editor.ReadOnly then exit;

        if (SelectionObj.ActiveSelectionMode = smColumn) and
           (SelectionObj.StartLinePos <> SelectionObj.EndLinePos)
        then begin
          ClipHelper := TSynClipboardStream.Create;
          try
            ClipHelper.ReadFromClipboard(Clipboard);
            if ClipHelper.SelectionMode = smColumn then begin
              Exclude(FStateFlags, sfProcessingCmd);
              exit;
            end;
          finally
            ClipHelper.Free;
          end;
        end;

        ExecCommandRepeated;
      end;
    ecTab..ecShiftTab:
      begin
        Include(FStateFlags, sfProcessingCmd);
        if Editor.ReadOnly then exit;

        if (eoTabIndent in Editor.Options) and Editor.SelAvail and
           (SelectionObj.ActiveSelectionMode = smColumn)
        then begin
          // no indent for column mode, when multicaret
          Editor.BeginUpdate(True);
          try
            AddCaret(Editor.LogicalCaretXY.x, Editor.CaretY, [cfMainCaret, cfNoneVisual, cfAddDuplicate]);
            Editor.SelText := '';
            if Carets.MainCaretIndex >= 0 then begin
              Editor.LogicalCaretXY := Carets.Caret[Carets.MainCaretIndex];
              RemoveCaret(Carets.MainCaretIndex);
            end
            else
              assert(False, 'TSynPluginMultiCaret.ProcessSynCommand: Maincaret index not found');
            ExecCommandRepeated;
          finally
            Editor.EndUpdate;
          end;
        end
        else
          ExecCommandRepeated;
      end;
    ecSelColCmdRangeStart..ecSelColCmdRangeEnd:
      begin
        Include(FStateFlags, sfExtendingColumnSel);
      end;
    ecCopy,
    ecScrollUp..ecScrollRight,
    ecInsertMode..ecToggleMode,
    ecNormalSelect, ecLineSelect,
    ecSetMarker0..ecSetMarker9,
    ecToggleMarker0..ecToggleMarker9,
    EcFoldLevel1..EcFoldLevel9, EcFoldLevel0, EcFoldCurrent,
    ecGotFocus, ecLostFocus
    :
      ; // Ignore, if no changes occur
    else
      ClearCarets;
  end;

end;

function TSynPluginMultiCaret.MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
  HandleActionProc: TSynEditMouseActionHandler): Boolean;
begin
  Result := HandleActionProc(FMouseActions, AnInfo);
end;

function TSynPluginMultiCaret.DoHandleMouseAction(AnAction: TSynEditMouseAction;
  var AnInfo: TSynEditMouseActionInfo): Boolean;
var
  i: Integer;
begin
  Result := False;

  if AnAction.Command = emcPluginMultiCaretToggleCaret then begin
    i := Carets.FindCaretIdx(AnInfo.NewCaret.BytePos, AnInfo.NewCaret.LinePos);
    if i >= 0 then
      RemoveCaret(i)
    else
      AddCaret(AnInfo.NewCaret.BytePos, AnInfo.NewCaret.LinePos);
  end;
end;

function TSynPluginMultiCaret.CreateVisual: TSynPluginMultiCaretVisual;
begin
  Result := inherited CreateVisual;
  if FInPaint then
    Result.BeginPaint(FPaintClip);
end;

constructor TSynPluginMultiCaret.Create(AOwner: TComponent);
begin
  FMouseActions := TSynPluginMultiCaretMouseActions.Create(Self);
  FMouseActions.ResetDefaults;
  inherited Create(AOwner);
end;

destructor TSynPluginMultiCaret.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FMouseActions);
end;

{$IfDef SynMultiCaretDebug}
initialization
  SynMCaretDebug := DebugLogger.FindOrRegisterLogGroup('SynMultiCaretDebug' {$IFDEF SynMultiCaretDebug} , True {$ENDIF} );
{$ENDIF}
end.


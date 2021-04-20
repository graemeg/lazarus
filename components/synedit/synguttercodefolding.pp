{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

-------------------------------------------------------------------------------}

unit SynGutterCodeFolding;

{$I synedit.inc}

interface

uses
  SysUtils, Classes, Controls, Graphics, Menus, LCLIntf, SynGutterBase,
  SynEditMiscProcs, SynEditFoldedView, SynEditMouseCmds,
  SynEditHighlighterFoldBase, LCLProc, LCLType, ImgList, Forms;

type

  { TSynEditMouseActionsGutterFold }

  TSynEditMouseActionsGutterFold = class(TSynEditMouseInternalActions)
  protected
    procedure InitForOptions(AnOptions: TSynEditorMouseOptions); override;
  end;

  // Line with [-] => ALL nodes expanded

  { TSynEditMouseActionsGutterFoldExpanded }

  TSynEditMouseActionsGutterFoldExpanded = class(TSynEditMouseInternalActions)
  protected
    procedure InitForOptions(AnOptions: TSynEditorMouseOptions); override;
  end;

  // Line with [+] => at LEAST ONE node collapsed

  { TSynEditMouseActionsGutterFoldCollapsed }

  TSynEditMouseActionsGutterFoldCollapsed = class(TSynEditMouseInternalActions)
  protected
    procedure InitForOptions(AnOptions: TSynEditorMouseOptions); override;
  end;

  TDrawNodeSymbolOptions = set of (nsoSubtype, nsoLostHl, nsoBlockSel);

  TSynGutterImageList = class(TImageList)
  public
    InitPPI: Integer;
  end;

  { TSynGutterCodeFolding }

  TSynGutterCodeFolding = class(TSynGutterPartBase)
  private
    const cNodeOffset = 1;
  private
    FMouseActionsCollapsed: TSynEditMouseInternalActions;
    FMouseActionsExpanded: TSynEditMouseInternalActions;
    FPopUp: TPopupMenu;
    FMenuInf: Array of TFoldViewNodeInfo;
    FIsFoldHidePreviousLine: Boolean;
    FPopUpImageList: TSynGutterImageList;
    FReversePopMenuOrder: Boolean;
    FPpiPenWidth: Integer;
    procedure FPopUpOnPopup(Sender: TObject);
    function GetFoldView: TSynEditFoldedView;
    function GetMouseActionsCollapsed: TSynEditMouseActions;
    function GetMouseActionsExpanded: TSynEditMouseActions;
    procedure SetMouseActionsCollapsed(const AValue: TSynEditMouseActions);
    procedure SetMouseActionsExpanded(const AValue: TSynEditMouseActions);
    function  FoldTypeForLine(AScreenLine: Integer): TSynEditFoldLineCapability;
    function  IsFoldHidePreviousLine(AScreenLine: Integer): Boolean;
    function  IsSingleLineHide(AScreenLine: Integer): Boolean;
    procedure InitPopUpImageList(const APPI: Integer);
    procedure DrawNodeSymbol(Canvas: TCanvas; Rect: TRect;
                             NodeType: TSynEditFoldLineCapability;
                             SubType: TDrawNodeSymbolOptions);
  protected
    function  PreferedWidth: Integer; override;
    procedure CreatePopUpMenuEntries(var APopUp: TPopupMenu; ALine: Integer); virtual;
    procedure PopClicked(Sender: TObject);
    function CreateMouseActions: TSynEditMouseInternalActions; override;
    procedure SetWidth(const AValue: integer); override;
    property FoldView: TSynEditFoldedView read GetFoldView;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ScalePPI(const AScaleFactor: Double); override;

    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
      override;
    procedure DoOnGutterClick(X, Y: integer); override;
    function MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
               HandleActionProc: TSynEditMouseActionHandler): Boolean; override;
    function DoHandleMouseAction(AnAction: TSynEditMouseAction;
                                 var AnInfo: TSynEditMouseActionInfo): Boolean; override;
    procedure ResetMouseActions; override; // set mouse-actions according to current Options / may clear them
  published
    property MarkupInfo;
    property MouseActionsExpanded: TSynEditMouseActions
      read GetMouseActionsExpanded write SetMouseActionsExpanded;
    property MouseActionsCollapsed: TSynEditMouseActions
      read GetMouseActionsCollapsed write SetMouseActionsCollapsed;
    property ReversePopMenuOrder: Boolean
      read FReversePopMenuOrder write FReversePopMenuOrder default True;
  end;

implementation

var
  GlobalPopUpImageList: TSynGutterImageList = nil;


{ TSynGutterCodeFolding }

procedure TSynGutterCodeFolding.SetMouseActionsCollapsed(const AValue: TSynEditMouseActions);
begin
  FMouseActionsCollapsed.UserActions := AValue;
end;

function TSynGutterCodeFolding.GetMouseActionsCollapsed: TSynEditMouseActions;
begin
  Result := FMouseActionsCollapsed.UserActions;
end;

function TSynGutterCodeFolding.GetMouseActionsExpanded: TSynEditMouseActions;
begin
  Result := FMouseActionsExpanded.UserActions;
end;

procedure TSynGutterCodeFolding.SetMouseActionsExpanded(const AValue: TSynEditMouseActions);
begin
  FMouseActionsExpanded.UserActions := AValue;
end;

function TSynGutterCodeFolding.FoldTypeForLine(AScreenLine: Integer): TSynEditFoldLineCapability;
var
  tmp, tmp2: TSynEditFoldLineCapabilities;
begin
  tmp := FoldView.FoldType[AScreenLine];
  tmp2 := FoldView.FoldType[AScreenLine-1];
  FIsFoldHidePreviousLine := False;
  if (AScreenLine = 0) and (ToIdx(GutterArea.TextArea.TopLine) = 0) and
     (cfCollapsedHide in tmp2)
  then begin
    Result := cfCollapsedHide;
    FIsFoldHidePreviousLine := True;
    // exit
  end
  //if tmp * [cfHideStart, cfFoldStart, cfCollapsedFold] = [cfHideStart, cfFoldStart, cfCollapsedFold]
  //                               then Result := cfHideStart
  else if cfCollapsedFold in tmp then Result := cfCollapsedFold
  else if cfCollapsedHide in tmp then Result := cfCollapsedHide
  else if cfFoldStart     in tmp then Result := cfFoldStart
  else if cfHideStart     in tmp then Result := cfHideStart
  else if cfFoldEnd       in tmp then Result := cfFoldEnd
  else if cfFoldBody      in tmp then Result := cfFoldBody
  else
    Result := cfNone;

  if (Result in [cfCollapsedFold, cfCollapsedHide, cfFoldStart]) and
     (cfHideStart in tmp) and
     (fncBlockSelection in FoldView.FoldClasifications[AScreenLine])
  then begin
    Result := cfHideStart;
  end;

  if (Result in [cfFoldBody, cfFoldEnd]) and
     not(fncBlockSelection in FoldView.FoldClasifications[AScreenLine-1])
  then begin
    tmp := FoldView.FoldType[AScreenLine - 1];
    if tmp * [cfHideStart, cfFoldStart, cfCollapsedFold, cfCollapsedHide]
       = [cfHideStart, cfFoldStart]
    then begin
      FIsFoldHidePreviousLine := True;
      Result := cfHideStart // hide for previous line
    end;
  end;
end;

procedure TSynGutterCodeFolding.FPopUpOnPopup(Sender: TObject);
var
  MonitorPPI: Integer;
begin
  MonitorPPI := Screen.MonitorFromPoint(FPopUp.PopupPoint).PixelsPerInch;
  if (FPopUpImageList.Count=0) or (FPopUpImageList.InitPPI<>MonitorPPI) then
    InitPopUpImageList(MonitorPPI);
end;

function TSynGutterCodeFolding.GetFoldView: TSynEditFoldedView;
begin
  Result := TSynEditFoldedView(FoldedTextBuffer);
end;

function TSynGutterCodeFolding.IsFoldHidePreviousLine(AScreenLine: Integer): Boolean;
begin
  FoldTypeForLine(AScreenLine);
  Result := FIsFoldHidePreviousLine;
end;

function TSynGutterCodeFolding.IsSingleLineHide(AScreenLine: Integer): Boolean;
var
  tmp: TSynEditFoldLineCapabilities;
begin
  Result := False;
  tmp := FoldView.FoldType[AScreenLine];
  if tmp * [cfHideStart, cfFoldStart, cfCollapsedFold] =
     [cfHideStart, cfFoldStart, cfCollapsedFold]
  then
    Result := True;
  if cfSingleLineHide in tmp then
    Result := True;
end;

procedure TSynGutterCodeFolding.InitPopUpImageList(const APPI: Integer);
var
  img: TBitmap;
  R: TRect;
  procedure NewImg;
  begin
    img := TBitmap.Create;
    img.SetSize(FPopUpImageList.Width, FPopUpImageList.Height);
    img.Canvas.Brush.Color := clWhite;
    img.Canvas.FillRect(img.Canvas.ClipRect);
    img.Canvas.Pen.Color := clBlack;
    img.Canvas.Pen.Width := 1;
  end;
begin
  FPopUpImageList.DrawingStyle := dsTransparent;
  FPopUpImageList.Clear;
  FPopUpImageList.Width := MulDiv(16, APPI, 96);
  FPopUpImageList.Height := FPopUpImageList.Width;
  FPopUpImageList.InitPPI := APPI;

  R.Left := MulDiv(3, APPI, 96);
  R.Top := R.Left;
  R.Right := MulDiv(14, APPI, 96);
  R.Bottom := R.Right;

  NewImg;
  DrawNodeSymbol(img.Canvas, R, cfFoldStart, []);  // [-]
  FPopUpImageList.AddMasked(img, img.TransparentColor);
  img.Free;

  NewImg;
  DrawNodeSymbol(img.Canvas, R, cfCollapsedFold, []);  // [+]
  FPopUpImageList.AddMasked(img, img.TransparentColor);
  img.Free;

  NewImg;
  DrawNodeSymbol(img.Canvas, R, cfHideStart, []);  // [.]
  FPopUpImageList.AddMasked(img, img.TransparentColor);
  img.Free;

  NewImg;
  DrawNodeSymbol(img.Canvas, R, cfCollapsedHide, []);  // [v]
  FPopUpImageList.AddMasked(img, img.TransparentColor);
  img.Free;

end;

procedure TSynGutterCodeFolding.CreatePopUpMenuEntries(var APopUp: TPopupMenu;
  ALine: Integer);

  function AddPopUpItem(const ACaption: String): TMenuItem;
  begin
    Result := TMenuItem.Create(APopUp);
    Result.OnClick := @PopClicked;
    Result.Caption := ACaption;
    Result.GlyphShowMode := gsmAlways;
    if FReversePopMenuOrder then
      APopUp.Items.Add(Result)
    else
      APopUp.Items.Insert(0, Result);
  end;

var
  c, i: Integer;
  inf: TFoldViewNodeInfo;
  m: TMenuItem;
  s, s2: String;
begin
  if APopUp = nil then begin
    if not assigned(GlobalPopUpImageList) then begin
      // Todo: Add a flag, when using global list, or make list ref-counted
      // See Destroy
      GlobalPopUpImageList  := TSynGutterImageList.Create(nil);
      FPopUpImageList := GlobalPopUpImageList;
    end
    else
      FPopUpImageList := GlobalPopUpImageList;

    APopUp := TPopupMenu.Create(nil);
    APopUp.Images := FPopUpImageList;
    APopUp.OnPopup := @FPopUpOnPopup;
  end
  else
    APopUp.Items.Clear;

  c := Min(100, FoldView.OpenFoldCount(ALine-1));
  if c > 0 then begin
    SetLength(FMenuInf,c);
    for i := c-1 downto 0 do begin
      inf := FoldView.OpenFoldInfo(ALine-1, i);
      if sfaInvalid in inf.HNode.FoldAction then
        continue;
      FMenuInf[i] := inf;
      if (i < c-1) and (FMenuInf[i+1].LineNum = ALine) and (inf.LineNum <> ALine)
      then begin
        m := AddPopUpItem(cLineCaption);
        m.Tag := -1;
      end;
      s := copy(inf.Text, 1, inf.HNode.LogXStart-1);
      if length(s) > 30 then s := copy(s,1,15) + '...' + copy(s, inf.HNode.LogXStart-11,10);
      s := s + copy(inf.Text, inf.HNode.LogXStart, 30 + (30 - length(s)));
      s2 := '';
      if inf.OpenCount > 1 then
        s2 := format(' (%d/%d)', [inf.ColIndex+1, inf.OpenCount]);

      if inf.IsFold then begin
        m := AddPopUpItem(format('%4d %s '#9'%s', [ inf.LineNum, inf.Keyword+s2+':', s]));
        m.Tag := i;
        if inf.IsHide then
          m.ImageIndex := 3
        else
          m.ImageIndex := 1;
      end
      else begin
        if sfaFoldFold in inf.HNode.FoldAction then begin
          m := AddPopUpItem(format('%4d %s '#9'%s', [ inf.LineNum, inf.Keyword+s2+':', s]));
          m.Tag := i;
          m.ImageIndex := 0;
        end;
        if sfaFoldHide in inf.HNode.FoldAction then begin
          if sfaFoldFold in inf.HNode.FoldAction then
            m := AddPopUpItem(format('%4d %s ', [ inf.LineNum, inf.Keyword+s2 ]))
          else
            m := AddPopUpItem(format('%4d %s '#9'%s', [ inf.LineNum, inf.Keyword+s2+':', s]));
          m.Tag := i;
          m.ImageIndex := 2;
        end;
      end;
    end;
  end;
end;

constructor TSynGutterCodeFolding.Create(AOwner: TComponent);
begin
  FPpiPenWidth := 1;
  FReversePopMenuOrder := true;
  FMouseActionsExpanded := TSynEditMouseActionsGutterFoldExpanded.Create(self);
  FMouseActionsCollapsed := TSynEditMouseActionsGutterFoldCollapsed.Create(self);

  inherited Create(AOwner);

  MarkupInfo.Background := clNone;
  MarkupInfo.Foreground := clDkGray;
  MarkupInfo.FrameColor := clNone;
end;

destructor TSynGutterCodeFolding.Destroy;
begin
  FreeAndNil(FMouseActionsCollapsed);
  FreeAndNil(FMouseActionsExpanded);
  FreeAndNil(FPopUp);
  // Todo: Currently only the global list is used. No Free is ever needed.
  // See: CreatePopUpMenuEntries
  // SynEdit could be destroyed, after finalization of this unit, then the condition would fail
  //if FPopUpImageList <> GlobalPopUpImageList then
  //  FreeAndNil(FPopUpImageList);
  inherited Destroy;
end;

procedure TSynGutterCodeFolding.ScalePPI(const AScaleFactor: Double);
begin
  inherited ScalePPI(AScaleFactor);
  FPpiPenWidth := Max(1, Scale96ToFont(1));
end;

procedure TSynGutterCodeFolding.PopClicked(Sender: TObject);
var
  inf: TFoldViewNodeInfo;
begin
   inf := FMenuInf[(Sender as TMenuItem).tag];
   if inf.LineNum < 0 then exit;
   case (Sender as TMenuItem).ImageIndex of
     0: FoldView.FoldAtTextIndex(inf.LineNum-1, inf.ColIndex, 1, False);
     1: FoldView.UnFoldAtTextIndex(inf.LineNum-1, inf.ColIndex, 1, False);
     2: FoldView.FoldAtTextIndex(inf.LineNum-1, inf.ColIndex, 1, False, 0);
     3: FoldView.UnFoldAtTextIndex(inf.LineNum-1, inf.ColIndex, 1, False, 0);
   end;
end;

function TSynGutterCodeFolding.CreateMouseActions: TSynEditMouseInternalActions;
begin
  Result := TSynEditMouseActionsGutterFold.Create(self);
end;

procedure TSynGutterCodeFolding.SetWidth(const AValue: integer);
begin
  if (Width=AValue) or (AutoSize) then exit;
  inherited SetWidth(AValue);

  FPpiPenWidth := Max(1, Scale96ToFont(1));
end;

procedure TSynGutterCodeFolding.DoOnGutterClick(X, Y : integer);
begin
  // Do Nothing
end;

function TSynGutterCodeFolding.MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
  HandleActionProc: TSynEditMouseActionHandler): Boolean;
var
  tmp: TSynEditFoldLineCapability;
  ScrLine: Integer;
begin
  Result := False;
  ScrLine := ToIdx(AnInfo.NewCaret.ViewedLinePos) - ToIdx(GutterArea.TextArea.TopLine);
  tmp := FoldTypeForLine(ScrLine);
  case tmp of
    cfCollapsedFold, cfCollapsedHide:
      Result := HandleActionProc(FMouseActionsCollapsed.GetActionsForOptions(SynEdit.MouseOptions), AnInfo);
    cfFoldStart, cfHideStart:
      Result := HandleActionProc(FMouseActionsExpanded.GetActionsForOptions(SynEdit.MouseOptions), AnInfo);
  end;

  if not Result then
    Result := inherited MaybeHandleMouseAction(AnInfo, HandleActionProc);
end;

function TSynGutterCodeFolding.DoHandleMouseAction(AnAction: TSynEditMouseAction;
  var AnInfo: TSynEditMouseActionInfo): Boolean;
var
  i, line, ScrLine: Integer;
  ACommand: Word;
  KeepVisible: Integer;
begin
  Result := False;
  if AnAction = nil then exit;
  ACommand := AnAction.Command;
  if (ACommand = emcNone) then exit;
  line := AnInfo.NewCaret.LinePos;

  ScrLine := ToIdx(AnInfo.NewCaret.ViewedLinePos) - ToIdx(GutterArea.TextArea.TopLine);

  // TODO: Keepvisible is incorrect, if the line can fold AND unfold, and the action does not match the symbol

  KeepVisible := 1;
  if (FoldTypeForLine(ScrLine) = cfHideStart) and (ACommand <> emcCodeFoldExpand) then
    KeepVisible := 0;

  if (FoldTypeForLine(ScrLine) = cfCollapsedHide) then begin
    if IsFoldHidePreviousLine(ScrLine) then
      line := ToPos(ViewedTextBuffer.DisplayView.ViewToTextIndex(ScrLine - 1 + ToIdx(GutterArea.TextArea.TopLine)));
    inc(line);
    KeepVisible := 0;
  end
  else
    if IsFoldHidePreviousLine(ScrLine) then dec(line);

  Result := True;
  case ACommand of
    emcCodeFoldCollaps:
      begin
        case AnAction.Option of
          emcoCodeFoldCollapsOne:
            begin
              FoldView.FoldAtTextIndex(Line-1, -1, 1, True, KeepVisible);
            end;
          emcoCodeFoldCollapsAll:
            begin
              FoldView.FoldAtTextIndex(Line-1, -1, 0, False, KeepVisible);
            end;
          emcoCodeFoldCollapsAtCaret:
            // Keyword at mouseclick/caret position
            begin
              i := FoldView.LogicalPosToNodeIndex(Line-1, AnInfo.NewCaret.BytePos, False);
              if i >= 0 then
                FoldView.FoldAtTextIndex(Line-1, i, 1, False, KeepVisible)
              else
                Result := False;
            end;
          emcoCodeFoldCollapsPreCaret:
            // mouseclick/caret position anywhere inside the fold
            begin
              i := FoldView.LogicalPosToNodeIndex(Line-1, AnInfo.NewCaret.BytePos, True);
              if i >= 0 then
                FoldView.FoldAtTextIndex(Line-1, i, 1, False, KeepVisible)
              else begin
                i := FoldView.ExpandedLineForBlockAtLine(Line);
                if i > 0 then
                  FoldView.FoldAtTextIndex(i-1, -1, 1, True, KeepVisible);
              end;
            end;
        end;
      end;
    emcCodeFoldExpand:
      begin
        case AnAction.Option of
          emcoCodeFoldExpandOne:
            FoldView.UnFoldAtTextIndex(line-1, 0, 1, True, KeepVisible);
          emcoCodeFoldExpandAll:
            FoldView.UnFoldAtTextIndex(line-1, -1, 0, False, KeepVisible);
        end;
      end;
    emcCodeFoldContextMenu:
      begin
        CreatePopUpMenuEntries(FPopUp, line);
        AnInfo.ActionResult.PopUpMenu := FPopUp;
      end;
    else
      Result := False;
  end;
end;

procedure TSynGutterCodeFolding.ResetMouseActions;
begin
  inherited;
  FMouseActionsExpanded.Options := SynEdit.MouseOptions;
  FMouseActionsExpanded.ResetUserActions;
  FMouseActionsCollapsed.Options := SynEdit.MouseOptions;
  FMouseActionsCollapsed.ResetUserActions;
end;

procedure TSynGutterCodeFolding.DrawNodeSymbol(Canvas: TCanvas; Rect: TRect;
  NodeType: TSynEditFoldLineCapability; SubType: TDrawNodeSymbolOptions);
var
  Points: Array [0..3] of TPoint;
  X, Y, LineBorder, c, LineBorderEnd: Integer;
  AliasMode: TAntialiasingMode;
  OdlCosmetic: Boolean;
begin
  AliasMode := Canvas.AntialiasingMode;
  Canvas.AntialiasingMode:=amOff;
  OdlCosmetic := Canvas.Pen.Cosmetic;
  if nsoLostHl in SubType then begin
    Canvas.Pen.Style := psDot;
    Canvas.Pen.Cosmetic := False;
  end;
  if nsoBlockSel in SubType then begin
    Canvas.Pen.Style := psDash;
    Canvas.Pen.Cosmetic := False;
  end;
  Canvas.Pen.JoinStyle := pjsMiter;
  Canvas.Rectangle(Rect);
  Canvas.Pen.Style := psSolid;
  Canvas.Pen.Cosmetic := OdlCosmetic;
  c := Canvas.Pen.Width div 2;
  LineBorder := Round((Rect.Right-Rect.Left) / 5) + c;
  LineBorderEnd := LineBorder + c;
  X := (Rect.Left - 1 + Rect.Right) div 2;
  Y := (Rect.Top - 1 + Rect.Bottom) div 2;

  case NodeType of
    cfFoldStart:
      begin
        // [-]
        Canvas.MoveTo(Rect.Left + LineBorder, Y);
        Canvas.LineTo(Rect.Right - LineBorderEnd, Y);
      end;
    cfHideStart:
      begin
        // [.]
        Canvas.MoveTo(X, Y);
        Canvas.LineTo(X + 1, Y);
      end;
    cfCollapsedFold:
      begin
        // [+]
        Canvas.MoveTo(Rect.Left + LineBorder, Y);
        Canvas.LineTo(Rect.Right - LineBorderEnd, Y);
        Canvas.MoveTo(X, Rect.Top + LineBorder);
        Canvas.LineTo(X, Rect.Bottom - LineBorderEnd);
      end;
    cfCollapsedHide:
      begin
        case nsoSubtype in SubType of
          false: begin
              // [v]
              Points[0].X := X;
              Points[0].y := Rect.Bottom - LineBorder - 1;
              Points[1].X := Rect.Left + LineBorder;
              Points[1].y := Y;
              Points[2].X := Rect.Right - LineBorder - 1;
              Points[2].y := Y;
              Points[3] := Points[0];
          end;
          true: begin
              // [v]
              Points[0].X := X;
              Points[0].y := Rect.Top + LineBorder;
              Points[1].X := Rect.Left + LineBorder;
              Points[1].y := Y;
              Points[2].X := Rect.Right - LineBorder - 1;
              Points[2].y := Y;
              Points[3] := Points[0];
          end;
        end;
        Canvas.Polygon(Points);
      end;
  end;
  Canvas.AntialiasingMode := AliasMode;
end;

function TSynGutterCodeFolding.PreferedWidth: Integer;
const PrefFullWidth = 10;
begin
  Result :=
    Max(PrefFullWidth div 2, Min(PrefFullWidth, SynEdit.LineHeight - cNodeOffset));
end;

procedure TSynGutterCodeFolding.Paint(Canvas : TCanvas; AClip : TRect; FirstLine, LastLine : integer);
var
  iLine: integer;
  rcLine: TRect;
  rcCodeFold: TRect;
  tmp: TSynEditFoldLineCapability;
  LineHeight, TextHeight, LineOffset, HalfBoxSize: Integer;

  procedure DrawNodeBox(rcCodeFold: TRect; NodeType: TSynEditFoldLineCapability);
  var
    rcNode: TRect;
    ptCenter : TPoint;
    isPrevLine: Boolean;
    DrawOpts: TDrawNodeSymbolOptions;
    c: Integer;
  begin

    isPrevLine := IsFoldHidePreviousLine(iLine);
    LineOffset := 0;
    DrawOpts := [];
    if fncHighlighterEx in FoldView.FoldClasifications[iLine] then
      include(DrawOpts, nsoLostHl)
    else
    if fncBlockSelection in FoldView.FoldClasifications[iLine] then
      include(DrawOpts, nsoBlockSel);

    //center of the draw area
    ptCenter.X := (rcCodeFold.Left + rcCodeFold.Right) div 2;
    ptCenter.Y := Max(HalfBoxSize,
                      (rcCodeFold.Top + Min(rcCodeFold.Top+TextHeight, rcCodeFold.Bottom)) div 2);

    // If belongs to line above, draw at very top
    if isPrevLine then
      ptCenter.Y := rcCodeFold.Top + (HalfBoxSize) - 1;
    c := Canvas.Pen.Width div 2;

    //area of drawbox
    rcNode.Left   := ptCenter.X - (HalfBoxSize) + 1 + c;
    rcNode.Right  := ptCenter.X + (HalfBoxSize) - c;
    rcNode.Top    := ptCenter.Y - (HalfBoxSize) + 1 + c;
    rcNode.Bottom := ptCenter.Y + (HalfBoxSize) - c;

    Canvas.Brush.Style := bsClear;

    //draw Paragraph end
    if isPrevLine and (cfFoldEnd in FoldView.FoldType[iLine]) and
       (rcCodeFold.Bottom-1 > rcNode.Bottom)
    then begin
      Canvas.MoveTo(ptCenter.X, rcNode.Bottom);
      Canvas.LineTo(ptCenter.X, rcCodeFold.Bottom-1);
      Canvas.LineTo(rcCodeFold.Right, rcCodeFold.Bottom-1);
      LineOffset := min(2, (rcCodeFold.Top + rcCodeFold.Bottom) div 2);
    end
    else
    //draw bottom handle to paragraph line
    if (cfFoldBody in FoldView.FoldType[iLine + 1]) and
       (not IsSingleLineHide(iLine))
    then begin
      Canvas.MoveTo(ptCenter.X, rcNode.Bottom);
      Canvas.LineTo(ptCenter.X, rcCodeFold.Bottom);
    end;

    if (NodeType in [cfCollapsedFold, cfCollapsedHide]) and
       (MarkupInfo.FrameColor <> clNone)
    then
      Canvas.Pen.Color := MarkupInfo.FrameColor;

    if isPrevLine and (NodeType = cfCollapsedHide) then
      include(DrawOpts, nsoSubtype);
    DrawNodeSymbol(Canvas, rcNode, NodeType, DrawOpts);

    Canvas.Pen.Color := MarkupInfo.Foreground;
    Canvas.Brush.Style := bsSolid;
  end;

  procedure DrawParagraphContinue(rcCodeFold: TRect);
  var
    iCenter : integer;
  begin
    //center of the draw area
    iCenter := (rcCodeFold.Left + rcCodeFold.Right) div 2;

    Canvas.MoveTo(iCenter, rcCodeFold.Top + LineOffset);
    Canvas.LineTo(iCenter, rcCodeFold.Bottom);
    LineOffset := 0;
  end;

  procedure DrawParagraphEnd(rcCodeFold: TRect);
  var
    X : Integer;
  begin
    //center of the draw area
    X := (rcCodeFold.Left + rcCodeFold.Right) div 2;

    Canvas.MoveTo(X, rcCodeFold.Top + LineOffset);
    Canvas.LineTo(X, rcCodeFold.Bottom - 1);
    Canvas.LineTo(rcCodeFold.Right, rcCodeFold.Bottom - 1);
    LineOffset := min(2, (rcCodeFold.Top + rcCodeFold.Bottom) div 2);
  end;

begin
  if not Visible then exit;
  LineHeight := SynEdit.LineHeight;
  TextHeight := LineHeight - Max(0, SynEdit.ExtraLineSpacing);
  LineOffset := 0;
  if (FirstLine > 0) and
     (FoldView.FoldType[FirstLine-1] - [cfFoldBody] = [cfFoldEnd]) then
    LineOffset := 2;
  HalfBoxSize := Min(Width, LineHeight - cNodeOffset*2) div 2;

  if MarkupInfo.Background <> clNone then
  begin
    Canvas.Brush.Color := MarkupInfo.Background;
    LCLIntf.SetBkColor(Canvas.Handle, TColorRef(Canvas.Brush.Color));
    Canvas.FillRect(AClip);
  end;

  with Canvas do
  begin
    Pen.Color := MarkupInfo.Foreground;
    Pen.EndCap := pecSquare;
    Pen.Width := Min(Max(1, Min(Width, HalfBoxSize*2 - cNodeOffset*2) div 5), FPpiPenWidth);

    rcLine.Bottom := AClip.Top;
    for iLine := FirstLine to LastLine do
    begin
      // next line rect
      rcLine.Top := rcLine.Bottom;
      Inc(rcLine.Bottom, LineHeight);

      rcCodeFold.Left := AClip.Left;
      rcCodeFold.Right := AClip.Left + self.Width;
      rcCodeFold.Top := rcLine.Top;
      rcCodeFold.Bottom := rcLine.Bottom;

      tmp := FoldTypeForLine(iLine);
      case tmp of
        cfFoldStart, cfHideStart, cfCollapsedFold, cfCollapsedHide:
          DrawNodeBox(rcCodeFold, tmp);
        cfFoldBody:
          DrawParagraphContinue(rcCodeFold);
        cfFoldEnd:
          DrawParagraphEnd(rcCodeFold);
        else
          LineOffset := 0;
      end;
    end;
  end;

end;

{ TSynEditMouseActionsGutterFold }

procedure TSynEditMouseActionsGutterFold.InitForOptions(AnOptions: TSynEditorMouseOptions);
var
  rmc: Boolean;
begin
  Clear;
  rmc := (emRightMouseMovesCursor in AnOptions);

  AddCommand(emcNone,                False,  mbXLeft, ccAny, cdDown, [], []);

  AddCommand(emcCodeFoldCollaps,     False, mbXMiddle, ccAny, cdDown, [], [ssShift], emcoCodeFoldCollapsOne);
  AddCommand(emcCodeFoldCollaps,     False, mbXMiddle, ccAny, cdDown, [ssShift], [ssShift], emcoCodeFoldCollapsAll);

  AddCommand(emcCodeFoldContextMenu, rmc,   mbXRight, ccSingle, cdUp, [], []);
end;

{ TSynEditMouseActionsGutterFoldExpanded }

procedure TSynEditMouseActionsGutterFoldExpanded.InitForOptions(AnOptions: TSynEditorMouseOptions);
begin
  Clear;
  AddCommand(emcCodeFoldCollaps, False, mbXLeft, ccAny, cdDown, [], [], emcoCodeFoldCollapsOne);
end;

{ TSynEditMouseActionsGutterFoldCollapsed }

procedure TSynEditMouseActionsGutterFoldCollapsed.InitForOptions(AnOptions: TSynEditorMouseOptions);
begin
  Clear;
  AddCommand(emcCodeFoldExpand, False, mbXLeft, ccAny, cdDown, [ssCtrl], [ssCtrl], emcoCodeFoldExpandOne);
  AddCommand(emcCodeFoldExpand, False, mbXLeft, ccAny, cdDown, [], [ssCtrl], emcoCodeFoldExpandAll);
end;


finalization
  FreeAndNil(GlobalPopUpImageList);

end.


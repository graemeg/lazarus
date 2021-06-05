{
/***************************************************************************
                               SourceSynEditor
                             -------------------

 ***************************************************************************/

 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************

  Abstract:
    SynEdit extensions for the IDE
    - DebugMarks: Mark lines with debug info
}
unit SourceSynEditor;

{$mode objfpc}{$H+}

interface

{$IFDEF Windows}
  {$IFnDEF WithoutWinIME}
    {$DEFINE WinIME}
  {$ENDIF}
{$ENDIF}

{$I ide.inc}

uses
  LazSynIMMBase,
  {$IFDEF WinIME}
  LazSynIMM,
  {$ENDIF}
  Classes, SysUtils,
  // LCL
  Controls, LCLProc, LCLType, Graphics, Menus, ImgList,
  // synedit
  SynEdit, SynEditMiscClasses, SynGutter, SynGutterBase, SynEditMarks,
  SynEditTypes, SynGutterLineNumber, SynGutterCodeFolding, SynGutterMarks,
  SynGutterChanges, SynGutterLineOverview, SynEditMarkup,
  SynEditMarkupGutterMark, SynEditMarkupSpecialLine, SynEditTextBuffer,
  SynEditFoldedView, SynTextDrawer, SynEditTextBase, LazSynEditText,
  SynPluginTemplateEdit, SynPluginSyncroEdit, LazSynTextArea,
  SynEditHighlighter, SynEditHighlighterFoldBase, SynHighlighterPas,
  SynEditMarkupHighAll, SynEditKeyCmds, SynEditMarkupIfDef, SynEditMiscProcs,
  SynPluginMultiCaret, SynEditPointClasses,
  SynEditMarkupFoldColoring, SynEditTextTabExpander,
  etSrcEditMarks, LazarusIDEStrConsts;

type

  TIDESynGutterMarks = class;
  {$IFDEF WithSynDebugGutter}
  TIDESynGutterDebugHL = class;
  {$ENDIF}

  { TSourceLazSynTopInfoView }

  TSourceLazSynTopInfoView = class(TLazSynDisplayViewEx)
  private
    FLineMapCount: integer;
    FLineMap: array of integer;
    function GetLineMap(Index: Integer): Integer;
    procedure SetLineMap(Index: Integer; AValue: Integer);
    procedure SetLineMapCount(AValue: integer);
  public
    procedure SetHighlighterTokensLine(ALine: TLineIdx; out ARealLine: TLineIdx; out AStartBytePos, ALineByteLen: Integer); override;
    function GetLinesCount: Integer; override;
    function TextToViewIndex(AIndex: TLineIdx): TLineRange; override;
    function ViewToTextIndex(AIndex: TLineIdx): TLineIdx; override;
  public
    constructor Create;
    property LineMapCount: integer read FLineMapCount write SetLineMapCount;
    property LineMap[Index: Integer]: Integer read GetLineMap write SetLineMap;
  end;

  { TSourceLazSynSurfaceGutter }

  TSourceLazSynSurfaceGutter = class(TLazSynGutterArea)
  private
    procedure TextSizeChanged(Sender: TObject);
  protected
    procedure DoPaint(ACanvas: TCanvas; AClip: TRect); override;
    procedure SetTextArea(ATextArea: TLazSynTextArea); override;
  end;

  { TSourceLazSynSurfaceManager }

  TSourceLazSynSurfaceManager = class(TLazSynSurfaceManager)
  private
    FExtraManager: TLazSynSurfaceManager;
    FOriginalManager: TLazSynSurfaceManager;
    FTopLineCount: Integer;
    procedure SetTopLineCount(AValue: Integer);
  protected
    function GetLeftGutterArea: TLazSynSurfaceWithText; override;
    function GetRightGutterArea: TLazSynSurfaceWithText; override;
    function GetTextArea: TLazSynTextArea; override;
  protected
    procedure SetBackgroundColor(AValue: TColor); override;
    procedure SetExtraCharSpacing(AValue: integer); override;
    procedure SetExtraLineSpacing(AValue: integer); override;
    procedure SetForegroundColor(AValue: TColor); override;
    procedure SetPadding(Side: TLazSynBorderSide; AValue: integer); override;
    procedure SetRightEdgeColor(AValue: TColor); override;
    procedure SetRightEdgeColumn(AValue: integer); override;
    procedure SetRightEdgeVisible(AValue: boolean); override;
    procedure SetVisibleSpecialChars(AValue: TSynVisibleSpecialChars); override;
    procedure SetHighlighter(AValue: TSynCustomHighlighter); override;
  protected
    procedure DoPaint(ACanvas: TCanvas; AClip: TRect); override;
    procedure DoDisplayViewChanged; override;
    procedure BoundsChanged; override;
  public
    constructor Create(AOwner: TWinControl; AnOriginalManager: TLazSynSurfaceManager);
    destructor Destroy; override;
    procedure  InvalidateLines(FirstTextLine, LastTextLine: TLineIdx); override;
    procedure InvalidateTextLines(FirstTextLine, LastTextLine: TLineIdx); override;
    procedure InvalidateGutterLines(FirstTextLine, LastTextLine: TLineIdx); override;
    property ExtraManager: TLazSynSurfaceManager read FExtraManager write FExtraManager;
    property OriginalManager: TLazSynSurfaceManager read FOriginalManager write FOriginalManager;
    property TopLineCount: Integer read FTopLineCount write SetTopLineCount;
  end;

  { TSourceSynSearchTermList }

  TSourceSynSearchTermList = class(TSynSearchTermList)
  public
    function FindMatchFor(ATerm: String; ACasesSensitive: Boolean;
                          ABoundaries: TSynSearchTermOptsBounds;
                          AStartAtIndex: Integer = 0;
                          AIgnoreIndex: Integer = -1): Integer;
    function FindSimilarMatchFor(ATerm: String; ACasesSensitive: Boolean;
                          ABoundaries: TSynSearchTermOptsBounds;
                          AEnabled: Boolean;
                          AStartAtIndex: Integer = 0;
                          AIgnoreIndex: Integer = -1;
                          AnOnlyWeakerOrEqual: Boolean = False;
                          AnSkipDisabled: Boolean = False): Integer; // weaker = matches less (subset of stronger)
    function FindSimilarMatchFor(ATerm: TSynSearchTerm;
                          AStartAtIndex: Integer = 0;
                          AIgnoreIndex: Integer = -1;
                          AnOnlyWeakerOrEqual: Boolean = False;
                          AnSkipDisabled: Boolean = False): Integer; // weaker = matches less (subset of stronger)
    procedure ClearSimilarMatches;
  end;

  { TSourceSynSearchTermDict }

  TSourceSynSearchTermDict = class(TSynSearchTermDict)
  private
    FModifiedTerms: TSynSearchTermList;
    FAddedByKeyWords: TSynSearchTermList;
    FFirstLocal: Integer;
    function GetTerms: TSourceSynSearchTermList;
    function  AddSearchTerm(ATerm: String): Integer;
  public
    constructor Create(ATermListClass: TSynSearchTermListClass);
    destructor Destroy; override;
    procedure AddTermByKey(ATerm: String; ACaseSensitive: Boolean;
      ABounds: TSynSearchTermOptsBounds);
    procedure RemoveTermByKey(RemoveIdx: Integer);
    procedure RestoreLocalChanges;
    property Terms: TSourceSynSearchTermList read GetTerms;
  end;

  { TSourceSynEditMarkupHighlightAllMulti }

  TSourceSynEditMarkupHighlightAllMulti = class(TSynEditMarkupHighlightAllMulti)
  private
    FAddTermCmd: TSynEditorCommand;
    FKeyAddCase: Boolean;
    FKeyAddSelectBoundMaxLen: Integer;
    FKeyAddSelectSmart: Boolean;
    FKeyAddWordBoundMaxLen: Integer;
    FKeyAddTermBounds: TSynSearchTermOptsBounds;
    FRemoveTermCmd: TSynEditorCommand;
    FToggleTermCmd: TSynEditorCommand;

    procedure ProcessSynCommand(Sender: TObject; {%H-}AfterProcessing: boolean;
              var Handled: boolean; var Command: TSynEditorCommand;
              var {%H-}AChar: TUTF8Char; {%H-}Data: pointer; {%H-}HandlerData: pointer);
  protected
    function CreateTermsList: TSynSearchTermDict; override;
  public
    constructor Create(ASynEdit: TSynEditBase);
    destructor Destroy; override;
    procedure RestoreLocalChanges;
    property AddTermCmd: TSynEditorCommand read FAddTermCmd write FAddTermCmd;
    property RemoveTermCmd: TSynEditorCommand read FRemoveTermCmd write FRemoveTermCmd;
    property ToggleTermCmd: TSynEditorCommand read FToggleTermCmd write FToggleTermCmd;
    property KeyAddTermBounds: TSynSearchTermOptsBounds read FKeyAddTermBounds write FKeyAddTermBounds;
    property KeyAddCase: Boolean read FKeyAddCase write FKeyAddCase;
    property KeyAddWordBoundMaxLen: Integer read FKeyAddWordBoundMaxLen write FKeyAddWordBoundMaxLen;
    property KeyAddSelectBoundMaxLen: Integer read FKeyAddSelectBoundMaxLen write FKeyAddSelectBoundMaxLen;
    property KeyAddSelectSmart: Boolean read FKeyAddSelectSmart write FKeyAddSelectSmart;
  end;

  TSourceSynEditMarkupIfDef = class(TSynEditMarkupIfDef)
  public
    property IfDefTree;
  end;

  TSynMarkupIdentComplWindow = class // don't inherit from TSynEditMarkup, no regular markup
  private
    FBackgroundSelectedColor: TColor;
    FBorderColor: TColor;
    FHighlightColor: TColor;
    FTextColor: TColor;
    FTextSelectedColor: TColor;
    FWindowColor: TColor;
  public
    constructor Create;
  public
    property WindowColor: TColor read FWindowColor write FWindowColor;
    property TextColor: TColor read FTextColor write FTextColor;
    property BorderColor: TColor read FBorderColor write FBorderColor;
    property HighlightColor: TColor read FHighlightColor write FHighlightColor;
    property TextSelectedColor: TColor read FTextSelectedColor write FTextSelectedColor;
    property BackgroundSelectedColor: TColor read FBackgroundSelectedColor write FBackgroundSelectedColor;
  end;

  { TIDESynEditor }

  TIDESynEditor = class(TSynEdit)
  private
    FCaretColor: TColor;
    FCaretStamp: Int64;
    FMarkupIdentComplWindow: TSynMarkupIdentComplWindow;
    FShowTopInfo: boolean;
    FFoldView: TSynEditFoldedView;
    FTopInfoNestList: TLazSynEditNestedFoldsList;
    FSyncroEdit: TSynPluginSyncroEdit;
    FTemplateEdit: TSynPluginTemplateEdit;
    FMultiCaret: TSynPluginMultiCaret;
    FMarkupForGutterMark: TSynEditMarkupGutterMark;
    FOnIfdefNodeStateRequest: TSynMarkupIfdefStateRequest;
    FMarkupIfDef: TSourceSynEditMarkupIfDef;
    FTopInfoDisplay: TSourceLazSynTopInfoView;
    FTopInfoLastTopLine: Integer;
    FSrcSynCaretChangedLock, FSrcSynCaretChangedNeeded: boolean;
    FExtraMarkupLine: TSynEditMarkupSpecialLine;
    FExtraMarkupMgr: TSynEditMarkupManager;
    FTopInfoMarkup: TSynSelectedColor;
    FUserWordsList: TFPList;

    function DoIfDefNodeStateRequest(Sender: TObject; LinePos,
      XStartPos: Integer; CurrentState: TSynMarkupIfdefNodeStateEx): TSynMarkupIfdefNodeState;
    function GetHighlightUserWordCount: Integer;
    function GetHighlightUserWords(AIndex: Integer): TSourceSynEditMarkupHighlightAllMulti;
    function GetIDEGutterMarks: TIDESynGutterMarks;
    function GetIsInMultiCaretMainExecution: Boolean;
    function GetIsInMultiCaretRepeatExecution: Boolean;
    function GetOnMultiCaretBeforeCommand: TSynMultiCaretBeforeCommand;
    procedure GetTopInfoMarkupForLine(Sender: TObject; {%H-}Line: integer; var Special: boolean;
      aMarkup: TSynSelectedColor);
    procedure SetCaretColor(AValue: TColor);
    procedure SetHighlightUserWordCount(AValue: Integer);
    procedure SetOnMultiCaretBeforeCommand(AValue: TSynMultiCaretBeforeCommand);
    procedure SetShowTopInfo(AValue: boolean);
    procedure SetTopInfoMarkup(AValue: TSynSelectedColor);
    procedure DoHighlightChanged(Sender: TSynEditStrings; {%H-}AIndex, {%H-}ACount : Integer);
    procedure SrcSynCaretChanged(Sender: TObject);
    function  GetHighlighter: TSynCustomFoldHighlighter;
  protected
    procedure DoOnStatusChange(Changes: TSynStatusChanges); override;
    function CreateGutter(AOwner : TSynEditBase; ASide: TSynGutterSide;
                          ATextDrawer: TheTextDrawer): TSynGutter; override;
    procedure SetHighlighter(const Value: TSynCustomHighlighter); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function TextIndexToViewPos(aTextIndex : Integer) : Integer;
    property IDEGutterMarks: TIDESynGutterMarks read GetIDEGutterMarks;
    property TopView;
    property TextBuffer;
    property ViewedTextBuffer;
    property TemplateEdit: TSynPluginTemplateEdit read FTemplateEdit;
    property SyncroEdit: TSynPluginSyncroEdit read FSyncroEdit;
    property MultiCaret: TSynPluginMultiCaret read FMultiCaret;
    //////
    property TopInfoMarkup: TSynSelectedColor read FTopInfoMarkup write SetTopInfoMarkup;
    property ShowTopInfo: boolean read FShowTopInfo write SetShowTopInfo;
    {$IFDEF WinIME}
    procedure CreateMinimumIme;
    procedure CreateFullIme;
    {$ENDIF}
    property HighlightUserWordCount: Integer read GetHighlightUserWordCount write SetHighlightUserWordCount;
    property HighlightUserWords[AIndex: Integer]: TSourceSynEditMarkupHighlightAllMulti read GetHighlightUserWords;
    property MarkupMgr;
    function  IsIfdefMarkupActive: Boolean;
    procedure InvalidateAllIfdefNodes;
    procedure SetIfdefNodeState(ALinePos, AstartPos: Integer; AState: TSynMarkupIfdefNodeState);
    property  OnIfdefNodeStateRequest: TSynMarkupIfdefStateRequest read FOnIfdefNodeStateRequest write FOnIfdefNodeStateRequest;
    property  MarkupIfDef: TSourceSynEditMarkupIfDef read FMarkupIfDef;
    property  MarkupIdentComplWindow: TSynMarkupIdentComplWindow read FMarkupIdentComplWindow;
    property  IsInMultiCaretMainExecution: Boolean read GetIsInMultiCaretMainExecution;
    property  IsInMultiCaretRepeatExecution: Boolean read GetIsInMultiCaretRepeatExecution;
    property  OnMultiCaretBeforeCommand: TSynMultiCaretBeforeCommand read GetOnMultiCaretBeforeCommand write SetOnMultiCaretBeforeCommand;
    property CaretStamp: Int64 read FCaretStamp;
    property CaretColor: TColor read FCaretColor write SetCaretColor;
  end;

  TIDESynHighlighterPasRangeList = class(TSynHighlighterPasRangeList)
  protected
    FInterfaceLine, FImplementationLine,
    FInitializationLine, FFinalizationLine: Integer;
  end;

  { TIDESynPasSyn }

  TIDESynPasSyn = class(TSynPasSyn)
  private
    function GetFinalizationLine: Integer;
    function GetImplementationLine: Integer;
    function GetInitializationLine: Integer;
    function GetInterfaceLine: Integer;
  protected
    function CreateRangeList({%H-}ALines: TSynEditStringsBase): TSynHighlighterRangeList; override;
    function StartCodeFoldBlock(ABlockType: Pointer = nil;
      IncreaseLevel: Boolean = true; ForceDisabled: Boolean = False
      ): TSynCustomCodeFoldBlock; override;
  public
    procedure SetLine({$IFDEF FPC}const {$ENDIF}NewValue: string;
      LineNumber: Integer); override;
    property InterfaceLine: Integer read GetInterfaceLine;
    property ImplementationLine: Integer read GetImplementationLine;
    property InitializationLine: Integer read GetInitializationLine;
    property FinalizationLine: Integer read GetFinalizationLine;
  end;

  { TIDESynFreePasSyn }

  TIDESynFreePasSyn = class(TIDESynPasSyn)
  public
    constructor Create(AOwner: TComponent); override;
    procedure ResetRange; override;
  end;

  { TIDESynGutterLOvProviderPascal }

  TIDESynGutterLOvProviderPascal = class(TSynGutterLineOverviewProvider)
  private
    FColor2: TColor;
    FInterfaceLine, FImplementationLine,
    FInitializationLine, FFinalizationLine: Integer;
    FPixInterfaceLine, FPixImplementationLine,
    FPixInitializationLine, FPixFinalizationLine: Integer;
    FPixEndInterfaceLine, FPixEndImplementationLine,
    FPixEndInitializationLine, FPixEndFinalizationLine: Integer;
    FSingleLine: Boolean;
    FRGBColor2: TColorRef;
    procedure SetColor2(const AValue: TColor);
    procedure SetSingleLine(const AValue: Boolean);
  protected
    procedure BufferChanged(Sender: TObject);
    procedure HighlightChanged(Sender: TSynEditStrings; {%H-}AIndex, {%H-}ACount : Integer);
    procedure ReCalc; override;

    procedure Paint(Canvas: TCanvas; AClip: TRect; TopOffset: integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;
  published
    property SingleLine: Boolean read FSingleLine write SetSingleLine;
    property Color2: TColor read FColor2 write SetColor2;
  end;

  { TIDESynGutterLOvProviderIDEMarks }

  TIDESynGutterLOvProviderIDEMarks = class(TSynGutterLOvProviderBookmarks)
  // Bookmarks and breakpoints
  private
    FBreakColor: TColor;
    FBreakDisabledColor: TColor;
    FExecLineColor: TColor;
    FRGBBreakColor: TColorRef;
    FRGBBreakDisabledColor: TColor;
    FRGBExecLineColor: TColor;
    procedure SetBreakColor(const AValue: TColor);
    procedure SetBreakDisabledColor(AValue: TColor);
    procedure SetExecLineColor(AValue: TColor);
  protected
    procedure AdjustColorForMark(AMark: TSynEditMark; var AColor: TColor; var APriority: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property BreakColor: TColor read FBreakColor write SetBreakColor;
    property BreakDisabledColor: TColor read FBreakDisabledColor write SetBreakDisabledColor;
    property ExecLineColor: TColor read FExecLineColor write SetExecLineColor;
  end;

  { TIDESynGutter }

  TIDESynGutter = class(TSynGutter)
  protected
    procedure CreateDefaultGutterParts; override;
  public
  {$IFDEF WithSynDebugGutter}
  DebugGutter: TIDESynGutterDebugHL;
  {$ENDIF}
  end;

  { TIDESynDebugMarkInfo }

  TIDESynDebugMarkInfo = class(TSynManagedStorageMem)
  private
    FRefCount: Integer;
    function GetSrcLineToMarkLine(SrcIndex: Integer): Integer;
    procedure SetSrcLineToMarkLine(SrcIndex: Integer; const AValue: Integer);
  public
    constructor Create;
    procedure IncRefCount;
    procedure DecRefCount;
    // Index is the Current line-index (0 based) in editor (including source modification)
    // Result is the original Line-pos (1 based) as known by the debugger
    property SrcLineToMarkLine[SrcIndex: Integer]: Integer
             read GetSrcLineToMarkLine write SetSrcLineToMarkLine; default;
    property RefCount: Integer read FRefCount;
  end;

  { TIDESynGutterMarks }

  TIDESynGutterMarks = class(TSynGutterMarks)
  private
    FDebugMarkInfo: TIDESynDebugMarkInfo;
    FMarkInfoTextBuffer: TSynEditStrings;
  protected
    procedure CheckTextBuffer;       // Todo: Add a notification, when TextBuffer Changes
    Procedure PaintLine(aScreenLine: Integer; Canvas : TCanvas; AClip : TRect); override;
    function PreferedWidthAtCurrentPPI: Integer; override;

    function GetImgListRes(const ACanvas: TCanvas;
      const AImages: TCustomImageList): TScaledImageListResolution; override;
  public
    destructor Destroy; override;
    procedure BeginSetDebugMarks;
    procedure EndSetDebugMarks;
    procedure SetDebugMarks(AFirstLinePos, ALastLinePos: Integer);
    procedure ClearDebugMarks;
    function HasDebugMarks: Boolean;
    function DebugLineToSourceLine(aLinePos: Integer): Integer;
    function SourceLineToDebugLine(aLinePos: Integer; AdjustOnError: Boolean = False): Integer;
  end;

  { TIDESynGutterCodeFolding }

  TIDESynGutterCodeFolding = class(TSynGutterCodeFolding)
  protected
    procedure UnFoldIfdef(AInclDisabled, AInclEnabled: Boolean);
    procedure FoldIfdef(AInclTemp: Boolean);

    procedure PopClickedUnfoldAll(Sender: TObject);
    procedure PopClickedUnfoldComment(Sender: TObject);
    procedure PopClickedFoldComment(Sender: TObject);
    procedure PopClickedHideComment(Sender: TObject);
    procedure PopClickedFoldIfdef(Sender: TObject);
    procedure PopClickedFoldIfdefNoMixed(Sender: TObject);
    procedure PopClickedUnfoldIfdefActive(Sender: TObject);
    procedure PopClickedUnfolDIfdefAll(Sender: TObject);
    procedure PopClickedUnfoldIfdefInactiv(Sender: TObject);
    procedure CreatePopUpMenuEntries(var APopUp: TPopupMenu; ALine: Integer); override;
  end;

  {$IFDEF WithSynDebugGutter}
  { TIDESynGutterDebugHL }

  TIDESynGutterDebugHL = class(TSynGutterPartBase)
    procedure PopContentClicked(Sender: TObject);
    procedure PopSizeClicked(Sender: TObject);
  private
    FTheLinesView: TSynEditStrings;
    FPopUp: TPopupMenu;
    FContent: Integer;
  protected
    function  PreferedWidth: Integer; override;
    function MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
               HandleActionProc: TSynEditMouseActionHandler): Boolean; override;
    procedure PaintFoldLvl(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
    procedure PaintCharWidths(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Paint(Canvas: TCanvas; AClip: TRect; FirstLine, LastLine: integer);
      override;
    property TheLinesView:  TSynEditStrings       read FTheLinesView  write FTheLinesView;
  end;
  {$ENDIF}

implementation

uses SourceMarks;

{ TSynMarkupIdentComplWindow }

constructor TSynMarkupIdentComplWindow.Create;
begin
  inherited Create;

  FBackgroundSelectedColor := clNone;
  FBorderColor := clNone;
  FHighlightColor := clNone;
  FTextColor := clNone;
  FTextSelectedColor := clNone;
  FWindowColor := clNone;
end;

{ TSourceSynSearchTermDict }

function TSourceSynSearchTermDict.GetTerms: TSourceSynSearchTermList;
begin
  Result := TSourceSynSearchTermList(inherited Terms);
end;

function TSourceSynSearchTermDict.AddSearchTerm(ATerm: String): Integer;
var
  Itm: TSynSearchTerm;
begin
  Itm := Terms.Add;
  Itm.SearchTerm := ATerm;
  Result := Itm.Index;
end;

constructor TSourceSynSearchTermDict.Create(ATermListClass: TSynSearchTermListClass);
begin
  inherited Create(ATermListClass);
  FModifiedTerms := TSynSearchTermList.Create;
  FAddedByKeyWords := TSynSearchTermList.Create;
end;

destructor TSourceSynSearchTermDict.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FModifiedTerms);
  FreeAndNil(FAddedByKeyWords);
end;

procedure TSourceSynSearchTermDict.AddTermByKey(ATerm: String; ACaseSensitive: Boolean;
  ABounds: TSynSearchTermOptsBounds);
var
  i, j, PresetIdx: Integer;
begin
  // check for pre-defined, compare text only
  PresetIdx := Terms.IndexOfSearchTerm(ATerm, False);
  if PresetIdx >= FFirstLocal then
    PresetIdx := -1;

  // Disable or remove weaker terms
  i := Terms.FindSimilarMatchFor(ATerm, ACaseSensitive, ABounds, True, 0, -1, True, True);
  while i >= 0 do begin
    if i >= FFirstLocal then begin
      j := FAddedByKeyWords.IndexOfSearchTerm(Terms[i]);
      Terms.Delete(i);
      if j >= 0 then
        FAddedByKeyWords.Delete(j);
    end
    else begin
      Terms[i].Enabled := False;
      j := FModifiedTerms.IndexOfSearchTerm(Terms[i]);
      if j < 0 then
        FModifiedTerms.Add.Assign(Terms[i])
      else
        FModifiedTerms[j].Assign(Terms[i]);
    end;
    i := Terms.FindSimilarMatchFor(ATerm, ACaseSensitive, ABounds, True, 0, -1, True, True);
  end;

  if PresetIdx >= 0 then begin
    while PresetIdx >= 0 do begin
      Terms[PresetIdx].Enabled := True;
      j := FModifiedTerms.IndexOfSearchTerm(Terms[PresetIdx]);
      if j < 0 then
        FModifiedTerms.Add.Assign(Terms[PresetIdx])
      else
        FModifiedTerms[j].Assign(Terms[PresetIdx]);
      PresetIdx := Terms.IndexOfSearchTerm(ATerm, False, PresetIdx+1);
      if PresetIdx >= FFirstLocal then
        PresetIdx := -1;
    end;
  end
  else begin
    // Could be adding selection that is not at bounds, but forcing bounds
    if Terms.FindMatchFor(ATerm, ACaseSensitive, ABounds) >= FFirstLocal then
      exit;
    i := AddSearchTerm(ATerm);
    Terms[i].MatchCase := ACaseSensitive;
    Terms[i].MatchWordBounds := ABounds;
    FAddedByKeyWords.Add.Assign(Terms[i]);
  end;
end;

procedure TSourceSynSearchTermDict.RemoveTermByKey(RemoveIdx: Integer);
var
  i: Integer;
begin
  if RemoveIdx >= FFirstLocal then begin
    i := FAddedByKeyWords.IndexOfSearchTerm(Terms[RemoveIdx]);
    Assert(i >= 0, 'FAddedByKeyWords.IndexOfSearchTerm(Terms[RemoveIdx])');
    FAddedByKeyWords.Delete(i);
    Terms.Delete(RemoveIdx);
  end
  else begin
    Terms[RemoveIdx].Enabled := False;
    i := FModifiedTerms.IndexOfSearchTerm(Terms[RemoveIdx]);
    if i < 0 then
      FModifiedTerms.Add.Assign(Terms[RemoveIdx])
    else
      FModifiedTerms[i].Assign(Terms[RemoveIdx]);
  end;
end;

procedure TSourceSynSearchTermDict.RestoreLocalChanges;
var
  i, j, k: Integer;
begin
  FFirstLocal := Terms.Count;
  IncChangeNotifyLock;
  try

    for i := FModifiedTerms.Count - 1 downto 0 do begin
      j := Terms.IndexOfSearchTerm(FModifiedTerms[i]);
      if (j < 0) or (Terms[j].Enabled = FModifiedTerms[i].Enabled) then
        FModifiedTerms.Delete(i)
      else
        Terms[j].Enabled := FModifiedTerms[i].Enabled;
    end;

    for i := 0 to FAddedByKeyWords.Count - 1 do begin
      // disable global (there may be new globals)
      j := Terms.FindSimilarMatchFor(FAddedByKeyWords[i], 0, -1, True, True);
      while j >= 0 do begin
        Assert(j < FFirstLocal, 'DISABLE preset in RESTORE j < FFirstLocal');
        if j < FFirstLocal then begin  // should always be true
  DebugLn(['DISABLE preset in RESTORE ',j]);
          Terms[j].Enabled := False;
          k := FModifiedTerms.IndexOfSearchTerm(Terms[j]);
          if k < 0 then
            FModifiedTerms.Add.Assign(Terms[j])
          else
            FModifiedTerms[k].Assign(Terms[j]);
        end;
        j := Terms.FindSimilarMatchFor(FAddedByKeyWords[i], 0, -1, True, True);
      end;

      Terms.Add.Assign(FAddedByKeyWords[i]);
    end;

  finally
    DecChangeNotifyLock;
  end;
end;

{ TSourceSynSearchTermList }

function TSourceSynSearchTermList.FindMatchFor(ATerm: String; ACasesSensitive: Boolean;
  ABoundaries: TSynSearchTermOptsBounds; AStartAtIndex: Integer;
  AIgnoreIndex: Integer): Integer;
var
  c: Integer;
  Entry: TSynSearchTerm;
begin
  Result := AStartAtIndex - 1;
  c := Count - 1;
  while Result < c do begin
    inc(Result);
    if Result = AIgnoreIndex then
      continue;

    Entry := Items[Result];
    if (ATerm = Entry.SearchTerm) and
       (ACasesSensitive = Entry.MatchCase) and
       (ABoundaries = Entry.MatchWordBounds)
    then
      exit;
  end;
   Result := -1;
end;

function TSourceSynSearchTermList.FindSimilarMatchFor(ATerm: String; ACasesSensitive: Boolean;
  ABoundaries: TSynSearchTermOptsBounds; AEnabled: Boolean; AStartAtIndex: Integer;
  AIgnoreIndex: Integer; AnOnlyWeakerOrEqual: Boolean; AnSkipDisabled: Boolean): Integer;
var
  c: Integer;
  Entry: TSynSearchTerm;
  WeakerByEnabled, WeakerByCase, WeakerByBounds: (wParam,  wEntry, wEqual);
begin
  Result := AStartAtIndex - 1;
  c := Count - 1;
  while Result < c do begin
    inc(Result);
    if Result = AIgnoreIndex then
      continue;

    Entry := Items[Result];
    (* if one has soBoundsAtStart, and the other has soBoundsAtEnd then they
        match 2 different sets, which may overlap
       In all other cases, one will match a subset of the other
    *)
    if [ABoundaries, Entry.MatchWordBounds] = [soBoundsAtStart, soBoundsAtEnd] then
      Continue; // Match different sets
    if AnSkipDisabled and not Entry.Enabled then
      Continue;

    WeakerByEnabled := wEqual;
    if (not Entry.Enabled) and AEnabled then WeakerByEnabled := wEntry;
    if Entry.Enabled and (not AEnabled) then WeakerByEnabled := wParam;

    if AnOnlyWeakerOrEqual and (WeakerByEnabled = wParam) then  // Entry can not be weaker
      continue;

    if (ATerm <> Entry.SearchTerm) and
       ( (ACasesSensitive and Entry.MatchCase) or
         (CompareText(ATerm, Entry.SearchTerm) <> 0)
       )
    then
      continue;

    // which one is weakerByCase?
    WeakerByCase := wEqual;
    if (ACasesSensitive) and (not Entry.MatchCase) then
      WeakerByCase := wParam  // param matches a sub-set of entry
    else
    if (not ACasesSensitive) and (Entry.MatchCase) then
      WeakerByCase := wEntry;  // Entry matches a sub-set of param

    if AnOnlyWeakerOrEqual and (WeakerByCase = wParam) then  // Entry can not be weaker
      continue;

    WeakerByBounds := wEqual;
    case ABoundaries of
      soNoBounds: begin
          if Entry.MatchWordBounds <> soNoBounds then
            WeakerByBounds := wEntry; // Entry matches less
        end;
      soBoundsAtStart, soBoundsAtEnd: begin // Combination of one at Start, other at End has already been filtered
          if Entry.MatchWordBounds = soNoBounds then
            WeakerByBounds := wParam
          else
          if Entry.MatchWordBounds = soBothBounds then
            WeakerByBounds := wEntry;
        end;
      soBothBounds: begin
          if Entry.MatchWordBounds <> soBothBounds then
            WeakerByBounds := wParam;
        end;
    end;

    if AnOnlyWeakerOrEqual and (WeakerByBounds = wParam) then  // Entry can not be weaker
      continue;

    if ( ([WeakerByEnabled, WeakerByBounds, WeakerByCase] - [wEqual] = [wEntry]) or
         ([WeakerByEnabled, WeakerByBounds, WeakerByCase] - [wEqual] = [wParam]) or
         ([WeakerByEnabled, WeakerByBounds, WeakerByCase] = [wEqual])
       )
    then
      exit;

  end;
  Result := -1;
end;

function TSourceSynSearchTermList.FindSimilarMatchFor(ATerm: TSynSearchTerm;
  AStartAtIndex: Integer; AIgnoreIndex: Integer; AnOnlyWeakerOrEqual: Boolean;
  AnSkipDisabled: Boolean): Integer;
begin
  Result := FindSimilarMatchFor(ATerm.SearchTerm, ATerm.MatchCase, ATerm.MatchWordBounds,
    ATerm.Enabled, AStartAtIndex, AIgnoreIndex, AnOnlyWeakerOrEqual, AnSkipDisabled);
end;

procedure TSourceSynSearchTermList.ClearSimilarMatches;
var
  i, j: Integer;
begin
  i := 0;
  while (i < Count) do begin
    j := FindSimilarMatchFor(Items[i].SearchTerm,
      Items[i].MatchCase, Items[i].MatchWordBounds, Items[i].Enabled,
      0, i, True);
    if (j >= 0) then begin
      Delete(j);
      if j < i then // May have more than one weaker duplicate
        dec(i);
    end
    else
      inc(i);
  end;
end;

{ TSourceSynEditMarkupHighlightAllMulti }

procedure TSourceSynEditMarkupHighlightAllMulti.ProcessSynCommand(Sender: TObject;
  AfterProcessing: boolean; var Handled: boolean; var Command: TSynEditorCommand;
  var AChar: TUTF8Char; Data: pointer; HandlerData: pointer);
var
  syn: TIDESynEditor;
  TermDict: TSourceSynSearchTermDict;

  function FindTermAtCaret: Integer;
  var
    i, y, x, x1, x2: Integer;
    s: string;
    b1, b2: Boolean;
    t: TSynSearchTerm;
  begin
    Result := -1;
    y := syn.CaretY;
    i := Matches.IndexOfFirstMatchForLine(y);
    if i < 0 then exit;
    x := syn.LogicalCaretXY.x;
    while (i < Matches.Count) and (Matches[i].StartPoint.y <= y) do begin
      if ((Matches[i].StartPoint.y < y) or (Matches[i].StartPoint.x <= x)) and
         ((Matches[i].EndPoint.y > y) or (Matches[i].EndPoint.x >= x))
      then
        break;
      inc(i);
    end;
    if (i >= Matches.Count) or (Matches[i].StartPoint.y > y) or (Matches[i].StartPoint.x > x) then
      exit;

    x1 := Matches[i].StartPoint.x;
    x2 := Matches[i].EndPoint.x;
    //if Matches[i].StartPoint.y < y then x1 := 1; // only one liners allowed
    s := syn.ViewedTextBuffer[y-1];
    b1 := (x1 = 1) or (s[x1-1] in WordBreakChars);
    b2 := (x2 > length(s)) or (s[x2] in WordBreakChars);
    s := copy(s, x1, x2-x1);

    Result := 0;
    while Result < Terms.Count do begin
      t := Terms[Result];
      if t.Enabled and
         ( (t.SearchTerm = s) or
           ( (not t.MatchCase) and (CompareText(t.SearchTerm,s)=0) ) ) and
         ( (t.MatchWordBounds = soNoBounds) or
           ( (t.MatchWordBounds = soBoundsAtStart) and b1 ) or
           ( (t.MatchWordBounds = soBoundsAtEnd) and b2 ) or
           ( (t.MatchWordBounds = soBothBounds) and b1 and b2 )
         )
      then
        exit;
      inc(Result);
    end;

    assert(false, 'TSourceSynEditMarkupHighlightAllMulti match not found');
    Result := -1; // Should never reach
  end;

  procedure AddTermByKey;
  var
    NewTerm, LineTxt: String;
    B1, B2: Boolean;
    NewBounds: TSynSearchTermOptsBounds;
  begin
    NewTerm := '';
    B1 := False;
    B2 := False;
    if syn.SelAvail and (syn.BlockBegin.y = syn.BlockEnd.y) then begin
      NewTerm := syn.SelText;
      LineTxt := syn.Lines[syn.CaretY-1];
      B1 := (KeyAddTermBounds in [soBoundsAtStart, soBothBounds]) and
            ( (KeyAddSelectBoundMaxLen < 1) or (length(NewTerm) <= KeyAddSelectBoundMaxLen) ) and
            ( (not KeyAddSelectSmart) or
              ( (Syn.BlockBegin.X <= 1) or (LineTxt[Syn.BlockBegin.X-1] in WordBreakChars) )
            );
      B2 := (KeyAddTermBounds in [soBoundsAtEnd, soBothBounds]) and
            ( (KeyAddSelectBoundMaxLen < 1) or (length(NewTerm) <= KeyAddSelectBoundMaxLen) ) and
            ( (not KeyAddSelectSmart) or
              ( (Syn.BlockEnd.X > length(LineTxt)) or (LineTxt[Syn.BlockEnd.X] in WordBreakChars) )
            );
    end
    else
    if not syn.SelAvail then begin
      NewTerm := syn.GetWordAtRowCol(syn.LogicalCaretXY);
      if NewTerm <> '' then begin
        B1 := (KeyAddTermBounds in [soBoundsAtStart, soBothBounds]) and
              ( (KeyAddWordBoundMaxLen < 1) or (length(NewTerm) <= KeyAddWordBoundMaxLen) );
        B2 := (KeyAddTermBounds in [soBoundsAtEnd, soBothBounds]) and
              ( (KeyAddWordBoundMaxLen < 1) or (length(NewTerm) <= KeyAddWordBoundMaxLen) );
      end;
    end;

    if B1 and B2 then NewBounds := soBothBounds
    else if B1   then NewBounds := soBoundsAtStart
    else if B2   then NewBounds := soBoundsAtEnd
    else              NewBounds := soNoBounds;

    TermDict.AddTermByKey(NewTerm, FKeyAddCase, NewBounds);
  end;

var
  i: Integer;
begin
  if Handled then
    exit;
  syn := TIDESynEditor(SynEdit);
  TermDict := (Terms as TSourceSynSearchTermDict);
  TermDict.IncChangeNotifyLock;
  try

    if Command = FAddTermCmd then begin
      AddTermByKey;
      Handled := True;
    end;

    if Command = FRemoveTermCmd then begin
      i := FindTermAtCaret;
      if i >= 0 then
        TermDict.RemoveTermByKey(i);
      Handled := True;
    end;

    if Command = FToggleTermCmd then begin
      i := FindTermAtCaret;
      if i >= 0 then
        TermDict.RemoveTermByKey(i)
      else
        AddTermByKey;
      Handled := True;
    end;

  finally
    TermDict.DecChangeNotifyLock;
  end;
end;

function TSourceSynEditMarkupHighlightAllMulti.CreateTermsList: TSynSearchTermDict;
begin
  Result := TSourceSynSearchTermDict.Create(TSourceSynSearchTermList);
end;

constructor TSourceSynEditMarkupHighlightAllMulti.Create(ASynEdit: TSynEditBase);
begin
  inherited Create(ASynEdit);
  TCustomSynEdit(SynEdit).RegisterCommandHandler(@ProcessSynCommand, nil, [hcfInit]);
end;

destructor TSourceSynEditMarkupHighlightAllMulti.Destroy;
begin
  inherited Destroy;
  TCustomSynEdit(SynEdit).UnregisterCommandHandler(@ProcessSynCommand);
end;

procedure TSourceSynEditMarkupHighlightAllMulti.RestoreLocalChanges;
begin
  (Terms as TSourceSynSearchTermDict).RestoreLocalChanges;
end;

{$IFDEF WithSynDebugGutter}
{ TIDESynGutterDebugHL }

procedure TIDESynGutterDebugHL.PopContentClicked(Sender: TObject);
begin
  FContent := TMenuItem(Sender).Tag;
  SynEdit.Invalidate;
end;

procedure TIDESynGutterDebugHL.PopSizeClicked(Sender: TObject);
begin
  Width := TMenuItem(Sender).Tag;
end;

function TIDESynGutterDebugHL.PreferedWidth: Integer;
begin
  Result := 15; // Gutter.TextDrawer.CharWidth * 15;
end;

function TIDESynGutterDebugHL.MaybeHandleMouseAction(var AnInfo: TSynEditMouseActionInfo;
  HandleActionProc: TSynEditMouseActionHandler): Boolean;
begin
  Result := False;
  if (AnInfo.Button <> mbXRight) then exit;
  Result := True;
  if (AnInfo.Dir = cdUp) then begin
    FPopUp.PopUp;
  end;
end;

procedure TIDESynGutterDebugHL.PaintFoldLvl(Canvas: TCanvas; AClip: TRect; FirstLine,
  LastLine: integer);
var
  TextDrawer: TheTextDrawer;
  c, i, iLine, LineHeight: Integer;
  rcLine: TRect;
  dc: HDC;
  s: String;
  RngLst: TSynHighlighterRangeList;
  r: TSynPasSynRange;
begin
  if TCustomSynEdit(SynEdit).Highlighter = nil then exit;
  if not(TCustomSynEdit(SynEdit).Highlighter is TSynPasSyn)  then exit;
  TCustomSynEdit(SynEdit).Highlighter.CurrentLines := TheLinesView;
  TextDrawer := Gutter.TextDrawer;
  dc := Canvas.Handle;
  //TSynHighlighterPasRangeList
  RngLst := TSynHighlighterRangeList(TheLinesView.Ranges[TCustomSynEdit(SynEdit).Highlighter]);

  // Clear all
  TextDrawer.BeginDrawing(dc);
  try
    TextDrawer.SetBackColor(Gutter.Color);
    TextDrawer.SetForeColor(TCustomSynEdit(SynEdit).Font.Color);
    TextDrawer.SetFrameColor(clNone);
     with AClip do
       TextDrawer.ExtTextOut(Left, Top, ETO_OPAQUE, AClip, nil, 0);

    rcLine := AClip;
    rcLine.Bottom := AClip.Top;
    LineHeight := TCustomSynEdit(SynEdit).LineHeight;
    c := TCustomSynEdit(SynEdit).Lines.Count;
    for i := FirstLine to LastLine do
    begin
      iLine := FoldView.DisplayNumber[i];
      if (iLine < 0) or (iLine >= c) then break;
      // next line rect
      rcLine.Top := rcLine.Bottom;
      rcLine.Bottom := rcLine.Bottom + LineHeight;

      if i > 0 then begin
        r := TSynPasSynRange(RngLst.Range[iLine-1]);
        s:= format('%2d %2d %2d  %2d %2d %2d ',
                   [r.PasFoldEndLevel, r.PasFoldMinLevel, r.PasFoldFixLevel,
                    r.CodeFoldStackSize, r.MinimumCodeFoldBlockLevel, r.LastLineCodeFoldLevelFix
                   ]
                  );
      end
      else
        s:= '';

      TextDrawer.ExtTextOut(rcLine.Left, rcLine.Top, ETO_OPAQUE or ETO_CLIPPED, rcLine,
        PChar(Pointer(S)),Length(S));
    end;

  finally
    TextDrawer.EndDrawing;
  end;
end;

procedure TIDESynGutterDebugHL.PaintCharWidths(Canvas: TCanvas; AClip: TRect; FirstLine,
  LastLine: integer);
var
  TextDrawer: TheTextDrawer;
  c, i, iLine, LineHeight: Integer;
  rcLine: TRect;
  dc: HDC;
  s, s2: String;
  CW: TPhysicalCharWidths;
  j: Integer;
begin
  TextDrawer := Gutter.TextDrawer;
  dc := Canvas.Handle;
  TextDrawer.BeginDrawing(dc);
  try
    TextDrawer.SetBackColor(Gutter.Color);
    TextDrawer.SetForeColor(TCustomSynEdit(SynEdit).Font.Color);
    TextDrawer.SetFrameColor(clNone);
     with AClip do
       TextDrawer.ExtTextOut(Left, Top, ETO_OPAQUE, AClip, nil, 0);

    rcLine := AClip;
    rcLine.Bottom := AClip.Top;
    LineHeight := TCustomSynEdit(SynEdit).LineHeight;
    c := TCustomSynEdit(SynEdit).Lines.Count;
    for i := FirstLine to LastLine do
    begin
      iLine := FoldView.DisplayNumber[i];
      if (iLine < 0) or (iLine >= c) then break;
      // next line rect
      rcLine.Top := rcLine.Bottom;
      rcLine.Bottom := rcLine.Bottom + LineHeight;

      if i >= 0 then begin
        CW := FTheLinesView.GetPhysicalCharWidths(iLine-1);
        s2 := FTheLinesView.Strings[iLine-1];
        s := '';
        for j := 0 to length(CW) - 1 do begin
          case FContent of
            1: s := s + IntToStr(CW[j]) + ',';
            2: s := s + IntToHex(ord(s2[j+1]),2) + ',';
            3: s := s + IntToHex(ord(s2[j+1]),2) + '(' + IntToStr(CW[j]) + '),';
          end;
          if (j+1 < length(s2)) and (s2[j+2] in [#$00..#$7f,#$C0..#$FF]) then
            s := s + ' ';
        end;
      end
      else
        s:= '';

      TextDrawer.ExtTextOut(rcLine.Left, rcLine.Top, ETO_OPAQUE or ETO_CLIPPED, rcLine,
        PChar(Pointer(S)),Length(S));
    end;

  finally
    TextDrawer.EndDrawing;
  end;
end;

constructor TIDESynGutterDebugHL.Create(AOwner: TComponent);
var
  Item: TMenuItem;
begin
  inherited Create(AOwner);
  FPopUp := TPopupMenu.Create(Self);
  AutoSize := False;
  Width := PreferedWidth;
  FContent := 0;

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopSizeClicked;
  Item.Caption := 'Size 15';
  Item.Tag := 15;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopSizeClicked;
  Item.Caption := 'Size 100';
  Item.Tag := 100;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopSizeClicked;
  Item.Caption := 'Size 250';
  Item.Tag := 240;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopSizeClicked;
  Item.Caption := 'Size 500';
  Item.Tag := 500;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.Caption := '-';
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopContentClicked;
  Item.Caption := 'Content: Fold Level';
  Item.Tag := 0;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopContentClicked;
  Item.Caption := 'Content: CharWidths';
  Item.Tag := 1;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopContentClicked;
  Item.Caption := 'Content: Hex';
  Item.Tag := 2;
  FPopUp.Items.Add(Item);

  Item := TMenuItem.Create(FPopUp);
  Item.OnClick := @PopContentClicked;
  Item.Caption := 'Content: CharWidths + hex';
  Item.Tag := 3;
  FPopUp.Items.Add(Item);


end;

procedure TIDESynGutterDebugHL.Paint(Canvas: TCanvas; AClip: TRect; FirstLine,
  LastLine: integer);
begin
  case FContent of
    0: PaintFoldLvl(Canvas, AClip, FirstLine, LastLine);
    1,2,3: PaintCharWidths(Canvas, AClip, FirstLine, LastLine);
  end;
end;
{$ENDIF}

{ TSourceLazSynTopInfoView }

function TSourceLazSynTopInfoView.GetLineMap(Index: Integer): Integer;
begin
  Result := FLineMap[Index];
end;

procedure TSourceLazSynTopInfoView.SetLineMap(Index: Integer; AValue: Integer);
begin
  FLineMap[Index] := AValue;
end;

procedure TSourceLazSynTopInfoView.SetLineMapCount(AValue: integer);
begin
  if FLineMapCount = AValue then Exit;
  FLineMapCount := AValue;
  SetLength(FLineMap, AValue);
end;

procedure TSourceLazSynTopInfoView.SetHighlighterTokensLine(ALine: TLineIdx;
  out ARealLine: TLineIdx; out AStartBytePos, ALineByteLen: Integer);
begin
  CurrentTokenLine := ALine;
  inherited SetHighlighterTokensLine(FLineMap[ALine], ARealLine, AStartBytePos, ALineByteLen);
end;

function TSourceLazSynTopInfoView.GetLinesCount: Integer;
begin
  Result := LineMapCount;
end;

function TSourceLazSynTopInfoView.TextToViewIndex(AIndex: TLineIdx): TLineRange;
var
  i: Integer;
  r: TLineRange;
begin
  Result.Top := -1;
  Result.Bottom := -1;
  r := inherited TextToViewIndex(AIndex);
  for i := 0 to LineMapCount - 1 do begin
    if LineMap[i] = r.Top then Result.Top  := i;
    if LineMap[i] = r.Bottom then Result.Bottom  := i;
  end;
  if Result.Bottom < Result.Top then
    Result.Bottom := Result.Top;
end;

function TSourceLazSynTopInfoView.ViewToTextIndex(AIndex: TLineIdx): TLineIdx;
begin
  Result := inherited ViewToTextIndex(AIndex);
end;

constructor TSourceLazSynTopInfoView.Create;
begin
  LineMapCount := 0;
end;

{ TSourceLazSynSurfaceGutter }

procedure TSourceLazSynSurfaceGutter.DoPaint(ACanvas: TCanvas; AClip: TRect);
begin
  // prevent output
  Gutter.Paint(ACanvas, Self, AClip, 0, -1);
end;

procedure TSourceLazSynSurfaceGutter.SetTextArea(ATextArea: TLazSynTextArea);
begin
  inherited SetTextArea(ATextArea);
  ATextArea.AddTextSizeChangeHandler(@TextSizeChanged);
end;

procedure TSourceLazSynSurfaceGutter.TextSizeChanged(Sender: TObject);
begin
  Gutter.DoAutoSize;
end;

{ TSourceLazSynSurfaceManager }

procedure TSourceLazSynSurfaceManager.SetTopLineCount(AValue: Integer);
begin
  if FTopLineCount = AValue then Exit;
  FTopLineCount := AValue;
  BoundsChanged;
end;

function TSourceLazSynSurfaceManager.GetLeftGutterArea: TLazSynSurfaceWithText;
begin
  Result := FOriginalManager.LeftGutterArea;
end;

function TSourceLazSynSurfaceManager.GetRightGutterArea: TLazSynSurfaceWithText;
begin
  Result := FOriginalManager.RightGutterArea;
end;

function TSourceLazSynSurfaceManager.GetTextArea: TLazSynTextArea;
begin
  Result := FOriginalManager.TextArea;
end;

procedure TSourceLazSynSurfaceManager.SetBackgroundColor(AValue: TColor);
begin
  FOriginalManager.BackgroundColor := AValue;
  FExtraManager.BackgroundColor := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetExtraCharSpacing(AValue: integer);
begin
  FOriginalManager.ExtraCharSpacing := AValue;
  FExtraManager.ExtraCharSpacing := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetExtraLineSpacing(AValue: integer);
begin
  FOriginalManager.ExtraLineSpacing := AValue;
  FExtraManager.ExtraLineSpacing := AValue;
  BoundsChanged;
end;

procedure TSourceLazSynSurfaceManager.SetForegroundColor(AValue: TColor);
begin
  FOriginalManager.ForegroundColor := AValue;
  FExtraManager.ForegroundColor := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetPadding(Side: TLazSynBorderSide; AValue: integer);
begin
  FOriginalManager.Padding[Side] := AValue;
  FExtraManager.Padding[Side] := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetRightEdgeColor(AValue: TColor);
begin
  FOriginalManager.RightEdgeColor := AValue;
  FExtraManager.RightEdgeColor := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetRightEdgeColumn(AValue: integer);
begin
  FOriginalManager.RightEdgeColumn := AValue;
  FExtraManager.RightEdgeColumn := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetRightEdgeVisible(AValue: boolean);
begin
  FOriginalManager.RightEdgeVisible := AValue;
  FExtraManager.RightEdgeVisible := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetVisibleSpecialChars(AValue: TSynVisibleSpecialChars);
begin
  FOriginalManager.VisibleSpecialChars := AValue;
  FExtraManager.VisibleSpecialChars := AValue;
end;

procedure TSourceLazSynSurfaceManager.SetHighlighter(AValue: TSynCustomHighlighter);
begin
  FOriginalManager.Highlighter := AValue;
  FExtraManager.Highlighter := AValue;
end;

procedure TSourceLazSynSurfaceManager.DoPaint(ACanvas: TCanvas; AClip: TRect);
begin
  FOriginalManager.Paint(ACanvas, AClip);
  FExtraManager.Paint(ACanvas, AClip);
end;

procedure TSourceLazSynSurfaceManager.DoDisplayViewChanged;
begin
  FOriginalManager.DisplayView := DisplayView;
end;

procedure TSourceLazSynSurfaceManager.BoundsChanged;
var
  t: Integer;
begin
  FExtraManager.LeftGutterWidth := LeftGutterWidth;
  FExtraManager.RightGutterWidth := RightGutterWidth;
  FOriginalManager.LeftGutterWidth := LeftGutterWidth;
  FOriginalManager.RightGutterWidth := RightGutterWidth;

  t := Min(Top + FTopLineCount * FExtraManager.TextArea.LineHeight,
           Max(Top, Bottom - FOriginalManager.TextArea.LineHeight)
          );
  FExtraManager.SetBounds(Top, Left, t, Right);
  FOriginalManager.SetBounds(t, Left, Bottom, Right);
end;

constructor TSourceLazSynSurfaceManager.Create(AOwner: TWinControl; AnOriginalManager: TLazSynSurfaceManager);
var
  txt: TLazSynTextArea;
  lgutter, rgutter: TLazSynGutterArea;
begin
  inherited Create(AOwner);
  FTopLineCount := 0;
  FOriginalManager := AnOriginalManager;

  txt := TLazSynTextArea.Create(AOwner, FOriginalManager.TextArea.TextDrawer);
  txt.Assign(FOriginalManager.TextArea);
  txt.TopLine := 1;
  txt.LeftChar := 1;

  lgutter:= TSourceLazSynSurfaceGutter.Create(AOwner);
  lgutter.Assign(FOriginalManager.LeftGutterArea);
  lgutter.TextArea := txt;

  rgutter:= TSourceLazSynSurfaceGutter.Create(AOwner);
  rgutter.Assign(FOriginalManager.RightGutterArea);
  rgutter.TextArea := txt;

  FExtraManager := TLazSynSurfaceManager.Create(AOwner);
  FExtraManager.TextArea := txt;
  FExtraManager.LeftGutterArea := lgutter;
  FExtraManager.RightGutterArea := rgutter;
end;

destructor TSourceLazSynSurfaceManager.Destroy;
begin
  inherited Destroy;
  FExtraManager.LeftGutterArea.Free;
  FExtraManager.RightGutterArea.Free;
  FExtraManager.TextArea.Free;
  FExtraManager.Free;
  FOriginalManager.Free;
end;

procedure TSourceLazSynSurfaceManager.InvalidateLines(FirstTextLine, LastTextLine: TLineIdx);
begin
  FOriginalManager.InvalidateLines(FirstTextLine, LastTextLine);
  FExtraManager.InvalidateLines(FirstTextLine, LastTextLine);
end;

procedure TSourceLazSynSurfaceManager.InvalidateTextLines(FirstTextLine, LastTextLine: TLineIdx);
begin
  FOriginalManager.InvalidateTextLines(FirstTextLine, LastTextLine);
  FExtraManager.InvalidateTextLines(FirstTextLine, LastTextLine);
end;

procedure TSourceLazSynSurfaceManager.InvalidateGutterLines(FirstTextLine, LastTextLine: TLineIdx);
begin
  FOriginalManager.InvalidateGutterLines(FirstTextLine, LastTextLine);
  FExtraManager.InvalidateGutterLines(FirstTextLine, LastTextLine);
end;

{ TIDESynEditor }

procedure TIDESynEditor.DoHighlightChanged(Sender: TSynEditStrings; AIndex, ACount: Integer);
begin
  FTopInfoNestList.Clear;
  if FSrcSynCaretChangedNeeded then
    SrcSynCaretChanged(nil);
end;

procedure TIDESynEditor.SrcSynCaretChanged(Sender: TObject);
  function RealTopLine: Integer;
  begin
    Result := TopLine - TSourceLazSynSurfaceManager(FPaintArea).TopLineCount;
  end;
var
  InfCnt, i, t, ListCnt: Integer;
  InfList: array [0..1] of
    record
      LineIndex: Integer;
      FoldType: TPascalCodeFoldBlockType;
    end;
  NodeFoldType: TPascalCodeFoldBlockType;
begin
  if (not FShowTopInfo) or (not HandleAllocated) or (FFoldView.HighLighter = nil) then exit;
  if FSrcSynCaretChangedLock or not(FFoldView.HighLighter is TSynPasSyn) then exit;

  if FFoldView.HighLighter.NeedScan then begin
    FSrcSynCaretChangedNeeded := True;
    exit;
  end;
  FSrcSynCaretChangedNeeded := False;

  FSrcSynCaretChangedLock := True;
  try
    ListCnt := 0;

    if CaretY >= RealTopLine then begin
      FTopInfoNestList.Lines := TextBuffer; // in case it changed
      FTopInfoNestList.Line := CaretY-1;
      FTopInfoNestList := FTopInfoNestList;

      InfCnt := FTopInfoNestList.Count;
      for i := InfCnt-1 downto 0 do begin
        NodeFoldType := TPascalCodeFoldBlockType({%H-}PtrUInt(FTopInfoNestList.NodeFoldType[i]));
        if not(NodeFoldType in
           [cfbtClass, cfbtClassSection, cfbtProcedure])
        then
          continue;

        if (NodeFoldType in [cfbtClassSection]) and (ListCnt = 0) then begin
          InfList[ListCnt].LineIndex := FTopInfoNestList.NodeLine[i];
          InfList[ListCnt].FoldType := NodeFoldType;
          inc(ListCnt);
        end;

        if (NodeFoldType in [cfbtClass]) and (ListCnt < 2) then begin
          InfList[ListCnt].LineIndex := FTopInfoNestList.NodeLine[i];
          InfList[ListCnt].FoldType := NodeFoldType;
          inc(ListCnt);
        end;

        if (NodeFoldType in [cfbtProcedure]) and (ListCnt < 2) then begin
          InfList[ListCnt].LineIndex := FTopInfoNestList.NodeLine[i];
          InfList[ListCnt].FoldType := NodeFoldType;
          inc(ListCnt);
        end;
        if (NodeFoldType in [cfbtProcedure]) and (ListCnt = 2) and
           (InfList[ListCnt-1].FoldType = cfbtProcedure)
        then begin
          InfList[ListCnt-1].LineIndex := FTopInfoNestList.NodeLine[i];
          InfList[ListCnt-1].FoldType := NodeFoldType;
        end;
      end;
    end;

    if TopLine <> FTopInfoLastTopLine then // if Sender = nil;
      ListCnt := Min(ListCnt, Max(0, CaretY - RealTopLine));

    t := TopLine + ListCnt - TSourceLazSynSurfaceManager(FPaintArea).TopLineCount;
    if (CaretY >= TopLine) and (CaretY < t) then
      t := CaretY;

    while ListCnt > 0 do begin
      if InfList[0].LineIndex + 1 >= t-1 then begin
        InfList[0] := InfList[1];
        dec(ListCnt);
        t := TopLine + ListCnt - TSourceLazSynSurfaceManager(FPaintArea).TopLineCount;
        if (CaretY >= TopLine) and (CaretY < t) then
          t := CaretY;
      end
      else
        break;
    end;

    FTopInfoDisplay.LineMapCount := ListCnt;

    if ListCnt <> TSourceLazSynSurfaceManager(FPaintArea).TopLineCount then begin
      TopLine := t;
      TSourceLazSynSurfaceManager(FPaintArea).TopLineCount := ListCnt;
      SizeOrFontChanged(FALSE);
      Invalidate; // TODO: move to PaintArea
    end;

    for i := 0 to ListCnt - 1 do begin
      if FTopInfoDisplay.LineMap[ListCnt-1-i] <> InfList[i].LineIndex then
        TSourceLazSynSurfaceManager(FPaintArea).ExtraManager.InvalidateLines(ListCnt-1-i, ListCnt-1-i);
      FTopInfoDisplay.LineMap[ListCnt-1-i] := InfList[i].LineIndex;
    end;

  finally
    FSrcSynCaretChangedLock := False;
    FTopInfoLastTopLine := TopLine;
  end;
end;

function TIDESynEditor.GetHighlighter: TSynCustomFoldHighlighter;
begin
  if Highlighter is TSynCustomFoldHighlighter then
    Result := TSynCustomFoldHighlighter(Highlighter)
  else
    Result := nil;
end;

procedure TIDESynEditor.DoOnStatusChange(Changes: TSynStatusChanges);
begin
  inherited DoOnStatusChange(Changes);
  if Changes * [scTopLine, scLinesInWindow] <> []then
      SrcSynCaretChanged(nil);
  {$push}{$R-}  // range check off
  if Changes * [scCaretX, scCaretY, scSelection] <> []then
    Inc(FCaretStamp);
  {$pop}
end;

procedure TIDESynEditor.GetTopInfoMarkupForLine(Sender: TObject; Line: integer;
  var Special: boolean; aMarkup: TSynSelectedColor);
begin
  Special := True;
  aMarkup.Assign(FTopInfoMarkup);
end;

procedure TIDESynEditor.SetCaretColor(AValue: TColor);
begin
  if FCaretColor = AValue then Exit;
  FCaretColor := AValue;
  if (AValue = clDefault) or (AValue = clNone) then begin
    FScreenCaretPainterClass{%H-} := TSynEditScreenCaretPainterSystem;
    if ScreenCaret.Painter.ClassType <> TSynEditScreenCaretPainterSystem then begin
      MultiCaret.ActiveMode := mcmNoCarets; // clear all carets, before changing the caret class
      ScreenCaret.ChangePainter(TSynEditScreenCaretPainterSystem);
  end;
  end
  else begin
    FScreenCaretPainterClass{%H-} := TSynEditScreenCaretPainterInternal;
    if ScreenCaret.Painter.ClassType <> TSynEditScreenCaretPainterInternal then begin
      MultiCaret.ActiveMode := mcmNoCarets; // clear all carets, before changing the caret class
      ScreenCaret.ChangePainter(TSynEditScreenCaretPainterInternal);
    end;
    TSynEditScreenCaretPainterInternal(ScreenCaret.Painter).Color := AValue;
  end;
end;

procedure TIDESynEditor.SetHighlightUserWordCount(AValue: Integer);
var
  m: TSourceSynEditMarkupHighlightAllMulti;
begin
  if AValue = FUserWordsList.Count then
    exit;

  while FUserWordsList.Count > AValue do begin
    TSynEditMarkupManager(MarkupMgr).RemoveMarkUp(TSourceSynEditMarkupHighlightAllMulti(FUserWordsList[AValue]));
    TSourceSynEditMarkupHighlightAllMulti(FUserWordsList[AValue]).Free;
    FUserWordsList.Delete(AValue);
  end;

  while AValue > FUserWordsList.Count do begin
    m := TSourceSynEditMarkupHighlightAllMulti.Create(self);
    if PaintLock > 0 then
      m.IncPaintLock;
    if Highlighter <> nil then
      m.WordBreakChars := Highlighter.WordBreakChars + TSynWhiteChars;
    FUserWordsList.Add(m);
    TSynEditMarkupManager(MarkupMgr).AddMarkUp(m);
  end;
end;

procedure TIDESynEditor.SetOnMultiCaretBeforeCommand(AValue: TSynMultiCaretBeforeCommand);
begin
  FMultiCaret.OnBeforeCommand := AValue;
end;

procedure TIDESynEditor.SetShowTopInfo(AValue: boolean);
begin
  if FShowTopInfo = AValue then Exit;
  FShowTopInfo := AValue;
  if FShowTopInfo then begin
    SrcSynCaretChanged(nil)
  end
  else
  if TSourceLazSynSurfaceManager(FPaintArea).TopLineCount <> 0 then begin
    TSourceLazSynSurfaceManager(FPaintArea).TopLineCount := 0;
    Invalidate; // TODO: move to PaintArea
  end;
end;

procedure TIDESynEditor.SetTopInfoMarkup(AValue: TSynSelectedColor);
begin
  if FTopInfoMarkup = AValue then Exit;
  FTopInfoMarkup.Assign(AValue);
end;

function TIDESynEditor.GetIDEGutterMarks: TIDESynGutterMarks;
begin
  Result := TIDESynGutterMarks(Gutter.Parts.ByClass[TIDESynGutterMarks, 0]);
end;

function TIDESynEditor.GetIsInMultiCaretMainExecution: Boolean;
begin
  Result := FMultiCaret.IsInMainExecution;
end;

function TIDESynEditor.GetIsInMultiCaretRepeatExecution: Boolean;
begin
  Result := FMultiCaret.IsInRepeatExecution;
end;

function TIDESynEditor.GetOnMultiCaretBeforeCommand: TSynMultiCaretBeforeCommand;
begin
  Result := FMultiCaret.OnBeforeCommand;
end;

function TIDESynEditor.IsIfdefMarkupActive: Boolean;
begin
  Result := FMarkupIfDef.RealEnabled;
end;

function TIDESynEditor.DoIfDefNodeStateRequest(Sender: TObject; LinePos,
  XStartPos: Integer; CurrentState: TSynMarkupIfdefNodeStateEx): TSynMarkupIfdefNodeState;
begin
  //debugln(['TIDESynEditor.DoIfDefNodeStateRequest x=',XStartPos,' y=',LinePos,' ',DbgSName(Sender)]);
  if FOnIfdefNodeStateRequest <> nil then
    Result := FOnIfdefNodeStateRequest(Self, LinePos, XStartPos, CurrentState)
  else
    Result := idnInvalid;
end;

procedure TIDESynEditor.InvalidateAllIfdefNodes;
begin
  FMarkupIfDef.InvalidateAll;
end;

procedure TIDESynEditor.SetIfdefNodeState(ALinePos, AstartPos: Integer;
  AState: TSynMarkupIfdefNodeState);
begin
  FMarkupIfDef.SetNodeState(ALinePos, AstartPos, AState);
end;

function TIDESynEditor.GetHighlightUserWordCount: Integer;
begin
  Result := FUserWordsList.Count;
end;

function TIDESynEditor.GetHighlightUserWords(AIndex: Integer): TSourceSynEditMarkupHighlightAllMulti;
begin
  Result := TSourceSynEditMarkupHighlightAllMulti(FUserWordsList[AIndex])
end;

function TIDESynEditor.CreateGutter(AOwner: TSynEditBase; ASide: TSynGutterSide;
  ATextDrawer: TheTextDrawer): TSynGutter;
begin
  Result := TIDESynGutter.Create(AOwner, ASide, ATextDrawer);
end;

procedure TIDESynEditor.SetHighlighter(const Value: TSynCustomHighlighter);
var
  i: Integer;
begin
  if Value = Highlighter then begin
    inherited SetHighlighter(Value);
    exit
  end;

  IncPaintLock;
  try
    FMarkupIfDef.Highlighter := nil;

    inherited SetHighlighter(Value);

    //TSynEditMarkupFoldColors(MarkupByClass[TSynEditMarkupFoldColors]).Highlighter := Highlighter; // XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
    if Highlighter is TSynPasSyn then
      FMarkupIfDef.Highlighter := TSynPasSyn(Highlighter)
    else
      FMarkupIfDef.Highlighter := nil;

    if Highlighter is TSynCustomFoldHighlighter then
      FTopInfoNestList.Highlighter := TSynCustomFoldHighlighter(Highlighter)
    else
      FTopInfoNestList.Highlighter := nil;

    if FUserWordsList = nil then
      exit;
    if Highlighter <> nil then
      for i := 0 to FUserWordsList.Count - 1 do
        HighlightUserWords[i].WordBreakChars := Highlighter.WordBreakChars + TSynWhiteChars
    else
      for i := 0 to FUserWordsList.Count - 1 do
        HighlightUserWords[i].ResetWordBreaks;
  finally
    DecPaintLock;
  end;
end;

constructor TIDESynEditor.Create(AOwner: TComponent);
var
  MarkupFoldColors: TSynEditMarkupFoldColors;
begin
  inherited Create(AOwner);
  FFoldView := TSynEditFoldedView(TextViewsManager.SynTextViewByClass[TSynEditFoldedView]);
  FCaretColor := clNone;
  FUserWordsList := TFPList.Create;
  FTemplateEdit:=TSynPluginTemplateEdit.Create(Self);
  FSyncroEdit := TSynPluginSyncroEdit.Create(Self);
  FMultiCaret := TSynPluginMultiCaret.Create(Self);
  FMultiCaret.MouseActions.Clear; // will be added to SynEdit
  FMultiCaret.KeyStrokes.Clear;
  FMultiCaret.SetCaretTypeSize(ctVerticalLine, 2, 1024, -1, 0, [ccsRelativeHeight]);
  FMultiCaret.SetCaretTypeSize(ctBlock, 1024, 1024, 0, 0, [ccsRelativeWidth, ccsRelativeHeight]);
  FMultiCaret.Color := $606060;

  FMarkupForGutterMark := TSynEditMarkupGutterMark.Create(Self, FWordBreaker);
  TSynEditMarkupManager(MarkupMgr).AddMarkUp(FMarkupForGutterMark);

  MarkupFoldColors := TSynEditMarkupFoldColors.Create(Self);
  //MarkupFoldColors.DefaultGroup := 0;
  TSynEditMarkupManager(MarkupMgr).AddMarkUp(MarkupFoldColors);

  FMarkupIfDef := TSourceSynEditMarkupIfDef.Create(Self);
  FMarkupIfDef.FoldView := TSynEditFoldedView(FoldedTextBuffer);
  //FMarkupIfDef.OnNodeStateRequest := @DoIfDefNodeStateRequest;
  TSynEditMarkupManager(MarkupMgr).AddMarkUp(FMarkupIfDef);

  FMarkupIdentComplWindow := TSynMarkupIdentComplWindow.Create;

  FPaintArea := TSourceLazSynSurfaceManager.Create(Self, FPaintArea);
  GetCaretObj.AddChangeHandler(@SrcSynCaretChanged);

  FTopInfoDisplay := TSourceLazSynTopInfoView.Create;
  FTopInfoDisplay.NextView := TextViewsManager.SynTextViewByClass[TSynEditStringTabExpander].DisplayView;
  TSourceLazSynSurfaceManager(FPaintArea).TopLineCount := 0;
//  TSourceLazSynSurfaceManager(FPaintArea).ExtraManager.TextArea.BackgroundColor := clSilver;
  TSourceLazSynSurfaceManager(FPaintArea).ExtraManager.DisplayView := FTopInfoDisplay;

  FTopInfoNestList := TLazSynEditNestedFoldsList.Create(TextBuffer);
  FTopInfoNestList.ResetFilter;
  FTopInfoNestList.FoldGroup := FOLDGROUP_PASCAL;
  FTopInfoNestList.FoldFlags := [sfbIncludeDisabled];
  FTopInfoNestList.IncludeOpeningOnLine := False;
  FTopInfoMarkup := TSynSelectedColor.Create;
  FTopInfoMarkup.Clear;

  ViewedTextBuffer.AddChangeHandler(senrHighlightChanged, @DoHighlightChanged);

  // Markup for top info hint
  FExtraMarkupLine := TSynEditMarkupSpecialLine.Create(Self);
  FExtraMarkupLine.OnSpecialLineMarkup  := @GetTopInfoMarkupForLine;
  FExtraMarkupMgr := TSynEditMarkupManager.Create(Self);
  FExtraMarkupMgr.AddMarkUp(TSynEditMarkup(MarkupMgr));
  FExtraMarkupMgr.AddMarkUp(FExtraMarkupLine);
  FExtraMarkupMgr.Lines := ViewedTextBuffer;
  FExtraMarkupMgr.Caret := GetCaretObj;
  FExtraMarkupMgr.InvalidateLinesMethod := @InvalidateLines;

  TSourceLazSynSurfaceManager(FPaintArea).ExtraManager.TextArea.MarkupManager :=
    FExtraMarkupMgr;
  {$IFDEF WithSynDebugGutter}
  TIDESynGutter(RightGutter).DebugGutter.TheLinesView := ViewedTextBuffer;
  {$ENDIF}
end;

destructor TIDESynEditor.Destroy;
begin
  HighlightUserWordCount := 0;
  Highlighter := nil;
  FreeAndNil(FUserWordsList);
  FExtraMarkupMgr.RemoveMarkUp(TSynEditMarkup(MarkupMgr));
  FreeAndNil(FTopInfoDisplay);
  FreeAndNil(FExtraMarkupMgr);
  FreeAndNil(FTopInfoMarkup);
  FreeAndNil(FTopInfoNestList);
  FreeAndNil(FMarkupIdentComplWindow);
  inherited Destroy;
end;

function TIDESynEditor.TextIndexToViewPos(aTextIndex: Integer): Integer;
begin
  Result := ToPos(TextView.TextToViewIndex(ToIdx(aTextIndex)));
end;

{$IFDEF WinIME}
procedure TIDESynEditor.CreateMinimumIme;
var
  Ime: LazSynIme;
begin
  if ImeHandler is LazSynImeSimple then exit;
  Ime := LazSynImeSimple.Create(Self);
  LazSynImeSimple(Ime).TextDrawer := TextDrawer;
  Ime.InvalidateLinesMethod := @InvalidateLines;
  ImeHandler := Ime;
end;

procedure TIDESynEditor.CreateFullIme;
var
  Ime: LazSynIme;
begin
  if ImeHandler is LazSynImeFull then exit;
  Ime := LazSynImeFull.Create(Self);
  Ime.InvalidateLinesMethod := @InvalidateLines;
  ImeHandler := Ime;
end;

{$ENDIF}

{ TIDESynPasSyn }

function TIDESynPasSyn.GetFinalizationLine: Integer;
begin
  Result := TIDESynHighlighterPasRangeList(CurrentRanges).FFinalizationLine;
end;

function TIDESynPasSyn.GetImplementationLine: Integer;
begin
  Result := TIDESynHighlighterPasRangeList(CurrentRanges).FImplementationLine;
end;

function TIDESynPasSyn.GetInitializationLine: Integer;
begin
  Result := TIDESynHighlighterPasRangeList(CurrentRanges).FInitializationLine;
end;

function TIDESynPasSyn.GetInterfaceLine: Integer;
begin
  Result := TIDESynHighlighterPasRangeList(CurrentRanges).FInterfaceLine;
end;

function TIDESynPasSyn.CreateRangeList(ALines: TSynEditStringsBase): TSynHighlighterRangeList;
begin
  Result := TIDESynHighlighterPasRangeList.Create;
  TIDESynHighlighterPasRangeList(Result).FInterfaceLine := -1;
  TIDESynHighlighterPasRangeList(Result).FImplementationLine := -1;
  TIDESynHighlighterPasRangeList(Result).FInitializationLine := -1;
  TIDESynHighlighterPasRangeList(Result).FFinalizationLine := -1;
end;

function TIDESynPasSyn.StartCodeFoldBlock(ABlockType: Pointer;
  IncreaseLevel: Boolean; ForceDisabled: Boolean): TSynCustomCodeFoldBlock;
begin
  if (ABlockType = Pointer(PtrUInt(cfbtUnitSection))) or
     (ABlockType = Pointer(PtrUInt(cfbtUnitSection)) + {%H-}PtrUInt(CountPascalCodeFoldBlockOffset))
  then begin
    if KeyComp('Interface') then
      TIDESynHighlighterPasRangeList(CurrentRanges).FInterfaceLine := LineIndex  + 1;
    if KeyComp('Implementation') then
      TIDESynHighlighterPasRangeList(CurrentRanges).FImplementationLine := LineIndex  + 1;
    if KeyComp('Initialization') then
      TIDESynHighlighterPasRangeList(CurrentRanges).FInitializationLine := LineIndex  + 1;
    if KeyComp('Finalization') then
      TIDESynHighlighterPasRangeList(CurrentRanges).FFinalizationLine := LineIndex  + 1;
  end;
  Result := inherited;
end;

procedure TIDESynPasSyn.SetLine(const NewValue: string; LineNumber: Integer);
begin
  if assigned(CurrentRanges) then begin
    if TIDESynHighlighterPasRangeList(CurrentRanges).FInterfaceLine = LineNumber + 1 then
      TIDESynHighlighterPasRangeList(CurrentRanges).FInterfaceLine := -1;
    if TIDESynHighlighterPasRangeList(CurrentRanges).FImplementationLine = LineNumber + 1 then
      TIDESynHighlighterPasRangeList(CurrentRanges).FImplementationLine := -1;
    if TIDESynHighlighterPasRangeList(CurrentRanges).FInitializationLine = LineNumber + 1 then
      TIDESynHighlighterPasRangeList(CurrentRanges).FInitializationLine := -1;
    if TIDESynHighlighterPasRangeList(CurrentRanges).FFinalizationLine = LineNumber + 1 then
      TIDESynHighlighterPasRangeList(CurrentRanges).FFinalizationLine := -1;
  end;
  inherited SetLine(NewValue, LineNumber);
end;

{ TIDESynFreePasSyn }

constructor TIDESynFreePasSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  CompilerMode:=pcmObjFPC;
end;

procedure TIDESynFreePasSyn.ResetRange;
begin
  inherited ResetRange;
  CompilerMode:=pcmObjFPC;
end;

{ TIDESynGutterLOvProviderPascal }

procedure TIDESynGutterLOvProviderPascal.SetSingleLine(const AValue: Boolean);
begin
  if FSingleLine = AValue then exit;
  FSingleLine := AValue;
  InvalidatePixelLines(0, Height);
end;

procedure TIDESynGutterLOvProviderPascal.SetColor2(const AValue: TColor);
begin
  if FColor2 = AValue then exit;
  FColor2 := AValue;
  FRGBColor2 := ColorToRGB(AValue);
  DoChange(Self);
end;

procedure TIDESynGutterLOvProviderPascal.BufferChanged(Sender: TObject);
begin
  //LineCountChanged(nil, 0, 0);
  HighlightChanged(nil,-1,-1);
end;

procedure TIDESynGutterLOvProviderPascal.HighlightChanged(Sender: TSynEditStrings; AIndex,
  ACount: Integer);
var
  hl: TIDESynPasSyn;
  procedure Update(var TheVal: Integer; NewVal: Integer);
  begin
    if TheVal = NewVal then exit;
    if FSingleLine then begin
      InvalidatePixelLines(TheVal, TheVal);
      InvalidatePixelLines(NewVal, NewVal);
    end else begin
      InvalidatePixelLines(Min(TheVal, NewVal), Height);
    end;

    TheVal := NewVal;
  end;
var i1,i1e,i2,i2e,i3,i3e,i4,i4e: Integer;
begin
  i1  := FPixInterfaceLine;
  i1e := FPixEndInterfaceLine;
  i2  := FPixImplementationLine;
  i2e := FPixEndImplementationLine;
  i3  := FPixInitializationLine;
  i3e := FPixEndInitializationLine;
  i4  := FPixFinalizationLine;
  i4e := FPixEndFinalizationLine;
  if not(TSynEdit(SynEdit).Highlighter is TIDESynPasSyn) then begin
    FInterfaceLine := -1;
    FImplementationLine := -1;
    FInitializationLine := -1;
    FFinalizationLine := -1;
  end else begin
    hl := TSynEdit(SynEdit).Highlighter as TIDESynPasSyn;
    if hl.CurrentLines = nil then exit;
    FInterfaceLine :=      hl.InterfaceLine;
    FImplementationLine := hl.ImplementationLine;
    FInitializationLine := hl.InitializationLine;
    FFinalizationLine :=   hl.FinalizationLine;
  end;

  ReCalc;

  if (i1 <> FPixInterfaceLine) or (i1e <> FPixEndInterfaceLine) then begin
    InvalidatePixelLines(i1,i1e);
    InvalidatePixelLines(FPixInterfaceLine, FPixEndInterfaceLine);
  end;
  if (i2 <> FPixImplementationLine) or (i2e <> FPixEndImplementationLine) then begin
    InvalidatePixelLines(i2,i2e);
    InvalidatePixelLines(FPixImplementationLine, FPixEndImplementationLine);
  end;
  if (i3 <> FPixInitializationLine) or (i3e <> FPixEndInitializationLine) then begin
    InvalidatePixelLines(i3,i3e);
    InvalidatePixelLines(FPixInitializationLine, FPixEndInitializationLine);
  end;
  if (i4 <> FPixFinalizationLine) or (i4e <> FPixEndFinalizationLine) then begin
    InvalidatePixelLines(i4,i4e);
    InvalidatePixelLines(FPixFinalizationLine, FPixEndFinalizationLine);
  end;
end;

procedure TIDESynGutterLOvProviderPascal.ReCalc;
begin
  FPixInterfaceLine      := TextLineToPixel(FInterfaceLine);
  FPixImplementationLine := TextLineToPixel(FImplementationLine);
  FPixInitializationLine := TextLineToPixel(FInitializationLine);
  FPixFinalizationLine   := TextLineToPixel(FFinalizationLine);

  if SingleLine then begin
    if FPixInterfaceLine < 0 then
      FPixEndInterfaceLine := -1
    else
      FPixEndInterfaceLine      := TextLineToPixelEnd(FInterfaceLine) + 1;

    if FPixImplementationLine < 0 then
      FPixEndImplementationLine := -1
    else
      FPixEndImplementationLine := TextLineToPixelEnd(FImplementationLine) + 1;

    if FPixInitializationLine < 0 then
      FPixEndInitializationLine := -1
    else
      FPixEndInitializationLine := TextLineToPixelEnd(FInitializationLine) + 1;

    if FPixFinalizationLine < 0 then
      FPixEndFinalizationLine := -1
    else
      FPixEndFinalizationLine   := TextLineToPixelEnd(FFinalizationLine) + 1;
  end else begin
    if FPixInterfaceLine < 0 then
      FPixEndInterfaceLine := -1
    else if FPixImplementationLine >= 0 then
      FPixEndInterfaceLine := FPixImplementationLine - 1
    else if FPixInitializationLine >= 0 then
      FPixEndInterfaceLine := FPixInitializationLine - 1
    else if FPixFinalizationLine >= 0 then
      FPixEndInterfaceLine := FPixFinalizationLine - 1
    else
      FPixEndInterfaceLine := Height - 1;

    if FPixImplementationLine < 0 then
      FPixEndImplementationLine := -1
    else if FPixInitializationLine >= 0 then
      FPixEndImplementationLine := FPixInitializationLine - 1
    else if FPixFinalizationLine >= 0 then
      FPixEndImplementationLine := FPixFinalizationLine - 1
    else
      FPixEndImplementationLine := Height - 1;

    if FPixInitializationLine < 0 then
      FPixEndInitializationLine := -1
    else if FPixFinalizationLine >= 0 then
      FPixEndInitializationLine := FPixFinalizationLine - 1
    else
      FPixEndInitializationLine := Height - 1;

    if FPixFinalizationLine < 0 then
      FPixEndFinalizationLine := -1
    else
      FPixEndFinalizationLine := Height - 1;
  end;
end;

procedure TIDESynGutterLOvProviderPascal.Paint(Canvas: TCanvas; AClip: TRect;
  TopOffset: integer);
  procedure DrawArea(AStartLine, AEndLine: Integer; C: TColor);
  var r: TRect;
  begin
    if (C = clNone) and SingleLine then
      c := Color;
    if (C = clNone) then
      exit;

    if (AStartLine + TopOffset > AClip.Bottom) or
       (AEndLine + TopOffset < AClip.Top)
    then
      exit;
    r := AClip;
    r.Top    := Max(r.Top, AStartLine + TopOffset);
    r.Bottom := Min(r.Bottom, AEndLine + 1 + TopOffset);
    Canvas.Brush.Color := C;
    Canvas.FillRect(r);
  end;
var
  C2, C3: TColor;
begin
  if FPixInterfaceLine >= 0 then
    DrawArea(FPixInterfaceLine, FPixEndInterfaceLine, Color);

  if FPixImplementationLine >= 0 then
    DrawArea(FPixImplementationLine, FPixEndImplementationLine, Color2);

  C2 := Color;
  C3 := Color2;
  if FPixImplementationLine < 0 then begin
    C2 := Color2;
    if FPixInitializationLine >= 0 then
      C3 := Color;
  end;

  if FPixInitializationLine >= 0 then
    DrawArea(FPixInitializationLine, FPixEndInitializationLine, C2);

  if FPixFinalizationLine >= 0 then
    DrawArea(FPixFinalizationLine, FPixEndFinalizationLine, C3);
end;

constructor TIDESynGutterLOvProviderPascal.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SingleLine := False;
  Color  := $D4D4D4;
  Color2 := $E8E8E8;
  ViewedTextBuffer.AddChangeHandler(senrHighlightChanged,
    @HighlightChanged);
  ViewedTextBuffer.AddNotifyHandler(senrTextBufferChanged,
    @BufferChanged);
end;

destructor TIDESynGutterLOvProviderPascal.Destroy;
begin
  ViewedTextBuffer.RemoveHanlders(self);
  inherited Destroy;
end;

{ TIDESynGutterLOvProviderIDEMarks }

procedure TIDESynGutterLOvProviderIDEMarks.SetBreakColor(const AValue: TColor);
begin
  if FBreakColor = AValue then exit;
  FBreakColor := AValue;
  FRGBBreakColor := ColorToRGB(AValue);
  DoChange(Self);
end;

procedure TIDESynGutterLOvProviderIDEMarks.SetBreakDisabledColor(AValue: TColor);
begin
  if FBreakDisabledColor = AValue then Exit;
  FBreakDisabledColor := AValue;
  FRGBBreakDisabledColor := ColorToRGB(AValue);
  DoChange(Self);
end;

procedure TIDESynGutterLOvProviderIDEMarks.SetExecLineColor(AValue: TColor);
begin
  if FExecLineColor = AValue then Exit;
  FExecLineColor := AValue;
  FRGBExecLineColor := ColorToRGB(AValue);
  DoChange(Self);
end;

procedure TIDESynGutterLOvProviderIDEMarks.AdjustColorForMark(AMark: TSynEditMark;
  var AColor: TColor; var APriority: Integer);
var
  i: Integer;
  ETMark: TETMark;
begin
  if (AMark is TETMark) then begin
    ETMark:=TETMark(AMark);
    AColor:=ETMark.SourceMarks.MarkStyles[ETMark.Urgency].Color;
  end else begin
    inc(APriority, 1);
    if not AMark.IsBookmark then begin
      //if (AMark.ImageList = SourceEditorMarks.ImgList) then begin
      i := AMark.ImageIndex;
      if (i = SourceEditorMarks.CurrentLineImg) or
         (i = SourceEditorMarks.CurrentLineBreakPointImg) or
         (i = SourceEditorMarks.CurrentLineDisabledBreakPointImg)
      then begin
        dec(APriority, 1);
        AColor := TColor(FRGBExecLineColor);
      end
      else
      if (i = SourceEditorMarks.InactiveBreakPointImg) or
         (i = SourceEditorMarks.InvalidDisabledBreakPointImg) or
         (i = SourceEditorMarks.UnknownDisabledBreakPointImg)
      then begin
        inc(APriority, 2);
        AColor := TColor(FRGBBreakDisabledColor);
      end
      else begin
        AColor := TColor(FRGBBreakColor);
        inc(APriority, 1);
      end;
    end;
  end;
  inherited AdjustColorForMark(AMark, AColor, APriority);
end;

constructor TIDESynGutterLOvProviderIDEMarks.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BreakColor         := $0080C8;
  BreakDisabledColor := $00D000;
  ExecLineColor      := $F000D0;
end;

{ TIDESynGutter }

procedure TIDESynGutter.CreateDefaultGutterParts;
begin
  IncChangeLock;
  try
    if Side = gsLeft then begin
      with TIDESynGutterMarks.Create(Parts) do
        Name := 'SynGutterMarks1';
      with TSynGutterLineNumber.Create(Parts) do
        Name := 'SynGutterLineNumber1';
      with TSynGutterChanges.Create(Parts) do
        Name := 'SynGutterChanges1';
      with TSynGutterSeparator.Create(Parts) do
        Name := 'SynGutterSeparator1';
      with TIDESynGutterCodeFolding.Create(Parts) do
        Name := 'SynGutterCodeFolding1';
    end
    else begin
      {$IFDEF WithSynDebugGutter}
      with TSynGutterSeparator.Create(Parts) do
        Name := 'SynGutterSeparatorR1';
      DebugGutter := TIDESynGutterDebugHL.Create(Parts);
      with DebugGutter do
        Name := 'TIDESynGutterDebugHL';
      {$ENDIF}
      with TSynGutterSeparator.Create(Parts) do
        Name := 'SynGutterSeparatorR2';
      with TSynGutterLineOverview.Create(Parts) do begin
        Name := 'SynGutterLineOverview1';
        with TIDESynGutterLOvProviderIDEMarks.Create(Providers) do
          Priority := 20;
        with TSynGutterLOvProviderModifiedLines.Create(Providers) do
          Priority := 9;
        with TSynGutterLOvProviderCurrentPage.Create(Providers) do
          Priority := 1;
        with TIDESynGutterLOvProviderPascal.Create(Providers) do
          Priority := 0;
      end;
      with TSynGutterSeparator.Create(Parts) do begin
        Name := 'SynGutterSeparatorR3';
        AutoSize := False;
        Width := 1;
        LineWidth := 0;
      end;
    end;
  finally
    DecChangeLock;
  end;
end;

{ TIDESynGutterMarks }

procedure TIDESynGutterMarks.CheckTextBuffer;
begin
  if (FMarkInfoTextBuffer <> nil) and
     (FMarkInfoTextBuffer <> TIDESynEditor(SynEdit).TextBuffer)
  then begin
    FMarkInfoTextBuffer := nil;
    if FDebugMarkInfo <> nil then FDebugMarkInfo.DecRefCount;
    if (FDebugMarkInfo <> nil) and (FDebugMarkInfo.RefCount = 0) then
      FreeAndNil(FDebugMarkInfo);
  end;
end;

procedure TIDESynGutterMarks.PaintLine(aScreenLine: Integer; Canvas: TCanvas; AClip: TRect);
var
  aGutterOffs, TxtIdx: Integer;
  HasAnyMark: Boolean;
  iRange: TLineRange;

  procedure DrawDebugMark(Line: Integer);
  var
    itop : Longint;
    LineHeight: LongInt;
    img: TScaledImageListResolution;
  begin
    if Line < 0 then Exit;
    if Assigned(FBookMarkOpt.BookmarkImages) and
       (DebugMarksImageIndex <= FBookMarkOpt.BookmarkImages.Count) and
       (DebugMarksImageIndex >= 0) then
    begin
      LineHeight := TSynEdit(SynEdit).LineHeight;
      img := GetImgListRes(Canvas, FBookMarkOpt.BookmarkImages);
      iTop := 0;
      if LineHeight > img.Height then
        iTop := (LineHeight - img.Height) div 2;

      img.Draw
        (Canvas, AClip.Left + LeftMarginAtCurrentPPI + aGutterOffs * ColumnWidth,
         AClip.Top + iTop, DebugMarksImageIndex, True);
    end
  end;

begin
  CheckTextBuffer;
  aGutterOffs := 0;
  HasAnyMark := PaintMarks(aScreenLine, Canvas, AClip, aGutterOffs);
  aScreenLine := aScreenLine + ToIdx(GutterArea.TextArea.TopLine);
  TxtIdx:= ViewedTextBuffer.DisplayView.ViewToTextIndexEx(aScreenLine, iRange);
  if aScreenLine <> iRange.Top then
    exit;
  if (TxtIdx < 0) or (TxtIdx >= TSynEdit(SynEdit).Lines.Count) then
    exit;
  if (not HasAnyMark) and (HasDebugMarks) and (TxtIdx < FDebugMarkInfo.Count) and
     (FDebugMarkInfo.SrcLineToMarkLine[TxtIdx] > 0)
  then
    DrawDebugMark(aScreenLine);
end;

function TIDESynGutterMarks.PreferedWidthAtCurrentPPI: Integer;
var
  img: TScaledImageListResolution;
begin
  if Assigned(SourceEditorMarks) and Assigned(SourceEditorMarks.ImgList) then
  begin
    img := GetImgListRes(nil, SourceEditorMarks.ImgList);
    // + 1 => right margin
    Result := img.Width * 2 + LeftMarginAtCurrentPPI + Scale96ToFont(1);
  end else
    Result := inherited PreferedWidthAtCurrentPPI;
end;

destructor TIDESynGutterMarks.Destroy;
begin
  ClearDebugMarks;
  inherited;
end;

procedure TIDESynGutterMarks.BeginSetDebugMarks;
begin
  CheckTextBuffer;

  if FDebugMarkInfo = nil then begin
    FDebugMarkInfo := TIDESynDebugMarkInfo(TIDESynEditor(SynEdit).TextBuffer.Ranges[ClassType]);
    if FDebugMarkInfo = nil then begin
      FDebugMarkInfo := TIDESynDebugMarkInfo.Create;
      // Todo: Add a notification, when TextBuffer Changes
      FMarkInfoTextBuffer := TIDESynEditor(SynEdit).TextBuffer;
      TIDESynEditor(SynEdit).TextBuffer.Ranges[ClassType] := FDebugMarkInfo;
    end
    else
      FDebugMarkInfo.IncRefCount;
  end;
end;

procedure TIDESynGutterMarks.EndSetDebugMarks;
begin
  TSynEdit(SynEdit).InvalidateGutter;
end;

function TIDESynGutterMarks.GetImgListRes(const ACanvas: TCanvas;
  const AImages: TCustomImageList): TScaledImageListResolution;
const
  AllowedHeights: array[0..7] of Integer = (5, 7, 9, 11, 16, 22, 33, 44);
var
  Scale: Double;
  PPI, LineHeight, I, ImageHeight: Integer;
begin
  // image height must be equal to width
  if AImages.Width<>AImages.Height then
    raise Exception.Create('Internal error: AImages.Width<>AImages.Height');

  Scale := 1;
  PPI := 96;
  if SynEdit is TSynEdit then
  begin
    LineHeight := TSynEdit(SynEdit).LineHeight;
    if LineHeight - Max(0, TSynEdit(SynEdit).ExtraLineSpacing) > 11 then
      LineHeight := LineHeight - Max(0, TSynEdit(SynEdit).ExtraLineSpacing);
    if LineHeight > 22 then
      I := LineHeight div 8
    else
      I := 1;
    If LineHeight - I >= 11 then
      LineHeight := LineHeight - I;
    if LineHeight < 11 then begin
      LineHeight := TSynEdit(SynEdit).LineHeight;
      if LineHeight > 11 then
        LineHeight := LineHeight - 1;
    end;
    ImageHeight := AllowedHeights[0];
    for I := High(AllowedHeights) downto Low(AllowedHeights) do
      if AllowedHeights[I] <= LineHeight then
      begin
        ImageHeight := AllowedHeights[I];
        break;
      end;
    // don't set PPI here -> we don't want to scale the image anymore
  end else
  begin
    ImageHeight := AImages.Height;
    if ACanvas is TControlCanvas then
      PPI := TControlCanvas(ACanvas).Control.Font.PixelsPerInch;
  end;

  if ACanvas is TControlCanvas then
    Scale := TControlCanvas(ACanvas).Control.GetCanvasScaleFactor;
  Result := AImages.ResolutionForPPI[ImageHeight, PPI, Scale];
end;

procedure TIDESynGutterMarks.SetDebugMarks(AFirstLinePos, ALastLinePos: Integer);
var
  i: LongInt;
begin
  CheckTextBuffer;

  if ALastLinePos > FDebugMarkInfo.Count then begin
    //debugln(['Request to set debug-mark out of range: max-count=',FDebugMarkInfo.Count,' Marks=',AFirstLinePos,' to=',ALastLinePos]);
    ALastLinePos := FDebugMarkInfo.Count;
  end;
  if AFirstLinePos < 1 then begin
    //debugln(['Request to set debug-mark out of range: max-count=',FDebugMarkInfo.Count,' Marks=',AFirstLinePos,' to=',ALastLinePos]);
    AFirstLinePos := 1;
  end;
  for i := AFirstLinePos - 1 to ALastLinePos - 1 do
    FDebugMarkInfo[i] := i + 1;
end;

procedure TIDESynGutterMarks.ClearDebugMarks;
begin
  CheckTextBuffer;

  if FDebugMarkInfo = nil then exit;
  FDebugMarkInfo.DecRefCount;
  if FDebugMarkInfo.RefCount = 0 then begin
    TIDESynEditor(SynEdit).TextBuffer.Ranges[ClassType] := nil;
    FreeAndNil(FDebugMarkInfo);
  end;
  FDebugMarkInfo := nil;
  FMarkInfoTextBuffer := nil;
  TSynEdit(SynEdit).InvalidateGutter;
end;

function TIDESynGutterMarks.HasDebugMarks: Boolean;
begin
  CheckTextBuffer;
  if FDebugMarkInfo = nil then begin
    FDebugMarkInfo := TIDESynDebugMarkInfo(TIDESynEditor(SynEdit).TextBuffer.Ranges[ClassType]);
    if FDebugMarkInfo <> nil then begin
      FDebugMarkInfo.IncRefCount;
      TSynEdit(SynEdit).InvalidateGutter;
    end;
  end;
  Result := FDebugMarkInfo <> nil;
end;

function TIDESynGutterMarks.DebugLineToSourceLine(aLinePos: Integer): Integer;
var
  i, c: LongInt;
  MaxCnt: Integer;
begin
  CheckTextBuffer;
  if (aLinePos < 1) or (not HasDebugMarks) then exit(aLinePos);
  Result := aLinePos - 1; // 0 based
  MaxCnt := FDebugMarkInfo.Count;
  Result := MinMax(Result, 0, MaxCnt - 1);
  if (FDebugMarkInfo[Result] = 0) or (FDebugMarkInfo[Result] > aLinePos) then begin
    i := Result;
    repeat
      dec(i);
      while (i >= 0) and (FDebugMarkInfo[i] = 0) do dec(i);
      if (i < 0) or (FDebugMarkInfo[i] < aLinePos) then break;
      Result := i;
    until FDebugMarkInfo[Result] = aLinePos;
    if (FDebugMarkInfo[Result] > aLinePos) and // line not found
       (Result > 0) and (FDebugMarkInfo[Result - 1] = 0)
    then
      dec(Result);
  end;
  if (FDebugMarkInfo[Result] = 0) or (FDebugMarkInfo[Result] < aLinePos) then begin
    c := FDebugMarkInfo.Count;
    i := Result;
    repeat
      inc(i);
      while (i < c) and (FDebugMarkInfo[i] = 0) do inc(i);
      if (i >= c) or (FDebugMarkInfo[i] > aLinePos) then break;
      Result := i;
    until FDebugMarkInfo[Result] = aLinePos;
    if (FDebugMarkInfo[Result] < aLinePos) and // line not found
       (Result < c-1) and (FDebugMarkInfo[Result + 1] = 0)
    then
      inc(Result);
  end;
  inc(Result); // 1 based
end;

function TIDESynGutterMarks.SourceLineToDebugLine(aLinePos: Integer;
  AdjustOnError: Boolean): Integer;
begin
  CheckTextBuffer;
  if (aLinePos < 1) or (not HasDebugMarks) or (aLinePos >= FDebugMarkInfo.Count) then
    exit(aLinePos);
  Result := FDebugMarkInfo[aLinePos - 1];
  while (Result = 0) and AdjustOnError and (aLinePos < FDebugMarkInfo.Count-1) do begin
    inc(aLinePos);
    Result := FDebugMarkInfo[aLinePos - 1];
  end;
end;

{ TIDESynDebugMarkInfo }

function TIDESynDebugMarkInfo.GetSrcLineToMarkLine(SrcIndex: Integer): Integer;
begin
  Result := Integer(ItemPointer[SrcIndex]^);
end;

procedure TIDESynDebugMarkInfo.SetSrcLineToMarkLine(SrcIndex: Integer; const AValue: Integer);
begin
  Integer(ItemPointer[SrcIndex]^) := AValue;
end;

constructor TIDESynDebugMarkInfo.Create;
begin
  Inherited;
  ItemSize := SizeOf(Integer);
  FRefCount := 1;
end;

procedure TIDESynDebugMarkInfo.IncRefCount;
begin
  inc(FRefCount);
end;

procedure TIDESynDebugMarkInfo.DecRefCount;
begin
  dec(FRefCount);
end;

{ TIDESynGutterCodeFolding }

procedure TIDESynGutterCodeFolding.PopClickedFoldIfdef(Sender: TObject);
begin
  FoldIfdef(True);
end;

procedure TIDESynGutterCodeFolding.PopClickedFoldIfdefNoMixed(Sender: TObject);
begin
  FoldIfdef(False);
end;

procedure TIDESynGutterCodeFolding.PopClickedUnfoldIfdefActive(Sender: TObject);
begin
  UnFoldIfdef(False, True);
end;

procedure TIDESynGutterCodeFolding.PopClickedUnfolDIfdefAll(Sender: TObject);
begin
  UnFoldIfdef(True, True);
end;

procedure TIDESynGutterCodeFolding.PopClickedUnfoldIfdefInactiv(Sender: TObject);
begin
  UnFoldIfdef(True, False);
end;

procedure TIDESynGutterCodeFolding.UnFoldIfdef(AInclDisabled, AInclEnabled: Boolean);
var
  i, j, k, y1, y2: Integer;
  FldInf: TSynFoldNodeInfo;
  Tree: TSynMarkupHighIfDefLinesTree;
  IfLineNode: TSynMarkupHighIfDefLinesNodeInfo;
  IsDisabled: Boolean;
begin
  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;
  Tree := TIDESynEditor(SynEdit).FMarkupIfDef.IfDefTree;

  if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  for i := y1-1 to y2-1 do begin
    j := FoldView.FoldProvider.FoldOpenCount(i);
    while j > 0 do begin
      dec(j);
      if FoldView.IsFoldedAtTextIndex(i,j) then begin
        FldInf := FoldView.FoldProvider.FoldOpenInfo(i, j);
        if TPascalCodeFoldBlockType({%H-}PtrUInt(FldInf.FoldType)) in [cfbtIfDef]
        then begin
          if AInclDisabled and AInclEnabled then begin
            FoldView.UnFoldAtTextIndex(i, j, 1, False, 1);
          end
          else begin
            IfLineNode := Tree.FindNodeAtPosition(ToPos(i), afmNil);
            k := IfLineNode.EntryCount - 1;
            while (k >= 0) and (IfLineNode.Entry[k].StartColumn <> FldInf.LogXStart) do
              dec(k);
            IsDisabled := (k >= 0) and (IfLineNode.Entry[k].IsDisabled);
            if (AInclDisabled and IsDisabled) or (AInclEnabled and not IsDisabled) then
              FoldView.UnFoldAtTextIndex(i, j, 1, False, 1);
          end;
        end;
      end; //FoldView.IsFoldedAtTextIndex(i,j)
    end;
  end;
end;

procedure TIDESynGutterCodeFolding.FoldIfdef(AInclTemp: Boolean);
var
  i, j, k, y1, y2: Integer;
  FldInf: TSynFoldNodeInfo;
  Tree: TSynMarkupHighIfDefLinesTree;
  IfLineNode: TSynMarkupHighIfDefLinesNodeInfo;
begin
  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;
  Tree := TIDESynEditor(SynEdit).FMarkupIfDef.IfDefTree;
  if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  for i := y1-1 to y2-1 do begin
    j := FoldView.FoldProvider.FoldOpenCount(i);
    while j > 0 do begin
      dec(j);
      FldInf := FoldView.FoldProvider.FoldOpenInfo(i, j);
      if (TPascalCodeFoldBlockType({%H-}PtrUInt(FldInf.FoldType)) in [cfbtIfDef]) and
         (sfaFoldFold in FldInf.FoldAction)
      then begin
        IfLineNode := Tree.FindNodeAtPosition(ToPos(i), afmNil);
        k := IfLineNode.EntryCount - 1;
        while (k >= 0) and (IfLineNode.Entry[k].StartColumn <> FldInf.LogXStart) do
          dec(k);
        if (k >= 0) and (IfLineNode.Entry[k].IsDisabled) and
           ( (not (IfLineNode.Entry[k].IsTemp)) or AInclTemp )
        then
          FoldView.FoldAtTextIndex(i, j, 1, False, 1);
      end;
    end;
  end;
end;

procedure TIDESynGutterCodeFolding.PopClickedUnfoldAll(Sender: TObject);
var
  i, y1, y2: Integer;
begin
  if not TSynEdit(SynEdit).SelAvail then begin
    FoldView.UnfoldAll;
    exit;
  end;
  y1 := TSynEdit(SynEdit).BlockBegin.Y;
  y2 := TSynEdit(SynEdit).BlockEnd.Y;
  if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  for i := y1-1 to y2-1 do
    FoldView.UnFoldAtTextIndex(i);
end;

procedure TIDESynGutterCodeFolding.PopClickedUnfoldComment(Sender: TObject);
var
  i, j, y1, y2: Integer;
  FldInf: TSynFoldNodeInfo;
begin
  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;

  for i := y1-1 to y2-1 do begin
    j := FoldView.FoldProvider.FoldOpenCount(i);
    while j > 0 do begin
      dec(j);
      if FoldView.IsFoldedAtTextIndex(i,j) then begin
        FldInf := FoldView.FoldProvider.FoldOpenInfo(i, j);
        if TPascalCodeFoldBlockType({%H-}PtrUInt(FldInf.FoldType)) in
           [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment]
        then begin
          FoldView.UnFoldAtTextIndex(i, j, 1, False, 0);
          FoldView.UnFoldAtTextIndex(i, j, 1, False, 1);
        end;
      end;
    end;
  end;
end;

procedure TIDESynGutterCodeFolding.PopClickedFoldComment(Sender: TObject);
var
  i, j, y1, y2: Integer;
  FldInf: TSynFoldNodeInfo;
begin
  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;

  for i := y1-1 to y2-1 do begin
    j := FoldView.FoldProvider.FoldOpenCount(i);
    while j > 0 do begin
      dec(j);
      FldInf := FoldView.FoldProvider.FoldOpenInfo(i, j);
      if (TPascalCodeFoldBlockType({%H-}PtrUInt(FldInf.FoldType)) in
          [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment]) and
         (sfaFoldFold in FldInf.FoldAction)
      then begin
        FoldView.FoldAtTextIndex(i, j, 1, False, 1);
      end;
    end;
  end;
end;

procedure TIDESynGutterCodeFolding.PopClickedHideComment(Sender: TObject);
var
  i, j, y1, y2: Integer;
  FldInf: TSynFoldNodeInfo;
begin
  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;

  for i := y1-1 to y2-1 do begin
    j := FoldView.FoldProvider.FoldOpenCount(i);
    while j > 0 do begin
      dec(j);
      FldInf := FoldView.FoldProvider.FoldOpenInfo(i, j);
      if (TPascalCodeFoldBlockType({%H-}PtrUInt(FldInf.FoldType)) in
          [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment]) and
         (sfaFoldHide in FldInf.FoldAction)
      then begin
        FoldView.FoldAtTextIndex(i, j, 1, False, 0);
      end;
    end;
  end;
end;

procedure TIDESynGutterCodeFolding.CreatePopUpMenuEntries(var APopUp: TPopupMenu; ALine: Integer);
var
  i, j, k, y1, y2: Integer;
  HasFolds, HasHideableComments, HasFoldableComments, HasCollapsedComments: Boolean;
  ft: TPascalCodeFoldBlockType;
  Foldable, HideAble: TPascalCodeFoldBlockTypes;
  lc: TSynEditFoldLineCapabilities;
  HasFoldableDisabledIfDef, HasFoldableTempDisabledIfDef,
  HasCollapsedActiveIfDef, HasCollapsedDisabledIfDef: Boolean; // HasCollapsedActiveIfDef includes all NOT disabled
  Tree: TSynMarkupHighIfDefLinesTree;
  IfLineNode: TSynMarkupHighIfDefLinesNodeInfo;
  FProv: TSynEditFoldProvider;
  inf: TSynFoldNodeInfo;
  HasComments, HasIfdef: Boolean;

  procedure CheckFoldConf(Val: TPascalCodeFoldBlockType);
  begin
    if not TSynPasSyn(FoldView.HighLighter).FoldConfig[ord(Val)].Enabled then
      exit;
    if fmFold in TSynPasSyn(FoldView.HighLighter).FoldConfig[ord(Val)].Modes then
      include(Foldable, Val);
    if fmHide in TSynPasSyn(FoldView.HighLighter).FoldConfig[ord(Val)].Modes then
      include(HideAble, Val);
  end;

  function AddPopUpItem(const ACaption: String): TMenuItem;
  begin
    Result := TMenuItem.Create(APopUp);
    Result.Caption := ACaption;
    APopUp.Items.Add(Result);
  end;


begin
  inherited CreatePopUpMenuEntries(APopUp, ALine);

  if not (FoldView.HighLighter is TSynPasSyn) then
    exit;

  Foldable := [];
  HideAble := [];
  CheckFoldConf(cfbtAnsiComment);
  CheckFoldConf(cfbtBorCommand);
  CheckFoldConf(cfbtSlashComment);
  if TIDESynEditor(SynEdit).IsIfdefMarkupActive then
    CheckFoldConf(cfbtIfDef);

  if (Foldable = []) and (HideAble = []) then
    exit;

  HasHideableComments           := False;
  HasFoldableComments           := False;
  HasCollapsedComments          := False;
  HasFoldableDisabledIfDef      := False;
  HasFoldableTempDisabledIfDef  := False;
  HasCollapsedActiveIfDef       := False;
  HasCollapsedDisabledIfDef     := False;

  HasComments := (Foldable*[cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment] <> []) or
                 (HideAble*[cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment] <> []);
  HasIfdef := (Foldable*[cfbtIfDef] <> []);

  if TSynEdit(SynEdit).SelAvail then begin
    y1 := TSynEdit(SynEdit).BlockBegin.Y;
    y2 := TSynEdit(SynEdit).BlockEnd.Y;
    if TSynEdit(SynEdit).BlockEnd.X = 1 then dec(y2);
  end
  else begin
    y1 := 1;
    y2 := TSynEdit(SynEdit).Lines.Count - 1;
  end;


  HasFolds := FoldView.TextToViewIndex(y2) - FoldView.TextToViewIndex(y1) <> y2 - y1;
  //debugln(['*** HasFolds=', HasFolds, ' y1=',y1, ' y2=',y2, ' VP1=',FoldView.TextToViewIndex(y1), ' VP2=',FoldView.TextToViewIndex(y2)]);

  FProv := FoldView.FoldProvider;
  Tree := TIDESynEditor(SynEdit).FMarkupIfDef.IfDefTree;
  IfLineNode.ClearInfo;

  i := ToIdx(y1);
  while i < y2 do begin // lines in selection
    lc := FProv.LineCapabilities[i];
    j := FProv.FoldOpenCount(i);

    while j > 0 do begin // foldnodes on line
      dec(j);
      inf := FProv.FoldOpenInfo(i, j);
      ft := TPascalCodeFoldBlockType({%H-}PtrUInt(inf.FoldType));
      if not ((ft in Foldable) or (ft in HideAble)) then
        continue;

      if ft = cfbtIfDef then begin
        if IfLineNode.StartLine <> ToPos(i) then
          IfLineNode := Tree.FindNodeAtPosition(ToPos(i), afmNil);
        k := IfLineNode.EntryCount - 1; // -1 if no node
        while (k >= 0) and (IfLineNode.Entry[k].StartColumn <> inf.LogXStart) do
          dec(k);
        if FoldView.IsFoldedAtTextIndex(i,j) then begin
          if (k >= 0) and (IfLineNode.Entry[k].IsDisabled) then
            HasCollapsedDisabledIfDef := True
          else
            HasCollapsedActiveIfDef := True;
        end
        else // IFDEF is only Fold-able, not hide-able
        if (k >= 0) and (IfLineNode.Entry[k].IsDisabled) then begin
          if IfLineNode.Entry[k].IsTemp then
            HasFoldableTempDisabledIfDef := True
          else
            HasFoldableDisabledIfDef := True;
        end;

      end
      else begin
        // comment
        if FoldView.IsFoldedAtTextIndex(i,j) then begin
          HasCollapsedComments := True;
        end
        else begin
          if (ft in Foldable) and (cfFoldStart in lc) then
            HasFoldableComments := True;
          if (ft in HideAble) and (cfHideStart in lc) then
            HasHideableComments := True;
        end;
      end;
    end;

    if (not HasComments) or
       ( (HasFoldableComments and HasHideableComments) and
         ((not HasFolds) or (HasCollapsedComments))
       )
    then begin
      // found all comment info
      if (not HasIfdef) or
         ( (HasFoldableDisabledIfDef and HasFoldableTempDisabledIfDef) and
           ((not HasFolds) or (HasCollapsedActiveIfDef and HasCollapsedDisabledIfDef))
         )
      then
        break;
      // only Ifdef needed
      if IfLineNode.HasNode and (IfLineNode.StartLine = ToPos(i)) then
        IfLineNode := IfLineNode.Successor
      else
        IfLineNode := Tree.FindNodeAtPosition(ToPos(i)+1, afmNext);
      if not IfLineNode.HasNode then
        break;
      i := ToIdx(IfLineNode.StartLine);
    end
    else
      inc(i);
  end;

  if (HasFolds) and (APopUp.Items.Count > 0) then
    AddPopUpItem(cLineCaption);
  If HasFolds then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfUnfoldAllInSelection).OnClick := @PopClickedUnfoldAll
    else AddPopUpItem(synfUnfoldAll).OnClick := @PopClickedUnfoldAll;


  if (HasCollapsedComments or HasFoldableComments or HasHideableComments) and
     (APopUp.Items.Count > 0)
  then
    AddPopUpItem(cLineCaption);

  If HasCollapsedComments then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfUnfoldCommentsInSelection).OnClick := @PopClickedUnfoldComment
    else AddPopUpItem(synfUnfoldComments).OnClick := @PopClickedUnfoldComment;
  If HasFoldableComments then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfFoldCommentsInSelection).OnClick := @PopClickedFoldComment
    else AddPopUpItem(synfFoldComments).OnClick := @PopClickedFoldComment;
  If HasHideableComments then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfHideCommentsInSelection).OnClick := @PopClickedHideComment
    else AddPopUpItem(synfHideComments).OnClick := @PopClickedHideComment;


  if (HasFoldableDisabledIfDef or HasCollapsedDisabledIfDef or
      HasCollapsedDisabledIfDef or HasCollapsedActiveIfDef) and
     (APopUp.Items.Count > 0)
  then
    AddPopUpItem(cLineCaption);

  If HasCollapsedActiveIfDef and HasCollapsedDisabledIfDef then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfUnfoldAllIfdefInSelection).OnClick := @PopClickedUnfolDIfdefAll
    else AddPopUpItem(synfUnfoldAllIfdef).OnClick := @PopClickedUnfolDIfdefAll;
  If HasCollapsedActiveIfDef then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfUnfoldActiveIfdefInSelection).OnClick := @PopClickedUnfoldIfdefActive
    else AddPopUpItem(synfUnfoldActiveIfdef).OnClick := @PopClickedUnfoldIfdefActive;
  If HasCollapsedDisabledIfDef then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfUnfoldInactiveIfdefInSelection).OnClick := @PopClickedUnfoldIfdefInactiv
    else AddPopUpItem(synfUnfoldInactiveIfdef).OnClick := @PopClickedUnfoldIfdefInactiv;

  If HasFoldableDisabledIfDef or HasFoldableTempDisabledIfDef then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfFoldInactiveIfdefInSelection).OnClick := @PopClickedFoldIfdef
    else AddPopUpItem(synfFoldInactiveIfdef).OnClick := @PopClickedFoldIfdef;
  If HasFoldableDisabledIfDef and HasFoldableTempDisabledIfDef then
    if TSynEdit(SynEdit).SelAvail
    then AddPopUpItem(synfFoldInactiveIfdefInSelectionExcludeMixedState).OnClick := @PopClickedFoldIfdefNoMixed
    else AddPopUpItem(synfFoldInactiveIfdefExcludeMixedState).OnClick := @PopClickedFoldIfdefNoMixed;
end;

end.


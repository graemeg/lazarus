unit SynBeautifierPascal;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, RegExpr, SynBeautifier, SynHighlighterPas, SynEditPointClasses, SynEditKeyCmds, SynEdit,
  SynEditHighlighterFoldBase, SynEditMiscProcs;

type
  { TSynBeautifierPascal }

  TSynBeautifierPascal = class(TSynBeautifier)
  private
    FIndentMode:           Array [TSynCommentType] of TSynCommentIndentFlags;
    FIndentFirstLineExtra: Array [TSynCommentType] of String;
    FIndentFirstLineMax:   Array [TSynCommentType] of Integer;

    FCommentMode:          Array [TSynCommentType] of TSynCommentContineMode;
    FMatchMode:            Array [TSynCommentType] of TSynCommentMatchMode;
    FMatchLine:            Array [TSynCommentType] of TSynCommentMatchLine;
    FMatch:                Array [TSynCommentType] of String;
    FPrefix:               Array [TSynCommentType] of String;
    FCommentIndent:        Array [TSynCommentType] of TSynBeautifierIndentType;

    FEolMatch:             Array [TSynCommentType] of String;
    FEolMode:              Array [TSynCommentType] of TSynCommentContineMode;
    FEolPostfix:           Array [TSynCommentType] of String;
    FEolSkipLongerLine:  Array [TSynCommentType] of Boolean;

    FExtendSlashCommentMode: TSynCommentExtendMode;

  private
    FPasHighlighter: TSynPasSyn;

    FCaretAtEOL: Boolean;
    FStringBreakAppend: String;
    FStringBreakEnabled: Boolean;
    FStringBreakPrefix: String;
    FWorkLine: Integer; // 1 based
    FWorkFoldType: TSynCommentType;
    FGetLineAfterComment: Boolean;
    FRegExprEngine: TRegExpr;

    FCacheFoldEndLvlIdx,         FCacheFoldEndLvl: Integer;
    FCacheCommentLvlIdx,         FCacheCommentLvl: Integer;
    FCacheFoldTypeForIdx: Integer;
                                 FCacheFoldType: TPascalCodeFoldBlockType;
    FCacheFirstLineForIdx,       FCacheFirstLine: Integer;
    FCacheSlashColumnForIdx,     FCacheSlashColumn: Integer;
    FCacheCommentStartColForIdx, FCacheCommentStartCol: Integer;
    FCacheLastHlTokenForIdx,     FCacheLastHlTokenCol: Integer;
    FCacheLastHlTokenKind:       TtkTokenKind;

    FCacheWorkFoldEndLvl: Integer;
    FCacheWorkCommentLvl: Integer;
    FCacheWorkFoldType: TPascalCodeFoldBlockType;
    FCacheWorkFirstLine: Integer;
    FCacheWorkSlashCol: Integer;
    FCacheWorkCommentStartCol: Integer;

  protected
    function  IsPasHighlighter: Boolean;
    procedure InitCache;
    procedure InitPasHighlighter;
    // Generic Helpers
    function  GetFoldEndLevelForIdx(AIndex: Integer): Integer;
    function  GetFoldCommentLevelForIdx(AIndex: Integer): Integer;
    function  GetFoldTypeAtEndOfLineForIdx(AIndex: Integer): TPascalCodeFoldBlockType;
    function  GetFirstCommentLineForIdx(AIndex: Integer): Integer; // Result is 1 based
    function  GetSlashStartColumnForIdx(AIndex: Integer): Integer;
    function  GetLastHlTokenForIdx(AIndex: Integer; out APos: Integer): TtkTokenKind;
    function  GetCommentStartColForIdx(AIndex: Integer): Integer; // Returns Column (logic) for GetFirstCommentLineForIdx(AIndex)
    // Values based on FWorkLine
    function  GetFoldEndLevel: Integer;
    function  GetFoldCommentLevel: Integer;
    function  GetFoldTypeAtEndOfLine: TPascalCodeFoldBlockType;
    function  GetFirstCommentLine: Integer; // Result is 1 based
    function  GetSlashStartColumn: Integer; // Acts on FWorkLine-1
    function  GetCommentStartCol: Integer;  // Acts on GetFirstCommentLineForIdx(FWorkLine) / Logical Resulc

    function  GetMatchStartColForIdx(AIndex: Integer): Integer; // Res=1-based
    function  GetMatchStartPos(AIndex: Integer = -1; AForceFirst: Boolean = False): TPoint; // Res=1-based / AIndex-1 is only used for sclMatchPrev

  protected
    function GetLine(AnIndex: Integer): String; override;

    procedure DoBeforeCommand(const ACaret: TSynEditCaret;
                              var Command: TSynEditorCommand); override;
    procedure DoAfterCommand(const ACaret: TSynEditCaret;
                             var Command: TSynEditorCommand;
                             StartLinePos, EndLinePos: Integer); override;
    procedure DoNewLineInString(AStringStartY, AStringStartX: Integer;
                                const ACaret: TSynEditCaret;
                                var Command: TSynEditorCommand;
                                StartLinePos, EndLinePos: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Assign(Src: TPersistent); override;
    // Returns a 0-based position (even 0-based physical)
  published
    // *** comments with (* *)

    (* AnsiIndentFirstLineMax:
       * For comments that use any sciAlignOpen...
         if AnsiIndentFirstLineMax is is set (none zero):
           The indent will be limited to this value

       AnsiIndentFirstLineExtra:
         For comments that do NOT start at the BOL, an extra indent is added
         on the 2nd line (except if sciAlignOpen is used (in Flags))
    *)
    property AnsiIndentMode: TSynCommentIndentFlags read FIndentMode[sctAnsi]
                                                   write FIndentMode[sctAnsi];
    property AnsiIndentFirstLineMax:   Integer     read FIndentFirstLineMax[sctAnsi]
                                                   write FIndentFirstLineMax[sctAnsi];
    property AnsiIndentFirstLineExtra: String      read FIndentFirstLineExtra[sctAnsi]
                                                   write FIndentFirstLineExtra[sctAnsi];

    (* match should start with ^, and leading spaces should not be in ()  "^\s?(\*\*?\*?)"
       prefix can refer to $1 and should have spaces to indent after the match "$1 "
    *)
    property AnsiCommentMode: TSynCommentContineMode read FCommentMode[sctAnsi]
                                                     write FCommentMode[sctAnsi];
    property AnsiMatch:       String                 read FMatch[sctAnsi]
                                                     write FMatch[sctAnsi];
    property AnsiPrefix :     String                 read FPrefix[sctAnsi]
                              write FPrefix[sctAnsi];
    property AnsiMatchMode:   TSynCommentMatchMode   read FMatchMode[sctAnsi]
                                                     write FMatchMode[sctAnsi];
    property AnsiMatchLine:   TSynCommentMatchLine   read FMatchLine[sctAnsi]
                                                     write FMatchLine[sctAnsi];
    property AnsiCommentIndent: TSynBeautifierIndentType read FCommentIndent[sctAnsi]
                                                         write FCommentIndent[sctAnsi];

    // Add postfix at EOL
    property AnsiEolMode: TSynCommentContineMode read FEolMode[sctAnsi]
                                                 write FEolMode[sctAnsi];
    property AnsiEolPostfix: String              read FEolPostfix[sctAnsi]
                                                 write FEolPostfix[sctAnsi];
    property AnsiEolMatch:   String              read FEolMatch[sctAnsi]
                                                 write FEolMatch[sctAnsi];
    property AnsiEolSkipLongerLine: Boolean      read FEolSkipLongerLine[sctAnsi]
                                                 write FEolSkipLongerLine[sctAnsi];

    // *** comments with { }

    property BorIndentMode: TSynCommentIndentFlags read FIndentMode[sctBor]
                                                  write FIndentMode[sctBor];
    property BorIndentFirstLineMax:   Integer     read FIndentFirstLineMax[sctBor]
                                                  write FIndentFirstLineMax[sctBor];
    property BorIndentFirstLineExtra: String      read FIndentFirstLineExtra[sctBor]
                                                  write FIndentFirstLineExtra[sctBor];

    property BorCommentMode: TSynCommentContineMode read FCommentMode[sctBor]
                                                    write FCommentMode[sctBor];
    property BorMatch:       String                 read FMatch[sctBor]
                                                    write FMatch[sctBor];
    property BorPrefix :     String                 read FPrefix[sctBor]
                             write FPrefix[sctBor];
    property BorMatchMode:   TSynCommentMatchMode   read FMatchMode[sctBor]
                                                    write FMatchMode[sctBor];
    property BorMatchLine:   TSynCommentMatchLine   read FMatchLine[sctBor]
                                                    write FMatchLine[sctBor];
    property BorCommentIndent: TSynBeautifierIndentType read FCommentIndent[sctBor]
                                                         write FCommentIndent[sctBor];

    property BorEolMode: TSynCommentContineMode read FEolMode[sctBor]
                                                write FEolMode[sctBor];
    property BorEolPostfix : String             read FEolPostfix[sctBor]
                             write FEolPostfix[sctBor];
    property BorEolMatch:    String             read FEolMatch[sctBor]
                                                write FEolMatch[sctBor];
    property BorEolSkipLongerLine: Boolean      read FEolSkipLongerLine[sctBor]
                                                write FEolSkipLongerLine[sctBor];

    // *** comments with //
    // Continue only, if Extended

    property ExtendSlashCommentMode: TSynCommentExtendMode read FExtendSlashCommentMode
                                                           write FExtendSlashCommentMode;

    property SlashIndentMode: TSynCommentIndentFlags read FIndentMode[sctSlash]
                                                    write FIndentMode[sctSlash];
    property SlashIndentFirstLineMax:   Integer     read FIndentFirstLineMax[sctSlash]
                                                    write FIndentFirstLineMax[sctSlash];
    property SlashIndentFirstLineExtra: String      read FIndentFirstLineExtra[sctSlash]
                                                    write FIndentFirstLineExtra[sctSlash];

    property SlashCommentMode: TSynCommentContineMode read FCommentMode[sctSlash]
                                                      write FCommentMode[sctSlash];
    property SlashMatch:     String                   read FMatch[sctSlash]
                                                      write FMatch[sctSlash];
    property SlashPrefix :   String                   read FPrefix[sctSlash]
                             write FPrefix[sctSlash];
    property SlashMatchMode: TSynCommentMatchMode     read FMatchMode[sctSlash]
                                                      write FMatchMode[sctSlash];
    property SlashMatchLine:   TSynCommentMatchLine   read FMatchLine[sctSlash]
                                                      write FMatchLine[sctSlash];
    property SlashCommentIndent: TSynBeautifierIndentType read FCommentIndent[sctSlash]
                                                         write FCommentIndent[sctSlash];

    property SlashEolMode: TSynCommentContineMode read FEolMode[sctSlash]
                                                  write FEolMode[sctSlash];
    property SlashEolPostfix : String             read FEolPostfix[sctSlash]
                               write FEolPostfix[sctSlash];
    property SlashEolMatch:    String             read FEolMatch[sctSlash]
                                                  write FEolMatch[sctSlash];
    property SlashEolSkipLongerLine: Boolean      read FEolSkipLongerLine[sctSlash]
                                                  write FEolSkipLongerLine[sctSlash];
    // String
    property StringBreakEnabled: Boolean read FStringBreakEnabled write FStringBreakEnabled;
    property StringBreakAppend: String read FStringBreakAppend write FStringBreakAppend;
    property StringBreakPrefix: String read FStringBreakPrefix write FStringBreakPrefix;
  end;


implementation

{ TSynBeautifierPascal }

function TSynBeautifierPascal.IsPasHighlighter: Boolean;
begin
  Result := (TSynEdit(CurrentEditor).Highlighter <> nil) and
            (TSynEdit(CurrentEditor).Highlighter is TSynPasSyn);
end;

procedure TSynBeautifierPascal.InitCache;
begin
  FCacheFoldEndLvlIdx         := -1;
  FCacheCommentLvlIdx         := -1;
  FCacheFoldTypeForIdx        := -1;
  FCacheFirstLineForIdx       := -1;
  FCacheSlashColumnForIdx     := -1;
  FCacheCommentStartColForIdx := -1;

  FCacheWorkFoldEndLvl         := -2;
  FCacheWorkCommentLvl         := -2;
  FCacheWorkFoldType           := cfbtIfThen; // dummy for not yet cached
  FCacheWorkFirstLine          := -2;
  FCacheWorkSlashCol           := -2;
  FCacheWorkCommentStartCol := -2;

end;

procedure TSynBeautifierPascal.InitPasHighlighter;
begin
  FPasHighlighter := TSynPasSyn(TSynEdit(CurrentEditor).Highlighter);
  FPasHighlighter.CurrentLines := CurrentLines;
  FPasHighlighter.ScanRanges;
end;

function TSynBeautifierPascal.GetFoldEndLevelForIdx(AIndex: Integer): Integer;
begin
  Result := FCacheFoldEndLvl;
  if AIndex = FCacheFoldEndLvlIdx then
    exit;
  FCacheFoldEndLvlIdx := AIndex;
  FCacheFoldEndLvl := FPasHighlighter.FoldBlockEndLevel(AIndex, FOLDGROUP_PASCAL, [sfbIncludeDisabled]);
  Result := FCacheFoldEndLvl;
end;

function TSynBeautifierPascal.GetFoldCommentLevelForIdx(AIndex: Integer): Integer;
var
  tmp: Pointer;
  Block: TPascalCodeFoldBlockType;
begin
  Result := FCacheCommentLvl;
  if AIndex = FCacheCommentLvlIdx then
    exit;
  FCacheCommentLvlIdx := AIndex;

  FCacheCommentLvl := GetFoldEndLevelForIdx(AIndex) - 1;
  while (FCacheCommentLvl > 0) do begin
    FPasHighlighter.FoldBlockNestedTypes(AIndex , FCacheCommentLvl - 1,
                 tmp, FOLDGROUP_PASCAL, [sfbIncludeDisabled]);
    Block:=TPascalCodeFoldBlockType(PtrUInt(tmp));
    if not (Block in [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment]) then
      break;
    dec(FCacheCommentLvl);
  end;
  inc(FCacheCommentLvl);
  Result := FCacheCommentLvl;
end;

function TSynBeautifierPascal.GetFoldTypeAtEndOfLineForIdx(AIndex: Integer): TPascalCodeFoldBlockType;
var
  EndLevel: Integer;
  tmp: Pointer;
begin
  // TODO cfbtNestedComment
  Result := FCacheFoldType;
  if AIndex = FCacheFoldTypeForIdx then
    exit;

  FCacheFoldTypeForIdx := AIndex;
  EndLevel := GetFoldEndLevelForIdx(AIndex);
  if (EndLevel > 0) then
  begin
    if FPasHighlighter.FoldBlockNestedTypes(AIndex, EndLevel - 1,
       tmp, FOLDGROUP_PASCAL, [sfbIncludeDisabled])
    then
      FCacheFoldType:=TPascalCodeFoldBlockType(PtrUInt(tmp))
    else
      FCacheFoldType := cfbtNone;
  end;

  while (FCacheFoldType = cfbtNestedComment) and (EndLevel > 1) do begin
    dec(EndLevel);
    if FPasHighlighter.FoldBlockNestedTypes(AIndex, EndLevel - 1,
         tmp, FOLDGROUP_PASCAL, [sfbIncludeDisabled])
    then
      FCacheFoldType:=TPascalCodeFoldBlockType(PtrUInt(tmp))
    else
      FCacheFoldType := cfbtNone;
  end;

  Result := FCacheFoldType;
end;

function TSynBeautifierPascal.GetFirstCommentLineForIdx(AIndex: Integer): Integer;
var
  FoldType: TPascalCodeFoldBlockType;
  ANewIndex, EndLvl, CommentLvl: Integer;
begin
  Result := FCacheFirstLine;
  if AIndex = FCacheFirstLineForIdx then
    exit;

  ANewIndex := AIndex;
  FoldType := GetFoldTypeAtEndOfLineForIdx(ANewIndex);
  EndLvl   := GetFoldEndLevelForIdx(ANewIndex);

  //if (EndLvl = 0) or not(FoldType in [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment]) and
  //   (AIndex > 0) and (GetSlashStartColumnForIdx(AIndex - 1) > 0)
  //then begin
  //  dec(ANewIndex);
  //  FoldType := GetFoldTypeAtEndOfLineForIdx(ANewIndex);
  //  EndLvl   := GetFoldEndLevelForIdx(ANewIndex);
  //end;

  if (EndLvl = 0) or not(FoldType in [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment])
  then begin
    Result := ToPos(AIndex) - 1; // 1 based - the line above ANewIndex
    // maybe the line above has a trailing comment
    //if (AIndex <> ANewIndex) and (ANewIndex > 0) and (GetSlashStartColumnForIdx(ANewIndex-1) > 0) then
    //  Result := ToPos(ANewIndex) - 1;
    exit;
  end;

  FCacheFirstLineForIdx := AIndex;
  FCacheFirstLine       := ToPos(ANewIndex) - 1;
  CommentLvl            := GetFoldCommentLevelForIdx(ANewIndex);

  while (FCacheFirstLine > 0) do begin
    if CommentLvl > FPasHighlighter.FoldBlockMinLevel(FCacheFirstLine-1, FOLDGROUP_PASCAL, [sfbIncludeDisabled]) then
      break;
    dec(FCacheFirstLine);
  end;

  if FoldType = cfbtSlashComment then begin
    // maybe the line above has a trailing comment
    if GetSlashStartColumnForIdx(ToIdx(FCacheFirstLine)) > 0 then
      dec(FCacheFirstLine);
  end;

  Result := FCacheFirstLine;
//debugln(['FIRST LINE ', FCacheFirstLine]);
end;

function TSynBeautifierPascal.GetSlashStartColumnForIdx(AIndex: Integer): Integer;
var
  Tk: TtkTokenKind;
begin
  Result := FCacheSlashColumn;
  if AIndex = FCacheSlashColumnForIdx then
    exit;

  FCacheSlashColumnForIdx := AIndex;
  Tk := GetLastHlTokenForIdx(AIndex, FCacheSlashColumn);
  if Tk <> SynHighlighterPas.tkComment then
    FCacheSlashColumn := -1;
  Result := FCacheSlashColumn;
end;

function TSynBeautifierPascal.GetLastHlTokenForIdx(AIndex: Integer; out
  APos: Integer): TtkTokenKind;
begin
  Result := FCacheLastHlTokenKind;
  APos   := FCacheLastHlTokenCol;
  if AIndex = FCacheLastHlTokenForIdx then
    exit;

  FCacheSlashColumnForIdx := AIndex;
  FCacheLastHlTokenKind   := SynHighlighterPas.tkUnknown;
  FCacheLastHlTokenCol    := -1;
  if (CurrentLines[AIndex] <> '') then begin
    FPasHighlighter.StartAtLineIndex(AIndex);
    while not FPasHighlighter.GetEol do begin
      FCacheLastHlTokenKind := TtkTokenKind(FPasHighlighter.GetTokenKind);
      FCacheLastHlTokenCol := FPasHighlighter.GetTokenPos + 1;
      FPasHighlighter.Next;
    end;
  end;
  Result := FCacheLastHlTokenKind;
  APos   := FCacheLastHlTokenCol;
end;

function TSynBeautifierPascal.GetCommentStartColForIdx(AIndex: Integer): Integer;
var
  nl: TLazSynFoldNodeInfoList;
  i: Integer;
  FoldCommentLvl: Integer;
begin
  Result := FCacheCommentStartCol;
  if AIndex = FCacheCommentStartColForIdx then
    exit;
  FCacheCommentStartColForIdx := AIndex;

  if (GetFoldEndLevelForIdx(AIndex) = 0) or
     not(GetFoldTypeAtEndOfLineForIdx(AIndex) in [cfbtAnsiComment, cfbtBorCommand, cfbtSlashComment])
  then begin
    // must be SlashComment
    FCacheCommentStartCol := GetSlashStartColumnForIdx(AIndex - 1);
    //FCacheCommentStartCol := GetSlashStartColumnForIdx(AIndex);
    //if FCacheCommentStartCol > 0 then begin
    //  i := GetSlashStartColumnForIdx(AIndex - 1);
    //  if i > 0 then
    //    FCacheCommentStartCol := i;
    //end;
    Result := FCacheCommentStartCol;
//debugln(['FIRST COL prev-// ', FCacheCommentStartCol]);
    exit;
  end;

  FCacheCommentStartCol := -1;
  FoldCommentLvl := GetFoldCommentLevelForIdx(AIndex);
  nl := FPasHighlighter.FoldNodeInfo[GetFirstCommentLineForIdx(AIndex) - 1];
  nl.AddReference;
  nl.ClearFilter;
  nl.ActionFilter := [sfaOpen];
  nl.GroupFilter  := FOLDGROUP_PASCAL;
  i := nl.Count - 1;
  while i >= 0 do  begin
    if (not (sfaInvalid in nl[i].FoldAction)) and
       (nl[i].NestLvlEnd = FoldCommentLvl)
    then begin
      FCacheCommentStartCol := nl[i].LogXStart + 1;  // Highlighter pos are 0 based
      break;
    end;
    dec(i);
  end;
  nl.ReleaseReference;
//debugln(['FIRST COL ', FCacheCommentStartCol]);

  Result := FCacheCommentStartCol;
end;

function TSynBeautifierPascal.GetFoldEndLevel: Integer;
begin
  Result := FCacheWorkFoldEndLvl;
  if FCacheWorkFoldEndLvl > -2 then
    exit;
  FCacheWorkFoldEndLvl := GetFoldEndLevelForIdx(FWorkLine-1);
  Result := FCacheWorkFoldEndLvl;
end;

function TSynBeautifierPascal.GetFoldCommentLevel: Integer;
begin
  Result := FCacheWorkCommentLvl;
  if FCacheWorkCommentLvl > -2 then
    exit;
  FCacheWorkCommentLvl := GetFoldCommentLevelForIdx(FWorkLine-1);
  Result := FCacheWorkCommentLvl;
end;

function TSynBeautifierPascal.GetFoldTypeAtEndOfLine: TPascalCodeFoldBlockType;
begin
  Result := FCacheWorkFoldType;
  if FCacheWorkFoldType <> cfbtIfThen then
    exit;
  FCacheWorkFoldType := GetFoldTypeAtEndOfLineForIdx(FWorkLine-1);
  Result := FCacheWorkFoldType;
end;

function TSynBeautifierPascal.GetFirstCommentLine: Integer;
begin
  Result := FCacheWorkFirstLine;
  if FCacheWorkFirstLine > -2 then
    exit;
  FCacheWorkFirstLine := GetFirstCommentLineForIdx(FWorkLine-1);
  Result := FCacheWorkFirstLine;
end;

function TSynBeautifierPascal.GetSlashStartColumn: Integer;
begin
  Result := FCacheWorkSlashCol;
  if FCacheWorkSlashCol > -2 then
    exit;
  FCacheWorkSlashCol := GetSlashStartColumnForIdx(FWorkLine-2);
  Result := FCacheWorkSlashCol;
end;

function TSynBeautifierPascal.GetCommentStartCol: Integer;
begin
  Result := FCacheWorkCommentStartCol;
  if FCacheWorkCommentStartCol > -2 then
    exit;
  FCacheWorkCommentStartCol := GetCommentStartColForIdx(FWorkLine-1);
  Result := FCacheWorkCommentStartCol;
end;

function TSynBeautifierPascal.GetMatchStartColForIdx(AIndex: Integer): Integer;
begin
  if ToPos(AIndex) = GetFirstCommentLine then begin
    // Match on FirstLine
    case FMatchMode[FWorkFoldType] of
      scmMatchAfterOpening: begin
          if FWorkFoldType = sctBor
          then Result := GetCommentStartCol + 1
          else Result := GetCommentStartCol + 2;
        end;
      scmMatchOpening:    Result := GetCommentStartCol;
      scmMatchWholeLine:  Result := 1;
      scmMatchAtAsterisk: Result := GetCommentStartCol + 1;
    end;
  end
  else begin
    // Match on prev, not first
    case FMatchMode[FWorkFoldType] of
      scmMatchAfterOpening, scmMatchOpening, scmMatchAtAsterisk:
          Result := 1 + GetIndentForLine(nil, CurrentLines[AIndex], False);
      scmMatchWholeLine:
          Result := 1;
    end;
  end;
end;

function TSynBeautifierPascal.GetMatchStartPos(AIndex: Integer; AForceFirst: Boolean): TPoint;
begin
  if AIndex < 0 then
    AIndex := ToIdx(FWorkLine);

  if AForceFirst then
    Result.Y := GetFirstCommentLine
  else
    case FMatchLine[FWorkFoldType] of
      sclMatchFirst: Result.Y := GetFirstCommentLine;
      sclMatchPrev:  Result.Y := ToPos(AIndex)-1; // FWorkLine - 1
    end;

  Result.X := GetMatchStartColForIdx(ToIdx(Result.Y));
end;


function TSynBeautifierPascal.GetLine(AnIndex: Integer): String;
var
  ReplacedPrefix: String;
  Indent, PreFixPos: Integer;
  r: Boolean;
  p: TPoint;
begin
  if not FGetLineAfterComment then begin
    Result := inherited GetLine(AnIndex);
    exit;
  end;

  // Need to cut of existing Prefix to find indent after prefix

  if AnIndex < GetFirstCommentLine-1 then begin
    Result := '';
//debugln(['GETLINE FROM (< First) ', AnIndex,' ''', CurrentLines[AnIndex], ''' to empty']);
  end;

  // 1) Run the match for this line (match prev, or first)
  //    and see if we can find the replaced prefix in this line
  if AnIndex > GetFirstCommentLine-1 then begin
    p := GetMatchStartPos(AnIndex);
    FRegExprEngine.InputString:= copy(CurrentLines[ToIdx(p.y)], p.x, MaxInt);
    FRegExprEngine.Expression := FMatch[FWorkFoldType];
    if FRegExprEngine.ExecPos(1) then begin
      ReplacedPrefix := FRegExprEngine.Substitute(FPrefix[FWorkFoldType]);
      while (ReplacedPrefix <> '') and (ReplacedPrefix[1] in [#9, ' ']) do
        delete(ReplacedPrefix, 1, 1);
      while (ReplacedPrefix <> '') and (ReplacedPrefix[length(ReplacedPrefix)] in [#9, ' ']) do
        delete(ReplacedPrefix, length(ReplacedPrefix), 1);
      if ReplacedPrefix <> '' then begin
        Result := CurrentLines[AnIndex];
        PreFixPos := pos(ReplacedPrefix, Result);
        if (PreFixPos > 0) and (PreFixPos <= GetMatchStartColForIdx(AnIndex)) then begin
          delete(Result, 1, PreFixPos - 1 + Length(ReplacedPrefix));
//debugln(['GETLINE FROM (1) ', AnIndex,' ''', CurrentLines[AnIndex], ''' to ''', Result, '''']);
          exit;
        end;
      end;
    end;
  end
  else
    p := Point(0,0);

  // 2) See, if the current-1 line can be matched
  r := False;
  Result := CurrentLines[AnIndex];
  Indent := GetMatchStartColForIdx(AnIndex);
  FRegExprEngine.InputString:= copy(CurrentLines[AnIndex], Indent, MaxInt);
  FRegExprEngine.Expression := FMatch[FWorkFoldType];
  r := FRegExprEngine.ExecPos(1);
  if (not r) and (Indent > 1) and
     ((p.y <> GetFirstCommentLine) or (FMatchMode[FWorkFoldType] = scmMatchWholeLine))
  then begin
    // try whole line
// TODO: only if not first, or if setting
    FRegExprEngine.InputString := CurrentLines[AnIndex];
    r := FRegExprEngine.ExecPos(1);
    if r then
      Indent := 1;
  end;
  if (r) then begin
    Indent := Indent + FRegExprEngine.MatchPos[0] - 1 + FRegExprEngine.MatchLen[0];
    Result := CurrentLines[AnIndex];
    if (Indent <= Length(Result)) then
      while (Indent > 1) and (Result[Indent] in [#9, ' ']) do
        dec(Indent);
    inc(Indent);
    if Indent > 0 then begin
      Result := copy(Result, Indent, MaxInt);
//debugln(['GETLINE FROM (2) ', AnIndex,' ''', CurrentLines[AnIndex], ''' to ''', Result, '''']);
      exit;
    end;
  end;

  // 3) maybe try currest replace, if different from 1?

  // Nothing found
  Result := '';
//debugln(['GETLINE FROM (X) ', AnIndex,' ''', CurrentLines[AnIndex], ''' to empty']);
end;

procedure TSynBeautifierPascal.DoBeforeCommand(const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand);
begin
  FCaretAtEOL := ACaret.BytePos > Length(CurrentLines[ToIdx(ACaret.LinePos)]);
  FGetLineAfterComment := False;
  inherited DoBeforeCommand(ACaret, Command);
end;

procedure TSynBeautifierPascal.DoAfterCommand(const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand; StartLinePos, EndLinePos: Integer);

var
  WorkLine, PrevLineShlasCol: Integer;
  ReplacedPrefix: String; // Each run matches only one Type
  MatchResultIntern, MatchedBOLIntern: Array [Boolean] of Boolean;  // Each run matches only one Type

  function CheckMatch(AType: TSynCommentType; AFailOnNoPattern: Boolean = False;
    AForceFirst: Boolean = False): Boolean;
  var
    p: TPoint;
  begin
    if (FMatch[AType] = '') and AFailOnNoPattern then begin
      Result := False;
      exit;
    end;

    if MatchedBOLIntern[AForceFirst] then begin
      Result := MatchResultIntern[AForceFirst];
      exit;
    end;

    p := GetMatchStartPos(-1, AForceFirst);

    FRegExprEngine.InputString:= copy(CurrentLines[ToIdx(p.y)], p.x, MaxInt);
    if (FRegExprEngine.InputString='') then
      exit(false);
    FRegExprEngine.Expression := FMatch[AType];
    if not FRegExprEngine.ExecPos(1) then begin
      ReplacedPrefix := FRegExprEngine.Substitute(FPrefix[AType]);
      MatchedBOLIntern[AForceFirst] := True;
      MatchResultIntern[AForceFirst] := False;
      Result := MatchResultIntern[AForceFirst];
      exit;
    end;

    ReplacedPrefix := FRegExprEngine.Substitute(FPrefix[AType]);
    MatchedBOLIntern[AForceFirst] := True;
    MatchResultIntern[AForceFirst] := True;
    Result := MatchResultIntern[AForceFirst];

  end;

  function IsFoldTypeEnabled(AType: TSynCommentType): Boolean;
  begin
  Result := (  ( (AType <> sctSlash) or
               ( ((not FCaretAtEOL) and (FExtendSlashCommentMode <> sceNever)) or
                 ((FCaretAtEOL)     and not(FExtendSlashCommentMode in [sceNever, sceSplitLine, sceMatchingSplitLine]))
               )
             ) and
             ( (FIndentMode[AType] <> []) or
               (FCommentMode[AType] <> sccNoPrefix) or
               (FEolMode[AType] <> sccNoPrefix)
            ))
  end;

var
  Indent, dummy: Integer;
  s: String;
  FoldTyp: TSynCommentType;
  AnyEnabled: Boolean;
  ExtendSlash, BeSmart, Matching: Boolean;
  PreviousIsFirst, CommentStartsAtBOL, DidAlignOpen: Boolean;

  IndentTypeBackup: TSynBeautifierIndentType;

begin
  if (EndLinePos < 1) or
     ((Command <> ecLineBreak) and (Command <> ecInsertLine)) or
     (not IsPasHighlighter)
  then begin
    inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
    exit;
  end;

  AnyEnabled := False;
  for FoldTyp := low(TSynCommentType) to high(TSynCommentType) do
    AnyEnabled := AnyEnabled or IsFoldTypeEnabled(FoldTyp);
  if (not AnyEnabled) and (not FStringBreakEnabled) then begin
    inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
    exit;
  end;

  InitCache;
  InitPasHighlighter;
  FGetLineAfterComment := False;
  MatchedBOLIntern[True] := False;
  MatchedBOLIntern[False] := False;
  PrevLineShlasCol := -1;
  dummy := 0;

  if (Command = ecLineBreak)
  then WorkLine := ACaret.LinePos
  else WorkLine := ACaret.LinePos + 1;
  FWorkLine := WorkLine;


  // Find Foldtype
  case GetFoldTypeAtEndOfLine of
    cfbtAnsiComment:  FoldTyp := sctAnsi;
    cfbtBorCommand:   FoldTyp := sctBor;
    cfbtSlashComment: FoldTyp := sctSlash;
    else
      begin
        if (CurrentLines[ToIdx(WorkLine)-1] <> '') and
           (FExtendSlashCommentMode <> sceNever) and
           ( (not FCaretAtEOL) or not(FExtendSlashCommentMode in [sceSplitLine, sceMatchingSplitLine]) )
        then begin
          PrevLineShlasCol := GetSlashStartColumn;
          if PrevLineShlasCol > 0 then
            FoldTyp := sctSlash;
        end;
        if PrevLineShlasCol < 0 then begin
          if (CurrentLines[ToIdx(WorkLine)-1] <> '') and
             (GetLastHlTokenForIdx(ToIdx(WorkLine)-1, dummy) = SynHighlighterPas.tkString)
          then
            DoNewLineInString(WorkLine - 1, dummy, ACaret, Command, StartLinePos, EndLinePos)
          else
            inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
          exit;
        end;
      end;
  end;

  if not IsFoldTypeEnabled(FoldTyp) then begin
    inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
    exit;
  end;

  FWorkFoldType := FoldTyp;

  // Check if we need extend
  ExtendSlash := False;
  if (FoldTyp = sctSlash) and (ACaret.OldLineBytePos.x > GetSlashStartColumn+2) then begin
    // Check if extension is needed
    case FExtendSlashCommentMode of
      sceAlways:    ExtendSlash := True;
      sceSplitLine: ExtendSlash := not FCaretAtEOL;
      sceMatching:  ExtendSlash := CheckMatch(FoldTyp);
      sceMatchingSplitLine: ExtendSlash := CheckMatch(FoldTyp) and (not FCaretAtEOL);
    end;

    if not ExtendSlash then begin
      inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
      exit;
    end;
  end;

  // Indent
  Matching := CheckMatch(FoldTyp);
  PreviousIsFirst := (GetFirstCommentLine = WorkLine -1);
  DidAlignOpen := False;
  CommentStartsAtBOL := True;
  if PreviousIsFirst then
    CommentStartsAtBOL := GetCommentStartCol = 1 + GetIndentForLine(nil, CurrentLines[ToIdx(GetFirstCommentLine)], False);


  // Aply indent before prefix
  if Matching or (FCommentMode[FoldTyp] = sccPrefixAlways) or (sciApplyIndentForNoMatch in FIndentMode[FoldTyp])
  then begin
    IndentTypeBackup := IndentType;
    try
      if IndentType = sbitPositionCaret then
        IndentType := sbitSpace;
      if IndentType = sbitConvertToTabOnly then
        IndentType := sbitConvertToTabSpace;

      // Align with open
      if ( (FIndentMode[FoldTyp] * [sciNone, sciAlignOpen] = [sciAlignOpen]) or
           ( (sciAlignOpenOnce in FIndentMode[FoldTyp]) and PreviousIsFirst )
         ) and
         ( (not (sciAlignOpenSkipBOL in FIndentMode[FoldTyp])) or (not CommentStartsAtBOL) )
      then begin
        Indent := CurrentLines.LogicalToPhysicalCol(CurrentLines[ToIdx(GetFirstCommentLine)],
                                                     ToIdx(GetFirstCommentLine),
                                                     GetCommentStartCol-1);
        if FIndentFirstLineMax[FoldTyp] > 0
        then Indent := Min(Indent, FIndentFirstLineMax[FoldTyp]);
        s := GetCharMix(WorkLine, Indent, dummy);
        FLogicalIndentLen := length(s);
        CurrentLines.EditInsert(1, WorkLine, s);
        DidAlignOpen := True;
      end
      else
      // Do not align with open, but check MaxIndent
      if PreviousIsFirst and (FIndentFirstLineMax[FoldTyp] > 0) and
         (FIndentMode[FoldTyp] * [sciNone] = []) then begin
        Indent := GetIndentForLine(nil, CurrentLines[ToIdx(WorkLine-1)], False);
        Indent := Min(Indent, FIndentFirstLineMax[FoldTyp]);
        s := GetCharMix(WorkLine, Indent, dummy);
        FLogicalIndentLen := length(s);
        CurrentLines.EditInsert(1, WorkLine, s);
      end
      else
      if (sciNone in FIndentMode[FoldTyp]) then begin
        // No indent
      end
      else
      begin
        inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
      end;
    finally
      IndentType := IndentTypeBackup;
    end;

    // AnsiIndentFirstLineExtra
    if PreviousIsFirst and (not CommentStartsAtBOL) and (not DidAlignOpen) then begin
      CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine, FIndentFirstLineExtra[FoldTyp]);
      FLogicalIndentLen := FLogicalIndentLen + length(FIndentFirstLineExtra[FoldTyp]);
    end;

  end
  else
    inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);

  Indent := 0; // Extra Indent
  BeSmart := (PreviousIsFirst or (sciAlignOpen in FIndentMode[FoldTyp])) and
             (Matching or ExtendSlash or (sciApplyIndentForNoMatch in FIndentMode[FoldTyp]) or
              (FCommentMode[FoldTyp] = sccPrefixAlways)  );

  // sciAddTokenLen -- Spaces for (* or {
  if BeSmart and
     ( (sciAddTokenLen in FIndentMode[FoldTyp]) and
       ( (not(sciMatchOnlyTokenLen in FIndentMode[FoldTyp])) or CheckMatch(FoldTyp, False, True) ) and
       ( (not(sciAlignOnlyTokenLen in FIndentMode[FoldTyp])) or DidAlignOpen )
     )
  then begin
    case FoldTyp of
      sctAnsi:  if FMatchMode[FoldTyp] = scmMatchAtAsterisk
                then Indent := 1
                else Indent := 2;
      sctBor:   Indent := 1;
      sctSlash: if ExtendSlash
                then Indent := 0 // do the slashes
                else Indent := 2;
    end;
  end;

  // sciAddPastTokenIndent -- Spaces from after (* or { (to go before prefix e.g " {  * foo")
  if BeSmart and
     ( (sciAddPastTokenIndent in FIndentMode[FoldTyp]) and
       ( (not(sciMatchOnlyPastTokenIndent in FIndentMode[FoldTyp])) or CheckMatch(FoldTyp, False, True) ) and
       ( (not(sciAlignOnlyPastTokenIndent in FIndentMode[FoldTyp])) or DidAlignOpen )
     ) and
     (GetCommentStartCol > 0) // foundStartCol
  then begin
    case FoldTyp of
      // ignores scmMatchAtAsterisk
      sctAnsi:  s := copy(CurrentLines[ToIdx(GetFirstCommentLine)], GetCommentStartCol+2, MaxInt);
      sctBor:   s := copy(CurrentLines[ToIdx(GetFirstCommentLine)], GetCommentStartCol+1, MaxInt);
      sctSlash: s := copy(CurrentLines[ToIdx(GetFirstCommentLine)], GetCommentStartCol+2, MaxInt);
    end;
    Indent := Indent + GetIndentForLine(nil, s, False);
  end;
  // Extend //
  if ExtendSlash then begin
    CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine, '//');
    FLogicalIndentLen := FLogicalIndentLen + 2;
  end;
  if (Indent > 0) then begin
    CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine, StringOfChar(' ', Indent ));
    FLogicalIndentLen := FLogicalIndentLen + Indent;
  end;

  // Apply prefix
  if (FCommentMode[FoldTyp] = sccPrefixAlways) or
     ((FCommentMode[FoldTyp] = sccPrefixMatch) and Matching)
  then begin
    CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine, ReplacedPrefix);
    FLogicalIndentLen := FLogicalIndentLen + length(ReplacedPrefix);

    // Post  prefix indent
    FGetLineAfterComment := True;
    try
      GetIndentInfo(WorkLine, s, Indent, GetFirstCommentLine);
      if s <> '' then begin
        CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine, s);
        FLogicalIndentLen := FLogicalIndentLen + length(s); // logical (Indent is phisical)
      end
      else
        FLogicalIndentLen := FLogicalIndentLen + Indent; // maybe position caret
    finally
      FGetLineAfterComment := False;
    end;
  end;


  if (Command = ecLineBreak) then begin
    ACaret.IncForcePastEOL;
    ACaret.BytePos := 1 + FLogicalIndentLen;
    ACaret.DecForcePastEOL;
  end;

end;

procedure TSynBeautifierPascal.DoNewLineInString(AStringStartY, AStringStartX: Integer;
  const ACaret: TSynEditCaret; var Command: TSynEditorCommand; StartLinePos,
  EndLinePos: Integer);
var
  s: String;
  WorkLine: Integer;
  f: Boolean;
begin
  inherited DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
  if not FStringBreakEnabled then
    exit;

  if (Command = ecLineBreak)
  then WorkLine := ACaret.LinePos - 1
  else WorkLine := ACaret.LinePos;

  s := CurrentLines[ToIdx(WorkLine)];
  if (AStringStartX < 1) or (AStringStartX > Length(s)) or (s[AStringStartX] <> '''') then
    exit;
  f := False;
  while AStringStartX <= length(s) do begin
    if (s[AStringStartX] = '''') then f := not f;
    inc(AStringStartX);
  end;
  if not f then exit;

  ACaret.IncForcePastEOL;

  CurrentLines.EditInsert(1 + length(s), WorkLine, '''' + FStringBreakAppend);
  //if Command = ecInsertLine then
  //  ACaret.BytePos := ACaret.BytePos + Length(FStringBreakAppend) + 1;

  CurrentLines.EditInsert(1 + FLogicalIndentLen, WorkLine + 1, FStringBreakPrefix + '''');
  if (Command = ecLineBreak) then
    ACaret.BytePos := ACaret.BytePos + Length(FStringBreakPrefix) + 1;

  ACaret.DecForcePastEOL;
end;

constructor TSynBeautifierPascal.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FRegExprEngine := TRegExpr.Create;
  FRegExprEngine.ModifierI := True;

  FIndentMode[sctAnsi]           := [sciAddTokenLen, sciAddPastTokenIndent];
  FIndentFirstLineExtra[sctAnsi] := '';
  FIndentFirstLineMax[sctAnsi]   := 0;

  FCommentMode[sctAnsi]          := sccPrefixMatch;
  FMatch[sctAnsi]                := '^ ?(\*)';
  FMatchMode[sctAnsi]            := scmMatchAfterOpening;
  FMatchLine[sctAnsi]            := sclMatchPrev;
  FPrefix[sctAnsi]               := '$1';

  FEolMatch[sctAnsi]             := '';
  FEolMode[sctAnsi]              := sccNoPrefix;
  FEolPostfix[sctAnsi]           := '';
  FEolSkipLongerLine[sctAnsi]    := False;


  FIndentMode[sctBor]           := [sciAddTokenLen, sciAddPastTokenIndent];
  FIndentFirstLineExtra[sctBor] := '';
  FIndentFirstLineMax[sctBor]   := 0;

  FCommentMode[sctBor]          := sccPrefixMatch;
  FMatch[sctBor]                := '^ ?(\*)';
  FMatchMode[sctBor]            := scmMatchAfterOpening;
  FMatchLine[sctBor]            := sclMatchPrev;
  FPrefix[sctBor]               := '$1';

  FEolMatch[sctBor]             := '';
  FEolMode[sctBor]              := sccNoPrefix;
  FEolPostfix[sctBor]           := '';
  FEolSkipLongerLine[sctBor]    := False;


  FExtendSlashCommentMode         := sceNever;

  FIndentMode[sctSlash]           := [];
  FIndentFirstLineExtra[sctSlash] := '';
  FIndentFirstLineMax[sctSlash]   := 0;

  FCommentMode[sctSlash]          := sccPrefixMatch;
  FMatch[sctSlash]                := '^ ?(\*)';
  FMatchMode[sctSlash]            := scmMatchAfterOpening;
  FMatchLine[sctSlash]            := sclMatchPrev;
  FPrefix[sctSlash]               := '$1';

  FEolMatch[sctSlash]             := '';
  FEolMode[sctSlash]              := sccNoPrefix;
  FEolPostfix[sctSlash]           := '';
  FEolSkipLongerLine[sctSlash]    := False;

  FStringBreakEnabled := False;
  FStringBreakAppend := ' +';
  FStringBreakPrefix := '';
end;

destructor TSynBeautifierPascal.Destroy;
begin
  inherited Destroy;
  FreeAndNil(FRegExprEngine);
end;

procedure TSynBeautifierPascal.Assign(Src: TPersistent);
var
  i: TSynCommentType;
begin
  inherited Assign(Src);
  if not(Src is TSynBeautifierPascal) then exit;

  FExtendSlashCommentMode := TSynBeautifierPascal(Src).FExtendSlashCommentMode;

  for i := low(TSynCommentType) to high(TSynCommentType) do begin
    FIndentMode[i]           := TSynBeautifierPascal(Src).FIndentMode[i];
    FIndentFirstLineExtra[i] := TSynBeautifierPascal(Src).FIndentFirstLineExtra[i];
    FIndentFirstLineMax[i]   := TSynBeautifierPascal(Src).FIndentFirstLineMax[i];

    FCommentMode[i]          := TSynBeautifierPascal(Src).FCommentMode[i];
    FMatch[i]                := TSynBeautifierPascal(Src).FMatch[i];
    FMatchMode[i]            := TSynBeautifierPascal(Src).FMatchMode[i];
    FMatchLine[i]            := TSynBeautifierPascal(Src).FMatchLine[i];
    FPrefix[i]               := TSynBeautifierPascal(Src).FPrefix[i];

    FEolMatch[i]             := TSynBeautifierPascal(Src).FEolMatch[i];
    FEolMode[i]              := TSynBeautifierPascal(Src).FEolMode[i];
    FEolPostfix[i]           := TSynBeautifierPascal(Src).FEolPostfix[i];
    FEolSkipLongerLine[i]    := TSynBeautifierPascal(Src).FEolSkipLongerLine[i];
  end;

  FStringBreakAppend         := TSynBeautifierPascal(Src).FStringBreakAppend;
  FStringBreakEnabled        := TSynBeautifierPascal(Src).FStringBreakEnabled;
  FStringBreakPrefix         := TSynBeautifierPascal(Src).FStringBreakPrefix;

end;

end.


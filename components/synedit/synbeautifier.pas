{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynHighlighterGeneral.pas, released 2000-04-07.
The Original Code is based on the mwGeneralSyn.pas file from the
mwEdit component suite by Martin Waldenburg and other developers, the Initial
Author of this file is Martin Waldenburg.
Portions written by Martin Waldenburg are copyright 1999 Martin Waldenburg.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id: SynHighlighterGeneral.pas,v 1.3 2000/11/08 22:09:59 mghie Exp $

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net
}
unit SynBeautifier;

{$I synedit.inc}

interface

uses
  Classes, SysUtils, StrUtils,
  LCLProc,
  LazStringUtils,
  SynEditMiscClasses, SynEditMiscProcs, LazSynEditText, SynEditPointClasses,
  SynEditKeyCmds, SynEditTypes;

type

  TSynCustomBeautifier = class;

  // Callback for indent
  TSynBeautifierSetIndentProc =
    procedure(
      (* LinePos:
           1-based, the line that should be changed *)
      LinePos: Integer;
      (* Indent:
           New indent in spaces (Logical = Physical *)
      Indent: Integer;
      (* RelativeToLinePos:
           Indent specifies +/- offset from indent on RTLine (0: for absolute indent) *)
      RelativeToLinePos: Integer = 0;
      (* IndentChars:
           String used to build indent; maybe empty, single char, or string (usually 1 tab or 1 space)
           The String will be repeated and cut as needed, then filled with spaces at the end
         * NOTE: If this is specified the TSynBeautifierIndentType is ignored
      *)
      IndentChars: String = '';
      (* IndentCharsFromLinePos:
           Use tab/space mix from this Line for indent (if specified > 0)
           "IndentChars" will only be used, if the found tab/space mix is to short
         * NOTE: If this is specified the TSynBeautifierIndentType is ignored
      *)
      IndentCharsFromLinePos: Integer = 0
    ) of object;

  // Event triggered if Lines may needs Indend
  TSynBeautifierGetIndentEvent =
    function(
      Sender: TObject;                       // the beautifier
      Editor: TObject;                       // the synedit
      LogCaret, OldLogCaret: TPoint;         // Caret after and before the edit action
      FirstLinePos, LastLinePos: Integer;    // Changed lines. this can include lines outside the range of OldLogCaret to LogCaret
      Reason: TSynEditorCommand;             // what caused the event
      SetIndentProc: TSynBeautifierSetIndentProc
     ): boolean of object;


  { TSynCustomBeautifier }

  TSynCustomBeautifier = class(TComponent)
  private
    FAutoIndent: Boolean;
    FOnGetDesiredIndent: TSynBeautifierGetIndentEvent;
    FCurrentEditor: TSynEditBase; // For callback / applyIndent
    FCurrentLines: TSynEditStrings;
  protected
    procedure DoBeforeCommand(const ACaret: TSynEditCaret;
                              var Command: TSynEditorCommand); virtual; abstract;
    procedure DoAfterCommand(const ACaret: TSynEditCaret;
                             var Command: TSynEditorCommand;
                             StartLinePos, EndLinePos: Integer); virtual; abstract;
    property CurrentEditor: TSynEditBase read FCurrentEditor;
    property CurrentLines: TSynEditStrings read FCurrentLines;
  public
    procedure Assign(Src: TPersistent); override;
    function  GetCopy: TSynCustomBeautifier;
    procedure BeforeCommand(const Editor: TSynEditBase; const Lines: TSynEditStrings;
                            const ACaret: TSynEditCaret; var Command: TSynEditorCommand;
                            InitialCmd: TSynEditorCommand);
    procedure AfterCommand(const Editor: TSynEditBase; const Lines: TSynEditStrings;
                           const ACaret: TSynEditCaret; var Command: TSynEditorCommand;
                           InitialCmd: TSynEditorCommand; StartLinePos, EndLinePos: Integer);
    // GetDesiredIndentForLine: Returns the 1-based Physical x pos
    function GetDesiredIndentForLine
             (Editor: TSynEditBase; const Lines: TSynEditStrings;
              const ACaret: TSynEditCaret): Integer; virtual; abstract;
    function GetDesiredIndentForLine
             (Editor: TSynEditBase; const Lines: TSynEditStrings;
              const ACaret: TSynEditCaret; out ReplaceIndent: Boolean;
              out DesiredIndent: String): Integer; virtual; abstract;
    property OnGetDesiredIndent: TSynBeautifierGetIndentEvent
      read FOnGetDesiredIndent write FOnGetDesiredIndent;
    property AutoIndent: Boolean read FAutoIndent write FAutoIndent;
  end;

  TSynCustomBeautifierClass = class of TSynCustomBeautifier;
  TSynBeautifierIndentType = (
    sbitSpace, sbitCopySpaceTab,
    sbitPositionCaret,
    sbitConvertToTabSpace,   // convert to tabs, fill with spcaces if needed
    sbitConvertToTabOnly     // convert to tabs, even if shorter
  );

  { TSynBeautifier }

  TSynBeautifier = class(TSynCustomBeautifier)
  private
    FIndentType: TSynBeautifierIndentType;
  protected
    FLogicalIndentLen: Integer;

    function GetLine(AnIndex: Integer): String; virtual;
    procedure GetIndentInfo(const LinePos: Integer;
                            out ACharMix: String; out AnIndent: Integer;
                            AStopScanAtLine: Integer = 0);
    // requiring FCurrentEditor, FCurrentLines
    procedure DoBeforeCommand(const ACaret: TSynEditCaret;
                              var Command: TSynEditorCommand); override;
    procedure DoAfterCommand(const ACaret: TSynEditCaret;
                             var Command: TSynEditorCommand;
                             StartLinePos, EndLinePos: Integer); override;
    function GetIndent(const LinePos: Integer; out BasedOnLine: Integer;
                       AStopScanAtLine: Integer = 0): Integer;
    function AdjustCharMix(DesiredIndent: Integer; CharMix, AppendMix: String): String;
    function CreateTabSpaceMix(var DesiredIndent: Integer; OnlyTabs: Boolean): String;
    function GetCharMix(const LinePos: Integer; var Indent: Integer;
                        var IndentCharsFromLinePos: Integer;
                        ModifyIndent: Boolean = False): String;
    procedure ApplyIndent(LinePos: Integer; Indent: Integer;
                          RelativeToLinePos: Integer = 0; IndentChars: String = '';
                          IndentCharsFromLinePos: Integer = 0);
    function UnIndentLine(const ACaret: TSynEditCaret; out CaretNewX: Integer): Boolean;
  public
    procedure Assign(Src: TPersistent); override;
    // Returns a 0-based position (even 0-based physical)
    function GetIndentForLine(Editor: TSynEditBase; const Line: string;
                        Physical: boolean): Integer;
    function GetDesiredIndentForLine
             (Editor: TSynEditBase; const Lines: TSynEditStrings;
              const ACaret: TSynEditCaret): Integer; override;
    function GetDesiredIndentForLine
             (Editor: TSynEditBase; const Lines: TSynEditStrings;
              const ACaret: TSynEditCaret; out ReplaceIndent: Boolean;
              out DesiredIndent: String): Integer; override;
  published
    property IndentType: TSynBeautifierIndentType read FIndentType write FIndentType;
  end;

  TSynCommentContineMode = (
      sccNoPrefix,      // May still do indent, if matched
      sccPrefixAlways,  // If the pattern did not match all will be done, except the indent AFTER the prefix (can not be detected)
      sccPrefixMatch
      //sccPrefixMatchFirst
      //sccPrefixMatchPrev
      //sccPrefixMatchPrevTwo           // last 2 lines match
      //sccPrefixMatchPrevTwoExact      // last 2 lines match and same result for prefix
    );

  TSynCommentMatchLine = (
      sclMatchFirst, // Match the first line of the comment to get substitutes for Prefix ($1)
      sclMatchPrev   // Match the previous line of the comment to get substitutes for Prefix ($1)
      //sclMatchNestedFirst // For nested comments, first line of this nest.
    );

  TSynCommentMatchMode = (
    // Which parts of the first line to match sclMatchFirst or sclMatchPrev (if prev = first)
      scmMatchAfterOpening, // will not include (*,{,//. The ^ will match the first char after
      scmMatchOpening,      // will include (*,{,//. The ^ will match the ({/
      scmMatchWholeLine,    // Match the entire line
      scmMatchAtAsterisk    // AnsiComment only, will match the * of (*, but not the (
    );

  TSynCommentIndentFlag = (
    // * For Matching lines (FCommentMode)
      //
      // * [], sciNone, sciAlignOpen
      // [] (neither sciNone nor sciAlignOpen)
                    // indent is the same as for none comment lines
                    // that is indent from previous line
      sciNone,      // Does not Indent comment lines (Prefix may contain a fixed indent)
                    // sciNone overrides sciAlignOpen
      sciAlignOpen, // Indent to real opening pos on first line, if comment does not start at BOL "Foo(); (*"
                    // Will force every new line back to Align.
      // add-ons (combine with above)
      sciAlignOpenOnce, // Force AlignOpen once for first line
                        // Can be combined sciNone or used without any of the above
      sciAlignOpenSkipBOL, // Combine with any sciAlignOpen...,
                           // only align if the comment starts behind other text (is not at BOL)

      // sciAdd...: if (only if) previous line had started with the opening token "(*" or "{".
      //            or if sciAlignOpen is set
      //            This is not done for "//", as Comment Extension will add a new "//"
      //            But Applies to sciNone
      sciAddTokenLen,        // add 1 or 2 spaces to indent (for the length of the token)
                             // in case of scmMatchAtAsterisk, 1 space is added. ("(" only)
      sciAddPastTokenIndent, // Adds any indent found past the opening token  "(*", "{" or "//".
                             // For "//" this is added after the nem "//", but before the prefix.


      sciMatchOnlyTokenLen,        // Apply the Above only if first line matches. (Only if sciAddTokenLen is specified)
      sciMatchOnlyPastTokenIndent,
      sciAlignOnlyTokenLen,        // Apply the Above only if sciAlignOpen/sciAlignOpenOnce was used
      sciAlignOnlyPastTokenIndent,

      // TODO: sciAlignOpenOnce followed by [] (neither = default indent) should keep the extra align, if it still is on the correct column

      // flag to ignore spaces, that are matched.
      // flag to be smart, if not matched

      sciApplyIndentForNoMatch  // Apply above rules For NONE Matching lines (FCommentMode),
                                // includes FIndentFirstLineExtra
    );
  TSynCommentIndentFlags = set of TSynCommentIndentFlag;

  TSynCommentExtendMode = (
      sceNever,                // Never Extend
      sceAlways,               // Always
      sceSplitLine,            // If the line was split (caret was not at EOL, when enter was pressed
      sceMatching,             // If the line matched (even if sccPrefixAlways or sccNoPrefix
      sceMatchingSplitLine
    );

  TSynCommentType = (sctAnsi, sctBor, sctSlash);

    // end mode

function dbgs(ACommentType: TSynCommentType): String; overload;
function dbgs(AContinueMode: TSynCommentContineMode): String; overload;
function dbgs(AMatchLine: TSynCommentMatchLine): String; overload;
function dbgs(AMatchMode: TSynCommentMatchMode): String; overload;
function dbgs(AIndentFlag: TSynCommentIndentFlag): String; overload;
function dbgs(AIndentFlags: TSynCommentIndentFlags): String; overload;
function dbgs(AExtendMode: TSynCommentExtendMode): String; overload;

implementation

function dbgs(ACommentType: TSynCommentType): String;
begin
  Result := ''; WriteStr(Result, ACommentType);
end;

function dbgs(AContinueMode: TSynCommentContineMode): String;
begin
  Result := ''; WriteStr(Result, AContinueMode);
end;

function dbgs(AMatchLine: TSynCommentMatchLine): String;
begin
  Result := ''; WriteStr(Result, AMatchLine);
end;

function dbgs(AMatchMode: TSynCommentMatchMode): String;
begin
  Result := ''; WriteStr(Result, AMatchMode);
end;

function dbgs(AIndentFlag: TSynCommentIndentFlag): String;
begin
  Result := ''; WriteStr(Result, AIndentFlag);
end;

function dbgs(AIndentFlags: TSynCommentIndentFlags): String;
var
  i: TSynCommentIndentFlag;
begin
  Result := '';
  for i := low(TSynCommentIndentFlag) to high(TSynCommentIndentFlag) do
    if i in AIndentFlags then
      if Result = ''
      then Result := dbgs(i)
      else Result := Result + ',' + dbgs(i);
  if Result <> '' then
    Result := '[' + Result + ']';
end;

function dbgs(AExtendMode: TSynCommentExtendMode): String;
begin
  Result := ''; WriteStr(Result, AExtendMode);
end;


{ TSynCustomBeautifier }

procedure TSynCustomBeautifier.Assign(Src: TPersistent);
begin
  if Src is TSynCustomBeautifier then begin
    FCurrentEditor := TSynCustomBeautifier(Src).FCurrentEditor;
    FCurrentLines := TSynCustomBeautifier(Src).FCurrentLines;
    FOnGetDesiredIndent := TSynCustomBeautifier(Src).FOnGetDesiredIndent;
    FAutoIndent := TSynCustomBeautifier(Src).FAutoIndent;
  end
  else
    inherited;
end;

function TSynCustomBeautifier.GetCopy: TSynCustomBeautifier;
begin
  // Since all synedits share one beautifier, create a temp instance.
  // Todo: have individual beautifiers
  Result := TSynCustomBeautifierClass(self.ClassType).Create(nil);
  Result.assign(self);
end;

procedure TSynCustomBeautifier.BeforeCommand(const Editor: TSynEditBase;
  const Lines: TSynEditStrings; const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand; InitialCmd: TSynEditorCommand);
begin
  // Must be called on GetCopy
  // Todo: have individual beautifiers
  FCurrentEditor := Editor;
  FCurrentLines := Lines;
  DoBeforeCommand(ACaret, Command);
end;

procedure TSynCustomBeautifier.AfterCommand(const Editor: TSynEditBase;
  const Lines: TSynEditStrings; const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand; InitialCmd: TSynEditorCommand;
  StartLinePos, EndLinePos: Integer);
begin
  // Must be called on GetCopy
  // Todo: have individual beautifiers
  FCurrentEditor := Editor;
  FCurrentLines := Lines;
  DoAfterCommand(ACaret, Command, StartLinePos, EndLinePos);
end;

{ TSynBeautifier }

procedure TSynBeautifier.Assign(Src: TPersistent);
begin
  inherited Assign(Src);
  if Src is TSynBeautifier then begin
    FIndentType := TSynBeautifier(Src).FIndentType;
    FCurrentEditor := TSynBeautifier(Src).FCurrentEditor;
    FCurrentLines := TSynBeautifier(Src).FCurrentLines;
  end;
end;

function TSynBeautifier.GetLine(AnIndex: Integer): String;
begin
  Result := FCurrentLines[AnIndex];
end;

procedure TSynBeautifier.GetIndentInfo(const LinePos: Integer; out ACharMix: String; out
  AnIndent: Integer; AStopScanAtLine: Integer);
var
  b: Integer;
begin
  ACharMix := '';
  if (GetLine(LinePos-2) = '') and (GetLine(LinePos-1) <> '') then
    AnIndent := 0
  else
    AnIndent := GetIndent(LinePos, b, AStopScanAtLine);

  if AnIndent > 0 then begin
    ACharMix := GetCharMix(LinePos, AnIndent, b, True);
    if (FIndentType = sbitPositionCaret) and (GetLine(LinePos-1) = '') then
      ACharMix := '';
  end;
end;

procedure TSynBeautifier.DoBeforeCommand(const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand);
var
  x: Integer;
begin
  if (Command = ecDeleteLastChar) and
     (FAutoIndent) and
     (ACaret.CharPos > 1) and
     (not FCurrentEditor.ReadOnly) and
     ( (not FCurrentEditor.SelAvail) or
       (eoPersistentBlock in FCurrentEditor.Options2) ) and
     (GetIndentForLine(FCurrentEditor, ACaret.LineText, True) = ACaret.CharPos - 1)
  then begin
    FCurrentLines.UndoList.CurrentReason := ecSmartUnindent;

    UnIndentLine(ACaret, x);
    ACaret.CharPos := x;
    Command := ecNone;
  end;
end;

procedure TSynBeautifier.DoAfterCommand(const ACaret: TSynEditCaret;
  var Command: TSynEditorCommand; StartLinePos, EndLinePos: Integer);
var
  y, Indent: Integer;
  s: String;
begin
  FLogicalIndentLen := 0;
  if EndLinePos < 1 then
    exit;
  if assigned(FOnGetDesiredIndent) and
    FOnGetDesiredIndent(self, FCurrentEditor, ACaret.LineBytePos,
                        ACaret.OldLineBytePos, StartLinePos, EndLinePos, Command,
                        @ApplyIndent)
  then
    exit;

  if ((Command = ecLineBreak) or (Command = ecInsertLine)) and FAutoIndent then begin
    if (Command = ecLineBreak) then
      y := ACaret.LinePos
    else
      y := ACaret.LinePos + 1;

    GetIndentInfo(y, s, Indent);

    if s <> '' then begin;
      FCurrentLines.EditInsert(1, y, s);
      FLogicalIndentLen := length(s);
    end;

    if (Command = ecLineBreak) then begin
      ACaret.IncForcePastEOL;
      ACaret.CharPos := Indent + 1;
      ACaret.DecForcePastEOL;
    end;
  end;
end;

function TSynBeautifier.UnIndentLine(const ACaret: TSynEditCaret;
  out CaretNewX: Integer): Boolean;
var
  SpaceCount1, SpaceCount2: Integer;
  BackCounter, LogSpacePos, FillSpace: Integer;
  LogCaret: TPoint;
  Line, Temp: String;
begin
  Line := ACaret.LineText;
  SpaceCount1 := GetIndentForLine(FCurrentEditor, Line, true); // physical, desired pos
  SpaceCount2 := 0;
  if (SpaceCount1 > 0) then begin
    BackCounter := ACaret.LinePos - 2;
    while BackCounter >= 0 do begin
      Temp := FCurrentLines[BackCounter];
      SpaceCount2 := GetIndentForLine(FCurrentEditor, Temp, true);
      if (SpaceCount2 < SpaceCount1) and (temp <> '') then
        break;
      Dec(BackCounter);
    end;
  end;
  if SpaceCount2 >= SpaceCount1 then
    SpaceCount2 := 0;
  // remove visible spaces
  LogSpacePos := FCurrentLines.PhysicalToLogicalCol(Line, ACaret.LinePos-1, SpaceCount2 + 1);
  FillSpace := SpaceCount2 + 1 - FCurrentLines.LogicalToPhysicalCol(Line, ACaret.LinePos-1, LogSpacePos);
  LogCaret := ACaret.LineBytePos;
  CaretNewX :=  SpaceCount2 + 1;
  FCurrentLines.EditDelete(LogSpacePos, ACaret.LinePos, LogCaret.X - LogSpacePos);
  if FillSpace > 0 then
    FCurrentLines.EditInsert(LogSpacePos, ACaret.LinePos, StringOfChar(' ', FillSpace));
  Result := True;
end;

function TSynBeautifier.GetIndent(const LinePos: Integer; out BasedOnLine: Integer;
  AStopScanAtLine: Integer): Integer;
var
  Temp: string;
begin
  if AStopScanAtLine > 0 then
    dec(AStopScanAtLine); // Convert to index
  BasedOnLine := LinePos - 1; // Convert to index
  while (BasedOnLine > AStopScanAtLine) do begin
    dec(BasedOnLine);
    Temp := GetLine(BasedOnLine);
    if Temp <> '' then begin
      Result := GetIndentForLine(FCurrentEditor, Temp, True);
      exit;
    end;
  end;
  Result := 0;
  //BasedOnLine := LinePos;
  //Result := GetIndentForLine(FCurrentEditor, GetLine(BasedOnLine), True);
end;

function TSynBeautifier.AdjustCharMix(DesiredIndent: Integer; CharMix, AppendMix: String): String;
var
  i: Integer;
  CurLen: Integer;
begin
  CurLen := FCurrentLines.LogicalToPhysicalCol(CharMix, -1, length(CharMix)+1) - 1; // TODO: Need the real index of the line
  if AppendMix <> '' then begin
    while CurLen < DesiredIndent do begin
      CharMix := CharMix + AppendMix;
      CurLen := FCurrentLines.LogicalToPhysicalCol(CharMix, -1, length(CharMix)+1) - 1; // TODO: Need the real index of the line
    end
  end;

  i := length(CharMix);
  while CurLen > DesiredIndent do begin
    Dec(i);
    CurLen := FCurrentLines.LogicalToPhysicalCol(CharMix, -1, i+1) - 1; // TODO: Need the real index of the line
  end;

  CharMix := copy(CharMix, 1, i) + StringOfChar(' ', DesiredIndent - CurLen);
  Result := CharMix;
end;

function TSynBeautifier.CreateTabSpaceMix(var DesiredIndent: Integer;
  OnlyTabs: Boolean): String;
var
  CurLen: Integer;
begin
  CurLen := 0;
  Result := '';
  while CurLen < DesiredIndent do begin
    Result := Result + #9;
    CurLen := FCurrentLines.LogicalToPhysicalCol(Result, -1, length(Result)+1) - 1; // TODO: Need the real index of the line
  end;

  if CurLen = DesiredIndent then
    exit;

  Delete(Result, Length(Result), 1);
  if OnlyTabs then begin
    CurLen := FCurrentLines.LogicalToPhysicalCol(Result, -1, length(Result)+1) - 1; // TODO: Need the real index of the line
    DesiredIndent := CurLen;
    exit;
  end;

  repeat
    Result := Result + ' ';
    CurLen := FCurrentLines.LogicalToPhysicalCol(Result, -1, length(Result)+1) - 1; // TODO: Need the real index of the line
  until CurLen >= DesiredIndent;
end;

function TSynBeautifier.GetCharMix(const LinePos: Integer; var Indent: Integer;
  var IndentCharsFromLinePos: Integer; ModifyIndent: Boolean): String;
var
  Temp, KnownMix, BasedMix: string;
  KnownPhysLen, PhysLen: Integer;
  BackCounter: LongInt;
  OrigIndent: Integer;
begin
  OrigIndent := Indent;
  case FIndentType of
      sbitSpace, sbitPositionCaret:
      begin
        IndentCharsFromLinePos := 0;
        Result := StringOfChar(' ', Indent);
        if not ModifyIndent then Indent := OrigIndent;
        exit;
      end;
    sbitConvertToTabSpace:
      begin
        IndentCharsFromLinePos := 0;
        Result := CreateTabSpaceMix(Indent, False);
        exit;
        if not ModifyIndent then Indent := OrigIndent;
      end;
    sbitConvertToTabOnly:
      begin
        IndentCharsFromLinePos := 0;
        Result := CreateTabSpaceMix(Indent, True);
        if not ModifyIndent then Indent := OrigIndent;
        exit;
      end;
  end;

  if (IndentCharsFromLinePos > 0) and (IndentCharsFromLinePos <= FCurrentLines.Count) then
  begin
    Temp := GetLine(IndentCharsFromLinePos);
    KnownMix := copy(Temp, 1, GetIndentForLine(FCurrentEditor, Temp, False));
  end
  else
    KnownMix := '';
  BasedMix := KnownMix;
  KnownPhysLen := GetIndentForLine(FCurrentEditor, KnownMix, True);

  BackCounter := LinePos;
  while (BackCounter > 0) and (KnownPhysLen < Indent) do begin
    dec(BackCounter);
    Temp := GetLine(BackCounter);
    if Temp <> '' then begin
      Temp := copy(Temp, 1, GetIndentForLine(FCurrentEditor, Temp, False));
      PhysLen := GetIndentForLine(FCurrentEditor, Temp, True);
      if (PhysLen > KnownPhysLen) and LazStartsStr(BasedMix, Temp) then
      begin
        KnownMix := Temp;
        KnownPhysLen := PhysLen;
        IndentCharsFromLinePos := BackCounter + 1;
      end;
    end;
  end;

  Result := AdjustCharMix(Indent, KnownMix, '');
  if not ModifyIndent then Indent := OrigIndent;
end;

procedure TSynBeautifier.ApplyIndent(LinePos: Integer;
  Indent: Integer; RelativeToLinePos: Integer; IndentChars: String = '';
  IndentCharsFromLinePos: Integer = 0);
var
  CharMix: String;
  i: Integer;
begin
  if (LinePos < 1) or (LinePos > FCurrentEditor.Lines.Count) then
    exit;

  // calculate the final indent needed
  if (RelativeToLinePos > 0) and (RelativeToLinePos <= FCurrentEditor.Lines.Count) then
    Indent := Indent + GetIndentForLine(FCurrentEditor, GetLine(RelativeToLinePos-1), True);
  if Indent< 0 then
    Indent := 0;

  // Calculate the charmix
  CharMix := '';
  if Indent > 0 then begin
    if (IndentCharsFromLinePos > 0) and (IndentCharsFromLinePos <= FCurrentEditor.Lines.Count) then begin
      CharMix := GetLine(IndentCharsFromLinePos-1);
      i :=  GetIndentForLine(FCurrentEditor, CharMix, False);
      CharMix := AdjustCharMix(Indent, copy(CharMix, 1, i), IndentChars);
    end
    else if IndentChars <> '' then begin
      CharMix := AdjustCharMix(Indent, '', IndentChars);
    end
    else begin
      i := LinePos;
      CharMix := GetCharMix(LinePos, Indent, i);
    end;
  end;

  {$IFDEF VerboseIndenter}
  DebugLn(['TSynBeautifier.ApplyIndent IndentChars="',dbgstr(IndentChars),' Indent=',Indent]);
  {$ENDIF}

  i :=  GetIndentForLine(FCurrentEditor, GetLine(LinePos-1), False);
  FCurrentLines.EditDelete(1, LinePos, i);
  if (CharMix <> '') and not((FIndentType = sbitPositionCaret) and (GetLine(LinePos-1) = '')) then
    FCurrentLines.EditInsert(1, LinePos, CharMix);
  FLogicalIndentLen := length(CharMix);

  {$IFDEF VerboseIndenter}
  DebugLn(['TSynBeautifier.ApplyIndent Line="',dbgstr(FCurrentLines.ExpandedStrings[LinePos-1]),'"']);
  {$ENDIF}
end;

function TSynBeautifier.GetIndentForLine(Editor: TSynEditBase; const Line: string; Physical: boolean): Integer;
var
  p: PChar;
begin
  p := PChar(Line);
  if Assigned(p) then begin
    Result := 0;
    while p^ in [#1..#32] do begin
      Inc(p);
      Inc(Result);
    end;
    if Physical and (Result>0) then
      Result := FCurrentLines.LogicalToPhysicalCol(Line, -1, Result+1)-1; // TODO, Need the real index of the line
  end else
    Result := 0;
end;

function TSynBeautifier.GetDesiredIndentForLine(Editor: TSynEditBase;
  const Lines: TSynEditStrings; const ACaret: TSynEditCaret;
  out ReplaceIndent: Boolean; out DesiredIndent: String): Integer;
var
  BackCounter, PhysLen: Integer;
  Temp: string;
  FoundLine: LongInt;
begin
  Result := 1;
  FCurrentLines := Lines; // for GetCurrentIndent
  BackCounter := ACaret.LinePos - 1;
  if BackCounter > 0 then
    repeat
      Dec(BackCounter);
      Temp := Lines[BackCounter];
      Result := GetIndentForLine(Editor, Temp, True) + 1; // Physical
    until (BackCounter = 0) or (Temp <> '');

  FoundLine := BackCounter + 1;
  ReplaceIndent := False;
  //if assigned(FOnGetDesiredIndent) then
  //  FOnGetDesiredIndent(Editor, ACaret.LineBytePos, ACaret.LinePos, Result,
  //                      FoundLine, ReplaceIndent);

  //if Result < 0 then exit;

  //if FoundLine > 0 then
  //  Temp := Lines[FoundLine-1]
  //else
  //  FoundLine := BackCounter + 1;
  Temp := copy(Temp, 1, GetIndentForLine(Editor, Temp, False));

  case FIndentType of
    sbitCopySpaceTab:
      begin
        DesiredIndent := copy(Temp, 1,
                   Lines.PhysicalToLogicalCol(Temp, FoundLine - 1, Result) - 1);
        PhysLen := Lines.LogicalToPhysicalCol(Temp, ACaret.LinePos - 1, Length(Temp) + 1);
        if PhysLen < Result then
          DesiredIndent := DesiredIndent + StringOfChar(' ', Result - PhysLen);
      end;
    sbitConvertToTabSpace:
      begin
        dec(Result);
        DesiredIndent := CreateTabSpaceMix(Result, False);
        inc(Result);
      end;
    sbitConvertToTabOnly:
      begin
        dec(Result);
        DesiredIndent := CreateTabSpaceMix(Result, True);
        inc(Result);
      end;
    else
      DesiredIndent := StringOfChar(' ', Result - 1);
  end;
end;

function TSynBeautifier.GetDesiredIndentForLine(Editor: TSynEditBase;
  const Lines: TSynEditStrings; const ACaret: TSynEditCaret): Integer;
var
  Dummy: String;
  Replace: Boolean;
begin
  Result := GetDesiredIndentForLine(Editor, Lines, ACaret, Replace, Dummy);
end;

end.


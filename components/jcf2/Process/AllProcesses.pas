unit AllProcesses;

{ all warnings put together }

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is AllProcesses, released May 2003.
The Initial Developer of the Original Code is Anthony Steele. 
Portions created by Anthony Steele are Copyright (C) 1999-2008 Anthony Steele.
All Rights Reserved. 
Contributor(s): Anthony Steele. 

The contents of this file are subject to the Mozilla Public License Version 1.1
(the "License"). you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.mozilla.org/NPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied.
See the License for the specific language governing rights and limitations 
under the License.

Alternatively, the contents of this file may be used under the terms of
the GNU General Public License Version 2 or later (the "GPL") 
See http://www.gnu.org/licenses/gpl.html
------------------------------------------------------------------------------*)
{*)}

{$I JcfGlobal.inc}

interface

uses
  ParseTreeNode, BaseVisitor, ConvertTypes, TreeWalker;

type

  TAllProcesses = class(TObject)
  private
    fcTreeWalker: TTreeWalker;

    fcOnMessages: TStatusMessageProc;
    fcRoot: TParseTreeNode;

    procedure ApplyVisitorType(const pcVisitorType: TTreeNodeVisitorType); overload;
    procedure ApplyVisitorType(const pcVisitorType: TTreeNodeVisitorType;
      const pcFollowSet: array of TTreeNodeVisitorType); overload;

    procedure Obfuscate;

    procedure ClarifySetup;
    procedure Transform;
    procedure Warnings;
    procedure Spacing;
    procedure LineBreaking;
    procedure Capitalisation;
    procedure Indent;
    procedure Align;

    procedure OnceOffs;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Execute(const pcRoot: TParseTreeNode);

    property OnMessage: TStatusMessageProc Read fcOnMessages Write fcOnMessages;
  end;

implementation

uses
  Forms, SysUtils,
  { local }
  JcfSettings, SetClarify, VisitSetXY,
  { once-offs }
  //MozComment,
  //GlobalInclude,
  { obfuscate}
  FixCase, RemoveComment, RemoveBlankLine, RemoveReturn, ReduceWhiteSpace,
  RemoveConsecutiveWhiteSpace, RemoveUnneededWhiteSpace, RebreakLines,
  { transform }
  FindReplace, UsesClauseInsert, UsesClauseRemove, UsesClauseFindReplace,
  RemoveEmptyComment, AddBeginEnd, AddBlockEndSemicolon, SortUses,
  { warnings }
  Warning, WarnEmptyBlock, WarnRealType, WarnAssignToFunctionName,
  WarnCaseNoElse, WarnDestroy, WarnUnusedParam, WarnImbalancedComment,
  { caps}
  UnitNameCaps, SpecificWordCaps, IdentifierCaps, Capitalisation,
  { returns }
  ReturnChars,
  RemoveReturnsAfterBegin, RemoveReturnsBeforeEnd,
  PropertyOnOneLine,
  RemoveBlankLinesAfterProcHeader, RemoveBlankLinesInVars,
  NoReturnBefore, NoReturnAfter, ReturnBefore, ReturnAfter,
  BlockStyles, ReturnsAfterFinalEnd,
  RemoveConsecutiveReturns, RemoveReturnsAfter,
  { spacing}
  TabToSpace, SpaceToTab, MaxSpaces,
  NoSpaceAfter, NoSpaceBefore, SingleSpaceBefore, SingleSpaceAfter,
  SpaceBeforeColon, RemoveSpaceAtLineEnd, VisitStripEmptySpace,
  MoveSpaceToBeforeColon,
  {indent}
  VisitSetNesting, Indenter, LongLineBreaker,
  { stats }
  BasicStats,
  { align }
  AlignConst, AlignVars, AlignAssign, AlignTypedef, AlignComment, AlignField,
  IndentAsmParam;

constructor TAllProcesses.Create;
begin
  inherited;

  fcOnMessages := nil;
  fcTreeWalker := TTreeWalker.Create;
end;


destructor TAllProcesses.Destroy;
begin
  FreeAndNil(fcTreeWalker);
  inherited;
end;

procedure TAllProcesses.ApplyVisitorType(const pcVisitorType: TTreeNodeVisitorType);
begin
  ApplyVisitorType(pcVisitorType, []);
end;

{ the idea behind the follow set is that
  several processes are often used after a main one.
  e.g. after the linebreaker, redo the VisitSetXY and the RemoveEmptySpace
  if the main process doesn't fire due to settings, or makes no changes,
  can save time by omitting the cleanup
  }
procedure TAllProcesses.ApplyVisitorType(const pcVisitorType: TTreeNodeVisitorType;
  const pcFollowSet: array of TTreeNodeVisitorType);
var
  lc, lcFollow: TBaseTreeNodeVisitor;
  lsMessage: string;
  liLoop: integer;
begin
  Assert(fcRoot <> nil);

  lc := pcVisitorType.Create;
  try
    if lc.IsIncludedInSettings then
    begin
      if lc is TWarning then
      begin
        (lc as TWarning).OnWarning := OnMessage;
      end;

      fcTreeWalker.Visit(fcRoot, lc);

      if lc.FinalSummary(lsMessage) then
        OnMessage('', lsMessage, mtFinalSummary, -1, -1);
      
      {$IFNDEF COMMAND_LINE}
      Application.ProcessMessages;
      {$ENDIF}

      { if the main process fired, do the follow set too }
      for liLoop := Low(pcFollowSet) to High(pcFollowSet) do
      begin
        lcFollow := pcFollowSet[liLoop].Create;
        try
          fcTreeWalker.Visit(fcRoot, lcFollow);
        finally
          lcFollow.Free;
        end;
      end;

    end;
  finally
    lc.Free;
  end;
end;

procedure TAllProcesses.Execute(const pcRoot: TParseTreeNode);
begin
  Assert(pcRoot <> nil);
  fcRoot := pcRoot;

  if FormattingSettings.Clarify.OnceOffs = eRunOnly then
  begin
    // run only the once-offs
    OnceOffs;
  end
  else if FormattingSettings.Obfuscate.Enabled then
  begin
    Obfuscate;
  end
  else
  begin
    // normal clarify path
    ClarifySetup;

    Transform;
    Warnings;
    Capitalisation;
    LineBreaking;
    Spacing;
    Indent;
    Align;

    // run the once-offs too?
    if FormattingSettings.Clarify.OnceOffs = eDoRun then
      OnceOffs;

    // Do this last - spaces may have been introduced above.
    ApplyVisitorType(TSpaceToTab);

    // stats last
    ApplyVisitorType(TBasicStats);
  end;
end;

procedure TAllProcesses.Obfuscate;
begin
  // apply them all
  ApplyVisitorType(TFixCase);
  ApplyVisitorType(TRemoveComment, [TVisitSetXY]);
  ApplyVisitorType(TRemoveBlankLine, [TVisitSetXY]);
  ApplyVisitorType(TRemoveReturn);
  ApplyVisitorType(TReduceWhiteSpace);
  ApplyVisitorType(TRemoveConsecutiveWhiteSpace);

  ApplyVisitorType(TRemoveUnneededWhiteSpace);

  ApplyVisitorType(TVisitSetXY);
  ApplyVisitorType(TVisitStripEmptySpace);
  ApplyVisitorType(TRebreakLines);
end;

procedure TAllProcesses.ClarifySetup;
begin
  ApplyVisitorType(TVisitSetNestings);
  ApplyVisitorType(TVisitSetXY);
end;

procedure TAllProcesses.Transform;
begin
  ApplyVisitorType(TFindReplace);
  ApplyVisitorType(TUsesClauseInsert);
  ApplyVisitorType(TUsesClauseRemove);
  ApplyVisitorType(TUsesClauseFindReplace);

  ApplyVisitorType(TRemoveEmptyComment);

  ApplyVisitorType(TAddBeginEnd, [TVisitSetNestings, TVisitSetXY]);
  ApplyVisitorType(TBlockEndSemicolon, [TVisitSetNestings, TVisitSetXY]);

  ApplyVisitorType(TSortUses, [TVisitSetXY]);
end;


procedure TAllProcesses.Warnings;
begin
  ApplyVisitorType(TVisitSetXY);

  ApplyVisitorType(TWarnEmptyBlock);
  ApplyVisitorType(TWarnRealType);
  ApplyVisitorType(TWarnAssignToFunctionName);
  ApplyVisitorType(TWarnCaseNoElse);
  ApplyVisitorType(TWarnDestroy);

  ApplyVisitorType(TWarnUnusedParam);

  ApplyVisitorType(TWarnImbalancedComment);
end;

procedure TAllProcesses.Capitalisation;
begin
  { reserved word caps must come before identifiers etc
    or "true" cannot be converted to "True" by the identifier process
  }
  ApplyVisitorType(TCapitalisation);

  ApplyVisitorType(TUnitNameCaps);
  ApplyVisitorType(TSpecificWordCaps);
  ApplyVisitorType(TIdentifierCaps);
end;

procedure TAllProcesses.Spacing;
begin
  ApplyVisitorType(TTabToSpace);
  //ApplyVisitorType(TSpaceToTab);
  ApplyVisitorType(TMaxSpaces);

  ApplyVisitorType(TNoSpaceAfter);
  ApplyVisitorType(TNoSpaceBefore);
  ApplyVisitorType(TVisitStripEmptySpace);

  ApplyVisitorType(TSingleSpaceBefore);
  ApplyVisitorType(TSingleSpaceAfter);
  ApplyVisitorType(TVisitStripEmptySpace);

  ApplyVisitorType(TSpaceBeforeColon);
  ApplyVisitorType(TRemoveSpaceAtLineEnd);
  ApplyVisitorType(TVisitStripEmptySpace);
end;

procedure TAllProcesses.LineBreaking;
begin
  ApplyVisitorType(TReturnChars);

  ApplyVisitorType(TPropertyOnOneLine, [TVisitStripEmptySpace]);
  ApplyVisitorType(TRemoveBlankLinesAfterProcHeader, [TVisitStripEmptySpace]);
  ApplyVisitorType(TRemoveBlankLinesInVars, [TVisitStripEmptySpace]);
  ApplyVisitorType(TRemoveReturnsAfterBegin, [TVisitStripEmptySpace]);
  ApplyVisitorType(TRemoveReturnsBeforeEnd, [TVisitStripEmptySpace]);

  ApplyVisitorType(TNoReturnAfter, [TVisitStripEmptySpace]);
  ApplyVisitorType(TNoReturnBefore, [TVisitStripEmptySpace]);

  ApplyVisitorType(TRemoveConsecutiveReturns);
  ApplyVisitorType(TRemoveReturnsAfter);

  ApplyVisitorType(TVisitSetXY);
  ApplyVisitorType(TReturnBefore, [TVisitSetXY]);
  ApplyVisitorType(TReturnAfter, [TVisitSetXY]);

  ApplyVisitorType(TBlockStyles, [TVisitSetXY]);

  { long line breaking is a bit of a circular thing
    The indentation before the code on the line
    influences if (and where) to insert a break

    But indenting needs to happen the linebreaker to indent the trailing line
    Fortunately this is only an issue when code is really badly formatted
    e.g. de-obfucation }

  ApplyVisitorType(TVisitStripEmptySpace, [TVisitSetXY]);
  ApplyVisitorType(TLongLineBreaker, [TVisitSetXY]);
  ApplyVisitorType(TReturnsAfterFinalEnd, [TVisitSetXY]);
  ApplyVisitorType(TLongLineBreaker);
end;


procedure TAllProcesses.Indent;
begin
  ApplyVisitorType(TVisitSetXY);
  ApplyVisitorType(TIndenter, [TVisitSetXY]);
end;

procedure TAllProcesses.Align;
begin
  ApplyVisitorType(TAlignConst, [TVisitSetXY]);
  ApplyVisitorType(TAlignVars, [TVisitSetXY]);
  ApplyVisitorType(TAlignAssign, [TVisitSetXY]);
  ApplyVisitorType(TAlignTypedef, [TVisitSetXY]);
  ApplyVisitorType(TAlignField, [TVisitSetXY]);
  ApplyVisitorType(TAlignComment, [TVisitSetXY]);

  ApplyVisitorType(TIndentAsmParam, [TVisitSetXY]);

  ApplyVisitorType(TMoveSpaceToBeforeColon);
end;

procedure TAllProcesses.OnceOffs;
begin
  //ApplyVisitorType(TMozComment);
  //ApplyVisitorType(TGlobalInclude);
end;

end.

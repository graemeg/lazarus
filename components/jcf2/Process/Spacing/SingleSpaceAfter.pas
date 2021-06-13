unit SingleSpaceAfter;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is SingleSpaceAfter, released May 2003.
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

{ AFS 9 Dec 1999
  Single space after }

uses SwitchableVisitor;

type
  TSingleSpaceAfter = class(TSwitchableVisitor)
  private
  protected
    function EnabledVisitSourceToken(const pcNode: TObject): boolean; override;
  public
    constructor Create; override;

    function IsIncludedInSettings: boolean; override;
  end;


implementation

uses
  { local }
  JcfStringUtils,
  SourceToken, Tokens, ParseTreeNodeType, JcfSettings,
  FormatFlags, TokenUtils, SettingsTypes;

const
  SingleSpaceAfterTokens: TTokenTypeSet = [ttColon, ttAssign, ttComma,
    ttPlusAssign, ttMinusAssign, ttTimesAssign, ttFloatDivAssign];

  SingleSpaceAfterWords: TTokenTypeSet = [
    ttProcedure, ttFunction,
    ttConstructor, ttDestructor, ttProperty,
    ttOf, ttDo, ttWhile, ttUntil, ttCase, ttIf, ttTo, ttDownTo, ttGeneric];

  PossiblyUnaryOperators: TTokenTypeSet = [ttPlus, ttMinus];

function NeedsSingleSpace(const pt, ptNext: TSourceToken): boolean;
var
  lcSameLineToken,lcPrev: TSourceToken;
begin
  Assert(pt <> nil);
  Assert(ptNext <> nil);

  Result := False;

  if pt.HasParentNode(nLiteralString) then
    exit;

  if pt.HasParentNode(nAsm) then
    exit;

  if pt.HasParentNode(nGeneric, 2) then
  begin
    if pt.TokenType in [ttComma, ttColon, ttSemiColon] then
      Result := true;
    exit;
  end;

  // if the next token is a comment, leave it where it is, do not adjust spacing
  if ptNext.TokenType = ttComment then
    exit;

  // semicolons
  if (pt.TokenType = ttSemiColon) then
  begin

    { semciolon as a record field seperator in a const record declaration
     has no newline (See ReturnAfter.pas), just a single space }
    if (pt.HasParentNode(nRecordConstant)) then
      exit(True);

    { semicolon  in param  declaration list }
    if (pt.HasParentNode(nFormalParams)) then
      exit(True);

    { semicolon in param lists in proc type def. as above }
    if (pt.HasParentNode(nProcedureType)) then
      exit(True);

    { semicolon in procedure directives }
    if (pt.HasParentNode(nProcedureDirectives)) then
      exit(True);

  end;// semicolon

  { function foo: integer; has single space after the colon
    single space after colon - anywhere? }
  if pt.TokenType = ttColon then
    Result := True;

  if (pt.TokenType in SingleSpaceAfterTokens) then
  begin
    lcPrev := pt.PriorSolidToken;
    if (lcPrev <> nil) and (lcPrev.TokenType = ttDot) then // operaror  typename.:=( )  .+= .*=
      exit(false);
    exit(True);
  end;

  if pt.TokenType = ttOpenBracket then
    if FormattingSettings.Spaces.SpaceAfterOpenBrackets then
      exit(true);

  { 'absolute' as a var directive }
  if (pt.TokenType = ttAbsolute) and pt.HasParentNode(nVarAbsolute) then
    exit(True);

  if (pt.TokenType in SingleSpaceAfterWords) then
  begin
    { 'procedure' and 'function' in proc type def don't have space after, e.g.
      type
        TFredProc = procedure(var psFred: integer); }

    if (pt.HasParentNode(nProcedureType, 2)) and (ptNext.TokenType in
      [ttOpenBracket, ttSemiColon]) then
      Result := False
    else
      Result := True;

    exit;
  end;

  if FormattingSettings.Spaces.SpaceForOperator = eAlways then
  begin
    if (pt.TokenType in SingleSpaceOperators) then
      exit(True);

    { + or - but only if it is a binary operator, ie a term to the left of it }
    if (pt.TokenType in PossiblyUnaryOperators) and (pt.HasParentNode(nExpression)) and
      ( not IsUnaryOperator(pt)) then
      exit(True);
  end;

  { only if it actually is a directive, see TestCases/TestBogusDirectives for details }
  if (pt.TokenType in AllDirectives) and (pt.HasParentNode(DirectiveNodes)) and
    (ptNext.TokenType <> ttSemiColon)
  then
    exit(True);

  if pt.TokenType = ttEquals then
    exit(True);

  { 'in' in the uses clause }
  if (pt.TokenType = ttIn) and (pt.HasParentNode(nUses)) then
    exit(True);

  { const or var as parameter var types }
  if (pt.TokenType in ParamTypes) and (pt.HasParentNode(nFormalParams)) then
    // beware of 'procedure foo (bar: array of const);' and the like
    if not ((pt.TokenType = ttConst) and pt.HasParentNode(nType, 1)) then
      exit(True);

  if (pt.TokenType in ParamTypes) and pt.HasParentNode(nPropertyParameterList) and
    pt.IsOnRightOf(nPropertyParameterList, ttOpenSquareBracket)
  then
    exit(True);

  { signle space after read, write etc in property }
  if pt.HasParentNode(nProperty) then
    if (pt.TokenType in [ttProperty, ttRead, ttWrite, ttDefault, ttStored, ttImplements])
      and (ptNext.TokenType <> ttSemiColon)
    then
      exit(True);

  { single space before class heritage ?
    see NoSpaceAfter }
  if (pt.HasParentNode(nRestrictedType)) and (pt.TokenType in ObjectTypeWords) and
    (FormattingSettings.Spaces.SpaceBeforeClassHeritage) then
  begin
    if (ptNext.TokenType in [ttOpenBracket, ttSemiColon]) then
      exit(True);
  end;

  if InStatements(pt) then
  begin
    // else if
    if (pt.TokenType = ttElse) and (ptNext.TokenType = ttIf) then
      exit(True);

    // end else
    if (pt.TokenType = ttEnd) and (ptNext.TokenType = ttElse) then
      exit(True);

    { else followed by something else on the same line,
      e.g if block style brings up the following "begin" }
    if (pt.TokenType = ttElse) then
    begin
      lcSameLineToken := pt.NexttokenWithExclusions([ttWhiteSpace]);
      if (lcSameLineToken <> nil) and (not (lcSameLineToken.TokenType in [ttReturn, ttSemiColon])) then
        exit(True);
    end;
  end;

end;


constructor TSingleSpaceAfter.Create;
begin
  inherited;
  FormatFlags := FormatFlags + [eAddSpace, eRemoveSpace, eRemoveReturn];
end;

function TSingleSpaceAfter.EnabledVisitSourceToken(const pcNode: TObject): boolean;
var
  lcSourceToken: TSourceToken;
  lcNext, lcNew: TSourceToken;
begin
  Result := False;
  lcSourceToken := TSourceToken(pcNode);

  { exclude if a comment is next }
  lcNext := lcSourceToken.NextTokenWithExclusions([ttWhiteSpace, ttReturn]);
  if lcNext = nil then
    exit;

  if lcNext.TokenType = ttComment then
    exit;

  if NeedsSingleSpace(lcSourceToken, lcNext) then
  begin
    { inspect the next token }
    lcNext := lcSourceToken.NextToken;
    if lcNext.TokenType = ttWhiteSpace then
    begin
      lcNext.SourceCode := NativeSpace;

      { empty any preceeding whitespace }
      repeat
        lcNext := lcNext.NextToken;
        if lcNext.TokenType = ttWhiteSpace then
          lcNext.SourceCode := '';
      until lcNext.TokenType <> ttWhiteSpace;

    end
    else if (lcNext.TokenType <> ttReturn) then
    begin
      // insert a space
      lcNew := TSourceToken.Create;
      lcNew.TokenType := ttWhiteSpace;
      lcNew.SourceCode := NativeSpace;

      InsertTokenAfter(lcSourceToken, lcNew);
    end;

  end;
end;

function TSingleSpaceAfter.IsIncludedInSettings: boolean;
begin
  Result := FormattingSettings.Spaces.FixSpacing;
end;

end.

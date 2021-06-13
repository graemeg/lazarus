unit SingleSpaceBefore;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is SingleSpaceBefore, released May 2003.
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


{ AFS 7 Dec 1999
  single space before certain tokens (e.g. ':='

  This process and SingleSpaceAfter must be carefull with directives:
   words like "read" and "write" must be single-spaced in property defs
   but in normal code these are valid procedure names, and
     converting "Result := myObject.Read;" to
     "Result := myObject. read ;" compiles, but looks all wrong
}

uses SwitchableVisitor;

type
  TSingleSpaceBefore = class(TSwitchableVisitor)
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
  // space before all operators
  SingleSpaceBeforeWords: TTokenTypeSet = [ttEquals, ttThen, ttOf, ttDo,
    ttTo, ttDownTo];

  NoSpaceAfterTokens: TTokenTypeSet = [ttOpenBracket, ttOpenSquareBracket];

function NeedsSpaceBefore(const pt: TSourceToken): boolean;
var                         
  lcPrev: TSourceToken;
begin
  Result := False;

  if pt = nil then
    exit;

  if pt.HasParentNode(nGeneric, 1) then
    exit;

  if pt.TokenType = ttCloseBracket then
  begin
    if FormattingSettings.Spaces.SpaceBeforeCloseBrackets then
      exit(True);
  end;

  if (pt.TokenType = ttOpenBracket) then
  begin
    if FormattingSettings.Spaces.SpaceBeforeOpenBracketsInFunctionDeclaration then
    begin
      if pt.HasParentNode(nFormalParams, 1) then
        exit(True);
    end;

    if FormattingSettings.Spaces.SpaceBeforeOpenBracketsInFunctionCall then
    begin
      if pt.HasParentNode(nActualParams, 1) then
        exit(True);
    end;

  end
  else if (pt.TokenType = ttOpenSquareBracket) then
  begin
    if FormattingSettings.Spaces.SpaceBeforeOpenSquareBracketsInExpression then
    begin
      if pt.HasParentNode(nExpression) then
        exit(True);
    end;
  end;

  if pt.HasParentNode(nLiteralString) then
    exit(False);

  if IsClassHelperWords(pt) then
    exit(True);

  { not in Asm block }
  if pt.HasParentNode(nAsm) then
    exit;

  if (pt.TokenType in AssignmentDirectives) then
  begin
    lcPrev := pt.PriorSolidToken;
    if (lcPrev <> nil) and (lcPrev.TokenType = ttDot) then // operaror  typename.:=( )
      exit(false);
    exit(True);
  end;

  if IsHintDirective(pt) then
    exit(True);

  if (pt.TokenType in AllDirectives) and (pt.HasParentNode(DirectiveNodes)) then
    exit(True);

  if (pt.TokenType in SingleSpaceBeforeWords) then
    exit(True);

  if FormattingSettings.Spaces.SpaceForOperator = eAlways then
  begin
    if (pt.TokenType in SingleSpaceOperators) then
    begin
      Result := True;
    end;

    { 'a := --3;' and 'lc := ptr^;'
    are the only exceptions to the rule of a space before an operator }
    if (pt.TokenType in Operators) then
    begin
      if (pt.TokenType = ttHat) or
        (IsUnaryOperator(pt) and IsUnaryOperator(pt.PriorSolidToken)) then
        Result := False
      else
        Result := True;

      exit;
    end;

  end;

  { 'in' in the uses clause }
  if ((pt.TokenType = ttIn) and (pt.HasParentNode(nUses))) then
    exit(True);

  { comment just after uses clause, unless it's a compiler directive }
  if (pt.TokenType = ttComment) and (pt.CommentStyle <> eCompilerDirective) then
  begin
    lcPrev := pt.PriorSolidToken;
    if (lcPrev <> nil) and (lcPrev.TokenType = ttUses) then
      exit(True);
  end;

  { 'absolute' as a var directive }
  if (pt.TokenType = ttAbsolute) and pt.HasParentNode(nVarAbsolute) then
    exit(True);

  { any token that starts a literal string }
  if StartsLiteralString(pt) then
    exit(True);

  if (pt.TokenType = ttDefault) and pt.HasParentNode(nPropertySpecifier) then
    exit(True);

  { signle space before read, write etc in property }
  if pt.HasParentNode(nProperty) then
  begin
    if (pt.TokenType in [ttProperty, ttRead, ttWrite, ttDefault,
      ttStored, ttNoDefault, ttImplements]) then
      exit(True);
  end;


  { program uses clauses has a form link comment }
  if InFilesUses(pt) then
  begin
    if ((pt.TokenType = ttComment) and (pt.CommentStyle in CURLY_COMMENTS)) and
      pt.IsOnRightOf(nUses, ttUses) then
      exit(True);
  end;

  if pt.TokenType in [ttNear,ttFar,ttHuge] then
    exit(True);

end;


constructor TSingleSpaceBefore.Create;
begin
  inherited;
  FormatFlags := FormatFlags + [eAddSpace, eRemoveSpace, eRemoveReturn];
end;

function TSingleSpaceBefore.EnabledVisitSourceToken(const pcNode: TObject): boolean;
var
  lcSourceToken, lcNext, lcNew: TSourceToken;
begin
  Result := False;
  lcSourceToken := TSourceToken(pcNode);
  lcNext := lcSourceToken.NextToken;

  if lcNext = nil then
    exit;

  // suspend this rule after open brackets
  // e.g. if there's a space before a '-' minus sign
  // this applies to "x - 1" but not "(-1 + x)"
  if lcSourceToken.TokenType in NoSpaceAfterTokens then
  begin
    exit;
  end;

  if NeedsSpaceBefore(lcNext) then
  begin
    if (lcSourceToken.TokenType = ttWhiteSpace) then
    begin
      { one space }
      lcSourceToken.SourceCode := NativeSpace;

      { empty any preceeding whitespace }
      repeat
        lcSourceToken := lcSourceToken.PriorToken;
        if lcSourceToken.TokenType = ttWhiteSpace then
          lcSourceToken.SourceCode := '';
      until lcSourceToken.TokenType <> ttWhiteSpace;
    end
    else
    begin
      lcNew := TSourceToken.Create;
      lcNew.TokenType := ttWhiteSpace;
      lcNew.SourceCode := NativeSpace;

      InsertTokenAfter(lcSourceToken, lcNew);
    end;
  end;

end;

function TSingleSpaceBefore.IsIncludedInSettings: boolean;
begin
  Result := FormattingSettings.Spaces.FixSpacing;
end;

end.

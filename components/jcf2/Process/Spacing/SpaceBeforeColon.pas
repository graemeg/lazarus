unit SpaceBeforeColon;

{ AFS 6 March 2003
  spaces (or not) before colon
}

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is SpaceBeforeColon, released May 2003.
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

uses SwitchableVisitor;

type
  TSpaceBeforeColon = class(TSwitchableVisitor)
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
  JcfSettings, SetSpaces, SourceToken, Tokens, ParseTreeNodeType,
  FormatFlags, TokenUtils;

function SpacesBefore(const pt: TSourceToken): integer;
var
  lcSpaces: TSetSpaces;
begin
  Assert(pt.TokenType = ttColon);

  lcSpaces := FormattingSettings.Spaces;

  if pt.HasParentNode(nFormalParams) and InRoundBrackets(pt) then
  begin
    { in procedure params }
    Result := lcSpaces.SpacesBeforeColonParam;
  end
  else if pt.HasParentNode(nFunctionHeading) and not
    (pt.HasParentNode(nFormalParams)) then
  begin
    // function result type
    Result := lcSpaces.SpacesBeforeColonFn;
  end
  else if pt.HasParentNode(nVarSection) then
  begin
    // variable decl
    Result := lcSpaces.SpacesBeforeColonVar;
  end

  else if pt.HasParentNode(nConstSection) then
  begin
    // variable/const/type decl
    Result := lcSpaces.SpacesBeforeColonConst;
  end

  else if pt.HasParentNode(nTypeSection) then
  begin
    // type decl uses =, but there are colons in the fields of record defs and object types
    if pt.HasParentNode(ObjectTypes) then
    begin
      Result := lcSpaces.SpacesBeforeColonClassVar;
    end
    else if pt.HasParentNode(nRecordType) then
    begin
      Result := lcSpaces.SpacesBeforeColonRecordField;
    end
    else
    if pt.HasParentNode(nGeneric) then
    begin
      Result := lcSpaces.SpacesBeforeColonInGeneric;
    end
    else
    begin
      Result := 0;
      Assert(False, 'No context for colon ' + pt.DescribePosition);
    end;
  end
  else if pt.HasParentNode(nLabelDeclSection) then
  begin
    Result := lcSpaces.SpacesBeforeColonLabel;
  end
  else if InStatements(pt) then
  begin
    if IsCaseColon(pt) then
      Result := lcSpaces.SpacesBeforeColonCaseLabel
    else if IsLabelColon(pt) then
      Result := lcSpaces.SpacesBeforeColonLabel
    else
      Result := lcSpaces.SpacesBeforeColonLabel;
  end
  else if pt.HasParentNode(nAsm) then
  begin
    Result := 0; // !!!
  end
  else if pt.HasParentNode(nAttribute) then
  begin
    // Delphi.Net attribute
    Result := 0;
  end
  else if pt.HasParentNode(nGeneric) then
  begin
    Result:=0; //tricky parse tree in generic with const.
  end
  else
  begin
    Result := 0;
    // assertion failure brings the house down
    Assert(False, 'No context for colon ' + pt.DescribePosition);
  end;
end;


constructor TSpaceBeforeColon.Create;
begin
  inherited;
  FormatFlags := FormatFlags + [eAddSpace, eRemoveSpace];
end;

function TSpaceBeforeColon.EnabledVisitSourceToken(const pcNode: TObject): Boolean;
var
  lcSourceToken, lcPrev: TSourceToken;
  liSpaces: integer;
begin
  Result := False;
  if pcNode = nil then
    exit;

  lcSourceToken := TSourceToken(pcNode);

  if lcSourceToken.TokenType <> ttColon then
    exit;

  lcPrev := lcSourceToken.PriorToken;
  if lcPrev = nil then
    exit;

  liSpaces := SpacesBefore(lcSourceToken);

  if liSpaces > 0 then
  begin
    { modify the existing previous space, or make a new one? }
    if (lcPrev.TokenType = ttWhiteSpace) then
    begin
      lcPrev.SourceCode := StrRepeat(NativeSpace, liSpaces);
    end
    else
    begin
      Result := True;
      InsertTokenBefore(lcSourceToken, NewSpace(liSpaces));
    end;
  end
  else
  begin
    { remove the space }
    if (lcPrev.TokenType = ttWhiteSpace) then
    begin
      lcPrev.SourceCode := '';
    end
    { else we are already right }
  end;

end;

function TSpaceBeforeColon.IsIncludedInSettings: boolean;
begin
  Result := FormattingSettings.Spaces.FixSpacing;
end;

end.

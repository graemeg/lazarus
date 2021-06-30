unit RemoveReturnsAfterBegin;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is RemoveReturnsAfterBegin, released May 2003.
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

uses SourceToken, SwitchableVisitor;

type
  TRemoveReturnsAfterBegin = class(TSwitchableVisitor)
  protected
    function EnabledVisitSourceToken(const pcNode: TObject): Boolean; override;

  public
    constructor Create; override;

    function IsIncludedInSettings: boolean; override;
  end;

implementation

uses JcfSettings, Tokens, TokenUtils;

{ TRemoveReturnsAfterBegin }

constructor TRemoveReturnsAfterBegin.Create;
begin
  inherited;

end;

function TRemoveReturnsAfterBegin.EnabledVisitSourceToken(const pcNode: TObject): Boolean;
var
  lcSourceToken: TSourceToken;
  lcNext: TSourceToken;
  lcTest: TSourceToken;
  liReturnCount: integer;
  liMaxReturns: integer;
begin
  Result := False;
  lcSourceToken := TSourceToken(pcNode);

  if lcSourceToken.TokenType <> ttBegin then
    exit;

  if not InStatements(lcSourceToken) then
    exit;

  lcNext := lcSourceToken.NextTokenWithExclusions([ttWhiteSpace, ttReturn]);

  liReturnCount := 0;
  liMaxReturns := Succ(FormattingSettings.Returns.MaxBlankLinesInSection);
  lcTest := lcSourceToken;

  { remove all returns up to that point (except one) }
  while (lcTest <> lcNext) do
  begin
    if (lcTest.TokenType = ttReturn) then
    begin
      // allow two returns -> 1 blank line
      Inc(liReturnCount);
      if (liReturnCount > liMaxReturns) then
      begin
        BlankToken(lcTest);
      end;
    end;
    lcTest := lcTest.NextToken;
  end;
end;

function TRemoveReturnsAfterBegin.IsIncludedInSettings: boolean;
begin
  Result := FormattingSettings.Returns.RemoveBlockBlankLines;
end;

end.

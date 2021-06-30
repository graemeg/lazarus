unit ParseError;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is ParseError, released May 2003.
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
  SysUtils,
  { local }
  SourceToken;

type
  TEParseError = class(Exception)
  private
    fcToken: TSourceToken;
    fiXPosition, fiYPosition: integer;
    fsFileName: string;

    function GetTokenMessage: string;
  public
    constructor Create(const psMessage: string; const pcToken: TSourceToken);

    property FileName: string Read fsFileName Write fsFileName;
    property TokenMessage: string Read GetTokenMessage;
    property XPosition: integer Read fiXPosition;
    property YPosition: integer Read fiYPosition;

  end;

  procedure CheckNilPointer(aPtr:Pointer);
  procedure CheckNilInstance(aInstance: TObject; aLastValidToken: TObject);

implementation

procedure CheckNilPointer(aPtr:Pointer);
begin
  if aPtr=nil then
    raise TEParseError.Create('JCF Internal Error. Unexpected NIL pointer', nil);
end;

procedure CheckNilInstance(aInstance: TObject; aLastValidToken: TObject);
begin
  if not Assigned(AInstance) then
  begin
    if not (aLastValidToken is TSourceToken) then
    begin
      aLastValidToken := nil;
    end;
    raise TEParseError.Create('JCF Internal Error. Unexpected error in source code', TSourceToken(aLastValidToken));
  end;
end;

{ TEParseError }

constructor TEParseError.Create(const psMessage: string; const pcToken: TSourceToken);
begin
  inherited Create(psMessage);

  fcToken := pcToken;
  if pcToken <> nil then
  begin
    fiXPosition := pcToken.XPosition;
    fiYPosition := pcToken.YPosition;
  end
  else
  begin
    fiXPosition := -1;
    fiYPosition := -1;
  end;
end;

function TEParseError.GetTokenMessage: string;
begin
  if fcToken = nil then
    Result := ''
  else
    Result := fcToken.Describe;
end;

end.

unit WarnImbalancedComment;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code 

The Original Code is ImbalancedCommentAction, released Jun 2021.
The Initial Developer of the Original Code is Udo Sommer.
Portions created by Udo Sommer are Copyright (C) 2021 Udo Sommer.
All Rights Reserved. 
Contributor(s): Udo Sommer.

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
  Warning, ConvertTypes;

type
  { TImbalancedCommentAction }

  TWarnImbalancedComment = class(TWarning)
  private
    procedure SendWarning(const AError: TObject);
  protected
    function IsCurlyBreaketCommentBalanced(const pcNode: TObject): Boolean; virtual;
    function IsBreaketStarCommentBalanced(const pcNode: TObject): Boolean; virtual;
    procedure AssertCurlyBreaketCommentBalanced(const pcNode: TObject); virtual;
    procedure AssertBreaketStarCommentBalanced(const pcNode: TObject); virtual;

    function EnabledVisitSourceToken(const pcNode: TObject): Boolean; override;
  public
    constructor Create; override;

    function IsIncludedInSettings: boolean; override;

    property OnWarning;
  end;


implementation

uses
  SysUtils,
  //
  SourceToken,
  ParseError,
  Tokens,
  SetComments,
  JcfSettings
  //
  ;


constructor TWarnImbalancedComment.Create;
begin
  inherited;
end;

function TWarnImbalancedComment.IsCurlyBreaketCommentBalanced(const pcNode: TObject): Boolean;
var
  lcSourceToken: TSourceToken;
  iBalance: Integer;
  idx: Integer;
  cnt: Integer;
begin
  Result := True;
  lcSourceToken := pcNode as TSourceToken;

  iBalance := 0;
  cnt := Length(lcSourceToken.SourceCode);
  for idx := 1 to cnt do
  begin
    if '{' = lcSourceToken.SourceCode[idx] then
    begin
      Inc(iBalance);
    end else if '}' = lcSourceToken.SourceCode[idx] then
    begin
      Dec(iBalance);
    end;
  end;

  Result := 0 = iBalance;
end;

function TWarnImbalancedComment.IsBreaketStarCommentBalanced(const pcNode: TObject): Boolean;
var
  lcSourceToken: TSourceToken;
  iBalance: Integer;
  idx: Integer;
  cnt: Integer;
begin
  Result := True;
  lcSourceToken := pcNode as TSourceToken;

  iBalance := 0;
  cnt := Pred(Length(lcSourceToken.SourceCode));
  for idx := 1 to cnt do
  begin
    if ('(' = lcSourceToken.SourceCode[idx]) and ('*' = lcSourceToken.SourceCode[Succ(idx)]) then
    begin
      Inc(iBalance);
    end else if ('*' = lcSourceToken.SourceCode[idx]) and (')' = lcSourceToken.SourceCode[Succ(idx)]) then
    begin
      Dec(iBalance);
    end;
  end;

  Result := 0 = iBalance;
end;

procedure TWarnImbalancedComment.AssertCurlyBreaketCommentBalanced(const pcNode: TObject);
begin
  if not IsCurlyBreaketCommentBalanced(pcNode) then
  begin
    raise TEParseError.Create('Imbalanced curly breaket comment!', pcNode as TSourceToken);
  end;
end;

procedure TWarnImbalancedComment.AssertBreaketStarCommentBalanced(const pcNode: TObject);
begin
  if not IsBreaketStarCommentBalanced(pcNode) then
  begin
    raise TEParseError.Create('Imbalanced breaket star comment!', pcNode as TSourceToken);
  end;
end;

function TWarnImbalancedComment.EnabledVisitSourceToken(const pcNode: TObject): Boolean;
var
  lcSourceToken: TSourceToken;
begin
  Result := False;
  lcSourceToken := TSourceToken(pcNode);

  try
    case lcSourceToken.CommentStyle of
      eNotAComment, eDoubleSlash:
      begin
        // $ (US): 2021-06-28 10:51:06 $
        //  Double slash comment can not be imbalanced...
      end;
      eCurlyBrace, eCompilerDirective:
      begin
        AssertCurlyBreaketCommentBalanced(pcNode);
      end;
      eBracketStar:
      begin
        AssertBreaketStarCommentBalanced(pcNode);
      end;
    else
      begin
        // should not be here
        Assert(False);
      end;
    end;
  except
    on E: TEParseError do
    begin
      if TImbalancedCommentAction.Error = FormattingSettings.Comments.ImbalancedCommentAction then
      begin
        raise;
      end else if TImbalancedCommentAction.Warn = FormattingSettings.Comments.ImbalancedCommentAction then
      begin
        SendWarning(E);
      end;
    end else
    begin
      raise;
    end;
  end;
end;

function TWarnImbalancedComment.IsIncludedInSettings: boolean;
begin
  Result := True;
end;

procedure TWarnImbalancedComment.SendWarning(const AError: TObject);
var
  LError: TEPArseError;
begin
  LError := AError as TEPArseError;
  if not Assigned(OnWarning) then
  begin
    exit;
  end;
  OnWarning(LError.FileName, LError.Message, mtCodeWarning, LError.YPosition, LError.XPosition);
end;

end.

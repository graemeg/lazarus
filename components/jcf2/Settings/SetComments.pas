unit SetComments;

{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code

The Original Code is SetComments.pas, released November 2000.
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

{ options on working with comments
  For now only options to remove empty comments
  but there may be more  }

{$I JcfGlobal.inc}
{$SCOPEDENUMS ON}

interface

uses Classes, JcfSetBase, SettingsStream;

type
  TImbalancedCommentAction = (
    Error = 0,
    Warn
  );

const
  DEF_IMBALANCED_COMMENT_ACTION: UInt8 = Ord(TImbalancedCommentAction.Error);

type
  { TSetComments }

  TSetComments = class(TSetBase)
  private
    fbRemoveEmptyDoubleSlashComments: boolean;
    fbRemoveEmptyCurlyBraceComments: boolean;
    fImbalancedCommentAction: TImbalancedCommentAction;
  protected
  public
    constructor Create;

    procedure WriteToStream(const pcOut: TSettingsOutput); override;
    procedure ReadFromStream(const pcStream: TSettingsInput); override;

    procedure GetImbalancedCommentActions(const AValues: TStrings);

    property RemoveEmptyDoubleSlashComments: boolean
      Read fbRemoveEmptyDoubleSlashComments Write fbRemoveEmptyDoubleSlashComments;
    property RemoveEmptyCurlyBraceComments: boolean
      Read fbRemoveEmptyCurlyBraceComments Write fbRemoveEmptyCurlyBraceComments;
    property ImbalancedCommentAction: TImbalancedCommentAction
      Read fImbalancedCommentAction Write fImbalancedCommentAction;
  end;

implementation

uses
  TypInfo;

const
  REG_REMOVE_EMPTY_DOUBLE_SLASH_COMMENTS = 'RemoveEmptyDoubleSlashComments';
  REG_REMOVE_EMPTY_CURLY_BRACE_COMMENTS  = 'RemoveEmptyCurlyBraceComments';
  REG_IMBALANCED_COMMENT_ACTION          = 'ImbalancedCommentAction';

constructor TSetComments.Create;
begin
  inherited;
  SetSection('Comments');
end;

procedure TSetComments.ReadFromStream(const pcStream: TSettingsInput);
var
  s: string;
begin
  Assert(pcStream <> nil);

  fbRemoveEmptyDoubleSlashComments :=
    pcStream.Read(REG_REMOVE_EMPTY_DOUBLE_SLASH_COMMENTS, True);
  fbRemoveEmptyCurlyBraceComments  :=
    pcStream.Read(REG_REMOVE_EMPTY_CURLY_BRACE_COMMENTS, True);

  s := pcStream.Read(REG_IMBALANCED_COMMENT_ACTION,
    GetEnumName(TypeInfo(TImbalancedCommentAction), DEF_IMBALANCED_COMMENT_ACTION));
  fImbalancedCommentAction         :=
    TImbalancedCommentAction(GetEnumValue(TypeInfo(TImbalancedCommentAction), s));
end;

procedure TSetComments.GetImbalancedCommentActions(const AValues: TStrings);
var
  iter: TImbalancedCommentAction;
begin
  Assert(Assigned(AValues));
  AValues.Clear();

  for iter := Low(TImbalancedCommentAction) to High(TImbalancedCommentAction) do
  begin
    AValues.Add(GetEnumName(TypeInfo(TImbalancedCommentAction), Ord(iter)));
  end;
end;

procedure TSetComments.WriteToStream(const pcOut: TSettingsOutput);
begin
  Assert(pcOut <> nil);

  pcOut.Write(REG_REMOVE_EMPTY_DOUBLE_SLASH_COMMENTS, fbRemoveEmptyDoubleSlashComments);
  pcOut.Write(REG_REMOVE_EMPTY_CURLY_BRACE_COMMENTS, fbRemoveEmptyCurlyBraceComments);
  pcOUt.Write(REG_IMBALANCED_COMMENT_ACTION,
    GetEnumName(TypeInfo(TImbalancedCommentAction), Ord(fImbalancedCommentAction)));
end;

end.

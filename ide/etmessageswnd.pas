{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************

  Author: Mattias Gaertner

  Abstract:
    Window for (compiler) messages.
}
unit etMessagesWnd;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  Forms, Controls, Graphics, Dialogs,
  // BuildIntf
  IDEExternToolIntf,
  // IdeIntf
  IDEMsgIntf, LazIDEIntf,
  // SynEdit
  SynEditMarks,
  // IDE
  IDEOptionDefs, etMessageFrame, etQuickFixes, LazarusIDEStrConsts;

type

  { TMessagesView }

  TMessagesView = class(TIDEMessagesWindowInterface)
    MessagesFrame1: TMessagesFrame;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure OnMsgCtrlOptsChanged(Sender: TObject);
    function OnOpenMessage(Sender: TObject; Msg: TMessageLine): boolean;
  private
    function GetDblClickJumps: boolean;
    function GetShowMessagesIcons: boolean;
    procedure SetDblClickJumps(AValue: boolean);
    procedure SetShowMessagesIcons(AValue: boolean);
  protected
    function GetViews(Index: integer): TExtToolView; override;
  public
    // views
    procedure Clear; override;
    procedure DeleteView(View: TExtToolView); override;
    function FindUnfinishedView: TExtToolView; override;
    function GetSelectedLine: TMessageLine; override;
    function GetView(aCaption: string; CreateIfNotExist: boolean
      ): TExtToolView; override;
    function ViewCount: integer; override;
    function CreateView(aCaptionPrefix: string): TExtToolView; override;
    function IndexOfView(View: TExtToolView): integer; override;

    // lines
    procedure SelectMsgLine(Msg: TMessageLine); override;
    function SelectFirstUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos: boolean): boolean; override;
    function SelectNextUrgentMessage(aMinUrgency: TMessageLineUrgency;
      WithSrcPos, Downwards: boolean): boolean; override;
    procedure ClearCustomMessages(const ViewCaption: string='');
    function AddCustomMessage(TheUrgency: TMessageLineUrgency; Msg: string;
      aSrcFilename: string=''; LineNumber: integer=0; Column: integer=0;
      const ViewCaption: string=''): TMessageLine; override;

    // misc
    procedure SourceEditorPopup(MarkLine: TSynEditMarkLine; const LogicalCaretXY: TPoint);
    procedure SourceEditorHint(MarkLine: TSynEditMarkLine; var HintStr: string);

    // options
    procedure ApplyIDEOptions;
    property DblClickJumps: boolean read GetDblClickJumps write SetDblClickJumps;
    property ShowMessagesIcons: boolean read GetShowMessagesIcons write SetShowMessagesIcons;
  end;

var
  MessagesView: TMessagesView;

implementation

{$R *.lfm}

{ TMessagesView }

procedure TMessagesView.FormCreate(Sender: TObject);
begin
  Name := NonModalIDEWindowNames[nmiwMessagesView];
  IDEMessagesWindow:=Self;
  Caption:=lisMenuViewMessages;
  {$IFNDEF LCLGtk2}
  try
    Icon.LoadFromResourceName(HInstance, 'WIN_MESSAGES');
  except
  end;
  {$ENDIF}
  MessagesFrame1.MessagesCtrl.OnOpenMessage:=@OnOpenMessage;
  MessagesFrame1.MessagesCtrl.OnOptionsChanged:=@OnMsgCtrlOptsChanged;

  ActiveControl:=MessagesFrame1.MessagesCtrl;
end;

procedure TMessagesView.FormDestroy(Sender: TObject);
begin
  IDEMessagesWindow:=nil;
end;

procedure TMessagesView.OnMsgCtrlOptsChanged(Sender: TObject);
begin
  if mcoWndStayOnTop in MessagesFrame1.MessagesCtrl.Options then
    FormStyle:=fsStayOnTop
  else
    FormStyle:=fsNormal;
end;

function TMessagesView.OnOpenMessage(Sender: TObject; Msg: TMessageLine): boolean;
begin
  Result:=false;
  // ask quickfixes
  if IDEQuickFixes.OpenMsg(Msg) then exit(true);
  if Msg.GetFullFilename<>'' then begin
    // open file in source editor and mark it as error
    Result:=LazarusIDE.DoJumpToCompilerMessage(true,Msg);
  end;
end;

procedure TMessagesView.SetDblClickJumps(AValue: boolean);
begin
  if AValue then
    MessagesFrame1.MessagesCtrl.Options:=
      MessagesFrame1.MessagesCtrl.Options-[mcoSingleClickOpensFile]
  else
    MessagesFrame1.MessagesCtrl.Options:=
      MessagesFrame1.MessagesCtrl.Options+[mcoSingleClickOpensFile]
end;

procedure TMessagesView.SetShowMessagesIcons(AValue: boolean);
begin
  if AValue then
    MessagesFrame1.MessagesCtrl.Options:=MessagesFrame1.MessagesCtrl.Options+[mcoShowMsgIcons]
  else
    MessagesFrame1.MessagesCtrl.Options:=MessagesFrame1.MessagesCtrl.Options-[mcoShowMsgIcons];
end;

function TMessagesView.GetViews(Index: integer): TExtToolView;
begin
  Result:=MessagesFrame1.Views[Index];
end;

procedure TMessagesView.ClearCustomMessages(const ViewCaption: string);
begin
  MessagesFrame1.ClearCustomMessages(ViewCaption);
end;

function TMessagesView.AddCustomMessage(TheUrgency: TMessageLineUrgency;
  Msg: string; aSrcFilename: string; LineNumber: integer; Column: integer;
  const ViewCaption: string): TMessageLine;
begin
  Result:=MessagesFrame1.AddCustomMessage(TheUrgency,Msg,aSrcFilename,
    LineNumber,Column,ViewCaption);
end;

procedure TMessagesView.SourceEditorPopup(MarkLine: TSynEditMarkLine;
  const LogicalCaretXY: TPoint);
begin
  MessagesFrame1.SourceEditorPopup(MarkLine,LogicalCaretXY);
end;

procedure TMessagesView.SourceEditorHint(MarkLine: TSynEditMarkLine;
  var HintStr: string);
begin
  MessagesFrame1.SourceEditorHint(MarkLine,HintStr);
end;

procedure TMessagesView.Clear;
begin
  MessagesFrame1.ClearViews(true);
end;

procedure TMessagesView.DeleteView(View: TExtToolView);
begin
  if View is TLMsgWndView then
    MessagesFrame1.DeleteView(TLMsgWndView(View));
end;

function TMessagesView.FindUnfinishedView: TExtToolView;
begin
  Result:=MessagesFrame1.FindUnfinishedView;
end;

function TMessagesView.GetSelectedLine: TMessageLine;
begin
  Result:=MessagesFrame1.MessagesCtrl.GetSelectedMsg;
end;

function TMessagesView.GetView(aCaption: string; CreateIfNotExist: boolean
  ): TExtToolView;
begin
  Result:=MessagesFrame1.GetView(aCaption,CreateIfNotExist);
end;

function TMessagesView.CreateView(aCaptionPrefix: string): TExtToolView;

  function TryCaption(aCaption: string; var View: TExtToolView): boolean;
  begin
    if GetView(aCaption,false)<>nil then exit(false);
    View:=GetView(aCaption,true);
    Result:=true;
  end;

var
  i: Integer;
begin
  Result:=nil;
  if TryCaption(aCaptionPrefix,Result) then exit;
  if (aCaptionPrefix<>'') and (aCaptionPrefix[length(aCaptionPrefix)] in ['0'..'9'])
  then
    aCaptionPrefix+='_';
  i:=2;
  repeat
    if TryCaption(aCaptionPrefix+IntToStr(i),Result) then exit;
    inc(i);
  until false;
end;

function TMessagesView.IndexOfView(View: TExtToolView): integer;
begin
  if View is TLMsgWndView then
    Result:=MessagesFrame1.IndexOfView(TLMsgWndView(View))
  else
    Result:=-1;
end;

procedure TMessagesView.SelectMsgLine(Msg: TMessageLine);
begin
  MessagesFrame1.SelectMsgLine(Msg,true);
end;

function TMessagesView.SelectFirstUrgentMessage(
  aMinUrgency: TMessageLineUrgency; WithSrcPos: boolean): boolean;
begin
  Result:=MessagesFrame1.SelectFirstUrgentMessage(aMinUrgency,WithSrcPos);
end;

function TMessagesView.SelectNextUrgentMessage(
  aMinUrgency: TMessageLineUrgency; WithSrcPos, Downwards: boolean): boolean;
begin
  Result:=MessagesFrame1.SelectNextUrgentMessage(aMinUrgency,WithSrcPos,Downwards);
end;

function TMessagesView.ViewCount: integer;
begin
  Result:=MessagesFrame1.ViewCount;
end;

procedure TMessagesView.ApplyIDEOptions;
begin
  MessagesFrame1.ApplyIDEOptions;
  OnMsgCtrlOptsChanged(Self);
end;

function TMessagesView.GetDblClickJumps: boolean;
begin
  Result:=not (mcoSingleClickOpensFile in MessagesFrame1.MessagesCtrl.Options);
end;

function TMessagesView.GetShowMessagesIcons: boolean;
begin
  Result:=mcoShowMsgIcons in MessagesFrame1.MessagesCtrl.Options;
end;

end.


unit LazSynIMMBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Messages, SynEditMiscClasses, SynEditPointClasses;

type

  { LazSynIme }

  LazSynIme = class(TSynEditFriend)
  private
    FInvalidateLinesMethod: TInvalidateLines;
    FOnIMEEnd: TNotifyEvent;
    FOnIMEStart: TNotifyEvent;
    FIMEActive: Boolean;
  protected
    FInCompose: Boolean;
    procedure InvalidateLines(FirstLine, LastLine: integer);
    procedure StopIme(Success: Boolean); virtual;
    procedure DoIMEStarted;
    procedure DoIMEEnded;
  public
    constructor Create(AOwner: TSynEditBase); reintroduce;
    procedure WMImeRequest(var Msg: TMessage); virtual;
    procedure WMImeNotify(var Msg: TMessage); virtual;
    procedure WMImeComposition(var Msg: TMessage); virtual;
    procedure WMImeStartComposition(var Msg: TMessage); virtual;
    procedure WMImeEndComposition(var Msg: TMessage); virtual;
    procedure FocusKilled; virtual;
    property InvalidateLinesMethod : TInvalidateLines write FInvalidateLinesMethod;
    property OnIMEStart: TNotifyEvent read FOnIMEStart write FOnIMEStart;
    property OnIMEEnd: TNotifyEvent read FOnIMEEnd write FOnIMEEnd;
  end;

implementation

{ LazSynIme }

procedure LazSynIme.InvalidateLines(FirstLine, LastLine: integer);
begin
  FInvalidateLinesMethod(FirstLine, LastLine);
end;

procedure LazSynIme.StopIme(Success: Boolean);
begin
  DoIMEEnded;
end;

procedure LazSynIme.DoIMEStarted;
begin
  if FIMEActive then
    exit;
  FIMEActive := True;
  if FOnIMEStart <> nil then
    FOnIMEStart(FriendEdit);
end;

procedure LazSynIme.DoIMEEnded;
begin
  if not FIMEActive then
    exit;
  FIMEActive := False;
  if FOnIMEEnd <> nil then
    FOnIMEEnd(FriendEdit);
end;

constructor LazSynIme.Create(AOwner: TSynEditBase);
begin
  FriendEdit := AOwner;
end;

procedure LazSynIme.WMImeRequest(var Msg: TMessage);
begin
end;

procedure LazSynIme.WMImeComposition(var Msg: TMessage);
begin
end;

procedure LazSynIme.WMImeNotify(var Msg: TMessage);
begin
end;

procedure LazSynIme.WMImeStartComposition(var Msg: TMessage);
begin
end;

procedure LazSynIme.WMImeEndComposition(var Msg: TMessage);
begin
end;

procedure LazSynIme.FocusKilled;
begin
end;

end.


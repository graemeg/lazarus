unit PQTEventMonitor;

{$mode objfpc}{$H+}

interface

uses
  Classes,PQEventMonitor,ExtCtrls;


type

  { TPQTEventMonitor }

  TPQTEventMonitor=class(TPQEventMonitor)
  private
    FInited:Boolean;
    Timer:TTimer;
    function GetPollInterval: integer;
    procedure OnTimer(Sender: TObject);
    procedure SetPollInterval(AValue: integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure RegisterEvents; override;
    procedure UnRegisterEvents; override;
  published
    property PollInterval:integer read GetPollInterval write SetPollInterval default 500;
  end;

implementation


{ TPQTEventMonitor }

procedure TPQTEventMonitor.SetPollInterval(AValue: integer);
begin
  Timer.Interval:=AValue;
end;

function TPQTEventMonitor.GetPollInterval: integer;
begin
  result:=Timer.Interval;
end;

procedure TPQTEventMonitor.OnTimer(Sender: TObject);
begin
  Poll;
end;

constructor TPQTEventMonitor.Create(AOwner: TComponent);
begin
  try
    inherited Create(AOwner);
    FInited:=true;
  except
    //FPC code raises EInOutError in Create() if Postgres lib was not loaded
    FInited:=false;
  end;
  Timer:=TTimer.Create(self);
  Timer.Interval:=500;
  Timer.Enabled:=false;
  Timer.OnTimer:=@OnTimer;
end;

destructor TPQTEventMonitor.Destroy;
begin
  if not FInited then exit;
  inherited Destroy;
end;

procedure TPQTEventMonitor.RegisterEvents;
begin
  if not FInited then exit;
  inherited RegisterEvents;
  Timer.Enabled:=true;
end;

procedure TPQTEventMonitor.UnRegisterEvents;
begin
  if not FInited then exit;
  Timer.Enabled:=false;
  inherited UnRegisterEvents;
end;

end.


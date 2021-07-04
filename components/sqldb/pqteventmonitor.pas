unit PQTEventMonitor;

{$mode objfpc}{$H+}

interface

uses
  Classes,PQEventMonitor,ExtCtrls;


type

  { TPQTEventMonitor }

  TPQTEventMonitor=class(TPQEventMonitor)
  private
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
  if Timer.Interval=AValue then Exit;
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
  inherited Create(AOwner);
  Timer:=TTImer.Create(self);
  Timer.Interval:=500;
  Timer.Enabled:=false;
  Timer.OnTimer:=@OnTimer;
end;

destructor TPQTEventMonitor.Destroy;
begin
  inherited Destroy;
end;

procedure TPQTEventMonitor.RegisterEvents;
begin
  inherited RegisterEvents;
  Timer.Enabled:=true;
end;

procedure TPQTEventMonitor.UnRegisterEvents;
begin
  Timer.Enabled:=false;
  inherited UnRegisterEvents;
end;

end.


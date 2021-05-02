{
  ./runtestscodetools --format=plain --suite=TestFindDeclaration_Generics
}
unit fdt_generics;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  generic TGenBaseAction<GenParam1> = class
  var
    BaseName: GenParam1{declaration:fdt_generics.TGenBaseAction.GenParam1};
  end;

  generic TGenCustomAction<GenParam2> = class(specialize TGenBaseAction{declaration:fdt_generics.TGenBaseAction}<GenParam2>)
    CustomName: GenParam2;
  end;

  { TGenAction }

  generic TGenAction<GenParam3> = class(specialize TGenCustomAction{declaration:fdt_generics.TGenCustomAction}<GenParam3>)
    ActionName: GenParam3;
    procedure InitActionName;
  end;

  TIntegerAction = specialize TGenAction<integer>;

implementation

procedure DoSomething;
var
  Action: TIntegerAction;
begin
  Action.ActionName{declaration:fdt_generics.TGenAction.ActionName}:=3;
end;

{ TGenAction }

procedure TGenAction.InitActionName;
begin
  ActionName{declaration:fdt_generics.TGenAction.ActionName}:=3;
end;

end.


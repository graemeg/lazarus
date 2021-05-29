unit FpDbgCallContextInfo;

{$mode objfpc}{$H+}

interface

uses
  DbgIntfBaseTypes,
  FpDbgInfo,
  FpdMemoryTools,
  FpDbgDwarfDataClasses,
  FpDbgDwarf,
  FpDbgClasses;

type
  { TFpDbgInfoCallContext }

  TFpDbgInfoCallContext = class(TFpDbgAbstractCallContext)
  public
    function CreateParamSymbol(AParamIndex: Integer; ASymbolType: TFpSymbol; ADbgProcess: TDbgProcess; AName: String = ''): TFpValue; virtual;
  end;

implementation

{ TFpDbgInfoCallContext }

function TFpDbgInfoCallContext.CreateParamSymbol(AParamIndex: Integer;
  ASymbolType: TFpSymbol; ADbgProcess: TDbgProcess; AName: String): TFpValue;
var
  ParameterMemLocation: TFpDbgMemLocation;
  TypeSymbol: TFpSymbol;
  ParamSymbol: TFpSymbolDwarfFunctionResult;
begin
  ParameterMemLocation := ADbgProcess.CallParamDefaultLocation(AParamIndex);
  TypeSymbol := ASymbolType.TypeInfo;
  if AName = '' then
    AName := ASymbolType.Name;
  ParamSymbol := TFpSymbolDwarfFunctionResult.Create(AName, TDbgDwarfSymbolBase(ASymbolType).InformationEntry, TypeSymbol.Kind, ParameterMemLocation);
  try
    Result := ParamSymbol.Value;
  finally
    ParamSymbol.ReleaseReference;
  end;
  TFpValueDwarf(Result).Context := Self;
end;

end.


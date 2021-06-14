unit TestTypeInfo;

{$mode objfpc}{$H+}

interface

uses
  FpPascalParser, FpDbgDwarf, FpDbgInfo, FpdMemoryTools, FpErrorMessages,
  FpDbgLoader, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8, sysutils, fpcunit, testregistry,
  TestHelperClasses, TestDwarfSetup1, TestDwarfSetupBasic, DbgIntfBaseTypes,
  TestDwarfSetupArray;


type

  TTestFlag = (ttHasType, ttNotHasType, ttHasSymbol, ttHasValSymbol, ttHasTypeSymbol);
  TTestFlags = set of TTestFlag;

  { TTestTypeInfo }

  TTestTypeInfo = class(TTestCase)
  protected
    FDwarfInfo: TFpDwarfInfo;
    FCurrentTestName: String;
    FCurrentContext: TFpDbgSymbolScope;
    FExpression: TFpPascalExpression;
    FImageLoader: TTestDummyImageLoader;
    FImageLoaderList: TDbgImageLoaderList;
    FMemReader: TTestMemReader;
    FMemManager: TFpDbgMemManager;

    procedure AssertEqualsQW(const AMessage: string; Expected, Actual: QWord);

    procedure ExpTestFlags(AVal: TFpValue; ATestFlags: TTestFlags = []);
    procedure ExpKind(AVal: TFpValue; AExpKind: TDbgSymbolKind; TestFlags: TTestFlags = []);
    procedure ExpFlags(AVal: TFpValue; AExpFlags: TFpValueFieldFlags; ExpNotFlags: TFpValueFieldFlags = []);
    procedure ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag; ExpValue: QWord);
    procedure ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag; ExpValue: Int64);
    procedure ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag; ExpValue: Boolean);
    procedure ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag; ExpValue: String);
    procedure ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag; ExpValue: WideString);
    procedure ExpMemberCount(AVal: TFpValue; ExpValue: Integer);

    procedure ExpFlags(AExpFlags: TFpValueFieldFlags; ExpNotFlags: TFpValueFieldFlags = []);
    procedure ExpResult(Field: TFpValueFieldFlag; ExpValue: QWord);
    procedure ExpResult(Field: TFpValueFieldFlag; ExpValue: Int64);
    procedure ExpResult(Field: TFpValueFieldFlag; ExpValue: Boolean);
    procedure ExpResult(Field: TFpValueFieldFlag; ExpValue: String);
    procedure ExpResult(Field: TFpValueFieldFlag; ExpValue: WideString);
    procedure ExpMemberCount(ExpValue: Integer);

    procedure InitTest(Expr: String; ExtraName: String = '');
    procedure StartTest(Expr: String; TestFlags: TTestFlags = []; ExtraName: String = '');
    procedure StartTest(Expr: String; AExpKind: TDbgSymbolKind; TestFlags: TTestFlags = []; ExtraName: String = '');
    procedure StartInvalTest(Expr: String; ExpError: String; ExtraName: String = '');

    procedure InitDwarf(ALoaderClass: TTestDummyImageLoaderClass);
  public
    procedure SetUp; override;
    procedure TearDown; override;
  published
    Procedure TestExpressionInt;
    Procedure TestExpressionBool;
    Procedure TestExpressionEnumAndSet;
    Procedure TestExpressionArray;
    Procedure TestExpressionStructures;
  end;

implementation

procedure TTestTypeInfo.AssertEqualsQW(const AMessage: string; Expected, Actual: QWord);
begin
  AssertTrue(AMessage + ComparisonMsg(IntToStr(Expected), IntToStr(Actual)), Expected = Actual);
end;

procedure TTestTypeInfo.ExpTestFlags(AVal: TFpValue; ATestFlags: TTestFlags);
var
  i: TTestFlag;
begin
  for i := low(TTestFlags) to high(TTestFlags) do
    if i in ATestFlags then
      case i of
        ttHasType:      AssertTrue(FCurrentTestName + 'hastype', AVal.TypeInfo <> nil);
        ttNotHasType:   AssertTrue(FCurrentTestName + 'has not type', AVal.TypeInfo = nil);
        ttHasSymbol:    AssertTrue(FCurrentTestName + 'hassymbol', AVal.DbgSymbol <> nil);
        ttHasValSymbol: AssertTrue(FCurrentTestName + 'hassymbol', (AVal.DbgSymbol <> nil) and
                                                (AVal.DbgSymbol.SymbolType = stValue));
        ttHasTypeSymbol: AssertTrue(FCurrentTestName + 'hassymbol', (AVal.DbgSymbol <> nil) and
                                                 (AVal.DbgSymbol.SymbolType = stType));
      end;
end;

procedure TTestTypeInfo.ExpKind(AVal: TFpValue; AExpKind: TDbgSymbolKind;
  TestFlags: TTestFlags);
var
  s: String;
begin
  WriteStr(s, FCurrentTestName, 'Kind exected ', AExpKind, ' but was ', AVal.Kind);
  AssertTrue(s, AVal.Kind = AExpKind);
  ExpTestFlags(AVal, TestFlags);
  if (ttHasType in TestFlags) and (AExpKind <> skNone) then begin
    WriteStr(s, FCurrentTestName, 'typeinfo.Kind exected ', AExpKind, ' but was ', AVal.TypeInfo.Kind);
    AssertTrue(s, AVal.TypeInfo.Kind = AExpKind);
  end;

  // some general assumptions
  s := FCurrentTestName;
  WriteStr(FCurrentTestName, s, ' Expecting for kind:', AExpKind);
  case AExpKind of
    skInstance: ;
    skUnit: ;
    skRecord:    ExpFlags(AVal, [svfMembers], [svfOrdinal, svfInteger, svfCardinal, svfDataAddress, svfDataSize, svfIdentifier]);
    skObject:    ExpFlags(AVal, [svfMembers], [svfOrdinal, svfInteger, svfCardinal, svfDataAddress, svfDataSize, svfIdentifier]);
    // skClass does NOT have svfSize (maybe svfSizeOfPointer ?);
    skClass:     ExpFlags(AVal, [svfOrdinal, svfMembers, svfDataAddress, svfDataSize], [svfSize, svfInteger, svfCardinal]);
    skInterface: ;
    skProcedure: ;
    skFunction: ;
    skProcedureRef: ;
    skFunctionRef: ;
    skArray: ;
    // skPointer: svfOrdinal, svfCardinal, svfDataAddress are all the same value
    skPointer:   ExpFlags(AVal, [svfOrdinal, svfCardinal, svfDataAddress, svfSizeOfPointer], [svfMembers, svfIdentifier]);
    skInteger:   ExpFlags(AVal, [svfOrdinal, svfInteger], [svfDataAddress, svfDataSize, svfMembers, svfIdentifier]);
    skCardinal:  ExpFlags(AVal, [svfOrdinal, svfCardinal], [svfDataAddress, svfDataSize, svfMembers, svfIdentifier]);
    skBoolean:   ExpFlags(AVal, [svfOrdinal, svfBoolean], [svfSizeOfPointer, svfDataAddress, svfDataSize, svfMembers, svfIdentifier]);
    skChar: ;
    skFloat: ;
    skString: ;
    skAnsiString: ;
    skCurrency: ;
    skVariant: ;
    skWideString: ;
    skEnum:      ExpFlags(AVal, [svfOrdinal, svfIdentifier, svfMembers, svfSize], [svfCardinal, svfString, svfDataAddress, svfDataSize, svfDataSizeOfPointer]);
    skEnumValue: ExpFlags(AVal, [svfOrdinal, svfIdentifier], [svfCardinal, svfString, svfMembers, svfAddress, svfSize, svfDataAddress, svfDataSize, svfDataSizeOfPointer]);
    skSet: ;
    skRegister: ;
  end;
  FCurrentTestName := s;
end;

procedure TTestTypeInfo.ExpFlags(AVal: TFpValue; AExpFlags: TFpValueFieldFlags;
  ExpNotFlags: TFpValueFieldFlags);
var
  i: TFpValueFieldFlag;
  s: string;
  f: TFpValueFieldFlags;
begin
  AssertTrue(FCurrentTestName + 'has ResVal', AVal <> nil);
  f := AVal.FieldFlags;
  For i := low(TFpValueFieldFlag) to High(TFpValueFieldFlag) do
    if i in AExpFlags then begin
      WriteStr(s, i);
      AssertTrue(FCurrentTestName + 'Has flag' + s, i in f);
    end;
  For i := low(TFpValueFieldFlag) to High(TFpValueFieldFlag) do
    if i in ExpNotFlags then begin
      WriteStr(s, i);
      AssertTrue(FCurrentTestName + 'Has NOT flag' + s, not (i in f));
    end;
end;

procedure TTestTypeInfo.ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag;
  ExpValue: QWord);
var
  s: string;
  sz: TFpDbgValueSize;
begin
  ExpFlags([Field]);
  WriteStr(s, FCurrentTestName, Field);
  case Field of
    svfAddress:           AssertEqualsQW('VAlue for '+s, ExpValue, LocToAddrOrNil(AVal.Address));
    svfSize:            begin
                          AVal.GetSize(sz);
                          AssertEqualsQW('VAlue for '+s, ExpValue, sz.Size);
                        end;
    svfDataAddress:       AssertEqualsQW('VAlue for '+s, ExpValue, LocToAddrOrNil(AVal.DataAddress));
    svfDataSize:        begin
                          AssertEqualsQW('VAlue for '+s, ExpValue, AVal.DataSize.Size);
                        end;
    svfInteger:           AssertEqualsQW('VAlue for '+s, ExpValue, AVal.AsInteger);
    svfCardinal:          AssertEqualsQW('VAlue for '+s, ExpValue, AVal.AsCardinal);
    svfOrdinal:           AssertEqualsQW('VAlue for '+s, ExpValue, AVal.AsCardinal);
    else                  AssertTrue('No test method avail', False);
  end;
end;

procedure TTestTypeInfo.ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag;
  ExpValue: Int64);
var
  s: string;
  sz: TFpDbgValueSize;
begin
  ExpFlags([Field]);
  WriteStr(s, FCurrentTestName, Field);
  case Field of
    svfAddress:           AssertEquals('VAlue for '+s, ExpValue, LocToAddrOrNil(AVal.Address));
    svfSize:            begin
                          AVal.GetSize(sz);
                          AssertEquals('VAlue for '+s, ExpValue, sz.Size);
                        end;
    svfDataAddress:       AssertEquals('VAlue for '+s, ExpValue, LocToAddrOrNil(AVal.DataAddress));
    svfDataSize:          AssertEquals('VAlue for '+s, ExpValue, AVal.DataSize.Size);
    svfInteger:           AssertEquals('VAlue for '+s, ExpValue, AVal.AsInteger);
    svfCardinal:          AssertEquals('VAlue for '+s, ExpValue, AVal.AsCardinal);
    svfOrdinal:           AssertEquals('VAlue for '+s, ExpValue, AVal.AsCardinal);
    else                  AssertTrue('No test method avail', False);
  end;
end;

procedure TTestTypeInfo.ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag;
  ExpValue: Boolean);
var
  s: string;
begin
  ExpFlags([Field]);
  WriteStr(s, FCurrentTestName, Field);
  case Field of
    svfBoolean:           AssertEquals('VAlue for '+s, ExpValue, AVal.AsBool);
    else                  AssertTrue('No test method avail', False);
  end;
end;

procedure TTestTypeInfo.ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag;
  ExpValue: String);
var
  s: string;
begin
  ExpFlags([Field]);
  WriteStr(s, FCurrentTestName, Field);
  case Field of
    svfString:            AssertEquals('VAlue for '+s, UpperCase(ExpValue), UpperCase(AVal.AsString));
    svfIdentifier:        AssertEquals('VAlue for '+s, UpperCase(ExpValue), UpperCase(AVal.AsString));
    else                  AssertTrue('No test method avail', False);
  end;
end;

procedure TTestTypeInfo.ExpResult(AVal: TFpValue; Field: TFpValueFieldFlag;
  ExpValue: WideString);
var
  s: string;
begin
  ExpFlags([Field]);
  WriteStr(s, FCurrentTestName, Field);
  case Field of
    svfWideString:        AssertEquals('VAlue for '+s, ExpValue, AVal.AsWideString);
    else                  AssertTrue('No test method avail', False);
  end;
end;

procedure TTestTypeInfo.ExpMemberCount(AVal: TFpValue; ExpValue: Integer);
begin
  ExpFlags([svfMembers]);
  AssertEquals(FCurrentTestName+'MemberCount', ExpValue, AVal.MemberCount);
end;

procedure TTestTypeInfo.ExpFlags(AExpFlags: TFpValueFieldFlags;
  ExpNotFlags: TFpValueFieldFlags);
begin
  ExpFlags(FExpression.ResultValue, AExpFlags, ExpNotFlags);
end;

procedure TTestTypeInfo.ExpResult(Field: TFpValueFieldFlag; ExpValue: QWord);
begin
  ExpResult(FExpression.ResultValue, Field, ExpValue);
end;

procedure TTestTypeInfo.ExpResult(Field: TFpValueFieldFlag; ExpValue: Int64);
begin
  ExpResult(FExpression.ResultValue, Field, ExpValue);
end;

procedure TTestTypeInfo.ExpResult(Field: TFpValueFieldFlag; ExpValue: Boolean);
begin
  ExpResult(FExpression.ResultValue, Field, ExpValue);
end;

procedure TTestTypeInfo.ExpResult(Field: TFpValueFieldFlag; ExpValue: String);
begin
  ExpResult(FExpression.ResultValue, Field, ExpValue);
end;

procedure TTestTypeInfo.ExpResult(Field: TFpValueFieldFlag; ExpValue: WideString);
begin
  ExpResult(FExpression.ResultValue, Field, ExpValue);
end;

procedure TTestTypeInfo.ExpMemberCount(ExpValue: Integer);
begin
  ExpMemberCount(FExpression.ResultValue, ExpValue);
end;

procedure TTestTypeInfo.InitTest(Expr: String; ExtraName: String);
begin
  if ExtraName <> '' then ExtraName := ' (' + ExtraName + ')';
  FCurrentTestName := Expr + ExtraName + ': ';
  FExpression.Free;
  FExpression := TFpPascalExpression.Create(Expr, FCurrentContext);
//debugln(Expression.DebugDump);
end;

procedure TTestTypeInfo.StartTest(Expr: String; TestFlags: TTestFlags; ExtraName: String);
begin
  InitTest(Expr, ExtraName);
  AssertTrue(FCurrentTestName + 'valid', FExpression.Valid);
  AssertTrue(FCurrentTestName + 'has ResVal', FExpression.ResultValue <> nil);
  ExpTestFlags(FExpression.ResultValue, TestFlags);
end;

procedure TTestTypeInfo.StartTest(Expr: String; AExpKind: TDbgSymbolKind;
  TestFlags: TTestFlags; ExtraName: String);
var
  s: String;
begin
  StartTest(Expr, TestFlags, ExtraName);
  ExpKind(FExpression.ResultValue, AExpKind, TestFlags);
end;

procedure TTestTypeInfo.StartInvalTest(Expr: String; ExpError: String; ExtraName: String);
begin
  InitTest(Expr, ExtraName);
  if FExpression.ResultValue <> nil then begin // some value are only invalid after accessing the data
    FExpression.ResultValue.AsInteger;
    FExpression.ResultValue.AsCardinal;
  end;
  AssertTrue(FCurrentTestName + 'invalid',
             (not FExpression.Valid) or (FExpression.ResultValue = nil) or
             (IsError(FExpression.ResultValue.LastError))
            );
  //AssertTrue(CurrentTestName + 'invalid', (not Expression.Valid));
  //ExpError
end;

procedure TTestTypeInfo.InitDwarf(ALoaderClass: TTestDummyImageLoaderClass);
begin
  FImageLoader := ALoaderClass.Create;
  FImageLoaderList := TDbgImageLoaderList.Create(True);
  FImageLoaderList.Add(FImageLoader);
  FMemReader := TTestMemReader.Create;
  FMemManager := TFpDbgMemManager.Create(FMemReader, TFpDbgMemConvertorLittleEndian.Create);
  FDwarfInfo := TFpDwarfInfo.Create(FImageLoaderList, FMemManager);
  FDwarfInfo.LoadCompilationUnits;
end;

procedure TTestTypeInfo.SetUp;
begin
  inherited SetUp;
  FImageLoader     := nil;
  FImageLoaderList := nil;
  FMemReader       := nil;
  FMemManager      := nil;
  FDwarfInfo       := nil;
  FCurrentTestName := '';
  FCurrentContext  := nil;
  FExpression      := nil;
end;

procedure TTestTypeInfo.TearDown;
begin
  FCurrentContext.ReleaseReference;
  FExpression.Free;
  FDwarfInfo.Free;
  FImageLoaderList.Free;
  FMemReader.Free;
  if FMemManager <> nil then
    FMemManager.TargetMemConvertor.Free;
  FreeAndNil(FMemManager);
  inherited TearDown;
end;

procedure TTestTypeInfo.TestExpressionInt;
var
  sym: TFpValue;
  ImgLoader: TTestLoaderSetupBasic;
  TmpResVal: TFpValue;
  Ctx: TFpDbgSimpleLocationContext;
begin
  InitDwarf(TTestLoaderSetupBasic);
  ImgLoader := TTestLoaderSetupBasic(FImageLoader);
  //FMemReader.RegisterValues[5] := TDbgPtr(@ImgLoader.TestStackFrame.EndPoint);

  Ctx := TFpDbgSimpleLocationContext.Create(FMemManager, TTestSetupBasicProcMainAddr, 4, 0, 0);
  FCurrentContext := FDwarfInfo.FindSymbolScope(Ctx, TTestSetupBasicProcMainAddr);
  Ctx.ReleaseReference;
  AssertTrue('got ctx', FCurrentContext <> nil);

  sym := FCurrentContext.FindSymbol('VarEnum0');
  AssertTrue('got sym',  sym <> nil);
  sym.ReleaseReference;


      ImgLoader.GlobalVar.VarInt16 := 22;
      StartTest('VarInt16', skInteger, [ttHasType]);
      ExpFlags([svfInteger, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
      ExpResult(svfInteger, 22);
      ExpResult(svfOrdinal, QWord(22));
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarInt16)));
      ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarInt16));

      ImgLoader.GlobalVar.VarSub5 := -10;
      StartTest('VarSub5', skInteger, [ttHasType]);
      ExpFlags([svfInteger, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
      ExpResult(svfInteger, -10);
      ExpResult(svfOrdinal, QWord(-10));
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarSub5)));
      ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarSub5));



      StartTest('QWord($1122334455667748)', skCardinal, []);
      ExpResult(svfCardinal, $1122334455667748);

      StartTest('ShortInt(QWord($1122334455667748))', skInteger, []);
      ExpResult(svfInteger, integer($48));

      StartTest('ShortInt(QWord($11223344556677F8))', skInteger, []);
      ExpResult(svfInteger, -8);

end;

procedure TTestTypeInfo.TestExpressionBool;
var
  sym: TFpValue;
  ImgLoader: TTestLoaderSetupBasic;
  TmpResVal: TFpValue;
  i: Integer;
  s: String;
  Ctx: TFpDbgSimpleLocationContext;
begin
  InitDwarf(TTestLoaderSetupBasic);
  ImgLoader := TTestLoaderSetupBasic(FImageLoader);
  //FMemReader.RegisterValues[5] := TDbgPtr(@ImgLoader.TestStackFrame.EndPoint);


  Ctx := TFpDbgSimpleLocationContext.Create(FMemManager, TTestSetupBasicProcMainAddr, 4, 0, 0);
  FCurrentContext := FDwarfInfo.FindSymbolScope(Ctx, TTestSetupBasicProcMainAddr);
  Ctx.ReleaseReference;
  AssertTrue('got ctx', FCurrentContext <> nil);

  sym := FCurrentContext.FindSymbol('VarEnum0');
  AssertTrue('got sym',  sym <> nil);
  sym.ReleaseReference;

    for i := 0 to 3 do begin
      case i of
         0: s := 'VarBoolean';
         1: s := 'Boolean(VarBoolean)';
         2: s := 'PBoolean(@VarBoolean)^';
         3: s := '^Boolean(@VarBoolean)^';
      end;

      ImgLoader.GlobalVar.VarBoolean := True;
      StartTest(s, skBoolean, [ttHasType]);
      ExpFlags([svfBoolean, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
      ExpResult(svfBoolean, True);
      ExpResult(svfOrdinal, QWord(True));
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarBoolean)));
      ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarBoolean));

      ImgLoader.GlobalVar.VarBoolean := False;
      StartTest(s, skBoolean, [ttHasType]);
      ExpFlags([svfBoolean, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
      ExpResult(svfBoolean, False);
      ExpResult(svfOrdinal, QWord(False));

      ImgLoader.GlobalVar.VarBoolean := boolean(100);
      StartTest(s, skBoolean, [ttHasType]);
      ExpFlags([svfBoolean, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
      ExpResult(svfBoolean, True);
      ExpResult(svfOrdinal, QWord(100));

    end;

    StartTest('Boolean(1)', skBoolean, [ttHasType]);
    ExpFlags([svfBoolean, svfOrdinal, svfSize], [svfAddress, svfSizeOfPointer, svfDataAddress, svfDataSize]);
    ExpResult(svfBoolean, True);
    ExpResult(svfOrdinal, QWord(1));

    StartTest('Boolean(0)', skBoolean, [ttHasType]);
    ExpFlags([svfBoolean, svfOrdinal, svfSize], [svfAddress, svfSizeOfPointer, svfDataAddress, svfDataSize]);
    ExpResult(svfBoolean, False);
    ExpResult(svfOrdinal, QWord(0));

    //TODO
    //StartTest('True', skBoolean, [ttHasType]);

end;

procedure TTestTypeInfo.TestExpressionArray;
var
  sym: TFpValue;
  ImgLoader: TTestLoaderSetupArray;
  TmpResVal: TFpValue;
  i: Integer;
  s: String;
  Ctx: TFpDbgSimpleLocationContext;
begin
  InitDwarf(TTestLoaderSetupArray);
  ImgLoader := TTestLoaderSetupArray(FImageLoader);
  //FMemReader.RegisterValues[5] := TDbgPtr(@ImgLoader.TestStackFrame.EndPoint);

  Ctx := TFpDbgSimpleLocationContext.Create(FMemManager, TTestSetupBasicProcMainAddr, 4, 0, 0);
  FCurrentContext := FDwarfInfo.FindSymbolScope(Ctx, TTestSetupArrayProcMainAddr);
  Ctx.ReleaseReference;
  AssertTrue('got ctx', FCurrentContext <> nil);

  sym := FCurrentContext.FindSymbol('VarDynIntArray');
  AssertTrue('got sym',  sym <> nil);
  sym.ReleaseReference;

  StartTest('VarDynIntArray', skArray, [ttHasType]);
  StartTest('VarStatIntArray1', skArray, [ttHasType]);

  ImgLoader.GlobalVar.VarDynIntArray := nil;
  StartInvalTest('VarDynIntArray[0]', 'xxx');
  StartInvalTest('VarDynIntArray[1]', 'xxx');

  SetLength(ImgLoader.GlobalVar.VarDynIntArray,33);
  ImgLoader.GlobalVar.VarDynIntArray[0] := 10;
  ImgLoader.GlobalVar.VarDynIntArray[1] := 11;
  ImgLoader.GlobalVar.VarDynIntArray[2] := 12;
  ImgLoader.GlobalVar.VarDynIntArray[31] := 410;
  ImgLoader.GlobalVar.VarDynIntArray[32] := 420;

  StartTest('VarDynIntArray', skArray, [ttHasType]);
  ExpResult(svfOrdinal, QWord(PtrUInt(ImgLoader.GlobalVar.VarDynIntArray)));
  AssertEquals(FExpression.ResultValue.MemberCount, 33);

  StartTest('TDynIntArray(VarDynIntArray)', skArray, [ttHasType]);
  ExpResult(svfOrdinal, QWord(PtrUInt(ImgLoader.GlobalVar.VarDynIntArray)));
  AssertEquals(FExpression.ResultValue.MemberCount, 33);

  StartTest('VarStatIntArray1', skArray, [ttHasType]);
  AssertEquals(FExpression.ResultValue.MemberCount, 11);

  StartTest('TStatIntArray1(VarStatIntArray1)', skArray, [ttHasType]);
  AssertEquals(FExpression.ResultValue.MemberCount, 11);


  StartTest('VarDynIntArray[0]', skInteger, [ttHasType]);
  ExpFlags([svfInteger, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
  ExpResult(svfInteger, 10);
  ExpResult(svfOrdinal, QWord(10));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarDynIntArray[0])));
  ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarDynIntArray[0]));

  StartTest('VarDynIntArray[1]', skInteger, [ttHasType]);
  ExpResult(svfInteger, 11);
  ExpResult(svfOrdinal, QWord(11));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarDynIntArray[1])));

  StartTest('VarDynIntArray[32]', skInteger, [ttHasType]);
  ExpResult(svfInteger, 420);
  ExpResult(svfOrdinal, QWord(420));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarDynIntArray[32])));

  StartTest('TDynIntArray(VarDynIntArray)[1]', skInteger, [ttHasType]);
  ExpResult(svfInteger, 11);
  ExpResult(svfOrdinal, QWord(11));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarDynIntArray[1])));


  ImgLoader.GlobalVar.VarStatIntArray1[0] := 110;
  ImgLoader.GlobalVar.VarStatIntArray1[1] := 111;

  StartTest('VarStatIntArray1[0]', skInteger, [ttHasType]);
  ExpFlags([svfInteger, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
  ExpResult(svfInteger, 110);
  ExpResult(svfOrdinal, QWord(110));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarStatIntArray1[0])));
  ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarStatIntArray1[0]));

  StartTest('VarStatIntArray1[1]', skInteger, [ttHasType]);
  ExpResult(svfInteger, 111);
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarStatIntArray1[1])));

  StartTest('TStatIntArray1(VarStatIntArray1)[0]', skInteger, [ttHasType]);
  ExpFlags([svfInteger, svfOrdinal, svfAddress, svfSize], [svfSizeOfPointer, svfDataAddress, svfDataSize]);
  ExpResult(svfInteger, 110);
  ExpResult(svfOrdinal, QWord(110));
  ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.GlobalVar.VarStatIntArray1[0])));
  ExpResult(svfSize, SizeOf(ImgLoader.GlobalVar.VarStatIntArray1[0]));


end;

procedure TTestTypeInfo.TestExpressionStructures;
var
  sym: TFpValue;

  obj1: TTestSetup1Class;
  obj1c: TTestSetup1ClassChild;
  vobj1: TTestSetup1Object;
  i, j: Integer;
  FieldsExp: TFpValueFieldFlags;
  AddrExp: TDbgPtr;
  s, s2: String;
  ImgLoader: TTestLoaderSetup1;
  Ctx: TFpDbgSimpleLocationContext;
begin
  InitDwarf(TTestLoaderSetup1);
  ImgLoader := TTestLoaderSetup1(FImageLoader);
  FMemReader.RegisterValues[5] := TDbgPtr(@ImgLoader.TestStackFrame.EndPoint);

  Obj1c := nil;
  obj1 := TTestSetup1Class.Create;
  ImgLoader.TestStackFrame.Int1 := -299;
  ImgLoader.TestStackFrame.Obj1 := obj1;
  try
    Ctx := TFpDbgSimpleLocationContext.Create(FMemManager, TTestSetupBasicProcMainAddr, 4, 0, 0);
    FCurrentContext := FDwarfInfo.FindSymbolScope(Ctx, TTestSetup1ProcBarAddr);
    Ctx.ReleaseReference;
    AssertTrue('got ctx', FCurrentContext <> nil);

    sym := FCurrentContext.FindSymbol('Int1');
    AssertTrue('got sym',  sym <> nil);
    sym.ReleaseReference;

    // Not existing
    StartInvalTest('NotExisting1399', 'xxx');

    // Not Existing Typecast
    StartInvalTest('TNotExisting1399(Int1)', 'xxx');

    StartInvalTest('@99', 'xxx');
    StartInvalTest('99^', 'xxx');
    StartInvalTest('longint(@99)', 'xxx');
    StartInvalTest('^longint(@99)', 'xxx');
    StartInvalTest('PInt(@99)', 'xxx');
    StartInvalTest('@Int1^', 'xxx');
    StartInvalTest('^(longint(Int1))', 'xxx'); // no ( allowed between ^ and type


    StartTest('LongInt', [ttHasSymbol, ttNotHasType]);
    StartTest('^LongInt', [ttHasSymbol, ttNotHasType]);
    StartTest('TObject', [ttHasSymbol, ttNotHasType]);
    StartTest('^TObject', [ttHasSymbol, ttNotHasType]);


    // TODO: maybe treat numbers as integer?
    StartTest('244', skCardinal, []);
    ExpFlags([svfCardinal, svfOrdinal], [svfAddress, svfSize, svfSizeOfPointer, svfDataAddress, svfDataSize]);
    ExpResult(svfCardinal, 244);
    ExpResult(svfOrdinal, QWord(244));

    ImgLoader.TestStackFrame.pint1 := @ImgLoader.TestStackFrame.Int1;
    ImgLoader.GlobTestSetup1.VarQWord := PtrInt(@ImgLoader.TestStackFrame.pint1);
    ImgLoader.GlobTestSetup1.VarPointer := @ImgLoader.TestStackFrame.pint1;
    for i := 0 to 22 do begin
      case i of
         0: s := 'Int1';
         1: s := 'longint(Int1)';
         2: s := 'int64(Int1)';
         3: s := '(@Int1)^';
         4: s := 'PInt(@Int1)^';
         5: s := '^longint(@Int1)^';
         6: s := '^longint(pointer(@Int1))^';
         7: s := 'longint(^longint(@Int1)^)';
         8: s := 'int64(^longint(@Int1)^)';
         9: s := 'PInt('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.Int1)))+')^';
        10: s := '^longint('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.Int1)))+')^';
        11: s := 'LongInt(Pointer('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.Int1)))+')^)';
        12: s := '^^longint('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.PInt1)))+')^^';
        13: s := '^^longint(GlobTestSetup1Pointer)^^';
        14: s := '^^^longint(@GlobTestSetup1Pointer)^^^';
        15: s := '^^longint(GlobTestSetup1QWord)^^';
        16: s := '^^^longint(@GlobTestSetup1QWord)^^^';
        17: s := '^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^^^';
        18: s := '(^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^^)^';
        19: s := '(^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^)^^';
        20: s := '((^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^)^)^';
        21: s := '^^PInt('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^^^';
        22: s := '(^^PInt('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^^)^';
      end;

      StartTest(s, skInteger, [ttHasType]);
      ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfCardinal, svfDataAddress]); // svfSize;
      ExpResult(svfInteger, -299);
      ExpResult(svfOrdinal, QWord(-299));
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Int1)));
      case i of
        0,1,3..7,10..22: ExpResult(svfSize, 4); // integer
        2,8: ExpResult(svfSize, 8); // int64
      end;
    end;

    for i := 0 to 19 do begin
      case i of
         0: s := '@Int1';
         1: s := 'PInt(@Int1)';
         2: s := 'PInt(Pointer(@Int1))';
         3: s := '^longint(@Int1)';
         4: s := '^word(@Int1)';
         5: s := '^int64(@Int1)';
         6: s := '@longint(Int1)';
         7: s := '@(longint(Int1))';
         8: s := '@word(Int1)';
         9: s := '@int64(Int1)';
        10: s := '^longint('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.Int1)))+')';
        11: s := 'PInt('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.Int1)))+')';
        12: s := '@PInt(@Int1)^';
        13: s := '@^longint(@Int1)^';
        14: s := '^^longint('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.PInt1)))+')^';
        15: s := '^^longint(GlobTestSetup1Pointer)^';
        16: s := '^^^longint(@GlobTestSetup1Pointer)^^';
        17: s := '^^longint(GlobTestSetup1QWord)^';
        18: s := '^^^longint(@GlobTestSetup1QWord)^^';
        19: s := '^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^^';
      end;

      StartTest(s, skPointer, [ttHasType]);
      ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
      ExpResult(svfOrdinal, PtrUInt(@ImgLoader.TestStackFrame.Int1));
      ExpResult(svfDataAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Int1)));
    end;

    for i := 0 to 5 do begin
      case i of
         0: s := '^^longint('+IntToStr((PtrUInt(@ImgLoader.TestStackFrame.PInt1)))+')';
         1: s := '^^longint(GlobTestSetup1Pointer)';
         2: s := '^^^longint(@GlobTestSetup1Pointer)^';
         3: s := '^^longint(GlobTestSetup1QWord)';
         4: s := '^^^longint(@GlobTestSetup1QWord)^';
         5: s := '^^^longint('+IntToStr((PtrUInt(@ImgLoader.GlobTestSetup1.VarPointer)))+')^';
      end;

      StartTest(s, skPointer, [ttHasType]);
      ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
      ExpResult(svfOrdinal, PtrUInt(@ImgLoader.TestStackFrame.PInt1));
      ExpResult(svfDataAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.PInt1)));
    end;


    // intentionally read more mem
    StartTest('^int64(@Int1)^', skInteger, [ttHasType]);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfCardinal, svfDataAddress]); // svfSize;
    ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Int1)));
    DebugLn([FExpression.ResultValue.AsInteger, '  ', IntToHex(FExpression.ResultValue.AsInteger,16)]);
    AssertTrue(FCurrentTestName+'unknown result', -299 <> FExpression.ResultValue.AsInteger);
    AssertTrue(FCurrentTestName+'result and mask',
               (Integer((FExpression.ResultValue.AsInteger shr 32) and int64($ffffffff))  = -299) or
               (Integer((FExpression.ResultValue.AsInteger)        and int64($ffffffff))  = -299) );

    StartTest('Word(Int1)');
    ExpFlags([svfCardinal, svfOrdinal, svfAddress], [svfInteger, svfDataAddress]); // svfSize;
    ExpResult(svfCardinal, $FED5);
    ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Int1)));

    StartTest('LongInt(Obj1)');
    ExpResult(svfOrdinal, PtrUInt(ImgLoader.TestStackFrame.Obj1));
    ExpResult(svfInteger, PtrInt(ImgLoader.TestStackFrame.Obj1));
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfCardinal]); // svfSize;

    // Class/Object
    ImgLoader.GlobTestSetup1.VarQWord := PtrInt(obj1);
    ImgLoader.GlobTestSetup1.VarPointer := @ImgLoader.TestStackFrame.Obj1;
    ImgLoader.TestStackFrame.PObj1 := @ImgLoader.TestStackFrame.Obj1;
    ImgLoader.TestStackFrame.VParamTestSetup1Class := @ImgLoader.TestStackFrame.Obj1;
    ImgLoader.TestStackFrame.VParamTestSetup1ClassP := @ImgLoader.TestStackFrame.PObj1;
    Obj1.FWord := 1019;
    Obj1.FBool := Boolean($9aa99aa9); // Make sure there is data, if other fields read to much
    Obj1.FWordL := QWord($9aa99aa97bb7b77b); // Make sure there is data, if other fields read to much

    for i := 0 to 23 do begin
       case i of
         11..13, 23: ImgLoader.GlobTestSetup1.VarPointer := @ImgLoader.TestStackFrame.Obj1;
         14:   ImgLoader.GlobTestSetup1.VarPointer := Pointer(ImgLoader.TestStackFrame.Obj1);
       end;
      // Different ways to access an object
      case i of
         0: s := 'Obj1';
         1: s := 'TTestSetup1Class(Obj1)';
         2: s := 'TTestSetup1Class(TObject(Obj1))';
         3: s := 'TTestSetup1Class(Pointer(Obj1))';
         4: s := 'TTestSetup1Class(TTestSetup1Class(Obj1))';
         // Downcast
         5: s := 'TObject(Obj1)';
         6: s := 'TObject(TTestSetup1Class(Obj1))';
         // object from const address (ord value of obj variable / pointer to obj-data)
         7: s := 'TTestSetup1Class('+IntToStr(PtrUInt(obj1))+')'; // no address
         8: s := 'TTestSetup1Class(Pointer('+IntToStr(PtrUInt(obj1))+'))'; // no address
         9: s := 'TTestSetup1Class(QWord('+IntToStr(PtrUInt(obj1))+'))'; // no address
         // object stored in QWord
        10: s := 'TTestSetup1Class(GlobTestSetup1QWord)';
         // pointer to object
        11: s := 'TTestSetup1Class(GlobTestSetup1Pointer^)';
        12: s := 'PTestSetup1Class(GlobTestSetup1Pointer)^';
         // object from const address of object var (pointer to obj)
        13: s := 'PTestSetup1Class('+IntToStr(PtrUInt(ImgLoader.GlobTestSetup1.VarPointer))+')^';
         // object stored in pointer (typecasted / NOT pointer to object)
        14: s := 'TTestSetup1Class(GlobTestSetup1Pointer)'; // no deref
        15: s := '(@Obj1)^';
        16: s := 'TTestSetup1Class(@(PInt(Obj1)^))';
         //
        17: s := 'PObj1^';
        18: s := 'TTestSetup1Class(PObj1^)';
        19: s := 'PTestSetup1Class(PObj1)^';
        20: s := '(@PObj1)^^';
        21: s := 'VParamTestSetup1Class';
        22: s := 'VParamTestSetup1ClassP^';
        23: s := '^TTestSetup1Class(GlobTestSetup1Pointer)^';
      end;
      FieldsExp := [svfMembers, svfOrdinal, svfAddress, svfDataAddress]; // svfSize dataSize;
      AddrExp   := TDbgPtr(@ImgLoader.TestStackFrame.Obj1);
      if i in [7..9, 16] then FieldsExp := FieldsExp - [svfAddress];
      if i in [10] then AddrExp := TDbgPtr(@ImgLoader.GlobTestSetup1.VarQWord);
      if i in [14] then AddrExp := TDbgPtr(@ImgLoader.GlobTestSetup1.VarPointer);

      // Check result for object
      StartTest(s, skClass, [ttHasType]);
      ExpFlags(FieldsExp);
      if i in [7..9, 16] then
        ExpFlags([], [svfAddress]);
      if svfAddress in FieldsExp then begin
        ExpResult(svfAddress, AddrExp);
        ExpFlags([svfSizeOfPointer]);
      end;
      ExpResult(svfDataAddress, TDbgPtr(PtrUInt(ImgLoader.TestStackFrame.Obj1)));
      ExpResult(svfOrdinal, PtrUInt (ImgLoader.TestStackFrame.Obj1));
      case i of
        5,6: ExpResult(svfDataSize, TObject.InstanceSize);
        // TODO: next line fails in 64 bit, as dummy debug info was created for 32 bit
        // in 32 bit the Obj has a size of 32 bytes.
        // TODO: this also depends on FPC version
        else ExpResult(svfDataSize, ImgLoader.TestStackFrame.Obj1.InstanceSize);
      end;


      // Check result for @object
      if svfAddress in FieldsExp then begin
        StartTest('@('+s+')', skPointer, [ttHasType]);
        ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
        ExpResult(svfCardinal, QWord(AddrExp));
        ExpResult(svfDataAddress, AddrExp);

        if not (i in [12, 13, 15, 17, 19, 20]) then begin
          StartTest('@'+s, skPointer, [ttHasType]);
          ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
          ExpResult(svfCardinal, QWord(AddrExp));
          ExpResult(svfDataAddress, AddrExp);
        end;
      end;


      if not (i in [5,6]) then begin

        // Object.FWord
        for j := 0 to 2 do begin
          case j of
            0: s2 := s+'.FWord';
            1: s2 := 'Word('+s+'.FWord)';
            2: s2 := '(@('+s+'.FWord))^';
          end;
          StartTest(s2, skCardinal, [ttHasType]);
          ExpFlags([svfCardinal, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;
          ExpResult(svfCardinal, 1019);
          ExpResult(svfOrdinal, 1019);
          ExpResult(svfAddress, TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FWord));
        end;

        // @Object.FWord
        StartTest('@('+s2+')');
        ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
        ExpResult(svfCardinal, QWord(TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FWord)));
        ExpResult(svfDataAddress, TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FWord));

        if not (j in [2]) then begin
          StartTest('@'+s2);
          ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]);
          ExpResult(svfCardinal, QWord(TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FWord)));
          ExpResult(svfDataAddress, TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FWord));
        end;


        // Object.FTest
        ImgLoader.TestStackFrame.Obj1.FTest := nil;
        StartTest(s+'.FTest', skClass, [ttHasType]);
        ExpFlags([svfMembers, svfOrdinal, svfAddress, svfDataAddress]); // svfSize;
        ExpResult(svfAddress, TDbgPtr(@ImgLoader.TestStackFrame.Obj1.FTest));
        ExpResult(svfDataAddress, TDbgPtr(PtrUInt(ImgLoader.TestStackFrame.Obj1.FTest)));
        ExpResult(svfOrdinal, QWord(PtrUInt(ImgLoader.TestStackFrame.Obj1.FTest)));


        ImgLoader.TestStackFrame.Obj1.FTest := obj1;
        StartTest(s+'.FTest.FWord', skCardinal, [ttHasSymbol]);
        ExpResult(svfCardinal, 1019);
        ExpFlags([svfCardinal, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

        ImgLoader.TestStackFrame.Obj1.FTest := obj1;
        StartTest(s+'.FTest.FTest.FWord', skCardinal, [ttHasSymbol]);
        ExpResult(svfCardinal, 1019);
        ExpFlags([svfCardinal, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

      end; // not (i in [4,5])

    end;


    StartTest('@Obj1.FTest');
    ExpResult(svfCardinal, PtrUint(@ImgLoader.TestStackFrame.Obj1.FTest));
    ExpFlags([svfCardinal, svfOrdinal], [svfAddress]);

    // TODO: NOT valid (^ operates before @
    StartInvalTest('@Obj1.FWord^', 'xxx');

    StartTest('(@Obj1.FWord)^');
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize;


    StartInvalTest('Obj1.@FWord', 'xxx');
    StartInvalTest('Obj1.@Int1', 'xxx');
    StartInvalTest('Obj1.@Obj1', 'xxx');
    StartInvalTest('Obj1.Obj1', 'xxx');
    StartInvalTest('Int1.FWord', 'xxx');
    StartInvalTest('Obj1.NotExisting', 'xxx');
    StartInvalTest('Obj1.123', 'xxx');
    StartInvalTest('123.NotExisting', 'xxx');

    StartInvalTest('TObject(Obj1).FWord', 'xxx');

    // Class/Object // typecast, and inherhited
    obj1c := TTestSetup1ClassChild.Create;
    ImgLoader.GlobTestSetup1.VarClass := Obj1c;
    ImgLoader.GlobTestSetup1.VarClassChild := Obj1c;
    Obj1c.FWord := 1019;
    Obj1c.FBool := Boolean($9aa99aa9); // Make sure there is data, if other fields read to much
    Obj1c.FWordL := QWord($9aa99aa97bb7b77b); // Make sure there is data, if other fields read to much

    StartTest('GlobTestSetup1Class.FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);

    StartTest('GlobTestSetup1ClassChild.FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);

    StartTest('TTestSetup1ClassChild(GlobTestSetup1Class).FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);

    // Record
    // VParamTestRecord mis-named
    ImgLoader.TestStackFrame.Rec1.FWord := $9ab7;
    ImgLoader.TestStackFrame.PRec1 := @ImgLoader.TestStackFrame.Rec1;
    ImgLoader.TestStackFrame.VParamTestSetup1Record := @ImgLoader.TestStackFrame.Rec1;
    ImgLoader.TestStackFrame.VParamTestRecord := @ImgLoader.TestStackFrame.PRec1;

    StartTest('PRec1', skPointer, [ttHasType]);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress, svfDataAddress]); // svfSize;

    for i := 0 to 7 do begin
      case i of
         0: s := 'Rec1';
         1: s := 'PRec1^';
         2: s := '(@Rec1)^';
         3: s := '(@PRec1)^^';
         4: s := 'VParamTestSetup1Record';
         5: s := 'VParamTestRecord^';
         6: s := 'TTestSetup1Record(Rec1)';
         7: s := 'TTestSetup1Record2(Rec1)'; // TTestSetup1Record2 is a distinct type, but same sive (actually identical)
      end;

      StartTest(s, skRecord, [ttHasType]);
      // svfSize;
      ExpFlags([svfMembers, svfAddress, svfSize], [svfOrdinal, svfCardinal, svfInteger, svfDataAddress, svfDataSize]);
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Rec1)));
      ExpResult(svfSize, SizeOf(ImgLoader.TestStackFrame.Rec1));


      StartTest(s+'.FWord', skCardinal, [ttHasType]);
      ExpFlags([svfCardinal, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;
      ExpResult(svfCardinal, $9ab7);
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Rec1.FWord)));

      StartTest('@'+s+'.FWord', skPointer, [ttHasType]);
      ExpFlags([svfCardinal, svfOrdinal, svfDataAddress], [svfAddress]); // svfSize;
      ExpResult(svfCardinal, QWord(PtrUInt(@ImgLoader.TestStackFrame.Rec1.FWord)));
      ExpResult(svfDataAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Rec1.FWord)));


      ImgLoader.TestStackFrame.Rec1.FBool := False;
      StartTest(s+'.FBool', skBoolean, [ttHasType]);
      ExpFlags([svfBoolean, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;
      ExpResult(svfBoolean, False);
      ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.Rec1.FBool)));

      ImgLoader.TestStackFrame.Rec1.FBool := True;
      StartTest(s+'.FBool', skBoolean, [ttHasType]);
      ExpResult(svfBoolean, True);

    end;

    // Record
    ImgLoader.TestStackFrame.Rec1.FWord := 1021;
    StartTest('Rec1');

    StartTest('Rec1.FWord');
    ExpResult(svfCardinal, 1021);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]);

    ImgLoader.TestStackFrame.Rec1.FBool := False;
    StartTest('Rec1.FBool');
    ExpResult(svfBoolean, False);

    ImgLoader.TestStackFrame.Rec1.FBool := True;
    StartTest('Rec1.FBool');
    ExpResult(svfBoolean, True);

    ImgLoader.TestStackFrame.Rec1.FBool := Boolean(100);
    StartTest('Rec1.FBool');
    ExpResult(svfBoolean, True);
    ExpResult(svfOrdinal, 100);

    StartInvalTest('TTestSetup1Record3(Rec1)', 'xxx'); // wrong size
    StartInvalTest('TTestSetup1Record3(Rec1).FWord', 'xxx'); // wrong size



    // type = Object ... end;
    StartTest('OldObj1', skObject, [ttHasType]);
    ExpFlags([svfMembers, svfAddress], [svfOrdinal, svfCardinal, svfInteger, svfDataAddress]);
    ExpResult(svfAddress, TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.OldObj1)));

    // var param // old style object
    vobj1.FWord := 1122;
    vobj1.FInt := -122;
    ImgLoader.TestStackFrame.OldObj1 := vobj1;
    ImgLoader.TestStackFrame.POldObj1 := @vobj1;
    ImgLoader.TestStackFrame.VParamTestSetup1Object := @vobj1;
    ImgLoader.TestStackFrame.VParamTestSetup1ObjectP := @ImgLoader.TestStackFrame.POldObj1;

    for i := 0 to 7 do begin
      case i of
         2,4: AddrExp := TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.OldObj1));
         else AddrExp := TDbgPtr(PtrUInt(@vobj1));
      end;
      case i of
         0: s := 'VParamTestSetup1Object';
         1: s := 'VParamTestSetup1ObjectP^';
         2: s := 'OldObj1';
         3: s := 'POldObj1^';
         4: s := '(@OldObj1)^';
         5: s := '(@POldObj1)^^';
         6: s := 'TTestSetup1Object(VParamTestSetup1Object)';
         7: s := 'TTestSetup1Object2(VParamTestSetup1Object)';
      end;

      StartTest(s, skObject, [ttHasType]);
      ExpFlags([svfMembers, svfAddress, svfSize], [svfOrdinal, svfCardinal, svfInteger, svfDataAddress, svfDataSize]);
      ExpResult(svfAddress, AddrExp);
      ExpResult(svfSize, SizeOf(ImgLoader.TestStackFrame.OldObj1));

      case i of
         2,4: AddrExp := TDbgPtr(PtrUInt(@ImgLoader.TestStackFrame.OldObj1.FWord));
         else AddrExp := TDbgPtr(PtrUInt(@vobj1.FWord));
      end;
      StartTest(s+'.FWord');
      ExpFlags([svfCardinal, svfOrdinal, svfAddress]);
      ExpResult(svfCardinal, 1122);
      ExpResult(svfAddress, AddrExp);

      StartTest(s+'.FInt');
      ExpResult(svfInteger, -122);
      ExpFlags([svfInteger, svfOrdinal, svfAddress]);

    end;

    StartInvalTest('TTestSetup1Object3(VParamTestSetup1Object)', 'xxx');

    // pointer
    ImgLoader.TestStackFrame.Int1 := -299;
    ImgLoader.TestStackFrame.pi := @ImgLoader.TestStackFrame.int1;
    ImgLoader.GlobTestSetup1.VarPointer := @ImgLoader.TestStackFrame.int1;
    ImgLoader.GlobTestSetup1.VarQWord := QWord(@ImgLoader.TestStackFrame.int1);

    StartTest('pi', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.TestStackFrame.pi));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('GlobTestSetup1Pointer', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.GlobTestSetup1.VarPointer));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('pointer(pi)', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.TestStackFrame.pi));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('PInt(pi)', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.TestStackFrame.pi));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('PTestSetup1Class(pi)', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.TestStackFrame.pi));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('pointer(GlobTestSetup1Pointer)', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.GlobTestSetup1.VarPointer));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('pint(GlobTestSetup1Pointer)', skPointer, [ttHasType]);
    ExpResult(svfOrdinal, QWord(@ImgLoader.TestStackFrame.int1));
    ExpResult(svfAddress, QWord(@ImgLoader.GlobTestSetup1.VarPointer));
    ExpResult(svfDataAddress, QWord(@ImgLoader.TestStackFrame.int1));
    ExpFlags([svfOrdinal, svfAddress, svfDataAddress, svfSizeOfPointer]);

    StartTest('pi^', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartTest('PInt(pi)^', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartTest('LongInt(pointer(pi)^)', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartTest('PInt(GlobTestSetup1Pointer)^', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartTest('LongInt(GlobTestSetup1Pointer^)', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartTest('PInt(GlobTestSetup1QWord)^', skInteger, [ttHasType]);
    ExpResult(svfInteger, -299);
    ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;

    StartInvalTest('LongInt(GlobTestSetup1QWord^)', '');

    //StartTest('LongInt(GlobTestSetup1QWord^)', skInteger, [ttHasType]);
    //ExpResult(svfInteger, -299);
    //ExpFlags([svfInteger, svfOrdinal, svfAddress], [svfDataAddress]); // svfSize;


    ImgLoader.TestStackFrame.pi := @ImgLoader.TestStackFrame.Obj1;
    ImgLoader.GlobTestSetup1.VarPointer := @ImgLoader.TestStackFrame.Obj1;
    ImgLoader.GlobTestSetup1.VarQWord := QWord(@ImgLoader.TestStackFrame.Obj1);

    StartTest('TTestSetup1Class(pi^).FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize; //

    StartTest('PTestSetup1Class(pi)^.FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize; //

    StartTest('TTestSetup1Class(GlobTestSetup1Pointer^).FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize; //

    StartTest('PTestSetup1Class(GlobTestSetup1Pointer)^.FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize; //

    StartTest('PTestSetup1Class(GlobTestSetup1QWord)^.FWord', skCardinal, [ttHasType]);
    ExpResult(svfCardinal, 1019);
    ExpFlags([svfCardinal, svfOrdinal, svfAddress]); // svfSize; //
  finally
    obj1.Free;
    Obj1c.Free;
  end;
end;

procedure TTestTypeInfo.TestExpressionEnumAndSet;
  procedure ExpEnumVal(AnIdent: String; AnOrd: QWord; AnAddr: TDbgPtr = 0; ASize: Integer = -1);
  begin
    if AnAddr <> 0 then
      ExpFlags([svfOrdinal, svfIdentifier, svfMembers, svfAddress, svfSize], [svfCardinal, svfString])
    else
      ExpFlags([svfOrdinal, svfIdentifier, svfMembers], [svfCardinal, svfString {, svfAddress, svfSize}]);
    ExpResult(svfOrdinal, AnOrd);
    ExpResult(svfIdentifier, AnIdent);
    if AnAddr <> 0 then
      ExpResult(svfAddress, AnAddr);
    if ASize >= 0 then
      ExpResult(svfSize, ASize);
    if AnIdent <> '' then
      ExpMemberCount(1)
    else
      ExpMemberCount(0);
  end;
  function ExpEnumMemberVal(AnIdent: String; AnOrd: QWord): TFpValue;
  begin
    FCurrentTestName := FCurrentTestName + ' (enum-val)';
    Result := FExpression.ResultValue.Member[0];
    ExpKind(Result, skEnumValue, [ttNotHasType]);
    ExpFlags(Result, [svfOrdinal, svfIdentifier], [svfCardinal, svfString, svfMembers, svfAddress, svfSize]);
    ExpResult(Result, svfIdentifier, AnIdent);
    ExpResult(Result, svfOrdinal, AnOrd);
    Result.ReleaseReference;
    Result := nil;
  end;

  procedure ExpSetVal(AMemberCount: Integer; AnAddr: TDbgPtr = 0; ASize: Integer = -1);
  begin
    if AnAddr <> 0 then
      ExpFlags([svfMembers, svfAddress, svfSize], [svfCardinal, svfString, svfIdentifier])
    else
      ExpFlags([svfMembers], [svfCardinal, svfString, svfIdentifier {, svfAddress, svfSize}]);
    if AnAddr <> 0 then
      ExpResult(svfAddress, AnAddr);
    if ASize >= 0 then
      ExpResult(svfSize, ASize);
    ExpMemberCount(AMemberCount);
  end;

  procedure ExpSetVal(AMemberCount: Integer; AnOrdinal: QWord; AnAddr: TDbgPtr = 0; ASize: Integer = -1);
  begin
    ExpSetVal(AMemberCount, AnAddr, ASize);
    ExpResult(svfOrdinal, AnOrdinal);
  end;

  procedure ExpSetIdent(AnIdentList: array of string);
  var
    i: Integer;
    m: TFpValue;
  begin
    for i := low(AnIdentList) to high(AnIdentList) do begin
      m := FExpression.ResultValue.Member[i];
      AssertTrue(FCurrentTestName + 'has member at pos '+IntToStr(i), m <> nil);
      AssertTrue(FCurrentTestName + 'member at pos fieldflag '+IntToStr(i), svfIdentifier in m.FieldFlags);
      AssertEquals(FCurrentTestName + 'member at pos value ident '+IntToStr(i), UpperCase(AnIdentList[i]), m.AsString);
      m.ReleaseReference;
    end;
  end;

  procedure ExpSetOrd(AnIdentList: array of QWord);
  var
    i: Integer;
    m: TFpValue;
  begin
    for i := low(AnIdentList) to high(AnIdentList) do begin
      m := FExpression.ResultValue.Member[i];
      AssertTrue(FCurrentTestName + 'has member at pos (ord)'+IntToStr(i), m <> nil);
      AssertTrue(FCurrentTestName + 'member at pos fieldflag (ord)'+IntToStr(i), svfOrdinal in m.FieldFlags);
      AssertEqualsQW(FCurrentTestName + 'member at pos value ord'+IntToStr(i), AnIdentList[i], m.AsCardinal);
      m.ReleaseReference;
    end;
  end;


var
  sym: TFpValue;
  ImgLoader: TTestLoaderSetupBasic;
  TmpResVal: TFpValue;
  Ctx: TFpDbgSimpleLocationContext;
begin
  InitDwarf(TTestLoaderSetupBasic);
  ImgLoader := TTestLoaderSetupBasic(FImageLoader);
  //FMemReader.RegisterValues[5] := TDbgPtr(@ImgLoader.TestStackFrame.EndPoint);


  Ctx := TFpDbgSimpleLocationContext.Create(FMemManager, TTestSetupBasicProcMainAddr, 4, 0, 0);
  FCurrentContext := FDwarfInfo.FindSymbolScope(Ctx, TTestSetupBasicProcMainAddr);
  Ctx.ReleaseReference;
  AssertTrue('got ctx', FCurrentContext <> nil);

  sym := FCurrentContext.FindSymbol('VarEnum0');
  AssertTrue('got sym',  sym <> nil);
  sym.ReleaseReference;


    ImgLoader.GlobalVar.VarEnum0 := e0a;
    StartTest('VarEnum0', skEnum, [ttHasType]);
    ExpEnumVal('e0a', 0, TDbgPtr(@ImgLoader.GlobalVar.VarEnum0), SizeOf(ImgLoader.GlobalVar.VarEnum0));
    ExpEnumMemberVal('e0a', 0);


    ImgLoader.GlobalVar.VarEnum1 := e1c;
    StartTest('VarEnum1', skEnum, [ttHasType], 'e1c');
    ExpEnumVal('e1c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum1), SizeOf(ImgLoader.GlobalVar.VarEnum1));
    ExpEnumMemberVal('e1c', 2);

    ImgLoader.GlobalVar.VarEnum1 := TEnum1(100);
    StartTest('VarEnum1', skEnum, [ttHasType], 'out of range');
    ExpEnumVal('', 100, TDbgPtr(@ImgLoader.GlobalVar.VarEnum1), SizeOf(ImgLoader.GlobalVar.VarEnum1));


    ImgLoader.GlobalVar.VarEnum2 := e2c;
    StartTest('VarEnum2', skEnum, [ttHasType], 'e2c');
    ExpEnumVal('e2c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum2), SizeOf(ImgLoader.GlobalVar.VarEnum2));
    ExpEnumMemberVal('e2c', 2);

    ImgLoader.GlobalVar.VarEnum2 := e2i;
    StartTest('VarEnum2', skEnum, [ttHasType], 'e2i');
    ExpEnumVal('e2i', 8, TDbgPtr(@ImgLoader.GlobalVar.VarEnum2), SizeOf(ImgLoader.GlobalVar.VarEnum2));
    ExpEnumMemberVal('e2i', 8);


    ImgLoader.GlobalVar.VarEnum3 := e3c;
    StartTest('VarEnum3', skEnum, [ttHasType], 'e3c');
    ExpEnumVal('e3c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3c', 2);

    ImgLoader.GlobalVar.VarEnum3 := e3j;
    StartTest('VarEnum3', skEnum, [ttHasType], 'e3j');
    ExpEnumVal('e3j', 9, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3j', 9);

    ImgLoader.GlobalVar.VarEnum3 := e3q;
    StartTest('VarEnum3', skEnum, [ttHasType], 'e3q');
    ExpEnumVal('e3q', 16, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3q', 16);


    ImgLoader.GlobalVar.VarEnumX := eXa;
    StartTest('VarEnumX', skEnum, [ttHasType], 'eXa');
    ExpEnumVal('eXa', 0, TDbgPtr(@ImgLoader.GlobalVar.VarEnumX), SizeOf(ImgLoader.GlobalVar.VarEnumX));
    ExpEnumMemberVal('eXa', 0);

    ImgLoader.GlobalVar.VarEnumX := eXb;
    StartTest('VarEnumX', skEnum, [ttHasType], 'eXb');
    ExpEnumVal('eXb', 10, TDbgPtr(@ImgLoader.GlobalVar.VarEnumX), SizeOf(ImgLoader.GlobalVar.VarEnumX));
    ExpEnumMemberVal('eXb', 10);

    ImgLoader.GlobalVar.VarEnumX := eXc;
    StartTest('VarEnumX', skEnum, [ttHasType], 'eXc');
    ExpEnumVal('eXc', 3, TDbgPtr(@ImgLoader.GlobalVar.VarEnumX), SizeOf(ImgLoader.GlobalVar.VarEnumX));
    ExpEnumMemberVal('eXc', 3);

    // enum sub range
    ImgLoader.GlobalVar.VarEnumR3 := e3e;
    StartTest('VarEnumR3', skEnum, [ttHasType], 'eXc');
    ExpEnumVal('e3e', 4, TDbgPtr(@ImgLoader.GlobalVar.VarEnumR3), SizeOf(ImgLoader.GlobalVar.VarEnumR3));
    ExpEnumMemberVal('e3e', 4);


    // Typecast
    ImgLoader.GlobalVar.VarEnum3 := e3c;
    StartTest('TEnum3(VarEnum3)', skEnum, [ttHasType], 'e3c');
    ExpEnumVal('e3c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3c', 2);

    ImgLoader.GlobalVar.VarEnum3 := e3c;
    StartTest('^TEnum3(@VarEnum3)^', skEnum, [ttHasType], 'e3c');
    ExpEnumVal('e3c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3c', 2);

    ImgLoader.GlobalVar.VarEnum3 := e3c;
    StartTest('^TEnum3('+inttostr(PtrUInt(@ImgLoader.GlobalVar.VarEnum3))+')^', skEnum, [ttHasType], 'e3c');
    ExpEnumVal('e3c', 2, TDbgPtr(@ImgLoader.GlobalVar.VarEnum3), SizeOf(ImgLoader.GlobalVar.VarEnum3));
    ExpEnumMemberVal('e3c', 2);

    ImgLoader.GlobalVar.VarEnum3 := e3a;
    StartTest('TEnum3(2)', skEnum, [ttHasType], '(2)');
    ExpFlags([], [svfAddress]);
    ExpEnumVal('e3c', 2);
    ExpEnumMemberVal('e3c', 2);

    ImgLoader.GlobalVar.VarEnum3 := e3a;
    StartTest('TEnum3(8)', skEnum, [ttHasType], '(8)');
    ExpFlags([], [svfAddress]);
    ExpEnumVal('e3i', 8);
    ExpEnumMemberVal('e3i', 8);

    ImgLoader.GlobalVar.VarEnum3 := e3a;
    StartTest('TEnum3(80)', skEnum, [ttHasType]);
    ExpFlags([], [svfAddress]);
    ExpEnumVal('', 80);

    ImgLoader.GlobalVar.VarEnum1 := e1b;
    ImgLoader.GlobalVar.VarEnum3 := e3d;
    StartTest('TEnum3(VarEnum1)', skEnum, [ttHasType]);
    ExpEnumVal('e3b', 1);
    ExpEnumMemberVal('e3b', 1);

    StartTest('TEnum1(VarEnum3)', skEnum, [ttHasType]);
    ExpEnumVal('', 3);

    ImgLoader.GlobalVar.VarEnum3 := e3c;
    StartTest('TEnum1(VarEnum3)', skEnum, [ttHasType]);
    ExpEnumVal('e1c', 2);
    ExpEnumMemberVal('e1c', 2);

    ImgLoader.GlobalVar.VarByte := 1;
    StartTest('TEnum3(VarByte)', skEnum, [ttHasType]);
    ExpEnumVal('e3b', 1);
    ExpEnumMemberVal('e3b', 1);

    ImgLoader.GlobalVar.VarRecEnum2.VarEnum2 := e2e;
    StartTest('TEnum2(VarRecEnum2)', skEnum, [ttHasType]);
    ExpEnumVal('e2e', 4);
    ExpEnumMemberVal('e2e', 4);

    StartInvalTest('TEnum2(VarRecSetB1)', 'xxx');


    //
    // SET
    //

    ImgLoader.GlobalVar.VarSet2 := [e2b, e2d, e2e];
    StartTest('VarSet2', skSet, [ttHasType]);
    ExpSetVal(3, QWord(Cardinal(ImgLoader.GlobalVar.VarSet2)), TDbgPtr(@ImgLoader.GlobalVar.VarSet2), SizeOf(ImgLoader.GlobalVar.VarSet2));
    ExpSetIdent(['e2b', 'e2d', 'e2e']);
    ExpSetOrd([1,3,4]);

    ImgLoader.GlobalVar.VarSet2 := [];
    StartTest('VarSet2', skSet, [ttHasType]);
    ExpSetVal(0, QWord(Cardinal(ImgLoader.GlobalVar.VarSet2)), TDbgPtr(@ImgLoader.GlobalVar.VarSet2), SizeOf(ImgLoader.GlobalVar.VarSet2));

    ImgLoader.GlobalVar.VarSet2 := [e2b];
    StartTest('VarSet2', skSet, [ttHasType]);
    ExpSetVal(1, QWord(Cardinal(ImgLoader.GlobalVar.VarSet2)), TDbgPtr(@ImgLoader.GlobalVar.VarSet2), SizeOf(ImgLoader.GlobalVar.VarSet2));

    ImgLoader.GlobalVar.VarSet2 := [e2a, e2d, e2e, e2i];
    StartTest('VarSet2', skSet, [ttHasType]);
    ExpSetVal(4, QWord(Cardinal(ImgLoader.GlobalVar.VarSet2)), TDbgPtr(@ImgLoader.GlobalVar.VarSet2), SizeOf(ImgLoader.GlobalVar.VarSet2));


    ImgLoader.GlobalVar.VarSetB1 := [0,1,200,255];
    StartTest('VarSetB1', skSet, [ttHasType]);
    ExpSetVal(4, TDbgPtr(@ImgLoader.GlobalVar.VarSetB1), SizeOf(ImgLoader.GlobalVar.VarSetB1));

    ImgLoader.GlobalVar.VarSetB2 := [5,80];
    StartTest('VarSetB2', skSet, [ttHasType], '5,80');
    ExpSetVal(2, TDbgPtr(@ImgLoader.GlobalVar.VarSetB2), SizeOf(ImgLoader.GlobalVar.VarSetB2));
    ExpSetOrd([5,80]);

    TmpResVal := FExpression.ResultValue.Member[0];
    AssertEqualsQW(FCurrentTestName + 'TmpResVal', 5, TmpResVal.AsCardinal);
    TmpResVal.AddReference;
    FExpression.ResultValue.Member[1].ReleaseReference;
    AssertEqualsQW(FCurrentTestName + 'TmpResVal', 5, TmpResVal.AsCardinal);
    TmpResVal.ReleaseReference;
    TmpResVal.ReleaseReference;

    ImgLoader.GlobalVar.VarSetB2 := [5..80];
    StartTest('VarSetB2', skSet, [ttHasType], '5..80');
    ExpSetVal(76, TDbgPtr(@ImgLoader.GlobalVar.VarSetB2), SizeOf(ImgLoader.GlobalVar.VarSetB2));

end;


initialization

  RegisterTest(TTestTypeInfo);
  DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_SEARCH' {$IFDEF FPDBG_DWARF_SEARCH} , True {$ENDIF} )^.Enabled := True;
end.


unit TestMemManager;

{$mode objfpc}{$H+}

interface

uses
  FpDbgDwarf, FpDbgUtil, FpdMemoryTools, FpDbgInfo, TestHelperClasses,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8, LazClasses, DbgIntfBaseTypes, sysutils, fpcunit,
  testregistry;

type

  { TTestMemManager }

  TTestMemManager = class(TTestCase)
  protected
    FCurrentTestName: String;
    FMemReader: TTestMemReader;
    FMemConvTarget: TFpDbgMemConvertorLittleEndian;
    FMemConvSelf: TFpDbgMemConvertorLittleEndian;
    FMemManager: TFpDbgMemManager;
    FDummyContext: TFpDbgSimpleLocationContext;

    procedure InitMemMgr;
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestMemMgr;
    procedure TestAddrAndSizeOperations;
  end;

implementation

procedure TTestMemManager.InitMemMgr;
begin
  FMemReader     := TTestMemReader.Create;
  FMemConvTarget := TFpDbgMemConvertorLittleEndian.Create;
  FMemConvSelf   := TFpDbgMemConvertorLittleEndian.Create;
  FMemManager    := TFpDbgMemManager.Create(FMemReader, FMemConvTarget, FMemConvSelf);
  FDummyContext := TFpDbgSimpleLocationContext.Create(FMemManager, 0, 4, 0, 0);
end;

procedure TTestMemManager.SetUp;
begin
  inherited SetUp;
  FMemReader     := nil;
  FMemConvTarget := nil;
  FMemConvSelf   := nil;
  FMemManager    := nil;
end;

procedure TTestMemManager.TearDown;
begin
  inherited TearDown;
  ReleaseRefAndNil(FDummyContext);
  FreeAndNil(FMemReader);
  FreeAndNil(FMemConvTarget);
  FreeAndNil(FMemConvSelf);
  FreeAndNil(FMemManager);
end;

procedure TTestMemManager.TestMemMgr;
var
  i, j: Integer;
  TestBaseName: String;
  Data: QWord;
  DataExt: Extended;
  DataDouble: Double;
  DataSingle: Single;
  MemValue: QWord;
  GotRes: Boolean;
  GotInt: Int64;
  GotUInt: QWord;
  GotAddr: TFpDbgMemLocation;
  GotExt: Extended;


  procedure SetData(Aval:  QWord);
  begin
    Data := Aval;
    FMemReader.RegisterValues[2] := Aval;
    FCurrentTestName := TestBaseName + ' ' + IntToHex(Aval, 16) + ': ';
  end;
  procedure CheckIntRes(AName: String; AExp: int64);
  begin
    AssertTrue(FCurrentTestName + AName + 'Read OK', GotRes);
    AssertEquals(FCurrentTestName + AName + 'Val', AExp, GotInt);
  end;
  procedure CheckUIntRes(AName: String; AExp: int64);
  begin
    AssertTrue(FCurrentTestName + AName + 'Read OK', GotRes);
    AssertEquals(FCurrentTestName + AName + 'Val', AExp, GotUInt);
  end;
  procedure CheckAddrRes(AName: String; AExp: int64);
  begin
    AssertTrue(FCurrentTestName + AName + 'Read OK', GotRes);
    AssertTrue(FCurrentTestName + AName + 'Valid', IsValidLoc(GotAddr));
    AssertEquals(FCurrentTestName + AName + 'Val', AExp, GotAddr.Address);
  end;

  Procedure DoSignedIntTests(ReadSize: Cardinal; ExpIntVal: Int64);
  var
    a: Cardinal;
  begin
    GotRes := FDummyContext.ReadSignedInt(TargetLoc(TDbgPtr(@Data)),    SizeVal(ReadSize), GotInt);
    CheckIntRes('signed target', ExpIntVal);

    GotRes := FDummyContext.ReadSignedInt(SelfLoc(@Data),               SizeVal(ReadSize), GotInt);
    CheckIntRes('signed self',   ExpIntVal);

    FMemReader.RegisterSizes[2] := ReadSize;
    GotRes := FDummyContext.ReadSignedInt(RegisterLoc(2),               SizeVal(ReadSize), GotInt);
    CheckIntRes('signed Reg ',    ExpIntVal);

    for a := ReadSize+1 to 8 do begin
      // expanded
      FMemReader.RegisterSizes[2] := ReadSize;
      GotRes := FDummyContext.ReadSignedInt(RegisterLoc(2),             SizeVal(a), GotInt);
      CheckIntRes('signed Reg  readsize='+IntToStr(a),    ExpIntVal);

      FMemReader.RegisterSizes[2] := a;
      GotRes := FDummyContext.ReadSignedInt(RegisterLoc(2),             SizeVal(ReadSize), GotInt);
      CheckIntRes('signed Reg  regsize'+IntToStr(a),    ExpIntVal);
    end;

    GotRes := FDummyContext.ReadSignedInt(ConstLoc(QWord(ExpIntVal)), SizeVal(ReadSize), GotInt);
    CheckIntRes('signed const (pre-expanded)', ExpIntVal);
  end;

  Procedure DoUnsignedIntTests(ReadSize: Cardinal; ExpIntVal: QWord);
  var
    a: Cardinal;
  begin
    GotRes := FDummyContext.ReadUnsignedInt(TargetLoc(TDbgPtr(@Data)),    SizeVal(ReadSize), GotUInt);
    CheckUIntRes('unsigned target', ExpIntVal);

    GotRes := FDummyContext.ReadUnsignedInt(SelfLoc(@Data),               SizeVal(ReadSize), GotUInt);
    CheckUIntRes('unsigned self',   ExpIntVal);

    FMemReader.RegisterSizes[2] := ReadSize;
    GotRes := FDummyContext.ReadUnsignedInt(RegisterLoc(2),               SizeVal(ReadSize), GotUInt);
    CheckUIntRes('unsigned Reg ',    ExpIntVal);

    for a := ReadSize+1 to 8 do begin
      // expanded
      FMemReader.RegisterSizes[2] := ReadSize;
      GotRes := FDummyContext.ReadUnsignedInt(RegisterLoc(2),             SizeVal(a), GotUInt);
      CheckUIntRes('unsigned Reg  readsize='+IntToStr(a),    ExpIntVal);

      FMemReader.RegisterSizes[2] := a;
      GotRes := FDummyContext.ReadUnsignedInt(RegisterLoc(2),             SizeVal(ReadSize), GotUInt);
      CheckUIntRes('unsigned Reg  regsize'+IntToStr(a),    ExpIntVal);
    end;

    GotRes := FDummyContext.ReadUnsignedInt(ConstLoc(QWord(ExpIntVal)), SizeVal(ReadSize), GotUInt);
    CheckUIntRes('unsigned const (pre-expanded)', ExpIntVal);

    //////
    // Address
    GotRes := FDummyContext.ReadAddress(TargetLoc(TDbgPtr(@Data)),    SizeVal(ReadSize), GotAddr);
    CheckAddrRes('addr target', ExpIntVal);

    GotRes := FDummyContext.ReadAddress(SelfLoc(@Data),               SizeVal(ReadSize), GotAddr);
    CheckAddrRes('addr self',   ExpIntVal);

    FMemReader.RegisterSizes[2] := ReadSize;
    GotRes := FDummyContext.ReadAddress(RegisterLoc(2),               SizeVal(ReadSize), GotAddr);
    CheckAddrRes('addr Reg ',    ExpIntVal);

    for a := ReadSize+1 to 8 do begin
      // expanded
      FMemReader.RegisterSizes[2] := ReadSize;
      GotRes := FDummyContext.ReadAddress(RegisterLoc(2),             SizeVal(a), GotAddr);
      CheckAddrRes('addr Reg  readsize='+IntToStr(a),    ExpIntVal);

      FMemReader.RegisterSizes[2] := a;
      GotRes := FDummyContext.ReadAddress(RegisterLoc(2),             SizeVal(ReadSize), GotAddr);
      CheckAddrRes('addr Reg  regsize'+IntToStr(a),    ExpIntVal);
    end;

    GotRes := FDummyContext.ReadAddress(ConstLoc(QWord(ExpIntVal)), SizeVal(ReadSize), GotAddr);
    CheckAddrRes('addr const (pre-expanded)', ExpIntVal);

    //////
    // Address
    GotAddr := FDummyContext.ReadAddress(TargetLoc(TDbgPtr(@Data)),    SizeVal(ReadSize));
    GotRes := isValidLoc(GotAddr);
    CheckAddrRes('addr target', ExpIntVal);

    GotAddr := FDummyContext.ReadAddress(SelfLoc(@Data),               SizeVal(ReadSize));
    GotRes := isValidLoc(GotAddr);
    CheckAddrRes('addr self',   ExpIntVal);

    FMemReader.RegisterSizes[2] := ReadSize;
    GotAddr := FDummyContext.ReadAddress(RegisterLoc(2),               SizeVal(ReadSize));
    GotRes := isValidLoc(GotAddr);
    CheckAddrRes('addr Reg ',    ExpIntVal);

    for a := ReadSize+1 to 8 do begin
      // expanded
      FMemReader.RegisterSizes[2] := ReadSize;
      GotAddr := FDummyContext.ReadAddress(RegisterLoc(2),             SizeVal(a));
      GotRes := isValidLoc(GotAddr);
      CheckAddrRes('addr Reg  readsize='+IntToStr(a),    ExpIntVal);

      FMemReader.RegisterSizes[2] := a;
      GotAddr := FDummyContext.ReadAddress(RegisterLoc(2),             SizeVal(ReadSize));
      GotRes := isValidLoc(GotAddr);
      CheckAddrRes('addr Reg  regsize'+IntToStr(a),    ExpIntVal);
    end;

    GotAddr := FDummyContext.ReadAddress(ConstLoc(QWord(ExpIntVal)), SizeVal(ReadSize));
    GotRes := isValidLoc(GotAddr);
    CheckAddrRes('addr const (pre-expanded)', ExpIntVal);

  end;
begin
  InitMemMgr;

  TestBaseName := 'size 1';
  SetData($00);  DoSignedIntTests(1,   0);
  SetData($08);  DoSignedIntTests(1,   8);
  SetData($7f);  DoSignedIntTests(1, 127);
  SetData($FB);  DoSignedIntTests(1,  -5);
  SetData($80);  DoSignedIntTests(1,-128);
  SetData($FF);  DoSignedIntTests(1,  -1);
  SetData($0108);  DoSignedIntTests(1,   8);

  TestBaseName := 'size 2';
  SetData($0000);  DoSignedIntTests(2,   0);
  SetData($0108);  DoSignedIntTests(2, 264);
  SetData($00FB);  DoSignedIntTests(2, 251);
  SetData($FFFB);  DoSignedIntTests(2,  -5);
  SetData($010208);  DoSignedIntTests(2, 520);

  TestBaseName := 'size 8';
  SetData($7FAAFFBBFFCCFFDD);  DoSignedIntTests(8, $7FAAFFBBFFCCFFDD);
  SetData(QWord(-3));  DoSignedIntTests(8,  -3);


  TestBaseName := 'size 1';
  SetData($00);  DoUnsignedIntTests(1,   0);
  SetData($08);  DoUnsignedIntTests(1,   8);
  SetData($7f);  DoUnsignedIntTests(1, 127);
  SetData($FB);  DoUnsignedIntTests(1, 251);
  SetData($80);  DoUnsignedIntTests(1, 128);
  SetData($FF);  DoUnsignedIntTests(1, 255);
  SetData($0108);  DoSignedIntTests(1,   8);

  FCurrentTestName := 'Extended';
  DataExt := 1.7722;
  GotRes := FDummyContext.ReadFloat(TargetLoc(TDbgPtr(@DataExt)), SizeVal(SizeOf(Extended)), GotExt);
  AssertTrue(FCurrentTestName +  'Read OK', GotRes);
  AssertEquals(FCurrentTestName + 'target not changed', 1.7722, DataExt);
  AssertEquals(FCurrentTestName + 'Val', DataExt, GotExt);

  FCurrentTestName := 'Double';
  DataDouble := 1.7722;
  GotRes := FDummyContext.ReadFloat(TargetLoc(TDbgPtr(@DataDouble)), SizeVal(SizeOf(Double)), GotExt);
  AssertTrue(FCurrentTestName +  'Read OK', GotRes);
  AssertEquals(FCurrentTestName + 'target not changed', 1.7722, DataDouble);
  AssertEquals(FCurrentTestName + 'Val', DataDouble, GotExt);

  FCurrentTestName := 'Single';
  DataSingle := 1.7722;
  GotRes := FDummyContext.ReadFloat(TargetLoc(TDbgPtr(@DataSingle)), SizeVal(SizeOf(Single)), GotExt);
  AssertTrue(FCurrentTestName +  'Read OK', GotRes);
  AssertEquals(FCurrentTestName + 'target not changed', 1.7722, DataSingle);
  AssertEquals(FCurrentTestName + 'Val', DataSingle, GotExt);


end;

procedure TTestMemManager.TestAddrAndSizeOperations;
  procedure CheckSize(AName: String; ASize: TFpDbgValueSize; ExpBytes, ExpBits: Int64);
  begin
    AssertEquals(AName + ' Byte: ', ExpBytes, ASize.Size);
    AssertEquals(AName + ' Bits: ', ExpBits, ASize.BitSize);
  end;
  procedure CheckLoc(AName: String; ALoc: TFpDbgMemLocation; ExpAddr, ExpBits: Int64);
  begin
    AssertEquals(AName + ' Byte: ', ExpAddr, ALoc.Address);
    AssertEquals(AName + ' Bits: ', ExpBits, ALoc.BitOffset);
  end;
var
  s1: TFpDbgValueSize;
  a, b: Integer;
begin
  s1 := SizeVal(  1);    CheckSize('SizeVal(  1)', s1, 1,0);
  s1 := SizeVal(  9);    CheckSize('SizeVal(  9)', s1, 9,0);
  s1 := SizeVal(  0);    CheckSize('SizeVal(  0)', s1, 0,0);
  s1 := SizeVal( -1);    CheckSize('SizeVal( -1)', s1, -1,0);
  s1 := SizeVal(-11);    CheckSize('SizeVal(-11)', s1, -11,0);
  s1 := ZeroSize;        CheckSize('ZeroSize', s1, 0,0);

  s1 := SizeFromBits(   1);    CheckSize('SizeFromBits(   1)', s1,  0, 1);
  s1 := SizeFromBits(   7);    CheckSize('SizeFromBits(   7)', s1,  0, 7);
  s1 := SizeFromBits(   8);    CheckSize('SizeFromBits(   8)', s1,  1, 0);
  s1 := SizeFromBits(   9);    CheckSize('SizeFromBits(   9)', s1,  1, 1);
  s1 := SizeFromBits( 128);    CheckSize('SizeFromBits( 128)', s1, 16, 0);
  s1 := SizeFromBits( 129);    CheckSize('SizeFromBits( 129)', s1, 16, 1);
  s1 := SizeFromBits(   0);    CheckSize('SizeFromBits(   0)', s1,  0, 0);
  s1 := SizeFromBits(  -1);    CheckSize('SizeFromBits(  -1)', s1,  0,-1);
  s1 := SizeFromBits(  -7);    CheckSize('SizeFromBits(  -7)', s1,  0,-7);
  s1 := SizeFromBits(  -8);    CheckSize('SizeFromBits(  -8)', s1, -1,-0);
  s1 := SizeFromBits(  -9);    CheckSize('SizeFromBits(  -9)', s1, -1,-1);
  s1 := SizeFromBits(-128);    CheckSize('SizeFromBits(-128)', s1,-16,-0);
  s1 := SizeFromBits(-129);    CheckSize('SizeFromBits(-129)', s1,-16,-1);

  // =
  for a := -50 to 50 do
  for b := -50 to 50 do
  if a = b then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')=SizeFromBits('+inttostr(b)+')', SizeFromBits(a)=SizeFromBits(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')=SizeFromBits('+inttostr(b)+')', SizeFromBits(a)=SizeFromBits(b));

  // =
  for a := -50 to 50 do
  for b := -7 to 7 do
  if a = b*8 then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')=('+inttostr(b)+')', SizeFromBits(a)=(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')=('+inttostr(b)+')', SizeFromBits(a)=(b));

  // >
  for a := -50 to 50 do
  for b := -7 to 7 do
  if a > b*8 then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')>('+inttostr(b)+')', SizeFromBits(a)>(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')>('+inttostr(b)+')', SizeFromBits(a)>(b));
  // >=
  for a := -50 to 50 do
  for b := -7 to 7 do
  if a >= b*8 then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')>=('+inttostr(b)+')', SizeFromBits(a)>=(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')>=('+inttostr(b)+')', SizeFromBits(a)>=(b));
  // <
  for a := -50 to 50 do
  for b := -7 to 7 do
  if a < b*8 then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')<('+inttostr(b)+')', SizeFromBits(a)<(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')<('+inttostr(b)+')', SizeFromBits(a)<(b));
  // <=
  for a := -50 to 50 do
  for b := -7 to 7 do
  if a <= b*8 then
    AssertTrue('True: SizeFromBits('+inttostr(a)+')<=('+inttostr(b)+')', SizeFromBits(a)<=(b))
  else
    AssertFalse('False: SizeFromBits('+inttostr(a)+')<=('+inttostr(b)+')', SizeFromBits(a)<=(b));

a:=-50;
b:=-50;
    AssertTrue('=: SizeFromBits('+inttostr(a)+')+ SizeFromBits('+inttostr(b)+' = SizeFromBits('+inttostr(a+b)+'))',
               SizeFromBits(a)+ SizeFromBits(b) = SizeFromBits(a+b));
    AssertTrue('=: SizeFromBits('+inttostr(a)+')- SizeFromBits('+inttostr(b)+' = SizeFromBits('+inttostr(a-b)+'))',
               SizeFromBits(a)- SizeFromBits(b) = SizeFromBits(a-b));

  // +
  for a := -50 to 50 do
  for b := -50 to 50 do
    AssertTrue('=: SizeFromBits('+inttostr(a)+')+ SizeFromBits('+inttostr(b)+' = SizeFromBits('+inttostr(a+b)+'))',
               SizeFromBits(a)+ SizeFromBits(b) = SizeFromBits(a+b));

  // -
  for a := -50 to 50 do
  for b := -50 to 50 do
    AssertTrue('=: SizeFromBits('+inttostr(a)+')- SizeFromBits('+inttostr(b)+' = SizeFromBits('+inttostr(a-b)+'))',
               SizeFromBits(a)- SizeFromBits(b) = SizeFromBits(a-b));

  // *
  for a := -50 to 50 do
  for b := -30 to 30 do
    AssertTrue('=: SizeFromBits('+inttostr(a)+')* ('+inttostr(b)+' = SizeFromBits('+inttostr(a-b)+'))',
               SizeFromBits(a)* (b) = SizeFromBits(a*b));


  //// X
  //for a := -50 to 50 do
  //for b := -7 to 7 do
  //if a X b*8 then
  //  AssertTrue('True: SizeFromBits('+inttostr(a)+')X('+inttostr(b)+')', SizeFromBits(a)X(b));
  //else
  //  AssertFalse('False: SizeFromBits('+inttostr(a)+')X('+inttostr(b)+')', SizeFromBits(a)X(b));


  CheckLoc('TargetLoc(500)', TargetLoc(500), 500, 0);
  CheckLoc('TargetLoc(501)', TargetLoc(501), 501, 0);

  CheckLoc('AddBitOffset(TargetLoc(500),  0)', AddBitOffset(TargetLoc(500),   0), 500,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),  1)', AddBitOffset(TargetLoc(500),   1), 500,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),  7)', AddBitOffset(TargetLoc(500),   7), 500,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),  8)', AddBitOffset(TargetLoc(500),   8), 501,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),  9)', AddBitOffset(TargetLoc(500),   9), 501,   1);
  CheckLoc('AddBitOffset(TargetLoc(500), 16)', AddBitOffset(TargetLoc(500),  16), 502,   0);
  CheckLoc('AddBitOffset(TargetLoc(500), 33)', AddBitOffset(TargetLoc(500),  33), 504,   1);
  CheckLoc('AddBitOffset(TargetLoc(500), -1)', AddBitOffset(TargetLoc(500),  -1), 499,   7);
  CheckLoc('AddBitOffset(TargetLoc(500), -2)', AddBitOffset(TargetLoc(500),  -2), 499,   6);
  CheckLoc('AddBitOffset(TargetLoc(500), -7)', AddBitOffset(TargetLoc(500),  -7), 499,   1);
  CheckLoc('AddBitOffset(TargetLoc(500), -8)', AddBitOffset(TargetLoc(500),  -8), 499,   0);
  CheckLoc('AddBitOffset(TargetLoc(500), -9)', AddBitOffset(TargetLoc(500),  -9), 498,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),-16)', AddBitOffset(TargetLoc(500), -16), 498,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),-33)', AddBitOffset(TargetLoc(500), -33), 495,   7);

  CheckLoc('TargetLoc(500) + SizeFromBits(  0)', TargetLoc(500) + SizeFromBits(  0), 500,   0);
  CheckLoc('TargetLoc(500) + SizeFromBits(  1)', TargetLoc(500) + SizeFromBits(  1), 500,   1);
  CheckLoc('TargetLoc(500) + SizeFromBits(  7)', TargetLoc(500) + SizeFromBits(  7), 500,   7);
  CheckLoc('TargetLoc(500) + SizeFromBits(  8)', TargetLoc(500) + SizeFromBits(  8), 501,   0);
  CheckLoc('TargetLoc(500) + SizeFromBits(  9)', TargetLoc(500) + SizeFromBits(  9), 501,   1);
  CheckLoc('TargetLoc(500) + SizeFromBits( 16)', TargetLoc(500) + SizeFromBits( 16), 502,   0);
  CheckLoc('TargetLoc(500) + SizeFromBits( 33)', TargetLoc(500) + SizeFromBits( 33), 504,   1);
  CheckLoc('TargetLoc(500) + SizeFromBits( -1)', TargetLoc(500) + SizeFromBits( -1), 499,   7);
  CheckLoc('TargetLoc(500) + SizeFromBits( -2)', TargetLoc(500) + SizeFromBits( -2), 499,   6);
  CheckLoc('TargetLoc(500) + SizeFromBits( -7)', TargetLoc(500) + SizeFromBits( -7), 499,   1);
  CheckLoc('TargetLoc(500) + SizeFromBits( -8)', TargetLoc(500) + SizeFromBits( -8), 499,   0);
  CheckLoc('TargetLoc(500) + SizeFromBits( -9)', TargetLoc(500) + SizeFromBits( -9), 498,   7);
  CheckLoc('TargetLoc(500) + SizeFromBits(-16)', TargetLoc(500) + SizeFromBits(-16), 498,   0);
  CheckLoc('TargetLoc(500) + SizeFromBits(-33)', TargetLoc(500) + SizeFromBits(-33), 495,   7);

  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(  0)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(  0), 500,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(  1)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(  1), 500,   2);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(  7)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(  7), 501,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(  8)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(  8), 501,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(  9)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(  9), 501,   2);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( 16)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( 16), 502,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( 33)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( 33), 504,   2);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( -1)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( -1), 500,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( -2)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( -2), 499,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( -7)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( -7), 499,   2);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( -8)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( -8), 499,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits( -9)', AddBitOffset(TargetLoc(500),1) + SizeFromBits( -9), 499,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(-16)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(-16), 498,   1);
  CheckLoc('AddBitOffset(TargetLoc(500),1) + SizeFromBits(-33)', AddBitOffset(TargetLoc(500),1) + SizeFromBits(-33), 496,   0);

  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(  0)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(  0), 500,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(  1)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(  1), 501,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(  7)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(  7), 501,   6);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(  8)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(  8), 501,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(  9)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(  9), 502,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( 16)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( 16), 502,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( 33)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( 33), 505,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( -1)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( -1), 500,   6);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( -2)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( -2), 500,   5);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( -7)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( -7), 500,   0);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( -8)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( -8), 499,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits( -9)', AddBitOffset(TargetLoc(500),7) + SizeFromBits( -9), 499,   6);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(-16)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(-16), 498,   7);
  CheckLoc('AddBitOffset(TargetLoc(500),7) + SizeFromBits(-33)', AddBitOffset(TargetLoc(500),7) + SizeFromBits(-33), 496,   6);


end;

initialization

  RegisterTest(TTestMemManager);
end.


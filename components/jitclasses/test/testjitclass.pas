unit TestJitClass;

{$mode objfpc}{$H+}
{$ModeSwitch typehelpers}
{$inline off}
{$WARN 4055 off : Conversion between ordinals and pointers is not portable}
interface

uses
  Classes, SysUtils, TypInfo, Math, fpcunit, testutils, testregistry,
  JitClass, JitTypes, LazLogger, Rtti;

type

  TInitProcedure = procedure of object;

  { TPropListTest }

  TPropListTest = class
  private
    FOwner: TTestCase;
    FObject: TObject;
    FPropCount: Integer;
    FPropList: PPropList;
  protected
    function GetPPropInfo(APropName: String): PPropInfo;
  public
    constructor Create(AnOwner: TTestCase; AnObject: TObject);
    destructor Destroy; override;

    procedure AssertPropCount(AName: String; AExpCount: Integer);
    procedure AssertPropOffsets(AName: String='');
    procedure AssertHasProp(AName, APropName: String; AExpType: TTypeKind);
    procedure AssertHasProp(AName, APropName: String; AExpType: TTypeKind; AValue: Int64);
    procedure AssertHasProp(AName, APropName: String; AExpType: TTypeKind; AValue: String);
  end;

  { TJitClassTest }

  TJitClassTest = class(TTestCase)
  private
    FFreedObjList, FFreedMemList: TList;

    procedure DoObjFreed(Sender: TObject);
    procedure AssertWasObjFreed(AName: String; AnObj: TObject);
    procedure AssertWasNotObjFreed(AName: String; AnObj: TObject);

    procedure StartMemMonitor;
    procedure StartAndClearMemMonitor;
    procedure StopMemMonitor;
    procedure ClearMemMonitor;
    procedure AssertWasMemFreed(AName: String; AMem: Pointer);
    procedure AssertWasNotMemFreed(AName: String; AMem: Pointer);

    procedure DumpPropInfo(AClass: TClass);
  private
    // Methods for circle ref testing
    FJitTypeLib: TJitTypeLibrary;
    FJitCreator: array [1..3] of TJitClassCreator;

    function GetCreator(ABase: TClass; AName: String; PropClass: String = '';
      ATakeCreatorOwnerShip: Boolean = False): TJitClassCreator;
    function GetCreator(ABase: TJitClassCreator; AName: String; PropClass: String = '';
      ATakeCreatorOwnerShip: Boolean = False): TJitClassCreator;
    procedure InitTwoClasses;
    procedure InitTwoClassesWithOneSelfRef;
    procedure InitTwoClassesWithDoubleLink;
    procedure InitTwoClassesAnchestor;
    procedure InitTwoClassesAnchestorWithAnchestorProp;
    procedure InitTwoClassesAnchestorWithAnchestorPropOneWay; // not for auto ref count tests // NOT a circle
    procedure InitThreeClasses;
    procedure InitThreeClassesWithOneSelfRef;
    procedure InitThreeClassesWithOneDoubleLink;
    procedure InitThreeClassesWithSubLoop;
    procedure InitThreeClassesWithSubLoopAndOneSelfRef;
    procedure InitThreeClassesWithTwoSubLoop;
    procedure InitThreeClassesChained;
    procedure InitThreeClassesChainedIndirect;
    procedure InitThreeClassesOneAnchestor;
    procedure InitThreeClassesOneAnchestorIndirect;
    procedure InitThreeClassesAnchestorParallel;
    procedure InitThreeClassesAnchestorParallelIndirect; // 5 classes
    procedure InitThreeClassesAnchestorParallelAndChildRef;
    procedure InitThreeClassesAnchestorParallelAndChildRefIndirect;
    procedure InitThreeClassesAnchestorParallelAndChildRefIndirect_2;
    procedure InitThreeClassesAnchestorParallelAndChildLoop;
    procedure InitThreeClassesAnchestorParallelAndChildLoopIndirect;
    procedure InitThreeClassesAnchestorParallelAndChildLoopIndirect_2;
    procedure InitThreeClassesTwoAnchestor;
    procedure InitThreeClassesTwoAnchestorIndirect;

    procedure TestTwoClassRefCount(AnInitProc: TInitProcedure);
    procedure TestThreeClassRefCount(AnInitProc: TInitProcedure);

  protected
    procedure DoStreamCopy(AJitSource, AJitDest: TComponent);
    procedure DoTestSimpleClass(AJitClass, AnExpParentClass: TComponentClass);

    procedure TearDown; override;
  published
    procedure TestSimpleClass;        // Test unmodified Jit
    procedure TestSimpleClassNested;  // Test unmodified Jit, with Jit as base
    procedure TestJitPropSimple;
    procedure TestJitParseClass;
    procedure TestJitPropCircularClassDef;
    procedure TestManagedJitProp;
    procedure TestRefCount;
    procedure TestRefCountProp;
    procedure TestRefCountClassCircle;
    procedure TestRefCountMethodCircle;
    procedure TestParseJitType;   // Parser errors / also run with valgrind
    procedure TestSetEnum;
    procedure TestMethods;
  end;

implementation

var
  MMgr: TMemoryManager;
  HeapState: TFPCHeapStatus;
  GlobFreedMemList: TList;
  InMyFreeMem: Integer;

function GetMemUsed: integer;
begin
  GetMemoryManager(MMgr);
  HeapState := MMgr.GetFPCHeapStatus();
  Result := HeapState.CurrHeapUsed;
end;

var
  TestVirt: Integer;
  OrigFreemem             : Function(p:pointer):ptruint;
  OrigFreememSize         : Function(p:pointer;Size:ptruint):ptruint;

Function MyFreemem(p:pointer):ptruint;
begin
  inc(InMyFreeMem);
  Result := OrigFreemem(p);
  if (InMyFreeMem = 1) and (GlobFreedMemList <> nil) then begin
    GlobFreedMemList.Add(p);
  end;
  dec(InMyFreeMem);
end;
Function MyFreememSize(p:pointer;Size:ptruint):ptruint;
begin
  inc(InMyFreeMem);
  Result := OrigFreememSize(p,Size);
  if (InMyFreeMem = 1) and (GlobFreedMemList <> nil) then begin
    GlobFreedMemList.Add(p);
  end;
  dec(InMyFreeMem);
end;


type

  { TMyBaseClass }

  TMyBaseClass = class(TComponent)
  private
    FMyBaseInt: Integer;
  public
    procedure MyVirt; virtual;
  published
    property MyBaseInt: Integer read FMyBaseInt write FMyBaseInt;
  end;

  { TMyClass }

  TMyClass = class(TMyBaseClass)
  private
    FMyLines: TStringList;
    FMyEvent: TNotifyEvent;
    FMyText: AnsiString;
    procedure SetMyLines(AValue: TStringList);
  protected
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
  public
    FMyDynArray: Array of integer;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure MyVirt; override;
  published
    MyField: TMyBaseClass;
    procedure MyFoo(Sender: TObject);
    property MyLines: TStringList read FMyLines write SetMyLines;
    property MyText: AnsiString read FMyText write FMyText;
    property MyEvent: TNotifyEvent read FMyEvent write FMyEvent;
  end;

const
  MYCLASS_PROP_COUNT = 6;

{ TMyBaseClass }

procedure TMyBaseClass.MyVirt;
begin
  TestVirt := 1;
end;

{ TMyClass }

procedure TMyClass.SetMyLines(AValue: TStringList);
begin
  if FMyLines = AValue then Exit;
  FMyLines.Assign(AValue);
end;

procedure TMyClass.GetChildren(Proc: TGetChildProc; Root: TComponent);
begin
  inherited GetChildren(Proc, Root);
  if MyField <> nil then
    Proc(MyField);
end;

constructor TMyClass.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMyLines := TStringList.Create;
end;

destructor TMyClass.Destroy;
begin
  FMyLines.Free;
  MyField.Free;
  inherited Destroy;
end;

procedure TMyClass.MyVirt;
begin
  TestVirt := 2;
end;

procedure TMyClass.MyFoo(Sender: TObject);
begin
//
end;

{ TPropListTest }

function TPropListTest.GetPPropInfo(APropName: String): PPropInfo;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to FPropCount-1 do
    if FPropList^[i]^.Name = APropName then
      exit(FPropList^[i]);
end;

constructor TPropListTest.Create(AnOwner: TTestCase; AnObject: TObject);
begin
  FOwner := AnOwner;
  FObject := AnObject;
  FPropCount := GetPropList(AnObject, FPropList);
end;

destructor TPropListTest.Destroy;
begin
  if FPropCount > 0 then
    Freemem(FPropList);
  inherited Destroy;
end;

procedure TPropListTest.AssertPropCount(AName: String; AExpCount: Integer);
begin
  FOwner.AssertEquals(AName+' (PropCount)', AExpCount, FPropCount);
end;

procedure TPropListTest.AssertPropOffsets(AName: String);
var
  CurPvmt, ParPvmt: pvmt;
  PropInf: PPropInfo;
  MaxOffs, MinOffs: SizeInt;
  ParMaxOffs: SmallInt;
  PropCount, i: Integer;
begin
  CurPvmt := PPVmt(FObject)^;
  PropCount := FPropCount;
  ParPvmt := CurPvmt^.vParent;
  MaxOffs := CurPvmt^.vInstanceSize;
  if ParPvmt <> nil then begin
    MinOffs := ParPvmt^.vInstanceSize;
    ParMaxOffs := GetTypeData(ParPvmt^.vTypeInfo)^.Propcount;
  end
  else begin
    ParMaxOffs := -1;
    MinOffs := 0
  end;

  FOwner.AssertTrue('', PropCount > 0);
  FOwner.AssertTrue('', PropCount >= ParMaxOffs);
  for i := 0 to PropCount-1 do begin
    PropInf := FPropList^[i];
    if i >= ParMaxOffs then
      FOwner.AssertTrue('', PropInf^.PropProcs = (ptConst shl 4));

    if PropInf^.PropProcs = 0 then begin
      //if PtrUInt(PropInf^.GetProc) <> 0 then
        FOwner.AssertTrue(AName+' (GetProc)', (PtrUInt(PropInf^.GetProc) <> 0));
        FOwner.AssertTrue(AName+' (GetProc)', (PtrUInt(PropInf^.GetProc) < MaxOffs));
      if PtrUInt(PropInf^.SetProc) <> 0 then
        FOwner.AssertTrue(AName+' (SetProc))', (PtrUInt(PropInf^.SetProc) < MaxOffs));

      if i >= ParMaxOffs then begin // belong to CurPvmt / must be bigger than MinOffs;
        //if PtrUInt(PropInf^.GetProc) <> 0 then
          FOwner.AssertTrue(AName+' (GetProc)', (PtrUInt(PropInf^.GetProc) >= MinOffs));
        if PtrUInt(PropInf^.SetProc) <> 0 then
          FOwner.AssertTrue(AName+' (SetProc))', (PtrUInt(PropInf^.SetProc) >= MinOffs));
      end;
    end;
  end;
end;

procedure TPropListTest.AssertHasProp(AName, APropName: String; AExpType: TTypeKind);
var
  PropInfo: PPropInfo;
begin
  PropInfo := GetPPropInfo(APropName);
  FOwner.AssertTrue(AName+' (HasProp '+APropName+')', PropInfo <> nil);
  FOwner.AssertTrue(AName+' (HasPropType '+APropName+')', PropInfo^.PropType <> nil);
  FOwner.AssertEquals(AName+' (HasPropType '+APropName+' match)', ord(AExpType), ord(PropInfo^.PropType^.Kind));
end;

procedure TPropListTest.AssertHasProp(AName, APropName: String; AExpType: TTypeKind; AValue: Int64);
var
  PropInfo: PPropInfo;
begin
  PropInfo := GetPPropInfo(APropName);
  FOwner.AssertTrue(AName+' (HasProp '+APropName+')', PropInfo <> nil);
  FOwner.AssertTrue(AName+' (HasPropType '+APropName+')', PropInfo^.PropType <> nil);
  FOwner.AssertEquals(AName+' (HasPropType '+APropName+' match)', ord(AExpType), ord(PropInfo^.PropType^.Kind));

  FOwner.AssertEquals(AName+' (Val for '+APropName+')', AValue, GetOrdProp(FObject, PropInfo));
end;

procedure TPropListTest.AssertHasProp(AName, APropName: String; AExpType: TTypeKind; AValue: String);
var
  PropInfo: PPropInfo;
begin
  PropInfo := GetPPropInfo(APropName);
  FOwner.AssertTrue(AName+' (HasProp '+APropName+')', PropInfo <> nil);
  FOwner.AssertTrue(AName+' (HasPropType '+APropName+')', PropInfo^.PropType <> nil);
  FOwner.AssertEquals(AName+' (HasPropType '+APropName+' match)', ord(AExpType), ord(PropInfo^.PropType^.Kind));

  FOwner.AssertEquals(AName+' (Val for '+APropName+')', AValue, GetStrProp(FObject, PropInfo));
end;

{ TJitClassTest }

procedure TJitClassTest.DoObjFreed(Sender: TObject);
begin
  if FFreedObjList = nil then
    FFreedObjList := TList.Create;
  FFreedObjList.Add(Pointer(Sender));
end;

procedure TJitClassTest.AssertWasObjFreed(AName: String; AnObj: TObject);
begin
  AssertTrue(AName, (FFreedObjList <> nil) and (FFreedObjList.IndexOf(Pointer(AnObj)) >= 0));
end;

procedure TJitClassTest.AssertWasNotObjFreed(AName: String; AnObj: TObject);
begin
  AssertFalse(AName, (FFreedObjList <> nil) and (FFreedObjList.IndexOf(Pointer(AnObj)) >= 0));
end;

procedure TJitClassTest.StartMemMonitor;
begin
  if FFreedMemList = nil then
    FFreedMemList := TList.Create;

  GlobFreedMemList := FFreedMemList;
end;

procedure TJitClassTest.StartAndClearMemMonitor;
begin
  ClearMemMonitor;
  StartMemMonitor;
end;

procedure TJitClassTest.StopMemMonitor;
begin
  GlobFreedMemList := nil;
end;

procedure TJitClassTest.ClearMemMonitor;
begin
  inc(InMyFreeMem);
  if FFreedMemList <> nil then
    FFreedMemList.Clear;
  dec(InMyFreeMem);
end;

procedure TJitClassTest.AssertWasMemFreed(AName: String; AMem: Pointer);
begin
  AssertTrue(AName, (FFreedMemList <> nil) and (FFreedMemList.IndexOf(AMem) >= 0));
end;

procedure TJitClassTest.AssertWasNotMemFreed(AName: String; AMem: Pointer);
begin
  AssertFalse(AName, (FFreedMemList <> nil) and (FFreedMemList.IndexOf(AMem) >= 0));
end;

procedure TJitClassTest.DumpPropInfo(AClass: TClass);
var
  PropCount, i: Integer;
  PropList: PPropList;
begin
  PropCount := GetPropList(AClass, PropList);
  if PropCount>0 then begin
    try
      DebugLn(['--- ', PropCount, '  InstSize ', PVmt(AClass)^.vInstanceSize]);
      for i := 0 to PropCount-1 do
        DebugLn('## %25s  %2d  // %2d %2d  // %10d     %d  %d  %d ', [
           PropList^[i]^.Name, PropList^[i]^.NameIndex,
           PropList^[i]^.Index, PropList^[i]^.Default,
           ptruint(PropList^[i]^.PropType),
           ptruint(PropList^[i]^.GetProc),
           ptruint(PropList^[i]^.SetProc),
           ptruint(PropList^[i]^.StoredProc)
        ]);
    finally
      Freemem(PropList);
    end;
  end;
end;

procedure TJitClassTest.DoStreamCopy(AJitSource, AJitDest: TComponent);
var
  strm: TMemoryStream;
  Driver: TAbstractObjectWriter;
  Writer: TWriter;
  Reader: TReader;
begin
  strm := TMemoryStream.Create;
  Driver := TBinaryObjectWriter.Create(strm,4096);
  Writer := TWriter.Create(Driver);
  Writer.WriteRootComponent(AJitSource);
  Driver.Free;
  Writer.Free;

  strm.Position := 0;
  Reader := TReader.Create(strm, 4096);
  Reader.ReadRootComponent(AJitDest);
  Reader.Free;

  strm.Free;
end;

procedure TJitClassTest.DoTestSimpleClass(AJitClass,
  AnExpParentClass: TComponentClass);
var
  JitObject, JitObject2: TMyClass;
  MemUsed, MemUsed2, PropCount, i: Integer;
  PropList: PPropList;
  TestProps: TPropListTest;
begin
  AssertEquals('Got class-name',    'TJitTestSimpleClass', AJitClass.ClassName);
  AssertEquals('Got unit-name',     'foo.pas',             AJitClass.UnitName);
  AssertEquals('Got class-parent',  AnExpParentClass,      AJitClass.ClassParent);
  AssertEquals('Got instance-size', TMyClass.InstanceSize, AJitClass.InstanceSize);

  MemUsed := GetMemUsed;

  // Call the virtual method
  JitObject := TMyClass(AJitClass.Create(nil));
  TMyBaseClass(JitObject).MyVirt;
  AssertEquals('virt meth call', 2, TestVirt);

  // check all memory is freed
  JitObject.Free;
  MemUsed2 := GetMemUsed;
  AssertEquals('Memory freed', MemUsed, MemUsed2);

  // check all memory is freed / including managed types
  JitObject := TMyClass(AJitClass.Create(nil));
  SetLength(JitObject.FMyDynArray, 100);
  JitObject.Free;
  MemUsed2 := GetMemUsed;
  AssertEquals('Memory freed (dyn array)', MemUsed, MemUsed2);

  // check RTTI properties
  JitObject := TMyClass(AJitClass.Create(nil));
  SetLength(JitObject.FMyDynArray, 1);
  JitObject.MyBaseInt := 88123;
  JitObject.MyText := 'SomeText';
  JitObject.MyLines.Text := 'Line123';
  JitObject.MyEvent := @JitObject.MyFoo;
  JitObject.MyField := TMyBaseClass.Create(JitObject);
  JitObject.MyField.Name := 'MyField';

  TestProps := TPropListTest.Create(Self, JitObject);
  try
    TestProps.AssertPropCount('', 6);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'MyBaseInt', tkInteger, 88123);
    TestProps.AssertHasProp('', 'MyText', tkAnsiString, 'SomeText');
    TestProps.AssertHasProp('', 'MyLines', tkClass);
    TestProps.AssertHasProp('', 'MyEvent', tkMethod);
  finally
    TestProps.Free;
  end;

  // stream and copy
  JitObject2 := TMyClass(AJitClass.Create(nil));
  DoStreamCopy(JitObject, JitObject2);

  AssertEquals('Stream-copied BaseInt', 88123,      JitObject2.MyBaseInt);
  AssertEquals('Stream-copied MyText',  'SomeText', JitObject2.MyText);
  AssertEquals('Stream-copied MyLines', 'Line123', JitObject2.MyLines[0]);
  AssertTrue  ('Stream-copied MyEvent', @JitObject.MyFoo = JitObject2.MyEvent);
  AssertTrue  ('Stream-copied MyField', JitObject2.MyField <> nil);
  AssertEquals('Stream-copied MyField', 'MyField', JitObject2.MyField.Name);

  TestProps := TPropListTest.Create(Self, JitObject2);
  try
    TestProps.AssertPropCount('', 6);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'MyBaseInt', tkInteger, 88123);
    TestProps.AssertHasProp('', 'MyText', tkAnsiString, 'SomeText');
    TestProps.AssertHasProp('', 'MyLines', tkClass);
    TestProps.AssertHasProp('', 'MyEvent', tkMethod);
  finally
    TestProps.Free;
  end;

  JitObject2.Free;



  PropCount := GetPropList(JitObject, PropList);
  if PropCount>0 then begin
    try
      for i := 0 to PropCount-1 do
        WriteLn('## ',
          ' / ', PropList^[i]^.Name,
          ' / ', PropList^[i]^.NameIndex,
          ' / ', PropList^[i]^.Index,
          ' / ', PropList^[i]^.Default,
          ' / ', ptruint(PropList^[i]^.PropType),
          ' / ', ptruint(PropList^[i]^.GetProc),
          ' / ', ptruint(PropList^[i]^.SetProc),
          ' / ', ptruint(PropList^[i]^.StoredProc)

        );
    finally
      Freemem(PropList);
    end;
  end;

  // RTTI methods
  AssertEquals('Func of Addr', PtrUint(@TMyClass.MyFoo), PtrUint(AJitClass.MethodAddress('MyFoo')));
  AssertEquals('Addr of Func', 'MyFoo', AJitClass.MethodName(@TMyClass.MyFoo));

  AssertEquals('Func of Addr', PtrUint(@TMyClass.MyFoo), PtrUint(JitObject.MethodAddress('MyFoo')));
  AssertEquals('Addr of Func', 'MyFoo', JitObject.MethodName(@TMyClass.MyFoo));

  AssertEquals('Func of Addr', PtrUint(@TMyClass.MyFoo), PtrUint(JitObject.ClassType.MethodAddress('MyFoo')));
  AssertEquals('Addr of Func', 'MyFoo', JitObject.ClassType.MethodName(@TMyClass.MyFoo));

  AssertEquals('Func of none Addr', 0, PtrUint(AJitClass.MethodAddress('NotHere')));
  AssertEquals('Addr of none Func', '', AJitClass.MethodName(codepointer($11002233)));

  // RTTI fields

  AssertEquals('Addr of Field', PtrUint(@JitObject.MyField), PtrUint(JitObject.FieldAddress('MyField')));
  AssertEquals('Addr of none Field', 0, PtrUint(JitObject.FieldAddress('NotHere')));

  JitObject.Free;
end;

procedure TJitClassTest.TearDown;
begin
  inherited TearDown;
  GlobFreedMemList := nil;
  FreeAndNil(FFreedObjList);
  FreeAndNil(FFreedMemList);
end;

procedure TJitClassTest.TestSimpleClass;
var
  JitCreator: TJitClassCreator;
type
  TTa= array of record a,b,c: cardinal; end; // vartype -1 // elSize 12
  TTb= array of record a,b,c: string; end; // vartype -1 // elSize 24
  TTc= array of byte; // vartype 17 // elSize 1
var a,b,c: PTypeInfo;
begin
a := PTypeInfo(TypeInfo(tta));
b := PTypeInfo(TypeInfo(ttb));
c := PTypeInfo(TypeInfo(ttc));
  JitCreator := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleClass', 'foo.pas');
  DoTestSimpleClass(TComponentClass(JitCreator.JitClass), TMyClass);
  JitCreator.Free;
end;

procedure TJitClassTest.TestSimpleClassNested;
var
  JitCreator, JitCreatorNested: TJitClassCreator;
begin
  (* Include an empty JitClass as parent
     Test that a JitClass can be used as parent
  *)
  JitCreator       := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleOuterClass', 'foo.pas');
  JitCreatorNested := TJitClassCreator.Create(JitCreator.JitClass, 'TJitTestSimpleClass', 'foo.pas');
  DoTestSimpleClass(TComponentClass(JitCreatorNested.JitClass), TComponentClass(JitCreator.JitClass));
  JitCreator.Free;
  JitCreatorNested.Free;
end;

procedure TJitClassTest.TestJitPropSimple;
var
  JitCreator: TJitClassCreator;
  JitClass: TComponentClass;
  JitObject, JitObject2: TComponent;
  TestProps: TPropListTest;
  PropList: PPropList;
  PropCount, i: Integer;
begin
  JitCreator       := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleOuterClass', 'foo.pas');

  JitCreator.JitProperties.Add('JitInt32', 'longint');
  JitCreator.JitProperties.Add('JitInt64', 'int64');
  JitCreator.JitProperties.Add('JitWord1', 'word');
  JitCreator.JitProperties.Add('JitWord2', 'Word');
  JitCreator.JitProperties.Add('JitString', 'AnsiString');

  JitClass := TComponentClass(JitCreator.JitClass);
  JitObject := JitClass.Create(nil);


  PropCount := GetPropList(JitObject, PropList);
  if PropCount>0 then begin
    try
      for i := 0 to PropCount-1 do
        WriteLn(format('## %15s %2d / %2d %10d / %x   %d %d %d', [
          AnsiString(PropList^[i]^.Name),
          PropList^[i]^.NameIndex,
          PropList^[i]^.Index,
          PropList^[i]^.Default,
          ptruint(PropList^[i]^.PropType),
          ptruint(PropList^[i]^.GetProc),
          ptruint(PropList^[i]^.SetProc),
          ptruint(PropList^[i]^.StoredProc)
        ]));
    finally
      Freemem(PropList);
    end;
  end;

  TestProps := TPropListTest.Create(Self, JitObject);
  try
    TestProps.AssertPropCount('', 11);
    TestProps.AssertPropOffsets;
    //TestProps.AssertHasProp('', 'MyBaseInt', tkInteger, 88123);
    //TestProps.AssertHasProp('', 'MyText', tkAnsiString, 'SomeText');
    TestProps.AssertHasProp('', 'MyLines', tkClass);
    TestProps.AssertHasProp('', 'MyEvent', tkMethod);

    TestProps.AssertHasProp('', 'JitInt32', tkInteger);
    TestProps.AssertHasProp('', 'JitInt64', tkInt64);
    TestProps.AssertHasProp('', 'JitWord1', tkInteger);
    TestProps.AssertHasProp('', 'JitWord2', tkInteger);
    TestProps.AssertHasProp('', 'JitString', tkAString);
  finally
    TestProps.Free;
  end;

  SetOrdProp(JitObject, 'JitInt32', $66771122);
  SetOrdProp(JitObject, 'JitInt64', $7557444475574444);
  SetOrdProp(JitObject, 'JitWord1', $2332);
  SetOrdProp(JitObject, 'JitWord2', $4334);
  SetStrProp(JitObject, 'JitString', 'Hello World');

  AssertEquals(GetOrdProp(JitObject, 'JitInt32'), $66771122);
  AssertEquals(GetOrdProp(JitObject, 'JitInt64'), $7557444475574444);
  AssertEquals(GetOrdProp(JitObject, 'JitWord1'), $2332);
  AssertEquals(GetOrdProp(JitObject, 'JitWord2'), $4334);
  AssertEquals(GetStrProp(JitObject, 'JitString'), 'Hello World');

  // set in reverse order
  SetStrProp(JitObject, 'JitString', 'Hello World');
  SetOrdProp(JitObject, 'JitWord2', $4334);
  SetOrdProp(JitObject, 'JitWord1', $2332);
  SetOrdProp(JitObject, 'JitInt64', $7557444475574444);
  SetOrdProp(JitObject, 'JitInt32', $66771122);

  AssertEquals(GetOrdProp(JitObject, 'JitInt32'), $66771122);
  AssertEquals(GetOrdProp(JitObject, 'JitInt64'), $7557444475574444);
  AssertEquals(GetOrdProp(JitObject, 'JitWord1'), $2332);
  AssertEquals(GetOrdProp(JitObject, 'JitWord2'), $4334);
  AssertEquals(GetStrProp(JitObject, 'JitString'), 'Hello World');

  JitObject2 := JitClass.Create(nil);
  DoStreamCopy(JitObject, JitObject2);
  AssertEquals(GetOrdProp(JitObject2, 'JitInt32'), $66771122);
  AssertEquals(GetOrdProp(JitObject2, 'JitInt64'), $7557444475574444);
  AssertEquals(GetOrdProp(JitObject2, 'JitWord1'), $2332);
  AssertEquals(GetOrdProp(JitObject2, 'JitWord2'), $4334);
  AssertEquals(GetStrProp(JitObject2, 'JitString'), 'Hello World');

  JitObject2.Free;
  JitObject.Free;
  JitCreator.Free;
end;

procedure TJitClassTest.TestJitParseClass;
var
  JitCreator: TJitClassCreator;
begin
  JitCreator := TJitClassCreator.Create(TMyClass, 'TJitTestClass', 'foo');
  JitCreator.JitProperties.ParseFromClassDeclaration(
    'class(foo)' +
    'published' +
    '  property TestProp1: int64 read foo write foo;' +
    '  property TestProp2: int64 read foo;' +
    'a: word;' +
    'function foo: boolean;' +
    '  property TestProp3: int64 read foo;' +
    'end'
  );

  AssertTrue(JitCreator.JitProperties.IndexOf('TestProp1') >= 0);
  AssertTrue(JitCreator.JitProperties.IndexOf('TestProp2') >= 0);
  AssertTrue(JitCreator.JitProperties.IndexOf('TestProp3') >= 0);
  AssertTrue(JitCreator.JitProperties.IndexOf('TestFoo') < 0);

  JitCreator.Free;
end;

procedure TJitClassTest.TestJitPropCircularClassDef;
  procedure DoTestProps(AClass: TClass);
  var
    Obj: TComponent;
    TestProps: TPropListTest;
  begin
    Obj := TComponentClass(AClass).Create(nil);
    TestProps := TPropListTest.Create(Self, Obj);
    try
      //TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 4);
      TestProps.AssertPropOffsets;
    finally
      TestProps.Free;
      Obj.Free;
    end;
  end;
  procedure TestTwoClassProps(AnInitProc: TInitProcedure; NotACircle: Boolean = False);
  var
    i, MemUsed: Integer;
    cl: TClass;
    pi: PPropInfo;
    ti: PTypeInfo;
  begin
    for i := 1 to 2 do begin
      AnInitProc();

      case i of // which class to access first
        1: FJitCreator[1].JitClass;
        2: FJitCreator[2].JitClass;
      end;
      MemUsed := GetMemUsed;
      DoTestProps(FJitCreator[1].JitClass);
      DoTestProps(FJitCreator[2].JitClass);
      if not NotACircle then
        AssertEquals('No more Memory alloc', MemUsed, GetMemUsed);

      FJitTypeLib.Free;
      FJitCreator[1].Free;
      FJitCreator[2].Free;
    end;
    // only access one class
    for i := 1 to 2 do begin
      AnInitProc();

      case i of // which class to access first
        1: cl := FJitCreator[1].JitClass;
        2: cl := FJitCreator[2].JitClass;
      end;
      DoTestProps(cl);
      if cl.ClassParent.ClassName <> 'TMyClass' then
        DoTestProps(cl.ClassParent);
      pi := GetPropInfo(cl, 'a');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;
      pi := GetPropInfo(cl, 'b');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;
      pi := GetPropInfo(cl, 'par');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;

      FJitTypeLib.Free;
      FJitCreator[1].Free;
      FJitCreator[2].Free;
    end;
  end;
  procedure TestThreeClassProps(AnInitProc: TInitProcedure);
  var
    i, MemUsed: Integer;
    cl: TClass;
    pi: PPropInfo;
    ti: PTypeInfo;
  begin
    for i := 1 to 3 do begin
      AnInitProc();

      case i of // which class to access first
        1: FJitCreator[1].JitClass;
        2: FJitCreator[2].JitClass;
        3: FJitCreator[3].JitClass;
      end;
      MemUsed := GetMemUsed;
      DoTestProps(FJitCreator[1].JitClass);
      DoTestProps(FJitCreator[2].JitClass);
      DoTestProps(FJitCreator[3].JitClass);
      AssertEquals('No more Memory alloc', MemUsed, GetMemUsed);

      FJitTypeLib.Free;
      FJitCreator[1].Free;
      FJitCreator[2].Free;
      FJitCreator[3].Free;
    end;
    // only access one class
    for i := 1 to 3 do begin
      AnInitProc();

      case i of // which class to access first
        1: cl := FJitCreator[1].JitClass;
        2: cl := FJitCreator[2].JitClass;
        3: cl := FJitCreator[3].JitClass;
      end;
      DoTestProps(cl);
      if cl.ClassParent.ClassName <> 'TMyClass' then
        DoTestProps(cl.ClassParent);
      pi := GetPropInfo(cl, 'a');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;
      pi := GetPropInfo(cl, 'b');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;
      pi := GetPropInfo(cl, 'par');
      if pi <> nil then begin
        ti := pi^.PropType;
        AssertTrue(ti <> nil);
        if ti^.Kind = tkClass then
          DoTestProps(GetTypeData(ti)^.ClassType);
      end;

      FJitTypeLib.Free;
      FJitCreator[1].Free;
      FJitCreator[2].Free;
      FJitCreator[3].Free;
    end;
  end;

var
  JitObject1, JitObject2: TComponent;
  TestProps: TPropListTest;
begin
  (* set up different circular scenarios *)

  //////////////////////////////////
  // 1 classes circle
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassOne');

  JitObject1 := TComponentClass(FJitCreator[1].JitClass).Create(nil);
  TestProps := TPropListTest.Create(Self, JitObject1);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 4);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'a', tkClass);
    TestProps.AssertHasProp('', 'prop1', tkInt64);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
  finally
    TestProps.Free;
  end;

  JitObject1.Free;
  FJitCreator[1].Free;
  FJitTypeLib.Free;


  // 2 class Property Circle
  InitTwoClasses;
  JitObject1 := TComponentClass(FJitCreator[1].JitClass).Create(nil);
  JitObject2 := TComponentClass(FJitCreator[2].JitClass).Create(nil);

  TestProps := TPropListTest.Create(Self, JitObject1);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 4);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'a', tkClass);
    TestProps.AssertHasProp('', 'prop1', tkInt64);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
  finally
    TestProps.Free;
  end;

  TestProps := TPropListTest.Create(Self, JitObject2);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 4);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'a', tkClass);
    TestProps.AssertHasProp('', 'prop1', tkInt64);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
  finally
    TestProps.Free;
  end;

  JitObject1.Free;
  JitObject2.Free;
  FJitCreator[1].Free;
  FJitCreator[2].Free;
  FJitTypeLib.Free;


  // Anchestor Class, has child-class as property
  InitTwoClassesAnchestor;
  JitObject1 := TComponentClass(FJitCreator[1].JitClass).Create(nil);
  JitObject2 := TComponentClass(FJitCreator[2].JitClass).Create(nil);

  TestProps := TPropListTest.Create(Self, JitObject1);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 4);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'a', tkClass);
    TestProps.AssertHasProp('', 'prop1', tkInt64);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
  finally
    TestProps.Free;
  end;

  TestProps := TPropListTest.Create(Self, JitObject2);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 6);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'a', tkClass);
    TestProps.AssertHasProp('', 'prop1', tkBool);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
    TestProps.AssertHasProp('', 'bprop1', tkInt64);
    TestProps.AssertHasProp('', 'bprop2', tkInt64);
  finally
    TestProps.Free;
  end;

  JitObject1.Free;
  JitObject2.Free;
  FJitCreator[1].Free;
  FJitCreator[2].Free;
  FJitTypeLib.Free;


  // Child Class, has anchestor-class as property / not a circle
  InitTwoClassesAnchestorWithAnchestorPropOneWay;
  JitObject1 := TComponentClass(FJitCreator[1].JitClass).Create(nil);
  JitObject2 := TComponentClass(FJitCreator[2].JitClass).Create(nil);

  TestProps := TPropListTest.Create(Self, JitObject1);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 3);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'prop1', tkInt64);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
  finally
    TestProps.Free;
  end;

  TestProps := TPropListTest.Create(Self, JitObject2);
  try
    TestProps.AssertPropCount('', MYCLASS_PROP_COUNT + 6);
    TestProps.AssertPropOffsets;
    TestProps.AssertHasProp('', 'prop1', tkBool);
    TestProps.AssertHasProp('', 'prop2', tkInteger);
    TestProps.AssertHasProp('', 'prop3', tkInt64);
    TestProps.AssertHasProp('', 'par', tkClass);
    TestProps.AssertHasProp('', 'bprop1', tkInt64);
    TestProps.AssertHasProp('', 'bprop2', tkInt64);
  finally
    TestProps.Free;
  end;

  JitObject1.Free;
  JitObject2.Free;
  FJitCreator[1].Free;
  FJitCreator[2].Free;
  FJitTypeLib.Free;

  /////////////////////

  TestTwoClassProps(@InitTwoClasses);
  TestTwoClassProps(@InitTwoClassesWithOneSelfRef);
  TestTwoClassProps(@InitTwoClassesWithDoubleLink);
  TestTwoClassProps(@InitTwoClassesAnchestor);
  TestTwoClassProps(@InitTwoClassesAnchestorWithAnchestorProp);
  TestTwoClassProps(@InitTwoClassesAnchestorWithAnchestorPropOneWay, True);

  TestThreeClassProps(@InitThreeClasses);
  TestThreeClassProps(@InitThreeClassesWithOneSelfRef);
  TestThreeClassProps(@InitThreeClassesWithOneDoubleLink);
  TestThreeClassProps(@InitThreeClassesWithSubLoop);
  TestThreeClassProps(@InitThreeClassesWithSubLoopAndOneSelfRef);
  TestThreeClassProps(@InitThreeClassesWithTwoSubLoop);
  TestThreeClassProps(@InitThreeClassesChained);
  TestThreeClassProps(@InitThreeClassesChainedIndirect);
  TestThreeClassProps(@InitThreeClassesOneAnchestor);
  TestThreeClassProps(@InitThreeClassesOneAnchestorIndirect);
  TestThreeClassProps(@InitThreeClassesAnchestorParallel);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelIndirect); // 5 classes
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildRef);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildRefIndirect);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildRefIndirect_2);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildLoop);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildLoopIndirect);
  TestThreeClassProps(@InitThreeClassesAnchestorParallelAndChildLoopIndirect_2);
  TestThreeClassProps(@InitThreeClassesTwoAnchestor);
  TestThreeClassProps(@InitThreeClassesTwoAnchestorIndirect);
end;

procedure TJitClassTest.TestManagedJitProp;
var
  JitCreator: TJitClassCreator;
  JitClass: TComponentClass;
  JitObject: TComponent;
  a: ansistring;
  MemUsedBeforeCreate, MemUsedAfterCreate, MemUsedTmp: Integer;
begin
  a := '';
  JitCreator       := TJitClassCreator.Create(TMyClass, 'TJitClass', 'foo');
  JitCreator.JitProperties.Add('JitString', 'AnsiString');
  JitClass := TComponentClass(JitCreator.JitClass);

  MemUsedBeforeCreate := GetMemUsed;
  JitObject := JitClass.Create(nil);
  JitObject.Destroy;
  AssertEquals('Memory for object released', MemUsedBeforeCreate, GetMemUsed);


  MemUsedBeforeCreate := GetMemUsed;
  JitObject := JitClass.Create(nil);
  MemUsedAfterCreate := GetMemUsed;

  MemUsedTmp := GetMemUsed;
  SetStrProp(JitObject, 'JitString', a);
  AssertEquals('No Memory used by setting empty string', MemUsedTmp, GetMemUsed);

  SetLength(a, 100);

  MemUsedTmp := GetMemUsed;
  SetStrProp(JitObject, 'JitString', a);
  AssertEquals('No Memory used by setting string with data', MemUsedTmp, GetMemUsed);

  MemUsedTmp := GetMemUsed;
  a := '';
  AssertEquals('Memory for string hold by jitprop', MemUsedTmp, GetMemUsed);

  SetStrProp(JitObject, 'JitString', a); // empty again
  AssertEquals('Memory for string hold by jitprop freed (set to empty)', MemUsedAfterCreate, GetMemUsed);


  SetLength(a, 100);
  MemUsedTmp := GetMemUsed;
  SetStrProp(JitObject, 'JitString', a);
  a := '';
  AssertEquals('Memory for string hold by jitprop (2)', MemUsedTmp, GetMemUsed);


  JitObject.Destroy;
  AssertEquals('Memory for string released', MemUsedBeforeCreate, GetMemUsed);

  JitCreator.Free;
end;

procedure TJitClassTest.TestRefCount;
var
  JitTypeLib: TJitTypeLibrary;
  MyEnLock, OthEnLock, MySetLock: TRefCountedJitReference;
  MyEn, OthEn, MySet: TJitType;
  MyEnInfo, OthEnInfo, MySetInfo: PTypeInfo;
begin
  JitTypeLib := TJitTypeLibrary.Create;
  MyEn  := JitTypeLib.AddType('MyEnum', '(e1, e2, e3, e4, e5, e6)');
  OthEn := JitTypeLib.AddType('OtherEnum', '(o1, o2, o3, o4, o5)');

  // Get Locks
  MyEnLock := MyEn.LockReference;
  OthEnLock := OthEn.LockReference;
  AssertEquals('LockCount for MyEnum (used by set)', 2, MyEnLock.RefCount);
  AssertEquals('LockCount for OtherEnum',            2, OthEnLock.RefCount);

  // Get Lock for MySet => No TypeInfo call yet => no lock to nested MyEnum
  MySet := JitTypeLib.AddType('MySet', 'set of MyEnum');
  MySetLock := MySet.LockReference;
  AssertEquals('LockCount for MySet',                2, MySetLock.RefCount);
  AssertEquals('LockCount for MyEnum 2',             2, MyEnLock.RefCount);
  AssertEquals('LockCount for OtherEnum 2',          2, OthEnLock.RefCount);

  // Watch when Objects are freed
  MyEn.AddFreeNotification(@DoObjFreed);
  OthEn.AddFreeNotification(@DoObjFreed);
  MySet.AddFreeNotification(@DoObjFreed);

  // Access MySet TypeInfo => MySet will need MyEnum
  MySetInfo := MySet.TypeInfo;
  AssertEquals('LockCount for MyEn used',            3, MyEnLock.RefCount);
  AssertEquals('LockCount for OthEn not parsed',     2, OthEnLock.RefCount);
  AssertEquals('LockCount for MySet parsed',         2, MySetLock.RefCount);

  // Get all TypeInfo => start monitoring FreeMem calls
  MyEnInfo  := MyEn.TypeInfo;
  OthEnInfo := OthEn.TypeInfo;

  StartMemMonitor;
  AssertEquals('LockCount for MyEn parsed',           3, MyEnLock.RefCount);
  AssertEquals('LockCount for OthEn parsed',          2, OthEnLock.RefCount);

  // Still the same ref object? The increase by LockReference, should be visible in the earlier ref
  MyEn.LockReference;
  AssertEquals('LockCount for MyEn locked 2',      4, MyEnLock.RefCount);
  OthEn.LockReference;
  AssertEquals('LockCount for OthEn locked 2',     3, OthEnLock.RefCount);
  MySet.LockReference;
  AssertEquals('LockCount for MySet locked 2',     3, MySetLock.RefCount);

  // Free the lib => JitType objects should be freed too
  AssertWasNotObjFreed('', MySet);
  AssertWasNotObjFreed('', MyEn);
  AssertWasNotObjFreed('', OthEn);

  JitTypeLib.Free;
  AssertWasObjFreed('', MySet);
  AssertWasObjFreed('', MyEn);
  AssertWasObjFreed('', OthEn);
  // LockCounts went down by one (no longer locked by the JitType object
  AssertEquals('LockCount for MyEn kept',            3, MyEnLock.RefCount);
  AssertEquals('LockCount for OthEn kept',           2, OthEnLock.RefCount);
  AssertEquals('LockCount for MySet kept',           2, MySetLock.RefCount);

  // Release MySet, which gives up one ref to MyEnum
  MySetLock.ReleaseLock;
  AssertWasNotMemFreed('', MySetInfo);
  // Check FreeMem(TypeInfo) for MySet
  MySetLock.ReleaseLock;
  AssertWasMemFreed('', MySetInfo);

  AssertEquals('LockCount for MyEn kept',            2, MyEnLock.RefCount);
  AssertEquals('LockCount for OthEn kept',           2, OthEnLock.RefCount);

  MyEnLock.ReleaseLock;
  OthEnLock.ReleaseLock;
  AssertWasNotMemFreed('', MyEnInfo);
  AssertWasNotMemFreed('', OthEnInfo);

  // Check FreeMem(TypeInfo)
  MyEnLock.ReleaseLock;
  OthEnLock.ReleaseLock;
  AssertWasMemFreed('', MyEnInfo);
  AssertWasMemFreed('', OthEnInfo);

  ////////////////////////
  // Test Mem without external lock
  StartAndClearMemMonitor;
  JitTypeLib := TJitTypeLibrary.Create;
  MyEn  := JitTypeLib.AddType('MyEnum', '(e1, e2, e3, e4, e5, e6)');
  MyEnInfo  := MyEn.TypeInfo;
  StartAndClearMemMonitor;

  AssertWasNotMemFreed('', MyEnInfo);
  JitTypeLib.Free;
  AssertWasMemFreed('', MyEnInfo);


  StopMemMonitor;
  StartAndClearMemMonitor;
end;

procedure TJitClassTest.TestRefCountProp;
var
  JitCreator: TJitClassCreator;
  JitTypeLib: TJitTypeLibrary;
  MyEnLock, ClassLock: TRefCountedJitReference;
  MyEn: TJitType;
  MyEnInfo: PTypeInfo;
begin
  JitTypeLib := TJitTypeLibrary.Create;
  MyEn  := JitTypeLib.AddType('MyEnum', '(e1, e2, e3, e4, e5, e6)');
  MyEnInfo := MyEn.TypeInfo;
  StartMemMonitor;

  MyEnLock := MyEn.LockReference;
  AssertEquals('LockCount for MyEnum after typeinfo', 2, MyEnLock.RefCount);


  JitCreator := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleOuterClass', 'foo.pas');
  JitCreator.TypeLibrary := JitTypeLib;
  JitCreator.JitProperties.Add('a', 'MyEnum');
  JitCreator.JitClass;

  AssertEquals('LockCount for MyEnum after jitclass', 3, MyEnLock.RefCount);

  JitTypeLib.Free;
  AssertEquals('LockCount for MyEnum after typelib free', 2, MyEnLock.RefCount);

  JitCreator.Free;
  AssertEquals('LockCount for MyEnum after creator free', 1, MyEnLock.RefCount);

  AssertWasNotMemFreed('', MyEnInfo);
  MyEnLock.ReleaseLock;
  AssertWasMemFreed('', MyEnInfo);


  ///////////////
  // Add as property
  // hold creator by lock
  JitTypeLib := TJitTypeLibrary.Create;
  MyEn  := JitTypeLib.AddType('MyEnum', '(e1, e2, e3, e4, e5, e6)');
  MyEnInfo := MyEn.TypeInfo;
  StartAndClearMemMonitor;

  MyEnLock := MyEn.LockReference;
  AssertEquals('LockCount for MyEnum after typeinfo', 2, MyEnLock.RefCount);


  JitCreator := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleOuterClass', 'foo.pas');
  JitCreator.TypeLibrary := JitTypeLib;
  JitCreator.JitProperties.Add('a', 'MyEnum');
  ClassLock := JitCreator.LockReference;
  AssertEquals('LockCount for class ', 2, ClassLock.RefCount);

  JitCreator.JitClass;
  AssertEquals('LockCount for MyEnum after jitclass', 3, MyEnLock.RefCount);

  JitTypeLib.Free;
  AssertEquals('LockCount for MyEnum after typelib free', 2, MyEnLock.RefCount);

  JitCreator.Free;
  AssertEquals('LockCount for MyEnum after creator free (locked)', 2, MyEnLock.RefCount);
  AssertEquals('LockCount for class after creator free', 1, ClassLock.RefCount);

  ClassLock.ReleaseLock;
  AssertEquals('LockCount for MyEnum after creator free (unlocked)', 1, MyEnLock.RefCount);

  AssertWasNotMemFreed('', MyEnInfo);
  MyEnLock.ReleaseLock;
  AssertWasMemFreed('', MyEnInfo);
end;

function TJitClassTest.GetCreator(ABase: TClass; AName: String; PropClass: String = ''; ATakeCreatorOwnerShip: Boolean = False): TJitClassCreator;
begin
  Result := TJitClassCreator.Create(ABase, AName, 'foo');
  Result.TypeLibrary := FJitTypeLib;
  if PropClass <> '' then
    Result.JitProperties.Add('a', PropClass);
  FJitTypeLib.AddJitClass(Result.JitClassName, Result, ATakeCreatorOwnerShip);

  Result.JitProperties.Add('prop1', 'Int64');
  Result.JitProperties.Add('prop2', 'word');
  Result.JitProperties.Add('prop3', 'Int64');
end;

function TJitClassTest.GetCreator(ABase: TJitClassCreator; AName: String;
  PropClass: String; ATakeCreatorOwnerShip: Boolean): TJitClassCreator;
begin
  Result := TJitClassCreator.Create(ABase, AName, 'foo');
  Result.TypeLibrary := FJitTypeLib;
  if PropClass <> '' then
    Result.JitProperties.Add('b', PropClass);
  FJitTypeLib.AddJitClass(Result.JitClassName, Result, ATakeCreatorOwnerShip);

  Result.JitProperties.Add('bprop1', 'Int64');
  Result.JitProperties.Add('bprop2', 'Int64');
  Result.JitProperties.Add('prop1', 'boolean'); // replace prop
end;

procedure TJitClassTest.InitTwoClasses;
begin
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[2] := GetCreator(TMyClass, 'TMyClassTwo', 'TMyClassOne');
end;

procedure TJitClassTest.InitTwoClassesWithOneSelfRef;
begin
  (* One -> Two
     One -> One
     Two -> One
  *)
  InitTwoClasses;
  FJitCreator[1].JitProperties.Add('b', 'TMyClassOne'); // self ref
end;

procedure TJitClassTest.InitTwoClassesWithDoubleLink;
begin
  (* One -> Two
     One -> Two (2nd property)
     Two -> One
  *)
  InitTwoClasses;
  FJitCreator[1].JitProperties.Add('b', 'TMyClassTwo'); // 2nd prop to TMyClassTwo;
end;

procedure TJitClassTest.InitTwoClassesAnchestor;
begin
  (* One -> Two
     Two >> One  (inherits)
  *)
  (* Anchestor Class, has child-class as property *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
end;

procedure TJitClassTest.InitTwoClassesAnchestorWithAnchestorProp;
begin
  (* One -> Two
     Two >> One  (inherits)
     Two -> One  (prop)
  *)
  (* Anchestor Class, has child-class as property
     AND Child has anchestor as prop
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
  FJitCreator[2].JitProperties.Add('par', 'TMyClassOne');
end;
procedure TJitClassTest.InitTwoClassesAnchestorWithAnchestorPropOneWay;
begin
  // NOT a circle
  (* Two >> One  (inherits)
     Two -> One  (prop)
  *)
  (* Child Class, has anchestor-class as property / not a circle *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne'); // anchestor does NOT refer to the child
  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
  FJitCreator[2].JitProperties.Add('par', 'TMyClassOne');
end;
procedure TJitClassTest.InitThreeClasses;
begin
  (* One   -> Two
     Two   -> Three
     Three -> One
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1]   := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[2]   := GetCreator(TMyClass, 'TMyClassTwo', 'TMyClassThree');
  FJitCreator[3] := GetCreator(TMyClass, 'TMyClassThree', 'TMyClassOne');
end;

procedure TJitClassTest.InitThreeClassesWithOneSelfRef;
begin
  (* One   -> Two
     One   -> One
     Two   -> Three
     Three -> One
  *)
  InitThreeClasses;
  FJitCreator[1].JitProperties.Add('c', 'TMyClassOne');
end;

procedure TJitClassTest.InitThreeClassesWithOneDoubleLink;
begin
  (* One   -> Two
     One   -> Two  (2nd prop)
     Two   -> Three
     Three -> One
  *)
  InitThreeClasses;
  FJitCreator[1].JitProperties.Add('c', 'TMyClassTwo');
end;

procedure TJitClassTest.InitThreeClassesWithSubLoop;
begin
  (* One   -> Two
     One   -> Three
     Two   -> Three
     Three -> One
  *)
  InitThreeClasses;
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesWithSubLoopAndOneSelfRef;
begin
  (* One   -> Two
     One   -> One
     One   -> Three
     Two   -> Three
     Three -> One
  *)
  InitThreeClasses;
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');
  FJitCreator[1].JitProperties.Add('c', 'TMyClassOne');
end;

procedure TJitClassTest.InitThreeClassesWithTwoSubLoop;
begin
  (* One   -> Two
     One   -> Three
     Two   -> Three
     Three -> One
     Three -> One  (2nd prop)
  *)
  InitThreeClasses;
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');
  FJitCreator[3].JitProperties.Add('c', 'TMyClassOne');
end;

procedure TJitClassTest.InitThreeClassesChained;
begin
  // 2 separate loops / only ONE is in both loops
  (* One   -> Two
     One   -> Three
     Two   -> One
     Three -> One
  *)
  // FJitCreator[1]  will be in 2 circles: One with FJitCreator[2] / the other one with FJitCreator[3]
  // FJitCreator[2] and FJitCreator[3] are anly connected to FJitCreator[1]
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1]   := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');
  FJitCreator[2]   := GetCreator(TMyClass, 'TMyClassTwo', 'TMyClassOne');
  FJitCreator[3] := GetCreator(TMyClass, 'TMyClassThree', 'TMyClassOne');
end;

procedure TJitClassTest.InitThreeClassesChainedIndirect;
begin
  // 2 separate loops / only ONE is in both loops
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   -> One
     Three -> One
  *)
  // FJitCreator[1]  will be in 2 circles: One with FJitCreator[2] / the other one with FJitCreator[3]
  // FJitCreator[2] and FJitCreator[3] are anly connected to FJitCreator[1]
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1]   := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(TMyClass, 'TMyClassTwo', 'TMyClassOne');
  FJitCreator[3] := GetCreator(TMyClass, 'TMyClassThree', 'TMyClassOne');

end;

procedure TJitClassTest.InitThreeClassesOneAnchestor;
begin
  (* One   -> Three
     Three -> Two
     Two   >> One  (inherits)
  *)
  (* Anchestor Class, has child-class via 3rd obj as property *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassThree');
  FJitCreator[3] := GetCreator(TMyClass, 'TMyClassThree', 'TMyClassTwo');
  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
end;

procedure TJitClassTest.InitThreeClassesOneAnchestorIndirect;
begin
  (* One   -> ThreeHolder -> Three
     Three -> TwoHolder   -> Two
     Two   >> One  (inherits)
  *)
  (* Anchestor Class, has child-class via 3rd obj as property *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  FJitCreator[3] := GetCreator(TMyClass, 'TMyClassThree', 'TMyClassTwoHolder');
  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallel;
begin
  // 2 separate loops / only ONE is in both loops
  (* One   -> Two
     One   -> Three
     Two   >> One  (inherits)
     Three >> One  (inherits)
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelIndirect;
begin
  // 2 separate loops / only ONE is in both loops
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Three >> One  (inherits)
  *)
  (* Anchestor Class, has TWO child-classes,
     BOTH as property via indirection
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildRef;
begin
  (* One   -> Two
     One   -> Three
     Two   >> One  (inherits)
     Two   -> Three
     Three >> One  (inherits)
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     One child has the other child as prop
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThree');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildRefIndirect;
begin
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Two   -> ThreeHolder -> Three
     Three >> One  (inherits)
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     One child has the other child as prop
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThreeHolder');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildRefIndirect_2;
begin
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Two   -> ThreeHolder_2 -> Three  // use different holder
     Three >> One  (inherits)
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     One child has the other child as prop
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder_2', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThreeHolder_2');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildLoop;
begin
  // 3 circles
  (* One   -> Two
     One   -> Three
     Two   >> One  (inherits)
     Two   -> Three
     Three >> One  (inherits)
     Three -> Two
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     Bothe children has the other child as prop (loop)
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwo');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThree');

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThree');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree', 'TMyClassTwo');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildLoopIndirect;
begin
  // 3 circles
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Two   -> ThreeHolder -> Three
     Three >> One  (inherits)
     Three -> TwoHolder   -> Two
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     Bothe children has the other child as prop (loop)
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThreeHolder');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree', 'TMyClassTwoHolder');
end;

procedure TJitClassTest.InitThreeClassesAnchestorParallelAndChildLoopIndirect_2;
begin
  // 3 circles
  (* One   -> TwoHolder   -> Two
     One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Two   -> ThreeHolder_2 -> Three
     Three >> One  (inherits)
     Three -> TwoHolder_2   -> Two
  *)
  (* Anchestor Class, has TWO child-classes, BOTH as property
     Bothe children has the other child as prop (loop)
  *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassTwoHolder');
  FJitCreator[1].JitProperties.Add('b', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassTwoHolder', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassTwoHolder_2', 'TMyClassTwo', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);
  GetCreator(TMyClass, 'TMyClassThreeHolder_2', 'TMyClassThree', True);

  FJitCreator[2] := GetCreator(FJitCreator[1], 'TMyClassTwo', 'TMyClassThreeHolder_2');
  FJitCreator[3] := GetCreator(FJitCreator[1], 'TMyClassThree', 'TMyClassTwoHolder_2');
end;

procedure TJitClassTest.InitThreeClassesTwoAnchestor;
begin
  (* One   -> Three
     Two   >> One  (inherits)
     Three >> Two  (inherits)
  *)
  (* Class, has grand child-class that has property to orig class *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassThree');

  // inherit TMyClassOne
  FJitCreator[2] := TJitClassCreator.Create(FJitCreator[1], 'TMyClassTwo', 'foo');
  FJitCreator[2].TypeLibrary := FJitTypeLib;
  FJitTypeLib.AddJitClass(FJitCreator[2].JitClassName, FJitCreator[2]);

  // inherit TMyClassTwo;
  FJitCreator[3] := GetCreator(FJitCreator[2], 'TMyClassThree');
end;

procedure TJitClassTest.InitThreeClassesTwoAnchestorIndirect;
begin
  (* One   -> ThreeHolder -> Three
     Two   >> One  (inherits)
     Three >> Two  (inherits)
  *)
  (* Class, has grand child-class that has property to orig class *)
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassThreeHolder');

  GetCreator(TMyClass, 'TMyClassThreeHolder', 'TMyClassThree', True);

  // inherit TMyClassOne
  FJitCreator[2] := TJitClassCreator.Create(FJitCreator[1], 'TMyClassTwo', 'foo');
  FJitCreator[2].TypeLibrary := FJitTypeLib;
  FJitTypeLib.AddJitClass(FJitCreator[2].JitClassName, FJitCreator[2]);

  // inherit TMyClassTwo;
  FJitCreator[3] := GetCreator(FJitCreator[2], 'TMyClassThree');
end;

procedure TJitClassTest.TestTwoClassRefCount(
  AnInitProc: TInitProcedure);
var
  i, j, MemUsed: Integer;
  JitClassOneInfo, JitClassTwoInfo: PTypeInfo;
  jc: TJitClassCreator;
begin
  for i := 1 to 2 do for j := 1 to 2 do begin
    AnInitProc();

    case i of // which class to access first
      1: JitClassOneInfo := FJitCreator[1].TypeInfo;
      2: JitClassTwoInfo := FJitCreator[2].TypeInfo;
    end;
    JitClassOneInfo := FJitCreator[1].TypeInfo; // access the other / double access to the first does not matter
    JitClassTwoInfo := FJitCreator[2].TypeInfo;
    StartAndClearMemMonitor;

    FJitTypeLib.Free;
    case j of // which class to destroy first
      1: FreeAndNil(FJitCreator[1]);
      2: FreeAndNil(FJitCreator[2]);
    end;

    AssertWasNotMemFreed('', JitClassOneInfo);
    AssertWasNotMemFreed('', JitClassTwoInfo);
    FreeAndNil(FJitCreator[1]);
    FreeAndNil(FJitCreator[2]);
    AssertWasMemFreed('', JitClassOneInfo);
    AssertWasMemFreed('', JitClassTwoInfo);
  end;

  // only access one typeinfo
  StopMemMonitor;
  for i := 1 to 2 do for j := 1 to 2 do begin
    MemUsed := GetMemUsed;

    AnInitProc();
    case i of // which class to access first
      1: jc := FJitCreator[1];
      2: jc := FJitCreator[2];
    end;
    JitClassOneInfo := jc.TypeInfo;

    FJitTypeLib.Free;
    case j of // which class to destroy first
      1: FreeAndNil(FJitCreator[1]);
      2: FreeAndNil(FJitCreator[2]);
    end;
    FreeAndNil(FJitCreator[1]);
    FreeAndNil(FJitCreator[2]);

    AssertEquals('mem used ', MemUsed, GetMemUsed);
  end;

end;

procedure TJitClassTest.TestThreeClassRefCount(AnInitProc: TInitProcedure);
var
  i, j, k, MemUsed: Integer;
  JitClassOneInfo, JitClassTwoInfo, JitClassThreeInfo: PTypeInfo;
  LastToFree, jc: TJitClassCreator;
begin
  for i := 1 to 3 do for j := 1 to 3 do for k := 1 to 3 do begin
    AnInitProc();
    case i of // which class to access first
      1: JitClassOneInfo   := FJitCreator[1].TypeInfo;
      2: JitClassTwoInfo   := FJitCreator[2].TypeInfo;
      3: JitClassThreeInfo := FJitCreator[3].TypeInfo;
    end;
    JitClassOneInfo   := FJitCreator[1].TypeInfo;
    JitClassTwoInfo   := FJitCreator[2].TypeInfo;
    JitClassThreeInfo := FJitCreator[3].TypeInfo;
    StartAndClearMemMonitor;
    FJitTypeLib.Free;
    case j of // which class to destroy last
      1: begin LastToFree := FJitCreator[1];   FJitCreator[1] := nil; end;
      2: begin LastToFree := FJitCreator[2];   FJitCreator[2] := nil; end;
      3: begin LastToFree := FJitCreator[3]; FJitCreator[3] := nil; end;
    end;
    case k of // which class to destroy first
      1: FreeAndNil(FJitCreator[1]);
      2: FreeAndNil(FJitCreator[2]);
      3: FreeAndNil(FJitCreator[3]);
    end;
    FJitCreator[1].Free;
    FJitCreator[2].Free;
    FJitCreator[3].Free;

    AssertWasNotMemFreed('', JitClassOneInfo);
    AssertWasNotMemFreed('', JitClassTwoInfo);
    AssertWasNotMemFreed('', JitClassThreeInfo);
    LastToFree.Free;
    AssertWasMemFreed('', JitClassOneInfo);
    AssertWasMemFreed('', JitClassTwoInfo);
    AssertWasMemFreed('', JitClassThreeInfo);
  end;


  // only access one typeinfo
  StopMemMonitor;
  for i := 1 to 3 do for j := 1 to 3 do for k := 1 to 3 do begin
    MemUsed := GetMemUsed;

    AnInitProc();
    case i of // which class to access first
      1: jc := FJitCreator[1];
      2: jc := FJitCreator[2];
      3: jc := FJitCreator[3];
    end;
    JitClassOneInfo := jc.TypeInfo;

    FJitTypeLib.Free;
    case j of // which class to destroy last
      1: FreeAndNil(FJitCreator[1]);
      2: FreeAndNil(FJitCreator[2]);
      3: FreeAndNil(FJitCreator[3]);
    end;
    case k of // which class to destroy first
      1: FreeAndNil(FJitCreator[1]);
      2: FreeAndNil(FJitCreator[2]);
      3: FreeAndNil(FJitCreator[3]);
    end;
    FJitCreator[1].Free;
    FJitCreator[2].Free;
    FJitCreator[3].Free;

    AssertEquals('mem used ', MemUsed, GetMemUsed);
  end;
end;


procedure TJitClassTest.TestRefCountClassCircle;
var
  JitClassOneInfo, JitClassTwoInfo, JitClassThreeInfo: PTypeInfo;
begin
  //////////////////////////////////
  // 1 classes circle
  FJitTypeLib := TJitTypeLibrary.Create;
  FJitCreator[1] := GetCreator(TMyClass, 'TMyClassOne', 'TMyClassOne');
  JitClassOneInfo := FJitCreator[1].TypeInfo;
  StartMemMonitor;

  FJitTypeLib.Free;

  AssertWasNotMemFreed('', JitClassOneInfo);
  FJitCreator[1].Free;
  AssertWasMemFreed('', JitClassOneInfo);

  TestTwoClassRefCount(@InitTwoClasses);
  TestTwoClassRefCount(@InitTwoClassesWithOneSelfRef);
  TestTwoClassRefCount(@InitTwoClassesWithDoubleLink);
  TestTwoClassRefCount(@InitTwoClassesAnchestor);
  TestTwoClassRefCount(@InitTwoClassesAnchestorWithAnchestorProp);

  TestThreeClassRefCount(@InitThreeClasses);
  TestThreeClassRefCount(@InitThreeClassesWithOneSelfRef);
  TestThreeClassRefCount(@InitThreeClassesWithOneDoubleLink);
  TestThreeClassRefCount(@InitThreeClassesWithSubLoop);
  TestThreeClassRefCount(@InitThreeClassesWithSubLoopAndOneSelfRef);
  TestThreeClassRefCount(@InitThreeClassesWithTwoSubLoop);
  TestThreeClassRefCount(@InitThreeClassesChained);
  TestThreeClassRefCount(@InitThreeClassesChainedIndirect);
  TestThreeClassRefCount(@InitThreeClassesOneAnchestor);
  TestThreeClassRefCount(@InitThreeClassesOneAnchestorIndirect);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallel);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelIndirect); // 5 classes
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildRef);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildRefIndirect);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildRefIndirect_2);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildLoop);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildLoopIndirect);
  TestThreeClassRefCount(@InitThreeClassesAnchestorParallelAndChildLoopIndirect_2);
  TestThreeClassRefCount(@InitThreeClassesTwoAnchestor);
  TestThreeClassRefCount(@InitThreeClassesTwoAnchestorIndirect);

end;

procedure TJitClassTest.TestRefCountMethodCircle;
var
  JitTypeLib: TJitTypeLibrary;
  MyProc: TJitType;
  MyProcInfo: PTypeInfo;
begin
  JitTypeLib := TJitTypeLibrary.Create;
  MyProc := JitTypeLib.AddType('TMyProc', 'procedure (a: TMyProc)');
  MyProcInfo := MyProc.TypeInfo;
  StartMemMonitor;

  AssertWasNotMemFreed('', MyProcInfo);
  JitTypeLib.Free;
  AssertWasMemFreed('', MyProcInfo);


end;

procedure TJitClassTest.TestParseJitType;
var
  JitCreator: TJitClassCreator;
  Cnt: Integer;
  JitTypeLib: TJitTypeLibrary;
  t: PTypeInfo;

  function DoParseNoError(AName: String; ADecl: String): PTypeInfo;
  var
    jp: TJitProperty;
  begin
    AName := AName + ' ' + ADecl + ' ';
    inc(Cnt);
    try
      jp := JitCreator.JitProperties.Add('a'+IntToStr(Cnt), ADecl);
      Result := jp.TypeInfo;
      //AssertTrue(AName, jp.TypeInfo <> nil);
    except
      AssertTrue(AName + 'no except', False);
    end;
  end;

  function ParseNoError(AName: String; ADecl: String): PTypeInfo;
  var
    s: String;
  begin
    Result := DoParseNoError(AName, ADecl);
    DoParseNoError(AName+' IN record', 'record a: '+ADecl+' end');
    s := Trim(ADecl);
    if (s <> '') and (s[Length(s)] <> ';') then
      DoParseNoError(AName+' IN record ;', 'record a: '+ADecl+'; end');
  end;

  procedure ParseExpectError(AName: String; ADecl: String);
  var
    jp: TJitProperty;
    t: Boolean;
  begin
    AName := AName + ' ' + ADecl + ' ';
    inc(Cnt);
    t := True;
    try
      jp := JitCreator.JitProperties.Add('a'+IntToStr(Cnt), ADecl);
      jp.TypeInfo;
      t := False; // should skipped by exception
    except
      on E: Exception do
        if not (e is JitTypeParserException) then
          t := False; // wrong exception type
    end;
    AssertTrue(AName, t); // should not reach if above fails
  end;


begin
  Cnt := 0;
  JitCreator := TJitClassCreator.Create(TMyClass, 'TJitTestSimpleOuterClass', 'unitfoo');
  JitTypeLib := TJitTypeLibrary.Create;
  JitCreator.TypeLibrary := JitTypeLib;

  JitTypeLib.AddAlias('integer', 'longint');
  JitTypeLib.AddAlias('int32', 'integer');
  JitTypeLib.AddType('MyEnum', '(e1, e2, e3, e4, e5, e6)', 'unitfoo');
  JitTypeLib.AddType('OtherEnum',  '(zo1, o2, zo3, o4, zo5)', 'abc');
  JitTypeLib.AddType('OtherEnum',  '(o1, o2, o3, o4, o5)', 'unitfoo');
  JitTypeLib.AddType('OtherEnumX', '(xo1, o2, xo3, o4, xo5)', 'unitbar');

  ParseExpectError('', 'string');
  ParseNoError('', 'string[1]');

  JitTypeLib.AddAlias('string', 'AnsiString');
  ParseNoError('', 'longint');
  ParseNoError('', 'integer');
  ParseNoError('', 'int32');
  ParseNoError('', 'string');
  ParseNoError('', 'string[1]');
  ParseNoError('', 'string[255]');
  ParseNoError('', 'string[$FF]');
  ParseNoError('', 'string[%10]');
  ParseNoError('', 'string[&10]');

  ParseNoError('', 'procedure');
  ParseNoError('', 'procedure()');
  ParseNoError('', 'procedure of object');
  ParseNoError('', 'procedure () of object');

  ParseNoError('', 'function: int64 ');
  ParseNoError('', 'function(): int64');
  ParseNoError('', 'function: int64 of object');
  ParseNoError('', 'function(): int64 of object');
  ParseNoError('', 'function(): OtherEnum of object');
  ParseNoError('', 'function(): unitfoo.OtherEnum of object');
  ParseNoError('', 'function(): abc.OtherEnum of object');

  ParseNoError('', 'function(a,b: MyEnum): int64 ');
  ParseNoError('', 'function(a,b: unitfoo.MyEnum): int64 ');
  ParseNoError('', 'function(a,b: word; c: boolean=true; const x): int64 ');
  ParseNoError('', 'function(a,b: word; c: boolean=true; const x; d,e: array of int64): int64 ');

  ParseNoError('', 'record end;');
  ParseNoError('', 'record a,b: word end;');
  ParseNoError('', 'record a,b: word; end;');
  ParseNoError('', 'record a,b: word; c: procedure() end;');
  ParseNoError('', 'record a,b: word; c: procedure(); end;');
  ParseNoError('', 'record a,b: word; c: procedure(); x: record xx: boolean end; end;');
  ParseNoError('', 'record a,b: word; c: procedure(); x: record xx: boolean end end;');
  ParseNoError('', 'record b: MyEnum end;');
  ParseNoError('', 'record b: MyEnum; end;');
  ParseNoError('', 'record b: unitfoo.MyEnum end;');
  ParseNoError('', 'record b: unitfoo.MyEnum; end;');

  ParseNoError('', '1..3');
  ParseNoError('', '''a''..''c''');
  ParseNoError('', 'e2..e3');
  ParseNoError('', 'MyEnum.e2..e3');
  ParseNoError('', 'e2..MyEnum.e3');
  ParseNoError('', 'MyEnum.e2..MyEnum.e3');
  ParseNoError('', 'MyEnum(e2)..MyEnum.e3');
  ParseNoError('', 'MyEnum.e2..MyEnum(e3)');

  t := ParseNoError('', 'o2..o4');
  AssertEquals('has o3', GetEnumValue(t, 'o3'), 2);
  AssertEquals('has not xo3', GetEnumValue(t, 'xo3'), -1);
  AssertEquals('has not zo3', GetEnumValue(t, 'zo3'), -1);

  ParseNoError('', 'unitbar.OtherEnumX.o2..unitbar.OtherEnumX(o4)');
  ParseNoError('', 'OtherEnumX.o2..OtherEnumX(o4)');
  ParseNoError('', 'OtherEnumX(o2)..OtherEnumX(o4)');
  ParseNoError('', 'OtherEnumX.o2..OtherEnumX.o4');
  t := ParseNoError('', 'OtherEnumX.o2..o4');
  AssertEquals('has xo3', GetEnumValue(t, 'xo3'), 2);
  AssertEquals('has not o3',  GetEnumValue(t, 'o3'), -1);
  AssertEquals('has not zo3', GetEnumValue(t, 'zo3'), -1);

  t := ParseNoError('', 'abc.OtherEnum.o2..o4');
  AssertEquals('has zo3', GetEnumValue(t, 'zo3'), 2);
  AssertEquals('has not o3',  GetEnumValue(t, 'o3'), -1);
  AssertEquals('has not xo3', GetEnumValue(t, 'xo3'), -1);


  ParseNoError('', 'set of (a,b,c)');
  ParseNoError('', 'set of byte');
  ParseNoError('', 'set of 1..3');
  ParseNoError('', 'set of Byte(1)..Byte(3)');
  ParseNoError('', 'set of MyEnum');
  ParseNoError('', 'set of unitfoo.MyEnum');
  ParseNoError('', 'set of MyEnum(1)..e3');
  ParseNoError('', 'set of unitfoo.MyEnum(1)..e3');
  ParseNoError('', 'set of e2..e5'); // typelibrary with enum (en1..en7)

  ParseNoError('', 'array of int64');
  ParseNoError('', 'array of array of int64');
  ParseNoError('', 'array of string');
  ParseNoError('', 'array of string[2]');
  ParseNoError('', 'array of record a: word; end;');
  ParseNoError('', 'array of record a: (b,c) end;');
  ParseNoError('', 'record a: array of string[2]; b: word; end;');



  ParseExpectError('', 'foo');
  ParseExpectError('', 'procedure foo');
  ParseExpectError('', 'procedure: foo');
  ParseExpectError('', 'procedure of ');
  ParseExpectError('', 'procedure(a: foo)');
  ParseExpectError('', 'function:');
  ParseExpectError('', 'function: foo');
  ParseExpectError('', 'function(): unitbar.OtherEnum');
  ParseExpectError('', 'function: array of int64');
  ParseExpectError('', 'string[256]');
  ParseExpectError('', 'string[0]');
  ParseExpectError('', 'string[-1]');
  ParseExpectError('', 'OtherEnumX.o2..OtherEnum.o4');
  ParseExpectError('', 'abc.OtherEnumX.o2..unitfoo.OtherEnum.o4');
  ParseExpectError('', 'record b: unitbar.MyEnum; end;');
  ParseExpectError('', 'record b: what.MyEnum; end;');

  //ParseExpectError('', 'set of o2..e5'); // typelibrary with enum (en1..en7)


  // TEST & escaping
  JitTypeLib.AddAlias('&function', 'integer');

  ParseNoError('', '&Function');
  ParseNoError('', '&integer');
  ParseNoError('', '&longint');
  ParseExpectError('', 'Function');
  ParseExpectError('', '&foo');

  JitCreator.Free;
  JitTypeLib.Free;
end;

procedure TJitClassTest.TestSetEnum;
  procedure CheckEnum(TpInf: PTypeInfo; Names: array of string; UnitName: string; ExpMinVal: Integer = 0);
  var
    i: Integer;
    TpDat: PTypeData;
    MinVal: LongInt;
  begin
    AssertTrue('kind', TpInf^.Kind = tkEnumeration);
    TpDat := GetTypeData(TpInf);
    MinVal := TpDat^.MinValue;
    AssertEquals('minval', ExpMinVal, TpDat^.MinValue);
    AssertEquals('elem count', Length(Names), GetEnumNameCount(TpInf));
    AssertEquals('unitname', UnitName, GetEnumName(TpInf, Length(Names) + MinVal)); // unitname
    for i := 0 to length(Names) - 1 do begin
      AssertEquals('elem', Names[i], GetEnumName(TpInf, i+MinVal));
      AssertEquals('',   i+MinVal, GetEnumValue(TpInf, Names[i]));
    end;
    //AssertEquals('bad val',   -1, GetEnumValue(TpInf, UnitName));
    AssertEquals('bad val',   -1, GetEnumValue(TpInf, 'nevereverusethis'));
  end;
  procedure CheckSet(TpInf: PTypeInfo; Names: array of string);
  var
    i: Integer;
    CT: PTypeInfo;
    MinVal: LongInt;
  begin
    AssertTrue('kind', TpInf^.Kind = tkSet);
    CT := GetTypeData(TpInf)^.CompType;
    MinVal := GetTypeData(CT)^.MinValue;
    for i := 0 to length(Names) - 1 do begin
      AssertEquals('elem', Names[i], SetToString(TpInf, 1 << (i+MinVal), False));
    end;
  end;
var
  JitTypeLib: TJitTypeLibrary;
  jp, en1, en2: TJitType;
  ti, ti2: PTypeInfo;
begin
  JitTypeLib := TJitTypeLibrary.Create;

  jp := TJitTypeInfo.Create('x','(a,b,c)', 'unitfoo');
  ti := jp.TypeInfo;
  CheckEnum(ti, ['a', 'b', 'c'], 'unitfoo');
  jp.Free;

  en1 := JitTypeLib.AddType('En1','(a,b,c,d,e)', 'unitfoo');
  ti := en1.TypeInfo;
  CheckEnum(ti, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');

  en2 := JitTypeLib.AddType('En2','b..d', 'unitbar');
  ti := en2.TypeInfo;
  CheckEnum(ti, ['b', 'c', 'd'], 'unitbar', 1);
  ti2 := GetTypeData(ti)^.BaseType;
  AssertTrue('', ti2 = en1.TypeInfo);
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');

  jp := TJitTypeInfo.Create('x','en1.b..d', 'unitabc', JitTypeLib);
  ti := jp.TypeInfo;
  CheckEnum(ti, ['b', 'c', 'd'], 'unitabc', 1);
  ti2 := GetTypeData(ti)^.BaseType;
  AssertTrue('', ti2 = en1.TypeInfo);
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');
  jp.Free;



  jp := TJitTypeInfo.Create('x','set of (a,b,c)', 'unitfoo');
  ti := jp.TypeInfo;
  CheckSet(ti, ['a', 'b', 'c']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['a', 'b', 'c'], 'unitfoo');
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of En1', 'unitsome', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['a', 'b', 'c', 'd', 'e']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of En2', 'unitsome', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitbar', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of EN1(b)..d', 'unitsome', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitsome', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  AssertTrue('', ti2 = en1.TypeInfo);
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of EN2(b)..d', 'unitother', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitother', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  AssertTrue('', ti2 = en2.TypeInfo);
  jp.Free;


  jp := TJitTypeInfo.Create('x','set of EN1.b..d', 'unitsome', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitsome', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  AssertTrue('', ti2 = en1.TypeInfo);
  CheckEnum(ti2, ['a', 'b', 'c', 'd', 'e'], 'unitfoo');
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of EN2.b..d', 'unitother', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitother', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  AssertTrue('', ti2 = en2.TypeInfo);
  jp.Free;

  jp := TJitTypeInfo.Create('x','set of EN2.b..EN2.d', 'unitother', JitTypeLib);
  ti := jp.TypeInfo;
  CheckSet(ti, ['b', 'c', 'd']);
  ti2 := GetTypeData(ti)^.CompType;
  CheckEnum(ti2, ['b', 'c', 'd'], 'unitother', 1);
  ti2 := GetTypeData(ti2)^.BaseType;
  AssertTrue('', ti2 = en2.TypeInfo);
  jp.Free;



  JitTypeLib.Free;
end;

procedure TJitClassTest.TestMethods;
var
  JitTypeLib: TJitTypeLibrary;

  procedure DoTest(Decl: String; ExpParam: array of string);
  var
    context: TRttiContext;
    jp: TJitTypeInfo;
    t: TRttiType;
  params: specialize TArray<TRttiParameter>;
  i: Integer;
  begin
    context := TRttiContext.Create;
    jp := TJitTypeInfo.Create('x', Decl, JitTypeLib);
    t := context.GetType(jp.TypeInfo);

    AssertTrue(t <> nil);
    AssertTrue(t is TRttiInvokableType);

    params := TRttiInvokableType(t).GetParameters;
    AssertEquals(Length(ExpParam), Length(params));

    for i := 0 to Length(ExpParam) - 1 do begin
      //debugln(params[i].tostring);
      AssertEquals(LowerCase(ExpParam[i]), LowerCase(params[i].ToString));
    end;
    jp.Free;
    context.Free;
  end;

begin
  JitTypeLib := TJitTypeLibrary.Create;
  JitTypeLib.AddType('TEnum1', '(a,b,c)');

  DoTest('function (const a: byte; b,c: word): boolean',
    ['const a: byte', 'b: word', 'c: word']
  );
  DoTest('function (const a: byte; var b,c: word): boolean of object',
    ['const a: byte', 'var b: word', 'var c: word']
  );
  DoTest('procedure (var a: TEnum1; b: array of Int64) of object',
    ['var a: TEnum1', {$IFDEF FooFIxed}'b: '+{$ENDIF}'array of Int64']
  );

  JitTypeLib.Free;
end;



initialization

  RegisterTest(TJitClassTest);

  GetMemoryManager(MMgr);
  OrigFreemem     := MMgr.Freemem;
  OrigFreememSize := MMgr.FreememSize;
  MMgr.Freemem     := @MyFreemem;
  MMgr.FreememSize := @MyFreememSize;
  SetMemoryManager(MMgr);
end.


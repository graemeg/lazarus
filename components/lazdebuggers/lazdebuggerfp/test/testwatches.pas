unit TestWatches;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, TestBase, TestDbgControl,
  TestDbgTestSuites, TestOutputLogger, TTestWatchUtilities, TestCommonSources,
  TestDbgConfig, DbgIntfDebuggerBase, DbgIntfBaseTypes, Forms;

type

  { TTestWatches }

  TTestWatches = class(TDBGTestCase)
  private
    FEvalDone: Boolean;
    procedure DoEvalDone(Sender: TObject; ASuccess: Boolean;
      ResultText: String; ResultDBGType: TDBGType);
    procedure RunToPause(var ABrk: TDBGBreakPoint);
  published
    procedure TestWatchesScope;
    procedure TestWatchesValue;
    procedure TestWatchesFunctions;
    procedure TestWatchesAddressOf;
    procedure TestWatchesTypeCast;
    procedure TestWatchesExpression;
    procedure TestWatchesModify;
    procedure TestWatchesErrors;
  end;

implementation

var
  ControlTestWatch, ControlTestWatchScope, ControlTestWatchValue, ControlTestWatchFunct,
  ControlTestWatchAddressOf, ControlTestWatchTypeCast, ControlTestModify,
  ControlTestExpression, ControlTestErrors: Pointer;

procedure TTestWatches.RunToPause(var ABrk: TDBGBreakPoint);
begin
  Debugger.RunToNextPause(dcRun);
  AssertDebuggerState(dsPause);
  ABrk.Enabled := False;
end;

procedure TTestWatches.DoEvalDone(Sender: TObject; ASuccess: Boolean;
  ResultText: String; ResultDBGType: TDBGType);
begin
  if ResultDBGType <> nil then
    ResultDBGType.Free;
  FEvalDone := True;
end;

procedure TTestWatches.TestWatchesScope;

  procedure AddWatchesForClassMethods(t: TWatchExpectationList; AName: String; AStackOffs: Integer);
  var
    n: String;
    f: Integer;
    //IntGlobFlags: TWatchExpErrorHandlingFlags;
  begin
    // Test all outer, class, glopbal scopes are visible - from each stackframe

    n := AName;
    f := -AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f);
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f);
      t.Add(n, 'Int_MethodMainChild'           ,  50, f);
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'Int_TClassMain'                ,  80, f);
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f);
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);
  //    t.Add(n, 'WatchesScopeUnit1.Int_GlobalPrg'   , 101, f).ExpectNotFound;
  //    t.Add(n, 'WatchesScopeUnit1.Int_GlobalUnit1' , 201, f);
  //    t.Add(n, 'WatchesScopeUnit2.Int_GlobalUnit1' , 201, f).ExpectNotFound;
  //    t.Add(n, 'WatchesScopeUnit2.Int_GlobalUnit2' , 202, f);

      t.Add(n, 'Self.Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Self.Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Self.Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'Self.Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'Self.Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'Self.Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'Self.Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'Self.Int_TClassMain'                ,  80, f);
      t.Add(n, 'Self.Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'Self.Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'Self.Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Self.Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Self.Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Self.Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Self.Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Self.Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Self.Int_GlobalPrg'                 , 101, f).ExpectNotFound;
      t.Add(n, 'Self.Int_GlobalUnit1'               , 201, f).ExpectNotFound;
      t.Add(n, 'Self.Int_GlobalUnit2'               , 202, f).ExpectNotFound;

      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain'                ,  80, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase'            , 170, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;

      t.Add(n, 'TClassMain(Self).Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMain'                ,  80, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase'            , 170, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;

      t.Add(n, 'TClassMainBase(Self).Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMain'                ,  80, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMain_Prot'           ,  81, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMain_Priv'           ,  82, f).ExpectNotFound;
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBase'            , 170, f);
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBase_Priv'       , 172, f);
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'TClassMainBase(Self).Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 3001, f);
      t.Add(n + '; Hide, view MainChild', 'Self.Int_HideTest_Class' , 3001, f);
      t.Add(n + '; Hide, view MainChild', 'TClassMain(Self).Int_HideTest_Class' , 0, f).ExpectNotFound.NotImplemented;
      t.Add(n + '; Hide, view MainChild', 'TClassMainBase(Self).Int_HideTest_Class' , 1001, f);
      t.Add(n + '; Hide, view MainChild', 'TObject(Self).Int_HideTest_Class' , 0, f).ExpectNotFound;

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 3010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f);
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f);
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f);
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f);
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f);
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f);

      t.Add(n, 'THideMainEnum(1)', weEnum('hmCNT2'), f);

    end;

    n := AName + ' (Stack: MethodMainChildNested)';
    f := 1 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f);
      t.Add(n, 'Int_MethodMainChild'           ,  50, f);
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'Int_TClassMain'                ,  80, f);
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f);
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 3001, f);
      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 3010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f);
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f);
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f);
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f);
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f);

      t.Add(n, 'THideMainEnum(1)', weEnum('hmCN2'), f);
    end;

    n := AName + ' (Stack: MethodMainChild)';
    f := 2 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild'           ,  50, f);
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'Int_TClassMain'                ,  80, f);
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f);
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 3001, f);
      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 3010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f);
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f);
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f);
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f);

      t.Add(n, 'THideMainEnum(1)', weEnum('hmC2'), f);
    end;

    n := AName + ' (Stack: MethodMain)';
    f := 3 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain'                ,  80, f);
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f);
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n + ', Hide, view glob Prg', 'Int_HideTest_Class' , 3000, f).ExpectNotFound.NotImplemented;

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f).ExpectNotFound;
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f);
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f);
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f);

      t.Add(n, 'THideMainEnum(1)', weEnum('hmB2'), f)^.AddFlag(ehNotImplementedData);
    end;

    n := AName + ' (Stack: MethodMainBase)';
    f := 4 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain'                ,  80, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase'            , 170, f);
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n, 'TClassMain(Self).Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_TClassMain'                ,  80, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase'            , 170, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'TClassMain(Self).Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'TClassMain(Self).Int_GlobalPrg'                 , 101, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_GlobalUnit1'               , 201, f).ExpectNotFound;
      t.Add(n, 'TClassMain(Self).Int_GlobalUnit2'               , 202, f).ExpectNotFound;

      t.Add(n, 'TClassMainChild(Self).Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'TClassMainChild(Self).Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'TClassMainChild(Self).Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'TClassMainChild(Self).Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild'           ,  70, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild_Prot'      ,  71, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainChild_Priv'      ,  72, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain'                ,  80, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain_Prot'           ,  81, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMain_Priv'           ,  82, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase'            , 170, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase_Prot'       , 171, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'TClassMainChild(Self).Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 1001, f);
      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 1010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f).ExpectNotFound;
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f).ExpectNotFound.NotImplemented; // found in other unit
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f);
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f).ExpectNotFound.NotImplemented;

      t.Add(n, 'THideMainEnum(1)', weEnum('hmB2'), f);  // found via unit / but otherwise ehNotImplemented;
    end;

    n := AName + ' (Stack: MethodMainBaseBase)';
    f := 5 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain'                ,  80, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase'            , 170, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f);
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f);
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalUnit1'               , 201, f).ExpectNotFound.NotImplemented;
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 2001, f);
      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 2010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f).ExpectNotFound;
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f).ExpectNotFound.NotImplemented; // found in other unit
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f).ExpectNotFound.NotImplemented; // found in other unit
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f).ExpectNotFound.NotImplemented;

      t.Add(n, 'THideMainEnum(1)', weEnum('x'), f).ExpectNotFound.NotImplemented; // will find main unit
    end;

    n := AName + ' (Stack: main)';
    f := 6 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_MethodMainChildNestedTwice',  30, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChildNested'     ,  40, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild'           ,  50, f).ExpectNotFound;
      t.Add(n, 'Int_MethodMainChild_Late'      ,  51, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild'           ,  70, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Prot'      ,  71, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainChild_Priv'      ,  72, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain'                ,  80, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Prot'           ,  81, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMain_Priv'           ,  82, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase'            , 170, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase_Prot'       , 171, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBase_Priv'       , 172, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBaseBase'        , 270, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBaseBase_Prot'   , 271, f).ExpectNotFound;
      t.Add(n, 'Int_TClassMainBaseBase_Priv'   , 272, f).ExpectNotFound;
      t.Add(n, 'Int_GlobalPrg'                 , 101, f);
      t.Add(n, 'Int_GlobalUnit1'               , 201, f);
      t.Add(n, 'Int_GlobalUnit2'               , 202, f);

      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Class' , 3000, f);
      t.Add(n + '; Hide, view MainChild', 'Int_HideTest_Unit' , 3010, f);

      t.Add(n, 'TMethodMainChildNestedTwiceEnum(1)', weEnum('mmCNT2'), f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildNestedEnum(1)',      weEnum('mmCN2'),  f).ExpectNotFound;
      t.Add(n, 'TMethodMainChildEnum(1)',            weEnum('mmC2'),   f).ExpectNotFound;
      t.Add(n, 'TMainEnum(1)',                       weEnum('mm2'),    f).ExpectNotFound.NotImplemented; // found in unit scope
      t.Add(n, 'TMainBaseEnum(1)',                   weEnum('mmB2'),   f).ExpectNotFound.NotImplemented; // found in unit scope
      t.Add(n, 'TMainGlobEnum(1)',                   weEnum('mmG2'),   f);

      t.Add(n, 'THideMainEnum(1)', weEnum('hmG2'), f)^.AddFlag([ehNotImplementedData]); // may find the class scope
    end;
  end;

  procedure AddWatchesForFoo(t: TWatchExpectationList; AName: String; AStackOffs: Integer; Twice2: Boolean = False);
  var
    n: String;
    f: Integer;
    //IntGlobFlags: TWatchExpErrorHandlingFlags;
  begin

    n := AName;
    f := -AStackOffs;
    if f >= 0 then begin
      if Twice2 then begin
        t.Add(n, 'Int_Hide_Foo',  5, f);
        t.Add(n, 'Result',  'abc2', f).IgnKindPtr.IgnKind(stDwarf3Up);;
      end
      else begin
        t.Add(n, 'Int_Hide_Foo',  4, f);
        t.Add(n, 'Result',  'abc', f).IgnKindPtr.IgnKind(stDwarf3Up);;
      end;
    end;

    n := AName + ' FooNested';
    f := 1 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_Hide_Foo',  3, f);
      t.Add(n, 'Result',  'bar', f).IgnKindPtr.IgnKind(stDwarf3Up);;
    end;

    n := AName + ' Foo';
    f := 2 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_Hide_Foo',  2, f);
      t.Add(n, 'Result',  99, f);
    end;

    n := AName + ' Prg';
    f := 3 - AStackOffs;
    if f >= 0 then begin
      t.Add(n, 'Int_Hide_Foo',  1, f);
      t.Add(n, 'Result',  0, f).ExpectNotFound;
    end;

    // Test: Nested can see Outer scope
    if AStackOffs <= 2 then
      t.Add(n, 'TestEnum',  weEnum('te3'), 0);
    if AStackOffs <= 1 then
      t.Add(n, 'TestEnum',  weEnum('te3'), 1);

  end;

var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestWatchScope) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesScopePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat, skString, skAnsiString, skCurrency, skVariant, skWideString];
    t.AddTypeNameAlias('integer', 'integer|longint');


    Debugger.SetBreakPoint(Src, 'FuncFooNestedTwice');
    Debugger.SetBreakPoint(Src, 'FuncFooNestedTwice2');
    Debugger.SetBreakPoint(Src, 'FuncFooNested');
    Debugger.SetBreakPoint(Src, 'FuncFoo');

    Debugger.SetBreakPoint(Src, 'MethodMainChildNestedTwice');
    Debugger.SetBreakPoint(Src, 'MethodMainChildNested');
    Debugger.SetBreakPoint(Src, 'MethodMainChild');
    Debugger.SetBreakPoint(Src, 'MethodMain');
    Debugger.SetBreakPoint(Src, 'WatchesScopeUnit1.pas', 'MethodMainBase');
    Debugger.SetBreakPoint(Src, 'WatchesScopeUnit2.pas', 'MethodMainBaseBase');

    Debugger.SetBreakPoint(Src, 'Prg');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForFoo(t, 'Scope in FuncFooNestedTwice', 0);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForFoo(t, 'Scope in FuncFooNestedTwice2', 0, True);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForFoo(t, 'Scope in FuncFooNested', 1);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForFoo(t, 'Scope in FuncFoo', 2);
    t.EvaluateWatches;
    t.CheckResults;

    (* ************ Class ************* *)

    Debugger.RunToNextPause(dcRun); // MethodMainChildNestedTwice
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMainChildNestedTwice', 0);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun); // MethodMainChildNested
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMainChildNested', 1);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun); // MethodMainChild
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMainChild', 2);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun); // MethodMain
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMain', 3);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun); // MethodMainBase
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMainBase', 4);
    t.EvaluateWatches;
    t.CheckResults;

    Debugger.RunToNextPause(dcRun); // MethodMainBaseBase
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in MethodMainBaseBase', 5);
    t.EvaluateWatches;
    t.CheckResults;

    (* ************ Program level ************* *)

    Debugger.RunToNextPause(dcRun);
    AssertDebuggerState(dsPause);
    t.Clear;
    AddWatchesForClassMethods(t, 'Scope in Prg', 6);
    AddWatchesForFoo(t, 'Scope in Prg', 3);
    t.EvaluateWatches;
    t.CheckResults;

  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesValue;

  type
    TTestLoc = (tlAny, tlConst, tlParam, tlArrayWrap, tlPointer, tlPointerAny, tlClassConst, tlClassVar);
    TTestIgn = set of (
      tiPointerMath  // pointer math / (ptr+n)^ / ptr[n]
    );

  procedure AddWatches(t: TWatchExpectationList; AName: String; APrefix: String; AOffs: Integer; AChr1: Char;
    ALoc: TTestLoc = tlAny; APostFix: String = ''; AIgnFlags: TTestIgn = []);
  var
    p, e: String;
    n, StartIdx, i, StartIdxClassConst: Integer;
  begin
    p := APrefix;
    e := APostFix;
    n := AOffs;

    t.Add(AName, p+'Byte'+e,       weCardinal(1+n,                    'Byte',     1));
    t.Add(AName, p+'Word'+e,       weCardinal(100+n,                  'Word',     2));
    t.Add(AName, p+'Longword'+e,   weCardinal(1000+n,                 'Longword', 4));
    t.Add(AName, p+'QWord'+e,      weCardinal(10000+n,                'QWord',    8));
    t.Add(AName, p+'Shortint'+e,   weInteger (50+n,                   'Shortint', 1));
    t.Add(AName, p+'Smallint'+e,   weInteger (500+n,                  'Smallint', 2));
    t.Add(AName, p+'Longint'+e,    weInteger (5000+n,                 'Longint',  4));
    t.Add(AName, p+'Int64'+e,      weInteger (50000+n,                'Int64',    8));
    t.Add(AName, p+'IntRange'+e,   weInteger (-50+n,                  'TIntRange',0));
    t.Add(AName, p+'CardinalRange'+e, weInteger(50+n,                 'TCardinalRange',0));

    t.Add(AName, p+'Byte_2'+e,     weCardinal(240+n,                  'Byte',     1));
    t.Add(AName, p+'Word_2'+e,     weCardinal(65501+n,                'Word',     2));
    t.Add(AName, p+'Longword_2'+e, weCardinal(4123456789+n,           'Longword', 4));
    t.Add(AName, p+'QWord_2'+e,    weCardinal(15446744073709551610+n, 'QWord',    8));
    t.Add(AName, p+'Shortint_2'+e, weInteger (112+n,                  'Shortint', 1));
    t.Add(AName, p+'Smallint_2'+e, weInteger (32012+n,                'Smallint', 2));
    t.Add(AName, p+'Longint_2'+e,  weInteger (20123456+n,             'Longint',  4));
    t.Add(AName, p+'Int64_2'+e,    weInteger (9123372036854775801+n,  'Int64',    8));

    t.Add(AName, p+'Shortint_3'+e, weInteger(-112+n,                 'Shortint', 1));
    t.Add(AName, p+'Smallint_3'+e, weInteger(-32012+n,               'Smallint', 2));
    t.Add(AName, p+'Longint_3'+e,  weInteger(-20123456+n,            'Longint',  4));
    t.Add(AName, p+'Int64_3'+e,    weInteger(-9123372036854775801+n, 'Int64',    8));

    t.Add(AName, p+'Bool1'+e,      weBool(False    ));
    t.Add(AName, p+'Bool2'+e,      weBool(True     ));
    t.Add(AName, p+'WBool1'+e,      weBool(False, 'Boolean16'));
    t.Add(AName, p+'WBool2'+e,      weBool(True , 'Boolean16'));
    t.Add(AName, p+'LBool1'+e,      weBool(False, 'Boolean32'));
    t.Add(AName, p+'LBool2'+e,      weBool(True , 'Boolean32'));
    t.Add(AName, p+'QBool1'+e,      weBool(False, 'Boolean64'));
    t.Add(AName, p+'QBool2'+e,      weBool(True , 'Boolean64'));

    t.Add(AName, p+'ByteBool1'+e,  weSizedBool(False, 'ByteBool'));
    t.Add(AName, p+'ByteBool2'+e,  weSizedBool(True , 'ByteBool'));
    t.Add(AName, p+'WordBool1'+e,  weSizedBool(False, 'WordBool'));
    t.Add(AName, p+'WordBool2'+e,  weSizedBool(True , 'WordBool'));
    t.Add(AName, p+'LongBool1'+e,  weSizedBool(False, 'LongBool'));
    t.Add(AName, p+'LongBool2'+e,  weSizedBool(True , 'LongBool'));
    t.Add(AName, p+'QWordBool1'+e, weSizedBool(False, 'QWordBool'));
    t.Add(AName, p+'QWordBool2'+e, weSizedBool(True , 'QWordBool'));

    t.Add(AName, p+'Real'+e,       weFloat(50.25+n,                 'Real'       ));
    t.Add(AName, p+'Single'+e,     weSingle(100.125+n,              'Single'     ));
    t.Add(AName, p+'Double'+e,     weDouble(1000.125+n,             'Double'     ));
    t.Add(AName, p+'Extended'+e,   weFloat(10000.175+n,             ''   )); // Double ?
    {$IFDEF cpu64}
    if Compiler.CpuBitType = cpu32 then // a 64bit debugger does has no 10byte extended type // TODO: check for error
      t.Tests[-1]^.AddFlag(ehExpectError); // TODO: check error msg
    {$ENDIF}
    //t.Add(p+'Comp'+e,       weInteger(150.125+n,              'Comp'       ));
    t.Add(AName, p+'Currency'+e,   weFloat(125.123+n,               'Currency'   ))^.AddFlag([ehNotImplementedData])
      .SkipIf(ALoc = tlPointerAny);

    t.Add(AName, p+'Real_2'+e,     weFloat(-50.25+n,                'Real'       ));
    t.Add(AName, p+'Single_2'+e,   weSingle(-100.125+n,             'Single'     ));
    t.Add(AName, p+'Double_2'+e,   weDouble(-1000.125+n,            'Double'     ));
    t.Add(AName, p+'Extended_2'+e, weFloat(-10000.175+n,            ''   )); // Double ?
    {$IFDEF cpu64}
    if Compiler.CpuBitType = cpu32 then // a 64bit debugger does has no 10byte extended type // TODO: check for error
      t.Tests[-1]^.AddFlag(ehExpectError); // TODO: check error msg
    {$ENDIF}
    //t.Add(p+'Comp_2'+e,     weFloat(-150.125+n,             'Comp'       ));
    t.Add(AName, p+'Currency_2'+e, weFloat(-125.123+n,              'Currency'   ))^.AddFlag([ehNotImplementedData])
      .SkipIf(ALoc = tlPointerAny);

    t.Add(AName, p+'Ptr1'+e, wePointerAddr(nil,                 'Pointer'));
    t.Add(AName, p+'Ptr2'+e, wePointerAddr(Pointer(1000+n),     'Pointer'));

    t.Add(AName, p+'Char'+e,       weChar(AChr1));
    t.Add(AName, p+'Char2'+e,      weChar(#0));
    t.Add(AName, p+'Char3'+e,      weChar(' '));

// tlConst => strings are stored as shortstring
    t.Add(AName, p+'String1'+e,    weShortStr(AChr1, 'ShortStr1'))                      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'String1e'+e,   weShortStr('',    'ShortStr1'))                      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'String10'+e,   weShortStr(AChr1+'bc1',               'ShortStr10')) .IgnTypeName([], ALoc in [tlConst, tlClassConst]).NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'String10e'+e,  weShortStr('',                        'ShortStr10')) .IgnTypeName([], ALoc in [tlConst, tlClassConst]).NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'String10x'+e,  weShortStr(AChr1+'S'#0'B'#9'b'#10#13, 'ShortStr10')) .IgnTypeName([], ALoc in [tlConst, tlClassConst]).NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'String255'+e,  weShortStr(AChr1+'bcd0123456789', 'ShortStr255'))                                      .NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);

    t.Add(AName, p+'Ansi1'+e,      weAnsiStr(Succ(AChr1)))     .IgnKindPtr(stDwarf2).IgnKind(stDwarf3Up)
      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).IgnKind([], ALoc in [tlConst, tlClassConst]);
    t.Add(AName, p+'Ansi2'+e,      weAnsiStr(AChr1+'abcd0123')).IgnKindPtr(stDwarf2).IgnKind(stDwarf3Up)
      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).IgnKind([], ALoc in [tlConst, tlClassConst]);
    t.Add(AName, p+'Ansi3'+e,      weAnsiStr(''))              .IgnKindPtr(stDwarf2).IgnKind(stDwarf3Up)
      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).IgnKind([], ALoc in [tlConst, tlClassConst]);
    t.Add(AName, p+'Ansi4'+e,      weAnsiStr(AChr1+'A'#0'B'#9'b'#10#13))  // cut off at #0 in dwarf2 / except tlConst, because it is a shortstring (kind of works by accident)
             .IgnKindPtr(stDwarf2).IgnData(stDwarf2, not(ALoc in [tlConst, tlClassConst])).IgnKind(stDwarf3Up)
      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).IgnKind([], ALoc in [tlConst, tlClassConst]);
    t.Add(AName, p+'Ansi5'+e,      weAnsiStr(AChr1+'bcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghij'
      ) )    .IgnKindPtr(stDwarf2)                  .IgnKind(stDwarf3Up)
      .IgnTypeName([], ALoc in [tlConst, tlClassConst]).IgnKind([], ALoc in [tlConst, tlClassConst]);

//TODO wePchar
    t.Add(AName, p+'PChar'+e,      wePointer(weAnsiStr(''), 'PChar'));
    t.Add(AName, p+'PChar2'+e,     wePointer(weAnsiStr(AChr1+'abcd0123'), 'TPChr')).SkipIf(ALoc in [tlConst, tlClassConst]);

    // char by index
    // TODO: no typename => calculated value ?
    t.Add(AName, p+'String10'+e+'[2]',   weChar('b', '')).CharFromIndex.NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'Ansi2'+e+'[2]',      weChar('a', '')).CharFromIndex;
    t.Add(AName, p+'PChar2'+e+'[1]',     weChar('a', '')).CharFromIndex.SkipIf(ALoc in [tlConst, tlClassConst]);
    t.Add(AName, p+'String10'+e+'[1]',   weChar(AChr1, '')).CharFromIndex.NotImplemented(stDwarf3up, tiPointerMath in AIgnFlags);
    t.Add(AName, p+'Ansi2'+e+'[1]',      weChar(AChr1, '')).CharFromIndex;
    t.Add(AName, p+'PChar2'+e+'[0]',     weChar(AChr1, '')).CharFromIndex.SkipIf(ALoc in [tlConst, tlClassConst]);


    t.Add(AName, p+'WideChar'+e,       weChar(AChr1)); // TODO: widechar
    t.Add(AName, p+'WideChar2'+e,      weChar(#0));
    t.Add(AName, p+'WideChar3'+e,      weChar(' '));

StartIdx := t.Count; // tlConst => Only eval the watch. No tests
    t.Add(AName, p+'WideString1'+e,    weWideStr(Succ(AChr1)))              .IgnKindPtr;
    t.Add(AName, p+'WideString2'+e,    weWideStr(AChr1+'abcX0123'))         .IgnKindPtr;
    t.Add(AName, p+'WideString3'+e,    weWideStr(''))                       .IgnKindPtr;
    t.Add(AName, p+'WideString4'+e,    weWideStr(AChr1+'A'#0'X'#9'b'#10#13)).IgnKindPtr
      .IgnData(stDwarf2).IgnData([], Compiler.Version < 030100); // cut off at #0
    t.Add(AName, p+'WideString5'+e,    weWideStr(AChr1+'XcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghij',
      'TWStrTA'))                                                         .IgnKindPtr;

    t.Add(AName, p+'WideString2'+e+'[1]',  weWideChar(AChr1))     .CharFromIndex.IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'WideString2'+e+'[2]',  weWideChar('a'))       .CharFromIndex.IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'WideString5'+e+'[1]',  weWideChar(AChr1))     .CharFromIndex.IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'WideString5'+e+'[2]',  weWideChar('X'))       .CharFromIndex.IgnTypeName(stDwarf3Up);
// for tlClassConst the error should be something about "unknown type" due to absence of type info
for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlConst, tlClassConst]);

//TODO wePWidechar
    t.Add(AName, p+'PWideChar'+e,      wePointer(weWideStr(''), 'PWideChar'));
    t.Add(AName, p+'PWideChar2'+e,     wePointer(weWideStr(AChr1+'abcX0123'), 'TPWChr')).SkipIf(ALoc in [tlConst, tlClassConst]);

StartIdx := t.Count; // tlConst => Only eval the watch. No tests
    t.Add(AName, p+'UnicodeString1'+e,    weUniStr(Succ(AChr1)))              .IgnKindPtr(stDwarf2);
    t.Add(AName, p+'UnicodeString2'+e,    weUniStr(AChr1+'aBcX0123'))         .IgnKindPtr(stDwarf2);
    t.Add(AName, p+'UnicodeString3'+e,    weUniStr(''))                       .IgnKindPtr(stDwarf2);
    t.Add(AName, p+'UnicodeString4'+e,    weUniStr(AChr1+'B'#0'X'#9'b'#10#13)).IgnKindPtr(stDwarf2).IgnData(stDwarf2); // #00 terminated in dwarf2
    t.Add(AName, p+'UnicodeString5'+e,    weUniStr(AChr1+'YcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghij',
      'TUStrTA'))                                                         .IgnKindPtr(stDwarf2);

//todo dwarf 3
    t.Add(AName, p+'UnicodeString2'+e+'[1]',    weWideChar(AChr1))       .CharFromIndex(stDwarf2).IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'UnicodeString2'+e+'[2]',    weWideChar('a'))         .CharFromIndex(stDwarf2).IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'UnicodeString5'+e+'[1]',    weWideChar(AChr1))       .CharFromIndex(stDwarf2).IgnTypeName(stDwarf3Up);
    t.Add(AName, p+'UnicodeString5'+e+'[2]',    weWideChar('Y'))         .CharFromIndex(stDwarf2).IgnTypeName(stDwarf3Up);
for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlConst, tlClassConst]);


    // TODO
    t.Add(AName, p+'ShortRec'+e,     weMatch(''''+AChr1+''', *''b'', *'''+AChr1+'''', skRecord))
      .SkipIf(ALoc in [tlClassConst])
      .SkipIf(ALoc = tlPointerAny);


StartIdx := t.Count;
    t.add(AName, p+'CharDynArray'+e,  weDynArray([]                                        )).SkipIf(ALoc in [tlPointer, tlClassConst]);
    t.add(AName, p+'CharDynArray2'+e, weDynArray(weChar(['N', AChr1, 'M'])                 )).SkipIf(ALoc in [tlConst, tlClassConst, tlPointer]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.add(AName, p+'CharDynArray3'+e, weDynArray([],                        'TCharDynArray')).SkipIf(ALoc in [tlClassConst]);
    t.Add(AName, p+'CharDynArray4'+e, weDynArray(weChar(['J', AChr1, 'M']), 'TCharDynArray')).SkipIf(ALoc in [tlConst, tlClassConst]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);

    t.Add(AName, p+'WCharDynArray'+e, weDynArray([]                        )).SkipIf(ALoc in [tlPointer, tlClassConst]);
    t.Add(AName, p+'WCharDynArray2'+e,weDynArray(weWideChar(['W', AChr1, 'M']) )).SkipIf(ALoc in [tlConst, tlClassConst,tlPointer]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.Add(AName, p+'WCharDynArray3'+e,weDynArray([]                        )).SkipIf(ALoc in [tlClassConst]);
    t.Add(AName, p+'WCharDynArray4'+e,weDynArray(weWideChar(['K', AChr1, 'M']) )).SkipIf(ALoc in [tlConst, tlClassConst]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);

    t.add(AName, p+'IntDynArray'+e,   weDynArray([]                                           )).SkipIf(ALoc in [tlPointer]);
    t.add(AName, p+'IntDynArray2'+e,  weDynArray(weInteger([11, 30+AOffs, 60])                )).SkipIf(ALoc in [tlConst,tlPointer]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.add(AName, p+'IntDynArray3'+e,  weDynArray([],                            'TIntDynArray'));
    t.Add(AName, p+'IntDynArray4'+e,  weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray')).SkipIf(ALoc in [tlConst]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);

    t.add(AName, p+'IntDynArray5'+e,  weDynArray([],                            'TIntDynArray'));

    t.add(AName, p+'AnsiDynArray'+e,  weDynArray([]                                                     )).SkipIf(ALoc in [tlPointer]);
    t.add(AName, p+'AnsiDynArray2'+e, weDynArray(weAnsiStr(['N123', AChr1+'ab', 'M'#9])                 )).SkipIf(ALoc in [tlConst,tlPointer]);
// TODO: currently gets skPointer instead of skAnsiString (dwarf 2)
//    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.add(AName, p+'AnsiDynArray3'+e, weDynArray([],                                     'TAnsiDynArray'));
    t.Add(AName, p+'AnsiDynArray4'+e, weDynArray(weAnsiStr(['J123', AChr1+'ab', 'M'#9]), 'TAnsiDynArray')).SkipIf(ALoc in [tlConst]);
// TODO: currently gets skPointer instead of skAnsiString (dwarf 2)
//    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);

    t.add(AName, p+'ShortStrDynArray'+e,  weDynArray([]                                                          )).SkipIf(ALoc in [tlPointer]);
    t.add(AName, p+'ShortStrDynArray2'+e, weDynArray(weShortStr(['N123', AChr1+'ac', 'M'#9], 'ShortStr10')                     ))
      .SkipIf(ALoc in [tlConst,tlPointer]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.add(AName, p+'ShortStrDynArray3'+e, weDynArray([],                                      'TShortStrDynArray'));
    t.Add(AName, p+'ShortStrDynArray4'+e, weDynArray(weShortStr(['J123', AChr1+'ac', 'M'#9], 'ShortStr10'), 'TShortStrDynArray'))
      .SkipIf(ALoc = tlConst);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlClassConst]);


StartIdx := t.Count; // tlConst => Only eval the watch. No tests
    t.Add(AName, p+'DynDynArrayInt'+e, weDynArray([
        weDynArray(weInteger([11+AOffs,0,-22])),
        weDynArray(weInteger([110+AOffs])),
        weDynArray(weInteger([11+AOffs,0,-22])),
        weDynArray(weInteger([])),
        weDynArray(weInteger([11,12,11,10]))
      ], 'TDynDynArrayInt'));

    t.Add(AName, p+'DynDynArrayInt'+e+'[0]', weDynArray(weInteger([11+AOffs,0,-22])) );
    t.Add(AName, p+'DynDynArrayInt'+e+'[1]', weDynArray(weInteger([110+AOffs])) );
    t.Add(AName, p+'DynDynArrayInt'+e+'[2]', weDynArray(weInteger([11+AOffs,0,-22])) );
    t.Add(AName, p+'DynDynArrayInt'+e+'[3]', weDynArray(weInteger([])) );
    t.Add(AName, p+'DynDynArrayInt'+e+'[4]', weDynArray(weInteger([11,12,11,10])) );

    t.Add(AName, p+'DynDynArrayInt2'+e+'[0]', weDynArray(weInteger([11+AOffs,0,-22])) );
    t.Add(AName, p+'DynDynArrayInt2'+e+'[1]', weDynArray(weInteger([110+AOffs])) );
    t.Add(AName, p+'DynDynArrayInt2'+e+'[2]', weDynArray(weInteger([11+AOffs,0,-22])) );
    t.Add(AName, p+'DynDynArrayInt2'+e+'[3]', weDynArray(weInteger([])) );
    t.Add(AName, p+'DynDynArrayInt2'+e+'[4]', weDynArray(weInteger([11,12,11,10])) );


/////    t.Add(AName, p+'pre__FiveDynArray'+e,  weStatArray(weChar([AChr1, 'b', AChr1, 'B', 'c'])                  ))
t.Add(AName, p+'FiveDynArray'+e,            weMatch('.*',skArray));
t.Add(AName, p+'FiveDynArray'+e+'[0]',      weMatch('.*',skRecord));
//    t.Add(AName, p+'FiveDynArray'+e,            we());
//    t.Add(AName, p+'FiveDynArrayPack'+e,        we());
//    t.Add(AName, p+'FivePackDynArray'+e,        we());
//    t.Add(AName, p+'FivePackDynArrayPack'+e,    we());
//    t.Add(AName, p+'RecFiveDynArray'+e,         we());
//    t.Add(AName, p+'RecFiveDynPackArray'+e,     we());
//    t.Add(AName, p+'RecFivePackDynArray'+e,     we());
//    t.Add(AName, p+'RecFivePackDynPackArray'+e, we());
//    t.Add(AName, p+'FiveDynArray2'+e,           we());
//    t.Add(AName, p+'FiveDynArrayPack2'+e,       we());
//    t.Add(AName, p+'FivePackDynArray2'+e,       we());
//    t.Add(AName, p+'FivePackDynArrayPack2'+e,   we());

for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlConst, tlClassConst]);


StartIdxClassConst := t.Count;
    t.Add(AName, p+'FiveRec'+e,            weMatch('a *=.*b *= *44',skRecord))
      .SkipIf(ALoc = tlPointerAny);
    t.Add(AName, p+'FiveRec'+e,     weRecord([weInteger(-22-n).N('a'), weInteger(44).N('b')], 'TRecordFive'))
      .SkipIf(ALoc = tlPointerAny);

      // FDynInt  // nil for tlconst
    t.Add(AName, p+'Instance1'+e,   weClass([weInteger(22+n).N('FInt'), weAnsiStr(AChr1+'T').N('FAnsi')], 'TClass1'))
      .AddFlag(ehMissingFields)
      .SkipIf(ALoc in [tlConst, tlPointerAny]);

    t.Add(AName, p+'Obj3'+e,   weObject([weInteger(-22).N('a'), weInteger(44).N('b'), weInteger(4000+n).N('c')],
      'TObject3Int64'))
      .Skip(stDwarf3Up)  // fixed in fpc 3.3 with .SkipKind since it reports skRecord
      .IgnKind([], Compiler.Version < 029900)
      .SkipIf(ALoc = tlPointerAny);
    t.Add(AName, p+'Obj3Ex'+e,   weObject([weInteger(-22).N('a'), weInteger(44).N('b'), weInteger(4100+n).N('c'), weInteger(555).N('d')],
      'TObject3Int64Ex'))
      .Skip(stDwarf3Up)  // fixed in fpc 3.3 with .SkipKind since it reports skRecord
      .SkipIf(ALoc = tlPointerAny);
    t.Add(AName, p+'Obj3C'+e,   weObject([weInteger(22).N('a'), weInteger(44).N('b'), weInteger(4200+n).N('c')],
      'TObjectCreate3Int64'))
      .AddFlag(ehMissingFields)
      .Skip(stDwarf3Up)  // fixed in fpc 3.3
      .SkipIf(ALoc in [tlConst, tlPointerAny]);
    t.Add(AName, p+'Obj3ExC'+e,   weObject([weInteger(22).N('a'), weInteger(44).N('b'), weInteger(4300+n).N('c'), weInteger(655).N('d')],
      'TObjectCreate3Int64Ex'))
      .AddFlag(ehMissingFields)
      .Skip(stDwarf3Up)  // fixed in fpc 3.3
      .SkipIf(ALoc in [tlConst, tlPointerAny]);


    t.Add(AName, p+'CharStatArray'+e,  weStatArray(weChar([AChr1, 'b', AChr1, 'B', 'c'])                  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'CharStatArray2'+e, weStatArray(weChar([AChr1, 'c', AChr1, 'B', 'c']), 'TCharStatArray'));

    t.Add(AName, p+'WCharStatArray'+e, weStatArray(weChar([AChr1, 'b', AChr1, 'B', 'd'])                   ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'WCharStatArray2'+e,weStatArray(weChar([AChr1, 'c', AChr1, 'B', 'd']), 'TwCharStatArray'));

    t.Add(AName, p+'IntStatArray'+e,  weStatArray(weInteger([-1, 300+AOffs, 2, 0, 1])                 ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'IntStatArray2'+e, weStatArray(weInteger([-2, 200+AOffs, 2, 0, 1]), 'TIntStatArray'));

    t.Add(AName, p+'AnsiStatArray'+e,  weStatArray(weAnsiStr([AChr1, 'b123', AChr1+'ab', 'B', 'cdef'#9])                  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'AnsiStatArray2'+e, weStatArray(weAnsiStr([AChr1, 'c123', AChr1+'ad', 'D', 'cxx'#9] ), 'TAnsiStatArray'));

    t.Add(AName, p+'ShortStrStatArray'+e,  weStatArray(weShortStr([AChr1, 'b123', AChr1+'ab', 'C', 'cdef'#9])                  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'ShortStrStatArray2'+e, weStatArray(weShortStr([AChr1, 'c123', AChr1+'ad', 'C', 'cxx'#9] ), 'TShortStrStatArray'));

//    t.Add(AName, p+'FiveStatArray{e}             _O2_ TFiveStatArray            _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_FiveStatArray;
//    t.Add(AName, p+'FiveStatArrayPack{e}         _O2_ TFiveStatArrayPack        _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_FiveStatArrayPack;
//    t.Add(AName, p+'FivePackStatArray{e}         _O2_ TFivePackStatArray        _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_FivePackStatArray;
//    t.Add(AName, p+'FivePackStatArrayPack{e}     _O2_ TFivePackStatArrayPack    _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_FivePackStatArrayPack;
//    t.Add(AName, p+'RecFiveStatArray{e}          _O2_ TRecFiveStatArray         _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_RecFiveStatArray;
//    t.Add(AName, p+'RecFiveStatPackArray{e}      _O2_ TRecFiveStatPackArray     _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_RecFiveStatPackArray;
//    t.Add(AName, p+'RecFivePackStatArray{e}      _O2_ TRecFivePackStatArray     _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_RecFivePackStatArray;
//    t.Add(AName, p+'RecFivePackStatPackArray{e}  _O2_ TRecFivePackStatPackArray _EQ_ ((a:-9;b:44), (a:-8-ADD;b:33), (a:-7;b:22));          //@@ _pre3_RecFivePackStatPackArray;


//TODO: element by index


    t.Add(AName, p+'ArrayEnum1'+e, weStatArray(weInteger([500+n,701,702,703])  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.AddIndexFromPrevious(['EnVal1','EnVal2','EnVal3','EnVal4',
     'gvEnum', 'gvEnumA', 'gvEnum1',  'gcEnum', 'gcEnumA', 'gcEnum1',   p+'Enum'+e, p+'EnumA'+e, p+'Enum1'+e],
     [0,1,2,3,  2,0,1,  2,0,1,  2,0,1]);
    t.Add(AName, p+'ArrayEnum3'+e, weStatArray(weInteger([200+n,701,702,703]), 'TArrayEnum'));
    t.AddIndexFromPrevious(['EnVal1','EnVal2','EnVal3','EnVal4',
     'gvEnum', 'gvEnumA', 'gvEnum1',  'gcEnum', 'gcEnumA', 'gcEnum1',   p+'Enum'+e, p+'EnumA'+e, p+'Enum1'+e],
     [0,1,2,3,  2,0,1,  2,0,1,  2,0,1]);

    t.Add(AName, p+'ArrayEnumSub1'+e, weStatArray(weInteger([600+n,801])  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.AddIndexFromPrevious(['EnVal1','EnVal2',
     'gvEnumA', 'gvEnum1',  'gcEnumA', 'gcEnum1',   p+'EnumA'+e, p+'Enum1'+e],
     [0,1,  0,1,  0,1,  0,1]);
    t.Add(AName, p+'ArrayEnumSub3'+e, weStatArray(weInteger([100+n,801]), 'TArrayEnumSub'));
    t.AddIndexFromPrevious(['EnVal1','EnVal2',
     'gvEnumA', 'gvEnum1',  'gcEnumA', 'gcEnum1',   p+'EnumA'+e, p+'Enum1'+e],
     [0,1,  0,1,  0,1,  0,1]);

    t.Add(AName, p+'ArrayEnum2'+e, weStatArray(weInteger([300+n,701,702,703])  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.AddIndexFromPrevious(['EnVal1','EnVal2','EnVal3','EnVal4',
     'gvEnum', 'gvEnumA', 'gvEnum1',  'gcEnum', 'gcEnumA', 'gcEnum1',   p+'Enum'+e, p+'EnumA'+e, p+'Enum1'+e],
     [0,1,2,3,  2,0,1,  2,0,1,  2,0,1]);
    t.Add(AName, p+'ArrayEnum4'+e, weStatArray(weInteger([800+n,701,702,703]), 'TArrayEnumElem'));
    t.AddIndexFromPrevious(['EnVal1','EnVal2','EnVal3','EnVal4',
     'gvEnum', 'gvEnumA', 'gvEnum1',  'gcEnum', 'gcEnumA', 'gcEnum1',   p+'Enum'+e, p+'EnumA'+e, p+'Enum1'+e],
     [0,1,2,3,  2,0,1,  2,0,1,  2,0,1]);

    t.Add(AName, p+'ArrayEnumSub2'+e, weStatArray(weInteger([400+n,801])  ))
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.AddIndexFromPrevious(['EnVal1','EnVal2',
     'gvEnumA', 'gvEnum1',  'gcEnumA', 'gcEnum1',   p+'EnumA'+e, p+'Enum1'+e],
     [0,1,  0,1,  0,1,  0,1]);
    t.Add(AName, p+'ArrayEnumSub4'+e, weStatArray(weInteger([700+n,801]), 'TArrayEnumSubElem'));
    t.AddIndexFromPrevious(['EnVal1','EnVal2',
     'gvEnumA', 'gvEnum1',  'gcEnumA', 'gcEnum1',   p+'EnumA'+e, p+'Enum1'+e],
     [0,1,  0,1,  0,1,  0,1]);




    t.Add(AName, p+'Enum'+e, weEnum('EnVal3', 'TEnum'));
    t.Add(AName, p+'Enum1'+e, weEnum('EnVal2', 'TEnumSub'));
    t.Add(AName, p+'Enum2'+e, weEnum('EnVal21', 'TEnum2'));
    t.Add(AName, p+'Enum3'+e, weEnum('EnVal25', 'TEnum2'));

//    t.Add(AName, 'EnVal2', weMatch('xxx', skEnumValue));

    t.Add(AName, p+'Enum16'+e, weEnum('ExVal23', 'TEnum16'));
    t.Add(AName, p+'Enum16A'+e, weEnum('ExValX5', 'TEnum16'));

    t.Add(AName, p+'Set'+e, weSet(['EnVal2', 'EnVal4'], 'TSet')).Skip([stDwarf]);
    t.Add(AName, p+'Set2'+e, weSet(['EnVal1', 'EnVal4'], '{set}')).Skip([stDwarf])
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);

    t.Add(AName, p+'Set4'+e, weSet(['E4Val02', 'E4Val0A'], 'TSet4')).Skip([stDwarf]);
    t.Add(AName, p+'Set5'+e, weSet(['E5Val02', 'E5Val12'], 'TSet5')).Skip([stDwarf]);
    t.Add(AName, p+'Set6'+e, weSet(['E6Val02', 'E6Val1A'], 'TSet6')).Skip([stDwarf]);
    t.Add(AName, p+'Set7'+e, weSet(['E7Val02', 'E7Val3A'], 'TSet7')).Skip([stDwarf]);
    t.Add(AName, p+'Set8'+e, weSet(['E8Val02', 'E8Val5B'], 'TSet8')).Skip([stDwarf]);

    t.Add(AName, p+'SmallSet'+e, weSet(['22', '24', '25'], 'TSmallRangeSet')).Skip([stDwarf])
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);
    t.Add(AName, p+'SmallSet2'+e, weSet(['21', '24', '25'], '{set}')).Skip([stDwarf])
      .SkipIf(ALoc = tlParam).SkipIf(ALoc = tlPointer);



    t.Add(AName, p+'IntfUnknown1'+e, weMatch('.?', skInterface)) //.Skip(); // only run eval / do not crash
      .SkipIf(ALoc = tlPointerAny);
    t.Add(AName, p+'IntfUnknown'+e, weMatch('nil', skInterface)); //.Skip(); // only run eval / do not crash


StartIdx := t.Count; // tlConst => Only eval the watch. No tests
    t.Add(AName, p+'SomeFunc1Ref'+e,         weMatch('\$[0-9A-F]+ = SomeFunc1: *function *\(SOMEVALUE, Foo: LONGINT; Bar: Word; x: Byte\): *BOOLEAN', skFunctionRef) );
    t.Add(AName, '@'+p+'SomeFunc1Ref'+e,     wePointer('^TFunc1') ).AddFlag(ehIgnPointerDerefData);
    t.Add(AName, p+'SomeProc1Ref'+e,         weMatch('\$[0-9A-F]+ = SomeProc1: *procedure *\(\) *$', skProcedureRef) );
    t.Add(AName, p+'SomeMeth1Ref'+e,         weMatch('TMeth1.*Proc *= *\$[0-9A-F]+ *= *TMyBaseClass\.SomeMeth1.*: *TMeth1;[\s\r\n]*Self.*=.*', skRecord) );
    t.Add(AName, p+'SomeMeth1Ref'+e+'.Proc', weMatch('\$[0-9A-F]+ = TMyBaseClass\.SomeMeth1: *function *\(.*AVal.*\): *BOOLEAN', skFunctionRef) );
for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlConst, tlPointerAny]);


  // bitpacked
    t.Add(AName, p+'BitPackBoolArray'+e,     weStatArray(weBool([True, False, True, True])   ));
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackTinyArray'+e,     weStatArray(weInteger([1, 0, 3, 2])   ));
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackTinyNegArray'+e,  weStatArray(weInteger([2, -2, 0, -1])   ));
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackEnumArray'+e,  weStatArray(weEnum(['EnVal3', 'EnVal1', 'EnVal2', 'EnVal3'])   ));
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackEnum3Array'+e,  weStatArray(weEnum(['EnVal32', 'EnVal32', 'EnVal31', 'EnVal32'])   ));
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackSetArray'+e,  weStatArray([ weSet(['EnVal1', 'EnVal3']), weSet([]), weSet(['EnVal3']), weSet(['EnVal1'])]  ))
      .Skip([stDwarf]);
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackSet3Array'+e,  weStatArray([weSet(['EnVal31', 'EnVal32']), weSet([]), weSet(['EnVal31']), weSet(['EnVal32'])]  ))
      .Skip([stDwarf]);
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);


    t.Add(AName, p+'BitPackBoolArray2'+e,     weStatArray([
       weStatArray(weBool([True, False, True])),
       weStatArray(weBool([False, True, True]))
    ]));
    t.AddIndexFromPrevious(['0','1'], [0,1]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.Add(AName, p+'BitPackTinyArray2'+e,     weStatArray([
        weStatArray(weInteger([1, 0, 3])),
        weStatArray(weInteger([2, 3, 0]))
    ]));
    t.AddIndexFromPrevious(['0','1'], [0,1]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.Add(AName, p+'BitPackTinyNegArray2'+e,  weStatArray([
        weStatArray(weInteger([2, -2, 0])),
        weStatArray(weInteger([1, 0, -1]))
    ]));
    t.AddIndexFromPrevious(['0','1'], [0,1]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.Add(AName, p+'BitPackEnumArray2'+e,  weStatArray([
        weStatArray(weEnum(['EnVal3', 'EnVal1', 'EnVal2'])),
        weStatArray(weEnum(['EnVal1', 'EnVal4', 'EnVal2']))
    ]));
    t.AddIndexFromPrevious(['0','1'], [0,1]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    t.Add(AName, p+'BitPackEnum3Array2'+e,  weStatArray([
        weStatArray(weEnum(['EnVal32', 'EnVal32', 'EnVal31'])),
        weStatArray(weEnum(['EnVal31', 'EnVal31', 'EnVal32']))
    ]));
    t.AddIndexFromPrevious(['0','1'], [0,1]);
    t.AddIndexFromPrevious(['0','1','2'], [0,1,2]);
    //t.Add(AName, p+'BitPackEnumSet'+e,  weStatArray(weSet(['EnVal3', 'EnVal1']), weSet([]), weSet(['EnVal3']), weSet(['EnVal1'])  ));
    //t.AddIndexFromPrevious(['0','1'], [0,1]);
    //t.Add(AName, p+'BitPackEnumSet3'+e,  weStatArray(weSet(['EnVal31', 'EnVal32']), weSet([]), weSet(['EnVal31']), weSet(['EnVal32'])  ));
    //t.AddIndexFromPrevious(['0','1'], [0,1]);


    t.Add(AName, p+'BitPackBoolRecord'+e,     weRecord([
      weBool(True).N('a'), weBool(False).N('b'), weBool(True).N('c'), weBool(True).N('d'), weBool(False).N('e')
    ], 'TBitPackBoolRecord')   );
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackTinyRecord'+e,     weRecord([
      weInteger(1).N('a'), weInteger(1).N('b'), weInteger(0).N('c'), weInteger(3).N('d'), weInteger(0).N('e')
    ], 'TBitPackTinyRecord')   );
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackTinyNegRecord'+e,     weRecord([
      weInteger(3).N('a'), weInteger(-2).N('b'), weInteger(-1).N('c'), weInteger(0).N('d'), weInteger(1).N('e')
    ], 'TBitPackTinyNegRecord')   );
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackEnumRecord'+e,     weRecord([
      weEnum('EnVal3').N('a'), weEnum('EnVal1').N('b'), weEnum('EnVal2').N('c'), weEnum('EnVal2').N('d'), weEnum('EnVal1').N('e')
    ], 'TBitPackEnumRecord')   );
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackEnum3Record'+e,     weRecord([
      weEnum('EnVal31').N('a'), weEnum('EnVal32').N('b'), weEnum('EnVal31').N('c'), weEnum('EnVal31').N('d'), weEnum('EnVal32').N('e')
    ], 'TBitPackEnum3Record')   );
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackSetRecord'+e,     weRecord([
      weSet(['EnVal3']).N('a'), weSet([]).N('b'), weSet(['EnVal1','EnVal2']).N('c'), weSet(['EnVal2']).N('d'), weSet(['EnVal1','EnVal3']).N('e')
    ], 'TBitPackSetRecord')   )
      .Skip([stDwarf]);
    t.AddMemberFromPrevious();
    t.Add(AName, p+'BitPackSet3Record'+e,     weRecord([
      weSet(['EnVal31']).N('a'), weSet([]).N('b'), weSet(['EnVal31','EnVal32']).N('c'), weSet(['EnVal32']).N('d'), weSet(['EnVal31']).N('e')
    ], 'TBitPackSet3Record')   )
      .Skip([stDwarf]);
    t.AddMemberFromPrevious();

    t.Add(AName, p+'BitPackBoolArrayRecord'+e,     weRecord([
       weStatArray(weBool([True, False, True, True])).N('a'),
       weStatArray(weBool([False, True, True, False])).N('b')
    ], 'TBitPackBoolArrayRecord')   );
    t.AddMemberFromPrevious();
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);

    t.Add(AName, p+'BitPackTinyArrayRecord'+e,     weRecord([
        weStatArray(weInteger([1, 0, 3, 2])).N('a'),
        weStatArray(weInteger([2, 3, 0, 1])).N('b')
    ], 'TBitPackTinyArrayRecord')   );
    t.AddMemberFromPrevious();
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);
    t.Add(AName, p+'BitPackTinyNegArrayRecord'+e,     weRecord([
        weStatArray(weInteger([2, -2, 0, -1])).N('a'),
        weStatArray(weInteger([1, 0, -1, 2])).N('b')
    ], 'TBitPackTinyNegArrayRecord')   );
    t.AddMemberFromPrevious();
    t.AddIndexFromPrevious(['0','1','2','3'], [0,1,2,3]);


    t.Add(AName, p+'FpDbgValueSize'+e,     weRecord([weInteger(0).N('Size'), weInteger(2).N('BitSize')], 'TFpDbgValueSize')   )
      .Skip([stDwarf]).SkipIf(ALoc in [tlConst, tlPointerAny]);
    t.AddMemberFromPrevious();
for i := StartIdxClassConst to t.Count-1 do
  t.Tests[i].SkipIf(ALoc in [tlClassConst]);

  end;

var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg, BrkFooBegin, BrkFoo, BrkFooVar, BrkFooVarBegin,
    BrkFooConstRef: TDBGBreakPoint;
  c, i: Integer;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestWatchValue) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface, skEnumValue];
    t.AddTypeNameAlias('integer', 'integer|longint');
    t.AddTypeNameAlias('ShortStr255', 'ShortStr255|ShortString');
    t.AddTypeNameAlias('TEnumSub', 'TEnum|TEnumSub');


    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    BrkFooBegin    := Debugger.SetBreakPoint(Src, 'FooBegin');
    BrkFoo         := Debugger.SetBreakPoint(Src, 'Foo');
    BrkFooVarBegin := Debugger.SetBreakPoint(Src, 'FooVarBegin');
    BrkFooVar      := Debugger.SetBreakPoint(Src, 'FooVar');
    BrkFooConstRef := Debugger.SetBreakPoint(Src, 'FooConstRef');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);
    t.Clear;

//t.Add('gvBitPackBoolArray',     weStatArray(weBool([True, False, True, True])   ));
  //t.Add('MyClass2.cl_c_Byte',     weStatArray(weBool([True, False, True, True])   ));
  //t.Add('MyClass2.cl_c_ShortRec',     weStatArray(weBool([True, False, True, True])   ));
//t.EvaluateWatches;
//t.CheckResults;
//exit;

    t.Add('U8Data1',    weAnsiStr(''''#$E2#$89#$A7'''', 'Utf8String'))
    //t.Add('U8Data1',    weAnsiStr(''''#$2267'''', 'Utf8String'))
     .NoCharQuoting
     .IgnTypeName.IgnKind
     .skipIf(Compiler.Version < 030000);
    t.Add('U8Data2',    weAnsiStr(''''#$E2#$89#$A7'X''', 'Utf8String'))
    //t.Add('U8Data2',    weAnsiStr(''''#$2267'X''', 'Utf8String'))
     .NoCharQuoting
     .IgnTypeName.IgnKind
     .skipIf(Compiler.Version < 030000);

    t.Add('SomeFunc1',    weMatch('^function *\(SOMEVALUE, Foo: LONGINT; Bar: Word; x: Byte\): *BOOLEAN *AT *\$[0-9A-F]+', skFunction) );
    t.Add('SomeProc1',    weMatch('^procedure *\(\) *AT *\$[0-9A-F]+', skProcedure) );
    t.Add('@SomeFunc1',   weMatch('^\^function.*\(\$[0-9A-F]+\)'{' = SomeFunc1'}, skPointer {skFunctionRef}) );
    t.Add('@SomeProc1',   weMatch('^\^procedure.*\(\$[0-9A-F]+\)'{' = SomeFunc1'}, skPointer {skProcedureRef}) );

    // TODO: TClass1 must not contain "<unknown>"
    // '    _vptr$TOBJECT: Pointer'
    t.Add( 'TClass1',       weMatch('type class\(TObject\).*FInt: (integer|longint).*end', skType)).AddFlag(ehNoTypeInfo);
    t.Add( 'TClass1',       weMatch('type class\(TObject\).*_vptr\$TOBJECT: *Pointer.*end', skType)).AddFlag(ehNoTypeInfo);
    t.Add( 'TFunc1',        weMatch('type function *\(SomeValue.*\) *: *Boolean', skType)).AddFlag(ehNoTypeInfo);
    t.Add( 'TIntStatArray', weMatch('type array *\[1\.\.5\] *of (integer|longint)', skType)).AddFlag(ehNoTypeInfo);
    t.Add( 'TIntDynArray',  weMatch('type array of (integer|longint)', skType)).AddFlag(ehNoTypeInfo);
    t.Add( 'byte',          weMatch('type byte', skType)).AddFlag(ehNoTypeInfo);

    t.Add('MyStringItemList',                 weStatArray([], -1) ).IgnTypeName();
    t.Add('MyStringList.FLIST^',                 weStatArray([], -1) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(MyStringList).FLIST^',    weStatArray([], -1) ).IgnTypeName();
    t.Add('MyClass1.FMyStringList.FLIST^',                 weStatArray([], -1) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(MyClass1.FMyStringList).FLIST^',    weStatArray([], -1) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(TMyClass(MyClass1).FMyStringList).FLIST^',    weStatArray([], -1) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(TMyClass(MyClass2).FMyStringList).FLIST^',    weStatArray([], -1) ).IgnTypeName();

    t.Add('MyStringList.FLIST^[0]',                 weMatch('FString', skRecord) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(MyStringList).FLIST^[0]',    weMatch('FString', skRecord) ).IgnTypeName();
    t.Add('MyClass1.FMyStringList.FLIST^[0]',                 weMatch('FString', skRecord) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(MyClass1.FMyStringList).FLIST^[0]',    weMatch('FString', skRecord) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(TMyClass(MyClass1).FMyStringList).FLIST^[0]',    weMatch('FString', skRecord) ).IgnTypeName();
    t.Add('TMYSTRINGLIST(TMyClass(MyClass2).FMyStringList).FLIST^[0]',    weMatch('FString', skRecord) ).IgnTypeName();

    // make sure no deep recorsion...
    t.Add('TSize', 'TSize', weMatch('.', skType)).AddFlag(ehNoTypeInfo);
    t.Add('TFuncSelfRef', 'TFuncSelfRef', weMatch('.', skType)).AddFlag(ehNoTypeInfo)
    .SkipIf(Compiler.Version < 029900);
    t.Add('PFuncSelfRef', 'PFuncSelfRef', weMatch('.', skType)).AddFlag(ehNoTypeInfo)
    .SkipIf(Compiler.Version < 029900);

    t.Add('EnVal1', 'EnVal1', weMatch('EnVal1 *:?= *0', skEnumValue));
    t.Add('EnVal2', 'EnVal2', weMatch('EnVal2 *:?= *1', skEnumValue));
    t.Add('EnVal3', 'EnVal3', weMatch('EnVal3 *:?= *2', skEnumValue));
    t.Add('EnVal21', 'EnVal21', weMatch('EnVal21 *:?= *3', skEnumValue));
    t.Add('EnVal23', 'EnVal23', weMatch('EnVal23 *:?= *7', skEnumValue));

    AddWatches(t, 'glob const', 'gc', 000, 'A', tlConst);
    AddWatches(t, 'glob var',   'gv', 001, 'B');
    AddWatches(t, 'glob var (@)^',   '(@gv', 001, 'B', tlAny, ')^');
    AddWatches(t, 'glob var (@)[0]',   '(@gv', 001, 'B', tlAny, ')[0]');
//    AddWatches(t, 'glob var @^',   '@gv', 001, 'B', tlAny, '^');

    AddWatches(t, 'glob MyClass1',     'MyClass1.mc',  002, 'C');
    AddWatches(t, 'glob MyBaseClass1', 'MyClass1.mbc', 003, 'D');
    AddWatches(t, 'glob cast MyClass2',     'TMyClass(MyClass2).mc',  004, 'E');
    AddWatches(t, 'glob cast MyBaseClass2', 'TMyClass(MyClass2).mbc', 005, 'F');
    AddWatches(t, 'glob MyPClass1',          'MyPClass1^.mc',  002, 'C');
    AddWatches(t, 'glob cast MyPClass2',     'TMyClass(MyPClass2^).mc',  004, 'E');

    c := t.Count; // Do not crash when accessing fields on nil
    AddWatches(t, 'glob MyNilClass1',     'MyNilClass1.mc',  002, 'C');
    for i := c to t.Count-1 do
      t.Tests[i].Skip;

    AddWatches(t, 'glob TMyBaseClass class const',   'TMyBaseClass.cl_c_',  001, 'c', tlClassConst);
    AddWatches(t, 'glob TMyClass class const',   'TMyClass.cl_c_',  001, 'c', tlClassConst);
    c := t.Count;
    AddWatches(t, 'glob TMyBaseClass class var',     'TMyBaseClass.cl_v_',  007, 'v', tlClassVar);
    AddWatches(t, 'glob TMyClass class var',     'TMyClass.cl_v_',  007, 'v', tlClassVar);
    for i := c to t.Count-1 do
      t.Tests[i].Skip;  // class var do not work => but ensure they do not crash

    AddWatches(t, 'glob MyClass2 class const',   'MyClass2.cl_c_',  001, 'c', tlClassConst);
    AddWatches(t, 'glob MyClass1 class const',   'MyClass1.cl_c_',  001, 'c', tlClassConst);
    c := t.Count;
    AddWatches(t, 'glob MyClass2 class var',     'MyClass2.cl_v_',  007, 'v', tlClassVar);
    AddWatches(t, 'glob MyClass1 class var',     'MyClass1.cl_v_',  007, 'v', tlClassVar);
    for i := c to t.Count-1 do
      t.Tests[i].Skip;  // class var do not work => but ensure they do not crash

    AddWatches(t, 'glob MyTestRec1',     'MyTestRec1.rc_f_',  002, 'r');
    AddWatches(t, 'glob MyPTestRec1',     'MyPTestRec1^.rc_f_',  002, 'r');

    AddWatches(t, 'glob MyTestRec1.MyEmbedClass class const',   'MyTestRec1.MyEmbedClass.cl_c_',  001, 'c', tlClassConst);

    AddWatches(t, 'glob var dyn array of [0]',   'gva', 005, 'K', tlArrayWrap, '[0]' );
    AddWatches(t, 'glob var dyn array of [1]',   'gva', 006, 'L', tlArrayWrap, '[1]');
    AddWatches(t, 'glob var array [0..2] of [0]',   'gv_sa_', 007, 'O', tlArrayWrap, '[0]' );
    AddWatches(t, 'glob var array [0..2] of [1]',   'gv_sa_', 008, 'P', tlArrayWrap, '[1]');
    AddWatches(t, 'glob var array [-1..2] of [-1]',   'gv_nsa_', 009, 'Q', tlArrayWrap, '[-1]' );
    AddWatches(t, 'glob var array [-1..2] of [0]',    'gv_nsa_', 010, 'R', tlArrayWrap, '[0]');
    AddWatches(t, 'glob var array [-1..2] of [1]',    'gv_nsa_', 011, 'S', tlArrayWrap, '[1]');

    AddWatches(t, 'glob var ptr dyn array of [0]',   'gvp_a_', 005, 'K', tlArrayWrap, '^[0]' );
    AddWatches(t, 'glob var ptr dyn array of [1]',   'gvp_a_', 006, 'L', tlArrayWrap, '^[1]');
    AddWatches(t, 'glob var ptr array [0..2] of [0]',   'gvp_sa_', 007, 'O', tlArrayWrap, '^[0]' );
    AddWatches(t, 'glob var ptr array [0..2] of [1]',   'gvp_sa_', 008, 'P', tlArrayWrap, '^[1]');
    AddWatches(t, 'glob var ptr array [-1..2] of [-1]',   'gvp_nsa_', 009, 'Q', tlArrayWrap, '^[-1]' );
    AddWatches(t, 'glob var ptr array [-1..2] of [0]',    'gvp_nsa_', 010, 'R', tlArrayWrap, '^[0]');
    AddWatches(t, 'glob var ptr array [-1..2] of [1]',    'gvp_nsa_', 011, 'S', tlArrayWrap, '^[1]');

    AddWatches(t, 'glob var pointer',            'gvp_', 001, 'B', tlPointer, '^'); // pointer
    AddWatches(t, 'glob var named pointer',      'gvpt_', 001, 'B', tlPointer, '^'); // pointer
    (*
      ptr[0] is tested above: glob var (@)[0]',   '(@gv', 001, 'B', tlAny, ')[0]'
      More pointer ops tested in Expression testcase
      // Using array index [1] or greater will fail some pchar tests, as the become pchar<>string
      // they need .CharFromIndex at least for Dwarf2...
    *)
    //AddWatches(t, 'glob var pointer 2 (@gva[1+0])',  'gvp2_', 006, 'L', tlPointer, '[0]'); // pointer
    //AddWatches(t, 'glob var pointer 2 (@gva[1+2])',  'gvp2_', 009, 'O', tlPointer, '[2]'); // pointer // fails gvp2_Char[2] / gvp2_WideChar[2] and similar => needs to
    AddWatches(t, 'glob var pointer 2 (@gva[1-1])',  'gvp2_', 005, 'K', tlPointer, '[-1]', [tiPointerMath]); // pointer
    AddWatches(t, 'glob var pointer 2 (@gva[1]+2)^','(gvp2_', 009, 'O', tlPointer, '+2)^', [tiPointerMath]); // pointer
    //AddWatches(t, 'glob var pointer 2 (@gva[1]-1)^','(gvp2_', 005, 'K', tlPointer, '-1)^'); // pointer

// type names do not match....
    c := t.Count;
    AddWatches(t, 'glob var TYPED pointer',            'gvptt_', 007, 'N', tlPointerAny, '^'); // pointer
    AddWatches(t, 'glob var TYPED ALIAS ',             'gvtt_', 007, 'N', tlPointerAny, '');
if Compiler.Version < 030300 then
    for i := c to t.Count-1 do
      t.Tests[i].IgnTypeName.AddFlag(ehIgnTypeNameInData);

    t.EvaluateWatches;
    t.CheckResults;


    RunToPause(BrkFooBegin);
    t.Clear;
    AddWatches(t, 'fooBegin local', 'fooloc', 002, 'C');
    AddWatches(t, 'fooBegin args', 'arg', 001, 'B', tlParam);
    t.EvaluateWatches;
    // Do not check values. // Just ensure no crash occurs
    // Registers are wrong in prologue.


    //cl := Debugger.LazDebugger.GetLocation.SrcLine;
    RunToPause(BrkFoo);
    //// below might have been caused by the break on FooVarBegin, if there was no code.
    //if (cl > 1) and (cl = Debugger.LazDebugger.GetLocation.SrcLine) then begin dbg.Run; Debugger.WaitForFinishRun(); end; // TODO: bug, stopping twice the same breakpoint
    t.Clear;
    AddWatches(t, 'foo local', 'fooloc', 002, 'C');
    AddWatches(t, 'foo args', 'arg', 001, 'B', tlParam);
    AddWatches(t, 'foo ArgMyClass1',     'ArgMyClass1.mc',  002, 'C');
    AddWatches(t, 'foo ArgMyBaseClass1', 'ArgMyClass1.mbc', 003, 'D');
    AddWatches(t, 'foo ArgMyClass1',     'TMyClass(ArgMyClass2).mc',  004, 'E');
    AddWatches(t, 'foo ArgMyBaseClass1', 'TMyClass(ArgMyClass2).mbc', 005, 'F');
    AddWatches(t, 'foo ArgMyTestRec1',   'ArgMyTestRec1.rc_f_',  002, 'r');
    t.EvaluateWatches;
    t.CheckResults;


    RunToPause(BrkFooVarBegin);
    t.Clear;
    AddWatches(t, 'foo var args', 'argvar', 001, 'B', tlParam);
    t.EvaluateWatches;
    // Do not check values. // Just ensure no crash occurs
    // Registers are wrong in prologue.


    RunToPause(BrkFooVar);
    t.Clear;
    AddWatches(t, 'foo var args', 'argvar', 001, 'B', tlParam);
    AddWatches(t, 'foo var ArgMyClass1',     'ArgVarMyClass1.mc',  002, 'C');
    AddWatches(t, 'foo var ArgMyBaseClass1', 'ArgVarMyClass1.mbc', 003, 'D');
    AddWatches(t, 'foo var ArgMyClass1',     'TMyClass(ArgVarMyClass2).mc',  004, 'E');
    AddWatches(t, 'foo var ArgMyBaseClass1', 'TMyClass(ArgVarMyClass2).mbc', 005, 'F');
    AddWatches(t, 'foo var ArgMyTestRec1',   'ArgVarMyTestRec1.rc_f_',  002, 'r');
    t.EvaluateWatches;
    t.CheckResults;


    RunToPause(BrkFooConstRef);
    t.Clear;
    AddWatches(t, 'foo const ref args', 'argconstref', 001, 'B', tlParam);
    t.EvaluateWatches;
    t.CheckResults;


  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesFunctions;
var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg: TDBGBreakPoint;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestWatchFunct) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface, skEnumValue];
    t.AddTypeNameAlias('integer', 'integer|longint');


    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);
    t.Clear;

    t.Add('SomeFuncIntRes()',     weInteger(0)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('SomeFuncInt()',     weInteger(0)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('SomeFuncInt()',     weInteger(1)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('SomeFuncInt()',     weInteger(2)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('FuncIntAdd(3,5)',     weInteger(8)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('FuncIntAdd(3,15)',     weInteger(18)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('FuncIntAdd(3,FuncIntAdd(4,5))',     weInteger(12)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('FuncIntAdd(3,4) + FuncIntAdd(4,5)',     weInteger(16)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('FuncTooManyArg(3,4,3,4,3,4,3,4,3,4,3,4)',     weInteger(16)).AddEvalFlag([defAllowFunctionCall])^.AddFlag(ehExpectError);

    t.Add('MyClass1.SomeFuncIntResAdd(3)',     weInteger(80)).AddEvalFlag([defAllowFunctionCall]);
    t.Add('MyClass1.SomeFuncIntRes()',     weInteger(80+999)).AddEvalFlag([defAllowFunctionCall]);

    t.EvaluateWatches;
    t.CheckResults;


  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesAddressOf;

  type
    TTestLoc = (tlAny, tlConst, tlParam, tlArrayWrap, tlPointer);

  procedure AddWatches(t: TWatchExpectationList; AName: String; APrefix: String; ALoc: TTestLoc = tlAny; APostFix: String = '');
  var
    p, e: String;
  begin
    p := APrefix;
    e := APostFix;

    t.AddWithoutExpect(AName, p+'Byte'+e);
    t.AddWithoutExpect(AName, p+'Word'+e);
    t.AddWithoutExpect(AName, p+'Longword'+e);
    t.AddWithoutExpect(AName, p+'QWord'+e);
    t.AddWithoutExpect(AName, p+'Shortint'+e);
    t.AddWithoutExpect(AName, p+'Smallint'+e);
    t.AddWithoutExpect(AName, p+'Longint'+e);
    t.AddWithoutExpect(AName, p+'Int64'+e);
    t.AddWithoutExpect(AName, p+'IntRange'+e);
    t.AddWithoutExpect(AName, p+'CardinalRange'+e);

    t.AddWithoutExpect(AName, p+'Byte_2'+e);
    t.AddWithoutExpect(AName, p+'Word_2'+e);
    t.AddWithoutExpect(AName, p+'Longword_2'+e);
    t.AddWithoutExpect(AName, p+'QWord_2'+e);
    t.AddWithoutExpect(AName, p+'Shortint_2'+e);
    t.AddWithoutExpect(AName, p+'Smallint_2'+e);
    t.AddWithoutExpect(AName, p+'Longint_2'+e);
    t.AddWithoutExpect(AName, p+'Int64_2'+e);

    t.AddWithoutExpect(AName, p+'Shortint_3'+e);
    t.AddWithoutExpect(AName, p+'Smallint_3'+e);
    t.AddWithoutExpect(AName, p+'Longint_3'+e);
    t.AddWithoutExpect(AName, p+'Int64_3'+e);

    t.AddWithoutExpect(AName, p+'Real'+e);
    t.AddWithoutExpect(AName, p+'Single'+e);
    t.AddWithoutExpect(AName, p+'Double'+e);
    t.AddWithoutExpect(AName, p+'Extended'+e);
    //t.AddWithoutExpect(p+'Comp'+e);
    t.AddWithoutExpect(AName, p+'Currency'+e);

    t.AddWithoutExpect(AName, p+'Real_2'+e);
    t.AddWithoutExpect(AName, p+'Single_2'+e);
    t.AddWithoutExpect(AName, p+'Double_2'+e);
    t.AddWithoutExpect(AName, p+'Extended_2'+e); // Double ?
    //t.AddWithoutExpect(p+'Comp_2'+e);
    t.AddWithoutExpect(AName, p+'Currency_2'+e);

    t.AddWithoutExpect(AName, p+'Char'+e);
    t.AddWithoutExpect(AName, p+'Char2'+e);
    t.AddWithoutExpect(AName, p+'Char3'+e);

    t.AddWithoutExpect(AName, p+'String1'+e);
    t.AddWithoutExpect(AName, p+'String1e'+e);
    t.AddWithoutExpect(AName, p+'String10'+e);
    t.AddWithoutExpect(AName, p+'String10e'+e);
    t.AddWithoutExpect(AName, p+'String10x'+e);
    t.AddWithoutExpect(AName, p+'String255'+e);

    t.AddWithoutExpect(AName, p+'Ansi1'+e);
    t.AddWithoutExpect(AName, p+'Ansi2'+e);
    t.AddWithoutExpect(AName, p+'Ansi3'+e);
    t.AddWithoutExpect(AName, p+'Ansi4'+e);
    t.AddWithoutExpect(AName, p+'Ansi5'+e);

//TODO wePchar
    t.AddWithoutExpect(AName, p+'PChar'+e);
    t.AddWithoutExpect(AName, p+'PChar2'+e);

    // char by index
    // TODO: no typename => calculated value ?
////    t.AddWithoutExpect(AName, p+'String10'+e+'[2]').CharFromIndex;
////    t.AddWithoutExpect(AName, p+'Ansi2'+e+'[2]').CharFromIndex;
////    t.AddWithoutExpect(AName, p+'PChar2'+e+'[1]').CharFromIndex;
////    t.AddWithoutExpect(AName, p+'String10'+e+'[1]').CharFromIndex;
////    t.AddWithoutExpect(AName, p+'Ansi2'+e+'[1]').CharFromIndex;
////    t.AddWithoutExpect(AName, p+'PChar2'+e+'[0]').CharFromIndex;


    t.AddWithoutExpect(AName, p+'WideChar'+e); // TODO: widechar
    t.AddWithoutExpect(AName, p+'WideChar2'+e);
    t.AddWithoutExpect(AName, p+'WideChar3'+e);

    t.AddWithoutExpect(AName, p+'WideString1'+e);
    t.AddWithoutExpect(AName, p+'WideString2'+e);
    t.AddWithoutExpect(AName, p+'WideString3'+e);
    t.AddWithoutExpect(AName, p+'WideString4'+e);
    t.AddWithoutExpect(AName, p+'WideString5'+e);

////    t.AddWithoutExpect(AName, p+'WideString2'+e+'[1]')     .CharFromIndex;
////    t.AddWithoutExpect(AName, p+'WideString2'+e+'[2]')     .CharFromIndex;
////    t.AddWithoutExpect(AName, p+'WideString5'+e+'[1]')     .CharFromIndex;
////    t.AddWithoutExpect(AName, p+'WideString5'+e+'[2]')     .CharFromIndex;

//TODO wePWidechar
    t.AddWithoutExpect(AName, p+'PWideChar'+e);
    t.AddWithoutExpect(AName, p+'PWideChar2'+e);

    t.AddWithoutExpect(AName, p+'UnicodeString1'+e);
    t.AddWithoutExpect(AName, p+'UnicodeString2'+e);
    t.AddWithoutExpect(AName, p+'UnicodeString3'+e);
    t.AddWithoutExpect(AName, p+'UnicodeString4'+e);
    t.AddWithoutExpect(AName, p+'UnicodeString5'+e);

//todo dwarf 3
////    t.AddWithoutExpect(AName, p+'UnicodeString2'+e+'[1]')       .CharFromIndex(stDwarf2);
////    t.AddWithoutExpect(AName, p+'UnicodeString2'+e+'[2]')       .CharFromIndex(stDwarf2);
////    t.AddWithoutExpect(AName, p+'UnicodeString5'+e+'[1]')       .CharFromIndex(stDwarf2);
////    t.AddWithoutExpect(AName, p+'UnicodeString5'+e+'[2]')       .CharFromIndex(stDwarf2);


// The below are not real constants => they can have @xxx their address taken.
// Do not add, if expecting ddsError
if not (ALoc = tlConst) then begin
    t.AddWithoutExpect(AName, p+'ShortRec'+e);


    t.AddWithoutExpect(AName, p+'CharDynArray3'+e);
    t.AddWithoutExpect(AName, p+'CharDynArray4'+e);

    t.AddWithoutExpect(AName, p+'WCharDynArray3'+e);
    t.AddWithoutExpect(AName, p+'WCharDynArray4'+e);

    t.AddWithoutExpect(AName, p+'IntDynArray3'+e);
    t.AddWithoutExpect(AName, p+'IntDynArray4'+e);

    t.AddWithoutExpect(AName, p+'AnsiDynArray3'+e);
    t.AddWithoutExpect(AName, p+'AnsiDynArray4'+e);

    t.AddWithoutExpect(AName, p+'ShortStrDynArray3'+e);
    t.AddWithoutExpect(AName, p+'ShortStrDynArray4'+e);


    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e);

////    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e+'[0]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e+'[1]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e+'[2]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e+'[3]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt'+e+'[4]');
////
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt2'+e+'[0]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt2'+e+'[1]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt2'+e+'[2]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt2'+e+'[3]');
////    t.AddWithoutExpect(AName, p+'DynDynArrayInt2'+e+'[4]');


/////    t.AddWithoutExpect(AName, p+'pre__FiveDynArray'+e                  ))
t.AddWithoutExpect(AName, p+'FiveDynArray'+e);
////t.AddWithoutExpect(AName, p+'FiveDynArray'+e+'[0]');
//    t.AddWithoutExpect(AName, p+'FiveDynArray'+e);
//    t.AddWithoutExpect(AName, p+'FiveDynArrayPack'+e);
//    t.AddWithoutExpect(AName, p+'FivePackDynArray'+e);
//    t.AddWithoutExpect(AName, p+'FivePackDynArrayPack'+e);
//    t.AddWithoutExpect(AName, p+'RecFiveDynArray'+e);
//    t.AddWithoutExpect(AName, p+'RecFiveDynPackArray'+e);
//    t.AddWithoutExpect(AName, p+'RecFivePackDynArray'+e);
//    t.AddWithoutExpect(AName, p+'RecFivePackDynPackArray'+e);
//    t.AddWithoutExpect(AName, p+'FiveDynArray2'+e);
//    t.AddWithoutExpect(AName, p+'FiveDynArrayPack2'+e);
//    t.AddWithoutExpect(AName, p+'FivePackDynArray2'+e);
//    t.AddWithoutExpect(AName, p+'FivePackDynArrayPack2'+e);



    t.AddWithoutExpect(AName, p+'CharStatArray2'+e);
    t.AddWithoutExpect(AName, p+'WCharStatArray2'+e);
    t.AddWithoutExpect(AName, p+'IntStatArray2'+e);
    t.AddWithoutExpect(AName, p+'AnsiStatArray2'+e);
    t.AddWithoutExpect(AName, p+'ShortStrStatArray2'+e);
end;


//    t.AddWithoutExpect(AName, p+'FiveStatArray{e}             _O2_ TFiveStatArray            _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_FiveStatArray;
//    t.AddWithoutExpect(AName, p+'FiveStatArrayPack{e}         _O2_ TFiveStatArrayPack        _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_FiveStatArrayPack;
//    t.AddWithoutExpect(AName, p+'FivePackStatArray{e}         _O2_ TFivePackStatArray        _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_FivePackStatArray;
//    t.AddWithoutExpect(AName, p+'FivePackStatArrayPack{e}     _O2_ TFivePackStatArrayPack    _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_FivePackStatArrayPack;
//    t.AddWithoutExpect(AName, p+'RecFiveStatArray{e}          _O2_ TRecFiveStatArray         _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_RecFiveStatArray;
//    t.AddWithoutExpect(AName, p+'RecFiveStatPackArray{e}      _O2_ TRecFiveStatPackArray     _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_RecFiveStatPackArray;
//    t.AddWithoutExpect(AName, p+'RecFivePackStatArray{e}      _O2_ TRecFivePackStatArray     _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_RecFivePackStatArray;
//    t.AddWithoutExpect(AName, p+'RecFivePackStatPackArray{e}  _O2_ TRecFivePackStatPackArray _EQ_ ((a:-9;b:44), (a:-8-AddWithoutExpect;b:33), (a:-7;b:22));          //@@ _pre3_RecFivePackStatPackArray;


//TODO: element by index


  t.AddWithoutExpect(AName, p+'Enum'+e);
  t.AddWithoutExpect(AName, p+'Enum1'+e);
  t.AddWithoutExpect(AName, p+'Enum2'+e);
  t.AddWithoutExpect(AName, p+'Enum3'+e);

  t.AddWithoutExpect(AName, p+'Set'+e).Skip([stDwarf]);

  t.AddWithoutExpect(AName, p+'IntfUnknown'+e);

  end;

  procedure CmpWatches(t1, t2: TWatchExpectationList);
  var
    i, Thread: Integer;
    v1, v2: String;
    p: SizeInt;
  begin
    AssertTrue('Same count', t1.Count = t2.Count);
    t1.EvaluateWatches;
    t2.EvaluateWatches;
    Thread := Debugger.Threads.Threads.CurrentThreadId;
    for i := 0 to t1.Count - 1 do begin
      v1 := t1.Tests[i]^.TstWatch.Values[Thread, 0].Value;
      v2 := t2.Tests[i]^.TstWatch.Values[Thread, 0].Value;

      // check, if v2 has the derefed value at the end
      if (length(v1) < Length(v2)) and (pos(') ', v2) = Length(v1)) then
        v2 := copy(v2, 1, Length(v1));

      // v1 may have a single deref value at the end
      if (length(v1) <> Length(v2)) and (pos('^: ', v1) = pos('^: ', v2)) then begin
        p := pos('^: ', v1);
        v1 := copy(v1, 1, p);
        v2 := copy(v2, 1, p);
      end;

      TestEquals(t1.Tests[i]^.TstTestName + ': ' + t1.Tests[i]^.TstWatch.Expression + ' <> ' + t2.Tests[i]^.TstWatch.Expression,
        v1, v2);
    end;
  end;

  procedure AssertFailedWatches(t1: TWatchExpectationList);
  var
    i, Thread: Integer;
    v1: TWatchValue;
    s: string;
  begin
    t1.EvaluateWatches;
    Thread := Debugger.Threads.Threads.CurrentThreadId;
    for i := 0 to t1.Count - 1 do begin
      v1 := t1.Tests[i]^.TstWatch.Values[Thread, 0];
      WriteStr(s, v1.Validity);

      TestTrue(t1.Tests[i]^.TstTestName + ': ' + t1.Tests[i]^.TstWatch.Expression + ' >> ' + v1.Value + ' / ' + s,
        v1.Validity in [ddsError{, ddsInvalid}]);
    end;
  end;

var
  ExeName: String;
  t, tp: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg, BrkFoo, BrkFooVar, BrkFooConstRef: TDBGBreakPoint;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestWatchAddressOf) then exit;
  t := nil;
  tp := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    tp := TWatchExpectationList.Create(Self);

    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    BrkFoo         := Debugger.SetBreakPoint(Src, 'Foo');
    BrkFooVar      := Debugger.SetBreakPoint(Src, 'FooVar');
    BrkFooConstRef := Debugger.SetBreakPoint(Src, 'FooConstRef');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);

    t.Clear;
    AddWatches(t,  'glob const',         '@gc', tlConst);
    AssertFailedWatches(t);

    t.Clear;
    tp.Clear;
    AddWatches(t,  'glob var',         '@gv');
    AddWatches(tp, 'glob var pointer', 'gvp_'); // pointer
    CmpWatches(t, tp);

// TODO: field / field on nil object


    RunToPause(BrkFoo);
    t.Clear;
    tp.Clear;
    AddWatches(t,  'foo local',         '@fooloc');
    AddWatches(tp, 'foo local pointer', 'fooloc_pl_');
    CmpWatches(t, tp);

    t.Clear;
    tp.Clear;
    AddWatches(t,  'foo local',         '@arg');
    AddWatches(tp, 'foo local pointer', 'fooloc_pa_');
    CmpWatches(t, tp);


    RunToPause(BrkFooVar);
    t.Clear;
    tp.Clear;
    AddWatches(t,  'foo var args',         '@argvar', tlParam);
    AddWatches(tp, 'foo var args pointer', 'fooloc_pv_');
    CmpWatches(t, tp);


    //RunToPause(BrkFooConstRef);
    //t.Clear;
    //AddWatches(t, 'foo const ref args', 'argconstref', tlParam);
    //CmpWatches(t, tp);


  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    tp.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesTypeCast;

  type
    TTestLoc = (tlAny, tlConst, tlParam, tlArrayWrap, tlPointer);
  var
    t2: TWatchExpectationList;

  procedure AddWatchesConv(t: TWatchExpectationList; AName: String; APrefix: String; AOffs: Integer; AChr1: Char;
    ALoc: TTestLoc = tlAny; APostFix: String = '');

    function SignedIntAnd(AVal: Int64; AMask: Qword): Int64;
    begin
      {$PUSH}{$Q-}{$R-}
      Result := AVal and AMask;
      if (Result and (AMask xor (AMask >> 1))) <> 0 then
        Result := Result or (not AMask);
      {$POP}
    end;
  const
    UIntConvert: array[0..3] of record TypeName: String; Mask: qword; end = (
      ( TypeName: 'Byte';     Mask: $FF),
      ( TypeName: 'Word';     Mask: $FFFF),
      ( TypeName: 'LongWord'; Mask: $FFFFFFFF),
      ( TypeName: 'QWord';    Mask: qword($FFFFFFFFFFFFFFFF))
      //( TypeName: 'Pointer';  Mask: ),
    );
    SIntConvert: array[0..3] of record TypeName: String; Mask: QWord; end = (
      ( TypeName: 'ShortInt';  Mask: $FF),
      ( TypeName: 'SmallInt';  Mask: $FFFF),
      ( TypeName: 'LongInt';   Mask: $FFFFFFFF),
      ( TypeName: 'Int64';     Mask: qword($FFFFFFFFFFFFFFFF))
    );

  var
    p, e, tn: String;
    i, n: Integer;
    tm: QWord  ;
  begin
    p := APrefix;
    e := APostFix;
    n := AOffs;

    {$PUSH}{$Q-}{$R-}
    for i := low(UIntConvert) to high(UIntConvert) do begin
      tn := UIntConvert[i].TypeName;
      tm := UIntConvert[i].Mask;
      t.Add(AName+' '+tn, tn+'('+p+'Byte'+e+')',          weCardinal(qword((1+n)                    and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Word'+e+')',          weCardinal(qword((100+n)                  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longword'+e+')',      weCardinal(qword((1000+n)                 and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'QWord'+e+')',         weCardinal(qword((10000+n)                and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint'+e+')',      weCardinal(qword((50+n)                   and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint'+e+')',      weCardinal(qword((500+n)                  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint'+e+')',       weCardinal(qword((5000+n)                 and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64'+e+')',         weCardinal(qword((50000+n)                and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'IntRange'+e+')',      weCardinal(qword((-50+n)                  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'CardinalRange'+e+')', weCardinal(qword((50+n)                   and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Byte_2'+e+')',        weCardinal(qword((240+n)                  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Word_2'+e+')',        weCardinal(qword((65501+n)                and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longword_2'+e+')',    weCardinal(qword((4123456789+n)           and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'QWord_2'+e+')',       weCardinal(qword((15446744073709551610+n) and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint_2'+e+')',    weCardinal(qword((112+n)                  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint_2'+e+')',    weCardinal(qword((32012+n)                and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint_2'+e+')',     weCardinal(qword((20123456+n)             and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64_2'+e+')',       weCardinal(qword((9123372036854775801+n)  and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint_3'+e+')',    weCardinal(qword((-112+n)                 and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint_3'+e+')',    weCardinal(qword((-32012+n)               and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint_3'+e+')',     weCardinal(qword((-20123456+n)            and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64_3'+e+')',       weCardinal(qword((-9123372036854775801+n) and tm), tn, -1));

      // constant
      t.Add(AName+' '+tn, tn+'($77AA55BBDD)',             weCardinal(qword(($77AA55BBDD)            and tm), tn, -1));
      // bit packed
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[0]'+e+')',    weCardinal(qword((2)        and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[1]'+e+')',    weCardinal(qword((-2)       and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[2]'+e+')',    weCardinal(qword((0)        and tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[3]'+e+')',    weCardinal(qword((-1)       and tm), tn, -1));

      t.Add(AName+' '+tn, tn+'('+p+'Char'+e+')',          weCardinal(ord(AChr1), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Char2'+e+')',         weCardinal(ord(#0),    tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Char3'+e+')',         weCardinal(ord(' '),   tn, -1));
    end;
    for i := low(SIntConvert) to high(SIntConvert) do begin
      tn := SIntConvert[i].TypeName;
      tm := SIntConvert[i].Mask;
      t.Add(AName+' '+tn, tn+'('+p+'Byte'+e+')',          weInteger(SignedIntAnd(1+n                   , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Word'+e+')',          weInteger(SignedIntAnd(100+n                 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longword'+e+')',      weInteger(SignedIntAnd(1000+n                , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'QWord'+e+')',         weInteger(SignedIntAnd(10000+n               , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint'+e+')',      weInteger(SignedIntAnd(50+n                  , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint'+e+')',      weInteger(SignedIntAnd(500+n                 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint'+e+')',       weInteger(SignedIntAnd(5000+n                , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64'+e+')',         weInteger(SignedIntAnd(50000+n               , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'IntRange'+e+')',      weInteger(SignedIntAnd(-50+n                 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'CardinalRange'+e+')', weInteger(SignedIntAnd(50+n                  , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Byte_2'+e+')',        weInteger(SignedIntAnd(240+n                 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Word_2'+e+')',        weInteger(SignedIntAnd(65501+n               , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longword_2'+e+')',    weInteger(SignedIntAnd(4123456789+n          , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'QWord_2'+e+')',       weInteger(SignedIntAnd(15446744073709551610+n, tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint_2'+e+')',    weInteger(SignedIntAnd(112+n                 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint_2'+e+')',    weInteger(SignedIntAnd(32012+n               , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint_2'+e+')',     weInteger(SignedIntAnd(20123456+n            , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64_2'+e+')',       weInteger(SignedIntAnd(9123372036854775801+n , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Shortint_3'+e+')',    weInteger(SignedIntAnd(-112+n                , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Smallint_3'+e+')',    weInteger(SignedIntAnd(-32012+n              , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Longint_3'+e+')',     weInteger(SignedIntAnd(-20123456+n           , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Int64_3'+e+')',       weInteger(SignedIntAnd(-9123372036854775801+n, tm), tn, -1));
      // bit packed
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[0]'+e+')',  weInteger(SignedIntAnd(2  , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[1]'+e+')',  weInteger(SignedIntAnd(-2 , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[2]'+e+')',  weInteger(SignedIntAnd(0  , tm), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'BitPackTinyNegArray[3]'+e+')',  weInteger(SignedIntAnd(-1 , tm), tn, -1));

      t.Add(AName+' '+tn, tn+'('+p+'Char'+e+')',          weInteger(ord(AChr1), tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Char2'+e+')',         weInteger(ord(#0),    tn, -1));
      t.Add(AName+' '+tn, tn+'('+p+'Char3'+e+')',         weInteger(ord(' '),   tn, -1));
    end;
    {$POP}

    t.Add(AName+' Char', 'Char('+p+'Byte'+e+')',          weChar(Chr(1+n), 'Char'));

    t.Add(AName+' Char', 'Char('+p+'FiveRec'+e+')',          weMatch('.', skSimple)).ExpectError();

  end;

  procedure AddWatchesCast(t: TWatchExpectationList; AName: String; APrefix: String; AOffs: Integer; AChr1: Char;
    ALoc: TTestLoc = tlAny; APostFix: String = '');
  var
    p, e, val: String;
    Thread, n, StartIdx, i: Integer;
    we: PWatchExpectation;
  begin
    p := APrefix;
    n := AOffs;
    e := APostFix;
    t2.Clear;

      t2.AddWithoutExpect(AName, p+'Instance1_Int'+e);
      t2.AddWithoutExpect(AName, 'PtrUInt(@'+p+'Instance1'+e+')');

      t2.AddWithoutExpect(AName, p+'Ansi5_Int'+e);
      t2.AddWithoutExpect(AName, p+'IntDynArray4_Int'+e);
      t2.AddWithoutExpect(AName, 'PtrUInt(@'+p+'IntDynArray4'+e+')');

      t2.AddWithoutExpect(AName, 'PtrUInt(@'+p+'Word'+e+')');
      t2.AddWithoutExpect(AName, 'PtrUInt(@'+p+'FiveRec'+e+')');

      t2.EvaluateWatches;
      Thread := Debugger.Threads.Threads.CurrentThreadId;

StartIdx := t.Count; // tlConst => Only eval the watch. No tests
      val := t2.Tests[0]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName+' Int', 'PtrUInt('+p+'Instance1'+e+')',   weCardinal(StrToQWordDef(val, qword(-7)), 'PtrUInt', -1));
      t.Add(AName+' TClass1', 'TClass1('+p+'Instance1_Int'+e+')',            weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' TClass1', 'TClass1('+val+')',                            weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' TClass1', 'TClass1(Pointer('+p+'Instance1_Int'+e+'))',   weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' TClass1', 'TClass1(Pointer('+val+'))',                   weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));

      val := t2.Tests[1]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName+' PTxInstance1', 'PTxInstance1(@'+p+'Instance1'+e+')^',           weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' PTxInstance1', 'PTxInstance1('+val+')^',                        weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' PTxInstance1', 'PTxInstance1(Pointer(@'+p+'Instance1'+e+'))^',  weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));
      t.Add(AName+' PTxInstance1', 'PTxInstance1(Pointer('+val+'))^',               weMatch('FAnsi *=[ $0-9A-F()]*\^?:? *'''+AChr1+'T', skClass));


      val := t2.Tests[2]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName+' Ansi', 'PtrUInt('+p+'Ansi5'+e+')',   weCardinal(StrToQWordDef(val, qword(-7)), 'PtrUInt', -1));
      t.Add(AName+' AnsiString', 'AnsiString('+p+'Ansi5_Int'+e+')',
        weAnsiStr(AChr1+'bcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghij')
      ).IgnKindPtr(stDwarf2)    .IgnKind(stDwarf3Up);
      t.Add(AName+' AnsiString', 'AnsiString('+val+')',
        weAnsiStr(AChr1+'bcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghijAbcdefghij')
      ).IgnKindPtr(stDwarf2)    .IgnKind(stDwarf3Up);

      val := t2.Tests[3]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName+' DynArray', 'PtrUInt('+p+'IntDynArray4'+e+')',   weCardinal(StrToQWordDef(val, qword(-7)), 'PtrUInt', -1));
      t.Add(AName, 'TIntDynArray('+p+'IntDynArray4_Int'+e+')',           weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));
      t.Add(AName, 'TIntDynArray('+val+')',                              weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));
      t.Add(AName, 'TIntDynArray(Pointer('+p+'IntDynArray4_Int'+e+'))',  weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));
      t.Add(AName, 'TIntDynArray(Pointer('+val+'))',                     weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));
      t.Add(AName, 'TIntDynArray(PtrUint('+p+'IntDynArray4_Int'+e+'))',  weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));
      t.Add(AName, 'TIntDynArray(PtrUint('+val+'))',                     weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));

      val := t2.Tests[4]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName, 'PTxIntDynArray4(@'+p+'IntDynArray4'+e+')^',           weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));
      t.Add(AName, 'PTxIntDynArray4('+val+')^',                           weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));
      t.Add(AName, 'PTxIntDynArray4(Pointer(@'+p+'IntDynArray4'+e+'))^',  weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));
      t.Add(AName, 'PTxIntDynArray4(Pointer('+val+'))^',                  weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));
      t.Add(AName, 'PTxIntDynArray4(PtrUint(@'+p+'IntDynArray4'+e+'))^',  weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));
      t.Add(AName, 'PTxIntDynArray4(PtrUint('+val+'))^',                  weDynArray(weInteger([12, 30+AOffs, 60]), 'TxIntDynArray4'));

      t.Add(AName, 'TIntDynArray(PxIntDynArray4('+val+')^)',       weDynArray(weInteger([12, 30+AOffs, 60]), 'TIntDynArray'));



      val := t2.Tests[5]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName, 'PTxWord(@'+p+'Word'+e+')^',                weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, 'PTxWord('+val+')^',                        weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, 'PTxWord(Pointer(@'+p+'Word'+e+'))^',       weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, 'PTxWord(Pointer('+val+'))^',               weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, 'PTxWord(PtrUInt(@'+p+'Word'+e+'))^',       weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, 'PTxWord(PtrUInt('+val+'))^',               weCardinal(100+n,         'TxWord',     2));
      if p='gv' then
        t.Add(AName, 'PTxWord(gvp_'+'Word'+e+')^',             weCardinal(100+n,         'TxWord',     2));

      t.Add(AName, 'PTxWord($'+IntToHex(StrToInt64Def(val, 0), 8)+')^',    weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, '^TxWord('+val+')^',                                    weCardinal(100+n,         'TxWord',     2));
      t.Add(AName, '^TxWord($'+IntToHex(StrToInt64Def(val, 0), 8)+')^',    weCardinal(100+n,         'TxWord',     2));


      val := t2.Tests[6]^.TstWatch.Values[Thread, 0].Value;
      t.Add(AName, 'PTxFiveRec(@'+p+'FiveRec'+e+')^',                  weMatch('a *=.*b *= *44',skRecord));
      t.Add(AName, 'PTxFiveRec('+val+')^',                             weMatch('a *=.*b *= *44',skRecord));
      t.Add(AName, 'PTxFiveRec(Pointer(@'+p+'FiveRec'+e+'))^',         weMatch('a *=.*b *= *44',skRecord));
      t.Add(AName, 'PTxFiveRec(Pointer('+val+'))^',                    weMatch('a *=.*b *= *44',skRecord));
      t.Add(AName, 'PTxFiveRec(PtrUInt(@'+p+'FiveRec'+e+'))^',         weMatch('a *=.*b *= *44',skRecord));
      t.Add(AName, 'PTxFiveRec(PtrUInt('+val+'))^',                    weMatch('a *=.*b *= *44',skRecord));
      if p='gv' then
        t.Add(AName, 'PTxFiveRec(gvp_'+'FiveRec'+e+')^',               weMatch('a *=.*b *= *44',skRecord));

for i := StartIdx to t.Count-1 do
  t.Tests[i].SkipIf(ALoc = tlConst);


if p='gv' then begin

      we:= t.Add(AName, '^TRecordClass1(gv_aptr_Class1Rec[0])^.Foo',          weClass([weInteger(22+n).N('FInt'), weAnsiStr(AChr1+'T').N('FAnsi')], 'TClass1') )
        .AddFlag(ehMissingFields);
      we^.EvalCallTestFlags := [defFullTypeInfo];
      we:= t.Add(AName, '^TRecordClass1(gv_aptr_Class1Rec[1])^.Foo',          weClass([weInteger(22+n+2).N('FInt'), weAnsiStr('D'+'T').N('FAnsi')], 'TClass1') )
        .AddFlag(ehMissingFields);
      we^.EvalCallTestFlags := [defFullTypeInfo];




      we:=      t.Add(AName, '^TRecordFive(gv_ptr_FiveRec)^.a',                             weInteger(-22-n));
      we^.EvalCallTestFlags := [defFullTypeInfo];

      t.Add(AName, '^TRecordFive(gv_aptr_FiveRec[0])^.a',                             weInteger(-22-n));
      t.Add(AName, '^TRecordFive(gv_aptr_FiveRec[1])^.a',                             weInteger(-22-(n+2)));

      t.Add(AName, 'PTxFiveRec(gv_aptr_FiveRec[0])^.a',                             weInteger(-22-n));
      t.Add(AName, 'PTxFiveRec(gv_aptr_FiveRec[1])^.a',                             weInteger(-22-(n+2)));

      we:=      t.Add(AName, '^TRecordFive(gv_ptrlist_FiveRec^[0])^.a',                             weInteger(-22-n));
      we^.TstWatch.EvaluateFlags := [defFullTypeInfo];
      we^.EvalCallTestFlags := [defFullTypeInfo];
      we:=      t.Add(AName, '^TRecordFive(gv_ptrlist_FiveRec^[1])^.a',                             weInteger(-22-(n+2)));
      we^.TstWatch.EvaluateFlags := [defFullTypeInfo];
      we^.EvalCallTestFlags := [defFullTypeInfo];

      we:=      t.Add(AName, 'PTxFiveRec(gv_ptrlist_FiveRec^[0])^.a',                             weInteger(-22-n));
      we^.TstWatch.EvaluateFlags := [defFullTypeInfo];
      we^.EvalCallTestFlags := [defFullTypeInfo];
      we:=      t.Add(AName, 'PTxFiveRec(gv_ptrlist_FiveRec^[1])^.a',                             weInteger(-22-(n+2)));
      we^.TstWatch.EvaluateFlags := [defFullTypeInfo];
      we^.EvalCallTestFlags := [defFullTypeInfo];

      t.Add(AName, 'PTxFiveRec('+val+')^.a',                             weInteger(-22-n));
      t.Add(AName, '^TRecordFive('+val+')^.a',                             weInteger(-22-n));
end;


    t.Add(AName+' Cardinal', 'Cardinal('+p+'Rec3S'+e+')',  weMatch('.', skSimple)).ExpectError();
    t.Add(AName+' QWord', 'QWord('+p+'Rec3S'+e+')',        weMatch('.', skSimple)).ExpectError();

    t.Add(AName+' QWord', 'TRecord3QWord('+p+'Rec3S'+e+')',        weMatch('a *=.*18446744073709551594.*b *=.*44.*c *= .', skRecord));

  end;

var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg, BrkFoo, BrkFooVar, BrkFooConstRef: TDBGBreakPoint;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestWatchTypeCast) then exit;
  t := nil;
  t2 := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t2 := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface];
    t.AddTypeNameAlias('integer', 'integer|longint');
    t.AddTypeNameAlias('ShortStr255', 'ShortStr255|ShortString');
    t.AddTypeNameAlias('TEnumSub', 'TEnum|TEnumSub');

    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    BrkFoo         := Debugger.SetBreakPoint(Src, 'Foo');
    BrkFooVar      := Debugger.SetBreakPoint(Src, 'FooVar');
    BrkFooConstRef := Debugger.SetBreakPoint(Src, 'FooConstRef');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);
//t.Clear;
//t.Add('', '^TRecordClass1(gv_aptr_Class1Rec[0])^.Foo',          weClass([weInteger(22+1).N('FInt'), weAnsiStr('T').N('FAnsi')], 'TClass1') ).AddFlag(ehMissingFields)
//^.EvalCallTestFlags := [defFullTypeInfo];
//t.EvaluateWatches;
//t.CheckResults;

    t.Clear;
    t.Add('pbyte(0)', 'pbyte(0)',  wePointerAddr(nil,    'PByte'));
    t.Add('pbyte($0)', 'pbyte($0)',  wePointerAddr(nil,    'PByte'));
    t.Add('^byte(0)', '^byte(0)',  wePointerAddr(nil,    '^Byte'));
    t.Add('^byte($0)', '^byte($0)',  wePointerAddr(nil,    '^Byte'));

    t.Add('^^^char(gvInstance1)^[3][0]',         '^^^char(gvInstance1)^[3][0]',   weChar(#7)); // TCLass1 / len=7
    t.Add('^^^char(gvInstance1)^[3][1]',         '^^^char(gvInstance1)^[3][1]',   weChar('T')); // TCLass1
    t.Add('^^^char(gvInstance1)^[3][2]',         '^^^char(gvInstance1)^[3][2]',   weChar('C'));
    t.Add('^^^char(gvInstance1)^[3][3]',         '^^^char(gvInstance1)^[3][3]',   weChar('l'));
    t.Add('^^^char(gvInstance1)^[3]^',           '^^^char(gvInstance1)^[3]^',    weChar(#7)); // TCLass1 / len=7
    t.Add('(^^^char(gvInstance1)^[3])^',         '(^^^char(gvInstance1)^[3])^',  weChar(#7)); // TCLass1 / len=7
    t.Add('(^^^char(gvInstance1)^[3]+0)^',       '(^^^char(gvInstance1)^[3]+0)^',   weChar(#7)); // TCLass1 / len=7
    t.Add('(^^^char(gvInstance1)^[3]+1)^',       '(^^^char(gvInstance1)^[3]+1)^',   weChar('T')); // TCLass1

    t.Add('((^^^char(gvInstance1)^)+3)^^',       '((^^^char(gvInstance1)^)+3)^^',   weChar(#7));
    t.Add('((^^^char(gvInstance1)^)+3)[0]^',     '((^^^char(gvInstance1)^)+3)[0]^',   weChar(#7));
    t.Add('((^^^char(gvInstance1)^)+3)^[0]',     '((^^^char(gvInstance1)^)+3)^[0]',   weChar(#7));
    t.Add('((^^^char(gvInstance1)^)+3)[0][0]',   '((^^^char(gvInstance1)^)+3)[0][0]',   weChar(#7));
    t.Add('(((^^^char(gvInstance1)^)+3)^+1)^',   '(((^^^char(gvInstance1)^)+3)^+1)^',   weChar('T'));
    t.Add('(((^^^char(gvInstance1)^)+3)[0]+1)^', '(((^^^char(gvInstance1)^)+3)[0]+1)^',   weChar('T'));
    t.Add('((^^^char(gvInstance1)^)+3)^[1]',     '((^^^char(gvInstance1)^)+3)^[1]',   weChar('T'));
    t.Add('((^^^char(gvInstance1)^)+3)[0][1]',   '((^^^char(gvInstance1)^)+3)[0][1]',   weChar('T'));

    AddWatchesConv(t, 'glob const', 'gc', 000, 'A', tlConst);
    AddWatchesConv(t, 'glob var',   'gv', 001, 'B');

    AddWatchesCast(t, 'glob const', 'gc', 000, 'A', tlConst);
    AddWatchesCast(t, 'glob var',   'gv', 001, 'B');
    AddWatchesCast(t, 'glob MyClass1',     'MyClass1.mc',  002, 'C');
    AddWatchesCast(t, 'glob MyBaseClass1', 'MyClass1.mbc', 003, 'D');
    AddWatchesCast(t, 'glob MyClass1',     'TMyClass(MyClass2).mc',  004, 'E');
    AddWatchesCast(t, 'glob MyBaseClass1', 'TMyClass(MyClass2).mbc', 005, 'F');
    AddWatchesCast(t, 'glob var dyn array of [0]',   'gva', 005, 'K', tlArrayWrap, '[0]' );
    AddWatchesCast(t, 'glob var dyn array of [1]',   'gva', 006, 'L', tlArrayWrap, '[1]');
    AddWatchesCast(t, 'glob var pointer',            'gvp_', 001, 'B', tlPointer, '^'); // pointer
    t.EvaluateWatches;
    t.CheckResults;


    RunToPause(BrkFoo);
    t.Clear;
    AddWatchesCast(t, 'foo local', 'fooloc', 002, 'C');
    t.EvaluateWatches;
    t.CheckResults;


    RunToPause(BrkFooVar);
    t.Clear;
    AddWatchesCast(t, 'foo var args', 'argvar', 001, 'B', tlParam);
    AddWatchesCast(t, 'foo var ArgMyBaseClass1', 'TMyClass(ArgVarMyClass2).mbc', 005, 'F');
    t.EvaluateWatches;
    t.CheckResults;

    RunToPause(BrkFooConstRef);
    t.Clear;
    AddWatchesCast(t, 'foo const ref args', 'argconstref', 001, 'B', tlParam);
    t.EvaluateWatches;
    t.CheckResults;


  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    t2.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesExpression;

  type
    TTestLoc = (tlAny, tlConst, tlParam, tlArrayWrap, tlPointer, tlPointerAny);

  procedure AddWatches(t: TWatchExpectationList; AName: String;
    APrefix: String;  AOffs: Integer;  AChr1: Char;  APostFix: String;  ALoc: TTestLoc;
    APrefix2: String; AOffs2: Integer; AChr12: Char; APostFix2: String; ALoc2: TTestLoc
  );
  var
    p, e, p2, e2: String;
    n, i, n2: Integer;
  begin
    p := APrefix;
    e := APostFix;
    n := AOffs;
    p2 := APrefix2;
    e2 := APostFix2;
    n2 := AOffs2;

    t.Add(AName, p+'Byte'+e +'='+ IntToStr(1+n),    weBool(True) );
    t.Add(AName, p+'Byte'+e +'='+ p2+'Byte'+e2,     weBool(n=n2) );
    t.Add(AName, p+'Byte'+e +'='+ p2+'Byte_2'+e2,   weBool(n+1=n2+240) );

    t.Add(AName, p+'Single'+e +'='+ FloatToStr(100.125+n),    weBool(True) );
    t.Add(AName, p+'Double'+e +'='+ FloatToStr(1000.125+n),    weBool(True) );

    t.Add(AName, p+'Single'+e +'='+ p+'Byte'+e,    weBool(False) );
    t.Add(AName, p+'Single'+e +'>'+ p+'Byte'+e,    weBool(True) );
    t.Add(AName, p+'Single'+e +'<'+ p+'Byte'+e,    weBool(False) );
    t.Add(AName, p+'Single'+e+'-99.125' +'='+ p+'Byte'+e,    weBool(True) );

    t.Add(AName, p+'String1e'+e + ' = '''' ',   weBool(True));
    t.Add(AName, p+'String10'+e + ' = '''+AChr1+'bc1'' ',   weBool(True));
    t.Add(AName, p+'String10'+e + '+''a'' = '''+AChr1+'bc1'' ',   weBool(False));
    t.Add(AName, p+'String10'+e + '+''a'' = '''+AChr1+'bc1a'' ',   weBool(True));

    t.Add(AName, p+'Ansi3'+e + ' = '''' ',   weBool(True));
    t.Add(AName, p+'Ansi2'+e + ' = '''+AChr1+'abcd0123'' ',   weBool(True));
    t.Add(AName, p+'Ansi2'+e + ' +''x'' = '''+AChr1+'abcd0123'' ',   weBool(False));
    t.Add(AName, p+'Ansi2'+e + ' +''x'' = '''+AChr1+'abcd0123x'' ',   weBool(True));

    t.Add(AName, p+'WideString3'+e + ' = '''' ',   weBool(True)).SkipIf(ALoc = tlConst);
    t.Add(AName, p+'WideString2'+e + ' = '''+AChr1+'abcX0123'' ',   weBool(True)).SkipIf(ALoc = tlConst);
    t.Add(AName, p+'WideString2'+e + ' +''x'' = '''+AChr1+'abcX0123'' ',   weBool(False)).SkipIf(ALoc = tlConst);
    t.Add(AName, p+'WideString2'+e + ' +''x'' = '''+AChr1+'abcX0123x'' ',   weBool(True)).SkipIf(ALoc = tlConst);

    t.Add(AName, p+'String1e'+e + ' = '+p+'Ansi3'+e,   weBool(True));


    t.Add(AName, p+'IntfUnknown'+e  +'='+ 'nil',              weBool(True) );
    t.Add(AName, p+'IntfUnknown1'+e +'='+ 'nil',              weBool(False) )
      .skipIf((ALoc in [tlConst]));
    t.Add(AName, 'nil' +'='+ p+'IntfUnknown'+e ,              weBool(True) );
    t.Add(AName, 'nil' +'='+ p+'IntfUnknown1'+e,              weBool(False) )
      .skipIf((ALoc in [tlConst]));

    t.Add(AName, p+'IntfUnknown'+e  +'='+ p2+'IntfUnknown'+e2,   weBool(True) );
    t.Add(AName, p+'IntfUnknown1'+e +'='+ p2+'IntfUnknown1'+e2,  weBool(True) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));

    t.Add(AName, p+'IntfUnknown'+e  +'='+ p2+'IntfUnknown2'+e2,   weBool(False) )
      .skipIf((ALoc2 in [tlConst]));
    t.Add(AName, p+'IntfUnknown1'+e +'='+ p2+'IntfUnknown2'+e2,  weBool(False) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));
    t.Add(AName, p+'IntfUnknown2'+e +'='+ p2+'IntfUnknown2b'+e2, weBool(True) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));


    t.Add(AName, p+'Instance0'+e +'='+ 'nil',               weBool(True) );
    t.Add(AName, p+'Instance1'+e +'='+ 'nil',               weBool(False) )
      .skipIf((ALoc in [tlConst]));

    t.Add(AName, p+'Instance0'+e +'='+ p2+'Instance0'+e2,   weBool(True) )
      .skipIf((ALoc2 in [tlConst]));
    t.Add(AName, p+'Instance1'+e +'='+ p2+'Instance1'+e2,   weBool(True) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));

    t.Add(AName, p+'Instance0'+e +'='+ p2+'Instance2'+e2,   weBool(False) )
      .skipIf((ALoc2 in [tlConst]));
    t.Add(AName, p+'Instance1'+e +'='+ p2+'Instance2'+e2,   weBool(False) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));
    t.Add(AName, p+'Instance2'+e +'='+ p2+'Instance2b'+e2,  weBool(True) )
      .skipIf((ALoc in [tlConst]) or (ALoc2 in [tlConst]));


    t.Add(AName, p+'Word'+e +' and '+ p+'LongWord'+e,           weInteger((100+n) and (1000+n)) );
    t.Add(AName, p+'Word'+e +' and Byte('+ p+'Char'+e+')',      weInteger((100+n) and Byte(AChr1)) );
    t.Add(AName, p+'Word'+e +' and '+ IntToStr(1002+n),         weInteger((100+n) and (1002+n)) );
    t.Add(AName, p+'Word'+e +' and ShortInt('+ p+'Char'+e+')',  weInteger((100+n) and Byte(AChr1)) );

    t.Add(AName, p+'ShortInt'+e +' and '+ p+'SmallInt'+e,       weInteger((50+n) and (500+n)) );
    t.Add(AName, p+'ShortInt'+e +' and '+ p+'Word'+e,           weInteger((50+n) and (1000+n)) );
    t.Add(AName, p+'ShortInt'+e +' and '+ IntToStr(1002+n),     weInteger((50+n) and (1002+n)) );

    for i := 0 to t.Count-1 do
      t.Tests[i].IgnTypeName();
  end;

var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg: TDBGBreakPoint;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestExpression) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface];
    t.AddTypeNameAlias('integer', 'integer|longint');
    t.AddTypeNameAlias('ShortStr255', 'ShortStr255|ShortString');
    t.AddTypeNameAlias('TEnumSub', 'TEnum|TEnumSub');

    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    //BrkFoo         := Debugger.SetBreakPoint(Src, 'Foo');
    //BrkFooVar      := Debugger.SetBreakPoint(Src, 'FooVar');
    //BrkFooConstRef := Debugger.SetBreakPoint(Src, 'FooConstRef');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);

    t.Clear;
    // Constant values
    t.Add('Const-Expr: 107', '107',     weInteger(107));
    t.Add('Const-Expr: $10', '$10',     weInteger(16));
    t.Add('Const-Expr: -17', '-17',     weInteger(-17));
    t.Add('Const-Expr: True', 'True',    weBool(True));
    t.Add('Const-Expr: False', 'False',    weBool(False));

    t.Add('Const-EQ: ', 'True and False',     weBool(False));
    t.Add('Const-EQ: ', 'True and True',     weBool(True));
    t.Add('Const-EQ: ', 'False and False',     weBool(False));
    t.Add('Const-EQ: ', 'True or False',     weBool(True));
    t.Add('Const-EQ: ', 'True or True',     weBool(True));
    t.Add('Const-EQ: ', 'False or False',     weBool(False));
    t.Add('Const-EQ: ', 'True xor False',     weBool(True));
    t.Add('Const-EQ: ', 'True xor True',     weBool(False));
    t.Add('Const-EQ: ', 'False xor False',     weBool(False));

    t.Add('Const-EQ: ', '(1=7) and (3=3)',     weBool(False));
    t.Add('Const-EQ: ', '(1<7) and (3>1)',     weBool(True));

    t.Add('Const-Expr: ansistring ', '''abc''',    weAnsiStr('abc')).IgnKind;
    t.Add('Const-Expr: ansistring ', '''''',    weAnsiStr('')).IgnKind;
    t.Add('Const-Expr: ansistring ', '''abc''''DE''',    weAnsiStr('abcDE')).IgnKind;
    t.Add('Const-Expr: ansistring ', '''abc''#32''DE''',    weAnsiStr('abc DE')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#32''abc''',    weAnsiStr(' abc')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#49',    weAnsiStr('1')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#49#50',    weAnsiStr('12')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#$30#$31',    weAnsiStr('01')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#&61#&62',    weAnsiStr('12')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#%110001',    weAnsiStr('1')).IgnKind;
    t.Add('Const-Expr: ansistring ', '#%00110001',    weAnsiStr('1')).IgnKind;

    t.Add('Const-Expr: ansistring ', '''a',    weAnsiStr('1')).IgnKind^.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '''',    weAnsiStr('1')).IgnKind^.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#$',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#''',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#$''',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#A',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);
    t.Add('Const-Expr: ansistring ', '#$X',    weAnsiStr('abc')).IgnKind.AddFlag(ehExpectError);

    t.Add('Const-Op: ', '10',     weInteger(10));
    t.Add('Const-Op: ', '-10',     weInteger(-10));
    t.Add('Const-Op: ', '- -10',     weInteger(10)); // 2 unary
    t.Add('Const-Op: ', '+10',     weInteger(10));

    t.Add('Const-Op: ', '107 + 1',     weInteger(108));
    t.Add('Const-Op: ', '107 - 1',     weInteger(106));
    t.Add('Const-Op: ', '107 + -1',    weInteger(106));
    t.Add('Const-Op: ', '107 + +1',    weInteger(108));
    t.Add('Const-Op: ', '107 - -1',    weInteger(108));
    t.Add('Const-Op: ', '11 * 3',      weInteger(33));
    t.Add('Const-Op: ', '11 * -3',     weInteger(-33));
    t.Add('Const-Op: ', '-11 * 3',     weInteger(-33));
    t.Add('Const-Op: ', '-11 * -3',    weInteger(33));
    t.Add('Const-Op: ', '11 / 3',      weMatch('3\.666', skFloat));
    t.Add('Const-Op: ', '11 div 3',    weInteger(3));
    t.Add('Const-Op: ', '11 mod 3',    weInteger(2));
    t.Add('Const-precedence: ', '1 + 11 * 3',      weInteger(34));
    t.Add('Const-precedence: ', '11 * 3 + 1',      weInteger(34));
    t.Add('Const-bracket: ', '(1 + 11) * 3',      weInteger(36));
    t.Add('Const-bracket: ', '11 * (3 + 1)',      weInteger(44));

    t.Add('Const-Op: ', '1.5',      weFloat(1.5));
    t.Add('Const-Op: ', '-1.5',     weFloat(-1.5));
    t.Add('Const-Op: ', '- -1.5',     weFloat(1.5));
    t.Add('Const-Op: ', '+1.5',     weFloat(1.5));

    t.Add('Const-Op: ', ' 10.5 + 1',      weFloat(11.5));
    t.Add('Const-Op: ', ' 10.0 + 1',      weFloat(11));
    t.Add('Const-Op: ', ' 10   + 1.5',    weFloat(11.5));
    t.Add('Const-Op: ', '-10   + 1.5',    weFloat(-8.5));
    t.Add('Const-Op: ', '-10   + -1.5',   weFloat(-11.5));

    t.Add('Const-Op: ', ' 10.5 - 1',      weFloat(9.5));
    t.Add('Const-Op: ', ' 10.0 - 1',      weFloat(9));
    t.Add('Const-Op: ', ' 10   - 1.5',    weFloat(8.5));
    t.Add('Const-Op: ', '-10   - 1.5',    weFloat(-11.5));
    t.Add('Const-Op: ', '-10   - -1.5',   weFloat(-8.5));

    t.Add('Const-Op: ', '10.5 * 3',      weFloat(31.5));
    t.Add('Const-Op: ', '10.0 * 3',      weFloat(30));
    t.Add('Const-Op: ', ' 9   * 1.5',    weFloat(13.5));
    t.Add('Const-Op: ', '-9   * 1.5',    weFloat(-13.5));
    t.Add('Const-Op: ', '-9   * -1.5',   weFloat(13.5));

    t.Add('Const-Op: ', ' 31.5 / 3',      weFloat(10.5));
    t.Add('Const-Op: ', ' 30.0 / 3',      weFloat(10));
    t.Add('Const-Op: ', ' 13.5 / 1.5',    weFloat(9));
    t.Add('Const-Op: ', '-13.5 / 1.5',    weFloat(-9));
    t.Add('Const-Op: ', '-13.5 / -1.5',   weFloat(9));

    t.Add('Const-Op: ', '35 And 17',     weInteger(1));
    t.Add('Const-Op: ', '35 And 7',     weInteger(3));
    t.Add('Const-Op: ', '35 or 7',     weInteger(39));
    t.Add('Const-Op: ', '35 Xor 7',     weInteger(36));

    t.Add('Const-EQ: ', '17 = $11',     weBool(True));
    t.Add('Const-EQ: ', '18 = $11',     weBool(False));
    t.Add('Const-EQ: ', '17 <> 17',     weBool(False));
    t.Add('Const-EQ: ', '18 <> 17',     weBool(True));
    t.Add('Const-EQ: ', '17 > 18',     weBool(False));
    t.Add('Const-EQ: ', '17 > 17',     weBool(False));
    t.Add('Const-EQ: ', '17 > 16',     weBool(True));
    t.Add('Const-EQ: ', '17 >= 18',     weBool(False));
    t.Add('Const-EQ: ', '17 >= 17',     weBool(True));
    t.Add('Const-EQ: ', '17 >= 16',     weBool(True));
    t.Add('Const-EQ: ', '17 < 18',     weBool(True));
    t.Add('Const-EQ: ', '17 < 17',     weBool(False));
    t.Add('Const-EQ: ', '17 < 16',     weBool(False));
    t.Add('Const-EQ: ', '17 <= 18',     weBool(True));
    t.Add('Const-EQ: ', '17 <= 17',     weBool(True));
    t.Add('Const-EQ: ', '17 <= 16',     weBool(False));

    t.Add('Const-EQ: ', '''A'' = #65',     weBool(True));
    t.Add('Const-EQ: ', '''A'' = #65#65',  weBool(False));
    t.Add('Const-EQ: ', '''A'' = ''B''',   weBool(False));
    t.Add('Const-EQ: ', '''A'' <> #65',     weBool(False));
    t.Add('Const-EQ: ', '''A'' <> #65#65',  weBool(True));
    t.Add('Const-EQ: ', '''A'' <> ''B''',   weBool(True));

    t.Add('Const-EQ: ', '17.0 = $11',     weBool(True));
    t.Add('Const-EQ: ', '18.0 = $11',     weBool(False));
    t.Add('Const-EQ: ', '17.0 <> 17',     weBool(False));
    t.Add('Const-EQ: ', '18.0 <> 17',     weBool(True));
    t.Add('Const-EQ: ', '17.0 > 18',     weBool(False));
    t.Add('Const-EQ: ', '17.0 > 17',     weBool(False));
    t.Add('Const-EQ: ', '17.0 > 16',     weBool(True));
    t.Add('Const-EQ: ', '17.0 >= 18',     weBool(False));
    t.Add('Const-EQ: ', '17.0 >= 17',     weBool(True));
    t.Add('Const-EQ: ', '17.0 >= 16',     weBool(True));
    t.Add('Const-EQ: ', '17.0 < 18',     weBool(True));
    t.Add('Const-EQ: ', '17.0 < 17',     weBool(False));
    t.Add('Const-EQ: ', '17.0 < 16',     weBool(False));
    t.Add('Const-EQ: ', '17.0 <= 18',     weBool(True));
    t.Add('Const-EQ: ', '17.0 <= 17',     weBool(True));
    t.Add('Const-EQ: ', '17.0 <= 16',     weBool(False));

    t.Add('Const-EQ: ', '17.5 = 17.5',     weBool(True));
    t.Add('Const-EQ: ', '17.1 <> 17.5',    weBool(True));
    t.Add('Const-EQ: ', '17.1 < 17.5',     weBool(True));
    t.Add('Const-EQ: ', '17.8 > 17.5',     weBool(True));
    t.Add('Const-EQ: ', '17.5 = 17.1',     weBool(False));
    t.Add('Const-EQ: ', '17.5 <> 17.5',    weBool(False));
    t.Add('Const-EQ: ', '17.8 < 17.5',     weBool(False));
    t.Add('Const-EQ: ', '17.1 > 17.5',     weBool(False));

    t.Add('Const-EQ: ', '12 = ''abc''',     weBool(False)).ExpectError();

    t.Add('Pointer-Op: ', 'LongInt(Pointer(10)+4)',     weInteger(14));

    t.Add('Pointer-Op: ', 'Pointer(10)-Pointer(4)',     weInteger(6));
    t.Add('Pointer-Op: ', 'PWord(10)-PWord(4)',     weInteger(3));
    t.Add('Pointer-Op: ', '^Word(10)-^Word(4)',     weInteger(3));
    t.Add('Pointer-Op: ', '^Word(10)-Pointer(4)',     weInteger(3)).ExpectError();

    t.Add('Pointer-Op: ', 'gcPtr2 - gcPtr1',     weInteger(1000));
    t.Add('Pointer-Op: ', 'gcPtr2 - gvPtr1',     weInteger(1000));
    t.Add('Pointer-Op: ', 'gvPtr2 - gcPtr2',     weInteger(1));
    t.Add('Pointer-Op: ', 'gvPtr2 - gvPtr1',     weInteger(1001));
    t.Add('Pointer-Op: ', '@gv_sa_Word[2] - @gv_sa_Word[1]',     weInteger(1));
    t.Add('Pointer-Op: ', 'pointer(@gv_sa_Word[2]) - pointer(@gv_sa_Word[1])',     weInteger(2));

    AddWatches(t, 'glob',   'gv', 001, 'B', '', tlAny,     'gv', 001, 'B', '', tlAny);
    AddWatches(t, 'glob',   'gc', 000, 'A', '', tlConst,   'gv', 001, 'B', '', tlAny);
    AddWatches(t, 'glob',   'gv', 001, 'B', '', tlAny,     'gc', 000, 'A', '', tlConst);
    t.EvaluateWatches;
    t.CheckResults;




  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesModify;
  procedure WaitForModify;
  var
    i: Integer;
  begin
    // Modify does not have a callback (yet). So wait for an eval
    FEvalDone := False;
    Debugger.LazDebugger.Evaluate('p', @DoEvalDone);
    i := 0;
    while (not FEvalDone) and (i < 5*400) do begin // timeout after 5 sec
      Application.Idle(False);
      Debugger.WaitForFinishRun(25);
      inc(i);
    end;
  end;
var
  ExeName, ExpName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg: TDBGBreakPoint;
  ExpPre: TWatchExpectationResult;
  testidx: Integer;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestModify) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface];
    t.AddTypeNameAlias('integer', 'integer|longint');
    t.AddTypeNameAlias('cardinal', 'cardinal|longword');
    t.AddTypeNameAlias('BYTEBOOL', 'boolean|BYTEBOOL');
    t.AddTypeNameAlias('TEnumSub', 'TEnum|TEnumSub');

    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);

    for testidx := 0 to 1 do begin
      ExpPre := weCardinal(qword($9696969696969696),    'QWord', 8);
      ExpName := 'ModifyTest';
      if testidx = 1 then begin
        ExpPre := weCardinal(byte($96),    'Byte', 1);
        ExpName := 'ModifyPackTest';
      end;

      t.Clear;

      //t.Add(AName, p+'QWord'+e,      weCardinal(10000+n,                'QWord',    8));
      //t.Add(AName, p+'Shortint'+e,   weInteger (50+n,                   'Shortint', 1));

      t.Add('(before)', ExpName + 'Byte.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Byte.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Byte.val',    weCardinal($01,    'Byte', 1));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Byte.val', '131');
      WaitForModify;
      t.Add('(after)', ExpName + 'Byte.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Byte.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Byte.val',    weCardinal(131,    'Byte', 1));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Word.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Word.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Word.val',    weCardinal($0101,    'Word', 2));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Word.val', '35131');
      WaitForModify;
      t.Add('(after)', ExpName + 'Word.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Word.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Word.val',    weCardinal(35131,    'Word', 2));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Cardinal.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Cardinal.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Cardinal.val',    weCardinal($81020102,    'Cardinal', 4));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Cardinal.val', '$9AA93333');
      WaitForModify;
      t.Add('(after)', ExpName + 'Cardinal.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Cardinal.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Cardinal.val',    weCardinal($9AA93333,    'Cardinal', 4));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'QWord.pre',    ExpPre);
      t.Add('(before)', ExpName + 'QWord.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'QWord.val',    weCardinal(qword($8102010201020102),    'QWord', 8));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'QWord.val', '$9AA9333344224422');
      WaitForModify;
      t.Add('(after)', ExpName + 'QWord.pre',    ExpPre);
      t.Add('(after)', ExpName + 'QWord.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'QWord.val',    weCardinal(qword($9AA9333344224422),    'QWord', 8));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Int.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Int.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Int.val',    weInteger(-$01030103,    'Integer', 4));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Int.val', '$44225522');
      WaitForModify;
      t.Add('(after)', ExpName + 'Int.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Int.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Int.val',    weInteger($44225522,    'Integer', 4));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Int64.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Int64.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Int64.val',    weInteger(-$0103010301030103,    'Int64', 8));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Int64.val', '$4422552201020102');
      WaitForModify;
      t.Add('(after)', ExpName + 'Int64.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Int64.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Int64.val',    weInteger($4422552201020102,    'Int64', 8));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Pointer.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Pointer.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Pointer.val',    wePointerAddr(Pointer(30), 'Pointer'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Pointer.val', '50');
      WaitForModify;
      t.Add('(after)', ExpName + 'Pointer.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Pointer.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Pointer.val',    wePointerAddr(Pointer(50), 'Pointer'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'PWord.pre',    ExpPre);
      t.Add('(before)', ExpName + 'PWord.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'PWord.val',    wePointerAddr(Pointer(40), 'PWord'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'PWord.val', '70');
      WaitForModify;
      t.Add('(after)', ExpName + 'PWord.pre',    ExpPre);
      t.Add('(after)', ExpName + 'PWord.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'PWord.val',    wePointerAddr(Pointer(70), 'PWord'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Bool.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Bool.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Bool.val',    weBool(True));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Bool.val', 'False');
      WaitForModify;
      t.Add('(after)', ExpName + 'Bool.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Bool.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Bool.val',    weBool(False));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'ByteBool.pre',    ExpPre);
      t.Add('(before)', ExpName + 'ByteBool.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'ByteBool.val',    weSizedBool(False, 'BYTEBOOL'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'ByteBool.val', 'True');
      WaitForModify;
      t.Add('(after)', ExpName + 'ByteBool.pre',    ExpPre);
      t.Add('(after)', ExpName + 'ByteBool.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'ByteBool.val',    weSizedBool(True, 'BYTEBOOL'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Char.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Char.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Char.val',    weChar('B'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Char.val', 'X');
      WaitForModify;
      t.Add('(after)', ExpName + 'Char.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Char.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Char.val',    weChar('X'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'WideChar.pre',    ExpPre);
      t.Add('(before)', ExpName + 'WideChar.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'WideChar.val',    weWideChar('B'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'WideChar.val', 'Y');
      WaitForModify;
      t.Add('(after)', ExpName + 'WideChar.pre',    ExpPre);
      t.Add('(after)', ExpName + 'WideChar.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'WideChar.val',    weWideChar('Y'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Enum.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Enum.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Enum.val',    weEnum('EnVal2'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Enum.val', 'EnVal4');
      WaitForModify;
      t.Add('(after)', ExpName + 'Enum.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Enum.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Enum.val',    weEnum('EnVal4'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;


      t.Add('(before)', ExpName + 'Enum16.pre',    ExpPre);
      t.Add('(before)', ExpName + 'Enum16.post',   weCardinal($69,    'Byte', 1));
      t.Add('(before)', ExpName + 'Enum16.val',    weEnum('ExValX2'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;
      Debugger.LazDebugger.Modify(ExpName + 'Enum16.val', 'ExValX7');
      WaitForModify;
      t.Add('(after)', ExpName + 'Enum16.pre',    ExpPre);
      t.Add('(after)', ExpName + 'Enum16.post',   weCardinal($69,    'Byte', 1));
      t.Add('(after)', ExpName + 'Enum16.val',    weEnum('ExValX7'));
      t.EvaluateWatches;
      t.CheckResults;
      t.Clear;

      if Compiler.SymbolType <> stDwarf then begin

        t.Add('(before)', ExpName + 'Set.pre',    ExpPre);
        t.Add('(before)', ExpName + 'Set.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'Set.val',    weSet(['EnVal2', 'EnVal4']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set.val', ' [ EnVal1, EnVal3] ');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set.val',    weSet(['EnVal1', 'EnVal3']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set.val', ' [ EnVal1] ');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set.val',    weSet(['EnVal1']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set.val', ' [ EnVal4] ');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set.val',    weSet(['EnVal4']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;


        t.Add('(before)', ExpName + 'Set4.pre',    ExpPre);
        t.Add('(before)', ExpName + 'Set4.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'Set4.val',    weSet(['E4Val02', 'E4Val09']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set4.val', '[E4Val03,E4Val0A ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set4.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set4.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set4.val',    weSet(['E4Val03', 'E4Val0A']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set4.val', ' [E4Val0B ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set4.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set4.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set4.val',    weSet(['E4Val0B']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;


        t.Add('(before)', ExpName + 'Set6.pre',    ExpPre);
        t.Add('(before)', ExpName + 'Set6.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'Set6.val',    weSet(['E6Val02', 'E6Val1A']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set6.val', '[E6Val03,E6Val1B ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set6.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set6.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set6.val',    weSet(['E6Val03', 'E6Val1B']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;


        t.Add('(before)', ExpName + 'Set7.pre',    ExpPre);
        t.Add('(before)', ExpName + 'Set7.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'Set7.val',    weSet(['E7Val02', 'E7Val3A']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set7.val', '[E7Val03,E7Val12,E7Val3B ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set7.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set7.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set7.val',    weSet(['E7Val03', 'E7Val12', 'E7Val3B']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;


        t.Add('(before)', ExpName + 'Set8.pre',    ExpPre);
        t.Add('(before)', ExpName + 'Set8.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'Set8.val',    weSet(['E8Val02', 'E8Val59']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'Set8.val', '[E8Val03,E8Val12,E8Val58 ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'Set8.pre',    ExpPre);
        t.Add('(after)', ExpName + 'Set8.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'Set8.val',    weSet(['E8Val03', 'E8Val12', 'E8Val58']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;


        t.Add('(before)', ExpName + 'SRangeSet.pre',    ExpPre);
        t.Add('(before)', ExpName + 'SRangeSet.post',   weCardinal($69,    'Byte', 1));
        t.Add('(before)', ExpName + 'SRangeSet.val',    weSet(['20','23','28']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'SRangeSet.val', '[21,$18,27 ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'SRangeSet.pre',    ExpPre);
        t.Add('(after)', ExpName + 'SRangeSet.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'SRangeSet.val',    weSet(['21', '24', '27']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;
        Debugger.LazDebugger.Modify(ExpName + 'SRangeSet.val', '[30 ]');
        WaitForModify;
        t.Add('(after)', ExpName + 'SRangeSet.pre',    ExpPre);
        t.Add('(after)', ExpName + 'SRangeSet.post',   weCardinal($69,    'Byte', 1));
        t.Add('(after)', ExpName + 'SRangeSet.val',    weSet(['30']));
        t.EvaluateWatches;
        t.CheckResults;
        t.Clear;

      end;

    end;
  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;

procedure TTestWatches.TestWatchesErrors;
var
  ExeName: String;
  t: TWatchExpectationList;
  Src: TCommonSource;
  BrkPrg: TDBGBreakPoint;
begin
  if SkipTest then exit;
  if not TestControlCanTest(ControlTestErrors) then exit;
  t := nil;

  Src := GetCommonSourceFor('WatchesValuePrg.pas');
  TestCompile(Src, ExeName);

  AssertTrue('Start debugger', Debugger.StartDebugger(AppDir, ExeName));

  try
    t := TWatchExpectationList.Create(Self);
    t.AcceptSkSimple := [skInteger, skCardinal, skBoolean, skChar, skFloat,
      skString, skAnsiString, skCurrency, skVariant, skWideString,
      skInterface];
    t.AddTypeNameAlias('integer', 'integer|longint');
    t.AddTypeNameAlias('ShortStr255', 'ShortStr255|ShortString');
    t.AddTypeNameAlias('TEnumSub', 'TEnum|TEnumSub');

    BrkPrg         := Debugger.SetBreakPoint(Src, 'Prg');
    //BrkFoo         := Debugger.SetBreakPoint(Src, 'Foo');
    //BrkFooVar      := Debugger.SetBreakPoint(Src, 'FooVar');
    //BrkFooConstRef := Debugger.SetBreakPoint(Src, 'FooConstRef');
    AssertDebuggerNotInErrorState;

    (* ************ Nested Functions ************* *)

    RunToPause(BrkPrg);

    t.Clear;
    // Constant values
    //t.Add('', '^char(1)^+[1]',   weMatchErr('Can not evaluate: "\[1\]"'));
    t.Add('', '^char(1)^+[1]',   weMatchErr('Can not evaluate: "\['));


    t.EvaluateWatches;
    t.CheckResults;




  finally
    Debugger.RunToNextPause(dcStop);
    t.Free;
    Debugger.ClearDebuggerMonitors;
    Debugger.FreeDebugger;

    AssertTestErrors;
  end;
end;


initialization
  RegisterDbgTest(TTestWatches);
  ControlTestWatch          := TestControlRegisterTest('TTestWatch');
  ControlTestWatchScope     := TestControlRegisterTest('Scope', ControlTestWatch);
  ControlTestWatchValue     := TestControlRegisterTest('Value', ControlTestWatch);
  ControlTestWatchFunct     := TestControlRegisterTest('Function', ControlTestWatch);
  ControlTestWatchAddressOf := TestControlRegisterTest('AddressOf', ControlTestWatch);
  ControlTestWatchTypeCast  := TestControlRegisterTest('TypeCast', ControlTestWatch);
  ControlTestModify         := TestControlRegisterTest('Modify', ControlTestWatch);
  ControlTestExpression     := TestControlRegisterTest('Expression', ControlTestWatch);
  ControlTestErrors         := TestControlRegisterTest('Errors', ControlTestWatch);

end.



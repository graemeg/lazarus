// TEST_USES=WatchesValuePrgIdent.inc

(*
  - Declare variables of every type available, including nested types, named/unnamed, ...
  - Declare in different locations: const, var, param, var param, field, ...

  Test that the debugger can read any type of value at any location
*)
program WatchesValuePrg;
{$mode objfpc}
{$LONGSTRINGS ON}
{$modeswitch advancedrecords}
{$hints off}
{$notes off}
{$warnings off}

uses sysutils, Classes;

function SomeFunc1(SomeValue, Foo: Integer; Bar: Word; X: Byte): Boolean;
begin result := SomeValue = 0; end;
procedure SomeProc1();
begin SomeFunc1(2,2,2,2); end;

var ValSomeFuncInt: integer;
function SomeFuncInt(): Integer;
begin
  result := ValSomeFuncInt;
  inc(ValSomeFuncInt);
end;
function SomeFuncIntRes(): Integer;
begin
  result := ValSomeFuncInt;
  ValSomeFuncInt := 0;
end;
function FuncIntAdd(a, b: Integer): Integer;
begin
  result := a+b;
end;
function FuncTooManyArg(a, b, c, d, e, f, g, h, i, j, k, l: Integer): Integer; // not enough registers to call in watch eval
begin result := 123; end;

const
  MaxListSize = high(longword) div 16;

type
{$ifdef CPU64}
  PtrUInt = type QWord;
{$endif CPU64}

{$ifdef CPU32}
  PtrUInt = type DWord;
{$endif CPU32}

  PPointerList = ^TPointerList;
  TPointerList = array[0..MaxListSize - 1] of Pointer;

  TMyStringItem = record
    FString: string;
    FObject: TObject;
  end;
  TMyStringItemListShort = array[0..10] of TMyStringItem;
  TMyStringItemList = array[0..MaxListSize - 1] of TMyStringItem;
  PMyStringItemList = ^TMyStringItemList;
  TMyStringList = class
  private
    FList: PMyStringItemList;
  end;


var
  BreakDummy: PtrUInt;
  PByteDummy: PByte;
  p: Pointer;
  pw: PWord; // ensure we have the type
  InterfacedObject, InterfacedObject2: TInterfacedObject;

type
  TClass1 = class;

  TIntRange = -300..300;
  TSmallRange = 20..30;
  TTinyRange = 0..3;
  TTinyNegRange = -2..3;
  TCardinalRange = 1..300;

  ShortStr1 = String[1];
  ShortStr10 = String[10];
  ShortStr255 = String[255];

  TStrA = AnsiString;
  TStrTA = type AnsiString;
  TPChr = ^Char;

  TWStrA = WideString;
  TWStrTA = type WideString;
  TPWChr = ^WideChar;

  TUStrA = UnicodeString;
  TUStrTA = type UnicodeString;
  //TPUChr = ^UnicodeChar;

  TShortRec = record // looks like shortstring
    length: byte;
    st: array [1..5] of char;
  end;

  TCharStatArray     = array [1..5] of char;
  TWCharStatArray    = array [1..5] of char;
  TIntStatArray      = array [1..5] of Integer;
  TAnsiStatArray     = array [1..5] of AnsiString;
  TShortStrStatArray = array [1..5] of ShortStr10;

  TCharDynArray      = array of char;
  TWCharDynArray     = array of widechar;
  TIntDynArray       = array of Integer;
  TAnsiDynArray      = array of AnsiString;
  TShortStrDynArray  = array of ShortStr10;

  TDynDynArrayInt    = array of array of integer;

  TRecordFive     =        record a:longint; b: byte end;
  TRecordFivePack = packed record a:longint; b: byte end;

  TRecord3Int64     =        record a,b,c: Int64; end;
  TRecord3QWord     =        record a,b,c: QWord; end;
  //PRecord3Int64     = ^TRecord3Int64;

  TObject3Int64     =        object a,b,c: Int64; end;
  TObject3Int64Ex   =        object(TObject3Int64) d: QWord; end;
  //PObject3Int64     = ^TObject3Int64;
  //PObject3Int64Ex   = ^TObject3Int64Ex;

  TObjectCreate3Int64     =        object a,b,c: Int64; public constructor Create; destructor Destroy; procedure Foo; virtual; end;
  TObjectCreate3Int64Ex   =        object(TObjectCreate3Int64) d: QWord; end;
  //PObjectCreate3Int64     = ^TObjectCreate3Int64;
  //PObjectCreate3Int64Ex   = ^TObjectCreate3Int64Ex;

  //PIUnknown = ^IUnknown;

  TFiveDynArray            =        array of          record a:longint; b: byte end;
  TFiveDynArrayPack        = packed array of          record a:longint; b: byte end;
  TFivePackDynArray        =        array of   packed record a:longint; b: byte end;
  TFivePackDynArrayPack    = packed array of   packed record a:longint; b: byte end;
  TRecFiveDynArray         =        array of   TRecordFive;
  TRecFiveDynPackArray     = packed array of   TRecordFive;
  TRecFivePackDynArray     =        array of   TRecordFivePack;
  TRecFivePackDynPackArray = packed array of   TRecordFivePack;

  TFiveStatArray            =        array [2..4] of          record a:longint; b: byte end;
  TFiveStatArrayPack        = packed array [2..4] of          record a:longint; b: byte end;
  TFivePackStatArray        =        array [2..4] of   packed record a:longint; b: byte end;
  TFivePackStatArrayPack    = packed array [2..4] of   packed record a:longint; b: byte end;
  TRecFiveStatArray         =        array [2..4] of   TRecordFive;
  TRecFiveStatPackArray     = packed array [2..4] of   TRecordFive;
  TRecFivePackStatArray     =        array [2..4] of   TRecordFivePack;
  TRecFivePackStatPackArray = packed array [2..4] of   TRecordFivePack;

  TRecordClass1     =        record Foo: TClass1; end;

  PClass1 = ^TClass1;
  TClass1a = class;
  TClass1 = class
  public
    FInt: integer;
    FDynInt: TIntDynArray;
    FAnsi: AnsiString;
    FThis: TClass1;
    FThat: TClass1a;
    FMe: PClass1;
  end;
  TClass1a = class(TClass1)
    FThisA: TClass1;
    FMeA: PClass1;
  end;


  TEnum  = (EnVal1, EnVal2, EnVal3, EnVal4);
  TEnumSub =  EnVal1..EnVal2;
  TEnum2 = (EnVal21= 3, EnVal22=4, EnVal23=7, EnVal24=10, EnVal25=30);
  TEnum3  = (EnVal31, EnVal32);
  TSet   = set of TEnum;
  TSet3  = set of TEnum3;
  TSmallRangeSet = set of TSmallRange;

  TArrayEnum = array [TEnum] of word;
  TArrayEnumSub = array [TEnumSub] of word;
  TArrayEnumElem = array [EnVal1..EnVal4] of word;
  TArrayEnumSubElem = array [EnVal1..EnVal2] of word;

  TBitPackBoolArray     = bitpacked array [0..3] of Boolean;
  TBitPackTinyArray     = bitpacked array [0..3] of TTinyRange;
  TBitPackTinyNegArray  = bitpacked array [0..3] of TTinyNegRange;
  TBitPackEnumArray     = bitpacked array [0..3] of TEnum;
  TBitPackEnum3Array    = bitpacked array [0..3] of TEnum3;
  TBitPackSetArray      = bitpacked array [0..3] of TSet;
  TBitPackSet3Array     = bitpacked array [0..3] of TSet3;

  TBitPackBoolArray2     = bitpacked array [0..1, 0..2] of Boolean;
  TBitPackTinyArray2     = bitpacked array [0..1, 0..2] of TTinyRange;
  TBitPackTinyNegArray2  = bitpacked array [0..1, 0..2] of TTinyNegRange;
  TBitPackEnumArray2     = bitpacked array [0..1, 0..2] of TEnum;
  TBitPackEnum3Array2    = bitpacked array [0..1, 0..2] of TEnum3;
  TBitPackSetArray2      = bitpacked array [0..1, 0..2] of TSet;
  TBitPackSet3Array2     = bitpacked array [0..1, 0..2] of TSet3;

  TBitPackBoolRecord     = bitpacked record a,b,c,d,e: Boolean; end;
  TBitPackTinyRecord     = bitpacked record a,b,c,d,e: TTinyRange; end;
  TBitPackTinyNegRecord  = bitpacked record a,b,c,d,e: TTinyNegRange; end;
  TBitPackEnumRecord     = bitpacked record a,b,c,d,e: TEnum; end;
  TBitPackEnum3Record    = bitpacked record a,b,c,d,e: TEnum3; end;
  TBitPackSetRecord      = bitpacked record a,b,c,d,e: TSet; end;
  TBitPackSet3Record     = bitpacked record a,b,c,d,e: TSet3; end;

  TBitPackBoolArrayRecord     = bitpacked record a,b: TBitPackBoolArray; end;
  TBitPackTinyArrayRecord     = bitpacked record a,b: TBitPackTinyArray; end;
  TBitPackTinyNegArrayRecord  = bitpacked record a,b: TBitPackTinyNegArray; end;
  TBitPackEnumArrayRecord     = bitpacked record a,b: TBitPackEnumArray; end;
  TBitPackEnum3ArrayRecord    = bitpacked record a,b: TBitPackEnum3Array; end;
  TBitPackSetArrayRecord      = bitpacked record a,b: TBitPackSetArray; end;
  TBitPackSet3ArrayRecord     = bitpacked record a,b: TBitPackSet3Array; end;

  TBitPackBoolRecordArray     = bitpacked array [0..3] of bitpacked record a,b,c: Boolean; end;
  TBitPackTinyRecordArray     = bitpacked array [0..3] of bitpacked record a,b,c: TTinyRange; end;
  TBitPackTinyNegRecordArray  = bitpacked array [0..3] of bitpacked record a,b,c: TTinyNegRange; end;
  TBitPackEnumRecordArray     = bitpacked array [0..3] of bitpacked record a,b,c: TEnum; end;
  TBitPackEnum3RecordArray    = bitpacked array [0..3] of bitpacked record a,b,c: TEnum3; end;
  TBitPackSetRecordArray      = bitpacked array [0..3] of bitpacked record a,b,c: TSet; end;
  TBitPackSet3RecordArray     = bitpacked array [0..3] of bitpacked record a,b,c: TSet3; end;

  TBitPackBoolTRecordArray     = bitpacked array [0..3] of TBitPackBoolRecord;
  TBitPackTinyTRecordArray     = bitpacked array [0..3] of TBitPackTinyRecord;
  TBitPackTinyNegTRecordArray  = bitpacked array [0..3] of TBitPackTinyNegRecord;
  TBitPackEnumTRecordArray     = bitpacked array [0..3] of TBitPackEnumRecord;
  TBitPackEnum3TRecordArray    = bitpacked array [0..3] of TBitPackEnum3Record;
  TBitPackSetTRecordArray      = bitpacked array [0..3] of TBitPackSetRecord;
  TBitPackSet3TRecordArray     = bitpacked array [0..3] of TBitPackSet3Record;

  TBitSize = -7..7;
  TFpDbgValueSize = bitpacked record
    Size: Int64;        // Also used for stried => can be negative
    BitSize: TBitSize;  // Must have the same sign as Size
  end;

  // recursive declaration
  TSize = record
    cx : Longint; cy : Longint;
   public
  {$if FPC_FULLVERSION >= 30000}
     constructor Create(asz :TSize);
  {$ENDIF}
  end;

  TFunc1 = function(SomeValue, Foo: Integer; Bar: Word; X: Byte): Boolean;
  TProc1 = procedure();
  TMeth1 = function(AVal: Integer): Boolean of object;
  {$if FPC_FULLVERSION >= 30000}
  PFuncSelfRef = ^TFuncSelfRef;
  TFuncSelfRef = function(SomeValue, Foo: PFuncSelfRef): PFuncSelfRef;
  {$ENDIF}

type
  (* LOCATION: TYPE *)

  // T_a_Byte = array of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=T_a_, "_OP_== array of ", (=;//, "_O2_== array of ", _EQ_=, _BLOCK_=TestVar )
  // PT_a_Byte = ^T_a_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=PT_a_, "_OP_={", "_O2_={", _pre3_=^T_a_, "//@@=} = ")  // }}}}

  // T_sa_Byte = array [0..2] of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=T_sa_, "_OP_== array [0..2] of ", (=;//, "_O2_== array [0..2] of ", _EQ_=, _BLOCK_=TestVar )
  // PT_sa_Byte = ^T_sa_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=PT_sa_, "_OP_={", "_O2_={", _pre3_=^T_sa_, "//@@=} = ")  // }}}}

  // T_nsa_Byte = array [-1..2] of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=T_nsa_, "_OP_== array [-1..2] of ", (=;//, "_O2_== array [-1..2] of ", _EQ_=, _BLOCK_=TestVar )
  // PT_nsa_Byte = ^T_nsa_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=PT_nsa_, "_OP_={", "_O2_={", _pre3_=^T_nsa_, "//@@=} = ")  // }}}}


  // type TxByte: type Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=Tx, "_OP_== type ", (=;//, "_O2_= = type", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestType )
  // type PTxByte: ^TxByte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=PTx, _OP_={, _O2_={, _pre3_=^Tx, "//@@=} = ", _BLOCK_=TestVar, _BLOCK2_=TestType ) //}

  // type PxByte: ^Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=Px, "_OP_==^", "_O2_==^", "(=;//", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer ) //}

  (******** CLASS ***********)

  TMyBaseClass = class
  public const
    (* LOCATION: class const *)
    // cl_c_Byte = Byte( 1 + add );
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=cl_c_, ADD=1, CHR1='c', _OP_==, _O2_=:, _EQ_==,"(nil)=nil", _BLOCK_=TestConst)
  public class var
    (* LOCATION: class var *)
    // cl_v_Byte: Byte = (1 + add);
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=cl_v_, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )
  public
    function SomeMeth1(SomeValue: Integer): Boolean;
  public
    (* LOCATION: field in baseclass *)
    // mbcByte: Byte;
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=mbc, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )
  end;
  PMyBaseClass = ^TMyBaseClass;

  TMyClass = class(TMyBaseClass)
  protected
    FFunctInt, FFunctIntConst: Integer;
  public
    (* LOCATION: field in class *)
    // mcByte: Byte;
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=mc, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )
    FMyStringList: TMyStringList;

    function SomeFuncIntRes(): Integer;
    function SomeFuncIntResAdd(a: integer): Integer;
  end;
  PMyClass = ^TMyClass;


  (******** RECORD ***********)

  TMyTestRec = record
    (* LOCATION: record var *)
    // rc_f_Byte: ADD=2, CHR1='r',
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=rc_f_, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )

    MyEmbedClass: TMyClass;
  end;
  PMyTestRec = ^TMyTestRec;

var
  MyClass1: TMyClass;
  MyNilClass1: TMyClass;
  MyClass2: TMyBaseClass; (* LOCATION: field, requires typecast of containing class *)
  MyPClass1: PMyClass;
  MyPClass2: PMyBaseClass;

  MyTestRec1: TMyTestRec;
  MyPTestRec1: PMyTestRec;

  MyStringItemList: TMyStringItemListShort;
  MyStringList: TMyStringList;

  U8Data1, U8Data2: Utf8String;

  {$if FPC_FULLVERSION >= 30000}
  dummy1: PFuncSelfRef;
  {$ENDIF}

const
(* LOCATION: global const *)
  // gcByte = Byte( 1 + add );
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gc, ADD=0, CHR1='A', _OP_==, _O2_=:, _EQ_==,"(nil)=nil", _BLOCK_=TestConst)

var
(* LOCATION: global var *)
  // gvByte: Byte = (1 + add);
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )
  // gv2_Byte: Byte = (1 + add);
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv2_, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )


(* LOCATION: global var  ARRAY OF <each type> *)
  // gvaByte: array of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gva, "_OP_=: array of", (=;//, "_O2_=: array of", _EQ_=, _BLOCK_=TestVar )
  // gvp_a_Byte: PT_a_;  // ^array of byte
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_a_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=PT_a_ ) // }

(* LOCATION: global var  ARRAY [0..2] OF <each type> *)
  // gv_sa_Byte: array [0..2] of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_sa_, "_OP_=: array [0..2] of", (=;//, "_O2_=: array [0..2] of", _EQ_=, _BLOCK_=TestVar )
  // gvp_sa_Byte: PT_sa_;  // ^array [0..2] of byte
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_sa_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=PT_sa_ ) // }

(* LOCATION: global var  ARRAY [-1..2] OF <each type> *)
  // gv_sa2_Byte: array [-1..2] of Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_nsa_, "_OP_=: array [-1..2] of", (=;//, "_O2_=: array [-1..2] of", _EQ_=, _BLOCK_=TestVar )
  // gvp_sa_Byte: PT_nsa_;  // ^array [-1..2] of byte
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_nsa_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=PT_nsa_ ) // }


(* LOCATION: global var  pointer <each type> *)
  // gvp_Byte: ^Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_, "_OP_=: ^", (=;//, "_O2_=: ^", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer )
  // gvp2_Byte: ^Byte; // gvp2_Byte := @gvaByte[1];
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp2_, "_OP_=: ^", (=;//, "_O2_=: ^", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer )

(* LOCATION: global var  TYPE alias // NO PRE-ASSIGNED VALUE *)
  // gvp_Byte: PxByte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvpt_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=Px, _BLOCK_=TestVar, _BLOCK2_=TestPointer ) // }

(* LOCATION: global var  NAMED pointer <each type> // NO PRE-ASSIGNED VALUE *)
  // gvtt_Byte: TxByte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvtt_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=Tx, _BLOCK_=TestVar, _BLOCK2_=TestType )  // }

(* LOCATION: global var  NAMED pointer <each TYPE ALIAS> // NO PRE-ASSIGNED VALUE *)
  // gvptt_Byte: PTxByte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvptt_, "_OP_={", "_O2_={", "//@@=} :", _pre3_=PTx, _BLOCK_=TestVar, _BLOCK2_=TestType )  // }


(* LOCATION: global var  untyped pointer // NO PRE-ASSIGNED VALUE *)
  // gv_ptr_Byte: pointer;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptr_, "_OP_=:pointer;//", "_O2_=:pointer;//" )
  // gv_ptr2_Byte: pointer;  //gv_ptr2_Byte := @gvaByte[1]
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptr2_, "_OP_=:pointer;//", "_O2_=:pointer;//" )
  // gv_aptr_Byte: array [0..2] of pointer;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_aptr_, "_OP_=:array [0..2] of pointer;//", "_O2_=:array [0..2] of pointer;//" )

(* LOCATION: global var  untyped PPointerList // NO PRE-ASSIGNED VALUE *)
  // gv_ptrlist_Byte: pointer;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptrlist_, "_OP_=:PPointerList;//", "_O2_=:PPointerList;//" )


{$if FPC_FULLVERSION >= 30000}
constructor TSize.Create(asz :TSize);
begin end;
{$endif}
constructor TObjectCreate3Int64.Create;
begin end;
destructor TObjectCreate3Int64.Destroy;
begin end;
procedure TObjectCreate3Int64.Foo;
begin end;

function TMyBaseClass.SomeMeth1(SomeValue: Integer): Boolean;
begin result := SomeValue = 0; end;


procedure Foo(
(* LOCATION: param *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=arg, _OP_=:, (=;//, _O2_=:, _EQ_= , _BLOCK_=TestArg)
  ArgMyClass1: TMyClass;
  ArgMyClass2: TMyBaseClass;
  ArgMyTestRec1: TMyTestRec;
  Dummy: Integer
);
var
(* LOCATION: local var *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=fooloc, _OP_=:, (=;//, _O2_=:, _EQ_=, _BLOCK_=TestVar )

(* LOCATION: local var  pointer <each type>  FOR locals *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=fooloc_pl_, "_OP_=: ^", (=;//, "_O2_=: ^", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer )
(* LOCATION: local var  pointer <each type>  FOR args *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=fooloc_pa_, "_OP_=: ^", (=;//, "_O2_=: ^", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer )

//TODO MyClass
begin  // TEST_BREAKPOINT=FooBegin
  BreakDummy:= 1;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=fooloc, ADD=2, CHR1='C', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)

(* INIT: local var  pointer <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=fooloc_pl_, _OP_={, _O2_={, _pre3_=@fooloc, "//@@=} :=", _BLOCK_=TestVar, _BLOCK2_=TestPointer) //}
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=fooloc_pa_, _OP_={, _O2_={, _pre3_=@arg, "//@@=} :=", _BLOCK_=TestArg, _BLOCK2_=TestPointer) //}

  BreakDummy:= 1; // TEST_BREAKPOINT=Foo
end;


procedure FooVar(
(* LOCATION: var param *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, "pre__=var argvar", _OP_=:, (=;//, _O2_=:, _EQ_= , _BLOCK_=TestArg)
  ArgVarMyClass1: TMyClass;
  ArgVarMyClass2: TMyBaseClass;
  ArgVarMyTestRec1: TMyTestRec;
  Dummy: Integer
);
var
(* LOCATION: var params  pointer <each type>  FOR args *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=fooloc_pv_, "_OP_=: ^", (=;//, "_O2_=: ^", _EQ_=, _BLOCK_=TestVar, _BLOCK2_=TestPointer )
begin // TEST_BREAKPOINT=FooVarBegin
(* INIT: local var  pointer <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=fooloc_pv_, _OP_={, _O2_={, _pre3_=@argvar, "//@@=} :=", _BLOCK_=TestPointer, _BLOCK2_=TestArg) //}

  BreakDummy:= 1;
  BreakDummy:= 1; // TEST_BREAKPOINT=FooVar
end;


procedure FooConstRef(
(* LOCATION: constref param *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, "pre__=constref argconstref", _OP_=:, (=;//, _O2_=:, _EQ_= , _BLOCK_=TestArg)
  ArgConstRefMyClass1: TMyClass;
  ArgConstRefMyClass2: TMyBaseClass;
  ArgConstRefMyTestRec1: TMyTestRec;
  Dummy: Integer
);
var
  xxx, xx2: ansistring; // enforce a stackframe
begin // TEST_BREAKPOINT=FooConstRefBegin
  BreakDummy:= 1;
  xxx := '1';
  BreakDummy:= 1; // TEST_BREAKPOINT=FooConstRef
end;

function TMyClass.SomeFuncIntRes(): Integer;
begin
  result := FFunctInt + FFunctIntConst;
end;
function TMyClass.SomeFuncIntResAdd(a: integer): Integer;
begin
  result := 77 + a;
  FFunctInt := result;
end;

begin
  U8Data1 := #$2267; //#$E2#$89#$A7;
  U8Data2 := #$2267'X';
  // access constant that are not passed as function arg
  // so every constant is accessed, and they can not be optimized away
  InterfacedObject:= TInterfacedObject.create;
  InterfacedObject2:= TInterfacedObject.create;
  BreakDummy := ord(gcCharStatArray[1]);
  BreakDummy := ord(gcWCharStatArray[1]);
  p := nil;
  PByteDummy := nil;
  pw := nil;
  SomeFunc1(1,1,1,1);
  SomeProc1();
  SomeFuncInt;
  SomeFuncIntRes;
  FuncIntAdd(1,1);
  FuncTooManyArg(1,1,1,1,1,1,1,1,1,1,1,1);
  {$if FPC_FULLVERSION >= 30000}
  dummy1 := nil;
  {$ENDIF}

(* use global const / value in "gv" will be overriden... *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv, {e}={, "//@@=} :=", _pre3_=gc, _BLOCK_=TestAssignGC)

(* INIT: global var *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv,   ADD=1, CHR1='B', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv2_, ADD=3, CHR1='D', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)

(* INIT: global var  TYPE alias // NO PRE-ASSIGNED VALUE *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gvtt_, ADD=7, CHR1='N', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign, _BLOCK2_=TestType)

(* INIT: global var  NAMED pointer <each type> // NO PRE-ASSIGNED VALUE *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvpt_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv, _BLOCK_=TestVar, _BLOCK2_=TestPointer ) // }

(* INIT: global var  NAMED pointer <each TYPE ALIAS> // NO PRE-ASSIGNED VALUE *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvptt_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gvtt_, _BLOCK_=TestVar, _BLOCK2_=TestType )  // }


(* INIT: global var  untyped NAMED pointer // NO PRE-ASSIGNED VALUE *)
  // gv_ptr_Byte := @gvByte;            // ADD=1, CHR1='B'
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptr_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv ) // }
  // gv_aptr_Byte[0] := @gvByte;        // ADD=1, CHR1='B'
  // gv_aptr_Byte[1] := @gv2_Byte;     // ADD=3, CHR1='D'
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_aptr_, "{e}=[0]", "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv ) // }
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_aptr_, "{e}=[1]", "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv2_ ) // }

(* INIT: global var  untyped PPointerList // NO PRE-ASSIGNED VALUE *)
  // gv_ptrlist_Byte := @gv_aptr_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptrlist_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv_aptr_ ) // }

(* INIT: class var *)
  // cl_v_Byte: Byte = (1 + add);
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=TMyClass.cl_v_,   ADD=1, CHR1='v', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)


(* INIT: field in class / baseclass *)
  MyClass1 := TMyClass.Create;
  MyClass1.FFunctIntConst := 999;
  MyClass1.SomeMeth1(1);
  MyClass1.SomeFuncIntRes();
  MyClass1.SomeFuncIntResAdd(1);
  MyPClass1 := @MyClass1;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=MyClass1.mbc, ADD=3, CHR1='D', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=MyClass1.mc, ADD=2, CHR1='C', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)

  MyNilClass1 := nil;

(* INIT: field in class / baseclass // typecast *)
  MyClass2 := TMyClass.Create;
  MyPClass2 := @MyClass2;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,"pre__=TMyClass(MyClass2).mbc", ADD=5, CHR1='F', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,"pre__=TMyClass(MyClass2).mc", ADD=4, CHR1='E', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)


(* INIT: record var *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=MyTestRec1.rc_f_, ADD=2, CHR1='r', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, _BLOCK_=TestAssign)
  MyPTestRec1 := @MyTestRec1;

  MyStringList := TMyStringList.Create;
  MyStringList.Flist := @MyStringItemList;
  MyClass1.FMyStringList := TMyStringList.Create;
  MyClass1.FMyStringList.Flist := @MyStringItemList;
  TMyClass(MyClass2).FMyStringList := TMyStringList.Create;
  TMyClass(MyClass2).FMyStringList.Flist := @MyStringItemList;
  MyStringItemList[0].FString := 'ABC1';
  MyStringItemList[1].FString := 'DEF2';
  MyStringItemList[2].FString := 'XYZ3';


(* INIT: global var  ARRAY OF <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,"pre__=SetLength(gva", "_OP_=,4);//", "_O2_=,4);//", _BLOCK_=TestSetLen)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gva, ADD=5, CHR1='K', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[0]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gva, ADD=6, CHR1='L', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[1]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gva, ADD=8, CHR1='N', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[2]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gva, ADD=9, CHR1='O', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[3]", _BLOCK_=TestAssign)
  // gvp_a_Byte := @gvaByte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_a_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gva ) // }

  // gv_ptr2_Byte := @gvaByte[1];
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv_ptr2_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gva ) //, {e3}=[1] }


(* INIT: global var  ARRAY [0..2] OF <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv_sa_, ADD=7, CHR1='O', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[0]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv_sa_, ADD=8, CHR1='P', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[1]", _BLOCK_=TestAssign)
  // gvp_sa_Byte := @gv_sa_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_sa_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv_sa_ ) // }

(* INIT: global var  ARRAY [-1..2] OF <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv_nsa_, ADD=9,  CHR1='Q', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[-1]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv_nsa_, ADD=10, CHR1='R', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[0]", _BLOCK_=TestAssign)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gv_nsa_, ADD=11, CHR1='S', _OP_=:=, _O2_={, _EQ_=}:=, _pre2_=gc, "{e}=[1]", _BLOCK_=TestAssign)
  // gvp_nsa_Byte := @gv_nsa_Byte;
  TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gvp_nsa_, "_OP_= {", "_O2_={ ", "//@@=} :=", _pre3_=@gv_nsa_ ) // }

(* INIT: global var  pointer <each type> *)
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gvp_, _OP_={, _O2_={, _pre3_=@gv, "//@@=} :=", _BLOCK_=TestVar, _BLOCK2_=TestPointer) //}
  TEST_PREPOCESS(WatchesValuePrgIdent.inc,pre__=gvp2_, _OP_={, _O2_={, _pre3_=@gva, "//@@=} :=", {e3}=[1], _BLOCK_=TestVar, _BLOCK2_=TestPointer) //}


  BreakDummy:= 1; // TEST_BREAKPOINT=Prg

  Foo(
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv, "_OP_=,//", "_O2_=,//", _BLOCK_=TestParam)
    MyClass1,
    MyClass2,
    MyTestRec1,
    0
  );

  FooVar(
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv, "_OP_=,//", "_O2_=,//", _BLOCK_=TestParam)
    MyClass1,
    MyClass2,
    MyTestRec1,
    0
  );

  FooConstRef(
    TEST_PREPOCESS(WatchesValuePrgIdent.inc, pre__=gv, "_OP_=,//", "_O2_=,//", _BLOCK_=TestParam)
    MyClass1,
    MyClass2,
    MyTestRec1,
    0
  );

end.


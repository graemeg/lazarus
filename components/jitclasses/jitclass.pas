(*
This file is distributed under the Lesser GNU General Public License
(see the file COPYING.LGPL) with the following modification:

As a special exception, the copyright holders of this library give you
permission to link this library with independent modules to produce an
executable, regardless of the license terms of these independent modules,
and to copy and distribute the resulting executable under terms of your choice,
provided that you also meet, for each linked independent module, the terms
and conditions of the license of that module. An independent module is a
module which is not derived from or based on this library. If you modify this
library, you may extend this exception to your version of the library, but
you are not obligated to do so. If you do not wish to do so, delete this
exception statement from your version.

If you didn't receive a copy of the file COPYING.LGPL, contact:
      Free Software Foundation, Inc.,
      675 Mass Ave
      Cambridge, MA  02139
      USA
*)
unit JitClass;

{$mode objfpc}{$H+}
{$ModeSwitch typehelpers}
{$PointerMath on}
{.$Inline off}

{$IF FPC_FULLVERSION<30100}
  {$DEFINE HasVMTParent}
{$ENDIF}
{$WARN 4055 off : Conversion between ordinals and pointers is not portable}
interface

uses
  Classes, SysUtils, TypInfo, fgl, PackageDependencyIntf,
  LazLoggerBase, JitTypes, JitHelper, JitRttiWriter;

const
  JIT_PROP_NO_DEFAULT_VAL = longint($80000000);

type

  TJitClassCreator = class;
  TJitMethodList = class;

  { TJitMethod }

  TJitMethod = class(TCollectionItem)
  private
    FCodeAddress: CodePointer;
    FDeclaration: String;
    FName: String;
    FCreateDummyCodePointer: Boolean;
    FJitType: TJitTypeInfo;

    procedure DoJitTypeFreed(Sender: TObject);
    function GetTypeInfo: PTypeInfo;
    function MethodList: TJitMethodList;
  public
    constructor Create(ACollection: TCollection; AName, ADeclaration: String; ACodeAddr: CodePointer); reintroduce;
    constructor Create(ACollection: TCollection; AName: String; ACodeAddr: CodePointer); reintroduce;
    constructor Create(ACollection: TCollection; AName, ADeclaration: String; ACreateDummyCodeAddr: Boolean); reintroduce;
    constructor Create(ACollection: TCollection; AName: String; ACreateDummyCodeAddr: Boolean); reintroduce;
    destructor Destroy; override;

    property Name: String read FName;
    property CodeAddress: CodePointer read FCodeAddress;
    property Declaration: String read FDeclaration;
    property TypeInfo: PTypeInfo read GetTypeInfo;
  end;

  { TJitMethodList }

  TJitMethodList = class(TCollection)
  private
    FOwner: TJitClassCreator;
    FTypeLibrary: TJitTypeLibrary;
    function GetItem(AIndex: Integer): TJitMethod;
    function GetMeth(AName: String): TJitMethod;
  protected
    procedure Update(Item: TCollectionItem); override;
    property  TypeLibrary: TJitTypeLibrary read FTypeLibrary;
  public
    constructor Create(AOwner: TJitClassCreator); reintroduce;

    function Add(AName, ADeclaration: String; ACodeAddr: CodePointer): TJitMethod; reintroduce; overload;
    function Add(AName: String; ACodeAddr: CodePointer): TJitMethod; reintroduce; overload;
    function Add(AName, ADeclaration: String; ACreateDummyCodeAddr: Boolean): TJitMethod; reintroduce; overload;
    function Add(AName: String; ACreateDummyCodeAddr: Boolean): TJitMethod; reintroduce; overload;
    procedure Remove(AName: String);
    function  IndexOf(AName: String): integer;

    property  Meth[AName: String]: TJitMethod read GetMeth;
    property  Items[AIndex: Integer]: TJitMethod read GetItem; default;
  end;

  TJitPropertyList = class;

  { TJitProperty }

  TJitProperty = class(TCollectionItem)
  private
    FDefaultVal: Longint;
    FIsStored: Boolean;
    FName: String;
    FDeclaration: String;
    FJitType: TJitType;
    FNoDefault: Boolean;
    FTypeInfo: PTypeInfo; // For buildin
    FisBuildIn: Boolean;
    FInstanceMemOffset: Integer;
    FWriteAble: Boolean;
    FNameIndex: Integer; // temp storage

    procedure DoJitClassFreed(Sender: TObject);
    function GetInstanceDataPointer(AnInstance: TObject): Pointer;
    function GetJitType: TJitType;
    function GetKind: TTypeKind;
    function GetTypeInfo: PTypeInfo;
    function PropertyList: TJitPropertyList;

    procedure ParseFromDeclaration;
    procedure SetDefaultVal(AValue: Longint);
    procedure SetIsStored(AValue: Boolean);
    procedure SetNoDefault(AValue: Boolean);

  protected
    FRecursionWasTriggered: Boolean;
  public
    constructor Create(ACollection: TCollection; AName, ADeclaration: String;
      AWriteAble: Boolean = True; ADefault: LongInt = 0; ANoDefault: Boolean = False; AStored: Boolean = True); reintroduce;
    constructor Create(ACollection: TCollection; AName: String; AJitType: TJitType;
      AWriteAble: Boolean = True; ADefault: LongInt = 0; ANoDefault: Boolean = False; AStored: Boolean = True); reintroduce;
    destructor Destroy; override;

    procedure SetDefaultFromIdent(AnDefaultIdent: String); // enum

    property Name: String read FName;
    property Declaration: String read FDeclaration;
    property Kind: TTypeKind read GetKind;
    property WriteAble: Boolean read FWriteAble;
    property TypeInfo: PTypeInfo read GetTypeInfo;
    property JitType: TJitType read GetJitType;

    property NoDefault: Boolean read FNoDefault write SetNoDefault;
    property DefaultVal: Longint read FDefaultVal write SetDefaultVal;
    property IsStored: Boolean read FIsStored write SetIsStored;

    property InstanceDataPointer[AnInstance: TObject]: Pointer read GetInstanceDataPointer;
  end;

  { TJitPropertyList }

  TJitPropertyList = class(TCollection)
  private type

    { TJitTypeInfoAcces }

    TJitTypeInfoParser = class(TJitTypeInfo)
    public
      constructor Create(ATypeName, AUnitName: String; AParser: PJitDeclarationParser;
        ATypeLibrary: TJitTypeLibrary = nil; AParseFlags: TJitTypeInfoParseFlags = []);
    end;
  private
    FOwner: TJitClassCreator;
    FTypeLibrary: TJitTypeLibrary;

    function GetItem(AIndex: Integer): TJitProperty;
    function GetKind(AName: String): TTypeKind;
    function GetProp(AName: String): TJitProperty;
    function DoCheckSectionEnd(AParser: PJitDeclarationParser): boolean;
  protected
    procedure Update(Item: TCollectionItem); override;
    property  TypeLibrary: TJitTypeLibrary read FTypeLibrary;
  public
    constructor Create(AOwner: TJitClassCreator); reintroduce;
    function  Add(AName, ADeclaration: String;
      AWriteAble: Boolean = True; ADefault: LongInt = 0; ANoDefault: Boolean = False; AStored: Boolean = True): TJitProperty; reintroduce;
    procedure Remove(AName: String);
    function  IndexOf(AName: String): integer;
    property  Prop[AName: String]: TJitProperty read GetProp;
    property  Items[AIndex: Integer]: TJitProperty read GetItem; default;
    procedure ParseFromClassDeclaration(ADecl: String);
  end;

  { TJitClassCreator }

  TJitClassCreator = class(TJitClassCreatorBase)
  private type

    { TRefCountedJitClassReference }

    TRefCountedJitClassReference = class(TRefCountedJitNestedReference)
    private
      FJitPVmt: PVmt;
      FAnchorClassRef: TRefCountedJitReference;
      procedure SetJitPVmt(AJitPVmt: PVmt);
      procedure FreePVmt;
    protected
      procedure DoRefCountZero; override;
      function NestedCount: integer; override;
      function GetNested(AnIndex: integer): TRefCountedJitReference; override;
    public
      constructor Create(AJitPVmt: PVmt);
      procedure AddToList(AJitProp: TJitProperty);
      procedure ClearList; override;
    end;

    TJitClassCreatorFlag = (
      ccfModifiedMethods, ccfModifiedProps, ccfModifiedClassName,
      ccfContinueAfterVMTNeeded, // vTypeInfo is a stub and must still be finished
      ccfJitPropsPrepareDone
    );
    TJitClassCreatorFlags = set of TJitClassCreatorFlag;
  private
    FJitMethods: TJitMethodList;
    FJitProperties: TJitPropertyList;
    FFlags: TJitClassCreatorFlags;

    FJitPVmt: PVmt;
    FRefCountedJitPVmt: TRefCountedJitClassReference;
    FAncestorClass: TClass;
    FAncestorJitClass: TJitClassCreator;
    FClassName: String;
    FTypeLibrary: TJitTypeLibrary;

    // Set by CreateJitPropsPrepare for CreateJitPropsFinish
    FTypeInfoMemSize, FRedirectPtrMemSize, FVmtParentMemSize: Integer;
    FRttiWriterClass: TJitRttiWriterTkClass;

    function RefCountedJitPvmt: TRefCountedJitClassReference;
    procedure SetJitPVmt(AJitPVmt: PVmt);
    procedure DoTypeLibFreed(Sender: TObject);
    procedure DoAnchesterJitClassFreed(Sender: TObject);

    function GetJitClass: TClass;
    procedure SetClassName(AValue: String);
    procedure SetClassUnit(AValue: String);
    procedure SetTypeLibrary(AValue: TJitTypeLibrary);
    procedure RaiseUnless(ACond: Boolean; const AMsg: string);
    function dbgsFlag(AFlags: TJitClassCreatorFlags): String;
  protected
    class procedure FreeJitClass(AJitPVmt: PVmt);
    function GetLockReferenceObj: TRefCountedJitReference; override;
    function  GetTypeInfo: PTypeInfo; override;

    procedure CreateJitClass;
    procedure CreateJitClassPreCheck;
    procedure CreateJitClassVMT;
    procedure CreateJitClassCallAllProp(AFirstEntry: Boolean = False);
    procedure CreateJitClassContinueAfteVMT;

    procedure UpdateClassName;
    procedure CreateJitMethods;
    procedure CreateJitProps;
    procedure CreateJitPropsPrepare;
    procedure CreateJitPropsFinish;
  public
    constructor Create(AnAncestorClass: TClass; AClassName: String; AClassUnit: String);
    constructor Create(AnAncestorJitClass: TJitClassCreator; AClassName: String; AClassUnit: String);
    destructor Destroy; override;

    (* UpdateJitClass
       * If no JitClass has been created, this forces creation of the JitClass.
         So calling the property JitClass later will not see any changes made
         from here on
       * If a JitClass already exists, this keeps the JitClass.
         It will update the following data:
         - Updates the ClassName
         - recreates the vmtMethodTable
         It will NOT update changes to the JitProperties
    *)
    procedure UpdateJitClass;
    (* This will trigger re-creation of the JitClass by removing the current
       JitClass.
       (The memory will be kept for any existing LockReference. So any instances
       created from the class, can be kept with the current class, by keeping
       a lock)
       The JitClass will be recreated, when the property JitClass is called
       again (or when UpdateJitClass is called).
    *)
    procedure RecreateJitClass;

    property AncestorClass: TClass read FAncestorClass; // write SetAncestorClass;
    property ClassName: String read FClassName write SetClassName; deprecated 'use JitClassName';
    property JitClassName: String read FClassName write SetClassName;

    property  TypeLibrary: TJitTypeLibrary read FTypeLibrary write SetTypeLibrary;
    property JitMethods: TJitMethodList read FJitMethods;
    property JitProperties: TJitPropertyList read FJitProperties;

    property JitClass: TClass read GetJitClass;
  end;

implementation

function GetVMTSize(AClass: TClass): integer;
const
  MAX_VMT_SIZE = 100000;
var
  p: PPointer;
begin
  assert(AClass <> nil, 'GetVMTSize: AClass <> nil');
  Result:=vmtMethodStart;
  p:=PPointer(pointer(AClass)+Result);
  while (p^<>nil) and (Result<MAX_VMT_SIZE) do begin
    inc(p);
    inc(Result,SizeOf(Pointer));
  end;
  inc(Result,SizeOf(Pointer)); // include the trailing 0
end;

{ TJitMethodList }

function TJitMethodList.GetItem(AIndex: Integer): TJitMethod;
begin
  Result := TJitMethod(inherited Items[AIndex]);
end;

function TJitMethodList.GetMeth(AName: String): TJitMethod;
var
  i: Integer;
begin
  i := IndexOf(AName);
  if i >= 0 then
    Result := TJitMethod(Items[i])
  else
    Result := nil;
end;

procedure TJitMethodList.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  include(FOwner.FFlags, ccfModifiedMethods);
end;

function TJitMethodList.IndexOf(AName: String): integer;
begin
  Result := Count - 1;
  while (Result >= 0) and (Items[Result].Name <> AName) do
    dec(Result);
end;

constructor TJitMethodList.Create(AOwner: TJitClassCreator);
begin
  FOwner := AOwner;
  inherited Create(TJitMethod);
end;

function TJitMethodList.Add(AName, ADeclaration: String; ACodeAddr: CodePointer
  ): TJitMethod;
begin
  Result := TJitMethod.Create(Self, AName, ADeclaration, ACodeAddr);
end;

function TJitMethodList.Add(AName: String; ACodeAddr: CodePointer): TJitMethod;
begin
  Result := TJitMethod.Create(Self, AName, ACodeAddr);
end;

function TJitMethodList.Add(AName, ADeclaration: String;
  ACreateDummyCodeAddr: Boolean): TJitMethod;
begin
  Result := TJitMethod.Create(Self, AName, ADeclaration, ACreateDummyCodeAddr);
end;

function TJitMethodList.Add(AName: String; ACreateDummyCodeAddr: Boolean
  ): TJitMethod;
begin
  Result := TJitMethod.Create(Self, AName, ACreateDummyCodeAddr);
end;

procedure TJitMethodList.Remove(AName: String);
begin
  Delete(IndexOf(AName));
end;

{ TJitMethod }

function TJitMethod.MethodList: TJitMethodList;
begin
  Result := TJitMethodList(Collection);
end;

function TJitMethod.GetTypeInfo: PTypeInfo;
begin
  if FJitType = nil then begin
    FJitType := TJitTypeInfo.Create('', FDeclaration,
      MethodList.FOwner.ClassUnit, MethodList.TypeLibrary, [pfAllowProcName, pfAlwaysAsMethod]);
    FJitType.AddFreeNotification(@DoJitTypeFreed);
  end;

  Result := FJitType.TypeInfo;
end;

procedure TJitMethod.DoJitTypeFreed(Sender: TObject);
begin
  FJitType := nil;
end;

constructor TJitMethod.Create(ACollection: TCollection; AName,
  ADeclaration: String; ACodeAddr: CodePointer);
begin
  inherited Create(ACollection);
  if MethodList.IndexOf(AName) >= 0 then
    raise Exception.Create('duplicate method name');

  FName := AName;
  FDeclaration := ADeclaration;
  FCodeAddress := ACodeAddr;
end;

constructor TJitMethod.Create(ACollection: TCollection; AName: String;
  ACodeAddr: CodePointer);
begin
  Create(ACollection, AName, '', ACodeAddr);
end;

constructor TJitMethod.Create(ACollection: TCollection; AName,
  ADeclaration: String; ACreateDummyCodeAddr: Boolean);
begin
  Create(ACollection, AName, ADeclaration, nil);
  FCreateDummyCodePointer := True;
end;

constructor TJitMethod.Create(ACollection: TCollection; AName: String;
  ACreateDummyCodeAddr: Boolean);
begin
  Create(ACollection, AName, '', nil);
  FCreateDummyCodePointer := True;
end;

destructor TJitMethod.Destroy;
begin
  FJitType.Free;
  inherited Destroy;
end;

{ TJitClassCreator.TRefCountedJitClassReference }

procedure TJitClassCreator.TRefCountedJitClassReference.SetJitPVmt(
  AJitPVmt: PVmt);
begin
  if (RefCount > 1) and (FJitPVmt <> nil) then
    raise Exception.Create('set TypeInfo while referrenced');

  if (FJitPVmt <> nil) then begin
    inherited ClearList;
    FreePVmt;
  end;

  FJitPVmt := AJitPVmt;
end;

procedure TJitClassCreator.TRefCountedJitClassReference.FreePVmt;
begin
  TJitClassCreator.FreeJitClass(FJitPVmt);
end;

procedure TJitClassCreator.TRefCountedJitClassReference.DoRefCountZero;
begin
  FreePVmt;
  if FAnchorClassRef <> nil then begin
    FAnchorClassRef.ReleaseLock;
    FAnchorClassRef := nil;
  end;
  inherited DoRefCountZero;
end;

function TJitClassCreator.TRefCountedJitClassReference.NestedCount: integer;
begin
  Result := inherited NestedCount;
  if FAnchorClassRef <> nil then
    inc(Result);
end;

function TJitClassCreator.TRefCountedJitClassReference.GetNested(
  AnIndex: integer): TRefCountedJitReference;
begin
  if FAnchorClassRef <> nil then begin
  if (AnIndex = 0) then
      Result := FAnchorClassRef
    else
      Result := inherited GetNested(AnIndex - 1);
  end
  else
    Result := inherited GetNested(AnIndex);
end;

constructor TJitClassCreator.TRefCountedJitClassReference.Create(AJitPVmt: PVmt
  );
begin
  inherited Create;
  FJitPVmt := AJitPVmt;
end;

procedure TJitClassCreator.TRefCountedJitClassReference.AddToList(
  AJitProp: TJitProperty);
var
  jt: TJitType;
begin
  if AJitProp = nil then
    exit;
  jt := AJitProp.JitType;
  if jt = nil then
    exit;
  inherited AddToList(jt.LockReference);
end;

procedure TJitClassCreator.TRefCountedJitClassReference.ClearList;
begin
  inherited ClearList;
  if FAnchorClassRef <> nil then
    FAnchorClassRef.ReleaseLock;
  FAnchorClassRef := nil;
end;

{ TJitProperty }

function TJitProperty.PropertyList: TJitPropertyList;
begin
  Result := TJitPropertyList(Collection);
end;

function TJitProperty.GetKind: TTypeKind;
var
  t: PTypeInfo;
begin
  Result := tkUnknown;
  t := TypeInfo;
  if t <> nil then
    Result := t^.Kind;
end;

function TJitProperty.GetJitType: TJitType;
begin
  Result := FJitType;
  if Result <> nil then
    exit;

  ParseFromDeclaration;
  Result := FJitType;
end;

function TJitProperty.GetInstanceDataPointer(AnInstance: TObject): Pointer;
begin
  if (FInstanceMemOffset > 0) and (AnInstance <> nil) then
    Result := Pointer(AnInstance) + FInstanceMemOffset
  else
    Result := nil;
end;

procedure TJitProperty.DoJitClassFreed(Sender: TObject);
begin
  FJitType := nil;
end;

function TJitProperty.GetTypeInfo: PTypeInfo;
var
  jt: TJitType;
begin
  Result := nil;
  jt := JitType;
  if FisBuildIn then begin
    Result := FTypeInfo;
    exit;
  end;

  if jt = nil then
    exit;
  Result := jt.TypeInfo;
end;

constructor TJitProperty.Create(ACollection: TCollection; AName,
  ADeclaration: String; AWriteAble: Boolean; ADefault: LongInt;
  ANoDefault: Boolean; AStored: Boolean);
begin
  inherited Create(ACollection);
  if PropertyList.IndexOf(AName) >= 0 then
    raise Exception.Create('duplicate property name');

  FName := AName;
  FDeclaration := ADeclaration;
  FWriteAble   := AWriteAble;
  FDefaultVal  := ADefault;
  FNoDefault   := ANoDefault;
  FIsStored    := AStored;
end;

constructor TJitProperty.Create(ACollection: TCollection; AName: String;
  AJitType: TJitType; AWriteAble: Boolean; ADefault: LongInt;
  ANoDefault: Boolean; AStored: Boolean);
begin
  inherited Create(ACollection);
  if PropertyList.IndexOf(AName) >= 0 then
    raise Exception.Create('duplicate property name');

  FName := AName;
  FJitType := AJitType;
  FJitType.AddFreeNotification(@DoJitClassFreed);
  FWriteAble   := AWriteAble;
  FDefaultVal  := ADefault;
  FNoDefault   := ANoDefault;
  FIsStored    := AStored;
end;

destructor TJitProperty.Destroy;
begin
  inherited Destroy;
  if (FJitType <> nil) then
    FJitType.RemoveFreeNotification(@DoJitClassFreed);
  if (FJitType <> nil) and (not FJitType.OwnedByLibrary) then
    FJitType.Free;
end;

procedure TJitProperty.SetDefaultFromIdent(AnDefaultIdent: String);
var
  i: int64;
  ti: PTypeInfo;
begin
  if AnDefaultIdent = '' then begin
    DefaultVal := 0;
    exit;
  end;
  if TryStrToInt64(AnDefaultIdent, i) then begin
    DefaultVal := i;
    exit;
  end;
  ti := TypeInfo;

  if ti^.Kind = tkEnumeration then begin
    i := GetEnumValue(ti, AnDefaultIdent);
    if i >= 0 then begin
      DefaultVal := i;
      exit;
    end;
  end
  else
  if ti^.Kind = tkSet then begin
    i := StringToSet(ti, AnDefaultIdent);
    DefaultVal := i;
    exit;
  end;

  raise Exception.Create('Cannot parse default');
end;

procedure TJitProperty.ParseFromDeclaration;
var
  Decl: String;
  TypeLib: TJitTypeLibrary;
begin
  assert(FJitType = nil, 'TJitProperty.ParseFromDeclaration: FJitType = nil');
  if FisBuildIn then
    exit;

  Decl := TrimDeclaration(FDeclaration);
  if Decl = '' then
    exit;

  TypeLib := PropertyList.TypeLibrary;

  if TypeLib <> nil then begin
    FJitType := TypeLib[FDeclaration];
    if FJitType <> nil then begin
      FJitType.AddFreeNotification(@DoJitClassFreed);
      exit;
    end;
  end;

  FTypeInfo := TypeInfoByName(Decl);
  FisBuildIn := FTypeInfo <> nil;
  if FisBuildIn then
    exit;

  FJitType := TJitTypeInfo.Create(FName, Decl, PropertyList.FOwner.ClassUnit, PropertyList.TypeLibrary);
end;

procedure TJitProperty.SetDefaultVal(AValue: Longint);
begin
  if FDefaultVal = AValue then Exit;
  FDefaultVal := AValue;
  Changed(False);
end;

procedure TJitProperty.SetIsStored(AValue: Boolean);
begin
  if FIsStored = AValue then Exit;
  FIsStored := AValue;
  Changed(False);
end;

procedure TJitProperty.SetNoDefault(AValue: Boolean);
begin
  if FNoDefault = AValue then Exit;
  FNoDefault := AValue;
  Changed(False);
end;

{ TJitPropertyList.TJitTypeInfoParser }

constructor TJitPropertyList.TJitTypeInfoParser.Create(ATypeName,
  AUnitName: String; AParser: PJitDeclarationParser;
  ATypeLibrary: TJitTypeLibrary; AParseFlags: TJitTypeInfoParseFlags);
begin
  inherited Create(ATypeName, AUnitName, '', ATypeLibrary, AParseFlags);
  ParseFromDeclaration(AParser);
end;

{ TJitPropertyList }

function TJitPropertyList.DoCheckSectionEnd(AParser: PJitDeclarationParser
  ): boolean;
var
  s: String;
begin
  s := LowerCase(AParser^.PeekTokenRaw); // "Raw" => must not strip any escaping &ident
  Result := (s = 'write') or (s = 'read') or (s = 'default') or (s = 'nodefault') or (s = 'stored');
end;

function TJitPropertyList.GetItem(AIndex: Integer): TJitProperty;
begin
  Result := TJitProperty(inherited Items[AIndex]);
end;

function TJitPropertyList.GetKind(AName: String): TTypeKind;
begin
  Result := Prop[AName].Kind;
end;

function TJitPropertyList.GetProp(AName: String): TJitProperty;
var
  i: Integer;
begin
  i := IndexOf(AName);
  if i >= 0 then
    Result := TJitProperty(Items[i])
  else
    Result := nil;
end;

procedure TJitPropertyList.Update(Item: TCollectionItem);
begin
  inherited Update(Item);
  include(FOwner.FFlags, ccfModifiedProps);
end;

function TJitPropertyList.IndexOf(AName: String): integer;
begin
  Result := Count - 1;
  while (Result >= 0) and (Items[Result].Name <> AName) do
    dec(Result);
end;

constructor TJitPropertyList.Create(AOwner: TJitClassCreator);
begin
  FOwner := AOwner;
  inherited Create(TJitProperty);
end;

function TJitPropertyList.Add(AName, ADeclaration: String; AWriteAble: Boolean;
  ADefault: LongInt; ANoDefault: Boolean; AStored: Boolean): TJitProperty;
begin
  Result := TJitProperty.Create(Self, AName, ADeclaration, AWriteAble,
    ADefault, ANoDefault, AStored);
end;

procedure TJitPropertyList.Remove(AName: String);
begin
  Delete(IndexOf(AName));
end;

procedure TJitPropertyList.ParseFromClassDeclaration(ADecl: String);
var
  Parser: TJitDeclarationParser;
  InPublished, NewWritable, NewNoDefault, NewIsStored, HasClass: Boolean;
  tk: TJitParserTkKind;
  NewName, s, NewDefault: String;
  NewPropJitType: TJitTypeInfoParser;
  TheProp: TJitProperty;
begin
  if ADecl = '' then
    exit;

  Parser := TJitDeclarationParser.Create(@ADecl[1]);
  InPublished := true;

  HasClass := False;
  if Parser.CurrentKind = kwClass then begin
    HasClass := True;
    // skipp "class (foo, intf)
    if Parser.PeekKind = ptRoundOpen then begin
      Parser.Next;
      tk := Parser.Next;
      while tk in [ptIdent, ptDot, ptComma] do
        tk := Parser.Next;
      if tk <> ptRoundClose then
        raise Exception.Create('expecting )');
    end;
    Parser.Next;
  end;

  while True do begin
    case Parser.CurrentKind of
      kwPublished: begin
          InPublished := True;
          Parser.Next;
        end;
      kwPrivate, kwProtected, kwPublic: begin
          InPublished := False;
          Parser.Next;
        end;
      kwFunction, kwProcedure: begin
          TJitTypeInfoParser.Create('', FOwner.ClassUnit, @Parser, TypeLibrary, [pfAllowProcName]).Free;
          tk := Parser.Next;
          if not (tk in [ptSemicolon, kwEnd]) then
            raise Exception.Create('expecting ;');
          Parser.Next;
        end;
      ptIdent: begin
          // skip variables
          tk := Parser.Next;
          while tk in [ptIdent, ptDot, ptComma] do
            tk := Parser.Next;
          if tk <> ptColon then
            raise Exception.Create('expecting :');
          Parser.Next;

          TJitTypeInfoParser.Create('', FOwner.ClassUnit, @Parser, TypeLibrary).Free;

          tk := Parser.Next;
          if not (tk in [ptSemicolon, kwEnd]) then
            raise Exception.Create('expecting ;');
          Parser.Next;
        end;
      kwProperty: begin
          tk := Parser.Next;
          if tk <> ptIdent then
            raise Exception.Create('expecting name');
          NewName := Parser.CurrentToken;

          tk := Parser.Next;
          if tk = ptSquareOpen then begin
            // no support for indexed properties / but skip over it
            tk := Parser.Next;
            while tk in [ptIdent, ptDot, ptColon, ptSemicolon] do
              tk := Parser.Next;
            if tk <> ptSquareClose then
              raise Exception.Create('expecting ]');
            tk := Parser.Next;
          end;
          if tk <> ptColon then
            raise Exception.Create('expecting :');
          Parser.Next;

          Parser.CheckSectionEndProc  := @DoCheckSectionEnd; // check for read/write keywords in property declaration
          NewPropJitType := TJitTypeInfoParser.Create('', FOwner.ClassUnit, @Parser, TypeLibrary);
          Parser.CheckSectionEndProc  := nil;

          NewWritable := False;
          NewDefault:= '';
          NewNoDefault := False;
          NewIsStored := True;
          tk := Parser.CurrentKind;
          if tk = ptIdent then begin // stopped at read or write
            while tk in [ptIdent, ptDot] do begin
              if (tk = ptIdent) then begin
                s := LowerCase(Parser.CurrentToken);
                if (s = 'write') then
                  NewWritable := True;
                if (s = 'default') then begin
                  tk := Parser.Next();
                  NewDefault := Parser.CurrentToken;
                  if not (tk in [ptIdent, ptNum]) then
                    raise Exception.Create('expecting default value');
                end;
                if (s = 'nodefault') then
                  NewNoDefault := True;
                if (s = 'stored') then begin
                  Parser.Next();
                  s := LowerCase(Parser.CurrentToken);
                  if s = 'true' then
                    NewIsStored := True
                  else
                  if s = 'false' then
                    NewIsStored := False
                  else
                    raise Exception.Create('expecting stored value');
                end;
              end;
              tk := Parser.Next;
            end;
          end;

          if not (tk in [ptSemicolon, kwEnd]) then
            raise Exception.Create('expecting ;');
          Parser.Next;
          // todo: skip deprecated and the lot

          if InPublished then begin
            TheProp := TJitProperty.Create(Self, NewName, NewPropJitType, NewWritable, 0, NewNoDefault);
            TheProp.SetDefaultFromIdent(NewDefault);
            TheProp.SetIsStored(NewIsStored);
          end
          else
            NewPropJitType.Free;

        end;
      ptEOT: begin
          if HasClass then
            raise Exception.Create('expected "end", but got EOT')
          else
            break;
        end;
      kwEnd: break;
      else
        raise Exception.Create('unexpected: ' + Parser.CurrentToken);
    end;
  end;
end;

{ TJitClassCreator }

procedure TJitClassCreator.DoTypeLibFreed(Sender: TObject);
begin
  FTypeLibrary := nil;
  FJitProperties.FTypeLibrary := nil;
  FJitMethods.FTypeLibrary := nil;
end;

procedure TJitClassCreator.DoAnchesterJitClassFreed(Sender: TObject);
begin
  FAncestorJitClass := nil;
end;

function TJitClassCreator.RefCountedJitPvmt: TRefCountedJitClassReference;
begin
  if FRefCountedJitPVmt = nil then begin
    (* FTypeInfo may be nil, but a refernce can be got anyway *)
    FRefCountedJitPVmt := TRefCountedJitClassReference.Create(FJitPVmt);
  end;
  Result := FRefCountedJitPVmt;
end;

procedure TJitClassCreator.SetJitPVmt(AJitPVmt: PVmt);
begin
  if FJitPVmt = AJitPVmt then Exit;
  FJitPVmt := AJitPVmt;
  if FRefCountedJitPVmt <> nil then begin
    if (FRefCountedJitPVmt.RefCount = 1) or (FRefCountedJitPVmt.FJitPVmt = nil) then
      FRefCountedJitPVmt.SetJitPVmt(AJitPVmt)
    else begin
      FRefCountedJitPVmt.ReleaseLock;
      FRefCountedJitPVmt := TRefCountedJitClassReference.Create(AJitPVmt);
    end;
  end;
end;

function TJitClassCreator.GetJitClass: TClass;
begin
  if not assigned(FJitPVmt) then
    CreateJitClass
  else begin
    CreateJitClassCallAllProp; // Finish triggering all recursions
    if ccfContinueAfterVMTNeeded in FFlags then
      CreateJitClassContinueAfteVMT;
  end;

  Result := TClass(FJitPVmt);
end;

procedure TJitClassCreator.SetClassName(AValue: String);
begin
  if FClassName = AValue then Exit;
  FClassName := AValue;
  include(FFlags, ccfModifiedClassName);
end;

procedure TJitClassCreator.SetClassUnit(AValue: String);
begin
  if FClassUnit = AValue then Exit;
  FClassUnit := AValue;
end;

procedure TJitClassCreator.SetTypeLibrary(AValue: TJitTypeLibrary);
begin
  if FTypeLibrary <> nil then
    FTypeLibrary.RemoveFreeNotification(@DoTypeLibFreed);

  FTypeLibrary := AValue;
  FJitProperties.FTypeLibrary := AValue;
  FJitMethods.FTypeLibrary := AValue;

  if FTypeLibrary <> nil then
    FTypeLibrary.AddFreeNotification(@DoTypeLibFreed);
end;

procedure TJitClassCreator.RaiseUnless(ACond: Boolean; const AMsg: string);
begin
  if not ACond then
    raise Exception.Create(AMsg);
end;

function TJitClassCreator.dbgsFlag(AFlags: TJitClassCreatorFlags): String;
var
  i: TJitClassCreatorFlag;
  s: String;
begin
  Result := '';
  for i in TJitClassCreatorFlags do
    if i in AFlags then begin
      WriteStr(s, i);
      Result := Result + ',' + s;
    end;
  if Result = '' then
    exit;
  Result[1] := '[';
  Result := Result + ']';
end;

function TJitClassCreator.GetLockReferenceObj: TRefCountedJitReference;
begin
  Result := RefCountedJitPvmt;
end;

procedure TJitClassCreator.CreateJitClassPreCheck;
begin
  assert(FJitPVmt = nil, 'TJitClassCreator.CreateJitClassPreCheck: FJitPVmt = nil');
  RaiseUnless((FAncestorClass <> nil) or (FAncestorJitClass <> nil), 'Missing Ancestor');
  RaiseUnless(IsValidIdent(FClassName), 'Invalid or missing ClassName');
  RaiseUnless(IsValidUnitName(FClassUnit), 'Invalid or missing UnitName');
end;

procedure TJitClassCreator.CreateJitClassVMT;
var
  AncestorVMT: PVmt;
  VmtFullSize, VmtMethodsSize: Integer;
begin
  (* Create the VMT, so it can be used as anchestor.
     Do not yet access any Properties, to avoid recursion. This may be called
     by a child-class that can not yet provide typeinfo
  *)
  if FAncestorClass = nil then begin
    (* Only get the class VMT
       Do not yet trigger the vTypeInfo(ClassInfo), as that may cause recursion
       => Access field direct. It was set by calling FAncestorJitClass.CreateJitClass(True)
    *)
    FAncestorClass := TClass(FAncestorJitClass.FJitPVmt);
    RaiseUnless((FAncestorClass <> nil), 'Missing Ancestor');
    RefCountedJitPvmt.FAnchorClassRef := FAncestorJitClass.LockReference;
    assert(FJitPVmt = nil, 'TJitClassCreator.CreateJitClassVMT: Not called recursively by anchestor');
// TODO: adjust FieldOffsets
  end;

  AncestorVMT:=PVmt(FAncestorClass);
  DebugLn(AncestorVMT^.vAutoTable <> nil, 'vmtAutoTable is not yet supported');

  // create vmt
  VmtFullSize:=GetVMTSize(FAncestorClass);
  VmtMethodsSize:=VmtFullSize-vmtMethodStart;
  SetJitPVmt(AllocMem(VmtFullSize));

  (* The following entries are searched recursively in the base classes,
     and do not need to be copied.
     vmtDynamicTable
     vmtMethodTable: look up published methods
     vmtFieldTable:  published fields for componenents
     vmtIntfTable
     vmtMsgStrPtr
  *)
  // set vmtParent
  {$IFDEF HasVMTParent}
  FJitPVmt^.vParent:=AncestorVMT;
  {$ELSE}
  GetMem(FJitPVmt^.vParentRef,SizeOf(Pointer));
  FJitPVmt^.vParentRef^:=AncestorVMT;
  {$ENDIF}

  // copy the methods part
  System.Move(Pointer(Pointer(AncestorVMT)+vmtMethodStart)^,
              Pointer(Pointer(FJitPVmt)+vmtMethodStart)^,
              VmtMethodsSize);
end;

procedure TJitClassCreator.CreateJitClassCallAllProp(AFirstEntry: Boolean);
var
  i: Integer;
begin
  (* Trigger all properties.
     - This may trigger an child-class, which needs to call (and wait for) CreateJitPropsFinish
     - Any child class that is triggered will call our GetJitClass.
       - If that happens we must finish CreateJitPropsFinish (calculate vInstanceSize
         before we return.
       - An we may have refernces to several children of ours, we must trigger
         all of them, before entering CreateJitPropsFinish.
         Once in CreateJitPropsFinish, all props are called again, but would get
         a stub (vInstanceSize = zero) back.
         Therefore we continue this loop when we enter GetJitClass.
         (Recursively, until we have done all entries. Then each entry can be given
         a full TypeInfo)
  *)
  if AFirstEntry then
    For i := 0 to FJitProperties.Count - 1 do
      FJitProperties.Items[i].FRecursionWasTriggered := False;

  For i := 0 to FJitProperties.Count - 1 do
    if not FJitProperties.Items[i].FRecursionWasTriggered then begin
      FJitProperties.Items[i].FRecursionWasTriggered := True;
      FJitProperties.Items[i].TypeInfo;
    end;
end;

procedure TJitClassCreator.CreateJitClassContinueAfteVMT;
begin
  if (FAncestorJitClass <> nil) and (PVmt(FAncestorClass)^.vInstanceSize  = 0) then begin
    include(FFlags, ccfContinueAfterVMTNeeded); // come back, when the anchestor is ready
    exit;
  end;
  Exclude(FFlags, ccfContinueAfterVMTNeeded);
  CreateJitProps;
  CreateJitMethods;
end;

procedure TJitClassCreator.CreateJitClass;
var
  HasJitAnchestor: Boolean;
begin
  CreateJitClassPreCheck;
  FFlags := FFlags - [ccfModifiedMethods, ccfModifiedProps, ccfModifiedClassName];

  (* * We always need the anchestor first
       - vInstanceSize
       - PropList (with Count and NameIndex)
     * Once the anchestor has some stub ready
       (At the end of CreateJitPropsPrepare, incl PropList, excl vInstanceSize)
       it will trigger all recursions.
       CreateJitClass may be re-enteded. (Including being called as anchestor)
     * Re-entry of CreateJitClass will
       - build the full VMT and TypeInfo (incl PropList and vInstanceSize)
       - in the process, it will itself trigger recursion
       - It will make a further call to the anchestor, which will complete
         the anchestors vInstanceSize
  *)
  HasJitAnchestor := (FAncestorClass = nil);
  if HasJitAnchestor then begin
    FAncestorJitClass.JitClass;
    (* If we are
       *>> OUTSIDE a recursion   then
           - FAncestorJitClass.FJitPVmt           is fully created
           - FAncestorJitClass.FJitPVmt.vTypeInfo is fully created
           => We can fully create our own FJitPVmt and TypeInfo
       *>> WITHIN a recursion   then  (only if recursing from the anchestor)
           - FAncestorJitClass.FJitPVmt           is a  STUB  (vInstanceSize = 0)
           - FAncestorJitClass.FJitPVmt.vTypeInfo is a  STUB  (with a PropList stub)
           => We will create a  STUB  for our own FJitPVmt and TypeInfo
              We will finish the stub, once back in our outer call.
    *)
    assert(((FAncestorJitClass.FJitPVmt <> nil) and (FAncestorJitClass.FJitPVmt^.vTypeInfo <> nil)), 'TJitClassCreator.CreateJitClass: ((FAncestorJitClass.FJitPVmt <> nil) and (FAncestorJitClass.FJitPVmt^.vTypeInfo <> nil))');
  end;

  if (FJitPVmt = nil) then begin
    CreateJitClassVMT;
    // FAncestorClass is set now
  end;

  UpdateClassName;
  // FJitPVmt^.vTypeInfo may have been done (as stub) in a recursive call
  if FJitPVmt^.vTypeInfo = nil then begin
    CreateJitPropsPrepare;
    (* Trigger all recursions (we may be re-enterd / re-entry to GetJitClass)
       If we are re-entered, we go straight to CreateJitClassContinueAfteVMT (directly from GetJitClass)
    *)
    CreateJitClassCallAllProp(True);
  end;

  (* * If we are in a recursion from our anchestor then anchestors.vInstanceSize
       will be zero. CreateJitClassContinueAfteVMT will defer its work
     * If a property class (outside the anchestor recursion) has (re-)entered
        our (Get)JitClass, then CreateJitClassContinueAfteVMT may have finished.
        (if it finished it will have cleared ccfContinueAfterVMTNeeded)
  *)
  if ccfContinueAfterVMTNeeded in FFlags then
    CreateJitClassContinueAfteVMT;
end;

class procedure TJitClassCreator.FreeJitClass(AJitPVmt: PVmt);
begin
  if AJitPVmt = nil then
    exit;

  if AJitPVmt^.vTypeInfo <> nil then
    Freemem(AJitPVmt^.vTypeInfo);
  if AJitPVmt^.vInitTable <> nil then
    Freemem(AJitPVmt^.vInitTable);
  if AJitPVmt^.vMethodTable <> nil then
    Freemem(AJitPVmt^.vMethodTable);
  if AJitPVmt^.vClassName <> nil then
    Freemem(AJitPVmt^.vClassName);
  {$IFnDEF HasVMTParent}
  if AJitPVmt^.vParentRef<> nil then
    Freemem(AJitPVmt^.vParentRef);
  {$ENDIF}

  Freemem(AJitPVmt);
end;

procedure TJitClassCreator.UpdateClassName;
begin
  Exclude(FFlags, ccfModifiedClassName);
  if Pointer(FJitPVmt^.vClassName) <> nil then
    Freemem(Pointer(FJitPVmt^.vClassName));

  GetMem(Pointer(FJitPVmt^.vClassName), SizeOf(ShortString));
  FJitPVmt^.vClassName^ := FClassName;
end;

procedure TJitClassCreator.CreateJitMethods;
var
  MemSize, StringMemSize, i: integer;
  RttiWriterMethods: TJitRttiWriterVmtMethodTable;
  DummyAddr: PtrUInt;
begin
  Exclude(FFlags, ccfModifiedMethods);
  if FJitPVmt^.vMethodTable <> nil then begin
    Freemem(FJitPVmt^.vMethodTable);
    FJitPVmt^.vMethodTable := nil;
  end;

  if FJitMethods.Count = 0 then
    exit;

  MemSize := TJitRttiWriterVmtMethodTable.NewSizeFor(FJitMethods.Count);
  StringMemSize := 0;
  for i := 0 to FJitMethods.Count - 1 do
    TJitRttiWriterVmtMethodTable.AddSizeForShortStringPtr(StringMemSize, FJitMethods[i].Name);

  MemSize := aligntoptr(MemSize);
  FJitPVmt^.vMethodTable := AllocMem(MemSize + StringMemSize);
  DummyAddr := PtrUInt(FJitPVmt^.vMethodTable);

  RttiWriterMethods := TJitRttiWriterVmtMethodTable.Create(FJitPVmt^.vMethodTable,
    pointer(FJitPVmt^.vMethodTable) + MemSize, JitMethods.Count);

  for i := 0 to FJitMethods.Count - 1 do
    if FJitMethods[i].FCreateDummyCodePointer then begin
      RttiWriterMethods.WriteMethodEntry(FJitMethods[i].Name, CodePointer(DummyAddr));
      inc(DummyAddr);
    end
    else
      RttiWriterMethods.WriteMethodEntry(FJitMethods[i].Name, FJitMethods[i].CodeAddress);

  assert(RttiWriterMethods.CurDestMemPos <= Pointer(FJitPVmt^.vMethodTable)+MemSize, 'TJitClassCreator.CreateJitMethods: RttiWriterMethods.CurDestMemPos <= Pointer(FJitPVmt^.vMethodTable)+MemSize');
  assert(RttiWriterMethods.CurNamesTargetMem <= Pointer(FJitPVmt^.vMethodTable)+MemSize+StringMemSize, 'TJitClassCreator.CreateJitMethods: RttiWriterMethods.CurNamesTargetMem <= Pointer(FJitPVmt^.vMethodTable)+MemSize+StringMemSize');

  RttiWriterMethods.Free;
end;

procedure TJitClassCreator.CreateJitProps;
begin
  Exclude(FFlags, ccfModifiedProps);
  if not (ccfJitPropsPrepareDone in FFlags) then
    CreateJitPropsPrepare;
  CreateJitPropsFinish;
end;

procedure TJitClassCreator.CreateJitPropsPrepare;
type
  TNameIndexMap = specialize TFPGMap<string, integer>;
var
  PropCount, i, idx: integer;
  PropList: PPropList;
  NameIdxMap: TNameIndexMap;
  Itm: TJitProperty;
  NewTypeInfo: Pointer;
  NewPropInfo: PPropInfo;
  VmtParentMem: TypeInfoPtr;
begin
  assert(not (ccfJitPropsPrepareDone in FFlags), 'TJitClassCreator.CreateJitPropsPrepare: not (ccfJitPropsPrepareDone in FFlags)');
  assert(FRttiWriterClass = nil, 'TJitClassCreator.CreateJitPropsPrepare: FRttiWriterClass = nil');
  assert(FJitPVmt^.vTypeInfo = nil, 'TJitClassCreator.CreateJitPropsPrepare: FJitPVmt^.vTypeInfo = nil');
  (* Prepare TypeInfo but do not yet trigger any recursion
     A child class may need Property count *BEFORE* it can create its own typeinfo.
     Therefore no recursion on the child must be triggered.
  *)
  include(FFlags, ccfJitPropsPrepareDone);
  // Get existing properties (parent class)
  PropCount := GetPropList(FAncestorClass, PropList);
  NameIdxMap := TNameIndexMap.Create;
  for i := 0 to PropCount - 1 do
    NameIdxMap.Add(PropList^[i]^.Name, PropList^[i]^.NameIndex);
  if PropCount > 0 then
    Freemem(PropList);
  NameIdxMap.Sorted := True;

  FTypeInfoMemSize := TJitRttiWriterTypeInfo.NewSizeForClass(FClassName, FClassUnit); // already aligned
  FRedirectPtrMemSize := 0;
  For i := 0 to FJitProperties.Count - 1 do begin
    Itm := FJitProperties.Items[i];
    TJitRttiWriterTkClass.AddSizeForProperty(FTypeInfoMemSize, FRedirectPtrMemSize, Itm.Name);
    if NameIdxMap.Find(Itm.Name, idx) then begin
      Itm.FNameIndex := idx; // override/reintroduce name
    end
    else begin
      Itm.FNameIndex := PropCount; // new name (not in any anchestor)
      inc(PropCount);
    end;
  end;
  NameIdxMap.Free;

  {$IFDEF HasVMTParent}
  FVmtParentMemSize := 0;
  {$ELSE}
  FVmtParentMemSize := SizeOf(Pointer);
  {$ENDIF}

  (* vmtTypeInfo = pointer to
        TTypeInfo (Kind, Name)
        TTypeData
        TPropData (PropCount, TPropInfo, TPropInfo, ...) // Size = PropInfoMemSize  *)
  NewTypeInfo := AllocMem(FTypeInfoMemSize
                        + FVmtParentMemSize
                        + FRedirectPtrMemSize);

  FJitPVmt^.vTypeInfo:=NewTypeInfo;
  FJitPVmt^.vInstanceSize  := 0; // not yet ready

  {$IFDEF HasVMTParent}
  VmtParentMem := FAncestorClass.ClassInfo;
  {$ELSE}
  VmtParentMem  := Pointer(NewTypeInfo) + FTypeInfoMemSize;
  VmtParentMem^ :=FAncestorClass.ClassInfo;
  {$ENDIF}

  FRttiWriterClass := TJitRttiWriterTkClass.Create(NewTypeInfo,
    FClassName, FClassUnit, TClass(FJitPVmt), VmtParentMem,
    FJitProperties.Count, PropCount);

  try
    (* Pre-init the properties => if we request the typeinfo of an inherited class
       then all the names must be present *)
    NewPropInfo := FRttiWriterClass.FirstPropInfo;
    For i := 0 to FJitProperties.Count - 1 do begin
      Itm := FJitProperties.Items[i];
      NewPropInfo^.GetProc := nil;
      NewPropInfo^.SetProc := nil;
      NewPropInfo^.StoredProc := nil;
      NewPropInfo^.Index := 0;
      NewPropInfo^.Default := 0;
      NewPropInfo^.PropProcs := 0; // all ptField;
      NewPropInfo^.Name := Itm.Name;
      NewPropInfo^.NameIndex := Itm.FNameIndex;
      // Skip typeinfo => must not yet trigger any recursive types
      NewPropInfo := NewPropInfo^.Next;
    end;
    assert(NewPropInfo <= Pointer(Pointer(NewTypeInfo) + FTypeInfoMemSize), 'TJitClassCreator.CreateJitProps: NewPropInfo <= Pointer(Pointer(NewTypeInfo) + FTypeInfoMemSize)');

    Include(FFlags, ccfContinueAfterVMTNeeded);

    (*    ***** FJitPVmt^.vTypeInfo is set for recursion                *****
          ***** From this point on, we can access any Property.TypeInfo *****
          ***** - Child-Classes can get all, except for vInstanceSize   ***** *)
  except
    FRttiWriterClass.Free;
    raise;
  end
end;

procedure TJitClassCreator.CreateJitPropsFinish;
var
  Itm: TJitProperty;
  i, DSize: Integer;
  ManagedFieldCount, ManagedFieldDataSize: Integer;
  InitTableMemSize: Integer;
  NewPropInfo: PPropInfo;
  NewInitTypeInfo: PTypeInfo;
  RedirectPtrMem: Pointer;
//  RttiWriterClass: TJitRttiWriterTkClass;
  RttiWriterInit: TJitRttiWriterRecInitInfo;
  InstanceDataSize: SizeInt;
begin
  assert(FJitPVmt^.vTypeInfo <> nil, 'TJitClassCreator.CreateJitPropsFinish: FJitPVmt^.vTypeInfo <> nil');
  assert(FRttiWriterClass <> nil, 'TJitClassCreator.CreateJitPropsFinish: FRttiWriterClass <> nil');
  assert(ccfJitPropsPrepareDone in FFlags, 'TJitClassCreator.CreateJitPropsFinish: ccfJitPropsPrepareDone in FFlags');

  exclude(FFlags, ccfJitPropsPrepareDone);
  RttiWriterInit := nil;
  RedirectPtrMem  := Pointer(FJitPVmt^.vTypeInfo) + FTypeInfoMemSize + FVmtParentMemSize;
  try
    ManagedFieldCount := 0;
    ManagedFieldDataSize := 0;
    For i := 0 to FJitProperties.Count - 1 do begin
      Itm := FJitProperties.Items[i];
      (* *****  This triggers any recursions that may be ***** *)
      if Itm.TypeInfo.IsManaged then begin
        inc(ManagedFieldCount);
        inc(ManagedFieldDataSize, Itm.TypeInfo.DataSize);
      end;
    end;
    InitTableMemSize := TJitRttiWriterRecInitInfo.NewSizeForInitTable(FClassName, ManagedFieldCount);

  // TODO: all typeinfos have been triggered: get anchestor.vInstanceSize
  // yet, if we have properties.child_class_of_this => then child_class_of_this goes wrong

    InstanceDataSize := FAncestorClass.InstanceSize;

    NewInitTypeInfo := AllocMem(InitTableMemSize);
    FJitPVmt^.vInitTable := NewInitTypeInfo;
    RttiWriterInit := TJitRttiWriterRecInitInfo.Create(NewInitTypeInfo, FClassName, tkClass,
      ManagedFieldCount, ManagedFieldDataSize);

    NewPropInfo := FRttiWriterClass.FirstPropInfo;
    For i := 0 to FJitProperties.Count - 1 do begin
      Itm := FJitProperties.Items[i];
      RefCountedJitPvmt.AddToList(Itm);
      Itm.FInstanceMemOffset := InstanceDataSize;

      NewPropInfo^.GetProc := {%H-}CodePointer(PtrUInt(InstanceDataSize));
      if Itm.WriteAble then
        NewPropInfo^.SetProc := {%H-}CodePointer(PtrUInt(InstanceDataSize));
      NewPropInfo^.PropTypeRef := PTypeInfoToTypeInfoPtr(Itm.TypeInfo, RedirectPtrMem);

      if Itm.NoDefault then
        NewPropInfo^.Default := JIT_PROP_NO_DEFAULT_VAL
      else
        NewPropInfo^.Default := Itm.DefaultVal;

      NewPropInfo^.StoredProc := {%H-}CodePointer(PtrUInt(( Itm.IsStored)));
      NewPropInfo^.PropProcs := (ptConst shl 4); // IsStored

      if Itm.TypeInfo.IsManaged then
        RttiWriterInit.WriteField(NewPropInfo^.PropTypeRef, InstanceDataSize);

      DSize := Itm.TypeInfo.DataSize;
      {$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
      InstanceDataSize := Align(InstanceDataSize, DSize);
      {$endif FPC_REQUIRES_PROPER_ALIGNMENT}
      InstanceDataSize := InstanceDataSize + DSize;

      NewPropInfo := NewPropInfo^.Next;
    end;

    FJitPVmt^.vInstanceSize  := InstanceDataSize;
    FJitPVmt^.vInstanceSize2 := -InstanceDataSize;

    assert(NewPropInfo <= Pointer(FJitPVmt^.vTypeInfo) + FTypeInfoMemSize, 'TJitClassCreator.CreateJitProps: NewPropInfo <= Pointer(FJitPVmt^.vTypeInfo) + FTypeInfoMemSize');
    assert(RedirectPtrMem <= Pointer(FJitPVmt^.vTypeInfo) + FTypeInfoMemSize + FVmtParentMemSize + FRedirectPtrMemSize, 'TJitClassCreator.CreateJitProps: RedirectPtrMem <= Pointer(FJitPVmt^.vTypeInfo) + FTypeInfoMemSize + FVmtParentMemSize + FRedirectPtrMemSize');
    assert(RttiWriterInit.CurDestMemPos <= Pointer(NewInitTypeInfo) + InitTableMemSize, 'TJitClassCreator.CreateJitProps: RttiWriterInit.CurDestMemPos <= Pointer(NewInitTypeInfo) + InitTableMemSize');

  finally
    FreeAndNil(FRttiWriterClass);
    FreeAndNil(RttiWriterInit);
  end;
end;

function TJitClassCreator.GetTypeInfo: PTypeInfo;
begin
  GetJitClass;
  Result := PTypeInfo(FJitPVmt^.vTypeInfo);
end;

constructor TJitClassCreator.Create(AnAncestorClass: TClass;
  AClassName: String; AClassUnit: String);
begin
  FJitPVmt := nil;
  FJitMethods := TJitMethodList.Create(Self);
  FJitProperties := TJitPropertyList.Create(Self);

  inherited Create;

  FAncestorClass := AnAncestorClass;
  FClassName := AClassName;
  FClassUnit := AClassUnit;
end;

constructor TJitClassCreator.Create(AnAncestorJitClass: TJitClassCreator;
  AClassName: String; AClassUnit: String);
begin
  Create(TClass(nil), AClassName, AClassUnit);
  FAncestorJitClass := AnAncestorJitClass;
  if FAncestorJitClass <> nil then
    FAncestorJitClass.AddFreeNotification(@DoAnchesterJitClassFreed);
end;

destructor TJitClassCreator.Destroy;
begin
  inherited Destroy;
  if FRefCountedJitPVmt <> nil then
    FRefCountedJitPVmt.ReleaseLock
  else
    FreeJitClass(FJitPVmt);

  if FTypeLibrary <> nil then
    FTypeLibrary.RemoveFreeNotification(@DoTypeLibFreed);

  FJitMethods.Free;
  FJitProperties.Free;
  if FAncestorJitClass <> nil then
    FAncestorJitClass.RemoveFreeNotification(@DoAnchesterJitClassFreed);
end;

procedure TJitClassCreator.UpdateJitClass;
begin
  if not Assigned(FJitPVmt) then begin
    CreateJitClass;
    exit;
  end;

  if ccfModifiedMethods in FFlags then
    CreateJitMethods;
  if ccfModifiedClassName in FFlags then
    UpdateClassName;
end;

procedure TJitClassCreator.RecreateJitClass;
begin
  FFlags := [];
  SetJitPVmt(nil);
end;

end.


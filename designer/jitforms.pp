{
 ***************************************************************************
 *                                                                         *
 *   This source is free software; you can redistribute it and/or modify   *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This code is distributed in the hope that it will be useful, but      *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   General Public License for more details.                              *
 *                                                                         *
 *   A copy of the GNU General Public License is available on the World    *
 *   Wide Web at <http://www.gnu.org/copyleft/gpl.html>. You can also      *
 *   obtain it by writing to the Free Software Foundation,                 *
 *   Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.   *
 *                                                                         *
 ***************************************************************************
 
  Author: Mattias Gaertner

  Abstract:
    This unit defines a list of forms descendents. The forms are normal TCustomForm
    descendents with one exception: Every form has its own class. These classes
    are changeable at runtime, so that IDEs can add, remove or rename methods
    and such stuff. Also these forms can be loaded from streams and missing
    components and methods are added just-in-time to the class definition.
    Hence the name for the class: TJITForms.
}
unit JITForms;

{$mode objfpc}{$H+}

{$I ide.inc}

{$IF FPC_FULLVERSION<30100}
  {$DEFINE HasVMTParent}
{$ENDIF}

{ $DEFINE VerboseJITForms}

interface

uses
  {$IFDEF IDE_MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, TypInfo, Laz_AVL_Tree,
  // LCL
  Forms, Controls, Dialogs, LResources, LCLMemManager, LCLProc,
  //LazUtils
  AvgLvlTree, LazUtilities, LazLoggerBase, LazTracer,
  // CodeTools
  BasicCodeTools,
  // IdeIntf
  PackageDependencyIntf, PropEditUtils, PropEdits, UnitResources, IDEDialogs,
  // IDE
  {$IFDEF VerboseJITForms}DesignerProcs,{$ENDIF}
  PackageDefs, Project, EnvironmentOpts;

type
  //----------------------------------------------------------------------------
  TJITFormError = (
      jfeNone,
      jfeUnknown,
      jfeUnknownProperty,
      jfeUnknownComponentClass,
      jfeReaderError
    );
  TJITFormErrors = set of TJITFormError;
  
  TJITReaderErrorEvent = procedure(Sender: TObject; Reader: TReader;
                                   ErrorType: TJITFormError;
                                   var Action: TModalResult) of object;
  TJITBeforeCreateEvent = procedure(Sender: TObject; Instance: TPersistent) of object;
  TJITExceptionEvent = procedure(Sender: TObject; E: Exception;
                                 var Action: TModalResult) of object;
  TJITPropertyNotFoundEvent = procedure(Sender: TObject; Reader: TReader;
                   Instance: TPersistent; var PropName: string; IsPath: boolean;
                   var Handled, Skip: Boolean) of object;
  TJITFindAncestors = procedure(Sender: TObject; AClass: TClass;
                                var Ancestors: TFPList;// list of TComponent
                                var BinStreams: TFPList;// list of TExtMemoryStream;
                                var Abort: boolean) of object;
  TJITFindClass = procedure(Sender: TObject;
                            const ComponentClassName: string;
                            var ComponentClass: TComponentClass) of object;


  { TJITComponentList }
  
  TJITCompListFlag = (
    jclAutoRenameComponents
    );
  TJITCompListFlags = set of TJITCompListFlag;

  TJITComponentList = class(TComponent)
  private
    FContextObject: TObject;
    FCurUnknownClass: string;
    FCurUnknownProperty: string;
    FErrors: TLRPositionLinks;
    FOnBeforeCreate: TJITBeforeCreateEvent;
    FOnException: TJITExceptionEvent;
    FOnFindAncestors: TJITFindAncestors;
    FOnFindClass: TJITFindClass;
    FOnPropertyNotFound: TJITPropertyNotFoundEvent;
  protected
    FCurReadErrorMsg: string;
    FCurReadJITComponent: TComponent;
    FCurReadClass: TClass;
    FCurReadChild: TComponent;
    FCurReadChildClass: TComponentClass;
    FCurReadStreamClass: TClass;
    FOnReaderError: TJITReaderErrorEvent;
    FJITComponents: TFPList;
    FFlags: TJITCompListFlags;
    fRenameList: TStringToStringTree;
    fReadComponents: TFPList;
    procedure Notification(AComponent: TComponent; Operation: TOperation);
         override;

    // jit procedures
    function CreateNewJITClass(AncestorClass: TClass;
                          const NewClassName, NewUnitName: ShortString): TClass;
    procedure FreeJITClass(var AClass: TClass);
    procedure DoAddNewMethod(JITClass: TClass; const AName: ShortString;
      ACode: Pointer); // Note: AddNewMethod does not check if method already exists
    procedure DoRemoveMethod(JITClass: TClass; AName: ShortString;
      var OldCode: Pointer); // Note: RemoveMethod does not free code memory
    procedure DoRenameMethod(JITClass: TClass; OldName, NewName: ShortString);
    procedure DoRenameClass(JITClass: TClass; const NewName: ShortString);
    procedure DoRenameUnitNameOfClass(JITClass: TClass;
                                      const NewUnitName: ShortString);
    // TReader events
    procedure ReaderFindMethod({%H-}Reader: TReader; const {%H-}FindMethodName: Ansistring;
      var {%H-}Address: Pointer; var {%H-}Error: Boolean);
    procedure ReaderSetMethodProperty(Reader: TReader; Instance: TPersistent;
      PropInfo: PPropInfo; const TheMethodName: string; var Handled: boolean);
    procedure ReaderPropertyNotFound(Reader: TReader; Instance: TPersistent;
      var PropName: string; IsPath: Boolean; var Handled, Skip: Boolean);
    procedure ReaderSetName({%H-}Reader: TReader; {%H-}Component: TComponent;
      var NewName: Ansistring);
    procedure ReaderReferenceName({%H-}Reader: TReader; var RefName: Ansistring);
    procedure ReaderAncestorNotFound({%H-}Reader: TReader;
      const ComponentName: Ansistring; ComponentClass: TPersistentClass;
      var Component: TComponent);
    procedure ReaderError(Reader: TReader; const ErrorMsg: Ansistring;
      var Handled: Boolean);
    procedure ReaderFindComponentClass({%H-}Reader: TReader;
      const FindClassName: Ansistring; var ComponentClass: TComponentClass);
    procedure ReaderCreateComponent(Reader: TReader;
      ComponentClass: TComponentClass; var Component: TComponent);
    procedure ReaderReadComponent(Component: TComponent);
    procedure ReadComponentsProc(AComponent: TComponent);

    // some useful functions
    function GetItem(Index:integer):TComponent;
    function OnFindGlobalComponent(const {%H-}AName:AnsiString):TComponent;
    procedure InitReading;
    procedure CreateReader(BinStream: TStream;
                           UnitResourcefileFormat: TUnitResourcefileFormatClass;
                           var Reader: TReader;
                           DestroyDriver: Boolean); virtual;
    function DoCreateJITComponent(const NewComponentName, NewClassName,
                         NewUnitName: shortstring; AncestorClass: TClass;
                         Visible, DisableAutoSize: boolean):integer;
    procedure ReadInlineComponent(var Component: TComponent;
                         ComponentClass: TComponentClass; NewOwner: TComponent);
    procedure DoFinishReading; virtual;
    procedure HandleException(E: Exception; const Context: string;
                              out Action: TModalResult);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property Items[Index: integer]: TComponent read GetItem; default;
    function Count: integer;
    function AddNewJITComponent(const NewUnitName: shortstring;
                                AncestorClass: TClass;
                                DisableAutoSize: boolean): integer;
    function AddJITComponentFromStream(BinStream: TStream;
                                UnitResourcefileFormat: TUnitResourcefileFormatClass;
                                AncestorClass: TClass;
                                const NewUnitName: ShortString;
                                {%H-}Interactive, Visible, DisableAutoSize: Boolean;
                                ContextObj: TObject): integer;
    procedure DestroyJITComponent(JITComponent: TComponent);
    procedure DestroyJITComponent(Index: integer);
    function IndexOf(JITComponent: TComponent): integer;
    function Contains(JITComponent: TComponent): boolean;
    function FindComponentByClassName(const AClassName: shortstring): integer;
    function FindComponentByClass(AClass: TComponentClass): integer;
    function FindComponentByName(const AName: shortstring): integer;
    procedure GetUnusedNames(out ComponentName: shortstring; var ComponentClassName: shortstring);
    function CreateNewMethod(JITComponent: TComponent;
                             const AName: ShortString): TMethod;
    procedure RemoveMethod(JITComponent: TComponent; const AName: ShortString);
    procedure RenameMethod(JITComponent: TComponent;
                           const OldName, NewName: ShortString);
    procedure RenameComponentClass(JITComponent: TComponent;
                                   const NewName: ShortString);
    procedure RenameComponentUnitname(JITComponent: TComponent;
                                      const NewUnitName: ShortString);
    // child components
    procedure AddJITChildComponentsFromStream(JITOwnerComponent: TComponent;
                            BinStream: TStream; ComponentClass: TComponentClass;
                            ParentControl: TWinControl; NewComponents: TFPList);
    procedure ReadInlineJITChildComponent(Component: TComponent);
  public
    property OnReaderError: TJITReaderErrorEvent
                                       read FOnReaderError write FOnReaderError;
    property OnPropertyNotFound: TJITPropertyNotFoundEvent
                             read FOnPropertyNotFound write FOnPropertyNotFound;
    property OnException: TJITExceptionEvent read FOnException write FOnException;
    property OnBeforeCreate: TJITBeforeCreateEvent read FOnBeforeCreate write FOnBeforeCreate;
    property OnFindAncestors: TJITFindAncestors read FOnFindAncestors
                                                write FOnFindAncestors;
    property OnFindClass: TJITFindClass read FOnFindClass write FOnFindClass;
    property CurReadJITComponent: TComponent read FCurReadJITComponent;
    property CurReadClass: TClass read FCurReadClass;
    property CurReadStreamClass: TClass read FCurReadStreamClass;
    property CurReadChild: TComponent read FCurReadChild;
    property CurReadChildClass: TComponentClass read FCurReadChildClass;
    property CurReadErrorMsg: string read FCurReadErrorMsg;
    property CurUnknownProperty: string read FCurUnknownProperty;
    property CurUnknownClass: string read FCurUnknownClass;
    property ContextObject: TObject read FContextObject;
    property Errors: TLRPositionLinks read FErrors;
  end;


  { TJITForms }
  
  TJITForms = class(TJITComponentList)
  private
    function GetItem(Index: integer): TCustomForm;
  public
    function IsJITForm(AComponent: TComponent): boolean;
    property Items[Index:integer]: TCustomForm read GetItem; default;
  end;
  
  
  { TJITNonFormComponents }
  
  TJITNonFormComponents = class(TJITComponentList)
  public
    function IsJITNonForm(AComponent: TComponent): boolean;
  end;


  TJITMethods = class;

  { TJITMethod }

  TJITMethod = class
  private
    FMethod: TMethod;
    FOwner: TJITMethods;
    FTheClass: TClass;
    FTheMethodName: shortstring;
  public
    constructor Create(AnOwner: TJITMethods; aClass: TClass;
                       const aMethodName: shortstring);
    destructor Destroy; override;
    property Method: TMethod read FMethod;
    property TheClass: TClass read FTheClass;
    property TheMethodName: shortstring read FTheMethodName;
    property Owner: TJITMethods read FOwner;
  end;
  
  
  { TJITMethods }

  TJITMethods = class
  private
    fClearing: boolean;
    fMethods: TAvlTree; // sorted with CompareJITMethod
    procedure InternalAdd(const AMethod: TJITMethod);
    procedure InternalRemove(const AMethod: TJITMethod);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Add(aClass: TClass; const aMethodName: shortstring): TJITMethod;
    function Find(aClass: TClass; const aMethodName: shortstring): TJITMethod;
    function Delete(aMethod: TJITMethod): boolean;
    function Delete(aClass: TClass; const aMethodName: shortstring): boolean;
    procedure DeleteAllOfClass(aClass: TClass);
    function Rename(aClass: TClass;
                    const OldMethodName, NewMethodName: shortstring): boolean;
  end;
  
function IsJITMethod(const aMethod: TMethod): boolean;
function GetJITMethod(const aMethod: TMethod; out aJITMethod: TJITMethod): boolean;
function CompareJITMethod(Data1, Data2: Pointer): integer;

var
  JITMethods: TJITMethods = nil;


function ClassAsString(AClass: TClass): string;
function ClassMethodTableAsString(AClass: TClass): string;
function ClassTypeInfoAsString(AClass: TClass): string;
function ClassFieldTableAsString(AClass: TClass): string;

function CalculateTypeDataSize(PropInfoCount: integer): integer;
function CalculateTypeInfoSize(const AClassName: shortstring;
                               PropInfoCount: integer): integer;
function GetTypeDataPropCountAddr(TypeData: PTypeData): PWord;

const
  DefaultJITUnitName = 'VirtualUnitForJITClasses';

procedure SetComponentDesignMode(AComponent: TComponent; Value: Boolean);
procedure SetComponentDesignInstanceMode(AComponent: TComponent; Value: Boolean);
procedure SetComponentInlineMode(AComponent: TComponent; Value: Boolean);
procedure SetComponentAncestorMode(AComponent: TComponent; Value: Boolean);

implementation

{$IFOPT R+}{$DEFINE RangeCheckOn}{$ENDIF}

// Define a dummy component to set the csDesigning, csDesignInstance, csInline flags which
// can not be set by a TForm, because SetDesigning, SetDesignInstance and SetInline are protected.
type
  TSetDesigningComponent = class(TComponent)
  public
    class procedure SetDesigningOfComponent(AComponent: TComponent; Value: Boolean);
    class procedure SetDesignInstanceOfComponent(AComponent: TComponent; Value: Boolean);
    class procedure SetInlineOfComponent(AComponent: TComponent; Value: Boolean);
  end;

procedure SetComponentDesignMode(AComponent: TComponent; Value: Boolean);
begin
  TSetDesigningComponent.SetDesigningOfComponent(AComponent, Value);
end;

procedure SetComponentDesignInstanceMode(AComponent: TComponent; Value: Boolean);
begin
  TSetDesigningComponent.SetDesignInstanceOfComponent(AComponent, Value);
end;

procedure SetComponentInlineMode(AComponent: TComponent; Value: Boolean);
begin
  TSetDesigningComponent.SetInlineOfComponent(AComponent, Value);
end;

procedure SetComponentAncestorMode(AComponent: TComponent; Value: Boolean);
begin
  TSetDesigningComponent(AComponent).SetAncestor(Value);
end;

class procedure TSetDesigningComponent.SetDesigningOfComponent(
  AComponent: TComponent; Value: Boolean);
begin
  TSetDesigningComponent(AComponent).SetDesigning(Value);
end;

class procedure TSetDesigningComponent.SetDesignInstanceOfComponent(
  AComponent: TComponent; Value: Boolean);
begin
  // requires fpc >= 2.2.1
  TSetDesigningComponent(AComponent).SetDesignInstance(Value);
end;

class procedure TSetDesigningComponent.SetInlineOfComponent(
  AComponent: TComponent; Value: Boolean);
begin
  // requires fpc >= 2.2.1
  TSetDesigningComponent(AComponent).SetInline(Value);
end;

//------------------------------------------------------------------------------
// adding, removing and renaming of classes and methods at runtime

const
  vmtInstanceSizeNeg = vmtInstanceSize+sizeof(ptrint);

type
  // these definitions are copied from typinfo.pp

  TMethodNameRec = packed record
    Name : PShortString;
    Addr : Pointer;
  end;

  TMethodNameTable = packed record
    Count : DWord;
    // for runtime range checking it is important to give a range
    Entries : packed array[0..1000000] of TMethodNameRec;
  end;
  PMethodNameTable =  ^TMethodNameTable;

  PFieldClassTable = ^TFieldClassTable;
  TFieldClassTable = 
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
  packed
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  record  
    Count: Word;
    Entries: array[Word] of TPersistentClass;
  end;

  PFieldInfo = ^TFieldInfo;
  TFieldInfo = 
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
  packed
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  record  
    FieldOffset: PtrUInt;
    ClassTypeIndex: Word;
    Name: ShortString;
  end;

  PFieldTable = ^TFieldTable;
  TFieldTable = 
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
  packed
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  record  
    FieldCount: Word;
    ClassTable: PFieldClassTable;
    { should be array[Word] of TFieldinfo;  but Elements have variant size! force at least proper alignment }
    Fields: array[0..0] of TFieldInfo;
  end;

function GetVMTSize(AClass: TClass): integer;
var
  p: PPointer;
begin
  Result:=100000;
  if AClass=nil then exit;
  Result:=vmtMethodStart;
  p:=PPointer(pointer(AClass)+Result);
  while (p^<>nil) and (Result<100000) do begin
    inc(p);
    inc(Result,SizeOf(Pointer));
  end;
end;

function FindVMTMethodOffset(AClass: TClass; MethodPointer: Pointer): integer;
var
  i: Integer;
  p: Pointer;
begin
  i:=vmtMethodStart div SizeOf(Pointer);
  while i<=10000 do begin
    p:=PPointer(pointer(AClass))[i];
    if p=nil then break;
    if p=MethodPointer then begin
      Result:=i*SizeOf(Pointer);
      exit;
    end;
    inc(i);
  end;
  Result:=0;
end;

function GetVMTVirtualMethodOffset(
  ParentClassWithVirtualMethod: TClass; MethodOfParentClass: Pointer;
  ClassWithOverrideMethod: TClass; OverrideMethodOfClass: Pointer
  ): integer;
var
  ParentMethodOffset: LongInt;
  OverrideMethodOffset: LongInt;
begin
  ParentMethodOffset:=FindVMTMethodOffset(
                              ParentClassWithVirtualMethod,MethodOfParentClass);
  if ParentMethodOffset<=0 then
    raise Exception.Create('GetVMTVirtualMethodOffset Parent Virtual Method not found');
  OverrideMethodOffset:=FindVMTMethodOffset(
                                 ClassWithOverrideMethod,OverrideMethodOfClass);
  if OverrideMethodOffset<=0 then
    raise Exception.Create('GetVMTVirtualMethodOffset Override Method not found');
  if ParentMethodOffset<>OverrideMethodOffset then
    raise Exception.Create('GetVMTVirtualMethodOffset Virtual Method Offset <> Override Method Offset');
  Result:=OverrideMethodOffset;
end;

{ TComponentWithOverrideValidateRename }
type
  TComponentWithOverrideValidateRename = class(TComponent)
  public
    procedure ValidateRename(AComponent: TComponent;
      const CurName, NewName: string); override;
  end;

var
  TComponentValidateRenameOffset: LongInt = 0;

procedure TComponentWithOverrideValidateRename.ValidateRename(
  AComponent: TComponent; const CurName, NewName: string);
var
  Designer: TIDesigner;
begin
  //debugln(['TComponentWithOverrideValidateRename.ValidateRename ',DbgSName(Self),
  //         ' ',DbgSName(AComponent),' CurName=',CurName,' NewName=',NewName]);
  inherited ValidateRename(AComponent, CurName, NewName);
  Designer:=FindRootDesigner(Self);
  if Designer <> nil then
    Designer.ValidateRename(AComponent, CurName, NewName);
end;


function GetTComponentValidateRenameVMTOffset: integer;
begin
  Result:=GetVMTVirtualMethodOffset(TComponent,
    @TComponent.ValidateRename,
    TComponentWithOverrideValidateRename,
    @TComponentWithOverrideValidateRename.ValidateRename);
end;

var
  MyFindGlobalComponentProc: function(const AName: AnsiString): TComponent of object;

function MyFindGlobalComponent(const AName: AnsiString): TComponent;
begin
  Result:=MyFindGlobalComponentProc(AName);
end;

function IsJITMethod(const aMethod: TMethod): boolean;
begin
  Result:=(aMethod.Data<>nil) and (aMethod.Code=nil)
      and (TObject(aMethod.Data).ClassType=TJITMethod);
end;

function ClassAsString(AClass: TClass): string;
var
  ParentClass: TClass;
begin
  Result:='Class='+DbgS(AClass);
  if AClass=nil then exit;
  Result:=Result+' Name="'+AClass.ClassName+'"';
  ParentClass:=AClass.ClassParent;
  if ParentClass<>nil then
    Result:=Result+' Parent='+DbgS(ParentClass)+'-"'+ParentClass.ClassName+'"';
  Result:=Result+LineEnding;
  Result:=Result+' vmtInstanceSize='+IntToStr(PLongInt(pointer(AClass)+vmtInstanceSize)^);
  Result:=Result+' vmtInstanceSizeNeg='+IntToStr(PLongInt(pointer(AClass)+vmtInstanceSizeNeg)^);
  Result:=Result+' vmtParent='+DbgS(pcardinal(pointer(AClass)+vmtParent)^);
  Result:=Result+' vmtClassName="'+PShortString((Pointer(AClass)+vmtClassName)^)^+'"';
  Result:=Result+' vmtDynamicTable='+DbgS(pcardinal(pointer(AClass)+vmtDynamicTable)^);
  Result:=Result+' vmtMethodTable='+DbgS(pcardinal(pointer(AClass)+vmtMethodTable)^);
  Result:=Result+' vmtFieldTable='+DbgS(pcardinal(pointer(AClass)+vmtFieldTable)^);
  Result:=Result+' vmtTypeInfo='+DbgS(pcardinal(pointer(AClass)+vmtTypeInfo)^);
  Result:=Result+' vmtInitTable='+DbgS(pcardinal(pointer(AClass)+vmtInitTable)^);
  Result:=Result+' vmtAutoTable='+DbgS(pcardinal(pointer(AClass)+vmtAutoTable)^);
  Result:=Result+' vmtIntfTable='+DbgS(pcardinal(pointer(AClass)+vmtIntfTable)^);
  Result:=Result+' vmtMsgStrPtr='+DbgS(pcardinal(pointer(AClass)+vmtMsgStrPtr)^);
  Result:=Result+LineEnding;
  Result:=Result+' MethodTable=['+ClassMethodTableAsString(AClass)+']';
  Result:=Result+LineEnding;
  Result:=Result+' TypeInfo=['+ClassTypeInfoAsString(AClass)+']';
  Result:=Result+LineEnding;
  Result:=Result+' FieldTable=['+ClassFieldTableAsString(AClass)+']';
end;

function ClassMethodTableAsString(AClass: TClass): string;
var
  MethodTable: PMethodNameTable;
  i: Integer;
begin
  Result:='';
  if AClass=nil then exit;
  MethodTable:=PMethodNameTable((Pointer(AClass)+vmtMethodTable)^);
  if MethodTable=nil then exit;
  for i:=0 to MethodTable^.Count-1 do begin
    if i>0 then Result:=Result+',';
    Result:=Result+IntToStr(i)+':"'+(MethodTable^.Entries[i].Name^)+'"'
      +':'+DbgS(MethodTable^.Entries[i].Addr);
  end;
end;

function ClassTypeInfoAsString(AClass: TClass): string;
var
  TypeInfo: PTypeInfo;
  TypeData: PTypeData;
  PropInfo: PPropInfo;
  PropList: PPropList;
  CurCount: integer;
  i: Integer;
begin
  Result:='';
  if AClass=nil then exit;
  TypeInfo:=AClass.ClassInfo;
  if TypeInfo=nil then exit;
  Result:=Result+'ClassInfo^.Name="'+TypeInfo^.Name+'"';
  // read all property infos of current class
  TypeData:=GetTypeData(TypeInfo);
  if TypeData=nil then exit;
  Result:=Result+' ClassType='+DbgS(TypeData^.ClassType);
  if TypeData^.ClassType<>AClass then
    Result:=Result+LineEnding
      +' WARNING: ClassType<>AClass('+DbgS(AClass)+')'+LineEnding;
  Result:=Result+' ParentInfo='+DbgS(TypeData^.ParentInfo);
  if (AClass.ClassParent<>nil)
  and (TypeData^.ParentInfo<>AClass.ClassParent.ClassInfo) then
    Result:=Result+LineEnding
      +' WARNING: TypeData^.ParentInfo<>AClass.ClassParent.ClassInfo('
      +DbgS(TypeData^.ParentInfo)+'<>'
      +DbgS(AClass.ClassParent.ClassInfo)+'<>'+')'+LineEnding;
  Result:=Result+' PropCount='+IntToStr(TypeData^.PropCount);
  Result:=Result+' UnitName="'+TypeData^.UnitName+'"';

  // read property count
  CurCount:=GetPropList(TypeInfo,PropList);;
  Result:=Result+' CurPropCnt='+IntToStr(CurCount);

  // read properties
  Result:=Result+' Properties={';
  for i:=0 to CurCount-1 do begin
    PropInfo:=PropList^[i];
    if i>0 then Result:=Result+',';
    // point PropInfo to next propinfo record.
    // Located at Name[Length(Name)+1] !
    Result:=Result+IntToStr(i)+':PropName="'+PropInfo^.Name+'"'
                  +':Type="'+PropInfo^.PropType^.Name+'"';
  end;
  FreeMem(PropList);
  Result:=Result+'}';
end;

function ClassFieldTableAsString(AClass: TClass): string;
var
  FieldTable: PFieldTable;
  FieldInfo: PFieldInfo;
  i: Integer;
  ClassTable: PFieldClassTable;
begin
  Result:='';
  if AClass=nil then exit;
  FieldTable:=PFieldTable((Pointer(AClass)+vmtFieldTable)^);
  if FieldTable=nil then exit;
  Result:=Result+'FieldCount='+IntToStr(FieldTable^.FieldCount);
  ClassTable:=FieldTable^.ClassTable;
  Result:=Result+' ClassTable='+DbgS(ClassTable);
  if ClassTable<>nil then begin
    Result:=Result+'={';
    for i:=0 to ClassTable^.Count-1 do begin
      if i>0 then Result:=Result+',';
      Result:=Result+IntToStr(i)+':Name="'+ClassTable^.Entries[i].ClassName+'"';
    end;
  end;
  Result:=Result+'}';
  FieldInfo := @FieldTable^.Fields[0];
  Result := Result + ' Fields={';
  for i := 0 to FieldTable^.FieldCount-1 do begin
    if i > 0 then Result:=Result+',';
    Result := Result + IntToStr(i) 
      + ':Name="' + FieldInfo^.Name + '"'
      + ':Offset=' +IntToStr(FieldInfo^.FieldOffset);
    FieldInfo := PFieldInfo(PByte(@FieldInfo^.Name) + 1 + Length(FieldInfo^.Name));
    {$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
    FieldInfo := Align(FieldInfo, SizeOf(Pointer));
    {$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  end;
  Result := Result+'}';
end;

function GetJITMethod(const aMethod: TMethod; out aJITMethod: TJITMethod
  ): boolean;
begin
  if IsJITMethod(aMethod) then begin
    Result:=true;
    aJITMethod:=TJITMethod(aMethod.Data);
  end else begin
    Result:=false;
    aJITMethod:=nil;
  end;
end;

function CompareJITMethod(Data1, Data2: Pointer): integer;
var
  JITMethod1: TJITMethod absolute Data1;
  JITMethod2: TJITMethod absolute Data2;
begin
  Result:=ComparePointers(JITMethod1.TheClass,JITMethod2.TheClass);
  if Result<>0 then exit;
  Result:=CompareText(JITMethod1.TheMethodName,JITMethod2.TheMethodName);
end;

function CalculateTypeDataSize(PropInfoCount: integer): integer;
begin
  Result := SizeOf(TTypeData) + 2; // TTypeData + one word for new prop count
  // Actually the size depends on the UnitName. But SizeOf(TTypeData) already
  // uses the maximum size of the shortstring.
  {$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
  if Result and (SizeOf(Pointer) - 1) <> 0 then
    Inc(Result, SizeOf(Pointer)); // a few bytes too much, but at least enough
  {$endif}
  inc(Result,PropInfoCount*SizeOf(TPropInfo));
end;

function CalculateTypeInfoSize(const AClassName: shortstring;
  PropInfoCount: integer): integer;
begin
  Result := SizeOf(TTypeKind)
           + 1 + length(AClassName)  // packed shortstring: length byte + chars
           + CalculateTypeDataSize(PropInfoCount);
  {$push}
  {$warnings off}
  if SizeOf(TTypeKind)<>1 then
    raise Exception.Create('CalculateTypeInfoSize SizeOf(TTypeInfo^.Kind)<>1');
  {$pop}
end;

function GetTypeDataPropCountAddr(TypeData: PTypeData): PWord;
begin
  Result:=PWord(PByte(@TypeData^.UnitName)+Length(TypeData^.UnitName)+1);
  {$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
  Result := Align(Result, SizeOf(Pointer));
  {$endif}
end;

//------------------------------------------------------------------------------


{ TJITComponentList }

constructor TJITComponentList.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FJITComponents:=TFPList.Create;
  FErrors:=TLRPositionLinks.Create;
  fRenameList:=TStringToStringTree.Create(false);
end;

destructor TJITComponentList.Destroy;
begin
  while FJITComponents.Count>0 do DestroyJITComponent(FJITComponents.Count-1);
  FreeAndNil(fRenameList);
  FreeAndNil(FJITComponents);
  FreeAndNil(FErrors);
  inherited Destroy;
end;

function TJITComponentList.GetItem(Index:integer):TComponent;
begin
  Result:=TComponent(FJITComponents[Index]);
end;

function TJITComponentList.Count:integer;
begin
  Result:=FJITComponents.Count;
end;

function TJITComponentList.IndexOf(JITComponent:TComponent):integer;
begin
  Result:=Count-1;
  while (Result>=0) and (Items[Result]<>JITComponent) do dec(Result);
end;

function TJITComponentList.Contains(JITComponent: TComponent): boolean;
begin
  Result:=IndexOf(JITComponent)>=0;
end;

procedure TJITComponentList.DestroyJITComponent(JITComponent:TComponent);
var a:integer;
begin
  if JITComponent=nil then
    RaiseGDBException('TJITComponentList.DestroyJITForm JITComponent=nil');
  a:=IndexOf(JITComponent);
  if a<0 then
    RaiseGDBException('TJITComponentList.DestroyJITForm JITComponent.ClassName='+
      JITComponent.ClassName);
  if a>=0 then DestroyJITComponent(a);
end;

procedure TJITComponentList.DestroyJITComponent(Index:integer);
var
  OldClass: TClass;
  Action: TModalResult;
  AComponent: TComponent;
begin
  AComponent:=Items[Index];
  OldClass:=AComponent.ClassType;
  try
    AComponent.Free;
  except
    on E: Exception do begin
      HandleException(E,'[TJITComponentList.DestroyJITComponent] ERROR destroying component',Action);
    end;
  end;
  FJITComponents.Remove(AComponent);
  FreeJITClass(OldClass);
end;

function TJITComponentList.FindComponentByClassName(
  const AClassName:shortstring):integer;
begin
  Result:=FJITComponents.Count-1;
  while (Result>=0)
  and (CompareText(Items[Result].ClassName,AClassName)<>0) do
    dec(Result);
end;

function TJITComponentList.FindComponentByClass(AClass: TComponentClass
  ): integer;
begin
  Result:=FJITComponents.Count-1;
  while (Result>=0) and (Items[Result].ClassType<>AClass) do
    dec(Result);
end;

function TJITComponentList.FindComponentByName(const AName:shortstring):integer;
begin
  Result:=FJITComponents.Count-1;
  while (Result>=0)
  and (CompareText(Items[Result].Name,AName)<>0) do
    dec(Result);
end;

procedure TJITComponentList.GetUnusedNames(out ComponentName: shortstring;
  var ComponentClassName: shortstring);
var a:integer;
  ComponentPrefix: String;
begin
  a:=1;
  ComponentPrefix:=ComponentClassName;
  if ComponentPrefix='' then
    ComponentPrefix:='Component';
  ComponentPrefix:=ClassNameToComponentName(ComponentPrefix);
  repeat
    ComponentName:=ComponentPrefix+IntToStr(a);
    ComponentClassName:='T'+ComponentName;
    inc(a);
  until (FindComponentByName(ComponentName)<0)
        and (FindComponentByClassName(ComponentClassName)<0);
end;

function TJITComponentList.AddNewJITComponent(const NewUnitName: shortstring;
  AncestorClass: TClass; DisableAutoSize: boolean): integer;
var
  NewComponentName, NewClassName: shortstring;
begin
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList] AddNewJITComponent');
  {$ENDIF}
  NewClassName:=AncestorClass.ClassName;
  GetUnusedNames(NewComponentName,NewClassName);
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.AddNewJITComponent NewComponentName=',NewComponentName,' NewClassName=',NewClassName,
    ' NewUnitName=',NewUnitName,' AncestorClass=',AncestorClass.ClassName);
  {$ENDIF}
  Result:=DoCreateJITComponent(NewComponentName,NewClassName,NewUnitName,
                               AncestorClass,true,DisableAutoSize);
end;

function TJITComponentList.AddJITComponentFromStream(BinStream: TStream;
  UnitResourcefileFormat: TUnitResourcefileFormatClass;
  AncestorClass: TClass;
  const NewUnitName: ShortString;
  Interactive, Visible, DisableAutoSize: Boolean;
  ContextObj: TObject): integer;
//  returns new index
// -1 = invalid stream

  procedure ReadStream(AStream: TStream; StreamClass: TClass);
  var
    Reader: TReader;
    DestroyDriver: Boolean;
  begin
    {$IFDEF VerboseJITForms}
    debugln('[TJITComponentList.AddJITComponentFromStream] InitReading ...');
    {$ENDIF}
    FCurReadStreamClass:=StreamClass;
    DestroyDriver:=false;
    InitReading;
    Reader:=nil;
    CreateReader(AStream,UnitResourcefileFormat,Reader,DestroyDriver);
    {$IFDEF VerboseJITForms}
    DebugLn(['TJITComponentList.AddJITComponentFromStream.ReadStream: FCurReadJITComponent=',
             DbgSName(FCurReadJITComponent), ', StreamClass=',DbgSName(StreamClass)]);
    {$ENDIF}
    try
      Reader.ReadRootComponent(FCurReadJITComponent);
      {$IFDEF VerboseJITForms}
      debugln('[TJITComponentList.AddJITComponentFromStream] Finish Reading ...');
      {$ENDIF}
      DoFinishReading;
    finally
      UnregisterFindGlobalComponentProc(@MyFindGlobalComponent);
      Application.FindGlobalComponentEnabled:=true;
      if DestroyDriver then Reader.Driver.Free;
      Reader.Free;
    end;
    FCurReadStreamClass:=nil;
  end;
  
  function ReadAncestorStreams: boolean;
  var
    i: Integer;
    Ancestors: TFPList;
    AncestorStreams: TFPList;
    Abort: boolean;
  begin
    if not Assigned(OnFindAncestors) then exit(true);
    {$IFDEF VerboseJITForms}
    DebugLn(['[TJITComponentList.AddJITComponentFromStream.ReadAncestorStreams] ',AncestorClass.ClassName]);
    {$ENDIF}
    Ancestors:=nil;
    AncestorStreams:=nil;
    try
      Abort:=false;
      OnFindAncestors(Self,AncestorClass,Ancestors,AncestorStreams,Abort);
      if Abort then exit(false);
      if (Ancestors<>nil) and (Ancestors.Count>0) then begin
        for i:=Ancestors.Count-1 downto 0 do begin
          ReadStream(TExtMemoryStream(AncestorStreams[i]),
                     TComponent(Ancestors[i]).ClassType);
        end;
        SetComponentAncestorMode(FCurReadJITComponent,true);
      end;
    finally
      Ancestors.Free;
      if AncestorStreams<>nil then
        for i:=0 to AncestorStreams.Count-1 do
          TObject(AncestorStreams[i]).Free;
      AncestorStreams.Free;
    end;
  end;

var
  NewClassName: shortstring;
  NewName: string;
  IsInherited: Boolean;
  Action: TModalResult;
  OldSetCaption: boolean;
  AControl: TControl;
begin
  Result:=-1;
  FContextObject:=ContextObj;
  NewClassName:=UnitResourcefileFormat.GetClassNameFromStream(BinStream,IsInherited);
  if IsInherited then ;
  if NewClassName='' then begin
    IDEMessageDialog('Error','No classname in stream found.',mtError,[mbOK]);
    FContextObject:=nil;
    exit;
  end;

  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.AddJITComponentFromStream] Create ...');
  {$ENDIF}
  try
    Result:=DoCreateJITComponent('',NewClassName,NewUnitName,AncestorClass,Visible,DisableAutoSize);
    if Result<0 then exit;
    ReadAncestorStreams;
    ReadStream(BinStream, FCurReadJITComponent.ClassType);

    if FCurReadJITComponent.Name = '' then
    begin
      NewName := FCurReadJITComponent.ClassName;
      if NewName[1]='T' then
        System.Delete(NewName, 1, 1);
      if FCurReadJITComponent is TControl then
        AControl:=TControl(FCurReadJITComponent)
      else
        AControl:=nil;
      OldSetCaption:=(AControl<>nil) and (csSetCaption in AControl.ControlStyle);
      if OldSetCaption then
        AControl.ControlStyle:=AControl.ControlStyle-[csSetCaption];
      FCurReadJITComponent.Name := NewName;
      if OldSetCaption then
        AControl.ControlStyle:=AControl.ControlStyle+[csSetCaption];
    end;
  except
    on E: Exception do begin
      HandleException(E,'[TJITComponentList.AddJITChildComponentFromStream] ERROR reading form stream'
         +' of Class "'+NewClassName+'"',Action);
      if Result>=0 then begin
        // try freeing the unfinished thing
        FCurReadJITComponent:=nil;
        DestroyJITComponent(Result);
        Result:=-1;
      end;
    end;
  end;
  {$IFDEF VerboseJITForms}
  WriteComponentStates(FCurReadJITComponent,true);
  {$ENDIF}
  FCurReadStreamClass:=nil;
  FCurReadJITComponent:=nil;
  FContextObject:=nil;
end;

function TJITComponentList.OnFindGlobalComponent(
  const AName: AnsiString): TComponent;
begin
  // This event is triggered everytime TReader searches a Component.
  // It is triggered for every sub component and every reference.
  // The sub comonent are found by TReader itself.
  // The other components are done at the end via GlobalFixupReferences.
  // So, there is nothing left to do here.
  Result := nil;
  //DebugLn(dbgsName(CurReadJITComponent), ' FIND global component ', AName, ' ', dbgsName(Result));
end;

procedure TJITComponentList.InitReading;
begin
  FFlags:=FFlags-[jclAutoRenameComponents];
  fRenameList.Clear;
  FErrors.Clear;
  
  MyFindGlobalComponentProc:=@OnFindGlobalComponent;
  RegisterFindGlobalComponentProc(@MyFindGlobalComponent);
  Application.FindGlobalComponentEnabled:=false;
end;

procedure TJITComponentList.CreateReader(BinStream: TStream;
  UnitResourcefileFormat: TUnitResourcefileFormatClass;
  var Reader: TReader; DestroyDriver: Boolean);
begin
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.InitReading] A');
  {$ENDIF}
  DestroyDriver:=false;
  Reader:=UnitResourcefileFormat.CreateReader(BinStream,DestroyDriver);
  // connect TReader events
  Reader.OnError:=@ReaderError;
  Reader.OnPropertyNotFound:=@ReaderPropertyNotFound;
  Reader.OnFindMethod:=@ReaderFindMethod;
  Reader.OnSetMethodProperty:=@ReaderSetMethodProperty;
  Reader.OnSetName:=@ReaderSetName;
  Reader.OnReferenceName:=@ReaderReferenceName;
  Reader.OnAncestorNotFound:=@ReaderAncestorNotFound;
  Reader.OnCreateComponent:=@ReaderCreateComponent;
  Reader.OnFindComponentClass:=@ReaderFindComponentClass;

  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.InitReading] B');
  {$ENDIF}

  FCurReadChildClass:=nil;
  FCurReadChild:=nil;
  FCurReadErrorMsg:='';
end;

function TJITComponentList.DoCreateJITComponent(
  const NewComponentName, NewClassName, NewUnitName: shortstring;
  AncestorClass: TClass; Visible, DisableAutoSize: boolean):integer;
var
  Instance: TComponent;
  InstAsCtrl: TControl absolute Instance;
  ok: boolean;
  Action: TModalResult;
  OldSetCaption: boolean;
begin
  Result:=-1;
  Instance:=nil;
  FCurReadClass:=nil;
  FCurReadStreamClass:=nil;
  FCurReadJITComponent:=nil;
  try
    ok:=false;
    // create new class and an instance
    {$IFDEF VerboseJITForms}
    DebugLn('[TJITForms.DoCreateJITComponent] Creating new JIT class "'+NewClassName+'" ...');
    {$ENDIF}
    FCurReadClass:=CreateNewJITClass(AncestorClass,NewClassName,NewUnitName);
    {$IFDEF VerboseJITForms}
    DebugLn('[TJITForms.DoCreateJITComponent] Creating an instance of JIT class "',
            FCurReadClass.ClassName,'" = class(',AncestorClass.ClassName,') ...');
    {$ENDIF}
    Instance:=TComponent(FCurReadClass.NewInstance);
    if DisableAutoSize and (Instance is TControl) then
      InstAsCtrl.DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TAnchorDockMaster Delayed'){$ENDIF};
    {$IFDEF VerboseJITForms}
    DebugLn('[TJITForms.DoCreateJITComponent] Initializing new instance "',Instance.Name,'" ',
            DbgS(Instance),' (',Instance.ClassName,')');
    {$ENDIF}
    FCurReadJITComponent:=Instance;
    try
      // set into design mode
      SetComponentDesignMode(Instance, True);
      // set csDesignInstance: it is a root design component
      SetComponentDesignInstanceMode(Instance, True);
      if (not Visible) and (Instance is TControl) then
        InstAsCtrl.ControlStyle:=InstAsCtrl.ControlStyle+[csNoDesignVisible];
      // event
      if Assigned(OnBeforeCreate) then
        OnBeforeCreate(Self,Instance);
      {$IFDEF VerboseJITForms}
      DebugLn('[TJITForms.DoCreateJITComponent] Finishing component creation.');
      {$ENDIF}
      // finish 'create' component
      Instance.Create(nil);
      if NewComponentName<>'' then begin
        // set Name, without changing Caption
        OldSetCaption:=(Instance is TControl) and (csSetCaption in InstAsCtrl.ControlStyle);
        if OldSetCaption then
          InstAsCtrl.ControlStyle:=InstAsCtrl.ControlStyle-[csSetCaption];
        Instance.Name:=NewComponentName;
        if OldSetCaption then
          InstAsCtrl.ControlStyle:=InstAsCtrl.ControlStyle+[csSetCaption];
      end;
      // set class name
      DoRenameClass(FCurReadClass,NewClassName);
      ok:=true;
    finally
      if not ok then begin
        FCurReadJITComponent:=nil;
        DebugLn('[TJITForms.DoCreateJITComponent] Error while creating instance: NewComponentName="',NewComponentName,'" NewClassName="',NewClassName,'" NewUnitName="',NewUnitName,'"');
      end;
    end;
  except
    on E: Exception do begin
      HandleException(E,'[TJITForms.DoCreateJITComponent] Error',Action);
      try
        if FCurReadClass<>nil then
          FreeJITClass(FCurReadClass);
        Instance.Free;
      except
        on E: Exception do begin
          HandleException(E,'[TJITForms.DoCreateJITComponent] Error while destroying instance: NewComponentName="'+NewComponentName+'" NewClassName="'+NewClassName+'" NewUnitName="'+NewUnitName+'"',Action);
        end;
      end;
    end;
  end;
  if FCurReadJITComponent<>nil then begin
    FCurReadJITComponent.FreeNotification(Self);
    Result:=FJITComponents.Add(FCurReadJITComponent);
  end;
end;

procedure TJITComponentList.ReadInlineComponent(var Component: TComponent;
  ComponentClass: TComponentClass; NewOwner: TComponent);
var
  DestroyDriver: Boolean;
  SubReader: TReader;
  BinStream: TExtMemoryStream;
  Ancestor: TComponent;
  Abort: boolean;
  Ancestors: TFPList;
  AncestorStreams: TFPList;
  i, j: Integer;
  OldStreamClass: TClass;
  DsgnComp, DsgnOwner: TCustomDesignControl;
begin
  fCurReadChild:=Component;
  fCurReadChildClass:=ComponentClass;

  if Assigned(OnFindAncestors) then begin
    Ancestors:=nil;
    AncestorStreams:=nil;
    OldStreamClass:=FCurReadStreamClass;
    try
      Abort:=false;
      OnFindAncestors(Self,ComponentClass,Ancestors,AncestorStreams,Abort);
      if Abort then begin
        DebugLn(['TJITComponentList.ReadInlineComponent aborted reading ComponentClass=',DbgSName(ComponentClass)]);
        raise EReadError.Create('TJITComponentList.ReadInlineComponent aborted reading ComponentClass='+DbgSName(ComponentClass));
      end;
      if Ancestors<>nil then begin
        // read ancestor streams
        Ancestor:=nil;
        for i:=Ancestors.Count-1 downto 0 do begin
          BinStream:=TExtMemoryStream(AncestorStreams[i]);
          FCurReadStreamClass:=TComponent(Ancestors[i]).ClassType;

          DebugLn(['TJITComponentList.ReadInlineComponent Has Stream: ',DbgSName(FCurReadStreamClass)]);
          // create component
          if Component=nil then begin
            DebugLn(['TJITComponentList.ReadInlineComponent creating ',DbgSName(ComponentClass),' NewOwner=',DbgSName(NewOwner),' ...']);
            // allocate memory without running the constructor
            Component:=TComponent(ComponentClass.newinstance);
            // set csDesigning
            SetComponentDesignMode(Component,true);
            // this is a streamed sub component => set csInline
            SetComponentInlineMode(Component,true);
            // now run the constructor
            Component.Create(NewOwner);
          end;
          // read stream
          fCurReadChild:=Component;
          fCurReadChildClass:=ComponentClass;
          SubReader:=nil;
          DestroyDriver:=false;
          try
            CreateReader(BinStream,LFMUnitResourcefileFormat,SubReader,DestroyDriver);
            // The stream contains only the diff to the Ancestor instance,
            // => give it the Ancestor instance
            SubReader.Ancestor:=Ancestor;
            SubReader.ReadRootComponent(Component);
          finally
            if SubReader<>nil then begin
              if DestroyDriver then SubReader.Driver.Free;
              SubReader.Free;
            end;
          end;
          FCurReadStreamClass:=OldStreamClass;
          // set csAncestor for the csInline subcomponents
          if csInline in Component.ComponentState then
            for j := 0 to Component.ComponentCount - 1 do
              SetComponentAncestorMode(Component.Components[j],true);
          // next
          Ancestor:=TComponent(Ancestors[i]);
        end;
        // scale to Owner's DesignTimePPI to get correct designed sizes - issue #36370
        if (Project1.Scaled or EnvironmentOptions.ForceDPIScalingInDesignTime)
        and Assigned(Component) and (Component is TCustomDesignControl) and (NewOwner is TCustomDesignControl) then
        begin
          DsgnComp := TCustomDesignControl(Component);
          DsgnOwner := TCustomDesignControl(NewOwner);
          if DsgnComp.Scaled and DsgnOwner.Scaled
          and (DsgnComp.DesignTimePPI<>DsgnOwner.PixelsPerInch) then
          begin
            DsgnComp.AutoAdjustLayout(lapAutoAdjustForDPI, DsgnComp.PixelsPerInch, DsgnOwner.DesignTimePPI, 0, 0);
            DsgnComp.DesignTimePPI := DsgnOwner.DesignTimePPI;
          end;
        end;
      end;
    finally
      Ancestors.Free;
      if AncestorStreams<>nil then
        for i:=0 to AncestorStreams.Count-1 do
          TObject(AncestorStreams[i]).Free;
      AncestorStreams.Free;
    end;
    FCurReadStreamClass:=OldStreamClass;
    fCurReadChild:=Component;
    fCurReadChildClass:=ComponentClass;
  end;
  //debugln(['[TJITComponentList.ReadInlineComponent] Class=',ComponentClass.ClassName,' Component=',dbgsName(Component)]);
end;

procedure TJITComponentList.DoFinishReading;
begin

end;

procedure TJITComponentList.HandleException(E: Exception;
  const Context: string; out Action: TModalResult);
begin
  Action:=mrAbort;
  FCurReadErrorMsg:=E.Message;
  // first write error to debug
  DebugLn(Context+' Error: '+FCurReadErrorMsg);
  // then try to give a backtrace
  DumpExceptionBackTrace;
  if Assigned(OnException) then
    OnException(Self,E,Action)
  else begin
    // then try to give a visible warning
    IDEMessageDialog('Read error',
      Context+LineEnding
       +'Error: '+FCurReadErrorMsg,mtError,[mbCancel]);
  end;
end;

procedure TJITComponentList.RemoveMethod(JITComponent:TComponent;
  const AName:ShortString);
var OldCode:Pointer;
begin
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.RemoveMethod ',JITComponent.Name,':',JITComponent.Name,' Method=',AName);
  {$ENDIF}
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RemoveMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RemoveMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if not IsValidIdent(AName) then
    raise Exception.Create('TJITComponentList.RemoveMethod invalid name: "'+AName+'"');

  // delete TJITMethod
  if JITMethods.Delete(JITComponent.ClassType,AName) then begin
    // this was a TJITmethod
    exit;
  end;
  
  // delete real method
  OldCode:=nil;
  DoRemoveMethod(JITComponent.ClassType,AName,OldCode);
  FreeMem(OldCode);
end;

procedure TJITComponentList.RenameMethod(JITComponent:TComponent;
  const OldName,NewName:ShortString);
begin
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.RenameMethod ',JITComponent.Name,':',JITComponent.Name,' Old=',OldName,' NewName=',NewName);
  {$ENDIF}
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RenameMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RenameMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if not IsValidIdent(NewName) then
    raise Exception.Create('TJITComponentList.RenameMethod invalid name: "'+NewName+'"');
    
  // rename TJITMethod
  if JITMethods.Rename(JITComponent.ClassType,OldName,NewName) then begin
    // this was a TJITMethod
    exit;
  end;
    
  // rename real method
  DoRenameMethod(JITComponent.ClassType,OldName,NewName);
end;

procedure TJITComponentList.RenameComponentClass(JITComponent:TComponent;
  const NewName:ShortString);
begin
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.RenameComponentClass ',JITComponent.Name,':',JITComponent.Name,' New=',NewName);
  {$ENDIF}
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RenameComponentClass JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RenameComponentClass JITComponent.ClassName='+
      JITComponent.ClassName);
  if not IsValidIdent(NewName) then
    raise Exception.Create('TJITComponentList.RenameComponentClass invalid name: "'+NewName+'"');
  DoRenameClass(JITComponent.ClassType,NewName);
end;

procedure TJITComponentList.RenameComponentUnitname(JITComponent: TComponent;
  const NewUnitName: ShortString);
begin
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.RenameComponentUnitname ',JITComponent.Name,':',JITComponent.Name,' New=',NewUnitName);
  {$ENDIF}
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.RenameComponentUnitname JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.RenameComponentUnitname JITComponent.ClassName='+
      JITComponent.ClassName);
  if (NewUnitName='') or (not IsValidUnitName(NewUnitName)) then
    raise Exception.Create('TJITComponentList.RenameComponentUnitname invalid name: "'+NewUnitName+'"');
  DoRenameUnitNameOfClass(JITComponent.ClassType,NewUnitName);
end;

procedure TJITComponentList.AddJITChildComponentsFromStream(
  JITOwnerComponent: TComponent; BinStream: TStream;
  ComponentClass: TComponentClass; ParentControl: TWinControl;
  NewComponents: TFPList);
var
  Reader: TReader;
  DestroyDriver: Boolean;
  Action: TModalResult;
begin
  if IndexOf(JITOwnerComponent)<0 then
    RaiseGDBException('TJITComponentList.AddJITChildComponentFromStream');
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.AddJITChildComponentFromStream] A');
  {$ENDIF}
  FCurReadJITComponent:=nil;
  FCurReadClass:=nil;
  FCurReadStreamClass:=nil;
  Reader:=nil;
  try
    DestroyDriver:=false;
    InitReading;
    CreateReader(BinStream,LFMUnitResourcefileFormat, Reader,DestroyDriver);
    {$IFDEF VerboseJITForms}
    debugln('[TJITComponentList.AddJITChildComponentFromStream] B');
    {$ENDIF}
    fReadComponents:=NewComponents;
    try
      FCurReadJITComponent:=JITOwnerComponent;
      FCurReadClass:=JITOwnerComponent.ClassType;
      FCurReadStreamClass:=FCurReadClass;

      FFlags:=FFlags+[jclAutoRenameComponents];
      {$IFDEF VerboseJITForms}
      debugln('[TJITComponentList.AddJITChildComponentFromStream] C1 ',ComponentClass.ClassName);
      {$ENDIF}
      Reader.ReadComponents(FCurReadJITComponent,ParentControl,@ReadComponentsProc);

      {$IFDEF VerboseJITForms}
      DebugLn('[TJITComponentList.AddJITChildComponentFromStream] C6 ');
      debugln('[TJITComponentList.AddJITChildComponentFromStream] D');
      {$ENDIF}
      DoFinishReading;
    finally
      fReadComponents:=nil;
      UnregisterFindGlobalComponentProc(@MyFindGlobalComponent);
      Application.FindGlobalComponentEnabled:=true;
      if DestroyDriver then Reader.Driver.Free;
      Reader.Free;
    end;
  except
    on E: Exception do begin
      HandleException(E,'[TJITComponentList.AddJITChildComponentFromStream] ERROR reading form stream of Class "'+ComponentClass.ClassName+'"',Action);
    end;
  end;
  FCurReadStreamClass:=nil;
end;

procedure TJITComponentList.ReadInlineJITChildComponent(Component: TComponent);
var
  Action: TModalResult;
begin
  FCurReadStreamClass:=nil;
  InitReading;
  {$IFDEF VerboseJITForms}
  DebugLn(['TJITComponentList.ReadInlineJITChildComponent Reading: ',DbgSName(Component)]);
  {$ENDIF}
  try
    try
      FCurReadJITComponent:=Component;
      ReadInlineComponent(Component,TComponentClass(Component.ClassType),Component.Owner);
    except
      on E: Exception do begin
        HandleException(E,'[TJITComponentList.ReadInlineJITChildComponent] ERROR reading inline stream'
           +' of "'+DbgSName(Component)+'"',Action);
      end;
    end;
    {$IFDEF VerboseJITForms}
    debugln('[TJITComponentList.ReadInlineJITChildComponent] Finish Reading ...');
    {$ENDIF}
    DoFinishReading;
  finally
    UnregisterFindGlobalComponentProc(@MyFindGlobalComponent);
    Application.FindGlobalComponentEnabled:=true;
  end;
  FCurReadJITComponent:=nil;
  FCurReadStreamClass:=nil;
end;

function TJITComponentList.CreateNewMethod(JITComponent: TComponent;
  const AName: ShortString): TMethod;
var
  OldCode: Pointer;
  JITMethod: TJITMethod;
begin
  {$IFDEF VerboseJITForms}
  debugln('TJITComponentList.CreateNewMethod ',JITComponent.Name,':',JITComponent.Name,' Method=',AName);
  {$ENDIF}
  if JITComponent=nil then
    raise Exception.Create('TJITComponentList.CreateNewMethod JITComponent=nil');
  if IndexOf(JITComponent)<0 then
    raise Exception.Create('TJITComponentList.CreateNewMethod JITComponent.ClassName='+
      JITComponent.ClassName);
  if not IsValidIdent(AName) then
    raise Exception.Create('TJITComponentList.CreateNewMethod invalid name: "'+AName+'"');
  OldCode:=JITComponent.MethodAddress(AName);
  if OldCode<>nil then begin
    // there is already a real method with this name
    Result.Data:=JITComponent;
    Result.Code:=OldCode;
    exit;
  end;
  // create a TJITMethod
  JITMethod:=JITMethods.Add(JITComponent.ClassType,AName);
  Result:=JITMethod.Method;
end;

procedure TJITComponentList.ReadComponentsProc(AComponent: TComponent);
var
  aControl: TControl;
  aCaption: TCaption;
begin
  if (AComponent.Name<>'') and (AComponent is TControl) then begin
    aControl:=TControl(AComponent);
    aCaption:=aControl.Caption;
    if (aCaption<>'') and (fRenameList[aCaption]=AComponent.Name) then begin
      // caption is the old name of the component
      // component was renamed => change caption too
      aControl.Caption:=AComponent.Name;
    end;
  end;
  if fReadComponents<>nil then
    fReadComponents.Add(AComponent);
end;

procedure TJITComponentList.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  if Operation=opRemove then
    FJITComponents.Remove(AComponent);
  inherited Notification(AComponent, Operation);
end;

function TJITComponentList.CreateNewJITClass(AncestorClass: TClass;
  const NewClassName, NewUnitName: ShortString): TClass;
// Create a new class (vmt, virtual method table, field table and typeinfo)
// that descends from AncestorClass.
// The new class will have no new variables, no new methods and no new fields.
var
  AncestorVMT: PVmt;

  procedure WarnUnsupportedVMTEntry(vmtOffset: PtrInt; const EntryName: string);
  begin
    if PPointer(Pointer(AncestorVMT)+vmtOffset)^<>nil then
      debugln(['Warn: (lazarus) TJITComponentList.CreateNewJITClass ',EntryName,' not yet supported. Ancestor=',AncestorClass.ClassName,' Class=',NewClassName]);
  end;


var
  NewVMT: PVmt;
  ClassNamePShortString: Pointer;
  NewFieldTable: PFieldTable;
  NewClassTable: PFieldClassTable;
  NewTypeInfo: PTypeInfo;
  NewTypeData: PTypeData;
  TypeInfoSize: Integer;
  AddedPropCount: PWord;
  vmtSize: Integer;
  vmtTailSize: Integer;
begin
  if AncestorClass=nil then
    raise Exception.Create('CreateNewClass AncestorClass=nil');
  if NewClassName='' then
    raise Exception.Create('CreateNewClass NewClassName empty');
  if not IsValidIdent(NewClassName) then
    raise Exception.Create('CreateNewClass NewClassName is not a valid identifier');
  if NewUnitName='' then
    raise Exception.Create('CreateNewClass NewUnitName empty');
  if not IsValidUnitName(NewUnitName) then
    raise Exception.Create('CreateNewClass NewUnitName is not a valid identifier');
  Result:=nil;

  AncestorVMT:=PVmt(AncestorClass);

  // create vmt
  vmtSize:=GetVMTSize(AncestorClass);
  vmtTailSize:=vmtSize-vmtMethodStart;
  GetMem(NewVMT,vmtSize);
  FillChar(NewVMT^,vmtSize,0);

  // set vmtInstanceSize
  NewVMT^.vInstanceSize:=AncestorClass.InstanceSize;
  NewVMT^.vInstanceSize2:=-AncestorClass.InstanceSize;

  // set vmtParent
  {$IFDEF HasVMTParent}
  NewVMT^.vParent:=AncestorVMT;
  {$ELSE}
  GetMem(NewVMT^.vParentRef,SizeOf(Pointer));
  NewVMT^.vParentRef^:=AncestorVMT;
  {$ENDIF}

  // set vmtClassName: create pointer to classname (PShortString)
  GetMem(ClassNamePShortString,SizeOf(ShortString));
  System.Move(NewClassName[0],ClassNamePShortString^,SizeOf(ShortString));
  NewVMT^.vClassName:=ClassNamePShortString; // don't use
                 // PShortString, so that the compiler does not get silly ideas

  WarnUnsupportedVMTEntry(vmtDynamicTable,'vmtDynamicTable');
  WarnUnsupportedVMTEntry(vmtMethodTable,'vmtMethodTable');

  // set vmtFieldTable
  GetMem(NewFieldTable,SizeOf(TFieldTable));
  FillChar(NewFieldTable^,SizeOf(TFieldTable),0);
  NewVMT^.vFieldTable:=NewFieldTable;

  // ClassTable
  GetMem(NewClassTable,SizeOf(Word));
  FillChar(NewClassTable^,SizeOf(Word),0);
  NewFieldTable^.ClassTable:=NewClassTable;

  // set vmtTypeInfo
  TypeInfoSize := CalculateTypeInfoSize(NewClassName,0);
  GetMem(NewTypeInfo,TypeInfoSize);
  FillChar(NewTypeInfo^,TypeInfoSize,0);
  NewVMT^.vTypeInfo:=NewTypeInfo;

  // set TypeInfo Kind and Name
  NewTypeInfo^.Kind:=tkClass;
  System.Move(NewClassName[0],NewTypeInfo^.Name[0],length(NewClassName)+1);
  NewTypeData:=GetTypeData(NewTypeInfo);

  // copy vmtInitTable
  NewVMT^.vInitTable:=AncestorVMT^.vInitTable;

  WarnUnsupportedVMTEntry(vmtAutoTable,'vmtAutoTable');

  // copy vmtIntfTable
  NewVMT^.vIntfTable:=AncestorVMT^.vIntfTable;

  WarnUnsupportedVMTEntry(vmtMsgStrPtr,'vmtMsgStrPtr');

  // set TypeData (PropCount is the total number of properties, including ancestors)
  NewTypeData^.ClassType:=TClass(NewVMT);
  {$IFDEF HasVMTParent}
  NewTypeData^.ParentInfo:=AncestorClass.ClassInfo;
  {$ELSE}
  GetMem(NewTypeData^.ParentInfoRef,SizeOf(Pointer));
  NewTypeData^.ParentInfoRef^:=AncestorClass.ClassInfo;
  {$ENDIF}
  NewTypeData^.PropCount:=GetTypeData(NewTypeData^.ParentInfo)^.PropCount;
  NewTypeData^.UnitName:=NewUnitName;
  AddedPropCount:=GetTypeDataPropCountAddr(NewTypeData);
  AddedPropCount^:=0;

  // copy the standard methods
  System.Move(Pointer(Pointer(AncestorVMT)+vmtMethodStart)^,
              Pointer(Pointer(NewVMT)+vmtMethodStart)^,
              vmtTailSize);

  //debugln(['TJITComponentList.CreateNewJITClass AncestorClass=',AncestorClass.ClassName,' NewClassName=',NewClassName,' NewUnitName=',NewUnitName,' vmtTailSize=',vmtTailSize]);

  // override 'ValidateRename' for TComponent descendants
  if AncestorClass.InheritsFrom(TComponent) then begin
    PPointer(Pointer(NewVMT)+TComponentValidateRenameOffset)^:=
                           @TComponentWithOverrideValidateRename.ValidateRename;
  end;

  Result:=TClass(NewVMT);
end;

procedure TJITComponentList.FreeJITClass(var AClass: TClass);

  procedure FreeMethodTableEntries(MethodTable: PMethodNameTable);
  var
    CurCount, i: integer;
    CurMethod: TMethodNameRec;
  begin
    if MethodTable=nil then exit;
    CurCount:=MethodTable^.Count;
    i:=CurCount;
    while i>0 do begin
      CurMethod:=MethodTable^.Entries[i-1];
      if CurMethod.Name<>nil then
        FreeMem(CurMethod.Name);
      if CurMethod.Addr<>nil then
        FreeMem(CurMethod.Addr);
      dec(i);
    end;
  end;

var
  OldVMT: PVmt;
  ClassNamePShortString: Pointer; // don't use PShortString so that the compiler don't get silly ideas
  OldFieldTable: PFieldTable;
  OldTypeInfo: PTypeInfo;
  OldMethodTable: PMethodNameTable;
  {$IF FPC_FULLVERSION>=30100}
  OldTypeData: PTypeData;
  {$ENDIF}
begin
  // free TJITMethods
  JITMethods.DeleteAllOfClass(AClass);

  OldVMT:=PVmt(Pointer(AClass));

  // free methodtable
  OldMethodTable:=PMethodNameTable(OldVMT^.vMethodTable);
  if Assigned(OldMethodTable) then begin
    FreeMethodTableEntries(OldMethodTable);
    FreeMem(OldMethodTable);
  end;

  // set vmtParent
  {$IFNDEF HasVMTParent}
  FreeMem(OldVMT^.vParentRef);
  {$ENDIF}

  // free classname
  ClassNamePShortString:=Pointer(OldVMT^.vClassName);
  FreeMem(ClassNamePShortString);

  // free field table
  OldFieldTable:=PFieldTable(OldVMT^.vFieldTable);
  ReallocMem(OldFieldTable^.ClassTable,0);
  FreeMem(OldFieldTable);

  // free typeinfo
  OldTypeInfo:=PTypeInfo(OldVMT^.vTypeInfo);
  {$IFNDEF HasVMTParent}
  // free ParentInfoRef
  OldTypeData:=GetTypeData(OldTypeInfo);
  FreeMem(OldTypeData^.ParentInfoRef);
  OldTypeData^.ParentInfoRef:=nil;
  {$ENDIF}
  FreeMem(OldTypeInfo);

  // free vmt
  FreeMem(OldVMT);
  AClass:=nil;
end;

procedure TJITComponentList.DoAddNewMethod(JITClass:TClass;
  const AName:ShortString;  ACode:Pointer);
var OldMethodTable, NewMethodTable: PMethodNameTable;
  NewMethodTableSize:integer;
begin
  //debugln('[TJITComponentList.AddNewMethod] '''+JITClass.ClassName+'.'+AName+'''');
  OldMethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  if Assigned(OldMethodTable) then begin
    NewMethodTableSize:=SizeOf(DWord)+
                     (OldMethodTable^.Count + 1)*SizeOf(TMethodNameRec);
  end else begin
    NewMethodTableSize:=SizeOf(DWord)+SizeOf(TMethodNameRec);
  end;
  GetMem(NewMethodTable,NewMethodTableSize);
  if Assigned(OldMethodTable) then begin
    Move(OldMethodTable^,NewMethodTable^,
      NewMethodTableSize-SizeOf(TMethodNameRec));
    NewMethodTable^.Count:=NewMethodTable^.Count+1;
  end else begin
    NewMethodTable^.Count:=1;
  end;
  {$R-}
  //for a:=0 to NewMethodTable^.Count-2 do
  //  debugln(a,'=',NewMethodTable^.Entries[a].Name^,' $'
  //    ,DbgS(PtrInt(NewMethodTable^.Entries[a].Name),8));
  with NewMethodTable^.Entries[NewMethodTable^.Count-1] do begin
    GetMem(Name,256);
    Name^:=AName;
    Addr:=ACode;
  end;
  //for a:=0 to NewMethodTable^.Count-1 do
  //  debugln(a,'=',NewMethodTable^.Entries[a].Name^,' $'
  //    ,DbgS(PtrInt(NewMethodTable^.Entries[a].Name),8));
  {$IFDEF RangeCheckOn}{$R+}{$ENDIF}
  PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^):=NewMethodTable;
  if Assigned(OldMethodTable) then
    FreeMem(OldMethodTable);
end;

procedure TJITComponentList.DoRemoveMethod(JITClass:TClass;
  AName:ShortString; var OldCode:Pointer);
// Note: does not free OldCode
var OldMethodTable, NewMethodTable: PMethodNameTable;
  NewMethodTableSize:integer;
  a:cardinal;
begin
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.DoRemoveMethod] '''+JITClass.ClassName+'.'+AName+'''');
  {$ENDIF}
  AName:=uppercase(AName);
  OldMethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  OldCode:=nil;
  if Assigned(OldMethodTable) then begin
    a:=0;
    while a<OldMethodTable^.Count do begin
      {$R-}
      if uppercase(OldMethodTable^.Entries[a].Name^)=AName then begin
        OldCode:=OldMethodTable^.Entries[a].Addr;
        FreeMem(OldMethodTable^.Entries[a].Name);
        if OldMethodTable^.Count>0 then begin
          NewMethodTableSize:=SizeOf(DWord)+
                              OldMethodTable^.Count*SizeOf(TMethodNameRec);
          GetMem(NewMethodTable,NewMethodTableSize);
          NewMethodTable^.Count:=OldMethodTable^.Count-1;
          Move(OldMethodTable^,NewMethodTable^,
               SizeOf(DWord)+a*SizeOf(TMethodNameRec));
          Move(OldMethodTable^.Entries[a],NewMethodTable^.Entries[a+1],
               SizeOf(DWord)+a*SizeOf(TMethodNameRec));
        end else begin
          NewMethodTable:=nil;
        end;
        PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^):=NewMethodTable;
        FreeMem(OldMethodTable);
        break;
      end;
      {$IFDEF RangeCheckOn}{$R+}{$ENDIF}
      inc(a);
    end;
  end;
end;

procedure TJITComponentList.DoRenameMethod(JITClass:TClass;
  OldName,NewName:ShortString);
var MethodTable: PMethodNameTable;
  a:integer;
begin
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.DoRenameMethod] ClassName='''+JITClass.ClassName+''''
    +' OldName='''+OldName+''' NewName='''+OldName+'''');
  {$ENDIF}
  OldName:=uppercase(OldName);
  MethodTable:=PMethodNameTable((Pointer(JITClass)+vmtMethodTable)^);
  if Assigned(MethodTable) then begin
    for a:=0 to MethodTable^.Count-1 do begin
      if uppercase(MethodTable^.Entries[a].Name^)=OldName then
        MethodTable^.Entries[a].Name^:=NewName;
    end;
  end;
end;

procedure TJITComponentList.DoRenameClass(JITClass:TClass; const NewName:ShortString);
begin
  {$IFDEF VerboseJITForms}
  debugln('[TJITComponentList.DoRenameClass] OldName='''+JITClass.ClassName
    +''' NewName='''+NewName+''' ');
  {$ENDIF}
  PShortString((Pointer(JITClass)+vmtClassName)^)^:=NewName;
end;

procedure TJITComponentList.DoRenameUnitNameOfClass(JITClass: TClass;
  const NewUnitName: ShortString);
var
  TypeInfo: PTypeInfo;
  TypeData: PTypeData;
  OldPropCount: Word;
begin
  TypeInfo:=PTypeInfo(JITClass.ClassInfo);
  if TypeInfo=nil then
    RaiseGDBException('TJITComponentList.DoRenameUnitNameOfClass');
  TypeData:=GetTypeData(TypeInfo);
  //DebugLn(['TJITComponentList.DoRenameUnitNameOfClass Old=',TypeData^.UnitName,' New=',NewUnitName]);
  OldPropCount:=GetTypeDataPropCountAddr(TypeData)^;
  if OldPropCount<>0 then
    RaiseGDBException('TJITComponentList.DoRenameUnitNameOfClass TODO: move properties and realloc mem');
  TypeData^.UnitName:=NewUnitName;
  GetTypeDataPropCountAddr(TypeData)^:=OldPropCount;
end;

//------------------------------------------------------------------------------

{
  TReader events.
  Normally at runtime a LFM is streamed back into the corresponding TForm
  descendent, all methods and components are published members and TReader can
  set these values.
  But at design time we do not have the corresponding TForm descendent. And
  there is no compiled code, thus it must be produced (just-in-time),
  if fake methods are not used.
}
procedure TJITComponentList.ReaderFindMethod(Reader: TReader;
  const FindMethodName: Ansistring;  var Address: Pointer; var Error: Boolean);
begin
  {$IFDEF IDE_DEBUG}
  debugln('[TJITComponentList.ReaderFindMethod] A "'+FindMethodName+'" Address=',DbgS(Address));
  {$ENDIF}
  RaiseGDBException('TJITComponentList.ReaderFindMethod this event should never be called -> this is a bug in TReader, or misuse of TReader.OnFindMethod');
end;

procedure TJITComponentList.ReaderPropertyNotFound(Reader: TReader;
  Instance: TPersistent; var PropName: string; IsPath: Boolean;
  var Handled, Skip: Boolean);
begin
  if Assigned(OnPropertyNotFound) then
    OnPropertyNotFound(Self,Reader,Instance,PropName,IsPath,Handled,Skip)
  else
    DebugLn('TJITComponentList.ReaderPropertyNotFound ',Instance.ClassName,'.',PropName);
end;

procedure TJITComponentList.ReaderSetMethodProperty(Reader: TReader;
  Instance: TPersistent; PropInfo: PPropInfo; const TheMethodName: string;
  var Handled: boolean);
var
  Method: TMethod;
  JITMethod: TJITMethod;
  CurLookupRoot: TPersistent;
begin
  //debugln('TJITComponentList.ReaderSetMethodProperty START ',DbgSName(Instance),' LookupRoot=',DbgSName(Reader.LookupRoot),' ',PropInfo^.Name,':=',TheMethodName);
  Method.Code:=FCurReadJITComponent.MethodAddress(TheMethodName);
  if Method.Code<>nil then begin
    // there is a real method with this name
    Method.Data := FCurReadJITComponent;
  end else begin
    JITMethod:=nil;
    if FCurReadStreamClass<>nil then begin
      // search in JIT method of stream class (e.g. ancestor)
      JITMethod:=JITMethods.Find(FCurReadStreamClass,TheMethodName);
    end;
    if (JITMethod=nil) then begin
      CurLookupRoot:=GetLookupRootForComponent(Reader.LookupRoot);
      if CurLookupRoot<>nil then begin
        // create a fake TJITMethod
        //DebugLn(['TJITComponentList.ReaderSetMethodProperty create JIT method: ',DbgSName(reader.LookupRoot),' TheMethodName=',TheMethodName]);
        JITMethod:=JITMethods.Add(CurLookupRoot.ClassType,TheMethodName);
      end;
    end;
    if JITMethod<>nil then
      Method:=JITMethod.Method
    else
      Method.Data:=nil;
  end;
  SetMethodProp(Instance, PropInfo, Method);
  //debugln(['TJITComponentList.ReaderSetMethodProperty Data=',dbgs(Method.Data),' Code=',dbgs(Method.Code)]);
  
  Handled:=true;
end;

procedure TJITComponentList.ReaderSetName(Reader: TReader;
  Component: TComponent; var NewName: Ansistring);
var
  OldName: String;
begin
//  debugln('[TJITComponentList.ReaderSetName] OldName="'+Component.Name+'" NewName="'+NewName+'"');
  if jclAutoRenameComponents in FFlags then begin
    OldName:=NewName;
    while FCurReadJITComponent.FindComponent(NewName)<>nil do
      NewName:=CreateNextIdentifier(NewName);
    if OldName<>NewName then
      fRenameList[OldName]:=NewName;
  end;
end;

procedure TJITComponentList.ReaderReferenceName(Reader: TReader;
  var RefName: Ansistring);
var
  NewName: String;
begin
  //debugln('[TJITComponentList.ReaderReferenceName] Name='''+RefName+'''');
  NewName:=fRenameList[RefName];
  if NewName<>'' then begin
    //debugln(['TJITComponentList.ReaderReferenceName Old="',RefName,'" New="',NewName,'"']);
    RefName:=NewName;
  end;
end;

procedure TJITComponentList.ReaderAncestorNotFound(Reader: TReader;
  const ComponentName: Ansistring;  ComponentClass: TPersistentClass;
  var Component: TComponent);
var
  i: Integer;
begin
  // ToDo: this is for custom form templates
  debugln('[TJITComponentList.ReaderAncestorNotFound] ComponentName="'+ComponentName
    +'" Component="'+dbgsName(Component)+'" ComponentClass="',dbgsName(ComponentClass)+'"');
  DebugLn(['TJITComponentList.ReaderAncestorNotFound FCurReadJITComponent=',dbgsName(FCurReadJITComponent)]);
  for i:=0 to FCurReadJITComponent.ComponentCount-1 do
    DebugLn(['TJITComponentList.ReaderAncestorNotFound ',i,' ',dbgsName(FCurReadJITComponent.Components[i])]);
end;

procedure TJITComponentList.ReaderError(Reader: TReader;
  const ErrorMsg: Ansistring; var Handled: Boolean);
// ToDo: use SUnknownProperty when it is published by the fpc team
const
  SUnknownProperty = 'Unknown property';
var
  ErrorType: TJITFormError;
  Action: TModalResult;
  ErrorBinPos: Int64;
begin
  ErrorType:=jfeReaderError;
  Action:=mrCancel;
  FCurReadErrorMsg:=ErrorMsg;
  FCurUnknownProperty:=''; // ToDo find name property
  // find out, what error occurred
  if RightStr(ErrorMsg,length(SUnknownProperty))=SUnknownProperty then begin
    ErrorType:=jfeUnknownProperty;
    Action:=mrIgnore;
  end;
  if Reader.Driver is TLRSObjectReader then begin
    // save error position
    ErrorBinPos:=TLRSObjectReader(Reader.Driver).Stream.Position;
    FErrors.Add(-1,ErrorBinPos,nil);
  end;
  if Assigned(OnReaderError) then
    OnReaderError(Self,Reader,ErrorType,Action);
  Handled:=Action in [mrIgnore];
  FCurUnknownProperty:='';
  
  DebugLn('>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>');
  DebugLn(['[TJITComponentList.ReaderError] "'+ErrorMsg+'" ignoring=',Handled]);
  DebugLn('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<');
end;

procedure TJITComponentList.ReaderFindComponentClass(Reader: TReader;
  const FindClassName: Ansistring; var ComponentClass: TComponentClass);
begin
  fCurReadChild:=nil;
  fCurReadChildClass:=ComponentClass;
  FCurUnknownClass:=FindClassName;
  if ComponentClass=nil then begin
    if Assigned(OnFindClass) then
      OnFindClass(Self,FindClassName,ComponentClass);
    fCurReadChildClass:=ComponentClass;
    if ComponentClass=nil then begin
      DebugLn('[TJITComponentList.ReaderFindComponentClass] '''+FindClassName
         +''' is unregistered');
      // The reader will create a ReaderError automatically
    end;
  end;
  FCurUnknownClass:='';
end;

procedure TJITComponentList.ReaderCreateComponent(Reader: TReader;
  ComponentClass: TComponentClass; var Component: TComponent);
begin
  fCurReadChild:=Component;
  fCurReadChildClass:=ComponentClass;
  
  ReadInlineComponent(Component,ComponentClass,Reader.Owner);
  //debugln(['[TJITComponentList.ReaderCreateComponent] Class=',ComponentClass.ClassName,' Component=',dbgsName(Component)]);
end;

procedure TJITComponentList.ReaderReadComponent(Component: TComponent);
begin
  fCurReadChild:=Component;
  fCurReadChildClass:=TComponentClass(Component.ClassType);
  DebugLn('TJITComponentList.ReaderReadComponent A ',Component.Name,':',Component.ClassName);
end;

//==============================================================================


{ TJITForms }

function TJITForms.IsJITForm(AComponent: TComponent): Boolean;
begin
  Result:=(AComponent is TCustomForm) and (IndexOf(AComponent)>=0);
end;

function TJITForms.GetItem(Index: integer): TCustomForm;
begin
  Result:=TCustomForm(inherited Items[Index]);
end;

{ TJITNonFormComponents }

function TJITNonFormComponents.IsJITNonForm(AComponent: TComponent): boolean;
begin
  Result:=(AComponent<>nil) and (not (AComponent is TCustomForm))
          and (IndexOf(AComponent)>=0);
end;

{ TJITMethod }

constructor TJITMethod.Create(AnOwner: TJITMethods;
  aClass: TClass; const aMethodName: shortstring);
begin
  FMethod.Data:=Self;
  FMethod.Code:=nil;
  fTheClass:=AClass;
  fTheMethodName:=aMethodName;
  FOwner:=AnOwner;
  Owner.InternalAdd(Self);
end;

destructor TJITMethod.Destroy;
begin
  if Owner<>nil then
    Owner.InternalRemove(Self);
  inherited Destroy;
end;

{ TJITMethods }

procedure TJITMethods.InternalAdd(const AMethod: TJITMethod);
begin
  fMethods.Add(AMethod);
  AMethod.fOwner:=Self;
end;

procedure TJITMethods.InternalRemove(const AMethod: TJITMethod);
begin
  AMethod.fOwner:=nil;
  if not fClearing then
    fMethods.Remove(AMethod);
end;

constructor TJITMethods.Create;
begin
  fMethods:=TAvlTree.Create(@CompareJITMethod);
end;

destructor TJITMethods.Destroy;
begin
  Clear;
  FreeAndNil(fMethods);
  inherited Destroy;
end;

procedure TJITMethods.Clear;
begin
  fClearing:=true;
  fMethods.FreeAndClear;
  fClearing:=false;
end;

function TJITMethods.Add(aClass: TClass;
  const aMethodName: shortstring): TJITMethod;
begin
  Result:=Find(aClass,aMethodName);
  if Result=nil then begin
    //DebugLn(['TJITMethods.Add Create Class=',dbgsname(aClass),' aMethodName=',aMethodName]);
    Result:=TJITMethod.Create(Self,aClass,aMethodName);
  end;
end;

function TJITMethods.Find(aClass: TClass;
  const aMethodName: shortstring): TJITMethod;
var
  CurMethod: TJITMethod;
  Node: TAvlTreeNode;
  Comp: LongInt;
begin
  //DebugLn(['TJITMethods.Find  Class=',dbgsname(aClass),' aMethodName=',aMethodName]);
  Node:=fMethods.Root;
  while (Node<>nil) do begin
    CurMethod:=TJITMethod(Node.Data);
    Comp:=ComparePointers(aClass,CurMethod.TheClass);
    if Comp=0 then
      Comp:=CompareText(aMethodName,CurMethod.TheMethodName);
    if Comp=0 then
      exit(CurMethod);
    if Comp<0 then begin
      Node:=Node.Left
    end else begin
      Node:=Node.Right
    end;
  end;
  Result:=nil;
end;

function TJITMethods.Delete(aMethod: TJITMethod): boolean;
begin
  //DebugLn(['TJITMethods.Delete  Class=',dbgsname(AMethod.TheClass),' aMethodName=',aMethod.TheMethodName]);
  Result:=false;
  if (aMethod<>nil) and (aMethod.Owner<>Self) then
    RaiseGDBException('TJITMethods.DeleteJITMethod')
  else begin
    Result:=true;
    InternalRemove(aMethod);
    aMethod.Free;
  end;
end;

function TJITMethods.Delete(aClass: TClass;
  const aMethodName: shortstring): boolean;
var
  CurMethod: TJITMethod;
begin
  CurMethod:=Find(aClass,aMethodName);
  if CurMethod=nil then begin
    Result:=false;
  end else begin
    Result:=true;
    InternalRemove(CurMethod);
    CurMethod.Free;
  end;
end;

procedure TJITMethods.DeleteAllOfClass(aClass: TClass);
var
  CurMethod: TJITMethod;
  Node: TAvlTreeNode;
  Comp: LongInt;
  NextNode: TAvlTreeNode;
begin
  Node:=fMethods.Root;
  while (Node<>nil) do begin
    CurMethod:=TJITMethod(Node.Data);
    Comp:=ComparePointers(aClass,CurMethod.TheClass);
    if Comp<0 then begin
      Node:=Node.Left
    end else if Comp>0 then begin
      Node:=Node.Right
    end else begin
      // one node found
      
      // search lowest
      repeat
        NextNode:=fMethods.FindPrecessor(Node);
        if (NextNode=nil)
           or (ComparePointers(aClass,TJITMethod(NextNode.Data).TheClass)<>0)
        then
          break;
        Node:=NextNode;
      until false;
      
      // delete all nodes of this class
      repeat
        NextNode:=fMethods.FindSuccessor(Node);
        CurMethod:=TJITMethod(Node.Data);
        CurMethod.FOwner:=nil;
        fMethods.Delete(Node);
        CurMethod.Free;
        Node:=NextNode;
      until (Node=nil)
           or (ComparePointers(aClass,TJITMethod(Node.Data).TheClass)<>0);

      exit;
    end;
  end;
end;

function TJITMethods.Rename(aClass: TClass; const OldMethodName,
  NewMethodName: shortstring): boolean;
var
  CurMethod: TJITMethod;
begin
  CurMethod:=Find(aClass,OldMethodName);
  if CurMethod=nil then begin
    Result:=false;
  end else begin
    Result:=true;
    //DebugLn(['TJITMethods.Rename Class=',DbgSName(aClass),' Old=',CurMethod.TheMethodName,' New=',NewMethodName]);
    fMethods.Remove(CurMethod);
    CurMethod.fTheMethodName:=NewMethodName;
    fMethods.Add(CurMethod);
  end;
end;

Initialization
  TComponentValidateRenameOffset:=GetTComponentValidateRenameVMTOffset;
  JITMethods:=TJITMethods.Create;
  
finalization
  FreeAndNil(JITMethods);

end.


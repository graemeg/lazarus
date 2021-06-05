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
unit JitRttiWriter;

{$mode objfpc}{$H+}
{$ModeSwitch typehelpers}

{$IF FPC_FULLVERSION<30100}
  {$DEFINE HasVMTParent}
{$ENDIF}
{$WARN 4055 off : Conversion between ordinals and pointers is not portable}
interface

uses
  SysUtils, TypInfo, Rtti;

const
{$ifdef ver3_0}
  SIZE_OF_TYPEINFO_PPOINTER = 0; // no intermediate pointer needed
  {$else}
  SIZE_OF_TYPEINFO_PPOINTER = SizeOf(PTypeInfo); // no intermediate pointer needed
{$endif}

type

{$ifdef ver3_0}
  TypeInfoPtr = PTypeInfo;
{$else}
  TypeInfoPtr = PPTypeInfo;
{$endif}
  PTypeInfoPtr = ^TypeInfoPtr;
  PCallConv = ^ TCallConv;

  JitRttiWriterException = class(Exception)
  end;

  { TJitRttiWriter }

  TJitRttiWriter = class
  private
    FCurDestMemPos: Pointer;

    function GetDestMem: Pointer; virtual; abstract;
  public
    constructor Create(ADestMem: Pointer);

    property DestMem: Pointer read GetDestMem;
    property CurDestMemPos: Pointer read FCurDestMemPos;
  end;

  { TJitRttiWriterTypeInfo }

  TJitRttiWriterTypeInfo = class(TJitRttiWriter)
  private
    FTypeInfo: PTypeInfo;
    FTypeData: PTypeData;

    function GetDestMem: Pointer; override;
  public
    constructor Create(ADestMem: Pointer; ATypeName: String; AKind: TTypeKind);

    property DestMem: Pointer read GetDestMem;
    property CurDestMemPos: Pointer read FCurDestMemPos;

    property TypeInfo: PTypeInfo read FTypeInfo;
    property TypeData: PTypeData read FTypeData;
  public
    // TODO: Maybe also emit the size needed for RedirectPointer TypeInfoPtr
    class function NewSizeFor(const ANewName: String): Integer; inline;
    class function NewSizeFor(const ANewName: String; ATypeKind: TTypeKind): Integer; inline;
    class function NewSizeForClass(const ANewName, AnUnitName: String): Integer; inline;
    class procedure AddSizeForShortString(var ASize: integer; const AText: String); inline;
  end;

  { TJitRttiWriterOrdSize }

  TJitRttiWriterOrdSize = class(TJitRttiWriterTypeInfo)
  public
    procedure WriteOrdType(AnOrdType : TOrdType); overload;
    procedure WriteOrdType(AnElemCount: QWord; AnSigned: Boolean); overload;
  end;

  { TJitRttiWriterOrdinal }

  TJitRttiWriterOrdinal = class(TJitRttiWriterOrdSize)
  public
    procedure WriteMinMax(AMin, AMax: Int64); overload;
    procedure WriteMinMax(AMin, AMax: QWord); overload;
  end;

  { TJitRttiWriterTkEnum }

  TJitRttiWriterTkEnum = class(TJitRttiWriterOrdinal)
  public
    constructor Create(ADestMem: Pointer; ATypeName: String; AnElemCount: integer);

    procedure WriteBaseTypeRef(ABaseType: TypeInfoPtr);
    procedure WriteEnumElemName(AnElemName: String);
    procedure WriteUnitName(AName: String); // Includes writing the final nil terminator
  public
    class procedure AddSizeForElemName(var ASize: integer; const AnElemName: String); inline;
    class procedure FinishSize(var ASize: integer); inline;
  end;

  { TJitRttiWriterTkSet }

  TJitRttiWriterTkSet = class(TJitRttiWriterOrdSize)
  public
    constructor Create(ADestMem: Pointer; ATypeName: String; AnElemCount: integer; ACompType: TypeInfoPtr = nil);
    procedure WriteCompTypeRef(ACompType: TypeInfoPtr);
  end;

  { TJitRttiWriterTkDynArray }

  TJitRttiWriterTkDynArray = class(TJitRttiWriterOrdSize)
  public
    constructor Create(ADestMem: Pointer; ATypeName, AnUnitname: String; AnElemSize: PtrUInt;
      AnElemtType: TypeInfoPtr; AVariantType: LongInt = -1);
  end;

  { TJitRttiWriterTkMethod }

  TJitRttiWriterTkMethod = class(TJitRttiWriterTypeInfo)
  private
    FState: (sInit, sParamInfo, sResultInfo, sCallConv, sParamType);
  public
    constructor Create(ADestMem: Pointer; ATypeName: String;
      AMethodKind : TMethodKind; AParamCount: Integer);

    procedure WriteParamInfo(AParamName, ATypeName: String; AParamFlags: TParamFlags);
    procedure WriteResultInfo(ATypeName: String; ATypeInfo: TypeInfoPtr);
    procedure WriteParamCallConv(ACallConv: TCallConv);
    procedure WriteParamType(ATypeInfo: TypeInfoPtr);
  public
    class procedure AddSizeForMethodField(var ASize, ATypeInfoRedrPtrSize: integer; const AName, ATypeName: String); inline;
    class procedure AddSizeForMethodResult(var ASize, ATypeInfoRedrPtrSize: integer; const ATypeName: String); inline;
    class procedure AddSizeForCallingConv(var ASize: integer); inline;
    (* TkMethod has 3 blocks of mem
       - Field-Info
       - Result-Info
       - Field-TypeInfo
       The size for Field TypeInfo is added as part of AddSizeForMethodField.
       But the Field-TypeInfo must be aligned, once all Field- and Result-Info
       have been written.
       This is done by FinalizeSizeForMethodTypeInfo.
       This can be done delayed, because the (P)TypeInfo itself is pointer sized
       and its early addition does not affect the alignment.
       If need, AddSizeForMethodField could keep count, and the size could be
       added in FinalizeSizeForMethodTypeInfo
    *)
    class procedure FinalizeSizeForMethodTypeInfo(var ASize: integer); inline;
  end;

  { TJitRttiWriterTkProcVar }

  TJitRttiWriterTkProcVar = class(TJitRttiWriterTypeInfo)
  public
    constructor Create(ADestMem: Pointer; ATypeName: String;
      AFlags: Byte; ACallConv: TCallConv; AResultTypeRef: TypeInfoPtr;
      AParamCount: Byte);

    procedure WriteProcedureParam(AParamName: String; ATypeInfo: TypeInfoPtr; AParamFlags: TParamFlags);
  public
    class procedure AddSizeForProcVarField(var ASize, ATypeInfoRedrPtrSize: integer; const AName: String); inline;
  end;

  { TJitRttiWriterBaseForManagedFields
    includes TInitManagedField // currently the same type as TManagedField
  }

  TJitRttiWriterBaseForManagedFields = class(TJitRttiWriterTypeInfo)
  public
    procedure WriteField(ATypeRefRef: TypeInfoPtr; AFldOffset: SizeInt);
  end;

  { TJitRttiWriterRecInitInfo }

  TJitRttiWriterRecInitInfo = class(TJitRttiWriterBaseForManagedFields)
  private
    function GetRecInitData: PRecInitData; inline;
  public
    constructor Create(ADestMem: Pointer; ATypeName: String; AKind: TTypeKind; AManagedFieldCount: Integer; ASize: Integer = 0);

    procedure WriteSize(ASize: Integer);
    property RecInitData: PRecInitData read GetRecInitData;
  public
    class function NewSizeForInitTable(ANewName: String; AFieldCount: Integer = 0): Integer; inline;
  end;

  { TJitRttiWriterTkRecord }

  TJitRttiWriterTkRecord = class(TJitRttiWriterBaseForManagedFields)
  private
    FState: (sUnlocked, sLocked);
    FRecInitFieldWriter: TJitRttiWriterRecInitInfo;
  public
    (* If no ARecInitDestMem is given, then RecInitWriter must not be accessed
       until all fields are written.
    *)
    constructor Create(ADestMem: Pointer; ATypeName: String;
      ATotalFieldCount: Integer; ARecSize: Integer = 0);
    constructor Create(ADestMem, ARecInitDestMem: Pointer; ATypeName: String;
      ATotalFieldCount, AManagedFieldCount: Integer; ARecSize: Integer = 0);
    destructor Destroy; override;

    procedure WriteField(ATypeRefRef: TypeInfoPtr; AFldOffset: SizeInt;
      AnWriteCopyToInitInfo: Boolean = False); reintroduce;
    procedure WriteRecSize(ARecSize: Integer);

    function StartRecInitFieldWriter(AManagedFieldCount: Integer): TJitRttiWriterRecInitInfo;
    property RecInitFieldWriter: TJitRttiWriterRecInitInfo read FRecInitFieldWriter;
  end;

  { TJitRttiWriterTkClass }

  TJitRttiWriterTkClass = class(TJitRttiWriterTypeInfo)
  private
    FPropData: PPropData;
  public
    constructor Create(ADestMem: Pointer;
      AClassName, AUnitName: String; AClass: TClass; AnAnchestorInfo: TypeInfoPtr;
      ALocalPropCount, ATotalPropCount: Integer);

    procedure WriteAnchestorInfo(AnAnchestorInfo: TypeInfoPtr);
    procedure WriteTotalPropCount(APropCount: Integer);
    function FirstPropInfo: PPropInfo;
  public
    class procedure AddSizeForProperty(var ASize, ATypeInfoRedrPtrSize: integer; const APropName: String); inline;
  end;


  { TJitRttiWriterVmtMethodTable }

  TJitRttiWriterVmtMethodTable = class(TJitRttiWriter)
  private
    FVmtMethodTable: PVmtMethodTable;
    FNamesTargetMem: Pointer;
    function GetDestMem: Pointer; override;
  public
    constructor Create(ADestMem: Pointer; ACount: integer);
    procedure WriteMethodEntry(ANamePtr: PShortString; ACodeAddr: CodePointer);

  public
    // Manage ShortString to PShortString conversion
    constructor Create(ADestMem, ANamesTargetMem: Pointer; ACount: integer);
    procedure WriteMethodEntry(AName: String; ACodeAddr: CodePointer);

    property CurNamesTargetMem: Pointer read FNamesTargetMem;
  public
    class function NewSizeFor(ACount: integer): integer; inline;
    class procedure AddSizeForShortStringPtr(var ASize: integer; const AMethName: String); inline;
  end;


function PTypeInfoToTypeInfoPtr(ATypeInfo: PTypeInfo; var ARedirectMem: Pointer): TypeInfoPtr; inline;
function TypeInfoPtrToPTypeInfo(ATypeInfoPtr: TypeInfoPtr): PTypeInfo; inline;
function aligntoptr(p : pointer) : pointer;inline; overload; // aligntoptr: copied from unit TypeInfo
function aligntoptr(p : Integer) : Integer;inline; overload;

implementation

type
  PParamFlags = ^TParamFlags;

  { TStringHelper }

  TStringHelper = type helper for string
    function WriteToShortStringMem(var ADest: Pointer): Pointer; // returns ADest
  end;

{ TJitRttiWriter }

constructor TJitRttiWriter.Create(ADestMem: Pointer);
begin
  FCurDestMemPos := ADestMem;
end;

{ TStringHelper }

function TStringHelper.WriteToShortStringMem(var ADest: Pointer): Pointer;
begin
  if Length(Self) > 255 then
    raise Exception.Create('Ident to long');
  Result := ADest;
  PByte(ADest)^ := Length(Self);
  if Self <> '' then
    move(Self[1], PByte(ADest)[1], Length(self));
  ADest := ADest + 1 + Length(Self)
end;

function PTypeInfoToTypeInfoPtr(ATypeInfo: PTypeInfo; var ARedirectMem: Pointer
  ): TypeInfoPtr;
begin
  if ATypeInfo = nil then begin
    Result := nil;
  end
  else begin
    {$ifdef ver3_0}
    Result := ATypeInfo;
    {$else}
    Result := ARedirectMem;
    PPTypeInfo(ARedirectMem)^ := ATypeInfo;
    inc(PPTypeInfo(ARedirectMem));
    {$endif}
  end;
end;

function TypeInfoPtrToPTypeInfo(ATypeInfoPtr: TypeInfoPtr): PTypeInfo;
begin
  {$ifdef ver3_0}
  Result := PTypeInfoPtr(mem)^;
  {$else}
  if ATypeInfoPtr^ = nil then
    Result := nil
  else
    Result := ATypeInfoPtr^;
  {$endif}
end;

(* aligntoptr: copied from unit TypeInfo *)
function aligntoptr(p : pointer) : pointer;inline;
begin
{$ifdef m68k}
     result:=AlignTypeData(p);
{$else m68k}
{$ifdef FPC_REQUIRES_PROPER_ALIGNMENT}
     result:=align(p,sizeof(p));
{$else FPC_REQUIRES_PROPER_ALIGNMENT}
     result:=p;
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
{$endif m68k}
end;

function aligntoptr(p: Integer): Integer;
begin
  Result := {%H-}PtrUInt(aligntoptr({%H-}Pointer(PtrUInt(p))));
end;

function AlignTypeData(p: Integer): Integer; overload;
begin
  Result := {%H-}PtrUInt(AlignTypeData({%H-}Pointer(PtrUInt(p))));
end;

function AlignTParamFlags(p: Integer): Integer; overload;
begin
  Result := {%H-}PtrUInt(AlignTParamFlags({%H-}Pointer(PtrUInt(p))));
end;


{ TJitRttiWriterTypeInfo }

function TJitRttiWriterTypeInfo.GetDestMem: Pointer;
begin
  Result := FTypeInfo;
end;

constructor TJitRttiWriterTypeInfo.Create(ADestMem: Pointer; ATypeName: String;
  AKind: TTypeKind);
begin
  inherited Create(nil); // for any subclass that does not use it
  FTypeInfo := ADestMem;
  FTypeInfo^.Name := ATypeName;
  FTypeInfo^.Kind := AKind;

  FTypeData := GetTypeData(FTypeInfo);
end;

class function TJitRttiWriterTypeInfo.NewSizeFor(const ANewName: String
  ): Integer;
var
  ti: TTypeInfo;
begin
  ti.Name := ANewName;
  Result := Pointer(GetTypeData(@ti)) - Pointer(@ti);
end;

class function TJitRttiWriterTypeInfo.NewSizeFor(const ANewName: String;
  ATypeKind: TTypeKind): Integer;
begin
  Result := NewSizeFor(ANewName);
  case ATypeKind of
    tkEnumeration: Result := Result
                           + PtrUInt(@PTypeData(nil)^.NameList);
    tkMethod:      Result := AlignTParamFlags(
                               Result
                             + PtrUInt(@PTypeData(nil)^.ParamList)
                             );
    tkProcVar:     Result := aligntoptr(
                               Result
                             + PtrUInt(@PTypeData(nil)^.ProcSig)
                             + SizeOf(TProcedureSignature)
                             );
    tkRecord:      Result := Result
                           + PtrUInt(@PTypeData(nil)^.TotalFieldCount)
                           + SizeOf(TTypeData.TotalFieldCount);
    tkSString:     Result := Result
                           + PtrUInt(@PTypeData(nil)^.MaxLength)
                           + SizeOf(TTypeData.MaxLength);
    tkInteger,tkChar,tkBool,tkWChar:
                   Result := Result
                           + PtrUInt(@PTypeData(nil)^.MaxValue)
                           + SizeOf(TTypeData.MaxValue);
    tkSet:         Result := Result
                           + PtrUInt(@PTypeData(nil)^.CompTypeRef)
                           + SizeOf(TTypeData.CompTypeRef);
    tkInt64:       Result := Result
                           + PtrUInt(@PTypeData(nil)^.MaxInt64Value)
                           + SizeOf(TTypeData.MaxInt64Value);
    tkQWord:       Result := Result
                           + PtrUInt(@PTypeData(nil)^.MaxQWordValue)
                           + SizeOf(TTypeData.MaxQWordValue);
    tkDynArray:    Result := Result
                           + PtrUInt(@PTypeData(nil)^.IntfUnit)
                           + SizeOf(TTypeData.MaxInt64Value);
                           //unitname

    else           Result := Result
                           + SizeOf(TTypeData); // include max size
  end;
end;

class function TJitRttiWriterTypeInfo.NewSizeForClass(const ANewName,
  AnUnitName: String): Integer;
begin
  Result := aligntoptr(
    NewSizeFor(ANewName)
      + aligntoptr(
      + PtrUInt(@PTypeData(nil)^.UnitName)
      + Length(AnUnitName) + 1
      )
      + SizeOf(TPropData.PropCount)
    );
end;

class procedure TJitRttiWriterTypeInfo.AddSizeForShortString(
  var ASize: integer; const AText: String);
begin
  ASize := ASize + 1 + Length(AText);
end;

{ TJitRttiWriterOrdSize }

procedure TJitRttiWriterOrdSize.WriteOrdType(AnOrdType: TOrdType);
begin
  FTypeData^.OrdType := AnOrdType;
end;

procedure TJitRttiWriterOrdSize.WriteOrdType(AnElemCount: QWord;
  AnSigned: Boolean);
begin
  if AnSigned then
    case AnElemCount of
      0..255:            FTypeData^.OrdType := otSByte;
      256..65535:        FTypeData^.OrdType := otSWord;
      $10000..$ffffffff: FTypeData^.OrdType := otSLong;
      else               FTypeData^.OrdType := otSQWord;
    end
  else
    case AnElemCount of
      0..255:            FTypeData^.OrdType := otUByte;
      256..65535:        FTypeData^.OrdType := otUWord;
      $10000..$ffffffff: FTypeData^.OrdType := otULong;
      else               FTypeData^.OrdType := otUQWord;
    end;
end;

procedure TJitRttiWriterOrdinal.WriteMinMax(AMin, AMax: Int64);
begin
  case FTypeInfo^.Kind of
    tkInt64: begin
      FTypeData^.MinInt64Value := AMin;
      FTypeData^.MaxInt64Value := AMax;
    end;
    tkQWord: begin
      FTypeData^.MinQWordValue := QWord(AMin);
      FTypeData^.MaxQWordValue := QWord(AMax);
    end;
    else begin
      FTypeData^.MinValue := AMin;
      FTypeData^.MaxValue := AMax;
    end;
  end;
end;

{ TJitRttiWriterOrdinal }

procedure TJitRttiWriterOrdinal.WriteMinMax(AMin, AMax: QWord);
begin
  WriteMinMax(Int64(AMin), Int64(AMax));
end;

{ TJitRttiWriterTkEnum }

constructor TJitRttiWriterTkEnum.Create(ADestMem: Pointer; ATypeName: String;
  AnElemCount: integer);
begin
  inherited Create(ADestMem, ATypeName, tkEnumeration);

  WriteOrdType(AnElemCount, False);
  FTypeData^.MinValue := 0;
  FTypeData^.MaxValue := AnElemCount - 1;
  FTypeData^.BaseTypeRef := nil;

  FCurDestMemPos := @FTypeData^.NameList;
end;

procedure TJitRttiWriterTkEnum.WriteBaseTypeRef(ABaseType: TypeInfoPtr);
begin
  FTypeData^.BaseTypeRef := ABaseType;
end;

procedure TJitRttiWriterTkEnum.WriteEnumElemName(AnElemName: String);
begin
  AnElemName.WriteToShortStringMem(FCurDestMemPos);
end;

procedure TJitRttiWriterTkEnum.WriteUnitName(AName: String);
begin
  AName.WriteToShortStringMem(FCurDestMemPos);
  PByte(FCurDestMemPos)^ := 0;
  inc(PByte(FCurDestMemPos));
end;

class procedure TJitRttiWriterTkEnum.AddSizeForElemName(var ASize: integer;
  const AnElemName: String);
begin
  ASize := ASize + Length(AnElemName) + 1;
end;

class procedure TJitRttiWriterTkEnum.FinishSize(var ASize: integer);
begin
  ASize := ASize + 1; // zero byte at the end
end;

{ TJitRttiWriterTkSet }

constructor TJitRttiWriterTkSet.Create(ADestMem: Pointer; ATypeName: String;
  AnElemCount: integer; ACompType: TypeInfoPtr);
begin
  inherited Create(ADestMem, ATypeName, tkSet);

  FTypeData^.SetSize := (AnElemCount + 7) div 8;
  FTypeData^.CompTypeRef := ACompType;

  case FTypeData^.SetSize of
     1: FTypeData^.OrdType := otUByte;
     2: FTypeData^.OrdType := otUWord;
     4: FTypeData^.OrdType := otULong;
     else
        FTypeData^.OrdType := otUByte;
  end;

  FCurDestMemPos := Pointer(FTypeData)
    + PtrUInt(@PTypeData(nil)^.CompTypeRef)
    + SizeOf(TTypeData.CompTypeRef);
end;

procedure TJitRttiWriterTkSet.WriteCompTypeRef(ACompType: TypeInfoPtr);
begin
  FTypeData^.CompTypeRef := ACompType;
end;

{ TJitRttiWriterTkDynArray }

constructor TJitRttiWriterTkDynArray.Create(ADestMem: Pointer; ATypeName,
  AnUnitname: String; AnElemSize: PtrUInt; AnElemtType: TypeInfoPtr;
  AVariantType: LongInt);
begin
  inherited Create(ADestMem, ATypeName, tkDynArray);

  FTypeData^.elSize := AnElemSize;
  FTypeData^.elType2Ref := AnElemtType;
  FTypeData^.elTypeRef := nil;
  if Rtti.IsManaged(AnElemtType{$ifndef ver3_0}^{$endif}) then
    FTypeData^.elTypeRef := AnElemtType;
  FTypeData^.varType := AVariantType;

  FCurDestMemPos := @FTypeData^.IntfUnit;
  AnUnitname.WriteToShortStringMem(FCurDestMemPos);
end;

{ TJitRttiWriterTkMethod }

constructor TJitRttiWriterTkMethod.Create(ADestMem: Pointer; ATypeName: String;
  AMethodKind: TMethodKind; AParamCount: Integer);
begin
  inherited Create(ADestMem, ATypeName, tkMethod);
  FCurDestMemPos := @FTypeData^.ParamList;
  FState := sParamInfo;

  FTypeData^.MethodKind := AMethodKind;
  FTypeData^.ParamCount := AParamCount;
end;

procedure TJitRttiWriterTkMethod.WriteParamInfo(AParamName, ATypeName: String;
  AParamFlags: TParamFlags);
begin
  if FState <> sInit then
    FCurDestMemPos := AlignTParamFlags(FCurDestMemPos);

  if FState = sInit       then FState := sParamInfo;
  if FState <> sParamInfo then raise JitRttiWriterException.Create('');

  PParamFlags(FCurDestMemPos)^ := AParamFlags;
  inc(PParamFlags(FCurDestMemPos));
  AParamName.WriteToShortStringMem(FCurDestMemPos);
  ATypeName.WriteToShortStringMem(FCurDestMemPos);
end;

procedure TJitRttiWriterTkMethod.WriteResultInfo(ATypeName: String;
  ATypeInfo: TypeInfoPtr);
begin
  if FState in [sInit, sParamInfo] then FState := sResultInfo
  else
    raise JitRttiWriterException.Create('');

  ATypeName.WriteToShortStringMem(FCurDestMemPos);
  FCurDestMemPos := AlignToPtr(FCurDestMemPos);
  PTypeInfoPtr(FCurDestMemPos)^ := ATypeInfo;
  inc(TypeInfoPtr(FCurDestMemPos));
end;

procedure TJitRttiWriterTkMethod.WriteParamCallConv(ACallConv: TCallConv);
begin
  if FState in [sInit, sParamInfo, sResultInfo] then
    FState := sCallConv
  else
    raise JitRttiWriterException.Create('');

  PCallConv(FCurDestMemPos)^ := ACallConv;
  inc(PCallConv(FCurDestMemPos));
end;

procedure TJitRttiWriterTkMethod.WriteParamType(ATypeInfo: TypeInfoPtr);
begin
  if FState = sCallConv then begin
    FState := sParamType;
    FCurDestMemPos := AlignTypeData(FCurDestMemPos);
  end;
  if FState <> sParamType then raise JitRttiWriterException.Create('');

  PTypeInfoPtr(FCurDestMemPos)^ := ATypeInfo;
  inc(TypeInfoPtr(FCurDestMemPos));
end;

class procedure TJitRttiWriterTkMethod.AddSizeForMethodField(var ASize,
  ATypeInfoRedrPtrSize: integer; const AName, ATypeName: String);
begin
  ASize := AlignTParamFlags(ASize)
    + Length(AName) + 1
    + Length(ATypeName) + 1
    + sizeof(TParamFlags)
    + SizeOf(PPTypeInfo);
  ATypeInfoRedrPtrSize := ATypeInfoRedrPtrSize + SIZE_OF_TYPEINFO_PPOINTER;  // for PPTypeInfo intemediate pointer
end;

class procedure TJitRttiWriterTkMethod.AddSizeForMethodResult(var ASize,
  ATypeInfoRedrPtrSize: integer; const ATypeName: String);
begin
  ASize := aligntoptr(ASize)
    + Length(ATypeName) + 1
    + SizeOf(PPTypeInfo)
    + sizeof(TCallConv);
  ATypeInfoRedrPtrSize := ATypeInfoRedrPtrSize + SIZE_OF_TYPEINFO_PPOINTER;  // for PPTypeInfo intemediate pointer
end;

class procedure TJitRttiWriterTkMethod.AddSizeForCallingConv(var ASize: integer
  );
begin
  ASize := ASize+ SizeOf(TCallConv);
end;

class procedure TJitRttiWriterTkMethod.FinalizeSizeForMethodTypeInfo(
  var ASize: integer);
begin
  ASize := AlignTypeData(ASize);
end;

{ TJitRttiWriterTkProcVar }

constructor TJitRttiWriterTkProcVar.Create(ADestMem: Pointer;
  ATypeName: String; AFlags: Byte; ACallConv: TCallConv;
  AResultTypeRef: TypeInfoPtr; AParamCount: Byte);
begin
  inherited Create(ADestMem, ATypeName, tkProcVar);

  FTypeData^.ProcSig.Flags := AFlags;
  FTypeData^.ProcSig.CC := ACallConv;
  FTypeData^.ProcSig.ResultTypeRef := AResultTypeRef;
  FTypeData^.ProcSig.ParamCount := AParamCount;

  FCurDestMemPos := FTypeData^.ProcSig.GetParam(0);
end;

procedure TJitRttiWriterTkProcVar.WriteProcedureParam(AParamName: String;
  ATypeInfo: TypeInfoPtr; AParamFlags: TParamFlags);
begin
  PProcedureParam(FCurDestMemPos)^.ParamFlags := AParamFlags;
  PProcedureParam(FCurDestMemPos)^.ParamTypeRef := ATypeInfo;
  FCurDestMemPos := FCurDestMemPos + PtrUInt(@PProcedureParam(nil)^.Name);
  AParamName.WriteToShortStringMem(FCurDestMemPos);
  FCurDestMemPos := aligntoptr(FCurDestMemPos);
end;

class procedure TJitRttiWriterTkProcVar.AddSizeForProcVarField(var ASize,
  ATypeInfoRedrPtrSize: integer; const AName: String);
begin
  ASize := aligntoptr(ASize)
    + Length(AName) + 1
    + PtrUInt(@PProcedureParam(nil)^.Name);
  ATypeInfoRedrPtrSize := ATypeInfoRedrPtrSize + SIZE_OF_TYPEINFO_PPOINTER;  // for PPTypeInfo intemediate pointer
end;

{ TJitRttiWriterBaseForManagedFields }

procedure TJitRttiWriterBaseForManagedFields.WriteField(
  ATypeRefRef: TypeInfoPtr; AFldOffset: SizeInt);
begin
  PManagedField(FCurDestMemPos)^.TypeRefRef := ATypeRefRef;
  PManagedField(FCurDestMemPos)^.FldOffset := AFldOffset;
  inc(PManagedField(FCurDestMemPos));
end;

{ TJitRttiWriterRecInitInfo }

function TJitRttiWriterRecInitInfo.GetRecInitData: PRecInitData;
begin
  Result := PRecInitData(TypeData);
end;

constructor TJitRttiWriterRecInitInfo.Create(ADestMem: Pointer;
  ATypeName: String; AKind: TTypeKind; AManagedFieldCount: Integer;
  ASize: Integer);
begin
  inherited Create(ADestMem, ATypeName, AKind);

  RecInitData^.Terminator := nil;
  RecInitData^.InitOffsetOp := nil;
  RecInitData^.ManagedFieldCount := AManagedFieldCount;
  RecInitData^.Size := ASize;

  FCurDestMemPos := Pointer(RecInitData) + SizeOf(TRecInitData);
end;

procedure TJitRttiWriterRecInitInfo.WriteSize(ASize: Integer);
begin
  RecInitData^.Size := ASize;
end;

class function TJitRttiWriterRecInitInfo.NewSizeForInitTable(ANewName: String;
  AFieldCount: Integer): Integer;
begin
  Result := NewSizeFor(ANewName)
          + SizeOf(TRecInitData)
          + SizeOf(TInitManagedField) * AFieldCount;
end;

{ TJitRttiWriterTkRecord }

function TJitRttiWriterTkRecord.StartRecInitFieldWriter(
  AManagedFieldCount: Integer): TJitRttiWriterRecInitInfo;
begin
  if FRecInitFieldWriter <> nil then
    raise JitRttiWriterException.Create('RecInitFieldWriter already created');
  FState := sLocked;
  FRecInitFieldWriter := TJitRttiWriterRecInitInfo.Create(
    FCurDestMemPos, FTypeInfo^.Name, tkRecord,
    AManagedFieldCount, FTypeData^.RecSize);
  // Size can be changed later

  FTypeData^.RecInitInfo := FRecInitFieldWriter;
  Result := FRecInitFieldWriter;
end;

constructor TJitRttiWriterTkRecord.Create(ADestMem: Pointer; ATypeName: String;
  ATotalFieldCount: Integer; ARecSize: Integer);
begin
  inherited Create(ADestMem, ATypeName, tkRecord);

  FState := sUnlocked;
  FTypeData^.RecSize := ARecSize;
  FTypeData^.TotalFieldCount := ATotalFieldCount;

  FCurDestMemPos := Pointer(FTypeData) + PtrUInt(@PTypeData(nil)^.TotalFieldCount) + SizeOf(TTypeData.TotalFieldCount);
end;

constructor TJitRttiWriterTkRecord.Create(ADestMem, ARecInitDestMem: Pointer;
  ATypeName: String; ATotalFieldCount, AManagedFieldCount: Integer;
  ARecSize: Integer);
begin
  Create(ADestMem, ATypeName, ATotalFieldCount, ARecSize);
  FRecInitFieldWriter := TJitRttiWriterRecInitInfo.Create(
    ARecInitDestMem, ATypeName, tkRecord,
    AManagedFieldCount, ARecSize);
  FTypeData^.RecInitInfo := ARecInitDestMem;
  // Size can be changed later
end;

destructor TJitRttiWriterTkRecord.Destroy;
begin
  inherited Destroy;
  FRecInitFieldWriter.Free;
end;

procedure TJitRttiWriterTkRecord.WriteField(ATypeRefRef: TypeInfoPtr;
  AFldOffset: SizeInt; AnWriteCopyToInitInfo: Boolean);
begin
  if FState = sLocked then
    raise JitRttiWriterException.Create('not allowed to add fields');
  if AnWriteCopyToInitInfo and (FRecInitFieldWriter = nil) then
    raise JitRttiWriterException.Create('RecInitWriter not ready');

  inherited WriteField(ATypeRefRef, AFldOffset);
  if AnWriteCopyToInitInfo then
    FRecInitFieldWriter.WriteField(ATypeRefRef, AFldOffset);
end;

procedure TJitRttiWriterTkRecord.WriteRecSize(ARecSize: Integer);
begin
  FTypeData^.RecSize := ARecSize;
end;

{ TJitRttiWriterTkClass }

constructor TJitRttiWriterTkClass.Create(ADestMem: Pointer; AClassName,
  AUnitName: String; AClass: TClass; AnAnchestorInfo: TypeInfoPtr;
  ALocalPropCount, ATotalPropCount: Integer);
begin
  inherited Create(ADestMem, AClassName, tkClass);

  FTypeData^.ClassType := AClass;
  {$IFDEF HasVMTParent}
  FTypeData^.ParentInfo := AnAnchestorInfo;
  {$ELSE}
  FTypeData^.ParentInfoRef := AnAnchestorInfo;
  {$ENDIF}
  FTypeData^.UnitName := AUnitName;
  FTypeData^.PropCount := ATotalPropCount;

  FPropData := aligntoptr(pointer(@FTypeData^.UnitName)+Length(FTypeData^.UnitName)+1);
  FPropData^.PropCount := ALocalPropCount;

  FCurDestMemPos := nil;
end;

procedure TJitRttiWriterTkClass.WriteAnchestorInfo(AnAnchestorInfo: TypeInfoPtr
  );
begin
  {$IFDEF HasVMTParent}
  FTypeData^.ParentInfo := AnAnchestorInfo;
  {$ELSE}
  FTypeData^.ParentInfoRef := AnAnchestorInfo;
  {$ENDIF}
end;

procedure TJitRttiWriterTkClass.WriteTotalPropCount(APropCount: Integer);
begin
  FTypeData^.PropCount := APropCount;
end;

function TJitRttiWriterTkClass.FirstPropInfo: PPropInfo;
begin
  Result := FPropData^.Prop[0];
end;

class procedure TJitRttiWriterTkClass.AddSizeForProperty(var ASize,
  ATypeInfoRedrPtrSize: integer; const APropName: String);
var
  pi: TPropInfo;
begin
  pi.Name := APropName;
  ASize := ASize + (Pointer(pi.Next) - Pointer(@pi));
  ATypeInfoRedrPtrSize := ATypeInfoRedrPtrSize + SIZE_OF_TYPEINFO_PPOINTER;  // for PPTypeInfo intemediate pointer
end;

{ TJitRttiWriterVmtMethodTable }

function TJitRttiWriterVmtMethodTable.GetDestMem: Pointer;
begin
  Result := FVmtMethodTable;
end;

constructor TJitRttiWriterVmtMethodTable.Create(ADestMem: Pointer;
  ACount: integer);
begin
  inherited Create(ADestMem);
  FVmtMethodTable := ADestMem;
  FVmtMethodTable^.Count := ACount;

  FCurDestMemPos := FVmtMethodTable^.Entry[0];
end;

procedure TJitRttiWriterVmtMethodTable.WriteMethodEntry(ANamePtr: PShortString;
  ACodeAddr: CodePointer);
begin
  PVmtMethodEntry(FCurDestMemPos)^.Name := ANamePtr;
  PVmtMethodEntry(FCurDestMemPos)^.CodeAddress := ACodeAddr;
  inc(PVmtMethodEntry(FCurDestMemPos));
end;

constructor TJitRttiWriterVmtMethodTable.Create(ADestMem,
  ANamesTargetMem: Pointer; ACount: integer);
begin
  Create(ADestMem, ACount);
  FNamesTargetMem := ANamesTargetMem;
end;

procedure TJitRttiWriterVmtMethodTable.WriteMethodEntry(AName: String;
  ACodeAddr: CodePointer);
begin
  WriteMethodEntry(AName.WriteToShortStringMem(FNamesTargetMem), ACodeAddr);
end;

class function TJitRttiWriterVmtMethodTable.NewSizeFor(ACount: integer
  ): integer;
var
  t: TVmtMethodTable;
begin
  t.Count := 1;
  Result := (Pointer(t.Entry[0]) - Pointer(@t)) + SizeOf(TVmtMethodEntry) * ACount;
end;

class procedure TJitRttiWriterVmtMethodTable.AddSizeForShortStringPtr(
  var ASize: integer; const AMethName: String);
begin
  ASize := ASize + Length(AMethName) + 1;
end;

end.


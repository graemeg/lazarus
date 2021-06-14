{
 ---------------------------------------------------------------------------
 fpdbgdwarf.pas  -  Native Freepascal debugger - Dwarf symbol processing
 ---------------------------------------------------------------------------

 This unit contains helper classes for handling and evaluating of debuggee data
 described by DWARF debug symbols

 ---------------------------------------------------------------------------

 @created(Mon Aug 1st WET 2006)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.nl>)
 @author(Martin Friebe)

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
}
unit FpDbgDwarf;

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}
{off $INLINE OFF}

(* Notes:

   * FpDbgDwarfValues and Context
     The Values do not add a reference to the Context. Yet they require the Context.
     It is the users responsibility to keep the context, as long as any value exists.

*)

interface

uses
  Classes, SysUtils, types, math, FpDbgInfo, FpDbgDwarfDataClasses,
  FpdMemoryTools, FpErrorMessages, FpDbgUtil, FpDbgDwarfConst, FpDbgCommon,
  DbgIntfBaseTypes, LazUTF8, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazClasses;

type
  TFpDwarfInfo = FpDbgDwarfDataClasses.TFpDwarfInfo;

  { TFpDwarfDefaultSymbolClassMap }

  TFpDwarfDefaultSymbolClassMap = class(TFpSymbolDwarfClassMap)
  private
    class var ExistingClassMap: TFpSymbolDwarfClassMap;
  protected
    class function GetExistingClassMap: PFpDwarfSymbolClassMap; override;
  public
    class function ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;
  public
    //function CanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;
    function GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass; override;
    function CreateScopeForSymbol(ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol; ADwarf: TFpDwarfInfo): TFpDbgSymbolScope; override;
    function CreateProcSymbol(ACompilationUnit: TDwarfCompilationUnit;
      AInfo: PDwarfAddressInfo; AAddress: TDbgPtr; ADbgInfo: TFpDwarfInfo): TDbgDwarfSymbolBase; override;
    function CreateUnitSymbol(ACompilationUnit: TDwarfCompilationUnit;
      AInfoEntry: TDwarfInformationEntry; ADbgInfo: TFpDwarfInfo): TDbgDwarfSymbolBase; override;
  end;

  TFpValueDwarf = class;
  TFpSymbolDwarf = class;
  TFpDwarfInfoSymbolScope = class;

  TDwarfCompilationUnitArray = array of TDwarfCompilationUnit;

  { TFpThreadWorkerFindSymbolInUnits }

  TFpThreadWorkerFindSymbolInUnits = class(TFpThreadWorkerItem)
  protected
    FScope: TFpDwarfInfoSymbolScope;
    FCUs: TDwarfCompilationUnitArray;
    FNameInfo: TNameSearchInfo;

    FFoundInfoEntry: TDwarfInformationEntry;
    FIsExt: Boolean;
    procedure DoExecute; override;
  public
    constructor Create(AScope: TFpDwarfInfoSymbolScope; CUs: TDwarfCompilationUnitArray; const ANameInfo: TNameSearchInfo);
    destructor Destroy; override;
  end;

  { TFpDwarfInfoSymbolScope }

  TFpDwarfInfoSymbolScope = class(TFpDbgSymbolScope)
  private
    FSymbol: TFpSymbolDwarf;
    FSelfParameter: TFpValueDwarf;
    FAddress: TDBGPtr;  // same as LocationContext.Address
    FDwarf: TFpDwarfInfo;
  protected
    function GetSymbolAtAddress: TFpSymbol; override;
    function GetProcedureAtAddress: TFpValue; override;
    function GetSizeOfAddress: Integer; override;
    function GetMemManager: TFpDbgMemManager; override;

    property Symbol: TFpSymbolDwarf read FSymbol;
    property Dwarf: TFpDwarfInfo read FDwarf;

    procedure ApplyContext(AVal: TFpValue); inline;
    function SymbolToValue(ASym: TFpSymbolDwarf): TFpValue; inline;
    function GetSelfParameter: TFpValueDwarf;

    function FindExportedSymbolInUnit(CU: TDwarfCompilationUnit; const ANameInfo: TNameSearchInfo;
      out AnInfoEntry: TDwarfInformationEntry; out AnIsExternal: Boolean): Boolean; inline;
    function FindExportedSymbolInUnits(const AName: String; const ANameInfo: TNameSearchInfo;
      SkipCompUnit: TDwarfCompilationUnit; out ADbgValue: TFpValue; const OnlyUnitNameLower: String = ''): Boolean;
    function FindSymbolInStructure(const AName: String; const ANameInfo: TNameSearchInfo;
      InfoEntry: TDwarfInformationEntry; out ADbgValue: TFpValue): Boolean; inline;
    // FindLocalSymbol: for the subroutine itself
    function FindLocalSymbol(const AName: String; const ANameInfo: TNameSearchInfo;
      InfoEntry: TDwarfInformationEntry; out ADbgValue: TFpValue): Boolean; virtual;
  public
    constructor Create(ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol; ADwarf: TFpDwarfInfo);
    destructor Destroy; override;
    function FindSymbol(const AName: String; const OnlyUnitName: String = ''): TFpValue; override;
  end;

  TFpSymbolDwarfType = class;
  TFpSymbolDwarfData = class;
  TFpSymbolDwarfDataClass = class of TFpSymbolDwarfData;
  TFpSymbolDwarfTypeClass = class of TFpSymbolDwarfType;

  PFpSymbolDwarfData = ^TFpSymbolDwarfData;

{%region Value objects }

  { TFpValueDwarfBase }

  TFpValueDwarfBase = class(TFpValue)
  strict private
    FLocContext: TFpDbgLocationContext;
    procedure SetContext(AValue: TFpDbgLocationContext);
  public
    destructor Destroy; override;
    property Context: TFpDbgLocationContext read FLocContext write SetContext;
  end;

  { TFpValueDwarfTypeDefinition }

  TFpValueDwarfTypeDefinition = class(TFpValueDwarfBase)
  private
    FSymbol: TFpSymbolDwarf; // stType
  protected
    function GetKind: TDbgSymbolKind; override;
    function GetDbgSymbol: TFpSymbol; override;

    function GetMemberCount: Integer; override;
    function GetMemberByName(const AIndex: String): TFpValue; override;
    function GetMember(AIndex: Int64): TFpValue; override;
  public
    constructor Create(ASymbol: TFpSymbolDwarf); // Only for stType
    destructor Destroy; override;
    function GetTypeCastedValue(ADataVal: TFpValue): TFpValue; override;
  end;

  { TFpValueDwarf }

  TFpValueDwarf = class(TFpValueDwarfBase)
  private
    FTypeSymbol: TFpSymbolDwarfType;        // the creator, usually the type
    FDataSymbol: TFpSymbolDwarfData;
    FTypeCastSourceValue: TFpValue;

    FCachedAddress, FCachedDataAddress: TFpDbgMemLocation;
    (* FParentTypeSymbol
       Container of any Symbol returned by GetNestedSymbol. (Set by GetNestedValue only)
         E.g. For Members: the class in which they are declared (in case StructureValue is inherited)
         Also: Enums, Array (others may set this but not used)
       FParentTypeSymbol is hold as part of the type chain in FTypeSymbol // Therefore it does not need AddReference
    *)
    FParentTypeSymbol: TFpSymbolDwarfType;
    FStructureValue: TFpValueDwarf;
    FForcedSize: TFpDbgValueSize; // for typecast from array member
    procedure SetStructureValue(AValue: TFpValueDwarf);
  protected
    function GetSizeFor(AnOtherValue: TFpValue; out ASize: TFpDbgValueSize): Boolean; inline;
    function AddressSize: Byte; inline;

    // Address of the symbol (not followed any type deref, or location)
    function GetAddress: TFpDbgMemLocation; override;
    function DoGetSize(out ASize: TFpDbgValueSize): Boolean; override;
    function OrdOrAddress: TFpDbgMemLocation;
    // Address of the data (followed type deref, location, ...)
    function OrdOrDataAddr: TFpDbgMemLocation;
    function GetDataAddress: TFpDbgMemLocation; override;
    function GetDwarfDataAddress(out AnAddress: TFpDbgMemLocation; ATargetType: TFpSymbolDwarfType = nil): Boolean;
    function GetStructureDwarfDataAddress(out AnAddress: TFpDbgMemLocation;
                                          ATargetType: TFpSymbolDwarfType = nil): Boolean;

    procedure Reset; override; // keeps lastmember and structureninfo
    function GetFieldFlags: TFpValueFieldFlags; override;
    function HasTypeCastInfo: Boolean;
    function IsValidTypeCast: Boolean; virtual;
    function GetKind: TDbgSymbolKind; override;
    function GetMemberCount: Integer; override;
    function GetMemberByName(const AIndex: String): TFpValue; override;
    function GetMember(AIndex: Int64): TFpValue; override;
    function GetDbgSymbol: TFpSymbol; override;
    function GetTypeInfo: TFpSymbol; override;
    function GetParentTypeInfo: TFpSymbol; override;

    property TypeCastSourceValue: TFpValue read FTypeCastSourceValue;
  public
    constructor Create(ADwarfTypeSymbol: TFpSymbolDwarfType);
    destructor Destroy; override;
    property TypeInfo: TFpSymbolDwarfType read FTypeSymbol;
    function MemManager: TFpDbgMemManager; inline;
    procedure SetDataSymbol(AValueSymbol: TFpSymbolDwarfData);
    function  SetTypeCastInfo(ASource: TFpValue): Boolean; // Used for Typecast
    // StructureValue: Any Value returned via GetMember points to its structure
    property StructureValue: TFpValueDwarf read FStructureValue write SetStructureValue;
  end;

  TFpValueDwarfUnknown = class(TFpValueDwarf)
  end;

  { TFpValueDwarfSized }

  TFpValueDwarfSized = class(TFpValueDwarf)
  protected
    function CanUseTypeCastAddress: Boolean;
    function GetFieldFlags: TFpValueFieldFlags; override;
  end;

  { TFpValueDwarfNumeric }

  TFpValueDwarfNumeric = class(TFpValueDwarfSized)
  protected
    FEvaluated: set of (doneUInt, doneInt, doneAddr, doneFloat);
  protected
    procedure Reset; override;
    function GetFieldFlags: TFpValueFieldFlags; override; // svfOrdinal
    function IsValidTypeCast: Boolean; override;
  public
    constructor Create(ADwarfTypeSymbol: TFpSymbolDwarfType);
  end;

  { TFpValueDwarfInteger }

  TFpValueDwarfInteger = class(TFpValueDwarfNumeric)
  private
    FIntValue: Int64;
  protected
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsCardinal: QWord; override;
    function GetAsInteger: Int64; override;
    procedure SetAsInteger(AValue: Int64); override;
    procedure SetAsCardinal(AValue: QWord); override;
  end;

  { TFpValueDwarfCardinal }

  TFpValueDwarfCardinal = class(TFpValueDwarfNumeric)
  private
    FValue: QWord;
  protected
    function GetAsCardinal: QWord; override;
    function GetAsInteger: Int64; override;
    procedure SetAsCardinal(AValue: QWord); override;
    function GetFieldFlags: TFpValueFieldFlags; override;
  end;

  { TFpValueDwarfFloat }

  TFpValueDwarfFloat = class(TFpValueDwarfNumeric) // TDbgDwarfSymbolValue
  // TODO: typecasts to int should convert
  private
    FValue: Extended;
  protected
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsFloat: Extended; override;
  end;

  { TFpValueDwarfBoolean }

  TFpValueDwarfBoolean = class(TFpValueDwarfCardinal)
  protected
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsBool: Boolean; override;
    procedure SetAsBool(AValue: Boolean); override;
  end;

  { TFpValueDwarfChar }

  TFpValueDwarfChar = class(TFpValueDwarfCardinal)
  protected
    // returns single char(byte) / widechar
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsString: AnsiString; override;
    function GetAsWideString: WideString; override;
    procedure SetAsString(AValue: AnsiString); override;
  end;

  { TFpValueDwarfPointer }

  TFpValueDwarfPointer = class(TFpValueDwarfNumeric)
  private
    FPointedToAddr: TFpDbgMemLocation;
    function GetDerefAddress: TFpDbgMemLocation;
  protected
    function GetAsCardinal: QWord; override;
    procedure SetAsCardinal(AValue: QWord); override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetDataAddress: TFpDbgMemLocation; override;
    function GetAsString: AnsiString; override;
    function GetAsWideString: WideString; override;
    function GetMember(AIndex: Int64): TFpValue; override;
  end;

  { TFpValueDwarfEnum }

  TFpValueDwarfEnum = class(TFpValueDwarfNumeric)
  private
    FValue: QWord;
    FMemberIndex: Integer;
    FMemberValueDone: Boolean;
    procedure InitMemberIndex;
  protected
    procedure Reset; override;
    //function IsValidTypeCast: Boolean; override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsCardinal: QWord; override;
    procedure SetAsCardinal(AValue: QWord); override;
    function GetAsString: AnsiString; override;
    procedure SetAsString(AValue: AnsiString); override;
    // Has exactly 0 (if the ordinal value is out of range) or 1 member (the current value's enum)
    function GetMemberCount: Integer; override;
    function GetMember({%H-}AIndex: Int64): TFpValue; override;
  end;

  { TFpValueDwarfEnumMember }

  TFpValueDwarfEnumMember = class(TFpValueDwarf)
  private
    FOwnerVal: TFpSymbolDwarfData;
  protected
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsCardinal: QWord; override;
    function GetAsString: AnsiString; override;
    function IsValidTypeCast: Boolean; override;
    function GetKind: TDbgSymbolKind; override;
  public
    constructor Create(AOwner: TFpSymbolDwarfData);
  end;

  { TFpValueDwarfConstNumber }

  TFpValueDwarfConstNumber = class(TFpValueConstNumber)
  protected
    procedure Update(AValue: QWord; ASigned: Boolean);
  end;

  { TFpValueDwarfSet }

  TFpValueDwarfSet = class(TFpValueDwarfSized)
  private
    FMem: array of Byte;
    FMemberCount: Integer;
    FMemberMap: array of Integer;
    FNumValue: TFpValueDwarfConstNumber;
    FTypedNumValue: TFpValue;
    procedure InitMap;
  protected
    procedure Reset; override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetMemberCount: Integer; override;
    function GetMember(AIndex: Int64): TFpValue; override;
    function GetAsCardinal: QWord; override; // only up to qmord
    function IsValidTypeCast: Boolean; override;
    procedure SetAsString(AValue: AnsiString); override;
  public
    destructor Destroy; override;
  end;

  { TFpValueDwarfStruct }

  { TFpValueDwarfStructBase }

  TFpValueDwarfStructBase = class(TFpValueDwarf)
  protected
    function GetMember(AIndex: Int64): TFpValue; override;
    function GetMemberByName(const AIndex: String): TFpValue; override;
  end;

  TFpValueDwarfStruct = class(TFpValueDwarfStructBase)
  private
    FDataAddressDone: Boolean;
  protected
    procedure Reset; override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsCardinal: QWord; override;
    procedure SetAsCardinal(AValue: QWord); override;
    function GetDataSize: TFpDbgValueSize; override;
    function IsValidTypeCast: Boolean; override;
  end;

  { TFpValueDwarfConstAddress }

  TFpValueDwarfConstAddress = class(TFpValueConstAddress)
  protected
    procedure Update(AnAddress: TFpDbgMemLocation);
  end;

  { TFpValueDwarfArray }
  TFpSymbolDwarfTypeArray = class;

  TFpValueDwarfArray = class(TFpValueDwarf)
  private
    FEvalFlags: set of (efMemberSizeDone, efMemberSizeUnavail,
                        efStrideDone, efStrideUnavail,
                        efMainStrideDone, efMainStrideUnavail,
                        efRowMajorDone, efRowMajorUnavail,
                        efBoundsDone, efBoundsUnavail);
    FAddrObj: TFpValueDwarfConstAddress;
    FArraySymbol: TFpSymbolDwarfTypeArray;
    FLastMember: TFpValueDwarf;
    FRowMajor: Boolean;
    FMemberSize: TFpDbgValueSize;
    FStride, FMainStride: TFpDbgValueSize;
    FStrides: array of bitpacked record Stride: TFpDbgValueSize; Done, Unavail: Boolean; end; // nested idx
    FBounds: array of array[0..1] of int64;
    procedure DoGetBounds; virtual;
  protected
    procedure Reset; override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetKind: TDbgSymbolKind; override;
    function GetAsCardinal: QWord; override;
    function GetMember(AIndex: Int64): TFpValue; override;
    function GetMemberEx(const AIndex: array of Int64): TFpValue; override;
    function GetMemberCount: Integer; override;
    function GetMemberCountEx(const AIndex: array of Int64): Integer; override;
    function GetHasBounds: Boolean; override;
    function GetOrdLowBound: Int64; override;
    function GetOrdHighBound: Int64; override;
    function GetIndexType(AIndex: Integer): TFpSymbol; override;
    function GetIndexTypeCount: Integer; override;
    function IsValidTypeCast: Boolean; override;
    function DoGetOrdering(out ARowMajor: Boolean): Boolean; virtual;
    function DoGetStride(out AStride: TFpDbgValueSize): Boolean; virtual;
    function DoGetMemberSize(out ASize: TFpDbgValueSize): Boolean; virtual; // array.stride or typeinfe.size
    function DoGetMainStride(out AStride: TFpDbgValueSize): Boolean; virtual;
    function DoGetDimStride(AnIndex: integer; out AStride: TFpDbgValueSize): Boolean; virtual;
  public
    constructor Create(ADwarfTypeSymbol: TFpSymbolDwarfType; AnArraySymbol :TFpSymbolDwarfTypeArray);
    destructor Destroy; override;
    function GetOrdering(out ARowMajor: Boolean): Boolean; inline;
    function GetStride(out AStride: TFpDbgValueSize): Boolean; inline; // UnAdjusted Stride
    function GetMemberSize(out ASize: TFpDbgValueSize): Boolean; inline;  // array.stride or typeinfe.size
    function GetMainStride(out AStride: TFpDbgValueSize): Boolean; inline; // Most inner idx
    function GetDimStride(AnIndex: integer; out AStride: TFpDbgValueSize): Boolean; inline; // outer idx // AnIndex start at 1
  end;

  { TFpValueDwarfSubroutine }

  TFpValueDwarfSubroutine = class(TFpValueDwarf)
  protected
    function IsValidTypeCast: Boolean; override;
  end;
{%endregion Value objects }

{%region Symbol objects }

  TInitLocParserData = record
    (* DW_AT_data_member_location: Is always pushed on stack
       DW_AT_data_location: Is avalibale for DW_OP_push_object_address
    *)
    ObjectDataAddress: TFpDbgMemLocation;
    ObjectDataAddrPush: Boolean; // always push ObjectDataAddress on stack: DW_AT_data_member_location
  end;
  PInitLocParserData = ^TInitLocParserData;

  (* TFpDwarfAtEntryDataReadState
     Since Dwarf-3 several DW_AT_* can be const, expression or reference.
  *)
  TFpDwarfAtEntryDataReadState = (rfNotRead, rfNotFound, rfError, rfConst, rfValue, rfExpression);
  PFpDwarfAtEntryDataReadState = ^TFpDwarfAtEntryDataReadState;

  { TFpSymbolDwarf }

  TFpSymbolDwarf = class(TDbgDwarfSymbolBase)
  private
    FNestedTypeInfo: TFpSymbolDwarfType;
    (* FLocalProcInfo: the procedure in which a local symbol is defined/used *)
    FLocalProcInfo: TFpSymbolDwarf;
    FDwarfReadFlags: set of (didtNameRead, didtTypeRead, didtArtificialRead, didtIsArtifical);
    function GetNestedTypeInfo: TFpSymbolDwarfType;
    function GetTypeInfo: TFpSymbolDwarfType; inline;
  protected
    procedure SetLocalProcInfo(AValue: TFpSymbolDwarf); virtual;

    function  DoGetNestedTypeInfo: TFpSymbolDwarfType; virtual;
    function  ReadMemberVisibility(out AMemberVisibility: TDbgSymbolMemberVisibility): Boolean;
    function  IsArtificial: Boolean; // usud by formal param and subprogram
    procedure NameNeeded; override;
    procedure TypeInfoNeeded; override;
    property NestedTypeInfo: TFpSymbolDwarfType read GetNestedTypeInfo;

    // LocalProcInfo: funtion for local var / param
    property LocalProcInfo: TFpSymbolDwarf read FLocalProcInfo write SetLocalProcInfo;

    function DoForwardReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; inline;
    function DoReadDataSize(const AValueObj: TFpValue; out ADataSize: TFpDbgValueSize): Boolean; virtual;
  protected
    function InitLocationParser(const {%H-}ALocationParser: TDwarfLocationExpression;
                                AnInitLocParserData: PInitLocParserData = nil): Boolean; virtual;
    function ComputeDataMemberAddress(const AnInformationEntry: TDwarfInformationEntry;
                              AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation): Boolean; inline;
    function ConstRefOrExprFromAttrData(const AnAttribData: TDwarfAttribData;
                              AValueObj: TFpValueDwarf; out AValue: Int64;
                              AReadState: PFpDwarfAtEntryDataReadState = nil;
                              ADataSymbol: PFpSymbolDwarfData = nil): Boolean;
    function  LocationFromAttrData(const AnAttribData: TDwarfAttribData; AValueObj: TFpValueDwarf;
                              var AnAddress: TFpDbgMemLocation; // kept, if tag does not exist
                              AnInitLocParserData: PInitLocParserData = nil;
                              AnAdjustAddress: Boolean = False
                             ): Boolean;
    function  LocationFromTag(ATag: Cardinal; AValueObj: TFpValueDwarf;
                              var AnAddress: TFpDbgMemLocation; // kept, if tag does not exist
                              AnInitLocParserData: PInitLocParserData = nil;
                              ASucessOnMissingTag: Boolean = False
                             ): Boolean; // deprecated
    function  ConstantFromTag(ATag: Cardinal; out AConstData: TByteDynArray;
                              var AnAddress: TFpDbgMemLocation; // kept, if tag does not exist
                              AnInformationEntry: TDwarfInformationEntry = nil;
                              ASucessOnMissingTag: Boolean = False
                             ): Boolean;
    // GetDataAddress: data of a class, or string
    function GetDataAddress(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
                            ATargetType: TFpSymbolDwarfType = nil): Boolean;
    function GetNextTypeInfoForDataAddress(ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType; virtual;
    function GetDataAddressNext(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
      out ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean; virtual;
    function HasAddress: Boolean; virtual;

    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; virtual;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; virtual;
    function GetNestedSymbol(AIndex: Int64): TFpSymbol; override;
    function GetNestedSymbolByName(const AIndex: String): TFpSymbol; override;

    procedure Init; override;
  public
    class function CreateSubClass(const AName: String; AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarf;
    destructor Destroy; override;
    function GetNestedValue(AIndex: Int64): TFpValueDwarf; inline;
    function GetNestedValueByName(const AIndex: String): TFpValueDwarf; inline;
    function StartScope: TDbgPtr; // return 0, if none. 0 includes all anyway
    property TypeInfo: TFpSymbolDwarfType read GetTypeInfo;
  end;

  { TFpSymbolDwarfData }

  TFpSymbolDwarfData = class(TFpSymbolDwarf) // var, const, member, ...
  protected
    function GetValueAddress({%H-}AValueObj: TFpValueDwarf;{%H-} out AnAddress: TFpDbgMemLocation): Boolean; virtual;
    procedure KindNeeded; override;
    procedure MemberVisibilityNeeded; override;

    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;

    procedure Init; override;
  public
    class function CreateValueSubClass(const AName: String; AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarfData;
  end;

  { TFpSymbolDwarfDataWithLocation }

  TFpSymbolDwarfDataWithLocation = class(TFpSymbolDwarfData)
  private
    procedure FrameBaseNeeded(ASender: TObject); // Sender = TDwarfLocationExpression
  protected
    function GetValueObject: TFpValue; override;
    function InitLocationParser(const ALocationParser: TDwarfLocationExpression;
                                AnInitLocParserData: PInitLocParserData): Boolean; override;
  end;

  { TFpSymbolDwarfFunctionResult }

  TFpSymbolDwarfFunctionResult = class(TFpSymbolDwarfDataWithLocation)
  protected
    function GetValueAddress(AValueObj: TFpValueDwarf; out AnAddress: TFpDbgMemLocation): Boolean; override;
    procedure Init; override;
  end;

  TFpSymbolDwarfThirdPartyExtension = class(TFpSymbolDwarf)
  end;

  { TFpSymbolDwarfType }

  (* Types and allowed tags in dwarf 2

  DW_TAG_enumeration_type, DW_TAG_subroutine_type, DW_TAG_union_type,
  DW_TAG_ptr_to_member_type, DW_TAG_set_type, DW_TAG_subrange_type, DW_TAG_file_type,
  DW_TAG_thrown_type

                          DW_TAG_base_type
  DW_AT_encoding          Y
  DW_AT_bit_offset        Y
  DW_AT_bit_size          Y

                          DW_TAG_base_type
                          |  DW_TAG_typedef
                          |  |   DW_TAG_string_type
                          |  |   |  DW_TAG_array_type
                          |  |   |  |
                          |  |   |  |    DW_TAG_class_type
                          |  |   |  |    |  DW_TAG_structure_type
                          |  |   |  |    |  |
                          |  |   |  |    |  |    DW_TAG_enumeration_type
                          |  |   |  |    |  |    |  DW_TAG_set_type
                          |  |   |  |    |  |    |  |  DW_TAG_enumerator
                          |  |   |  |    |  |    |  |  |  DW_TAG_subrange_type
  DW_AT_name              Y  Y   Y  Y    Y  Y    Y  Y  Y  Y
  DW_AT_sibling           Y  Y   Y  Y    Y  Y    Y  Y  Y  Y
  DECL                       Y   Y  Y    Y  Y    Y  Y  Y  Y
  DW_AT_byte_size         Y      Y  Y    Y  Y    Y  Y     Y
  DW_AT_abstract_origin      Y   Y  Y    Y  Y    Y  Y     Y
  DW_AT_accessibility        Y   Y  Y    Y  Y    Y  Y     Y
  DW_AT_declaration          Y   Y  Y    Y  Y    Y  Y     Y
  DW_AT_start_scope          Y   Y  Y    Y  Y    Y  Y
  DW_AT_visibility           Y   Y  Y    Y  Y    Y  Y     Y
  DW_AT_type                 Y      Y               Y     Y
  DW_AT_segment                  Y                              DW_TAG_string_type
  DW_AT_string_length            Y
  DW_AT_ordering                    Y                           DW_TAG_array_type
  DW_AT_stride_size                 Y
  DW_AT_const_value                                    Y        DW_TAG_enumerator
  DW_AT_count                                             Y     DW_TAG_subrange_type
  DW_AT_lower_bound                                       Y
  DW_AT_upper_bound                                       Y

                           DW_TAG_pointer_type
                           |  DW_TAG_reference_type
                           |  |  DW_TAG_packed_type
                           |  |  |  DW_TAG_const_type
                           |  |  |  |  DW_TAG_volatile_type
  DW_AT_address_class      Y  Y
  DW_AT_sibling            Y  Y  Y  Y Y
  DW_AT_type               Y  Y  Y  Y Y

DECL = DW_AT_decl_column, DW_AT_decl_file, DW_AT_decl_line
  *)

  TFpSymbolDwarfType = class(TFpSymbolDwarf)
  protected
    procedure Init; override;
    procedure MemberVisibilityNeeded; override;
    function  DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
    function DoReadStride(AValueObj: TFpValueDwarf; out AStride: TFpDbgValueSize): Boolean; virtual;
  public
    (* GetTypedValueObject
       AnOuterType: If the type is a "chain" (Declaration > Pointer > ActualType)
                    then Result.Owner will be set to the outer most type
       Result.Owner: will not be refcounted. ??? (Hold via the FDataSymbol...)
       Result: Is returned with a RefCount of 1. This ref has to be released by the caller.
    *)
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; virtual;
    class function CreateTypeSubClass(const AName: String; AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarfType;
    function TypeCastValue(AValue: TFpValue): TFpValue; override;

    (*TODO: workaround / quickfix // only partly implemented
      When reading several elements of an array (dyn or stat), the typeinfo is always the same instance (type of array entry)
      But once that instance has read data (like bounds / dwarf3 bounds are read from app mem), this is cached.
      So all consecutive entries get the same info...
        array of string
        array of shortstring
        array of {dyn} array
      This works similar to "Init", but should only clear data that is not static / depends on memory reads

      Bounds (and maybe all such data) should be stored on the value object)
    *)
    procedure ResetValueBounds; virtual;
    function ReadStride(AValueObj: TFpValueDwarf; out AStride: TFpDbgValueSize): Boolean; inline;
  end;

  { TFpSymbolDwarfTypeBasic }

  TFpSymbolDwarfTypeBasic = class(TFpSymbolDwarfType)
  //function DoGetNestedTypeInfo: TFpSymbolDwarfType; // return nil
  protected
    procedure KindNeeded; override;
    procedure TypeInfoNeeded; override;
  public
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
    function GetValueBounds(AValueObj: TFpValue; out ALowBound,
      AHighBound: Int64): Boolean; override;
    function GetValueLowBound(AValueObj: TFpValue; out ALowBound: Int64): Boolean; override;
    function GetValueHighBound(AValueObj: TFpValue; out AHighBound: Int64): Boolean; override;
  end;

  { TFpSymbolDwarfTypeModifierBase }

  TFpSymbolDwarfTypeModifierBase = class(TFpSymbolDwarfType)
  protected
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbol(AIndex: Int64): TFpSymbol; override;
    function GetNestedSymbolByName(const AIndex: String): TFpSymbol; override;
  end;

  { TFpSymbolDwarfTypeModifier }

  TFpSymbolDwarfTypeModifier = class(TFpSymbolDwarfTypeModifierBase)
  protected
    procedure TypeInfoNeeded; override;
    procedure ForwardToSymbolNeeded; override;
    function DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
    function DoReadStride(AValueObj: TFpValueDwarf; out AStride: TFpDbgValueSize): Boolean; override;
    function GetNextTypeInfoForDataAddress(ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType; override;
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpSymbolDwarfTypeRef }

  TFpSymbolDwarfTypeRef = class(TFpSymbolDwarfTypeModifier)
  protected
    function GetFlags: TDbgSymbolFlags; override;
    function GetDataAddressNext(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
      out ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean; override;
  end;

  { TFpSymbolDwarfTypeDeclaration }

  TFpSymbolDwarfTypeDeclaration = class(TFpSymbolDwarfTypeModifier)
  end;

  { TFpSymbolDwarfTypeSubRange }

  TFpSymbolDwarfTypeSubRange = class(TFpSymbolDwarfTypeModifierBase)
  // TODO not a modifier, maybe have a forwarder base class
  private
    FLowBoundConst: Int64;
    FLowBoundSymbol: TFpSymbolDwarfData;
    FLowBoundState: TFpDwarfAtEntryDataReadState;
    FHighBoundConst: Int64;
    FHighBoundSymbol: TFpSymbolDwarfData;
    FHighBoundState: TFpDwarfAtEntryDataReadState;
    FCountConst: Int64;
    FCountSymbol: TFpSymbolDwarfData;
    FCountState: TFpDwarfAtEntryDataReadState;
    FLowEnumIdx, FHighEnumIdx: Integer;
    FEnumIdxValid: Boolean;
    procedure InitEnumIdx;
  protected
    function DoGetNestedTypeInfo: TFpSymbolDwarfType; override;
    procedure ForwardToSymbolNeeded; override;
    procedure TypeInfoNeeded; override;

    procedure NameNeeded; override;
    procedure KindNeeded; override;
    function  DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;
    function GetFlags: TDbgSymbolFlags; override;
    procedure Init; override;
  public
    procedure ResetValueBounds; override;
    destructor Destroy; override;

    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
    function GetValueBounds(AValueObj: TFpValue; out ALowBound, AHighBound: Int64): Boolean; override;
    function GetValueLowBound(AValueObj: TFpValue; out ALowBound: Int64): Boolean; override;
    function GetValueHighBound(AValueObj: TFpValue; out AHighBound: Int64): Boolean; override;
    property LowBoundState: TFpDwarfAtEntryDataReadState read FLowBoundState; deprecated;
    property HighBoundState: TFpDwarfAtEntryDataReadState read FHighBoundState;  deprecated;
    property CountState: TFpDwarfAtEntryDataReadState read FCountState;  deprecated;

  end;

  { TFpSymbolDwarfTypePointer }

  TFpSymbolDwarfTypePointer = class(TFpSymbolDwarfTypeModifierBase)
  protected
    procedure KindNeeded; override;
    function  DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpSymbolDwarfTypeSubroutine }

  TFpSymbolDwarfTypeSubroutine = class(TFpSymbolDwarfType)
  private
    FProcMembers: TRefCntObjList;
    FLastMember: TFpSymbol;
    procedure CreateMembers;
  protected
    //copied from TFpSymbolDwarfDataProc
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String;
      out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;

    // TODO: deal with DW_TAG_pointer_type
    function GetDataAddressNext(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
      out ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean; override;
    procedure KindNeeded; override;
    function DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
  public
    destructor Destroy; override;
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpSymbolDwarfDataEnumMember }

  TFpSymbolDwarfDataEnumMember  = class(TFpSymbolDwarfData)
    FOrdinalValue: Int64;
    FOrdinalValueRead, FHasOrdinalValue: Boolean;
    procedure ReadOrdinalValue;
  protected
    procedure KindNeeded; override;
    function GetHasOrdinalValue: Boolean; override;
    function GetOrdinalValue: Int64; override;
    procedure Init; override;
    function GetValueObject: TFpValue; override;
  end;


  { TFpSymbolDwarfTypeEnum }

  TFpSymbolDwarfTypeEnum = class(TFpSymbolDwarfType)
  private
    FMembers: TRefCntObjList;
    procedure CreateMembers;
  protected
    procedure KindNeeded; override;
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;
  public
    destructor Destroy; override;
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
    function GetValueBounds(AValueObj: TFpValue; out ALowBound,
      AHighBound: Int64): Boolean; override;
    function GetValueLowBound(AValueObj: TFpValue; out ALowBound: Int64): Boolean; override;
    function GetValueHighBound(AValueObj: TFpValue; out AHighBound: Int64): Boolean; override;
  end;


  { TFpSymbolDwarfTypeSet }

  TFpSymbolDwarfTypeSet = class(TFpSymbolDwarfType)
  protected
    procedure KindNeeded; override;
    function GetNestedSymbolCount: Integer; override;
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
  public
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;


  { TFpSymbolDwarfDataMember }

  TFpSymbolDwarfDataMember = class(TFpSymbolDwarfDataWithLocation)
  private
    FConstData: TByteDynArray;
  protected
    function DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
    function GetValueAddress(AValueObj: TFpValueDwarf; out AnAddress: TFpDbgMemLocation): Boolean; override;
    function HasAddress: Boolean; override;
  end;

  { TFpSymbolDwarfTypeStructure }

  TFpSymbolDwarfTypeStructure = class(TFpSymbolDwarfType)
  // record or class
  private
    FMembers: TRefCntObjList;
    FLastChildByName: TFpSymbolDwarf;
    FInheritanceInfo: TDwarfInformationEntry;
    procedure CreateMembers;
    procedure InitInheritanceInfo; inline;
  protected
    function DoGetNestedTypeInfo: TFpSymbolDwarfType; override;
    procedure KindNeeded; override;

    // GetNestedSymbolEx, if AIndex > Count then parent
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;

    function GetDataAddressNext(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
      out ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean; override;
  public
    destructor Destroy; override;
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpSymbolDwarfTypeArray }

  TFpSymbolDwarfTypeArray = class(TFpSymbolDwarfType)
  private
    FMembers: TRefCntObjList;
    procedure CreateMembers;
  protected
    procedure KindNeeded; override;
    function DoReadOrdering(AValueObj: TFpValueDwarf; out ARowMajor: Boolean): Boolean;

    function GetFlags: TDbgSymbolFlags; override;
    // GetNestedSymbolEx: returns the TYPE/range of each index. NOT the data
    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;
    function GetMemberAddress(AValueObj: TFpValueDwarf; const AIndex: Array of Int64): TFpDbgMemLocation;
  public
    destructor Destroy; override;
    function GetTypedValueObject({%H-}ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
    procedure ResetValueBounds; override;
  end;

  { TFpSymbolDwarfDataProc }

  TFpSymbolDwarfDataProc = class(TFpSymbolDwarfData)
  private
    //FCU: TDwarfCompilationUnit;
    FAddress: TDbgPtr;
    FAddressInfo: PDwarfAddressInfo;
    FStateMachine: TDwarfLineInfoStateMachine;
    FFrameBaseParser: TDwarfLocationExpression;
    FDwarf: TFpDwarfInfo;
    function GetLineEndAddress: TDBGPtr;
    function GetLineStartAddress: TDBGPtr;
    function GetLineUnfixed: TDBGPtr;
    function StateMachineValid: Boolean;
    function  ReadVirtuality(out AFlags: TDbgSymbolFlags): Boolean;
  protected
    function GetFrameBase(ASender: TDwarfLocationExpression): TDbgPtr;
    function GetFlags: TDbgSymbolFlags; override;
    procedure TypeInfoNeeded; override;

    function GetParent: TFpSymbol; override;
    function GetColumn: Cardinal; override;
    function GetFile: String; override;
//    function GetFlags: TDbgSymbolFlags; override;
    function GetLine: Cardinal; override;
    function GetValueObject: TFpValue; override;
    function GetValueAddress(AValueObj: TFpValueDwarf; out
      AnAddress: TFpDbgMemLocation): Boolean; override;
  public
    constructor Create(ACompilationUnit: TDwarfCompilationUnit; AInfo: PDwarfAddressInfo; AAddress: TDbgPtr; ADbgInfo: TFpDwarfInfo = nil); overload;
    destructor Destroy; override;
    function CreateSymbolScope(ALocationContext: TFpDbgLocationContext): TFpDbgSymbolScope; override;
    function CreateSymbolScope(ALocationContext: TFpDbgLocationContext; ADwarfInfo: TFpDwarfInfo): TFpDbgSymbolScope; override;
    // TODO members = locals ?
    function GetSelfParameter(AnAddress: TDbgPtr = 0): TFpValueDwarf;
    // Contineous (sub-)part of the line
    property LineStartAddress: TDBGPtr read GetLineStartAddress;
    property LineEndAddress: TDBGPtr read GetLineEndAddress;
    property LineUnfixed: TDBGPtr read GetLineUnfixed; // with 0 lines
  end;

  { TFpSymbolDwarfTypeProc }

  TFpSymbolDwarfTypeProc = class(TFpSymbolDwarfType)
  private
    FAddressInfo: PDwarfAddressInfo;
    FLastMember: TFpSymbol;
    FProcMembers: TRefCntObjList; // Locals

    procedure CreateMembers;
  protected
    procedure NameNeeded; override;
    procedure KindNeeded; override;
    function  DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;

    function GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolExByName(const AIndex: String;
      out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
    function GetNestedSymbolCount: Integer; override;

  public
    constructor Create(const AName: String; AnInformationEntry: TDwarfInformationEntry; AInfo: PDwarfAddressInfo);
    destructor Destroy; override;
  end;

  { TFpSymbolDwarfDataVariable }

  TFpSymbolDwarfDataVariable = class(TFpSymbolDwarfDataWithLocation)
  private
    FConstData: TByteDynArray;
  protected
    function GetValueAddress(AValueObj: TFpValueDwarf; out AnAddress: TFpDbgMemLocation): Boolean; override;
    function HasAddress: Boolean; override;
  public
  end;

  { TFpSymbolDwarfDataParameter }

  TFpSymbolDwarfDataParameter = class(TFpSymbolDwarfDataWithLocation)
  protected
    function GetValueAddress(AValueObj: TFpValueDwarf; out AnAddress: TFpDbgMemLocation): Boolean; override;
    function HasAddress: Boolean; override;
    function GetFlags: TDbgSymbolFlags; override;
  public
  end;

  { TFpSymbolDwarfUnit }

  TFpSymbolDwarfUnit = class(TFpSymbolDwarf)
  private
    FLastChildByName: TFpSymbol;
    FDwarf: TFpDwarfInfo;
  protected
    procedure Init; override;
    function GetNestedSymbolExByName(const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol; override;
  public
    constructor Create(const AName: String; AnInformationEntry: TDwarfInformationEntry; ADbgInfo: TFpDwarfInfo = nil); overload;
    destructor Destroy; override;
    function CreateSymbolScope(ALocationContext: TFpDbgLocationContext): TFpDbgSymbolScope; override;
    function CreateSymbolScope(ALocationContext: TFpDbgLocationContext; ADwarfInfo: TFpDwarfInfo): TFpDbgSymbolScope; override;
  end;
{%endregion Symbol objects }

function dbgs(ASubRangeBoundReadState: TFpDwarfAtEntryDataReadState): String; overload;

implementation

var
  DBG_WARNINGS, FPDBG_DWARF_VERBOSE, FPDBG_DWARF_ERRORS, FPDBG_DWARF_WARNINGS, FPDBG_DWARF_SEARCH, FPDBG_DWARF_DATA_WARNINGS: PLazLoggerLogGroup;

function dbgs(ASubRangeBoundReadState: TFpDwarfAtEntryDataReadState): String;
begin
  WriteStr(Result, ASubRangeBoundReadState);
end;

{ TFpValueDwarfBase }

procedure TFpValueDwarfBase.SetContext(AValue: TFpDbgLocationContext);
begin
  if FLocContext = AValue then Exit;
  if FLocContext <> nil then
    FLocContext.ReleaseReference;
  FLocContext := AValue;
  if FLocContext <> nil then
    FLocContext.AddReference;
end;

destructor TFpValueDwarfBase.Destroy;
begin
  inherited Destroy;
  if FLocContext <> nil then
    FLocContext.ReleaseReference;
end;

{ TFpSymbolDwarfFunctionResult }

function TFpSymbolDwarfFunctionResult.GetValueAddress(AValueObj: TFpValueDwarf; out AnAddress: TFpDbgMemLocation): Boolean;
begin
  AnAddress := Address;
  Result := IsInitializedLoc(AnAddress);
end;

procedure TFpSymbolDwarfFunctionResult.Init;
begin
  inherited Init;
  EvaluatedFields := EvaluatedFields + [sfiAddress];
end;

{ TFpValueDwarfStructBase }

function TFpValueDwarfStructBase.GetMember(AIndex: Int64): TFpValue;
begin
  Result := inherited GetMember(AIndex);
end;

function TFpValueDwarfStructBase.GetMemberByName(const AIndex: String
  ): TFpValue;
begin
  Result := inherited GetMemberByName(AIndex);

end;

{ TFpValueDwarfSubroutine }

function TFpValueDwarfSubroutine.IsValidTypeCast: Boolean;
var
  f: TFpValueFieldFlags;
  SrcSize: TFpDbgValueSize;
begin
  Result := HasTypeCastInfo;
  If not Result then
    exit;

  // Can typecast, IF source has an Address, but NO Size
  f := FTypeCastSourceValue.FieldFlags;
  if (f * [svfAddress, svfSize, svfSizeOfPointer] = [svfAddress]) then
    exit;

  // Can typecast, IF source has ordinal
  if (svfOrdinal in f)then
    exit;

  // Can typecast, IF source has address an size=pointer
  if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) then begin
    Result := GetSizeFor(FTypeCastSourceValue, SrcSize);
    if not Result then
      exit;
    if SrcSize = FTypeSymbol.CompilationUnit.AddressSize then
      exit;
  end;
  // Can typecast, IF source has address an size=pointer
  if (f * [svfAddress, svfSizeOfPointer] = [svfAddress, svfSizeOfPointer]) then
    exit;

  Result := False;
end;

{ TFpDwarfDefaultSymbolClassMap }

class function TFpDwarfDefaultSymbolClassMap.GetExistingClassMap: PFpDwarfSymbolClassMap;
begin
  Result := @ExistingClassMap;
end;

class function TFpDwarfDefaultSymbolClassMap.ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean;
begin
  Result := True;
end;

function TFpDwarfDefaultSymbolClassMap.GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass;
begin
  case ATag of
    // TODO:
    DW_TAG_constant:
      Result := TFpSymbolDwarfData;
    DW_TAG_string_type,
    DW_TAG_union_type, DW_TAG_ptr_to_member_type,
    DW_TAG_file_type,
    DW_TAG_thrown_type:
      Result := TFpSymbolDwarfType;

    // Type types
    DW_TAG_packed_type,
    DW_TAG_const_type,
    DW_TAG_volatile_type:    Result := TFpSymbolDwarfTypeModifier;
    DW_TAG_reference_type:   Result := TFpSymbolDwarfTypeRef;
    DW_TAG_typedef:          Result := TFpSymbolDwarfTypeDeclaration;
    DW_TAG_pointer_type:     Result := TFpSymbolDwarfTypePointer;

    DW_TAG_base_type:        Result := TFpSymbolDwarfTypeBasic;
    DW_TAG_subrange_type:    Result := TFpSymbolDwarfTypeSubRange;
    DW_TAG_enumeration_type: Result := TFpSymbolDwarfTypeEnum;
    DW_TAG_enumerator:       Result := TFpSymbolDwarfDataEnumMember;
    DW_TAG_set_type:         Result := TFpSymbolDwarfTypeSet;
    DW_TAG_structure_type,
    DW_TAG_interface_type,
    DW_TAG_class_type:       Result := TFpSymbolDwarfTypeStructure;
    DW_TAG_array_type:       Result := TFpSymbolDwarfTypeArray;
    DW_TAG_subroutine_type:  Result := TFpSymbolDwarfTypeSubroutine;
    // Value types
    DW_TAG_variable:         Result := TFpSymbolDwarfDataVariable;
    DW_TAG_formal_parameter: Result := TFpSymbolDwarfDataParameter;
    DW_TAG_member:           Result := TFpSymbolDwarfDataMember;
    DW_TAG_subprogram:       Result := TFpSymbolDwarfDataProc;
    //DW_TAG_inlined_subroutine, DW_TAG_entry_poin
    //
    DW_TAG_compile_unit:     Result := TFpSymbolDwarfUnit;

    DW_TAG_lo_user
     ..DW_TAG_hi_user:      Result := TFpSymbolDwarfThirdPartyExtension;
    else
      Result := TFpSymbolDwarf;
  end;
end;

function TFpDwarfDefaultSymbolClassMap.CreateScopeForSymbol(
  ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol;
  ADwarf: TFpDwarfInfo): TFpDbgSymbolScope;
begin
  Result := TFpDwarfInfoSymbolScope.Create(ALocationContext,ASymbol, ADwarf);
end;

function TFpDwarfDefaultSymbolClassMap.CreateProcSymbol(
  ACompilationUnit: TDwarfCompilationUnit; AInfo: PDwarfAddressInfo;
  AAddress: TDbgPtr; ADbgInfo: TFpDwarfInfo): TDbgDwarfSymbolBase;
begin
  Result := TFpSymbolDwarfDataProc.Create(ACompilationUnit, AInfo, AAddress, ADbgInfo);
end;

function TFpDwarfDefaultSymbolClassMap.CreateUnitSymbol(
  ACompilationUnit: TDwarfCompilationUnit; AInfoEntry: TDwarfInformationEntry;
  ADbgInfo: TFpDwarfInfo): TDbgDwarfSymbolBase;
begin
  Result := TFpSymbolDwarfUnit.Create(ACompilationUnit.UnitName, AInfoEntry, ADbgInfo);
end;

{ TFpThreadWorkerFindSymbolInUnits }

procedure TFpThreadWorkerFindSymbolInUnits.DoExecute;
var
  i: Integer;
  InfoEntry: TDwarfInformationEntry;
  IsExt: Boolean;
begin
  FFoundInfoEntry := nil;
  for i := 0 to Length(FCUs) - 1 do begin
    if FScope.FindExportedSymbolInUnit(FCUs[i], FNameInfo, InfoEntry, IsExt) then begin
      FFoundInfoEntry.ReleaseReference;
      FFoundInfoEntry := InfoEntry;
      if FIsExt then
        break;
    end;
  end;
end;

constructor TFpThreadWorkerFindSymbolInUnits.Create(
  AScope: TFpDwarfInfoSymbolScope; CUs: TDwarfCompilationUnitArray;
  const ANameInfo: TNameSearchInfo);
begin
  inherited Create;
  FScope := AScope;
  FCUs := CUs;
  FNameInfo := ANameInfo;
end;

destructor TFpThreadWorkerFindSymbolInUnits.Destroy;
begin
  FFoundInfoEntry.ReleaseReference;
  inherited Destroy;
end;

{ TFpDwarfInfoSymbolScope }

function TFpDwarfInfoSymbolScope.GetSymbolAtAddress: TFpSymbol;
begin
  Result := FSymbol;
end;

function TFpDwarfInfoSymbolScope.GetProcedureAtAddress: TFpValue;
begin
  Result := inherited GetProcedureAtAddress;
  ApplyContext(Result);
end;

function TFpDwarfInfoSymbolScope.GetSizeOfAddress: Integer;
begin
  if Symbol = nil then begin
    if FDwarf.CompilationUnitsCount > 0 then
      Result := FDwarf.CompilationUnits[0].AddressSize
    else
      case FDwarf.TargetInfo.bitness of
        bNone: Result := 0;
        b32:   Result := 4;
        b64:   Result := 8;
      end;
  end
  else
    Result := TFpSymbolDwarf(FSymbol).CompilationUnit.AddressSize;
end;

function TFpDwarfInfoSymbolScope.GetMemManager: TFpDbgMemManager;
begin
  Result := FDwarf.MemManager;
end;

procedure TFpDwarfInfoSymbolScope.ApplyContext(AVal: TFpValue);
begin
  if (AVal <> nil) and (TFpValueDwarfBase(AVal).Context = nil) then
    TFpValueDwarfBase(AVal).Context := Self.LocationContext;
end;

function TFpDwarfInfoSymbolScope.SymbolToValue(ASym: TFpSymbolDwarf): TFpValue;
begin
  if ASym = nil then begin
    Result := nil;
    exit;
  end;

  if ASym.SymbolType = stValue then begin
    Result := ASym.Value;
  end
  else begin
    Result := TFpValueDwarfTypeDefinition.Create(ASym);
  end;
  ASym.ReleaseReference;
end;

function TFpDwarfInfoSymbolScope.GetSelfParameter: TFpValueDwarf;
begin
  Result := FSelfParameter;
  if not(Symbol is TFpSymbolDwarfDataProc) then
    exit;
  if Result <> nil then
    exit;
  Result := TFpSymbolDwarfDataProc(FSymbol).GetSelfParameter(FAddress);
  if (Result <> nil) then
    Result.Context := Self.LocationContext;
  FSelfParameter := Result;
end;

function TFpDwarfInfoSymbolScope.FindExportedSymbolInUnit(
  CU: TDwarfCompilationUnit; const ANameInfo: TNameSearchInfo; out
  AnInfoEntry: TDwarfInformationEntry; out AnIsExternal: Boolean): Boolean;
var
  i, ExtVal: Integer;
  InfoEntry: TDwarfInformationEntry;
  s: String;
begin
  Result := False;

  AnInfoEntry := nil;
  AnIsExternal := False;

  //DebugLn(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier search UNIT Name=', CU.FileName]);

  InfoEntry := TDwarfInformationEntry.Create(CU, nil);
  InfoEntry.ScopeIndex := CU.FirstScope.Index;

  if not InfoEntry.AbbrevTag = DW_TAG_compile_unit then
    exit;
  // compile_unit can not have startscope

  s := CU.UnitName;
  if (s <> '') and (CompareUtf8BothCase(PChar(ANameInfo.NameUpper), PChar(ANameInfo.NameLower), @s[1])) then begin
    Result := True;
    AnInfoEntry := InfoEntry;
    AnIsExternal := True;
  end

  else
  if InfoEntry.GoNamedChildEx(ANameInfo) then begin
    if InfoEntry.IsAddressInStartScope(FAddress) then begin
      // only variables are marked "external", but types not / so we may need all top level
      Result := True;
      AnInfoEntry := InfoEntry;
      //DebugLn(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier MAYBE FOUND Name=', CU.FileName]);

      // DW_AT_visibility ?

      if InfoEntry.ReadValue(DW_AT_external, ExtVal) then
        AnIsExternal := ExtVal <> 0;
    end;
  end;

  if not  Result then
    InfoEntry.ReleaseReference;
end;

function TFpDwarfInfoSymbolScope.FindExportedSymbolInUnits(const AName: String;
  const ANameInfo: TNameSearchInfo; SkipCompUnit: TDwarfCompilationUnit; out
  ADbgValue: TFpValue; const OnlyUnitNameLower: String): Boolean;
const
  PER_WORKER_CNT = 20;
var
  i, j: Integer;
  CU: TDwarfCompilationUnit;
  CUList: TDwarfCompilationUnitArray;
  InfoEntry, FoundInfoEntry: TDwarfInformationEntry;
  IsExt: Boolean;
  WorkItem, PrevWorkItem: TFpThreadWorkerFindSymbolInUnits;
begin
  Result := False;

  ADbgValue := nil;
  FoundInfoEntry := nil;
  PrevWorkItem := nil;
  IsExt := False;

  i := FDwarf.CompilationUnitsCount;
  while i > 0 do begin
    j := 0;
    SetLength(CUList, PER_WORKER_CNT);
    while (j < PER_WORKER_CNT) and (i > 0) do begin
      dec(i);
      CU := FDwarf.CompilationUnits[i];

      if (OnlyUnitNameLower <> '') and (OnlyUnitNameLower <> LowerCase(CU.UnitName)) then
        continue;
      if (CU = SkipCompUnit) or
         (not CU.KnownNameHashes^[ANameInfo.NameHash and KnownNameHashesBitMask])
      then
        continue;

      CUList[j] := CU;
      inc(j);
    end;

    if j < PER_WORKER_CNT then begin
      assert(i=0, 'TFpDwarfInfoSymbolScope.FindExportedSymbolInUnits: i=0');
      SetLength(CUList, j);
    end;

    if j > 0 then begin
      WorkItem := TFpThreadWorkerFindSymbolInUnits.Create(Self, CUList, ANameInfo);
      WorkItem.AddRef;
    end
    else
      WorkItem := nil;

    if PrevWorkItem <> nil then begin
      if (not PrevWorkItem.IsDone) then begin
        if WorkItem <> nil then begin
          WorkItem.Execute;
          if (WorkItem.FFoundInfoEntry = nil) and (not PrevWorkItem.IsDone) then begin
            WorkItem.DecRef;
            continue;
          end;
        end;
        Dwarf.WorkQueue.WaitForItem(PrevWorkItem); // must check result from Prev first, to keep a stable search order
      end;

      while PrevWorkItem <> nil do begin
        assert(PrevWorkItem.IsDone, 'TFpDwarfInfoSymbolScope.FindExportedSymbolInUnits: PrevWorkItem.IsDone');
        ReadBarrier;
        if PrevWorkItem.FFoundInfoEntry <> nil then begin
          FoundInfoEntry.ReleaseReference;
          FoundInfoEntry := PrevWorkItem.FFoundInfoEntry;
          FoundInfoEntry.AddReference;
          IsExt := PrevWorkItem.FIsExt;
        end;
        PrevWorkItem.DecRef;
        PrevWorkItem := nil;
        if IsExt then begin
          WorkItem.DecRef;
          break;
        end;
        if (WorkItem <> nil) and WorkItem.IsDone then begin
          PrevWorkItem := WorkItem;
          WorkItem := nil;
        end;
      end;
    end;

    if WorkItem <> nil then begin
      if i = 0 then
        WorkItem.Execute
      else
        Dwarf.WorkQueue.PushItemIdleOrRun(WorkItem);
      PrevWorkItem := WorkItem;
      WorkItem := nil;
    end;
  end;

  if PrevWorkItem <> nil then begin
    if not IsExt then begin  // IsExt => already got a final result
      if not PrevWorkItem.IsDone then
        Dwarf.WorkQueue.WaitForItem(PrevWorkItem);
      if PrevWorkItem.FFoundInfoEntry <> nil then begin
        FoundInfoEntry.ReleaseReference;
        FoundInfoEntry := PrevWorkItem.FFoundInfoEntry;
        FoundInfoEntry.AddReference
      end;
    end;
    PrevWorkItem.DecRef;
  end;

  if FoundInfoEntry <> nil then begin
    ADbgValue := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, FoundInfoEntry));
    FoundInfoEntry.ReleaseReference;
  end;

  Result := ADbgValue <> nil;
end;

function TFpDwarfInfoSymbolScope.FindSymbolInStructure(const AName: String;
  const ANameInfo: TNameSearchInfo; InfoEntry: TDwarfInformationEntry; out
  ADbgValue: TFpValue): Boolean;
var
  InfoEntryInheritance: TDwarfInformationEntry;
  FwdInfoPtr: Pointer;
  FwdCompUint: TDwarfCompilationUnit;
  SelfParam: TFpValue;
begin
  Result := False;
  ADbgValue := nil;
  InfoEntry.AddReference;

  while True do begin
    if not InfoEntry.IsAddressInStartScope(FAddress) then
      break;

    InfoEntryInheritance := InfoEntry.FindChildByTag(DW_TAG_inheritance);

    if InfoEntry.GoNamedChildEx(ANameInfo) then begin
      if InfoEntry.IsAddressInStartScope(FAddress) then begin
        SelfParam := GetSelfParameter;
        if (SelfParam <> nil) then begin
          // TODO: only valid, as long as context is valid, because if context is freed, then self is lost too
          ADbgValue := SelfParam.MemberByName[AName];
          assert(ADbgValue <> nil, 'FindSymbol: SelfParam.MemberByName[AName]');
        end;
        if ADbgValue = nil then begin // Todo: abort the searh /SetError
          ADbgValue := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, InfoEntry));
        end;
        InfoEntry.ReleaseReference;
        InfoEntryInheritance.ReleaseReference;
        Result := True;
        exit;
      end;
    end;


    if not( (InfoEntryInheritance <> nil) and
            (InfoEntryInheritance.ReadReference(DW_AT_type, FwdInfoPtr, FwdCompUint)) )
    then
      break;
    InfoEntry.ReleaseReference;
    InfoEntry := TDwarfInformationEntry.Create(FwdCompUint, FwdInfoPtr);
    InfoEntryInheritance.ReleaseReference;
    DebugLn(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier  PARENT ', dbgs(InfoEntry, FwdCompUint) ]);
  end;

  InfoEntry.ReleaseReference;
  Result := ADbgValue <> nil;
end;

function TFpDwarfInfoSymbolScope.FindLocalSymbol(const AName: String;
  const ANameInfo: TNameSearchInfo; InfoEntry: TDwarfInformationEntry; out
  ADbgValue: TFpValue): Boolean;
begin
  Result := False;
  ADbgValue := nil;
  if not(Symbol is TFpSymbolDwarfDataProc) then
    exit;
  if not InfoEntry.GoNamedChildEx(ANameInfo) then
    exit;
  if InfoEntry.IsAddressInStartScope(FAddress) and not InfoEntry.IsArtificial then begin
    ADbgValue := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, InfoEntry));
    if ADbgValue <> nil then
      TFpSymbolDwarf(ADbgValue.DbgSymbol).LocalProcInfo := TFpSymbolDwarfDataProc(FSymbol);
  end;
  Result := ADbgValue <> nil;
end;

constructor TFpDwarfInfoSymbolScope.Create(
  ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol;
  ADwarf: TFpDwarfInfo);
begin
  assert((ASymbol=nil) or (ASymbol is TFpSymbolDwarf), 'TFpDwarfInfoSymbolScope.Create: (ASymbol=nil) or (ASymbol is TFpSymbolDwarf)');
  inherited Create(ALocationContext);
  FDwarf   := ADwarf;
  FSymbol  := TFpSymbolDwarf(ASymbol);
  FAddress := LocationContext.Address; // for quick access
  if FSymbol <> nil then
    FSymbol.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FSymbol, 'Context to Symbol'){$ENDIF};
end;

destructor TFpDwarfInfoSymbolScope.Destroy;
begin
  FSelfParameter.ReleaseReference;
  FSymbol.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FSymbol, 'Context to Symbol'){$ENDIF};
  inherited Destroy;
end;

function TFpDwarfInfoSymbolScope.FindSymbol(const AName: String;
  const OnlyUnitName: String): TFpValue;
var
  SubRoutine: TFpSymbolDwarfDataProc; // TDbgSymbol;
  CU: TDwarfCompilationUnit;
  //Scope,
  StartScopeIdx: Integer;
  InfoEntry: TDwarfInformationEntry;
  NameInfo: TNameSearchInfo;
  InfoName: PChar;
  tg: Cardinal;
begin
  Result := nil;
  //if (FSymbol = nil) or not(FSymbol is TFpSymbolDwarfDataProc) or (AName = '') then
  if (AName = '') then
    exit;

  NameInfo := NameInfoForSearch(AName);

  if OnlyUnitName <> '' then begin
    // TODO: dwarf info for libraries
    FindExportedSymbolInUnits(AName, NameInfo, nil, Result, LowerCase(OnlyUnitName));
    exit;
  end;

  if FSymbol is TFpSymbolDwarfDataProc then
    SubRoutine := TFpSymbolDwarfDataProc(FSymbol)
  else
    SubRoutine := nil;

  if Symbol = nil then begin
    FindExportedSymbolInUnits(AName, NameInfo, nil, Result);
    ApplyContext(Result);
    if Result = nil then
      Result := inherited FindSymbol(AName);
    exit;
  end;

  try
    CU := Symbol.CompilationUnit;
    InfoEntry := Symbol.InformationEntry.Clone;

    while InfoEntry.HasValidScope do begin
      //debugln(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier Searching ', dbgs(InfoEntry.FScope, CU)]);
      StartScopeIdx := InfoEntry.ScopeIndex;

      tg := InfoEntry.AbbrevTag;
      if (tg = DW_TAG_compile_unit) and
         (not CU.KnownNameHashes^[NameInfo.NameHash and KnownNameHashesBitMask])
      then
        break;

      //if InfoEntry.Abbrev = nil then
      //  exit;

      if not InfoEntry.IsAddressInStartScope(FAddress) // StartScope = first valid address
      then begin
        // CONTINUE: Search parent(s)
        //InfoEntry.ScopeIndex := StartScopeIdx;
        InfoEntry.GoParent;
        Continue;
      end;

      if InfoEntry.InfoScope.Current^.NameHash = NameInfo.NameHash then
      if InfoEntry.ReadName(InfoName) and not InfoEntry.IsArtificial
      then begin
        if (CompareUtf8BothCase(PChar(NameInfo.NameUpper), PChar(NameInfo.NameLower), InfoName)) then begin
          // TODO: this is a pascal specific search order? Or not?
          // If this is a type with a pointer or ref, need to find the pointer or ref.
          InfoEntry.GoParent;
          if InfoEntry.HasValidScope and
             InfoEntry.GoNamedChildEx(NameInfo)
          then begin
            if InfoEntry.IsAddressInStartScope(FAddress) and not InfoEntry.IsArtificial then begin
              Result := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, InfoEntry));
              exit;
            end;
          end;

          InfoEntry.ScopeIndex := StartScopeIdx;
          Result := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, InfoEntry));
          exit;
        end;
      end;


      if (tg = DW_TAG_class_type) or (tg = DW_TAG_structure_type) then begin
        if FindSymbolInStructure(AName,NameInfo, InfoEntry, Result) then begin
          exit; // TODO: check error
        end;
        //InfoEntry.ScopeIndex := StartScopeIdx;
      end

      else
      if (SubRoutine <> nil) and (StartScopeIdx = SubRoutine.InformationEntry.ScopeIndex) then begin // searching in subroutine
        if FindLocalSymbol(AName,NameInfo, InfoEntry, Result) then begin
          exit;        // TODO: check error
        end;
        //InfoEntry.ScopeIndex := StartScopeIdx;
      end
          // TODO: nested subroutine

      else
      if InfoEntry.GoNamedChildEx(NameInfo) then begin
        if InfoEntry.IsAddressInStartScope(FAddress) and not InfoEntry.IsArtificial then begin
          Result := SymbolToValue(TFpSymbolDwarf.CreateSubClass(AName, InfoEntry));
          exit;
        end;
      end;

      // Search parent(s)
      InfoEntry.ScopeIndex := StartScopeIdx;
      InfoEntry.GoParent;
    end;

    FindExportedSymbolInUnits(AName, NameInfo, CU, Result);

  finally
    if (Result = nil) or (InfoEntry = nil)
    then DebugLn(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier NOT found  Name=', AName])
    else DebugLn(FPDBG_DWARF_SEARCH, ['TDbgDwarf.FindIdentifier(',AName,') found Scope=', TFpSymbolDwarf(Result.DbgSymbol).InformationEntry.ScopeDebugText, '  ResultSymbol=', DbgSName(Result.DbgSymbol), ' ', Result.DbgSymbol.Name, ' in ', TFpSymbolDwarf(Result.DbgSymbol).CompilationUnit.FileName]);
    ReleaseRefAndNil(InfoEntry);

    assert((Result = nil) or (Result is TFpValueDwarfBase), 'TDbgDwarfInfoAddressContext.FindSymbol: (Result = nil) or (Result is TFpValueDwarfBase)');
    ApplyContext(Result);
  end;
  if Result = nil then
    Result := inherited FindSymbol(AName);
end;

{ TFpValueDwarfTypeDefinition }

function TFpValueDwarfTypeDefinition.GetKind: TDbgSymbolKind;
begin
  Result := skType;
end;

function TFpValueDwarfTypeDefinition.GetDbgSymbol: TFpSymbol;
begin
  Result := FSymbol;
end;

function TFpValueDwarfTypeDefinition.GetMemberCount: Integer;
begin
    Result := FSymbol.NestedSymbolCount;
end;

function TFpValueDwarfTypeDefinition.GetMemberByName(const AIndex: String
  ): TFpValue;
begin
  Result := FSymbol.GetNestedValueByName(AIndex);
  if Result = nil then
    exit;
//  TFpValueDwarf(Result).SetStructureValue(Self);
  TFpValueDwarf(Result).Context := Context;
end;

function TFpValueDwarfTypeDefinition.GetMember(AIndex: Int64): TFpValue;
begin
  Result := FSymbol.GetNestedValue(AIndex);
  if Result = nil then
    exit;
//  TFpValueDwarf(Result).SetStructureValue(Self);
  TFpValueDwarf(Result).Context := Context;
end;

constructor TFpValueDwarfTypeDefinition.Create(ASymbol: TFpSymbolDwarf);
begin
  inherited Create;
  FSymbol := ASymbol;
  FSymbol.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FSymbol, 'TFpValueDwarfTypeDefinition'){$ENDIF};
end;

destructor TFpValueDwarfTypeDefinition.Destroy;
begin
  inherited Destroy;
  FSymbol.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FSymbol, 'TFpValueDwarfTypeDefinition'){$ENDIF};
end;

function TFpValueDwarfTypeDefinition.GetTypeCastedValue(ADataVal: TFpValue): TFpValue;
begin
  Result := FSymbol.TypeCastValue(ADataVal);
  assert((Result = nil) or (Result is TFpValueDwarf), 'TFpValueDwarfTypeDefinition.GetTypeCastedValue: (Result = nil) or (Result is TFpValueDwarf)');
  if (Result <> nil) and (TFpValueDwarf(Result).Context = nil) then
    TFpValueDwarf(Result).Context := Context;
end;

{ TFpValueDwarf }

function TFpValueDwarf.MemManager: TFpDbgMemManager;
begin
assert(Context<>nil, 'TFpValueDwarf.MemManager: Context<>nil');
  Result := nil;
  if Context <> nil then
    Result := Context.MemManager;

  if Result = nil then begin
    // Either a typecast, or a member gotten from a typecast,...
    assert((FTypeSymbol <> nil) and (FTypeSymbol.CompilationUnit <> nil) and (FTypeSymbol.CompilationUnit.Owner <> nil), 'TDbgDwarfSymbolValue.MemManager');
    Result := FTypeSymbol.CompilationUnit.Owner.MemManager;
  end;
end;

function TFpValueDwarf.AddressSize: Byte;
begin
  assert((FTypeSymbol <> nil) and (FTypeSymbol.CompilationUnit <> nil), 'TDbgDwarfSymbolValue.AddressSize');
  Result := FTypeSymbol.CompilationUnit.AddressSize;
end;

procedure TFpValueDwarf.SetStructureValue(AValue: TFpValueDwarf);
begin
  if FStructureValue <> nil then
    Reset;

  if FStructureValue = AValue then
    exit;

  FStructureValue.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FStructureValue, 'TDbgDwarfSymbolValue'){$ENDIF};
  FStructureValue := AValue;
  if FStructureValue <> nil then
    FStructureValue.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FStructureValue, 'TDbgDwarfSymbolValue'){$ENDIF};
end;

function TFpValueDwarf.GetSizeFor(AnOtherValue: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  Result := AnOtherValue.GetSize(ASize);
  if (not Result) and IsError(AnOtherValue.LastError) then
    SetLastError(AnOtherValue.LastError);
end;

function TFpValueDwarf.OrdOrDataAddr: TFpDbgMemLocation;
begin
  if HasTypeCastInfo and (svfOrdinal in FTypeCastSourceValue.FieldFlags) then
    Result := ConstLoc(FTypeCastSourceValue.AsCardinal)
  else
    GetDwarfDataAddress(Result);
end;

function TFpValueDwarf.GetDataAddress: TFpDbgMemLocation;
begin
  GetDwarfDataAddress(Result);
end;

function TFpValueDwarf.GetDwarfDataAddress(out AnAddress: TFpDbgMemLocation;
  ATargetType: TFpSymbolDwarfType): Boolean;
var
  fields: TFpValueFieldFlags;
  ti: TFpSymbol;
begin
  AnAddress := FCachedDataAddress;
  Result := IsInitializedLoc(AnAddress);
  if Result then
    exit(IsValidLoc(AnAddress));

  FCachedDataAddress := InvalidLoc;

  if FDataSymbol <> nil then begin
    Assert(FDataSymbol is TFpSymbolDwarfData, 'TDbgDwarfSymbolValue.GetDwarfDataAddress FValueSymbol');
    Assert(TypeInfo is TFpSymbolDwarfType, 'TDbgDwarfSymbolValue.GetDwarfDataAddress TypeInfo');
    Assert(not HasTypeCastInfo, 'TDbgDwarfSymbolValue.GetDwarfDataAddress not HasTypeCastInfo');

    ti := FDataSymbol.TypeInfo;
    Result := ti <> nil;
    if not Result then
      exit;
    Assert((ti is TFpSymbolDwarfType) and (ti.SymbolType = stType), 'TDbgDwarfSymbolValue.GetDwarfDataAddress TypeInfo = stType');

    AnAddress := Address;
    Result := IsReadableLoc(AnAddress);

    if Result then
      Result := TFpSymbolDwarf(ti).GetDataAddress(Self, AnAddress, ATargetType);
  end

  else
  begin
    // TODO: cache own address
    // try typecast
    AnAddress := InvalidLoc;
    Result := HasTypeCastInfo;
    if not Result then
      exit;
    fields := FTypeCastSourceValue.FieldFlags;
    if svfOrdinal in fields then
      AnAddress := ConstLoc(FTypeCastSourceValue.AsCardinal)
    else
    if svfAddress in fields then
      AnAddress := FTypeCastSourceValue.Address;

    Result := IsReadableLoc(AnAddress);
    if Result then
      Result := FTypeSymbol.GetDataAddress(Self, AnAddress, ATargetType);
  end;

  if not Result then
    AnAddress := InvalidLoc;
  FCachedDataAddress := AnAddress;
end;

function TFpValueDwarf.GetStructureDwarfDataAddress(out AnAddress: TFpDbgMemLocation;
  ATargetType: TFpSymbolDwarfType): Boolean;
begin
  AnAddress := InvalidLoc;
  Result := StructureValue <> nil;
  if Result then
    Result := StructureValue.GetDwarfDataAddress(AnAddress, ATargetType); // ATargetType could be parent class;
end;

procedure TFpValueDwarf.Reset;
begin
  FCachedAddress := UnInitializedLoc;
  FCachedDataAddress := UnInitializedLoc;
  FTypeSymbol.ResetValueBounds;
end;

function TFpValueDwarf.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  if FDataSymbol <> nil then begin
    if FDataSymbol.HasAddress then Result := Result + [svfAddress];
  end
  else
  if HasTypeCastInfo then begin
    Result := Result + FTypeCastSourceValue.FieldFlags * [svfAddress];
  end;
end;

function TFpValueDwarf.HasTypeCastInfo: Boolean;
begin
  Result := (FTypeCastSourceValue <> nil);
end;

function TFpValueDwarf.IsValidTypeCast: Boolean;
begin
  Result := False;
end;

function TFpValueDwarf.GetKind: TDbgSymbolKind;
begin
  Result := FTypeSymbol.Kind;
end;

function TFpValueDwarf.GetAddress: TFpDbgMemLocation;
begin
  if IsInitializedLoc(FCachedAddress) then
    exit(FCachedAddress);

  if FDataSymbol <> nil then
    FDataSymbol.GetValueAddress(Self, Result)
  else
  if HasTypeCastInfo then
    Result := FTypeCastSourceValue.Address
  else
    Result := inherited GetAddress;

  assert(IsInitializedLoc(Result), 'TFpValueDwarf.GetAddress: IsInitializedLoc(Result)');
  FCachedAddress := Result;
end;

function TFpValueDwarf.DoGetSize(out ASize: TFpDbgValueSize): Boolean;
begin
  if (TypeCastSourceValue = nil) then begin
    Result := DbgSymbol.ReadSize(Self, ASize);
    if Result then
      exit;
  end
  else
  if not IsZeroSize(FForcedSize) then begin
    Result := True;
    ASize := FForcedSize;
    exit;
  end;

  if FTypeSymbol <> nil then begin
    Result := FTypeSymbol.ReadSize(Self, ASize);
  end
  else
    Result := inherited DoGetSize(ASize);
end;

function TFpValueDwarf.OrdOrAddress: TFpDbgMemLocation;
begin
  if HasTypeCastInfo and (svfOrdinal in FTypeCastSourceValue.FieldFlags) then
    Result := ConstLoc(FTypeCastSourceValue.AsCardinal)
  else
    Result := Address;
end;

function TFpValueDwarf.GetMemberCount: Integer;
begin
  Result := FTypeSymbol.NestedSymbolCount;
end;

function TFpValueDwarf.GetMemberByName(const AIndex: String): TFpValue;
begin
  Result := FTypeSymbol.GetNestedValueByName(AIndex);
  if Result = nil then
    exit;
  TFpValueDwarf(Result).SetStructureValue(Self);
  TFpValueDwarf(Result).Context := Context;
end;

function TFpValueDwarf.GetMember(AIndex: Int64): TFpValue;
begin
  Result := FTypeSymbol.GetNestedValue(AIndex);
  if Result = nil then
    exit;
  TFpValueDwarf(Result).SetStructureValue(Self);
  TFpValueDwarf(Result).Context := Context;
end;

function TFpValueDwarf.GetDbgSymbol: TFpSymbol;
begin
  Result := FDataSymbol;
end;

function TFpValueDwarf.GetTypeInfo: TFpSymbol;
begin
  Result := FTypeSymbol;
end;

function TFpValueDwarf.GetParentTypeInfo: TFpSymbol;
begin
  Result := FParentTypeSymbol;
end;

constructor TFpValueDwarf.Create(ADwarfTypeSymbol: TFpSymbolDwarfType);
begin
  FTypeSymbol := ADwarfTypeSymbol;
  inherited Create;
end;

destructor TFpValueDwarf.Destroy;
begin
  FTypeCastSourceValue.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FTypeCastSourceValue, ClassName+'.FTypeCastSourceValue'){$ENDIF};
  FStructureValue.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FStructureValue, 'TDbgDwarfSymbolValue'){$ENDIF};
  FDataSymbol.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FDataSymbol, ClassName+'.FDataSymbol'){$ENDIF};
  inherited Destroy;
end;

procedure TFpValueDwarf.SetDataSymbol(AValueSymbol: TFpSymbolDwarfData);
begin
  if FDataSymbol = AValueSymbol then
    exit;

  FDataSymbol.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FDataSymbol, ClassName+'.FDataSymbol'){$ENDIF};
  FDataSymbol := AValueSymbol;
  if FDataSymbol <> nil then
    FDataSymbol.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FDataSymbol, ClassName+'.FDataSymbol'){$ENDIF};
end;

function TFpValueDwarf.SetTypeCastInfo(ASource: TFpValue): Boolean;
begin
  Reset;

  if FTypeCastSourceValue <> ASource then begin
    if FTypeCastSourceValue <> nil then
      FTypeCastSourceValue.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FTypeCastSourceValue, ClassName+'.FTypeCastSourceValue'){$ENDIF};
    FTypeCastSourceValue := ASource;
    if FTypeCastSourceValue <> nil then
      FTypeCastSourceValue.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FTypeCastSourceValue, ClassName+'.FTypeCastSourceValue'){$ENDIF};
  end;

  Result := IsValidTypeCast;
end;

{ TFpValueDwarfSized }

function TFpValueDwarfSized.CanUseTypeCastAddress: Boolean;
var
  TypeSize, SrcSize: TFpDbgValueSize;
begin
  Result := True;
  // Can Use TypeCast-Address, if source has an Address, but NO Size
  if (FTypeCastSourceValue.FieldFlags * [svfAddress, svfSize, svfSizeOfPointer] = [svfAddress]) then
    exit
  else
  // Can Use TypeCast-Address, if source has an Address, and SAME Size as this (this = cast-target-type)
  if (FTypeCastSourceValue.FieldFlags * [svfAddress, svfSize] = [svfAddress, svfSize]) then begin
    Result := GetSize(TypeSize) and GetSizeFor(FTypeCastSourceValue, SrcSize);
    if not Result then
      exit;
    if (TypeSize = SrcSize) and (SrcSize > 0) then
      exit;
  end;
  // Can Use TypeCast-Address, if source has an Address, but SAME Size as this (this = cast-target-type)
  // and yet not target type = pointer ???
  if (FTypeCastSourceValue.FieldFlags * [svfAddress, svfSizeOfPointer] = [svfAddress, svfSizeOfPointer]) and
     not ( (FTypeSymbol.Kind = skPointer) //or
           //(FSize = AddressSize xxxxxxx)
         )
  then
    exit;
  Result := False;
end;

function TFpValueDwarfSized.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfSize];
end;

{ TFpValueDwarfNumeric }

procedure TFpValueDwarfNumeric.Reset;
begin
  inherited Reset;
  FEvaluated := [];
end;

function TFpValueDwarfNumeric.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfOrdinal];
end;

function TFpValueDwarfNumeric.IsValidTypeCast: Boolean;
begin
  Result := HasTypeCastInfo;
  If not Result then
    exit;
  if (svfOrdinal in FTypeCastSourceValue.FieldFlags) or CanUseTypeCastAddress then
    exit;
  Result := False;
end;

constructor TFpValueDwarfNumeric.Create(ADwarfTypeSymbol: TFpSymbolDwarfType);
begin
  inherited Create(ADwarfTypeSymbol);
  FEvaluated := [];
end;

{ TFpValueDwarfInteger }

function TFpValueDwarfInteger.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfInteger];
end;

function TFpValueDwarfInteger.GetAsCardinal: QWord;
begin
  Result := QWord(GetAsInteger);  // include sign extension
end;

function TFpValueDwarfInteger.GetAsInteger: Int64;
var
  Size: TFpDbgValueSize;
begin
  if doneInt in FEvaluated then begin
    Result := FIntValue;
    exit;
  end;
  Include(FEvaluated, doneInt);

  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(Result)) then
    Result := inherited GetAsInteger
  else
  if not Context.ReadSignedInt(OrdOrDataAddr, Size, Result) then begin
    Result := 0; // TODO: error
    SetLastError(Context.LastMemError);
  end;

  FIntValue := Result;
end;

procedure TFpValueDwarfInteger.SetAsInteger(AValue: Int64);
var
  Size: TFpDbgValueSize;
begin
  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(AValue)) then begin
    inherited SetAsCardinal(AValue);
  end
  else
  if not Context.WriteSignedInt(OrdOrDataAddr, Size, AValue) then begin
    SetLastError(Context.LastMemError);
    Exclude(FEvaluated, doneInt);
  end
  else begin
    FIntValue := AValue;
    Include(FEvaluated, doneInt);
  end;
end;

procedure TFpValueDwarfInteger.SetAsCardinal(AValue: QWord);
begin
  SetAsInteger(int64(AValue));
end;

{ TDbgDwarfCardinalSymbolValue }

function TFpValueDwarfCardinal.GetAsCardinal: QWord;
var
  Size: TFpDbgValueSize;
begin
  if doneUInt in FEvaluated then begin
    Result := FValue;
    exit;
  end;
  Include(FEvaluated, doneUInt);

  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(Result)) then
    Result := inherited GetAsCardinal
  else
  if not Context.ReadUnsignedInt(OrdOrDataAddr, Size, Result) then begin
    Result := 0; // TODO: error
    SetLastError(Context.LastMemError);
  end;

  FValue := Result;
end;

function TFpValueDwarfCardinal.GetAsInteger: Int64;
begin
  Result := Int64(GetAsCardinal);
end;

function TFpValueDwarfCardinal.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfCardinal];
end;

procedure TFpValueDwarfCardinal.SetAsCardinal(AValue: QWord);
var
  Size: TFpDbgValueSize;
begin
  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(AValue)) then begin
    inherited SetAsCardinal(AValue);
  end
  else
  if not Context.WriteUnsignedInt(OrdOrDataAddr, Size, AValue) then begin
    SetLastError(Context.LastMemError);
    Exclude(FEvaluated, doneUInt);
  end
  else begin
    FValue := AValue;
    Include(FEvaluated, doneUInt);
  end;
end;

{ TFpValueDwarfFloat }

function TFpValueDwarfFloat.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfFloat] - [svfOrdinal];
end;

function TFpValueDwarfFloat.GetAsFloat: Extended;
var
  Size: TFpDbgValueSize;
begin
  if doneFloat in FEvaluated then begin
    Result := FValue;
    exit;
  end;
  Include(FEvaluated, doneUInt);

  if not GetSize(Size) then
    Result := 0
  else
  if (Size <= 0) or (Size > SizeOf(Result)) then begin
    Result := 0;
    SetLastError(CreateError(fpErrorBadFloatSize));
  end
  else
  if not Context.ReadFloat(OrdOrDataAddr, Size, Result) then begin
    Result := 0; // TODO: error
    SetLastError(Context.LastMemError);
  end;

  FValue := Result;
end;

{ TFpValueDwarfBoolean }

function TFpValueDwarfBoolean.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfBoolean];
end;

function TFpValueDwarfBoolean.GetAsBool: Boolean;
begin
  Result := QWord(GetAsCardinal) <> 0;
end;

procedure TFpValueDwarfBoolean.SetAsBool(AValue: Boolean);
begin
  SetAsCardinal(QWord(AValue));
end;

{ TFpValueDwarfChar }

function TFpValueDwarfChar.GetFieldFlags: TFpValueFieldFlags;
var
  Size: TFpDbgValueSize;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  Result := inherited GetFieldFlags;
  case Size.Size of
    1: Result := Result + [svfString];
    2: Result := Result + [svfWideString];
  end;
end;

function TFpValueDwarfChar.GetAsString: AnsiString;
var
  Size: TFpDbgValueSize;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  // Can typecast, because of FSize = 1, GetAsCardinal only read one byte
  if Size.Size = 2 then
    Result := GetAsWideString  // temporary workaround for WideChar
  else
  if Size <> 1 then
    Result := inherited GetAsString
  else
    Result := SysToUTF8(char(byte(GetAsCardinal)));
end;

function TFpValueDwarfChar.GetAsWideString: WideString;
var
  Size: TFpDbgValueSize;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  if Size.Size > 2 then
    Result := inherited GetAsWideString
  else
    Result := WideChar(Word(GetAsCardinal));
end;

procedure TFpValueDwarfChar.SetAsString(AValue: AnsiString);
var
  Size: TFpDbgValueSize;
  u: UnicodeString;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  if Size.Size > 2 then begin
    inherited SetAsString(AValue);
  end
  else
  if Size.Size = 2 then begin
    u := UTF8Decode(AValue);
    if Length(u) <> 1 then
      inherited SetAsString(AValue) // error
    else
      SetAsCardinal(Word(u[1]));
  end
  else begin
    if Length(AValue) <> 1 then
      inherited SetAsString(AValue) // error
    else
      SetAsCardinal(Byte(AValue[1]));
  end;
end;

{ TFpValueDwarfPointer }

function TFpValueDwarfPointer.GetDerefAddress: TFpDbgMemLocation;
var
  Size: TFpDbgValueSize;
  Addr: TFpDbgMemLocation;
begin
  if doneAddr in FEvaluated then begin
    Result := FPointedToAddr;
    exit;
  end;
  Include(FEvaluated, doneAddr);
  Result := InvalidLoc;

  if not GetSize(Size) then
    Size := ZeroSize;
  if (Size > 0) then begin
    Addr := OrdOrDataAddr;
    if not IsNilLoc(Addr) then begin
      if not Context.ReadAddress(Addr, SizeVal(Context.SizeOfAddress), Result) then
        SetLastError(Context.LastMemError);
    end;
  end;
  FPointedToAddr := Result;
end;

function TFpValueDwarfPointer.GetAsCardinal: QWord;
var
  a: TFpDbgMemLocation;
begin
  a := GetDerefAddress;
  if IsTargetAddr(a) then
    Result := LocToAddr(a)
  else
    Result := 0;
end;

function TFpValueDwarfPointer.GetFieldFlags: TFpValueFieldFlags;
var
  t: TFpSymbol;
  Size: TFpDbgValueSize;
begin
  Result := inherited GetFieldFlags;
  //TODO: svfDataAddress should depend on (hidden) Pointer or Ref in the TypeInfo
  Result := Result + [svfCardinal, svfOrdinal, svfSizeOfPointer, svfDataAddress] - [svfSize]; // data address

  t := TypeInfo;
  if (t <> nil) then t := t.TypeInfo;
  if (t <> nil) and (t.Kind = skChar) and IsValidLoc(GetDerefAddress) then begin // pchar
    if not t.ReadSize(nil, Size) then
      Size := ZeroSize;
    case Size.Size of
      1: Result := Result + [svfString];
      2: Result := Result + [svfWideString];
    end;
  end;
end;

function TFpValueDwarfPointer.GetDataAddress: TFpDbgMemLocation;
var
  Size: TFpDbgValueSize;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  if (Size <= 0) then
    Result := InvalidLoc
  else
    Result := inherited;
end;

function TFpValueDwarfPointer.GetAsString: AnsiString;
var
  t: TFpSymbol;
  i: Cardinal;
  Size: TFpDbgValueSize;
begin
  Result := '';
  t := TypeInfo;
  if t = nil then
    exit;
  t := t.TypeInfo;
  if t = nil then
    exit;

  // Only test for hardcoded size. TODO: dwarf 3 could have variable size, but for char that is not expected
  if not t.ReadSize(nil, Size) then
    exit;

  if Size.Size = 2 then
    Result := GetAsWideString
  else
  if  (MemManager <> nil) and (t <> nil) and (t.Kind = skChar) and IsReadableMem(GetDerefAddress) then begin // pchar
    i := MemManager.MemLimits.MaxNullStringSearchLen;
    if i = 0 then
      i := 32*1024;
    if i > MemManager.MemLimits.MaxMemReadSize then
      i := MemManager.MemLimits.MaxMemReadSize;
    if not MemManager.SetLength(Result, i) then begin
      Result := '';
      SetLastError(MemManager.LastError);
      exit;
    end;

    if not Context.ReadMemory(GetDerefAddress, SizeVal(i), @Result[1], [mmfPartialRead]) then begin
      Result := '';
      SetLastError(Context.LastMemError);
      exit;
    end;

    i := Context.PartialReadResultLenght;
    SetLength(Result,i);
    i := pos(#0, Result);
    if i > 0 then
      SetLength(Result,i-1);
  end
  else
    Result := inherited GetAsString;
end;

function TFpValueDwarfPointer.GetAsWideString: WideString;
var
  t: TFpSymbol;
  i: Cardinal;
begin
  t := TypeInfo;
  if (t <> nil) then t := t.TypeInfo;
  // skWideChar ???
  if  (MemManager <> nil) and (t <> nil) and (t.Kind = skChar) and IsReadableMem(GetDerefAddress) then begin // pchar
    i := MemManager.MemLimits.MaxNullStringSearchLen * 2;
    if i = 0 then
      i := 32*1024 * 2;
    if i > MemManager.MemLimits.MaxMemReadSize then
      i := MemManager.MemLimits.MaxMemReadSize;
    if not MemManager.SetLength(Result, i div 2) then begin
      Result := '';
      SetLastError(MemManager.LastError);
      exit;
    end;

    if not Context.ReadMemory(GetDerefAddress, SizeVal(i), @Result[1], [mmfPartialRead]) then begin
      Result := '';
      SetLastError(Context.LastMemError);
      exit;
    end;

    i := Context.PartialReadResultLenght;
    SetLength(Result, i div 2);
    i := pos(#0, Result);
    if i > 0 then
      SetLength(Result, i-1);
  end
  else
    Result := inherited GetAsWideString;
end;

function TFpValueDwarfPointer.GetMember(AIndex: Int64): TFpValue;
var
  ti: TFpSymbol;
  addr: TFpDbgMemLocation;
  Tmp: TFpValueDwarfConstAddress;
  Size: TFpDbgValueSize;
begin
  //TODO: ?? if no TypeInfo.TypeInfo;, then return TFpValueDwarfConstAddress.Create(addr); (for mem dump)
  Result := nil;
  if (TypeInfo = nil) then begin // TODO dedicanted error code
    SetLastError(CreateError(fpErrAnyError, ['Can not dereference an untyped pointer']));
    exit;
  end;

  // TODO re-use last member

  ti := TypeInfo.TypeInfo;
  {$PUSH}{$R-}{$Q-} // TODO: check overflow
  if (ti <> nil) and (AIndex <> 0) then begin
    // Only test for hardcoded size. TODO: dwarf 3 could have variable size, but for char that is not expected
    // TODO: Size of member[0] ?
    if not ti.ReadSize(nil, Size) then begin
      SetLastError(CreateError(fpErrAnyError, ['Can index element of unknown size']));
      exit;
    end;
    AIndex := AIndex * SizeToFullBytes(Size);
  end;
  addr := GetDerefAddress;
  if not IsTargetAddr(addr) then begin
    SetLastError(CreateError(fpErrAnyError, ['Internal dereference error']));
    exit;
  end;
  addr.Address := addr.Address + AIndex;
  {$POP}

  Tmp := TFpValueDwarfConstAddress.Create(addr);
  if ti <> nil then begin
    Result := ti.TypeCastValue(Tmp);
    Tmp.ReleaseReference;
    TFpValueDwarf(Result).SetStructureValue(Self);
    TFpValueDwarf(Result).Context := Context;
  end
  else begin
    Result := Tmp;
  end;
end;

procedure TFpValueDwarfPointer.SetAsCardinal(AValue: QWord);
begin
  if not Context.WriteSignedInt(OrdOrDataAddr, SizeVal(Context.SizeOfAddress), AValue) then begin
    SetLastError(Context.LastMemError);
    Exclude(FEvaluated, doneAddr);
  end
  else begin
    FPointedToAddr := TargetLoc(TDBGPtr(AValue));
    Include(FEvaluated, doneAddr);
  end;
end;

{ TFpValueDwarfEnum }

procedure TFpValueDwarfEnum.InitMemberIndex;
var
  v: QWord;
  i: Integer;
begin
  // TODO: if TypeInfo is a subrange, check against the bounds, then bypass it, and scan all members (avoid subrange scanning members)
  if FMemberValueDone then exit;
  // FTypeSymbol (if not nil) must be same as FTypeSymbol. It may have wrappers like declaration.
  v := GetAsCardinal;
  i := FTypeSymbol.NestedSymbolCount - 1;
  while i >= 0 do begin
    if FTypeSymbol.NestedSymbol[i].OrdinalValue = v then break;
    dec(i);
  end;
  FMemberIndex := i;
  FMemberValueDone := True;
end;

procedure TFpValueDwarfEnum.Reset;
begin
  inherited Reset;
  FMemberValueDone := False;
end;

function TFpValueDwarfEnum.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfOrdinal, svfMembers, svfIdentifier];
end;

function TFpValueDwarfEnum.GetAsCardinal: QWord;
var
  Size: TFpDbgValueSize;
begin
  if doneUInt in FEvaluated then begin
    Result := FValue;
    exit;
  end;
  Include(FEvaluated, doneUInt);

  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(Result)) then
    Result := inherited GetAsCardinal
  else
  if not Context.ReadEnum(OrdOrDataAddr, Size, Result) then begin
    SetLastError(Context.LastMemError);
    Result := 0; // TODO: error
  end;

  FValue := Result;
end;

procedure TFpValueDwarfEnum.SetAsCardinal(AValue: QWord);
var
  Size: TFpDbgValueSize;
begin
  if (not GetSize(Size)) or (Size <= 0) or (Size > SizeOf(AValue)) then begin
    inherited SetAsCardinal(AValue);
  end
  else
  if not Context.WriteEnum(OrdOrDataAddr, Size, AValue) then begin
    SetLastError(Context.LastMemError);
    Exclude(FEvaluated, doneUInt);
  end
  else begin
    FValue := AValue;
    Include(FEvaluated, doneUInt);
  end;
end;

function TFpValueDwarfEnum.GetAsString: AnsiString;
begin
  InitMemberIndex;
  if FMemberIndex >= 0 then
    Result := FTypeSymbol.NestedSymbol[FMemberIndex].Name
  else
    Result := '';
end;

function TFpValueDwarfEnum.GetMemberCount: Integer;
begin
  InitMemberIndex;
  if FMemberIndex < 0 then
    Result := 0
  else
    Result := 1;
end;

function TFpValueDwarfEnum.GetMember(AIndex: Int64): TFpValue;
begin
  InitMemberIndex;
  if (FMemberIndex >= 0) and (AIndex = 0) then begin
    Result := FTypeSymbol.GetNestedValue(FMemberIndex);
    assert(Result is TFpValueDwarfBase, 'Result is TFpValueDwarfBase');
    TFpValueDwarfBase(Result).Context := Context;
  end
  else
    Result := nil;
end;

procedure TFpValueDwarfEnum.SetAsString(AValue: AnsiString);
var
  EnumSymbol: TFpSymbol;
begin
  EnumSymbol := TypeInfo.NestedSymbolByName[AValue];
  if Assigned(EnumSymbol) then begin
    SetAsCardinal(EnumSymbol.OrdinalValue);
  end
  else
    SetLastError(CreateError(fpErrAnyError, ['Not a valid enum-value']));
end;

{ TFpValueDwarfEnumMember }

function TFpValueDwarfEnumMember.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfOrdinal, svfIdentifier];
end;

function TFpValueDwarfEnumMember.GetAsCardinal: QWord;
begin
  Result := FOwnerVal.OrdinalValue;
end;

function TFpValueDwarfEnumMember.GetAsString: AnsiString;
begin
  Result := FOwnerVal.Name;
end;

function TFpValueDwarfEnumMember.IsValidTypeCast: Boolean;
begin
  assert(False, 'TDbgDwarfEnumMemberSymbolValue.IsValidTypeCast can not be returned for typecast');
  Result := False;
end;

function TFpValueDwarfEnumMember.GetKind: TDbgSymbolKind;
begin
  Result := skEnumValue;
end;

constructor TFpValueDwarfEnumMember.Create(AOwner: TFpSymbolDwarfData);
begin
  FOwnerVal := AOwner;
  inherited Create(nil);
end;

{ TFpValueDwarfConstNumber }

procedure TFpValueDwarfConstNumber.Update(AValue: QWord; ASigned: Boolean);
begin
  Signed := ASigned;
  Value := AValue;
end;

{ TFpValueDwarfSet }

procedure TFpValueDwarfSet.InitMap;
const
  BitCount: array[0..15] of byte = (0, 1, 1, 2,  1, 2, 2, 3,  1, 2, 2, 3,  2, 3, 3, 4);
var
  i, i2, v, MemIdx, Bit, Cnt: Integer;

  t: TFpSymbol;
  hb, lb: Int64;
  DAddr: TFpDbgMemLocation;
  Size: TFpDbgValueSize;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  if (length(FMem) > 0) or (Size <= 0) then
    exit;
  t := TypeInfo;
  if t = nil then exit;
  t := t.TypeInfo;
  if t = nil then exit;

  GetDwarfDataAddress(DAddr);
  if not Context.ReadSet(DAddr, Size, FMem) then begin
    SetLastError(Context.LastMemError);
    exit; // TODO: error
  end;

  Cnt := 0;
  for i := 0 to Size.Size - 1 do
    Cnt := Cnt + (BitCount[FMem[i] and 15])  + (BitCount[(FMem[i] div 16) and 15]);
  FMemberCount := Cnt;

  if (Cnt = 0) then exit;
  SetLength(FMemberMap, Cnt);

  if (t.Kind = skEnum) then begin
    i2 := 0;
    for i := 0 to t.NestedSymbolCount - 1 do
    begin
      v := t.NestedSymbol[i].OrdinalValue;
      MemIdx := v shr 3;
      Bit := 1 shl (v and 7);
      if (FMem[MemIdx] and Bit) <> 0 then begin
        assert(i2 < Cnt, 'TDbgDwarfSetSymbolValue.InitMap too many members');
        if i2 = Cnt then break;
        FMemberMap[i2] := i;
        inc(i2);
      end;
    end;

    if i2 < Cnt then begin
      FMemberCount := i2;
      debugln(FPDBG_DWARF_DATA_WARNINGS, ['TDbgDwarfSetSymbolValue.InitMap  not enough members']);
    end;
  end
  else begin
    i2 := 0;
    MemIdx := 0;
    Bit := 1;
    t.GetValueBounds(nil, lb, hb);
    for i := lb to hb do
    begin
      if (FMem[MemIdx] and Bit) <> 0 then begin
        assert(i2 < Cnt, 'TDbgDwarfSetSymbolValue.InitMap too many members');
        if i2 = Cnt then break;
        FMemberMap[i2] := i - lb; // offset from low-bound
        inc(i2);
      end;
      if Bit = 128 then begin
        Bit := 1;
        inc(MemIdx);
      end
      else
        Bit := Bit shl 1;
    end;

    if i2 < Cnt then begin
      FMemberCount := i2;
      debugln(FPDBG_DWARF_DATA_WARNINGS, ['TDbgDwarfSetSymbolValue.InitMap  not enough members']);
    end;
  end;

end;

procedure TFpValueDwarfSet.Reset;
begin
  inherited Reset;
  SetLength(FMem, 0);
end;

function TFpValueDwarfSet.GetFieldFlags: TFpValueFieldFlags;
var
  Size: TFpDbgValueSize;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfMembers];
  if not GetSize(Size) then
    exit;
  if Size <= 8 then
    Result := Result + [svfOrdinal];
end;

function TFpValueDwarfSet.GetMemberCount: Integer;
begin
  InitMap;
  Result := FMemberCount;
end;

function TFpValueDwarfSet.GetMember(AIndex: Int64): TFpValue;
var
  lb: Int64;
  t: TFpSymbolDwarfType;
begin
  Result := nil;
  InitMap;
  t := TypeInfo;
  if t = nil then exit;
  t := t.TypeInfo;
  if t = nil then exit;
  assert(t is TFpSymbolDwarfType, 'TDbgDwarfSetSymbolValue.GetMember t');

  if t.Kind = skEnum then begin
    Result := t.GetNestedValue(FMemberMap[AIndex]);
    assert(Result is TFpValueDwarfBase, 'Result is TFpValueDwarfBase');
    TFpValueDwarfBase(Result).Context := Context;
  end
  else begin
    // TODO: value object for the subrange
    // TODO: cache the result
    if not t.GetValueLowBound(nil, lb) then
      lb := 0;
    if (FNumValue = nil) or (FNumValue.RefCount > 1) then begin // refcount 1 by FTypedNumValue
      FNumValue := TFpValueDwarfConstNumber.Create(FMemberMap[AIndex] + lb, t.Kind = skInteger);
    end
    else
    begin
      FNumValue.Update(FMemberMap[AIndex] + lb, t.Kind = skInteger);
      FNumValue.AddReference;
    end;

    if (FTypedNumValue = nil) or (FTypedNumValue.RefCount > 1) then begin
      FTypedNumValue.ReleaseReference;
      FTypedNumValue := t.TypeCastValue(FNumValue);
      assert((FTypedNumValue is TFpValueDwarf), 'is TFpValueDwarf');
      TFpValueDwarf(FTypedNumValue).Context := Context;
    end
    else
      TFpValueDwarf(FTypedNumValue).SetTypeCastInfo(FNumValue); // update

    FNumValue.ReleaseReference;
    Assert((FTypedNumValue <> nil) and (TFpValueDwarf(FTypedNumValue).IsValidTypeCast), 'TDbgDwarfSetSymbolValue.GetMember FTypedNumValue');
    Assert((FNumValue <> nil) and (FNumValue.RefCount > 0), 'TDbgDwarfSetSymbolValue.GetMember FNumValue');
    Result := FTypedNumValue;
    Result.AddReference;
  end;
end;

function TFpValueDwarfSet.GetAsCardinal: QWord;
var
  Size: TFpDbgValueSize;
begin
  Result := 0;
  if (not GetSize(Size)) or (Size < 0) or (Size > SizeOf(QWord)) then
    exit;
  InitMap;
  if (Size <= SizeOf(Result)) and (length(FMem) > 0) then
    move(FMem[0], Result, Min(SizeOf(Result), SizeToFullBytes(Size)));
end;

function TFpValueDwarfSet.IsValidTypeCast: Boolean;
var
  f: TFpValueFieldFlags;
  TypeSize, SrcSize: TFpDbgValueSize;
begin
  Result := HasTypeCastInfo;
  If not Result then
    exit;

  assert(FTypeSymbol.Kind = skSet, 'TFpValueDwarfSet.IsValidTypeCast: FTypeSymbol.Kind = skSet');

  if (FTypeCastSourceValue.TypeInfo = FTypeSymbol)
  then
    exit; // pointer deref

  // Is valid if source has Address, but NO Size
  f := FTypeCastSourceValue.FieldFlags;
  if (f * [svfAddress, svfSize, svfSizeOfPointer] = [svfAddress]) then
    exit;

  // Is valid if source has Address, but and same Size
  if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) then begin
    Result := GetSize(TypeSize) and GetSizeFor(FTypeCastSourceValue, SrcSize);
    if not Result then
      exit;
    if (TypeSize = SrcSize) then
      exit;
  end;

  Result := False;
end;

procedure TFpValueDwarfSet.SetAsString(AValue: AnsiString);
type
  TCharSet = set of char;
  function CheckInChar(var p: PChar; c: TCharSet): Boolean;
  begin
    Result := p^ in c;
    if Result then
      inc(p)
    else
      SetLastError(CreateError(fpErrFailedWriteMem));
  end;
  procedure SkipSpaces(var p: Pchar);
  begin
    while p^ in [' ', #9] do inc(p);
  end;
  function CopySubString(PEnd, PStart: PChar): String;
  begin
    SetLength(Result, PEnd - PStart);
    move(PStart^, Result[1], PEnd - PStart);
  end;
var
  Size: TFpDbgValueSize;
  WriteMem: array of Byte;
  p, p2: PChar;
  s: String;
  idx: Integer;
  t: TFpSymbolDwarfType;
  nest: TFpSymbol;
  v, lb, hb, MemIdx, Bit: Int64;
  DAddr: TFpDbgMemLocation;
begin
  if not GetSize(Size) then
    Size := ZeroSize;
  if (Size <= 0) then begin
    SetLastError(CreateError(fpErrFailedWriteMem));
    exit;
  end;
  InitMap;
  t := TypeInfo;
  if t = nil then exit;
  t := t.TypeInfo;
  if t = nil then exit;
  assert(t is TFpSymbolDwarfType, 'TDbgDwarfSetSymbolValue.GetMember t');

  SetLength(WriteMem, SizeToFullBytes(Size));

  p := Pchar(AValue);
  SkipSpaces(p);
  if not CheckInChar(p, ['[']) then
    exit;

  SkipSpaces(p);
  if p^ <> ']' then begin // not an empty set

    if t.Kind = skEnum then begin
      while p^ in ['a'..'z', 'A'..'Z', '_'] do begin
        p2 := p;
        inc(p);
        while p^ in ['a'..'z', 'A'..'Z', '_', '0'..'9'] do
          inc(p);
        s := LowerCase(CopySubString(p, p2));

        idx := t.GetNestedSymbolCount - 1;
        while idx >= 0 do begin
          nest := t.GetNestedSymbol(idx);
          if (nest <> nil) and (LowerCase(nest.Name) = s) then
            break;
          dec(idx);
        end;
        if (idx >= 0) then begin
          v := nest.OrdinalValue;
          if (v >= 0) and (v < Length(WriteMem) * 8) then begin
            MemIdx := v shr 3;
            Bit := 1 shl (v and 7);
            WriteMem[MemIdx] := WriteMem[MemIdx] or Bit;
          end
          else
            idx := -1;
        end;
        if idx < 0 then begin
          SetLastError(CreateError(fpErrFailedWriteMem));
          exit;
        end;

        SkipSpaces(p);
        if p^ = ']' then
          break;
        if not CheckInChar(p, [',']) then
          exit;
        SkipSpaces(p);
      end;
      SkipSpaces(p);
    end
    else begin // set of 1..9
      if not t.GetValueBounds(nil, lb, hb) then begin
        SetLastError(CreateError(fpErrFailedWriteMem));
        exit;
      end;

      while p^ in ['0'..'9', '$', '%', '&'] do begin
        p2 := p;
        inc(p);
        case p[-1] of
          '$': while p^ in ['a'..'f', 'A'..'F', '0'..'9'] do inc(p);
          '&': while p^ in ['0'..'7'] do inc(p);
          '%': while p^ in ['0'..'1'] do inc(p);
          else while p^ in ['0'..'9'] do inc(p);
        end;
        if not TryStrToInt(CopySubString(p, p2), idx) then begin
          SetLastError(CreateError(fpErrFailedWriteMem));
          exit;
        end;
        idx := idx - lb;

        if (idx >= 0) and (idx < Length(WriteMem) * 8) then begin
          MemIdx := idx shr 3;
          Bit := 1 shl (idx and 7);
          WriteMem[MemIdx] := WriteMem[MemIdx] or Bit;
        end
        else begin
          SetLastError(CreateError(fpErrFailedWriteMem));
          exit;
        end;

        SkipSpaces(p);
        if p^ = ']' then
          break;
        if not CheckInChar(p, [',']) then
          exit;
        SkipSpaces(p);
      end;
      SkipSpaces(p);
    end;

  end;
  if not CheckInChar(p, [']']) then
    exit;
  SkipSpaces(p);
  if not CheckInChar(p, [#0]) then
    exit;

  // we got the value
  FMem := nil;

  // todo writeset
  GetDwarfDataAddress(DAddr);
  if not Context.WriteSet(DAddr, Size, WriteMem) then begin
    SetLastError(Context.LastMemError);
    exit; // TODO: error
  end;

end;

destructor TFpValueDwarfSet.Destroy;
begin
  FTypedNumValue.ReleaseReference;
  inherited Destroy;
end;

{ TFpValueDwarfStruct }

procedure TFpValueDwarfStruct.Reset;
begin
  inherited Reset;
  FDataAddressDone := False;
end;

function TFpValueDwarfStruct.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfMembers];

  //TODO: svfDataAddress should depend on (hidden) Pointer or Ref in the TypeInfo
  if Kind in [skClass] then begin
    Result := Result + [svfOrdinal, svfDataAddress, svfDataSize]; // svfDataSize
    if ((FDataSymbol <> nil) and FDataSymbol.HasAddress) or
       (HasTypeCastInfo and (Kind = skClass))
    then
      Result := Result + [svfSizeOfPointer];
  end
  else begin
    Result := Result + [svfSize];
  end;
end;

function TFpValueDwarfStruct.GetAsCardinal: QWord;
var
  Addr: TFpDbgMemLocation;
begin
  if not GetDwarfDataAddress(Addr) then
    Result := 0
  else
  Result := QWord(LocToAddrOrNil(Addr));
end;

procedure TFpValueDwarfStruct.SetAsCardinal(AValue: QWord);
var
  Addr: TFpDbgMemLocation;
begin
  Addr := Address;
  if not IsValidLoc(Addr) then
    SetLastError(CreateError(fpErrFailedWriteMem))
  else begin
    if not Context.WriteUnsignedInt(Addr, SizeVal(Context.SizeOfAddress), AValue) then
      SetLastError(Context.LastMemError);
  end;
end;

function TFpValueDwarfStruct.GetDataSize: TFpDbgValueSize;
var
  ti: TFpSymbolDwarf;
begin
  Result := ZeroSize;
  ti := nil;
  if HasTypeCastInfo then begin
    Assert((FTypeSymbol = nil) or (FTypeSymbol is TFpSymbolDwarf));
    ti := FTypeSymbol;
  end
  else begin
    Assert((FDataSymbol = nil) or (FDataSymbol.TypeInfo is TFpSymbolDwarf));
    if (FDataSymbol <> nil) then
      ti := TFpSymbolDwarf(FDataSymbol.TypeInfo);
  end;

  if (ti <> nil) and (ti.Kind = skClass) then begin
    if not ti.DoReadDataSize(Self, Result) then
      Result := ZeroSize;
  end
  else
    if not GetSize(Result) then
      Result := ZeroSize;
end;

function TFpValueDwarfStruct.IsValidTypeCast: Boolean;
var
  f: TFpValueFieldFlags;
  SrcSize, TypeSize: TFpDbgValueSize;
begin
  if not HasTypeCastInfo then begin
    Result := inherited IsValidTypeCast;
  end
  else begin
    Result := HasTypeCastInfo;
    if not Result then
      exit;

    if FTypeSymbol.Kind in [skClass, skInstance] then begin
      f := FTypeCastSourceValue.FieldFlags;
      // skClass: Valid if Source has Ordinal
      Result := (svfOrdinal in f); // ordinal is prefered in GetDataAddress
      if Result then
        exit;
      // skClass: Valid if Source has Address, and (No Size) OR (same Size)
      if not (svfAddress in f) then
        exit;
      Result := not(svfSize in f);  // either svfSizeOfPointer or a void type, e.g. pointer(1)^
      if Result then
        exit;
      if not GetSizeFor(FTypeCastSourceValue, SrcSize) then
        exit;
      Result := SrcSize = AddressSize;
    end
    else begin
      f := FTypeCastSourceValue.FieldFlags;
      // skRecord: ONLY  Valid if Source has Address
      if (f * [{svfOrdinal, }svfAddress] = [svfAddress]) then begin
        // skRecord: AND either ... if Source has same Size
        if (f * [svfSize, svfSizeOfPointer]) = [svfSize] then begin
          Result := GetSize(TypeSize) and GetSizeFor(FTypeCastSourceValue, SrcSize);
          Result := Result and (TypeSize = SrcSize)
        end
        else
        // skRecord: AND either ... if Source has same Size (pointer size)
        if (f * [svfSize, svfSizeOfPointer]) = [svfSizeOfPointer] then begin
          Result := GetSize(TypeSize);
          Result := Result and (TypeSize = AddressSize);
        end
        // skRecord: AND either ... if Source has NO Size
        else
          Result := (f * [svfSize, svfSizeOfPointer]) = []; // source is a void type, e.g. pointer(1)^
      end
      else
        Result := False;
    end;
  end;
end;

{ TFpValueDwarfConstAddress }

procedure TFpValueDwarfConstAddress.Update(AnAddress: TFpDbgMemLocation);
begin
  Address := AnAddress;
end;

{ TFpValueDwarfArray }

procedure TFpValueDwarfArray.Reset;
begin
  FEvalFlags := [];
  FStrides := nil;
  inherited Reset;
end;

function TFpValueDwarfArray.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfMembers];
  if (TypeInfo <> nil) and (sfDynArray in TypeInfo.Flags) then
    Result := Result + [svfOrdinal, svfDataAddress];
end;

function TFpValueDwarfArray.GetKind: TDbgSymbolKind;
begin
  Result := skArray;
end;

function TFpValueDwarfArray.GetAsCardinal: QWord;
begin
  // TODO cache
  if not Context.ReadUnsignedInt(OrdOrAddress, SizeVal(AddressSize), Result) then begin
    SetLastError(Context.LastMemError);
    Result := 0;
  end;
end;

function TFpValueDwarfArray.GetMember(AIndex: Int64): TFpValue;
begin
  Result := GetMemberEx([AIndex]);
end;

function TFpValueDwarfArray.GetMemberEx(const AIndex: array of Int64
  ): TFpValue;
var
  Addr: TFpDbgMemLocation;
  i: Integer;
  Stride: TFpDbgValueSize;
begin
  Result := nil;
  assert((FArraySymbol is TFpSymbolDwarfTypeArray) and (FArraySymbol.Kind = skArray));

  Addr := TFpSymbolDwarfTypeArray(FArraySymbol).GetMemberAddress(Self, AIndex);
  if not IsReadableLoc(Addr) then exit;

  // FAddrObj.RefCount: hold by self
  i := 1;
  // FAddrObj.RefCount: hold by FLastMember (ignore only, if FLastMember is not hold by others)
  if (FLastMember <> nil) and (FLastMember.RefCount = 1) then
    i := 2;
  if (FAddrObj = nil) or (FAddrObj.RefCount > i) then begin
    FAddrObj.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FAddrObj, 'TDbgDwarfArraySymbolValue'){$ENDIF};
    FAddrObj := TFpValueDwarfConstAddress.Create(Addr);
    {$IFDEF WITH_REFCOUNT_DEBUG}FAddrObj.DbgRenameReference(@FAddrObj, 'TDbgDwarfArraySymbolValue');{$ENDIF}
  end
  else begin
    FAddrObj.Update(Addr);
  end;

  if (FLastMember = nil) or (FLastMember.RefCount > 1) then begin
    FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpValueDwarfArray.FLastMember'){$ENDIF};
    FLastMember := TFpValueDwarf(FArraySymbol.TypeInfo.TypeCastValue(FAddrObj));
    {$IFDEF WITH_REFCOUNT_DEBUG}FLastMember.DbgRenameReference(@FLastMember, 'TFpValueDwarfArray.FLastMember'){$ENDIF};
    FLastMember.Context := Context;
    if GetStride(Stride) then
      TFpValueDwarf(FLastMember).FForcedSize := Stride;
  end
  else begin
    TFpValueDwarf(FLastMember).SetTypeCastInfo(FAddrObj);
  end;

  Result := FLastMember;
  Result.AddReference;
end;

function TFpValueDwarfArray.GetMemberCount: Integer;
begin
  Result := 0;
  if not (efBoundsDone in FEvalFlags) then
    DoGetBounds;
  if (efBoundsUnavail in FEvalFlags) then
    Exit;
  if Abs(FBounds[0][1]-FBounds[0][0]) >= MaxLongint then
    Exit(0); // TODO: error
  Result := FBounds[0][1]-FBounds[0][0] + 1;
  if Result < 0 then
    Exit(0); // TODO: error
end;

function TFpValueDwarfArray.GetMemberCountEx(const AIndex: array of Int64
  ): Integer;
var
  i: SizeInt;
begin
  Result := 0;
  if not (efBoundsDone in FEvalFlags) then
    DoGetBounds;
  if (efBoundsUnavail in FEvalFlags) then
    Exit;
  i := Length(AIndex);
  if i > High(FBounds) then
    Exit;
  if Abs(FBounds[i][1]-FBounds[i][0]) >= MaxLongint then
    Exit(0); // TODO: error
  Result := FBounds[i][1]-FBounds[i][0] + 1;
  if Result < 0 then
    Exit(0); // TODO: error
end;

function TFpValueDwarfArray.GetIndexType(AIndex: Integer): TFpSymbol;
begin
  Result := TypeInfo.NestedSymbol[AIndex];
end;

function TFpValueDwarfArray.GetIndexTypeCount: Integer;
begin
  Result := TypeInfo.NestedSymbolCount;
end;

function TFpValueDwarfArray.IsValidTypeCast: Boolean;
var
  f: TFpValueFieldFlags;
  SrcSize, TypeSize: TFpDbgValueSize;
begin
  Result := HasTypeCastInfo;
  If not Result then
    exit;

  assert(FTypeSymbol.Kind = skArray, 'TFpValueDwarfArray.IsValidTypeCast: FTypeSymbol.Kind = skArray');
//TODO: shortcut, if FTypeSymbol = FTypeCastSourceValue.TypeInfo ?

  f := FTypeCastSourceValue.FieldFlags;
  if (f * [svfAddress, svfSize, svfSizeOfPointer] = [svfAddress]) then
    exit;

  if sfDynArray in FTypeSymbol.Flags then begin
    // dyn array
    if (svfOrdinal in f)then
      exit;
    if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) then begin
      Result := GetSizeFor(FTypeCastSourceValue, SrcSize);
      if not Result then
        exit;
      if (SrcSize = FTypeSymbol.CompilationUnit.AddressSize) then
        exit;
    end;
    if (f * [svfAddress, svfSizeOfPointer] = [svfAddress, svfSizeOfPointer]) then
      exit;
  end
  else begin
    // stat array
    if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) then begin
      Result := GetSize(TypeSize) and GetSizeFor(FTypeCastSourceValue, SrcSize);
      if not Result then
        exit;
      if (SrcSize = TypeSize) then
        exit;
    end;
  end;
  Result := False;
end;

function TFpValueDwarfArray.DoGetOrdering(out ARowMajor: Boolean): Boolean;
var
  ti: TFpSymbolDwarfType;
begin
  ti := TypeInfo;
  while ti is TFpSymbolDwarfTypeModifierBase do
    ti := ti.NestedTypeInfo;
  Result := TFpSymbolDwarfTypeArray(ti).DoReadOrdering(Self, ARowMajor);
end;

function TFpValueDwarfArray.DoGetStride(out AStride: TFpDbgValueSize): Boolean;
begin
  Result := TFpSymbolDwarfType(TypeInfo).DoReadStride(Self, AStride);
end;

function TFpValueDwarfArray.DoGetMemberSize(out ASize: TFpDbgValueSize
  ): Boolean;
begin
  ASize := ZeroSize;
  Result := GetStride(ASize);
  if (not Result) and (not IsError(LastError)) then begin
    Result := TypeInfo.TypeInfo <> nil;
    if Result then
      TypeInfo.TypeInfo.ReadSize(Self, ASize);
  end;
end;

function TFpValueDwarfArray.DoGetMainStride(out AStride: TFpDbgValueSize
  ): Boolean;
var
  ExtraStride: TFpDbgValueSize;
begin
  Result := GetMemberSize(AStride);
  if Result and (not IsError(LastError)) then begin
    assert(TypeInfo.NestedSymbolCount > 0, 'TFpValueDwarfArray.DoGetMainStride: TypeInfo.NestedSymbolCount > 0');
    Result := TFpSymbolDwarfType(TypeInfo.NestedSymbol[0]).DoReadStride(Self, ExtraStride);
    if Result then
      AStride := AStride + ExtraStride
    else
      Result := not IsError(LastError);
  end;
end;

function TFpValueDwarfArray.DoGetDimStride(AnIndex: integer; out
  AStride: TFpDbgValueSize): Boolean;
var
  ExtraStride: TFpDbgValueSize;
begin
  Result := GetMemberSize(AStride);
  if Result and (not IsError(LastError)) then begin
    assert(TypeInfo.NestedSymbolCount > AnIndex, 'TFpValueDwarfArray.DoGetDimStride(): TypeInfo.NestedSymbolCount > 0');
    Result := TFpSymbolDwarfType(TypeInfo.NestedSymbol[AnIndex]).DoReadStride(Self, ExtraStride);
    if Result then
      AStride := AStride + ExtraStride
    else
      Result := not IsError(LastError);
  end;
end;

constructor TFpValueDwarfArray.Create(ADwarfTypeSymbol: TFpSymbolDwarfType;
  AnArraySymbol: TFpSymbolDwarfTypeArray);
begin
  FArraySymbol := AnArraySymbol;
  inherited Create(ADwarfTypeSymbol);
end;

destructor TFpValueDwarfArray.Destroy;
begin
  FAddrObj.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FAddrObj, 'TDbgDwarfArraySymbolValue'){$ENDIF};
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpValueDwarfArray.FLastMember'){$ENDIF};
  inherited Destroy;
end;

function TFpValueDwarfArray.GetOrdering(out ARowMajor: Boolean): Boolean;
begin
  Result := not (efRowMajorUnavail in FEvalFlags);
  if not Result then // If there was an error, then LastError should still be set
    exit;

  if not (efRowMajorDone in FEvalFlags) then begin
    Result := DoGetOrdering(FRowMajor);
    if Result then
      Include(FEvalFlags, efRowMajorDone)
    else
      Include(FEvalFlags, efRowMajorUnavail);
  end;

  ARowMajor := FRowMajor;
end;

function TFpValueDwarfArray.GetStride(out AStride: TFpDbgValueSize): Boolean;
begin
  AStride := ZeroSize;
  Result := not (efStrideUnavail in FEvalFlags);
  if not Result then // If there was an error, then LastError should still be set
    exit;

  if not (efStrideDone in FEvalFlags) then begin
    Result := DoGetStride(FStride);
    if Result then
      Include(FEvalFlags, efStrideDone)
    else
      Include(FEvalFlags, efStrideUnavail);
  end;

  AStride := FStride;
end;

function TFpValueDwarfArray.GetMemberSize(out ASize: TFpDbgValueSize): Boolean;
begin
  Result := not (efMemberSizeUnavail in FEvalFlags);
  if not Result then // If there was an error, then LastError should still be set
    exit;

  if not (efMemberSizeDone in FEvalFlags) then begin
    Result := DoGetMemberSize(FMemberSize);
    if Result then
      Include(FEvalFlags, efMemberSizeDone)
    else
      Include(FEvalFlags, efMemberSizeUnavail);
  end;

  ASize := FMemberSize;
end;

function TFpValueDwarfArray.GetMainStride(out AStride: TFpDbgValueSize
  ): Boolean;
begin
  AStride := ZeroSize;
  Result := not (efMainStrideUnavail in FEvalFlags);
  if not Result then // If there was an error, then LastError should still be set
    exit;

  if not (efMainStrideDone in FEvalFlags) then begin
    Result := DoGetMainStride(FMainStride);
    if Result then
      Include(FEvalFlags, efMainStrideDone)
    else
      Include(FEvalFlags, efMainStrideUnavail);
  end;

  AStride := FMainStride;
end;

function TFpValueDwarfArray.GetDimStride(AnIndex: integer; out
  AStride: TFpDbgValueSize): Boolean;
begin
  AStride := ZeroSize;
  Result := AnIndex < MemberCount;
  if not Result then
    exit;
  if AnIndex < Length(FStrides) then
    SetLength(FStrides, MemberCount);

  Result := not FStrides[AnIndex].Unavail;
  if not Result then
    exit;
  if not FStrides[AnIndex].Done then begin
    Result := DoGetDimStride(AnIndex, FStrides[AnIndex].Stride);
    FStrides[AnIndex].Done := Result;
    FStrides[AnIndex].Unavail := not Result;
  end;
  AStride := FStrides[AnIndex].Stride;
end;

function TFpValueDwarfArray.GetOrdHighBound: Int64;
begin
  if not (efBoundsDone in FEvalFlags) then
    DoGetBounds;
  if Length(FBounds) > 0 then
    Result := FBounds[0][1]
  else
    Result := Inherited GetOrdLowBound;
end;

function TFpValueDwarfArray.GetOrdLowBound: Int64;
begin
  if not (efBoundsDone in FEvalFlags) then
    DoGetBounds;
  if Length(FBounds) > 0 then
    Result := FBounds[0][0]
  else
    Result := Inherited GetOrdLowBound;
end;

procedure TFpValueDwarfArray.DoGetBounds;
var
  t: TFpSymbol;
  c: Integer;
  i: Integer;
begin
  if not (efBoundsDone in FEvalFlags) then begin
    Include(FEvalFlags, efBoundsDone);
    t := TypeInfo;
    c := t.NestedSymbolCount;
    if c < 1 then begin
      Include(FEvalFlags, efBoundsUnavail);
      exit;
      end;
    SetLength(FBounds, c);
    for i := 0 to c -1 do begin
      t := t.NestedSymbol[i];
      if not t.GetValueBounds(self, FBounds[i][0], FBounds[i][1]) then
        Include(FEvalFlags, efBoundsUnavail)
    end;
  end;
end;

function TFpValueDwarfArray.GetHasBounds: Boolean;
begin
  if not (efBoundsDone in FEvalFlags) then
    DoGetBounds;
  Result := not (efBoundsUnavail in FEvalFlags)
    and (FBounds[0][1]>0); // Empty array has no bounds
end;

{ TDbgDwarfIdentifier }

function TFpSymbolDwarf.GetNestedTypeInfo: TFpSymbolDwarfType;
begin
// TODO DW_AT_start_scope;
  Result := FNestedTypeInfo;
  if (Result <> nil) or (didtTypeRead in FDwarfReadFlags) then
    exit;

  include(FDwarfReadFlags, didtTypeRead);
  FNestedTypeInfo := DoGetNestedTypeInfo;
  {$IFDEF WITH_REFCOUNT_DEBUG}if FNestedTypeInfo <> nil then FNestedTypeInfo.DbgRenameReference(@FNestedTypeInfo, ClassName+'.FNestedTypeInfo'){$ENDIF};

  Result := FNestedTypeInfo;
end;

function TFpSymbolDwarf.GetTypeInfo: TFpSymbolDwarfType;
begin
  assert((inherited TypeInfo = nil) or (inherited TypeInfo is TFpSymbolDwarfType), 'TFpSymbolDwarf.GetTypeInfo: (inherited TypeInfo = nil) or (inherited TypeInfo is TFpSymbolDwarfType)');
  Result := TFpSymbolDwarfType(inherited TypeInfo);
end;

procedure TFpSymbolDwarf.SetLocalProcInfo(AValue: TFpSymbolDwarf);
begin
  if FLocalProcInfo = AValue then exit;

  FLocalProcInfo.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLocalProcInfo, 'FLocalProcInfo'){$ENDIF};

  FLocalProcInfo := AValue;

  if (FLocalProcInfo <> nil) then
    FLocalProcInfo.AddReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLocalProcInfo, 'FLocalProcInfo'){$ENDIF};
end;

function TFpSymbolDwarf.DoGetNestedTypeInfo: TFpSymbolDwarfType;
var
  FwdInfoPtr: Pointer;
  FwdCompUint: TDwarfCompilationUnit;
  InfoEntry: TDwarfInformationEntry;
begin // Do not access anything that may need forwardSymbol
  if InformationEntry.ReadReference(DW_AT_type, FwdInfoPtr, FwdCompUint) then begin
    InfoEntry := TDwarfInformationEntry.Create(FwdCompUint, FwdInfoPtr);
    Result := TFpSymbolDwarfType.CreateTypeSubClass('', InfoEntry);
    ReleaseRefAndNil(InfoEntry);
  end
  else
    Result := nil;
end;

function TFpSymbolDwarf.ReadMemberVisibility(out
  AMemberVisibility: TDbgSymbolMemberVisibility): Boolean;
var
  Val: Integer;
begin
  Result := InformationEntry.ReadValue(DW_AT_external, Val);
  if Result and (Val <> 0) then begin
    AMemberVisibility := svPublic;
    exit;
  end;

  Result := InformationEntry.ReadValue(DW_AT_accessibility, Val);
  if not Result then exit;
  case Val of
    DW_ACCESS_private:   AMemberVisibility := svPrivate;
    DW_ACCESS_protected: AMemberVisibility := svProtected;
    DW_ACCESS_public:    AMemberVisibility := svPublic;
    else                 AMemberVisibility := svPrivate;
  end;
end;

function TFpSymbolDwarf.IsArtificial: Boolean;
begin
  if not(didtArtificialRead in FDwarfReadFlags) then begin
    if InformationEntry.IsArtificial then
      Include(FDwarfReadFlags, didtIsArtifical);
    Include(FDwarfReadFlags, didtArtificialRead);
  end;
  Result := didtIsArtifical in FDwarfReadFlags;
end;

procedure TFpSymbolDwarf.NameNeeded;
var
  AName: String;
begin
  if InformationEntry.ReadName(AName) then
    SetName(AName)
  else
    inherited NameNeeded;
end;

procedure TFpSymbolDwarf.TypeInfoNeeded;
begin
  SetTypeInfo(NestedTypeInfo);
end;

function TFpSymbolDwarf.DoForwardReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  Result := inherited DoReadSize(AValueObj, ASize);
end;

function TFpSymbolDwarf.DoReadDataSize(const AValueObj: TFpValue; out
  ADataSize: TFpDbgValueSize): Boolean;
var
  t: TFpSymbolDwarfType;
begin
  t := NestedTypeInfo;
  if t <> nil then
    Result := t.DoReadDataSize(AValueObj, ADataSize)
  else
  begin
    Result := False;
    ADataSize := ZeroSize;
  end;
end;

function TFpSymbolDwarf.InitLocationParser(const ALocationParser: TDwarfLocationExpression;
  AnInitLocParserData: PInitLocParserData): Boolean;
var
  ObjDataAddr: TFpDbgMemLocation;
begin
  if (AnInitLocParserData <> nil) then begin
    ObjDataAddr := AnInitLocParserData^.ObjectDataAddress;
    if IsValidLoc(ObjDataAddr) then begin
      if ObjDataAddr.MType = mlfConstant then begin
        DebugLn(DBG_WARNINGS, 'Changing mlfConstant to mlfConstantDeref'); // TODO: Should be done by caller
        ObjDataAddr.MType := mlfConstantDeref;
      end;

      debugln(FPDBG_DWARF_VERBOSE, ['TFpSymbolDwarf.InitLocationParser CurrentObjectAddress=', dbgs(ObjDataAddr), ' Push=',AnInitLocParserData^.ObjectDataAddrPush]);
      ALocationParser.CurrentObjectAddress := ObjDataAddr;
      if AnInitLocParserData^.ObjectDataAddrPush then
        ALocationParser.Push(ObjDataAddr);
    end
    else
      ALocationParser.CurrentObjectAddress := InvalidLoc
  end
  else
    ALocationParser.CurrentObjectAddress := InvalidLoc;

  Result := True;
end;

function TFpSymbolDwarf.ComputeDataMemberAddress(
  const AnInformationEntry: TDwarfInformationEntry; AValueObj: TFpValueDwarf;
  var AnAddress: TFpDbgMemLocation): Boolean;
var
  AttrData, AttrDataBitSize, AttrDataBitOffset: TDwarfAttribData;
  Form: Cardinal;
  ConstOffs: Int64;
  InitLocParserData: TInitLocParserData;
  ByteSize: TFpDbgValueSize;
  BitOffset, BitSize: Int64;
begin
  Result := True;
  if AnInformationEntry.GetAttribData(DW_AT_data_member_location, AttrData) then begin
    Form := AnInformationEntry.AttribForm[AttrData.Idx];
    Result := False;

    if Form in [DW_FORM_data1, DW_FORM_data2, DW_FORM_sdata, DW_FORM_udata] then begin
      if AnInformationEntry.ReadValue(AttrData, ConstOffs) then begin
        {$PUSH}{$R-}{$Q-} // TODO: check overflow
        AnAddress.Address := AnAddress.Address + ConstOffs;
        {$POP}
         Result := True;
      end
      else
        SetLastError(AValueObj, CreateError(fpErrAnyError));
    end

    // TODO: loclistptr: DW_FORM_data4, DW_FORM_data8,
    else

    if Form in [DW_FORM_block, DW_FORM_block1, DW_FORM_block2, DW_FORM_block4] then begin
      InitLocParserData.ObjectDataAddress := AnAddress;
      InitLocParserData.ObjectDataAddrPush := True;
      Result := LocationFromAttrData(AttrData, AValueObj, AnAddress, @InitLocParserData);
    end

    else begin
      SetLastError(AValueObj, CreateError(fpErrAnyError));
    end;

    // Bit Offset
    if Result and AnInformationEntry.GetAttribData(DW_AT_bit_offset, AttrDataBitOffset) then begin
      // Make sure we have ALL the data needed
      Result := InformationEntry.GetAttribData(DW_AT_bit_size, AttrDataBitSize);
      if Result then
        if InformationEntry.GetAttribData(DW_AT_byte_size, AttrData) then begin
          ByteSize := ZeroSize;
          Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, ByteSize.Size);
        end
        else
          Result := (TypeInfo <> nil) and TypeInfo.ReadSize(AValueObj, ByteSize);

      if Result then
        Result := ConstRefOrExprFromAttrData(AttrDataBitOffset, AValueObj as TFpValueDwarf, BitOffset) and
                  ConstRefOrExprFromAttrData(AttrDataBitSize, AValueObj as TFpValueDwarf, BitSize);

      if Result then
        AnAddress := AddBitOffset(AnAddress + ByteSize, -(BitOffset + BitSize));
    end;

    if not Result then
      SetLastError(AValueObj, CreateError(fpErrAnyError));
    exit;
  end;

  // Dwarf 4
  if AnInformationEntry.GetAttribData(DW_AT_data_bit_offset, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, BitOffset);
    if Result then
      AnAddress := AddBitOffset(AnAddress, BitOffset);

    if not Result then
      SetLastError(AValueObj, CreateError(fpErrAnyError));
  end;

end;

function TFpSymbolDwarf.ConstRefOrExprFromAttrData(
  const AnAttribData: TDwarfAttribData; AValueObj: TFpValueDwarf; out
  AValue: Int64; AReadState: PFpDwarfAtEntryDataReadState;
  ADataSymbol: PFpSymbolDwarfData): Boolean;
var
  Form: Cardinal;
  FwdInfoPtr: Pointer;
  FwdCompUint: TDwarfCompilationUnit;
  NewInfo: TDwarfInformationEntry;
  RefSymbol: TFpSymbolDwarfData;
  InitLocParserData: TInitLocParserData;
  t: TFpDbgMemLocation;
  ValObj: TFpValue;
begin
  Form := InformationEntry.AttribForm[AnAttribData.Idx];
  Result := False;

  if Form in [DW_FORM_data1, DW_FORM_data2, DW_FORM_data4, DW_FORM_data8,
              DW_FORM_sdata, DW_FORM_udata]
  then begin
    Result := InformationEntry.ReadValue(AnAttribData, AValue);
    if Result then begin
      if AReadState <> nil then
        AReadState^ := rfConst;
    end
    else begin
      if AReadState <> nil then
        AReadState^ := rfError;
      SetLastError(AValueObj, CreateError(fpErrAnyError));
    end;
  end

  else
  if Form in [DW_FORM_ref1, DW_FORM_ref2, DW_FORM_ref4, DW_FORM_ref8,
              DW_FORM_ref_addr, DW_FORM_ref_udata]
  then begin
    if AValueObj = nil then
      exit(False); // keep state rfNotRead;

    if AReadState <> nil then
      AReadState^ := rfValue;

    Result := InformationEntry.ReadReference(AnAttribData, FwdInfoPtr, FwdCompUint);
    if Result then begin
      NewInfo := TDwarfInformationEntry.Create(FwdCompUint, FwdInfoPtr);
      RefSymbol := TFpSymbolDwarfData.CreateValueSubClass('', NewInfo);
      NewInfo.ReleaseReference;
      Result := RefSymbol <> nil;
      if Result then begin
        ValObj := RefSymbol.Value;
        Result := ValObj <> nil;
        if Result then begin
          assert(ValObj is TFpValueDwarfBase, 'Result is TFpValueDwarfBase');
          TFpValueDwarfBase(ValObj).Context := AValueObj.Context;
          AValue := ValObj.AsInteger;
          if IsError(ValObj.LastError) then begin
            Result := False;
            if AReadState <> nil then
              AReadState^ := rfError;
            SetLastError(AValueObj, ValObj.LastError);
          end;
          ValObj.ReleaseReference;

          if ADataSymbol <> nil then
            ADataSymbol^ := RefSymbol
          else
            RefSymbol.ReleaseReference;
        end
        else
          RefSymbol.ReleaseReference;
      end;
    end;
    if (not Result) and (not HasError(AValueObj)) then begin
      if AReadState <> nil then
        AReadState^ := rfError;
      SetLastError(AValueObj, CreateError(fpErrAnyError));
    end;
  end

  else
  if Form in [DW_FORM_block, DW_FORM_block1, DW_FORM_block2, DW_FORM_block4]
  then begin
    // TODO: until there always will be an AValueObj
    if AValueObj = nil then begin
      if AReadState <> nil then
        AReadState^ := rfNotRead;
        exit(False);
    end;

    if AReadState <> nil then
      AReadState^ := rfExpression;

    // TODO: (or not todo?) AValueObj may be the pointer (internal ptr to object),
    // but since that is the nearest actual variable => what would the LocExpr expect?
    // Maybe we need "AddressFor(type)  // see TFpSymbolDwarfFreePascalTypePointer.DoReadDataSize
    InitLocParserData.ObjectDataAddress := AValueObj.Address;
    if not IsValidLoc(InitLocParserData.ObjectDataAddress) then
      InitLocParserData.ObjectDataAddress := AValueObj.OrdOrAddress;
    InitLocParserData.ObjectDataAddrPush := False;
    Result := LocationFromAttrData(AnAttribData, AValueObj, t, @InitLocParserData);
    if Result then begin
      AValue := Int64(t.Address);
    end
    else begin
      if AReadState <> nil then
        AReadState^ := rfError;
      SetLastError(AValueObj, CreateError(fpErrLocationParser));
    end;
  end

  else begin
    if AReadState <> nil then
      AReadState^ := rfError;
    SetLastError(AValueObj, CreateError(fpErrAnyError));
  end;

  if (not Result) and (AReadState <> nil) then
    AReadState^ := rfError;
end;

function TFpSymbolDwarf.LocationFromAttrData(
  const AnAttribData: TDwarfAttribData; AValueObj: TFpValueDwarf;
  var AnAddress: TFpDbgMemLocation; AnInitLocParserData: PInitLocParserData;
  AnAdjustAddress: Boolean): Boolean;
var
  Val: TByteDynArray;
  LocationParser: TDwarfLocationExpression;
begin
  //debugln(['TDbgDwarfIdentifier.LocationFromAttrData', ClassName, '  ',Name, '  ', DwarfAttributeToString(ATag)]);

  Result := False;
  AnAddress := InvalidLoc;

  //TODO: avoid copying data
  // DW_AT_data_member_location in members [ block or const]
  // DW_AT_location [block or reference] todo: const
  if not InformationEntry.ReadValue(AnAttribData, Val) then begin
    DebugLn([FPDBG_DWARF_VERBOSE, 'LocationFromAttrData: failed to read DW_AT_location']);
    SetLastError(AValueObj, CreateError(fpErrAnyError));
    exit;
  end;

  if Length(Val) = 0 then begin
    DebugLn(FPDBG_DWARF_VERBOSE, 'LocationFromAttrData: Warning DW_AT_location empty');
    SetLastError(AValueObj, CreateError(fpErrAnyError));
    //exit;
  end;

  LocationParser := TDwarfLocationExpression.Create(@Val[0], Length(Val), CompilationUnit,
    AValueObj.Context);
  InitLocationParser(LocationParser, AnInitLocParserData);
  LocationParser.Evaluate;

  if IsError(LocationParser.LastError) then
    SetLastError(AValueObj, LocationParser.LastError);

  AnAddress := LocationParser.ResultData;
  Result := IsValidLoc(AnAddress);
  if IsTargetAddr(AnAddress) and  AnAdjustAddress then
    AnAddress.Address :=CompilationUnit.MapAddressToNewValue(AnAddress.Address);
  debugln(FPDBG_DWARF_VERBOSE and (not Result), ['TDbgDwarfIdentifier.LocationFromAttrDataFAILED']); // TODO

  LocationParser.Free;
end;

function TFpSymbolDwarf.LocationFromTag(ATag: Cardinal;
  AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
  AnInitLocParserData: PInitLocParserData; ASucessOnMissingTag: Boolean
  ): Boolean;
var
  AttrData: TDwarfAttribData;
begin
  //debugln(['TDbgDwarfIdentifier.LocationFromTag', ClassName, '  ',Name, '  ', DwarfAttributeToString(ATag)]);

  Result := False;
  //TODO: avoid copying data
  // DW_AT_data_member_location in members [ block or const]
  // DW_AT_location [block or reference] todo: const
  if not InformationEntry.GetAttribData(ATag, AttrData) then begin
    (* if ASucessOnMissingTag = true AND tag does not exist
       then AnAddress will NOT be modified
       this can be used for DW_AT_data_member_location, if it does not exist members are on input location
       TODO: review - better use temp var in caller
    *)
    Result := ASucessOnMissingTag;
    if not Result then
      AnAddress := InvalidLoc;
    if not Result then
      DebugLn([FPDBG_DWARF_VERBOSE, 'LocationFromTag: failed to read DW_AT_..._location / ASucessOnMissingTag=', dbgs(ASucessOnMissingTag)]);
    exit;
  end;

  Result := LocationFromAttrData(AttrData, AValueObj, AnAddress, AnInitLocParserData, ATag = DW_AT_location);
end;

function TFpSymbolDwarf.ConstantFromTag(ATag: Cardinal; out
  AConstData: TByteDynArray; var AnAddress: TFpDbgMemLocation;
  AnInformationEntry: TDwarfInformationEntry; ASucessOnMissingTag: Boolean
  ): Boolean;
var
  v: QWord;
  AttrData: TDwarfAttribData;
begin
  AConstData := nil;
  if InformationEntry.GetAttribData(DW_AT_const_value, AttrData) then
    case InformationEntry.AttribForm[AttrData.Idx] of
      DW_FORM_string, DW_FORM_strp,
      DW_FORM_block, DW_FORM_block1, DW_FORM_block2, DW_FORM_block4: begin
        Result := InformationEntry.ReadValue(AttrData, AConstData, True);
        if Result then
          if Length(AConstData) > 0 then
            AnAddress := SelfLoc(@AConstData[0])
          else
            AnAddress := InvalidLoc; // TODO: ???
      end;
      DW_FORM_data1, DW_FORM_data2, DW_FORM_data4, DW_FORM_data8, DW_FORM_sdata, DW_FORM_udata: begin
        Result := InformationEntry.ReadValue(AttrData, v);
        if Result then
          AnAddress := ConstLoc(v);
      end;
      else
        Result := False; // ASucessOnMissingTag ?
    end
  else
    Result := ASucessOnMissingTag;
end;

function TFpSymbolDwarf.GetDataAddress(AValueObj: TFpValueDwarf;
  var AnAddress: TFpDbgMemLocation; ATargetType: TFpSymbolDwarfType): Boolean;
var
  ti: TFpSymbolDwarfType;
  AttrData: TDwarfAttribData;
  t: Int64;
  dummy: Boolean;
begin
Assert(self is TFpSymbolDwarfType);
  Result := False;
  if InformationEntry.GetAttribData(DW_AT_allocated, AttrData) then begin
    if not ConstRefOrExprFromAttrData(AttrData, AValueObj, t) then
      exit;
    if t = 0 then begin
      AnAddress := NilLoc;
      exit(True);
    end;
  end;

  if InformationEntry.GetAttribData(DW_AT_associated, AttrData) then begin
    if not ConstRefOrExprFromAttrData(AttrData, AValueObj, t) then
      exit;
    if t = 0 then begin
      AnAddress := NilLoc;
      exit(True);
    end;
  end;

  Result := GetDataAddressNext(AValueObj, AnAddress, dummy, ATargetType);
  if not Result then
    exit;

  ti := GetNextTypeInfoForDataAddress(ATargetType);
  if ti = nil then
    exit;

  Result := ti.GetDataAddress(AValueObj, AnAddress, ATargetType);
end;

function TFpSymbolDwarf.GetNextTypeInfoForDataAddress(
  ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType;
begin
  if (ATargetType = nil) or (ATargetType = self) then
    Result := nil
  else
    Result := NestedTypeInfo;
end;

function TFpSymbolDwarf.GetDataAddressNext(AValueObj: TFpValueDwarf;
  var AnAddress: TFpDbgMemLocation; out ADoneWork: Boolean;
  ATargetType: TFpSymbolDwarfType): Boolean;
var
  AttrData: TDwarfAttribData;
  InitLocParserData: TInitLocParserData;
begin
  Result := True;
  ADoneWork := False;

  if InformationEntry.GetAttribData(DW_AT_data_location, AttrData) then begin
    ADoneWork := True;
    InitLocParserData.ObjectDataAddress := AnAddress;
    InitLocParserData.ObjectDataAddrPush := False;
    Result := LocationFromAttrData(AttrData, AValueObj, AnAddress, @InitLocParserData);
  end;
end;

function TFpSymbolDwarf.HasAddress: Boolean;
begin
  Result := False;
end;

function TFpSymbolDwarf.GetNestedValue(AIndex: Int64): TFpValueDwarf;
var
  OuterSym: TFpSymbolDwarfType;
  sym: TFpSymbol;
begin
  sym := GetNestedSymbolEx(AIndex, OuterSym);
  if sym <> nil then begin
    assert(sym is TFpSymbolDwarfData, 'TFpSymbolDwarf.GetNestedValue: sym is TFpSymbolDwarfData');
    Result := TFpValueDwarf(sym.Value);
    if Result <> nil then
      Result.FParentTypeSymbol := OuterSym;
  end
  else
    Result := nil;
end;

function TFpSymbolDwarf.GetNestedValueByName(const AIndex: String
  ): TFpValueDwarf;
var
  OuterSym: TFpSymbolDwarfType;
  sym: TFpSymbol;
begin
  sym := GetNestedSymbolExByName(AIndex, OuterSym);
  // Ignore third-party extensions that are not supported
  if (sym <> nil) and not (sym is TFpSymbolDwarfThirdPartyExtension) then begin
    assert(sym is TFpSymbolDwarfData, 'TFpSymbolDwarf.GetNestedValueByName: sym is TFpSymbolDwarfData');
    Result := TFpValueDwarf(sym.Value);
    if Result <> nil then
      Result.FParentTypeSymbol := OuterSym;
  end
  else
    Result := nil;
end;

function TFpSymbolDwarf.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  assert(False, 'TFpSymbolDwarf.GetNestedSymbolEx: False not a structuer');
  Result := nil;
  AnParentTypeSymbol := nil;
end;

function TFpSymbolDwarf.GetNestedSymbolExByName(const AIndex: String; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  assert(False, 'TFpSymbolDwarf.GetNestedSymbolExByName: False not a structuer');
  Result := nil;
  AnParentTypeSymbol := nil;
end;

function TFpSymbolDwarf.GetNestedSymbol(AIndex: Int64): TFpSymbol;
var
  dummy: TFpSymbolDwarfType;
begin
  Result := GetNestedSymbolEx(AIndex, dummy);
end;

function TFpSymbolDwarf.GetNestedSymbolByName(const AIndex: String): TFpSymbol;
var
  dummy: TFpSymbolDwarfType;
begin
  Result := GetNestedSymbolExByName(AIndex, dummy);
end;

procedure TFpSymbolDwarf.Init;
begin
  //
end;

class function TFpSymbolDwarf.CreateSubClass(const AName: String;
  AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarf;
var
  c: TDbgDwarfSymbolBaseClass;
begin
  c := AnInformationEntry.CompUnit.DwarfSymbolClassMap.GetDwarfSymbolClass(AnInformationEntry.AbbrevTag);
  Result := TFpSymbolDwarf(c.Create(AName, AnInformationEntry));
end;

destructor TFpSymbolDwarf.Destroy;
begin
  inherited Destroy;
  FNestedTypeInfo.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FNestedTypeInfo, ClassName+'.FNestedTypeInfo'){$ENDIF};
  FLocalProcInfo.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLocalProcInfo, 'FLocalProcInfo'){$ENDIF};
end;

function TFpSymbolDwarf.StartScope: TDbgPtr;
begin
  if not InformationEntry.ReadStartScope(Result) then
    Result := 0;
end;

{ TFpSymbolDwarfData }

function TFpSymbolDwarfData.GetValueAddress(AValueObj: TFpValueDwarf; out
  AnAddress: TFpDbgMemLocation): Boolean;
begin
  Result := False;
end;

procedure TFpSymbolDwarfData.KindNeeded;
var
  t: TFpSymbol;
begin
  t := TypeInfo;
  if t = nil then
    inherited KindNeeded
  else
    SetKind(t.Kind);
end;

procedure TFpSymbolDwarfData.MemberVisibilityNeeded;
var
  Val: TDbgSymbolMemberVisibility;
begin
  if ReadMemberVisibility(Val) then
    SetMemberVisibility(Val)
  else
  if TypeInfo <> nil then
    SetMemberVisibility(TypeInfo.MemberVisibility)
  else
    inherited MemberVisibilityNeeded;
end;

function TFpSymbolDwarfData.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  AnParentTypeSymbol := TypeInfo;
  if AnParentTypeSymbol = nil then begin
    Result := inherited GetNestedSymbolEx(AIndex, AnParentTypeSymbol);
    exit;
  end;

  // while holding result, until refcount added, do not call any function
  Result := AnParentTypeSymbol.GetNestedSymbolEx(AIndex, AnParentTypeSymbol);
  assert((Result = nil) or (Result is TFpSymbolDwarfData), 'TFpSymbolDwarfData.GetMember is Value');
end;

function TFpSymbolDwarfData.GetNestedSymbolExByName(const AIndex: String; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  AnParentTypeSymbol := TypeInfo;
  if AnParentTypeSymbol = nil then begin
    Result := inherited GetNestedSymbolExByName(AIndex, AnParentTypeSymbol);
    exit;
  end;

  // while holding result, until refcount added, do not call any function
  Result := AnParentTypeSymbol.GetNestedSymbolExByName(AIndex, AnParentTypeSymbol);
  assert((Result = nil) or (Result is TFpSymbolDwarfData), 'TFpSymbolDwarfData.GetMember is Value');
end;

function TFpSymbolDwarfData.GetNestedSymbolCount: Integer;
var
  ti: TFpSymbol;
begin
  ti := TypeInfo;
  if ti <> nil then
    Result := ti.NestedSymbolCount
  else
    Result := inherited GetNestedSymbolCount;
end;

procedure TFpSymbolDwarfData.Init;
begin
  inherited Init;
  SetSymbolType(stValue);
end;

class function TFpSymbolDwarfData.CreateValueSubClass(const AName: String;
  AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarfData;
var
  c: TDbgDwarfSymbolBaseClass;
begin
  c := AnInformationEntry.CompUnit.DwarfSymbolClassMap.GetDwarfSymbolClass(AnInformationEntry.AbbrevTag);

  if c.InheritsFrom(TFpSymbolDwarfData) then
    Result := TFpSymbolDwarfDataClass(c).Create(AName, AnInformationEntry)
  else
    Result := nil;
end;

{ TFpSymbolDwarfDataWithLocation }

function TFpSymbolDwarfDataWithLocation.InitLocationParser(const ALocationParser: TDwarfLocationExpression;
  AnInitLocParserData: PInitLocParserData): Boolean;
begin
  Result := inherited InitLocationParser(ALocationParser, AnInitLocParserData);
  ALocationParser.OnFrameBaseNeeded := @FrameBaseNeeded;
end;

procedure TFpSymbolDwarfDataWithLocation.FrameBaseNeeded(ASender: TObject);
var
  p: TFpSymbolDwarf;
  fb: TDBGPtr;
begin
  debugln(FPDBG_DWARF_SEARCH, ['TFpSymbolDwarfDataVariable.FrameBaseNeeded ']);
  p := LocalProcInfo;
  // TODO: what if parent is declaration?
  if p is TFpSymbolDwarfDataProc then begin
    fb := TFpSymbolDwarfDataProc(p).GetFrameBase(ASender as TDwarfLocationExpression);
    (ASender as TDwarfLocationExpression).FrameBase := fb;
    if fb = 0 then begin
      debugln(FPDBG_DWARF_ERRORS, ['DWARF ERROR in TFpSymbolDwarfDataWithLocation.FrameBaseNeeded result is 0']);
    end;
    exit;
  end;

{$warning TODO}
  //else
  //if ParentTypeInfo <> nil then
  //  ParentTypeInfo.fr;
  // TODO: check owner
  debugln(FPDBG_DWARF_ERRORS, ['DWARF ERROR in TFpSymbolDwarfDataWithLocation.FrameBaseNeeded no parent type info']);
  (ASender as TDwarfLocationExpression).FrameBase := 0;
end;

function TFpSymbolDwarfDataWithLocation.GetValueObject: TFpValue;
var
  ti: TFpSymbol;
begin
  Result := nil;
  ti := TypeInfo;
  if (ti = nil) or not (ti.SymbolType = stType) then exit;

  Result := TFpSymbolDwarfType(ti).GetTypedValueObject(False);
  if Result <> nil then
    TFpValueDwarf(Result).SetDataSymbol(self);
end;

{ TFpSymbolDwarfType }

procedure TFpSymbolDwarfType.Init;
begin
  inherited Init;
  SetSymbolType(stType);
end;

procedure TFpSymbolDwarfType.MemberVisibilityNeeded;
var
  Val: TDbgSymbolMemberVisibility;
begin
  if ReadMemberVisibility(Val) then
    SetMemberVisibility(Val)
  else
    inherited MemberVisibilityNeeded;
end;

function TFpSymbolDwarfType.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
var
  AttrData: TDwarfAttribData;
  Bits: Int64;
begin
  ASize := ZeroSize;
  Result := False;

  if InformationEntry.GetAttribData(DW_AT_bit_size, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, Bits);
    if not Result then
      exit;
    ASize := SizeFromBits(Bits);
    exit;
  end;

  if InformationEntry.GetAttribData(DW_AT_byte_size, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, ASize.Size);
    if not Result then
      exit;
  end;

  // If it does not have a size => No error
end;

function TFpSymbolDwarfType.DoReadStride(AValueObj: TFpValueDwarf; out
  AStride: TFpDbgValueSize): Boolean;
var
  BitStride: Int64;
  AttrData: TDwarfAttribData;
begin
  AStride := ZeroSize;
  Result := False;
  if InformationEntry.GetAttribData(DW_AT_bit_stride, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, BitStride);
    AStride := SizeFromBits(BitStride);
    exit;
  end;

  if InformationEntry.GetAttribData(DW_AT_byte_stride, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, AStride.Size);
    exit;
  end;
end;

function TFpSymbolDwarfType.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfUnknown.Create(AnOuterType);
end;

procedure TFpSymbolDwarfType.ResetValueBounds;
var
  ti: TFpSymbolDwarfType;
begin
  ti := NestedTypeInfo;
  if (ti <> nil) then
    ti.ResetValueBounds;
end;

function TFpSymbolDwarfType.ReadStride(AValueObj: TFpValueDwarf; out
  AStride: TFpDbgValueSize): Boolean;
begin
  Result := DoReadStride(AValueObj, AStride);
end;

class function TFpSymbolDwarfType.CreateTypeSubClass(const AName: String;
  AnInformationEntry: TDwarfInformationEntry): TFpSymbolDwarfType;
var
  c: TDbgDwarfSymbolBaseClass;
begin
  c := AnInformationEntry.CompUnit.DwarfSymbolClassMap.GetDwarfSymbolClass(AnInformationEntry.AbbrevTag);

  if c.InheritsFrom(TFpSymbolDwarfType) then
    Result := TFpSymbolDwarfTypeClass(c).Create(AName, AnInformationEntry)
  else
    Result := nil;
end;

function TFpSymbolDwarfType.TypeCastValue(AValue: TFpValue): TFpValue;
begin
  Result := GetTypedValueObject(True);
  If Result = nil then
    exit;
  assert(Result is TFpValueDwarf);
  if not TFpValueDwarf(Result).SetTypeCastInfo(AValue) then
    ReleaseRefAndNil(Result);
end;

{ TDbgDwarfBaseTypeIdentifier }

procedure TFpSymbolDwarfTypeBasic.KindNeeded;
var
  Encoding: Integer;
begin
  if not InformationEntry.ReadValue(DW_AT_encoding, Encoding) then begin
    DebugLn(FPDBG_DWARF_WARNINGS, ['TFpSymbolDwarfTypeBasic.KindNeeded: Failed reading encoding for ', DwarfTagToString(InformationEntry.AbbrevTag)]);
    inherited KindNeeded;
    exit;
  end;

  case Encoding of
    DW_ATE_address :      SetKind(skPointer);
    DW_ATE_boolean:       SetKind(skBoolean);
    //DW_ATE_complex_float:
    DW_ATE_float:         SetKind(skFloat);
    DW_ATE_signed:        SetKind(skInteger);
    DW_ATE_signed_char:   SetKind(skChar);
    DW_ATE_unsigned:      SetKind(skCardinal);
    DW_ATE_unsigned_char: SetKind(skChar);
    DW_ATE_numeric_string:SetKind(skChar); // temporary for widestring
    else
      begin
        DebugLn(FPDBG_DWARF_WARNINGS, ['TFpSymbolDwarfTypeBasic.KindNeeded: Unknown encoding ', DwarfBaseTypeEncodingToString(Encoding), ' for ', DwarfTagToString(InformationEntry.AbbrevTag)]);
        inherited KindNeeded;
      end;
  end;
end;

procedure TFpSymbolDwarfTypeBasic.TypeInfoNeeded;
begin
  SetTypeInfo(nil);
end;

function TFpSymbolDwarfTypeBasic.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  case Kind of
    skPointer:  Result := TFpValueDwarfPointer.Create(AnOuterType);
    skInteger:  Result := TFpValueDwarfInteger.Create(AnOuterType);
    skCardinal: Result := TFpValueDwarfCardinal.Create(AnOuterType);
    skBoolean:  Result := TFpValueDwarfBoolean.Create(AnOuterType);
    skChar:     Result := TFpValueDwarfChar.Create(AnOuterType);
    skFloat:    Result := TFpValueDwarfFloat.Create(AnOuterType);
  end;
end;

function TFpSymbolDwarfTypeBasic.GetValueBounds(AValueObj: TFpValue; out
  ALowBound, AHighBound: Int64): Boolean;
begin
  Result := GetValueLowBound(AValueObj, ALowBound); // TODO: ond GetValueHighBound() // but all callers must check result;
  if not GetValueHighBound(AValueObj, AHighBound) then
    Result := False;
end;

function TFpSymbolDwarfTypeBasic.GetValueLowBound(AValueObj: TFpValue; out
  ALowBound: Int64): Boolean;
var
  Size: TFpDbgValueSize;
begin
  Result := AValueObj.GetSize(Size);
  if not Result then
    exit;
  case Kind of
    skInteger:  ALowBound := -(int64( high(int64) shr (64 - Min(Size.Size, 8) * 8)))-1;
    skCardinal: ALowBound := 0;
    else
      Result := False;
  end;
end;

function TFpSymbolDwarfTypeBasic.GetValueHighBound(AValueObj: TFpValue; out
  AHighBound: Int64): Boolean;
var
  Size: TFpDbgValueSize;
begin
  Result := AValueObj.GetSize(Size);
  if not Result then
    exit;
  case Kind of
    skInteger:  AHighBound := int64( high(int64) shr (64 - Min(Size.Size, 8) * 8));
    skCardinal: AHighBound := int64( high(qword) shr (64 - Min(Size.Size, 8) * 8));
    else
      Result := False;
  end;
end;

{ TFpSymbolDwarfTypeModifierBase }

function TFpSymbolDwarfTypeModifierBase.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  p: TFpSymbol;
begin
  p := GetForwardToSymbol;
  if p <> nil then
    Result := TFpSymbolDwarfType(p).GetNestedSymbolEx(AIndex, AnParentTypeSymbol)
  else
    Result := nil;  //  Result := inherited GetMember(AIndex);
end;

function TFpSymbolDwarfTypeModifierBase.GetNestedSymbolExByName(
  const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  p: TFpSymbol;
begin
  p := GetForwardToSymbol;
  if p <> nil then
    Result := TFpSymbolDwarfType(p).GetNestedSymbolExByName(AIndex, AnParentTypeSymbol)
  else
    Result := nil;  //  Result := inherited GetMember(AIndex);
end;

function TFpSymbolDwarfTypeModifierBase.GetNestedSymbol(AIndex: Int64): TFpSymbol;
var
  p: TFpSymbol;
begin
  p := GetForwardToSymbol;
  if p <> nil then
    Result := p.NestedSymbol[AIndex]
  else
    Result := nil;  //  Result := inherited GetMember(AIndex);
end;

function TFpSymbolDwarfTypeModifierBase.GetNestedSymbolByName(
  const AIndex: String): TFpSymbol;
var
  p: TFpSymbol;
begin
  p := GetForwardToSymbol;
  if p <> nil then
    Result := p.NestedSymbolByName[AIndex]
  else
    Result := nil;  //  Result := inherited GetMemberByName(AIndex);
end;

{ TFpSymbolDwarfTypeModifier }

procedure TFpSymbolDwarfTypeModifier.TypeInfoNeeded;
var
  p: TFpSymbolDwarfType;
begin
  p := NestedTypeInfo;
  if p <> nil then
    SetTypeInfo(p.TypeInfo)
  else
    SetTypeInfo(nil);
end;

procedure TFpSymbolDwarfTypeModifier.ForwardToSymbolNeeded;
begin
  SetForwardToSymbol(NestedTypeInfo);
end;

function TFpSymbolDwarfTypeModifier.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  Result := inherited DoForwardReadSize(AValueObj, ASize);
end;

function TFpSymbolDwarfTypeModifier.DoReadStride(AValueObj: TFpValueDwarf; out
  AStride: TFpDbgValueSize): Boolean;
var
  p: TFpSymbol;
begin
  p := GetForwardToSymbol;
  if p <> nil then
    Result := TFpSymbolDwarfType(p).DoReadStride(AValueObj, AStride)
  else
    Result := inherited DoReadStride(AValueObj, AStride);
end;

function TFpSymbolDwarfTypeModifier.GetNextTypeInfoForDataAddress(
  ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType;
begin
  if (ATargetType = self) then
    Result := nil
  else
    Result := NestedTypeInfo;
end;

function TFpSymbolDwarfTypeModifier.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
var
  ti: TFpSymbolDwarfType;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  ti := NestedTypeInfo;
  if ti <> nil then
    Result := ti.GetTypedValueObject(ATypeCast, AnOuterType)
  else
    Result := inherited;
end;

{ TFpSymbolDwarfTypeRef }

function TFpSymbolDwarfTypeRef.GetFlags: TDbgSymbolFlags;
begin
  Result := (inherited GetFlags) + [sfInternalRef];
end;

function TFpSymbolDwarfTypeRef.GetDataAddressNext(AValueObj: TFpValueDwarf;
  var AnAddress: TFpDbgMemLocation; out ADoneWork: Boolean;
  ATargetType: TFpSymbolDwarfType): Boolean;
begin
  Result := inherited GetDataAddressNext(AValueObj, AnAddress, ADoneWork, ATargetType);
  if (not Result) or ADoneWork then
    exit;

  Result := AValueObj.MemManager <> nil;
  if not Result then begin
    SetLastError(AValueObj, CreateError(fpErrAnyError));
    exit;
  end;
  AnAddress := AValueObj.Context.ReadAddress(AnAddress, SizeVal(CompilationUnit.AddressSize));
  Result := IsValidLoc(AnAddress);

  if (not Result) and
     IsError(AValueObj.Context.LastMemError)
  then
    SetLastError(AValueObj, AValueObj.Context.LastMemError);
  // Todo: other error
end;

{ TFpSymbolDwarfTypeSubRange }

procedure TFpSymbolDwarfTypeSubRange.InitEnumIdx;
var
  t: TFpSymbolDwarfType;
  i: Integer;
  h, l: Int64;
begin
  if FEnumIdxValid then
    exit;
  FEnumIdxValid := True;

  t := NestedTypeInfo;
  i := t.NestedSymbolCount - 1;
  GetValueBounds(nil, l, h);

  while (i >= 0) and (t.NestedSymbol[i].OrdinalValue > h) do
    dec(i);
  FHighEnumIdx := i;

  while (i >= 0) and (t.NestedSymbol[i].OrdinalValue >= l) do
    dec(i);
  FLowEnumIdx := i + 1;
end;

function TFpSymbolDwarfTypeSubRange.DoGetNestedTypeInfo: TFpSymbolDwarfType;
begin
  Result := inherited DoGetNestedTypeInfo;
  if Result <> nil then
    exit;

  if FLowBoundState = rfValue then
    Result := FLowBoundSymbol.TypeInfo as TFpSymbolDwarfType
  else
  if FHighBoundState = rfValue then
    Result := FHighBoundSymbol.TypeInfo as TFpSymbolDwarfType
  else
  if FCountState = rfValue then
    Result := FCountSymbol.TypeInfo as TFpSymbolDwarfType;
end;

procedure TFpSymbolDwarfTypeSubRange.ForwardToSymbolNeeded;
begin
  SetForwardToSymbol(NestedTypeInfo);
end;

procedure TFpSymbolDwarfTypeSubRange.TypeInfoNeeded;
var
  p: TFpSymbolDwarfType;
begin
  p := NestedTypeInfo;
  if p <> nil then
    SetTypeInfo(p.TypeInfo)
  else
    SetTypeInfo(nil);
end;

procedure TFpSymbolDwarfTypeSubRange.NameNeeded;
var
  AName: String;
begin
  if InformationEntry.ReadName(AName) then
    SetName(AName)
  else
    SetName('');
end;

procedure TFpSymbolDwarfTypeSubRange.KindNeeded;
var
  t: TFpSymbol;
begin
// TODO: limit to ordinal types
  t := NestedTypeInfo;
  if t = nil then begin
    SetKind(skInteger);
  end
  else
    SetKind(t.Kind);
end;

function TFpSymbolDwarfTypeSubRange.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
var
  t: TFpSymbolDwarfType;
begin
  Result := inherited DoReadSize(AValueObj, ASize);
  if Result or HasError(AValueObj) then
    exit;

  t := NestedTypeInfo;
  if t = nil then begin
    Result := False;
    exit;
  end;

  Result := t.ReadSize(AValueObj, ASize);
end;

function TFpSymbolDwarfTypeSubRange.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  if Kind = skEnum then begin
    if not FEnumIdxValid then
      InitEnumIdx;
    Result := TFpSymbolDwarfType(NestedTypeInfo).GetNestedSymbolEx(AIndex - FLowEnumIdx, AnParentTypeSymbol);
  end
  else
    Result := inherited GetNestedSymbolEx(AIndex, AnParentTypeSymbol);
end;

function TFpSymbolDwarfTypeSubRange.GetNestedSymbolCount: Integer;
begin
  if Kind = skEnum then begin
    if not FEnumIdxValid then
      InitEnumIdx;
    Result := FHighEnumIdx - FLowEnumIdx + 1;
  end
  else
    Result := inherited GetNestedSymbolCount;
end;

function TFpSymbolDwarfTypeSubRange.GetFlags: TDbgSymbolFlags;
begin
  Result := (inherited GetFlags) + [sfSubRange];
end;

procedure TFpSymbolDwarfTypeSubRange.ResetValueBounds;
begin
  inherited ResetValueBounds;
  FLowBoundState := rfNotRead;
  FHighBoundState := rfNotRead;
  FCountState := rfNotRead;
end;

destructor TFpSymbolDwarfTypeSubRange.Destroy;
begin
  FLowBoundSymbol.ReleaseReference;
  FHighBoundSymbol.ReleaseReference;
  FCountSymbol.ReleaseReference;
  inherited Destroy;
end;

function TFpSymbolDwarfTypeSubRange.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
var
  ti: TFpSymbolDwarfType;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  ti := NestedTypeInfo;
  if ti <> nil then
    Result := ti.GetTypedValueObject(ATypeCast, AnOuterType)
  else
    Result := inherited;
end;

function TFpSymbolDwarfTypeSubRange.GetValueBounds(AValueObj: TFpValue; out
  ALowBound, AHighBound: Int64): Boolean;
begin
  Result := GetValueLowBound(AValueObj, ALowBound); // TODO: ond GetValueHighBound() // but all callers must check result;
  if not GetValueHighBound(AValueObj, AHighBound) then
    Result := False;
end;

function TFpSymbolDwarfTypeSubRange.GetValueLowBound(AValueObj: TFpValue;
  out ALowBound: Int64): Boolean;
var
  AttrData: TDwarfAttribData;
  t: Int64;
begin
  assert((AValueObj = nil) or (AValueObj is TFpValueDwarf), 'TFpSymbolDwarfTypeSubRange.GetValueLowBound: AValueObj is TFpValueDwarf(');
  if FLowBoundState = rfNotRead then begin
    if InformationEntry.GetAttribData(DW_AT_lower_bound, AttrData) then
      ConstRefOrExprFromAttrData(AttrData, TFpValueDwarf(AValueObj), t, @FLowBoundState, @FLowBoundSymbol)
    else
      FLowBoundState := rfNotFound;
    FLowBoundConst := t;
  end;

  Result := FLowBoundState in [rfConst, rfValue, rfExpression];
  ALowBound := FLowBoundConst;
end;

function TFpSymbolDwarfTypeSubRange.GetValueHighBound(AValueObj: TFpValue;
  out AHighBound: Int64): Boolean;
var
  AttrData: TDwarfAttribData;
  t: int64;
begin
  assert((AValueObj = nil) or (AValueObj is TFpValueDwarf), 'TFpSymbolDwarfTypeSubRange.GetValueHighBound: AValueObj is TFpValueDwarf(');
  if FHighBoundState = rfNotRead then begin
    if InformationEntry.GetAttribData(DW_AT_upper_bound, AttrData) then
      ConstRefOrExprFromAttrData(AttrData, TFpValueDwarf(AValueObj), t, @FHighBoundState, @FHighBoundSymbol)
    else
      FHighBoundState := rfNotFound;
    FHighBoundConst := t;
  end;

  Result := FHighBoundState in [rfConst, rfValue, rfExpression];
  AHighBound := FHighBoundConst;

  if FHighBoundState = rfNotFound then begin
    Result := GetValueLowBound(AValueObj, AHighBound);
    if Result then begin
      if FCountState = rfNotRead then begin
        if InformationEntry.GetAttribData(DW_AT_upper_bound, AttrData) then
          ConstRefOrExprFromAttrData(AttrData, TFpValueDwarf(AValueObj), t, @FCountState, @FCountSymbol)
        else
          FCountState := rfNotFound;
        FCountConst := t;
      end;

      Result := FCountState in [rfConst, rfValue, rfExpression];
      {$PUSH}{$R-}{$Q-}
      AHighBound := AHighBound + FCountConst;
      {$POP}
    end;
  end;
end;

procedure TFpSymbolDwarfTypeSubRange.Init;
begin
  FLowBoundState := rfNotRead;
  FHighBoundState := rfNotRead;
  FCountState := rfNotRead;
  inherited Init;
end;

{ TFpSymbolDwarfTypePointer }

procedure TFpSymbolDwarfTypePointer.KindNeeded;
begin
  SetKind(skPointer);
end;

function TFpSymbolDwarfTypePointer.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  ASize := ZeroSize;
  ASize.Size := CompilationUnit.AddressSize;
  Result := True;
end;

function TFpSymbolDwarfTypePointer.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfPointer.Create(AnOuterType);
end;

{ TFpSymbolDwarfTypeSubroutine }

procedure TFpSymbolDwarfTypeSubroutine.CreateMembers;
var
  Info: TDwarfInformationEntry;
  Info2: TDwarfInformationEntry;
begin
  if FProcMembers <> nil then
    exit;
  FProcMembers := TRefCntObjList.Create;
  Info := InformationEntry.Clone;
  Info.GoChild;

  while Info.HasValidScope do begin
    if ((Info.AbbrevTag = DW_TAG_formal_parameter) or (Info.AbbrevTag = DW_TAG_variable)) //and
       //not(Info.IsArtificial)
    then begin
      Info2 := Info.Clone;
      FProcMembers.Add(Info2);
      Info2.ReleaseReference;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
end;

function TFpSymbolDwarfTypeSubroutine.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  CreateMembers;
  AnParentTypeSymbol := Self;
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  FLastMember := TFpSymbolDwarf.CreateSubClass('', TDwarfInformationEntry(FProcMembers[AIndex]));
  {$IFDEF WITH_REFCOUNT_DEBUG}FLastMember.DbgRenameReference(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember');{$ENDIF}
  Result := FLastMember;
end;

function TFpSymbolDwarfTypeSubroutine.GetNestedSymbolExByName(const AIndex: String;
  out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  Info: TDwarfInformationEntry;
  s: String;
  i: Integer;
begin
  CreateMembers;
  AnParentTypeSymbol := Self;
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  FLastMember := nil;
  for i := 0 to FProcMembers.Count - 1 do begin
    Info := TDwarfInformationEntry(FProcMembers[i]);
    if Info.ReadName(s) and (CompareText(s, AIndex) = 0) then begin
      FLastMember := TFpSymbolDwarf.CreateSubClass('', Info);
      {$IFDEF WITH_REFCOUNT_DEBUG}FLastMember.DbgRenameReference(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember');{$ENDIF}
      break;
    end;
  end;
  Result := FLastMember;
end;

function TFpSymbolDwarfTypeSubroutine.GetNestedSymbolCount: Integer;
begin
  CreateMembers;
  Result := FProcMembers.Count;
end;

function TFpSymbolDwarfTypeSubroutine.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfSubroutine.Create(AnOuterType);
end;

function TFpSymbolDwarfTypeSubroutine.GetDataAddressNext(
  AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation; out
  ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean;
begin
  Result := inherited GetDataAddressNext(AValueObj, AnAddress, ADoneWork, ATargetType);
  if (not Result) or ADoneWork then
    exit;

  Result := AValueObj.MemManager <> nil;
  if not Result then begin
    SetLastError(AValueObj, CreateError(fpErrAnyError));
    exit;
  end;
  AnAddress := AValueObj.Context.ReadAddress(AnAddress, SizeVal(CompilationUnit.AddressSize));
  Result := IsValidLoc(AnAddress);

  if not Result then
    if IsError(AValueObj.Context.LastMemError) then
      SetLastError(AValueObj, AValueObj.Context.LastMemError);
  // Todo: other error
end;

procedure TFpSymbolDwarfTypeSubroutine.KindNeeded;
begin
  if TypeInfo <> nil then
    SetKind(skFunctionRef)
  else
    SetKind(skProcedureRef);
end;

function TFpSymbolDwarfTypeSubroutine.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  ASize := ZeroSize;
  ASize.Size := CompilationUnit.AddressSize;
  Result := True;
end;

destructor TFpSymbolDwarfTypeSubroutine.Destroy;
begin
  FreeAndNil(FProcMembers);
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  inherited Destroy;
end;

{ TDbgDwarfIdentifierEnumElement }

procedure TFpSymbolDwarfDataEnumMember.ReadOrdinalValue;
begin
  if FOrdinalValueRead then exit;
  FOrdinalValueRead := True;
  FHasOrdinalValue := InformationEntry.ReadValue(DW_AT_const_value, FOrdinalValue);
end;

procedure TFpSymbolDwarfDataEnumMember.KindNeeded;
begin
  SetKind(skEnumValue);
end;

function TFpSymbolDwarfDataEnumMember.GetHasOrdinalValue: Boolean;
begin
  ReadOrdinalValue;
  Result := FHasOrdinalValue;
end;

function TFpSymbolDwarfDataEnumMember.GetOrdinalValue: Int64;
begin
  ReadOrdinalValue;
  Result := FOrdinalValue;
end;

procedure TFpSymbolDwarfDataEnumMember.Init;
begin
  FOrdinalValueRead := False;
  inherited Init;
end;

function TFpSymbolDwarfDataEnumMember.GetValueObject: TFpValue;
begin
  Result := TFpValueDwarfEnumMember.Create(Self);
  TFpValueDwarf(Result).SetDataSymbol(self);
end;

{ TFpSymbolDwarfTypeEnum }

procedure TFpSymbolDwarfTypeEnum.CreateMembers;
var
  Info, Info2: TDwarfInformationEntry;
  sym: TFpSymbolDwarf;
begin
  if FMembers <> nil then
    exit;
  FMembers := TRefCntObjList.Create;
  Info := InformationEntry.FirstChild;
  if Info = nil then exit;

  while Info.HasValidScope do begin
    if (Info.AbbrevTag = DW_TAG_enumerator) then begin
      Info2 := Info.Clone;
      sym := TFpSymbolDwarf.CreateSubClass('', Info2);
      FMembers.Add(sym);
      sym.ReleaseReference;
      Info2.ReleaseReference;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
end;

function TFpSymbolDwarfTypeEnum.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfEnum.Create(AnOuterType);
end;

procedure TFpSymbolDwarfTypeEnum.KindNeeded;
begin
  SetKind(skEnum);
end;

function TFpSymbolDwarfTypeEnum.GetNestedSymbolEx(AIndex: Int64; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  CreateMembers;
  AnParentTypeSymbol := Self;
  Result := TFpSymbol(FMembers[AIndex]);
end;

function TFpSymbolDwarfTypeEnum.GetNestedSymbolExByName(const AIndex: String;
  out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  i: Integer;
  s, s1, s2: String;
begin
  if AIndex = '' then begin
    Result := nil;
    Exit;
  end;
  s1 := UTF8UpperCase(AIndex);
  s2 := UTF8LowerCase(AIndex);
  CreateMembers;
  AnParentTypeSymbol := Self;
  i := FMembers.Count - 1;
  while i >= 0 do begin
    Result := TFpSymbol(FMembers[i]);
    s := Result.Name;
    if (s <> '') and CompareUtf8BothCase(@s1[1], @s2[1], @s[1]) then
      exit;
    dec(i);
  end;
  Result := nil;
end;

function TFpSymbolDwarfTypeEnum.GetNestedSymbolCount: Integer;
begin
  CreateMembers;
  Result := FMembers.Count;
end;

destructor TFpSymbolDwarfTypeEnum.Destroy;
begin
  if FMembers <> nil then
  FreeAndNil(FMembers);
  inherited Destroy;
end;

function TFpSymbolDwarfTypeEnum.GetValueBounds(AValueObj: TFpValue; out
  ALowBound, AHighBound: Int64): Boolean;
begin
  Result := GetValueLowBound(AValueObj, ALowBound); // TODO: ond GetValueHighBound() // but all callers must check result;
  if not GetValueHighBound(AValueObj, AHighBound) then
    Result := False;
end;

function TFpSymbolDwarfTypeEnum.GetValueLowBound(AValueObj: TFpValue; out
  ALowBound: Int64): Boolean;
var
  c: Integer;
begin
  Result := True;
  c := NestedSymbolCount;
  if c > 0 then
    ALowBound := NestedSymbol[0].OrdinalValue
  else
    ALowBound := 0;
end;

function TFpSymbolDwarfTypeEnum.GetValueHighBound(AValueObj: TFpValue; out
  AHighBound: Int64): Boolean;
var
  c: Integer;
begin
  Result := True;
  c := NestedSymbolCount;
  if c > 0 then
    AHighBound := NestedSymbol[c-1].OrdinalValue
  else
    AHighBound := -1;
end;

{ TFpSymbolDwarfTypeSet }

procedure TFpSymbolDwarfTypeSet.KindNeeded;
begin
  SetKind(skSet);
end;

function TFpSymbolDwarfTypeSet.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfSet.Create(AnOuterType);
end;

function TFpSymbolDwarfTypeSet.GetNestedSymbolCount: Integer;
begin
  if TypeInfo.Kind = skEnum then
    Result := TypeInfo.NestedSymbolCount
  else
    Result := inherited GetNestedSymbolCount;
end;

function TFpSymbolDwarfTypeSet.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  if TypeInfo.Kind = skEnum then begin
    Result := TypeInfo.GetNestedSymbolEx(AIndex, AnParentTypeSymbol);
  end
  else
    Result := inherited GetNestedSymbolEx(AIndex, AnParentTypeSymbol);
end;

{ TFpSymbolDwarfDataMember }

function TFpSymbolDwarfDataMember.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
// COPY OF TFpSymbolDwarfType.DoReadSize
var
  AttrData: TDwarfAttribData;
  Bits: Int64;
begin
  ASize := ZeroSize;
  Result := False;

  if InformationEntry.GetAttribData(DW_AT_bit_size, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, Bits);
    if not Result then
      exit;
    ASize := SizeFromBits(Bits);
    exit;
  end;

  if InformationEntry.GetAttribData(DW_AT_byte_size, AttrData) then begin
    Result := ConstRefOrExprFromAttrData(AttrData, AValueObj as TFpValueDwarf, ASize.Size);
    if not Result then
      exit;
  end;

  // If it does not have a size => No error
end;

function TFpSymbolDwarfDataMember.GetValueAddress(AValueObj: TFpValueDwarf; out
  AnAddress: TFpDbgMemLocation): Boolean;
begin
  if AValueObj = nil then debugln([FPDBG_DWARF_VERBOSE, 'TFpSymbolDwarfDataMember.InitLocationParser: NO VAl Obj !!!!!!!!!!!!!!!'])
  else if AValueObj.StructureValue = nil then debugln(FPDBG_DWARF_VERBOSE, ['TFpSymbolDwarfDataMember.InitLocationParser: NO STRUCT Obj !!!!!!!!!!!!!!!']);

  if InformationEntry.HasAttrib(DW_AT_const_value) then begin
    // fpc specific => constant members
    Result := ConstantFromTag(DW_AT_const_value, FConstData, AnAddress);
    exit;
    // There should not be a DW_AT_data_member_location
  end;

  AnAddress := InvalidLoc;
  if (AValueObj = nil) or (AValueObj.StructureValue = nil) or (AValueObj.FParentTypeSymbol = nil)
  then begin
    debugln(FPDBG_DWARF_ERRORS, ['DWARF ERROR in TFpSymbolDwarfDataMember.InitLocationParser ']);
    Result := False;
    if not HasError(AValueObj) then
      SetLastError(AValueObj, CreateError(fpErrLocationParserInit)); // TODO: error message?
    exit;
  end;
  if not AValueObj.GetStructureDwarfDataAddress(AnAddress, AValueObj.FParentTypeSymbol) then begin
    debugln(FPDBG_DWARF_ERRORS, ['DWARF ERROR in TFpSymbolDwarfDataMember.InitLocationParser Error: ',ErrorCode(AValueObj.LastError)]);
    Result := False;
    if not HasError(AValueObj) then
      SetLastError(AValueObj, CreateError(fpErrLocationParserInit)); // TODO: error message?
    exit;
  end;
  //TODO: AValueObj.StructureValue.LastError

  Result := ComputeDataMemberAddress(InformationEntry, AValueObj, AnAddress);
  if not Result then
    exit;
end;

function TFpSymbolDwarfDataMember.HasAddress: Boolean;
begin
  // DW_AT_data_member_location defaults to zero => i.e. at the start of the containing structure
  Result := not (InformationEntry.HasAttrib(DW_AT_const_value));
            //(InformationEntry.HasAttrib(DW_AT_data_member_location));
end;

{ TFpSymbolDwarfTypeStructure }

function TFpSymbolDwarfTypeStructure.GetNestedSymbolExByName(
  const AIndex: String; out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  Ident: TDwarfInformationEntry;
  ti: TFpSymbolDwarfType;
begin
  // Todo, maybe create all children?
  if FLastChildByName <> nil then begin
    FLastChildByName.ReleaseReference;
    FLastChildByName := nil;
  end;
  Result := nil;

  Ident := InformationEntry.FindNamedChild(AIndex);
  if Ident <> nil then begin
    AnParentTypeSymbol := Self;
    FLastChildByName := TFpSymbolDwarf.CreateSubClass('', Ident);
    //assert is member ?
    ReleaseRefAndNil(Ident);
    Result := FLastChildByName;

    exit;
  end;

  ti := TypeInfo; // Parent
  if ti <> nil then
    Result := ti.GetNestedSymbolExByName(AIndex, AnParentTypeSymbol);
end;

function TFpSymbolDwarfTypeStructure.GetNestedSymbolCount: Integer;
var
  ti: TFpSymbol;
begin
  CreateMembers;
  Result := FMembers.Count;

  ti := TypeInfo;
  if ti <> nil then
    Result := Result + ti.NestedSymbolCount;
end;

function TFpSymbolDwarfTypeStructure.GetDataAddressNext(
  AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation; out
  ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean;
begin
  Result := inherited GetDataAddressNext(AValueObj, AnAddress, ADoneWork, ATargetType);

  // TODO: This should be done via GetNextTypeInfoForDataAddress, which should return the parent class

  (* We have the DataAddress for this class => stop here, unless ATargetType
     indicates that we want a parent-class DataAddress
     Adding the InheritanceInfo's DW_AT_data_member_location would normally
     have to be done by the parent class. But then we would need to make it
     available there.
     // TODO: Could not determine from the Dwarf Spec, if the parent class
        should skip its DW_AT_data_location, if it was reached via
        DW_AT_data_member_location
        The spec says "handled the same as for members" => might indicate it should
  *)

  if (ATargetType = nil) or (ATargetType = self) then
    exit;

  Result := IsReadableMem(AnAddress);
  if not Result then
    exit;
  InitInheritanceInfo;

  Result := FInheritanceInfo = nil;
  if Result then
    exit;

  Result := ComputeDataMemberAddress(FInheritanceInfo, AValueObj, AnAddress);
  if not Result then
    exit;
end;

function TFpSymbolDwarfTypeStructure.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  i: Int64;
  ti: TFpSymbolDwarfType;
begin
  CreateMembers;

  i := AIndex;
  ti := TypeInfo;
  if ti <> nil then
    i := i - ti.NestedSymbolCount;

  if i < 0 then
    Result := ti.GetNestedSymbolEX(AIndex, AnParentTypeSymbol)
  else begin
    AnParentTypeSymbol := Self;
    Result := TFpSymbol(FMembers[i]);
  end;
end;

destructor TFpSymbolDwarfTypeStructure.Destroy;
begin
  ReleaseRefAndNil(FInheritanceInfo);
  FreeAndNil(FMembers);
  FLastChildByName.ReleaseReference;
  inherited Destroy;
end;

procedure TFpSymbolDwarfTypeStructure.CreateMembers;
var
  Info: TDwarfInformationEntry;
  Info2: TDwarfInformationEntry;
  sym: TFpSymbolDwarf;
begin
  if FMembers <> nil then
    exit;
  FMembers := TRefCntObjList.Create;
  Info := InformationEntry.Clone;
  Info.GoChild;

  while Info.HasValidScope do begin
    if (Info.AbbrevTag = DW_TAG_member) or (Info.AbbrevTag = DW_TAG_subprogram) then begin
      Info2 := Info.Clone;
      sym := TFpSymbolDwarf.CreateSubClass('', Info2);
      FMembers.Add(sym);
      sym.ReleaseReference;
      Info2.ReleaseReference;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
end;

procedure TFpSymbolDwarfTypeStructure.InitInheritanceInfo;
begin
  if FInheritanceInfo = nil then
    FInheritanceInfo := InformationEntry.FindChildByTag(DW_TAG_inheritance);
end;

function TFpSymbolDwarfTypeStructure.DoGetNestedTypeInfo: TFpSymbolDwarfType;
var
  FwdInfoPtr: Pointer;
  FwdCompUint: TDwarfCompilationUnit;
  ParentInfo: TDwarfInformationEntry;
begin
  Result:= nil;
  InitInheritanceInfo;
  if (FInheritanceInfo <> nil) and
     FInheritanceInfo.ReadReference(DW_AT_type, FwdInfoPtr, FwdCompUint)
  then begin
    ParentInfo := TDwarfInformationEntry.Create(FwdCompUint, FwdInfoPtr);
    //DebugLn(FPDBG_DWARF_SEARCH, ['Inherited from ', dbgs(ParentInfo.FInformationEntry, FwdCompUint) ]);
    Result := TFpSymbolDwarfType.CreateTypeSubClass('', ParentInfo);
    ParentInfo.ReleaseReference;
  end;
end;

procedure TFpSymbolDwarfTypeStructure.KindNeeded;
begin
  if (InformationEntry.AbbrevTag = DW_TAG_class_type) then
    SetKind(skClass)
  else
  if (InformationEntry.AbbrevTag = DW_TAG_interface_type) then
    SetKind(skInterface)
  else
    SetKind(skRecord);
end;

function TFpSymbolDwarfTypeStructure.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
    Result := TFpValueDwarfStruct.Create(AnOuterType);
end;

{ TFpSymbolDwarfTypeArray }

procedure TFpSymbolDwarfTypeArray.CreateMembers;
var
  Info, Info2: TDwarfInformationEntry;
  t: Cardinal;
  sym: TFpSymbolDwarf;
begin
  if FMembers <> nil then
    exit;
  FMembers := TRefCntObjList.Create;

  Info := InformationEntry.FirstChild;
  if Info = nil then exit;

  while Info.HasValidScope do begin
    t := Info.AbbrevTag;
    if (t = DW_TAG_enumeration_type) or (t = DW_TAG_subrange_type) then begin
      Info2 := Info.Clone;
      sym := TFpSymbolDwarf.CreateSubClass('', Info2);
      FMembers.Add(sym);
      sym.ReleaseReference;
      Info2.ReleaseReference;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
end;

procedure TFpSymbolDwarfTypeArray.KindNeeded;
begin
  SetKind(skArray); // Todo: static/dynamic?
end;

function TFpSymbolDwarfTypeArray.DoReadOrdering(AValueObj: TFpValueDwarf; out
  ARowMajor: Boolean): Boolean;
var
  AVal: Integer;
  AttrData: TDwarfAttribData;
begin
  Result := True;
  ARowMajor := True; // default (at least in pas)

  if InformationEntry.GetAttribData(DW_AT_ordering, AttrData) then begin
    Result := InformationEntry.ReadValue(AttrData, AVal);
    if Result then
      ARowMajor := AVal = DW_ORD_row_major
    else
      SetLastError(AValueObj, CreateError(fpErrAnyError));
  end;
end;

function TFpSymbolDwarfTypeArray.GetTypedValueObject(ATypeCast: Boolean;
  AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfArray.Create(AnOuterType, Self);
end;

function TFpSymbolDwarfTypeArray.GetFlags: TDbgSymbolFlags;
  function IsDynSubRange(m: TFpSymbolDwarf): Boolean;
  begin
    Result := sfSubRange in m.Flags;
    if not Result then exit;
    while (m <> nil) and not(m is TFpSymbolDwarfTypeSubRange) do
      m := m.NestedTypeInfo;
    Result := m <> nil;
    if not Result then exit; // TODO: should not happen, handle error
    Result := (TFpSymbolDwarfTypeSubRange(m).FHighBoundState = rfValue) // dynamic high bound // TODO:? Could be rfConst for locationExpr
           or (TFpSymbolDwarfTypeSubRange(m).FHighBoundState = rfNotRead); // dynamic high bound (yet to be read)
  end;
var
  m: TFpSymbol;
  lb, hb: Int64;
begin
  Result := inherited GetFlags;
  if (NestedSymbolCount = 1) then begin   // TODO: move to freepascal specific
    m := NestedSymbol[0];
    if (not m.GetValueBounds(nil, lb, hb)) or                // e.g. Subrange with missing upper bound
       (hb < lb) or
       (IsDynSubRange(TFpSymbolDwarf(m)))
    then
      Result := Result + [sfDynArray]
    else
      Result := Result + [sfStatArray];
  end
  else
    Result := Result + [sfStatArray];
end;

function TFpSymbolDwarfTypeArray.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  CreateMembers;
  AnParentTypeSymbol := Self;
  Result := TFpSymbol(FMembers[AIndex]);
end;

function TFpSymbolDwarfTypeArray.GetNestedSymbolCount: Integer;
begin
  CreateMembers;
  Result := FMembers.Count;
end;

function TFpSymbolDwarfTypeArray.GetMemberAddress(AValueObj: TFpValueDwarf;
  const AIndex: array of Int64): TFpDbgMemLocation;
var
  Idx, Factor: Int64;
  LowBound, HighBound: int64;
  i: Integer;
  m: TFpSymbolDwarf;
  RowMajor: Boolean;
  Offs, StrideInBits: TFpDbgValueSize;
begin
  assert((AValueObj is TFpValueDwarfArray), 'TFpSymbolDwarfTypeArray.GetMemberAddress AValueObj');
//  ReadOrdering;
//  ReadStride(AValueObj); // TODO Stride per member (member = dimension/index)
  Result := InvalidLoc;

  if not TFpValueDwarfArray(AValueObj).GetMainStride(StrideInBits) then
    exit;
  if (StrideInBits <= 0) then
    exit;

  CreateMembers;
  if Length(AIndex) > FMembers.Count then
    exit;

  if AValueObj is TFpValueDwarfArray then begin
    if not TFpValueDwarfArray(AValueObj).GetDwarfDataAddress(Result) then begin
      Result := InvalidLoc;
      Exit;
    end;
  end
  else
    exit; // TODO error
  if IsTargetNil(Result) then begin
    Result := InvalidLoc;
    SetLastError(AValueObj, CreateError(fpErrAddressIsNil));
    Exit;
  end;
  assert(IsReadableMem(Result), 'DwarfArray MemberAddress');
  if not IsReadableMem(Result) then begin
    Result := InvalidLoc;
    SetLastError(AValueObj, CreateError(fpErrAnyError));
    Exit;
  end;

  Offs := ZeroSize;
  Factor := 1;


  if not TFpValueDwarfArray(AValueObj).GetOrdering(RowMajor) then
    exit;
  {$PUSH}{$R-}{$Q-} // TODO: check range of index
  if RowMajor then begin
    for i := Length(AIndex) - 1 downto 0 do begin
      Idx := AIndex[i];
      m := TFpSymbolDwarf(FMembers[i]);
      if i > 0 then begin
        if not m.GetValueBounds(AValueObj, LowBound, HighBound) then begin
          Result := InvalidLoc;
          exit;
        end;
        Idx := Idx - LowBound;
        Offs := Offs + StrideInBits * Idx * Factor;
        Factor := Factor * (HighBound - LowBound + 1);  // TODO range check
      end
      else begin
        if m.GetValueLowBound(AValueObj, LowBound) then
          Idx := Idx - LowBound;
        Offs := Offs + StrideInBits * Idx * Factor;
      end;
    end;
  end
  else begin
    for i := 0 to Length(AIndex) - 1 do begin
      Idx := AIndex[i];
      m := TFpSymbolDwarf(FMembers[i]);
      if i > 0 then begin
        if not m.GetValueBounds(AValueObj, LowBound, HighBound) then begin
          Result := InvalidLoc;
          exit;
        end;
        Idx := Idx - LowBound;
        Offs := Offs + StrideInBits * Idx * Factor;
        Factor := Factor * (HighBound - LowBound + 1);  // TODO range check
      end
      else begin
        if m.GetValueLowBound(AValueObj, LowBound) then
          Idx := Idx - LowBound;
        Offs := Offs + StrideInBits * Idx * Factor;
      end;
    end;
  end;

  Result := Result + Offs;
  {$POP}
end;

destructor TFpSymbolDwarfTypeArray.Destroy;
begin
  FreeAndNil(FMembers);
  inherited Destroy;
end;

procedure TFpSymbolDwarfTypeArray.ResetValueBounds;
var
  i: Integer;
begin
  inherited ResetValueBounds;
  if FMembers <> nil then
    for i := 0 to FMembers.Count - 1 do
      if TObject(FMembers[i]) is TFpSymbolDwarfType then
        TFpSymbolDwarfType(FMembers[i]).ResetValueBounds;
end;

{ TDbgDwarfSymbol }

constructor TFpSymbolDwarfDataProc.Create(
  ACompilationUnit: TDwarfCompilationUnit; AInfo: PDwarfAddressInfo;
  AAddress: TDbgPtr; ADbgInfo: TFpDwarfInfo);
var
  InfoEntry: TDwarfInformationEntry;
begin
  FAddress := AAddress;
  FAddressInfo := AInfo;
  FDwarf := ADbgInfo;

  InfoEntry := TDwarfInformationEntry.Create(ACompilationUnit, nil);
  InfoEntry.ScopeIndex := AInfo^.ScopeIndex;

  inherited Create(
    String(FAddressInfo^.Name),
    InfoEntry
  );

  SetAddress(TargetLoc(FAddressInfo^.StartPC));

  InfoEntry.ReleaseReference;
//BuildLineInfo(

//   AFile: String = ''; ALine: Integer = -1; AFlags: TDbgSymbolFlags = []; const AReference: TDbgSymbol = nil);
end;

destructor TFpSymbolDwarfDataProc.Destroy;
begin
  FreeAndNil(FStateMachine);
  inherited Destroy;
end;

function TFpSymbolDwarfDataProc.CreateSymbolScope(
  ALocationContext: TFpDbgLocationContext): TFpDbgSymbolScope;
begin
  Result := nil;
  if FDwarf <> nil then
    Result := CompilationUnit.DwarfSymbolClassMap.CreateScopeForSymbol
      (ALocationContext, Self, FDwarf);
end;

function TFpSymbolDwarfDataProc.CreateSymbolScope(
  ALocationContext: TFpDbgLocationContext; ADwarfInfo: TFpDwarfInfo
  ): TFpDbgSymbolScope;
begin
  Result := CompilationUnit.DwarfSymbolClassMap.CreateScopeForSymbol
    (ALocationContext, Self, ADwarfInfo);
end;

function TFpSymbolDwarfDataProc.GetColumn: Cardinal;
begin
  if StateMachineValid
  then Result := FStateMachine.Column
  else Result := inherited GetColumn;
end;

function TFpSymbolDwarfDataProc.GetFile: String;
begin
  if StateMachineValid
  then Result := FStateMachine.FileName
  else Result := inherited GetFile;
end;

function TFpSymbolDwarfDataProc.GetLine: Cardinal;
var
  sm: TDwarfLineInfoStateMachine;
begin
  if StateMachineValid
  then begin
    Result := FStateMachine.Line;
    if Result = 0 then begin // TODO: fpc specific.
      sm := FStateMachine.Clone;
      sm.NextLine;
      Result := sm.Line;
      sm.Free;
    end;
  end
  else Result := inherited GetLine;
end;

function TFpSymbolDwarfDataProc.GetLineEndAddress: TDBGPtr;
var
  sm: TDwarfLineInfoStateMachine;
begin
  if StateMachineValid
  then begin
    sm := FStateMachine.Clone;
    if sm.NextLine then
      Result := sm.Address
    else
      Result := 0;
    sm.Free;
  end
  else Result := 0;
end;

function TFpSymbolDwarfDataProc.GetLineStartAddress: TDBGPtr;
begin
  if StateMachineValid
  then
    Result := FStateMachine.Address
  else
    Result := 0;
end;

function TFpSymbolDwarfDataProc.GetLineUnfixed: TDBGPtr;
begin
  if StateMachineValid
  then
    Result := FStateMachine.Line
  else
    Result := inherited GetLine;
end;

function TFpSymbolDwarfDataProc.GetValueObject: TFpValue;
begin
  assert(TypeInfo is TFpSymbolDwarfType, 'TFpSymbolDwarfDataProc.GetValueObject: TypeInfo is TFpSymbolDwarfType');
  Result := TFpValueDwarfSubroutine.Create(TFpSymbolDwarfType(TypeInfo)); // TODO: GetTypedValueObject;
  TFpValueDwarf(Result).SetDataSymbol(self);
end;

function TFpSymbolDwarfDataProc.GetValueAddress(AValueObj: TFpValueDwarf; out
  AnAddress: TFpDbgMemLocation): Boolean;
var
  AttrData: TDwarfAttribData;
  Addr: TDBGPtr;
begin
  AnAddress := InvalidLoc;
  if InformationEntry.GetAttribData(DW_AT_low_pc, AttrData) then
    if InformationEntry.ReadAddressValue(AttrData, Addr) then
      AnAddress := TargetLoc(Addr);
  //DW_AT_ranges
  Result := IsValidLoc(AnAddress);
end;

function TFpSymbolDwarfDataProc.StateMachineValid: Boolean;
var
  SM1, SM2: TDwarfLineInfoStateMachine;
  SM2val: Boolean;
begin
  Result := FStateMachine <> nil;
  if Result then Exit;

  if FAddressInfo^.StateMachine = nil
  then begin
    CompilationUnit.BuildLineInfo(FAddressInfo, False);
    if FAddressInfo^.StateMachine = nil then Exit;
  end;

  // we cannot restore a statemachine to its current state
  // so we shouldn't modify FAddressInfo^.StateMachine
  // so use clones to navigate
  if FAddress < FAddressInfo^.StateMachine.Address
  then
    Exit;    // The address we want to find is before the start of this symbol ??

  SM1 := FAddressInfo^.StateMachine.Clone;
  SM2 := FAddressInfo^.StateMachine.Clone;

  repeat
    SM2val := SM2.NextLine;
    if (not SM1.EndSequence) and
       ( (FAddress = SM1.Address) or
         ( (FAddress > SM1.Address) and
           SM2val and (FAddress < SM2.Address)
         )
       )
    then begin
      // found
      FStateMachine := SM1;
      SM2.Free;
      Result := True;
      Exit;
    end;
  until not SM1.NextLine;

  //if all went well we shouldn't come here
  SM1.Free;
  SM2.Free;
end;

function TFpSymbolDwarfDataProc.ReadVirtuality(out AFlags: TDbgSymbolFlags): Boolean;
var
  Val: Integer;
begin
  AFlags := [];
  Result := InformationEntry.ReadValue(DW_AT_virtuality, Val);
  if not Result then exit;
  case Val of
    DW_VIRTUALITY_none:   ;
    DW_VIRTUALITY_virtual:      AFlags := [sfVirtual];
    DW_VIRTUALITY_pure_virtual: AFlags := [sfVirtual];
  end;
end;

function TFpSymbolDwarfDataProc.GetFrameBase(ASender: TDwarfLocationExpression): TDbgPtr;
var
  Val: TByteDynArray;
  rd: TFpDbgMemLocation;
begin
  Result := 0;
  if FFrameBaseParser = nil then begin
    //TODO: avoid copying data
    if not  InformationEntry.ReadValue(DW_AT_frame_base, Val) then begin
      // error
      debugln(FPDBG_DWARF_ERRORS, ['TFpSymbolDwarfDataProc.GetFrameBase failed to read DW_AT_frame_base']);
      exit;
    end;
    if Length(Val) = 0 then begin
      // error
      debugln(FPDBG_DWARF_ERRORS, ['TFpSymbolDwarfDataProc.GetFrameBase failed to read DW_AT_location']);
      exit;
    end;

    FFrameBaseParser := TDwarfLocationExpression.Create(@Val[0], Length(Val), CompilationUnit,
      ASender.Context);
    FFrameBaseParser.Evaluate;
  end;

  rd := FFrameBaseParser.ResultData;
  if IsValidLoc(rd) then
    Result := rd.Address;

  if IsError(FFrameBaseParser.LastError) then begin
    ASender.SetLastError(FFrameBaseParser.LastError);
    debugln(FPDBG_DWARF_ERRORS, ['TFpSymbolDwarfDataProc.GetFrameBase location parser failed ', ErrorHandler.ErrorAsString(ASender.LastError)]);
  end
  else
  if Result = 0 then begin
    debugln(FPDBG_DWARF_ERRORS, ['TFpSymbolDwarfDataProc.GetFrameBase location parser failed. result is 0']);
  end;

end;

function TFpSymbolDwarfDataProc.GetFlags: TDbgSymbolFlags;
var
  flg: TDbgSymbolFlags;
begin
  Result := inherited GetFlags;
  if ReadVirtuality(flg) then
    Result := Result + flg;
end;

procedure TFpSymbolDwarfDataProc.TypeInfoNeeded;
var
  t: TFpSymbolDwarfTypeProc;
begin
  t := TFpSymbolDwarfTypeProc.Create('', InformationEntry, FAddressInfo);
  SetTypeInfo(t); // TODO: avoid adding a reference, already got one....
  t.ReleaseReference;
end;

function TFpSymbolDwarfDataProc.GetParent: TFpSymbol;
var
  InfoEntry: TDwarfInformationEntry;
  tg: Cardinal;
  c: TDbgDwarfSymbolBaseClass;
begin
  // special: search "self"
  // Todo nested procs
  Result := nil;
  InfoEntry := InformationEntry.Clone;
  InfoEntry.GoParent;
  tg := InfoEntry.AbbrevTag;
  if (tg = DW_TAG_class_type) or (tg = DW_TAG_structure_type) then begin
    c := InfoEntry.CompUnit.DwarfSymbolClassMap.GetDwarfSymbolClass(tg);
    if c <> nil then
      Result := c.Create('', InfoEntry);
  end;
  InfoEntry.ReleaseReference;
end;

var
  ThisNameInfo, SelfNameInfo: TNameSearchInfo;
function TFpSymbolDwarfDataProc.GetSelfParameter(AnAddress: TDbgPtr): TFpValueDwarf;
var
  InfoEntry: TDwarfInformationEntry;
  tg: Cardinal;
  found: Boolean;
begin
  // special: search "self"
  // Todo nested procs
  Result := nil;
  InfoEntry := InformationEntry.Clone;
  //StartScopeIdx := InfoEntry.ScopeIndex;
  InfoEntry.GoParent;
  tg := InfoEntry.AbbrevTag;
  if (tg = DW_TAG_class_type) or (tg = DW_TAG_structure_type) then begin
    InfoEntry.ScopeIndex := InformationEntry.ScopeIndex;
    found := InfoEntry.GoNamedChildEx(ThisNameInfo);
    if not found then begin
      InfoEntry.ScopeIndex := InformationEntry.ScopeIndex;
      found := InfoEntry.GoNamedChildEx(SelfNameInfo);
    end;
    if found then begin
      if ((AnAddress = 0) or InfoEntry.IsAddressInStartScope(AnAddress)) and
         InfoEntry.IsArtificial
      then begin
        Result := TFpValueDwarf(TFpSymbolDwarfData.CreateValueSubClass('self', InfoEntry).Value);
        if Result <> nil then begin
          Result.FDataSymbol.ReleaseReference;
          Result.FDataSymbol.LocalProcInfo := Self;
        end;
        debugln(FPDBG_DWARF_SEARCH, ['TFpSymbolDwarfDataProc.GetSelfParameter ', InfoEntry.ScopeDebugText, DbgSName(Result)]);
      end;
    end;
  end;
  InfoEntry.ReleaseReference;
end;

{ TFpSymbolDwarfTypeProc }

procedure TFpSymbolDwarfTypeProc.CreateMembers;
var
  Info: TDwarfInformationEntry;
  Info2: TDwarfInformationEntry;
begin
  if FProcMembers <> nil then
    exit;
  FProcMembers := TRefCntObjList.Create;
  Info := InformationEntry.Clone;
  Info.GoChild;

  while Info.HasValidScope do begin
    if ((Info.AbbrevTag = DW_TAG_formal_parameter) or (Info.AbbrevTag = DW_TAG_variable)) //and
       //not(Info.IsArtificial)
    then begin
      Info2 := Info.Clone;
      FProcMembers.Add(Info2);
      Info2.ReleaseReference;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
end;

procedure TFpSymbolDwarfTypeProc.NameNeeded;
begin
  case Kind of
    skFunction:  SetName('function');
    skProcedure: SetName('procedure');
    else         SetName('');
  end;
end;

procedure TFpSymbolDwarfTypeProc.KindNeeded;
begin
  if TypeInfo <> nil then
    SetKind(skFunction)
  else
    SetKind(skProcedure);
end;

function TFpSymbolDwarfTypeProc.DoReadSize(const AValueObj: TFpValue; out
  ASize: TFpDbgValueSize): Boolean;
begin
  ASize := ZeroSize;
  Result := FAddressInfo <> nil;
  DebugLn(FPDBG_DWARF_WARNINGS, 'function has no address info');
  if Result then
    ASize.Size := FAddressInfo^.EndPC - FAddressInfo^.StartPC;
end;

function TFpSymbolDwarfTypeProc.GetNestedSymbolEx(AIndex: Int64; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
begin
  CreateMembers;
  AnParentTypeSymbol := nil;
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  FLastMember := TFpSymbolDwarf.CreateSubClass('', TDwarfInformationEntry(FProcMembers[AIndex]));
  {$IFDEF WITH_REFCOUNT_DEBUG}FLastMember.DbgRenameReference(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember');{$ENDIF}
  Result := FLastMember;
end;

function TFpSymbolDwarfTypeProc.GetNestedSymbolExByName(const AIndex: String;
  out AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  Info: TDwarfInformationEntry;
  s: String;
  i: Integer;
begin
  CreateMembers;
  AnParentTypeSymbol := nil;
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  FLastMember := nil;
  for i := 0 to FProcMembers.Count - 1 do begin
    Info := TDwarfInformationEntry(FProcMembers[i]);
    if Info.ReadName(s) and (CompareText(s, AIndex) = 0) then begin
      FLastMember := TFpSymbolDwarf.CreateSubClass('', Info);
      {$IFDEF WITH_REFCOUNT_DEBUG}FLastMember.DbgRenameReference(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember');{$ENDIF}
      break;
    end;
  end;
  Result := FLastMember;
end;

function TFpSymbolDwarfTypeProc.GetNestedSymbolCount: Integer;
begin
  CreateMembers;
  Result := FProcMembers.Count;
end;

constructor TFpSymbolDwarfTypeProc.Create(const AName: String;
  AnInformationEntry: TDwarfInformationEntry; AInfo: PDwarfAddressInfo);
begin
  FAddressInfo := AInfo;
  inherited Create(AName, AnInformationEntry);
end;

destructor TFpSymbolDwarfTypeProc.Destroy;
begin
  FreeAndNil(FProcMembers);
  FLastMember.ReleaseReference{$IFDEF WITH_REFCOUNT_DEBUG}(@FLastMember, 'TFpSymbolDwarfDataProc.FLastMember'){$ENDIF};
  inherited Destroy;
end;

{ TFpSymbolDwarfDataVariable }

function TFpSymbolDwarfDataVariable.GetValueAddress(AValueObj: TFpValueDwarf; out
  AnAddress: TFpDbgMemLocation): Boolean;
var
  AttrData: TDwarfAttribData;
begin
  if InformationEntry.GetAttribData(DW_AT_location, AttrData) then
    Result := LocationFromAttrData(AttrData, AValueObj, AnAddress, nil, True)
  else
    Result := ConstantFromTag(DW_AT_const_value, FConstData, AnAddress);
end;

function TFpSymbolDwarfDataVariable.HasAddress: Boolean;
begin
  // TODO: THis is wrong. It might allow for the @ operator on a const...
  Result := InformationEntry.HasAttrib(DW_AT_location) or
            InformationEntry.HasAttrib(DW_AT_const_value);
end;

{ TFpSymbolDwarfDataParameter }

function TFpSymbolDwarfDataParameter.GetValueAddress(AValueObj: TFpValueDwarf; out
  AnAddress: TFpDbgMemLocation): Boolean;
begin
  Result := LocationFromTag(DW_AT_location, AValueObj, AnAddress);
end;

function TFpSymbolDwarfDataParameter.HasAddress: Boolean;
begin
  Result := InformationEntry.HasAttrib(DW_AT_location);
end;

function TFpSymbolDwarfDataParameter.GetFlags: TDbgSymbolFlags;
begin
  Result := (inherited GetFlags) + [sfParameter];
end;

{ TFpSymbolDwarfUnit }

procedure TFpSymbolDwarfUnit.Init;
begin
  inherited Init;
  SetSymbolType(stNone);
  SetKind(skUnit);
end;

function TFpSymbolDwarfUnit.GetNestedSymbolExByName(const AIndex: String; out
  AnParentTypeSymbol: TFpSymbolDwarfType): TFpSymbol;
var
  Ident: TDwarfInformationEntry;
begin
  // Todo, param to only search external.
  ReleaseRefAndNil(FLastChildByName);
  Result := nil;
  AnParentTypeSymbol := nil;

  Ident := InformationEntry.Clone;
  Ident.GoNamedChildEx(AIndex);
  if Ident <> nil then
    Result := TFpSymbolDwarf.CreateSubClass('', Ident);
  ReleaseRefAndNil(Ident);
  FLastChildByName := Result;
end;

constructor TFpSymbolDwarfUnit.Create(const AName: String;
  AnInformationEntry: TDwarfInformationEntry; ADbgInfo: TFpDwarfInfo);
begin
  FDwarf := ADbgInfo;
  inherited Create(AName, AnInformationEntry);
end;

destructor TFpSymbolDwarfUnit.Destroy;
begin
  ReleaseRefAndNil(FLastChildByName);
  inherited Destroy;
end;

function TFpSymbolDwarfUnit.CreateSymbolScope(
  ALocationContext: TFpDbgLocationContext): TFpDbgSymbolScope;
begin
  Result := nil;
  if FDwarf <> nil then
    Result := CompilationUnit.DwarfSymbolClassMap.CreateScopeForSymbol
      (ALocationContext, Self, FDwarf);
end;

function TFpSymbolDwarfUnit.CreateSymbolScope(
  ALocationContext: TFpDbgLocationContext; ADwarfInfo: TFpDwarfInfo
  ): TFpDbgSymbolScope;
begin
  Result := CompilationUnit.DwarfSymbolClassMap.CreateScopeForSymbol
    (ALocationContext, Self, ADwarfInfo);
end;

initialization
  DwarfSymbolClassMapList.SetDefaultMap(TFpDwarfDefaultSymbolClassMap);

  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
  FPDBG_DWARF_VERBOSE       := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_VERBOSE' {$IFDEF FPDBG_DWARF_VERBOSE} , True {$ENDIF} );
  FPDBG_DWARF_ERRORS        := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_ERRORS' {$IFDEF FPDBG_DWARF_ERRORS} , True {$ENDIF} );
  FPDBG_DWARF_WARNINGS      := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_WARNINGS' {$IFDEF FPDBG_DWARF_WARNINGS} , True {$ENDIF} );
  FPDBG_DWARF_SEARCH        := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_SEARCH' {$IFDEF FPDBG_DWARF_SEARCH} , True {$ENDIF} );
  FPDBG_DWARF_DATA_WARNINGS := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_DATA_WARNINGS' {$IFDEF FPDBG_DWARF_DATA_WARNINGS} , True {$ENDIF} );

  ThisNameInfo := NameInfoForSearch('THIS');
  SelfNameInfo := NameInfoForSearch('$SELF');

end.


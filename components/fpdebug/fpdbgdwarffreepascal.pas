unit FpDbgDwarfFreePascal;

{$mode objfpc}{$H+}
{$TYPEDADDRESS on}

interface

uses
  Classes, SysUtils, Types, math,
  FpDbgDwarfDataClasses, FpDbgDwarf, FpDbgInfo,
  FpDbgUtil, FpDbgDwarfConst, FpErrorMessages, FpdMemoryTools,
  DbgIntfBaseTypes,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazStringUtils;

type

  {%Region * ***** SymbolClassMap ***** *}

  { TFpDwarfFreePascalSymbolClassMap }

  TFpDwarfFreePascalSymbolClassMap = class(TFpDwarfDefaultSymbolClassMap)
  strict private
    class var ExistingClassMap: TFpSymbolDwarfClassMap;
  private
    FCompilerVersion: Cardinal;
  protected
    function CanHandleCompUnit(ACU: TDwarfCompilationUnit; AHelperData: Pointer): Boolean; override;
    class function GetExistingClassMap: PFpDwarfSymbolClassMap; override;
  public
    class function GetInstanceForCompUnit(ACU: TDwarfCompilationUnit): TFpSymbolDwarfClassMap; override;
    class function ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;

    class function GetInstanceForDbgInfo(ADbgInfo: TDbgInfo):TFpDwarfFreePascalSymbolClassMap;
  public
    constructor Create(ACU: TDwarfCompilationUnit; AHelperData: Pointer); override;
    function GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass; override;
    function CreateScopeForSymbol(ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol;
      ADwarf: TFpDwarfInfo): TFpDbgSymbolScope; override;
    //class function CreateProcSymbol(ACompilationUnit: TDwarfCompilationUnit;
    //  AInfo: PDwarfAddressInfo; AAddress: TDbgPtr): TDbgDwarfSymbolBase; override;

    function GetInstanceClassNameFromPVmt(APVmt: TDbgPtr;
      AContext: TFpDbgLocationContext; ASizeOfAddr: Integer;
      out AClassName: String; out AnError: TFpError): boolean;
  end;

  { TFpDwarfFreePascalSymbolClassMapDwarf2 }

  TFpDwarfFreePascalSymbolClassMapDwarf2 = class(TFpDwarfFreePascalSymbolClassMap)
  strict private
    class var ExistingClassMap: TFpSymbolDwarfClassMap;
  protected
    class function GetExistingClassMap: PFpDwarfSymbolClassMap; override;
  public
    class function ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;
  public
    function GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass; override;
    //class function CreateSymbolScope(AThreadId, AStackFrame: Integer; AnAddress: TDBGPtr; ASymbol: TFpSymbol;
    //  ADwarf: TFpDwarfInfo): TFpDbgSymbolScope; override;
    //class function CreateProcSymbol(ACompilationUnit: TDwarfCompilationUnit;
    //  AInfo: PDwarfAddressInfo; AAddress: TDbgPtr): TDbgDwarfSymbolBase; override;
  end;

  { TFpDwarfFreePascalSymbolClassMapDwarf3 }

  TFpDwarfFreePascalSymbolClassMapDwarf3 = class(TFpDwarfFreePascalSymbolClassMap)
  strict private
    class var ExistingClassMap: TFpSymbolDwarfClassMap;
  protected
    class function GetExistingClassMap: PFpDwarfSymbolClassMap; override;
  public
    class function ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean; override;
  public
    function GetDwarfSymbolClass(ATag: Cardinal): TDbgDwarfSymbolBaseClass; override;
    //class function CreateSymbolScope(AThreadId, AStackFrame: Integer; AnAddress: TDBGPtr; ASymbol: TFpSymbol;
    //  ADwarf: TFpDwarfInfo): TFpDbgSymbolScope; override;
    //class function CreateProcSymbol(ACompilationUnit: TDwarfCompilationUnit;
    //  AInfo: PDwarfAddressInfo; AAddress: TDbgPtr): TDbgDwarfSymbolBase; override;
  end;

  {%EndRegion }

  {%Region * ***** Context ***** *}

  { TFpDwarfFreePascalSymbolScope }

  TFpDwarfFreePascalSymbolScope = class(TFpDwarfInfoSymbolScope)
  private
    FOuterNestContext: TFpDbgSymbolScope;
    FOuterNotFound: Boolean;
  protected
    function FindLocalSymbol(const AName: String; const ANameInfo: TNameSearchInfo;
      InfoEntry: TDwarfInformationEntry; out ADbgValue: TFpValue): Boolean; override;
  public
    destructor Destroy; override;
  end;

  {%EndRegion }

  {%Region * ***** Value & Types ***** *}

  (* *** Class vs ^Record vs ^Object *** *)

  { TFpSymbolDwarfFreePascalTypeDeclaration }

  TFpSymbolDwarfFreePascalTypeDeclaration = class(TFpSymbolDwarfTypeDeclaration)
  protected
   // fpc encodes classes as pointer, not ref (so Obj1 = obj2 compares the pointers)
   // typedef > pointer > srtuct
   // while a pointer to class/object: pointer > typedef > ....
    function DoGetNestedTypeInfo: TFpSymbolDwarfType; override;
  end;

  { TFpSymbolDwarfFreePascalTypePointer }

  TFpSymbolDwarfFreePascalTypePointer = class(TFpSymbolDwarfTypePointer)
  private
    FIsInternalPointer: Boolean;
    function GetIsInternalPointer: Boolean; inline;
    function IsInternalDynArrayPointer: Boolean; inline;
  protected
    procedure TypeInfoNeeded; override;
    procedure KindNeeded; override;
    function DoReadStride(AValueObj: TFpValueDwarf; out AStride: TFpDbgValueSize): Boolean; override;
    procedure ForwardToSymbolNeeded; override;
    function GetNextTypeInfoForDataAddress(ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType; override;
    function GetDataAddressNext(AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation;
      out ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean; override;
    function DoReadDataSize(const AValueObj: TFpValue; out ADataSize: TFpDbgValueSize): Boolean; override;
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
    property IsInternalPointer: Boolean read GetIsInternalPointer write FIsInternalPointer; // Class (also DynArray, but DynArray is handled without this)
  end;

  { TFpSymbolDwarfFreePascalTypeStructure }

  TFpSymbolDwarfFreePascalTypeStructure = class(TFpSymbolDwarfTypeStructure)
  protected
    procedure KindNeeded; override;
    //function GetInstanceClass(AValueObj: TFpValueDwarf): TFpSymbolDwarf; override;
    class function GetInstanceClassNameFromPVmt(APVmt: TDbgPtr;
      AContext: TFpDbgLocationContext; ASizeOfAddr: Integer;
      out AClassName: String; out AnError: TFpError): boolean;
  public
    function GetInstanceClassName(AValueObj: TFpValue; out
      AClassName: String): boolean; override;
  end;

  (* *** Record vs ShortString *** *)

  { TFpSymbolDwarfV2FreePascalTypeStructure }

  TFpSymbolDwarfV2FreePascalTypeStructure = class(TFpSymbolDwarfFreePascalTypeStructure)
  private
    FIsShortString: (issUnknown, issShortString, issStructure);
    function IsShortString: Boolean;
  protected
    procedure KindNeeded; override;
    function GetNestedSymbolCount: Integer; override;
    //function GetNestedSymbolByName(AIndex: String): TFpSymbol; override;
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpValueDwarfV2FreePascalShortString }

  TFpValueDwarfV2FreePascalShortString = class(TFpValueDwarf)
  protected
    function IsValidTypeCast: Boolean; override;
    function GetInternMemberByName(const AIndex: String): TFpValue;
    procedure Reset; override;
  private
    FValue: String;
    FValueDone: Boolean;
  protected
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsString: AnsiString; override;
    function GetAsWideString: WideString; override;
  end;

  (* *** "Open Array" in params *** *)

  { TFpSymbolDwarfFreePascalSymbolTypeArray }

  TFpSymbolDwarfFreePascalSymbolTypeArray = class(TFpSymbolDwarfTypeArray)
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpValueDwarfFreePascalArray }

  TFpValueDwarfFreePascalArray = class(TFpValueDwarfArray)
  protected
    function GetKind: TDbgSymbolKind; override;
    function GetMemberCount: Integer; override;
    function DoGetStride(out AStride: TFpDbgValueSize): Boolean; override;
    function DoGetMainStride(out AStride: TFpDbgValueSize): Boolean; override;
    function DoGetDimStride(AnIndex: integer; out AStride: TFpDbgValueSize): Boolean; override;
  end;

  (* *** Array vs AnsiString *** *)

  { TFpSymbolDwarfV3FreePascalSymbolTypeArray }

  TFpSymbolDwarfV3FreePascalSymbolTypeArray = class(TFpSymbolDwarfFreePascalSymbolTypeArray)
  private type
    TArrayOrStringType = (iasUnknown, iasArray, iasShortString, iasAnsiString, iasUnicodeString);
  private
    FArrayOrStringType: TArrayOrStringType;
    function GetInternalStringType: TArrayOrStringType;
  protected
    procedure KindNeeded; override;
    function DoReadSize(const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean; override;
  public
    function GetTypedValueObject(ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType = nil): TFpValueDwarf; override;
  end;

  { TFpValueDwarfV3FreePascalString }

  TFpValueDwarfV3FreePascalString = class(TFpValueDwarf) // short & ansi...
  private
    FValue: String;
    FValueDone: Boolean;
    function GetDynamicCodePage(Addr: TFpDbgMemLocation; out Codepage: TSystemCodePage): Boolean;
  protected
    function IsValidTypeCast: Boolean; override;
    procedure Reset; override;
    function GetFieldFlags: TFpValueFieldFlags; override;
    function GetAsString: AnsiString; override;
    function GetAsWideString: WideString; override;
  end;

  {%EndRegion }

implementation

uses
  FpDbgCommon;

var
  FPDBG_DWARF_VERBOSE: PLazLoggerLogGroup;

{ TFpDwarfFreePascalSymbolClassMap }

function TFpDwarfFreePascalSymbolClassMap.CanHandleCompUnit(
  ACU: TDwarfCompilationUnit; AHelperData: Pointer): Boolean;
begin
  Result := (FCompilerVersion = PtrUInt(AHelperData)) and
            inherited CanHandleCompUnit(ACU, AHelperData);
end;

class function TFpDwarfFreePascalSymbolClassMap.GetExistingClassMap: PFpDwarfSymbolClassMap;
begin
  Result := @ExistingClassMap;
end;

class function TFpDwarfFreePascalSymbolClassMap.GetInstanceForCompUnit(
  ACU: TDwarfCompilationUnit): TFpSymbolDwarfClassMap;
var
  s: String;
  i, j, AVersion: Integer;
begin
  AVersion := 0;
  s := ACU.Producer+' ';
  i := PosI('free pascal', s) + 11;

  if i > 11 then begin
    while (i < Length(s)) and (s[i] in [' ', #9]) do
      inc(i);
    delete(s, 1, i - 1);
    i := pos('.', s);
    if (i > 1) then begin
      j := StrToIntDef(copy(s, 1, i - 1), 0);
      if (j >= 0) then
        AVersion := j * $10000;
      delete(s, 1, i);
    end;
    if (AVersion > 0) then begin
      i := pos('.', s);
      if (i > 1) then begin
        j := StrToIntDef(copy(s, 1, i - 1), 0);
        if (j >= 0) and (j < 99) then
          AVersion := AVersion + j * $100
        else
          AVersion := 0;
        delete(s, 1, i);
      end;
    end;
    if (AVersion > 0) then begin
      i := pos(' ', s);
      if (i > 1) then begin
        j := StrToIntDef(copy(s, 1, i - 1), 0);
        if (j >= 0) and (j < 99) then
          AVersion := AVersion + j
        else
          AVersion := 0;
      end;
    end;
  end;

  Result := DoGetInstanceForCompUnit(ACU, Pointer(PtrUInt(AVersion)));
end;

class function TFpDwarfFreePascalSymbolClassMap.ClassCanHandleCompUnit(ACU: TDwarfCompilationUnit): Boolean;
begin
  Result := PosI('free pascal', ACU.Producer) > 0;
end;

var
  LastInfo: TDbgInfo = nil;
  FoundMap: TFpDwarfFreePascalSymbolClassMap = nil;

class function TFpDwarfFreePascalSymbolClassMap.GetInstanceForDbgInfo(
  ADbgInfo: TDbgInfo): TFpDwarfFreePascalSymbolClassMap;
var
  i: Integer;
begin
  if ADbgInfo <> LastInfo then begin
    FoundMap := nil;
    LastInfo := nil;
  end;

  Result := FoundMap;
  if LastInfo <> nil then
    exit;

  if not (ADbgInfo is TFpDwarfInfo) then
    exit;

  for i := 0 to TFpDwarfInfo(ADbgInfo).CompilationUnitsCount - 1 do
    if TFpDwarfInfo(ADbgInfo).CompilationUnits[i].DwarfSymbolClassMap is TFpDwarfFreePascalSymbolClassMap
    then begin
      FoundMap := TFpDwarfFreePascalSymbolClassMap(TFpDwarfInfo(ADbgInfo).CompilationUnits[i].DwarfSymbolClassMap);
    end;

  Result := FoundMap;
  LastInfo := ADbgInfo;
end;

constructor TFpDwarfFreePascalSymbolClassMap.Create(ACU: TDwarfCompilationUnit;
  AHelperData: Pointer);
begin
  FCompilerVersion := PtrUInt(AHelperData);
  inherited Create(ACU, AHelperData);
end;

function TFpDwarfFreePascalSymbolClassMap.GetDwarfSymbolClass(
  ATag: Cardinal): TDbgDwarfSymbolBaseClass;
begin
  case ATag of
    DW_TAG_typedef:          Result := TFpSymbolDwarfFreePascalTypeDeclaration;
    DW_TAG_pointer_type:     Result := TFpSymbolDwarfFreePascalTypePointer;
    DW_TAG_structure_type,
    DW_TAG_class_type:       Result := TFpSymbolDwarfFreePascalTypeStructure;
    DW_TAG_array_type:       Result := TFpSymbolDwarfFreePascalSymbolTypeArray;
    else                     Result := inherited GetDwarfSymbolClass(ATag);
  end;
end;

function TFpDwarfFreePascalSymbolClassMap.CreateScopeForSymbol(
  ALocationContext: TFpDbgLocationContext; ASymbol: TFpSymbol;
  ADwarf: TFpDwarfInfo): TFpDbgSymbolScope;
begin
  Result := TFpDwarfFreePascalSymbolScope.Create(ALocationContext, ASymbol, ADwarf);
end;

function TFpDwarfFreePascalSymbolClassMap.GetInstanceClassNameFromPVmt(
  APVmt: TDbgPtr; AContext: TFpDbgLocationContext; ASizeOfAddr: Integer; out
  AClassName: String; out AnError: TFpError): boolean;
begin
  Result := TFpSymbolDwarfFreePascalTypeStructure.GetInstanceClassNameFromPVmt(APVmt,
    AContext, ASizeOfAddr, AClassName, AnError);
end;

{ TFpDwarfFreePascalSymbolClassMapDwarf2 }

class function TFpDwarfFreePascalSymbolClassMapDwarf2.GetExistingClassMap: PFpDwarfSymbolClassMap;
begin
  Result := @ExistingClassMap;
end;

class function TFpDwarfFreePascalSymbolClassMapDwarf2.ClassCanHandleCompUnit(
  ACU: TDwarfCompilationUnit): Boolean;
begin
  Result := inherited ClassCanHandleCompUnit(ACU);
  Result := Result and (ACU.Version < 3);
end;

function TFpDwarfFreePascalSymbolClassMapDwarf2.GetDwarfSymbolClass(
  ATag: Cardinal): TDbgDwarfSymbolBaseClass;
begin
  case ATag of
    DW_TAG_structure_type:
      Result := TFpSymbolDwarfV2FreePascalTypeStructure; // maybe record
  //  // TODO:
  //  //DW_TAG_reference_type:   Result := TFpSymbolDwarfTypeRef;
  //  //DW_TAG_typedef:          Result := TFpSymbolDwarfTypeDeclaration;
  //  //DW_TAG_pointer_type:     Result := TFpSymbolDwarfTypePointer;
  //  //
  //  //DW_TAG_base_type:        Result := TFpSymbolDwarfTypeBasic;
  //  //DW_TAG_subrange_type:    Result := TFpSymbolDwarfTypeSubRange;
  //  //DW_TAG_enumeration_type: Result := TFpSymbolDwarfTypeEnum;
  //  //DW_TAG_enumerator:       Result := TFpSymbolDwarfDataEnumMember;
  //  //DW_TAG_array_type:       Result := TFpSymbolDwarfTypeArray;
  //  ////
  //  //DW_TAG_compile_unit:     Result := TFpSymbolDwarfUnit;
  //
    else
      Result := inherited GetDwarfSymbolClass(ATag);
  end;
end;

{ TFpDwarfFreePascalSymbolClassMapDwarf3 }

class function TFpDwarfFreePascalSymbolClassMapDwarf3.GetExistingClassMap: PFpDwarfSymbolClassMap;
begin
  Result := @ExistingClassMap;
end;

class function TFpDwarfFreePascalSymbolClassMapDwarf3.ClassCanHandleCompUnit(
  ACU: TDwarfCompilationUnit): Boolean;
begin
  Result := inherited ClassCanHandleCompUnit(ACU);
  Result := Result and (ACU.Version >= 3);
end;

function TFpDwarfFreePascalSymbolClassMapDwarf3.GetDwarfSymbolClass(
  ATag: Cardinal): TDbgDwarfSymbolBaseClass;
begin
  case ATag of
    DW_TAG_array_type:
      Result := TFpSymbolDwarfV3FreePascalSymbolTypeArray;
  //  DW_TAG_structure_type:
  //    Result := TFpSymbolDwarfV2FreePascalTypeStructure; // maybe record
  //  // TODO:
  //  //DW_TAG_reference_type:   Result := TFpSymbolDwarfTypeRef;
  //  //DW_TAG_typedef:          Result := TFpSymbolDwarfTypeDeclaration;
  //  //DW_TAG_pointer_type:     Result := TFpSymbolDwarfTypePointer;
  //  //
  //  //DW_TAG_base_type:        Result := TFpSymbolDwarfTypeBasic;
  //  //DW_TAG_subrange_type:    Result := TFpSymbolDwarfTypeSubRange;
  //  //DW_TAG_enumeration_type: Result := TFpSymbolDwarfTypeEnum;
  //  //DW_TAG_enumerator:       Result := TFpSymbolDwarfDataEnumMember;
  //  //DW_TAG_array_type:       Result := TFpSymbolDwarfTypeArray;
  //  ////
  //  //DW_TAG_compile_unit:     Result := TFpSymbolDwarfUnit;
  //
    else
      Result := inherited GetDwarfSymbolClass(ATag);
  end;
end;

type

  { TFpDbgDwarfSimpleLocationContext }

  TFpDbgDwarfSimpleLocationContext = class(TFpDbgSimpleLocationContext)
  protected
    FStackFrame: Integer;
    function GetStackFrame: Integer; override;
  public
    constructor Create(AMemManager: TFpDbgMemManager; AnAddress: TDbgPtr;
      AnSizeOfAddr, AThreadId: Integer; AStackFrame: Integer);
  end;

{ TFpDbgDwarfSimpleLocationContext }

constructor TFpDbgDwarfSimpleLocationContext.Create(
  AMemManager: TFpDbgMemManager; AnAddress: TDbgPtr; AnSizeOfAddr,
  AThreadId: Integer; AStackFrame: Integer);
begin
  inherited Create(AMemManager, AnAddress, AnSizeOfAddr, AThreadId, AStackFrame);
  FStackFrame := AStackFrame;
end;

function TFpDbgDwarfSimpleLocationContext.GetStackFrame: Integer;
begin
  Result := FStackFrame;
end;

{ TFpDwarfFreePascalSymbolScope }

var
  ParentFpLowerNameInfo, ParentFp2LowerNameInfo: TNameSearchInfo; // case sensitive
function TFpDwarfFreePascalSymbolScope.FindLocalSymbol(const AName: String;
  const ANameInfo: TNameSearchInfo; InfoEntry: TDwarfInformationEntry; out
  ADbgValue: TFpValue): Boolean;
const
  selfname = 'self';
  // TODO: get reg num via memreader name-to-num
  RegFp64 = 6;
  RegPc64 = 16;
  RegFp32 = 5;
  RegPc32 = 8;
var
  StartScopeIdx, RegFp, RegPc: Integer;
  ParentFpVal: TFpValue;
  SearchCtx: TFpDbgDwarfSimpleLocationContext;
  par_fp, cur_fp, prev_fp, pc: TDbgPtr;
  d, i: Integer;
  ParentFpSym: TFpSymbolDwarf;
  Ctx: TFpDbgSimpleLocationContext;
begin
  Result := False;
  if not(Symbol is TFpSymbolDwarfDataProc) then
    exit;

  if Dwarf.TargetInfo.bitness = b64 then begin
    RegFP := RegFp64;
    RegPc := RegPc64;
  end
  else begin
    RegFP := RegFp32;
    RegPc := RegPc32;
  end;
  if (Length(AName) = length(selfname)) and (CompareUtf8BothCase(PChar(ANameInfo.NameUpper), PChar(ANameInfo.NameLower), @selfname[1])) then begin
    ADbgValue := GetSelfParameter;
    if ADbgValue <> nil then begin
      ADbgValue.AddReference;
      Result := True;
      exit;
    end;
  end;

  StartScopeIdx := InfoEntry.ScopeIndex;
  Result := inherited FindLocalSymbol(AName, ANameInfo, InfoEntry, ADbgValue);
  if Result then
    exit;

  if FOuterNotFound then
    exit;

  if FOuterNestContext <> nil then begin
    ADbgValue := FOuterNestContext.FindSymbol(AName); // TODO: pass upper/lower
    Result := True; // self, global was done by outer
    exit;
  end;


  InfoEntry.ScopeIndex := StartScopeIdx;
  if not InfoEntry.GoNamedChildEx(ParentFpLowerNameInfo) then begin
    InfoEntry.ScopeIndex := StartScopeIdx;
    if not InfoEntry.GoNamedChildEx(ParentFp2LowerNameInfo) then begin
      FOuterNotFound := True;
      exit;
    end;
  end;

  ParentFpSym := TFpSymbolDwarf.CreateSubClass(AName, InfoEntry);
  ParentFpVal := ParentFpSym.Value;
  if ParentFpVal = nil then begin
    Result := False;
    exit;
  end;
  ApplyContext(ParentFpVal);
  if not (svfOrdinal in ParentFpVal.FieldFlags) then begin
    DebugLn(FPDBG_DWARF_VERBOSE, 'no ordinal for parentfp');
    ParentFpSym.ReleaseReference;
    ParentFpVal.ReleaseReference;
    FOuterNotFound := True;
    exit;
  end;

  par_fp := ParentFpVal.AsCardinal;
  ParentFpVal.ReleaseReference;
  ParentFpSym.ReleaseReference;
  if par_fp = 0 then begin
    DebugLn(FPDBG_DWARF_VERBOSE, 'no ordinal for parentfp');
    FOuterNotFound := True;
    exit;
  end;

  // TODO: FindCallStackEntryByBasePointer, once all evaluates run in thread.
  i := LocationContext.StackFrame + 1;
  SearchCtx := TFpDbgDwarfSimpleLocationContext.Create(MemManager, 0, SizeOfAddress, LocationContext.ThreadId, i);

  cur_fp := 0;
  if LocationContext.ReadRegister(RegFp, cur_fp) then begin
    if cur_fp > par_fp then
      d := -1  // cur_fp must go down
    else
      d := 1;  // cur_fp must go up
    while not (cur_fp = par_fp) do begin
      SearchCtx.FStackFrame := i;
      // TODO: get reg num via memreader name-to-num
      prev_fp := cur_fp;
      if not SearchCtx.ReadRegister(RegFp, cur_fp) then
        break;
      inc(i);
      if (cur_fp = prev_fp) or ((cur_fp < prev_fp) xor (d = -1)) then
        break;  // wrong direction
      if i > LocationContext.StackFrame + 200 then break; // something wrong? // TODO better check
    end;
    dec(i);
  end;

  if (par_fp <> cur_fp) or (cur_fp = 0) or
     (i <= 0) or
     not SearchCtx.ReadRegister(RegPc, pc)
  then begin
    FOuterNotFound := True;
    SearchCtx.ReleaseReference;
    exit;
  end;

  SearchCtx.ReleaseReference;

  Ctx := TFpDbgSimpleLocationContext.Create(MemManager, pc, SizeOfAddress, LocationContext.ThreadId, i);
  FOuterNestContext := Dwarf.FindSymbolScope(Ctx, pc);
  Ctx.ReleaseReference;

  ADbgValue := FOuterNestContext.FindSymbol(AName); // TODO: pass upper/lower
  Result := True; // self, global was done by outer
end;

destructor TFpDwarfFreePascalSymbolScope.Destroy;
begin
  FOuterNestContext.ReleaseReference;
  inherited Destroy;
end;

{ TFpSymbolDwarfV2FreePascalTypeStructure }

function TFpSymbolDwarfV2FreePascalTypeStructure.IsShortString: Boolean;
var
  LenSym, StSym, StSymType: TFpSymbol;
begin
  if FIsShortString <> issUnknown then
    exit(FIsShortString = issShortString);

  Result := False;
  FIsShortString := issStructure;
  if (inherited NestedSymbolCount <> 2) then
    exit;

  if (Name <> 'ShortString') and (Name <> 'LongString') then  // DWARF-2 => user types are all caps
    exit;

  LenSym := inherited NestedSymbolByName['length'];
  if (LenSym = nil) or (LenSym.Kind <> skCardinal) // or (LenSym.Size <> 1) // not implemented yet
  then
    exit;

  StSym := inherited NestedSymbolByName['st'];
  if (StSym = nil) then
    exit;
  StSymType := StSym.TypeInfo;
  if (StSymType = nil) or (StSymType.Kind <> skArray) or not (StSymType is TFpSymbolDwarfTypeArray) then
    exit;

  FIsShortString := issShortString;
  Result := True;
end;

function TFpSymbolDwarfV2FreePascalTypeStructure.GetTypedValueObject(
  ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  if not IsShortString then
    Result := inherited GetTypedValueObject(ATypeCast, AnOuterType)
  else
    Result := TFpValueDwarfV2FreePascalShortString.Create(AnOuterType);
end;

procedure TFpSymbolDwarfV2FreePascalTypeStructure.KindNeeded;
begin
  if not IsShortString then
    inherited KindNeeded
  else
    SetKind(skString);
end;

function TFpSymbolDwarfV2FreePascalTypeStructure.GetNestedSymbolCount: Integer;
begin
  if IsShortString then
    Result := 0
  else
    Result := inherited GetNestedSymbolCount;
end;

{ TFpSymbolDwarfFreePascalTypeDeclaration }

function TFpSymbolDwarfFreePascalTypeDeclaration.DoGetNestedTypeInfo: TFpSymbolDwarfType;
var
  ti: TFpSymbolDwarfType;
begin
  Result := inherited DoGetNestedTypeInfo;

  // Is internal class pointer?
  // Do not trigged any cached property of the pointer
  if (Result = nil) or
     not (Result is TFpSymbolDwarfFreePascalTypePointer)
  then
    exit;

  ti := TFpSymbolDwarfFreePascalTypePointer(Result).NestedTypeInfo;
  // only if it is NOT a declaration
  if ti is TFpSymbolDwarfTypeStructure then
    TFpSymbolDwarfFreePascalTypePointer(Result).IsInternalPointer := True;
end;

{ TFpSymbolDwarfFreePascalTypePointer }

function TFpSymbolDwarfFreePascalTypePointer.GetIsInternalPointer: Boolean;
begin
  Result := FIsInternalPointer or IsInternalDynArrayPointer;
end;

function TFpSymbolDwarfFreePascalTypePointer.IsInternalDynArrayPointer: Boolean;
var
  ti: TFpSymbol;
begin
  Result := False;
  ti := NestedTypeInfo;  // Same as TypeInfo, but does not try to be forwarded
  Result := ti is TFpSymbolDwarfTypeArray;
  if Result then
    Result := (sfDynArray in ti.Flags);
end;

procedure TFpSymbolDwarfFreePascalTypePointer.TypeInfoNeeded;
var
  p: TFpSymbol;
begin
  p := NestedTypeInfo;
  if IsInternalPointer and (p <> nil) then
    p := p.TypeInfo;
  SetTypeInfo(p);
end;

procedure TFpSymbolDwarfFreePascalTypePointer.KindNeeded;
var
  k: TDbgSymbolKind;
begin
  if IsInternalPointer then begin
      k := NestedTypeInfo.Kind;
      if k in [skObject, skRecord] then   // TODO
        SetKind(skInterface)
      else
        SetKind(k);
  end
  else
    inherited;
end;

function TFpSymbolDwarfFreePascalTypePointer.DoReadStride(
  AValueObj: TFpValueDwarf; out AStride: TFpDbgValueSize): Boolean;
begin
  if IsInternalPointer then
    Result := NestedTypeInfo.ReadStride(AValueObj, AStride)
  else
    Result := inherited DoReadStride(AValueObj, AStride);
end;

procedure TFpSymbolDwarfFreePascalTypePointer.ForwardToSymbolNeeded;
begin
  if IsInternalPointer then
    SetForwardToSymbol(NestedTypeInfo) // Same as TypeInfo, but does not try to be forwarded
  else
    SetForwardToSymbol(nil); // inherited ForwardToSymbolNeeded;
end;

function TFpSymbolDwarfFreePascalTypePointer.GetNextTypeInfoForDataAddress(
  ATargetType: TFpSymbolDwarfType): TFpSymbolDwarfType;
begin
  if IsInternalPointer then
    Result := NestedTypeInfo
  else
    Result := inherited;
end;

function TFpSymbolDwarfFreePascalTypePointer.GetDataAddressNext(
  AValueObj: TFpValueDwarf; var AnAddress: TFpDbgMemLocation; out
  ADoneWork: Boolean; ATargetType: TFpSymbolDwarfType): Boolean;
begin
  if (not IsInternalPointer) and (ATargetType = nil) then exit(True);

  Result := inherited GetDataAddressNext(AValueObj, AnAddress, ADoneWork, ATargetType);
  if (not Result) or ADoneWork then
    exit;

  Result := AValueObj.MemManager <> nil;
  if not Result then
    exit;
  AnAddress := AValueObj.Context.ReadAddress(AnAddress, SizeVal(CompilationUnit.AddressSize));
  Result := IsValidLoc(AnAddress);

  if (not Result) and
     IsError(AValueObj.Context.LastMemError)
  then
    SetLastError(AValueObj, AValueObj.Context.LastMemError);
end;

function TFpSymbolDwarfFreePascalTypePointer.GetTypedValueObject(
  ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  if IsInternalPointer then
    Result := NestedTypeInfo.GetTypedValueObject(ATypeCast, AnOuterType)
  else
    Result := inherited GetTypedValueObject(ATypeCast, AnOuterType);
end;

function TFpSymbolDwarfFreePascalTypePointer.DoReadDataSize(
  const AValueObj: TFpValue; out ADataSize: TFpDbgValueSize): Boolean;
begin
  if Kind = skClass then begin
    // TODO: get/adjust a value object to have the deref address // see ConstRefOrExprFromAttrData
    Result := NestedTypeInfo.ReadSize(AValueObj, ADataSize);
    if not Result then
      ADataSize := ZeroSize;
  end
  else
    Result := inherited DoReadDataSize(AValueObj, ADataSize);
end;

{ TFpSymbolDwarfFreePascalTypeStructure }

procedure TFpSymbolDwarfFreePascalTypeStructure.KindNeeded;
var
  t: TDbgSymbolKind;
begin
  (* DW_TAG_structure_type
     - Is either objec or record.
     - Except: fpc < 3.0 => can be class or interface too
     DW_TAG_class_type
     - Is either class, interface, or object (object only with virtual methods)

     tested up to fpc 3.2 beta
  *)
  if (InformationEntry.AbbrevTag = DW_TAG_interface_type) then begin
    SetKind(skInterface);
  end
  else
  if TypeInfo <> nil then begin // inheritance
    t := TypeInfo.Kind;
    if t = skRecord then
      t := skObject; // could be skInterface
    SetKind(t); // skClass, skInterface or skObject
  end
  else
  begin
    if NestedSymbolByName['_vptr$TOBJECT'] <> nil then
      SetKind(skClass)
    else
    if NestedSymbolByName['_vptr$'+Name] <> nil then // vptr is only present for skObject with virtual methods/Constructor
      SetKind(skObject)
    else
    if (InformationEntry.AbbrevTag = DW_TAG_class_type) then
      SetKind(skObject)   // could be skInterface  // fix in TFpSymbolDwarfFreePascalTypePointer.KindNeeded
    else
      SetKind(skRecord);  // could be skObject(?) or skInterface   // fix in TFpSymbolDwarfFreePascalTypePointer.KindNeeded
  end;
end;

function TFpSymbolDwarfFreePascalTypeStructure.GetInstanceClassName(
  AValueObj: TFpValue; out AClassName: String): boolean;
var
  AnErr: TFpError;
begin
  Result := AValueObj is TFpValueDwarf;
  if not Result then
    exit;
  Result := GetInstanceClassNameFromPVmt(LocToAddrOrNil(AValueObj.DataAddress),
    TFpValueDwarf(AValueObj).Context, TFpValueDwarf(AValueObj).Context.SizeOfAddress, AClassName, AnErr);
  if not Result then
    SetLastError(AValueObj, AnErr);
end;

class function TFpSymbolDwarfFreePascalTypeStructure.GetInstanceClassNameFromPVmt
  (APVmt: TDbgPtr; AContext: TFpDbgLocationContext; ASizeOfAddr: Integer; out
  AClassName: String; out AnError: TFpError): boolean;
var
  VmtAddr, ClassNameAddr: TFpDbgMemLocation;
  NameLen: QWord;
begin
  Result := False;
  AnError := NoError;
  AClassName := '';
  if not AContext.ReadAddress(TargetLoc(APVmt), SizeVal(ASizeOfAddr), VmtAddr) then begin
    AnError := AContext.LastMemError;
    exit;
  end;
  if not IsReadableMem(VmtAddr) then begin
    AnError := CreateError(fpErrCanNotReadMemAtAddr, [VmtAddr.Address]);
    exit;
  end;
  {$PUSH}{$Q-}
  VmtAddr.Address := VmtAddr.Address + TDBGPtr(3 * ASizeOfAddr);
  {$POP}

  if not AContext.ReadAddress(VmtAddr, SizeVal(ASizeOfAddr), ClassNameAddr) then begin
    AnError := AContext.LastMemError;
    exit;
  end;
  if not IsReadableMem(ClassNameAddr) then begin
    AnError := CreateError(fpErrCanNotReadMemAtAddr, [ClassNameAddr.Address]);
    exit;
  end;
  if not AContext.ReadUnsignedInt(ClassNameAddr, SizeVal(1), NameLen) then begin
    AnError := AContext.LastMemError;
    exit;
  end;
  if NameLen = 0 then begin
    AnError := CreateError(fpErrAnyError, ['No name found']);
    exit;
  end;
  if not AContext.MemManager.SetLength(AClassName, NameLen) then begin
    AnError := AContext.LastMemError;
    exit;
  end;

  ClassNameAddr.Address := ClassNameAddr.Address + 1;
  Result := AContext.ReadMemory(ClassNameAddr, SizeVal(NameLen), @AClassName[1]);
  if not Result then
    AnError := AContext.LastMemError;
end;

{ TFpValueDwarfV2FreePascalShortString }

function TFpValueDwarfV2FreePascalShortString.IsValidTypeCast: Boolean;
begin
  // currently only allow this / used by array access
  Result := TypeCastSourceValue is TFpValueConstAddress;
end;

function TFpValueDwarfV2FreePascalShortString.GetInternMemberByName(
  const AIndex: String): TFpValue;
begin
  if HasTypeCastInfo then begin
    Result := TypeInfo.GetNestedValueByName(AIndex);
    TFpValueDwarf(Result).StructureValue := Self;
    if (TFpValueDwarf(Result).Context = nil) then
      TFpValueDwarf(Result).Context := Context;
  end
  else
    Result := MemberByName[AIndex];
end;

procedure TFpValueDwarfV2FreePascalShortString.Reset;
begin
  inherited Reset;
  FValueDone := False;
end;

function TFpValueDwarfV2FreePascalShortString.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  Result := Result + [svfString];
end;

function TFpValueDwarfV2FreePascalShortString.GetAsString: AnsiString;
var
  len: QWord;
  Size: TFpDbgValueSize;
  LenSym, StSym: TFpValueDwarf;
begin
  if FValueDone then
    exit(FValue);

  LenSym := TFpValueDwarf(GetInternMemberByName('length'));
  assert(LenSym is TFpValueDwarf, 'LenSym is TFpValueDwarf');
  len := LenSym.AsCardinal;
  LenSym.ReleaseReference;

  if not GetSize(Size) then begin;
    SetLastError(CreateError(fpErrAnyError));
    exit('');
  end;
  if (Size < len) then begin
    SetLastError(CreateError(fpErrAnyError));
    exit('');
  end;

  if not MemManager.SetLength(Result, len) then begin
    SetLastError(MemManager.LastError);
    exit;
  end;

  StSym := TFpValueDwarf(GetInternMemberByName('st'));
  assert(StSym is TFpValueDwarf, 'StSym is TFpValueDwarf');

  if len > 0 then
    if not Context.ReadMemory(StSym.DataAddress, SizeVal(len), @Result[1]) then begin
      Result := ''; // TODO: error
      SetLastError(Context.LastMemError);
      StSym.ReleaseReference;
      exit;
    end;
  StSym.ReleaseReference;

  FValue := Result;
  FValueDone := True;
end;

function TFpValueDwarfV2FreePascalShortString.GetAsWideString: WideString;
begin
  Result := GetAsString;
end;

{ TFpSymbolDwarfFreePascalSymbolTypeArray }

function TFpSymbolDwarfFreePascalSymbolTypeArray.GetTypedValueObject(
  ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  Result := TFpValueDwarfFreePascalArray.Create(AnOuterType, Self);
end;

{ TFpValueDwarfFreePascalArray }

function TFpValueDwarfFreePascalArray.GetKind: TDbgSymbolKind;
begin
  if TypeInfo <> nil then
    Result := TypeInfo.Kind
  else
    Result := inherited GetKind;
end;

function TFpValueDwarfFreePascalArray.GetMemberCount: Integer;
var
  t, t2: TFpSymbol;
  Info: TDwarfInformationEntry;
  n: AnsiString;
  UpperBoundSym: TFpSymbolDwarf;
  val: TFpValue;
  l, h: Int64;
  Addr: TFpDbgMemLocation;
begin
  Result := 0;
  t := TypeInfo;
  if (t.Kind <> skArray) or (t.NestedSymbolCount < 1) then // IndexTypeCount;
    exit(inherited GetMemberCount);

  t2 := t.NestedSymbol[0]; // IndexType[0];
  if not (t2 is TFpSymbolDwarfTypeSubRange) then
    exit(inherited GetMemberCount);


  TFpSymbolDwarfTypeSubRange(t2).GetValueBounds(Self, l, h);
  if (l <> 0) or
     (TFpSymbolDwarfTypeSubRange(t2).LowBoundState <> rfConst) or
     (TFpSymbolDwarfTypeSubRange(t2).HighBoundState <> rfNotFound) or
     (TFpSymbolDwarfTypeSubRange(t2).CountState <> rfNotFound)
  then
    exit(inherited GetMemberCount);

  // Check for open array param
  if (t is TFpSymbolDwarfTypeArray) and
     (DbgSymbol is TFpSymbolDwarfDataParameter) // open array exists only as param
  then begin
    Info := TFpSymbolDwarfDataParameter(DbgSymbol).InformationEntry.Clone;
    Info.GoNext;
    if Info.HasValidScope and
       Info.HasAttrib(DW_AT_location) and  // the high param must have a location / cannot be a constant
       Info.ReadName(n)
    then begin
      if (n <> '') and (n[1] = '$') then // dwarf3 // TODO: make required in dwarf3
        delete(n, 1, 1);
      if (copy(n,1,4) = 'high')
      and (CompareText(copy(n, 5, length(n)), DbgSymbol.Name) = 0) then begin
        UpperBoundSym := TFpSymbolDwarf.CreateSubClass('', Info);
        if UpperBoundSym <> nil then begin
          val := UpperBoundSym.Value;
          if val <> nil then begin
            TFpValueDwarf(val).Context := Context;
            h := Val.AsInteger;
            val.ReleaseReference;
            if (h >= 0) and (h < maxLongint) then begin
              Result := h + 1;
            end
            else
              Result := 0;
  // TODO h < -1  => Error
            Info.ReleaseReference;
            UpperBoundSym.ReleaseReference;
            exit;
          end;
        end;
      end;
    end;
    Info.ReleaseReference;
  end;

  // dynamic array
  if (sfDynArray in t.Flags) and (AsCardinal <> 0) and GetDwarfDataAddress(Addr) then begin
    if not (IsReadableMem(Addr) and (LocToAddr(Addr) > AddressSize)) then
      exit(0); // dyn array, but bad data
    Addr.Address := Addr.Address - AddressSize;
    if Context.ReadSignedInt(Addr, SizeVal(AddressSize), h) then begin
// TODO h < -1  => Error
      if (h >= 0) and (h < maxLongint) then
        Result := h+1;
      exit;
    end
    else
      SetLastError(Context.LastMemError);
    Result := 0;
    exit;
  end;

  // Should not be here. There is no knowledeg how many members there are
  Result := inherited GetMemberCount;
end;

function TFpValueDwarfFreePascalArray.DoGetStride(out AStride: TFpDbgValueSize
  ): Boolean;
begin
  if (TFpDwarfFreePascalSymbolClassMap(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion >= $030300)
  then
    Result := inherited DoGetStride(AStride)
  else
    Result := TFpSymbolDwarfType(TypeInfo.NestedSymbol[0]).ReadStride(Self, AStride);
end;

function TFpValueDwarfFreePascalArray.DoGetMainStride(out
  AStride: TFpDbgValueSize): Boolean;
begin
  if (TFpDwarfFreePascalSymbolClassMap(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion >= $030300)
  then
    Result := inherited DoGetMainStride(AStride)
  else
    Result := GetMemberSize(AStride);
end;

function TFpValueDwarfFreePascalArray.DoGetDimStride(AnIndex: integer; out
  AStride: TFpDbgValueSize): Boolean;
begin
  if (TFpDwarfFreePascalSymbolClassMap(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion >= $030300)
  then
    Result := inherited DoGetDimStride(AnIndex, AStride)
  else
  begin
    Result := True;
    AStride := ZeroSize;
  end;
end;

{ TFpSymbolDwarfV3FreePascalSymbolTypeArray }

function TFpSymbolDwarfV3FreePascalSymbolTypeArray.GetInternalStringType: TArrayOrStringType;
var
  Info: TDwarfInformationEntry;
  t: Cardinal;
  t2: TFpSymbol;
  CharSize: TFpDbgValueSize;
  LocData: array of byte;
begin
  Result := FArrayOrStringType;
  if Result <> iasUnknown then
    exit;

  FArrayOrStringType := iasArray;
  Result := FArrayOrStringType;

  t2 := TypeInfo;
  if (t2 = nil) or (t2.Kind <> skChar) then
    exit;

  // TODO: check lowbound = 1 (const)

  Info := InformationEntry.FirstChild;
  if Info = nil then
    exit;

  while Info.HasValidScope do begin
    t := Info.AbbrevTag;
    if (t = DW_TAG_enumeration_type) then
      break;
    if (t = DW_TAG_subrange_type) then begin
      if Info.HasAttrib(DW_AT_byte_stride) or Info.HasAttrib(DW_AT_type) then
        break;

      // TODO: check the location parser, if it is a reference

      if InformationEntry.ReadValue(DW_AT_data_location, LocData) then begin
        if (Length(LocData) = 3) and
           (LocData[0] = $97) and
           (LocData[1] = $31) and
           (LocData[2] = $22)
        then begin
          FArrayOrStringType := iasShortString;
          break;
        end;
      end;

      if not t2.ReadSize(nil, CharSize) then
        CharSize := ZeroSize; // TODO: error
      if (CharSize.Size = 2) then
        FArrayOrStringType := iasUnicodeString
      else
        FArrayOrStringType := iasAnsiString;
      break;
    end;
    Info.GoNext;
  end;

  Info.ReleaseReference;
  Result := FArrayOrStringType;
end;

function TFpSymbolDwarfV3FreePascalSymbolTypeArray.GetTypedValueObject(
  ATypeCast: Boolean; AnOuterType: TFpSymbolDwarfType): TFpValueDwarf;
begin
  if AnOuterType = nil then
    AnOuterType := Self;
  if GetInternalStringType in [iasShortString, iasAnsiString, iasUnicodeString] then
    Result := TFpValueDwarfV3FreePascalString.Create(AnOuterType)
  else
    Result := inherited GetTypedValueObject(ATypeCast, AnOuterType);
end;

procedure TFpSymbolDwarfV3FreePascalSymbolTypeArray.KindNeeded;
begin
  case GetInternalStringType of
    iasShortString:
      SetKind(skString);
    iasAnsiString:
      SetKind(skString); // TODO skAnsiString
    iasUnicodeString:
      SetKind(skWideString);
    else
      inherited KindNeeded;
  end;
end;

function TFpSymbolDwarfV3FreePascalSymbolTypeArray.DoReadSize(
  const AValueObj: TFpValue; out ASize: TFpDbgValueSize): Boolean;
begin
  if GetInternalStringType in [iasAnsiString, iasUnicodeString] then begin
    ASize := ZeroSize;
    ASize.Size := CompilationUnit.AddressSize;
    Result := True;
  end
  else begin
    Result := inherited DoReadSize(AValueObj, ASize);
    if (not Result) and (GetInternalStringType = iasArray) then begin
      ASize := ZeroSize;
      ASize.Size := CompilationUnit.AddressSize;
      Result := True;
    end;
  end;
end;

{ TFpValueDwarfV3FreePascalString }

function TFpValueDwarfV3FreePascalString.IsValidTypeCast: Boolean;
var
  f: TFpValueFieldFlags;
begin
  Result := HasTypeCastInfo;
  If not Result then
    exit;

  assert(TypeInfo.Kind in [skString, skWideString], 'TFpValueDwarfArray.IsValidTypeCast: TypeInfo.Kind = skArray');

  f := TypeCastSourceValue.FieldFlags;
  if (f * [svfAddress, svfSize, svfSizeOfPointer] = [svfAddress]) or
     (svfOrdinal in f)
  then
    exit;

  //if sfDynArray in TypeInfo.Flags then begin
  //  // dyn array
  //  if (svfOrdinal in f)then
  //    exit;
  //  if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) and
  //     (TypeCastSourceValue.Size = TypeInfo.CompilationUnit.AddressSize)
  //  then
  //    exit;
  //  if (f * [svfAddress, svfSizeOfPointer] = [svfAddress, svfSizeOfPointer]) then
  //    exit;
  //end
  //else begin
  //  // stat array
  //  if (f * [svfAddress, svfSize] = [svfAddress, svfSize]) and
  //     (TypeCastSourceValue.Size = TypeInfo.Size)
  //  then
  //    exit;
  //end;
  Result := False;
end;

procedure TFpValueDwarfV3FreePascalString.Reset;
begin
  inherited Reset;
  FValueDone := False;
end;

function TFpValueDwarfV3FreePascalString.GetFieldFlags: TFpValueFieldFlags;
begin
  Result := inherited GetFieldFlags;
  case TypeInfo.Kind of
    skWideString: Result := Result + [svfWideString];
    else          Result := Result + [svfString];
  end;
end;

function TFpValueDwarfV3FreePascalString.GetAsString: AnsiString;
var
  t, t2: TFpSymbol;
  LowBound, HighBound, i: Int64;
  Addr, Addr2: TFpDbgMemLocation;
  WResult: WideString;
  RResult: RawByteString;
  AttrData: TDwarfAttribData;
  Codepage: TSystemCodePage;
begin
  if FValueDone then
    exit(FValue);

  // TODO: error handling
  FValue := '';
  Result := '';
  FValueDone := True;

  // get length
  t := TypeInfo;
  if t.NestedSymbolCount < 1 then // subrange type
    exit;

  t2 := t.NestedSymbol[0]; // subrange type
  if not( (t2 is TFpSymbolDwarfType) and TFpSymbolDwarfType(t2).GetValueBounds(self, LowBound, HighBound) )
  then
    exit;

  GetDwarfDataAddress(Addr);
  if (not IsValidLoc(Addr)) and (svfOrdinal in TypeCastSourceValue.FieldFlags) then
    Addr := TargetLoc(TypeCastSourceValue.AsCardinal);
  if not IsReadableLoc(Addr) then
    exit;

  assert((TypeInfo <> nil) and (TypeInfo.CompilationUnit <> nil) and (TypeInfo.CompilationUnit.DwarfSymbolClassMap is TFpDwarfFreePascalSymbolClassMapDwarf3), 'TFpValueDwarfV3FreePascalString.GetAsString: (Owner <> nil) and (Owner.CompilationUnit <> nil) and (TypeInfo.CompilationUnit.DwarfSymbolClassMap is TFpDwarfFreePascalSymbolClassMapDwarf3)');
  if (TFpDwarfFreePascalSymbolClassMapDwarf3(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion > 0) and
     (TFpDwarfFreePascalSymbolClassMapDwarf3(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion < $030100)
  then begin
    if t.Kind = skWideString then begin
      if (t2 is TFpSymbolDwarfTypeSubRange) and (LowBound = 1) then begin
        if (TFpSymbolDwarfTypeSubRange(t2).InformationEntry.GetAttribData(DW_AT_upper_bound, AttrData)) and
           (TFpSymbolDwarfTypeSubRange(t2).InformationEntry.AttribForm[AttrData.Idx] = DW_FORM_block1) and
           (IsReadableMem(Addr) and (LocToAddr(Addr) > AddressSize))
        then begin
          // fpc issue 0035359
          // read data and check for DW_OP_shr ?
          Addr2 := Addr;
          Addr2.Address := Addr2.Address - AddressSize;
          if Context.ReadSignedInt(Addr2, SizeVal(AddressSize), i) then begin
            if (i shr 1) = HighBound then
              HighBound := i;
          end
        end;
      end;
    end;
  end;

  if HighBound < LowBound then
    exit; // empty string

  if MemManager.MemLimits.MaxStringLen > 0 then begin
    {$PUSH}{$Q-}
    if QWord(HighBound - LowBound) > MemManager.MemLimits.MaxStringLen then
      HighBound := LowBound + MemManager.MemLimits.MaxStringLen;
    {$POP}
  end;

  if t.Kind = skWideString then begin
    if not MemManager.SetLength(WResult, HighBound-LowBound+1) then begin
      WResult := '';
      SetLastError(MemManager.LastError);
    end
    else
    if not Context.ReadMemory(Addr, SizeVal((HighBound-LowBound+1)*2), @WResult[1]) then begin
      WResult := '';
      SetLastError(Context.LastMemError);
    end;

    Result := WResult;
  end else
  if Addr.Address = Address.Address + 1 then begin
    // shortstring
    if not MemManager.SetLength(Result, HighBound-LowBound+1) then begin
      Result := '';
      SetLastError(MemManager.LastError);
    end
    else
    if not Context.ReadMemory(Addr, SizeVal(HighBound-LowBound+1), @Result[1]) then begin
      Result := '';
      SetLastError(Context.LastMemError);
    end;
  end
  else begin
    if not MemManager.SetLength(RResult, HighBound-LowBound+1) then begin
      Result := '';
      SetLastError(MemManager.LastError);
    end
    else
    if not Context.ReadMemory(Addr, SizeVal(HighBound-LowBound+1), @RResult[1]) then begin
      Result := '';
      SetLastError(Context.LastMemError);
    end else begin
      if GetDynamicCodePage(Addr, Codepage) then
        SetCodePage(RResult, Codepage, False);
      Result := RResult;
    end;
  end;

  FValue := Result;
end;

function TFpValueDwarfV3FreePascalString.GetAsWideString: WideString;
begin
  // todo: widestring, but currently that is encoded as PWideChar
  Result := GetAsString;
end;

function TFpValueDwarfV3FreePascalString.GetDynamicCodePage(Addr: TFpDbgMemLocation; out
  Codepage: TSystemCodePage): Boolean;
var
  CodepageOffset: SmallInt;
begin
  // Only call this function for non-empty strings!
  Result := False;
  if not IsTargetNotNil(Addr) then
    exit;

  // Only AnsiStrings in fpc 3.0.0 and higher have a dynamic codepage.
  if (TypeInfo.Kind = skString) and (TFpDwarfFreePascalSymbolClassMapDwarf3(TypeInfo.CompilationUnit.DwarfSymbolClassMap).FCompilerVersion >= $030000) then begin
    // Too bad the debug-information does not deliver this information. So we
    // use these hardcoded information, and hope that FPC does not change and
    // we never reach this point for a compilationunit that is not compiled by
    // fpc.
    CodepageOffset := AddressSize * 3;
    Addr.Address := Addr.Address - CodepageOffset;
    if Context.ReadMemory(Addr, SizeVal(2), @Codepage) then
      Result := CodePageToCodePageName(Codepage) <> '';
  end;
end;

initialization
  DwarfSymbolClassMapList.AddMap(TFpDwarfFreePascalSymbolClassMapDwarf2);
  DwarfSymbolClassMapList.AddMap(TFpDwarfFreePascalSymbolClassMapDwarf3);

  FPDBG_DWARF_VERBOSE       := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_VERBOSE' {$IFDEF FPDBG_DWARF_VERBOSE} , True {$ENDIF} );

  ParentFpLowerNameInfo := NameInfoForSearch('parentfp');
  ParentFp2LowerNameInfo := NameInfoForSearch('$parentfp');
end.


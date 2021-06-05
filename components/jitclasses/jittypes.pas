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
unit JitTypes;

{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}
{$ModeSwitch typehelpers}
{.$Inline off}
{..$DEFINE JIT_REFCNT_DEBUG}

interface

uses
  {$IFDEF JIT_REFCNT_DEBUG}
  LazLogger,
  {$ENDIF}
  Classes, SysUtils, TypInfo, fgl, JitHelper, JitRttiWriter;

type

  { JitTypeParserException }

  JitTypeParserException = class(Exception)
  private
    FErrorPos: Integer;
    FErrorToken: String;
  public
    constructor Create(APos: Integer; const AToken, msg: string);
    property ErrorPos: Integer read FErrorPos;
    property ErrorToken: String read FErrorToken;
  end;
  JitTypeParserExceptionTypeNotFound = class(JitTypeParserException)
  end;
  JitTypeParserExceptionSyntaxError = class(JitTypeParserException)
  end;

  (* TRefCountedJitReference
     By default, when TJitType and TJitCreator are destroyed, they will free the
     TypeInfo and JitClass that they provided.
     In order to be able to use this data past the creators life time, one can
     obtain a LockReference from the creator.
     The TJitType and TJitCreator can still be destroyed, but the TypeInfo and
     JitClass will be kept, until all locks have been released.
  *)

  { TRefCountedJitReference }

  TRefCountedJitReference = class
  strict private
    FRefCount: Integer;

  protected
    procedure DoRefCountZero; virtual;
    procedure DoBeforeDecRefCount; virtual;

    procedure IncRefCount; inline;
    procedure DecRefCount; inline;
  public
    constructor Create;
    destructor Destroy; override;

    procedure ReleaseLock; inline;
    property RefCount: Integer read FRefCount;
  end;

  { TRefCountedJitNestedReference }

  TRefCountedJitNestedReference = class(TRefCountedJitReference)
  protected type
    { TRefCountedJitReferenceList }

    TRefCountedJitReferenceList = class(specialize TFPGList<TRefCountedJitReference>)
    public
      procedure ClearList;
    end;
  strict private
    (* The list can contain duplicates / This way we know when this list has more that one ref to the same object *)
    FNestedReferrences: TRefCountedJitReferenceList;
  private class var
    FLastTag: QWord;
  private
    FInGetCircularRefCount,
    FOnlyHasCircularNestedRefs: ByteBool; // All refs start with a none circular ref
    FTag: QWord;
    function HasExternalCircularRefCount(ARefObj: TRefCountedJitReference;
      ATag: QWord; AnHasExternRefInCallPath: Boolean): Boolean;
    function GetCircularRefCount(ARefObj: TRefCountedJitReference; ATag: QWord;
      AnHasExternRefInCallPath: Boolean; out AnFoundExternRef: Boolean): integer;
  protected
    procedure DoRefCountZero; override;
    procedure DoBeforeDecRefCount; override;
    property NestedReferrences: TRefCountedJitReferenceList read FNestedReferrences;

    function NestedCount: integer; virtual;
    function GetNested(AnIndex: integer): TRefCountedJitReference; virtual;
    property Nested[AnIndex: integer]: TRefCountedJitReference read GetNested;
  public
    procedure AddToList(AReference: TRefCountedJitReference); overload;
    // RemoveFromList: will remove ONE entry of the given instance
    procedure RemoveFromList(AReference: TRefCountedJitReference);
    procedure ClearList; virtual;

  public
    destructor Destroy; override;
  end;

  { TFreeNotifyingObject }

  TFreeNotifyingObject = class
  private type

    { TMethodComp }

    TMethodComp = record
      m: TMethod;
      class operator = (a, b: TMethodComp): Boolean;
    end;
    TNotifyList = specialize TFPGList<TMethodComp>;
  private
    FFreeNotificationList: TNotifyList;
  public
    destructor Destroy; override;
    procedure AddFreeNotification(ANotification: TNotifyEvent);
    procedure RemoveFreeNotification(ANotification: TNotifyEvent);
  end;

  { TReferenceAbleJitClass }

  TReferenceAbleJitClass = class(TFreeNotifyingObject)
  protected
    function GetLockReferenceInc: TRefCountedJitReference; virtual; // forwarders must overwrite this method, to avoid double inc
    function GetLockReferenceObj: TRefCountedJitReference; virtual;
  public
    (* LockReference
       - returns nil, if no ref needed
       - returned referrence will have RefCount already increased
    *)
    property LockReference: TRefCountedJitReference read GetLockReferenceInc;
  end;

  { TJitClassCreatorBase }

  TJitClassCreatorBase = class(TReferenceAbleJitClass)
  protected
    FClassUnit: String;
    function GetTypeInfo: PTypeInfo; virtual; abstract;
  public
    property TypeInfo: PTypeInfo read GetTypeInfo;
    property ClassUnit: String read FClassUnit; // write SetClassUnit;
  end;

  TJitTypeLibrary = class;

  { TJitType }

  TJitType = class(TReferenceAbleJitClass)
  strict private
    FTypeLibrary: TJitTypeLibrary;
  private
    FOwnedByLibrary: Boolean;
    FTypeName: String;
    FUnitName: String;
    procedure DoTypeLibFreed(Sender: TObject);
    procedure SetTypeLibrary(AValue: TJitTypeLibrary);

  protected
    function GetTypeInfo: PTypeInfo; virtual;
    function IsConstTypeInfo: Boolean; virtual; // TypeInfo must not be freed
    function GetResolvedTypeName: String;
    property TypeLibrary: TJitTypeLibrary read FTypeLibrary write SetTypeLibrary;
  public
    constructor Create(ATypeName: String; ATypeLibrary: TJitTypeLibrary = nil);
    destructor Destroy; override;
    property TypeName: String read FTypeName;
    property ResolvedTypeName: String read GetResolvedTypeName; // un-aliased
    property TypeInfo: PTypeInfo read GetTypeInfo;
    property UnitName: String read FUnitName write FUnitName; // ignored by alias
    property OwnedByLibrary: Boolean read FOwnedByLibrary;
  end;

  { TJitDeclarationParser }

  TJitParserTkKind = (
    ptNone, ptError,
    ptIdent, ptNum, ptChar, ptEmptyString,
    ptRoundOpen, ptRoundClose, ptSquareOpen, ptSquareClose,  // brackens
    ptColon, ptComma, ptSemicolon, ptEqual, ptSymbol,
    ptDot, ptDotDot,
    kwSet, kwArray, kwOf, kwClass, kwObject, kwString, kwRecord, kwFunction, kwProcedure,
    kwProperty, kwPublished, kwPublic, kwProtected, kwPrivate,
    kwEnd,
    kwVar, kwConst, kwOut, kwConstRef,
    ptEOT);
  TJitParserTkKinds = set of TJitParserTkKind;

  PJitDeclarationParser = ^TJitDeclarationParser;
  TCheckSectionEndProc = function(AParser: PJitDeclarationParser): boolean of object;

  TJitDeclarationParser = record
  private type
    TJitDeclarationParserData = record
      FCurToken: PChar;
      FCurTokenLen: Integer;
      FCurTokenKind: TJitParserTkKind;
    end;
    TParseContext = (pcNone, pcFuncParamStart, pcOfExpexted);
  private
    FStartPos: PChar;
    FCheckSectionEndProc: TCheckSectionEndProc;
    FSavePoint: TJitDeclarationParserData;
    DAT: TJitDeclarationParserData;
    procedure SkipWhiteSpace; inline;
  public
    constructor Create(ATokenStart: PChar);
    function CurPos: Integer;
    function IsBeforeEOT: Boolean;  // Next will be IsBeforeEOT
    function IsBeforeEotOrSectionEnd: Boolean; // at IsBeforeEOT, ";" or "end"

    function Next(AContext: TParseContext = pcNone): TJitParserTkKind;
    function CurrentToken: String;
    function CurrentTokenAsNum(out IsQWord: Boolean): Int64;
    function CurrentTokenRaw: String; inline; // with escaping & for idents
    function NextToken: String; inline;

    function PeekKind(AContext: TParseContext = pcNone): TJitParserTkKind; inline;
    function PeekTokenRaw: String;
    // GetQualifiedIdent: Expands CurrentToken to full ident
    procedure GetQualifiedIdent(out APath, AnIdent: String);           // for unit.type
    procedure GetQualifiedIdent(out APath, AnIdent1, AnIdent2: String); // for unit.enumtype.member
    procedure SavePosition;
    procedure RestorePosition;
    property CurrentKind: TJitParserTkKind read DAT.FCurTokenKind;
    property CheckSectionEndProc: TCheckSectionEndProc read FCheckSectionEndProc write FCheckSectionEndProc;
  end;

  TJitTypeInfoParseFlag = (pfAllowProcName, pfAlwaysAsMethod);
  TJitTypeInfoParseFlags = set of TJitTypeInfoParseFlag;

  { TJitTypeInfo }

  TJitTypeInfo = class(TJitType)
  private type
    { TRefCountedTypeInfo }
    TRefCountedTypeInfo = class(TRefCountedJitNestedReference)
    private
      FTypeInfo: PTypeInfo;

      function IndexOf(ATypeInfo: PTypeInfo): integer;
      procedure AddToList(ATypeInfo: TJitType); overload;
      // RemoveFromList: will remove ONE entry of this
      procedure RemoveFromList(ATypeInfo: PTypeInfo);
      procedure SetTypeInfo(ATypeInfo: PTypeInfo);
    protected
      procedure DoRefCountZero; override;
      property TypeInfo: PTypeInfo read FTypeInfo;
    public
      constructor Create(ATypeInfo: PTypeInfo);
    end;

  private
    FIsConstTypeInfo: Boolean;
    FTypeInfo: PTypeInfo;                     // use Set[Const]FTypeInfo for write access => so Ref is updated too
    FRefCountedTypeInfo: TRefCountedTypeInfo; // created on request => use RefCountedTypeInfo()
    FDeclaration: String;
    FParseFlags: TJitTypeInfoParseFlags;
    FIsInParseFromDeclaration: Boolean;

    procedure SetFTypeInfo(AValue: PTypeInfo);
    procedure SetConstFTypeInfo(AValue: PTypeInfo);
    function  RefCountedTypeInfo: TRefCountedTypeInfo; inline;
  protected
    procedure ParseFromDeclaration(AParser: PJitDeclarationParser = nil);
    function  GetTypeInfo: PTypeInfo; override;
    function  GetLockReferenceObj: TRefCountedJitReference; override;
    function IsConstTypeInfo: Boolean; override;
  public
    constructor Create(ATypeName, ADeclaration, AUnitName: String;
      ATypeLibrary: TJitTypeLibrary = nil; AParseFlags: TJitTypeInfoParseFlags = []);
    constructor Create(ATypeName, ADeclaration: String;
      ATypeLibrary: TJitTypeLibrary = nil; AParseFlags: TJitTypeInfoParseFlags = []);
    constructor Create(ATypeName: String; ATypeInfo: PTypeInfo; ATypeLibrary: TJitTypeLibrary = nil);
    destructor Destroy; override;

    property Declaration: String read FDeclaration;

  end;

  { TJitTypeClass }

  TJitTypeClass = class(TJitType)
  private
    FClass: TClass;

  protected
    function GetTypeInfo: PTypeInfo; override;
  public
    constructor Create(ATypeName: String; AClass: TClass; ATypeLibrary: TJitTypeLibrary = nil);
  end;

  { TJitTypeJitClass }

  TJitTypeJitClass = class(TJitType)
  private
    FJitClassCreator: TJitClassCreatorBase;
    FOwnJitCreator: Boolean;
    procedure DoCreatorFreed(Sender: TObject);

  protected
    function GetTypeInfo: PTypeInfo; override;
    function GetLockReferenceInc: TRefCountedJitReference; override;
    function IsConstTypeInfo: Boolean; override;
  public
    constructor Create(ATypeName: String; AJitClassCreator: TJitClassCreatorBase;
      ATypeLibrary: TJitTypeLibrary = nil; ATakeOwnerShip: Boolean = False);
    destructor Destroy; override;

    property OwnJitCreator: Boolean read FOwnJitCreator write FOwnJitCreator;
  end;

  { TJitTypeAlias }

  TJitTypeAlias = class(TJitType)
  private
    FRealType: TJitType;
    FRealTypeName: String;
    FInGetRealType: Boolean;

    procedure DoRealTypeFreed(Sender: TObject);
    function GetRealType: TJitType;
  protected
    function GetTypeInfo: PTypeInfo; override;
    function GetLockReferenceInc: TRefCountedJitReference; override;
    function IsConstTypeInfo: Boolean; override;
    function GetResolvedTypeName: String;
  public
    constructor Create(ATypeName, ARealTypeName: String; ATypeLibrary: TJitTypeLibrary = nil);
    constructor Create(ATypeName: String; ARealType: TJitType; ATypeLibrary: TJitTypeLibrary = nil);
    destructor Destroy; override;
  end;


  TTypeSearchOption = (
    tsoOnlyUnit   // Search only in the given unit. Otherwise search the unit first, then all others
  );
  TTypeSearchOptions = set of TTypeSearchOption;

  { TJitTypeLibrary }

  TJitTypeLibrary = class(TFreeNotifyingObject)
  private type
    TTypeMap = specialize TFPGMap<String, TJitType>;
  procedure DoTypeFreed(Sender: TObject);
  private
    FAllowDuplicates: Boolean;
    FTypeMap: TTypeMap;
    function GetTypes(AName: String): TJitType;
    procedure SetAllowDuplicates(AValue: Boolean);
  protected
    function IndexOf(ATypeName, AnUnitName: String): Integer; overload;
  public
    constructor Create;
    destructor Destroy; override;

    function  AddType(AType: TJitType; ATakeOwnerShip: Boolean = True): TJitType;
    (* AddType:
       AddType may create an alias, if the Declaration is a single existing identifier.
       If a new TJitTypeInfo should be created regardless => use AForceNewJitTypeInfo
    *)
    function  AddType(ATypeName, ADeclaration: String; AForceNewJitTypeInfo: Boolean = False): TJitType; overload;
    function  AddType(ATypeName, ADeclaration, AUnitName: String; AForceNewJitTypeInfo: Boolean = False): TJitType; overload;
    function  AddClass(ATypeName: String; AClass: TClass): TJitType; overload;
    function  AddJitClass(ATypeName: String; AJitClassCreator: TJitClassCreatorBase; ATakeCreatorOwnerShip: Boolean = False): TJitType; overload;
    function  AddAlias(ATypeName, ARealTypeName: String): TJitType; overload;
    procedure Remove(ATypeName: String; AnUnitName: String = '');
    procedure Clear;

    function FindType(const AName: String; AnUnitName: String = ''; ASearchOptions: TTypeSearchOptions = []): TJitType;

    function FindTypeForEnumElem(const AnEnumElem: String; AnUnitName: String = ''; ASearchOptions: TTypeSearchOptions = []): TJitType;
    function FindTypeForEnumElem(const AnEnumElem: String; out AnEnumVal: Integer; AnUnitName: String = ''; ASearchOptions: TTypeSearchOptions = []): TJitType;

    property Types[AName: String]: TJitType read GetTypes; default;
    property AllowDuplicates: Boolean read FAllowDuplicates write SetAllowDuplicates;
  end;

function TypeInfoByName(ATypeName: String): PTypeInfo;
function TrimDeclaration(ADecl: String): String;

implementation

function TypeInfoByName(ATypeName: String): PTypeInfo;
begin
  case lowercase(ATypeName) of
    'byte':               Result := TypeInfo(Byte);
    'word':               Result := TypeInfo(Word);
    'longword':           Result := TypeInfo(LongWord);
    'qword':              Result := TypeInfo(QWord);
    'shortint':           Result := TypeInfo(ShortInt);
    'smallint':           Result := TypeInfo(SmallInt);
    'longint':            Result := TypeInfo(LongInt);
    'int64':              Result := TypeInfo(Int64);
    'single':             Result := TypeInfo(Single);
    'double':             Result := TypeInfo(Double);
    'real':               Result := TypeInfo(Real);
    'extended':           Result := TypeInfo(Extended);
    'boolean':            Result := TypeInfo(Boolean);
    'bytebool':           Result := TypeInfo(ByteBool);
    'wordbool':           Result := TypeInfo(WordBool);
    'longbool':           Result := TypeInfo(LongBool);
    'qwordbool':          Result := TypeInfo(QWordBool);
    'ansistring':         Result := TypeInfo(AnsiString);
    'unicodestring':      Result := TypeInfo(UnicodeString);
    'widestring':         Result := TypeInfo(WideString);
    'shortstring':        Result := TypeInfo(shortstring);
    'char':               Result := TypeInfo(Char);
    'widechar':           Result := TypeInfo(WideChar);
    'pointer':            Result := TypeInfo(pointer);
    else
      Result := nil;
  end;
end;

function TrimDeclaration(ADecl: String): String;
Const WhiteSpace = [#0..' ', ';'];
var Ofs, Len: integer;
begin
  len := Length(ADecl);
  while (Len>0) and (ADecl[Len] in WhiteSpace) do
   dec(Len);
  Ofs := 1;
  while (Ofs<=Len) and (ADecl[Ofs] in WhiteSpace) do
   Inc(Ofs);
  result := Copy(ADecl, Ofs, 1 + Len - Ofs);
end;

{ JitTypeParserException }

constructor JitTypeParserException.Create(APos: Integer; const AToken,
  msg: string);
begin
  FErrorPos := APos;
  FErrorToken := AToken;
end;

{ TRefCountedJitNestedReference.TRefCountedJitReferenceList }

procedure TRefCountedJitNestedReference.TRefCountedJitReferenceList.ClearList;
var
  i: Integer;
begin
  for i := 0 to Count - 1 do
    Items[i].ReleaseLock;
  Clear;
end;

{ TFreeNotifyingObject.TMethodComp }

class operator TFreeNotifyingObject.TMethodComp. = (a, b: TMethodComp): Boolean;
begin
  result := (a.m.Code = b.m.Code) and
            (a.m.Data = b.m.Data);
end;

{ TRefCountedJitReference }

procedure TRefCountedJitReference.DoRefCountZero;
begin
  //
end;

procedure TRefCountedJitReference.DoBeforeDecRefCount;
begin
  //
end;

constructor TRefCountedJitReference.Create;
begin
  FRefCount := 1;
end;

destructor TRefCountedJitReference.Destroy;
begin
  {$IFDEF JIT_REFCNT_DEBUG}
  debuglnEnter(['> TRefCountedJitReference.Destroy ',dbgs(self),' ' ]); try
  {$ENDIF}
  if FRefCount > 0 then raise
    exception.Create('destroy while referrenced');

  DoRefCountZero;
  inherited Destroy;
  {$IFDEF JIT_REFCNT_DEBUG}
  finally debuglnExit(['< TRefCountedJitReference.Destroy ',dbgs(self) ]); end;
  {$ENDIF}
end;

procedure TRefCountedJitReference.IncRefCount;
begin
  inc(FRefCount);
end;

procedure TRefCountedJitReference.DecRefCount;
begin
  DoBeforeDecRefCount;
  dec(FRefCount);
  if FRefCount = 0 then
    Destroy;
end;

procedure TRefCountedJitReference.ReleaseLock;
begin
  DecRefCount;
end;

{ TRefCountedJitNestedReference }

function TRefCountedJitNestedReference.HasExternalCircularRefCount(
  ARefObj: TRefCountedJitReference; ATag: QWord; AnHasExternRefInCallPath: Boolean
  ): Boolean;
var
  i: Integer;
  n: TRefCountedJitReference;
begin
  {$IFDEF JIT_REFCNT_DEBUG}
  debuglnEnter(['> HasExternalCircularRefCount ',dbgs(self),' ', RefCount ]); try
  {$ENDIF}
  // Once the caller itself has no external refs (i.e. has only circular ones),
  // the search can stop, as soon as any ONE circle with external has been found
  Result := not FOnlyHasCircularNestedRefs;
  if FInGetCircularRefCount or (NestedCount = 0) then
    exit;

  FInGetCircularRefCount := True;
  try
    for i := 0 to NestedCount - 1 do begin
      n := Nested[i];
      if (n is TRefCountedJitNestedReference) and
         (TRefCountedJitNestedReference(n).FTag <> ATag) // not yet visited
      then begin
        if n = ARefObj then begin
          Result := AnHasExternRefInCallPath;
        end
        else
        if (TRefCountedJitNestedReference(n).FTag <> ATag) then // not yet visited
        begin
          TRefCountedJitNestedReference(n).FTag := ATag;
          Result := TRefCountedJitNestedReference(n).HasExternalCircularRefCount(ARefObj, ATag,
            AnHasExternRefInCallPath or not FOnlyHasCircularNestedRefs);
        end;
        if Result then
          exit;
      end;
    end;
  finally
    FInGetCircularRefCount := False;
  end;
  {$IFDEF JIT_REFCNT_DEBUG}
  finally debuglnExit(['< TRefCountedJitNestedReference.HasExternalCircularRefCount ', Result ]); end;
  {$ENDIF}
end;

function TRefCountedJitNestedReference.GetCircularRefCount(
  ARefObj: TRefCountedJitReference; ATag: QWord;
  AnHasExternRefInCallPath: Boolean; out AnFoundExternRef: Boolean): integer;
var
  i: Integer;
  n: TRefCountedJitReference;
  ExtFound: Boolean;
begin
  {$IFDEF JIT_REFCNT_DEBUG}
  debuglnEnter(['> GetCircularRefCount ',dbgs(Self) , ' //', RefCount, ' Only:', FOnlyHasCircularNestedRefs, ' nestcnt: ', NestedCount, '  ext in path: ', AnHasExternRefInCallPath]); try
  {$ENDIF}
  Result := 0;
  AnHasExternRefInCallPath := AnHasExternRefInCallPath or not FOnlyHasCircularNestedRefs;
  AnFoundExternRef := AnHasExternRefInCallPath;

  if FInGetCircularRefCount or (NestedCount = 0) then
    exit;

  FInGetCircularRefCount := True;
  try
    for i := 0 to NestedCount - 1 do begin
      n := Nested[i];
      if (n is TRefCountedJitNestedReference) then begin
        if n = ARefObj then begin
          inc(Result);
          if AnHasExternRefInCallPath then
            AnFoundExternRef := True;
        end
        else
        if (TRefCountedJitNestedReference(n).FTag <> ATag) then // not yet visited
        begin
          TRefCountedJitNestedReference(n).FTag := ATag;
          Result := Result + TRefCountedJitNestedReference(n).GetCircularRefCount(ARefObj,
            ATag,
            AnHasExternRefInCallPath,
            ExtFound
            );
          AnFoundExternRef := AnFoundExternRef or ExtFound;
        end;
      end;
    end;
  finally
    FInGetCircularRefCount := False;
  end;
  {$IFDEF JIT_REFCNT_DEBUG}
  finally debuglnExit(['< GetCircularRefCount ', Result, ' with ext: ', AnFoundExternRef ]); end;
  {$ENDIF}
end;

procedure TRefCountedJitNestedReference.DoRefCountZero;
begin
  inherited DoRefCountZero;
  ClearList;
end;

procedure TRefCountedJitNestedReference.DoBeforeDecRefCount;
var
  ExtFound: Boolean;
begin
  {$IFDEF JIT_REFCNT_DEBUG}
  debuglnEnter(['> DoBeforeDecRefCount ',dbgs(self),' refc ', RefCount, '  Only:', FOnlyHasCircularNestedRefs, ' nestcnt: ', NestedCount , '  SKIP ',FInGetCircularRefCount]); try
  {$ENDIF}
  if (RefCount = 1) or FInGetCircularRefCount then
    exit;
  {$PUSH}{$R-}
  inc(FLastTag);
  if FLastTag = 0 then
    inc(FLastTag);
  {$POP}
  if FOnlyHasCircularNestedRefs then begin
    ExtFound := HasExternalCircularRefCount(Self, FLastTag, False);
    {$IFDEF JIT_REFCNT_DEBUG}
    DebugLn(['has ext: ', ExtFound]);
    {$ENDIF}
  end
  else
  begin
    FOnlyHasCircularNestedRefs := True; // pretend
    FOnlyHasCircularNestedRefs :=  RefCount - 1 - GetCircularRefCount(Self, FLastTag, False, ExtFound) = 0;
    {$IFDEF JIT_REFCNT_DEBUG}
    DebugLn(['Only : ', FOnlyHasCircularNestedRefs, ' has ext: ', ExtFound]);
    {$ENDIF}
  end;
  if not ExtFound then begin
    // release all refs
    FInGetCircularRefCount := True;
    ClearList;
  end;
  {$IFDEF JIT_REFCNT_DEBUG}
  finally debuglnExit(['< DoBeforeDecRefCount ', RefCount ]); end;
  {$ENDIF}
end;

function TRefCountedJitNestedReference.NestedCount: integer;
begin
  if FNestedReferrences = nil then
    Result := 0
  else
    Result := FNestedReferrences.Count;
end;

function TRefCountedJitNestedReference.GetNested(AnIndex: integer
  ): TRefCountedJitReference;
begin
  Result := FNestedReferrences[AnIndex];
end;

procedure TRefCountedJitNestedReference.AddToList(
  AReference: TRefCountedJitReference);
begin
  if AReference = nil then
    exit;
  if FNestedReferrences = nil then
    FNestedReferrences := TRefCountedJitReferenceList.Create;
  FNestedReferrences.Add(AReference);
end;

procedure TRefCountedJitNestedReference.RemoveFromList(
  AReference: TRefCountedJitReference);
begin
  if (FNestedReferrences = nil) or (AReference = nil) then
    exit;
  FNestedReferrences.Remove(AReference);
end;

procedure TRefCountedJitNestedReference.ClearList;
begin
  if FNestedReferrences = nil then
    exit;
  FNestedReferrences.ClearList;
end;

destructor TRefCountedJitNestedReference.Destroy;
begin
  inherited Destroy;
  ClearList;
  FNestedReferrences.Free;
end;

{ TFreeNotifyingObject }

destructor TFreeNotifyingObject.Destroy;
var
  i: Integer;
begin
  if FFreeNotificationList <> nil then begin
    i := FFreeNotificationList.Count - 1;
    while i >= 0 do begin
      TNotifyEvent(FFreeNotificationList[i])(Self);
      dec(i);
      if i >= FFreeNotificationList.Count then
        i := FFreeNotificationList.Count - 1;
    end;
  end;
  inherited Destroy;
  FreeAndNil(FFreeNotificationList);
end;

procedure TFreeNotifyingObject.AddFreeNotification(ANotification: TNotifyEvent);
begin
  if FFreeNotificationList = nil then
    FFreeNotificationList := TNotifyList.Create;
  FFreeNotificationList.Add(TMethodComp(ANotification));
end;

procedure TFreeNotifyingObject.RemoveFreeNotification(ANotification: TNotifyEvent);
begin
  if FFreeNotificationList = nil then
    exit;
  FFreeNotificationList.Remove(TMethodComp(ANotification));
end;

{ TReferenceAbleJitClass }

function TReferenceAbleJitClass.GetLockReferenceInc: TRefCountedJitReference;
begin
  Result := GetLockReferenceObj;
  if Result <> nil then
    Result.IncRefCount;
end;

function TReferenceAbleJitClass.GetLockReferenceObj: TRefCountedJitReference;
begin
  Result := nil;
end;

{ TJitType }

function TJitType.GetResolvedTypeName: String;
begin
  Result := TypeName;
end;

procedure TJitType.DoTypeLibFreed(Sender: TObject);
begin
  FTypeLibrary := Nil;
end;

procedure TJitType.SetTypeLibrary(AValue: TJitTypeLibrary);
begin
  if FTypeLibrary = AValue then Exit;

  if FTypeLibrary <> nil then
    FTypeLibrary.RemoveFreeNotification(@DoTypeLibFreed);

  FTypeLibrary := AValue;

  if FTypeLibrary <> nil then
    FTypeLibrary.AddFreeNotification(@DoTypeLibFreed);
end;

function TJitType.GetTypeInfo: PTypeInfo;
begin
  Result := nil;
end;

function TJitType.IsConstTypeInfo: Boolean;
begin
  Result := True;
end;

constructor TJitType.Create(ATypeName: String; ATypeLibrary: TJitTypeLibrary);
begin
  FTypeName := ATypeName;
  FTypeLibrary := ATypeLibrary;
  if FTypeLibrary <> nil then
    FTypeLibrary.AddFreeNotification(@DoTypeLibFreed);
  inherited Create;
end;

destructor TJitType.Destroy;
begin
  inherited Destroy;
  if FTypeLibrary <> nil then
    FTypeLibrary.RemoveFreeNotification(@DoTypeLibFreed);
end;

{ TJitDeclarationParser }

procedure TJitDeclarationParser.SkipWhiteSpace;
begin
  while DAT.FCurToken^ in [' ', #9, #10, #13] do
    inc(DAT.FCurToken);
end;

constructor TJitDeclarationParser.Create(ATokenStart: PChar);
begin
  FStartPos := ATokenStart;
  DAT.FCurToken := ATokenStart;
  DAT.FCurTokenLen := 0;
  FCheckSectionEndProc := nil;
  SavePosition;
  Next;
end;

function TJitDeclarationParser.CurPos: Integer;
begin
  Result := DAT.FCurToken - FStartPos;
end;

function TJitDeclarationParser.IsBeforeEOT: Boolean;
var
  t: PChar;
begin
  t := DAT.FCurToken;
  inc(DAT.FCurToken, DAT.FCurTokenLen);
  SkipWhiteSpace;
  Result := (DAT.FCurToken^ = #0);
  DAT.FCurToken := t;
end;

function TJitDeclarationParser.IsBeforeEotOrSectionEnd: Boolean;
var
  t: PChar;
begin
  t := DAT.FCurToken;
  inc(DAT.FCurToken, DAT.FCurTokenLen);
  SkipWhiteSpace;
  Result := (DAT.FCurToken^ = #0) or
            (DAT.FCurToken^ = ';') or
            ( (DAT.FCurToken[0] in ['e', 'E']) and
              (DAT.FCurToken[1] in ['n', 'N']) and
              (DAT.FCurToken[2] in ['d', 'D']) and
              (DAT.FCurToken[3] in [#0, ';', ' ', #9, #10, #13])
            );
  DAT.FCurToken := t;
  if (not Result) and Assigned(FCheckSectionEndProc) then
    Result := FCheckSectionEndProc(@Self);
end;

function TJitDeclarationParser.Next(AContext: TParseContext): TJitParserTkKind;
  type TCSet = set of char;
  var  NxtTok: PChar;
  procedure SetResult(ATokenKind: TJitParserTkKind; ALen: Integer = 1);
  begin
    DAT.FCurTokenKind := ATokenKind;
    Inc(NxtTok, ALen);
  end;
  procedure SetResultForSet(ATokenKind: TJitParserTkKind; const cs: TCSet; ASkip: Integer = 0);
  begin
    DAT.FCurTokenKind := ATokenKind;
    NxtTok := NxtTok + ASkip;
    while (NxtTok^ in cs) do
      Inc(NxtTok);
  end;
begin
  inc(DAT.FCurToken, DAT.FCurTokenLen);
  DAT.FCurTokenLen := 0;
  SkipWhiteSpace;
  if IsBeforeEOT then begin
    DAT.FCurTokenLen := 0;
    DAT.FCurTokenKind := ptEOT;
    Result := ptEOT;
    exit;
  end;

  DAT.FCurTokenKind := ptError;
  NxtTok := DAT.FCurToken;
  case DAT.FCurToken^ of
    'a'..'z', 'A'..'Z', '_': begin
      SetResultForSet(ptIdent, ['a'..'z', 'A'..'Z', '_', '0'..'9']);
      case NxtTok - DAT.FCurToken of
        2: if (AContext = pcOfExpexted) and
              (strlicomp('of', DAT.FCurToken, 2) = 0) then DAT.FCurTokenKind := kwOf;
        3: case DAT.FCurToken^ of
             's', 'S': if strlicomp('set', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwSet;
             'v', 'V': if strlicomp('var', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwVar;
             'e', 'E': if strlicomp('end', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwEnd;
           end;
        5: case DAT.FCurToken^ of
             'c', 'C': if strlicomp('const', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwConst
                       else
                       if strlicomp('class', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwClass;
             'a', 'A': if strlicomp('array', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwArray;
           end;
        6: case DAT.FCurToken^ of
             'r', 'R': if strlicomp('record', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwRecord;
             's', 'S': if strlicomp('string', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwString;
             'p', 'P': if strlicomp('public', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwPublic;
             'o', 'O': if strlicomp('object', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwObject;
           end;
        7: case DAT.FCurToken^ of
             'p', 'P': if strlicomp('private', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwPrivate;
           end;
        8: case DAT.FCurToken^ of
             'c', 'C': if (AContext = pcFuncParamStart) and
                         (strlicomp('constref', DAT.FCurToken, 3) = 0) then DAT.FCurTokenKind := kwConstRef; // not a keyword / needs contexct
             'p', 'P': if strlicomp('property', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwProperty;
             'f', 'F': if strlicomp('function', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwFunction;
           end;
        9: case DAT.FCurToken[3] of
             'c', 'C': if strlicomp('procedure', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwProcedure;
             't', 'T': if strlicomp('protected', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwProcedure;
             'l', 'L': if strlicomp('published', DAT.FCurToken, 3) = 0 then DAT.FCurTokenKind := kwPublished;
           end;
      end;
    end;
    '0'..'9': SetResultForSet(ptNum, ['0'..'9']);
    '$':      SetResultForSet(ptNum, ['0'..'9', 'a'..'f', 'A'..'F'], 1);
    '&':      if DAT.FCurToken[1] in ['0'..'7'] then
                SetResultForSet(ptNum, ['0'..'7'], 1)
              else begin
                SetResultForSet(ptIdent, ['a'..'z', 'A'..'Z', '_', '0'..'9'], 1); // escaped ident
              end;
    '%':      SetResultForSet(ptNum, ['0'..'1'], 1);
    '-','+':  case DAT.FCurToken[1] of
      '0'..'9': SetResultForSet(ptNum, ['0'..'9'], 1);
      '$':      SetResultForSet(ptNum, ['0'..'9', 'a'..'f', 'A'..'F'], 2);
      '&':      SetResultForSet(ptNum, ['0'..'7'], 2);
      '%':      SetResultForSet(ptNum, ['0'..'1'], 2);
      //else // error / return empty
    end;
    '.': if DAT.FCurToken[1] = '.' then
        SetResult(ptDotDot, 2)
      else
        SetResult(ptDot);
    '#': case DAT.FCurToken[1] of
      '0'..'9':                SetResultForSet(ptChar, ['0'..'9'], 1);
      '$':                     SetResultForSet(ptChar, ['0'..'9', 'a'..'f', 'A'..'F'], 2);
      '&':                     SetResultForSet(ptChar, ['0'..'7'], 2);
      '%':                     SetResultForSet(ptChar, ['0'..'1'], 2);
      //else // error / return empty
    end;
    '''': if (DAT.FCurToken[1] = '''') then
        SetResult(ptEmptyString, 2)
      else
      if (DAT.FCurToken[1] <> #0) and (DAT.FCurToken[2] = '''') then
        SetResult(ptChar, 3);
    '(': SetResult(ptRoundOpen);
    ')': SetResult(ptRoundClose);
    '[': SetResult(ptSquareOpen);
    ']': SetResult(ptSquareClose);
    ',': SetResult(ptComma);
    ':': SetResult(ptColon);
    ';': SetResult(ptSemicolon);
    '=': SetResult(ptEqual);
      //else // error / return empty // only chars => subset of char
    else begin
      // error
      DAT.FCurTokenKind := ptSymbol;
      inc(NxtTok);
    end;
  end;
  DAT.FCurTokenLen := NxtTok - DAT.FCurToken;
  Result := DAT.FCurTokenKind;
end;

function TJitDeclarationParser.CurrentToken: String;
var
  t: PChar;
  l: Integer;
begin
  case DAT.FCurTokenKind of
    ptNone, ptError, ptEOT: Result := '';
    ptEmptyString:          Result := '''';
    ptChar: case DAT.FCurToken^ of
      '#':  begin
        SetLength(Result, DAT.FCurTokenLen - 1);
        if DAT.FCurTokenLen > 1 then
          move((DAT.FCurToken+1)^, Result[1], DAT.FCurTokenLen - 1);
        Result := char(StrToInt(Result));
      end;
      '''': Result := (DAT.FCurToken + 1)^;
      else raise JitTypeParserExceptionSyntaxError.Create(CurPos, '', 'Internal parser error');
    end;
    else begin
      t := DAT.FCurToken;
      l := DAT.FCurTokenLen;
      if (DAT.FCurTokenKind = ptIdent) and (t^ = '&') then begin
        inc(t);
        dec(l);
      end;
      SetLength(Result, DAT.FCurTokenLen);
      if DAT.FCurTokenLen > 0 then
        move(DAT.FCurToken^, Result[1], DAT.FCurTokenLen);
    end;
  end;
end;

function TJitDeclarationParser.CurrentTokenAsNum(out IsQWord: Boolean): Int64;
var
  s: String;
begin
  if DAT.FCurTokenKind <> ptNum then
    raise JitTypeParserExceptionSyntaxError.Create(CurPos, CurrentToken, 'Number expected');

  IsQWord := False;
  s := CurrentToken;
  if not TryStrToInt64(s, Result) then
  if TryStrToQWord(s, QWord(Result)) then
    IsQWord := True
  else
    raise JitTypeParserExceptionSyntaxError.Create(CurPos, CurrentToken, 'Number expected');
end;

function TJitDeclarationParser.CurrentTokenRaw: String;
begin
  case DAT.FCurTokenKind of
    ptNone, ptError, ptEOT: Result := '';
    ptEmptyString:          Result := '''';
    else begin
      SetLength(Result, DAT.FCurTokenLen);
      if DAT.FCurTokenLen > 0 then
        move(DAT.FCurToken^, Result[1], DAT.FCurTokenLen);
    end;
  end;
end;

function TJitDeclarationParser.NextToken: String;
begin
  Next;
  Result := CurrentTokenRaw;
end;

function TJitDeclarationParser.PeekTokenRaw: String;
var
  t: TJitDeclarationParserData;
begin
  t := DAT;
  Result := NextToken;
  DAT := t;
end;

function TJitDeclarationParser.PeekKind(AContext: TParseContext
  ): TJitParserTkKind;
var
  t: TJitDeclarationParserData;
begin
  t := DAT;
  Result := Next(AContext);
  DAT := t;
end;

procedure TJitDeclarationParser.GetQualifiedIdent(out APath, AnIdent: String);
var
  ct: PChar;
begin
  APath := '';
  AnIdent := '';
  if CurrentKind <> ptIdent then
    raise JitTypeParserExceptionSyntaxError.Create(CurPos, CurrentToken, 'Identifier expected');

  ct := DAT.FCurToken;
  AnIdent := CurrentToken;
  while ((DAT.FCurToken + DAT.FCurTokenLen)^ = '.') and
        ( ((DAT.FCurToken + DAT.FCurTokenLen + 1)^ in ['a'..'z', 'A'..'Z', '_']) or
          ((DAT.FCurToken + DAT.FCurTokenLen + 1)^ = '&') and
          ((DAT.FCurToken + DAT.FCurTokenLen + 2)^ in ['a'..'z', 'A'..'Z', '_'])
        )
  do begin
    if APath <> '' then
      APath := APath + '.';
    APath := APath + AnIdent;
    Next;
    Next;
    AnIdent := CurrentToken;
  end;

  DAT.FCurTokenLen := DAT.FCurToken - ct + DAT.FCurTokenLen;
  DAT.FCurToken := ct;
end;

procedure TJitDeclarationParser.GetQualifiedIdent(out APath, AnIdent1,
  AnIdent2: String);
var
  ct: PChar;
begin
  APath := '';
  AnIdent1 := '';
  AnIdent2 := '';
  if CurrentKind <> ptIdent then
    raise JitTypeParserExceptionSyntaxError.Create(CurPos, CurrentToken, 'Identifier expected');

  ct := DAT.FCurToken;
  AnIdent2 := CurrentToken;
  while ((DAT.FCurToken + DAT.FCurTokenLen)^ = '.') and
        ( ((DAT.FCurToken + DAT.FCurTokenLen + 1)^ in ['a'..'z', 'A'..'Z', '_']) or
          ((DAT.FCurToken + DAT.FCurTokenLen + 1)^ = '&') and
          ((DAT.FCurToken + DAT.FCurTokenLen + 2)^ in ['a'..'z', 'A'..'Z', '_'])
        )
  do begin
    if (APath <> '') and (AnIdent1 <> '') then
      APath := APath + '.';
    APath := APath + AnIdent1;
    AnIdent1 := AnIdent2;
    Next;
    Next;
    AnIdent2 := CurrentToken;
  end;

  DAT.FCurTokenLen := DAT.FCurToken - ct + DAT.FCurTokenLen;
  DAT.FCurToken := ct;
end;

procedure TJitDeclarationParser.SavePosition;
begin
  FSavePoint := DAT;
end;

procedure TJitDeclarationParser.RestorePosition;
begin
  DAT := FSavePoint;
end;

{ TJitTypeInfo.TRefCountedTypeInfo }

function TJitTypeInfo.TRefCountedTypeInfo.IndexOf(ATypeInfo: PTypeInfo): integer;
begin
  if NestedReferrences = nil then
    exit;
  Result := NestedReferrences.Count - 1;
  while Result >= 0 do begin
    if (NestedReferrences[Result] is TRefCountedTypeInfo) and
       (TRefCountedTypeInfo(NestedReferrences[Result]).TypeInfo = ATypeInfo)
    then
      exit;
    dec(Result);
  end;
end;

procedure TJitTypeInfo.TRefCountedTypeInfo.AddToList(ATypeInfo: TJitType);
begin
  if ATypeInfo <> nil then
    AddToList(ATypeInfo.LockReference);
end;

procedure TJitTypeInfo.TRefCountedTypeInfo.RemoveFromList(ATypeInfo: PTypeInfo);
var
  i: Integer;
begin
  if NestedReferrences = nil then
    exit;
  i := IndexOf(ATypeInfo);
  if i < 0 then
    exit;
  NestedReferrences[i].ReleaseLock;
  NestedReferrences.Delete(i);
end;

procedure TJitTypeInfo.TRefCountedTypeInfo.SetTypeInfo(ATypeInfo: PTypeInfo);
begin
  if (RefCount > 1) and (FTypeInfo <> nil) then
    raise Exception.Create('set TypeInfo while referrenced');

  if (FTypeInfo <> nil) then begin
    ClearList;
    Freemem(FTypeInfo);
  end;

  FTypeInfo := ATypeInfo;
end;

procedure TJitTypeInfo.TRefCountedTypeInfo.DoRefCountZero;
begin
  inherited DoRefCountZero;
  if FTypeInfo <> nil then begin
    Freemem(FTypeInfo);
    FTypeInfo := nil;
  end;
end;

constructor TJitTypeInfo.TRefCountedTypeInfo.Create(ATypeInfo: PTypeInfo);
begin
  inherited Create;
  FTypeInfo := ATypeInfo;
end;

{ TJitTypeInfo }

function TJitTypeInfo.GetTypeInfo: PTypeInfo;
begin
  if FTypeInfo = nil then
    ParseFromDeclaration;
  Result := FTypeInfo;
end;

function TJitTypeInfo.GetLockReferenceObj: TRefCountedJitReference;
begin
  Result := RefCountedTypeInfo;
end;

function TJitTypeInfo.IsConstTypeInfo: Boolean;
begin
  Result := FIsConstTypeInfo;
end;

procedure TJitTypeInfo.SetFTypeInfo(AValue: PTypeInfo);
begin
  if FTypeInfo = AValue then
    Exit;
  if (FTypeInfo <> nil) and (FRefCountedTypeInfo = nil) then
    Freemem(FTypeInfo);
  FTypeInfo := AValue;
  FIsConstTypeInfo := False;
  if FRefCountedTypeInfo <> nil then begin
    if (FRefCountedTypeInfo.RefCount = 1) or (FRefCountedTypeInfo.FTypeInfo = nil) then
      FRefCountedTypeInfo.SetTypeInfo(AValue)
    else begin
      FRefCountedTypeInfo.ReleaseLock;
      FRefCountedTypeInfo := TRefCountedTypeInfo.Create(AValue);
    end;
  end;
end;

procedure TJitTypeInfo.SetConstFTypeInfo(AValue: PTypeInfo);
begin
  assert((AValue = nil) or (FTypeInfo <> AValue) or (FRefCountedTypeInfo = nil), 'TJitTypeInfo.SetConstFTypeInfo: (AValue = nil) or (FTypeInfo <> AValue) or (FRefCountedTypeInfo = nil)');
  if FTypeInfo = AValue then
    Exit;
  if (FTypeInfo <> nil) and (FRefCountedTypeInfo = nil) then
    Freemem(FTypeInfo);
  FTypeInfo := AValue;
  FIsConstTypeInfo := True;
  if FRefCountedTypeInfo <> nil then begin
    FRefCountedTypeInfo.ReleaseLock;
    FRefCountedTypeInfo := Nil;
  end;
end;

function TJitTypeInfo.RefCountedTypeInfo: TRefCountedTypeInfo;
begin
  if FRefCountedTypeInfo = nil then begin
    (* FTypeInfo may be nil, but a refernce can be got anyway *)
    if FIsConstTypeInfo then
      FRefCountedTypeInfo := TRefCountedTypeInfo.Create(nil)
    else
      FRefCountedTypeInfo := TRefCountedTypeInfo.Create(FTypeInfo);
  end;
  Result := FRefCountedTypeInfo;
end;

procedure TJitTypeInfo.ParseFromDeclaration(AParser: PJitDeclarationParser);
  var
    Decl: String;
    TheTokenParser: TJitDeclarationParser;
    TokenParser: PJitDeclarationParser;

  function IsBeforeEOT(AnIncludeSoftEOT: Boolean = False): Boolean;
  begin
    if AnIncludeSoftEOT then
      Result := TokenParser^.IsBeforeEotOrSectionEnd
    else
      Result := TokenParser^.IsBeforeEOT;
  end;

  procedure AssertIsIdent(tk: TJitParserTkKind; s: string = '');
  begin
    if tk <> ptIdent then begin
      if s = '' then s := TokenParser^.CurrentToken;
      raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, s, 'Identifier expected');
    end;
  end;
  procedure AssertExpectedToken(tk: TJitParserTkKind; AExp: TJitParserTkKinds; s: string = '');
  var
    e, b: String;
    a: TJitParserTkKind;
  begin
    if not (tk in AExp) then begin
      if s = '' then s := TokenParser^.CurrentToken;
      e := '';
      for a in TJitParserTkKind do
        if a in AExp then begin
          WriteStr(b, a);
          e := e + ', ' + copy(b, 3, Length(b));
        end;
        delete(e, 1, 2);
      raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, s, 'Unexpected token, expected ' + e);
    end;
  end;
  procedure AssertIsBeforeEOT(AnIncludeSoftEOT: Boolean = False);
  begin
    if not IsBeforeEOT(AnIncludeSoftEOT) then
      raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'End of declaration expected');
  end;
  procedure AssertFoundTypeInfo(const t: PTypeInfo; const s: string);
  begin
    if t = nil then
      raise JitTypeParserExceptionTypeNotFound.Create(TokenParser^.CurPos, s, 'No typeinfo for: ');
  end;

  var
    LastIntTypeInfoFound: TJitType;
  function FindTypeInfo(n: String; AddToRefList: Boolean; AnUnitName: String = '';
    ASearchOptions: TTypeSearchOptions = []): PTypeInfo;
  var
    jt: TJitType;
  begin
    LastIntTypeInfoFound := nil;
    if (AnUnitName = '') and (ASearchOptions = []) then
      AnUnitName := FUnitName;
    if TypeLibrary <> nil then begin
      jt := TypeLibrary.FindType(n, AnUnitName, ASearchOptions);
      if (jt = nil) and  (n <> '') and (n[1] = '&') then begin
        delete(n, 1, 1);
        jt := TypeLibrary.FindType(n, AnUnitName, ASearchOptions);
      end;
      if jt <> nil then begin
        Result := jt.TypeInfo;
        AssertFoundTypeInfo(Result, n);
        LastIntTypeInfoFound := jt;
        if AddToRefList then
          RefCountedTypeInfo.AddToList(jt);
        exit;
      end;
    end;
    if (n <> '') and (n[1] = '&') then
      delete(n, 1, 1);
    Result := TypeInfoByName(n);
  end;

  function GetIdentList(out AList: TStringArray; const ASeparator: TJitParserTkKinds): TJitParserTkKind;
  var
    l: Integer;
  begin
    l := 0;
    AList := nil;
    SetLength(AList, 10);
    repeat
      if l >= Length(AList) then
        SetLength(AList, l + 10);
      AssertIsIdent(TokenParser^.Next);
      AList[l] := TokenParser^.CurrentToken;
      inc(l);
      Result := TokenParser^.Next;
    until not(Result in ASeparator);
    SetLength(AList, l);
  end;

  procedure DoEnum;
  var
    Elems: TStringArray;
    s, un: String;
    MemSize: Integer;
    RttiWriter: TJitRttiWriterTkEnum;
    tk: TJitParserTkKind;
  begin
    tk := GetIdentList(Elems, [ptComma]);
    AssertExpectedToken(tk, [ptRoundClose]);
    AssertIsBeforeEOT(AParser <> nil);

    MemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkEnumeration);
    for s in Elems do
      TJitRttiWriterTkEnum.AddSizeForElemName(MemSize, s);
    un := FUnitName;
    if un = '' then un := '$u'; // must write some unitname
    TJitRttiWriterTkEnum.AddSizeForElemName(MemSize, un);
    TJitRttiWriterTkEnum.FinishSize(MemSize);

    SetFTypeInfo(AllocMem(MemSize));
    RttiWriter := TJitRttiWriterTkEnum.Create(FTypeInfo, FTypeName, Length(Elems));

    for s in Elems do
      RttiWriter.WriteEnumElemName(s);
    RttiWriter.WriteUnitName(un);
    assert(RttiWriter.CurDestMemPos<=Pointer(FTypeInfo)+MemSize, 'DoEnum: RttiWriter.CurDestMemPos<=Pointer(FTypeInfo)+MemSize');
    RttiWriter.Free;
  end;

  procedure DoProcedure(AnIsFunction: Boolean);
  const
    FORMAL_PARAM_NAME = '$formal';
    function TNameToTInfo(tn, tu: string; var rmem: Pointer): TypeInfoPtr; inline;
    var t: PTypeInfo;
    begin
      if (tn = '') or (tn = FORMAL_PARAM_NAME) then
        exit(nil);

      if tu <> '' then
        t := FindTypeInfo(tn, True, tu, [tsoOnlyUnit])
      else
        t := FindTypeInfo(tn, True, FUnitName);
      AssertFoundTypeInfo(t, tn);
      Result := PTypeInfoToTypeInfoPtr(t, rmem);
    end;
  type
    TFuncParam = record
      Flags: TParamFlags;
      NameList: TStringArray;
      TypeName, TypeUnit: String;
    end;
  var
    ParamList: array of TFuncParam;
    CurParams: ^TFuncParam;
    ResTypeName, ResTypeUnit, s, s2: String;
    ti_int64: PTypeInfo;
    HasName, OfObject, HasOpenArray: Boolean;
    Flags: TParamFlags;
    ParamListCnt, ParamCnt, MemSize, PtrRedirectMemSize: Integer;
    param: TFuncParam;
    PtrRedirectMem: Pointer;
    RttiWriterMeth: TJitRttiWriterTkMethod;
    RttiWriterProc: TJitRttiWriterTkProcVar;
    tk: TJitParserTkKind;
  begin
    HasName := False;
    OfObject := pfAlwaysAsMethod in FParseFlags;
    ParamListCnt := 0;
    ParamCnt := 0;
    HasOpenArray := False;

    tk := TokenParser^.PeekKind;
    if (pfAllowProcName in FParseFlags) and (tk = ptIdent) then begin
      TokenParser^.Next;
      TokenParser^.GetQualifiedIdent(s, s2);
      HasName := True;
      OfObject := s <> '';

      tk := TokenParser^.PeekKind;
    end;

    if tk = ptRoundOpen then begin
      // read arguments
      TokenParser^.Next;
      tk := TokenParser^.PeekKind;
      if (tk <> ptRoundClose) then begin
        repeat
          Flags := [];
          tk := TokenParser^.PeekKind(pcFuncParamStart);
          case tk of
            kwVar:      Flags := Flags + [pfVar];
            kwOut:      Flags := Flags + [pfOut];
            kwConst:    Flags := Flags + [pfConst];
            kwConstRef: Flags := Flags + [pfConstRef];
          end;
          if Flags <> [] then
            TokenParser^.Next;

          SetLength(ParamList, ParamListCnt + 1);
          CurParams := @ParamList[ParamListCnt];
          CurParams^.Flags := Flags;
          tk := GetIdentList(CurParams^.NameList, [ptComma]);
          inc(ParamCnt, Length(CurParams^.NameList));

          if tk = ptColon then begin
            tk := TokenParser^.Next;
            if tk = kwArray then begin
              AssertExpectedToken(TokenParser^.Next(pcOfExpexted), [kwOf]);
              HasOpenArray := True;
              CurParams^.Flags := CurParams^.Flags + [pfArray, pfReference];
              inc(ParamCnt, Length(CurParams^.NameList));
              TokenParser^.Next;
              // TODO: if s = 'const' // array of const => array of TVarRec
            end;
            TokenParser^.GetQualifiedIdent(CurParams^.TypeUnit, CurParams^.TypeName);
            tk := TokenParser^.Next;
            if tk = ptEqual then // default value
              while not (tk in [ptSemicolon, ptRoundClose]) do
                tk := TokenParser^.Next;
          end
          else begin
            CurParams^.TypeName := FORMAL_PARAM_NAME;
            CurParams^.TypeUnit := '';
          end;

          // else untyped param
          inc(ParamListCnt);
        until tk <> ptSemicolon;
        AssertExpectedToken(TokenParser^.CurrentKind, [ptRoundClose]);
      end
      else
        TokenParser^.Next; // get the ')' from TokenParser^.PeekKind;
    end;

    if AnIsFunction then begin
      AssertExpectedToken(TokenParser^.Next, [ptColon]);
      TokenParser^.Next;
      TokenParser^.GetQualifiedIdent(ResTypeUnit, ResTypeName);
    end
    else begin
      ResTypeName := '';
      ResTypeUnit := '';
    end;

    tk := TokenParser^.PeekKind(pcOfExpexted);
    if (not HasName) and (tk = kwOf) then begin
      TokenParser^.Next;
      AssertExpectedToken(TokenParser^.Next, [kwObject]);
      OfObject := True;
      tk := TokenParser^.PeekKind;
    end;
    if tk = ptSemicolon then begin
      // TODO: check cdecl....
    end;
    AssertIsBeforeEOT(AParser <> nil);


    if HasOpenArray then begin
      ti_int64 := system.TypeInfo(Int64);
      AssertFoundTypeInfo(ti_int64, 'int64');
    end;

    if OfObject then begin
      // write tkMethod
      inc(ParamCnt); // $self
      MemSize  := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkMethod);
      PtrRedirectMemSize := 0;
      TJitRttiWriterTkMethod.AddSizeForMethodField(MemSize, PtrRedirectMemSize, '$self', 'Pointer');
      for param in ParamList do
        for s in param.NameList do begin
          TJitRttiWriterTkMethod.AddSizeForMethodField(MemSize, PtrRedirectMemSize, s, param.TypeName);
          if pfArray in param.Flags then
            TJitRttiWriterTkMethod.AddSizeForMethodField(MemSize, PtrRedirectMemSize, '$high'+s, 'Int64');
          // TODO: '$formal' param do not need PtrRedirectMemSize
        end;
      if AnIsFunction then
        TJitRttiWriterTkMethod.AddSizeForMethodResult(MemSize, PtrRedirectMemSize, ResTypeName);

      TJitRttiWriterTkMethod.AddSizeForCallingConv(MemSize);
      TJitRttiWriterTkMethod.FinalizeSizeForMethodTypeInfo(MemSize);
      if PtrRedirectMemSize <> 0 then
        MemSize := aligntoptr(MemSize); // for the start of PtrRedirectMemSize

      SetFTypeInfo(AllocMem(MemSize + PtrRedirectMemSize));
      PtrRedirectMem := aligntoptr(Pointer(FTypeInfo) + MemSize);

      if AnIsFunction then
        RttiWriterMeth := TJitRttiWriterTkMethod.Create(FTypeInfo, FTypeName, mkFunction, ParamCnt)
      else
        RttiWriterMeth := TJitRttiWriterTkMethod.Create(FTypeInfo, FTypeName, mkProcedure, ParamCnt);

      try try
        RttiWriterMeth.WriteParamInfo('$self', 'Pointer', [pfHidden, pfSelf]);
        // Params: Flags, ParamName, TypeName
        for param in ParamList do
          for s in param.NameList do begin
            RttiWriterMeth.WriteParamInfo(s, param.TypeName, param.Flags);
            if pfArray in param.Flags then
              RttiWriterMeth.WriteParamInfo('$high'+s, 'Int64', [pfHidden, pfHigh, pfConst]);
          end;
        if AnIsFunction then begin
          RttiWriterMeth.WriteResultInfo(ResTypeName, TNameToTInfo(ResTypeName, ResTypeUnit, PtrRedirectMem));
        end;
        RttiWriterMeth.WriteParamCallConv(ccReg);
        // Params: TypeInfo
        RttiWriterMeth.WriteParamType(PTypeInfoToTypeInfoPtr(system.TypeInfo(Pointer), PtrRedirectMem));
        for param in ParamList do begin
          for s in param.NameList do begin
            RttiWriterMeth.WriteParamType(TNameToTInfo(param.TypeName, param.TypeUnit, PtrRedirectMem));
            if pfArray in param.Flags then
  // TODO: int64 redirection can be created once and for all
              RttiWriterMeth.WriteParamType(PTypeInfoToTypeInfoPtr(ti_int64, PtrRedirectMem));
          end;
        end;
        assert(RttiWriterMeth.CurDestMemPos<=Pointer(FTypeInfo)+MemSize, 'DoProcedure: RttiWriterMeth.CurDestMemPos<=Pointer(FTypeInfo)+MemSize');
      except
//TODO: at this point, any type that got our typeinfo during recursion, has an invalid typeinfo
        SetFTypeInfo(nil);
        raise;
      end
      finally
        RttiWriterMeth.Free;
      end;
    end

    else begin
      // write tkProcVar
      MemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkProcVar);
      if AnIsFunction then
        PtrRedirectMemSize := SIZE_OF_TYPEINFO_PPOINTER
      else
        PtrRedirectMemSize := 0;
      for param in ParamList do
        for s in param.NameList do begin
          TJitRttiWriterTkProcVar.AddSizeForProcVarField(MemSize, PtrRedirectMemSize, s);
          if pfArray in param.Flags then
            TJitRttiWriterTkProcVar.AddSizeForProcVarField(MemSize, PtrRedirectMemSize, '$high'+s);
        end;

      if PtrRedirectMemSize <> 0 then
        MemSize := aligntoptr(MemSize);
      SetFTypeInfo(AllocMem(MemSize + PtrRedirectMemSize));
      PtrRedirectMem := Pointer(FTypeInfo) + MemSize;

      RttiWriterProc := TJitRttiWriterTkProcVar.Create(FTypeInfo, FTypeName,
        0, ccReg, TNameToTInfo(ResTypeName, ResTypeUnit, PtrRedirectMem), ParamCnt);

      try try
        for param in ParamList do begin
          for s in param.NameList do begin
            // TODO: keep a referenc => internal type-lib FInternalTypeLib
            RttiWriterProc.WriteProcedureParam(s, TNameToTInfo(param.TypeName, param.TypeUnit, PtrRedirectMem), param.Flags);
            if pfArray in param.Flags then
              RttiWriterProc.WriteProcedureParam('$high'+s, PTypeInfoToTypeInfoPtr(ti_int64, PtrRedirectMem), [pfHidden, pfHigh, pfConst]);
          end;
        end;
        assert(RttiWriterProc.CurDestMemPos<=Pointer(FTypeInfo)+MemSize, 'DoProcedure: RttiWriterProc.CurDestMemPos<=Pointer(FTypeInfo)+MemSize');
      except
//TODO: at this point, any type that got our typeinfo during recursion, has an invalid typeinfo
        SetFTypeInfo(nil);
        raise;
      end
      finally
        RttiWriterProc.Free;
      end;
    end;
    assert(PtrRedirectMem <= Pointer(FTypeInfo) + MemSize + PtrRedirectMemSize, 'DoProcedure: PtrRedirectMem <= Pointer(FTypeInfo) + MemSize + PtrRedirectMemSize');
  end;

  procedure DoRecord;
  type
    TRecEntry = record
      NameList: TStringArray;
      TypeInfo: PTypeInfo;
    end;
  var
    s, TpName, TpUnit: String;
    tk: TJitParserTkKind;
    RecEntryList: array of TRecEntry;
    CurRecEntry: ^TRecEntry;
    SubJitTypeInfo: TJitTypeInfo;
    RecEntryListCnt, RecEntryCnt, ManagedCount: Integer;
    RecMemSize, InitTblMemSize, PtrRedirectMemSize, RecInstanceSize: Integer;
    RecEntry: TRecEntry;
    PtrRedirectMem: Pointer;
    RttiWriter: TJitRttiWriterTkRecord;
    IsEmbeddedTp: Boolean;
  begin
    // Todo: peak "case"
    RecEntryCnt := 0;
    ManagedCount := 0;
    RecEntryListCnt := 0;
    tk := TokenParser^.PeekKind;
    if tk <> kwEnd then begin
      repeat
        SetLength(RecEntryList, RecEntryListCnt + 1);
        CurRecEntry := @RecEntryList[RecEntryListCnt];

        tk := GetIdentList(CurRecEntry^.NameList, [ptComma]);
        inc(RecEntryCnt, Length(CurRecEntry^.NameList));
        AssertExpectedToken(tk, [ptColon]);

        IsEmbeddedTp := True;
        tk := TokenParser^.Next;
        TokenParser^.SavePosition;
        if tk = ptIdent then begin
          TokenParser^.GetQualifiedIdent(TpUnit, TpName);
          tk := TokenParser^.Next;
          if tk in [ptSemicolon, kwEnd] then begin
            IsEmbeddedTp := False;
            if TpUnit <> '' then
              CurRecEntry^.TypeInfo := FindTypeInfo(TpName, True, TpUnit, [tsoOnlyUnit])
            else
              CurRecEntry^.TypeInfo := FindTypeInfo(TpName, True, FUnitName);
          end;
        end;
        if IsEmbeddedTp then  begin
          // scan embedded type
          TokenParser^.RestorePosition;
          SubJitTypeInfo := TJitTypeInfo.Create('', FDeclaration, FUnitName, TypeLibrary);
          SubJitTypeInfo.ParseFromDeclaration(TokenParser);
          CurRecEntry^.TypeInfo := SubJitTypeInfo.FTypeInfo;  // do not use property / do not scan again if nil
          RefCountedTypeInfo.AddToList(SubJitTypeInfo);
          SubJitTypeInfo.Free;
          tk := TokenParser^.Next;
        end;
        AssertFoundTypeInfo(CurRecEntry^.TypeInfo, '');
        if CurRecEntry^.TypeInfo.isManaged then
          inc(ManagedCount, Length(CurRecEntry^.NameList));

        if (tk = ptSemicolon) and (TokenParser^.PeekKind = kwEnd) then
          tk := TokenParser^.Next;
      until tk <> ptSemicolon;
      AssertExpectedToken(TokenParser^.CurrentKind, [kwEnd]);
    end
    else
      TokenParser^.Next; // read the "end"
    AssertIsBeforeEOT(AParser <> nil);

    RecMemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkRecord)
      + SizeOf(TManagedField) * RecEntryCnt;
    InitTblMemSize := TJitRttiWriterRecInitInfo.NewSizeForInitTable(FTypeName, ManagedCount);
    PtrRedirectMemSize := SIZE_OF_TYPEINFO_PPOINTER * RecEntryCnt;

    RecInstanceSize := 0;

    SetFTypeInfo(AllocMem(RecMemSize + InitTblMemSize + PtrRedirectMemSize));
    PtrRedirectMem := pointer(FTypeInfo) + RecMemSize + InitTblMemSize;

    RttiWriter := TJitRttiWriterTkRecord.Create(FTypeInfo, Pointer(FTypeInfo) + RecMemSize,
      FTypeName, RecEntryCnt, ManagedCount);

    for RecEntry in RecEntryList do
      for s in RecEntry.NameList do begin
        RttiWriter.WriteField(PTypeInfoToTypeInfoPtr(RecEntry.TypeInfo, PtrRedirectMem), RecInstanceSize, RecEntry.TypeInfo.IsManaged);
        RecInstanceSize := RecInstanceSize + RecEntry.TypeInfo.DataSize;
      end;

    RttiWriter.WriteRecSize(RecInstanceSize);
    RttiWriter.RecInitFieldWriter.WriteSize(RecInstanceSize);

    assert(PtrRedirectMem <= Pointer(FTypeInfo)+RecMemSize+InitTblMemSize+PtrRedirectMemSize, 'DoRecord: PtrRedirectMem <= Pointer(FTypeInfo)+RecMemSize+InitTblMemSize+PtrRedirectMemSize');
    assert(RttiWriter.CurDestMemPos <= Pointer(FTypeInfo)+RecMemSize, 'DoRecord: RttiWriter.CurDestMemPos <= Pointer(FTypeInfo)+RecMemSize');
    assert(RttiWriter.RecInitFieldWriter.CurDestMemPos <= Pointer(FTypeInfo)+RecMemSize+InitTblMemSize, 'DoRecord: RttiWriter.RecInitFieldWriter.CurDestMemPos <= Pointer(FTypeInfo)+RecMemSize+InitTblMemSize');
    RttiWriter.Free;
  end;

  procedure DoShortString;
  var
    i: Int64;
    l: Integer;
    qw: Boolean;
  begin
    AssertExpectedToken(TokenParser^.Next, [ptSquareOpen]);
    TokenParser^.Next;
    i := TokenParser^.CurrentTokenAsNum(qw);
    if (i < 1) or (i > 255) then
      raise JitTypeParserException.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'shortstring length out of range');
    AssertExpectedToken(TokenParser^.Next, [ptSquareClose]);
    AssertIsBeforeEOT(AParser <> nil);

    l := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkSString);
    SetFTypeInfo(GetMem(l));
    FTypeInfo^.Kind := tkSString;
    FTypeInfo^.Name := FTypeName;
    GetTypeData(FTypeInfo)^.MaxLength := i;
  end;

  procedure DoSet;
  var
    s, s2: String;
    enum: PTypeInfo;
    SubJitTypeInfo: TJitTypeInfo;
    ByteSize, MemSize: LongInt;
    PtrRedirectMem: Pointer;
    RttiWriter: TJitRttiWriterTkSet;
    IsEmbeddedTp: Boolean;
    tk: TJitParserTkKind;
  begin
    AssertExpectedToken(TokenParser^.Next(pcOfExpexted), [kwOf]);

    IsEmbeddedTp := True;
    tk := TokenParser^.Next;
    TokenParser^.SavePosition;  // So we can roll back to current = 'of', because recursive call starts with NEXT
    if tk = ptIdent then begin
      TokenParser^.GetQualifiedIdent(s2, s);
      if IsBeforeEOT(AParser <> nil) then begin
        IsEmbeddedTp := False;
        if s2 <> '' then
          enum := FindTypeInfo(s, True, s2, [tsoOnlyUnit])
        else
          enum := FindTypeInfo(s, True, FUnitName);
      end;
    end;
    if IsEmbeddedTp then begin
      s := '';
      TokenParser^.RestorePosition;
      SubJitTypeInfo := TJitTypeInfo.Create('', FDeclaration, FUnitName, TypeLibrary);
      SubJitTypeInfo.ParseFromDeclaration(TokenParser);
      enum := SubJitTypeInfo.FTypeInfo;  // do not use property / do not scan again if nil
      RefCountedTypeInfo.AddToList(SubJitTypeInfo);
      SubJitTypeInfo.Free;
      AssertIsBeforeEOT(AParser <> nil);
    end;
    AssertFoundTypeInfo(enum, s);

    case enum^.Kind of
      tkEnumeration,
      tkInteger,tkChar,tkBool,tkWChar:
               ByteSize := GetTypeData(enum)^.MaxValue - GetTypeData(enum)^.MinValue + 1;
      tkInt64: ByteSize := GetTypeData(enum)^.MaxInt64Value - GetTypeData(enum)^.MinInt64Value + 1;
      tkQWord: ByteSize := GetTypeData(enum)^.MaxQWordValue - GetTypeData(enum)^.MinQWordValue + 1;
      else
        raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'Expected enumeration or sub-range');
    end;

    MemSize := aligntoptr(TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkSet));
    SetFTypeInfo(AllocMem(MemSize + SIZE_OF_TYPEINFO_PPOINTER));
    PtrRedirectMem := Pointer(FTypeInfo) + MemSize;

    RttiWriter := TJitRttiWriterTkSet.Create(FTypeInfo, FTypeName, ByteSize, PTypeInfoToTypeInfoPtr(enum, PtrRedirectMem));
    RttiWriter.Free;
  end;

  procedure DoSubRange(tk: TJitParserTkKind; s: String); // s has been read with TokenParser^.Next
    procedure ParseValue(CurKind: TJitParserTkKind; out AnOrdVal: Int64;
      out AJitType: TJitType; out APTypeInfo: PTypeInfo; ALowJitType: TJitType = nil);
    var
      EnumUnit, EnumType, EnumMember: String;
      JitDummy: TJitType;
      InfoDummy: PTypeInfo;
      MemberVal: Integer;
      IsQw: Boolean;
    begin
      LastIntTypeInfoFound := nil;
      APTypeInfo := nil;
      case CurKind of
        ptIdent: if (TypeLibrary <> nil) then begin
            TokenParser^.GetQualifiedIdent(EnumUnit, EnumType, EnumMember);
            case TokenParser^.PeekKind of
              ptRoundOpen: begin                      // we have "EnumType(val)..
                  if EnumUnit <> '' then EnumUnit := EnumUnit + '.';
                  EnumUnit := EnumUnit + EnumType;
                  if EnumUnit = '' then
                    APTypeInfo := FindTypeInfo(EnumMember, False, FUnitName) // EnumMember countains the typename
                  else
                    APTypeInfo := FindTypeInfo(EnumMember, False, EnumUnit, [tsoOnlyUnit]);
                  TokenParser^.Next;
                  CurKind := TokenParser^.Next; // skip the "("
                  AJitType := LastIntTypeInfoFound;
                  ParseValue(CurKind, AnOrdVal, JitDummy, InfoDummy);
                  LastIntTypeInfoFound := AJitType;
                  AssertExpectedToken(TokenParser^.Next, [ptRoundClose]);
                end;
              else begin
                  if EnumType <> '' then begin  // We have "unit.EnumType.Member" or "EnumType.Member"
                    if EnumUnit = '' then
                      APTypeInfo := FindTypeInfo(EnumType, False, FUnitName)
                    else
                      APTypeInfo := FindTypeInfo(EnumType, False, EnumUnit, [tsoOnlyUnit]);
                    AssertFoundTypeInfo(APTypeInfo, TokenParser^.CurrentTokenRaw);
                    if APTypeInfo^.Kind <> tkEnumeration then
                      raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'Enumeration type expected: ');
                    AnOrdVal := GetEnumValue(APTypeInfo, EnumMember);
                    if AnOrdVal < 0 then
                      raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, EnumMember,'Identifier not found');
                  end
                  else
                  begin                               // We have just "Member"
                    if (ALowJitType = nil) or (ALowJitType.TypeInfo^.Kind <> tkEnumeration) then begin
                      LastIntTypeInfoFound := TypeLibrary.FindTypeForEnumElem(EnumMember, MemberVal, FUnitName);
                      AnOrdVal := MemberVal;
                      if LastIntTypeInfoFound <> nil then
                        APTypeInfo := LastIntTypeInfoFound.TypeInfo;
                    end
                    else begin   // parsing high end of range / must be same type
                      APTypeInfo := ALowJitType.TypeInfo;
                      LastIntTypeInfoFound := ALowJitType;
                      AnOrdVal := GetEnumValue(APTypeInfo, EnumMember);
                      if AnOrdVal < 0 then
                        raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, EnumMember,'Identifier not found');
                    end;
                  end;
                end;
            end;
            AssertFoundTypeInfo(APTypeInfo, TokenParser^.CurrentTokenRaw);
         end;
        ptNum: begin
            AnOrdVal := TokenParser^.CurrentTokenAsNum(IsQw);
            if IsQw then
              APTypeInfo := system.TypeInfo(QWord)
            else
            if (AnOrdVal > high(LongInt)) or (AnOrdVal < low(LongInt)) then
              APTypeInfo := system.TypeInfo(Int64)
            else
              APTypeInfo := system.TypeInfo(longint);
          end;
        ptChar: begin
            AnOrdVal  := ord(s[1]);
            APTypeInfo := system.TypeInfo(Char);
          end;
        else
          raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'Expected enumeration or sub-range');
      end;
      AJitType := LastIntTypeInfoFound;
    end;

  var
    LowVal, HighVal, i: Int64;
    LowType, HighType: PTypeInfo;
    MemSize, PtrRedirectMemSize: Integer;
    RttiWriterEnum: TJitRttiWriterTkEnum;
    PtrRedirectMem: Pointer;
    Signed: Boolean;
    RttiWriterIntRange: TJitRttiWriterOrdinal;
    LowJitType, HighJitType: TJitType;
    un: String;
  begin
    ParseValue(tk, LowVal, LowJitType, LowType);
    AssertExpectedToken(TokenParser^.Next, [ptDotDot]);

    ParseValue(TokenParser^.Next, HighVal, HighJitType, HighType, LowJitType);

    if HighVal < LowVal then
      raise JitTypeParserException.Create(TokenParser^.CurPos, '', 'Negative range for set');
    AssertIsBeforeEOT(AParser <> nil);

    case LowType^.Kind of
      tkEnumeration: begin
        if HighType <> LowType then
          raise JitTypeParserException.Create(TokenParser^.CurPos, '', 'Type mismatch between low and high bound');

        MemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkEnumeration);
        PtrRedirectMemSize := SIZE_OF_TYPEINFO_PPOINTER;
        MemSize := aligntoptr(MemSize); // for the start of PtrRedirectMemSize
        i := LowVal;
        while i <= HighVal do begin
          TJitRttiWriterTkEnum.AddSizeForElemName(MemSize, GetEnumName(LowType, i));
          inc(i);
        end;
        un := FUnitName;
        if un = '' then un := '$u'; // must write some unitname
        TJitRttiWriterTkEnum.AddSizeForElemName(MemSize, un);
        TJitRttiWriterTkEnum.FinishSize(MemSize);

        SetFTypeInfo(AllocMem(MemSize + PtrRedirectMemSize));
        PtrRedirectMem := Pointer(FTypeInfo) + MemSize;
        RttiWriterEnum := TJitRttiWriterTkEnum.Create(FTypeInfo, FTypeName, HighVal - LowVal + 1);

        i := LowVal;
        while i <= HighVal do begin
          RttiWriterEnum.WriteEnumElemName(GetEnumName(LowType, i));
          inc(i);
        end;
        RttiWriterEnum.WriteMinMax(LowVal, HighVal);
        RttiWriterEnum.WriteUnitName(un);
        RttiWriterEnum.WriteBaseTypeRef(PTypeInfoToTypeInfoPtr(LowType, PtrRedirectMem));

        assert(RttiWriterEnum.CurDestMemPos <= Pointer(FTypeInfo) + MemSize, 'DoSubRange: RttiWriterEnum.CurDestMemPos <= Pointer(FTypeInfo) + MemSize');

        RttiWriterEnum.Free;
        RefCountedTypeInfo.AddToList(LowJitType);
      end;

      tkInteger, tkInt64, tkQWord: begin
        Signed := LowType^.Kind <> tkQWord;
        if not Signed then begin
          if (HighType^.Kind <> tkQWord) and (HighVal < 0) then begin
            if QWord(LowVal) > QWord(high(int64)) then
              raise JitTypeParserException.Create(TokenParser^.CurPos, '', 'range check error');
            Signed := True;
            if (LowVal <= High(longint)) then begin  // TODO: maybe downgrade if: and (HighVal >= low(LongInt)) => force tkInteger;
              LowType := HighType;  // tkInteger or tkInt64
              LowJitType := HighJitType;
            end
            else begin
              LowType := system.TypeInfo(Int64);
              LowJitType := nil;
            end;
          end;
        end
        else begin // LowType is Signed
          case HighType^.Kind of
            tkInt64: begin
              LowType := HighType; // LowType was either tkInt64 or tkInteger;
              LowJitType := HighJitType;
            end;
            tkQWord: begin
              if (LowVal < 0) then begin
                if QWord(HighVal) > QWord(high(int64)) then
                  raise JitTypeParserException.Create(TokenParser^.CurPos, '', 'range check error');
                Signed := True;
                if (HighVal > High(longint)) then begin
                  LowType := system.TypeInfo(Int64);
                  LowJitType := nil;
                end;
              end
              else begin
                LowType := HighType; // both QWord
                LowJitType := HighJitType;
              end;
            end;
          end;
        end;

        MemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, LowType^.Kind);

        SetFTypeInfo(AllocMem(MemSize));
        RttiWriterIntRange := TJitRttiWriterOrdinal.Create(FTypeInfo, FTypeName, LowType^.Kind);
        RttiWriterIntRange.WriteOrdType(HighVal - LowVal + 1, Signed);
        RttiWriterIntRange.WriteMinMax(LowVal, HighVal);

        RttiWriterIntRange.Free;
        RefCountedTypeInfo.AddToList(LowJitType);
      end;

      tkChar, tkWChar: begin
        if HighType <> LowType then
          raise JitTypeParserException.Create(TokenParser^.CurPos, '', 'Type mismatch between low and high bound');

        MemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, LowType^.Kind);

        SetFTypeInfo(AllocMem(MemSize));
        RttiWriterIntRange := TJitRttiWriterOrdinal.Create(FTypeInfo, FTypeName, LowType^.Kind);
        RttiWriterIntRange.WriteOrdType(HighVal - LowVal + 1, False);
        RttiWriterIntRange.WriteMinMax(LowVal, HighVal);

        RttiWriterIntRange.Free;
        RefCountedTypeInfo.AddToList(LowJitType);
      end;
      //tkBool:; // TODO:
      else
        raise JitTypeParserException.Create(TokenParser^.CurPos, LowType^.Name, 'unexpected sub range type');
    end;
  end;

  procedure DoArray;
  var
    TpUnit, TpName: String;
    ArrayTypeInfo: PTypeInfo;
    SubJitTypeInfo: TJitTypeInfo;
    TypeMemSize: Integer;
    PtrRedirectMem: Pointer;
    RttiWriter: TJitRttiWriterTkDynArray;
    IsEmbeddedTp: Boolean;
    tk: TJitParserTkKind;
  begin
    case TokenParser^.Next(pcOfExpexted) of
      kwOf: begin
        IsEmbeddedTp := True;
        tk := TokenParser^.Next;
        TokenParser^.SavePosition;
        if tk = ptIdent then begin
          TokenParser^.GetQualifiedIdent(TpUnit, TpName);

          if not TokenParser^.IsBeforeEotOrSectionEnd then begin
            IsEmbeddedTp := False;
            if TpUnit <> '' then
              ArrayTypeInfo := FindTypeInfo(TpName, True, TpUnit, [tsoOnlyUnit])
            else
              ArrayTypeInfo := FindTypeInfo(TpName, True, FUnitName);
          end;
        end;
        if IsEmbeddedTp then begin
          TokenParser^.RestorePosition;
          SubJitTypeInfo := TJitTypeInfo.Create('', FDeclaration, FUnitName, TypeLibrary);
          SubJitTypeInfo.ParseFromDeclaration(TokenParser);
          ArrayTypeInfo := SubJitTypeInfo.FTypeInfo;  // do not use property / do not scan again if nil
          RefCountedTypeInfo.AddToList(SubJitTypeInfo);
          SubJitTypeInfo.Free;
        end;
        AssertIsBeforeEOT(AParser <> nil);

        TypeMemSize := TJitRttiWriterTypeInfo.NewSizeFor(FTypeName, tkDynArray);
        SetFTypeInfo(AllocMem(TypeMemSize + SIZE_OF_TYPEINFO_PPOINTER));
        PtrRedirectMem := Pointer(FTypeInfo) + TypeMemSize;

        // TODO: variant type info
        RttiWriter := TJitRttiWriterTkDynArray.Create(FTypeInfo, FTypeName,
          FUnitName, ArrayTypeInfo.DataSize, PTypeInfoToTypeInfoPtr(ArrayTypeInfo, PtrRedirectMem), -1);

        assert(RttiWriter.CurDestMemPos <= Pointer(FTypeInfo) + TypeMemSize, 'DoArray: RttiWriter.CurDestMemPos <= Pointer(FTypeInfo) + TypeMemSize');
        RttiWriter.Free;
      end;
      //ptSquareOpen: ;
      else
        raise JitTypeParserExceptionSyntaxError.Create(TokenParser^.CurPos, TokenParser^.CurrentToken, 'Expected "of"'); // 'Expected "[" or "of"'
    end;
  end;

var
  NewTypeInfo: PTypeInfo;
  s: String;
  tk, tk2: TJitParserTkKind;
begin
  if FIsInParseFromDeclaration then
    exit;
  FIsInParseFromDeclaration := true;
  try
    Decl := FDeclaration;
    if AParser = nil then
      Decl := TrimDeclaration(Decl);

    if AParser <> nil then begin
      TokenParser := AParser;
    end
    else begin
      TheTokenParser.Create(@Decl[1]);
      TokenParser := @TheTokenParser;
    end;

    tk := TokenParser^.CurrentKind;
    case tk of
      ptRoundOpen: DoEnum;
      kwProcedure: DoProcedure(False);
      kwFunction:  DoProcedure(True);
      kwRecord:    DoRecord;
      kwSet:       DoSet;
      kwArray:     DoArray;
      else begin
        if (tk = kwString) and (TokenParser^.PeekKind() = ptSquareOpen ) then begin
          DoShortString;
          exit;
        end;

        s := TokenParser^.CurrentToken;
        if tk in [ptIdent, ptNum, ptChar] then begin
          tk2 := TokenParser^.PeekKind;
          if tk2 in [ptRoundOpen, ptDotDot, ptDot] then begin
            // subrange: value .. value  OR  TypeCast(value) ..
            DoSubRange(tk, s);
            exit;
          end;
        end;

        if tk <> kwString then // string may be added as an alias
          AssertIsIdent(tk, s);

        NewTypeInfo := FindTypeInfo(s, False);
        if IsBeforeEOT(AParser <> nil) and (NewTypeInfo <> nil) then begin
          if (LastIntTypeInfoFound <> nil) and (not LastIntTypeInfoFound.IsConstTypeInfo) then
            SetFTypeInfo(NewTypeInfo)
          else
            SetConstFTypeInfo(NewTypeInfo);
          RefCountedTypeInfo.AddToList(LastIntTypeInfoFound);
          exit;
        end;

        raise JitTypeParserExceptionTypeNotFound.Create(TokenParser^.CurPos, s, 'type not found')
      end;
    end;

  finally
    FIsInParseFromDeclaration := False;
  end;
end;

constructor TJitTypeInfo.Create(ATypeName, ADeclaration, AUnitName: String;
  ATypeLibrary: TJitTypeLibrary; AParseFlags: TJitTypeInfoParseFlags);
begin
  Create(ATypeName, ADeclaration, ATypeLibrary, AParseFlags);
  UnitName := AUnitName;
end;

constructor TJitTypeInfo.Create(ATypeName, ADeclaration: String;
  ATypeLibrary: TJitTypeLibrary; AParseFlags: TJitTypeInfoParseFlags);
begin
  FDeclaration := ADeclaration;
  FParseFlags := AParseFlags;
  inherited Create(ATypeName, ATypeLibrary);
end;

constructor TJitTypeInfo.Create(ATypeName: String; ATypeInfo: PTypeInfo;
  ATypeLibrary: TJitTypeLibrary);
begin
  SetConstFTypeInfo(ATypeInfo);
  inherited Create(ATypeName, ATypeLibrary);
end;

destructor TJitTypeInfo.Destroy;
begin
  inherited Destroy;
  if FRefCountedTypeInfo <> nil then
    FRefCountedTypeInfo.ReleaseLock
  else
  if (FTypeInfo <> nil) and not FIsConstTypeInfo then
    Freemem(FTypeInfo);
end;

{ TJitTypeClass }

function TJitTypeClass.GetTypeInfo: PTypeInfo;
begin
  Result := FClass.ClassInfo;
end;

constructor TJitTypeClass.Create(ATypeName: String; AClass: TClass;
  ATypeLibrary: TJitTypeLibrary);
begin
  inherited Create(ATypeName, ATypeLibrary);
  FClass := AClass;
end;

{ TJitTypeJitClass }

procedure TJitTypeJitClass.DoCreatorFreed(Sender: TObject);
begin
  FJitClassCreator := nil;
end;

function TJitTypeJitClass.GetTypeInfo: PTypeInfo;
begin
  if FJitClassCreator <> nil then
    Result := FJitClassCreator.TypeInfo
  else
    Result := nil;
end;

function TJitTypeJitClass.GetLockReferenceInc: TRefCountedJitReference;
begin
  if FJitClassCreator <> nil then
    Result := FJitClassCreator.LockReference
  else
    Result := nil;
end;

function TJitTypeJitClass.IsConstTypeInfo: Boolean;
begin
  Result := False;
end;

constructor TJitTypeJitClass.Create(ATypeName: String;
  AJitClassCreator: TJitClassCreatorBase; ATypeLibrary: TJitTypeLibrary;
  ATakeOwnerShip: Boolean);
begin
  inherited Create(ATypeName, ATypeLibrary);
  FJitClassCreator := AJitClassCreator;
  if FJitClassCreator <> nil then
    FJitClassCreator.AddFreeNotification(@DoCreatorFreed);
  FOwnJitCreator := ATakeOwnerShip;
end;

destructor TJitTypeJitClass.Destroy;
begin
  inherited Destroy;
  if FJitClassCreator <> nil then begin
    FJitClassCreator.RemoveFreeNotification(@DoCreatorFreed);
    if FOwnJitCreator then
      FJitClassCreator.Free;
  end;
end;

{ TJitTypeAlias }

function TJitTypeAlias.GetRealType: TJitType;
begin
  Result := FRealType;
  if Result <> nil then
    exit;
  if TypeLibrary = nil then
    exit;

  if FInGetRealType then
    raise Exception.Create('circular alias');
  FInGetRealType := True;
  try
    Result := TypeLibrary[FRealTypeName];
  finally
    FInGetRealType := False;
  end;
end;

procedure TJitTypeAlias.DoRealTypeFreed(Sender: TObject);
begin
  FRealType := nil;
  FTypeName := ''; // no longer valid / do not look up a new type
end;

function TJitTypeAlias.GetTypeInfo: PTypeInfo;
var
  RealType: TJitType;
begin
  Result := nil;
  RealType := GetRealType;
  if RealType <> nil then begin
    Result := RealType.TypeInfo;
    exit;
  end;
  Result := TypeInfoByName(FRealTypeName);
end;

function TJitTypeAlias.GetLockReferenceInc: TRefCountedJitReference;
var
  RealType: TJitType;
begin
  RealType := GetRealType;
  if RealType <> nil then
    Result := GetRealType.LockReference
  else
    Result := nil;
end;

function TJitTypeAlias.IsConstTypeInfo: Boolean;
var
  RealType: TJitType;
begin
  RealType := GetRealType;
  if RealType <> nil then
    Result := GetRealType.IsConstTypeInfo
  else
    Result := inherited IsConstTypeInfo;
end;

function TJitTypeAlias.GetResolvedTypeName: String;
var
  RealType: TJitType;
begin
  RealType := GetRealType;
  if RealType <> nil then
    Result := GetRealType.ResolvedTypeName
  else
    Result := inherited ResolvedTypeName;
end;

constructor TJitTypeAlias.Create(ATypeName, ARealTypeName: String;
  ATypeLibrary: TJitTypeLibrary);
begin
  FRealTypeName := ARealTypeName;
  inherited Create(ATypeName, ATypeLibrary);
end;

constructor TJitTypeAlias.Create(ATypeName: String; ARealType: TJitType;
  ATypeLibrary: TJitTypeLibrary);
begin
  FRealType := ARealType;
  if FRealType <> nil then
    FRealType.AddFreeNotification(@DoRealTypeFreed);
  inherited Create(ATypeName, ATypeLibrary);
end;

destructor TJitTypeAlias.Destroy;
begin
  inherited Destroy;
  if FRealType <> nil then
    FRealType.RemoveFreeNotification(@DoRealTypeFreed);
end;

{ TJitTypeLibrary }

procedure TJitTypeLibrary.DoTypeFreed(Sender: TObject);
var
  i: Integer;
begin
  i := FTypeMap.IndexOfData(TJitType(Sender));
  if i < 0 then
    exit;
  FTypeMap.Delete(i);
end;

function TJitTypeLibrary.GetTypes(AName: String): TJitType;
var
  i: Integer;
begin
  Result := nil;
  i := FTypeMap.IndexOf(LowerCase(AName));
  if i >= 0 then
    Result := FTypeMap.Data[i];
end;

procedure TJitTypeLibrary.SetAllowDuplicates(AValue: Boolean);
begin
  if FAllowDuplicates = AValue then Exit;
  FAllowDuplicates := AValue;
  case AValue of
    True:  FTypeMap.Duplicates := dupAccept;
    False: FTypeMap.Duplicates := dupError;
  end;
end;

function TJitTypeLibrary.IndexOf(ATypeName, AnUnitName: String): Integer;
begin
  if AnUnitName = '' then begin
    Result := FTypeMap.IndexOf(ATypeName);
    exit;
  end;
  Result := FTypeMap.Count - 1;
  while (Result >= 0) and
        ( (FTypeMap.Data[Result].TypeName <> ATypeName) or
          (FTypeMap.Data[Result].UnitName <> AnUnitName) )
  do
    dec(Result);
end;

constructor TJitTypeLibrary.Create;
begin
  FTypeMap := TTypeMap.Create;
  AllowDuplicates := True;
end;

destructor TJitTypeLibrary.Destroy;
begin
  Clear;
  FTypeMap.Free;
  inherited Destroy;
end;

function TJitTypeLibrary.AddType(AType: TJitType; ATakeOwnerShip: Boolean
  ): TJitType;
begin
  Result := AType;
  Result.AddFreeNotification(@DoTypeFreed);
  if (IndexOf(AType.TypeName, AType.UnitName) >= 0) then
    raise Exception.Create('Duplicate Type');

  FTypeMap.Add(LowerCase(AType.TypeName), AType);

  if (AType.TypeLibrary = nil) or ATakeOwnerShip then
    AType.TypeLibrary := Self;
  if ATakeOwnerShip then
    AType.FOwnedByLibrary := True;

end;

function TJitTypeLibrary.AddType(ATypeName, ADeclaration: String;
  AForceNewJitTypeInfo: Boolean): TJitType;
begin
  Result := AddType(ATypeName, ADeclaration, '', AForceNewJitTypeInfo);
end;

function TJitTypeLibrary.AddType(ATypeName, ADeclaration, AUnitName: String;
  AForceNewJitTypeInfo: Boolean): TJitType;
begin
  if (IndexOf(ATypeName, AUnitName) >= 0) then
    raise Exception.Create('Duplicate Type');

  if not AForceNewJitTypeInfo then begin
    Result := Self[ADeclaration];
    if Result <> nil then begin
      Result := AddAlias(ATypeName, ADeclaration);
      exit;
    end;
  end;

  Result := TJitTypeInfo.Create(ATypeName, ADeclaration, AUnitName);
  Result.AddFreeNotification(@DoTypeFreed);
  FTypeMap.Add(LowerCase(ATypeName), Result);
  Result.TypeLibrary := Self;
  Result.FOwnedByLibrary := True;
end;

function TJitTypeLibrary.AddClass(ATypeName: String; AClass: TClass): TJitType;
begin
  if (IndexOf(ATypeName, AClass.UnitName) >= 0) then
    raise Exception.Create('Duplicate Type');

  Result := TJitTypeClass.Create(ATypeName, AClass);
  Result.AddFreeNotification(@DoTypeFreed);
  FTypeMap.Add(LowerCase(ATypeName), Result);
  Result.TypeLibrary := Self;
  Result.FOwnedByLibrary := True;
end;

function TJitTypeLibrary.AddJitClass(ATypeName: String;
  AJitClassCreator: TJitClassCreatorBase; ATakeCreatorOwnerShip: Boolean
  ): TJitType;
begin
  if (IndexOf(ATypeName, AJitClassCreator.ClassUnit) >= 0) then
    raise Exception.Create('Duplicate Type');

  Result := TJitTypeJitClass.Create(ATypeName, AJitClassCreator, Self, ATakeCreatorOwnerShip);
  Result.AddFreeNotification(@DoTypeFreed);
  FTypeMap.Add(LowerCase(ATypeName), Result);
  Result.FOwnedByLibrary := True;
end;

function TJitTypeLibrary.AddAlias(ATypeName, ARealTypeName: String): TJitType;
begin
  Result := TJitTypeAlias.Create(ATypeName, ARealTypeName);
  Result.AddFreeNotification(@DoTypeFreed);
  FTypeMap.Add(LowerCase(ATypeName), Result);
  Result.TypeLibrary := Self;
  Result.FOwnedByLibrary := True;
end;

procedure TJitTypeLibrary.Remove(ATypeName: String; AnUnitName: String);
  procedure RemoveEntry(AnIdx: Integer; AJytTyp: TJitType);
  var
    owned: Boolean;
  begin
    owned := AJytTyp.FOwnedByLibrary and (AJytTyp.TypeLibrary = Self);
    if AJytTyp.TypeLibrary = Self then
      AJytTyp.TypeLibrary := nil;

    FTypeMap.Delete(AnIdx);
    if owned then
      AJytTyp.Free  // TODO: Decrease RefCount ?
    else
      AJytTyp.RemoveFreeNotification(@DoTypeFreed);
  end;
var
  i: Integer;
  JytTyp: TJitType;
begin
  if AllowDuplicates or (AnUnitName <> '') then begin
    i := FTypeMap.Count - 1;
    while i >= 0 do begin
      JytTyp := FTypeMap.Data[i];
      if (JytTyp.TypeName = ATypeName) and
         ( (AnUnitName = '') or (AnUnitName = JytTyp.UnitName) )
      then
        RemoveEntry(i, JytTyp);
      dec(i);
      if i >= FTypeMap.Count then
        i := FTypeMap.Count - 1;
    end;
  end
  else begin
    i := FTypeMap.IndexOf(ATypeName); // bin search if sorted
    if i < 0 then
      exit;
    JytTyp := FTypeMap.Data[i];

    RemoveEntry(i, JytTyp);
  end;
end;

procedure TJitTypeLibrary.Clear;
var
  i: Integer;
  t: TJitType;
begin
  for i := 0 to FTypeMap.Count - 1 do begin
    t := FTypeMap.Data[i];
    t.RemoveFreeNotification(@DoTypeFreed);
    if t.FOwnedByLibrary and (t.TypeLibrary = Self) then
      t.Free;
  end;
  FTypeMap.Clear;
end;

function TJitTypeLibrary.FindType(const AName: String; AnUnitName: String;
  ASearchOptions: TTypeSearchOptions): TJitType;
var
  i: Integer;
  FOtherUnitResult: TJitType;
  n, u: String;
begin
  FOtherUnitResult := nil;
  n := LowerCase(AName);
  u := LowerCase(AnUnitName);
  for i := 0 to FTypeMap.Count - 1 do begin
    Result := FTypeMap.Data[i];
    if LowerCase(Result.TypeName) <> n then
      continue;
    if (tsoOnlyUnit in ASearchOptions) and (LowerCase(Result.UnitName) <> u) then
      continue;

    if (AnUnitName <> '') and (u <> LowerCase(Result.UnitName)) and (FOtherUnitResult = nil) then
        FOtherUnitResult := Result
    else
      exit;
  end;
  Result := FOtherUnitResult;
end;

function TJitTypeLibrary.FindTypeForEnumElem(const AnEnumElem: String;
  AnUnitName: String; ASearchOptions: TTypeSearchOptions): TJitType;
var
  x: Integer;
begin
  Result := FindTypeForEnumElem(AnEnumElem, x, AnUnitName, ASearchOptions);
end;

function TJitTypeLibrary.FindTypeForEnumElem(const AnEnumElem: String; out
  AnEnumVal: Integer; AnUnitName: String; ASearchOptions: TTypeSearchOptions
  ): TJitType;
var
  i, FOtherUnitEnumVal: Integer;
  t: PTypeInfo;
  FOtherUnitResult: TJitType;
  u: String;
begin
  FOtherUnitResult := nil;
  FOtherUnitEnumVal := -1;
  u := LowerCase(AnUnitName);
  for i := 0 to FTypeMap.Count - 1 do begin
    Result := FTypeMap.Data[i];
    if (not (tsoOnlyUnit in ASearchOptions)) or (LowerCase(Result.UnitName) = u) then begin
      t := Result.TypeInfo;
      if (t <> nil) and (t^.Kind = tkEnumeration) then begin
        AnEnumVal := GetEnumValue(Result.TypeInfo, AnEnumElem);
        if AnEnumVal >= 0 then begin
          if (AnUnitName <> '') and (u <> LowerCase(Result.UnitName)) and (FOtherUnitResult = nil) then begin
            FOtherUnitResult := Result;
            FOtherUnitEnumVal := AnEnumVal;
          end
          else
            exit;
        end;
      end;
    end;
  end;
  Result := FOtherUnitResult;
  AnEnumVal := FOtherUnitEnumVal;
end;

end.


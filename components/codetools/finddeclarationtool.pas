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
    TFindDeclarationTool enhances the TPascalReaderTool with the ability
    to find the source position or code tree node of a declaration.


  ToDo:
    - high type expression evaluation
      (i.e. at the moment: integer+integer=longint
                   wanted: integer+integer=integer)
    - make @Proc context sensitive (started, but not complete)
    - operator overloading
    - ppu, dcu files
    - many things, search for 'ToDo'
}
unit FindDeclarationTool;

{$ifdef FPC}{$mode objfpc}{$endif}{$H+}

interface

{$I codetools.inc}

// activate for debugging:

// mem check
{ $DEFINE MEM_CHECK}

// verbosity
{ $DEFINE CTDEBUG}
{ $DEFINE ShowTriedFiles}
{ $DEFINE ShowTriedContexts}
{ $DEFINE ShowTriedBaseContexts}
{ $DEFINE ShowTriedParentContexts}
{ $DEFINE ShowTriedIdentifiers}
{ $DEFINE ShowTriedUnits}
{ $DEFINE ShowExprEval}
{ $DEFINE ShowForInEval}
{ $DEFINE ShowFoundIdentifier}
{ $DEFINE ShowNodeCache}
{ $DEFINE ShowBaseTypeCache}
{ $DEFINE ShowCacheDependencies}
{ $DEFINE ShowCollect}
{ $DEFINE ShowProcSearch}
{ $DEFINE VerboseFindDeclarationFail}
{ $DEFINE DebugAddToolDependency}
{ $DEFINE VerboseCPS}
{ $DEFINE VerboseFindDeclarationAndOverload}
{ $DEFINE VerboseFindFileAtCursor}

{$IFDEF CTDEBUG}{$DEFINE DebugPrefix}{$ENDIF}
{$IFDEF ShowTriedIdentifiers}{$DEFINE DebugPrefix}{$ENDIF}
{$IFDEF ShowTriedContexts}{$DEFINE DebugPrefix}{$ENDIF}
{$IFDEF ShowExprEval}{$DEFINE ShowForInEval}{$ENDIF}

uses
  {$IFDEF MEM_CHECK}
  MemCheck,
  {$ENDIF}
  Classes, SysUtils, Laz_AVL_Tree,
  // LazUtils
  LazFileUtils, LazUtilities,
  // Codetools
  CodeToolsStrConsts, CodeTree, CodeAtom, CustomCodeTool,
  SourceLog, KeywordFuncLists, BasicCodeTools, LinkScanner, CodeCache,
  DirectoryCacher, PascalParserTool, PascalReaderTool, FileProcs,
  DefineTemplates, FindDeclarationCache;

type
  TFindDeclarationTool = class;
  
  //----------------------------------------------------------------------------
  // variable atoms

  TVariableAtomType = (
    vatNone,             // undefined
    vatSpace,            // empty or space
    vatIdentifier,       // an identifier
    vatPreDefIdentifier, // an identifier with special meaning to the compiler
    vatPoint,            // .
    vatAS,               // AS keyword
    vatINHERITED,        // INHERITED keyword
    vatUp,               // ^
    vatRoundBracketOpen, // (
    vatRoundBracketClose,// )
    vatEdgedBracketOpen, // [
    vatEdgedBracketClose,// ]
    vatAddrOp,           // @
    vatKeyword,          // other keywords
    vatNumber,           // decimal, & octal, % binary, $ hex
    vatStringConstant    // '' or #
    );
    
const
  // for nicer debugging output
  VariableAtomTypeNames: array[TVariableAtomType] of string =
    ('<None>',
     'Space',
     'Ident',
     'PreDefIdent',
     'Point',
     'AS',
     'INHERITED',
     'Up^ ',
     'Bracket(',
     'Bracket)',
     'Bracket[',
     'Bracket]',
     'AddrOperator@ ',
     'Keyword',
     'Number',
     'StringConstant'
     );
     
type
  //----------------------------------------------------------------------------
  // searchpath delimiter is semicolon
  TOnGetSearchPath = function(Sender: TObject): string of object;
  TOnGetSrcPathForCompiledUnit =
    function(Sender: TObject; const Filename: string): string of object;

  //----------------------------------------------------------------------------
  TOnGetMethodName = function(const AMethod: TMethod;
                              CheckOwner: TObject): string of object;

  //----------------------------------------------------------------------------
  // flags/states for searching
  TFindDeclarationFlag = (
    fdfSearchInAncestors,   // if context is a class, search also in
                            //    ancestors/interfaces
    fdfSearchInParentNodes, // if identifier not found in current context,
                            //    proceed in prior nodes on same lvl and parents
    fdfIgnoreCurContextNode,// skip context and proceed in prior/parent context
    fdfIgnoreUsedUnits,     // stay in current source
    fdfSearchForward,       // instead of searching in prior nodes, search in
                            //    next nodes (successors)
                            
    fdfExceptionOnNotFound, // raise exception if identifier not found
                            //    predefined identifiers will not raise
    fdfExceptionOnPredefinedIdent,// raise an exception even if the identifier
                            // is a predefined identifier
                            
    fdfIgnoreClassVisibility,//find inaccessible private+protected fields

    fdfIgnoreMissingParams, // found proc fits, even if parameters are missing
    fdfOnlyCompatibleProc,  // incompatible procs are ignored
    fdfIgnoreOverloadedProcs,// ignore param lists and take the first proc found
    
    fdfFindVariable,        // do not search for the base type of a variable,
                            //   instead return the variable declaration
    fdfFunctionResult,      // if function is found, return result type
    fdfEnumIdentifier,      // do not resolve enum to its enum type
    fdfFindChildren,        // search the class of a 'class of', the interface of a unit
    fdfSkipClassForward,    // when a class forward was found search the class
    
    fdfCollect,             // return every reachable identifier
    fdfTopLvlResolving,     // set, when searching for an identifier of the
                            //   top lvl variable. Calling DoOnIdentifierFound.
    fdfDoNotCache,          // result will not be cached
    fdfExtractOperand,      // operand will be extracted
    fdfPropertyResolving,   // used with fdfExtractOperand to resolve properties to getters

    fdfSearchInHelpers,     // search in class/record/type helpers too
    fdfSearchInHelpersInTheEnd, // search in helpers after current class (used with inherited call in helper)
    fdfTypeType,            // do not resolve TMyString = type string;
    fdfIgnoreOperatorError, // return expression type even if an operator error was found
    fdfOverrideStringTypesWithFirstParamType  // if you search for an expression result type of a "function A(B: string): string", override the result type with type of B expression
    );
  TFindDeclarationFlags = set of TFindDeclarationFlag;
  
const
  // masks to pass flags to sub searches
  fdfGlobals = [fdfExceptionOnNotFound, fdfTopLvlResolving,
                fdfExtractOperand, fdfPropertyResolving,
                fdfOverrideStringTypesWithFirstParamType];
  fdfGlobalsSameIdent = fdfGlobals+[fdfExceptionOnPredefinedIdent,
                fdfIgnoreMissingParams, fdfIgnoreUsedUnits, fdfDoNotCache,
                fdfOnlyCompatibleProc, fdfSearchInAncestors, fdfCollect, fdfSearchInHelpers];
  // initial flags for searches
  fdfDefaultForExpressions = [fdfSearchInParentNodes, fdfSearchInAncestors, fdfSearchInHelpers,
                              fdfExceptionOnNotFound,fdfIgnoreCurContextNode];

type
  // flags/states for result
  TFoundDeclarationFlag = (
    fodDoNotCache
    );
  TFoundDeclarationFlags = set of TFoundDeclarationFlag;
  
  //----------------------------------------------------------------------------
type
  TFindDeclarationParams = class;
  
  TFindContext = record
    Node: TCodeTreeNode;
    Tool: TFindDeclarationTool;
  end;
  PFindContext = ^TFindContext;
  
const
  CleanFindContext: TFindContext = (Node:nil; Tool:nil);
  
type
  //----------------------------------------------------------------------------
  { TExpressionTypeDesc describes predefined types
    The Freepascal compiler can automatically convert them
  }
  TExpressionTypeDesc = (
    xtNone,        // undefined
    xtContext,     // a node
    xtChar,        // char
    xtWideChar,    // widechar
    xtReal,        // real
    xtSingle,      // single
    xtDouble,      // double
    xtExtended,    // extended
    xtCExtended,   // cextended
    xtCurrency,    // currency
    xtComp,        // comp
    xtInt64,       // int64
    xtCardinal,    // cardinal
    xtQWord,       // qword
    xtBoolean,     // boolean
    xtByteBool,    // bytebool
    xtWordBool,    // wordbool
    xtLongBool,    // longbool
    xtQWordBool,   // qwordbool
    xtString,      // string
    xtAnsiString,  // ansistring
    xtShortString, // shortstring
    xtWideString,  // widestring
    xtUnicodeString,// unicodestring
    xtPChar,       // pchar
    xtPointer,     // pointer
    xtFile,        // file
    xtText,        // text
    xtConstOrdInteger,// enum, number, integer
    xtConstString, // string, string constant, char constant
    xtConstReal,   // real number
    xtConstSet,    // [] set
    xtConstBoolean,// true, false
    xtLongint,     // longint
    xtLongWord,    // longword
    xtWord,        // word
    xtSmallInt,    // smallint
    xtShortInt,    // shortint
    xtByte,        // byte
    xtNativeInt,   // depends on compiler and platform
    xtNativeUInt,  // depends on compiler and platform
    xtCompilerFunc,// SUCC, PREC, LOW, HIGH, ORD, LENGTH, COPY (1.1), ...
    xtVariant,     // variant
    xtJSValue,     // jsvalue only in Pas2JS, similar to variant
    xtNil,         // nil  = pointer, class, procedure, method, ...
    xtSizeInt      // SizeInt for Length intrinsic
    );
  // Do not define: TExpressionTypeDescs = set of TExpressionTypeDesc;
  // There are too many enums, so the set would be big and slow
  
var
  ExpressionTypeDescNames: array[TExpressionTypeDesc] of string = (
    'None',
    'Context',
    'Char',
    'WideChar',
    'Real',
    'Single',
    'Double',
    'Extended',
    'CExtended',
    'Currency',
    'Comp',
    'Int64',
    'Cardinal',
    'QWord',
    'Boolean',
    'ByteBool',
    'WordBool',
    'LongBool',
    'QWordBool',
    'String',
    'AnsiString',
    'ShortString',
    'WideString',
    'UnicodeString',
    'PChar',
    'Pointer',
    'File',
    'TextFile',
    'ConstOrdInt',
    'ConstString',
    'ConstReal',
    'ConstSet',
    'ConstBoolean',
    'LongInt',
    'LongWord',
    'Word',
    'SmallInt',
    'ShortInt',
    'Byte',
    'NativeInt',
    'NativeUInt',
    'CompilerFunc',
    'Variant',
    'JSValue',
    'Nil',
    'SizeInt'
  );

const
  xtAllTypes = [Low(TExpressionTypeDesc)..High(TExpressionTypeDesc)]-[xtNone];
  xtAllPredefinedTypes = xtAllTypes-[xtContext];
  xtAllConstTypes = [xtConstOrdInteger,xtConstBoolean,xtConstReal,
                     xtConstString,xtConstSet,xtCompilerFunc,xtNil];
  xtAllIdentTypes = xtAllTypes - xtAllConstTypes;
  xtAllIdentPredefinedTypes = xtAllIdentTypes - [xtContext];
  xtAllIntegerTypes = [xtInt64, xtQWord, xtConstOrdInteger, xtLongint,
                       xtLongWord, xtWord, xtCardinal, xtSmallInt, xtShortInt,
                       xtByte,xtNativeInt,xtNativeUInt,xtSizeInt];
  xtAllBooleanTypes = [xtBoolean, xtByteBool, xtWordBool, xtLongBool,xtQWordBool];
  xtAllRealTypes = [xtReal, xtConstReal, xtSingle, xtDouble,
                    xtExtended, xtCExtended, xtCurrency, xtComp];
  xtAllStringTypes = [xtConstString, xtShortString, xtString, xtAnsiString];
  xtAllWideStringTypes = [xtConstString, xtWideString, xtUnicodeString];
  xtAllPointerTypes = [xtPointer, xtNil];
  xtAllTypeHelperTypes = xtAllPredefinedTypes-[xtCompilerFunc,xtVariant,xtJSValue,xtNil];

  xtAllStringCompatibleTypes = xtAllStringTypes+[xtChar,xtJSValue];
  xtAllWideStringCompatibleTypes = xtAllWideStringTypes+[xtWideChar,xtChar];

  xtAllIntegerConvertibles = xtAllIntegerTypes;
  xtAllRealConvertibles = xtAllRealTypes+xtAllIntegerTypes;
  xtAllStringConvertibles = xtAllStringCompatibleTypes+[xtPChar];
  xtAllWideStringConvertibles = xtAllWideStringCompatibleTypes+[xtPChar];
  xtAllBooleanConvertibles = xtAllBooleanTypes+[xtConstBoolean];
  xtAllPointerConvertibles = xtAllPointerTypes+[xtPChar];
  xtAllPas2JSExtraTypes = [xtJSValue,xtNativeInt,xtNativeUInt];

type
  { TExpressionType is used for compatibility check
    A compatibility check is done by comparing two TExpressionType

    if Desc = xtConstSet, SubDesc contains the type of the set
    if Context.Node<>nil, it contains the corresponding codetree node
    if Desc = xtPointer then SubDesc contains the type e.g. xtChar
  }
  TExpressionType = record
    Desc: TExpressionTypeDesc;
    SubDesc: TExpressionTypeDesc;
    Context: TFindContext;
  end;
  PExpressionType = ^TExpressionType;
  
const
  CleanExpressionType : TExpressionType =
    (Desc:xtNone; SubDesc:xtNone; Context:(Node:nil; Tool:nil));

type
  //----------------------------------------------------------------------------
  // TTypeCompatibility is the result of a compatibility check
  TTypeCompatibility = (
    tcExact,        // exactly same type, can be used for var parameters
    tcCompatible,   // type can be auto converted, can not be used for var parameters
    tcIncompatible  // type is incompatible
    );
  TTypeCompatibilityList = ^TTypeCompatibility;
    
const
  TypeCompatibilityNames: array[TTypeCompatibility] of string = (
       'Exact',
       'Compatible', // convertable, but not allowed for var params
       'Incompatible'
     );

type
  //----------------------------------------------------------------------------
  // TExprTypeList is used for compatibility checks of whole parameter lists
  TExprTypeList = class
  private
    FCapacity: integer;
    procedure SetCapacity(const AValue: integer);
  protected
    procedure Grow;
  public
    Count: integer;
    Items: PExpressionType;
    AliasTypes: PFindContext;
    procedure Add(const ExprType: TExpressionType);
    procedure Add(const ExprType: TExpressionType; const AliasType: TFindContext);
    procedure AddFirst(const ExprType: TExpressionType);
    property Capacity: integer read FCapacity write SetCapacity;
    destructor Destroy; override;
    function AsString: string;
    function CalcMemSize: PtrUInt;
  end;

type

  { TOperand }

  TOperand = record
    Expr: TExpressionType;
    AliasType: TFindContext;
  end;

  //----------------------------------------------------------------------------
  // TTypeAliasOrderList is used for comparing type aliases in binary operators

  TTypeAliasItem = class
  public
    AliasName: string;
    Position: Integer;
  end;

  TTypeAliasOrderList = class
  private
    FTree: TAVLTree;
  public
    constructor Create(const AliasNames: array of string);
    destructor Destroy; override;

    procedure Add(const AliasName: string);
    procedure Add(const AliasNames: array of string);
    procedure Insert(const AliasName: string; const Pos: Integer);
    procedure InsertBefore(const AliasName, BeforeAlias: string);
    procedure InsertAfter(const AliasName, AfterAlias: string);
    procedure Delete(const Pos: Integer);
    procedure Delete(const AliasName: string);
    function IndexOf(const AliasName: string): Integer;
    function Compare(const AliasName1, AliasName2: string): Integer;
    function Compare(const Operand1, Operand2: TOperand;
      Tool: TFindDeclarationTool; CleanPos: Integer): TOperand;
  end;

  function CompareTypeAliasItems(Item1, Item2: Pointer): Integer;
  function CompareTypeAliasItemString(AliasName, Item: Pointer): Integer;

type
  //----------------------------------------------------------------------------
  // TFoundProc is used for comparing overloaded procs
  PFoundProc = ^TFoundProc;
  TFoundProc = record
    // the expression input list, which should fit into the searched proc
    ExprInputList: TExprTypeList;
    // the best proc found till now
    Context: TFindContext;
    // if the proc was already compared (CacheValid=true), then some of the
    // compatibility check results are cached.
    CacheValid: boolean;
    ProcCompatibility: TTypeCompatibility;
    ParamCompatibilityList: TTypeCompatibilityList;
    // each TFindDeclarationParams has a list of PFoundProc
    Owner: TObject;
    Next, Prior: PFoundProc;
  end;

  //---------------------------------------------------------------------------
type
  TIdentifierFoundResult = (ifrProceedSearch, ifrAbortSearch, ifrSuccess);

const
  IdentifierFoundResultNames: array[TIdentifierFoundResult] of string =
    ('ProceedSearch', 'AbortSearch', 'Success');

type
  TOnIdentifierFound = function(Params: TFindDeclarationParams;
    const FoundContext: TFindContext): TIdentifierFoundResult of object;
  TOnFindUsedUnit = function(SrcTool: TFindDeclarationTool;
    const TheUnitName, TheUnitInFilename: string): TCodeBuffer of object;
  TOnGetCodeToolForBuffer = function(Sender: TObject;
    Code: TCodeBuffer; GoToMainCode: boolean): TFindDeclarationTool of object;
  TOnGetDirectoryCache = function(const ADirectory: string
                                  ): TCTDirectoryCache of object;

  TFDHelpersListKind = (
    fdhlkDelphiHelper,
    fdhlkObjCCategory
    );

  { TFDHelpersListItem }

  TFDHelpersListItem = class(TObject)
    ForExprType: TExpressionType;
    HelperContext: TFindContext; // Node.Desc (ctnClassHelper, ctnRecordHelper, ctnTypeHelper) or (ctnObjCCategory)
    function CalcMemSize: PtrUInt;
  end;

  { TFDHelpersListRec }

  TFDHelpersListRec = record
    ForExprType: TExpressionType;
    HelperContext: TFindContext;
  end;

  { TFDHelpersList }

  TFDHelpersList = class
  private
    FKind: TFDHelpersListKind;
    FTree: TAVLTree; { tree of TFDHelpersListItem sorted for CompareHelpersList.
       Nodes with same key (ForExprType) are chronologically ordered from left to right. }
     procedure AddChronologically(Item: TFDHelpersListItem);
  public
    function AddFromHelperNode(HelperNode: TCodeTreeNode;
      Tool: TFindDeclarationTool; Replace: Boolean): TFDHelpersListItem;
    procedure AddFromList(const Tool: TFindDeclarationTool; const ExtList: TFDHelpersList);
    function IterateFromClassNode(ClassNode: TCodeTreeNode;
      Tool: TFindDeclarationTool; out HelperContext: TFindContext; out Iterator: TAVLTreeNode): boolean; // returns newest (rightmost)
    function GetNext(out HelperContext: TFindContext; var Iterator: TAVLTreeNode): boolean;
    function FindFromExprType(const ExprType: TExpressionType): TFindContext; // returns newest (rightmost)
    procedure DeleteHelperNode(HelperNode: TCodeTreeNode; Tool: TFindDeclarationTool);
    constructor Create(aKind: TFDHelpersListKind);
    destructor Destroy; override;
    procedure Clear;
    function Count: Integer;
    function CalcMemSize: PtrUInt;
    procedure WriteDebugReport;
    property Kind: TFDHelpersListKind read FKind;
    property Tree: TAVLTree read FTree;
  end;

  { TGenericParamValueMapping }

  TGenericParamValueMapping = packed class
    NextBrother: TGenericParamValueMapping;
    GenericParamNode,
    SpecializeValueNode: TCodeTreeNode;
    constructor Create(pPrevBrother: TGenericParamValueMapping; pParam, pValue: TCodeTreeNode);
    destructor Destroy; override;
  end;

  { TGenericParamValueMappings }

  TGenericParamValueMappings = record
    SpecializeParamsTool: TFindDeclarationTool;
    SpecializeParamsNode: TCodeTreeNode;
    SpecializeValuesTool: TFindDeclarationTool;
    FirstParamValueMapping: TGenericParamValueMapping;
  end;

  { TGenericParams }

  TGenericParams = record
    ParamValuesTool: TFindDeclarationTool;
    SpecializeParamsNode: TCodeTreeNode;
  end;

  TFindDeclarationInput = record
    Flags: TFindDeclarationFlags;
    Identifier: PChar;
    ContextNode: TCodeTreeNode;
    OnIdentifierFound: TOnIdentifierFound;
    IdentifierTool: TFindDeclarationTool;
    FoundProc: PFoundProc;
  end;

  { TFindDeclarationParams
    This contains the parameters for find declaration, the result, the hooks
    and the memory management for dynamic search data.
    It can be re-used. That means, the search parameters can be saved, changed
    and restored (load).
    The static parameters are stored on the stack, while the dynamic data
    (e.g. FoundProc) is stored in a private list (FirstFoundProc).
    For speed reasons the find declaration does not use try..finally and that's
    why some saved data is not explicitely freed. Therefore the Load method
    frees all dynamic data, that was later saved too.
    That's why the following code is forbidden:
      Save(Data1);
      Save(Data2);
      Load(Data1); // this will free Data2
      Load(Data2);
    
    When searching a procedure, the parameter list must be compared.
    The parameter list of the currently best fitting procedure is stored in
    FoundProc.
      }

  TFindDeclarationParams = class(TObject)
  private
    FFoundProcStackFirst: PFoundProc;//list of all saved PFoundProc
    FFoundProcStackLast: PFoundProc;
    FExtractedOperand: string;
    FHelpers: array[TFDHelpersListKind] of TFDHelpersList;
    FFreeHelpers: array[TFDHelpersListKind] of Boolean;
    FNeedHelpers: Boolean;
    GenParamValueMappings: TGenericParamValueMappings;
    procedure ClearFoundProc;
    procedure FreeFoundProc(aFoundProc: PFoundProc; FreeNext: boolean);
    procedure RemoveFoundProcFromList(aFoundProc: PFoundProc);
  private
    procedure SetFoundProc(const ProcContext: TFindContext);
    procedure ChangeFoundProc(const ProcContext: TFindContext;
                              ProcCompatibility: TTypeCompatibility;
                              ParamCompatibilityList: TTypeCompatibilityList);
  private
    procedure SetGenericParamValues(SpecializeParamsTool: TFindDeclarationTool;
                SpecializeNode: TCodeTreeNode);
    procedure UpdateGenericParamMapping(SpecializeParamsTool: TFindDeclarationTool;
                SpecializeParamsNode: TCodeTreeNode; GenericParamsNode: TCodeTreeNode);
    procedure UpdateContexWithGenParamValue(var SpecializeParamContext: TFindContext);
    function FindGenericParamType: Boolean;
    procedure AddOperandPart(aPart: string);
    property ExtractedOperand: string read FExtractedOperand;
    function IsFoundProcFinal: boolean;
    procedure PrettifyResult;
    procedure ConvertResultCleanPosToCaretPos;
    procedure ClearResult(CopyCacheFlags: boolean);
    procedure ClearInput;
  public
    // input parameters:
    Flags: TFindDeclarationFlags;
    Identifier: PChar;
    StartTool: TFindDeclarationTool;
    StartNode: TCodeTreeNode;
    Parent: TFindDeclarationParams;
    ContextNode: TCodeTreeNode;
    OnIdentifierFound: TOnIdentifierFound;
    IdentifierTool: TFindDeclarationTool;
    FoundProc: PFoundProc;
    Data: Pointer;
    // global params
    OnTopLvlIdentifierFound: TOnIdentifierFound;
    GenParams: TGenericParams;
    // results:
    NewNode: TCodeTreeNode;
    NewCleanPos: integer;
    NewCodeTool: TFindDeclarationTool;
    NewPos: TCodeXYPosition;
    NewTopLine: integer;
    NewFlags: TFoundDeclarationFlags;
    constructor Create(ParentParams: TFindDeclarationParams = nil);
    constructor Create(Tool: TFindDeclarationTool; AContextNode: TCodeTreeNode);
    destructor Destroy; override;
    procedure Clear;
    procedure Save(out Input: TFindDeclarationInput);
    procedure Load(Input: TFindDeclarationInput; FreeInput: boolean);
    procedure SetResult(const AFindContext: TFindContext);
    procedure SetResult(ANewCodeTool: TFindDeclarationTool;
                        ANewNode: TCodeTreeNode);
    procedure SetResult(ANewCodeTool: TFindDeclarationTool;
                        ANewNode: TCodeTreeNode;  ANewCleanPos: integer);
    procedure SetResult(NodeCacheEntry: PCodeTreeNodeCacheEntry);
    procedure SetIdentifier(NewIdentifierTool: TFindDeclarationTool;
                NewIdentifier: PChar; NewOnIdentifierFound: TOnIdentifierFound);
    procedure WriteDebugReport;
    function GetHelpers(HelperKind: TFDHelpersListKind; CreateIfNotExists: boolean = false): TFDHelpersList;
  end;
  
  
  //----------------------------------------------------------------------------
  // TFindDeclarationTool is source based and can therefore search for more
  // than declarations:
type
  TFindSmartFlag = (
    fsfIncludeDirective, // search for include file
    fsfFindMainDeclaration, // stop if already on a declaration
    fsfSearchSourceName, // if searching for a unit name, return the source name node
    fsfSkipClassForward  // when a forward class was found, jump further to the class
    );
  TFindSmartFlags = set of TFindSmartFlag;
const
  DefaultFindSmartFlags = [fsfIncludeDirective];
  DefaultFindSmartHintFlags = DefaultFindSmartFlags+[fsfFindMainDeclaration];

type
  TFindSrcStartType = (
    fsstIdentifier
    );

  TFindDeclarationListFlag = (
    fdlfWithoutEmptyProperties, // omit properties without type and attributes
    fdlfWithoutForwards,        // omit foward classes and procedures
    fdlfIfStartIsDefinitionStop,// omit overloads when start is a definition
    fdlfOneOverloadPerUnit      // ignore other overloads of an identifier within the same unit
    );
  TFindDeclarationListFlags = set of TFindDeclarationListFlag;

  TFindOperatorEnumerator = (
    foeProcNode, // proc node of operator
    foeResultClassNode, // classnode of result type of operator
    foeEnumeratorCurrentNode, // function or property with modifier 'enumerator Current'
    foeEnumeratorCurrentExprType // expression type of 'enumerator Current'
    );

  TFindFileAtCursorFlag = (
    ffatNone,
    ffatUsedUnit,
    ffatIncludeFile,
    ffatDisabledIncludeFile,
    ffatResource,
    ffatDisabledResource,
    ffatLiteral,
    ffatComment,
    ffatUnit // unit by name
    );
  TFindFileAtCursorFlags = set of TFindFileAtCursorFlag;
const
  DefaultFindFileAtCursorAllowed = [Low(TFindFileAtCursorFlag)..high(TFindFileAtCursorFlag)];

type
  //----------------------------------------------------------------------------
  ECodeToolUnitNotFound = class(ECodeToolFileNotFound)
  end;

  //----------------------------------------------------------------------------

  TFindIdentifierInUsesSection_FindMissingFPCUnit = class;

  //----------------------------------------------------------------------------

  { TFindDeclarationTool }

  TFindDeclarationTool = class(TPascalReaderTool)
  private
    FAdjustTopLineDueToComment: boolean;
    FDirectoryCache: TCTDirectoryCache;
    FFindMissingFPCUnits: TFindIdentifierInUsesSection_FindMissingFPCUnit;
    FInterfaceIdentifierCache: TInterfaceIdentifierCache;
    FInterfaceHelperCache: array[TFDHelpersListKind] of TFDHelpersList;
    FOnFindUsedUnit: TOnFindUsedUnit;
    FOnGetCodeToolForBuffer: TOnGetCodeToolForBuffer;
    FOnGetDirectoryCache: TOnGetDirectoryCache;
    FOnGetMethodName: TOnGetMethodname;
    FOnGetSrcPathForCompiledUnit: TOnGetSrcPathForCompiledUnit;
    FOnGetUnitSourceSearchPath: TOnGetSearchPath;
    FFirstNodeCache: TCodeTreeNodeCache;
    FOnRescanFPCDirectoryCache: TNotifyEvent;
    FRootNodeCache: TCodeTreeNodeCache;
    FFirstBaseTypeCache: TBaseTypeCache;
    FDependentCodeTools: TAVLTree;// the codetools, that depend on this codetool
    FDependsOnCodeTools: TAVLTree;// the codetools, that this codetool depends on
    FClearingDependentNodeCaches: boolean;
    FCheckingNodeCacheDependencies: boolean;
    FSourcesChangeStep, FFilesChangeStep: int64;
    FInitValuesChangeStep: integer;
    {$IFDEF DebugPrefix}
    DebugPrefix: string;
    procedure IncPrefix;
    procedure DecPrefix;
    {$ENDIF}
    function FindDeclarationInUsesSection(UsesNode: TCodeTreeNode;
      CleanPos: integer;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindUnitFileInUsesSection(UsesNode: TCodeTreeNode;
      const AFilename: string): TCodeTreeNode;
    function FindUnitFileInAllUsesSections(const AFilename: string;
      CheckMain: boolean = true; CheckImplementation: boolean = true): TCodeTreeNode;
    function FindEnumInContext(Params: TFindDeclarationParams): boolean;
    // sub methods for FindIdentifierInContext
    function DoOnIdentifierFound(Params: TFindDeclarationParams;
      FoundNode: TCodeTreeNode): TIdentifierFoundResult;
    function FindIdentifierInProcContext(ProcContextNode: TCodeTreeNode;
      Params: TFindDeclarationParams): TIdentifierFoundResult;
    function FindIdentifierInClassOfMethod(ProcContextNode: TCodeTreeNode;
      Params: TFindDeclarationParams): boolean;
    function FindIdentifierInWithVarContext(WithVarNode: TCodeTreeNode;
      Params: TFindDeclarationParams): boolean;
    function FindIdentifierInAncestors(ClassNode: TCodeTreeNode;
      Params: TFindDeclarationParams; var IdentFoundResult: TIdentifierFoundResult): boolean;
    function FindIdentifierInAncestors(ClassNode: TCodeTreeNode;
      Params: TFindDeclarationParams): boolean;
    function FindIdentifierInUsesSection(UsesNode: TCodeTreeNode;
      Params: TFindDeclarationParams; FindMissingFPCUnits: Boolean): boolean;
    function FindIdentifierInHiddenUsedUnits(
      Params: TFindDeclarationParams): boolean;
    function FindIdentifierInUsedUnit(const AnUnitName: string;
      Params: TFindDeclarationParams; ErrorPos: integer): boolean;
    function FindIdentifierInTypeOfConstant(VarConstNode: TCodeTreeNode;
      Params: TFindDeclarationParams): boolean;
  protected
    WordIsPredefinedIdentifier: TKeyWordFunctionList;
    procedure RaiseUsesExpected(id: int64);
    procedure RaiseStrConstExpected(id: int64);
  protected
    // node caches
    procedure DoDeleteNodes(StartNode: TCodeTreeNode); override;
    function CheckDependsOnNodeCaches(CheckedTools: TAVLTree = nil): boolean;
    procedure ClearNodeCaches;
    procedure ClearDependentNodeCaches;
    procedure ClearDependsOnToolRelationships;
    procedure AddToolDependency(DependOnTool: TFindDeclarationTool);
    function CreateNewNodeCache(Node: TCodeTreeNode): TCodeTreeNodeCache;
    function CreateNewBaseTypeCache(Tool: TFindDeclarationTool;
                                    Node: TCodeTreeNode): TBaseTypeCache;
    procedure CreateBaseTypeCaches(NodeStack: PCodeTreeNodeStack;
      const Result: TFindContext);
    function GetNodeCache(Node: TCodeTreeNode;
      CreateIfNotExists: boolean): TCodeTreeNodeCache;
    procedure AddResultToNodeCaches(
      StartNode, EndNode: TCodeTreeNode; SearchedForward: boolean;
      Params: TFindDeclarationParams; SearchRangeFlags: TNodeCacheEntryFlags);
  protected
    // expressions, operands, variables
    function GetCurrentAtomType: TVariableAtomType;
    function FindEndOfTerm(StartPos: integer;
      ExceptionIfNoVariableStart, WithAsOperator: boolean): integer; // read one operand
    function FindStartOfTerm(EndPos: integer; InType: boolean): integer;
    function NodeTermInType(Node: TCodeTreeNode): boolean;
    function FindExpressionTypeOfTerm(StartPos, EndPos: integer;
      Params: TFindDeclarationParams; WithAsOperator: boolean;
      AliasType: PFindContext = nil): TExpressionType;
    function FindEndOfExpression(StartPos: integer): integer; // read all operands and operators
    function ReadOperandTypeAtCursor(Params: TFindDeclarationParams;
      MaxEndPos: integer = -1; AliasType: PFindContext = nil): TExpressionType;
    function FindExpressionTypeOfPredefinedIdentifier(StartPos: integer;
      Params: TFindDeclarationParams; AliasType: PFindContext = nil): TExpressionType;
    function FindExpressionTypeOfConstSet(Node: TCodeTreeNode): TExpressionType;
    function GetDefaultStringType: TExpressionTypeDesc;
    function CalculateBinaryOperator(LeftOperand, RightOperand: TOperand;
      BinaryOperator: TAtomPosition;
      Params: TFindDeclarationParams): TOperand;
    function GetParameterNode(Node: TCodeTreeNode): TCodeTreeNode;
    function GetExpressionTypeOfTypeIdentifier(
      Params: TFindDeclarationParams): TExpressionType;
    function FindTermTypeAsString(TermPos: TAtomPosition;
      Params: TFindDeclarationParams; out ExprType: TExpressionType): string;
    function FindForInTypeAsString(TermPos: TAtomPosition;
      CursorNode: TCodeTreeNode; Params: TFindDeclarationParams;
      out ExprType: TExpressionType): string;
    function FindEnumeratorOfClass(ClassNode: TCodeTreeNode;
      ExceptionOnNotFound: boolean; out ExprType: TExpressionType;
      AliasType: PFindContext = nil; ParentParams: TFindDeclarationParams = nil): boolean;
    function FindOperatorEnumerator(Node: TCodeTreeNode;
      ExprType: TExpressionType; Need: TFindOperatorEnumerator;
      out ResultExprType: TExpressionType): boolean;
    function FindEnumerationTypeOfSetType(SetTypeNode: TCodeTreeNode;
      out Context: TFindContext): boolean;
    function FindElementTypeOfArrayType(ArrayNode: TCodeTreeNode;
      out ExprType: TExpressionType; AliasType: PFindContext;
      ParentParams: TFindDeclarationParams = nil): boolean;
    function CheckOperatorEnumerator(Params: TFindDeclarationParams;
      const FoundContext: TFindContext): TIdentifierFoundResult;
    function CheckModifierEnumeratorCurrent({%H-}Params: TFindDeclarationParams;
      const FoundContext: TFindContext): TIdentifierFoundResult;
    function IsTermEdgedBracket(TermPos: TAtomPosition;
      out EdgedBracketsStartPos: integer): boolean;
    function IsTermNamedPointer(TermPos: TAtomPosition;
      out ExprType: TExpressionType): boolean;
    function FindSetOfEnumerationType(EnumNode: TCodeTreeNode): TCodeTreeNode;
    function FindPointerOfIdentifier(TypeNode: TCodeTreeNode): TCodeTreeNode;
    function FindExprTypeAsString(const ExprType: TExpressionType;
      TermCleanPos: integer;
      AliasType: PFindContext = nil): string;
  protected
    function CheckSrcIdentifier(Params: TFindDeclarationParams;
      const FoundContext: TFindContext): TIdentifierFoundResult;
    function FindDeclarationOfIdentAtParam(
      Params: TFindDeclarationParams; out ExprType: TExpressionType): boolean;
    function FindDeclarationOfIdentAtParam(
      Params: TFindDeclarationParams): boolean;
    function IdentifierIsDefined(const IdentAtom: TAtomPosition;
      ContextNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
    function FindContextNodeAtCursor(
      Params: TFindDeclarationParams): TFindContext;
    function FindClassOfMethod(ProcNode: TCodeTreeNode;
      FindClassContext, ExceptionOnNotFound: boolean): TCodeTreeNode;
    function FindClassMember(aClassNode: TCodeTreeNode; Identifier: PChar): TCodeTreeNode;
    function FindForwardIdentifier(Params: TFindDeclarationParams;
      out IsForward: boolean): boolean;
    function FindNonForwardClass(ForwardNode: TCodeTreeNode): TCodeTreeNode;
    function FindNonForwardClass(Params: TFindDeclarationParams): boolean;
    function FindIdentifierInInterface(AskingTool: TFindDeclarationTool;
      Params: TFindDeclarationParams): boolean;
    function CompareNodeIdentifier(Node: TCodeTreeNode;
      Params: TFindDeclarationParams): boolean;
    function GetInterfaceNode: TCodeTreeNode;
    function CompatibilityList1IsBetter(List1, List2: TTypeCompatibilityList;
      ListCount: integer): boolean;
    function IsParamExprListCompatibleToNodeList(
      FirstTargetParameterNode: TCodeTreeNode;
      SourceExprParamList: TExprTypeList; IgnoreMissingParameters: boolean;
      Params: TFindDeclarationParams;
      CompatibilityList: TTypeCompatibilityList): TTypeCompatibility;
    function IsParamNodeListCompatibleToParamNodeList(FirstTargetParameterNode,
      FirstSourceParameterNode: TCodeTreeNode;
      Params: TFindDeclarationParams;
      CompatibilityList: TTypeCompatibilityList): TTypeCompatibility;
    function CreateParamExprListFromStatement(StartPos: integer;
      Params: TFindDeclarationParams; GetAlias: boolean = false): TExprTypeList;
    function ContextIsDescendOf(
      const DescendContext, AncestorContext: TFindContext;
      Params: TFindDeclarationParams): boolean;
    function IsCompatible(TargetNode: TCodeTreeNode;
      const ExpressionType: TExpressionType;
      Params: TFindDeclarationParams): TTypeCompatibility;
    function IsCompatible(TargetType, ExpressionType: TExpressionType;
      Params: TFindDeclarationParams): TTypeCompatibility;
    function IsBaseCompatible(const TargetType, ExpressionType: TExpressionType;
      Params: TFindDeclarationParams): TTypeCompatibility;
    function CheckParameterSyntax(StartPos, CleanCursorPos: integer;
      out ParameterAtom, ProcNameAtom: TAtomPosition;
      out ParameterIndex: integer): boolean;
    procedure OnFindUsedUnitIdentifier(Sender: TPascalParserTool;
      IdentifierCleanPos: integer; Range: TEPRIRange;
      Node: TCodeTreeNode; Data: Pointer; var {%H-}Abort: boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ConsistencyCheck; override;
    procedure CalcMemSize(Stats: TCTMemStats); override;

    procedure BeginParsing(Range: TLinkScannerRange); override;
    procedure ValidateToolDependencies; override;
    function BuildInterfaceIdentifierCache(ExceptionOnNotUnit: boolean): boolean;
    function FindDeclaration(const CursorPos: TCodeXYPosition;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindMainDeclaration(const CursorPos: TCodeXYPosition;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindDeclarationOfIdentifier(const CursorPos: TCodeXYPosition;
      Identifier: PChar;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindDeclaration(const CursorPos: TCodeXYPosition;
      SearchSmartFlags: TFindSmartFlags;
      out NewTool: TFindDeclarationTool; out NewNode: TCodeTreeNode;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindDeclaration(const CursorPos: TCodeXYPosition;
      SearchSmartFlags: TFindSmartFlags;
      out NewTool: TFindDeclarationTool; out NewNode: TCodeTreeNode;
      out NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine, BlockBottomLine: integer): boolean;
    function FindDeclaration(const CursorPos: TCodeXYPosition;
      SearchSmartFlags: TFindSmartFlags;
      out NewExprType: TExpressionType;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindDeclaration(const CursorPos: TCodeXYPosition;
      SearchSmartFlags: TFindSmartFlags;
      out NewExprType: TExpressionType;
      out NewPos: TCodeXYPosition; out NewTopLine,BlockTopLine,BlockBottomLine: integer): boolean;
    function FindDeclarationInInterface(const Identifier: string;
      out NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine, BlockBottomLine: integer): boolean;
    function FindDeclarationWithMainUsesSection(const Identifier: string;
      out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
    function FindClassMember(aClassNode: TCodeTreeNode;
      const Identifier: String; SearchInAncestors: boolean): TFindContext;
    function FindDeclarationOfPropertyPath(const PropertyPath: string;
      out NewContext: TFindContext; IgnoreTypeLess: boolean = false): boolean;
    function FindDeclarationOfPropertyPath(const PropertyPath: string;
      out NewPos: TCodeXYPosition; out NewTopLine: integer;
      IgnoreTypeLess: boolean = false): boolean;
    function FindDeclarationNodeInInterface(const Identifier: string;
      BuildTheTree: Boolean): TCodeTreeNode;// search for type, const, var, proc, prop
    function FindDeclarationNodeInImplementation(Identifier: string;
      BuildTheTree: Boolean): TCodeTreeNode;// search for type, const, var, proc, prop
    function FindSubDeclaration(Identifier: string; ParentNode: TCodeTreeNode
      ): TCodeTreeNode; // search for type, const, var, proc, prop
    function FindNameInUsesSection(UsesNode: TCodeTreeNode; const AUnitName: string): TCodeTreeNode;
    function FindUnitInUsesSection(UsesNode: TCodeTreeNode; const AnUnitName: string;
          out NamePos, InPos: TAtomPosition): boolean;
    function FindUnitInAllUsesSections(const AnUnitName: string;
          out NamePos, InPos: TAtomPosition): boolean;
    function GetUnitNameForUsesSection(TargetTool: TFindDeclarationTool): string;
    function IsHiddenUsedUnit(TheUnitName: PChar): boolean;

    function FindCodeToolForUsedUnit(const AnUnitName, AnUnitInFilename: string;
      ExceptionOnNotFound: boolean): TFindDeclarationTool;
    function FindUnitSource(const AnUnitName,
      AnUnitInFilename: string; ExceptionOnNotFound: boolean;
      ErrorPos: integer = 0): TCodeBuffer;
    function FindUnitCaseInsensitive(var AnUnitName,
                                     AnUnitInFilename: string): string;
    procedure GatherUnitAndSrcPath(var UnitPath, CompleteSrcPath: string);
    function SearchUnitInUnitSet(const TheUnitName: string): string;
    function GetNameSpaces: string;

    function IsIncludeDirectiveAtPos(CleanPos, CleanCodePosInFront: integer;
      out IncludeCode: TCodeBuffer): boolean;
    function FindFileAtCursor(const CursorPos: TCodeXYPosition;
      out Found: TFindFileAtCursorFlag; out FoundFilename: string;
      SearchFor: TFindFileAtCursorFlags = DefaultFindFileAtCursorAllowed;
      StartPos: PCodeXYPosition = nil): boolean;

    function FindSmartHint(const CursorPos: TCodeXYPosition;
                    Flags: TFindSmartFlags = DefaultFindSmartHintFlags): string;
    function GetSmartHint(Node: TCodeTreeNode; XYPos: TCodeXYPosition;
                          WithPosition: boolean; WithDefinition: boolean = True): string;

    function BaseTypeOfNodeHasSubIdents(ANode: TCodeTreeNode): boolean;
    function FindBaseTypeOfNode(Params: TFindDeclarationParams;
      Node: TCodeTreeNode; AliasType: PFindContext = nil;
      NodeStack: PCodeTreeNodeStack = nil): TFindContext;
    function ConvertNodeToExpressionType(Node: TCodeTreeNode;
      Params: TFindDeclarationParams; AliasType: PFindContext = nil): TExpressionType;
    function FindExpressionResultType(Params: TFindDeclarationParams;
      StartPos, EndPos: integer; AliasType: PFindContext = nil): TExpressionType;

    function FindDeclarationAndOverload(const CursorPos: TCodeXYPosition;
      out ListOfPCodeXYPosition: TFPList;
      Flags: TFindDeclarationListFlags): boolean;
    function FindIdentifierContextsAtStatement(CleanPos: integer;
      out IsSubIdentifier: boolean; out ListOfPFindContext: TFPList): boolean;

    // ancestors
    function FindClassAndAncestors(ClassNode: TCodeTreeNode;
      var ListOfPFindContext: TFPList; ExceptionOnNotFound: boolean
      ): boolean; // without interfaces, recursive
    function FindContextClassAndAncestorsAndExtendedClassOfHelper(const CursorPos: TCodeXYPosition;
      var ListOfPFindContext: TFPList): boolean; // without interfaces
    function FindAncestorOfClass(ClassNode: TCodeTreeNode;
      Params: TFindDeclarationParams; FindClassContext: boolean): boolean; // returns false for TObject, IInterface, IUnknown
    function FindDefaultAncestorOfClass(ClassNode: TCodeTreeNode;
      Params: TFindDeclarationParams; FindClassContext: boolean): boolean; // returns false for TObject, IInterface, IUnknown
    function FindAncestorOfClassInheritance(IdentifierNode: TCodeTreeNode;
      ResultParams: TFindDeclarationParams; FindClassContext: boolean): boolean;
    function FindAncestorsOfClass(ClassNode: TCodeTreeNode;
      var ListOfPFindContext: TFPList;
      Params: TFindDeclarationParams; FindClassContext: boolean;
      ExceptionOnNotFound: boolean = true): boolean; // with interfaces, not recursive

    function FindExtendedExprOfHelper(HelperNode: TCodeTreeNode): TExpressionType;

    function FindReferences(const CursorPos: TCodeXYPosition;
      SkipComments: boolean; out ListOfPCodeXYPosition: TFPList): boolean;
    function FindUnitReferences(UnitCode: TCodeBuffer;
      SkipComments: boolean; out ListOfPCodeXYPosition: TFPList): boolean; // searches unitname of UnitCode
    procedure FindUsedUnitReferences(const CursorPos: TCodeXYPosition;
      SkipComments: boolean; out UsedUnitFilename: string;
      out ListOfPCodeXYPosition: TFPList); // searches all references of unit in uses clause
    procedure FindUsedUnitReferences(TargetTool: TFindDeclarationTool;
      SkipComments: boolean;
      out ListOfPCodeXYPosition: TFPList); // searches all references of TargetTool

    function CleanPosIsDeclarationIdentifier(CleanPos: integer;
                                             Node: TCodeTreeNode): boolean;

    procedure FindHelpersInContext(Params: TFindDeclarationParams);
    procedure FindHelpersInUsesSection(UsesNode: TCodeTreeNode;
      Params: TFindDeclarationParams);
    procedure FindHelpersInInterface(AskingTool: TFindDeclarationTool;
      Params: TFindDeclarationParams);
    function FindIdentifierInContext(Params: TFindDeclarationParams;
      var IdentFoundResult: TIdentifierFoundResult): boolean;
    function FindIdentifierInContext(Params: TFindDeclarationParams): boolean;
    function FindIdentifierInBasicTypeHelpers(ExprType: TExpressionTypeDesc;
      Params: TFindDeclarationParams): Boolean;
    function FindNthParameterNode(Node: TCodeTreeNode;
                                  ParameterIndex: integer): TCodeTreeNode;
    function GetFirstParameterNode(Node: TCodeTreeNode): TCodeTreeNode;
    function IsParamNodeListCompatibleToExprList(
      TargetExprParamList: TExprTypeList;
      FirstSourceParameterNode: TCodeTreeNode;
      Params: TFindDeclarationParams;
      CompatibilityList: TTypeCompatibilityList = nil): TTypeCompatibility;
    function CreateParamExprListFromProcNode(ProcNode: TCodeTreeNode;
      Params: TFindDeclarationParams): TExprTypeList;

    function JumpToNode(ANode: TCodeTreeNode;
        out NewPos: TCodeXYPosition; out NewTopLine: integer;
        IsCodeBlock: boolean): boolean;
    function JumpToNode(ANode: TCodeTreeNode;
        out NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine, BlockBottomLine: integer;
        IsCodeBlock: boolean): boolean;
    function JumpToCleanPos(NewCleanPos, NewTopLineCleanPos,
        NewBottomLineCleanPos: integer;
        out NewPos: TCodeXYPosition; out NewTopLine: integer;
        IsCodeBlock: boolean): boolean;
    function JumpToCleanPos(NewCleanPos, NewTopLineCleanPos,
        NewBottomLineCleanPos: integer;
        out NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine, BlockBottomLine: integer;
        IsCodeBlock: boolean): boolean;
    function NodeIsForwardDeclaration(Node: TCodeTreeNode): boolean;

    function GetExpandedOperand(const CursorPos: TCodeXYPosition;
          out Operand: string; ResolveProperty: Boolean): Boolean;

    property InterfaceIdentifierCache: TInterfaceIdentifierCache
                                                 read FInterfaceIdentifierCache;
    property OnGetUnitSourceSearchPath: TOnGetSearchPath
               read FOnGetUnitSourceSearchPath write FOnGetUnitSourceSearchPath;
    property OnFindUsedUnit: TOnFindUsedUnit
                                     read FOnFindUsedUnit write FOnFindUsedUnit;
    property OnGetCodeToolForBuffer: TOnGetCodeToolForBuffer
                     read FOnGetCodeToolForBuffer write FOnGetCodeToolForBuffer;
    property OnGetDirectoryCache: TOnGetDirectoryCache read FOnGetDirectoryCache
                                                     write FOnGetDirectoryCache;
    property OnGetSrcPathForCompiledUnit: TOnGetSrcPathForCompiledUnit
           read FOnGetSrcPathForCompiledUnit write fOnGetSrcPathForCompiledUnit;
    property OnGetMethodName: TOnGetMethodname read FOnGetMethodName
                                               write FOnGetMethodName;
    property AdjustTopLineDueToComment: boolean
               read FAdjustTopLineDueToComment write FAdjustTopLineDueToComment;
    property DirectoryCache: TCTDirectoryCache read FDirectoryCache write FDirectoryCache;

    property OnRescanFPCDirectoryCache: TNotifyEvent read FOnRescanFPCDirectoryCache write FOnRescanFPCDirectoryCache;
  end;

  TFindIdentifierInUsesSection_FindMissingFPCUnit = class
  private
    FUnitName: string;
    FFound: Boolean;
    FResults: TStringList;

    procedure Iterate(const AFilename: string);
  public
    constructor Create;
    destructor Destroy; override;
    function Find(const AUnitName: string; const ADirectoryCache: TCTDirectoryCache): Boolean;
    function IsInResults(const AUnitName: string): Boolean;
  end;

function ExprTypeToString(const ExprType: TExpressionType): string;
function CreateExpressionType(const Desc, SubDesc: TExpressionTypeDesc;
  const Context: TFindContext): TExpressionType;

function FindContextToString(const FindContext: TFindContext; RelativeFilename: boolean = true): string; overload;
function FindContextToString(const FindContext: PFindContext; RelativeFilename: boolean = true): string; overload;
function CreateFindContext(NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode): TFindContext;
function CreateFindContext(Params: TFindDeclarationParams): TFindContext;
function CreateFindContext(BaseTypeCache: TBaseTypeCache): TFindContext;
function FindContextAreEqual(const Context1, Context2: TFindContext): boolean;
function CompareFindContexts(const Context1, Context2: PFindContext): integer;
procedure AddFindContext(var ListOfPFindContext: TFPList;
  const NewContext: TFindContext);
function IndexOfFindContext(var ListOfPFindContext: TFPList;
  const AContext: PFindContext): integer;
procedure FreeListOfPFindContext(var ListOfPFindContext: TFPList);

function ListOfPFindContextToStr(const ListOfPFindContext: TFPList): string;
function dbgsFC(const Context: TFindContext): string;

function PredefinedIdentToExprTypeDesc(Identifier: PChar; Compiler: TPascalCompiler): TExpressionTypeDesc;
function dbgs(const Flags: TFindDeclarationFlags): string; overload;
function dbgs(const Flags: TFoundDeclarationFlags): string; overload;
function dbgs(const vat: TVariableAtomType): string; overload;
function dbgs(const Kind: TFDHelpersListKind): string; overload;


function BooleanTypesOrderList: TTypeAliasOrderList;
function IntegerTypesOrderList: TTypeAliasOrderList;
function RealTypesOrderList: TTypeAliasOrderList;
function StringTypesOrderList: TTypeAliasOrderList;

implementation

var
  FBooleanTypesOrderList: TTypeAliasOrderList;
  FIntegerTypesOrderList: TTypeAliasOrderList;
  FRealTypesOrderList: TTypeAliasOrderList;
  FStringTypesOrderList: TTypeAliasOrderList;

type

  { TFindUsedUnitReferences }

  TFindUsedUnitReferences = class
  public
    TargetTool: TFindDeclarationTool;
    TargetUnitName: string;
    ListOfPCodeXYPosition: TFPList;
    Params: TFindDeclarationParams;
    constructor Create(Tool: TFindDeclarationTool; AContextNode: TCodeTreeNode);
    destructor Destroy; override;
  end;

function dbgs(const Flags: TFindDeclarationFlags): string;
var
  Flag: TFindDeclarationFlag;
  s: string;
begin
  Result:='';
  for Flag:=Low(TFindDeclarationFlag) to High(TFindDeclarationFlag) do begin
    if Flag in Flags then begin
      if Result<>'' then
        Result:=Result+', ';
      WriteStr(s, Flag);
      Result:=Result+s;
    end;
  end;
end;

function dbgs(const Flags: TFoundDeclarationFlags): string;
var
  Flag: TFoundDeclarationFlag;
  s: string;
begin
  Result:='';
  for Flag:=Low(TFoundDeclarationFlag) to High(TFoundDeclarationFlag) do begin
    if Flag in Flags then begin
      if Result<>'' then
        Result:=Result+', ';
      WriteStr(s, Flag);
      Result:=Result+s;
    end;
  end;
end;

function dbgs(const vat: TVariableAtomType): string;
begin
  Result:=VariableAtomTypeNames[vat];
end;

function dbgs(const Kind: TFDHelpersListKind): string;
begin
  WriteStr(Result, Kind);
end;

function BooleanTypesOrderList: TTypeAliasOrderList;
begin
  if FBooleanTypesOrderList=nil then
    FBooleanTypesOrderList:=TTypeAliasOrderList.Create([
       'LongBool', 'WordBool', 'Boolean', 'ByteBool']);

  Result := FBooleanTypesOrderList;
end;

function IntegerTypesOrderList: TTypeAliasOrderList;
begin
  if FIntegerTypesOrderList=nil then
    FIntegerTypesOrderList:=TTypeAliasOrderList.Create([
       'Int64', 'QWord',
       'NativeInt', 'IntPtr', 'SizeInt', 'NativeUInt', 'UIntPtr',
       'Int32', 'Integer', 'LongInt', 'UInt32', 'Cardinal', 'LongWord',
       'Int16', 'SmallInt', 'UInt16', 'Word',
       'Int8', 'ShortInt', 'UInt8', 'Byte']);

  Result := FIntegerTypesOrderList;
end;

function RealTypesOrderList: TTypeAliasOrderList;
begin
  if FRealTypesOrderList=nil then
    FRealTypesOrderList:=TTypeAliasOrderList.Create([
       'Extended', 'Real', 'Double', 'Single']);

  Result := FRealTypesOrderList;
end;

function StringTypesOrderList: TTypeAliasOrderList;
begin
  if FStringTypesOrderList=nil then
    FStringTypesOrderList:=TTypeAliasOrderList.Create([
       'string', 'AnsiString', 'WideString', 'ShortString', 'Char', 'WideChar', 'AnsiChar']);

  Result := FStringTypesOrderList;
end;

function ListOfPFindContextToStr(const ListOfPFindContext: TFPList): string;
var
  Context: TFindContext;
  i: Integer;
begin
  if ListOfPFindContext=nil then
    Result:='nil'
  else begin
    Result:='';
    for i:=0 to ListOfPFindContext.Count-1 do begin
      Context:=PFindContext(ListOfPFindContext[i])^;
      Result:=Result+'  '+DbgsFC(Context)+LineEnding;
    end;
  end;
end;

function dbgsFC(const Context: TFindContext): string;
var
  CursorPos: TCodeXYPosition;
begin
  if Context.Tool=nil then
    Result:='nil'
  else begin
    Result:=Context.Tool.MainFilename;
    if Context.Node=nil then
      Result:=Result+'()'
    else begin
      Context.Tool.CleanPosToCaret(Context.Node.StartPos,CursorPos);
      Result:=Result+'(y='+dbgs(CursorPos.Y)+',x='+dbgs(CursorPos.X)+')';
    end;
  end;
end;

function PredefinedIdentToExprTypeDesc(Identifier: PChar;
  Compiler: TPascalCompiler): TExpressionTypeDesc;
begin
  // predefined identifiers
  if CompareIdentifiers(Identifier,'NIL')=0 then
    Result:=xtNil
  else if CompareIdentifiers(Identifier,'POINTER')=0 then
    Result:=xtPointer
  else if (CompareIdentifiers(Identifier,'TRUE')=0)
  or (CompareIdentifiers(Identifier,'FALSE')=0) then
    Result:=xtConstBoolean
  else if CompareIdentifiers(Identifier,'STRING')=0 then
    Result:=xtString
  else if CompareIdentifiers(Identifier,'SHORTSTRING')=0 then
    Result:=xtShortString
  else if CompareIdentifiers(Identifier,'ANSISTRING')=0 then
    Result:=xtAnsiString
  else if CompareIdentifiers(Identifier,'WIDESTRING')=0 then
    Result:=xtWideString
  else if CompareIdentifiers(Identifier,'UNICODESTRING')=0 then
    Result:=xtUnicodeString
  else if CompareIdentifiers(Identifier,'INT64')=0 then
    Result:=xtInt64
  else if CompareIdentifiers(Identifier,'CARDINAL')=0 then
    Result:=xtCardinal
  else if CompareIdentifiers(Identifier,'QWORD')=0 then
    Result:=xtQWord
  else if CompareIdentifiers(Identifier,'BOOLEAN')=0 then
    Result:=xtBoolean
  else if CompareIdentifiers(Identifier,'BYTEBOOL')=0 then
    Result:=xtByteBool
  else if CompareIdentifiers(Identifier,'WORDBOOL')=0 then
    Result:=xtWordBool
  else if CompareIdentifiers(Identifier,'LONGBOOL')=0 then
    Result:=xtLongBool
  else if CompareIdentifiers(Identifier,'QWORDBOOL')=0 then
    Result:=xtQWordBool
  else if CompareIdentifiers(Identifier,'CHAR')=0 then
    Result:=xtChar
  else if CompareIdentifiers(Identifier,'WIDECHAR')=0 then
    Result:=xtWideChar
  else if CompareIdentifiers(Identifier,'REAL')=0 then
    Result:=xtReal
  else if CompareIdentifiers(Identifier,'SINGLE')=0 then
    Result:=xtSingle
  else if CompareIdentifiers(Identifier,'DOUBLE')=0 then
    Result:=xtDouble
  else if CompareIdentifiers(Identifier,'EXTENDED')=0 then
    Result:=xtExtended
  else if CompareIdentifiers(Identifier,'CEXTENDED')=0 then
    Result:=xtCExtended
  else if CompareIdentifiers(Identifier,'COMP')=0 then
    Result:=xtComp
  else if CompareIdentifiers(Identifier,'FILE')=0 then
    Result:=xtFile
  else if CompareIdentifiers(Identifier,'TEXT')=0 then
    Result:=xtText
  else if CompareIdentifiers(Identifier,'SIZEOF')=0 then
    Result:=xtConstOrdInteger
  else if CompareIdentifiers(Identifier,'ORD')=0 then
    Result:=xtConstOrdInteger
  else if CompareIdentifiers(Identifier,'ASSIGNED')=0 then
    Result:=xtConstBoolean
  else if CompareIdentifiers(Identifier,'VARIANT')=0 then
    Result:=xtVariant
  else if CompareIdentifiers(Identifier,'CURRENCY')=0 then
    Result:=xtCurrency
  else if CompareIdentifiers(Identifier,'LONGINT')=0 then
    Result:=xtLongInt
  else if CompareIdentifiers(Identifier,'LONGWORD')=0 then
    Result:=xtLongWord
  else if CompareIdentifiers(Identifier,'WORD')=0 then
    Result:=xtWord
  else if CompareIdentifiers(Identifier,'LONGWORD')=0 then
    Result:=xtCardinal
  else if CompareIdentifiers(Identifier,'SMALLINT')=0 then
    Result:=xtSmallInt
  else if CompareIdentifiers(Identifier,'SHORTINT')=0 then
    Result:=xtShortInt
  else if CompareIdentifiers(Identifier,'BYTE')=0 then
    Result:=xtByte
  else if CompareIdentifiers(Identifier,'PCHAR')=0 then
    Result:=xtPChar
  else if IsWordBuiltInFunc.DoItCaseInsensitive(Identifier) then
    Result:=xtCompilerFunc
  else begin
    // compiler specific
    if (Compiler=pcPas2js) then begin
      if CompareIdentifiers(Identifier,'JSVALUE')=0 then
        exit(xtJSValue);
      if CompareIdentifiers(Identifier,'NATIVEINT')=0 then
        exit(xtNativeInt);
      if CompareIdentifiers(Identifier,'NATIVEUINT')=0 then
       exit(xtNativeUInt);
    end;
    if (Compiler=pcDelphi) then begin
      if CompareIdentifiers(Identifier,'NATIVEINT')=0 then
        exit(xtNativeInt);
      if CompareIdentifiers(Identifier,'NATIVEUINT')=0 then
       exit(xtNativeUInt);
    end;
    Result:=xtNone;
  end;
end;

function CompareTypeAliasItems(Item1, Item2: Pointer): Integer;
var
  xItem1: TTypeAliasItem absolute Item1;
  xItem2: TTypeAliasItem absolute Item2;
begin
  Result := CompareIdentifiers(PChar(xItem1.AliasName), PChar(xItem2.AliasName));
end;

function CompareTypeAliasItemString(AliasName, Item: Pointer): Integer;
var
  xAliasName: PChar absolute AliasName;
  xItem: TTypeAliasItem absolute Item;
begin
  Result := CompareIdentifiers(xAliasName, PChar(xItem.AliasName));
end;

function ExprTypeToString(const ExprType: TExpressionType): string;
begin
  Result:='Desc='+ExpressionTypeDescNames[ExprType.Desc]
         +' SubDesc='+ExpressionTypeDescNames[ExprType.SubDesc]
         +' '+FindContextToString(ExprType.Context);
end;

function CreateExpressionType(const Desc, SubDesc: TExpressionTypeDesc;
  const Context: TFindContext): TExpressionType;
begin
  Result.Desc:=Desc;
  Result.SubDesc:=SubDesc;
  Result.Context:=Context;
end;

{ TFindContext }

function FindContextToString(const FindContext: TFindContext;
  RelativeFilename: boolean): string;
var
  IdentNode: TCodeTreeNode;
begin
  Result:='';
  if FindContext.Node<>nil then begin
    Result:=Result+'Node="'+FindContext.Node.DescAsString+'"';
    IdentNode:=FindContext.Node;
    while IdentNode<>nil do begin
      if IdentNode.Desc in AllSimpleIdentifierDefinitions
        +[ctnIdentifier,ctnEnumIdentifier,ctnLabel]
      then begin
        Result:=Result+' Ident="'+
          FindContext.Tool.ExtractIdentifier(IdentNode.StartPos)+'"';
        break;
      end else if IdentNode.Desc=ctnGenericType then begin
        if IdentNode.FirstChild<>nil then
          Result:=Result+' Generic="'+
            FindContext.Tool.ExtractIdentifier(IdentNode.FirstChild.StartPos)+'"'
        else
          Result:=Result+' Generic=?';
      end else if IdentNode.Desc in [ctnProperty,ctnGlobalProperty] then begin
        Result:=Result+' PropName="'+
          FindContext.Tool.ExtractPropName(IdentNode,false)+'"';
        break;
      end else if IdentNode.Desc=ctnProcedure then begin
        Result:=Result+' Proc="'+FindContext.Tool.ExtractProcName(IdentNode,[])+'"';
        break;
      end;
      IdentNode:=IdentNode.Parent;
    end;
    if RelativeFilename then
      Result:=Result+' at "'+FindContext.Tool.CleanPosToStr(FindContext.Node.StartPos,true)+'"'
    else
      Result:=Result+' at "'+FindContext.Tool.CleanPosToRelativeStr(FindContext.Node.StartPos,'')+'"'
  end else
    Result:='nil';
end;

function FindContextToString(const FindContext: PFindContext;
  RelativeFilename: boolean): string;
begin
  if FindContext=nil then
    Result:='-'
  else
    Result:=FindContextToString(FindContext^,RelativeFilename);
end;

function CreateFindContext(NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode): TFindContext;
begin
  Result.Node:=NewNode;
  Result.Tool:=NewTool;
end;

function CreateFindContext(Params: TFindDeclarationParams): TFindContext;
begin
  Result.Node:=Params.NewNode;
  Result.Tool:=TFindDeclarationTool(Params.NewCodeTool);
end;

function CreateFindContext(BaseTypeCache: TBaseTypeCache): TFindContext;
begin
  Result.Node:=BaseTypeCache.BaseNode;
  Result.Tool:=TFindDeclarationTool(BaseTypeCache.BaseTool);
end;

function FindContextAreEqual(const Context1, Context2: TFindContext): boolean;
begin
  Result:=(Context1.Tool=Context2.Tool) and (Context1.Node=Context2.Node);
end;

function CompareFindContexts(const Context1, Context2: PFindContext): integer;
begin
  if Pointer(Context1^.Tool)>Pointer(Context2^.Tool) then
    Result:=1
  else if Pointer(Context1^.Tool)<Pointer(Context2^.Tool) then
    Result:=-1
  else if Pointer(Context1^.Node)>Pointer(Context2^.Node) then
    Result:=1
  else if Pointer(Context1^.Node)<Pointer(Context2^.Node) then
    Result:=-1
  else
    Result:=0;
end;

procedure AddFindContext(var ListOfPFindContext: TFPList;
  const NewContext: TFindContext);
var
  AddContext: PFindContext;
begin
  if ListOfPFindContext=nil then ListOfPFindContext:=TFPList.Create;
  New(AddContext);
  AddContext^:=NewContext;
  ListOfPFindContext.Add(AddContext);
end;

function IndexOfFindContext(var ListOfPFindContext: TFPList;
  const AContext: PFindContext): integer;
begin
  if ListOfPFindContext=nil then
    Result:=-1
  else begin
    Result:=ListOfPFindContext.Count-1;
    while (Result>=0)
    and (CompareFindContexts(AContext,
                             PFindContext(ListOfPFindContext[Result]))<>0)
    do
      dec(Result);
  end;
end;

procedure FreeListOfPFindContext(var ListOfPFindContext: TFPList);
var
  CurContext: PFindContext;
  i: Integer;
begin
  if ListOfPFindContext=nil then exit;
  for i:=0 to ListOfPFindContext.Count-1 do begin
    CurContext:=PFindContext(ListOfPFindContext[i]);
    Dispose(CurContext);
  end;
  ListOfPFindContext.Free;
  ListOfPFindContext:=nil;
end;

{ TGenericParamValueMapping }

constructor TGenericParamValueMapping.Create(pPrevBrother: TGenericParamValueMapping; pParam, pValue: TCodeTreeNode);
begin
  if pPrevBrother <> nil then
    pPrevBrother.NextBrother := Self;
  GenericParamNode := pParam;
  SpecializeValueNode := pValue;
end;

destructor TGenericParamValueMapping.Destroy;
begin
  if NextBrother <> nil then
    NextBrother.Free;
  inherited Destroy;
end;

{ TFindIdentifierInUsesSection_FindMissingFPCUnit }

constructor TFindIdentifierInUsesSection_FindMissingFPCUnit.Create;
begin
  inherited;
  FResults := TStringList.Create;
  FResults.CaseSensitive := True;  // Why CaseSensitive?
  {$IF FPC_FULLVERSION>=30200}FResults.UseLocale := False;{$ENDIF}
  FResults.Duplicates := dupIgnore;
  FResults.Sorted := True;
end;

destructor TFindIdentifierInUsesSection_FindMissingFPCUnit.Destroy;
begin
  FResults.Free;

  inherited Destroy;
end;

function TFindIdentifierInUsesSection_FindMissingFPCUnit.Find(
  const AUnitName: string; const ADirectoryCache: TCTDirectoryCache): Boolean;
var
  IRes: Integer;
begin
  IRes := FResults.IndexOf(AUnitName);
  if IRes>=0 then
    Exit(Boolean(PtrInt(FResults.Objects[IRes])));
  FUnitName := AUnitName;
  ADirectoryCache.IterateFPCUnitsInSet(@Iterate);
  Result := FFound;
  FResults.AddObject(AUnitName, TObject(PtrInt(Result)));
end;

function TFindIdentifierInUsesSection_FindMissingFPCUnit.IsInResults(
  const AUnitName: string): Boolean;
begin
  Result := FResults.IndexOf(AUnitName)>=0;
end;

procedure TFindIdentifierInUsesSection_FindMissingFPCUnit.Iterate(
  const AFilename: string);
begin
  FFound := FFound or SameFileName(FUnitName, ExtractFileNameOnly(AFilename));
end;

{ TTypeAliasOrderList }

constructor TTypeAliasOrderList.Create(const AliasNames: array of string);
begin
  inherited Create;

  FTree := TAVLTree.Create(@CompareTypeAliasItems);
  Add(AliasNames);
end;

procedure TTypeAliasOrderList.Add(const AliasNames: array of string);
var
  AliasName: string;
begin
  for AliasName in AliasNames do
    Add(AliasName);
end;

procedure TTypeAliasOrderList.Add(const AliasName: string);
var
  NewItem: TTypeAliasItem;
begin
  if IndexOf(AliasName) > -1 then Exit;

  NewItem := TTypeAliasItem.Create;
  NewItem.AliasName := AliasName;
  NewItem.Position := FTree.Count;
  FTree.Add(NewItem);
end;

function TTypeAliasOrderList.Compare(const AliasName1, AliasName2: string
  ): Integer;
var
  xAliasIndex1, xAliasIndex2: Integer;
begin
  xAliasIndex1 := IndexOf(AliasName1);
  xAliasIndex2 := IndexOf(AliasName2);
  if (xAliasIndex1=-1) and (xAliasIndex2=-1) then
    Exit(0)
  else if (xAliasIndex2=-1) then
    Exit(-1)
  else if (xAliasIndex1=-1) then
    Exit(1)
  else
    Result := xAliasIndex1-xAliasIndex2;
end;

function TTypeAliasOrderList.Compare(const Operand1,
  Operand2: TOperand; Tool: TFindDeclarationTool; CleanPos: Integer
  ): TOperand;
var
  xCompRes: Integer;
begin
  // first check if one of the operands is a constant -> if yes, automatically
  // return the other
  // (x := f + 1; should return always type of f)
  if (Operand1.Expr.Desc in xtAllConstTypes) and not (Operand2.Expr.Desc in xtAllConstTypes) then
    Exit(Operand2)
  else
  if (Operand2.Expr.Desc in xtAllConstTypes) and not (Operand1.Expr.Desc in xtAllConstTypes) then
    Exit(Operand1);

  // then compare base types
  xCompRes := Compare(
    Tool.FindExprTypeAsString(Operand1.Expr, CleanPos, nil),
    Tool.FindExprTypeAsString(Operand2.Expr, CleanPos, nil));
  // if base types are same, compare aliases
  if xCompRes = 0 then
    xCompRes := Compare(
      Tool.FindExprTypeAsString(Operand1.Expr, CleanPos, @Operand1.AliasType),
      Tool.FindExprTypeAsString(Operand2.Expr, CleanPos, @Operand2.AliasType));
  if xCompRes > 0 then
    Result := Operand2
  else
    Result := Operand1;
end;

procedure TTypeAliasOrderList.Delete(const Pos: Integer);
var
  xAVItem, xDelItem: TAVLTreeNode;
  xItem: TTypeAliasItem;
begin
  xDelItem := nil;
  for xAVItem in FTree do
  begin
    xItem := TTypeAliasItem(xAVItem.Data);
    if xItem.Position = Pos then
      xDelItem := xAVItem
    else if xItem.Position > Pos then
      Dec(xItem.Position);
  end;

  if xDelItem<>nil then
    FTree.FreeAndDelete(xDelItem);
end;

procedure TTypeAliasOrderList.Delete(const AliasName: string);
var
  xIndex: Integer;
begin
  xIndex := IndexOf(AliasName);
  if xIndex<0 then Exit;
  Delete(xIndex);
end;

destructor TTypeAliasOrderList.Destroy;
begin
  FTree.FreeAndClear;
  FTree.Free;

  inherited Destroy;
end;

function TTypeAliasOrderList.IndexOf(const AliasName: string): Integer;
var
  xAVNode: TAVLTreeNode;
begin
  xAVNode := FTree.FindKey(PChar(AliasName), @CompareTypeAliasItemString);
  if xAVNode<>nil then
    Result := TTypeAliasItem(xAVNode.Data).Position
  else
    Result := -1;
end;

procedure TTypeAliasOrderList.Insert(const AliasName: string; const Pos: Integer
  );
var
  xAVItem: TAVLTreeNode;
  xItem, NewItem: TTypeAliasItem;
begin
  for xAVItem in FTree do
  begin
    xItem := TTypeAliasItem(xAVItem.Data);
    if xItem.Position >= Pos then
      Inc(xItem.Position);
  end;

  NewItem := TTypeAliasItem.Create;
  NewItem.AliasName := AliasName;
  NewItem.Position := Pos;
  FTree.Add(NewItem);
end;

procedure TTypeAliasOrderList.InsertAfter(const AliasName, AfterAlias: string);
var
  xIndex: Integer;
begin
  if IndexOf(AliasName) = -1 then
  begin
    xIndex := IndexOf(AfterAlias);
    if xIndex >= 0 then
      Insert(AliasName, xIndex+1)
    else
      Add(AliasName);
  end;
end;

procedure TTypeAliasOrderList.InsertBefore(const AliasName, BeforeAlias: string
  );
var
  xIndex: Integer;
begin
  if IndexOf(AliasName) = -1 then
  begin
    xIndex := IndexOf(BeforeAlias);
    if xIndex >= 0 then
      Insert(AliasName, xIndex)
    else
      Add(AliasName);
  end;
end;

{ TFDHelpersListItem }

function TFDHelpersListItem.CalcMemSize: PtrUInt;
begin
  Result := InstanceSize;
end;

{ TFDHelpersList }

function CompareHelpersList(Item1, Item2: Pointer): Integer;
var
  I1: TFDHelpersListItem absolute Item1;
  I2: TFDHelpersListItem absolute Item2;
begin
  Result := ord(I1.ForExprType.Desc)-ord(I2.ForExprType.Desc);
  if Result<>0 then exit;
  Result := ComparePointers(I1.ForExprType.Context.Node, I2.ForExprType.Context.Node);
end;

function CompareHelpersListExprType(Item1, Item2: Pointer): Integer;
var
  I1: PExpressionType absolute Item1;
  I2: TFDHelpersListItem absolute Item2;
begin
  Result := ord(I1^.Desc)-ord(I2.ForExprType.Desc);
  if Result<>0 then exit;
  Result := ComparePointers(I1^.Context.Node, I2.ForExprType.Context.Node);
end;

procedure TFDHelpersList.AddFromList(const Tool: TFindDeclarationTool;
  const ExtList: TFDHelpersList);
  function CopyNode(ANode: TAVLTreeNode): TFDHelpersListItem;
  var
    FromNode: TFDHelpersListItem;
  begin
    FromNode := TFDHelpersListItem(ANode.Data);
    if (Kind=fdhlkDelphiHelper) and not (cmsMultiHelpers in Tool.Scanner.CompilerModeSwitches) then
      if FTree.FindKey(FromNode, @CompareHelpersList) <> nil then
        Exit(nil); //FPC & Delphi don't support duplicate class helpers!
    Result := TFDHelpersListItem.Create;
    Result.HelperContext := FromNode.HelperContext;
    Result.ForExprType := FromNode.ForExprType;
    AddChronologically(Result);
  end;
var
  Node: TAVLTreeNode;
begin
  for Node in ExtList.FTree do
    CopyNode(Node);
end;

function TFDHelpersList.CalcMemSize: PtrUInt;
var
  Node: TAVLTreeNode;
begin
  Result:=PtrUInt(InstanceSize)+PtrUInt(FTree.InstanceSize);
  for Node in FTree do
    Inc(Result, TFDHelpersListItem(Node.Data).CalcMemSize);
end;

procedure TFDHelpersList.WriteDebugReport;
var
  Node: TAVLTreeNode;
  Item: TFDHelpersListItem;
begin
  debugln(['TFDHelpersList.WriteDebugReport ',dbgs(Kind),' Count=',FTree.Count]);
  Node:=FTree.FindLowest;
  while Node<>nil do begin
    Item:=TFDHelpersListItem(Node.Data);
    debugln(['  ForExprType=[',ExprTypeToString(Item.ForExprType),']',
      ' Helper=[',FindContextToString(Item.HelperContext),']']);
    Node:=FTree.FindSuccessor(Node);
  end;
end;

procedure TFDHelpersList.AddChronologically(Item: TFDHelpersListItem);
begin
  with Item.ForExprType.Context do begin
    // Note: ObjCCategory allows multiple helpers for a class (here: ForExprType)
    // => there can be multiple items with the same key in the tree which
    //    must be chronologically sorted
    // -> append the new item rightmost by slightly increasing the key
    Node:=TCodeTreeNode(Pointer(Node)-SizeOf(Pointer));
    FTree.Add(Item);
    Node:=TCodeTreeNode(Pointer(Node)+SizeOf(Pointer));
  end;
end;

function TFDHelpersList.AddFromHelperNode(HelperNode: TCodeTreeNode;
  Tool: TFindDeclarationTool; Replace: Boolean): TFDHelpersListItem;
var
  OldKey: TAVLTreeNode;
  ExprType: TExpressionType;
begin
  //debugln(['TFDHelpersList.AddFromHelperNode Start ',Tool.CleanPosToStr(HelperNode.StartPos,true),' ',Tool.ExtractCode(HelperNode.StartPos,HelperNode.StartPos+20,[])]);
  ExprType:=Tool.FindExtendedExprOfHelper(HelperNode);
  //debugln(['TFDHelpersList.AddFromHelperNode ExprType=',ExprTypeToString(ExprType)]);

  if ExprType.Desc in xtAllIdentTypes then
  begin
    if (Kind=fdhlkDelphiHelper) and not (cmsMultiHelpers in Tool.Scanner.CompilerModeSwitches) then begin
      // class/type/record helpers only allow one helper per class
      OldKey := FTree.FindKey(@ExprType, @CompareHelpersListExprType);
      if OldKey <> nil then
      begin
        Result:=TFDHelpersListItem(OldKey.Data);
        if Replace then begin
          // keep AVLNode, it may be in use by the iterator of SearchInHelpers
          Result.HelperContext.Node := HelperNode;
          Result.HelperContext.Tool := Tool;
        end;
        exit;
      end;
    end;

    Result := TFDHelpersListItem.Create;
    Result.ForExprType := ExprType;
    Result.HelperContext.Node := HelperNode;
    Result.HelperContext.Tool := Tool;
    AddChronologically(Result);
  end else
    Result := nil;
end;

procedure TFDHelpersList.Clear;
begin
  FTree.FreeAndClear;
end;

function TFDHelpersList.Count: Integer;
begin
  Result := FTree.Count;
end;

constructor TFDHelpersList.Create(aKind: TFDHelpersListKind);
begin
  inherited Create;
  FKind:=aKind;
  FTree:=TAVLTree.Create(@CompareHelpersList);
end;

procedure TFDHelpersList.DeleteHelperNode(HelperNode: TCodeTreeNode;
  Tool: TFindDeclarationTool);
var
  OldKey: TAVLTreeNode;
  ExprType: TExpressionType;
begin
  ExprType:=Tool.FindExtendedExprOfHelper(HelperNode);

  if ExprType.Desc in xtAllIdentTypes then
  begin
    OldKey := FTree.FindKey(@ExprType, @CompareHelpersListExprType);
    if OldKey <> nil then
      FTree.FreeAndDelete(OldKey);
  end;
end;

destructor TFDHelpersList.Destroy;
begin
  Clear;
  FTree.Free;
  inherited Destroy;
end;

function TFDHelpersList.IterateFromClassNode(ClassNode: TCodeTreeNode;
  Tool: TFindDeclarationTool; out HelperContext: TFindContext; out
  Iterator: TAVLTreeNode): boolean;
var
  ExprType: TExpressionType;
begin
  ExprType.Desc:=xtContext;
  ExprType.Context.Node:=ClassNode;
  ExprType.Context.Tool:=Tool;
  Iterator := FTree.FindRightMostKey(@ExprType, @CompareHelpersListExprType);
  if Iterator=nil then exit(false);
  HelperContext:=TFDHelpersListItem(Iterator.Data).HelperContext;
  Result:=true;
end;

function TFDHelpersList.GetNext(out HelperContext: TFindContext;
  var Iterator: TAVLTreeNode): boolean;
var
  NextNode: TAVLTreeNode;
begin
  NextNode:=FTree.FindPrecessor(Iterator);
  if (NextNode=nil) or (CompareHelpersList(NextNode.Data,Iterator.Data)<>0) then
    exit(false);
  // found an older compatible helper
  Iterator:=NextNode;
  HelperContext:=TFDHelpersListItem(Iterator.Data).HelperContext;
  Result:=true;
end;

function TFDHelpersList.FindFromExprType(const ExprType: TExpressionType
  ): TFindContext;
var
  Node: TAVLTreeNode;
begin
  Node := FTree.FindRightMostKey(@ExprType, @CompareHelpersListExprType);
  if Node<>nil then
    Result := TFDHelpersListItem(Node.Data).HelperContext
  else
    Result := CleanFindContext;
end;

constructor TFindUsedUnitReferences.Create(Tool: TFindDeclarationTool; AContextNode: TCodeTreeNode);
begin
  inherited Create;
  Params:=TFindDeclarationParams.Create(Tool, AContextNode);
end;

destructor TFindUsedUnitReferences.Destroy;
begin
  FreeAndNil(Params);
  inherited Destroy;
end;

{ TFindDeclarationTool }

function TFindDeclarationTool.FindDeclaration(const CursorPos: TCodeXYPosition;
  out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
var
  NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode;
begin
  Result:=FindDeclaration(CursorPos,DefaultFindSmartFlags,NewTool,NewNode,
                          NewPos,NewTopLine);
end;

function TFindDeclarationTool.FindMainDeclaration(
  const CursorPos: TCodeXYPosition; out NewPos: TCodeXYPosition; out
  NewTopLine: integer): boolean;
var
  NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode;
begin
  Result:=FindDeclaration(CursorPos,[fsfFindMainDeclaration,fsfSearchSourceName],NewTool,NewNode,
                          NewPos,NewTopLine);
end;

function TFindDeclarationTool.FindDeclarationOfIdentifier(
  const CursorPos: TCodeXYPosition; Identifier: PChar;
  out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
var
  CleanCursorPos: integer;
  CursorNode: TCodeTreeNode;
  Params: TFindDeclarationParams;
begin
  Result:=false;
  ActivateGlobalWriteLock;
  Params:=nil;
  try
    // build code tree
    {$IFDEF CTDEBUG}
    DebugLn('TFindDeclarationTool.FindDeclarationOfIdentifier A CursorPos=X',dbgs(CursorPos.X),',Y',dbgs(CursorPos.Y));
    {$ENDIF}
    BuildTreeAndGetCleanPos(trTillCursor,lsrEnd,CursorPos,CleanCursorPos,
                            [btSetIgnoreErrorPos]);
    {$IFDEF CTDEBUG}
    DebugLn('TFindDeclarationTool.FindDeclarationOfIdentifier B CleanCursorPos=',dbgs(CleanCursorPos));
    {$ENDIF}
    // find CodeTreeNode at cursor
    CursorNode:=BuildSubTreeAndFindDeepestNodeAtPos(CleanCursorPos,true);
    // search
    Params:=TFindDeclarationParams.Create(Self, CursorNode);
    Params.SetIdentifier(Self,Identifier,nil);
    Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound,
                   fdfExceptionOnPredefinedIdent,
                   fdfTopLvlResolving,fdfSearchInAncestors,fdfSearchInHelpers,
                   fdfIgnoreCurContextNode];
    FindIdentifierInContext(Params);
    // convert result to nice source position
    Params.PrettifyResult;
    Params.ConvertResultCleanPosToCaretPos;
    NewPos:=Params.NewPos;
    NewTopLine:=Params.NewTopLine;
    Result:=true;
  finally
    Params.Free;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.FindDeclaration(const CursorPos: TCodeXYPosition;
  SearchSmartFlags: TFindSmartFlags; out NewExprType: TExpressionType; out
  NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine,
  BlockBottomLine: integer): boolean;
var
  CleanCursorPos: integer;
  CursorNode, ClassNode: TCodeTreeNode;
  DirectSearch, SkipChecks, SearchForward: boolean;

  function CheckIfNodeIsForwardDefinedClass(ANode: TCodeTreeNode;
    ATool: TFindDeclarationTool): Boolean;
  var
    TypeNode: TCodeTreeNode;
  begin
    Result := False;
    if not (ANode.Desc in [ctnTypeDefinition,ctnGenericType]) then exit;
    TypeNode:=ATool.FindTypeNodeOfDefinition(ANode);
    if (TypeNode<>nil)
    and (TypeNode.Desc in AllClasses)
    and ((TypeNode.SubDesc and ctnsForwardDeclaration)>0)
    then
      Result := True;
  end;

  procedure CheckIfCursorOnAForwardDefinedClass;
  begin
    if SkipChecks then exit;
    if CheckIfNodeIsForwardDefinedClass(CursorNode, Self) then
    begin
      DirectSearch:=true;
      SearchForward:=true;
      SkipChecks:=true;
    end;
  end;

  procedure CheckIfCursorInClassNode;
  begin
    if SkipChecks then exit;
    ClassNode:=CursorNode;
    while (ClassNode<>nil)
    and (not (ClassNode.Desc in AllClasses))
    do
      ClassNode:=ClassNode.Parent;
    if ClassNode=nil then exit;
    // cursor is in class/object/class interface definition
    if (ClassNode.SubDesc and ctnsForwardDeclaration)>0 then exit;
    // parse class and build CodeTreeNodes for all properties/methods
    CursorNode:=FindDeepestNodeAtPos(ClassNode,CleanCursorPos,true);
    if CursorNode.GetNodeOfType(ctnClassInheritance)=nil then exit;
    // identifier is an ancestor/interface identifier
    CursorNode:=ClassNode.Parent;
    DirectSearch:=true;
    SkipChecks:=true;
  end;

  procedure CheckIfCursorInProcNode;
  var IsMethod: boolean;
  begin
    if SkipChecks then exit;
    if CursorNode.Desc=ctnProcedureHead then
      CursorNode:=CursorNode.Parent;
    if CursorNode.Desc<>ctnProcedure then exit;
    BuildSubTreeForProcHead(CursorNode);
    CursorNode:=FindDeepestNodeAtPos(CursorNode,CleanCursorPos,true);
    // check if cursor on proc name
    if (CursorNode.Desc=ctnProcedureHead)
    and (CleanCursorPos>=CursorNode.StartPos) then begin
      MoveCursorToNodeStart(CursorNode);
      ReadNextAtom;
      IsMethod:=false;
      if AtomIsIdentifier then begin
        ReadNextAtom;
        if AtomIsChar('.') then begin
          ReadNextAtom;
          ReadNextAtom;
          IsMethod:=true;
        end;
      end;
      if (CurPos.StartPos>CleanCursorPos) and (not IsMethod) then begin
        // cursor on proc name
        // -> ignore proc name and search overloaded identifier
        DirectSearch:=true;
        SkipChecks:=true;
      end;
    end;
    if CursorNode.Desc=ctnProcedureHead then
      CursorNode:=CursorNode.Parent;
  end;

  procedure CheckIfCursorInPropertyNode;
  begin
    if SkipChecks then exit;
    if not (CursorNode.Desc in [ctnProperty,ctnGlobalProperty]) then exit;
    MoveCursorToNodeStart(CursorNode);
    if (CursorNode.Desc=ctnProperty) then begin
      ReadNextAtom; // read 'property'
      if UpAtomIs('CLASS') then ReadNextAtom;
    end;
    ReadNextAtom; // read property name
    if CleanCursorPos<CurPos.EndPos then begin
      DirectSearch:=true;
      SkipChecks:=true;
    end;
  end;
  
  function FindSourceName(ACode: TCodeBuffer): boolean;
  var
    NamePos: TAtomPosition;
  begin
    Result:=false;
    NewExprType :=CleanExpressionType;
    if Assigned(FOnGetCodeToolForBuffer) then
      NewExprType.Context.Tool:=FOnGetCodeToolForBuffer(Self,ACode,false);
    if NewExprType.Context.Tool=nil then exit;
    NewExprType.Context.Tool.BuildTree(lsrSourceName);
    if not NewExprType.Context.Tool.GetSourceNamePos(NamePos) then exit;
    NewExprType.Context.Node:=NewExprType.Context.Tool.Tree.Root;
    if not NewExprType.Context.Tool.JumpToCleanPos(NamePos.StartPos,NamePos.StartPos,
                                  NamePos.StartPos,NewPos,NewTopLine,BlockTopLine,BlockBottomLine,false)
    then exit;
    Result:=true;
    NewExprType.Desc:=xtContext;
  end;

  {$IFDEF VerboseFindDeclarationFail}
  procedure WriteFailReport;
  var
    CodePos: integer;
    LinkIndex: Integer;
    Link: TSourceLink;
    i: Integer;
    SrcCodes: TAVLTree;
    SrcNode: TAVLTreeNode;
  begin
    debugln(['TFindDeclarationTool.FindDeclaration failed',
      ' CursorPos=X=',CursorPos.X,',Y=',CursorPos.Y,
      ',File=',CursorPos.Code.Filename,
      ',LineCount=',CursorPos.Code.LineCount]);
    if CursorPos.Y<=CursorPos.Code.LineCount then
      debugln([' Line="',dbgstr(CursorPos.Code.GetLine(CursorPos.Y-1),1,CursorPos.X-1),'|',dbgstr(CursorPos.Code.GetLine(CursorPos.Y-1),CursorPos.X,1000),'"']);
    if CleanCursorPos>0 then begin
      debugln([ ' CleanCursorPos=',CleanCursorPos,' CleanCode="',dbgstr(Src,CleanCursorPos-40,40),'|',dbgstr(Src,CleanCursorPos,30),'"']);
    end;
    CursorPos.Code.LineColToPosition(CursorPos.Y,CursorPos.X,CodePos);
    LinkIndex:=Scanner.LinkIndexAtCursorPos(CodePos,CursorPos.Code);
    dbgout([' CodePos=',CodePos,' LinkIndex=',LinkIndex]);
    if LinkIndex>=0 then begin
      Link:=Scanner.Links[LinkIndex];
      dbgout([',CleanedPos=',Link.CleanedPos,',Size=',Scanner.LinkSize(LinkIndex),',SrcPos=',Link.SrcPos,',Kind=',dbgs(Link.Kind),',CodeSame=',Link.Code=Pointer(CursorPos.Code)]);
    end else begin
      dbgout([' LinkCount=',Scanner.LinkCount]);
      i:=0;
      while (i<Scanner.LinkCount-1) do begin
        Link:=Scanner.Links[i];
        if Link.Code=Pointer(CursorPos.Code) then begin
          if LinkIndex<0 then
            dbgout([', First Link of Code: ID=',i,',CleanedPos=',Link.CleanedPos,',Size=',Scanner.LinkSize(i),',SrcPos=',Link.SrcPos,',Kind=',dbgs(Link.Kind)]);
          LinkIndex:=i;
        end;
        inc(i);
      end;
      if LinkIndex>=0 then begin
        Link:=Scanner.Links[LinkIndex];
        dbgout([', Last Link of Code: ID=',LinkIndex,',CleanedPos=',Link.CleanedPos,',Size=',Scanner.LinkSize(i),',SrcPos=',Link.SrcPos,',Kind=',dbgs(Link.Kind)]);
      end else begin
        SrcCodes:=Scanner.CreateTreeOfSourceCodes;
        try
          for SrcNode in SrcCodes do begin
            dbgout(',LinkFile="',TCodeBuffer(SrcNode.Data).Filename,'"');
          end;
        finally
          SrcCodes.Free;
        end;
      end;
    end;
    debugln;
  end;
  {$ENDIF}

var
  IdentStartPos: Integer;

  function TrySkipClassForward(Params: TFindDeclarationParams): Boolean;
  var
    ForwardXY, NewSkipPos: TCodeXYPosition;
    NewSkipExprType: TExpressionType;
    NewSkipTopLine, NewSkipCleanPos, NewSkipBlockTopLine,
      NewSkipBlockBottomLine: integer;
  begin
    // if we skip forward class definitions and we found one -> proceed search!
    Result :=
         (fsfSkipClassForward in SearchSmartFlags)
      and CheckIfNodeIsForwardDefinedClass(Params.NewNode, Params.NewCodeTool)
      and Params.NewCodeTool.CleanPosToCaret(Params.NewNode.StartPos, ForwardXY)
      and Params.NewCodeTool.FindDeclaration(ForwardXY, SearchSmartFlags-[fsfSkipClassForward],
        NewSkipExprType, NewSkipPos, NewSkipTopLine, NewSkipBlockTopLine, NewSkipBlockBottomLine);

    if Result
      and (NewSkipExprType.Desc=xtContext)
      and (NewSkipExprType.Context.Tool=Self)
      and (NewSkipExprType.Context.Tool.CaretToCleanPos(NewSkipPos, NewSkipCleanPos)=0)
      and (IdentStartPos = GetIdentStartPosition(Src,NewSkipCleanPos))
    then begin
      // the old startpos and the skipclass startpos are the same -> we want to
      // jump to the forward declaration because we jump from the actual one
      Result := False;
    end;

    if Result then
    begin
      NewExprType := NewSkipExprType;
      NewPos := NewSkipPos;
      NewTopLine := NewSkipTopLine;
      BlockTopLine := NewSkipBlockTopLine;
      BlockBottomLine := NewSkipBlockBottomLine;
    end;
  end;

var
  CleanPosInFront: integer;
  CursorAtIdentifier: boolean;
  IdentifierStart: PChar;
  LineRange: TLineRange;
  Params: TFindDeclarationParams;
begin
  Result:=false;
  NewExprType:=CleanExpressionType;
  NewPos.X:=-1;
  NewPos.Y:=-1;
  SkipChecks:=false;
  // check cursor in source
  if (CursorPos.Y<1) or (CursorPos.Y>CursorPos.Code.LineCount)
  or (CursorPos.X<1) then begin
    {$IFDEF VerboseFindDeclarationFail}
    debugln(['TFindDeclarationTool.FindDeclaration invalid CursorPos=X=',CursorPos.X,' Y=',CursorPos.Y,' File=',CursorPos.Code.Filename,' LineCount=',CursorPos.Code.LineCount]);
    {$ENDIF}
    exit;
  end;
  CursorPos.Code.GetLineRange(CursorPos.Y-1,LineRange);
  if LineRange.EndPos-LineRange.StartPos+1<CursorPos.X then begin
    // beyond end of line
    {$IFDEF VerboseFindDeclarationFail}
    debugln(['TFindDeclarationTool.FindDeclaration beyond end of line: CursorPos=X=',CursorPos.X,' Y=',CursorPos.Y,' File=',CursorPos.Code.Filename,' LineLen=',LineRange.EndPos-LineRange.StartPos]);
    {$ENDIF}
    exit;
  end;

  CleanCursorPos:=0;
  ActivateGlobalWriteLock;
  try
    // build code tree
    {$IFDEF CTDEBUG}
    DebugLn('TFindDeclarationTool.FindDeclaration A CursorPos=X',dbgs(CursorPos.X),',Y',dbgs(CursorPos.Y),' ',CursorPos.Code.Filename);
    debugln(['TFindDeclarationTool.FindDeclaration B ',dbgtext(copy(CursorPos.Code.GetLine(CursorPos.Y),1,CursorPos.X-1)),'|',dbgtext(copy(CursorPos.Code.GetLine(CursorPos.Y),CursorPos.X,120))]);
    {$ENDIF}
    BuildTreeAndGetCleanPos(trTillCursor,lsrEnd,CursorPos,CleanCursorPos,
                  [btSetIgnoreErrorPos,btCursorPosOutAllowed]);
    {$IFDEF CTDEBUG}
    debugLn('TFindDeclarationTool.FindDeclaration B CleanCursorPos=',dbgs(CleanCursorPos));
    debugln(['TFindDeclarationTool.FindDeclaration C ',dbgtext(copy(Src,CleanCursorPos-30,30)),'|',dbgtext(copy(Src,CleanCursorPos,30))]);
    {$ENDIF}

    // find CodeTreeNode at cursor
    if (Tree.Root<>nil) and (Tree.Root.StartPos<=CleanCursorPos) then begin
      CursorNode:=BuildSubTreeAndFindDeepestNodeAtPos(CleanCursorPos,true);
      if (fsfFindMainDeclaration in SearchSmartFlags)
      and CleanPosIsDeclarationIdentifier(CleanCursorPos,CursorNode)
      then begin
        //DebugLn(['TFindDeclarationTool.FindDeclaration CleanPosIsDeclarationIdentifier']);
        NewExprType.Desc:=xtContext;
        NewExprType.Context.Tool:=Self;
        NewExprType.Context.Node:=CursorNode;
        CleanCursorPos:=GetIdentStartPosition(Src,CleanCursorPos);
        if CursorNode.Desc=ctnVarDefinition then begin
          // if this is a parameter, try to find the corresponding declaration
          NewExprType.Context.Node:=FindCorrespondingProcParamNode(NewExprType.Context.Node);
          if (NewExprType.Context.Node<>nil) and (NewExprType.Context.Node.StartPos<CursorNode.StartPos) then
            CleanCursorPos:=NewExprType.Context.Node.StartPos
          else
            NewExprType.Context.Node:=CursorNode;
        end;
        if (CursorNode.Desc=ctnProcedureHead)
        and (NodeIsMethodBody(CursorNode.Parent)) then begin
          // if this is a procedure body, try to find the corresponding declaration
          NewExprType.Context.Node:=FindCorrespondingProcNode(CursorNode.Parent);
          if (NewExprType.Context.Node<>nil) and (NewExprType.Context.Node.Desc=ctnProcedure) then
            NewExprType.Context.Node:=NewExprType.Context.Node.FirstChild;
          if (NewExprType.Context.Node<>nil) and (NewExprType.Context.Node.StartPos<CursorNode.StartPos) then begin
            CleanCursorPos:=NewExprType.Context.Node.StartPos;
          end
          else
            NewExprType.Context.Node:=CursorNode;
        end;

        Result:=JumpToCleanPos(CleanCursorPos,CleanCursorPos,CleanCursorPos,
                               NewPos,NewTopLine,BlockTopLine,BlockBottomLine,false);
        {$IFDEF VerboseFindDeclarationFail}
        if not Result then begin
          debugln(['TFindDeclarationTool.FindDeclaration cursor at declaration, but JumpToCleanPos failed']);
        end;
        {$ENDIF}
        exit;
      end;
      CleanPosInFront:=CursorNode.StartPos;
    end else begin
      CleanPosInFront:=1;
      CursorNode:=nil;
    end;
    if IsIncludeDirectiveAtPos(CleanCursorPos,CleanPosInFront,NewPos.Code)
    then begin
      // include directive
      //DebugLn(['TFindDeclarationTool.FindDeclaration IsIncludeDirectiveAtPos']);
      NewPos.X:=1;
      NewPos.Y:=1;
      NewTopLine:=1;
      BlockTopLine:=NewPos.Y;
      BlockBottomLine:=NewPos.Y;
      NewExprType.Desc:=xtContext;
      NewExprType.Context.Node:=nil;
      NewExprType.Context.Tool:=Self;
      Result:=(fsfIncludeDirective in SearchSmartFlags);
      {$IFDEF VerboseFindDeclarationFail}
      if not Result then begin
        debugln(['TFindDeclarationTool.FindDeclaration cursor at include directive and fsfIncludeDirective not set']);
      end;
      {$ENDIF}
      exit;
    end;
    if CursorNode=nil then begin
      // raise exception
      RaiseCursorOutsideCode(CursorPos);
    end;
    {$IFDEF CTDEBUG}
    DbgOut(['TFindDeclarationTool.FindDeclaration D CursorNode=',NodeDescriptionAsString(CursorNode.Desc),' HasChildren=',dbgs(CursorNode.FirstChild<>nil)]);
    if CursorNode.Parent<>nil then
      DbgOut(' Parent="',CursorNode.Parent.DescAsString,'"');
    Debugln;
    {$ENDIF}
    if (CursorNode.Desc = ctnUseUnitNamespace) then begin
      NewExprType.Desc:=xtContext;
      NewExprType.Context.Node:=CursorNode;
      NewExprType.Context.Tool:=Self;
      CleanPosToCaret(CursorNode.StartPos, NewPos);
      NewTopLine := NewPos.Y;
      BlockTopLine := NewTopLine;
      CleanPosToCaret(CursorNode.EndPos, NewPos);
      BlockBottomLine := NewPos.Y;
      Result := True;
      Exit;
    end else
    if (CursorNode.Desc in [ctnUsesSection,ctnUseUnitClearName]) then begin
      // in uses section
      //DebugLn(['TFindDeclarationTool.FindDeclaration IsUsesSection']);
      Result:=FindDeclarationInUsesSection(CursorNode,CleanCursorPos,
                                           NewPos,NewTopLine);
      BlockTopLine:=NewPos.Y;
      BlockBottomLine:=NewPos.Y;
      NewExprType:=CleanExpressionType;
      {$IFDEF VerboseFindDeclarationFail}
      if not Result then begin
        debugln(['TFindDeclarationTool.FindDeclaration cursor in uses and FindDeclarationInUsesSection failed']);
      end;
      {$ENDIF}
      if Result and (fsfSearchSourceName in SearchSmartFlags) then begin
        Result:=FindSourceName(NewPos.Code);
        {$IFDEF VerboseFindDeclarationFail}
        if not Result then begin
          debugln(['TFindDeclarationTool.FindDeclaration cursor in uses and FindSourceName failed']);
        end;
        {$ENDIF}
      end;
      exit;
    end;
    DirectSearch:=false;
    SearchForward:=false;
    CheckIfCursorOnAForwardDefinedClass;
    CheckIfCursorInClassNode;
    CheckIfCursorInProcNode;
    CheckIfCursorInPropertyNode;
    // set cursor on identifier
    MoveCursorToCleanPos(CleanCursorPos);
    GetIdentStartEndAtPosition(Src,CleanCursorPos,
                               CurPos.StartPos,CurPos.EndPos);
    IdentStartPos:=CurPos.StartPos;
    CursorAtIdentifier:=CurPos.StartPos<CurPos.EndPos;
    if CursorAtIdentifier then
      IdentifierStart:=@Src[CurPos.StartPos]
    else
      IdentifierStart:=PChar(Src);
    if CursorAtIdentifier then begin
      // find declaration of identifier
      Params:=TFindDeclarationParams.Create(Self, CursorNode);
      try
        Params.SetIdentifier(Self,IdentifierStart,@CheckSrcIdentifier);
        Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound,
                       fdfExceptionOnPredefinedIdent,
                       fdfTopLvlResolving,fdfSearchInAncestors,fdfSearchInHelpers];
        if fsfSkipClassForward in SearchSmartFlags then
          Include(Params.Flags,fdfSkipClassForward);
        if not DirectSearch then begin
          Result:=FindDeclarationOfIdentAtParam(Params, NewExprType);
          {$IFDEF VerboseFindDeclarationFail}
          if not Result then begin
            debugln(['TFindDeclarationTool.FindDeclaration FindDeclarationOfIdentAtParam failed']);
          end;
          {$ENDIF}
          if Result and TrySkipClassForward(Params) then
            Exit(True);
        end else begin
          Include(Params.Flags,fdfIgnoreCurContextNode);
          if SearchForward then
            Include(Params.Flags,fdfSearchForward);
          //debugln(['TFindDeclarationTool.FindDeclaration Flags=',dbgs(Params.Flags),' FindIdentifierInContext ...']);
          Result:=FindIdentifierInContext(Params);
          if Result then
          begin
            if TrySkipClassForward(Params) then
              Exit(True);

            NewExprType.Desc:=xtContext;
            NewExprType.Context.Node:=Params.NewNode;
            NewExprType.Context.Tool:=Params.NewCodeTool;
          end;
          {$IFDEF VerboseFindDeclarationFail}
          if not Result then begin
            debugln(['TFindDeclarationTool.FindDeclaration FindIdentifierInContext failed']);
          end;
          {$ENDIF}
        end;
        if Result then begin
          Params.PrettifyResult;
          Params.ConvertResultCleanPosToCaretPos;
          NewPos:=Params.NewPos;
          NewTopLine:=Params.NewTopLine;
          BlockTopLine:=NewPos.Y;
          BlockBottomLine:=NewPos.Y;
          if (NewExprType.Desc=xtContext) and
             ((NewPos.Code=nil) or (NewExprType.Context.Node=nil))
          then begin
            if Params.IdentifierTool.IsPCharInSrc(Params.Identifier) then
              Params.IdentifierTool.MoveCursorToCleanPos(Params.Identifier)
            else
              MoveCursorToCleanPos(CleanCursorPos);
            Params.IdentifierTool.RaiseExceptionFmt(20170421200024,ctsIdentifierNotFound,
                                          [GetIdentifier(Params.Identifier)]);
          end;
        end;
      finally
        Params.Free;
      end;
    end else begin
      // find declaration of non identifier, e.g. numeric label
      {$IFDEF VerboseFindDeclarationFail}
      if not Result then begin
        debugln(['TFindDeclarationTool.FindDeclaration cursor at non identifier']);
      end;
      {$ENDIF}
    end;
  finally
    ClearIgnoreErrorAfter;
    DeactivateGlobalWriteLock;
    {$IFDEF VerboseFindDeclarationFail}
    WriteFailReport;
    {$ENDIF}
  end;
end;

function TFindDeclarationTool.FindDeclaration(const CursorPos: TCodeXYPosition;
  SearchSmartFlags: TFindSmartFlags; out NewExprType: TExpressionType; out
  NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
var
  BlockTopLine, BlockBottomLine: integer;
begin
  Result := FindDeclaration(CursorPos, SearchSmartFlags, NewExprType, NewPos,
    NewTopLine, BlockTopLine, BlockBottomLine);
end;

function TFindDeclarationTool.FindDeclaration(const CursorPos: TCodeXYPosition;
  SearchSmartFlags: TFindSmartFlags; out NewTool: TFindDeclarationTool; out
  NewNode: TCodeTreeNode; out NewPos: TCodeXYPosition; out NewTopLine,
  BlockTopLine, BlockBottomLine: integer): boolean;
var
  ExprType: TExpressionType;
begin
  Result := FindDeclaration(CursorPos, SearchSmartFlags, ExprType,
                            NewPos, NewTopLine, BlockTopLine, BlockBottomLine)
      and (NewPos.X >= 0) and (NewPos.Y >= 0);
  if Result then begin
    NewTool := ExprType.Context.Tool;
    NewNode := ExprType.Context.Node;
  end else begin
    NewTool := nil;
    NewNode := nil;
  end;
end;

function TFindDeclarationTool.FindDeclaration(const CursorPos: TCodeXYPosition;
  SearchSmartFlags: TFindSmartFlags; out NewTool: TFindDeclarationTool; out
  NewNode: TCodeTreeNode; out NewPos: TCodeXYPosition; out NewTopLine: integer
  ): boolean;
var
  BlockTopLine, BlockBottomLine: integer;
begin
  Result := FindDeclaration(CursorPos, SearchSmartFlags, NewTool, NewNode, NewPos,
    NewTopLine, BlockTopLine, BlockBottomLine);
end;

function TFindDeclarationTool.FindDeclarationInInterface(
  const Identifier: string; out NewPos: TCodeXYPosition; out NewTopLine,
  BlockTopLine, BlockBottomLine: integer): boolean;
var
  Node: TCodeTreeNode;
begin
  Result:=false;
  if Identifier='' then exit;
  Node:=FindDeclarationNodeInInterface(Identifier,true);
  if Node<>nil then
    Result:=JumpToNode(Node,NewPos,NewTopLine,BlockTopLine,BlockBottomLine,false);
end;

function TFindDeclarationTool.FindDeclarationWithMainUsesSection(
  const Identifier: string; out NewPos: TCodeXYPosition; out NewTopLine: integer
  ): boolean;
var
  UsesNode: TCodeTreeNode;
  Params: TFindDeclarationParams;
begin
  Result:=false;
  if Identifier='' then exit;
  BuildTree(lsrMainUsesSectionEnd);
  UsesNode:=FindMainUsesNode;
  if UsesNode=nil then exit;

  Params:=TFindDeclarationParams.Create(Self, FindLastNode);
  ActivateGlobalWriteLock;
  try
    Params.Flags:=[fdfExceptionOnNotFound];
    Params.SetIdentifier(Self,PChar(Pointer(Identifier)),nil);
    if FindIdentifierInUsesSection(UsesNode,Params,True) then begin
      if Params.NewNode=nil then exit;
      Result:=Params.NewCodeTool.JumpToNode(Params.NewNode,NewPos,
                                            NewTopLine,false);
    end;
  finally
    Params.Free;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.FindDeclarationOfPropertyPath(
  const PropertyPath: string; out NewContext: TFindContext;
  IgnoreTypeLess: boolean): boolean;
// example: PropertyPath='TForm1.Font.Color'
var
  StartPos: Integer;

  function GetNextIdentifier: string;
  var
    EndPos: LongInt;
  begin
    EndPos:=StartPos;
    while (EndPos<=length(PropertyPath)) and (IsIdentChar[PropertyPath[EndPos]])
    do inc(EndPos);
    if (EndPos<=length(PropertyPath)) and (PropertyPath[EndPos]<>'.') then
      Result:=''
    else begin
      Result:=copy(PropertyPath,StartPos,EndPos-StartPos);
      StartPos:=EndPos+1;
    end;
  end;

var
  Params: TFindDeclarationParams;
  Identifier: String;
  IsLastProperty: Boolean;
  Context: TFindContext;
  IsTypeLess: Boolean;
  Node: TCodeTreeNode;
begin
  Result:=false;
  NewContext:=CleanFindContext;
  //DebugLn('TFindDeclarationTool.FindDeclarationOfPropertyPath ',MainFilename,' PropertyPath="',PropertyPath,'"');
  if PropertyPath='' then exit;
  ActivateGlobalWriteLock;
  Params:=TFindDeclarationParams.Create(Self, FindLastNode);
  try
    BuildTree(lsrInitializationStart);

    //DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath ',Src]);

    // first search the class/variable in the interface
    StartPos:=1;
    Identifier:=GetNextIdentifier;
    if Identifier='' then exit;
    Context.Tool:=Self;
    Context.Node:=FindDeclarationNodeInInterface(Identifier,true);
    if Context.Node=nil then begin
      DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath Identifier not found in interface ',Identifier]);
      exit;
    end;
    Context:=FindBaseTypeOfNode(Params,Context.Node);
    if Context.Node=nil then begin
      DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath context not found']);
      exit;
    end;
    // then search the properties
    repeat
      Identifier:=GetNextIdentifier;
      IsLastProperty:=StartPos>length(PropertyPath);
      //DebugLn('TFindDeclarationTool.FindDeclarationOfPropertyPath Context=',Context.Node.DescAsString,' Identifier=',Identifier);
      if Identifier='' then begin
        NewContext:=Context;
        exit(true);
      end;
      if Context.Node.Desc=ctnSetType then begin
        // set
        if not IsLastProperty then exit;
        Node:=Context.Node.FirstChild;
        if (Node=nil) or (Node.Desc<>ctnIdentifier) then exit;

        // search enum type
        Params.Flags:=[fdfExceptionOnNotFound,fdfSearchInParentNodes,fdfFindChildren];
        Params.SetIdentifier(Self,@Context.Tool.Src[Node.StartPos],nil);
        Params.ContextNode:=Node;
        if not Context.Tool.FindIdentifierInContext(Params) then exit;

        Context.Tool:=Params.NewCodeTool;
        Context.Node:=Params.NewNode;
        // search enum base type
        Context:=Context.Tool.FindBaseTypeOfNode(Params,Context.Node);
        //debugln(['TFindDeclarationTool.FindDeclarationOfPropertyPath enum base type ',FindContextToString(Context)]);
        if (Context.Node=nil) or (Context.Node.Desc<>ctnEnumerationType) then
          exit;
        // search enum
        Node:=Context.Node.FirstChild;
        while Node<>nil do begin
          if CompareIdentifiers(PChar(Pointer(Identifier)),@Context.Tool.Src[Node.StartPos])=0
          then begin
            //debugln(['TFindDeclarationTool.FindDeclarationOfPropertyPath identifier=',Identifier]);
            NewContext.Tool:=Context.Tool;
            NewContext.Node:=Node;
            //debugln(['TFindDeclarationTool.FindDeclarationOfPropertyPath FOUND ',FindContextToString(NewContext)]);
            exit(true);
          end;
          Node:=Node.NextBrother;
        end;
        exit;
      end;

      if (not (Context.Node.Desc in AllClasses)) then begin
        debugln(['TFindDeclarationTool.FindDeclarationOfPropertyPath failed Context=',Context.Node.DescAsString]);
        exit;
      end;
      //DebugLn('TFindDeclarationTool.FindDeclarationOfPropertyPath Identifier="',identifier,'"');
      Params.Flags:=[fdfExceptionOnNotFound,fdfSearchInAncestors,fdfSearchInHelpers];
      Params.SetIdentifier(Self,PChar(Pointer(Identifier)),nil);
      Params.ContextNode:=Context.Node;
      if IsLastProperty then
        Params.Flags:=Params.Flags+[fdfFindVariable]
      else
        Params.Flags:=Params.Flags-[fdfFindVariable]+[fdfFunctionResult,fdfFindChildren];
      if not Context.Tool.FindIdentifierInContext(Params) then exit;
      Context.Tool:=Params.NewCodeTool;
      Context.Node:=Params.NewNode;
      if Context.Node=nil then exit;
      if IsLastProperty then begin
        if IgnoreTypeLess then begin
          repeat
            IsTypeLess:=false;
            if (Context.Node.Desc=ctnProperty)
            and Context.Tool.PropNodeIsTypeLess(Context.Node) then
              IsTypeLess:=true;
            if not IsTypeLess then break;
            //DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath has no type, searching next ...']);
            Params.SetIdentifier(Self,PChar(Pointer(Identifier)),nil);
            Params.ContextNode:=Context.Tool.FindClassOrInterfaceNode(Context.Node);
            if Params.ContextNode=nil then
              Params.ContextNode:=Context.Node;
            Params.Flags:=[fdfExceptionOnNotFound,fdfSearchInAncestors,fdfSearchInHelpers,
                           fdfFindVariable,fdfIgnoreCurContextNode];
            //DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath ',Context.Tool.MainFilename,' ',Params.ContextNode.DescAsString,' ',Context.Tool.CleanPosToStr(Params.ContextNode.StartPos)]);
            if not Context.Tool.FindIdentifierInContext(Params) then exit;
            Context.Tool:=Params.NewCodeTool;
            Context.Node:=Params.NewNode;
            if Context.Node=nil then exit;
          until false;
        end;
        //DebugLn(['TFindDeclarationTool.FindDeclarationOfPropertyPath FOUND']);
        NewContext:=Context;
        Result:=true;
        exit;
      end else begin
        Context:=Context.Tool.FindBaseTypeOfNode(Params,Context.Node);
        if Context.Node=nil then exit;
      end;
    until false;
  finally
    Params.Free;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.FindDeclarationOfPropertyPath(
  const PropertyPath: string;
  out NewPos: TCodeXYPosition; out NewTopLine: integer;
  IgnoreTypeLess: boolean): boolean;
var
  Context: TFindContext;
begin
  Result:=FindDeclarationOfPropertyPath(PropertyPath,Context,IgnoreTypeLess);
  if not Result then exit;
  Result:=Context.Tool.JumpToNode(Context.Node,NewPos,NewTopLine,false);
end;

function TFindDeclarationTool.FindDeclarationNodeInInterface(
  const Identifier: string; BuildTheTree: Boolean): TCodeTreeNode;
var
  CacheEntry: PInterfaceIdentCacheEntry;
begin
  Result:=nil;
  if Identifier='' then exit;
  if BuildTheTree and (not BuildInterfaceIdentifierCache(true)) then
    exit;
  CacheEntry:=FInterfaceIdentifierCache.FindIdentifier(PChar(Identifier));
  if CacheEntry=nil then exit;
  Result:=CacheEntry^.Node;
end;

function TFindDeclarationTool.FindDeclarationNodeInImplementation(
  Identifier: string; BuildTheTree: Boolean): TCodeTreeNode;
begin
  Result:=nil;
  if Identifier='' then exit;
  if BuildTheTree then
    BuildTree(lsrInitializationStart);
  Result:=FindSubDeclaration(Identifier,FindImplementationNode);
end;

function TFindDeclarationTool.FindSubDeclaration(Identifier: string;
  ParentNode: TCodeTreeNode): TCodeTreeNode;
var
  LastNode: TCodeTreeNode;
begin
  Result:=nil;
  if ParentNode=nil then exit;
  if Identifier='' then exit;
  Identifier:=UpperCaseStr(Identifier);
  LastNode:=ParentNode.NextSkipChilds;
  Result:=ParentNode.Next;
  while Result<>LastNode do begin
    // ToDo: check enums
    if Result.Desc in AllIdentifierDefinitions then begin
      if CompareNodeIdentChars(Result,Identifier)=0 then
        exit;
      Result:=Result.NextSkipChilds;
    end else if Result.Desc=ctnProcedure then begin
      if CompareIdentifiers(PChar(ExtractProcName(Result,[])),PChar(Pointer(Identifier)))=0 then
        exit;
      Result:=Result.NextSkipChilds;
    end else
      Result:=Result.Next;
  end;
  Result:=nil;
end;

function TFindDeclarationTool.FindNameInUsesSection(UsesNode: TCodeTreeNode;
  const AUnitName: string): TCodeTreeNode;
var
  CurUnitName: string;
begin
  Result:=UsesNode.FirstChild;
  while (Result<>nil) do begin
    CurUnitName:=ExtractUsedUnitName(Result);
    if CompareDottedIdentifiers(PChar(CurUnitName),PChar(AUnitName))=0 then exit;
    Result:=Result.NextBrother;
  end;
end;

function TFindDeclarationTool.FindUnitInUsesSection(UsesNode: TCodeTreeNode;
  const AnUnitName: string; out NamePos, InPos: TAtomPosition): boolean;
var
  CurUnitName: String;
  StartPos: Integer;
begin
  Result:=false;
  NamePos:=CleanAtomPosition;
  InPos:=CleanAtomPosition;
  if (UsesNode=nil) or (not IsDottedIdentifier(AnUnitName))
  or (UsesNode.Desc<>ctnUsesSection) then begin
    DebugLn(['TFindDeclarationTool.FindUnitInUsesSection invalid AnUnitName']);
    exit;
  end;
  MoveCursorToNodeStart(UsesNode);
  ReadNextAtom; // read 'uses'
  repeat
    ReadNextAtom; // read name
    if CurPos.Flag=cafSemicolon then break;
    if (CurPos.StartPos>SrcLen) then break;
    StartPos:=CurPos.StartPos;
    CurUnitName:=ExtractUsedUnitNameAtCursor;
    if CompareDottedIdentifiers(PChar(CurUnitName),PChar(AnUnitName))=0 then
    begin
      MoveCursorToCleanPos(StartPos);
      ReadNextAtom;
      ReadNextUsedUnit(NamePos,InPos);
      exit(true);
    end;
    if CurPos.Flag=cafSemicolon then break;
    if CurPos.Flag<>cafComma then break;
  until (CurPos.StartPos>SrcLen);
end;

function TFindDeclarationTool.FindUnitInAllUsesSections(
  const AnUnitName: string; out NamePos, InPos: TAtomPosition): boolean;

  procedure RaiseInvalidUnitName;
  begin
    raise Exception.Create('invalid unit name '+AnUnitName);
  end;

  function FindInSection(UsesNode: TCodeTreeNode): boolean;
  begin
    Result:=(UsesNode<>nil)
           and FindUnitInUsesSection(UsesNode,AnUnitName,NamePos,InPos);
  end;

begin
  Result:=false;
  NamePos.StartPos:=-1;
  InPos.StartPos:=-1;
  if not IsDottedIdentifier(AnUnitName) then
    RaiseInvalidUnitName;
  BuildTree(lsrImplementationUsesSectionEnd);
  if FindInSection(FindMainUsesNode) then exit(true);
  if FindInSection(FindImplementationUsesNode) then exit(true);
end;

function TFindDeclarationTool.GetUnitNameForUsesSection(
  TargetTool: TFindDeclarationTool): string;
// if unit is already used return ''
// else return nice name
var
  UsesNode: TCodeTreeNode;
  Alternative: String;
begin
  Result:='';
  if (TargetTool=nil) or (TargetTool.MainFilename='') or (TargetTool=Self) then
    exit;
  Result:=ExtractFileNameOnly(TargetTool.MainFilename);
  if Result='' then exit;

  // check if system unit
  if IsHiddenUsedUnit(PChar(Result)) then begin
    Result:='';
    exit;
  end;

  // check if already there
  UsesNode:=FindMainUsesNode;
  if (UsesNode<>nil) and (FindNameInUsesSection(UsesNode,Result)<>nil)
  then begin
    Result:='';
    exit;
  end;
  UsesNode:=FindImplementationUsesNode;
  if (UsesNode<>nil) and (FindNameInUsesSection(UsesNode,Result)<>nil)
  then begin
    Result:='';
    exit;
  end;

  // beautify
  if Result=lowercase(Result) then begin
    Alternative:=TargetTool.GetSourceName(false);
    if Alternative<>'' then
      Result:=Alternative;
  end;
end;

function TFindDeclarationTool.IsHiddenUsedUnit(TheUnitName: PChar): boolean;
var
  HiddenUnits: String;
  p: PChar;
begin
  if TheUnitName=nil then exit(false);
  HiddenUnits:=Scanner.GetHiddenUsedUnits;
  if HiddenUnits<>'' then begin
    p:=PChar(HiddenUnits);
    while p^<>#0 do begin
      if CompareDottedIdentifiers(TheUnitName,p)=0 then
        exit(true);
      while not (p^ in [',',#0]) do inc(p);
      while p^=',' do inc(p);
    end;
  end;
  Result:=false;
end;

function TFindDeclarationTool.FindDeclarationInUsesSection(
  UsesNode: TCodeTreeNode; CleanPos: integer;
  out NewPos: TCodeXYPosition; out NewTopLine: integer): boolean;
var
  AUnitName, UnitInFilename: string;
  UnitNamePos, UnitInFilePos: TAtomPosition;
begin
  Result:=false;
  {$IFDEF ShowTriedContexts}
  DebugLn('TFindDeclarationTool.FindDeclarationInUsesSection A');
  {$ENDIF}
  {$IFDEF CheckNodeTool}CheckNodeTool(UsesNode);{$ENDIF}
  // reparse uses section, ignore errors after CleanPos
  MoveCursorToNodeStart(UsesNode);
  if (UsesNode.Desc=ctnUsesSection) then begin
    ReadNextAtom;
    if not UpAtomIs('USES') then
      RaiseUsesExpected(20170421200506);
  end else
  if (UsesNode.Desc = ctnUseUnitClearName) then
    MoveCursorToNodeStart(UsesNode.Parent);

  repeat
    ReadNextAtom;  // read name
    if CurPos.StartPos>CleanPos then break;
    if CurPos.Flag=cafSemicolon then break;
    ReadNextUsedUnit(UnitNamePos,UnitInFilePos);
    if CleanPos<=CurPos.StartPos then begin
      // cursor is on an used unit -> try to locate it
      MoveCursorToCleanPos(UnitNamePos.StartPos);
      ReadNextAtom;
      AUnitName:=ExtractUsedUnitNameAtCursor(@UnitInFilename);
      NewPos.Code:=FindUnitSource(AUnitName,UnitInFilename,true,UnitNamePos.StartPos);
      NewPos.X:=1;
      NewPos.Y:=1;
      NewTopLine:=1;
      Result:=true;
      exit;
    end;
    if CurPos.Flag=cafSemicolon then break;
    if CurPos.Flag<>cafComma then
      RaiseExceptionFmt(20170421200032,ctsStrExpectedButAtomFound,[';',GetAtom])
  until (CurPos.StartPos>SrcLen);
  {$IFDEF ShowTriedContexts}
  DebugLn('TFindDeclarationTool.FindDeclarationInUsesSection END cursor not on AUnitName');
  {$ENDIF}
end;

function TFindDeclarationTool.FindUnitFileInUsesSection(
  UsesNode: TCodeTreeNode; const AFilename: string): TCodeTreeNode;
var
  TargetUnitName: string;
  TargetShortFilename: string;

  function CheckUseNode(Node: TCodeTreeNode): boolean;
  var
    Code: TCodeBuffer;
    UnitInFilename: string;
    AUnitName: string;
  begin
    Result:=false;
    MoveCursorToNodeStart(Node);
    ReadNextAtom;
    AUnitName:=ExtractUsedUnitNameAtCursor(@UnitInFilename);
    if AUnitName='' then exit;

    // quick check: compare unitname
    if UnitInFilename<>'' then begin
      if CompareText(ExtractFilename(UnitInFilename),TargetShortFilename)<>0 then
        exit;
    end else if CompareText(AUnitName,TargetUnitName)<>0 then
      exit;

    // search in search paths
    Code:=FindUnitSource(AUnitName,UnitInFilename,false,Node.StartPos);
    Result:=(Code<>nil) and (CompareFilenames(Code.Filename,AFilename)=0);
  end;

begin
  Result:=nil;
  if (UsesNode=nil) or (UsesNode.Desc<>ctnUsesSection) then exit;
  TargetUnitName:=ExtractFileNameOnly(AFilename);
  TargetShortFilename:=ExtractFileName(AFilename);
  if TargetShortFilename='' then exit;
  Result:=UsesNode.LastChild;
  while Result<>nil do begin
    if CheckUseNode(Result) then exit;
    Result:=Result.PriorBrother;
  end;
end;

function TFindDeclarationTool.FindUnitFileInAllUsesSections(
  const AFilename: string; CheckMain: boolean; CheckImplementation: boolean
  ): TCodeTreeNode;
begin
  Result:=nil;
  //debugln(['TFindDeclarationTool.FindUnitFileInAllUsesSections Self=',ExtractFilename(MainFilename),' Search=',ExtractFilename(AFilename)]);
  if AFilename='' then exit;
  if CheckMain then begin
    Result:=FindUnitFileInUsesSection(FindMainUsesNode,AFilename);
    //debugln(['TFindDeclarationTool.FindUnitFileInAllUsesSections Self=',ExtractFilename(MainFilename),' Search=',ExtractFilename(AFilename),' used in main uses=',Result<>nil]);
    if Result<>nil then exit;
  end;
  if CheckImplementation then
    Result:=FindUnitFileInUsesSection(FindImplementationUsesNode,AFilename);
end;

function TFindDeclarationTool.FindUnitSource(const AnUnitName,
  AnUnitInFilename: string; ExceptionOnNotFound: boolean; ErrorPos: integer
  ): TCodeBuffer;
var
  CompiledFilename: string;
  AFilename: String;
  NewUnitName: String;
  NewInFilename: String;
  NewCompiledUnitname: String;
  ErrMsg: string;
begin
  {$IF defined(ShowTriedFiles) or defined(ShowTriedUnits)}
  DebugLn('TFindDeclarationTool.FindUnitSource Self="',MainFilename,'" AnUnitName="',AnUnitName,'" AnUnitInFilename="',AnUnitInFilename,'"');
  {$ENDIF}
  Result:=nil;
  if (AnUnitName='') or (Scanner=nil) then
    RaiseException(20171214184503,'TFindDeclarationTool.FindUnitSource Invalid Data');
  if (Scanner.MainCode=nil) then
    RaiseException(20171214184512,'TFindDeclarationTool.FindUnitSource Invalid Data');
  if (not (TObject(Scanner.MainCode) is TCodeBuffer)) then
    RaiseException(20171214184519,'TFindDeclarationTool.FindUnitSource Invalid Data');
  if (Scanner.OnLoadSource=nil) then
    RaiseException(20171214184527,'TFindDeclarationTool.FindUnitSource Invalid Data');

  NewUnitName:=AnUnitName;
  NewInFilename:=AnUnitInFilename;

  AFilename:=DirectoryCache.FindUnitSourceInCompletePath(
                          NewUnitName,NewInFilename,false,false,AddedNameSpace);
  Result:=TCodeBuffer(Scanner.OnLoadSource(Self,AFilename,true));

  if (Result=nil) and Assigned(OnFindUsedUnit) then begin
    // no unit found
    Result:=OnFindUsedUnit(Self,AnUnitName,AnUnitInFilename);
  end;
  
  if Result=nil then begin
    // search .ppu
    NewCompiledUnitname:=AnUnitName+'.ppu';
    CompiledFilename:=DirectoryCache.FindCompiledUnitInCompletePath(
                                                     NewCompiledUnitname,false);
    //debugln(['TFindDeclarationTool.FindUnitSource UnitName=',NewUnitName,' ',NewCompiledUnitname,' CompiledFilename=',CompiledFilename]);
  end else begin
    CompiledFilename:='';
  end;

  if (Result=nil) and ExceptionOnNotFound then begin
    ErrMsg:='';
    if ErrorPos>0 then
      MoveCursorToCleanPos(ErrorPos)
    else if ErrorPos=0 then begin
      CurPos.StartPos:=-1;
    end else begin
      CurPos.StartPos:=-1;
      ErrMsg:=Format(ctsNeededByMode, [CompilerModeNames[Scanner.CompilerMode]]);
    end;
    if CompiledFilename<>'' then begin
      // there is a compiled unit, only the source was not found
      RaiseExceptionInstance(
        ECodeToolUnitNotFound.Create(Self,20170421200052,
          Format(ctsSourceNotFoundUnit+ErrMsg, [CompiledFilename]),
          AnUnitName));
    end else begin
      // nothing found
      RaiseExceptionInstance(
        ECodeToolUnitNotFound.Create(Self,20170421200056,
          Format(ctsUnitNotFound+ErrMsg,[AnUnitName]),
          AnUnitInFilename));
    end;
  end;
end;

function TFindDeclarationTool.FindUnitCaseInsensitive(var AnUnitName,
  AnUnitInFilename: string): string;
begin
  Result:=DirectoryCache.FindUnitSourceInCompletePath(
                         AnUnitName,AnUnitInFilename,true,false,AddedNameSpace);
end;

procedure TFindDeclarationTool.GatherUnitAndSrcPath(var UnitPath,
  CompleteSrcPath: string);
begin
  UnitPath:='';
  CompleteSrcPath:='';
  UnitPath:=DirectoryCache.Strings[ctdcsUnitPath];
  CompleteSrcPath:=DirectoryCache.Strings[ctdcsCompleteSrcPath];
  //DebugLn('TFindDeclarationTool.GatherUnitAndSrcPath UnitPath="',UnitPath,'" CompleteSrcPath="',CompleteSrcPath,'"');
end;

function TFindDeclarationTool.SearchUnitInUnitSet(const TheUnitName: string): string;
begin
  Result:=DirectoryCache.FindUnitInUnitSet(TheUnitName);
end;

function TFindDeclarationTool.GetNameSpaces: string;
begin
  Result:=DirectoryCache.Strings[ctdcsNamespaces];
  if AddedNameSpace<>'' then begin
    if Result<>'' then Result:=';'+Result;
    Result:=AddedNameSpace+Result;
  end;
end;

function TFindDeclarationTool.FindSmartHint(const CursorPos: TCodeXYPosition;
  Flags: TFindSmartFlags): string;
var
  NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode;
  NewPos: TCodeXYPosition;
  NewTopLine: integer;
begin
  Result:='';
  if not FindDeclaration(CursorPos,Flags,NewTool,NewNode,NewPos,NewTopLine) then
  begin
    // identifier not found
    exit;
  end;
  Result:=NewTool.GetSmartHint(NewNode,NewPos,true);
end;

function TFindDeclarationTool.GetSmartHint(Node: TCodeTreeNode;
  XYPos: TCodeXYPosition; WithPosition: boolean; WithDefinition: boolean
  ): string;

  function ReadIdentifierWithDots: String;
  begin
    Result := '';
    repeat
      ReadNextAtom;
      Result := Result + GetAtom;
      ReadNextAtom;
      if CurPos.Flag = cafPoint then
        Result := Result + '.'
      else
        break;
    until false;
  end;

  function MoveToLastIdentifierThroughDots(ExtTool: TFindDeclarationTool): Boolean;
  var
    LastPos: TAtomPosition;
  begin
    LastPos := ExtTool.CurPos;
    ExtTool.ReadNextAtom;
    if ExtTool.CurPos.Flag = cafWord then
      ExtTool.ReadNextAtom;
    while ExtTool.CurPos.Flag = cafPoint do
    begin
      ExtTool.ReadNextAtom;
      LastPos := ExtTool.CurPos;
      ExtTool.ReadNextAtom;
    end;
    ExtTool.CurPos := LastPos;
    Result := True;
  end;

  function ProceedWithSmartHint(ExtTool: TFindDeclarationTool): string;
  var
    CTExprType: TExpressionType;
    CTXYPos: TCodeXYPosition;
    CTTopLine: integer;
    CTCursorPos: TCodeXYPosition;
  begin
    MoveToLastIdentifierThroughDots(ExtTool);
    if ExtTool.CleanPosToCaret(ExtTool.CurPos.StartPos,CTCursorPos)
    and ExtTool.FindDeclaration(CTCursorPos,
         DefaultFindSmartHintFlags+[fsfSearchSourceName],CTExprType,CTXYPos,CTTopLine)
    and not((CTExprType.Desc=xtContext) and (CTExprType.Context.Node=nil) and (CTExprType.Context.Tool=nil))
    and not((CTExprType.Context.Tool=Self) and (CTXYPos.X=XYPos.X) and (CTXYPos.Y=XYPos.Y)) // prevent endless loop
    then
      Result := CTExprType.Context.Tool.GetSmartHint(CTExprType.Context.Node, CTXYPos, False, False)
    else
      Result := '';
  end;
var
  IdentNode, TypeNode, ANode: TCodeTreeNode;
  ClassStr, NodeStr, SetStr: String;
  Params: TFindDeclarationParams;
  Tool: TFindDeclarationTool;
  HelperForNode: TCodeTreeNode;
  SubNode: TCodeTreeNode;
begin
  Result:='';

  { Examples:
      var i: integer
      /home/.../codetools/finddeclarationtools.pas(1224,7)
  }
  // identifier category and identifier
  if Node<>nil then begin
    // class visibility
    if Node.Parent<>nil then begin
      ANode:=Node.Parent;
      while ANode<>nil do begin
        case ANode.Desc of
        ctnClassPrivate:
          Result+='private ';
        ctnClassProtected:
          Result+='protected ';
        ctnClassPublic:
          Result+='public ';
        ctnClassPublished:
          Result+='published ';
        ctnClassClassVar:
          Result+='class ';
        else
          break;
        end;
        ANode:=ANode.Parent;
      end;
    end;

    if Node.Desc = ctnGenericName then
      Node := Node.Parent;
    case Node.Desc of
    ctnIdentifier:
      if Assigned(Node.Parent) and (Node.Parent.Desc = ctnProcedureHead) then
        // function result
        Result := 'var Result: ' + ExtractNode(Node, []);

    ctnVarDefinition, ctnTypeDefinition, ctnConstDefinition,
    ctnEnumIdentifier, ctnLabel, ctnGenericType:
      begin
        case Node.Desc of
        ctnVarDefinition: Result+='var ';
        ctnTypeDefinition: Result+='type ';
        ctnConstDefinition: Result+='const ';
        ctnEnumIdentifier: Result+='enum ';
        ctnLabel: Result+='label ';
        ctnGenericType: Result+='generic type ';
        end;

        // add class name
        ClassStr := ExtractClassPath(Node.Parent);
        if ClassStr <> '' then Result += ClassStr + '.';

        Result:=Result+ExtractDefinitionName(Node);
        TypeNode:=FindTypeNodeOfDefinition(Node);
        if not WithDefinition then Result := '';
        if TypeNode<>nil then begin
          case Node.Desc of
            ctnTypeDefinition, ctnGenericType:
              Result+=' = ';
            ctnConstDefinition:
              if TypeNode.Desc = ctnConstant then
                Result += ' = '
              else
                Result += ': ';
            ctnEnumIdentifier,ctnLabel: ;
            else
              Result += ': ';
          end;
          case TypeNode.Desc of
          ctnSetType:
            begin
              Result += ExtractNode(TypeNode, [phpCommentsToSpace]);
              MoveCursorToNodeStart(TypeNode);
              ReadNextAtom;
              if ReadNextUpAtomIs('OF') then
              begin
                if (Length(Result) > 0) and (Result[Length(Result)] = ';') then//delete last ";" from set
                  Delete(Result, Length(Result), 1);
                ReadNextAtom;
                SetStr := ProceedWithSmartHint(Self);
                if (Length(SetStr) > 2) and (SetStr[2] = '=') then
                  SetStr := Copy(SetStr, 4, High(Integer));
                if (SetStr <> '') then
                  Result += ' = ['+SetStr+']';
              end;
            end;
          ctnIdentifier, ctnSpecialize, ctnSpecializeType,
          ctnPointerType, ctnRangeType, ctnFileType, ctnClassOfType:
            begin
              Result += ExtractNode(TypeNode, [phpCommentsToSpace]);
              MoveCursorToNodeStart(TypeNode);
              Result += ProceedWithSmartHint(Self);
            end;
          ctnClass, ctnClassInterface, ctnDispinterface,
          ctnClassHelper, ctnTypeHelper, ctnRecordHelper,
          ctnObject, ctnRangedArrayType, ctnOpenArrayType,
          ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass:
            begin
              MoveCursorToNodeStart(TypeNode);
              case TypeNode.Desc of
              ctnClass: Result:=Result+'class';
              ctnClassHelper: Result:=Result+'class helper';
              ctnRecordHelper: Result:=Result+'record helper';
              ctnTypeHelper: Result:=Result+'type helper';
              ctnObject: Result:=Result+'object';
              ctnObjCClass: Result:=Result+'objcclass';
              ctnObjCCategory: Result:=Result+'objccategory';
              ctnCPPClass: Result:=Result+'cppclass';
              ctnClassInterface: Result:=Result+'interface';
              ctnObjCProtocol: Result:=Result+'objcprotocol';
              ctnDispinterface: Result:=Result+'dispinterface';
              ctnRangedArrayType, ctnOpenArrayType: Result:=Result+'array';
              end;
              try
                BuildSubTree(TypeNode);
              except
                on ECodeToolError do ;
              end;
              SubNode:=FindInheritanceNode(TypeNode);
              if SubNode<>nil then
                Result:=Result+ExtractNode(SubNode,[]);

              if TypeNode.Desc in [ctnClassHelper, ctnRecordHelper, ctnTypeHelper] then
                HelperForNode := FindHelperForNode(TypeNode)
              else
                HelperForNode := nil;
              if HelperForNode<>nil then
                Result:=Result+' '+ExtractNode(HelperForNode,[]);
            end;
          ctnRecordType:
            Result:=Result+'record';
          ctnTypeType:
            begin
              Result:=Result+'type';
              if TypeNode.FirstChild <> nil then
                Result:=Result+' '+ExtractNode(TypeNode.FirstChild,[]);
            end;
          ctnConstant:
            begin
              NodeStr:=ExtractNode(TypeNode,[phpCommentsToSpace]);
              Result+=copy(NodeStr,1,50);
            end;
          ctnEnumerationType:
            begin
              if Assigned(Node.FirstChild) then
              begin
                NodeStr:=ExtractCode(Node.FirstChild.StartPos,Node.FirstChild.EndPos,[phpCommentsToSpace]);
                if Length(NodeStr) > 50 then
                  NodeStr:=Copy(NodeStr, 1, 50) + ' ...';
                Result += NodeStr;
              end else
                Result += 'enum';
            end;
          end;
        end else begin
          case Node.Desc of
          ctnConstDefinition:
            begin
              DebugLn('TFindDeclarationTool.GetSmartHint const without subnode "',ExtractNode(Node,[]),'"');
              NodeStr:=ExtractCode(Node.StartPos
                                 +GetIdentLen(@Src[Node.StartPos]),
                                 Node.EndPos,[phpCommentsToSpace]);
              Result+=copy(NodeStr,1,50);
            end;
          end;
        end;
      end;

    ctnProcedure,ctnProcedureHead:
      begin

        // ToDo: ppu, dcu files

        Result+=ExtractProcHead(Node,
          [phpAddClassName,phpWithStart,phpWithVarModifiers,phpWithParameterNames,
           phpWithDefaultValues,phpWithResultType,phpWithOfObject,phpCommentsToSpace]);
      end;

    ctnProperty,ctnGlobalProperty:
      begin
        IdentNode:=Node;

        // ToDo: ppu, dcu files

        Result+='property ';
        MoveCursorToNodeStart(IdentNode);
        ReadNextAtom;
        if Node.Desc = ctnProperty then begin
          // e.g. property Caption: string;
          // skip keyword
          ReadNextAtom;
          // add class name
          ClassStr := ExtractClassName(Node, False, True);
          if ClassStr <> '' then Result += ClassStr + '.';
        end else begin
          // global property starts with identifier
        end;
        // add name
        Result+=GetAtom;

        Tool:=Self;
        while (Node.Desc=ctnProperty)
        and not Tool.MoveCursorToPropType(Node) do begin
          // property without type
          // -> search ancestor property
          if not Tool.MoveCursorToPropName(Node) then break;
          Params:=TFindDeclarationParams.Create(Tool, Node);
          try
            Params.SetIdentifier(Tool,@Tool.Src[Tool.CurPos.StartPos],nil);
            Params.Flags:=[fdfSearchInAncestors,fdfSearchInHelpers];
            if not Tool.FindIdentifierInAncestors(Node.Parent.Parent,Params) then break;
            Tool:=Params.NewCodeTool;
            Node:=Params.NewNode;
          finally
            Params.Free;
          end;
        end;
        if (Node<>nil) then begin
          if (Node.Desc in [ctnProperty,ctnGlobalProperty]) then begin
            Result += Tool.ExtractProperty(Node,
                [phpWithoutName,phpWithParameterNames,phpWithResultType]);
          end;

          if Tool.MoveCursorToPropType(Node) then
            Result += ProceedWithSmartHint(Tool);
        end;
      end;

    ctnProgram,ctnUnit,ctnPackage,ctnLibrary:
      begin
        IdentNode:=Node;

        // ToDo: ppu, dcu files

        MoveCursorToNodeStart(IdentNode);
        ReadNextAtom;
        if (IdentNode.Desc=ctnProgram) and not UpAtomIs('PROGRAM') then begin
          // program without source name
          Result:='program '+ExtractFileNameOnly(MainFilename)+' ';
        end else begin
          Result+=GetAtom+' '; // keyword
          Result := Result + ReadIdentifierWithDots + ' ';
        end;
      end;

    ctnUseUnitNamespace:
      begin
        // hint for unit namespace in "uses" section
        Result += 'namespace ';
        MoveCursorToNodeStart(Node);
        ReadNextAtom;
        Result := Result + GetAtom;
      end;

    ctnUseUnitClearName:
      begin
        // hint for unit in "uses" section
        Result += 'unit ';
        MoveCursorToNodeStart(Node.Parent);
        Result := Result + ReadIdentifierWithDots;
      end

    else
      DebugLn('ToDo: TFindDeclarationTool.GetSmartHint ',Node.DescAsString);
    end;
  end;
  if WithPosition then begin
    // filename
    if Result<>'' then Result:=Result+LineEnding;
    if XYPos.Code=nil then
      CleanPosToCaret(Node.StartPos,XYPos);
    Result+=XYPos.Code.Filename;
    // file position
    if XYPos.Y>=1 then begin
      Result+='('+IntToStr(XYPos.Y);
      if XYPos.X>=1 then begin
        Result+=','+IntToStr(XYPos.X);
      end;
      Result+=')';
    end;
  end;
end;

function TFindDeclarationTool.BaseTypeOfNodeHasSubIdents(ANode: TCodeTreeNode
  ): boolean;
var
  FindContext: TFindContext;
  Params: TFindDeclarationParams;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ANode);{$ENDIF}
  Result:=false;
  if (ANode=nil) then exit;
  ActivateGlobalWriteLock;
  Params:=TFindDeclarationParams.Create(Self, ANode);
  try
    Params.Flags:=Params.Flags+[fdfFunctionResult,fdfFindChildren];
    FindContext:=FindBaseTypeOfNode(Params,ANode);
    if (FindContext.Node<>nil)
    and ((FindContext.Node.Desc in ([ctnEnumerationType]+AllClasses)))
    and (FindContext.Node.FirstChild<>nil)
    then
      Result:=true;
  finally
    Params.Free;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.IsIncludeDirectiveAtPos(CleanPos,
  CleanCodePosInFront: integer; out IncludeCode: TCodeBuffer): boolean;
var LinkIndex, CommentStart, CommentEnd: integer;
  SrcLink: TSourceLink;
begin
  Result:=false;
  IncludeCode:=nil;
  if (Scanner=nil) then exit;
  LinkIndex:=Scanner.LinkIndexAtCleanPos(CleanPos);
  if (LinkIndex<0) or (LinkIndex>=Scanner.LinkCount-1) then exit;
  SrcLink:=Scanner.Links[LinkIndex+1];
  if (SrcLink.Code=nil) or (SrcLink.Code=Scanner.Links[LinkIndex].Code) then
    exit;
  //DebugLn(['TFindDeclarationTool.IsIncludeDirectiveAtPos CleanPos=',CleanPos,' CleanCodePosInFront=',CleanCodePosInFront,' ',copy(Src,CleanCodePosInFront,10)]);
  if CleanPosIsInComment(CleanPos,CleanCodePosInFront,CommentStart,CommentEnd)
  and (CommentEnd=SrcLink.CleanedPos) then begin
    //DebugLn(['TFindDeclarationTool.IsIncludeDirectiveAtPos CommentStart=',CommentStart,' CommentEnd=',CommentEnd,' ',copy(Src,CommentStart,CommentEnd-CommentStart)]);
    IncludeCode:=TCodeBuffer(SrcLink.Code);
    Result:=true;
    exit;
  end;
end;

function TFindDeclarationTool.FindFileAtCursor(
  const CursorPos: TCodeXYPosition; out Found: TFindFileAtCursorFlag; out
  FoundFilename: string; SearchFor: TFindFileAtCursorFlags;
  StartPos: PCodeXYPosition): boolean;
var
  CleanPos: integer;

  function CheckComment(CommentStart, CommentEnd: integer; Enabled: boolean): boolean;
  var
    DirectiveName, Param: string;
    NewCode: TCodeBuffer;
    MissingIncludeFile: TMissingIncludeFile;
    NewCodePtr: Pointer;
  begin
    Result:=false;
    // cursor in comment in parsed code
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFindDeclarationTool.FindFileAtCursor.CheckComment']);
    {$ENDIF}
    if CommentStart=CommentEnd then exit;
    if ExtractLongParamDirective(Src,CommentStart,DirectiveName,Param) then begin
      DirectiveName:=lowercase(DirectiveName);
      if ((Enabled and (ffatIncludeFile in SearchFor))
      or (not Enabled and (ffatDisabledIncludeFile in SearchFor)))
        and (DirectiveName='i') or (DirectiveName='include')
      then begin
        // include directive
        if (Param<>'') and (Param[1]<>'%') then begin
          // include file directive
          Result:=true;
          if Enabled then
            Found:=ffatIncludeFile
          else
            Found:=ffatDisabledIncludeFile;
          if Enabled and IsIncludeDirectiveAtPos(CleanPos,CommentStart,NewCode) then
          begin
            FoundFilename:=NewCode.Filename;
          end else begin
            FoundFilename:=ResolveDots(GetForcedPathDelims(Param));
            // search include file
            MissingIncludeFile:=nil;
            if Scanner.SearchIncludeFile(FoundFilename,NewCodePtr,
              MissingIncludeFile)
            then
              FoundFilename:=TCodeBuffer(NewCodePtr).Filename;
          end;
          exit;
        end;
      end else if ((Enabled and (ffatResource in SearchFor))
      or (not Enabled and (ffatDisabledResource in SearchFor)))
        and ((DirectiveName='r') or (DirectiveName='resource'))
      then begin
        // resource directive
        Result:=true;
        if Enabled then
          Found:=ffatResource
        else
          Found:=ffatDisabledResource;
        FoundFilename:=ResolveDots(GetForcedPathDelims(Param));
        if (FoundFilename<>'') and (copy(FoundFilename,1,2)='*.') then begin
          Delete(FoundFilename,1,1);
          FoundFilename:=ChangeFileExt(MainFilename,FoundFilename);
        end else if not FilenameIsAbsolute(FoundFilename) then begin
          FoundFilename:=ResolveDots(ExtractFilePath(MainFilename)+FoundFilename);
        end;
        exit;
      end;
    end;
  end;

  function CheckPlainComments(Source: string; CurAbsPos: integer): boolean;
  var
    Filename: String;
    p, EndPos, FileStartPos, FileEndPos, MinPos, MaxPos: Integer;
  begin
    // check if cursor in a comment (ignoring directives)
    Result:=false;
    CursorPos.Code.LineColToPosition(CursorPos.Y,CursorPos.X,CurAbsPos);
    Source:=CursorPos.Code.Source;
    if (CurAbsPos<1) or (CurAbsPos>length(Source)) then exit;
    p:=1;
    repeat
      p:=FindNextComment(Source,p);
      if p>CurAbsPos then break;
      EndPos:=FindCommentEnd(Source,p,Scanner.NestedComments);
      if EndPos>CurAbsPos then begin
        // cursor in comment
        MinPos:=p+1;
        MaxPos:=EndPos-1;
        if Source[p]<>'{' then begin
          inc(MinPos);
          dec(MaxPos);
        end;
        FileStartPos:=CurAbsPos;
        while (FileStartPos>MinPos) and not (Source[FileStartPos-1] in [#0..#32]) do
          dec(FileStartPos);
        FileEndPos:=CurAbsPos;
        while (FileEndPos<MaxPos) and not (Source[FileEndPos] in [#0..#32]) do
          inc(FileEndPos);
        Filename:=TrimFilename(copy(Source,FileStartPos,FileEndPos-FileStartPos));
        if not FilenameIsAbsolute(Filename) then
          Filename:=ResolveDots(ExtractFilePath(MainFilename)+Filename);
        if Scanner.OnLoadSource(Scanner,Filename,false)<>nil then begin
          Found:=ffatComment;
          FoundFilename:=Filename;
          exit(true);
        end;
        exit;
      end;
      p:=EndPos;
    until false;
  end;

  function CheckUnitByWordAtCursor(Source: string; CurAbsPos: integer): boolean;
  // e.g. 'Sy|sUtils.CompareText'
  var
    AnUnitName: String;
    Code: TCodeBuffer;
    p: Integer;
  begin
    Result:=false;
    p:=FindStartOfAtom(Source,CurAbsPos);
    if p<1 then exit;
    AnUnitName:=GetIdentifier(@Source[p]);
    Code:=FindUnitSource(AnUnitName,'',false);
    if Code=nil then exit;
    Found:=ffatUnit;
    FoundFilename:=Code.Filename;
    Result:=true;
  end;

var
  CommentStart, CommentEnd, Col, StartCol, CurAbsPos: integer;
  Node: TCodeTreeNode;
  aUnitName, UnitInFilename, Line, Literal, aSource: string;
  NewCode: TCodeBuffer;
  p, StartP: PChar;
begin
  {$IFDEF VerboseFindFileAtCursor}
  debugln(['TFindDeclarationTool.FindFileAtCursor START']);
  {$ENDIF}
  Result:=false;
  Found:=ffatNone;
  FoundFilename:='';
  if StartPos<>nil then
    StartPos^:=CleanCodeXYPosition;
  if CursorPos.Code.LineColIsOutside(CursorPos.Y,CursorPos.X) then begin
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFindDeclarationTool.FindFileAtCursor LineColIsOutside ',dbgs(CursorPos)]);
    {$ENDIF}
    exit;
  end;
  if CursorPos.Code.LineColIsSpace(CursorPos.Y,CursorPos.X) then begin
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFindDeclarationTool.FindFileAtCursor LineColIsSpace ',dbgs(CursorPos)]);
    {$ENDIF}
    exit;
  end;
  if (CursorPos.Y<1) or (CursorPos.Y>CursorPos.Code.LineCount) then begin
    {$IFDEF VerboseFindFileAtCursor}
    debugln(['TFindDeclarationTool.FindFileAtCursor outside Line ',dbgs(CursorPos)]);
    {$ENDIF}
    exit;
  end;
  if [ffatUsedUnit,ffatIncludeFile,ffatDisabledIncludeFile]*SearchFor<>[]
  then begin
    try
      {$IFDEF VerboseFindFileAtCursor}
      debugln(['TFindDeclarationTool.FindFileAtCursor search in nodes']);
      {$ENDIF}
      BuildTreeAndGetCleanPos(trTillCursor,lsrEnd,CursorPos,CleanPos,
                    [btSetIgnoreErrorPos,btCursorPosOutAllowed]);
      Node:=FindDeepestNodeAtPos(CleanPos,false);
      {$IFDEF VerboseFindFileAtCursor}
      debugln(['TFindDeclarationTool.FindFileAtCursor has node: ',Node<>nil]);
      {$ENDIF}
      if Node<>nil then begin
        {$IFDEF VerboseFindFileAtCursor}
        debugln(['TFindDeclarationTool.FindFileAtCursor in node "',Node.DescAsString,'"']);
        {$ENDIF}
        // cursor in parsed code
        if CleanPosIsInComment(CleanPos,Node.StartPos,CommentStart,CommentEnd,true)
        then begin
          //debugln(['TFindDeclarationTool.FindFileAtCursor Comment="',copy(Src,CommentStart,CommentEnd-CommentStart),'"']);
          if (CommentEnd-CommentStart>4)
          and (Src[CommentStart]='{') and (Src[CommentStart+1]=#3) then begin
            // cursor in disabled code
            if CleanPosIsInComment(CleanPos,CommentStart+2,CommentStart,CommentEnd,true)
            then begin
              // cursor in disabled comment
              if CheckComment(CommentStart,CommentEnd,false) then
                exit(true);
            end;
          end else begin
            // cursor in enabled comment
            if CheckComment(CommentStart,CommentEnd,true) then
              exit(true);
          end;
        end else begin
          {$IFDEF VerboseFindFileAtCursor}
          debugln(['TFindDeclarationTool.FindFileAtCursor in parsed code, not in comment Node=',Node.DescAsString]);
          {$ENDIF}
          if Node.Desc in [ctnUseUnitClearName,ctnUseUnitNamespace] then begin
            Node:=Node.Parent;
            {$IFDEF VerboseFindFileAtCursor}
            debugln(['TFindDeclarationTool.FindFileAtCursor node="',Node.DescAsString,'"']);
            {$ENDIF}
          end;
          if Node.Desc=ctnUseUnit then begin
            {$IFDEF VerboseFindFileAtCursor}
            debugln(['TFindDeclarationTool.FindFileAtCursor in use unit CleanPos=',CleanPos,' Node=',Node.StartPos,'-',Node.EndPos]);
            {$ENDIF}
            if (CleanPos>=Node.StartPos) and (CleanPos<Node.EndPos) then begin
              // cursor on used unit
              Found:=ffatUsedUnit;
              if StartPos<>nil then
                CleanPosToCaret(Node.StartPos,StartPos^);
              MoveCursorToNodeStart(Node);
              ReadNextAtom;
              aUnitName:=ExtractUsedUnitNameAtCursor(@UnitInFilename);
              NewCode:=FindUnitSource(aUnitName,UnitInFilename,false);
              {$IFDEF VerboseFindFileAtCursor}
              debugln(['TFindDeclarationTool.FindFileAtCursor cursor on used unit "',aUnitName,'" in "',UnitInFilename,'" Found=',NewCode<>nil]);
              {$ENDIF}
              if NewCode<>nil then begin
                FoundFilename:=NewCode.Filename;
                Result:=true;
              end else begin
                FoundFilename:=UnitInFilename;
                Result:=false;
              end;
              exit;
            end;
          end;
        end;
      end;
    except
      on ELinkScannerError do ;
      on ECodeToolError do ;
    end;
  end;

  // fallback: ignore parsed code and read the line at cursor directly
  if (CursorPos.Y<1) or (CursorPos.Y>CursorPos.Code.LineCount) then exit;
  Line:=CursorPos.Code.GetLine(CursorPos.Y-1,false);
  {$IFDEF VerboseFindFileAtCursor}
  debugln(['TFindDeclarationTool.FindFileAtCursor Line="',copy(Line,1,CursorPos.X-1),'|',copy(Line,CursorPos.X,200),'"']);
  {$ENDIF}
  if CursorPos.X>length(Line) then exit;
  if ffatLiteral in SearchFor then begin
    // check literal
    p:=PChar(Line);
    repeat
      case p^ of
      #0:
        break;
      '''':
        begin
          StartCol:=p-PChar(Line)+1;
          inc(p);
          StartP:=p;
          repeat
            case p^ of
            #0,'''': break;
            else inc(p);
            end;
          until false;
          Col:=p-PChar(Line)+1;
          //debugln(['TFindDeclarationTool.FindFileAtCursor Col=',Col,' CursorCol=',CursorPos.X,' Literal=',copy(Line,StartCol+1,p-StartP)]);
          if (p>StartP) and (CursorPos.X>=StartCol) and (CursorPos.X<=Col) then begin
            Literal:=copy(Line,StartCol+1,p-StartP);
            if not FilenameIsAbsolute(Literal) then
              Literal:=TrimFilename(ExtractFilePath(Scanner.MainFilename)+Literal);
            Found:=ffatLiteral;
            FoundFilename:=Literal;
            exit(true);
          end;
          if p^=#0 then break;
          // p is now on the ending '
        end;
      end;
      inc(p);
      inc(Col);
    until false;
  end;

  // search without node tree with basic tools
  CursorPos.Code.LineColToPosition(CursorPos.Y,CursorPos.X,CurAbsPos);
  aSource:=CursorPos.Code.Source;
  if (CurAbsPos<1) or (CurAbsPos>length(aSource)) then exit;

  if ffatComment in SearchFor then begin
    // ignore syntax and only read comments
    if CheckPlainComments(aSource,CurAbsPos) then exit(true);
  end;

  if ffatUnit in SearchFor then begin
    if CheckUnitByWordAtCursor(aSource,CurAbsPos) then exit(true);
  end;
end;

function TFindDeclarationTool.FindDeclarationOfIdentAtParam(
  Params: TFindDeclarationParams): boolean;
var
  ExprType: TExpressionType;
begin
  Result := FindDeclarationOfIdentAtParam(Params, ExprType) and (Params.NewNode<>nil);
end;

function TFindDeclarationTool.FindDeclarationOfIdentAtParam(
  Params: TFindDeclarationParams; out ExprType: TExpressionType): boolean;
{ searches an identifier in clean code, parses code in front and after the
  identifier

  Params:
    Identifier in clean source
    ContextNode  // = DeepestNode at Cursor

  Result:
    true, if found

  Examples:
    A^.B().C[].Identifier
    inherited Identifier(p1,p2)
    'Hello'.identifier
}
var
  StartPos, EndPos: integer;
  SkipForward: boolean;
  Node: TCodeTreeNode;
begin
  {$IFDEF CTDEBUG}
  DebugLn('[TFindDeclarationTool.FindDeclarationOfIdentAtParam] Identifier=',
    '"',GetIdentifier(Params.Identifier),'"',
    ' ContextNode=',NodeDescriptionAsString(Params.ContextNode.Desc),
    ' "',dbgstr(copy(Src,Params.ContextNode.StartPos,20)),'"');
  {$ENDIF}
  Result:=false;
  // search in cleaned source

  MoveCursorToCleanPos(Params.Identifier);
  StartPos:=FindStartOfTerm(CurPos.StartPos,NodeTermInType(Params.ContextNode));
  MoveCursorToCleanPos(Params.Identifier);
  ReadNextAtom;
  EndPos:=CurPos.EndPos;
  if (Params.ContextNode.Desc=ctnIdentifier)
  and (Params.ContextNode.Parent.Desc=ctnAttribParam) then begin
    // parameters don't matter for the attribute name
  end else begin
    ReadNextAtom;
    if CurPos.Flag=cafRoundBracketOpen then begin
      ReadTilBracketClose(true);
      EndPos:=CurPos.EndPos;
    end;
  end;
  {$IFDEF ShowExprEval}
  debugln(['TFindDeclarationTool.FindDeclarationOfIdentAtParam Term=',dbgstr(Src,StartPos,EndPos-StartPos)]);
  {$ENDIF}
  SkipForward:=fdfSkipClassForward in Params.Flags;
  Include(Params.Flags,fdfFindVariable);
  ExprType:=FindExpressionTypeOfTerm(StartPos,EndPos,Params,false);
  if (ExprType.Desc=xtContext) then
    Params.SetResult(ExprType.Context)
  else
    Params.SetResult(CleanFindContext);
  if SkipForward and (Params.NewNode<>nil) then
    Params.NewCodeTool.FindNonForwardClass(Params);
  if (Params.NewNode<>nil) and (Params.NewNode.Desc=ctnProcedure) then begin
    Node:=Params.NewNode.FirstChild;
    if (Node<>nil) and (Node.Desc=ctnProcedureHead) then
      Params.NewNode:=Node;
  end;
  {$IFDEF ShowExprEval}
  DbgOut('[TFindDeclarationTool.FindDeclarationOfIdentAtParam] Ident=',
    '"',GetIdentifier(Params.Identifier),'" ');
  if Params.NewNode<>nil then
    DebugLn('Node=',Params.NewNode.DescAsString,' ',Params.NewCodeTool.MainFilename)
  else
    DebugLn('NOT FOUND');
  {$ENDIF}
  Result:=ExprType.Desc<>xtNone;
end;

function TFindDeclarationTool.IdentifierIsDefined(const IdentAtom: TAtomPosition;
  ContextNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
var
  Identifier: PChar;
  Node: TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ContextNode);{$ENDIF}
  // find declaration of identifier
  Identifier:=@Src[IdentAtom.StartPos];
  //DebugLn(['TFindDeclarationTool.IdentifierIsDefined BEGIN Params IdentAtom.StartPos=',IdentAtom.StartPos,'=',GetIdentifier(Identifier),', ContextNode.StartPos=',ContextNode.StartPos,'=',ContextNode.DescAsString,' "',ExtractNode(ContextNode,[]),'"']);
  if (CompareIdentifiers(Identifier,'Self')=0) then begin
    Node:=ContextNode;
    while (Node<>nil) do begin
      if NodeIsMethodBody(Node) then
        exit(true);
      Node:=Node.Parent;
    end;
  end;
  if (cmsResult in FLastCompilerModeSwitches)
  and (CompareIdentifiers(Identifier,'Result')=0) then begin
    Node:=ContextNode;
    while (Node<>nil) do begin
      if NodeIsFunction(Node) then
        exit(true);
      Node:=Node.Parent;
    end;
  end;
  Params.ContextNode:=ContextNode;
  Params.SetIdentifier(Self,Identifier,nil);
  Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,fdfSearchInHelpers,
                 fdfTopLvlResolving,fdfFindVariable,fdfIgnoreCurContextNode];
  Result:=FindIdentifierInContext(Params);
  //DebugLn(['TFindDeclarationTool.IdentifierIsDefined END Result=',Result]);
end;

function TFindDeclarationTool.FindIdentifierInContext(
  Params: TFindDeclarationParams; var IdentFoundResult: TIdentifierFoundResult
  ): boolean;
{ searches an identifier in context node
  It does not care about code in front of the identifier like 'a.Identifier'.
  
  Params:
    Identifier
    ContextNode  // = DeepestNode at Cursor

  Result:
    true, if NewPos+NewTopLine valid
}
var
  LastContextNode, StartContextNode, FirstSearchedNode, LastSearchedNode,
  ContextNode: TCodeTreeNode;
  IsForward: boolean;
  IdentifierFoundResult: TIdentifierFoundResult;
  LastNodeCache: TCodeTreeNodeCache;
  LastCacheEntry: PCodeTreeNodeCacheEntry;
  SearchRangeFlags: TNodeCacheEntryFlags;
  NodeCacheEntryFlags: TNodeCacheEntryFlags;
  Flags: TFindDeclarationFlags;
  OldFlags: TFindDeclarationFlags;
  SearchInHelpersInTheEnd: Boolean;

  procedure InitNodesAndCacheAccess;
  
    procedure RaiseInternalError;
    begin
      RaiseException(20170421200059,'[TFindDeclarationTool.FindIdentifierInContext] '
        +' internal error: Params.ContextNode=nil');
    end;
  
  begin
    ContextNode:=Params.ContextNode;
    if ContextNode=nil then RaiseInternalError;
    {$IFDEF CheckNodeTool}
    CheckNodeTool(ContextNode);
    {$ENDIF}
    StartContextNode:=ContextNode;
    FirstSearchedNode:=nil;
    LastSearchedNode:=nil;
    SearchRangeFlags:=[];
    Flags:=Params.Flags;
    if fdfSearchInParentNodes in Flags then
      Include(SearchRangeFlags,ncefSearchedInParents);
    if fdfSearchInAncestors in Flags then
    Include(SearchRangeFlags,ncefSearchedInAncestors);
    LastNodeCache:=nil;
    LastCacheEntry:=nil;
    NodeCacheEntryFlags:=[];
    if fdfSearchInParentNodes in Flags then
      Include(NodeCacheEntryFlags,ncefSearchedInParents);
    if fdfSearchInAncestors in Flags then
      Include(NodeCacheEntryFlags,ncefSearchedInAncestors);
  end;

  function FindInNodeCache: boolean;
  var
    NodeCache: TCodeTreeNodeCache;
  begin
    Result:=false;
    // the node cache is identifier based
    if ([fdfCollect,fdfExtractOperand]*Flags<>[]) then exit;

    NodeCache:=GetNodeCache(ContextNode,false);
    if (NodeCache<>LastNodeCache) then begin
      // NodeCache changed -> search nearest cache entry for the identifier
      LastNodeCache:=NodeCache;
      if NodeCache<>nil then begin
        LastCacheEntry:=NodeCache.FindNearest(Params.Identifier,
                    ContextNode.StartPos,ContextNode.EndPos,
                    not (fdfSearchForward in Flags));
      end else
        LastCacheEntry:=nil;
    end;
    if (LastCacheEntry<>nil)
    and (LastCacheEntry^.CleanStartPos<=ContextNode.StartPos)
    and (LastCacheEntry^.CleanEndPos>=ContextNode.EndPos)
    and ((NodeCacheEntryFlags-LastCacheEntry^.Flags)=[])
    then begin
      // cached result found
      Params.SetResult(LastCacheEntry);
      {$IFDEF ShowNodeCache}
      DbgOut(':::: TFindDeclarationTool.FindIdentifierInContext.FindInNodeCache');
      DebugLn(' Ident=',GetIdentifier(Params.Identifier),
               ' Wanted=[',NodeCacheEntryFlagsAsString(NodeCacheEntryFlags),']',
               ' Cache=[',NodeCacheEntryFlagsAsString(LastCacheEntry^.Flags),']'
             );
      DebugLn('    ContextNode=',ContextNode.DescAsString,
              ' StartPos=',DbgS(ContextNode.StartPos),
              ' EndPos=',DbgS(ContextNode.EndPos),
              ' Self=',MainFilename);
      DebugLn('  LastCacheEntry(Pos=',DbgS(LastCacheEntry^.CleanStartPos),
              '-',DbgS(LastCacheEntry^.CleanEndPos),')');
      if (Params.NewNode<>nil) then
        DebugLn('   NewTool=',Params.NewCodeTool.MainFilename,
                ' NewNode=',Params.NewNode.DescAsString)
      else
        DebugLn('   cache says: identifier does NOT exist');
      if CompareSrcIdentifiers(Params.Identifier,'TDefineAction') then begin
        NodeCache.WriteDebugReport('NANUNANA: ');
      end;
      {$ENDIF}
      Result:=true;
    end;
  end;
  
  procedure CacheResult(Found: boolean; EndNode: TCodeTreeNode);
  begin
    if not Found then exit;
    FindIdentifierInContext:=true;
    {$IFDEF ShowCollect}
    if fdfCollect in Flags then
      raise Exception.Create('fdfCollect must never return true');
    {$ENDIF}
    {$IFDEF ShowFoundIdentifier}
    debugln(['CacheResult FOUND ',GetIdentifier(Params.Identifier)]);
    Params.WriteDebugReport;
    {$ENDIF}
    if (FirstSearchedNode=nil) then exit;
    if ([fdfDoNotCache,fdfCollect,fdfExtractOperand]*Flags<>[]) then exit;
    if ([fodDoNotCache]*Params.NewFlags<>[]) then exit;
    if (Params.OnIdentifierFound<>@CheckSrcIdentifier) then exit;
    if (Params.FoundProc<>nil) then exit; // do not cache proc searches
    // cache result
    if (Params.NewNode<>nil) and (Params.NewNode.Desc=ctnProcedure) then begin
      DebugLn('NOTE: TFindDeclarationTool.FindIdentifierInContext.CacheResult Node is proc');
      // ToDo:
      // The search range is from start to end of search.
      // This does not work for overloaded procs.
      // -> do not cache
      exit;
    end;
    AddResultToNodeCaches(FirstSearchedNode,EndNode,
                      fdfSearchForward in Flags,Params,SearchRangeFlags);
  end;

  function CheckResult(NewResult, CallOnIdentifierFound: boolean): boolean;
  // returns: true to stop search
  //          false if search should continue
  
    procedure RaiseNotFound;
    var
      Identifier: string;
    begin
      Identifier:=GetIdentifier(Params.Identifier);
      if (Identifier='') and (Params.Identifier<>nil)
      and (Params.Identifier[0]<>#0) then begin
        Identifier:=Params.Identifier[0];
        if Identifier='[' then begin
          Params.IdentifierTool.RaiseException(20170421200103,ctsDefaultPropertyNotFound);
        end;
      end;
      Params.IdentifierTool.RaiseExceptionFmt(20170421200105,ctsIdentifierNotFound,
                                              [Identifier]);
    end;

  begin
    Result:=true;
    FindIdentifierInContext:=NewResult and (not (fdfCollect in Flags));
    {$IFDEF ShowCollect}
    if fdfCollect in Flags then begin
      DebugLn('[TFindDeclarationTool.FindIdentifierInContext.CheckResult] COLLECT CheckResult Ident=',
      '"',GetIdentifier(Params.Identifier),'"',
      ' File="',ExtractFilename(MainFilename)+'"',
      ' Flags=[',dbgs(Flags)+']',
      ' NewResult=',DbgS(NewResult),
      ' CallOnIdentifierFound=',DbgS(CallOnIdentifierFound));
    end;
    {$ENDIF}
    if NewResult then begin
      // identifier found
      {$IFDEF ShowFoundIdentifier}
      debugln(['CheckResult FOUND ',GetIdentifier(Params.Identifier)]);
      Params.WriteDebugReport;
      {$ENDIF}

      if fdfExtractOperand in Flags then
        case Params.NewNode.Desc of
          ctnVarDefinition, ctnConstDefinition:
            with Params do
              AddOperandPart(GetIdentifier(@NewCodeTool.Src[NewNode.StartPos]));
          ctnProperty,ctnGlobalProperty:
            begin
              if fdfPropertyResolving in Flags then begin
                if not PropNodeIsTypeLess(Params.NewNode)
                and ReadTilGetterOfProperty(Params.NewNode) then begin
                  // continue searching of getter
                  Params.Identifier := @Src[CurPos.StartPos];
                end;
                ContextNode := Params.NewNode;
                Exit(False);
              end else
                Params.AddOperandPart(GetIdentifier(Params.Identifier));
            end;
          ctnProcedure:
            begin
              Params.AddOperandPart(ExtractProcName(Params.NewNode,[]));
              // ToDo: add default parameters
            end;
        end;

      if CallOnIdentifierFound then begin
        {debugln(['[TFindDeclarationTool.FindIdentifierInContext.CheckResult] CallOnIdentifierFound Ident=',
        '"',GetIdentifier(Params.Identifier),'"',
        ' StartContext="',StartContextNode.DescAsString,'" "',copy(Src,StartContextNode.StartPos,20),'"',
        ' File="',ExtractFilename(MainFilename)+'"',
        ' Flags=[',dbgs(Flags),']'
        ]);}

        IdentFoundResult:=Params.NewCodeTool.DoOnIdentifierFound(Params,
                                                                Params.NewNode);
        {$IFDEF ShowProcSearch}
        DebugLn(['[TFindDeclarationTool.FindIdentifierInContext.CheckResult] DoOnIdentifierFound=',IdentifierFoundResultNames[IdentFoundResult]]);
        {$ENDIF}
        if (IdentFoundResult=ifrSuccess) then
          CacheResult(true,ContextNode);
        Result:=IdentFoundResult<>ifrProceedSearch;
        if IdentFoundResult<>ifrAbortSearch then exit;
      end else begin
        if fdfCollect in Flags then
          Result:=false;
        CacheResult(true,ContextNode);
        exit;
      end;
    end;
    if Params.FoundProc<>nil then begin
      // there was a proc,
      // either the search for the overloaded proc was unsuccessful
      // or the searched proc was found in a recursive sub search
      // -> return the found proc
      if Params.FoundProc^.CacheValid
      and (Params.FoundProc^.ProcCompatibility=tcExact) then begin
        // stop the search
        Result:=true;
      end;
      FindIdentifierInContext:=true;
      {$IFDEF ShowCollect}
      if fdfCollect in Flags then
        raise Exception.Create('fdfCollect must never return true');
      {$ENDIF}
      Params.SetResult(Params.FoundProc^.Context.Tool,
                       Params.FoundProc^.Context.Node);
      {$IF defined(ShowProcSearch) or defined(ShowFoundIdentifier)}
      DebugLn('[TFindDeclarationTool.FindIdentifierInContext] PROC Search ended with only one proc (normal when searching every used unit):');
      Params.WriteDebugReport;
      {$ENDIF}
      exit;
    end;
    // identifier was not found
    if not (fdfExceptionOnNotFound in Flags) then exit;
    if (Params.Identifier<>nil)
    and not (fdfExceptionOnPredefinedIdent in Flags)
    and WordIsPredefinedIdentifier.DoItCaseInsensitive(Params.Identifier)
    then begin
      Params.SetResult(nil,nil);
      exit;
    end;
    // identifier was not found and exception is wanted
    // -> raise exception
    if Params.IdentifierTool.IsPCharInSrc(Params.Identifier) then
      Params.IdentifierTool.MoveCursorToCleanPos(Params.Identifier);
    RaiseNotFound;
  end;
  
  procedure MoveContextNodeToChildren;
  begin
    if (ContextNode.LastChild<>nil) then begin
      if not (fdfSearchForward in Flags) then begin
        RaiseLastErrorIfInFrontOfCleanedPos(ContextNode.EndPos);
        ContextNode:=ContextNode.LastChild;
      end else
        ContextNode:=ContextNode.FirstChild;
    end;
  end;
  
  function SearchInGenericParams(GenParamsNode: TCodeTreeNode): boolean;
  var
    Node: TCodeTreeNode;
  begin
    Result:=false;
    if (GenParamsNode=nil) or (GenParamsNode.Desc<>ctnGenericParams) then exit;
    Node:=GenParamsNode.FirstChild;
    while Node<>nil do begin
      if (fdfCollect in Flags)
      or CompareSrcIdentifiers(Node.StartPos,Params.Identifier)
      then begin
        {$IFDEF ShowTriedIdentifiers}
        DebugLn('  SearchInGenericParams Identifier found="',GetIdentifier(@Src[Node.StartPos]),'" at '+CleanPosToStr(Node.StartPos));
        {$ENDIF}
        // identifier found
        Params.SetResult(Self,Node);
        Result:=CheckResult(true,true);
        if not (fdfCollect in Flags) then
          exit;
      end;
      Node:=Node.NextBrother;
    end;
  end;

  function SearchInTypeVarConstGlobPropDefinition: boolean;
  // returns: true if ok to exit
  //          false if search should continue
  var
    NameNode: TCodeTreeNode;
  begin
    Result:=false;
    NameNode:=ContextNode;
    if ContextNode.Desc=ctnGenericType then begin
      NameNode:=ContextNode.FirstChild;
      if NameNode=nil then exit;
    end;

    if (fdfCollect in Flags)
    or CompareSrcIdentifiers(NameNode.StartPos,Params.Identifier)
    then begin
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('  Definition Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      // identifier found
      Params.SetResult(Self,ContextNode);
      Result:=CheckResult(true,true);
      if not (fdfCollect in Flags) then begin
        if (fdfSkipClassForward in Flags)
        and (ContextNode.FirstChild<>nil)
        and (ContextNode.FirstChild.Desc in AllClasses)
        and ((ctnsForwardDeclaration and ContextNode.FirstChild.SubDesc)<>0)
        then begin
          FindNonForwardClass(Params);
        end;
        exit;
      end;
    end;
    // search for enums
    Params.ContextNode:=ContextNode;
    if FindEnumInContext(Params) then begin
      Result:=CheckResult(true,false);
    end;
  end;

  function SearchInGenericType: boolean;
  // returns: true if ok to exit
  //          false if search should continue
  var
    NameNode: TCodeTreeNode;
  begin
    Result:=false;
    NameNode:=ContextNode.FirstChild;
    if NameNode=nil then exit;

    // try type name
    if (fdfCollect in Flags)
    or CompareSrcIdentifiers(NameNode.StartPos,Params.Identifier)
    then begin
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('  Definition Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      // identifier found
      Params.SetResult(Self,ContextNode);
      Result:=CheckResult(true,true);
      if not (fdfCollect in Flags) then begin
        if (fdfSkipClassForward in Flags)
        and (ContextNode.LastChild.Desc in AllClasses)
        and ((ctnsForwardDeclaration and ContextNode.LastChild.SubDesc)<>0)
        then begin
          FindNonForwardClass(Params);
        end;
        exit;
      end;
    end;

    // search for enums
    Params.ContextNode:=ContextNode;
    if FindEnumInContext(Params) then begin
      Result:=CheckResult(true,false);
    end;
  end;

  function SearchInTypeOfVarConst: boolean;
  // returns: true if ok to exit
  //          false if search should continue
  begin
    Result:=false;
    //debugln(['SearchInTypeOfVarConst ',ContextNode.Parent.DescAsString]);
    if (ContextNode.Parent.Desc in [ctnConstDefinition,ctnVarDefinition])
    and (Src[ContextNode.StartPos]='(') then
    begin
      if FindIdentifierInTypeOfConstant(ContextNode.Parent,Params) then begin
        Result:=CheckResult(true,false);
      end;
    end;
  end;

  function SearchInEnumLabelDefinition: boolean;
  // returns: true if ok to exit
  //          false if search should continue
  begin
    Result:=false;
    if (fdfCollect in Flags)
    or CompareSrcIdentifiers(ContextNode.StartPos,Params.Identifier)
    then begin
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('  Enum/Label Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      // identifier found
      Params.SetResult(Self,ContextNode);
      Result:=CheckResult(true,true);
      if not (fdfCollect in Flags) then begin
        exit;
      end;
    end;
  end;

  function SearchInOnBlockDefinition: boolean;
  begin
    Result:=false;
    if ContextNode.FirstChild=nil then exit;
    //debugln('SearchInOnBlockDefinition B ',GetIdentifier(@Src[ContextNode.StartPos]));
    if (fdfCollect in Flags)
    or CompareSrcIdentifiers(ContextNode.FirstChild.StartPos,Params.Identifier)
    then begin
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('  ON Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      // identifier found
      Params.SetResult(Self,ContextNode.FirstChild);
      Result:=CheckResult(true,true);
      if not (fdfCollect in Flags) then
        exit;
    end;
  end;

  function SearchInSourceName: boolean;
  // returns: true if ok to exit
  //          false if search should continue
  var
    SrcNode: TCodeTreeNode;
  begin
    Result:=false;
    SrcNode:=Tree.Root;
    MoveCursorToNodeStart(SrcNode);
    ReadNextAtom; // read keyword
    if (SrcNode.Desc=ctnProgram) and (not UpAtomIs('PROGRAM')) then exit;
    ReadNextAtom; // read name
    if (fdfCollect in Flags)
    or CompareSrcIdentifiers(CurPos.StartPos,Params.Identifier) then
    begin
      // identifier found
      {$IFDEF ShowTriedIdentifiers}
      if not (fdfCollect in Flags) then
        DebugLn('  Source Name Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      Params.SetResult(Self,SrcNode,CurPos.StartPos);
      Result:=CheckResult(true,true);
      if not (fdfCollect in Flags) then
        exit;
    end;
  end;
  
  function SearchDefault: boolean;
  begin
    Result:=false;
    if SearchInSourceName then
      exit(true);
    if (not (fdfIgnoreUsedUnits in Flags))
    and FindIdentifierInHiddenUsedUnits(Params) then begin
      Result:=CheckResult(true,false);
    end;
  end;

  function SearchInProperty: boolean;
  // search in ctnProperty, not ctnGlobalProperty
  // returns: true if ok to exit
  //          false if search should continue
  begin
    Result:=false;
    if (fdfCollect in Flags)
    or (Params.Identifier[0]<>'[') then begin
      MoveCursorToNodeStart(ContextNode);
      ReadNextAtom; // read keyword 'property'
      if UpAtomIs('CLASS') then ReadNextAtom;
      ReadNextAtom; // read name
      if (fdfCollect in Flags)
      or CompareSrcIdentifiers(CurPos.StartPos,Params.Identifier) then begin
        // identifier found
        {$IFDEF ShowTriedIdentifiers}
        DebugLn('  Property Identifier found="',GetIdentifier(Params.Identifier),'"');
        {$ENDIF}
        Params.SetResult(Self,ContextNode,CurPos.StartPos);
        Result:=CheckResult(true,true);
      end;
    end else begin
      // the default property is searched
      if PropertyIsDefault(ContextNode) then begin
        Params.SetResult(Self,ContextNode);
        Result:=CheckResult(true,true);
      end;
    end;
  end;
  
  function LeavingContextIsPermitted: boolean;
  begin
    Result:=true;
    if (not ContextNode.HasAsParent(StartContextNode)) then begin
      // searching in a prior node, will leave the start context
      if (not (fdfSearchInParentNodes in Flags)) then begin
        // searching in any parent context is not permitted
        if not ((fdfSearchInAncestors in Flags)
        and (ContextNode.Desc in AllClasses)) then begin
          // even searching in ancestors contexts is not permitted
          // -> there is no prior context accessible any more
          // -> identifier not found
          {$IFDEF ShowTriedContexts}
          DebugLn('[TFindDeclarationTool.FindIdentifierInContext] no prior node accessible ',
          ' ContextNode=',ContextNode.DescAsString,
          ' "',StringToPascalConst(copy(Src,ContextNode.StartPos,15)),'"'
          );
          {$ENDIF}
          ContextNode:=nil;
          Result:=false;
        end;
      end;
    end;
  end;
  
  function SearchInHelpers: Boolean;
  var
    HelperContext: TFindContext;
    Helpers: TFDHelpersList;
    HelperKind: TFDHelpersListKind;
    HelperIterator: TAVLTreeNode;
  begin
    Result := False;
    SearchInHelpersInTheEnd := False;
    if StartContextNode.Desc=ctnObjCClass then
      HelperKind:=fdhlkObjCCategory
    else
      HelperKind:=fdhlkDelphiHelper;
    Helpers:=Params.GetHelpers(HelperKind);
    if Helpers=nil then exit;
    if not Helpers.IterateFromClassNode(StartContextNode,Self,
      HelperContext,HelperIterator) then exit;
    //debugln(['SearchInHelpers START at least one helper found, iterating...']);
    //Helpers.WriteDebugReport;
    repeat
      //debugln(['SearchInHelpers searching in Helper=',FindContextToString(HelperContext),'...']);
      OldFlags := Params.Flags;
      try
        Params.Flags:=Params.Flags
          -[fdfExceptionOnNotFound,fdfIgnoreCurContextNode,fdfSearchInHelpers]
          +[fdfIgnoreUsedUnits];
        Params.ContextNode := HelperContext.Node;

        if HelperContext.Tool.FindIdentifierInContext(Params, IdentFoundResult) then
        begin
          if (IdentFoundResult = ifrAbortSearch)
            or ((IdentFoundResult = ifrSuccess) and CheckResult(true,False))
          then
            Result := True;
        end;
      finally
        Params.Flags := OldFlags;
      end;
    until ((HelperKind=fdhlkDelphiHelper)
      and (Params.StartTool<>nil)
      and not (cmsMultiHelpers in Params.StartTool.Scanner.CompilerModeSwitches))
      or (not Helpers.GetNext(HelperContext,HelperIterator));
    //debugln(['SearchInHelpers END']);
  end;

  function SearchInNamespaces(SourceNamespaceNode: TCodeTreeNode): Boolean;
  // SourceNamespaceNode.Desc = ctnUseUnitNamespace
  // search all use-unit nodes with the same namespace prefix as SourceNamespaceNode
  var
    UnitNode, ThisNamespaceNode, TargetNamespaceNode, UsesNode: TCodeTreeNode;
    Level, CurLevel: Integer;
    InFilename, AnUnitName, FoundNames, FoundName: String;
    NewCodeTool: TFindDeclarationTool;
  begin
    Result := False;
    if SourceNamespaceNode.Desc<>ctnUseUnitNamespace then
      RaiseException(20170426102058,'');
    //debugln(['SearchInNamespaces ',ExtractNode(SourceNamespaceNode.Parent,[]),' ',fdfCollect in Flags]);
    if not (fdfCollect in Flags) then begin
      // search a specific identifier within a use-unit name
      if (SourceNamespaceNode.NextBrother<>nil)
         and (
           (Params.Identifier=nil) or
            CompareSrcIdentifiers(SourceNamespaceNode.NextBrother.StartPos,Params.Identifier))
      then begin
        Params.SetResult(Self,SourceNamespaceNode.NextBrother);
        Result:=CheckResult(true,true);
      end;
      exit;
    end;
    // collect all uses-units with same namespace

    UsesNode:=SourceNamespaceNode.Parent.Parent;

    Level:=1;
    while SourceNamespaceNode.PriorBrother<>nil do begin
      inc(Level);
      SourceNamespaceNode:=SourceNamespaceNode.PriorBrother;
    end;

    FoundNames:='';
    UnitNode := UsesNode.LastChild;
    while UnitNode<>nil do
    begin
      ThisNamespaceNode := SourceNamespaceNode;
      TargetNamespaceNode := UnitNode.FirstChild;
      CurLevel:=0;
      while (ThisNamespaceNode<>nil) and (TargetNamespaceNode<>nil) do
      begin
        if CompareIdentifierPtrs(
          @Src[ThisNamespaceNode.StartPos],
          @Src[TargetNamespaceNode.StartPos]) <> 0
        then Break;
        inc(CurLevel);
        if CurLevel=Level then break;

        ThisNamespaceNode := ThisNamespaceNode.NextBrother;
        TargetNamespaceNode := TargetNamespaceNode.NextBrother;
      end;
      if CurLevel=Level then
      begin
        // namespace paths match
        //debugln(['SearchInNamespaces Match ',ExtractNode(TargetNamespaceNode.Parent,[])]);
        if (TargetNamespaceNode.NextBrother<>nil) then begin
          // prefix matches
          FoundName:='('+GetIdentifier(@Src[TargetNamespaceNode.NextBrother.StartPos])+')';
          if (Pos(FoundName,FoundNames)<1)
          and ((Params.Identifier=nil)
            or CompareSrcIdentifiers(TargetNamespaceNode.NextBrother.StartPos,Params.Identifier))
          then begin
            FoundNames:=FoundNames+FoundName;
            Params.SetResult(Self,TargetNamespaceNode.NextBrother);
            Result:=CheckResult(true,true);
          end;
        end else begin
          // whole unit name matches -> list all interface identifiers
          AnUnitName:=ExtractUsedUnitName(UnitNode,@InFilename);
          NewCodeTool:=FindCodeToolForUsedUnit(AnUnitName,InFilename,true);
          NewCodeTool.FindIdentifierInInterface(Params.IdentifierTool,Params);
        end;
      end;

      if UnitNode.PriorBrother<>nil then
        UnitNode := UnitNode.PriorBrother
      else if UnitNode.Parent.Desc=ctnImplementation then begin
        UnitNode:=FindMainUsesNode;
        if UnitNode=nil then break;
        UnitNode:=UnitNode.LastChild;
      end else
        break;
    end;
  end;

  function SearchNextNode: boolean;
  const
    AbortNoCacheResult = false;
    Proceed = true;
  begin
    repeat
      // search for prior node
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('[TFindDeclarationTool.FindIdentifierInContext.SearchNextNode] Searching prior node of ',ContextNode.DescAsString,' ',dbgstr(copy(Src,ContextNode.StartPos,ContextNode.EndPos-ContextNode.StartPos)));
      {$ENDIF}
      LastSearchedNode:=ContextNode;

      if (ContextNode.Desc in AllClasses) then begin
        // after searching in a class definition ...

        if (ContextNode.PriorBrother<>nil) and (ContextNode.PriorBrother.Desc=ctnGenericParams)
        then begin
          // before searching in the ancestors, search in the generic parameters
          if SearchInGenericParams(ContextNode.PriorBrother) then begin
            FindIdentifierInContext:=true;
            {$IFDEF ShowCollect}
            if fdfCollect in Flags then
              raise Exception.Create('fdfCollect must never return true');
            {$ENDIF}
            exit(AbortNoCacheResult);
          end;
        end;

        //allow ctnRecordType and ctnTypeTypeBeforeHelper: they can have helpers!
        if (fdfSearchInAncestors in Flags) then begin
          // after searching in a class definition, search in its ancestors
          // ToDo: check for cycles in ancestors

          OldFlags := Params.Flags;
          Params.Flags:=Params.Flags-[fdfExceptionOnNotFound,fdfSearchInHelpersInTheEnd];

          // leaving current class -> check if search in helpers in the end
          if SearchInHelpersInTheEnd then
          begin
            Result := SearchInHelpers;
            Params.Flags := OldFlags;
            if Result then
            begin
              FindIdentifierInContext:=true;
              Exit(AbortNoCacheResult);
            end;
          end;

          Exclude(Params.Flags,fdfExceptionOnNotFound);
          Result:=FindIdentifierInAncestors(ContextNode,Params,IdentFoundResult);
          Params.Flags := OldFlags;
          if Result then begin
            FindIdentifierInContext:=true;
            {$IFDEF ShowCollect}
            if fdfCollect in Flags then
              raise Exception.Create('fdfCollect must never return true');
            {$ENDIF}
            exit(AbortNoCacheResult);
          end;
        end;
        // if this was a nested class, the identifier can be in the ancestors
        // of the enclosing class
        Flags:=Flags+[fdfSearchInAncestors];
      end else if ContextNode.Desc=ctnClassInheritance then begin
        if (StartContextNode=ContextNode)
        or StartContextNode.HasAsParent(ContextNode) then
          // searching an ancestor => don't search within ancestors
          Exclude(Flags,fdfSearchInAncestors);
      end;

      if (ContextNode=StartContextNode)
      and (not (fdfSearchInParentNodes in Flags)) then begin
        // startcontext completed => not searching in parents or ancestors
        ContextNode:=nil;
        exit(Proceed);
      end;

      if ((not (fdfSearchForward in Flags))
           and (ContextNode.PriorBrother<>nil))
      or ((fdfSearchForward in Flags)
          and (ContextNode.NextBrother<>nil)
          and (ContextNode.NextBrother.Desc<>ctnImplementation)) then
      begin
        // search next in prior/next brother
        if not (fdfSearchForward in Flags) then
          ContextNode:=ContextNode.PriorBrother
        else begin
          RaiseLastErrorIfInFrontOfCleanedPos(ContextNode.NextBrother.EndPos);
          ContextNode:=ContextNode.NextBrother;
        end;
        {$IFDEF ShowTriedIdentifiers}
        DebugLn('[TFindDeclarationTool.FindIdentifierInContext] Searching in Brother  ContextNode=',ContextNode.DescAsString);
        {$ENDIF}
        // it is not always allowed to search in every node on the same lvl:

        // -> test if class visibility valid
        if ContextNode.Desc in AllClassSections then
          break
        else if ContextNode.Desc=ctnWithVariable then begin
          { check if StartContextNode is covered by the ContextNode
             a WithVariable ranges from the start of its expression
             to the end of the with statement
             for example:
               will be skipped:
                 with ContextNode do ;
                 with B do StartContextNode;

               will be searched:
                 with ContextNode, StartContextNode do ;
          }
          {$IFDEF ShowExprEval}
          DebugLn('SearchNextNode WithVar StartContextNode.StartPos=',dbgs(StartContextNode.StartPos),
            ' ContextNode=',dbgs(ContextNode.StartPos),'-',dbgs(ContextNode.EndPos),
            ' WithStart=',StringToPascalConst(
              copy(copy(Src,ContextNode.StartPos,ContextNode.EndPos-ContextNode.StartPos),1,50)));
          {$ENDIF}
          if (StartContextNode.StartPos>=ContextNode.StartPos)
          and (StartContextNode.StartPos<ContextNode.EndPos) then begin
            {$IFDEF ShowExprEval}
            debugln(['SearchNextNode WithVar covers startcontext']);
            {$ENDIF}
            // for example: with ContextNode, StartContextNode do ;
            break;
          end else begin
            // this with statement does not cover the startcontext. For instance:
            //   with ContextNode do ;
            //   with B do StartContextNode;
            // -> skip it
          end;
        end else if ContextNode.Desc=ctnOnBlock then begin
          // the ctnOnIdentifier is only valid within the ctnOnStatement
          // => skip
        end else begin
          break;
        end;
      end else if (ContextNode.Parent<>nil)
      and ((fdfSearchInParentNodes in Flags)
        or (ContextNode.HasAsParent(StartContextNode))) then
      begin
        // search next in parent
        {$IFDEF ShowTriedParentContexts}
        DebugLn('[TFindDeclarationTool.FindIdentifierInContext] Searching in Parent ',
          ' old ContextNode=',ContextNode.DescAsString,
          ' new ContextNode=',ContextNode.Parent.DescAsString
          );
        {$ENDIF}
        ContextNode:=ContextNode.Parent;

        case ContextNode.Desc of

        ctnTypeSection, ctnVarSection, ctnConstSection, ctnResStrSection,
        ctnLabelSection, ctnPropertySection,
        ctnInterface, ctnImplementation, ctnProgram, ctnLibrary,
        ctnClassPublished,ctnClassPublic,ctnClassProtected,ctnClassPrivate,
        ctnClassClassVar,
        ctnRecordVariant,
        ctnProcedureHead, ctnParameterList,
        ctnClassInheritance,ctnHelperFor:
          // these codetreenodes build a parent-child-relationship, but
          // for pascal it is only a range, hence after searching in the
          // children of the last node, search must continue in the children
          // of the prior node
          ;

        ctnClass, ctnClassInterface, ctnDispinterface, ctnObject,
        ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass,
        ctnRecordType, ctnRecordCase,
        ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
        ctnEnumerationType:
          // do not search again in this node, go on ...
          ;
          
        ctnVarDefinition, ctnConstDefinition:
          if (ContextNode.Parent<>nil)
          and (ContextNode.Parent.Desc=ctnParameterList) then begin
            // pascal allows declarations like: 'var a: a;' in parameters
            // -> skip variable and search in next context node
            ;
          end else begin
            break;
          end;

        ctnProcedure:
          begin
            Result:=FindIdentifierInClassOfMethod(ContextNode,Params);
            if Result then begin
              FindIdentifierInContext:=true;
              {$IFDEF ShowCollect}
              if fdfCollect in Flags then
                raise Exception.Create('fdfCollect must never return true');
              {$ENDIF}
              exit(AbortNoCacheResult);
            end;
          end;

        else
          break;
        end;
      end else begin
        ContextNode:=nil;
        break;
      end;
    until false;
    Result:=Proceed;
  end;
  
begin
  Result:=false;
  InitNodesAndCacheAccess;

  {$IFDEF ShowTriedContexts}
  DebugLn('[TFindDeclarationTool.FindIdentifierInContext] Start Ident=',
  '"'+GetIdentifier(Params.Identifier)+'"',
  ' Context="'+ContextNode.DescAsString+'" "'+StringToPascalConst(copy(Src,ContextNode.StartPos,20)),'"',
  ' at '+CleanPosToStr(ContextNode.StartPos,true),
  ' Flags=['+dbgs(Flags)+']'
  );
  {$ELSE}
    {$IFDEF ShowCollect}
    if fdfCollect in Flags then begin
      DebugLn(['[TFindDeclarationTool.FindIdentifierInContext] COLLECT Start Ident=',
      '"',GetIdentifier(Params.Identifier),'"',
      ' Context="',ContextNode.DescAsString,'" "',copy(Src,ContextNode.StartPos,20),'"',
      ' at '+CleanPosToStr(ContextNode.StartPos,true),
      ' Flags=[',dbgs(Flags),']'
      ]);
    end;
    {$ENDIF}
  {$ENDIF}

  if (ContextNode.Desc=ctnInterface)
  and (fdfIgnoreUsedUnits in Flags) then begin
    {$IFDEF ShowTriedContexts}
    DebugLn(['TFindDeclarationTool.FindIdentifierInContext searching in interface of ',MainFilename]);
    {$ENDIF}
    Result:=FindIdentifierInInterface(Params.IdentifierTool,Params);
    CheckResult(Result,false);
    exit;
  end;

  if (ContextNode.Desc=ctnUseUnitNamespace) then
  begin
    //search in namespaces
    //debugln(['TFindDeclarationTool.FindIdentifierInContext NameSpace ',GetIdentifier(Params.Identifier),' ',ExtractNode(ContextNode,[])]);
    if SearchInNamespaces(ContextNode) then exit;
    Exit;
  end;

  // find class helper functions
  SearchInHelpersInTheEnd := False;
  if (fdfSearchInHelpers in Flags)
    and (ContextNode.Desc in [ctnClass,ctnRecordType,ctnTypeType,ctnObjCClass,ctnEnumerationType,ctnRangedArrayType,ctnOpenArrayType])
    and (ContextNode.Parent<>nil) and (ContextNode.Parent.Desc = ctnTypeDefinition)
  then begin
    if (fdfSearchInHelpersInTheEnd in Flags) then
      SearchInHelpersInTheEnd := True
    else begin
      if SearchInHelpers then Exit;
    end;
  end;

  //try
    // search in the Tree of this tool
    repeat
      {$IFDEF ShowTriedIdentifiers}
      DebugLn('[TFindDeclarationTool.FindIdentifierInContext] Loop Ident=',
      '"',GetIdentifier(Params.Identifier),'"',
      ' Context="',ContextNode.DescAsString,'" "',copy(Src,ContextNode.StartPos,20),'"',
      ' Flags=[',dbgs(Flags),']'
      );
      {$ELSE}
        {$IFDEF ShowCollect}
        if fdfCollect in Flags then begin
          DebugLn('[TFindDeclarationTool.FindIdentifierInContext] COLLECT Loop Ident=',
          '"',GetIdentifier(Params.Identifier),'"',
          ' Context="',ContextNode.DescAsString,'" "',copy(Src,ContextNode.StartPos,20),'"',
          ' Flags=[',dbgs(Flags),']'
          );
        end;
        {$ENDIF}
      {$ENDIF}
      // search identifier in current context
      LastContextNode:=ContextNode;
      if not (fdfIgnoreCurContextNode in Flags) then begin
        // search in cache
        if FindInNodeCache then begin
          if CheckResult(Params.NewNode<>nil,Params.NewNode<>nil) then
            exit;
        end;
        if FirstSearchedNode=nil then FirstSearchedNode:=ContextNode;
        LastSearchedNode:=ContextNode;

        case ContextNode.Desc of

        ctnTypeSection, ctnVarSection, ctnConstSection, ctnResStrSection,
        ctnLabelSection, ctnPropertySection,
        ctnInterface, ctnImplementation,
        ctnProgram, ctnLibrary,
        ctnClassPublic, ctnClassPrivate, ctnClassProtected, ctnClassPublished,
        ctnClassClassVar,
        ctnClass, ctnClassInterface, ctnDispinterface, ctnObject,
        ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass,
        ctnRecordType, ctnRecordVariant,
        ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
        ctnEnumerationType,
        ctnParameterList:
          // these nodes build a parent-child relationship. But in pascal
          // they just define a range and not a context.
          // -> search in all children
          MoveContextNodeToChildren;

        ctnTypeDefinition, ctnVarDefinition, ctnConstDefinition,
        ctnGlobalProperty:
          if SearchInTypeVarConstGlobPropDefinition then exit;

        ctnGenericType:
          if SearchInGenericType then exit;
        // ctnGenericParams: skip here, it was searched before searching the ancestors

        ctnIdentifier:
          if (ContextNode.Parent.Desc in [ctnConstDefinition,ctnVarDefinition])
              and (ContextNode=ContextNode.Parent.LastChild)
              and SearchInTypeOfVarConst then
            exit;

        ctnEnumIdentifier,ctnLabel:
          if SearchInEnumLabelDefinition then exit;

        ctnProcedure:
          begin
            IdentifierFoundResult:=
              FindIdentifierInProcContext(ContextNode,Params);
            if IdentifierFoundResult in [ifrAbortSearch,ifrSuccess] then begin
              if CheckResult(IdentifierFoundResult=ifrSuccess,true) then begin
                {$IFDEF ShowProcSearch}
                DebugLn(['TFindDeclarationTool.FindIdentifierInContext ctnProcedure FOUND, stopping']);
                {$ENDIF}
                exit;
              end;
              {$IFDEF ShowProcSearch}
              DebugLn(['TFindDeclarationTool.FindIdentifierInContext ctnProcedure FOUND, continue']);
              {$ENDIF}
            end;
          end;

        ctnProcedureHead:
          begin
            BuildSubTreeForProcHead(ContextNode);
            if ContextNode.FirstChild<>nil then
              ContextNode:=ContextNode.FirstChild; // the ctnParameterList
          end;

        ctnProperty:
          if SearchInProperty then exit;
          
        ctnUsesSection:
          begin
            if FindIdentifierInUsesSection(ContextNode,Params,True)
            and CheckResult(true,false) then
              exit;
          end;

        ctnWithVariable:
          begin
            if FindIdentifierInWithVarContext(ContextNode,Params)
            and CheckResult(true,false) then
              exit;
          end;
          
        ctnOnBlock:
          if SearchInOnBlockDefinition then exit;

        ctnPointerType,ctnClassOfType:
          begin
            // pointer and class-of can be forward definitions
            // -> search in both directions
            Params.ContextNode:=ContextNode.Parent;
            if CheckResult(FindForwardIdentifier(Params,IsForward),false) then
              exit;
          end;

        ctnRecordCase:
          begin
            // search in variable and variants
            MoveContextNodeToChildren;
          end;
          
        end;
      end else begin
        Exclude(Params.Flags,fdfIgnoreCurContextNode);
        Exclude(Flags,fdfIgnoreCurContextNode);
        {$IFDEF ShowTriedContexts}
        DebugLn('[TFindDeclarationTool.FindIdentifierInContext] IgnoreCurContext ');
        {$ENDIF}
      end;
      if LastContextNode=ContextNode then begin
        // no special context switch => search next node
        if not LeavingContextIsPermitted then break;
        if not SearchNextNode then exit;
      end;
    until ContextNode=nil;

    if SearchInHelpersInTheEnd then
    begin
      if SearchInHelpers then Exit;
    end;

    if LastSearchedNode=Tree.Root then begin
      if SearchDefault then exit;
    end;

  {except
    // unexpected exception
    on E: Exception do begin
      DebugLn('*** Unexpected Exception during find declaration: ',
        E.ClassName,': ',E.Message);
      DebugLn('  MainFilename=',MainFilename);
      raise;
    end;
  end;}
  // if we are here, the identifier was not found and there was no error
  if (FirstSearchedNode<>nil) and (Params.FoundProc=nil)
  and ([fdfCollect,fdfExtractOperand]*Flags=[]) then begin
    // add result to cache
    Params.NewNode:=nil;
    Params.NewCodeTool:=nil;
    AddResultToNodeCaches(FirstSearchedNode,LastSearchedNode,
                    fdfSearchForward in Flags,Params,SearchRangeFlags);
  end;
  CheckResult(false,false);
end;

function TFindDeclarationTool.FindEnumInContext(
  Params: TFindDeclarationParams): boolean;
{ search all subnodes for ctnEnumIdentifier

  Params:
    Identifier
    ContextNode  // = DeepestNode at Cursor

  Result:
    true, if enum found
 }
var OldContextNode, CurContextNode: TCodeTreeNode;
  CollectResult: TIdentifierFoundResult;
  SearchEnumIdentifiers: Boolean;
begin
  Result:=false;
  CurContextNode:=Params.ContextNode;
  if CurContextNode=nil then exit;
  if CurContextNode.Desc=ctnEnumerationType then
    SearchEnumIdentifiers := not (Scanner.GetDirectiveValueAt(sdScopedEnums, CurContextNode.StartPos) = '1')
  else
    SearchEnumIdentifiers := False;
  CurContextNode:=CurContextNode.FirstChild;
  while CurContextNode<>nil do begin
    if SearchEnumIdentifiers and (CurContextNode.Desc=ctnEnumIdentifier) then begin
      if (fdfCollect in Params.Flags) then begin
        //debugln('TFindDeclarationTool.FindEnumInContext ',GetIdentifier(@Src[CurContextNode.StartPos]));
        CollectResult:=DoOnIdentifierFound(Params,CurContextNode);
        if CollectResult=ifrAbortSearch then begin
          Result:=false;
          exit;
        end else if CollectResult=ifrSuccess then begin
          Result:=true;
          Params.SetResult(Self,CurContextNode);
          exit;
        end;
      end else if CompareSrcIdentifiers(CurContextNode.StartPos,Params.Identifier)
      then begin
        // identifier found
        Result:=true;
        Params.SetResult(Self,CurContextNode);
        exit;
      end;
    end;
    if CurContextNode.FirstChild<>nil then begin
      OldContextNode:=Params.ContextNode;
      Params.ContextNode:=CurContextNode;
      Result:=FindEnumInContext(Params);
      Params.ContextNode:=OldContextNode;
      if Result then exit;
    end;
    CurContextNode:=CurContextNode.NextBrother;
  end;
end;

function TFindDeclarationTool.FindContextNodeAtCursor(
  Params: TFindDeclarationParams): TFindContext;
{ searches for the context node at a specific cursor pos
  Params.Context should contain the deepest node at cursor
  if there is no special context, then result is equal to Params.Context }
var
  EndPos: integer;
  ExprType: TExpressionType;
  OldFlags: TFindDeclarationFlags;
begin
  EndPos:=CurPos.StartPos;
  OldFlags:=Params.Flags;
  Params.Flags:=Params.Flags-[fdfFindVariable];
  ExprType:=FindExpressionTypeOfTerm(-1,EndPos,Params,false);
  Params.Flags:=OldFlags;
  if (ExprType.Desc=xtContext) then
    Result:=ExprType.Context
  else begin
    Result:=CleanFindContext;
    if fdfExceptionOnNotFound in Params.Flags then begin
      MoveCursorToCleanPos(EndPos);
      RaiseException(20170421200111,ctsNoContextNodeFoundAtCursor);
    end;
  end;
end;

function TFindDeclarationTool.FindBaseTypeOfNode(
  Params: TFindDeclarationParams; Node: TCodeTreeNode; AliasType: PFindContext;
  NodeStack: PCodeTreeNodeStack): TFindContext;
var
  MyNodeStack: TCodeTreeNodeStack;

  procedure RaiseForwardClassNameLess;
  begin
    RaiseException(20170421200114,'[TFindDeclarationTool.FindBaseTypeOfNode] '
                  +'forward class node without name');
  end;
  
  procedure RaiseCircleDefs;
  begin
    Params.NewCodeTool.RaiseException(20170421200117,ctsCircleInDefinitions
      +' ('+ctsIdentifier+'='+GetIdentifier(Params.Identifier)+')');
  end;
  
  procedure RaiseInternalError;
  begin
    Params.IdentifierTool.RaiseException(20170421200121,
       '[TFindDeclarationTool.FindBaseTypeOfNode]'
      +' internal error: not IsPCharInSrc(Params.Identifier) '
      +' Params.IdentifierTool.='
              +TCodeBuffer(Params.IdentifierTool.Scanner.MainCode).Filename
      +' Ident="'+GetIdentifier(Params.Identifier)+'"');
  end;
  
  procedure RaiseBaseTypeOfNotFound;
  begin
    RaiseExceptionFmt(20170421200124,ctsBaseTypeOfNotFound,[GetIdentifier(Params.Identifier)]);
  end;
  
  procedure RaiseClassOfWithoutIdentifier;
  begin
    RaiseExceptionFmt(20170421200133,ctsBaseTypeOfNotFound+' ("class of")',
                      [GetIdentifier(Params.Identifier)]);
  end;

  procedure RaiseForwardNotResolved(ClassIdentNode: TCodeTreeNode);
  begin
    RaiseExceptionFmt(20170421200136,ctsForwardClassDefinitionNotResolved,
        [copy(Src,ClassIdentNode.StartPos,
            ClassIdentNode.EndPos-ClassIdentNode.StartPos)]);
  end;
  
  procedure RaiseClassOfNotResolved(ClassIdentNode: TCodeTreeNode);
  begin
    MoveCursorToNodeStart(ClassIdentNode);
    RaiseExceptionFmt(20170421200141,ctsClassOfDefinitionNotResolved,
        [copy(Src,ClassIdentNode.StartPos,
            ClassIdentNode.EndPos-ClassIdentNode.StartPos)]);
  end;

  procedure SearchIdentifier(StartNode: TCodeTreeNode; CleanPos: integer;
    out IsPredefined: boolean; var Context: TFindContext);
  var
    TypeFound: Boolean;
    TestContext: TFindContext;
    IdentStart: LongInt;
    SubParams: TFindDeclarationParams;
    ExprType: TExpressionType;
  begin
    IsPredefined:=false;

    SubParams:=TFindDeclarationParams.Create(Params);
    try
      SubParams.GenParams := Params.GenParams;
      IdentStart:=CleanPos;
      {$IFDEF ShowTriedBaseContexts}
      debugln(['TFindDeclarationTool.FindBaseTypeOfNode.SearchIdentifier Identifier=',GetIdentifier(@Src[IdentStart])]);
      {$ENDIF}
      SubParams.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound]
                      +(fdfGlobals*SubParams.Flags);
      SubParams.ContextNode:=StartNode.Parent;
      if (SubParams.ContextNode.Desc in (AllIdentifierDefinitions))
      then begin
        // pascal allows things like 'var a: a;' -> skip var definition
        Include(SubParams.Flags,fdfIgnoreCurContextNode);
      end;
      if SubParams.ContextNode.Desc=ctnParameterList then
        // skip search in parameter list
        SubParams.ContextNode:=SubParams.ContextNode.Parent;
      if SubParams.ContextNode.Desc=ctnProcedureHead then
        // skip search in proc parameters
        SubParams.ContextNode:=SubParams.ContextNode.Parent;

      MoveCursorToCleanPos(CleanPos);
      ReadNextAtom;
      ReadNextAtom;
      if (CurPos.Flag=cafPoint) or AtomIsChar('<') then begin
        // this is an expression, e.g. A.B or A<B>
        Include(SubParams.Flags,fdfFindVariable);
        ExprType:=FindExpressionTypeOfTerm(CleanPos,-1,SubParams,false);
        if ExprType.Desc=xtContext then begin
          if not (ExprType.Context.Node.Desc in [ctnTypeDefinition,ctnGenericType,ctnGenericParameter]) then
          begin
            // not a type
            {$IFDEF ShowTriedBaseContexts}
            debugln(['TFindDeclarationTool.FindBaseTypeOfNode.SearchIdentifier expression: type expected but found ',ExprTypeToString(ExprType)]);
            {$ENDIF}
            MoveCursorToCleanPos(IdentStart);
            ReadNextAtom;
            RaiseExceptionFmt(20170421200144,ctsStrExpectedButAtomFound,
                              [ctsTypeIdentifier,GetAtom]);
          end;
          Context:=ExprType.Context;
        end else begin
          IsPredefined:=true;
        end;
        exit;
      end;

      SubParams.SetIdentifier(Self,@Src[IdentStart],nil);
      TypeFound:=FindIdentifierInContext(SubParams);
      if TypeFound and (SubParams.NewNode.Desc in [ctnUnit,ctnLibrary,ctnPackage])
      then begin
        // identifier is a unit
        // => type expected
        MoveCursorToCleanPos(IdentStart);
        ReadNextAtom; // read AUnitName
        SaveRaiseCharExpectedButAtomFound(20170421200146,'.');
      end;
      if TypeFound and (SubParams.NewNode.Desc=ctnGenericParameter) then begin
        TypeFound:=SubParams.FindGenericParamType;
      end;
      if TypeFound then begin
        // only types allowed here
        TestContext.Tool:=SubParams.NewCodeTool;
        TestContext.Node:=SubParams.NewNode;
        if not (TestContext.Node.Desc in [ctnTypeDefinition,ctnGenericType,ctnGenericParameter]) then
        begin
          // not a type
          {$IFDEF ShowTriedBaseContexts}
          debugln(['TFindDeclarationTool.FindBaseTypeOfNode.SearchIdentifier expected type but found ',TestContext.Node.DescAsString]);
          {$ENDIF}
          MoveCursorToCleanPos(IdentStart);
          ReadNextAtom;
          RaiseExceptionFmt(20170421200149,ctsStrExpectedButAtomFound,
                            [ctsTypeIdentifier,GetAtom]);
        end;
        Context:=TestContext;
        {$IFDEF ShowTriedBaseContexts}
        debugln(['TFindDeclarationTool.FindBaseTypeOfNode.SearchIdentifier found ',GetIdentifier(@Src[IdentStart]),' Node=',Context.Node.DescAsString,' ',Context.Tool.CleanPosToStr(Context.Node.StartPos,true)]);
        {$ENDIF}
      end else begin
        // predefined identifier
        IsPredefined:=true;
      end;

    finally
      SubParams.Free;
    end;
  end;

  procedure CheckResult(var Context: TFindContext);
  var
    ResultNode: TCodeTreeNode;
    OldFlags: TFindDeclarationFlags;
    AliasContext: TFindContext;
    Cache: TBaseTypeCache;
  begin
    if (NodeStack<>nil) and (NodeStack<>@MyNodeStack) then exit; // will be handled by caller

    if (Context.Node<>nil) and (Context.Node.Desc in [ctnProcedure,ctnProcedureHead])
    and (fdfFunctionResult in Params.Flags) then begin
      // Note: do not resolve a constructor here
      //       because TMyClass.Create should return TMyClass
      //       and not TObject, where the Create is defined
      // a proc -> if this is a function then return the Context type
      //debugln(['TFindDeclarationTool.FindBaseTypeOfNode checking function Context: ',Context.Tool.ExtractNode(Context.Node,[])]);
      Context.Tool.BuildSubTreeForProcHead(Context.Node,ResultNode);
      if (ResultNode<>nil) then begin
        // a function or an overloaded operator
        // search further for the base type of the function Context type
        OldFlags:=Params.Flags;
        Exclude(Params.Flags,fdfFunctionResult);
        //debugln(['TFindDeclarationTool.FindBaseTypeOfNode searching for function Context type: ',Context.Tool.ExtractNode(DummyNode,[])]);
        Context:=Context.Tool.FindBaseTypeOfNode(Params,ResultNode,AliasType);
        AliasType:=nil;  // aliasing has been done
        Params.Flags:=OldFlags;
        exit;
      end;
    end;
    if (Context.Node=nil) and (fdfExceptionOnNotFound in Params.Flags) then begin
      if (Context.Tool<>nil) and (Params.Identifier<>nil) then begin

        // ToDo ppu, dcu

        if (not Params.IdentifierTool.IsPCharInSrc(Params.Identifier)) then
          RaiseInternalError;
        Params.IdentifierTool.MoveCursorToCleanPos(Params.Identifier);
      end;
      RaiseBaseTypeOfNotFound;
    end;
    if AliasType<>nil then begin
      // follow the base type chain to the first type
      // for example: var d: TDateTime;  use TDateTime, instead of Double.
      AliasContext.Node:=Node;
      AliasContext.Tool:=Self;
      while AliasContext.Node<>nil do begin
        if AliasContext.Node.Desc in [ctnTypeDefinition,ctnGenericType] then begin
          {$IF defined(ShowExprEval) or defined(ShowTriedBaseContexts)}
          debugln(['TFindDeclarationTool.FindBaseTypeOfNode.CheckResult using alias ',AliasContext.Tool.ExtractDefinitionName(AliasContext.Node),' instead of base type ',Context.Node.DescAsString]);
          {$ENDIF}
          AliasType^:=AliasContext;
          exit;
        end;
        if AliasContext.Node.Cache is TBaseTypeCache then begin
          Cache:=TBaseTypeCache(AliasContext.Node.Cache);
          if AliasContext.Node=Cache.NextNode then break;
          AliasContext.Node:=Cache.NextNode;
          AliasContext.Tool:=TFindDeclarationTool(Cache.NextTool);
        end else
          break;
      end;
    end;
  end;

var
  OldInput: TFindDeclarationInput;
  ClassIdentNode: TCodeTreeNode;
  TestContext: TFindContext;
  OldPos: integer;
  SpecializeNode: TCodeTreeNode;
  NameNode: TCodeTreeNode;
  IsPredefined: boolean;
  OldStartFlags: TFindDeclarationFlags;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  //debugln(['TFindDeclarationTool.FindBaseTypeOfNode Flags=[',dbgs(Params.Flags),'] CacheValid=',Node.Cache is TBaseTypeCache]);
  if (Node<>nil) and (Node.Cache is TBaseTypeCache) then begin
    // base type already cached
    Result:=CreateFindContext(TBaseTypeCache(Node.Cache));
    CheckResult(Result);
    exit;
  end;

  Result.Node:=Node;
  Result.Tool:=Self;
  OldStartFlags:=Params.Flags;
  Exclude(Params.Flags,fdfTopLvlResolving);
  if NodeStack=nil then begin
    NodeStack:=@MyNodeStack;
    InitializeNodeStack(NodeStack);
  end;
  try
    while (Result.Node<>nil) do begin
      if (Result.Node.Cache is TBaseTypeCache) then begin
        // base type already cached
        if NodeStack^.StackPtr>=0 then
          AddNodeToStack(NodeStack,Result.Tool,Result.Node);
        Result:=CreateFindContext(TBaseTypeCache(Result.Node.Cache));
        break;
      end;
      {$IFDEF ShowTriedBaseContexts}
      DebugLn('[TFindDeclarationTool.FindBaseTypeOfNode] LOOP Result=',Result.Node.DescAsString,' ',Result.Tool.CleanPosToStr(Result.Node.StartPos,true),' Flags=[',dbgs(Params.Flags),']');
      {$ENDIF}
      if NodeExistsInStack(NodeStack,Result.Node) then begin
        // cycle detected
        Result.Tool.MoveCursorToNodeStart(Result.Node);
        Result.Tool.RaiseException(20170421200151,ctsCircleInDefinitions);
      end;
      {$IFDEF CheckNodeTool}Result.Tool.CheckNodeTool(Result.Node);{$ENDIF}

      if Result.Tool<>Self then begin
        {$IFDEF ShowTriedBaseContexts}
        DebugLn(['[TFindDeclarationTool.FindBaseTypeOfNode] continuing in ',Result.Tool.MainFilename]);
        {$ENDIF}
        Result:=Result.Tool.FindBaseTypeOfNode(Params,Result.Node,AliasType,NodeStack);
        break;
      end;

      AddNodeToStack(NodeStack,Result.Tool,Result.Node);

      if (Result.Node.Desc in (AllSimpleIdentifierDefinitions+[ctnGenericType]))
      then begin
        // instead of variable/const/type definition, return the type
        TestContext.Node:=FindTypeNodeOfDefinition(Result.Node);
        if TestContext.Node=nil then
          // some constants and variants do not have a type
          break;
        Result.Node:=TestContext.Node;
      end else
      if (Result.Node.Desc in AllClasses)
      and ((Result.Node.SubDesc and ctnsForwardDeclaration)>0) then
      begin
        // this is a forward defined class
        // -> search the real class
        {$IFDEF ShowTriedBaseContexts}
        DebugLn('[TFindDeclarationTool.FindBaseTypeOfNode] Class is forward');
        {$ENDIF}

        // ToDo: check for cycles in ancestor chain
        
        ClassIdentNode:=Result.Node.Parent;
        if (ClassIdentNode=nil)
        or (not (ClassIdentNode.Desc in [ctnTypeDefinition,ctnGenericType]))
        then begin
          MoveCursorToCleanPos(Result.Node.StartPos);
          RaiseForwardClassNameLess;
        end;
        Params.Save(OldInput);
        Params.SetIdentifier(Self,@Src[ClassIdentNode.StartPos],
                             @CheckSrcIdentifier);
        Params.Flags:=[fdfSearchInParentNodes,fdfSearchForward,
                       fdfIgnoreUsedUnits,fdfExceptionOnNotFound,
                       fdfIgnoreCurContextNode]
                      +(fdfGlobals*Params.Flags);
        Params.ContextNode:=ClassIdentNode;
        FindIdentifierInContext(Params);
        if (not (Params.NewNode.Desc in [ctnTypeDefinition,ctnGenericType]))
        or (Params.NewCodeTool<>Self) then begin
          MoveCursorToCleanPos(Result.Node.StartPos);
          RaiseForwardNotResolved(ClassIdentNode);
        end;
        Result.Tool:=Params.NewCodeTool;
        Result.Node:=Params.NewNode;
        Params.Load(OldInput,true);
      end else
      if (Result.Node.Desc=ctnClassOfType) and (fdfFindChildren in Params.Flags)
      then begin
        // this is a 'class of' type
        // -> search the real class
        {$IFDEF ShowTriedBaseContexts}
        DebugLn('[TFindDeclarationTool.FindBaseTypeOfNode] "Class Of"');
        {$ENDIF}

        // ToDo: check for cycles in ancestor chain

        ClassIdentNode:=Result.Node.FirstChild;
        if (ClassIdentNode=nil) or (not (ClassIdentNode.Desc=ctnIdentifier))
        then begin
          MoveCursorToCleanPos(Result.Node.StartPos);
          RaiseClassOfWithoutIdentifier;
        end;
        Params.Save(OldInput);
        // first search backwards
        Params.SetIdentifier(Self,@Src[ClassIdentNode.StartPos],
                             @CheckSrcIdentifier);
        Params.Flags:=[fdfSearchInParentNodes,
                       fdfIgnoreCurContextNode]
                      +(fdfGlobals*Params.Flags)-[fdfExceptionOnNotFound];
        Params.ContextNode:=Result.Node.Parent;
        if not FindIdentifierInContext(Params) then begin
          // then search forwards
          Params.Load(OldInput,false);
          Params.SetIdentifier(Self,@Src[ClassIdentNode.StartPos],
                               @CheckSrcIdentifier);
          Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound,
                         fdfIgnoreCurContextNode,fdfSearchForward]
                        +(fdfGlobals*Params.Flags);
          Params.ContextNode:=Result.Node.Parent;
          FindIdentifierInContext(Params);
        end;
        if not (Params.NewNode.Desc in [ctnTypeDefinition,ctnGenericType]) then
        begin
          MoveCursorToCleanPos(Result.Node.StartPos);
          RaiseClassOfNotResolved(ClassIdentNode);
        end;
        Result.Tool:=Params.NewCodeTool;
        Result.Node:=Params.NewNode;
        Params.Load(OldInput,true);
      end else
      if (Result.Node.Desc=ctnOnIdentifier) and (Result.Node.PriorBrother=nil)
      then begin
        // this is the ON variable node, the type comes right behind
        Result.Node:=Result.Node.NextBrother;
      end else if Result.Node.Desc=ctnSrcName then begin
        break;
      end else if (Result.Node.Desc=ctnIdentifier)
      and (Result.Node.Parent.Desc=ctnSrcName) then begin
        if (Result.Node.NextBrother=nil) then
          Result.Node:=Result.Node.Parent;
        break;
      end else
      if (Result.Node.Desc in [ctnIdentifier,ctnOnIdentifier])
      then begin
        // this type is just an alias for another type
        // -> search the basic type
        if Result.Node.Parent=nil then
          break;
        SearchIdentifier(Result.Node,Result.Node.StartPos,IsPredefined,Result);
        if IsPredefined then break;
      end else
      if (Result.Node.Desc=ctnProperty)
      or (Result.Node.Desc=ctnGlobalProperty) then begin
        // this is a property -> search the type definition of the property
        if MoveCursorToPropType(Result.Node) then begin
          // property has a type
          SearchIdentifier(Result.Node,CurPos.StartPos,IsPredefined,Result);
          if IsPredefined then break;
        end else if (Result.Node.Desc=ctnProperty) then begin
          // property has no type
          // -> search ancestor property
          Params.Save(OldInput);
          if not MoveCursorToPropName(Result.Node) then break;
          OldPos:=CurPos.StartPos;
          Params.SetIdentifier(Self,@Src[CurPos.StartPos],nil);
          Params.Flags:=[fdfExceptionOnNotFound,fdfSearchInAncestors,fdfSearchInHelpers]
                       +(fdfGlobalsSameIdent*Params.Flags);
          FindIdentifierInAncestors(Result.Node.Parent.Parent,Params);
          TestContext.Tool:=Params.NewCodeTool;
          TestContext.Node:=Params.NewNode;
          Params.Load(OldInput,true);
          if Params.NewNode.Desc<>ctnProperty then begin
            // ancestor is not a property
            MoveCursorToCleanPos(OldPos);
            RaiseException(20170421200153,ctsAncestorIsNotProperty);
          end;
          Result:=TestContext;
        end else
          break;
      end else
      if Result.Node.Desc=ctnProcedure then begin
        Result.Node:=Result.Node.FirstChild;
        break;
      end else
      if Result.Node.Desc=ctnProcedureHead then begin
        break;
      end else
      if (Result.Node.Desc=ctnTypeType) then begin
        if fdfTypeType in Params.Flags then
          break; // the type node is wanted, not its real type
        // a TypeType is for example 'MyInt = type integer;'
        // the context is not the 'type' keyword, but the identifier after it.
        Result.Node:=Result.Node.FirstChild;
      end else
      if (Result.Node.Desc=ctnEnumIdentifier) then begin
        // an enum identifier
        if fdfEnumIdentifier in Params.Flags then
          break; // the enum is wanted, not its type
        // an enum identifier, the base type is the enumeration
        Result.Node:=Result.Node.Parent;
      end else
      if (Result.Node.Desc=ctnSpecialize) then begin
        // go to the type name of the specialisation
        SpecializeNode:=Result.Node;
        NameNode:=SpecializeNode.FirstChild;
        Result.Node:=NameNode;
        if Result.Node=nil then break;
        Params.SetGenericParamValues(Self, SpecializeNode);
        Params.UpdateGenericParamMapping(Self, SpecializeNode.FirstChild.NextBrother, Nil);
        SearchIdentifier(SpecializeNode,NameNode.StartPos,IsPredefined,Result);
        if (Result.Node=nil) or (Result.Node.Desc<>ctnGenericType) then begin
          // not a generic
          MoveCursorToNodeStart(NameNode);
          ReadNextAtom;
          RaiseExceptionFmt(20170421200156,ctsStrExpectedButAtomFound,
                            [ctsGenericIdentifier,GetAtom]);
        end;
      end else
        break;
    end;

    Params.Flags:=OldStartFlags;
  finally
    if NodeStack=@MyNodeStack then begin
      // cache the result in all nodes
      // do not cache the result of generic type
      if not Assigned(Params.GenParams.ParamValuesTool) then
        CreateBaseTypeCaches(NodeStack,Result);
      // free node stack
      FinalizeNodeStack(NodeStack);
    end;
  end;

  CheckResult(Result);

  {$IFDEF ShowFoundIdentifier}
  Debugln(['[TFindDeclarationTool.FindBaseTypeOfNode] END Node=',Node.DescAsString,' Result=',Result.Node.DescAsString]);
  {$ENDIF}
end;

function TFindDeclarationTool.FindIdentifierInBasicTypeHelpers(
  ExprType: TExpressionTypeDesc; Params: TFindDeclarationParams): Boolean;
var
  OldFlags: TFindDeclarationFlags;
  FullExprType: TExpressionType;
  CHContext: TFindContext;
  Helpers: TFDHelpersList;
begin
  Helpers:=Params.GetHelpers(fdhlkDelphiHelper);
  if Helpers=nil then exit(false);
  FullExprType := CleanExpressionType;
  FullExprType.Desc := ExprType;
  case FullExprType.Desc of
  xtConstString: FullExprType.Desc:=GetDefaultStringType;
  xtConstOrdInteger: FullExprType.Desc:=xtLongint;
  xtConstBoolean: FullExprType.Desc:=xtBoolean;
  xtConstReal: FullExprType.Desc:=xtDouble;
  end;
  //debugln(['TFindDeclarationTool.FindIdentifierInBasicTypeHelpers ',ExprTypeToString(FullExprType)]);

  // find class helper functions
  CHContext := Helpers.FindFromExprType(FullExprType);

  if Assigned(CHContext.Node) and Assigned(CHContext.Tool) then
  begin
    OldFlags := Params.Flags;
    try
      Exclude(Params.Flags, fdfExceptionOnNotFound);
      Exclude(Params.Flags, fdfIgnoreCurContextNode);
      Include(Params.Flags, fdfIgnoreUsedUnits);
      Params.ContextNode := CHContext.Node;

      Result := CHContext.Tool.FindIdentifierInContext(Params);
    finally
      Params.Flags := OldFlags;
    end;
  end else
    Result := False;
end;

function TFindDeclarationTool.FindDeclarationAndOverload(
  const CursorPos: TCodeXYPosition; out ListOfPCodeXYPosition: TFPList;
  Flags: TFindDeclarationListFlags): boolean;
var
  CurCursorPos: TCodeXYPosition;
  NewTool: TFindDeclarationTool;
  NewNode: TCodeTreeNode;
  NewPos: TCodeXYPosition;
  NewTopLine: integer;
  CurTool: TFindDeclarationTool;
  OldPositions: TFPList;
  NodeList: TFPList;
  CleanPos: integer;
  AtDefinition: Boolean;

  procedure AddPos;
  begin
    AddCodePosition(OldPositions,NewPos);
    if (NodeList.IndexOf(NewNode)>=0) then begin
      {$IFDEF VerboseFindDeclarationAndOverload}
      debugln(['AddPos skip, because Node already in NodList']);
      {$ENDIF}
      exit;
    end;

    if (fdlfOneOverloadPerUnit in Flags)
    and (NodeList.Count>0)
    and (TCodeTreeNode(NodeList[NodeList.Count-1]).GetRoot=NewTool.Tree.Root)
    then begin
      {$IFDEF VerboseFindDeclarationAndOverload}
      debugln(['AddPos skip, because in same unit']);
      {$ENDIF}
      exit;
    end;
    NodeList.Add(NewNode);

    if (fdlfWithoutEmptyProperties in Flags)
    and (NewNode.Desc=ctnProperty)
    and (NewTool.PropNodeIsTypeLess(NewNode)) then begin
      {$IFDEF VerboseFindDeclarationAndOverload}
      debugln(['AddPos skip, because property has no type']);
      {$ENDIF}
      exit;
    end;
    if (fdlfWithoutForwards in Flags) then begin
      if (NewNode.Desc in [ctnTypeDefinition,ctnGenericType])
      and NewTool.NodeIsForwardDeclaration(NewNode) then begin
        {$IFDEF VerboseFindDeclarationAndOverload}
        debugln(['AddPos skip, because type is forward']);
        {$ENDIF}
        exit;
      end;
      if (NewNode.Desc=ctnProcedure)
      and ((NewNode.SubDesc and ctnsForwardDeclaration)>0)
      and (not NewNode.HasParentOfType(ctnInterface)) then begin
        {$IFDEF VerboseFindDeclarationAndOverload}
        debugln(['AddPos skip, because proc is forward']);
        {$ENDIF}
        exit;
      end;
    end;

    AddCodePosition(ListOfPCodeXYPosition,NewPos);
  end;
  
  function StartPositionAtDefinition: boolean;
  begin
    if (NewNode.Desc in AllIdentifierDefinitions)
    and (PositionInDefinitionName(NewNode,CleanPos)) then
      Result:=true
    else if (NewNode.Desc in [ctnProcedure,ctnProcedureHead])
    and (PositionInProcName(NewNode,false,CleanPos)) then
      Result:=true
    else if (NewNode.Desc in [ctnProperty,ctnGlobalProperty])
    and (PositionInPropertyName(NewNode,CleanPos)) then
      Result:=true
    else if (NewNode.Desc in AllSourceTypes)
    and (PositionInSourceName(CleanPos)) then
      Result:=true
    else
      Result:=false;
  end;

  function StartPositionAtFunctionResult: boolean;
  var
    Node: TCodeTreeNode;
  begin
    Result:=false;
    if (NewNode.Desc in [ctnProcedureHead,ctnIdentifier])
    and PositionInFuncResultName(NewNode,CleanPos) then begin
      Node:=NewNode;
      if Node.Desc=ctnProcedureHead then begin
        Node:=Node.FirstChild;
        if Node=nil then exit;
        if Node.Desc=ctnParameterList then Node:=Node.NextBrother;
        if Node=nil then exit;
      end;
      if Node.Desc in [ctnVarDefinition,ctnIdentifier] then begin
        // return the function result type or the operator variable name
        NewNode:=Node;
        Result:=true;
      end;
    end;
  end;

begin
  {$IFDEF VerboseFindDeclarationAndOverload}
  debugln(['TFindDeclarationTool.FindDeclarationAndOverload START']);
  {$ENDIF}
  Result:=true;
  ListOfPCodeXYPosition:=nil;
  NewTool:=nil;
  NewNode:=nil;
  OldPositions:=nil;
  NodeList:=nil;

  ActivateGlobalWriteLock;
  try
    BuildTreeAndGetCleanPos(trTillCursorSection,lsrEnd,CursorPos,CleanPos,[]);

    NodeList:=TFPList.Create;
    NewTool:=Self;
    NewNode:=BuildSubTreeAndFindDeepestNodeAtPos(CleanPos,true);
    NewPos:=CursorPos;
    AtDefinition:=StartPositionAtDefinition;
    if AtDefinition then begin
      AddPos;
      if fdlfIfStartIsDefinitionStop in Flags then begin
        {$IFDEF VerboseFindDeclarationAndOverload}
        debugln(['TFindDeclarationTool.FindDeclarationAndOverload AtDefiniton and fdlfIfStartIsDefinitionStop in Flags']);
        {$ENDIF}
        exit;
      end;
    end;
    if StartPositionAtFunctionResult then begin
      AddPos;
      // the function result has no overloads => stop search
      {$IFDEF VerboseFindDeclarationAndOverload}
      debugln(['TFindDeclarationTool.FindDeclarationAndOverload function result has no overloads']);
      {$ENDIF}
      exit;
    end;
    if NewNode.Desc in AllSourceTypes then begin
      // the unit name has no overloads => stop search
      {$IFDEF VerboseFindDeclarationAndOverload}
      debugln(['TFindDeclarationTool.FindDeclarationAndOverload unit name has no overload']);
      {$ENDIF}
      exit;
    end;

    CurCursorPos:=CursorPos;
    CurTool:=Self;
    try
      while CurTool.FindDeclaration(CurCursorPos,DefaultFindSmartFlags
        +[fsfSearchSourceName],
        NewTool,NewNode,NewPos,NewTopLine) do
      begin
        if IndexOfCodePosition(OldPositions,@NewPos)>=0 then break;
        AddPos;
        CurCursorPos:=NewPos;
        CurTool:=NewTool;
        {$IFDEF VerboseFindDeclarationAndOverload}
        debugln('TFindDeclarationTool.FindDeclarationAndOverload Self="',MainFilename,'" ');
        if CurCursorPos.Code<>nil then
          debugln('  CurCursorPos=',CurCursorPos.Code.Filename,' ',dbgs(CurCursorPos.X),',',dbgs(CurCursorPos.Y));
        if CurTool<>nil then
          debugln('  CurTool=',CurTool.MainFilename);
        {$ENDIF}
        if (CurTool=nil) then exit;
      end;
    except
      // ignore normal errors
      on E: ECodeToolError do ;
      on E: ELinkScannerError do ;
    end;
  finally
    FreeListOfPCodeXYPosition(OldPositions);
    NodeList.Free;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.FindIdentifierContextsAtStatement(CleanPos: integer;
  out IsSubIdentifier: boolean; out ListOfPFindContext: TFPList): boolean;
var
  Params: TFindDeclarationParams;
  CursorNode: TCodeTreeNode;
  Node: TCodeTreeNode;
  Context: TFindContext;
  WithNode: TCodeTreeNode;
  ExprType: TExpressionType;
begin
  Result:=false;
  IsSubIdentifier:=false;
  ListOfPFindContext:=nil;
  CursorNode:=FindDeepestNodeAtPos(CleanPos,true);
  if not (CursorNode.Desc in AllPascalStatements) then begin
    debugln(['TFindDeclarationTool.FindIdentifierContextsAtStatement CursorNode.Desc=',CursorNode.DescAsString]);
    exit;
  end;
  // check expression in front
  MoveCursorToCleanPos(CleanPos);
  ReadPriorAtom;
  if CurPos.Flag=cafPoint then begin
    // sub identifier
    // for example A.Identifier
    IsSubIdentifier:=true;
    // search the context of A and add it to the ListOfPFindContext
    Params:=TFindDeclarationParams.Create(Self, CursorNode);
    try
      Params.ContextNode:=CursorNode;
      Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,fdfSearchInHelpers,
                     fdfTopLvlResolving,fdfFunctionResult];
      ExprType:=FindExpressionTypeOfTerm(-1,CleanPos,Params,false);
    finally
      Params.Free;
    end;
    if ExprType.Desc=xtContext then
      AddFindContext(ListOfPFindContext,ExprType.Context);
  end else begin
    // not a sub identifier
    BuildSubTree(CursorNode);
    CursorNode:=FindDeepestNodeAtPos(CursorNode,CleanPos,true);
    Node:=CursorNode;
    while Node<>nil do begin
      case Node.Desc of
      ctnWithStatement:
        begin
          // add all With contexts
          WithNode:=Node.Parent;
          while WithNode<>nil do begin
            if WithNode.Desc<>ctnWithVariable then break;
            Params:=TFindDeclarationParams.Create(Self, WithNode);
            try
              Params.ContextNode:=WithNode;
              Params.Flags:=[fdfExceptionOnNotFound,fdfSearchInAncestors,fdfSearchInHelpers,
                fdfSearchInParentNodes,fdfFunctionResult,fdfIgnoreCurContextNode,
                fdfFindChildren];
              ExprType:=FindExpressionResultType(Params,WithNode.StartPos,-1);
              if ExprType.Desc=xtContext then
                AddFindContext(ListOfPFindContext,ExprType.Context);
            finally
              Params.Free;
            end;
            WithNode:=WithNode.PriorBrother;
          end;
        end;
      ctnProcedure:
        begin
          // add procedure context
          Context.Node:=Node;
          Context.Tool:=Self;
          AddFindContext(ListOfPFindContext,Context);
          if NodeIsMethodBody(Node) then begin
            // add class context
            Context.Node:=FindClassNodeForMethodBody(Node,true,false);
            if Context.Node<>nil then begin
              Context.Tool:=Self;
              AddFindContext(ListOfPFindContext,Context);
            end;
          end;
        end;
      ctnImplementation:
        begin
          Context.Node:=Node;
          Context.Tool:=Self;
          AddFindContext(ListOfPFindContext,Context);
        end;
      end;
      Node:=Node.Parent;
    end;
  end;
  Result:=true;
end;

function TFindDeclarationTool.FindIdentifierInAncestors(
  ClassNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
var
  IdentFoundResult: TIdentifierFoundResult;
begin
  Result := FindIdentifierInAncestors(ClassNode, Params, IdentFoundResult{%H-});
end;

function TFindDeclarationTool.FindClassAndAncestors(ClassNode: TCodeTreeNode;
  var ListOfPFindContext: TFPList; ExceptionOnNotFound: boolean): boolean;
var
  Params: TFindDeclarationParams;

  function Search: boolean;
  var
    CurTool: TFindDeclarationTool;
    FoundContext: TFindContext;
  begin
    CurTool:=Self;
    while CurTool.FindAncestorOfClass(ClassNode,Params,true) do begin
      if (Params.NewCodeTool=nil) then break;
      FoundContext.Tool:=Params.NewCodeTool;
      FoundContext.Node:=Params.NewNode;
      if IndexOfFindContext(ListOfPFindContext,@FoundContext)>=0 then break;
      AddFindContext(ListOfPFindContext,FoundContext);
      //debugln('TFindDeclarationTool.FindClassAndAncestors FoundContext=',DbgsFC(FoundContext));
      CurTool:=Params.NewCodeTool;
      ClassNode:=Params.NewNode;
      if (ClassNode=nil)
      or (not (ClassNode.Desc in AllClasses)) then
        break;
    end;
    Result:=true;
  end;

begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ClassNode);{$ENDIF}
  Result:=false;
  if (ClassNode=nil) or (not (ClassNode.Desc in AllClasses))
  or (ClassNode.Parent=nil)
  or (not (ClassNode.Parent.Desc in [ctnTypeDefinition,ctnGenericType])) then
    exit;

  AddFindContext(ListOfPFindContext,CreateFindContext(Self,ClassNode));

  Params:=TFindDeclarationParams.Create;
  ActivateGlobalWriteLock;
  try
    if ExceptionOnNotFound then
      Result:=Search
    else begin
      try
        Result:=Search;
      except
        // catch syntax errors
        on E: ECodeToolError do ;
        on E: ELinkScannerError do ;
      end;
    end;
  finally
    DeactivateGlobalWriteLock;
    Params.Free;
  end;
end;

procedure TFindDeclarationTool.FindHelpersInContext(
  Params: TFindDeclarationParams);
var
  Node: TCodeTreeNode;
begin
  Node:=Params.StartNode;
  Params.FNeedHelpers:=false;
  while Node<>nil do
  begin
    case Node.Desc of
      ctnClassHelper, ctnRecordHelper, ctnTypeHelper:
        if (Node.Parent.Desc = ctnTypeDefinition) then
          Params.GetHelpers(fdhlkDelphiHelper,true).AddFromHelperNode(Node, Self,
            False{ keep last found Helper }
            );
      ctnObjCCategory:
        if (Node.Parent.Desc = ctnTypeDefinition) then
          Params.GetHelpers(fdhlkObjCCategory,true).AddFromHelperNode(Node, Self, False);
      ctnUsesSection:
        FindHelpersInUsesSection(Node, Params);
    end;
    Node := Node.Prior;
  end;
end;

procedure TFindDeclarationTool.FindHelpersInInterface(
  AskingTool: TFindDeclarationTool; Params: TFindDeclarationParams);
var
  HelperKind: TFDHelpersListKind;
  Cache: TFDHelpersList;
begin
  // build tree for pascal source
  if not BuildInterfaceIdentifierCache(true) then exit;
  if (AskingTool<>Self) and (AskingTool<>nil) then
  begin
    AskingTool.AddToolDependency(Self);
    for HelperKind in TFDHelpersListKind do begin
      Cache:=FInterfaceHelperCache[HelperKind];
      if (Cache<>nil) and (Cache.Count>0) then
        Params.GetHelpers(HelperKind,true).AddFromList(AskingTool, FInterfaceHelperCache[HelperKind]);
    end;
  end;
end;

procedure TFindDeclarationTool.FindHelpersInUsesSection(
  UsesNode: TCodeTreeNode; Params: TFindDeclarationParams);
var
  NewCodeTool: TFindDeclarationTool;
  Node: TCodeTreeNode;
  AnUnitName: string;
  InFilename: string;
begin
  // search in units
  //debugln(['TFindDeclarationTool.FindHelpersInUsesSection START ',CleanPosToStr(UsesNode.StartPos,true),' Main=',MainFilename]);
  Node:=UsesNode.LastChild;
  while Node<>nil do begin
    AnUnitName:=ExtractUsedUnitName(Node,@InFilename);
    if AnUnitName<>'' then begin
      //debugln(['TFindDeclarationTool.FindHelpersInUsesSection ',CleanPosToStr(Node.StartPos),' AnUnitName="',AnUnitName,'" in "',InFilename,'"']);
      NewCodeTool:=FindCodeToolForUsedUnit(AnUnitName,InFilename,false);
      if NewCodeTool<>nil then begin
        // search the identifier in the interface of the used unit
        NewCodeTool.FindHelpersInInterface(Self,Params);
      end;
    end;
    Node:=Node.PriorBrother;
  end;
end;

function TFindDeclarationTool.FindContextClassAndAncestorsAndExtendedClassOfHelper
  (const CursorPos: TCodeXYPosition; var ListOfPFindContext: TFPList): boolean;
// returns a list of nodes of AllClasses (ctnClass, ...)
var
  CleanCursorPos: integer;
  ANode: TCodeTreeNode;
  ClassNode: TCodeTreeNode;
  ExtendedClassExpr: TExpressionType;
begin
  Result:=false;
  ListOfPFindContext:=nil;

  ActivateGlobalWriteLock;
  try
    BuildTreeAndGetCleanPos(trTillCursor,lsrEnd,CursorPos,CleanCursorPos,
                [btSetIgnoreErrorPos]);

    // find class node
    ANode:=FindDeepestNodeAtPos(CleanCursorPos,true);
    if (ANode.GetNodeOfType(ctnClassInheritance)<>nil) then
      exit;
    ClassNode:=FindClassNode(ANode);
    if (ClassNode=nil) or (ClassNode.Parent=nil)
    or (not (ClassNode.Parent.Desc in [ctnTypeDefinition,ctnGenericType])) then
      exit;

    //debugln('TFindDeclarationTool.FindContextClassAndAncestors A ClassName=',ExtractClassName(ClassNode,false));
    // add class and ancestors type definition to ListOfPCodeXYPosition
    if not FindClassAndAncestors(ClassNode,ListOfPFindContext,true)
    then exit;
    
    //find extended class node
    ExtendedClassExpr := FindExtendedExprOfHelper(ClassNode);
    if ((ExtendedClassExpr.Desc=xtContext) and (ExtendedClassExpr.Context.Tool<>nil) and
        (ExtendedClassExpr.Context.Node<>nil) and (ExtendedClassExpr.Context.Node.Desc=ctnClass)) then
    begin
      if not ExtendedClassExpr.Context.Tool.FindClassAndAncestors(ExtendedClassExpr.Context.Node,ListOfPFindContext,true)
      then exit;
    end;

    //debugln('TFindDeclarationTool.FindContextClassAndAncestors List: ',ListOfPFindContextToStr(ListOfPFindContext));
    
  finally
    DeactivateGlobalWriteLock;
  end;
  Result:=true;
end;

function TFindDeclarationTool.FindDefaultAncestorOfClass(
  ClassNode: TCodeTreeNode; Params: TFindDeclarationParams;
  FindClassContext: boolean): boolean;
var
  OldInput: TFindDeclarationInput;
  AncestorNode, ClassIdentNode: TCodeTreeNode;
  AncestorContext: TFindContext;
  BaseClassName: PChar;

  procedure RaiseBaseClassNotFound;
  begin
    MoveCursorToNodeStart(ClassNode);
    if BaseClassName='TObject' then
      RaiseException(20170421200159,ctsDefaultClassAncestorTObjectNotFound)
    else if BaseClassName='IInterface' then
      RaiseException(20170421200202,ctsDefaultInterfaceAncestorIInterfaceNotFound)
    else if BaseClassName='IDispatch' then
      RaiseException(20170421200205,ctsDefaultDispinterfaceAncestorIDispatchNotFound)
    else if BaseClassName='JLObject' then
      RaiseException(20170421200207,ctsDefaultJavaClassAncestorJLObjectNotFound)
    else
      RaiseExceptionFmt(20170421200210,ctsDefaultAncestorNotFound, [BaseClassName]);
  end;

begin
  //debugln(['TFindDeclarationTool.FindAncestorOfClass ',CleanPosToStr(ClassNode.StartPos,true)]);
  {$IFDEF CheckNodeTool}CheckNodeTool(ClassNode);{$ENDIF}
  if (ClassNode=nil) or (not (ClassNode.Desc in AllClasses))
  then
    RaiseException(20170421200213,'[TFindDeclarationTool.FindDefaultAncestorOfClass] '
      +' invalid classnode');
  Result:=false;

  // ToDo: ppu, dcu

  // no ancestor class specified
  ClassIdentNode:=ClassNode.Parent;
  // check class name
  if (ClassIdentNode<>nil)
  and (not (ClassIdentNode.Desc in [ctnTypeDefinition,ctnGenericType])) then
  begin
    debugln(['TFindDeclarationTool.FindDefaultAncestorOfClass not a type']);
    exit;
  end;
  BaseClassName:=nil;
  case ClassNode.Desc of
  ctnClass:
    if Scanner.Values.IsDefined('CPUJVM') then
      BaseClassName:='JLObject'
    else if (Scanner.PascalCompiler=pcPas2js)
    and (FindClassExternalNode(ClassNode)<>nil) then
      exit // external root class has no ancestor
    else
      BaseClassName:='TObject';
  ctnDispinterface:
    // default interface is IDispatch
    BaseClassName:='IDispatch';
  ctnClassInterface:
    begin
      if Scanner.Values.IsDefined('CPUJVM') then
        exit; // JVM has no default interface
      // Delphi has as default interface IInterface
      // FPC has as default interface IUnknown and an alias IInterface = IUnknown
      if CompareSrcIdentifiers(ClassIdentNode.StartPos,'IUnknown') then exit;
      BaseClassName:='IInterface';
    end
  else
    exit; // has no default ancestor (e.g. record)
  end;
  if CompareSrcIdentifiers(ClassIdentNode.StartPos,BaseClassName) then
    exit; // this is already the base class

  {$IFDEF ShowTriedContexts}
  DebugLn('[TFindDeclarationTool.FindAncestorOfClass] ',
  ' search default ancestor class '+BaseClassName);
  {$ENDIF}

  // search default ancestor
  Params.Save(OldInput);
  Params.Flags:=[fdfSearchInParentNodes,fdfIgnoreCurContextNode,
                 fdfExceptionOnNotFound]
                +(fdfGlobals*Params.Flags)
                -[fdfTopLvlResolving];
  Params.SetIdentifier(Self,BaseClassName,nil);
  Params.ContextNode:=ClassNode;
  if not FindIdentifierInContext(Params) then
    RaiseBaseClassNotFound;

  // check result
  if not (Params.NewNode.Desc in [ctnTypeDefinition,ctnGenericType]) then
    RaiseBaseClassNotFound;

  // search ancestor class context
  if FindClassContext then begin
    AncestorNode:=Params.NewNode;
    Params.Flags:=Params.Flags+[fdfFindChildren];
    AncestorContext:=Params.NewCodeTool.FindBaseTypeOfNode(Params,
                                                           AncestorNode);
    Params.SetResult(AncestorContext);

    // check result
    if Params.NewNode.Desc<>ClassNode.Desc then
      RaiseBaseClassNotFound;
  end;
  Result:=true;
  Params.Load(OldInput,true);
end;

{-------------------------------------------------------------------------------
  function TFindDeclarationTool.FindReferences(const CursorPos: TCodeXYPosition;
    SkipComments: boolean; var ListOfPCodeXYPosition: TFPList): boolean;

  Search for all identifiers in current unit, referring to the declaration
  at CursorPos.
-------------------------------------------------------------------------------}
function TFindDeclarationTool.FindReferences(const CursorPos: TCodeXYPosition;
  SkipComments: boolean; out ListOfPCodeXYPosition: TFPList): boolean;
var
  DeclarationFound: boolean;
  Identifier: string;
  CleanDeclCursorPos: integer;
  DeclarationTool: TFindDeclarationTool;
  DeclarationNode: TCodeTreeNode; // in DeclarationTool
  AliasDeclarationNode: TCodeTreeNode; // if exists: always in front of DeclarationNode, and in DeclarationTool
  Params: TFindDeclarationParams;
  PosTree: TAVLTree; // tree of PChar positions in Src
  ReferencePos: TCodeXYPosition;
  MinPos, MaxPos: Integer;
  CursorNode: TCodeTreeNode;
  UnitStartFound, Found: Boolean;
  StartPos: integer; // keep this here, it is modified at several places

  procedure AddReference(ACleanPos: integer);
  var
    p: PChar;
  begin
    if PosTree=nil then
      PosTree:=TAVLTree.Create;
    p:=@Src[ACleanPos];
    {$IFDEF VerboseFindReferences}
    debugln('TFindDeclarationTool.FindReferences.AddReference ',CleanPosToStr(ACleanPos),' ',dbgs(PosTree.Find(p)=nil),' Code=',dbgstr(copy(Src,ACleanPos-8,8)+'|'+dbgstr(copy(Src,ACleanPos,5))));
    {$ENDIF}
    if PosTree.Find(p)=nil then
      PosTree.Add(p);
  end;

  procedure AddNodeReference(Node: TCodeTreeNode);
  var
    p: LongInt;
  begin
    p:=Node.StartPos;
    if Node.Desc in [ctnProcedure,ctnProcedureHead] then begin
      MoveCursorToProcName(Node,true);
      p:=CurPos.StartPos;
    end else if Node.Desc in [ctnProperty,ctnGlobalProperty] then begin
      MoveCursorToPropName(Node);
      p:=CurPos.StartPos;
    end;
    AddReference(p);
  end;

  procedure UseProcHead(var Node: TCodeTreeNode);
  begin
    if Node=nil then exit;
    if (Node.Desc=ctnProcedure)
    and (Node.FirstChild<>nil)
    and (Node.FirstChild.Desc=ctnProcedureHead) then
      Node:=Node.FirstChild;
  end;
  
  procedure ReadIdentifier(IsComment: boolean);
  var
    IdentStartPos: Integer;
    IdentEndPos: integer;
    UnitNamePos, UnitInFilePos: TAtomPosition;
    NewCodeTool: TFindDeclarationTool;
    AnUnitName: String;
    UnitInFilename: AnsiString;
    Node: TCodeTreeNode;
  begin
    if (not IsComment) then
      UnitStartFound:=true;
    IdentStartPos:=StartPos;
    IdentEndPos:=IdentStartPos;
    while (IdentEndPos<=MaxPos) and (IsIdentChar[Src[IdentEndPos]]) do
      inc(IdentEndPos);
    StartPos:=IdentEndPos;
    //debugln(['ReadIdentifier ',CleanPosToStr(IdentStartPos,true),' ',copy(Src,IdentStartPos,IdentEndPos-IdentStartPos),' ',CompareIdentifiers(PChar(Pointer(Identifier)),@Src[IdentStartPos])]);
    if IdentEndPos-IdentStartPos<>length(Identifier) then exit;
    if CompareIdentifiers(PChar(Pointer(Identifier)),@Src[IdentStartPos])<>0 then exit;
    if IsComment and (SkipComments or (not UnitStartFound)) then exit;
    {$IFDEF VerboseFindReferences}
    debugln(['Identifier with same name found at: ',
      IdentStartPos,'=',CleanPosToStr(StartPos),' ',GetIdentifier(@Src[IdentStartPos]),
      ' CleanDeclCursorPos=',CleanDeclCursorPos,
      ' MaxPos=',MaxPos,
      ' IsComment=',IsComment,
      ' SkipComments=',SkipComments,
      ' UnitStartFound=',UnitStartFound
      ]);
    {$ENDIF}

    CursorNode:=BuildSubTreeAndFindDeepestNodeAtPos(IdentStartPos,true);
    //debugln('  CursorNode=',NodePathAsString(CursorNode),' Forward=',dbgs(CursorNode.SubDesc and ctnsForwardDeclaration));

    if (DeclarationTool=Self)
    and ((IdentStartPos=CleanDeclCursorPos) or (CursorNode=AliasDeclarationNode))
    then begin
      // declaration itself found
      //debugln(['ReadIdentifier declaration itself found, adding ...']);
      AddReference(IdentStartPos)
    end
    else if CleanPosIsDeclarationIdentifier(IdentStartPos,CursorNode) then
      // this identifier is another declaration with the same name
    else begin
      // find declaration
      if Params=nil then
        Params:=TFindDeclarationParams.Create(Self, CursorNode)
      else
        Params.Clear;
      Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,fdfSearchInHelpers,
                     fdfIgnoreCurContextNode];
      Params.ContextNode:=CursorNode;
      //debugln(copy(Src,Params.ContextNode.StartPos,200));
      Params.SetIdentifier(Self,@Src[IdentStartPos],@CheckSrcIdentifier);

      // search identifier in comment -> if not found, this is no bug
      // => silently ignore
      try
        Found:=FindDeclarationOfIdentAtParam(Params);
      except
        on E: ECodeToolError do begin
          if E.Sender<>Self then begin
            // there is an error in another unit, which prevents searching
            // stop further searching in this unit
            raise;
          end;
          // continue
        end;
        on E: Exception do
          raise;
      end;

      //debugln(' Found=',dbgs(Found));
      Node:=Params.NewNode;
      if Found and (Node<>nil) then begin
        if ((Node.Desc=ctnUseUnit) or (Node.Parent.Desc=ctnUseUnit))
            and (Params.NewCodeTool=Self) then begin
          // identifier is a unit reference
          if (DeclarationNode.Desc=ctnSrcName)
              or ((DeclarationNode.Parent<>nil) and (DeclarationNode.Parent.Desc=ctnSrcName)) then begin
            // searching a unit reference -> check if it is the same
            MoveCursorToNodeStart(Node);
            if ReadNextUsedUnit(UnitNamePos,UnitInFilePos) then begin
              // cursor is on an used unit -> try to locate it
              MoveCursorToCleanPos(UnitNamePos.StartPos);
              ReadNextAtom;
              AnUnitName:=ExtractUsedUnitNameAtCursor(@UnitInFilename);
              NewCodeTool:=FindCodeToolForUsedUnit(AnUnitName,UnitInFilename,false);
              if NewCodeTool=DeclarationTool then begin
                AddReference(IdentStartPos);
                exit;
              end;
            end;
          end;
        end;

        UseProcHead(Node);
        //debugln('Context=',NodePathAsString(Params.NewNode),' FoundPos=',Params.NewCodeTool.CleanPosToStr(Params.NewNode.StartPos,true),' SearchPos=',DeclarationTool.CleanPosToStr(DeclarationNode.StartPos,true));
        if (Params.NewNode=DeclarationNode)
        or (Params.NewNode=AliasDeclarationNode) then begin
          debugln(['ReadIdentifier reference found, adding ...']);
          AddReference(IdentStartPos);
        end;
      end;
    end;
  end;
  
  procedure SearchIdentifiers;
  var
    CommentLvl: Integer;
    InStrConst: Boolean;
  begin
    StartPos:=MinPos;
    UnitStartFound:=false;
    while StartPos<=MaxPos do begin
      case Src[StartPos] of
      
      '{':
        begin
          inc(StartPos);
          if (StartPos<=MaxPos) and (Src[StartPos]=#3) then begin
            // codetools skip comment {#3 #3}
            inc(StartPos);
            while (StartPos<=MaxPos) do begin
              if (Src[StartPos]=#3) and (StartPos<MaxPos) and (Src[StartPos+1]='}')
              then begin
                inc(StartPos,2);
                break;
              end;
              inc(StartPos);
            end;
          end else begin
            // pascal comment {}
            CommentLvl:=1;
            InStrConst:=false;
            while StartPos<=MaxPos do begin
              case Src[StartPos] of
              '{': if Scanner.NestedComments then inc(CommentLvl);
              '}':
                begin
                  dec(CommentLvl);
                  if CommentLvl=0 then break;
                end;
              'a'..'z','A'..'Z','_':
                if not InStrConst then begin
                  ReadIdentifier(true);
                  dec(StartPos);
                end;
              '''':
                InStrConst:=not InStrConst;
              #10,#13:
                InStrConst:=false;
              end;
              inc(StartPos);
            end;
            inc(StartPos);
            //debugln(StartPos,' ',copy(Src,CommentStart,StartPos-CommentStart));
          end;
        end;
        
      '/':  // Delphi comment
        if (Src[StartPos+1]<>'/') then begin
          inc(StartPos);
        end else begin
          inc(StartPos,2);
          InStrConst:=false;
          while (StartPos<=MaxPos) do begin
            case Src[StartPos] of
            #10,#13:
              break;
            'a'..'z','A'..'Z','_':
              if not InStrConst then begin
                ReadIdentifier(true);
                dec(StartPos);
              end;
            '''':
              InStrConst:=not InStrConst;
            end;
            inc(StartPos);
          end;
          inc(StartPos);
          if (StartPos<=MaxPos) and (Src[StartPos] in [#10,#13])
          and (Src[StartPos-1]<>Src[StartPos]) then
            inc(StartPos);
        end;
        
      '(': // turbo pascal comment
        if (Src[StartPos+1]<>'*') then begin
          inc(StartPos);
        end else begin
          inc(StartPos,3);
          InStrConst:=false;
          while (StartPos<=MaxPos) do begin
            case Src[StartPos] of
            ')':
              if Src[StartPos-1]='*' then break;
            'a'..'z','A'..'Z','_':
              if not InStrConst then begin
                ReadIdentifier(true);
                dec(StartPos);
              end;
            '''':
              InStrConst:=not InStrConst;
            #10,#13:
              InStrConst:=false;
            end;
            inc(StartPos);
          end;
          inc(StartPos);
        end;
        
      'a'..'z','A'..'Z','_':
        ReadIdentifier(false);
        
      '''':
        begin
          // skip string constant
          inc(StartPos);
          while (StartPos<=MaxPos) do begin
            if (not (Src[StartPos] in ['''',#10,#13])) then
              inc(StartPos)
            else begin
              inc(StartPos);
              break;
            end;
          end;
        end;
        
      else
        inc(StartPos);
      end;
    end;
  end;

  function GetDeclarationTool: boolean;
  begin
    Result:=false;
    DeclarationTool:=nil;
    if Assigned(FOnGetCodeToolForBuffer) then
      DeclarationTool:=FOnGetCodeToolForBuffer(Self,CursorPos.Code,true)
    else if CursorPos.Code=TObject(Scanner.MainCode) then
      DeclarationTool:=Self;
    if DeclarationTool=nil then begin
      debugln('WARNING: TFindDeclarationTool.FindReferences DeclarationTool=nil');
      exit;
    end;
    Result:=true;
  end;
  
  function FindDeclarationNode: boolean;
  const
    ProcAttr = [phpInUpperCase,phpAddClassName,phpWithVarModifiers];
  var
    Node: TCodeTreeNode;
    CommentStart: integer;
    CommentEnd: integer;
    p: LongInt;
  begin
    if DeclarationFound then exit(true);
    Result:=false;

    // find the main declaration node and identifier
    DeclarationTool.BuildTreeAndGetCleanPos(CursorPos,CleanDeclCursorPos);
    DeclarationNode:=DeclarationTool.BuildSubTreeAndFindDeepestNodeAtPos(
                                           CleanDeclCursorPos,true);
    Identifier:=DeclarationTool.ExtractIdentifier(CleanDeclCursorPos);
    if Identifier='' then begin
      //debugln('FindDeclarationNode Identifier="',Identifier,'"');
      exit;
    end;
    UseProcHead(DeclarationNode);
    if DeclarationTool=Self then begin
      //debugln(['FindDeclarationNode adding DeclarationNode ...']);
      AddNodeReference(DeclarationNode);
    end;

    // find alias declaration node
    //debugln('FindDeclarationNode DeclarationNode=',NodePathAsString(DeclarationNode),' at ',DeclarationTool.CleanPosToStr(DeclarationNode.StartPos));
    AliasDeclarationNode:=nil;
    case DeclarationNode.Desc of

    ctnProcedure,ctnProcedureHead:
      begin
        Node:=DeclarationNode;
        if DeclarationNode.Desc=ctnProcedureHead then
          Node:=Node.Parent;
        AliasDeclarationNode:=DeclarationTool.FindCorrespondingProcNode(
                     Node,ProcAttr);
      end;

    ctnVarDefinition:
      if DeclarationNode.HasParentOfType(ctnProcedureHead) then begin
        AliasDeclarationNode:=DeclarationTool.FindCorrespondingProcParamNode(DeclarationNode,ProcAttr);
      end;

    ctnTypeDefinition:
      if NodeIsForwardType(DeclarationNode) then
        AliasDeclarationNode:=DeclarationTool.FindTypeOfForwardNode(DeclarationNode)
      else
        AliasDeclarationNode:=DeclarationTool.FindForwardTypeNode(DeclarationNode,true);

    end;
    if AliasDeclarationNode=DeclarationNode then
      AliasDeclarationNode:=nil;

    if AliasDeclarationNode<>nil then begin
      UseProcHead(AliasDeclarationNode);
      if DeclarationTool=Self then begin
        //debugln(['FindDeclarationNode adding alias node ...']);
        AddNodeReference(AliasDeclarationNode);
      end;
      if AliasDeclarationNode.StartPos>DeclarationNode.StartPos then begin
        Node:=AliasDeclarationNode;
        AliasDeclarationNode:=DeclarationNode;
        DeclarationNode:=Node;
      end;
    end;

    // search comment in front of declaration
    //debugln(['FindDeclarationNode search comment in front: ',DeclarationTool=Self,' SkipComments=',SkipComments,' Identifier=',Identifier]);
    if (DeclarationTool=Self)
    and (not SkipComments)
    and FindCommentInFront(DeclarationNode.StartPos,Identifier,
      true,false,false,true,true,CommentStart,CommentEnd)
    then begin
      //debugln(['FindDeclarationNode Comment="',dbgstr(copy(Src,CommentStart,CommentEnd)),'"']);
      p:=CommentStart;
      if (Src[p]='{') then begin
        inc(p);
        while (p<=SrcLen) and IsSpaceChar[Src[p]] do inc(p);
        if (p<=SrcLen) and (CompareIdentifiers(@Src[p],PChar(Identifier))=0)
        then begin
          //debugln(['FindDeclarationNode comment in front']);
          AddReference(p);
        end;
      end;
    end;

    DeclarationFound:=true;
    Result:=true;
  end;

  procedure LimitScope(UseNode: TCodeTreeNode);
  var
    Node: TCodeTreeNode;
    StartNode: TCodeTreeNode;
  begin
    MinPos:=Tree.FindFirstPosition;
    MaxPos:=Tree.FindLastPosition;
    if MaxPos>SrcLen then MaxPos:=SrcLen;

    if DeclarationTool<>Self then begin
      MinPos:=UseNode.StartPos;
      exit;
    end;

    StartNode:=DeclarationNode;
    if (AliasDeclarationNode<>nil) then
      StartNode:=AliasDeclarationNode;
    Node:=StartNode;
    while Node<>nil do begin
      case Node.Desc of
      ctnImplementation:
        // only search in implementation
        if MinPos<Node.StartPos then MinPos:=Node.StartPos;

      ctnTypeDefinition:
        begin
          // Note: types can be used before declaration
        end;

      ctnVarDefinition,ctnConstDefinition,ctnEnumIdentifier,ctnLabel:
        begin
          // only search behind variable
          if MinPos<Node.StartPos then MinPos:=Node.StartPos;
        end;

      ctnProcedureHead:
        MinPos:=Node.StartPos;

      ctnProcedure:
        begin
          if (FindProcBody(Node)<>nil) and (StartNode<>Node.FirstChild) then
          begin
            // DeclarationNode is a local identifier
            // limit scope to procedure
            //debugln(['LimitScope ProcNode=',CleanPosToStr(Node.StartPos),'..',CleanPosToStr(Node.EndPos)]);
            if MinPos<Node.FirstChild.EndPos then
              MinPos:=Node.FirstChild.EndPos;
            if MaxPos>Node.EndPos then
              MaxPos:=Node.EndPos;
          end;
        end;

      ctnOnBlock:
        begin
          // a declaration in an on block is only accessible in the on block
          if MinPos<Node.StartPos then
            MinPos:=Node.StartPos;
          if MaxPos>Node.EndPos then
            MaxPos:=Node.EndPos;
        end;

      end;
      //debugln(['scope limited to node: ',Node.DescAsString,' ',CleanPosToStr(MinPos),'..',CleanPosToStr(MaxPos),': ',dbgstr(copy(Src,MinPos,20)),'..',dbgstr(copy(Src,MaxPos-20,20))]);
      Node:=Node.Parent;
    end;
    //debugln(['LimitScope ',CleanPosToStr(MinPos),'..',CleanPosToStr(MaxPos),': ',dbgstr(copy(Src,MinPos,20)),'..',dbgstr(copy(Src,MaxPos-20,20))]);
  end;
  
var
  UseNode: TCodeTreeNode;
  AVLNode: TAVLTreeNode;
begin
  Result:=false;
  {$IFDEF VerboseFindReferences}
  debugln('FindReferences ',MainFilename,' CursorPos=',CursorPos.Code.Filename,' x=',dbgs(CursorPos.X),' y=',dbgs(CursorPos.Y),' SkipComments=',dbgs(SkipComments));
  {$ENDIF}
  
  ListOfPCodeXYPosition:=nil;
  Params:=nil;
  PosTree:=nil;
  DeclarationFound:=false;

  ActivateGlobalWriteLock;
  try
    // get the tool of the declaration
    if not GetDeclarationTool then exit;

    // check if this unit uses the declaration unit
    UseNode:=nil;
    if Self<>DeclarationTool then begin
      BuildTree(lsrImplementationUsesSectionEnd);
      UseNode:=FindUnitFileInAllUsesSections(DeclarationTool.MainFilename);
      if UseNode=nil then
        exit(true); // the declaration unit is not used
    end;

    // find declaration nodes and identifier
    BuildTree(lsrEnd);
    if not FindDeclarationNode then exit;

    // search identifiers
    LimitScope(UseNode);

    //debugln('FindReferences MinPos=',CleanPosToStr(MinPos),' MaxPos=',CleanPosToStr(MaxPos));
    SearchIdentifiers;

    // create the reference list
    if PosTree<>nil then begin
      AVLNode:=PosTree.FindHighest;
      while AVLNode<>nil do begin
        StartPos:=PChar(AVLNode.Data)-PChar(Pointer(Src))+1;
        // Note: if an include file is included twice a code position could be duplicated
        if CleanPosToCaret(StartPos,ReferencePos) then
          AddCodePosition(ListOfPCodeXYPosition,ReferencePos);
        AVLNode:=PosTree.FindPrecessor(AVLNode);
      end;
    end;

  finally
    Params.Free;
    PosTree.Free;
    DeactivateGlobalWriteLock;
  end;
  Result:=true;
end;

function TFindDeclarationTool.FindUnitReferences(UnitCode: TCodeBuffer;
  SkipComments: boolean; out ListOfPCodeXYPosition: TFPList): boolean;
var
  AUnitName, UpperUnitName: String;

  function CheckUsesSection(UsesNode: TCodeTreeNode): boolean;
  // Returns True if unit name is found.
  var
    ReferencePos: TCodeXYPosition;
    UnitNamePos, UnitInFilePos: TAtomPosition;
    UnitNameP: PChar;
  begin
    Result:=false;
    if UsesNode=nil then exit;
    //DebugLn(['CheckUsesSection ',UsesNode.DescAsString]);
    MoveCursorToNodeStart(UsesNode);
    if (UsesNode.Desc=ctnUsesSection) then begin
      ReadNextAtom;
      if not UpAtomIs('USES') then
        RaiseUsesExpected(20170421200509);
    end;
    UnitNameP:=PChar(UpperUnitName);
    repeat
      ReadNextAtom;  // read name
      ReadNextUsedUnit(UnitNamePos,UnitInFilePos); // read dotted name + IN file
      if CurPos.StartPos>SrcLen then break;
      if CompareSrcIdentifiers(UnitNamePos.StartPos,UnitNameP) then begin // compare case insensitive
        if CleanPosToCaret(UnitNamePos.StartPos,ReferencePos) then begin
          //DebugLn(['CheckUsesSection found in uses section: ',Dbgs(ReferencePos)]);
          Result:=true;
          AddCodePosition(ListOfPCodeXYPosition,ReferencePos);
        end;
      end;
      if AtomIsChar(';') then break;
      if not AtomIsChar(',') then
        RaiseExceptionFmt(20170421200217,ctsStrExpectedButAtomFound,[';',GetAtom])
    until (CurPos.StartPos>SrcLen);
  end;

  function CheckSource(StartPos: integer): boolean;
  var
    ReferencePos: TCodeXYPosition;
  begin
    MoveCursorToCleanPos(StartPos);
    repeat
      ReadNextAtom;
      if not SkipComments then
        ; // ToDo
      if UpAtomIs(UpperUnitName)
      and not LastAtomIs(0,'.') then begin
        if CleanPosToCaret(CurPos.StartPos,ReferencePos) then begin
          //DebugLn(['CheckSource found: ',Dbgs(ReferencePos)]);
          AddCodePosition(ListOfPCodeXYPosition,ReferencePos);
        end;
      end;
    until CurPos.StartPos>SrcLen;
    Result:=true;
  end;

var
  InterfaceUsesNode: TCodeTreeNode;
  ImplementationUsesNode: TCodeTreeNode;
  StartPos: Integer;
begin
  Result:=false;
  //debugln('FindUnitReferences UnitCode=',UnitCode.Filename,' SkipComments=',dbgs(SkipComments),' ',MainFilename);

  AUnitName:=ExtractFileNameOnly(UnitCode.Filename);
  UpperUnitName:=UpperCaseStr(AUnitName);
  ListOfPCodeXYPosition:=nil;
  ActivateGlobalWriteLock;
  try
    BuildTree(lsrEnd);

    InterfaceUsesNode:=FindMainUsesNode;
    if CheckUsesSection(InterfaceUsesNode) then
      StartPos:=InterfaceUsesNode.EndPos
    else begin
      ImplementationUsesNode:=FindImplementationUsesNode;
      if CheckUsesSection(ImplementationUsesNode) then
        StartPos:=ImplementationUsesNode.EndPos
      else
        StartPos:=-1;
    end;

    // find unit reference in source
    if StartPos>0 then begin
      if not CheckSource(StartPos) then exit;
    end;
  finally
    DeactivateGlobalWriteLock;
  end;
  Result:=true;
end;

procedure TFindDeclarationTool.FindUsedUnitReferences(
  const CursorPos: TCodeXYPosition; SkipComments: boolean; out
  UsedUnitFilename: string; out ListOfPCodeXYPosition: TFPList);
var
  CleanPos: integer;
  Node: TCodeTreeNode;
  UnitInFilename: string;
  AnUnitName: String;
  TargetCode: TCodeBuffer;
  TargetTool: TFindDeclarationTool;
begin
  //debugln(['TFindDeclarationTool.FindUsedUnitReferences ',dbgs(CursorPos)]);
  UsedUnitFilename:='';
  ListOfPCodeXYPosition:=nil;
  BuildTreeAndGetCleanPos(CursorPos,CleanPos);
  Node:=FindDeepestNodeAtPos(CleanPos,true);
  if Node.Desc in [ctnUseUnitNamespace,ctnUseUnitClearName] then
    Node:=Node.Parent;
  if Node.Desc<>ctnUseUnit then
    RaiseException(20170421200221,'This function needs the cursor at a unit in a uses clause');
  // cursor is on an used unit -> try to locate it
  MoveCursorToCleanPos(Node.StartPos);
  ReadNextAtom;
  AnUnitName:=ExtractUsedUnitNameAtCursor(@UnitInFilename);
  //debugln(['TFindDeclarationTool.FindUsedUnitReferences Used Unit=',AnUnitName,' in "',UnitInFilename,'"']);
  TargetCode:=FindUnitSource(AnUnitName,UnitInFilename,true,Node.StartPos);
  UsedUnitFilename:=TargetCode.Filename;
  //debugln(['TFindDeclarationTool.FindUsedUnitReferences TargetCode=',TargetCode.Filename]);
  TargetTool:=FOnGetCodeToolForBuffer(Self,TargetCode,false);
  FindUsedUnitReferences(TargetTool,SkipComments,ListOfPCodeXYPosition);
end;

procedure TFindDeclarationTool.FindUsedUnitReferences(
  TargetTool: TFindDeclarationTool; SkipComments: boolean; out
  ListOfPCodeXYPosition: TFPList);
var
  refs: TFindUsedUnitReferences;
begin
  ListOfPCodeXYPosition:=TFPList.Create;
  if TargetTool=nil then
    RaiseException(20170421200226,'TargetTool=nil');
  TargetTool.BuildInterfaceIdentifierCache(true);
  refs:=TFindUsedUnitReferences.Create(Self, FindLastNode);
  try
    refs.TargetTool:=TargetTool;
    refs.TargetUnitName:=TargetTool.GetSourceName(false);
    refs.ListOfPCodeXYPosition:=ListOfPCodeXYPosition;
    ForEachIdentifier(SkipComments,@OnFindUsedUnitIdentifier,refs);
  finally
    refs.Free;
  end;
end;

{-------------------------------------------------------------------------------
  function TFindDeclarationTool.CleanPosIsDeclarationIdentifier(CleanPos: integer;
    Node: TCodeTreeNode): boolean;

  Node should be the deepest node at CleanPos, and all sub trees built.
  See BuildSubTree
-------------------------------------------------------------------------------}
function TFindDeclarationTool.CleanPosIsDeclarationIdentifier(CleanPos: integer;
  Node: TCodeTreeNode): boolean;

  function InNodeIdentifier(NodeIdentStartPos: Integer): boolean;
  var
    IdentStartPos, IdentEndPos: integer;
  begin
    GetIdentStartEndAtPosition(Src,CleanPos,IdentStartPos,IdentEndPos);
    Result:=(IdentEndPos>IdentStartPos) and (IdentStartPos=NodeIdentStartPos);
  end;

begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=false;
  if Node=nil then exit;
  case Node.Desc of

  ctnTypeDefinition,ctnVarDefinition,ctnConstDefinition,ctnEnumIdentifier,ctnLabel:
    begin
      if NodeIsForwardDeclaration(Node) then exit;
      Result:=InNodeIdentifier(Node.StartPos);
    end;
    
  ctnGenericType:
    begin
      if (Node.FirstChild=nil) or NodeIsForwardDeclaration(Node) then exit;
      Result:=InNodeIdentifier(Node.FirstChild.StartPos);
    end;
    
  ctnProcedure:
    begin
      if (Node.FirstChild<>nil)
      and ((Node.FirstChild.SubDesc and ctnsForwardDeclaration)>0) then
        RaiseException(20170421200230,'TFindDeclarationTool.CleanPosIsDeclarationIdentifier Node not expanded');
      MoveCursorToProcName(Node,true);
      Result:=InNodeIdentifier(CurPos.StartPos);
    end;
    
  ctnProcedureHead:
    begin
      MoveCursorToProcName(Node,true);
      Result:=InNodeIdentifier(CurPos.StartPos);
    end;
    
  ctnProperty, ctnGlobalProperty:
    begin
      if not MoveCursorToPropName(Node) then exit;
      Result:=InNodeIdentifier(CurPos.StartPos);
    end;

  ctnUnit:
    Result:=PositionInSourceName(CleanPos);

  ctnIdentifier:
    if Node.Parent.Desc=ctnSrcName then
      Result:=true;
  end;
end;

function TFindDeclarationTool.JumpToNode(ANode: TCodeTreeNode; out
  NewPos: TCodeXYPosition; out NewTopLine, BlockTopLine,
  BlockBottomLine: integer; IsCodeBlock: boolean): boolean;
var
  JumpPos: LongInt;
  Caret: TCodeXYPosition;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ANode);{$ENDIF}
  Result:=false;
  if (ANode=nil) or (ANode.StartPos<1) then exit;
  JumpPos:=ANode.StartPos;
  if ANode.Desc in [ctnProperty,ctnGlobalProperty] then begin
    MoveCursorToPropName(ANode);
    JumpPos:=CurPos.StartPos;
  end;
  Result:=JumpToCleanPos(JumpPos,JumpPos,ANode.EndPos,
                         NewPos,NewTopLine,BlockTopLine,BlockBottomLine,IsCodeBlock);
  if CleanPosToCaret(ANode.StartPos, Caret) then
    BlockTopLine := Caret.Y
  else
    BlockTopLine := -1;
  if CleanPosToCaret(ANode.EndPos, Caret) then
    BlockBottomLine := Caret.Y
  else
    BlockBottomLine := -1;
end;

function TFindDeclarationTool.JumpToNode(ANode: TCodeTreeNode; out
  NewPos: TCodeXYPosition; out NewTopLine: integer; IsCodeBlock: boolean
  ): boolean;
var
  BlockTopLine, BlockBottomLine: integer;
begin
  Result := JumpToNode(ANode, NewPos, NewTopLine, BlockTopLine, BlockBottomLine, IsCodeBlock);
end;

function TFindDeclarationTool.JumpToCleanPos(NewCleanPos, NewTopLineCleanPos,
  NewBottomLineCleanPos: integer; out NewPos: TCodeXYPosition; out NewTopLine,
  BlockTopLine, BlockBottomLine: integer; IsCodeBlock: boolean): boolean;
var
  NewTopLinePos: TCodeXYPosition;
  NewBottomLinePos: TCodeXYPosition;
  JumpPos: Integer;
begin
  Result:=false;
  // convert clean position to line, column and code
  if not CleanPosToCaret(NewCleanPos,NewPos) then exit;
  NewTopLine:=NewPos.Y;
  if AdjustTopLineDueToComment then begin
    // if there is a comment in front of the top position, it probably belongs
    // to the destination code
    // -> adjust the topline position, so that the comment is visible
    NewTopLineCleanPos:=FindLineEndOrCodeInFrontOfPosition(NewTopLineCleanPos,
                                                           false);
    if (NewTopLineCleanPos>=1) and (Src[NewTopLineCleanPos] in [#13,#10])
    then begin
      inc(NewTopLineCleanPos);
      if (Src[NewTopLineCleanPos] in [#10,#13])
      and (Src[NewTopLineCleanPos]<>Src[NewTopLineCleanPos-1]) then
        inc(NewTopLineCleanPos);
    end;
  end;
  // convert clean top line position to line, column and code
  if not CleanPosToCaret(NewTopLineCleanPos,NewTopLinePos) then exit;
  BlockTopLine := NewTopLinePos.Y;
  // convert clean bottom line position to line, column and code
  NewBottomLinePos:=NewPos;
  if (NewBottomLineCleanPos>NewCleanPos)
  and (not CleanPosToCaret(NewBottomLineCleanPos,NewBottomLinePos)) then exit;
  BlockBottomLine := NewBottomLinePos.Y;

  if NewTopLinePos.Code=NewPos.Code then begin
    // center the destination position in the source editor
    if IsCodeBlock and (JumpCodeBlockPos>0) then
      JumpPos := JumpCodeBlockPos
    else
    if not IsCodeBlock and (JumpSingleLinePos>0) then
      JumpPos := JumpSingleLinePos
    else
      JumpPos := 0;
    if JumpPos>0 then
      NewTopLine:=NewTopLinePos.Y-((VisibleEditorLines-(NewBottomLinePos.Y-NewTopLinePos.Y))*JumpPos div 100)
    else
      NewTopLine:=High(NewTopLine);
    if NewTopLine>NewTopLinePos.Y then
      NewTopLine:=NewTopLinePos.Y;

    // NewTopLine not above first line of code
    if NewTopLine<1 then NewTopLine:=1;
    // make NewTopLine visible
    if NewTopLine<=NewPos.Y-VisibleEditorLines then begin
      // NewTopLine is not visible
      // center or align to bottom
      if (NewBottomLineCleanPos>NewCleanPos)
      and (NewBottomLinePos.Y<NewPos.Y+(VisibleEditorLines div 2))
      then begin
        // align to bottom
        NewTopLine:=NewBottomLinePos.Y-VisibleEditorLines+1;
      end else begin
        // center
        NewTopLine:=NewPos.Y-(VisibleEditorLines*JumpSingleLinePos div 100);
      end;
      if NewTopLine<1 then NewTopLine:=1;
    end;
  end else
    NewTopLine:=1;
  Result:=true;
end;

function TFindDeclarationTool.JumpToCleanPos(NewCleanPos, NewTopLineCleanPos,
  NewBottomLineCleanPos: integer; out NewPos: TCodeXYPosition; out
  NewTopLine: integer; IsCodeBlock: boolean): boolean;
var
  BlockTopLine, BlockBottomLine: integer;
begin
  Result := JumpToCleanPos(NewCleanPos, NewTopLineCleanPos, NewBottomLineCleanPos,
    NewPos, NewTopLine, BlockTopLine, BlockBottomLine, IsCodeBlock);
end;

function TFindDeclarationTool.NodeIsForwardDeclaration(Node: TCodeTreeNode
  ): boolean;
var
  TypeNode: TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=false;
  if (Node=nil) or (not (Node.Desc in [ctnTypeDefinition,ctnGenericType])) then
    exit;
  TypeNode:=FindTypeNodeOfDefinition(Node);
  if TypeNode=nil then exit;
  if TypeNode.Desc in AllClasses then begin
    if (TypeNode.SubDesc and ctnsForwardDeclaration)>0 then begin
      Result:=true;
      exit;
    end;
  end;
end;

function TFindDeclarationTool.GetExpandedOperand(const CursorPos: TCodeXYPosition;
  out Operand: string; ResolveProperty: Boolean): Boolean;
var
  CursorNode: TCodeTreeNode;
  CleanCursorPos: integer;
  Params: TFindDeclarationParams;
  Identifier: PChar;
  LineRange: TLineRange;
begin
  Result := False;
  Operand := '';
  if (CursorPos.Y<1) or (CursorPos.Y>CursorPos.Code.LineCount)
  or (CursorPos.X<1) then Exit;
  CursorPos.Code.GetLineRange(CursorPos.Y-1,LineRange);
  if LineRange.EndPos-LineRange.StartPos+1<CursorPos.X then Exit;

  ActivateGlobalWriteLock;
  try
    // build code tree
    BuildTreeAndGetCleanPos(trTillCursor,lsrEnd,CursorPos,CleanCursorPos,
                  [btSetIgnoreErrorPos,btCursorPosOutAllowed]);
    // find CodeTreeNode at cursor
    if (Tree.Root<>nil) and (Tree.Root.StartPos<=CleanCursorPos) then
      CursorNode := BuildSubTreeAndFindDeepestNodeAtPos(CleanCursorPos, True)
    else
      CursorNode := nil;

    if CursorNode = nil then begin
      // raise exception
      CursorNode := FindDeepestNodeAtPos(CleanCursorPos, True);
    end;
    if CursorNode.Desc = ctnBeginBlock then begin
      BuildSubTreeForBeginBlock(CursorNode);
      CursorNode := FindDeepestNodeAtPos(CursorNode, CleanCursorPos, True);
    end;
    // set cursor on identifier
    MoveCursorToCleanPos(CleanCursorPos);
    GetIdentStartEndAtPosition(Src,CleanCursorPos,
                               CurPos.StartPos,CurPos.EndPos);
    if CurPos.StartPos >= CurPos.EndPos then Exit;
    Identifier := @Src[CurPos.StartPos];
    // find declaration of identifier
    Params := TFindDeclarationParams.Create;
    try
      Params.ContextNode := CursorNode;
      Params.SetIdentifier(Self, Identifier, nil);
      Params.Flags := [fdfSearchInParentNodes, fdfTopLvlResolving,
                       fdfSearchInAncestors, fdfSkipClassForward,
                       fdfExtractOperand];
      if ResolveProperty then
        Include(Params.Flags, fdfPropertyResolving);
      if FindDeclarationOfIdentAtParam(Params) then
      begin
        Operand := Params.ExtractedOperand;
        Result := Operand <> '';
      end;
    finally
      Params.Free;
    end;
  finally
    ClearIgnoreErrorAfter;
    DeactivateGlobalWriteLock;
  end;
end;

function TFindDeclarationTool.FindIdentifierInProcContext(
  ProcContextNode: TCodeTreeNode;
  Params: TFindDeclarationParams): TIdentifierFoundResult;
{ this function is internally used by FindIdentifierInContext
}
var
  NameAtom: TAtomPosition;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ProcContextNode);{$ENDIF}
  Result:=ifrProceedSearch;
  // if proc is a method body, search in class
  // -> find class name
  if ProcContextNode.FirstChild=nil then
    exit(ifrProceedSearch);
  MoveCursorToNodeStart(ProcContextNode.FirstChild);
  ReadNextAtom; // read name
  if not AtomIsIdentifier then exit; // ignore operator procs
  NameAtom:=CurPos;
  ReadNextAtom;
  if AtomIsChar('.') then begin
    // proc is a method body (not a declaration).
    // -> proceed the search normally ...
  end else begin
    // proc is a proc declaration
    if ((fdfCollect in Params.Flags)
    or CompareSrcIdentifiers(NameAtom.StartPos,Params.Identifier)) then begin
      // proc identifier found
      // the parameters will be checked by the caller
      {$IFDEF ShowTriedContexts}
      DebugLn('[TFindDeclarationTool.FindIdentifierInProcContext]  Proc-Identifier found="',GetIdentifier(@Src[NameAtom.StartPos]),'"');
      {$ENDIF}
      Params.SetResult(Self,ProcContextNode,NameAtom.StartPos);
      Result:=ifrSuccess;
    end else begin
      // proceed the search normally ...
    end;
  end;
end;

function TFindDeclarationTool.FindIdentifierInClassOfMethod(
  ProcContextNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
{ this function is internally used by FindIdentifierInContext
}
var
  ClassNameAtom: TAtomPosition;
  OldFlags: TFindDeclarationFlags;
  IdentFoundResult: TIdentifierFoundResult;
  CurClassNode: TCodeTreeNode;
  ForExprType: TExpressionType;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ProcContextNode);{$ENDIF}
  Result:=false;
  // if proc is a method, search in class
  // -> find class name
  MoveCursorToNodeStart(ProcContextNode);
  ReadNextAtom; // read keyword
  if UpAtomIs('CLASS') then
    ReadNextAtom;
  ReadNextAtom; // read classname
  ClassNameAtom:=CurPos;
  ReadNextAtom;
  if AtomIsChar('.') then begin
    // proc is a method
    if CompareSrcIdentifiers(ClassNameAtom.StartPos,Params.Identifier) then
    begin
      // the class itself is searched
      // -> proceed the search normally ...
    end else begin
      // search the identifier in the class first
      // search the class in the same unit
      CurClassNode:=FindClassOfMethod(ProcContextNode,true,true);
      repeat
        // search identifier in class
        OldFlags := Params.Flags;
        Params.Flags:=[fdfSearchInAncestors]
                      +(fdfGlobalsSameIdent*Params.Flags)
                      -[fdfExceptionOnNotFound];
        Params.ContextNode:=CurClassNode;
        {$IFDEF ShowTriedContexts}
        DebugLn('[TFindDeclarationTool.FindIdentifierInClassOfMethod]  searching identifier in class of method Identifier=',GetIdentifier(Params.Identifier));
        {$ENDIF}
        if (fdfSearchInHelpers in Params.Flags)
          and (CurClassNode.Desc in [ctnClassHelper,ctnRecordHelper])
          and (Params.GetHelpers(fdhlkDelphiHelper)<>nil)
        then begin
          // override current helper for the type and search in that type
          ForExprType := Params.GetHelpers(fdhlkDelphiHelper).AddFromHelperNode(CurClassNode, Self, True).ForExprType;
          if (ForExprType.Desc = xtContext) and (ForExprType.Context.Node<>nil)
          then begin
            Params.ContextNode:=ForExprType.Context.Node;
            Result:=ForExprType.Context.Tool.FindIdentifierInContext(Params);
          end;
        end else
          Result:=FindIdentifierInContext(Params);
        Params.Flags := OldFlags;
        if Result and Params.IsFoundProcFinal then exit;
        // in a nested class, continue search in enclosing class
        repeat
          CurClassNode:=CurClassNode.Parent;
        until (CurClassNode=nil) or (CurClassNode.Desc in AllClassObjects);
      until CurClassNode=nil;
    end;
  end else begin
    // proc is not a method
    if (fdfCollect in Params.Flags)
    or CompareSrcIdentifiers(ClassNameAtom.StartPos,Params.Identifier) then
    begin
      // proc identifier found
      {$IFDEF ShowTriedContexts}
      DebugLn('[TFindDeclarationTool.FindIdentifierInClassOfMethod]  Proc Identifier found="',GetIdentifier(Params.Identifier),'"');
      {$ENDIF}
      Params.SetResult(Self,ProcContextNode,ClassNameAtom.StartPos);
      IdentFoundResult:=Params.NewCodeTool.DoOnIdentifierFound(Params,
                                                               Params.NewNode);
      Result:=IdentFoundResult=ifrSuccess;
      exit;
    end else begin
      // proceed the search normally ...
    end;
  end;
end;

function TFindDeclarationTool.FindIdentifierInContext(
  Params: TFindDeclarationParams): boolean;
var
  IdentFoundResult: TIdentifierFoundResult;
begin
  Result := FindIdentifierInContext(Params, IdentFoundResult{%H-});
end;

function TFindDeclarationTool.FindClassOfMethod(ProcNode: TCodeTreeNode;
  FindClassContext, ExceptionOnNotFound: boolean): TCodeTreeNode;
var
  ClassNameAtom: TAtomPosition;
  Node: TCodeTreeNode;
  TypeNode: TCodeTreeNode;
  NextNameAtom: TAtomPosition;
  CurClassName: PChar;
  CurClassNode: TCodeTreeNode;

  procedure RaiseClassNotFound;
  begin
    MoveCursorToAtomPos(ClassNameAtom);
    RaiseExceptionFmt(20170421200233,'Class %s not found',[GetAtom]);
  end;

  procedure RaiseNotAClass;
  begin
    MoveCursorToAtomPos(ClassNameAtom);
    RaiseExceptionFmt(20170421200237,'Class expected, but %s found',[GetAtom]);
  end;

begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ProcNode);{$ENDIF}
  {$IFDEF ShowTriedContexts}
  DebugLn('[TFindDeclarationTool.FindClassOfMethod] A ');
  {$ENDIF}
  Result:=nil;
  if ProcNode.Desc=ctnProcedureHead then
    ProcNode:=ProcNode.Parent;
  if (ProcNode.Parent<>nil) and (ProcNode.Parent.Desc in AllClassSections) then begin
    CurClassNode:=ProcNode.Parent.Parent;
    if FindClassContext then begin
      // return the class node
      exit(CurClassNode);
    end else begin
      // return the type identifier node
      exit(CurClassNode.Parent);
    end;
  end;
  
  MoveCursorToNodeStart(ProcNode);
  ReadNextAtom; // read keyword
  if UpAtomIs('CLASS') then ReadNextAtom;
  ReadNextAtom; // read classname
  ClassNameAtom:=CurPos;
  if CurPos.Flag<>cafWord then begin
    if not ExceptionOnNotFound then exit;
    RaiseNotAClass;
  end;
  CurClassName:=@Src[ClassNameAtom.StartPos];
  ReadNextAtom;
  if CurPos.Flag<>cafPoint then begin
    // not a method
    if not ExceptionOnNotFound then exit;
    RaiseNotAClass;
  end;
  ReadNextAtom;
  NextNameAtom:=CurPos;

  //debugln(['TFindDeclarationTool.FindClassOfMethod ClassName="',GetAtom(ClassNameAtom),'"']);

  // proc is a method
  // -> search the class
  Node:=ProcNode;
  repeat
    if Node.Desc=ctnTypeSection then begin
      TypeNode:=Node.LastChild;
      while TypeNode<>nil do begin
        {$IFDEF ShowTriedIdentifiers}
        debugln(['TFindDeclarationTool.FindClassOfMethod ',TypeNode.DescAsString,' ',dbgstr(ExtractNode(TypeNode,[]),1,40)]);
        {$ENDIF}
        if ((TypeNode.Desc=ctnTypeDefinition)
        and (CompareIdentifierPtrs(CurClassName,@Src[TypeNode.StartPos])=0))
        or ((TypeNode.Desc=ctnGenericType)
        and (TypeNode.FirstChild<>nil)
        and (CompareIdentifierPtrs(CurClassName,@Src[TypeNode.FirstChild.StartPos])=0))
        then begin
          repeat
            // type with same name found
            //debugln(['TFindDeclarationTool.FindClassOfMethod type found ',ExtractDefinitionName(TypeNode)]);
            CurClassNode:=FindTypeNodeOfDefinition(TypeNode);
            if (CurClassNode=nil) then begin
              if not ExceptionOnNotFound then exit;
              RaiseClassNotFound;
            end;
            if (not (CurClassNode.Desc in AllClassObjects))
            or ((ctnsForwardDeclaration and Node.SubDesc)<>0)
            then begin
              if not ExceptionOnNotFound then exit;
              RaiseNotAClass;
            end;
            //debugln(['TFindDeclarationTool.FindClassOfMethod class found, NextNameAtom=',GetAtom(NextNameAtom)]);
            // class found
            if NextNameAtom.Flag=cafWord then begin
              MoveCursorToAtomPos(NextNameAtom);
              ReadNextAtom;
              if CurPos.Flag<>cafPoint then begin
                if FindClassContext then begin
                  // return the class node
                  exit(CurClassNode);
                end else begin
                  // return the type identifier node
                  exit(TypeNode);
                end;
              end;
              ReadNextAtom;
              ClassNameAtom:=NextNameAtom;
              NextNameAtom:=CurPos;
              CurClassName:=@Src[ClassNameAtom.StartPos];
            end else begin
              // operator or missing sub identifier
              if FindClassContext then begin
                // return the class node
                exit(CurClassNode);
              end else begin
                // return the type identifier node
                exit(TypeNode);
              end;
            end;
            // search sub class
            //debugln(['TFindDeclarationTool.FindClassOfMethod searching sub class "',GetIdentifier(CurClassName),'"']);
            Node:=FindClassMember(CurClassNode,CurClassName);
            if Node=nil then begin
              if not ExceptionOnNotFound then exit;
              RaiseClassNotFound;
            end;
            if not (Node.Desc in [ctnTypeDefinition,ctnGenericType]) then begin
              if not ExceptionOnNotFound then exit;
              RaiseNotAClass;
            end;
            TypeNode:=Node;
          until false;
        end;
        TypeNode:=TypeNode.PriorBrother;
      end;
    end;
    // next
    if Node.PriorBrother<>nil then
      Node:=Node.PriorBrother
    else begin
      Node:=Node.Parent;
      if (Node=nil) or (Node.Desc<>ctnImplementation) then break;
      Node:=Node.PriorBrother;
      if (Node=nil) or (Node.Desc<>ctnInterface) then break;
      Node:=Node.LastChild;
      if Node=nil then break;
    end;
  until false;
  if ExceptionOnNotFound then
    RaiseClassNotFound;
end;

function TFindDeclarationTool.FindClassMember(aClassNode: TCodeTreeNode;
  Identifier: PChar): TCodeTreeNode;
var
  Node: TCodeTreeNode;
  CurIdentifier: PChar;
begin
  Result:=nil;
  if GetIdentLen(Identifier)=0 then exit;
  if aClassNode=nil then exit;
  Node:=aClassNode.LastChild;
  while Node<>nil do begin
    if (Node.Desc in AllClassSections)
    and (Node.FirstChild<>nil) then begin
      Node:=Node.LastChild;
      continue;
    end
    else if Node.Desc in AllSimpleIdentifierDefinitions then begin
      if CompareIdentifierPtrs(@Src[Node.StartPos],Identifier)=0 then
        exit(Node);
    end else if Node.Desc=ctnProperty then begin
      CurIdentifier:=GetPropertyNameIdentifier(Node);
      if CompareIdentifierPtrs(CurIdentifier,Identifier)=0 then
        exit(Node);
    end else if Node.Desc=ctnProcedure then begin
      CurIdentifier:=GetProcNameIdentifier(Node);
      if CompareIdentifierPtrs(CurIdentifier,Identifier)=0 then
        exit(Node);
    end;
    // next
    if Node.PriorBrother<>nil then
      Node:=Node.PriorBrother
    else begin
      repeat
        Node:=Node.Parent;
        if Node=aClassNode then exit;
      until Node.PriorBrother<>nil;
      Node:=Node.PriorBrother;
    end;
  end;
end;

function TFindDeclarationTool.FindClassMember(aClassNode: TCodeTreeNode;
  const Identifier: String; SearchInAncestors: boolean): TFindContext;
var
  Params: TFindDeclarationParams;
begin
  Result.Tool:=Self;
  Result.Node:=FindClassMember(aClassNode,PChar(Identifier));
  if Result.Node<>nil then exit;
  if not SearchInAncestors then begin
    Result:=CleanFindContext;
    exit;
  end;
  Params:=TFindDeclarationParams.Create;
  try
    while Result.Tool.FindAncestorOfClass(aClassNode,Params,True) do begin
      Result.Tool:=Params.NewCodeTool;
      aClassNode:=Params.NewNode;
      Result.Node:=Result.Tool.FindClassMember(aClassNode,PChar(Identifier));
      if Result.Node<>nil then exit;
    end;
    Result:=CleanFindContext;
  finally
    Params.Free;
  end;
end;

function TFindDeclarationTool.FindAncestorOfClass(ClassNode: TCodeTreeNode;
  Params: TFindDeclarationParams; FindClassContext: boolean): boolean;
var
  InheritanceNode: TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ClassNode);{$ENDIF}
  if (ClassNode=nil) or (not (ClassNode.Desc in AllClasses)) then
    RaiseException(20170421200240,'[TFindDeclarationTool.FindAncestorOfClass]  invalid classnode');
  Result:=false;
  
  // ToDo: ppu, dcu

  InheritanceNode:=FindInheritanceNode(ClassNode);
  if (InheritanceNode<>nil)
  and (InheritanceNode.FirstChild<>nil) then begin
    Result:=FindAncestorOfClassInheritance(InheritanceNode.FirstChild,
                                           Params,FindClassContext);
  end else begin
    Result:=FindDefaultAncestorOfClass(ClassNode,Params,FindClassContext);
  end;
end;

function TFindDeclarationTool.FindAncestorOfClassInheritance(
  IdentifierNode: TCodeTreeNode; ResultParams: TFindDeclarationParams;
  FindClassContext: boolean): boolean;
var
  InheritanceNode: TCodeTreeNode;
  ClassNode: TCodeTreeNode;
  SpecializeNode , GenericParamsNode: TCodeTreeNode;
  AncestorContext: TFindContext;
  AncestorStartPos: LongInt;
  ExprType: TExpressionType;
  Params: TFindDeclarationParams;

  procedure RaiseExpected(const Expected: string);
  begin
    MoveCursorToCleanPos(AncestorStartPos);
    ReadNextAtom;
    RaiseExceptionFmt(20170421200243,ctsStrExpectedButAtomFound,[Expected,ExtractNode(IdentifierNode,[])]);
  end;

begin
  {$IFDEF CheckNodeTool}CheckNodeTool(IdentifierNode);{$ENDIF}
  if (IdentifierNode=nil)
  or (not (IdentifierNode.Desc in [ctnIdentifier,ctnSpecialize]))
  or (IdentifierNode.Parent=nil)
  or (IdentifierNode.Parent.Desc<>ctnClassInheritance)
  then
    RaiseException(20170421200245,'[TFindDeclarationTool.FindAncestorOfClass] '
      +' not an inheritance node');
  Result:=false;

  InheritanceNode:=IdentifierNode.Parent;
  ClassNode:=InheritanceNode.Parent;

  if IdentifierNode.Desc=ctnSpecialize then begin
    if (IdentifierNode.FirstChild=nil) then begin
      MoveCursorToCleanPos(IdentifierNode.StartPos);
      ReadNextAtom;
      if UpAtomIs('SPECIALIZE') then
        ReadNextAtom;
      RaiseStringExpectedButAtomFound(20170421200248,'class type');
    end;
    MoveCursorToCleanPos(IdentifierNode.FirstChild.StartPos);
  end else
    MoveCursorToCleanPos(IdentifierNode.StartPos);
  ReadNextAtom;
  AtomIsIdentifierE;
  AncestorStartPos:=CurPos.StartPos;
  ReadNextAtom;

  Params:=TFindDeclarationParams.Create(ResultParams);
  try
    Params.Flags:=fdfDefaultForExpressions;
    Params.ContextNode:=IdentifierNode;
    if CurPos.Flag=cafPoint then begin
      // complex identifier
      {$IFDEF ShowTriedContexts}
      DebugLn(['[TFindDeclarationTool.FindAncestorOfClass] ',
      ' search complex ancestor class = "',ExtractNode(IdentifierNode,[]),'" for class "',ExtractClassName(ClassNode,false),'"']);
      {$ENDIF}
      if not FindClassContext then
        Params.Flags:=Params.Flags+[fdfFindVariable];
      ExprType:=FindExpressionTypeOfTerm(IdentifierNode.StartPos,IdentifierNode.EndPos,Params,false);
      if ExprType.Desc<>xtContext then
        RaiseExpected('type');
      AncestorContext:=ExprType.Context
    end else begin
      // simple identifier
      {$IFDEF ShowTriedContexts}
      DebugLn('[TFindDeclarationTool.FindAncestorOfClass] ',
      ' search ancestor class="',GetIdentifier(@Src[AncestorStartPos]),'" for class "',ExtractClassName(ClassNode,false),'"');
      {$ENDIF}
      Params.SetIdentifier(Self,@Src[AncestorStartPos],nil);
      if not FindIdentifierInContext(Params) then
        exit;
      AncestorContext.Tool:=Params.NewCodeTool;
      AncestorContext.Node:=Params.NewNode;
    end;
  finally
    Params.Free;
  end;

  if FindClassContext then begin
    // search ancestor class context
    if (AncestorContext.Node.Desc in [ctnTypeDefinition,ctnGenericType]) then
    begin
      Params:=TFindDeclarationParams.Create;
      if IdentifierNode.Desc=ctnSpecialize then begin
         SpecializeNode:=IdentifierNode;
         Params.SetGenericParamValues(Self, SpecializeNode);
         if (ClassNode <> nil) then begin
           GenericParamsNode := nil;
           if (ClassNode.Parent <> nil)
           and (ClassNode.Parent.Desc = ctnGenericType) then
             GenericParamsNode:=ClassNode.Parent.FirstChild.NextBrother;
           ResultParams.UpdateGenericParamMapping(Self, SpecializeNode.FirstChild.NextBrother, GenericParamsNode);
         end;
      end;
      try
        Params.Flags:=fdfDefaultForExpressions+[fdfFindChildren];
        AncestorContext:=AncestorContext.Tool.FindBaseTypeOfNode(Params,AncestorContext.Node);
        ResultParams.GenParams:=Params.GenParams;
      finally
        Params.Free;
      end;
    end;
    // check result
    if not (AncestorContext.Node.Desc in AllClasses) then
      RaiseExpected('class');
    if AncestorContext.Node=ClassNode then begin
      MoveCursorToCleanPos(AncestorStartPos);
      ReadNextAtom;
      RaiseException(20170421200252,'cycle detected');
    end;
  end else begin
    // check if class identifier
    if (not (AncestorContext.Node.Desc in [ctnTypeDefinition,ctnGenericType])) then
      RaiseExpected('type');
  end;

  ResultParams.SetResult(AncestorContext);
  Result:=true;
end;

function TFindDeclarationTool.FindAncestorsOfClass(ClassNode: TCodeTreeNode;
  var ListOfPFindContext: TFPList;
  Params: TFindDeclarationParams; FindClassContext: boolean;
  ExceptionOnNotFound: boolean): boolean;
var
  Node: TCodeTreeNode;
  Context: TFindContext;
  InheritanceNode: TCodeTreeNode;
begin
  Result:=false;
  InheritanceNode:=FindInheritanceNode(ClassNode);
  if (InheritanceNode=nil) then
    exit(true);
  Node:=InheritanceNode.FirstChild;
  if Node=nil then begin
    try
      if not FindAncestorOfClass(ClassNode,Params,FindClassContext) then begin
        exit(true); // this is TObject or IInterface, IUnknown
      end else begin
        Context:=CreateFindContext(Params);
      end;
      AddFindContext(ListOfPFindContext,Context);
      Result:=Context.Node<>nil;
    except
      if ExceptionOnNotFound then raise;
    end;
  end else begin
    while Node<>nil do begin
      try
        if FindAncestorOfClassInheritance(Node,Params,FindClassContext) then
        begin
          Context:=CreateFindContext(Params);
          AddFindContext(ListOfPFindContext,Context);
        end;
      except
        if ExceptionOnNotFound then raise;
      end;
      Node:=Node.NextBrother;
    end;
  end;
  Result:=true;
end;

function TFindDeclarationTool.FindForwardIdentifier(
  Params: TFindDeclarationParams; out IsForward: boolean): boolean;
{ first search the identifier in the normal way via FindIdentifierInContext
  then search the other direction }
var
  OldInput: TFindDeclarationInput;
begin
  Params.Save(OldInput);
  Exclude(Params.Flags,fdfExceptionOnNotFound);
  Result:=FindIdentifierInContext(Params);
  if not Result then begin
    Params.Load(OldInput,false);
    Params.Flags:=Params.Flags+[fdfSearchForward,fdfIgnoreCurContextNode];
    Result:=FindIdentifierInContext(Params);
    IsForward:=true;
  end else begin
    IsForward:=false;
  end;
  Params.Load(OldInput,true);
end;

function TFindDeclarationTool.FindNonForwardClass(ForwardNode: TCodeTreeNode
  ): TCodeTreeNode;
var
  Node: TCodeTreeNode;
  Identifier: PChar;
begin
  Result:=nil;
  Node:=ForwardNode;
  if Node.Desc=ctnGenericType then begin
    Node:=Node.FirstChild;
    if Node=nil then exit;
  end else if Node.Desc<>ctnTypeDefinition then
    exit;
  Node:=Node.FirstChild;
  if Node=nil then
    Exit;
  Identifier:=@Src[Node.StartPos];
  if (Node=nil)
  or (not (Node.Desc in AllClasses))
  or ((ctnsForwardDeclaration and Node.SubDesc)=0) then
    exit;
  Node:=ForwardNode;
  repeat
    //DebugLn(['TFindDeclarationTool.FindNonForwardClass Node=',dbgstr(copy(Src,Node.StartPos,20))]);
    if Node.NextBrother<>nil then
      Node:=Node.NextBrother
    else if (Node.Parent=nil)
    or (not (Node.Parent.Desc in AllDefinitionSections)) then
      break
    else begin
      Node:=Node.Parent.NextBrother;
      while (Node<>nil)
      and ((Node.FirstChild=nil) or (not (Node.Desc in AllDefinitionSections)))
      do
        Node:=Node.NextBrother;
      if Node=nil then break;
      Node:=Node.FirstChild;
    end;
    if CompareSrcIdentifiers(Node.StartPos,Identifier) then begin
      Result:=Node;
      exit;
    end;
  until false;
end;

function TFindDeclarationTool.FindNonForwardClass(Params: TFindDeclarationParams
  ): boolean;
var
  Node: TCodeTreeNode;
begin
  Node:=FindNonForwardClass(Params.NewNode);
  if Node<>nil then begin
    Params.SetResult(Self,Node,Node.StartPos);
    Result:=true;
  end else begin
    Result:=false;
  end;
end;

function TFindDeclarationTool.FindIdentifierInWithVarContext(
  WithVarNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
{ this function is internally used by FindIdentifierInContext }
var
  WithVarExpr: TExpressionType;
  OldInput: TFindDeclarationInput;
  OldExtractedOperand, NewExtractedOperand: string;
begin
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.FindIdentifierInWithVarContext] Ident=',
  '"',GetIdentifier(Params.Identifier),'"',
  ' WithStart=',StringToPascalConst(copy(Src,WithVarNode.StartPos,15))
  );
  {$ENDIF}
  {$IFDEF CheckNodeTool}CheckNodeTool(WithVarNode);{$ENDIF}
  Result:=false;
  // find the base type of the with variable
  // move cursor to end of with-variable
  Params.Save(OldInput);
  Params.ContextNode:=WithVarNode;
  Params.Flags:=Params.Flags*fdfGlobals
                +[fdfExceptionOnNotFound,fdfFunctionResult,fdfFindChildren];
  OldExtractedOperand:=Params.ExtractedOperand;
  WithVarExpr:=FindExpressionTypeOfTerm(WithVarNode.StartPos,-1,Params,true);
  if fdfExtractOperand in Params.Flags then
    NewExtractedOperand:=Params.ExtractedOperand+'.'
  else
    NewExtractedOperand:='';
  if (WithVarExpr.Desc<>xtContext)
  or (WithVarExpr.Context.Node=nil)
  or (WithVarExpr.Context.Node=OldInput.ContextNode)
  or (not (WithVarExpr.Context.Node.Desc in (AllClasses+[ctnEnumerationType])))
  then begin
    MoveCursorToCleanPos(WithVarNode.StartPos);
    RaiseException(20170421200254,ctsExprTypeMustBeClassOrRecord);
  end;
  // search identifier in 'with' context
  // Note: do not search in parent nodes (e.g. with ListBox1 do Items)
  Params.Load(OldInput,false);
  Params.Flags:=Params.Flags-[fdfExceptionOnNotFound,fdfSearchInParentNodes];
  Params.ContextNode:=WithVarExpr.Context.Node;
  Result:=WithVarExpr.Context.Tool.FindIdentifierInContext(Params);
  Params.Load(OldInput,true);
  if fdfExtractOperand in Params.Flags then
    if Result then
      Params.FExtractedOperand:=NewExtractedOperand
    else
      Params.FExtractedOperand:=OldExtractedOperand;
end;

function TFindDeclarationTool.FindIdentifierInAncestors(
  ClassNode: TCodeTreeNode; Params: TFindDeclarationParams;
  var IdentFoundResult: TIdentifierFoundResult): boolean;
{ this function is internally used by FindIdentifierInContext
  and FindBaseTypeOfNode
}

  function Search(AncestorTool: TFindDeclarationTool;
    AncestorClassNode: TCodeTreeNode): boolean;
  var
    OldFlags: TFindDeclarationFlags;
  begin
    OldFlags := Params.Flags;
    Params.ContextNode:=AncestorClassNode;
    Params.Flags:=Params.Flags
      -[fdfIgnoreCurContextNode,fdfSearchInParentNodes]
      +[fdfSearchInAncestors];
    Result:=AncestorTool.FindIdentifierInContext(Params,IdentFoundResult);
    Params.Flags := OldFlags;
  end;

var
  InheritanceNode: TCodeTreeNode;
  Node: TCodeTreeNode;
  SearchDefaultAncestor: Boolean;
begin
  Result:=false;
  {$IFDEF CheckNodeTool}CheckNodeTool(ClassNode);{$ENDIF}

  if not (fdfSearchInAncestors in Params.Flags) then exit;

  SearchDefaultAncestor:=true;
  InheritanceNode:=FindInheritanceNode(ClassNode);
  if (InheritanceNode<>nil) then begin
    Node:=InheritanceNode.FirstChild;
    while Node<>nil do begin
      if not FindAncestorOfClassInheritance(Node,Params,true) then exit;
      SearchDefaultAncestor:=false;
      if Search(Params.NewCodeTool,Params.NewNode) then exit(true);
      Node:=Node.NextBrother;
    end;
  end;
  //debugln(['TFindDeclarationTool.FindIdentifierInAncestors SearchDefaultAncestor=',SearchDefaultAncestor,' ',CleanPosToStr(ClassNode.StartPos,true)]);
  if SearchDefaultAncestor then begin
    if not FindDefaultAncestorOfClass(ClassNode,Params,true) then exit;
    //debugln(['TFindDeclarationTool.FindIdentifierInAncestors search in default ancestor ',FindContextToString(CreateFindContext(Params.NewCodeTool,Params.NewNode))]);
    Result:=Search(Params.NewCodeTool,Params.NewNode);
  end;
end;

{$IFDEF DebugPrefix}
procedure TFindDeclarationTool.DecPrefix;
begin
  DebugPrefix:=copy(DebugPrefix,1,length(DebugPrefix)-2);
end;

procedure TFindDeclarationTool.IncPrefix;
begin
  DebugPrefix:=DebugPrefix+'  ';
end;
{$ENDIF}

function TFindDeclarationTool.FindExpressionResultType(
  Params: TFindDeclarationParams; StartPos, EndPos: integer;
  AliasType: PFindContext): TExpressionType;
{
- operators
    - mixing ansistring and shortstring gives ansistring
    - Pointer +,- Pointer gives Pointer
    - Sets:
        [enum1] gives  set of enumeration type
        set *,-,+ set   gives set of same type
        set <>,=,<,> set  gives boolean
    - precedence rules table:
        1. brackets
        2. not @ sign
        3. * / div mod and shl shr as
        4. + - or xor
        5. < <> > <= >= in is
    - nil is compatible to pointers and classes
    

- operator overloading?
- internal types. e.g. string[], ansistring[], shortstring[], pchar[] to char
- the type of a subrange is the type of the first constant/enum/number/char
- predefined types:
    ordinal:
      int64, cardinal, QWord, boolean, bytebool, wordbool, qwordbool, longbool, char
      
    real:
      real, single, double, extended, cextended, comp, currency
      
- predefined functions:
    function pred(ordinal type): ordinal constant of same type;
    function succ(ordinal type): ordinal constant of same type;
    function ord(ordinal type): ordinal type;
    val?
    function low(array): type of leftmost index type in the array;
    function high(array): type of leftmost index type in the array;
    procedure dec(ordinal var);
    procedure dec(ordinal var; ordinal type);
    procedure dec(pointer var);
    procedure dec(pointer var; ordinal type);
    procedure inc(ordinal var);
    procedure inc(ordinal var; ordinal type);
    procedure inc(pointer var);
    procedure inc(pointer var; ordinal type);
    procedure write(...);
    procedure writeln(...);
    function SizeOf(type): ordinal constant;
    typeinfo?
    uniquestring?
    procedure include(set type,enum identifier);
    procedure exclude(set type,enum identifier);
    function objcselector(string): sel;
}
type
  TOperandAndOperator = record
    Operand: TOperand;
    theOperator: TAtomPosition;
    OperatorLvl: integer;
  end;
  POperandAndOperator = ^TOperandAndOperator;
  TExprStack = array[0..4] of TOperandAndOperator;
var
  CurExprType: TExpressionType;
  CurAliasType: PFindContext;
  AliasTypeStorage: TFindContext;
  ExprStack: TExprStack;
  StackPtr: integer;

  procedure ExecuteStack(Complete: boolean);
  { Executes the operand+operator stack
    Examples:
      Position Operand Operator
         0      AWord     *
         1      AByte     +
      Because * has higher predence than + the stack is executed:
      AWord*AByte gives an integer. New stack
      Position Operand Operator
         0      Integer   +
  }
  var
    NewOperand: TOperand;
    LastPos: TAtomPosition;
  begin
    if StackPtr<=0 then begin
      // only one element -> nothing to do
      exit;
    end;
    LastPos:=CurPos;
    {$IFDEF ShowExprEval}
    DebugLn('[TFindDeclarationTool.FindExpressionResultType.ExecuteStack] ',
      ' StackPtr=',dbgs(StackPtr),
      ' Lvl=',dbgs(ExprStack[StackPtr].OperatorLvl),
      ' Complete=',dbgs(Complete));
    {$ENDIF}
    while (StackPtr>0)
    and (Complete
     or (ExprStack[StackPtr-1].OperatorLvl<=ExprStack[StackPtr].OperatorLvl)) do
    begin
      // next operand has a higher or equal precedence
      // (lower is computed before higher)
      // -> calculate last two operands
      NewOperand:=CalculateBinaryOperator(ExprStack[StackPtr-1].Operand,
        ExprStack[StackPtr].Operand,ExprStack[StackPtr-1].theOperator,
        Params);
      // put result on stack
      ExprStack[StackPtr-1]:=ExprStack[StackPtr];

      dec(StackPtr);
      ExprStack[StackPtr].Operand:=NewOperand;
    end;
    MoveCursorToAtomPos(LastPos);
  end;
  
  procedure RaiseBinaryOperatorNotFound;
  begin
    RaiseExceptionFmt(20170421200256,ctsStrExpectedButAtomFound,[ctsBinaryOperator,GetAtom]);
  end;
  
  procedure RaiseInternalError;
  begin
    RaiseException(20170421200300,'[TFindDeclarationTool.FindExpressionResultType]'
      +' internal error: unknown precedence lvl for operator '+GetAtom);
  end;

  procedure RaiseInternalErrorStack;
  begin
    RaiseException(20170421200303,'[TFindDeclarationTool.FindExpressionResultType]'
      +' internal error: stackptr too big ');
  end;

var
  OldFlags: TFindDeclarationFlags;
  StackEntry: POperandAndOperator;
  IsEnd, IsBinOpError: Boolean;
begin
  {$IFDEF ShowExprEval}
  DebugLn(['[TFindDeclarationTool.FindExpressionResultType] Start',
  ' Pos=',StartPos,'-',EndPos,
  '="',dbgstr(Src,StartPos,EndPos-StartPos),'" Context=',Params.ContextNode.DescAsString,' Alias=',AliasType<>nil]);
  {$ENDIF}
  Result:=CleanExpressionType;
  if (AliasType<>nil) and (AliasType^.Node=nil) then begin
    AliasTypeStorage:=CleanFindContext;
    CurAliasType:=@AliasTypeStorage;
  end else
    CurAliasType:=nil;
  OldFlags:=Params.Flags;
  Exclude(Params.Flags,fdfFindVariable);
  // read the expression from left to right and calculate the type
  StackPtr:=-1;
  MoveCursorToCleanPos(StartPos);
  repeat
    // read operand
    CurExprType:=ReadOperandTypeAtCursor(Params,EndPos,CurAliasType);
    {$IFDEF ShowExprEval}
    DebugLn(['[TFindDeclarationTool.FindExpressionResultType] Operand: ',
      ExprTypeToString(CurExprType),' Alias=',FindContextToString(CurAliasType)]);
    {$ENDIF}
    // put operand on stack
    inc(StackPtr);
    if StackPtr>High(ExprStack) then
      RaiseInternalErrorStack;
    StackEntry:=@ExprStack[StackPtr];
    StackEntry^.Operand.Expr:=CurExprType;
    if CurAliasType<>nil then
      StackEntry^.Operand.AliasType:=CurAliasType^
    else
      StackEntry^.Operand.AliasType:=CleanFindContext;
    StackEntry^.theOperator.StartPos:=-1;
    StackEntry^.OperatorLvl:=5;
    // read operator
    ReadNextAtom;
    {$IFDEF ShowExprEval}
    DebugLn('[TFindDeclarationTool.FindExpressionResultType] Operator: ',
      GetAtom,' CurPos.EndPos=',dbgs(CurPos.EndPos),' EndPos=',dbgs(EndPos));
    {$ENDIF}
    IsEnd := (CurPos.EndPos>EndPos) or (CurExprType.Desc=xtNone);
    if not IsEnd then
      IsBinOpError := not WordIsBinaryOperator.DoItCaseInsensitive(Src,CurPos.StartPos,
        CurPos.EndPos-CurPos.StartPos)
    else
      IsBinOpError := False;
    // check if expression is completely parsed
    if IsEnd or (IsBinOpError and (fdfIgnoreOperatorError in Params.Flags)) then
    begin
      // -> execute complete stack
      ExecuteStack(true);
      Result:=ExprStack[StackPtr].Operand.Expr;
      if CurAliasType<>nil then
        AliasType^:=ExprStack[StackPtr].Operand.AliasType;
      Params.Flags:=OldFlags;
      exit;
    end;
    if IsBinOpError then
      RaiseBinaryOperatorNotFound;
    // put operator on stack
    ExprStack[StackPtr].theOperator:=CurPos;
    // find operator precendence level
    if WordIsLvl1Operator.DoItCaseInsensitive(Src,CurPos.StartPos,
            CurPos.EndPos-CurPos.StartPos)
    then
      ExprStack[StackPtr].OperatorLvl:=1
    else if WordIsLvl2Operator.DoItCaseInsensitive(Src,CurPos.StartPos,
            CurPos.EndPos-CurPos.StartPos)
    then
      ExprStack[StackPtr].OperatorLvl:=2
    else if WordIsLvl3Operator.DoItCaseInsensitive(Src,CurPos.StartPos,
            CurPos.EndPos-CurPos.StartPos)
    then
      ExprStack[StackPtr].OperatorLvl:=3
    else if WordIsLvl4Operator.DoItCaseInsensitive(Src,CurPos.StartPos,
            CurPos.EndPos-CurPos.StartPos)
    then
      ExprStack[StackPtr].OperatorLvl:=4
    else
      RaiseInternalError;
    // execute stack if possible
    ExecuteStack(false);
    // move cursor to next atom (= next operand start)
    ReadNextAtom;
  until false;
end;

function TFindDeclarationTool.FindIdentifierInUsesSection(
  UsesNode: TCodeTreeNode; Params: TFindDeclarationParams;
  FindMissingFPCUnits: Boolean): boolean;
{ this function is internally used by FindIdentifierInContext

   search backwards through the uses section
   compare first all unit names, then load the units and search there
}
var
  NewCodeTool: TFindDeclarationTool;
  OldFlags: TFindDeclarationFlags;
  Node: TCodeTreeNode;
  CollectResult: TIdentifierFoundResult;
  MissingUnit: TCodeTreeNode;

  procedure RaiseUnitNotFound;
  var
    AnUnitName: String;
    InFilename: String;
  begin
    AnUnitName:=ExtractUsedUnitName(MissingUnit,@InFilename);
    RaiseExceptionInstance(
      ECodeToolUnitNotFound.Create(Self,20170421200312,
        Format(ctsUnitNotFound,[AnUnitName]),InFilename));
  end;

var
  AnUnitName: string;
  InFilename: string;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(UsesNode);{$ENDIF}
  {$IFDEF ShowTriedParentContexts}
  DebugLn(['TFindDeclarationTool.FindIdentifierInUsesSection ',MainFilename,' fdfIgnoreUsedUnits=',fdfIgnoreUsedUnits in Params.Flags]);
  {$ENDIF}
  Result:=false;
  // first search the identifier in the uses section (not in the interfaces of the units)
  if (Params.IdentifierTool=Self) then begin
    Node:=UsesNode.LastChild;
    while Node<>nil do begin
      if (fdfCollect in Params.Flags) then begin
        CollectResult:=DoOnIdentifierFound(Params,Node.FirstChild);
        if CollectResult=ifrAbortSearch then begin
          Result:=false;
          exit;
        end else if CollectResult=ifrSuccess then begin
          Result:=true;
          Params.SetResult(Self,Node.FirstChild);
          exit;
        end;
      end else if CompareSrcIdentifiers(Node.StartPos,Params.Identifier) then begin
        // the searched identifier was a uses AUnitName, point to the identifier in
        // the uses section
        // if the unit name has a namespace defined point to the namespace
        Params.SetResult(Self,Node.FirstChild);
        Result:=true;
        exit;
      end;
      Node:=Node.PriorBrother;
    end;
  end;

  if not (fdfIgnoreUsedUnits in Params.Flags) then begin
    MissingUnit:=nil;
    // search in units
    Node:=UsesNode.LastChild;
    while Node<>nil do begin
      AnUnitName:=ExtractUsedUnitName(Node,@InFilename);
      if AnUnitName<>'' then begin
        NewCodeTool:=FindCodeToolForUsedUnit(AnUnitName,InFilename,false);
        if NewCodeTool<>nil then begin
          // search the identifier in the interface of the used unit
          OldFlags:=Params.Flags;
          Params.Flags:=[fdfIgnoreUsedUnits]+(fdfGlobalsSameIdent*Params.Flags)
                       -[fdfExceptionOnNotFound];
          Result:=NewCodeTool.FindIdentifierInInterface(Self,Params);
          Params.Flags:=OldFlags;
          if Result and Params.IsFoundProcFinal then exit;
        end else if MissingUnit=nil then begin
          MissingUnit:=Node;
        end;
        {$IFDEF ShowTriedParentContexts}
        DebugLn(['TFindDeclarationTool.FindIdentifierInUsesSection ',AnUnitName,' Result=',Result]);
        {$ENDIF}
      end;
      Node:=Node.PriorBrother;
    end;

    if (not Result) and (MissingUnit<>nil) then begin
      // identifier not found and there is a missing unit
      if FindMissingFPCUnits and Assigned(FOnRescanFPCDirectoryCache) then
      begin
        AnUnitName := LowerCase(AnUnitName);
        if FFindMissingFPCUnits=nil then
          FFindMissingFPCUnits := TFindIdentifierInUsesSection_FindMissingFPCUnit.Create;
        if not FFindMissingFPCUnits.IsInResults(AnUnitName) // don't rescan twice
        and FFindMissingFPCUnits.Find(AnUnitName, DirectoryCache) then
        begin
          FOnRescanFPCDirectoryCache(Self);
          Result := FindIdentifierInUsesSection(UsesNode, Params, False);
        end else
          RaiseUnitNotFound;
      end else
        RaiseUnitNotFound;
    end;
  end;
end;

function TFindDeclarationTool.FindCodeToolForUsedUnit(const AnUnitName,
  AnUnitInFilename: string; ExceptionOnNotFound: boolean): TFindDeclarationTool;
var
  NewCode: TCodeBuffer;
begin
  Result:=nil;
  NewCode:=FindUnitSource(AnUnitName,AnUnitInFilename,ExceptionOnNotFound);
  if (NewCode=nil) then begin
    // no source found
    if ExceptionOnNotFound then
      RaiseException(20170421200315,'unit '+AnUnitName+' not found');
  end else begin
    // source found -> get codetool for it
    {$IF defined(ShowTriedFiles) or defined(ShowTriedUnits)}
    DebugLn('[TFindDeclarationTool.FindCodeToolForUsedUnit] ',
    ' This source is=',TCodeBuffer(Scanner.MainCode).Filename,
    ' NewCode=',NewCode.Filename);
    {$ENDIF}
    if Assigned(FOnGetCodeToolForBuffer) then
      Result:=FOnGetCodeToolForBuffer(Self,NewCode,false)
    else if NewCode=TCodeBuffer(Scanner.MainCode) then
      Result:=Self;
  end;
end;

function TFindDeclarationTool.FindIdentifierInInterface(
  AskingTool: TFindDeclarationTool; Params: TFindDeclarationParams): boolean;

  function CheckEntry(Entry: PInterfaceIdentCacheEntry): TIdentifierFoundResult;
  begin
    while Entry<>nil do begin
      Params.SetResult(Self,Entry^.Node,Entry^.CleanPos);
      Result:=DoOnIdentifierFound(Params,Params.NewNode);
      if Result in [ifrSuccess,ifrAbortSearch] then
        exit;
      // proceed
      Entry:=Entry^.Overloaded;
    end;
    Result:=ifrProceedSearch;
  end;

var
  CacheEntry: PInterfaceIdentCacheEntry;
  AVLNode: TAVLTreeNode;
begin
  Result:=false;
  // build code tree
  {$IFDEF ShowTriedContexts}
  DebugLn({$IFDEF DebugPrefix}DebugPrefix,{$ENDIF}
  'TFindDeclarationTool.FindIdentifierInInterface',
  ' Ident="',GetIdentifier(Params.Identifier),'"',
  ' IgnoreUsedUnits=',dbgs(fdfIgnoreUsedUnits in Params.Flags),
  ' Self=',TCodeBuffer(Scanner.MainCode).Filename
  );
  {$ENDIF}

  // ToDo: build codetree for ppu, dcu files

  // build tree for pascal source
  if not BuildInterfaceIdentifierCache(true) then exit(false);
  if (AskingTool<>Self) and (AskingTool<>nil) then
    AskingTool.AddToolDependency(Self);
  // search identifier in cache
  if fdfCollect in Params.Flags then begin
    AVLNode:=FInterfaceIdentifierCache.Items.FindLowest;
    while AVLNode<>nil do begin
      CacheEntry:=PInterfaceIdentCacheEntry(AVLNode.Data);
      //DebugLn(['TFindDeclarationTool.FindIdentifierInInterface ',CacheEntry^.Identifier]);
      case CheckEntry(CacheEntry) of
      ifrSuccess: exit(true);
      ifrAbortSearch: exit(false);
      end;
      AVLNode:=FInterfaceIdentifierCache.Items.FindSuccessor(AVLNode);
    end;
  end else begin
    CacheEntry:=FInterfaceIdentifierCache.FindIdentifier(Params.Identifier);
    if CacheEntry=nil then
      exit(false);
    case CheckEntry(CacheEntry) of
    ifrSuccess: exit(true);
    ifrAbortSearch: exit(false);
    end;
  end;

  // proceed search
  Result:=false;
end;

function TFindDeclarationTool.BuildInterfaceIdentifierCache(
  ExceptionOnNotUnit: boolean): boolean;

  procedure ScanForEnums(ParentNode: TCodeTreeNode);
  var
    Node: TCodeTreeNode;
  begin
    Node:=ParentNode.FirstChild;
    if (Node=nil) or (Scanner.GetDirectiveValueAt(sdScopedEnums, Node.StartPos) = '1') then
      Exit;
    while Node<>nil do begin
      if Node.Desc=ctnEnumIdentifier then
        FInterfaceIdentifierCache.Add(@Src[Node.StartPos],Node,Node.StartPos);
      if Node.FirstChild<>nil then
        Node:=Node.FirstChild
      else begin
        while Node.NextBrother=nil do begin
          Node:=Node.Parent;
          if Node=ParentNode then exit;
        end;
        Node:=Node.NextBrother;
      end;
    end;
  end;

  procedure ScanChildren(ParentNode: TCodeTreeNode); forward;

  procedure ScanNode(Node: TCodeTreeNode);
  var
    FirstChild: TCodeTreeNode;
  begin
    case Node.Desc of
    ctnTypeSection,ctnConstSection,ctnVarSection,ctnResStrSection,ctnPropertySection:
      ScanChildren(Node);
    ctnVarDefinition,ctnConstDefinition,ctnTypeDefinition,ctnGlobalProperty:
      begin
        FInterfaceIdentifierCache.Add(@Src[Node.StartPos],Node,Node.StartPos);
        ScanForEnums(Node);
        FirstChild:=Node.FirstChild;
        if (Node.Desc = ctnTypeDefinition) and (FirstChild<>nil) then begin
          case FirstChild.Desc of
          ctnClassHelper, ctnRecordHelper, ctnTypeHelper:
            FInterfaceHelperCache[fdhlkDelphiHelper].AddFromHelperNode(FirstChild, Self,
              True{ use last found helper}
              );
          ctnObjCCategory:
            FInterfaceHelperCache[fdhlkObjCCategory].AddFromHelperNode(FirstChild, Self, false);
          end;
        end;
      end;
    ctnGenericType:
      if Node.FirstChild<>nil then begin
        FInterfaceIdentifierCache.Add(@Src[Node.FirstChild.StartPos],Node,Node.StartPos);
        ScanForEnums(Node);
      end;
    ctnProperty:
      begin
        MoveCursorToPropName(Node);
        FInterfaceIdentifierCache.Add(@Src[CurPos.StartPos],Node,Node.StartPos);
      end;
    ctnProcedure:
      if (Node.FirstChild<>nil) and (not NodeIsOperator(Node)) then
        FInterfaceIdentifierCache.Add(@Src[Node.FirstChild.StartPos],Node,
                                      Node.FirstChild.StartPos);
    end;
  end;

  procedure ScanChildren(ParentNode: TCodeTreeNode);
  var
    Node: TCodeTreeNode;
  begin
    Node:=ParentNode.FirstChild;
    while Node<>nil do begin
      ScanNode(Node);
      Node:=Node.NextBrother;
    end;
  end;

var
  InterfaceNode: TCodeTreeNode;
  Node: TCodeTreeNode;
  HelperKind: TFDHelpersListKind;
begin
  // build tree for pascal source
  //debugln(['TFindDeclarationTool.BuildInterfaceIdentifierCache BEFORE ',MainFilename]);
  BuildTree(lsrImplementationStart);
  //debugln(['TFindDeclarationTool.BuildInterfaceIdentifierCache AFTER ',MainFilename]);
  if Tree.Root=nil then exit(false);

  // search interface section
  InterfaceNode:=FindInterfaceNode;
  if InterfaceNode=nil then begin
    // check source type
    if ExceptionOnNotUnit then begin
      MoveCursorToNodeStart(Tree.Root);
      ReadNextAtom; // read keyword for source type, e.g. 'unit'
      if not UpAtomIs('UNIT') then
        RaiseException(20170421200317,ctsSourceIsNotUnit);
      RaiseException(20170421200319,ctsInterfaceSectionNotFound);
    end;
  end;

  // create tree
  if (FInterfaceIdentifierCache<>nil) and FInterfaceIdentifierCache.Complete then
    exit(true);

  if FInterfaceIdentifierCache=nil then
    FInterfaceIdentifierCache:=TInterfaceIdentifierCache.Create(Self)
  else
    FInterfaceIdentifierCache.Clear;
  FInterfaceIdentifierCache.Complete:=true;
  for HelperKind in TFDHelpersListKind do
    if FInterfaceHelperCache[HelperKind]=nil then
      FInterfaceHelperCache[HelperKind]:=TFDHelpersList.Create(HelperKind)
    else
      FInterfaceHelperCache[HelperKind].Clear;

  // add unit node
  MoveCursorToNodeStart(Tree.Root);
  ReadNextAtom; // keyword unit
  ReadNextAtom;
  FInterfaceIdentifierCache.Add(@Src[CurPos.StartPos],Tree.Root,CurPos.StartPos);

  // create nodes
  if InterfaceNode<>nil then
    // scan interface
    ScanChildren(InterfaceNode)
  else begin
    // scan program
    Node:=Tree.Root;
    while Node<>nil do begin
      ScanNode(Node);
      Node:=Node.NextBrother;
    end;
  end;

  //DebugLn(['TFindDeclarationTool.BuildInterfaceIdentifierCache ',MainFilename,' ',FInterfaceIdentifierCache.Items.Count,' ',GlobalIdentifierTree.Count]);
  Result:=true;
end;

function TFindDeclarationTool.CompareNodeIdentifier(Node: TCodeTreeNode;
  Params: TFindDeclarationParams): boolean;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=false;
  if Node=nil then exit;
  if Node.Desc in AllSourceTypes then begin
    MoveCursorToNodeStart(Node);
    ReadNextAtom;
    if (Node.Desc=ctnProgram) and not UpAtomIs('PROGRAM') then exit;
    ReadNextAtom;
    Result:=CompareSrcIdentifiers(CurPos.StartPos,Params.Identifier);
  end else if (Node.Desc in AllSimpleIdentifierDefinitions)
  or (Node.Desc in [ctnIdentifier,ctnGenericName]) then begin
    Result:=CompareSrcIdentifiers(Node.StartPos,Params.Identifier);
  end else if Node.Desc=ctnGenericType then begin
    if Node.FirstChild<>nil then
      Result:=CompareSrcIdentifiers(Node.FirstChild.StartPos,Params.Identifier);
  end;
end;

function TFindDeclarationTool.GetInterfaceNode: TCodeTreeNode;
begin
  Result:=Tree.Root;
  if Result=nil then begin
    CurPos.StartPos:=-1;
    RaiseException(20170421200323,'[TFindDeclarationTool.GetInterfaceNode] no code tree found');
  end;
  if not (Tree.Root.Desc in AllUsableSourceTypes) then begin
    CurPos.StartPos:=-1;
    RaiseException(20170421200325,ctsUsedUnitIsNotAPascalUnit);
  end;
  Result:=FindInterfaceNode;
  if Result=nil then begin
    CurPos.StartPos:=-1;
    RaiseException(20170421200327,ctsInterfaceSectionNotFound);
  end;
end;

function TFindDeclarationTool.FindIdentifierInUsedUnit(
  const AnUnitName: string; Params: TFindDeclarationParams; ErrorPos: integer
  ): boolean;
{ Note: this function is internally used by FindIdentifierInHiddenUsedUnits
  for hidden used units, like the system unit or the objpas unit
}
var
  NewCode: TCodeBuffer;
  NewCodeTool: TFindDeclarationTool;
  OldFlags: TFindDeclarationFlags;
begin
  Result:=false;
  // open the unit and search the identifier in the interface
  NewCode:=FindUnitSource(AnUnitName,'',true,ErrorPos);
  if NewCode=TCodeBuffer(Scanner.MainCode) then begin
    // Searching again in hidden unit
    DebugLn('WARNING: Searching again in hidden unit: "',NewCode.Filename,'" identifier=',GetIdentifier(Params.Identifier));
    NewCodeTool:=Self;
    MoveCursorToCleanPos(ErrorPos);
    RaiseExceptionFmt(20170421200330,ctsIllegalCircleInUsedUnits,[AnUnitName]);
  end else begin
    // source found -> get codetool for it
    {$IF defined(ShowTriedContexts) or defined(ShowTriedUnits)}
    DebugLn('[TFindDeclarationTool.FindIdentifierInUsedUnit] ',
    ' This source is=',TCodeBuffer(Scanner.MainCode).Filename,
    ' NewCode=',NewCode.Filename,' IgnoreUsedUnits=',dbgs(fdfIgnoreUsedUnits in Params.Flags));
    {$ENDIF}
    NewCodeTool:=nil;
    if not Assigned(FOnGetCodeToolForBuffer) then begin
      MoveCursorToCleanPos(ErrorPos);
      RaiseExceptionFmt(20170421200333,
        'Unable to create codetool for "%s", need OnGetCodeToolForBuffer',
          [NewCode.Filename]);
    end;
    NewCodeTool:=FOnGetCodeToolForBuffer(Self,NewCode,false);
    if NewCodeTool=nil then begin
      MoveCursorToCleanPos(ErrorPos);
      RaiseExceptionFmt(20170421200346,'Unable to create codetool for "%s"',[NewCode.Filename]);
    end;
    // search the identifier in the interface of the used unit
    OldFlags:=Params.Flags;
    Params.Flags:=[fdfIgnoreUsedUnits]+(fdfGlobalsSameIdent*Params.Flags)
                 -[fdfExceptionOnNotFound];
    Result:=NewCodeTool.FindIdentifierInInterface(Self,Params);
    Params.Flags:=OldFlags;
  end;
end;

function TFindDeclarationTool.FindIdentifierInTypeOfConstant(
  VarConstNode: TCodeTreeNode; Params: TFindDeclarationParams): boolean;
{ const a: atype = context;
  for example:  const p: TPoint = (x:0; y:0);
}
var
  TypeNode: TCodeTreeNode;
  ExprType: TExpressionType;
  TypeParams: TFindDeclarationParams;
  OldInput: TFindDeclarationInput;
begin
  Result:=false;
  //debugln(['TFindDeclarationTool.FindIdentifierInTypeOfConstant ',VarConstNode.DescAsString]);
  TypeNode:=VarConstNode.FirstChild;
  if TypeNode=nil then exit;
  if TypeNode.Desc=ctnIdentifier then begin
    // resolve type
    //debugln(['TFindDeclarationTool.FindIdentifierInTypeOfConstant ']);
    TypeParams:=TFindDeclarationParams.Create(Params);
    try
      TypeParams.ContextNode:=TypeNode;
      TypeParams.SetIdentifier(Self,nil,nil);
      TypeParams.Flags:=fdfDefaultForExpressions;
      ExprType:=FindExpressionTypeOfTerm(TypeNode.StartPos,-1,TypeParams,false);
      //debugln(['TFindDeclarationTool.FindIdentifierInTypeOfConstant ExprType=',ExprTypeToString(ExprType)]);
    finally
      TypeParams.Free;
    end;
    if ExprType.Desc=xtContext then begin
      if ExprType.Context.Node.Parent=nil then exit;
      if not (ExprType.Context.Node.Parent.Desc in [ctnTypeDefinition,ctnGenericType])
      then
        exit;
      // search identifier in type
      Params.Save(OldInput);
      Params.ContextNode:=ExprType.Context.Node;
      Params.Flags:=Params.Flags-[fdfIgnoreCurContextNode,fdfSearchInParentNodes];
      Result:=ExprType.Context.Tool.FindIdentifierInContext(Params);
      Params.Load(OldInput,true);
    end;
  end;
end;

procedure TFindDeclarationTool.RaiseUsesExpected(id: int64);
begin
  RaiseExceptionFmt(id,ctsStrExpectedButAtomFound,['"uses"',GetAtom]);
end;

procedure TFindDeclarationTool.RaiseStrConstExpected(id: int64);
begin
  RaiseExceptionFmt(id,ctsStrExpectedButAtomFound,[ctsStringConstant,GetAtom]);
end;

procedure TFindDeclarationTool.BeginParsing(Range: TLinkScannerRange);
begin
  // scan code and init parser
  inherited BeginParsing(Range);

  // now the scanner knows, which compiler mode is needed
  // -> setup compiler dependent tables
  case Scanner.PascalCompiler of
  pcDelphi: WordIsPredefinedIdentifier:=WordIsPredefinedDelphiIdentifier;
  pcPas2js: WordIsPredefinedIdentifier:=WordIsPredefinedPas2jsIdentifier;
  else
    WordIsPredefinedIdentifier:=WordIsPredefinedFPCIdentifier;
  end;
end;

function TFindDeclarationTool.FindIdentifierInHiddenUsedUnits(
  Params: TFindDeclarationParams): boolean;
var
  HiddenUnits: String;
  p: Integer;
  AnUnitName: String;
begin
  Result:=false;
  {$IFDEF ShowTriedContexts}
  DebugLn('[TFindDeclarationTool.FindIdentifierInHiddenUsedUnits] ',
  '"',GetIdentifier(Params.Identifier),'" IgnoreUsedUnits=',dbgs(fdfIgnoreUsedUnits in Params.Flags));
  {$ENDIF}
  if (Tree.Root<>nil) and (not (fdfIgnoreUsedUnits in Params.Flags)) then begin
    HiddenUnits:=Scanner.GetHiddenUsedUnits;
    {$IFDEF ShowTriedContexts}
    debugln(['TFindDeclarationTool.FindIdentifierInHiddenUsedUnits Identifier=',GetIdentifier(Params.Identifier),' ',Scanner.MainFilename,' SourceName=',Scanner.SourceName,' HiddenUnits=',HiddenUnits]);
    {$ENDIF}
    p:=length(HiddenUnits);
    while p>=1 do begin
      while (p>1) and (HiddenUnits[p-1]<>',') do dec(p);
      AnUnitName:=GetDottedIdentifier(@HiddenUnits[p]);
      if AnUnitName<>'' then begin
        // try hidden used unit
        Result:=FindIdentifierInUsedUnit(AnUnitName,Params,0);
        if Result and Params.IsFoundProcFinal then exit;
      end;
      dec(p);
    end;
  end;
end;

function TFindDeclarationTool.FindEndOfTerm(
  StartPos: integer; ExceptionIfNoVariableStart, WithAsOperator: boolean
  ): integer;
{ ExceptionIfNoVariableStart: if false allow starting in the middle of a term

  a variable can have the form:
    A
    A.B()^.C()[]^^.D
    (A).B
    inherited A
    A as B
}
  procedure RaiseIdentNotFound;
  begin
    RaiseExceptionFmt(20170421200525,ctsIdentExpectedButAtomFound,[GetAtom]);
  end;

var
  FirstIdentifier: boolean;

  procedure StartVar;
  begin
    ReadNextAtom;
    if UpAtomIs('INHERITED') then
      ReadNextAtom;
    if UpAtomIs('ARRAY') then
    begin
      ReadNextAtom;
      if UpAtomIs('OF') then
        ReadNextAtom;
    end;
    FirstIdentifier:=true;
    if not (CurPos.Flag in AllCommonAtomWords) then exit;
    AtomIsIdentifierE;
    FirstIdentifier:=false;
    ReadNextAtom;
  end;

begin
  MoveCursorToCleanPos(StartPos);
  StartVar;
  repeat
    case CurPos.Flag of
    cafRoundBracketOpen:
      begin
        ReadTilBracketClose(true);
        FirstIdentifier:=false;
      end;
      
    cafPoint:
      begin
        if FirstIdentifier and ExceptionIfNoVariableStart then
          RaiseIdentNotFound;
        ReadNextAtom;
        AtomIsIdentifierE;
      end;

    cafEdgedBracketOpen:
      begin
        if FirstIdentifier and ExceptionIfNoVariableStart then
          RaiseIdentNotFound;
        ReadTilBracketClose(true);
      end;

    else
      if AtomIsChar('^') then begin
        if FirstIdentifier and ExceptionIfNoVariableStart then
          RaiseIdentNotFound;
      end else if UpAtomIs('AS') then begin
        if not WithAsOperator then
          break;
        StartVar;
        UndoReadNextAtom;
      end else
        break;
    end;
    ReadNextAtom;
  until false;
  if LastAtoms.HasPrior then
    UndoReadNextAtom
  else
    MoveCursorToCleanPos(StartPos);
  Result:=CurPos.EndPos;
end;

function TFindDeclarationTool.FindStartOfTerm(EndPos: integer; InType: boolean
  ): integer;
{ a variable can be combinations of
  1. A.B
  2. A().B
  3. inherited A
  4. A[].
  5. A[].B
  6. A^.
  7. (A).
  8. (A as B)
  9. (@A)
  10. A()[]
  11. nothing (e.g. cursor behind semicolon, keyword or closing bracket)
  12. 'A'.B  (constant.B, type helpers)
}
  procedure RaiseIdentNotFound;
  begin
    RaiseExceptionFmt(20170421200528,ctsIdentExpectedButAtomFound,[GetAtom]);
  end;

var CurAtom, NextAtom: TAtomPosition;
  NextAtomType, CurAtomType: TVariableAtomType;
  StartPos: LongInt;
  CurIsValue, NextIsValue: Boolean;
begin
  StartPos:=FindStartOfAtom(Src,EndPos);
  MoveCursorToCleanPos(StartPos);
  NextAtom:=CurPos;
  if not IsSpaceChar[Src[StartPos]] then
    ReadNextAtom;
  NextAtomType:=GetCurrentAtomType;
  NextIsValue:=NextAtomType in [vatIdentifier,vatPreDefIdentifier,vatNumber,vatStringConstant];
  repeat
    ReadPriorAtom;
    CurAtom:=CurPos;
    CurAtomType:=GetCurrentAtomType;
    if CurAtomType=vatNone then begin
      Result:=NextAtom.StartPos;
      exit;
    end;
    //DebugLn(['TFindDeclarationTool.FindStartOfTerm ',GetAtom,' Cur=',VariableAtomTypeNames[CurAtomType],' Next=',VariableAtomTypeNames[NextAtomType]]);
    if CurAtomType in [vatRoundBracketClose,vatEdgedBracketClose] then begin
      if NextAtomType in [vatRoundBracketOpen,vatRoundBracketClose,
                     vatEdgedBracketOpen,vatEdgedBracketClose,vatPoint,vatUp,
                     vatAS,vatNone,vatSpace]
      then begin
        ReadBackTilBracketOpen(true);
        CurAtom.StartPos:=CurPos.StartPos;
      end else begin
        Result:=NextAtom.StartPos;
        exit;
      end;
    end;
    // check if CurAtom belongs to variable
    if CurAtomType=vatINHERITED then begin
      Result:=CurAtom.StartPos;
      exit;
    end;
    if (CurAtomType in [vatAS,vatKeyword]) then begin
      Result:=NextAtom.StartPos;
      exit;
    end;
    if (CurAtomType=vatUp) and InType then begin
      Result:=NextAtom.StartPos;
      exit;
    end;
    CurIsValue:=CurAtomType in [vatIdentifier,vatPreDefIdentifier,vatNumber,vatStringConstant];

    if (not (CurAtomType in [vatIdentifier,vatPreDefIdentifier,vatNumber,vatStringConstant,
      vatPoint,vatUp,vatEdgedBracketClose,vatRoundBracketClose]))
    or (CurIsValue and NextIsValue)
    then begin
      // boundary found between current and next
      if NextAtom.StartPos>=EndPos then begin
        // no token belongs to a variable (e.g. ; ;)
        Result:=EndPos;
      end else begin
        // the next atom is the start of the variable
        if (not (NextAtomType in [vatSpace,vatIdentifier,vatPreDefIdentifier,vatStringConstant,
          vatRoundBracketClose,vatEdgedBracketClose,vatAddrOp])) then
        begin
          MoveCursorToCleanPos(NextAtom.StartPos);
          ReadNextAtom;
          RaiseIdentNotFound;
        end;
        Result:=NextAtom.StartPos;
      end;
      exit;
    end;
    NextAtom:=CurAtom;
    NextAtomType:=CurAtomType;
    NextIsValue:=CurIsValue;
  until false;
end;

function TFindDeclarationTool.NodeTermInType(Node: TCodeTreeNode): boolean;
begin
  if Node=nil then exit(false);
  Result:=not (Node.Desc in AllPascalStatements);
end;

function TFindDeclarationTool.FindExpressionTypeOfTerm(StartPos,
  EndPos: integer; Params: TFindDeclarationParams; WithAsOperator: boolean;
  AliasType: PFindContext): TExpressionType;
{ examples
  1. A.B
  2. A().B
  3. inherited A
  4. A[]
  5. A[].B
  6. A^.
  7. (A).
  8. (A as B)
  9. (@A)
  10. A as B
}
type
  TIsIdentEndOfVar = (iieovYes, iieovNo, iieovUnknown);
var
  CurAtomType: TVariableAtomType;
  NextAtomType: TVariableAtomType; // next, if CurAtomType is brackets then after the brackets
  PrevAtomType: TVariableAtomType; // previous, start of brackets
  CurAtom, NextAtom: TAtomPosition;
  CurAtomBracketEndPos: integer;
  StartNode: TCodeTreeNode;
  OldInput: TFindDeclarationInput;
  StartFlags: TFindDeclarationFlags;
  IsIdentEndOfVar: TIsIdentEndOfVar;
  FlagCanBeForwardDefined, FlagCanBeForwardDefinedValid: boolean;
  ExprType: TExpressionType;
  FirstParamStartPos: Integer;
  FirstParamProcContext: TFindContext;

  procedure RaiseIdentExpected(const Id: int64);
  begin
    RaiseExceptionFmt(Id,ctsStrExpectedButAtomFound,[ctsIdentifier,GetAtom]);
  end;

  procedure RaiseIllegalQualifierFound(const Id: int64);
  begin
    RaiseExceptionFmt(Id,ctsIllegalQualifier,[GetAtom]);
  end;

  procedure RaisePointNotFound(const Id: int64);
  begin
    RaiseExceptionFmt(Id,ctsStrExpectedButAtomFound,['.',GetAtom]);
  end;

  function InitAtomQueue: boolean;
  
    procedure RaiseInternalError;
    begin
      RaiseException(20170421200543,'internal codetool error: FindExpressionTypeOfVariable '
        +' StartPos='+IntToStr(StartPos)+' EndPos='+IntToStr(EndPos));
    end;
  
  begin
    Result:=false;
    if StartPos<1 then
      StartPos:=FindStartOfTerm(EndPos,NodeTermInType(Params.ContextNode))
    else if EndPos<1 then
      EndPos:=FindEndOfTerm(StartPos,true,WithAsOperator);
    //DebugLn(['InitAtomQueue StartPos=',StartPos,'=',dbgstr(copy(Src,StartPos,10)),' EndPos=',dbgstr(copy(Src,EndPos,10))]);
    if (StartPos<1) then
      RaiseInternalError;
    if StartPos>SrcLen then exit;
    if StartPos=EndPos then begin
      // e.g. cursor behind semicolon, keyword or closing bracket
      exit;
    end;
    {$IFDEF ShowExprEval}
    DebugLn(['  FindExpressionTypeOfTerm InitAtomQueue StartPos=',StartPos,' EndPos=',EndPos,' Expr="',copy(Src,StartPos,EndPos-StartPos),'"']);
    {$ENDIF}
    PrevAtomType:=vatNone;
    MoveCursorToCleanPos(StartPos);
    ReadNextAtom;
    if CurPos.StartPos>SrcLen then exit;
    CurAtom:=CurPos;
    CurAtomType:=GetCurrentAtomType;
    if CurAtomType in [vatRoundBracketOpen,vatEdgedBracketOpen] then
      ReadTilBracketClose(true);
    CurAtomBracketEndPos:=CurPos.EndPos;
    ReadNextAtom;
    NextAtom:=CurPos;
    if NextAtom.EndPos<=EndPos then
      NextAtomType:=GetCurrentAtomType
    else
      NextAtomType:=vatSpace;
    MoveCursorToCleanPos(CurAtom.StartPos);
    IsIdentEndOfVar:=iieovUnknown;
    FlagCanBeForwardDefinedValid:=false;
    Result:=true;
  end;
  
  procedure ReadNextExpressionAtom;
  begin
    PrevAtomType:=CurAtomType;
    CurAtom:=NextAtom;
    CurAtomType:=NextAtomType;
    MoveCursorToCleanPos(NextAtom.StartPos);
    ReadNextAtom;
    if CurAtomType in [vatRoundBracketOpen,vatEdgedBracketOpen] then
      ReadTilBracketClose(true);
    CurAtomBracketEndPos:=CurPos.EndPos;
    ReadNextAtom;
    NextAtom:=CurPos;
    if NextAtom.EndPos<=EndPos then
      NextAtomType:=GetCurrentAtomType
    else
      NextAtomType:=vatSpace;
    MoveCursorToCleanPos(CurAtom.StartPos);
    IsIdentEndOfVar:=iieovUnknown;
  end;
  
  function IsIdentifierEndOfVariable: boolean;
  var BehindFuncAtomType: TVariableAtomType;
  begin
    if IsIdentEndOfVar=iieovUnknown then begin
      if CurAtom.StartPos>=EndPos then begin
        IsIdentEndOfVar:=iieovYes;
      end else if CurAtom.Flag=cafWord then begin
        ReadNextAtom;
        if AtomIsChar('(') then begin
          ReadTilBracketClose(true);
          ReadNextAtom;
        end;
        if CurPos.StartPos<EndPos then begin
          BehindFuncAtomType:=GetCurrentAtomType;
          if (BehindFuncAtomType in [vatPoint,vatUP,
            vatEdgedBracketOpen,vatRoundBracketOpen])
          then
            IsIdentEndOfVar:=iieovNo
          else
            IsIdentEndOfVar:=iieovYes;
        end else begin
          IsIdentEndOfVar:=iieovYes;
        end;
      end else begin
        IsIdentEndOfVar:=iieovNo
      end;
    end;
    Result:=(IsIdentEndOfVar=iieovYes);
  end;

  function CanBeForwardDefined: boolean;
  var
    Node: TCodeTreeNode;
  begin
    if not FlagCanBeForwardDefinedValid then begin
      FlagCanBeForwardDefinedValid:=true;
      FlagCanBeForwardDefined:=false;
      Node:=StartNode;
      while Node<>nil do begin
        if Node.Desc in [ctnTypeDefinition,ctnGenericType] then begin
          FlagCanBeForwardDefined:=true;
          break;
        end else if not (Node.Desc in AllPascalTypes) then
          break;
        Node:=Node.Parent;
      end;
    end;
    Result:=FlagCanBeForwardDefined;
  end;

  procedure ResolveTypeLessProperty;
  begin
    if ExprType.Desc<>xtContext then exit;
    with ExprType.Context do begin
      if not (Node.Desc in [ctnProperty,ctnGlobalProperty]) then exit;
      if Tool.PropNodeIsTypeLess(Node)
      and Tool.MoveCursorToPropName(Node) then begin
        // typeless property => search in ancestors: it can be property with parameters
        Params.Save(OldInput);
        Params.SetIdentifier(Tool,@Tool.Src[Tool.CurPos.StartPos],nil);
        Params.Flags:=[fdfSearchInAncestors,fdfSearchInHelpers];
        if Tool.FindIdentifierInAncestors(Node.Parent.Parent,Params) then begin
          Tool:=Params.NewCodeTool;
          Node:=Params.NewNode;
        end;
        Params.Load(OldInput,true);
      end;
    end;
  end;

  procedure ResolveStringFunctionParam;
  var
    FirstParamAlias: TFindContext;
    FirstParamExprType: TExpressionType;
  begin
    MoveCursorToCleanPos(FirstParamStartPos);
    ReadNextAtom;
    if (CurPos.Flag=cafRoundBracketOpen) then
    begin
      ReadNextAtom;
      FirstParamStartPos := CurPos.StartPos;

      if CurPos.Flag<>cafRoundBracketClose then
      begin
        // read first expressions
        // read til comma or bracket close
        repeat
          while not(AtomIsChar(',') or AtomIsChar('[') or AtomIsChar('(') or AtomIsChar(')')) do
            ReadNextAtom;
          if CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen] then begin
            ReadTilBracketClose(true);
            ReadNextAtom;
          end;
          if (CurPos.StartPos>SrcLen)
          or (CurPos.Flag in [cafRoundBracketClose,cafEdgedBracketClose,cafComma])
          then
            break;
        until false;

        // find expression type
        Params.Flags:=Params.Flags-[fdfExceptionOnNotFound];
        FillChar(FirstParamAlias{%H-}, SizeOf(FirstParamAlias), 0);
        //DebugLn('TFindDeclarationTool.CreateParamExprListFromStatement CurIgnoreErrorAfterPos=',dbgs(CurIgnoreErrorAfterPos),' ExprStartPos=',dbgs(ExprStartPos));
        FirstParamExprType:=FindExpressionResultType(Params,FirstParamStartPos,CurPos.StartPos,@FirstParamAlias);
        if (FirstParamExprType.Desc in [xtAnsiString, xtString, xtShortString]) then
        begin
          ExprType := FirstParamExprType;
          if AliasType<>nil then
            AliasType^ := FirstParamAlias;
        end;
      end;
    end;
  end;
  
  procedure ResolveBaseTypeOfIdentifier;
  { normally not the identifier is searched, but its type
    but there is one exception:
      if the identifier is a function and it is the end of the variable then
      the decision is based on the fdfFunctionResult flag.
  }
  var
    ProcNode, FuncResultNode, FirstParamNode: TCodeTreeNode;
    AtEnd: Boolean;
    CurAliasType: PFindContext;
    Context: TFindContext;
    FirstParamProcExpr: TExpressionType;
    NewParams: TFindDeclarationParams;
  begin
    //DebugLn(['ResolveBaseTypeOfIdentifier ',ExprType.Context.Node<>nil]);
    if ExprType.Desc=xtContext then
      Context:=ExprType.Context
    else
      Context:=CreateFindContext(Self,StartNode);
    if (Context.Node=nil) then exit;

    AtEnd:=IsIdentifierEndOfVariable;
    // check if at the end of the variable
    if AtEnd and (fdfFindVariable in StartFlags) then begin
      // the variable is wanted, not its type
      exit;
    end;
    if (not AtEnd)
    and (Context.Node.Desc in [ctnProperty,ctnGlobalProperty])
    then begin
      ResolveTypeLessProperty;
    end;

    CurAliasType:=nil;
    if AtEnd then CurAliasType:=AliasType;

    // find base type
    Params.Flags:=Params.Flags+[fdfEnumIdentifier]-[fdfFunctionResult,fdfFindChildren];
    {$IFDEF ShowExprEval}
    DebugLn(['  FindExpressionTypeOfTerm ResolveBaseTypeOfIdentifier BEFORE ExprType=',ExprTypeToString(ExprType),' Alias=',CurAliasType<>nil]);
    {$ENDIF}
    ExprType:=Context.Tool.ConvertNodeToExpressionType(
                               Context.Node,Params,CurAliasType);
    {$IFDEF ShowExprEval}
    DebugLn(['  FindExpressionTypeOfTerm ResolveBaseTypeOfIdentifier AFTER ExprType=',ExprTypeToString(ExprType),' Alias=',FindContextToString(CurAliasType)]);
    {$ENDIF}
    if (ExprType.Desc=xtContext)
    and (ExprType.Context.Node.Desc in [ctnProcedure,ctnProcedureHead]) then
    begin
      // check if this is a function
      ProcNode:=ExprType.Context.Node;
      if ProcNode.Desc=ctnProcedureHead then
        ProcNode:=ProcNode.Parent;
      ExprType.Context.Tool.BuildSubTreeForProcHead(ProcNode.FirstChild,
                                                    FuncResultNode);
      {$IFDEF ShowExprEval}
      DebugLn(['  FindExpressionTypeOfTerm ResolveBaseTypeOfIdentifier IsFunction=',FuncResultNode<>nil,' IsIdentifierEndOfVariable=',IsIdentifierEndOfVariable,' fdfFunctionResult in StartFlags=',fdfFunctionResult in StartFlags]);
      {$ENDIF}
      if (FuncResultNode<>nil) then begin
        // it is function
        // -> use the result type instead of the function
        if AtEnd then begin
          // this function identifier is the end of the variable
          if not (fdfFunctionResult in StartFlags) then
            exit;
        end;
        Include(Params.Flags,fdfFunctionResult);
        ExprType:=ExprType.Context.Tool.ConvertNodeToExpressionType(
                                            ProcNode,Params,CurAliasType);

        if  (ExprType.Desc in [xtAnsiString, xtString, xtShortString])
        and (FirstParamStartPos>0)
        and (FirstParamProcContext.Node<>nil) then
        begin
          FirstParamNode := FirstParamProcContext.Node;
          while (FirstParamNode<>nil) and (FirstParamNode.Desc in [ctnProcedure, ctnProcedureHead, ctnParameterList]) do
            FirstParamNode := FirstParamNode.FirstChild;
          if (FirstParamNode<>nil) and (FirstParamNode.Desc=ctnVarDefinition) then
          begin
            while FirstParamNode.NextBrother<>nil do
              FirstParamNode := FirstParamNode.NextBrother;
            FirstParamNode := FirstParamNode.FirstChild;
          end;
          if (FirstParamNode<>nil) and (FirstParamNode.Desc=ctnIdentifier) then
          begin
            NewParams := TFindDeclarationParams.Create(FirstParamProcContext.Tool, FirstParamProcContext.Node);
            try
              FirstParamProcExpr := FirstParamProcContext.Tool.FindExpressionResultType(NewParams, FirstParamNode.StartPos, FirstParamNode.EndPos);
            finally
              NewParams.Free;
            end;
            if FirstParamProcExpr.Desc in [xtAnsiString, xtString, xtShortString] then
              ResolveStringFunctionParam;
          end;
        end;
      end;
    end;
  end;

  function ResolveUseUnit(StartUseUnitNode: TCodeTreeNode): TCodeTreeNode;
  // IsStart=true, NextAtomType=vatPoint,
  // StartUseUnitNameNode.Desc=ctnUseUnit
  // -> Find the longest namespaced used unit (ctnUseUnitNamespace,ctnUseUnitClearName)
  //    or the source name (ctnIdentifier), that fits the start of the
  //    current identifier a.b.c...
  //

    function GetPrevUseUnit(UseUnitNode: TCodeTreeNode): TCodeTreeNode;
    begin
      if UseUnitNode.PriorBrother<>nil then
        Result:=UseUnitNode.PriorBrother
      else begin
        if UseUnitNode.Parent.Parent.Desc=ctnImplementation then begin
          Result:=FindMainUsesNode;
          if Result<>nil then
            Result:=Result.FirstChild;
        end else
          Result:=nil;
      end;
    end;

  var
    UseUnitNode, Node, BestNode: TCodeTreeNode;
    HasNamespace: Boolean;
    Count, Level, BestLevel: Integer;
    p: PChar;
    DottedIdentifier: String;
  begin
    Result:=StartUseUnitNode.FirstChild;
    //debugln(['ResolveUsenit START ',NextAtomType,' ',StartUseUnitNode.DescAsString,' "',GetIdentifier(@Src[CurAtom.StartPos]),'"']);
    // find all candidates
    Count:=0;
    HasNamespace:=false;
    UseUnitNode:=StartUseUnitNode;
    repeat
      if (UseUnitNode.FirstChild<>nil)
      and CompareSrcIdentifiers(CurAtom.StartPos,UseUnitNode.StartPos) then begin
        // found candidate
        inc(Count);
        //debugln(['ResolveUsenit candidate found']);
        if UseUnitNode.FirstChild.Desc=ctnUseUnitNamespace then begin
          HasNamespace:=true;
        end;
      end;
      UseUnitNode:=GetPrevUseUnit(UseUnitNode);
    until UseUnitNode=nil;
    //debugln(['ResolveUsenit CandidateCount=',Count,' HasNamespace=',HasNamespace]);
    if not HasNamespace then exit;

    // multiple uses start with this identifier -> collect candidates
    //debugln(['ResolveUsenit collect candidates ...']);

    // read a.b.c...
    DottedIdentifier:=GetIdentifier(@Src[CurAtom.StartPos]);
    MoveCursorToCleanPos(NextAtom.EndPos);
    Level:=1;
    repeat
      ReadNextAtom;
      if not AtomIsIdentifier then break;
      inc(Level);
      DottedIdentifier:=DottedIdentifier+'.'+GetAtom;
      ReadNextAtom;
    until CurPos.Flag<>cafPoint;
    //debugln(['ResolveUsenit DottedIdentifier="',DottedIdentifier,'"']);

    // find longest dotted unit name in uses and source name
    UseUnitNode:=StartUseUnitNode;
    BestNode:=nil;
    BestLevel:=0;
    repeat
      Node:=UseUnitNode.FirstChild; // ctnUseUnitNamespace or ctnUseUnitClearName
      UseUnitNode:=GetPrevUseUnit(UseUnitNode);
      if (Node<>nil)
      and CompareSrcIdentifiers(CurAtom.StartPos,Node.StartPos) then begin
        // found candidate
        //debugln(['ResolveUseUnit Candidate=',ExtractNode(Node,[])]);
        Level:=1;
        p:=PChar(DottedIdentifier);
        repeat
          inc(p,GetIdentLen(p));
          if p^='.' then inc(p);
          //debugln(['ResolveUseUnit p=',p,' NextBrother=',Node.NextBrother<>nil]);
          if Node.NextBrother=nil then begin
            // fits
            if Level>BestLevel then begin
              BestNode:=Node.Parent;
              BestLevel:=Level;
            end;
            break;
          end else if p^=#0 then begin
            // unitname too long
            break;
          end else begin
            Node:=Node.NextBrother;
            //debugln(['ResolveUseUnit p=',p,' node=',GetIdentifier(@Src[Node.StartPos])]);
            if not CompareSrcIdentifiers(Node.StartPos,p) then
              break;
            inc(Level);
          end;
        until false;
      end;
    until UseUnitNode=nil;
    //debugln(['ResolveUseUnit collected candidates Best=',ExtractNode(BestNode,[])]);

    //debugln(['ResolveUseUnit Src=',Tree.Root.DescAsString,' Name=',GetSourceName(false),' DottedIdentifier="',DottedIdentifier,'"']);
    // check source name
    if (Tree.Root.Desc in AllSourceTypes)
    and (Tree.Root.FirstChild<>nil)
    and (Tree.Root.FirstChild.Desc=ctnSrcName)
    and CompareSrcIdentifiers(Tree.Root.FirstChild.StartPos,PChar(DottedIdentifier))
    then begin
      // found candidate
      Level:=1;
      Node:=Tree.Root.FirstChild.FirstChild;
      //debugln(['ResolveUseUnit Candidate SrcName']);
      p:=PChar(DottedIdentifier);
      repeat
        //debugln('ResolveUseUnit SrcName p=',p,' Node=',ExtractNode(Node,[]));
        if (Node.FirstChild=nil) or (Node.NextBrother.Desc<>ctnIdentifier) then begin
          // fits
          //debugln(['ResolveUseUnit FITS Level=',Level,' Best=',BestLevel]);
          if Level>BestLevel then begin
            // source name fits best
            Result:=Tree.Root.FirstChild.FirstChild;
            // move cursor forward
            while (Result.NextBrother<>nil)
            and (NextAtom.EndPos<EndPos) do begin
              if (Result.NextBrother=nil) then
                exit(Tree.Root);
              ReadNextExpressionAtom; // read point
              ReadNextExpressionAtom; // read namespace/unitname
              //debugln(['ResolveUseUnit Next ',GetAtom(CurAtom)]);
              Result:=Result.NextBrother;
            end;
            //debugln(['ResolveUseUnit SrcName fits better']);
            exit;
          end;
          break;
        end else if p^=#0 then begin
          // source name too long
          break;
        end else begin
          Node:=Node.NextBrother;
          inc(p,GetIdentLen(p));
          if p^='.' then inc(p);
          //debugln('ResolveUseUnit SrcName NEXT p=',p,' Node=',ExtractNode(Node,[]));
          if not CompareSrcIdentifiers(Node.StartPos,p) then
            break;
          inc(Level);
        end;
      until false;
    end;

    Result:=BestNode;
    if Result=nil then exit;

    // Result is now a ctnUseUnit
    Result:=Result.FirstChild;
    // move cursor forward
    while (Result.NextBrother<>nil) and (NextAtom.EndPos<EndPos) do begin
      ReadNextExpressionAtom; // read point
      ReadNextExpressionAtom; // read namespace/unitname
      //debugln(['ResolveUseUnit Next ',GetAtom(CurAtom)]);
      Result:=Result.NextBrother;
    end;
  end;

  function ResolveAttribute(const Context: TFindContext): boolean;
  var
    Identifier: String;
    l: Integer;
  begin
    Result:=false;
    if CurAtom.Flag<>cafWord then exit;
    Identifier:=GetAtom;
    l:=length(Identifier)-length('attribute');
    if (l>0) and (CompareIdentifiers(@Identifier[l+1],'attribute')=0) then
      exit;
    // auto append 'attribute' to typename
    Identifier+='Attribute';
    Params.SetIdentifier(Self,PChar(Identifier),@CheckSrcIdentifier);
    if Context.Tool.FindIdentifierInContext(Params) then begin
      ExprType.Desc:=xtContext;
      ExprType.Context:=CreateFindContext(Params);
      Params.Load(OldInput,true);
      exit(true);
    end;
    Params.Load(OldInput,false);
    Result:=false;
  end;
  
  procedure ResolveIdentifier;
  var
    ProcNode: TCodeTreeNode;
    IdentFound: boolean;
    OldFlags: TFindDeclarationFlags;
    ResultNode: TCodeTreeNode;
    IsStart: Boolean;
    Context: TFindContext;
    IsEnd: Boolean;
    SearchForwardToo: Boolean;
  begin
    // for example  'AnObject[3]'

    {$IFDEF ShowExprEval}
    debugln(['ResolveIdentifier "',GetAtom(CurAtom),'"']);
    {$ENDIF}

    // check special identifiers 'Result' and 'Self'
    IdentFound:=false;
    IsStart:=ExprType.Desc=xtNone;
    IsEnd:=IsIdentifierEndOfVariable;
    if IsStart then begin
      // start context
      if (StartNode.Desc in AllPascalStatements) then begin
        if CompareSrcIdentifiers(CurAtom.StartPos,'SELF') then begin
          // SELF in a method is the object itself
          // -> check if in a method or nested proc of a method
          if fdfExtractOperand in Params.Flags then
            Params.AddOperandPart('Self');
          ProcNode:=StartNode;
          while (ProcNode<>nil) do begin
            if (ProcNode.Desc=ctnProcedure) and NodeIsMethodBody(ProcNode) then
            begin
              ResultNode:=FindClassOfMethod(ProcNode,True,
                fdfExceptionOnNotFound in Params.Flags);
              if (ResultNode<>nil) and
                 (ResultNode.Desc in [ctnClassHelper,ctnRecordHelper,ctnTypeHelper])
              then//Self is helper -> return extended type
              begin
                ExprType := FindExtendedExprOfHelper(ResultNode);
                ResultNode := ExprType.Context.Node;
              end else
              begin//Self is class/record
                if (ResultNode<>nil) and (ResultNode.Parent<>nil) then
                begin
                  ExprType.Desc:=xtContext;
                  ExprType.Context.Tool:=Self;
                end else
                  ExprType := CleanExpressionType;
              end;
              if IsEnd and (ResultNode<>nil) then
                ResultNode := ResultNode.Parent;
              ExprType.Context.Node:=ResultNode;
              IdentFound:=ExprType.Desc<>xtNone;
              break;
            end;
            ProcNode:=ProcNode.Parent;
          end;
        end else if CompareSrcIdentifiers(CurAtom.StartPos,'RESULT')
        and (cmsResult in Scanner.CompilerModeSwitches) then begin
          // RESULT has a special meaning in a function
          // -> check if in a function
          if fdfExtractOperand in Params.Flags then
            Params.AddOperandPart('Result');
          ProcNode:=StartNode;
          while (ProcNode<>nil) do begin
            if (ProcNode.Desc=ctnProcedure)
            and (NodeIsFunction(ProcNode) or NodeIsOperator(ProcNode)) then
              break;
            ProcNode:=ProcNode.Parent;
          end;
          if (ProcNode<>nil) then begin
            if IsEnd and (fdfFindVariable in StartFlags) then begin
              BuildSubTreeForProcHead(ProcNode);
              ResultNode:=ProcNode.FirstChild.FirstChild;
              while (ResultNode<>nil) do begin
                if ResultNode.Desc in [ctnVarDefinition,ctnIdentifier] then begin
                  // procedure: none
                  // operator: ctnVarDefinition,ctnIdentifier
                  // function: ctnIdentifier
                  ExprType.Desc:=xtContext;
                  ExprType.Context.Node:=ResultNode;
                  ExprType.Context.Tool:=Self;
                  exit;
                end;
                ResultNode:=ResultNode.NextBrother;
              end;
            end else begin
              OldFlags:=Params.Flags;
              Params.Flags:=Params.Flags+[fdfFunctionResult,fdfFindChildren];
              ExprType.Context:=FindBaseTypeOfNode(Params,ProcNode);
              ExprType.Desc:=xtContext;
              Params.Flags:=OldFlags;
              exit;
            end;
          end;
        end;
      end;
    end;
    // find identifier
    if not IdentFound then begin
      if not (ExprType.Desc in [xtContext,xtNone]) then
      begin
        // find special sub identifier
        if (ExprType.Desc in xtAllTypeHelperTypes) then
        begin
          // found predefined basic type (e.g. string) without a context!
          // -> search in type helpers
          Params.Save(OldInput);
          // build new param flags for sub identifiers
          Params.Flags:=[fdfSearchInAncestors,fdfExceptionOnNotFound,fdfSearchInHelpers]
                        +(fdfGlobals*Params.Flags);
          Params.SetIdentifier(Self,@Src[CurAtom.StartPos],nil);
          {$IFDEF ShowExprEval}
          debugln(['ResolveIdentifier searching "',GetAtom(CurAtom),'" in helper of predefined type "',ExprTypeToString(ExprType),'"']);
          {$ENDIF}
          if FindIdentifierInBasicTypeHelpers(ExprType.Desc, Params) then
          begin
            ExprType.Desc:=xtContext;
            ExprType.SubDesc:=xtNone;
            ExprType.Context.Tool := Params.NewCodeTool;
            ExprType.Context.Node := Params.NewNode;
            {$IFDEF ShowExprEval}
            debugln(['ResolveIdentifier "',GetAtom(CurAtom),'" Found In Helper: "',ExprTypeToString(ExprType),'"']);
            {$ENDIF}
          end else begin
            {$IFDEF ShowExprEval}
            debugln(['ResolveIdentifier "',GetAtom(CurAtom),'" NOT Found In Helper']);
            {$ENDIF}
          end;
          Params.Load(OldInput,true);
        end;

        if ExprType.Desc in xtAllPredefinedTypes then begin
          ExprType:=FindExpressionTypeOfPredefinedIdentifier(CurAtom.StartPos,
                                                             Params);
          {$IFDEF CheckNodeTool}
          if ExprType.Desc=xtContext then
            ExprType.Context.Tool.CheckNodeTool(ExprType.Context.Node);
          {$ENDIF}
          {$IFDEF ShowExprEval}
          debugln(['ResolveIdentifier Predefined  "',GetAtom(CurAtom),'" : ',ExprType.Desc in xtAllTypeHelperTypes]);
          {$ENDIF}
        end;
      end else
      begin
        // find identifier
        if ExprType.Desc=xtContext then
          Context:=ExprType.Context
        else
          Context:=CreateFindContext(Self,StartNode);
        Params.Save(OldInput);
        // build new param flags for sub identifiers
        Params.Flags:=[fdfSearchInAncestors,fdfExceptionOnNotFound,fdfSearchInHelpers]
                      +(fdfGlobals*Params.Flags);
        Params.ContextNode:=Context.Node;
        SearchForwardToo:=false;
        if Context.Node=StartNode then begin
          // there is no special context -> search in parent contexts too
          Params.Flags:=Params.Flags+[fdfSearchInParentNodes,fdfIgnoreCurContextNode];
          // check if searching forward too
          if CanBeForwardDefined then begin
            SearchForwardToo:=true;
            Params.Flags:=Params.Flags-[fdfExceptionOnNotFound];
          end;
        end else begin
          // only search in special context
          Params.Flags:=Params.Flags+[fdfIgnoreUsedUnits];
          if Assigned(Context.Node) and (Context.Node.Desc=ctnImplementation) then
            Params.Flags:=Params.Flags+[fdfSearchInParentNodes];
          if Context.Node.Desc=ctnObjCClass then
            Exclude(Params.Flags,fdfExceptionOnNotFound); // ObjCClass has predefined identifiers like 'alloc'
        end;

        // check identifier for overloaded procs
        if (IsEnd and (fdfIgnoreOverloadedProcs in StartFlags))
        then
          Include(Params.Flags,fdfIgnoreOverloadedProcs);

        //debugln(['ResolveIdentifier ',IsEnd,' ',GetAtom(CurAtom),' ',Context.Node.DescAsString,' ',Context.Node.Parent.DescAsString,' ']);
        if IsEnd and (Context.Node.Desc=ctnIdentifier)
        and (Context.Node.Parent.Desc=ctnAttribParam)
        and ResolveAttribute(Context) then begin
          exit;
        end;

        Params.SetIdentifier(Self,@Src[CurAtom.StartPos],@CheckSrcIdentifier);

        // search ...
        {$IFDEF ShowExprEval}
        Debugln(['  FindExpressionTypeOfTerm ResolveIdentifier "',GetIdentifier(Params.Identifier),'" backward ',BoolToStr(IsStart,'Main','Sub'),'Ident="',GetIdentifier(Params.Identifier),'" ContextNode="',Params.ContextNode.DescAsString,'" "',dbgstr(Context.Tool.Src,Params.ContextNode.StartPos,15),'" ',dbgs(Params.Flags)]);
        {$ENDIF}
        ExprType.Desc:=xtNone;
        // first search backwards
        if Context.Tool.FindIdentifierInContext(Params) then begin
          ExprType.Desc:=xtContext;
        end else if SearchForwardToo then begin
          // then search forwards
          Params.Load(OldInput,false);
          Params.SetIdentifier(Self,@Src[CurAtom.StartPos],@CheckSrcIdentifier);
          Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound,
                         fdfIgnoreCurContextNode,fdfSearchForward]
                        +(fdfGlobals*Params.Flags);
          Params.ContextNode:=Context.Node;
          {$IFDEF ShowExprEval}
          DebugLn(['  FindExpressionTypeOfTerm ResolveIdentifier "',GetAtom(CurAtom),'" forward SubIdent="',GetIdentifier(Params.Identifier),'" ContextNode="',Params.ContextNode.DescAsString,'" "',dbgstr(Context.Tool.Src,Params.ContextNode.StartPos,15),'" ',dbgs(Params.Flags)]);
          {$ENDIF}
          if FindIdentifierInContext(Params) then begin
            ExprType.Desc:=xtContext;
          end;
        end;
        if ExprType.Desc=xtContext then begin
          // identifier found
          if Params.NewCodeTool.NodeIsConstructor(Params.NewNode) then begin
            // identifier is a constructor
            if (Context.Node.Desc in AllClassObjects) then begin
              if (not IsEnd) or (not (fdfFindVariable in StartFlags)) then begin
                // examples:
                //   TMyClass.Create.
                //   :=TMyClass.Create;
                // use this class (the constructor can be defined in the ancestor)
                ExprType.Context:=Context;
                Params.Load(OldInput,true);
                exit;
              end;
            end;
          end;
          if IsStart and (NextAtomType=vatPoint)
          and (Params.NewCodeTool=Self)
          and (Params.NewNode.Desc in [ctnUseUnitClearName,ctnUseUnitNamespace])
          then begin
            // first identifier is a used unit -> find longest fitting unitname
            //debugln(['ResolveIdentifier UseUnit FindLongest... ',Params.NewNode.DescAsString,' ',ExtractNode(Params.NewNode,[])]);
            Params.NewNode:=ResolveUseUnit(Params.NewNode.Parent);
            //debugln(['ResolveIdentifier UseUnit FoundLongest: ',Params.NewNode.DescAsString,' ',ExtractNode(Params.NewNode,[])]);
          end;
          ExprType.Context:=CreateFindContext(Params);
          Params.Load(OldInput,true);
        end else begin
          // predefined identifier
          if (Context.Node.Desc=ctnObjCClass)
            and CompareSrcIdentifiers('alloc',Params.Identifier)
          then begin
            // 'alloc' returns the class itself
            ExprType.Context:=Context;
            //debugln(['ResolveIdentifier ',ExprTypeToString(ExprType)]);
            Params.Load(OldInput,true);
            exit;
          end;

          Params.Load(OldInput,true);
          if IsEnd then
            ExprType:=FindExpressionTypeOfPredefinedIdentifier(CurAtom.StartPos,
                                                               Params,AliasType)
          else
            ExprType:=FindExpressionTypeOfPredefinedIdentifier(CurAtom.StartPos,
                                                               Params);
          {$IFDEF CheckNodeTool}
          if ExprType.Desc=xtContext then
            ExprType.Context.Tool.CheckNodeTool(ExprType.Context.Node);
          {$ENDIF}
        end;
      end;
      {$IFDEF ShowExprEval}
      DebugLn(['  FindExpressionTypeOfTerm ResolveIdentifier END Ident="',dbgstr(Src,StartPos,CurAtom.EndPos-StartPos),'" Expr=',ExprTypeToString(ExprType)]);
      {$ENDIF}
    end;
  end;

  procedure ResolveConstant;
  var
    IsStart: Boolean;
  begin
    IsStart:=ExprType.Desc=xtNone;
    if not IsStart then
      RaiseExceptionFmt(20170421200546,ctsOperatorExpectedButAtomFound,[GetAtom]);
    if AtomIsStringConstant then begin
      // string or char constant
      if AtomIsCharConstant then
        ExprType.Desc:=xtChar
      else
        ExprType.Desc:=xtConstString;
      MoveCursorToCleanPos(CurPos.StartPos);
    end
    else if AtomIsNumber then begin
      // ordinal or real constant
      if AtomIsRealNumber then
        ExprType.Desc:=xtConstReal
      else
        ExprType.Desc:=xtConstOrdInteger;
      MoveCursorToCleanPos(CurPos.EndPos);
    end else
      RaiseExceptionFmt(20170421200548,ctsOperatorExpectedButAtomFound,[GetAtom]);
  end;

  procedure ResolveUseUnit;
  var
    AnUnitName: string;
    InFilename: string;
    aTool: TFindDeclarationTool;
    NewCodeTool: TFindDeclarationTool;
    NewNode: TCodeTreeNode;
  begin
    aTool:=ExprType.Context.Tool;
    {$IFDEF ShowExprEval}
    debugln(['  FindExpressionTypeOfTerm ResolveUseUnit used unit -> interface node ',dbgstr(ExprType.Context.Tool.ExtractNode(ExprType.Context.Node,[]))]);
    {$ENDIF}
    AnUnitName:=aTool.ExtractUsedUnitName(ExprType.Context.Node.Parent,@InFilename);
    NewCodeTool:=aTool.FindCodeToolForUsedUnit(AnUnitName,InFilename,true);
    NewCodeTool.BuildInterfaceIdentifierCache(true);
    NewNode:=NewCodeTool.FindInterfaceNode;
    ExprType.Context.Tool:=NewCodeTool;
    ExprType.Context.Node:=NewNode;
  end;

  procedure ResolveChildren;
  var
    NewNode: TCodeTreeNode;
  begin
    if (ExprType.Context.Node=nil) then exit;
    {$IFDEF ShowExprEval}
    debugln(['  FindExpressionTypeOfTerm ResolveChildren']);
    {$ENDIF}
    ResolveBaseTypeOfIdentifier;
    {$IFDEF ShowExprEval}
    debugln(['  FindExpressionTypeOfTerm ResolveChildren ExprType=',ExprTypeToString(ExprType)]);
    //debugln(['ResolveChildren xtContext=',(ExprType.Desc=xtContext),
    //  ' ctnPointerType=',(ExprType.Context.Node.Desc=ctnPointerType),
    //  ' Node=',(ExprType.Context.Node<>StartNode),
    //  ' cmsAutoderef=',(cmsAutoderef in Scanner.CompilerModeSwitches),
    //  ' ',CompilerModeNames[Scanner.CompilerMode]
    //  ]);
    {$ENDIF}
    NewNode:=ExprType.Context.Node;
    if (NewNode=nil) then exit;
    if (NewNode.Desc in AllUsableSourceTypes)
    or (NewNode.Desc=ctnSrcName)
    or ((NewNode.Desc=ctnIdentifier) and (NewNode.Parent.Desc=ctnSrcName)
      and (NewNode.NextBrother=nil))
    then begin
      if ExprType.Context.Tool=Self then begin
        // unit name of this unit => implementation
        // Note: allowed for programs too
        NewNode:=Tree.Root;
        if NewNode.Desc=ctnUnit then begin
          NewNode:=FindImplementationNode;
          if NewNode=nil then
            NewNode:=FindInterfaceNode;
        end;
        {$IFDEF ShowExprEval}
        debugln(['  FindExpressionTypeOfTerm ResolveChildren this unit -> ',NewNode.DescAsString]);
        {$ENDIF}
        ExprType.Context.Node:=NewNode;
      end else begin
        // unit name of another unit => interface
        {$IFDEF ShowExprEval}
        debugln(['  FindExpressionTypeOfTerm ResolveChildren unit -> interface node']);
        {$ENDIF}
        ExprType.Context.Node:=ExprType.Context.Tool.GetInterfaceNode;
      end;
    end
    else if (ExprType.Context.Node.Desc=ctnUseUnitClearName) then begin
      // uses unit name => interface of used unit
      ResolveUseUnit;
    end
    else if (ExprType.Context.Node.Desc=ctnClassOfType) then begin
      // 'class of' => jump to the class
      ExprType.Context:=ExprType.Context.Tool.FindBaseTypeOfNode(Params,ExprType.Context.Node.FirstChild);
    end
    else if (ExprType.Desc=xtContext)
    and (ExprType.Context.Node.Desc=ctnPointerType)
    and (ExprType.Context.Node<>StartNode)
    and (cmsAutoderef in Scanner.CompilerModeSwitches) then begin
      // Delphi knows . as shortcut for ^.
      // -> check for pointer type
      // left side of expression has defined a special context
      // => this '.' is a dereference
      ExprType.Context:=ExprType.Context.Tool.FindBaseTypeOfNode(Params,ExprType.Context.Node.FirstChild);
    end;
  end;

  procedure ResolvePoint;
  begin
    // for example 'A.B'
    if fdfExtractOperand in Params.Flags then
      Params.AddOperandPart('.');
    if (not (NextAtomType in [vatSpace,vatIdentifier,vatPreDefIdentifier])) then
    begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIdentExpected(20191003163224);
    end;
    repeat
      ResolveChildren;
      if ExprType.Desc in xtAllTypeHelperTypes then begin
        // Lazarus supports record helpers for basic types (string) as well (with TYPEHELPERS modeswitch!).
        break;
      end else if (ExprType.Context.Node=nil) then begin
        MoveCursorToCleanPos(CurAtom.StartPos);
        ReadNextAtom;
        RaiseIllegalQualifierFound(20191003163056);
        break;
      end else if ExprType.Context.Node.Desc in AllPointContexts then begin
        // ok, allowed
        break;
      end else if ExprType.Context.Node.Desc = ctnGenericParameter then begin
        // ok, allowed
        Params.UpdateContexWithGenParamValue(ExprType.Context);
      end else begin
        // not allowed
        //debugln(['ResolvePoint ',ExprTypeToString(ExprType)]);
        MoveCursorToCleanPos(CurAtom.StartPos);
        ReadNextAtom;
        RaiseIllegalQualifierFound(20191003163059);
      end;
    until False;
  end;

  procedure ResolveAs;
  begin
    // for example 'A as B'
    if (not (NextAtomType in [vatSpace,vatIdentifier,vatPreDefIdentifier])) then
    begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIdentExpected(20191003163227);
    end;
    // 'as' is a type cast, so the left side is irrelevant
    // -> context is default context
    ExprType.Desc:=xtContext;
    ExprType.Context.Tool:=Self;
    ExprType.Context.Node:=StartNode;
  end;
  
  procedure ResolveUp;
  begin
    // for example:
    //   1. 'PInt = ^integer'  pointer type
    //   2. a^  dereferencing
    {$IFDEF ShowExprEval}
    debugln(['  FindExpressionTypeOfTerm ResolveUp']);
    {$ENDIF}
    if fdfExtractOperand in Params.Flags then
      Params.AddOperandPart('^');
    if (not (NextAtomType in [vatSpace,vatPoint,vatUp,vatAS,vatEdgedBracketOpen]))
    or ((ExprType.Context.Node=nil) and (ExprType.Desc<>xtPointer))
    then begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIllegalQualifierFound(20191003163101);
    end;
    ResolveBaseTypeOfIdentifier;
    if (ExprType.Desc=xtPointer) then begin
      // the compiler type 'Pointer'
      exit;
    end;
    if (ExprType.Context.Node<>StartNode) then begin
      // left side of expression has defined a special context
      // => this '^' is a dereference
      if (not
          (NextAtomType in [vatSpace,vatPoint,vatAS,vatUP,vatEdgedBracketOpen]))
      then begin
        MoveCursorToCleanPos(NextAtom.StartPos);
        ReadNextAtom;
        RaisePointNotFound(20191003163249);
      end;
      if (ExprType.Context.Node=nil)
      or (ExprType.Context.Node.Desc<>ctnPointerType) then begin
        MoveCursorToCleanPos(CurAtom.StartPos);
        RaiseExceptionFmt(20170421200550,ctsIllegalQualifier,['^']);
      end;
      ExprType.Desc:=xtContext;
      ExprType.Context.Node:=ExprType.Context.Node.FirstChild;
    end else if NodeHasParentOfType(ExprType.Context.Node,ctnPointerType) then
    begin
      // this is a pointer type definition
      // -> the default context is ok
    end;
  end;

  procedure ResolveEdgedBracketOpen;
  { for example:  a[]
      this could be:
        1. ranged array      e.g. array[1..2] of
        2. dynamic array     e.g. array of integer
        3. variant array     e.g. array of const
        4. indexed pointer   e.g. PInteger[1]
        5. default property  e.g. Items[Index: integer]
        6. indexed property  e.g. Items[Index: integer]
        7. string character  e.g. string[3]
  }

    procedure RaiseIdentInCurContextNotFound(const Id: int64);
    begin
      ExprType.Context.Tool.RaiseExceptionFmt(Id,ctsStrExpectedButAtomFound,
                                              [ctsIdentifier,GetAtom]);
    end;
  var
    LastAtomPos: TAtomPosition;
  begin
    {$IFDEF ShowExprEval}
    debugln(['  FindExpressionTypeOfTerm ResolveEdgedBracketOpen ',ExprTypeToString(ExprType)]);
    {$ENDIF}
    if fdfExtractOperand in Params.Flags then begin
      // simple copying, todo: expand argument
      Params.AddOperandPart(ExtractBrackets(CurPos.StartPos,[]));
    end;
    if (not (NextAtomType in [vatSpace,vatPoint,vatAs,vatUp,vatRoundBracketClose,
      vatRoundBracketOpen,vatEdgedBracketClose,vatEdgedBracketOpen]))
    then begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIllegalQualifierFound(20191003163104);
    end;

    if (ExprType.Desc=xtContext)
    and (ExprType.Context.Node.Desc=ctnProperty) then begin
      // [] behind a property
      // -> Check if this property has parameters
      ResolveTypeLessProperty;
      if (ExprType.Desc=xtContext)
      and (ExprType.Context.Node.Desc=ctnProperty)
      and ExprType.Context.Tool.PropertyNodeHasParamList(ExprType.Context.Node)
      then begin
        // use the property type
        ResolveChildren;
        exit;
      end;
    end;

    ResolveBaseTypeOfIdentifier;

    if ExprType.Desc in xtAllStringTypes then begin
      ExprType.Desc:=xtChar;
      ExprType.Context.Node:=nil;
      exit;
    end;
    if ExprType.Desc in xtAllWideStringTypes then begin
      ExprType.Desc:=xtWideChar;
      ExprType.Context.Node:=nil;
      exit;
    end;
    if ExprType.Context.Node=nil then begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIllegalQualifierFound(20191003163107);
    end;

    if ExprType.Context.Node.Desc in [ctnRangedArrayType,ctnOpenArrayType] then
    begin
      MoveCursorToCleanPos(CurAtom.StartPos);
      ReadNextAtom; // "["
      ReadNextAtom;
      repeat
        case CurPos.Flag of
        cafRoundBracketClose: RaiseCharExpectedButAtomFound(20191003162217,']');
        cafRoundBracketOpen,
        cafEdgedBracketOpen: ReadTilBracketClose(true);
        cafEdgedBracketClose: break;
        cafComma:
          with ExprType do begin
            LastAtomPos:=CurPos;
            Context:=Context.Tool.FindBaseTypeOfNode(Params,Context.Node.LastChild);
            if not (Context.Node.Desc in [ctnRangedArrayType,ctnOpenArrayType]) then
              RaiseIllegalQualifierFound(20191003162513);
            MoveCursorToAtomPos(LastAtomPos);
          end;
        cafNone:
          if CurPos.StartPos>SrcLen then
            ;
        end;
        ReadNextAtom;
      until CurPos.Flag=cafEdgedBracketClose;
    end;

    {$IFDEF ShowExprEval}
    DebugLn(['  FindExpressionTypeOfTerm ResolveEdgedBracketOpen ExprType=',ExprTypeToString(ExprType)]);
    {$ENDIF}
    case ExprType.Context.Node.Desc of

    ctnOpenArrayType,ctnRangedArrayType:
      begin
        // the array type is the last child node
        //debugln('ResolveEdgedBracketOpen Open/RangedArray LastChild=',ExprType.Context.Node.LastChild.DescAsString);
        if ExprType.Context.Node.LastChild.Desc=ctnOfConstType then begin
          // 'array of const'; the array type is 'TVarRec'

          // => search 'TVarRec'
          Params.Save(OldInput);
          Params.Flags:=[fdfSearchInParentNodes,fdfIgnoreCurContextNode,
                         fdfExceptionOnNotFound,fdfFindChildren];
          // special identifier for TVarRec
          Params.SetIdentifier(Self,'tvarrec',nil);
          Params.ContextNode:=ExprType.Context.Node;
          ExprType.Context.Tool.FindIdentifierInContext(Params);
          ExprType.Context:=CreateFindContext(Params);
          Params.Load(OldInput,true);
        end else begin
          ExprType.Context.Node:=ExprType.Context.Node.LastChild;
        end;
      end;
                                               
    ctnPointerType:
      // the pointer type is the only child node
      ExprType.Context.Node:=ExprType.Context.Node.FirstChild;

    ctnClass, ctnClassInterface, ctnDispinterface, ctnObject, ctnRecordType,
    ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
    ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass:
      begin
        // search default property of the class / interface
        Params.Save(OldInput);
        Params.Flags:=[fdfSearchInAncestors,fdfExceptionOnNotFound,fdfSearchInHelpers]
                      +fdfGlobals*Params.Flags;
        // special identifier '[' for default property
        Params.SetIdentifier(Self,@Src[CurAtom.StartPos],nil);
        Params.ContextNode:=ExprType.Context.Node;
        ExprType.Context.Tool.FindIdentifierInContext(Params);
        ExprType.Context:=CreateFindContext(Params);
        Params.Load(OldInput,true);
      end;

    ctnProperty, ctnGlobalProperty:
      begin
        if not ExprType.Context.Tool.PropertyNodeHasParamList(ExprType.Context.Node) then
          RaiseIdentInCurContextNotFound(20191003163359);
      end;

    ctnIdentifier:
      begin
        MoveCursorToNodeStart(ExprType.Context.Node);
        ReadNextAtom;
        if UpAtomIs('STRING') or UpAtomIs('ANSISTRING')
        or UpAtomIs('SHORTSTRING') then begin
          ExprType.Desc:=xtChar;
          ExprType.Context.Node:=nil;
          exit;
        end else if UpAtomIs('WIDESTRING') or UpAtomIs('UNICODESTRING') then begin
          ExprType.Desc:=xtWideChar;
          ExprType.Context.Node:=nil;
          exit;
        end else begin
          MoveCursorToCleanPos(CurAtom.StartPos);
          ReadNextAtom;
          RaiseIllegalQualifierFound(20191003163124);
        end;
      end;

    else
      MoveCursorToCleanPos(CurAtom.StartPos);
      ReadNextAtom;
      RaiseIllegalQualifierFound(20191003163127);
    end;
  end;

  procedure ResolveRoundBracketOpen;
  begin
    { for example:
        (a+b)   expression bracket: the type is the result type of the
                                    expression.
        a()     typecast or function
    }
    if not (NextAtomType in [vatSpace,vatPoint,vatAs,vatUp,vatRoundBracketClose,
      vatRoundBracketOpen,vatEdgedBracketClose,vatEdgedBracketOpen]) then
    begin
      MoveCursorToCleanPos(NextAtom.StartPos);
      ReadNextAtom;
      RaiseIllegalQualifierFound(20191003163130);
    end;
    if PrevAtomType<>vatNone then begin
      // typecast or function
      {$IFDEF ShowExprEval}
      debugln(['  FindExpressionTypeOfTerm ResolveRoundBracketOpen skip typecast/paramlist="',dbgstr(Src,CurAtom.StartPos,CurAtomBracketEndPos-CurAtom.StartPos),'"']);
      {$ENDIF}
      if fdfExtractOperand in Params.Flags then begin
        if (ExprType.Context.Node<>nil)
        and (ExprType.Context.Node.Desc=ctnTypeDefinition) then begin
          // typecast
          with ExprType.Context do
            Params.AddOperandPart(GetIdentifier(@Tool.Src[Node.StartPos]));
          Params.AddOperandPart('(');
          // assumption: one term in brakets
          FindExpressionTypeOfTerm(CurAtom.StartPos+1,CurAtomBracketEndPos-1,
            Params,false);
          Params.AddOperandPart(')');
        end;
      end;
      if fdfOverrideStringTypesWithFirstParamType in Params.Flags then begin
        if (ExprType.Context.Node<>nil)
        and (ExprType.Context.Node.Desc in [ctnProcedure, ctnProcedureHead])
        and (FirstParamStartPos<0) then begin
          FirstParamStartPos := CurAtom.StartPos;
          FirstParamProcContext := ExprType.Context;
        end;
      end;
    end else begin
      // expression
      {$IFDEF ShowExprEval}
      debugln(['  FindExpressionTypeOfTerm ResolveRoundBracketOpen subexpr="',dbgstr(Src,CurAtom.StartPos,CurAtomBracketEndPos-CurAtom.StartPos),'"']);
      {$ENDIF}
      ExprType:=FindExpressionResultType(Params,CurAtom.StartPos+1,
                                         CurAtomBracketEndPos-1, AliasType);
    end;
  end;

  procedure ResolveINHERITED;
  // for example: inherited A; inherited;
  // inherited skips the class and begins to search in the ancestor class
  var
    ProcNode: TCodeTreeNode;
    ClassNodeOfMethod: TCodeTreeNode;
    HasIdentifier: Boolean;
    Context: TFindContext;
  var
    DefProcNode: TCodeTreeNode;
    HelperForExpr: TExpressionType;
    SearchInHelpersInTheEnd: Boolean;
  begin
    if ExprType.Desc=xtNone then
      Context:=CreateFindContext(Self,StartNode)
    else
      Context:=ExprType.Context;

    if (Context.Node<>StartNode) or (Context.Node=nil) then begin
      MoveCursorToCleanPos(CurAtom.StartPos);
      RaiseIllegalQualifierFound(20191003163133);
    end;
    ProcNode:=GetMethodOfBody(Context.Node);
    if ProcNode=nil then begin
      MoveCursorToCleanPos(CurAtom.StartPos);
      RaiseException(20170421200601,ctsInheritedKeywordOnlyAllowedInMethods);
    end;
    HasIdentifier:=NextAtom.EndPos<=EndPos;
    if HasIdentifier then begin
      if (not (NextAtomType in [vatIdentifier,vatPreDefIdentifier])) then
      begin
        MoveCursorToCleanPos(NextAtom.StartPos);
        ReadNextAtom;
        RaiseIdentExpected(20191003163231);
      end;

      ReadNextExpressionAtom;
    end;
    {$IFDEF ShowExprEval}
    DebugLn('  FindExpressionTypeOfTerm ResolveINHERITED CurAtomType=',
      VariableAtomTypeNames[CurAtomType],
      ' CurAtom="',copy(Src,CurAtom.StartPos,CurAtom.EndPos-CurAtom.StartPos),'"');
    {$ENDIF}

    // find class of method
    ClassNodeOfMethod:=FindClassOfMethod(ProcNode,true,true);

    // find class ancestor
    OldInput.Flags:=Params.Flags;
    Params.Flags:=[fdfSearchInParentNodes,fdfExceptionOnNotFound]
                  +fdfGlobals*Params.Flags;
    FindAncestorOfClass(ClassNodeOfMethod,Params,true);
    Params.Flags:=OldInput.Flags;

    ExprType.Desc:=xtContext;
    ExprType.Context:=CreateFindContext(Params);

    SearchInHelpersInTheEnd := False;
    if ClassNodeOfMethod.Desc in [ctnClassHelper,ctnRecordHelper] then
    begin
      // helpers have different order in "inherited" call.
      // -> first search in extended class and then in helper (applies only to inherited call)
      if (ExprType.Context.Node<>nil) then//inherited helper found -> use it!
        Params.GetHelpers(fdhlkDelphiHelper,true)
          .AddFromHelperNode(ExprType.Context.Node, ExprType.Context.Tool, True)
      else//inherited helper not found -> delete current
        Params.GetHelpers(fdhlkDelphiHelper,true)
          .DeleteHelperNode(ClassNodeOfMethod, Self);

      HelperForExpr := FindExtendedExprOfHelper(ClassNodeOfMethod);
      if HelperForExpr.Desc = xtContext then
      begin
        ExprType.Context := HelperForExpr.Context;
        SearchInHelpersInTheEnd := True;
      end;
    end;

    if (not HasIdentifier) then begin
      // the keyword 'inherited' is the last atom
      if StartFlags*[fdfFindChildren,fdfFindVariable]=[fdfFindVariable] then begin
        // for example: inherited; search the method, not the context
        DefProcNode:=FindCorrespondingProcNode(ProcNode);
        if DefProcNode=nil then begin
          MoveCursorToProcName(ProcNode,true);
          RaiseExceptionFmt(20170421200604,ctsMethodSignatureSNotFoundInClass, [GetAtom]);
        end;
        MoveCursorToProcName(DefProcNode,true);
      end else begin
        // for example: inherited |
        // return the ancestor class context
        exit;
      end;
    end else
      MoveCursorToCleanPos(CurAtom.StartPos);

    // search identifier only in class ancestor
    if SearchInHelpersInTheEnd then
      Params.Flags := Params.Flags + [fdfSearchInHelpersInTheEnd];
    Params.Save(OldInput);
    Params.SetIdentifier(Self,@Src[CurPos.StartPos],@CheckSrcIdentifier);
    Params.ContextNode:=ExprType.Context.Node;
    Params.Flags:=Params.Flags-[fdfSearchInParentNodes]
                              +[fdfExceptionOnNotFound,fdfSearchInAncestors];
    ExprType.Context.Tool.FindIdentifierInContext(Params);
    ExprType.Context:=CreateFindContext(Params);
    Params.Load(OldInput,true);
    Params.Flags := Params.Flags - [fdfSearchInHelpersInTheEnd];
  end;
  
begin
  Result:=CleanExpressionType;
  FirstParamStartPos := -1;
  FirstParamProcContext := CleanFindContext;
  StartFlags:=Params.Flags;
  StartNode:=Params.ContextNode;
  {$IFDEF ShowExprEval}
  DebugLn(['[TFindDeclarationTool.FindExpressionTypeOfTerm] START',
    ' Flags=[',dbgs(Params.Flags),']',
    ' StartContext=',StartNode.DescAsString,'=',dbgstr(Src,StartNode.StartPos,15),
    ' Alias=',AliasType<>nil]
  );
  {$ENDIF}
  {$IFDEF CheckNodeTool}
  CheckNodeTool(StartNode);
  {$ENDIF}

  if not InitAtomQueue then exit;
  ExprType:=CleanExpressionType;
  repeat
    {$IFDEF ShowExprEval}
    DebugLn(['  FindExpressionTypeOfTerm ATOM',
      ' CurAtomType=',VariableAtomTypeNames[CurAtomType],
      ' CurAtom="',GetAtom(CurAtom),'"',
      ' ExprType=',ExprTypeToString(ExprType)]);
    {$ENDIF}
    case CurAtomType of
    vatIdentifier, vatPreDefIdentifier: ResolveIdentifier;
    vatStringConstant,vatNumber: ResolveConstant;
    vatPoint:             ResolvePoint;
    vatAS:                ResolveAs;
    vatUP:                ResolveUp;
    vatEdgedBracketOpen:  ResolveEdgedBracketOpen;
    vatRoundBracketOpen:  ResolveRoundBracketOpen;
    vatINHERITED:         ResolveINHERITED;
    end;
    ReadNextExpressionAtom;
  until CurAtom.EndPos>EndPos;

  if fdfFunctionResult in StartFlags then
    ResolveChildren;

  Result:=ExprType;
  if (Result.Desc=xtContext) and (not (fdfFindVariable in StartFlags))
  and (not (Result.Context.Node.Desc = ctnSpecialize)) then
    Result:=Result.Context.Tool.ConvertNodeToExpressionType(
                 Result.Context.Node,Params);
  {$IFDEF ShowExprEval}
  DebugLn('  FindExpressionTypeOfTerm Result=',ExprTypeToString(Result));
  {$ENDIF}
end;

function TFindDeclarationTool.FindEndOfExpression(StartPos: integer): integer;
var
  First: Integer;
begin
  MoveCursorToCleanPos(StartPos);
  Result:=CurPos.StartPos;
  First:=0;
  repeat
    ReadNextAtom;
    if First=0 then begin
      First:=CurPos.StartPos;
      if UpAtomIs('INHERITED') then begin
        Result:=CurPos.EndPos;
        ReadNextAtom;
      end;
    end;
    // read till statement end
    if (CurPos.StartPos>SrcLen)
    or (CurPos.Flag in [cafSemicolon,cafComma,cafEnd,
                        cafRoundBracketClose,cafEdgedBracketClose])
    or (AtomIsKeyWord
      and not IsKeyWordInConstAllowed.DoItCaseInsensitive(Src,
                                 CurPos.StartPos,CurPos.EndPos-CurPos.StartPos))
    then begin
      break;
    end
    else if CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen] then begin
      ReadTilBracketClose(true);
    end;
    Result:=CurPos.EndPos;
  until false;
end;

function TFindDeclarationTool.ConvertNodeToExpressionType(Node: TCodeTreeNode;
  Params: TFindDeclarationParams; AliasType: PFindContext): TExpressionType;
  
  procedure ConvertIdentifierAtCursor(Tool: TFindDeclarationTool);
  begin
    if WordIsPredefinedIdentifier.DoItCaseInsensitive(Tool.Src,Tool.CurPos.StartPos,
      Tool.CurPos.EndPos-Tool.CurPos.StartPos) then
    begin
      // predefined identifiers
      ConvertNodeToExpressionType:=Tool.FindExpressionTypeOfPredefinedIdentifier(
                                                    Tool.CurPos.StartPos,Params);
    end;
  end;
  
var
  BaseContext: TFindContext;
  OldInput: TFindDeclarationInput;
  Tool: TFindDeclarationTool;
  CurAliasType: PFindContext;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  {$IFDEF ShowExprEval}
  DebugLn(['[TFindDeclarationTool.ConvertNodeToExpressionType] A',
  ' Node=',Node.DescAsString,' "',dbgstr(copy(ExtractNode(Node,[]),1,30)),'" Flags=[',dbgs(Params.Flags),'] Alias=',AliasType<>nil]);
  {$ENDIF}
  BaseContext:=FindBaseTypeOfNode(Params,Node,AliasType);
  Node:=BaseContext.Node;
  Tool:=BaseContext.Tool;
  Result:=CleanExpressionType;
  Result.Desc:=xtContext;
  Result.Context:=BaseContext;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.ConvertNodeToExpressionType] B',
  ' Expr=',ExprTypeToString(Result),' Alias=',FindContextToString(AliasType));
  {$ENDIF}
  if (AliasType<>nil) and (AliasType^.Node=nil) then
    CurAliasType:=AliasType
  else
    CurAliasType:=nil;
  case Node.Desc of
  ctnRangeType:
    begin
      // range type -> convert to special expression type
      // for example: type c = 1..3;

      // ToDo: ppu, dcu files

      Tool.MoveCursorToNodeStart(Node);

      // ToDo: check for cycles

      Params.Save(OldInput);
      Params.ContextNode:=Node;
      Result:=Tool.ReadOperandTypeAtCursor(Params,-1,CurAliasType);
      Params.Load(OldInput,true);
      Result.Context:=CreateFindContext(Tool,Node);
    end;
    
  ctnConstDefinition:
    begin
      // const -> convert to special expression type
      // for example: const a: integer = 3;

      // ToDo: ppu, dcu files

      Tool.MoveCursorToNodeStart(Node);

      Tool.ReadNextAtom;
      if not Tool.AtomIsIdentifier then exit;
      Tool.ReadNextAtom;
      if not (CurPos.Flag in [cafEqual,cafColon]) then exit;
      Tool.ReadNextAtom;

      // ToDo: check for cycles

      Params.Save(OldInput);
      Params.ContextNode:=Node;
      Result:=Tool.ReadOperandTypeAtCursor(Params,-1,CurAliasType);
      Params.Load(OldInput,true);
      Result.Context:=CreateFindContext(Tool,Node);
    end;
    
  ctnIdentifier:
    begin

      // ToDo: ppu, dcu files

      Tool.MoveCursorToNodeStart(Node);
      Tool.ReadNextAtom;
      ConvertIdentifierAtCursor(Tool);
    end;
    
  ctnProperty,ctnGlobalProperty:
    begin

      // ToDo: ppu, dcu files

      if Tool.MoveCursorToPropType(Node) then
        ConvertIdentifierAtCursor(Tool);
    end;
    
  ctnConstant:
    begin
      // for example: const a = 3;

      // ToDo: ppu, dcu files

      Tool.MoveCursorToNodeStart(Node);
      Params.Save(OldInput);
      Params.ContextNode:=Node;
      Result:=Tool.ReadOperandTypeAtCursor(Params,-1,CurAliasType);
      Params.Load(OldInput,true);
      Result.Context:=CreateFindContext(Tool,Node);
    end;
  end;

  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.ConvertNodeToExpressionType] END',
  ' Expr=',ExprTypeToString(Result),' Alias=',FindContextToString(AliasType));
  {$ENDIF}
end;

function TFindDeclarationTool.ReadOperandTypeAtCursor(
  Params: TFindDeclarationParams; MaxEndPos: integer; AliasType: PFindContext
  ): TExpressionType;
{ internally used by FindExpressionResultType
  after reading, the cursor will be on the next atom
}
var EndPos, SubStartPos: integer;

  procedure ReadEdgedBracketOperand;
  
    procedure RaiseConstExpected;
    begin
      RaiseExceptionFmt(20170421200607,ctsStrExpectedButAtomFound,[ctsConstant,GetAtom]);
    end;
  
  begin
    // 'set' constant
    SubStartPos:=CurPos.StartPos;
    ReadNextAtom;
    if not AtomIsChar(']') then begin
      Result:=ReadOperandTypeAtCursor(Params);
      {$IFDEF ShowExprEval}
      DebugLn('[TFindDeclarationTool.ReadOperandTypeAtCursor] Set of ',
      ExpressionTypeDescNames[Result.Desc]);
      if Result.Desc=xtContext then
        DebugLn('  Result.Context.Node=',Result.Context.Node.DescAsString);
      {$ENDIF}
    end else begin
      // empty set '[]'
      Result.Desc:=xtNone;
    end;
    Result.SubDesc:=Result.Desc;
    Result.Desc:=xtConstSet;
    MoveCursorToCleanPos(SubStartPos);
    ReadNextAtom;
    ReadTilBracketClose(true);
    MoveCursorToCleanPos(CurPos.EndPos);
  end;
  
  procedure RaiseIdentExpected;
  begin
    RaiseExceptionFmt(20170421200609,ctsStrExpectedButAtomFound,[ctsIdentifier,GetAtom]);
  end;

var
  OldFlags: TFindDeclarationFlags;
begin
  Result:=CleanExpressionType;
  if AliasType<>nil then
    AliasType^:=CleanFindContext;

  if CurPos.StartPos=CurPos.EndPos then ReadNextAtom;
  // read unary operators which have no effect on the type: +, -, not
  while AtomIsChar('+') or AtomIsChar('-') or UpAtomIs('NOT') do
    ReadNextAtom;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.ReadOperandTypeAtCursor] A Atom=',GetAtom);
  debugln(['TFindDeclarationTool.ReadOperandTypeAtCursor StartContext=',Params.ContextNode.DescAsString,'="',dbgstr(Src,Params.ContextNode.StartPos,15),'"']);
  {$ENDIF}
  if (AtomIsIdentifier)
  or (CurPos.Flag=cafRoundBracketOpen)
  or UpAtomIs('INHERITED')
  or UpAtomIs('ARRAY')
  then begin
    // read variable
    SubStartPos:=CurPos.StartPos;
    EndPos:=FindEndOfTerm(SubStartPos,false,true);
    if EndPos>MaxEndPos then
      EndPos:=MaxEndPos;
    OldFlags:=Params.Flags;
    Params.Flags:=(Params.Flags*fdfGlobals)+[fdfFunctionResult];
    Result:=FindExpressionTypeOfTerm(SubStartPos,EndPos,Params,true,AliasType);
    Params.Flags:=OldFlags;
    MoveCursorToCleanPos(EndPos);
  end
  else if UpAtomIs('NIL') then begin
    Result.Desc:=xtNil;
    ReadNextAtom;
  end
  else if AtomIsChar('[') then begin
    ReadEdgedBracketOperand;
  end
  else if AtomIsStringConstant then begin
    // string or char constant
    if AtomIsCharConstant then
      Result.Desc:=xtChar
    else
      Result.Desc:=xtConstString;
    MoveCursorToCleanPos(CurPos.StartPos);
    ReadAsStringConstant;
  end
  else if AtomIsNumber then begin
    // ordinal or real constant
    if AtomIsRealNumber then
      Result.Desc:=xtConstReal
    else
      Result.Desc:=xtConstOrdInteger;
    MoveCursorToCleanPos(CurPos.EndPos);
  end
  else if AtomIsChar('@') then begin
    // a simple pointer or a PChar or an event
    ReadNextAtom;
    if CurPos.Flag=cafWord then begin
      SubStartPos:=CurPos.StartPos;
      EndPos:=FindEndOfTerm(SubStartPos,false,true);
      if EndPos>MaxEndPos then
        EndPos:=MaxEndPos;
      OldFlags:=Params.Flags;
      Params.Flags:=(Params.Flags*fdfGlobals)-[fdfFunctionResult];
      Result:=FindExpressionTypeOfTerm(SubStartPos,EndPos,Params,true,AliasType);
      Params.Flags:=OldFlags;
      MoveCursorToCleanPos(EndPos);
    end else begin
      MoveCursorToCleanPos(CurPos.StartPos);
      Result:=ReadOperandTypeAtCursor(Params);
    end;
    if (Result.Desc=xtContext)
    or ((Result.Context.Node<>nil) and (Result.Context.Node.Desc=ctnProcedure))
    then begin
      Result.SubDesc:=Result.Desc;
      Result.Desc:=xtPointer;
    end else if (Result.Desc=xtChar) then begin
      Result.SubDesc:=xtNone;
      Result.Desc:=xtPChar
    end else begin
      Result.SubDesc:=xtNone;
      Result.Context:=CleanFindContext;
      Result.Desc:=xtPointer;
    end;
  end
  else
    RaiseIdentExpected;

  {$IFDEF ShowExprEval}
  DbgOut('[TFindDeclarationTool.ReadOperandTypeAtCursor] END ',
  ExpressionTypeDescNames[Result.Desc]);
  if Result.Context.Node<>nil then
    DbgOut(' Context.Node=',Result.Context.Node.DescAsString)
  else
    DbgOut(' Context.Node=nil');
  if AliasType<>nil then
    DbgOut(' Alias=',FindContextToString(AliasType));
  DebugLn('');
  {$ENDIF}
end;

function TFindDeclarationTool.FindExpressionTypeOfPredefinedIdentifier(
  StartPos: integer; Params: TFindDeclarationParams; AliasType: PFindContext
  ): TExpressionType;
var
  IdentPos: PChar;
  ParamList: TExprTypeList;
  ParamNode: TCodeTreeNode;
  SubParams: TFindDeclarationParams;
  NewTool: TFindDeclarationTool;
begin
  Result:=CleanExpressionType;
  IdentPos:=@Src[StartPos];
  Result.Desc:=PredefinedIdentToExprTypeDesc(IdentPos,Scanner.PascalCompiler);

  {$IFDEF ShowExprEval}
  debugln('TFindDeclarationTool.FindExpressionTypeOfPredefinedIdentifier "',GetIdentifier(IdentPos),'" ',
    ExpressionTypeDescNames[Result.Desc]);
  if Result.desc=xtNone then begin
    //CTDumpStack;
    //IsWordBuiltInFunc.WriteDebugListing;
  end;
  {$ENDIF}
  ParamList:=nil;
  try
    case Result.Desc of
    xtCompilerFunc:
      begin
        if not (Params.ContextNode.Desc in (AllPascalStatements+[ctnConstant])) then begin
          {$IFDEF ShowExprEval}
          debugln(['TFindDeclarationTool.FindExpressionTypeOfPredefinedIdentifier Skipping non expr parent ContextNode=',Params.ContextNode.DescAsString]);
          {$ENDIF}
          exit;
        end;
        MoveCursorToCleanPos(StartPos);
        ReadNextAtom;
        ReadNextAtom;
        if not AtomIsChar('(') then
          exit;
        ParamList:=CreateParamExprListFromStatement(CurPos.StartPos,Params,true);
        if (CompareIdentifiers(IdentPos,'PRED')=0)
        or (CompareIdentifiers(IdentPos,'SUCC')=0)
        or (CompareIdentifiers(IdentPos,'DEFAULT')=0)
        then begin
          // the DEFAULT, PRED and SUCC of a expression has the same type as the expression
          if ParamList.Count<>1 then exit;
          Result:=ParamList.Items[0];
          if AliasType<>nil then
            AliasType^:=ParamList.AliasTypes[0];
          //debugln(['TFindDeclarationTool.FindExpressionTypeOfPredefinedIdentifier ',ExprTypeToString(Result)]);
        end
        else if (CompareIdentifiers(IdentPos,'LOW')=0)
             or (CompareIdentifiers(IdentPos,'HIGH')=0) then
        begin
          {$IFDEF ShowExprEval}
          debugln('TFindDeclarationTool.FindExpressionTypeOfPredefinedIdentifier Ident=',GetIdentifier(IdentPos));
          {$ENDIF}
          { examples:
             Low(ordinal type)  is the ordinal type
             Low(array)         has type of the array items
             Low(set)           has type of the enums
          }
          if ParamList.Count<>1 then exit;
          Result:=ParamList.Items[0];
          if Result.Desc<>xtContext then exit;
          ParamNode:=Result.Context.Node;
          case ParamNode.Desc of

          ctnEnumerationType:
            // Low(enum)   has the type of the enum
            if (ParamNode.Parent<>nil)
            and (ParamNode.Parent.Desc=ctnTypeDefinition) then
              Result.Context.Node:=ParamNode.Parent;

          ctnOpenArrayType:
            // array without explicit range -> open array
            // Low(Open array) is ordinal integer
            begin
              Result.Desc:=xtConstOrdInteger;
              Result.Context:=CleanFindContext;
            end;

          ctnRangedArrayType:
            begin
              // array with explicit range
              // Low(array[SubRange])  has the type of the subrange
              Result.Context.Tool.MoveCursorToNodeStart(ParamNode.FirstChild);
              SubParams:=TFindDeclarationParams.Create(Params);
              try
                SubParams.Flags:=fdfDefaultForExpressions;
                SubParams.ContextNode:=ParamNode;
                Result:=Result.Context.Tool.ReadOperandTypeAtCursor(SubParams);
              finally
                SubParams.Free;
              end;
            end;

          else
            DebugLn('NOTE: unimplemented Low(type) type=',ParamNode.DescAsString);
          end;
        end
        else if (CompareIdentifiers(IdentPos,'LENGTH')=0) then
        begin
          if ParamList.Count<>1 then exit;
          Result.Desc:=xtSizeInt;
        end
        else if (CompareIdentifiers(IdentPos,'COPY')=0) then
        begin
          if (ParamList.Count<1) or (ParamList.Count>3) or (Scanner.Values.IsDefined('VER1_0')) then
            exit;
          Result:=ParamList.Items[0]; // Copy sets the result based on the first
            // parameter (can be any kind of string or array)
        end
        else if (CompareIdentifiers(IdentPos,'GET_FRAME')=0) then
        begin
          if ParamList.Count<>1 then exit;
          Result.Desc:=xtPointer;
        end
        else if (CompareIdentifiers(IdentPos,'OBJCSELECTOR')=0) then
        begin
          // return type is System.SEL
          NewTool:=FindCodeToolForUsedUnit('system','',true);
          if NewTool=nil then exit;
          SubParams:=TFindDeclarationParams.Create(Params);
          try
            SubParams.Identifier:='SEL'#0;
            if (not NewTool.FindIdentifierInInterface(Self,SubParams))
            or (SubParams.NewNode=nil) then exit;
            Result.Desc:=xtContext;
            Result.Context.Node:=SubParams.NewNode;
            Result.Context.Tool:=SubParams.NewCodeTool;
          finally
            SubParams.Free;
          end;
        end;
      end;

    xtString:
      Result.Desc:=GetDefaultStringType;
    end;
  finally
    ParamList.Free;
  end;
end;

function TFindDeclarationTool.FindExpressionTypeOfConstSet(Node: TCodeTreeNode
  ): TExpressionType;
var
  AliasType: TFindContext;
  Params: TFindDeclarationParams;
begin
  Result:=CleanExpressionType;
  if Node=nil then
    RaiseException(20170421212058,'TFindDeclarationTool.FindExpressionTypeOfConstSet Node=nil');
  {$IFDEF CheckNodeTool}
  CheckNodeTool(Node);
  {$ENDIF}
  MoveCursorToNodeStart(Node);
  ReadNextAtom;
  if CurPos.Flag<>cafEdgedBracketOpen then
    RaiseStringExpectedButAtomFound(20170421212227,'[');
  ReadNextAtom;
  Params:=TFindDeclarationParams.Create(Self,Node);
  try
    Params.Flags:=fdfDefaultForExpressions+[fdfFunctionResult];
    AliasType:=CleanFindContext;
    Result:=FindExpressionTypeOfTerm(CurPos.StartPos,-1,Params,false,@AliasType);
    //debugln(['TFindDeclarationTool.FindExpressionTypeOfConstSet ',ExprTypeToString(Result)]);
  finally
    Params.Free;
  end;
end;

function TFindDeclarationTool.GetDefaultStringType: TExpressionTypeDesc;
begin
  if cmsDefault_unicodestring in Scanner.CompilerModeSwitches then
    Result:=xtUnicodeString
  else if (Scanner.PascalCompiler=pcDelphi)
  or ((Scanner.CompilerMode=cmDELPHI)
  or (Scanner.Values['LONGSTRINGS']='1')) then
    Result:=xtAnsiString
  else
    Result:=xtString;
end;

function TFindDeclarationTool.CalculateBinaryOperator(LeftOperand,
  RightOperand: TOperand; BinaryOperator: TAtomPosition;
  Params: TFindDeclarationParams): TOperand;
begin
  Result.Expr:=CleanExpressionType;
  Result.AliasType:=CleanFindContext;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.CalculateBinaryOperator] A',
  ' LeftOperand=',ExprTypeToString(LeftOperand.Expr),
  ' Operator=',GetAtom(BinaryOperator),
  ' RightOperand=',ExprTypeToString(RightOperand.Expr)
  );
  {$ENDIF}
  // convert Left and RightOperand contexts to expressiontype
  if LeftOperand.Expr.Desc=xtContext then begin
    LeftOperand.Expr:=LeftOperand.Expr.Context.Tool.ConvertNodeToExpressionType(
                      LeftOperand.Expr.Context.Node,Params);
  end;
  if RightOperand.Expr.Desc=xtContext then begin
    RightOperand.Expr:=RightOperand.Expr.Context.Tool.ConvertNodeToExpressionType(
                      RightOperand.Expr.Context.Node,Params);
  end;


  // ToDo: search for an overloaded operator

  if WordIsBooleanOperator.DoItCaseInsensitive(Src,BinaryOperator.StartPos,
    BinaryOperator.EndPos-BinaryOperator.StartPos)
  then begin
    // Boolean operators
    // < > <= >= <> in is
    Result.Expr.Desc:=xtBoolean;
  end
  else if (BinaryOperator.EndPos-BinaryOperator.StartPos=1)
  and (Src[BinaryOperator.StartPos]='/') then begin
    // real division /
    Result:=RealTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos);
    if not(Result.Expr.Desc in xtAllRealTypes) then
    begin
      Result.Expr.Desc:=xtConstReal;
      Result.AliasType:=CleanFindContext;
    end;
  end
  else if WordIsOrdNumberOperator.DoItCaseInsensitive(Src,BinaryOperator.StartPos,
    BinaryOperator.EndPos-BinaryOperator.StartPos)
  then begin
    // ordinal number operator
    // or xor and mod div shl shr
    if LeftOperand.Expr.Desc in xtAllBooleanTypes then
      Result:=BooleanTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos)
    else
      Result:=IntegerTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos);
  end
  else if WordIsNumberOperator.DoItCaseInsensitive(Src,BinaryOperator.StartPos,
    BinaryOperator.EndPos-BinaryOperator.StartPos)
  then begin
    // number operator (or string concatenating or set cut)
    // + - *

    if (Src[BinaryOperator.StartPos]='+')
    and (LeftOperand.Expr.Desc in xtAllStringCompatibleTypes)
    then begin
      // string/char '+'
      if (RightOperand.Expr.Desc in xtAllStringCompatibleTypes)
      then
      begin
        Result:=StringTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos);
        if not(Result.Expr.Desc in xtAllStringTypes) then
        begin
          Result.Expr.Desc:=xtConstString;
          Result.AliasType:=CleanFindContext;
        end;
      end else begin
        MoveCursorToCleanPos(BinaryOperator.EndPos);
        ReadNextAtom;
        RaiseExceptionFmt(20170421200612,ctsIncompatibleTypesGotExpected,
                          ['char',ExpressionTypeDescNames[RightOperand.Expr.Desc]]);
      end;
    end else if (Src[BinaryOperator.StartPos] in ['+','-','*'])
    and (LeftOperand.Expr.Desc=xtContext)
    and (LeftOperand.Expr.Context.Node<>nil)
    and (LeftOperand.Expr.Context.Node.Desc=ctnSetType)
    then begin
      Result:=LeftOperand;
    end else begin
      if (LeftOperand.Expr.Desc in xtAllRealTypes)
      or (RightOperand.Expr.Desc in xtAllRealTypes) then
        Result:=RealTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos)
      else if (LeftOperand.Expr.Desc=xtPointer)
      or (RightOperand.Expr.Desc=xtPointer)
      or ((LeftOperand.Expr.Desc=xtContext)
        and (LeftOperand.Expr.Context.Node.Desc=ctnPointerType))
      or ((RightOperand.Expr.Desc=xtContext)
        and (RightOperand.Expr.Context.Node.Desc=ctnPointerType))
      then
        Result.Expr.Desc:=xtPointer
      else
        Result:=IntegerTypesOrderList.Compare(LeftOperand, RightOperand, Self, BinaryOperator.EndPos);
    end;
  end else begin
    // ???
    {$IFDEF ShowExprEval}
    debugln(['TFindDeclarationTool.CalculateBinaryOperator unknown operator: ',GetAtom(BinaryOperator)]);
    {$ENDIF}
    Result:=RightOperand;
  end;
end;

function TFindDeclarationTool.IsParamExprListCompatibleToNodeList(
  FirstTargetParameterNode: TCodeTreeNode;
  SourceExprParamList: TExprTypeList;  IgnoreMissingParameters: boolean;
  Params: TFindDeclarationParams;
  CompatibilityList: TTypeCompatibilityList): TTypeCompatibility;
// tests if SourceExprParamList fits into the TargetFirstParameterNode
var
  ParamNode: TCodeTreeNode;
  i, MinParamCnt, MaxParamCnt: integer;
  ParamCompatibility: TTypeCompatibility;
  CompatibilityListCount: LongInt;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(FirstTargetParameterNode);{$ENDIF}
  // quick check: parameter count
  ParamNode:=FirstTargetParameterNode;
  MinParamCnt:=0;
  while (ParamNode<>nil)
  and ((ParamNode.SubDesc and ctnsHasDefaultValue)=0) do begin
    ParamNode:=ParamNode.NextBrother;
    inc(MinParamCnt);
  end;
  MaxParamCnt:=MinParamCnt;
  while (ParamNode<>nil) do begin
    ParamNode:=ParamNode.NextBrother;
    inc(MaxParamCnt);
  end;

  {$IF defined(ShowExprEval) or defined(ShowProcSearch)}
  DebugLn('[TFindDeclarationTool.IsParamExprListCompatibleToNodeList] ',
  ' ExprParamList.Count=',dbgs(SourceExprParamList.Count),
  ' MinParamCnt=',dbgs(MinParamCnt),' MaxParamCnt=',dbgs(MaxParamCnt)
  );
    try
  {$ENDIF}
  Result:=tcExact;

  if (SourceExprParamlist.Count>MaxParamCnt)
  or ((not IgnoreMissingParameters) and (SourceExprParamList.Count<MinParamCnt))
  then begin
    Result:=tcIncompatible;
    exit;
  end;

  // check each parameter for compatibility
  ParamNode:=FirstTargetParameterNode;
  i:=0;
  CompatibilityListCount:=SourceExprParamList.Count;
  while (ParamNode<>nil) and (i<CompatibilityListCount) do begin
    ParamCompatibility:=IsCompatible(ParamNode,SourceExprParamList.Items[i],
                                     Params);
    {$IF defined(ShowExprEval) or defined(ShowProcSearch)}
    DebugLn(['[TFindDeclarationTool.IsParamExprListCompatibleToNodeList] SourceParam=',ExprTypeToString(SourceExprParamList.Items[i]),' TargetParam=',ExtractNode(ParamNode,[]),' ',TypeCompatibilityNames[ParamCompatibility]]);
    {$ENDIF}
    if CompatibilityList<>nil then
      CompatibilityList[i]:=ParamCompatibility;
    if (ParamCompatibility=tcIncompatible)
    or ((ParamCompatibility=tcCompatible)
        and MoveCursorToParameterSpecifier(ParamNode)
        and (UpAtomIs('VAR') or UpAtomIs('CONSTREF')
             or (UpAtomIs('OUT') and (cmsOut in Scanner.CompilerModeSwitches))))
    then begin
      Result:=tcIncompatible;
      exit;
    end;
    if ParamCompatibility=tcCompatible then
      Result:=tcCompatible;
    ParamNode:=ParamNode.NextBrother;
    inc(i);
  end;
  if (i<SourceExprParamList.Count) then begin
    // there are more expressions, then the param list has variables
    Result:=tcIncompatible;
  end else if (ParamNode<>nil) then begin
    // there are not enough expressions for the param list
    // -> check if missing variables have default variables
    if (ParamNode.SubDesc and ctnsHasDefaultValue)>0 then begin
      // the rest params have default values
      if CompatibilityList<>nil then begin
        while (ParamNode<>nil) and (i<CompatibilityListCount) do begin
          CompatibilityList[i]:=tcExact;
          ParamNode:=ParamNode.NextBrother;
          inc(i);
        end;
      end;
    end else if not IgnoreMissingParameters then begin
      // not enough expression for param list
      // -> incompatible
      Result:=tcIncompatible;
    end;
  end;
  {$IF defined(ShowExprEval) or defined(ShowProcSearch)}
    finally
      DebugLn('[TFindDeclarationTool.IsParamExprListCompatibleToNodeList] END ',
      ' Result=',TypeCompatibilityNames[Result],' ! ONLY VALID if no error !'
      );
    end;
  {$ENDIF}
end;

function TFindDeclarationTool.IsParamNodeListCompatibleToExprList(
  TargetExprParamList: TExprTypeList; FirstSourceParameterNode: TCodeTreeNode;
  Params: TFindDeclarationParams;
  CompatibilityList: TTypeCompatibilityList): TTypeCompatibility;
// tests if FirstSourceParameterNode fits (i.e. can be assigned) into
// the TargetExprParamList
var
  ParamNode: TCodeTreeNode;
  i, MinParamCnt, MaxParamCnt: integer;
  ParamCompatibility: TTypeCompatibility;
  SourceExprType: TExpressionType;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(FirstSourceParameterNode);{$ENDIF}

  // quick check: parameter count
  MinParamCnt:=0;
  ParamNode:=FirstSourceParameterNode;
  while (ParamNode<>nil) do begin
    ParamNode:=ParamNode.NextBrother;
    inc(MinParamCnt);
  end;
  MaxParamCnt:=MinParamCnt;

  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsParamNodeListCompatibleToExprList] ',
  ' ExprParamList.Count=',dbgs(TargetExprParamList.Count),' ',
  ' MinParamCnt=',dbgs(MinParamCnt),' MaxParamCnt=',dbgs(MaxParamCnt)
  );
    try
  {$ENDIF}
  Result:=tcExact;

  if (TargetExprParamList.Count<>MaxParamCnt) then begin
    Result:=tcIncompatible;
    exit;
  end;

  // check each parameter for compatibility
  
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsParamNodeListCompatibleToExprList] ',
    ' ExprParamList=[',TargetExprParamList.AsString,']');
  {$ENDIF}
  ParamNode:=FirstSourceParameterNode;
  i:=0;
  while (ParamNode<>nil) and (i<TargetExprParamList.Count) do begin
    SourceExprType:=ConvertNodeToExpressionType(ParamNode,Params);
    ParamCompatibility:=IsCompatible(TargetExprParamList.Items[i],
                                     SourceExprType,Params);
    {$IFDEF ShowExprEval}
    DebugLn(['[TFindDeclarationTool.IsParamNodeListCompatibleToExprList] B ',i,' Source=[',ExprTypeToString(SourceExprType),'] Target=[',ExprTypeToString(TargetExprParamList.Items[i]),'] Result=',TypeCompatibilityNames[ParamCompatibility]]);
    {$ENDIF}
    if CompatibilityList<>nil then
      CompatibilityList[i]:=ParamCompatibility;
    if ParamCompatibility=tcIncompatible then begin
      Result:=tcIncompatible;
      exit;
    end else if ParamCompatibility=tcCompatible then begin
      Result:=tcCompatible;
    end;
    ParamNode:=ParamNode.NextBrother;
    inc(i);
  end;
  if (ParamNode<>nil) or (i<TargetExprParamList.Count) then
    RaiseException(20170421200618,'Internal Error: one param list has changed');
    
  {$IFDEF ShowExprEval}
    finally
      DebugLn('[TFindDeclarationTool.IsParamNodeListCompatibleToExprList] END ',
      ' Result=',TypeCompatibilityNames[Result],' ! ONLY VALID if no error !'
      );
    end;
  {$ENDIF}
end;

function TFindDeclarationTool.IsParamNodeListCompatibleToParamNodeList(
  FirstTargetParameterNode, FirstSourceParameterNode: TCodeTreeNode;
  Params: TFindDeclarationParams;
  CompatibilityList: TTypeCompatibilityList): TTypeCompatibility;
var
  CurParamNode1, CurParamNode2: TCodeTreeNode;
  ParamCompatibility: TTypeCompatibility;
  SourceExprType, TargetExprType: TExpressionType;
  OldFlags: TFindDeclarationFlags;
  i: integer;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(FirstTargetParameterNode);{$ENDIF}
  // quick check: parameter count
  CurParamNode1:=FirstTargetParameterNode;
  CurParamNode2:=FirstSourceParameterNode;
  while (CurParamNode1<>nil) and (CurParamNode2<>nil) do begin
    CurParamNode1:=CurParamNode1.NextBrother;
    CurParamNode2:=CurParamNode2.NextBrother;
  end;
  if (CurParamNode1<>nil) or (CurParamNode2<>nil) then begin
    Result:=tcIncompatible;
    exit;
  end;
  
  // check each parameter
  OldFlags:=Params.Flags;
  Params.Flags:=Params.Flags-[fdfFindVariable]+[fdfIgnoreOverloadedProcs];
  CurParamNode1:=FirstTargetParameterNode;
  CurParamNode2:=FirstSourceParameterNode;
  Result:=tcExact;
  i:=0;
  while (CurParamNode1<>nil) and (CurParamNode2<>nil) do begin
    TargetExprType:=ConvertNodeToExpressionType(CurParamNode1,Params);
    SourceExprType:=ConvertNodeToExpressionType(CurParamNode2,Params);
    ParamCompatibility:=IsBaseCompatible(TargetExprType,SourceExprType,Params);
    if CompatibilityList<>nil then
      CompatibilityList[i]:=ParamCompatibility;
    if ParamCompatibility=tcIncompatible then begin
      Result:=tcIncompatible;
      exit;
    end else if ParamCompatibility=tcCompatible then begin
      Result:=tcCompatible;
    end;
    CurParamNode1:=CurParamNode1.NextBrother;
    CurParamNode2:=CurParamNode2.NextBrother;
    inc(i);
  end;
  Params.Flags:=OldFlags;
end;

function TFindDeclarationTool.GetParameterNode(Node: TCodeTreeNode
  ): TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=Node;
  if Result=nil then exit;
  if Result.Desc=ctnReferenceTo then begin
    Result:=Result.FirstChild;
    if Result=nil then exit;
  end;
  if (Result.Desc in [ctnProperty,ctnGlobalProperty]) then
    Result:=Result.FirstChild
  else if Result.Desc in [ctnProcedure,ctnProcedureHead,ctnProcedureType] then begin
    BuildSubTreeForProcHead(Result);
    if Result.Desc in [ctnProcedure,ctnProcedureType] then
      Result:=Result.FirstChild;
    if Result.Desc=ctnProcedureHead then
      Result:=Result.FirstChild;
  end;
end;

function TFindDeclarationTool.GetFirstParameterNode(Node: TCodeTreeNode
  ): TCodeTreeNode;
begin
  Result:=GetParameterNode(Node);
  if Result<>nil then Result:=Result.FirstChild;
end;

function TFindDeclarationTool.CheckSrcIdentifier(
  Params: TFindDeclarationParams;
  const FoundContext: TFindContext): TIdentifierFoundResult;
// this is a TOnIdentifierFound function
//   if identifier found is a proc then it searches for the best overloaded proc

  function CallHasEmptyParamsAndFoundProcFits: boolean;
  var
    FirstParameterNode: TCodeTreeNode;
    TargetTool: TFindDeclarationTool;
  begin
    Result:=false;
    FirstParameterNode:=FoundContext.Tool.GetFirstParameterNode(
                                              FoundContext.Node);
    if (FirstParameterNode<>nil)
    and ((FirstParameterNode.SubDesc and ctnsHasDefaultValue)=0) then begin
      // found proc needs at least one parameter
      exit;
    end;
    // FoundContext is a proc with no or only default params
    TargetTool:=Params.IdentifierTool;
    TargetTool.MoveCursorToCleanPos(Params.Identifier);
    TargetTool.ReadNextAtom; // read identifier
    TargetTool.ReadNextAtom; // read bracket
    if TargetTool.CurPos.Flag<>cafRoundBracketOpen then exit;
    TargetTool.ReadNextAtom; // read bracket close
    if TargetTool.CurPos.Flag<>cafRoundBracketClose then exit;
    Result:=true;
  end;

var
  FirstParameterNode, StartContextNode: TCodeTreeNode;
  ParamCompatibility: TTypeCompatibility;
  OldInput: TFindDeclarationInput;
  CurCompatibilityList: TTypeCompatibilityList;
  CompListSize: integer;
  NewExprInputList: TExprTypeList;
begin
  // the search has found an identifier with the right name
  {$IFDEF ShowFoundIdentifier}
  DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
  ' Ident=',GetIdentifier(Params.Identifier),
  ' FoundContext=',FoundContext.Node.DescAsString,
  ' Flags=[',dbgs(Params.Flags),']'
  );
  {$ENDIF}
  if FoundContext.Node.Desc=ctnProcedure then begin
    // the found node is a proc
    
    // 1. the current identifier cache is blind for parameter lists
    // => proc identifiers can not be identified by the name alone
    // -> do not cache
    // 2. Even if there is only one proc. With different search flags,
    //    different routes will be searched and then there can be another proc.
    //    The only solution is to store the param expression list and all flags
    //    in the cache. This is a ToDo
    Include(Params.Flags,fdfDoNotCache);
    Include(Params.NewFlags,fodDoNotCache);

    if (fdfIgnoreOverloadedProcs in Params.Flags) then begin
      // do not check for overloaded procs -> ident found
      Result:=ifrSuccess;
      exit;
    end;
    
    // Procs can be overloaded, that means there can be several procs with the
    // same name, but with different param lists.
    // The search must go on, and the most compatible proc is returned.
    
    if not Params.IdentifierTool.IsPCharInSrc(Params.Identifier) then begin
      // Params.Identifier is not in the source of the start tool
      // => impossible to check param list, because the context is unknown
      // -> identifier found
      {$IFDEF ShowProcSearch}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' NO SOURCE to check params'
      );
      {$ENDIF}
      Result:=ifrSuccess;
      exit;
    end;

    if FoundContext.Tool.NodeIsClassConstructorOrDestructor(FoundContext.Node) then
    begin
      Result:=ifrProceedSearch;
      Exit;
    end;

    if (not (fdfCollect in Params.Flags))
    and CallHasEmptyParamsAndFoundProcFits then begin
      // call has brackets without params (e.g. writeln() )
      // and found proc fits exactly
      // => stop search
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      debugln(['TFindDeclarationTool.CheckSrcIdentifier call is () and found proc fits exactly',
        ' Ident=',GetIdentifier(Params.Identifier),
        ' ',FoundContext.Tool.CleanPosToStr(FoundContext.Node.StartPos)
        ]);
      {$ENDIF}
      Params.SetResult(FoundContext);
      Result:=ifrSuccess;
      exit;
    end;
    
    Result:=ifrProceedSearch;
    if (Params.FoundProc=nil) then begin
      // this is the first proc found
      // -> save it and proceed the search to find all overloadeded procs
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' ',FoundContext.Tool.CleanPosToStr(FoundContext.Node.StartPos),
      ' FIRST PROC searching for overloads ...'
      );
      {$ENDIF}
      Params.SetFoundProc(FoundContext);
      exit;
    end;
    
    // -> check which one is more compatible
    // create the input expression list
    // (the expressions in the brackets are parsed and converted to types)
    if Params.FoundProc^.ExprInputList=nil then begin
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' Creating Input Expression List ...'
      );
      {$ENDIF}
      if Params.IdentifierTool.IsPCharInSrc(Params.Identifier) then begin
        Params.IdentifierTool.MoveCursorToCleanPos(Params.Identifier);
        StartContextNode:=Params.IdentifierTool.FindDeepestNodeAtPos(
          Params.IdentifierTool.CurPos.StartPos,true);
        if (StartContextNode<>nil) then begin
          if (StartContextNode.Desc in AllPascalStatements) then begin
            {$IFDEF ShowProcSearch}
            DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
            ' Ident=',GetIdentifier(Params.Identifier),
            ' Creating Input Expression List for statement ...'
            );
            {$ENDIF}
            Params.Save(OldInput);
            Params.IdentifierTool.MoveCursorToCleanPos(Params.Identifier);
            Params.Flags:=fdfDefaultForExpressions+Params.Flags*fdfGlobals;
            Params.ContextNode:=StartContextNode;
            Params.OnIdentifierFound:=@Params.IdentifierTool.CheckSrcIdentifier;
            Params.IdentifierTool.ReadNextAtom;
            NewExprInputList:=
              Params.IdentifierTool.CreateParamExprListFromStatement(
                                    Params.IdentifierTool.CurPos.EndPos,Params);
            {$IFDEF ShowProcSearch}
            debugln(['TFindDeclarationTool.CheckSrcIdentifier Params: ',NewExprInputList.AsString]);
            {$ENDIF}
            Params.Load(OldInput,true);
            FreeAndNil(Params.FoundProc^.ExprInputList);
            Params.FoundProc^.ExprInputList:=NewExprInputList;
          end
          else if (StartContextNode.Desc in [ctnProcedureHead,ctnProcedure])
          then begin
            {$IFDEF ShowProcSearch}
            DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
            ' Ident=',GetIdentifier(Params.Identifier),
            ' Creating Input Expression List for proc node ...'
            );
            {$ENDIF}
            NewExprInputList:=
              Params.IdentifierTool.CreateParamExprListFromProcNode(
                                                       StartContextNode,Params);
            {$IFDEF ShowProcSearch}
            debugln(['TFindDeclarationTool.CheckSrcIdentifier Params: ',NewExprInputList.AsString]);
            {$ENDIF}
            FreeAndNil(Params.FoundProc^.ExprInputList);
            Params.FoundProc^.ExprInputList:=NewExprInputList;
          end;
        end;
      end;
      if Params.FoundProc^.ExprInputList=nil then begin
        // create expression list without params
        Params.FoundProc^.ExprInputList:=TExprTypeList.Create;
      end;
    end;

    // create compatibility lists for params
    // (each parameter is checked for compatibility)
    CompListSize:=SizeOf(TTypeCompatibility)
                  *Params.FoundProc^.ExprInputList.Count;
    if (CompListSize>0)
    and (Params.FoundProc^.ParamCompatibilityList=nil) then begin
      GetMem(Params.FoundProc^.ParamCompatibilityList,CompListSize);
      //DebugLn(['TFindDeclarationTool.CheckSrcIdentifier FoundProc=',dbgs(Params.FoundProc),' New ParamCompatibilityList=',dbgs(Params.FoundProc^.ParamCompatibilityList),' CompListSize=',CompListSize]);
    end else begin
      //DebugLn(['TFindDeclarationTool.CheckSrcIdentifier FoundProc=',dbgs(Params.FoundProc),' Old ParamCompatibilityList=',dbgs(Params.FoundProc^.ParamCompatibilityList),' CompListSize=',CompListSize]);
    end;

    // check the first found proc for compatibility
    // (compare the expression list with the proc param list)
    if not Params.FoundProc^.CacheValid then begin
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' Check the first found proc for compatibility ...'
      );
      {$ENDIF}
      FirstParameterNode:=Params.FoundProc^.Context.Tool.GetFirstParameterNode(
                                                Params.FoundProc^.Context.Node);
      ParamCompatibility:=
        Params.FoundProc^.Context.Tool.IsParamExprListCompatibleToNodeList(
          FirstParameterNode,
          Params.FoundProc^.ExprInputList,
          fdfIgnoreMissingParams in Params.Flags,
          Params,Params.FoundProc^.ParamCompatibilityList);
      Params.FoundProc^.ProcCompatibility:=ParamCompatibility;
      Params.FoundProc^.CacheValid:=true;
      if ParamCompatibility=tcExact then begin
        Params.SetResult(Params.FoundProc^.Context.Tool,
                         Params.FoundProc^.Context.Node.FirstChild);
      end;
    end;
    
    if Params.FoundProc^.ProcCompatibility=tcExact then begin
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' First Proc ParamCompatibility=',TypeCompatibilityNames[Params.FoundProc^.ProcCompatibility]
      );
      {$ENDIF}
      // the first proc fits exactly -> stop the search
      Result:=ifrSuccess;
      exit;
    end;

    // check the current proc for compatibility
    // (compare the expression list with the proc param list)
    {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
    DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
    ' Ident=',GetIdentifier(Params.Identifier),
    ' Check the current found proc for compatibility ...'
    );
    {$ENDIF}
    if CompListSize>0 then begin
      GetMem(CurCompatibilityList,CompListSize);
      //DebugLn(['TFindDeclarationTool.CheckSrcIdentifier create temp CurCompatibilityList=',dbgs(CurCompatibilityList),' CompListSize=',CompListSize]);
    end else begin
      CurCompatibilityList:=nil;
    end;
    try
      FirstParameterNode:=
        FoundContext.Tool.GetFirstParameterNode(FoundContext.Node);
      ParamCompatibility:=
        FoundContext.Tool.IsParamExprListCompatibleToNodeList(
          FirstParameterNode,
          Params.FoundProc^.ExprInputList,
          fdfIgnoreMissingParams in Params.Flags,
          Params,CurCompatibilityList);
      {$IF defined(ShowFoundIdentifier) or defined(ShowProcSearch)}
      DebugLn('[TFindDeclarationTool.CheckSrcIdentifier]',
      ' Ident=',GetIdentifier(Params.Identifier),
      ' Current Proc ParamCompatibility=',TypeCompatibilityNames[ParamCompatibility]
      );
      {$ENDIF}
      if ParamCompatibility=tcExact then begin
        // the current proc fits exactly -> stop the search
        Params.ChangeFoundProc(FoundContext,ParamCompatibility,
          CurCompatibilityList);
        CurCompatibilityList:=nil; // set to nil, so that it will not be freed
        Params.SetResult(FoundContext.Tool,FoundContext.Node.FirstChild);
        Result:=ifrSuccess;
      end else if ParamCompatibility=tcCompatible then begin
        // the proc fits not exactly, but is compatible
        if (Params.FoundProc^.ProcCompatibility=tcInCompatible)
        or CompatibilityList1IsBetter(CurCompatibilityList,
          Params.FoundProc^.ParamCompatibilityList,
          Params.FoundProc^.ExprInputList.Count) then
        begin
          // the new proc fits better
          Params.ChangeFoundProc(FoundContext,ParamCompatibility,CurCompatibilityList);
          CurCompatibilityList:=nil; // set to nil, so that it will not be freed
        end;
      end;
    finally
      // end overloaded proc search
      if CurCompatibilityList<>nil then begin
        //DebugLn(['TFindDeclarationTool.CheckSrcIdentifier free CurCompatibilityList=',dbgs(CurCompatibilityList)]);
        FreeMem(CurCompatibilityList);
      end;
    end;
  end else
  if (FoundContext.Node.Desc=ctnVarDefinition) then begin
    if not (fdfIgnoreClassVisibility in Params.Flags)
    and (FoundContext.Tool<>Params.IdentifierTool)
    and (GetClassVisibility(FoundContext.Node)=ctnClassPrivate) then
      Result:=ifrProceedSearch
    else
      Result:=ifrSuccess;
  end else begin
    Result:=ifrSuccess;
  end;
end;

function TFindDeclarationTool.DoOnIdentifierFound(
  Params: TFindDeclarationParams;
  FoundNode: TCodeTreeNode): TIdentifierFoundResult;
// this internal function is called, whenever an identifier is found
var IsTopLvlIdent: boolean;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(FoundNode);{$ENDIF}
  IsTopLvlIdent:=(fdfTopLvlResolving in Params.Flags);
  if Assigned(Params.OnIdentifierFound) then
    Result:=Params.OnIdentifierFound(Params,CreateFindContext(Self,FoundNode))
  else
    Result:=ifrSuccess;
  if (Result=ifrSuccess) and IsTopLvlIdent
  and Assigned(Params.OnTopLvlIdentifierFound) then
    Params.OnTopLvlIdentifierFound(Params,CreateFindContext(Self,FoundNode));
end;

function TFindDeclarationTool.IsCompatible(TargetNode: TCodeTreeNode;
  const ExpressionType: TExpressionType;
  Params: TFindDeclarationParams): TTypeCompatibility;
var TargetContext: TFindContext;
  OldInput: TFindDeclarationInput;
  NodeExprType: TExpressionType;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(TargetNode);{$ENDIF}
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsCompatible] A Node=',TargetNode.DescAsString,
  ' ExpressionType=',ExpressionTypeDescNames[ExpressionType.Desc]);
  {$ENDIF}
  Result:=tcIncompatible;
  // find base type of node
  OldInput.Flags:=Params.Flags;
  Include(Params.Flags,fdfExceptionOnNotFound);
  TargetContext:=FindBaseTypeOfNode(Params,TargetNode);
  Params.Flags:=OldInput.Flags;
  
  // compare node base type and ExpressionType
  if (ExpressionType.Context.Node<>nil)
  and (ExpressionType.Context.Node=TargetContext.Node) then begin
    // same base type
    Result:=tcExact;
  end
  else if (TargetContext.Node.Desc=ctnGenericParameter)
  or ((ExpressionType.Desc=xtContext)
      and (ExpressionType.Context.Node.Desc=ctnGenericParameter))
  then begin
    // generic type is always preferred
    Result:=tcExact;
  end
  else if (TargetContext.Node.Desc=ctnSetType) then begin
    {$IFDEF ShowExprEval}
    DebugLn('[TFindDeclarationTool.IsCompatible] TargetContext.Node.Desc=ctnSetType',
    ' "',copy(TargetContext.Tool.Src,TargetContext.Node.Parent.StartPos,20),'"');
    {$ENDIF}
    if (ExpressionType.Desc=xtConstSet) then begin
      // both are sets, compare type of sets
      if (ExpressionType.SubDesc<>xtNone) then begin

        // ToDo: check if enums of expression fits into enums of target

        // ToDo: ppu, dcu

        Result:=tcCompatible;
      end else
        // the empty set is compatible to all kinds of sets
        Result:=tcExact;
    end else begin
    
    end;
  end else begin
    NodeExprType:=CleanExpressionType;
    NodeExprType.Desc:=xtContext;
    NodeExprType.Context:=CreateFindContext(Self,TargetNode);
    Result:=IsCompatible(NodeExprType,ExpressionType,Params);
  end;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsCompatible] END',
  ' BaseNode=',TargetContext.Node.DescAsString,
  ' ExpressionType=',ExpressionTypeDescNames[ExpressionType.Desc],
  ' Result=',TypeCompatibilityNames[Result]
  );
  {$ENDIF}
end;

function TFindDeclarationTool.IsCompatible(TargetType,
  ExpressionType: TExpressionType; Params: TFindDeclarationParams
  ): TTypeCompatibility;
begin
  if TargetType.Desc=xtContext then begin
    if TargetType.Context.Node.Desc=ctnGenericParameter then
      exit(tcExact);
    TargetType:=TargetType.Context.Tool.ConvertNodeToExpressionType(
                    TargetType.Context.Node,Params);
  end;
  if ExpressionType.Desc=xtContext then begin
    if ExpressionType.Context.Node.Desc=ctnGenericParameter then
      exit(tcExact);
    ExpressionType:=ExpressionType.Context.Tool.ConvertNodeToExpressionType(
                    ExpressionType.Context.Node,Params);
  end;
  Result:=IsBaseCompatible(TargetType,ExpressionType,Params);
end;

function TFindDeclarationTool.GetCurrentAtomType: TVariableAtomType;
var
  Node: TCodeTreeNode;
  c: Char;
begin
  //debugln(['TFindDeclarationTool.GetCurrentAtomType ',CurPos.StartPos,' ',CurPos.EndPos,' ',SrcLen,' ',GetAtom]);
  if (CurPos.StartPos=CurPos.EndPos) then
    exit(vatSpace)
  else if (CurPos.StartPos<1) or (CurPos.StartPos>SrcLen) then
    exit(vatNone);
  c:=Src[CurPos.StartPos];
  if IsIdentStartChar[c] then begin
    if WordIsPredefinedIdentifier.DoItCaseInsensitive(Src,CurPos.StartPos,
      CurPos.EndPos-CurPos.StartPos) then
      exit(vatPreDefIdentifier)
    else if UpAtomIs('INHERITED') then
      exit(vatINHERITED)
    else if UpAtomIs('AS') then
      exit(vatAS)
    else if WordIsKeyWord.DoItCaseInsensitive(Src,CurPos.StartPos,
             CurPos.EndPos-CurPos.StartPos) then
      exit(vatKeyWord)
    else if UpAtomIs('PROPERTY') then begin
      Node:=FindDeepestNodeAtPos(CurPos.StartPos,false);
      if (Node<>nil) and (Node.Desc in [ctnProperty,ctnPropertySection]) then
        exit(vatKeyword)
      else
        exit(vatIdentifier);
    end else
      exit(vatIdentifier);
  end else if (CurPos.StartPos=CurPos.EndPos-1) then begin
    case c of
    '.': exit(vatPoint);
    '^': exit(vatUp);
    '(': exit(vatRoundBracketOpen);
    ')': exit(vatRoundBracketClose);
    '[': exit(vatEdgedBracketOpen);
    ']': exit(vatEdgedBracketClose);
    '@': exit(vatAddrOp);
    else exit(vatNone);
    end;
  end
  else begin
    case c of
    '''','#': exit(vatStringConstant);
    '&':
      begin
        if (CurPos.StartPos+1=CurPos.EndPos) then exit(vatNone);
        c:=Src[CurPos.StartPos+1];
        if IsIdentStartChar[c] then begin
          // &keyword
          exit(vatIdentifier);
        end else if IsNumberChar[c] then
          exit(vatNumber) // octal
        else exit(vatNone);
      end;
    else exit(vatNone);
    end;
  end;
end;

function TFindDeclarationTool.CreateParamExprListFromStatement(
  StartPos: integer; Params: TFindDeclarationParams; GetAlias: boolean
  ): TExprTypeList;
var ExprType: TExpressionType;
  BracketClose: char;
  ExprStartPos, ExprEndPos: integer;
  CurIgnoreErrorAfterPos: Integer;
  OldFlags: TFindDeclarationFlags;
  ok: Boolean;
  AliasType: TFindContext;

  procedure RaiseBracketNotFound;
  begin
    RaiseExceptionFmt(20170421200621,ctsStrExpectedButAtomFound,[BracketClose,GetAtom]);
  end;
  
begin
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.CreateParamExprListFromStatement] ',
  '"',copy(Src,StartPos,40),'" Context=',Params.ContextNode.DescAsString);
  {$ENDIF}
  Result:=TExprTypeList.Create;
  ok:=false;
  try
    MoveCursorToCleanPos(StartPos);
    ReadNextAtom; // reads first atom after proc name
    if AtomIsChar('(') then
      BracketClose:=')'
    else if AtomIsChar('[') then
      BracketClose:=']'
    else
      BracketClose:=#0;
    if IgnoreErrorAfterValid then
      CurIgnoreErrorAfterPos:=IgnoreErrorAfterCleanedPos
    else
      CurIgnoreErrorAfterPos:=-1;
    OldFlags:=Params.Flags;
    if BracketClose<>#0 then begin
      // read parameter list
      ReadNextAtom;
      if not AtomIsChar(BracketClose) then begin
        // read all expressions
        while true do begin
          ExprStartPos:=CurPos.StartPos;
          // read til comma or bracket close
          repeat
            if CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen] then begin
              ReadTilBracketClose(true);
            end;
            ReadNextAtom;
            if (CurPos.StartPos>SrcLen)
            or (CurPos.Flag in [cafRoundBracketClose,cafEdgedBracketClose,cafComma])
            then
              break;
          until false;
          ExprEndPos:=CurPos.StartPos;
          // find expression type
          if (CurIgnoreErrorAfterPos>=ExprStartPos) then
            Params.Flags:=Params.Flags-[fdfExceptionOnNotFound];
          //DebugLn('TFindDeclarationTool.CreateParamExprListFromStatement CurIgnoreErrorAfterPos=',dbgs(CurIgnoreErrorAfterPos),' ExprStartPos=',dbgs(ExprStartPos));
          if GetAlias then begin
            AliasType:=CleanFindContext;
            ExprType:=FindExpressionResultType(Params,ExprStartPos,ExprEndPos,@AliasType);
            Result.Add(ExprType,AliasType);
          end else begin
            ExprType:=FindExpressionResultType(Params,ExprStartPos,ExprEndPos);
            Result.Add(ExprType);
          end;
          MoveCursorToCleanPos(ExprEndPos);
          ReadNextAtom;
          if AtomIsChar(BracketClose) then break;
          if not AtomIsChar(',') then
            RaiseBracketNotFound;
          ReadNextAtom;
        end;
      end;
    end;
    Params.Flags:=OldFlags;
    {$IFDEF ShowExprEval}
    DebugLn('[TFindDeclarationTool.CreateParamExprListFromStatement] END ',
    'ParamCount=',dbgs(Result.Count),' "',copy(Src,StartPos,40),'"');
    DebugLn('  ExprList=[',Result.AsString,']');
    {$ENDIF}
    Ok:=true;
  finally
    if not Ok then Result.Free;
  end;
end;

function TFindDeclarationTool.CreateParamExprListFromProcNode(
  ProcNode: TCodeTreeNode; Params: TFindDeclarationParams): TExprTypeList;
var
  ExprType: TExpressionType;
  ParamNode: TCodeTreeNode;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(ProcNode);{$ENDIF}
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.CreateParamExprListFromProcNode] ',
  '"',copy(Src,ProcNode.StartPos,40),'" Context=',ProcNode.DescAsString);
  {$ENDIF}
  Result:=TExprTypeList.Create;
  ParamNode:=GetFirstParameterNode(ProcNode);
  while ParamNode<>nil do begin
    // find expression type
    ExprType:=ConvertNodeToExpressionType(ParamNode,Params);
    // add expression type to list
    Result.Add(ExprType);
    ParamNode:=ParamNode.NextBrother;
  end;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.CreateParamExprListFromProcNode] END ',
  'ParamCount=',dbgs(Result.Count),' "',copy(Src,ProcNode.StartPos,40),'"');
  DebugLn('  ExprList=[',Result.AsString,']');
  {$ENDIF}
end;

function TFindDeclarationTool.CompatibilityList1IsBetter( List1,
  List2: TTypeCompatibilityList; ListCount: integer): boolean;
// List1 and List2 should only contain tcCompatible and tcExact values
var i: integer;
begin
  // search first difference, start at end
  i:=ListCount-1;
  while (i>=0) and (List1[i]=List2[i]) do dec(i);
  // List1 is better, if first difference is better for List1
  Result:=(i>=0) and (List1[i]=tcExact);
  {$IFDEF ShowFoundIdentifier}
  DebugLn('[TFindDeclarationTool.CompatibilityList1IsBetter] END i=',dbgs(i));
  {$ENDIF}
end;

function TFindDeclarationTool.ContextIsDescendOf(const DescendContext,
  AncestorContext: TFindContext; Params: TFindDeclarationParams): boolean;
  
  procedure RaiseInternalError;
  begin
    RaiseException(20170421200624,'[TFindDeclarationTool.ContextIsDescendOf] '
      +' internal error: DescendContext.Desc<>ctnClass');
  end;
  
var CurContext: TFindContext;
  OldInput: TFindDeclarationInput;
begin
  if not (DescendContext.Node.Desc in AllClasses) then
    RaiseInternalError;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.ContextIsDescendOf] ',
  ' DescendContext="',copy(DescendContext.Tool.Src,DescendContext.Node.Parent.StartPos,15),'"');
  {$ENDIF}
  CurContext:=DescendContext;
  Params.Save(OldInput);
  repeat
    Result:=CurContext.Tool.FindAncestorOfClass(CurContext.Node,Params,true);
    if Result then begin
      CurContext:=CreateFindContext(Params);
      {$IFDEF ShowExprEval}
      DebugLn('[TFindDeclarationTool.ContextIsDescendOf] B ',
      ' CurContext="',copy(CurContext.Tool.Src,CurContext.Node.Parent.StartPos,15),'"');
      {$ENDIF}
      Result:=FindContextAreEqual(CurContext,AncestorContext);
      if Result then exit;
    end else
      break;
  until false;
  Result:=false;
end;

function TFindDeclarationTool.IsBaseCompatible(const TargetType,
  ExpressionType: TExpressionType; Params: TFindDeclarationParams
  ): TTypeCompatibility;
// test if ExpressionType can be assigned to TargetType
// both expression types must be base types
var TargetNode, ExprNode: TCodeTreeNode;
begin
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsBaseCompatible] START ',
  ' TargetType=',ExprTypeToString(TargetType),
  ' ExpressionType=',ExprTypeToString(ExpressionType));
  {$ENDIF}
  Result:=tcIncompatible;
  if (TargetType.Desc=xtContext)
  and (TargetType.Context.Node.Desc=ctnGenericParameter) then
    exit(tcExact);
  if (ExpressionType.Desc=xtContext)
  and (ExpressionType.Context.Node.Desc=ctnGenericParameter) then
    exit(tcExact);
  if (TargetType.Desc=ExpressionType.Desc) then begin
    case TargetType.Desc of
    
    xtNone: ;
    
    xtContext:
      begin
        TargetNode:=TargetType.Context.Node;
        ExprNode:=ExpressionType.Context.Node;
        {$IFDEF ShowExprEval}
        DebugLn('[TFindDeclarationTool.IsBaseCompatible] C ',
        ' TargetContext="',copy(TargetType.Context.Tool.Src,TargetType.Context.Node.StartPos,20),'"',
        ' ExpressionContext="',copy(ExpressionType.Context.Tool.Src,ExpressionType.Context.Node.StartPos,20),'"'
        );
        {$ENDIF}
        if TargetNode=ExprNode then
          Result:=tcExact
        else
        if ExprNode.Desc=TargetNode.Desc then begin
          // same context type
          case ExprNode.Desc of
          
          ctnClass, ctnClassInterface, ctnDispinterface, ctnObject, ctnRecordType,
          ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
          ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass:
            // check, if ExpressionType.Context descends from TargetContext
            if ContextIsDescendOf(ExpressionType.Context,
                                  TargetType.Context,Params)
            then
              Result:=tcExact;
              
          ctnRangedArrayType,ctnOpenArrayType:
            // ToDo: check range and type of arrayfields
            begin
              Result:=tcCompatible;
            end;

          end;
        end else begin
          // different context type
          
        end;
      end;
    else
      Result:=tcExact;
    end;
    
  end else if ((TargetType.Desc=xtPointer)
      and (ExpressionType.Desc=xtContext)
      and (ExpressionType.Context.Node.Desc in AllClasses))
  then begin
    // assigning a class to a pointer
    Result:=tcExact;
    
  end else begin
    // check, if ExpressionType can be auto converted into TargetType
    if ((TargetType.Desc in xtAllRealTypes)
      and (ExpressionType.Desc in xtAllRealConvertibles))
    or ((TargetType.Desc in xtAllStringTypes)
      and (ExpressionType.Desc in xtAllStringConvertibles))
    or ((TargetType.Desc in xtAllWideStringTypes)
      and (ExpressionType.Desc in xtAllWideStringCompatibleTypes))
    or ((TargetType.Desc in xtAllIntegerTypes)
      and (ExpressionType.Desc in xtAllIntegerConvertibles))
    or ((TargetType.Desc in xtAllBooleanTypes)
      and (ExpressionType.Desc in xtAllBooleanConvertibles))
    or ((TargetType.Desc in xtAllPointerTypes)
      and (ExpressionType.Desc in xtAllPointerConvertibles))
    or (TargetType.Desc=xtJSValue)
    then
      Result:=tcCompatible
    else if (TargetType.Desc=xtContext) then begin
      TargetNode:=TargetType.Context.Node;
      if ((TargetNode.Desc in (AllClasses+[ctnProcedure]))
        and (ExpressionType.Desc=xtNil))
      or ((TargetNode.Desc in [ctnOpenArrayType,ctnRangedArrayType])
        and (TargetNode.LastChild<>nil)
        and (TargetNode.LastChild.Desc=ctnOfConstType)
        and (ExpressionType.Desc=xtConstSet))
      then
        Result:=tcCompatible
    end
    else if (ExpressionType.Desc=xtContext) then begin
      ExprNode:=ExpressionType.Context.Node;
      if (TargetType.Desc=xtFile) and (ExprNode.Desc=ctnFileType)
      then
        Result:=tcCompatible
    end;
  end;
  {$IFDEF ShowExprEval}
  DebugLn('[TFindDeclarationTool.IsBaseCompatible] END ',
  ' TargetType=',ExpressionTypeDescNames[TargetType.Desc],
  ' ExpressionType=',ExpressionTypeDescNames[ExpressionType.Desc],
  ' Result=',TypeCompatibilityNames[Result]
  );
  {$ENDIF}
end;

function TFindDeclarationTool.CheckParameterSyntax(StartPos,
  CleanCursorPos: integer; out ParameterAtom, ProcNameAtom: TAtomPosition; out
  ParameterIndex: integer): boolean;
// check for Identifier(expr,expr,...,expr,VarName
//        or Identifier[expr,expr,...,expr,VarName
// ParameterIndex is 0 based
{off $DEFINE VerboseCPS}

  procedure RaiseBracketNotOpened;
  begin
    if CurPos.Flag=cafRoundBracketClose then
      RaiseExceptionFmt(20170421200628,ctsBracketNotFound,['('])
    else
      RaiseExceptionFmt(20170421200630,ctsBracketNotFound,['[']);
  end;

  function CheckIdentifierAndParameterList: boolean; forward;

  function CheckBrackets: boolean;
  { check simple brackets (no identifier in front of brackets)
  }
  var
    BracketAtom: TAtomPosition;
  begin
    BracketAtom:=CurPos;
    {$IFDEF VerboseCPS}DebugLn('CheckBrackets "',GetAtom,'" BracketAtom=',dbgs(BracketAtom));{$ENDIF}
    repeat
      ReadNextAtom;
      if CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen] then begin
        if (LastAtoms.GetPriorAtom.Flag=cafWord) then begin
          {$IFDEF VerboseCPS}DebugLn('CheckBrackets check word+bracket open');{$ENDIF}
          UndoReadNextAtom;
          if CheckIdentifierAndParameterList() then exit(true);
        end else begin
          {$IFDEF VerboseCPS}DebugLn('CheckBrackets check bracket open');{$ENDIF}
          if CheckBrackets() then exit(true);
        end;
      end else if CurPos.Flag in [cafRoundBracketClose,cafEdgedBracketClose]
      then begin
        if (BracketAtom.Flag=cafRoundBracketOpen)
           =(CurPos.Flag=cafRoundBracketClose)
        then begin
          // closing bracket found, but the variable was not in them
          {$IFDEF VerboseCPS}DebugLn('CheckBrackets bracket closed');{$ENDIF}
          exit(false);
        end else begin
          // invalid closing bracket found
          RaiseBracketNotOpened;
        end;
      end;
    until (CurPos.EndPos>CleanCursorPos);
    Result:=false;
  end;

  function CheckIdentifierAndParameterList: boolean;
  { when called: CursorPos is at an identifier followed by a ( or [
  }
  var
    BracketAtom: TAtomPosition;
    CurProcNameAtom: TAtomPosition;
    CurParameterIndex: Integer;
    ParameterStart: integer;
  begin
    Result:=false;
    if CurPos.Flag<>cafWord then exit;
    CurProcNameAtom:=CurPos;
    CurParameterIndex:=0;
    {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList START "',GetAtom,'" ',dbgs(CurProcNameAtom));{$ENDIF}
    ReadNextAtom;
    if not (CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen]) then exit;
    BracketAtom:=CurPos;
    ParameterStart:=CurPos.EndPos;
    {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList Bracket="',GetAtom,'"');{$ENDIF}
    repeat
      ReadNextAtom;
      {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList Atom="',GetAtom,'"');{$ENDIF}
      if (CurPos.EndPos>CleanCursorPos)
      or ((CurPos.EndPos=CleanCursorPos)
        and ((CurPos.Flag=cafWord) or AtomIsChar('@')))
      then begin
        // parameter found => search parameter expression bounds e.g. ', parameter ,'
        // important: this function should work, even if the code
        //            behind CleanCursorPos has syntax errors
        {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList Parameter found, search range ...');{$ENDIF}
        ProcNameAtom:=CurProcNameAtom;
        ParameterIndex:=CurParameterIndex;
        ParameterAtom.StartPos:=ParameterStart;
        ParameterAtom.EndPos:=ParameterStart;
        MoveCursorToCleanPos(ParameterStart);
        repeat
          ReadNextAtom;
          {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList parameter atom "',GetAtom,'"');{$ENDIF}
          if (CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen]) then
          begin
            // atom belongs to the parameter expression
            if ParameterAtom.StartPos=ParameterAtom.EndPos then
              ParameterAtom.StartPos:=CurPos.StartPos;
            ReadTilBracketClose(false);
            ParameterAtom.EndPos:=CurPos.EndPos;
          end
          else
          if (CurPos.StartPos>SrcLen)
          or (CurPos.Flag in [cafComma,cafSemicolon,cafEnd,
              cafRoundBracketClose,cafEdgedBracketClose])
          or ((CurPos.Flag=cafWord)
              and (LastAtoms.GetPriorAtom.Flag=cafWord)
              and (not LastUpAtomIs(0,'INHERITED'))) then
          begin
            // end of parameter expression found
            {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList end of parameter found "',GetAtom,'" Parameter="',dbgstr(Src,ParameterAtom.StartPos,ParameterAtom.EndPos-ParameterAtom.StartPos),'"');{$ENDIF}
            exit(true);
          end else begin
            // atom belongs to the parameter expression
            if ParameterAtom.StartPos=ParameterAtom.EndPos then
              ParameterAtom.StartPos:=CurPos.StartPos;
            ParameterAtom.EndPos:=CurPos.EndPos;
          end;
        until false;
      end;
      if (CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen]) then begin
        if (LastAtoms.GetPriorAtom.Flag=cafWord) then begin
          {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList check word+bracket open');{$ENDIF}
          UndoReadNextAtom;
          if CheckIdentifierAndParameterList() then exit(true);
        end else begin
          {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList check bracket open');{$ENDIF}
          if CheckBrackets then exit(true);
        end;
      end
      else if CurPos.Flag in [cafRoundBracketClose,cafEdgedBracketClose] then
      begin
        {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList check bracket close');{$ENDIF}
        if (BracketAtom.Flag=cafRoundBracketOpen)
        =(CurPos.Flag=cafRoundBracketClose)
        then begin
          // parameter list ended in front of Variable => continue search
          {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList parameter list ended in front of cursor');{$ENDIF}
          if CurPos.Flag=cafEdgedBracketClose then begin
            ReadNextAtom;
            if CurPos.Flag=cafEdgedBracketOpen then begin
              // [][] is equal to [,]
              ParameterStart:=CurPos.EndPos;
              inc(CurParameterIndex);
              continue;
            end else
              UndoReadNextAtom;
          end;
          exit;
        end else begin
          // invalid closing bracket found
          RaiseBracketNotOpened;
        end;
      end;
      // finally after checking the expression: count commas
      if CurPos.Flag=cafComma then begin
        ParameterStart:=CurPos.EndPos;
        inc(CurParameterIndex);
      end;
      {$IFDEF VerboseCPS}DebugLn('CheckIdentifierAndParameterList After parsing atom. atom="',GetAtom,'"');{$ENDIF}
    until (CurPos.EndPos>CleanCursorPos);
  end;

var
  CommentStart: integer;
  CommentEnd: integer;
  CleanPosInFront: Integer;
begin
  Result:=false;
  ParameterAtom:=CleanAtomPosition;
  ProcNameAtom:=CleanAtomPosition;
  ParameterIndex:=0;
  //DebugLn('TFindDeclarationTool.CheckParameterSyntax START');

  if StartPos<1 then exit;
  // read code in front to find ProcName and check the syntax
  MoveCursorToCleanPos(StartPos);
  repeat
    ReadNextAtom;
    {$IFDEF VerboseCPS}
    DebugLn('TFindDeclarationTool.CheckParameterSyntax ',GetAtom,' at ',CleanPosToStr(CurPos.StartPos),' ',dbgs(CurPos.EndPos),'<',dbgs(CleanCursorPos));
    {$ENDIF}
    if CurPos.EndPos>CleanCursorPos then begin
      if not LastAtoms.HasPrior then exit;
      CleanPosInFront:=LastAtoms.GetPriorAtom.EndPos;
      //debugln(['TFindDeclarationTool.CheckParameterSyntax Cur="',GetAtom,'" Last="',GetAtom(LastAtoms.GetValueAt(0)),'"']);
      if not CleanPosIsInComment(CleanCursorPos,CleanPosInFront,
        CommentStart,CommentEnd,false) then exit;
      // cursor in a comment
      // => parse within the comment
      MoveCursorToCleanPos(CommentStart);
    end else if (CurPos.Flag in [cafRoundBracketOpen,cafEdgedBracketOpen])
    and (LastAtoms.GetPriorAtom.Flag=cafWord) then begin
      UndoReadNextAtom;
      if CheckIdentifierAndParameterList then exit(true);
      if CurPos.EndPos>CleanCursorPos then exit;
    end;
  until false;
end;

procedure TFindDeclarationTool.OnFindUsedUnitIdentifier(
  Sender: TPascalParserTool; IdentifierCleanPos: integer; Range: TEPRIRange;
  Node: TCodeTreeNode; Data: Pointer; var Abort: boolean);
var
  Identifier: PChar;
  CacheEntry: PInterfaceIdentCacheEntry;
  refs: TFindUsedUnitReferences;
  Found: Boolean;
  ReferencePos: TCodeXYPosition;
begin
  if Range=epriInDirective then exit;
  if not (Node.Desc in (AllPascalTypes+AllPascalStatements)) then exit;
  Identifier:=@Src[IdentifierCleanPos];
  refs:=TFindUsedUnitReferences(Data);
  CacheEntry:=refs.TargetTool.FInterfaceIdentifierCache.FindIdentifier(Identifier);
  //debugln(['TFindUsedUnitReferences.OnIdentifier Identifier=',GetIdentifier(Identifier),' Found=',CacheEntry<>nil]);
  if (CacheEntry=nil)
  and (CompareIdentifiers(Identifier,PChar(refs.TargetUnitName))<>0) then
    exit;
  Sender.MoveCursorToCleanPos(IdentifierCleanPos);
  Sender.ReadPriorAtom;
  if (Sender.CurPos.Flag=cafPoint) or (Sender.UpAtomIs('inherited')) then exit;
  //debugln(['TFindUsedUnitReferences.OnIdentifier Identifier=',GetIdentifier(Identifier),' at begin of term']);
  // find declaration
  refs.Params.Clear;
  refs.Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,
                 fdfIgnoreCurContextNode];
  refs.Params.ContextNode:=Node;
  //debugln(copy(Src,Params.ContextNode.StartPos,200));
  refs.Params.SetIdentifier(Self,Identifier,@CheckSrcIdentifier);

  if Range=epriInCode then begin
    // search identifier in code
    Found:=FindDeclarationOfIdentAtParam(refs.Params);
  end else begin
    // search identifier in comment -> if not found, this is no problem
    // => silently ignore
    try
      Found:=FindDeclarationOfIdentAtParam(refs.Params);
    except
      on E: ECodeToolError do begin
        // continue
      end;
      on E: Exception do
        raise;
    end;
  end;
  //debugln(['TFindUsedUnitReferences.OnIdentifier Identifier=',GetIdentifier(Identifier),' found=',Found]);

  if not Found then exit;

  if CleanPosToCaret(IdentifierCleanPos,ReferencePos) then
    AddCodePosition(refs.ListOfPCodeXYPosition,ReferencePos);
end;

function TFindDeclarationTool.FindNthParameterNode(Node: TCodeTreeNode;
  ParameterIndex: integer): TCodeTreeNode;
var
  ProcNode, FunctionNode: TCodeTreeNode;
  ProcHeadNode: TCodeTreeNode;
  ParameterNode: TCodeTreeNode;
  i: Integer;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=nil;
  if Node=nil then exit;
  if Node.Desc=ctnReferenceTo then begin
    Node:=Node.FirstChild;
    if Node=nil then exit;
  end;
  if Node.Desc in [ctnProcedure,ctnProcedureType] then begin
    ProcNode:=Node;
    //DebugLn('  FindNthParameterNode ProcNode="',copy(Params.NewCodeTool.Src,ProcNode.StartPos,ProcNode.EndPos-ProcNode.StartPos),'"');
    FunctionNode:=nil;
    BuildSubTreeForProcHead(ProcNode,FunctionNode);
    // find procedure head
    ProcHeadNode:=ProcNode.FirstChild;
    if (ProcHeadNode=nil) or (ProcHeadNode.Desc<>ctnProcedureHead) then begin
      DebugLn('  FindNthParameterNode Procedure has no parameter list');
      exit;
    end;
    // find parameter list
    ParameterNode:=ProcHeadNode.FirstChild;
    if (ParameterNode=nil) or (ParameterNode.Desc<>ctnParameterList)
    then begin
      DebugLn('  FindNthParameterNode Procedure has no parameter list');
      exit;
    end;
    // find parameter
    ParameterNode:=ParameterNode.FirstChild;
    i:=0;
    while (i<ParameterIndex) and (ParameterNode<>nil) do begin
      //DebugLn('  FindNthParameterNode ',ParameterNode.DescAsString);
      ParameterNode:=ParameterNode.NextBrother;
      inc(i);
    end;
    Result:=ParameterNode;
  end;
end;

constructor TFindDeclarationTool.Create;
begin
  inherited Create;
  FSourcesChangeStep:=CTInvalidChangeStamp64;
  FFilesChangeStep:=CTInvalidChangeStamp64;
  FInitValuesChangeStep:=CTInvalidChangeStamp;
end;

procedure TFindDeclarationTool.DoDeleteNodes(StartNode: TCodeTreeNode);
var
  HelperKind: TFDHelpersListKind;
begin
  ClearNodeCaches;
  if FInterfaceIdentifierCache<>nil then begin
    FInterfaceIdentifierCache.Clear;
    FInterfaceIdentifierCache.Complete:=false;
  end;
  for HelperKind in TFDHelpersListKind do
    if FInterfaceHelperCache[HelperKind]<>nil then
      FInterfaceHelperCache[HelperKind].Clear;
  inherited DoDeleteNodes(StartNode);
end;

function TFindDeclarationTool.CheckDependsOnNodeCaches(
  CheckedTools: TAVLTree = nil): boolean;
var
  ANode: TAVLTreeNode;
  ATool: TFindDeclarationTool;
  FreeCheckedTools: Boolean;
  SourcesChangeStep, FilesChangeStep: int64;
  InitValuesChangeStep: integer;
begin
  Result:=false;
  //debugln(['TFindDeclarationTool.CheckDependsOnNodeCaches ',MainFilename,' FDependsOnCodeTools=',FDependsOnCodeTools]);
  if (FDependsOnCodeTools=nil) or FCheckingNodeCacheDependencies then exit;
  if Scanner=nil then exit;

  if Assigned(Scanner.OnGetGlobalChangeSteps) then begin
    // check if any sources or values have changed
    Scanner.OnGetGlobalChangeSteps(SourcesChangeStep,FilesChangeStep,
                                   InitValuesChangeStep);
    if (SourcesChangeStep=FSourcesChangeStep)
    and (FilesChangeStep=FFilesChangeStep)
    and (InitValuesChangeStep=FInitValuesChangeStep) then
      // all sources and values are the same
      exit;
    FSourcesChangeStep:=SourcesChangeStep;
    FFilesChangeStep:=FilesChangeStep;
    FInitValuesChangeStep:=InitValuesChangeStep;
  end;

  if (CheckedTools<>nil) and (CheckedTools.Find(Self)<>nil) then exit;

  {$IFDEF ShowCacheDependencies}
  DebugLn(['[TFindDeclarationTool.CheckDependsOnNodeCaches] START DependsOn=',FDependsOnCodeTools.Count,' ',MainFilename]);
  {$ENDIF}
  FCheckingNodeCacheDependencies:=true;
  FreeCheckedTools:=false;
  if CheckedTools=nil then begin
    FreeCheckedTools:=true;
    CheckedTools:=TAVLTree.Create;
  end;
  try
    CheckedTools.Add(Self);
    ANode:=FDependsOnCodeTools.FindLowest;
    while ANode<>nil do begin
      ATool:=TFindDeclarationTool(ANode.Data);
      Result:=ATool.UpdateNeeded(lsrImplementationStart)
              or ATool.CheckDependsOnNodeCaches(CheckedTools);
      if Result then exit;
      ANode:=FDependsOnCodeTools.FindSuccessor(ANode);
    end;
    Result:=false;
  finally
    {$IFDEF ShowCacheDependencies}
    DebugLn('[TFindDeclarationTool.CheckDependsOnNodeCaches] Result=',DbgS(Result),' ',MainFilename);
    {$ENDIF}
    FCheckingNodeCacheDependencies:=false;
    if FreeCheckedTools then FreeAndNil(CheckedTools);
    if Result then ClearNodeCaches;
  end;
end;

destructor TFindDeclarationTool.Destroy;
var
  HelperKind: TFDHelpersListKind;
begin
  FreeAndNil(FInterfaceIdentifierCache);
  for HelperKind in TFDHelpersListKind do
    FreeAndNil(FInterfaceHelperCache[HelperKind]);
  FreeAndNil(FDependsOnCodeTools);
  FreeAndNil(FDependentCodeTools);
  if FDirectoryCache<>nil then begin
    FDirectoryCache.Release;
    FDirectoryCache:=nil;
  end;
  FFindMissingFPCUnits.Free;
  inherited Destroy;
end;

procedure TFindDeclarationTool.ClearNodeCaches;
var
  NodeCache: TCodeTreeNodeCache;
  BaseTypeCache: TBaseTypeCache;
begin
  // check if there is something in cache to delete
  if (FFirstNodeCache=nil) and (FFirstBaseTypeCache=nil)
  and (FRootNodeCache=nil)
  and ((FDependentCodeTools=nil) or (FDependentCodeTools.Count=0))
  and ((FDependsOnCodeTools=nil) or (FDependsOnCodeTools.Count=0)) then
    exit;
  {$IFDEF ShowCacheDependencies}
  DebugLn('[TFindDeclarationTool.ClearNodeCaches] Force=',
          DbgS(Force),' ',MainFilename);
  {$ENDIF}
    
  // clear node caches
  while FFirstNodeCache<>nil do begin
    NodeCache:=FFirstNodeCache;
    FFirstNodeCache:=NodeCache.Next;
    NodeCacheMemManager.DisposeNodeCache(NodeCache);
  end;
  while FFirstBaseTypeCache<>nil do begin
    BaseTypeCache:=FFirstBaseTypeCache;
    FFirstBaseTypeCache:=BaseTypeCache.NextCache;
    BaseTypeCacheMemManager.DisposeBaseTypeCache(BaseTypeCache);
  end;
  if FRootNodeCache<>nil then begin
    NodeCacheMemManager.DisposeNodeCache(FRootNodeCache);
    FRootNodeCache:=nil;
  end;
  
  // clear dependent codetools
  ClearDependentNodeCaches;
  ClearDependsOnToolRelationships;
end;

procedure TFindDeclarationTool.ClearDependentNodeCaches;
var
  ANode: TAVLTreeNode;
  DependentTool: TFindDeclarationTool;
begin
  if (FDependentCodeTools=nil) or (FDependentCodeTools.Count=0)
  or FClearingDependentNodeCaches then exit;
  FClearingDependentNodeCaches:=true;
  {$IFDEF ShowCacheDependencies}
  DebugLn('[TFindDeclarationTool.ClearDependentNodeCaches] ',MainFilename);
  {$ENDIF}
  try
    ANode:=FDependentCodeTools.FindLowest;
    while ANode<>nil do begin
      DependentTool:=TFindDeclarationTool(ANode.Data);
      DependentTool.ClearNodeCaches;
      ANode:=FDependentCodeTools.FindSuccessor(ANode);
    end;
    FDependentCodeTools.Clear;
  finally
    FClearingDependentNodeCaches:=false;
  end;
end;

procedure TFindDeclarationTool.ClearDependsOnToolRelationships;
var
  ANode: TAVLTreeNode;
  DependOnTool: TFindDeclarationTool;
begin
  if (FDependsOnCodeTools=nil) or (FDependsOnCodeTools.Count=0) then exit;
  {$IFDEF ShowCacheDependencies}
  DebugLn('[TFindDeclarationTool.ClearDependsOnToolRelationships] ',MainFilename);
  {$ENDIF}
  ANode:=FDependsOnCodeTools.FindLowest;
  while ANode<>nil do begin
    DependOnTool:=TFindDeclarationTool(ANode.Data);
    if not DependOnTool.FClearingDependentNodeCaches then
      DependOnTool.FDependentCodeTools.Remove(Self);
    ANode:=FDependsOnCodeTools.FindSuccessor(ANode);
  end;
  FDependsOnCodeTools.Clear;
end;

procedure TFindDeclarationTool.AddToolDependency(
  DependOnTool: TFindDeclarationTool);
// build a relationship: this tool depends on DependOnTool
{$IFDEF DebugAddToolDependency}
var
  AVLNode: TAVLTreeNode;
  Tool: TFindDeclarationTool;
{$ENDIF}
begin
  {$IFDEF ShowCacheDependencies}
  DebugLn('[TFindDeclarationTool.AddToolDependency] "',MainFilename,'" depends on "',DependOnTool.MainFilename,'"');
  {$ENDIF}
  if DependOnTool.FDependentCodeTools=nil then
    DependOnTool.FDependentCodeTools:=TAVLTree.Create;
  if DependOnTool.FDependentCodeTools.Find(Self)=nil then
    DependOnTool.FDependentCodeTools.Add(Self);

  if FDependsOnCodeTools=nil then
    FDependsOnCodeTools:=TAVLTree.Create;

  if FDependsOnCodeTools.Find(DependOnTool)=nil then begin
    {$IFDEF DebugAddToolDependency}
    AVLNode:=FDependsOnCodeTools.FindLowest;
    while AVLNode<>nil do begin
      Tool:=TFindDeclarationTool(AVLNode.Data);
      if CompareFilenames(ExtractFilename(Tool.MainFilename),ExtractFilename(DependOnTool.MainFilename))=0 then begin
        DebugLn(['TFindDeclarationTool.AddToolDependency inconsistency: ',Tool.MainFilename,' ',DependOnTool.MainFilename]);
      end;
      AVLNode:=FDependsOnCodeTools.FindSuccessor(AVLNode);
    end;
    {$ENDIF}

    FDependsOnCodeTools.Add(DependOnTool);
  end;
end;

procedure TFindDeclarationTool.ConsistencyCheck;
var ANodeCache: TCodeTreeNodeCache;
begin
  inherited ConsistencyCheck;
  if FInterfaceIdentifierCache<>nil then
    FInterfaceIdentifierCache.ConsistencyCheck;
  ANodeCache:=FFirstNodeCache;
  while ANodeCache<>nil do begin
    ANodeCache.ConsistencyCheck;
    ANodeCache:=ANodeCache.Next;
  end;
  if FDependentCodeTools<>nil then
    FDependentCodeTools.ConsistencyCheck;
  if FDependsOnCodeTools<>nil then
    FDependsOnCodeTools.ConsistencyCheck;
end;

procedure TFindDeclarationTool.CalcMemSize(Stats: TCTMemStats);
var
  NodeCache: TCodeTreeNodeCache;
  TypeCache: TBaseTypeCache;
  m: PtrUInt;
  HelperKind: TFDHelpersListKind;
begin
  inherited CalcMemSize(Stats);
  if FInterfaceIdentifierCache<>nil then
    Stats.Add('TFindDeclarationTool.FInterfaceIdentifierCache',
      FInterfaceIdentifierCache.CalcMemSize);
  for HelperKind in TFDHelpersListKind do
    if FInterfaceHelperCache[HelperKind]<>nil then
      Stats.Add('TFindDeclarationTool.FInterfaceHelperCache[]',
        FInterfaceHelperCache[HelperKind].CalcMemSize);
  if FFirstNodeCache<>nil then begin
    m:=0;
    NodeCache:=FFirstNodeCache;
    while NodeCache<>nil do begin
      inc(m,NodeCache.CalcMemSize);
      NodeCache:=NodeCache.Next;
    end;
    Stats.Add('TFindDeclarationTool.NodeCache',m);
  end;
  if FFirstBaseTypeCache<>nil then begin
    m:=0;
    TypeCache:=FFirstBaseTypeCache;
    while TypeCache<>nil do begin
      inc(m,TypeCache.CalcMemSize);
      TypeCache:=TypeCache.NextCache;
    end;
    Stats.Add('TFindDeclarationTool.TypeCache',m);
  end;
  if FDependentCodeTools<>nil then
    Stats.Add('TFindDeclarationTool.FDependentCodeTools',
      FDependentCodeTools.Count*SizeOf(TAVLTreeNode));
  if FDependsOnCodeTools<>nil then
    Stats.Add('TFindDeclarationTool.FDependsOnCodeTools',
      FDependsOnCodeTools.Count*SizeOf(TAVLTreeNode));
end;

procedure TFindDeclarationTool.ValidateToolDependencies;
begin
  //debugln(['TFindDeclarationTool.ValidateToolDependencies ',MainFilename]);
  inherited ValidateToolDependencies;
  CheckDependsOnNodeCaches;
end;

function TFindDeclarationTool.GetNodeCache(Node: TCodeTreeNode;
  CreateIfNotExists: boolean): TCodeTreeNodeCache;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  while (Node<>nil) and (not (Node.Desc in AllNodeCacheDescs)) do
    Node:=Node.Parent;
  if Node<>nil then begin
    if (Node.Cache=nil) and CreateIfNotExists then
      CreateNewNodeCache(Node);
    if (Node.Cache is TCodeTreeNodeCache) then
      Result:=TCodeTreeNodeCache(Node.Cache)
    else
      Result:=nil;
  end else begin
    if (FRootNodeCache=nil) and CreateIfNotExists then
      FRootNodeCache:=CreateNewNodeCache(nil);
    Result:=FRootNodeCache;
  end;
end;

procedure TFindDeclarationTool.AddResultToNodeCaches(
  StartNode, EndNode: TCodeTreeNode; SearchedForward: boolean;
  Params: TFindDeclarationParams; SearchRangeFlags: TNodeCacheEntryFlags);
var Node: TCodeTreeNode;
  CurNodeCache, LastNodeCache: TCodeTreeNodeCache;
  CleanStartPos, CleanEndPos: integer;
  NewNode: TCodeTreeNode;
  NewTool: TPascalParserTool;
  NewCleanPos: integer;
  {$IFDEF ShowNodeCache}
  BeVerbose: boolean;
  NodeOwner: TObject;
  
  function WriteSrcPos(t: TPascalParserTool; p: integer): string;
  begin
    Result:=StringToPascalConst(copy(t.Src,p-10,10)+'|'+copy(t.Src,p,15)+'"');
  end;
  
  function NodeOwnerAsString(ANodeOwner: TObject): string;
  begin
    if ANodeOwner=nil then
      Result:='nil'
    else if ANodeOwner is TPascalParserTool then
      Result:=ExtractFileName(TPascalParserTool(ANodeOwner).MainFilename)
    else
      Result:='?'+ANodeOwner.ClassName+'?';
  end;
  {$ENDIF}
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(StartNode);{$ENDIF}
  if StartNode=nil then exit;
  if EndNode=nil then EndNode:=StartNode;

  if Params.NewNode<>nil then begin
    // identifier found
    NewNode:=Params.NewNode;
    NewTool:=Params.NewCodeTool;
    NewCleanPos:=Params.NewCleanPos;
  end else begin
    // identifier not found
    NewNode:=nil;
    NewTool:=nil;
    NewCleanPos:=-1;
  end;
  // calculate search range
  if EndNode<>nil then begin
    if SearchedForward then begin
      CleanStartPos:=StartNode.StartPos;
      CleanEndPos:=EndNode.EndPos;
    end else begin
      CleanStartPos:=EndNode.StartPos;
      CleanEndPos:=StartNode.EndPos;
    end;
  end else begin
    // searched till start or end of source
    if not SearchedForward then begin
      CleanStartPos:=1;
      CleanEndPos:=StartNode.StartPos;
    end else begin
      CleanStartPos:=StartNode.StartPos;
      CleanEndPos:=SrcLen+1;
    end;
  end;

  {$IFDEF ShowNodeCache}
  beVerbose:=true; //CompareSrcIdentifiers(Params.Identifier,'InitDecompressor');
  if beVerbose then begin
    DebugLn('(((((((((((((((((((((((((((==================');
    
    DbgOut('TFindDeclarationTool.AddResultToNodeCaches ',
    ' Ident=',GetIdentifier(Params.Identifier));
    DbgOut(' SearchedForward=',DbgS(SearchedForward));
    DbgOut(' Flags=[');
    if ncefSearchedInParents in SearchRangeFlags then DbgOut('Parents');
    if ncefSearchedInAncestors in SearchRangeFlags then DbgOut(',Ancestors');
    DebugLn(']');
    
    DbgOut('     StartNode=',StartNode.DescAsString,
      '('+DbgS(StartNode.StartPos),'-',DbgS(StartNode.EndPos)+')=',
      WriteSrcPos(Self,StartNode.StartPos));
    NodeOwner:=FindOwnerOfCodeTreeNode(StartNode);
    if NodeOwner<>Self then DbgOut(' StartNodeOwner=',NodeOwnerAsString(NodeOwner));
    DebugLn('');
    
    if EndNode<>nil then
      DbgOut(' EndNode=',EndNode.DescAsString,
        '('+DbgS(EndNode.StartPos),'-',DbgS(EndNode.EndPos)+')=',
        WriteSrcPos(Self,EndNode.StartPos))
    else
      DbgOut(' EndNode=nil');
    NodeOwner:=FindOwnerOfCodeTreeNode(EndNode);
    if NodeOwner<>Self then DbgOut(' EndNodeOwner=',NodeOwnerAsString(NodeOwner));
    DebugLn('');

    DebugLn('     Self=',ExtractFileName(MainFilename));
    
    if NewNode<>nil then begin
      DebugLn('       NewNode=',NewNode.DescAsString,
              '(',DbgS(NewNode.StartPos),'-',DbgS(NewNode.EndPos),')=',
              WriteSrcPos(NewTool,NewNode.StartPos),
                 ' NewTool=',ExtractFileName(NewTool.MainFilename));
    end else begin
      DebugLn('       NOT FOUND');
      //RaiseCatchableException('');
    end;
    
    DebugLn('  CleanStartPos=',DbgS(CleanStartPos),' ',WriteSrcPos(Self,CleanStartPos));
    DebugLn('  CleanEndPos=',DbgS(CleanEndPos),' ',WriteSrcPos(Self,CleanEndPos));
  end;
  {$ENDIF}
  LastNodeCache:=nil;
  // start with parent of deepest node and end parent of highest
  Node:=StartNode;
  repeat
    if (Node.Desc in AllNodeCacheDescs) then begin
      if (Node.Cache=nil) then
        CreateNewNodeCache(Node);
      if (Node.Cache is TCodeTreeNodeCache) then begin
        CurNodeCache:=TCodeTreeNodeCache(Node.Cache);
        if LastNodeCache<>CurNodeCache then begin
          {$IFDEF ShowNodeCache}
          if BeVerbose then begin
            CurNodeCache.WriteDebugReport('  BEFORE NODECACHE REPORT: ');
          end;
          {$ENDIF}
          CurNodeCache.Add(Params.Identifier,
                           Self,CleanStartPos,CleanEndPos,
                           NewNode,NewTool,NewCleanPos,SearchRangeFlags);
          {$IFDEF ShowNodeCache}
          if BeVerbose then begin
            CurNodeCache.WriteDebugReport('  AFTER NODECACHE REPORT: ');
          end;
          {$ENDIF}
          LastNodeCache:=CurNodeCache;
        end;
      end;
    end;
    Node:=Node.Parent;
  until (Node=nil) or (EndNode=Node) or EndNode.HasAsParent(Node);
  {$IFDEF ShowNodeCache}
  if BeVerbose then begin
    DebugLn('=========================))))))))))))))))))))))))))))))))');
  end;
  {$ENDIF}
end;

function TFindDeclarationTool.CreateNewNodeCache(
  Node: TCodeTreeNode): TCodeTreeNodeCache;
begin
  {$IFDEF CheckNodeTool}CheckNodeTool(Node);{$ENDIF}
  Result:=NodeCacheMemManager.NewNodeCache(Node);
  Result.Next:=FFirstNodeCache;
  FFirstNodeCache:=Result;
end;

function TFindDeclarationTool.CreateNewBaseTypeCache(
  Tool: TFindDeclarationTool; Node: TCodeTreeNode): TBaseTypeCache;
begin
  {$IFDEF CheckNodeTool}Tool.CheckNodeTool(Node);{$ENDIF}
  Result:=BaseTypeCacheMemManager.NewBaseTypeCache(Node);
  Result.NextCache:=Tool.FFirstBaseTypeCache;
  Tool.FFirstBaseTypeCache:=Result;
end;

procedure TFindDeclarationTool.CreateBaseTypeCaches(
  NodeStack: PCodeTreeNodeStack; const Result: TFindContext);
var i: integer;
  Entry: PCodeTreeNodeStackEntry;
  BaseTypeCache: TBaseTypeCache;
  NextEntry: PCodeTreeNodeStackEntry;
begin
  {$IFDEF ShowBaseTypeCache}
  DbgOut('[TFindDeclarationTool.CreateBaseTypeCaches] ',
  ' StackPtr=',DbgS(NodeStack^.StackPtr));
  DebugLn(' Self=',MainFilename);
  if Result.Node<>nil then
    DbgOut(' Result='+Result.Node.DescAsString,
       ' Start='+DbgS(Result.Node.StartPos),
       ' End='+DbgS(Result.Node.EndPos),
       ' "'+copy(Result.Tool.Src,Result.Node.StartPos,15)+'" ',Result.Tool.MainFilename)
  else
    DbgOut(' Result=nil');
  DebugLn('');
  {$ENDIF}
  for i:=0 to NodeStack^.StackPtr do begin
    Entry:=GetNodeStackEntry(NodeStack,i);
    if Entry^.Node.Cache=nil then begin
      {$IFDEF ShowBaseTypeCache}
      DebugLn('  i=',DbgS(i),' Node=',Entry^.Node.DescAsString,' "',copy(Entry^.Tool.Src,Entry^.Node.StartPos,15),'"');
      {$ENDIF}
      BaseTypeCache:=
        CreateNewBaseTypeCache(TFindDeclarationTool(Entry^.Tool),Entry^.Node);
      if BaseTypeCache<>nil then begin
        BaseTypeCache.BaseNode:=Result.Node;
        BaseTypeCache.BaseTool:=Result.Tool;
        if i<NodeStack^.StackPtr then begin
          NextEntry:=GetNodeStackEntry(NodeStack,i+1);
          BaseTypeCache.NextNode:=NextEntry^.Node;
          BaseTypeCache.NextTool:=NextEntry^.Tool;
        end else begin
          BaseTypeCache.NextNode:=Result.Node;
          BaseTypeCache.NextTool:=Result.Tool;
        end;
      end;
    end;
  end;
end;

function TFindDeclarationTool.GetExpressionTypeOfTypeIdentifier(
  Params: TFindDeclarationParams): TExpressionType;
var
  OldFlags: TFindDeclarationFlags;
begin
  OldFlags:=Params.Flags;
  if FindIdentifierInContext(Params) then begin
    Params.Flags:=OldFlags;
    Result:=Params.NewCodeTool.ConvertNodeToExpressionType(Params.NewNode,Params);
  end else begin
    // predefined identifier
    Params.Flags:=OldFlags;
    Result:=CleanExpressionType;
    Result.Desc:=PredefinedIdentToExprTypeDesc(Params.Identifier,Scanner.PascalCompiler);
  end;
end;

function TFindDeclarationTool.FindTermTypeAsString(TermPos: TAtomPosition;
  Params: TFindDeclarationParams;
  out ExprType: TExpressionType): string;
var
  EdgedBracketsStartPos: integer;
  SetNode: TCodeTreeNode;
  SetTool: TFindDeclarationTool;
  AliasType: TFindContext;
begin
  //debugln(['TFindDeclarationTool.FindTermTypeAsString START']);
  {$IFDEF CheckNodeTool}CheckNodeTool(Params.ContextNode);{$ENDIF}
  Result:='';
  AliasType:=CleanFindContext;

  if IsTermEdgedBracket(TermPos,EdgedBracketsStartPos) then begin
    // check for constant sets: [enum]
    MoveCursorToCleanPos(EdgedBracketsStartPos);
    ReadNextAtom;
    ReadNextAtom;
    if CurPos.Flag=cafWord then begin
      {$IFDEF ShowExprEval}
      debugln(['TFindDeclarationTool.FindTermTypeAsString "[name" : check for enumeration type ...']);
      debugln(['TFindDeclarationTool.FindTermTypeAsString StartContext=',Params.ContextNode.DescAsString,'=',dbgstr(Src,Params.ContextNode.StartPos,15),'"']);
      {$ENDIF}
      ExprType:=FindExpressionResultType(Params,EdgedBracketsStartPos+1,-1);
      {$IFDEF ShowExprEval}
      debugln(['TFindDeclarationTool.FindTermTypeAsString "[name" : ',ExprTypeToString(ExprType)]);
      {$ENDIF}
      if (ExprType.Desc=xtContext)
      and (ExprType.Context.Node.Desc in [ctnEnumerationType,ctnEnumIdentifier])
      then begin
        SetTool:=ExprType.Context.Tool;
        SetNode:=SetTool.FindSetOfEnumerationType(ExprType.Context.Node);
        if SetNode<>nil then begin
          ExprType:=CleanExpressionType;
          ExprType.Desc:=xtContext;
          ExprType.SubDesc:=xtNone;
          ExprType.Context.Tool:=SetTool;
          ExprType.Context.Node:=SetNode;
          Result:=SetTool.ExtractDefinitionName(SetNode);
          exit;
        end;
      end;
    end;
  end;

  // check if TermPos is @Name and a pointer (= ^Name) can be found
  if IsTermNamedPointer(TermPos,ExprType) then begin
    // pointer type
  end else begin
    ExprType:=CleanExpressionType;
    Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,fdfSearchInHelpers,
                   fdfTopLvlResolving,fdfFunctionResult,fdfIgnoreOperatorError]
                  +Params.Flags*[fdfOverrideStringTypesWithFirstParamType];
    ExprType:=FindExpressionResultType(Params,TermPos.StartPos,TermPos.EndPos,
                                       @AliasType);
  end;

  if AliasType.Node<>nil then begin
    ExprType:=CleanExpressionType;
    ExprType.Desc:=xtContext;
    ExprType.Context:=AliasType;
  end;
  Result:=FindExprTypeAsString(ExprType,TermPos.StartPos);
end;

function TFindDeclarationTool.FindForInTypeAsString(TermPos: TAtomPosition;
  CursorNode: TCodeTreeNode; Params: TFindDeclarationParams; out
  ExprType: TExpressionType): string;

  procedure RaiseTermHasNoIterator(id: int64; TermExprType: TExpressionType);
  begin
    if TermPos.StartPos<1 then
      TermPos.StartPos:=1;
    MoveCursorToCleanPos(TermPos.StartPos);
    debugln(['TFindDeclarationTool.FindForInTypeAsString TermExprType=',ExprTypeToString(TermExprType)]);
    RaiseException(id,'Can not find an enumerator for '''+TrimCodeSpace(GetAtom(TermPos))+'''');
  end;

  procedure ResolveExpr(SubExprType: TExpressionType);
  var
    AliasType: TFindContext;
    Node: TCodeTreeNode;
  begin
    {$IFDEF ShowForInEval}
    debugln(['  ResolveExpr ',ExprTypeToString(SubExprType)]);
    {$ENDIF}
    // use default enumerators
    case SubExprType.Desc of
      xtContext:
        begin
          case SubExprType.Context.Node.Desc of
          ctnSpecialize, ctnClass, ctnRecordType, ctnClassHelper, ctnRecordHelper, ctnTypeHelper, ctnClassInterface:
            begin
              AliasType:=CleanFindContext;
              if not SubExprType.Context.Tool.FindEnumeratorOfClass(
                SubExprType.Context.Node,true,ExprType,@AliasType, Params)
              then
                RaiseTermHasNoIterator(20170421211210,SubExprType);
              if (ExprType.Desc = xtContext)
              and (ExprType.Context.Node.Desc = ctnGenericParameter) then begin
                Params.UpdateContexWithGenParamValue(ExprType.Context);
              end;
              Result:=FindExprTypeAsString(ExprType,TermPos.StartPos,@AliasType);
            end;
          ctnEnumerationType:
            begin
              Node:=SubExprType.Context.Node.Parent;
              if Node.Desc=ctnTypeDefinition then
                Result:=SubExprType.Context.Tool.ExtractIdentifier(Node.StartPos);
            end;
          ctnSetType:
            if SubExprType.Context.Tool.FindEnumerationTypeOfSetType(
                                    SubExprType.Context.Node,ExprType.Context)
            then begin
              ExprType.Desc:=xtContext;
              Result:=FindExprTypeAsString(ExprType,TermPos.StartPos);
            end;
          ctnRangedArrayType,ctnOpenArrayType:
            begin
              AliasType:=CleanFindContext;
              if SubExprType.Context.Tool.FindElementTypeOfArrayType(
                                    SubExprType.Context.Node,ExprType,@AliasType,Params)
              then begin
                Result:=FindExprTypeAsString(ExprType,TermPos.StartPos,@AliasType);
              end;
            end;
          else
            RaiseTermHasNoIterator(20170421211213,SubExprType);
          end;
        end;
      xtChar,
      xtSmallInt,
      xtShortInt,
      xtByte,
      xtWord,
      xtBoolean,
      xtByteBool,
      xtWordBool,
      xtLongBool,
      xtQWordBool,
      xtNativeInt,
      xtNativeUInt:
        Result:=ExpressionTypeDescNames[SubExprType.Desc];
      xtNone,
      xtWideChar,
      xtReal,
      xtSingle,
      xtDouble,
      xtExtended,
      xtCExtended,
      xtCurrency,
      xtComp,
      xtInt64,
      xtCardinal,
      xtQWord,
      xtPointer,
      xtFile,
      xtText,
      xtConstOrdInteger,
      xtConstReal,
      xtConstBoolean,
      xtLongint,
      xtLongWord,
      xtCompilerFunc,
      xtVariant,
      xtJSValue,
      xtNil:
        RaiseTermHasNoIterator(20170421211217,SubExprType);
      xtString,
      xtAnsiString,
      xtShortString,
      xtPChar,
      xtConstString:
        begin
          ExprType.Desc:=xtChar;
          Result:=ExpressionTypeDescNames[ExprType.Desc];
        end;
      xtWideString,
      xtUnicodeString:
        begin
          ExprType.Desc:=xtWideChar;
          Result:=ExpressionTypeDescNames[ExprType.Desc];
        end;
      xtConstSet:
        begin
        if SubExprType.Context.Node=nil then
          RaiseTermHasNoIterator(20170421211222,SubExprType);
        SubExprType:=SubExprType.Context.Tool.FindExpressionTypeOfConstSet(SubExprType.Context.Node);
        {$IFDEF ShowForInEval}
        debugln(['  ResolveExpr ConstSet Element: ',ExprTypeToString(SubExprType)]);
        {$ENDIF}
        if SubExprType.Desc=xtConstSet then
          RaiseTermHasNoIterator(20170421211222,SubExprType);
        ResolveExpr(SubExprType);
        end;
    else
      DebugLn('TFindDeclarationTool.FindForInTypeAsString.ResolveExpr TermExprType=',
        ExprTypeToString(SubExprType));
      RaiseTermHasNoIterator(20170421211225,SubExprType);
    end;
  end;

var
  TermExprType: TExpressionType;
  OperatorExprType: TExpressionType;
begin
  Result:='';
  ExprType:=CleanExpressionType;
  TermExprType:=CleanExpressionType;
  Params.ContextNode:=CursorNode;
  Params.Flags:=[fdfSearchInParentNodes,fdfSearchInAncestors,fdfSearchInHelpers,
                 fdfTopLvlResolving,fdfFunctionResult];
  TermExprType:=FindExpressionResultType(Params,TermPos.StartPos,TermPos.EndPos);

  {$IFDEF ShowForInEval}
  DebugLn('TFindDeclarationTool.FindForInTypeAsString TermExprType=',
    ExprTypeToString(TermExprType));
  {$ENDIF}
  // search operator enumerator
  if FindOperatorEnumerator(CursorNode,TermExprType,foeEnumeratorCurrentExprType,
    OperatorExprType)
  then begin
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindForInTypeAsString Operator=',ExprTypeToString(OperatorExprType)]);
    {$ENDIF}
    ExprType:=OperatorExprType;
    Result:=FindExprTypeAsString(ExprType,TermPos.StartPos);
    exit;
  end;
  // convert to string
  ResolveExpr(TermExprType);

  {$IFDEF ShowExprEval}
  DebugLn('TFindDeclarationTool.FindForInTypeAsString Result=',Result);
  {$ENDIF}
end;

function TFindDeclarationTool.FindEnumeratorOfClass(ClassNode: TCodeTreeNode;
  ExceptionOnNotFound: boolean; out ExprType: TExpressionType;
  AliasType: PFindContext; ParentParams: TFindDeclarationParams): boolean;
var
  Params: TFindDeclarationParams;
  ClassTool: TFindDeclarationTool;
  ClassContext: TFindContext;
  ProcTool: TFindDeclarationTool;
  ProcNode: TCodeTreeNode;
  EnumeratorContext: TFindContext;
  PropTool: TFindDeclarationTool;
  PropNode: TCodeTreeNode;
  CurrentContext: TFindContext;
begin
  Result:=false;
  if AliasType<>nil then
    AliasType^:=CleanFindContext;
  ExprType:=CleanExpressionType;
  Params:=TFindDeclarationParams.Create(ParentParams);
  try
    if ClassNode.Desc = ctnSpecialize then begin
      Params.ContextNode:=ClassNode;
      Params.Flags:=[fdfEnumIdentifier,fdfTopLvlResolving];
      ClassContext := FindBaseTypeOfNode(Params, ClassNode, AliasType);
      if (ClassContext.Node = nil)
      or not (ClassContext.Node.Desc in [ctnClass,ctnClassInterface,ctnRecordType]) then begin
        if ExceptionOnNotFound then begin
          MoveCursorToCleanPos(ClassNode.StartPos);
          RaiseExceptionFmt(20200505081501,ctsBaseTypeOfNotFound,[GetIdentifier(@Src[ClassNode.StartPos])]);
        end else
          exit;
      end;
      ClassTool := ClassContext.Tool;
      ClassNode := ClassContext.Node;
    end else begin
      ClassTool := Self;
    end;
    // search function 'GetEnumerator'
    Params.ContextNode:=ClassNode;
    Params.Flags:=[fdfSearchInAncestors,fdfSearchInHelpers];
    Params.SetIdentifier(Self,'GetEnumerator',nil);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass searching GetEnumerator for ',ExtractClassName(ClassNode,false),' ...']);
    {$ENDIF}
    if not ClassTool.FindIdentifierInContext(Params) then begin
      if ExceptionOnNotFound then begin
        MoveCursorToCleanPos(ClassNode.StartPos);
        RaiseException(20170421200638,ctsFunctionGetEnumeratorNotFoundInThisClass);
      end else begin
        {$IFDEF ShowForInEval}
        debugln(['TFindDeclarationTool.FindEnumeratorOfClass GetEnumerator not found for ',ExtractClassName(ClassNode,false)]);
        {$ENDIF}
        exit;
      end;
    end;
    ProcTool:=Params.NewCodeTool;
    ProcNode:=Params.NewNode;
    //DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass Proc']);
    if (ProcNode=nil) or (ProcNode.Desc<>ctnProcedure) then begin
      if ExceptionOnNotFound then begin
        MoveCursorToCleanPos(ClassNode.StartPos);
        RaiseException(20170421200640,ctsFunctionGetEnumeratorNotFoundInThisClass2);
      end else begin
        {$IFDEF ShowForInEval}
        debugln(['TFindDeclarationTool.FindEnumeratorOfClass GetEnumerator is not a proc, class=',ExtractClassName(ClassNode,false)]);
        {$ENDIF}
        exit;
      end;
    end;
    // search function type
    Params.Clear;
    Include(Params.Flags,fdfFunctionResult);
    EnumeratorContext:=ProcTool.FindBaseTypeOfNode(Params,ProcNode);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass EnumeratorContext=',FindContextToString(EnumeratorContext)]);
    {$ENDIF}
    if (EnumeratorContext.Node=nil)
    or not (EnumeratorContext.Node.Desc in [ctnClass,ctnClassInterface,ctnRecordType])
    then begin
      if ExceptionOnNotFound then begin
        ProcTool.MoveCursorToCleanPos(ProcNode.StartPos);
        ProcTool.RaiseException(20170421200642,ctsResultTypeOfFunctionGetEnumeratorNotFound);
      end else
        exit;
    end;
    // search 'Current' in enumerator class
    Params.Clear;
    Params.ContextNode:=EnumeratorContext.Node;
    Params.Flags:=[fdfSearchInAncestors];
    if ExceptionOnNotFound then
      Include(Params.Flags,fdfExceptionOnNotFound);
    Params.SetIdentifier(EnumeratorContext.Tool,'Current',nil);
    //DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass search current ...']);
    if not EnumeratorContext.Tool.FindIdentifierInContext(Params) then begin
      {$IFDEF ShowForInEval}
      DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass missing "current" in ',EnumeratorContext.Tool.ExtractClassName(EnumeratorContext.Node,false)]);
      {$ENDIF}
      exit;
    end;
    // check if "current" is a property
    PropTool:=Params.NewCodeTool;
    PropNode:=Params.NewNode;
    //DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass PropNode=',PropNode.DescAsString]);
    if (PropNode=nil) or (PropNode.Desc<>ctnProperty) then begin
      if ExceptionOnNotFound then begin
        EnumeratorContext.Tool.MoveCursorToCleanPos(EnumeratorContext.Node.StartPos);
        RaiseException(20170421200644,ctsPropertyCurrentNotFound);
      end else begin
        {$IFDEF ShowForInEval}
        DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass "current" is not a property']);
        {$ENDIF}
        exit;
      end;
    end;
    // search type of Current
    Params.Clear;
    if ExceptionOnNotFound then
      Include(Params.Flags,fdfExceptionOnNotFound);
    //DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass searching property type ...']);
    CurrentContext:=PropTool.FindBaseTypeOfNode(Params,PropNode,AliasType);
    ExprType:=CurrentContext.Tool.ConvertNodeToExpressionType(
                                          CurrentContext.Node,Params,AliasType);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindEnumeratorOfClass exprtype of CURRENT: ExprType=',ExprTypeToString(ExprType),' Alias=',FindContextToString(AliasType)]);
    {$ENDIF}
    Result:=ExprType.Desc<>xtNone;
  finally
    Params.Free;
  end;
end;

function TFindDeclarationTool.FindOperatorEnumerator(Node: TCodeTreeNode;
  ExprType: TExpressionType; Need: TFindOperatorEnumerator; out
  ResultExprType: TExpressionType): boolean;
// find a compatible operator overload for 'enumerator' with a parameter
// compatible to ExprType
// for example:
//   operator enumerator (AList: TMyList): TMyListEnumerator;
var
  Params: TFindDeclarationParams;
  OperatorTool: TFindDeclarationTool;
  OperatorNode: TCodeTreeNode;
  ClassContext: TFindContext;
  EnumeratorCurrentTool: TFindDeclarationTool;
  EnumeratorCurrentNode: TCodeTreeNode;
begin
  Result:=false;
  ResultExprType:=CleanExpressionType;
  Params:=TFindDeclarationParams.Create;
  try
    // search compatible operator enumerator
    Params.ContextNode:=Node;
    Params.Flags:=[fdfSearchInParentNodes];
    Params.Data:=@ExprType;
    Params.SetIdentifier(Self,'Enumerator',@CheckOperatorEnumerator);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator searching operator enumerator ...']);
    {$ENDIF}
    if not FindIdentifierInContext(Params) then begin
      {$IFDEF ShowForInEval}
      DebugLn(['TFindDeclarationTool.FindOperatorEnumerator operator enumerator not found']);
      {$ENDIF}
      exit;
    end;

    // operator found
    // now check if it is valid
    OperatorTool:=Params.NewCodeTool;
    OperatorNode:=Params.NewNode;
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator Operator="',OperatorTool.ExtractNode(OperatorNode,[]),'"']);
    {$ENDIF}
    if Need=foeProcNode then begin
      ResultExprType.Desc:=xtContext;
      ResultExprType.Context.Tool:=OperatorTool;
      ResultExprType.Context.Node:=OperatorNode;
      exit(true);
    end;

    // search class node
    Params.Clear;
    Params.Flags:=[fdfFunctionResult];
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator searching operator result object ...']);
    {$ENDIF}
    ClassContext:=OperatorTool.FindBaseTypeOfNode(Params,OperatorNode);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator ClassContext=',FindContextToString(ClassContext)]);
    {$ENDIF}
    case ClassContext.Node.Desc of
    ctnClass,ctnObject,ctnRecordType,ctnClassInterface,ctnDispinterface: ;
    else
      OperatorTool.MoveCursorToNodeStart(OperatorNode);
      OperatorTool.RaiseException(20170421200650,'operator enumerator result type is not object');
    end;
    if Need=foeResultClassNode then begin
      ResultExprType.Desc:=xtContext;
      ResultExprType.Context:=ClassContext;
      exit(true);
    end;

    // search property with modifier enumerator Current
    Params.Clear;
    Params.ContextNode:=ClassContext.Node;
    Params.Flags:=[fdfSearchInAncestors,fdfCollect];
    Params.SetIdentifier(Self,'',@CheckModifierEnumeratorCurrent);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator searching enumerator current ...']);
    {$ENDIF}
    if not ClassContext.Tool.FindIdentifierInContext(Params) then begin
      ClassContext.Tool.MoveCursorToNodeStart(ClassContext.Node);
      ClassContext.Tool.RaiseException(20170421200654,'enumerator ''current'' not found');
    end;
    EnumeratorCurrentTool:=Params.NewCodeTool;
    EnumeratorCurrentNode:=Params.NewNode;
    if Need=foeEnumeratorCurrentNode then begin
      ResultExprType.Desc:=xtContext;
      ResultExprType.Context.Tool:=EnumeratorCurrentTool;
      ResultExprType.Context.Node:=EnumeratorCurrentNode;
      exit(true);
    end;

    // search expression type of 'enumerator current'
    Params.Clear;
    Params.Flags:=[fdfFunctionResult];
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator searching enumerator current result ...']);
    {$ENDIF}
    ResultExprType:=EnumeratorCurrentTool.ConvertNodeToExpressionType(
                                                  EnumeratorCurrentNode,Params);
    {$IFDEF ShowForInEval}
    DebugLn(['TFindDeclarationTool.FindOperatorEnumerator enumerator current result=',ExprTypeToString(ResultExprType)]);
    {$ENDIF}
    Result:=true;
  finally
    Params.Free;
  end;
end;

function TFindDeclarationTool.FindEnumerationTypeOfSetType(
  SetTypeNode: TCodeTreeNode; out Context: TFindContext): boolean;
var
  Params: TFindDeclarationParams;
  p: LongInt;
begin
  Result:=false;
  if (SetTypeNode=nil) or (SetTypeNode.Desc<>ctnSetType) then exit;
  MoveCursorToNodeStart(SetTypeNode);
  ReadNextAtom; // set
  if not UpAtomIs('SET') then exit;
  ReadNextAtom; // of
  if not UpAtomIs('OF') then exit;
  ReadNextAtom;
  if not IsIdentStartChar[Src[CurPos.StartPos]] then
    // set of ()
    exit;
  Params:=TFindDeclarationParams.Create;
  try
    Params.Flags:=fdfDefaultForExpressions;
    Params.ContextNode:=SetTypeNode;
    p:=CurPos.StartPos;
    Params.SetIdentifier(Self,@Src[p],nil);
    if not FindIdentifierInContext(Params) then exit;
    if (Params.NewNode=nil)
    or (Params.NewNode.Desc<>ctnTypeDefinition)
    or (Params.NewNode.FirstChild=nil)
    or (Params.NewNode.FirstChild.Desc<>ctnEnumerationType) then begin
      MoveCursorToCleanPos(p);
      ReadNextAtom;
      RaiseStringExpectedButAtomFound(20170421200656,ctsEnumerationType);
    end;
    Context.Tool:=Params.NewCodeTool;
    Context.Node:=Params.NewNode;
    Result:=true;
  finally
    Params.Free;
  end;
end;

function TFindDeclarationTool.FindElementTypeOfArrayType(
  ArrayNode: TCodeTreeNode; out ExprType: TExpressionType;
  AliasType: PFindContext; ParentParams: TFindDeclarationParams): boolean;
var
  Params: TFindDeclarationParams;
  p: LongInt;
begin
  Result:=false;
  ExprType:=CleanExpressionType;
  AliasType^:=CleanFindContext;
  if (ArrayNode=nil) then exit;
  if (ArrayNode.Desc<>ctnOpenArrayType) and (ArrayNode.Desc<>ctnRangedArrayType)
  then exit;
  if (ArrayNode.Parent <> nil)
  and (ArrayNode.Parent.Desc = ctnGenericType)
  and (ParentParams <> nil) then begin
    ExprType.Desc := xtContext;
    ExprType.Context.Node := ParentParams.GenParamValueMappings.SpecializeParamsNode.FirstChild;
    ExprType.Context.Tool := ParentParams.GenParamValueMappings.SpecializeParamsTool;
    Result:=true;
  end else begin
    MoveCursorToNodeStart(ArrayNode);
    ReadNextAtom; // array
    if not UpAtomIs('ARRAY') then exit;
    ReadNextAtom; // of
    if CurPos.Flag=cafEdgedBracketOpen then begin
      ReadTilBracketClose(true);
      ReadNextAtom;
    end;
    if not UpAtomIs('OF') then exit;
    ReadNextAtom;
    if not AtomIsIdentifier then exit;
    Params:=TFindDeclarationParams.Create;
    try
      Params.Flags:=fdfDefaultForExpressions;
      Params.ContextNode:=ArrayNode;
      p:=CurPos.StartPos;
      Params.SetIdentifier(Self,@Src[p],nil);
      ExprType:=FindExpressionResultType(Params,p,-1,AliasType);
      Result:=true;
    finally
      Params.Free;
    end;
  end;
end;

function TFindDeclarationTool.CheckOperatorEnumerator(
  Params: TFindDeclarationParams; const FoundContext: TFindContext
  ): TIdentifierFoundResult;
var
  Node: TCodeTreeNode;
  ExprType: TExpressionType;
  Params2: TFindDeclarationParams;
begin
  Result:=ifrProceedSearch;
  {$IFDEF ShowExprEval}
  DebugLn(['TFindDeclarationTool.CheckOperatorEnumerator ',FindContextToString(FoundContext)]);
  {$ENDIF}
  if not FoundContext.Tool.NodeIsOperator(FoundContext.Node) then exit;
  FoundContext.Tool.BuildSubTreeForProcHead(FoundContext.Node);
  Node:=FoundContext.Node.FirstChild;
  if (Node=nil) or (Node.Desc<>ctnProcedureHead) then exit;
  Node:=Node.FirstChild;
  if (Node=nil) or (Node.Desc<>ctnParameterList) then exit;
  Node:=Node.FirstChild;
  if (Node=nil) then exit;
  if Node.NextBrother<>nil then exit;
  ExprType:=PExpressionType(Params.Data)^;
  Params2:=TFindDeclarationParams.Create;
  try
    if IsCompatible(Node,ExprType,Params2)=tcIncompatible then exit;
  finally
    Params2.Free;
  end;
  {$IFDEF ShowExprEval}
  DebugLn(['TFindDeclarationTool.CheckOperatorEnumerator FOUND ',FoundContext.Tool.ExtractNode(FoundContext.Node,[])]);
  {$ENDIF}
  Result:=ifrSuccess;
end;

function TFindDeclarationTool.CheckModifierEnumeratorCurrent(
  Params: TFindDeclarationParams; const FoundContext: TFindContext
  ): TIdentifierFoundResult;
begin
  Result:=ifrProceedSearch;
  //DebugLn(['TFindDeclarationTool.CheckModifierEnumeratorCurrent ',FindContextToString(FoundContext)]);
  case FoundContext.Node.Desc of
  ctnProperty:
    begin
      if FoundContext.Tool.PropertyHasSpecifier(FoundContext.Node,'Enumerator',false)
      then begin
        FoundContext.Tool.ReadNextAtom;
        if FoundContext.Tool.UpAtomIs('CURRENT') then
          Result:=ifrSuccess;
      end;
    end;
  end;
end;

function TFindDeclarationTool.IsTermEdgedBracket(TermPos: TAtomPosition; out
  EdgedBracketsStartPos: integer): boolean;
{ allowed:
   - at least one edged brackets
   - identifiers
   - functions
   - operators: + and -

    [a,b]+[c]-D()*inherited E

  not allowed:
    []<>[]
}
var
  Lvl: Integer;
  EndPos: LongInt;
begin
  Result:=false;
  EdgedBracketsStartPos:=0;
  EndPos:=TermPos.EndPos;
  if EndPos>SrcLen then
    EndPos:=SrcLen;
  MoveCursorToCleanPos(TermPos.StartPos);
  Lvl:=0;
  repeat
    ReadNextAtom;
    if (CurPos.StartPos>=EndPos) then
      break;
    case CurPos.Flag of
    cafRoundBracketOpen: ReadTilBracketClose(false);
    cafEdgedBracketOpen:
      begin
        inc(Lvl);
        if (Lvl=1) and (EdgedBracketsStartPos<1) then begin
          if (not LastAtoms.HasPrior)
          or LastAtomIs(-1,'+') or LastAtomIs(-1,'-') or LastAtomIs(-1,'*')
          then
            EdgedBracketsStartPos:=CurPos.StartPos;
        end;
      end;
    cafEdgedBracketClose:
      dec(Lvl);
    cafWord:
      ;
    cafComma:
      if Lvl<1 then
        break
      else if Lvl>1 then
        exit;
    else
      if AtomIsChar('+') or AtomIsChar('-') then begin
        // allowed
      end else begin
        // not allowed
        exit;
      end;
    end;
  until false;
  Result:=EdgedBracketsStartPos>0;
end;

function TFindDeclarationTool.IsTermNamedPointer(TermPos: TAtomPosition; out
  ExprType: TExpressionType): boolean;
// check if TermPos is @Name and a pointer (= ^Name) can be found
var
  SubExprType: TExpressionType;
  Node: TCodeTreeNode;
  PointerTool: TFindDeclarationTool;
  Params: TFindDeclarationParams;
  PointerNode: TCodeTreeNode;
begin
  //debugln(['TFindDeclarationTool.IsTermNamedPointer ',CleanPosToStr(TermPos.StartPos,true),' Term={',copy(Src,TermPos.StartPos,TermPos.EndPos-TermPos.StartPos),'}']);
  Result:=false;
  MoveCursorToCleanPos(TermPos.StartPos);
  ReadNextAtom;
  if not AtomIsChar('@') then exit;
  // a pointer
  ExprType:=CleanExpressionType;
  ExprType.Desc:=xtPointer;
  Result:=true;
  // try to find a name
  ReadNextAtom;
  if CurPos.StartPos>SrcLen then exit;
  Node := FindDeepestNodeAtPos(CurPos.StartPos,true);
  Params:=TFindDeclarationParams.Create(Self, Node);
  try
    SubExprType:=FindExpressionResultType(Params,CurPos.StartPos,-1);
  finally
    Params.Free;
  end;
  //debugln(['TFindDeclarationTool.IsTermNamedPointer SubExprType=',ExprTypeToString(SubExprType)]);
  if SubExprType.Desc in xtAllPredefinedTypes then begin
    ExprType.SubDesc:=SubExprType.Desc;
    exit(true);
  end else if (SubExprType.Desc=xtContext) then begin
    Node:=SubExprType.Context.Node;
    if (not (Node.Desc in AllIdentifierDefinitions))
    and (Node.Parent<>nil) and (Node.Parent.Desc in AllIdentifierDefinitions) then
      Node:=Node.Parent;
    if (Node.Desc in AllIdentifierDefinitions) then begin
      PointerTool:=SubExprType.Context.Tool;
      PointerNode:=PointerTool.FindPointerOfIdentifier(Node);
      if PointerNode<>nil then begin
        ExprType:=CleanExpressionType;
        ExprType.Desc:=xtContext;
        ExprType.SubDesc:=xtNone;
        ExprType.Context.Tool:=PointerTool;
        ExprType.Context.Node:=PointerNode;
        exit(true);
      end;
    end;
  end;
end;

function TFindDeclarationTool.FindSetOfEnumerationType(EnumNode: TCodeTreeNode
  ): TCodeTreeNode;
// search in the same type section for a 'set of ' node
var
  p: PChar;

 function IsSetOfEnum(Node: TCodeTreeNode): boolean;
 begin
   Result:=false;
   if (Node.Desc<>ctnTypeDefinition)
   or (Node.FirstChild=nil)
   or (Node.FirstChild.Desc<>ctnSetType) then exit;
   MoveCursorToNodeStart(Node.FirstChild);
   ReadNextAtom; // read set
   if not UpAtomIs('SET') then exit;
   ReadNextAtom; // read of
   if not UpAtomIs('OF') then exit;
   ReadNextAtom; // read of
   if CurPos.Flag<>cafWord then exit;
   Result:=CompareSrcIdentifiers(CurPos.StartPos,p);
 end;

begin
  {$IFDEF ShowExprEval}
  debugln(['TFindDeclarationTool.FindSetOfEnumerationType ',EnumNode.DescAsString]);
  {$ENDIF}
  if EnumNode.Desc=ctnEnumIdentifier then EnumNode:=EnumNode.Parent;
  if EnumNode.Desc=ctnEnumerationType then EnumNode:=EnumNode.Parent;
  p:=@Src[EnumNode.StartPos];
  Result:=EnumNode.Parent.FirstChild;
  while Result<>nil do begin
    if IsSetOfEnum(Result) then exit;
    Result:=Result.NextBrother;
  end;
end;

function TFindDeclarationTool.FindPointerOfIdentifier(
  TypeNode: TCodeTreeNode): TCodeTreeNode;
// search in the same type section for a '^identifier' node
var
  p: PChar;

 function IsPointerOf(Node: TCodeTreeNode): boolean;
 begin
   Result:=false;
   if (Node.Desc<>ctnTypeDefinition)
   or (Node.FirstChild=nil)
   or (Node.FirstChild.Desc<>ctnPointerType) then exit;
   MoveCursorToNodeStart(Node.FirstChild);
   ReadNextAtom; // read ^
   if not AtomIsChar('^') then exit;
   ReadNextAtom; // read identifier
   if not AtomIsIdentifier then exit;
   Result:=CompareSrcIdentifiers(CurPos.StartPos,p);
 end;

begin
  if TypeNode.Desc<>ctnTypeDefinition then exit(nil);
  p:=@Src[TypeNode.StartPos];
  Result:=TypeNode.Parent.FirstChild;
  while Result<>nil do begin
    if IsPointerOf(Result) then exit;
    Result:=Result.NextBrother;
  end;
end;

function TFindDeclarationTool.FindExprTypeAsString(
  const ExprType: TExpressionType; TermCleanPos: integer;
  AliasType: PFindContext): string;

  procedure RaiseTermNotSimple(id: int64);
  begin
    if TermCleanPos<1 then
      TermCleanPos:=1;
    MoveCursorToCleanPos(TermCleanPos);
    RaiseException(id,ctsTermNotSimple);
  end;

var
  FindContext: TFindContext;
  ANode: TCodeTreeNode;
begin
  {$IFDEF ShowExprEval}
  DebugLn('TFindDeclarationTool.FindExprTypeAsString ExprType=',
    ExprTypeToString(ExprType),' Alias=',FindContextToString(AliasType));
  {$ENDIF}
  Result:='';
  if (AliasType<>nil) and (AliasType^.Node<>nil) then begin
    case AliasType^.Node.Desc of
    ctnTypeDefinition:
      Result:=GetIdentifier(@AliasType^.Tool.Src[AliasType^.Node.StartPos]);
    end;
    if Result<>'' then exit;
  end;

  case ExprType.Desc of
    xtNone:
      RaiseTermNotSimple(20170421204649);

    xtContext:
      begin
        FindContext:=ExprType.Context;

        // ToDo: PPU, DCU

        if FindContext.Node.Parent.Desc=ctnTypeDefinition then
          FindContext.Node:=FindContext.Node.Parent;
        case FindContext.Node.Desc of

        ctnTypeDefinition:
          Result:=GetIdentifier(
                              @FindContext.Tool.Src[FindContext.Node.StartPos]);

        ctnVarDefinition,ctnConstDefinition:
          begin
            ANode:=FindContext.Tool.FindTypeNodeOfDefinition(FindContext.Node);
            if (ANode=nil) or (ANode.Desc<>ctnIdentifier) then
              RaiseTermNotSimple(20170421204653);
            Result:=GetIdentifier(@FindContext.Tool.Src[ANode.StartPos]);
          end;

        ctnClass, ctnClassInterface, ctnDispinterface, ctnObject, ctnRecordType,
        ctnClassHelper, ctnRecordHelper, ctnTypeHelper,
        ctnObjCClass, ctnObjCCategory, ctnObjCProtocol, ctnCPPClass:
          if (FindContext.Node.Parent<>nil)
          and (FindContext.Node.Parent.Desc in [ctnTypeDefinition,ctnGenericType])
          then
            Result:=GetIdentifier(
                       @FindContext.Tool.Src[FindContext.Node.Parent.StartPos]);

        ctnEnumIdentifier:
          if (FindContext.Node.Parent<>nil)
          and (FindContext.Node.Parent.Desc=ctnEnumerationType)
          and (FindContext.Node.Parent.Parent<>nil)
          and (FindContext.Node.Parent.Parent.Desc=ctnTypeDefinition)
          then
            Result:=GetIdentifier(
                     @FindContext.Tool.Src[FindContext.Node.Parent.Parent.StartPos]);

        ctnEnumerationType:
          if (FindContext.Node.Parent<>nil)
          and (FindContext.Node.Parent.Desc=ctnTypeDefinition)
          then
            Result:=GetIdentifier(
                     @FindContext.Tool.Src[FindContext.Node.Parent.StartPos]);

        ctnProperty,ctnGlobalProperty:
          begin
            FindContext.Tool.MoveCursorToPropType(FindContext.Node);
            Result:=FindContext.Tool.GetAtom;
          end;

        ctnIdentifier:
          begin
            Result:=GetIdentifier(
                              @FindContext.Tool.Src[FindContext.Node.StartPos]);
          end;

        ctnProcedureHead:
          begin
          ANode:=GetProcResultNode(FindContext.Node);
          if ANode<>nil then
            Result:=FindContext.Tool.ExtractNode(ANode,[]);
          end;

        end;

        if Result='' then begin
          DebugLn('TFindDeclarationTool.FindExprTypeAsString ContextNode=',
            FindContext.Node.DescAsString,' ',dbgsFC(FindContext));
          RaiseTermNotSimple(20170421204655);
        end;
      end;

    xtChar,
    xtWideChar,
    xtReal,
    xtSingle,
    xtDouble,
    xtExtended,
    xtCExtended,
    xtCurrency,
    xtComp,
    xtInt64,
    xtCardinal,
    xtQWord,
    xtPChar:
      Result:=ExpressionTypeDescNames[ExprType.Desc];

    xtPointer:
      begin
        case ExprType.SubDesc of
        xtChar,
        xtWideChar,
        xtReal,
        xtSingle,
        xtDouble,
        xtExtended,
        xtCExtended,
        xtCurrency,
        xtComp,
        xtInt64,
        xtCardinal,
        xtQWord,
        xtBoolean,
        xtByteBool,
        xtWordBool,
        xtLongBool,
        xtQWordBool,
        xtString,
        xtAnsiString,
        xtShortString,
        xtWideString,
        xtUnicodeString,
        xtLongint,
        xtLongWord,
        xtWord,
        xtSmallInt,
        xtShortInt,
        xtByte,
        xtNativeInt,
        xtNativeUInt:
          Result:='P'+ExpressionTypeDescNames[ExprType.SubDesc];
        else
          Result:=ExpressionTypeDescNames[xtPointer];
        end;
      end;

    xtFile,
    xtText,
    xtLongint,
    xtLongWord,
    xtSmallInt,
    xtWord,
    xtShortInt,
    xtByte,
    xtNativeInt,
    xtNativeUInt,
    xtSizeInt:
      Result:=ExpressionTypeDescNames[ExprType.Desc];

    xtBoolean,
    xtByteBool,
    xtWordBool,
    xtLongBool,
    xtQWordBool:
      Result:=ExpressionTypeDescNames[xtBoolean];

    xtString,
    xtAnsiString,
    xtShortString:
      Result:=ExpressionTypeDescNames[xtString];

    xtWideString, xtUnicodeString:
      Result:=ExpressionTypeDescNames[ExprType.Desc];

    xtConstOrdInteger:
      Result:='Integer';
    xtConstString:
      Result:=ExpressionTypeDescNames[xtString];
    xtConstReal:
      Result:=ExpressionTypeDescNames[xtExtended];
    xtConstSet:
      begin
        // eventually try to find the 'set of ' type
        RaiseTermNotSimple(20170421204658);
      end;
    xtConstBoolean:
      Result:=ExpressionTypeDescNames[xtBoolean];
    xtJSValue:
      Result:=ExpressionTypeDescNames[ExprType.Desc];
    xtNil:
      RaiseTermNotSimple(20170421204702);
  else
    DebugLn('TCodeCompletionCodeTool.FindExprTypeAsString ExprType=',
      ExprTypeToString(ExprType),' Alias=',FindContextToString(AliasType));
    RaiseTermNotSimple(20170421204705);
  end;
end;

function TFindDeclarationTool.FindExtendedExprOfHelper(HelperNode: TCodeTreeNode
  ): TExpressionType;
// returns the expression type of the extended class/type of a "helper for"
var
  ForNode: TCodeTreeNode;
  Params: TFindDeclarationParams;
begin
  case HelperNode.Desc of
  ctnClassHelper,ctnRecordHelper,ctnTypeHelper:
    ForNode:=FindHelperForNode(HelperNode);
  ctnObjCCategory:
    ForNode:=FindInheritanceNode(HelperNode);
  else
    exit(CleanExpressionType);
  end;
  if Assigned(ForNode) and Assigned(ForNode.FirstChild) then
  begin
    Params:=TFindDeclarationParams.Create;
    try
      Params.Flags:=fdfDefaultForExpressions-[fdfSearchInHelpers,fdfSearchInAncestors]+[fdfTypeType];
      Params.ContextNode:=ForNode;
      Result:=FindExpressionTypeOfTerm(ForNode.FirstChild.StartPos,ForNode.FirstChild.EndPos,Params,false);
    finally
      Params.Free;
    end;
  end else
    Result := CleanExpressionType;
end;

{ TFindDeclarationParams }

procedure TFindDeclarationParams.ClearFoundProc;
begin
  if FoundProc=nil then exit;
  //DebugLn(['TFindDeclarationParams.ClearFoundProc ',dbgs(FoundProc),' Saved=',FoundProc^.Owner<>nil]);
  if FoundProc^.Owner=nil then
    // the FoundProc is not saved
    FreeFoundProc(FoundProc,true)
  else if FoundProc^.Next<>nil then
    // the FoundProc is saved (release the later FoundProcs,
    // which are not needed any more)
    FreeFoundProc(FoundProc^.Next,true)
  else begin
    // the FoundProc is owned, that means someo other function is reponsible for freeing it
  end;
  FoundProc:=nil;
end;

procedure TFindDeclarationParams.FreeFoundProc(aFoundProc: PFoundProc; FreeNext: boolean);
var
  Next: PFoundProc;
begin
  //DebugLn(['TFindDeclarationParams.FreeFoundProc ',dbgs(aFoundProc)]);
  while aFoundProc<>nil do begin
    if (aFoundProc^.Owner<>Self)
    and ((FFoundProcStackFirst=aFoundProc)
         or (aFoundProc^.Prior<>nil) or (aFoundProc^.Next<>nil))
    then
      raise Exception.Create('FoundProc is in list, but not owned');
    if FreeNext then
      Next:=aFoundProc^.Next
    else
      Next:=nil;
    RemoveFoundProcFromList(aFoundProc);
    with aFoundProc^ do begin
      //DebugLn(['TFindDeclarationParams.FreeFoundProc ExprInputList=',dbgs(ExprInputList)]);
      if ExprInputList<>nil then
        FreeAndNil(ExprInputList);
      //DebugLn(['TFindDeclarationParams.FreeFoundProc ParamCompatibilityList=',dbgs(ParamCompatibilityList)]);
      if ParamCompatibilityList<>nil then begin
        FreeMem(ParamCompatibilityList);
        ParamCompatibilityList:=nil;
      end;
      CacheValid:=false;
    end;
    //DebugLn(['TFindDeclarationParams.FreeFoundProc Dispose ',dbgs(aFoundProc)]);
    Dispose(aFoundProc);
    aFoundProc:=Next;
  end;
end;

procedure TFindDeclarationParams.RemoveFoundProcFromList(aFoundProc: PFoundProc);
begin
  //DebugLn(['TFindDeclarationParams.RemoveFoundProcFromList ',dbgs(aFoundProc)]);
  if aFoundProc^.Owner<>Self then exit;
  if FFoundProcStackFirst=aFoundProc then
    FFoundProcStackFirst:=aFoundProc^.Next;
  if FFoundProcStackLast=aFoundProc then
    FFoundProcStackLast:=aFoundProc^.Next;
  with aFoundProc^ do begin
    if Next<>nil then
      Next^.Prior:=Prior;
    if Prior<>nil then
      Prior^.Next:=Next;
    Prior:=nil;
    Next:=nil;
    Owner:=nil;
  end;
end;

constructor TFindDeclarationParams.Create(ParentParams: TFindDeclarationParams);
begin
  inherited Create;
  Clear;
  Parent:=ParentParams;
end;

constructor TFindDeclarationParams.Create(Tool: TFindDeclarationTool;
  AContextNode: TCodeTreeNode);
begin
  Create(nil);//helper list will be created
  StartTool := Tool;
  StartNode := AContextNode;
  ContextNode := AContextNode;
  {$IFDEF CheckNodeTool}
  if (StartNode<>nil) and (StartNode.GetRoot<>StartTool.Tree.Root) then begin
    debugln(['TFindDeclarationParams.Create Inconsistency']);
    CTDumpStack;
    raise Exception.Create('TFindDeclarationParams.Create StartNode does not belong to StartTool');
  end;
  {$ENDIF}
  if (StartTool<>nil) and (StartNode<>nil) then
    FNeedHelpers:=true;
end;

destructor TFindDeclarationParams.Destroy;
var
  HelperKind: TFDHelpersListKind;
begin
  Clear;
  FreeFoundProc(FFoundProcStackFirst,true);
  for HelperKind in TFDHelpersListKind do
    if FFreeHelpers[HelperKind] then
      FreeAndNil(FHelpers[HelperKind]);
  GenParamValueMappings.FirstParamValueMapping.Free;
  inherited Destroy;
end;

procedure TFindDeclarationParams.Clear;
begin
  ClearInput;
  ClearFoundProc;
  ClearResult(false);
  OnTopLvlIdentifierFound:=nil;
end;

procedure TFindDeclarationParams.Save(out Input: TFindDeclarationInput);
begin
  Input.Flags:=Flags;
  Input.Identifier:=Identifier;
  Input.ContextNode:=ContextNode;
  Input.OnIdentifierFound:=OnIdentifierFound;
  Input.IdentifierTool:=IdentifierTool;
  Input.FoundProc:=FoundProc;
  if (FoundProc<>nil) and (FoundProc^.Owner=nil) then begin
    // add to list of saved FoundProcs
    //DebugLn(['TFindDeclarationParams.Save ',dbgs(FoundProc)]);
    FoundProc^.Prior:=FFoundProcStackLast;
    if FFoundProcStackLast<>nil then
      FFoundProcStackLast^.Next:=FoundProc;
    FFoundProcStackLast:=FoundProc;
    if FFoundProcStackFirst=nil then
      FFoundProcStackFirst:=FoundProc;
    FoundProc^.Owner:=Self;
  end;
end;

procedure TFindDeclarationParams.Load(Input: TFindDeclarationInput;
  FreeInput: boolean);
// set FreeInput to true, if the Input is not needed anymore and the dynamic
// data can be freed.
begin
  Flags:=Input.Flags;
  Identifier:=Input.Identifier;
  ContextNode:=Input.ContextNode;
  OnIdentifierFound:=Input.OnIdentifierFound;
  IdentifierTool:=Input.IdentifierTool;
  if FoundProc<>Input.FoundProc then begin
    // clear current FoundProc
    if FoundProc<>nil then
      ClearFoundProc;
    // use saved FoundProc
    FoundProc:=Input.FoundProc;
    // free all FoundProcs, that were saved later
    if (FoundProc<>nil) then begin
      FreeFoundProc(FoundProc^.Next,true);
      if FreeInput then begin
        Input.FoundProc:=nil;
        RemoveFoundProcFromList(FoundProc);
      end;
    end;
  end;
end;

procedure TFindDeclarationParams.ClearResult(CopyCacheFlags: boolean);
begin
  NewPos.Code:=nil;
  NewPos.X:=-1;
  NewPos.Y:=-1;
  NewTopLine:=-1;
  NewNode:=nil;
  NewCleanPos:=-1;
  NewCodeTool:=nil;
  NewFlags:=[];
  if CopyCacheFlags and (fdfDoNotCache in Flags) then
    Include(NewFlags,fodDoNotCache);
end;

procedure TFindDeclarationParams.SetResult(const AFindContext: TFindContext);
begin
  ClearResult(true);
  NewCodeTool:=AFindContext.Tool;
  NewNode:=AFindContext.Node;
end;

procedure TFindDeclarationParams.SetResult(ANewCodeTool: TFindDeclarationTool;
  ANewNode: TCodeTreeNode);
begin
  ClearResult(true);
  NewCodeTool:=ANewCodeTool;
  NewNode:=ANewNode;
  {$IFDEF CheckNodeTool}if NewCodeTool<>nil then NewCodeTool.CheckNodeTool(NewNode);{$ENDIF}
end;

procedure TFindDeclarationParams.SetResult(ANewCodeTool: TFindDeclarationTool;
  ANewNode: TCodeTreeNode; ANewCleanPos: integer);
begin
  ClearResult(true);
  NewCodeTool:=ANewCodeTool;
  NewNode:=ANewNode;
  NewCleanPos:=ANewCleanPos;
  {$IFDEF CheckNodeTool}if NewCodeTool<>nil then NewCodeTool.CheckNodeTool(NewNode);{$ENDIF}
end;

procedure TFindDeclarationParams.ConvertResultCleanPosToCaretPos;
begin
  NewPos.Code:=nil;
  if NewCodeTool<>nil then begin
    if (NewCleanPos>=1) then
      NewCodeTool.CleanPosToCaretAndTopLine(NewCleanPos,NewPos,NewTopLine)
    else if (NewNode<>nil) then
      NewCodeTool.CleanPosToCaretAndTopLine(NewNode.StartPos,NewPos,NewTopLine);
  end;
end;

procedure TFindDeclarationParams.ClearInput;
begin
  Flags:=[];
  Identifier:=nil;
  ContextNode:=nil;
  OnIdentifierFound:=nil;
  IdentifierTool:=nil;
end;

procedure TFindDeclarationParams.WriteDebugReport;
begin
  DebugLn('TFindDeclarationParams.WriteDebugReport Self=',DbgS(Self));

  // input parameters:
  DebugLn(' Flags=',dbgs(Flags));
  DebugLn(' Identifier=',GetIdentifier(Identifier));
  if ContextNode<>nil then
    DebugLn(' ContextNode=',ContextNode.DescAsString)
  else
    DebugLn(' ContextNode=nil');
  if OnIdentifierFound<>nil then
    DebugLn(' OnIdentifierFound=',TFindDeclarationTool(TMethod(OnIdentifierFound).Data).MainFilename);
  if IdentifierTool<>nil then
    DebugLn(' IdentifierTool=',IdentifierTool.MainFilename)
  else
    DebugLn(' IdentifierTool=nil');
  if FoundProc<>nil then begin
    if FoundProc^.Context.Node<>nil then
      DebugLn(' FoundProc=',FoundProc^.Context.Tool.CleanPosToStr(FoundProc^.Context.Node.StartPos,true))
    else
      DebugLn(' FoundProc<>nil');
  end;

  // global params
  if OnTopLvlIdentifierFound<>nil then
    DebugLn(' OnTopLvlIdentifierFound=',TFindDeclarationTool(TMethod(OnTopLvlIdentifierFound).Code).MainFilename);

  // results:
  if NewNode<>nil then
    DebugLn(' NewNode=',NewNode.DescAsString)
  else
    DebugLn(' NewNode=nil');
  DebugLn(' NewCleanPos=',dbgs(NewCleanPos));
  if NewCodeTool<>nil then begin
    DebugLn(' NewCodeTool=',NewCodeTool.MainFilename,' at ',NewCodeTool.CleanPosToStr(NewCleanPos,false))
  end else begin
    DebugLn([' NewCodeTool=nil NewCleanPos=',NewCleanPos]);
  end;
  if NewPos.Code<>nil then
    DebugLn([' NewPos=',NewPos.Code.Filename,' x=',NewPos.X,' y=',NewPos.Y,' topline=',NewTopLine])
  else
    DebugLn(' NewPos=nil');
  DebugLn(' NewFlags=',dbgs(NewFlags));
  DebugLn('');
end;

function TFindDeclarationParams.GetHelpers(HelperKind: TFDHelpersListKind;
  CreateIfNotExists: boolean): TFDHelpersList;
begin
  if Parent<>nil then
    exit(Parent.GetHelpers(HelperKind,CreateIfNotExists));
  if FNeedHelpers then
    StartTool.FindHelpersInContext(Self); // beware: this calls GetHelpers
  Result:=FHelpers[HelperKind];
  if (Result=nil) and CreateIfNotExists then begin
    Result:=TFDHelpersList.Create(HelperKind);
    FHelpers[HelperKind]:=Result;
    FFreeHelpers[HelperKind]:=true;
    //if HelperKind=fdhlkDelphiHelper then
    //  debugln(['TFindDeclarationParams.GetHelpers Self=',dbgs(Pointer(Self)),' Helper=',dbgs(Pointer(FHelpers[HelperKind]))]);
  end;
end;

procedure TFindDeclarationParams.SetIdentifier(
  NewIdentifierTool: TFindDeclarationTool; NewIdentifier: PChar;
  NewOnIdentifierFound: TOnIdentifierFound);
begin
  Identifier:=NewIdentifier;
  IdentifierTool:=NewIdentifierTool;
  OnIdentifierFound:=NewOnIdentifierFound;
  ClearFoundProc;
end;

procedure TFindDeclarationParams.SetFoundProc(
  const ProcContext: TFindContext);
begin
  //DebugLn(['TFindDeclarationParams.SetFirstFoundProc Old=',dbgs(FoundProc)]);
  if FoundProc<>nil then
    ClearFoundProc;
  New(FoundProc);
  //DebugLn(['TFindDeclarationParams.SetFirstFoundProc New=',dbgs(FoundProc)]);
  FillChar(FoundProc^,SizeOf(TFoundProc),0);
  FoundProc^.Context:=ProcContext;
end;

procedure TFindDeclarationParams.SetGenericParamValues(
  SpecializeParamsTool: TFindDeclarationTool;
  SpecializeNode: TCodeTreeNode);
begin
  GenParams.ParamValuesTool := SpecializeParamsTool;
  GenParams.SpecializeParamsNode := SpecializeNode.FirstChild.NextBrother;
end;

procedure TFindDeclarationParams.UpdateGenericParamMapping(SpecializeParamsTool: TFindDeclarationTool;
  SpecializeParamsNode: TCodeTreeNode; GenericParamsNode: TCodeTreeNode);

  procedure ForwardParamMapping;
  var
    lGenericParamNode,
    lSpecializeParamNode,
    lGenericParamValueNode: TCodeTreeNode;
    lFirstMapping,
    lMapping,
    lLoopMapping: TGenericParamValueMapping;
    lFound: Boolean;
  begin
    lFirstMapping := nil;
    lMapping := nil;
    // GenericParams: GObject1<V1, V2> = class(GObject2<V2, V1>)
    //                         ^^^^^^
    // SpecializeParams: GObject1<V1, V2> = class(GObject2<V2, V1>)
    //                                                     ^^^^^^
    if GenParamValueMappings.FirstParamValueMapping = nil then begin
      // first mapping: values from GenParamValueMappings.SpecializeParamsNode
      lSpecializeParamNode := SpecializeParamsNode.FirstChild;
      while lSpecializeParamNode <> nil do begin
        //find generic param / generic param value
        lGenericParamNode := GenericParamsNode.FirstChild;
        lGenericParamValueNode := GenParamValueMappings.SpecializeParamsNode.FirstChild;
        lFound := false;
        while (lGenericParamNode <> nil)
        and (lGenericParamValueNode <> nil) do begin
          if SpecializeParamsTool.CompareSrcIdentifiers(lSpecializeParamNode.StartPos, lGenericParamNode.StartPos) then begin
            // found generic param
            lMapping := TGenericParamValueMapping.Create(lMapping, lSpecializeParamNode, lGenericParamValueNode);
            if lFirstMapping = nil then
              lFirstMapping := lMapping;
            lFound := true;
            break;
          end;
          lGenericParamNode := lGenericParamNode.NextBrother;
          lGenericParamValueNode := lGenericParamValueNode.NextBrother;
        end;
        if not lFound then begin

        end;
        lSpecializeParamNode := lSpecializeParamNode.NextBrother;
      end;
      GenParamValueMappings.FirstParamValueMapping := lFirstMapping;
      GenParamValueMappings.SpecializeValuesTool := GenParamValueMappings.SpecializeParamsTool;
    end else begin
      // further mapping: values from GenParamValueMappings.FirstParamValueMapping
      lSpecializeParamNode := SpecializeParamsNode.FirstChild;
      while lSpecializeParamNode <> nil do begin
        //find generic param / generic param value
        lLoopMapping := GenParamValueMappings.FirstParamValueMapping;
        lGenericParamNode := GenericParamsNode.FirstChild;
        lFound := false;
        while (lLoopMapping <> nil) do begin
          lGenericParamValueNode := lLoopMapping.SpecializeValueNode;
          if SpecializeParamsTool.CompareSrcIdentifiers(lSpecializeParamNode.StartPos, lGenericParamNode.StartPos) then begin
            // found generic param
            lMapping := TGenericParamValueMapping.Create(lMapping, lSpecializeParamNode, lGenericParamValueNode);
            if lFirstMapping = nil then
              lFirstMapping := lMapping;
            lFound := true;
            break;
          end;
          lGenericParamNode := lGenericParamNode.NextBrother;
          lLoopMapping := lLoopMapping.NextBrother;
        end;
        if not lFound then begin

        end;
        lSpecializeParamNode := lSpecializeParamNode.NextBrother;
      end;
      GenParamValueMappings.FirstParamValueMapping.Free;
      GenParamValueMappings.FirstParamValueMapping := lFirstMapping;
    end;
  end;

begin
  if Parent <> nil then begin
    Parent.UpdateGenericParamMapping(SpecializeParamsTool, SpecializeParamsNode, GenericParamsNode);
    exit;
  end;
  if (GenericParamsNode <> nil)
  and (GenParamValueMappings.SpecializeParamsNode <> nil) then
    ForwardParamMapping;
  GenParamValueMappings.SpecializeParamsTool := SpecializeParamsTool;
  GenParamValueMappings.SpecializeParamsNode := SpecializeParamsNode;
end;

procedure TFindDeclarationParams.UpdateContexWithGenParamValue(var SpecializeParamContext: TFindContext);
var
  lMapping: TGenericParamValueMapping;
  lPNode, lVNode: TCodeTreeNode;
  lPTool, lVTool: TFindDeclarationTool;
begin
  if Assigned(Parent) then begin
    Parent.UpdateContexWithGenParamValue(SpecializeParamContext);
    exit;
  end;
  lMapping := GenParamValueMappings.FirstParamValueMapping;
  while lMapping <> nil do begin
    lPNode := lMapping.GenericParamNode;
    lPTool := GenParamValueMappings.SpecializeParamsTool;
    lVNode := lMapping.SpecializeValueNode;
    lVTool := GenParamValueMappings.SpecializeValuesTool;
    if SpecializeParamContext.Tool.CompareSrcIdentifiers(SpecializeParamContext.Node.StartPos, @lPTool.Src[lPNode.StartPos]) then begin
      SpecializeParamContext.Node := lVNode;
      SpecializeParamContext.Tool := lVTool;
      exit;
    end;
    lMapping := lMapping.NextBrother;
  end;
end;

function TFindDeclarationParams.FindGenericParamType: Boolean;
var
  i, n: integer;
  GenParamType: TCodeTreeNode;
begin
  // NewCodeTool, NewNode=GenericParamType
  if not Assigned(NewCodeTool) or not Assigned(NewNode)
  or not Assigned(GenParams.ParamValuesTool)
  or not Assigned(GenParams.SpecializeParamsNode) then exit(false);
  n:=0;
  GenParamType:=NewNode;
  while GenParamType<>nil do begin
    GenParamType:=GenParamType.PriorBrother;
    inc(n);
  end;
  with GenParams.ParamValuesTool do begin
    MoveCursorToNodeStart(GenParams.SpecializeParamsNode);
    ReadNextAtom;
    // maybe all this syntax check is redundant
    if not AtomIsChar('<') then
      RaiseExceptionFmt(20170421200701,ctsStrExpectedButAtomFound,['<']);
    ReadNextAtom;
    if CurPos.Flag<>cafWord then
      RaiseExceptionFmt(20170421200703,ctsIdentExpectedButAtomFound,[GetAtom]);
    for i:=2 to n do begin
      ReadNextAtom;
      if AtomIsChar('>') then
        RaiseException(20170421200705,ctsNotEnoughGenParams);
      if not AtomIsChar(',') then
        RaiseExceptionFmt(20170421200707,ctsStrExpectedButAtomFound,['>']);
      ReadNextAtom;
      if CurPos.Flag<>cafWord then
        RaiseExceptionFmt(20170421200710,ctsIdentExpectedButAtomFound,[GetAtom]);
    end;
    Identifier:=@Src[CurPos.StartPos];
    IdentifierTool:=GenParams.ParamValuesTool;
    ContextNode:=GenParams.SpecializeParamsNode;
    Result:=FindIdentifierInContext(Self);
  end;
end;

procedure TFindDeclarationParams.AddOperandPart(aPart: string);
begin
  FExtractedOperand := FExtractedOperand + aPart;
end;

procedure TFindDeclarationParams.ChangeFoundProc(
  const ProcContext: TFindContext;
  ProcCompatibility: TTypeCompatibility;
  ParamCompatibilityList: TTypeCompatibilityList);
begin
  FoundProc^.Context:=ProcContext;
  FoundProc^.ProcCompatibility:=ProcCompatibility;
  if (FoundProc^.ParamCompatibilityList<>ParamCompatibilityList) then begin
    //DebugLn(['TFindDeclarationParams.ChangeFoundProc Old ParamCompatibilityList=',dbgs(FoundProc^.ParamCompatibilityList)]);
    if (FoundProc^.ParamCompatibilityList<>nil) then
      FreeMem(FoundProc^.ParamCompatibilityList);
    FoundProc^.ParamCompatibilityList:=ParamCompatibilityList;
    //DebugLn(['TFindDeclarationParams.ChangeFoundProc New ParamCompatibilityList=',dbgs(FoundProc^.ParamCompatibilityList)]);
  end;
end;

function TFindDeclarationParams.IsFoundProcFinal: boolean;
begin
  Result:=(FoundProc=nil)
       or (FoundProc^.CacheValid and (FoundProc^.ProcCompatibility=tcExact));
end;

procedure TFindDeclarationParams.PrettifyResult;
begin
  // adjust result for nicer position
  if (NewNode<>nil) then begin
    {$IFDEF CheckNodeTool}
    if NewCodeTool<>nil then
      NewCodeTool.CheckNodeTool(NewNode);
    {$ENDIF}
    case NewNode.Desc of
    ctnProcedure:
      if (NewNode.FirstChild<>nil)
      and (NewNode.FirstChild.Desc=ctnProcedureHead) then begin
        // Instead of jumping to the procedure keyword,
        // jump to the procedure name
        NewNode:=NewNode.FirstChild;
        NewCleanPos:=NewNode.StartPos;
      end;
    ctnGenericType:
      if (NewNode.FirstChild<>nil) then begin
        // Instead of jumping to the generic keyword,
        // jump to the name
        NewNode:=NewNode.FirstChild;
        NewCleanPos:=NewNode.StartPos;
      end;
    ctnProperty:
      // jump to the name of the property
      if NewCodeTool.MoveCursorToPropName(NewNode) then
        NewCleanPos:=NewCodeTool.CurPos.StartPos;
    end;
  end;
end;

procedure TFindDeclarationParams.SetResult(
  NodeCacheEntry: PCodeTreeNodeCacheEntry);
begin
  ClearResult(true);
  NewCodeTool:=TFindDeclarationTool(NodeCacheEntry^.NewTool);
  NewNode:=NodeCacheEntry^.NewNode;
  NewCleanPos:=NodeCacheEntry^.NewCleanPos;
end;


{ TExprTypeList }

destructor TExprTypeList.Destroy;
begin
  if Items<>nil then begin
    FreeMem(Items);
    Freemem(AliasTypes);
  end;
end;

function TExprTypeList.AsString: string;
var i: integer;
begin
  Result:='';
  for i:=0 to Count-1 do begin
    Result:=Result+'{'+IntToStr(i)+'/'+IntToStr(Count)+':'+ExprTypeToString(Items[i])+'}'+LineEnding;
  end;
end;

function TExprTypeList.CalcMemSize: PtrUInt;
begin
  Result:=PtrUInt(InstanceSize)
    +PtrUInt(FCapacity)*SizeOf(TExpressionType);
end;

procedure TExprTypeList.SetCapacity(const AValue: integer);
var NewSize, NewAliasSize: integer;
begin
  if FCapacity=AValue then exit;
  FCapacity:=AValue;
  NewSize:=FCapacity*SizeOf(TExpressionType);
  NewAliasSize:=FCapacity*SizeOf(TFindContext);
  if Items=nil then begin
    GetMem(Items,NewSize);
    GetMem(AliasTypes,NewAliasSize);
  end
  else begin
    ReAllocMem(Items,NewSize);
    ReAllocMem(AliasTypes,NewAliasSize);
  end;
  if Count>Capacity then Count:=Capacity;
end;

procedure TExprTypeList.Grow;
begin
  Capacity:=Capacity*2+4;
end;

procedure TExprTypeList.Add(const ExprType: TExpressionType);
begin
  inc(Count);
  if Count>Capacity then Grow;
  Items[Count-1]:=ExprType;
  AliasTypes[Count-1]:=CleanFindContext;
end;

procedure TExprTypeList.Add(const ExprType: TExpressionType;
  const AliasType: TFindContext);
begin
  inc(Count);
  if Count>Capacity then Grow;
  Items[Count-1]:=ExprType;
  AliasTypes[Count-1]:=AliasType;
end;

procedure TExprTypeList.AddFirst(const ExprType: TExpressionType);
begin
  inc(Count);
  if Count>Capacity then Grow;
  if Count>1 then
    Move(Items[0],Items[1],SizeOf(TExpressionType)*(Count-1));
  Items[0]:=ExprType;
end;


finalization
  FreeAndNil(FBooleanTypesOrderList);
  FreeAndNil(FIntegerTypesOrderList);
  FreeAndNil(FRealTypesOrderList);
  FreeAndNil(FStringTypesOrderList);

end.


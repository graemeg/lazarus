{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code

The Original Code is Tokens.pas, released June 2003.
The Initial Developer of the Original Code is Anthony Steele.
Portions created by Anthony Steele are Copyright (C) 1999-2008 Anthony Steele.
All Rights Reserved.
Contributor(s): Anthony Steele, Adem Baba

The contents of this file are subject to the Mozilla Public License Version 1.1
(the "License"). you may not use this file except in compliance with the License.
You may obtain a copy of the License at http://www.mozilla.org/NPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied.
See the License for the specific language governing rights and limitations
under the License.

Alternatively, the contents of this file may be used under the terms of
the GNU General Public License Version 2 or later (the "GPL") 
See http://www.gnu.org/licenses/gpl.html
------------------------------------------------------------------------------*)
{*)}
unit Tokens;

{
  Enumerates the kinds of words and symbols found in a delphi program

  If you knew the code for Jcf 0.x series,
  then this now unifies the enumerations for TTokenType and TWordType

  There were 149 words and about 22 tokens
  So there are now over 160 token types (some were removed on joining)

  will not add in the parse tree node types into this enum
  as this would push the total over 256
  and you cannot have sets over enums with more than 256 elements
  I get a lot of value from sets over these enums

  there will still be space for new keywords later without reaching that limit

  When these are textual tokens,
  the enum item name is the token prefixed with 'tt'
  ie 'while' -> ttWhile
}

{$I JcfGlobal.inc}

interface

uses
  SysUtils;

type
  TWordType = (wtNotAWord,
    wtReservedWord, wtReservedWordDirective, wtBuiltInConstant, wtBuiltInType,
    wtIdentifier, wtOperator);

  TWordTypeSet = set of TWordType;

  TTokenType =
    (
    // errors -  should only occur when input is bad, or parser is in error
    ttPunctuation, // non-aphanum characters - a catch-all category for other symbols
    ttUnknown, // default category used for unrecognised input

    // spacing
    ttReturn,     // CR & LF chars
    ttWhiteSpace, // spaces & tabs
    ttComment,    // one of these
    ttConditionalCompilationRemoved,


    ttNumber,        // a numeric constant
    ttQuotedLiteralString, // 'This is a string'
    ttSemicolon,     // ;
    ttColon,         // :
    ttComma,         // ,
    ttOpenBracket,       // (
    ttCloseBracket,      // )
    ttOpenSquareBracket, // [
    ttCloseSquareBracket,// ]
    ttDot,       // .
    ttHash,      // #
    ttDoubleDot, // '..' as in '[1 .. 2]'
    ttAssign,    // :=
    ttAmpersand, // '&' is used in Asm

    ttIdentifier, // a user-defined name for a var, type, unit, etc

    { built-in keywords }
    ttArray,
    ttAsm,
    ttBegin,
    ttCase,
    ttClass,
    ttConst,
    ttConstref,
    ttContains,
    ttConstructor,
    ttDestructor,
    ttDispinterface,
    ttDo,
    ttDownto,
    ttElse,
    ttEnd,
    ttEnumerator,
    ttExcept,
    ttExports,
    ttFile,
    ttFinalization,
    ttFinally,
    ttFor,
    ttFunction,
    ttGoto,
    ttIf,
    ttImplementation,
    ttInherited,
    ttInitialization,
    ttInline,
    ttInterface,
    ttLabel,
    ttLibrary,
    ttObject,
    ttOf,
    ttOperator,
    ttOut,
    ttOtherwise,
    ttPackage,
    ttPacked,
    ttProcedure,
    ttProgram,
    ttProperty,
    ttRaise,
    ttRecord,
    ttRepeat,
    ttRequires,
    ttResourcestring,
    ttSet,
    ttSpecialize,
    ttThen,
    ttThreadvar,
    ttTo,
    ttTry,
    ttType,
    ttUnit,
    ttUntil,
    ttUses,
    ttVar,
    ttWhile,
    ttWith,
    ttAt,
    ttOn,

    { reserved words that are directives }
    ttAbsolute,
    ttExternal,
    ttPascal,
    ttSafecall,
    ttAbstract,
    ttFar,
    ttPrivate,
    ttStrict,
    ttStdcall,
    ttAssembler,
    ttForward,
    ttProtected,
    ttStored,
    ttAutomated,
    ttIndex,
    ttPublic,
    ttVirtual,
    ttCdecl,
    ttMessage,
    ttPublished,
    ttWrite,
    ttDefault,
    ttName,
    ttRead,
    ttWriteOnly,
    ttDispId,
    ttNear,
    ttHuge,
    ttReadOnly,
    ttDynamic,
    ttNodefault,
    ttRegister,
    ttExport,
    ttOverride,
    ttOverload,
    ttResident,
    ttLocal,
    ttImplements,
    ttReintroduce,
    ttGeneric,
    ttCVar,
    ttNostackframe,
    ttNested,
    ttVectorcall,
    // used in asm
    ttOffset,
    ttPtr,
    ttVmtOffset,
    ttDmtOffset,

    { Delphi 6 directives }
    ttDeprecated,
    ttPlatform,

    { delphi.net keywords and directives }
    ttHelper,
    ttStatic,
    ttSealed,
    ttFinal,
    ttAdd,
    ttRemove,
    ttUnsafe,
    ttVarArgs,

    { delphi 2009 }
    ttReference,

    { Additional Free Pascal directives }
    ttExperimental,
    ttUnimplemented,
    ttInterrupt,

    { built-in constants }
    ttNil,
    ttTrue,
    ttFalse,

    { built in types }
    ttBoolean,
    ttByteBool,
    ttWordBool,
    ttLongBool,
    ttInteger,
    ttCardinal,
    ttShortint,
    ttSmallint,
    ttLongint,
    ttInt64,
    ttByte,
    ttWord,
    ttLongword,
    ttChar,
    ttWidechar,
    ttString,
    ttAnsiString,
    ttWidestring,
    ttPchar,
    ttShortString,
    ttPShortString,
    ttAnsiChar,
    ttPAnsiChar,
    ttPWideChar,
    ttUnicodeChar,
    ttUnicodeString,
    ttPUnicodeChar,
    ttUtf8String,
    ttUtf16String,
    ttRawByteString,
    ttPByte,
    ttSingle,
    ttDouble,
    ttExtended,
    ttReal,
    ttReal48,
    ttComp,
    ttCurrency,
    ttNativeInt,
    ttNativeUInt,
    ttInt8,
    ttInt16,
    ttInt32,
    ttUInt8,
    ttUInt16,
    ttUInt32,
    ttUInt64,

    ttVariant,
    ttOleVariant,

    { operators that are words not symbols }
    ttAnd,
    ttAs,
    ttDiv,
    ttIn,
    ttIs,
    ttMod,
    ttNot,
    ttOr,
    ttShl,
    ttShr,
    ttXor,

    // symbol operators
    ttAtSign,
    ttHat,
    ttTimes,
    ttFloatDiv,
    ttExponent,
    ttPlus,
    ttMinus,
    ttEquals,
    ttGreaterThan,
    ttLessThan,
    ttGreaterThanOrEqual,
    ttLessThanOrEqual,
    ttNotEqual,
    ttSetSymDif,
    ttBackSlash, { legal in char literals }

    // FreePascal c-style operators
    ttPlusAssign,     // +=
    ttMinusAssign,    // -=
    ttTimesAssign,    // *=
    ttFloatDivAssign, // /=
    ttShl_ll,         // <<
    ttShr_gg          // >>
    );

  TTokenTypeSet = set of TTokenType;

const
  TextualWordTypes: TWordTypeSet =
    [wtReservedWord, wtReservedWordDirective,
    wtBuiltInConstant, wtOperator, wtBuiltInType, wtIdentifier];

  // identifiers can use these word categories
  IdentifierTypes: TWordTypeSet = [wtReservedWordDirective,
    wtBuiltInType, wtBuiltInConstant, wtIdentifier];

  // a literal string must start with ', # or ^
  LiteralStringStarters: TTokenTypeSet = [ttQuotedLiteralString, ttHat, ttHash];

  { all tokens spelled with a-z }
  TextualTokens: TTokenTypeSet   = [ttIdentifier .. ttXor];
  IdentiferTokens: TTokenTypeSet = [ttIdentifier .. ttXor];

  { same as above, with numbers added }
  TextOrNumberTokens: TTokenTypeSet = [ttNumber, ttIdentifier .. ttXor];

  BracketTokens: TTokenTypeSet =
    [ttOpenBracket, ttCloseBracket, ttOpenSquareBracket, ttCloseSquareBracket];
  OpenBrackets: TTokenTypeSet  = [ttOpenBracket, ttOpenSquareBracket];
  CloseBrackets: TTokenTypeSet = [ttCloseBracket, ttCloseSquareBracket];


  NotSolidTokens: TTokenTypeSet =
    [ttWhiteSpace, ttComment, ttReturn, ttConditionalCompilationRemoved];

  { procedure can have local declarations of vars, const and yes, types }
  Declarations: TTokenTypeSet =
    [ttConst, ttResourceString, ttVar, ttThreadVar, ttType, ttLabel, ttExports];

  ParamTypes: TTokenTypeSet = [ttVar, ttConst, ttConstref, ttOut];

  BlockOutdentWords: TTokenTypeSet =
    [ttVar, ttThreadVar, ttConst, ttResourceString, ttType, ttLabel,
    ttBegin, ttEnd, ttTry, ttFinally, ttExcept,
    ttWhile, ttFor, ttRepeat, ttUntil, ttWith,
    ttAsm, ttCase, ttInitialization, ttFinalization];

  PropertyDirectives: TTokenTypeSet =
    { the basics }
    [ttRead, ttWrite,
    { the advanced stuff  }
    ttStored, ttDefault, ttNoDefault, ttImplements,
    { for COM interface properties }
    ttReadOnly, ttWriteOnly, ttDispId,
    // hints
    ttDeprecated, ttLibrary, ttPlatform,
    // free pascal hints
    ttExperimental, ttUnimplemented,

    // Delphi.Net
    ttAdd, ttRemove
    ];

  ExportDirectives: TTokenTypeSet = [ttIndex, ttName];

  VariableDirectives: TTokenTypeSet = [ttAbsolute, ttDeprecated, ttLibrary, ttPlatform,
                                       ttExperimental, ttUnimplemented, ttCVar];

  ClassVisibility: TTokenTypeSet =
    [ttPrivate, ttProtected, ttPublic, ttPublished, ttAutomated];

  ProcedureDirectives: TTokenTypeSet = [ttExternal, ttPascal, ttSafecall, ttAbstract,
    ttFar, ttStdcall, ttAssembler, ttInline, ttForward,
    ttVirtual, ttCdecl, ttMessage, ttName, ttRegister, ttDispId,
    ttNear, ttDynamic, ttExport, ttOverride, ttResident, ttLocal,
    ttOverload, ttReintroduce,
    ttDeprecated, ttLibrary, ttPlatform, ttExperimental, ttUnimplemented,
    ttStatic, ttFinal, ttVarArgs, ttUnsafe, ttEnumerator, ttNostackframe, ttInterrupt,
    ttPublic, ttVectorcall,ttHuge];

  ClassDirectives: TTokenTypeSet =
    [ttPrivate, ttProtected, ttPublic, ttPublished, ttAutomated, ttStrict];
  HintDirectives: TTokenTypeSet  = [ttDeprecated, ttLibrary, ttPlatform, ttCVar,
                                    ttExperimental, ttUnimplemented, ttStatic];

  AllDirectives: TTokenTypeSet =
  [ttAbsolute, ttExternal, ttPascal, ttSafecall,
    ttAbstract, ttFar, ttPrivate, ttStdcall, ttAssembler, ttForward,
    ttProtected, ttStored, ttAutomated, ttIndex, ttPublic,
    ttVirtual, ttCdecl, ttMessage, ttPublished, ttWrite,
    ttDefault, ttName, ttRead, ttWriteOnly, ttDispId,
    ttNear, ttReadOnly, ttDynamic, ttNoDefault, ttRegister,
    ttExport, ttOverride, ttOverload, ttResident, ttLocal,
    ttImplements, ttReintroduce,
    ttLibrary, ttPlatform, ttStatic, ttFinal, ttVarArgs, ttCVar, ttVectorcall,ttHuge];

  ProcedureWords: TTokenTypeSet = [ttProcedure, ttFunction, ttConstructor, ttDestructor, ttOperator];

  StructuredTypeWords: TTokenTypeSet =
    [ttClass, ttObject, ttInterface, ttDispinterface, ttRecord];
  ObjectTypeWords: TTokenTypeSet     = [ttClass, ttObject, ttInterface, ttDispinterface];

  InterfaceWords: TTokenTypeSet = [ttInterface, ttDispinterface];

  ConstWords: TTokenTypeSet = [ttConst, ttResourceString];

  StructStatementWords: TTokenTypeSet = [ttBegin, ttAsm,
    ttIf, ttCase, ttRepeat, ttWhile, ttFor, ttWith, ttTry];

  VariantTypes: TTokenTypeSet = [ttVariant, ttOleVariant];

  Operators: TTokenTypeSet = [ttAnd .. ttSetSymDif, ttEnumerator];

  { these words are
  - operators
  - can be unary
  - have no alphabet chars in them }
  PossiblyUnarySymbolOperators: TTokenTypeSet = [ttAtSign, ttHat, ttPlus, ttMinus];

  RelationalOperators: TTokenTypeSet = [
    ttIn, ttIs, ttAs, ttGreaterThan,
    ttLessThan, ttGreaterThanOrEqual, ttLessThanOrEqual, ttEquals,
    ttNotEqual, ttSetSymDif];

  AddOperators: TTokenTypeSet = [ttPlus, ttMinus, ttOr, ttXor];

  MulOperators: TTokenTypeSet = [ttTimes, ttFloatDiv, ttDiv, ttMod, ttAnd, ttShl, ttShr, ttExponent, ttShl_ll,ttShr_gg];

  SingleSpaceOperators = [
    // some unary operators
    ttNot,
    // all operators that are always binary
    ttAnd, ttAs, ttDiv, ttIn, ttIs, ttMod, ttOr, ttShl, ttShr, ttXor,
    ttTimes, ttFloatDiv, ttExponent, ttEquals, ttGreaterThan, ttLessThan,
    ttGreaterThanOrEqual, ttLessThanOrEqual, ttNotEqual, ttSetSymDif, ttShl_ll, ttShr_gg];

  StringWords: TTokenTypeSet = [ttString, ttAnsiString, ttWideString, ttShortString,
    ttUnicodeString, ttUtf8String, ttUtf16String, ttRawByteString];

  RealTypes: TTokenTypeSet =
    [ttReal48, ttReal, ttSingle, ttDouble, ttExtended, ttCurrency, ttComp];

  OrdTypes: TTokenTypeSet =
    [ttShortInt, ttSmallInt, ttInteger, ttByte,
    ttLongInt, ttInt64, ttWord,
    ttBoolean, ttByteBool, ttWordBool, ttLongBool,
    ttChar, ttWideChar, ttLongWord, ttPChar, ttCardinal, ttNativeInt, ttNativeUInt,
    ttInt8, ttInt16, ttInt32, ttUInt8, ttUInt16, ttUInt32, ttUInt64, ttAnsiChar,
    ttUnicodeChar, ttPAnsiChar, ttPUnicodeChar, ttPWideChar, ttPByte, ttPShortString];

  UsesWords: TTokenTypeSet = [ttUses, ttRequires, ttContains];

  BuiltInConstants: TTokenTypeSet = [ttNil, ttTrue, ttFalse];
  BuiltInTypes: TTokenTypeSet     = [ttBoolean .. ttOleVariant];

  AsmOffsets: TTokenTypeSet = [ttVmtOffset, ttDmtOffset];

  AssignmentDirectives: TTokenTypeSet = [ttAssign, ttPlusAssign, ttMinusAssign, ttTimesAssign, ttFloatDivAssign];

{ interpret a string as a token }
procedure TypeOfToken(const psWord: string; out peWordType: TWordType;
  out peToken: TTokenType); overload;
function TypeOfToken(const psWord: string): TTokenType; overload;
function WordTypeOfToken(const peTokenType: TTokenType): TWordType; overload;

{ back to the string for error message }
function TokenTypeToString(const peToken: TTokenType): string;

{ similarly for a token set }
function TokenTypesToString(const peTokens: TTokenTypeSet): string;


{ chars used to make the comment }
{ these} (* or these *) // or these
type
  TCommentStyle    = (eNotAComment, eDoubleSlash, eBracketStar,
    eCurlyBrace, eCompilerDirective);
  TCommentStyleSet = set of TCommentStyle;

const
  CURLY_COMMENTS: TCommentStyleSet = [eCurlyBrace, eCompilerDirective];


{ preprocessor symbols }
type
  TPreProcessorSymbolType = (ppNone,
    ppDefine, ppUndef,
    ppIfDef, ppIfNotDef, ppIfOpt, ppIfExpr, ppElseIf,
    ppElse, ppEndIf, ppIfEnd);

  TPreProcessorSymbolTypeSet = set of TPreProcessorSymbolType;

const
  PREPROC_BLOCK_END = [ppElseIf, ppElse, ppEndIf, ppIfEnd];

procedure GetPreprocessorSymbolData(const psSourceCode: String;
  var peSymbolType: TPreProcessorSymbolType; var psText: String);

function PreProcSymbolTypeToString(const peSymbolType: TPreProcessorSymbolType): string;
function PreProcSymbolTypeSetToString(
  const peSymbolTypes: TPreProcessorSymbolTypeSet): string;

implementation

uses
  { local }
  JcfStringUtils;

{ the majority of these tokens have a fixed textual representation
  e.g. ':=', 'if'.
  Those that don't include comments, numbers, literal strings and identifiers
  Recognising text as tokens is data driven, so here is the data
}

type
  TRTokenTextMap = record
    sToken: string;
    iLength: integer; // length of string above
    eWordType: TWordType;
    eToken: TTokenType;
  end;

const
  { the longest token 'resourcestring' = 14 chars  }
  LONGEST_KEYWORD_LEN = 14;

  { a value larger than the number of keywords,
    used as an initial size for the dynamic array }
  INITIAL_MAX_KEYWORDS = 230;

var
  { final number of keywords added }
  miKeyWordCount: integer;

  { the keyword data }
  mrKeywordTextMap: array of TRTokenTextMap;

  { Array is sorted by length -
    this indexes where in the array tokens of a particular length start }
  miKeywordLengthIndexes: array[1 .. LONGEST_KEYWORD_LEN + 1] of integer;

procedure AddKeyWord(psToken: string; const peWordType: TWordType;
  const peToken: TTokenType);
var
  liLength: integer;
begin
  { the UpperCase fn seems to be safe from locale -
    it works on chars a..z and we are not feeding it any accented chars   }
  psToken := Trim(UpperCase(psToken));

  liLength := Length(psToken);
  Assert(liLength <= LONGEST_KEYWORD_LEN,
    'Found a longer token: ' + psToken + ' length ' + IntToStr(liLength));

  mrKeywordTextMap[miKeyWordCount].sToken  := psToken;
  mrKeywordTextMap[miKeyWordCount].iLength := liLength;

  mrKeywordTextMap[miKeyWordCount].eWordType := peWordType;
  mrKeywordTextMap[miKeyWordCount].eToken    := peToken;

  Inc(miKeyWordCount);
  Assert(miKeyWordCount < INITIAL_MAX_KEYWORDS);
end;

procedure AddKeyWords;
begin
  {NOTES: Adding the keywords to a dynamic array adds negligible overhead but
  it is quite flexible as we can add stuff later. Array size is not fixed

  Plus, we will sort it so that all the searches will be faster. }


  SetLength(mrKeywordTextMap, INITIAL_MAX_KEYWORDS); {Something sufficiently large}
  miKeyWordCount := 0;

  // add all the data into the array

  AddKeyword(';', wtNotAWord, ttSemicolon);
  AddKeyword(':', wtNotAWord, ttColon);
  AddKeyword(',', wtNotAWord, ttComma);
  AddKeyword('(', wtNotAWord, ttOpenBracket);
  AddKeyword(')', wtNotAWord, ttCloseBracket);
  AddKeyword('[', wtNotAWord, ttOpenSquareBracket);
  AddKeyword(']', wtNotAWord, ttCloseSquareBracket);
  AddKeyword('..', wtNotAWord, ttDoubleDot);
  AddKeyword('.', wtNotAWord, ttDot);
  AddKeyword('#', wtNotAWord, ttHash);
  AddKeyword(':=', wtNotAWord, ttAssign);
  AddKeyword('&', wtNotAWord, ttAmpersand);

  { reserved words }
  AddKeyword('array', wtReservedWord, ttArray);
  AddKeyword('asm', wtReservedWord, ttAsm);
  AddKeyword('begin', wtReservedWord, ttBegin);
  AddKeyword('bitpacked', wtReservedWord, ttPacked);
  AddKeyword('case', wtReservedWord, ttCase);
  AddKeyword('class', wtReservedWord, ttClass);
  AddKeyword('const', wtReservedWord, ttConst);
  AddKeyword('constref', wtReservedWordDirective, ttConstref);
  AddKeyword('constructor', wtReservedWord, ttConstructor);

  AddKeyword('destructor', wtReservedWord, ttDestructor);
  AddKeyword('dispinterface', wtReservedWord, ttDispinterface);
  AddKeyword('do', wtReservedWord, ttDo);
  AddKeyword('downto', wtReservedWord, ttDownTo);
  AddKeyword('else', wtReservedWord, ttElse);
  AddKeyword('end', wtReservedWord, ttEnd);
  // 'enumerator' can be a valid identifier.
  //AddKeyword('enumerator', wtReservedWord, ttEnumerator);
  AddKeyword('except', wtReservedWord, ttExcept);
  AddKeyword('exports', wtReservedWord, ttExports);
  AddKeyword('file', wtReservedWord, ttFile);
  AddKeyword('finalization', wtReservedWord, ttFinalization);
  AddKeyword('finally', wtReservedWord, ttFinally);
  AddKeyword('for', wtReservedWord, ttFor);
  AddKeyword('function', wtReservedWord, ttFunction);
  AddKeyword('goto', wtReservedWord, ttGoto);
  AddKeyword('if', wtReservedWord, ttIf);
  AddKeyword('implementation', wtReservedWord, ttImplementation);
  AddKeyword('inherited', wtReservedWord, ttInherited);
  AddKeyword('initialization', wtReservedWord, ttInitialization);
  AddKeyword('inline', wtReservedWord, ttInline);
  AddKeyword('interface', wtReservedWord, ttInterface);
  AddKeyword('label', wtReservedWord, ttLabel);
  AddKeyword('library', wtReservedWord, ttLibrary);
  AddKeyword('object', wtReservedWord, ttObject);
  AddKeyword('of', wtReservedWord, ttOf);
  AddKeyword('operator', wtReservedWord, ttOperator);
  AddKeyword('out', wtReservedWordDirective, ttOut);
  AddKeyword('otherwise', wtReservedWord, ttOtherwise);
  AddKeyword('packed', wtReservedWord, ttPacked);
  AddKeyword('procedure', wtReservedWord, ttProcedure);
  AddKeyword('program', wtReservedWord, ttProgram);
  AddKeyword('property', wtReservedWord, ttProperty);
  AddKeyword('raise', wtReservedWord, ttRaise);
  AddKeyword('record', wtReservedWord, ttRecord);
  AddKeyword('repeat', wtReservedWord, ttRepeat);
  AddKeyword('resourcestring', wtReservedWord, ttResourceString);
  AddKeyword('set', wtReservedWord, ttSet);
  AddKeyword('specialize', wtReservedWord, ttSpecialize);
  AddKeyword('then', wtReservedWord, ttThen);
  AddKeyword('threadvar', wtReservedWord, ttThreadvar);
  AddKeyword('to', wtReservedWord, ttTo);
  AddKeyword('try', wtReservedWord, ttTry);
  AddKeyword('type', wtReservedWord, ttType);
  AddKeyword('unit', wtReservedWord, ttUnit);
  AddKeyword('until', wtReservedWord, ttUntil);
  AddKeyword('uses', wtReservedWord, ttUses);
  AddKeyword('var', wtReservedWord, ttVar);
  AddKeyword('while', wtReservedWord, ttWhile);
  AddKeyword('with', wtReservedWord, ttWith);

  { reseved words that must be parsed as directives because they can be identifier names }
  AddKeyword('at', wtReservedWordDirective, ttAt);
  AddKeyword('on', wtReservedWordDirective, ttOn);
  AddKeyword('package', wtReservedWordDirective, ttPackage);
  AddKeyword('contains', wtReservedWordDirective, ttContains);
  AddKeyword('requires', wtReservedWordDirective, ttRequires);

  { reseved words that are directives }
  AddKeyword('absolute', wtReservedWordDirective, ttAbsolute);
  AddKeyword('external', wtReservedWordDirective, ttExternal);
  AddKeyword('pascal', wtReservedWordDirective, ttPascal);
  AddKeyword('safecall', wtReservedWordDirective, ttSafecall);
  AddKeyword('abstract', wtReservedWordDirective, ttAbstract);
  AddKeyword('far', wtReservedWordDirective, ttFar);
  AddKeyword('private', wtReservedWordDirective, ttPrivate);
  AddKeyword('strict', wtReservedWordDirective, ttStrict);
  AddKeyword('stdcall', wtReservedWordDirective, ttStdCall);
  AddKeyword('assembler', wtReservedWordDirective, ttAssembler);
  AddKeyword('forward', wtReservedWordDirective, ttForward);
  AddKeyword('protected', wtReservedWordDirective, ttProtected);
  AddKeyword('stored', wtReservedWordDirective, ttStored);
  AddKeyword('automated', wtReservedWordDirective, ttAutomated);
  AddKeyword('index', wtReservedWordDirective, ttIndex);
  AddKeyword('public', wtReservedWordDirective, ttPublic);
  AddKeyword('virtual', wtReservedWordDirective, ttVirtual);
  AddKeyword('cdecl', wtReservedWordDirective, ttCdecl);
  AddKeyword('message', wtReservedWordDirective, ttMessage);
  AddKeyword('published', wtReservedWordDirective, ttPublished);
  AddKeyword('write', wtReservedWordDirective, ttWrite);
  AddKeyword('default', wtReservedWordDirective, ttDefault);
  AddKeyword('name', wtReservedWordDirective, ttName);
  AddKeyword('read', wtReservedWordDirective, ttRead);
  AddKeyword('writeonly', wtReservedWordDirective, ttWriteOnly);
  AddKeyword('dispid', wtReservedWordDirective, ttDispId);
  AddKeyword('near', wtReservedWordDirective, ttNear);
  AddKeyword('readonly', wtReservedWordDirective, ttReadOnly);
  AddKeyword('dynamic', wtReservedWordDirective, ttDynamic);
  AddKeyword('nodefault', wtReservedWordDirective, ttNoDefault);
  AddKeyword('register', wtReservedWordDirective, ttRegister);
  AddKeyword('export', wtReservedWordDirective, ttExport);
  AddKeyword('override', wtReservedWordDirective, ttOverride);
  AddKeyword('overload', wtReservedWordDirective, ttOverload);
  AddKeyword('resident', wtReservedWordDirective, ttResident);
  AddKeyword('local', wtReservedWordDirective, ttLocal);
  AddKeyword('generic', wtReservedWordDirective, ttGeneric);
  AddKeyword('vectorcall', wtReservedWordDirective, ttVectorcall);

  AddKeyword('implements', wtReservedWordDirective, ttImplements);
  AddKeyword('reintroduce', wtReservedWordDirective, ttReintroduce);

  AddKeyword('cvar', wtReservedWordDirective, ttCVar);
  AddKeyword('nostackframe', wtReservedWordDirective, ttNostackframe);
  AddKeyword('nested', wtReservedWordDirective, ttNested);

  // asm
  AddKeyword('offset', wtReservedWordDirective, ttOffset);
  AddKeyword('ptr', wtReservedWordDirective, ttPtr);
  AddKeyword('vmtoffset', wtReservedWordDirective, ttVmtOffset);
  AddKeyword('dmtoffset', wtReservedWordDirective, ttDmtOffset);

  { D6 directives }
  AddKeyword('deprecated', wtReservedWordDirective, ttDeprecated);
  AddKeyword('platform', wtReservedWordDirective, ttPlatform);

  { delphi.net directives}
  AddKeyword('helper', wtReservedWordDirective, ttHelper);
  AddKeyword('sealed', wtReservedWordDirective, ttSealed);
  AddKeyword('static', wtReservedWordDirective, ttStatic);
  AddKeyword('final', wtReservedWordDirective, ttFinal);
  
  AddKeyword('add', wtReservedWordDirective, ttAdd);
  AddKeyword('remove', wtReservedWordDirective, ttRemove);
  AddKeyword('unsafe', wtReservedWordDirective, ttUnsafe);
  AddKeyword('varargs', wtReservedWordDirective, ttVarArgs);

  { delphi 2009 }
    AddKeyword('reference', wtReservedWordDirective, ttReference);

  { Additional Free Pascal directives }
  AddKeyword('experimental', wtReservedWordDirective, ttExperimental);
  AddKeyword('unimplemented', wtReservedWordDirective, ttUnimplemented);
  AddKeyword('interrupt', wtReservedWordDirective, ttInterrupt);

  { operators that are words not symbols }
  AddKeyword('and', wtOperator, ttAnd);
  AddKeyword('as', wtOperator, ttAs);
  AddKeyword('div', wtOperator, ttDiv);
  AddKeyword('in', wtOperator, ttIn);
  AddKeyword('is', wtOperator, ttIs);
  AddKeyword('mod', wtOperator, ttMod);
  AddKeyword('not', wtOperator, ttNot);
  AddKeyword('or', wtOperator, ttOr);
  AddKeyword('shl', wtOperator, ttShl);
  AddKeyword('shr', wtOperator, ttShr);
  AddKeyword('xor', wtOperator, ttXor);

  { built-in constants }
  AddKeyword('nil', wtBuiltInConstant, ttNil);
  AddKeyword('true', wtBuiltInConstant, ttTrue);
  AddKeyword('false', wtBuiltInConstant, ttFalse);

  { built-in types }
  AddKeyword('boolean', wtBuiltInType, ttBoolean);
  AddKeyword('ByteBool', wtBuiltInType, ttByteBool);
  AddKeyword('WordBool', wtBuiltInType, ttWordBool);
  AddKeyword('LongBool', wtBuiltInType, ttLongBool);

  AddKeyword('integer', wtBuiltInType, ttInteger);
  AddKeyword('cardinal', wtBuiltInType, ttCardinal);
  AddKeyword('shortint', wtBuiltInType, ttShortInt);
  AddKeyword('smallint', wtBuiltInType, ttSmallInt);
  AddKeyword('longint', wtBuiltInType, ttLongInt);
  AddKeyword('int64', wtBuiltInType, ttInt64);
  AddKeyword('byte', wtBuiltInType, ttByte);
  AddKeyword('word', wtBuiltInType, ttWord);
  AddKeyword('longword', wtBuiltInType, ttLongWord);

  AddKeyword('char', wtBuiltInType, ttChar);
  AddKeyword('widechar', wtBuiltInType, ttWideChar);
  AddKeyword('string', wtBuiltInType, ttString);
  AddKeyword('ansistring', wtBuiltInType, ttAnsiString);
  AddKeyword('widestring', wtBuiltInType, ttWideString);
  AddKeyword('pChar', wtBuiltInType, ttPchar);

  AddKeyword('single', wtBuiltInType, ttSingle);
  AddKeyword('double', wtBuiltInType, ttDouble);
  AddKeyword('extended', wtBuiltInType, ttExtended);
  AddKeyword('real', wtBuiltInType, ttReal);
  AddKeyword('real48', wtBuiltInType, ttReal48);
  AddKeyword('comp', wtBuiltInType, ttComp);
  AddKeyword('currency', wtBuiltInType, ttCurrency);

  AddKeyword('variant', wtBuiltInType, ttVariant);
  AddKeyword('OleVariant', wtBuiltInType, ttOleVariant);

  { operators that are symbols }
  AddKeyword('@', wtOperator, ttAtSign);
  AddKeyword('^', wtOperator, ttHat);
  AddKeyword('*', wtOperator, ttTimes);
  AddKeyword('**', wtOperator, ttExponent); // in FreePascal
  AddKeyword('/', wtOperator, ttFloatDiv);
  AddKeyword('+', wtOperator, ttPlus);
  AddKeyword('-', wtOperator, ttMinus);
  AddKeyword('=', wtOperator, ttEquals);
  AddKeyword('>=', wtOperator, ttGreaterThanOrEqual);
  AddKeyword('<=', wtOperator, ttLessThanOrEqual);
  AddKeyword('<>', wtOperator, ttNotEqual);
  AddKeyword('><', wtOperator, ttSetSymDif);
  AddKeyword('<<', wtOperator, ttShl_ll);  // in FreePascal
  AddKeyword('>>', wtOperator, ttShr_gg);  // in FreePascal
  // these must come after the above as they are shorter
  AddKeyword('>', wtOperator, ttGreaterThan);
  AddKeyword('<', wtOperator, ttLessThan);
  AddKeyword('\', wtOperator, ttBackSlash);

  // FreePascal c-style operators
  AddKeyword('+=', wtNotAWord, ttPlusAssign);
  AddKeyword('-=', wtNotAWord, ttMinusAssign);
  AddKeyword('*=', wtNotAWord, ttTimesAssign);
  AddKeyword('/=', wtNotAWord, ttFloatDivAssign);

  AddKeyword('nativeint', wtBuiltInType, ttNativeInt);
  AddKeyword('nativeuint', wtBuiltInType, ttNativeUInt);
  AddKeyword('int8', wtBuiltInType, ttInt8);
  AddKeyword('int16', wtBuiltInType, ttInt16);
  AddKeyword('int32', wtBuiltInType, ttInt32);
  AddKeyword('uint8', wtBuiltInType, ttUInt8);
  AddKeyword('uint16', wtBuiltInType, ttUInt16);
  AddKeyword('uint32', wtBuiltInType, ttUInt32);
  AddKeyword('uint64', wtBuiltInType, ttUInt64);
  AddKeyword('shortstring', wtBuiltInType, ttShortString);
  AddKeyword('pshortstring', wtBuiltInType, ttPShortString);
  AddKeyword('ansichar', wtBuiltInType, ttAnsiChar);
  AddKeyword('pansichar', wtBuiltInType, ttPAnsiChar);
  AddKeyword('pwidechar', wtBuiltInType, ttPWideChar);
  AddKeyword('unicodechar', wtBuiltInType, ttUnicodeChar);
  AddKeyword('unicodestring', wtBuiltInType, ttUnicodeString);
  AddKeyword('punicodechar', wtBuiltInType, ttPUnicodeChar);
  AddKeyword('utf8string', wtBuiltInType, ttUtf8String);
  AddKeyword('utf16string', wtBuiltInType, ttUtf16String);
  AddKeyword('rawbytestring', wtBuiltInType, ttRawByteString);
  AddKeyword('pbyte', wtBuiltInType, ttPByte);
  AddKeyword('huge', wtReservedWordDirective, ttHuge);

  {Now that we know how many keywords were added,
    we can set the actual size of the array }
  SetLength(mrKeywordTextMap, miKeyWordCount);
end;

{ sort order for the keyword data array }
function KeyWordCompare(const prMap1, prMap2: TRTokenTextMap): integer;
var
  liIndex: integer;
begin
  { first sort by length }
  Result := prMap1.iLength - prMap2.iLength;
  if Result <> 0 then
    exit;

  { then for tokensof the same length: alphabetic, not localised }
  liIndex := 1;
  while (Result = 0) and (liIndex <= prMap1.iLength) do
  begin
    Result := Ord(prMap1.sToken[liIndex]) - Ord(prMap2.sToken[liIndex]);
    Inc(liIndex);
  end;
end;

procedure SortKeywords;
var
  liIndex:    integer;
  lrSwap:     TRTokenTextMap;
  lbDoneWork: boolean;
begin
  {We have a fairly small number of items, < 200.
    Bubble sort is good enough, if not the best here }

  lbDoneWork := True;
  while lbDoneWork do
  begin
    lbDoneWork := False;

    for liIndex := 0 to (miKeyWordCount - 2) do
    begin
      if KeyWordCompare(mrKeywordTextMap[Succ(liIndex)],
        mrKeywordTextMap[liIndex]) < 0 then
      begin
        { swap the items }
        lrSwap := mrKeywordTextMap[Succ(liIndex)];
        mrKeywordTextMap[Succ(liIndex)] := mrKeywordTextMap[liIndex];
        mrKeywordTextMap[liIndex] := lrSwap;

        // have made a swap. List was not sorted.
        lbDoneWork := True;
      end;
    end;
  end;
end;

procedure InitLengthOffestIndexes;
var
  liLoop, liLen: integer;
begin
  { init all indexes to a dummy value  }
  for liLoop := low(miKeywordLengthIndexes) to High(miKeywordLengthIndexes) do
    miKeywordLengthIndexes[liLoop] := -1;

  { the keywords are sorted firstly by length }
  for liLoop := 0 to Pred(miKeyWordCount) do
  begin
    liLen := mrKeywordTextMap[liLoop].iLength;

    { keywords of length liLen are found at index liLoop onwards }
    if miKeywordLengthIndexes[liLen] < 0 then
      miKeywordLengthIndexes[liLen] := liLoop;
  end;

  { init all remaining to past the last item }
  for liLoop := low(miKeywordLengthIndexes) to High(miKeywordLengthIndexes) do
    if miKeywordLengthIndexes[liLoop] < 0 then
      miKeywordLengthIndexes[liLoop] := miKeyWordCount;

end;


{ turn text to enum. Assumes data is sorted out and sorted }
procedure TypeOfToken(const psWord: string; out peWordType: TWordType;
  out peToken: TTokenType);
var
  liMapItemLoop:  integer;
  liCharIndex:    integer;
  liStart, liEnd: integer;
  liTokenLength:  integer;
  lbFoundItem:    boolean;
begin
  Assert(psWord <> '');

  { if its not found in the list, it is unknown }
  peWordType := wtNotAWord;
  peToken    := ttUnknown;

  // the token in should already be trimmed
  liTokenLength := Length(psWord);

  { pointless and dangerous to continue if the keyword is longer than any known }
  if liTokenLength > LONGEST_KEYWORD_LEN then
    exit;

  // where in the map do we find tokens of this length?
  liStart := miKeywordLengthIndexes[liTokenLength];
  // tokens of this length stop when the longer ones start :)
  liEnd   := miKeywordLengthIndexes[liTokenLength + 1] - 1;

  { of course the ultimate would be binary search not for-loop
    but it is questionable if that is needed
    seeing as the part of the list to be searched has already been greatly limited }
  for liMapItemLoop := liStart to liEnd do
  begin
    { 'a simplified version of Boyer-Moore comparison technique' }
    if (mrKeywordTextMap[liMapItemLoop].sToken[1] = UpCase(psWord[1])) and
      (mrKeywordTextMap[liMapItemLoop].sToken[liTokenLength] =
      UpCase(psWord[liTokenLength])) then
    begin
      lbFoundItem := True;
      liCharIndex := 2;
      {We have already checked the 2 ends of the string. Check the rest }
      while lbFoundItem and (liCharIndex < liTokenLength) do
      begin
        lbFoundItem := lbFoundItem and
          (mrKeywordTextMap[liMapItemLoop].sToken[liCharIndex] =
          UpCase(psWord[liCharIndex]));
        Inc(liCharIndex);
      end;

      if lbFoundItem then
      begin
        peWordType := mrKeywordTextMap[liMapItemLoop].eWordType;
        peToken    := mrKeywordTextMap[liMapItemLoop].eToken;
        break;
      end;

    end; { matched first and last and uppercase }

  end; { for loop through the array }
end;

function TypeOfToken(const psWord: string): TTokenType; overload;
var
  leWordType: TWordType;
begin
  TypeOfToken(psWord, leWordType, Result);
end;

function TokenTypeToString(const peToken: TTokenType): string;
var
  lbFound: boolean;
  liLoop:  integer;
begin
  lbFound := False;

  case peToken of
    ttPunctuation:
    begin
      Result  := 'Unknown punctuation';
      lbFound := True;
    end;
    ttUnknown:
    begin
      Result  := 'Unknown';
      lbFound := True;
    end;
    ttReturn:
    begin
      Result  := 'Return';
      lbFound := True;
    end;
    ttWhiteSpace:
    begin
      Result  := 'White space';
      lbFound := True;
    end;
    ttIdentifier:
    begin
      // identifier not in the list as it has no fixed text
      Result  := 'Identifier';
      lbFound := True;
    end;
    ttNumber:
    begin
      Result  := 'Number';
      lbFound := True;
    end;
    ttQuotedLiteralString:
    begin
      Result  := 'Quoted literal string';
      lbFound := True;
    end;
    ttComment:
    begin
      Result  := 'comment';
      lbFound := True;
    end;
    ttConditionalCompilationRemoved:
    begin
      Result  := 'cond compilation removed';
      lbFound := True;
    end
    else
    begin
      for liLoop := Low(mrKeywordTextMap) to High(mrKeywordTextMap) do
      begin
        if peToken = mrKeywordTextMap[liLoop].eToken then
        begin
          Result  := mrKeywordTextMap[liLoop].sToken;
          lbFound := True;
          break;
        end;
      end;
    end;
  end;

  if not lbFound then
    Result := 'Token ' + IntToStr(Ord(peToken)) + ' not found';
end;

function TokenTypesToString(const peTokens: TTokenTypeSet): string;
var
  liLoop: integer;
begin
  if peTokens = [] then
    Result := '[]'
  else
  begin
    Result := '';

    for liLoop := Low(mrKeywordTextMap) to High(mrKeywordTextMap) do
    begin
      if mrKeywordTextMap[liLoop].eToken in peTokens then
      begin
        if Result <> '' then
          Result := Result + ' ';
        Result := Result + mrKeywordTextMap[liLoop].sToken;
      end;
    end;
  end;
end;

function WordTypeOfToken(const peTokenType: TTokenType): TWordType; overload;
var
  liLoop: integer;
begin
  Result := wtNotAWord;

  if peTokenType = ttIdentifier then
  begin
    // identifier not in the list as it has no fixed text
    Result := wtIdentifier;
  end
  else
  begin
    for liLoop := Low(mrKeywordTextMap) to High(mrKeywordTextMap) do
    begin
      if mrKeywordTextMap[liLoop].eToken = peTokenType then
      begin
        Result := mrKeywordTextMap[liLoop].eWordType;
        break;
      end;
    end;
  end;
end;

const
  PreProcessorSymbolData: array[TPreProcessorSymbolType] of string = (
    '$$$$$$$$$$',
    '{$DEFINE',
    '{$UNDEF',
    '{$IFDEF',
    '{$IFNDEF',
    '{$IFOPT',
    '{$IF',
    '{$ELSEIF',
    '{$ELSE',
    '{$ENDIF',
    '{$IFEND'
    );


{ given a token, identify the preprocessor symbol and the text after it }
procedure GetPreprocessorSymbolData(const psSourceCode: String;
  var peSymbolType: TPreProcessorSymbolType; var psText: String);
var
  leLoop:    TPreProcessorSymbolType;
  liItemLen: integer;
begin
  peSymbolType := ppNone;
  psText := '';

  for leLoop := low(TPreProcessorSymbolType) to High(TPreProcessorSymbolType) do
  begin
    if leLoop = ppNone then
      continue;

    liItemLen := Length(PreProcessorSymbolData[leLoop]);
    if AnsiSameText(StrLeft(psSourceCode, liItemLen), PreProcessorSymbolData[leLoop]) and
      ( not CharIsAlpha(psSourceCode[liItemLen + 1])) then
    begin
      peSymbolType := leLoop;
      break;
    end;
  end;

  if peSymbolType = ppNone then
    exit;

  psText := StrRestOf(psSourceCode, Length(PreProcessorSymbolData[peSymbolType]) + 1);

  if psText <> '' then
  begin
    if StrRight(psText, 1) = '}' then
      psText := StrChopRight(psText, 1);

    psText := Trim(psText);
  end;
end;

function PreProcSymbolTypeToString(const peSymbolType: TPreProcessorSymbolType): string;
begin
  case peSymbolType of
    ppNone:
      Result := 'none';
    ppDefine:
      Result := '$DEFINE';
    ppUndef:
      Result := '$UNDEF';
    ppIfDef:
      Result := '$IFDEF';
    ppIfNotDef:
      Result := '$IFNDEF';
    ppIfOpt:
      Result := '$IFOPT';
    ppIfExpr:
      Result := '$IFEXPR';
    ppElseIf:
      Result := '$ELSEIF';
    ppElse:
      Result := '$ELSE';
    ppEndIf:
      Result := '$ENDIF';
    ppIfEnd:
      Result := '$IFEND';
    else
      Assert(False);
  end;
end;

function PreProcSymbolTypeSetToString(
  const peSymbolTypes: TPreProcessorSymbolTypeSet): string;
var
  leLoop: TPreProcessorSymbolType;
begin
  Result := '';

  for leLoop := Low(TPreProcessorSymbolType) to High(TPreProcessorSymbolType) do
  begin
    if leLoop in peSymbolTypes then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + PreProcSymbolTypeToString(leLoop);
    end;
  end;

end;

initialization
  AddKeywords;
  SortKeywords;
  InitLengthOffestIndexes;
end.

unit BuildParseTree;
{(*}
(*------------------------------------------------------------------------------
 Delphi Code formatter source code

The Original Code is BuildParseTree, released May 2003.
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

{ AFS 27 October
 This unit turns a token stream into a full parse tree
 using the Recursive Descent method

 The tokens are then the leaves of a tree structure

 The grammer is 'Appendix A Object Pascal grammar'
 As found on the borland Web site.
 It is much extended via test cases as that is woefully incomplete
}

{$I JcfGlobal.inc}

interface

uses
  Contnrs, SysUtils,
  Forms,
  // local
  ParseTreeNode,
  ParseTreeNodeType,
  ParseError,
  SourceToken,
  SourceTokenList,
  Tokens,
  TokenUtils,
  JcfStringUtils;

type
  TBuildParseTree = class(TObject)
  Private
    fbMadeTree: boolean;
    fiTokenIndex: integer;

    fcRoot: TParseTreeNode;
    fcStack: TStack;
    fcTokenList: TSourceTokenList;

    fiTokenCount: integer;
    procedure RecogniseTypeHelper;
    procedure SplitGreaterThanOrEqual;
    procedure SplitShr_gg;

    procedure RecogniseGoal;
    procedure RecogniseUnit;
    procedure RecogniseProgram;
    procedure RecognisePackage;
    procedure RecogniseLibrary;

    procedure RecogniseFileEnd;

    procedure RecogniseProgramBlock;
    procedure RecogniseUsesClause(const pbInFiles: boolean);
    procedure RecogniseUsesItem(const pbInFiles: boolean);
    procedure RecogniseDottedName;
    procedure RecogniseDottedNameElement;

    procedure RecogniseInterfaceSection;
    procedure RecogniseInterfaceDecls;
    procedure RecogniseInterfaceDecl;
    procedure RecogniseExportedHeading;

    procedure RecogniseIdentifier(const pbCanHaveUnitQualifier: boolean; const peStrictness: TIdentifierStrictness);
    procedure RecognisePossiblyAmpdIdentifier;

    procedure RecogniseImplementationSection;
    procedure RecogniseDeclSections;
    procedure RecogniseDeclSection;
    procedure RecogniseInitSection;
    procedure RecogniseBlock(const CanBeJustEnd: boolean = false);
    procedure RecogniseIdentList(const pbCanHaveUnitQualifier: boolean);
    procedure RecogniseIdentValue;
    procedure RecogniseAsCast;

    procedure RecogniseLabelDeclSection;
    procedure RecogniseLabel;
    procedure RecogniseConstSection(const pbNestedInClass: Boolean);
    procedure RecogniseConstantDecl;
    procedure CheckLabelPrefix;

    procedure RecogniseTypeSection(const pbNestedInCLass: Boolean);
    procedure RecogniseVarSection(const pbClassVars: boolean);
    procedure RecogniseProcedureDeclSection;
    procedure RecogniseClassOperator(const pbHasBody: boolean);
    procedure RecogniseOperator(const pbHasBody: boolean);
    procedure RecogniseOperatorSymbol;

    // set pbAnon = true if the proc has no name
    procedure RecogniseProcedureHeading(const pbAnon, pbCanInterfaceMap: boolean);
    procedure RecogniseFunctionHeading(const pbAnon, pbCanInterfaceMap: boolean);
    procedure RecogniseCompoundStmnt;
    procedure RecogniseStatementList(const peEndTokens: TTokenTypeSet);
    procedure RecogniseStatement;

    procedure RecogniseTypeId;
    procedure RecogniseTypedConstant;
    procedure RecogniseArrayConstant;
    procedure RecogniseRecordConstant;
    procedure RecogniseRecordFieldConstant;

    procedure RecogniseTypeDecl;

    procedure RecogniseArrayType;
    procedure RecogniseClassRefType;
    procedure RecogniseEnumeratedType;
    procedure RecogniseFieldDecl;
    procedure RecogniseFieldList;
    procedure RecogniseRecordStaticItem;
    procedure RecogniseMethodReferenceType;

    procedure RecogniseFileType;
    procedure RecogniseOrdIdent;
    procedure RecogniseOrdinalType;
    procedure RecognisePointerType;
    procedure RecogniseProcedureType;
    procedure RecogniseRealType;
    procedure RecogniseRecordType;
    procedure RecogniseRecordBody;
    procedure RecogniseRecVariant;
    procedure RecogniseRestrictedType;
    procedure RecogniseSpecializeType;
    procedure RecogniseSetType;
    procedure RecogniseSimpleType;
    procedure RecogniseStringType;
    procedure RecogniseStrucType;
    procedure RecogniseSubrangeType;
    procedure RecogniseType;
    procedure RecogniseVariantType;
    procedure RecogniseClassType;
    procedure RecogniseClassBody;
    procedure RecogniseClassDeclarations(const pbInterface: boolean);

    procedure RecogniseInterfaceType;
    procedure RecogniseObjectType;
    procedure RecogniseVariantSection;
    procedure RecogniseVarDecl;
    procedure RecogniseAddOp;
    procedure RecogniseDesignator;
    procedure RecogniseDesignatorTail;
    procedure RecogniseExpr(const pbAllowRelop: boolean);
    procedure RecogniseExprList;
    procedure RecogniseFactor;
    procedure RecogniseUnarySymbolFactor;
    procedure RecogniseTerm;
    procedure RecogniseMulOp;
    procedure RecogniseRelOp;
    procedure RecogniseSetConstructor;
    procedure RecogniseSetElement;
    procedure RecogniseQualId;
    procedure RecogniseConstantExpression;
    procedure RecogniseLiteralString;

    procedure RecogniseBracketedStatement;
    procedure RecognisePossibleAssign;

    procedure RecogniseSimpleExpression;
    procedure RecogniseSimpleStmnt;

    procedure RecogniseCaseLabel;
    procedure RecogniseCaseSelector;
    procedure RecogniseCaseStmnt;
    procedure RecogniseForStmnt;
    procedure RecogniseIfStmnt;
    procedure RecogniseRepeatStmnt;
    procedure RecogniseStructStmnt;
    procedure RecogniseWhileStmnt;
    procedure RecogniseWithStmnt;
    procedure RecogniseTryStatement;
    procedure RecogniseExceptionHandlerBlock;
    procedure RecogniseExceptionHandler;
    procedure RecogniseRaise;

    procedure RecogniseInline;
    procedure RecogniseInlineItem;

    procedure RecogniseFunctionDecl(const pbAnon: boolean);
    procedure RecogniseProcedureDecl(const pbAnon: boolean);
    procedure RecogniseConstructorDecl;
    procedure RecogniseDestructorDecl;

    procedure RecogniseFormalParameters;
    procedure RecogniseFormalParam;
    procedure RecogniseParameter;
    procedure RecogniseActualParams;
    procedure RecogniseActualParam;

    procedure RecogniseProcedureDirectives;

    procedure RecogniseExportsSection;
    procedure RecogniseExportedProc;

    // set pbDeclaration to false if the method body is to be recognised
    procedure RecogniseConstructorHeading(const pbDeclaration: boolean);
    procedure RecogniseDestructorHeading(const pbDeclaration: boolean);
    procedure RecogniseObjHeritage;

    procedure RecogniseContainsClause;
    procedure RecogniseInterfaceHeritage;
    procedure RecogniseProperty;
    procedure RecognisePropertyInterface;
    procedure RecognisePropertyParameterList;
    procedure RecognisePropertySpecifiers;
    procedure RecognisePropertyAccess;
    procedure RecogniseRequiresClause;
    procedure RecogniseInterfaceGuid;
    procedure RecogniseClassHeritage;
    procedure RecogniseClassVisibility;
    procedure RecogniseMethodName(const pbClassNameCompulsory: boolean);

    procedure RecogniseAsmBlock;
    procedure RecogniseAsmParam;
    procedure RecogniseAsmStatement;
    procedure RecogniseAsmExpr;
    procedure RecogniseAsmOperator;
    procedure RecogniseAsmFactor;

    procedure RecogniseAsmIdent;
    procedure RecogniseAsmOpcode;
    procedure RecogniseAsmLabel(const pbColon: boolean);
    procedure RecogniseWhiteSpace;
    procedure RecogniseNotSolidTokens;

    procedure RecogniseHintDirectives;
    procedure RecognisePropertyDirectives;
    procedure RecogniseExternalProcDirective;
    function RecognisePublicProcDirective: boolean;

    procedure RecogniseAttributes;

    function GenericAhead: boolean;
    procedure RecogniseGenericType;

    procedure Recognise(const peTokenTypes: TTokenTypeSet; const pbKeepTrailingWhiteSpace: Boolean = False); overload;
    procedure Recognise(const peTokenType: TTokenType; const pbKeepTrailingWhiteSpace: Boolean = False); overload;

    function PushNode(const peNodeType: TParseTreeNodeType): TParseTreeNode;
    function PopNode: TParseTreeNode;
    function TopNode: TParseTreeNode;
    function IdentifierNext(const peStrictness: TIdentifierStrictness): boolean;
    function ArrayConstantNext: boolean;
    function SubrangeTypeNext: boolean;
    function TypePastAttribute: boolean;
    procedure RecogniseGenericConstraints;
    procedure RecogniseGenericConstraint;
    procedure RecogniseHeritageList;

    procedure RecogniseAnonymousMethod;
    function AnonymousMethodNext: boolean;
    procedure CheckEnumeratorToken;
  Protected

  Public
    constructor Create;
    destructor Destroy; override;

    procedure BuildParseTree;
    procedure Clear;

    property Root: TParseTreeNode Read fcRoot;
    property TokenList: TSourceTokenList Read fcTokenList Write fcTokenList;
  end;

implementation

const
  UPDATE_INTERVAL = 512;

  {------------------------------------------------------------------------------
    standard overrides }

constructor TBuildParseTree.Create;
begin
  inherited;
  fcStack := TStack.Create;
  fcRoot  := nil;
  fiTokenCount := 0;
end;

destructor TBuildParseTree.Destroy;
begin
  Clear;
  FreeAndNil(fcStack);

  inherited;
end;

procedure TBuildParseTree.Clear;
begin
  while fcStack.Count > 0 do
    fcStack.Pop;
    
  FreeAndNil(fcRoot);
end;

procedure TBuildParseTree.RecogniseHeritageList;
var
  lbMore: boolean;
begin
  { heritage of a class or interface
  }

  lbMore := true;

  while lbMore do
  begin

    if fcTokenList.FirstSolidTokenType = ttSpecialize then
      Recognise(ttSpecialize);

    RecogniseDottedName;
    if fcTokenList.FirstSolidTokenType = ttLessThan then
    begin
      RecogniseGenericType;
    end;

    lbMore := fcTokenList.FirstSolidTokenType = ttComma;

    if lbMore then
      Recognise(ttComma);
  end;

end;

procedure TBuildParseTree.BuildParseTree;
begin
  Assert(fcTokenList <> nil);
  Clear;
  { read to end of file necessary?
  liIndex := 0;
  while BufferTokens(liIndex).TokenType <> ttEOF do
  begin
    BufferTokens(liIndex);
    inc(liIndex);
  end; }
  fiTokenIndex := 0;
  RecogniseGoal;

  { should not have any sections started but not finished }
  Assert(fcStack.Count = 0);

  { all tokens should have been processed }
  Assert(fcTokenList.Count = fcTokenList.CurrentTokenIndex);
  fcTokenList.Clear;


  fbMadeTree := True;
end;

{-------------------------------------------------------------------------------
  recogniser support }

procedure TBuildParseTree.Recognise(const peTokenTypes: TTokenTypeSet;
  const pbKeepTrailingWhiteSpace: Boolean);

  function DescribeTarget: string;
  begin
    Result := '"';
    if peTokenTypes <> [] then
      Result := Result + TokenTypesToString(peTokenTypes);
    Result := Result + '"';
  end;

var
  lcCurrentToken:  TSourceToken;
begin
  // must accept something
  Assert(peTokenTypes <> []);

  { read tokens up to and including the specified one.
    Add them to the parse tree at the current growing point  }
  while not fcTokenList.EOF do
  begin
    lcCurrentToken := fcTokenList.Extract;
    Assert(lcCurrentToken <> nil);

    TopNode.AddChild(lcCurrentToken);
    // the the match must be the first solid token
    if lcCurrentToken.TokenType in peTokenTypes then
    begin
      // found it
      Break;
    end
    // accept any white space until we find it
    else if not (lcCurrentToken.TokenType in NotSolidTokens) then
      raise TEParseError.Create('Unexpected token, expected ' +
        DescribeTarget, lcCurrentToken);
  end;
  
  
  Inc(fiTokenCount);
  {$IFNDEF COMMAND_LINE}
  if (fiTokenCount mod UPDATE_INTERVAL) = 0 then
     Application.ProcessMessages;
  {$ENDIF}

  { add trailing white space
    fixes some problems, causes others
    problem is that comments are not well-attached }
  // add trailing white space
  if pbKeepTrailingWhiteSpace then
    RecogniseNotSolidTokens;
end;


procedure TBuildParseTree.Recognise(const peTokenType: TTokenType; const pbKeepTrailingWhiteSpace: Boolean = False);
begin
  Recognise([peTokenType], pbKeepTrailingWhiteSpace);
end;

function TBuildParseTree.PushNode(const peNodeType: TParseTreeNodeType): TParseTreeNode;
begin
  Result := TParseTreeNode.Create;
  Result.NodeType := peNodeType;

  if fcStack.Count > 0 then
  begin
    TopNode.AddChild(Result);
    Result.Parent := TopNode;
  end
  else
    fcRoot := Result;

  fcStack.Push(Result);
end;

function TBuildParseTree.PopNode: TParseTreeNode;
begin
  Result := fcStack.Pop;
end;

function TBuildParseTree.TopNode: TParseTreeNode;
begin
  Result := fcStack.Peek;
end;

{a unit / type/var name }

function TBuildParseTree.IdentifierNext(const peStrictness: TIdentifierStrictness): boolean;
var
  lc: TSourceToken;
begin
  lc     := fcTokenList.FirstSolidToken;
  { We have to admit directives and type names as identifiers. see TestBogusDirectives.pas for the reasons why }
  Result := IsIdentifierToken(lc, peStrictness);
end;

{-------------------------------------------------------------------------------
  recognisers for the parse tree  top to bottom

  These procs are based on the "Appendix A Object Pascal grammar"
  Found on the Borland Web site
  All the productions should be here, in the same order
}

procedure TBuildParseTree.RecogniseGoal;
var
  lc: TSourceToken;
  s: string;
begin
  // Goal -> (Program | Package  | Library  | Unit)

  if fcTokenList.Count < 1 then
    raise TEParseError.Create('No source to parse', nil);

  lc := fcTokenList.FirstSolidToken;
  Assert(lc <> nil);

  WriteStr(s, lc.TokenType);
  case lc.TokenType of
    ttProgram:
      RecogniseProgram;
    ttPackage:
      RecognisePackage;
    ttLibrary:
      RecogniseLibrary;
    ttUnit:
      RecogniseUnit;
    else
      raise TEParseError.Create('Expected program, package, library, unit, got "'
                                + s + '" ', lc);
  end
end;

procedure TBuildParseTree.RecogniseProgram;
begin
  // Program -> [PROGRAM Ident ['(' IdentList ')'] ';']  ProgramBlock '.'
  PushNode(nProgram);

  PushNode(nUnitHeader);
  Recognise(ttProgram);

  PushNode(nUnitName);
  RecogniseIdentifier(False, idStrict);
  PopNode;

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
  begin
    Recognise(ttOpenBracket);
    RecogniseIdentList(False);
    Recognise(ttCloseBracket);
  end;

  if fcTokenList.FirstSolidTokenType = ttSemiColon then
    Recognise(ttSemicolon);

  PopNode;

  RecogniseProgramBlock;
  RecogniseFileEnd;

  PopNode;
end;

procedure TBuildParseTree.RecogniseUnit;
begin
  // Unit -> UNIT Ident ';' InterfaceSection ImplementationSection InitSection '.'
  PushNode(nUnit);

  PushNode(nUnitHeader);
  Recognise(ttUnit);

  PushNode(nUnitName);
  RecogniseDottedName;
  PopNode;

  { unit can be "deprecated platform library" }
  if fcTokenList.FirstSolidTokenType in HintDirectives then
  begin
    PushNode(nHintDirectives);

    while fcTokenList.FirstSolidTokenType in HintDirectives do
      Recognise(HintDirectives);

    PopNode;
  end;

  { or platform }
  if fcTokenList.FirstSolidTokenType = ttPlatform then
    Recognise(ttPlatform);

  Recognise(ttSemicolon);

  PopNode;

  RecogniseInterfaceSection;
  RecogniseImplementationSection;
  RecogniseInitSection;
  RecogniseFileEnd;

  PopNode;
end;

procedure TBuildParseTree.RecognisePackage;
begin
  // Package -> PACKAGE Ident ';' [RequiresClause] [ContainsClause] END '.'
  PushNode(nPackage);

  PushNode(nUnitHeader);
  Recognise(ttPackage);

  PushNode(nUnitName);
  RecogniseIdentifier(False, idStrict);
  PopNode;
  Recognise(ttSemicolon);
  PopNode;

  if fcTokenList.FirstSolidTokenType = ttRequires then
    RecogniseRequiresClause;

  if fcTokenList.FirstSolidTokenType = ttContains then
    RecogniseContainsClause;

  Recognise(ttEnd);
  RecogniseFileEnd;

  PopNode;
end;

procedure TBuildParseTree.RecogniseLibrary;
begin
  // Library -> LIBRARY Ident ';' ProgramBlock '.'
  PushNode(nLibrary);

  PushNode(nUnitHeader);
  Recognise(ttLibrary);

  PushNode(nUnitName);
  RecogniseIdentifier(False, idStrict);
  PopNode;
  Recognise(ttSemicolon);
  PopNode;

  RecogniseProgramBlock;
  RecogniseFileEnd;

  PopNode;
end;

procedure TBuildParseTree.RecogniseFileEnd;
var
  lcCurrentToken: TSourceToken;
begin
  Recognise(ttDot);

  { delphi accepts anything after the final end }
  while not fcTokenList.EOF do
  begin
    lcCurrentToken := fcTokenList.Extract;
    TopNode.AddChild(lcCurrentToken);
  end;
end;

procedure TBuildParseTree.RecogniseProgramBlock;
var
  lc: TSourceToken;
begin
  // ProgramBlock -> [UsesClause] Block
  // also it seems that the block is optional, can just be the "end" for the file

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttUses then
    RecogniseUsesClause(True);

  if fcTokenList.FirstSolidTokenType = ttOpenSquareBracket then
    RecogniseAttributes;

  RecogniseBlock(True);
end;

procedure TBuildParseTree.RecogniseUsesClause(const pbInFiles: boolean);
begin
  // recognise comments etc before the uses clause
  RecogniseNotSolidTokens;


  // UsesClause -> USES IdentList ';'
  PushNode(nUses);

  Recognise(ttUses);

  // IdentList -> Ident/','...
  PushNode(nIdentList);

  RecogniseNotSolidTokens;

  RecogniseUsesItem(pbInFiles);

  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseNotSolidTokens;
    RecogniseUsesItem(pbInFiles);
  end;

  PopNode;

  Recognise(ttSemicolon);

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseUsesItem(const pbInFiles: boolean);
begin
  PushNode(nUsesItem);

  RecogniseDottedName;

  if pbInFiles and (fcTokenList.FirstSolidTokenType = ttIn) then
  begin
    Recognise(ttIn);
    Recognise(ttQuotedLiteralString);
  end;

  RecogniseNotSolidTokens;

  PopNode;
end;


{ elements in a dotted name are usually just identifiers
  but occasionally are reserved words - e.g. "object" and "type"
  as in "var MyType: System.Type; " or "var pElement: System.Object; "
  }
procedure TBuildParseTree.RecogniseDottedNameElement;
var
  lcNext: TSourceToken;
begin
  lcNext := fcTokenList.FirstSolidToken;

  if lcNext = nil then
    exit;

  case lcNext.TokenType of
    ttObject:
      Recognise(ttObject);
    ttType:
      Recognise(ttType);
    ttAmpersand:
      RecognisePossiblyAmpdIdentifier;
    else
      // "Label" is valid here as an identifier even though it is a reserved word
      RecogniseIdentifier(False, idAny);

  end;
end;


procedure TBuildParseTree.RecogniseDottedName;
begin
  RecogniseIdentifier(False, idStrict);

  while fcTokenList.FirstSolidTokenType = ttDot do
  begin
    Recognise(ttDot);
    RecogniseDottedNameElement;
  end;
end;

procedure TBuildParseTree.RecogniseInterfaceSection;
begin
  // InterfaceSection -> INTERFACE [UsesClause] [InterfaceDecl]...

  PushNode(nInterfaceSection);

  Recognise(ttInterface, True);

  if fcTokenList.FirstSolidTokenType = ttUses then
    RecogniseUsesClause(True);

  RecogniseInterfaceDecls;

  PopNode;
end;

procedure TBuildParseTree.RecogniseInterfaceDecls;
begin
  { a list of InterfaceDecl sections
    e.g.

      var a,b: integer;
      const b = 3;
      type foo = integer;
      procedure fred;

      NB also threadvar

  }
  while fcTokenList.FirstSolidTokenType in [ttConst, ttResourceString,
      ttType, ttVar, ttThreadVar, ttOpenSquareBracket, ttExports, ttOperator, ttProperty,ttGeneric] + ProcedureWords do
    RecogniseInterfaceDecl;
end;

procedure TBuildParseTree.RecogniseInterfaceDecl;
var
  lc: TSourceToken;
  lt: Tokens.TTokenType;
begin
  {
   InterfaceDecl
        -> ConstSection
       -> TypeSection
       -> VarSection
       -> ExportedHeading
   }
  PushNode(nDeclSection);

  lc := fcTokenList.FirstSolidToken;
  lt := fcTokenList.FirstSolidTokenType;

  case lt of
    ttConst, ttResourceString:
      RecogniseConstSection(false);
    ttType:
      RecogniseTypeSection(false);
    ttVar, ttThreadvar:
      RecogniseVarSection(false);
    ttProcedure, ttFunction, ttOperator,ttGeneric:
      RecogniseExportedHeading;
    ttOpenSquareBracket:
      RecogniseAttributes;
    ttExports:
      RecogniseExportsSection;
    ttProperty:
    begin
      RecogniseProperty;
      Recognise(ttSemicolon);
    end
    else
      raise TEParseError.Create('Expected const, type, var, procedure or function', lc);
  end;

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseExportedHeading;
var
  lc: TSourceToken;
  lt: TTokenType;
begin
  { ExportedHeading
     -> ProcedureHeading ';' [Directive]
     -> FunctionHeading ';' [Directive] }

  lc := fcTokenList.FirstSolidToken;
  lt := lc.TokenType;

  case lt of
    ttProcedure:
      RecogniseProcedureHeading(False, False);
    ttFunction:
      RecogniseFunctionHeading(False, False);
    ttOperator:
      RecogniseOperator(false);
    ttGeneric:
    begin
      case fcTokenList.SolidTokenType(2) of
        ttProcedure:
          RecogniseProcedureHeading(False, False);
        ttFunction:
          RecogniseFunctionHeading(False, False);
        ttOperator:
          RecogniseOperator(false);
        else
          TEParseError.Create('Expected function or procedure', lc);
        end;
    end
    else
      raise TEParseError.Create('Expected function or procedure', lc);
  end;

  { the ';' is ommited by lazy programmers in some rare occasions}
  if fcTokenList.FirstSolidTokenType = ttSemicolon then
    Recognise(ttSemicolon);
end;

procedure TBuildParseTree.RecogniseImplementationSection;
begin
  {
    ImplementationSection -> IMPLEMENTATION
         [UsesClause]
         [DeclSection]...
  }
  PushNode(nImplementationSection);

  Recognise(ttImplementation, True);

  if fcTokenList.FirstSolidTokenType = ttUses then
    RecogniseUsesClause(True);

  RecogniseDeclSections;

  PopNode;
end;

procedure TBuildParseTree.RecogniseBlock(const CanBeJustEnd: boolean = false);
var
  lc: TSourceToken;
  lt: TTokenType;
begin
  { Block -> [DeclSection] CompoundStmt }

  lc := fcTokenList.FirstSolidToken;
  lt := lc.TokenType;

  PushNode(nBlock);

  // [DeclSection]
  if lt in ([ttGeneric] + Declarations + ProcedureWords) then
    RecogniseDeclSections;

  lc := fcTokenList.FirstSolidToken;
  lt := lc.TokenType;

  if lt = ttAsm then
    RecogniseAsmBlock
  else if CanBeJustEnd and (lt = ttEnd) then
    Recognise(ttEnd)
  else
    RecogniseCompoundStmnt;

  PopNode;
end;

procedure TBuildParseTree.RecogniseDeclSections;
begin
  { a list of Decl sections
    e.g.

      label b;
      var a: integer;
      const b = 3;
      type foo = integer;
      procedure fred;
      class procedure TFoo.bar;

  }
  while fcTokenList.FirstSolidTokenType in
    [ttClass, ttGeneric] + Declarations + ProcedureWords do
    RecogniseDeclSection;
end;

procedure TBuildParseTree.RecogniseDeclSection;
var
  lc: TSourceToken;
  lt: TTokenType;
begin
  PushNode(nDeclSection);
  {
   DeclSection
     -> LabelDeclSection
     -> ConstSection
     -> TypeSection
     -> VarSection
     -> ProcedureDeclSection
   }

  lc := fcTokenList.FirstSolidToken;
  lt := fcTokenList.FirstSolidTokenType;

  case lt of
    ttLabel:
      RecogniseLabelDeclSection;
    ttConst, ttResourceString:
      RecogniseConstSection(false);
    ttType:
      RecogniseTypeSection(false);
    ttVar, ttThreadvar:
      RecogniseVarSection(false);
    ttProcedure, ttFunction, ttConstructor, ttDestructor, ttClass, ttOperator,ttGeneric:
      RecogniseProcedureDeclSection;
    ttExports:
      RecogniseExportsSection;
    ttProperty:
    begin
      RecogniseProperty;
      Recognise(ttSemicolon);
    end

    else
      raise TEParseError.Create(
        'Expected label, const, type, var, procedure or function', lc);
  end;

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseLabelDeclSection;
begin
  {
    LabelDeclSection -> LABEL LabelId
    this grammer can't be right. Can be mutiple labels and must have semicolon

    e.g.
      Label foo, bar, fish;

    code below is more flexible
  }

  PushNode(nLabelDeclSection);
  Recognise(ttLabel);

  // almost a RecogniseIdentList, but not quite. also numbers allowed
  PushNode(nIdentList);

  RecogniseLabel;

  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseLabel;
  end;

  PopNode;

  Recognise(ttSemicolon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseLabel;
begin
  if fcTokenList.FirstSolidTokenType = ttNumber then
    Recognise(ttNumber)
  else
    // no unit qualifier
    RecogniseIdentifier(False, idAllowDirectives);
end;

procedure TBuildParseTree.RecogniseConstSection(const pbNestedInClass: Boolean);
var
  leFirstTokenType: TTokenType;
begin
  {
    ConstSection -> CONST (ConstantDecl ';')...
  }
  PushNode(nConstSection);
  Recognise([ttConst, ttResourceString]);

  while (fcTokenList.FirstSolidWordType in IdentifierTypes) do
  begin
    RecogniseConstantDecl;
    Recognise(ttSemicolon);

    // #Trident# If const is nested inside a class, a visibility designator
    // ("private" for exemple) can be written after.
    // So, inside a class, no wtReservedWordDirective allowed
    leFirstTokenType := fcTokenList.FirstSolidTokenType;
    if pbNestedInClass then
    begin
      if leFirstTokenType in (ClassVisibility+[ttStrict]) then
        break;
      if leFirstTokenType in [ttClass,ttVar,ttThreadVar,ttConst,ttFunction,ttProcedure,ttOperator,ttConstructor,ttDestructor,ttProperty,ttCase] then
        break;
    end
    else
    begin
      if (fcTokenList.FirstSolidTokenType = ttGeneric) and (fcTokenList.SolidTokenType(2) in [ttFunction,ttProcedure,ttOperator]) then
        break;
    end;

    // can be followed by an operator decl in FreePascal
    if leFirstTokenType = ttOperator then
      break;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseConstantDecl;
var
  lc: TSourceToken;
begin
  {
  ConstantDecl
    -> Ident '=' ConstExpr
    -> Ident ':' TypeId '=' TypedConstant

    TypeID is too simplistic -
    can be, for e.g.

    "const foo: array[1..3] of integer = (1,2,3);"
    or "const recs: array[1..3] of TSomeRecord = ( (... "
  }

  PushNode(nConstDecl);

  RecogniseIdentifier(False, idAllowDirectives);

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttEquals then
  begin
    Recognise(ttEquals);
    RecogniseConstantExpression;
  end
  else if lc.TokenType = ttColon then
  begin
    Recognise(ttColon);
    //RecogniseTypeId;
    RecogniseType;
    Recognise(ttEquals);
    RecogniseTypedConstant;
  end
  else
    raise TEParseError.Create('Expected equals or colon', lc);

  { can be deprecated library platform }
  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseTypeSection(const pbNestedInCLass: Boolean);
var
  lc: TSourceToken;
begin
  {
  TypeSection -> TYPE (TypeDecl ';')...
  }
  PushNode(nTypeSection);
  Recognise(ttType);

  { In Delphi.Net, the type can be preceeded by an attribute in '[ ]' }
  lc := fcTokenList.FirstSolidToken;
  while (lc <> nil) and ((lc.WordType in IdentifierTypes) or TypePastAttribute) do
  begin
    RecogniseTypeDecl;

    if pbNestedInClass then
    begin
      if fcTokenList.FirstSolidTokenType in (ClassVisibility + [ttStrict]) then
        break;
      if fcTokenList.FirstSolidTokenType in [ttClass,ttVar,ttThreadVar, ttConst,ttFunction,ttProcedure,ttOperator,ttConstructor,ttDestructor,ttProperty,ttCase] then
        break;
    end
    else
    begin
      if (fcTokenList.FirstSolidTokenType = ttGeneric) and (fcTokenList.SolidTokenType(2) in [ttFunction,ttProcedure,ttOperator]) then
        break;
    end;
    lc := fcTokenList.FirstSolidToken;
  end;

  PopNode;
end;

// is there an attribute followed by a type name?
function TBuildParseTree.TypePastAttribute: boolean;
var
  lc: TSourceToken;
  i: integer;

  procedure AdvanceToSolid;
  begin
    while (lc <> nil) and (not lc.IsSolid) do
    begin
      inc(i);
      lc := fcTokenList.SourceTokens[i];
    end;
  end;

begin
  i := fcTokenList.CurrentTokenIndex;

  lc := fcTokenList.SourceTokens[i];
  AdvanceToSolid;

  if (lc = nil) or (lc.TokenType <> ttOpenSquareBracket) then
  begin
    Result := False;
    exit;
  end;

  while (lc <> nil) and (lc.TokenType <> ttCloseSquareBracket) do
  begin
    inc(i);
    lc := fcTokenList.SourceTokens[i];
  end;

  inc(i);
  lc := fcTokenList.SourceTokens[i];

  if lc = nil then
  begin
    Result := False;
    exit;
  end;

  AdvanceToSolid;

  Result := (lc <> nil) and (lc.WordType in IdentifierTypes);

end;

procedure TBuildParseTree.RecogniseTypeHelper;
begin
  PushNode(nClassType);
  Recognise([ttType,ttRecord]);
  Recognise(ttHelper);
  if fcTokenList.FirstSolidTokenType = ttOpenBracket then begin
    Recognise(ttOpenBracket);
    RecogniseIdentifier(False, idStrict);
    Recognise(ttCloseBracket);
  end;
  Recognise(ttFor);
  RecogniseIdentifier(False, idStrict);
  RecogniseClassBody;
  Recognise(ttEnd);
  RecogniseHintDirectives;
  PopNode;
end;

procedure TBuildParseTree.RecogniseTypeDecl;
begin
  {
  TypeDecl -> Ident '=' Type
     -> Ident '=' RestrictedType

  Need a semicolon
  }

  PushNode(nTypeDecl);


  //Recognise generic keyword (for fpc)
  if (fcTokenList.FirstSolidTokenType = ttGeneric) then
  begin
   Recognise(ttGeneric);
  end;

  // Delph.Net Attribute?
  if (fcTokenList.FirstSolidTokenType = ttOpenSquareBracket) then
    RecogniseAttributes;

  RecogniseIdentifier(False, idAllowDirectives);
  if fcTokenList.FirstSolidTokenType = ttLessThan then
  begin
    // generic type decl
    RecogniseGenericType;
  end;

  Recognise(ttEquals);

  repeat

     //Recognise type helper (for fpc)
    if (fcTokenList.FirstSolidTokenType in [ttType,ttRecord]) and
      (fcTokenList.SolidToken(2).TokenType=ttHelper) then
    begin
       RecogniseTypeHelper;
    end else


    // type or restricted type
    if (fcTokenList.FirstSolidTokenType in [ttObject, ttClass, ttInterface,
      ttDispInterface]) then
      RecogniseRestrictedType
    else
      RecogniseType;

    if fcTokenList.FirstSolidTokenType = ttLessThan then
    begin
      RecogniseGenericType;
    end;

    if fcTokenList.FirstSolidTokenType = ttIs then
    begin
      Recognise(ttIs);
      Recognise(ttNested);
    end;

    // the type can be deprecated
    if fcTokenList.FirstSolidTokenType = ttDeprecated then
      Recognise(ttDeprecated);

    if fcTokenList.FirstSolidTokenType <> ttDot then
      break;
    Recognise(ttDot);

  until false;

  Recognise(ttSemicolon);

  PopNode;
end;

const
  CONST_GENERIC_TOKENS = [ttAt, ttOpenBracket, ttOpenSquareBracket, ttIdentifier, ttPlus, ttMinus,
        ttNot, ttNumber, ttQuotedLiteralString, ttNil, ttTrue, ttFalse];

function TBuildParseTree.GenericAhead: boolean;
var
  liTokenIndex: integer;
  lcToken: TSourceToken;
begin
  Result := false;
  // generics follow the pattern "< typeid >" or  "< typeid, typeid >"

  if fcTokenList.FirstSolidTokenType <> ttLessThan then
  begin
    exit;
  end;

  liTokenIndex := 2;
  while True do
  begin
    lcToken := fcTokenList.SolidToken(liTokenIndex);
    if lcToken = nil then
    begin
      exit;
    end;

    // alternating id and comma
    if liTokenIndex mod 2 = 0 then
    begin
      // should be id
      if (lcToken.WordType <> wtBuiltInType) and (not IsIdentifierToken(lcToken, idAny)) and (not (lcToken.TokenType in CONST_GENERIC_TOKENS)) then
      begin
        break;
      end;

    end
    else
    begin
      // should be comma or end with ">"
      if lcToken.TokenType = ttGreaterThan then
      begin
        Result := true;
        break;
      end
      else if lcToken.TokenType = ttLessThan then
      begin
        // looks like a nested generic
        Result := true;
        break;
      end
      else if lcToken.TokenType <> ttComma then
      begin
        break;
      end;
    end;

    inc(liTokenIndex);
  end; // while

end;


const
  ConstraintTokens = [ttClass, ttRecord, ttConstructor, ttInterface, ttObject];

procedure TBuildParseTree.RecogniseGenericType;
var
  lbHasConst: boolean;
  lbIsGenericType:boolean;

  procedure RecogniseP;
  var
    liNestLevel: integer;
  begin
    if fcTokenList.FirstSolidTokenType = ttConst then
    begin
      Recognise(ttConst);
      lbHasConst := True;
    end;
    if lbHasConst = False then //can be a expresion like    h: specialize TNames<[Blaise,Pascal]>;
    begin
      lbisGenericType:=(fcTokenList.FirstSolidTokenType=ttIdentifier) and (fcTokenList.SolidTokenType(2)=ttLessThan); //is generic type
      if fcTokenList.FirstSolidTokenType=ttSpecialize then
        lbIsGenericType:=true;
      if (fcTokenList.FirstSolidTokenType in CONST_GENERIC_TOKENS) and (not lbIsGenericType) then
      begin //hack. recognise tokens until ; , or >
        liNestLevel := 0;
        while (liNestLevel > 0) or (not (fcTokenList.FirstTokenType in [ttComma, ttGreaterThan, ttSemiColon, ttGreaterThanOrEqual, ttShr_gg])) do
        begin
          if fcTokenList.FirstTokenType in [ttOpenSquareBracket, ttOpenBracket] then
            Inc(liNestLevel);
          if fcTokenList.FirstTokenType in [ttCloseSquareBracket, ttCloseBracket] then
            Dec(liNestLevel);
          Recognise(fcTokenList.FirstTokenType);
          if fcTokenList.EOF then
          begin
            raise TEParseError.Create('Unexpected EOF. ',nil);
          end;
        end;
      end
      else
        RecogniseType;
    end
    else
      RecogniseType;

    if lbHasConst then
    begin
      if fcTokenList.FirstSolidTokenType = ttColon then
        RecogniseGenericConstraints;
    end;
  end;

begin
  PushNode(nGeneric);

  // angle brackets
  Recognise(ttLessThan);

  while True do
  begin
    lbHasConst := False;
    PushNode(nType);
    RecogniseP;
    // more types after commas
    while fcTokenList.FirstSolidTokenType = ttComma do
    begin
      Recognise(ttComma);
      RecogniseP;
    end;

    if fcTokenList.FirstSolidTokenType = ttColon then
    begin
      RecogniseGenericConstraints;
    end;
    if fcTokenList.FirstSolidTokenType <> ttSemiColon then
    begin
      PopNode;
      break;
    end;
    Recognise(ttSemiColon);
    PopNode;
  end;

  if fcTokenList.FirstSolidTokenType = ttGreaterThanOrEqual then
  begin
    // the tokenizer got it wrong - e.g "TTestNullable<T:Record>=Class"
    // this is the same as TTestNullable<T:Record> =Class
    RecogniseWhiteSpace;
    SplitGreaterThanOrEqual;
  end;

  if fcTokenList.FirstSolidTokenType = ttShr_gg then
  begin
    // >> operator
    RecogniseWhiteSpace;
    SplitShr_gg;
  end;


  Recognise(ttGreaterThan);

  PopNode;
end;

procedure TBuildParseTree.RecogniseGenericConstraints;
begin
  // restriction on the generic type. Colon followed by the constraint
  Recognise(ttColon);

  RecogniseGenericConstraint;

  // optionally more constraints seperated by commas
  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseGenericConstraint;
  end;

end;

procedure TBuildParseTree.RecogniseGenericConstraint;
begin
  // one of a small set of constraints - class, record, constructor
  if fcTokenList.FirstSolidTokenType in ConstraintTokens then
  begin
    Recognise(ConstraintTokens);
  end
  else
  begin
    // can be a class name
    RecogniseIdentifier(true, idAny);
    // and the class can be generic
    if fcTokenList.FirstSolidTokenType = ttLessThan then
    begin
      RecogniseGenericType;
    end;
  end;
end;


procedure TBuildParseTree.SplitGreaterThanOrEqual;
var
  liIndex: integer;
  lcNewToken: TSourceToken;
  fsFileName: string;
begin
  if fcTokenList.FirstTokenType = ttGreaterThanOrEqual then
  begin
    liIndex := fcTokenList.CurrentTokenIndex;
    fsFileName := fcTokenList.SourceTokens[liIndex].FileName;

    fcTokenList.Delete(liIndex);

    lcNewToken := TSourceToken.Create();
    lcNewToken.FileName := fsFileName;
    lcNewToken.SourceCode := '>';
    lcNewToken.TokenType := ttGreaterThan;

    fcTokenList.Insert(liIndex, lcNewToken);

    lcNewToken := TSourceToken.Create();
    lcNewToken.FileName := fsFileName;
    lcNewToken.SourceCode := '=';
    lcNewToken.TokenType := ttEquals;

    fcTokenList.Insert(liIndex + 1 , lcNewToken);
  end;
end;

procedure TBuildParseTree.SplitShr_gg;
var
  liIndex: integer;
  lcNewToken: TSourceToken;
  fsFileName: string;
begin
  if fcTokenList.FirstTokenType = ttShr_gg then
  begin
    liIndex := fcTokenList.CurrentTokenIndex;
    fsFileName := fcTokenList.SourceTokens[liIndex].FileName;

    fcTokenList.Delete(liIndex);

    lcNewToken := TSourceToken.Create();
    lcNewToken.FileName := fsFileName;
    lcNewToken.SourceCode := '>';
    lcNewToken.TokenType := ttGreaterThan;

    fcTokenList.Insert(liIndex, lcNewToken);

    lcNewToken := TSourceToken.Create();
    lcNewToken.FileName := fsFileName;
    lcNewToken.SourceCode := '>';
    lcNewToken.TokenType := ttGreaterThan;

    fcTokenList.Insert(liIndex + 1 , lcNewToken);
  end;
end;


{ helper proc for RecogniseTypedConstant
  need to distinguish
  "expr" from "(expr, expr)"
  note that expr can -> (expr)
  so we need to notice the comma
  is there a semicolon first or a comma

  Array of records can be "((f: 1), (f: 2))"
  and if it is an array with one element then it is "((f: x))"

  Is  more deeply nested comma valid in non-array expressions?
}

function TBuildParseTree.ArrayConstantNext: boolean;
var
  liIndex: integer;
  liBracketLevel: integer;
  tt:      TTokenType;
begin
  Result := False;

  if fcTokenList.FirstSolidTokenType <> ttOpenBracket then
    exit;

  liBracketLevel := 0;
  liIndex := fcTokenList.CurrentTokenIndex;
  // scan past the open bracket
  while fcTokenList.SourceTokens[liIndex].TokenType <> ttOpenBracket do
    Inc(liIndex);

  if fcTokenList.SourceTokens[liIndex].TokenType = ttOpenBracket then
  begin
    inc(liBracketLevel);
    Inc(liIndex);
  end;
  
  // look forward to find the first comma or semicolon
  while True do
  begin
    if liIndex >= fcTokenList.Count then
      break;

    tt := fcTokenList.SourceTokens[liIndex].TokenType;

    if tt = ttOpenBracket then
      Inc(liBracketLevel)
    else if tt = ttCloseBracket then
      Dec(liBracketLevel)
    else if (tt = ttComma) then // and (liBracketLevel = 1) then
    begin
      Result := True;
      break;
    end
    else if (tt = ttSemicolon) and (liBracketLevel = 0) then
    begin
      Result := False;
      break;
    end
      { if we get an semicolon at bracket level 2, it means an array of records
        e.g.
          Const MyFooRecArray = ((x: 2; y:3), (x: 5; y: 6)); }
    else if (tt = ttSemicolon) and (liBracketLevel = 2) then
    begin
      Result := True;
      break;
    end;

    Inc(liIndex);

    if (liBracketLevel = 0)  then
    begin
      Result := False;
      break;
    end;
  end;

end;

procedure TBuildParseTree.RecogniseTypedConstant;
begin
  { TypedConstant -> (ConstExpr | ArrayConstant | RecordConstant)

   How to tell these apart?

   The record constant must start with open brackets, a field name followed by a colon,
   e.g.   "AREC: TMap = (s1: 'Foo'; i1: 1; i2: 4);"
    No complexity is permitted here. All that can vary is the names

    Array and normal constants are trickier, as both can start with an
    arbitrary number of open brackets
    a normal constant is an expression, and an array constant is a
    bracketed comma-sperated list of them
    You can't look for the word 'array' in the just-parsed text
    as an alias type could be used
   }
  if (fcTokenList.FirstSolidTokenType = ttOpenBracket) and
    (fcTokenList.SolidWordType(2) in IdentifierTypes) and
    (fcTokenList.SolidTokenType(3) = ttColon) then
  begin
    RecogniseRecordConstant;
  end
  else if (ArrayConstantNext) then
  begin
    RecogniseArrayConstant
  end
  else
    RecogniseConstantExpression;
end;

procedure TBuildParseTree.RecogniseArrayConstant;
begin
  // ArrayConstant -> '(' TypedConstant/','... ')'

  PushNode(nArrayConstant);

  Recognise(ttOpenBracket);

  RecogniseTypedConstant;
  while (fcTokenList.FirstSolidTokenType = ttComma) do
  begin
    Recognise(ttComma);
    RecogniseTypedConstant;
  end;

  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseRecordConstant;
begin
  // RecordConstant -> '(' RecordFieldConstant/';'... ')'

  PushNode(nRecordConstant);

  Recognise(ttOpenBracket);

  RecogniseRecordFieldConstant;
  while (fcTokenList.FirstSolidTokenType = ttSemicolon) do
  begin
    Recognise(ttSemicolon);

    if fcTokenList.FirstSolidTokenType = ttCloseBracket then
      break;

    RecogniseRecordFieldConstant;
  end;

  Recognise(ttCloseBracket);
  PopNode;
end;

procedure TBuildParseTree.RecogniseRecordFieldConstant;
begin
  // RecordFieldConstant -> Ident ':' TypedConstant

  PushNode(nRecordFieldConstant);

  RecogniseIdentifier(False, idAllowDirectives);
  Recognise(ttColon);
  RecogniseTypedConstant;

  PopNode;
end;

procedure TBuildParseTree.RecogniseType;
var
  lc, lc2: TSourceToken;
begin
  {
  Type
    -> TypeId
    -> SimpleType
    -> StrucType
    -> PointerType
    -> StringType
    -> ProcedureType
    -> VariantType
    -> ClassRefType

    NB: const can be a psuedo-type in params
    e.g. "procedure fred(foo: const);"
  }

  PushNode(nType);

  lc  := fcTokenList.FirstSolidToken;
  lc2 := fcTokenList.SolidToken(2);

  if (lc.TokenType = ttType) then
  begin
    { this can be a prefix. See help under "Declaring types".
      an e.g. is in TestDeclarations.pas }
    Recognise(ttType);
  end;

  { Adem Baba - used case for speed
      not sure this is faster. But it does avoid mixing tokentypes in the conditionals}
  case lc.TokenType of
    ttConst: Recognise(ttConst);
    ttReal48, ttReal, ttSingle, ttDouble, ttExtended, ttCurrency, ttComp,
    ttShortInt, ttSmallInt, ttInteger, ttByte, ttLongInt, ttInt64, ttWord,
    ttBoolean, ttByteBool, ttWordBool, ttLongBool,
    ttChar, ttWideChar, ttLongWord, ttPChar, ttCardinal, ttNativeInt, ttNativeUInt,
    ttInt8, ttInt16, ttInt32, ttUInt8, ttUInt16, ttUInt32, ttUInt64, ttAnsiChar,
    ttUnicodeChar, ttPAnsiChar, ttPUnicodeChar, ttPWideChar, ttPByte, ttPShortString:
      RecogniseSimpleType; {RealTypes + OrdTypes}
    ttOpenBracket:
      RecogniseSimpleType; {enumerated types}
    ttPacked:
    begin
      // packed can be applied to class types and to structured types (e.g. records)
      if lc2.TokenType = ttClass then
      begin
        RecogniseClassType;
      end
      else if lc2.TokenType = ttObject then
      begin
        RecogniseObjectType;
      end
      else
      begin
        RecogniseStrucType;
      end;
    end;

    ttArray, ttSet, ttFile, ttRecord:
          RecogniseStrucType;
    ttSpecialize:
      RecogniseSpecializeType;
    ttHat:
      RecognisePointerType;
    ttString, ttAnsiString, ttWideString, ttShortString,
    ttUnicodeString, ttUtf8String, ttUtf16String, ttRawByteString:
      RecogniseStringType; {StringWords}
    ttProcedure, ttFunction:
      RecogniseProcedureType;
    ttVariant, ttOleVariant:
      RecogniseVariantType; {VariantTypes}
    else
      if (lc.TokenType = ttClass) and (lc2.TokenType = ttOf) then
      begin
        RecogniseClassRefType;
      end else
      if (lc.TokenType = ttReference) and (lc2.TokenType = ttTo) then
      begin
        RecogniseMethodReferenceType;
      end
      else if (lc.WordType in IdentifierTypes) or (lc.TokenType = ttAmpersand) then
      begin
        { could be a subrange on an enum,
          e.g. "clBlue .. clBlack".
          NB: this can also be Low(Integer) .. High(Integer)
          or <expr> .. <expr>
          }
        if SubrangeTypeNext then
          RecogniseSubRangeType
        else
          // some previously declared type that this simple prog does not know of
          RecogniseTypeId;
      end
      else
        RecogniseSimpleType;
  end;

  PopNode;
end;

function TBuildParseTree.SubrangeTypeNext: boolean;
var
  lc: TSourceToken;
begin
  lc  := fcTokenList.FirstSolidToken;
  result :=
    AnsiSameText(lc.SourceCode, 'Low') or
    (fcTokenList.SolidTokenType(2) = ttDoubleDot);

{

 - not needed
var
  liIndex: integer;
  leType: TTokenType;
begin
  liIndex := fcTokenList.CurrentTokenIndex;

  // which comes first, a ".." or a ";"

  Result := False;


  while True do
  begin
    if liIndex >= fcTokenList.Count then
      break;

    leType := fcTokenList.SourceTokens[liIndex].TokenType;

    if leType = ttSemicolon then
      break;

    if leType = ttDoubleDot then
    begin
      Result := True;
      break;
    end;


    inc(liIndex);
  end;
  }

end;

procedure TBuildParseTree.RecogniseRestrictedType;
var
  lc: TSourceToken;
begin
  {
  RestrictedType
    -> ObjectType
    -> ClassType
    -> InterfaceType
  }

  PushNode(nRestrictedType);

  lc := fcTokenList.FirstSolidToken;
  case lc.TokenType of
    ttObject:
      RecogniseObjectType;
    ttClass:
      RecogniseClassType;
    ttInterface, ttDispInterface:
      RecogniseInterfaceType;
    else
      raise TEParseError.Create('Expected object, class or interface', lc);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassRefType;
begin
  // ClassRefType -> CLASS OF TypeId

  Recognise(ttClass);
  Recognise(ttOf);
  RecogniseTypeId;
end;

procedure TBuildParseTree.RecogniseSimpleType;
var
  lc: TSourceToken;
begin
  // SimpleType -> (OrdinalType | RealType)

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType in RealTypes then
    RecogniseRealType
  else
    RecogniseOrdinalType;
end;

procedure TBuildParseTree.RecogniseRealType;
begin
  { RealType
     -> REAL48
     -> REAL
     -> SINGLE
     -> DOUBLE
     -> EXTENDED
     -> CURRENCY
     -> COMP
  }
  Recognise(RealTypes);
end;

procedure TBuildParseTree.RecogniseOrdinalType;
var
  lc: TSourceToken;
begin
  // OrdinalType -> (SubrangeType | EnumeratedType | OrdIdent)

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttOpenBracket then
    RecogniseEnumeratedType
  else if lc.TokenType in OrdTypes then
    RecogniseOrdIdent
  else
    RecogniseSubRangeType;
end;

procedure TBuildParseTree.RecogniseOrdIdent;
begin
  {
   OrdIdent
     -> SHORTINT
     -> SMALLINT
     -> INTEGER
     -> BYTE
     -> LONGINT
     -> INT64
     -> WORD
     -> BOOLEAN
     -> CHAR
     -> WIDECHAR
     -> LONGWORD
     -> PCHAR
    }
  Recognise(OrdTypes);
end;

procedure TBuildParseTree.RecogniseVariantType;
begin
  {
    VariantType
      -> VARIANT
      -> OLEVARIANT
  }

  Recognise(VariantTypes);

end;

procedure TBuildParseTree.RecogniseSubrangeType;
begin
  { SubrangeType -> ConstExpr '..' ConstExpr
    this fails when an array is indexed on an entire type, eg
    'BoolArray: array[Boolean] of Boolean;'
  }
  PushNode(nSubrangeType);

  RecogniseConstantExpression;
  if fcTokenList.FirstSolidTokenType = ttDoubleDot then
  begin
    Recognise(ttDoubleDot);

    { recognising any expr is a bad idea here, as "a = 3" is an expression
      and we want this to end with a '='
      this could be "const ValidCharSet: set of 'A'..'z' = ['A'..'Z','a'..'z'];"

       }
    RecogniseExpr(False);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseEnumeratedType;
begin
  // EnumeratedType -> '(' IdentList ')'
  PushNode(nEnumeratedType);

  Recognise(ttOpenBracket);
  RecogniseIdentList(False);
  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseStringType;
begin
  {
    StringType
      -> STRING
       -> ANSISTRING
       -> WIDESTRING
       -> STRING '[' ConstExpr ']'
   }

  if fcTokenList.FirstSolidTokenType = ttString then
  begin
    Recognise(ttString);
    if fcTokenList.FirstSolidTokenType = ttOpenSquareBracket then
    begin
      // e.g. var f = String[30];
      Recognise(ttOpenSquareBracket);
      RecogniseConstantExpression;
      Recognise(ttCloseSquareBracket);

    end;
  end
  else
    Recognise(StringWords);
end;

//Recognise specialize keyword in type definition (for fpc)
procedure TBuildParseTree.RecogniseSpecializeType;
begin
 Recognise(ttSpecialize);
 RecogniseType;
end;

procedure TBuildParseTree.RecogniseStrucType;
var
  lc: TSourceToken;
begin
  // StrucType -> [PACKED] (ArrayType | SetType | FileType | RecType)

  if fcTokenList.FirstSolidTokenType = ttPacked then
    Recognise(ttPacked);

  lc := fcTokenList.FirstSolidToken;

  case lc.TokenType of
    ttArray:
      RecogniseArrayType;
    ttSet:
      RecogniseSetType;
    ttFile:
      RecogniseFileType;
    ttRecord:
      RecogniseRecordType;
    else
      raise TEParseError.Create('Expected array, set, file or record type', lc);
  end;
end;

procedure TBuildParseTree.RecogniseArrayType;
var
  lcType: TTokenType;
begin
  // ArrayType -> ARRAY ['[' OrdinalType/','... ']'] OF Type
  PushNode(nArrayType);

  Recognise(ttArray);

  if fcTokenList.FirstSolidTokenType = ttOpenSquarebracket then
  begin
    Recognise(ttOpenSquareBracket);

    { Maybe just empty bracket with comma inside
      Possible syntaxes for dotNET dynamic array :
       -> array[]
       -> array[,]
       -> array[x,e]
    }
    while fcTokenList.FirstSolidTokenType = ttComma do
      Recognise(ttComma);

    lcType := fcTokenList.FirstSolidTokenType;
    if lcType = ttCloseSquareBracket then
    begin
      // Delphi.net can have dynamic arrays
    end
    else
    begin
      RecogniseOrdinalType;
      while fcTokenList.FirstSolidTokenType = ttComma do
      begin
        Recognise(ttComma);
        RecogniseOrdinalType;
      end;
    end;

    Recognise(ttCloseSquareBracket);
  end;

  Recognise(ttOf);
  RecogniseType;

  PopNode;
end;

procedure TBuildParseTree.RecogniseRecordType;
var
  lcType: TTokenType;
begin
  {
    RecType -> RECORD [FieldList] END

    Also in Delphi.net it can be a forward declaration e.g.
      "TRecord1 = record;"
  }

  PushNode(nRecordType);

  Recognise(ttRecord);

  lcType := fcTokenList.FirstSolidTokenType;

  if lcType = ttSemiColon then
  begin                     

  end
  else
  begin
    RecogniseRecordBody;
    Recognise(ttEnd);
  end;

  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseRecordBody;
var
  lcNextToken: TSourceToken;
begin
  lcNextToken := fcTokenList.FirstSolidToken;

  if lcNextToken.TokenType = ttEnd then
    exit;

  RecogniseFieldList;

  lcNextToken := fcTokenList.FirstSolidToken;

  { delphi.net records can have public and private parts }
  while lcNextToken.TokenType in ClassVisibility + [ttStrict, ttClass] do
  begin
    PushNode(nClassVisibility);
    RecogniseClassVisibility;
    RecogniseFieldList;
    PopNode;

    lcNextToken := fcTokenList.FirstSolidToken;
  end;

end;

{ recognise the fields of a record }
procedure TBuildParseTree.RecogniseFieldList;
var
  lcNextToken: TSourceToken;
  lcVarSection:boolean;  
begin
  // FieldList ->  FieldDecl/';'... [VariantSection] [';']
  lcNextToken := fcTokenList.FirstSolidToken;

  while not (lcNextToken.TokenType in [ttEnd, ttCase, ttCloseBracket, ttStrict] + ClassVisibility) do
  begin
    case lcNextToken.TokenType of
      ttProcedure:
        RecogniseProcedureHeading(False, False);
      ttFunction:
        RecogniseFunctionHeading(False, False);
      ttConstructor:
        RecogniseConstructorHeading(True);
      ttDestructor:
        RecogniseDestructorHeading(True);
      ttClass:
      begin
        lcVarSection:=fcTokenList.SolidTokenType(2) in [ttVar,ttThreadVar];
        RecogniseRecordStaticItem;
        if lcVarSection then
        begin
          lcNextToken := fcTokenList.FirstSolidToken;
          continue;
        end;		
      end;
      ttProperty:
        RecogniseProperty;
      // nested types.
      ttType:
      begin
        RecogniseTypeSection(true);
        lcNextToken := fcTokenList.FirstSolidToken;
        continue;
      end;
      ttVar, ttThreadVar:
      begin
        RecogniseVarSection(True);
        lcNextToken := fcTokenList.FirstSolidToken;
        continue;
      end;
      ttConst:
      begin
        RecogniseConstSection(true);
        lcNextToken := fcTokenList.FirstSolidToken;
        continue;
      end
      else
        RecogniseFieldDecl;
    end;

    lcNextToken := fcTokenList.FirstSolidToken;

    if lcNextToken.TokenType = ttSemicolon then
    begin
      Recognise(ttSemicolon);
      lcNextToken := fcTokenList.FirstSolidToken;
    end
    else
      Break;
  end;

  if lcNextToken.TokenType = ttCase then
  begin
    RecogniseVariantSection;
    lcNextToken := fcTokenList.FirstSolidToken;
  end;

  if lcNextToken.TokenType = ttSemicolon then
    Recognise(ttSemicolon);
end;

procedure TBuildParseTree.RecogniseRecordStaticItem;
var
  lcNextItem: TSourceToken;
begin
  lcNextItem := fcTokenList.SolidToken(2);

  case lcNextItem.TokenType of
    ttOperator:
      RecogniseClassOperator(False);
    ttProcedure:
    begin
      PushNode(nFunctionDecl);
      RecogniseProcedureHeading(false, false);
      PopNode;
    end;
    ttFunction:
    begin
      PushNode(nFunctionDecl);
      RecogniseFunctionHeading(false, false);
      PopNode;
    end;
    ttConstructor:
    begin
      PushNode(nConstructorDecl);
      RecogniseConstructorHeading(true);
      PopNode;
    end;
    ttDestructor:
    begin
      PushNode(nDestructorDecl);
      RecogniseDestructorHeading(true);
      PopNode;
    end;
    ttProperty:
    begin
      PushNode(nProperty);
      RecogniseProperty;
      PopNode;
    end;
    ttVar,ttThreadVar:
    begin
      RecogniseVarSection(true);
    end;
  end;
end;

procedure TBuildParseTree.RecogniseFieldDecl;
begin
  // FieldDecl -> IdentList ':' Type
  PushNode(nFieldDeclaration);

  RecogniseIdentList(False);
  Recognise(ttColon);
  RecogniseType;

  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseVariantSection;
begin
  PushNode(nRecordVariantSection);

  // VariantSection -> CASE [Ident ':'] TypeId OF RecVariant/';'...
  Recognise(ttCase);

  // is there an 'of' 2 tokens hence? If not, must be 'ident:' first
  if not (fcTokenList.SolidTokenType(2) = ttOf) then
  begin
    RecogniseIdentifier(False, idAllowDirectives);
    Recognise(ttColon);
  end;

  RecogniseTypeId;
  Recognise(ttOf);

  // I have tested and that there must be at least 1 case in a var section
  repeat
    RecogniseRecVariant;

    // semicolon is optional on the last one
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon)
    else
      break;

  until (fcTokenList.FirstSolidTokenType in [ttEnd, ttCloseBracket]);

  PopNode;
end;

procedure TBuildParseTree.RecogniseRecVariant;
begin
  // RecVariant -> ConstExpr/','...  ':' '(' [FieldList] ')'

  PushNode(nRecordVariant);

  RecogniseConstantExpression;
  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseConstantExpression;
  end;

  Recognise(ttColon);
  Recognise(ttOpenBracket);

  if fcTokenList.FirstSolidTokenType <> ttCloseBracket then
    RecogniseFieldList;

  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseSetType;
begin
  { SetType -> SET OF OrdinalType

  cannot limit it to ord types, as this will not parse the below:

  e.g.
    type
    TFoo = 1..20;
    TBars = (monkey, williamshatnir, soy);

    TFooSet = set of TFoo;
    TBarSet = set of TBar;
  }

  PushNode(nSetType);

  Recognise(ttSet);
  Recognise(ttOf);

  //RecogniseOrdinalType;
  RecogniseType;

  PopNode;
end;

procedure TBuildParseTree.RecogniseFileType;
begin
  {
   FileType -> FILE OF TypeId

   also just plain 'file'
  }

  Recognise(ttFile);
  if fcTokenList.FirstSolidTokenType = ttOf then
  begin
    Recognise(ttOf);
    RecogniseTypeId;
  end;
end;

procedure TBuildParseTree.RecognisePointerType;
var
  wTT:TTokenType;
begin
  // PointerType -> '^' TypeId
  Recognise(ttHat);
  RecogniseTypeId;

  wTT:=fcTokenList.FirstSolidTokenType;
  if (wTT = ttSemiColon) then
  begin
    if fcTokenList.SolidTokenType(2)=ttNear then
    begin
      Recognise(ttSemiColon);
      Recognise(ttNear);
      // segment  'CS' 'DS' 'ES' 'SS' 'FS' 'GS'
      if fcTokenList.FirstSolidTokenType = ttQuotedLiteralString then
        Recognise(ttQuotedLiteralString);
    end
    else
    if (fcTokenList.SolidTokenType(2)=ttFar) then
    begin
      Recognise(ttSemiColon);
      Recognise(ttFar);
    end
    else if (fcTokenList.SolidTokenType(2)=ttHuge) then
    begin
      Recognise(ttSemiColon);
      Recognise(ttHuge);
    end;
  end;
end;

procedure TBuildParseTree.RecogniseProcedureType;
begin
  PushNode(nProcedureType);

  // ProcedureType -> (ProcedureHeading | FunctionHeading) [OF OBJECT]
  if fcTokenList.FirstSolidTokenType = ttProcedure then
    RecogniseProcedureHeading(True, False)
  else if fcTokenList.FirstSolidTokenType = ttFunction then
    RecogniseFunctionHeading(True, False)
  else
    raise TEParseError.Create('Expected procedure or function type',
      fcTokenList.FirstSolidToken);

  if fcTokenList.FirstSolidTokenType = ttOf then
  begin
    Recognise(ttOf);
    Recognise(ttObject);
  end;

  RecogniseProcedureDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseVarSection(const pbClassVars: boolean);
const
  END_VAR_SECTION: TTokenTypeSet =
    [ttVar, ttThreadVar, ttConst, ttLabel, ttResourceString, ttType,
    ttBegin, ttEnd, ttImplementation, ttInitialization,
    ttProcedure, ttFunction, ttOperator, ttConstructor, ttDestructor, ttClass, ttAsm, ttGeneric, ttCase];
var
  leEndVarSection: TTokenTypeSet;
begin
  leEndVarSection := END_VAR_SECTION;
  if pbClassVars then
    leEndVarSection := leEndVarSection + ClassVisibility + [ttStrict];

  if pbClassVars and (fcTokenList.FirstSolidTokenType=ttClass) then
  begin
    PushNode(nClassVars);
    Recognise(ttClass);
  end
  else
    PushNode(nVarSection);

  // VarSection -> VAR (VarDecl ';')...
  Recognise([ttVar, ttThreadvar]);

  // can be empty
  while not (fcTokenList.FirstSolidTokenType in leEndVarSection) do
  begin
    RecogniseVarDecl;
    Recognise(ttSemicolon);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassOperator(const pbHasBody: boolean);
begin
  PushNode(nFunctionDecl);
  PushNode(nFunctionHeading);
  Recognise(ttClass);
  Recognise(ttOperator);

  RecogniseMethodName(False);
  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  //Managed records have operators without return
  // Initialize, Finalize, Copy, AddRef.
  if fcTokenList.FirstSolidTokenType = ttColon then
  begin
    Recognise(ttColon);
    PushNode(nFunctionReturnType);
    RecogniseType;
    PopNode;
  end;
  RecogniseProcedureDirectives;
  PopNode;
  if pbHasBody then
  begin
    Recognise(ttSemiColon);
    RecogniseBlock;
    Recognise(ttSemiColon);
  end;
  PopNode;
end;

{
This is a free-pascal style operator
}
procedure TBuildParseTree.RecogniseOperator(const pbHasBody: boolean);
begin
  PushNode(nFunctionDecl);
  PushNode(nFunctionHeading);
  Recognise(ttOperator);

  CheckEnumeratorToken();
  RecogniseOperatorSymbol();

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  // FreePascal can give a name to "result" here
  if fcTokenList.FirstSolidTokenType <> ttColon then
  begin
    RecogniseIdentifier(false, idAny);
  end;

  Recognise(ttColon);
  PushNode(nFunctionReturnType);
  RecogniseType;
  PopNode;

  RecogniseProcedureDirectives;

  PopNode;

  if pbHasBody then
  begin
    Recognise(ttSemiColon);
    RecogniseBlock;
    Recognise(ttSemiColon);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseOperatorSymbol;
const
  OperatorTokens: TTokenTypeSet = [ttPlus, ttMinus, ttTimes, ttFloatDiv, ttExponent,
    ttEquals, ttGreaterThan, ttLessThan, ttGreaterThanOrEqual, ttLessThanOrEqual,
    ttAssign, ttPlusAssign, ttMinusAssign, ttTimesAssign, ttFloatDivAssign, ttXor,
    ttAnd, ttOr, ttEnumerator, ttNot, ttDiv, ttMod, ttIn, ttShl, ttShr];
begin
  Recognise(OperatorTokens);
end;

procedure TBuildParseTree.RecogniseVarDecl;
var
  lc: TSourceToken;
begin
  // (* attempted EBNF definition of a variable definition *)
  // named : 'name' var_name
  // exppubl : ( 'export' | 'public' ) [named] ';'
  // external : ( 'external' [[lib_name] [named]] ';'
  // absolute : 'absolute' var_name
  // absolute : 'absolute' expression
  // initvalue : '=' ConstExpr
  // hints : [ 'deprecated'
  // | 'experimental'
  // | 'platform'
  // | 'unimplemented' ]
  // identlist : var_name { ',' var_name }
  //
  // vardef : identlist ':' vartype [ absolute ] ';'
  // [( exppubl | external )] [ hints ]

  PushNode(nVarDecl);

  RecogniseIdentList(False);
  Recognise(ttColon);
  RecogniseType;

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttAbsolute then
  begin
    PushNode(nVarAbsolute);
    Recognise(ttAbsolute);
    RecogniseConstantExpression;
    PopNode;
  end
  else
  begin
    RecogniseHintDirectives;

    if fcTokenList.FirstSolidTokenType = ttEquals then
    begin
      PushNode(nVariableInit);

      Recognise(ttEquals);

      { not just an expr - can be an array, record or the like
        reuse the code from typed constant declaration as it works the same
      }
      RecogniseTypedConstant;

      PopNode;
    end;
  end;

  { yes, they can occur here too }
  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseExpr(const pbAllowRelop: boolean);
begin
  { Expression -> SimpleExpression [RelOp SimpleExpression]...

    nb this doesn't parse
    lb := foo.Owner;
  }

  PushNode(nExpression);

  RecogniseSimpleExpression;

  if pbAllowRelop then
  begin
    while fcTokenList.FirstSolidTokenType in RelationalOperators do
    begin
      RecogniseRelop;
      RecogniseSimpleExpression;
    end;
  end;

  // added this to cope with real usage - see TestCastSimple
  if fcTokenList.FirstSolidTokenType = ttDot then
  begin
    Recognise(ttDot);
    RecogniseExpr(True);
  end;

  //likewise need to cope with pchar(foo)^
  if fcTokenList.FirstSolidTokenType = ttHat then
  begin
    Recognise(ttHat);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseSimpleExpression;
{var
  lc: TSourceToken;}
begin
  { SimpleExpression -> ['+' | '-'] Term [AddOp Term]...

    the plus/minus prefix is a red herring
    RecogniseFactor does that with a unary operator
  }

{
  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = wMinus then
    Recognise(wMinus)
  else if lc.TokenType = wPlus then
    Recognise(wPlus);
 }
  RecogniseTerm;
  while fcTokenList.FirstSolidTokenType in AddOperators do
  begin
    RecogniseAddOp;
    RecogniseTerm;
  end;
end;

procedure TBuildParseTree.RecogniseTerm;
begin
  // Term -> Factor [MulOp Factor]...

  PushNode(nTerm);

  RecogniseFactor;

  while fcTokenList.FirstSolidTokenType in MulOperators do
  begin
    RecogniseMulOp;
    RecogniseFactor;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseFactor;
var
  lc: TSourceToken;
begin
  {
  Factor
    -> Designator ['(' ExprList ')']
    -> '' Designator
    -> Number
    -> String
    -> NIL
    -> '(' Expression ')'
    -> NOT Factor
    -> SetConstructor
    -> TypeId '(' Expression ')'

    What is that second line??

    What about unary operators other than not,
    e.g. b := b * -2;
    PossiblyUnarySymbolOperators

    Can also be fn call with no params but with the optional braces,
      e.g. "Foo();"

      or a call to an inherited fucntion, e.g. "inherited foo();
      Note that the function name can be omitted "
   }
  lc := fcTokenList.FirstSolidToken;
  if lc.TokenType = ttSpecialize then
  begin
    Recognise(ttSpecialize);
    lc := fcTokenList.FirstSolidToken;
  end;
  if AnonymousMethodNext then
  begin
    RecogniseAnonymousMethod;
  end
  else if lc.TokenType = ttInherited then
  begin
    Recognise(ttInherited);

    if not (fcTokenList.FirstSolidTokenType in Operators + [ttSemicolon]) then
    begin
      RecogniseDesignator;
      if fcTokenList.FirstSolidTokenType = ttOpenBracket then
      begin
        RecogniseActualParams;
      end;
    end;
  end
  else if (lc.TokenType = ttNumber) then
  begin
    Recognise(ttNumber);
  end
  else if (lc.TokenType in LiteralStringStarters) then
  begin
    RecogniseLiteralString;
  end
  else if (lc.TokenType in BuiltInConstants) then
  begin
    // nil, true, false
    Recognise(BuiltInConstants);
  end
  else if (lc.TokenType = ttOpenBracket) then
  begin
    Recognise(ttOpenBracket);

    while fcTokenList.FirstSolidTokenType = ttComma do
      Recognise(ttComma);

    { can be empty brackets }
    if fcTokenList.FirstSolidTokenType <> ttCloseBracket then
    begin
      RecogniseExpr(True);

      {  Delphi dotNET : or bracket with initilizer separated by comma
       Example : the New method parameters to initialize a dynamic array}
      while fcTokenList.FirstSolidTokenType = ttComma do
      begin
        Recognise(ttComma);
        RecogniseExpr(True);
      end;
    end;

    Recognise(ttCloseBracket);
  end
  else if (lc.TokenType = ttNot) then
  begin
    Recognise(ttNot);
    RecogniseFactor;
  end
  else if lc.TokenType in PossiblyUnarySymbolOperators then
  begin
    RecogniseUnarySymbolFactor;
  end
  else if (lc.TokenType = ttOpenSquareBracket) then
  begin
    RecogniseSetConstructor;
  end
  // try identifiers last, since liberal identifiers may match text tokens above
  // can prefix with an '&' to force it to be an identifier not a keyword
  else if (lc.TokenType = ttAmpersand) or IsIdentifierToken(lc, idAny) then
  begin
    if lc.TokenType = ttAmpersand then
      Recognise(ttAmpersand);

    RecogniseDesignator;
    if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    begin
      RecogniseActualParams;
    end
    else if fcTokenList.FirstSolidTokenType = ttLessThan then
    begin
      // check for a generic type
      if GenericAhead then
      begin
        // a type constructor - specifying types for the generic
        RecogniseGenericType();
      end;
      
    end;
         
  end

  else
    raise TEParseError.Create('unexpected token in factor', lc);

  { can't use lc for FirstSolidToken any more, have moved on }
  if fcTokenList.FirstSolidTokenType in [ttHat, ttDot, ttOpenSquareBracket] then
  begin
    RecogniseDesignatorTail;
  end
  else if fcTokenList.FirstSolidTokenType = ttOpenBracket then
  begin
    // following an anonymous method
    RecogniseActualParams;
  end;

end;

procedure TBuildParseTree.RecogniseUnarySymbolFactor;
var
  lc2: TSourceToken;
  lbOldStyleCharEscape: boolean;
begin
  {!!! special undocumented syntax held from Turbopascal
   A char constant can be represented by '^G' for a ctrl-g char etc
   This caused problems when it is the likes of '^@' or '^]'

   see Sourceforge bugs #888862, #913439
   and test case code in TestCharLiterals.pas
   }
  lbOldStyleCharEscape := False;
  if fcTokenList.FirstSolidTokenType = ttHat then
  begin
    lc2 := fcTokenList.SolidToken(2);
    lbOldStyleCharEscape := (lc2 <> nil) and (Length(lc2.Sourcecode) = 1) and
      not (CharIsAlpha(lc2.Sourcecode[1]));
  end
  else
    lc2 := nil;

  if lbOldStyleCharEscape then
  begin
    { bizarre char constant }
    Recognise(ttHat);
    Recognise(lc2.TokenType);
  end
  else
  begin
    { normal path }
    PushNode(nUnaryOp);
    Recognise(PossiblyUnarySymbolOperators);
    RecogniseFactor;
    PopNode;
  end;

end;

procedure TBuildParseTree.RecogniseRelOp;
var
  lc: TSourceToken;
begin
  {RelOp
  -> '>'
  -> '<'
  -> '<='
  -> '>='
  -> '<>'
  -> IN
  -> IS
  -> AS
  }

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType in RelationalOperators then
    Recognise(RelationalOperators)
  else
    raise TEParseError.Create('unexpected token in rel op', lc);
end;

procedure TBuildParseTree.RecogniseAddOp;
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType in AddOperators then
    Recognise(AddOperators)
  else
    raise TEParseError.Create('unexpected token in add op', lc);
end;

procedure TBuildParseTree.RecogniseAnonymousMethod;
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;

  PushNode(nAnonymousMethod);

  case lc.TokenType of
    ttProcedure:
      RecogniseProcedureDecl(true);
    ttFunction:
      RecogniseFunctionDecl(true);
    else
      raise TEParseError.Create('unexpected token in RecogniseAnonymousMethod', lc);
  end;


  PopNode;
end;

procedure TBuildParseTree.RecogniseMulOp;
var
  lc: TSourceToken;
begin
  {
  MulOp
    -> '*'
    -> '/'
    -> DIV
    -> MOD
    -> AND
    -> SHL
    -> SHR

  }
  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType in MulOperators then
    Recognise(MulOperators)
  else
    raise TEParseError.Create('unexpected token in mul op', lc);
end;

procedure TBuildParseTree.RecogniseDesignator;
var
  lc: TSourceToken;
begin
  { Designator -> QualId ['.' Ident | '[' ExprList ']' | '^']...

    Need brackets here too for hard typecasts like
      pointer(foo)

    And can be an anonymous function/procedure
  }
  PushNode(nDesignator);

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttAtSign then
  begin
    Recognise(ttAtSign);
  end;

  RecogniseQualId;

  lc := fcTokenList.FirstSolidToken;
   if (lc.TokenType = ttLessThan) and GenericAhead then
   begin
     RecogniseGenericType;
   end;

  RecogniseDesignatorTail;

  PopNode;
end;

{ Delphi.Net uses '&' to signal that the next token
  is not a reserved word,
  but is a CLR method of the same name
}
procedure TBuildParseTree.RecognisePossiblyAmpdIdentifier;
begin
  if fcTokenList.FirstSolidTokenType = ttAmpersand then
  begin
    Recognise(ttAmpersand);
    RecogniseIdentifier(False, idAny);
  end
  else
  begin
    RecogniseIdentifier(False, idAny);
  end;

end;

procedure TBuildParseTree.RecogniseDesignatorTail;
const
  DESIGNATOR_TAIL_TOKENS = [ttDot, ttOpenBracket, ttOpenSquareBracket, ttHat,
    ttPlus, ttMinus, ttAs];
begin

  while (fcTokenList.FirstSolidTokenType in DESIGNATOR_TAIL_TOKENS) do
  begin
    case fcTokenList.FirstSolidTokenType of
      ttDot:
      begin
        Recognise(ttDot);

        RecognisePossiblyAmpdIdentifier;

        if GenericAhead then
        begin
          RecogniseGenericType;
        end;

      end;
      ttHat:
      begin
        Recognise(ttHat);
          // and after the deref operator ?
      end;
      ttOpenSquareBracket:
      begin
        Recognise(ttOpenSquareBracket);
        RecogniseExprList;
        // partial array pass  Test(A[2..5]);
        if fcTokenList.FirstSolidTokenType=ttDoubleDot then
        begin
          Recognise(ttDoubleDot);
          RecogniseExprList;
        end;
        Recognise(ttCloseSquareBracket);
      end;
      ttOpenBracket:
      begin
        RecogniseActualParams;
      end;
      ttPlus, ttMinus:
      begin
        Recognise([ttPlus, ttMinus]);
        RecogniseExpr(True);
      end;
      ttAs:
      begin
        RecogniseAsCast;
      end;
      else
        Assert(False, 'Should not be here - bad token type');
    end;
  end;
end;

procedure TBuildParseTree.RecogniseSetConstructor;
begin
  // SetConstructor -> '[' [SetElement/','...] ']'

  Recognise(ttOpenSquareBracket);

  while fcTokenList.FirstSolidTokenType <> ttCloseSquareBracket do
  begin
    RecogniseSetElement;
    if fcTokenList.FirstSolidTokenType = ttComma then
      Recognise(ttComma)
    else
      break; // no comma -> no more items
  end;

  Recognise(ttCloseSquareBracket);
end;

procedure TBuildParseTree.RecogniseSetElement;
begin
  // SetElement -> Expression ['..' Expression]

  RecogniseExpr(True);
  if fcTokenList.FirstSolidTokenType = ttDoubleDot then
  begin
    Recognise(ttDoubleDot);
    RecogniseExpr(False);
  end;
end;

procedure TBuildParseTree.RecogniseExprList;
begin
  // ExprList -> Expression/','...

  RecogniseExpr(True);
  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseExpr(True);
  end;
end;

procedure TBuildParseTree.RecogniseStatement;
const
  BLOCK_END: TTokenTypeSet = [ttEnd, ttFinally, ttExcept, ttUntil];
var
  lc: TSourceToken;
  lct: TTokenType;
begin
  RecogniseNotSolidTokens;

  // Statement -> [LabelId ':'] [SimpleStatement | StructStmt]

  PushNode(nStatement);

  lct :=  fcTokenList.FirstSolidTokenType;

  if lct = ttSpecialize then
  begin
    Recognise(ttSpecialize);
    lct :=  fcTokenList.FirstSolidTokenType;
  end;

  if lct = ttSemicolon then
  begin
    // empty statement
    PopNode;
    Exit;
  end
  else if lct = ttEnd then
  begin
    PopNode;
    Exit;
  end;

  CheckLabelPrefix;

  lc := fcTokenList.FirstSolidToken;

  { anything more? can just be a label at the end of the proc/block }
  if not (lc.TokenType in BLOCK_END) then
  begin

    if lc.TokenType in StructStatementWords then
      RecogniseStructStmnt
    else
      RecogniseSimpleStmnt;
  end;

  PopNode;
end;

procedure TBuildParseTree.CheckLabelPrefix;
var
  lc2: TSourceToken;
  lbColonSecond: boolean;
begin
  lc2 := fcTokenList.SolidToken(2);
  lbColonSecond := (lc2.TokenType = ttColon);
  if lbColonSecond then
  begin
    PushNode(nStatementLabel);
    RecogniseLabel;
    Recognise(ttColon);
    PopNode;

    { can be followed by another label  }
    CheckLabelPrefix
  end

end;

procedure TBuildParseTree.RecogniseStatementList(const peEndTokens: TTokenTypeSet);
begin
  // StmtList -> Statement/';'...
  PushNode(nStatementList);

  while not (fcTokenList.FirstSolidTokenType in peEndTokens) do
  begin
    RecogniseStatement;

    // last semicolon is optional
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon)
    else
      break;
    
    RecogniseNotSolidTokens;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseSimpleStmnt;
var
  lc: TSourceToken;
begin
  {
  SimpleStatement
    -> Designator ['(' ExprList ')']
    -> Designator ':=' Expression
    -> INHERITED
    -> GOTO LabelId
    -> inline ()

    argh this doesn't take brackets into account
    as far as I can tell, typecasts like "(lcFoo as TComponent)" is a designator

    so is "Pointer(lcFoo)" so that you can do
    " Pointer(lcFoo) := Pointer(lcFoo) + 1;

    Niether does it take into account using property on returned object, e.g.
    qry.fieldbyname('line').AsInteger := 1;

    These can be chained indefinitely, as in
   foo.GetBar(1).Stuff['fish'].MyFudgeFactor.Default(2).Name := 'Jiim';

   you can also bracket the whole expression, as in
   "(CheckBox1.Checked := not CheckBox1.Checked);"
}

  lc := fcTokenList.FirstSolidToken;

  if  lc.TokenType = ttOpenBracket then
  begin
    RecogniseBracketedStatement;
    RecogniseDesignatorTail;

    if fcTokenList.FirstSolidTokenType in AssignmentDirectives then
    begin
      PushNode(nAssignment);

      Recognise(fcTokenList.FirstSolidTokenType);
      RecogniseExpr(True);
      
      PopNode;
    end;
  end
  else if (IdentifierNext(idAllowDirectives)) or (lc.TokenType = ttAtSign) then
  begin
    RecognisePossibleAssign;
    // else nothing at all is also ok. i.e. procedure call with no params
  end
  else if lc.TokenType = ttInherited then
  begin
    { can be one of
      "inherited;
      inherited Foo;
      inherited Foo(bar);
      inherited FooProp := bar;
      inherited FooProp[Bar] := Fish;
      bar :=  inherited FooProp[Bar];
      }

    Recognise(ttInherited);
    if IdentifierNext(idAllowDirectives) then
      RecogniseSimpleStmnt;
  end
  else if lc.TokenType = ttGoto then
  begin
    Recognise(ttGoto);
    RecogniseLabel;
  end
  else if lc.TokenType = ttRaise then
  begin
    RecogniseRaise;
  end
  else if lc.TokenType = ttInline then
  begin
    RecogniseInline;
  end
  else if lc.TokenType = ttSemicolon then
  begin
    // empty statement
    // this gets doen later in common code Recognise(ttSemicolon);
  end
  else
    raise TEParseError.Create('expected simple statement', lc);

end;

procedure TBuildParseTree.RecogniseBracketedStatement;
begin
  Recognise(ttOpenBracket);

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseBracketedStatement
  else
   RecognisePossibleAssign;

  Recognise(ttCloseBracket);
  RecogniseDesignatorTail;
end;

procedure TBuildParseTree.RecognisePossibleAssign;
begin
  // should be fullblown expression?
  RecogniseDesignator;

  RecogniseDesignatorTail;

  if TokenList.FirstSolidTokenType in AssignmentDirectives then
  begin
    PushNode(nAssignment);

    Recognise(TokenList.FirstSolidTokenType);
    RecogniseExpr(True);

    PopNode;
  end;

  if (fcTokenList.FirstSolidTokenType = ttAs) then
    RecogniseAsCast;
end;

procedure TBuildParseTree.RecogniseRaise;
begin
  // another omission - raise expr  or just raise (in except block)
  Recognise(ttRaise);
  if not (fcTokenList.FirstSolidTokenType in [ttSemicolon, ttEnd, ttElse]) then
    RecogniseExpr(True);

  // can be at addr
  if fcTokenList.FirstSolidTokenType = ttAt then
  begin
    Recognise(ttAt);
    RecogniseExpr(True);
  end;
end;

procedure TBuildParseTree.RecogniseInline;
begin
  { inline is not supported in Delphi,
    but occurs in some Turbo Pascal code.

    It is a primitive way to do inline machine code,
    by wedging in some literal bytes into the exe
  }

  PushNode(nInline);


  Recognise(ttInline);
  Recognise(ttOpenBracket);

  // inline body is some inline constants separated by '/'
  while fcTokenList.FirstSolidTokenType <> ttCloseBracket do
  begin
    RecogniseInlineItem;

    // floatdiv is the '/' char here 
    if fcTokenList.FirstSolidTokenType = ttFloatDiv then
      Recognise(ttFloatDiv);
  end;

  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseInlineItem;
begin
  PushNode(nInlineItem);

  // for not, accept anything up to the '/' or ')'

  while not (fcTokenList.FirstSolidTokenType in [ttFloatDiv, ttCloseBracket]) do
    Recognise(fcTokenList.FirstSolidTokenType);

  PopNode;
end;

procedure TBuildParseTree.RecogniseStructStmnt;
var
  lc: TSourceToken;
begin
  {
    StructStmt
      -> CompoundStmt
       -> ConditionalStmt
       -> LoopStmt
       -> WithStmt
    }

    { ConditionalStmt
        -> IfStmt
        -> CaseStmt
    }

   {
    LoopStmt
      -> RepeatStmt
     -> WhileStmt
     -> ForStmt
    }

    { they completely left out try blocks !}

  lc := fcTokenList.FirstSolidToken;

  case lc.TokenType of
    ttBegin:
      RecogniseCompoundStmnt;
    ttAsm:
      RecogniseAsmBlock;
    ttIf:
      RecogniseIfStmnt;
    ttCase:
      RecogniseCaseStmnt;
    ttRepeat:
      RecogniseRepeatStmnt;
    ttWhile:
      RecogniseWhileStmnt;
    ttFor:
      RecogniseForStmnt;
    ttWith:
      RecogniseWithStmnt;
    ttTry:
      RecogniseTryStatement;
    else
      raise TEParseError.Create('expected structured statement', lc);
  end;

end;

procedure TBuildParseTree.RecogniseCompoundStmnt;
begin
  { CompoundStmt -> BEGIN StmtList END }
  PushNode(nCompoundStatement);
  Recognise(ttBegin);
  RecogniseStatementList([ttEnd]);
  Recognise(ttEnd);
  PopNode;
end;

procedure TBuildParseTree.RecogniseIfStmnt;
begin
  // IfStmt -> IF Expression THEN Statement [ELSE Statement]

  Recognise(ttIf);

  PushNode(nIfCondition);
  RecogniseExpr(True);
  PopNode;

  Recognise(ttThen);

  PushNode(nIfBlock);

  { if body can be completely missing - go straight to else }
  if fcTokenList.FirstSolidTokenType <> ttElse then
    RecogniseStatement;
  PopNode;

  if fcTokenList.FirstSolidTokenType = ttElse then
  begin
    Recognise(ttElse);
    PushNode(nElseBlock);
    if not (fcTokenList.FirstSolidTokenType in [ttElse, ttEnd]) then
      RecogniseStatement;
    PopNode;
  end;
end;

procedure TBuildParseTree.RecogniseCaseStmnt;
begin
  // CaseStmt -> CASE Expression OF CaseSelector/';'... [ELSE / OTHERWISE Statement] [';'] END
  PushNode(nCaseStatement);

  Recognise(ttCase);

  PushNode(nBlockHeaderExpr);
  RecogniseExpr(True);
  PopNode;

  Recognise(ttOf);

  while not (fcTokenList.FirstSolidTokenType in [ttElse, ttOtherwise, ttEnd]) do
    RecogniseCaseSelector;

  if fcTokenList.FirstSolidTokenType in [ttElse, ttOtherwise] then
  begin
    PushNode(nElseCase);
    Recognise(fcTokenList.FirstSolidTokenType);
    RecogniseStatementList([ttEnd]);
    PopNode;
  end;

  if fcTokenList.FirstSolidTokenType = ttSemicolon then
    Recognise(ttSemicolon);

  Recognise(ttEnd);

  PopNode;
end;

procedure TBuildParseTree.RecogniseCaseSelector;
begin
  // CaseSelector -> CaseLabel/','... ':' Statement ';'

  PushNode(nCaseSelector);

  PushNode(nCaseLabels);
  RecogniseCaseLabel;

  while (fcTokenList.FirstSolidTokenType = ttComma) do
  begin
    Recognise(ttComma);
    RecogniseCaseLabel;
  end;

  Recognise(ttColon);
  PopNode;

  { semicolon is optional in the last case before the else }
  if not (fcTokenList.FirstSolidTokenType in [ttElse, ttEnd]) then
  begin
    RecogniseStatement;

    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseCaseLabel;
begin
  // CaseLabel -> ConstExpr ['..' ConstExpr]

  PushNode(nCaseLabel);

  RecogniseConstantExpression;
  if (fcTokenList.FirstSolidTokenType = ttDoubleDot) then
  begin
    Recognise(ttDoubleDot);
    RecogniseConstantExpression;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseRepeatStmnt;
begin
  { RepeatStmt -> REPEAT Statement UNTIL Expression

   Incorect - it is a statement list
  }
  PushNode(nRepeatStatement);

  Recognise(ttRepeat);
  RecogniseStatementList([ttUntil]);
  Recognise(ttUntil);

  PushNode(nLoopHeaderExpr);
  RecogniseExpr(True);
  PopNode;

  PopNode;
end;

procedure TBuildParseTree.RecogniseWhileStmnt;
begin
  // WhileStmt -> WHILE Expression DO Statement
  PushNode(nWhileStatement);

  Recognise(ttWhile);

  PushNode(nLoopHeaderExpr);
  RecogniseExpr(True);
  PopNode;

  Recognise(ttDo);
  RecogniseStatement;

  PopNode;
end;

procedure TBuildParseTree.RecogniseForStmnt;
var
  lc: TSourceToken;
  lCountBrackets:integer;
begin
  { ForStmt -> FOR QualId ':=' Expression (TO | DOWNTO) Expression DO Statement

    or Delphi 2005 syntax:
    ForStmt ->  FOR QualId 'in' Expression DO Statement

  }
  PushNode(nForStatement);

  Recognise(ttFor);
  RecogniseQualId;


  //type cast    for TCollectionItem(item) in ItemList do 
  // TypeCast1(TypeCast2(TypeCast3(item)))
  lCountBrackets:=0;
  while fcTokenList.FirstSolidTokenType=ttOpenBracket do
  begin
    Recognise(ttOpenBracket);
    RecogniseQualId;
    Inc(lCountBrackets);
  end;
  while lCountBrackets>0 do
  begin
    Recognise(ttCloseBracket);
    Dec(lCountBrackets);
  end;

  lc := fcTokenList.FirstSolidToken;
  if lc.TokenType = ttIn then
  begin
    // Delphi 2005 syntax
    Recognise(ttIn);
    RecogniseExpr(True);
  end
  else
  begin
    Recognise(ttAssign);

    PushNode(nLoopHeaderExpr);
    RecogniseExpr(True);
    PopNode;

    Recognise([ttTo, ttDownto]);

    PushNode(nLoopHeaderExpr);
    RecogniseExpr(True);
    PopNode;
  end;

  Recognise(ttDo);
  RecogniseStatement;

  PopNode;
end;

procedure TBuildParseTree.RecogniseWithStmnt;
begin
  { WithStmt -> WITH IdentList DO Statement

   it's not an identlist, but an expression list
  }
  PushNode(nWithStatement);

  Recognise(ttWith);

  //RecogniseIdentList;
  PushNode(nBlockHeaderExpr);
  RecogniseExprList;
  PopNode;

  Recognise(ttDo);
  RecogniseStatement;

  PopNode;
end;

procedure TBuildParseTree.RecogniseTryStatement;
var
  lc: TSourceToken;
begin
  { um. right, I'll have to wing this one
    as borland neglected to mention it at all

    TryStatement -> 'try' StatementList TryEnd

    TryEnd
      -> 'finally' StatementList 'end'
      -> except ExceptionHandlers 'end'
  }

  PushNode(nTryAndHandlerBlock);

  PushNode(nTryBlock);

  Recognise(ttTry);
  RecogniseStatementList([ttEnd, ttFinally, ttExcept]);

  PopNode;

  lc := fcTokenList.FirstSolidToken;
  case lc.TokenType of
    ttFinally:
    begin
      PushNode(nFinallyBlock);

      Recognise(ttFinally);
      RecogniseStatementList([ttEnd]);
      Recognise(ttEnd);

      PopNode;
    end;
    ttExcept:
    begin
      PushNode(nExceptBlock);

      Recognise(ttExcept);
      RecogniseExceptionHandlerBlock;

      // can be statements here - see SF bug 1314607
      if fcTokenList.FirstSolidTokenType <> ttEnd then
        RecogniseStatementList([ttEnd]);

      Recognise(ttEnd);

      PopNode;
    end
    else
      raise TEParseError.Create('expected except or finally', lc);

  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseExceptionHandlerBlock;
begin
  { um. Double-um
    can be a statement list
     or those 'on Excepttype' thingies
    ie

    try
      ...
    except
      ShowMessage('Foo');
    end

    or

    try
      ...
    except
      on TFooException do
        ShowMessage('Foo');
      on E: TBarException do
        ShowMessage('Bar');
      else
        ShowMessage('Else');
    end;

    here's the grammar

    ExceptionHandlers -> Statement
    ExceptionHandlers -> ExceptionSpecifier

  }
  RecogniseNotSolidTokens;

  PushNode(nExceptionHandlers);

  if fcTokenList.FirstSolidTokenType in [ttOn, ttElse] then
  begin
    while fcTokenList.FirstSolidTokenType in [ttOn, ttElse] do
      RecogniseExceptionHandler;
  end
  else
  begin
    // can be 0 or more statements
    RecogniseStatementList([ttEnd]);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseExceptionHandler;
begin
  {
    ExceptionSpecifier
        -> 'on' [ident ':'] ExceptType 'do' Statement
        -> 'else' Statement
  }
  PushNode(nOnExceptionHandler);

  if fcTokenList.FirstSolidTokenType = ttElse then
  begin
    Recognise(ttElse);
    RecogniseStatement;
  end
  else if fcTokenList.FirstSolidTokenType = ttOn then
  begin
    Recognise(ttOn);
    if fcTokenList.SolidTokenType(2) = ttColon then
    begin
      RecogniseIdentifier(False, idAllowDirectives);
      Recognise(ttColon);
    end;

    RecogniseDottedName;
    Recognise(ttDo);

    RecogniseNotSolidTokens;

    { special case - empty statement block, go straight on to the else }
    if fcTokenList.FirstSolidTokenType <> ttElse then
      RecogniseStatement;
  end
  else
    RecogniseStatement;

  if fcTokenList.FirstSolidTokenType = ttSemicolon then
    Recognise(ttSemicolon);

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseProcedureDeclSection;
var
  lc: TSourceToken;
begin
  {
  ProcedureDeclSection
    -> ProcedureDecl
    -> FunctionDecl
  }

  lc := fcTokenList.FirstSolidToken;

  case lc.TokenType of
    ttProcedure:
      RecogniseProcedureDecl(false);
    ttFunction:
      RecogniseFunctionDecl(false);
    ttConstructor:
      RecogniseConstructorDecl;
    ttDestructor:
      RecogniseDestructorDecl;
    ttOperator:
      RecogniseOperator(True);

    ttClass:
    begin
      { class proc or class function
        or in delphi.net
        class constructor or operator }
      case fcTokenList.SolidTokenType(2) of
        ttProcedure:
          RecogniseProcedureDecl(false);
        ttFunction:
          RecogniseFunctionDecl(false);
        ttConstructor:
          RecogniseConstructorDecl;
        ttDestructor:
          RecogniseDestructorDecl;
        ttOperator:
          RecogniseClassOperator(True);
        else
          raise TEParseError.Create('expected class procedure or class function', lc);
      end;
    end;
    ttGeneric:
      case fcTokenList.SolidTokenType(2) of
        ttProcedure:
          RecogniseProcedureDecl(false);
        ttFunction:
          RecogniseFunctionDecl(false);
        ttClass:
          case fcTokenList.SolidTokenType(3) of
            ttProcedure:
              RecogniseProcedureDecl(false);
            ttFunction:
              RecogniseFunctionDecl(false);
            else
              raise TEParseError.Create('expected class procedure or class function', lc);
          end
        else
          raise TEParseError.Create('expected class procedure or class function', lc);
     end;
    else
      raise TEParseError.Create('expected procedure or function', lc);
  end;

end;

{ the proc/function is forward or extern (ie has no body)
  if the word 'forward' or 'extern' is in the directives
  these are also valid param names }

function IsForwardExtern(pt: TParseTreeNode): boolean;
var
  lcDirectives: TParseTreeNode;
begin
  Assert(pt <> nil);

  if pt.NodeType in ProcedureNodes then
    pt := pt.GetImmediateChild(ProcedureHeadings);

  Assert(pt <> nil);

  lcDirectives := pt.GetImmediateChild(nProcedureDirectives);

  Result := (lcDirectives <> nil) and lcDirectives.HasChildNode([ttExternal, ttForward])
end;

procedure TBuildParseTree.RecogniseProcedureDecl(const pbAnon: boolean);
var
  lcTop: TParseTreeNode;
begin
  { ProcedureDecl -> ProcedureHeading ';' [Directive] Block ';'

    NB: the block is omitted if there is a 'forward' or external' directive

  }
  PushNode(nProcedureDecl);

  RecogniseProcedureHeading(pbAnon, False);

  { the ';' is ommited by lazy programmers in some rare occasions}
  if fcTokenList.FirstSolidTokenType = ttSemicolon then
    Recognise(ttSemicolon);

  RecogniseNotSolidTokens;

  { if the proc declaration has the directive external or forward,
    it will not have a body
    note that though 'forward' is a spectacularly unfortunate variable name,
    it has happened, e.g. in ActnMenus.pas }
  lcTop := TParseTreeNode(fcStack.Peek);
  if not IsForwardExtern(lcTop) then
  begin
    RecogniseBlock;

    if (not pbAnon) and (fcTokenList.FirstSolidTokenType = ttSemiColon) then
    begin
      Recognise(ttSemicolon);
    end;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseFunctionDecl(const pbAnon: boolean);
var
  lcTop: TParseTreeNode;
begin
  // ProcedureDecl -> FunctionHeading ';' [Directive] Block ';'

  PushNode(nFunctionDecl);

  RecogniseFunctionHeading(pbAnon, False);
  { the ';' is ommited by lazy programmers in some rare occasions}
  if fcTokenList.FirstSolidTokenType = ttSemicolon then
    Recognise(ttSemicolon);

  //opt
  CheckEnumeratorToken();
  if fcTokenList.FirstSolidTokenType in ProcedureDirectives then
    RecogniseProcedureDirectives;

  { if the proc declaration has the directive external or forward,
    it will not have a body }
  lcTop := TParseTreeNode(fcStack.Peek);
  if not IsForwardExtern(lcTop) then
  begin
    RecogniseBlock;

    if (not pbAnon) and (fcTokenList.FirstSolidTokenType = ttSemiColon) then
    begin
      Recognise(ttSemicolon);
    end;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseConstructorDecl;
begin
  // ProcedureDecl -> ProcedureHeading ';' [Directive] Block ';'

  PushNode(nConstructorDecl);

  RecogniseConstructorHeading(False);
  Recognise(ttSemicolon);
  CheckEnumeratorToken();
  if fcTokenList.FirstSolidTokenType in ProcedureDirectives then
    RecogniseProcedureDirectives;
  RecogniseBlock;
  Recognise(ttSemicolon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseDestructorDecl;
begin
  // ProcedureDecl -> ProcedureHeading ';' [Directive] Block ';'

  PushNode(nDestructorDecl);

  RecogniseDestructorHeading(False);
  Recognise(ttSemicolon);
  CheckEnumeratorToken();
  if fcTokenList.FirstSolidTokenType in ProcedureDirectives then
    RecogniseProcedureDirectives;
  RecogniseBlock;
  Recognise(ttSemicolon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseFunctionHeading(
  const pbAnon, pbCanInterfaceMap: boolean);
begin
  // FunctionHeading -> FUNCTION Ident [FormalParameters] ':' (SimpleType | STRING)
  PushNode(nFunctionHeading);

  if fcTokenList.FirstSolidTokenType = ttGeneric then
    Recognise(ttGeneric);

  // class procs
  if fcTokenList.FirstSolidTokenType = ttClass then
    Recognise(ttClass);

  Recognise(ttFunction);
  if not pbAnon then
    RecogniseMethodName(False);

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  { the colon and type is in fact optional in
    - external fns
    - when making good on a forward }
  if fcTokenList.FirstSolidTokenType = ttColon then
  begin
    Recognise(ttColon);
    PushNode(nFunctionReturnType);
    RecogniseType;
    PopNode;
  end;

  RecogniseProcedureDirectives;

  if pbCanInterfaceMap and (fcTokenList.FirstSolidTokenType = ttEquals) then
  begin
    Recognise(ttEquals);
    RecogniseIdentifier(False, idAllowDirectives);
  end;

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseProcedureHeading(
  const pbAnon, pbCanInterfaceMap: boolean);
begin
  { ProcedureHeading -> PROCEDURE Ident [FormalParameters]

    can also map to an interface name
    e.g.
      type
        TFoo = class(TObject, IFoo)
          public
            procedure IFoo.P1 = MyP1;
            Procedure MyP1;
        end;

        Or a constant
  }

  PushNode(nProcedureHeading);
  if fcTokenList.FirstSolidTokenType = ttGeneric then
    Recognise(ttGeneric);

  if fcTokenList.FirstSolidTokenType = ttClass then
    Recognise(ttClass);

  Recognise(ttProcedure);
  if not pbAnon then
    RecogniseMethodName(False);

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  RecogniseProcedureDirectives;

  if pbCanInterfaceMap and (fcTokenList.FirstSolidTokenType = ttEquals) then
  begin
    Recognise(ttEquals);
    RecogniseIdentifier(False, idAllowDirectives);
  end;

  PopNode;

  RecogniseNotSolidTokens;
end;

procedure TBuildParseTree.RecogniseFormalParameters;
begin
  // FormalParameters -> '(' FormalParm/';'... ')'

  PushNode(nFormalParams);

  Recognise(ttOpenBracket);

  { funciton Foo(); is accepted so must allow empty brackets }

  if fcTokenList.FirstSolidTokenType <> ttCloseBracket then
  begin
    RecogniseFormalParam;
    while fcTokenList.FirstSolidTokenType = ttSemicolon do
    begin
      Recognise(ttSemicolon);
      RecogniseFormalParam;
    end;
  end;

  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseFormalParam;
const
  PARAM_PREFIXES: TTokenTypeSet = [ttVar, ttConst, ttConstRef];
begin
  PushNode(nFormalParam);

  if (fcTokenList.FirstSolidTokenType = ttOpenSquareBracket) then
    RecogniseAttributes;

  { FormalParm -> [VAR | CONST | CONSTREF | OUT] Parameter

    'out' is different as it is also a param name so this is legal
    procedure Foo(out out: integer);

    'out' with a comma, colon or ')' directly after is not a prefix, it is a param name
    if another name follows it is a prefix
  }

  if fcTokenList.FirstSolidTokenType in PARAM_PREFIXES then
    Recognise(PARAM_PREFIXES)
  else if fcTokenList.FirstSolidTokenType = ttOut then
  begin
    if IsIdentifierToken(fcTokenList.SolidToken(2), idAllowDirectives) then
      Recognise(ttOut);
  end;

  RecogniseParameter;

  PopNode;
end;

procedure TBuildParseTree.RecogniseParameter;
var
  lbArray: boolean;
begin
  { Parameter
    -> IdentList  [':' ([ARRAY OF] SimpleType | STRING | FILE)]
    -> Ident ':' SimpleType '=' ConstExpr

    hard to distinguish these two productions
    will go for the superset

    -> IdentList  [':' ([ARRAY OF] Type) ['=' ConstExpr] ]

    Also I think that's broken as the following are legal:

    procedure foo(bar: array of file);
    procedure foo(bar: array of TMyRecord);

  }
  lbArray := False;
  RecogniseIdentList(False);
  if fcTokenList.FirstSolidTokenType = ttColon then
  begin
    Recognise(ttColon);

    if fcTokenList.FirstSolidTokenType = ttArray then
    begin
      Recognise(ttArray);
      Recognise(ttOf);
      lbArray := True;
    end;

    // type is optional in params ie procedure foo(var pp);
    if (lbArray) or ( not (fcTokenList.FirstSolidTokenType in
      [ttSemicolon, ttCloseBracket])) then
      RecogniseType;

    if fcTokenList.FirstSolidTokenType = ttEquals then
    begin
      Recognise(ttEquals);
      RecogniseConstantExpression;
    end;
  end;
end;

procedure TBuildParseTree.RecogniseProcedureDirectives;
var
  lbFirstPass: boolean;
begin
  { these are semi-colon separated

    want to leave 'Function foo;' as is,
    but strip off the '; safecall' off 'Function bar; safecall;'

    external is more complex
  }
  CheckEnumeratorToken();
  if (fcTokenList.FirstSolidTokenType in ProcedureDirectives) or
    ((fcTokenList.FirstSolidTokenType = ttSemicolon) and
    (fcTokenList.SolidTokenType(2) in ProcedureDirectives)) then
  begin
    PushNode(nProcedureDirectives);

    if fcTokenList.FirstSolidTokenType = ttSemiColon then
      Recognise(ttSemiColon);
    lbFirstPass := True;

    CheckEnumeratorToken();
    while (fcTokenList.FirstSolidTokenType in ProcedureDirectives) or
      ((fcTokenList.FirstSolidTokenType = ttSemicolon) and
        (fcTokenList.SolidTokenType(2) in ProcedureDirectives)) do
    begin
      if ( not lbFirstPass) and (fcTokenList.FirstSolidTokenType = ttSemiColon) then
        Recognise(ttSemiColon);

      case fcTokenList.FirstSolidTokenType of
        ttExternal:
        begin
          RecogniseExternalProcDirective;
        end;
        ttPublic:
        begin
          { Break the loop if we have found a class visibility "public" }
          if not RecognisePublicProcDirective then
            break;
        end;
        ttDispId:
        begin
          Recognise(ttDispId);
          RecogniseConstantExpression;
        end;
        ttMessage:
        begin
          Recognise(ttMessage);
          RecogniseConstantExpression;
        end;
        ttEnumerator:
        begin
          Recognise(ttEnumerator);
          RecogniseIdentifier(False, idStrict);
        end;
        ttDeprecated:
        begin
          Recognise(ttDeprecated);
          if fcTokenList.FirstSolidTokenType <> ttSemicolon then
            RecogniseConstantExpression;
        end
        else
          Recognise(ProcedureDirectives);
      end;

      lbFirstPass := False;
      CheckEnumeratorToken();
    end;

    PopNode;
  end;
end;

procedure TBuildParseTree.RecogniseExternalProcDirective;
begin
  { right, i'll fake this one

    ExternalProcDirective ->
      External ["'" libname "'"] ["name" "'" procname "'"]

      also allow "index expr"
  }
  PushNode(nExternalDirective);

  Recognise(ttExternal);

  if fcTokenList.FirstSolidTokenType = ttName then
  begin
    Recognise(ttName);
    RecogniseConstantExpression;
  end
  else if fcTokenList.FirstSolidTokenType in (IdentiferTokens + [ttQuotedLiteralString]) then
  begin
    Recognise((IdentiferTokens + [ttQuotedLiteralString]));

    if fcTokenList.FirstSolidTokenType = ttName then
    begin
      Recognise(ttName);
      RecogniseConstantExpression;
    end;
  end;

  if fcTokenList.FirstSolidTokenType = ttIndex then
  begin
    Recognise(ttIndex);
    RecogniseConstantExpression;
  end;

  PopNode;
end;

function TBuildParseTree.RecognisePublicProcDirective: boolean;
begin
  {
    PublicProcDirective ->
      Public ["name" "'" symname "'"]
  }
  result:=false;
  if TopNode.HasParentNode([nClassBody, nObjectType, nRecordType]) then
    exit;

  Recognise(ttPublic);

  if fcTokenList.FirstSolidTokenType = ttName then
  begin
    Recognise(ttName);
    RecogniseConstantExpression;
  end;

  result:=true;
end;

procedure TBuildParseTree.RecogniseObjectType;
begin
  { ObjectType -> OBJECT [ObjHeritage] [ObjFieldList] [MethodList] END

      arg this is badly broken, need to
  }

  PushNode(nObjectType);

  // optional "packed" on the oject
  if fcTokenList.FirstSolidTokenType = ttPacked then
   Recognise(ttPacked);

  Recognise(ttObject);

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseObjHeritage;

  // swiped this from the delphi object defs
  RecogniseClassBody;

  Recognise(ttEnd);

  PopNode;
end;

procedure TBuildParseTree.RecogniseObjHeritage;
begin
  // ObjHeritage -> '(' QualId ')'

  Recognise(ttOpenBracket);
  RecogniseQualId;
  Recognise(ttCloseBracket);
end;

procedure TBuildParseTree.RecogniseConstructorHeading(const pbDeclaration: boolean);
begin
  //ConstructorHeading -> CONSTRUCTOR Ident [FormalParameters]
  PushNode(nConstructorHeading);

  if fcTokenList.FirstSolidTokenType = ttClass then
    Recognise(ttClass);

  Recognise(ttConstructor);
  RecogniseMethodName( not pbDeclaration);
  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  RecogniseProcedureDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseDestructorHeading(const pbDeclaration: boolean);
begin
  //DestructorHeading -> DESTRUCTOR Ident [FormalParameters]
  PushNode(nDestructorHeading);

  if fcTokenList.FirstSolidTokenType = ttClass then
    Recognise(ttClass);

  Recognise(ttDestructor);
  RecogniseMethodName( not pbDeclaration);
  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  RecogniseProcedureDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseInitSection;
var
  lc: TSourceToken;
begin
  {
    InitSection
      -> INITIALIZATION StmtList [FINALIZATION StmtList] END
      -> BEGIN StmtList END
      -> END
  }

  lc := fcTokenList.FirstSolidToken;

  if lc = nil then
   exit;

  PushNode(nInitSection);

  case lc.TokenType of
    ttInitialization:
    begin
      Recognise(ttInitialization, True);
      RecogniseStatementList([ttEnd, ttFinalization]);

      if fcTokenList.FirstSolidTokenType = ttFinalization then
      begin
        Recognise(ttFinalization, True);
        RecogniseStatementList([ttEnd]);
      end;

      Recognise(ttEnd);
    end;
    ttFinalization:
    begin
      Recognise(ttFinalization, True);
      RecogniseStatementList([ttEnd]);
      Recognise(ttEnd);
    end;
    ttBegin:
    begin
      Recognise(ttBegin);
      RecogniseStatementList([ttEnd]);
      Recognise(ttEnd);
    end;
    ttEnd:
    begin
      Recognise(ttEnd);
    end
    else
      raise TEParseError.Create('expected initialisation, begin or end', lc);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassType;
begin
  {
  ClassType -> CLASS [ClassHeritage]
       [ClassFieldList]
       [ClassMethodList]
       [ClassPropertyList]
       END

  This is not right - these can repeat

  My own take on this is as follows:

  class -> ident '=' 'class' [Classheritage] classbody 'end'
  classbody -> clasdeclarations (ClassVisibility clasdeclarations) ...
  ClassVisibility -> 'private' | 'protected' | 'public' | 'published' | 'automated'
  classdeclarations -> (procheader|fnheader|constructor|destructor|vars|property|) [';'] ...

  can also be a forward declaration, e.g.
    TFred = class;

  or a class ref type
    TFoo = class of TBar;

  or in delphi.net

  TMyClassHelper = class helper for TMyClass
  TMyClassHelper2 = class helper(TMyClassHelper) for TMyClass
  TSealedClass = class sealed (TMaClass)
  TAbstractClass = class abstract (TObject)
  }

  PushNode(nClassType);

  // the class can be prefixed with "packed"
  if fcTokenList.FirstSolidTokenType = ttPacked then
    Recognise(ttPacked);

  Recognise(ttClass);

  if fcTokenList.FirstSolidTokenType = ttHelper then
  begin
    Recognise(ttHelper);

    if fcTokenList.FirstSolidTokenType = ttOpenBracket then
      RecogniseClassHeritage;

    Recognise(ttFor);
    RecogniseIdentifier(False, idStrict);
  end
  else
  begin
    // delphi.net sealed class
    if fcTokenList.FirstSolidTokenType = ttSealed then
      Recognise(ttSealed);

    // abstract class
    if fcTokenList.FirstSolidTokenType = ttAbstract then
      Recognise(ttAbstract);

    if fcTokenList.FirstSolidTokenType = ttSemicolon then
    begin
      PopNode;
      exit;
    end;

    if fcTokenList.FirstSolidTokenType = ttOf then
    begin
      Recognise(ttOf);
      RecogniseIdentifier(True, idStrict);
      PopNode;
      exit;
    end;

    if fcTokenList.FirstSolidTokenType = ttOpenBracket then
      RecogniseClassHeritage;

  end;

    // can end here
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
    begin
      PopNode;
      exit;
    end;

  RecogniseClassBody;
  Recognise(ttEnd);

  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassHeritage;
begin
  PushNode(nClassHeritage);

  // ClassHeritage -> '(' IdentList ')'
  Recognise(ttOpenBracket);
  RecogniseHeritageList;
  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassVisibility;
begin
  // ClassVisibility -> [PUBLIC | PROTECTED | PRIVATE | PUBLISHED]

  if fcTokenList.FirstSolidTokenType = ttStrict then
  begin
    // Delphi.net allows "strict private" and "strict protected"
    Recognise(ttStrict);
    Recognise([ttPrivate, ttProtected]);
  end
  else
    Recognise(ClassVisibility);
end;

procedure TBuildParseTree.RecogniseClassBody;
begin
  //ClassBody -> classdeclarations (access classdeclarations) ...
  PushNode(nClassBody);

  RecogniseClassDeclarations(False);

  while (fcTokenList.FirstSolidTokenType in ClassVisibility + [ttStrict, ttClass]) do
  begin
    PushNode(nClassVisibility);
    RecogniseClassVisibility;
    RecogniseClassDeclarations(False);
    PopNode;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseClassDeclarations(const pbInterface: boolean);
const
  // can declare thse things in a class
  CLASS_DECL_WORDS = [ttProcedure, ttFunction, ttConstructor, ttDestructor,
                      ttProperty, ttClass, ttConst, ttType, ttVar, ttThreadVar];
var
  lc: TSourceToken;
  lbStarted: boolean;
  lbHasTrailingSemicolon: Boolean;
begin
  { this is a superset of delphi.
    in dcc these must be ordered vars, then fns then properties

    nb this can be empty  as in
      class TFoo(Tobject)
        private
        public
        end;

    or even
      class TBar(TObject) end;

   classdeclarations -> (procheader|fnheader|constructor|destructor|vars|property|) [';'] ...

   This is all the stuff in a class def between different visibility sections

    could a procedure, fuction, constructor, destructor, or property
     all of which start with the requite word
     or it could just be a varaible declaration, which starts with a new var name

     addition: must also do class fns and procs,
     eg
      " class function ClassName: ShortString; "

     Delphi .net allows class types to be declared inside other class types
     also "var" to introduce variables
   }
  lbStarted := False;

  while (fcTokenList.FirstSolidTokenType in (CLASS_DECL_WORDS + [ttOpenSquareBracket])) or
    (fcTokenList.FirstSolidWordType in IdentifierTypes) do
  begin
    // only make this node if it will have children
    if not lbStarted then
      PushNode(nClassDeclarations);
    lbStarted := True;

    lc := fcTokenList.FirstSolidToken;
    lbHasTrailingSemicolon := True;

    // these end the visibility section
    if lc.TokenType in (ClassVisibility + [ttEnd, ttStrict]) then
      break;

    { delphi.net attribute applied to the procedure, property or vars }
    if lc.TokenType = ttOpenSquareBracket then
    begin
      RecogniseAttributes();
      lc := fcTokenList.FirstSolidToken;
    end;

    case lc.TokenType of
      ttProcedure:
        RecogniseProcedureHeading(False, True);
      ttFunction:
        RecogniseFunctionHeading(False, True);
      ttConst:
      begin
        { constant in a class are legal in Delphi.net }
        RecogniseConstSection(true);
        lbHasTrailingSemicolon := False;
      end;
      ttClass:
      begin
        { 'class' must be followed by 'procedure' or 'function'
         or in Delphi.Net: "var", "property", "constructor" or "operator"
        }

        case fcTokenList.SolidTokenType(2) of
          ttProcedure:
            RecogniseProcedureHeading(False, True);
          ttFunction:
            RecogniseFunctionHeading(False, True);
          ttVar, ttThreadVar:
          begin
            RecogniseVarSection(True);
            lbHasTrailingSemicolon := False;
          end;
          ttProperty:
          begin
            RecogniseProperty;
          end;
          ttConstructor:
            RecogniseConstructorHeading(True);
          ttDestructor:
            RecogniseDestructorHeading(True);
          ttOperator:
            RecogniseClassOperator(False);
          else
            raise TEParseError.Create('Expected class procedure or class function', lc);
        end;

      end;
      ttConstructor:
      begin
          // no constructor on interface
        if pbInterface then
          raise TEParseError.Create('unexpected token', lc);
        RecogniseConstructorHeading(True);
      end;
      ttDestructor:
      begin
          // no constructor on interface
        if pbInterface then
          raise TEParseError.Create('unexpected token', lc);
        RecogniseDestructorHeading(True);
      end;
      ttProperty:
        RecogniseProperty;
      ttType:
      begin
        RecogniseTypeSection(true);
        lbHasTrailingSemicolon := False;
      end;
      ttVar, ttThreadVar:
      begin
        RecogniseVarSection(True);
        lbHasTrailingSemicolon := False;
      end;
      else
      begin
        // end of this list with next visibility section or class end?
        if lc.TokenType in CLASS_DECL_WORDS + [ttEnd] then
        begin
          break;
        end
          // vars start with an identifier
        else if lc.TokenType in IdentiferTokens then
        begin
          // no vars on interface
          if pbInterface then
            raise TEParseError.Create('unexpected token', lc);

          RecogniseVarDecl;
        end
        else
          raise TEParseError.Create('unexpected token', lc);
      end;
    end;

    // semicolon after each def.
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon)
    else if lbHasTrailingSemicolon then
      { expect a semicolon on all except the last, or a const or type (already parsed therein ) }
      Break;

  end;

  if lbStarted then
    PopNode;
end;

procedure TBuildParseTree.RecogniseProperty;
begin
  {PropertyList -> PROPERTY  Ident [PropertyInterface]  PropertySpecifiers

  There is also the syntax of reclaring properties to raise visibility
    -> Property Ident;
  }
  PushNode(nProperty);

  // class property
  if  fcTokenList.FirstSolidTokenType = ttClass then
    Recognise(ttClass);

  Recognise(ttProperty);

  RecogniseIdentifier(False, idAllowDirectives);

  { this is omitted if it is a property redeclaration for visibility raising
    in that case it may still have directives and hints }
  if fcTokenList.FirstSolidTokenType in [ttColon, ttOpenSquareBracket] then
  begin
    RecognisePropertyInterface;
  end;

  RecognisePropertySpecifiers;

  RecognisePropertyDirectives;
  RecogniseHintDirectives;

  PopNode;
end;

procedure TBuildParseTree.RecognisePropertyInterface;
begin
  // PropertyInterface -> [PropertyParameterList] ':' Ident

  if fcTokenList.FirstSolidTokenType <> ttColon then
    RecognisePropertyParameterList;

  Recognise(ttColon);

  // recongising any type is overkill but hey
  RecogniseType;
end;

procedure TBuildParseTree.RecognisePropertyParameterList;
begin
  { PropertyParameterList -> '[' (IdentList ':' TypeId)/';'... ']'

   this forgets const and var, e.g.

   property ComplexArrayProp[const piIndex: integer; var pcsString: string]: boolean read GetComplexArrayProp ;

  }
  PushNode(nPropertyParameterList);

  Recognise(ttOpenSquareBracket);
  repeat
    if (fcTokenList.FirstSolidTokenType in [ttConst, ttConstref, ttVar, ttOut]) then
      Recognise([ttConst, ttConstref, ttVar, ttOut]);

    RecogniseIdentList(False);
    Recognise(ttColon);
    RecogniseTypeId;

    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon)
    else
      break;

  until fcTokenList.FirstSolidTokenType = ttCloseSquareBracket;

  Recognise(ttCloseSquareBracket);

  PopNode;
end;

procedure TBuildParseTree.RecognisePropertySpecifiers;
var
  lc: TSourceToken;
const
  PROPERTY_SPECIFIERS: TTokenTypeSet = [ttIndex, ttRead, ttWrite,
    ttAdd, ttRemove,
    ttStored, ttDefault, ttNoDefault,
    ttImplements, ttDispId, ttReadOnly, ttWriteOnly];
begin
  {
   PropertySpecifiers ->
     [INDEX ConstExpr]
     [READ Ident]
     [WRITE Ident]
     [STORED (Ident | Constant)]
     [(DEFAULT ConstExpr) | NODEFAULT]
     [IMPLEMENTS TypeId]

     This is broken in that
       - can be more than one of them (and usually are for read and write)
       - left out dispid
       - left out readonly
       - Add and remove for Delphi.net
   }
  lc := fcTokenList.FirstSolidToken;

  while lc.TokenType in PROPERTY_SPECIFIERS do
  begin
    PushNode(nPropertySpecifier);

    case lc.TokenType of
      ttIndex:
      begin
        Recognise(ttIndex);
        RecogniseConstantExpression;
      end;
      ttRead, ttWrite, ttAdd, ttRemove:
      begin
        Recognise(lc.TokenType);
        RecognisePropertyAccess;
      end;
      ttStored:
      begin
        Recognise(ttStored);
        RecogniseConstantExpression;
      end;
      ttDefault:
      begin
        Recognise(ttDefault);
        RecogniseConstantExpression;
      end;
      ttNoDefault:
      begin
        Recognise(ttNoDefault);
      end;
      ttImplements:
      begin
        Recognise(ttImplements);
        RecogniseTypeId;

          { can be a lost of them, e.g. "implements foo, bar" }
        while fcTokenList.FirstSolidTokenType = ttComma do
        begin
          Recognise(ttComma);
          RecogniseTypeId;
        end;
      end;
      ttDispId:
      begin
        Recognise(ttDispId);
        RecogniseConstantExpression;
      end;
      ttReadOnly:
      begin
        Recognise(ttReadOnly);
      end;
      ttWriteOnly:
      begin
        Recognise(ttWriteOnly);
      end;
      else
        raise TEParseError.Create('expected property specifier',
          fcTokenList.FirstSolidToken);
    end;

    PopNode;
    lc := fcTokenList.FirstSolidToken;

  end;
end;

procedure TBuildParseTree.RecognisePropertyAccess;
begin
  { property access is the bit after the "read" or "write" in a property declaration
    This is usually just a procedure, function or simple var
    but sometimes it is a record or array field, .. or both e.g. "FDummy[0].ERX" }

  RecogniseIdentifier(False, idAllowDirectives);

  { array access }
  if fcTokenList.FirstSolidTokenType = ttOpenSquareBracket then
  begin
    Recognise(ttOpenSquareBracket);
    // this is evaluated at compile-time, so we expect a constant subscript, e.g. "FDummy[0]"
    RecogniseConstantExpression;
    Recognise(ttCloseSquareBracket);
  end;

  { record field }
  if fcTokenList.FirstSolidTokenType = ttDot then
  begin
    Recognise(ttDot);
    // after the dot can be more structure, so recurse
    RecognisePropertyAccess;
  end

end;

procedure TBuildParseTree.RecogniseInterfaceType;
begin
  {
    InterfaceType -> INTERFACE [InterfaceHeritage]
         [ClassMethodList]
         [ClassPropertyList]
         END

    This is broken
      - left out Dispinterface
      - left out possible guid
      - left out forward declaration e.g. "IFoo = interface; "
  }
  PushNode(nInterfaceType);
  Recognise(InterfaceWords);

  if fcTokenList.FirstSolidTokenType = ttSemicolon then
  begin
    PopNode;
    exit;
  end;

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseInterfaceHeritage;

  if fcTokenList.FirstSolidTokenType = ttOpenSquareBracket then
    RecogniseInterfaceGuid;

  if fcTokenList.FirstSolidTokenType <> ttEnd then
  begin
    PushNode(nInterfaceBody);
    RecogniseClassDeclarations(True);
    PopNode;
  end;

  Recognise(ttEnd);

  PopNode;
end;

procedure TBuildParseTree.RecogniseInterfaceGuid;
begin
  // interface guid can be a litteral string, or occasionally a string constant
  PushNode(nInterfaceTypeGuid);

  Recognise(ttOpenSquareBracket);
  if fcTokenList.FirstSolidTokenType = ttQuotedLiteralString then
    Recognise(ttQuotedLiteralString)
  else
    RecogniseIdentifier(False, idStrict);

  Recognise(ttCloseSquareBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseInterfaceHeritage;
begin
  // InterfaceHeritage -> '(' IdentList ')'
  PushNode(nInterfaceHeritage);

  Recognise(ttOpenBracket);
  RecogniseHeritageList;
  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseRequiresClause;
begin
  // RequiresClause -> REQUIRES IdentList... ';'

  PushNode(nRequires);

  Recognise(ttRequires);
  RecogniseIdentList(False);
  Recognise(ttSemicolon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseContainsClause;
begin
  // ContainsClause -> CONTAINS IdentList... ';'

  { it's not an ident list it's a unit list can be
  "ident1, indent2" etc

  or more usually
  "ident1 in 'file1.pas',
  ident2 in 'file2.pas' " etc}

  PushNode(nContains);

  Recognise(ttContains);

  PushNode(nIdentList);

  RecogniseUsesItem(True);
  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseUsesItem(True);
  end;
  PopNode;

  Recognise(ttSemicolon);

  PopNode;
end;

{ worker for RecogniseIdentList }

procedure TBuildParseTree.RecogniseIdentValue;
begin
  if fcTokenList.FirstSolidTokenType in [ttEquals, ttAssign] then
  begin
    Recognise(fcTokenList.FirstSolidTokenType);
    RecogniseExpr(True);
  end;
end;

procedure TBuildParseTree.RecogniseIdentList(const pbCanHaveUnitQualifier: boolean);
begin
  { IdentList -> Ident/','...

    now in D6 enum types can have numeric values
     e.g. (foo, bar = 3, baz)
  }
  PushNode(nIdentList);

  RecogniseIdentifier(pbCanHaveUnitQualifier, idAllowDirectives);
  RecogniseIdentValue;

  while fcTokenList.FirstSolidTokenType = ttComma do
  begin
    Recognise(ttComma);
    RecogniseIdentifier(pbCanHaveUnitQualifier, idAllowDirectives);
    RecogniseIdentValue;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseConstantExpression;
begin
  RecogniseExpr(True);
end;

procedure TBuildParseTree.RecogniseQualId;
begin
  { typecast, e.g. "(x as Ty)"
     or just bracketed, as in (x).y();

     See TestCastSimple.pas for the heinous examples

     QualID ->
      -> (Designator)
      -> (Designator as type)
      -> ident
      ->(pointervar + expr)
  }
  if (fcTokenList.FirstSolidTokenType = ttOpenBracket) then
  begin
    PushNode(nBracketedQual);
    Recognise(ttOpenBracket);
    RecogniseDesignator;

    if (fcTokenList.FirstSolidTokenType = ttAs) then
      RecogniseAsCast;

    Recognise(ttCloseBracket);
    PopNode;
  end
  else
    // a simple ident - e.g. "x"
    RecogniseIdentifier(True, idAny);
end;

procedure TBuildParseTree.RecogniseIdentifier(const pbCanHaveUnitQualifier: boolean;
  const peStrictness: TIdentifierStrictness);
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;

  if not IdentifierNext(peStrictness) then
    raise TEParseError.Create('Expected identifier', lc);

  PushNode(nIdentifier);
  Recognise(IdentiferTokens);

  { tokens can be qualified by a unit name }
  { can be nested types }
  if pbCanHaveUnitQualifier and (fcTokenList.FirstSolidTokenType = ttDot) then
  begin
    while fcTokenList.FirstSolidTokenType = ttDot do
    begin
      Recognise(ttDot);

      { delphi.net can preface the identifier with an '&'
        in order to do something obscure with it - make it a literal or something

        e.g. "WebRequest.&Create" is not a constructor,
        but a C# method called "Create", which is not a reserved word in C#
      }

      RecognisePossiblyAmpdIdentifier;
    end;
  end;

  PopNode;
end; 

{ the name of a procedure/function/constructor can be
  a plain name or classname.methodname
  or class<generic>.typename }
procedure TBuildParseTree.RecogniseMethodName(const pbClassNameCompulsory: boolean);
var
  lbMore: boolean;
begin
  if fcTokenList.FirstSolidTokenType = ttAssign then
  begin
    PushNode(nIdentifier);
    Recognise(ttAssign);
    PopNode;
    exit;
  end
  else
  if IsSymbolOperator(fcTokenList.FirstSolidToken) then begin
      PushNode(nIdentifier);
      Recognise(Operators);
      PopNode;
      exit;
  end;
  if not (IdentifierNext(idAllowDirectives)) then
    raise TEParseError.Create('Expected identifier', fcTokenList.FirstSolidToken);

  // a method name is an identifier
  PushNode(nIdentifier);

  Recognise(IdentiferTokens);

  if fcTokenList.FirstSolidTokenType = ttLessThan then
  begin
    // a generic decl on the method or class
    RecogniseGenericType;
  end;

  if (fcTokenList.FirstSolidTokenType = ttDot) or pbClassNameCompulsory then
  begin
    lbMore := true;

    while lbMore do
    begin
      Recognise(ttDot);
      if fcTokenList.FirstSolidTokenType = ttAssign then
        Recognise(ttAssign)
      else
        Recognise(IdentiferTokens + Operators);

      if fcTokenList.FirstSolidTokenType = ttLessThan then
      begin
        // a generic decl on the method in a class
        RecogniseGenericType;
      end;

      { delphi.net nested types have more than one dot }
      lbMore := (fcTokenList.FirstSolidTokenType = ttDot);
    end;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseMethodReferenceType;
var
  lc: TSourceToken;
begin
  PushNode(nMethodReferenceType);

  Recognise(ttReference);
  Recognise(ttTo);

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttFunction then
  begin
    RecogniseFunctionHeading(true, false);
  end
  else if lc.TokenType = ttProcedure then
  begin
    RecogniseProcedureHeading(true, false);
  end
  else
  begin
    raise TEParseError.Create('expected procedure or function', lc);
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseTypeId;
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;

  { a type is an identifier. Or a file or other Reserved word }
  if lc.TokenType in BuiltInTypes then
  begin
    Recognise(BuiltInTypes);
  end
  else if lc.TokenType = ttFile then
  begin
    Recognise(ttFile);
  end
  else if lc.TokenType = ttAmpersand then
  begin
    RecognisePossiblyAmpdIdentifier;
  end
  else
  begin
    { type can be prefixed with a unit name, e.g. Classes.TList;
      or it could be .NET style, e.g. System.Windows.Forms.TextBox }
    RecogniseDottedName;
  end;

  if fcTokenList.FirstSolidTokenType = ttLessThan then
  begin
    // a use not a decl
    RecogniseGenericType;
  end;
  if fcTokenList.FirstSolidTokenType = ttDot then
  begin
    Recognise(ttDot);
    RecogniseTypeId;
  end;
end;


procedure TBuildParseTree.RecogniseAsmBlock;
begin
  PushNode(nAsm);

  Recognise(ttAsm);
  while fcTokenList.FirstSolidTokenType <> ttEnd do
    RecogniseAsmStatement;

  Recognise(ttEnd);

  PopNode;
end;

procedure TBuildParseTree.RecogniseAsmStatement;
begin
  { um.

    AsmStatement
     -> [AsmLabel]
     -> Opcode [AsmParam] [',' AsmParam]...

     NB whitespace is significant, i.e. returns can separate statement
     Help says ' semicolons, end-of-line characters, or Delphi comments.'

     I know that the help claims that a label is a prefix on a statement,
     but a label can be the last thing in an asm block
     so that would require a complete statement to consist of
     an optional label followed by an optional opcode

     Anyway labels are usually placed on a separate line

     RET is opcode with no params
  }

  PushNode(nAsmStatement);

  if fcTokenList.FirstSolidTokenType = ttAtSign then
  begin
    RecogniseAsmLabel(True);
  end
  else
  begin
    // apparently you can have a regular colon label in here
    CheckLabelPrefix;

    RecogniseAsmOpcode;

    RecogniseWhiteSpace;

    if fcTokenList.FirstSolidTokenType = ttSemiColon then
    begin
      Recognise(ttSemiColon);
    end
    else
    begin
      while not (fcTokenList.FirstTokenType in [ttSemicolon, ttReturn, ttComment, ttEnd]) do
      begin
        if fcTokenList.FirstSolidTokenType = ttComma then
        begin
          Recognise(ttComma);
        end;
        RecogniseAsmParam;

        RecogniseWhiteSpace;

        if fcTokenList.FirstSolidTokenType = ttEnd then
        begin
          Break;
        end;

        if fcTokenList.FirstSolidTokenType = ttSemiColon then
        begin
          Recognise(ttSemiColon);
          break;
        end;
      end;

    end;
  end;



  PopNode;
end;

{ purpose: to consume white space
  make sure that buffertokens(0)
  contains a return, comment or solid token }

procedure TBuildParseTree.RecogniseWhiteSpace;
begin
  while fcTokenList.FirstTokenType = ttWhiteSpace do
    Recognise(ttWhiteSpace);
end;

procedure TBuildParseTree.RecogniseNotSolidTokens;
begin
  while (fcTokenList.CurrentTokenIndex < fcTokenList.Count) and
    (fcTokenList.FirstTokenType in NotSolidTokens) do
  begin
    TopNode.AddChild(fcTokenList.Extract);
  end;
end;


procedure TBuildParseTree.RecogniseAsmIdent;
var
  lc: TSourceToken;
begin
  PushNode(nAsmIdent);

  { can contain '@' signs }
  lc := fcTokenList.FirstSolidToken;

  if not (lc.TokenType in IdentiferTokens + [ttAtSign]) then
    raise TEParseError.Create('Expected asm identifier', lc);

  while (lc.TokenType in IdentiferTokens + [ttAtSign]) do
  begin
    Recognise(IdentiferTokens + [ttAtSign]);
    { whitespace ends this so no fcTokenList.FirstSolidToken }
    lc := fcTokenList.First;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseAsmOpcode;
begin
  { these are all short (3 chars? 4 chars)

    but it's too large a cast and varies from CPU to CPU
    so I will not enumerate them all

    some overlap with Delphi reserved words
    e.g. SHL
   }
  PushNode(nAsmOpcode);
  if IdentifierNext(idStrict) then
    RecogniseIdentifier(False, idStrict)
  else if WordTypeOfToken(fcTokenList.FirstSolidTokenType) in TextualWordTypes then
    // match anything
    Recognise(fcTokenList.FirstSolidTokenType)
  else
    raise TEParseError.Create('Expected asm opcode', fcTokenList.FirstSolidToken);

  PopNode;
end;

function IsAsmLabel(const pt: TSourceToken): boolean;
begin
  Result := False;
  if pt = nil then
    exit;
  Result := (pt.TokenType in [ttNumber, ttIdentifier, ttAtSign]) or
    (pt.WordType in [wtReservedWord, wtReservedWordDirective,
    wtBuiltInConstant, wtBuiltInType]);
end;

procedure TBuildParseTree.RecogniseAsmLabel(const pbColon: boolean);
begin
  PushNode(nAsmLabel);

  Recognise(ttAtSign);
  if fcTokenList.FirstSolidTokenType = ttAtSign then
    Recognise(ttAtSign);

  { label can be a number, eg "@@1:"
    or an identifier that starts with a number, eg "@@2a"

    can also be a delphi keyword, e.g. "@@repeat:"
  }

  while IsAsmLabel(fcTokenList.First) do
  begin
    Recognise(fcTokenList.FirstTokenType);
  end;

  if pbColon then
    Recognise(ttColon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseAsmParam;
const
  ASM_EXPRESSION_START = [ttOpenBracket, ttOpenSquareBracket, ttNumber,
    ttNot, ttQuotedLiteralString,
    ttTrue, ttFalse, ttPlus, ttMinus, ttType, ttOffset,
    ttVmtOffset, ttDmtOffset];
var
  lc, lcNext: TSourceToken;
  lbHasLabel: boolean;
begin
  { um.  No formal grammar for these

  AsmParam
    -> Ident
    -> Ident(AsmExpr) 
    -> '@' Ident
    -> '&' Ident
    -> '[' AsmExpr ']'
  }

  lbHasLabel := False;
  PushNode(nAsmParam);

  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType = ttAtSign then
  begin
    RecogniseAsmLabel(False);
    lbHasLabel := True;

    if fcTokenList.FirstSolidTokenType = ttDot then
      Recognise(ttDot);
  end;

  if lc.TokenType = ttAmpersand then
  begin
    Recognise(ttAmpersand);
  end;

  { only parse trailing expressions if it is on the same line
    Asm is not completely white-space-independant }
  lcNext := fcTokenList.FirstTokenWithExclusion([ttWhiteSpace]);
  if (lcNext <> nil) and (lcNext.TokenType <> ttReturn) then
  begin
    if IdentifierNext(idAllowDirectives) or (lc.TokenType in ASM_EXPRESSION_START) then
    begin
      RecogniseAsmExpr;
    end
    else
    begin
      if not lbHasLabel then
        raise TEParseError.Create('Expected asm param', lc);
    end;
  end;

  PopNode;
end;

const
  ASM_OPERATORS = [ttPlus, ttMinus, ttAnd, ttOr, ttTimes, ttFloatDiv, ttPtr, ttColon];

  { having to wing this one. it is like expressions, but different }

procedure TBuildParseTree.RecogniseAsmExpr;
var
  lc: TSourceToken;
begin
  RecogniseAsmFactor;

  { can't go past returns }
  lc := fcTokenList.FirstTokenWithExclusion([ttWhiteSpace]);
  while lc.TokenType in ASM_OPERATORS do
  begin
    RecogniseAsmOperator;
    RecogniseAsmFactor;
    lc := fcTokenList.FirstTokenWithExclusion([ttWhiteSpace]);
  end;
end;

procedure TBuildParseTree.RecogniseAsmOperator;
begin
  Recognise(ASM_OPERATORS);
end;

procedure TBuildParseTree.RecogniseAsmFactor;
var
  lcNext: TSourceToken;
  lcLastChar: Char;
begin
  if fcTokenList.FirstSolidTokenType = ttNot then
    Recognise(ttNot);

  if fcTokenList.FirstSolidTokenType = ttMinus then
    Recognise(ttMinus);

  if fcTokenList.FirstSolidTokenType = ttAt then
    Recognise(ttAt);

  if fcTokenList.FirstSolidTokenType = ttType then
    Recognise(ttType);

  if fcTokenList.FirstSolidTokenType = ttOffset then
    Recognise(ttOffset);

  if fcTokenList.FirstSolidTokenType in AsmOffsets then
    Recognise(AsmOffsets);


  case fcTokenList.FirstSolidTokenType of
    ttNumber:
    begin
      Recognise(ttNumber);

      // numbers in Asm blocks can be suffixed with 'h' for hex
      // there could be unanounced hex digits before the 'h'
      lcNext := fcTokenList.FirstSolidToken;
      if (lcNext.TokenType = ttIdentifier) then
      begin
        lcLastChar := lcNext.SourceCode[Length(lcNext.SourceCode)];

        if ((lcLastChar = 'h') or (lcLastChar = 'H')) then
        begin
          Recognise(ttIdentifier);
        end;

      end;

    end;
    ttQuotedLiteralString:
      Recognise(ttQuotedLiteralString);
    ttTrue:
      Recognise(ttTrue);
    ttFalse:
      Recognise(ttFalse);
    ttOpenBracket:
    begin
      Recognise(ttOpenBracket);
      RecogniseAsmExpr;
      Recognise(ttCloseBracket);
    end;
    ttOpenSquareBracket:
    begin
      Recognise(ttOpenSquareBracket);
      RecogniseAsmExpr;
      Recognise(ttCloseSquareBracket);
    end;
    ttComma, ttSemicolon:
    begin
      // expression over, go home
      // can be caused by bug 1933836 - the unary operator was actually a var name
    end
    else
    begin
      RecogniseAsmIdent;
    end
  end;

  while fcTokenList.FirstSolidTokenType in [ttDot, ttOpenBracket, ttOpenSquareBracket] do
  begin

    if fcTokenList.FirstSolidTokenType = ttDot then
    begin
      Recognise(ttDot);

      if fcTokenList.FirstSolidTokenType = ttAtSign then
        Recognise(ttAtSign);
      RecogniseAsmIdent;
    end;

    if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    begin
      Recognise(ttOpenBracket);
      RecogniseAsmFactor;
      Recognise(ttCloseBracket);
    end;

    if fcTokenList.FirstSolidTokenType = ttOpenSquareBracket then
    begin
      Recognise(ttOpenSquareBracket);
      RecogniseAsmExpr;
      Recognise(ttCloseSquareBracket);
    end;
  end;

end;

procedure TBuildParseTree.RecogniseHintDirectives;
begin
  if ((fcTokenList.FirstSolidTokenType = ttSemicolon) and
    (fcTokenList.SolidTokenType(2) in HintDirectives)) or
    (fcTokenList.FirstSolidTokenType in HintDirectives) then
  begin
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon);

    PushNode(nHintDirectives);

    while (fcTokenList.FirstSolidTokenType in HintDirectives) do
    begin
      Recognise(HintDirectives);
    end;

    PopNode;
  end;
end;

procedure TBuildParseTree.RecognisePropertyDirectives;
const
  { this can be specified at the end after a semicolon
  so it's not just in the specifiers

  the default directive works differently for array and not-array properties

  for non-array properties it is followed by an identifier
  }
  PropertyDirectives = [ttDefault, ttNoDefault, ttStored, ttEnumerator];
begin
  CheckEnumeratorToken();
  if ((fcTokenList.FirstSolidTokenType = ttSemicolon) and
    (fcTokenList.SolidTokenType(2) in PropertyDirectives)) or
    (fcTokenList.FirstSolidTokenType in PropertyDirectives) then
  begin
    if fcTokenList.FirstSolidTokenType = ttSemicolon then
      Recognise(ttSemicolon);
    CheckEnumeratorToken();
    while fcTokenList.FirstSolidTokenType in PropertyDirectives do
    begin
      PushNode(nPropertyDirective);

      case fcTokenList.FirstSolidTokenType of
        ttDefault:
        begin
          Recognise(ttDefault);
          if fcTokenList.FirstSolidTokenType <> ttSemicolon then
            RecogniseConstantExpression;
        end;
        ttNoDefault:
        begin
          Recognise(ttNoDefault);
        end;
        ttStored:
        begin
          Recognise(ttStored);
          if fcTokenList.FirstSolidTokenType <> ttSemicolon then
            RecogniseConstantExpression;
        end;
        ttEnumerator:
        begin
          Recognise(ttEnumerator);
          RecogniseIdentifier(False, idStrict);
        end;
      end;
      PopNode;
      CheckEnumeratorToken();
    end;
  end;
end;

procedure TBuildParseTree.RecogniseExportsSection;
begin
  PushNode(nExports);

  Recognise(ttExports);
  RecogniseExportedProc;

  // more to come?
  while fcTokenList.FirstSolidTokenType <> ttSemicolon do
  begin
    Recognise(ttComma);
    RecogniseExportedProc;
  end;

  Recognise(ttSemicolon);

  PopNode;
end;

procedure TBuildParseTree.RecogniseExportedProc;
const
  ExportedDirectives: TTokenTypeSet = [ttName, ttIndex, ttResident];
var
  lc: TSourceToken;
begin
  PushNode(nExportedProc);

  RecogniseIdentifier(True, idAllowDirectives);

  if fcTokenList.FirstSolidTokenType = ttOpenBracket then
    RecogniseFormalParameters;

  while fcTokenList.FirstSolidTokenType in ExportedDirectives do
  begin
    lc := fcTokenList.FirstSolidToken;

    case lc.TokenType of
      ttName:
      begin
        Recognise(ttName);
        Recognise(IdentiferTokens + [ttQuotedLiteralString]);
      end;
      ttIndex:
      begin
        Recognise(ttIndex);
        Recognise(ttNumber);
      end;
      ttResident:
        Recognise(ttResident);
      else
        raise TEParseError.Create('Expected export directive', lc);
    end;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseActualParams;
const
   SKIP_PARAM: TTokenTypeSet = [ttComma, ttCloseBracket];
var
  lbMore: boolean;
  liParamsRecognised: integer;
begin
  PushNode(nActualParams);

  Recognise(ttOpenBracket);
  liParamsRecognised := 0;

  if fcTokenList.FirstSolidTokenType <> ttCloseBracket then
  begin
    //RecogniseExprList;

    repeat

      { SF Bug 1311753
       - end param can be empty, as in "GetBitmap(1, bitmap, );"
        this is the case when
        - not first param
        - next solid token is comma or close brackets
      }
      if (liParamsRecognised = 0) or (not (fcTokenList.FirstSolidTokenType in SKIP_PARAM)) then
        RecogniseActualParam;

      inc(liParamsRecognised);

      lbMore := fcTokenList.FirstSolidTokenType = ttComma;
      if lbMore then
        Recognise(ttComma);

    until not lbMore;

  end;

  Recognise(ttCloseBracket);

  PopNode;
end;

procedure TBuildParseTree.RecogniseActualParam;
const
  EXPR_TYPES = [ttNumber, ttIdentifier, ttQuotedLiteralString,
    ttPlus, ttMinus, ttOpenBracket, ttOpenSquareBracket, ttNot, ttInherited];
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;
  if lc.TokenType = ttSpecialize then
  begin
    Recognise(ttSpecialize);
    lc := fcTokenList.FirstSolidToken;
  end;
  { all kinds of reserved words can sometimes be param names
    thanks to COM and named params
    See LittleTest43.pas }
  if ( not (lc.TokenType in EXPR_TYPES)) and StrIsAlphaNum(lc.SourceCode) and
    ( not IsIdentifierToken(lc, idAllowDirectives)) then
  begin
    { TridenT - test if token is the Reserved word ARRAY
      Sample Delphi2005 syntax :
      TbObj:= New(array[] of TObject, (S1, I, D1, D2, Etat, S2));
    }
    if lc.TokenType = ttArray then
    begin
      RecogniseArrayType;
    end
    else if AnonymousMethodNext then
    begin
      RecogniseAnonymousMethod;
    end
    else
    begin
      { quick surgery. Perhaps even a hack -
        reclasify the token, as it isn't what it thinks it is
        e.g. if this word is 'then', then
        we don't want a linbreak after it like in if statements }
      lc.TokenType := ttIdentifier;
      Recognise(ttIdentifier);

      { this must be a named value, e.g. "end = 3". See LittleTest43.pas for e.g.s }
      Recognise(ttAssign);
      RecogniseExpr(True);
    end;

  end
  else if lc.TokenType = ttComma then
  begin
    { See TestOleParam: "WordApp.Documents.Open('foo',,,,'bar');"
      params can be skipped
      I guess a missing param has a default value
    }
  end
  else
  begin
    RecogniseExpr(True);

    { ole named param syntax, e.g.
      " MSWord.TextToTable(ConvertFrom := 2, NumColumns := 3);"
    }

    if fcTokenList.FirstSolidTokenType = ttAssign then
    begin
      Recognise(ttAssign);
      RecogniseExpr(True);
    end

      { str width specifiers e.g. " Str(val:0, S);" this is an odd wart on the syntax }
    else if fcTokenList.FirstSolidTokenType = ttColon then
    begin
      { can be more than one of them }
      while fcTokenList.FirstSolidTokenType = ttColon do
      begin
        Recognise(ttColon);
        RecogniseExpr(True);
      end;
    end;
  end;
end;

function TBuildParseTree.AnonymousMethodNext: boolean;
var
  lc, lcNext: TSourceToken;
begin
  Result := False;
  lc := fcTokenList.FirstSolidToken;

  if lc.TokenType in [ttProcedure, ttFunction] then
  begin
    lcNext := fcTokenList.SolidToken(2);
    if lcNext <> nil then
      Result := (lcNext.TokenType in [ttOpenBracket, ttColon]);
  end;
end;

procedure TBuildParseTree.CheckEnumeratorToken;
var
  lc: TSourceToken;
begin
  lc := fcTokenList.FirstSolidToken;
  if (lc<>nil) and (lc.TokenType=ttIdentifier) and (length(lc.SourceCode)=10) and (lowercase(lc.SourceCode)='enumerator') then
  begin
    lc.TokenType:=ttEnumerator;
    lc.WordType:=wtReservedWord;
  end;
  lc := fcTokenList.SolidToken(2);
  if (lc<>nil) and (lc.TokenType=ttIdentifier) and (length(lc.SourceCode)=10) and (lowercase(lc.SourceCode)='enumerator') then
  begin
    lc.TokenType:=ttEnumerator;
    lc.WordType:=wtReservedWord;
  end;
end;

procedure TBuildParseTree.RecogniseLiteralString;
begin
  RecogniseNotSolidTokens;  

  PushNode(nLiteralString);

  while fcTokenList.FirstTokenType in LiteralStringStarters do
  begin
    case fcTokenList.FirstTokenType of
      ttQuotedLiteralString:
      begin
        Recognise(ttQuotedLiteralString);
      end;
      ttHat:
      begin
        Recognise(ttHat);
        // followed by any single char token
        if fcTokenList.FirstTokenLength = 1 then
          Recognise(fcTokenList.FirstTokenType)
        else
          raise TEParseError.Create('Unexpected token, expected single char after ^', fcTokenList.FirstSolidToken);
      end;
      ttHash:
      begin
        Recognise(ttHash);
        Recognise(ttNumber);
      end;
    end;
  end;

  PopNode;
end;

procedure TBuildParseTree.RecogniseAsCast;
begin
  Recognise(ttAs);
  RecogniseIdentifier(True, idStrict);
end;

procedure TBuildParseTree.RecogniseAttributes;
begin
  repeat
    PushNode(nAttribute);

    { Delphi.Net syntax for metadata in square brackets }
    Recognise(ttOpenSquareBracket);
    while fcTokenList.FirstTokenType <> ttCloseSquareBracket do
      Recognise(fcTokenList.FirstTokenType);

    Recognise(ttCloseSquareBracket);

    PopNode;

    RecogniseNotSolidTokens;
  until fcTokenList.FirstTokenType <> ttOpenSquareBracket;
end;

end.

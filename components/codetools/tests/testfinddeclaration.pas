{
 Test with:
   ./testcodetools --suite=TTestFindDeclaration
   ./testcodetools --suite=TestFindDeclaration_Basic
   ./testcodetools --suite=TestFindDeclaration_ClassOf
   ./testcodetools --suite=TestFindDeclaration_With
   ./testcodetools --suite=TestFindDeclaration_NestedClasses
   ./testcodetools --suite=TestFindDeclaration_ClassHelper
   ./testcodetools --suite=TestFindDeclaration_TypeHelper
   ./testcodetools --suite=TestFindDeclaration_ObjCClass
   ./testcodetools --suite=TestFindDeclaration_ObjCCategory
   ./testcodetools --suite=TestFindDeclaration_Generics
   ./testcodetools --suite=TestFindDeclaration_FileAtCursor

 FPC tests:
   ./testcodetools --suite=TestFindDeclaration_FPCTests
   ./testcodetools --suite=TestFindDeclaration_FPCTests --filemask=t*.pp
   ./testcodetools --suite=TestFindDeclaration_FPCTests --filemask=tchlp41.pp
 Laz tests:
   ./testcodetools --suite=TestFindDeclaration_LazTests
   ./testcodetools --suite=TestFindDeclaration_LazTests --filemask=t*.pp
   ./testcodetools --suite=TestFindDeclaration_LazTests --filemask=tdefaultproperty1.pp
}
unit TestFindDeclaration;

{$i runtestscodetools.inc}

{off $define VerboseFindDeclarationTests}

interface

uses
  Classes, SysUtils, contnrs,
  fpcunit, testregistry,
  FileProcs, LazFileUtils, LazLogger,
  CodeToolManager, ExprEval, CodeCache, BasicCodeTools,
  CustomCodeTool, CodeTree, FindDeclarationTool, KeywordFuncLists,
  IdentCompletionTool, DefineTemplates, TestPascalParser;

const
  MarkDecl = '#'; // a declaration, must be unique
  MarkRef = '@'; // a reference to a declaration

type
  TFDMarker = class
  public
    Name: string;
    Kind: char;
    NameStartPos, NameEndPos: integer; // identifier in front of comment
    CleanPos: integer; // comment end
  end;

  { TCustomTestFindDeclaration }

  TCustomTestFindDeclaration = class(TCustomTestPascalParser)
  private
    FMainCode: TCodeBuffer;
    FMarkers: TObjectList;// list of TFDMarker
    FMainTool: TCodeTool;
    function GetMarkers(Index: integer): TFDMarker;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
    function MarkerCount: integer;
    property Markers[Index: integer]: TFDMarker read GetMarkers;
    function AddMarker(const aName: string; Kind: char; CleanPos: integer;
      NameStartPos, NameEndPos: integer): TFDMarker;
    function IndexOfMarker(const aName: string; Kind: char): integer;
    procedure ParseSimpleMarkers(aCode: TCodeBuffer);
    function FindMarker(const aName: string; Kind: char): TFDMarker;
    procedure CheckReferenceMarkers;
    procedure FindDeclarations(Filename: string; ExpandFile: boolean = true);
    procedure FindDeclarations(aCode: TCodeBuffer);
    procedure TestFiles(Directory: string);
    property MainCode: TCodeBuffer read FMainCode;
    property MainTool: TCodeTool read FMainTool;
  end;

  { TTestFindDeclaration }

  TTestFindDeclaration = class(TCustomTestFindDeclaration)
  published
    procedure TestFindDeclaration_Program;
    procedure TestFindDeclaration_Basic;
    procedure TestFindDeclaration_Proc_BaseTypes;
    procedure TestFindDeclaration_With;
    procedure TestFindDeclaration_ClassOf;
    procedure TestFindDeclaration_NestedClasses;
    procedure TestFindDeclaration_ClassHelper;
    procedure TestFindDeclaration_TypeHelper;
    procedure TestFindDeclaration_ObjCClass;
    procedure TestFindDeclaration_ObjCCategory;
    procedure TestFindDeclaration_GenericFunction;
    procedure TestFindDeclaration_Generics_Enumerator;
    procedure TestFindDeclaration_Generics;
    procedure TestFindDeclaration_Generics_GuessType;
    procedure TestFindDeclaration_Generics_GuessType2;
    procedure TestFindDeclaration_Generics_FindDeclaration;
    procedure TestFindDeclaration_GenericsDelphi_InterfaceAncestor;
    procedure TestFindDeclaration_GenericsDelphi_FuncParam;
    procedure TestFindDeclaration_ForIn;
    procedure TestFindDeclaration_FileAtCursor;
    procedure TestFindDeclaration_CBlocks;
    procedure TestFindDeclaration_Arrays;
    procedure TestFindDeclaration_GuessType;
    procedure TestFindDeclaration_Attributes;
    procedure TestFindDeclaration_BracketOpen;
    procedure TestFindDeclaration_AnonymProc;
    procedure TestFindDeclaration_AnonymProc_ExprDot;
    procedure TestFindDeclaration_ArrayMultiDimDot;
    procedure TestFindDeclaration_VarArgsOfType;
    procedure TestFindDeclaration_ProcRef;
    procedure TestFindDeclaration_UnitSearch_CurrentDir;
    // test all files in directories:
    procedure TestFindDeclaration_FPCTests;
    procedure TestFindDeclaration_LazTests;
  end;

implementation

{ TCustomTestFindDeclaration }

procedure TCustomTestFindDeclaration.CheckReferenceMarkers;
var
  i, FoundTopLine, FoundCleanPos, BlockTopLine, BlockBottomLine: Integer;
  Marker, DeclMarker: TFDMarker;
  CursorPos, FoundCursorPos: TCodeXYPosition;
  FoundTool: TFindDeclarationTool;
begin
  for i:=0 to MarkerCount-1 do begin
    Marker:=Markers[i];
    if Marker.Kind=MarkRef then begin
      DeclMarker:=FindMarker(Marker.Name,MarkDecl);
      if DeclMarker=nil then
        Fail('ref has no decl marker. ref "'+Marker.Name+'" at '+MainTool.CleanPosToStr(Marker.CleanPos));
      MainTool.CleanPosToCaret(Marker.NameStartPos,CursorPos);

      // test FindDeclaration
      if not CodeToolBoss.FindDeclaration(CursorPos.Code,CursorPos.X,CursorPos.Y,
        FoundCursorPos.Code,FoundCursorPos.X,FoundCursorPos.Y,FoundTopLine,
        BlockTopLine,BlockBottomLine)
      then begin
        WriteSource(CursorPos);
        Fail('find declaration failed at '+MainTool.CleanPosToStr(Marker.NameStartPos,true)+': '+CodeToolBoss.ErrorMessage);
      end else begin
        FoundTool:=CodeToolBoss.GetCodeToolForSource(FoundCursorPos.Code,true,true) as TFindDeclarationTool;
        if FoundTool<>MainTool then begin
          WriteSource(CursorPos);
          Fail('find declaration at '+MainTool.CleanPosToStr(Marker.NameStartPos,true)
            +' returned wrong tool "'+FoundTool.MainFilename+'" instead of "'+MainTool.MainFilename+'"');
        end;
        MainTool.CaretToCleanPos(FoundCursorPos,FoundCleanPos);
        if (FoundCleanPos<DeclMarker.NameStartPos)
        or (FoundCleanPos>DeclMarker.NameEndPos) then begin
          WriteSource(CursorPos);
          Fail('find declaration at '+MainTool.CleanPosToStr(Marker.NameStartPos,true)
            +' returned wrong position "'+MainTool.CleanPosToStr(FoundCleanPos)+'"'
            +' instead of "'+MainTool.CleanPosToStr(Marker.NameStartPos)+'"');
        end;
      end;
    end;
  end;
end;

procedure TCustomTestFindDeclaration.FindDeclarations(Filename: string;
  ExpandFile: boolean);
var
  aCode: TCodeBuffer;
begin
  if ExpandFile then
    Filename:=TrimAndExpandFilename(Filename);
  {$IFDEF VerboseFindDeclarationTests}
  debugln(['TTestFindDeclaration.FindDeclarations File=',Filename]);
  {$ENDIF}
  aCode:=CodeToolBoss.LoadFile(Filename,true,false);
  if aCode=nil then
    raise Exception.Create('unable to load '+Filename);
  FindDeclarations(aCode);
end;

procedure TCustomTestFindDeclaration.FindDeclarations(aCode: TCodeBuffer);

  procedure PrependPath(Prefix: string; var Path: string);
  begin
    if Path<>'' then Path:='.'+Path;
    Path:=Prefix+Path;
  end;

  function NodeAsPath(Tool: TFindDeclarationTool; Node: TCodeTreeNode): string;
  var
    aName: String;
  begin
    Result:='';
    while Node<>nil do begin
      case Node.Desc of
      ctnTypeDefinition,ctnVarDefinition,ctnConstDefinition,ctnGenericParameter:
        PrependPath(GetIdentifier(@Tool.Src[Node.StartPos]),Result);
      ctnGenericType:
        PrependPath(GetIdentifier(@Tool.Src[Node.FirstChild.StartPos]),Result);
      ctnInterface,ctnUnit:
        PrependPath(Tool.GetSourceName(false),Result);
      ctnProcedure:
        begin
        aName:=Tool.ExtractProcName(Node,[]);
        if aName='' then
          aName:='$ano';
        PrependPath(aName,Result);
        end;
      ctnProperty:
        PrependPath(Tool.ExtractPropName(Node,false),Result);
      ctnUseUnit:
        PrependPath(Tool.ExtractUsedUnitName(Node),Result);
      ctnUseUnitNamespace,ctnUseUnitClearName:
        begin
          PrependPath(GetIdentifier(@Tool.Src[Node.StartPos]),Result);
          if Node.PriorBrother<>nil then begin
            Node:=Node.PriorBrother;
            continue;
          end else
            Node:=Node.Parent;
        end;
      //else debugln(['NodeAsPath ',Node.DescAsString]);
      end;
      Node:=Node.Parent;
    end;
    //debugln(['NodeAsPath ',Result]);
  end;

var
  CommentP: Integer;
  p: Integer;
  ExpectedPath: String;
  PathPos: Integer;
  CursorPos, FoundCursorPos: TCodeXYPosition;
  FoundTopLine: integer;
  FoundTool: TFindDeclarationTool;
  FoundCleanPos: Integer;
  FoundNode: TCodeTreeNode;
  FoundPath: String;
  Src: String;
  NameStartPos, i, l, IdentifierStartPos, IdentifierEndPos,
    BlockTopLine, BlockBottomLine: Integer;
  Marker, ExpectedType, NewType: String;
  IdentItem: TIdentifierListItem;
  ItsAKeyword, IsSubIdentifier: boolean;
  ExistingDefinition: TFindContext;
  ListOfPFindContext: TFPList;
  NewExprType: TExpressionType;
begin
  FMainCode:=aCode;
  DoParseModule(MainCode,FMainTool);
  CommentP:=1;
  Src:=MainTool.Src;
  while CommentP<length(Src) do begin
    CommentP:=FindNextComment(Src,CommentP);
    if CommentP>length(Src) then break;
    p:=CommentP;
    CommentP:=FindCommentEnd(Src,CommentP,MainTool.Scanner.NestedComments);
    if Src[p]<>'{' then continue;
    if Src[p+1] in ['$','%',' ',#0..#31] then continue;

    IdentifierStartPos:=p;
    IdentifierEndPos:=p;
    while (IdentifierStartPos>1) and (IsIdentChar[Src[IdentifierStartPos-1]]) do
      dec(IdentifierStartPos);
    if IdentifierStartPos=p then begin
      WriteSource(p,MainTool);
      Fail('missing identifier in front of marker at '+MainTool.CleanPosToStr(p));
    end;
    inc(p);
    NameStartPos:=p;
    if Src[p] in ['#','@'] then begin
      {#name}  {@name}
      inc(p);
      if not IsIdentStartChar[Src[p]] then begin
        WriteSource(p,MainTool);
        Fail('Expected identifier at '+MainTool.CleanPosToStr(p,true));
      end;
      NameStartPos:=p;
      while IsIdentChar[Src[p]] do inc(p);
      Marker:=copy(Src,NameStartPos,p-NameStartPos);
      AddMarker(Marker,Src[NameStartPos],CommentP,IdentifierStartPos,IdentifierEndPos);
      continue;
    end;

    // check for specials:
    {declaration:path}
    {guesstype:type}
    if not IsIdentStartChar[Src[p]] then continue;
    while (p<=length(Src)) and (IsIdentChar[Src[p]]) do inc(p);
    Marker:=copy(Src,NameStartPos,p-NameStartPos);
    if (p>length(Src)) or (Src[p]<>':') then begin
      WriteSource(p,MainTool);
      AssertEquals('Expected : at '+MainTool.CleanPosToStr(p,true),'declaration',Marker);
      continue;
    end;
    inc(p);
    PathPos:=p;

    //debugln(['TTestFindDeclaration.FindDeclarations Marker="',Marker,'" params: ',dbgstr(MainTool.Src,p,CommentP-p)]);
    if (Marker='declaration') then begin
      ExpectedPath:=copy(Src,PathPos,CommentP-1-PathPos);
      {$IFDEF VerboseFindDeclarationTests}
      debugln(['TTestFindDeclaration.FindDeclarations searching "',Marker,'" at ',MainTool.CleanPosToStr(NameStartPos-1),' ExpectedPath=',ExpectedPath]);
      {$ENDIF}
      MainTool.CleanPosToCaret(IdentifierStartPos,CursorPos);

      // test FindDeclaration
      if not CodeToolBoss.FindDeclaration(CursorPos.Code,CursorPos.X,CursorPos.Y,
        FoundCursorPos.Code,FoundCursorPos.X,FoundCursorPos.Y,FoundTopLine,
        BlockTopLine,BlockBottomLine)
      then begin
        if ExpectedPath<>'' then begin
          //if (CodeToolBoss.ErrorCode<>nil) then begin
            //ErrorTool:=CodeToolBoss.GetCodeToolForSource(CodeToolBoss.ErrorCode);
            //if ErrorTool<>MainTool then
             // WriteSource(,ErrorTool);
          WriteSource(IdentifierStartPos,MainTool);
          Fail('find declaration failed at '+MainTool.CleanPosToStr(IdentifierStartPos,true)+': '+CodeToolBoss.ErrorMessage);
        end;
        continue;
      end else begin
        FoundTool:=CodeToolBoss.GetCodeToolForSource(FoundCursorPos.Code,true,true) as TFindDeclarationTool;
        FoundPath:='';
        FoundNode:=nil;
        if (FoundCursorPos.Y=1) and (FoundCursorPos.X=1) then begin
          // unit
          FoundPath:=ExtractFileNameOnly(FoundCursorPos.Code.Filename);
        end else begin
          FoundTool.CaretToCleanPos(FoundCursorPos,FoundCleanPos);
          if (FoundCleanPos>1) and (IsIdentChar[FoundTool.Src[FoundCleanPos-1]]) then
            dec(FoundCleanPos);
          FoundNode:=FoundTool.FindDeepestNodeAtPos(FoundCleanPos,true);
          //debugln(['TTestFindDeclaration.FindDeclarations Found: ',FoundTool.CleanPosToStr(FoundNode.StartPos,true),' FoundNode=',FoundNode.DescAsString]);
          FoundPath:=NodeAsPath(FoundTool,FoundNode);
        end;
        //debugln(['TTestFindDeclaration.FindDeclarations FoundPath=',FoundPath]);
        if LowerCase(ExpectedPath)<>LowerCase(FoundPath) then begin
          WriteSource(IdentifierStartPos,MainTool);
          AssertEquals('find declaration wrong at '+MainTool.CleanPosToStr(IdentifierStartPos,true),LowerCase(ExpectedPath),LowerCase(FoundPath));
        end;
      end;

      // test identifier completion
      if (ExpectedPath<>'') then begin
        if not CodeToolBoss.GatherIdentifiers(CursorPos.Code,CursorPos.X,CursorPos.Y)
        then begin
          if ExpectedPath<>'' then begin
            WriteSource(IdentifierStartPos,MainTool);
            AssertEquals('GatherIdentifiers failed at '+MainTool.CleanPosToStr(IdentifierStartPos,true)+': '+CodeToolBoss.ErrorMessage,false,true);
          end;
          continue;
        end else begin
          i:=CodeToolBoss.IdentifierList.GetFilteredCount-1;
          while i>=0 do begin
            IdentItem:=CodeToolBoss.IdentifierList.FilteredItems[i];
            //debugln(['TTestFindDeclaration.FindDeclarations ',IdentItem.Identifier]);
            l:=length(IdentItem.Identifier);
            if ((l=length(ExpectedPath)) or (ExpectedPath[length(ExpectedPath)-l]='.'))
            and (CompareText(IdentItem.Identifier,RightStr(ExpectedPath,l))=0)
            then break;
            dec(i);
          end;
          if i<0 then begin
            WriteSource(IdentifierStartPos,MainTool);
            AssertEquals('GatherIdentifiers misses "'+ExpectedPath+'" at '+MainTool.CleanPosToStr(IdentifierStartPos,true),true,i>=0);
          end;
        end;
      end;
    end else if Marker='guesstype' then begin
      ExpectedType:=copy(Src,PathPos,CommentP-1-PathPos);
      {$IFDEF VerboseFindDeclarationTests}
      debugln(['TTestFindDeclaration.FindDeclarations "',Marker,'" at ',Tool.CleanPosToStr(NameStartPos-1),' ExpectedType=',ExpectedType]);
      {$ENDIF}
      MainTool.CleanPosToCaret(IdentifierStartPos,CursorPos);

      // test GuessTypeOfIdentifier
      ListOfPFindContext:=nil;
      try
        if not CodeToolBoss.GuessTypeOfIdentifier(CursorPos.Code,CursorPos.X,CursorPos.Y,
          ItsAKeyword, IsSubIdentifier, ExistingDefinition, ListOfPFindContext,
          NewExprType, NewType)
        then begin
          if ExpectedType<>'' then
            AssertEquals('GuessTypeOfIdentifier failed at '+MainTool.CleanPosToStr(IdentifierStartPos,true)+': '+CodeToolBoss.ErrorMessage,false,true);
          continue;
        end else begin
          //debugln(['TTestFindDeclaration.FindDeclarations FoundPath=',FoundPath]);
          if LowerCase(ExpectedType)<>LowerCase(NewType) then begin
            WriteSource(IdentifierStartPos,MainTool);
            AssertEquals('GuessTypeOfIdentifier wrong at '+MainTool.CleanPosToStr(IdentifierStartPos,true),LowerCase(ExpectedType),LowerCase(NewType));
          end;
        end;
      finally
        FreeListOfPFindContext(ListOfPFindContext);
      end;

    end else begin
      WriteSource(IdentifierStartPos,MainTool);
      AssertEquals('Unknown marker at '+MainTool.CleanPosToStr(IdentifierStartPos,true),'declaration',Marker);
      continue;
    end;
  end;
  CheckReferenceMarkers;
end;

function TCustomTestFindDeclaration.GetMarkers(Index: integer): TFDMarker;
begin
  Result:=TFDMarker(FMarkers[Index]);
end;

procedure TCustomTestFindDeclaration.TestFiles(Directory: string);
const
  fmparam = '--filemask=';
var
  Info: TSearchRec;
  aFilename, Param, aFileMask: String;
  i: Integer;
  Verbose: Boolean;
begin
  aFileMask:='t*.p*';
  Verbose:=false;
  for i:=1 to ParamCount do begin
    Param:=ParamStr(i);
    if LeftStr(Param,length(fmparam))=fmparam then
      aFileMask:=copy(Param,length(fmparam)+1,100);
    if Param='-v' then
      Verbose:=true;
  end;
  Directory:=AppendPathDelim(Directory);

  if FindFirstUTF8(Directory+aFileMask,faAnyFile,Info)=0 then begin
    repeat
      if faDirectory and Info.Attr>0 then continue;
      aFilename:=Info.Name;
      if not FilenameIsPascalUnit(aFilename) then continue;
      if Verbose then
        debugln(['TTestFindDeclaration.TestFiles File="',aFilename,'"']);
      FindDeclarations(Directory+aFilename);
    until FindNextUTF8(Info)<>0;
  end;
end;

procedure TCustomTestFindDeclaration.SetUp;
begin
  inherited SetUp;
  FMarkers:=TObjectList.Create(true);
end;

procedure TCustomTestFindDeclaration.TearDown;
begin
  FMainCode:=nil;
  FMainTool:=nil;
  FreeAndNil(FMarkers);
  inherited TearDown;
end;

function TCustomTestFindDeclaration.MarkerCount: integer;
begin
  if FMarkers=nil then
    Result:=0
  else
    Result:=FMarkers.Count;
end;

function TCustomTestFindDeclaration.AddMarker(const aName: string; Kind: char;
  CleanPos: integer; NameStartPos, NameEndPos: integer): TFDMarker;
begin
  if (Kind=MarkDecl) then begin
    Result:=FindMarker(aName,Kind);
    if Result<>nil then
      Fail('duplicate decl marker at '+MainTool.CleanPosToStr(CleanPos)+' and at '+MainTool.CleanPosToStr(Result.CleanPos));
  end;
  Result:=TFDMarker.Create;
  Result.Name:=aName;
  Result.Kind:=Kind;
  Result.CleanPos:=CleanPos;
  Result.NameStartPos:=NameStartPos;
  Result.NameEndPos:=NameEndPos;
  FMarkers.Add(Result);
end;

function TCustomTestFindDeclaration.IndexOfMarker(const aName: string; Kind: char
  ): integer;
var
  i: Integer;
  Marker: TFDMarker;
begin
  for i:=0 to MarkerCount-1 do begin
    Marker:=Markers[i];
    if (Marker.Kind=Kind) and (CompareText(Markers[i].Name,aName)=0) then
      exit(i);
  end;
  Result:=-1;
end;

procedure TCustomTestFindDeclaration.ParseSimpleMarkers(aCode: TCodeBuffer);
var
  CommentP, p, IdentifierStartPos, IdentifierEndPos, NameStartPos: Integer;
  Src, Marker: String;
begin
  FMainCode:=aCode;
  DoParseModule(MainCode,FMainTool);
  CommentP:=1;
  Src:=MainTool.Src;
  while CommentP<length(Src) do begin
    CommentP:=FindNextComment(Src,CommentP);
    if CommentP>length(Src) then break;
    p:=CommentP;
    CommentP:=FindCommentEnd(Src,CommentP,MainTool.Scanner.NestedComments);
    if Src[p]<>'{' then continue;
    if Src[p+1] in ['$','%',' ',#0..#31] then continue;

    IdentifierStartPos:=p;
    IdentifierEndPos:=p;
    while (IdentifierStartPos>1) and (IsIdentChar[Src[IdentifierStartPos-1]]) do
      dec(IdentifierStartPos);

    inc(p);
    NameStartPos:=p;
    if Src[p] in ['#','@'] then begin
      {#name}  {@name}
      inc(p);
      if not IsIdentStartChar[Src[p]] then begin
        WriteSource(p,MainTool);
        Fail('Expected identifier at '+MainTool.CleanPosToStr(p,true));
      end;
      NameStartPos:=p;
      while IsIdentChar[Src[p]] do inc(p);
      Marker:=copy(Src,NameStartPos,p-NameStartPos);
      AddMarker(Marker,Src[NameStartPos-1],CommentP,IdentifierStartPos,IdentifierEndPos);
    end else begin
      WriteSource(p,MainTool);
      Fail('invalid marker at '+MainTool.CleanPosToStr(p));
    end;
  end;
end;

function TCustomTestFindDeclaration.FindMarker(const aName: string; Kind: char
  ): TFDMarker;
var
  i: Integer;
begin
  i:=IndexOfMarker(aName,Kind);
  if i<0 then
    Result:=nil
  else
    Result:=Markers[i];
end;

procedure TTestFindDeclaration.TestFindDeclaration_Program;
begin
  StartProgram;
  Add([
  'var Cow: longint;',
  'begin',
  '  cow{declaration:Cow}:=3;',
  '  test1{declaration:Test1}.cow{declaration:Cow}:=3;',
  'end.',
  '']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_Basic;
begin
  FindDeclarations('moduletests/fdt_basic.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_Proc_BaseTypes;
begin
  FindDeclarations('moduletests/fdt_proc_basetypes.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_With;
begin
  FindDeclarations('moduletests/fdt_with.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_ClassOf;
begin
  FindDeclarations('moduletests/fdt_classof.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_NestedClasses;
begin
  FindDeclarations('moduletests/fdt_nestedclasses.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_ClassHelper;
begin
  FindDeclarations('moduletests/fdt_classhelper.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_TypeHelper;
begin
  FindDeclarations('moduletests/fdt_typehelper.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_ObjCClass;
begin
  {$IFDEF Darwin}
  FindDeclarations('moduletests/fdt_objcclass.pas');
  {$ENDIF}
end;

procedure TTestFindDeclaration.TestFindDeclaration_ObjCCategory;
begin
  {$IFDEF Darwin}
  FindDeclarations('moduletests/fdt_objccategory.pas');
  {$ENDIF}
end;

procedure TTestFindDeclaration.TestFindDeclaration_GenericFunction;
begin
  StartProgram;
  Add([
  '{$mode objfpc}',
  'type',
  '  TBird = class',
  '    generic class function Fly<T>(const AValues:array of T):T;',
  '  end;',
  'generic function RandomFrom<T>(const AValues:array of T):T;',
  'begin',
  '  Result:=Avalue[1];',
  'end;',
  'generic class function TBird.Fly<T>(const AValues:array of T):T;',
  'begin',
  '  Result:=Avalue[1];',
  'end;',
  'begin',
  '  i:=RandomFrom<longint>([1,2,3]);',
  'end.',
  '']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_Generics_Enumerator;
begin
  StartProgram;
  Add([
  'type',
  '  integer = longint;',
  '  TOwnedCollection = class',
  '  end;',
  '  generic TMyOwnedCollection<T: class> = class(TOwnedCollection)',
  '  public type',
  '    TEnumerator = class',
  '    private',
  '      FIndex: Integer;',
  '      FCol: specialize TMyOwnedCollection<T>;',
  '    public',
  '      constructor Create(ACol: specialize TMyOwnedCollection<T>);',
  '      function GetCurrent: T;',
  '      function MoveNext: Boolean;',
  '      property Current: T read GetCurrent;',
  '    end;',
  '  public',
  '    function GetEnumerator: TEnumerator;',
  '    function GetItem(AIndex: Integer): T;',
  '  end;',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_Generics;
begin
  FindDeclarations('moduletests/fdt_generics.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_Generics_GuessType;
begin
  FindDeclarations('moduletests/fdt_generics_guesstype.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_Generics_GuessType2;
begin
  FindDeclarations('moduletests/fdt_generics_guesstype2.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_Generics_FindDeclaration;
begin
  FindDeclarations('moduletests/fdt_generics_finddeclaration.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_GenericsDelphi_InterfaceAncestor;
begin
  StartProgram;
  Add([
  '{$mode delphi}',
  'type',
  '  IParameters = interface',
  '  end;',
  '  IItem = class',
  '  end;',
  '  IBirdy = interface (IParameters<IItem>)',
  '    [''guid'']',
  '  end;',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_GenericsDelphi_FuncParam;
begin
  StartProgram;
  Add([
  '{$mode delphi}',
  'type',
  '  TAnt<T> = class',
  '  type TEvent = procedure(aSender: T);',
  '  end;',
  '  TBird = class',
  '    procedure Fly<T>(Event: TAnt<T>.TEvent; aSender: T)',
  '  end;',
  'procedure Run(Sender: TObject);',
  'begin',
  'end;',
  'var Bird: TBird;',
  'begin',
  '  Bird.Fly<TObject>(Run,Bird);',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_ForIn;
begin
  FindDeclarations('moduletests/fdt_for_in.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_FileAtCursor;
var
  SubUnit2Code, LFMCode: TCodeBuffer;
  Found: TFindFileAtCursorFlag;
  FoundFilename: string;
begin
  FMainCode:=CodeToolBoss.CreateFile('test1.lpr');
  MainCode.Source:='uses unit2 in ''sub/../unit2.pas'';'+LineEnding;
  SubUnit2Code:=CodeToolBoss.CreateFile('unit2.pas');
  LFMCode:=CodeToolBoss.CreateFile('test1.lfm');
  try
    // --- used unit ---
    // test cursor on 'unit2'
    if not CodeToolBoss.FindFileAtCursor(MainCode,6,1,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at uses unit2');
    AssertEquals('FindFileAtCursor at uses unit2 Found',ord(ffatUsedUnit),ord(Found));
    AssertEquals('FindFileAtCursor at uses unit2 FoundFilename','unit2.pas',FoundFilename);
    // test cursor on 'in'
    if not CodeToolBoss.FindFileAtCursor(MainCode,12,1,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at uses unit2-in');
    AssertEquals('FindFileAtCursor at uses unit2-in Found',ord(ffatUsedUnit),ord(Found));
    AssertEquals('FindFileAtCursor at uses unit2-in FoundFilename','unit2.pas',FoundFilename);
    // test cursor on in-file literal
    if not CodeToolBoss.FindFileAtCursor(MainCode,16,1,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at uses unit2-in-literal');
    AssertEquals('FindFileAtCursor at uses unit2-in-lit Found',ord(ffatUsedUnit),ord(Found));
    AssertEquals('FindFileAtCursor at uses unit2-in-lit FoundFilename','unit2.pas',FoundFilename);

    // --- enabled include directive ---
    // test cursor on enabled include directive of empty file
    MainCode.Source:='program test1;'+LineEnding
      +'{$i unit2.pas}'+LineEnding;
    SubUnit2Code.Source:='';
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at enabled include directive of empty inc');
    AssertEquals('FindFileAtCursor at enabled include directive of empty Found',ord(ffatIncludeFile),ord(Found));
    AssertEquals('FindFileAtCursor at enabled include directive of empty FoundFilename','unit2.pas',FoundFilename);

    // test cursor on enabled include directive of not empty file
    SubUnit2Code.Source:='{$define a}';
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at enabled include directive of non-empty inc');
    AssertEquals('FindFileAtCursor at enabled include directive of non-empty Found',ord(ffatIncludeFile),ord(Found));
    AssertEquals('FindFileAtCursor at enabled include directive of non-empty FoundFilename','unit2.pas',FoundFilename);

    // --- disabled include directive ---
    // test cursor on disabled include directive
    MainCode.Source:='program test1;'+LineEnding
      +'{$ifdef disabled}'+LineEnding
      +'{$i unit2.pas}'+LineEnding
      +'{$endif}'+LineEnding;
    SubUnit2Code.Source:='';
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,3,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at disabled include directive');
    AssertEquals('FindFileAtCursor at disabled include directive Found',ord(ffatDisabledIncludeFile),ord(Found));
    AssertEquals('FindFileAtCursor at disabled include directive FoundFilename','unit2.pas',FoundFilename);

    // --- enabled resource directive ---
    MainCode.Source:='program test1;'+LineEnding
      +'{$R test1.lfm}'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at enabled resource directive');
    AssertEquals('FindFileAtCursor at enabled resource directive Found',ord(ffatResource),ord(Found));
    AssertEquals('FindFileAtCursor at enabled resource directive FoundFilename','test1.lfm',FoundFilename);

    MainCode.Source:='program test1;'+LineEnding
      +'{$R *.lfm}'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at enabled resource directive');
    AssertEquals('FindFileAtCursor at enabled resource directive Found',ord(ffatResource),ord(Found));
    AssertEquals('FindFileAtCursor at enabled resource directive FoundFilename','test1.lfm',FoundFilename);

    // --- disabled resource directive ---
    MainCode.Source:='program test1;'+LineEnding
      +'{$ifdef disabled}'+LineEnding
      +'{$R test1.lfm}'+LineEnding
      +'{$endif}'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,1,3,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor at disabled resource directive');
    AssertEquals('FindFileAtCursor at disabled resource directive Found',ord(ffatDisabledResource),ord(Found));
    AssertEquals('FindFileAtCursor at disabled resource directive FoundFilename','test1.lfm',FoundFilename);

    // --- literal ---
    MainCode.Source:='program test1;'+LineEnding
      +'const Cfg=''unit2.pas'';'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,11,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor in literal');
    AssertEquals('FindFileAtCursor in literal Found',ord(ffatLiteral),ord(Found));
    AssertEquals('FindFileAtCursor in literal FoundFilename','unit2.pas',FoundFilename);

    // --- comment ---
    MainCode.Source:='program test1;'+LineEnding
      +'{unit2.pas}'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,3,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor in comment');
    AssertEquals('FindFileAtCursor in comment Found',ord(ffatComment),ord(Found));
    AssertEquals('FindFileAtCursor in comment FoundFilename','unit2.pas',FoundFilename);

    // --- unit name search in comment ---
    MainCode.Source:='program test1;'+LineEnding
      +'{unit2}'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,3,2,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor in comment');
    AssertEquals('FindFileAtCursor in comment Found',ord(ffatUnit),ord(Found));
    AssertEquals('FindFileAtCursor in comment FoundFilename','unit2.pas',FoundFilename);

    // --- unit name search in MainCode ---
    MainCode.Source:='program test1;'+LineEnding
      +'begin'+LineEnding
      +'  unit2.Test;'+LineEnding;
    if not CodeToolBoss.FindFileAtCursor(MainCode,3,3,Found,FoundFilename) then
      Fail('CodeToolBoss.FindFileAtCursor in comment');
    AssertEquals('FindFileAtCursor in comment Found',ord(ffatUnit),ord(Found));
    AssertEquals('FindFileAtCursor in comment FoundFilename','unit2.pas',FoundFilename);

  finally
    MainCode.IsDeleted:=true;
    SubUnit2Code.IsDeleted:=true;
    LFMCode.IsDeleted:=true;
  end;
end;

procedure TTestFindDeclaration.TestFindDeclaration_CBlocks;
begin
  StartProgram;
  Add([
    '{$modeswitch cblocks}',
    'type tblock = reference to procedure; cdecl;',
    'procedure test(b: tblock);',
    'begin',
    '  b;',
    'end;',
    'procedure proc;',
    'begin',
    'end;',
    'const bconst: tblock = @proc;',
    'var',
    '  b: tblock;',
    'begin',
    '  b:=@proc;',
    '  b;',
    '  test{declaration:test1.test}(@proc);',
    '  test{declaration:test1.test}(b);',
    '  bconst{declaration:test1.bconst};',
    '  test{declaration:test1.test}(bconst{declaration:test1.bconst});',
    'end.',
  '']);
  ParseModule;
end;

procedure TTestFindDeclaration.TestFindDeclaration_Arrays;
begin
  FindDeclarations('moduletests/fdt_arrays.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_GuessType;
begin
  FindDeclarations('moduletests/fdt_guesstype1.pas');
end;

procedure TTestFindDeclaration.TestFindDeclaration_Attributes;
var
  Node: TCodeTreeNode;
  p: Integer;
  Src: String;
begin
  StartProgram;
  Add([
  '{$modeswitch prefixedattributes}',
  'type',
  '  TCustomAttribute = class',
  '  end;',
  '  BirdAttribute = class(TCustomAttribute)',
  '  end;',
  '  Bird = class(TCustomAttribute)',
  '  end;',
  '  [Bird{declaration:BirdAttribute}]',
  '  THawk = class',
  '    [Bird{declaration:BirdAttribute}(1)]',
  '    FField: integer;',
  '    [Bird(2)]',
  '    procedure DoSome;',
  '    [Bird(3)]',
  '    property  F: integer read FField;',
  '  end;',
  '  IMy = interface',
  '    [''guid'']',
  '    [Bird]',
  '    [Bird(12)]',
  '    function GetSome: integer;',
  '    [Bird(13)]',
  '    property  Some: integer read GetSome;',
  '  end;',
  '  IMy = dispinterface',
  '    [''guid'']',
  '    [Bird(21)]',
  '    function GetMore: integer;',
  '  end;',
  '[test1.bird]',
  '[bird(4)]',
  'procedure DoIt; forward;',
  '[bird(5)]',
  'procedure DoIt;',
  'begin',
  'end;',
  'var',
  '  [bird(1+2,3),bird]',
  '  Foo: TObject;',
  'begin',
  'end.',
  '']);
  FindDeclarations(Code);
  // check if all attributes were parsed
  Src:=MainTool.Src;
  for p:=1 to length(Src) do begin
    if (Src[p]='[') and (IsIdentStartChar[Src[p+1]]) then begin
      Node:=MainTool.FindDeepestNodeAtPos(p,false);
      if (Node=nil) then begin
        WriteSource(p,MainTool);
        Fail('missing node at '+MainTool.CleanPosToStr(p));
      end;
      if (Node.Desc<>ctnAttribute) then begin
        WriteSource(p,MainTool);
        Fail('missing attribute at '+MainTool.CleanPosToStr(p));
      end;
      if Node.NextBrother=nil then begin
        WriteSource(Node.StartPos,MainTool);
        Fail('Attribute without NextBrother');
      end;
      if not (Node.NextBrother.Desc in [ctnAttribute,ctnVarDefinition,ctnTypeDefinition,ctnProcedure,ctnProperty])
      then begin
        WriteSource(Node.StartPos,MainTool);
        Fail('Attribute invalid NextBrother '+Node.NextBrother.DescAsString);
      end;
    end;
  end;
end;

procedure TTestFindDeclaration.TestFindDeclaration_BracketOpen;
begin
  StartProgram;
  Add([
  'var c: integer;',
  'procedure DoIt(i: integer);',
  '  procedure WriteStr(s: string);',
  '  begin',
  '  end;',
  'begin',
  '  begin',
  '    DoIt(c{declaration:c}',
  '  end;',
  '  begin',
  '    WriteStr(c{declaration:c}',
  '  end;',
  'end;',
  'begin',
  'end.',
  '']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_AnonymProc;
begin
  StartProgram;
  Add([
  '{$mode objfpc}{$modeswitch closures}',
  'type',
  '  int = word;',
  '  TFunc = function(i: int): int;',
  'var f: TFunc;',
  'procedure DoIt(a: int);',
  '  procedure Sub(b: int);',
  '  begin',
  '    f:=function(c: int{declaration:int}): int{declaration:int}',
  '      begin',
  '        f{declaration:f}:=nil;',
  '        a{declaration:doit.a}:=b{declaration:doit.sub.b}+c{declaration:doit.sub.$ano.c};',
  '      end;',
  '    DoIt(function(i: int{declaration:int}): int{declaration:int}',
  '      begin',
  '        a{declaration:doit.a}:=b{declaration:doit.sub.b}+i{declaration:doit.sub.$ano.i};',
  '      end);',
  '  end;',
  'begin',
  'end;',
  'begin',
  'end.',
  '']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_AnonymProc_ExprDot;
begin
  StartProgram;
  Add([
  '{$mode objfpc}{$modeswitch closures}',
  'type',
  '  int = word;',
  '  TFunc = function(i: int): int;',
  'var f: TFunc;',
  'function DoIt(f: TProc): TObject{declaration:system.tobject};',
  'begin',
  '  DoIt(nil).ClassInfo{declaration:system.tobject.classinfo};',
  '  DoIt(function(c: int{declaration:int}): int{declaration:int}',
  '      type t = record o:byte end;',
  '      var w: t;',
  '      const v = 4;',
  '      begin',
  '        repeat until true;',
  '        asm end;',
  '        try except end;',
  '      end).ClassInfo{declaration:system.tobject.classinfo};',
  'end;',
  'begin',
  'end.',
  '']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_ArrayMultiDimDot;
begin
  StartProgram;
  Add([
  'type',
  '  TmyClass = class',
  '    Field: integer;',
  '  end;',
  '  TArray1 = array of TmyClass;',
  '  TArray2 = array of TArray1;',
  'var',
  '  tmp: TArray2;',
  'begin',
  '  tmp[0,0].Field{declaration:tmyclass.field};',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_VarArgsOfType;
begin
  StartProgram;
  Add([
  'procedure Run; varargs of word;',
  'begin',
  '  Run{declaration:run}(1,2);',
  'end;',
  'procedure Fly; varargs;',
  'begin',
  '  Run{declaration:run}(2,3);',
  'end;',
  'begin',
  '  Run{declaration:run}(3);',
  '  Fly{declaration:fly}(4);',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_ProcRef;
begin
  StartProgram;
  Add([
  'type',
  '  TProc = procedure of object;',
  '  TFoo = class',
  '  private',
  '    FTest: TClassProcedure;',
  '  public',
  '    procedure TestProc;',
  '    property Test: TProc read FTest write FTest;',
  '  end;',
  'procedure TFoo.TestProc;',
  'begin',
  '  Self.Test{declaration:TFoo.Test} := @TestProc{declaration:TFoo.TestProc};',
  '  Test{declaration:TFoo.Test} := @Self.TestProc{declaration:TFoo.TestProc};',
  '  // TestProc{declaration:TFoo.TestProc}',
  'end;',
  'var Foo: TFoo;',
  'begin',
  '  Foo.Test{declaration:TFoo.Test} := @Foo.TestProc{declaration:TFoo.TestProc};',
  '  with Foo do',
  '    Test{declaration:TFoo.Test} := @TestProc{declaration:TFoo.TestProc};',
  'end.']);
  FindDeclarations(Code);
end;

procedure TTestFindDeclaration.TestFindDeclaration_UnitSearch_CurrentDir;
var
  Unit1A, Unit1B: TCodeBuffer;
  DefTemp: TDefineTemplate;
begin
  Unit1A:=CodeToolBoss.CreateFile('unit1.pas');
  Unit1A.Source:=
    'unit unit1;'+sLineBreak
    +'interface'+sLineBreak
    +'var r: word;'+sLineBreak
    +'implementation'+sLineBreak
    +'end.';
  Unit1B:=CodeToolBoss.CreateFile('sub'+PathDelim+'unit1.pas');
  Unit1B.Source:=
    'unit unit1;'+sLineBreak
    +'interface'+sLineBreak
    +'implementation'+sLineBreak
    +'end.';

  DefTemp:=TDefineTemplate.Create('unitpath','add sub',UnitPathMacroName,'sub',da_Define);
  try
    StartProgram;
    Add([
    'uses unit1;',
    'begin',
    '  r{declaration:unit1.r}:=3;',
    'end.']);
    CodeToolBoss.DefineTree.Add(DefTemp);

    //debugln(['TTestFindDeclaration.TestFindDeclaration_UnitSearch_CurrentDir ',CodeToolBoss.GetUnitPathForDirectory('')]);

    FindDeclarations(Code);
  finally
    Unit1A.IsDeleted:=true;
    Unit1B.IsDeleted:=true;
    CodeToolBoss.DefineTree.RemoveDefineTemplate(DefTemp);
  end;
end;

procedure TTestFindDeclaration.TestFindDeclaration_FPCTests;
begin
  TestFiles('fpctests');
end;

procedure TTestFindDeclaration.TestFindDeclaration_LazTests;
begin
  TestFiles('laztests');
end;

initialization
  RegisterTests([TTestFindDeclaration]);
end.


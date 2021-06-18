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
    This unit is part of the IDE's help system. It implements the help for
    sources via fpdoc files and Pascal comments.
}
unit CodeHelp;

{$mode objfpc}{$H+}

{off $DEFINE VerboseCodeHelp}
{off $DEFINE VerboseCodeHelpFails}
{off $DEFINE VerboseHints}

{$IFDEF VerboseCodeHelp}
  {$DEFINE VerboseCodeHelpFails}
{$ENDIF}

interface

uses
  // RTL + FCL
  Classes, SysUtils, Laz_AVL_Tree,
  // LCL
  LCLProc, Forms, Controls, Dialogs,
  // CodeTools
  CodeAtom, CodeTree, CodeToolManager, FindDeclarationTool, BasicCodeTools,
  KeywordFuncLists, PascalParserTool, CodeCache, CacheCodeTools, CustomCodeTool,
  FileProcs, DefineTemplates,
  // LazUtils
  AvgLvlTree, FileUtil, LazFileUtils, LazUTF8, LazFileCache, LazMethodList,
  LazLoggerBase, Laz2_DOM, Laz2_XMLRead, Laz2_XMLWrite,
  // SynEdit
  SynHighlighterPas,
  // IDEIntf
  IDECommands, IDEMsgIntf, MacroIntf, PackageIntf, LazHelpIntf, ProjectIntf,
  IDEDialogs, IDEHelpIntf, LazIDEIntf, IDEExternToolIntf,
  // IDE
  EditorOptions, LazarusIDEStrConsts, IDEProcs, PackageDefs,
  EnvironmentOpts, TransferMacros, PackageSystem, DialogProcs, KeyMapping;

const
  IDEProjectName = 'Lazarus';
  FPCDocsRepositoryURL = 'http://svn.freepascal.org/svn/fpcdocs/trunk';
type
  TFPDocItem = (
    fpdiShort,
    fpdiElementLink,
    fpdiDescription,
    fpdiErrors,
    fpdiSeeAlso,
    fpdiExample
    );

  TFPDocElementValues = array [TFPDocItem] of String;
  
const
  FPDocItemNames: array[TFPDocItem] of shortstring = (
      'short',
      'elementlink',
      'descr',
      'errors',
      'seealso',
      'example'
    );

type
  TLazFPDocFileFlag = (
    ldffDocChangingCalled,
    ldffDocChangedNeedsCalling
    );
  TLazFPDocFileFlags = set of TLazFPDocFileFlag;

  { TLazFPDocFile
    An fpdoc xml file. The CodeBuffer is the xml source. The Doc is the parsed dom tree. }

  TLazFPDocFile = class
  private
    fUpdateLock: integer;
    FFlags: TLazFPDocFileFlags;
    FDocChangeStamp: int64;
    FDocSaveChangeStamp: int64;
    function GetDocModified: boolean;
    procedure SetDocModified(AValue: boolean);
  public
    Filename: string;// the fpdoc xml filename
    Doc: TXMLdocument;// IMPORTANT: if you change this, call DocChanging and DocChanged to notify the references
    DocErrorMsg: string; // if xml is broken, Doc could not be created
    CodeBufferChangeStep: integer;// the CodeBuffer.ChangeStep value, when Doc was built
    CodeBuffer: TCodeBuffer;
    constructor Create;
    destructor Destroy; override;
    function GetPackageNode: TDOMNode; // the lazarus project or package
    function GetPackageName: string;
    function GetModuleNode: TDOMNode; // the unit
    function GetModuleName: string;
    function GetModuleTopicCount: Integer;
    function GetModuleTopicName(Index: Integer): String;
    function GetModuleTopic(Name: String): TDOMNode;
    function CreateModuleTopic(Name: String): TDOMNode;
    function GetFirstElement: TDOMNode;
    function GetElementWithName(const ElementName: string;
                                CreateIfNotExists: boolean = false): TDOMNode;
    function GetChildValuesAsString(Node: TDOMNode): String;
    function GetValuesFromNode(Node: TDOMNode): TFPDocElementValues;
    function GetValueFromNode(Node: TDOMNode; Item: TFPDocItem): string;
    procedure SetChildValue(Node: TDOMNode; const ChildName: string; NewValue: string);
    property DocModified: boolean read GetDocModified write SetDocModified;
    property DocChangeStamp: int64 read FDocChangeStamp;
    procedure DocChanging;
    procedure DocChanged;
    procedure BeginUpdate;
    procedure EndUpdate;
  end;

  { TLazFPDocNode }

  TLazFPDocNode = class
  public
    DocFile: TLazFPDocFile;
    Node: TDomNode;
    constructor Create(AFile: TLazFPDocFile; ANode: TDOMNode);
  end;
  
  { TCHSourceToFPDocFile - cache item for source to FPDoc file mapping }

  TCHSourceToFPDocFile = class
  public
    SourceFilename: string;
    FPDocFilename: string;
    FPDocFileOwner: TObject; // always check FPDocFilenameTimeStamp before accessing
    FPDocFilenameTimeStamp: integer; // corresponds to CompilerParseStamp
    FilesTimeStamp: int64; // corresponds to FileStateCache.TimeStamp
    function IsValid: boolean;
    procedure MakeValid;
  end;
  
  { TCodeHelpElement - mapping between one codetools position and a fpdoc xml node.
    This data is only valid as long as codetools data and fpdoc data are not
    changed, so don't store it. }

  TCodeHelpElement = class
  public
    CodeContext: TFindContext;
    CodeXYPos: TCodeXYPosition;
    ElementOwnerName: string;// the name of the lazarus package or project
    ElementFPDocPackageName: string;
    ElementUnitName: string;
    ElementUnitFileName: string;
    ElementName: string;
    ElementNode: TDOMNode; // nil = not yet parsed (ElementNodeValid=false) or does not exist (ElementNodeValid=true)
    ElementNodeValid: boolean;
    FPDocFile: TLazFPDocFile;
    procedure WriteDebugReport;
  end;
  
  { TCodeHelpElementChain - a list of TCodeHelpElement.
    For example the list of one element plus its ancestors.
    Only valid for short time. So always check IsValid. }

  TCodeHelpElementChain = class
  private
    FItems: TFPList; // list of TCodeHelpElement
    function GetCount: integer;
    function GetItems(Index: integer): TCodeHelpElement;
    function Add: TCodeHelpElement;
  public
    CodePos: TCodePosition;
    IDEChangeStep: integer; // corresponds to CompilerParseStamp
    CodetoolsChangeStep: integer; // corresponds to CodeToolBoss.CodeTreeNodesDeletedStep
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    property Items[Index: integer]: TCodeHelpElement read GetItems; default;
    property Count: integer read GetCount;
    function IndexOfFile(AFile: TLazFPDocFile): integer;
    function IndexOfElementName(ElementName: string): integer;
    function IndexOfElementName(ElementUnitName, ElementName: string): integer;
    function IsValid: boolean;
    procedure MakeValid;
    function DocFile: TLazFPDocFile; // DocFile of first element
    procedure WriteDebugReport;
  end;
  
  TCodeHelpChangeEvent = procedure(Sender: TObject; LazFPDocFile: TLazFPDocFile) of object;
  
  TCodeHelpManagerHandler = (
    chmhDocChanging,
    chmhDocChanged
    );

  TCodeHelpOpenFileFlag = (
    chofUpdateFromDisk,
    chofRevert,
    chofQuiet
    );
  TCodeHelpOpenFileFlags = set of TCodeHelpOpenFileFlag;
    
  TCodeHelpParseResult = (
    chprParsing, // means: done a small step, but not yet finished the job
    chprFailed,
    chprSuccess
    );

  TCodeHelpHintOption = (
    chhoSmallStep,         // do the next step. Use this to run on idle.
    chhoDeclarationHeader, // add a header with source position and type of identifier
    chhoComments,          // add the pasdoc comments
    chhoShowFocusHint      // show the shortcut ecFocusHint
  );
  TCodeHelpHintOptions = set of TCodeHelpHintOption;
    
  { TCodeHelpManager }

  TCodeHelpManager = class(TComponent)
  private
    FDocs: TAvlTree;// tree of loaded TLazFPDocFile
    FHandlers: array[TCodeHelpManagerHandler] of TMethodList;
    FPasHighlighter: TSynPasSyn;
    FSrcToDocMap: TAvlTree; // tree of TCHSourceToFPDocFile sorted for SourceFilename
    FDeclarationCache: TDeclarationInheritanceCache;
    procedure AddHandler(HandlerType: TCodeHelpManagerHandler;
                         const AMethod: TMethod; {%H-}AsLast: boolean = false);
    procedure RemoveHandler(HandlerType: TCodeHelpManagerHandler;
                            const AMethod: TMethod);
    procedure FreeHandlers;
    procedure CallDocChangeEvents(HandlerType: TCodeHelpManagerHandler;
                                  Doc: TLazFPDocFile);
    function DoCreateFPDocFileForSource(const SrcFilename: string;
                                        out NewOwner: TObject): string;
    function CreateFPDocFile(const ExpandedFilename, PackageName,
                             ModuleName: string): TCodeBuffer;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure FreeDocs;
    procedure ClearSrcToDocMap;

    function FindFPDocFile(const Filename: string): TLazFPDocFile;
    function LoadFPDocFile(const Filename: string;
                           Flags: TCodeHelpOpenFileFlags;
                           out ADocFile: TLazFPDocFile;
                           out CacheWasUsed: boolean): TCodeHelpParseResult;
    function SaveFPDocFile(ADocFile: TLazFPDocFile): TModalResult;
    function GetFPDocFilenameForHelpContext(
                                       Context: TPascalHelpContextList;
                                       out CacheWasUsed: boolean): string;
    function GetFPDocFilenameForSource(SrcFilename: string;
                                       ResolveIncludeFiles: Boolean;
                                       out CacheWasUsed: boolean;
                                       out AnOwner: TObject;// a package or a project or LazarusHelp or nil for user defined
                                       CreateIfNotExists: boolean = false): string;
    procedure GetFPDocFilenamesForSources(SrcFilenames: TFilenameToStringTree;
                      ResolveIncludeFiles: boolean;
                      var FPDocFilenames: TFilenameToStringTree // Filename to ModuleName
                      );
    function GetIDESrcFPDocPath: string; // $(LazarusDir)/docs/xml/ide/
    function IsIDESrcFile(const SrcFilename: string): boolean;
    function FindFPDocPackageOwner(const PackageName: string): TObject;
    function FindModuleOwner(FPDocFile: TLazFPDocFile): TObject;
    function GetModuleOwnerName(TheOwner: TObject): string;
    function GetFPDocPackageNameByOwner(TheOwner: TObject): string;
    function ExpandFPDocLinkID(const LinkID, DefaultUnitName,
                               DefaultOwnerName: string): string;
    function ExpandFPDocLinkID(const LinkID, DefaultUnitName: string;
                               TheOwner: TObject): string;
    function CodeNodeToElementName(Tool: TFindDeclarationTool;
                                   CodeNode: TCodeTreeNode): string;
    function GetFPDocNode(Tool: TCodeTool; CodeNode: TCodeTreeNode; Complete: boolean;
                          out FPDocFile: TLazFPDocFile; out DOMNode: TDOMNode;
                          out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetLinkedFPDocNode(StartFPDocFile: TLazFPDocFile;
                          StartDOMNode: TDOMNode;
                          const Path: string;
                          Flags: TCodeHelpOpenFileFlags;
                          out ModuleOwner: TObject;
                          out FPDocFile: TLazFPDocFile; out DOMNode: TDOMNode;
                          out InvalidPath: integer;
                          out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetDeclarationChain(Code: TCodeBuffer; X, Y: integer;
                                 out ListOfPCodeXYPosition: TFPList;
                                 out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetCodeContext(CodePos: PCodeXYPosition;
                            out FindContext: TFindContext;
                            {%H-}Complete: boolean;
                            out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetElementChain(Code: TCodeBuffer; X, Y: integer; Complete: boolean;
                             out Chain: TCodeHelpElementChain;
                             out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetHTMLHint(Code: TCodeBuffer; X, Y: integer; Options: TCodeHelpHintOptions;
                     out BaseURL, HTMLHint, PropDetails: string;
                     out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetHTMLHintForNode(CTTool: TFindDeclarationTool; CTNode: TCodeTreeNode;
                     XYPos: TCodeXYPosition; Options: TCodeHelpHintOptions;
                     out BaseURL, HTMLHint: string;
                     out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetHTMLHintForExpr(CTExprType: TExpressionType;
                     XYPos: TCodeXYPosition; Options: TCodeHelpHintOptions;
                     out BaseURL, HTMLHint: string;
                     out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetHTMLHintForUnit(AUnitName, InFilename: string; BaseDir: string;
                     Options: TCodeHelpHintOptions;
                     out BaseURL, HTMLHint: string;
                     out CacheWasUsed: boolean): TCodeHelpParseResult;
    function GetHTMLDeclarationHeader(Tool: TFindDeclarationTool;
                           Node: TCodeTreeNode; XYPos: TCodeXYPosition): string;
    function GetHTMLDeclarationHeader(Tool: TFindDeclarationTool;
      Node: TCodeTreeNode; Desc: TExpressionTypeDesc; XYPos: TCodeXYPosition): string;
    function GetPasDocCommentsAsHTML(Tool: TFindDeclarationTool; Node: TCodeTreeNode): string;
    function GetFPDocNodeAsHTML(FPDocFile: TLazFPDocFile; DOMNode: TDOMNode): string;
    function TextToHTML(Txt: string): string;
    function CreateElement(Code: TCodeBuffer; X, Y: integer;
                           out Element: TCodeHelpElement): Boolean;
    function SourceToFPDocHint(Src: string; NestedComments: boolean = true): string;
    function SourcePosToFPDocHint(XYPos: TCodeXYPosition; Caption: string=''): string;
    function SourcePosToFPDocHint(const aFilename: string; X,Y: integer;
                                  Caption: string=''): string;
    function OwnerToFPDocHint(AnOwner: TObject): string;
    function FPDocLinkToURL(FPDocFile: TLazFPDocFile; const LinkID: string): string;
  public
    // Event lists
    procedure RemoveAllHandlersOfObject(AnObject: TObject);
    procedure AddHandlerOnChanging(const OnDocChangingEvent: TCodeHelpChangeEvent;
                                   AsLast: boolean = false);
    procedure RemoveHandlerOnChanging(const OnDocChangingEvent: TCodeHelpChangeEvent);
    procedure AddHandlerOnChanged(const OnDocChangedEvent: TCodeHelpChangeEvent;
                                  AsLast: boolean = false);
    procedure RemoveHandlerOnChanged(const OnDocChangedEvent: TCodeHelpChangeEvent);
  public
    property PasHighlighter: TSynPasSyn read FPasHighlighter;
  end;

  TFPDocHintToken = (
    fpdhtText,
    fpdhtKeyword,
    fpdhtString,
    fpdhtNumber,
    fpdhtSymbol
    );
  TFPDocHintTokens = set of TFPDocHintToken;

var
  CodeHelpBoss: TCodeHelpManager = nil;// set by the IDE
  
function CompareLazFPDocFilenames(Data1, Data2: Pointer): integer;
function CompareAnsistringWithLazFPDocFile(Key, Data: Pointer): integer;
function CompareLDSrc2DocSrcFilenames(Data1, Data2: Pointer): integer;
function CompareAnsistringWithLDSrc2DocSrcFile(Key, Data: Pointer): integer;

function ToUnixLineEnding(const s: String): String;
function ToOSLineEnding(const s: String): String;
function ReplaceLineEndings(const s, NewLineEnds: string): string;
function AppendLineEnding(const s: string): string; // append if not empty and there is not already a line ending
function XMLUnescape(s: string): string; // convert escape characters
function MakeValidFPDocPackageName(const s: string): string;

implementation

function ToUnixLineEnding(const s: String): String;
var
  p: Integer;
begin
  Result:=s;
  p:=1;
  while (p<=length(Result)) do begin
    case Result[p] of
    #10:
      if (p<length(Result)) and (Result[p+1] in [#10,#13])
      and (Result[p]<>Result[p+1]) then begin
        // double character line ending
        System.Delete(Result,p,2);
      end;
    #13:
      begin
        // single char line ending #13
        Result[p]:=#10;
      end;
    end;
    inc(p);
  end;
end;

function ToOSLineEnding(const s: String): String;
const
  le: shortstring = LineEnding;
var
  p: Integer;
begin
  Result:=s;
  p:=1;
  while (p<=length(Result)) do begin
    if not (Result[p] in [#10,#13]) then begin
      inc(p);
    end else begin
      // line ending
      if (p<length(Result)) and (Result[p+1] in [#10,#13]) and (Result[p]<>Result[p+1]) then begin
        // double character line ending
        if (length(le)<>2)
        or (le[1]<>Result[p]) or (le[2]<>Result[p+1]) then begin
          Result:=copy(Result,1,p-1)+le+copy(Result,p+2,length(Result));
          inc(p, length(le)-1);
        end
        else
          inc(p);
      end else begin
        // single char line ending #13 or #10
        if (length(le)<>1)
        or (le[1]<>Result[p]) then begin
          Result:=copy(Result,1,p-1)+le+copy(Result,p+1,length(Result));
          inc(p, length(le)-1);
        end;
      end;
      inc(p);
    end;
  end;
end;

function ReplaceLineEndings(const s, NewLineEnds: string): string;
var
  p: Integer;
  StartPos: LongInt;
begin
  Result:=s;
  p:=1;
  while (p<=length(Result)) do begin
    if Result[p] in [#10,#13] then begin
      StartPos:=p;
      if (p<length(Result))
      and (Result[p+1] in [#10,#13]) and (Result[p]<>Result[p+1]) then
        inc(p);
      Result:=copy(Result,1,StartPos-1)+NewLineEnds+copy(Result,p+1,length(Result));
      inc(p,length(NewLineEnds));
    end else begin
      inc(p);
    end;
  end;
end;

function AppendLineEnding(const s: string): string;
begin
  Result:=s;
  if (Result='') or (Result[length(Result)] in [#10,#13]) then exit;
  Result:=Result+LineEnding;
end;

function XMLUnescape(s: string): string;
var
  p: PChar;

  procedure Replace(StartPos: PChar; const NewTxt: string);
  var
    RelStartP: PtrInt;
  begin
    RelStartP:=StartPos-PChar(s);
    s:=copy(s,1,RelStartP)+NewTxt+copy(s,p-PChar(s)+1,length(s));
    p:=PChar(s)+RelStartP+length(NewTxt);
  end;

var
  StartPos: PChar;
  i: Integer;
  CurChar: String;
begin
  if s='' then exit('');
  p:=PChar(s);
  repeat
    if (p^=#0) and (p-PChar(s)>=length(s)) then
      break
    else if p^='&' then begin
      StartPos:=p;
      CurChar:='';
      case p[1] of
      '0'..'9':
        begin
          // decimal number
          i:=0;
          while p^ in ['0'..'9'] do
          begin
            if i>=0 then
              i:=i+10+ord(p^)-ord('0');
            if i>$10FFFF then
              i:=-1;
            inc(p);
          end;
          if i>=0 then
            CurChar:=UnicodeToUTF8(i);
        end;
      'a'..'z','A'..'Z':
        begin
          // name
          inc(p);
          while not (p^ in [';',#0]) do inc(p);
          if p^=';' then begin
            if CompareIdentifiers(StartPos+1,'amp')=0 then
              CurChar:='&'
            else if CompareIdentifiers(StartPos+1,'quot')=0 then
              CurChar:='"'
            else if CompareIdentifiers(StartPos+1,'apos')=0 then
              CurChar:=''''
            else if CompareIdentifiers(StartPos+1,'lt')=0 then
              CurChar:='<'
            else if CompareIdentifiers(StartPos+1,'gt')=0 then
              CurChar:='>';
          end;
        end;
      end;
      while not (p^ in [';',#0]) do inc(p);
      if p^=';' then inc(p);
      Replace(StartPos,CurChar);
    end else
      inc(p);
  until false;
  Result:=s;
end;

function MakeValidFPDocPackageName(const s: string): string;
var
  i: Integer;
begin
  Result:=s;
  for i:=length(Result) downto 1 do
    if not (Result[i] in ['a'..'z','A'..'Z','0'..'9','_',' ',',','+','-','/','(',')'])
    then
      system.Delete(Result,i,1);
end;

function CompareLazFPDocFilenames(Data1, Data2: Pointer): integer;
begin
  Result:=CompareFilenames(TLazFPDocFile(Data1).Filename,
                           TLazFPDocFile(Data2).Filename);
end;

function CompareAnsistringWithLazFPDocFile(Key, Data: Pointer): integer;
begin
  Result:=CompareFilenames(AnsiString(Key),TLazFPDocFile(Data).Filename);
end;

function CompareLDSrc2DocSrcFilenames(Data1, Data2: Pointer): integer;
begin
  Result:=CompareFilenames(TCHSourceToFPDocFile(Data1).SourceFilename,
                           TCHSourceToFPDocFile(Data2).SourceFilename);
end;

function CompareAnsistringWithLDSrc2DocSrcFile(Key, Data: Pointer): integer;
begin
  Result:=CompareFilenames(AnsiString(Key),TCHSourceToFPDocFile(Data).SourceFilename);
end;

{ TCHSourceToFPDocFile }

function TCHSourceToFPDocFile.IsValid: boolean;
begin
  Result:=(FPDocFilenameTimeStamp=CompilerParseStamp)
      and (FilesTimeStamp=FileStateCache.TimeStamp)
end;

procedure TCHSourceToFPDocFile.MakeValid;
begin
  FPDocFilenameTimeStamp:=CompilerParseStamp;
  FilesTimeStamp:=FileStateCache.TimeStamp;
end;

{ TLazFPDocFile }

function TLazFPDocFile.GetDocModified: boolean;
begin
  Result:=FDocSaveChangeStamp<>FDocChangeStamp;
end;

procedure TLazFPDocFile.SetDocModified(AValue: boolean);
begin
  if AValue then
    CTIncreaseChangeStamp64(FDocChangeStamp)
  else
    FDocSaveChangeStamp:=FDocChangeStamp;
end;

constructor TLazFPDocFile.Create;
begin
  FDocChangeStamp:=CTInvalidChangeStamp64;
  FDocSaveChangeStamp:=CTInvalidChangeStamp64;
end;

destructor TLazFPDocFile.Destroy;
begin
  FreeAndNil(Doc);
  inherited Destroy;
end;

function TLazFPDocFile.GetPackageNode: TDOMNode;
begin
  Result:=nil;
  if Doc=nil then exit;

  // get first node
  Result := Doc.FindNode('fpdoc-descriptions');
  if Result=nil then begin
    //DebugLn(['TLazFPDocFile.GetPackageNode fpdoc-descriptions not found']);
    exit;
  end;

  // proceed to package
  Result := Result.FindNode('package');
end;

function TLazFPDocFile.GetPackageName: string;
var
  Node: TDOMNode;
begin
  Node:=GetPackageNode;
  if Node is TDOMElement then
    Result:=TDomElement(Node).GetAttribute('name')
  else
    Result:='';
end;

function TLazFPDocFile.GetModuleNode: TDOMNode;
begin
  Result:=GetPackageNode;
  if Result=nil then begin
    //DebugLn(['TLazFPDocFile.GetModuleNode fpdoc-descriptions has no package']);
    exit;
  end;

  // proceed to module
  Result := Result.FindNode('module');
end;

function TLazFPDocFile.GetModuleName: string;
var
  Node: TDOMNode;
begin
  Node:=GetModuleNode;
  if Node is TDOMElement then
    Result:=TDomElement(Node).GetAttribute('name')
  else
    Result:='';
end;

function TLazFPDocFile.GetModuleTopicCount: Integer;
var
  Node: TDOMNode;
begin
  Result := 0;
  Node := GetModuleNode;
  if Node = nil then exit;
  Node := Node.FirstChild;
  while (Node <> nil) do begin
    if (Node.NodeName = 'topic') then inc(result);
    Node := Node.NextSibling;
  end;
end;

function TLazFPDocFile.GetModuleTopicName(Index: Integer): String;
var
  Node: TDOMNode;
begin
  Result := '';
  Node := GetModuleNode;
  if Node = nil then exit;
  Node := Node.FirstChild;
  while (Node <> nil) and (Index >= 0) do begin
    if (Node.NodeName = 'topic') and (Node is TDomElement) then begin
      if Index = 0 then begin
        Result := TDomElement(Node).GetAttribute('name');
        exit;
      end;
      dec(Index);
    end;
    Node := Node.NextSibling;
  end;
end;

function TLazFPDocFile.GetModuleTopic(Name: String): TDOMNode;
begin
  Result := GetModuleNode;
  if Result = nil then exit(nil);
  Result := Result.FirstChild;
  while (Result <> nil) do begin
    if (Result.NodeName = 'topic') and (Result is TDomElement) and
        (CompareTextIgnoringSpace(TDomElement(Result).GetAttribute('name'), Name,false) = 0)
    then
      exit;
    Result := Result.NextSibling;
  end;
end;

function TLazFPDocFile.CreateModuleTopic(Name: String): TDOMNode;
var
  ModuleNode: TDOMNode;
begin
  ModuleNode := GetModuleNode;
  if ModuleNode = nil then exit(nil);

  DocChanging;
  try
    Result:=Doc.CreateElement('topic');
    TDOMElement(Result).SetAttribute('name', Name);
    ModuleNode.AppendChild(Result);
  finally
    DocChanged;
  end;
end;

function TLazFPDocFile.GetFirstElement: TDOMNode;
begin
  //get first module node
  Result := GetModuleNode;
  //DebugLn(['TLazFPDocFile.GetFirstElement GetModuleNode=',GetModuleNode<>nil]);
  if Result=nil then exit;

  //proceed to element
  Result := Result.FirstChild;
  while (Result<>nil) and (Result.NodeName <> 'element') do
    Result := Result.NextSibling;
end;

function TLazFPDocFile.GetElementWithName(const ElementName: string;
  CreateIfNotExists: boolean): TDOMNode;
var
  ModuleNode: TDOMNode;
begin
  Result:=nil;
  // get first module node
  ModuleNode:=GetModuleNode;
  if ModuleNode=nil then begin
    if CreateIfNotExists then
      DebugLn(['TLazFPDocFile.GetElementWithName create failed: missing module name. ElementName=',ElementName]);
    exit;
  end;
  // check module name
  if (ModuleNode is TDomElement)
  and (CompareTextIgnoringSpace(TDomElement(ModuleNode).GetAttribute('name'),ElementName,false)=0)
  then begin
    exit(ModuleNode);
  end;
  // check elements
  Result:=GetFirstElement;
  //DebugLn(['TLazFPDocFile.GetElementWithName ',ElementName,' GetFirstElement=',GetFirstElement<>nil]);
  while Result<>nil do begin
    //DebugLn(['TLazFPDocFile.GetElementWithName ',dbgsName(Result)]);
    //if Result is TDomElement then DebugLn(['TLazFPDocFile.GetElementWithName ',TDomElement(Result).GetAttribute('name')]);
    if (Result is TDomElement)
    and (CompareTextIgnoringSpace(TDomElement(Result).GetAttribute('name'),ElementName,false)=0)
    then
      exit;
    Result:=Result.NextSibling;
  end;
  if (Result=nil) and CreateIfNotExists then begin
    DebugLn(['TLazFPDocFile.GetElementWithName creating ',ElementName]);
    DocChanging;
    try
      Result:=Doc.CreateElement('element');
      TDOMElement(Result).SetAttribute('name',ElementName);
      ModuleNode.AppendChild(Result);
    finally
      DocChanged;
    end;
  end;
end;

function TLazFPDocFile.GetChildValuesAsString(Node: TDOMNode): String;

  procedure FindEndOfTag(const Src: string; var EndPos: integer);
  begin
    while (EndPos<=length(Src)) do begin
      if (Src[EndPos]='>') then begin
        inc(EndPos);
        exit;
      end else if Src[EndPos]='"' then begin
        repeat
          inc(EndPos);
        until (EndPos>=length(Src)) or (Src[EndPos]='"');
      end;
      inc(EndPos);
    end;
  end;

var
  MemStream: TMemoryStream;
  StartPos: Integer;
  EndPos: Integer;
begin
  Result:='';
  MemStream:=TMemoryStream.Create;
  try
    // write node with children
    WriteXML(Node,MemStream);
    MemStream.Position:=0;
    SetLength(Result,MemStream.Size);
    if Result<>'' then
      MemStream.Read(Result[1],length(Result));
    // remove enclosing tag(s) for Node, because Result should only
    // contain the child values:
    //   <nodename/> or <nodename>...<nodename/>
    //   <nodename something=""/>
    //   plus line ends
    StartPos:=1;
    EndPos:=length(Result)+1;
    // skip start tag and spaces at start
    while (StartPos<=length(Result))
    and (Result[StartPos] in [' ',#9,#10,#13]) do
      inc(StartPos);
    if (StartPos<=length(Result)) and (Result[StartPos]='<') then begin
      inc(StartPos);
      FindEndOfTag(Result,StartPos);
      while (StartPos<=length(Result))
      and (Result[StartPos] in [' ',#9,#10,#13]) do
        inc(StartPos);
    end;
    // skip ending line ends and spaces at end
    while (EndPos>StartPos) and (Result[EndPos-1] in [' ',#9,#10,#13]) do
      dec(EndPos);
    // skip end tag
    if (EndPos>StartPos) and (Result[EndPos-1]='>') then begin
      repeat
        dec(EndPos);
        if (EndPos=StartPos) then break;
        if (Result[EndPos-1]='"') then begin
          repeat
            dec(EndPos);
          until (EndPos=StartPos) or (Result[EndPos]='"');
        end else if (Result[EndPos-1]='<') then begin
          dec(EndPos);
          break;
        end;
      until false;
      while (EndPos>StartPos) and (Result[EndPos-1] in [' ',#9,#10,#13]) do
        dec(EndPos);
    end;
    Result:=copy(Result,StartPos,EndPos-StartPos);
    
    // the xml writer adds/removes spaces/new lines automatically
    // add newlines after br and p tags
    StartPos:=1;
    while StartPos<length(Result) do begin
      if Result[StartPos]='<' then begin
        // search end of tag
        EndPos:=StartPos+1;
        FindEndOfTag(Result,EndPos);
        if Result[StartPos+1]='/' then
          inc(StartPos);
        if (CompareIdentifiers(@Result[StartPos+1],'br')=0)
            or (CompareIdentifiers(@Result[StartPos+1],'p')=0) then
        begin
          // add new line
          if (EndPos <= Length(Result)) and not (Result[EndPos] in [#10,#13]) then
            Result:=copy(Result,1,EndPos-1)+LineEnding+copy(Result,EndPos,length(Result));
        end;
        StartPos:=EndPos;
      end else begin
        inc(StartPos);
      end;
    end;
  finally
    MemStream.Free;
  end;
  {$ifdef VerboseCodeHelp}
  if Result<>'' then
    DebugLn(['TLazFPDocFile.GetChildValuesAsString Node=',Node.NodeName,' Result=',Result]);
  {$endif}
end;

function TLazFPDocFile.GetValuesFromNode(Node: TDOMNode): TFPDocElementValues;
// simple function to return the values as string
var
  S: String;
  i: TFPDocItem;
begin
  //DebugLn(['TLazFPDocFile.GetValuesFromNode ',Node.NodeName,' ',dbgsName(Node),' ',Node is TDomElement]);
  for i in TFPDocItem do
    Result[i] := '';
  if Node is TDomElement then
    Result[fpdiElementLink] := TDomElement(Node).GetAttribute('link');
  Node := Node.FirstChild;
  while Assigned(Node) do
  begin
    if (Node.NodeType = ELEMENT_NODE) then
    begin
      S := Node.NodeName;
      if S = FPDocItemNames[fpdiShort] then
        Result[fpdiShort] := GetChildValuesAsString(Node);

      if S = FPDocItemNames[fpdiDescription] then
        Result[fpdiDescription] := GetChildValuesAsString(Node);

      if S = FPDocItemNames[fpdiErrors] then
        Result[fpdiErrors] := GetChildValuesAsString(Node);

      if S = FPDocItemNames[fpdiSeeAlso] then
        Result[fpdiSeeAlso] := GetChildValuesAsString(Node);

      if S = FPDocItemNames[fpdiExample] then
        Result[fpdiExample] := Node.Attributes.GetNamedItem('file').NodeValue;
    end;
    Node := Node.NextSibling;
  end;
end;

function TLazFPDocFile.GetValueFromNode(Node: TDOMNode; Item: TFPDocItem): string;
var
  Child: TDOMNode;
begin
  Result:='';
  Child:=Node.FindNode(FPDocItemNames[Item]);
  //DebugLn(['TLazFPDocFile.GetValueFromNode ',FPDocItemNames[Item],' Found=',Child<>nil]);
  if Child<>nil then begin
    if Item=fpdiExample then
      Result := Child.Attributes.GetNamedItem('file').NodeValue
    else
      Result := GetChildValuesAsString(Child);
  end;
end;

procedure TLazFPDocFile.SetChildValue(Node: TDOMNode; const ChildName: string;
  NewValue: string);
  
  procedure ReadXMLFragmentFromString(AParentNode: TDOMNode; const s: string);
  var
    MemStream: TStream;
  begin
    if s='' then exit;
    try
      MemStream:=TMemoryStream.Create;
      MemStream.Write(s[1],length(s));
      MemStream.Position:=0;
      ReadXMLFragment(AParentNode,MemStream);
    finally
      MemStream.Free;
    end;
  end;
  
var
  Child: TDOMNode;
  FileAttribute, LinkAttribute: TDOMAttr;
begin
  NewValue:=ToOSLineEnding(NewValue);
  if ChildName=FPDocItemNames[fpdiElementLink] then begin
    // update attribute
    if Node is TDomElement then begin
      LinkAttribute:=TDomElement(Node).GetAttributeNode('link');
      if ((NewValue='') and (LinkAttribute<>nil))
      or ((NewValue<>'') and ((LinkAttribute=nil) or (LinkAttribute.NodeValue<>NewValue)))
      then begin
        // delete, add or change attribute 'link'
        DebugLn(['TLazFPDocFile.SetChildValue Changing link Name=',ChildName,' NewValue="',NewValue,'"']);
        DocChanging;
        try
          if NewValue='' then begin
            TDomElement(Node).RemoveAttributeNode(LinkAttribute);
            LinkAttribute.Free;
          end else
            TDomElement(Node).SetAttribute('link',NewValue);
        finally
          DocChanged;
        end;
      end;
    end;
  end else begin
    // update sub node
    Child:=Node.FindNode(ChildName);
    if ChildName = FPDocItemNames[fpdiExample] then begin
      // update sub node example, attribute file
      NewValue:=FilenameToURLPath(NewValue);
      FileAttribute:=nil;
      if Child is TDomElement then
        FileAttribute:=TDomElement(Child).GetAttributeNode('file');
      if ((NewValue='') and (FileAttribute<>nil))
      or ((NewValue<>'') and ((FileAttribute=nil) or (FileAttribute.NodeValue<>NewValue)))
      then begin
        // delete, add or change attribute 'file'
        DebugLn(['TLazFPDocFile.SetChildValue Changing example file Name=',ChildName,' NewValue="',NewValue,'"']);
        DocChanging;
        try
          if NewValue='' then begin
            // remove old content
            while Child.LastChild<>nil do
              Child.RemoveChild(Child.LastChild);
            Node.RemoveChild(Child);
          end else begin
            if Child=nil then begin
              Child := Doc.CreateElement(ChildName);
              Node.AppendChild(Child);
            end;
            TDomElement(Child).SetAttribute('file',NewValue);
          end;
        finally
          DocChanged;
        end;
      end;
    end else begin
      if Child=nil then begin
        // add node
        if NewValue<>'' then begin
          DebugLn(['TLazFPDocFile.SetChildValue Adding Name=',ChildName,' NewValue="',NewValue,'"']);
          DocChanging;
          try
            Child := Doc.CreateElement(ChildName);
            Node.AppendChild(Child);
            ReadXMLFragmentFromString(Child,NewValue);
          finally
            DocChanged;
          end;
        end;
      end else if GetChildValuesAsString(Child)<>NewValue then begin
        // change node
        DocChanging;
        try
          DebugLn(['TLazFPDocFile.SetChildValue Changing ',Node.NodeName,
            ' ChildName=',Child.NodeName,
            ' OldValue=',GetChildValuesAsString(Child),
            ' NewValue="',NewValue,'"']);
          // remove old content
          while Child.LastChild<>nil do
            Child.RemoveChild(Child.LastChild);
          if NewValue='' then begin
            // remove entire child
            Node.RemoveChild(Child);
          end else begin
            // set new content
            ReadXMLFragmentFromString(Child,NewValue);
          end;
        finally
          DocChanged;
        end;
      end;
    end;
  end;
end;

procedure TLazFPDocFile.DocChanging;
begin
  if (ldffDocChangingCalled in FFlags) then exit;
  DocModified:=true;
  Include(FFlags,ldffDocChangingCalled);
  CodeHelpBoss.CallDocChangeEvents(chmhDocChanging,Self);
end;

procedure TLazFPDocFile.DocChanged;
begin
  if not (ldffDocChangingCalled in FFlags) then
    raise Exception.Create('TLazFPDocFile.DocChanged missing call to DocChanging');
  if (fUpdateLock>0) then begin
    Include(FFlags,ldffDocChangedNeedsCalling);
    exit;
  end;
  Exclude(FFlags,ldffDocChangedNeedsCalling);
  Exclude(FFlags,ldffDocChangingCalled);
  CodeHelpBoss.CallDocChangeEvents(chmhDocChanged,Self);
end;

procedure TLazFPDocFile.BeginUpdate;
begin
  inc(fUpdateLock);
end;

procedure TLazFPDocFile.EndUpdate;
begin
  dec(fUpdateLock);
  if fUpdateLock<0 then RaiseGDBException('TLazFPDocFile.EndUpdate');
  if fUpdateLock=0 then begin
    if ldffDocChangedNeedsCalling in FFlags then
      DocChanged;
  end;
end;

procedure TCodeHelpManager.AddHandler(HandlerType: TCodeHelpManagerHandler;
  const AMethod: TMethod; AsLast: boolean);
begin
  if FHandlers[HandlerType]=nil then
    FHandlers[HandlerType]:=TMethodList.Create;
  FHandlers[HandlerType].Add(AMethod);
end;

procedure TCodeHelpManager.RemoveHandler(HandlerType: TCodeHelpManagerHandler;
  const AMethod: TMethod);
begin
  FHandlers[HandlerType].Remove(AMethod);
end;

procedure TCodeHelpManager.FreeHandlers;
var
  HandlerType: TCodeHelpManagerHandler;
begin
  for HandlerType:=Low(TCodeHelpManagerHandler) to High(TCodeHelpManagerHandler) do
    FreeThenNil(FHandlers[HandlerType]);
end;

procedure TCodeHelpManager.CallDocChangeEvents(HandlerType: TCodeHelpManagerHandler;
  Doc: TLazFPDocFile);
var
  i: LongInt;
begin
  i:=FHandlers[HandlerType].Count;
  while FHandlers[HandlerType].NextDownIndex(i) do
    TCodeHelpChangeEvent(FHandlers[HandlerType].Items[i])(Self,Doc);
end;

function TCodeHelpManager.DoCreateFPDocFileForSource(const SrcFilename: string;
  out NewOwner: TObject): string;
  
  procedure CleanUpPkgList(var PkgList: TFPList);
  var
    i: Integer;
    AProject: TLazProject;
    BaseDir: String;
    APackage: TLazPackage;
  begin
    if (PkgList=nil) then exit;
    for i:=PkgList.Count-1 downto 0 do begin
      if TObject(PkgList[i]) is TLazProject then begin
        AProject:=TLazProject(PkgList[i]);
        BaseDir:=ExtractFilePath(AProject.ProjectInfoFile);
        if BaseDir<>'' then continue;
      end else if TObject(PkgList[i]) is TLazPackage then begin
        APackage:=TLazPackage(PkgList[i]);
        BaseDir:=APackage.DirectoryExpanded;
        if BaseDir<>'' then continue;
      end;
      // this owner can not be used
      PkgList.Delete(i);
    end;
    if PkgList.Count=0 then
      FreeAndNil(PkgList);
      
    if PkgList.Count>1 then begin
      // there are more than one possible owners
      DebugLn(['TCodeHelpManager.DoCreateFPDocFileForSource.CleanUpPkgList Warning: overlapping projects/packages']);
    end;
  end;
  
  function SelectNewFPDocPaths(const Title, BaseDir: string): string;
  begin
    Result:=LazSelectDirectory('Choose FPDoc directory for '+Title,BaseDir);
    if (Result<>'') then
      Result:=CreateRelativePath(Result,BaseDir);
  end;

  function FindSuitableDirectory(SearchPath, BaseDir: string; Writable: boolean): string;
  var
    p: Integer;
  begin
    //debugln(['FindSuitableDirectory SearchPath="',SearchPath,'"']);
    p:=1;
    repeat
      Result:=GetNextDirectoryInSearchPath(SearchPath,p);
      if Result='' then exit;
      if not FilenameIsAbsolute(Result) then
        Result:=ChompPathDelim(AppendPathDelim(BaseDir)+Result);
      //debugln(['FindSuitableDirectory Dir="',Result,'" exists=',DirPathExistsCached(Result),' writable=',DirectoryIsWritableCached(Result)]);
      if not DirPathExistsCached(Result) then continue;
      if Writable and not DirectoryIsWritableCached(Result) then
        continue;
      exit;
    until false;
  end;
  
var
  OwnerList: TFPList;
  AProject: TLazProject;
  APackage: TLazPackage;
  FPDocPaths: String;
  FPDocPackageName: String;
  NewPath: String;
  BaseDir: String;
  Code: TCodeBuffer;
  CurUnitName: String;
  UnitSet: TFPCUnitSetCache;
  IsInFPCSrc: Boolean;
  AVLNode: TAvlTreeNode;
begin
  Result:='';
  NewOwner:=nil;
  DebugLn(['TCodeHelpManager.DoCreateFPDocFileForSource ',SrcFilename]);
  if not FilenameIsAbsolute(SrcFilename) then begin
    DebugLn(['TCodeHelpManager.DoCreateFPDocFileForSource failed, because file no absolute: ',SrcFilename]);
    exit;
  end;

  OwnerList:=nil;
  try
    IsInFPCSrc:=false;
    // get all packages owning the file
    OwnerList:=PackageEditingInterface.GetOwnersOfUnit(SrcFilename);
    CleanUpPkgList(OwnerList);
    if (OwnerList=nil) then begin
      OwnerList:=PackageEditingInterface.GetPossibleOwnersOfUnit(SrcFilename,
                                               [piosfIncludeSourceDirectories]);
      CleanUpPkgList(OwnerList);
    end;
    if (OwnerList=nil) and IsIDESrcFile(SrcFilename) then begin
      OwnerList:=TFPList.Create;
      OwnerList.Add(LazarusHelp);
    end;
    if OwnerList=nil then begin
      UnitSet:=CodeToolBoss.GetUnitSetForDirectory(ExtractFilePath(SrcFilename));
      if (UnitSet<>nil) and FileIsInPath(SrcFilename,UnitSet.FPCSourceDirectory)
      then begin
        // in FPC sources
        IsInFPCSrc:=true;
        BaseDir:=GetCurrentDirUTF8;
        FPDocPaths:=EnvironmentOptions.GetParsedFPDocPaths;
        FPDocPackageName:='fcl';
        NewPath:=CreateRelativePath(SrcFilename,UnitSet.FPCSourceDirectory);
        if copy(NewPath,1,4)='rtl'+PathDelim then
          FPDocPackageName:='rtl';
      end else begin
        // no package/project found
        IDEMessageDialog(lisProjAddPackageNotFound,
          Format(lisLDTheUnitIsNotOwnedBeAnyPackageOrProjectPleaseAddThe, [
            SrcFilename, #13, #13]), mtError, [mbCancel]);
        exit;
      end;
    end else begin
      NewOwner:=TObject(OwnerList[0]);
      if NewOwner is TLazProject then begin
        AProject:=TLazProject(NewOwner);
        BaseDir:=ExtractFilePath(AProject.ProjectInfoFile);
        if AProject.FPDocPaths='' then
          AProject.FPDocPaths:=SelectNewFPDocPaths(AProject.GetTitleOrName,BaseDir);
        FPDocPaths:=AProject.FPDocPaths;
        FPDocPackageName:=GetFPDocPackageNameByOwner(AProject);
      end else if NewOwner is TLazPackage then begin
        APackage:=TLazPackage(NewOwner);
        BaseDir:=APackage.DirectoryExpanded;
        if APackage.FPDocPaths='' then
          APackage.FPDocPaths:=SelectNewFPDocPaths(APackage.Name,BaseDir);
        FPDocPaths:=APackage.FPDocPaths;
        FPDocPackageName:=GetFPDocPackageNameByOwner(APackage);
      end else if NewOwner=LazarusHelp then begin
        // in IDE
        BaseDir:=EnvironmentOptions.GetParsedLazarusDirectory;
        FPDocPaths:=GetIDESrcFPDocPath;
        FPDocPackageName:=IDEProjectName;
      end else begin
        DebugLn(['TCodeHelpManager.DoCreateFPDocFileForSource unknown owner type ',dbgsName(NewOwner)]);
        NewOwner:=nil;
        exit;
      end;
    end;

    IDEMacros.CreateAbsoluteSearchPath(FPDocPaths,BaseDir);

    // search a writable directory
    NewPath:=FindSuitableDirectory(FPDocPaths,BaseDir,true);
    if NewPath='' then
      NewPath:=FindSuitableDirectory(FPDocPaths,BaseDir,false);
    if NewPath='' then begin
      // no valid directory found
      DebugLn(['TCodeHelpManager.DoCreateFPDocFileForSource FPDocPackageName="',FPDocPackageName,'" FPDocPaths="',FPDocPaths,'" ']);
      if IsInFPCSrc then
        IDEMessageDialog(lisLDNoValidFPDocPath,
          Format(lisTheUnitIsPartOfTheFPCSourcesButTheCorrespondingFpd, [
            SrcFilename, #13, #13, FPCDocsRepositoryURL, #13, #13])
            , mtError, [mbCancel])
      else
        IDEMessageDialog(lisLDNoValidFPDocPath,
          Format(lisLDDoesNotHaveAnyValidFPDocPathUnableToCreateTheFpdo,
                 [FPDocPackageName, LineEnding, SrcFilename]),
          mtError, [mbCancel]);
      exit;
    end;
    // fpdoc directory found
    Result:=AppendPathDelim(NewPath)+lowercase(ExtractFileNameOnly(SrcFilename))+'.xml';
    Code:=CodeToolBoss.LoadFile(SrcFilename,true,false);
    // get unitname
    CurUnitName:=ExtractFileNameOnly(SrcFilename);
    if Code<>nil then
      CurUnitName:=CodeToolBoss.GetSourceName(Code,false);
    // remove cache (source to fpdoc filename)
    AVLNode:=FSrcToDocMap.FindKey(Pointer(SrcFilename),
                                  @CompareAnsistringWithLDSrc2DocSrcFile);
    if AVLNode<>nil then
      FSrcToDocMap.FreeAndDelete(AVLNode);
    // create fpdoc file
    if CreateFPDocFile(Result,FPDocPackageName,CurUnitName)=nil then
      Result:='';
  finally
    OwnerList.Free;
  end;
end;

function TCodeHelpManager.CreateFPDocFile(const ExpandedFilename,
  PackageName, ModuleName: string): TCodeBuffer;
var
  Doc: TXMLDocument;
  DescrNode: TDOMElement;
  ms: TMemoryStream;
  s: string;
  ModuleNode: TDOMElement;
  PackageNode: TDOMElement;
begin
  Result:=nil;
  if FileExistsCached(ExpandedFilename) then begin
    Result:=CodeToolBoss.LoadFile(ExpandedFilename,true,false);
    exit;
  end;
  Result:=CodeToolBoss.CreateFile(ExpandedFilename);
  if Result=nil then begin
    IDEMessageDialog(lisUnableToCreateFile,
      Format(lisUnableToCreateFile2, [ExpandedFilename]), mtError, [mbCancel]);
    exit;
  end;
  
  Doc:=nil;
  ms:=nil;
  try
    Doc:=TXMLDocument.Create;
    // <fpdoc-descriptions>
    DescrNode:=Doc.CreateElement('fpdoc-descriptions');
    Doc.AppendChild(DescrNode);
    //   <package name="packagename">
    PackageNode:=Doc.CreateElement('package');
    PackageNode.SetAttribute('name',PackageName);
    DescrNode.AppendChild(PackageNode);
    //   <module name="unitname">
    ModuleNode:=Doc.CreateElement('module');
    ModuleNode.SetAttribute('name',ModuleName);
    PackageNode.AppendChild(ModuleNode);
    // write the XML to a string
    ms:=TMemoryStream.Create;
    WriteXMLFile(Doc,ms,[xwfPreserveWhiteSpace]);
    ms.Position:=0;
    SetLength(s,ms.Size);
    if s<>'' then
      ms.Read(s[1],length(s));
    // copy to codebuffer
    //DebugLn(['TCodeHelpManager.CreateFPDocFile ',s]);
    Result.Source:=s;
    // save file
    if SaveCodeBuffer(Result)<>mrOk then
      Result:=nil;
  finally
    ms.Free;
    Doc.Free;
  end;
end;

constructor TCodeHelpManager.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FDocs:=TAvlTree.Create(@CompareLazFPDocFilenames);
  FSrcToDocMap:=TAvlTree.Create(@CompareLDSrc2DocSrcFilenames);
  FDeclarationCache:=TDeclarationInheritanceCache.Create(
                                  @CodeToolBoss.FindDeclarationAndOverload,
                                  @CodeToolBoss.GetCodeTreeNodesDeletedStep);
  FPasHighlighter:=TSynPasSyn.Create(Self);
end;

destructor TCodeHelpManager.Destroy;
begin
  ClearSrcToDocMap;
  FreeDocs;
  FreeAndNil(FDocs);
  FreeAndNil(FSrcToDocMap);
  FreeAndNil(FDeclarationCache);
  FreeHandlers;
  inherited Destroy;
end;

function TCodeHelpManager.FindFPDocFile(const Filename: string): TLazFPDocFile;
var
  Node: TAvlTreeNode;
begin
  Node:=FDocs.FindKey(Pointer(Filename),@CompareAnsistringWithLazFPDocFile);
  if Node<>nil then
    Result:=TLazFPDocFile(Node.Data)
  else
    Result:=nil;
end;

function TCodeHelpManager.LoadFPDocFile(const Filename: string;
  Flags: TCodeHelpOpenFileFlags;
  out ADocFile: TLazFPDocFile; out CacheWasUsed: boolean
  ): TCodeHelpParseResult;
var
  MemStream: TMemoryStream;
  CurFilename: String;
begin
  Result:=chprFailed;
  CacheWasUsed:=true;
  ADocFile:=FindFPDocFile(Filename);
  if ADocFile=nil then begin
    CacheWasUsed:=false;
    ADocFile:=TLazFPDocFile.Create;
    ADocFile.Filename:=Filename;
    FDocs.Add(ADocFile);
  end;
  ADocFile.CodeBuffer:=CodeToolBoss.LoadFile(Filename,
                               chofUpdateFromDisk in Flags,chofRevert in Flags);
  if ADocFile.CodeBuffer=nil then begin
    DebugLn(['TCodeHelpManager.LoadFPDocFile unable to load "',Filename,'"']);
    FreeAndNil(ADocFile.Doc);
    exit;
  end;
  if (ADocFile.CodeBufferChangeStep=ADocFile.CodeBuffer.ChangeStep) then begin
    // CodeBuffer has not changed
    if ADocFile.DocErrorMsg<>'' then begin
      if not (chofQuiet in Flags) then begin
        // for example: Filename(y,x) Error: description
        IDEMessagesWindow.AddCustomMessage(mluError,ADocFile.DocErrorMsg,
          ADocFile.CodeBuffer.Filename,0,0,'FPDoc');
      end;
      // no update needed
      exit(chprFailed);
    end;
    if ADocFile.DocModified and (chofRevert in Flags) then begin
      // revert the modifications => rebuild the Doc from the CodeBuffer
    end else begin
      // no update needed
      exit(chprSuccess);
    end;
  end;
  CacheWasUsed:=false;
  
  {$IFDEF VerboseCodeHelp}
  DebugLn(['TCodeHelpManager.LoadFPDocFile parsing ',ADocFile.Filename]);
  {$ENDIF}
  CallDocChangeEvents(chmhDocChanging,ADocFile);

  // parse XML
  ADocFile.CodeBufferChangeStep:=ADocFile.CodeBuffer.ChangeStep;
  ADocFile.DocModified:=false;
  ADocFile.DocErrorMsg:='Unknown error';
  FreeAndNil(ADocFile.Doc);
  CurFilename:=ADocFile.CodeBuffer.Filename;

  MemStream:=TMemoryStream.Create;
  try
    ADocFile.CodeBuffer.SaveToStream(MemStream);
    MemStream.Position:=0;
    Result:=chprFailed;
    try
      ReadXMLFile(ADocFile.Doc,MemStream,CurFilename,[xrfPreserveWhiteSpace]);
      ADocFile.DocErrorMsg:='';
      Result:=chprSuccess;
    except
      on E: EXMLReadError do begin
        ADocFile.DocErrorMsg:=E.Message;
        DebugLn(['TCodeHelpManager.LoadFPDocFile ',E.Message]);
        if not (chofQuiet in Flags) then begin
          // for example: Filename(y,x) Error: description
          IDEMessagesWindow.AddCustomMessage(mluError,ADocFile.DocErrorMsg,
            CurFilename,0,0,'FPDoc');
        end;
      end;
      on E: Exception do begin
        ADocFile.DocErrorMsg:='Error reading xml file "'+CurFilename+'" '+E.Message;
        DebugLn(['TCodeHelpManager.LoadFPDocFile '+ADocFile.DocErrorMsg]);
        if not (chofQuiet in Flags) then begin
          IDEMessageDialog(lisErrorReadingXML,
            Format(lisErrorReadingXmlFile, [CurFilename, LineEnding, E.Message]),
            mtError, [mbCancel]);
        end;
      end;
    end;
  finally
    if Result<>chprSuccess then
      FreeAndNil(ADocFile.Doc);
    MemStream.Free;
    CallDocChangeEvents(chmhDocChanging,ADocFile);
  end;
end;

function TCodeHelpManager.SaveFPDocFile(ADocFile: TLazFPDocFile): TModalResult;
var
  ms: TMemoryStream;
  s: string;
begin
  if (not ADocFile.DocModified)
  and (ADocFile.CodeBufferChangeStep=ADocFile.CodeBuffer.ChangeStep)
  and (not ADocFile.CodeBuffer.FileOnDiskNeedsUpdate) then begin
    DebugLn(['TCodeHelpManager.SaveFPDocFile no save needed: ',ADocFile.Filename]);
    exit(mrOk);
  end;
  if (ADocFile.Doc=nil) then begin
    DebugLn(['TCodeHelpManager.SaveFPDocFile no Doc: ',ADocFile.Filename]);
    exit(mrOk);
  end;
  if not FilenameIsAbsolute(ADocFile.Filename) then begin
    DebugLn(['TCodeHelpManager.SaveFPDocFile no expanded filename: ',ADocFile.Filename]);
    exit(mrCancel);
  end;

  // write Doc to xml stream
  try
    ms:=TMemoryStream.Create;
    WriteXMLFile(ADocFile.Doc,ms,[xwfPreserveWhiteSpace]);
    ms.Position:=0;
    SetLength(s,ms.Size);
    if s<>'' then
      ms.Read(s[1],length(s));
  finally
    ms.Free;
  end;

  // write to CodeBuffer
  ADocFile.CodeBuffer.Source:=s;
  ADocFile.DocModified:=false;
  if ADocFile.CodeBuffer.ChangeStep=ADocFile.CodeBufferChangeStep then begin
    // doc was not really modified => do not save to keep file date
    DebugLn(['TCodeHelpManager.SaveFPDocFile Doc was not really modified ',ADocFile.Filename]);
    exit(mrOk);
  end;
  ADocFile.CodeBufferChangeStep:=ADocFile.CodeBuffer.ChangeStep;
  
  // write to disk
  Result:=SaveCodeBuffer(ADocFile.CodeBuffer);
  DebugLn(['TCodeHelpManager.SaveFPDocFile saved ',ADocFile.Filename]);
end;

function TCodeHelpManager.GetFPDocFilenameForHelpContext(
  Context: TPascalHelpContextList; out CacheWasUsed: boolean): string;
var
  i: Integer;
  SrcFilename: String;
  AnOwner: TObject;
begin
  Result:='';
  CacheWasUsed:=true;
  if Context=nil then exit;
  for i:=0 to Context.Count-1 do begin
    if Context.Items[i].Descriptor<>pihcFilename then continue;
    SrcFilename:=Context.Items[i].Context;
    Result:=GetFPDocFilenameForSource(SrcFilename,true,CacheWasUsed,AnOwner);
    exit;
  end;
end;

function TCodeHelpManager.GetFPDocFilenameForSource(SrcFilename: string;
  ResolveIncludeFiles: Boolean; out CacheWasUsed: boolean;
  out AnOwner: TObject; CreateIfNotExists: boolean): string;
{off $Define VerboseGetFPDocForSrc}
var
  FPDocName: String;
  SearchedPaths: string;

  function SearchInPath(Paths: string; const BaseDir: string;
    out Filename: string): boolean;
  var
    CurPath: String;
    p: Integer;
  begin
    Result:=false;
    if Paths='' then exit;
    {$IFDEF VerboseGetFPDocForSrc}
    debugln(['GetFPDocFilenameForSource.SearchInPath unresolved Paths="',Paths,'" BaseDir="',BaseDir,'"']);
    {$ENDIF}
    if not IDEMacros.CreateAbsoluteSearchPath(Paths,BaseDir) then begin
      {$IFDEF VerboseGetFPDocForSrc}
      debugln(['GetFPDocFilenameForSource.SearchInPath invalid macro Paths="',Paths,'"']);
      {$ENDIF}
      exit;
    end;
    {$IFDEF VerboseGetFPDocForSrc}
    debugln(['GetFPDocFilenameForSource.SearchInPath resolved Paths="',Paths,'"']);
    {$ENDIF}
    if Paths='' then exit;
    p:=1;
    repeat
      CurPath:=GetNextDirectoryInSearchPath(Paths,p);
      if CurPath<>'' then begin
        CurPath:=CleanAndExpandDirectory(CurPath);
        if SearchDirectoryInSearchPath(SearchedPaths,CurPath)<1 then begin
          // not yet searched in this directory
          SearchedPaths:=SearchedPaths+';'+CurPath;
          Filename:=AppendPathDelim(CurPath)+FPDocName;
          {$IFDEF VerboseGetFPDocForSrc}
          debugln(['GetFPDocFilenameForSource.SearchInPath try file="',Filename,'"']);
          {$ENDIF}
          if FileExistsCached(Filename) then exit(true);
        end;
      end;
    until p>length(Paths);
    Filename:='';
  end;
  
  function CheckUnitOwners(CheckSourceDirectories: boolean;
    out Filename: string): boolean;
  var
    PkgList: TFPList;
    i: Integer;
    APackage: TLazPackage;
    BaseDir: String;
    AProject: TLazProject;
  begin
    Result:=false;
    Filename:='';
    if not FilenameIsAbsolute(SrcFilename) then exit;
    
    if CheckSourceDirectories then begin
      PkgList:=PackageEditingInterface.GetPossibleOwnersOfUnit(SrcFilename,[]);
    end else begin
      PkgList:=PackageEditingInterface.GetOwnersOfUnit(SrcFilename);
    end;
    // get all packages owning the file
    if PkgList=nil then begin
      {$IFDEF VerboseGetFPDocForSrc}
      debugln(['GetFPDocFilenameForSource.CheckUnitOwners no owner for SrcFile="',SrcFilename,'"']);
      {$ENDIF}
      exit;
    end;
    try
      for i:=0 to PkgList.Count-1 do begin
        {$IFDEF VerboseGetFPDocForSrc}
        debugln(['GetFPDocFilenameForSource.CheckUnitOwners owner="',DbgSName(TObject(PkgList[i])),'"']);
        {$ENDIF}
        if TObject(PkgList[i]) is TLazProject then begin
          AProject:=TLazProject(PkgList[i]);
          AnOwner:=AProject;
          if AProject.FPDocPaths='' then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners project has no FPDocPaths "',AProject.ProjectInfoFile,'"']);
            {$ENDIF}
            continue;
          end;
          BaseDir:=ExtractFilePath(AProject.ProjectInfoFile);
          if BaseDir='' then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners project is virtual "',AProject.ProjectInfoFile,'"']);
            {$ENDIF}
            continue;
          end;
          // add fpdoc paths of project
          if SearchInPath(AProject.FPDocPaths,BaseDir,Filename) then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners found in project "',AProject.ProjectInfoFile,'" File="',Filename,'"']);
            {$ENDIF}
            exit(true);
          end;
        end else if TObject(PkgList[i]) is TLazPackage then begin
          APackage:=TLazPackage(PkgList[i]);
          AnOwner:=APackage;
          if APackage.FPDocPaths='' then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners package has no FPDocPaths ',APackage.Name,'  "',APackage.Filename,'"']);
            {$ENDIF}
            continue;
          end;
          BaseDir:=APackage.Directory;
          if BaseDir='' then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners package is virtual "',APackage.Name,'"']);
            {$ENDIF}
            continue;
          end;
          // add fpdoc paths of package
          if SearchInPath(APackage.FPDocPaths,BaseDir,Filename) then begin
            {$IFDEF VerboseGetFPDocForSrc}
            debugln(['GetFPDocFilenameForSource.CheckUnitOwners found in package "',APackage.Filename,'" File="',Filename,'"']);
            {$ENDIF}
            exit(true);
          end;
        end;
      end;
    finally
      PkgList.Free;
    end;
  end;
  
  function CheckIfInLazarus(out Filename: string): boolean;
  begin
    Result:=false;
    Filename:='';
    if not FilenameIsAbsolute(SrcFilename) then exit;
    // check IDE directories
    if IsIDESrcFile(SrcFilename) then begin
      AnOwner:=LazarusHelp;
      {$IFDEF VerboseGetFPDocForSrc}
      debugln(['GetFPDocFilenameForSource.CheckIfInLazarus IsIDESrcFile "',SrcFilename,'"']);
      {$ENDIF}
      if SearchInPath(GetIDESrcFPDocPath,'',Filename) then begin
        {$IFDEF VerboseGetFPDocForSrc}
        debugln(['GetFPDocFilenameForSource.CheckIfInLazarus found in IDE "',Filename,'"']);
        {$ENDIF}
        exit(true);
      end;
    end;

    // finally: check if in user directories
    if SearchInPath(EnvironmentOptions.FPDocPaths,'',Filename) then
    begin
      {$IFDEF VerboseGetFPDocForSrc}
      debugln(['GetFPDocFilenameForSource.CheckIfInLazarus found in user files "',Filename,'"']);
      {$ENDIF}
      AnOwner:=nil;
      exit(true);
    end;
  end;

var
  CodeBuf: TCodeBuffer;
  AVLNode: TAvlTreeNode;
  MapEntry: TCHSourceToFPDocFile;
begin
  Result:='';
  CacheWasUsed:=true;
  AnOwner:=nil;

  if ResolveIncludeFiles then begin
    CodeBuf:=CodeToolBoss.FindFile(SrcFilename);
    if CodeBuf<>nil then begin
      CodeBuf:=CodeToolBoss.GetMainCode(CodeBuf);
      if CodeBuf<>nil then begin
        SrcFilename:=CodeBuf.Filename;
      end;
    end;
  end;
  
  if not FilenameIsPascalSource(SrcFilename) then
  begin
    {$IFDEF VerboseGetFPDocForSrc}
    DebugLn(['TCodeHelpManager.GetFPDocFilenameForSource error: not a source file: "',SrcFilename,'"']);
    {$ENDIF}
    exit;
  end;
  
  try
    // first try cache
    MapEntry:=nil;
    AVLNode:=FSrcToDocMap.FindKey(Pointer(SrcFilename),
                                  @CompareAnsistringWithLDSrc2DocSrcFile);
    if AVLNode<>nil then begin
      MapEntry:=TCHSourceToFPDocFile(AVLNode.Data);
      if MapEntry.IsValid then begin
        AnOwner:=MapEntry.FPDocFileOwner;
        Result:=MapEntry.FPDocFilename;
        exit;
      end;
    end;
    CacheWasUsed:=false;

    {$IF defined(VerboseCodeHelp) or defined(VerboseGetFPDocForSrc)}
    DebugLn(['TCodeHelpManager.GetFPDocFilenameForSource searching SrcFilename=',SrcFilename]);
    {$ENDIF}

    // first check if the file is owned by any project/package
    SearchedPaths:='';
    FPDocName:=lowercase(ExtractFileNameOnly(SrcFilename))+'.xml';
    if (not CheckUnitOwners(false,Result)) // first check if file is owned by a package/project
    and (not CheckUnitOwners(true,Result))// then check if the file is in a source directory of a package/project
    and (not CheckIfInLazarus(Result))
    then begin
      // not found
      if AnOwner=nil then
        DebugLn(['TCodeHelpManager.GetFPDocFilenameForSource Hint: file without owner: ',SrcFilename])
      else if AnOwner is TLazProject then begin
        if TLazProject(AnOwner).FPDocPaths='' then
          debugln(['TCodeHelpManager.GetFPDocFilenameForSource Hint: Owner (project) has no fpdoc paths: ',SrcFilename])
        else
          debugln(['TCodeHelpManager.GetFPDocFilenameForSource Hint: Owner (project) has no fpdoc file for: ',SrcFilename])
      end else if AnOwner is TLazPackage then begin
        if TLazPackage(AnOwner).FPDocPaths='' then
          debugln(['TCodeHelpManager.GetFPDocFilenameForSource Hint: Owner (package ',TLazPackage(AnOwner).Name,') has no fpdoc paths: ',SrcFilename])
        else
          debugln(['TCodeHelpManager.GetFPDocFilenameForSource Hint: Owner (package ',TLazPackage(AnOwner).Name,') has no fpdoc file for: ',SrcFilename])
      end;
    end;

    // save to cache
    if MapEntry=nil then begin
      MapEntry:=TCHSourceToFPDocFile.Create;
      MapEntry.SourceFilename:=SrcFilename;
      FSrcToDocMap.Add(MapEntry);
    end;
    MapEntry.FPDocFilename:=Result;
    MapEntry.FPDocFileOwner:=AnOwner;
    MapEntry.MakeValid;
  finally
    if (Result='') and CreateIfNotExists then begin
      Result:=DoCreateFPDocFileForSource(SrcFilename,AnOwner);
    end;
    {$IF defined(VerboseCodeHelp) or defined(VerboseGetFPDocForSrc)}
    DebugLn(['TCodeHelpManager.GetFPDocFilenameForSource SrcFilename="',SrcFilename,'" Result="',Result,'"']);
    {$ENDIF}
  end;
  {$IF defined(VerboseCodeHelp) or defined(VerboseGetFPDocForSrc)}
  DebugLn(['TCodeHelpManager.GetFPDocFilenameForSource ',dbgsName(AnOwner)]);
  {$endif}
end;

procedure TCodeHelpManager.GetFPDocFilenamesForSources(
  SrcFilenames: TFilenameToStringTree; ResolveIncludeFiles: boolean;
  var FPDocFilenames: TFilenameToStringTree);
var
  SrcFilename: String;
  CacheWasUsed: boolean;
  AnOwner: TObject;
  FPDocFilename: String;
  S2SItem: PStringToStringItem;
begin
  for S2SItem in SrcFilenames do begin
    SrcFilename:=S2SItem^.Name;
    FPDocFilename:=GetFPDocFilenameForSource(SrcFilename,ResolveIncludeFiles,
                                             CacheWasUsed,AnOwner);
    //DebugLn(['TCodeHelpManager.GetFPDocFilenamesForSources FPDoc=',FPDocFilename,' Src=',SrcFilename]);
    if FPDocFilename<>'' then begin
      if FPDocFilenames=nil then
        FPDocFilenames:=TFilenameToStringTree.Create(false);
      FPDocFilenames[FPDocFilename]:=GetModuleOwnerName(AnOwner);
    end;
  end;
end;

function TCodeHelpManager.GetIDESrcFPDocPath: string;
var
  LazDir: String;
begin
  Result:='';
  LazDir:=AppendPathDelim(EnvironmentOptions.GetParsedLazarusDirectory);
  if (LazDir='') or not FilenameIsAbsolute(LazDir) then exit;
  Result:=LazDir+GetForcedPathDelims('docs/xml/ide/');
end;

function TCodeHelpManager.IsIDESrcFile(const SrcFilename: string): boolean;
var
  LazDir: String;
begin
  Result:=false;
  LazDir:=AppendPathDelim(EnvironmentOptions.GetParsedLazarusDirectory);
  if (LazDir='') or not FilenameIsAbsolute(LazDir) then exit;
  if not FileIsInPath(SrcFilename,LazDir) then exit;
  // check if SrcFilename is in one of the IDE directories or sub directories
  if FileIsInPath(SrcFilename,LazDir+'ide')
  or FileIsInPath(SrcFilename,LazDir+'debugger')
  or FileIsInPath(SrcFilename,LazDir+'packager')
  or FileIsInPath(SrcFilename,LazDir+'converter')
  or FileIsInPath(SrcFilename,LazDir+'designer')
  then
    Result:=true;
end;

function TCodeHelpManager.FindFPDocPackageOwner(const PackageName: string
  ): TObject;
var
  AProject: TLazProject;
  i: Integer;
  Pkg: TLazPackage;
begin
  // check project
  AProject:=LazarusIDE.ActiveProject;
  if (AProject<>nil)
  and (SysUtils.CompareText(GetFPDocPackageNameByOwner(AProject),PackageName)=0)
  then begin
    Result:=AProject;
    exit;
  end;
  // check package
  for i:=0 to PackageGraph.Count-1 do begin
    Pkg:=PackageGraph[i];
    if SysUtils.CompareText(Pkg.GetFPDocPackageName,PackageName)=0 then
      exit(Pkg);
  end;
  // check IDE as project
  if SysUtils.CompareText(IDEProjectName,PackageName)=0 then begin
    Result:=LazarusHelp;
    exit;
  end;
  Result:=nil;
end;

function TCodeHelpManager.FindModuleOwner(FPDocFile: TLazFPDocFile): TObject;
var
  AProject: TLazProject;
  Path: String;
  p: PChar;
  PkgName: String;

  function InPackage(Pkg: TLazPackage): boolean;
  var
    SearchPath: String;
  begin
    Result:=false;
    if (Pkg=nil) or (Pkg.FPDocPaths='') then exit;
    // check if the file is in the search path
    Path:=ExtractFilePath(FPDocFile.Filename);
    SearchPath:=Pkg.FPDocPaths;
    if not IDEMacros.CreateAbsoluteSearchPath(SearchPath,Pkg.Directory)
    then
      exit;
    SearchPath:=MinimizeSearchPath(SearchPath);
    //DebugLn(['InPackage Path="',Path,'" SearchPath="',SearchPath,'"']);
    p:=FindPathInSearchPath(PChar(Path),length(Path),
                            PChar(SearchPath),length(SearchPath));
    if p<>nil then begin
      FindModuleOwner:=Pkg;
      Result:=true;
    end;
  end;

var
  Pkg: TLazPackage;
  SearchPath: String;
  i: Integer;
begin
  Result:=nil;
  if FPDocFile=nil then exit;
  AProject:=LazarusIDE.ActiveProject;

  // virtual files belong to the project
  if not FilenameIsAbsolute(FPDocFile.Filename) then
    exit(AProject);

  // check if in the doc path of the project
  if (AProject<>nil) and (AProject.FPDocPaths<>'')
  and FilenameIsAbsolute(AProject.ProjectInfoFile) then begin
    Path:=ExtractFilePath(FPDocFile.Filename);
    SearchPath:=AProject.FPDocPaths;
    IDEMacros.CreateAbsoluteSearchPath(SearchPath,
                                     ExtractFilePath(AProject.ProjectInfoFile));
    SearchPath:=TrimSearchPath(SearchPath,'');
    p:=FindPathInSearchPath(PChar(Path),length(Path),
                            PChar(SearchPath),length(SearchPath));
    if p<>nil then begin
      Result:=AProject;
      exit;
    end;
  end;

  // check the packagename in the fpdoc file
  PkgName:=FPDocFile.GetPackageName;
  if PkgName<>'' then begin
    Pkg:=PackageGraph.FindPackageWithName(PkgName,nil);
    if InPackage(Pkg) then exit;
  end;

  // search in all packages
  for i:=0 to PackageGraph.Count-1 do
    if InPackage(PackageGraph.Packages[i]) then exit;

  // check the IDE
  SearchPath:=GetIDESrcFPDocPath;
  if (SearchPath<>'') and FileIsInPath(FPDocFile.Filename,SearchPath) then
  begin
    Result:=LazarusHelp;
    exit;
  end;
end;

function TCodeHelpManager.GetModuleOwnerName(TheOwner: TObject): string;
begin
  if TheOwner is TLazPackage then
    Result:=TLazPackage(TheOwner).Name
  else if TheOwner is TLazProject then
    Result:=ExtractFileNameOnly(TLazProject(TheOwner).ProjectInfoFile)
  else if TheOwner=LazarusHelp then
    Result:=IDEProjectName
  else
    Result:='';
end;

function TCodeHelpManager.GetFPDocPackageNameByOwner(TheOwner: TObject
  ): string;
begin
  if TheOwner is TLazPackage then
    Result:=TLazPackage(TheOwner).GetFPDocPackageName
  else if TheOwner is TLazProject then
    Result:=TLazProject(TheOwner).GetFPDocPackageName
  else if TheOwner=LazarusHelp then
    Result:=IDEProjectName
  else
    Result:='';
end;

function TCodeHelpManager.ExpandFPDocLinkID(const LinkID, DefaultUnitName,
  DefaultOwnerName: string): string;
begin
  Result:=LinkID;
  if (LinkID='') or (LinkID[1]='#') then exit;
  Result:=ExpandFPDocLinkID(LinkId,DefaultUnitName,
                            FindFPDocPackageOwner(DefaultOwnerName));
end;

function TCodeHelpManager.ExpandFPDocLinkID(const LinkID,
  DefaultUnitName: string; TheOwner: TObject): string;
  
  function SearchFPDocFile(SearchPath: string;
    const BaseDir, AUnitname: string): string;
  var
    FPDocFilename: String;
  begin
    Result:='';
    if BaseDir='' then exit;
    if not IDEMacros.CreateAbsoluteSearchPath(SearchPath,BaseDir) then exit;
    FPDocFilename:=lowercase(AUnitName)+'.xml';
    Result:=SearchFileInPath(FPDocFilename,'',SearchPath,';',ctsfcDefault);
  end;
  
var
  FirstPointPos: LongInt;
  APackage: TLazPackage;
  FirstIdentifier: String;
  AddUnit: Boolean;
  AProject: TLazProject;
begin
  Result:=LinkID;
  if (LinkID='') or (LinkID[1]='#') then exit;
  FirstPointPos:=System.Pos(LinkID,'.');
  FirstIdentifier:=copy(LinkID,1,FirstPointPos);
  if (FirstIdentifier<>'')
  and (SysUtils.CompareText(FirstIdentifier,DefaultUnitName)<>0) then
  begin
    // the LinkID has sub identifiers, so the first identifier could be a unit
    // But it is not the DefaultUnitName
    // => check if it is another unitname of the Owner
    AddUnit:=false;
    if TheOwner is TLazPackage then begin
      APackage:=TLazPackage(TheOwner);
      if (APackage.FindUnit(FirstIdentifier)=nil) then begin
        // the unit is not owned.
        if SearchFPDocFile(APackage.FPDocPaths,APackage.DirectoryExpanded,
          FirstIdentifier)='' then
        begin
          // and there is no fpdoc file for this identifier
          // => not a unit
          AddUnit:=true;
        end;
      end;
    end else if TheOwner is TLazProject then begin
      AProject:=TLazProject(TheOwner);
      if SearchFPDocFile(AProject.FPDocPaths,
        ExtractFilePath(AProject.ProjectInfoFile),FirstIdentifier)='' then
      begin
        // there is no fpdoc file for this identifier
        // => not a unit
        AddUnit:=true;
      end;
    end else begin
      // unknown owner type
      exit;
    end;
    if AddUnit then
      Result:=DefaultUnitName+'.'+Result;
  end;
  Result:='#'+GetFPDocPackageNameByOwner(TheOwner)+'.'+Result;
end;

function TCodeHelpManager.CodeNodeToElementName(Tool: TFindDeclarationTool;
  CodeNode: TCodeTreeNode): string;
var
  NodeName: String;
begin
  Result:='';
  if CodeNode.Desc in AllSourceTypes then begin
    Result:=Tool.ExtractSourceName;
  end else begin
    while CodeNode<>nil do begin
      NodeName:='';
      case CodeNode.Desc of
      ctnVarDefinition:
        if Tool.NodeIsResultIdentifier(CodeNode) then
          // fpdoc prefixes the result variable with 'Identifier ' (don't ask)
          NodeName:='Identifier '+Tool.ExtractDefinitionName(CodeNode)
        else
          NodeName:=Tool.ExtractDefinitionName(CodeNode);
      ctnConstDefinition, ctnTypeDefinition, ctnGenericType:
        NodeName:=Tool.ExtractDefinitionName(CodeNode);
      ctnProperty:
        NodeName:=Tool.ExtractPropName(CodeNode,false);
      ctnProcedure:
        if Tool.NodeIsOperator(CodeNode) then
          NodeName:=Tool.ExtractProcHead(CodeNode,
                           [phpWithStart,phpWithResultType,phpWithoutSemicolon])
        else
          NodeName:=Tool.ExtractProcName(CodeNode,[]);
      ctnEnumIdentifier:
        NodeName:=GetIdentifier(@Tool.Src[CodeNode.StartPos]);
      ctnIdentifier:
        if Tool.NodeIsResultType(CodeNode) then
          NodeName:='Result';
      end;
      if NodeName<>'' then begin
        if Result<>'' then
          Result:='.'+Result;
        Result:=NodeName+Result;
      end;
      CodeNode:=CodeNode.Parent;
    end;
  end;
end;

function TCodeHelpManager.GetFPDocNode(Tool: TCodeTool; CodeNode: TCodeTreeNode;
  Complete: boolean; out FPDocFile: TLazFPDocFile; out DOMNode: TDOMNode;
  out CacheWasUsed: boolean): TCodeHelpParseResult;
var
  SrcFilename: String;
  FPDocFilename: String;
  ElementName: String;
  AnOwner: TObject;
begin
  FPDocFile:=nil;
  DOMNode:=nil;
  CacheWasUsed:=true;
  
  // find corresponding FPDoc file
  SrcFilename:=Tool.MainFilename;
  FPDocFilename:=GetFPDocFilenameForSource(SrcFilename,false,CacheWasUsed,AnOwner);
  if FPDocFilename='' then exit(chprFailed);
  if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

  // load FPDoc file
  Result:=LoadFPDocFile(FPDocFilename,[chofUpdateFromDisk],FPDocFile,CacheWasUsed);
  if Result<>chprSuccess then exit;
  if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

  // find FPDoc node
  ElementName:=CodeNodeToElementName(Tool,CodeNode);
  if ElementName='' then exit(chprFailed);
  DOMNode:=FPDocFile.GetElementWithName(ElementName);
  if DOMNode=nil then exit(chprFailed);
  
  Result:=chprSuccess;
end;

function TCodeHelpManager.GetLinkedFPDocNode(StartFPDocFile: TLazFPDocFile;
  StartDOMNode: TDOMNode; const Path: string; Flags: TCodeHelpOpenFileFlags;
  out ModuleOwner: TObject; out FPDocFile: TLazFPDocFile; out DOMNode: TDOMNode;
  out InvalidPath: integer; out CacheWasUsed: boolean): TCodeHelpParseResult;

  function FindFPDocFilename(BaseDir, SearchPath, AUnitName: string): string;
  begin
    Result:='';
    if not IDEMacros.CreateAbsoluteSearchPath(SearchPath,BaseDir) then exit;
    //DebugLn(['FindFPDocFilename BaseDir=',BaseDir,' SearchPath=',SearchPath,' UnitName=',AUnitname]);
    Result:=SearchFileInPath(AUnitName+'.xml',BaseDir,SearchPath,';',ctsfcDefault);
  end;

  function FindElement(StartPos: integer; aFPDocFile: TLazFPDocFile): boolean;
  var
    ElementName: String;
    p: integer;
  begin
    p:=length(Path)+1;
    while p>StartPos do begin
      ElementName:=copy(Path,StartPos,p-StartPos);
      //DebugLn(['TCodeHelpManager.GetLinkedFPDocNode ElementName=',ElementName]);
      DOMNode:=aFPDocFile.GetElementWithName(ElementName);
      if DOMNode<>nil then begin
        InvalidPath:=p;
        if p>length(Path) then
          GetLinkedFPDocNode:=chprSuccess
        else
          GetLinkedFPDocNode:=chprFailed;
        FPDocFile:=aFPDocFile;
        exit(true);
      end;
      dec(p);
      while (p>StartPos) and (Path[p]<>'.') do dec(p);
    end;
    Result:=false;
  end;

var
  StartPos, p: LongInt;
  PkgName: String;
  Pkg: TLazPackage;
  AUnitName: String;
  AProject: TLazProject;
  FPDocFilename: String;
  BaseDir: String;
begin
  ModuleOwner:=nil;
  FPDocFile:=nil;
  DOMNode:=nil;
  InvalidPath:=0;
  CacheWasUsed:=false;
  Result:=chprFailed;

  //DebugLn(['TCodeHelpManager.GetLinkedFPDocNode Path="',Path,'"']);
  if Path='' then exit;
  if StartDOMNode=nil then ; // for future use

  StartPos:=1;
  p:=1;
  if Path[1]='#' then begin
    // switch package
    while (p<=length(Path)) and (Path[p]<>'.') do inc(p);
    PkgName:=copy(Path,2,p-2);
    //DebugLn(['TCodeHelpManager.GetLinkedFPDocNode PkgName=',PkgName]);
    if PkgName='' then exit;
    Pkg:=PackageGraph.FindPackageWithName(PkgName,nil);
    if Pkg=nil then exit;
    InvalidPath:=p;
    ModuleOwner:=Pkg;
    if p>length(Path) then begin
      // link to the module, no unit
      Result:=chprSuccess;
      exit;
    end;
    StartPos:=p+1;
    p:=StartPos;
  end else begin
    // relative link (either in the same fpdoc file or of the same module)
    // use same package
    ModuleOwner:=FindModuleOwner(StartFPDocFile);
    if ModuleOwner=nil then exit;
    // try in the same fpdoc file
    if FindElement(StartPos,StartFPDocFile) then exit;
  end;

  // search in another unit
  while (p<=length(Path)) and (Path[p]<>'.') do inc(p);
  AUnitName:=copy(Path,StartPos,p-StartPos);
  //DebugLn(['TCodeHelpManager.GetLinkedFPDocNode UnitName=',AUnitName]);
  if AUnitName='' then exit;
  FPDocFilename:='';
  if ModuleOwner is TLazProject then begin
    AProject:=TLazProject(ModuleOwner);
    if (AProject.FPDocPaths<>'') then begin
      BaseDir:=ExtractFilePath(AProject.ProjectInfoFile);
      FPDocFilename:=FindFPDocFilename(BaseDir,AProject.FPDocPaths,AUnitName);
    end;
  end else if ModuleOwner is TLazPackage then begin
    Pkg:=TLazPackage(ModuleOwner);
    if Pkg.FPDocPaths<>'' then begin
      BaseDir:=Pkg.Directory;
      FPDocFilename:=FindFPDocFilename(BaseDir,Pkg.FPDocPaths,AUnitName);
    end;
  end;
  //DebugLn(['TCodeHelpManager.GetLinkedFPDocNode FPDocFilename=',FPDocFilename]);
  if FPDocFilename='' then exit;

  // load FPDocFile
  Result:=LoadFPDocFile(FPDocFilename,Flags,FPDocFile,CacheWasUsed);
  if Result<>chprSuccess then exit;
  InvalidPath:=p;
  if p>length(Path) then begin
    // link to a unit, no element
    Result:=chprSuccess;
    exit;
  end;
  StartPos:=p+1;

  // find element
  if FindElement(StartPos,FPDocFile) then exit;

  Result:=chprFailed;
end;

function TCodeHelpManager.GetDeclarationChain(Code: TCodeBuffer; X, Y: integer;
  out ListOfPCodeXYPosition: TFPList; out CacheWasUsed: boolean
  ): TCodeHelpParseResult;
begin
  if FDeclarationCache.FindDeclarations(Code,X,Y,ListOfPCodeXYPosition,
    CacheWasUsed)
  then
    Result:=chprSuccess
  else
    Result:=chprFailed;
end;

function TCodeHelpManager.GetCodeContext(CodePos: PCodeXYPosition; out
  FindContext: TFindContext; Complete: boolean; out CacheWasUsed: boolean
  ): TCodeHelpParseResult;
var
  CurTool: TCodeTool;
  CleanPos: integer;
  Node: TCodeTreeNode;
begin
  Result:=chprFailed;
  FindContext:=CleanFindContext;
  CacheWasUsed:=true;

  //DebugLn(['TCodeHelpManager.GetElementChain i=',i,' X=',CodePos^.X,' Y=',CodePos^.Y]);
  if (CodePos=nil) or (CodePos^.Code=nil) or (CodePos^.X<1) or (CodePos^.Y<1)
  then begin
    DebugLn(['TCodeHelpManager.GetElementChain invalid CodePos']);
    exit;
  end;

  // build CodeTree and find node
  if not CodeToolBoss.Explore(CodePos^.Code,CurTool,false,true) then begin
    DebugLn(['TCodeHelpManager.GetElementChain note: there was a parser error']);
  end;
  if CurTool=nil then begin
    DebugLn(['TCodeHelpManager.GetElementChain explore failed']);
    exit;
  end;
  if CurTool.CaretToCleanPos(CodePos^,CleanPos)<>0 then begin
    DebugLn(['TCodeHelpManager.GetElementChain invalid CodePos']);
    exit;
  end;

  Node:=CurTool.FindDeepestNodeAtPos(CleanPos,false);
  if Node=nil then begin
    DebugLn(['TCodeHelpManager.GetElementChain node not found']);
    exit;
  end;

  // use only definition nodes
  if (Node.Desc=ctnProcedureHead) then begin
    if CurTool.PositionInFuncResultName(Node,CleanPos)
    and (Node.LastChild<>nil) and (Node.LastChild.Desc=ctnIdentifier) then begin
      // cursor on function result
      // use the result type node
      Node:=Node.LastChild;
    end else if (Node.Parent<>nil) and (Node.Parent.Desc=ctnProcedure) then
      Node:=Node.Parent;
  end;
  if (not (Node.Desc in
    (AllIdentifierDefinitions+AllSourceTypes
      +[ctnProperty,ctnProcedure,ctnEnumIdentifier])))
  and (not CurTool.NodeIsResultType(Node))
  then begin
    DebugLn(['TCodeHelpManager.GetElementChain ignoring node ',Node.DescAsString]);
    exit;
  end;
  if (CurTool.NodeIsForwardDeclaration(Node)) then begin
    //DebugLn(['TCodeHelpManager.GetElementChain ignoring forward']);
    exit;
  end;
  
  // success
  FindContext.Tool:=CurTool;
  FindContext.Node:=Node;
  Result:=chprSuccess;
end;

function TCodeHelpManager.GetElementChain(Code: TCodeBuffer; X, Y: integer;
  Complete: boolean; out Chain: TCodeHelpElementChain; out CacheWasUsed: boolean
  ): TCodeHelpParseResult;
var
  ListOfPCodeXYPosition: TFPList;
  i: Integer;
  CodePos: PCodeXYPosition;
  CHElement: TCodeHelpElement;
  FPDocFilename: String;
  FindContext: TFindContext;
  AnOwner: TObject;
  NewElementName: String;
  NewUnitName: String;
begin
  Chain:=nil;
  ListOfPCodeXYPosition:=nil;
  CodeToolBoss.ActivateWriteLock;
  try
    //DebugLn(['TCodeHelpManager.GetElementChain GetDeclarationChain...']);
    // get the declaration chain
    Result:=GetDeclarationChain(Code,X,Y,ListOfPCodeXYPosition,CacheWasUsed);
    if Result<>chprSuccess then begin
      {$IFDEF VerboseCodeHelpFails}
      DebugLn(['TCodeHelpManager.GetElementChain GetDeclarationChain failed ',Code.Filename,' x=',x,' y=',y]);
      {$ENDIF}
      exit;
    end;
    if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

    {$IFDEF VerboseCodeHelp}
    DebugLn(['TCodeHelpManager.GetElementChain init the element chain: ListOfPCodeXYPosition.Count=',ListOfPCodeXYPosition.Count,' ...']);
    {$ENDIF}
    // init the element chain
    Result:=chprParsing;
    Chain:=TCodeHelpElementChain.Create;
    Chain.CodePos.Code:=Code;
    Chain.MakeValid;
    Code.LineColToPosition(Y,X,Chain.CodePos.P);
    // fill the element chain
    for i:=0 to ListOfPCodeXYPosition.Count-1 do begin
      // get source position of declaration
      CodePos:=PCodeXYPosition(ListOfPCodeXYPosition[i]);
      Result:=GetCodeContext(CodePos,FindContext,Complete,CacheWasUsed);
      if Result=chprFailed then continue; // skip invalid contexts
      if Result<>chprSuccess then continue;
      if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

      // get fpdoc element path
      NewUnitName:=FindContext.Tool.GetSourceName(false);
      NewElementName:=CodeNodeToElementName(FindContext.Tool,FindContext.Node);

      // skip code nodes with same fpdoc element
      if (Chain.IndexOfElementName(NewUnitName,NewElementName)>=0) then continue;

      // add element
      CHElement:=Chain.Add;
      CHElement.CodeXYPos:=CodePos^;
      CHElement.CodeContext:=FindContext;
      CHElement.ElementName:=NewElementName;
      //DebugLn(['TCodeHelpManager.GetElementChain i=',i,' CodeContext=',FindContextToString(CHElement.CodeContext)]);

      // find corresponding FPDoc file
      CHElement.ElementUnitFileName:=CHElement.CodeContext.Tool.MainFilename;
      CHElement.ElementUnitName:=NewUnitName;
      AnOwner:=Self;
      FPDocFilename:=GetFPDocFilenameForSource(CHElement.ElementUnitFileName,
                                               false,CacheWasUsed,AnOwner);
      CHElement.ElementOwnerName:=GetModuleOwnerName(AnOwner);
      CHElement.ElementFPDocPackageName:=GetFPDocPackageNameByOwner(AnOwner);
      //DebugLn(['TCodeHelpManager.GetElementChain FPDocFilename=',FPDocFilename]);
      if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

      if FPDocFilename<>'' then begin
        // load FPDoc file
        LoadFPDocFile(FPDocFilename,[chofUpdateFromDisk],CHElement.FPDocFile,
                      CacheWasUsed);
        if (not CacheWasUsed) and (not Complete) then exit(chprParsing);
      end;
    end;
    
    // get fpdoc nodes
    for i:=0 to Chain.Count-1 do begin
      CHElement:=Chain[i];
      //DebugLn(['TCodeHelpManager.GetElementChain i=',i,' Element=',CHElement.ElementName]);
      // get fpdoc node
      if (CHElement.FPDocFile<>nil) and (CHElement.ElementName<>'') then begin
        CHElement.ElementNode:=
                  CHElement.FPDocFile.GetElementWithName(CHElement.ElementName);
        CHElement.ElementNodeValid:=true;
      end;
      //DebugLn(['TCodeHelpManager.GetElementChain ElementNode=',CHElement.ElementNode<>nil]);
    end;

    Result:=chprSuccess;
  finally
    if Result<>chprSuccess then
      FreeAndNil(Chain);
    CodeToolBoss.DeactivateWriteLock;
  end;
end;

function TCodeHelpManager.GetHTMLHint(Code: TCodeBuffer; X, Y: integer;
  Options: TCodeHelpHintOptions;
  out BaseURL, HTMLHint, PropDetails: string;
  out CacheWasUsed: boolean): TCodeHelpParseResult;
var
  CursorPos: TCodeXYPosition;
  XYPos: TCodeXYPosition;
  TopLine: integer;
  CTExprType: TExpressionType;
begin
  Result:=chprFailed;
  BaseURL:='lazdoc://';
  HTMLHint:='';
  PropDetails:='';
  CacheWasUsed:=true;

  CursorPos.X:=X;
  CursorPos.Y:=Y;
  CursorPos.Code:=Code;
  if not CodeToolBoss.InitCurCodeTool(Code) then exit;
  try
    // find declaration
    if not CodeToolBoss.CurCodeTool.FindDeclaration(CursorPos,
      DefaultFindSmartHintFlags+[fsfSearchSourceName],CTExprType,XYPos,TopLine)
    then
      exit;
    if (CTExprType.Desc=xtContext) and (CTExprType.Context.Node=nil) then begin
      // codetools found a source file, not a declararion
      debugln(['TCodeHelpManager.GetHTMLHint not a declaration']);
      exit;
    end;
    Result:=GetHTMLHintForExpr(CTExprType,XYPos,Options,BaseURL,HTMLHint,CacheWasUsed);
    // Property details are like "published property TType.PropName:Integer"
    if (CTExprType.Desc=xtContext) and (CTExprType.Context.Tool<>nil) then
      PropDetails:=CTExprType.Context.Tool.GetSmartHint(CTExprType.Context.Node,XYPos,false);
  except
    on E: ECodeToolError do begin
      //debugln(['TCodeHelpManager.GetHTMLHint ECodeToolError: ',E.Message]);
    end;
    on E: Exception do begin
      debugln(['TCodeHelpManager.GetHTMLHint Exception: ',E.Message]);
      //DumpExceptionBackTrace;
    end;
  end;
end;

function TCodeHelpManager.GetHTMLHintForExpr(CTExprType: TExpressionType;
  XYPos: TCodeXYPosition; Options: TCodeHelpHintOptions; out BaseURL,
  HTMLHint: string; out CacheWasUsed: boolean): TCodeHelpParseResult;
var
  aTopLine: integer;
  ListOfPCodeXYPosition: TFPList;
  AnOwner: TObject;
  FPDocFilename: String;
  FPDocFile: TLazFPDocFile;
  Complete: boolean;
  ElementName: String;
  ElementNode: TDOMNode;
  ElementNames: TStringList;
  i: Integer;
  OldXYPos: TCodeXYPosition;
  OldCTTool: TFindDeclarationTool;
  OldCTNode: TCodeTreeNode;
  n: Integer;
  s, Descr, Short: String;
  Cmd: TKeyCommandRelation;
  CTTool: TFindDeclarationTool;
  CTNode: TCodeTreeNode;
begin
  Result:=chprFailed;
  BaseURL:='lazdoc://';
  HTMLHint:='';
  CacheWasUsed:=true;
  AnOwner := nil;

  if (CTExprType.Desc in xtAllIdentPredefinedTypes) then
    CTExprType.Context.Tool := CodeToolBoss.CurCodeTool.FindCodeToolForUsedUnit('system','',false);
  CTTool := CTExprType.Context.Tool;
  CTNode := CTExprType.Context.Node;

  if CTTool=nil then
    Exit(chprFailed);

  ListOfPCodeXYPosition:=nil;
  Complete:=not (chhoSmallStep in Options);
  ElementNames:=TStringList.Create;
  try
    try
      if chhoDeclarationHeader in Options then
        HTMLHint:=HTMLHint+GetHTMLDeclarationHeader(CTTool,CTNode,CTExprType.Desc,XYPos);

      for n:=1 to 30 do
      begin
        if (CTExprType.Desc=xtContext) and (CTNode<>nil) then
          ElementName:=CodeNodeToElementName(CTTool,CTNode)
        else if (CTExprType.Desc in xtAllIdentPredefinedTypes) then
          ElementName:=ExpressionTypeDescNames[CTExprType.Desc]
        else
          break;
        //debugln(['TCodeHelpManager.GetHTMLHintForNode ElementName=',ElementName]);
        i:=ElementNames.Count-1;
        while (i>=0) do begin
          if (ElementNames.Objects[i]=CTTool)
          and (CompareText(ElementNames[i],ElementName)=0) then
            break;
          dec(i);
        end;
        if i>=0 then begin
          // a loop or a forward definition
          {$IFDEF VerboseCodeHelp}
          debugln(['TCodeHelpManager.GetHTMLHintForNode already seen "',ElementName,'"']);
          {$ENDIF}
        end else begin
          ElementNames.AddObject(ElementName,CTTool);

          // add fpdoc entry
          FPDocFilename:=GetFPDocFilenameForSource(CTTool.MainFilename,
                                                   false,CacheWasUsed,AnOwner);
          {$IFDEF VerboseCodeHelp}
          DebugLn(['TCodeHelpManager.GetHTMLHintForNode: FPDocFilename=',FPDocFilename,' ElementName="',ElementName,'"']);
          {$ENDIF}
          if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

          if FPDocFilename<>'' then begin
            // load FPDoc file
            LoadFPDocFile(FPDocFilename,[chofUpdateFromDisk],FPDocFile,CacheWasUsed);
            if (not CacheWasUsed) and (not Complete) then exit(chprParsing);

            ElementNode:=FPDocFile.GetElementWithName(ElementName);
            if ElementNode<>nil then begin
              //DebugLn(['TCodeHelpManager.GetHTMLHintForNode: fpdoc element found "',ElementName,'"']);
              Short:=AppendLineEnding(GetFPDocNodeAsHTML(FPDocFile,ElementNode.FindNode(FPDocItemNames[fpdiShort])));
              Descr:=AppendLineEnding(GetFPDocNodeAsHTML(FPDocFile,ElementNode.FindNode(FPDocItemNames[fpdiDescription])));
              s:=Short+Descr;
              if chhoDeclarationHeader in Options then
              begin
                // Add Description header only when requested. Save space otherwise.
                if s<>'' then
                  s:='<br>'+LineEnding+'<div class="title">Description</div>'+LineEnding+s;
              end
              else begin
                // Make Short text distinctive if both are given and no header is requested.
                if (Short<>'') and (Descr<>'') then
                  s:=Short+'<hr>'+Descr;
              end;
              HTMLHint:=HTMLHint+s;
              HTMLHint:=HTMLHint+GetFPDocNodeAsHTML(FPDocFile,ElementNode.FindNode(FPDocItemNames[fpdiErrors]));
              HTMLHint:=HTMLHint+GetFPDocNodeAsHTML(FPDocFile,ElementNode.FindNode(FPDocItemNames[fpdiSeeAlso]));
              HTMLHint:=HTMLHint+GetFPDocNodeAsHTML(FPDocFile,ElementNode.FindNode(FPDocItemNames[fpdiExample]));
            end;
          end;

          if chhoComments in Options then
          begin
            // add pasdoc
            HTMLHint:=HTMLHint+GetPasDocCommentsAsHTML(CTTool,CTNode);
          end;
        end;

        // find inherited node
        if  (CTNode<>nil) and (
             (CTNode.Desc=ctnProperty) or
             ((CTNode.Desc in [ctnProcedure,ctnProcedureHead])
              and (CTTool.ProcNodeHasSpecifier(CTNode,psOVERRIDE))))
        then begin
          {$ifdef VerboseCodeHelp}
          debugln(['TCodeHelpManager.GetHTMLHintForNode: searching for inherited of ',CTNode.DescAsString,' ',dbgs(XYPos)]);
          {$endif}
          OldXYPos:=XYPos;
          OldCTTool:=CTTool;
          OldCTNode:=CTNode;
          if (not OldCTTool.FindDeclaration(OldXYPos,[fsfSearchSourceName],
            CTTool,CTNode,XYPos,aTopLine))
          or (CTNode=OldCTNode)
          or (CTNode=nil)
          then begin
            {$ifdef VerboseCodeHelp}
            debugln(['TCodeHelpManager.GetHTMLHintForNode: inherited not found: ',dbgs(OldXYPos)]);
            {$endif}
            break;
          end;
        end else begin
          {$ifdef VerboseCodeHelp}
          debugln(['TCodeHelpManager.GetHTMLHintForNode: not searching inherited for ',CTNode.DescAsString]);
          {$endif}
          break;
        end;

      end;

    except
      on E: ECodeToolError do begin
        //debugln(['TCodeHelpManager.GetHTMLHintForNode: ECodeToolError: ',E.Message]);
      end;
      on E: Exception do begin
        debugln(['TCodeHelpManager.GetHTMLHintForNode: Exception: ',E.Message]);
        //DumpExceptionBackTrace;
      end;
    end;

  finally
    ElementNames.Free;
    FreeListOfPCodeXYPosition(ListOfPCodeXYPosition);

    // Add package name
    s:=OwnerToFPDocHint(AnOwner);
    if s<>'' then
      HTMLHint:=HTMLHint+s;

    if HTMLHint<>'' then begin
      if (chhoShowFocusHint in Options) then begin
        Cmd:=EditorOpts.KeyMap.FindByCommand(ecFocusHint);
        if (Cmd<>nil) and (not IDEShortCutEmpty(Cmd.ShortcutA)) then begin
          HTMLHint:=HTMLHint+'<div class="focushint">Press '
            +KeyAndShiftStateToEditorKeyString(Cmd.ShortcutA)+' for focus</div>'+LineEnding;
        end;
      end;
      HTMLHint:='<html><head><link rel="stylesheet" href="lazdoc://lazarus/lazdoc.css" type="text/css">'+LineEnding
        +'<meta http-equiv="Content-Type" content="text/html; charset=utf-8"></head>'+LineEnding
        +'<body>'+LineEnding+HTMLHint+'</body>'+LineEnding;
      Result:=chprSuccess;
    end else
      Result:=chprFailed;
  end;
  {$ifdef VerboseCodeHelp}
  debugln(['TCodeHelpManager.GetHTMLHintForNode: ',HTMLHint]);
  {$endif}
end;

function TCodeHelpManager.GetHTMLHintForNode(CTTool: TFindDeclarationTool;
  CTNode: TCodeTreeNode; XYPos: TCodeXYPosition; Options: TCodeHelpHintOptions;
  out BaseURL, HTMLHint: string; out CacheWasUsed: boolean
  ): TCodeHelpParseResult;
var
  ExprType: TExpressionType;
begin
  ExprType.Desc:=xtContext;
  ExprType.Context.Tool:=CTTool;
  ExprType.Context.Node:=CTNode;
  Result := GetHTMLHintForExpr(ExprType, XYPos, Options, BaseURL, HTMLHint, CacheWasUsed);
end;

function TCodeHelpManager.GetHTMLHintForUnit(AUnitName, InFilename: string;
  BaseDir: string; Options: TCodeHelpHintOptions; out BaseURL,
  HTMLHint: string; out CacheWasUsed: boolean): TCodeHelpParseResult;
var
  aFilename: String;
  Code: TCodeBuffer;
  CTTool: TCodeTool;
  NamePos: TAtomPosition;
  XYPos: TCodeXYPosition;
begin
  Result:=chprFailed;
  BaseURL:='lazdoc://';
  HTMLHint:='';
  CacheWasUsed:=true;

  try
    aFilename:=CodeToolBoss.DirectoryCachePool.FindUnitSourceInCompletePath(
      BaseDir,AUnitName,InFilename);
    if aFilename='' then begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit unit "',AUnitName,'" not found, BaseDir="',BaseDir,'"']);
      exit; // unit not found
    end;
    Code:=CodeToolBoss.LoadFile(aFilename,true,false);
    if Code=nil then begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit unable to load file "',aFilename,'"']);
      exit; // can not load source file
    end;
    CodeToolBoss.Explore(Code,CTTool,false,true);
    if CTTool=nil then begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit unable to explore ',Code.Filename]);
      exit; // e.g. main source not found
    end;
    if not CTTool.GetSourceNamePos(NamePos) then begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit unit has no header ',CTTool.MainFilename]);
      exit;
    end;
    if not CTTool.CleanPosToCaret(NamePos.StartPos,XYPos) then begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit CTTool.CleanPosToCaret failed']);
      exit;
    end;
    debugln(['TCodeHelpManager.GetHTMLHintForUnit ',dbgs(XYPos)]);
    Result:=GetHTMLHintForNode(CTTool,CTTool.Tree.Root,XYPos,
                               Options,BaseURL,HTMLHint,CacheWasUsed);
  except
    on E: ECodeToolError do begin
      debugln(['TCodeHelpManager.GetHTMLHint ECodeToolError: ',E.Message]);
    end;
    on E: Exception do begin
      debugln(['TCodeHelpManager.GetHTMLHintForUnit Exception: ',E.Message]);
      //DumpExceptionBackTrace;
    end;
  end;
end;

function TCodeHelpManager.GetHTMLDeclarationHeader(Tool: TFindDeclarationTool;
  Node: TCodeTreeNode; Desc: TExpressionTypeDesc; XYPos: TCodeXYPosition
  ): string;
var
  CTHint: String;
begin
  Result:='<div class="header">';
  // add declaration
  if Desc=xtContext then
    CTHint:=Tool.GetSmartHint(Node,XYPos,false)
  else if Desc in xtAllIdentPredefinedTypes then
    CTHint:='type '+ExpressionTypeDescNames[Desc]
  else
    CTHint:='';
  Result:=Result+'  <nobr>'+SourceToFPDocHint(CTHint)+'</nobr>';

  // add link to declaration
  Result:=Result+'<br>'+LineEnding;
  if XYPos.Code=nil then begin
    if (Node<>nil) then
      Tool.CleanPosToCaret(Node.StartPos,XYPos)
    else if Desc in xtAllIdentPredefinedTypes then
      Tool.CleanPosToCaret(Tool.Tree.Root.StartPos,XYPos);
  end;
  Result:=Result+'  '+SourcePosToFPDocHint(XYPos)+LineEnding;

  if (XYPos.Code<>nil) and (CompareFilenames(Tool.MainFilename,XYPos.Code.Filename)<>0)
  then begin
    // node in include file => show link to unit
    Result:=Result+'<br>  unit '+SourcePosToFPDocHint(Tool.MainFilename,1,1,Tool.GetSourceName)+LineEnding;
  end;

  Result:=Result+'</div>'+LineEnding;
end;

function TCodeHelpManager.GetHTMLDeclarationHeader(Tool: TFindDeclarationTool;
  Node: TCodeTreeNode; XYPos: TCodeXYPosition): string;
begin
  Result := GetHTMLDeclarationHeader(Tool, Node, xtContext, XYPos);
end;

function TCodeHelpManager.GetPasDocCommentsAsHTML(Tool: TFindDeclarationTool;
  Node: TCodeTreeNode): string;
var
  ListOfPCodeXYPosition: TFPList;
  i: Integer;
  CodeXYPos, LastCodeXYPos: PCodeXYPosition;
  CommentCode: TCodeBuffer;
  CommentStart: integer;
  NestedComments: Boolean;
  CommentStr, LastComment: String;

  function ShiftLeft(const Comment: String) : String;
  var
    Lines : TStringList;
    S : String;
    I, J, LeftMost : Integer;
  begin
    try
      Lines := TStringList.Create;
      Lines.Text := Comment;

      LeftMost := Length(Comment);

      for I := 0 to Lines.Count - 1 do
      begin
        if LeftMost <= 1 then
          Break;

        S := Lines[I];
        J := 1;
        while (J <= Length(S)) and (J < LeftMost) and (S[J] = ' ') do
          Inc(J);

        if J < LeftMost then
          LeftMost := J;
      end;

      if LeftMost > 1 then
        for I := 0 to Lines.Count - 1 do
          Lines[I] := Copy(Lines[I], LeftMost, Length(Lines[I]) - LeftMost + 1);

      Result := Lines.Text;
    finally
      FreeAndNil(Lines);
    end;
  end;  
  
  procedure AddComment;
  begin
    if (CodeXYPos=nil) or (LastCodeXYPos=nil)
    or (CodeXYPos^.Code<>LastCodeXYPos^.Code)
    or (CodeXYPos^.Y-LastCodeXYPos^.Y>10) then begin
      // the last comment is at a different position => add a source link
      if LastComment<>'' then
        Result:=Result+'<span class="comment">'+TextToHTML(ShiftLeft(LastComment))
          +' ('+SourcePosToFPDocHint(LastCodeXYPos^,'Source')+')'
          +'</span><br>'+LineEnding;
      LastComment:=CommentStr;
    end else begin
      // these two comments are very near together => combine them
      if LastComment<>'' then
        LastComment+=LineEnding;
      LastComment+=CommentStr;
    end;
    LastCodeXYPos:=CodeXYPos;
  end;

  function ExtractComment(const Source: String;
    CommentStart: Integer) : String;
  var
    CommentEnd, XPos: Integer;
  begin
    XPos := CodeXYPos^.X;
    CommentEnd := FindCommentEnd(Source, CommentStart, NestedComments);
    
    case Source[CommentStart] of
    '/': 
      begin
        CommentStart := CommentStart + 2;
        XPos := 0;
      end;
    '(': 
      begin 
        CommentStart := CommentStart + 2;
        CommentEnd := CommentEnd - 2;
        XPos := XPos + 1;
      end;
    '{': 
      begin 
        CommentStart := CommentStart + 1;
        CommentEnd := CommentEnd - 1;
      end;    
    end;
    Result:=Copy(Source, CommentStart, CommentEnd - CommentStart);
    
    Result := TrimRight(Result);    
    
    if XPos > 0 then
      Result := StringOfChar(' ', XPos) + Result;
  end;
  
begin
  Result:='';
  if (Tool=nil) or (Node=nil) then exit;
  ListOfPCodeXYPosition:=nil;
  try
    if not Tool.GetPasDocComments(Node,ListOfPCodeXYPosition) then exit;
    if ListOfPCodeXYPosition=nil then exit;
    NestedComments := Tool.Scanner.NestedComments;
    LastCodeXYPos := nil;
    LastComment := '';
    for i := 0 to ListOfPCodeXYPosition.Count - 1 do
    begin
      CodeXYPos := PCodeXYPosition(ListOfPCodeXYPosition[i]);
      CommentCode := CodeXYPos^.Code;
      CommentCode.LineColToPosition(CodeXYPos^.Y,CodeXYPos^.X,CommentStart);
      if (CommentStart<1) or (CommentStart>CommentCode.SourceLength)
      then
        continue;
      CommentStr := ExtractComment(CommentCode.Source, CommentStart);
      AddComment;
    end;
    CommentStr:='';
    CodeXYPos:=nil;
    AddComment;
  finally
    FreeListOfPCodeXYPosition(ListOfPCodeXYPosition);
  end;
end;

function TCodeHelpManager.GetFPDocNodeAsHTML(FPDocFile: TLazFPDocFile;
  DOMNode: TDOMNode): string;

  function NodeToHTML(Node: TDOMNode): string; forward;

  function AddChilds(Node: TDOMNode): string;
  var
    Child: TDOMNode;
  begin
    Result:='';
    Child:=Node.FirstChild;
    while Child<>nil do begin
      Result:=Result+NodeToHTML(Child);
      Child:=Child.NextSibling;
    end;
  end;

  function NodeToHTML(Node: TDOMNode): string;
  var
    s: String;
    Attr: TDOMNode;
  begin
    Result:='';
    if Node=nil then exit;
    //debugln(['TCodeHelpManager.GetFPDocNodeAsHTML.NodeToHTML ',Node.NodeName]);
    if (Node.NodeName='short')
    or (Node.NodeName='descr')
    or (Node.NodeName='seealso')
    or (Node.NodeName='errors')
    then begin
      s:=AddChilds(Node);
      if s='' then exit;
      if Node.NodeName='errors' then
        Result:=Result+'<div class="title">'+'Errors'+'</div>'
      else if Node.NodeName='seealso' then
        Result:=Result+'<div class="title">'+'See also'+'</div>';
      Result:=Result+'<div class="'+Node.NodeName+'">'+s+'</div>'+LineEnding;
    end else
    if (Node.NodeName='p')
    or (Node.NodeName='b')
    or (Node.NodeName='pre')
    or (Node.NodeName='table')
    or (Node.NodeName='th')
    or (Node.NodeName='tr')
    or (Node.NodeName='td')
    or (Node.NodeName='ul')
    or (Node.NodeName='li')
    or (Node.NodeName='hr')
    then begin
      Result:=Result+'<'+Node.NodeName+'>'+AddChilds(Node)+'</'+Node.NodeName+'>';
    end else if (Node.NodeName='var') then begin
      Result:=Result+'<span class="keyword">'+AddChilds(Node)+'</span>';
    end else if (Node.NodeName='link') and (Node.Attributes<>nil) then begin
      Attr:=Node.Attributes.GetNamedItem('id');
      if (Attr=nil) or (Attr.NodeValue='') then exit;
      s:=AddChilds(Node);
      if s='' then s:=Attr.NodeValue;
      Result:=Result+'<a href="fpdoc://'+FPDocLinkToURL(FPDocFile,Attr.NodeValue)+'">'+s+'</a>';
      if (Node.ParentNode<>nil) and (Node.ParentNode.NodeName='seealso') then
        Result:=Result+'<br>';
    end else if (Node.NodeName='example') then begin
      Attr:=Node.Attributes.GetNamedItem('file');
      if (Attr=nil) or (Attr.NodeValue='') then exit;
      s:=ExtractFilePath(FPDocFile.Filename);
      if not FilenameIsAbsolute(s) then exit;
      s:=s+Attr.NodeValue;
      Result:=Result+SourcePosToFPDocHint(s,1,1,'Example')+'<br>';
    end else if (Node.NodeName='#text') then begin
      Result:=Result+Node.NodeValue;
    end else begin
      debugln(['TCodeHelpManager.GetFPDocNodeAsHTML.NodeToHTML skipping ',Node.NodeName]);
    end;
  end;

begin
  Result:=NodeToHTML(DOMNode);
end;

function TCodeHelpManager.TextToHTML(Txt: string): string;
var
  l: Integer;
  c, d: PChar;
begin
  Result := '';
  if Txt = '' then
    exit;
  c := @Txt[1];
  l := 0;
  while c^ <> #0 do begin
    inc(l);
    case c^ of
      ' ' : inc(l, 5);
      '<' : inc(l, 3);
      '>' : inc(l, 3);
      '&' : inc(l, 4);
      #10,#13 :
        begin
          inc(l, 3);
          if c[1] in [#10,#13] then
            inc(c);
        end;
    end;
    inc(c);
  end;

  SetLength(Result, l);
  c := @Txt[1];
  d := @Result[1];
  while c^ <> #0 do begin
    case c^ of
      ' ' :
        begin
          d[0] := '&';
          d[1] := 'n';
          d[2] := 'b';
          d[3] := 's';
          d[4] := 'p';
          d[5] := ';';
          inc(d, 5);
        end;
      '<' :
        begin
          d[0] := '&';
          d[1] := 'l';
          d[2] := 't';
          d[3] := ';';
          inc(d, 3);
        end;
      '>' :
        begin
          d[0] := '&';
          d[1] := 'g';
          d[2] := 't';
          d[3] := ';';
          inc(d, 3);
        end;
      '&' :
        begin
          d[0] := '&';
          d[1] := 'a';
          d[2] := 'm';
          d[3] := 'p';
          d[4] := ';';
          inc(d, 4);
        end;
      #10,#13 :
        begin
          d[0] := '<';
          d[1] := 'b';
          d[2] := 'r';
          d[3] := '>';
          inc(d, 3);
          if c[1] in [#10,#13] then
            inc(c);
        end;
      else
        d^ := c^;
    end;
    inc(c);
    inc(d);
  end;
end;

function TCodeHelpManager.CreateElement(Code: TCodeBuffer; X, Y: integer;
  out Element: TCodeHelpElement): Boolean;
var
  CacheWasUsed: boolean;
  FPDocFilename: String;
  AnOwner: TObject;
  CHResult: TCodeHelpParseResult;
begin
  Result:=false;
  Element:=nil;
  if Code=nil then begin
    DebugLn(['TCodeHelpManager.CreateElement failed Code=nil']);
    exit;
  end;
  DebugLn(['TCodeHelpManager.CreateElement START ',Code.Filename,' ',X,',',Y]);
  
  Element:=TCodeHelpElement.Create;
  try
    // check if code context can have a fpdoc element
    Element.CodeXYPos.Code:=Code;
    Element.CodeXYPos.X:=X;
    Element.CodeXYPos.Y:=Y;
    if GetCodeContext(@Element.CodeXYPos,Element.CodeContext,true,
      CacheWasUsed)<>chprSuccess then
    begin
      DebugLn(['TCodeHelpManager.CreateElement GetCodeContext failed for ',Code.Filename,' ',X,',',Y]);
      exit;
    end;
    Element.ElementName:=CodeNodeToElementName(Element.CodeContext.Tool,
                                               Element.CodeContext.Node);
    DebugLn(['TCodeHelpManager.CreateElement Element.ElementName=',Element.ElementName]);

    // find / create fpdoc file
    Element.ElementUnitFileName:=Element.CodeContext.Tool.MainFilename;
    Element.ElementUnitName:=Element.CodeContext.Tool.GetSourceName(false);
    FPDocFilename:=GetFPDocFilenameForSource(Element.ElementUnitFileName,false,
                                             CacheWasUsed,AnOwner,true);
    if FPDocFilename='' then begin
      // no fpdoc file
      DebugLn(['TCodeHelpManager.CreateElement unable to create fpdoc file for ',FPDocFilename]);
    end;
    DebugLn(['TCodeHelpManager.CreateElement FPDocFilename=',FPDocFilename]);

    // parse fpdoc file
    CHResult:=LoadFPDocFile(FPDocFilename,[chofUpdateFromDisk],
                            Element.FPDocFile,CacheWasUsed);
    if CHResult<>chprSuccess then begin
      DebugLn(['TCodeHelpManager.CreateElement unable to load fpdoc file ',FPDocFilename]);
      exit;
    end;

    Element.ElementNode:=Element.FPDocFile.GetElementWithName(
                                                      Element.ElementName,true);
    Result:=Element.ElementNode<>nil;
  finally
    if not Result then
      FreeAndNil(Element);
  end;
end;

function TCodeHelpManager.SourceToFPDocHint(Src: string; NestedComments: boolean
  ): string;

  procedure EndSpan(SpanName: string; var r: string);
  begin
    if SpanName='' then exit;
    r:=r+'</span>';
  end;

  procedure StartSpan(SpanName: string; var r: string);
  begin
    if SpanName='' then exit;
    r:=r+'<span class="'+SpanName+'">';
  end;

  function TokenIDToSpan(TokenID: TtkTokenKind): string;
  begin
    case TokenID of
    tkComment: Result:='comment';
    tkIdentifier: Result:='identifier';
    tkKey: Result:='keyword';
    tkNumber: Result:='number';
    tkString: Result:='string';
    tkSymbol: Result:='symbol';
    tkDirective: Result:='directive';
    else Result:='';
    end;
  end;

var
  TokenID: TtkTokenKind;
  LastTokenID: TtkTokenKind;
  Token: String;
begin
  Result:='';
  PasHighlighter.NestedComments:=NestedComments;
  PasHighlighter.ResetRange;
  PasHighlighter.SetLine(Src,0);
  LastTokenID:=tkUnknown;
  while not PasHighlighter.GetEol do begin
    TokenID:=PasHighlighter.GetTokenID;
    if (Result<>'') and (LastTokenID<>TokenID) then
      EndSpan(TokenIDToSpan(LastTokenID),Result);
    if (Result='') or (LastTokenID<>TokenID) then
      StartSpan(TokenIDToSpan(TokenID),Result);
    Token:=PasHighlighter.GetToken;
    //debugln(['TCodeHelpManager.SourceToFPDocHint ',Token,' ',ord(TokenID)]);
    Result:=Result+TextToHTML(Token);
    LastTokenID:=TokenID;
    PasHighlighter.Next;
  end;
  if (Result<>'') and (LastTokenID<>tkUnknown) then
    EndSpan(TokenIDToSpan(LastTokenID),Result);
end;

function TCodeHelpManager.SourcePosToFPDocHint(XYPos: TCodeXYPosition;
  Caption: string): string;
begin
  Result:='';
  if XYPos.Code=nil then exit;
  Result:=SourcePosToFPDocHint(XYPos.Code.Filename,XYPos.X,XYPos.Y,Caption);
end;

function TCodeHelpManager.SourcePosToFPDocHint(const aFilename: string; X,
  Y: integer; Caption: string): string;
var
  Link: String;
  i: Integer;
begin
  Result:='';
  if aFilename='' then exit;
  Link:=aFilename;
  if Y>=1 then begin
    Link:=Link+'('+IntToStr(Y);
    if X>=1 then
      Link:=Link+','+IntToStr(X);
    Link:=Link+')';
  end;
  if Caption='' then begin
    Caption:=Link;
    // make caption breakable into several lines
    for i:=length(Caption)-1 downto 1 do begin
      if Caption[i]=PathDelim then
        System.Insert('<wbr/>',Caption,i+1);
    end;
  end;
  Result:='<a href="source://'+Link+'">'+Caption+'</a>';
end;

function TCodeHelpManager.OwnerToFPDocHint(AnOwner: TObject): string;
var
  PackName: string;
begin
  Result:='';
  if AnOwner=nil then exit;
  if AnOwner is TLazPackage then begin
    PackName:=TLazPackage(AnOwner).Name;
    Result:='<br>'+LineEnding+'<div class="title">Package</div>'+LineEnding
           +'<a href="openpackage://'+PackName+'">'+PackName+'</a>';
  end;
end;

function TCodeHelpManager.FPDocLinkToURL(FPDocFile: TLazFPDocFile;
  const LinkID: string): string;
begin
  Result:=LinkID;
  if Result='' then exit;
  if Result[1]='#' then begin
    // has already a package
    exit;
  end;
  if FPDocFile.GetElementWithName(Result)<>nil then begin
    // link target is in this unit => prepend package and unit name
    Result:='#'+FPDocFile.GetPackageName+'.'+FPDocFile.GetModuleName+'.'+Result;
  end else begin
    // link target is not in this unit, but same package => prepend package name
    Result:='#'+FPDocFile.GetPackageName+'.'+Result;
  end;
end;

procedure TCodeHelpManager.FreeDocs;
var
  AVLNode: TAvlTreeNode;
begin
  AVLNode:=FDocs.FindLowest;
  while AVLNode<>nil do begin
    CallDocChangeEvents(chmhDocChanging,TLazFPDocFile(AVLNode.Data));
    AVLNode:=FDocs.FindSuccessor(AVLNode);
  end;
  FDocs.FreeAndClear;
end;

procedure TCodeHelpManager.ClearSrcToDocMap;
begin
  FSrcToDocMap.FreeAndClear;
end;

procedure TCodeHelpManager.RemoveAllHandlersOfObject(AnObject: TObject);
var
  HandlerType: TCodeHelpManagerHandler;
begin
  for HandlerType:=Low(TCodeHelpManagerHandler) to High(TCodeHelpManagerHandler) do
    FHandlers[HandlerType].RemoveAllMethodsOfObject(AnObject);
end;

procedure TCodeHelpManager.AddHandlerOnChanging(
  const OnDocChangingEvent: TCodeHelpChangeEvent; AsLast: boolean);
begin
  AddHandler(chmhDocChanging,TMethod(OnDocChangingEvent),AsLast);
end;

procedure TCodeHelpManager.RemoveHandlerOnChanging(
  const OnDocChangingEvent: TCodeHelpChangeEvent);
begin
  RemoveHandler(chmhDocChanging,TMethod(OnDocChangingEvent));
end;

procedure TCodeHelpManager.AddHandlerOnChanged(
  const OnDocChangedEvent: TCodeHelpChangeEvent; AsLast: boolean);
begin
  AddHandler(chmhDocChanged,TMethod(OnDocChangedEvent),AsLast);
end;

procedure TCodeHelpManager.RemoveHandlerOnChanged(
  const OnDocChangedEvent: TCodeHelpChangeEvent);
begin
  RemoveHandler(chmhDocChanged,TMethod(OnDocChangedEvent));
end;


{ TCodeHelpElementChain }

function TCodeHelpElementChain.GetCount: integer;
begin
  Result:=FItems.Count;
end;

function TCodeHelpElementChain.GetItems(Index: integer): TCodeHelpElement;
begin
  Result:=TCodeHelpElement(FItems[Index]);
end;

function TCodeHelpElementChain.Add: TCodeHelpElement;
begin
  Result:=TCodeHelpElement.Create;
  FItems.Add(Result);
end;

constructor TCodeHelpElementChain.Create;
begin
  FItems:=TFPList.Create;
end;

destructor TCodeHelpElementChain.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TCodeHelpElementChain.Clear;
var
  i: Integer;
begin
  for i:=0 to FItems.Count-1 do TObject(FItems[i]).Free;
  FItems.Clear;
end;

function TCodeHelpElementChain.IndexOfFile(AFile: TLazFPDocFile): integer;
begin
  Result:=FItems.Count-1;
  while (Result>=0) do begin
    if Items[Result].FPDocFile=AFile then exit;
    dec(Result);
  end;
end;

function TCodeHelpElementChain.IndexOfElementName(ElementName: string): integer;
begin
  Result:=FItems.Count-1;
  while (Result>=0) do begin
    if SysUtils.CompareText(Items[Result].ElementName,ElementName)=0 then exit;
    dec(Result);
  end;
end;

function TCodeHelpElementChain.IndexOfElementName(ElementUnitName,
  ElementName: string): integer;
begin
  Result:=FItems.Count-1;
  while (Result>=0) do begin
    if (SysUtils.CompareText(Items[Result].ElementUnitName,ElementUnitName)=0)
    and (SysUtils.CompareText(Items[Result].ElementName,ElementName)=0) then
      exit;
    dec(Result);
  end;
end;

function TCodeHelpElementChain.IsValid: boolean;
begin
  Result:=(IDEChangeStep=CompilerParseStamp)
    and (CodetoolsChangeStep=CodeToolBoss.CodeTreeNodesDeletedStep);
  //DebugLn(['TCodeHelpElementChain.IsValid Result=',Result,' IDEChangeStep=',IDEChangeStep,' CompilerParseStamp=',CompilerParseStamp,' CodetoolsChangeStep=',CodetoolsChangeStep,' CodeToolBoss.CodeTreeNodesDeletedStep=',CodeToolBoss.CodeTreeNodesDeletedStep]);
end;

procedure TCodeHelpElementChain.MakeValid;
begin
  IDEChangeStep:=CompilerParseStamp;
  CodetoolsChangeStep:=CodeToolBoss.CodeTreeNodesDeletedStep;
end;

function TCodeHelpElementChain.DocFile: TLazFPDocFile;
begin
  Result:=nil;
  if (Count>0) then
    Result:=Items[0].FPDocFile;
end;

procedure TCodeHelpElementChain.WriteDebugReport;
var
  Line, Column: integer;
  i: Integer;
begin
  CodePos.Code.AbsoluteToLineCol(CodePos.P,Line,Column);
  DebugLn(['TCodeHelpElementChain.WriteDebugReport ',CodePos.Code.Filename,' X=',Column,' Y=',Line,' IDEChangeStep=',IDEChangeStep,' CodetoolsChangeStep=',CodetoolsChangeStep]);
  for i:=0 to Count-1 do
    Items[i].WriteDebugReport;
end;

{ TLazFPDocNode }

constructor TLazFPDocNode.Create(AFile: TLazFPDocFile; ANode: TDOMNode);
begin
  Node:=ANode;
  DocFile:=AFile;
end;

{ TCodeHelpElement }

procedure TCodeHelpElement.WriteDebugReport;
begin
  DebugLn(['  ',CodeXYPos.Code.Filename,' X=',CodeXYPos.X,' Y=',CodeXYPos.Y,' ElementOwnerName=',ElementOwnerName,' ElementFPDocPackageName=',ElementFPDocPackageName,' ElementUnitName=',ElementUnitName,' ElementUnitFileName=',ElementUnitFileName,' ElementName=',ElementName]);
end;

end.


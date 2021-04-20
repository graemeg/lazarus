{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: SynEditStrConst.pas, released 2000-04-07.
The Original Code is based on mwLocalStr.pas by Michael Hieke, part of the
mwEdit component suite.
All Rights Reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id$

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

Known Issues:
-------------------------------------------------------------------------------}

unit SynEditStrConst;

{$I synedit.inc}

interface

// NOTE: this is design-time stuff, so no need to have it in stringtables
const
  SYNS_ComponentsPage           =  'SynEdit';
  SYNS_HighlightersPage         =  'SynEdit Highlighters';

resourcestring
  (* IMPORTANT
     If you add any Names, also add a unique identifier to the list in the const section below
  *)

  (* Attribute Names *)
  SYNS_Untitled                 =  'Untitled';
  // names for highlighter attributes
  SYNS_AttrASP                  =  'Asp';
  SYNS_AttrCDATA                =  'CDATA';
  SYNS_AttrDOCTYPE              =  'DOCTYPE';
  SYNS_AttrAnnotation           =  'Annotation';
  SYNS_AttrAssembler            =  'Assembler';
  SYNS_AttrAttributeName        =  'Attribute Name';
  SYNS_AttrAttributeValue       =  'Attribute Value';
  SYNS_AttrBlock                =  'Block';
  SYNS_AttrBrackets             =  'Brackets';
  SYNS_AttrCDATASection         =  'CDATA Section';
  SYNS_AttrCharacter            =  'Character';
  SYNS_AttrClass                =  'Class';
  SYNS_AttrComment              =  'Comment';
  SYNS_AttrIDEDirective         =  'IDE Directive';
  SYNS_AttrCondition            =  'Condition';
  SYNS_AttrDataType             =  'Data type';
  SYNS_AttrDefaultPackage       =  'Default packages';
  SYNS_AttrDir                  =  'Direction';
  SYNS_AttrDirective            =  'Directive';
  SYNS_AttrDOCTYPESection       =  'DOCTYPE Section';
  SYNS_AttrDocumentation        =  'Documentation';
  SYNS_AttrElementName          =  'Element Name';
  SYNS_AttrEmbedSQL             =  'Embedded SQL';
  SYNS_AttrEmbedText            =  'Embedded text';
  SYNS_AttrEntityReference      =  'Entity Reference';
  SYNS_AttrEscapeAmpersand      =  'Escape ampersand';
  SYNS_AttrEvent                =  'Event';
  SYNS_AttrException            =  'Exception';
  SYNS_AttrFloat                =  'Float';
  SYNS_AttrForm                 =  'Form';
  SYNS_AttrFunction             =  'Function';
  SYNS_AttrHexadecimal          =  'Hexadecimal';
  SYNS_AttrIcon                 =  'Icon reference';
  SYNS_AttrIdentifier           =  'Identifier';
  SYNS_AttrIllegalChar          =  'Illegal char';
  SYNS_AttrInclude              =  'Include';
  SYNS_AttrIndirect             =  'Indirect';
  SYNS_AttrInvalidSymbol        =  'Invalid symbol';
  SYNS_AttrInternalFunction     =  'Internal function';
  SYNS_AttrKey                  =  'Key';
  SYNS_AttrLabel                =  'Label';
  SYNS_AttrMacro                =  'Macro';
  SYNS_AttrMarker               =  'Marker';
  SYNS_AttrMessage              =  'Message';
  SYNS_AttrMiscellaneous        =  'Miscellaneous';
  SYNS_AttrNamespaceAttrName    =  'Namespace Attribute Name';
  SYNS_AttrNamespaceAttrValue   =  'Namespace Attribute Value';
  SYNS_AttrNonReservedKeyword   =  'Non-reserved keyword';
  SYNS_AttrNull                 =  'Null';
  SYNS_AttrNumber               =  'Number';
  SYNS_AttrOctal                =  'Octal';
  SYNS_AttrOperator             =  'Operator';
  SYNS_AttrPLSQL                =  'Reserved word (PL/SQL)';
  SYNS_AttrPragma               =  'Pragma';
  SYNS_AttrPreprocessor         =  'Preprocessor';
  SYNS_AttrProcessingInstr      =  'Processing Instruction';
  SYNS_AttrQualifier            =  'Qualifier';
  SYNS_AttrRegister             =  'Register';
  SYNS_AttrReservedWord         =  'Reserved word';
  SYNS_AttrRpl                  =  'Rpl';
  SYNS_AttrRplKey               =  'Rpl key';
  SYNS_AttrRplComment           =  'Rpl comment';
  SYNS_AttrSASM                 =  'SASM';
  SYNS_AttrSASMComment          =  'SASM Comment';
  SYNS_AttrSASMKey              =  'SASM Key';
  SYNS_AttrSecondReservedWord   =  'Second reserved word';
  SYNS_AttrSection              =  'Section';
  SYNS_AttrSpace                =  'Space';
  SYNS_AttrSpecialVariable      =  'Special variable';
  SYNS_AttrSQLKey               =  'SQL keyword';  
  SYNS_AttrSQLPlus              =  'SQL*Plus command';
  SYNS_AttrString               =  'String';
  SYNS_AttrSymbol               =  'Symbol';
  SYNS_AttrProcedureHeaderName  =  'Procedure header name';
  SYNS_AttrCaseLabel            =  'Case label';
  SYNS_AttrSyntaxError          =  'SyntaxError';
  SYNS_AttrSystem               =  'System functions and variables';
  SYNS_AttrSystemValue          =  'System value';
  SYNS_AttrTerminator           =  'Terminator';
  SYNS_AttrText                 =  'Text';
  SYNS_AttrUnknownWord          =  'Unknown word';
  SYNS_AttrUser                 =  'User functions and variables';
  SYNS_AttrUserFunction         =  'User functions';
  SYNS_AttrValue                =  'Value';
  SYNS_AttrVariable             =  'Variable';
  SYNS_AttrWhitespace           =  'Whitespace';
  SYNS_AttrTableName            =  'Table Name';
  SYNS_AttrMathMode             =  'Math Mode';
  SYNS_AttrTextMathMode         =  'Text in Math Mode';
  SYNS_AttrSquareBracket        =  'Square Bracket';
  SYNS_AttrRoundBracket         =  'Round Bracket';
  SYNS_AttrTeXCommand           =  'TeX Command';
  SYNS_AttrOrigFile             =  'Diff Original File';
  SYNS_AttrNewFile              =  'Diff New File';
  SYNS_AttrChunkMarker          =  'Diff Chunk Marker';
  SYNS_AttrChunkOrig            =  'Diff Chunk Original Line Count';
  SYNS_AttrChunkNew             =  'Diff Chunk New Line Count';
  SYNS_AttrChunkMixed           =  'Diff Chunk Line Counts';
  SYNS_AttrLineAdded            =  'Diff Added line';
  SYNS_AttrLineRemoved          =  'Diff Removed Line';
  SYNS_AttrLineChanged          =  'Diff Changed Line';
  SYNS_AttrLineContext          =  'Diff Context Line';
  SYNS_AttrPrevValue            =  'Previous value';
  SYNS_AttrMeasurementUnitValue =  'Measurement unit';
  SYNS_AttrSelectorValue        =  'Selector';
  SYNS_AttrFlags                =  'Flags';
  (* End of Attribute Names *)

const
  (* IMPORTANT
     The highlight attribute "StoredName" are the only independent
     identification of Attributes.
     They must be UNIQUE and UNCHANGED.

  *)

  (* Stored Attribute Names *)
  SYNS_XML_Untitled                 =  'Untitled';
  SYNS_XML_AttrASP                  =  'Asp';
  SYNS_XML_AttrCDATA                =  'CDATA';
  SYNS_XML_AttrDOCTYPE              =  'DOCTYPE';
  SYNS_XML_AttrAnnotation           =  'Annotation';
  SYNS_XML_AttrAssembler            =  'Assembler';
  SYNS_XML_AttrAttributeName        =  'Attribute Name';
  SYNS_XML_AttrAttributeValue       =  'Attribute Value';
  SYNS_XML_AttrBlock                =  'Block';
  SYNS_XML_AttrBrackets             =  'Brackets';
  SYNS_XML_AttrCDATASection         =  'CDATA Section';
  SYNS_XML_AttrCharacter            =  'Character';
  SYNS_XML_AttrClass                =  'Class';
  SYNS_XML_AttrComment              =  'Comment';
  SYNS_XML_AttrIDEDirective         =  'IDE Directive';
  SYNS_XML_AttrCondition            =  'Condition';
  SYNS_XML_AttrDataType             =  'Data type';
  SYNS_XML_AttrDefaultPackage       =  'Default packages';
  SYNS_XML_AttrDir                  =  'Direction';
  SYNS_XML_AttrDirective            =  'Directive';
  SYNS_XML_AttrDOCTYPESection       =  'DOCTYPE Section';
  SYNS_XML_AttrDocumentation        =  'Documentation';
  SYNS_XML_AttrElementName          =  'Element Name';
  SYNS_XML_AttrEmbedSQL             =  'Embedded SQL';
  SYNS_XML_AttrEmbedText            =  'Embedded text';
  SYNS_XML_AttrEntityReference      =  'Entity Reference';
  SYNS_XML_AttrEscapeAmpersand      =  'Escape ampersand';
  SYNS_XML_AttrEvent                =  'Event';
  SYNS_XML_AttrException            =  'Exception';
  SYNS_XML_AttrFloat                =  'Float';
  SYNS_XML_AttrForm                 =  'Form';
  SYNS_XML_AttrFunction             =  'Function';
  SYNS_XML_AttrHexadecimal          =  'Hexadecimal';
  SYNS_XML_AttrIcon                 =  'Icon reference';
  SYNS_XML_AttrIdentifier           =  'Identifier';
  SYNS_XML_AttrIllegalChar          =  'Illegal char';
  SYNS_XML_AttrInclude              =  'Include';
  SYNS_XML_AttrIndirect             =  'Indirect';
  SYNS_XML_AttrInvalidSymbol        =  'Invalid symbol';
  SYNS_XML_AttrInternalFunction     =  'Internal function';
  SYNS_XML_AttrKey                  =  'Key';
  SYNS_XML_AttrLabel                =  'Label';
  SYNS_XML_AttrMacro                =  'Macro';
  SYNS_XML_AttrMarker               =  'Marker';
  SYNS_XML_AttrMessage              =  'Message';
  SYNS_XML_AttrMiscellaneous        =  'Miscellaneous';
  SYNS_XML_AttrNamespaceAttrName    =  'Namespace Attribute Name';
  SYNS_XML_AttrNamespaceAttrValue   =  'Namespace Attribute Value';
  SYNS_XML_AttrNonReservedKeyword   =  'Non-reserved keyword';
  SYNS_XML_AttrNull                 =  'Null';
  SYNS_XML_AttrNumber               =  'Number';
  SYNS_XML_AttrOctal                =  'Octal';
  SYNS_XML_AttrOperator             =  'Operator';
  SYNS_XML_AttrPLSQL                =  'Reserved word (PL/SQL)';
  SYNS_XML_AttrPragma               =  'Pragma';
  SYNS_XML_AttrPreprocessor         =  'Preprocessor';
  SYNS_XML_AttrProcessingInstr      =  'Processing Instruction';
  SYNS_XML_AttrQualifier            =  'Qualifier';
  SYNS_XML_AttrRegister             =  'Register';
  SYNS_XML_AttrReservedWord         =  'Reserved word';
  SYNS_XML_AttrRpl                  =  'Rpl';
  SYNS_XML_AttrRplKey               =  'Rpl key';
  SYNS_XML_AttrRplComment           =  'Rpl comment';
  SYNS_XML_AttrSASM                 =  'SASM';
  SYNS_XML_AttrSASMComment          =  'SASM Comment';
  SYNS_XML_AttrSASMKey              =  'SASM Key';
  SYNS_XML_AttrSecondReservedWord   =  'Second reserved word';
  SYNS_XML_AttrSection              =  'Section';
  SYNS_XML_AttrSpace                =  'Space';
  SYNS_XML_AttrSpecialVariable      =  'Special variable';
  SYNS_XML_AttrSQLKey               =  'SQL keyword';
  SYNS_XML_AttrSQLPlus              =  'SQL*Plus command';
  SYNS_XML_AttrString               =  'String';
  SYNS_XML_AttrSymbol               =  'Symbol';
  SYNS_XML_AttrProcedureHeaderName  =  'Procedure header name';
  SYNS_XML_AttrCaseLabel            =  'Case label';
  SYNS_XML_AttrSyntaxError          =  'SyntaxError';
  SYNS_XML_AttrSystem               =  'System functions and variables';
  SYNS_XML_AttrSystemValue          =  'System value';
  SYNS_XML_AttrTerminator           =  'Terminator';
  SYNS_XML_AttrText                 =  'Text';
  SYNS_XML_AttrUnknownWord          =  'Unknown word';
  SYNS_XML_AttrUser                 =  'User functions and variables';
  SYNS_XML_AttrUserFunction         =  'User functions';
  SYNS_XML_AttrValue                =  'Value';
  SYNS_XML_AttrVariable             =  'Variable';
  SYNS_XML_AttrWhitespace           =  'Whitespace';
  SYNS_XML_AttrTableName            =  'Table Name';
  SYNS_XML_AttrMathMode             =  'Math Mode';
  SYNS_XML_AttrTextMathMode         =  'Text in Math Mode';
  SYNS_XML_AttrSquareBracket        =  'Square Bracket';
  SYNS_XML_AttrRoundBracket         =  'Round Bracket';
  SYNS_XML_AttrTeXCommand           =  'TeX Command';
  SYNS_XML_AttrOrigFile             =  'Diff Original File';
  SYNS_XML_AttrNewFile              =  'Diff New File';
  SYNS_XML_AttrChunkMarker          =  'Diff Chunk Marker';
  SYNS_XML_AttrChunkOrig            =  'Diff Chunk Original Line Count';
  SYNS_XML_AttrChunkNew             =  'Diff Chunk New Line Count';
  SYNS_XML_AttrChunkMixed           =  'Diff Chunk Line Counts';
  SYNS_XML_AttrLineAdded            =  'Diff Added line';
  SYNS_XML_AttrLineRemoved          =  'Diff Removed Line';
  SYNS_XML_AttrLineChanged          =  'Diff Changed Line';
  SYNS_XML_AttrLineContext          =  'Diff Context Line';
  SYNS_XML_AttrPrevValue            =  'Previous value';
  SYNS_XML_AttrMeasurementUnitValue =  'Measurement unit';
  SYNS_XML_AttrSelectorValue        =  'Selector';
  SYNS_XML_AttrFlags                =  'Flags';
  (* End of Stored Attribute Names *)

resourcestring
  // names of exporter output formats
  SYNS_ExporterFormatHTML       =  'HTML';
  SYNS_ExporterFormatRTF        =  'RTF';

  // TCustomSynEdit scroll hint window caption
//  SYNS_ScrollInfoFmt            =  'Top Line: %d';
  SYNS_ScrollInfoFmt            =  '%d - %d';                                   //DDH 10/16/01
  SYNS_ScrollInfoFmtTop         =  'Top Line: %d';
  // TSynEditPrintPreview page number
  SYNS_PreviewScrollInfoFmt     =  'Page: %d';

  // strings for property editors etc
  SYNS_EDuplicateShortcut       =  'Mouse-Shortcut already exists';
  SYNS_ShortcutNone             =  '<none>';
  SYNS_DuplicateShortcutMsg     =  'The keystroke "%s" is already assigned ' +
                                   'to another editor command. (%s)';

  // Filters used for open/save dialog
  SYNS_FilterPascal             =  'Pascal Files (*.pas,*.dpr,*.dpk,*.inc)|*.pas;*.dpr;*.dpk;*.inc';
  SYNS_FilterHP48               =  'HP48 Files (*.s,*.sou,*.a,*.hp)|*.s;*.sou;*.a;*.hp';
  SYNS_FilterCAClipper          =  'CA-Clipper Files (*.prg,*.ch,*.inc)|*.prg;*.ch;*.inc';
  SYNS_FilterCORBAIDL           =  'CORBA IDL files (*.idl)|*.idl';
  SYNS_FilterCPM                =  'CPM reports (*.rdf,*.rif,*.rmf,*.rxf)|*.rdf;*.rif;*.rmf;*.rxf';
  SYNS_FilterCPP                =  'C++ Files (*.c,*.cpp,*.h,*.hpp,*.hh)|*.c;*.cpp;*.h;*.hpp;*.hh';
  SYNS_FilterJava               =  'Java Files (*.java)|*.java';
  SYNS_FilterPerl               =  'Perl Files (*.pl,*.pm,*.cgi)|*.pl;*.pm;*.cgi';
  SYNS_FilterAWK                =  'AWK Script (*.awk)|*.awk';
  SYNS_FilterHTML               =  'HTML Document (*.htm,*.html)|*.htm;*.html';
  SYNS_FilterVBScript           =  'VBScript Files (*.vbs)|*.vbs';
  SYNS_FilterGalaxy             =  'Galaxy Files (*.gtv,*.galrep,*.txt)|*.gtv;*.galrep;*.txt';
  SYNS_FilterPython             =  'Python Files (*.py)|*.py';
  SYNS_FilterSQL                =  'SQL Files (*.sql)|*.sql';
  SYNS_FilterTclTk              =  'Tcl/Tk Files (*.tcl)|*.tcl';
  SYNS_FilterRTF                =  'Rich Text Format (*.rtf)|*.rtf';
  SYNS_FilterBatch              =  'MS-DOS Batch Files (*.bat;*.cmd)|*.bat;*.cmd';
  SYNS_FilterDFM                =  'Borland Form Files (*.dfm;*.xfm)|*.dfm;*.xfm';
  SYNS_FilterLFM                =  'Lazarus Form Files (*.lfm)|*.lfm';
  SYNS_FilterX86Asm             =  'x86 Assembly Files (*.asm)|*.ASM';
  SYNS_FilterGembase            =  'GEMBASE Files (*.dml,*.gem)|*.DML;*.GEM';
  SYNS_FilterINI                =  'INI Files (*.ini)|*.ini';
  SYNS_FilterSML                =  'Standard ML Files (*.sml)|*.sml';
  SYNS_FilterVisualBASIC        =  'Visual Basic Files (*.bas)|*.bas';
  SYNS_FilterADSP21xx           =  'DSP Files (*.dsp,*.inc)|*.DSP;*.INC';
  SYNS_FilterPHP                =  'PHP Files (*.php,*.php3,*.phtml,*.inc)|*.php;*.php3;*.phtml;*.inc';
  SYNS_FilterCache              =  'Cache Files (*.mac,*.inc,*.int)|*.mac;*.inc;*.int';
  SYNS_FilterCSS                =  'Cascading Stylesheets (*.css)|*.css';
  SYNS_FilterJScript            =  'Javascript Files (*.js)|*.js';
  SYNS_FilterKIX                =  'KiXtart scripts (*.kix)|*.kix';
  SYNS_FilterBaan               =  'Baan 4GL Files (*.cln)|*.cln';
  SYNS_FilterFoxpro             =  'Foxpro Files (*.prg)|*.prg';
  SYNS_FilterFortran            =  'Fortran Files (*.for)|*.for';
  SYNS_FilterAsm68HC11          =  '68HC11 Assembler Files (*.hc11,*.asm,*.asc)|*.HC11;*.ASM;*.ASC';
  SYNS_FilterProgress           =  'Progress Files (*.w,*.p,*.i)|*.w;*.p;*.i';
  SYNS_FilterInno               =  'Inno Setup Script Files (*.iss)|*.iss';
  SYNS_FilterModelica           =  'Modelica Files (*.mo)|*.mo';
  SYNS_FilterModula3            =  'Modula-3 Files (*.m3)|*.m3';
  SYNS_FilterSDD                =  'Semanta DD files (*.sdd)|*.sdd';
  SYNS_FilterXML                =  'XML Document (*.xml,*.xsd,*.xsl,*.xslt,*.dtd)|*.xml;*.xsd;*.xsl;*.xslt;*.dtd';
  SYNS_FilterGWS                =  'GW-TEL Script Files (*.gws)|*.gws';
  SYNS_FilterSynGenMsgfiles     =  'Msg files (*.msg)|*.msg';
  SYNS_FilterUNIXShellScript    =  'UNIX Shell Scripts (*.sh)|*.sh';
  SYNS_FilterTeX                =  'TeX Files (*.tex)|*.tex';
  SYNS_FilterPo                 =  'Po Files (*.po)|*.po';

// Currently the language names are used to identify the language
// ToDo: create translation table
const
  // Language names. Maybe somebody wants them translated / more detailed...
  SYNS_LangHP48                 =  'HP48';
  SYNS_LangCAClipper            =  'CA-Clipper';
  SYNS_LangCPM                  =  'COAS Product Manager report';
  SYNS_LangCPP                  =  'C++';
  SYNS_LangJava                 =  'Java';
  SYNS_LangPerl                 =  'Perl';
  SYNS_LangBatch                =  'MS-DOS batch language';
  SYNS_LangDfm                  =  'Borland Form definition';
  SYNS_LangLfm                  =  'Lazarus Form definition';
  SYNS_LangDiff                 =  'Diff File';
  SYNS_LangAWK                  =  'AWK Script';
  SYNS_LangCORBAIDL             =  'CORBA IDL';
  SYNS_LangHTML                 =  'HTML document';
  SYNS_LangVBSScript            =  'MS VBScript';
  SYNS_LangGalaxy               =  'Galaxy';
  SYNS_LangGeneral              =  'General';
  SYNS_LangPascal               =  'ObjectPascal';
  SYNS_LangX86Asm               =  'x86 assembly language';
  SYNS_LangPython               =  'Python';
  SYNS_LangTclTk                =  'Tcl/Tk';
  SYNS_LangSQL                  =  'SQL';
  SYNS_LangGembase              =  'Gembase';
  SYNS_LangINI                  =  'INI file';
  SYNS_LangSML                  =  'Standard ML';
  SYNS_LangVisualBASIC          =  'Visual Basic';
  SYNS_LangADSP21xx             =  'ADSP21xx';
  SYNS_LangPHP                  =  'PHP';
  SYNS_LangSybaseSQL            =  'Sybase SQL';
  SYNS_LangGeneralMulti         =  'General Multi-Highlighter';
  SYNS_LangCache                =  'Cache Object script';
  SYNS_LangCSS                  =  'Cascading style sheets';
  SYNS_LangJScript              =  'Javascript';
  SYNS_LangKIX                  =  'KiXtart script';
  SYNS_LangBaan                 =  'Baan 4GL';
  SYNS_LangFoxpro               =  'Foxpro';
  SYNS_LangFortran              =  'Fortran';
  SYNS_Lang68HC11               =  '68HC11 assembler';
  SYNS_LangProgress             =  'Progress';
  SYNS_LangInno                 =  'Inno Setup script';
  SYNS_LangModelica             =  'Modelica';
  SYNS_LangModula3              =  'Modula 3';
  SYNS_LangSDD                  =  'Semanta data dictionary';
  SYNS_LangXML                  =  'XML document';
  SYNS_LangGWS                  =  'GW-TEL script';
  SYNS_LangSynGenMsgfiles       =  'SynGen Msg files';
  SYNS_LangUnreal               =  'Unreal';
  SYNS_LangTeX                  =  'TeX';
  SYNS_LangPo                   =  'po language files';
  SYNS_LangPike                 =  'Pike';
  SYNS_LangSh                   =  'UNIX Shell Script';

resourcestring

  SYNS_emcNone                     = 'No Action';
  SYNS_emcStartSelection           = 'Selection';
  SYNS_emcStartColumnSelections    = 'Column Selection';
  SYNS_emcStartLineSelections      = 'Line Selection';
  SYNS_emcStartLineSelectionsNoneEmpty = 'Line Selection (select immediate)';
  SYNS_emcSelection_opt            = 'Mode,Begin,Continue';
  SYNS_emcSelectWord               = 'Select Word';
  SYNS_emcSelectLine               = 'Select Line';
  SYNS_emcSelectLine_opt           = '"Include spaces",no,yes';
  SYNS_emcSelectPara               = 'Select Paragraph';
  SYNS_emcStartDragMove            = 'Drag Selection';
  SYNS_emcPasteSelection           = 'Quick Paste Selection';
  SYNS_emcMouseLink                = 'Source Link';
  SYNS_emcMouseLink_opt            = 'Underline,yes, no';
  SYNS_emcStartDragMove_opt        = '"Caret on up if not dragged",yes,no';
  SYNS_emcContextMenu              = 'Popup Menu';
  SYNS_emcBreakPointToggle         = 'Toggle Breakpoint';
  SYNS_emcCodeFoldCollaps          = 'Fold Code';
  SYNS_emcCodeFoldCollaps_opt      = 'Nodes,One,"All on line","At Caret","Current Node"';
  SYNS_emcCodeFoldExpand           = 'Unfold Code';
  SYNS_emcCodeFoldExpand_opt       = 'Nodes,One,"All on line"';
  SYNS_emcCodeFoldContextMenu      = 'Fold Menu';
  SYNS_emcSynEditCommand           = 'IDE Command';
  SYNS_emcWheelScrollDown          = 'Wheel scroll down';
  SYNS_emcWheelScrollUp            = 'Wheel scroll up';
  SYNS_emcWheelHorizScrollDown     = 'Wheel scroll down (Horizontal)';
  SYNS_emcWheelHorizScrollUp       = 'Wheel scroll up (Horizontal)';
  SYNS_emcWheelVertScrollDown      = 'Wheel scroll down (Vertical)';
  SYNS_emcWheelVertScrollUp        = 'Wheel scroll up (Vertical)';
  SYNS_emcWheelZoomOut             = 'Wheel zoom out';
  SYNS_emcWheelZoomIn              = 'Wheel zoom in';
  SYNS_emcWheelZoomNorm            = 'Wheel zoom default';
  SYNS_emcStartSelectTokens        = 'Selection (tokens) ';
  SYNS_emcStartSelectWords         = 'Selection (words)';
  SYNS_emcStartSelectLines         = 'Selection (lines)';
  SYNS_emcOverViewGutterGotoMark   = 'Jump to Mark (Overview Gutter)';
  SYNS_emcOverViewGutterScrollTo   = 'Scroll (Overview Gutter)';

  SYNS_emcContextMenuCaretMove_opt = '"Move caret, when selection exists", Never, "Click outside", Always';
  SYNS_emcWheelScroll_opt          = 'Speed,"System settings",Lines,Pages,"Pages (less one line)"';

  SYNS_emcPluginMultiCaretToggleCaret = 'Toggle extra caret';
  SYNS_emcPluginMultiCaretSelectionToCarets = 'Set carets at EOL in selected lines';

  //SynMacroRecorder
  sCannotRecord = 'Cannot record macro when recording';
  sCannotPlay = 'Cannot playback macro when recording';
  sCannotPause = 'Can only pause when recording';
  sCannotResume = 'Can only resume when paused';
implementation

end.

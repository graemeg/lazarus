{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit allsynedit;

{$warn 5023 off : no warning about unused units}
interface

uses
  SynBeautifier, SynCompletion, SynEdit, SynEditAutoComplete, SynEditExport, 
  SynEditFoldedView, SynEditHighlighter, SynEditHighlighterFoldBase, 
  SynEditHighlighterXMLBase, SynEditKeyCmds, LazSynEditMouseCmdsTypes, 
  SynHighlighterPo, SynEditLines, SynEditMarks, SynEditMarkup, 
  SynEditMarkupBracket, SynEditMarkupCtrlMouseLink, SynEditMarkupHighAll, 
  SynEditMarkupSelection, SynEditMarkupSpecialLine, SynEditMarkupWordGroup, 
  SynEditMiscClasses, SynEditMiscProcs, SynEditMouseCmds, SynEditPlugins, 
  SynEditPointClasses, SynEditRegexSearch, SynEditSearch, SynEditStrConst, 
  SynEditTextBase, SynEditTextBuffer, SynEditTextBidiChars, 
  SynEditTextTabExpander, SynEditTextTrimmer, SynEditTypes, SynExportHTML, 
  SynGutter, SynGutterBase, SynGutterChanges, SynGutterCodeFolding, 
  SynGutterLineNumber, SynGutterLineOverview, SynGutterMarks, 
  SynHighlighterAny, SynHighlighterCpp, SynHighlighterCss, SynHighlighterDiff, 
  SynHighlighterHashEntries, SynHighlighterHTML, SynHighlighterJava, 
  SynHighlighterJScript, SynHighlighterLFM, SynHighlighterMulti, 
  SynHighlighterPas, SynHighlighterPerl, SynHighlighterPHP, 
  SynHighlighterPosition, SynHighlighterPython, SynHighlighterSQL, 
  SynHighlighterTeX, synhighlighterunixshellscript, SynHighlighterVB, 
  SynHighlighterXML, SynMacroRecorder, SynMemo, SynPluginSyncroEdit, 
  SynPluginSyncronizedEditBase, SynPluginTemplateEdit, LazSynEditText, 
  LazSynTextArea, SynTextDrawer, SynEditMarkupGutterMark, SynHighlighterBat, 
  SynHighlighterIni, SynEditMarkupSpecialChar, SynEditTextDoubleWidthChars, 
  SynEditTextSystemCharWidth, SynEditMarkupIfDef, SynPluginMultiCaret, 
  synhighlighterpike, SynEditMarkupFoldColoring, SynEditViewedLineMap, 
  SynEditWrappedView, SynBeautifierPascal, LazSynIMMBase, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('SynEdit', @SynEdit.Register);
end;

initialization
  RegisterPackage('SynEdit', @Register);
end.

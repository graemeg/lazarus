
{*****************************************}
{                                         }
{             FastReport v2.3             }
{           Resource constants            }
{                                         }
{  Copyright (c) 1998-99 by Tzyganenko A. }
{                                         }
{*****************************************}

unit LR_Const;

interface

{$I LR_vers.inc}


resourcestring
//--- ShapeForm resources
  sShapeFormCaption='Shape';
  sShapeFormKind   ='Shape kind';
  
//--- RoundRectForm resources -------------------------------------------------
  sRoundRectFormCaption='Property editor';
  sRoundRectFormSample='Sample :';
  sRoundRectFormVar='Variables ...';
  sRoundRectFormData='Data ..';
  sRoundRectFormGradient='Gradient';
  sRoundRectFormShadow='Shadow width';
  sRoundRectFormColor='Color';
  sRoundRectFormCurve='Curve';
  sRoundRectFormFramed='Framed zone';
  sRoundRectFormEndColor='End Color';
  sRoundRectFormBeginColor='Begin color';
  sRoundRectFormStyle='Style';
  sRoundRectFormStyleDif='Vertical,Horizontal,Elliptic,Rectangle,Horiz._Center,Vert._Center';
  sRoundRectFormHint='Click here to define the shadow color or gradient colors';
  sRoundRectSqrCorners='Squared corners';

//--- PgoptForm resources -----------------------------------------------------
  sPgoptFormCapt = 'Page options';
  sPgoptFormPaper = 'Paper';
  sPgoptFormOr = 'Orientation';
  sPgoptFormPort = '&Portrait';
  sPgoptFormLand = '&Landscape';
  sPgoptFormSize = 'Size';
  sPgoptFormWidth = '&Width, mm';
  sPgoptFormHeight = '&Height, mm';
  sPgoptFormMargins = 'Margins';
  sPgoptFormPgMargins = 'Page margins';
  sPgoptFormLeft = '&Left, mm';
  sPgoptFormTop = '&Top, mm';
  sPgoptFormRight = '&Right, mm';
  sPgoptFormBottom = '&Bottom, mm';
  sPgoptFormDontUse = '&Don''t use';
  sPgoptFormOptions = 'Options';
  sPgoptFormpRINT = '&Print to previous page';
  sPgoptFormColumn = 'Columns';
  sPgoptFormNumber = '&Number';
  sPgoptFormColGap = '&Column gap, mm';
  sPgoptFormLayoutOrder = 'Layout Order';
  sPgoptFormByColumns = 'By Colum&ns';
  sPgoptFormByRows = 'By Row&s';
  sPgoptFormInvalidCustomPaperSize = 'Invalid custom paper size.';

//--- EditorForm resources ----------------------------------------------------
  sEditorFormCapt = 'Text editor';
  sEditorFormMemo = '&Memo';
  sEditorFormScript = '&Script';
  sEditorFormBig = '&Big font';
  sEditorFormWord = '&Word wrap';
  sEditorFormScr = 'S&cript';
  sEditorFormVar = '&Variable';
  sEditorFormField = '&DB field';
  sEditorFormFormat = '&Format';
  sEditorFormFunction = 'Function';

//--- DesOptionsForm resources ------------------------------------------------
  sDesOptionsFormOpt = 'Options';
  sDesOptionsFormDes = 'Designer';
  sDesOptionsFormGrid = 'Grid';
  sDesOptionsFormObj = 'Object moving';
  sDesOptionsFormUnits = 'Report units';
  sDesOptionsFormGrdSize = 'Grid size';
  sDesOptionsFormShowGrd = '&Show grid';
  sDesOptionsFormAlignGrd = 'Align to &grid';
  sDesOptionsFormColoredButton = 'Colored &buttons';
  sDesOptionsForm4Pix = '&4 pixels';
  sDesOptionsForm8Pix = '&8 pixels';
  sDesOptionsForm18pix = '&18 pixels (5mm)';
  sDesOptionsFormShape = 'S&hape';
  sDesOptionsFormContents = '&Contents';
  sDesOptionsFormPix = '&Pixels';
  sDesOptionsFormmm = '&MM';
  sDesOptionsFormInch = '&Inches';
  sDesOptionsFormOther = 'Other';
  sDesOptionsFormEditing = '&Editing after insert';
  sDesOptionsFormShowBand = 'Show band &titles';
  sDesOptionsFormInPlace = 'Use inplace editor';

//--- HilightForm resources ---------------------------------------------------
  sHilightFormHilitAttr = 'Highlight attributes';
  sHilightFormCond = 'Condition';
  sHilightFormFont = 'Font';
  sHilightFormColor = 'C&olor ...';
  sHilightFormBold = '&Bold';
  sHilightFormItalic = '&Italic';
  sHilightFormUnder = '&Underline';
  sHilightFormBack = 'Background';
  sHilightFormColor2 = 'Co&lor ...';
  sHilightFormTransp = '&Transparent';
  sHilightFormOther = 'Ot&her';

//--- FieldsForm resources ----------------------------------------------------
  sFieldsFormInsert = 'Insert DB field';
  sFieldsFormAviableDB = '&Available DB''s';

//--- DocOptForm resources ----------------------------------------------------
  sDocOptFormOpt        = 'Report options';
  sDocOptFormPrinter    = 'Printer';
  sDocOptFormSelect     = '&Select when report loaded';
  sDocOptFormOther      = 'Other';
  sDocOptForm2Pass      = '&Two-pass report';
  sDocOptFormTitle      = 'Title';
  sDocOptFormSubject    = 'Subject';
  sDocOptFormKeyWords   = 'Keywords';
  sDocOptFormComments   = 'Comments';
  sDocVersion           = 'Version';
  sDocMajor             = 'Major';
  sDocMinor             = 'Minor';
  sDocRelease           = 'Release';
  sDocBuild             = 'Build';
  sDocAutor             = 'Author';
  sReportCreateDate     = 'Report creation date';
  sReportLastModifyDate = 'Report last modification date';
  
  
//--- EvForm resources --------------------------------------------------------
  sEvFormCapt = 'Variables editor';
  sEvFormVar = '&Variable';
  sEvFormValue = 'Va&lue';
  sEvFormExp = '&Expression';
  sEvFormCopy = 'Copy variables';
  sEvFormPaste = 'Paste variables';
  sEvFormVars = 'Va&riables ...';

//--- VaredForm resources -----------------------------------------------------
  sVaredFormCapt = 'Variables list';
  sVaredFormCat = '&Categories and variables';

//--- TemplForm resources -----------------------------------------------------
  sTemplFormNewRp = 'New report';
  sTemplFormDesc  = 'Description';
  sNewTemplate    = 'New template';
  sTemplEmtpyRp   = 'Empty template';
  sTemplEmptyDesc = 'New report based on empty template';

//--- GEditorForm resources ---------------------------------------------------
  sGEditorFormCapt = 'Picture';
  sGEditorFormStretch = '&Stretch';
  sGEditorFormLoad = '&Load ...';
  sGEditorFormClear = '&Clear';
  sGEditorFormMemo = '&Memo';

//--- VarForm resources -------------------------------------------------------
  sVarFormCapt = 'Variables';
  sVarFormCat = '&Category:';

//--- Object names ------------------------------------------------------------
  sBand1  = 'Report title';
  sBand2  = 'Report summary';
  sBand3  = 'Page header';
  sBand4  = 'Page footer';
  sBand5  = 'Master header';
  sBand6  = 'Master data';
  sBand7  = 'Master footer';
  sBand8  = 'Detail header';
  sBand9  = 'Detail data';
  sBand10 = 'Detail footer';
  sBand11 = 'Subdetail header';
  sBand12 = 'Subdetail data';
  sBand13 = 'Subdetail footer';
  sBand14 = 'Overlay';
  sBand15 = 'Column header';
  sBand16 = 'Column footer';
  sBand17 = 'Group header';
  sBand18 = 'Group footer';
  sBand19 = 'Cross header';
  sBand20 = 'Cross data';
  sBand21 = 'Cross footer';
  sBand22 = 'Child';
  sBand23 = 'None';

  sVar1 = 'Page#';
  sVar2 = 'Expression';
  sInsert = 'Insert';
  sDBField = 'DB field';
  sVariable = 'Variable';
  sVar3 = 'Date';
  sVar4 = 'Time';
  sVar5 = 'Line#';
  sVar6 = 'Line through#';
  sVar7 = 'Column#';
  sVar8 = 'Current line#';
  sVar9 = 'TotalPages';

//--- General resources -------------------------------------------------------
  sOk = 'Ok';
  sCancel = 'Cancel';
  sYes = 'Yes';
  sNo = 'No';
  sPg = 'Page';
  sRepFile = 'Report file';
  sRemovePg = 'Remove this page?';
  sConfirm = 'Confirm';
  sStretched = 'Stretched';
  sVarFormat = 'Variable format ...';
  sFont = 'Font ...';

  sWordWrap       = 'Word wrap';
  sWordBreak      = 'Word break';
  sAutoSize       = 'Auto size';
  sHideZeroValues = 'Hide zero values';

  sCharset  = '0';
  sNotAssigned = '[None]';
  sFormNewPage = 'Force new page';
  sPrintIfSubsetEmpty = 'Print if detail empty';
  sPrintChildIfNotVisible = 'Print child if not visible';
  sBreaked = 'Breaked';
  sKeepChild = 'Keep child together with parent';
  sPictureCenter = 'Center picture';
  sKeepAspectRatio = 'Keep aspect ratio';

  sFormFile        = 'FastReport form';
  sTemplFile       = 'FastReport template';
  sLazFormFile     = 'LazReport form';
  sLazTemplateFile = 'LazReport template';

  sPictFile = 'Picture file';
  sBMPFile = 'Bitmap file';
  sAllFiles = 'All files';
  sInsCheckBox = 'Insert CheckBox object';
  sInsChart = 'Insert Chart object';
  sInsShape = 'Insert Shape object';
  sInsBarcode = 'Insert Barcode object';
  sInsCrossTab = 'Insert Cross-tab object';
  sInsRoundRect = 'Insert a RoundRect with shadow area';
  sSubReportOnPage = 'SubReport on page';
  sPicture = '[Picture]';
  sTransparent = 'Transparent';
  sOther = 'Other ...';
  sOnFirstPage = 'On first page';
  sOnLastPage = 'On last page';
  sRepeatHeader = 'Show on all pages';
  sDesignReport = 'Design report';
  sInsertFields = 'Insert DB fields';
  sSaveChanges = 'Save changes';
  sTo = 'to';
  sShape1 = 'Rectangle';
  sShape2 = 'Rounded rectangle';
  sShape3 = 'Ellipse';
  sShape4 = 'Triangle';
  sShape5 = 'Diagonal1';
  sShape6 = 'Diagonal2';
  sPixels = 'Pixels';
  sMM = 'MM';
  sInches = 'Inches';
  sVirtualDataset = 'Virtual Dataset';
  sFRVariables = 'FR variables';
  sErrorOccurred = 'An error occurred during calculation';
  sSpecVal = 'Other';
  sInvalidFRFReport = 'Invalid binary report';
  sInvalidLRFReport = 'Invalid report format';
  sUnableToReadVersion = 'Unable to read report version';
  sInvalidFRFVersion = 'Invalid report version';
  sReportLoadingError = 'Error while loading report';
  sClassObjectNotFound = 'Class Object "%s" not found';
  sDuplicatedObjectName = 'An object named "%s" already exists';
  sObjectNotFound = 'Object "%s" not found';
  sFileNotFound = 'File not found';
  sNoValidFilterClassWasSupplied    = 'No valid filterclass was supplied';
  sNoValidExportFilenameWasSupplied = 'No valid export filename was supplied';
  
  SDoc       = 'Report:';
  SBand      = 'Band:';
  sCurMemo   = 'Memo:';
  SReportPreparing = 'Preparing report';
  SFirstPass = 'Performing 1st pass:';
  SPagePreparing = 'Processing page:';
  SError = 'Error';
  SPreview = 'Preview';
  SPagePrinting = 'Printing page:';
  SUntitled = 'Untitled';
  SPrinterError = 'Selected printer is not valid';
  STextFile = 'ASCII Text file';
  SRTFFile = 'Rich Text file';
  SCSVFile = 'CSV File';
  SHTMFile = 'HTML file';
  SFilter = 'Filter properties';
  SFilterParam = 'Average font height:';
  sFrom = 'from';
  sDefaultPrinter = 'Default printer';
  sExportFilterIndexError = 'Export filter index out of range';
  sFindTextNotFound = 'Search text not found.';
  sInvalidVariableName = '"%s" is not a valid variable name.';

//--- PrintForm resources ---------------------------------------------------
  sPrintFormPrint = 'Print';
  sPrintFormPrinter = 'Printer';
  sPrintFormProp = 'Properties';
  sPrintFormCopy = '&Copies:';
  sPrintFormPgRange = 'Page range';
  sPrintFormAll = '&All';
  sPrintFormCurPg = 'Current &page';
  sPrintFormNumber= '&Numbers:';
  sPrintFormInfo = 'Enter page numbers and/or page ranges, separated by commas. For example, 1,3,5-12';
  sPrintFormCollate = 'Collate';

//--- BandEditorForm resources ------------------------------------------------
  sBandEditorFormCapt = 'Band data source';
  sBandEditorFormDataSrc = 'Data source';
  sBandEditorFormRecCount = '&Record count';

//--- BandTypesForm resources -------------------------------------------------
  sBandTypesFormCapt = 'Insert new band';
  sBandTypesFormBType ='Band type';

//--- GroupEditorForm resources -----------------------------------------------
  sGroupEditorFormCapt = 'Group';
  sGroupEditorFormCond = 'Condition';
  sGroupEditorFormAddDbField = 'Insert DB field';

//--- InsertFieldsForm resources ----------------------------------------------
  sInsertFieldsFormCapt = 'Insert fields';
  sInsertFieldsFormAviableDSet = '&Available datasets';
  sInsertFieldsFormPlace = 'Placement';
  sInsertFieldsFormHorz = '&Horizontal';
  sInsertFieldsFormVert = '&Vertical';
  sInsertFieldsFormHeader = '&Include headers';
  sInsertFieldsFormBand = 'Include &bands';

//--- AboutForm resources -----------------------------------------------------
  sAboutFormCapt = 'About FastReport';

//---- Paper Src --------------------------------------------------------------
  sPaper1 = 'Letter, 8 1/2 x 11"';
  sPaper2 = 'Letter small, 8 1/2 x 11"';
  sPaper3 = 'Tabloid, 11 x 17"';
  sPaper4 = 'Ledger, 17 x 11"';
  sPaper5 = 'Legal, 8 1/2 x 14"';
  sPaper6 = 'Statement, 5 1/2 x 8 1/2"';
  sPaper7 = 'Executive, 7 1/4 x 10 1/2"';
  sPaper8 = 'A3 297 x 420 mm';
  sPaper9 = 'A4 210 x 297 mm';
  sPaper10 = 'A4 small sheet, 210 x 297 mm';
  sPaper11 = 'A5 148 x 210 mm';
  sPaper12 = 'B4 250 x 354 mm';
  sPaper13 = 'B5 182 x 257 mm';
  sPaper14 = 'Folio, 8 1/2 x 13"';
  sPaper15 = 'Quarto Sheet, 215 x 275 mm';
  sPaper16 = '10 x 14"';
  sPaper17 = '11 x 17"';
  sPaper18 = 'Note, 8 1/2 x 11"';
  sPaper19 = '9 Envelope, 3 7/8 x 8 7/8"';
  sPaper20 = '#10 Envelope, 4 1/8  x 9 1/2"';
  sPaper21 = '#11 Envelope, 4 1/2 x 10 3/8"';
  sPaper22 = '#12 Envelope, 4 3/4 x 11"';
  sPaper23 = '#14 Envelope, 5 x 11 1/2"';
  sPaper24 = 'C Sheet, 17 x 22"';
  sPaper25 = 'D Sheet, 22 x 34"';
  sPaper26 = 'E Sheet, 34 x 44"';
  sPaper27 = 'DL Envelope, 110 x 220 mm';
  sPaper28 = 'C5 Envelope, 162 x 229 mm';
  sPaper29 = 'C3 Envelope,  324 x 458 mm';
  sPaper30 = 'C4 Envelope,  229 x 324 mm';
  sPaper31 = 'C6 Envelope,  114 x 162 mm';
  sPaper32 = 'C65 Envelope, 114 x 229 mm';
  sPaper33 = 'B4 Envelope,  250 x 353 mm';
  sPaper34 = 'B5 Envelope,  176 x 250 mm';
  sPaper35 = 'B6 Envelope,  176 x 125 mm';
  sPaper36 = 'Italy Envelope, 110 x 230 mm';
  sPaper37 = 'Monarch Envelope, 3 7/8 x 7 1/2"';
  sPaper38 = '6 3/4 Envelope, 3 5/8 x 6 1/2"';
  sPaper39 = 'US Std Fanfold, 14 7/8 x 11"';
  sPaper40 = 'German Std Fanfold, 8 1/2 x 12"';
  sPaper41 = 'German Legal Fanfold, 8 1/2 x 13"';
  sPaper42 = 'B4 (ISO) 250 x 353 mm';
  sPaper43 = 'Japanese Postcard 100 x 148 mm';
  sPaper44 = '9 x 11"';
  sPaper45 = '10 x 11"';
  sPaper46 = '15 x 11"';
  sPaper47 = 'Envelope Invite 220 x 220 mm';
  sPaper50 = 'Letter Extra 9/275 x 12"';
  sPaper51 = 'Legal Extra 9/275 x 15"';
  sPaper52 = 'Tabloid Extra 11.69 x 18"';
  sPaper53 = 'A4 Extra 9.27 x 12.69"';
  sPaper54 = 'Letter Transverse 8/275 x 11"';
  sPaper55 = 'A4 Transverse 210 x 297 mm';
  sPaper56 = 'Letter Extra Transverse 9/275 x 12"';
  sPaper57 = 'SuperASuperAA4 227 x 356 mm';
  sPaper58 = 'SuperBSuperBA3 305 x 487 mm';
  sPaper59 = 'Letter Plus 8.5 x 12.69"';
  sPaper60 = 'A4 Plus 210 x 330 mm';
  sPaper61 = 'A5 Transverse 148 x 210 mm';
  sPaper62 = 'B5 (JIS) Transverse 182 x 257 mm';
  sPaper63 = 'A3 Extra 322 x 445 mm';
  sPaper64 = 'A5 Extra 174 x 235 mm';
  sPaper65 = 'B5 (ISO) Extra 201 x 276 mm';
  sPaper66 = 'A2 420 x 594 mm';
  sPaper67 = 'A3 Transverse 297 x 420 mm';
  sPaper68 = 'A3 Extra Transverse 322 x 445 mm';
  // new papers
  sPaper69 = 'Double Japanese Postcard 200 x 148 mm';
  sPaper70 = 'A6 105x148 mm';
  sPaper71 = 'DMPAPER_JENV_KAKU2 240X132';
  sPaper72 = 'DMPAPER_JENV_KAKU3 216X277';
  sPaper73 = 'DMPAPER_JENV_CHOU3 120X235';
  sPaper74 = 'DMPAPER_JENV_CHOU4 90X205';
  sPaper75 = 'DMPAPER_LETTER_ROTATED 279.4x215.9';
  sPaper76 = 'DMPAPER_A3_ROTATED 420x297';
  sPaper77 = 'DMPAPER_A4_ROTATED 297X210';
  sPaper78 = 'DMPAPER_A5_ROTATED 210X148';
  sPaper79 = 'DMPAPER_B4_JIS_ROTATED 364X257';
  sPaper80 = 'DMPAPER_B5_JIS_ROTATED 257X182';
  sPaper81 = 'DMPAPER_JAPANESE_POSTCARD_ROTATED 148X100';
  sPaper82 = 'DMPAPER_DBL_JAPANESE_POSTCARD_ROTATED 148X200';
  sPaper83 = 'DMPAPER_A6_ROTATED 148X105';
  sPaper84 = 'DMPAPER_JENV_KAKU2_ROTATED 332X240';
  sPaper85 = 'DMPAPER_JENV_KAKU3_ROTATED 277X216';
  sPaper86 = 'DMPAPER_JENV_CHOU3_ROTATED 235X120';
  sPaper87 = 'DMPAPER_JENV_CHOU4_ROTATED 205X90';
  sPaper88 = 'DMPAPER_B6_JIS 128X122';
  sPaper89 = 'DMPAPER_B6_JIS_ROTATED 182X128';
  sPaper90 = 'DMPAPER_12X11 304.8X279.4';
  sPaper91 = 'DMPAPER_JENV_YOU4 105X235';
  sPaper92 = 'DMPAPER_JENV_YOU4_ROTATED 235X105';
  sPaper93 = 'DMPAPER_P16K 146X215';
  sPaper94 = 'DMPAPER_P32K 97X151';
  sPaper95 = 'DMPAPER_P32KBIG 97X151';
  sPaper96 = 'DMPAPER_PENV_1 102X165';
  sPaper97 = 'DMPAPER_PENV_2 102X176';
  sPaper98 = 'DMPAPER_PENV_3 125X176';
  sPaper99 = 'DMPAPER_PENV_4 110X208';
  sPaper100= 'DMPAPER_PENV_5 110X220';
  sPaper101= 'DMPAPER_PENV_6 120X230';
  sPaper102= 'DMPAPER_PENV_7 160X230';
  sPaper103= 'DMPAPER_PENV_8 120X309';
  sPaper104= 'DMPAPER_PENV_9 229X324';
  sPaper105= 'DMPAPER_PENV_10 324X458';
  sPaper106= 'DMPAPER_P16K_ROTATED 215X146';
  sPaper107= 'DMPAPER_P32K_ROTATED 151X97';
  sPaper108= 'DMPAPER_P32KBIG_ROTATED 151X97';
  sPaper109= 'DMPAPER_PENV_1_ROTATED 165X102';
  sPaper110= 'DMPAPER_PENV_2_ROTATED 176X102';
  sPaper111= 'DMPAPER_PENV_3_ROTATED 176X125';
  sPaper112= 'DMPAPER_PENV_4_ROTATED 208X110';
  sPaper113= 'DMPAPER_PENV_5_ROTATED 220X110';
  sPaper114= 'DMPAPER_PENV_6_ROTATED 230X120';
  sPaper115= 'DMPAPER_PENV_7_ROTATED 230X160';
  sPaper116= 'DMPAPER_PENV_8_ROTATED 309X120';
  sPaper117= 'DMPAPER_PENV_9_ROTATED 324X229';
  sPaper118= 'DMPAPER_PENV_10_ROTATED 458X324';
  sPaper256 = 'Custom';

//--- FRDesignerForm resources ------------------------------------------------
  sFRDesignerFormCapt = 'Designer';
  sFRDesignerFormrect = 'Rectangle';
  sFRDesignerFormStd = 'Standard';
  sFRDesignerFormText = 'Text';
  sFRDesignerFormObj = 'Objects';
  sFRDesignerFormAlign = 'Alignment';
  sFRDesignerFormTools = 'Tools';
  sFRDesignerFormNewRp = 'New report';
  sFRDesignerFormOpenRp = 'Open report';
  sFRDesignerFormSaveRp = 'Save report';
  sFRDesignerFormPreview = 'Preview report';
  sFRDesignerFormCut = 'Cut';
  sFRDesignerFormCopy = 'Copy';
  sFRDesignerFormPast = 'Paste';
  sFRDesignerFormUndo = 'Undo last action';
  sFRDesignerFormRedo = 'Redo cancelled action';
  sFRDesignerFormBring = 'Bring to front';
  sFRDesignerFormBack = 'Send to back';
  sFRDesignerFormSelectAll = 'Select all';
  sFRDesignerFormAddPg = 'Add page';
  sFRDesignerFormRemovePg = 'Remove page';
  sFRDesignerFormPgOption = 'Page options';
  sFRDesignerFormGrid = 'Grid';
  sFRDesignerFormGridAlign = 'Grid align';
  sFRDesignerFormFitGrid = 'Fit to grid';
  sFRDesignerFormClose = 'Close';
  sFRDesignerFormCloseDesigner = 'Close designer';
  sFRDesignerFormLeftAlign = 'Left align';
  sFRDesignerFormRightAlign = 'Right align';
  sFRDesignerFormCenerAlign = 'Center align';
  sFRDesignerFormNormalText = 'Normal text / 90 degrees';
  sFRDesignerFormVertCenter = 'Vertical center';
  sFRDesignerFormTopAlign = 'Top align';
  sFRDesignerFormBottomAlign = 'Bottom align';
  sFRDesignerFormWidthAlign = 'Width align';
  sFRDesignerFormBold = 'Bold';
  sFRDesignerFormItalic = 'Italic';
  sFRDesignerFormUnderLine = 'Underline';
  sFRDesignerFormFont = 'Font color';
  sFRDesignerFormHightLight = 'Highlight attributes';
  sFRDesignerFormFontSize = 'Font size';
  sFRDesignerFormFontName = 'Font name';
  sFRDesignerFormTopFrame = 'Top frame line';
  sFRDesignerFormleftFrame = 'Left frame line';
  sFRDesignerFormBottomFrame = 'Bottom frame line';
  sFRDesignerFormRightFrame = 'Right frame line';
  sFRDesignerFormAllFrame = 'All frame lines';
  sFRDesignerFormNoFrame = 'No frame';
  sFRDesignerFormBackColor = 'Background color';
  sFRDesignerFormFrameColor = 'Frame color';
  sFRDesignerFormFrameWidth = 'Frame width';
  sFRDesignerFormSelectSameClass = 'Select same class objects';
  //  53131 = 'Frame width';
  sFRDesignerFormSelObj = 'Select object';
  sFRDesignerFormInsRect = 'Insert rectangle object';
  sFRDesignerFormInsBand = 'Insert band';
  sFRDesignerFormInsPict = 'Insert picture';
  sFRDesignerFormInsSub = 'Insert subreport';
  sFRDesignerFormDrawLine = 'Draw lines';
  sFRDesignerFormAlignLeftedge = 'Align left edges';
  sFRDesignerFormAlignHorzCenter = 'Align horizontal centers';
  sFRDesignerFormCenterHWind = 'Center horizontally in window';
  sFRDesignerFormSpace = 'Space equally, horizontally';
  sFRDesignerFormAlignRightEdge = 'Align right edges';
  sFRDesignerFormAligneTop = 'Align tops';
  sFRDesignerFormAlignVertCenter = 'Align vertical centers';
  sFRDesignerFormCenterVertWing = 'Center vertically in window';
  sFRDesignerFormSpaceEqVert = 'Space equally, vertically';
  sFRDesignerFormAlignBottoms = 'Align bottoms';
  sFRDesignerForm_Cut = 'C&ut';
  sFRDesignerForm_Copy = '&Copy';
  sFRDesignerForm_Paste = '&Paste';
  sFRDesignerForm_Delete = '&Delete';
  sFRDesignerForm_SelectAll = 'Select &all';
  sFRDesignerForm_Edit = '&Edit ...';
  sFRDesignerForm_File = '&File';
  sFRDesignerForm_New = '&New ...';
  sFRDesignerForm_Open = '&Open ...';
  sFRDesignerForm_Save = '&Save';
  sFRDesignerForm_Var = 'Variables &list ...';
  sFRDesignerForm_RptOpt = '&Report options ...';
  sFRDesignerForm_PgOpt = '&Page options ...';
  sFRDesignerForm_preview = 'Pre&view';
  sFRDesignerForm_Exit = 'E&xit';
  sFRDesignerForm_Edit2 = '&Edit';
  sFRDesignerForm_Undo = '&Undo';
  sFRDesignerForm_Redo = '&Redo';
  //sFRDesignerForm_Cut = 'C&ut';
  //sFRDesignerForm_Copy = '&Copy';
  //sFRDesignerForm_Paste = '&Paste';
  //sFRDesignerForm_Delete = '&Delete';
  //sFRDesignerForm_SelectAll = '&Select all';
  sFRDesignerForm_Editp = '&Edit ...';
  sFRDesignerForm_AddPg = '&Add page';
  sFRDesignerForm_RemovePg = '&Remove page';
  sFRDesignerForm_Bring = 'Bring to &front';
  sFRDesignerForm_Back = 'Send to &back';
  sFRDesignerForm_Tools = '&Tools';
  sFRDesignerForm_ToolBars = '&Toolbars';
  sFRDesignerForm_Tools2 = 'Too&ls';
  sFRDesignerForm_Opts = '&Options ...';
  sFRDesignerForm_Rect = '&Rectangle';
  sFRDesignerForm_Std = '&Standard';
  sFRDesignerForm_Text = '&Text';
  sFRDesignerForm_Obj = '&Objects';
  sFRDesignerForm_Insp = 'Object &Inspector';
  sFRDesignerForm_AlignPalette = '&Alignment palette';
  sFRDesignerForm_Tools3 = 'Too&ls';
  sFRDesignerForm_DataInsp = '&Data inspector';
  sFRDesignerForm_About = '&About ...';
  sFRDesignerForm_SaveAs = 'Save &as ...';
  sFRDesignerForm_BeforePrintScript = '&Before print script ...';
  sFRDesignerForm_Help1 = '&Help contents';
  sFRDesignerForm_Help2 = 'Help &tool';
  sFRDesignerForm_Line = 'Line style';
  sFRDesignerForm_Modified = 'Modified';
  sFRDesignerExists        = 'You already have one TfrDesigner component';
  sFRDesignerDataInsp      = 'Data inspector';
  sFrDesignerFormUnableToCreateTemplateDir = 'Unable to create template directory';

//--- InspForm resources ------------------------------------------------------
  sObjectInspector ='Object inspector';

//--- VBandEditorForm resources ------------------------------------------------
  sVBandEditorFormCapt = 'Band data sources';
  sVBandEditorFormBnd = 'Bands';
  sVBandEditorFormDataSource = 'Data source';
  sVBandEditorFormRecordCount = '&Record count';

//--- FmtForm resources -------------------------------------------------------
  sFmtFormFrmtVar = 'Variable formatting';
  sFmtFormVarFmt = 'Variable format';
  sFmtFormDeciD = '&Decimal digits';
  sFmtFormFrac = 'Fraction &symbol';
  sFmtFormFrmt = '&Format';

  sCateg1 = 'Text';
  sCateg2 = 'Number';
  sCateg3 = 'Date';
  sCateg4 = 'Time';
  sCateg5 = 'Boolean';

  sFormat11 ='[None]';

  sFormat21 ='1234,5';
  sFormat22 ='1234,50';
  sFormat23 ='1 234,5';
  sFormat24 ='1 234,50';
  sFormat25 ='Custom';

  sFormat31 = '11.15.98';
  sFormat32 = '11.15.1998';
  sFormat33 = '15 nov 1998';
  sFormat34 = '15 november 1998';
  sFormat35 = 'Custom';

  sFormat41 = '02:43:35';
  sFormat42 = '2:43:35';
  sFormat43 = '02:43';
  sFormat44 = '2:43';
  sFormat45 = 'Custom';
  
  sFormat51 = '0;1';
  sFormat52 = 'No;Yes';
  sFormat53 = '_;x';
  sFormat54 = 'False;True';
  sFormat55 = 'Custom';
{
  sDateFormat1 = 'mm.dd.yy';
  sDateFormat2 = 'mm.dd.yyyy';
  sDateFormat3 = 'd mmm yyyy';
  sDateFormat4 = 'd mmmm yyyy';

  sTimeFormat1 = 'hh:nn:ss';
  sTimeFormat2 = 'h:nn:ss';
  sTimeFormat3 = 'hh:nn';
  sTimeFormat4 = 'h:nn';
}
//--- PreviewSearchForm resources ---------------------------------------------
  sFindTextCaption='Find text';
  sFindTextText='Text to &find';
  sFindTextOptions='Options';
  sFindTextCase='&Case sensitive';
  sFindTextOrg='Origin';
  sFindTextFirstPg='&1st page';
  sFindTextCurrentPg='Current &page';

//--- PreviewForm resources ---------------------------------------------------
  sPreviewFormPW='&Page width';
  sPreviewFormWhole='&Whole page';
  sPreviewForm2Pg='&Two pages';
  sPreviewFormClose='Close preview';
  sPreviewFormScale='Scale';
  sPreviewFormOpen='Open report';
  sPreviewFormSave='Save report';
  sPreviewFormPrint='Print report';
  sPreviewFormFind='Find text';
  sPreviewFormEdit='Edit page';
  sPreviewFormAdd='Add page';
  sPreviewFormDel='Delete page';
  sPreviewFormHelp='Show help';

//--- BarCodeForm resources ---------------------------------------------------
  sBarCodeFormTitle='Barcode editor';
  sBarCodeFormCode='&Code';
  sBarCodeFormType='&Type of barcode';
  sBarCodeFormOpts='Options';
  sBarCodeFormChksum='Check&sum';
  sBarCodeFormReadable='&Human readable';
  sBarCodeFormDbFld='Insert DB field';
  sBarCodeFormVar='Insert variable';
  sBarCodeFormRotate='Rotation';
  SBarcodeError = 'Error in barcode';
  sBarcodeZoom  = 'Zoom';
  
//--- Descriptions ------------------------------------------------------------
  SAggregateCategory = 'Aggregate';
  SDateTimeCategory  = 'Date and time';
  SStringCategory    = 'String';
  SOtherCategory     = 'Other';
  SMathCategory      = 'Math';
  SInterpretator     = 'Interpretator';

  SDescriptionAVG = 'AVG(<Expression> [,BandName [,1]])/' +
    'Calculates the average of <Expression> for [BandName] row given. '+
    'If [1] parameter is used, calculates average for non-visible rows too.';

  SDescriptionCOUNT = 'COUNT(<BandName>)/'+
    'Returns count of data rows given in the <BandName>. ';

  SDescriptionDAYOF =  'DAYOF(<Date>)/'+
    'Returns day number (1..31) of given <Date>.';

  SDescriptionFORMATDATETIME = 'FORMATDATETIME(<Fmt>, <DateTime>)/'+
    'Converts a <DateTime> value to a string using mask in <Fmt>.';

  SDescriptionFORMATFLOAT = 'FORMATFLOAT(<Fmt>, <Numeric>)/'+
    'Converts a <Numeric> value to a string using mask in <Fmt>.';

  SDescriptionFORMATTEXT = 'FORMATTEXT(<Mask>, <String>)/'+
    'Applies <Mask> to given <String> and returns formatted string.';

  SDescriptionINPUT = 'INPUT(<Caption> [,Default])/'+
    'Shows dialog window with title <Caption> and edit box. '+
    'If [Default] parameter is set, puts this string in edit box. '+
    'After user clicks OK, returns input string.';

  SDescriptionLENGTH = 'LENGTH(<String>)/'+
    'Returns length of <String>.';

  SDescriptionLOWERCASE =  'LOWERCASE(<String>)/'+
    'Converts <String> symbols to lower case.';

  SDescriptionMAX = 'MAX(<Expression> [,BandName [,1]])/'+
    'Calculates the maximum of <Expression> for [BandName] row given. '+
    'If [1] parameter is used, calculates maximum for non-visible rows too.';

  SDescriptionMIN = 'MIN(<Expression> [,BandName [,1]])/'+
    'Calculates the minimum of <Expression> for [BandName] row given. '+
    'If [1] parameter is used, calculates minimum for non-visible rows too.';

  SDescriptionMONTHOF = 'MONTHOF(<Date>)/'+
    'Returns month number (1..12) of given <Date>.';

  SDescriptionNAMECASE = 'NAMECASE(<String>)/'+
    'Converts <String> symbols to lower case, and first symbol '+
    'is in upper case.';

  SDescriptionSTRTODATE = 'STRTODATE(<String>)/'+
    'Converts <String> to date.';

  SDescriptionSTRTOTIME = 'STRTOTIME(<String>)/' +
    'Converts <String> to time.';

  SDescriptionSUM = 'SUM(<Expression> [,BandName [,1]])/'+
    'Calculates the sum of <Expression> for [BandName] row given. '+
    'If [1] parameter is used, calculates sum for non-visible rows too.';

  SDescriptionTRIM = 'TRIM(<String>)/'+
    'Trims all heading and trailing spaces in <String> and returns '+
    'resulting string.';

  SDescriptionUPPERCASE = 'UPPERCASE(<String>)/'+
    'Converts <String> symbols to upper case.';

  SDescriptionYEAROF = 'YEAROF(<Date>)/'+
    'Returns year of given <Date>.';
    
  SDescriptionMAXNUM = 'MAXNUM(<Value1>, <Value2>)/'+
    'Returns max of given values.';

  SDescriptionMINNUM = 'MINNUM(<Value1>, <Value2>)/'+
    'Returns min of given values.';

  SDescriptionPOS = 'POS(<SubString>, <String>)/'+
    'Returns position of substring in given string.';

  SDescriptionMESSAGEBOX = 'MESSAGEBOX(<Text>, <Title>, <Buttons>)/'+
    'Shows standard dialog window with title, text and buttons.';

  SDescriptionCOPY = 'COPY(<String>, <Position>, <Length>)/'+
    'Returns <Length> characters from <String> starting at <Position>.';

  SDescriptionSTR = 'STR(<Value>)/'+
    'Converts the given (numeric) <Value> in string.';

  SDescriptionINT = 'INT(<Value>)/'+
    'Returns the integer part of floating point <Value>.';

  SDescriptionROUND = 'ROUND(<Value>)/'+
    'Rounds the floating point <Value> to nearest integer number.';

  SDescriptionFRAC = 'FRAC(<Value>)/'+
    'Returns the fractional part of floating point <Value>.';

  SDescriptionNEWPAGE = 'NEWPAGE/'+
    'Create new page for current report.';
  SDescriptionNEWCOLUMN =  'NEWCOLUMN/'+
    'Create new column on page for current report.';

  SDescriptionSTOPREPORT = 'STOPREPORT/'+
    'Terminate report creation.';

  SDescriptionSHOWBAND = 'SHOWBAND(<BandName>)/'+
    'Show <BandName> in report.';

  SDescriptionINC = 'INC(<Value>)/'+
    'Increment <Value>.';

  SDescriptionDEC = 'DEC(<Value>)/'+
    'Decrement <Value>.';

  SDescriptionIF = 'IF(<expression>, <Value1>, <Value2>)/' +
  'Returns <Value1>, if <expression> is true; otherwise returns <Value2>.';

 //Date and time display format
  sDateFormat1 = 'mm.dd.yy';
  sDateFormat2 = 'mm.dd.yyyy';
  sDateFormat3 = 'd mmm yyyy';
  sDateFormat4 = 'd mmmm yyyy';

  sTimeFormat1 = 'hh:nn:ss';
  sTimeFormat2 = 'h:nn:ss';
  sTimeFormat3 = 'hh:nn';
  sTimeFormat4 = 'h:nn';

  sInsertExpression = 'Insert Expression';
  sFunctions = 'Functions';
  sArguments = 'Arguments';
  sFunctionEditor = 'Function editor';
  sArgument1 = 'Argument 1';
  sArgument2 = 'Argument 2';
  sArgument3 = 'Argument 3';
  sEditor = 'Editor';
  sMemoEditor = 'Memo editor';
  sUseMemoFontSettings = 'Use Memo font settings';
  sUseFixedFontSettings = 'Use fixed font settings';
  sScriptEditor = 'Script editor';
  sUseSyntaxHighlight = 'Use syntax highlight';
  sReportCorruptOldKnowVersion = 'This report is corrupt, it probably needs "LRE_OLDV%d_FRF_READ"=true';
  sReportCorruptUnknownVersion = 'This report is corrupt, frVersion=%d';

//--- LR_Intrp resources ---------------------------------------------------
  sErrLine        = 'Line';
  sErrExpectedEnd = 'Expected ";" or "end"';
  sErrExpectedThen  = 'Expected "then"';
  sErrExpectedUntil = 'Expected ";" or "until"';
  sErrExpectedDO    = 'Expected "do"';
  sErrLabelGoto     = 'Label in goto must be a number';
  sErrExpectedAssign          = 'Expected ":="';
  sErrExpectedClosingBracket1  = 'Expected ")"';
  sErrExpectedClosingBracket2  = 'Expected "]"';
  sErrExpectedComma            ='Expected "," or ")"';
  sErrNeedDo                   = 'Need "do" here';
  sErrNeedTo                   = 'Need "to" here';

  // --- Cross-Tab resources -------------------------------------------------

    sCrossTabRowTitle     = 'Row title';
    sCrossTabRowTotal     = 'Row total';
    sCrossTabColTitle     = 'Col title';
    sCrossTabColTotal     = 'Col total';
    sCrossTabGranTotal    = 'Grand total';
    sCrossTabTotalCHCell  = 'Total CH cell';
    sCrossTabTotalRHCell  = 'Total RH cell';
    sCrossTabData         = 'Data';


  // --- Cross-Tab editor resources ------------------------------------------

    sCrossEditorCaption   = 'Cross tab editor';
    sCrossEditorSource    = 'Source data';
    sCrossEditorStructure = 'Cross-tab structure';
    sCrossEditorStyle     = 'Select style';
    sCrossEditorNone      = 'None';
    sCrossEditorSum       = 'Sum';
    sCrossEditorMin       = 'Min';
    sCrossEditorMax       = 'Max';
    sCrossEditorAverage   = 'Average';
    sCrossEditorCount     = 'Count';
    sCrossEditorWhite     = 'White';
    sCrossEditorGray      = 'Gray';
    sCrossEditorOrange    = 'Orange';
    sCrossEditorGreen     = 'Green';
    sCrossEditorGreenOrange = 'Green and Orange';
    sCrossEditorBlue      = 'Blue';
    sCrossEditorBlueWhite = 'Blue and White';
    sCrossEditorCyan      = 'Cyan';
    sCrossEditorShowColHeader = 'Show column header';
    sCrossEditorShowColTotal  = 'Show column total';
    sCrossEditorShowCorner1   = 'Show corner 1';
    sCrossEditorShowRowHeader = 'Show row header';
    sCrossEditorShowRowTotal  = 'Show row total';
    sCrossEditorShowTitle     = 'Show title';
    sCrossEditorShowGranTotal = 'Show grand total';
    sCrossEditorShowCorner2   = 'Show corner 2';

  // --- Data Inspector frame -----------------------------------------------

    sDataInspFields = 'Fields';
    sDataInspVariables = 'Variables';

const
  frRes = 53000;

  SInsOLEObject = frRes + 2221;
  SInsRichObject = frRes + 2222;
  SFields = frRes + 2239;
  SPath = frRes + 2240;
  SRemoveDS = frRes + 2241;
  STables = frRes + 2242;
  SFieldType1 = frRes + 2243;
  SFieldType2 = frRes + 2244;
  SFieldType3 = frRes + 2245;
  SFieldType4 = frRes + 2246;
  SFieldType5 = frRes + 2247;
  SFieldType6 = frRes + 2248;
  SFieldType7 = frRes + 2249;
  SFieldType8 = frRes + 2250;
  SFieldType9 = frRes + 2251;
  SFieldType10 = frRes + 2252;
  SParamType1 = frRes + 2270;
  SParamType2 = frRes + 2271;
  SParamType3 = frRes + 2272;
  SParamType4 = frRes + 2273;
  SParamType5 = frRes + 2274;
  SParamType6 = frRes + 2275;
  SParamType7 = frRes + 2276;
  SParamType8 = frRes + 2277;
  SParamType9 = frRes + 2278;
  SParamType10 = frRes + 2279;
  SParamType11 = frRes + 2280;
  SDataManager = frRes + 2300;
  SParams = frRes + 2301;
  SQueryError = frRes + 2302;
  STableProps = frRes + 2303;
  SParamDialog = frRes + 2304;

  SInvalidParamValue = frRes + 2340;
  SDatabase = frRes + 2341;
  SInsRich2Object = frRes + 2343;
  SFieldSizeError = frRes + 2346;


implementation

end.

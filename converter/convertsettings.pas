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

  Author: Juha Manninen

  Abstract:
    Settings for ConvertDelphi unit. Used for unit, project and package conversion.
}
unit ConvertSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Laz_AVL_Tree,
  // LCL
  Forms, Controls, Dialogs, StdCtrls, Buttons, ButtonPanel, ComCtrls,
  // LazUtils
  FileUtil, LazFileUtils, DividerBevel, LazConfigStorage, AvgLvlTree,
  // CodeTools
  CodeToolManager, CodeCache,
  // IdeIntf
  BaseIDEIntf, IDEMsgIntf, IDEExternToolIntf, IDEImagesIntf,
  // IDE
  IDEProcs, DialogProcs, LazarusIDEStrConsts,
  // Converter
  ConverterTypes, ReplaceNamesUnit, ReplaceFuncsUnit;

const
  ConverterVersion: integer = 2;
  // 2 removed conversion of string functions into their UTF8 versions.

type

  TReplaceModeLong = (rlDisabled, rlInteractive, rlAutomatic);
  TReplaceModeShort = (rsDisabled, rsEnabled);
  TReplaceModeAllow = (raEnabled, raAutomatic);

  TConvertSettingsForm = class;

  { TConvertSettings }

  TConvertSettings = class
  private
    fVersion: Integer;
    fEnabled: Boolean;
    fTitle: String;       // Used for form caption.
    fLog: TStringList;
    // Unit, Project or Package top file and path.
    fMainFilenames: TStringList;
    // Persistent storage in XML or some other format.
    fConfigStorage: TConfigStorage;
    fSettingsForm: TConvertSettingsForm;
    // Actual user settings.
    fCrossPlatform: Boolean;
    fSupportDelphi: Boolean;
    fSameDfmFile: Boolean;
    fDelphiDefine: Boolean;
    fBackupFiles: Boolean;
    fKeepFileOpen: Boolean;
    fScanParentDir: Boolean;
    fFuncReplaceComment: Boolean;
    // Modes for replacements:
    fUnitsReplaceMode: TReplaceModeLong;
    fPropReplaceMode: TReplaceModeLong;
    fTypeReplaceMode: TReplaceModeAllow;
    fFuncReplaceMode: TReplaceModeShort;
    fCoordOffsMode: TReplaceModeShort;
    // Unit names to leave out of a project. Currently not user editable.
    fOmitProjUnits: TStringToStringTree;
    // Delphi units mapped to Lazarus units, will be replaced or removed.
    fReplaceUnits: TStringToStringTree;
    // Delphi types mapped to Lazarus types, will be replaced.
    fReplaceTypes: TStringToStringTree;
    // Delphi global function names mapped to FCL/LCL functions.
    fReplaceFuncs: TFuncsAndCategories;
    // Coordinate offsets of components in a visual container.
    fCoordOffsets: TVisualOffsets;
    procedure Load;
    procedure LoadFuncReplacements;
    procedure LoadStringToStringTree(Path: string; Tree: TStringToStringTree);
    procedure LoadVisualOffsets;
    procedure Save;
    procedure SaveFuncReplacements;
    procedure SaveStringToStringTree(Path: string; Tree: TStringToStringTree);
    procedure SaveVisualOffsets;
    // Getter / setter:
    function GetBackupPath: String;
    function GetMainFilename: String;
    function GetMainPath: String;
    procedure SetEnabled(const AValue: Boolean);
  public
    constructor Create(const ATitle: string);
    destructor Destroy; override;
    function RunForm(ACacheUnitsThread: TThread): TModalResult;

    // Lazarus file name based on Delphi file name, keep suffix.
    function DelphiToLazFilename(const DelphiFilename: string;
      LowercaseFilename: Boolean): string; overload;
    // Lazarus file name based on Delphi file name with new suffix.
    function DelphiToLazFilename(const DelphiFilename, LazExt: string;
      LowercaseFilename: Boolean): string; overload;
    // Create Lazarus file name and copy/rename from Delphi file, keep suffix.
    function RenameDelphiToLazFile(const DelphiFilename: string;
      out LazFilename: string; LowercaseFilename: Boolean): TModalResult; overload;
    // Create Lazarus file name and copy/rename from Delphi file with new suffix.
    function RenameDelphiToLazFile(const DelphiFilename, LazExt: string;
      out LazFilename: string; LowercaseFilename: Boolean): TModalResult; overload;
    function MaybeBackupFile(const AFilename: string): TModalResult;
    procedure ClearLog;
    procedure AddLogLine(Urgency: TMessageLineUrgency; const Msg: string;
      const Filename: string=''; LineNumber: integer=0; Column: integer=0);
    function SaveLog: Boolean;
  public
    property MainFilenames: TStringlist read fMainFilenames;
    property MainFilename: String read GetMainFilename;
    property MainPath: String read GetMainPath;
    property BackupPath: String read GetBackupPath;
    property Enabled: Boolean read fEnabled write SetEnabled;

    property CrossPlatform: Boolean read fCrossPlatform;
    property SupportDelphi: Boolean read fSupportDelphi;
    property SameDfmFile: Boolean read fSameDfmFile;
    property DelphiDefine: Boolean read fDelphiDefine;
    property BackupFiles: Boolean read fBackupFiles;
    property KeepFileOpen: Boolean read fKeepFileOpen;
    property ScanParentDir: Boolean read fScanParentDir;

    property FuncReplaceComment: Boolean read fFuncReplaceComment;
    property UnitsReplaceMode: TReplaceModeLong read fUnitsReplaceMode;
    property PropReplaceMode: TReplaceModeLong read fPropReplaceMode;
    property TypeReplaceMode: TReplaceModeAllow read fTypeReplaceMode;
    property FuncReplaceMode: TReplaceModeShort read fFuncReplaceMode;
    property CoordOffsMode:   TReplaceModeShort read fCoordOffsMode;
    property OmitProjUnits: TStringToStringTree read fOmitProjUnits;
    property ReplaceUnits: TStringToStringTree read fReplaceUnits;
    property ReplaceTypes: TStringToStringTree read fReplaceTypes;
    property ReplaceFuncs: TFuncsAndCategories read fReplaceFuncs;
    property CoordOffsets: TVisualOffsets read fCoordOffsets;
  end;


  { TConvertSettingsForm }

  TConvertSettingsForm = class(TForm)
    BackupCheckBox: TCheckBox;
    DelphiDefineCheckBox: TCheckBox;
    FuncReplaceCommentCB: TCheckBox;
    ScanParentDirCheckBox: TCheckBox;
    OtherOptGroupBox: TGroupBox;
    InputPathLabel: TLabel;
    InputPathListBox: TListBox;
    KeepFileOpenCheckBox: TCheckBox;
    StopScanButton: TBitBtn;
    CoordOffsComboBox: TComboBox;
    ScanLabel: TLabel;
    ScanProgressBar: TProgressBar;
    UnitReplaceComboBox: TComboBox;
    CrossPlatformCheckBox: TCheckBox;
    SameDfmCheckBox: TCheckBox;
    SupportDelphiCheckBox: TCheckBox;
    TargetGroupBox: TGroupBox;
    FuncReplaceComboBox: TComboBox;
    TypeReplaceComboBox: TComboBox;
    UnknownPropsComboBox: TComboBox;
    UnknownPropsDivider: TDividerBevel;
    UnitReplaceDivider: TDividerBevel;
    TypeReplaceDivider: TDividerBevel;
    FuncReplaceDivider: TDividerBevel;
    CoordOffsDivider: TDividerBevel;
    FuncReplaceButton: TBitBtn;
    ButtonPanel1: TButtonPanel;
    TypeReplaceButton: TBitBtn;
    UnitReplaceButton: TBitBtn;
    CoordOffsButton: TBitBtn;
    procedure SameDfmCheckBoxChange(Sender: TObject);
    procedure ScanParentDirCheckBoxClick(Sender: TObject);
    procedure StopScanButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure SupportDelphiCheckBoxChange(Sender: TObject);
    procedure TypeReplaceButtonClick(Sender: TObject);
    procedure FuncReplaceButtonClick(Sender: TObject);
    procedure CoordOffsButtonClick(Sender: TObject);
    procedure UnitReplaceButtonClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    fSettings: TConvertSettings;
    fCacheUnitsThread: TThread;
    fThreadStarted: Boolean;
    procedure StartThreadIfValid;
    procedure ThreadGuiShow(aRunning: Boolean);
    procedure ThreadTerminated(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; ASettings: TConvertSettings); reintroduce;
    destructor Destroy; override;
  end;


function IsWinSpecificUnit(const ALowercaseUnitName: string): Boolean;


implementation

uses ConvertDelphi;

{$R *.lfm}

function IsWinSpecificUnit(const ALowercaseUnitName: string): Boolean;
// These units exist in Windows only.
// They must be treated as missing units when converting for multi-platform.
begin
  Result := (ALowercaseUnitName = 'windows')
         or (ALowercaseUnitName = 'shellapi')
         or (ALowercaseUnitName = 'wintypes')
         or (ALowercaseUnitName = 'winproc') ;
end;

{ TConvertSettings }

constructor TConvertSettings.Create(const ATitle: string);
begin
  fTitle:=ATitle;
  fLog:=TStringList.Create;
  fMainFilenames:=TStringList.Create;
  fEnabled:=True;
  fSettingsForm:=Nil;
  fOmitProjUnits:=TStringToStringTree.Create(false);
  fReplaceUnits:=TStringToStringTree.Create(false);
  fReplaceTypes:=TStringToStringTree.Create(false);
  fReplaceFuncs:=TFuncsAndCategories.Create;
  fCoordOffsets:=TVisualOffsets.Create;
  fConfigStorage:=GetIDEConfigStorage('delphiconverter.xml', true);

  // Units left out of project. Some projects include them although there are
  //  Lazarus packages for them. This setting is not saved in configuration.
  //  Key = Unit name, Value = Lazarus Package to be added to project as dependency
  fOmitProjUnits['FastMM4']            :='';  // FastMM4 is not needed as FPC's
  fOmitProjUnits['FastMM4Messages']    :='';  // memory manager does its job well.
  fOmitProjUnits['GR32']               :='GR32_Lazarus';
  fOmitProjUnits['GR32_Blend']         :='GR32_Lazarus';
  fOmitProjUnits['GR32_Containers']    :='GR32_Lazarus';
  fOmitProjUnits['GR32_DrawingEx']     :='GR32_Lazarus';
  fOmitProjUnits['GR32_Filters']       :='GR32_Lazarus';
  fOmitProjUnits['GR32_Image']         :='GR32_Lazarus';
  fOmitProjUnits['GR32_Layers']        :='GR32_Lazarus';
  fOmitProjUnits['GR32_LowLevel']      :='GR32_Lazarus';
  fOmitProjUnits['GR32_Math']          :='GR32_Lazarus';
  fOmitProjUnits['GR32_MicroTiles']    :='GR32_Lazarus';
  fOmitProjUnits['GR32_OrdinalMaps']   :='GR32_Lazarus';
  fOmitProjUnits['GR32_RangeBars']     :='GR32_Lazarus';
  fOmitProjUnits['GR32_Rasterizers']   :='GR32_Lazarus';
  fOmitProjUnits['GR32_RepaintOpt']    :='GR32_Lazarus';
  fOmitProjUnits['GR32_Resamplers']    :='GR32_Lazarus';
  fOmitProjUnits['GR32_System']        :='GR32_Lazarus';
  fOmitProjUnits['GR32_Transforms']    :='GR32_Lazarus';
  fOmitProjUnits['GR32_VectorMaps']    :='GR32_Lazarus';
  // OpenGL will be replaced with dglOpenGL in uses section. Download dglOpenGL :
  //  http://wiki.delphigl.com/index.php/dglOpenGL.pas/en#Download
  fOmitProjUnits['OpenGL']             :='';
  fOmitProjUnits['uPSCompiler']        :='pascalscript';
  fOmitProjUnits['uPSUtils']           :='pascalscript';
  fOmitProjUnits['uPSComponent']       :='pascalscript';
  fOmitProjUnits['uPSRuntime']         :='pascalscript';
  fOmitProjUnits['uPSDebugger']        :='pascalscript';
  fOmitProjUnits['uPSPreProcessor']    :='pascalscript';
  fOmitProjUnits['uPSR_dll']           :='pascalscript';
  fOmitProjUnits['uPSC_dll']           :='pascalscript';
  fOmitProjUnits['SynEdit']            :='SynEdit';
  fOmitProjUnits['SynEditMiscProcs']   :='SynEdit';
  fOmitProjUnits['SynEditTextBuffer']  :='SynEdit';
  fOmitProjUnits['SynEditTypes']       :='SynEdit';
  fOmitProjUnits['SynEditHighlighter'] :='SynEdit';
  fOmitProjUnits['SynEditKbdHandler']  :='SynEdit';
  fOmitProjUnits['SynEditKeyCmds']     :='SynEdit';
  fOmitProjUnits['SynEditKeyConst']    :='SynEdit';
  fOmitProjUnits['SynEditMiscClasses'] :='SynEdit';
  fOmitProjUnits['SynEditStrConst']    :='SynEdit';
  fOmitProjUnits['SynEditWordWrap']    :='SynEdit';
  fOmitProjUnits['SynHighlighterMulti']:='SynEdit';
  fOmitProjUnits['SynHighlighterPas']  :='SynEdit';
  fOmitProjUnits['SynTextDrawer']      :='SynEdit';
end;

destructor TConvertSettings.Destroy;
begin
  fConfigStorage.Free;
  fCoordOffsets.Free;
  fReplaceFuncs.Clear;
  fReplaceFuncs.Free;
  fReplaceTypes.Free;
  fReplaceUnits.Free;
  fOmitProjUnits.Free;
  fMainFilenames.Free;
  fLog.Free;
  inherited Destroy;
end;

// Load and store configuration in StringToStringTree :

procedure TConvertSettings.LoadStringToStringTree(Path: string; Tree: TStringToStringTree);
var
  SubPath: String;
  CurName, CurValue: String;
  Cnt, i: Integer;
begin
  Tree.Clear;
  Cnt:=fConfigStorage.GetValue(Path+'Count', 0);
  for i:=0 to Cnt-1 do begin
    SubPath:=Path+'Item'+IntToStr(i)+'/';
    CurName:=fConfigStorage.GetValue(SubPath+'Name','');
    CurValue:=fConfigStorage.GetValue(SubPath+'Value','');
    Tree[CurName]:=CurValue;
  end;
end;

procedure TConvertSettings.SaveStringToStringTree(Path: string; Tree: TStringToStringTree);
var
  Node: TAVLTreeNode;
  Item: PStringToStringItem;
  SubPath: String;
  i: Integer;
begin
  fConfigStorage.DeletePath(Path);      // Make sure there are no old leftover items.
  fConfigStorage.SetDeleteValue(Path+'Count', Tree.Tree.Count, 0);
  Node:=Tree.Tree.FindLowest;
  i:=0;
  while Node<>nil do begin
    Item:=PStringToStringItem(Node.Data);
    SubPath:=Path+'Item'+IntToStr(i)+'/';
    fConfigStorage.SetDeleteValue(SubPath+'Name',Item^.Name,'');
    fConfigStorage.SetDeleteValue(SubPath+'Value',Item^.Value,'');
    Node:=Tree.Tree.FindSuccessor(Node);
    inc(i);
  end;
end;

// Load and store configuration in TFuncsAndCategories :

procedure TConvertSettings.LoadFuncReplacements;
var
  SubPath: String;
  xCategory, xDelphiFunc, xReplacement, xPackage, xUnitName: String;
  CategUsed: Boolean;
  Cnt, i: Integer;
begin
  fReplaceFuncs.Clear;
  // Replacement functions
  Cnt:=fConfigStorage.GetValue('FuncReplacements/Count', 0);
  for i:=0 to Cnt-1 do begin
    SubPath:='FuncReplacements/Item'+IntToStr(i)+'/';
    xCategory   :=fConfigStorage.GetValue(SubPath+'Category','');
    // Delete UTF8 func conversion from old configuration.
    if (fVersion < 2) and (xCategory = 'UTF8Names') then Continue;
    xDelphiFunc :=fConfigStorage.GetValue(SubPath+'DelphiFunction','');
    xReplacement:=fConfigStorage.GetValue(SubPath+'Replacement','');
    xPackage    :=fConfigStorage.GetValue(SubPath+'Package','');
    xUnitName   :=fConfigStorage.GetValue(SubPath+'UnitName','');
    fReplaceFuncs.AddFunc(xCategory, xDelphiFunc, xReplacement, xPackage, xUnitName);
  end;
  // Categories
  Cnt:=fConfigStorage.GetValue('Categories/Count', 0);
  for i:=0 to Cnt-1 do begin
    SubPath:='Categories/Item'+IntToStr(i)+'/';
    xCategory:=fConfigStorage.GetValue(SubPath+'Name','');
    // Delete UTF8 category from old configuration.
    if (fVersion < 2) and (xCategory = 'UTF8Names') then Continue;
    CategUsed:=fConfigStorage.GetValue(SubPath+'InUse',True);
    fReplaceFuncs.AddCategory(xCategory, CategUsed);
  end;
end;

procedure TConvertSettings.SaveFuncReplacements;
var
  FuncRepl: TFuncReplacement;
  SubPath, s: String;
  i: Integer;
begin
  // Replacement functions
  fConfigStorage.DeletePath('FuncReplacements/');
  fConfigStorage.SetDeleteValue('FuncReplacements/Count', fReplaceFuncs.Funcs.Count, 0);
  for i:=0 to fReplaceFuncs.Funcs.Count-1 do begin
    FuncRepl:=fReplaceFuncs.FuncAtInd(i);
    if FuncRepl<>nil then begin
      SubPath:='FuncReplacements/Item'+IntToStr(i)+'/';
      fConfigStorage.SetDeleteValue(SubPath+'Category'      ,FuncRepl.Category,'');
      fConfigStorage.SetDeleteValue(SubPath+'DelphiFunction',fReplaceFuncs.Funcs[i],'');
      fConfigStorage.SetDeleteValue(SubPath+'Replacement'   ,FuncRepl.ReplClause,'');
      fConfigStorage.SetDeleteValue(SubPath+'Package'       ,FuncRepl.PackageName,'');
      fConfigStorage.SetDeleteValue(SubPath+'UnitName'      ,FuncRepl.UnitName,'');
    end;
  end;
  // Categories
  fConfigStorage.DeletePath('Categories/');
  fConfigStorage.SetDeleteValue('Categories/Count', fReplaceFuncs.Categories.Count, 0);
  for i:=0 to fReplaceFuncs.Categories.Count-1 do begin
    s:=fReplaceFuncs.Categories[i];
    if s<>'' then begin
      SubPath:='Categories/Item'+IntToStr(i)+'/';
      fConfigStorage.SetDeleteValue(SubPath+'Name',s,'');
      fConfigStorage.SetDeleteValue(SubPath+'InUse',fReplaceFuncs.CategoryIsUsed(i),True);
    end;
  end;
end;

// Load and store configuration in VisualOffsets :

procedure TConvertSettings.LoadVisualOffsets;
var
  ParentType, SubPath: String;
  xTop, xLeft: Integer;
  Cnt, i: Integer;
begin
  fCoordOffsets.Clear;
  Cnt:=fConfigStorage.GetValue('VisualOffsets/Count', 0);
  for i:=0 to Cnt-1 do begin
    SubPath:='VisualOffsets/Item'+IntToStr(i)+'/';
    ParentType:=fConfigStorage.GetValue(SubPath+'ParentType','');
    xTop :=fConfigStorage.GetValue(SubPath+'Top',0);
    xLeft:=fConfigStorage.GetValue(SubPath+'Left',0);
    fCoordOffsets.Add(TVisualOffset.Create(ParentType, xTop, xLeft));
  end;
end;

procedure TConvertSettings.SaveVisualOffsets;
var
  offs: TVisualOffset;
  SubPath: String;
  i: Integer;
begin
  fConfigStorage.DeletePath('VisualOffsets/');
  fConfigStorage.SetDeleteValue('VisualOffsets/Count', fCoordOffsets.Count, 0);
  for i:=0 to fCoordOffsets.Count-1 do begin
    offs:=fCoordOffsets[i];
    SubPath:='VisualOffsets/Item'+IntToStr(i)+'/';
    fConfigStorage.SetDeleteValue(SubPath+'ParentType',offs.ParentType,'');
    fConfigStorage.SetDeleteValue(SubPath+'Top'       ,offs.Top,0);
    fConfigStorage.SetDeleteValue(SubPath+'Left'      ,offs.Left,0);
  end;
end;

procedure TConvertSettings.Load;
var
  TheMap: TStringToStringTree;
  Categ: string;

  procedure MapReplacement(aDelphi, aLCL: string);
  begin
    if not TheMap.Contains(aDelphi) then
      TheMap[aDelphi]:=aLCL;
  end;

  procedure AddDefaultCategory(aCategory: string);
  var
    x: integer;
  begin
    with fReplaceFuncs do
      if not Categories.Find(aCategory, x) then
        AddCategory(aCategory, True);
  end;

begin
  fVersion                          :=fConfigStorage.GetValue('Version', 0);
  fCrossPlatform                    :=fConfigStorage.GetValue('CrossPlatform', true);
  fSupportDelphi                    :=fConfigStorage.GetValue('SupportDelphi', false);
  fSameDfmFile                      :=fConfigStorage.GetValue('SameDfmFile', false);
  fDelphiDefine                     :=fConfigStorage.GetValue('DelphiDefine', true);
  fBackupFiles                      :=fConfigStorage.GetValue('BackupFiles', true);
  fKeepFileOpen                     :=fConfigStorage.GetValue('KeepFileOpen', false);
  fScanParentDir                    :=fConfigStorage.GetValue('ScanParentDir', true);
  fFuncReplaceComment               :=fConfigStorage.GetValue('FuncReplaceComment', true);
  fUnitsReplaceMode:=TReplaceModeLong(fConfigStorage.GetValue('UnitsReplaceMode', 2));
  fPropReplaceMode :=TReplaceModeLong(fConfigStorage.GetValue('UnknownPropsMode', 2));
  fTypeReplaceMode:=TReplaceModeAllow(fConfigStorage.GetValue('TypeReplaceMode', 1));
  fFuncReplaceMode:=TReplaceModeShort(fConfigStorage.GetValue('FuncReplaceMode', 1));
  fCoordOffsMode  :=TReplaceModeShort(fConfigStorage.GetValue('CoordOffsMode', 1));

  // * Map Delphi units to Lazarus units *
  TheMap:=fReplaceUnits;
  LoadStringToStringTree('UnitReplacements/', TheMap);
  // Add default values for configuration if ConfigStorage doesn't have them
  MapReplacement('Windows',             'LCLIntf, LCLType, LMessages');
  MapReplacement('WinTypes',            'LCLIntf, LCLType, LMessages');
  MapReplacement('WinProcs',            'LCLIntf, LCLType, LMessages');
  MapReplacement('Mask',                'Masks');
  MapReplacement('TabNotBk',            'ComCtrls');
  MapReplacement('OpenGL',              'dglOpenGL');
//  MapReplacement('dglOpenGL',           'GL, GLu, GLut');  // ?
  // Database components
  MapReplacement('SqlExpr',             'sqldb');
  MapReplacement('DBLocalS',            'sqldb');
  MapReplacement('DBLocalB',            'sqldb');
  MapReplacement('DBTables',            'sqldb');
  MapReplacement('ADODB',               'sqldb');
  MapReplacement('IBTable',             'sqldb');
  MapReplacement('IBQuery',             'sqldb');
  MapReplacement('IBStoredProc',        'sqldb');
  MapReplacement('IBDatabase',          'sqldb');
  MapReplacement('IBUpdateSQL',         'sqldb');
  MapReplacement('IBCustomDataSet',     'sqldb');
  MapReplacement('IBSQL',               'sqldb');
  MapReplacement('DBLocalI',            'IBConnection');
  // Remove these
  MapReplacement('ShellApi',            '');
  MapReplacement('pngImage',            '');
  MapReplacement('Jpeg',                '');
  MapReplacement('gifimage',            '');
  MapReplacement('^FastMM.*',           '');           // External memory manager.
  MapReplacement('MMSystem',            '');
  MapReplacement('.*dll.*',             '');
  MapReplacement('^Q(.+)',              '$1');         // Kylix unit names.
  // SynEdit has an identical RegExpr as FCL has, but names differ.
  MapReplacement('SynRegExpr',          'RegExpr');
  // Tnt* third party components.
  MapReplacement('TntLXStringGrids',    'Grids');
  MapReplacement('TntLXCombos',         '');
  MapReplacement('TntLXDataSet',        '');
  MapReplacement('TntLXVarArrayDataSet','');
  MapReplacement('TntLXLookupCtrls',    '');
  MapReplacement('^TntLX(.+)',          '$1');
  MapReplacement('^Tnt(([^L]|L[^X]).*)','$1');

  // * Map Delphi types to LCL types *
  TheMap:=fReplaceTypes;
  LoadStringToStringTree('TypeReplacements/', TheMap);
  // Add default values for configuration if ConfigStorage doesn't have them
  MapReplacement('TFlowPanel',        'TPanel');
  MapReplacement('TGridPanel',        'TPanel');
  MapReplacement('TRichEdit',         'TMemo'); // or TRichMemo from CRC.
  MapReplacement('TDBRichEdit',       'TDBMemo');
  MapReplacement('TApplicationEvents','TApplicationProperties');
  MapReplacement('TPNGObject',        'TPortableNetworkGraphic');
  MapReplacement('TTabbedNotebook',   'TPageControl');
  MapReplacement('TTabPage',          'ts$autoinc: TTabSheet');
  MapReplacement('THeader',           'THeaderControl');
  MapReplacement('TMonthCalendar',    'TCalendar');
  MapReplacement('TOleContainer',     'TActiveXContainer'); // from LazActiveX
  // Database components
  MapReplacement('TSQLConnection',    'TSQLConnector');
  MapReplacement('TSQLClientDataSet', 'TSQLConnector');
  MapReplacement('TSQLDataset',       'TSQLQuery');
  MapReplacement('TSQLTable',         'TSQLQuery');
  MapReplacement('TSQLStoredProc',    'TSQLQuery');
  // BDE
  MapReplacement('TDatabase',         'TSQLConnector');
  MapReplacement('TBDEClientDataSet', 'TSQLConnector');
  MapReplacement('TTable',            'TSQLQuery');
  MapReplacement('TQuery',            'TSQLQuery');
  MapReplacement('TUpdateSQL',        'TSQLQuery');
  MapReplacement('TStoredProc',       'TSQLQuery');
  // ADO
  MapReplacement('TADOConnection',    'TSQLConnector');
  MapReplacement('TADODataSet',       'TSQLQuery');
  MapReplacement('TADOTable',         'TSQLQuery');
  MapReplacement('TADOQuery',         'TSQLQuery');
  MapReplacement('TADOCommand',       'TSQLQuery');
  MapReplacement('TADOStoredProc',    'TSQLQuery');
  // Interbase
  MapReplacement('TIBDatabase',       'TIBConnection');
  MapReplacement('TIBClientDataSet',  'TIBConnection');
  MapReplacement('TIBDataSet',        'TSQLQuery');
  MapReplacement('TIBTable',          'TSQLQuery');
  MapReplacement('TIBQuery',          'TSQLQuery');
  MapReplacement('TIBUpdateSQL',      'TSQLQuery');
  MapReplacement('TIBSQL',            'TSQLQuery');
  MapReplacement('TIBStoredProc',     'TSQLQuery');
  MapReplacement('TIBTransaction',    'TSQLTransaction');
  // DevExpress components
  MapReplacement('TCxEdit',           'TEdit');
  // Tnt* third party components
  MapReplacement('^TTnt(.+)LX$',      'T$1');
  MapReplacement('^TTnt(.+[^L][^X])$','T$1');

  // * Map Delphi function names to FCL/LCL functions *
  LoadFuncReplacements;
  // Add default values for configuration if ConfigStorage doesn't have them
  with fReplaceFuncs do begin
    // File functions using a handle
    Categ:='FileHandle';
    AddDefaultCategory(Categ);
    //AddFunc(Categ, 'CreateFile', 'FileCreate($1)','','SysUtils');
    //AddFunc(Categ, 'ReadFile',   'FileRead($1)'  ,'','SysUtils');
    AddFunc(Categ, 'CloseHandle','FileClose($1)' ,'','SysUtils');
    AddFunc(Categ, 'GetFileSize','FileSize($1)'  ,'LazUtils','FileUtil');
    // WindowsAPI
    Categ:='WindowsAPI';
    AddDefaultCategory(Categ);
    AddFunc(Categ, 'ShellExecute',
                   'if $3 match ":/" then OpenURL($3); OpenDocument($3)', 'LCL', 'LCLIntf');
    AddFunc(Categ, 'TimeGetTime', 'GetTickCount','LCL','LCLIntf'); // In Windows MMSystems unit.
    // OpenGL
    Categ:='OpenGL';
    AddDefaultCategory(Categ);
    AddFunc(Categ, 'glIsEnabled', 'Boolean(glIsEnabled($1))', '', 'GL');
    AddFunc(Categ, 'glIsList',    'Boolean(glIsList($1))',    '', 'GL');
    AddFunc(Categ, 'glIsTexture', 'Boolean(glIsTexture($1))', '', 'GL');
    AddFunc(Categ, 'glColorMask', 'glColorMask(GLboolean($1),GLboolean($2),GLboolean($3),GLboolean($4))', '', 'GL');
    AddFunc(Categ, 'glDepthMask', 'glDepthMask(GLboolean($1))', '', 'GL');
    AddFunc(Categ, 'gluQuadricTexture', 'gluQuadricTexture($1,GLboolean($2))', '', 'GLu');
    // Others
    Categ:='Other';
    AddDefaultCategory(Categ);
    AddFunc(Categ, 'Ptr','Pointer($1)' ,'','');
    AddFunc(Categ, 'RecreateWnd','RecreateWnd(Self)' ,'LCL', 'Controls');
    // SysUtils has AnsiSameStr and SameText but no SameStr.
    AddFunc(Categ, 'SameStr','(CompareStr($1,$2) = 0)' ,'', 'SysUtils');
  end;

  // * Coordinate offsets for some visual containers *
  LoadVisualOffsets;
  // Add default values for configuration if ConfigStorage doesn't have them
  with fCoordOffsets do begin
    AddVisualOffset('TGroupBox' , 14,2);
    AddVisualOffset('TPanel',      2,2);
    AddVisualOffset('RadioGroup', 14,2);
    AddVisualOffset('CheckGroup', 14,2);
  end;
end;

procedure TConvertSettings.Save;
begin
  // Save possibly modified settings to ConfigStorage.
  fConfigStorage.SetDeleteValue('Version',           ConverterVersion, 0);
  fConfigStorage.SetDeleteValue('CrossPlatform',     fCrossPlatform, true);
  fConfigStorage.SetDeleteValue('SupportDelphi',     fSupportDelphi, false);
  fConfigStorage.SetDeleteValue('SameDfmFile',       fSameDfmFile, false);
  fConfigStorage.SetDeleteValue('DelphiDefine',      fDelphiDefine, true);
  fConfigStorage.SetDeleteValue('BackupFiles',       fBackupFiles, true);
  fConfigStorage.SetDeleteValue('KeepFileOpen',      fKeepFileOpen, false);
  fConfigStorage.SetDeleteValue('ScanParentDir',     fScanParentDir, true);
  fConfigStorage.SetDeleteValue('FuncReplaceComment', fFuncReplaceComment, true);
  fConfigStorage.SetDeleteValue('UnitsReplaceMode', integer(fUnitsReplaceMode), 2);
  fConfigStorage.SetDeleteValue('UnknownPropsMode', integer(fPropReplaceMode), 2);
  fConfigStorage.SetDeleteValue('TypeReplaceMode',  integer(fTypeReplaceMode), 1);
  fConfigStorage.SetDeleteValue('FuncReplaceMode',  integer(fFuncReplaceMode), 1);
  fConfigStorage.SetDeleteValue('CoordOffsMode',    integer(fCoordOffsMode), 1);
  SaveStringToStringTree('UnitReplacements/', fReplaceUnits);
  SaveStringToStringTree('TypeReplacements/', fReplaceTypes);
  SaveFuncReplacements;
  SaveVisualOffsets;
end;

function TConvertSettings.RunForm(ACacheUnitsThread: TThread): TModalResult;
begin
  fSettingsForm:=TConvertSettingsForm.Create(nil, Self);
  try
    Load;   // Load settings from ConfigStorage.
    with fSettingsForm do
    begin
      Caption:=fTitle + ' - ' + ExtractFileName(MainFilename);
      InputPathListBox.Items.Assign(fMainFilenames);
      // Settings --> UI. Loaded from ConfigSettings earlier.
      CrossPlatformCheckBox.Checked  :=fCrossPlatform;
      SupportDelphiCheckBox.Checked  :=fSupportDelphi;
      SameDfmCheckBox.Checked        :=fSameDfmFile;
      DelphiDefineCheckBox.Checked   :=fDelphiDefine;
      BackupCheckBox.Checked         :=fBackupFiles;
      KeepFileOpenCheckBox.Checked   :=fKeepFileOpen;
      ScanParentDirCheckBox.Checked  :=fScanParentDir;
      FuncReplaceCommentCB.Checked   :=fFuncReplaceComment;

      UnitReplaceComboBox.ItemIndex  :=integer(fUnitsReplaceMode);
      UnknownPropsComboBox.ItemIndex :=integer(fPropReplaceMode);
      TypeReplaceComboBox.ItemIndex  :=integer(fTypeReplaceMode);
      FuncReplaceComboBox.ItemIndex  :=integer(fFuncReplaceMode);
      CoordOffsComboBox.ItemIndex    :=integer(fCoordOffsMode);
      SupportDelphiCheckBoxChange(SupportDelphiCheckBox);
      SameDfmCheckBoxChange(SameDfmCheckBox);

      fCacheUnitsThread := ACacheUnitsThread;
      StartThreadIfValid;
      Result:=ShowModal;   // Let the user change the settings.
      if Result=mrOK then  // The thread will be finished before the form closes.
      begin
        // UI --> Settings. Will be saved to ConfigSettings later.
        fCrossPlatform     :=CrossPlatformCheckBox.Checked;
        fSupportDelphi     :=SupportDelphiCheckBox.Checked;
        fSameDfmFile       :=SameDfmCheckBox.Checked;
        fDelphiDefine      :=DelphiDefineCheckBox.Checked;
        fBackupFiles       :=BackupCheckBox.Checked;
        fKeepFileOpen      :=KeepFileOpenCheckBox.Checked;
        fScanParentDir     :=ScanParentDirCheckBox.Checked;
        fFuncReplaceComment:=FuncReplaceCommentCB.Checked;

        fUnitsReplaceMode:=TReplaceModeLong(UnitReplaceComboBox.ItemIndex);
        fPropReplaceMode :=TReplaceModeLong(UnknownPropsComboBox.ItemIndex);
        fTypeReplaceMode :=TReplaceModeAllow(TypeReplaceComboBox.ItemIndex);
        fFuncReplaceMode :=TReplaceModeShort(FuncReplaceComboBox.ItemIndex);
        fCoordOffsMode   :=TReplaceModeShort(CoordOffsComboBox.ItemIndex);
        if fBackupFiles then
          DeleteDirectory(BackupPath, True); // Delete old backup if there is any.
        Save;
      end;
    end;
  finally
    FreeAndNil(fSettingsForm);
  end;
end;

function TConvertSettings.DelphiToLazFilename(const DelphiFilename: string;
                                              LowercaseFilename: Boolean): string;
begin
  Result:=DelphiToLazFilename(DelphiFilename,'',LowercaseFilename);
end;

function TConvertSettings.DelphiToLazFilename(const DelphiFilename, LazExt: string;
                                              LowercaseFilename: Boolean): string;
var
  RelPath, SubPath, fn: string;
begin
  RelPath:=CreateRelativePath(DelphiFilename, MainPath);
  SubPath:=ExtractFilePath(RelPath);
  if LazExt='' then                 // Include ext in filename if not defined.
    fn:=ExtractFileName(RelPath)
  else
    fn:=ExtractFileNameOnly(RelPath);
  if LowercaseFilename then
    fn:=LowerCase(fn);
  Result:=MainPath+SubPath+fn+LazExt;
end;

function TConvertSettings.RenameDelphiToLazFile(const DelphiFilename: string;
  out LazFilename: string; LowercaseFilename: Boolean): TModalResult;
begin
  Result:=RenameDelphiToLazFile(DelphiFilename,'',LazFilename,LowercaseFilename);
end;

function TConvertSettings.RenameDelphiToLazFile(const DelphiFilename, LazExt: string;
  out LazFilename: string; LowercaseFilename: Boolean): TModalResult;
var
  RelPath, SubPath, fn: string;
begin
  RelPath:=CreateRelativePath(DelphiFilename, MainPath);
  SubPath:=ExtractFilePath(RelPath);
  if LazExt='' then                 // Include ext in filename if not defined.
    fn:=ExtractFileName(RelPath)
  else
    fn:=ExtractFileNameOnly(RelPath);
  if LowercaseFilename then
    fn:=LowerCase(fn);
  // Rename in the same directory.
  Result:=MaybeBackupFile(DelphiFilename); // Save before rename.
  if Result<>mrOK then exit;
  LazFilename:=MainPath+SubPath+fn+LazExt;
  Result:=RenameFileWithErrorDialogs(DelphiFilename,LazFilename,[mbAbort]);
end;

function TConvertSettings.MaybeBackupFile(const AFilename: string): TModalResult;
var
  BackupFN: String;
begin
  Result:=mrOK;
  if fBackupFiles then begin
    BackupFN:=BackupPath+ExtractFileName(AFilename);
    if not FileExistsUTF8(BackupFN) then
      Result:=CopyFileWithErrorDialogs(AFilename,BackupFN,[mbAbort]);
  end;
end;

procedure TConvertSettings.ClearLog;
begin
  IDEMessagesWindow.Clear;
  fLog.Clear;
end;

procedure TConvertSettings.AddLogLine(Urgency: TMessageLineUrgency;
  const Msg: string; const Filename: string; LineNumber: integer; Column: integer);
var
  FN, Coords, Urg: String;
begin
  // Show in message window
  IDEMessagesWindow.AddCustomMessage(Urgency, Msg, Filename, LineNumber, Column);
  // and store for log.
  FN := ExtractFileName(Filename);
  if (LineNumber<>0) or (Column<>0) then
    Coords := Format('(%d,%d)', [LineNumber, Column]);
  if Urgency <> mluImportant then
    Urg := MessageLineUrgencyNames[Urgency];
  fLog.Add(FN + Coords + ' ' + Urg + ': ' + Msg);
end;

function TConvertSettings.SaveLog: Boolean;
var
  aFilename: String;
  Code: TCodeBuffer;
begin
  aFilename:=MainPath+'AutomaticConversion.log';
  Code:=CodeToolBoss.CreateFile(aFilename);
  Code.Assign(fLog);
  Result:=SaveCodeBuffer(Code)=mrOk;
  if Result then                                     // Show in message window
    IDEMessagesWindow.AddCustomMessage(mluHint,Format(lisConvThisLogWasSaved, [aFilename]));
end;

function TConvertSettings.GetBackupPath: String;
const
  BackupPathName='ConverterBackup';
begin
  Result:='';
  if fBackupFiles then begin
    Result:=MainPath+BackupPathName+PathDelim;
    // Create backup path if needed.
    if not DirectoryExistsUTF8(Result) then
      CreateDirUTF8(Result);
  end;
end;

function TConvertSettings.GetMainFilename: String;
begin
  Result:=fMainFilenames[0];
end;

function TConvertSettings.GetMainPath: String;
begin
  Result:=ExtractFilePath(fMainFilenames[0]);
end;

procedure TConvertSettings.SetEnabled(const AValue: Boolean);
begin
  if fEnabled=AValue then exit;
  fEnabled:=AValue;
  if Assigned(fSettingsForm) then
    fSettingsForm.ButtonPanel1.Enabled:=fEnabled; // OKButton
end;


{ TConvertSettingsForm }

constructor TConvertSettingsForm.Create(AOwner: TComponent; ASettings: TConvertSettings);
begin
  inherited Create(AOwner);
  fSettings:=ASettings;
end;

destructor TConvertSettingsForm.Destroy;
begin
  inherited Destroy;
end;

procedure TConvertSettingsForm.FormCreate(Sender: TObject);
begin
  InputPathLabel.Caption:=lisToFPCPath; // Reuse a string form options page.
  InputPathListBox.Clear;
  InputPathListBox.Hint:=lisProjectPathHint;
  // Target
  TargetGroupBox.Caption:=lisConvertTarget;
  TargetGroupBox.Hint:=lisConvertTargetHint;
  CrossPlatformCheckBox.Caption:=lisConvertTargetCrossPlatform;
  CrossPlatformCheckBox.Hint:=lisConvertTargetCrossPlatformHint;
  SupportDelphiCheckBox.Caption:=lisConvertTargetSupportDelphi;
  SupportDelphiCheckBox.Hint:=lisConvertTargetSupportDelphiHint;
  SameDfmCheckBox.Caption:=lisConvertTargetSameDfmFile;
  SameDfmCheckBox.Hint:=lisConvertTargetSameDfmFileHint;
  // Other
  OtherOptGroupBox.Caption:=lisCEOtherGroup;
  OtherOptGroupBox.Hint:=lisConvertOtherHint;
  DelphiDefineCheckBox.Caption:=lisAddDelphiDefine;
  DelphiDefineCheckBox.Hint:=lisAddDelphiDefineHint;
  BackupCheckBox.Caption:=lisBackupChangedFiles;
  BackupCheckBox.Hint:=lisBackupHint;
  KeepFileOpenCheckBox.Caption:=lisKeepFileOpen;
  KeepFileOpenCheckBox.Hint:=lisKeepFileOpenHint;
  ScanParentDirCheckBox.Caption:=lisScanFilesInParentDir;
  ScanParentDirCheckBox.Hint:=lisScanFilesInParentDirHint;
  // File system scanning
  ScanLabel.Caption := lisScanParentDir;
  StopScanButton.Caption:=lisStop;
  IDEImages.AssignImage(StopScanButton, 'menu_stop');
  // Unit Replacements
  UnitReplaceDivider.Caption:=lisConvUnitReplacements;
  UnitReplaceButton.Caption:=lisEdit;    // Recycled string.
  IDEImages.AssignImage(UnitReplaceButton, 'laz_edit');
  UnitReplaceDivider.Hint:=lisConvUnitReplHint;
  UnitReplaceButton.Hint:=lisConvUnitReplHint;
  UnitReplaceComboBox.Items.Add(lisDisabled);    // 'Disabled'
  UnitReplaceComboBox.Items.Add(lisInteractive); // 'Interactive'
  UnitReplaceComboBox.Items.Add(lisAutomatic);   // 'Automatic'
  // Unknown Properties
  UnknownPropsDivider.Caption:=lisConvUnknownProps;
  UnknownPropsComboBox.Items.Add(lisDisabled);
  UnknownPropsComboBox.Items.Add(lisInteractive);
  UnknownPropsComboBox.Items.Add(lisAutomatic);
  // Type Replacements
  TypeReplaceDivider.Caption:=lisConvTypeReplacements;
  TypeReplaceButton.Caption:=lisEdit;
  IDEImages.AssignImage(TypeReplaceButton, 'laz_edit');
  TypeReplaceDivider.Hint:=lisConvTypeReplHint;
  TypeReplaceButton.Hint:=lisConvTypeReplHint;
  TypeReplaceComboBox.Items.Add(lisInteractive);
  TypeReplaceComboBox.Items.Add(lisAutomatic);
  // Func Replacements
  FuncReplaceDivider.Caption:=lisConvFuncReplacements;
  FuncReplaceButton.Caption:=lisEdit;
  IDEImages.AssignImage(FuncReplaceButton, 'laz_edit');
  FuncReplaceDivider.Hint:=lisConvFuncReplHint;
  FuncReplaceButton.Hint:=lisConvFuncReplHint;
  FuncReplaceComboBox.Items.Add(lisDisabled);
  FuncReplaceComboBox.Items.Add(lisEnabled);
  FuncReplaceCommentCB.Caption:=lisConvAddCommentAfterReplacement;
  // Coordinate Offsets
  CoordOffsDivider.Caption:=lisConvCoordOffs;
  CoordOffsButton.Caption:=lisEdit;
  IDEImages.AssignImage(CoordOffsButton, 'laz_edit');
  CoordOffsDivider.Hint:=lisConvCoordHint;
  CoordOffsButton.Hint:=lisConvCoordHint;
  CoordOffsComboBox.Items.Add(lisDisabled);
  CoordOffsComboBox.Items.Add(lisEnabled);

  ButtonPanel1.OKButton.Caption:=lisStartConversion;
end;

procedure TConvertSettingsForm.FormDestroy(Sender: TObject);
begin
  ;
end;

procedure TConvertSettingsForm.SupportDelphiCheckBoxChange(Sender: TObject);
var
  Chk: Boolean;
begin
  Chk:=(Sender as TCheckBox).Checked;
  SameDfmCheckBox.Enabled:=Chk;
  if not Chk then
    SameDfmCheckBox.Checked:=Chk;
end;

procedure TConvertSettingsForm.SameDfmCheckBoxChange(Sender: TObject);
var
  Chk: Boolean;
begin
  Chk:=(Sender as TCheckBox).Checked;
  if Chk then
    CoordOffsComboBox.ItemIndex:=integer(rsDisabled);
  CoordOffsComboBox.Enabled:=not Chk;
end;

procedure TConvertSettingsForm.ScanParentDirCheckBoxClick(Sender: TObject);
begin
  if (Sender as TCheckBox).Checked then
    StartThreadIfValid;
end;

procedure TConvertSettingsForm.StartThreadIfValid;
begin
  if ScanParentDirCheckBox.Checked and Assigned(fCacheUnitsThread) then
  begin
    ThreadGuiShow(True);
    fCacheUnitsThread.OnTerminate:=@ThreadTerminated;
    fCacheUnitsThread.Start;
    fThreadStarted := True;
  end
  else
    ThreadGuiShow(False);          // Hide controls dealing with scanning
end;

procedure TConvertSettingsForm.StopScanButtonClick(Sender: TObject);
begin
  (fCacheUnitsThread as TCacheUnitsThread).Searcher.Stop; // Terminate;
end;

procedure TConvertSettingsForm.CancelButtonClick(Sender: TObject);
begin
  if Assigned(fCacheUnitsThread) and fThreadStarted then
  begin
    (fCacheUnitsThread as TCacheUnitsThread).Searcher.Stop;
    fCacheUnitsThread.WaitFor;
  end;
end;

procedure TConvertSettingsForm.ThreadGuiShow(aRunning: Boolean);
begin
  ScanLabel.Visible := aRunning;
  ScanProgressBar.Visible := aRunning;
  StopScanButton.Visible := aRunning;
  // These are disabled while thread is running
  ButtonPanel1.OKButton.Enabled := not aRunning;
  ScanParentDirCheckBox.Enabled := not aRunning;
end;

procedure TConvertSettingsForm.ThreadTerminated(Sender: TObject);
begin
  ThreadGuiShow(False);
end;

// Edit replacements in grids

procedure TConvertSettingsForm.UnitReplaceButtonClick(Sender: TObject);
begin
  EditMap(fSettings.ReplaceUnits, lisConvUnitsToReplace);
end;

procedure TConvertSettingsForm.TypeReplaceButtonClick(Sender: TObject);
begin
  EditMap(fSettings.ReplaceTypes, lisConvTypesToReplace);
end;

procedure TConvertSettingsForm.FuncReplaceButtonClick(Sender: TObject);
begin
  EditFuncReplacements(fSettings.ReplaceFuncs, lisConvFuncsToReplace);
end;

procedure TConvertSettingsForm.CoordOffsButtonClick(Sender: TObject);
begin
  EditCoordOffsets(fSettings.CoordOffsets, lisConvCoordOffs);
end;

end.


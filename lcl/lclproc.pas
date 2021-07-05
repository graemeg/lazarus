{
 /***************************************************************************
                                  lclproc.pas
                                  -----------
                             Component Library Code


 ***************************************************************************/

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

  Useful lower level helper functions and classes.
}
unit LCLProc;

{$MODE ObjFPC}{$H+}
{$I lcl_defines.inc}
{$inline on}

interface

uses
  {$IFDEF Darwin}MacOSAll, {$ENDIF}
  Classes, SysUtils, Math, Types, Laz_AVL_Tree,
  // LazUtils
  LazFileUtils, LazUtilities, LazMethodList, LazUTF8, LazLoggerBase, LazTracer,
  // LCL
  LCLStrConsts, LCLType;

type
  TMethodList = LazMethodList.TMethodList;

  { TDebugLCLItemInfo }

  TDebugLCLItemInfo = class
  public
    Item: Pointer;
    IsDestroyed: boolean;
    Info: string;
    CreationStack: TStackTracePointers; // stack trace at creationg
    DestructionStack: TStackTracePointers;// stack trace at destruction
    function AsString(WithStackTraces: boolean): string;
    destructor Destroy; override;
  end;

  { TDebugLCLItems }

  TDebugLCLItems = class
  private
    FItems: TAvlTree;// tree of TDebugLCLItemInfo
    FName: string;
  public
    constructor Create(const TheName: string);
    destructor Destroy; override;
    function FindInfo(p: Pointer; CreateIfNotExists: boolean = false
                      ): TDebugLCLItemInfo;
    function IsDestroyed(p: Pointer): boolean;
    function IsCreated(p: Pointer): boolean;
    function MarkCreated(p: Pointer; const InfoText: string): TDebugLCLItemInfo;
    procedure MarkDestroyed(p: Pointer);
    function GetInfo(p: Pointer; WithStackTraces: boolean): string;
    property Name: string read FName;
  end;

{$IFDEF DebugLCLComponents}
var
  DebugLCLComponents: TDebugLCLItems = nil;
{$ENDIF}

function CompareDebugLCLItemInfos(Data1, Data2: Pointer): integer;
function CompareItemWithDebugLCLItemInfo(Item, DebugItemInfo: Pointer): integer;


type
  TStringsSortCompare = function(const Item1, Item2: string): Integer;

// sort so that for each i is OnCompare(List[i],List[i+1])<=0
procedure MergeSort(List: TFPList; const OnCompare: TListSortCompare); overload; inline;
procedure MergeSort(List: TFPList; StartIndex, EndIndex: integer; const OnCompare: TListSortCompare); overload;
procedure MergeSort(List: TStrings; const OnCompare: TStringsSortCompare); overload;

function KeyAndShiftStateToKeyString(Key: word; ShiftState: TShiftState): String;
function KeyStringIsIrregular(const s: string): boolean;
function ShortCutToText(ShortCut: TShortCut): string; inline;    // localized output
function ShortCutToTextRaw(ShortCut: TShortCut): string; inline; // NOT localized output
function TextToShortCut(const ShortCutText: string): TShortCut; inline;   // localized input
function TextToShortCutRaw(const ShortCutText: string): TShortCut; inline;// NOT localized input

function GetCompleteText(const sText: string; iSelStart: Integer;
  bCaseSensitive, bSearchAscending: Boolean; slTextList: TStrings): string;
function IsEditableTextKey(Key: Word): Boolean;

// Hooks used to prevent unit circles
type
  TSendApplicationMessageFunction =
    function(Msg: Cardinal; WParam: WParam; LParam: LParam):Longint;
  TOwnerFormDesignerModifiedProc =
    procedure(AComponent: TComponent);


var
  SendApplicationMessageFunction: TSendApplicationMessageFunction=nil;
  OwnerFormDesignerModifiedProc: TOwnerFormDesignerModifiedProc=nil;

function SendApplicationMessage(Msg: Cardinal; WParam: WParam; LParam: LParam):Longint;
procedure OwnerFormDesignerModified(AComponent: TComponent);
procedure FreeThenNil(var obj); inline;

{ the LCL interfaces finalization sections are called before the finalization
  sections of the LCL. Those parts, that should be finalized after the LCL, can
  be registered here. }
procedure RegisterInterfaceInitializationHandler(p: TProcedure);
procedure CallInterfaceInitializationHandlers;
procedure RegisterInterfaceFinalizationHandler(p: TProcedure);
procedure CallInterfaceFinalizationHandlers;

function OffsetRect(var ARect: TRect; dx, dy: Integer): Boolean;
procedure MoveRect(var ARect: TRect; x, y: Integer);
procedure MoveRectToFit(var ARect: TRect; const MaxRect: TRect);
procedure MakeMinMax(var i1, i2: integer);
procedure CalculateLeftTopWidthHeight(X1,Y1,X2,Y2: integer;
  out Left,Top,Width,Height: integer);

// Ampersands
function DeleteAmpersands(var Str : String) : Integer;
function RemoveAmpersands(const ASource: String): String;
function RemoveAmpersands(Src: PChar; var LineLength: Longint): PChar;

function CompareHandles(h1, h2: THandle): integer;
function CompareRect(R1, R2: PRect): Boolean;
function ComparePoints(const p1, p2: TPoint): integer;
function CompareCaret(const FirstCaret, SecondCaret: TPoint): integer;

// Deprecated in 2.1 / 12.12.2020 / Remove in 2.3
function CompareMethods(m1, m2: TMethod): boolean; deprecated 'Use LazMethodList.CompareMethods';
function ComparePointers(p1, p2: Pointer): integer; deprecated 'Use LazUtilities.ComparePointers';
function RoundToInt(e: Extended): integer; deprecated 'Use LazUtilities.RoundToInt';
function RoundToCardinal(e: Extended): cardinal; deprecated 'Use LazUtilities.RoundToCardinal';
function TruncToInt(e: Extended): integer; deprecated 'Use LazUtilities.TruncToInt';
function TruncToCardinal(e: Extended): cardinal; deprecated 'Use LazUtilities.TruncToCardinal';
function StrToDouble(const s: string): double; deprecated 'Use LazUtilities.StrToDouble';

// Call debugging procedure in LazLoggerBase.
procedure RaiseGDBException(const Msg: string); inline;

{$IFnDEF WithOldDebugln}
procedure DbgOut(const s: string = ''); inline; overload;
procedure DbgOut(Args: array of const); {inline;} overload;
procedure DbgOut(const S: String; Args: array of const); {inline;} overload;// similar to Format(s,Args)
procedure DbgOut(const s1, s2: string; const s3: string = '';
                 const s4: string = ''; const s5: string = ''; const s6: string = '';
                 const s7: string = ''; const s8: string = ''; const s9: string = '';
                 const s10: string = ''; const s11: string = ''; const s12: string = '';
                 const s13: string = ''; const s14: string = ''; const s15: string = '';
                 const s16: string = ''; const s17: string = ''; const s18: string = ''); inline; overload;

procedure DebugLn(const s: string = ''); inline; overload;
procedure DebugLn(Args: array of const); {inline;} overload;
procedure DebugLn(const S: String; Args: array of const); {inline;} overload;// similar to Format(s,Args)
procedure DebugLn(const s1, s2: string; const s3: string = '';
                  const s4: string = ''; const s5: string = ''; const s6: string = '';
                  const s7: string = ''; const s8: string = ''; const s9: string = '';
                  const s10: string = ''; const s11: string = ''; const s12: string = '';
                  const s13: string = ''; const s14: string = ''; const s15: string = '';
                  const s16: string = ''; const s17: string = ''; const s18: string = ''); inline; overload;

procedure DebugLnEnter(const s: string = ''); inline; overload;
procedure DebugLnEnter(Args: array of const); {inline;} overload;
procedure DebugLnEnter(s: string; Args: array of const); {inline;} overload;
procedure DebugLnEnter(const s1, s2: string; const s3: string = '';
                       const s4: string = ''; const s5: string = ''; const s6: string = '';
                       const s7: string = ''; const s8: string = ''; const s9: string = '';
                       const s10: string = ''; const s11: string = ''; const s12: string = '';
                       const s13: string = ''; const s14: string = ''; const s15: string = '';
                       const s16: string = ''; const s17: string = ''; const s18: string = ''); inline; overload;

procedure DebugLnExit(const s: string = ''); inline; overload;
procedure DebugLnExit(Args: array of const); {inline;} overload;
procedure DebugLnExit(s: string; Args: array of const); {inline;} overload;
procedure DebugLnExit (const s1, s2: string; const s3: string = '';
                       const s4: string = ''; const s5: string = ''; const s6: string = '';
                       const s7: string = ''; const s8: string = ''; const s9: string = '';
                       const s10: string = ''; const s11: string = ''; const s12: string = '';
                       const s13: string = ''; const s14: string = ''; const s15: string = '';
                       const s16: string = ''; const s17: string = ''; const s18: string = ''); inline; overload;

procedure CloseDebugOutput; inline;
{$ELSE}
procedure DebugLn(Args: array of const); overload;
procedure DebugLn(const S: String; Args: array of const); overload;// similar to Format(s,Args)
procedure DebugLn; overload;
procedure DebugLn(const s: string); overload;
procedure DebugLn(const s1,s2: string); overload;
procedure DebugLn(const s1,s2,s3: string); overload;
procedure DebugLn(const s1,s2,s3,s4: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15: string); overload;
procedure DebugLn(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,s16: string); overload;

procedure DebugLnEnter(const s: string = ''); overload;
procedure DebugLnEnter(Args: array of const); overload;
procedure DebugLnEnter(s: string; Args: array of const); overload;
procedure DebugLnEnter(const s1, s2: string; const s3: string = '';
                     const s4: string = ''; const s5: string = ''; const s6: string = '';
                     const s7: string = ''; const s8: string = ''; const s9: string = '';
                     const s10: string = ''; const s11: string = ''; const s12: string = '';
                     const s13: string = ''; const s14: string = ''; const s15: string = '';
                     const s16: string = ''; const s17: string = ''; const s18: string = ''); overload;
procedure DebugLnExit(const s: string = ''); overload;
procedure DebugLnExit(Args: array of const); overload;
procedure DebugLnExit(s: string; Args: array of const); overload;
procedure DebugLnExit (const s1, s2: string; const s3: string = '';
                     const s4: string = ''; const s5: string = ''; const s6: string = '';
                     const s7: string = ''; const s8: string = ''; const s9: string = '';
                     const s10: string = ''; const s11: string = ''; const s12: string = '';
                     const s13: string = ''; const s14: string = ''; const s15: string = '';
                     const s16: string = ''; const s17: string = ''; const s18: string = ''); overload;

procedure DbgOut(const S: String; Args: array of const); overload;
procedure DbgOut(const s: string); overload;
procedure DbgOut(const s1,s2: string); overload;
procedure DbgOut(const s1,s2,s3: string); overload;
procedure DbgOut(const s1,s2,s3,s4: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7,s8: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7,s8,s9: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11: string); overload;
procedure DbgOut(const s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12: string); overload;

procedure CloseDebugOutput;
{$ENDIF}

function DbgS(const c: cardinal): string; overload; inline;
function DbgS(const i: longint): string; overload; inline;
function DbgS(const i: int64): string; overload; inline;
function DbgS(const q: qword): string; overload; inline;
function DbgS(const r: TRect): string; overload; inline;
function DbgS(const p: TPoint): string; overload; inline;
function DbgS(const p: pointer): string; overload; inline;
function DbgS(const e: extended; MaxDecimals: integer = 999): string; overload; inline;
function DbgS(const b: boolean): string; overload; inline;
function DbgS(const s: TComponentState): string; overload; inline;
function DbgS(const m: TMethod): string; overload; inline;
function DbgSName(const p: TObject): string; overload; inline;
function DbgSName(const p: TClass): string; overload; inline;
function DbgStr(const StringWithSpecialChars: string): string; overload; inline;
function DbgWideStr(const StringWithSpecialChars: widestring): string; overload; inline;
function dbgMemRange(P: PByte; Count: integer; Width: integer = 0): string; overload; inline;
function dbgMemStream(MemStream: TCustomMemoryStream; Count: integer): string; overload; inline;
function dbgObjMem(AnObject: TObject): string; overload; inline;
function dbgHex(i: Int64): string; overload; inline;
function DbgSWindowPosFlags(Flags: UInt): String;

function DbgS(const i1,i2,i3,i4: integer): string; overload; inline;
function DbgS(const Shift: TShiftState): string; overload; inline;
function DbgsVKCode(c: word): string;

function DbgS(const ASize: TSize): string; overload; inline;
function DbgS(const ATM: TTextMetric): string; overload;
function DbgS(const AScrollInfo: TScrollInfo): string; overload;
function DbgS(const AVariant: Variant): string; overload;

procedure DbgOutThreadLog(const Msg: string); overload;
procedure DebuglnThreadLog(const Msg: string); overload;
procedure DebuglnThreadLog(Args: array of const); overload;
procedure DebuglnThreadLog; overload;
procedure DbgSaveData(FileName: String; AData: PChar; ADataSize: PtrUInt);
procedure DbgAppendToFile(FileName, S: String);
procedure DbgAppendToFileWithoutLn(FileName, S: String);

// case..of utility functions
function ClassCase(const AClass: TClass; const ACase: array of TClass {; const ADescendant: Boolean = True}): Integer; overload;
function ClassCase(const AClass: TClass; const ACase: array of TClass; const ADescendant: Boolean): Integer; overload;

// MWE: define (missing) UTF16string similar to UTF8
//      strictly spoken, a widestring <> utf16string
// todo: use it in existing functions
type
  UTF16String = type UnicodeString;
  PUTF16String = ^UTF16String;

// Felipe: Don't substitute with calls to lazutf16 because lazutf16 includes
// some initialization code and tables, which are not necessary for the LCL
function UTF16CharacterLength(p: PWideChar): integer;
function UTF16Length(const s: UTF16String): PtrInt; inline;
function UTF16Length(p: PWideChar; WordCount: PtrInt): PtrInt;
function UTF16CharacterToUnicode(p: PWideChar; out CharLen: integer): Cardinal;
function UnicodeToUTF16(u: cardinal): UTF16String;

// identifier
function CreateFirstIdentifier(const Identifier: string): string;
function CreateNextIdentifier(const Identifier: string): string;
// Font
function IsFontNameDefault(const AName: string): boolean; inline;

{$IFDEF WithOldDebugln}
type
  TDebugLnProc = procedure (s: string) of object;

var
  DebugLnMaxNestPrefixLen: Integer = 15;
  DebugLnNestLvlIndent: Integer = 2;
  DebugText: ^Text;

  DebugLnProc: TDebugLnProc = nil;
  DebugOutProc: TDebugLnProc = nil;
{$ENDIF}

implementation

const
  {$IFDEF WithOldDebugln}
  Str_LCL_Debug_File = 'lcldebug.log';
  {$ENDIF}
  UNKNOWN_VK_PREFIX = 'Word(''';
  UNKNOWN_VK_POSTFIX = ''')';

var
  InterfaceInitializationHandlers: TFPList = nil;
  InterfaceFinalizationHandlers: TFPList = nil;
  {$IFDEF WithOldDebugln}
  DebugTextAllocated: boolean;
  DebugNestLvl: Integer = 0;
  DebugNestPrefix: PChar = nil;
  DebugNestAtBOL: Boolean;
  {$ENDIF}

function DeleteAmpersands(var Str : String) : Integer;
// Replace all &x with x and return the position of the first accelerator letter in
//  the resulting Str, meaning the letter following the first & in the original Str.
// Double ampersands && are converted to a single & and ignored.
var
  SrcPos, DestPos, SrcLen: Integer;
begin
  Result:=-1;
  SrcLen:=length(Str);
  SrcPos:=1;
  DestPos:=1;
  while SrcPos<=SrcLen do begin
    if (Str[SrcPos]='&') and (SrcPos<SrcLen) then
    begin
      inc(SrcPos); // skip &
      if (Str[SrcPos]<>'&') and (Result<1) then  // Ignore && as accelerator
        Result:=DestPos;
    end;
    if DestPos<SrcPos then
      Str[DestPos]:=Str[SrcPos];
    inc(SrcPos);
    inc(DestPos);
  end;
  if DestPos<SrcPos then
    SetLength(Str,DestPos-1);
end;

function RemoveAmpersands(const ASource: String): String;
var
  n: Integer;
  DoubleAmp: Boolean;
begin
  Result := ASource;
  n := 1;
  while n <= Length(Result) do
  begin
    if Result[n] = '&' then
    begin
      DoubleAmp := (n < Length(Result)) and (Result[n+1] = '&');
      Delete(Result, n, 1);
      if DoubleAmp then
        Inc(n);            // skip the second & of &&
    end;
    Inc(n);
  end;
end;

function RemoveAmpersands(Src: PChar; var LineLength: Longint): PChar;
var
  s: String;
begin
  SetLength(s, LineLength);
  strlcopy(PChar(s), Src, LineLength);
  s := RemoveAmpersands(s);
  LineLength := Length(s);
  Result := StrAlloc(LineLength+1); // +1 for #0 char at end
  strcopy(Result, PChar(s));
end;

//-----------------------------------------------------------------------------
// Keys and shortcuts

const
  // MS documentation:
  // https://msdn.microsoft.com/en-us/library/windows/desktop/dd375731(v=vs.85).aspx
  //
  // Note: ShortcutToText must ignore single key Ctrl, Alt, Shift, Win,
  // so these items have empty str here
  //
  KeyCodeStrings: array[0..$FF] of string = (
    'Unknown',
    'Mouse_Left', // 0x1 - VK_LBUTTON
    'Mouse_Right', // 0x2 - VK_RBUTTON
    'Cancel', // 0x3 - VK_CANCEL - generated by Ctrl+Break
    'Mouse_Middle', // 0x4 - VK_MBUTTON
    'Mouse_X1', // 0x5 - VK_XBUTTON1
    'Mouse_X2', // 0x6 - VK_XBUTTON2
    '', // 0x7
    'Backspace', // 0x8 - VK_BACK
    'Tab', // 0x9 - VK_TAB
    '', // 0xa
    '', // 0xb
    'NumClear', // 0xc - VK_CLEAR - generated by Num5 (NumLock off)
    'Enter', // 0xd - VK_RETURN
    '', // 0xe
    '', // 0xf
    '', //'Shift', // 0x10 - VK_SHIFT
    '', //'Ctrl', // 0x11 - VK_CONTROL
    '', //'Alt', // 0x12 - VK_MENU
    'Break', // 0x13 - VK_PAUSE - Pause/Break key
    'CapsLock', // 0x14 - VK_CAPITAL
    'IME_Kana', // 0x15 - VK_KANA
    '', // 0x16
    'IME_Junja', // 0x17 - VK_JUNJA
    'IME_final', // 0x18 - VK_FINAL
    'IME_Hanja', // 0x19 - VK_HANJA
    '', // 0x1a
    'Esc', // 0x1b - VK_ESCAPE
    'IME_convert', // 0x1c - VK_CONVERT
    'IME_nonconvert', // 0x1d - VK_NONCONVERT
    'IME_accept', // 0x1e - VK_ACCEPT
    'IME_mode_change', // 0x1f - VK_MODECHANGE
    'Space', // 0x20 - VK_SPACE
    'PgUp', // 0x21 - VK_PRIOR
    'PgDown', // 0x22 - VK_NEXT
    'End', // 0x23 - VK_END
    'Home', // 0x24 - VK_HOME
    'Left', // 0x25 - VK_LEFT
    'Up', // 0x26 - VK_UP
    'Right', // 0x27 - VK_RIGHT
    'Down', // 0x28 - VK_DOWN
    'Select', // 0x29 - VK_SELECT
    'Print', // 0x2a - VK_PRINT
    'Execute', // 0x2b - VK_EXECUTE
    'PrintScreen', // 0x2c - VK_SNAPSHOT
    'Ins', // 0x2d - VK_INSERT
    'Del', // 0x2e - VK_DELETE
    'Help', // 0x2f - VK_HELP
    '0', // 0x30
    '1', // 0x31
    '2', // 0x32
    '3', // 0x33
    '4', // 0x34
    '5', // 0x35
    '6', // 0x36
    '7', // 0x37
    '8', // 0x38
    '9', // 0x39
    '', // 0x3a
    '', // 0x3b
    '', // 0x3c
    '', // 0x3d
    '', // 0x3e
    '', // 0x3f
    '', // 0x40
    'A', // 0x41
    'B', // 0x42
    'C', // 0x43
    'D', // 0x44
    'E', // 0x45
    'F', // 0x46
    'G', // 0x47
    'H', // 0x48
    'I', // 0x49
    'J', // 0x4a
    'K', // 0x4b
    'L', // 0x4c
    'M', // 0x4d
    'N', // 0x4e
    'O', // 0x4f
    'P', // 0x50
    'Q', // 0x51
    'R', // 0x52
    'S', // 0x53
    'T', // 0x54
    'U', // 0x55
    'V', // 0x56
    'W', // 0x57
    'X', // 0x58
    'Y', // 0x59
    'Z', // 0x5a
    '', //'LWindows', // 0x5b - VK_LWIN
    '', //'RWindows', // 0x5c - VK_RWIN
    'PopUp', // 0x5d - VK_APPS - PC, key near right Ctrl
    '', // 0x5e
    'Sleep', // 0x5f - VK_SLEEP
    'Num0', // 0x60 - VK_NUMPAD0
    'Num1', // 0x61
    'Num2', // 0x62
    'Num3', // 0x63
    'Num4', // 0x64
    'Num5', // 0x65
    'Num6', // 0x66
    'Num7', // 0x67
    'Num8', // 0x68
    'Num9', // 0x69 - VK_NUMPAD9
    'NumMul', // 0x6a - VK_MULTIPLY
    'NumPlus', // 0x6b - VK_ADD
    'NumSepar', // 0x6c - VK_SEPARATOR
    'NumMinus', // 0x6d - VK_SUBTRACT
    'NumDot', // 0x6e - VK_DECIMAL
    'NumDiv', // 0x6f - VK_DIVIDE
    'F1', // 0x70 - VK_F1
    'F2', // 0x71
    'F3', // 0x72
    'F4', // 0x73
    'F5', // 0x74
    'F6', // 0x75
    'F7', // 0x76
    'F8', // 0x77
    'F9', // 0x78
    'F10', // 0x79
    'F11', // 0x7a
    'F12', // 0x7b
    'F13', // 0x7c
    'F14', // 0x7d
    'F15', // 0x7e
    'F16', // 0x7f
    'F17', // 0x80
    'F18', // 0x81
    'F19', // 0x82
    'F20', // 0x83
    'F21', // 0x84
    'F22', // 0x85
    'F23', // 0x86
    'F24', // 0x87 - VK_F24
    '', // 0x88
    '', // 0x89
    '', // 0x8a
    '', // 0x8b
    '', // 0x8c
    '', // 0x8d
    '', // 0x8e
    '', // 0x8f
    'NumLock', // 0x90 - VK_NUMLOCK
    'ScrollLock', // 0x91 - VK_SCROLL
    'OEM_0x92', // 0x92
    'OEM_0x93', // 0x93
    'OEM_0x94', // 0x94
    'OEM_0x95', // 0x95
    'OEM_0x96', // 0x96
    '', // 0x97
    '', // 0x98
    '', // 0x99
    '', // 0x9a
    '', // 0x9b
    '', // 0x9c
    '', // 0x9d
    '', // 0x9e
    '', // 0x9f
    '', //'LShift', // 0xa0 - VK_LSHIFT
    '', //'RShift', // 0xa1 - VK_RSHIFT
    '', //'LCtrl', // 0xa2 - VK_LCONTROL
    '', //'RCtrl', // 0xa3 - VK_RCONTROL
    '', //'LAlt', // 0xa4 - VK_LMENU
    '', //'RAlt', // 0xa5 - VK_RMENU
    'BrowserBack', // 0xa6 - VK_BROWSER_BACK
    'BrowserForward', // 0xa7 - VK_BROWSER_FORWARD
    'BrowserRefresh', // 0xa8 - VK_BROWSER_REFRESH
    'BrowserStop', // 0xa9 - VK_BROWSER_STOP
    'BrowserSearch', // 0xaa - VK_BROWSER_SEARCH
    'BrowserFav', // 0xab - VK_BROWSER_FAVORITES
    'BrowserHome', // 0xac - VK_BROWSER_HOME
    'VolumeMute', // 0xad - VK_VOLUME_MUTE
    'VolumeDown', // 0xae - VK_VOLUME_DOWN
    'VolumeUp', // 0xaf - VK_VOLUME_UP
    'MediaNext', // 0xb0 - VK_MEDIA_NEXT_TRACK
    'MediaPrev', // 0xb1 - VK_MEDIA_PREV_TRACK
    'MediaStop', // 0xb2 - VK_MEDIA_STOP
    'MediaPlayPause', // 0xb3 - VK_MEDIA_PLAY_PAUSE
    'LaunchMail', // 0xb4 - VK_LAUNCH_MAIL
    'LaunchMedia', // 0xb5 - VK_LAUNCH_MEDIA_SELECT
    'LaunchApp1', // 0xb6 - VK_LAUNCH_APP1
    'LaunchApp2', // 0xb7 - VK_LAUNCH_APP2
    '', // 0xb8
    '', // 0xb9
    ';', // 0xba - VK_OEM_1 - Can vary by keyboard, US keyboard, the ';:' key
    '=', // 0xbb - VK_OEM_PLUS - For any country/region, the '+/=' key Delphi returns '=' Issue #0036489
    ',', // 0xbc - VK_OEM_COMMA - For any country/region, the ',' key
    '-', // 0xbd - VK_OEM_MINUS - For any country/region, the '-' key
    '.', // 0xbe - VK_OEM_PERIOD - For any country/region, the '.' key
    '/', // 0xbf - VK_OEM_2 - Can vary by keyboard, US keyboard, the '/?' key
    '`', // 0xc0 - VK_OEM_3 - Can vary by keyboard, US keyboard, the '`~' key
    '', // 0xc1
    '', // 0xc2
    '', // 0xc3
    '', // 0xc4
    '', // 0xc5
    '', // 0xc6
    '', // 0xc7
    '', // 0xc8
    '', // 0xc9
    '', // 0xca
    '', // 0xcb
    '', // 0xcc
    '', // 0xcd
    '', // 0xce
    '', // 0xcf
    '', // 0xd0
    '', // 0xd1
    '', // 0xd2
    '', // 0xd3
    '', // 0xd4
    '', // 0xd5
    '', // 0xd6
    '', // 0xd7
    '', // 0xd8
    '', // 0xd9
    '', // 0xda
    '[', // 0xdb - VK_OEM_4 - Can vary by keyboard, US keyboard, the '[{' key
    '\', // 0xdc - VK_OEM_5 - Can vary by keyboard, US keyboard, the '\|' key
    ']', // 0xdd - VK_OEM_6 - Can vary by keyboard, US keyboard, the ']}' key
    '''', // 0xde - VK_OEM_7 - Can vary by keyboard, US keyboard, the 'single-quote/double-quote' key
    'OEM_8', // 0xdf - VK_OEM_8
    '', // 0xe0
    'OEM_0xE1', // 0xe1
    'OEM_Backslash', // 0xe2 - VK_OEM_102 - Either the angle bracket key or the backslash key on the RT 102-key keyboard
    'OEM_0xE3', // 0xe3
    'OEM_0xE4', // 0xe4
    'IME_process', // 0xe5 - VK_PROCESSKEY
    'OEM_0xE6', // 0xe6
    'UnicodePacket', // 0xe7 - VK_PACKET
    '', // 0xe8
    'OEM_0xE9', // 0xe9
    'OEM_0xEA', // 0xea
    'OEM_0xEB', // 0xeb
    'OEM_0xEC', // 0xec
    'OEM_0xED', // 0xed
    'OEM_0xEE', // 0xee
    'OEM_0xEF', // 0xef
    'OEM_0xF0', // 0xf0
    'OEM_0xF1', // 0xf1
    'OEM_0xF2', // 0xf2
    'OEM_0xF3', // 0xf3
    'OEM_0xF4', // 0xf4
    'OEM_0xF5', // 0xf5
    'Attn', // 0xf6 - VK_ATTN
    'CrSel', // 0xf7 - VK_CRSEL
    'ExSel', // 0xf8 - VK_EXSEL
    'EraseEOF', // 0xf9 - VK_EREOF
    'Play', // 0xfa - VK_PLAY
    'Zoom', // 0xfb - VK_ZOOM
    '', // 0xfc
    'PA1', // 0xfd - VK_PA1
    'OEM_Clear', // 0xfe - VK_OEM_CLEAR
    '' // 0xff
  );


function CompareDebugLCLItemInfos(Data1, Data2: Pointer): integer;
begin
  Result:={%H-}ComparePointers(TDebugLCLItemInfo(Data1).Item,
                          TDebugLCLItemInfo(Data2).Item);
end;

function CompareItemWithDebugLCLItemInfo(Item, DebugItemInfo: Pointer): integer;
begin
  Result:={%H-}ComparePointers(Item,TDebugLCLItemInfo(DebugItemInfo).Item);
end;

function KeyCodeToKeyString(Key: TShortCut; Localized: boolean): string;
begin
  if Key <= High(KeyCodeStrings) then
  begin
    if Localized then
      case Key of
        VK_UNKNOWN: Result:=ifsVK_UNKNOWN;
        VK_BACK: Result:=SmkcBkSp;
        VK_TAB: Result:=SmkcTab;
        VK_ESCAPE: Result:=SmkcEsc;
        VK_RETURN: Result:=SmkcEnter;
        VK_SPACE: Result:=SmkcSpace;
        VK_PRIOR: Result:=SmkcPgUp;
        VK_NEXT: Result:=SmkcPgDn;
        VK_END: Result:=SmkcEnd;
        VK_HOME: Result:=SmkcHome;
        VK_LEFT: Result:=SmkcLeft;
        VK_UP: Result:=SmkcUp;
        VK_RIGHT: Result:=SmkcRight;
        VK_DOWN: Result:=SmkcDown;
        VK_INSERT: Result:=SmkcIns;
        VK_DELETE: Result:=SmkcDel;
        VK_HELP: Result:=ifsVK_HELP;
        // must ignore single Shift, Alt, Ctrl in KeyCodeStrings
        //VK_SHIFT: Result:=SmkcShift;
        //VK_CONTROL: Result:=SmkcCtrl;
        //VK_MENU: Result:=SmkcAlt;
      otherwise
        Result := KeyCodeStrings[Key];
      end
    else
      Result := KeyCodeStrings[Key];
  end
  else
    case Key of
      scMeta: if Localized then Result:=SmkcMeta else Result:='Meta+';
      scShift: if Localized then Result:=SmkcShift else Result:='Shift+';
      scCtrl: if Localized then Result:=SmkcCtrl else Result:='Ctrl+';
      scAlt: if Localized then Result:=SmkcAlt else Result:='Alt+';
    otherwise
      Result:='';
    end;
end;

// Used also by TWidgetSet.GetAcceleratorString
function KeyAndShiftStateToKeyString(Key: word; ShiftState: TShiftState): String;

  procedure AddPart(const APart: string);
  begin
    if Result <> '' then
      Result := Result + '+';
    Result := Result + APart;
  end;

var
  s: string;
begin
  Result := '';
  if ssCtrl in ShiftState then AddPart(ifsCtrl);
  if ssAlt in ShiftState then AddPart(ifsAlt);
  if ssShift in ShiftState then AddPart(ifsVK_SHIFT);
  if ssMeta in ShiftState then
    {$IFDEF LCLcarbon}
    AddPart(ifsVK_CMD);
    {$ELSE}
    AddPart(ifsVK_META);
    {$ENDIF}
  if ssSuper in ShiftState then AddPart(ifsVK_SUPER);

  s := KeyCodeToKeyString(Key, true);
  // function returned "Word(nnn)" previously, keep this
  if s = '' then
    s := UNKNOWN_VK_PREFIX + IntToStr(Key) + UNKNOWN_VK_POSTFIX;
  AddPart(s);
end;

function KeyStringIsIrregular(const s: string): boolean;
begin
  Result:=(length(UNKNOWN_VK_PREFIX)<length(s)) and
    (AnsiStrLComp(PChar(s),PChar(UNKNOWN_VK_PREFIX),length(UNKNOWN_VK_PREFIX))=0);
end;

function ShortCutToTextGeneric(ShortCut: TShortCut; Localized: boolean): string;
var
  Name: string;
begin
  Result := '';
  Name := KeyCodeToKeyString(ShortCut and $FF, Localized);
  if Name <> '' then
  begin
    if ShortCut and scShift <> 0 then Result := Result + KeyCodeToKeyString(scShift, Localized);
    if ShortCut and scCtrl <> 0 then Result := Result + KeyCodeToKeyString(scCtrl, Localized);
    if ShortCut and scMeta <> 0 then Result := Result + KeyCodeToKeyString(scMeta, Localized);
    if ShortCut and scAlt <> 0 then Result := Result + KeyCodeToKeyString(scAlt, Localized);
    Result := Result + Name;
  end;
end;

function ShortCutToText(ShortCut: TShortCut): string;
begin
  Result:=ShortCutToTextGeneric(ShortCut, true);
end;

function ShortCutToTextRaw(ShortCut: TShortCut): string;
begin
  Result:=ShortCutToTextGeneric(ShortCut, false);
end;

function TextToShortCutGeneric(const ShortCutText: string; Localized: boolean): TShortCut;

  function CompareFront(var StartPos: integer; const Front: string): Boolean;
  begin
    if (Front<>'') and (StartPos+length(Front)-1<=length(ShortCutText))
    and (AnsiStrLIComp(@ShortCutText[StartPos], PChar(Front), Length(Front))= 0)
    then begin
      Result:=true;
      inc(StartPos,length(Front));
    end else
      Result:=false;
  end;

var
  Key: TShortCut;
  Shift: TShortCut;
  StartPos: integer;
  Name: string;
begin
  Result := 0;
  if ShortCutText = '' then Exit;
  Shift := 0;
  StartPos := 1;
  while True do
  begin
    if CompareFront(StartPos, KeyCodeToKeyString(scShift, Localized)) then
      Shift := Shift or scShift
    else if CompareFront(StartPos, '^') then
      Shift := Shift or scCtrl
    else if CompareFront(StartPos, KeyCodeToKeyString(scCtrl, Localized)) then
      Shift := Shift or scCtrl
    else if CompareFront(StartPos, KeyCodeToKeyString(scAlt, Localized)) then
      Shift := Shift or scAlt
    else if CompareFront(StartPos, KeyCodeToKeyString(scMeta, Localized)) then
      Shift := Shift or scMeta
    else
      Break;
  end;

  for Key := Low(KeyCodeStrings) to High(KeyCodeStrings) do
  begin
    Name := KeyCodeToKeyString(Key, Localized);
    if (Name<>'') and (length(Name)=length(ShortCutText)-StartPos+1)
    and (AnsiStrLIComp(@ShortCutText[StartPos], PChar(Name), length(Name)) = 0)
    then begin
      Result := Key or Shift;
      Exit;
    end;
  end;
end;

function TextToShortCut(const ShortCutText: string): TShortCut;
begin
  Result:=TextToShortCutGeneric(ShortCutText, true);
end;

function TextToShortCutRaw(const ShortCutText: string): TShortCut;
begin
  Result:=TextToShortCutGeneric(ShortCutText, false);
end;

function GetCompleteText(const sText: string; iSelStart: Integer;
  bCaseSensitive, bSearchAscending: Boolean; slTextList: TStrings): string;

  function IsSamePrefix(const sCompareText, sPrefix: string; iStart: Integer;
    var ResultText: string): Boolean;
  var
    sTempText: string;
  begin
    Result := False;
    sTempText := UTF8Copy(sCompareText, 1, iStart);
    if not bCaseSensitive then
      sTempText := UTF8UpperCase(sTempText);
    if (sTempText = sPrefix) then
    begin
      ResultText := sCompareText;
      Result := True;
    end;
  end;

var
  i: Integer;
  sPrefixText: string;
begin
  //DebugLn(['GetCompleteText sText=',sText,' iSelStart=',iSelStart,' bCaseSensitive=',bCaseSensitive,' bSearchAscending=',bSearchAscending,' slTextList.Count=',slTextList.Count]);
  Result := sText;//Default to return original text if no identical text are found
  if (sText = '') then Exit;//Everything is compatible with nothing, Exit.
  if (iSelStart = 0) then Exit;//Cursor at beginning
  if (slTextList.Count = 0) then Exit;//No text list to search for idtenticals, Exit.
  sPrefixText := UTF8Copy(sText, 1, iSelStart);//Get text from beginning to cursor position.
  if not bCaseSensitive then
    sPrefixText := UTF8UpperCase(sPrefixText);
  if bSearchAscending then
  begin
    for i := 0 to slTextList.Count - 1 do
      if IsSamePrefix(slTextList[i], sPrefixText, iSelStart, Result) then
        break;
  end else
  begin
    for i := slTextList.Count - 1 downto 0 do
      if IsSamePrefix(slTextList[i], sPrefixText, iSelStart, Result) then
        break;
  end;
end;

function IsEditableTextKey(Key: Word): Boolean;
begin
  Result := Key in [
      VK_A..VK_Z,
      VK_0..VK_9,
      VK_NUMPAD0..VK_DIVIDE,
      VK_OEM_1..VK_OEM_3,
      VK_OEM_4..VK_OEM_7
  ];
end;

function SendApplicationMessage(Msg: Cardinal; WParam: WParam; LParam: LParam
  ): Longint;
begin
  if SendApplicationMessageFunction<>nil then
    Result:=SendApplicationMessageFunction(Msg, WParam, LParam)
  else
    Result:=0;
end;

procedure OwnerFormDesignerModified(AComponent: TComponent);
begin
  if ([csDesigning,csLoading,csDestroying]*AComponent.ComponentState=[csDesigning])
  then begin
    if OwnerFormDesignerModifiedProc<>nil then
      OwnerFormDesignerModifiedProc(AComponent);
  end;
end;

function OffSetRect(var ARect: TRect; dx,dy: Integer): Boolean;
Begin
  with ARect do
  begin
    Left := Left + dx;
    Right := Right + dx;
    Top := Top + dy;
    Bottom := Bottom + dy;
  end;
  Result := (ARect.Left >= 0) and (ARect.Top >= 0);
end;

procedure FreeThenNil(var obj);
begin
  LazUtilities.FreeThenNil(obj);
end;

procedure RegisterInterfaceInitializationHandler(p: TProcedure);
begin
  InterfaceInitializationHandlers.Add(p);
end;

procedure CallInterfaceInitializationHandlers;
var
  i: Integer;
begin
  for i:=0 to InterfaceInitializationHandlers.Count-1 do
    TProcedure(InterfaceInitializationHandlers[i])();
end;

procedure RegisterInterfaceFinalizationHandler(p: TProcedure);
begin
  InterfaceFinalizationHandlers.Add(p);
end;

procedure CallInterfaceFinalizationHandlers;
var
  i: Integer;
begin
  for i:=InterfaceFinalizationHandlers.Count-1 downto 0 do
    TProcedure(InterfaceFinalizationHandlers[i])();
end;

procedure MoveRect(var ARect: TRect; x, y: Integer);
begin
  inc(ARect.Right,x-ARect.Left);
  inc(ARect.Bottom,y-ARect.Top);
  ARect.Left:=x;
  ARect.Top:=y;
end;

procedure MoveRectToFit(var ARect: TRect; const MaxRect: TRect);
// move ARect, so it fits into MaxRect
// if MaxRect is too small, ARect is resized.
begin
  if ARect.Left<MaxRect.Left then begin
    // move rectangle right
    ARect.Right:=Min(ARect.Right+MaxRect.Left-ARect.Left,MaxRect.Right);
    ARect.Left:=MaxRect.Left;
  end;
  if ARect.Top<MaxRect.Top then begin
    // move rectangle down
    ARect.Bottom:=Min(ARect.Bottom+MaxRect.Top-ARect.Top,MaxRect.Bottom);
    ARect.Top:=MaxRect.Top;
  end;
  if ARect.Right>MaxRect.Right then begin
    // move rectangle left
    ARect.Left:=Max(ARect.Left-ARect.Right+MaxRect.Right,MaxRect.Left);
    ARect.Right:=MaxRect.Right;
  end;
  if ARect.Bottom>MaxRect.Bottom then begin
    // move rectangle left
    ARect.Top:=Max(ARect.Top-ARect.Bottom+MaxRect.Bottom,MaxRect.Top);
    ARect.Bottom:=MaxRect.Bottom;
  end;
end;

procedure MakeMinMax(var i1, i2: integer);
var
  h: Integer;
begin
  if i1>i2 then begin
    h:=i1;
    i1:=i2;
    i2:=h;
  end;
end;

procedure CalculateLeftTopWidthHeight(X1, Y1, X2, Y2: integer;
  out Left, Top, Width, Height: integer);
begin
  if X1 <= X2 then 
   begin
    Left := X1;
    Width := X2 - X1;
  end 
  else 
  begin
    Left := X2;
    Width := X1 - X2;
  end;
  if Y1 <= Y2 then 
  begin
    Top := Y1;
    Height := Y2 - Y1;
  end 
  else 
  begin
    Top := Y2;
    Height := Y1 - Y2;
  end;
end;

function CompareHandles(h1, h2: THandle): integer;
begin
  if h1>h2 then
    Result:=1
  else if h1<h2 then
    Result:=-1
  else
    Result:=0;
end;

function CompareRect(R1, R2: PRect): Boolean;
begin
  Result:=(R1^.Left=R2^.Left) and (R1^.Top=R2^.Top) and
          (R1^.Bottom=R2^.Bottom) and (R1^.Right=R2^.Right);
  {if not Result then begin
    DebugLn(' DIFFER: ',R1^.Left,',',R1^.Top,',',R1^.Right,',',R1^.Bottom
      ,' <> ',R2^.Left,',',R2^.Top,',',R2^.Right,',',R2^.Bottom);
  end;}
end;

function ComparePoints(const p1, p2: TPoint): integer;
begin
  if p1.Y>p2.Y then
    Result:=1
  else if p1.Y<p2.Y then
    Result:=-1
  else if p1.X>p2.X then
    Result:=1
  else if p1.X<p2.X then
    Result:=-1
  else
    Result:=0;
end;

function CompareCaret(const FirstCaret, SecondCaret: TPoint): integer;
begin
  if (FirstCaret.Y<SecondCaret.Y) then
    Result:=1
  else if (FirstCaret.Y>SecondCaret.Y) then
    Result:=-1
  else if (FirstCaret.X<SecondCaret.X) then
    Result:=1
  else if (FirstCaret.X>SecondCaret.X) then
    Result:=-1
  else
    Result:=0;
end;

function CompareMethods(m1, m2: TMethod): boolean;
begin
  Result:=LazMethodList.CompareMethods(m1, m2);
end;

function ComparePointers(p1, p2: Pointer): integer;
begin
  Result:=LazUtilities.ComparePointers(p1, p2);
end;

function RoundToInt(e: Extended): integer;
begin
  Result:=LazUtilities.RoundToInt(e);
end;

function RoundToCardinal(e: Extended): cardinal;
begin
  Result:=LazUtilities.RoundToCardinal(e);
end;

function TruncToInt(e: Extended): integer;
begin
  Result:=LazUtilities.TruncToInt(e);
end;

function TruncToCardinal(e: Extended): cardinal;
begin
  Result:=LazUtilities.TruncToCardinal(e);
end;

function StrToDouble(const s: string): double;
begin
  Result:=LazUtilities.StrToDouble(s);
end;

procedure MergeSort(List: TFPList; const OnCompare: TListSortCompare);
begin
  if List=nil then exit;
  MergeSort(List,0,List.Count-1,OnCompare);
end;

procedure MergeSort(List: TFPList; StartIndex, EndIndex: integer;
  const OnCompare: TListSortCompare);
// sort so that for each i is OnCompare(List[i],List[i+1])<=0
var
  MergeList: PPointer;

  procedure SmallSort(StartPos, EndPos: PtrInt);
  // use insertion sort for small lists
  var
    i: PtrInt;
    Best: PtrInt;
    j: PtrInt;
    Item: Pointer;
  begin
    for i:=StartPos to EndPos-1 do begin
      Best:=i;
      for j:=i+1 to EndPos do
        if OnCompare(List[Best],List[j])>0 then
          Best:=j;
      if Best>i then begin
        Item:=List[i];
        List[i]:=List[Best];
        List[Best]:=Item;
      end;
    end;
  end;

  procedure Merge(Pos1, Pos2, Pos3: PtrInt);
  // merge two sorted arrays
  // the first array ranges Pos1..Pos2-1, the second ranges Pos2..Pos3
  var Src1Pos,Src2Pos,DestPos,cmp,a:PtrInt;
  begin
    while (Pos3>=Pos2) and (OnCompare(List[Pos2-1],List[Pos3])<=0) do
      dec(Pos3);
    if (Pos1>=Pos2) or (Pos2>Pos3) then exit;
    Src1Pos:=Pos2-1;
    Src2Pos:=Pos3;
    DestPos:=Pos3;
    while (Src2Pos>=Pos2) and (Src1Pos>=Pos1) do begin
      cmp:=OnCompare(List[Src1Pos],List[Src2Pos]);
      if cmp>0 then begin
        MergeList[DestPos]:=List[Src1Pos];
        dec(Src1Pos);
      end else begin
        MergeList[DestPos]:=List[Src2Pos];
        dec(Src2Pos);
      end;
      dec(DestPos);
    end;
    while Src2Pos>=Pos2 do begin
      MergeList[DestPos]:=List[Src2Pos];
      dec(Src2Pos);
      dec(DestPos);
    end;
    for a:=DestPos+1 to Pos3 do
      List[a]:=MergeList[a];
  end;

  procedure Sort(StartPos, EndPos: PtrInt);
  // sort an interval in List. Use MergeList as work space.
  var
    mid: integer;
  begin
    if EndPos-StartPos<6 then begin
      SmallSort(StartPos,EndPos);
    end else begin
      mid:=(StartPos+EndPos) shr 1;
      Sort(StartPos,mid);
      Sort(mid+1,EndPos);
      Merge(StartPos,mid+1,EndPos);
    end;
  end;

var
  Cnt: Integer;
begin
  if (List=nil) then exit;
  Cnt:=List.Count;
  if StartIndex<0 then StartIndex:=0;
  if EndIndex>=Cnt then EndIndex:=Cnt-1;
  if StartIndex>=EndIndex then exit;
  MergeList:=GetMem(List.Count*SizeOf(Pointer));
  Sort(StartIndex,EndIndex);
  Freemem(MergeList);
end;

procedure MergeSort(List: TStrings; const OnCompare: TStringsSortCompare);
// sort so that for each i is OnCompare(List[i],List[i+1])<=0
var
  MergeList: PAnsiString;

  procedure SmallSort(StartPos, EndPos: PtrInt);
  // use insertion sort for small lists
  var
    i: PtrInt;
    Best: PtrInt;
    j: PtrInt;
    Item: string;
  begin
    for i:=StartPos to EndPos-1 do begin
      Best:=i;
      for j:=i+1 to EndPos do
        if OnCompare(List[Best],List[j])>0 then
          Best:=j;
      if Best>i then begin
        Item:=List[i];
        List[i]:=List[Best];
        List[Best]:=Item;
      end;
    end;
  end;

  procedure Merge(Pos1, Pos2, Pos3: PtrInt);
  // merge two sorted arrays
  // the first array ranges Pos1..Pos2-1, the second ranges Pos2..Pos3
  var Src1Pos,Src2Pos,DestPos,cmp,a:integer;
  begin
    while (Pos3>=Pos2) and (OnCompare(List[Pos2-1],List[Pos3])<=0) do
      dec(Pos3);
    if (Pos1>=Pos2) or (Pos2>Pos3) then exit;
    Src1Pos:=Pos2-1;
    Src2Pos:=Pos3;
    DestPos:=Pos3;
    while (Src2Pos>=Pos2) and (Src1Pos>=Pos1) do begin
      cmp:=OnCompare(List[Src1Pos],List[Src2Pos]);
      if cmp>0 then begin
        MergeList[DestPos]:=List[Src1Pos];
        dec(Src1Pos);
      end else begin
        MergeList[DestPos]:=List[Src2Pos];
        dec(Src2Pos);
      end;
      dec(DestPos);
    end;
    while Src2Pos>=Pos2 do begin
      MergeList[DestPos]:=List[Src2Pos];
      dec(Src2Pos);
      dec(DestPos);
    end;
    for a:=DestPos+1 to Pos3 do
      List[a]:=MergeList[a];
  end;

  procedure Sort(StartPos, EndPos: PtrInt);
  // sort an interval in List. Use MergeList as work space.
  var
    mid: integer;
  begin
    if EndPos-StartPos<6 then begin
      SmallSort(StartPos,EndPos);
    end else begin
      mid:=(StartPos+EndPos) shr 1;
      Sort(StartPos,mid);
      Sort(mid+1,EndPos);
      Merge(StartPos,mid+1,EndPos);
    end;
  end;

var
  CurSize: PtrInt;
  i: PtrInt;
begin
  if (List=nil) or (List.Count<=1) then exit;
  CurSize:=PtrInt(List.Count)*SizeOf(Pointer);
  MergeList:=GetMem(CurSize);
  FillChar(MergeList^,CurSize,0);
  Sort(0,List.Count-1);
  for i:=0 to List.Count-1 do MergeList[i]:='';
  Freemem(MergeList);
end;


// Debug funcs :

procedure RaiseGDBException(const Msg: string);
begin
  LazTracer.RaiseGDBException(Msg);
end;

{$IFnDEF WithOldDebugln}
procedure CloseDebugOutput;
begin
  DebugLogger.Finish;
end;

procedure DbgOut(const s: string);
begin
  DebugLogger.DbgOut(s);
end;

procedure DbgOut(Args: array of const);
begin
  DebugLogger.DbgOut(Args);
end;

procedure DbgOut(const S: String; Args: array of const);
begin
  DebugLogger.DbgOut(S, Args);
end;

procedure DbgOut(const s1, s2: string; const s3: string; const s4: string; const s5: string;
  const s6: string; const s7: string; const s8: string; const s9: string; const s10: string;
  const s11: string; const s12: string; const s13: string; const s14: string;
  const s15: string; const s16: string; const s17: string; const s18: string);
begin
  DebugLogger.DbgOut(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18);
end;

procedure DebugLn(const s: string);
begin
  DebugLogger.DebugLn(s);
end;

procedure DebugLn(Args: array of const);
begin
  DebugLogger.DebugLn(Args);
end;

procedure DebugLn(const S: String; Args: array of const);
begin
  DebugLogger.DebugLn(S, Args);
end;

procedure DebugLn(const s1, s2: string; const s3: string; const s4: string; const s5: string;
  const s6: string; const s7: string; const s8: string; const s9: string; const s10: string;
  const s11: string; const s12: string; const s13: string; const s14: string;
  const s15: string; const s16: string; const s17: string; const s18: string);
begin
  DebugLogger.DebugLn(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18);
end;

procedure DebugLnEnter(const s: string);
begin
  DebugLogger.DebugLnEnter(s);
end;

procedure DebugLnEnter(Args: array of const);
begin
  DebugLogger.DebugLnEnter(Args);
end;

procedure DebugLnEnter(s: string; Args: array of const);
begin
  DebugLogger.DebugLnEnter(s, Args);
end;

procedure DebugLnEnter(const s1, s2: string; const s3: string; const s4: string;
  const s5: string; const s6: string; const s7: string; const s8: string; const s9: string;
  const s10: string; const s11: string; const s12: string; const s13: string;
  const s14: string; const s15: string; const s16: string; const s17: string;
  const s18: string);
begin
  DebugLogger.DebugLnEnter(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18);
end;

procedure DebugLnExit(const s: string);
begin
  DebugLogger.DebugLnExit(s);
end;

procedure DebugLnExit(Args: array of const);
begin
  DebugLogger.DebugLnExit(Args);
end;

procedure DebugLnExit(s: string; Args: array of const);
begin
  DebugLogger.DebugLnExit(s, Args);
end;

procedure DebugLnExit(const s1, s2: string; const s3: string; const s4: string;
  const s5: string; const s6: string; const s7: string; const s8: string; const s9: string;
  const s10: string; const s11: string; const s12: string; const s13: string;
  const s14: string; const s15: string; const s16: string; const s17: string;
  const s18: string);
begin
  DebugLogger.DebugLnExit(s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13, s14, s15, s16, s17, s18);
end;


{$ELSE}

procedure InitializeDebugOutput;
var
  DebugFileName: string;

  function GetDebugFileName: string;
  const
    DebugLogStart = '--debug-log=';
    DebugLogStartLength = length(DebugLogStart);
  var
    i: integer;
    EnvVarName: string;
  begin
    Result := '';
    // first try to find the log file name in the command line parameters
    for i:= 1 to Paramcount do begin
      if copy(ParamStrUTF8(i),1, DebugLogStartLength)=DebugLogStart then begin
        Result := copy(ParamStrUTF8(i), DebugLogStartLength+1,
                   Length(ParamStrUTF8(i))-DebugLogStartLength);
      end;
    end;
    // if not found yet, then try to find in the environment variables
    if (length(result)=0) then begin
      EnvVarName:= ChangeFileExt(ExtractFileName(ParamStrUTF8(0)),'') + '_debuglog';
      Result := GetEnvironmentVariableUTF8(EnvVarName);
    end;
    if (length(result)>0) then
      Result := ExpandFileNameUTF8(Result);
  end;

var
  fm: Byte;
begin
  DebugText := nil;
  DebugFileName := GetDebugFileName;
  if (length(DebugFileName)>0) and
    (DirPathExists(ExtractFileDir(DebugFileName))) then
  begin
    fm:=Filemode;
    new(DebugText);
    try
      Filemode:=fmShareDenyNone;
      Assign(DebugText^, DebugFileName);
      if FileExistsUTF8(DebugFileName) then
        Append(DebugText^)
      else
        Rewrite(DebugText^);
    except
      Freemem(DebugText);
      DebugText := nil;
      // Add extra line ending: a dialog will be shown in windows gui application
      writeln(StdOut, 'Cannot open file: ', DebugFileName+LineEnding);
    end;
    Filemode:=fm;
  end;
  if DebugText=nil then
  begin
    if TextRec(Output).Mode=fmClosed then
      DebugText := nil
    else
      DebugText := @Output;
    DebugTextAllocated := false;
  end else
    DebugTextAllocated := true;
end;

procedure CloseDebugOutput;
begin
  if DebugTextAllocated then begin
    Close(DebugText^);
    Dispose(DebugText);
    DebugTextAllocated := false;
  end;
  DebugText := nil;
end;

procedure FinalizeDebugOutput;
begin
  CloseDebugOutput;
end;

procedure DebugLnNestCreatePrefix;
const
  CurrentLen: Integer = 0;
var
  s: String;
  NewLen: Integer;
begin
  NewLen := DebugNestLvl * DebugLnNestLvlIndent;
  if NewLen < 0 then NewLen := 0;
  if (NewLen >= DebugLnMaxNestPrefixLen) then begin
    NewLen := DebugLnMaxNestPrefixLen;
    s := IntToStr(DebugNestLvl);
    if length(s)+1 > NewLen then
      NewLen := length(s)+1;
  end else
    s := '';

  if NewLen > CurrentLen then
    ReAllocMem(DebugNestPrefix, NewLen+21);
  CurrentLen := NewLen+20;

  FillChar(DebugNestPrefix^, NewLen, ' ');
  if s <> '' then
    System.Move(s[1], DebugNestPrefix[0], length(s));

  if (NewLen >= DebugLnMaxNestPrefixLen) then
    DebugNestPrefix[DebugLnMaxNestPrefixLen] := #0
  else
    DebugNestPrefix[NewLen] := #0;
end;

procedure DebugLnNestFreePrefix;
begin
  if DebugNestPrefix <> nil then
    ReAllocMem(DebugNestPrefix, 0);
end;

procedure DumpStack;
begin
  if Assigned(DebugText) then
    Dump_Stack(DebugText^, get_frame);
end;

procedure DebugLn(Args: array of const);
var
  i: Integer;
begin
  for i:=Low(Args) to High(Args) do begin
    case Args[i].VType of
    vtInteger: DbgOut(dbgs(Args[i].vinteger));
    vtInt64: DbgOut(dbgs(Args[i].VInt64^));
    vtQWord: DbgOut(dbgs(Args[i].VQWord^));
    vtBoolean: DbgOut(dbgs(Args[i].vboolean));
    vtExtended: DbgOut(dbgs(Args[i].VExtended^));
{$ifdef FPC_CURRENCY_IS_INT64}
    // MWE:
    // fpc 2.x has troubles in choosing the right dbgs()
    // so we convert here
    vtCurrency: DbgOut(dbgs(int64(Args[i].vCurrency^)/10000, 4));
{$else}
    vtCurrency: DbgOut(dbgs(Args[i].vCurrency^));
{$endif}
    vtString: DbgOut(Args[i].VString^);
    vtAnsiString: DbgOut(AnsiString(Args[i].VAnsiString));
    vtChar: DbgOut(Args[i].VChar);
    vtPChar: DbgOut(Args[i].VPChar);
    vtPWideChar: DbgOut(Args[i].VPWideChar);
    vtWideChar: DbgOut(AnsiString(Args[i].VWideChar));
    vtWidestring: DbgOut(AnsiString(WideString(Args[i].VWideString)));
    vtUnicodeString: DbgOut(AnsiString(UnicodeString(Args[i].VUnicodeString)));
    vtObject: DbgOut(DbgSName(Args[i].VObject));
    vtClass: DbgOut(DbgSName(Args[i].VClass));
    vtPointer: DbgOut(Dbgs(Args[i].VPointer));
    else
      DbgOut('?unknown variant?');
    end;
  end;
  DebugLn;
end;

procedure DebugLn(const S: String; Args: array of const);
begin
  DebugLn(Format(S, Args));
end;

procedure DebugLn;
begin
  DebugLn('');
end;

procedure DebugLn(const s: string);
begin
  {$ifdef WinCE}
  if DebugNestAtBOL and (s <> '') then
    DbgAppendToFile(ExtractFilePath(ParamStr(0)) + Str_LCL_Debug_File, DebugNestPrefix+s)
  else
    DbgAppendToFile(ExtractFilePath(ParamStr(0)) + Str_LCL_Debug_File, s);
  {$else}
  // First of all verify if a widgetset has override DebugLn
  if DebugLnProc <> nil then
  begin
    DebugLnProc(s);
    Exit;
  end;

  // Now the default code
  if not Assigned(DebugText) then exit;
  if DebugNestAtBOL and (s <> '') then
    write(DebugText^, DebugNestPrefix);
  writeln(DebugText^, ConvertLineEndings(s));
  {$endif}
  DebugNestAtBOL := True;
end;

procedure DebugLn(const s1, s2: string);
begin
  DebugLn(s1+s2);
end;

procedure DebugLn(const s1, s2, s3: string);
begin
  DebugLn(s1+s2+s3);
end;

procedure DebugLn(const s1, s2, s3, s4: string);
begin
  DebugLn(s1+s2+s3+s4);
end;

procedure DebugLn(const s1, s2, s3, s4, s5: string);
begin
  DebugLn(s1+s2+s3+s4+s5);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11,
  s12: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12,
  s13: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13,
  s14: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13+s14);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13,
  s14, s15: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13+s14+s15);
end;

procedure DebugLn(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12, s13,
  s14, s15, s16: string);
begin
  DebugLn(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13+s14+s15+s16);
end;

procedure DebugLnEnter(const s: string);
begin
  if not DebugNestAtBOL then
    DebugLn;
  if s <> '' then
    DebugLn(s);
  inc(DebugNestLvl);
  DebugLnNestCreatePrefix;
end;

procedure DebugLnEnter(Args: array of const);
begin
  if not DebugNestAtBOL then
    DebugLn;
  DebugLn(Args);
  inc(DebugNestLvl);
  DebugLnNestCreatePrefix;
end;

procedure DebugLnEnter(s: string; Args: array of const);
begin
  DebugLnEnter(Format(s, Args));
end;

procedure DebugLnEnter(const s1: string; const s2: string; const s3: string;
  const s4: string; const s5: string; const s6: string; const s7: string;
  const s8: string; const s9: string; const s10: string; const s11: string;
  const s12: string; const s13: string; const s14: string; const s15: string;
  const s16: string; const s17: string; const s18: string);
begin
  DebugLnEnter(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13+s14+s15+s16+s17+s18);
end;

procedure DebugLnExit(const s: string);
begin
  dec(DebugNestLvl);
  if DebugNestLvl < 0 then DebugNestLvl := 0;
  DebugLnNestCreatePrefix;
  if not DebugNestAtBOL then
    DebugLn;
  if s <> '' then
    DebugLn(s);
end;

procedure DebugLnExit(Args: array of const);
begin
  dec(DebugNestLvl);
  if DebugNestLvl < 0 then DebugNestLvl := 0;
  DebugLnNestCreatePrefix;
  if not DebugNestAtBOL then
    DebugLn;
  DebugLn(Args);
end;

procedure DebugLnExit(s: string; Args: array of const);
begin
  DebugLnExit(Format(s, Args));
end;

procedure DebugLnExit(const s1: string; const s2: string; const s3: string;
  const s4: string; const s5: string; const s6: string; const s7: string;
  const s8: string; const s9: string; const s10: string; const s11: string;
  const s12: string; const s13: string; const s14: string; const s15: string;
  const s16: string; const s17: string; const s18: string);
begin
  DebugLnExit(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12+s13+s14+s15+s16+s17+s18);
end;

procedure DbgOut(const S: String; Args: array of const);
begin
  DbgOut(Format(S, Args));
end;

procedure DBGOut(const s: string);
begin
  {$ifdef WinCE}
  if DebugNestAtBOL and (s <> '') then
    DbgAppendToFileWithoutLn(ExtractFilePath(ParamStr(0)) + Str_LCL_Debug_File, DebugNestPrefix);
  DbgAppendToFileWithoutLn(ExtractFilePath(ParamStr(0)) + Str_LCL_Debug_File, s);
  {$else}
  if DebugOutProc <> nil then
  begin
    DebugOutProc(s);
    Exit;
  end;

  if Assigned(DebugText) then begin
    if DebugNestAtBOL and (s <> '') then
      write(DebugText^, DebugNestPrefix);
    write(DebugText^, s);
  end;
  {$endif}
  DebugNestAtBOL := (s = '') or (s[length(s)] in [#10,#13]);
end;

procedure DBGOut(const s1, s2: string);
begin
  DbgOut(s1+s2);
end;

procedure DbgOut(const s1, s2, s3: string);
begin
  DbgOut(s1+s2+s3);
end;

procedure DbgOut(const s1, s2, s3, s4: string);
begin
  DbgOut(s1+s2+s3+s4);
end;

procedure DbgOut(const s1, s2, s3, s4, s5: string);
begin
  DbgOut(s1+s2+s3+s4+s5);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7, s8: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7+s8);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7, s8, s9: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7+s8+s9);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11);
end;

procedure DbgOut(const s1, s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, s12: string);
begin
  DbgOut(s1+s2+s3+s4+s5+s6+s7+s8+s9+s10+s11+s12);
end;
{$ENDIF}

function DbgS(const c: cardinal): string;
begin
  Result:=LazLoggerBase.DbgS(c);
end;

function DbgS(const i: longint): string;
begin
  Result:=LazLoggerBase.DbgS(i);
end;

function DbgS(const i: int64): string;
begin
  Result:=LazLoggerBase.DbgS(i);
end;

function DbgS(const q: qword): string;
begin
  Result:=LazLoggerBase.DbgS(q);
end;

function DbgS(const r: TRect): string;
begin
  Result:=LazLoggerBase.DbgS(r);
end;

function DbgS(const p: TPoint): string;
begin
  Result:=LazLoggerBase.DbgS(p);
end;

function DbgS(const p: pointer): string;
begin
  Result:=LazLoggerBase.DbgS(p);
end;

function DbgS(const e: extended; MaxDecimals: integer): string;
begin
  Result:=LazLoggerBase.DbgS(e,MaxDecimals);
end;

function DbgS(const b: boolean): string;
begin
  Result:=LazLoggerBase.DbgS(b);
end;

function DbgS(const s: TComponentState): string;
begin
  Result:=LazLoggerBase.DbgS(s);
end;

function DbgS(const m: TMethod): string;
begin
  Result:=LazLoggerBase.DbgS(m);
end;

function DbgSName(const p: TObject): string;
begin
  Result:=LazLoggerBase.DbgSName(p);
end;

function DbgSName(const p: TClass): string;
begin
  Result:=LazLoggerBase.DbgSName(p);
end;

function DbgStr(const StringWithSpecialChars: string): string;
begin
  Result:=LazLoggerBase.DbgStr(StringWithSpecialChars);
end;

function DbgWideStr(const StringWithSpecialChars: widestring): string;
begin
  Result:=LazLoggerBase.DbgWideStr(StringWithSpecialChars);
end;

function dbgMemRange(P: PByte; Count: integer; Width: integer): string;
begin
  Result:=LazLoggerBase.dbgMemRange(P,Count,Width);
end;

function dbgMemStream(MemStream: TCustomMemoryStream; Count: integer): string;
begin
  Result:=LazLoggerBase.dbgMemStream(MemStream,Count);
end;

function dbgObjMem(AnObject: TObject): string;
begin
  Result:=LazLoggerBase.dbgObjMem(AnObject);
end;

function dbghex(i: Int64): string;
begin
  Result:=LazLoggerBase.dbghex(i);
end;

function DbgSWindowPosFlags(Flags: UInt): String;
begin
  Result := '';
  if (SWP_NOSIZE and Flags) <> 0 then
    Result := Result + 'SWP_NOSIZE, ';
  if (SWP_NOMOVE and Flags) <> 0 then
    Result := Result + 'SWP_NOMOVE, ';
  if (SWP_NOZORDER and Flags) <> 0 then
    Result := Result + 'SWP_NOZORDER, ';
  if (SWP_NOREDRAW and Flags) <> 0 then
    Result := Result + 'SWP_NOREDRAW, ';
  if (SWP_NOACTIVATE and Flags) <> 0 then
    Result := Result + 'SWP_NOACTIVATE, ';
  if (SWP_DRAWFRAME and Flags) <> 0 then
    Result := Result + 'SWP_DRAWFRAME, ';
  if (SWP_SHOWWINDOW and Flags) <> 0 then
    Result := Result + 'SWP_SHOWWINDOW, ';
  if (SWP_HIDEWINDOW and Flags) <> 0 then
    Result := Result + 'SWP_HIDEWINDOW, ';
  if (SWP_NOCOPYBITS and Flags) <> 0 then
    Result := Result + 'SWP_NOCOPYBITS, ';
  if (SWP_NOOWNERZORDER and Flags) <> 0 then
    Result := Result + 'SWP_NOOWNERZORDER, ';
  if (SWP_NOSENDCHANGING and Flags) <> 0 then
    Result := Result + 'SWP_NOSENDCHANGING, ';
  if (SWP_DEFERERASE and Flags) <> 0 then
    Result := Result + 'SWP_DEFERERASE, ';
  if (SWP_ASYNCWINDOWPOS and Flags) <> 0 then
    Result := Result + 'SWP_ASYNCWINDOWPOS, ';
  if (SWP_STATECHANGED and Flags) <> 0 then
    Result := Result + 'SWP_STATECHANGED, ';
  if (SWP_SourceIsInterface and Flags) <> 0 then
    Result := Result + 'SWP_SourceIsInterface, ';
  if Result <> '' then
    Delete(Result, Length(Result) - 1, 2);
end;

function DbgS(const i1, i2, i3, i4: integer): string;
begin
  Result:=LazLoggerBase.DbgS(i1,i2,i3,i4);
end;

function DbgS(const Shift: TShiftState): string;
begin
  Result:=LazLoggerBase.DbgS(Shift);
end;

function DbgsVKCode(c: word): string;
begin
  case c of
  VK_UNKNOWN: Result:='VK_UNKNOWN';
  VK_LBUTTON: Result:='VK_LBUTTON';
  VK_RBUTTON: Result:='VK_RBUTTON';
  VK_CANCEL: Result:='VK_CANCEL';
  VK_MBUTTON: Result:='VK_MBUTTON';
  VK_BACK: Result:='VK_BACK';
  VK_TAB: Result:='VK_TAB';
  VK_CLEAR: Result:='VK_CLEAR';
  VK_RETURN: Result:='VK_RETURN';
  VK_SHIFT: Result:='VK_SHIFT';
  VK_CONTROL: Result:='VK_CONTROL';
  VK_MENU: Result:='VK_MENU';
  VK_PAUSE: Result:='VK_PAUSE';
  VK_CAPITAL: Result:='VK_CAPITAL';
  VK_KANA: Result:='VK_KANA';
  VK_JUNJA: Result:='VK_JUNJA';
  VK_FINAL: Result:='VK_FINAL';
  VK_HANJA: Result:='VK_HANJA';
  VK_ESCAPE: Result:='VK_ESCAPE';
  VK_CONVERT: Result:='VK_CONVERT';
  VK_NONCONVERT: Result:='VK_NONCONVERT';
  VK_ACCEPT: Result:='VK_ACCEPT';
  VK_MODECHANGE: Result:='VK_MODECHANGE';
  VK_SPACE: Result:='VK_SPACE';
  VK_PRIOR: Result:='VK_PRIOR';
  VK_NEXT: Result:='VK_NEXT';
  VK_END: Result:='VK_END';
  VK_HOME: Result:='VK_HOME';
  VK_LEFT: Result:='VK_LEFT';
  VK_UP: Result:='VK_UP';
  VK_RIGHT: Result:='VK_RIGHT';
  VK_DOWN: Result:='VK_DOWN';
  VK_SELECT: Result:='VK_SELECT';
  VK_PRINT: Result:='VK_PRINT';
  VK_EXECUTE: Result:='VK_EXECUTE';
  VK_SNAPSHOT: Result:='VK_SNAPSHOT';
  VK_INSERT: Result:='VK_INSERT';
  VK_DELETE: Result:='VK_DELETE';
  VK_HELP: Result:='VK_HELP';

  VK_0: Result:='VK_0';
  VK_1: Result:='VK_1';
  VK_2: Result:='VK_2';
  VK_3: Result:='VK_3';
  VK_4: Result:='VK_4';
  VK_5: Result:='VK_5';
  VK_6: Result:='VK_6';
  VK_7: Result:='VK_7';
  VK_8: Result:='VK_8';
  VK_9: Result:='VK_9';

  VK_A: Result:='VK_A';
  VK_B: Result:='VK_B';
  VK_C: Result:='VK_C';
  VK_D: Result:='VK_D';
  VK_E: Result:='VK_E';
  VK_F: Result:='VK_F';
  VK_G: Result:='VK_G';
  VK_H: Result:='VK_H';
  VK_I: Result:='VK_I';
  VK_J: Result:='VK_J';
  VK_K: Result:='VK_K';
  VK_L: Result:='VK_L';
  VK_M: Result:='VK_M';
  VK_N: Result:='VK_N';
  VK_O: Result:='VK_O';
  VK_P: Result:='VK_P';
  VK_Q: Result:='VK_Q';
  VK_R: Result:='VK_R';
  VK_S: Result:='VK_S';
  VK_T: Result:='VK_T';
  VK_U: Result:='VK_U';
  VK_V: Result:='VK_V';
  VK_W: Result:='VK_W';
  VK_X: Result:='VK_X';
  VK_Y: Result:='VK_Y';
  VK_Z: Result:='VK_Z';

  VK_LWIN: Result:='VK_LWIN';
  VK_RWIN: Result:='VK_RWIN';
  VK_APPS: Result:='VK_APPS';
  VK_SLEEP: Result:='VK_SLEEP';

  VK_NUMPAD0: Result:='VK_NUMPAD0';
  VK_NUMPAD1: Result:='VK_NUMPAD1';
  VK_NUMPAD2: Result:='VK_NUMPAD2';
  VK_NUMPAD3: Result:='VK_NUMPAD3';
  VK_NUMPAD4: Result:='VK_NUMPAD4';
  VK_NUMPAD5: Result:='VK_NUMPAD5';
  VK_NUMPAD6: Result:='VK_NUMPAD6';
  VK_NUMPAD7: Result:='VK_NUMPAD7';
  VK_NUMPAD8: Result:='VK_NUMPAD8';
  VK_NUMPAD9: Result:='VK_NUMPAD9';
  VK_MULTIPLY: Result:='VK_MULTIPLY';
  VK_ADD: Result:='VK_ADD';
  VK_SEPARATOR: Result:='VK_SEPARATOR';
  VK_SUBTRACT: Result:='VK_SUBTRACT';
  VK_DECIMAL: Result:='VK_DECIMAL';
  VK_DIVIDE: Result:='VK_DIVIDE';
  VK_F1: Result:='VK_F1';
  VK_F2: Result:='VK_F2';
  VK_F3: Result:='VK_F3';
  VK_F4: Result:='VK_F4';
  VK_F5: Result:='VK_F5';
  VK_F6: Result:='VK_F6';
  VK_F7: Result:='VK_F7';
  VK_F8: Result:='VK_F8';
  VK_F9: Result:='VK_F9';
  VK_F10: Result:='VK_F10';
  VK_F11: Result:='VK_F11';
  VK_F12: Result:='VK_F12';
  VK_F13: Result:='VK_F13';
  VK_F14: Result:='VK_F14';
  VK_F15: Result:='VK_F15';
  VK_F16: Result:='VK_F16';
  VK_F17: Result:='VK_F17';
  VK_F18: Result:='VK_F18';
  VK_F19: Result:='VK_F19';
  VK_F20: Result:='VK_F20';
  VK_F21: Result:='VK_F21';
  VK_F22: Result:='VK_F22';
  VK_F23: Result:='VK_F23';
  VK_F24: Result:='VK_F24';

  VK_NUMLOCK: Result:='VK_NUMLOCK';
  VK_SCROLL: Result:='VK_SCROLL';

  VK_LSHIFT: Result:='VK_LSHIFT';
  VK_RSHIFT: Result:='VK_RSHIFT';
  VK_LCONTROL: Result:='VK_LCONTROL';
  VK_RCONTROL: Result:='VK_RCONTROL';
  VK_LMENU: Result:='VK_LMENU';
  VK_RMENU: Result:='VK_RMENU';

  VK_BROWSER_BACK: Result:='VK_BROWSER_BACK';
  VK_BROWSER_FORWARD: Result:='VK_BROWSER_FORWARD';
  VK_BROWSER_REFRESH: Result:='VK_BROWSER_REFRESH';
  VK_BROWSER_STOP: Result:='VK_BROWSER_STOP';
  VK_BROWSER_SEARCH: Result:='VK_BROWSER_SEARCH';
  VK_BROWSER_FAVORITES: Result:='VK_BROWSER_FAVORITES';
  VK_BROWSER_HOME: Result:='VK_BROWSER_HOME';
  VK_VOLUME_MUTE: Result:='VK_VOLUME_MUTE';
  VK_VOLUME_DOWN: Result:='VK_VOLUME_DOWN';
  VK_VOLUME_UP: Result:='VK_VOLUME_UP';
  VK_MEDIA_NEXT_TRACK: Result:='VK_MEDIA_NEXT_TRACK';
  VK_MEDIA_PREV_TRACK: Result:='VK_MEDIA_PREV_TRACK';
  VK_MEDIA_STOP: Result:='VK_MEDIA_STOP';
  VK_MEDIA_PLAY_PAUSE: Result:='VK_MEDIA_PLAY_PAUSE';
  VK_LAUNCH_MAIL: Result:='VK_LAUNCH_MAIL';
  VK_LAUNCH_MEDIA_SELECT: Result:='VK_LAUNCH_MEDIA_SELECT';
  VK_LAUNCH_APP1: Result:='VK_LAUNCH_APP1';
  VK_LAUNCH_APP2: Result:='VK_LAUNCH_APP2';
  // New keys in 0.9.31+
  VK_LCL_EQUAL: Result:='VK_LCL_EQUAL';
  VK_LCL_COMMA: Result:='VK_LCL_COMMA';
  VK_LCL_POINT: Result:='VK_LCL_POINT';
  VK_LCL_SLASH: Result:='VK_LCL_SLASH';
  VK_LCL_SEMI_COMMA:Result:='VK_LCL_SEMI_COMMA';
  VK_LCL_MINUS     :Result:='VK_LCL_MINUS';
  VK_LCL_OPEN_BRAKET:Result:='VK_LCL_OPEN_BRAKET';
  VK_LCL_CLOSE_BRAKET:Result:='VK_LCL_CLOSE_BRAKET';
  VK_LCL_BACKSLASH :Result:='VK_LCL_BACKSLASH';
  VK_LCL_TILDE     :Result:='VK_LCL_TILDE';
  VK_LCL_QUOTE     :Result:='VK_LCL_QUOTE';
  //
  VK_LCL_POWER: Result:='VK_LCL_POWER';
  VK_LCL_CALL: Result:='VK_LCL_CALL';
  VK_LCL_ENDCALL: Result:='VK_LCL_ENDCALL';
  VK_LCL_AT: Result:='VK_LCL_AT';
  else
    Result:='VK_('+dbgs(c)+')';
  end;
end;

function DbgS(const ASize: TSize): string;
begin
  Result:=LazLoggerBase.DbgS(ASize);
end;

function DbgS(const ATM: TTextMetric): string;
begin
  with ATM do
    Result :=
      'tmHeight: ' + DbgS(tmHeight) +
      ' tmAscent: ' + DbgS(tmAscent) +
      ' tmDescent: ' + DbgS(tmDescent) +
      ' tmInternalLeading: ' + DbgS(tmInternalLeading) +
      ' tmExternalLeading: ' + DbgS(tmExternalLeading) +
      ' tmAveCharWidth: ' + DbgS(tmAveCharWidth) +
      ' tmMaxCharWidth: ' + DbgS(tmMaxCharWidth) +
      ' tmWeight: ' + DbgS(tmWeight) +
      ' tmOverhang: ' + DbgS(tmOverhang) +
      ' tmDigitizedAspectX: ' + DbgS(tmDigitizedAspectX) +
      ' tmDigitizedAspectY: ' + DbgS(tmDigitizedAspectY) +
      ' tmFirstChar: ' + tmFirstChar +
      ' tmLastChar: ' + tmLastChar +
      ' tmDefaultChar: ' + tmDefaultChar +
      ' tmBreakChar: ' + tmBreakChar +
      ' tmItalic: ' + DbgS(tmItalic) +
      ' tmUnderlined: ' + DbgS(tmUnderlined) +
      ' tmStruckOut: ' + DbgS(tmStruckOut) +
      ' tmPitchAndFamily: ' + DbgS(tmPitchAndFamily) +
      ' tmCharSet: ' + DbgS(tmCharSet);
end;

function DbgS(const AScrollInfo: TScrollInfo): string;
begin
  Result := '';

  if (SIF_POS and AScrollInfo.fMask) > 0 then
    Result := 'Pos: ' + DbgS(AScrollInfo.nPos);
  if (SIF_RANGE and AScrollInfo.fMask) > 0 then
    Result := Result + ' Min: ' + DbgS(AScrollInfo.nMin) + ' Max: ' +
      DbgS(AScrollInfo.nMax);
  if (SIF_PAGE and AScrollInfo.fMask) > 0 then
    Result := Result + ' Page: ' + DbgS(AScrollInfo.nPage);
  if (SIF_TRACKPOS and AScrollInfo.fMask) > 0 then
    Result := Result + ' TrackPos: ' + DbgS(AScrollInfo.nTrackPos);

  if Result = '' then Result := '(no scrollinfo)';
end;

function DbgS(const AVariant: Variant): string;
begin
  if TVarData(AVariant).VType = varEmpty then
    result := '<empty>'
  else
  if TVarData(AVariant).vtype = varNull then
    result := '<null>'
  else
    result := AVariant;
end;

procedure DbgOutThreadLog(const Msg: string);
var
  PID: PtrInt;
  fs: TFileStream;
  Filename: string;
begin
  PID:=PtrInt(GetThreadID);
  Filename:='Log'+IntToStr(PID);
  if FileExistsUTF8(Filename) then
    fs:=TFileStream.Create(Filename,fmOpenWrite or fmShareDenyNone)
  else
    fs:=TFileStream.Create(Filename,fmCreate);
  fs.Position:=fs.Size;
  fs.Write(Msg[1], length(Msg));
  fs.Free;
end;

procedure DebuglnThreadLog(const Msg: string);
var
  PID: PtrInt;
begin
  PID:=PtrInt(GetThreadID);
  DbgOutThreadLog(IntToStr(PtrInt(PID))+' : '+Msg+LineEnding);
end;

procedure DebuglnThreadLog(Args: array of const);
var
  i: Integer;
  s: String;
begin
  s:='';
  for i:=Low(Args) to High(Args) do begin
    case Args[i].VType of
    vtInteger: s:=s+dbgs(Args[i].vinteger);
    vtInt64: s:=s+dbgs(Args[i].VInt64^);
    vtQWord: s:=s+dbgs(Args[i].VQWord^);
    vtBoolean: s:=s+dbgs(Args[i].vboolean);
    vtExtended: s:=s+dbgs(Args[i].VExtended^);
{$ifdef FPC_CURRENCY_IS_INT64}
    // MWE:
    // ppcppc 2.0.2 has troubles in choosing the right dbgs()
    // so we convert here (i don't know about other versions
    vtCurrency: s:=s+dbgs(int64(Args[i].vCurrency^)/10000, 4);
{$else}
    vtCurrency: s:=s+dbgs(Args[i].vCurrency^);
{$endif}
    vtString: s:=s+Args[i].VString^;
    vtAnsiString: s:=s+AnsiString(Args[i].VAnsiString);
    vtChar: s:=s+Args[i].VChar;
    vtPChar: s:=s+Args[i].VPChar;
    vtPWideChar: s:=AnsiString(WideString(s)+Args[i].VPWideChar);
    vtWideChar: s:=AnsiString(WideString(s)+Args[i].VWideChar);
    vtWidestring: s:=AnsiString(WideString(s)+WideString(Args[i].VWideString));
{$IF FPC_FULLVERSION>=20701}
    vtUnicodeString: s:=AnsiString(UnicodeString(s)+UnicodeString(Args[i].VUnicodeString));
{$endif}
    vtObject: s:=s+DbgSName(Args[i].VObject);
    vtClass: s:=s+DbgSName(Args[i].VClass);
    vtPointer: s:=s+Dbgs(Args[i].VPointer);
    else
      DbgOutThreadLog('?unknown variant?');
    end;
  end;
  DebuglnThreadLog(s);
end;

procedure DebuglnThreadLog;
begin
  DebuglnThreadLog('');
end;

procedure DbgSaveData(FileName: String; AData: PChar; ADataSize: PtrUInt);
var
  S: TStream;
begin
  S := TFileStream.Create(FileName, fmCreate);
  S.Write(AData^, ADataSize);
  S.Free;
end;

procedure DbgAppendToFile(FileName, S: String);
var
  F: TextFile;
begin
  AssignFile(F, FileName);
  {$I-}
  Append(F);
  if IOResult <> 0 then
    Rewrite(F);
  {$I+}
  WriteLn(F, S);
  CloseFile(F);
end;

procedure DbgAppendToFileWithoutLn(FileName, S: String);
var
  F: TextFile;
begin
  AssignFile(F, FileName);
  {$I-}
  Append(F);
  if IOResult <> 0 then
    Rewrite(F);
  {$I+}
  Write(F, S);
  CloseFile(F);
end;

function ClassCase(const AClass: TClass; const ACase: array of TClass {; const ADescendant: Boolean = True}): Integer;
begin
  Result := ClassCase(AClass, ACase, True);
end;

function ClassCase(const AClass: TClass; const ACase: array of TClass; const ADescendant: Boolean): Integer;
begin
  for Result := Low(ACase) to High(ACase) do
  begin
    if AClass = ACase[Result] then Exit;
    if not ADescendant then Continue;
    if AClass.InheritsFrom(ACase[Result]) then Exit;
  end;

  Result := -1;
end;

function UTF16CharacterLength(p: PWideChar): integer;
// returns length of UTF16 character in number of words
// The endianess of the machine will be taken.
begin
  if p<>nil then begin
    if (ord(p[0]) < $D800) or (ord(p[0]) > $DFFF) then
      Result:=1
    else
      Result:=2;
  end else begin
    Result:=0;
  end;
end;

function UTF16Length(const s: UTF16String): PtrInt;
begin
  Result:=UTF16Length(PWideChar(s),length(s));
end;

function UTF16Length(p: PWideChar; WordCount: PtrInt): PtrInt;
var
  CharLen: LongInt;
begin
  Result:=0;
  while (WordCount>0) do begin
    inc(Result);
    CharLen:=UTF16CharacterLength(p);
    inc(p,CharLen);
    dec(WordCount,CharLen);
  end;
end;

function UTF16CharacterToUnicode(p: PWideChar; out CharLen: integer): Cardinal;
var
  w1: cardinal;
  w2: Cardinal;
begin
  if p<>nil then begin
    w1:=ord(p[0]);
    if (w1 < $D800) or (w1 > $DFFF) then begin
      // is 1 word character
      Result:=w1;
      CharLen:=1;
    end else begin
      // could be 2 word character
      w2:=ord(p[1]);
      if (w2>=$DC00) then begin
        // is 2 word character
        Result:=(w1-$D800) shl 10 + (w2-$DC00) + $10000;
        CharLen:=2;
      end else begin
        // invalid character
        Result:=w1;
        CharLen:=1;
      end;
    end;
  end else begin
    Result:=0;
    CharLen:=0;
  end;
end;

function UnicodeToUTF16(u: cardinal): UTF16String;
begin
  // u should be <= $10FFFF to fit into UTF-16

  if u < $10000 then
    // Note: codepoints $D800 - $DFFF are reserved
    Result:=system.widechar(u)
  else
    Result:=system.widechar($D800+((u - $10000) shr 10))+system.widechar($DC00+((u - $10000) and $3ff));
end;

function CreateFirstIdentifier(const Identifier: string): string;
// example: Ident59 becomes Ident1
var
  p: Integer;
begin
  p:=length(Identifier);
  while (p>=1) and (Identifier[p] in ['0'..'9']) do dec(p);
  Result:=copy(Identifier,1,p)+'1';
end;

function CreateNextIdentifier(const Identifier: string): string;
// example: Ident59 becomes Ident60
var
  p: Integer;
begin
  p:=length(Identifier);
  while (p>=1) and (Identifier[p] in ['0'..'9']) do dec(p);
  Result:=copy(Identifier,1,p)
          +IntToStr(1+StrToIntDef(copy(Identifier,p+1,length(Identifier)-p),0));
end;

function IsFontNameDefault(const AName: string): boolean;
begin
  Result := CompareText(AName, 'default') = 0;
end;

{ TDebugLCLItems }

constructor TDebugLCLItems.Create(const TheName: string);
begin
  FName:=TheName;
  FItems:=TAvlTree.Create(@CompareDebugLCLItemInfos);
end;

destructor TDebugLCLItems.Destroy;
begin
  FItems.FreeAndClear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

function TDebugLCLItems.FindInfo(p: Pointer; CreateIfNotExists: boolean): TDebugLCLItemInfo;
var
  ANode: TAvlTreeNode;
begin
  ANode:=FItems.FindKey(p,@CompareItemWithDebugLCLItemInfo);
  if ANode<>nil then
    Result:=TDebugLCLItemInfo(ANode.Data)
  else begin
    // does not yet exists
    if CreateIfNotExists then begin
      Result:=MarkCreated(p,'TDebugLCLItems.FindInfo');
    end else begin
      Result:=nil;
    end;
  end;
end;

function TDebugLCLItems.IsDestroyed(p: Pointer): boolean;
var
  Info: TDebugLCLItemInfo;
begin
  Info:=FindInfo(p);
  if Info=nil then
    Result:=false
  else
    Result:=Info.IsDestroyed;
end;

function TDebugLCLItems.IsCreated(p: Pointer): boolean;
var
  Info: TDebugLCLItemInfo;
begin
  Info:=FindInfo(p);
  if Info=nil then
    Result:=false
  else
    Result:=not Info.IsDestroyed;
end;

procedure TDebugLCLItems.MarkDestroyed(p: Pointer);
var
  Info: TDebugLCLItemInfo;

  procedure RaiseNotCreated;
  begin
    DebugLn('TDebugLCLItems.MarkDestroyed not created: p=',dbgs(p));
    DumpStack;
    RaiseGDBException('TDebugLCLItems.MarkDestroyed');
  end;

  procedure RaiseDoubleDestroyed;
  begin
    debugLn('TDebugLCLItems.MarkDestroyed Double destroyed:');
    debugln(Info.AsString(true));
    debugln('Now:');
    DebugLn(GetStackTrace(true));
    RaiseGDBException('RaiseDoubleDestroyed');
  end;

begin
  Info:=FindInfo(p);
  if Info=nil then
    RaiseNotCreated;
  if Info.IsDestroyed then
    RaiseDoubleDestroyed;
  Info.IsDestroyed:=true;
  GetStackTracePointers(Info.DestructionStack);
  //DebugLn(['TDebugLCLItems.MarkDestroyed ',dbgs(p)]);
end;

function TDebugLCLItems.GetInfo(p: Pointer; WithStackTraces: boolean): string;
var
  Info: TDebugLCLItemInfo;
begin
  Info:=FindInfo(p,false);
  if Info<>nil then
    Result:=Info.AsString(WithStackTraces)
  else
    Result:='';
end;

function TDebugLCLItems.MarkCreated(p: Pointer;
  const InfoText: string): TDebugLCLItemInfo;
var
  Info: TDebugLCLItemInfo;

  procedure RaiseDoubleCreated;
  begin
    debugLn('TDebugLCLItems.MarkCreated CREATED TWICE. Old:');
    debugln(Info.AsString(true));
    debugln(' New=',dbgs(p),' InfoText="',InfoText,'"');
    DebugLn(GetStackTrace(true));
    RaiseGDBException('RaiseDoubleCreated');
  end;

begin
  Info:=FindInfo(p);
  if Info=nil then begin
    Info:=TDebugLCLItemInfo.Create;
    Info.Item:=p;
    FItems.Add(Info);
  end else if not Info.IsDestroyed then begin
    RaiseDoubleCreated;
  end;
  Info.IsDestroyed:=false;
  Info.Info:=InfoText;
  GetStackTracePointers(Info.CreationStack);
  SetLength(Info.DestructionStack,0);
  //DebugLn(['TDebugLCLItems.MarkCreated ',Name,' ',dbgs(p),' ',FItems.Count]);
  //DebugLn(GetStackTrace(true));
  Result:=Info;
end;

{ TDebugLCLItemInfo }

function TDebugLCLItemInfo.AsString(WithStackTraces: boolean): string;
begin
  Result:='Item='+Dbgs(Item)+LineEnding
          +'Info="'+DbgStr(Info)+LineEnding;
  if WithStackTraces then
    Result:=Result+'Creation:'+LineEnding+StackTraceAsString(CreationStack,true);
  if IsDestroyed then begin
    Result:=Result+'Destroyed:'+LineEnding;
    if WithStackTraces then
      Result:=Result+StackTraceAsString(DestructionStack,true);
  end;
end;

destructor TDebugLCLItemInfo.Destroy;
begin
  SetLength(CreationStack,0);
  SetLength(DestructionStack,0);
  inherited Destroy;
end;

initialization
  {$IFDEF WithOldDebugln} InitializeDebugOutput; {$ENDIF}
  {$ifdef WinCE}
  // The stabs based back trace function crashes on wince,
  // see http://bugs.freepascal.org/view.php?id=14330
  // To prevent crashes, replace it with the default system back trace function
  // that just outputs addresses and not source and line number
  BackTraceStrFunc := @SysBackTraceStr;
  {$endif}
  {$ifdef AROS}
    {$if FPC_FULLVERSION>=30101}
    EnableBackTraceStr;
    {$endif}
  {$endif}
  InterfaceInitializationHandlers := TFPList.Create;
  InterfaceFinalizationHandlers := TFPList.Create;
  {$IFDEF DebugLCLComponents}
  DebugLCLComponents:=TDebugLCLItems.Create('LCLComponents');
  {$ENDIF}
finalization
  InterfaceInitializationHandlers.Free;
  InterfaceInitializationHandlers:=nil;
  InterfaceFinalizationHandlers.Free;
  InterfaceFinalizationHandlers:=nil;
  {$IFDEF DebugLCLComponents}
  DebugLCLComponents.Free;
  DebugLCLComponents:=nil;
  {$ENDIF}
  {$IFDEF WithOldDebugln}
  FinalizeDebugOutput;
  DebugLnNestFreePrefix;
  {$ENDIF}

end.

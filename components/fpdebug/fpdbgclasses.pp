{ $Id$ }
{
 ---------------------------------------------------------------------------
 fpdbgclasses.pp  -  Native freepascal debugger
 ---------------------------------------------------------------------------

 This unit contains debugger classes for a native freepascal debugger

 ---------------------------------------------------------------------------

 @created(Mon Apr 10th WET 2006)
 @lastmod($Date$)
 @author(Marc Weustink <marc@@dommelstein.nl>)

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
}
unit FpDbgClasses;
{$mode objfpc}{$H+}
{$TYPEDADDRESS on}

interface

uses
  Classes, SysUtils, Maps, FpDbgDwarf, FpDbgUtil, FpDbgLoader, FpDbgInfo,
  FpdMemoryTools, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazClasses, LazFileUtils, DbgIntfBaseTypes,
  fgl, DbgIntfDebuggerBase, FpPascalBuilder, fpDbgSymTableContext,
  FpDbgDwarfDataClasses, FpDbgCommon, FpErrorMessages;

type
  TFPDEvent = (
    deExitProcess, deCreateProcess,
    deLoadLibrary, deUnloadLibrary,
    deFinishedStep, deBreakpoint, deHardCodedBreakpoint,
    deException,
    deInternalContinue);
  TFPDCompareStepInfo = (dcsiNewLine, dcsiSameLine, dcsiNoLineInfo, dcsiZeroLine);

  { TDbgRegisterValue }

  TDbgRegisterValue = class
  private
    FDwarfIdx: cardinal;
    FName: string;
    FNumValue: TDBGPtr;
    FSize: byte;
    FStrValue: string;
  public
    constructor Create(const AName: String);
    procedure SetValue(ANumValue: TDBGPtr; const AStrValue: string; ASize: byte; ADwarfIdx: cardinal);
    procedure Setx86EFlagsValue(ANumValue: TDBGPtr);
    property Name: string read FName;
    property NumValue: TDBGPtr read FNumValue;
    property StrValue: string read FStrValue;
    property Size: byte read FSize;
    property DwarfIdx: cardinal read FDwarfIdx;
  end;

  TGDbgRegisterValueList = specialize TFPGObjectList<TDbgRegisterValue>;

  { TDbgRegisterValueList }

  TDbgRegisterValueList = class(TGDbgRegisterValueList)
  private
    function GetDbgRegister(const AName: string): TDbgRegisterValue;
    function GetDbgRegisterAutoCreate(const AName: string): TDbgRegisterValue;
  public
    property DbgRegisterAutoCreate[AName: string]: TDbgRegisterValue read GetDbgRegisterAutoCreate;
    function FindRegisterByDwarfIndex(AnIdx: cardinal): TDbgRegisterValue;
  end;

  { TDbgCallstackEntry }
  TDbgThread = class;
  TFPDThreadArray = array of TDbgThread;
  TDbgLibrary = class;
  TOSDbgClasses = class;
  TDbgAsmInstruction = class;

  TDbgCallstackEntry = class
  private
    FAnAddress: TDBGPtr;
    FFrameAdress: TDBGPtr;
    FThread: TDbgThread;
    FIsSymbolResolved: boolean;
    FSymbol: TFpSymbol;
    FRegisterValueList: TDbgRegisterValueList;
    FIndex: integer;
    function GetFunctionName: string;
    function GetProcSymbol: TFpSymbol;
    function GetLine: integer;
    function GetSourceFile: string;
    function GetSrcClassName: string;
  public
    constructor create(AThread: TDbgThread; AnIndex: integer; AFrameAddress, AnAddress: TDBGPtr);
    destructor Destroy; override;
    function GetParamsAsString(APrettyPrinter: TFpPascalPrettyPrinter): string;
    property AnAddress: TDBGPtr read FAnAddress;
    property FrameAdress: TDBGPtr read FFrameAdress;
    property SourceFile: string read GetSourceFile;
    property FunctionName: string read GetFunctionName;
    property SrcClassName: string read GetSrcClassName;
    property Line: integer read GetLine;
    property RegisterValueList: TDbgRegisterValueList read FRegisterValueList;
    property ProcSymbol: TFpSymbol read GetProcSymbol;
    property Index: integer read FIndex;
  end;

  { TDbgCallstackEntryList }

  TDbgCallstackEntryList = class(specialize TFPGObjectList<TDbgCallstackEntry>)
  private
    FHasReadAllAvailableFrames: boolean;
  protected
    procedure SetHasReadAllAvailableFrames;
  public
    procedure Clear;
    property HasReadAllAvailableFrames: boolean read FHasReadAllAvailableFrames;
  end;

  TDbgProcess = class;
  TFpWatchPointData = class;

  { TDbgMemReader }

  TDbgMemReader = class(TFpDbgMemReaderBase)
  protected
    function GetDbgProcess: TDbgProcess; virtual; abstract;
    function GetDbgThread(AContext: TFpDbgLocationContext): TDbgThread; virtual;
  public
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override; overload;
    function ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer; out ABytesRead: Cardinal): Boolean; override; overload;
    function ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean; override;
    function WriteMemory(AnAddress: TDbgPtr; ASize: Cardinal; ASource: Pointer): Boolean; override; overload;
    function ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr; AContext: TFpDbgLocationContext): Boolean; override;
    function RegisterSize(ARegNum: Cardinal): Integer; override;

    function WriteRegister(ARegNum: Cardinal; const AValue: TDbgPtr; AContext: TFpDbgLocationContext): Boolean; override;
  end;

  { TDbgStackFrameInfo
    This can be overridden by each OS dependen class. Or it could be gotten from the Disassemble, if it is CPU specific
    This default assumes an Intel like stack, with StackPointer and FrameBase.
    This default assumes the stack grows by decreasing addresses.
  }

  TDbgStackFrameInfo = class
  private
    FThread: TDbgThread;
    FStoredStackFrame, FStoredStackPointer: TDBGPtr;
    FHasSteppedOut: Boolean;
    FProcessAfterRun: Boolean;
    FLeaveState: (lsNone, lsWasAtLeave1, lsWasAtLeave2, lsLeaveDone);
    Procedure DoAfterRun;
  protected
    procedure DoCheckNextInstruction(ANextInstruction: TDbgAsmInstruction; NextIsSingleStep: Boolean); virtual;
    function  CalculateHasSteppedOut: Boolean;  virtual;
  public
    constructor Create(AThread: TDbgThread);
    procedure CheckNextInstruction(ANextInstruction: TDbgAsmInstruction; NextIsSingleStep: Boolean); inline;
    function  HasSteppedOut: Boolean; inline;
    procedure FlagAsSteppedOut; inline;

    // only for FpLldbDebugger
    property StoredStackFrame: TDBGPtr read FStoredStackFrame;
  end;

  { TDbgThread }
  TFpInternalBreakpoint = class;

  TDbgThread = class(TObject)
  private
    FNextIsSingleStep: boolean;
    FProcess: TDbgProcess;
    FID: Integer;
    FHandle: THandle;
    FPausedAtRemovedBreakPointState: (rbUnknown, rbNone, rbFound{, rbFoundAndDec});
    FPausedAtHardcodeBreakPoint: Boolean;
    FPausedAtRemovedBreakPointAddress: TDBGPtr;

    function GetRegisterValueList: TDbgRegisterValueList;
  protected
    FCallStackEntryList: TDbgCallstackEntryList;
    FRegisterValueListValid: boolean;
    FRegisterValueList: TDbgRegisterValueList;
    FStoreStepSrcFilename, FStoreStepFuncName: string;
    FStoreStepStartAddr, FStoreStepEndAddr: TDBGPtr;
    FStoreStepSrcLineNo: integer;
    FStoreStepFuncAddr: TDBGPtr;
    procedure LoadRegisterValues; virtual;
    property Process: TDbgProcess read FProcess;
    function ResetInstructionPointerAfterBreakpoint: boolean; virtual; abstract;
    procedure DoBeforeBreakLocationMapChange; // A new location added / or a location removed => memory will change
    procedure ValidateRemovedBreakPointInfo;
  public
    constructor Create(const AProcess: TDbgProcess; const AID: Integer; const AHandle: THandle); virtual;
    function HasInsertedBreakInstructionAtLocation(const ALocation: TDBGPtr): Boolean; // include removed breakpoints that (may have) already triggered
    (* CheckAndResetInstructionPointerAfterBreakpoint
       This will check if the last instruction was a breakpoint (int3).
       It must ONLY be called, if the signal indicated that it should have been.
       Since the previous IP is not known, this assumes the length of the
         previous asm statement to be the same as the length of int3.
       If a longer command would end in the signature of int3, then this would
         detect the int3 (false positive)
    *)
    procedure CheckAndResetInstructionPointerAfterBreakpoint;
    procedure BeforeContinue; virtual;
    procedure ApplyWatchPoints(AWatchPointData: TFpWatchPointData); virtual;
    function DetectHardwareWatchpoint: Pointer; virtual;
    // This function changes the value of a register in the debugee.
    procedure SetRegisterValue(AName: string; AValue: QWord); virtual; abstract;

    function GetInstructionPointerRegisterValue: TDbgPtr; virtual; abstract;
    function GetStackBasePointerRegisterValue: TDbgPtr; virtual; abstract;
    function GetStackPointerRegisterValue: TDbgPtr; virtual; abstract;
    function GetCurrentStackFrameInfo: TDbgStackFrameInfo;

    procedure PrepareCallStackEntryList(AFrameRequired: Integer = -1); virtual;
    function  FindCallStackEntryByBasePointer(AFrameBasePointer: TDBGPtr; AMaxFrameToSearch: Integer; AStartFrame: integer = 0): Integer; //virtual;
    function  FindCallStackEntryByInstructionPointer(AInstructionPointer: TDBGPtr; AMaxFrameToSearch: Integer; AStartFrame: integer = 0): Integer; //virtual;
    procedure ClearCallStack;
    // Use these functions to 'save' the value of all registers, and to reset
    // them to their original values. (Used to be able to restore the original
    // situation after calling functions inside the debugee)
    procedure StoreRegisters; virtual; abstract;
    procedure RestoreRegisters; virtual; abstract;
    // It could be that an signal led to an exception, and that this
    // signal is stored to be send to the debuggee again upon continuation.
    // Use ClearExceptionSignal to remove/eat this signal.
    procedure ClearExceptionSignal; virtual;

    destructor Destroy; override;
    function CompareStepInfo(AnAddr: TDBGPtr = 0; ASubLine: Boolean = False): TFPDCompareStepInfo;
    function IsAtStartOfLine: boolean;
    procedure StoreStepInfo(AnAddr: TDBGPtr = 0);
    property ID: Integer read FID;
    property Handle: THandle read FHandle;
    property NextIsSingleStep: boolean read FNextIsSingleStep write FNextIsSingleStep;
    property RegisterValueList: TDbgRegisterValueList read GetRegisterValueList;
    property CallStackEntryList: TDbgCallstackEntryList read FCallStackEntryList;
    property StoreStepFuncName: String read FStoreStepFuncName;
    property PausedAtHardcodeBreakPoint: Boolean read FPausedAtHardcodeBreakPoint;
  end;
  TDbgThreadClass = class of TDbgThread;

  { TThreadMapUnLockedEnumerator }

  TThreadMapUnLockedEnumerator = class(TMapIterator)
  private
    FDoneFirst: Boolean;
    function GetCurrent: TDbgThread;
  public
    function MoveNext: Boolean;
    property Current: TDbgThread read GetCurrent;
  end;

    { TThreadMapEnumerator }

  TThreadMapEnumerator = class(TLockedMapIterator)
  private
    FDoneFirst: Boolean;
    function GetCurrent: TDbgThread;
  public
    function MoveNext: Boolean;
    property Current: TDbgThread read GetCurrent;
  end;

  { TThreadMap }

  TThreadMap = class(TMap)
  public
    function GetEnumerator: TThreadMapEnumerator;
  end;

  { TLibraryMap }

  TLibraryMap = class(TMap)
  private
    FLastLibraryAdded: TDbgLibrary;
  public
    procedure Add(const AId, AData);
    function GetLib(const AHandle: THandle; out ALib: TDbgLibrary): Boolean;
    function GetLib(const AName: String; out ALib: TDbgLibrary; IsFullName: Boolean = True): Boolean;
    property LastLibraryAdded: TDbgLibrary read FLastLibraryAdded;
  end;

  TFpInternalBreakpointArray = array of TFpInternalBreakpoint;

  { TBreakLocationEntry }

  TBreakLocationEntry = object
    Location: TDBGPtr;
    Data: Pointer;
    function OrigValue: Byte;
    function ErrorSetting: ByteBool;
  end;

  { TBreakLocationMap }

  TBreakLocationMap = class(TMap)
  private type
    TInternalBreakLocationEntry = record
      OrigValue: Byte;
      IsBreakList, ErrorSetting: ByteBool;
      InternalBreakPoint: Pointer;
    end;
    PInternalBreakLocationEntry = ^TInternalBreakLocationEntry;

    { TBreakLocationMapEnumerator }

    TBreakLocationMapEnumerator = class(TMapIterator)
    private
      FDoneFirst: Boolean;
      function GetCurrent: TBreakLocationEntry;
    public
      function MoveNext: Boolean;
      property Current: TBreakLocationEntry read GetCurrent;
    end;
  private
    FProcess: TDbgProcess;
    class function OrigByteFromPointer(AData: Pointer): Byte;
    class function ErrorSettingFromPointer(AData: Pointer): ByteBool;
  public
    constructor Create(AProcess: TDbgProcess);
    destructor Destroy; override;
    procedure Clear; reintroduce;
    procedure AddLocotion(const ALocation: TDBGPtr; const AInternalBreak: TFpInternalBreakpoint; AnIgnoreIfExists: Boolean = True);
    procedure RemoveLocotion(const ALocation: TDBGPtr; const AInternalBreak: TFpInternalBreakpoint);
    // When the debugger modifies the debuggee's code, it might be that the
    // original value underneeth the breakpoint has to be changed. This function
    // makes this possible.
    procedure AdaptOriginalValueAtLocation(const ALocation: TDBGPtr; const NewOrigValue: Byte);
    function GetInternalBreaksAtLocation(const ALocation: TDBGPtr): TFpInternalBreakpointArray;
    function GetOrigValueAtLocation(const ALocation: TDBGPtr): Byte; // returns Int3, if there is no break at this location
    function HasInsertedBreakInstructionAtLocation(const ALocation: TDBGPtr): Boolean;
    function GetEnumerator: TBreakLocationMapEnumerator;
  end;

  { TFpDbgBreakpoint }

  TFpDbgBreakpoint = class(TObject)
  private
    FFreeByDbgProcess: Boolean;
  public
    function Hit(const AThreadID: Integer; ABreakpointAddress: TDBGPtr): Boolean; virtual; abstract;
    function HasLocation(const ALocation: TDBGPtr): Boolean; virtual; abstract;

    procedure AddAddress(const ALocation: TDBGPtr); virtual; abstract;
    procedure RemoveAddress(const ALocation: TDBGPtr); virtual; abstract;
    procedure RemoveAllAddresses; virtual; abstract;

    procedure SetBreak; virtual; abstract;
    procedure ResetBreak; virtual; abstract;

    // FreeByDbgProcess: The breakpoint will be freed by TDbgProcess.Destroy
    property FreeByDbgProcess: Boolean read FFreeByDbgProcess write FFreeByDbgProcess;
  end;

  { TFpInternalBreakBase }

  TFpInternalBreakBase = class(TFpDbgBreakpoint)
  private
    FProcess: TDbgProcess;
  protected
    property Process: TDbgProcess read FProcess;
  public
    constructor Create(const AProcess: TDbgProcess); virtual;
  end;

  TFpInternalBreakpointList = specialize TFPGObjectList<TFpInternalBreakBase>;

  { TFpInternalBreakpoint }

  TFpInternalBreakpoint = class(TFpInternalBreakBase)
  private
    FLocation: TDBGPtrArray;
    FInternal: Boolean;
  protected
    property Location: TDBGPtrArray read FLocation;
  public
    constructor Create(const AProcess: TDbgProcess; const ALocation: TDBGPtrArray; AnEnabled: Boolean); virtual;
    destructor Destroy; override;
    function Hit(const AThreadID: Integer; ABreakpointAddress: TDBGPtr): Boolean; override;
    function HasLocation(const ALocation: TDBGPtr): Boolean; override;

    procedure AddAddress(const ALocation: TDBGPtr); override;
    procedure RemoveAddress(const ALocation: TDBGPtr); override;
    procedure RemoveAllAddresses; override;

    procedure SetBreak; override;
    procedure ResetBreak; override;
  end;
  TFpInternalBreakpointClass = class of TFpInternalBreakpoint;

  { TFpInternalWatchpoint }

  TFpInternalWatchpoint  = class(TFpInternalBreakBase)
  private
    FLocation: TDBGPtr;
    FSize: Cardinal;
    FReadWrite: TDBGWatchPointKind;
    FScope: TDBGWatchPointScope;

    FOtherWatchCount: Integer;
    FFirstWatchLocation: TDBGPtr;
    FFirstWatchSize,
    FOtherWatchesSize,
    FLastWatchSize: Integer;
  protected
    property Location: TDBGPtr read FLocation;
    property Size: Cardinal read FSize;
    property ReadWrite: TDBGWatchPointKind read FReadWrite;
    property Scope: TDBGWatchPointScope read FScope;
  public
    constructor Create(const AProcess: TDbgProcess; const ALocation: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind;
                      AScope: TDBGWatchPointScope); virtual;
    destructor Destroy; override;

    procedure SetBreak; override;
    procedure ResetBreak; override;
  end;
  TFpInternalWatchpointClass = class of TFpInternalWatchpoint;

  { TDbgInstance }

  TDbgInstance = class(TObject)
  private
    FMemManager: TFpDbgMemManager;
    FMode: TFPDMode;
    FFileName: String;
    FProcess: TDbgProcess;
    FSymbolTableInfo: TFpSymbolInfo;
    FLoaderList: TDbgImageLoaderList;
    function GetOSDbgClasses: TOSDbgClasses;
    function GetPointerSize: Integer;

  protected
    FDbgInfo: TDbgInfo;
    procedure InitializeLoaders; virtual;
    procedure SetFileName(const AValue: String);
    property LoaderList: TDbgImageLoaderList read FLoaderList write FLoaderList;
    procedure SetMode(AMode: TFPDMode); experimental; // for testcase
  public
    constructor Create(const AProcess: TDbgProcess); virtual;
    destructor Destroy; override;

    function AddBreak(const AFileName: String; ALine: Cardinal; AnEnabled: Boolean = True): TFpInternalBreakpoint; overload;
    function AddBreak(const AFuncName: String; AnEnabled: Boolean = True): TFpDbgBreakpoint; overload;
    function AddrOffset: TDBGPtr; virtual;  // gives the offset between  the loaded addresses and the compiled addresses
    function FindProcSymbol(const AName: String): TFpSymbol; overload;
    function FindProcSymbol(AAdress: TDbgPtr): TFpSymbol; overload;
    procedure LoadInfo; virtual;

    property Process: TDbgProcess read FProcess;
    property OSDbgClasses: TOSDbgClasses read GetOSDbgClasses;
    property DbgInfo: TDbgInfo read FDbgInfo;
    property SymbolTableInfo: TFpSymbolInfo read FSymbolTableInfo;
    property Mode: TFPDMode read FMode;
    property PointerSize: Integer read GetPointerSize;
    property MemManager: TFpDbgMemManager read FMemManager;
  end;

  { TDbgLibrary }

  TDbgLibrary = class(TDbgInstance)
  private
    FModuleHandle: THandle;
    FBaseAddr: TDBGPtr;
  public
    constructor Create(const AProcess: TDbgProcess; const ADefaultName: String; const AModuleHandle: THandle; const ABaseAddr: TDbgPtr);
    property Name: String read FFileName;
    property ModuleHandle: THandle read FModuleHandle;
    property BaseAddr: TDBGPtr read FBaseAddr;
  end;

  TStartInstanceFlag = (siRediretOutput, siForceNewConsole);
  TStartInstanceFlags = set of TStartInstanceFlag;

  { TDbgAsmInstruction }

  TDbgAsmInstruction = class(TRefCountedObject)
  public
    // returns byte len of call instruction at AAddress // 0 if not a call intruction
    function IsCallInstruction: boolean; virtual;
    function IsReturnInstruction: boolean; virtual;
    function IsLeaveStackFrame: boolean; virtual;
    //function ModifiesBasePointer: boolean; virtual;
    function ModifiesStackPointer: boolean; virtual;
    function IsJumpInstruction(IncludeConditional: Boolean = True; IncludeUncoditional: Boolean = True): boolean; virtual;
    function InstructionLength: Integer; virtual;
  end;

  { TDbgAsmDecoder }

  TDbgAsmDecoder = class
  protected
    function GetLastErrorWasMemReadErr: Boolean; virtual;
    function GetMaxInstrSize: integer; virtual; abstract;
    function GetMinInstrSize: integer; virtual; abstract;
    function GetCanReverseDisassemble: boolean; virtual;
  public
    constructor Create(AProcess: TDbgProcess); virtual; abstract;

    procedure Disassemble(var AAddress: Pointer; out ACodeBytes: String; out ACode: String); virtual; abstract;
    procedure ReverseDisassemble(var AAddress: Pointer; out ACodeBytes: String; out ACode: String); virtual;

    function GetInstructionInfo(AnAddress: TDBGPtr): TDbgAsmInstruction; virtual; abstract;
    function GetFunctionFrameInfo(AnAddress: TDBGPtr; out AnIsOutsideFrame: Boolean): Boolean; virtual;

    property LastErrorWasMemReadErr: Boolean read GetLastErrorWasMemReadErr;
    property MaxInstructionSize: integer read GetMaxInstrSize;  // abstract
    property MinInstructionSize: integer read GetMinInstrSize;  // abstract
    property CanReverseDisassemble: boolean read GetCanReverseDisassemble;
  end;
  TDbgDisassemblerClass = class of TDbgAsmDecoder;

  { TDbgProcess }

  TDbgProcess = class(TDbgInstance)
  protected const
    Int3: Byte = $CC;
  private
    FDisassembler: TDbgAsmDecoder;
    FExceptionClass: string;
    FExceptionMessage: string;
    FExitCode: DWord;
    FGotExitProcess: Boolean;
    FLastLibraryUnloaded: TDbgLibrary;
    FOSDbgClasses: TOSDbgClasses;
    FProcessID: Integer;
    FThreadID: Integer;
    FWatchPointData: TFpWatchPointData;

    function GetDisassembler: TDbgAsmDecoder;
    function GetLastLibraryLoaded: TDbgLibrary;
    function GetPauseRequested: boolean;
    procedure SetPauseRequested(AValue: boolean);
    procedure ThreadDestroyed(const AThread: TDbgThread);
  protected
    FBreakpointList, FWatchPointList: TFpInternalBreakpointList;
    FCurrentBreakpoint: TFpInternalBreakpoint;  // set if we are executing the code at the break
                                         // if the singlestep is done, set the break again
    FCurrentWatchpoint: Pointer;         // Indicates the owner
    FReEnableBreakStep: Boolean;         // Set when we are reenabling a breakpoint
                                         // We need a single step, so the IP is after the break to set

    FSymInstances: TList;  // list of dbgInstances with debug info

    FThreadMap: TThreadMap; // map ThreadID -> ThreadObject
    FLibMap: TLibraryMap;    // map LibAddr -> LibObject
    FBreakMap: TBreakLocationMap;  // map BreakAddr -> BreakObject
    FTmpRemovedBreaks: array of TDBGPtr;
    FPauseRequested: longint;

    FMainThread: TDbgThread;
    function GetHandle: THandle; virtual;
    procedure SetThreadId(AThreadId: Integer);
    procedure SetExitCode(AValue: DWord);
    function GetLastEventProcessIdentifier: THandle; virtual;
    function DoBreak(BreakpointAddress: TDBGPtr; AThreadID: integer): Boolean;
    procedure SetLastLibraryUnloaded(ALib: TDbgLibrary);
    procedure SetLastLibraryUnloadedNil(ALib: TDbgLibrary);
    function GetRequiresExecutionInDebuggerThread: boolean; virtual;

    function InsertBreakInstructionCode(const ALocation: TDBGPtr; out OrigValue: Byte): Boolean; virtual;
    function RemoveBreakInstructionCode(const ALocation: TDBGPtr; const OrigValue: Byte): Boolean; virtual;
    procedure RemoveAllBreakPoints;
    procedure BeforeChangingInstructionCode(const ALocation: TDBGPtr; ACount: Integer); virtual;
    procedure AfterChangingInstructionCode(const ALocation: TDBGPtr; ACount: Integer); virtual;

    procedure MaskBreakpointsInReadData(const AAdress: TDbgPtr; const ASize: Cardinal; var AData);
    // Should create a TDbgThread-instance for the given ThreadIdentifier.
    function CreateThread(AthreadIdentifier: THandle; out IsMainThread: boolean): TDbgThread; virtual; abstract;
    // Should analyse why the debugger has stopped.
    function AnalyseDebugEvent(AThread: TDbgThread): TFPDEvent; virtual; abstract;

    function CreateWatchPointData: TFpWatchPointData; virtual;
public
    class function StartInstance(AFileName: string; AParams, AnEnvironment: TStrings;
      AWorkingDirectory, AConsoleTty: string; AFlags: TStartInstanceFlags;
      AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess; virtual;
    class function AttachToInstance(AFileName: string; APid: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess; virtual;
    class function isSupported(ATargetInfo: TTargetDescriptor): boolean; virtual;
    constructor Create(const AFileName: string; const AProcessID, AThreadID: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager); virtual;
    destructor Destroy; override;
    function  AddInternalBreak(const ALocation: TDBGPtr): TFpInternalBreakpoint; overload;
    function  AddInternalBreak(const ALocation: TDBGPtrArray): TFpInternalBreakpoint; overload;
    function  AddBreak(const ALocation: TDBGPtr; AnEnabled: Boolean = True): TFpInternalBreakpoint; overload;
    function  AddBreak(const ALocation: TDBGPtrArray; AnEnabled: Boolean = True): TFpInternalBreakpoint; overload;
    function  AddWatch(const ALocation: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind;
                      AScope: TDBGWatchPointScope): TFpInternalWatchpoint;
    property WatchPointData: TFpWatchPointData read FWatchPointData;
    (* FindProcSymbol(Address)
         Search the program and all libraries.
       FindProcSymbol(Name)
         Search ONLY the program.
         Names can be ambigious, as dll can have the same names.
    *)
    function  FindProcSymbol(const AName, ALibraryName: String; IsFullLibName: Boolean = True): TFpSymbol;  overload;
    function  FindProcSymbol(AAdress: TDbgPtr): TFpSymbol;  overload;
    function  FindSymbolScope(AThreadId, AStackFrame: Integer): TFpDbgSymbolScope;
    function  ContextFromProc(AThreadId, AStackFrame: Integer; AProcSym: TFpSymbol): TFpDbgLocationContext; inline; deprecated 'use TFpDbgSimpleLocationContext.Create';
    function  GetLib(const AHandle: THandle; out ALib: TDbgLibrary): Boolean;
    property  LastLibraryLoaded: TDbgLibrary read GetLastLibraryLoaded;
    property  LastLibraryUnloaded: TDbgLibrary read FLastLibraryUnloaded write SetLastLibraryUnloadedNil;
    function  GetThread(const AID: Integer; out AThread: TDbgThread): Boolean;
    procedure RemoveBreak(const ABreakPoint: TFpDbgBreakpoint);
    procedure DoBeforeBreakLocationMapChange;
    function  HasBreak(const ALocation: TDbgPtr): Boolean; // TODO: remove, once an address can have many breakpoints
    procedure RemoveThread(const AID: DWord);
    function FormatAddress(const AAddress): String;
    function  Pause: boolean; virtual;

    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean; virtual;
    function ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData; out APartSize: Cardinal): Boolean; virtual;
    function ReadAddress(const AAdress: TDbgPtr; out AData: TDBGPtr): Boolean; virtual;
    function ReadOrdinal(const AAdress: TDbgPtr; out AData): Boolean; virtual;
    function ReadString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: String): Boolean; virtual;
    function ReadWString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: WideString): Boolean; virtual;
    // Get the default location for parameters in default calling mode // Note functions may take result as argument
    function CallParamDefaultLocation(AParamIdx: Integer): TFpDbgMemLocation; virtual;

    //function LocationIsBreakInstructionCode(const ALocation: TDBGPtr): Boolean; // excludes TempRemoved
    procedure TempRemoveBreakInstructionCode(const ALocation: TDBGPtr);
    procedure RestoreTempBreakInstructionCodes;
    function HasInsertedBreakInstructionAtLocation(const ALocation: TDBGPtr): Boolean; // returns Int3, if there is no break at this location

    function Continue(AProcess: TDbgProcess; AThread: TDbgThread; SingleStep: boolean): boolean; virtual;
    function WaitForDebugEvent(out ProcessIdentifier, ThreadIdentifier: THandle): boolean; virtual; abstract;
    function ResolveDebugEvent(AThread: TDbgThread): TFPDEvent; virtual;

    function CheckForConsoleOutput(ATimeOutMs: integer): integer; virtual;
    function GetConsoleOutput: string; virtual;
    procedure SendConsoleInput(AString: string); virtual;

    function AddThread(AThreadIdentifier: THandle): TDbgThread;
    function GetThreadArray: TFPDThreadArray;
    procedure ThreadsBeforeContinue;
    procedure ThreadsClearCallStack;
    procedure LoadInfo; override;

    function WriteData(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean; virtual;
    // Modify the debugee's code.
    function WriteInstructionCode(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean; virtual;

    procedure TerminateProcess; virtual; abstract;
    function Detach(AProcess: TDbgProcess; AThread: TDbgThread): boolean; virtual;

    property OSDbgClasses: TOSDbgClasses read FOSDbgClasses;
    property RequiresExecutionInDebuggerThread: boolean read GetRequiresExecutionInDebuggerThread;
    property Handle: THandle read GetHandle;
    property Name: String read FFileName write SetFileName;
    property ProcessID: integer read FProcessID;
    property ThreadID: integer read FThreadID;
    property ExitCode: DWord read FExitCode;
    property CurrentBreakpoint: TFpInternalBreakpoint read FCurrentBreakpoint;
    property CurrentWatchpoint: Pointer read FCurrentWatchpoint;
    property PauseRequested: boolean read GetPauseRequested write SetPauseRequested;
    function GetAndClearPauseRequested: Boolean;

    // Properties valid when last event was an deException
    property ExceptionMessage: string read FExceptionMessage write FExceptionMessage;
    property ExceptionClass: string read FExceptionClass write FExceptionClass;

    property LastEventProcessIdentifier: THandle read GetLastEventProcessIdentifier;
    property MainThread: TDbgThread read FMainThread;
    property GotExitProcess: Boolean read FGotExitProcess write FGotExitProcess;
    property Disassembler: TDbgAsmDecoder read GetDisassembler;
    property ThreadMap: TThreadMap read FThreadMap;
  end;
  TDbgProcessClass = class of TDbgProcess;

  { TFpWatchPointData }

  TFpWatchPointData = class
  private
    FChanged: Boolean;
  public
    function AddOwnedWatchpoint(AnOwner: Pointer; AnAddr: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind): boolean; virtual;
    function RemoveOwnedWatchpoint(AnOwner: Pointer): boolean; virtual;
    property Changed: Boolean read FChanged write FChanged;
  end;

  { TFpIntelWatchPointData }

  TFpIntelWatchPointData = class(TFpWatchPointData)
  private
    // For Intel: Dr0..Dr3
    FOwners: array [0..3] of Pointer;
    FDr03: array [0..3] of TDBGPtr;
    FDr7: DWord;
    function GetDr03(AnIndex: Integer): TDBGPtr; inline;
    function GetOwner(AnIndex: Integer): Pointer; inline;
  public
    function AddOwnedWatchpoint(AnOwner: Pointer; AnAddr: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind): boolean; override;
    function RemoveOwnedWatchpoint(AnOwner: Pointer): boolean; override;
    property Dr03[AnIndex: Integer]: TDBGPtr read GetDr03;
    property Dr7: DWord read FDr7;
    property Owner[AnIndex: Integer]: Pointer read GetOwner;
  end;

  { TOSDbgClasses }

  TOSDbgClasses = class
  public
    DbgProcessClass : TDbgProcessClass;
    DbgThreadClass : TDbgThreadClass;
    DbgDisassemblerClass : TDbgDisassemblerClass;
    DbgBreakpointClass : TFpInternalBreakpointClass;
    DbgWatchpointClass : TFpInternalWatchpointClass;
    constructor Create(
      ADbgProcessClass: TDbgProcessClass;
      ADbgThreadClass: TDbgThreadClass;
      ADbgDisassemblerClass: TDbgDisassemblerClass;
      ADbgBreakpointClass: TFpInternalBreakpointClass = nil;
      ADbgWatchpointClass: TFpInternalWatchpointClass = nil
    );
    function Equals(AnOther: TOSDbgClasses): Boolean;
  end;

const
  FPDEventNames: array[TFPDEvent] of string = (
    'deExitProcess', 'deCreateProcess',
    'deLoadLibrary', 'deUnloadLibrary',
    'deFinishedStep', 'deBreakpoint', 'deHardCodedBreakpoint',
    'deException',
    'deInternalContinue'
  );

function GetDbgProcessClass(ATargetInfo: TTargetDescriptor): TOSDbgClasses;

procedure RegisterDbgOsClasses(ADbgOsClasses: TOSDbgClasses);

implementation

type
  TOSDbgClassesList = class(specialize TFPGObjectList<TOSDbgClasses>)
  public
    function Find(a: TOSDbgClasses): Integer;
  end;
var
  DBG_VERBOSE, DBG_WARNINGS, DBG_BREAKPOINTS, FPDBG_COMMANDS: PLazLoggerLogGroup;
  RegisteredDbgProcessClasses: TOSDbgClassesList;

function GetDbgProcessClass(ATargetInfo: TTargetDescriptor): TOSDbgClasses;
var
  i   : Integer;
begin
  for i := 0 to RegisteredDbgProcessClasses.Count - 1 do
  begin
    Result := RegisteredDbgProcessClasses[i];
    try
      if Result.DbgProcessClass.isSupported(ATargetInfo) then
        Exit;
    except
      on e: exception do
      begin
        //writeln('exception! WHY? ', e.Message);
      end;
    end;
  end;
  Result := nil;
end;

procedure RegisterDbgOsClasses(ADbgOsClasses: TOSDbgClasses);
begin
  if not Assigned(RegisteredDbgProcessClasses) then
    RegisteredDbgProcessClasses := TOSDbgClassesList.Create;
  if RegisteredDbgProcessClasses.Find(ADbgOsClasses) < 0 then // TODO: by content
    RegisteredDbgProcessClasses.Add(ADbgOsClasses);
end;

{ TDbgCallstackEntryList }

procedure TDbgCallstackEntryList.SetHasReadAllAvailableFrames;
begin
  FHasReadAllAvailableFrames := True;
end;

procedure TDbgCallstackEntryList.Clear;
begin
  inherited Clear;
  FHasReadAllAvailableFrames := False;
end;

{ TOSDbgClasses }

constructor TOSDbgClasses.Create(ADbgProcessClass: TDbgProcessClass;
  ADbgThreadClass: TDbgThreadClass;
  ADbgDisassemblerClass: TDbgDisassemblerClass;
  ADbgBreakpointClass: TFpInternalBreakpointClass;
  ADbgWatchpointClass: TFpInternalWatchpointClass);
begin
  DbgProcessClass      := ADbgProcessClass;
  DbgThreadClass       := ADbgThreadClass;
  DbgDisassemblerClass := ADbgDisassemblerClass;
  DbgBreakpointClass   := ADbgBreakpointClass;
  DbgWatchpointClass   := ADbgWatchpointClass;
  if DbgBreakpointClass = nil then
    DbgBreakpointClass := TFpInternalBreakpoint;
  if DbgWatchpointClass = nil then
    DbgWatchpointClass := TFpInternalWatchpoint;
end;

function TOSDbgClasses.Equals(AnOther: TOSDbgClasses): Boolean;
begin
  Result := (DbgThreadClass       = AnOther.DbgThreadClass) and
            (DbgBreakpointClass   = AnOther.DbgBreakpointClass) and
            (DbgWatchpointClass   = AnOther.DbgWatchpointClass) and
            (DbgProcessClass      = AnOther.DbgProcessClass) and
            (DbgDisassemblerClass = AnOther.DbgDisassemblerClass);
end;

{ TOSDbgClassesList }

function TOSDbgClassesList.Find(a: TOSDbgClasses): Integer;
begin
  Result := Count - 1;
  while (Result >= 0) and not (Items[Result].Equals(a)) do
    dec(Result);
end;

{ TThreadMapUnLockedEnumerator }

function TThreadMapUnLockedEnumerator.GetCurrent: TDbgThread;
begin
  GetData(Result);
end;

function TThreadMapUnLockedEnumerator.MoveNext: Boolean;
begin
  if FDoneFirst then
    Next
  else
    First;
  FDoneFirst := True;
  Result := not EOM;
end;

{ TThreadMapEnumerator }

function TThreadMapEnumerator.GetCurrent: TDbgThread;
begin
  GetData(Result);
end;

function TThreadMapEnumerator.MoveNext: Boolean;
begin
  if FDoneFirst then
    Next
  else
    First;
  FDoneFirst := True;
  Result := not EOM;
end;

{ TThreadMap }

function TThreadMap.GetEnumerator: TThreadMapEnumerator;
begin
  Result := TThreadMapEnumerator.Create(Self);
end;

{ TLibraryMap }

procedure TLibraryMap.Add(const AId, AData);
begin
  inherited Add(AId, AData);
  FLastLibraryAdded := TDbgLibrary(AData);
end;

function TLibraryMap.GetLib(const AHandle: THandle; out ALib: TDbgLibrary
  ): Boolean;
var
  Iterator: TMapIterator;
  Lib: TDbgLibrary;
begin
  Result := False;
  Iterator := TMapIterator.Create(Self);
  while not Iterator.EOM do
  begin
    Iterator.GetData(Lib);
    Result := Lib.ModuleHandle = AHandle;
    if Result
    then begin
      ALib := Lib;
      Break;
    end;
    Iterator.Next;
  end;
  Iterator.Free;
end;

function TLibraryMap.GetLib(const AName: String; out ALib: TDbgLibrary;
  IsFullName: Boolean): Boolean;
var
  Iterator: TMapIterator;
  Lib: TDbgLibrary;
  s: String;
begin
  Result := False;
  Iterator := TMapIterator.Create(Self);
  while not Iterator.EOM do
  begin
    Iterator.GetData(Lib);
    if IsFullName then
      s := Lib.Name
    else
      s := ExtractFileName(Lib.Name);
    Result := CompareText(s, AName) = 0;
    if Result
    then begin
      ALib := Lib;
      Break;
    end;
    Iterator.Next;
  end;
  Iterator.Free;
end;

{ TBreakLocationEntry }

function TBreakLocationEntry.OrigValue: Byte;
begin
  Result := TBreakLocationMap.OrigByteFromPointer(Data);
end;

function TBreakLocationEntry.ErrorSetting: ByteBool;
begin
  Result := TBreakLocationMap.ErrorSettingFromPointer(Data);
end;

{ TBreakLocationMap.TBreakLocationMapEnumerator }

function TBreakLocationMap.TBreakLocationMapEnumerator.GetCurrent: TBreakLocationEntry;
begin
  Result.Data := DataPtr;
  GetID(Result.Location);
end;

function TBreakLocationMap.TBreakLocationMapEnumerator.MoveNext: Boolean;
begin
  if FDoneFirst then
    Next
  else
    First;
  FDoneFirst := True;
  Result := not EOM;
end;

{ TBreakLocationMap }

procedure TBreakLocationMap.Clear;
var
  LocData: TBreakLocationEntry;
begin
  debugln(DBG_VERBOSE or DBG_BREAKPOINTS, ['TBreakLocationMap.Clear ']);
  for LocData in Self do begin
    if PInternalBreakLocationEntry(LocData.Data)^.IsBreakList then
      TFpInternalBreakpointArray(PInternalBreakLocationEntry(LocData.Data)^.InternalBreakPoint) := nil;
  end;
  inherited Clear;
end;

class function TBreakLocationMap.OrigByteFromPointer(AData: Pointer): Byte;
begin
  Result := PInternalBreakLocationEntry(AData)^.OrigValue;
end;

class function TBreakLocationMap.ErrorSettingFromPointer(AData: Pointer
  ): ByteBool;
begin
  Result := PInternalBreakLocationEntry(AData)^.ErrorSetting;
end;

constructor TBreakLocationMap.Create(AProcess: TDbgProcess);
begin
  FProcess := AProcess;
  inherited Create(itu8, SizeOf(TInternalBreakLocationEntry));
end;

destructor TBreakLocationMap.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TBreakLocationMap.AddLocotion(const ALocation: TDBGPtr;
  const AInternalBreak: TFpInternalBreakpoint; AnIgnoreIfExists: Boolean);
var
  LocData: PInternalBreakLocationEntry;
  Len, i: Integer;
  BList: TFpInternalBreakpointArray;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadIdNotMain('TBreakLocationMap.AddLocotion');{$ENDIF}
  LocData := GetDataPtr(ALocation);

  if LocData <> nil then begin
    if LocData^.IsBreakList then begin
      Len := Length(TFpInternalBreakpointArray(LocData^.InternalBreakPoint));
      if AnIgnoreIfExists then begin
        i := Len - 1;
        while (i >= 0) and (TFpInternalBreakpointArray(LocData^.InternalBreakPoint)[i] <> AInternalBreak) do
          dec(i);
        if i >= 0 then
          exit;
      end;

      SetLength(TFpInternalBreakpointArray(LocData^.InternalBreakPoint), Len+1);
      TFpInternalBreakpointArray(LocData^.InternalBreakPoint)[Len] := AInternalBreak;
    end
    else begin
      if AnIgnoreIfExists and (TFpInternalBreakpoint(LocData^.InternalBreakPoint) = AInternalBreak) then
        exit;

      LocData^.IsBreakList := True;
      SetLength(BList, 2);
      BList[0] := TFpInternalBreakpoint(LocData^.InternalBreakPoint);
      BList[1] := AInternalBreak;
      LocData^.InternalBreakPoint := nil;
      TFpInternalBreakpointArray(LocData^.InternalBreakPoint) := BList;
    end;

    exit;
  end;

  FProcess.DoBeforeBreakLocationMapChange; // Only if a new breakpoint is set => memory changed
  new(LocData);
  LocData^.ErrorSetting := not FProcess.InsertBreakInstructionCode(ALocation, LocData^.OrigValue);
  LocData^.IsBreakList := False;
  LocData^.InternalBreakPoint := AInternalBreak;
  Add(ALocation, LocData^);
  Dispose(LocData);
end;

procedure TBreakLocationMap.RemoveLocotion(const ALocation: TDBGPtr;
  const AInternalBreak: TFpInternalBreakpoint);
var
  LocData: PInternalBreakLocationEntry;
  Len, i: Integer;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadIdNotMain('TBreakLocationMap.RemoveLocotion');{$ENDIF}
  LocData := GetDataPtr(ALocation);
  if LocData = nil then begin
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, ['Missing breakpoint for loc ', FormatAddress(ALocation)]);
    exit;
  end;

  if LocData^.IsBreakList then begin
    Len := Length(TFpInternalBreakpointArray(LocData^.InternalBreakPoint));
    i := Len - 1;
    while (i >= 0) and (TFpInternalBreakpointArray(LocData^.InternalBreakPoint)[i] <> AInternalBreak) do
      dec(i);
    if i < 0 then begin
      DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, ['Wrong break for loc ', FormatAddress(ALocation)]);
      exit;
    end;
    if i < Len - 1 then
      move(TFpInternalBreakpointArray(LocData^.InternalBreakPoint)[i+1],
           TFpInternalBreakpointArray(LocData^.InternalBreakPoint)[i],
           (Len - 1 - i) * sizeof(TFpInternalBreakpoint));
    SetLength(TFpInternalBreakpointArray(LocData^.InternalBreakPoint), Len-1);

    if Len > 1 then
      exit;
  end
  else
  if AInternalBreak <> TFpInternalBreakpoint(LocData^.InternalBreakPoint) then begin
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, ['Wrong break for loc ', FormatAddress(ALocation)]);

    exit;
  end;

  FProcess.DoBeforeBreakLocationMapChange; // Only if a breakpoint is removed => memory changed
  if not LocData^.ErrorSetting then
    FProcess.RemoveBreakInstructionCode(ALocation, LocData^.OrigValue);
  Delete(ALocation);
end;

function TBreakLocationMap.GetInternalBreaksAtLocation(const ALocation: TDBGPtr
  ): TFpInternalBreakpointArray;
var
  LocData: PInternalBreakLocationEntry;
begin
  LocData := GetDataPtr(ALocation);
  if LocData = nil then begin
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, ['Missing breakpoint for loc ', FormatAddress(ALocation)]);
    Result := nil;
    exit;
  end;

  if LocData^.IsBreakList then begin
    Result := TFpInternalBreakpointArray(LocData^.InternalBreakPoint)
  end
  else begin
    SetLength(Result, 1);
    Result[0] := TFpInternalBreakpoint(LocData^.InternalBreakPoint);
  end;
end;

function TBreakLocationMap.GetOrigValueAtLocation(const ALocation: TDBGPtr
  ): Byte;
var
  LocData: PInternalBreakLocationEntry;
begin
  LocData := GetDataPtr(ALocation);
  if LocData = nil then begin
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, ['Missing breakpoint for loc ', FormatAddress(ALocation)]);
    Result := TDbgProcess.Int3;
    exit;
  end;
  Result := LocData^.OrigValue;
end;

function TBreakLocationMap.HasInsertedBreakInstructionAtLocation(
  const ALocation: TDBGPtr): Boolean;
begin
  Result := GetDataPtr(ALocation) <> nil;
end;

function TBreakLocationMap.GetEnumerator: TBreakLocationMapEnumerator;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadId('TBreakLocationMap.GetEnumerator');{$ENDIF}
  Result := TBreakLocationMapEnumerator.Create(Self);
end;

procedure TBreakLocationMap.AdaptOriginalValueAtLocation(const ALocation: TDBGPtr; const NewOrigValue: Byte);
var
  LocData: PInternalBreakLocationEntry;
begin
  LocData := GetDataPtr(ALocation);
  if Assigned(LocData) then
    LocData^.OrigValue := NewOrigValue;
end;

{ TDbgCallstackEntry }

function TDbgCallstackEntry.GetProcSymbol: TFpSymbol;
begin
  if not FIsSymbolResolved then begin
    if FIndex > 0 then
      FSymbol := FThread.Process.FindProcSymbol(FAnAddress - 1) // -1 => inside the call instruction
    else
      FSymbol := FThread.Process.FindProcSymbol(FAnAddress);
    FIsSymbolResolved := FSymbol <> nil
  end;
  result := FSymbol;
end;

function TDbgCallstackEntry.GetFunctionName: string;
var
  Symbol: TFpSymbol;
begin
  Symbol := GetProcSymbol;
  if assigned(Symbol) then begin
    if Symbol is TFpSymbolTableProc then begin
      if AnAddress > Symbol.Address.Address then
        result := Format('%s+%d', [Symbol.Name, AnAddress - Symbol.Address.Address])
      else
        result := Symbol.Name;
    end
    else
      result := Symbol.Name;
  end
  else
    result := '';
end;

function TDbgCallstackEntry.GetParamsAsString(
  APrettyPrinter: TFpPascalPrettyPrinter): string;
var
  ProcVal: TFpValue;
  AContext: TFpDbgLocationContext;
  m: TFpValue;
  v: String;
  i: Integer;
begin
  result := '';
  if assigned(ProcSymbol) then begin
    ProcVal := ProcSymbol.Value;
    if (ProcVal <> nil) then begin
      AContext := TFpDbgSimpleLocationContext.Create(FThread.Process.MemManager,
        LocToAddrOrNil(ProcSymbol.Address), DBGPTRSIZE[FThread.Process.Mode], FThread.ID, Index);

      if AContext <> nil then begin
        TFpValueDwarf(ProcVal).Context := AContext;
        APrettyPrinter.Context := AContext;
        APrettyPrinter.AddressSize := AContext.SizeOfAddress;
        for i := 0 to ProcVal.MemberCount - 1 do begin
          m := ProcVal.Member[i];
          if (m <> nil) and (sfParameter in m.DbgSymbol.Flags) then begin
            APrettyPrinter.PrintValue(v, m, wdfDefault, -1, [ppoStackParam]);
            if result <> '' then result := result + ', ';
            result := result + v;
          end;
          m.ReleaseReference;
        end;
        TFpValueDwarf(ProcVal).Context := nil;
        AContext.ReleaseReference;
      end;
      ProcVal.ReleaseReference;
    end;
    if result <> '' then
      result := '(' + result + ')';
  end;
end;

function TDbgCallstackEntry.GetLine: integer;
var
  Symbol: TFpSymbol;
begin
  Symbol := GetProcSymbol;
  if assigned(Symbol) then
    result := Symbol.Line
  else
    result := -1;
end;

function TDbgCallstackEntry.GetSourceFile: string;
var
  Symbol: TFpSymbol;
begin
  Symbol := GetProcSymbol;
  if assigned(Symbol) then
    result := Symbol.FileName
  else
    result := '';
end;

function TDbgCallstackEntry.GetSrcClassName: string;
var
  Symbol: TFpSymbol;
begin
  result := '';
  Symbol := GetProcSymbol;
  if assigned(Symbol) then begin
    Symbol := Symbol.Parent;
    if assigned(Symbol) then begin
      result := Symbol.Name;
      Symbol.ReleaseReference;
    end;
  end;
end;

constructor TDbgCallstackEntry.create(AThread: TDbgThread; AnIndex: integer; AFrameAddress, AnAddress: TDBGPtr);
begin
  FThread := AThread;
  FFrameAdress:=AFrameAddress;
  FAnAddress:=AnAddress;
  FIndex:=AnIndex;
  FRegisterValueList := TDbgRegisterValueList.Create;
end;

destructor TDbgCallstackEntry.Destroy;
begin
  FreeAndNil(FRegisterValueList);
  ReleaseRefAndNil(FSymbol);
  inherited Destroy;
end;

{ TDbgMemReader }

function TDbgMemReader.GetDbgThread(AContext: TFpDbgLocationContext): TDbgThread;
var
  Process: TDbgProcess;
begin
  Process := GetDbgProcess;
  // In fact, AContext should always be assigned, assuming that the main thread
  // should be used is dangerous. But functions like TFpDbgMemManager.ReadSignedInt
  // have a default value of nil for the context. Which is a lot of work to fix.
  if not Assigned(AContext) or not Process.GetThread(AContext.ThreadId, Result) then
    Result := Process.MainThread;
end;

function TDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean;
begin
  result := GetDbgProcess.ReadData(AnAddress, ASize, ADest^);
end;

function TDbgMemReader.ReadMemory(AnAddress: TDbgPtr; ASize: Cardinal;
  ADest: Pointer; out ABytesRead: Cardinal): Boolean;
begin
  result := GetDbgProcess.ReadData(AnAddress, ASize, ADest^, ABytesRead);
end;

function TDbgMemReader.ReadMemoryEx(AnAddress, AnAddressSpace: TDbgPtr; ASize: Cardinal; ADest: Pointer): Boolean;
begin
  Assert(AnAddressSpace>0,'TDbgMemReader.ReadMemoryEx ignores AddressSpace');
  result := GetDbgProcess.ReadData(AnAddress, ASize, ADest^);
end;

function TDbgMemReader.WriteMemory(AnAddress: TDbgPtr; ASize: Cardinal;
  ASource: Pointer): Boolean;
begin
  result := GetDbgProcess.WriteData(AnAddress, ASize, ASource^);
end;

function TDbgMemReader.ReadRegister(ARegNum: Cardinal; out AValue: TDbgPtr; AContext: TFpDbgLocationContext): Boolean;
var
  ARegister: TDbgRegisterValue;
  StackFrame: Integer;
  AFrame: TDbgCallstackEntry;
  CtxThread: TDbgThread;
begin
  // TODO: Thread with ID
  result := false;
  CtxThread := GetDbgThread(AContext);
  if CtxThread = nil then
    exit;

  if AContext <> nil then // TODO: Always true?
    StackFrame := AContext.StackFrame
  else
    StackFrame := 0;
  if StackFrame = 0 then
    begin
    ARegister:=CtxThread.RegisterValueList.FindRegisterByDwarfIndex(ARegNum);
    end
  else
    begin
    CtxThread.PrepareCallStackEntryList(StackFrame+1);
    if CtxThread.CallStackEntryList.Count <= StackFrame then
      exit;
    AFrame := CtxThread.CallStackEntryList[StackFrame];
    if AFrame <> nil then
      ARegister:=AFrame.RegisterValueList.FindRegisterByDwarfIndex(ARegNum)
    else
      ARegister:=nil;
    end;
  if assigned(ARegister) then
    begin
    AValue := ARegister.NumValue;
    result := true;
    end;
end;

function TDbgMemReader.WriteRegister(ARegNum: Cardinal; const AValue: TDbgPtr; AContext: TFpDbgLocationContext): Boolean;
var
  ARegister: TDbgRegisterValue;
  StackFrame: Integer;
  CtxThread: TDbgThread;
begin
  result := false;
  CtxThread := GetDbgThread(AContext);
  if CtxThread = nil then
    exit;

  if AContext <> nil then // TODO: Always true?
    StackFrame := AContext.StackFrame
  else
    StackFrame := 0;
  if StackFrame = 0 then
    begin
    ARegister:=CtxThread.RegisterValueList.FindRegisterByDwarfIndex(ARegNum);
    if assigned(ARegister) then
      begin
      CtxThread.SetRegisterValue(ARegister.Name, AValue);
      CtxThread.LoadRegisterValues;
      result := true;
      end;
    end
end;

function TDbgMemReader.RegisterSize(ARegNum: Cardinal): Integer;
var
  ARegister: TDbgRegisterValue;
begin
  ARegister:=GetDbgProcess.MainThread.RegisterValueList.FindRegisterByDwarfIndex(ARegNum);
  if assigned(ARegister) then
    result := ARegister.Size
  else
    result := sizeof(pointer);
end;

{ TDbgRegisterValueList }

function TDbgRegisterValueList.GetDbgRegister(const AName: string
  ): TDbgRegisterValue;
var
  i: integer;
begin
  for i := 0 to Count -1 do
    if Items[i].Name=AName then
      begin
      result := items[i];
      exit;
      end;
  result := nil;
end;

function TDbgRegisterValueList.GetDbgRegisterAutoCreate(const AName: string
  ): TDbgRegisterValue;
begin
  result := GetDbgRegister(AName);
  if not Assigned(result) then
    begin
    result := TDbgRegisterValue.Create(AName);
    add(result);
    end;
end;

function TDbgRegisterValueList.FindRegisterByDwarfIndex(AnIdx: cardinal): TDbgRegisterValue;
var
  i: Integer;
begin
  for i := 0 to Count-1 do
    if Items[i].DwarfIdx=AnIdx then
    begin
      result := Items[i];
      exit;
    end;
  result := nil;
end;

{ TDbgRegisterValue }

constructor TDbgRegisterValue.Create(const AName: String);
begin
  FName:=AName;
end;

procedure TDbgRegisterValue.SetValue(ANumValue: TDBGPtr;
  const AStrValue: string; ASize: byte; ADwarfIdx: cardinal);
begin
  FStrValue:=AStrValue;
  FNumValue:=ANumValue;
  FSize:=ASize;
  FDwarfIdx:=ADwarfIdx;
end;

procedure TDbgRegisterValue.Setx86EFlagsValue(ANumValue: TDBGPtr);
var
  FlagS: string;
begin
  FlagS := '';
  if ANumValue and (1 shl 0) <> 0 then FlagS := FlagS + 'CF ';
  if ANumValue and (1 shl 2) <> 0 then FlagS := FlagS + 'PF ';
  if ANumValue and (1 shl 4) <> 0 then FlagS := FlagS + 'AF ';
  if ANumValue and (1 shl 6) <> 0 then FlagS := FlagS + 'ZF ';
  if ANumValue and (1 shl 7) <> 0 then FlagS := FlagS + 'SF ';
  if ANumValue and (1 shl 8) <> 0 then FlagS := FlagS + 'TF ';
  if ANumValue and (1 shl 9) <> 0 then FlagS := FlagS + 'IF ';
  if ANumValue and (1 shl 10) <> 0 then FlagS := FlagS + 'DF ';
  if ANumValue and (1 shl 11) <> 0 then FlagS := FlagS + 'OF ';
  if (ANumValue shr 12) and 3 <> 0 then FlagS := FlagS + 'IOPL=' + IntToStr((ANumValue shr 12) and 3);
  if ANumValue and (1 shl 14) <> 0 then FlagS := FlagS + 'NT ';
  if ANumValue and (1 shl 16) <> 0 then FlagS := FlagS + 'RF ';
  if ANumValue and (1 shl 17) <> 0 then FlagS := FlagS + 'VM ';
  if ANumValue and (1 shl 18) <> 0 then FlagS := FlagS + 'AC ';
  if ANumValue and (1 shl 19) <> 0 then FlagS := FlagS + 'VIF ';
  if ANumValue and (1 shl 20) <> 0 then FlagS := FlagS + 'VIP ';
  if ANumValue and (1 shl 21) <> 0 then FlagS := FlagS + 'ID ';

  SetValue(ANumValue, trim(FlagS),4,Cardinal(-1));
end;

{ TDbgAsmInstruction }

function TDbgAsmInstruction.IsCallInstruction: boolean;
begin
  Result := False;
end;

function TDbgAsmInstruction.IsReturnInstruction: boolean;
begin
  Result := False;
end;

function TDbgAsmInstruction.IsLeaveStackFrame: boolean;
begin
  Result := False;
end;

function TDbgAsmInstruction.ModifiesStackPointer: boolean;
begin
  Result := False;
end;

function TDbgAsmInstruction.IsJumpInstruction(IncludeConditional: Boolean;
  IncludeUncoditional: Boolean): boolean;
begin
  Result := False;
end;

function TDbgAsmInstruction.InstructionLength: Integer;
begin
  Result := 0;
end;

{ TDbgAsmDecoder }

function TDbgAsmDecoder.GetLastErrorWasMemReadErr: Boolean;
begin
  Result := False;
end;

function TDbgAsmDecoder.GetCanReverseDisassemble: boolean;
begin
  Result := false;
end;

// Naive backwards scanner, decode MaxInstructionSize
// if pointer to next instruction matches, done!
// If not decrease instruction size and try again.
// Many pitfalls with X86 instruction encoding...
// Avr may give 130/65535 = 0.2% errors per instruction reverse decoded
procedure TDbgAsmDecoder.ReverseDisassemble(var AAddress: Pointer; out
  ACodeBytes: String; out ACode: String);
var
  instrLen: integer;
  tmpAddress: PtrUint;
begin
  // Decode max instruction length backwards,
  instrLen := MaxInstructionSize + MinInstructionSize;
  repeat
    dec(instrLen, MinInstructionSize);
    tmpAddress := PtrUInt(AAddress) - instrLen;
    Disassemble(pointer(tmpAddress), ACodeBytes, ACode);
  until (tmpAddress >= PtrUInt(AAddress)) or (instrLen = MinInstructionSize);

  // After disassemble tmpAddress points to the starting address of next instruction
  // Decrement with the instruction length to point to the start of this instruction
  AAddress := AAddress - instrLen;
end;

function TDbgAsmDecoder.GetFunctionFrameInfo(AnAddress: TDBGPtr; out
  AnIsOutsideFrame: Boolean): Boolean;
begin
  Result := False;
end;

{ TDbgInstance }

function TDbgInstance.AddBreak(const AFileName: String; ALine: Cardinal;
  AnEnabled: Boolean): TFpInternalBreakpoint;
var
  addr: TDBGPtrArray;
  o: Int64;
  i: Integer;
begin
  Result := nil;
  if not FDbgInfo.HasInfo then Exit;
  if FDbgInfo.GetLineAddresses(AFileName, ALine, addr) then begin
    o := AddrOffset;
    for i := 0 to High(addr) do
      addr[i] := addr[i] - o;
    Result := FProcess.AddBreak(addr, AnEnabled);
  end;
end;

function TDbgInstance.AddBreak(const AFuncName: String; AnEnabled: Boolean
  ): TFpDbgBreakpoint;
var
  AProc: TFpSymbol;
begin
  Result := nil;
  AProc := FindProcSymbol(AFuncName);
  if AProc <> nil then begin
    Result := FProcess.AddBreak(AProc.Address.Address, AnEnabled);
    AProc.ReleaseReference;
  end;
end;

function TDbgInstance.AddrOffset: TDBGPtr;
begin
  Result := FLoaderList.ImageBase;
end;

function TDbgInstance.FindProcSymbol(const AName: String): TFpSymbol;
begin
  if FDbgInfo <> nil then
    Result := FDbgInfo.FindProcSymbol(AName)
  else
    Result := nil;
  if (Result = nil) and (SymbolTableInfo <> nil) then
    Result := SymbolTableInfo.FindProcSymbol(AName);
end;

constructor TDbgInstance.Create(const AProcess: TDbgProcess);
begin
  FProcess := AProcess;
  FMemManager := AProcess.MemManager;
  FLoaderList := TDbgImageLoaderList.Create(True);

  inherited Create;
end;

destructor TDbgInstance.Destroy;
begin
  FreeAndNil(FDbgInfo);
  FreeAndNil(FSymbolTableInfo);
  FreeAndNil(FLoaderList);
  inherited;
end;

function TDbgInstance.FindProcSymbol(AAdress: TDbgPtr): TFpSymbol;
begin
  {$PUSH}{$R-}{$Q-}
  AAdress := AAdress + AddrOffset;
  {$POP}
  Result := FDbgInfo.FindProcSymbol(AAdress);
  if not assigned(Result) then
    result := FSymbolTableInfo.FindProcSymbol(AAdress);
end;

procedure TDbgInstance.LoadInfo;
begin
  InitializeLoaders;
  if FLoaderList.TargetInfo.bitness = b64 then  //Image64Bit then
    FMode:=dm64
  else
    FMode:=dm32;
  FDbgInfo := TFpDwarfInfo.Create(FLoaderList, MemManager);
  TFpDwarfInfo(FDbgInfo).LoadCompilationUnits;
  if self is TDbgProcess then
    FSymbolTableInfo := TFpSymbolInfo.Create(FLoaderList, MemManager)
  else
    FSymbolTableInfo := TFpSymbolInfo.Create(FLoaderList, MemManager, ExtractFileNameOnly(FFileName));
end;

procedure TDbgInstance.SetFileName(const AValue: String);
begin
  FFileName := AValue;
end;

procedure TDbgInstance.SetMode(AMode: TFPDMode);
begin
  FMode := AMode;
end;

function TDbgInstance.GetPointerSize: Integer;
const
  PTRSZ: array[TFPDMode] of Integer = (4, 8); // (dm32, dm64)
begin
  Result := PTRSZ[FMode];
end;

function TDbgInstance.GetOSDbgClasses: TOSDbgClasses;
begin
  Result := FProcess.OSDbgClasses;
end;

procedure TDbgInstance.InitializeLoaders;
begin
  // Do nothing;
end;

{ TDbgLibrary }

constructor TDbgLibrary.Create(const AProcess: TDbgProcess; const ADefaultName: String; const AModuleHandle: THandle; const ABaseAddr: TDbgPtr);

begin
  inherited Create(AProcess);
  FModuleHandle:=AModuleHandle;
  FBaseAddr:=ABaseAddr;
end;

{ TDbgProcess }

function TDbgProcess.AddBreak(const ALocation: TDBGPtr; AnEnabled: Boolean
  ): TFpInternalBreakpoint;
var
  a: TDBGPtrArray;
begin
  SetLength(a, 1);
  a[0] := ALocation;
  Result := AddBreak(a, AnEnabled);
// TODO: if a = GetInstructionPointerRegisterValue (of any thread?)
end;

function TDbgProcess.AddBreak(const ALocation: TDBGPtrArray; AnEnabled: Boolean
  ): TFpInternalBreakpoint;
var
  a, ip: TDBGPtr;
begin
  Result := OSDbgClasses.DbgBreakpointClass.Create(Self, ALocation, AnEnabled);
  // TODO: empty breakpoint (all address failed to set) = nil
  ip := FMainThread.GetInstructionPointerRegisterValue;
  if not assigned(FCurrentBreakpoint) then
    for a in ALocation do
      if ip=a then begin
        FCurrentBreakpoint := Result;
        break;
      end;
end;

function TDbgProcess.AddWatch(const ALocation: TDBGPtr; ASize: Cardinal;
  AReadWrite: TDBGWatchPointKind; AScope: TDBGWatchPointScope
  ): TFpInternalWatchpoint;
begin
  Result := OSDbgClasses.DbgWatchpointClass.Create(Self, ALocation, ASize, AReadWrite, AScope);
end;

function TDbgProcess.FindProcSymbol(const AName, ALibraryName: String;
  IsFullLibName: Boolean): TFpSymbol;
var
  lib: TDbgLibrary;
begin
  Result := nil;
  if not FLibMap.GetLib(ALibraryName, lib, IsFullLibName) then
    exit;
  Result := lib.FindProcSymbol(AName);
end;

constructor TDbgProcess.Create(const AFileName: string; const AProcessID,
  AThreadID: Integer; AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager
  );
const
  {.$IFDEF CPU64}
  MAP_ID_SIZE = itu8;
  {.$ELSE}
//  MAP_ID_SIZE = itu4;
  {.$ENDIF}
begin
  FMemManager := AMemManager;
  FProcessID := AProcessID;
  FThreadID := AThreadID;
  FOSDbgClasses := AnOsClasses;

  FBreakpointList := TFpInternalBreakpointList.Create(False);
  FWatchPointList := TFpInternalBreakpointList.Create(False);
  FThreadMap := TThreadMap.Create(itu4, SizeOf(TDbgThread));
  FLibMap := TLibraryMap.Create(MAP_ID_SIZE, SizeOf(TDbgLibrary));
  FWatchPointData := CreateWatchPointData;
  FBreakMap := TBreakLocationMap.Create(Self);
  FCurrentBreakpoint := nil;
  FCurrentWatchpoint := nil;

  FSymInstances := TList.Create;

  SetFileName(AFileName);

  inherited Create(Self);
end;

destructor TDbgProcess.Destroy;

  procedure FreeItemsInMap(AMap: TMap);
  var
    AnObject: TObject;
    Iterator: TMapIterator;
  begin
    iterator := TMapIterator.Create(AMap);
    try
      Iterator.First;
      while not Iterator.EOM do
      begin
        Iterator.GetData(AnObject);
        AnObject.Free;
        iterator.Next;
      end;
    finally
      Iterator.Free;
    end;
  end;

var
  i: Integer;
begin
  FProcessID:=0;
  SetLastLibraryUnloaded(nil);

  for i := 0 to FBreakpointList.Count - 1 do begin
    FBreakpointList[i].FProcess := nil;
    if FBreakpointList[i].FreeByDbgProcess then
      FBreakpointList[i].Free;
  end;
  for i := 0 to FWatchPointList.Count - 1 do begin
    FWatchPointList[i].FProcess := nil;
    if FWatchPointList[i].FreeByDbgProcess then
      FWatchPointList[i].Free;
  end;
  FreeAndNil(FBreakpointList);
  FreeAndNil(FWatchPointList);
  //Assert(FBreakMap.Count=0, 'No breakpoints left');
  //FreeItemsInMap(FBreakMap);
  FreeItemsInMap(FThreadMap);
  FreeItemsInMap(FLibMap);

  FreeAndNil(FWatchPointData);
  FreeAndNil(FBreakMap);
  FreeAndNil(FThreadMap);
  FreeAndNil(FLibMap);
  FreeAndNil(FSymInstances);
  FreeAndNil(FDisassembler);
  inherited;
end;

function TDbgProcess.AddInternalBreak(const ALocation: TDBGPtr): TFpInternalBreakpoint;
begin
  Result := AddBreak(ALocation);
  Result.FInternal := True;
end;

function TDbgProcess.AddInternalBreak(const ALocation: TDBGPtrArray): TFpInternalBreakpoint;
begin
  Result := AddBreak(ALocation);
  Result.FInternal := True;
end;

function TDbgProcess.FindProcSymbol(AAdress: TDbgPtr): TFpSymbol;
var
  n: Integer;
  Inst: TDbgInstance;
begin
  for n := 0 to FSymInstances.Count - 1 do
  begin
    Inst := TDbgInstance(FSymInstances[n]);
    Result := Inst.FindProcSymbol(AAdress);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;

function TDbgProcess.FindSymbolScope(AThreadId, AStackFrame: Integer): TFpDbgSymbolScope;
var
  Thread: TDbgThread;
  Frame: TDbgCallstackEntry;
  Addr: TDBGPtr;
  Ctx: TFpDbgSimpleLocationContext;
  sym: TFpSymbol;
begin
  Result := nil;
  Ctx := TFpDbgSimpleLocationContext.Create(MemManager, Addr, DBGPTRSIZE[Mode], AThreadId, AStackFrame);

  if GetThread(AThreadId, Thread) then begin
    Thread.PrepareCallStackEntryList(AStackFrame + 1);

    if AStackFrame < Thread.CallStackEntryList.Count then begin
      Frame := Thread.CallStackEntryList[AStackFrame];

      if Frame <> nil then begin
        sym := Frame.ProcSymbol;
        if sym <> nil then
          Result := sym.CreateSymbolScope(Ctx);

        if Result = nil then begin
          Addr := Frame.AnAddress;
          if Addr <> 0 then
            Result := FDbgInfo.FindSymbolScope(Ctx, Addr);
        end;
      end;
    end;

    // SymbolTableInfo.FindSymbolScope()
  end;

  if Result = nil then
    Result := TFpDbgSymbolScope.Create(Ctx);

  Ctx.ReleaseReference;
end;

function TDbgProcess.ContextFromProc(AThreadId, AStackFrame: Integer;
  AProcSym: TFpSymbol): TFpDbgLocationContext;
begin
  Result := TFpDbgSimpleLocationContext.Create(MemManager, LocToAddrOrNil(AProcSym.Address), DBGPTRSIZE[Mode], AThreadId, AStackFrame);
end;

function TDbgProcess.GetLib(const AHandle: THandle; out ALib: TDbgLibrary): Boolean;
begin
  Result := FLibMap.GetLib(AHandle, ALib);
end;

function TDbgProcess.GetThread(const AID: Integer; out AThread: TDbgThread): Boolean;
var
  Thread: TDbgThread;
begin
  AThread := nil;
  Result := FThreadMap.GetData(AID, Thread) and (Thread <> nil);
  if Result
  then AThread := Thread;
end;

function TDbgProcess.ReadData(const AAdress: TDbgPtr; const ASize: Cardinal; out AData): Boolean;
begin
  result := false
end;

function TDbgProcess.ReadData(const AAdress: TDbgPtr; const ASize: Cardinal;
  out AData; out APartSize: Cardinal): Boolean;
var
  SizeRemaining, sz: Cardinal;
  Offs: Integer;
  APartAddr: TDBGPtr;
begin
  // subclasses can do better implementation if checking for error reasons, such as part_read
  APartSize := ASize;
  Result := ReadData(AAdress, APartSize, AData);
  if Result then
    exit;

  SizeRemaining := ASize;
  Offs := 0;
  APartAddr := AAdress;
  APartSize := 0;

  while SizeRemaining > 0 do begin
    Result := False;
    sz := SizeRemaining;
    while (not Result) and (sz > 1) do begin
      sz := sz div 2;
      Result := ReadData(APartAddr, sz, (@AData + Offs)^);
    end;
    if not Result then
      break;

    APartSize := APartSize + sz;
    Offs := Offs + sz;
    APartAddr := APartAddr + sz;
    SizeRemaining := SizeRemaining - sz;
  end;

  Result := APartSize > 0;
end;

function TDbgProcess.ReadAddress(const AAdress: TDbgPtr; out AData: TDBGPtr): Boolean;
var
  dw: DWord;
  qw: QWord;
begin
  case Mode of
    dm32:
      begin
        result := ReadData(AAdress, sizeof(dw), dw);
        AData:=dw;
      end;
    dm64:
      begin
        result := ReadData(AAdress, sizeof(qw), qw);
        AData:=qw;
      end;
  end;
end;

function TDbgProcess.ReadOrdinal(const AAdress: TDbgPtr; out AData): Boolean;
begin
  Result := ReadData(AAdress, 4, AData);
end;

function TDbgProcess.ReadString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: String): Boolean;
begin
  Result := false;
end;

function TDbgProcess.ReadWString(const AAdress: TDbgPtr; const AMaxSize: Cardinal; out AData: WideString): Boolean;
begin
  result := false;
end;

function TDbgProcess.CallParamDefaultLocation(AParamIdx: Integer
  ): TFpDbgMemLocation;
begin
  Result := InvalidLoc;
end;

function TDbgProcess.Continue(AProcess: TDbgProcess; AThread: TDbgThread;
  SingleStep: boolean): boolean;
begin
  result := false;
end;

function TDbgProcess.ResolveDebugEvent(AThread: TDbgThread): TFPDEvent;
var
  CurrentAddr: TDBGPtr;
begin
  if AThread <> nil then
    AThread.ValidateRemovedBreakPointInfo;
  result := AnalyseDebugEvent(AThread);

  if (result = deBreakpoint) and (AThread <> nil) then
  begin
    // Determine the address where the execution has stopped
    CurrentAddr:=AThread.GetInstructionPointerRegisterValue;
    FCurrentWatchpoint:=AThread.DetectHardwareWatchpoint;
    if (FCurrentWatchpoint <> nil) and (FWatchPointList.IndexOf(TFpInternalWatchpoint(FCurrentWatchpoint)) < 0) then
      FCurrentWatchpoint := Pointer(-1);
    FCurrentBreakpoint:=nil;
    AThread.NextIsSingleStep:=false;

    // Whatever reason there was to change the result to deInternalContinue,
    // if a breakpoint has been hit, always trigger it...
    if DoBreak(CurrentAddr, AThread.ID) then
      result := deBreakpoint;
  end
end;

function TDbgProcess.CheckForConsoleOutput(ATimeOutMs: integer): integer;
begin
  result := -1;
end;

function TDbgProcess.GetConsoleOutput: string;
begin
  result := '';
end;

procedure TDbgProcess.SendConsoleInput(AString: string);
begin
  // Do nothing
end;

function TDbgProcess.AddThread(AThreadIdentifier: THandle): TDbgThread;
var
  IsMainThread: boolean;
begin
  result := CreateThread(AthreadIdentifier, IsMainThread);
  if assigned(result) then
  begin
    FThreadMap.Add(AThreadIdentifier, Result);
    if IsMainThread then
    begin
      assert(FMainThread=nil);
      FMainThread := result;
    end;
    Result.ApplyWatchPoints(FWatchPointData);
  end
  else
    DebugLn(DBG_WARNINGS, 'Unknown thread ID %u for process %u', [AThreadIdentifier, ProcessID]);
end;

function TDbgProcess.GetThreadArray: TFPDThreadArray;
var
  Iterator: TMapIterator;
  Thread: TDbgThread;
  I: Integer;
begin
  SetLength(Result, FThreadMap.Count);
  Iterator := TMapIterator.Create(FThreadMap);
  try
    Iterator.First;
    I := 0;
    while not Iterator.EOM do
    begin
      Iterator.GetData(Thread);
      Result[I] := Thread;
      Inc(I);
      iterator.Next;
    end;
  finally
    Iterator.Free;
  end;
end;

procedure TDbgProcess.ThreadsBeforeContinue;
var
  Iterator: TMapIterator;
  Thread: TDbgThread;
begin
  Iterator := TLockedMapIterator.Create(FThreadMap);
  try
    Iterator.First;
    while not Iterator.EOM do
    begin
      Iterator.GetData(Thread);
      if FWatchPointData.Changed then
        Thread.ApplyWatchPoints(FWatchPointData);
      Thread.BeforeContinue;
      iterator.Next;
    end;
  finally
    Iterator.Free;
  end;
  FWatchPointData.Changed := False;
end;

procedure TDbgProcess.ThreadsClearCallStack;
var
  Iterator: TMapIterator;
  Thread: TDbgThread;
begin
  Iterator := TLockedMapIterator.Create(FThreadMap);
  try
    Iterator.First;
    while not Iterator.EOM do
    begin
      Iterator.GetData(Thread);
      Thread.ClearCallStack;
      iterator.Next;
    end;
  finally
    Iterator.Free;
  end;
end;

procedure TDbgProcess.RemoveBreak(const ABreakPoint: TFpDbgBreakpoint);
begin
  if ABreakPoint=FCurrentBreakpoint then
    FCurrentBreakpoint := nil;
end;

procedure TDbgProcess.DoBeforeBreakLocationMapChange;
var
  t: TDbgThread;
begin
  for t in FThreadMap do
    t.DoBeforeBreakLocationMapChange;
end;

function TDbgProcess.HasBreak(const ALocation: TDbgPtr): Boolean;
begin
  if FBreakMap = nil then
    Result := False
  else
    result := FBreakMap.HasId(ALocation);
end;

procedure TDbgProcess.RemoveThread(const AID: DWord);
begin
  if FThreadMap = nil then Exit;
  FThreadMap.Delete(AID);
end;

function TDbgProcess.FormatAddress(const AAddress): String;
begin
  Result := HexValue(AAddress, DBGPTRSIZE[Mode], [hvfIncludeHexchar]);
end;

function TDbgProcess.Pause: boolean;
begin
  result := false;
end;

function TDbgProcess.GetHandle: THandle;
begin
  result := 0;
end;

procedure TDbgProcess.SetThreadId(AThreadId: Integer);
begin
  assert(FThreadID = 0, 'TDbgProcess.SetThreadId: FThreadID = 0');
  FThreadID := AThreadId;
end;

procedure TDbgProcess.SetExitCode(AValue: DWord);
begin
  FExitCode:=AValue;
end;

class function TDbgProcess.StartInstance(AFileName: string; AParams,
  AnEnvironment: TStrings; AWorkingDirectory, AConsoleTty: string;
  AFlags: TStartInstanceFlags; AnOsClasses: TOSDbgClasses;
  AMemManager: TFpDbgMemManager; out AnError: TFpError): TDbgProcess;
begin
  DebugLn(DBG_VERBOSE, 'Debug support is not available for this platform.');
  result := nil;
end;

class function TDbgProcess.AttachToInstance(AFileName: string; APid: Integer;
  AnOsClasses: TOSDbgClasses; AMemManager: TFpDbgMemManager; out
  AnError: TFpError): TDbgProcess;
begin
  DebugLn(DBG_VERBOSE, 'Attach not supported');
  Result := nil;
end;

class function TDbgProcess.isSupported(ATargetInfo: TTargetDescriptor): boolean;
begin
  result := false;
end;

procedure TDbgProcess.ThreadDestroyed(const AThread: TDbgThread);
begin
  if AThread = FMainThread
  then FMainThread := nil;
end;

function TDbgProcess.GetPauseRequested: boolean;
begin
  Result := Boolean(InterLockedExchangeAdd(FPauseRequested, 0));
end;

function TDbgProcess.GetRequiresExecutionInDebuggerThread: boolean;
begin
  Result := False;
end;

function TDbgProcess.GetLastLibraryLoaded: TDbgLibrary;
begin
  Result := FLibMap.LastLibraryAdded;
end;

function TDbgProcess.GetDisassembler: TDbgAsmDecoder;
begin
  if FDisassembler = nil then
    FDisassembler := OSDbgClasses.DbgDisassemblerClass.Create(Self);
  Result := FDisassembler;
end;

function TDbgProcess.GetAndClearPauseRequested: Boolean;
begin
  Result := Boolean(InterLockedExchange(FPauseRequested, ord(False)));
end;

procedure TDbgProcess.SetPauseRequested(AValue: boolean);
begin
  InterLockedExchange(FPauseRequested, ord(AValue));
end;

procedure TDbgProcess.LoadInfo;
begin
  inherited LoadInfo;

  if DbgInfo.HasInfo then
    FSymInstances.Add(Self);
end;

function TDbgProcess.GetLastEventProcessIdentifier: THandle;
begin
  result := 0;
end;

function TDbgProcess.DoBreak(BreakpointAddress: TDBGPtr; AThreadID: integer): Boolean;
var
  BList: TFpInternalBreakpointArray;
  i: Integer;
begin
  Result := False;

  BList := FBreakMap.GetInternalBreaksAtLocation(BreakpointAddress);
  if BList = nil then exit;
  i := 0;
  FCurrentBreakpoint := nil;
  while (i < Length(BList)) and (FCurrentBreakpoint = nil) do
    if BList[0].FInternal then
      inc(i)
    else
      FCurrentBreakpoint := BList[i];
  if FCurrentBreakpoint = nil then Exit;

  Result := True;
  if not FCurrentBreakpoint.Hit(AThreadId, BreakpointAddress)
  then FCurrentBreakpoint := nil; // no need for a singlestep if we continue
end;

procedure TDbgProcess.SetLastLibraryUnloaded(ALib: TDbgLibrary);
begin
  if FLastLibraryUnloaded <> nil then
    FLastLibraryUnloaded.Destroy;
  FLastLibraryUnloaded := ALib;
end;

procedure TDbgProcess.SetLastLibraryUnloadedNil(ALib: TDbgLibrary);
begin
  assert(ALib = nil, 'TDbgProcess.SetLastLibraryUnloadedNil: ALib = nil');
  SetLastLibraryUnloaded(nil);
end;

function TDbgProcess.InsertBreakInstructionCode(const ALocation: TDBGPtr; out
  OrigValue: Byte): Boolean;
var
  i: Integer;
begin
  Result := FProcess.ReadData(ALocation, 1, OrigValue);
  if not Result then begin
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, 'Unable to read pre-breakpoint at '+FormatAddress(ALocation));
    exit;
  end;

  if OrigValue = Int3 then
    exit; // breakpoint on a hardcoded breakpoint

  // TODO: maybe remove, when TempRemoveBreakInstructionCode is called by "OS"Classes.Continue, which means no breakpoint can be set, while TempRemove are active
  for i := 0 to high(FTmpRemovedBreaks) do
    if ALocation = FTmpRemovedBreaks[i] then
      exit;

  BeforeChangingInstructionCode(ALocation, 1);

  Result := FProcess.WriteData(ALocation, 1, Int3);
  DebugLn(DBG_VERBOSE or DBG_BREAKPOINTS, ['Breakpoint Int3 set to '+FormatAddress(ALocation), ' Result:',Result, ' OVal:', OrigValue]);
  if not Result then
    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS, 'Unable to set breakpoint at '+FormatAddress(ALocation));

  if Result then
    AfterChangingInstructionCode(ALocation, 1);
end;

function TDbgProcess.RemoveBreakInstructionCode(const ALocation: TDBGPtr;
  const OrigValue: Byte): Boolean;
begin
  if OrigValue = Int3 then
    exit(True); // breakpoint on a hardcoded breakpoint

  BeforeChangingInstructionCode(ALocation, 1);

  Result := WriteData(ALocation, 1, OrigValue);
  DebugLn(DBG_VERBOSE or DBG_BREAKPOINTS, ['Breakpoint Int3 removed from '+FormatAddress(ALocation), ' Result:',Result, ' OVal:', OrigValue]);
  DebugLn((not Result) and (not GotExitProcess) and (DBG_WARNINGS or DBG_BREAKPOINTS), 'Unable to reset breakpoint at %s', [FormatAddress(ALocation)]);

  if Result then
    AfterChangingInstructionCode(ALocation, 1);
end;

procedure TDbgProcess.RemoveAllBreakPoints;
var
  i: LongInt;
  b: TFpInternalBreakBase;
begin
  i := FBreakpointList.Count - 1;
  while i >= 0 do begin
    b := FBreakpointList[i];
    b.ResetBreak;
    b.FProcess := nil;
    FBreakpointList.Delete(i);
    dec(i);
  end;
  i := FWatchPointList.Count - 1;
  while i >= 0 do begin
    b := FWatchPointList[i];
    b.ResetBreak;
    b.FProcess := nil;
    FWatchPointList.Delete(i);
    dec(i);
  end;
  assert(FBreakMap.Count = 0, 'TDbgProcess.RemoveAllBreakPoints: FBreakMap.Count = 0');
end;

procedure TDbgProcess.BeforeChangingInstructionCode(const ALocation: TDBGPtr; ACount: Integer);
begin
  //
end;

procedure TDbgProcess.AfterChangingInstructionCode(const ALocation: TDBGPtr; ACount: Integer);
begin
  //
end;

//function TDbgProcess.LocationIsBreakInstructionCode(const ALocation: TDBGPtr
//  ): Boolean;
//var
//  OVal: Byte;
//begin
//  Result := FBreakMap.HasId(ALocation);
//  if not Result then
//    exit;
//
//  Result := FProcess.ReadData(ALocation, 1, OVal);
//  if Result then
//    Result := OVal = Int3
//  else
//    DebugLn(DBG_WARNINGS or DBG_BREAKPOINTS'Unable to read pre-breakpoint at '+FormatAddress(ALocation));
//end;

procedure TDbgProcess.TempRemoveBreakInstructionCode(const ALocation: TDBGPtr);
var
  OVal: Byte;
  l, i: Integer;
begin
  DebugLn(DBG_VERBOSE or DBG_BREAKPOINTS, ['>>> TempRemoveBreakInstructionCode']);
  l := length(FTmpRemovedBreaks);
  for i := 0 to l-1 do
    if FTmpRemovedBreaks[i] = ALocation then
      exit;

  OVal := FBreakMap.GetOrigValueAtLocation(ALocation);
  if OVal = Int3 then
    exit;

  SetLength(FTmpRemovedBreaks, l+1);
  FTmpRemovedBreaks[l] := ALocation;
  RemoveBreakInstructionCode(ALocation, OVal); // Do not update FBreakMap
  DebugLn(DBG_VERBOSE or DBG_BREAKPOINTS, ['<<< TempRemoveBreakInstructionCode']);
end;

procedure TDbgProcess.RestoreTempBreakInstructionCodes;
var
  OVal: Byte;
  t: array of TDBGPtr;
  i: Integer;
begin
  if Length(FTmpRemovedBreaks) = 0 then
    exit;
  DebugLnEnter(DBG_VERBOSE or DBG_BREAKPOINTS, ['>>> RestoreTempBreakInstructionCodes']);
  t := FTmpRemovedBreaks;
  FTmpRemovedBreaks := nil;
  for i := 0 to length(t) - 1 do
    if FBreakMap.HasId(t[i]) then // may have been removed
      InsertBreakInstructionCode(t[i], OVal);
  DebugLnExit(DBG_VERBOSE or DBG_BREAKPOINTS, ['<<< RestoreTempBreakInstructionCodes']);
end;

function TDbgProcess.HasInsertedBreakInstructionAtLocation(
  const ALocation: TDBGPtr): Boolean;
begin
  Result := FBreakMap.HasInsertedBreakInstructionAtLocation(ALocation);
end;

procedure TDbgProcess.MaskBreakpointsInReadData(const AAdress: TDbgPtr; const ASize: Cardinal; var AData);
var
  Brk: TBreakLocationEntry;
begin
  for Brk in FBreakMap do begin
    if (Brk.Location >= AAdress) and (Brk.Location < (AAdress+ASize)) then
      TByteArray(AData)[Brk.Location-AAdress] := Brk.OrigValue;
  end;
end;

function TDbgProcess.CreateWatchPointData: TFpWatchPointData;
begin
  Result := TFpWatchPointData.Create;
end;

function TDbgProcess.WriteData(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean;
begin
  result := false;
end;

function TDbgProcess.Detach(AProcess: TDbgProcess; AThread: TDbgThread
  ): boolean;
begin
  Result := False;
end;

function TDbgProcess.WriteInstructionCode(const AAdress: TDbgPtr; const ASize: Cardinal; const AData): Boolean;
var
  i: Integer;
begin
  BeforeChangingInstructionCode(AAdress, ASize);
  for i := 0 to ASize -1 do
  begin
    if HasInsertedBreakInstructionAtLocation(AAdress+i) then
      FBreakMap.AdaptOriginalValueAtLocation(AAdress+i, PByte(@AData+i)^);
  end;
  Result := WriteData(AAdress, ASize, AData);
  AfterChangingInstructionCode(AAdress, ASize);
end;


{ TDbgStackFrameInfo }

procedure TDbgStackFrameInfo.DoAfterRun;
var
  CurStackFrame: TDBGPtr;
begin
  FProcessAfterRun := False;
  case FLeaveState of
    lsWasAtLeave1: begin
        CurStackFrame   := FThread.GetStackBasePointerRegisterValue;
        FStoredStackPointer := FThread.GetStackPointerRegisterValue;
        if CurStackFrame <> FStoredStackFrame then
          FLeaveState := lsLeaveDone // real leave
        else
          FLeaveState := lsWasAtLeave2; // lea rsp,[rbp+$00] / pop ebp // epb in next command
      end;
    lsWasAtLeave2: begin
        // TODO: maybe check, if stackpointer only goes down by sizeof(pointer) "Pop bp"
        FStoredStackFrame   := FThread.GetStackBasePointerRegisterValue;
        FStoredStackPointer := FThread.GetStackPointerRegisterValue;
        FLeaveState := lsLeaveDone;
      end;
  end;
end;

procedure TDbgStackFrameInfo.DoCheckNextInstruction(
  ANextInstruction: TDbgAsmInstruction; NextIsSingleStep: Boolean);
begin
  if FProcessAfterRun then
    DoAfterRun;

  if not NextIsSingleStep then begin
    if FLeaveState = lsWasAtLeave2 then
      FLeaveState := lsLeaveDone;
    exit;
  end;

  if ANextInstruction.IsReturnInstruction then begin
    FHasSteppedOut := True;
    FLeaveState := lsLeaveDone;
  end
  else if FLeaveState = lsNone then begin
    if ANextInstruction.IsLeaveStackFrame then
      FLeaveState := lsWasAtLeave1;
  end;

  FProcessAfterRun := FLeaveState in [lsWasAtLeave1, lsWasAtLeave2];
end;

function TDbgStackFrameInfo.CalculateHasSteppedOut: Boolean;
var
  CurBp, CurSp: TDBGPtr;
begin
  if FProcessAfterRun then
    DoAfterRun;

  Result := False;
  CurBp := FThread.GetStackBasePointerRegisterValue;
  if FStoredStackFrame < CurBp then begin
    CurSp := FThread.GetStackPointerRegisterValue;
    if FStoredStackPointer >= CurSp then // this happens, if current was recorded before the BP frame was set up // a finally handle may then fake an outer frame
      exit;
//    {$PUSH}{$Q-}{$R-}
//    if CurSp = FStoredStackPointer + FThread.Process.PointerSize then
//      exit; // Still in proc, but passed asm "leave" (BP has been popped, but IP not yet)
//    {$POP}
    Result := True;
    debugln(FPDBG_COMMANDS, ['BreakStepBaseCmd.GetIsSteppedOut: Has stepped out Stored-BP=', FStoredStackFrame, ' < BP=', CurBp, ' / SP', CurSp]);
  end;
end;

constructor TDbgStackFrameInfo.Create(AThread: TDbgThread);
begin
  FThread := AThread;
  FStoredStackFrame   := AThread.GetStackBasePointerRegisterValue;
  FStoredStackPointer := AThread.GetStackPointerRegisterValue;
end;

procedure TDbgStackFrameInfo.CheckNextInstruction(
  ANextInstruction: TDbgAsmInstruction; NextIsSingleStep: Boolean);
begin
  if not FHasSteppedOut then
    DoCheckNextInstruction(ANextInstruction, NextIsSingleStep);
end;

function TDbgStackFrameInfo.HasSteppedOut: Boolean;
begin
  Result := FHasSteppedOut;
  if Result then
    exit;
  FHasSteppedOut := CalculateHasSteppedOut;
  Result := FHasSteppedOut;
end;

procedure TDbgStackFrameInfo.FlagAsSteppedOut;
begin
  FHasSteppedOut := True;
end;

{ TDbgThread }

function TDbgThread.GetRegisterValueList: TDbgRegisterValueList;
begin
  if not FRegisterValueListValid then
    LoadRegisterValues;
  result := FRegisterValueList;
end;

function TDbgThread.CompareStepInfo(AnAddr: TDBGPtr; ASubLine: Boolean
  ): TFPDCompareStepInfo;
var
  Sym: TFpSymbol;
  l: TDBGPtr;
begin
  if FStoreStepSrcLineNo = -1 then begin // stepping from location with no line info
    Result := dcsiNewLine;
    exit;
  end;

  if AnAddr = 0 then
    AnAddr := GetInstructionPointerRegisterValue;

  if (FStoreStepStartAddr <> 0) then begin
    if (AnAddr > FStoreStepStartAddr) and (AnAddr < FStoreStepEndAddr)
    then begin
      result := dcsiSameLine;
      exit;
    end
    else
    if ASubLine then begin
      // this is used for the (unmarked) proloque of finally handlers in 3.1.1
      result := dcsiNewLine; // may have the same line number, but has a new address block
      exit;
    end;
  end;

  sym := FProcess.FindProcSymbol(AnAddr);
  if assigned(sym) then
  begin
    if sym is TFpSymbolDwarfDataProc then
      l := TFpSymbolDwarfDataProc(sym).LineUnfixed
    else
      l := Sym.Line;
    debugln(FPDBG_COMMANDS, ['CompareStepInfo @IP=',AnAddr,' ',sym.FileName, ':',l, ' in ',sym.Name, ' @Func=',sym.Address.Address]);
    if (((FStoreStepSrcFilename=sym.FileName) and (FStoreStepSrcLineNo=l)) {or FStepOut}) then
      result := dcsiSameLine
    else if sym.FileName = '' then
      result := dcsiNoLineInfo
    else if l = 0 then
      result := dcsiZeroLine
    else
      result := dcsiNewLine;
    sym.ReleaseReference;
  end
  else
    result := dcsiNoLineInfo;
end;

function TDbgThread.IsAtStartOfLine: boolean;
var
  AnAddr, b: TDBGPtr;
  Sym: TFpSymbol;
  CU: TDwarfCompilationUnit;
  a: TDBGPtrArray;
begin
  AnAddr := GetInstructionPointerRegisterValue;
  sym := FProcess.FindProcSymbol(AnAddr);
  if (sym is TDbgDwarfSymbolBase) then
  begin
    CU := TDbgDwarfSymbolBase(sym).CompilationUnit;
    Result := False;
    CU.GetLineAddresses(sym.FileName, sym.Line, a);
    for b in a do begin
      Result := b = AnAddr;
      if Result then break;
    end;
  end
  else
    Result := True;
  sym.ReleaseReference;
end;

procedure TDbgThread.StoreStepInfo(AnAddr: TDBGPtr);
var
  Sym: TFpSymbol;
begin
  if AnAddr = 0 then
    AnAddr := GetInstructionPointerRegisterValue;
  sym := FProcess.FindProcSymbol(AnAddr);
  FStoreStepStartAddr := AnAddr;
  FStoreStepEndAddr := AnAddr;
  if assigned(sym) then
  begin
    FStoreStepSrcFilename:=sym.FileName;
    FStoreStepFuncAddr:=sym.Address.Address;
    FStoreStepFuncName:=sym.Name;
    if sym is TFpSymbolDwarfDataProc then begin
      FStoreStepStartAddr := TFpSymbolDwarfDataProc(sym).LineStartAddress;
      FStoreStepEndAddr := TFpSymbolDwarfDataProc(sym).LineEndAddress;
      FStoreStepSrcLineNo := TFpSymbolDwarfDataProc(sym).LineUnfixed;
    end
    else
      FStoreStepSrcLineNo:=sym.Line;
    debugln(FPDBG_COMMANDS, ['StoreStepInfo @IP=',AnAddr,' ',sym.FileName, ':',FStoreStepSrcLineNo, ' in ',sym.Name, ' @Func=',sym.Address.Address]);
    sym.ReleaseReference;
  end
  else begin
    debugln(FPDBG_COMMANDS, ['StoreStepInfo @IP=',AnAddr,' - No symbol']);
    FStoreStepSrcLineNo:=-1;
  end;
end;

procedure TDbgThread.LoadRegisterValues;
begin
  // Do nothing
end;

procedure TDbgThread.DoBeforeBreakLocationMapChange;
var
  t: TDBGPtr;
begin
  if (FPausedAtRemovedBreakPointState <> rbUnknown) and
     (FPausedAtRemovedBreakPointAddress = GetInstructionPointerRegisterValue) then
    exit;

  t := GetInstructionPointerRegisterValue;
  if (t <> 0) and Process.HasInsertedBreakInstructionAtLocation(t - 1) then begin
  (* There is a chance, that the code jumped to this Addr, instead of executing the breakpoint.
     But if the next signal for this thread is a breakpoint at this address, then
     it must be handled (even if the breakpoint has been removed since)
  *)
    FPausedAtRemovedBreakPointAddress := t;
    FPausedAtRemovedBreakPointState := rbFound;
    // Most likely the debugger should see the previous address (unless we got here
    // by jump.
    // Call something like ResetInstructionPointerAfterBreakpointForPendingSignal; virtual;
    ////ResetInstructionPointerAfterBreakpoint;
  end
  else
    FPausedAtRemovedBreakPointState := rbNone;
end;

procedure TDbgThread.ValidateRemovedBreakPointInfo;
begin
  if (FPausedAtRemovedBreakPointState <> rbUnknown) and
     (FPausedAtRemovedBreakPointAddress <> GetInstructionPointerRegisterValue)
  then
    FPausedAtRemovedBreakPointState := rbUnknown;
end;

constructor TDbgThread.Create(const AProcess: TDbgProcess; const AID: Integer; const AHandle: THandle);
begin
  FID := AID;
  FHandle := AHandle;
  FProcess := AProcess;
  FRegisterValueList:=TDbgRegisterValueList.Create;
  inherited Create;
end;

function TDbgThread.HasInsertedBreakInstructionAtLocation(const ALocation: TDBGPtr): Boolean;
var
  t: TDBGPtr;
begin
  t := GetInstructionPointerRegisterValue;
  Result := ( (FPausedAtRemovedBreakPointState = rbFound) and
              (FPausedAtRemovedBreakPointAddress = t) ) or
            ( (t <> 0) and Process.HasInsertedBreakInstructionAtLocation(t - 1) );
end;

procedure TDbgThread.CheckAndResetInstructionPointerAfterBreakpoint;
var
  t: TDBGPtr;
  OVal: Byte;
begin
  // todo: check that the breakpoint is NOT in the temp removed list
  t := GetInstructionPointerRegisterValue;
  if t = 0 then
    exit;
  if HasInsertedBreakInstructionAtLocation(t - 1)
  then begin
    FPausedAtRemovedBreakPointState := rbFound;
    ResetInstructionPointerAfterBreakpoint;
  end
  else begin
    // TODO: allow to skip this, while detaching
    if FProcess.ReadData(t-1, 1, OVal) then
      FPausedAtHardcodeBreakPoint := OVal = TDbgProcess.Int3;
  end;
end;

procedure TDbgThread.BeforeContinue;
begin
  // On Windows this is only called, if this was the signalled thread
  FPausedAtHardcodeBreakPoint := False;
  FPausedAtRemovedBreakPointState := rbUnknown;
  FPausedAtRemovedBreakPointAddress := 0;
end;

procedure TDbgThread.ApplyWatchPoints(AWatchPointData: TFpWatchPointData);
begin
  //
end;

function TDbgThread.DetectHardwareWatchpoint: Pointer;
begin
  result := nil;
end;

function TDbgThread.GetCurrentStackFrameInfo: TDbgStackFrameInfo;
begin
  Result := TDbgStackFrameInfo.Create(Self);
end;

procedure TDbgThread.PrepareCallStackEntryList(AFrameRequired: Integer);
const
  MAX_FRAMES = 50000; // safety net
var
  Address, FrameBase, LastFrameBase: QWord;
  Size, CountNeeded, IP, BP, CodeReadErrCnt, SP: integer;
  AnEntry: TDbgCallstackEntry;
  R: TDbgRegisterValue;
  nIP, nBP, nSP: String;
  NextIdx: LongInt;
  OutSideFrame: Boolean;
  StackPtr: TDBGPtr;
begin
  // TODO: use AFrameRequired // check if already partly done
  if FCallStackEntryList = nil then
    FCallStackEntryList := TDbgCallstackEntryList.Create;
  if AFrameRequired = -2 then
    exit;

  if (AFrameRequired >= 0) and (AFrameRequired < FCallStackEntryList.Count) then
    exit;

  case FProcess.Mode of
    dm32: begin
      Size := 4;
      IP := 8; // Dwarf Reg Num EIP
      BP := 5; // EBP
      SP := 4; // ESP
      nIP := 'eip';
      nBP := 'ebp';
      nSP := 'esp';
    end;
    dm64: begin
      Size := 8;
      IP := 16; // Dwarf Reg Num RIP
      BP := 6; // RBP
      SP := 7; // RSP
      nIP := 'rip';
      nBP := 'rbp';
      nSP := 'rsp';
    end;
    else begin
      assert(False, 'unknown address size for stack');
      exit;
    end;
  end;

  FCallStackEntryList.FreeObjects:=true;

  if FCallStackEntryList.Count > 0 then begin
    AnEntry := FCallStackEntryList[FCallStackEntryList.Count - 1];
    R := AnEntry.RegisterValueList.FindRegisterByDwarfIndex(IP);
    if R = nil then exit;
    Address := R.NumValue;
    R := AnEntry.RegisterValueList.FindRegisterByDwarfIndex(BP);
    if R = nil then exit;
    FrameBase := R.NumValue;
    R := AnEntry.RegisterValueList.FindRegisterByDwarfIndex(SP);
    if R = nil then exit;
    StackPtr := R.NumValue;
  end
  else begin
    Address := GetInstructionPointerRegisterValue;
    FrameBase := GetStackBasePointerRegisterValue;
    StackPtr := GetStackPointerRegisterValue;
    AnEntry := TDbgCallstackEntry.create(Self, 0, FrameBase, Address);
    // Top level could be without entry in registerlist / same as GetRegisterValueList / but some code tries to find it here ....
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nIP].SetValue(Address, IntToStr(Address),Size, IP);
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nBP].SetValue(FrameBase, IntToStr(FrameBase),Size, BP);
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nSP].SetValue(StackPtr, IntToStr(StackPtr),Size, SP);
    FCallStackEntryList.Add(AnEntry);
  end;

  NextIdx := FCallStackEntryList.Count;
  if AFrameRequired < 0 then
    AFrameRequired := MaxInt;
  CountNeeded := AFrameRequired - FCallStackEntryList.Count;
  LastFrameBase := 0;
  CodeReadErrCnt := 0;
  while (CountNeeded > 0) and (FrameBase <> 0) and (FrameBase > LastFrameBase) do
  begin
    if not Process.Disassembler.GetFunctionFrameInfo(Address, OutSideFrame) then begin
      if Process.Disassembler.LastErrorWasMemReadErr then begin
      inc(CodeReadErrCnt);
      if CodeReadErrCnt > 5 then break; // If the code cannot be read the stack pointer is wrong.
      end;
        OutSideFrame := False;
    end;
    LastFrameBase := FrameBase;

    if (not OutSideFrame) and (NextIdx = 1) and (AnEntry.ProcSymbol <> nil) then begin
      OutSideFrame := Address = LocToAddrOrNil(AnEntry.ProcSymbol.Address); // the top frame must be outside frame, if it is at entrypoint / needed for exceptions
    end;

    if OutSideFrame then begin
      if not Process.ReadData(StackPtr, Size, Address) or (Address = 0) then Break;
      {$PUSH}{$R-}{$Q-}
      StackPtr := StackPtr + 1 * Size; // After popping return-addr from "StackPtr"
      LastFrameBase := LastFrameBase - 1; // Make the loop think thas LastFrameBase was smaller
      {$POP}
      // last stack has no frame
      //AnEntry.RegisterValueList.DbgRegisterAutoCreate[nBP].SetValue(0, '0',Size, BP);
    end
    else begin
      {$PUSH}{$R-}{$Q-}
      StackPtr := FrameBase + 2 * Size; // After popping return-addr from "FrameBase + Size"
      {$POP}
      if not Process.ReadData(FrameBase + Size, Size, Address) or (Address = 0) then Break;
      if not Process.ReadData(FrameBase, Size, FrameBase) then Break;
    end;
    AnEntry := TDbgCallstackEntry.create(Self, NextIdx, FrameBase, Address);
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nIP].SetValue(Address, IntToStr(Address),Size, IP);
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nBP].SetValue(FrameBase, IntToStr(FrameBase),Size, BP);
    AnEntry.RegisterValueList.DbgRegisterAutoCreate[nSP].SetValue(StackPtr, IntToStr(StackPtr),Size, SP);
    FCallStackEntryList.Add(AnEntry);
    Dec(CountNeeded);
    inc(NextIdx);
    CodeReadErrCnt := 0;
    If (NextIdx > MAX_FRAMES) then
      break;
  end;
  if CountNeeded > 0 then // there was an error / not possible to read more frames
    FCallStackEntryList.SetHasReadAllAvailableFrames;
end;

function TDbgThread.FindCallStackEntryByBasePointer(AFrameBasePointer: TDBGPtr;
  AMaxFrameToSearch: Integer; AStartFrame: integer): Integer;
var
  RegFP: Integer;
  AFrame: TDbgCallstackEntry;
  ARegister: TDbgRegisterValue;
  fp, prev_fp: TDBGPtr;
begin
  if Process.Mode = dm64 then
    RegFP := 6
  else
    RegFP := 5;

  Result := AStartFrame;
  prev_fp := low(prev_fp);
  while Result <= AMaxFrameToSearch do begin
    PrepareCallStackEntryList(Result+1);
    if CallStackEntryList.Count <= Result then
      exit(-1);

    AFrame := CallStackEntryList[Result];
    if AFrame = nil then
      exit(-1);
    ARegister := AFrame.RegisterValueList.FindRegisterByDwarfIndex(RegFP);
    if ARegister = nil then
      exit(-1);

    fp := ARegister.NumValue;

    if fp = AFrameBasePointer then
      exit;

    if (fp < prev_fp) or (fp > AFrameBasePointer) then
      exit(-1);

    prev_fp := fp;
    inc(Result);
  end;
end;

function TDbgThread.FindCallStackEntryByInstructionPointer(
  AInstructionPointer: TDBGPtr; AMaxFrameToSearch: Integer; AStartFrame: integer
  ): Integer;
var
  RegIP: Integer;
  AFrame: TDbgCallstackEntry;
  ARegister: TDbgRegisterValue;
  ip: TDBGPtr;
begin
  if Process.Mode = dm64 then
    RegIP := 16
  else
    RegIP := 8;

  Result := AStartFrame;
  while Result <= AMaxFrameToSearch do begin
    PrepareCallStackEntryList(Result+1);
    if CallStackEntryList.Count <= Result then
      exit(-1);

    AFrame := CallStackEntryList[Result];
    if AFrame = nil then
      exit(-1);
    ARegister := AFrame.RegisterValueList.FindRegisterByDwarfIndex(RegIP);
    if ARegister = nil then
      exit(-1);

    ip := ARegister.NumValue;

    if ip = AInstructionPointer then
      exit;

    inc(Result);
  end;
end;

procedure TDbgThread.ClearCallStack;
begin
  if FCallStackEntryList <> nil then
    FCallStackEntryList.Clear;
end;

destructor TDbgThread.Destroy;
begin
  FProcess.ThreadDestroyed(Self);
  FreeAndNil(FRegisterValueList);
  ClearCallStack;
  FreeAndNil(FCallStackEntryList);
  inherited;
end;

procedure TDbgThread.ClearExceptionSignal;
begin
  // To be implemented in sub-classes
end;

{ TFpWatchPointData }

function TFpWatchPointData.AddOwnedWatchpoint(AnOwner: Pointer;
  AnAddr: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind): boolean;
begin
  Result := False;
end;

function TFpWatchPointData.RemoveOwnedWatchpoint(AnOwner: Pointer): boolean;
begin
  Result := True;
end;

{ TFpIntelWatchPointData }

function TFpIntelWatchPointData.GetDr03(AnIndex: Integer): TDBGPtr;
begin
  Result := FDr03[AnIndex];
end;

function TFpIntelWatchPointData.GetOwner(AnIndex: Integer): Pointer;
begin
  Result := FOwners[AnIndex];
end;

function TFpIntelWatchPointData.AddOwnedWatchpoint(AnOwner: Pointer;
  AnAddr: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind): boolean;
var
  SizeBits, ModeBits: DWord;
  idx: Integer;
begin
  Result := False;
  case ASize of
    1: SizeBits := $00000 shl 2;
    2: SizeBits := $10000 shl 2;
    4: SizeBits := $30000 shl 2;
    8: SizeBits := $20000 shl 2; // Only certain cpu / must be 8byte aligned
    else exit;
  end;
  case AReadWrite of
    wpkWrite:     ModeBits := $10000;
    wpkRead:      ModeBits := $30000; // caller must check
    wpkReadWrite: ModeBits := $30000;
    wkpExec:      ModeBits := $00000; // Size must be 1 (SizeBits=0)
  end;

  for idx := 0 to 3 do begin
    if (FDr7 and (1 shl (idx * 2))) = 0 then begin
      FDr7 := FDr7 or (1 shl (idx*2))
                   or (ModeBits shl (idx*4)) // read/write
                   or (SizeBits shl (idx*4)); // size
      FDr03[idx] := AnAddr;
      FOwners[idx] := AnOwner;
      Changed := True;
      Result := True;
      break;
    end;
  end;
end;

function TFpIntelWatchPointData.RemoveOwnedWatchpoint(AnOwner: Pointer
  ): boolean;
var
  idx: Integer;
begin
  Result := False;
  for idx := 0 to 3 do begin
    if FOwners[idx] = AnOwner then begin
      FDr7 := FDr7 and not (
                   (DWord(3) shl (idx*2)) or
                   (DWord($F0000) shl (idx*4))
      );
      FDr03[idx] := 0;
      FOwners[idx] := nil;
      Changed := True;
      Result := True;
    end;
  end;
end;

{ TFpInternalBreakBase }

constructor TFpInternalBreakBase.Create(const AProcess: TDbgProcess);
begin
  inherited Create;
  FProcess := AProcess;
end;

{ TDbgBreak }

constructor TFpInternalBreakpoint.Create(const AProcess: TDbgProcess;
  const ALocation: TDBGPtrArray; AnEnabled: Boolean);
begin
  inherited Create(AProcess);
  FProcess.FBreakpointList.Add(Self);
  FLocation := ALocation;
  if AnEnabled then
    SetBreak;
end;

destructor TFpInternalBreakpoint.Destroy;
begin
  if FProcess <> nil then
    FProcess.FBreakpointList.Remove(Self);
  ResetBreak;
  inherited;
end;

function TFpInternalBreakpoint.Hit(const AThreadID: Integer;
  ABreakpointAddress: TDBGPtr): Boolean;
begin
  Result := False;
  assert(FProcess<>nil, 'TFpInternalBreakpoint.Hit: FProcess<>nil');
  if //FProcess.FBreakMap.HasId(ABreakpointAddress) and
     (FProcess.FBreakMap.GetOrigValueAtLocation(ABreakpointAddress) = TDbgProcess.Int3)
  then
    exit; // breakpoint on a hardcoded breakpoint
          // no need to jump back and restore instruction

  Result := true;
end;

function TFpInternalBreakpoint.HasLocation(const ALocation: TDBGPtr): Boolean;
var
  i: Integer;
begin
  Result := True;
  for i := 0 to High(FLocation) do begin
    if FLocation[i] = ALocation then
      exit;
  end;
  Result := False;
end;

procedure TFpInternalBreakpoint.AddAddress(const ALocation: TDBGPtr);
var
  l: Integer;
begin
  l := Length(FLocation);
  SetLength(FLocation, l+1);
  FLocation[l] := ALocation;
end;

procedure TFpInternalBreakpoint.RemoveAddress(const ALocation: TDBGPtr);
var
  l, i: Integer;
begin
  l := Length(FLocation) - 1;
  i := l;
  while (i >= 0) and (FLocation[i] <> ALocation) do
    dec(i);
  if i < 0 then
    exit;
  FLocation[i] := FLocation[l];
  SetLength(FLocation, l-1);
  FProcess.FBreakMap.RemoveLocotion(ALocation, Self);
end;

procedure TFpInternalBreakpoint.RemoveAllAddresses;
begin
  ResetBreak;
  SetLength(FLocation, 0);
end;

procedure TFpInternalBreakpoint.ResetBreak;
var
  i: Integer;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadId('TFpInternalBreakpoint.ResetBreak');{$ENDIF}
  if FProcess = nil then
    exit;
  for i := 0 to High(FLocation) do
    FProcess.FBreakMap.RemoveLocotion(FLocation[i], Self);
end;

procedure TFpInternalBreakpoint.SetBreak;
var
  i: Integer;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadId('TFpInternalBreakpoint.SetBreak');{$ENDIF}
  if FProcess = nil then
    exit;
  for i := 0 to High(FLocation) do
    FProcess.FBreakMap.AddLocotion(FLocation[i], Self, True);
end;

{ TFpInternalWatchpoint }

constructor TFpInternalWatchpoint.Create(const AProcess: TDbgProcess;
  const ALocation: TDBGPtr; ASize: Cardinal; AReadWrite: TDBGWatchPointKind;
  AScope: TDBGWatchPointScope);
(* FROM INTEL DOCS / About 8 byte watchpoints
For Pentium® 4 and Intel® Xeon® processors with a CPUID signature corresponding to family 15 (model 3, 4, and 6),
break point conditions permit specifying 8-byte length on data read/write with an of encoding 10B in the LENn field.
Encoding 10B is also supported in processors based on Intel Core microarchitecture or
enhanced Intel Core microarchitecture, the respective CPUID signatures corresponding to family 6, model 15,
and family 6, DisplayModel value 23 (see CPUID instruction in Chapter 3,
“Instruction Set Reference, A-L” in the Intel® 64 and IA-32 Architectures Software Developer’s Manual, Volume 2A).
The Encoding 10B is supported in processors based on Intel® Atom™ microarchitecture,
with CPUID signature of family 6, DisplayModel value 1CH. The encoding 10B is undefined for other processors
*)
const
  MAX_WATCH_SIZE = 8;
  SIZE_TO_BOUNDMASK: array[1..8] of TDBGPtr = (
    0,        // Size=1
    1, 0,     // Size=2
    3, 0,0,0, // Size=4
    7         // Size=8
    );
  SIZE_TO_WATCHSIZE: array[0..8] of Integer = (0, 1, 2, 4, 4, 8, 8, 8, 8);
var
  MaxWatchSize: Integer;
  BoundaryOffset, S, HalfSize: Integer;
begin
  inherited Create(AProcess);
  FProcess.FWatchPointList.Add(Self);
  FLocation := ALocation;
  FSize := ASize;
  FReadWrite := AReadWrite;
  FScope := AScope;

  MaxWatchSize := MAX_WATCH_SIZE;
//   Wach at 13FFC20:4 TO First 13FFC18:8 Other 0 (0) Last 0

  FFirstWatchSize := MaxWatchSize;
  BoundaryOffset := Integer(FLocation and SIZE_TO_BOUNDMASK[FFirstWatchSize]);
  // As long as the full first half of the watch is unused, use the next smaller watch-size
  HalfSize := FFirstWatchSize div 2;
  while (FFirstWatchSize > 1) and
        ( (BoundaryOffset >= HalfSize) or
          (FSize <= HalfSize)
        )
  do begin
    FFirstWatchSize := HalfSize;
    HalfSize := FFirstWatchSize div 2;
    BoundaryOffset := Integer(FLocation and SIZE_TO_BOUNDMASK[FFirstWatchSize]);
  end;
  FFirstWatchLocation := FLocation - BoundaryOffset;

  FOtherWatchesSize := 0;
  FOtherWatchCount := 0;
  FLastWatchSize := 0;

  S := FSize - FFirstWatchSize + BoundaryOffset; // remainder size
  if S > 0 then begin
    FOtherWatchCount := (S - 1) div MaxWatchSize;
    if FOtherWatchCount > 0 then
      FOtherWatchesSize := MaxWatchSize;

    S := S - FOtherWatchCount * FOtherWatchesSize;
    assert(S >= 0, 'TFpInternalWatchpoint.Create: S >= 0');

    FLastWatchSize := SIZE_TO_WATCHSIZE[S];
  end;
  debugln(DBG_VERBOSE, 'Wach at %x:%d TO First %x:%d Other %d (%d) Last %d',
    [FLocation, FSize, FFirstWatchLocation, FFirstWatchSize, FOtherWatchCount, FOtherWatchesSize, FLastWatchSize]);

  SetBreak;
end;

destructor TFpInternalWatchpoint.Destroy;
begin
  if FProcess <> nil then
    FProcess.FWatchPointList.Remove(Self);
  ResetBreak;
  inherited Destroy;
end;

procedure TFpInternalWatchpoint.SetBreak;
var
  a: TDBGPtr;
  wd: TFpWatchPointData;
  R: Boolean;
  i: Integer;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadId('TFpInternalWatchpoint.SetBreak');{$ENDIF}
  if FProcess = nil then
    exit;
  //TODO: read current mem content. So in case of overlap it can be checked

  wd := FProcess.WatchPointData;

  a := FFirstWatchLocation;
  R := wd.AddOwnedWatchpoint(Self, a, FFirstWatchSize, FReadWrite);
  if not R then begin
    ResetBreak;
    exit;
  end;

  a := a + FFirstWatchSize;
  for i := 0 to FOtherWatchCount - 1 do begin
    R := wd.AddOwnedWatchpoint(Self, a, FOtherWatchesSize, FReadWrite);
    if not R then begin
      ResetBreak;
      exit;
    end;
    a := a + FOtherWatchesSize;
  end;

  if FLastWatchSize > 0 then
    R := wd.AddOwnedWatchpoint(Self, a, FLastWatchSize, FReadWrite);
  if not R then
    ResetBreak;
end;

procedure TFpInternalWatchpoint.ResetBreak;
begin
  {$IFDEF FPDEBUG_THREAD_CHECK}AssertFpDebugThreadId('TFpInternalWatchpoint.ResetBreak');{$ENDIF}
  if FProcess = nil then
    exit;

  FProcess.WatchPointData.RemoveOwnedWatchpoint(Self);
end;

initialization
  DBG_VERBOSE := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
  DBG_BREAKPOINTS := DebugLogger.FindOrRegisterLogGroup('DBG_BREAKPOINTS' {$IFDEF DBG_BREAKPOINTS} , True {$ENDIF} );
  FPDBG_COMMANDS := DebugLogger.FindOrRegisterLogGroup('FPDBG_COMMANDS' {$IFDEF FPDBG_COMMANDS} , True {$ENDIF} );

finalization
  if assigned(RegisteredDbgProcessClasses) then
    FreeAndNil(RegisteredDbgProcessClasses);

end.

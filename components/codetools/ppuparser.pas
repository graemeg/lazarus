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
    Functions and classes to read ppu streams (Free Pascal compiled units)
    of various versions. For example reading 2.3.1 ppus compiled for 64bit
    with a lazarus compiled with fpc 2.2.2 i386.
}
unit PPUParser;

{$mode objfpc}{$H+}

{off $DEFINE VerbosePPUParser}

interface

uses
  Classes, SysUtils, contnrs,
  FileProcs,
  LazFileUtils, LazUTF8;

const
  PPUIsEndianBig = {$IFDEF ENDIAN_BIG}True{$ELSE}False{$ENDIF};

// from ppu.pas
const
{ppu entries}
  mainentryid         = 1;
  subentryid          = 2;
  {special}
  iberror             = 0;
  ibstartdefs         = 248;
  ibenddefs           = 249;
  ibstartsyms         = 250;
  ibendsyms           = 251;
  ibendinterface      = 252;
  ibendimplementation = 253;
  ibendbrowser        = 254;
  ibend               = 255;
  {general}
  ibmodulename           = 1;
  ibsourcefiles          = 2;
  ibloadunit             = 3;
  ibinitunit             = 4;
  iblinkunitofiles       = 5;
  iblinkunitstaticlibs   = 6;
  iblinkunitsharedlibs   = 7;
  iblinkotherofiles      = 8;
  iblinkotherstaticlibs  = 9;
  iblinkothersharedlibs  = 10;
  ibImportSymbols        = 11;
  ibsymref               = 12;
  ibdefref               = 13;
  ibendsymtablebrowser   = 14;
  ibbeginsymtablebrowser = 15;
  ibusedmacros           = 16;
  ibderefdata            = 17;
  ibexportedmacros       = 18;
  ibderefmap             = 19;
  {syms}
  ibtypesym        = 20;
  ibprocsym        = 21;
  ibstaticvarsym   = 22;
  ibconstsym       = 23;
  ibenumsym        = 24;
  ibtypedconstsym  = 25;
  ibabsolutevarsym = 26;
  ibpropertysym    = 27;
  ibfieldvarsym    = 28;
  ibunitsym        = 29;
  iblabelsym       = 30;
  ibsyssym         = 31;
  ibrttisym        = 32;
  iblocalvarsym    = 33;
  ibparavarsym     = 34;
  ibmacrosym       = 35;
  {definitions}
  iborddef         = 40;
  ibpointerdef     = 41;
  ibarraydef       = 42;
  ibprocdef        = 43;
  ibshortstringdef = 44;
  ibrecorddef      = 45;
  ibfiledef        = 46;
  ibformaldef      = 47;
  ibobjectdef      = 48;
  ibenumdef        = 49;
  ibsetdef         = 50;
  ibprocvardef     = 51;
  ibfloatdef       = 52;
  ibclassrefdef    = 53;
  iblongstringdef  = 54;
  ibansistringdef  = 55;
  ibwidestringdef  = 56;
  ibvariantdef     = 57;
  ibundefineddef   = 58;
  ibunicodestringdef = 59; // svn rev 9382
  {implementation/ObjData}
  ibnodetree       = 80;
  ibasmsymbols     = 81;
  ibresources      = 82;  // svn rev 7515   ppu version 80
  ibcreatedobjtypes = 83; // svn rev 12341  ppu version 95
  ibwpofile         = 84; // svn rev 12341  ppu version 95
  ibmoduleoptions   = 85; // svn rev 14767  ppu version 114

  ibmainname       = 90;  // svn rev 10406
  ibsymtableoptions = 91; // svn rev 17328  ppu version 128
  ibrecsymtableoptions = 91; // svn rev 18114
  { target-specific things }
  iblinkotherframeworks = 100; // svn rev 8344
  ibjvmnamespace = 101; // svn rec 21069

  { unit flags }
  uf_init                = $000001; { unit has initialization section }
  uf_finalize            = $000002; { unit has finalization section   }
  uf_big_endian          = $000004;
  //uf_has_browser         = $000010;
  uf_in_library          = $000020; { is the file in another file than <ppufile>.* ? }
  uf_smart_linked        = $000040; { the ppu can be smartlinked }
  uf_static_linked       = $000080; { the ppu can be linked static }
  uf_shared_linked       = $000100; { the ppu can be linked shared }
  //uf_local_browser       = $000200;
  uf_no_link             = $000400; { unit has no .o generated, but can still have external linking! }
  uf_has_resourcestrings = $000800; { unit has resource string section }
  uf_little_endian       = $001000;
  uf_release             = $002000; { unit was compiled with -Ur option }
  uf_threadvars          = $004000; { unit has threadvars }
  uf_fpu_emulation       = $008000; { this unit was compiled with fpu emulation on }
  uf_has_stabs_debuginfo = $010000; { this unit has stabs debuginfo generated }
  uf_local_symtable      = $020000; { this unit has a local symtable stored }
  uf_uses_variants       = $040000; { this unit uses variants }
  uf_has_resourcefiles   = $080000; { this unit has external resources (using $R directive)}
  uf_has_exports         = $100000; { this module or a used unit has exports }
  uf_has_dwarf_debuginfo = $200000; { this unit has dwarf debuginfo generated }
  uf_wideinits           = $400000; { this unit has winlike widestring typed constants }
  uf_classinits          = $800000; { this unit has class constructors/destructors }
  uf_resstrinits        = $1000000; { svn rev 18968: this unit has string consts referencing resourcestrings }
  uf_i8086_far_code     = $2000000; { svn rev 25365: this unit uses an i8086 memory model with far code (i.e. medium, large or huge) }
  uf_i8086_far_data     = $4000000; { svn rev 25365: this unit uses an i8086 memory model with far data (i.e. compact or large) }
  uf_i8086_huge_data    = $8000000; { svn rev 25365: this unit uses an i8086 memory model with huge data (i.e. huge) }
  uf_i8086_cs_equals_ds = $10000000; { svn rev 27516: this unit uses an i8086 memory model with CS=DS (i.e. tiny) }

// from systems.inc
type
   tsystemcpu=
    (
          cpu_no,                       { 0 }
          cpu_i386,                     { 1 }
          cpu_m68k,                     { 2 }
          obsolete_cpu_alpha,           { 3 }
          cpu_powerpc,                  { 4 }
          cpu_sparc,                    { 5 }
          obsolete_cpu_vm,              { 6 }
          obsolete_cpu_ia64,            { 7 }
          cpu_x86_64,                   { 8 }
          cpu_mipseb,                   { 9 }
          cpu_arm,                      { 10 }
          cpu_powerpc64,                { 11 }
          cpu_avr,                      { 12 }
          cpu_mipsel,                   { 13 }
          cpu_jvm,                      { 14 }
          cpu_i8086,                    { 15 }
          cpu_aarch64,                  { 16 }
          cpu_wasm32,                   { 17 }
          cpu_sparc64,                  { 18 }
          cpu_riscv32,                  { 19 }
          cpu_riscv64,                  { 20 }
          cpu_xtensa,                   { 21 }
          cpu_z80                       { 22 }
    );

const
  PPU_CPUNames : array[tsystemcpu] of string[9]=
    ('none',
     'i386',
     'm68k',
     'alpha',
     'powerpc',
     'sparc',
     'vis',
     'ia64',
     'x86_64',
     'mips',
     'arm',
     'powerpc64',
     'avr',
     'mipsel',
     'jvm',
     'i8086',
     'aarch64',
     'wasm32',
     'sparc64',
     'riscv32',
     'riscv64',
     'xtensa',
     'z80'
     );

// from ppu.pas
  { We need to use the correct size of aint and pint for the target CPU }
const
  CpuAddrBitSize : array[tsystemcpu] of longint =
    (
    {  0 } 32 {'none'},
    {  1 } 32 {'i386'},
    {  2 } 32 {'m68k'},
    {  3 } 32 {'alpha'},
    {  4 } 32 {'powerpc'},
    {  5 } 32 {'sparc'},
    {  6 } 32 {'vis'},
    {  7 } 64 {'ia64'},
    {  8 } 64 {'x86_64'},
    {  9 } 32 {'mipseb'},
    { 10 } 32 {'arm'},
    { 11 } 64 {'powerpc64'},
    { 12 } 16 {'avr'},
    { 13 } 32 {'mipsel'},
    { 14 } 32 {'jvm'},
    { 15 } 16 {'i8086'},
    { 16 } 64 {'aarch64'},
    { 17 } 32 {'wasm32},
    { 18 } 64 {'sparc64},
    { 19 } 32 {'riscv32'},
    { 20 } 64 {'riscv64'},
    { 21 } 32 {'xtensa'},
    { 22 } 16 {'z80'}
    );
  CpuAluBitSize : array[tsystemcpu] of longint =
    (
    {  0 } 32 {'none'},
    {  1 } 32 {'i386'},
    {  2 } 32 {'m68k'},
    {  3 } 32 {'alpha'},
    {  4 } 32 {'powerpc'},
    {  5 } 32 {'sparc'},
    {  6 } 32 {'vis'},
    {  7 } 64 {'ia64'},
    {  8 } 64 {'x86_64'},
    {  9 } 32 {'mipseb'},
    { 10 } 32 {'arm'},
    { 11 } 64 {'powerpc64'},
    { 12 }  8 {'avr'},
    { 13 } 32 {'mipsel'},
    { 14 } 64 {'jvm'},
    { 15 } 16 {'i8086'},
    { 16 } 64 {'aarch64'},
    { 17 } 64 {'wasm32'},
    { 18 } 64 {'sparc64'},
    { 19 } 32 {'riscv32'},
    { 20 } 64 {'riscv64'},
    { 21 } 32 {'xtensa'},
    { 22 }  8 {'z80'}
    );

type
  // from globtype.pas
  tproccalloption=(
    pocall_none,
    { procedure uses C styled calling }
    pocall_cdecl,
    { C++ calling conventions }
    pocall_cppdecl,
    { Far16 for OS/2 }
    pocall_far16,
    { Old style FPC default calling }
    pocall_oldfpccall,
    { Procedure has compiler magic}
    pocall_internproc,
    { procedure is a system call, applies e.g. to MorphOS and PalmOS }
    pocall_syscall,
    { pascal standard left to right }
    pocall_pascal,
    { procedure uses register (fastcall) calling }
    pocall_register,
    { safe call calling conventions }
    pocall_safecall,
    { procedure uses stdcall call }
    pocall_stdcall,
    { Special calling convention for cpus without a floating point
      unit. Floating point numbers are passed in integer registers
      instead of floating point registers. Depending on the other
      available calling conventions available for the cpu
      this replaces either pocall_fastcall or pocall_stdcall.
    }
    pocall_softfloat,
    { Metrowerks Pascal. Special case on Mac OS (X): passes all }
    { constant records by reference.                            }
    pocall_mwpascal,
    { for x86-64: Microsoft's "vectorcall" ABI }
    pocall_vectorcall
  );
  tproccalloptions = set of tproccalloption;

  // from symconst.pas
  tproctypeoption=(
    potype_none,
    potype_proginit,     { Program initialization }
    potype_unitinit,     { unit initialization }
    potype_unitfinalize, { unit finalization }
    potype_constructor,  { Procedure is a constructor }
    potype_destructor,   { Procedure is a destructor }
    potype_operator,     { Procedure defines an operator }
    potype_procedure,
    potype_function,
    potype_class_constructor, { class constructor }
    potype_class_destructor   { class destructor  }
  );
  tproctypeoptions = set of tproctypeoption;
  
  tprocoption=(po_none,
    po_classmethod,       { class method }
    po_virtualmethod,     { Procedure is a virtual method }
    po_abstractmethod,    { Procedure is an abstract method }
    po_finalmethod,       { Procedure is a final method }
    po_staticmethod,      { static method }
    po_overridingmethod,  { method with override directive }
    po_methodpointer,     { method pointer, only in procvardef, also used for 'with object do' }
    po_interrupt,         { Procedure is an interrupt handler }
    po_iocheck,           { IO checking should be done after a call to the procedure }
    po_assembler,         { Procedure is written in assembler }
    po_msgstr,            { method for string message handling }
    po_msgint,            { method for int message handling }
    po_exports,           { Procedure has export directive (needed for OS/2) }
    po_external,          { Procedure is external (in other object or lib)}
    po_overload,          { procedure is declared with overload directive }
    po_varargs,           { printf like arguments }
    po_internconst,       { procedure has constant evaluator intern }
    { flag that only the address of a method is returned and not a full methodpointer }
    po_addressonly,
    { procedure is exported }
    po_public,
    { calling convention is specified explicitly }
    po_hascallingconvention,
    { reintroduce flag }
    po_reintroduce,
    { location of parameters is given explicitly as it is necessary for some syscall
      conventions like that one of MorphOS }
    po_explicitparaloc,
    { no stackframe will be generated, used by lowlevel assembler like get_frame }
    po_nostackframe,
    po_has_mangledname,
    po_has_public_name,
    po_forward,
    po_global,
    po_has_inlininginfo, // deleted in PPUVersion 167
    { The different kind of syscalls on MorphOS }
    po_syscall_legacy,
    po_syscall_sysv,
    po_syscall_basesysv,
    po_syscall_sysvbase,
    po_syscall_r12base,
    { Used to record the fact that a symbol is asociated to this syscall }
    po_syscall_has_libsym,
    { Procedure can be inlined }
    po_inline,
    { Procedure is used for internal compiler calls }
    po_compilerproc,
    { importing }
    po_has_importdll,
    po_has_importname,
    po_kylixlocal,
    po_dispid,
    { weakly linked (i.e., may or may not exist at run time) }
    po_weakexternal,
    { Objective-C method }
    po_objc,
    { enumerator support }
    po_enumerator_movenext,
    { optional Objective-C protocol method }
    po_optional,
    { nested procedure that uses Delphi-style calling convention for passing
      the frame pointer (pushed on the stack, always the last parameter,
      removed by the caller). Required for nested procvar compatibility,
      because such procvars can hold both regular and nested procedures
      (when calling a regular procedure using the above convention, it will
       simply not see the frame pointer parameter, and since the caller cleans
       up the stack will also remain balanced) }
    po_delphi_nested_cc,
    { allows the routine's RawByteString var/out parameters to accept parameters
      that do not match exactly (without typeconversion) }
    po_rtlproc,
    { Non-virtual method of a Java class that has been transformed into a
      "virtual; final;" method for JVM-implementation reasons }
    po_java_nonvirtual,
    { automatically inherited routine from parent class, ignore for resolving
      overloads (on the JVM target, constructors are not automatically
      inherited, so we explicitly have to add the constructors of the parent
      class to the child class; this influences the overload resolution logic
      though, so ignore them there) }
    po_ignore_for_overload_resolution,
    { the visibility of of this procdef was raised automatically by the
      compiler, e.g. because it was designated as a getter/setter for a property
      with a higher visibility on the JVM target }
    po_auto_raised_visibility,
    { procedure is far (x86 only) }
    po_far,
    { the procedure never returns, this information is usefull for dfa }
    po_noreturn
  );
  tprocoptions = set of tprocoption;

  { options that should not trigger the recompilation of a unit if they change
    between the interface and the implementation }
  timplprocoption = (
    { the routine contains no code }
    pio_empty,
    { the inline body of this routine is available }
    pio_has_inlininginfo
  );
  timplprocoptions = set of timplprocoption;

const
  proccalloptionNames : array[tproccalloption] of string[14]=('',
     'CDecl',
     'CPPDecl',
     'Far16',
     'OldFPCCall',
     'InternProc',
     'SysCall',
     'Pascal',
     'Register',
     'SafeCall',
     'StdCall',
     'SoftFloat',
     'MWPascal',
     'VectorCall'
   );
  proctypeoptionNames : array[tproctypeoption] of string[20]=(
     'none',
     'ProgInit',
     'UnitInit',
     'UnitFinalize',
     'Constructor',
     'Destructor',
     'Operator',
     'Procedure',
     'Function',
     'Class Constructor',
     'Class Destructor'
  );
  procoptionNames : array[tprocoption] of string[30]=(
    'none',
    'classmethod',       { class method }
    'virtualmethod',     { Procedure is a virtual method }
    'abstractmethod',    { Procedure is an abstract method }
    'finalmethod',       { Procedure is a final method }
    'staticmethod',      { static method }
    'overridingmethod',  { method with override directive }
    'methodpointer',     { method pointer, only in procvardef, also used for 'with object do' }
    'interrupt',         { Procedure is an interrupt handler }
    'iocheck',           { IO checking should be done after a call to the procedure }
    'assembler',         { Procedure is written in assembler }
    'msgstr',            { method for string message handling }
    'msgint',            { method for int message handling }
    'exports',           { Procedure has export directive (needed for OS/2) }
    'external',          { Procedure is external (in other object or lib)}
    'overload',          { procedure is declared with overload directive }
    'varargs',           { printf like arguments }
    'internconst',       { procedure has constant evaluator intern }
    { flag that only the address of a method is returned and not a full methodpointer }
    'addressonly',
    { procedure is exported }
    'public',
    { calling convention is specified explicitly }
    'hascallingconvention',
    { reintroduce flag }
    'reintroduce',
    { location of parameters is given explicitly as it is necessary for some syscall
      conventions like that one of MorphOS }
    'explicitparaloc',
    { no stackframe will be generated', used by lowlevel assembler like get_frame }
    'nostackframe',
    'has_mangledname',
    'has_public_name',
    'forward',
    'global',
    'po_has_inlininginfo',
    { The different kind of syscalls on MorphOS }
    'syscall_legacy',
    'syscall_sysv',
    'syscall_basesysv',
    'syscall_sysvbase',
    'syscall_r12base',
    { Used to record the fact that a symbol is asociated to this syscall }
    'syscall_has_libsym',
    { Procedure can be inlined }
    'inline',
    { Procedure is used for internal compiler calls }
    'compilerproc',
    { importing }
    'has_importdll',
    'has_importname',
    'kylixlocal',
    'dispid',
    { weakly linked (i.e., may or may not exist at run time) }
    'weakexternal',
    { Objective-C method }
    'objc',
    { enumerator support }
    'enumerator_movenext',
    { optional Objective-C protocol method }
    'optional',
    { nested procedure that uses Delphi-style calling convention for passing
      the frame pointer (pushed on the stack, always the last parameter,
      removed by the caller). Required for nested procvar compatibility,
      because such procvars can hold both regular and nested procedures
      (when calling a regular procedure using the above convention, it will
       simply not see the frame pointer parameter, and since the caller cleans
       up the stack will also remain balanced) }
    'delphi_nested_cc',
    { allows the routine's RawByteString var/out parameters to accept parameters
      that do not match exactly (without typeconversion) }
    'rtlproc',
    { Non-virtual method of a Java class that has been transformed into a
      "virtual; final;" method for JVM-implementation reasons }
    'java_nonvirtual',
    { automatically inherited routine from parent class, ignore for resolving
      overloads (on the JVM target, constructors are not automatically
      inherited, so we explicitly have to add the constructors of the parent
      class to the child class; this influences the overload resolution logic
      though, so ignore them there) }
    'ignore_for_overload_resolution',
    { the visibility of of this procdef was raised automatically by the
      compiler, e.g. because it was designated as a getter/setter for a property
      with a higher visibility on the JVM target }
    'auto_raised_visibility',
    { procedure is far (x86 only) }
    'far',
    { the procedure never returns, this information is usefull for dfa }
    'noreturn'
  );

type
  tsymoption=(
    sp_none,
    sp_public,
    sp_private,
    sp_published,
    sp_protected,
    sp_static,
    sp_hint_deprecated,
    sp_hint_platform,
    sp_hint_library,
    sp_hint_unimplemented,
    sp_has_overloaded,
    sp_internal  { internal symbol, not reported as unused }
  );
  tsymoptions=set of tsymoption;
const
  symoptionNames : array[tsymoption] of string[20]=(
     '?',
     'Public',
     'Private',
     'Published',
     'Protected',
     'Static',
     'Hint Deprecated',
     'Hint Platform',
     'Hint Library',
     'Hint Unimplemented',
     'Has overloaded',
     'Internal'
  );

type
  { flags for a definition }
  tdefoption=(
    df_none,
    { type is unique, i.e. declared with type = type <tdef>; }
    df_unique,
    { type is a generic }
    df_generic,
    { type is a specialization of a generic type }
    df_specialization,
    df_genconstraint
  );
  tdefoptions=set of tdefoption;

  tdefstate=(
    ds_none,
    ds_vmt_written,
    ds_rtti_table_used,
    ds_init_table_used,
    ds_rtti_table_written,
    ds_init_table_written,
    ds_dwarf_dbg_info_used,
    ds_dwarf_dbg_info_written
  );
  tdefstates=set of tdefstate;

  { flags for generic type constraints }
  tgenericconstraintflag=(gcf_none,
    gcf_constructor,       { specialization type needs to have a constructor }
    gcf_class,             { specialization type needs to be a class }
    gcf_record             { specialization type needs to be a record type }
  );
  tgenericconstraintflags=set of tgenericconstraintflag;

const
  defoptionNames : array[tdefoption] of string=(
     '?',
     'Unique Type',
     'Generic',
     'Specialization',
     'Generic Constraint'
  );
  defstateNames : array[tdefstate] of string=(
     '?',
     'VMT Written',
     'RTTITable Used',
     'InitTable Used',
     'RTTITable Written',
     'InitTable Written',
     'Dwarf DbgInfo Used',
     'Dwarf DbgInfo Written'
  );

type
  TPPUPart = (
    ppInterfaceHeader,
    ppInterfaceDefinitions,
    ppInterfaceSymbols,
    ppInterfaceMacros,
    ppImplementationHeader,
    ppImplementationDefinitions,
    ppImplementationSymbols
  );
  TPPUParts = set of TPPUPart;
  
const
  PPUPartsAll = [low(TPPUPart)..high(TPPUPart)];

const
  PPU_ID = 'PPU';
  PPU_ID_Size = 3;
  PPU_Ver_Size = 3;

type
  TPPUHeader = packed record
    id       : array[1..PPU_ID_Size] of char; { = 'PPU' }
    ver      : array[1..PPU_Ver_Size] of char;
    compiler : word;
    cpu      : word;
    target   : word;
    flags    : longint;
    size     : longint; { size of the ppufile without header }
    checksum : cardinal; { checksum for this ppufile }
    interface_checksum : cardinal;
    deflistsize,
    symlistsize : longint;
    indirect_checksum: cardinal; // svn rev 14503
  end;

  TPPUEntry = packed record
    size : longint; // number of bytes following directly behind the entry
    id   : byte;
    nr   : byte;
  end;
  PPPUEntry = ^TPPUEntry;

  TPPU = class;
  
  { EPPUParserError }

  EPPUParserError = class(Exception)
    Sender: TPPU;
    constructor Create(ASender: TPPU; const AMessage: string);
  end;

  TPPULinkedFile = class
  public
    ID: byte; // see iblinkunitofiles, iblink...
    Filename: string;
    Flags: Longint;
  end;

  { TPPU }

  TPPU = class
  private
    FSizeOfAInt: integer;
    FSizeOfASizeInt: integer;
    fChangeEndian: boolean;
    FHeader: TPPUHeader;
    FEntry: TPPUEntry;
    FEntryStart: integer;
    FEntryPos: integer;
    FEntryBuf: Pointer;
    FEntryBufSize: integer;
    FOwner: TObject;
    FVersion: integer;
    FDerefData: PByte;
    FDerefDataSize: integer;
    FData: Pointer;
    FDataPos: integer;
    FDataSize: integer;
    FInterfaceHeaderPos: integer; // start of the interface header entries
    FImplementationHeaderPos: integer; // start of the implementation header entries
    FMainUsesSectionPos: integer;// start of the ibloadunit entry
    FImplementationUsesSectionPos: integer;// start of the ibloadunit entry
    FInitProcPos: integer;// start of the ibprocdef entry
    FFinalProcPos: integer;// start of the ibprocdef entry
    procedure ReadPPU(const Parts: TPPUParts);
    procedure ReadHeader;
    procedure ReadInterfaceHeader;
    procedure ReadImplementationHeader;
    function ReadEntry: byte;
    function EndOfEntry: boolean;
    procedure SkipUntilEntry(EntryNr: byte);
    procedure ReadDataFromStream(s: TStream);
    procedure ReadData(var Buf; Count: longint);
    function ReadEntryByte: byte;
    function ReadEntryByte(const Msg: string): byte;
    function ReadEntryShortstring: shortstring;
    function ReadEntryShortstring(const Msg: string): shortstring;
    function ReadEntryAnsistring: ansistring;
    function ReadEntryAnsistring(const Msg: string): ansistring;
    function ReadEntryLongint: longint;
    function ReadEntryLongint(const Msg: string): longint;
    function ReadEntryDWord: cardinal;
    function ReadEntryDWord(const Msg: string): cardinal;
    function ReadEntryWord: word;
    function ReadEntryWord(const Msg: string): word;
    function ReadEntryInt64: int64;
    function ReadEntryInt64(const Msg: string): int64;
    function ReadEntryQWord: QWord;
    function ReadEntryQWord(const Msg: string): QWord;
    function ReadEntryAInt: int64;
    function ReadEntryAInt(const Msg: string): int64;
    function ReadEntryASizeInt: int64;
    function ReadEntryASizeInt(const Msg: string): int64;
    procedure ReadEntrySmallSet(out s);
    procedure ReadEntryNormalSet(out s);
    procedure ReadUsedUnits;
    procedure ReadModuleOptions;
    procedure ReadLinkContainer(aContainerType: byte);
    procedure ReadResources;
    procedure ReadImportSymbols;
    procedure ReadDerefData;
    procedure ReadDerefMap;
    procedure ReadDereference;
    procedure ReadPosInfo;
    procedure ReadSymTableOptions;
    procedure ReadDefinitions;
    procedure ReadProcImplOptions(out ImplProcOptions: timplprocoptions);
    procedure ReadSymbols;
    procedure ReadNodeTree;
    procedure ReadCommonDefinition;
    procedure ReadAbstractProcDef(out proccalloption: tproccalloption;
                                  out procoptions: tprocoptions;
                                  out proctypeoption: tproctypeoption);
    procedure ReadSymOptions;
    procedure Skip(Count: integer);
    procedure Error(const Msg: string);
    
    procedure GetUsesSection(StartPos: integer; var List: TStrings);
    procedure SetDataPos(NewPos: integer);
    function GetProcMangledName(ProcDefPos: integer): string;
  public
    constructor Create(TheOwner: TObject);
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromStream(s: TStream; const Parts: TPPUParts = PPUPartsAll);
    procedure LoadFromFile(const Filename: string; const Parts: TPPUParts = PPUPartsAll);
    procedure Dump(const Prefix: string = '');
    procedure DumpHeader(const Prefix: string = '');
    procedure GetMainUsesSectionNames(var List: TStrings);
    procedure GetImplementationUsesSectionNames(var List: TStrings);
    procedure GetLinkedFiles(var ListOfTPPULinkedFile: TObjectList);
    function GetInitProcName: string;
    function GetFinalProcName: string;
    property Version: integer read FVersion;
    property Owner: TObject read FOwner;
  end;

function PPUTargetToStr(w: longint): string;
function PPUCpuToStr(w: longint): string;
function PPUFlagsToStr(flags: longint): string;
function PPUTimeToStr(t: longint): string;

function PPULinkContainerFlagToStr(Flags: longint): string;

function PPUEntryName(Entry: byte): string;

function ComparePPULinkedFiles(Item1, Item2: Pointer): integer;

implementation

function reverse_byte(b: byte): byte;
const
  reverse_nible: array[0..15] of 0..15 =
    (%0000,%1000,%0100,%1100,%0010,%1010,%0110,%1110,
     %0001,%1001,%0101,%1101,%0011,%1011,%0111,%1111);
begin
  Result:=(reverse_nible[b and $f] shl 4) or reverse_nible[b shr 4];
end;

function PPUTargetToStr(w: longint): string;
type
       { taken from systems.pas }
       ttarget =
       (
        system_none,               { 0 }
        obsolete_system_i386_GO32V1,{ 1 }
        system_i386_GO32V2,        { 2 }
        system_i386_linux,         { 3 }
        system_i386_OS2,           { 4 }
        system_i386_Win32,         { 5 }
        system_i386_freebsd,       { 6 }
        system_m68k_Amiga,         { 7 }
        system_m68k_Atari,         { 8 }
        system_m68k_Mac,           { 9 }
        system_m68k_linux,         { 10 }
        system_m68k_PalmOS,        { 11 }
        system_alpha_linux,        { 12 }
        system_powerpc_linux,      { 13 }
        system_powerpc_macos,      { 14 }
        system_i386_solaris,       { 15 }
        system_i386_beos,          { 16 }
        system_i386_netbsd,        { 17 }
        system_m68k_netbsd,        { 18 }
        system_i386_Netware,       { 19 }
        system_i386_qnx,           { 20 }
        system_i386_wdosx,         { 21 }
        system_sparc_solaris,      { 22 }
        system_sparc_linux,        { 23 }
        system_i386_openbsd,       { 24 }
        system_m68k_openbsd,       { 25 }
        system_x86_64_linux,       { 26 }
        system_powerpc_darwin,     { 27 }
        system_i386_emx,           { 28 }
        system_powerpc_netbsd,     { 29 }
        system_powerpc_openbsd,    { 30 }
        system_arm_linux,          { 31 }
        system_i386_watcom,        { 32 }
        system_powerpc_MorphOS,    { 33 }
        system_x86_64_freebsd,     { 34 }
        system_i386_netwlibc,      { 35 }
        system_powerpc_Amiga,      { 36 }
        system_x86_64_win64,       { 37 }
        system_arm_wince,          { 38 }
        system_ia64_win64,         { 39 }
        system_i386_wince,         { 40 }
        system_x86_6432_linux,     { 41 }
        system_arm_gba,            { 42 }
        system_powerpc64_linux,    { 43 }
        system_i386_darwin,        { 44 }
        system_arm_palmos,         { 45 }
        system_powerpc64_darwin,   { 46 }
        system_arm_nds,            { 47 }
        system_i386_embedded,      { 48 }
        system_m68k_embedded,      { 49 }
        system_alpha_embedded,     { 50 }
        system_powerpc_embedded,   { 51 }
        system_sparc_embedded,     { 52 }
        system_vm_embedded,        { 53 }
        system_iA64_embedded,      { 54 }
        system_x86_64_embedded,    { 55 }
        system_mips_embedded,      { 56 }
        system_arm_embedded,       { 57 }
        system_powerpc64_embedded, { 58 }
        system_i386_symbian,       { 59 }
        system_arm_symbian,        { 60 }
        system_x86_64_darwin,      { 61 }
        system_avr_embedded,       { 62 }
        system_i386_haiku,         { 63 }
        system_arm_ios,            { 64 }
        system_x86_64_solaris,     { 65 }
        system_mips_linux,         { 66 }
        system_mipsel_linux,       { 67 }
        system_i386_nativent,      { 68 }
        system_i386_iphonesim,     { 69 }
        system_powerpc_wii,        { 70 }
        system_x86_64_openbsd,     { 71 }
        system_x86_64_netbsd,      { 72 }
        system_powerpc_aix,        { 73 }
        system_powerpc64_aix,      { 74 }
        system_jvm_java32,         { 75 }
        system_jvm_android32,      { 76 }
        system_arm_android,        { 77 }
        system_i386_android,       { 78 }
        system_i8086_msdos,        { 79 }
        system_mipsel_android,     { 80 }
        system_mipseb_embedded,    { 81 }
        system_mipsel_embedded,    { 82 }
        system_i386_aros,          { 83 }
        system_x86_64_aros,        { 84 }
        system_x86_64_dragonfly,   { 85 }
        system_aarch64_ios,        { 86 }
        system_x86_64_iphonesim,   { 87 }
        system_aarch64_win64,      { 107 }
        system_aarch64_darwin      { 111 }
      );
const
  // taken form ppudump.pp
  Targets : array[ttarget] of string[18]=(
  { 0 }   'none',
  { 1 }   'GO32V1 (obsolete)',
  { 2 }   'GO32V2',
  { 3 }   'Linux-i386',
  { 4 }   'OS/2',
  { 5 }   'Win32',
  { 6 }   'FreeBSD-i386',
  { 7 }   'Amiga',
  { 8 }   'Atari',
  { 9 }   'MacOS-m68k',
  { 10 }  'Linux-m68k',
  { 11 }  'PalmOS-m68k',
  { 12 }  'Linux-alpha',
  { 13 }  'Linux-ppc',
  { 14 }  'MacOS-ppc',
  { 15 }  'Solaris-i386',
  { 16 }  'BeOS-i386',
  { 17 }  'NetBSD-i386',
  { 18 }  'NetBSD-m68k',
  { 19 }  'Netware-i386-clib',
  { 20 }  'Qnx-i386',
  { 21 }  'WDOSX-i386',
  { 22 }  'Solaris-sparc',
  { 23 }  'Linux-sparc',
  { 24 }  'OpenBSD-i386',
  { 25 }  'OpenBSD-m68k',
  { 26 }  'Linux-x86-64',
  { 27 }  'MacOSX-ppc',
  { 28 }  'OS/2 via EMX',
  { 29 }  'NetBSD-powerpc',
  { 30 }  'OpenBSD-powerpc',
  { 31 }  'Linux-arm',
  { 32 }  'Watcom-i386',
  { 33 }  'MorphOS-powerpc',
  { 34 }  'FreeBSD-x86-64',
  { 35 }  'Netware-i386-libc',
  { 36 }  'Amiga-PowerPC',
  { 37 }  'Win64-x64',
  { 38 }  'WinCE-ARM',
  { 39 }  'Win64-iA64',
  { 40 }  'WinCE-i386',
  { 41 }  'Linux-x64',
  { 42 }  'GBA-arm',
  { 43 }  'Linux-powerpc64',
  { 44 }  'Darwin-i386',
  { 45 }  'PalmOS-arm',
  { 46 }  'MacOSX-powerpc64',
  { 47 }  'NDS-arm',
  { 48 }  'Embedded-i386',
  { 49 }  'Embedded-m68k',
  { 50 }  'Embedded-alpha',
  { 51 }  'Embedded-powerpc',
  { 52 }  'Embedded-sparc',
  { 53 }  'Embedded-vm',
  { 54 }  'Embedded-iA64',
  { 55 }  'Embedded-x64',
  { 56 }  'Embedded-mips',
  { 57 }  'Embedded-arm',
  { 58 }  'Embedded-powerpc64',
  { 59 }  'Symbian-i386',
  { 60 }  'Symbian-arm',
  { 61 }  'MacOSX-x64',
  { 62 }  'Embedded-avr',
  { 63 }  'Haiku-i386',
  { 64 }  'iOS-ARM',
  { 65 }  'Solaris-x86-64',
  { 66 }  'Linux-MIPS',
  { 67 }  'Linux-MIPSel',
  { 68 }  'NativeNT-i386',
  { 69 }  'iPhoneSim-i386',
  { 70 }  'Wii-powerpc',
  { 71 }  'OpenBSD-x86-64',
  { 72 }  'NetBSD-x86-64',
  { 73 }  'AIX-powerpc',
  { 74 }  'AIX-powerpc64',
  { 75 }  'Java-JVM',
  { 76 }  'Android-JVM',
  { 77 }  'Android-arm',
  { 78 }  'Android-i386',
  { 79 }  'MSDOS-i8086',
  { 80 }  'Android-MIPSel',
  { 81 }  'Embedded-mipseb',
  { 82 }  'Embedded-mipsel',
  { 83 }  'AROS-i386',
  { 84 }  'AROS-x86-64',
  { 85 }  'DragonFly-x86-64',
  { 86 }  'iOS-AArch64',
  { 87 }  'iPhoneSim-x86-64',
  { 107 }  'Win64-AArch64',
  { 111 }  'Darwin-AArch64'
  );
begin
  if w<=ord(high(ttarget)) then
    Result:=Targets[ttarget(w)]
  else
    Result:='<!! Unknown target value '+IntToStr(w)+'>';
end;

function PPUCpuToStr(w:longint):string;
begin
  if w<=ord(high(tsystemcpu)) then
    Result:=PPU_CPUNames[tsystemcpu(w)]
  else
    Result:='<!! Unknown cpu value '+IntToStr(w)+'>';
end;

function PPUFlagsToStr(flags:longint):string;
type
  tflagopt=record
    mask : longint;
    str  : string[30];
  end;
const
  flagopts=17;
  flagopt : array[1..flagopts] of tflagopt=(
    (mask: $1    ;str:'init'),
    (mask: $2    ;str:'final'),
    (mask: $4    ;str:'big_endian'),
    (mask: $8    ;str:'dbx'),
//    (mask: $10   ;str:'browser'),
    (mask: $20   ;str:'in_library'),
    (mask: $40   ;str:'smart_linked'),
    (mask: $80   ;str:'static_linked'),
    (mask: $100  ;str:'shared_linked'),
//    (mask: $200  ;str:'local_browser'),
    (mask: $400  ;str:'no_link'),
    (mask: $800  ;str:'has_resources'),
    (mask: $1000  ;str:'little_endian'),
    (mask: $2000  ;str:'release'),
    (mask: $4000  ;str:'local_threadvars'),
    (mask: $8000  ;str:'fpu_emulation_on'),
    (mask: $10000  ;str:'has_debug_info'),
    (mask: $20000  ;str:'local_symtable'),
    (mask: $40000  ;str:'uses_variants')
  );
var
  i : longint;
  first  : boolean;
  s : string;
begin
  s:='';
  if flags<>0 then
   begin
     first:=true;
     for i:=1to flagopts do
      if (flags and flagopt[i].mask)<>0 then
       begin
         if first then
           first:=false
         else
           s:=s+', ';
         s:=s+flagopt[i].str;
       end;
   end
  else
   s:='none';
  Result:=s;
end;

function L0(l: longint): shortstring;
{
  return the string of value l, if l<10 then insert a zero, so
  the string is always at least 2 chars '01','02',etc
}
var
  s : shortstring;
begin
  Str(l,s);
  if l<10 then
    s:='0'+s;
  Result:=s;
end;

function PPUTimeToStr(t: longint): string;
{
  convert dos datetime t to a string YY/MM/DD HH:MM:SS
}
var
  DT: TDateTime;
  hsec: word;
  Year, Month, Day: Word;
  hour, min, sec: word;
begin
  if t=-1 then
  begin
    Result := '<invalid time>';
    exit;
  end;
  DT := FileDateToDateTimeDef(t);
  DecodeTime(DT,hour,min,sec,hsec);
  DecodeDate(DT,year,month,day);
  Result := L0(Year)+'/'+L0(Month)+'/'+L0(Day)+' '+L0(Hour)+':'+L0(min)+':'+L0(sec);
end;

function PPULinkContainerFlagToStr(Flags: longint): string;
const
  { link options }
  //link_none    = $0;
  link_always  = $1;
  link_static  = $2;
  link_smart   = $4;
  link_shared  = $8;
begin
  Result:='';
  if (Flags and link_always)<>0 then
    Result:=Result+'always,';
  if (Flags and link_static)<>0 then
    Result:=Result+'static,';
  if (Flags and link_smart)<>0 then
    Result:=Result+'smart,';
  if (Flags and link_shared)<>0 then
    Result:=Result+'shared,';
  if Result<>'' then Result:=copy(Result,1,length(Result)-1);
end;

function PPUEntryName(Entry: byte): string;
begin
  case Entry of
  iberror:             Result:='iberror';
  ibstartdefs:         Result:='ibstartdefs';
  ibenddefs:           Result:='ibenddefs';
  ibstartsyms:         Result:='ibstartsyms';
  ibendsyms:           Result:='ibendsyms';
  ibendinterface:      Result:='ibendinterface';
  ibendimplementation: Result:='ibendimplementation';
  ibendbrowser:        Result:='ibendbrowser';
  ibend:               Result:='ibend';
  {general}
  ibmodulename:           Result:='ibmodulename';
  ibsourcefiles:          Result:='ibsourcefiles';
  ibloadunit:             Result:='ibloadunit';
  ibinitunit:             Result:='ibinitunit';
  iblinkunitofiles:       Result:='iblinkunitofiles';
  iblinkunitstaticlibs:   Result:='iblinkunitstaticlibs';
  iblinkunitsharedlibs:   Result:='iblinkunitsharedlibs';
  iblinkotherofiles:      Result:='iblinkotherofiles';
  iblinkotherstaticlibs:  Result:='iblinkotherstaticlibs';
  iblinkothersharedlibs:  Result:='iblinkothersharedlibs';
  ibImportSymbols:        Result:='ibImportSymbols';
  ibsymref:               Result:='ibsymref';
  ibdefref:               Result:='ibdefref';
  ibendsymtablebrowser:   Result:='ibendsymtablebrowser';
  ibbeginsymtablebrowser: Result:='ibbeginsymtablebrowser';
  ibusedmacros:           Result:='ibusedmacros';
  ibderefdata:            Result:='ibderefdata';
  ibexportedmacros:       Result:='ibexportedmacros';
  ibderefmap:             Result:='ibderefmap';
  {syms}
  ibtypesym:        Result:='ibtypesym';
  ibprocsym:        Result:='ibprocsym';
  ibstaticvarsym:   Result:='ibstaticvarsym';
  ibconstsym:       Result:='ibconstsym';
  ibenumsym:        Result:='ibenumsym';
  ibtypedconstsym:  Result:='ibtypedconstsym';
  ibabsolutevarsym: Result:='ibabsolutevarsym';
  ibpropertysym:    Result:='ibpropertysym';
  ibfieldvarsym:    Result:='ibfieldvarsym';
  ibunitsym:        Result:='ibunitsym';
  iblabelsym:       Result:='iblabelsym';
  ibsyssym:         Result:='ibsyssym';
  ibrttisym:        Result:='ibrttisym';
  iblocalvarsym:    Result:='iblocalvarsym';
  ibparavarsym:     Result:='ibparavarsym';
  ibmacrosym:       Result:='ibmacrosym';
  {definitions}
  iborddef:         Result:='iborddef';
  ibpointerdef:     Result:='ibpointerdef';
  ibarraydef:       Result:='ibarraydef';
  ibprocdef:        Result:='ibprocdef';
  ibshortstringdef: Result:='ibshortstringdef';
  ibrecorddef:      Result:='ibrecorddef';
  ibfiledef:        Result:='ibfiledef';
  ibformaldef:      Result:='ibformaldef';
  ibobjectdef:      Result:='ibobjectdef';
  ibenumdef:        Result:='ibenumdef';
  ibsetdef:         Result:='ibsetdef';
  ibprocvardef:     Result:='ibprocvardef';
  ibfloatdef:       Result:='ibfloatdef';
  ibclassrefdef:    Result:='ibclassrefdef';
  iblongstringdef:  Result:='iblongstringdef';
  ibansistringdef:  Result:='ibansistringdef';
  ibwidestringdef:  Result:='ibwidestringdef';
  ibvariantdef:     Result:='ibvariantdef';
  ibundefineddef:   Result:='ibundefineddef';
  ibunicodestringdef: Result:='ibunicodestringdef';
  {implementation/ObjData}
  ibnodetree:       Result:='ibnodetree';
  ibasmsymbols:     Result:='ibasmsymbols';
  ibresources:      Result:='ibresources';
  ibcreatedobjtypes:Result:='ibcreatedobjtypes';
  ibwpofile:        Result:='ibwpofile';
  ibmoduleoptions:  Result:='ibmoduleoptions';

  ibmainname:       Result:='ibmainname';
  ibsymtableoptions:Result:='ibsymtableoptions';
  //ibrecsymtableoptions: duplicate with ibsymtableoptions
  { target-specific things }
  iblinkotherframeworks: Result:='iblinkotherframeworks';
  ibjvmnamespace:   Result:='ibjvmnamespace';
  else Result:='unknown('+IntToStr(Entry)+')';
  end;
end;

function ComparePPULinkedFiles(Item1, Item2: Pointer): integer;
var
  File1: TPPULinkedFile absolute Item1;
  File2: TPPULinkedFile absolute Item2;
begin
  if File1.ID<File2.ID then exit(1)
  else if File1.ID>File2.ID then exit(-1);
  Result:=CompareFilenames(File1.Filename,File2.Filename);
  if Result<>0 then exit;
  if File1.Flags<File2.Flags then exit(1)
  else if File1.Flags>File2.Flags then exit(-1);
  Result:=0;
end;

{ EPPUParserError }

constructor EPPUParserError.Create(ASender: TPPU; const AMessage: string);
begin
  Sender:=ASender;
  inherited Create(AMessage);
end;

{ TPPU }

procedure TPPU.ReadPPU(const Parts: TPPUParts);
begin
  ReadHeader;

  // interface header
  if ppInterfaceHeader in Parts then
    ReadInterfaceHeader
  else
    SkipUntilEntry(ibendinterface);

  if Version>=128 then
    ReadSymTableOptions;

  // interface definitions
  if ppInterfaceDefinitions in Parts then
    ReadDefinitions
  else
    SkipUntilEntry(ibenddefs);

  // Interface Symbols
  SkipUntilEntry(ibendsyms);

  // Interface Macros
  if ReadEntry=ibexportedmacros then begin
    if boolean(ReadEntryByte) then begin
      // skip the definition section for macros (since they are never used)
      SkipUntilEntry(ibenddefs);
      // read the macro symbols
      SkipUntilEntry(ibendsyms);
    end;
  end;

  // Implementation Header
  if ppImplementationHeader in Parts then
    ReadImplementationHeader
  else
    SkipUntilEntry(ibendimplementation);

  // Implementation Definitions and Symbols
  if (FHeader.flags and uf_local_symtable)<>0 then begin
    if Version>=128 then
      ReadSymTableOptions;
    if ppImplementationDefinitions in Parts then
      ReadDefinitions
    else
      SkipUntilEntry(ibenddefs);
    SkipUntilEntry(ibendsyms);
  end else begin
    // no definitions and no symbols
  end;
end;

{$R-}
procedure TPPU.ReadHeader;
var
  cpu: tsystemcpu;
begin
  fChangeEndian:=PPUIsEndianBig;
  // read ID
  ReadData(FHeader.id,PPU_ID_Size);
  if String(FHeader.id)<>PPU_ID then
    Error('This is not a PPU. Wrong ID.');
  // read Version
  ReadData(FHeader.ver,PPU_Ver_Size);
  FVersion:=StrToIntDef(String(FHeader.ver),0);
  if FVersion<16 then
    Error('Old PPU versions (<16) are not supported.');
  // read rest of header
  ReadData(FHeader.compiler,SizeOf(TPPUHeader)-PPU_Ver_Size-PPU_ID_Size);
  if fChangeEndian then begin
    fHeader.compiler := swapendian(fHeader.compiler);
    fHeader.cpu := swapendian(fHeader.cpu);
    fHeader.target := swapendian(fHeader.target);
    fHeader.flags := swapendian(fHeader.flags);
    fHeader.size := swapendian(fHeader.size);
    fHeader.checksum := swapendian(fHeader.checksum);
    fHeader.interface_checksum := swapendian(fHeader.interface_checksum);
    fHeader.deflistsize := swapendian(fHeader.deflistsize);
    fHeader.symlistsize := swapendian(fHeader.symlistsize);
  end;
  fChangeEndian:=((FHeader.flags and uf_big_endian) = uf_big_endian)<>PPUIsEndianBig;

  FEntryPos:=0;
  FillByte(FEntry,SizeOf(FEntry),0);

  cpu:=tsystemcpu(FHeader.cpu);
  if (cpu<low(tsystemcpu)) or (cpu>high(tsystemcpu)) then
    cpu:=tsystemcpu(FHeader.cpu);
  FSizeOfAInt:=CpuAluBitSize[cpu] div 8;
  FSizeOfASizeInt:=CpuAddrBitSize[cpu] div 8;

  {$IFDEF VerbosePPUParser}
  DumpHeader('');
  {$ENDIF}
end;
{$R+}

procedure TPPU.ReadInterfaceHeader;
var
  EntryNr: Byte;
  {$IFDEF VerbosePPUParser}
  ModuleName: ShortString;
  Filename: ShortString;
  FileTime: LongInt;
  Conditional: ShortString;
  DefinedAtStartUp: Boolean;
  IsUsed: Boolean;
  {$ENDIF}
begin
  FInterfaceHeaderPos:=FDataPos;
  repeat
    EntryNr:=ReadEntry;
    {$IFDEF VerbosePPUParser}
    DebugLn(['TPPU.ReadInterface EntryNr=',EntryNr,'=',PPUEntryName(EntryNr)]);
    {$ENDIF}
    case EntryNr of
    
    ibmodulename:
      begin
        {$IFDEF VerbosePPUParser}ModuleName:={$ENDIF}ReadEntryShortstring;
        {$IFDEF VerbosePPUParser}
        DebugLn(['TPPU.ReadInterfaceHeader ModuleName=',ModuleName]);
        {$ENDIF}
      end;

    ibmoduleoptions:
      ReadModuleOptions;
    
    ibsourcefiles:
      begin
        while not EndOfEntry do
        begin
          {$IFDEF VerbosePPUParser}Filename:={$ENDIF}ReadEntryShortstring;// filename
          {$IFDEF VerbosePPUParser}FileTime:={$ENDIF}ReadEntryLongint;// file time
          {$IFDEF VerbosePPUParser}
          DebugLn(['TPPU.ReadInterfaceHeader SourceFile=',Filename,' Time=',PPUTimeToStr(FileTime)]);
          {$ENDIF}
        end;
      end;
      
    ibloadunit:
      begin
        FMainUsesSectionPos:=FEntryStart;
        ReadUsedUnits;
      end;

    iblinkunitofiles,iblinkunitstaticlibs,iblinkunitsharedlibs,
    iblinkotherofiles,iblinkotherstaticlibs,iblinkothersharedlibs,
    iblinkotherframeworks:
      ReadLinkContainer(EntryNr);

    ibresources:
      ReadResources;
      
    ibImportSymbols:
      ReadImportSymbols;

    ibusedmacros:
      begin
        while not EndOfEntry do
        begin
          {$IFDEF VerbosePPUParser}Conditional:={$ENDIF}ReadEntryShortstring;
          {$IFDEF VerbosePPUParser}DefinedAtStartUp:=boolean(ReadEntryByte){$ELSE}ReadEntryByte{$ENDIF};
          {$IFDEF VerbosePPUParser}IsUsed:=boolean(ReadEntryByte){$ELSE}ReadEntryByte{$ENDIF};
          {$IFDEF VerbosePPUParser}
          DebugLn(['TPPU.ReadInterfaceHeader Macro=',Conditional,' DefinedAtStartUp=',DefinedAtStartUp,' Used=',IsUsed]);
          {$ENDIF}
        end;
      end;

    ibderefdata:
      ReadDerefData;

    ibderefmap:
      ReadDerefMap;

    ibendinterface:
      break;
       
    else
      {$IFDEF VerbosePPUParser}
      DebugLn(['TPPU.ReadInterfaceHeader Skipping unsupported entry ',EntryNr]);
      {$ENDIF}
      FEntryPos:=FEntry.size;
    end;
  until false;
end;

procedure TPPU.ReadImplementationHeader;
var
  EntryNr: Byte;
begin
  FImplementationHeaderPos:=FDataPos;
  repeat
    EntryNr:=ReadEntry;
    case EntryNr of

    // ToDo: ibasmsymbols
    
    ibloadunit:
      begin
        FImplementationUsesSectionPos:=FEntryStart;
        ReadUsedUnits;
      end;

    ibendimplementation:
      break;

    else
      {$IFDEF VerbosePPUParser}
      DebugLn(['TPPU.ReadImplementationHeader Skipping unsupported entry ',EntryNr]);
      {$ENDIF}
      FEntryPos:=FEntry.size;
    end;
  until false;
end;

procedure TPPU.ReadDefinitions;
type
  {
  tsettype  = (normset,smallset,varset);

  tordtype = (
    uvoid,
    u8bit,u16bit,u32bit,u64bit,
    s8bit,s16bit,s32bit,s64bit,
    bool8bit,bool16bit,bool32bit,bool64bit,
    uchar,uwidechar,scurrency
  );

  tobjecttyp = (odt_none,
    odt_class,
    odt_object,
    odt_interfacecom,
    odt_interfacecorba,
    odt_cppclass,
    odt_dispinterface
  );

  tvarianttype = (
    vt_normalvariant,vt_olevariant
  );
  }

  tprocinfoflag=(
    {# procedure uses asm }
    pi_uses_asm,
    {# procedure does a call }
    pi_do_call,
    {# procedure has a try statement = no register optimization }
    pi_uses_exceptions,
    {# procedure is declared as @var(assembler), don't optimize}
    pi_is_assembler,
    {# procedure contains data which needs to be finalized }
    pi_needs_implicit_finally
  );
  //tprocinfoflags=set of tprocinfoflag;
var
  EntryNr: Byte;
  calloption: tproccalloption;
  procoptions: tprocoptions;
  procinfooptions : tprocinfoflag;
  proctypeoption: tproctypeoption;
  ImplProcOptions: timplprocoptions;
  CurEntryStart: LongInt;
  HasInliningInfo: Boolean;
begin
  EntryNr:=ReadEntry;
  if EntryNr<>ibstartdefs then
  begin
    Error('expected ibstartdefs, but found '+PPUEntryName(EntryNr));
  end;
  repeat
    EntryNr:=ReadEntry;
    CurEntryStart:=FEntryStart;
    case EntryNr of
    
    ibpointerdef:
      begin
        {$IFDEF VerbosePPUParser} DebugLn(['TPPU.ReadDefinitions Pointer definition:']); {$ENDIF}
        ReadCommonDefinition;
        {$IFDEF VerbosePPUParser} DebugLn(['TPPU.ReadDefinitions Pointed type:']); {$ENDIF}
        ReadDereference;
        ReadEntryByte{$IFDEF VerbosePPUParser}('IsFar='){$ENDIF}; // is Far
      end;
      
    ibprocdef:
      begin
        {$IFDEF VerbosePPUParser} DebugLn(['TPPU.ReadDefinitions Procedure definition:']); {$ENDIF}
        ReadCommonDefinition;
        ReadAbstractProcDef(calloption,procoptions,proctypeoption);
        if proctypeoption in [potype_proginit,potype_unitinit] then
          FInitProcPos:=CurEntryStart;
        if proctypeoption in [potype_unitfinalize] then
          FFinalProcPos:=CurEntryStart;
        if (po_has_mangledname in procoptions) then begin
          ReadEntryShortstring{$IFDEF VerbosePPUParser}('     Mangled name : '){$ENDIF};
        end;
        ReadEntryWord{$IFDEF VerbosePPUParser}('           Number : '){$ENDIF};
        ReadEntryByte{$IFDEF VerbosePPUParser}('            Level : '){$ENDIF};
        {$IFDEF VerbosePPUParser}
        dbgout('            Class : ');
        {$ENDIF}
        ReadDereference;
        {$IFDEF VerbosePPUParser}
        dbgout('          Procsym : ');
        {$ENDIF}
        ReadDereference;
        {$IFDEF VerbosePPUParser}
        dbgout('         File Pos : ');
        {$ENDIF}
        readposinfo;
        {$IFDEF VerbosePPUParser}
        dbgout('       SymOptions : ');
        {$ENDIF}
        ReadSymOptions;
        if tsystemcpu(FHeader.cpu)=cpu_powerpc then begin
          { library symbol for AmigaOS/MorphOS }
          {$IFDEF VerbosePPUParser} dbgout('   Library symbol : '); {$ENDIF}
          ReadDereference;
        end;
        if (po_has_importdll in procoptions) then
          ReadEntryShortstring{$IFDEF VerbosePPUParser}('       Import DLL : '){$ENDIF};
        if (po_has_importname in procoptions) then
          ReadEntryShortstring{$IFDEF VerbosePPUParser}('      Import Name : '){$ENDIF};
        ReadEntryWord{$IFDEF VerbosePPUParser}('        Import Nr : '){$ENDIF};
        if (po_msgint in procoptions) then
          ReadEntryLongint{$IFDEF VerbosePPUParser}('           MsgInt : '){$ENDIF};
        if (po_msgstr in procoptions) then
          ReadEntryShortstring{$IFDEF VerbosePPUParser}('           MsgStr : '){$ENDIF};
        if (po_dispid in procoptions) then
          ReadEntryLongint{$IFDEF VerbosePPUParser}('           DispID : '){$ENDIF};
        if Version>=167 then
          ReadProcImplOptions(ImplProcOptions);

        HasInliningInfo:=
          ((Version<167) and (po_has_inlininginfo in procoptions))
          or ((Version>=167) and (pio_has_inlininginfo in implprocoptions));
        if HasInliningInfo then begin
          {$IFDEF VerbosePPUParser} dbgout('       FuncretSym : '); {$ENDIF}
          ReadDereference;
          ReadEntrySmallSet(procinfooptions);
          {$IFDEF VerbosePPUParser} debugln(['  ProcInfoOptions : ',dword(procinfooptions)]);{$ENDIF}
        end;
        // parast
        if Version>=128 then
          ReadSymTableOptions;
        ReadDefinitions;
        ReadSymbols;
        // localst
        if HasInliningInfo then
        begin
          ReadDefinitions;
          ReadSymbols;
        end;
        if HasInliningInfo then
          readnodetree;
      end;
      
    ibenddefs:
      break;

    else
      {$IFDEF VerbosePPUParser} DebugLn(['TPPU.ReadDefinitions Skipping unsupported: ',EntryNr]); {$ENDIF}
    end;
    {$IFDEF VerbosePPUParser}
    if not EndOfEntry then
      DebugLn(['TPPU.ReadDefinitions: Warning: Entry has more information stored']);
    {$ENDIF}
  until false;
end;

procedure TPPU.ReadProcImplOptions(out ImplProcOptions: timplprocoptions);
begin
  ReadEntrySmallSet(ImplProcOptions);
end;

procedure TPPU.ReadSymbols;
{type
  pguid = ^tguid;
  tguid = packed record
    D1: LongWord;
    D2: Word;
    D3: Word;
    D4: array[0..7] of Byte;
  end;

  absolutetyp = (
    tovar,
    toasm,
    toaddr
    );
  tconsttyp = (
    constnone,
    constord,
    conststring,
    constreal,
    constset,
    constpointer,
    constnil,
    constresourcestring,
    constwstring,
    constguid
    );}
var
  EntryNr: Byte;
begin
  if ReadEntry<>ibstartsyms then
    Error('missing ibstartsyms');
  ReadEntryLongint{$IFDEF VerbosePPUParser}('Symtable datasize : '){$ENDIF};
  if FEntryPos<FEntry.size then
    ReadEntryLongint{$IFDEF VerbosePPUParser}('Symtable alignment: '){$ENDIF};
  repeat
    EntryNr:=ReadEntry;
    case EntryNr of
    
    ibendsyms:
      break;

    else
      {$IFDEF VerbosePPUParser}
      DebugLn(['TPPU.ReadSymbols Skipping unsupported PPU Entry in Symbols: ',EntryNr]);
      {$ENDIF}
    end;
    {$IFDEF VerbosePPUParser}
    if not EndOfEntry then
      DebugLn(['TPPU.ReadSymbols Entry has more information stored: ',EntryNr]);
    {$ENDIF}
  until false;
end;

procedure TPPU.ReadNodeTree;
begin
  if ReadEntry<>ibnodetree then
    Error('TPPU.ReadNodeTree missing ibnodetree');
  FEntryPos:=FEntry.size;
end;

procedure TPPU.ReadCommonDefinition;
var
  defoptions: tdefoptions;
  defstates: tdefstates;
  genconstr: tgenericconstraintflags;
  len: Int64;
  i: Integer;
  {$IFDEF VerbosePPUParser}
  defopt: tdefoption;
  defstate: tdefstate;
  TokenBuf: Pointer;
  TokenBufSize: LongInt;
  {$ENDIF}
begin
  ReadEntryLongint{$IFDEF VerbosePPUParser}('DefinitionID='){$ENDIF};
  ReadDereference;

  ReadEntrySmallSet(defoptions);
  {$IFDEF VerbosePPUParser}
  if defoptions<>[] then begin
    dbgout(' DefOptions:');
    for defopt:=low(tdefoption) to high(tdefoption) do
      if defopt in defoptions then
        dbgout(' ',defoptionNames[defopt]);
    debugln;
  end;
  {$ENDIF}
  
  ReadEntrySmallSet(defstates);
  {$IFDEF VerbosePPUParser}
  if defstates<>[] then begin
    dbgout(' DefStates:');
    for defstate:=low(tdefstate) to high(tdefstate) do
      if defstate in defstates then
        dbgout(' ',defstateNames[defstate]);
    debugln;
  end;
  {$ENDIF}

  if df_genconstraint in defoptions then begin
    // generic constraints
    ReadEntrySmallSet(genconstr);
    len:=ReadEntryASizeInt({$IFDEF VerbosePPUParser}'generic consstraints='{$ENDIF});
    for i:=1 to len do begin
      ReadDereference;
    end;
  end;

  if [df_generic,df_specialization]*defoptions<>[] then begin
    // generic parameters
    len:=ReadEntryLongint;
    for i:=1 to len do begin
      ReadDereference;
    end;
  end;

  if df_generic in defoptions then begin
    {$IFDEF VerbosePPUParser}TokenBufSize:={$ENDIF}ReadEntryLongint;
    {$IFDEF VerbosePPUParser}
    TokenBuf:=allocmem(TokenBufSize);
    try
      System.Move(Pointer(FEntryBuf+FEntryPos)^,TokenBuf^,TokenBufSize);
      inc(FEntryPos,TokenBufSize);
      i:=0;
      while i<TokenBufSize do begin
        // The tokens depends on compiler Version
        // ToDo: write tokens
        inc(i);
      end;
    finally
      FreeMem(TokenBuf);
    end;
    {$ENDIF}
  end;

  if df_specialization in defoptions then
  begin
    ReadDereference;
  end;
end;

procedure TPPU.ReadAbstractProcDef(out proccalloption: tproccalloption;
  out procoptions: tprocoptions; out proctypeoption: tproctypeoption);
var
  i     : longint;
  p: PByte;
  {$IFDEF VerbosePPUParser}
  po: tprocoption;
  {$ENDIF}
begin
  {$IFDEF VerbosePPUParser}
  dbgout('Return type: ');
  {$ENDIF}
  ReadDereference;
  if Version<169 then
    ReadEntryByte{$IFDEF VerbosePPUParser}('FPU='){$ENDIF};
  proctypeoption:=tproctypeoption(ReadEntryByte);
  {$IFDEF VerbosePPUParser}
  debugln('Typeoptions: ',proctypeoptionNames[proctypeoption]);
  {$ENDIF}
  proccalloption:=tproccalloption(ReadEntryByte);
  {$IFDEF VerbosePPUParser}
  debugln('CallOption : ',proccalloptionNames[proccalloption]);
  {$ENDIF}
  ReadEntryNormalSet(procoptions);
  if Version>=167 then begin
    // po_has_inlininginfo was deleted in PPU version 167
    p:=@PByte(@procoptions)[ord(po_has_inlininginfo)];
    System.Move(p[0],p[1],ord(High(procoptions))-ord(po_has_inlininginfo));
    p^:=0;
  end;

  {$IFDEF VerbosePPUParser}
  if procoptions<>[] then begin
    dbgout('Options: ');
    for po:=low(tprocoption) to high(tprocoption) do
      if po in procoptions then
        dbgout(' ',procoptionNames[po]);
    debugln;
  end;
  {$ENDIF}
  if (po_explicitparaloc in procoptions) then
  begin
    i:=ReadEntryByte;
    inc(FEntryPos,i);
  end;
  if po_syscall_has_libsym in procoptions then
    ReadDereference;
end;

procedure TPPU.ReadSymOptions;
var
  symoptions : tsymoptions;
  {$IFDEF VerbosePPUParser}
  s: tsymoption;
  {$ENDIF}
begin
  ReadEntrySmallSet(symoptions);
  {$IFDEF VerbosePPUParser}
  if symoptions<>[] then begin
    for s:=Low(tsymoption) to high(tsymoption) do
      if s in SymOptions then
        dbgout(' ',symoptionNames[s]);
  end;
  debugln;
  {$ENDIF}
end;

procedure TPPU.ReadDereference;
type
  tdereftype = (
    deref_nil,
    deref_unit,
    deref_symid,
    deref_defid
  );
var
  DerefPos: LongInt;
  pdata: PByte;
  n: Byte;
  i: Integer;
  b: tdereftype;
  {$IFDEF VerbosePPUParser}
  idx: integer;
  {$ENDIF}
begin
  DerefPos:=ReadEntryLongint;
  if DerefPos=-1 then begin
    {$IFDEF VerbosePPUParser}
    dbgout(' Nil');
    {$ENDIF}
    exit;
  end;
  if DerefPos>FDerefDataSize then
    Error('Invalid Deref, DerefPos>=FDerefDataSize');
  {$IFDEF VerbosePPUParser}
  dbgout('(',IntToStr(DerefPos),')');
  {$ENDIF}
  pdata:=@FDerefData[DerefPos];
  n:=pdata^;
  if n<1 then
    Error('Invalid Deref, n<1');
  i:=1;
  while i<=n do begin
    b:=tdereftype(pdata[i]);
    inc(i);
    case b of
    deref_nil :
      begin
        {$IFDEF VerbosePPUParser}
        dbgout(' Nil');
        {$ENDIF}
      end;
    deref_symid :
      begin
        {$IFDEF VerbosePPUParser}
        idx:=pdata[i] shl 24 or pdata[i+1] shl 16 or pdata[i+2] shl 8 or pdata[i+3];
        dbgout(' SymId ',IntToStr(idx));
        {$ENDIF}
        inc(i,4);
      end;
    deref_defid :
      begin
        {$IFDEF VerbosePPUParser}
        idx:=pdata[i] shl 24 or pdata[i+1] shl 16 or pdata[i+2] shl 8 or pdata[i+3];
        dbgout(' DefId ',IntToStr(idx));
        {$ENDIF}
        inc(i,4);
      end;
    deref_unit :
      begin
        {$IFDEF VerbosePPUParser}
        idx:=pdata[i] shl 8 or pdata[i+1];
        dbgout(' Unit ',IntToStr(idx));
        {$ENDIF}
        inc(i,2);
      end;
    else
      begin
        Error('unsupported dereftyp: '+IntToStr(ord(b)));
        break;
      end;
    end;
  end;
  {$IFDEF VerbosePPUParser}
  debugln;
  {$ENDIF}
end;

procedure TPPU.ReadPosInfo;
var
  info : byte;
  fileindex,line,column : longint;
begin
  {
     info byte layout in bits:
     0-1 - amount of bytes for fileindex
     2-3 - amount of bytes for line
     4-5 - amount of bytes for column
  }
  fileindex:=0;
  line:=0;
  column:=0;
  info:=ReadEntryByte;
  case (info and $03) of
    0 : fileindex:=ReadEntryByte;
    1 : fileindex:=ReadEntryWord;
    2 : fileindex:=(ReadEntryByte shl 16) or ReadEntryWord;
    3 : fileindex:=ReadEntryLongint;
  end;
  case ((info shr 2) and $03) of
    0 : line:=ReadEntryByte;
    1 : line:=ReadEntryWord;
    2 : line:=(ReadEntryByte shl 16) or ReadEntryWord;
    3 : line:=ReadEntryLongint;
  end;
  case ((info shr 4) and $03) of
    0 : column:=ReadEntryByte;
    1 : column:=ReadEntryWord;
    2 : column:=(ReadEntryByte shl 16) or ReadEntryWord;
    3 : column:=ReadEntryLongint;
  end;
  if (fileindex<0) and (line<0) and (column<0) then ;
  {$IFDEF VerbosePPUParser}
  debugln(dbgs(fileindex),' (',dbgs(line),',',dbgs(column),')');
  {$ENDIF}
end;

procedure TPPU.ReadSymTableOptions;
var
  Nr: Byte;
  s: DWord;
begin
  Nr:=ReadEntry;
  if Nr<>ibsymtableoptions then
    Error('expected ibsymtableoptions, but found '+PPUEntryName(Nr));
  ReadEntrySmallSet(s);
end;

function TPPU.ReadEntry: byte;

  procedure ErrorInvalidTypeID;
  begin
    Error('Invalid entry type-id '+IntToStr(FEntry.id));
  end;

begin
  FEntryPos:=0;
  FEntryStart:=FDataPos;
  ReadData(FEntry,SizeOf(FEntry));
  if fChangeEndian then
    FEntry.size:=SwapEndian(FEntry.size);
  {$IFDEF VerbosePPUParser}
  //DebugLn(['TPPU.ReadEntry nr=',FEntry.Nr,'=',PPUEntryName(FEntry.nr),' streampos=',FDataPos,' type-id=',FEntry.id]);
  {$ENDIF}
  if not (FEntry.id in [mainentryid,subentryid]) then
    ErrorInvalidTypeID;
  Result:=FEntry.nr;
  if FEntryBufSize<FEntry.size then begin
    FEntryBufSize:=FEntryBufSize*2;
    if FEntryBufSize<FEntry.size then
      FEntryBufSize:=FEntry.size;
    ReAllocMem(FEntryBuf,FEntryBufSize);
  end;
  if FEntry.size>0 then
    ReadData(FEntryBuf^,FEntry.size);
end;

function TPPU.EndOfEntry: boolean;
begin
  Result:=FEntryPos>=FEntry.Size;
end;

procedure TPPU.SkipUntilEntry(EntryNr: byte);
var
  b: Byte;
begin
  repeat
    b:=ReadEntry;
  until (b=ibend) or ((b=EntryNr) and (FEntry.id=mainentryid));
  if b<>EntryNr then
    Error('TPPU.SkipUntilEntry not found: '+IntToStr(EntryNr));
end;

procedure TPPU.ReadDataFromStream(s: TStream);
var
  Entry: PPPUEntry;

  procedure Grow(Add: integer);
  const InitialSize = 16384;
  var
    NewSize: Integer;
  begin
    NewSize:=FDataPos+Add;
    if NewSize<=FDataSize then exit;
    // need grow
    if FDataSize<InitialSize then
      FDataSize:=InitialSize
    else
      FDataSize:=FDataSize*2;
    while FDataSize<NewSize do begin
      if FDataSize>100000000 then
        Error('ppu too big');
      FDataSize:=FDataSize*2;
    end;
    ReAllocMem(FData,FDataSize);
  end;
  
  function Read(Count: integer): Pointer;
  var
    ReadCount: LongInt;
  begin
    //DebugLn(['Read Count=',Count,' Pos=',FDataPos]);
    // read and copy some more data to FData
    Grow(Count);
    Result:=Pointer(FData+FDataPos);
    ReadCount:=s.Read(Result^,Count);
    if ReadCount<Count then
      Error('ppu too short, buggy ppu');
    inc(FDataPos,Count);
  end;

  function ReadEntryBlock: byte;
  begin
    Entry:=PPPUEntry(Read(SizeOf(FEntry)));
    if not (Entry^.id in [mainentryid,subentryid]) then
      Error('Invalid entry id '+IntToStr(Entry^.id));
    Result:=Entry^.nr;
    if fChangeEndian then
      Entry^.Size:=SwapEndian(Entry^.Size);
    if Entry^.Size<0 then
      Error('entry has negative size');
    Read(Entry^.Size);
  end;
  
  function ReadUntilEntry(EntryNr: byte): boolean;
  var
    b: Byte;
  begin
    repeat
      b:=ReadEntryBlock;
      if b=ibend then exit(false);
    until (b=EntryNr) and (Entry^.id=mainentryid);
    Result:=true;
  end;

var
  p: Pointer;
begin
  fChangeEndian:=PPUIsEndianBig;
  Entry:=nil;
  
  // read header
  p:=Read(SizeOf(TPPUHeader));
  System.Move(p^,FHeader,SizeOf(TPPUHeader));
  
  if String(FHeader.id)<>PPU_ID then
    Error('This is not a PPU. Wrong ID.');
  // read Version
  FVersion:=StrToIntDef(String(FHeader.ver),0);
  if FVersion<16 then
    Error('Old PPU versions (<16) are not supported.');
  // read rest of header
  if fChangeEndian then begin
    fHeader.compiler := swapendian(fHeader.compiler);
    fHeader.cpu := swapendian(fHeader.cpu);
    fHeader.target := swapendian(fHeader.target);
    fHeader.flags := swapendian(fHeader.flags);
    fHeader.size := swapendian(fHeader.size);
    fHeader.checksum := swapendian(fHeader.checksum);
    fHeader.interface_checksum := swapendian(fHeader.interface_checksum);
    fHeader.deflistsize := swapendian(fHeader.deflistsize);
    fHeader.symlistsize := swapendian(fHeader.symlistsize);
  end;
  fChangeEndian:=((FHeader.flags and uf_big_endian) = uf_big_endian)<>PPUIsEndianBig;

  // read entries
  if not ReadUntilEntry(ibendinterface) then
    Error('missing end of interface');
  if not ReadUntilEntry(ibenddefs) then
    Error('missing end of interface definitions');
  if not ReadUntilEntry(ibendsyms) then
    Error('missing end of interface symbols');
  if ReadEntryBlock=ibexportedmacros then begin
    if boolean(PByte(PByte(Entry)+SizeOf(TPPUEntry))^) then begin
      if not ReadUntilEntry(ibenddefs) then
        Error('missing end of macro definitions');
      if not ReadUntilEntry(ibendsyms) then
        Error('missing end of macro symbols');
    end;
  end;
  if not ReadUntilEntry(ibendimplementation) then
    Error('missing end of implementation');
  if (FHeader.flags and uf_local_symtable)<>0 then begin
    if not ReadUntilEntry(ibenddefs) then
      Error('missing end of implementation definitions');
    if not ReadUntilEntry(ibendsyms) then
      Error('missing end of implementation symbols');
  end;
  
  // shrink FData
  FDataSize:=FDataPos;
  ReAllocMem(FData,FDataSize);
  FDataPos:=0;
end;

procedure TPPU.ReadData(var Buf; Count: longint);
begin
  //DebugLn(['TPPU.ReadData Count=',Count,' Pos=',FDataPos]);
  if FDataPos+Count>FDataSize then
    Error('TPPU.ReadData: out of data');
  System.Move(Pointer(FData+FDataPos)^,Buf,Count);
  inc(FDataPos,Count);
end;

function TPPU.ReadEntryByte: byte;
begin
  if FEntryPos>=FEntry.size then
    Error('TPPU.ReadEntryByte: out of bytes');
  Result:=PByte(FEntryBuf+FEntryPos)^;
  inc(FEntryPos);
end;

function TPPU.ReadEntryByte(const Msg: string): byte;
begin
  Result:=ReadEntryByte();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryShortstring: shortstring;
var
  l: byte;
  s: shortstring;

  procedure ErrorOutOfBytes;
  begin
    Error('TPPU.ReadEntryShortstring: out of bytes. needed='+IntToStr(l)+', found='+IntToStr(FEntry.size-FEntryPos));
  end;

begin
  l:=ReadEntryByte;
  s[0]:=chr(l);
  if l>0 then begin
    if FEntryPos+l>FEntry.size then
      ErrorOutOfBytes;
    System.Move(Pointer(FEntryBuf+FEntryPos)^,s[1],l);
  end;
  Result:=s;
  inc(FEntryPos,l);
end;

function TPPU.ReadEntryShortstring(const Msg: string): shortstring;
begin
  Result:=ReadEntryShortstring();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryAnsistring: ansistring;
var
  l: longint;

  procedure ErrorOutOfBytes;
  begin
    Error('TPPU.ReadEntryAnsistring: out of bytes. needed='+IntToStr(l)+', found='+IntToStr(FEntry.size-FEntryPos));
  end;

begin
  l:=ReadEntryLongint;
  SetLength(Result,l);
  if l>0 then begin
    if FEntryPos+l>FEntry.size then
      ErrorOutOfBytes;
    System.Move(Pointer(FEntryBuf+FEntryPos)^,Result[1],l);
  end;
  inc(FEntryPos,l);
end;

function TPPU.ReadEntryAnsistring(const Msg: string): ansistring;
begin
  Result:=ReadEntryAnsistring();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryLongint: longint;
begin
  if FEntryPos+SizeOf(Longint)>FEntry.size then
    Error('TPPU.ReadEntryLongint: out of bytes');
  Result:=PLongint(FEntryBuf+FEntryPos)^;
  inc(FEntryPos,SizeOf(Longint));
end;

function TPPU.ReadEntryLongint(const Msg: string): longint;
begin
  Result:=ReadEntryLongint();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryDWord: cardinal;
begin
  Result:=cardinal(ReadEntryLongint);
end;

function TPPU.ReadEntryDWord(const Msg: string): cardinal;
begin
  Result:=cardinal(ReadEntryLongint(Msg));
end;

function TPPU.ReadEntryWord: word;
begin
  if FEntryPos+SizeOf(Word)>FEntry.size then
    Error('TPPU.ReadEntryLongint: out of bytes');
  Result:=PWord(FEntryBuf+FEntryPos)^;
  inc(FEntryPos,SizeOf(Word));
end;

function TPPU.ReadEntryWord(const Msg: string): word;
begin
  Result:=ReadEntryWord();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryInt64: int64;
begin
  if FEntryPos+SizeOf(Int64)>FEntry.size then
    Error('TPPU.ReadEntryInt64: out of bytes');
  Result:=PInt64(FEntryBuf+FEntryPos)^;
  inc(FEntryPos,SizeOf(Int64));
end;

function TPPU.ReadEntryInt64(const Msg: string): int64;
begin
  Result:=ReadEntryInt64();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryQWord: QWord;
begin
  if FEntryPos+SizeOf(QWord)>FEntry.size then
    Error('TPPU.ReadEntryQWord: out of bytes');
  Result:=PQWord(FEntryBuf+FEntryPos)^;
  inc(FEntryPos,SizeOf(QWord));
end;

function TPPU.ReadEntryQWord(const Msg: string): QWord;
begin
  Result:=ReadEntryQWord();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryAInt: int64;
begin
  case FSizeOfAInt of
    8: result:=ReadEntryInt64;
    4: result:=ReadEntryLongint;
    2: result:=smallint(ReadEntryWord);
    1: result:=shortint(ReadEntryByte);
  else
    Result:=0;
  end;
end;

function TPPU.ReadEntryAInt(const Msg: string): int64;
begin
  Result:=ReadEntryAInt();
  debugln([Msg,Result]);
end;

function TPPU.ReadEntryASizeInt: int64;
begin
  case FSizeOfASizeInt of
    8: result:=ReadEntryInt64;
    4: result:=ReadEntryLongint;
    2: result:=smallint(ReadEntryWord);
    1: result:=shortint(ReadEntryByte);
  else
    Result:=0;
  end;
end;

function TPPU.ReadEntryASizeInt(const Msg: string): int64;
begin
  Result:=ReadEntryASizeInt();
  debugln([Msg,Result]);
end;

procedure TPPU.ReadEntrySmallSet(out s);
var
  i: longint;
begin
  if FEntryPos+4>FEntry.size then
    Error('TPPU.ReadEntryLongint: out of bytes');
  System.Move(PByte(FEntryBuf+FEntryPos)^,s{%H-},4);
  inc(FEntryPos,4);
  if fChangeEndian then
    for i:=0 to 3 do
      Pbyte(@s)[i]:=reverse_byte(Pbyte(@s)[i]);
end;

procedure TPPU.ReadEntryNormalSet(out s);
var
  i: longint;
begin
  if FEntryPos+32>FEntry.size then
    Error('TPPU.ReadEntryLongint: out of bytes');
  System.Move(PByte(FEntryBuf+FEntryPos)^,s{%H-},32);
  inc(FEntryPos,32);
  if fChangeEndian then
    for i:=0 to 31 do
      Pbyte(@s)[i]:=reverse_byte(Pbyte(@s)[i]);
end;

procedure TPPU.ReadUsedUnits;
{$IFDEF VerbosePPUParser}
var
  AUnitName: ShortString;
  CRC: DWord;
  IntfCRC: DWord;
  IndirectCRC: DWord;
{$ENDIF}
begin
  while not EndOfEntry do begin
    {$IFDEF VerbosePPUParser}AUnitName:={$ENDIF}ReadEntryShortstring;
    {$IFDEF VerbosePPUParser}CRC:={$ENDIF}ReadEntryDWord;
    {$IFDEF VerbosePPUParser}IntfCRC:={$ENDIF}ReadEntryDWord;
    if FVersion>=107 then begin
      // svn rev 14503  ppu ver 107
      {$IFDEF VerbosePPUParser}IndirectCRC:={$ENDIF}ReadEntryDWord;
    end else begin
      {$IFDEF VerbosePPUParser}IndirectCRC:=0;{$ENDIF}
    end;
    {$IFDEF VerbosePPUParser}
    DebugLn(['TPPU.ReadUsedUnits Unit=',AUnitName,' CRC=',HexStr(cardinal(CRC),8),' IntfCRC=',HexStr(cardinal(IntfCRC),8),' IndCRC=',HexStr(cardinal(IndirectCRC),8)]);
    {$ENDIF}
  end;
end;

procedure TPPU.ReadModuleOptions;
type
  tmoduleoption = (
    mo_none,
    mo_hint_deprecated,
    mo_hint_platform,
    mo_hint_library,
    mo_hint_unimplemented,
    mo_hint_experimental,
    mo_has_deprecated_msg
  );
  tmoduleoptions = set of tmoduleoption;
{$IFDEF VerbosePPUParser}
type
  tmoduleopt=record
    mask : tmoduleoption;
    str  : string[30];
  end;
const
  moduleopts=6;
  moduleopt : array[1..moduleopts] of tmoduleopt=(
     (mask:mo_hint_deprecated;    str:'Hint Deprecated'),
     (mask:mo_hint_platform;      str:'Hint Platform'),
     (mask:mo_hint_library;       str:'Hint Library'),
     (mask:mo_hint_unimplemented; str:'Hint Unimplemented'),
     (mask:mo_hint_experimental;  str:'Hint Experimental'),
     (mask:mo_has_deprecated_msg; str:'Has Deprecated Message')
  );
{$ENDIF}
var
  moduleoptions : tmoduleoptions;
  {$IFDEF VerbosePPUParser}
  i      : longint;
  first  : boolean;
  {$ENDIF}
begin
  ReadEntrySmallSet(moduleoptions);
  {$IFDEF VerbosePPUParser}
  if moduleoptions<>[] then
  begin
    first:=true;
    for i:=1 to moduleopts do
      if (moduleopt[i].mask in moduleoptions) then
      begin
        if first then
          first:=false
        else
          dbgout(', ');
        dbgout(moduleopt[i].str);
      end;
    debugln;
  end;
  {$ENDIF}
  if mo_has_deprecated_msg in moduleoptions then begin
    ReadEntryShortstring{$IFDEF VerbosePPUParser}('Deprecated : '){$ENDIF};
  end;
end;

procedure TPPU.ReadLinkContainer(aContainerType: byte);
{$IFDEF VerbosePPUParser}
var
  Desc: String;
var
  Filename: ShortString;
  Flags: LongInt;
{$ENDIF}
begin
  {$IFNDEF VerbosePPUParser}
  if aContainerType=0 then ;
  {$ENDIF}
  while not EndOfEntry do begin
    {$IFDEF VerbosePPUParser}Filename:={$ENDIF}ReadEntryShortstring;
    {$IFDEF VerbosePPUParser}Flags:={$ENDIF}ReadEntryLongint;
    {$IFDEF VerbosePPUParser}
    case Nr of
    iblinkunitofiles:
      Desc:='Link unit object file: ';
    iblinkunitstaticlibs :
      Desc:='Link unit static lib: ';
    iblinkunitsharedlibs :
      Desc:='Link unit shared lib: ';
    iblinkotherofiles :
      Desc:='Link other object file: ';
    iblinkotherstaticlibs :
      Desc:='Link other static lib: ';
    iblinkothersharedlibs :
      Desc:='Link other shared lib: ';
    iblinkotherframeworks:
      Desc:='Link framework: ';
    end;
    Desc:=Desc+Filename+' '+PPULinkContainerFlagToStr(Flags);
    DebugLn(['TPPU.ReadLinkContainer ',Desc]);
    {$ENDIF}
  end;
end;

procedure TPPU.ReadResources;
{$IFDEF VerbosePPUParser}
var
  Filename: ShortString;
{$ENDIF}
begin
  while not EndOfEntry do begin
    {$IFDEF VerbosePPUParser}Filename:={$ENDIF}ReadEntryShortstring;
    {$IFDEF VerbosePPUParser}
    DebugLn(['TPPU.ReadResources file: '+Filename]);
    {$ENDIF}
  end;
end;

procedure TPPU.ReadImportSymbols;
var
  SymbolCount: LongInt;
  i: Integer;
  {$IFDEF VerbosePPUParser}
  LibName: ShortString;
  SymbolName: ShortString;
  SymbolOrdNr: LongInt;
  SymbolIsVar: Boolean;
  SymMangledName: String;
  {$ENDIF}
begin
  while not EndOfEntry do begin
    {$IFDEF VerbosePPUParser}LibName:={$ENDIF}ReadEntryShortstring;
    SymbolCount:=ReadEntryLongint;
    {$IFDEF VerbosePPUParser}
    DebugLn(['TPPU.ReadImportSymbols External Library: ',LibName,' (',SymbolCount,' imports)']);
    {$ENDIF}
    for i:=0 to SymbolCount-1 do
    begin
      {$IFDEF VerbosePPUParser}SymbolName:={$ENDIF}ReadEntryShortstring;
      if Version>130 then
        {$IFDEF VerbosePPUParser}SymMangledName:={$ENDIF}ReadEntryShortstring
      else
        {$IFDEF VerbosePPUParser}SymMangledName:=SymbolName{$ENDIF};
      {$IFDEF VerbosePPUParser}SymbolOrdNr:={$ENDIF}ReadEntryLongint;
      {$IFDEF VerbosePPUParser}SymbolIsVar:=ReadEntryByte<>0{$ELSE}ReadEntryByte{$ENDIF};
      {$IFDEF VerbosePPUParser}
      DebugLn(['TPPU.ReadImportSymbols "',SymbolName,'" Mangled="',SymMangledName,'" (OrdNr: ',SymbolOrdNr,' IsVar: ',SymbolIsVar,')']);
      {$ENDIF}
    end;
  end;
end;

procedure TPPU.ReadDerefData;
begin
  {$IFDEF VerbosePPUParser}
  DebugLn(['TPPU.ReadDerefData Deref Data length: ',FEntry.size-FEntryPos]);
  {$ENDIF}
  FDerefDataSize:=FEntry.size-FEntryPos;
  if FDerefDataSize>0 then begin
    FDerefData:=AllocMem(FDerefDataSize);
    System.Move(PByte(FEntryBuf+FEntryPos)^,FDerefData^,FDerefDataSize);
    FEntryPos:=FEntry.size;
  end;
end;

procedure TPPU.ReadDerefMap;
var
  Count: LongInt;
  i: Integer;
  {$IFDEF VerbosePPUParser}
  MapName: ShortString;
  {$ENDIF}
begin
  Count:=ReadEntryLongint;
  for i:=0 to Count-1 do begin
    {$IFDEF VerbosePPUParser}MapName:={$ENDIF}ReadEntryShortstring;
    {$IFDEF VerbosePPUParser}
    DebugLn(['TPPU.ReadDerefMap ',i,' ',MapName]);
    {$ENDIF}
  end;
end;

procedure TPPU.Skip(Count: integer);
begin
  if FDataPos+Count>FDataSize then
    Error('TPPU.Skip: out of data');
  inc(FDataPos,Count);
end;

procedure TPPU.Error(const Msg: string);
begin
  {$IFDEF VerbosePPUParser}
  CTDumpStack;
  {$ENDIF}
  raise EPPUParserError.Create(Self,Msg);
end;

procedure TPPU.GetUsesSection(StartPos: integer; var List: TStrings);
var
  AUnitName: String;
begin
  if StartPos<=0 then exit;
  SetDataPos(StartPos);
  if ReadEntry<>ibloadunit then exit;
  while not EndOfEntry do begin
    AUnitName:=ReadEntryShortstring;
    if List=nil then
      List:=TStringListUTF8Fast.Create;
    if List.IndexOf(AUnitName)<0 then
      List.Add(AUnitName);
    ReadEntryDWord; // CRC
    ReadEntryDWord; // IntfCRC
    if FVersion>=107 then ReadEntryDWord;
  end;
end;

procedure TPPU.SetDataPos(NewPos: integer);
begin
  FillByte(FEntry,SizeOf(FEntry),0);
  FEntryPos:=0;
  FDataPos:=NewPos;
end;

function TPPU.GetProcMangledName(ProcDefPos: integer): string;
var
  calloption: tproccalloption;
  procoptions: tprocoptions;
  proctypeoption: tproctypeoption;
begin
  Result:='';
  if ProcDefPos<=0 then exit;
  SetDataPos(ProcDefPos);
  if ReadEntry<>ibprocdef then exit;
  ReadCommonDefinition;
  ReadAbstractProcDef(calloption,procoptions,proctypeoption);
  if (po_has_mangledname in procoptions) then
    Result:=ReadEntryShortstring;
end;

constructor TPPU.Create(TheOwner: TObject);
begin
  FOwner:=TheOwner;
end;

destructor TPPU.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TPPU.Clear;
begin
  FillByte(FHeader,SizeOf(FHeader),0);
  FillByte(FEntry,SizeOf(FEntry),0);
  FEntryPos:=0;
  
  ReAllocMem(FEntryBuf,0);
  FEntryBufSize:=0;
  
  ReAllocMem(FDerefData,0);
  FDerefDataSize:=0;
  
  ReAllocMem(FData,0);
  FDataSize:=0;
  FDataPos:=0;

  FInterfaceHeaderPos:=0;
  FMainUsesSectionPos:=0;
  FImplementationHeaderPos:=0;
  FImplementationUsesSectionPos:=0;
  FInitProcPos:=0;
  FFinalProcPos:=0;
end;

procedure TPPU.LoadFromStream(s: TStream; const Parts: TPPUParts);
begin
  Clear;
  ReadDataFromStream(s);
  ReadPPU(Parts);
end;

procedure TPPU.LoadFromFile(const Filename: string; const Parts: TPPUParts);
var
  ms: TMemoryStream;
  fs: TFileStream;
begin
  fs:=TFileStream.Create(Filename,fmOpenRead or fmShareDenyWrite);
  ms:=TMemoryStream.Create;
  try
    ms.Size:=fs.Size;
    ms.CopyFrom(fs,fs.Size);
    ms.Position:=0;
    LoadFromStream(ms,Parts);
  finally
    ms.Free;
    fs.Free;
  end;
end;

procedure TPPU.Dump(const Prefix: string);
begin
  DebugLn([Prefix+'TPPU.Dump ']);
  DumpHeader(Prefix+'  ');
end;

procedure TPPU.DumpHeader(const Prefix: string);
begin
  DebugLn([Prefix,'Header']);
  DebugLn([Prefix,'  ID=',String(FHeader.ID)]);
  DebugLn([Prefix,'  Ver=',StrToIntDef(String(FHeader.ver),0)]);
  DebugLn([Prefix,'  Compiler=',FHeader.compiler shr 14,'.',
                            (FHeader.compiler shr 7) and $7f,'.',
                            FHeader.compiler and $7f]);
  DebugLn([Prefix,'  Target CPU=',PPUCpuToStr(FHeader.cpu)]);
  DebugLn([Prefix,'  Target OS=',PPUTargetToStr(FHeader.target)]);
  DebugLn([Prefix,'  Unit Flags=',PPUFlagsToStr(FHeader.flags)]);
  DebugLn([Prefix,'  Filesize (w/o header)=',FHeader.size]);
  DebugLn([Prefix,'  Checksum=',HexStr(cardinal(FHeader.checksum),8)]);
  DebugLn([Prefix,'  Interface CheckSum=',HexStr(cardinal(FHeader.interface_checksum),8)]);
  DebugLn([Prefix,'  Number of Definitions=',FHeader.deflistsize]);
  DebugLn([Prefix,'  Number of Symbols=',FHeader.symlistsize]);
  DebugLn([Prefix,'  Indirect Checksum=',HexStr(cardinal(FHeader.indirect_checksum),8)]);
  DebugLn([Prefix,'  sizeof(aint)=',FSizeOfAInt]);
end;

procedure TPPU.GetMainUsesSectionNames(var List: TStrings);
begin
  GetUsesSection(FMainUsesSectionPos,List);
end;

procedure TPPU.GetImplementationUsesSectionNames(var List: TStrings);
begin
  GetUsesSection(FImplementationUsesSectionPos,List);
end;

procedure TPPU.GetLinkedFiles(var ListOfTPPULinkedFile: TObjectList);
var
  EntryNr: Byte;
  Item: TPPULinkedFile;
  Filename: String;
  Flags: LongInt;
begin
  if FInterfaceHeaderPos=0 then exit;
  SetDataPos(FInterfaceHeaderPos);
  repeat
    EntryNr:=ReadEntry;
    case EntryNr of
    iblinkunitofiles,iblinkunitstaticlibs,iblinkunitsharedlibs,
    iblinkotherofiles,iblinkotherstaticlibs,iblinkothersharedlibs,
    iblinkotherframeworks:
      begin
        while not EndOfEntry do begin
          Filename:=ReadEntryShortstring;
          Flags:=ReadEntryLongint;
          //debugln(['TPPU.GetLinkedFiles ',PPUEntryName(EntryNr),' ',Filename]);
          if ListOfTPPULinkedFile=nil then
            ListOfTPPULinkedFile:=TObjectList.Create(true);
          Item:=TPPULinkedFile.Create;
          Item.ID:=EntryNr;
          Item.Filename:=Filename;
          Item.Flags:=Flags;
          ListOfTPPULinkedFile.Add(Item);
        end;
      end;

    ibendinterface:
      break;

    else
      FEntryPos:=FEntry.size;
    end;
  until false;
end;

function TPPU.GetInitProcName: string;
begin
  Result:=GetProcMangledName(FInitProcPos);
end;

function TPPU.GetFinalProcName: string;
begin
  Result:=GetProcMangledName(FFinalProcPos);
end;

end.


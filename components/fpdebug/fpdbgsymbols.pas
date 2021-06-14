{ $Id$ }
{
 ---------------------------------------------------------------------------
 fpdbgsymbols.pas  -  Native freepascal debugger - Symbol loader/resolver
 ---------------------------------------------------------------------------

 This unit contains helper classes for loading and resolving of debug symbols

 ---------------------------------------------------------------------------

 @created(Sat Jun 24th WET 2006)
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
unit FpDbgSymbols;

{$mode objfpc}{$H+}

interface

uses
{$ifdef windows}
  Windows,
{$endif}
  Classes, SysUtils, FpDbgInfo, FpDbgWinExtra, FpDbgPETypes, FpDbgDwarf, FpDbgUtil,
  FpDbgDwarfConst, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif};
  

{$ifdef windows}
procedure AddSymbols(AParent: TFpSymbol; AModule: THandle);
{$endif}

implementation

{$ifdef windows}
var
  DBG_WARNINGS, FPDBG_DWARF_VERBOSE_LOAD: PLazLoggerLogGroup;

procedure AddSymbols(AParent: TFpSymbol; AModule: THandle);
var
  ModulePtr: Pointer;
  //Is64: Boolean;
  Sections: TStringList;
  
  procedure AddDwarf;
    procedure Dump(p: PChar; count: Integer; SH: PImageSectionHeader);
    var
      n: integer;
    begin
      if (FPDBG_DWARF_VERBOSE_LOAD = nil) or (not FPDBG_DWARF_VERBOSE_LOAD^.Enabled) then
        exit;
      DebugLn('.debug_info');
      DebugLn('  length: ', IntToStr(PCardinal(p)^));
      Inc(p, 4);
      DebugLn('  version: ', IntToStr(PWord(p)^));
      Inc(p, 2);
      DebugLn('  abbrev offset: ', IntToStr(PCardinal(p)^));
      Inc(p, 4);
      DebugLn('  address size: ', IntToStr(PByte(p)^));
      Inc(p, 1);

      DebugLn( HexValue(SH^.PointerToRawData, 8, []), ': ');
      for n := 1 to count do
      begin
        case p^ of
          #32..#127: DebugLn(p^, ' ');
        else
          DebugLn('#', Char(p^), ' ');
        end;
        Inc(p);
      end;
      DebugLn('');
    end;
    
    function ULEB128toOrdinal(var p: PByte): Integer;
    var
      n: Byte;
    begin
      Result := 0;
      n := 0;
      repeat
        Result := Result + (p^ and $7F) shl n;
        Inc(n, 7);
        Inc(p);
      until ((p^ and $80) = 0) or (n > 128);
    end;

  var
    idx4, idx16: Integer;
    data4, data16: Pointer;
    SH: PImageSectionHeader;
    n: integer;
    p: Pointer;
    pb: PByte absolute p;
    pw: PWord absolute p;
    Name, Value: Cardinal;
  begin
    idx4 := Sections.IndexOf('/4');
    idx16 := Sections.IndexOf('/16');
    if (idx4 = -1) and (idx16 = -1) then Exit;

    SH := Pointer(Sections.Objects[idx4]);
    Data4 := ModulePtr + SH^.PointerToRawData;
    Dump(Data4, 80, SH);

    SH := Pointer(Sections.Objects[idx16]);
    Data16 := ModulePtr + SH^.PointerToRawData;
    p := Data16;
    DebugLn(FPDBG_DWARF_VERBOSE_LOAD, '.debug_abbrev');
    while pb^ <> 0 do
    begin
      Value := Cardinal(ULEB128toOrdinal(pb));
      Name := Cardinal(ULEB128toOrdinal(pb));
      DebugLn(FPDBG_DWARF_VERBOSE_LOAD, ['  abbrev:  ', IntToStr(Cardinal(ULEB128toOrdinal(pb))),
        '  tag:     ', IntToStr(Value), '=', DwarfTagToString(Value),
        '  children:', IntToStr(pb^)]);
      inc(pb);
      for n := 0 to 15 do
      begin
        Name := Cardinal(ULEB128toOrdinal(pb));
        Value := Cardinal(ULEB128toOrdinal(pb));
        if (name = 0) and (value = 0) then Break;
        DebugLn(FPDBG_DWARF_VERBOSE_LOAD, '   [', IntToStr(n), '] name: ', IntToStr(Name), '=', DwarfAttributeToString(Name), ', value:', IntToStr(Value), '=', DwarfAttributeFormToString(Value));
      end;
      if (name = 0) and (value = 0) then Continue;
      while pw^ <> 0 do Inc(pw);
      inc(pw);
    end;

  end;
  
  procedure AddStabs;
  var
    idx, idxstr: Integer;
  begin
    idx := Sections.Indexof('.stab');
    idxstr := Sections.Indexof('.stabstr');
    if (idx = -1) and (idxstr = -1) then Exit;
  end;

var
  hMap: THandle;
  DosHeader: PImageDosHeader;
  NtHeaders: PImageNtHeaders;
  SectionHeader: PImageSectionHeader;
  n: Integer;
  SectionName: array[0..IMAGE_SIZEOF_SHORT_NAME] of Char;
begin
  hMap := 0;
  ModulePtr := nil;
  Sections := nil;
  try
    hMap := CreateFileMapping(AModule, nil, PAGE_READONLY{ or SEC_IMAGE}, 0, 0, nil);
    if hMap = 0
    then begin
      DebugLn(DBG_WARNINGS or FPDBG_DWARF_VERBOSE_LOAD, 'AddSymbols: Could not create module mapping');
      Exit;
    end;

    ModulePtr := MapViewOfFile(hMap, FILE_MAP_READ, 0, 0, 0);
    if ModulePtr = nil
    then begin
      DebugLn(DBG_WARNINGS or FPDBG_DWARF_VERBOSE_LOAD, 'AddSymbols: Could not map view');
      Exit;
    end;

    DosHeader := ModulePtr;
    if (DosHeader^.e_magic <> IMAGE_DOS_SIGNATURE)
    or (DosHeader^.e_lfanew = 0)
    then begin
      DebugLn(DBG_WARNINGS or FPDBG_DWARF_VERBOSE_LOAD, 'AddSymbols: Invalid DOS header');
      Exit;
    end;

    NTHeaders := ModulePtr + DosHeader^.e_lfanew;

    if NTHeaders^.Signature <> IMAGE_NT_SIGNATURE
    then begin
      DebugLn(DBG_WARNINGS or FPDBG_DWARF_VERBOSE_LOAD, 'AddSymbols: Invalid NT header: %s', [IntToHex(NTHeaders^.Signature, 8)]);
      Exit;
    end;

    //Is64 := NTHeaders^.OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR64_MAGIC;

    Sections := TStringList.Create;
    Sections.CaseSensitive := False;
    Sections.Duplicates := dupIgnore;
    Sections.Sorted := True;
    for n := 0 to NtHeaders^.FileHeader.NumberOfSections - 1 do
    begin
      SectionHeader := Pointer(@NTHeaders^.OptionalHeader) + NTHeaders^.FileHeader.SizeOfOptionalHeader + SizeOf(SectionHeader^) * n;
      // make a null terminated name
      Move(SectionHeader^.Name, SectionName, IMAGE_SIZEOF_SHORT_NAME);
      SectionName[IMAGE_SIZEOF_SHORT_NAME] := #0;
      Sections.AddObject(SectionName, TObject(SectionHeader));
    end;
    
    AddDwarf;
    AddStabs;
    //TODO: AddOther



  (*
      with SectionHeader do
      begin
        Move(SectionHeader.Name, SectionName, IMAGE_SIZEOF_SHORT_NAME);
        SectionName[IMAGE_SIZEOF_SHORT_NAME] := #0;
        WriteLN('  Name:                 ',SectionName);
        WriteLN('  Misc.PhysicalAddress: ',FormatAddress(Misc.PhysicalAddress));
        WriteLN('  Misc.VirtualSize:     ',Misc.VirtualSize);
        WriteLN('  VirtualAddress:       ',FormatAddress(VirtualAddress));
        WriteLN('  SizeOfRawData:        ',SizeOfRawData);
        WriteLN('  PointerToRawData:     ',FormatAddress(PointerToRawData));
        WriteLN('  PointerToRelocations: ',FormatAddress(PointerToRelocations));
        WriteLN('  PointerToLinenumbers: ',FormatAddress(PointerToLinenumbers));
        WriteLN('  NumberOfRelocations:  ',NumberOfRelocations);
        WriteLN('  NumberOfLinenumbers:  ',NumberOfLinenumbers);
        Write('  Characteristics:      ', IntToHex(Characteristics, 8), ' [');
      end;
  *)

  finally
    UnmapViewOfFile(ModulePtr);
    CloseHandle(hMap);
    Sections.Free;
  end;
end;
{$endif}

initialization
  {$ifdef windows}
  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
  FPDBG_DWARF_VERBOSE_LOAD  := DebugLogger.FindOrRegisterLogGroup('FPDBG_DWARF_VERBOSE_LOAD' {$IFDEF FPDBG_DWARF_VERBOSE_LOAD} , True {$ENDIF} );
  {$endif}
end.


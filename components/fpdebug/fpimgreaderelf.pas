{
 This unit contains the types needed for reading Elf images.

 This file was ported from DUBY. See svn log for details

 ---------------------------------------------------------------------------

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
unit FpImgReaderElf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  LazUTF8, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif},
  DbgIntfBaseTypes,
  // FpDebug
  FpImgReaderBase, fpDbgSymTable, FpImgReaderElfTypes, FpDbgCommon;

type
  TElfSection = packed record
    name      : AnsiString;
    FileOfs   : QWord;
    Address   : QWord;
    Size      : QWord;
  end;
  PElfSection = ^TElfSection;

  { TElfFile }

  TElfFile = class(TObject)
  private
    FTargetInfo: TTargetDescriptor;
    function FElfToMachineType(machinetype: word): TMachineType;
  protected
    function Load32BitFile(ALoader: TDbgFileLoader): Boolean;
    function Load64BitFile(ALoader: TDbgFileLoader): Boolean;
    procedure AddSection(const name: AnsiString; FileOffset, Address, Size: Qword);
  public
    sections  : array of TElfSection;
    seccount  : Integer;
    function LoadFromFile(ALoader: TDbgFileLoader): Boolean;
    function FindSection(const Name: String): Integer;
  end;

  { TElfDbgSource }

  TElfDbgSource = class(TDbgImageReader) // executable parser
  private
    FSections: TStringListUTF8Fast;
    FFileLoader     : TDbgFileLoader;
    fOwnSource  : Boolean;
    fElfFile    : TElfFile;
  protected
    function GetSection(const AName: String): PDbgImageSection; override;
  public
    class function isValid(ASource: TDbgFileLoader): Boolean; override;
    class function UserName: AnsiString; override;
    constructor Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean); override;
    destructor Destroy; override;
    procedure ParseSymbolTable(AFpSymbolInfo: TfpSymbolList); override;

    //function GetSectionInfo(const SectionName: AnsiString; var Size: int64): Boolean; override;
    //function GetSectionData(const SectionName: AnsiString; Offset, Size: Int64; var Buf: array of byte): Int64; override;
  end;

implementation

type
  TElf32symbol=record
    st_name  : longword;
    st_value : longword;
    st_size  : longword;
    st_info  : byte; { bit 0-3: type, 4-7: bind }
    st_other : byte;
    st_shndx : word;
  end;
  PElf32symbolArray = ^TElf32symbolArray;
  TElf32symbolArray = array[0..maxSmallint] of TElf32symbol;

  TElf64symbol=record
    st_name  : longword;
    st_info  : byte; { bit 0-3: type, 4-7: bind }
    st_other : byte;
    st_shndx : word;
    st_value : qword;
    st_size  : qword;
  end;
  PElf64symbolArray = ^TElf64symbolArray;
  TElf64symbolArray = array[0..maxSmallint] of TElf64symbol;



const
  // Symbol-map section name
  _symbol        = '.symtab';
  _symbolstrings = '.strtab';

{ TElfFile }

function TElfFile.FElfToMachineType(machinetype: word): TMachineType;
begin
  case machinetype of
    EM_386:       result := mt386;
    EM_68K:       result := mt68K;
    EM_PPC:       result := mtPPC;
    EM_PPC64:     result := mtPPC64;
    EM_ARM:       result := mtARM;
    EM_OLD_ALPHA: result := mtOLD_ALPHA;
    EM_IA_64:     result := mtIA_64;
    EM_X86_64:    result := mtX86_64;
    EM_AVR:       result := mtAVR8;
    EM_ALPHA:     result := mtALPHA;
  else
    result := mtNone;
  end;

  // If OS is not encoded in header, take some guess based on machine type
  if FTargetInfo.OS = osNone then
  begin
    if result = mtAVR8 then
      FTargetInfo.OS := osEmbedded
    else
      // Default to the same as host...
      FTargetInfo.OS := {$if defined(Linux)}osLinux
                    {$elseif defined(Darwin)}osDarwin
                    {$else}osWindows{$endif};
  end;
end;

function TElfFile.Load32BitFile(ALoader: TDbgFileLoader): Boolean;
var
  hdr   : Elf32_Ehdr;
  sect  : array of Elf32_shdr;
  i, j  : integer;
  nm    : string;
  sz    : LongWord;
  strs  : array of byte;
begin
  Result := ALoader.Read(0, sizeof(hdr), @hdr) = sizeof(hdr);
  if not Result then Exit;

  FTargetInfo.machineType := FElfToMachineType(hdr.e_machine);

  SetLength(sect, hdr.e_shnum);
  //ALoader.Position := hdr.e_shoff;

  sz := hdr.e_shetsize * hdr.e_shnum;
  if sz > LongWord(length(sect)*sizeof(Elf32_shdr)) then begin
    debugln(['TElfFile.Load32BitFile Size of SectHdrs is ', sz, ' expected ', LongWord(length(sect)*sizeof(Elf32_shdr))]);
    sz := LongWord(length(sect)*sizeof(Elf32_shdr));
  end;
  //ALoader.Read(sect[0], sz);
  ALoader.Read(hdr.e_shoff, sz, @sect[0]);

  i := sect[hdr.e_shstrndx].sh_offset;
  j := sect[hdr.e_shstrndx].sh_size;
  SetLength(strs, j);
  //ALoader.Position:=i;
  //ALoader.Read(strs[0], j);
  ALoader.Read(i, j, @strs[0]);

  for i := 0 to hdr.e_shnum - 1 do
    with sect[i] do begin
      nm := PChar( @strs[sh_name] );
      AddSection(nm, sh_offset, sh_addr, sh_size );
    end;
end;

function TElfFile.Load64BitFile(ALoader: TDbgFileLoader): Boolean;
var
  hdr   : Elf64_Ehdr;
  sect  : array of Elf64_shdr;
  i, j  : integer;
  nm    : string;
  sz    : LongWord;
  strs  : array of byte;
begin
  Result := ALoader.Read(0, sizeof(hdr), @hdr) = sizeof(hdr);
  if not Result then Exit;

  FTargetInfo.machineType := FElfToMachineType(hdr.e_machine);

  SetLength(sect, hdr.e_shnum);
  //ALoader.Position := hdr.e_shoff;

  sz := hdr.e_shentsize * hdr.e_shnum;
  if sz > LongWord(length(sect)*sizeof(Elf64_shdr)) then begin
    debugln(['TElfFile.Load64BitFile Size of SectHdrs is ', sz, ' expected ', LongWord(length(sect)*sizeof(Elf64_shdr))]);
    sz := LongWord(length(sect)*sizeof(Elf64_shdr));
  end;
  //ALoader.Read(sect[0], sz);
  ALoader.Read(hdr.e_shoff, sz, @sect[0]);

  i := sect[hdr.e_shstrndx].sh_offset;
  j := sect[hdr.e_shstrndx].sh_size;
  SetLength(strs, j);
  //ALoader.Position:=i;
  //ALoader.Read(strs[0], j);
  ALoader.Read(i, j, @strs[0]);

  for i := 0 to hdr.e_shnum - 1 do
    with sect[i] do begin
      nm := PChar( @strs[sh_name] );
      AddSection(nm, sh_offset, sh_address, sh_size );
    end;
end;

procedure TElfFile.AddSection(const name: AnsiString; FileOffset, Address,
  Size: Qword);
begin
  if seccount=Length(sections) then begin
    if seccount = 0 then SetLength(sections, 4)
    else SetLength(sections, seccount*2);
  end;
  sections[seccount].Address:= Address;
  sections[seccount].name:=name;
  sections[seccount].FileOfs:=FileOffset;
  sections[seccount].Size:=Size;
  inc(seccount);
end;

function TElfFile.LoadFromFile(ALoader: TDbgFileLoader): Boolean;
var
  ident : array [0..EINDENT-1] of byte;
begin
  try
    Result :=  ALoader.Read(0, sizeof(ident), @ident[0]) = sizeof(ident);
    if not Result then Exit;

    Result := (ident[EI_MAG0] = $7f) and
              (ident[EI_MAG1] = byte('E')) and
              (ident[EI_MAG2] = byte('L')) and
              (ident[EI_MAG3] = byte('F'));
    if not Result then Exit;

    Result := False;
    case ident[EI_DATA] of
      ELFDATA2LSB: FTargetInfo.ByteOrder := boLSB;
      ELFDATA2MSB: FTargetInfo.ByteOrder := boMSB;
    else
      FTargetInfo.byteOrder := boNone;
    end;

    case ident[EI_OSABI] of
      ELFOSABI_LINUX: FTargetInfo.OS := osLinux;
      ELFOSABI_STANDALONE: FTargetInfo.OS := osEmbedded;
    else
      FTargetInfo.OS := osNone;  // Will take a guess after machine type is available
    end;

    if ident[EI_CLASS] = ELFCLASS32 then begin
      FTargetInfo.bitness := b32;
      Result := Load32BitFile(ALoader);
      exit;
    end;

    if ident[EI_CLASS] = ELFCLASS64 then begin
      FTargetInfo.bitness := b64;
      Result := Load64BitFile(ALoader);
      exit;
    end;

  except
    Result := false;
  end;
end;

function TElfFile.FindSection(const Name: String): Integer;
var
  i : Integer;
begin
  Result := -1;
  for i := 0 to seccount - 1 do
    if sections[i].name = Name then begin
      Result := i;
      Exit;
    end;
end;

{ TElfDbgSource }

function TElfDbgSource.GetSection(const AName: String): PDbgImageSection;
var
  i: Integer;
  ex: PDbgImageSectionEx;
begin
  Result := nil;
  i := FSections.IndexOf(AName);
  if i < 0 then
    exit;
  ex := PDbgImageSectionEx(FSections.Objects[i]);
  Result := @ex^.Sect;
  if ex^.Loaded then
    exit;
  ex^.Loaded  := True;
  FFileLoader.LoadMemory(ex^.Offs, Result^.Size, Result^.RawData);
end;

class function TElfDbgSource.isValid(ASource: TDbgFileLoader): Boolean;
var
  buf : array [0..3+sizeof(Elf32_EHdr)] of byte;
begin
  try
    Result := Assigned(ASource) and
      (ASource.Read(0, sizeof(Elf32_EHdr), @buf[0]) = sizeof(Elf32_EHdr));

    if not Result then Exit;

    Result := (buf[EI_MAG0] = $7f) and (buf[EI_MAG1] = byte('E')) and
              (buf[EI_MAG2] = byte('L')) and (buf[EI_MAG3] = byte('F'));
  except
    Result := false;
  end;
end;

class function TElfDbgSource.UserName: AnsiString;
begin
  Result := 'ELF executable';
end;

constructor TElfDbgSource.Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean);
var
  p: PDbgImageSectionEx;
  idx: integer;
  i: Integer;
  fs: TElfSection;
begin
  FSections := TStringListUTF8Fast.Create;
  FSections.Sorted := True;
  //FSections.Duplicates := dupError;
  FSections.CaseSensitive := False;

  FFileLoader := ASource;
  fOwnSource := OwnSource;
  fElfFile := TElfFile.Create;
  fElfFile.LoadFromFile(ASource);

  for i := 0 to fElfFile.seccount - 1 do begin
    fs := fElfFile.sections[i];
    idx := FSections.AddObject(fs.name, nil);
    New(p);
    P^.Offs := fs.FileOfs;
    p^.Sect.Size := fs.Size;
    p^.Sect.VirtualAddress := 0; // Todo? fs.Address - ImageBase
    p^.Loaded := False;
    FSections.Objects[idx] := TObject(p);
  end;

  FTargetInfo := fElfFile.FTargetInfo;

  inherited Create(ASource, ADebugMap, OwnSource);
end;

destructor TElfDbgSource.Destroy;
begin
  if fOwnSource then FFileLoader.Free;
  fElfFile.Free;
  while FSections.Count > 0 do begin
    Freemem(FSections.Objects[0]);
    FSections.Delete(0);
  end;
  FreeAndNil(FSections);
  inherited Destroy;
end;

procedure TElfDbgSource.ParseSymbolTable(AFpSymbolInfo: TfpSymbolList);
var
  p: PDbgImageSection;
  ps: PDbgImageSection;
  SymbolArr32: PElf32symbolArray;
  SymbolArr64: PElf64symbolArray;
  SymbolStr: pointer;
  i: integer;
  SymbolCount: integer;
  SymbolName: AnsiString;
  SectIdx: Word;
  Sect: PElfSection;
begin
  AfpSymbolInfo.SetAddressBounds(1, High(AFpSymbolInfo.HighAddr)); // always search / TODO: iterate all sections for bounds
  p := Section[_symbol];
  ps := Section[_symbolstrings];
  if assigned(p) and assigned(ps) then
  begin
    SymbolStr:=PDbgImageSectionEx(ps)^.Sect.RawData;
    if FTargetInfo.Bitness = b64 then
    begin
      SymbolArr64:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(TElf64symbol);
      for i := 0 to SymbolCount-1 do
      begin
        begin
          {$push}
          {$R-}
          if SymbolArr64^[i].st_name<>0 then
            begin
            SectIdx := SymbolArr64^[i].st_shndx;
            if (SectIdx < 0) or (SectIdx >= fElfFile.seccount) then
              continue;
            Sect := @fElfFile.sections[SectIdx];
            if Sect^.Address = 0 then
              continue; // not loaded, symbol not in memory

            SymbolName:=pchar(SymbolStr+SymbolArr64^[i].st_name);
            AfpSymbolInfo.Add(SymbolName, TDbgPtr(SymbolArr64^[i].st_value+ImageBase),
              Sect^.Address + Sect^.Size);
            end;
          {$pop}
        end
      end;
    end
    else
    begin
      SymbolArr32:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(TElf32symbol);
      for i := 0 to SymbolCount-1 do
      begin
        begin
          if SymbolArr32^[i].st_name<>0 then
            begin
            SectIdx := SymbolArr32^[i].st_shndx;
            if (SectIdx < 0) or (SectIdx >= fElfFile.seccount) then
              continue;
            Sect := @fElfFile.sections[SectIdx];
            if Sect^.Address = 0 then
              continue; // not loaded, symbol not in memory

            SymbolName:=pchar(SymbolStr+SymbolArr32^[i].st_name);
            AfpSymbolInfo.Add(SymbolName, TDBGPtr(SymbolArr32^[i].st_value+ImageBase),
              Sect^.Address + Sect^.Size);
            end;
        end
      end;
    end;
  end;
end;

initialization
  RegisterImageReaderClass( TElfDbgSource );

end.


{
 This unit contains the types needed for reading PE images.

 This file was ported from DUBY. See svn log for details

 ---------------------------------------------------------------------------

 @created(Thu May 4th WET 2006)
 @lastmod($Date: 2009-01-16 03:26:10 +0300 (Пт, 16 янв 2009) $)
 @author(Marc Weustink <marc@@dommelstein.nl>)

 @modified by dmitry boyarintsev (july 2009:
   + removed Windows unit dependancy. added SectionCount and
   + added Sections access by Index

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
unit FpImgReaderWinPE;

{$mode objfpc}{$H+}

interface

uses
  Classes, {$ifdef windows}windows,{$endif} SysUtils, math,
  {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazUTF8,
  DbgIntfBaseTypes, LazFileUtils, crc,
  FpImgReaderBase, FpImgReaderWinPETypes, fpDbgSymTable;
  
type

  { TPEFileSource }

  TPEFileSource = class(TDbgImageReader)
  private
    FSections: TStringListUTF8Fast;
    FFileLoader : TDbgFileLoader;
    FOwnLoader  : Boolean;
    FCodeBase   : DWord;
  protected
    function GetSection(const AName: String): PDbgImageSection; override;
    function GetSection(const AVirtAddr: QWord): PDbgImageSection;
    function MapVirtAddressToSection(AVirtAddr: Pointer): Pointer;

    procedure LoadSections;
    procedure ClearSections;
  public
    class function isValid(ASource: TDbgFileLoader): Boolean; override;
    class function UserName: AnsiString; override;
  public
    constructor Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean); override;
    destructor Destroy; override;
    procedure ParseSymbolTable(AfpSymbolInfo: TfpSymbolList); override;
    procedure ParseLibrarySymbolTable(AFpSymbolInfo: TfpSymbolList); override;
  end;

implementation

uses
  FpDbgCommon;

const
  // Symbol-map section name
  _symbol        = '.symbols';
  _symbolstrings = '.symbolsstrings';

type
  PImageSymbolArray = ^TImageSymbolArray;
  TImageSymbolArray = array[0..maxSmallint] of TImageSymbol;

function isValidPEStream(ASource: TDbgFileLoader): Boolean;
var
  DosHeader: TImageDosHeader;
begin
  try
    Result := false;
    if ASource.Read(0, sizeof(DosHeader), @DosHeader) <> sizeof(DosHeader) then
      Exit;
    if (DosHeader.e_magic <> IMAGE_DOS_SIGNATURE) or (DosHeader.e_lfanew = 0) then 
      Exit;
    Result := true;
  except
    Result := false;
  end;
end;

constructor TPEFileSource.Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean);
var
  p: PDbgImageSectionEx;
  crc, c: cardinal;
  DbgFileName, SourceFileName: String;
  i, j: Integer;
  mem: Pointer;
  NewFileLoader: TDbgFileLoader;
begin
  FSections := TStringListUTF8Fast.Create;
  FSections.Sorted := False;  // need sections in original order / Symbols use "SectionNumber"
  //FSections.Duplicates := dupError;
  FSections.CaseSensitive := False;

  FFileLoader:=ASource;
  FOwnLoader:=OwnSource;
  LoadSections;
  // check external debug file
  p := PDbgImageSectionEx(Section['.gnu_debuglink']);
  if p <> nil then
  begin
    if IndexByte(p^.Sect.RawData^, p^.Sect.Size-4, 0) < p^.Sect.Size then
    begin
      DbgFileName := StrPas(PChar(PDbgImageSectionEx(p)^.Sect.RawData));
      i := align(length(DbgFileName)+1, 4);
      if (i+4) <= p^.Sect.Size then begin
        move((p^.Sect.RawData+i)^, crc, 4);

        SourceFileName := ASource.FileName;
        if SourceFileName<>'' then
          DbgFileName := ExtractFilePath(SourceFileName)+DbgFileName;
        if FileExists(DbgFileName) then
        begin
          NewFileLoader := TDbgFileLoader.Create(DbgFileName);

          i := FileSizeUtf8(DbgFileName) - 4096;
          j := 0;

          c:=0;
          while j < i do begin
            NewFileLoader.LoadMemory(j, 4096, mem);
            c:=Crc32(c, mem, 4096);
            NewFileLoader.UnloadMemory(mem);
            inc(j, 4096)
          end;
          i := i - j + 4096;
          NewFileLoader.LoadMemory(j, i, mem);
          c:=Crc32(c, mem, i);
          NewFileLoader.UnloadMemory(mem);

          debugln(crc <> c, ['Invalid CRC for ext debug info']);
          if crc = c then begin
            if FOwnLoader then
              FFileLoader.Free;

            FFileLoader := NewFileLoader;
            FOwnLoader := True;
            ClearSections;
            LoadSections;
          end
          else
            NewFileLoader.Free;
        end;
      end;
    end;
  end;
  inherited Create(ASource, ADebugMap, OwnSource);
end;

procedure TPEFileSource.ClearSections;
var
  i: Integer;
begin
  for i := 0 to FSections.Count-1 do
    Freemem(FSections.Objects[i]);
  FSections.Clear;
end;

destructor TPEFileSource.Destroy;  
begin
  if FOwnLoader then FFileLoader.Free;
  ClearSections;
  FSections.Free;
  inherited Destroy;  
end;

procedure TPEFileSource.ParseSymbolTable(AfpSymbolInfo: TfpSymbolList);
var
  p: PDbgImageSection;
  ps: PDbgImageSection;
  SymbolArr: PImageSymbolArray;
  SymbolStr: pointer;
  i,j: integer;
  SymbolCount: integer;
  SymbolName: AnsiString;
  SectNumber, SectCount: Integer;
  SectRVA: QWord;
begin
  AfpSymbolInfo.SetAddressBounds(ImageBase, ImageBase+ImageSize);
  p := Section[_symbol];
  ps := Section[_symbolstrings];
  if assigned(p) and assigned(ps) then
  begin
    SymbolArr:=PDbgImageSectionEx(p)^.Sect.RawData;
    SymbolStr:=PDbgImageSectionEx(ps)^.Sect.RawData;
    SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(TImageSymbol);
    SectCount := FSections.Count;
    {$PUSH}{$R-} // SymbolArr may be more than maxSmallInt
    for i := 0 to SymbolCount-1 do
    begin
      begin
        // Section-index is ignored for now...
        if SymbolArr^[i].N.Name.Short=0 then
          SymbolName:=pchar(SymbolStr+SymbolArr^[i].N.Name.Long)
        else
        begin
          SymbolName:='';
          if SymbolArr^[i].N.Name.Long<>0 then
          begin
            for j := 0 to sizeof(SymbolArr^[i].N.ShortName)-1 do
            begin
              if SymbolArr^[i].N.ShortName[j]=#0 then break;
              SymbolName:=SymbolName+SymbolArr^[i].N.ShortName[j];
            end;
          end;
        end;
        SectNumber := integer(SymbolArr^[i].SectionNumber) - 1;
        if (SectNumber >= 0) and (SectNumber < SectCount) then
          SectRVA := PDbgImageSectionEx(FSections.Objects[SectNumber])^.Sect.VirtualAddress
        else
          SectRVA := 0;
        AfpSymbolInfo.Add(SymbolName, TDBGPtr(SymbolArr^[i].Value+ImageBase+SectRVA));
      end
    end;
    {$POP}
  end;
end;

procedure TPEFileSource.ParseLibrarySymbolTable(AFpSymbolInfo: TfpSymbolList);
{$ifdef windows}
var
  hBase: PImageDosHeader;
  header64: PImageNtHeaders64;
  header32: PImageNtHeaders32;
  ExportSect: PIMAGE_EXPORT_DIRECTORY;
  ExportSize: DWord;
  NameCnt, FuncCnt: DWord;
  NameList, FuncList: PDWORD;
  OrdList: PWORD;
  i: Integer;
  NameAddr: PByte;
  FuncName: AnsiString;
  OrdVal: Word;
  FuncAddr: TDBGPtr;
{$ENDIF}
begin
  {$ifdef windows}
  if LoadedTargetImageAddr = 0 then
    exit;

  SetImageBase(LoadedTargetImageAddr);
  FFileLoader.LoadMemory(0, 1, hBase); // size does not matter, only obtain address
  if (hBase = nil) or (hBase^.e_magic <> IMAGE_DOS_SIGNATURE) then
    exit;

  if TargetInfo.bitness = b64 then begin
    header64 := PImageNtHeaders64(PByte(hBase) + hBase^.e_lfanew);
    if (header64^.Signature <> IMAGE_NT_SIGNATURE) or
       (header64^.OptionalHeader.NumberOfRvaAndSizes = 0)
    then
      exit;

    ExportSect := MapVirtAddressToSection(
      PIMAGE_EXPORT_DIRECTORY(PtrUInt(header64^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress))
    );
    ExportSize := header64^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].Size;
    SetImageSize(header64^.OptionalHeader.SizeOfImage);
  end
  else begin
    header32 := PImageNtHeaders32(PByte(hBase) + hBase^.e_lfanew);
    if (header32^.Signature <> IMAGE_NT_SIGNATURE) or
       (header32^.OptionalHeader.NumberOfRvaAndSizes = 0)
    then
      exit;

    ExportSect := MapVirtAddressToSection(
      PIMAGE_EXPORT_DIRECTORY(PtrUInt(header32^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress))
    );
    ExportSize := header32^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].Size;
    SetImageSize(header32^.OptionalHeader.SizeOfImage);
  end;
  AfpSymbolInfo.SetAddressBounds(ImageBase, ImageBase+ImageSize);

  if (ExportSect = nil) or (ExportSect^.AddressOfNames = 0) or (ExportSize = 0) then
    exit;

  NameCnt := ExportSect^.NumberOfNames;
  FuncCnt := ExportSect^.NumberOfFunctions;
  if (NameCnt = 0) or (FuncCnt = 0) then
    exit;

  NameList := MapVirtAddressToSection(PDWORD(PtrUInt(ExportSect^.AddressOfNames)));
  OrdList  := MapVirtAddressToSection( PWORD(PtrUInt(ExportSect^.AddressOfNameOrdinals)));
  FuncList := MapVirtAddressToSection(PDWORD(PtrUInt(ExportSect^.AddressOfFunctions)));
  if (NameList = nil) or (OrdList = nil) or (FuncList = nil) then
    exit;

  for i := 0 to NameCnt - 1 do begin
    NameAddr := MapVirtAddressToSection(PByte(PtrUInt(NameList[i])));
    if IndexByte(NameAddr^, 500, 0) < 0 then
      continue;
    FuncName := PChar(NameAddr);
    OrdVal := OrdList[i];

    if OrdVal >= FuncCnt then
      continue;

    FuncAddr := TDBGPtr(FuncList[OrdVal]);
    if FuncAddr = 0 then
      Continue;

    AFpSymbolInfo.Add(FuncName, LoadedTargetImageAddr + FuncAddr);
  end;
  {$ENDIF}
end;

function TPEFileSource.GetSection(const AName: String): PDbgImageSection;
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

function TPEFileSource.GetSection(const AVirtAddr: QWord): PDbgImageSection;
var
  i: Integer;
  ex: PDbgImageSectionEx;
begin
  for i := 0 to FSections.Count - 1 do begin
    ex := PDbgImageSectionEx(FSections.Objects[i]);
    Result := @ex^.Sect;
    if (Result^.VirtualAddress <= AVirtAddr) and
       (Result^.VirtualAddress + Result^.Size > AVirtAddr)
    then begin
      FFileLoader.LoadMemory(ex^.Offs, Result^.Size, Result^.RawData);
      exit;
    end;
  end;
  Result := nil;
end;

function TPEFileSource.MapVirtAddressToSection(AVirtAddr: Pointer): Pointer;
var
  Sect: PDbgImageSection;
begin
  (* AVirtAddress is a 32bit pointer (DWORD) as found in the mem mapped file.
     It will be mapped to the Address to which the file has been loaded. (native pointer)
  *)
  Result := nil;
  Sect := GetSection(QWord(AVirtAddr));
  if Sect = nil then
    exit;

  {$PUSH}{$R-}
  Result := (PByte(Sect^.RawData) + (QWord(AVirtAddr) - Sect^.VirtualAddress));
  {$POP}
end;

procedure TPEFileSource.LoadSections;

  procedure Add(const AName: String; ARawData: QWord; ASize: QWord; AVirtualAdress: QWord);
  var
    p: PDbgImageSectionEx;
    idx: integer;
  begin
    idx := FSections.AddObject(AName, nil);
    New(p);
    P^.Offs := ARawData;
    p^.Sect.Size := ASize;
    p^.Sect.VirtualAddress := AVirtualAdress;
    p^.Loaded := False;
    FSections.Objects[idx] := TObject(p);
  end;

var
  DosHeader: TImageDosHeader;
  NtHeaders: record
    case integer of
      1: (Sys: TImageNtHeaders;);
      2: (W32: TImageNtHeaders32;);
      3: (W64: TImageNtHeaders64;);
    end;
  SectionHeader: PImageSectionHeader;
  n, i: Integer;
  SectionName: array[0..IMAGE_SIZEOF_SHORT_NAME] of Char;
  SectionMax: QWord;
  s: string[255];
  StringTableLen: DWord;
  StringTableStart: QWord;
begin
  FTargetInfo.machineType := mtNONE;
  FTargetInfo.bitness     := bNone;
  FTargetInfo.byteOrder   := boNone;
  FTargetInfo.OS          := osNone;

  FFileLoader.Read(0, sizeof(DosHeader), @DosHeader);
  if (DosHeader.e_magic <> IMAGE_DOS_SIGNATURE)
  or (DosHeader.e_lfanew = 0)
  then begin
    //WriteLn('Invalid DOS header');
    Exit;
  end;

  FFileLoader.Read(DosHeader.e_lfanew, sizeof(NtHeaders), @NtHeaders);
  if NtHeaders.Sys.Signature <> IMAGE_NT_SIGNATURE
  then begin
    //WriteLn('Invalid NT header: ', IntToHex(NtHeaders^.Signature, 8));
    Exit;
  end;
  FTargetInfo.OS := osWindows;

  case NtHeaders.Sys.FileHeader.Machine of
    IMAGE_FILE_MACHINE_I386:
    begin
      FTargetInfo.machineType := mt386;
      FTargetInfo.byteOrder := boLSB;
    end;
    IMAGE_FILE_MACHINE_ARM:
    begin
      FTargetInfo.machineType := mtARM;
      FTargetInfo.byteOrder := boLSB;
    end;
    IMAGE_FILE_MACHINE_IA64, IMAGE_FILE_MACHINE_AMD64:
    begin
      FTargetInfo.machineType := mtX86_64;
      FTargetInfo.byteOrder := boLSB;
    end;
  else
    FTargetInfo.OS := osNone;
  end;

  case NtHeaders.Sys.OptionalHeader.Magic of
    IMAGE_NT_OPTIONAL_HDR32_MAGIC: FTargetInfo.Bitness := b32;
    IMAGE_NT_OPTIONAL_HDR64_MAGIC: FTargetInfo.Bitness := b64;
  else
    FTargetInfo.Bitness := bNone;
  end;

  if FTargetInfo.Bitness = b64 then begin
    SetImageBase(NtHeaders.W64.OptionalHeader.ImageBase);
    SetImageSize(NtHeaders.W64.OptionalHeader.SizeOfImage);
  end else begin
    SetImageBase(NtHeaders.W32.OptionalHeader.ImageBase);
    SetImageSize(NtHeaders.W32.OptionalHeader.SizeOfImage);
  end;
  FCodeBase := NtHeaders.W32.OptionalHeader.BaseOfCode;
  SectionMax := FFileLoader.LoadMemory(
    DosHeader.e_lfanew +
    (@NtHeaders.Sys.OptionalHeader - @NtHeaders.Sys) +
    NtHeaders.Sys.FileHeader.SizeOfOptionalHeader,
    SizeOf(TImageSectionHeader) * NtHeaders.Sys.FileHeader.NumberOfSections,
    SectionHeader
    )
    div SizeOf(TImageSectionHeader);
  if SectionMax <> NtHeaders.Sys.FileHeader.NumberOfSections then begin
    DebugLn(['Could not load all headers', NtHeaders.Sys.FileHeader.NumberOfSections, ' ', SectionMax]);
  end;

  for n := 0 to SectionMax - 1 do
  begin
    //SectionHeader := Pointer(@NtHeaders.Sys.OptionalHeader) +
    //                         NtHeaders.Sys.FileHeader.SizeOfOptionalHeader +
    //                         SizeOf(TImageSectionHeader) * n;
    // make a null terminated name
    Move(SectionHeader[n].Name, SectionName, IMAGE_SIZEOF_SHORT_NAME);
    SectionName[IMAGE_SIZEOF_SHORT_NAME] := #0;
    if (SectionName[0] = '/') and (SectionName[1] in ['0'..'9'])
    then begin
      // long name
      i := FFileLoader.Read(
        NTHeaders.Sys.FileHeader.PointerToSymbolTable +
        NTHeaders.Sys.FileHeader.NumberOfSymbols * IMAGE_SIZEOF_SYMBOL +
        StrToIntDef(PChar(@SectionName[1]), 0), 255, @s[1]);
      s[Min(i, 255)] := #0;
      Add(pchar(@s[1]), SectionHeader[n].PointerToRawData, SectionHeader[n].Misc.VirtualSize,  SectionHeader[n].VirtualAddress);
    end
    else begin
      // short name
      Add(SectionName, SectionHeader[n].PointerToRawData, SectionHeader[n].Misc.VirtualSize,  SectionHeader[n].VirtualAddress);
    end
  end;

  // Create a fake-sections for the symbol-table:
  if NtHeaders.Sys.FileHeader.PointerToSymbolTable<>0 then
    begin
    Add(_symbol,NtHeaders.Sys.FileHeader.PointerToSymbolTable, NtHeaders.Sys.FileHeader.NumberOfSymbols*IMAGE_SIZEOF_SYMBOL,0);
    StringTableStart:=NtHeaders.Sys.FileHeader.PointerToSymbolTable+NtHeaders.Sys.FileHeader.NumberOfSymbols*IMAGE_SIZEOF_SYMBOL;
    FFileLoader.Read(StringTableStart, sizeof(DWord), @StringTableLen);
    Add(_symbolstrings,StringTableStart, StringTableLen, 0);
    end;

  FFileLoader.UnloadMemory(SectionHeader);
end;

class function TPEFileSource.isValid(ASource: TDbgFileLoader): Boolean;
begin
  Result := isValidPEStream(ASource);
end;

class function TPEFileSource.UserName: AnsiString;
begin
  Result:='PE file';
end;


initialization
  RegisterImageReaderClass(TPEFileSource);

end.


unit FpImgReaderMacho;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs,
  LazFglHash, {$ifdef FORCE_LAZLOGGER_DUMMY} LazLoggerDummy {$else} LazLoggerBase {$endif}, LazFileUtils, LazUTF8,
  DbgIntfBaseTypes,
  // FpDebug
  macho, FpImgReaderMachoFile, FpImgReaderBase, fpDbgSymTable, FpDbgUtil;

type

  { TDbgMachoDataSource }

  TDbgMachoDataSource = class(TDbgImageReader)
  private
    fSource     : TDbgFileLoader;
    FSections: TStringListUTF8Fast;
    fSubFiles: TStringList;
    fAddressMapList: TDbgAddressMapList;
    fOwnSource  : Boolean;
    fFile       : TMachoFile;
    hasSymTable : Boolean;
    StabsCmd    : symtab_command;
    fileRead    : Boolean;
    function GetSectionInfo(const SectionName: AnsiString; var Size: int64): Boolean;
    function GetSectionData(const SectionName: AnsiString; Offset, {%H-}Size: Int64; var Buf: array of byte): Int64;
    procedure ParseMainAppleDwarfDataMap;
    procedure ParseSubAppleDwarfDataMap(ADebugMap: TObject);
  protected
    procedure ReadFile;
    function GetSubFiles: TStrings; override;
    function GetAddressMapList: TDbgAddressMapList; override;
    function GetSymTableSectionInfo({%H-}StabStr: Boolean; var {%H-}SectionOffset, {%H-}SectionSize: Int64): Boolean;
    function GetSectionIndex(const SectionName: AnsiString): Integer;

    function GetSection(const AName: String): PDbgImageSection; override;
  public
    class function isValid(ASource: TDbgFileLoader): Boolean; override;
    class function UserName: AnsiString; override;
    class procedure LoadSubFiles(ASubFiles: TStrings; ALoaderList: TFPObjectList);
    procedure AddSubFilesToLoaderList(ALoaderList: TObject; PrimaryLoader: TObject); override;
    procedure ParseSymbolTable(AfpSymbolInfo: TfpSymbolList); override;
  public
    constructor Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean); override;
    destructor Destroy; override;
  end;

implementation

uses
  FpDbgLoader, FpDbgCommon;

var
  DBG_VERBOSE, DBG_WARNINGS: PLazLoggerLogGroup;

type
  PnlistArray = ^nlist; // ^array[0..infinite] of nlist;
  PnlistArray64 = ^nlist_64; // ^array[0..infinite] of nlist_64;

const
  // Symbol-map section name
  _symbol        = '.symbols';
  _symbolstrings = '.symbolsstrings';

type
  TDebugTableState = (dtsDir, dtsSource, dtsObjectFile, dtsProc, dtsProcLen, dtsProcEnd, dtsEnd);
  TDebugTableEntry = record
    Dir: string;
    SourceFile: string;
    ObjectFile: string;
    ObjFileAge: longint;
    Offset: TDBGPtr;
  end;

  { TAppleDwarfDebugMap }

  TAppleDwarfDebugMap = class(TObject)
  private
    //FAddressMap: TDbgAddressMapList;
    FDir: string;
    FGlobalList: TDbgAddressMapHashList;
    FObjectFile: string;
    FObjFileAge: longint;
    FOffset: TDBGPtr;
    FSourceFile: string;
  public
    constructor create;
    destructor destroy; override;
    procedure clear;
    property Offset: TDBGPtr read FOffset write FOffset;
    property Dir: string read FDir write FDir;
    property ObjectFile: string read FObjectFile write FObjectFile;
    property SourceFile: string read FSourceFile write FSourceFile;
    property ObjFileAge: longint read FObjFileAge write FObjFileAge;
    // This list contains the locations for all symbols in the executable,
    // parsed from the 'stabs'-debuginfo in the executable.
    // This property is only available in the debug-map for the main
    // executable.
    property GlobalList: TDbgAddressMapHashList read FGlobalList;
    // This list maps addresses in an object-file to the addresses
    // in the main executable.
    // This property is only available in the debug-map for a specific
    // object-file.
    //property AddressMap: TDbgAddressMapList read FAddressMap;
  end;

function isValidMachoStream(ASource: TDbgFileLoader): Boolean;
var
  header  : mach_header;
begin
  try
    Result := Assigned(ASource);
    if not Result then Exit;
    Result := ASource.Read(0, sizeof(header), @header) = sizeof(header);
    if not Result then Exit;
    Result := (header.magic = MH_CIGAM) or (header.magic = MH_MAGIC) or
              (header.magic = MH_CIGAM_64) or (header.magic = MH_MAGIC_64);
  except
    Result := false;
  end;
end;

function FixMachoName(const macsectionname: String): String;
begin
  if Copy(macsectionName, 1, 2) = '__' then
    Result:= '.'+Copy(macsectionName, 3, length(macsectionName)-2)
  else
    Result := macsectionname;
end;

constructor TAppleDwarfDebugMap.create;
begin
  FGlobalList := TDbgAddressMapHashList.Create;
  //FAddressMap := TDbgAddressMapList.Create;
end;

destructor TAppleDwarfDebugMap.destroy;
begin
  //FAddressMap.Free;
  FGlobalList.Free;
  inherited destroy;
end;

procedure TAppleDwarfDebugMap.clear;
begin
  //FAddressMap.Clear;
  FDir := '';
  FGlobalList.Clear;
  FObjectFile := '';
  FObjFileAge := 0;
  FOffset := 0;
  FSourceFile := '';
end;

{ TDbgMachoDataSource }

class function TDbgMachoDataSource.isValid(ASource: TDbgFileLoader): Boolean;
begin
  Result := isValidMachoStream(ASource);
end;

class function TDbgMachoDataSource.UserName: AnsiString;
begin
  Result:='mach-o file';
end;

class procedure TDbgMachoDataSource.LoadSubFiles(ASubFiles: TStrings; ALoaderList: TFPObjectList);
var
  DwarfDebugMap: TAppleDwarfDebugMap;
  Loader: TDbgImageLoader;
  i: Integer;
begin
  if assigned(ASubFiles) then
    begin
    for i := 0 to ASubFiles.Count -1 do
      begin
      if (ASubFiles.Objects[i] is TAppleDwarfDebugMap) and FileExists(ASubFiles[i]) then
        begin
        DwarfDebugMap:=TAppleDwarfDebugMap(ASubFiles.Objects[i]);
        if FileAge(ASubFiles[i]) <> DwarfDebugMap.ObjFileAge then
          debugln(Format('The timestamp of the object-file "%s" does not correspond to the timestamp (%s) stored inside the executable. The debug-info in this file is not loaded.', [DwarfDebugMap.ObjectFile, DateTimeToStr(FileDatetoDateTime(DwarfDebugMap.ObjFileAge))]))
        else
          begin
          Loader := TDbgImageLoader.Create(DwarfDebugMap.ObjectFile, DwarfDebugMap);
          ALoaderList.Add(Loader);
          end;
        end
      else
        DebugLn('File with debug-info "'+DwarfDebugMap.ObjectFile+'" does not exist. This could lead to missing debug-information.');
      end;
    end;
end;

procedure TDbgMachoDataSource.ParseSymbolTable(AfpSymbolInfo: TfpSymbolList);
var
  p: PDbgImageSection;
  ps: PDbgImageSection;
  SymbolArr: PnlistArray;
  SymbolArr64: PnlistArray64;
  SymbolStr: pointer;
  SymbolType: uint8_t;
  StringOffset: uint32_t;
  SymbolValue: TDBGPtr;
  i: integer;
  SymbolCount: integer;
begin
  p := Section[_symbol];
  ps := Section[_symbolstrings];
  if assigned(p) and assigned(ps) then
  begin
    SymbolStr:=PDbgImageSectionEx(ps)^.Sect.RawData;
    if TargetInfo.Bitness = b64 then
      begin
        SymbolArr64:=PDbgImageSectionEx(p)^.Sect.RawData;
        SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist_64);
      end
      else
      begin
        SymbolArr:=PDbgImageSectionEx(p)^.Sect.RawData;
        SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist);
      end;
    for i := 0 to SymbolCount-1 do
    begin
      if TargetInfo.Bitness = b64 then
      begin
        SymbolType := SymbolArr64[i].n_type;
        StringOffset := SymbolArr64[i].n_un.n_strx;
        SymbolValue := SymbolArr64[i].n_value;
      end
      else
      begin
        SymbolType := SymbolArr[i].n_type;
        StringOffset := SymbolArr[i].n_un.n_strx;
        SymbolValue := SymbolArr[i].n_value;
      end;
      if (SymbolType and $e0)<>0 then
        // This is a stabs-entry. Ignore.
        Continue;
      if (SymbolType and $0e)=$e then
      begin
        // Section-index is ignored for now...
        AfpSymbolInfo.Add(pchar(SymbolStr+StringOffset), SymbolValue);
      end
    end;
  end;

end;

procedure TDbgMachoDataSource.ReadFile;
var
  i : Integer;
begin
  if Assigned(fFile) then fFile.Free;
  fFile:=TMachOFile.Create;
  fFile.LoadFromFile(fSource);
  for i := 0 to fFile.header.ncmds - 1 do begin
    hasSymTable := fFile.commands[i]^.cmd = LC_SYMTAB;
    if hasSymTable then begin
      StabsCmd := psymtab_command(fFile.commands[i])^;
      Break;
    end;
  end;
  FTargetInfo := fFile.TargetInfo;
  SetUUID(fFile.UUID);
  fileRead := true;
end;

function TDbgMachoDataSource.GetSubFiles: TStrings;
begin
  if not assigned(fSubFiles) then
    begin
    fSubFiles:=TStringList.Create;
    fSubFiles.OwnsObjects:=true;
    end;
  Result:=fSubFiles;
end;

function TDbgMachoDataSource.GetAddressMapList: TDbgAddressMapList;
begin
  if not assigned(fAddressMapList) then
    begin
    fAddressMapList:=TDbgAddressMapList.Create;
    end;
  Result:=fAddressMapList;
end;

function TDbgMachoDataSource.GetSymTableSectionInfo(StabStr: Boolean;
  var SectionOffset, SectionSize: Int64): Boolean;
begin
  Result := hasSymTable;
  if not Result then Exit;
  if StabStr then begin
    SectionOffset := StabsCmd.stroff;
    SectionSize := StabsCmd.strsize;
  end else begin
    SectionOffset := StabsCmd.symoff;
    if TargetInfo.Bitness = b64 then
      SectionSize := Int64(StabsCmd.nsyms * sizeof(nlist_64))
    else
      SectionSize := Int64(StabsCmd.nsyms * sizeof(nlist));
  end;
end;

function TDbgMachoDataSource.GetSectionIndex(const SectionName: AnsiString): Integer;
var
  i     : Integer;
  Name  : AnsiString;
begin
  //todo: hash-table
  for i := 0 to fFile.Sections.Count - 1 do begin
    with TMachoSection(fFile.sections[i]) do
      if is32
        then Name := FixMachoName(sec32.sectname)
        else Name := FixMachoName(sec64.sectname);
    if Name = SectionName then begin
      Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;

function TDbgMachoDataSource.GetSection(const AName: String): PDbgImageSection;
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
  fSource.LoadMemory(ex^.Offs, Result^.Size, Result^.RawData);
end;

procedure TDbgMachoDataSource.AddSubFilesToLoaderList(ALoaderList: TObject;
  PrimaryLoader: TObject);
var
  PLoader: TDbgImageLoader absolute PrimaryLoader;
  LList: TDbgImageLoaderList absolute ALoaderList;
  ALoader: TDbgImageLoader;
  fname, dSYMFilename: String;
  i: SizeInt;
begin
  // JvdS: Mach-O binaries do not contain DWARF-debug info. Instead this info
  // is stored inside the .o files, and the executable contains a map (in stabs-
  // format) of all these .o files. An alternative to parsing this map and reading
  // those .o files a dSYM-bundle could be used, which could be generated
  // with dsymutil.

  // PLoader.FileName in Contents/MacOS
  ALoader:=nil;

  fname := PLoader.FileName;
  i := pos('/Contents/MacOS', fname);
  if i > 0 then delete(fname, i, Length(fname));
  dSYMFilename:=ChangeFileExt(PLoader.FileName, '.dSYM');
  dSYMFilename:=dSYMFilename+'/Contents/Resources/DWARF/'+ExtractFileName(fname); // TDbgProcess.Name

  if FilenameExtIs(dSYMFilename,'.app',true) then
    dSYMFilename := ChangeFileExt(dSYMFilename,'');

  if FileExists(dSYMFilename) then
    begin
    ALoader := TDbgImageLoader.Create(dSYMFilename);
    if GUIDToString(ALoader.UUID)<>GUIDToString(PLoader.UUID) then
      begin
      AddReaderError('The unique UUID''s of the executable and the dSYM bundle with debug-info ('+dSYMFilename+') do not match.');
      debugln(DBG_WARNINGS, 'The unique UUID''s of the executable and the dSYM bundle with debug-info ('+dSYMFilename+') do not match.');
      FreeAndNil(ALoader);
      end
    else
      begin
      debugln(DBG_VERBOSE, 'Load debug-info from dSYM bundle ('+dSYMFilename+').');
      LList.Add(ALoader);
      end;
    end;

  if not assigned(ALoader) then
    begin
    debugln(DBG_VERBOSE, 'Read debug-info from separate object files.');
    TDbgMachoDataSource.LoadSubFiles(PLoader.SubFiles, LList);
    end;
end;

constructor TDbgMachoDataSource.Create(ASource: TDbgFileLoader; ADebugMap: TObject; OwnSource: Boolean);
const
  SymbolsSectionName : array [Boolean] of AnsiString = (_symbol, _symbolstrings);
var
  p: PDbgImageSectionEx;
  fs: TMachOsection;
  i: Integer;
  Name: String;
  soffset: int64;
  ssize: int64;
begin
  fSource := ASource;
  fOwnSource := OwnSource;

  ReadFile;

  FSections := TStringListUTF8Fast.Create;
  FSections.Sorted := True;
  FSections.Duplicates := dupAccept;
  FSections.CaseSensitive := False;

  for i := 0 to fFile.sections.Count - 1 do begin
    fs := TMachoSection(fFile.sections[i]);
    New(p);

    if fs.is32 then begin
      Name := FixMachoName(fs.sec32.sectname);
      P^.Offs := fs.sec32.offset;
      p^.Sect.Size := fs.sec32.size;
    end
    else begin
      Name := FixMachoName(fs.sec64.sectname);
      P^.Offs := fs.sec64.offset;
      p^.Sect.Size := fs.sec64.size;
    end;

    p^.Sect.VirtualAddress := 0; // Todo?
    p^.Loaded := False;
    FSections.AddObject(Name, TObject(p));
  end;

  if GetSymTableSectionInfo(false, soffset, ssize) then begin
    new(p);
    p^.Offs:=soffset;
    p^.Sect.Size:=ssize;
    p^.Sect.VirtualAddress:=0;
    p^.Loaded:=false;
    FSections.AddObject(SymbolsSectionName[false], TObject(p));
  end;

  if GetSymTableSectionInfo(true, soffset, ssize) then begin
    new(p);
    p^.Offs:=soffset;
    p^.Sect.Size:=ssize;
    p^.Sect.VirtualAddress:=0;
    p^.Loaded:=false;
    FSections.AddObject(SymbolsSectionName[true], TObject(p));
  end;

  if assigned(ADebugMap) then
    ParseSubAppleDwarfDataMap(ADebugMap)
  else
    ParseMainAppleDwarfDataMap;

  inherited Create(ASource, ADebugMap, OwnSource);
end;

destructor TDbgMachoDataSource.Destroy;
begin
  if assigned(fSubFiles) then
    fSubFiles.Free;
  if assigned(fAddressMapList) then
    fAddressMapList.Free;
  if Assigned(fFile) then fFile.Free;
  if fOwnSource then fSource.Free;
  while FSections.Count > 0 do begin
    Freemem(FSections.Objects[0]);
    FSections.Delete(0);
  end;
  FreeAndNil(FSections);
  inherited Destroy;
end;

{function TDbgMachoDataSource.SectionsCount: Integer;
begin
  if not Assigned(fFile) then ReadFile;
  Result := fFile.Sections.Count;
  if isStabs then inc(Result, 2);
end;

function TDbgMachoDataSource.GetSection(Index: Integer; var Name: AnsiString; var Size: Int64): Boolean;
var
  cnt   : Integer;
  sstr  : Boolean;
const
  StabSectionName : array [Boolean] of AnsiString = (_stab, _stabstr);
begin
  if not Assigned(fFile) then ReadFile;
  cnt := fFile.Sections.Count;
  if isStabs then inc(cnt, 2);
  Result := (Index >= 0) and (Index < cnt);
  if not Result then Exit;

  if Index < fFile.Sections.Count then begin
    with TMachoSection(fFile.sections[index]) do
      if is32 then begin
        Name := FixMachoName(sec32.sectname);
        Size := sec32.size;
      end else begin
        Name := FixMachoName(sec64.sectname);
        Size := sec64.size;
      end;
  end else begin
    sstr := Index = cnt - 1;
    Name := StabSectionName[sstr];
    Result := GetStabSectionInfo(sstr, Size);
  end;
end;

function TDbgMachoDataSource.GetSectionData(index: Integer; outStream: TStream): Boolean;
var
  ofs : Int64;
  sz  : Int64;
begin
  //todo: method will be removed
  if not Assigned(outStream) then begin
    Result := false;
    Exit;
  end;
  if not Assigned(fFile) then ReadFile;
  Result := (Index >= 0) and (Index < fFile.Sections.Count);
  if not Result then Exit;

  with TMachOsection(fFile.sections[index]) do begin
    if is32 then begin
      ofs := sec32.offset;
      sz := sec32.size;
    end else begin
      ofs := sec64.offset;
      sz := sec64.size;
    end;
  end;
  if ofs > 0 then begin
    fSource.Position:=ofs;
    outStream.CopyFrom(fSource, sz);
  end;
end;}

function TDbgMachoDataSource.GetSectionInfo(const SectionName: AnsiString; var Size: int64): Boolean;
var
  idx     : integer;
  symtablestr : Boolean;
  dummy   : int64;
begin
  if not fileRead then ReadFile;

  symtablestr := (SectionName = _symbolstrings);
  if symtablestr or (SectionName = _symbol) then
    Result := GetSymTableSectionInfo(symtablestr, dummy, Size)
  else begin
    idx := GetSectionIndex(SectionName);
    Result := idx >= 0;
    if not Result then Exit;

    with TMachOsection(fFile.sections[idx]) do
      if is32
        then Size := sec32.size
        else Size := sec64.size;
  end;
end;

function TDbgMachoDataSource.GetSectionData(const SectionName: AnsiString; Offset, Size: Int64; var Buf: array of byte): Int64;
var
  idx     : Integer;
  sofs    : int64;
  ssize   : int64;
  symstr : Boolean;
  sz      : Int64;
  s       : TMachOsection;
begin
  if not fileRead then ReadFile;

  Result := 0;
  symstr := SectionName = _symbolstrings;
  if symstr or (SectionName = _symbol)  then begin
    if not GetSymTableSectionInfo(symstr, sofs, ssize) then
      Exit;
  end else begin
    idx := GetSectionIndex(SectionName);
    s := TMachOsection(fFile.sections[idx]);
    if s.is32 then begin
      ssize := s.sec32.size;
      sofs := s.sec32.offset;
    end else begin
      sofs := s.sec64.offset;
      ssize := s.sec64.size;
    end;
  end;

  sz := ssize - Offset;
  if sz < 0 then Exit;

  //fSource.Position := sofs + Offset;
  //Result := fSource.Read(Buf[0], sz);
  Result := fSource.Read(sofs + Offset, sz, @Buf[0]);
end;

procedure TDbgMachoDataSource.ParseMainAppleDwarfDataMap;
var
  p: PDbgImageSection;
  ps: PDbgImageSection;
  SymbolArr: PnlistArray;
  SymbolArr64: PnlistArray64;
  SymbolStr: pointer;
  i: integer;
  SymbolCount: integer;
  SymbolType, SymbolSect: uint8_t;
  StringOffset: uint32_t;
  SymbolValue: QWord;
  State: TDebugTableState;
  AddressMap: TDbgAddressMap;
  ProcName: string;
  DwarfDebugMap: TAppleDwarfDebugMap;
  FullDwarfDebugMap: TDbgAddressMapPointerHashList;
  ind: THTCustomNode;
begin
  DwarfDebugMap:=nil;
  FullDwarfDebugMap := TDbgAddressMapPointerHashList.Create;
  p := Section[_symbol];
  ps := Section[_symbolstrings];
  if assigned(p) and assigned(ps) then
  begin
    SymbolStr:=PDbgImageSectionEx(ps)^.Sect.RawData;
    if TargetInfo.Bitness = b64 then
    begin
      SymbolArr64:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist_64);
    end
    else
    begin
      SymbolArr:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist);
    end;
    state := dtsEnd;
    for i := 0 to SymbolCount-1 do
    begin
      if TargetInfo.Bitness = b64 then
      begin
        SymbolType := SymbolArr64[i].n_type;
        StringOffset := SymbolArr64[i].n_un.n_strx;
        SymbolValue := SymbolArr64[i].n_value;
        SymbolSect := SymbolArr64[i].n_sect;
      end
      else
      begin
        SymbolType := SymbolArr[i].n_type;
        StringOffset := SymbolArr[i].n_un.n_strx;
        SymbolValue := SymbolArr[i].n_value;
        SymbolSect := SymbolArr[i].n_sect;
      end;
      case state of
        dtsEnd:
          begin
            if SymbolType = N_SO then
            begin
              if not assigned(DwarfDebugMap) then
                DwarfDebugMap := TAppleDwarfDebugMap.Create
              else
                DwarfDebugMap.clear;
              DwarfDebugMap.Dir := pchar(SymbolStr+StringOffset);
              state := dtsDir;
            end
            else if (SymbolType in [14,15]) then begin
              ind := FullDwarfDebugMap.Find(pchar(SymbolStr+StringOffset));
              if (ind <> nil) and (FullDwarfDebugMap.ItemPointerFromNode(ind)^.NewAddr = 0) then begin
                FullDwarfDebugMap.ItemPointerFromNode(ind)^.NewAddr := SymbolValue;
              end;
            end;
          end;
        dtsDir:
          begin
            if SymbolType = N_SO then
            begin
              DwarfDebugMap.SourceFile:=pchar(SymbolStr+StringOffset);
              inc(state);
            end
            else
              state := dtsEnd;
          end;
        dtsSource:
          begin
            if SymbolType = N_OSO then
            begin
              DwarfDebugMap.ObjectFile:=pchar(SymbolStr+StringOffset);
              DwarfDebugMap.ObjFileAge:=SymbolValue;
              inc(state);
            end;
          end;
        dtsObjectFile:
          begin
            if (SymbolType = N_BNSYM) then
            begin
              inc(state);
            end
            else if (SymbolType = N_STSYM) or (SymbolType = N_GSYM) then
            begin
              AddressMap.NewAddr:=SymbolValue;
              AddressMap.OrgAddr:=0;
              AddressMap.Length:=0;
              DwarfDebugMap.GlobalList.Add(pchar(SymbolStr+StringOffset), AddressMap);
              if (SymbolType = N_GSYM) and (SymbolValue = 0) then begin
                ind := DwarfDebugMap.GlobalList.Find(pchar(SymbolStr+StringOffset));
                FullDwarfDebugMap.Add(pchar(SymbolStr+StringOffset),
                  DwarfDebugMap.GlobalList.ItemPointerFromNode(ind));
              end;
            end
            else if (SymbolType = N_SO) and (SymbolSect=1) then
            begin
              state := dtsEnd;
              SubFiles.AddObject(DwarfDebugMap.ObjectFile, DwarfDebugMap);
              DwarfDebugMap:=nil;
            end;
          end;
        dtsProc:
          begin
            if (SymbolType = N_FUN) and (SymbolSect=1) then
            begin
              AddressMap.NewAddr:=SymbolValue;
              ProcName:=pchar(SymbolStr+StringOffset);
              inc(state);
            end;
          end;
        dtsProcLen:
          begin
            if (SymbolType = N_FUN) and (SymbolSect=0) then
            begin
              AddressMap.Length:=SymbolValue;
              inc(state);
            end;
          end;
        dtsProcEnd:
          begin
            if (SymbolType = N_ENSYM) and (SymbolSect=1) then
            begin
              DwarfDebugMap.GlobalList.Add(ProcName, AddressMap);
              state := dtsObjectFile;
            end;
          end;
      end;
    end;
  end;
  FullDwarfDebugMap.Free;
end;

procedure TDbgMachoDataSource.ParseSubAppleDwarfDataMap(ADebugMap: TObject);
var
  p: PDbgImageSection;
  ps: PDbgImageSection;
  SymbolArr: PnlistArray;
  SymbolArr64: PnlistArray64;
  SymbolStr: pointer;
  SymbolType: uint8_t;
  StringOffset: uint32_t;
  SymbolValue: QWord;
  i: integer;
  SymbolCount: integer;
  MainDwarfDebugMap: TAppleDwarfDebugMap;
  ind: THTCustomNode;
  AddressMap: TDbgAddressMap;
  s: string;
begin
  MainDwarfDebugMap:=TAppleDwarfDebugMap(ADebugMap);
  p := Section[_symbol];
  ps := Section[_symbolstrings];
  if assigned(p) and assigned(ps) then
  begin
    SymbolStr:=PDbgImageSectionEx(ps)^.Sect.RawData;
    if TargetInfo.Bitness = b64 then
    begin
      SymbolArr64:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist_64);
    end
    else
    begin
      SymbolArr:=PDbgImageSectionEx(p)^.Sect.RawData;
      SymbolCount := PDbgImageSectionEx(p)^.Sect.Size div sizeof(nlist);
    end;
    for i := 0 to SymbolCount-1 do
    begin
      if TargetInfo.Bitness = b64 then
      begin
        SymbolType := SymbolArr64[i].n_type;
        StringOffset := SymbolArr64[i].n_un.n_strx;
        SymbolValue := SymbolArr64[i].n_value;
      end
      else
      begin
        SymbolType := SymbolArr[i].n_type;
        StringOffset := SymbolArr[i].n_un.n_strx;
        SymbolValue := SymbolArr[i].n_value;
      end;
      if SymbolType = N_SECT then
      begin
        s := pchar(SymbolStr+StringOffset);
        ind := MainDwarfDebugMap.GlobalList.Find(s);
        if assigned(ind) then
          begin
            AddressMap:=MainDwarfDebugMap.GlobalList.ItemFromNode(ind);
            AddressMap.OrgAddr:=SymbolValue;
            AddressMapList.Add(AddressMap);
          end;
      end;
      if SymbolType = N_SECT+N_EXT then
      begin
        s := pchar(SymbolStr+StringOffset);
        ind := MainDwarfDebugMap.GlobalList.Find(s);
        if assigned(ind) then
          begin
            AddressMap:=MainDwarfDebugMap.GlobalList.ItemFromNode(ind);
            AddressMap.OrgAddr:=SymbolValue;
            AddressMapList.Add(AddressMap);
          end;
      end;
    end;
  end;
end;

initialization
  RegisterImageReaderClass( TDbgMachoDataSource );

  DBG_VERBOSE := DebugLogger.FindOrRegisterLogGroup('DBG_VERBOSE' {$IFDEF DBG_VERBOSE} , True {$ENDIF} );
  DBG_WARNINGS := DebugLogger.FindOrRegisterLogGroup('DBG_WARNINGS' {$IFDEF DBG_WARNINGS} , True {$ENDIF} );
end.


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

 Author: Balázs Székely
 Abstract:
   Implementation of the serializable package class. Information about the
   repository packages are stored in a json file. After the JSON is downloaded
   it gets serialized to a package list.}

unit opkman_serializablepackages;

{$mode objfpc}{$H+}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}
interface

uses
  Classes, SysUtils, Variants, contnrs, dateutils, fpjson, jsonparser, md5,
  // LazUtils
  FileUtil, Laz2_XMLCfg, LazFileUtils,
  // IdeIntf
  PackageDependencyIntf, PackageIntf,
  // OpkMan
  opkman_common, opkman_const, opkman_options;

type
  TPackageState = (
    psRepository,
    psDownloaded,
    psExtracted,
    psInstalled,
    psError);
  TPackageStates = set of TPackageState;

  TChangeType = (ctAdd, ctRemove);
  TSortType = (stName, stDate);
  TSortOrder = (soAscendent, soDescendent);

  {$M+}
  TPackageVersion = class(TPkgVersion)
  published
    property Major;
    property Minor;
    property Release;
    property Build;
    property IsNullVersion;
  end;
  {$M-}

  { TPackageDependency }

  TPackageDependency = class(TCollectionItem)
  private
    FMaxVersion: TPackageVersion;
    FMinVersion: TPackageVersion;
    FPkgFileName: String;
    procedure SetMinVersion(const AValue: TPackageVersion);
    procedure SetMaxVersion(const AValue: TPackageVersion);
  public
    procedure Assign(ASource: TPersistent); override;
    constructor Create(ACollection: TCollection); override;
    destructor Destroy; override;
  published
    property PkgFileName: String read FPkgFileName write FPkgFileName;
    property MinVersion: TPackageVersion read FMinVersion write SetMinVersion;
    property MaxVersion: TPackageVersion read FMaxVersion write SetMaxVersion;
  end;

  { TPackageDependencies }

  TPackageDependencies = class(TCollection)
  private
    function GetDependency(AIndex: Integer): TPackageDependency;
    procedure SetDependency(AIndex: Integer; const AValue: TPackageDependency);
  public
    function GetDependenciesAsString(const AIsDisplayString: Boolean): String;
    procedure SetDependenciesAsString(const AValue: String);
    property Dependencies[AIndex: Integer]: TPackageDependency read GetDependency write SetDependency; default;
  end;

  { TLazarusPackage }

  TLazarusPackage = class(TCollectionItem)
  private
    FName: String;
    FDescription: String;
    FAuthor: String;
    FLicense: String;
    FPackageState: TPackageState;
    FPackageStates: TPackageStates;
    FPackageType: TLazPackageType;
    FLazCompatibility: String;
    FFPCCompatibility: String;
    FSupportedWidgetSet: String;
    FPackageRelativePath: String;
    FPackageAbsolutePath: String;
    FInstalledFileName: String;
    FInstalledFileVersion: String;
    FInstalledFileDescription: String;
    FInstalledFileLincese: String;
    FUpdateVersion: String;
    FForceNotify: Boolean;
    FInternalVersion: Integer;
    FInternalVersionOld: Integer;
    FHasUpdate: Boolean;
    FVersion: TPackageVersion;
    FVersionAsString: String;
    FDependencies: TPackageDependencies;
    FDependenciesAsString: String;
    FChecked: Boolean;
    FIsDependencyPackage: Boolean;
    function GetVersionAsString: String;
    function GetDependenciesAsString: String;
    procedure SetVersionAsString(const AValue: String);
    procedure SetDependenciesAsString(const AValue: String);
    function GetInstallable: Boolean;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
  public
    procedure RefreshHasUpdate;
    property Version: TPackageVersion read FVersion write FVersion;
    property Dependencies: TPackageDependencies read FDependencies write FDependencies;
    property PackageStates: TPackageStates read FPackageStates write FPackageStates;
    property PackageState: TPackageState read FPackageState write FPackageState;
    property InstalledFileName: String read FInstalledFileName write FInstalledFileName;
    property InstalledFileVersion: String read FInstalledFileVersion write FInstalledFileVersion;
    property UpdateVersion: String read FUpdateVersion write FUpdateVersion;
    property PackageAbsolutePath: String read FPackageAbsolutePath write FPackageAbsolutePath;
    property Checked: Boolean read FChecked write FChecked;
    property IsDependencyPackage: Boolean read FIsDependencyPackage write FIsDependencyPackage;
    property IsInstallable: Boolean read GetInstallable;
    property ForceNotify: Boolean read FForceNotify write FForceNotify;
    property InternalVersion: Integer read FInternalVersion write FInternalVersion;
    property InternalVersionOld: Integer read FInternalVersionOld write FInternalVersionOld;
    property HasUpdate: Boolean read FHasUpdate write FHasUpdate;
    property InstalledFileDescription: String read FInstalledFileDescription write FInstalledFileDescription;
    property InstalledFileLincese: String read FInstalledFileLincese write FInstalledFileLincese;
  published
    property Name: String read FName write FName;
    property Author: String read FAuthor write FAuthor;
    property Description: String read FDescription write FDescription;
    property PackageRelativePath: string read FPackageRelativePath write FPackageRelativePath;
    property VersionAsString: String read GetVersionAsString write SetVersionAsString;
    property LazCompatibility: String read FLazCompatibility write FLazCompatibility;
    property FPCCompatibility: String read FFPCCompatibility write FFPCCompatibility;
    property SupportedWidgetSet: String read FSupportedWidgetSet write FSupportedWidgetSet;
    property PackageType: TLazPackageType read FPackageType write FPackageType;
    property License: String read FLicense write FLicense;
    property DependenciesAsString: String read GetDependenciesAsString write SetDependenciesAsString;
  end;

  {TMetaPackage}

  TMetaPackage = class(TCollectionItem)
  private
    FName: String;
    FDisplayName: String;
    FCategory: String;
    FCommunityDescription: String;
    FExternalDependencies: String;
    FOrphanedPackage: Integer;
    FRepositoryFileName: String;
    FRepositoryFileSize: Int64;
    FRepositoryFileHash: String;
    FChecked: Boolean;
    FIsDependencyPackage: Boolean;
    FRepositoryDate: TDateTime;
    FPackageState: TPackageState;
    FPackageStates: TPackageStates;
    FPackageBaseDir: String;
    FHomePageURL: String;
    FDownloadURL: String;
    FDownloadZipURL: String;
    FHasUpdate: Boolean;
    FDisableInOPM: Boolean;
    FSVNURL: String;
    FUpdateSize: Int64;
    FIsDirZipped: Boolean;
    FZippedBaseDir: String;
    FRating: Integer;
    FLazarusPackages: TCollection;
    function GetDownloadable: Boolean;
    function GetExtractable: Boolean;
  public
    constructor Create; reintroduce;
    destructor Destroy; override;
    procedure ChangePackageStates(const AChangeType: TChangeType; APackageState: TPackageState);
    function FindLazarusPackage(const APackageName: String): TLazarusPackage;
  public
    property PackageStates: TPackageStates read FPackageStates;
    property PackageState: TPackageState read FPackageState;
    property IsDownloadable: Boolean read GetDownloadable;
    property IsExtractable: Boolean read GetExtractable;
    property UpdateSize: Int64 read FUpdateSize write FUpdateSize;
    property IsDirZipped: Boolean read FIsDirZipped write FIsDirZipped;
    property ZippedBaseDir: String read FZippedBaseDir write FZippedBaseDir;
    property DownloadZipURL: String read FDownloadZipURL write FDownloadZipURL;
    property HasUpdate: Boolean read FHasUpdate write FHasUpdate;
    property DisableInOPM: Boolean read FDisableInOPM write FDisableInOPM;
    property Rating: Integer read FRating write FRating;
  published
    property Name: String read FName write FName;
    property DisplayName: String read FDisplayName write FDisplayName;
    property Category: String read FCategory write FCategory;
    property CommunityDescription: String read FCommunityDescription write FCommunityDescription;
    property ExternalDependecies: String read FExternalDependencies write FExternalDependencies;
    property OrphanedPackage: Integer read FOrphanedPackage write FOrphanedPackage;
    property Checked: Boolean read FChecked write FChecked;
    property IsDependencyPackage: Boolean read FIsDependencyPackage write FIsDependencyPackage;
    property RepositoryFileName: String read FRepositoryFileName write FRepositoryFileName;
    property RepositoryFileSize: int64 read FRepositoryFileSize write FRepositoryFileSize;
    property RepositoryFileHash: String read FRepositoryFileHash write FRepositoryFileHash;
    property RepositoryDate: TDateTime read FRepositoryDate write FRepositoryDate;
    property PackageBaseDir: String read FPackageBaseDir write FPackageBaseDir;
    property LazarusPackages: TCollection read FLazarusPackages write FLazarusPackages;
    property HomePageURL: String read FHomePageURL write FHomePageURL;
    property DownloadURL: String read FDownloadURL write FDownloadURL;
    property SVNURL: String read FSVNURL write FSVNURL;
  end;

  { TSerializablePackages }

  TFindPackageBy = (fpbPackageName, fpbRepositoryFilename);

  TSerializablePackages = class
  private
    FMetaPackages: TCollection;
    FLastError: String;
    FOnProcessJSON: TNotifyEvent;
    FOnUpdatePackageLinks: TNotifyEvent;
    FUpdates: String;
    function GetCount: Integer;
    function GetDownloadCount: Integer;
    function GetExtractCount: Integer;
    function GetInstallCount: Integer;
    function GetItem(const AIndex: Integer): TMetaPackage;
    procedure SetItem(const AIndex: Integer; const AMetaPackage: TMetaPackage);
    procedure DoGetPackageDependencies(const APkgFileName: String; ASL: TStringList; ALevel: Integer);
    function JSONToPackageData(const APackageData: TJSONData; var AMetaPackage: TMetaPackage): Boolean;
    function JSONToLazarusPackages(const APackageData: TJSONData; var AMetaPackage: TMetaPackage): Boolean;
    function PackageDataToJSON(AMetaPackage: TMetaPackage; var APackageData: TJSONObject): Boolean;
    function LazarusPackagesToJSON(AMetaPackage: TMetaPackage; var ALazarusPkgsArr: TJSONArray): Boolean;
    function IsPackageDownloaded(const AMetaPackage: TMetaPackage): Boolean;
    function IsPackageExtracted(const AMetaPackage: TMetaPackage): Boolean;
    function IsPackageInstalled(const ALazarusPkg: TLazarusPackage; const APackageBaseDir: String): Boolean;
    function AtLeastOneLazPkgInstalled(const AMetaPackage: TMetaPackage): Boolean;
    function GetPackageVersion(const APath: String): String;
    function GetPackageDescription(const APath: String): String;
    function GetPackageLicense(const APath: String): String;
    procedure LoadUpdateInfo;
    procedure SaveUpdateInfo;
  public
    constructor Create;
    destructor Destroy; override;
  public
    procedure Clear;
    function AddMetaPackage(const AName: String): TMetaPackage;
    procedure DeletePackage(const AIndex: Integer);
    function AddPackageFromJSON(JSON: TJSONStringType): Boolean;
    function FindMetaPackage(const AValue: String; const AFindPackageBy: TFindPackageBy): TMetaPackage;
    function FindMetaPackageByLazarusPackage(const ALazarusPackage: TLazarusPackage): TMetaPackage;
    function FindPackageIndex(const AValue: String; const AFindPackageBy: TFindPackageBy): Integer;
    function FindLazarusPackage(const APackageName: String): TLazarusPackage;
    function JSONToPackages(JSON: TJSONStringType): Boolean;
    function PackagesToJSON(var JSON: TJSONStringType): Boolean;
    procedure GetPackageDependencies(const APkgFileName: String; List: TObjectList; Recurse, OnlyUnresolved: Boolean);
    procedure GetPackageStates;
    procedure RemoveErrorState;
    procedure RemoveCheck;
    procedure MarkRuntimePackages;
    function Cleanup: Integer;
    function IsDependencyOk(PackageDependency: TPackageDependency; DependencyPackage: TLazarusPackage): Boolean;
    function IsInstalledVersionOk(PackageDependency: TPackageDependency; InstalledVersion: String): Boolean;
    function GetPackageInstallState(const AMetaPackage: TMetaPackage): Integer; overload;
    procedure DeleteDownloadedZipFiles;
    procedure Sort(const ASortType: TSortType; const ASortOrder: TSortOrder);
    function QuickStatistics: String;
  public
    property Count: Integer read GetCount;
    property DownloadCount: Integer read GetDownloadCount;
    property ExtractCount: Integer read GetExtractCount;
    property InstallCount: Integer read GetInstallCount;
    property Items[Index: Integer]: TMetaPackage read GetItem write SetItem;
    property LastError: String read FlastError;
    property OnProcessJSON: TNotifyEvent read FOnProcessJSON write FOnProcessJSON;
    property OnUpdatePackageLinks: TNotifyEvent read FOnUpdatePackageLinks write FOnUpdatePackageLinks;
  end;

var
  SerializablePackages: TSerializablePackages = nil;


implementation

{ TPackageDependency }

procedure TPackageDependency.SetMinVersion(const AValue: TPackageVersion);
begin
  FMinVersion.Assign(AValue);
end;

procedure TPackageDependency.SetMaxVersion(const AValue: TPackageVersion);
begin
  FMaxVersion.Assign(AValue);
end;

procedure TPackageDependency.Assign(ASource: TPersistent);
var
  Source: TPackageDependency;
begin
  if ASource is TPackageDependency then
  begin
    Source := ASource as TPackageDependency;
    FPkgFileName := Source.PkgFileName;
    if Assigned(Source.MinVersion) then
      FMinVersion.Assign(Source.MinVersion);
    if Assigned(Source.MaxVersion) then
      FMaxVersion.Assign(Source.MaxVersion);
  end
  else
    inherited Assign(Source);
end;

constructor TPackageDependency.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);
  FMinVersion := TPackageVersion.Create;
  FMaxVersion := TPackageVersion.Create;
end;

destructor TPackageDependency.Destroy;
begin
  if Assigned(FMinVersion) then
    FMinVersion.Free;
  if Assigned(fMaxVersion) then
    FMaxVersion.Free;
  inherited Destroy;
end;

{ TPackageDependencies }

function TPackageDependencies.GetDependency(AIndex: Integer): TPackageDependency;
begin
  Result := TPackageDependency(Items[AIndex]);
end;

procedure TPackageDependencies.SetDependency(AIndex: Integer;
  const AValue: TPackageDependency);
begin
  Items[AIndex] := AValue;
end;

function TPackageDependencies.GetDependenciesAsString(const AIsDisplayString: Boolean): String;
var
  I: Integer;
  MinVer, MaxVer: String;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    MinVer := '';
    MaxVer := '';
    if not Dependencies[I].FMinVersion.IsNullVersion then
    begin
      if AIsDisplayString then
        MinVer := '(>=' + IntToStr(Dependencies[I].FMinVersion.Major) + '.' + IntToStr(Dependencies[I].FMinVersion.Minor) + ')'
      else
        MinVer := '(' + Dependencies[I].FMinVersion.AsString + ')';
    end;
    if not Dependencies[I].FMaxVersion.IsNullVersion then
    begin
      if AIsDisplayString then
        MaxVer := '(<=' + IntToStr(Dependencies[I].FMaxVersion.Major) + '.' + IntToStr(Dependencies[I].FMaxVersion.Minor) + ')'
      else
        MaxVer := '(' + Dependencies[I].FMaxVersion.AsString + ')'
    end;
    if Result = '' then
      Result := Dependencies[I].PkgFileName + MinVer + MaxVer
    else
      Result := Result + ', ' + Dependencies[I].PkgFileName + MinVer + MaxVer;
  end;
end;

procedure TPackageDependencies.SetDependenciesAsString(const AValue: String);
var
  PackageDependency: TPackageDependency;
  SL: TStringList;
  P1, P2: Integer;
  Str: String;
  I: Integer;
begin
  SL := TStringList.Create;
  try
    SL.Delimiter := ',';
    SL.DelimitedText := AValue;
    for I := 0 to SL.Count - 1  do
    begin
      Str := Trim(SL.Strings[I]);
      PackageDependency := TPackageDependency(Self.Add);
      if not Assigned(PackageDependency.FMinVersion) then
        PackageDependency.FMinVersion := TPackageVersion.Create;
      if not Assigned(PackageDependency.FMaxVersion) then
        PackageDependency.FMaxVersion := TPackageVersion.Create;
      P1 := Pos('(', Str);
      P2 := Pos(')', Str);
      if (P1 <> 0) and (P2 <> 0) then
      begin
        PackageDependency.PkgFileName := Trim(Copy(Str, 1, P1 - 1));
        PackageDependency.FMinVersion.AsString := Trim(Copy(Str, P1 + 1, P2 - P1 - 1));
        System.Delete(Str, 1, P2);
        if Length(Trim(Str)) > 0 then
          PackageDependency.FMaxVersion.AsString := Trim(Copy(Str, 2, Length(Str) - 2));
      end
      else
        PackageDependency.PkgFileName := Trim(Str);
    end;
  finally
    SL.Free;
  end;
end;

{ TLazarusPackage }

function TLazarusPackage.GetVersionAsString: String;
begin
  Result := IntToStr(FVersion.Major) + '.' + IntToStr(FVersion.Minor) + '.' +
            IntToStr(FVersion.Release) + '.' + IntToStr(FVersion.Build);
end;

procedure TLazarusPackage.SetVersionAsString(const AValue: String);
begin
  if not Assigned(FVersion) then
  begin
    if not Assigned(FVersion) then
      FVersion := TPackageVersion.Create;
    FVersion.AsString := AValue;
  end;
  FVersionAsString := AValue;
end;

function TLazarusPackage.GetDependenciesAsString: String;
begin
  Result := FDependencies.GetDependenciesAsString(False);
end;

procedure TLazarusPackage.SetDependenciesAsString(const AValue: String);
begin
  if not Assigned(FDependencies) then
  begin
    FDependencies := TPackageDependencies.Create(TPackageDependency);
    FDependencies.SetDependenciesAsString(AValue);
  end;
  FDependenciesAsString := AValue;
end;

function TLazarusPackage.GetInstallable: Boolean;
begin
  case PackageAction of
     paDownloadTo:
       Result := False;
     paInstall, paUpdate:
       Result := (Checked) and
                 (psExtracted in PackageStates) and
                 (not (psError in PackageStates));
   end;
end;

constructor TLazarusPackage.Create;
begin
  FVersion := TPackageVersion.Create;
  FVersion.Clear;
  PackageStates := [];
  FDependencies := TPackageDependencies.Create(TPackageDependency);
end;

destructor TLazarusPackage.Destroy;
begin
  if Assigned(FVersion) then
    FreeAndNil(FVersion);
  if Assigned(FDependencies) then
    FreeAndNil(FDependencies);
  inherited Destroy;
end;

procedure TLazarusPackage.RefreshHasUpdate;
begin
  FHasUpdate := (FUpdateVersion <> '') and (FInstalledFileVersion <> '') and
     (
       ((not FForceNotify) {and (FUpdateVersion > FInstalledFileVersion)}) or
       ((FForceNotify) and (FInternalVersion > FInternalVersionOld))
     );
end;

{ TMetaPackage }
function TMetaPackage.GetDownloadable: Boolean;
begin
  case PackageAction of
    paDownloadTo, paUpdate:
      Result := (Checked) and (not (psError in PackageStates));
    paInstall:
      Result := (Checked) and
                (psRepository in PackageStates) and
                (not (psError in PackageStates)) and
                ((Options.ForceDownloadAndExtract) or ((not (psDownloaded in PackageStates)) and (not (psExtracted in PackageStates))));
  end;
end;

function TMetaPackage.GetExtractable: Boolean;
begin
  case PackageAction of
     paDownloadTo, paUpdate:
       Result := (Checked) and (not (psError in PackageStates));
     paInstall:
       Result := (Checked) and
                 (psDownloaded in PackageStates) and
                 (not (psError in PackageStates)) and
                 ((Options.ForceDownloadAndExtract) or ((not (psExtracted in PackageStates)) and (not (psInstalled in PackageStates))));
   end;
end;

constructor TMetaPackage.Create;
begin
  FLazarusPackages := TCollection.Create(TLazarusPackage);
end;

destructor TMetaPackage.Destroy;
var
  I: Integer;
begin
  FLazarusPackages.Clear;
  for I := FLazarusPackages.Count - 1 downto 0  do
    FLazarusPackages.Items[I].Free;
  FLazarusPackages.Free;
  inherited Destroy;
end;

procedure TMetaPackage.ChangePackageStates(const AChangeType: TChangeType;
  APackageState: TPackageState);
var
  I: Integer;
  LazarusPkg: TLazarusPackage;
begin
  if APackageState = psInstalled then
    Exit;
  //propagate states to package files
  case AChangeType of
    ctAdd:
      begin
        FPackageStates := FPackageStates + [APackageState];
        for I := 0 to LazarusPackages.Count - 1 do
        begin
          LazarusPkg := TLazarusPackage(LazarusPackages.Items[I]);
          LazarusPkg.PackageStates := LazarusPkg.PackageStates + [APackageState];
          LazarusPkg.PackageState := APackageState;
        end;
      end;
    ctRemove:
      begin
        FPackageStates := FPackageStates - [APackageState];
        for I := 0 to LazarusPackages.Count - 1 do
        begin
          LazarusPkg := TLazarusPackage(LazarusPackages.Items[I]);
          LazarusPkg.PackageStates := LazarusPkg.PackageStates - [APackageState];
        end;
      end;
  end;
end;

function TMetaPackage.FindLazarusPackage(const APackageName: String): TLazarusPackage;
var
  I: Integer;
begin
  for I := 0 to FLazarusPackages.Count - 1 do
  begin
    Result := TLazarusPackage(FLazarusPackages.Items[I]);
    if CompareText(Result.Name, APackageName) = 0 then
      Exit;
  end;
  Result := nil;
end;

{ TSerializablePackages }

constructor TSerializablePackages.Create;
begin
  FMetaPackages := TCollection.Create(TMetaPackage);
  FUpdates := Format(LocalRepositoryUpdatesFile, [MD5Print(MD5String(Options.RemoteRepository[Options.ActiveRepositoryIndex]))]);
end;

destructor TSerializablePackages.Destroy;
begin
  if Count > 0 then
    SaveUpdateInfo;
  Clear;
  FMetaPackages.Free;
  inherited Destroy;
end;

procedure TSerializablePackages.Clear;
var
  I: Integer;
begin
  for I := Count - 1 downto 0 do
    Items[I].Free;
  FMetaPackages.Clear;
end;

function TSerializablePackages.GetCount: Integer;
begin
  Result := FMetaPackages.Count;
end;

function TSerializablePackages.GetDownloadCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].IsDownloadable then
      Inc(Result);
end;

function TSerializablePackages.GetExtractCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if Items[I].IsExtractable then
      Inc(Result);
end;

function TSerializablePackages.GetInstallCount: Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
      if TLazarusPackage(Items[I].FLazarusPackages.Items[J]).IsInstallable then
        Inc(Result);
end;

function TSerializablePackages.GetItem(const AIndex: Integer): TMetaPackage;
begin
  if AIndex > FMetaPackages.Count - 1 then
    Exit(nil);
  Result := TMetaPackage(FMetaPackages.Items[AIndex]);
end;

procedure TSerializablePackages.SetItem(const AIndex: Integer; const AMetaPackage: TMetaPackage);
begin
  if AIndex > FMetaPackages.Count - 1 then
    Exit;
  FMetaPackages.Items[AIndex] := AMetaPackage;
end;

procedure TSerializablePackages.DoGetPackageDependencies(const APkgFileName: String;
  ASL: TStringList; ALevel: Integer);
var
  LazarusPkg: TLazarusPackage;
  D2, D1: TPackageDependency;
  I, J: Integer;
begin
  if (ALevel > 10) then
    Exit;
  LazarusPkg := FindLazarusPackage(APkgFileName);
  if LazarusPkg = nil then
    Exit;
  for I := 0 to LazarusPkg.Dependencies.Count - 1 do
  begin
    D1 := LazarusPkg.Dependencies[I];
    J := ASL.IndexOf(APkgFileName);
    If J = -1 then
    begin
      D2 := TPackageDependency.Create(nil);
      D2.Assign(D1);
      ASL.AddObject(D2.PkgFileName, D2);
    end
    else
    begin
      D2 := ASL.Objects[J] as TPackageDependency;
      if D1.MinVersion.Compare(D2.MinVersion) > 0 then
        D2.MinVersion.Assign(D1.MinVersion);
    end;
    if (ALevel >= 0) and (J = -1) Then
      DoGetPackageDependencies(D2.PkgFileName, ASL, ALevel + 1);
  end;
end;

function TSerializablePackages.AddMetaPackage(const AName: String): TMetaPackage;
var
  MetaPackage: TMetaPackage;
begin
  MetaPackage := FindMetaPackage(AName, fpbPackageName);
  if MetaPackage <> nil then
  begin
    FLastError := rsMainFrm_PackageNameAlreadyExists;
    Exit(nil);
  end;
  Result := TMetaPackage(FMetaPackages.Add);
  Result.FLazarusPackages := TCollection.Create(TLazarusPackage);
  Result.Name := AName;
end;

procedure TSerializablePackages.DeletePackage(const AIndex: Integer);
begin
  if AIndex > FMetaPackages.Count - 1 then
    Exit;
  FMetaPackages.Delete(AIndex);
end;

function TSerializablePackages.AddPackageFromJSON(JSON: TJSONStringType): Boolean;
var
  Data: TJSONData;
  Parser: TJSONParser;
  I: Integer;
  MetaPackage: TMetaPackage;
begin
  if Trim(JSON) = '' then
    Exit(False);
  Result := True;
  Parser := TJSONParser.Create(JSON){%H-};
  try
    Data := Parser.Parse;
    try
      MetaPackage := nil;
      try
        if Data.JSONType = jtObject then
        begin
          for I := 0 to Data.Count - 1 do
          begin
            if Data.Items[I].JSONType = jtObject then
            begin
              if not JSONToPackageData(Data.Items[I], MetaPackage) then
                Result := False;
            end
            else if Data.Items[I].JSONType = jtArray then
            begin
              if not JSONToLazarusPackages(Data.Items[I], MetaPackage) then
                Result := False;
            end;
          end;
        end;
      except
        Result := False;
      end;
    finally
      Data.Free;
    end;
  finally
    Parser.Free;
  end;
end;

function TSerializablePackages.FindMetaPackage(const AValue: String;
  const AFindPackageBy: TFindPackageBy): TMetaPackage;
var
  I: Integer;
  S: String;
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    case AFindPackageBy of
      fpbPackageName:        S := Items[I].Name;
      fpbRepositoryFilename: S := Items[I].RepositoryFileName;
    end;
    if CompareText(S, AValue) = 0 then
      Exit(Items[I]);
  end;
end;

function TSerializablePackages.FindMetaPackageByLazarusPackage(
  const ALazarusPackage: TLazarusPackage): TMetaPackage;
var
  I, J: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      if ALazarusPackage.Equals(TLazarusPackage(Items[I].FLazarusPackages.Items[J])) then
      begin
        Result := Items[I];
        Break;
      end;
    end;
  end;
end;

function TSerializablePackages.FindPackageIndex(const AValue: String;
  const AFindPackageBy: TFindPackageBy): Integer;
var
  I: Integer;
  S: String;
begin
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    case AFindPackageBy of
      fpbPackageName:        S := Items[I].Name;
      fpbRepositoryFilename: S := Items[I].RepositoryFileName;
    end;
    if S = AValue then
      Exit(I);
  end;
end;

function TSerializablePackages.FindLazarusPackage(const APackageName: String): TLazarusPackage;
var
  I, J: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
  begin
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      if CompareText(TLazarusPackage(Items[I].FLazarusPackages.Items[J]).Name, APackageName) = 0 then
      begin
        Result := TLazarusPackage(Items[I].FLazarusPackages.Items[J]);
        Break;
      end;
    end;
  end;
end;

function TSerializablePackages.JSONToPackageData(const APackageData: TJSONData;
  var AMetaPackage: TMetaPackage): Boolean;
var
  PackageData: TJSONObject;
begin
  Result := True;
  try
    PackageData := TJSONObject(APackageData);
    AMetaPackage := TMetaPackage(FMetaPackages.Add);
    //need to change
    AMetaPackage.Name := PackageData.Get('Name');
    AMetaPackage.DisplayName := PackageData.Get('DisplayName');
    AMetaPackage.Category := PackageData.Get('Category');
    AMetaPackage.CommunityDescription := PackageData.Get('CommunityDescription');
    AMetaPackage.ExternalDependecies := PackageData.Get('ExternalDependecies');
    AMetaPackage.OrphanedPackage := PackageData.Get('OrphanedPackage');
    AMetaPackage.RepositoryFileName := PackageData.Get('RepositoryFileName');
    AMetaPackage.RepositoryFileSize := PackageData.Get('RepositoryFileSize');
    AMetaPackage.RepositoryFileHash := PackageData.Get('RepositoryFileHash');
    AMetaPackage.RepositoryDate := VarToDateTime(PackageData.Get('RepositoryDate'));
    AMetaPackage.PackageBaseDir := PackageData.Get('PackageBaseDir');
    if AMetaPackage.PackageBaseDir <> '' then
      AMetaPackage.PackageBaseDir := StringReplace(AMetaPackage.PackageBaseDir, '\/', PathDelim, [rfReplaceAll]);;
    AMetaPackage.HomePageURL := PackageData.Get('HomePageURL');
    AMetaPackage.DownloadURL := PackageData.Get('DownloadURL');
    AMetaPackage.SVNURL := PackageData.Get('SVNURL');
  except
    on E: Exception do
    begin
      Result := False;
      FlastError := '"' + AMetaPackage.Name + '": ' + E.Message;
    end;
  end;
end;

function TSerializablePackages.JSONToLazarusPackages(const APackageData: TJSONData;
  var AMetaPackage: TMetaPackage): Boolean;
var
  LazarusPkgsArr: TJSONArray;
  LazarusPkgsObj: TJSONObject;
  LazarusPkg: TLazarusPackage;
  I: Integer;
begin
  Result := True;
  try
    LazarusPkgsArr := TJSONArray(APackageData);
    AMetaPackage.LazarusPackages := TCollection.Create(TLazarusPackage);
    for I := 0 to LazarusPkgsArr.Count - 1 do
    begin
      if LazarusPkgsArr.Items[I].JSONType = jtObject then
      begin
       LazarusPkgsObj := TJSONObject(LazarusPkgsArr.Items[I]);
       LazarusPkg := TLazarusPackage(AMetaPackage.LazarusPackages.Add);
       //need to change
       LazarusPkg.Name := LazarusPkgsObj.Get('Name');
       LazarusPkg.Description := LazarusPkgsObj.Get('Description');
       LazarusPkg.Author := LazarusPkgsObj.Get('Author');
       LazarusPkg.License := LazarusPkgsObj.Get('License');
       LazarusPkg.PackageRelativePath := LazarusPkgsObj.Get('RelativeFilePath');
       if LazarusPkg.PackageRelativePath <> '' then
         LazarusPkg.PackageRelativePath := StringReplace(LazarusPkg.PackageRelativePath, '\/', PathDelim, [rfReplaceAll]);
       LazarusPkg.VersionAsString := LazarusPkgsObj.Get('VersionAsString');
       LazarusPkg.LazCompatibility := LazarusPkgsObj.Get('LazCompatibility');
       LazarusPkg.FPCCompatibility := LazarusPkgsObj.Get('FPCCompatibility');
       LazarusPkg.SupportedWidgetSet := LazarusPkgsObj.Get('SupportedWidgetSet');
       LazarusPkg.PackageType := TLazPackageType(LazarusPkgsObj.Get('PackageType'));
       {the package type wasn't changed in the packagelist.json to preserve compatibility with older versions, we need to convert from old to new
       Old --> TPackageType = (ptRunAndDesignTime, ptDesignTime, ptRunTime, ptRunTimeOnly);
       New --> TLazPackageType = (lptRunTime, lptDesignTime, lptRunAndDesignTime, lptRunTimeOnly);}
       case Ord(LazarusPkg.PackageType) of
         0: LazarusPkg.PackageType := lptRunAndDesignTime;
         1: LazarusPkg.PackageType := lptDesignTime;
         2: LazarusPkg.PackageType := lptRunTime;
         3: LazarusPkg.PackageType := lptRunTimeOnly;
       end;
       LazarusPkg.DependenciesAsString := LazarusPkgsObj.Get('DependenciesAsString');
      end;
    end;
  except
    on E: Exception do
    begin
      Result := False;
      FlastError := '"' + LazarusPkg.Name + '": ' + E.Message;
    end;
  end;
end;

function TSerializablePackages.JSONToPackages(JSON: TJSONStringType): Boolean;
var
  Data: TJSONData;
  Parser: TJSONParser;
  I: Integer;
  MetaPackage: TMetaPackage;
begin
  Clear;
  if Trim(JSON) = '' then
    Exit(False);
  Result := True;
  Parser := TJSONParser.Create(JSON){%H-};
  try
    Data := Parser.Parse;
    try
      MetaPackage := nil;
      try
        if Data.JSONType = jtObject then
        begin
          for I := 0 to Data.Count - 1 do
          begin
            if Assigned(FOnProcessJSON) then
              FOnProcessJSON(Self);
            if Data.Items[I].JSONType = jtObject then
            begin
              if not JSONToPackageData(Data.Items[I], MetaPackage) then
                Result := False;
            end
            else if Data.Items[I].JSONType = jtArray then
            begin
              if not JSONToLazarusPackages(Data.Items[I], MetaPackage) then
                Result := False;
            end;
          end;
          if Result then
            GetPackageStates;
        end;
      except
        Result := False;
      end;
    finally
      Data.Free;
    end;
  finally
    Parser.Free;
  end;
  if Result then
  begin
    LoadUpdateInfo;
    if Assigned(FOnUpdatePackageLinks) then
      FOnUpdatePackageLinks(Self);
  end;
end;

function TSerializablePackages.LazarusPackagesToJSON(AMetaPackage: TMetaPackage;
 var ALazarusPkgsArr: TJSONArray): Boolean;
var
  LazarusPkg: TLazarusPackage;
  LazarusPkgObj: TJSONObject;
  I: Integer;
  RelPath: String;
begin
  Result := True;
  try
    ALazarusPkgsArr := TJSONArray.Create;
    for I := 0 to AMetaPackage.FLazarusPackages.Count - 1 do
    begin
      LazarusPkg := TLazarusPackage(AMetaPackage.FLazarusPackages.Items[I]);
      LazarusPkgObj := TJSONObject.Create;
      //need to change
      LazarusPkgObj.Add('Name', LazarusPkg.Name);
      LazarusPkgObj.Add('Description', LazarusPkg.Description);
      LazarusPkgObj.Add('Author', LazarusPkg.Author);
      LazarusPkgObj.Add('License', LazarusPkg.License);
      RelPath := LazarusPkg.PackageRelativePath;
      if Trim(RelPath) <> '' then
      begin
        RelPath := AppendPathDelim(RelPath);
        RelPath := StringReplace(RelPath, PathDelim, '\/', [rfReplaceAll]);
      end;
      LazarusPkgObj.Add('RelativeFilePath', RelPath);
      LazarusPkgObj.Add('VersionAsString', LazarusPkg.VersionAsString);
      LazarusPkgObj.Add('LazCompatibility', LazarusPkg.LazCompatibility);
      LazarusPkgObj.Add('FPCCompatibility', LazarusPkg.FPCCompatibility);
      LazarusPkgObj.Add('SupportedWidgetSet', LazarusPkg.SupportedWidgetSet);
      {the package type wasn't changed in the packagelist.json to preserve compatibility with older versions, we need to convert from new to old
       New --> TLazPackageType = (lptRunTime, lptDesignTime, lptRunAndDesignTime, lptRunTimeOnly);
       Old --> TPackageType = (ptRunAndDesignTime, ptDesignTime, ptRunTime, ptRunTimeOnly);}
       case Ord(LazarusPkg.PackageType) of
         0: LazarusPkg.PackageType := lptRunAndDesignTime;
         1: LazarusPkg.PackageType := lptDesignTime;
         2: LazarusPkg.PackageType := lptRunTime;
         3: LazarusPkg.PackageType := lptRunTimeOnly;
       end;
      LazarusPkgObj.Add('PackageType', Ord(LazarusPkg.PackageType));
      LazarusPkgObj.Add('DependenciesAsString', LazarusPkg.DependenciesAsString);
      ALazarusPkgsArr.Add(LazarusPkgObj);
    end;
  except
    on E: Exception do
    begin
      Result := False;
      FlastError := '"' + LazarusPkg.Name + '": ' + E.Message;
    end;
  end;
end;

function TSerializablePackages.IsPackageDownloaded(const AMetaPackage: TMetaPackage): Boolean;
var
  FileName: String;
begin
  FileName := Options.LocalRepositoryArchiveExpanded + AMetaPackage.RepositoryFileName;
  Result := (FileExists(FileName)) and
//            (MD5Print(MD5File(FileName)) = AMetaPackage.RepositoryFileHash) and
            (FileUtil.FileSize(FileName) = AMetaPackage.RepositoryFileSize);
end;

function TSerializablePackages.IsPackageExtracted(const AMetaPackage: TMetaPackage): Boolean;
var
  I: Integer;
  LazarusPkg: TLazarusPackage;
begin
  Result := True;
  for I := 0 to AMetaPackage.FLazarusPackages.Count - 1 do
  begin
    LazarusPkg := TLazarusPackage(AMetaPackage.FLazarusPackages.Items[I]);
    LazarusPkg.FPackageAbsolutePath := Options.LocalRepositoryPackagesExpanded + AMetaPackage.PackageBaseDir
                                      + LazarusPkg.FPackageRelativePath + LazarusPkg.Name;
    if not FileExists(LazarusPkg.FPackageAbsolutePath) then
    begin
      Result := False;
      Break;
    end;
  end;
end;

function TSerializablePackages.GetPackageVersion(const APath: String): String;

  function VersionBound(const AVersion: Integer): Integer;
  begin
    if AVersion > 9999 then
      Result := 9999
    else if AVersion < 0 then
      Result := 0
    else
      Result := AVersion;
  end;

  function GetVersion(const AXMLConfig: TXMLConfig; const APath: String): String;
  var
    Major, Minor, Release, Build: Integer;
  begin
    Major := VersionBound(AXMLConfig.GetValue(APath + '/Major', 0));
    Minor := VersionBound(AXMLConfig.GetValue(APath + '/Minor', 0));
    Release := VersionBound(AXMLConfig.GetValue(APath + '/Release', 0));
    Build := VersionBound(AXMLConfig.GetValue(APath + '/Build', 0));
    Result := IntToStr(Major) + '.' + IntToStr(Minor) + '.' + IntToStr(Release) + '.' + IntToStr(Build);
  end;

var
  XMLConfig: TXMLConfig;
begin
  Result := '-';
  XMLConfig := TXMLConfig.Create(APath);
  try
    Result := GetVersion(XMLConfig, 'Package/Version');
  finally
    XMLConfig.Free;
  end;
end;

function TSerializablePackages.GetPackageDescription(const APath: String): String;
var
  XMLConfig: TXMLConfig;
begin
  Result := '';
  XMLConfig := TXMLConfig.Create(APath);
  try
    Result := XMLConfig.GetValue('Package/Description/Value', '');
  finally
    XMLConfig.Free;
  end;
end;

function TSerializablePackages.GetPackageLicense(const APath: String): String;
var
  XMLConfig: TXMLConfig;
begin
  Result := '';
  XMLConfig := TXMLConfig.Create(APath);
  try
    Result := XMLConfig.GetValue('Package/License/Value', '');
  finally
    XMLConfig.Free;
  end;
end;

procedure TSerializablePackages.LoadUpdateInfo;
var
  PackageCount: Integer;
  LazarusPkgCount: Integer;
  I, J: Integer;
  Path, SubPath: String;
  PackageName: String;
  LazarusPkgName: String;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
  HasUpdate: Boolean;
  FXML: TXMLConfig;
begin
  if not FileExists(FUpdates) then
    Exit;
  FXML := TXMLConfig.Create(FUpdates);
  try
    PackageCount := FXML.GetValue('Count/Value', 0);
    for I := 0 to PackageCount - 1 do
    begin
      Path := 'Package' + IntToStr(I) + '/';
      PackageName := FXML.GetValue(Path + 'Name', '');
      MetaPkg := FindMetaPackage(PackageName, fpbPackageName);
      if MetaPkg <> nil then
      begin
        HasUpdate := False;
        MetaPkg.DownloadZipURL := FXML.GetValue(Path + 'DownloadZipURL', '');
        MetaPkg.DisableInOPM := FXML.GetValue(Path + 'DisableInOPM', False);
        MetaPkg.Rating := FXML.GetValue(Path + 'Rating', 0);
        LazarusPkgCount := FXML.GetValue(Path + 'Count', 0);
        for J := 0 to LazarusPkgCount - 1 do
        begin
          SubPath := Path + 'PackageFile' +  IntToStr(J) + '/';
          LazarusPkgName := FXML.GetValue(SubPath + 'Name', '');
          LazarusPkg := MetaPkg.FindLazarusPackage(LazarusPkgName);
          if LazarusPkg <> nil then
          begin
            LazarusPkg.UpdateVersion := FXML.GetValue(SubPath + 'UpdateVersion', '');
            LazarusPkg.ForceNotify := FXML.GetValue(SubPath + 'ForceNotify', False);
            LazarusPkg.InternalVersion := FXML.GetValue(SubPath + 'InternalVersion', 0);;
            LazarusPkg.InternalVersionOld := FXML.GetValue(SubPath + 'InternalVersionOld', 0);
            LazarusPkg.RefreshHasUpdate;
            if not HasUpdate then
              HasUpdate := (LazarusPkg.HasUpdate) and (LazarusPkg.InstalledFileVersion < LazarusPkg.UpdateVersion);
          end;
        end;
        MetaPkg.HasUpdate := HasUpdate;
      end;
    end;
  finally
    FXML.Free;
  end;
end;

procedure TSerializablePackages.SaveUpdateInfo;
var
  I, J: Integer;
  Path, SubPath: String;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
  FXML: TXMLConfig;
begin
  FXML := TXMLConfig.CreateClean(FUpdates);
  try
    FXML.SetDeleteValue('Version/Value', OpkVersion, 0);
    FXML.SetDeleteValue('Count/Value', Count, 0);
    for I := 0 to Count - 1 do
    begin
      MetaPkg := Items[I];
      Path := 'Package' + IntToStr(I) + '/';
      FXML.SetDeleteValue(Path + 'Name', MetaPkg.Name, '');
      FXML.SetDeleteValue(Path + 'DownloadZipURL', MetaPkg.DownloadZipURL, '');
      FXML.SetDeleteValue(Path + 'DisableInOPM', MetaPkg.DisableInOPM, False);
      FXML.SetDeleteValue(Path + 'Rating', MetaPkg.Rating, 0);
      FXML.SetDeleteValue(Path + 'Count', Items[I].LazarusPackages.Count, 0);
      for J := 0 to Items[I].LazarusPackages.Count - 1 do
      begin
        SubPath := Path + 'PackageFile' +  IntToStr(J) + '/';
        LazarusPkg := TLazarusPackage(Items[I].LazarusPackages.Items[J]);
        FXML.SetDeleteValue(SubPath + 'Name', LazarusPkg.Name, '');
        FXML.SetDeleteValue(SubPath + 'UpdateVersion', LazarusPkg.UpdateVersion, '');
        FXML.SetDeleteValue(SubPath + 'ForceNotify', LazarusPkg.ForceNotify, False);
        FXML.SetDeleteValue(SubPath + 'InternalVersion', LazarusPkg.InternalVersion, 0);
        FXML.SetDeleteValue(SubPath + 'InternalVersionOld', LazarusPkg.InternalVersionOld, 0);
      end;
    end;
    FXML.Flush;
  finally
    FXML.Free;
  end;
end;

function TSerializablePackages.IsPackageInstalled(const ALazarusPkg: TLazarusPackage;
  const APackageBaseDir: String): Boolean;

  function CheckIDEPackages: Boolean;
  var
    IDEPkg: TIDEPackage;
    PkgExt: String;
    PkgName: String;
  begin
    Result := False;
    PkgExt := ExtractFileExt(ALazarusPkg.Name);
    PkgName := StringReplace(ALazarusPkg.Name, PkgExt, '', [rfIgnoreCase]);
    IDEPkg := PackageEditingInterface.IsPackageInstalled(PkgName);
    if IDEPkg <> nil then
    begin
      ALazarusPkg.InstalledFileName := IDEPkg.Filename;
      ALazarusPkg.InstalledFileVersion := IntToStr(IDEPkg.Version.Major) + '.' +
                                          IntToStr(IDEPkg.Version.Minor) + '.' +
                                          IntToStr(IDEPkg.Version.Release) + '.' +
                                          IntToStr(IDEPkg.Version.Build);
     if FileExists(ALazarusPkg.InstalledFileName) then
     begin
       ALazarusPkg.InstalledFileDescription := GetPackageDescription(IDEPkg.Filename);
       ALazarusPkg.InstalledFileLincese := GetPackageLicense(IDEPkg.Filename);
     end;
     Result := True;
    end;
  end;

var
  FileName, RepoPath: String;
begin
  Result := False;
  case ALazarusPkg.PackageType of
    lptRunTime, lptRunTimeOnly:
      begin
        FileName := StringReplace(ALazarusPkg.Name, '.lpk', '.opkman', [rfIgnoreCase]);
        RepoPath := Options.LocalRepositoryPackagesExpanded + APackageBaseDir + ALazarusPkg.PackageRelativePath;
        Result := (psExtracted in ALazarusPkg.PackageStates) and FileExists(RepoPath + FileName);
        if Result then
        begin
          ALazarusPkg.InstalledFileName := RepoPath + ALazarusPkg.Name;
          if FileExists(ALazarusPkg.InstalledFileName) then
          begin
            ALazarusPkg.InstalledFileVersion := GetPackageVersion(ALazarusPkg.InstalledFileName);
            ALazarusPkg.InstalledFileDescription := GetPackageDescription(ALazarusPkg.InstalledFileName);
            ALazarusPkg.InstalledFileLincese := GetPackageLicense(ALazarusPkg.InstalledFileName);
          end;
        end
        else
          Result := CheckIDEPackages
      end;
    lptDesignTime, lptRunAndDesignTime:
      begin
        Result := CheckIDEPackages
      end;
  end;
end;

function TSerializablePackages.GetPackageInstallState(const AMetaPackage: TMetaPackage): Integer;
var
  I: Integer;
  LazarusPkg: TLazarusPackage;
  InstCnt: Integer;
begin
  InstCnt := 0;
  for I := 0 to AMetaPackage.LazarusPackages.Count - 1 do
  begin
    LazarusPkg := TLazarusPackage(AMetaPackage.LazarusPackages.Items[I]);
    if IsPackageInstalled(LazarusPkg, AMetaPackage.PackageBaseDir) then
      Inc(InstCnt);
  end;
  case InstCnt of
    0: Result := 0;
    1..High(Integer):
        if InstCnt < AMetaPackage.LazarusPackages.Count then
          Result := 2
        else
          Result := 1;
  end;
end;

function TSerializablePackages.PackageDataToJSON(AMetaPackage: TMetaPackage;
 var APackageData: TJSONObject): Boolean;
var
  PackageBaseDir: String;
begin
  //need to change
  Result := True;
  try
    APackageData := TJSONObject.Create;
    APackageData.Add('Name', AMetaPackage.Name);
    APackageData.Add('DisplayName', AMetaPackage.DisplayName);
    APackageData.Add('Category', AMetaPackage.Category);
    APackageData.Add('CommunityDescription', AMetaPackage.CommunityDescription);
    APackageData.Add('ExternalDependecies', AMetaPackage.ExternalDependecies);
    APackageData.Add('OrphanedPackage', AMetaPackage.OrphanedPackage);
    APackageData.Add('RepositoryFileName', AMetaPackage.RepositoryFileName);
    APackageData.Add('RepositoryFileSize', AMetaPackage.RepositoryFileSize);
    APackageData.Add('RepositoryFileHash', AMetaPackage.RepositoryFileHash);
    APackageData.Add('RepositoryDate', AMetaPackage.RepositoryDate);
    PackageBaseDir := AMetaPackage.PackageBaseDir;
    if Trim(PackageBaseDir) <> '' then
    begin
      PackageBaseDir := AppendPathDelim(PackageBaseDir);
      PackageBaseDir := StringReplace(PackageBaseDir, PathDelim, '\/', [rfReplaceAll]);
    end;
    APackageData.Add('PackageBaseDir', PackageBaseDir);
    APackageData.Add('HomePageURL', AMetaPackage.HomePageURL);
    APackageData.Add('DownloadURL', AMetaPackage.DownloadURL);
    APackageData.Add('SVNURL', AMetaPackage.SVNURL);
  except
    on E: Exception do
    begin
      Result := False;
      FlastError := '"' + AMetaPackage.Name + '": ' + E.Message;
    end;
  end;
end;

function TSerializablePackages.PackagesToJSON(var JSON: TJSONStringType): Boolean;
var
  PackageObject: TJSONObject;
  PackageData: TJSONObject;
  LazarusPkgsArr: TJSONArray;
  I: Integer;
  MetaPackage: TMetaPackage;
begin
  Result := True;
  PackageObject := TJSONObject.Create;
  try
    LazarusPkgsArr := nil;
    PackageData := nil;
    try
      for I := 0 to FMetaPackages.Count - 1 do
      begin
        MetaPackage := TMetaPackage(FMetaPackages.Items[I]);
        if not LazarusPackagesToJSON(MetaPackage, LazarusPkgsArr) then
          Result := False;
        if not PackageDataToJSON(MetaPackage, PackageData) then
          Result := False;
        PackageObject.Add('PackageData' + IntToStr(I), PackageData);
        PackageObject.Add('PackageFiles' + IntToStr(I), LazarusPkgsArr);
      end;
      if Result then
        JSON := PackageObject.FormatJSON(DefaultFormat, DefaultIndentSize);
    except
      Result := False;
    end;
  finally
    PackageObject.Free;
  end;
end;

procedure TSerializablePackages.GetPackageDependencies(const APkgFileName: String;
 List: TObjectList; Recurse, OnlyUnresolved: Boolean);
var
  SL: TStringList;
  I, J: Integer;
  PackageName: String;
  Installed: Boolean;
  IDEPackage: TIDEPackage;
  LazarusPkg: TLazarusPackage;
begin
  SL := TStringList.Create;
  try
    SL.Sorted := True;
    DoGetPackageDependencies(APkgFileName, SL, Ord(Recurse) - 1);
    if OnlyUnresolved then
    begin
      for I := SL.Count - 1 downto 0 do
      begin
        PackageName := TPackageDependency(SL.Objects[I]).PkgFileName + '.lpk';
        Installed := False;
        for J := 0 to PackageEditingInterface.GetPackageCount - 1 do
        begin
          IDEPackage := PackageEditingInterface.GetPackages(J);
          if CompareText(ExtractFileName(IDEPackage.Filename), PackageName) = 0 then
          begin
            LazarusPkg := FindLazarusPackage(PackageName);
            if LazarusPkg <> nil then
              Installed := IsInstalledVersionOk(TPackageDependency(SL.Objects[I]), LazarusPkg.InstalledFileVersion)
            else
              Installed := True;
            Break;
          end;
        end;
        if Installed then
          SL.Objects[I].Free
        else
          List.Add(SL.Objects[I])
      end;
    end
    else
      for I := 0 to SL.Count - 1 do
        List.Add(SL.Objects[I]);
  finally
    SL.Free;
  end;
end;

procedure TSerializablePackages.GetPackageStates;
var
  I, J: Integer;
  LazarusPkg: TLazarusPackage;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].FPackageState := psRepository;
    Items[I].ChangePackageStates(ctAdd, psRepository);

    if IsPackageDownloaded(Items[I]) then
      Items[I].ChangePackageStates(ctAdd, psDownloaded)
    else
      Items[I].ChangePackageStates(ctRemove, psDownloaded);


    if IsPackageExtracted(Items[I]) then
      Items[I].ChangePackageStates(ctAdd, psExtracted)
    else
      Items[I].ChangePackageStates(ctRemove, psExtracted);

    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      LazarusPkg := TLazarusPackage(Items[I].FLazarusPackages.Items[J]);
      if IsPackageInstalled(LazarusPkg, Items[I].PackageBaseDir) then
      begin
        LazarusPkg.PackageStates := LazarusPkg.PackageStates + [psInstalled];
        LazarusPkg.PackageState := psInstalled;
      end
      else
        LazarusPkg.PackageStates := LazarusPkg.PackageStates - [psInstalled];
    end;
  end;
end;

procedure TSerializablePackages.RemoveErrorState;
var
  I, J: Integer;
  LazarusPkg: TLazarusPackage;
begin
  for I := 0 to Count - 1 do
  begin
    if psError in Items[I].PackageStates then
      Items[I].ChangePackageStates(ctRemove, psError);
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      LazarusPkg := TLazarusPackage(Items[I].FLazarusPackages.Items[J]);
      if psError in LazarusPkg.PackageStates then
        LazarusPkg.PackageStates := LazarusPkg.PackageStates - [psError];
    end;
  end;
end;

procedure TSerializablePackages.RemoveCheck;
var
  I, J: Integer;
  MetaPkg: TMetaPackage;
  LazarusPkg: TLazarusPackage;
begin
  for I := 0 to Count - 1 do
  begin
    MetaPkg := TMetaPackage(Items[I]);
    MetaPkg.Checked := False;
    MetaPkg.IsDependencyPackage := False;
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      LazarusPkg := TLazarusPackage(Items[I].FLazarusPackages.Items[J]);
      LazarusPkg.Checked := False;
      LazarusPkg.IsDependencyPackage := False;
    end;
  end;
end;

procedure TSerializablePackages.MarkRuntimePackages;
var
  I, J: Integer;
  FileName: String;
  LazarusPkg: TLazarusPackage;
begin
  for I := 0 to Count - 1 do
  begin
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
    begin
      LazarusPkg := TLazarusPackage(Items[I].FLazarusPackages.Items[J]);
      if (LazarusPkg.Checked) and
         (psInstalled in LazarusPkg.PackageStates) and
           (not (psError in LazarusPkg.PackageStates)) and
             (LazarusPkg.PackageType in [lptRunTime, lptRunTimeOnly]) then
      begin
        FileName := StringReplace(LazarusPkg.Name, '.lpk', '.opkman', [rfIgnoreCase]);
        FileCreate(Options.LocalRepositoryPackagesExpanded + Items[I].PackageBaseDir + LazarusPkg.PackageRelativePath + FileName);
      end;
    end;
  end;
end;

function TSerializablePackages.AtLeastOneLazPkgInstalled(const AMetaPackage: TMetaPackage): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AMetaPackage.LazarusPackages.Count - 1 do
  begin
    if IsPackageInstalled(TLazarusPackage(AMetaPackage.FLazarusPackages.Items[I]), AMetaPackage.PackageBaseDir) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TSerializablePackages.Cleanup: Integer;
var
  I: Integer;
  AlreadyCounted: Boolean;
begin
  Result := 0;
  for I := 0 to Count - 1 do
  begin
    if not AtLeastOneLazPkgInstalled(Items[I]) then
    begin
      AlreadyCounted := False;
      if IsPackageDownloaded(Items[I]) then
      begin
        if DeleteFile(Options.LocalRepositoryArchiveExpanded + Items[I].RepositoryFileName) then
        begin
          Inc(Result);
          AlreadyCounted := True;
        end;
      end;
      if IsPackageExtracted(Items[I]) then
      begin
        if DirectoryExists(Options.LocalRepositoryPackagesExpanded + Items[I].PackageBaseDir) then
        begin
          DeleteDirectory(Options.LocalRepositoryPackagesExpanded + Items[I].PackageBaseDir, False);
          if not AlreadyCounted then
            Inc(Result);
        end;
      end;
    end;
  end;
end;

procedure TSerializablePackages.DeleteDownloadedZipFiles;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    case PackageAction of
      paInstall:
        begin
          if IsPackageDownloaded(Items[I]) then
            DeleteFile(Options.LocalRepositoryArchiveExpanded + Items[I].RepositoryFileName)
        end;
      paUpdate:
        begin
          if FileExists(Options.LocalRepositoryUpdateExpanded + Items[I].RepositoryFileName) then
            DeleteFile(Options.LocalRepositoryUpdateExpanded + Items[I].RepositoryFileName)
        end;
    end;
  end;
end;

function SortByNameAsc(Item1, Item2: TCollectionItem): Integer;
var
  Package1, Package2: TMetaPackage;
begin
  Package1 := TMetaPackage(Item1);
  Package2 := TMetaPackage(Item2);
  Result := CompareText(Package1.FDisplayName, Package2.FDisplayName);
end;

function SortByNameDsc(Item1, Item2: TCollectionItem): Integer;
var
  Package1, Package2: TMetaPackage;
begin
  Package1 := TMetaPackage(Item1);
  Package2 := TMetaPackage(Item2);
  Result := CompareText(Package2.FDisplayName, Package1.FDisplayName);
end;

function SortByDateAsc(Item1, Item2: TCollectionItem): Integer;
var
  Package1, Package2: TMetaPackage;
begin
  Package1 := TMetaPackage(Item1);
  Package2 := TMetaPackage(Item2);
  Result := CompareDateTime(Package1.RepositoryDate, Package2.RepositoryDate);
end;

function SortByDateDsc(Item1, Item2: TCollectionItem): Integer;
var
  Package1, Package2: TMetaPackage;
begin
  Package1 := TMetaPackage(Item1);
  Package2 := TMetaPackage(Item2);
  Result := CompareDateTime(Package2.RepositoryDate, Package1.RepositoryDate);
end;

procedure TSerializablePackages.Sort(const ASortType: TSortType;
  const ASortOrder: TSortOrder);
begin
  case ASortType of
    stName:
      if ASortOrder = soAscendent then
        FMetaPackages.Sort(@SortByNameAsc)
      else if ASortOrder = soDescendent then
        FMetaPackages.Sort(@SortByNameDsc);
    stDate:
      if ASortOrder = soAscendent then
        FMetaPackages.Sort(@SortByDateAsc)
      else if ASortOrder = soDescendent then
        FMetaPackages.Sort(@SortByDateDsc)
  end;
end;

function TSerializablePackages.QuickStatistics: String;
var
  I, J: Integer;
  LazPackCnt: Integer;
  TotSize: Int64;
begin
  LazPackCnt := 0;
  TotSize := 0;
  for I := 0 to Count - 1 do
  begin
    TotSize := TotSize + Items[I].RepositoryFileSize;
    for J := 0 to Items[I].FLazarusPackages.Count - 1 do
      Inc(LazPackCnt);
  end;
  Result := Format(rsPackagesFound, [IntToStr(SerializablePackages.Count), IntToStr(LazPackCnt), FormatSize(TotSize)]);
end;

function TSerializablePackages.IsDependencyOk(PackageDependency: TPackageDependency;
  DependencyPackage: TLazarusPackage): Boolean;
var
  MinVerOk: Boolean;
  MaxVerOk: Boolean;
begin
  if PackageDependency.MinVersion.IsNullVersion then
    MinVerOk := True
  else
    MinVerOk := PackageDependency.MinVersion.Compare(DependencyPackage.Version) <= 0;

  if PackageDependency.MaxVersion.IsNullVersion then
    MaxVerOk := True
  else
    MaxVerOk := PackageDependency.MaxVersion.Compare(DependencyPackage.Version) >= 0;

  Result := (MinVerOk) and (MaxVerOk)
end;

function TSerializablePackages.IsInstalledVersionOk(PackageDependency: TPackageDependency;
  InstalledVersion: String): Boolean;
var
  MinVerOk: Boolean;
  MaxVerOk: Boolean;
begin
  if PackageDependency.MinVersion.IsNullVersion then
    MinVerOk := True
  else
    MinVerOk := PackageDependency.MinVersion.AsString <= InstalledVersion;

  if PackageDependency.MaxVersion.IsNullVersion then
    MaxVerOk := True
  else
    MaxVerOk := PackageDependency.MaxVersion.AsString >= InstalledVersion;

  Result := (MinVerOk) and (MaxVerOk)
end;

end.


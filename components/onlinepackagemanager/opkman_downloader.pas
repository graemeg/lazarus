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
   Implementation of the package downloader class.
}
unit opkman_downloader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, LazIDEIntf, md5,
  // OpkMan
  opkman_common, opkman_serializablepackages, opkman_const, opkman_options,
  {$IF FPC_FULLVERSION>=30200}fphttpclient, opensslsockets{$ELSE}opkman_httpclient{$ENDIF};

type
  TDownloadType = (dtJSON, dtPackage, dtUpdate);
  TErrorType = (etNone, etConfig, etTimeOut, etHTTPClient);
  TOnTimer = TNotifyEvent;
  TOnJSONProgress = TNotifyEvent;
  TOnJSONDownloadCompleted = procedure(Sender: TObject; AJSON: TJSONStringType; AErrTyp: TErrorType; const AErrMsg: String = '') of object;
  TOnWriteStream = procedure(Sender: TObject; APos: Int64) of object;
  TOnPackageDownloadProgress = procedure(Sender: TObject; AFrom, ATo: String; ACnt, ATotCnt: Integer; ACurPos, ACurSize, ATotPos, ATotSize: Int64;
    AElapsed, ARemaining, ASpeed: LongInt) of object;
  TOnPackageDownloadError = procedure(Sender: TObject; APackageName: String; const AErrMsg: String = '') of object;
  TOnPackageDownloadCompleted = TNotifyEvent;
  TOnPackageUpdateProgress = procedure(Sender: TObject; AUPackageName, AUPackageURL: String; ACnt, ATotCnt: Integer; AUTyp: Integer; AUErrMsg: String) of object;
  TOnPackageUpdateCompleted = procedure(Sender: TObject; AUSuccess: Boolean) of object;

  { TDownloadStream }

  TDownloadStream = class(TStream)
  private
    FOnWriteStream: TOnWriteStream;
    FStream: TStream;
  public
    constructor Create(AStream: TStream);
    destructor Destroy; override;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
    procedure DoProgress;
  published
    property OnWriteStream: TOnWriteStream read FOnWriteStream write FOnWriteStream;
  end;

  { TThreadDownload }

  TThreadDownload = class(TThread)
  private
    FHTTPClient: TFPHTTPClient;
    FOnJSONComplete: TOnJSONDownloadCompleted;
    FOnJSONProgress: TNotifyEvent;
    FRemoteJSONFile: String;
    FErrMsg: String;
    FDownloadType: TDownloadType;
    FErrTyp: TErrorType;
    FMS: TMemoryStream;
    FFrom: String;
    FTo: String;
    FCnt: Integer;
    FTotCnt: Integer;
    FCurPos: Int64;
    FCurSize: Int64;
    FTotPos: Int64;
    FTotPosTmp: Int64;
    FTotSize: Int64;
    FRemaining: Integer;
    FSpeed: Integer;
    FStartTime: QWord;
    FElapsed: QWord;
    FTick: Qword;
    FNeedToBreak: Boolean;
    FDownloadTo: String;
    FUPackageName: String;
    FUPackageURL: String;
    FUTyp: Integer;
    FUErrMsg: String;
    FUSuccess: Boolean;
    FSilent: Boolean;
    FOnPackageDownloadProgress: TOnPackageDownloadProgress;
    FOnPackageDownloadError: TOnPackageDownloadError;
    FOnPackageDownloadCompleted: TOnPackageDownloadCompleted;
    FOnPackageUpdateProgress: TOnPackageUpdateProgress;
    FOnPackageUpdateCompleted: TOnPackageUpdateCompleted;
    function GetUpdateSize(const AURL: String; var AErrMsg: String): Int64;
    procedure DoReceivedUpdateSize(Sender: TObject; const ContentLength, {%H-}CurrentPos: int64);
    procedure DoOnJSONProgress;
    procedure DoOnJSONDownloadCompleted;
    procedure DoOnWriteStream(Sender: TObject; APos: Int64);
    procedure DoOnPackageDownloadProgress;
    procedure DoOnPackageDownloadError;
    procedure DoOnPackageDownloadCompleted;
    procedure DoOnPackageUpdateProgress;
    procedure DoOnPackageUpdateCompleted;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure DownloadJSON(const ATimeOut: Integer = -1; const ASilent: Boolean = False);
    procedure DownloadPackages(const ADownloadTo: String);
    procedure UpdatePackages(const ADownloadTo: String);
  published
    property OnJSONProgress: TNotifyEvent read FOnJSONProgress write FOnJSONProgress;
    property OnJSONDownloadCompleted: TOnJSONDownloadCompleted read FOnJSONComplete write FOnJSONComplete;
    property OnPackageDownloadCompleted: TOnPackageDownloadCompleted read FOnPackageDownloadCompleted write FOnPackageDownloadCompleted;
    property OnPackageDownloadError: TOnPackageDownloadError read FOnPackageDownloadError write FOnPackageDownloadError;
    property OnPackageDownloadProgress: TOnPackageDownloadProgress read FOnPackageDownloadProgress write FOnPackageDownloadProgress;
    property OnPackageUpdateProgress: TOnPackageUpdateProgress read FOnPackageUpdateProgress write FOnPackageUpdateProgress;
    property OnPackageUpdateCompleted: TOnPackageUpdateCompleted read FOnPackageUpdateCompleted write FOnPackageUpdateCompleted;
    property NeedToBreak: Boolean read FNeedToBreak write FNeedToBreak;
  end;

  { TPackageDownloader }

  TPackageDownloader = class
  private
    FJSON: TJSONStringType;
    FDownload: TThreadDownload;
    FRemoteRepository: String;
    FLastError: String;
    FDownloadingJSON: Boolean;
    FSilent: Boolean;
    FOnJSONProgress: TNotifyEvent;
    FOnJSONDownloadCompleted: TOnJSONDownloadCompleted;
    FOnPackageDownloadProgress: TOnPackageDownloadProgress;
    FOnPackageDownloadError: TOnPackageDownloadError;
    FOnPackageDownloadCompleted: TOnPackageDownloadCompleted;
    FOnPackageUpdateProgress: TOnPackageUpdateProgress;
    FOnPackageUpdateCompleted: TOnPackageUpdateCompleted;
    procedure DoOnJSONProgress(Sender: TObject);
    procedure DoOnJSONDownloadCompleted(Sender: TObject; AJSON: TJSONStringType; AErrTyp: TErrorType; const AErrMsg: String = '');
    procedure DoOnPackageDownloadProgress(Sender: TObject; AFrom, ATo: String; ACnt, ATotCnt: Integer;
      ACurPos, ACurSize, ATotPos, ATotSize: Int64; AElapsed, ARemaining, ASpeed: LongInt);
    procedure DoOnPackageDownloadError(Sender: TObject; APackageName: String; const AErrMsg: String = '');
    procedure DoOnPackageDownloadCompleted(Sender: TObject);
    procedure DoOnPackageUpdateProgress(Sender: TObject; AUPackageName, AUPackageURL: String; ACnt, ATotCnt: Integer; AUTyp: Integer; AUErrMsg: String);
    procedure DoOnPackageUpdateCompleted(Sender: TObject; AUSuccess: Boolean);
    procedure DoOnTerminate(Sender: TObject);
  public
    constructor Create(const ARemoteRepository: String);
    destructor Destroy; override;
    procedure DownloadJSON(const ATimeOut: Integer = -1; const ASilent: Boolean = False);
    procedure DownloadPackages(const ADownloadTo: String);
    procedure UpdatePackages(const ADownloadTo: String);
    procedure Cancel;
  published
    property RemoteRepository: String read FRemoteRepository write FRemoteRepository;
    property LastError: String read FLastError write FLastError;
    property DownloadingJSON: Boolean read FDownloadingJSON;
    property JSON: TJSONStringType read FJSON;
    property OnJSONProgress: TNotifyEvent read FOnJSONProgress write FOnJSONProgress;
    property OnJSONDownloadCompleted: TOnJSONDownloadCompleted read FOnJSONDownloadCompleted write FOnJSONDownloadCompleted;
    property OnPackageDownloadProgress: TOnPackageDownloadProgress read FOnPackageDownloadProgress write FOnPackageDownloadProgress;
    property OnPackageDownloadError: TOnPackageDownloadError read FOnPackageDownloadError write FOnPackageDownloadError;
    property OnPackageDownloadCompleted: TOnPackageDownloadCompleted read FOnPackageDownloadCompleted write FOnPackageDownloadCompleted;
    property OnPackageUpdateProgress: TOnPackageUpdateProgress read FOnPackageUpdateProgress write FOnPackageUpdateProgress;
    property OnPackageUpdateCompleted: TOnPackageUpdateCompleted read FOnPackageUpdateCompleted write FOnPackageUpdateCompleted;
  end;

var
  PackageDownloader: TPackageDownloader = nil;

implementation

{ TDownloadStream }
constructor TDownloadStream.Create(AStream: TStream);
begin
  inherited Create;
  FStream := AStream;
  FStream.Position := 0;
end;

destructor TDownloadStream.Destroy;
begin
  FStream.Free;
  inherited Destroy;
end;

function TDownloadStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result := FStream.Read(Buffer, Count);
end;

function TDownloadStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  Result := FStream.Write(Buffer, Count);
  DoProgress;
end;

function TDownloadStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
  Result := FStream.Seek(Offset, Origin);
end;

procedure TDownloadStream.DoProgress;
begin
  if Assigned(FOnWriteStream) then
    FOnWriteStream(Self, Self.Position);
end;

{ TThreadDownload }

procedure TThreadDownload.DoOnPackageDownloadProgress;
begin
  if Assigned(FOnPackageDownloadProgress) then
    FOnPackageDownloadProgress(Self, FFrom, FTo, FCnt, FTotCnt, FCurPos, FCurSize, FTotPosTmp, FTotSize, FElapsed, FRemaining, FSpeed);
end;

procedure TThreadDownload.DoOnPackageDownloadError;
begin
  if Assigned(FOnPackageDownloadError) then
    FOnPackageDownloadError(Self, ExtractFileName(FTo), FErrMsg);
end;

procedure TThreadDownload.DoOnPackageDownloadCompleted;
begin
  if Assigned(FOnPackageDownloadCompleted) then
    FOnPackageDownloadCompleted(Self);
end;

procedure TThreadDownload.DoOnPackageUpdateProgress;
begin
  if Assigned(FOnPackageUpdateProgress) then
    FOnPackageUpdateProgress(Self, FUPackageName, FUPackageURL, FCnt, FTotcnt, FUTyp, FUErrMsg);
end;

procedure TThreadDownload.DoOnPackageUpdateCompleted;
begin
  if Assigned(FOnPackageUpdateCompleted) then
    FOnPackageUpdateCompleted(Self, FUSuccess);
end;

procedure TThreadDownload.DoOnJSONDownloadCompleted;
var
  JSON: TJSONStringType = '';
  JSONFile: String;
begin
  if Assigned(FOnJSONComplete) then
  begin
    if (FErrTyp = etNone) or (FMS.Size > 0) then
    begin
      SetLength(JSON, FMS.Size);
      FMS.Read(Pointer(JSON)^, Length(JSON));
      JSONFile := ExtractFilePath(LocalRepositoryConfigFile) + 'packagelist' + '_' + MD5Print(MD5String(Options.RemoteRepository[Options.ActiveRepositoryIndex])) + '.json';
      FMS.Position := 0;
      FMS.SaveToFile(JSONFile);
      SerializablePackages.JSONToPackages(JSON);
      FOnJSONComplete(Self, JSON, FErrTyp, '');
    end
    else
      FOnJSONComplete(Self, '', FErrTyp, FErrMsg);
  end;
end;


procedure TThreadDownload.DoOnJSONProgress;
begin
  if FSilent then
    Exit;
  if Assigned(FOnJSONProgress) then
    FOnJSONProgress(Self);
end;

procedure TThreadDownload.DoOnWriteStream(Sender: TObject; APos: Int64);
begin
  FElapsed := GetTickCount64 - FStartTime;
  if FElapsed < 1000 then
    Exit;
  FElapsed := FElapsed div 1000;
  FCurPos := APos;
  FTotPosTmp := FTotPos + APos;
  FSpeed := Round(FTotPosTmp/FElapsed);
  if FSpeed > 0 then
    FRemaining := Round((FTotSize - FTotPosTmp)/FSpeed);
  if FElapsed >= FTick + 1 then
  begin
    FTick := FElapsed;
    Synchronize(@DoOnPackageDownloadProgress);
  end;
  Sleep(5);
end;

procedure TThreadDownload.Execute;
var
  I: Integer;
  DS: TDownloadStream;
  UpdateSize: Int64;
  UpdCnt: Integer;
begin
  Sleep(50);
  FErrMsg := '';
  FErrTyp := etNone;
  if FDownloadType = dtJSON then
  begin
    if not FNeedToBreak then
      Synchronize(@DoOnJSONProgress);
    if FRemoteJSONFile <> cRemoteJSONFile then
    begin
      try
        FHTTPClient.Get(FRemoteJSONFile, FMS);
        if FMS.Size > 0 then
          FMS.Position := 0;
      except
        on E: Exception do
        begin
          FErrMsg := E.Message;
          FErrTyp := etHTTPClient;
        end;
      end;
    end
    else
    begin
      FErrTyp := etConfig;
      FErrMsg := rsMainFrm_rsMessageNoRepository0;
    end;
    if not FNeedToBreak then
      Synchronize(@DoOnJSONDownloadCompleted)
  end
  else if FDownloadType = dtPackage then //download from repository
  begin
    FCnt := 0;
    FStartTime := GetTickCount64;
    for I := 0 to SerializablePackages.Count - 1 do
    begin
      if NeedToBreak then
        Break;
      if SerializablePackages.Items[I].IsDownloadable then
      begin
        Inc(FCnt);
        FFrom := Options.RemoteRepository[Options.ActiveRepositoryIndex] + SerializablePackages.Items[I].RepositoryFileName;
        FTo := FDownloadTo + SerializablePackages.Items[I].RepositoryFileName;
        FCurSize := SerializablePackages.Items[I].RepositoryFileSize;
        DS := TDownloadStream.Create(TFileStream.Create(FTo, fmCreate));
        try
          DS.FOnWriteStream := @DoOnWriteStream;
          try
            FHTTPClient.HTTPMethod('GET', FFrom, DS, [200]);
            SerializablePackages.Items[I].ChangePackageStates(ctAdd, psDownloaded);
          except
            on E: Exception do
            begin
              FErrMsg := E.Message;
              FErrTyp := etHTTPClient;
              SerializablePackages.Items[I].ChangePackageStates(ctRemove, psDownloaded);
              SerializablePackages.Items[I].ChangePackageStates(ctAdd, psError);
              Synchronize(@DoOnPackageDownloadError);
            end;
          end;
        finally
          DS.Free
        end;
        if psError in  SerializablePackages.Items[I].PackageStates then
          DeleteFile(FTo);
        FTotPos := FTotPos + FCurSize;
      end;
    end;
    if (FNeedToBreak) then
      DeleteFile(FTo)
    else
      Synchronize(@DoOnPackageDownloadCompleted);
  end
  else if FDownloadType = dtUpdate then //download from external link
  begin
    FCnt := 0;
    UpdCnt := 0;
    FStartTime := GetTickCount64;
    for I := 0 to SerializablePackages.Count - 1 do
    begin
      if FNeedToBreak then
        Break;
      if (SerializablePackages.Items[I].Checked) then
      begin
        Inc(FCnt);
        FUpackageName := SerializablePackages.Items[I].Name;
        if SerializablePackages.Items[I].IsDependencyPackage then
          FUPackageURL := Options.RemoteRepository[Options.ActiveRepositoryIndex] + SerializablePackages.Items[I].RepositoryFileName
        else
          FUPackageURL := SerializablePackages.Items[I].DownloadZipURL;
        FUTyp := 0;
        Synchronize(@DoOnPackageUpdateProgress);
        UpdateSize := GetUpdateSize(FUPackageURL, FUErrMsg);
        if UpdateSize > -1 then
        begin
          if UpdateSize = 0 then
            UpdateSize := SerializablePackages.Items[I].RepositoryFileSize;
          FUTyp := 1;
          Synchronize(@DoOnPackageUpdateProgress);
          Inc(UpdCnt);
          SerializablePackages.Items[I].UpdateSize := UpdateSize;
          FTotSize := FTotSize + UpdateSize;
        end
        else
        begin
          FUTyp := 2;
          Synchronize(@DoOnPackageUpdateProgress);
          SerializablePackages.Items[I].UpdateSize := -1;
          SerializablePackages.Items[I].ChangePackageStates(ctAdd, psError);
        end;
      end;
    end;
    if FNeedToBreak then
      Exit;
    if (UpdCnt = 0) then
    begin
      FUSuccess := False;
      Synchronize(@DoOnPackageUpdateCompleted);
    end
    else
    begin
      FUSuccess := True;
      Synchronize(@DoOnPackageUpdateCompleted);
      FCnt := 0;
      FTotCnt := UpdCnt;
      for I := 0 to SerializablePackages.Count - 1 do
      begin
        if NeedToBreak then
          Break;
        if (SerializablePackages.Items[I].Checked) and (SerializablePackages.Items[I].UpdateSize > -1) and (not (psError in  SerializablePackages.Items[I].PackageStates)) then
        begin
          Inc(FCnt);
          if SerializablePackages.Items[I].IsDependencyPackage then
            FFrom := Options.RemoteRepository[Options.ActiveRepositoryIndex] + SerializablePackages.Items[I].RepositoryFileName
          else
            FFrom := FixProtocol(SerializablePackages.Items[I].DownloadZipURL);
          FTo := FDownloadTo + SerializablePackages.Items[I].RepositoryFileName;
          FCurSize := SerializablePackages.Items[I].UpdateSize;
          DS := TDownloadStream.Create(TFileStream.Create(FTo, fmCreate));
          try
            DS.FOnWriteStream := @DoOnWriteStream;
            try
              FHTTPClient.AllowRedirect := True;
              FHTTPClient.HTTPMethod('GET', FFrom, DS, []);
            except
            end;
            if FHTTPClient.ResponseStatusCode <> 200 then
            begin
              FErrMsg := IntToStr(FHTTPClient.ResponseStatusCode);
              FErrTyp := etHTTPClient;
              SerializablePackages.Items[I].ChangePackageStates(ctRemove, psDownloaded);
              SerializablePackages.Items[I].ChangePackageStates(ctAdd, psError);
              Synchronize(@DoOnPackageDownloadError);
            end
            else
              SerializablePackages.Items[I].ChangePackageStates(ctAdd, psDownloaded);
          finally
            DS.Free
          end;
          if psError in  SerializablePackages.Items[I].PackageStates then
            DeleteFile(FTo);
          FTotPos := FTotPos + FCurSize;
        end;
      end;
      if (FNeedToBreak) then
        DeleteFile(FTo)
      else
        Synchronize(@DoOnPackageDownloadCompleted);
    end;
  end;
end;

constructor TThreadDownload.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FMS := TMemoryStream.Create;
  FHTTPClient := TFPHTTPClient.Create(nil);
  if Options.ProxyEnabled then
  begin
    FHTTPClient.Proxy.Host:= Options.ProxyServer;
    FHTTPClient.Proxy.Port:= Options.ProxyPort;
    FHTTPClient.Proxy.UserName:= Options.ProxyUser;
    FHTTPClient.Proxy.Password:= Options.ProxyPassword;
  end;
end;

destructor TThreadDownload.Destroy;
begin
  FHTTPClient.Free;
  FMS.Free;
  inherited Destroy;
end;

procedure TThreadDownload.DownloadJSON(const ATimeOut: Integer = -1;
  const ASilent: Boolean = False);
begin
  FRemoteJSONFile := Options.RemoteRepository[Options.ActiveRepositoryIndex] + cRemoteJSONFile;
  FDownloadType := dtJSON;
  FSilent := ASilent;
  if Assigned(LazarusIDE) and LazarusIDE.IDEStarted and not LazarusIDE.IDEIsClosing then
    Start;
end;

procedure TThreadDownload.DownloadPackages(const ADownloadTo: String);
var
  I: Integer;
begin
  FDownloadType := dtPackage;
  FDownloadTo := ADownloadTo;
  FTotCnt := 0;
  FTotSize := 0;
  for I := 0 to SerializablePackages.Count - 1 do
  begin
    if SerializablePackages.Items[I].IsDownloadable then
    begin
      Inc(FTotCnt);
      FTotSize := FTotSize + SerializablePackages.Items[I].RepositoryFileSize;
    end;
  end;
  if Assigned(LazarusIDE) and LazarusIDE.IDEStarted and not LazarusIDE.IDEIsClosing then
    Start;
end;

procedure TThreadDownload.DoReceivedUpdateSize(Sender: TObject;
  const ContentLength, CurrentPos: int64);
begin
  if ContentLength > 0 then
    Abort;
end;

function TThreadDownload.GetUpdateSize(const AURL: String; var AErrMsg: String): Int64;
var
  SS: TStringStream;
  HttpClient: TFPHTTPClient;
  URL: String;
begin
  Result := -1;
  AErrMsg := '';
  SS := TStringStream.Create('');
  try
    URL := FixProtocol(AURL);
    HttpClient := TFPHTTPClient.Create(nil);
    if Options.ProxyEnabled then
      begin
        HTTPClient.Proxy.Host:= Options.ProxyServer;
        HTTPClient.Proxy.Port:= Options.ProxyPort;
        HTTPClient.Proxy.UserName:= Options.ProxyUser;
        HTTPClient.Proxy.Password:= Options.ProxyPassword;
      end;

    try
      HttpClient.OnDataReceived := @DoReceivedUpdateSize;
      HttpClient.AllowRedirect := True;
      HttpClient.ResponseHeaders.NameValueSeparator := ':';
      try
        HttpClient.HTTPMethod('GET', URL, SS, []);
      except
      end;
      if HttpClient.ResponseStatusCode = 200 then
        Result := StrToIntDef(HttpClient.ResponseHeaders.Values['CONTENT-LENGTH'], 0)
      else
        AErrMsg := 'Error code: ' + IntToStr(HttpClient.ResponseStatusCode);
    finally
      HttpClient.Free;
    end;
  finally
    SS.Free
  end;
end;

procedure TThreadDownload.UpdatePackages(const ADownloadTo: String);
var
  I: Integer;
begin
  FDownloadTo := ADownloadTo;
  FDownloadType := dtUpdate;
  FTotCnt := 0;
  FTotSize := 0;
  for I := 0 to SerializablePackages.Count - 1 do
    if (SerializablePackages.Items[I].Checked) then
      Inc(FTotCnt);
  if (Assigned(LazarusIDE) and LazarusIDE.IDEStarted and (not LazarusIDE.IDEIsClosing)) then
    Start;
end;

{ TPackageDownloader}

procedure TPackageDownloader.DoOnPackageDownloadProgress(Sender: TObject; AFrom, ATo: String;
  ACnt, ATotCnt: Integer; ACurPos, ACurSize, ATotPos, ATotSize: Int64;
  AElapsed, ARemaining, ASpeed: LongInt);
begin
  if Assigned(FOnPackageDownloadProgress) then
    FOnPackageDownloadProgress(Self, AFrom, ATo, ACnt, ATotCnt, ACurPos, ACurSize, ATotPos, ATotSize, AElapsed, ARemaining, ASpeed);
end;

procedure TPackageDownloader.DoOnPackageDownloadError(Sender: TObject;
  APackageName: String; const AErrMsg: String);
begin
  if Assigned(FOnPackageDownloadError) then
    FOnPackageDownloadError(Self, APackageName, AErrMsg);
end;

procedure TPackageDownloader.DoOnPackageDownloadCompleted(Sender: TObject);
begin
  if Assigned(FOnPackageDownloadCompleted) then
    FOnPackageDownloadCompleted(Sender);
end;

procedure TPackageDownloader.DoOnPackageUpdateProgress(Sender: TObject; AUPackageName,
  AUPackageURL: String; ACnt, ATotCnt: Integer; AUTyp: Integer; AUErrMsg: String);
begin
  if Assigned(FOnPackageUpdateProgress) then
    FOnPackageUpdateProgress(Self, AUPackageName, AUPackageURL, ACnt, ATotCnt, AUTyp, AUErrMsg);
end;

procedure TPackageDownloader.DoOnPackageUpdateCompleted(Sender: TObject;
  AUSuccess: Boolean);
begin
  if Assigned(FOnPackageUpdateCompleted) then
    FOnPackageUpdateCompleted(Self, AUSuccess);
end;

procedure TPackageDownloader.DoOnJSONProgress(Sender: TObject);
begin
  if Assigned(FOnJSONProgress) then
    FOnJSONProgress(Self);
end;

procedure TPackageDownloader.DoOnJSONDownloadCompleted(Sender: TObject;
  AJSON: TJSONStringType; AErrTyp: TErrorType; const AErrMsg: String);
begin
  if not FSilent then
  begin
    FJSON := AJSON;
    if Assigned(FOnJSONDownloadCompleted) then
      FOnJSONDownloadCompleted(Self, AJSON, AErrTyp, AErrMsg);
  end;
  FDownloadingJSON := False;
end;

constructor TPackageDownloader.Create(const ARemoteRepository: String);
begin
  FRemoteRepository := ARemoteRepository;
  if (Length(FRemoteRepository) > 0) and (not IsPathDelimiter(FRemoteRepository, Length(FRemoteRepository))) then
    FRemoteRepository := FRemoteRepository + '/';
end;

destructor TPackageDownloader.Destroy;
begin
{  if Assigned(FDownload) then
    FDownload.Terminate;}
  inherited Destroy;
end;

procedure TPackageDownloader.DownloadJSON(const ATimeOut: Integer = -1;
  const ASilent: Boolean = False);
begin
  FDownloadingJSON := True;
  FSilent := ASilent;
  FDownload := TThreadDownload.Create;
  FDownload.OnJSONProgress := @DoOnJSONProgress;
  FDownload.OnJSONDownloadCompleted := @DoOnJSONDownloadCompleted;
  FDownload.OnTerminate := @DoOnTerminate;
  FDownload.DownloadJSON(ATimeOut, ASilent);
end;

procedure TPackageDownloader.DownloadPackages(const ADownloadTo: String);
begin
  FDownload := TThreadDownload.Create;
  FDownload.OnPackageDownloadProgress := @DoOnPackageDownloadProgress;
  FDownload.OnPackageDownloadError := @DoOnPackageDownloadError;
  FDownload.OnPackageDownloadCompleted := @DoOnPackageDownloadCompleted;
  FDownload.OnTerminate := @DoOnTerminate;
  FDownload.DownloadPackages(ADownloadTo);
end;

procedure TPackageDownloader.UpdatePackages(const ADownloadTo: String);
begin
  FDownload := TThreadDownload.Create;
  FDownload.OnPackageDownloadProgress := @DoOnPackageDownloadProgress;
  FDownload.OnPackageDownloadError := @DoOnPackageDownloadError;
  FDownload.OnPackageDownloadCompleted := @DoOnPackageDownloadCompleted;
  FDownload.OnPackageUpdateProgress := @DoOnPackageUpdateProgress;
  FDownload.OnPackageUpdateCompleted := @DoOnPackageUpdateCompleted;
  FDownload.OnTerminate := @DoOnTerminate;
  FDownload.UpdatePackages(ADownloadTo);
end;

procedure TPackageDownloader.Cancel;
begin
  if Assigned(FDownload) then
  begin
    FDownload.FHTTPClient.Terminate;
    FDownload.NeedToBreak := True;
  end;
end;

procedure TPackageDownloader.DoOnTerminate(Sender: TObject);
begin
  FDownload := nil;
end;


end.


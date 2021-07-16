unit LR_DB_Zeos;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, DB, LR_Class, ZDataset, LR_DBComponent,
  LR_Intrp, ZConnection, contnrs;

type
  TlrZeosData = class(TComponent)

  end;

type
  TQueryParam = class
    ParamType:TFieldType;
    ParamName:string;
    ParamValue:string;
  end;

  { TQueryParamList }

  TQueryParamList = class(TFPObjectList)
    function ParamByName(const AParamName:string):TQueryParam;
    function Add(AParamType:TFieldType; const AParamName, AParamValue:string):TQueryParam;
  end;


  { TLRZQuery }

  TLRZQuery = class(TLRDataSetControl)
  private
    FDatabase: string;
    FParams: TQueryParamList;
    procedure SetDatabase(AValue: string);
    procedure ZQueryBeforeOpen(ADataSet: TDataSet);
    procedure DoMakeParams;
    procedure DoEditParams;
  protected
    function GetSQL: string;
    procedure SetSQL(AValue: string);
    procedure SetDataSource(AValue: string); override;
    procedure AfterLoad;override;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
  published
    property SQL:string read GetSQL write SetSQL;
    property Database:string read FDatabase write SetDatabase;
    property Params:TQueryParamList read FParams write FParams;
  end;

  { TLRZConnection }

  TLRZConnection = class(TfrNonVisualControl)
  private
    FConnected:boolean;
    FZConnection: TZConnection;
    function GetConnected: Boolean;
    function GetDatabase: string;
    function GetHostName: string;
    function GetLoginPrompt: Boolean;
    function GetPassword: string;
    function GetPort: Integer;
    function GetProtocol: string;
    function GetUser: string;
    procedure SetConnected(AValue: Boolean);
    procedure SetDatabase(AValue: string);
    procedure SetHostName(AValue: string);
    procedure SetLoginPrompt(AValue: Boolean);
    procedure SetPassword(AValue: string);
    procedure SetPort(AValue: Integer);
    procedure SetProtocol(AValue: string);
    procedure SetUser(AValue: string);
  protected
    procedure SetName(const AValue: string); override;
    procedure AfterLoad;override;
  public
    constructor Create(AOwnerPage:TfrPage); override;
    destructor Destroy; override;

    procedure LoadFromXML(XML: TLrXMLConfig; const Path: String); override;
    procedure SaveToXML(XML: TLrXMLConfig; const Path: String); override;
  published
    property Connected: Boolean read GetConnected write SetConnected;
    property LoginPrompt: Boolean read GetLoginPrompt write SetLoginPrompt;
    property Protocol: string read GetProtocol write SetProtocol;
    property HostName: string read GetHostName write SetHostName;
    property Port: Integer read GetPort write SetPort;
    property Database: string read GetDatabase write SetDatabase;
    property User: string read GetUser write SetUser;
    property Password: string read GetPassword write SetPassword;
  end;

procedure Register;
implementation

{$R lr_zeos_img.res}

uses LR_Utils, DBPropEdits, PropEdits, LazarusPackageIntf, ZDbcIntfs, types,
  lr_EditParams, Forms, Controls, variants, Dialogs, strutils;

var
  lrBMP_ZQuery:TBitmap = nil;
  lrBMP_ZConnection:TBitmap = nil;

procedure InitLRComp;
begin
  if not assigned(lrBMP_ZQuery) then
  begin
    lrBMP_ZQuery := TbitMap.Create;
    lrBMP_ZQuery.LoadFromResourceName(HInstance, 'TLRZQuery');
    frRegisterObject(TLRZQuery, lrBMP_ZQuery, 'TLRZQuery', nil, otlUIControl, nil);
  end;
  if not assigned(lrBMP_ZConnection) then
  begin
    lrBMP_ZConnection := TbitMap.Create;
    lrBMP_ZConnection.LoadFromResourceName(HInstance, 'TLRZConnection');
    frRegisterObject(TLRZConnection, lrBMP_ZConnection, 'TLRZConnection', nil, otlUIControl, nil);
  end;
end;

{ TQueryParamList }

function TQueryParamList.ParamByName(const AParamName: string): TQueryParam;
var
  i:integer;
begin
  Result:=nil;
  for i:=0 to Count - 1 do
  begin
    if CompareText(TQueryParam(Items[i]).ParamName, AParamName) = 0 then
    begin
      Result:=TQueryParam(Items[i]);
      exit;
    end;
  end;
end;

function TQueryParamList.Add(AParamType: TFieldType; const AParamName,
  AParamValue: string): TQueryParam;
begin
  Result:=TQueryParam.Create;
  inherited Add(Result);
  Result.ParamType:=AParamType;
  Result.ParamName:=AParamName;
  Result.ParamValue:=AParamValue;
end;

{ TLRZConnection }

procedure TLRZConnection.SetDatabase(AValue: string);
begin
  FZConnection.Database:=AValue;
end;

function TLRZConnection.GetDatabase: string;
begin
  Result:=FZConnection.Database;
end;

function TLRZConnection.GetConnected: Boolean;
begin
  Result:=FZConnection.Connected;
end;

function TLRZConnection.GetHostName: string;
begin
  Result:=FZConnection.HostName;
end;

function TLRZConnection.GetLoginPrompt: Boolean;
begin
  Result:=FZConnection.LoginPrompt;
end;

function TLRZConnection.GetPassword: string;
begin
  Result:=FZConnection.Password;
end;

function TLRZConnection.GetPort: Integer;
begin
  Result:=FZConnection.Port;
end;

function TLRZConnection.GetProtocol: string;
begin
  Result:=FZConnection.Protocol;
end;

function TLRZConnection.GetUser: string;
begin
  Result:=FZConnection.User;
end;

procedure TLRZConnection.SetConnected(AValue: Boolean);
begin
  FZConnection.Connected:=AValue;
end;

procedure TLRZConnection.SetHostName(AValue: string);
begin
  FZConnection.HostName:=AValue;
end;

procedure TLRZConnection.SetLoginPrompt(AValue: Boolean);
begin
  FZConnection.LoginPrompt:=AValue;
end;

procedure TLRZConnection.SetPassword(AValue: string);
begin
  FZConnection.Password:=AValue;
end;

procedure TLRZConnection.SetPort(AValue: Integer);
begin
  FZConnection.Port:=AValue;
end;

procedure TLRZConnection.SetProtocol(AValue: string);
begin
  FZConnection.Protocol:=AValue;
end;

procedure TLRZConnection.SetUser(AValue: string);
begin
  FZConnection.User:=AValue;
end;

procedure TLRZConnection.SetName(const AValue: string);
begin
  inherited SetName(AValue);
  FZConnection.Name:=Name;
end;

procedure TLRZConnection.AfterLoad;
begin
  inherited AfterLoad;
  FZConnection.Connected:=FConnected;
end;

constructor TLRZConnection.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  FDesignOptions:=FDesignOptions + [doUndoDisable];
  BaseName := 'LRZConnection';
  FZConnection:=TZConnection.Create(OwnerForm);
end;

destructor TLRZConnection.Destroy;
begin
  if not (Assigned(OwnerPage) and (OwnerPage is TfrPageDialog)) then
  begin
    FreeAndNil(FZConnection);
  end;
  inherited Destroy;
end;

procedure TLRZConnection.LoadFromXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited LoadFromXML(XML, Path);
  FZConnection.Port:=XML.GetValue(Path + 'Connected/Value'{%H-}, 0);
  FZConnection.LoginPrompt:=XML.GetValue(Path + 'LoginPrompt/Value'{%H-}, false);
  FZConnection.Protocol:=XML.GetValue(Path + 'Protocol/Value'{%H-}, '');

  FZConnection.HostName:=XML.GetValue(Path + 'HostName/Value'{%H-}, '');
  FZConnection.Database:=XML.GetValue(Path + 'Database/Value'{%H-}, '');
  FZConnection.User:=XML.GetValue(Path + 'User/Value'{%H-}, '');
  FZConnection.Password:=XML.GetValue(Path + 'Password/Value'{%H-}, '');
  FConnected:=XML.GetValue(Path + 'Connected/Value'{%H-}, false);
end;

procedure TLRZConnection.SaveToXML(XML: TLrXMLConfig; const Path: String);
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path + 'Connected/Value'{%H-}, FZConnection.Port);
  XML.SetValue(Path + 'LoginPrompt/Value'{%H-}, FZConnection.LoginPrompt);
  XML.SetValue(Path + 'Protocol/Value'{%H-}, FZConnection.Protocol);

  XML.SetValue(Path + 'HostName/Value'{%H-}, FZConnection.HostName);
  XML.SetValue(Path + 'Database/Value'{%H-}, FZConnection.Database);
  XML.SetValue(Path + 'User/Value'{%H-}, FZConnection.User);
  XML.SetValue(Path + 'Password/Value'{%H-}, FZConnection.Password);
  XML.SetValue(Path + 'Connected/Value'{%H-}, FZConnection.Connected);
end;

{ TLRZQuery }

procedure TLRZQuery.SetSQL(AValue: string);
begin
  DataSet.Active:=false;
  TZQuery(DataSet).SQL.Text:=AValue;
  DoMakeParams;
  if Assigned(frDesigner) then
    frDesigner.Modified:=true;
end;

procedure TLRZQuery.SetDataSource(AValue: string);
var
  D:TComponent;
begin
  inherited SetDataSource(AValue);
  D:=frFindComponent(OwnerForm, AValue);
  if D is TDataSource then
    TZQuery(DataSet).DataSource:=TDataSource(D);
end;

procedure TLRZQuery.AfterLoad;
var
  D:TComponent;
  SPage: String;
  S: String;
  Z: TLRZConnection;
begin
  D:=frFindComponent(OwnerForm, DataSource);
  if D is TDataSource then
    TZQuery(DataSet).DataSource:=TDataSource(D);

  D:=frFindComponent(DataSet.Owner, FDatabase);
  if D is TZConnection then
  begin
    TZQuery(DataSet).Connection:=TZConnection(D);
    DataSet.Active:=FActive;
  end
  else
  if Assigned(CurReport) then
  begin
    S:=FDatabase;
    if Pos('.', S)>0 then
      SPage:=Copy2SymbDel(S, '.')
    else
      SPage:='';
    Z:=CurReport.FindObject(S) as TLRZConnection;
    if Assigned(Z) then
    begin
      TZQuery(DataSet).Connection:=Z.FZConnection;
      DataSet.Active:=FActive;
    end
  end;
end;

procedure TLRZQuery.SetDatabase(AValue: string);
var
  D:TComponent;
begin
  if FDatabase=AValue then Exit;
  FDatabase:=AValue;

  DataSet.Active:=false;
  D:=frFindComponent(TZQuery(DataSet).Owner, FDatabase);
  if D is TZConnection then
    TZQuery(DataSet).Connection:=TZConnection(D)
end;

procedure TLRZQuery.ZQueryBeforeOpen(ADataSet: TDataSet);
var
  i: Integer;
  s: String;
  SaveView: TfrView;
  SavePage: TfrPage;
  SaveBand: TfrBand;
  Q:TZQuery;
  P:TQueryParam;
begin
  Q:=TZQuery(DataSet);
  SaveView := CurView;
  SavePage := CurPage;
  SaveBand := CurBand;

  CurView := Self;
  CurPage := OwnerPage;
  CurBand := nil;

  for i := 0 to Q.Params.Count - 1 do
  begin
    S:=Q.Params[i].Name;
    P:=FParams.ParamByName(S);
    if Assigned(P) and (P.ParamValue <> '') and (DocMode = dmPrinting) then
    begin
      case P.ParamType of
        ftDate,
        ftDateTime:Q.Params[i].AsDateTime := frParser.Calc(P.ParamValue);
        ftInteger:Q.Params[i].AsInteger := frParser.Calc(P.ParamValue);
        ftFloat:Q.Params[i].AsFloat := frParser.Calc(P.ParamValue);
        ftString:Q.Params[i].AsString := frParser.Calc(P.ParamValue);
      else
        Q.Params[i].Value := frParser.Calc(P.ParamValue);
      end;
    end;
  end;

  if Assigned(Q.Connection) then
    if not Q.Connection.Connected then Q.Connection.Connect;

  CurView := SaveView;
  CurPage := SavePage;
  CurBand := SaveBand;
end;

procedure TLRZQuery.DoMakeParams;
var
  Q:TZQuery;
  i:integer;
begin
  Q:=TZQuery(DataSet);
  if Q.Params.Count > 0 then
  begin
    //Add new params...
    for i:=0 to Q.Params.Count-1 do
    begin
      if not Assigned(FParams.ParamByName(Q.Params[i].Name)) then
        FParams.Add(ftUnknown, Q.Params[i].Name, '');
    end;

    //Delete not exists params
    for i:=FParams.Count-1 downto 0 do
    begin
      if not Assigned(Q.Params.FindParam(TQueryParam(FParams[i]).ParamName)) then
        FParams.Delete(i);
    end;
  end
  else
    FParams.Clear;
end;

procedure TLRZQuery.DoEditParams;
begin
  lrEditParamsForm:=TlrEditParamsForm.Create(Application);
  lrEditParamsForm.LoadParamList(FParams);
  if lrEditParamsForm.ShowModal = mrOk then
  begin
    lrEditParamsForm.SaveParamList(FParams);
    if Assigned(frDesigner) then
      frDesigner.Modified:=true;
  end;
  lrEditParamsForm.Free;
end;

function TLRZQuery.GetSQL: string;
begin
  Result:=TZQuery(DataSet).SQL.Text;
end;

constructor TLRZQuery.Create(AOwnerPage: TfrPage);
begin
  inherited Create(AOwnerPage);
  BaseName := 'lrZQuery';
  FParams:=TQueryParamList.Create;

  DataSet:=TZQuery.Create(OwnerForm);
  DataSet.BeforeOpen:=@ZQueryBeforeOpen;
end;

destructor TLRZQuery.Destroy;
begin
  FreeAndNil(FParams);
  inherited Destroy;
end;

function StrToFieldType(const AStrTypeName:string):TFieldType;
var
  i:TFieldType;
begin
  Result:=ftUnknown;
  for i in TFieldType do
  begin
    if CompareText(Fieldtypenames[i], AStrTypeName) = 0 then
    begin
      Result:=i;
      exit;
    end;
  end;
end;

procedure TLRZQuery.LoadFromXML(XML: TLrXMLConfig; const Path: String);
var
  C, I:integer;
begin
  inherited LoadFromXML(XML, Path);
  TZQuery(DataSet).SQL.Text:=XML.GetValue(Path+'SQL/Value'{%H-}, '');
  FDatabase:= XML.GetValue(Path+'Database/Value'{%H-}, '');


  C:=XML.GetValue(Path+'Params/Count/Value', 0);
  for i:=0 to C-1 do
    FParams.Add(
        StrToFieldType(XML.GetValue(Path+'Params/Item'+IntToStr(i)+'/ParamType', '')),
        XML.GetValue(Path+'Params/Item'+IntToStr(i)+'/Name', ''),
        XML.GetValue(Path+'Params/Item'+IntToStr(i)+'/Value', '')
        );
end;

procedure TLRZQuery.SaveToXML(XML: TLrXMLConfig; const Path: String);
var
  i:integer;
  P:TQueryParam;
begin
  inherited SaveToXML(XML, Path);
  XML.SetValue(Path+'SQL/Value', TZQuery(DataSet).SQL.Text);
  XML.SetValue(Path+'Database/Value', FDatabase);

  XML.SetValue(Path+'Params/Count/Value', FParams.Count);
  for i:=0 to FParams.Count-1 do
  begin
    P:=TQueryParam(FParams[i]);
    XML.SetValue(Path+'Params/Item'+IntToStr(i)+'/Name', P.ParamName);
    XML.SetValue(Path+'Params/Item'+IntToStr(i)+'/Value', P.ParamValue);
    XML.SetValue(Path+'Params/Item'+IntToStr(i)+'/ParamType', Fieldtypenames[P.ParamType]);
  end;
end;


type

  { TLRZQueryParamsProperty }

  TLRZQueryParamsProperty = class(TPropertyEditor)
  public
    function  GetAttributes: TPropertyAttributes; override;
    function GetValue: ansistring; override;
    procedure Edit; override;
  end;

  { TLRZQueryDataBaseProperty }

  TLRZQueryDataBaseProperty = class(TFieldProperty)
  public
    procedure FillValues(const Values: TStringList); override;
  end;

  { TLRZConnectionProtocolProperty }

  TLRZConnectionProtocolProperty = class(TFieldProperty)
  public
    procedure FillValues(const Values: TStringList); override;
  end;


  { TLRZQuerySQLProperty }

  TLRZQuerySQLProperty = class(TStringPropertyEditor)
  public
    function GetAttributes: TPropertyAttributes; override;
    function GetValue: ansistring; override;
    procedure Edit; override;
  end;

{ TLRZQuerySQLProperty }

function TLRZQuerySQLProperty.GetAttributes: TPropertyAttributes;
begin
  Result:=[paDialog, paReadOnly];
end;

function TLRZQuerySQLProperty.GetValue: ansistring;
begin
  Result:='(SQL)';
end;

procedure TLRZQuerySQLProperty.Edit;
var
  TheDialog : TStringsPropEditorDlg;
  AString : string;
begin
  AString := GetStrValue;
  TheDialog := TStringsPropEditorDlg.Create(nil);
  try
    TheDialog.Editor := Self;
    TheDialog.Memo.Text := AString;
    TheDialog.MemoChange(nil);
    if (TheDialog.ShowModal = mrOK) then
    begin
      AString := TheDialog.Memo.Text;
      //erase the last lineending if any
      if Copy(AString, length(AString) - length(LineEnding) + 1, length(LineEnding)) = LineEnding then
        Delete(AString, length(AString) - length(LineEnding) + 1, length(LineEnding));
      SetStrValue(AString);
    end;
  finally
    TheDialog.Free;
  end;
end;

{ TLRZQueryParamsProperty }

function TLRZQueryParamsProperty.GetAttributes: TPropertyAttributes;
begin
  Result:=[paDialog, paReadOnly];
end;

function TLRZQueryParamsProperty.GetValue: ansistring;
begin
  Result:='(Params)';
end;

procedure TLRZQueryParamsProperty.Edit;
begin
  if (GetComponent(0) is TLRZQuery) then
    TLRZQuery(GetComponent(0)).DoEditParams;
end;

{ TLRZConnectionProtocolProperty }

procedure TLRZConnectionProtocolProperty.FillValues(const Values: TStringList);
var
  i, j:integer;
  A:TStringDynArray;
begin
  if (GetComponent(0) is TLRZConnection) and Assigned(DriverManager) then
  begin
    for i:=0 to DriverManager.GetDrivers.GetCount-1 do
    begin
      A:=(DriverManager.GetDrivers.Items[i] as IZDriver).GetSupportedProtocols;
      for j:=Low(A) to High(A) do
        Values.Add(A[j]);
    end;
  end;
end;

{ TLRZQueryDataBaseProperty }
procedure TLRZQueryDataBaseProperty.FillValues(const Values: TStringList);
var
  i: Integer;
  j: Integer;
  S: String;
begin
  if (GetComponent(0) is TLRZQuery) then
  begin
    frGetComponents(nil, TZConnection, Values, nil);

    if Assigned(CurReport) then
    begin
      for i:=0 to CurReport.Pages.Count-1 do
        if CurReport.Pages[i] is TfrPageDialog then
        begin
          for j:=0 to CurReport.Pages[i].Objects.Count-1 do
          begin
            if TfrObject(CurReport.Pages[i].Objects[j]) is TLRZConnection then
            begin
              S:=CurReport.Pages[i].Name+'.'+TLRDataSetControl(CurReport.Pages[i].Objects[j]).lrDBDataSet.Name;
              Values.Add(S);
            end;
          end;
        end;
    end;
  end;
end;


procedure RegisterLR_DB_Zeos;
begin
  RegisterComponents('LazReport',[TlrZeosData]);
end;

procedure Register;
begin
  RegisterUnit('LR_DB_Zeos', @RegisterLR_DB_Zeos);
end;


initialization
  InitLRComp;

  RegisterPropertyEditor(TypeInfo(string), TLRZQuery, 'Database', TLRZQueryDataBaseProperty);
  RegisterPropertyEditor(TypeInfo(string), TLRZQuery, 'SQL', TLRZQuerySQLProperty);

  RegisterPropertyEditor(TypeInfo(TQueryParamList), TLRZQuery, 'Params', TLRZQueryParamsProperty);
  RegisterPropertyEditor(TypeInfo(string), TLRZConnection, 'Protocol', TLRZConnectionProtocolProperty);

finalization
  if Assigned(lrBMP_ZQuery) then
    FreeAndNil(lrBMP_ZQuery);
  if Assigned(lrBMP_ZConnection) then
    FreeAndNil(lrBMP_ZConnection);
end.


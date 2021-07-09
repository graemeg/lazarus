{
 /***************************************************************************
                            pkgregisterbase.pas
                            -------------------


 ***************************************************************************/

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
    Registration of the FCL components used by the IDE.
}
unit PkgRegisterBase;

{$mode objfpc}{$H+}

interface

uses
  LazarusPackageIntf,
{$ifdef mswindows}
  ServiceManager,
{$endif}
  Classes, SysUtils, Process, DB, BufDataset, csvdataset, SimpleIPC, XMLConf, EventLog,
  UTF8Process, ComponentEditors;

procedure RegisterFCLBaseComponents;
procedure RegisterLazUtilsComponents;

implementation

type
  TDatasetRequirements = class(TComponentRequirements)
    procedure RequiredUnits(Units: TStrings); override;
  end;

procedure TDatasetRequirements.RequiredUnits(Units: TStrings);
begin
  { the DB unit is nearly always required for working comfortably with datasets }
  Units.Add('DB');
end;

procedure RegisterDB;
begin                                                   // this bites dbflaz
  RegisterComponents('Data Access',[TDatasource, TBufDataset, TCSVDataset]);
  RegisterComponentRequirements([TBufDataset, TCSVDataset], TDatasetRequirements);
end;

procedure RegisterSimpleIPC;
begin
  RegisterComponents('System',[TSimpleIPCClient, TSimpleIPCServer]);
end;

procedure RegisterXMLConf;
begin
  RegisterComponents('System',[TXMLConfig]);
end;

procedure RegisterEventLog;
begin
  RegisterComponents('System',[TEventLog]);
end;

{$ifdef mswindows}
procedure RegisterServiceManager;
begin
  RegisterComponents('System',[TServiceManager]);
end;
{$endif mswindows}

procedure RegisterProcess;
begin
  RegisterComponents('System',[TProcess]);
end;

procedure RegisterFCLBaseComponents;
begin
  RegisterUnit('DB',@RegisterDB);
  RegisterUnit('SimpleIPC', @RegisterSimpleIPC);
  RegisterUnit('XMLConf',@RegisterXMLConf);
  RegisterUnit('EventLog',@RegisterEventLog);
{$ifdef mswindows}
  RegisterUnit('ServiceManager',@RegisterServiceManager);
{$endif mswindows}
  RegisterUnit('Process',@RegisterProcess);
end;

procedure RegisterUTF8Process;
begin
  RegisterComponents('System',[TProcessUTF8]);
end;

procedure RegisterLazUtilsComponents;
begin
  RegisterUnit('UTF8Process',@RegisterUTF8Process);
end;

initialization
  // register package FCL and LazUtils here to avoid pulling in all units
  // and to keep those package clean of designtime code.
  RegisterPackage('FCL', @RegisterFCLBaseComponents);
  RegisterPackage('LazUtils', @RegisterLazUtilsComponents);

end.


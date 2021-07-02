{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit SQLDBLaz;

{$warn 5023 off : no warning about unused units}
interface

uses
  registersqldb, SQLStringsPropertyEditorDlg, generatesqldlg, SqlDbStrConst, 
  PQTEventMonitor, LazarusPackageIntf;

implementation

procedure Register;
begin
  RegisterUnit('registersqldb', @registersqldb.Register);
end;

initialization
  RegisterPackage('SQLDBLaz', @Register);
end.

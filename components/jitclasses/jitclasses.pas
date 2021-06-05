{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit JitClasses;

{$warn 5023 off : no warning about unused units}
interface

uses
  JitClass, JitHelper, JitTypes, JitRttiWriter, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('JitClasses', @Register);
end.

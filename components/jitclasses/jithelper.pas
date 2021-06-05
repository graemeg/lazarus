(*
This file is distributed under the Lesser GNU General Public License
(see the file COPYING.LGPL) with the following modification:

As a special exception, the copyright holders of this library give you
permission to link this library with independent modules to produce an
executable, regardless of the license terms of these independent modules,
and to copy and distribute the resulting executable under terms of your choice,
provided that you also meet, for each linked independent module, the terms
and conditions of the license of that module. An independent module is a
module which is not derived from or based on this library. If you modify this
library, you may extend this exception to your version of the library, but
you are not obligated to do so. If you do not wish to do so, delete this
exception statement from your version.

If you didn't receive a copy of the file COPYING.LGPL, contact:
      Free Software Foundation, Inc.,
      675 Mass Ave
      Cambridge, MA  02139
      USA
*)
unit JitHelper;

{$mode objfpc}{$H+}
{$ModeSwitch typehelpers}
{$ModeSwitch advancedrecords}
{.$Inline off}

interface

uses
  SysUtils, TypInfo, JitRttiWriter, Rtti;

type

  { TProcCallParamList
    Unified access to params of tkProcVar and tkMethod
  }

  TProcCallParam = record
    ParamName: String;
    ParamFlags: TParamFlags;
    ParamTypeRef: PTypeInfo;
  end;

  TProcCallParamList = record
    Kind:        TTypeKind;
    MethodKind : TMethodKind;
    CC:          TCallConv;
    ResultType:  PTypeInfo;
    ParamCount:  integer;
    Params:      array of TProcCallParam;
  end;

  { TPropDataPointerHelper }

  TPropDataPointerHelper = type helper for PPropData
    function SizeOf: Integer;
  end;

  { TTypeDataPointerHelper }

  TTypeDataPointerHelper = type helper for PTypeData
    function DataSize(AKind: TTypeKind): Integer;
    // for tkClass
    function PtrPropData: PPropData; inline;
  end;

  { TTypeInfoPointerHelper }

  TTypeInfoPointerHelper = type helper for PTypeInfo
    function SizeOf: Integer;
    function PtrPropData: PPropData; inline;
    function DataSize: Integer; inline;
    function IsManaged: boolean; inline;

    // for tkMethod / tkProcVar
    function GetTkMethodData(out ParamList: TProcCallParamList): Boolean;
  end;

implementation

{ TPropDataPointerHelper }

function TPropDataPointerHelper.SizeOf: Integer;
var
  i: SmallInt;
  p: PPropInfo;
begin
  i := Self^.PropCount;
  p := Self^.Prop[0];
  while i > 0 do begin
    p := p^.Next;
    dec(i);
  end;
  Result := pointer(p) - pointer(Self);
end;

{ TTypeDataPointerHelper }

function TTypeDataPointerHelper.DataSize(AKind: TTypeKind): Integer;
begin
  Result := 4;
  case AKind of
    tkInterface, tkInterfaceRaw,
    tkDynArray,
    tkClass,
    tkWString, tkUString, tkAString:
      Result:= sizeof(Pointer);
    tkChar, tkBool:
      Result:=1;
    tkWChar:
      Result:=2;
    tkSet:
      Result := Self^.SetSize; // In ver_3_0 use OrdType
    tkEnumeration,
    tkInteger:
      case Self^.OrdType of
        otSByte,otUByte: Result := 1;
        otSWord,otUWord: Result := 2;
        otSQWord,otUQWord: Result := 8;
      end;
    tkInt64 :
      Result:=8;
    tkQword :
      Result:=8;
    tkMethod:
      Result := SizeOf(TMethod);
    tkProcVar:
      Result := SizeOf(CodePointer);
    tkRecord:
      Result := Self^.RecSize;
  end;
end;

function TTypeDataPointerHelper.PtrPropData: PPropData;
begin
  Result := aligntoptr(pointer(@Self^.UnitName)+Length(Self^.UnitName)+1);
end;

{ TTypeInfoPointerHelper }

function TTypeInfoPointerHelper.SizeOf: Integer;
var
  t: PTypeData;
  pd: PPropData;
begin
  t := GetTypeData(Self);
  case Self^.Kind of
    tkClass: begin
      pd := t.PtrPropData;
      Result := pointer(pd) - pointer(Self) + pd.SizeOf;
    end;
    else begin
      Result := (pointer(t) - pointer(Self)) + system.SizeOf(TTypeData);
    end;
  end;
end;

function TTypeInfoPointerHelper.PtrPropData: PPropData;
begin
  Result := GetTypeData(Self).PtrPropData;
end;

function TTypeInfoPointerHelper.DataSize: Integer;
begin
  Result := GetTypeData(Self).DataSize(Self^.Kind);
end;

function TTypeInfoPointerHelper.IsManaged: boolean;
begin
  Result := Rtti.IsManaged(Self);
end;

function TTypeInfoPointerHelper.GetTkMethodData(out ParamList: TProcCallParamList): Boolean;
type
  PParamFlags = ^TParamFlags;
  PCallConv = ^ TCallConv;
  PProcedureSignature = ^TProcedureSignature;
var
  td: PTypeData;
  Cnt, i: Integer;
  mem: Pointer;
  sig: PProcedureSignature;
  par: PProcedureParam;
begin
  Result := True;
  ParamList.Kind := Self^.Kind;
  td := GetTypeData(Self);
  case Self^.Kind of
  tkMethod: begin
    ParamList.MethodKind := td^.MethodKind;
    Cnt := td^.ParamCount;
    ParamList.ParamCount := Cnt;
    SetLength(ParamList.Params, Cnt);
    mem := @td^.ParamList;
    for i := 0 to Cnt - 1 do begin
      ParamList.Params[i].ParamFlags := PParamFlags(mem)^;
      inc(PParamFlags(mem));
      ParamList.Params[i].ParamName := PShortString(mem)^;
      inc(mem, PByte(mem)^ + 1); // skip shortstring / ParamName
      inc(mem, PByte(mem)^ + 1); // skip shortstring / TypeName
    end;

    if ParamList.MethodKind in [mkFunction, mkClassFunction] then begin
      inc(mem, PByte(mem)^ + 1); // skip shortstring / Result TypeName
      mem := aligntoptr(mem);
      ParamList.ResultType := TypeInfoPtrToPTypeInfo(PTypeInfoPtr(mem)^);
      inc(PTypeInfoPtr(mem));
    end;

    ParamList.CC := PCallConv(mem)^;
    inc(PCallConv(mem));

    mem := AlignTypeData(mem);
    for i := 0 to Cnt - 1 do begin
      ParamList.Params[i].ParamTypeRef := TypeInfoPtrToPTypeInfo(PTypeInfoPtr(mem)^);
      inc(PTypeInfoPtr(mem));
    end;
  end;
  tkProcVar: begin
    sig := @td^.ProcSig;
    if sig^.ResultTypeRef <> nil then
      ParamList.MethodKind := mkFunction
    else
      ParamList.MethodKind := mkProcedure;

    ParamList.CC := sig^.CC;
    ParamList.ResultType:= sig^.ResultType;

    Cnt := sig^.ParamCount;
    ParamList.ParamCount := Cnt;
    SetLength(ParamList.Params, Cnt);

    for i := 0 to Cnt - 1 do begin
      par := sig^.GetParam(i);
      ParamList.Params[i].ParamFlags   := par^.ParamFlags;
      ParamList.Params[i].ParamName    := par^.Name;
      ParamList.Params[i].ParamTypeRef := par^.ParamType;
    end;
  end;
  else
    Result := False;
  end;
end;

end.


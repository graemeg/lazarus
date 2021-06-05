unit Unit1;

{$mode objfpc}{$H+}
{$Inline off}

interface

uses
  Classes, SysUtils, TypInfo, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, LResources, ObjectInspector, PropEdits, ComponentTreeView,
  JitClass, JitTypes, JitHelper, LazLogger;

type

  { TForm1 }

  TForm1 = class(TForm)
    Memo1: TMemo;
    pnlTree: TPanel;
    PnlOI: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    procedure FormCreate(Sender: TObject);
  private
    FComponentTree: TComponentTreeView;
    FPropertyEditorHook: TPropertyEditorHook;
    FPropertyGrid: TOIPropertyGrid;
    FCurComp: TComponent;
    FEmbedObject1, FEmbedObject2: TComponent;
    FTypeLib: TJitTypeLibrary;
    JitCreator1, JitCreator2: TJitClassCreator;
    FFont1, FFont2: TFont;

    function CompareMethodsForEvent(AProcInfo, AEventInfo: PTypeInfo): Boolean;
    function DoCreateMeth(const AName: ShortString; ATypeInfo: PTypeInfo;
      APersistent: TPersistent; const APropertyPath: string): TMethod;
    procedure DoGetCompMeth(InstProp: PInstProp; const Proc: TGetStrProc);
    function DoGetCompMethExists(const AName: String; InstProp: PInstProp;
      var MethodIsCompatible, MethodIsPublished, IdentIsMethod: boolean
      ): boolean;
    procedure DoOIMod(Sender: TObject);
    procedure DoTreeSelChanged(Sender: TObject);
    procedure PopulateOI;
  public
    destructor Destroy; override;

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

type
  { TMyComponent }

  TMyComponent = class(TComponent)
  protected
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
  public
    property ComponentStyle: TComponentStyle read FComponentStyle write FComponentStyle;
  end;

{ TMyComponent }

procedure TMyComponent.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  i: Integer;
begin
  inherited GetChildren(Proc, Root);
  for i := 0 to ComponentCount - 1 do
    Proc(Components[i]);
end;

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  FPropertyEditorHook := TPropertyEditorHook.Create(Self);
  FPropertyEditorHook.AddHandlerModified(@DoOIMod);
  FPropertyEditorHook.AddHandlerGetCompatibleMethods(@DoGetCompMeth);
  FPropertyEditorHook.AddHandlerCompatibleMethodExists(@DoGetCompMethExists);
  FPropertyEditorHook.AddHandlerCreateMethod(@DoCreateMeth);

  FPropertyGrid := TOIPropertyGrid.CreateWithParams(Self, FPropertyEditorHook, AllTypeKinds, 0);
  FPropertyGrid.Align := alClient;
  FPropertyGrid.Width := 150;
  FPropertyGrid.Parent := PnlOI;


  FComponentTree := TComponentTreeView.Create(Self);
  FComponentTree.Parent := pnlTree;
  FComponentTree.Align := alClient;
  FComponentTree.OnSelectionChanged  := @DoTreeSelChanged;

  FComponentTree.PropertyEditorHook:=FPropertyEditorHook;


  PopulateOI;
  FComponentTree.BuildComponentNodes(True);
  FComponentTree.Selected := nil;
end;

procedure TForm1.PopulateOI;
type
  PObject = ^TObject;
var
  JitClass, JitClass2: TComponentClass;
  JitObject, JitObject2: TComponent;
  JitPropReadObj, JitPropFont: TJitProperty;
begin
  FTypeLib := TJitTypeLibrary.Create;
  FTypeLib.AddAlias('integer', 'longint');
  FTypeLib.AddAlias('string', 'ansistring');
  FTypeLib.AddType('TKind', '(k1, k2, k3, k4, k5)');
  FTypeLib.AddType('TPartKind', 'k2..k3');
  FTypeLib.AddType('TKinds', 'set of TKind');
  FTypeLib.AddType('TPartKinds', 'set of TPartKind');
  FTypeLib.AddType('TOthers', '(ok1, ok2, ok3, ok4)');
  FTypeLib.AddClass('TFont', TFont);

  (* JitCreator2 *)

  JitCreator2 := TJitClassCreator.Create(TMyComponent, 'TOtherClass', 'bar');
  JitCreator2.TypeLibrary := FTypeLib;
  JitCreator2.JitProperties.Add('TagInt', 'Integer');
  JitCreator2.JitProperties.Add('TagText', 'WideString');
  JitCreator2.JitProperties.Add('TagChar', 'Char');
  JitCreator2.JitProperties.Add('Meth1', 'function(k1: integer): longint of object');
  JitCreator2.JitProperties.Add('Meth2', 'function(k1: integer): boolean of object');
  JitCreator2.JitMethods.Add('Bad', 'function a(k1: integer): integer', True);

  JitClass2 := TComponentClass(JitCreator2.JitClass);

  // Add to typelib
  FTypeLib.AddClass('TOtherClass', JitClass2);

  (* JitCreator1 *)

  JitCreator1 := TJitClassCreator.Create(TMyComponent, 'TJitClass', 'foo');
  JitCreator1.TypeLibrary := FTypeLib;
  JitCreator1.JitProperties.Add('IntValue', 'Integer');
  JitCreator1.JitProperties.Add('IntDefault_1', 'Integer', True, 1);
  JitCreator1.JitProperties.Add('IntDefault_NoDef', 'Integer', True, 0, True);
  JitCreator1.JitProperties.Add('IntDefault_NotStored', 'Integer', True, 0, False, False);
  JitCreator1.JitProperties.Add('QWordValue', 'QWord');
  JitCreator1.JitProperties.Add('Text', 'AnsiString');
  JitCreator1.JitProperties.Add('OnOff', 'ByteBool');
  JitCreator1.JitProperties.Add('kind', 'TKind');
  JitCreator1.JitProperties.Add('subkind', 'k2..k4');
  JitCreator1.JitProperties.Add('sk_def_k3', 'k2..k4')
    .SetDefaultFromIdent('k3');
  JitCreator1.JitProperties.Add('kinds', 'TKinds');
  JitCreator1.JitProperties.Add('ks_def_k1_k2', 'TKinds')
    .SetDefaultFromIdent('[k1,k2]');
  JitCreator1.JitProperties.Add('partkinds', 'TPartKinds');
  JitCreator1.JitProperties.Add('others', 'TOthers');
  //JitCreator1.JitProperties.Add('UntypedFunc', 'function(k1, k2, k3: integer; bb: array of string; const b; c: char = #0): longint of object');
  JitCreator1.JitProperties.Add('MethodFunc', 'function(k1, k2, k3: integer; bb: array of string; const b: boolean; c: char = #0): longint of object');
  JitCreator1.JitProperties.Add('MethodProc', 'procedure(var k1, k2, k3: integer; bb, cc: array of string; const b: char; c: char = #0) of object');
  JitCreator1.JitProperties.Add('Meth1', 'function(k1: integer): longint of object');
  JitCreator1.JitProperties.Add('Meth2', 'function(k1: integer): boolean of object');
  JitCreator1.JitProperties.Add('Obj', 'TOtherClass');

  // ReadObj is not streamed, because GetChildren does not list it;
  JitPropReadObj := JitCreator1.JitProperties.Add('ReadObj', 'TOtherClass', False); // ReadOnly
  JitPropFont    := JitCreator1.JitProperties.Add('Font', 'TFont');

  JitCreator1.JitMethods.Add('TheFunc1', 'function a(xxk1: integer): integer', True);
  JitCreator1.JitMethods.Add('TheFunc1a', 'function a(k1: longint): integer', True);
  JitCreator1.JitMethods.Add('TheFunc2', 'function a(xxk1: integer): boolean', True);
  JitCreator1.JitMethods.Add('TheFunc2x', 'function a(xxk1, xx2: integer): boolean', True);

  JitClass := TComponentClass(JitCreator1.JitClass);


  (* JitObject // Root Object *)

  JitObject := JitClass.Create(nil);
  JitObject.Name := 'foo';

  FEmbedObject1 := JitClass2.Create(nil);
  FEmbedObject1.Name := 'Embed_1';
  TMyComponent(FEmbedObject1).ComponentStyle := FEmbedObject1.ComponentStyle + [csSubComponent];
  PObject(JitPropReadObj.InstanceDataPointer[JitObject])^ := FEmbedObject1;
  FFont1 := TFont.Create;
  PObject(JitPropFont.InstanceDataPointer[JitObject])^ := FFont1;

  FCurComp := JitObject;

  (* JitObject2 // JitClass1 *)

  JitObject2 := JitClass.Create(JitObject);
  JitObject2.Name := 'bar';

  FEmbedObject2 := JitClass2.Create(nil);
  FEmbedObject2.Name := 'Embed_2';
  TMyComponent(FEmbedObject2).ComponentStyle := FEmbedObject2.ComponentStyle + [csSubComponent];
  PObject(JitPropReadObj.InstanceDataPointer[JitObject2])^ := FEmbedObject2;
  FFont2 := TFont.Create;
  PObject(JitPropFont.InstanceDataPointer[JitObject2])^ := FFont2;

  (* JitObject2 // JitClass2 *)

  JitObject2 := JitClass2.Create(JitObject);
  JitObject2.Name := 'other';

  (* JitObject2 // JitClass2 *)

  JitClass2.Create(JitObject2).Name := 'OtherBar';

  (* --- *)

  FPropertyEditorHook.LookupRoot := JitObject;
  FPropertyGrid.Selection.Clear;
  FPropertyGrid.Selection.Add(JitObject);
  FPropertyGrid.BuildPropertyList;

  DoOIMod(nil);
end;

destructor TForm1.Destroy;
begin
  inherited Destroy;
  FTypeLib.Free;
  FCurComp.Free;
  FEmbedObject1.Free;
  FEmbedObject2.Free;
  FFont1.Free;
  FFont2.Free;

  JitCreator1.Free;
  JitCreator2.Free;
end;

procedure TForm1.DoOIMod(Sender: TObject);
var
  strm, strm2: TMemoryStream;
  Writer: TWriter;
  DestroyDriver: boolean;
  s: AnsiString;
begin
  strm  := TMemoryStream.Create;
  strm2 := TMemoryStream.Create;
        DestroyDriver:=false;
  Writer := CreateLRSWriter(strm, DestroyDriver);
  Writer.WriteRootComponent(FCurComp);
  if DestroyDriver then
    Writer.Driver.Free;
  Writer.Free;

  strm.Position := 0;
  LRSObjectBinaryToText(strm, strm2);
  strm2.Position := 0;

  SetLength(s, strm2.Size);
  strm2.ReadBuffer(s[1], strm2.Size);

  Memo1.Text := s;

  strm.Free;
  strm2.Free;

  FComponentTree.UpdateComponentNodesValues;
end;

type
   tmethodnamerec = packed record
      name : pshortstring;
      addr : codepointer;
   end;

   tmethodnametable = packed record
     count : dword;
     entries : packed array[0..0] of tmethodnamerec;
   end;

   pmethodnametable =  ^tmethodnametable;
procedure TForm1.DoGetCompMeth(InstProp: PInstProp; const Proc: TGetStrProc);
var
  mtable: pmethodnametable;
  ovmt: PVmt;
  i: Integer;
  pname: String;
  Meth: TJitMethod;
begin
  for i := 0 to JitCreator1.JitMethods.Count - 1 do begin
    Meth := JitCreator1.JitMethods[i];
    if CompareMethodsForEvent(Meth.TypeInfo, InstProp^.PropInfo^.PropType) then
      Proc(Meth.Name);
  end;

//  ovmt:=PPVmt(InstProp^.Instance)^;
//debugln([InstProp^.Instance.ClassName,' ',TComponent( InstProp^.Instance).Name]);
//  while assigned(ovmt) do begin
//    mtable := pmethodnametable(ovmt^.vMethodTable);
//    if assigned(mtable) then
//      for i:=0 to mtable^.count-1 do begin
//        {$Push}{$R-}
//        pname := mtable^.entries[i].name^;
//        {$POP}
//        Proc(pname);
//      end;
//    ovmt := ovmt^.vParent;
//  end;
end;

function TForm1.CompareMethodsForEvent(AProcInfo, AEventInfo: PTypeInfo
  ): Boolean;
  function IsTypeComp(t1, t2: PTypeInfo): Boolean;
  var
    d1, d2: PTypeData;
  begin
    Result := (t1 = t2);
    if Result then exit;

    Result := (t1^.Kind = t2^.Kind);
    if not Result then exit;

    d1 := GetTypeData(t1);
    d2 := GetTypeData(t2);
    case t1^.Kind of
    tkInteger,tkChar,tkEnumeration,tkBool,tkWChar,tkSet: begin
        Result := d1^.OrdType = d2^.OrdType;
        if not Result then exit;
        case t1^.Kind of
          tkEnumeration: Result := (t1 = t2); // todo: compare name AND unitname
          tkSet:         Result := (t1 = t2); // todo: compare name AND unitname
        end;
      end;
    tkClass:; // depending on param flag (var, out) must be equal or inherhit
    tkMethod, tkProcVar:; // TODO
    tkArray:; // TODO
    end;
  end;
var
  ParInfo1, ParInfo2: TProcCallParamList;
  i: Integer;
begin
  Result := AProcInfo.GetTkMethodData(ParInfo1);
  Result := Result and AEventInfo.GetTkMethodData(ParInfo2);
  if not Result then
    exit;

  Result := (ParInfo1.Kind       = ParInfo2.Kind) and
            (ParInfo1.MethodKind = ParInfo2.MethodKind) and
            (ParInfo1.CC         = ParInfo2.CC) and
            (ParInfo1.ParamCount = ParInfo2.ParamCount);

  if ParInfo1.MethodKind in [mkFunction, mkClassFunction] then
    Result := Result and
      IsTypeComp(ParInfo1.ResultType, ParInfo2.ResultType);

  if not Result then
    exit;

  Result := False;
  for i := 0 to ParInfo1.ParamCount - 1 do begin
    if ParInfo1.Params[i].ParamFlags <> ParInfo2.Params[i].ParamFlags then
      exit;
    if not IsTypeComp(ParInfo1.Params[i].ParamTypeRef, ParInfo2.Params[i].ParamTypeRef) then
      exit;
  end;
  Result := True;
end;

function TForm1.DoCreateMeth(const AName: ShortString; ATypeInfo: PTypeInfo;
  APersistent: TPersistent; const APropertyPath: string): TMethod;
begin
  Result.Code := FCurComp.MethodAddress(AName);
  Result.Data := FCurComp;
end;

function TForm1.DoGetCompMethExists(const AName: String; InstProp: PInstProp;
  var MethodIsCompatible, MethodIsPublished, IdentIsMethod: boolean): boolean;
var
  Meth: TJitMethod;
begin
   Meth := JitCreator1.JitMethods.Meth[AName];
   Result := (Meth <> nil)
     and CompareMethodsForEvent(Meth.TypeInfo, InstProp^.PropInfo^.PropType);
debugln(['PROC  ', AName,'  ', Result]);

  //Result := InstProp^.Instance.MethodAddress(AName) <> nil;
  MethodIsCompatible := Result;
  MethodIsPublished := Result;
  IdentIsMethod := Result;
end;

procedure TForm1.DoTreeSelChanged(Sender: TObject);
begin
  FPropertyGrid.Selection.Clear;
  FPropertyGrid.Selection.Assign(FComponentTree.Selection);
  FPropertyGrid.BuildPropertyList;
end;

end.


{
 *****************************************************************************
 *                             MUIBaseUnit.pas                               *
 *                              --------------                               *
 *                Base MUI objects and application object                    *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit MUIBaseUnit;

{$mode objfpc}{$H+}
interface

uses
  Classes, dos, SysUtils, Controls, Contnrs, Types, graphics, Math,
  {$ifdef HASAMIGA}
  Exec, AmigaDos, agraphics, Intuition, Utility, Mui, inputevent, KeyMap, diskfont, layers,
  {$if defined(MorphOS) or defined(Amiga68k)}
  AmigaLib,
  {$endif}
  {$endif}
  muiglobal, tagsparamshelper,
  Forms, LCLMessageGlue, lcltype, LMessages, interfacebase, muidrawing;

{.$define CHECKOBJECTS} // reports not freed MUIObjects on exit

type
  TMUICaret = class
    Shown: Boolean;
    Left: Integer;
    Top: Integer;
    Width: Integer;
    Height: Integer;
  end;

  { TMUIObject }

  TMUIObject = class
  private
    //Parent
    FParent: TMUIObject;
    // AWinControl lcl-Object
    FPasObject: TControl;
    FOnDraw: TNotifyEvent;
    FMuiCanvas: TMUICanvas;
    HookList: array of PHook;
  protected
    //Position
    FLeft, FTop, FWidth, FHeight: longint;
    //
    FVisible: Boolean;
    LayoutHook: THook;

    FGrpObj: pObject_;
    procedure ConnectHook(MUIField: PtrUInt; TriggerValue: PtrUInt; HookFunc: THookFunc);
    procedure ConnectHookObject(Obj: PObject_; MUIField: PtrUInt; TriggerValue: PtrUInt; HookFunc: THookFunc);
    procedure SetAttribute(const Tags: array of NativeUInt); overload;
    procedure SetAttribute(Tag: LongWord; Data: NativeUInt); overload;
    procedure SetAttribute(Tag: LongWord; Data: Boolean); overload;
    procedure SetAttribute(Tag: LongWord; Data: Pointer); overload;
    function GetAttribute(Tag: longword): NativeUInt;
    procedure SetAttObj(obje: pObject_; const Tags: array of NativeUInt);
    function GetAttObj(obje: pObject_; Tag: longword): NativeUInt;
    // DoMethod(Params = [MethodID, Parameter for Method ...])
    function DoMethod(const Params: array of NativeUInt): longint;

    procedure SetParent(const AValue: TMUIObject); virtual;

    procedure AddChild(ChildObj: PObject_); virtual;
    procedure RemoveChild(ChildObj: PObject_); virtual;
    procedure SetVisible(const AValue: boolean); virtual;
    function GetVisible: boolean; virtual;
    function GetEnabled: boolean; virtual;
    procedure SetEnabled(const AValue: boolean); virtual;

    procedure SetLeft(ALeft: integer); virtual;
    procedure SetTop(ATop: integer); virtual;
    procedure SetWidth(AWidth: integer); virtual;
    procedure SetHeight(AHeight: integer); virtual;

    function GetTop(): Integer; virtual;
    function GetLeft(): Integer; virtual;
    function GetWidth(): integer; virtual;
    function GetHeight(): integer; virtual;
    procedure InstallHooks; virtual;
    procedure DoReDraw(); virtual;
    procedure DoChildRedraw(); virtual;
    //
    procedure BasicInitOnCreate(); virtual;
    procedure SetScrollbarPos;
    function GetParentWindow: TMUIObject; virtual;
    function GetFocusObject: PObject_; virtual;
  public
    FirstPaint: Boolean;
    EHNode: PMUI_EventHandlerNode;
    FChilds: TObjectList;
    FObject: pObject_;
    BlockRedraw: boolean;
    MUIDrawing: Boolean;
    Caret: TMUICaret;
    LastClick: Int64; // time of the last click -> for double click events
    NumMoves: Integer; // max 3 movements before lastclick is deleted;
    VScroll, HScroll: TMUIObject;
    VScrollPos, HScrollPos: Integer;
    constructor Create(ObjType: longint; const Params: TAParamList); overload; reintroduce; virtual;
    constructor Create(AClassName: PChar; const Tags: TATagList); overload; reintroduce; virtual;
    constructor Create(AClassType: PIClass; const Tags: TATagList); overload; reintroduce; virtual;
    destructor Destroy; override;
    procedure SetOwnSize; virtual;
    procedure Redraw; virtual;
    procedure DoMUIDraw; virtual;
    function GetClientRect: TRect; virtual;
    function GetWindowOffset: Types.TPoint; virtual;
    // scrollbars
    procedure CreateScrollbars;

    class function DoMethodObj(Obje: pObject_; const Params: array of NativeUInt): longint;

    property Parent: TMUIObject read FParent write SetParent;
    property Left: longint read GetLeft write SetLeft;
    property Top: longint read GetTop write SetTop;
    property Width: longint read GetWidth write SetWidth;
    property Height: longint read GetHeight write SetHeight;
    property Obj: pObject_ read FObject write FObject;
    property GrpObj: pObject_ read FGrpObj;
    property PasObject: TControl read FPasObject write FPasObject;
    property Visible: boolean read GetVisible write SetVisible;
    property Enabled: boolean read GetEnabled write SetEnabled;
    property MUICanvas: TMUICanvas read FMUICanvas;
    property FocusObject: PObject_ read GetFocusObject;

    property OnDraw: TNotifyEvent read FOnDraw write FOnDraw;
  end;

  TMUIWinControl = class
    PasObject: TWinControl;
    Parent: TMUIObject;
  end;

  { TMuiArea }

  TMuiArea = class(TMUIObject)
  private
    FCaption: string;
  protected
    FColor: TColor;
    function GetChecked: Boolean; virtual;
    procedure SetChecked(const AValue: Boolean); virtual;
    function GetCaption: string; virtual;
    function GetDragable: boolean; virtual;
    function GetDropable: boolean; virtual;
    function GetEnabled: boolean; override;
    function GetHint: string; virtual;
    function GetTabStop: boolean; virtual;
    procedure SetCaption(const AValue: string); virtual;
    procedure SetDragable(const AValue: boolean); virtual;
    procedure SetDropable(const AValue: boolean); virtual;
    procedure SetEnabled(const AValue: boolean); override;
    procedure SetHint(const AValue: string); virtual;
    procedure SetTabStop(const AValue: boolean); virtual;
    procedure SetColor(const AValue: TColor); virtual;
  public
    FBlockChecked: Boolean;
    property Caption: string read GetCaption write SetCaption;
    property Enabled: boolean read GetEnabled write SetEnabled;
    property Dragable: boolean read GetDragable write SetDragable;
    property Dropable: boolean read GetDropable write SetDropable;
    property Hint: string read GetHint write SetHint;
    property Checked: Boolean read GetChecked write SetChecked;
    property TabStop: boolean read GetTabStop write SetTabStop;
    property Color: TColor read FColor write SetColor;
  end;

  TMUIGroup = class(TMUIArea)

  end;

  { TMUITimer }

  TMUITimer = class
    Func: TWSTimerProc;
    StartTime: Int64;
    InterVal: Int64;
    Handle: THandle;
    function CheckTimer: Boolean;
  end;

  { TMuiApplication }

  TRexxMsgEvent = function(Msg: string; out ReturnMsg: string): LongInt of object;

  TMuiApplication = class(TMUIObject)
  private
    FOnRexxMsg: TRexxMsgEvent;
    FThreadID: TThreadID;
    FTerminated: boolean;
    FSignals: longword;
    FMainWin: pObject_;
    FTimers: TObjectList;
    FInvalidatedObjects: TObjectList;
    FInsidePaint: Boolean;
    InRedrawList: Boolean;
    FRexxHook: THook;
    FObjectsToDestroy: Classes.TList;
    function GetIconified: boolean;
    procedure SetIconified(const AValue: boolean);
    procedure CheckTimer;
    function GotRexxMsg(Param: string; out ReturnText: string): LongInt;
  protected
    procedure AddChild(ChildObj: PObject_); override;
    procedure RemoveChild(ChildObj: PObject_); override;
    procedure InstallHooks; override;
  public
    constructor Create(const Tags: TATagList); overload; reintroduce; virtual;
    destructor Destroy; override;
    procedure DoMUIDraw; override;
    function NewInput(Signals: PLongword): longword;
    procedure ProcessMessages;
    procedure WaitMessages;
    function CreateTimer(Interval: integer; TimerFunc: TWSTimerProc): THandle;
    function DestroyTimer(TimerHandle: THandle): boolean;
    procedure AddInvalidatedObject(AObj: TMUIObject);
    procedure RemInvalidatedObject(AObj: TMUIObject);
    procedure RedrawList;
    procedure AddDestroyObj(DestroyObj: PObject_);
    procedure DestroyPendingObjs;
    //
    property MainWin: pObject_ read FMainWin;
    property Terminated: boolean read FTerminated write FTerminated;
    property Iconified: boolean read GetIconified write SetIconified;
    property InsidePaint: Boolean read FInsidePaint write FInsidePaint;
    property OnRexxMsg: TRexxMsgEvent read FOnRexxMsg write FOnRexxMsg;
  end;

function TColorToImageSpec(ACol: TColor): string;

var
  MUIApp: TMuiApplication;
  UseAmigaAlpha: Boolean = True;
  LCLGroupClass: PIClass;
  LCLClass: PMUI_CustomClass;
  KeyState: Integer = 0;
  CaptureObj: TMUIObject = nil;
  {$ifdef CHECKOBJECTS}
  AllItems: Classes.TList;
  {$endif}
  BlockLayout: Boolean = False;
implementation

uses
  muiformsunit, muistdctrls, muiint;

procedure TMUIObject.ConnectHook(MUIField: PtrUInt; TriggerValue: PtrUInt; HookFunc: THookFunc);
var
  Idx: Integer;
begin
  Idx := Length(HookList);
  SetLength(HookList, Idx + 1);
  New(HookList[Idx]);
  ConnectHookFunction(MUIField, TriggerValue, FObject, Self, HookList[Idx], HookFunc);
end;

procedure TMUIObject.ConnectHookObject(Obj: PObject_; MUIField: PtrUInt; TriggerValue: PtrUInt; HookFunc: THookFunc);
var
  Idx: Integer;
begin
  Idx := Length(HookList);
  SetLength(HookList, Idx + 1);
  New(HookList[Idx]);
  ConnectHookFunction(MUIField, TriggerValue, Obj, Self, HookList[Idx], HookFunc);
end;

function BtnDownFunc(Hook: PHook; Obj: PObject_; Msg: Pointer): LongInt;
var
  MuiObject: TMuiObject;
begin
  Result := 0;
  //writeln('-->btndown');
  if TObject(Hook^.h_Data) is TMuiObject then
  begin
    MuiObject := TMuiObject(Hook^.h_Data);
    Result := LCLSendMouseDownMsg(TControl(MuiObject.PasObject), 0, 0, mbLeft, []);
  end;
  //writeln('<--btndown');
end;

function BtnUpFunc(Hook: PHook; Obj: PObject_; Msg: Pointer): LongInt;
var
  MuiObject: TMuiObject;
begin
  //writeln('-->btnup');
  if TObject(Hook^.h_Data) is TMuiObject then
  begin
    MuiObject := TMuiObject(Hook^.h_Data);
    LCLSendMouseUpMsg(TControl(MuiObject.PasObject), 0, 0, mbLeft, []);
    Result := LCLSendClickedMsg(TControl(MuiObject.PasObject));
  end;
  //writeln('<--btnup');
end;

{ TMUITimer }

function TMUITimer.CheckTimer: Boolean;
var
  t: Int64;
begin
  Result := False;
  t := GetLCLTime;
  if t - StartTime >= Interval then
  begin
    if Assigned(Func) then
      Func;
    StartTime := t;
    Result := True;
  end;
end;

{ TMUIObject }

// search for the parent window (can be many Parent relations)
// or nil if it is not connected to a Window
function TMUIObject.GetParentWindow: TMUIObject;
begin
  Result := Self;
  while Assigned(Result) and (not (Result is TMUIWindow)) do
  begin
    Result := Result.Parent;
  end;
end;

// Object which should get the focus on Set Focus (for combined things)
function TMUIObject.GetFocusObject: PObject_;
begin
  Result := FObject;
end;

procedure TMUIObject.SetParent(const AValue: TMUIObject);
var
  Win: TMUIObject;
begin
  //Writeln(self.classname, 'Set Parent: ', HexStr(AValue));
  if FParent = AValue then
  begin
    //writeln('same');
    Exit;
  end;
  // Unlink the old Parent
  if Assigned(FParent) then
  begin
    // if the Widget is the Focused Control, we have to remove it
    // or we will earn a crash after it gets destroyed or so
    // destroy always make an SetParent(nil)
    Win := GetParentWindow;
    if Win is TMUIWindow then
    begin
      if TMUIWindow(Win).FocusedControl = self then
        TMUIWindow(Win).FocusedControl := nil;
    end;
    if Assigned(Self.Obj) then
      FParent.RemoveChild(Self.obj);
    FParent.FChilds.Remove(Self);
    FParent := nil;
  end;
  // Link the new Parent
  if Assigned(AValue) then
  begin
    //write('  New: ', AValue.Classname, ' assigned: ', Assigned(AValue.FChilds));
    AValue.FChilds.Add(Self);
    if Assigned(Self.Obj) then
      AValue.AddChild(Self.Obj);
    FParent := AValue;
  end;
  //writeln('  done.');
end;

function TMUIObject.GetVisible: boolean;
begin
  //writeln('getvis');
  // Seems ShowMe is Buggy, always returns true
  {$ifdef AROS}
  Result := boolean(GetAttribute(MUIA_ShowMe));
  {$else}
  Result := FVisible;
  {$endif}
end;

procedure TMUIObject.SetVisible(const AValue: boolean);
begin
  if not AValue then
    FirstPaint := True;
  SetAttribute(MUIA_ShowMe, AValue);
  FVisible := AValue;
end;

procedure TMUIObject.SetLeft(ALeft: integer);
begin
  FLeft := ALeft;
  SetScrollbarPos();
  if Assigned(Parent) then
    MUIApp.AddInvalidatedObject(Parent);
end;

procedure TMUIObject.SetTop(ATop: integer);
begin
  FTop := ATop;
  SetScrollbarPos();
  if Assigned(Parent) then
    MUIApp.AddInvalidatedObject(Parent);
end;

procedure TMUIObject.SetWidth(AWidth: integer);
begin
  FWidth := AWidth;
  SetScrollbarPos();
  if Assigned(Parent) then
    MUIApp.AddInvalidatedObject(Parent);
end;

procedure TMUIObject.SetHeight(AHeight: integer);
begin
  FHeight := AHeight;
  SetScrollbarPos();
  if Assigned(Parent) then
    MUIApp.AddInvalidatedObject(Parent);
end;

function TMUIObject.GetTop(): Integer;
begin
  Result := FTop;
end;

function TMUIObject.GetLeft(): Integer;
begin
  Result := FLeft;
end;

function TMUIObject.GetWidth(): integer;
begin
  Result := FWidth;
end;

function TMUIObject.GetHeight(): integer;
begin
  Result := FHeight;
end;

procedure TMUIObject.DoReDraw();
var
  PS: PPaintStruct;

begin
  FMUICanvas.InitCanvas;
  if Assigned(PasObject) then
  begin
    new(PS);
    FillChar(PS^, SizeOf(TPaintStruct), 0);
    PS^.hdc := THandle(Pointer(FMuiCanvas));
    PS^.rcPaint := FMuiCanvas.DrawRect;
    //writeln(self.classname, ' Send paintmessage to ', pasobject.classname);
    MUIApp.InsidePaint := True;
    try
      if not MUIDrawing then
        LCLSendEraseBackgroundMsg(TWinControl(PasObject), PS^.hdc);
      LCLSendPaintMsg(TControl(PasObject), PS^.hdc, PS);
    finally
      MUIApp.InsidePaint := False;
    end;
    Dispose(PS);
  end;
  FMUICanvas.DeInitCanvas;
end;

procedure TMUIObject.DoChildRedraw();
var
  i: integer;
begin
  for i := 0 to FChilds.Count - 1 do
  begin
    if FChilds.Items[i] is TMUIObject then
    begin
      if TMuiObject(FChilds.Items[i]).Visible then
      begin
        //SysDebugln(IntToStr(i) + '. -->'+ FChilds[i].classname+ ' MUI Paint');
        TMuiObject(FChilds[i]).DoMuiDraw;
        //SysDebugln(IntToStr(i) + '. <--'+ FChilds[i].classname + ' MUI Paint');
      end;
    end;
  end;
end;

procedure TMUIObject.DoMUIDraw();
begin
  if Assigned(FObject) and (not BlockRedraw) and Visible then
  begin
    //MUI_Redraw(FObject, MADF_DRAWOBJECT);
    // Hacky, not documented feature :-P Let MUI redraw everything
    //SysDebugln('--> '+ classname+ ' MUI Paint');
    MUI_Redraw(FObject, $805);
    //SysDebugln('<-- '+ classname+ ' MUI Paint');
  end;
end;

function TMUIObject.GetClientRect: TRect;
begin
  Result.Left := GetAttribute(MUIA_InnerLeft);
  Result.Top := GetAttribute(MUIA_InnerTop);
  Result.Right:= FWidth - GetAttribute(MUIA_InnerRight);
  Result.Bottom := FHeight - GetAttribute(MUIA_InnerBottom);
  if Assigned(VSCroll) and Assigned(VScroll) then
  begin
    if VScroll.Visible then
      Result.Right:= Result.Right - VScroll.Width;
    if HScroll.Visible then
      Result.Bottom := Result.Bottom - HScroll.Height;
  end;
end;

function TMUIObject.GetWindowOffset: Types.TPoint;
var
  P: Types.TPoint;
begin
  Result.X := Left;
  Result.Y := Top;
  if Assigned(Parent) then
  begin
    P := Parent.GetWindowOffset;
    Result.X := Result.X + P.X;
    Result.Y := Result.Y + P.Y;
  end;
end;

procedure TMUIObject.SetAttObj(obje: pObject_; const Tags: array of NativeUInt);
var
  TagList: TATagList;
begin
  if Assigned(Obje) then
  begin
    TagList.AddTags(Tags);
    SetAttrsA(obje, TagList);
  end;
end;

function TMUIObject.GetAttObj(obje: pObject_; tag: LongWord): NativeUInt;
var
  Res: NativeUInt;
begin
  Res := 0;
  if Assigned(Obje) then
  begin
    GetAttr(tag, obje, @Res);
    Result := Res;
  end;
end;

class function TMUIObject.DoMethodObj(Obje: pObject_; const Params: array of NativeUInt): longint;
begin
  if Assigned(Obje) then
  begin
    Result := DoMethodA(Obje, @Params);
  end;
end;

function TMUIObject.GetEnabled: boolean;
begin
  Result := not boolean(GetAttribute(MUIA_Disabled));
end;

procedure TMUIObject.SetEnabled(const AValue: boolean);
begin
  SetAttribute(MUIA_Disabled, not AValue);
end;

procedure TMUIObject.SetAttribute(const Tags: array of NativeUInt);
var
  TagList: TATagList;
begin
  if Assigned(FObject) then
  begin
    TagList.AddTags(Tags);
    SetAttrsA(FObject, TagList);
  end;
end;

procedure TMUIObject.SetAttribute(Tag: LongWord; Data: NativeUInt);
var
  Tags: TATagList;
begin
  if Assigned(FObject) then
  begin
    Tags.AddTag(Tag, Data);
    SetAttrsA(FObject, Tags);
  end;
end;

procedure TMUIObject.SetAttribute(Tag: LongWord; Data: Boolean);
var
  TagList: TATagList;
begin
  if Assigned(FObject) then
  begin
    TagList.AddTag(Tag, IfThen(Data, TagTrue, TagFalse));
    SetAttrsA(FObject, TagList);
  end;
end;

procedure TMUIObject.SetAttribute(Tag: LongWord; Data: Pointer);
var
  TagList: TATagList;
begin
  if Assigned(FObject) then
  begin
    TagList.AddTag(Tag, NativeUInt(Data));
    SetAttrsA(FObject, TagList);
  end;
end;

function TMUIObject.GetAttribute(tag: longword): NativeUInt;
var
  Res: NativeUInt;
begin
  Res := 0;
  if Assigned(FObject) then
    GetAttr(tag, FObject, @Res);
  Result := Res;
end;

function TMUIObject.DoMethod(const Params: array of NativeUInt): longint;
begin
  if Assigned(FObject) then
  begin
    Result := DoMethodA(FObject, @Params);
  end;
end;

procedure TMUIObject.AddChild(ChildObj: PObject_);
begin
  if Assigned(ChildObj) then
  begin
    DoMethod([NativeUInt(MUIM_Group_InitChange)]);
    DoMethod([NativeUInt(OM_ADDMEMBER), NativeUInt(ChildObj)]);
    DoMethod([NativeUInt(MUIM_Group_ExitChange)]);
  end;
end;

procedure TMUIObject.RemoveChild(ChildObj: PObject_);
begin
  if Assigned(ChildObj) then
  begin
    //sysdebugln('Remove Child: ' + self.classname +' addr:' + HexStr(FObject));
    //DoMethod([NativeUInt(MUIM_Group_InitChange)]);
    DoMethod([NativeUInt(OM_REMMEMBER), NativeUInt(ChildObj)]);
    //DoMethod([NativeUInt(MUIM_Group_ExitChange)]);
  end;
end;

function PanelLayoutFunc(Hook: PHook; Obj: PObject_; Msg:Pointer): Longint;
var
  LMsg: pMUI_LayoutMsg;
  i: LongInt;
  MUIObj: TMuiObject;
  Miw, Mih: Integer;
begin
  LMsg := Msg;
  Result := LongInt(True);
  MUIObj := TMuiObject(Hook^.h_Data);
  case LMsg^.lm_type of
    MUILM_MINMAX: begin
      begin
        MiW := MUIObj.Width;
        MiH := MUIObj.Height;
        LMsg^.lm_MinMax.MinWidth := 1;
        LMsg^.lm_MinMax.MinHeight := 1;
        LMsg^.lm_MinMax.MaxWidth :=  MUI_MAXMAX;
        LMsg^.lm_MinMax.MaxHeight := MUI_MAXMAX;
        LMsg^.lm_MinMax.DefWidth := MiW;
        LMsg^.lm_MinMax.DefHeight := MiH;
      end;
      TWinControl(MUIObj.PasObject).Realign;
    end;
    MUILM_LAYOUT:
    begin
      for i:= 0 to MUIObj.FChilds.Count - 1 do
      begin
        if MUIObj.FChilds.Items[i] is TMUIObject then
          TMuiObject(MUIObj.FChilds.Items[i]).SetOwnSize;
      end;
    end;
  end;
end;


procedure TMUIObject.InstallHooks;
begin
  //writeln(self.classname, ' create obj ', HexStr(FObject));
  ConnectHook(MUIA_Pressed, TagTrue, @BtnDownFunc);
  ConnectHook(MUIA_Pressed, TagFalse, @BtnUpFunc);
end;

procedure TMUIObject.BasicInitOnCreate();
begin
  {$ifdef CHECKOBJECTS}
  AllItems.Add(Self);
  {$endif}
  Caret := nil;
  EHNode := nil;
  MUIDrawing := False;
  FMUICanvas := TMUICanvas.Create;
  FMUICanvas.MUIObject := self;
  BlockRedraw := False;
  FChilds := TObjectList.Create(False);
  FParent := nil;
  VScroll := nil;
  HSCroll := nil;
  FirstPaint := True;
end;

constructor TMUIObject.Create(ObjType: LongInt; const Params: TAParamList);
begin
  inherited Create;
  BasicInitOnCreate;
  //SysDebugln(self.classname + 'create Type '+  IntToStr(ObjType));
  //writeln(self.classname, ' create obj ', ObjType);
  FObject := MUI_MakeObjectA(ObjType, Params.GetParamPointer);
  if not Assigned(FObject) then
    raise EInvalidOperation.Create(Self.Classname + ': Unable to Create Object Type: ' + IntToStr(ObjType));
  InstallHooks;
  //writeln('create obj: ',self.classname,' addr:', inttoHex(Cardinal(FObject),8));
end;

constructor TMUIObject.Create(AClassName: PChar; const Tags: TATagList);
begin
  inherited Create;
  BasicInitOnCreate();
  //writeln(self.classname, ' create obj class ', AClassName);
  //SysDebugln(self.classname + 'create class ' + AClassName);
  //Tags.DebugPrint;
  FObject := MUI_NewObjectA(AClassName, Tags.GetTagPointer);
  if not Assigned(FObject) then
    raise EInvalidOperation.Create(Self.Classname + ': Unable to Create Object Class: ' + AClassName);
  //writeln('    ----- ');
  InstallHooks;
  //writeln('create class: ',self.classname,' addr:', inttoHex(Cardinal(FObject),8));
end;

constructor TMUIObject.Create(AClassType: PIClass; const Tags: TATagList);
begin
  inherited Create;
  BasicInitOnCreate();
  SetHook(LayoutHook, @PanelLayoutFunc, self);
  Tags.AddTag(MUIA_Group_LayoutHook, NativeUInt(@LayoutHook));
  //SysDebugln(self.classname + 'create Class Type $' + HexStr(AClassType));
  //writeln(self.classname, ' create type');
  FObject := NewObjectA(AClassType, nil, Tags.GetTagPointer);
  if not Assigned(FObject) then
    raise EInvalidOperation.Create(Self.Classname + ': Unable to own Create Object Class');
  if Assigned(FObject) then
    Pointer(INST_DATA(AClassType, Pointer(FObject))^) := Self;
  InstallHooks;
  //writeln('create classtype: ',self.classname,' addr:', inttoHex(Cardinal(FObject),8));
end;

destructor TMUIObject.Destroy;
var
  i: Integer;
  DestroyObj: PObject_;
  OldParent: TMuiObject;
begin
  {$ifdef CHECKOBJECTS}
  AllItems.Remove(Self);
  {$endif}
  //writeln('destroy ', HexStr(PasObject));
  if FocusWidget = HWnd(PasObject) then
    FocusWidget := 0;
  BlockRedraw := True;
  BlockLayout := True;
  //writeln(self.classname, '--> destroy');
  if Assigned(HScroll) then
    HScroll.Free;
  if Assigned(VScroll) then
    VScroll.Free;
  HScroll := nil;
  VScroll := nil;
  //
  DestroyObj := FObject;
  OldParent := FParent;
  FObject := nil;
  //
  //writeln(self.classname, ' 1');
  if Assigned(OldParent) then
    OldParent.RemoveChild(DestroyObj);
  SetParent(nil);
  //writeln(self.classname , ' 2 --- Destroy object ', HexStr(DestroyObj));
  MuiApp.AddDestroyObj(DestroyObj);
  DestroyObj := nil;
  //if Assigned(DestroyObj) then
  //  MUI_DisposeObject(DestroyObj);
  //writeln(self.classname, ' 3 ');
  FChilds.Free;
  FMUICanvas.Free;
  if not (self is TMUIApplication) then
    MUIApp.RemInvalidatedObject(Self);
  for i := 0 to High(HookList) do
  begin
    if Assigned(HookList[i]) then
      Dispose(HookList[i]);
    HookList[i] := nil;
  end;
  SetLength(HookList, 0);
  inherited;
  BlockLayout := False;
  //writeln(self.classname, '<-- muiobject destroy');
end;

procedure TMUIObject.CreateScrollbars;
var
  Tags1, Tags2: TATagList;
begin
  if not Assigned(VScroll) then
  begin
    Tags1.Clear;
    Tags1.AddTags([MUIA_Group_Horiz, TagFalse]);
    VScroll := TMUIScrollBar.Create(Tags1);
    VScroll.PasObject := Self.PasObject;
    VScroll.Parent := self;
    {$ifdef Amiga}
    VScroll.Visible := True;
    {$else}
    VScroll.Visible := False;
    {$endif}
  end;
  //
  if not Assigned(HScroll) then
  begin
    Tags2.Clear;
    Tags2.AddTags([MUIA_Group_Horiz, TagTrue]);
    HScroll := TMUIScrollBar.Create(Tags2);
    HScroll.PasObject := Self.PasObject;
    HScroll.Parent := Self;
    HScroll.Visible := False;
  end;
  if PasObject is TWinControl then
    TWinControl(pasobject).InvalidateClientRectCache(True);
  SetScrollbarPos;
end;

procedure TMUIObject.SetScrollbarPos;
begin
  if Assigned(VScroll) then
  begin
    VScroll.Width := 16;
    VScroll.Left := FWidth - VScroll.Width;
    VScroll.Top := 0;
    VScroll.Height := FHeight;
  end;
  if Assigned(HScroll) then
  begin
    HScroll.Height := 18;
    HScroll.Top := FHeight - HScroll.Height;
    HScroll.Left := 0;
    HScroll.Width := FWidth - 16;
  end;
end;

procedure TMUIObject.SetOwnSize;
var
  i: longint;
  w,h: LongInt;
begin
  //writeln(self.classname, '-->setownsize ', pasobject.classname);
  if not Assigned(FObject) then
    Exit;
  if BlockRedraw or BlockLayout then
    Exit;
  w := Min(FWidth, OBJ_MaxWidth(FObject));
  w := Max(w, OBJ_MinWidth(FObject));
  h := Min(FHeight, OBJ_MaxHeight(FObject));
  h := Max(h, OBJ_MinHeight(FObject));
  //writeln(self.classname,' setsize ', FLeft, ', ', FTop, ' - ', FWidth, ', ', FHeight,' count: ', Fchilds.Count, ' obj ', pasobject.classname);
  MUI_Layout(FObject, FLeft, FTop, w, h, 0);
  //writeln(self.classname, '  setsize done');
  for i := 0 to FChilds.Count - 1 do
  begin
    //writeln(self.classname, '  Child ', i);
    if FChilds.Items[i] is TMUIObject then
      TMuiObject(FChilds.Items[i]).SetOwnSize;
  end;
  //writeln(self.classname, '<--setownsize');
end;


procedure TMUIObject.Redraw;
begin
  if BlockRedraw then
  begin
    Exit;
  end;
  DoMethod([NativeUInt(MUIM_Group_InitChange)]);
  DoMethod([NativeUInt(MUIM_Group_ExitChange)]);
end;

{ TMuiApplication }

function TMuiApplication.GetIconified: boolean;
begin
  Result := boolean(GetAttribute(MUIA_Application_Iconified));
end;

procedure TMuiApplication.SetIconified(const AValue: boolean);
begin
  SetAttribute(MUIA_Application_Iconified, AValue);
end;

procedure TMuiApplication.CheckTimer;
var
  i: Integer;
  Num: Integer;
begin
  i := 0;
  Num := FTimers.Count;
  while i < FTimers.Count do
  begin
    TMUITimer(FTimers.items[i]).CheckTimer;
    if Num = FTimers.Count then
      Inc(i)
    else
      Num := FTimers.Count;
  end;
end;

procedure TMuiApplication.AddChild(ChildObj: PObject_);
begin
  inherited AddChild(ChildObj);
  if FMainWin = nil then
  begin
    FMainWin := ChildObj;
    //SetAttribute(MUIA_Application_Window, ChildObj);
    //CallHook(PHook(OCLASS(FMainWin)), FMainWin,
    //  [PtrInt(MUIM_Notify), PtrInt(MUIA_Window_CloseRequest), TagTrue,
    //  PtrInt(FObject), 2, PtrInt(MUIM_Application_ReturnID),
    //  PtrInt(MUIV_Application_ReturnID_Quit)]);
  end;
end;

procedure TMuiApplication.RemoveChild(ChildObj: PObject_);
begin
  inherited RemoveChild(ChildObj);
  if ChildObj = FMainWin then
  begin
    FMainWin := nil;
    //SetAttribute(MUIA_Application_Window, nil);
  end;
end;

type
  TRexxMsg = record
    rm_Node: TMessage;
    rm_TaskBlock: APTR;
    rm_LibBase: APTR;
    rm_Action: LongInt;
    rm_Result1: LongInt;
    rm_Result2: PtrInt;
    rm_Args: array[0..15] of STRPTR;
    rm_MsgPort: PMsgPort;
    rm_CommAddr: STRPTR;
    rm_FileExt: STRPTR;
    rm_Stdin: BPTR;
    rm_Stdout: BPTR;
    rm_Avail: LongInt;
  end;
  PRexxMsg = ^TRexxMsg;

function RexxHookEvent(Hook: PHook; Obj: PObject_; Msg: Pointer): LongInt;
var
  RexxMsg: PRexxMsg;
  Txt: string;
begin
  Result := 20;
  if Assigned(Msg) then
  begin
    RexxMsg := Msg;
    Txt := '';
    Result := MuiApp.GotRexxMsg(RexxMsg^.rm_Args[0], Txt);
    if Txt <> '' then
    begin
      Txt := Txt + #13#10;
      doswrite(RexxMsg^.rm_Stdout, PChar(Txt), Length(Txt));
    end;
  end;
end;

function TMuiApplication.GotRexxMsg(Param: string; out ReturnText: string): LongInt;
begin
  Result := 20;
  ReturnText := 'Rexx not supported';
  if Assigned(FOnRexxMsg) then
  begin
    ReturnText := '';
    Result := FOnRexxMsg(Param, ReturnText);
  end;
end;


procedure TMuiApplication.InstallHooks;
begin
  SetHook(FRexxHook, @RexxHookEvent, Self);
  SetAttribute(MUIA_Application_RexxHook, PtrUInt(@FRexxHook));
end;

constructor TMuiApplication.Create(const Tags: TATagList);
begin
  FObjectsToDestroy := Classes.TList.Create;
  //
  inherited Create(MUIC_Application, Tags);
  FThreadID := GetThreadId;
  FSignals := 0;
  FTimers := TObjectList.Create;
  FTimers.OwnsObjects := True;
  FInvalidatedObjects := TObjectList.Create;
  FInvalidatedObjects.OwnsObjects := False;
  InRedrawList := False;
end;

destructor TMuiApplication.Destroy;
begin
  FTimers.Free;
  FInvalidatedObjects.Free;
  inherited Destroy;
  DestroyPendingObjs;
  FObjectsToDestroy.Free;
end;

procedure TMuiApplication.DestroyPendingObjs;
var
  i: Integer;
begin
  for i := 0 to FObjectsToDestroy.Count - 1 do
  begin
    MUI_DisposeObject(FObjectsToDestroy[i]);
  end;
  FObjectsToDestroy.Clear;
end;

procedure TMuiApplication.AddDestroyObj(DestroyObj: PObject_);
begin
  if Assigned(DestroyObj) then
    FObjectsToDestroy.Add(DestroyObj);
end;

function TMuiApplication.NewInput(Signals: PLongword): longword;
begin
  Result := DoMethod([NativeUInt(Signals)]);
end;

procedure TMuiApplication.DoMUIDraw;
begin
  //writeln('MUI Draw for application called');
end;

procedure TMuiApplication.ProcessMessages;
begin
  if GetThreadId <> FThreadID then
    SysDebugln('ProcessMessages called inside a Thread');
  RedrawList;
  CheckTimer;
  if PtrInt(DoMethod([MUIM_Application_NewInput, PtrUInt(@FSignals)])) =
    MUIV_Application_ReturnID_Quit then
  begin
    //writeln('got terminate1'); // no need to terminate self, LCL will do it for us
    //Application.Terminate;
    Exit;
  end;
end;

procedure TMuiApplication.WaitMessages;
begin
  if GetThreadId <> FThreadID then
    SysDebugln('ProcessMessages called inside a Thread');
  RedrawList;
  CheckTimer;
  if DoMethod([MUIM_Application_NewInput, PtrUInt(@FSignals)]) =
    MUIV_Application_ReturnID_Quit then
  begin
    //writeln('got terminate2');
    //Application.Terminate;
    Exit;
  end;
  if (FSignals <> 0) then
  begin
    FSignals := CheckSignal(FSignals or SIGBREAKF_CTRL_C);
    if FTerminated or ((FSignals and SIGBREAKF_CTRL_C) <> 0) then
    begin
      //writeln('got terminate3');
      Application.Terminate;
      Exit;
    end;
    Sleep(25);
  end;
  CheckTimer;
end;

function TMuiApplication.CreateTimer(Interval: integer; TimerFunc: TWSTimerProc
  ): THandle;
var
  NewTimer: TMUITimer;
begin
  NewTimer := TMUITimer.create;
  NewTimer.StartTime := GetLCLTime;
  NewTimer.Interval := Interval;
  NewTimer.Func := TimerFunc;
  NewTimer.Handle := THandle(NewTimer);
  FTimers.Add(NewTimer);
  Result := NewTimer.Handle;
end;

function TMuiApplication.DestroyTimer(TimerHandle: THandle): boolean;
begin
  Result := True;
  if TimerHandle <> 0 then
    FTimers.Remove(TObject(TimerHandle));
end;

procedure TMuiApplication.AddInvalidatedObject(AObj: TMUIObject);
var
  Index: Integer;
  PObj: TMUIObject;
begin
  if not Assigned(AObj) then
    Exit;
  PObj := AObj;
  while Assigned(PObj) do
  begin
    Index := FInvalidatedObjects.IndexOf(AObj);
    if Index >= 0 then
      Exit;
    PObj := PObj.Parent;
  end;
  FInvalidatedObjects.Add(AObj);
end;

procedure TMuiApplication.RemInvalidatedObject(AObj: TMUIObject);
var
  Index: Integer;
begin
  if not Assigned(AObj) then
    Exit;
  Index := FInvalidatedObjects.IndexOf(AObj);
  if Index < 0 then
    Exit;
  FInvalidatedObjects.Delete(Index);
end;

procedure TMuiApplication.RedrawList;
var
  ActObj: TMUIObject;
begin
  if InRedrawList then
    Exit;
  InRedrawList := True;
  try
    while FInvalidatedObjects.Count > 0 do
    begin
      ActObj := TMUIObject(FInvalidatedObjects.Items[0]);
      FInvalidatedObjects.Delete(0);
      ActObj.DoMUIDraw;
    end;
  finally
    InRedrawList := False;
  end;
end;


{ TMuiArea }

function TMuiArea.GetChecked: Boolean;
begin
  Result := boolean(GetAttribute(MUIA_Selected));
end;

procedure TMuiArea.SetChecked(const AValue: Boolean);
begin
  if Checked = AValue then
    Exit;
  FBlockChecked := True;
  SetAttribute(MUIA_Selected, AValue);
  FBlockChecked := False;
end;

function TMuiArea.GetCaption: string;
var
  Pc: PChar;
begin
  // removed as long MorphOS Crashes at this point
  //Result := '';
  //Pc := PChar(GetAttribute(MUIA_Text_Contents));
  //if Assigned(PC) then
  Result := FCaption;//string(Pc);
end;

function TMuiArea.GetDragable: boolean;
begin
  Result := boolean(GetAttribute(MUIA_Draggable));
end;

function TMuiArea.GetDropable: boolean;
begin
  Result := boolean(GetAttribute(MUIA_Dropable));
end;

function TMuiArea.GetEnabled: boolean;
begin
  Result := not boolean(GetAttribute(MUIA_Disabled));
end;

function TMuiArea.GetHint: string;
begin
  Result := string(PChar(GetAttribute(MUIA_ShortHelp)));
end;

procedure TMuiArea.SetCaption(const AValue: string);
begin
  FCaption := AValue;
  SetAttribute(MUIA_Text_Contents, PChar(FCaption));
end;

procedure TMuiArea.SetDragable(const AValue: boolean);
begin
  SetAttribute(MUIA_Draggable, AValue);
end;

procedure TMuiArea.SetDropable(const AValue: boolean);
begin
  SetAttribute(MUIA_Dropable, AValue);
end;

procedure TMuiArea.SetEnabled(const AValue: boolean);
begin
  SetAttribute(MUIA_Disabled, not AValue);
end;

procedure TMuiArea.SetHint(const AValue: string);
begin
  SetAttribute(MUIA_ShortHelp, PChar(AValue));
end;

function TMuiArea.GetTabStop: boolean;
begin
  Result := GetAttribute(NativeUInt(MUIA_CycleChain)) <> 0;
end;

procedure TMuiArea.SetTabStop(const AValue: boolean);
begin
  SetAttribute(MUIA_CycleChain, AValue);
end;

function TColorToImageSpec(ACol: TColor): string;
var
  r,g,b: Byte;
begin
  if ACol and $FF000000 <> 0 then
    ACol := Widgetset.GetSysColor((ACol and $1F));
  r := Red(ACol);
  g := Green(ACol);
  b := Blue(ACol);
  Result := '2:' +
    IntToHex(r,2) + IntToHex(r,2) + IntToHex(r,2) + IntToHex(r,2) +',' +
    IntToHex(g,2) + IntToHex(g,2) + IntToHex(g,2) + IntToHex(g,2) +',' +
    IntToHex(b,2) + IntToHex(b,2) + IntToHex(b,2) + IntToHex(b,2);
end;

procedure TMUIArea.SetColor(const AValue: TColor);
var
  ColSet: string;
begin
  FColor := AValue;
  if AValue = clNone then
    exit;
  if FColor = clDefault then
    FColor := clBtnFace;
  if FColor <> clNone then
  begin
    ColSet := TColorToImageSpec(FColor);
    SetAttribute(MUIA_Background, PChar(ColSet));
  end;
end;

{$PACKRECORDS 4}
type
  TehNode = record
    ehn_Node: TNode;
    ehn_Flags: Word;
    ehn_Object: PObject_;
    ehn_Class: PIClass;
    ehn_Events: ULONG;
    ehn_Priority: Byte;
  end;

function RawKeyToKeycode(RawKey: Byte): Word;
const
  TranslTable: array[Byte] of Integer = (
    -1,     // $00
    49,     // $01  1
    50,     // $02  2
    51,     // $03  3
    52,     // $04  4
    53,     // $05  5
    54,     // $06  6
    55,     // $07  7
    56,     // $08  8
    57,     // $09  9
    58,     // $0a  0
    59,         // $0b
    187,        // $0c  //VK_CLEAR?
    VK_Return,      // $0d
    -1,         // $0e
    VK_NUMPAD0,         // $0f
    -1,     // $10
    -1,             // $11
    -1,     // $12  e
    -1,             // $13
    -1,         // $14
    -1,         // $15
    -1,         // $16
    -1,         // $17
    -1,         // $18
    -1,         // $19
    -1,         // $1a
    -1,       // $1b
    -1,         // $1c
    VK_NUMPAD1,         // $1d
    VK_NUMPAD2,         // $1e
    VK_NUMPAD3, //keyModeSwitch,    // $1f
    -1,     // $20  a
    -1,//keyPrior,      // $21
    -1,     // $22  d
    -1,                 // $23
    -1,             // $24
    -1,             // $25
    -1,             // $26
    -1,             // $27
    -1,             // $28
    VK_Select,      // $29
    145,//keyPrintScreen,   // $2a
    146, //keyExecute,      // $2b
    147, //keyPrintScreen,  // $2c
    VK_NUMPAD4,     // $2d
    VK_NUMPAD5,     // $2e
    VK_NUMPAD6,     // $2f
    -1,     // $30
    -1,     // $31
    -1,     // $32
    -1,     // $33  c
    -1,     // $34
    -1,     // $35  b
    -1,     // $36
    -1,     // $37
    188,        // $38
    190,        // $39
    189,            // $3a
    -1,         // $3b
    $6c,            // $3c
    VK_NUMPAD7,         // $3d
    VK_NUMPAD8,         // $3e
    VK_NUMPAD9,         // $3f
    $20,        // $40
    VK_BACK,            // $41
    VK_TAB, // $42
    -1,         // $43
    -1,         // $44
    -1,         // $45
    VK_DELETE,  // $46
    VK_INSERT,  // $47
    VK_PRIOR,       // $48
    VK_NEXT,    // $49
    -1,         // $4a
    VK_F11,             // $4b  'K'
    VK_Up,      // $4c  'L'
    VK_Down,        // $4d  'M'
    VK_Right,       // $4e  'N'
    VK_Left,        // $4f  'O'
    VK_F1,      // $50  'P'
    VK_F2,      // $51  'Q'
    VK_F3,      // $52  'R'
    VK_F4,      // $53  'S'
    VK_F5,      // $54  'T'
    VK_F6,      // $55  'U'
    VK_F7,      // $56  'V'
    VK_F8,      // $57  'W'
    VK_F9,      // $58  'X'
    VK_F10,     // $59  'Y'
    VK_NumLock,     // $5a  'Z'
    VK_DIVIDE,          // $5b  VK_LWIN
    VK_MULTIPLY,            // $5c  VK_RWIN
    VK_SUBTRACT,        // $5d  VK_APPS
    VK_ADD,         // $5e
    VK_Pause,       // $5f  VK_SLEEP
    VK_LShift,      // $60
    VK_LShift,          // $61
    VK_CAPITAL,            // $62
    VK_CONTROL,         // $63
    VK_MENU,            // $64
    $e6,//VK_RMENU,         // $65
    VK_LWIN,            // $66
    VK_RWIN, //VK_P7,       // $67
    -1, //VK_P8,        // $68
    -1, //VK_P9,        // $69
    -1, //VK_PAsterisk, // $6a
    -1, //VK_PPlus,     // $6b
    -1, //VK_PSeparator,    // $6c
    -1, //VK_PMinus,        // $6d
    -1, //VK_PDecimal,  // $6eL
    VK_F12,     // $6f
    VK_Home,        // $70  VK_F1
    VK_End,     // $71  VK_F2
    -1,             // $72  VK_F3
    -1,             // $73  VK_F4
    -1,             // $74  VK_F5
    -1,             // $75  VK_F6
    -1,             // $76  VK_F7
    -1,             // $77  VK_F8
    -1,             // $78  VK_F9
    -1,             // $79  VK_F10
    -1,             // $7a  VK_F11
    VK_F12,     // $7b  VK_F12
    VK_F13,     // $7c  VK_F13
    VK_F14,     // $7d  VK_F14
    VK_F15,     // $7e  VK_F15
    VK_F16,     // $7f  VK_F16
    VK_F17,     // $80  VK_F17
    VK_F18,     // $81  VK_F18
    VK_F19,     // $82  VK_F19
    VK_F20,     // $83  VK_F20
    VK_F21,     // $84  VK_F21
    VK_F22,     // $85  VK_F22
    VK_F23,     // $86  VK_F23
    VK_F24,     // $87  VK_F24
    -1,         // $88
    -1,         // $89
    -1,         // $8a
    -1,         // $8b
    -1,         // $8c
    -1,         // $8d
    -1,         // $8e
    -1,         // $8f
    VK_NumLock,     // $90  VK_NUMLOCK
    VK_Scroll,      // $91  VK_SCROLL
    -1,         // $92  VK_OEM_NEC_EQUAL
    -1,         // $93  VK_OEM_FJ_MASSHOU
    -1,         // $94  VK_OEM_FJ_TOUROKU
    -1,         // $95  VK_OEM_FJ_LOYA
    -1,         // $96  VK_OEM_FJ_ROYA
    -1,         // $97
    -1,         // $98
    -1,         // $99
    -1,         // $9a
    -1,         // $9b
    -1,         // $9c
    -1,         // $9d
    -1,         // $9e
    -1,         // $9f
    -1, //VK_ShiftL,        // $a0  VK_LSHIFT
    -1, //VK_ShiftR,        // $a1  VK_RSHIFT
    -1, //VK_CtrlL,     // $a2  VK_LCONTROL
    -1, //VK_CtrlR,     // $a3  VK_RCONTROL
    -1,         // $a4  VK_LMENU
    -1,         // $a5  VK_RMENU
    -1,         // $a6  VK_BROWSER_BACK
    -1,         // $a7  VK_BROWSER_FORWARD
    -1,         // $a8  VK_BROWSER_REFRESH
    -1,         // $a9  VK_BROWSER_STOP
    -1,         // $aa  VK_BROWSER_SEARCH
    -1,         // $ab  VK_BROWSER_FAVORITES
    -1,         // $ac  VK_BROWSER_HOME
    -1,         // $ad  VK_VOLUME_MUTE
    -1,         // $ae  VK_VOLUME_DOWN
    -1,         // $af  VK_VOLUME_UP
    -1,         // $b0  VK_MEDIA_NEXT_TRACK
    -1,         // $b1  VK_MEDIA_PREV_TRACK
    -1,         // $b2  VK_MEDIA_STOP
    -1,         // $b3  VK_MEDIA_PLAY_PAUSE
    -1,         // $b4  VK_LAUNCH_MAIL
    -1,         // $b5  VK_LAUNCH_MEDIA_SELECT
    -1,         // $b6  VK_LAUNCH_APP1
    -1,         // $b7  VK_LAUNCH_APP2
    -1,         // $b8
    -1,         // $b9
    -1, {U Umlaut}  // $ba  VK_OEM_1
    -1, {+ char}    // $bb  VK_OEM_PLUS
    -1, {, char}    // $bc  VK_OEM_COMMA
    -1, {- char}    // $bd  VK_OEM_MINUS
    -1, {. char}    // $be  VK_OEM_PERIOD
    -1, {# char}    // $bf  VK_OEM_2
    -1, {O Umlaut}  // $c0  VK_OEM_3
    -1,         // $c1
    -1,         // $c2
    -1,         // $c3
    -1,         // $c4
    -1,         // $c5
    -1,         // $c6
    -1,         // $c7
    -1,         // $c8
    -1,         // $c9
    -1,         // $ca
    -1,         // $cb
    -1,         // $cc
    -1,         // $cd
    -1,         // $ce
    -1,         // $cf
    -1,         // $d0
    -1,         // $d1
    -1,         // $d2
    -1,         // $d3
    -1,         // $d4
    -1,         // $d5
    -1,         // $d6
    -1,         // $d7
    -1,         // $d8
    -1,         // $d9
    -1,         // $da
    -1,         // $db  VK_OEM_4
    -1, //VK_DeadCircumflex,    // $dc  VK_OEM_5
    -1, //VK_DeadAcute, // $dd  VK_OEM_6
    -1, {A Umlaut}  // $de  VK_OEM_7
    -1,             // $df  VK_OEM_8
    -1,         // $e0
    -1,         // $e1  VK_OEM_AX
    -1, {< char}    // $e2  VK_OEM_102
    -1,         // $e3  VK_ICO_HELP
    -1, //VK_P5,        // $e4  VK_ICO_00
    -1,         // $e5  VK_PROCESSKEY
    -1,         // $e6  VK_ICO_CLEAR
    -1,         // $e7  VK_PACKET
    -1,         // $e8
    -1,         // $e9  VK_OEM_RESET
    -1,         // $ea  VK_OEM_JUMP
    -1,         // $eb  VK_OEM_PA1
    -1,         // $ec  VK_OEM_PA2
    -1,         // $ed  VK_OEM_PA3
    -1,         // $ee  VK_OEM_WSCTRL
    -1,         // $ef  VK_OEM_CUSEL
    -1,         // $f0  VK_OEM_ATTN
    -1,         // $f1  VK_OEM_FINISH
    -1,         // $f2  VK_OEM_COPY
    -1,         // $f3  VK_OEM_AUTO
    -1,         // $f4  VK_OEM_ENLW
    -1,         // $f5  VK_OEM_BACKTAB
    -1,         // $f6  VK_ATTN
    -1,         // $f7  VK_CRSEL
    -1,         // $f8  VK_EXSEL
    -1,         // $f9  VK_EREOF
    -1,         // $fa  VK_PLAY
    -1,         // $fb  VK_ZOOM
    -1,         // $fc  VK_NONAME
    -1,         // $fd  VK_PA1
    -1,         // $fe  VK_OEM_CLEAR
    -1          // $ff
  );
begin
  Result := 0;
  if TranslTable[RawKey]  = -1 then
    Result := 0
  else
    Result := TranslTable[RawKey];
  //writeln('tranbslate Key ', RawKey, ' $',IntToHex(RawKey, 2),' -> ', Result);
end;

function KeyboardShiftState(State: Word): PtrInt;
begin
  Result := 0;
  if State and IEQUALIFIER_LALT <> 0 then
    Result := Result or MK_ALT;
  //if State and IEQUALIFIER_RALT <> 0 then
  //  Result := Result or MK_ALT;
  //writeln('ShiftState AROS: ', HexStr(Pointer(State)), ' and ', HexStr(Pointer(IEQUALIFIER_LALT)),' -> ', HexStr(Pointer(Result)));
end;


{ ######################################################################
  DRAW Event for Dispatcher}
function DrawEvent(cl: PIClass; Obj: PObject_; Msg: intuition.PMsg): longword;
var
  MUIB: TMUIObject;
  Buffered: Boolean;
  ri: PMUI_RenderInfo;
  rp: PRastPort;
  li: pLayer_Info;
  clip: Pointer;
  WithScrollbars: Boolean;
  PaintX, PaintY: Integer;
  PaintH, PaintW: Integer;
begin
  MUIB := TMUIObject(INST_DATA(cl, Pointer(obj))^);
  //sysdebugln('->>DRAW');
  //if (PMUIP_Draw(msg)^.Flags and MADF_DRAWOBJECT = 0) then
  // Exit;
  Buffered := True;
  rp := nil;
  ri := MUIRenderInfo(Obj);
  if Assigned(ri) then
    rp := ri^.mri_RastPort;
  if Assigned(rp) then
  begin
    MUIB := TMUIObject(INST_DATA(cl, Pointer(obj))^);
    clip := MUI_AddClipping(ri, Obj_Left(obj), Obj_top(Obj),
        Obj_Width(Obj), Obj_Height(Obj));
    try
      if Assigned(MUIB) then
      begin
        if MUIB.FirstPaint and (MUIB is TMUIGroupBox) then
        begin
          MUIB.FirstPaint := False;
          TWinControl(MUIB.pasobject).InvalidateClientRectCache(True);
        end;
        //writeln('-->Draw ', muib.classname, ' ', HexStr(MUIB.FMUICanvas));
        //if MUIB.MUIDrawing then
        WithScrollbars := Assigned(MUIB.VScroll) and Assigned(MUIB.HScroll);
        //
        if (MUIB.FChilds.Count = 0) or ((MUIB.FChilds.Count = 2) and WithScrollbars) then
        begin
          //PMUIP_Draw(msg)^.Flags := MADF_DRAWOBJECT;
          //Result := DoSuperMethodA(cl, obj, msg);
          if MUIB.MUIDrawing then
            Result := DoSuperMethodA(cl, obj, msg);
        end else
        begin
          {.$ifndef MorphOS} // makes strong flicker on MorphOS
          if MUIB is TMuiGroup then
            Result := DoSuperMethodA(cl, obj, msg);
          {.$endif}
        end;
          //Result := DoSuperMethodA(cl, obj, msg);
        Buffered := True; //not MUIB.MUIDrawing;//(MUIB.FChilds.Count = 0) or ((MUIB.FChilds.Count = 2) and WithScrollbars);
        if MUIB is TMUIWindow then
        begin
          PaintX := Obj_Left(Obj);
          PaintY := Obj_Top(Obj);
          PaintW := Obj_Width(Obj);
          PaintH := Obj_Height(Obj);
        end else
        begin
          PaintX := Obj_MLeft(Obj);
          PaintY := Obj_MTop(Obj);
          PaintW := Obj_MWidth(Obj);
          PaintH := Obj_MHeight(Obj);
        end;
        // make sure we stay inside the window (MOS/Amiga need this)
        PaintW := Min(PaintW, (ri^.mri_Window^.Width - PaintX) - ri^.mri_Window^.BorderRight);
        PaintH := Min(PaintH, (ri^.mri_Window^.Height - PaintY) - ri^.mri_Window^.BorderBottom);
        //
        if WithScrollbars then
        begin
          if MUIB.VScroll.Visible then
            PaintW := PaintW - MUIB.VScroll.Width;
          If MUIB.HScroll.Visible then
            PaintH := PaintH - MUIB.HScroll.Height;
          //writeln('-->Draw ', muib.classname, ' ', HexStr(MUIB.FMUICanvas));
        end;
        if Buffered then
        begin
          MUIB.FMUICanvas.DrawRect := Rect(0, 0, PaintW, PaintH);
          MUIB.FMUICanvas.RastPort := CreateRastPortA;
          li := NewLayerInfo();
          MUIB.FMUICanvas.RastPort^.Bitmap := AllocBitMap(PaintW, PaintH, rp^.Bitmap^.Depth, BMF_MINPLANES or BMF_DISPLAYABLE, rp^.Bitmap);
          MUIB.FMUICanvas.RastPort^.Layer := CreateUpFrontHookLayer(li, MUIB.FMUICanvas.RastPort^.Bitmap, 0, 0, PaintW - 1, PaintH - 1, LAYERSIMPLE, nil, nil);
          ClipBlit(rp, PaintX, PaintY, MUIB.FMUICanvas.RastPort, 0, 0, PaintW, PaintH, $00C0);
        end else
        begin
          MUIB.FMUICanvas.RastPort := rp;
          MUIB.FMUICanvas.DrawRect :=
              Rect(PaintX, PaintY, PaintW, PaintH);
        end;
        MUIB.FMUICanvas.Offset.X := 0;
        MUIB.FMUICanvas.Offset.Y := 0;
        MUIB.FMUICanvas.Position.X := 0;
        MUIB.FMUICanvas.Position.Y := 0;
        MUIB.FMUICanvas.RenderInfo := ri;
        MUIB.FMUICanvas.DeInitCanvas;
        MUIB.FMUICanvas.InitCanvas;
        //writeln('-->Draw ', MUIB.FMUICanvas.DrawRect.Top, ', ', MUIB.FMUICanvas.DrawRect.Bottom);
        MUIB.DoRedraw;
        if Assigned(MUIB.FOnDraw) then
        begin
          MUIB.FOnDraw(MUIB);
        end;
        MUIB.FMUICanvas.DeInitCanvas;
        if Buffered and Assigned(MUIB.FMUICanvas.RastPort) then
        begin
          ClipBlit(MUIB.FMUICanvas.RastPort, 0,0, rp, PaintX, PaintY, PaintW, PaintH, $00C0);
          DeleteLayer(0, MUIB.FMUICanvas.RastPort^.layer);
          DisposeLayerInfo(li);
          MUIB.FMUICanvas.RastPort^.layer := nil;
          FreeBitmap(MUIB.FMUICanvas.RastPort^.Bitmap);
          FreeRastPortA(MUIB.FMUICanvas.RastPort);
          MUIB.FMUICanvas.RastPort := nil;
        end;
        //writeln('<--Draw ', muib.classname);
      end;
    finally
      MUI_RemoveClipRegion(ri, clip);
      MUIB.FMUICanvas.RastPort := nil;
    end;
    MUIB.DoChildRedraw();
  end;
  Result := 0;
end;
{END Draw event
########################################################################}

const
  MUI_EHF_GUIMODE = 1 shl 1;

function Dispatcher(cl: PIClass; Obj: PObject_; Msg: intuition.PMsg): longword;
var
  MUIB: TMUIObject;
  MUIParent: TMUIObject;
  p: TMUIObject;
  HEMsg: PMUIP_HandleEvent;
  ri: PMUI_RenderInfo;
  iMsg: PIntuiMessage;
  winObj: PObject_;
  relX, relY: Integer;
  Buff: array[0..19] of Char;
  Ret: Integer;
  CharCode: Word;
  KeyData: PtrInt;
  KeyUp: Boolean;
  ie: TInputEvent;
  Win: PWindow;
  CurTime: Int64;
  MUIWin: TMUIWindow;
  IsSysKey: Boolean;
  EatEvent: Boolean;
  Key: Char;
  i: Integer;
  {$ifdef AmigaOS4}
  data: PIntuiWheelData;
  {$endif}
begin
  Result := 0;
  MUIB := nil;
  MUIWin := nil;
  //write('Enter Dispatcher with: ', Msg^.MethodID);
  case Msg^.MethodID of
// ################# Setup EVENT #######################################
    MUIM_SETUP: begin
      //writeln(' setup');
      Result := DoSuperMethodA(cl, obj, msg);
      MUIB := TMUIObject(INST_DATA(cl, Pointer(obj))^);
      if Assigned(MUIB) then
      begin
        New(MUIB.EHNode);
        FillChar(MUIB.EHNode^, SizeOf(MUIB.EHNode^), 0);
        P := MUIB;
        MUIB.EHNode^.ehn_Priority := Byte(-100);
        repeat
          Inc(MUIB.EHNode^.ehn_Priority);
          p := p.Parent;
        until P = nil;

        MUIB.EHNode^.ehn_Flags := MUI_EHF_GUIMODE;
        MUIB.EHNode^.ehn_Object := obj;
        MUIB.EHNode^.ehn_Class := cl;
        MUIB.EHNode^.ehn_Events := IDCMP_MOUSEBUTTONS or IDCMP_MOUSEMOVE or IDCMP_RAWKEY;
        {$ifdef AmigaOS4}
        MUIB.EHNode^.ehn_Events := MUIB.EHNode^.ehn_Events or IDCMP_EXTENDEDMOUSE;
        {$endif}
        winObj := OBJ_win(obj);
        ri := MUIRenderInfo(Obj);
        WinObj := ri^.mri_WindowObject;
        DoMethod(WinObj, [MUIM_Window_AddEventHandler, NativeUInt(MUIB.EHNode)]);

        //MUIB.SetAttObj(Obj, [MUIA_FillArea, LFalse]);
      end;
      //MUI_RequestIDCMP(Obj, IDCMP_MOUSEBUTTONS);
    end;
// ################# Cleanup EVENT #####################################
    MUIM_CLEANUP: begin
      //write(' cleanup');
      MUIB := TMUIObject(INST_DATA(cl, Pointer(obj))^);
      if Assigned(MUIB) then
      begin
        DoMethod(OBJ_win(obj), [MUIM_Window_RemEventHandler, NativeUInt(MUIB.EHNode)]);
        Dispose(MUIB.EHNode);
        MUIB.EHNode := nil;
      end;
      Result := DoSuperMethodA(cl, obj, msg);
      //MUI_RejectIDCMP(Obj, IDCMP_MOUSEBUTTONS);
    end;
// ################# DRAW EVENT ########################################
    MUIM_Draw:
    begin
      Result := DrawEvent(cl, obj, Msg);
    end;
// ################# Handle EVENT ######################################
    MUIM_HANDLEEVENT: begin
      Result := 0;
      MUIB := TMUIObject(INST_DATA(cl, Pointer(obj))^);
      Win := nil;
      ri := MUIRenderInfo(Obj);
      if Assigned(ri) then
        Win := ri^.mri_Window;
      if Assigned(MUIB) and Assigned(MUIB.PasObject) and Assigned(MUIB.Parent) then
      begin
        HEMsg := Pointer(Msg);
        iMsg := HeMsg^.imsg;
        // save Keystate for Winapi.GetKeyState
        KeyState := IMsg^.Qualifier;
        // Eat this Event if it is inside our border
        // but not inside of any of my Childs
        EatEvent := OBJ_IsInObject(Imsg^.MouseX, Imsg^.MouseY, obj);
        if EatEvent and (not MUIB.Enabled or not MUIB.pasobject.Visible)then
        begin
          Result := 0;//MUI_EventHandlerRC_Eat;
          Exit;
        end;
        //writeln('Imsg^.MouseX: ', Imsg^.MouseX, ' Imsg^.MouseY: ', Imsg^.MouseY, ' Name:', MUIB.pasobject.classname, ' ', MUIB.Visible);
        for i := 0 to MUIB.FChilds.Count - 1 do
        begin
          //writeln(i, '. child ', obj_left(TMUIObject(MUIB.FCHilds[i]).Obj), ',', obj_top(TMUIObject(MUIB.FCHilds[i]).Obj), ' name ', TMUIObject(MUIB.FCHilds[i]).pasobject.classname, ' visible ', TMUIObject(MUIB.FCHilds[i]).Visible);
          if OBJ_IsInObject(Imsg^.MouseX, Imsg^.MouseY, TMUIObject(MUIB.FCHilds[i]).Obj) and TMUIObject(MUIB.FCHilds[i]).Visible then
            EatEvent := False;  // the mouse is inside of one of my Childs! so do not eat it
        end;
        MUIParent := MUIB.GetParentWindow;
        MUIWin := nil;
        if MUIParent is TMuiWindow then
          MUIWin := MUIParent as TMuiWindow;
        if Assigned(Win) and EatEvent then
        begin
          // Activate the RMBTrap if no menu -> we can use the Right mousekey
          // get parent window
          if Assigned(MUIWin) then
          begin
            // if Window has a MainMenu do not catch Right MB
            //if (Win^.Flags and WFLG_RMBTrap) <> 0 then
            //  writeln('before RMB TRAP ACTIVE');
            if MUIWin.HasMenu then
            begin
              //writeln('NO RMB TRAP');
              Win^.Flags := Win^.Flags and not WFLG_RMBTrap
            end
            else
            begin
              //writeln('YES RMB TRAP');
              Win^.Flags := Win^.Flags or WFLG_RMBTrap;
            end;
            //if (Win^.Flags and WFLG_RMBTrap) <> 0 then
           //   writeln('after RMB TRAP ACTIVE');
          end;
        end;
        if True then
        begin
          //writeln(MUIB.classname,' obj Event ', Imsg^.MouseX, ' ', Imsg^.MouseY);
          // Calc relative mouse coordinates for this Item
          RelX := Imsg^.MouseX - obj_Left(obj);
          RelY := Imsg^.MouseY - obj_Top(obj);
          // Check the EventClass
          case IMsg^.IClass of
            // Mouse MOVE  #############################################
            IDCMP_MOUSEMOVE: begin
              LCLSendMouseMoveMsg(MUIB.PasObject, RelX, RelY, []);
              if MUIB.LastClick > 0 then
                if MUIB.NumMoves > 0 then
                  Dec(MUIB.NumMoves)
                else
                  MUIB.LastClick := -1;
            end;
            // MOUSE BUTTON ############################################
            IDCMP_MOUSEBUTTONS: begin
              // Check the Mouse Status
              case iMsg^.Code of
                SELECTDOWN: begin  // Left Button down
                  if not EatEvent then
                  begin
                    //writeln('handleevent Exit');
                    Exit;  // Mouse buttons only send if the mouse is inside the Widget
                  end;
                  // Check if we have to switch the Focus to the clicked one
                  if MUIWin.FocusedControl <> MUIB then
                  begin
                    if Assigned(MUIWin.FocusedControl) then
                      LCLSendKillFocusMsg(MUIWin.FocusedControl.PasObject); // send 'Unfocus' message
                    LCLSendSetFocusMsg(MUIB.PasObject);                     // send 'Focus' message
                    FocusWidget := HWND(MUIB.PasObject);
                  end;
                  MUIWin.FocusedControl := MUIB;
                  LCLSendMouseDownMsg(MUIB.PasObject, RelX, RelY, mbLeft, []);
                  // Check if it is an Double click < 250 ms and less than 3 move events between
                  CurTime := GetLCLTime;
                  //sysdebugln('mouse down Moved:' + IntToStr(MUIB.NumMoves));
                  if (CurTime - MUIB.LastClick <= 750) and (MUIB.NumMoves > 0) then
                  begin
                    LCLSendMouseMultiClickMsg(MUIB.PasObject, RelX, RelY, mbLeft, 2, []);  // its a double click
                    MUIB.LastClick := -1;
                  end else
                  begin
                    MUIB.NumMoves := 3;            // first click, maybe later as Double Click ;)
                    MUIB.LastClick := CurTime;
                  end;
                end;
                // Left Mouse UP
                SELECTUP:
                begin
                  LCLSendMouseUpMsg(MUIB.PasObject, RelX, RelY, mbLeft, []);
                end;
                // Middle Mouse Down
                MIDDLEDOWN: begin
                    if not EatEvent then
                      Exit;  // Mouse buttons only send if the mouse is inside the Widget
                    LCLSendMouseDownMsg(MUIB.PasObject, RelX, RelY, mbMiddle, []);
                  end;
                // Middle Mouse Up
                MIDDLEUP: LCLSendMouseUpMsg(MUIB.PasObject, RelX, RelY, mbMiddle, []);
                // Right Mouse Down;
                MENUDOWN: begin
                    //if not EatEvent then
                    //  Exit;  // Mouse buttons only send if the mouse is inside the Widget
                    if EatEvent then
                      LCLSendMouseDownMsg(MUIB.PasObject, RelX, RelY, mbRight, []);
                  end;
                // Right Mouse Up
                MENUUP: LCLSendMouseUpMsg(MUIB.PasObject, RelX, RelY, mbRight, []);
              end;
            end;
            {$ifdef AmigaOS4}
            IDCMP_EXTENDEDMOUSE: begin
              if iMsg^.Code = IMSGCODE_INTUIWHEELDATA then
              begin
                data := PIntuiWheelData(IMsg^.IAddress);
                if not EatEvent then
                  Exit;
                RelX := Imsg^.MouseX - obj_Left(obj);
                RelY := Imsg^.MouseY - obj_Top(obj);
                // Mouse wheel with Value 120 (from the other interfaces)
                if Data^.WheelY = 1 then
                  LCLSendMouseWheelMsg(MUIB.PasObject, RelX, RelY, -120, []);
                if Data^.WheelY = -1 then
                  LCLSendMouseWheelMsg(MUIB.PasObject, RelX, RelY, +120, [])
              end;
            end;
            {$endif}
            // KEYS ####################################################
            IDCMP_RAWKEY: begin
              // Mouse scroll wheel produce a up/down message
              if (iMsg^.Code = $7A) or (iMsg^.Code = $7B) then
              begin
                if not EatEvent then
                  Exit;
                RelX := Imsg^.MouseX - obj_Left(obj);
                RelY := Imsg^.MouseY - obj_Top(obj);
                // Mouse wheel with Value 120 (from the other interfaces)
                if iMsg^.Code = $7B then
                  LCLSendMouseWheelMsg(MUIB.PasObject, RelX, RelY, -120, [])
                else
                  LCLSendMouseWheelMsg(MUIB.PasObject, RelX, RelY, +120, [])
              end else
              begin
                // Get the Keyboard Focus (see Mouse Buttons Left Down)
                if Assigned(MUIWin) then
                  if Assigned(MUIWin.FocusedControl) then
                    MUIB := MUIWin.FocusedControl;
                // Keyboard events always get eaten -> focussed Control
                EatEvent := True;
                // Extrace some data and let MapRawKey do the job
                KeyUp := (IMsg^.Code and IECODE_UP_PREFIX) <> 0;
                IMsg^.Code := IMsg^.Code and not IECODE_UP_PREFIX;
                ie.ie_Class := IECLASS_RAWKEY;
                ie.ie_SubClass := 0;
                ie.ie_Code := IMsg^.Code;
                ie.ie_Qualifier := IMsg^.Qualifier and (not (IEQUALIFIER_CONTROL or IEQUALIFIER_LALT));
                ie.ie_position.ie_addr := PPointer(iMsg^.IAddress)^;
                ie.ie_NextEvent := nil;
                Buff[0] := #0;
                Ret := MapRawKey(@ie, @Buff[0], 1, nil);
                //writeln('Key: ', MUIB.PasObject.Classname, ' got Key "',Buff[0],'" #', KeyData, ' Ret: ', Ret);
                Key := Buff[0];
                // Shiftstate mainly for ALT
                // TODO: still not working!!!! ssALT is never set
                KeyData := KeyboardShiftState(IMsg^.Qualifier);
                // save KeyState for Winapi.GetKeyState
                KeyState := IMsg^.Qualifier;
                IsSysKey := KeyData <> 0;
                //writeln(' send key: $', IntToHex(KeyData,8) );
                if Ret = 1 then
                begin
                  CharCode := RawKeyToKeycode(IMsg^.Code);
                  if CharCode = 0 then
                    CharCode := Ord(uppercase(Key)[1]);
                  if KeyUp then
                  begin
                    LCLSendKeyUpEvent(MUIB.PasObject, CharCode, KeyData, True, False);
                  end else
                  begin
                    //writeln('Down ', Char(CharCode), ' ', Charcode, ' ', Ord(''''));
                    LCLSendKeyDownEvent(MUIB.PasObject, CharCode, KeyData, True, False);
                    if (IMsg^.Qualifier and (IEQUALIFIER_CONTROL or IEQUALIFIER_LALT) = 0) then
                    begin
                      CharCode := Ord(Key);
                      //writeln('Press ', Char(CharCode), '  ', Key,' ' ,charcode);
                      LCLSendCharEvent(MUIB.PasObject, CharCode, KeyData, True, False, True);
                    end;
                  end;
                end else
                begin
                  CharCode := RawKeyToKeycode(IMsg^.Code);
                  if KeyUp then
                    LCLSendKeyUpEvent(MUIB.PasObject, CharCode, KeyData, True, IsSysKey)
                  else
                    LCLSendKeyDownEvent(MUIB.PasObject, CharCode, KeyData, True, IsSysKey);
                end;
              end;
            end;
            else
            begin
              //writeln('IDCMP: ', HexStr(Pointer(IMsg^.IClass)));
            end;
          end;
          Result := 0;
          if EatEvent then
            Result := MUI_EventHandlerRC_Eat;
        end else
        begin
          Result := 0;
        end;
      end;
    end
    else
    begin
      //writeln(Dos.GetLCLTime, ' unknown messageID $', HexStr(Pointer(Msg^.MethodID)));
      Result := DoSuperMethodA(cl, obj, msg);
    end;
  end;
end;

procedure DestroyClasses;
begin
  if Assigned(LCLClass) then
    MUI_DeleteCustomClass(LCLClass);
end;

procedure SetDispatcher(var Hook: THook; Func: Pointer);
begin
  SetHook(Hook, THookFunc(Func), nil);
end;

procedure CreateClasses;
begin
  LCLClass := MUI_CreateCustomClass(nil, MUIC_Group, nil, sizeOf(Pointer), nil);
  if not Assigned(LCLClass) then
  begin
    writeln('Cannot make class.');
    DestroyClasses;
    halt(5);
  end;
  LCLGroupClass := LCLClass^.mcc_Class;
  SetDispatcher(LCLGroupClass^.cl_Dispatcher, @Dispatcher);
end;

{$ifdef CHECKOBJECTS}
procedure NotDestroyed;
var
  i: Integer;
begin
  SysDebugLn('not destroyed : ' + IntToStr(AllItems.Count));
  for i := 0 to AllItems.Count - 1 do
    SysDebugln(TMuiObject(AllItems[i]).Classname);
end;
{$endif}

{$ifdef MorphOS}
procedure InitMorphOS;
begin
  //InitMUIMasterLibrary;
  //InitIntuitionLibrary;
  //InitGraphicsLibrary;
  InitKeymapLibrary;
  //InitDiskFontLibrary;
end;
{$endif}

initialization
  {$ifdef MorphOS}
  InitMorphOS;
  {$endif}
  CreateClasses;
  {$ifdef CHECKOBJECTS}
  AllItems := classes.TList.create;
  {$endif}
finalization
  MUIApp.Free;
  DestroyClasses;
  {$ifdef CHECKOBJECTS}
  NotDestroyed;
  AllItems.Free;
  {$endif}
end.


{
 *****************************************************************************
  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

 Authors: Michael W. Vogel

}

unit DockedBasicAnchorDesigner;

{$mode objfpc}{$H+}

interface

uses
  // RTL, FCL
  Classes, SysUtils,
  // LCL
  LCLProc, Forms, Controls, LMessages, LCLType,
  // IDEIntf
  ComponentEditors, PropEdits, ComponentReg;

type

  TBoolFunc = function: Boolean of object;

  { TBasicAnchorDesigner }

  TBasicAnchorDesigner = class(TComponentEditorDesigner)
  private
    FOnDesignerSetFocus: TProcedureOfObject;
    FOnMouseWheel: TMouseWheelEvent;
    FParent: TWinControl;
  public
    procedure Abort; virtual; abstract;
    procedure BeginUpdate; virtual; abstract;
    procedure EndUpdate; virtual; abstract;
    procedure Invalidate; virtual; abstract;
    procedure Refresh; virtual; abstract;
    procedure SetParent(AValue: TWinControl); virtual;
    // Needed for valid compiling
    procedure AddComponent(const {%H-}NewRegisteredComponent: TRegisteredComponent;
                           const {%H-}NewComponentClass: TComponentClass; const {%H-}NewParent: TComponent;
                           const {%H-}NewLeft, {%H-}NewTop, {%H-}NewWidth, {%H-}NewHeight: Integer); override;
    procedure AddComponentCheckParent(var {%H-}NewParent: TComponent;
                                      const {%H-}OriginComponent: TComponent; const {%H-}OriginWinControl: TWinControl;
                                      const {%H-}NewComponentClass: TComponentClass); override;
    function  AddUndoAction(const {%H-}aPersistent: TPersistent; {%H-}aOpType: TUndoOpType; {%H-}IsSetNewId: boolean;
                            {%H-}aFieldName: string; const {%H-}aOldVal, {%H-}aNewVal: variant): boolean; override;
    function  CanCopy: Boolean; override;
    function  CanPaste: Boolean; override;
    function  ChangeClass: boolean; override;
    function  ClearSelection: boolean; override;
    function  CopySelection: boolean; override;
    function  CopySelectionToStream({%H-}s: TStream): boolean; override;
    function  CreateUniqueComponentName(const {%H-}AClassName: string): string; override;
    function  CutSelection: boolean; override;
    function  DeleteSelection: boolean; override;
    procedure DrawDesignerItems({%H-}OnlyIfNeeded: boolean); override;
    function  GetPropertyEditorHook: TPropertyEditorHook; override;
    function  GetShiftState: TShiftState; override;
    function  GetShowNonVisualComponents: boolean; override;
    function  InsertFromStream({%H-}s: TStream; {%H-}Parent: TWinControl; {%H-}Flags: TComponentPasteSelectionFlags): Boolean; override;
    function  InvokeComponentEditor({%H-}AComponent: TComponent): boolean; override;
    function  IsDesignMsg(Sender: TControl; var {%H-}Message: TLMessage): Boolean; override;
    function  IsUndoLocked: boolean; override;
    procedure Notification({%H-}AComponent: TComponent; {%H-}Operation: TOperation); override;
    procedure PaintGrid; override;
    function  PasteSelection({%H-}Flags: TComponentPasteSelectionFlags): boolean; override;
    procedure PrepareFreeDesigner({%H-}AFreeComponent: boolean); override;
    procedure SelectOnlyThisComponent({%H-}AComponent: TComponent); override;
    procedure SetShowNonVisualComponents({%H-}AValue: boolean); override;
    function  UniqueName(const {%H-}BaseName: string): string; override;
    procedure UTF8KeyPress(var {%H-}UTF8Key: TUTF8Char); override;
    procedure ValidateRename({%H-}AComponent: TComponent; const {%H-}CurName, {%H-}NewName: string); override;
  public
    property OnDesignerSetFocus: TProcedureOfObject read FOnDesignerSetFocus write FOnDesignerSetFocus;
    property OnMouseWheel: TMouseWheelEvent read FOnMouseWheel write FOnMouseWheel;
    property Parent: TWinControl read FParent write SetParent;
  end;

implementation

{ TBasicAnchorDesigner }

procedure TBasicAnchorDesigner.SetParent(AValue: TWinControl);
begin
  if FParent = AValue then Exit;
  FParent := AValue;
end;

procedure TBasicAnchorDesigner.AddComponent(
  const NewRegisteredComponent: TRegisteredComponent;
  const NewComponentClass: TComponentClass; const NewParent: TComponent;
  const NewLeft, NewTop, NewWidth, NewHeight: Integer);
begin
end;

procedure TBasicAnchorDesigner.AddComponentCheckParent(
  var NewParent: TComponent; const OriginComponent: TComponent;
  const OriginWinControl: TWinControl; const NewComponentClass: TComponentClass);
begin
end;

function TBasicAnchorDesigner.AddUndoAction(const aPersistent: TPersistent;
  aOpType: TUndoOpType; IsSetNewId: boolean; aFieldName: string; const aOldVal,
  aNewVal: variant): boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.CanCopy: Boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.CanPaste: Boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.ChangeClass: boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.ClearSelection: boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.CopySelection: boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.CopySelectionToStream(s: TStream): boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.CreateUniqueComponentName(const AClassName: string): string;
begin
  Result := EmptyStr;
end;

function TBasicAnchorDesigner.CutSelection: boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.DeleteSelection: boolean;
begin
  Result := False;
end;

procedure TBasicAnchorDesigner.DrawDesignerItems(OnlyIfNeeded: boolean);
begin
end;

function TBasicAnchorDesigner.GetPropertyEditorHook: TPropertyEditorHook;
begin
  Result := nil;
end;

function TBasicAnchorDesigner.GetShiftState: TShiftState;
begin
  Result := [];
end;

function TBasicAnchorDesigner.GetShowNonVisualComponents: boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.InsertFromStream(s: TStream; Parent: TWinControl;
  Flags: TComponentPasteSelectionFlags): Boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.InvokeComponentEditor(AComponent: TComponent): boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.IsDesignMsg(Sender: TControl; var Message: TLMessage): Boolean;
begin
  Result := False;
end;

function TBasicAnchorDesigner.IsUndoLocked: boolean;
begin
  Result := False;
end;

procedure TBasicAnchorDesigner.Notification(AComponent: TComponent; Operation: TOperation);
begin
end;

procedure TBasicAnchorDesigner.PaintGrid;
begin
end;

function TBasicAnchorDesigner.PasteSelection(Flags: TComponentPasteSelectionFlags): boolean;
begin
  Result := False;
end;

procedure TBasicAnchorDesigner.PrepareFreeDesigner(AFreeComponent: boolean);
begin
end;

procedure TBasicAnchorDesigner.SelectOnlyThisComponent(AComponent: TComponent);
begin
end;

procedure TBasicAnchorDesigner.SetShowNonVisualComponents(AValue: boolean);
begin
end;

function TBasicAnchorDesigner.UniqueName(const BaseName: string): string;
begin
  Result := EmptyStr;
end;

procedure TBasicAnchorDesigner.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
end;

procedure TBasicAnchorDesigner.ValidateRename(AComponent: TComponent; const CurName, NewName: string);
begin
end;

end.


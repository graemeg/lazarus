{                 -----------------------------------
                  carbonstrings.pp  -  Carbon strings
                  -----------------------------------

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CarbonStrings;

{$mode objfpc}{$H+}

interface

// defines
{$I carbondefines.inc}

{$if (FPC_FULLVERSION>=20701) OR (FPC_FULLVERSION>=20603)}
{$define HAS_INHERITED_INSERTITEM}
{$endif}

uses
 // rtl+ftl
  Classes, SysUtils,
 // LCL
  LCLProc, LCLType, Graphics, Controls, StdCtrls, LazUtf8Classes,
 // LCL Carbon
  CarbonEdits, CarbonListViews;

type
  { TCarbonComboBoxStrings }

  TCarbonComboBoxStrings = class(TStringList)
  private
    FOwner: TCarbonComboBox;  // Carbon combo box control owning strings
  protected
    procedure Put(Index: Integer; const S: string); override;
    {$IFNDEF HAS_INHERITED_INSERTITEM}
    // before fpc 2.7.1 InsertItem(Index,S) did not call InsertItem(Index,S,nil)
    procedure InsertItem(Index: Integer; const S: string); override;
    {$ENDIF}
    procedure InsertItem(Index: Integer; const S: string; O: TObject); override;
  public
    constructor Create(AOwner: TCarbonComboBox);
    destructor Destroy; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Sort; override;
  public
    property Owner: TCarbonComboBox read FOwner;
  end;
  
  { TCarbonListBoxStrings }

  TCarbonListBoxStrings = class(TStringList)
  private
    FOwner: TCarbonListBox;  // Carbon list box control owning strings
    FWinControl: TWinControl;
  protected
    procedure Put(Index: Integer; const S: string); override;
    {$IFNDEF HAS_INHERITED_INSERTITEM}
    // before fpc 2.7.1 InsertItem(Index,S) did not call InsertItem(Index,S,nil)
    procedure InsertItem(Index: Integer; const S: string); override;
    {$ENDIF}
    procedure InsertItem(Index: Integer; const S: string; O: TObject); override;
  public
    constructor Create(AOwner: TCarbonListBox; AWinControl: TWinControl);
    destructor Destroy; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Move(CurIndex, NewIndex: Integer); override;
    procedure Sort; override;
    procedure Exchange(Index1, Index2: Integer); override;
  public
    property Owner: TCarbonListBox read FOwner;
  end;

  { TCarbonMemoStrings }

  TCarbonMemoStrings = class(TStrings)
  private
    FOwner: TCarbonMemo;      // Carbon memo control owning strings
  protected
    function GetTextStr: string; override;
    procedure SetTextStr(const Value: string); override;
    function GetCount: Integer; override;
    function Get(Index: Integer): string; override;
  public
    constructor Create(AOwner: TCarbonMemo);
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: string); override;
    procedure LoadFromFile(const FileName: string); override;
    procedure SaveToFile(const FileName: string); override;
    procedure AddStrings(TheStrings: TStrings); overload; override;
  public
    property Owner: TCarbonMemo read FOwner;
  end;


implementation

uses
  CarbonProc, CarbonWSCheckLst, CheckLst;

{ TCarbonComboBoxStrings }

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.Put
  Params:  Index - Index of string to change
           S     - New text

  Changes the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.Put(Index: Integer; const S: string);
begin
  inherited Put(Index, S);

  FOwner.Remove(Index);
  FOwner.Insert(Index, S);
end;

{$IFNDEF HAS_INHERITED_INSERTITEM}
{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.InsertItem
  Params:  Index - Line index
           S     - Text to insert

  Inserts the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.InsertItem(Index: Integer; const S: string);
begin
  inherited InsertItem(Index, S);

  FOwner.Insert(Index, S);
end;
{$ENDIF}

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.InsertItem
  Params:  Index - Line index
           S     - Text to insert
           O     - Object to insert

  Inserts the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.InsertItem(Index: Integer; const S: string;
  O: TObject);
begin
  inherited InsertItem(Index, S, O);

  FOwner.Insert(Index, S);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.Create
  Params:  AOwner - Carbon combo box owner of strings

  Creates new strings for Carbon combo box items
 ------------------------------------------------------------------------------}
constructor TCarbonComboBoxStrings.Create(AOwner: TCarbonComboBox);
begin
  inherited Create;
  FOwner := AOwner;
end;

destructor TCarbonComboBoxStrings.Destroy;
begin
  FOwner := nil;
  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.Clear

  Clears strings
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.Clear;
var
  I: Integer;
  C: Integer;
begin
  if Assigned(FOwner) then
    C := Count;
  inherited Clear;
  if Assigned(FOwner) then
    for I := C - 1 downto 0 do
      FOwner.Remove(I);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.Delete
  Params:  Index - Line index

  Deletes line with the specified index from strings
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.Delete(Index: Integer);
begin
  inherited Delete(Index);
  
  FOwner.Remove(Index);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonComboBoxStrings.Sort

  Sorts the strings
 ------------------------------------------------------------------------------}
procedure TCarbonComboBoxStrings.Sort;
var
  I: Integer;
begin
  inherited Sort;
  
  for I := 0 to Count - 1 do
  begin
    FOwner.Remove(I);
    FOwner.Insert(I, Strings[I]);
  end;
end;

{ TCarbonListBoxStrings }

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.Put
  Params:  Index - Index of string to change
           S     - New text

  Changes the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.Put(Index: Integer; const S: string);
begin
  inherited Put(Index, S);

  FOwner.UpdateItem(Index);
end;

{$IFNDEF HAS_INHERITED_INSERTITEM}
{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.InsertItem
  Params:  Index - Line index
           S     - Text to insert

  Inserts the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.InsertItem(Index: Integer; const S: string);
begin
  inherited InsertItem(Index, S);

  FOwner.InsertItem(Index); // Without this call, dynamically adding items won't work
end;
{$ENDIF}

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.InsertItem
  Params:  Index - Line index
           S     - Text to insert
           O     - Object to insert

  Inserts the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.InsertItem(Index: Integer; const S: string;
  O: TObject);
begin
  inherited InsertItem(Index, S, O);

  FOwner.InsertItem(Index);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.Create
  Params:  AOwner - Carbon list box owner of strings

  Creates new strings for Carbon list box items
 ------------------------------------------------------------------------------}
constructor TCarbonListBoxStrings.Create(AOwner: TCarbonListBox; AWinControl: TWinControl);
begin
  inherited Create;
  FOwner := AOwner;
  FWinControl := AWinControl;
end;

destructor TCarbonListBoxStrings.Destroy;
begin
  FOwner := nil;
  inherited Destroy;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.Clear

  Clears strings
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.Clear;
begin
  inherited Clear;
  if Assigned(FOwner) then
    FOwner.ClearItems;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.Delete
  Params:  Index - Line index

  Deletes line with the specified index from strings
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.Delete(Index: Integer);
begin
  inherited Delete(Index);

  FOwner.DeleteItem(Index);
end;

procedure TCarbonListBoxStrings.Move(CurIndex, NewIndex: Integer);
var
  AState: TCheckBoxState;
begin
  if FWinControl is TCustomCheckListBox then
    AState := TCarbonWSCustomCheckListBox.GetState(TCustomCheckListBox(FWinControl), CurIndex);

  inherited Move(CurIndex, NewIndex);

  if FWinControl is TCustomCheckListBox then
    TCarbonWSCustomCheckListBox.SetState(TCustomCheckListBox(FWinControl), NewIndex, AState);

end;

{------------------------------------------------------------------------------
  Method:  TCarbonListBoxStrings.Sort

  Sorts the strings
 ------------------------------------------------------------------------------}
procedure TCarbonListBoxStrings.Sort;
begin
  inherited Sort;

  FOwner.UpdateItems;
end;

procedure TCarbonListBoxStrings.Exchange(Index1, Index2: Integer);
begin
  inherited Exchange(Index1, Index2);
  if Assigned(FOwner) then
  begin
    FOwner.UpdateItem(Index1);
    FOwner.UpdateItem(Index2);
  end;
end;

{ TCarbonMemoStrings }

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.GetTextStr
  Returns: Text of Carbon strings
 ------------------------------------------------------------------------------}
function TCarbonMemoStrings.GetTextStr: string;
begin
  FOwner.GetText(Result{%H-});
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.SetTextStr
 ------------------------------------------------------------------------------}
procedure TCarbonMemoStrings.SetTextStr(const Value: string);
begin
  FOwner.SetText(Value);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.GetCount
  Returns: Number of lines
 ------------------------------------------------------------------------------}
function TCarbonMemoStrings.GetCount: Integer;
begin
  Result := FOwner.GetLineCount;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.Get
  Params:  Index - Line index
  Returns: Text on line with the specified index
 ------------------------------------------------------------------------------}
function TCarbonMemoStrings.Get(Index: Integer): string;
begin
  Result := FOwner.GetLine(Index);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.Create
  Params:  AOwner - Carbon memo owner of strings

  Creates new strings for Carbon memo strings
 ------------------------------------------------------------------------------}
constructor TCarbonMemoStrings.Create(AOwner: TCarbonMemo);
begin
  FOwner := AOwner;
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.Clear

  Clears strings
 ------------------------------------------------------------------------------}
procedure TCarbonMemoStrings.Clear;
begin
  SetTextStr('');
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.Delete
  Params:  Index - Line index

  Deletes line with the specified index from strings
 ------------------------------------------------------------------------------}
procedure TCarbonMemoStrings.Delete(Index: Integer);
begin
  FOwner.DeleteLine(Index);
end;

{------------------------------------------------------------------------------
  Method:  TCarbonMemoStrings.Insert
  Params:  Index - Line index
           S     - Text to insert

  Inserts the text on line with the specified index
 ------------------------------------------------------------------------------}
procedure TCarbonMemoStrings.Insert(Index: Integer; const S: string);
begin
  FOwner.InsertLine(Index, S);
end;

procedure TCarbonMemoStrings.LoadFromFile(const FileName: string);
var
  TheStream: TFileStreamUTF8;
begin
  TheStream:=TFileStreamUtf8.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

procedure TCarbonMemoStrings.SaveToFile(const FileName: string);
var
  TheStream: TFileStreamUTF8;
begin
  TheStream:=TFileStreamUtf8.Create(FileName,fmCreate);
  try
    SaveToStream(TheStream);
  finally
    TheStream.Free;
  end;
end;

procedure TCarbonMemoStrings.AddStrings(TheStrings: TStrings);
begin
  BeginUpdate;
  try
    // don't need to copy Objects, VCL does not support them neither
    // preserve the last line ending
    Text:=ConvertLineEndings(TheStrings.Text);
  finally
    EndUpdate;
  end;
end;


end.

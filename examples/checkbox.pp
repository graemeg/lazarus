{
 /***************************************************************************
                             checkbox.pp
                             -----------
                        Sample for Lazarus Checkbox.


                   Initial Revision  : Wed Dec 29 23:15:32 CST 1999


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
}
program CheckBox;

{$mode objfpc}{$H+}

uses
  Interfaces, Classes, Stdctrls, Forms, Buttons, Menus, Comctrls,
  SysUtils, ExtCtrls, GraphType, Graphics, Controls, LazLogger;

type
  TForm1 = class(TFORM)
  public
    Button2: TButton;
    Button3: TButton;
    Button11, Button12, Button13 : TSpeedButton; 
    Panel1: TPanel;
    mnuMain: TMainMenu;
    itmFileQuit: TMenuItem;
    itmFile: TMenuItem;
    CheckBox1 : TCheckBox;
    RadioButton : TRadioButton;
    RadioButton2 : TRadioButton;
    RadioButton3 : TRadioButton;
    RadioGroup   : TRadioGroup;
    RadioGroup2  : TRadioGroup;
    ToggleBox   : TToggleBox;
    label1    : TLabel;   
    label2    : TLabel;
    constructor Create(AOwner: TComponent); override;
    procedure LoadMainMenu;
    Procedure FormKill(Sender : TObject);
    procedure mnuQuitClicked(Sender : TObject);
  protected
    procedure Button1CLick(Sender : TObject);
    procedure Button2CLick(Sender : TObject);
    procedure Button3CLick(Sender : TObject);
    procedure Button4CLick(Sender : TObject);
    procedure CheckBoxClick(Sender : TObject);
    procedure RadioButtonClick(Sender : TObject);
    procedure RadioGroupClick(Sender : TObject);
    procedure ToggleBoxClick(Sender : TObject);
  end;

var
Form1 : TForm1;

constructor TForm1.Create(AOwner: TComponent);  
begin
  inherited CreateNew(AOwner, 1);
  Caption := 'CheckBox Demo V.02';
  LoadMainMenu;
end;

procedure TForm1.Button1Click(Sender : TObject);
Begin
End;

procedure TForm1.Button2Click(Sender : TObject);
Begin
   if assigned (CheckBox1) then
   begin
      CheckBox1.Checked := not CheckBox1.Checked; 
   end;
   Panel1.Caption:= 'Changed';
End;

procedure TForm1.Button3Click(Sender : TObject);
var
   i : integer;
Begin
   if assigned (RadioGroup) then
   begin
      i := RadioGroup.ItemIndex;
      if i < RadioGroup.Items.Count -1 
         then RadioGroup.ItemIndex := i + 1
         else RadioGroup.ItemIndex := 0
   end;
   if assigned (RadioGroup2) then
   begin
      i := RadioGroup2.ItemIndex;
      if i < RadioGroup2.Items.Count -1 
         then RadioGroup2.ItemIndex := i + 1
         else RadioGroup2.ItemIndex := 0
   end;
End;

procedure TForm1.Button4Click(Sender : TObject);
Begin
End;

procedure TForm1.CheckBoxClick(Sender : TObject);
Begin
  DebugLn('[TForm1.CheckBoxClick]');
   if assigned (CheckBox1) and assigned (label1) then begin
      DebugLn ('   [checkbox and label assigned]');
      if CheckBox1.Checked
        then label1.Caption := 'checked'
        else label1.Caption := 'unchecked';
      if CheckBox1.Checked
        then CheckBox1.Caption := 'new caption'
        else CheckBox1.Caption := 'Checkbox 1';
   end;
End;

procedure TForm1.RadioButtonClick(Sender : TObject);
begin
   debugln('[TForm1.RadioButtonClick]');
   if assigned (label2)
      then label2.Caption := 'active: ' + TRadioButton (Sender).Caption
end;

procedure TForm1.RadioGroupClick(Sender : TObject);
begin
   debugln('[TForm1.RadioGroupClick]');
end;

procedure TForm1.ToggleBoxClick(Sender : TObject);
begin
   debugln('[TForm1.ToggleBoxClick]');
   if assigned (ToggleBox) then
   begin
      if ToggleBox.checked
         then ToggleBox.Caption := 'Togglebox1'
	 else ToggleBox.Caption := 'does nothing:-(';
   end;
end;

{------------------------------------------------------------------------------}

procedure TForm1.FormKill(Sender : TObject);
Begin

End;

{------------------------------------------------------------------------------}
procedure TForm1.LoadMainMenu;
var
  BtnGlyph: TPortableNetworkGraphic;
begin
 OnDestroy := @FormKill;

{    set the height and width }
   Height := 450;
   Width := 700;

   { Create a checkbox }
   CheckBox1 := TCheckBox.Create(Self);
   CheckBox1.Parent := self;
   CheckBox1.top := 35;
   CheckBox1.left := 10;
   CheckBox1.Height :=20;
   CheckBox1.Width := 200;
   CheckBox1.OnCLick := @CheckBoxClick;
   CheckBox1.Show;
   CheckBox1.Caption := 'Checkbox 1';

   { Create a label which shows the state checked/unchecked of the checkbox}
   label1 := TLabel.Create(Self);
   label1.Parent := self;
   label1.top := 35;
   label1.left := 220;
   label1.Height :=20;
   label1.Width := 100;
   label1.Show;
   label1.Caption := 'unchecked';


   { Sample panel here }
   Panel1:= TPanel.Create(Self);
   with Panel1 do begin
     Parent := Self;
     Left := 320;
     Top := 60;
     Width := 280;
     Height := 81;
     Alignment:= taRightJustify;
     BevelInner:= bvLowered;
     BevelOuter:= bvRaised;
     BorderWidth:= 4;
     BevelWidth:= 4;
     Show;
     Caption:= 'Hello world';
   end;     

   { Create a button which toggles the checkbox }
   Button2 := TButton.Create(Self);
   Button2.Parent := Panel1;
   Button2.Left := 5;
   Button2.Top := 45;
   Button2.Width := 180;
   Button2.Height := 20;
   Button2.Show;
   Button2.Caption := 'Toggle checkbox';
   Button2.OnClick := @Button2Click;

   Button11 := TSpeedButton.Create(Self);
   Button11.GroupIndex:= 1;
   Button11.Layout:= blGlyphTop;
//   Button11.Caption:= 'Option 1';
   Button11.Parent := Self;
   Button11.Left := 5;
   Button11.Top := 5;
   Button11.Width:= 45;
   Button11.Height:= 55;
   Button11.Flat:= true;
   BtnGlyph := TPortableNetworkGraphic.Create;
   try
     BtnGlyph.LoadFromFile('../images/items/item_form.png');
     Button11.Glyph.Assign(BtnGlyph);
   finally
     BtnGlyph.Free;
   end;

//   Button11.Spacing:= -1;
//   Button11.Margin:= 4;
   Button11.Visible:= true;
   
   Button12 := TSpeedButton.Create(Self);
   Button12.GroupIndex:= 1;
   Button12.Caption:= '2';
   Button12.Parent := Self;
   Button12.Left := 55;
   Button12.Top := 5;
//   Button12.Flat:= true;
   Button12.Visible:= true;

   Button13 := TSpeedButton.Create(Self);
   Button13.GroupIndex:= 1;
   Button13.Caption:= '3';
   Button13.Parent := Self;
   Button13.Left := 95;
   Button13.Top := 5;
   Button13.Flat:= true;
   Button13.AllowAllUp:= true;
   Button13.Visible:= true;
   

   { Create a label which shows the caption of the active radiobutton }
   label2 := TLabel.Create(Self);
   label2.Parent := self;
   label2.top := 90;
   label2.left := 220;
   label2.Height :=20;
   label2.Width := 200;
   label2.Show;
   label2.Caption := 'active: unknown';

   { Create a radio button }
   RadioButton := TRadioButton.Create(Self);
   RadioButton.Parent := self;
   RadioButton.top := 70;
   RadioButton.left := 10;
   RadioButton.Height :=20;
   RadioButton.Width := 200;
   RadioButton.OnCLick := @RadioButtonClick;
   RadioButton.Checked := false;  
   RadioButton.Show;
   RadioButton.Caption := 'Radio button 1';
   
   { Create a 2nd radiobutton }
   RadioButton2 := TRadioButton.Create(Self);
   with RadioButton2 do
   begin
     Parent := self;
     top := 90;
     left := 10;
     Height :=20;
     Width := 200;
     OnCLick := @RadioButtonClick;
     Checked := true; 
     Show;
     Caption := 'Radiobutton 2'
   end;

   { Create a 3rd radiobutton }
   RadioButton3 := TRadioButton.Create(Self);
   with RadioButton3 do
   begin
     Parent := self;
     top := 110;
     left := 10;
     Height :=20;
     Width := 200;
     OnCLick := @RadioButtonClick;
     Checked := false;  
     Show;
     Caption := 'Radiobutton 3'
   end;

   { Create a radiogroup }
   RadioGroup := TRadioGroup.Create(Self);
   with RadioGroup do
   begin
     Parent := self;
     top := 200;
     left := 10;
     Height :=200;
     Width := 150;
     OnCLick := @RadioGroupClick;
     RadioGroup.Items.Add ('No 1');
     RadioGroup.Items.Add ('No 2');
     RadioGroup.Items.Add ('No 3');
     RadioGroup.Items.Add ('No 4');
     RadioGroup.Items.Add ('No 5');
     RadioGroup.Items.Add ('No 6');
     ItemIndex := 3;
     Show;
     Caption := 'Radiogroup';
   end;

   { Create a button which does mystic things with the radiogroup }
   Button3 := TButton.Create(Self);
   Button3.Parent := Self;
   Button3.Left := 220;
   Button3.Top := 220;
   Button3.Width := 180;
   Button3.Height := 30;
   Button3.Show;
   Button3.Caption := 'Mystic Radiogroups';
   Button3.OnClick := @Button3Click;

   { Create a radiogroup }
   RadioGroup2 := TRadioGroup.Create(Self);
   with RadioGroup2 do
   begin
     Parent := self;
     top     := 300;
     left    := 220;
     Height  := 100;
     Width   := 300;
     Columns := 3;
     Items.Add ('No 1');
     Items.Add ('No 2');
     Items.Add ('No 3');
     Items.Add ('No 4');
     Items.Add ('No 5');
     Items.Add ('No 6');
     ItemIndex := 1;
     Show;
     Caption := '3 columns';
   end;

   { Create a togglebox }
   ToggleBox := TToggleBox.Create(Self);
   with ToggleBox do
   begin
     Parent := self;
     top := 150;
     left := 10;
     Height :=30;
     Width := 240;
     OnCLick := @ToggleBoxClick;
     Show;
     Caption := 'ToggleBox 1'
   end;

   mnuMain := TMainMenu.Create(Self);
   Menu := mnuMain;

   itmFile := TMenuItem.Create(Self);
   itmFile.Caption := 'File';
   mnuMain.Items.Add(itmFile);

   itmFileQuit := TMenuItem.Create(Self);
   itmFileQuit.Caption := 'Quit';
   itmFileQuit.OnClick := @mnuQuitClicked;
   itmFile.Add(itmFileQuit);

   

end;

{------------------------------------------------------------------------------}
procedure TForm1.mnuQuitClicked(Sender : TObject);
begin
  Close;
end;
{------------------------------------------------------------------------------}

begin
   Application.Initialize; { calls InitProcedure which starts up GTK }
   Application.CreateForm(TForm1, Form1);
   Application.Run;
end.



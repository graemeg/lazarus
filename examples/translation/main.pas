{ ------------------------------------------------------------------------------
  Steps to create a translated application
  ------------------------------------------------------------------------------

- In Project Options, activate i18n and specify a folder for translations
  Make sure that this folder can be found at run-time. If you use a relative
  filename it must be relative to the location of the exe.
  Select the option to automatically update the po file.
  
- Add DefaultTranslator or LCLTranslator to uses clause of main form
  (DefaultTranslator determines the default language automatically,
  LCLTranslator does not).

- If the project contains several forms that need translation:
  - Copy LocalizedForms.* (to be found in this project) to the folder of
    the new project
  - Inherit all forms to be translated from LocalizedForm
    (defined in LocalizedForms.pas)
  - For this purpose modify the class declaration of the forms to
      "class(TLocalizedForm)" instead of "class(TForm)"
    Open the lfm file ("view source (.lfm)") and change the first word to
    "inherited". See main.lfm and unit2.lfm for examples.
  - Create an empty unit to collect all resourcestrings of the project
    (this simplifies cross-form usage of strings).
    
- Declare each string that needs to be translated as a resourcestring. This
  is not absolutely necessary for component properties "Caption", "Text" or
  "Hint" which are transparently handled by Default/LCLTranslator. 
  Explicitly declared resource strings are required for stringlist items, 
  such as those of comboboxes, radiogroups etc.
  
- To create resource strings from existing code: create a resourcestring section
  at the end of the interface section of each unit, then <right click> on each
  string and select "Refactoring" | "Make Resource String..." This will create
  the resource strings and place the string into the declaration. Then copy all
  resource strings to the resource strings unit and delete the resourcestring 
  sections. Or, enter the resource strings into the resource strings unit 
  directly.

- Using poedit (or a similar translation program) translate the strings in the
  project's po file (to be found in the languages folder) to the languages that
  you support. When saving insert language code before ".po", i.e.
  "Project1.de.po" for German translation file of "Project1.po".)

- See "SelectLanguage()" for required procedures when changing language at
  run-time.
}

unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, LCLTranslator, LocalizedForms;

type

  { TMainForm }

  // inherit from TLocalizedForm, .lfm file begins with "inherited" instead of "object"
  TMainForm = class(TLocalizedForm)
    Bevel1: TBevel;
    Button1: TButton;
    Button2: TButton;
    CbLanguage: TComboBox;
    Label1: TLabel;
    LblCurrentSelection: TLabel;
    RgDrinks: TRadioGroup;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure CbLanguageChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure RgDrinksClick(Sender: TObject);
  private
    { private declarations }
    FSelectionTime: TTime;
    procedure SelectLanguage(ALang: String);
  protected
    procedure UpdateTranslation(ALang: String); override;
  public
    { public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

uses
  Unit2, StringsUnit;

procedure TMainForm.Button1Click(Sender: TObject);
begin
  Form2.Show;
end;

{ This example demonstrates how a translated string can be composed of other
  words in phrases. }
procedure TMainForm.Button2Click(Sender: TObject);
begin
  if RgDrinks.ItemIndex = -1 then
    MessageDlg(LblCurrentSelection.Caption, mtInformation, [mbClose], 0)
  else
    MessageDlg(Format(rsYouSelectedAt, [
      RgDrinks.Items[RgDrinks.ItemIndex], TimeToStr(FSelectionTime)]),
      mtInformation, [mbClose], 0);
    { The format mask rsYouSelectedAt ('You selected %0:s at %1:s.') contains
      two format placeholders %0:s and %1:s. The former one is replaced by the
      string with index 0 in the parameter list, the latter one by the string
      with index 1. When using multiple placeholders always use the index
      specifiers because the order of placeholders may change from language to
      language. }

    { Another comment: The strings used in "MessageDlg" can be translated by
      copying the files "lclstrconsts.*.po" to the languages folder.
      LCL/DefaultTranslater then includes these strings as well. Please note that
      we did not copy these files in this demo project to avoid duplication of
      Lazarus files. }
end;

{ Event handler fired when a new language is selected in the language combobox.
  We extract the language code from the selected combobox item, and call the
  procedure "SelectLanguage". }
procedure TMainForm.CbLanguageChange(Sender: TObject);
var
  lang: String;
  p: Integer;
begin
  if CbLanguage.ItemIndex > -1 then begin
    lang := CbLanguage.Items[CbLanguage.ItemIndex];
    p := pos(' ', lang);
    if p = 0 then p := pos('-', lang);
    if p = 0 then
      raise Exception.Create('Language items are not properly formatted');
      { This string is essentially meant as a message to the programmer, it
        will - hopefully - never make its way to the user. Therefore, there is
        not need to use a resourcestring and activate if for translation. }
    lang := copy(lang, 1, p-1);
    SelectLanguage(lang);
  end;
end;

procedure TMainForm.FormCreate(Sender: TObject);
begin
  { Lets start the program with English translation by default. You could also
    store language in a configuration file and apply that selection here. }
  SelectLanguage('en');
  { OR: Start the program with system's default language:
  SelectLanguage(GetDefaultLang); }
end;

{ Another example how to combine translated strings, in this case  for a
  label caption. }
procedure TMainForm.RgDrinksClick(Sender: TObject);
begin
  if RgDrinks.ItemIndex > -1 then
    LblCurrentSelection.Caption := Format(rsYouSelected, [RgDrinks.Items[RgDrinks.ItemIndex]]);
  FSelectionTime := time();
end;

{ This is the main procedure that has to be called when changing language:
  - It replaces resourcestrings with the translated ones.
  - It activates the format settings corresponding to the new language
  - It tries to use the BiDi mode for the new language (not completely correct)
  - It calls "UpdateTranslation" for itself and for each form of the project -
    this way, the forms can do things that are not done automatically.
  - It updates the language selector combobox }
procedure TMainForm.SelectLanguage(ALang: String);
var
  i, p: Integer;
  lang: String;
begin
  // Switch language - this is in LCLTranslator
  SetDefaultLang(ALang);

  // Switch default settings by calling the procedure provided in BasicLocalizedForm.pas.
  UpdateFormatSettings(ALang);

  // Adjust BiDiMode to new language
  UpdateBiDiMode(ALang);

  // Update items not automatically translated.
  UpdateTranslation(ALang);

  // Select the new language in the language combobox.
  ALang := lowercase(ALang);
  for i:=0 to CbLanguage.Items.Count-1 do begin
    lang := CbLanguage.Items[i];
    p := pos(' ', lang);
    if p = 0 then p := pos('-', lang);
    if p = 0 then
      raise Exception.Create('Language items are not properly formatted.');
    lang := lowercase(copy(lang, 1, p-1));
    if lang = ALang then begin
      CbLanguage.ItemIndex := i;
      break;
    end;
  end;

  { Remember the new language. Forms may want to check in UpdateTranslation
    whether the new language has a different BiDiMode. }
  CurrentLang := ALang;
end;

{ This method is inherited from LocalizedForm and manually inserts translated
  strings in cases where LCL/DefaultTranslator cannot do this. }
procedure TMainForm.UpdateTranslation(ALang: String);
begin
  inherited;

  { The items of the radiogroup are not automatically handled by
    LCL/DefaultTranslator. Therefore, we have to assign the strings to the
    translated versions explicitly. }
  RgDrinks.Items[0] := rsBeer;
  RgDrinks.Items[1] := rsWine;
  RgDrinks.Items[2] := rsWater;

  { The label LblCurrentSelection is created by a Format statement. Since
    LCL/DefaultTranslator does not execute code we have to update the translation
    of the label here. It is sufficient to call RgDrinksClick here where the
    caption is re-composed by means of the Format statement. }
  RgDrinksClick(nil);
end;

end.


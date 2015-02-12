unit LCLTranslator;

{ Copyright (C) 2004-2015 V.I.Volchenko and Lazarus Developers Team

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at your
  option) any later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
  for more details.

  You should have received a copy of the GNU Library General Public License
  along with this library; if not, write to the Free Software Foundation,
  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}
{
This unit is needed for using translated form strings made by Lazarus IDE.
It searches for translated .po/.mo files in some common places. If you need
to have .po/.mo files anywhere else, don't use this unit but initialize
LRSMoFile variable from LResources in your project by yourself.

If you need standard translation, just use this unit in your project and enable
i18n in project options. Note that you will have to call SetDefaultLang manually.
If you want it to be called automatically, use DefaultTranslator unit instead.

Another reason for including this unit may be using translated LCL messages.
This unit localizes LCL too, if it finds lclstrconsts.xx.po/lclstrconsts.xx.mo
in directory where your program translation files are placed.
}
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, GetText, Controls, typinfo, FileUtil,
  Translations, Forms, LazUTF8;

type

  { TUpdateTranslator }

  TUpdateTranslator = class(TAbstractTranslator)
  private
    FStackPath: string;
    procedure IntUpdateTranslation(AnInstance: TPersistent);
  public
    procedure UpdateTranslation(AnInstance: TPersistent);
  end;

  TDefaultTranslator = class(TUpdateTranslator)
  private
    FMOFile: TMOFile;
  public
    constructor Create(MOFileName: string);
    destructor Destroy; override;
    procedure TranslateStringProperty(Sender: TObject; const Instance: TPersistent;
      PropInfo: PPropInfo; var Content: string); override;
  end;

  { TPOTranslator }

  TPOTranslator = class(TUpdateTranslator)
  private
    FPOFile: TPOFile;
  public
    constructor Create(POFileName: string);
    destructor Destroy; override;
    procedure TranslateStringProperty(Sender: TObject; const Instance: TPersistent;
      PropInfo: PPropInfo; var Content: string); override;
  end;

procedure SetDefaultLang(Lang: string; Dir: string = ''; ForceUpdate: boolean = true);
function GetDefaultLang: String;

implementation

uses
  Menus;

type
  TPersistentAccess = class(TPersistent);

var
  DefaultLang: String = '';

function FindLocaleFileName(LCExt: string; Lang: string; Dir: string): string;
var
  T: string;
  i: integer;

  function GetLocaleFileName(const LangID, LCExt: string; Dir: string): string;
  var
    LangShortID: string;
    AppDir,LCFileName,FullLCFileName: String;
  begin
    DefaultLang := LangID;

    if LangID <> '' then
    begin
      AppDir := ExtractFilePath(ParamStrUTF8(0));
      LCFileName := ChangeFileExt(ExtractFileName(ParamStrUTF8(0)), LCExt);
      FullLCFileName := ChangeFileExt(ExtractFileName(ParamStrUTF8(0)), '.' + LangID) + LCExt;

      if Dir<>'' then
      begin
        Result := AppDir + Dir + DirectorySeparator + LangID +
          DirectorySeparator + LCFileName;
        if FileExistsUTF8(Result) then
          exit;
      end;

      //ParamStrUTF8(0) is said not to work properly in linux, but I've tested it
      Result := AppDir + LangID + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'languages' + DirectorySeparator + LangID +
        DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'locale' + DirectorySeparator + LangID +
        DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'locale' + DirectorySeparator + LangID +
        DirectorySeparator + 'LC_MESSAGES' + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      {$IFDEF UNIX}
      //In unix-like systems we can try to search for global locale
      Result := '/usr/share/locale/' + LangID + '/LC_MESSAGES/' + LCFileName;
      if FileExistsUTF8(Result) then
        exit;
      {$ENDIF}
      //Let us search for reducted files
      LangShortID := copy(LangID, 1, 2);
      Defaultlang := LangShortID;

      if Dir<>'' then
      begin
        Result := AppDir + Dir + DirectorySeparator +
          LangShortID + DirectorySeparator + LCFileName;
        if FileExistsUTF8(Result) then
          exit;
      end;

      //At first, check all was checked
      Result := AppDir + LangShortID + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'languages' + DirectorySeparator +
        LangShortID + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'locale' + DirectorySeparator
        + LangShortID + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'locale' + DirectorySeparator + LangShortID +
        DirectorySeparator + 'LC_MESSAGES' + DirectorySeparator + LCFileName;
      if FileExistsUTF8(Result) then
        exit;

      //Full language in file name - this will be default for the project
      //We need more careful handling, as it MAY result in incorrect filename
      try
        if Dir<>'' then
        begin
          Result := AppDir + Dir + DirectorySeparator + FullLCFileName;
          if FileExistsUTF8(Result) then
            exit;
        end;

        Result := AppDir + FullLCFileName;
        if FileExistsUTF8(Result) then
          exit;

        //Common location (like in Lazarus)
        Result := AppDir + 'locale' + DirectorySeparator + FullLCFileName;
        if FileExistsUTF8(Result) then
          exit;

        Result := AppDir + 'languages' + DirectorySeparator + FullLCFileName;
        if FileExistsUTF8(Result) then
          exit;
      except
        Result := '';//Or do something else (useless)
      end;
      {$IFDEF UNIX}
      Result := '/usr/share/locale/' + LangShortID + '/LC_MESSAGES/' +
        LCFileName;
      if FileExistsUTF8(Result) then
        exit;
      {$ENDIF}

      FullLCFileName := ChangeFileExt(ExtractFileName(ParamStrUTF8(0)), '.' + LangShortID) + LCExt;

      if Dir<>'' then
      begin
        Result := AppDir + Dir + DirectorySeparator + FullLCFileName;
        if FileExistsUTF8(Result) then
          exit;
      end;

      Result := AppDir + FullLCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'locale' + DirectorySeparator + FullLCFileName;
      if FileExistsUTF8(Result) then
        exit;

      Result := AppDir + 'languages' + DirectorySeparator + FullLCFileName;
      if FileExistsUTF8(Result) then
        exit;
    end;

    Result := '';
    DefaultLang := '';
  end;

begin
  Result := '';

  if Lang = '' then
    for i := 1 to Paramcount - 1 do
      if (ParamStrUTF8(i) = '--LANG') or (ParamStrUTF8(i) = '-l') or
        (ParamStrUTF8(i) = '--lang') then
        Lang := ParamStrUTF8(i + 1);

  //Win32 user may decide to override locale with LANG variable.
  if Lang = '' then
    Lang := GetEnvironmentVariableUTF8('LANG');

  if Lang = '' then
    LazGetLanguageIDs(Lang, T);

  Result := GetLocaleFileName(Lang, LCExt, Dir);
  if Result <> '' then
    exit;

  Result := ChangeFileExt(ParamStrUTF8(0), LCExt);
  if FileExistsUTF8(Result) then
    exit;

  Result := '';
  DefaultLang := '';
end;

function GetIdentifierPath(Sender: TObject;
                           const Instance: TPersistent;
                           PropInfo: PPropInfo): string;
var
  Tmp: TPersistent;
  Component: TComponent;
  Reader: TReader;
begin
  Result := '';
  if (PropInfo = nil) or
     (SysUtils.CompareText(PropInfo^.PropType^.Name, 'TTRANSLATESTRING') <> 0) then
    exit;

  // do not translate at design time
  // get the component
  Tmp := Instance;
  while Assigned(Tmp) and not (Tmp is TComponent) do
    Tmp := TPersistentAccess(Tmp).GetOwner;
  if not Assigned(Tmp) then
    exit;
  Component := Tmp as TComponent;
  if (csDesigning in Component.ComponentState) then
    exit;

  if (Sender is TReader) then
  begin
    Reader := TReader(Sender);
    if Reader.Driver is TLRSObjectReader then
      Result := TLRSObjectReader(Reader.Driver).GetStackPath
    else
      Result := Instance.ClassName + '.' + PropInfo^.Name;
  end else if (Sender is TUpdateTranslator) then
    Result := TUpdateTranslator(Sender).FStackPath + '.' + PropInfo^.Name;
  Result := UpperCase(Result);
end;

var
  lcfn: string;

{ TUpdateTranslator }

procedure TUpdateTranslator.IntUpdateTranslation(AnInstance: TPersistent);
var
  i,j: integer;
  APropCount: integer;
  APropList: PPropList;
  APropInfo: PPropInfo;
  TmpStr: string;
  APersistentProp: TPersistent;
  StoreStackPath: string;
begin
  APropCount := GetPropList(AnInstance.ClassInfo, APropList);
  try
    for i := 0 to APropCount-1 do
      begin
      APropInfo:=APropList^[i];
      if Assigned(PPropInfo(APropInfo)^.GetProc) and
         assigned(APropInfo^.PropType) and
         IsStoredProp(AnInstance, APropInfo) then
        case APropInfo^.PropType^.Kind of
          tkSString,
          tkLString,
          tkAString:  begin
                      TmpStr := '';
                      LRSTranslator.TranslateStringProperty(self,aninstance,APropInfo,TmpStr);
                      if TmpStr <>'' then
                        SetStrProp(AnInstance, APropInfo, TmpStr);
                      end;
          tkclass:    begin
                      APersistentProp := TPersistent(GetObjectProp(AnInstance, APropInfo, TPersistent));
                      if Assigned(APersistentProp) then
                        begin
                        if APersistentProp is TCollection then
                          begin
                          for j := 0 to TCollection(APersistentProp).Count-1 do
                            begin
                            StoreStackPath:=FStackPath;
                            FStackPath:=FStackPath+'.'+APropInfo^.Name+'['+inttostr(j)+']';
                            IntUpdateTranslation(TCollection(APersistentProp).Items[j]);
                            FStackPath:=StoreStackPath;
                            end;
                          end
                        else
                          begin
                          if APersistentProp is TComponent then
                            begin
                            if (csSubComponent in TComponent(APersistentProp).ComponentStyle) then
                              begin
                              StoreStackPath:=FStackPath;
                              FStackPath:=FStackPath+'.'+TComponent(APersistentProp).Name;
                              IntUpdateTranslation(APersistentProp);
                              FStackPath:=StoreStackPath;
                              end
                            end
                          else
                            begin
                            StoreStackPath:=FStackPath;
                            FStackPath:=FStackPath+'.'+APropInfo^.Name;
                            IntUpdateTranslation(APersistentProp);
                            FStackPath:=StoreStackPath;
                            end;
                          end;
                        end;
                      end;
          end;
      end;
  finally
    freemem(APropList);
  end;

  if (AnInstance is TComponent) then
    for i := 0 to TComponent(AnInstance).ComponentCount-1 do
      begin
      StoreStackPath:=FStackPath;
      if TComponent(AnInstance).Components[i] is TCustomFrame then
        UpdateTranslation(TComponent(AnInstance).Components[i]);
      FStackPath:=StoreStackPath+'.'+TComponent(AnInstance).Components[i].Name;
      IntUpdateTranslation(TComponent(AnInstance).Components[i]);
      FStackPath:=StoreStackPath;
      end;
end;

procedure TUpdateTranslator.UpdateTranslation(AnInstance: TPersistent);
begin
  FStackPath:=AnInstance.ClassName;
  IntUpdateTranslation(AnInstance);
end;

{ TDefaultTranslator }

constructor TDefaultTranslator.Create(MOFileName: string);
begin
  inherited Create;
  FMOFile := TMOFile.Create(UTF8ToSys(MOFileName));
end;

destructor TDefaultTranslator.Destroy;
begin
  FMOFile.Free;
  //If someone will use this class incorrectly, it can be destroyed
  //before Reader destroying. It is a very bad thing, but in THIS situation
  //in this case is impossible. Maybe, in future we can overcome this difficulty
  inherited Destroy;
end;

procedure TDefaultTranslator.TranslateStringProperty(Sender: TObject;
  const Instance: TPersistent; PropInfo: PPropInfo; var Content: string);
var
  s: string;
begin
  if Assigned(FMOFile) then
  begin
    s := GetIdentifierPath(Sender, Instance, PropInfo);
    if s <> '' then
    begin
      s := FMoFile.Translate(s + #4 + Content);

      if s = '' then
        s := FMOFile.Translate(Content);

      if s <> '' then
        Content := s;
    end;
  end;
end;

{ TPOTranslator }

constructor TPOTranslator.Create(POFileName: string);
begin
  inherited Create;
  // TPOFile expects AFileName in UTF-8 encoding, no conversion required
  FPOFile := TPOFile.Create(POFileName);
end;

destructor TPOTranslator.Destroy;
begin
  FPOFile.Free;
  //If someone will use this class incorrectly, it can be destroyed
  //before Reader destroying. It is a very bad thing, but in THIS situation
  //in this case is impossible. May be, in future we can overcome this difficulty
  inherited Destroy;
end;

procedure TPOTranslator.TranslateStringProperty(Sender: TObject;
  const Instance: TPersistent; PropInfo: PPropInfo; var Content: string);
var
  s: string;
begin
  if Assigned(FPOFile) then
  begin
    s := GetIdentifierPath(Sender, Instance, PropInfo);
    if s <> '' then
    begin
      s := FPOFile.Translate(s, Content);

      if s <> '' then
        Content := s;
    end;
  end;
end;

procedure SetDefaultLang(Lang: string; Dir: string = ''; ForceUpdate: boolean = true);
{ Arguments:
  Lang - language (e.g. 'ru', 'de'); empty argument is default language.
  Dir - custom translation files subdirectory (e.g. 'mylng'); empty argument means searching only in predefined subdirectories.
  ForceUpdate - true means forcing immediate interface update. Only should be set to false when the procedure is
    called from unit Initialization section. User code normally should not specify it.
}
var
  Dot1: integer;
  LCLPath: string;
  LocalTranslator: TUpdateTranslator;
  i: integer;

begin
  LocalTranslator := nil;
  // search first po translation resources
  try
     lcfn := FindLocaleFileName('.po', Lang, Dir);
     if lcfn <> '' then
     begin
       Translations.TranslateResourceStrings(lcfn);
       LCLPath := ExtractFileName(lcfn);
       Dot1 := pos('.', LCLPath);
       if Dot1 > 1 then
       begin
         Delete(LCLPath, 1, Dot1 - 1);
         LCLPath := ExtractFilePath(lcfn) + 'lclstrconsts' + LCLPath;
         Translations.TranslateUnitResourceStrings('LCLStrConsts', LCLPath);
       end;
       LocalTranslator := TPOTranslator.Create(lcfn);
     end;
   except
     lcfn := '';
   end;

  if lcfn='' then
  begin
    // try now with MO traslation resources
    try
      lcfn := FindLocaleFileName('.mo', Lang, Dir);
      if lcfn <> '' then
      begin
        GetText.TranslateResourceStrings(UTF8ToSys(lcfn));
        LCLPath := ExtractFileName(lcfn);
        Dot1 := pos('.', LCLPath);
        if Dot1 > 1 then
        begin
          Delete(LCLPath, 1, Dot1 - 1);
          LCLPath := ExtractFilePath(lcfn) + 'lclstrconsts' + LCLPath;
          if FileExistsUTF8(LCLPath) then
            GetText.TranslateResourceStrings(UTF8ToSys(LCLPath));
        end;
        LocalTranslator := TDefaultTranslator.Create(lcfn);
      end;
    except
      lcfn := '';
    end;
  end;

  if LocalTranslator<>nil then
  begin
    if Assigned(LRSTranslator) then
      LRSTranslator.Free;
    LRSTranslator := LocalTranslator;

    // Do not update the translations when this function is called from within
    // the unit initialization.
    if ForceUpdate=true then
    begin
      for i := 0 to Screen.CustomFormCount-1 do
        LocalTranslator.UpdateTranslation(Screen.CustomForms[i]);
    end;
  end;
end;

function GetDefaultLang: String;
begin
  if DefaultLang = '' then SetDefaultLang('');
  GetDefaultLang := DefaultLang;
end;

finalization
  LRSTranslator.Free;

end.

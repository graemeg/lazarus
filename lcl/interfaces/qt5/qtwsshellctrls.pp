{
 *****************************************************************************
 *                              WSShellCtrls.pp                              * 
 *                              -------------                                * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit qtwsshellctrls;

{$mode objfpc}{$H+}
{$I qtdefines.inc}

interface

uses
  SysUtils, Classes, ComCtrls, ShellCtrls, Types,
////////////////////////////////////////////////////
// To get as little as posible circles,
// uncomment only when needed for registration
////////////////////////////////////////////////////
//  Graphics, ImgList, Controls, ShellCtrls,
////////////////////////////////////////////////////
  WSShellCtrls;

type

  { TQTWSCustomShellTreeView }

  TQTWSCustomShellTreeView = class(TWSCustomShellTreeView)
  published
    class function DrawBuiltInIcon(ATreeView: TCustomShellTreeView;
      ANode: TTreeNode; ARect: TRect): Types.TSize; override;
    class function GetBuiltinIconSize: Types.TSize; override;
  end;

  { TQTWSCustomShellListView }
  TQTWSCustomShellListView = class(TWSCustomShellListView)
  published
    class function GetBuiltInImageIndex(AListView: TCustomShellListView;
      const AFileName: String; ALargeImage: Boolean): Integer; override;
  end;

implementation

uses
  graphics, qt5, qtobjects, Contnrs, LCLType, SyncObjs, BaseUnix, StrUtils,
  LazFileUtils, Controls, StringHashList, IniFiles;

var
  FExtToMimeIconName: TFPDataHashTable = nil;
  FLock: TCriticalSection = nil;
  FImageList: TImageList = nil;
  FCacheIcon: TStringHashList = nil;

const
  ICON_SIZE_SMALL = 16;
  ICON_SIZE_LARGE = 32;

procedure LoadMimeIconNames;
const
  mime_globs = '/usr/share/mime/globs';
  mime_generic_icons = '/usr/share/mime/generic-icons';
var
  I, J: Integer;
  globs: TStringList = nil;
  generic_icons: THashedStringList = nil;
  sMimeType,
  sMimeIconName,
  sExtension: String;
  node: THTDataNode = nil;
  iconsList: TStringList;
  EntriesCount: Cardinal;
begin
  if not Assigned(FLock) then
    FLock := TCriticalSection.Create;

  if not Assigned(FExtToMimeIconName) then
    FExtToMimeIconName := TFPDataHashTable.Create;

  FLock.Acquire;
  try
    if FExtToMimeIconName.Count = 0 then
    begin
      if FpAccess(mime_globs, R_OK) = 0 then
      begin
        // Load mapping: MIME type -> file extension.
        globs:= TStringList.Create;
        globs.NameValueSeparator:= ':';
        globs.LoadFromFile(mime_globs);

        // Try to load mapping: MIME type -> generic MIME icon name.
        if FileExists(mime_generic_icons) then
          begin
            generic_icons:= THashedStringList.Create;
            generic_icons.NameValueSeparator:= ':';
            generic_icons.LoadFromFile(mime_generic_icons);
          end;

        EntriesCount := 0;
        // Create mapping: file extension -> list of MIME icon names.
        for I:= 0 to globs.Count - 1 do
          if (globs.Strings[I]    <> EmptyStr) and   // bypass empty lines
             (globs.Strings[I][1] <> '#') then // and comments
          begin
            sMimeType := globs.Names[I];
            sMimeIconName:= StringReplace(sMimeType, '/', '-', []);
            sExtension:= globs.ValueFromIndex[I];

            // Support only extensions, not full file name masks.
            if (sExtension <> EmptyStr) and (sExtension <> '.*') then
            begin
              node := THTDataNode(FExtToMimeIconName.Find(sExtension));
              if not Assigned(node) then
                begin
                  iconsList := TStringList.Create;
                  FExtToMimeIconName.Add(sExtension, iconsList);
                  Inc(EntriesCount);
                end
              else
                iconsList := TStringList(node.Data);

              if iconsList.IndexOf(sMimeIconName) < 0 then
                iconsList.Add(sMimeIconName);

              // Shared-mime-info spec says:
              // "If [generic-icon] is not specified then the mimetype is used to generate the
              // generic icon by using the top-level media type (e.g. "video" in "video/ogg")
              // and appending "-x-generic" (i.e. "video-x-generic" in the previous example)."
              if Assigned(generic_icons) then
                begin
                  J := generic_icons.IndexOfName(sMimeType);
                  if J <> -1 then
                    sMimeIconName := generic_icons.ValueFromIndex[J] // found generic icon
                  else
                    sMimeIconName := Copy2Symb(sMimeIconName, '-') + '-x-generic';
                end
              else
                sMimeIconName := Copy2Symb(sMimeIconName, '-') + '-x-generic';

              if iconsList.IndexOf(sMimeIconName) < 0 then
                iconsList.Add(sMimeIconName);
            end;
          end;
      end;
    end;

  finally
    if Assigned(globs) then
      FreeAndNil(globs);
    if Assigned(generic_icons) then
      FreeAndNil(generic_icons);
    FLock.Release;
  end;

end;   

function IsDirectory(AFilename: String): Boolean;
var
  Info: BaseUnix.Stat;
begin
  Result := False;
  if fpStat(AFilename, Info) >= 0 then
    Result := fpS_ISDIR(Info.st_mode);
end;

function CheckIconName(const AIconName: Widestring): Boolean;
begin
  //QIcon_fromTheme can load icon name and absolute filepath, too
  Result := ((AIconName <> EmptyStr) and (QIcon_hasThemeIcon(@AIconName) or FileExists(AIconName)));
end;

function QIconToHBitmap(AIcon: QIconH; ASize: Types.TSize): HBITMAP;
var
  AImage: QImageH;
  APixmap: QPixmapH;
begin
  APixmap := QPixmap_create();
  QIcon_pixmap(AIcon, APixmap, Types.PSize(@ASize));

  AImage := QImage_create();
  QPixmap_toImage(APixmap, AImage);
  QPixmap_destroy(APixmap);

  Result := HBitmap(TQtImage.Create(AImage));
end;

function ExtractIcon(const sIconName: WideString; ALargeImage: Boolean): TBitmap;
var
  QIcon: QIconH;
  Size: Types.TSize;
begin
  Result := TBitmap.Create; 

  if ALargeImage then
    Size := Types.Size(ICON_SIZE_LARGE, ICON_SIZE_LARGE)
  else
    Size := Types.Size(ICON_SIZE_SMALL, ICON_SIZE_SMALL);

  QIcon := QIcon_Create();
  try
    if CheckIconName(sIconName) then
    begin
      QIcon_fromTheme(QIcon, @sIconName);
      Result.Handle := QIconToHBitmap(QIcon, Size);
    end;
  finally
    QIcon_destroy(QIcon);
  end;
end;

function GetIconByDesktopFile(AFileName: String): String;
var
  iniDesktop: TIniFile = nil;
begin
  Result := EmptyStr;

  try
    iniDesktop := TIniFile.Create(AFileName);
    try
      Result := iniDesktop.ReadString('Desktop Entry', 'Icon', EmptyStr);
    finally
      FreeAndNil(iniDesktop);
    end;
  except
    Exit;
  end;
end;

function GetIconName(const AFileName: WideString): WideString;
var
  I: Integer;
  node: THTDataNode;
  iconList: TStringList;
  Extension: String;
begin
  LoadMimeIconNames;

  Result := EmptyStr;

  //It is a link? Ok, get target file icon
  if FpReadLink(AFilename) <> EmptyStr then
    Extension := '*' + ExtractFileExt(FpReadLink(AFileName))
  else
    Extension := '*' + ExtractFileExt(AFileName);

  Extension := LowerCase(Extension);

  //TODO: Special folders icon https://gitlab.gnome.org/GNOME/glib/-/commit/129eb074823101102611690f053ffa246bb7784d#3549e1301fc4c17bf0dd809eca0a36fb87aac264_1582_1582

  if IsDirectory(AFileName) then
  begin
    if FileExists(AFileName + PathDelim + '.directory') then
      Result := GetIconByDesktopFile(AFileName + PathDelim + '.directory')
    else
      Result := 'folder';
  end
  else if (Extension = '*.desktop') then
  begin
    Result := GetIconByDesktopFile(AFileName);
  end
  else if FileIsExecutable(AFileName) then
  begin
    Result := 'application-x-executable';
  end
  else if (Extension = '*.ico') then
  begin
    Result := AFileName;
  end
  else if (Extension <> '*') then
  begin
    node := THTDataNode(FExtToMimeIconName.Find(Extension));
    if Assigned(node) then
      begin
        iconList := TStringList(node.Data);

        //First valid icon wins
        for I := 0 to iconList.Count - 1 do
          begin
            Result := iconList.Strings[I];
            if QIcon_hasThemeIcon(@Result) then
              break;
          end;
      end;
  end;

  //Not found icon? No problem. Use generic icon
  if (not CheckIconName(Result)) or (Result = EmptyStr) then
  begin
    if FileIsText(AFileName) then
      Result := 'text-x-generic'
    else
      Result := 'unknown';
  end;
end;

procedure CreateLVImageList;
begin
  if Assigned(FImageList) then
    Exit;

  FImageList := TImageList.Create(nil);

  FImageList.RegisterResolutions([ICON_SIZE_SMALL, ICON_SIZE_LARGE]);
end;

{ TQTWSCustomShellTreeView }

class function TQTWSCustomShellTreeView.DrawBuiltInIcon(ATreeView: TCustomShellTreeView;
  ANode: TTreeNode; ARect: TRect): Types.TSize;
var
  filename: WideString;
  bmp: TBitmap;
  iconName: String;
begin
  fileName := ATreeView.GetPathFromNode(ANode);
  iconName := GetIconName(fileName);
  bmp := ExtractIcon(iconName, False);
  try
    ATreeView.Canvas.Draw(ARect.Left, (ARect.Top + ARect.Bottom - bmp.Height) div 2, bmp);
    Result := Types.Size(bmp.Width, bmp.Height);
  finally
    bmp.Free;
  end;
end;

class function TQTWSCustomShellTreeView.GetBuiltinIconSize: Types.TSize;
begin
  Result := Types.Size(ICON_SIZE_SMALL, ICON_SIZE_SMALL);
end;


{ TQTWSCustomShellListView }

class function TQTWSCustomShellListView.GetBuiltInImageIndex(
  AListView: TCustomShellListView; const AFileName: String;
  ALargeImage: Boolean): Integer;
var
  bmpSmall, bmpLarge: TBitmap;
  iconName: String;
  FCacheImageIndex: Integer;
begin
  Result := -1;

  CreateLVImageList;

  if ALargeImage then
  begin
    AListView.SmallImages := nil;
    AListView.SmallImagesWidth := 0;
    AListView.LargeImages := FImageList;
    AListView.LargeImagesWidth := ICON_SIZE_LARGE;
  end
  else begin
    AListView.SmallImages := FImageList;
    AListView.SmallImagesWidth := ICON_SIZE_SMALL;
    AListView.LargeImages := nil;
    AListView.LargeImagesWidth := 0;
  end;

  if FCacheIcon = nil then
    FCacheIcon := TStringHashList.Create(True);

  iconName := GetIconName(AFileName);

  FCacheImageIndex := FCacheIcon.Find(iconName);
  if FCacheImageIndex < 0 then
  begin
    bmpSmall := ExtractIcon(iconName, False);
    bmpLarge := ExtractIcon(iconName, True);
    try
      Result := FImageList.AddMultipleResolutions([bmpSmall, bmpLarge]);

      FCacheIcon.Add(iconName, Pointer(Result));
    finally
      bmpSmall.Free;
      bmpLarge.Free;
    end;
  end
  else begin
    Result := PtrInt(FCacheIcon.List[FCacheImageIndex]^.Data);
  end;
end;

procedure ClearExtToMimeList;
var
  nodeList: TFPObjectList;
  I, J : Integer;
begin
  for I := 0 to FExtToMimeIconName.HashTable.Count - 1 do
  begin
    begin
      nodeList := TFPObjectList(FExtToMimeIconName.HashTable.Items[I]);
      if Assigned(nodeList) then
        for J := 0 to nodeList.Count - 1 do
          TStringList(THtDataNode(nodeList.Items[J]).Data).Free;
    end;
  end;
end;

finalization
  if Assigned(FExtToMimeIconName) then
  begin
    ClearExtToMimeList;
    FExtToMimeIconName.Free;
  end;

  if Assigned(FLock) then
    FLock.Free;

  if Assigned(FImageList) then
    FImageList.Free;

  if Assigned(FCacheIcon) then
    FCacheIcon.Free;

end.
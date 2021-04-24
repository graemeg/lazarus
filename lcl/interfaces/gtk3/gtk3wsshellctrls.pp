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
unit gtk3wsshellctrls;

{$mode objfpc}{$H+}

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

  { TGTK3WSCustomShellTreeView }

  TGTK3WSCustomShellTreeView = class(TWSCustomShellTreeView)
  published
    class function DrawBuiltInIcon(ATreeView: TCustomShellTreeView;
      ANode: TTreeNode; ARect: TRect): Types.TSize; override;
    class function GetBuiltinIconSize: Types.TSize; override;
  end;

  { TGTK3WSCustomShellListView }
  TGTK3WSCustomShellListView = class(TWSCustomShellListView)
  published
    class function GetBuiltInImageIndex(AListView: TCustomShellListView;
      const AFileName: String; ALargeImage: Boolean): Integer; override;
  end;

implementation

uses
  lazgtk3, lazgdkpixbuf2, LazGLib2, LazGdk3, LazGObject2,
  GraphType, IntfGraphics, graphics, Contnrs, LCLType, SyncObjs, BaseUnix,
  StrUtils, LazFileUtils, Controls, StringHashList, IniFiles;

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

function CheckIconName(const AIconName: String): Boolean;
begin
  Result := ((AIconName <> EmptyStr) and (gtk_icon_theme_has_icon(gtk_icon_theme_get_default, PChar(AIconName)) or
             FileExists(AIconName)));
end;

function PixBufToBitmap(Pixbuf: PGdkPixbuf): TBitmap;
var
  width, height, rowstride, n_channels, i, j: Integer;
  pixels: ^guchar;
  pSrc: PByte;
  pDst: PLongWord;
  BmpData: TLazIntfImage;
  hasAlphaChannel: Boolean;
  QueryFlags: TRawImageQueryFlags = [riqfRGB];
  Description: TRawImageDescription;    
  ARawImage: TRawImage;
begin
  Result := nil;

  n_channels:= gdk_pixbuf_get_n_channels(Pixbuf);

  if ((n_channels <> 3) and (n_channels <> 4)) or  // RGB or RGBA
     (gdk_pixbuf_get_colorspace(pixbuf) <> GDK_COLORSPACE_RGB) or
     (gdk_pixbuf_get_bits_per_sample(pixbuf) <> 8) then Exit;

  width:= gdk_pixbuf_get_width(Pixbuf);
  height:= gdk_pixbuf_get_height(Pixbuf);
  rowstride:= gdk_pixbuf_get_rowstride(Pixbuf);
  pixels:= gdk_pixbuf_get_pixels(Pixbuf);
  hasAlphaChannel:= gdk_pixbuf_get_has_alpha(Pixbuf);

  if hasAlphaChannel then
    Include(QueryFlags, riqfAlpha);

  BmpData := TLazIntfImage.Create(width, height, QueryFlags);
  try
    BmpData.CreateData;
    Description := BmpData.DataDescription;

    pDst := PLongWord(BmpData.PixelData);
    for j:= 0 to Height - 1 do
    begin
      pSrc := PByte(pixels) + j * rowstride;
      for i:= 0 to Width - 1 do
      begin
        pDst^ := pSrc[0] shl Description.RedShift +
                 pSrc[1] shl Description.GreenShift +
                 pSrc[2] shl Description.BlueShift;

        if hasAlphaChannel then
          pDst^ := pDst^ + pSrc[3] shl Description.AlphaShift;

        Inc(pSrc, n_channels);
        Inc(pDst);
      end;
    end;

    Result := TBitmap.Create;

    BmpData.GetRawImage(ARawImage, True);
    // Simply change raw image owner without data copy
    Result.LoadFromRawImage(ARawImage, True);

    if not hasAlphaChannel then
      Result.Transparent := True;

  finally
    BmpData.Free;
  end;
end;

function ExtractIcon(const sIconName: String; ALargeImage: Boolean): TBitmap;
var            
  pbPicture: PGdkPixbuf = nil;
  Size: Integer;
begin
  Result := nil;

  if ALargeImage then
    Size := ICON_SIZE_LARGE
  else
    Size := ICON_SIZE_SMALL;

  try
    if CheckIconName(sIconName) then
    begin
      if FileExists(sIconName) then
        pbPicture := gdk_pixbuf_new_from_file_at_size(PChar(sIconName), Size, Size, nil)
      else
        pbPicture := gtk_icon_theme_load_icon(gtk_icon_theme_get_for_screen(gdk_screen_get_default), Pgchar(sIconName), Size, GTK_ICON_LOOKUP_USE_BUILTIN, nil);
    end;

    if Assigned(pbPicture) then
      Result := PixBufToBitmap(pbPicture)
    else
      Result := TBitmap.Create;
  finally
    g_object_unref(pbPicture);
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

function GetIconName(const AFileName: String): String;
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
            if gtk_icon_theme_has_icon(gtk_icon_theme_get_default, PChar(Result)) then
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

{ TGTK3WSCustomShellTreeView }

class function TGTK3WSCustomShellTreeView.DrawBuiltInIcon(ATreeView: TCustomShellTreeView;
  ANode: TTreeNode; ARect: TRect): Types.TSize;
var
  filename: String;
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

class function TGTK3WSCustomShellTreeView.GetBuiltinIconSize: Types.TSize;
begin
  Result := Types.Size(ICON_SIZE_SMALL, ICON_SIZE_SMALL);
end;


{ TGTK3WSCustomShellListView }

class function TGTK3WSCustomShellListView.GetBuiltInImageIndex(
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
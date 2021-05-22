{
 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit UnityWSCtrls;

interface

{$mode delphi}
{$I gtk2defines.inc}

uses
  GLib2, Gtk2, Gdk2Pixbuf,
  Classes, SysUtils, dynlibs,
  Graphics, Controls, Forms, ExtCtrls, WSExtCtrls, LCLType, LazUTF8,
  FileUtil;

{ Copyleft implementation of TTrayIcon originally for Unity applications indicators
  Original version 2015 by Anthony Walter sysrpl@gmail.com

  Updated May 2021 to try first the Canonical libappindicator3-1 (Fedora Gnome)
  then libayatana-appindicator3-1 (Debian Bullseye). Ayatana is a fork of the
  Canonical one, does not mention Unity or Ubuntu (very much). DRB

  Changed October 2019, we now try and identify those Linux distributions that
  need to use LibAppIndicator3 and allow the remainder to use the older and
  more functional SystemTray. Only a few old distributions can use LibAppIndicator_1
  so don't bother to try it, rely, here on LibAppIndicator3

  The 'look up table' in NeedAppIndicator() can be overridden.
  Introduce an optional env var, LAZUSEAPPIND that can be unset or set to
  YES, NO or INFO - YES forces an attempt to use one of the AppIndicator3, NO prevents
  an attempt, any non blank value (eg INFO) displays to std out what is happening.

  Note we assume this env var will only be used in Linux were its always safe to
  write to stdout.
  DRB
}

{ TUnityWSCustomTrayIcon is the class for tray icons on systems
  running the Unity desktop environment.

  Unity allows only AppIndicator objects in its tray. These objects
  have the following reduced functionality:

  Tooltips are not allowed
  Icons do not receive mouse events
  Indicators display a menu when clicked by any mouse button

  See also: http://www.markshuttleworth.com/archives/347
  "Clicking on an indicator will open its menu..."
  "There’ll be no ability for arbitrary applications to define arbitrary
   behaviours to arbitrary events on indicators"

  Personal observations:

  A popup menu is required always
  You can only create one AppIndicator per appplication
  You cannot use a different popupmenu once one has been used }

type
  TUnityWSCustomTrayIcon = class(TWSCustomTrayIcon)
  published
    class function Hide(const ATrayIcon: TCustomTrayIcon): Boolean; override;
    class function Show(const ATrayIcon: TCustomTrayIcon): Boolean; override;
    class procedure InternalUpdate(const ATrayIcon: TCustomTrayIcon); override;
    class function GetPosition(const {%H-}ATrayIcon: TCustomTrayIcon): TPoint; override;
  end;

{ UnityAppIndicatorInit returns true if an AppIndicator library can be loaded }

function UnityAppIndicatorInit: Boolean;

implementation

// X is needed to test for traditional SysTray being available
{$IFDEF HASX}uses gtk2extra, x, xlib;{$ENDIF}

const
  libappindicator_3 = 'libappindicator3.so.1';              // Canonical's Unity Appindicator3 library
  LibAyatanaAppIndicator = 'libayatana-appindicator3.so.1'; // Ayatana - typically called libayatana-appindicator3-1

{const
  APP_INDICATOR_SIGNAL_NEW_ICON = 'new-icon';
  APP_INDICATOR_SIGNAL_NEW_ATTENTION_ICON = 'new-attention-icon';
  APP_INDICATOR_SIGNAL_NEW_STATUS = 'new-status';
  APP_INDICATOR_SIGNAL_NEW_LABEL = 'new-label';
  APP_INDICATOR_SIGNAL_CONNECTION_CHANGED = 'connection-changed';
  APP_INDICATOR_SIGNAL_NEW_ICON_THEME_PATH = 'new-icon-theme-path';
}
type
  TAppIndicatorCategory = (
    APP_INDICATOR_CATEGORY_APPLICATION_STATUS,
    APP_INDICATOR_CATEGORY_COMMUNICATIONS,
    APP_INDICATOR_CATEGORY_SYSTEM_SERVICES,
    APP_INDICATOR_CATEGORY_HARDWARE,
    APP_INDICATOR_CATEGORY_OTHER
  );

  TAppIndicatorStatus = (
    APP_INDICATOR_STATUS_PASSIVE,
    APP_INDICATOR_STATUS_ACTIVE,
    APP_INDICATOR_STATUS_ATTENTION
  );

  PAppIndicator = Pointer;

var
  { GlobalAppIndicator creation routines }
  app_indicator_get_type: function: GType; cdecl;
  app_indicator_new: function(id, icon_name: PGChar; category: TAppIndicatorCategory): PAppIndicator; cdecl;
  app_indicator_new_with_path: function(id, icon_name: PGChar; category: TAppIndicatorCategory; icon_theme_path: PGChar): PAppIndicator; cdecl;
  { Set properties }
  app_indicator_set_status: procedure(self: PAppIndicator; status: TAppIndicatorStatus); cdecl;
  app_indicator_set_attention_icon: procedure(self: PAppIndicator; icon_name: PGChar); cdecl;
  app_indicator_set_menu: procedure(self: PAppIndicator; menu: PGtkMenu); cdecl;
  app_indicator_set_icon: procedure(self: PAppIndicator; icon_name: PGChar); cdecl;
  app_indicator_set_label: procedure(self: PAppIndicator; _label, guide: PGChar); cdecl;
  app_indicator_set_icon_theme_path: procedure(self: PAppIndicator; icon_theme_path: PGChar); cdecl;
  app_indicator_set_ordering_index: procedure(self: PAppIndicator; ordering_index: guint32); cdecl;
  { Get properties }
  app_indicator_get_id: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_category: function(self: PAppIndicator): TAppIndicatorCategory; cdecl;
  app_indicator_get_status: function(self: PAppIndicator): TAppIndicatorStatus; cdecl;
  app_indicator_get_icon: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_icon_theme_path: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_attention_icon: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_menu: function(self: PAppIndicator): PGtkMenu; cdecl;
  app_indicator_get_label: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_label_guide: function(self: PAppIndicator): PGChar; cdecl;
  app_indicator_get_ordering_index: function(self: PAppIndicator): guint32; cdecl;

{ TUnityTrayIconHandle }

type
  TUnityTrayIconHandle = class
  private
    FTrayIcon: TCustomTrayIcon;
    FName: string;
    FIconName: string;
  public
    constructor Create(TrayIcon: TCustomTrayIcon);
    destructor Destroy; override;
    procedure Update;
  end;

{ It seems to me, and please tell me otherwise if untrue, that the only way
  to load icons for AppIndicator is through files }

const
  IconThemePath = '/tmp/appindicators/';
  IconType = 'png';

{ It seems to me, and please tell me otherwise if untrue, that you can only
  create one working AppIndicator for your program over its lifetime }

var
  GlobalAppIndicator: PAppIndicator;
  GlobalIcon: Pointer;
  GlobalIconPath: string;

constructor TUnityTrayIconHandle.Create(TrayIcon: TCustomTrayIcon);
var
  NewIcon: Pointer;
begin
  inherited Create;
  FTrayIcon := TrayIcon;
  FName := 'app-' + IntToHex(IntPtr(Application), SizeOf(IntPtr) * 2);
  NewIcon := {%H-}Pointer(FTrayIcon.Icon.Handle);
  if NewIcon = nil then
    NewIcon := {%H-}Pointer(Application.Icon.Handle);
  if NewIcon <> GlobalIcon then
  begin
    GlobalIcon := NewIcon;
    ForceDirectories(IconThemePath);
    FIconName := FName + '-' + IntToHex({%H-}IntPtr(GlobalIcon), SizeOf(GlobalIcon) * 2);
    if FileExists(GlobalIconPath) then
      DeleteFile(GlobalIconPath);
    GlobalIconPath := IconThemePath + FIconName + '.' + IconType;
    gdk_pixbuf_save(GlobalIcon, PChar(GlobalIconPath), IconType, nil, [nil]);
    if GlobalAppIndicator <> nil then
      app_indicator_set_icon(GlobalAppIndicator, PChar(FIconName));
  end
  else
    FIconName := FName + '-' + IntToHex({%H-}IntPtr(GlobalIcon), SizeOf(GlobalIcon) * 2);
  { Only the first created AppIndicator is functional }
  if GlobalAppIndicator = nil then
    { It seems that icons can only come from files :( }
    GlobalAppIndicator := app_indicator_new_with_path(PChar(FName), PChar(FIconName),
      APP_INDICATOR_CATEGORY_APPLICATION_STATUS, IconThemePath);
  Update;
end;

destructor TUnityTrayIconHandle.Destroy;
begin
  { Hide the global AppIndicator }
  app_indicator_set_status(GlobalAppIndicator, APP_INDICATOR_STATUS_PASSIVE);
  inherited Destroy;
end;

procedure TUnityTrayIconHandle.Update;
var
  NewIcon: Pointer;
begin
  NewIcon := {%H-}Pointer(FTrayIcon.Icon.Handle);
  if NewIcon = nil then
    NewIcon := {%H-}Pointer(Application.Icon.Handle);
  if NewIcon <> GlobalIcon then
  begin
    GlobalIcon := NewIcon;
    FIconName := FName + '-' + IntToHex({%H-}IntPtr(GlobalIcon), SizeOf(GlobalIcon) * 2);
    ForceDirectories(IconThemePath);
    if FileExists(GlobalIconPath) then
      DeleteFile(GlobalIconPath);
    GlobalIconPath := IconThemePath + FIconName + '.' + IconType;
    gdk_pixbuf_save(GlobalIcon, PChar(GlobalIconPath), IconType, nil, [nil]);
    { Again it seems that icons can only come from files }
    app_indicator_set_icon(GlobalAppIndicator, PChar(FIconName));
  end;
  { It seems to me you can only set the menu once for an AppIndicator }
  if (app_indicator_get_menu(GlobalAppIndicator) = nil) and (FTrayIcon.PopUpMenu <> nil) then
    app_indicator_set_menu(GlobalAppIndicator, {%H-}PGtkMenu(FTrayIcon.PopUpMenu.Handle));
  app_indicator_set_status(GlobalAppIndicator, APP_INDICATOR_STATUS_ACTIVE);
end;

{ TUnityWSCustomTrayIcon }

class function TUnityWSCustomTrayIcon.Hide(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  T: TUnityTrayIconHandle;
begin
  if ATrayIcon.Handle <> 0 then
  begin
    T := TUnityTrayIconHandle(ATrayIcon.Handle);
    ATrayIcon.Handle := 0;
    T.Free;
  end;
  Result := True;
end;

class function TUnityWSCustomTrayIcon.Show(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  T: TUnityTrayIconHandle;
begin
  if ATrayIcon.Handle = 0 then
  begin
    T := TUnityTrayIconHandle.Create(ATrayIcon);
    ATrayIcon.Handle := HWND(T);
  end;
  Result := True;
end;

class procedure TUnityWSCustomTrayIcon.InternalUpdate(const ATrayIcon: TCustomTrayIcon);
var
  T: TUnityTrayIconHandle;
begin
  if ATrayIcon.Handle <> 0 then
  begin
    T := TUnityTrayIconHandle(ATrayIcon.Handle);
    T.Update;
  end;
end;

class function TUnityWSCustomTrayIcon.GetPosition(const ATrayIcon: TCustomTrayIcon): TPoint;
begin
  Result := Point(0, 0);
end;

{ UnityAppIndicatorInit }

var
  Loaded: Boolean;
  Initialized: Boolean;

function UnityAppIndicatorInit: Boolean;
var
  Module: HModule;
  UseAppInd : string;

  function NeedAppIndicator: boolean;
  {$IFDEF HASX}
  // Here we assume if no X, its pure eg wayland so no traditional SysTray either.
  var
    A : TAtom;
    XDisplay: PDisplay;
  {$endif}
  begin
    Result := True;
    {$IFDEF HASX}
    XDisplay := gdk_display;
    A := XInternAtom(XDisplay, '_NET_SYSTEM_TRAY_S0', False);
    result := (XGetSelectionOwner(XDisplay, A) = 0);
    {$endif}
  end;

  function TryLoad(const ProcName: string; var Proc: Pointer): Boolean;
  begin
    Proc := GetProcAddress(Module, ProcName);
    Result := Proc <> nil;
  end;

begin
  Result := False;
  if Loaded then
    Exit(Initialized);
  Loaded := True;
  if Initialized then
    Exit(True);
  UseAppInd := getEnvironmentVariable('LAZUSEAPPIND');
  if UseAppInd = 'NO' then
  begin
    Initialized := False;
    writeln('APPIND Debug : Choosing to use Traditional SysTray');
    Exit;
  end;
  if (UseAppInd <> 'YES') and (not NeedAppIndicator()) then    // ie its NO or blank or INFO
  begin
    Initialized := False;
    if UseAppInd <> '' then
      writeln('APPIND Debug : Will use Traditional SysTray');
    Exit;
  end;
  if UseAppInd = 'YES' then                                    // either a YES or OS needs it
    writeln('APPIND Debug : Will try to force AppIndicator3')
  else
    if UseAppInd <> '' then
      writeln('APPIND Debug : OS and Desktop request AppIndicator');

  Module := LoadLibrary(libappindicator_3);        // might have several package names, see wiki
  if Module = 0 then begin
    if UseAppInd <> '' then                                    // either a YES or OS needs it
      writeln('APPIND Debug : Failed to load Unity AppIndicator, will try Ayatana');
    Module := LoadLibrary(LibAyatanaAppIndicator);
    if Module = 0 then begin
      if UseAppInd <> '' then
        writeln('APPIND Debug : Failed to load Ayatana AppIndicator, its likely no SysTray available.');
      exit(False);
    end;
  end;

  Result :=
    TryLoad('app_indicator_get_type', @app_indicator_get_type) and
    TryLoad('app_indicator_new', @app_indicator_new) and
    TryLoad('app_indicator_new_with_path', @app_indicator_new_with_path) and
    TryLoad('app_indicator_set_status', @app_indicator_set_status) and
    TryLoad('app_indicator_set_attention_icon', @app_indicator_set_attention_icon) and
    TryLoad('app_indicator_set_menu', @app_indicator_set_menu) and
    TryLoad('app_indicator_set_icon', @app_indicator_set_icon) and
    TryLoad('app_indicator_set_label', @app_indicator_set_label) and
    TryLoad('app_indicator_set_icon_theme_path', @app_indicator_set_icon_theme_path) and
    TryLoad('app_indicator_set_ordering_index', @app_indicator_set_ordering_index) and
    TryLoad('app_indicator_get_id', @app_indicator_get_id) and
    TryLoad('app_indicator_get_category', @app_indicator_get_category) and
    TryLoad('app_indicator_get_status', @app_indicator_get_status) and
    TryLoad('app_indicator_get_icon', @app_indicator_get_icon) and
    TryLoad('app_indicator_get_icon_theme_path', @app_indicator_get_icon_theme_path) and
    TryLoad('app_indicator_get_attention_icon', @app_indicator_get_attention_icon) and
    TryLoad('app_indicator_get_menu', @app_indicator_get_menu) and
    TryLoad('app_indicator_get_label', @app_indicator_get_label) and
    TryLoad('app_indicator_get_label_guide', @app_indicator_get_label_guide) and
    TryLoad('app_indicator_get_ordering_index', @app_indicator_get_ordering_index);
  if UseAppInd <> '' then
     writeln('APPIND Debug : An AppIndicator has loaded ' + booltostr(Result, True));
  Initialized := Result;
end;

initialization
  GlobalAppIndicator := nil;
  GlobalIconPath := '';
finalization
  if FileExists(GlobalIconPath) then
    DeleteFile(GlobalIconPath);
  if GlobalAppIndicator <> nil then
    g_object_unref(GlobalAppIndicator);
end.

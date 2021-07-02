{ $Id: Cocoawsmenus.pp 15309 2008-06-04 22:12:59Z vincents $}
{
 *****************************************************************************
 *                               CocoaWSMenus.pp                             *
 *                               ------------                                * 
 *                                                                           *
 *                                                                           *
 *****************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}
unit CocoaWSMenus;

{$mode objfpc}{$H+}
{$modeswitch objectivec2}
{$include cocoadefines.inc}

interface

uses
  // Libs
  CocoaAll,
  MacOSAll,
  // RTL
  sysutils,
  // LCL
  Controls, Forms, Menus, Graphics, LCLType, LMessages, LCLProc, Classes,
  LCLMessageGlue, LCLStrConsts,
  // Widgetset
  WSMenus, WSLCLClasses,
  // LCL Cocoa
  Cocoa_extra,
  CocoaPrivate, CocoaWSCommon, CocoaUtils, CocoaGDIObjects;

type

  IMenuItemCallback = interface(ICommonCallBack)
    procedure ItemSelected;
    function MenuItemTarget: TMenuItem;
  end;

  { TLCLMenuItemCallback }

  TLCLMenuItemCallback = class(TLCLCommonCallback, IMenuItemCallback)
  private
    FMenuItemTarget: TMenuItem;
  public
    constructor Create(AOwner: NSObject; AMenuItemTarget: TMenuItem); reintroduce;
    procedure ItemSelected;
    function MenuItemTarget: TMenuItem;
  end;

  TCocoaMenuItem = objcclass;

  { TCocoaMenu }

  TCocoaMenu = objcclass(NSMenu)
  private
    appleMenu: TCocoaMenuItem;
    attachedAppleMenu: Boolean;
    isKeyEq: Boolean;
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
    procedure createAppleMenu(); message 'createAppleMenu';
    procedure overrideAppleMenu(AItem: TCocoaMenuItem); message 'overrideAppleMenu:';
    procedure attachAppleMenu(); message 'attachAppleMenu';
    function performKeyEquivalent(theEvent: NSEvent): LCLObjCBoolean; override;
    function lclIsKeyEquivalent: LCLObjCBoolean; message 'lclIsKeyEquivalent';
  end;

  { TCocoaMenuItem }

  TCocoaMenuItem = objcclass(NSMenuItem, NSMenuDelegateProtocol)
  public
    menuItemCallback: IMenuItemCallback;
    attachedAppleMenuItems: Boolean;
    FMenuItemTarget: TMenuItem;
    procedure UncheckSiblings(AIsChangingToChecked: LCLObjCBoolean = False); message 'UncheckSiblings:';
    function GetMenuItemHandle(): TMenuItem; message 'GetMenuItemHandle';
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
    function lclGetCallback: IMenuItemCallback; override;
    procedure lclClearCallback; override;
    procedure attachAppleMenuItems(); message 'attachAppleMenuItems';
    function isValidAppleMenu(): LCLObjCBoolean; message 'isValidAppleMenu';
    // menuWillOpen cannot be used. Because it SHOULD NOT change the contents
    // of the menu. While LCL allows to modify the menu contents when the submenu
    // is about to be activated.
    procedure menuNeedsUpdate(AMenu: NSMenu); message 'menuNeedsUpdate:';
    //procedure menuDidClose(AMenu: NSMenu); message 'menuDidClose:';
    function worksWhenModal: LCLObjCBoolean; message 'worksWhenModal';
  end;

  TCocoaMenuItem_HideApp = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_HideOthers = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_ShowAllApp = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  TCocoaMenuItem_Quit = objcclass(NSMenuItem)
  public
    procedure lclItemSelected(sender: id); message 'lclItemSelected:';
  end;

  { TCocoaWSMenuItem }

  TCocoaWSMenuItem = class(TWSMenuItem)
  private
    class procedure Do_SetCheck(const ANSMenuItem: NSMenuItem; const Checked: boolean);
    // used from the MenuMadness example
    class function NSMenuCheckmark: NSImage;
    class function NSMenuRadio: NSImage;
    class function isSeparator(const ACaption: AnsiString): Boolean;
  published
    class procedure AttachMenu(const AMenuItem: TMenuItem); override;
    class function  CreateHandle(const AMenuItem: TMenuItem): HMENU; override;
    class procedure DestroyHandle(const AMenuItem: TMenuItem); override;
    class procedure SetCaption(const AMenuItem: TMenuItem; const ACaption: string); override;
    class procedure SetShortCut(const AMenuItem: TMenuItem; const ShortCutK1, ShortCutK2: TShortCut); override;
    class procedure SetVisible(const AMenuItem: TMenuItem; const Visible: boolean); override;
    class function SetCheck(const AMenuItem: TMenuItem; const Checked: boolean): boolean; override;
    class function SetEnable(const AMenuItem: TMenuItem; const Enabled: boolean): boolean; override;
    class function SetRadioItem(const AMenuItem: TMenuItem; const RadioItem: boolean): boolean; override;
    //class function SetRightJustify(const AMenuItem: TMenuItem; const Justified: boolean): boolean; override;
    class procedure UpdateMenuIcon(const AMenuItem: TMenuItem; const HasIcon: Boolean; const AIcon: TBitmap); override;
  end;

  { TCocoaWSMenu }

  TCocoaWSMenu = class(TWSMenu)
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
  end;

  { TCocoaWSMainMenu }

  TCocoaWSMainMenu = class(TWSMainMenu)
  published
    class function CreateHandle(const AMenu: TMenu): HMENU; override;
  end;

  { TCocoaWSPopupMenu }

  TCocoaWSPopupMenu = class(TWSPopupMenu)
  published
    class procedure Popup(const APopupMenu: TPopupMenu; const X, Y: Integer); override;
  end;

procedure NSMenuItemSetBitmap(mn: NSMenuItem; bmp: TBitmap);

// the returned "Key" should not be released, as it's not memory owned
procedure ShortcutToKeyEquivalent(const AShortCut: TShortcut; out Key: NSString; out shiftKeyMask: NSUInteger);

// returns the last state the menu was at
function ToggleAppMenu(ALogicalEnabled: Boolean): Boolean;

function AllocCocoaMenu(const atitle: string = ''): TCocoaMenu;
function LCLMenuItemInit(item: NSMenuItem; const atitle: string; ashortCut: TShortCut): id;
function LCLMenuItemInit(item: NSMenuItem; const atitle: string; VKKey: Word = 0; State: TShiftState = []): id;

implementation

uses
  CocoaInt;

function LCLMenuItemInit(item: NSMenuItem; const atitle: string; ashortCut: TShortCut): id;
var
  key   : NSString;
  mask  : NSUInteger;
begin
  ShortcutToKeyEquivalent(ashortCut, key, mask);

  Result := item.initWithTitle_action_keyEquivalent(
    ControlTitleToNSStr(Atitle),
    objcselector('lclItemSelected:'), // Selector is Hard-coded, that's why it's LCLMenuItemInit
    key);
  NSMenuItem(Result).setKeyEquivalentModifierMask(mask);
  NSMenuItem(Result).setTarget(Result);
end;

function LCLMenuItemInit(item: NSMenuItem; const atitle: string; VKKey: Word; State: TShiftState): id;
var
  key   : NSString;
  mask  : NSUInteger;
begin
  Result := LCLMenuItemInit(item, atitle, ShortCut(VKKey, State));
end;

function AllocCocoaMenu(const atitle: string = ''): TCocoaMenu;
begin
  Result := TCocoaMenu.alloc.initWithTitle(ControlTitleToNSStr(atitle));
  Result.setAutoenablesItems(false);
end;

{ TCocoaMenuItem_ShowAllApp }

procedure TCocoaMenuItem_ShowAllApp.lclItemSelected(sender: id);
begin
  NSApplication(NSApp).unhideAllApplications(sender);
end;

{ TLCLMenuItemCallback }

constructor TLCLMenuItemCallback.Create(AOwner: NSObject; AMenuItemTarget: TMenuItem);
begin
  Owner := AOwner;
  FMenuItemTarget := AMenuItemTarget;
end;

procedure TLCLMenuItemCallback.ItemSelected;
var
  Msg:TLMessage;
begin
  FillChar(Msg{%H-}, SizeOf(Msg), 0);
  Msg.msg := LM_ACTIVATE;
  // debugln('send LM_Activate');
  LCLMessageGlue.DeliverMessage(FMenuItemTarget,Msg);
end;

function TLCLMenuItemCallback.MenuItemTarget: TMenuItem;
begin
  Result:=FMenuItemTarget;
end;

{ TCocoaMenu }

procedure TCocoaMenu.lclItemSelected(sender:id);
begin

end;

// For when there is no menu item with title 
procedure TCocoaMenu.createAppleMenu();
var
  nskey, nstitle, nssubmeykey: NSString;
  lNSSubmenu: NSMenu;
begin
  // create the menu item
  nstitle := NSStringUtf8('');
  appleMenu := TCocoaMenuItem.alloc.initWithTitle_action_keyEquivalent(nstitle,
    objcselector('lclItemSelected:'), NSString.string_);
  nstitle.release;

  // add the submenu
  lNSSubmenu := NSMenu.alloc.initWithTitle(NSString.string_);
  appleMenu.setSubmenu(lNSSubmenu);

  appleMenu.attachAppleMenuItems();
end;

// For when there is a menu item with title 
procedure TCocoaMenu.overrideAppleMenu(AItem: TCocoaMenuItem);
begin
  if appleMenu <> nil then
  begin
    if indexOfItem(appleMenu) >= 0 then
      removeItem(appleMenu);
    appleMenu.release;
    appleMenu := nil;
  end;
  attachedAppleMenu := False;
  AItem.attachAppleMenuItems();
end;

procedure TCocoaMenu.attachAppleMenu();
begin
  if attachedAppleMenu then Exit;
  if appleMenu = nil then Exit;
  attachedAppleMenu := True;
  insertItem_atIndex(appleMenu, 0);
end;

function TCocoaMenu.performKeyEquivalent(theEvent: NSEvent): LCLObjCBoolean;
var
  OldKeyEq: boolean;
begin
  OldKeyEq:=isKeyEq;
  isKeyEq := true;
  try
    Result := inherited performKeyEquivalent(theEvent);
  finally
    isKeyEq := OldKeyEq;
  end;
end;

function TCocoaMenu.lclIsKeyEquivalent: LCLObjCBoolean;
begin
  Result := isKeyEq;
end;

{ TCocoaMenuITem }

procedure TCocoaMenuItem.UncheckSiblings(AIsChangingToChecked: LCLObjCBoolean);
var
  i: Integer;
  lMenuItem, lSibling, lParentMenu: TMenuItem;
  lSiblingHandle: NSMenuItem;
begin
  //lMenuItem := GetMenuItemHandle();
  lMenuItem := FMenuItemTarget;
  if lMenuItem = nil then Exit;
  if not lMenuItem.RadioItem then Exit;
  if (not AIsChangingToChecked) and (not lMenuItem.Checked) then Exit;
  lParentMenu := lMenuItem.Parent;
  if lParentMenu = nil then Exit;
  for i := 0 to lParentMenu.Count - 1 do
  begin
    lSibling := lParentMenu.Items[i];
    if lSibling = nil then Continue;
    if lSibling = lMenuItem then Continue;

    if lSibling.RadioItem and (lSibling.GroupIndex = lMenuItem.GroupIndex) and
      lSibling.HandleAllocated() then
    begin
      lSiblingHandle := NSMenuItem(lSibling.Handle);
      TCocoaWSMenuItem.Do_SetCheck(lSiblingHandle, False);
    end;
  end;
end;

function TCocoaMenuItem.GetMenuItemHandle(): TMenuItem;
begin
  Result := nil;
  if menuItemCallback = nil then Exit;
  Result := menuItemCallback.MenuItemTarget;
end;

procedure TCocoaMenuItem.lclItemSelected(sender:id);
begin
  menuItemCallback.ItemSelected;
  UncheckSiblings();
end;

function TCocoaMenuItem.lclGetCallback: IMenuItemCallback;
begin
  result:=menuItemCallback;
end;

procedure TCocoaMenuItem.lclClearCallback;
begin
  menuItemCallback := nil;
end;

procedure TCocoaMenuItem.attachAppleMenuItems();
var
  item    : NSMenuItem;
begin
  if attachedAppleMenuItems then Exit;
  if not hasSubmenu() then Exit;

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Services
  item := LCLMenuItemInit( TCocoaMenuItem.alloc, rsMacOSMenuServices);
  item.setTarget(nil);
  item.setAction(nil);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);
  item.setSubmenu(NSMenu.alloc.initWithTitle( ControlTitleToNSStr(rsMacOSMenuServices)));
  NSApplication(NSApp).setServicesMenu(item.submenu);

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Hide App     Meta-H
  item := LCLMenuItemInit( TCocoaMenuItem_HideApp.alloc, Format(rsMacOSMenuHide, [Application.Title]), VK_H, [ssMeta]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Hide Others  Meta-Alt-H
  item := LCLMenuItemInit( TCocoaMenuItem_HideOthers.alloc, rsMacOSMenuHideOthers, VK_H, [ssMeta, ssAlt]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Show All
  item := LCLMenuItemInit( TCocoaMenuItem_ShowAllApp.alloc, rsMacOSMenuShowAll);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  // Separator
  submenu.insertItem_atIndex(NSMenuItem.separatorItem, submenu.itemArray.count);

  // Quit   Meta-Q
  item := LCLMenuItemInit( TCocoaMenuItem_Quit.alloc, Format(rsMacOSMenuQuit, [Application.Title]), VK_Q, [ssMeta]);
  submenu.insertItem_atIndex(item, submenu.itemArray.count);

  attachedAppleMenuItems := True;
end;

function TCocoaMenuItem.isValidAppleMenu(): LCLObjCBoolean;
begin
  Result := hasSubmenu() and (submenu() <> nil);
  Result := Result and ('' = NSStringToString(title));
end;

procedure TCocoaMenuItem.menuNeedsUpdate(AMenu: NSMenu);
begin
  if not Assigned(menuItemCallback) then Exit;
  if (menu.isKindOfClass(TCocoaMenu)) then
  begin
    // Issue #37789
    // Cocoa tries to find, if there's a menu with the key event
    // so item is not actually selected yet. Thus should not send ItemSelected
    if TCocoaMenu(menu).lclIsKeyEquivalent then
      Exit;
  end;

  //todo: call "measureItem"
  menuItemCallback.ItemSelected;
end;

function TCocoaMenuItem.worksWhenModal: LCLObjCBoolean;
begin
  // refer to NSMenuItem.target (Apple) documentation
  // the method must be implemented in target and return TRUE
  // otherwise it won't work for modal!
  //
  // The method COULD be used to protect the main menu from being clicked
  // if a modal window doesn't have a menu.
  // But LCL disables (is it?) the app menu manually on modal
  Result := true;
end;

{  menuDidClose should not change the structure of the menu.
   The restructuring is causing issues on Apple's special menus (i.e. HELP menu)
   See bug #35625

procedure TCocoaMenuItem.menuDidClose(AMenu: NSMenu);
var
  par : NSMenu;
  idx : NSInteger;
  mn  : NSMenuItem;
begin
  // the only purpose of this code is to "invalidate" the submenu of the item.
  // an invalidated menu will call menuNeedsUpdate.
  // There's no other way in Cocoa to do the "invalidate"
  par := amenu.supermenu;
  if Assigned(par) then
  begin
    idx := par.indexOfItemWithSubmenu(AMenu);
    if idx<>NSNotFound then
    begin
      mn := par.itemAtIndex(idx);
      mn.setSubmenu(nil);
      mn.setSubmenu(AMenu);
    end;
  end;
end;
}

procedure TCocoaMenuItem_HideApp.lclItemSelected(sender: id);
begin
  // Applicaiton.Minimize, calls WidgetSet.AppMinimize;
  // which calls NSApplication.hide() anyway
  Application.Minimize;
end;

procedure TCocoaMenuItem_HideOthers.lclItemSelected(sender: id);
begin
  NSApplication(NSApp).hideOtherApplications(sender);
end;

procedure TCocoaMenuItem_Quit.lclItemSelected(sender: id);
begin
  {$ifdef COCOALOOPHIJACK}
  // see bug #36265. if hot-key (Cmd+Q) is used the menu item
  // would be called once. 1) in LCL controlled loop 2) after the loop finished
  // The following if statement prevents "double" form close
  if LoopHiJackEnded then Exit;
  {$endif}
  // Should be used instead of Application.Terminate to allow events to be sent, see bug 32148
  Application.MainForm.Close;
end;

{ TCocoaWSMenu }

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenu.CreateHandle
  Params:  AMenu - LCL menu
  Returns: Handle to the menu in Cocoa interface

  Creates new menu in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenu.CreateHandle(const AMenu: TMenu): HMENU;
begin
  //WriteLn(':>[TCocoaWSMenu.CreateHandle]');
  Result := HMENU(AllocCocoaMenu);
end;

{ TCocoaWSMainMenu }

class function TCocoaWSMainMenu.CreateHandle(const AMenu: TMenu): HMENU;
begin
  Result := HMENU(AllocCocoaMenu);
  TCocoaMenu(Result).createAppleMenu();
end;

{ TCocoaWSMenuItem }

class procedure TCocoaWSMenuItem.Do_SetCheck(const ANSMenuItem: NSMenuItem; const Checked: boolean);
const
  menustate : array [Boolean] of NSInteger = (NSOffState, NSOnState);
begin
  ANSMenuItem.setState( menustate[Checked] );
end;

// used from the MenuMadness example
class function TCocoaWSMenuItem.NSMenuCheckmark: NSImage;
begin
  Result:=NSImage.imageNamed(NSStringUtf8('NSMenuCheckmark'));
end;

class function TCocoaWSMenuItem.NSMenuRadio: NSImage;
begin
  Result:=NSImage.imageNamed(NSStringUtf8('NSMenuRadio'))
end;

class function TCocoaWSMenuItem.isSeparator(const ACaption: AnsiString): Boolean;
begin
  Result:=ACaption='-';
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.AttachMenu
  Params:  AMenuItem - LCL menu item

  Attaches menu item to its parent menu in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.AttachMenu(const AMenuItem: TMenuItem);
var
  ParObj  : NSObject;
  Parent  : TCocoaMenu;
  item    : NSMenuItem;
  MenuObj : NSObject;
  Menu    : NSMenu;
  idx     : Integer;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) or not Assigned(AMenuItem.Parent) or (AMenuItem.Parent.Handle=0) then Exit;
  ParObj:=NSObject(AMenuItem.Parent.Handle);
  item:=NSMenuItem(AMenuItem.Handle);

  if ParObj.isKindOfClass(NSMenuItem) then
  begin
    if not NSMenuItem(ParObj).hasSubmenu then
    begin
      Parent := AllocCocoaMenu(AMenuItem.Parent.Caption);
      Parent.setDelegate(TCocoaMenuItem(ParObj));
      NSMenuItem(ParObj).setSubmenu(Parent);

      // no longer respond to clicks. LCL might still need to get an event
      // yet the menu should not close
      NSMenuItem(ParObj).setAction(nil);
    end
    else
      Parent:=TCocoaMenu(NSMenuItem(ParObj).submenu);
  end else if ParObj.isKindOfClass(NSMenu) then
    Parent:=TCocoaMenu(ParObj)
  else
    Exit;

  item := nil;
  MenuObj := NSObject(AMenuItem.Handle);
  if MenuObj.isKindOfClass(NSMenuItem) then
    item := NSMenuItem(MenuObj)
  else if MenuObj.isKindOfClass(NSMenu) then
  begin
    Menu := NSMenu(MenuObj);
    item := NSMenuItem(NSMenuItem.alloc).initWithTitle_action_keyEquivalent(
      ControlTitleToNSStr(AMenuItem.Caption), nil, NSString.string_ );
    item.setSubmenu( Menu );
  end;

  if Assigned(item) then
  begin
    idx := AMenuItem.MenuVisibleIndex;
    if idx < 0 then idx := Parent.numberOfItems;
    Parent.insertItem_atIndex(NSMenuItem(item), idx)
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.CreateHandle
  Params:  AMenuItem - LCL menu item
  Returns: Handle to the menu item in Cocoa interface

  Creates new menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.CreateHandle(const AMenuItem: TMenuItem): HMENU;
var
  item    : NSMenuItem;
  ANSMenu : NSMenu;
begin
  if not Assigned(AMenuItem) then
  begin
    Result:=0;
    Exit;
  end;

  // A handle of TMenu.fItems (TMenuItem) could be recreated.
  // in this case LCL calls TCocoaWSMenuItem.CreateHandle
  // instead of the proper owner.
  if (AMenuItem.Owner is TMainMenu) and (TMainMenu(AMenuItem.Owner).Items = AMenuItem) then begin
    Result:=TCocoaWSMainMenu.CreateHandle(TMenu(AMenuItem.Owner));
    Exit;
  end else if (AMenuItem.Owner is TMenu) and (TMenu(AMenuItem.Owner).Items = AMenuItem) then begin
    Result:=TCocoaWSMenu.CreateHandle(TMenu(AMenuItem.Owner));
    Exit;
  end;

  if AMenuItem.Caption = '-' then
  begin
    item := NSMenuItem.separatorItem;
  end
  else
  begin
    item := LCLMenuItemInit(TCocoaMenuItem.alloc, AMenuItem.Caption, AMenuItem.ShortCut);
    TCocoaMenuItem(item).FMenuItemTarget := AMenuItem;

    if AMenuItem.IsInMenuBar then
    begin
      ANSMenu := AllocCocoaMenu(AMenuItem.Caption);
      ANSMenu.setDelegate(TCocoaMenuItem(item));
      item.setSubmenu(ANSMenu);
    end;

    TCocoaMenuItem(item).menuItemCallback:=TLCLMenuItemCallback.Create(item, AMenuItem);

    // initial set of properties
    {$ifdef BOOLFIX}
    item.setEnabled_(Ord(AMenuItem.Enabled));
    {$else}
    item.setEnabled(AMenuItem.Enabled);
    {$endif}

    if AMenuItem.RadioItem then
      item.setOnStateImage( NSMenuRadio )
    else
      item.setOnStateImage(NSMenuCheckmark);

    Do_SetCheck(item, AMenuItem.Checked);

    if AMenuItem.HasIcon and ((AMenuItem.ImageIndex>=0) or (AMenuItem.HasBitmap)) then
      NSMenuItemSetBitmap(item, AMenuItem.Bitmap);
  end;

  Result:=HMENU(item);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.DestroyHandle
  Params:  AMenuItem - LCL menu item

  Destroys menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.DestroyHandle(const AMenuItem: TMenuItem);
var
  callback: IMenuItemCallback;
  callbackObject: TObject;
  item     : NSObject;
  menuitem : TCocoaMenuItem;
  nsitem   : NSMenuItem;
begin
  item:=NSObject(AMenuItem.Handle);
  if item.isKindOfClass_(TCocoaMenuItem) then
  begin
    menuitem := TCocoaMenuItem(item);
    callback := menuitem.lclGetCallback;
    if Assigned(callback) then
    begin
      callbackObject := callback.GetCallbackObject;
      callback := nil;
      menuitem.lclClearCallback;
      callbackObject.Free;
    end;
    if Assigned(menuitem.menu) then
      menuitem.menu.removeItem(menuitem);
    AMenuItem.Handle := 0;
    menuitem.release; // TCocoaMenuItems are "alloced" - thus should be released;
  end else if item.isKindOfClass_(NSMenuItem) then begin
    nsitem := NSMenuItem(item);
    if nsitem.isSeparatorItem and Assigned(nsitem.menu) then
      nsitem.menu.removeItem(nsitem);
    // separator items are not "alloced", thus should not be released
  end;

end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetCaption
  Params:  AMenuItem - LCL menu item
           ACaption  - Menu item caption

  Sets the caption of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetCaption(const AMenuItem: TMenuItem; const ACaption: string);
var
  ns : NSString;
  s: string;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;
  if NSMenuItem(AMenuItem.Handle).isSeparatorItem <> (ACaption='-') then
    AMenuItem.RecreateHandle
  else
  begin
    s := ACaption;
    DeleteAmpersands(s);
    ns:=NSStringUtf8(s);
    NSMenuItem(AMenuItem.Handle).setTitle(ns);
    if NSMenuItem(AMenuItem.Handle).hasSubmenu then
      NSMenuItem(AMenuItem.Handle).submenu.setTitle(ns);
    ns.release;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetShortCut
  Params:  AMenuItem   - LCL menu item
           ShortCutK1 and ShortCutK2 - New shortcut key1 and key2

  Sets the shortcut of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetShortCut(const AMenuItem: TMenuItem;
  const ShortCutK1, ShortCutK2: TShortCut);
var
  ShiftState: NSUInteger;
  ns: NSString;
begin
  ShortcutToKeyEquivalent(ShortCutK1, ns, ShiftState);
  TCocoaMenuItem(AMenuItem.Handle).setKeyEquivalentModifierMask(ShiftState);
  TCocoaMenuItem(AMenuItem.Handle).setKeyEquivalent(ns);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetVisible
  Params:  AMenuItem - LCL menu item
           Visible   - Menu item visibility

  Sets the visibility of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSMenuItem.SetVisible(const AMenuItem: TMenuItem;
  const Visible: boolean);
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;
  {$ifdef BOOLFIX}
  NSMenuItem(AMenuItem.Handle).setHidden_( Ord(not Visible) );
  {$else}
  NSMenuItem(AMenuItem.Handle).setHidden( not Visible );
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetCheck
  Params:  AMenuItem - LCL menu item
           Checked   - Menu item checked
  Returns: If the function succeeds

  Sets the check of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetCheck(const AMenuItem: TMenuItem;
  const Checked: boolean): boolean;
var
  lHandle: NSMenuItem;
  lCocoaHandle: TCocoaMenuItem absolute lHandle;
begin
  Result := Assigned(AMenuItem) and AMenuItem.HandleAllocated() and (AMenuItem.Handle<>0);
  if not Result then Exit;
  lHandle := NSMenuItem(AMenuItem.Handle);
  Result := Result and lHandle.isKindOfClass_(TCocoaMenuItem);
  if not Result then Exit;
  TCocoaWSMenuItem.Do_SetCheck(lHandle, Checked);
  lCocoaHandle.UncheckSiblings(True);
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetEnable
  Params:  AMenuItem - LCL menu item
           Enabled   - Menu item enabled
  Returns: If the function succeeds

  Sets the enabled of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetEnable(const AMenuItem: TMenuItem;
  const Enabled: boolean): boolean;
begin
  Result:=Assigned(AMenuItem) and (AMenuItem.Handle<>0);
  if not Result then Exit;
  {$ifdef BOOLFIX}
  NSMenuItem(AMenuItem.Handle).setEnabled_( Ord(Enabled) );
  {$else}
  NSMenuItem(AMenuItem.Handle).setEnabled( Enabled );
  {$endif}
end;

{------------------------------------------------------------------------------
  Method:  TCocoaWSMenuItem.SetRadioItem
  Params:  AMenuItem - LCL menu item
           RadioItem - Menu item has radio
  Returns: If the function succeeds

  Sets the radio behaviour of menu item in Cocoa interface
 ------------------------------------------------------------------------------}
class function TCocoaWSMenuItem.SetRadioItem(const AMenuItem: TMenuItem;
  const RadioItem: boolean): boolean;
const
  menustate : array [Boolean] of NSInteger = (NSOffState, NSOnState);
begin
  Result:=Assigned(AMenuItem) and (AMenuItem.Handle<>0);
  if not Result then Exit;
  //todo: disable relative radio items
  if RadioItem then
    NSMenuItem(AMenuItem.Handle).setOnStateImage( NSMenuRadio )
  else
    NSMenuItem(AMenuItem.Handle).setOnStateImage(NSMenuCheckmark);

  NSMenuItem(AMenuItem.Handle).setState( menustate[RadioItem] );
end;

procedure NSMenuItemSetBitmap(mn: NSMenuItem; bmp: TBitmap);
begin
  if not Assigned(mn) then Exit;
  if not Assigned(bmp) or (bmp.Handle = 0) then
    mn.setImage(nil)
  else
    mn.setImage(TCocoaBitmap(bmp.Handle).Image);
end;

class procedure TCocoaWSMenuItem.UpdateMenuIcon(const AMenuItem: TMenuItem;
  const HasIcon: Boolean; const AIcon: TBitmap);
var
  mn : NSMenuItem;
begin
  if not Assigned(AMenuItem) or (AMenuItem.Handle=0) then Exit;

  if NSObject(AMenuItem.Handle).isKindOfClass(NSMenuItem) then
    NSMenuItemSetBitmap( NSMenuItem(AMenuItem.Handle), AIcon);
end;

{ TCocoaWSPopupMenu }

{------------------------------------------------------------------------------
  Method:  TCocoaWSPopupMenu.Popup
  Params:  APopupMenu - LCL popup menu
           X, Y       - Screen coordinates to popup

  Popups menu in Cocoa interface
 ------------------------------------------------------------------------------}
class procedure TCocoaWSPopupMenu.Popup(const APopupMenu: TPopupMenu; const X,
  Y: Integer);
var
  res : Boolean;
  mnu : NSMenuItem;
  view : NSView;
  w : NSWindow;
  px, py: Integer;
  wi: NSUInteger;
begin
  if Assigned(APopupMenu) and (APopupMenu.Handle<>0) then
  begin
    // old method which doesn't consider position but supports 10.0+ (useless since we target 10.6+)
    {w:=NSApp.keyWindow;
    if Assigned(w) then
    begin
      NSMenu.popUpContextMenu_withEvent_forView( TCocoaMenu(APopupMenu.Handle),
        NSApp.currentEvent, NSView(w.contentView));
    end;}

    // New method for 10.6+
    px := x;
    py := y;
    view := nil;
    w :=NSApp.keyWindow;
    if not Assigned(w) and (NSApp.windows.count>0) then
    begin
      // in macOS it's possible to "rightclick" without focusing a window
      // so let's try to find the window
      for wi := 0 to NSApp.windows.count-1 do
      begin
        w := NSWindow(NSApp.windows.objectAtIndex(wi));
        if not w.isVisible then Continue;
        view := w.contentView;
        view.lclScreenToLocal(px, py);
        if (px >= 0) and (py >= 0)
          and (px<=Round(view.frame.size.width))
          and (py<=Round(view.frame.size.height))
        then
        begin
          px := X;
          py := Y;
          Break;
        end;
        w := nil;
        px := X;
        py := Y;
      end;
    end;

    if Assigned(w) then
    begin
      view := w.contentView;
      if Assigned(view) then
      begin
        view.lclScreenToLocal(px, py);
        // have to flip again, because popUpMenuPositioningItem expects point
        // to be in View coordinates and it does respect Flipped flag
        if not view.isFlipped then
          py := Round(view.frame.size.height - py);
      end;
    end;
    res := TCocoaMenu(APopupMenu.Handle).popUpMenuPositioningItem_atLocation_inView(
      nil, NSMakePoint(px, py), view);
    APopupMenu.Close; // notify LCL popup menu
  end;
end;

procedure ShortcutToKeyEquivalent(const AShortCut: TShortcut; out Key: NSString; out shiftKeyMask: NSUInteger);
var
  w: word;
  s: TShiftState;
begin
  ShortCutToKey(AShortCut, w, s);
  key := VirtualKeyCodeToMacString(w);
  shiftKeyMask := 0;
  if ssShift in s then
    ShiftKeyMask := ShiftKeyMask + NSShiftKeyMask;
  if ssAlt in s then
    ShiftKeyMask := ShiftKeyMask + NSAlternateKeyMask;
  if ssCtrl in s then
    ShiftKeyMask := ShiftKeyMask + NSControlKeyMask;
  if ssMeta in s then
    ShiftKeyMask := ShiftKeyMask + NSCommandKeyMask;
end;

procedure ToggleAppNSMenu(mn: NSMenu; ALogicalEnabled: Boolean);
var
  it  : NSMenuItem;
  obj : NSObject;
  enb : Boolean;
begin
  if not Assigned(mn) then Exit;
  for obj in mn.itemArray do begin
    if not obj.isKindOfClass(NSMenuItem) then continue;
    it := NSMenuItem(obj);
    enb := ALogicalEnabled;
    if enb and (it.isKindOfClass(TCocoaMenuItem)) then
    begin
      enb := not Assigned(TCocoaMenuItem(it).FMenuItemTarget)
         or ( TCocoaMenuItem(it).FMenuItemTarget.Enabled );
    end;
    {$ifdef BOOLFIX}
    it.setEnabled_( Ord(enb));
    {$else}
    it.setEnabled(enb);
    {$endif}
    if (it.hasSubmenu) then
    begin
      ToggleAppNSMenu(it.submenu, ALogicalEnabled);
    end;
  end;
end;

var
  isMenuEnabled : Boolean = true;

function ToggleAppMenu(ALogicalEnabled: Boolean): Boolean;
begin
  Result := isMenuEnabled;
  ToggleAppNSMenu( NSApplication(NSApp).mainMenu, ALogicalEnabled );
  isMenuEnabled := ALogicalEnabled;
end;

end.

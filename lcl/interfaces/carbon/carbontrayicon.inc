{%mainunit carbonwsextctrls.pp}

{$ifdef CarbonUseCocoa}

type

  { TPrivateCocoaCarbonTrayIcon }

  TPrivateCocoaCarbonTrayIcon = class(NSObject)
  public
    { Fields }
    LCLTrayIcon: TCustomTrayIcon;
    bar: NSStatusBar;
    item: NSStatusItem;
    image: NSImage;
    menu: NSMenu;
    EmptyMenuTitle: CFStringRef;
    // The following lists store the items and are used
    // to be able to release them in ReleaseMenu
    //
    // SubMenuOwners: Holds all internal owners of the submenus
    // SubMenuItems: Holds all items in submenus
    SubMenuOwners: array of NSMenu;
    SubMenuItems: array of NSMenuItem;
    SubMenuImages: array of NSImage;
    { Structural Methods }
    constructor Create; override;
    destructor Destroy; override;
    class function getClass: lobjc.id; override;
    procedure AddMethods; override;
    { Pascal Methods }
    function TrimAllChar(const S: string; const ch: Char): string;
    function CreateMenu(APopUpMenu: TPopUpMenu): NSMenu;
    function RecursiveCreateMenuItems(AMenuItem: TMenuItem;
      {%H-}ACallbackName: string; {%H-}ACallbackClass: NSObject): NSMenuItem;
    function CreateMenuItem(AMenuItem: TMenuItem;
      ACallbackName: string; ACallbackClass: NSObject): NSMenuItem;
    procedure ReleaseMenu();
    procedure RemoveIcon();
    function ConvertTIconToNSImage(AIcon: TIcon): NSImage;
    function ConvertTBitmapToNSImage(ABitmap: TBitmap): NSImage;
    function IsMenuVisible: Boolean;
    { Objective-C compatible methods }
    class procedure HandleMenuItemClick({%H-}_self: lobjc.id; _cmd: SEL; {%H-}sender: lobjc.id); cdecl; //static;
    class procedure HandleMenuWillOpen({%H-}_self: lobjc.id; {%H-}_cmd: SEL; sender: lobjc.id); cdecl; //static;
    class procedure HandleMenuDidClose({%H-}_self: lobjc.id; {%H-}_cmd: SEL; sender: lobjc.id); cdecl; //static;
  end;

const
  {%H-}Str_TPrivateCocoaCarbonTrayIcon = 'TTrayIcon';

  Str_HandleMenuItemClick = 'HandleMenuItemClick';
  Str_HandleMenuWillOpen = 'menuWillOpen:';
  Str_HandleMenuDidClose = 'menuDidClose:';

{ TPrivateCocoaCarbonTrayIcon }

{@@
  Adds methods to the class

  Details of the parameters string:

  The first parameter is the result (v = void),
  followed by self and _cmd (@ = id and : = SEL),
  and on the end "sender" (@ = id)
}
procedure TPrivateCocoaCarbonTrayIcon.AddMethods;
begin
  AddMethod(Str_HandleMenuItemClick, 'v@:@', Pointer(HandleMenuItemClick));
  AddMethod(Str_HandleMenuWillOpen, 'v@:@', Pointer(HandleMenuWillOpen));
  AddMethod(Str_HandleMenuDidClose, 'v@:@', Pointer(HandleMenuDidClose));
end;

constructor TPrivateCocoaCarbonTrayIcon.Create;
begin
  { The class is registered on the Objective-C runtime before the NSObject constructor is called }
  // The original plan was to create a descendent class, but causes wierd crashes
  // so now we just stuck our method into NSObject
//  if not CreateClassDefinition(Str_TPrivateCocoaCarbonTrayIcon, Str_NSObject) then WriteLn('Failed to create lobjc class');

  EmptyMenuTitle := CFStringCreateWithPascalString(nil, '', kCFStringEncodingUTF8);

  inherited Create;
end;

destructor TPrivateCocoaCarbonTrayIcon.Destroy;
begin
  CFRelease(EmptyMenuTitle);

  RemoveIcon();
  ReleaseMenu();

  if item <> nil then
  begin
    item.setImage(nil);
    item.Free;
    item := nil;
  end;

  if image <> nil then
  begin
    image.Free;
    image := nil;
  end;

  inherited Destroy;
end;

class function TPrivateCocoaCarbonTrayIcon.getClass: lobjc.id;
begin
  Result := objc_getClass({Str_TPrivateCocoaCarbonTrayIcon} Str_NSObject);
end;

{Removes/replaces all occurrences of a character from a string}
function TPrivateCocoaCarbonTrayIcon.TrimAllChar(const S: string; const ch: Char): string;
var
  buf: string;
begin
  buf := S;
  Result := '';
  {while Pos finds a blank}
  while (Pos(ch, buf) > 0) do
    begin
      {copy the substrings before the blank in to Result}
      Result := Result + Copy(buf, 1, Pos(ch, buf) - 1);
      buf := Copy(buf, Pos(ch, buf) + 1, Length(buf) - Pos(ch, buf));
    end;
  {There will still be a remainder in buf, so copy remainder into Result}
  Result := Result + buf;
end;

{ Creates a NSMenu structure representing a TPopUpMenu }
function TPrivateCocoaCarbonTrayIcon.CreateMenu(APopUpMenu: TPopUpMenu): NSMenu;
var
  i: Integer;
  Item: NSMenuItem;
begin
  Result := NSMenu.initWithTitle(EmptyMenuTitle);
//  Result.setVersion(0);
  Result.setDelegate(Self.Handle);
  Result.setAutoenablesItems(LongBool(NO)); // For menu enabling/disabling

  for i := 0 to APopUpMenu.Items.Count - 1 do
  begin
    { If the submenu has a submenu it needs special treatment }
    if APopUpMenu.Items[i].Count > 0 then
      Item := RecursiveCreateMenuItems(APopUpMenu.Items[i], Str_HandleMenuItemClick, Self)
    else
      Item := CreateMenuItem(APopUpMenu.Items[i], Str_HandleMenuItemClick, Self);

    if item <> nil then
      Result.addItem(Item.Handle);
  end;
end;

function TPrivateCocoaCarbonTrayIcon.RecursiveCreateMenuItems(
  AMenuItem: TMenuItem; ACallbackName: string; ACallbackClass: NSObject): NSMenuItem;
var
  j, subindex: Integer;
  InternalOwner: NSMenu;
  SubItem: NSMenuItem;
begin
  // First create the menu
  Result := CreateMenuItem(AMenuItem, Str_HandleMenuItemClick, Self);

  // Then a owner for the children
  InternalOwner := NSMenu.initWithTitle(EmptyMenuTitle);
  InternalOwner.setAutoenablesItems(LongBool(NO)); // For menu enabling/disabling

  subindex := Length(SubMenuOwners);
  SetLength(SubMenuOwners, subindex + 1);
  SubMenuOwners[subindex] := InternalOwner;

  { Add all submenus in this submenu }
  for j := 0 to AMenuItem.Count - 1 do
  begin
    if AMenuItem.Items[j].Count > 0 then
      SubItem := RecursiveCreateMenuItems(AMenuItem.Items[j], Str_HandleMenuItemClick, Self)
    else
      SubItem := CreateMenuItem(AMenuItem.Items[j], Str_HandleMenuItemClick, Self);

    if SubItem <> nil then
      InternalOwner.addItem(SubItem.Handle);
  end;

  // And set the submenu to the item
  Result.setSubmenu(InternalOwner.Handle);
end;

function TPrivateCocoaCarbonTrayIcon.CreateMenuItem(AMenuItem: TMenuItem;
  ACallbackName: string; ACallbackClass: NSObject): NSMenuItem;
var
  ItemText: CFStringRef;
  KeyText: CFStringRef;
  subitemindex: Integer;
  subimageindex: Integer;
  AImage: NSImage;
  StrBuffer: string;
  // Default property implementation (=bold)
  FontManager: NSFontManager;
  AttrString: NSAttributedString;
  AttrStringFont: NSFont;
  AttrDictionary: NSDictionary;
begin
  Result := nil;

  { Check visibility, invisible menus are implemented by not adding them at all,
    because NSMenuItem.setHidden was only added in Mac OS X 10.5 }
  if not AMenuItem.Visible then Exit;

  { The MenuItem is a separator }
  if AMenuItem.Caption = '-' then
  begin
    Result := NSMenuItem.separatorItem();
  end
  { A normal menu item }
  else
  begin
    { While creating the menus we ignore the & shortcut identifiers }
    StrBuffer := TrimAllChar(AMenuItem.Caption, '&');
    KeyText := CFStringCreateWithPascalString(nil, '', kCFStringEncodingUTF8);
    ItemText := CFStringCreateWithPascalString(nil, StrBuffer, kCFStringEncodingUTF8);
    {$ifdef VerboseCarbonTrayIcon}
    WriteLn(' ItemText: ', IntToHex(Int64(ItemText), 8), ' ATitle: ', AMenuItem.Caption);
    {$endif}

    Result := NSMenuItem.initWithTitle_action_keyEquivalent(ItemText, nil, KeyText);
    
    { Assign the OnClick event handler }
    Result.setTarget(ACallbackClass.Handle);
    Result.setAction(sel_registerName(PChar(ACallbackName)));

    { Assign the checked state }
    if AMenuItem.Checked then Result.setState(NSOnState)
    else Result.setState(NSOffState);

    { Assign default (=bold) state }
    if AMenuItem.Default then
    begin
      FontManager := NSFontManager.sharedFontManager;
      // For now hard-code the menu font to 14, because the default size
      // is 13, which is wrong, and looks bad.
      AttrStringFont := NSFont.menuFontOfSize(14); // 0 = default size
      AttrStringFont.Handle := FontManager.convertFont_toHaveTrait_(AttrStringFont.Handle, NSBoldFontMask);
      AttrDictionary := NSDictionary.dictionaryWithObject_forKey(AttrStringFont.Handle, lobjc.id(NSFontAttributeName));
      AttrString := NSAttributedString.initWithString_attributes(ItemText, CFDictionaryRef(AttrDictionary.Handle));
      if AttrString.Handle <> nil then
        Result.setAttributedTitle(AttrString.Handle);

      // Only objects acquired with routines with alloc,
      // init or copy in the name should be manually released
      AttrString.Free;
      AttrDictionary.Handle := nil;
      AttrDictionary.Free;
      AttrStringFont.Handle := nil;
      AttrStringFont.Free;
      FontManager.Handle := nil;
      FontManager.Free;
    end;

    { Assign enabled/disabled state }
    if AMenuItem.Enabled then Result.setEnabled(LongBool(YES))
    else Result.setEnabled(LongBool(NO));

    { Assign the item image, if any }
    if (AMenuItem.Bitmap <> nil) and (not AMenuItem.Bitmap.Empty) then
    begin
      AImage := ConvertTBitmapToNSImage(AMenuItem.Bitmap);
      Result.setImage(AImage.Handle);

      // We also need to free the images
      subimageindex := Length(SubMenuImages);
      SetLength(SubMenuImages, subimageindex + 1);
      SubMenuImages[subimageindex] := AImage;
    end;

    { We use the Tag to hold the LCL MenuItem
      RepresentedObject was also tried, by it crashed.
      Cocoa probably tryes to use it as a real Cocoa object }
    Result.setTag(PtrInt(AMenuItem));

    { Never add separators to the list of items to be freed }
    subitemindex := Length(SubMenuItems);
    SetLength(SubMenuItems, subitemindex + 1);
    SubMenuItems[subitemindex] := Result;
  end;
end;

procedure TPrivateCocoaCarbonTrayIcon.ReleaseMenu();
var
  i: Integer;
begin
  for i := 0 to Length(SubMenuOwners) - 1 do
    if SubMenuOwners[i] <> nil then SubMenuOwners[i].Free;
  for i := 0 to Length(SubMenuItems) - 1 do
    if (SubMenuItems[i] <> nil) then SubMenuItems[i].Free;
  for i := 0 to Length(SubMenuImages) - 1 do
    if (SubMenuImages[i] <> nil) then SubMenuImages[i].Free;

  SetLength(SubMenuOwners, 0);
  SetLength(SubMenuItems, 0);
  SetLength(SubMenuImages, 0);

  if item <> nil then
    item.setMenu(nil);

  if menu <> nil then
  begin
    menu.Free;
    menu := nil;
  end;
end;

procedure TPrivateCocoaCarbonTrayIcon.RemoveIcon();
begin
  if item <> nil then
    bar.removeStatusItem(item.Handle);
end;

function TPrivateCocoaCarbonTrayIcon.ConvertTIconToNSImage(AIcon: TIcon): NSImage;
var
  ASize: NSSize;
  ACGRect: CGRect;
  AcurrentContext: NSGraphicsContext;
begin
  Result := nil;

  if (AIcon = nil) or (AIcon.Empty) then Exit;

  { Convert our CFImageRef to a NSImage }

  ASize.width := TCarbonBitmap(AIcon.Handle).Width;
  ASize.height := TCarbonBitmap(AIcon.Handle).Height;
  ACGRect.size.width := ASize.width;
  ACGRect.size.height := ASize.height;
  ACGRect.origin.x := 0;
  ACGRect.origin.y := 0;

  Result := NSImage.initWithSize(ASize);
  Result.setCacheMode(NSImageCacheNever);
  Result.lockFocus;
  AcurrentContext := NSGraphicsContext.currentContext();
  CGContextDrawImage(AcurrentContext.graphicsPort, ACGRect, TCarbonBitmap(AIcon.Handle).CGImage);
  {$ifdef VerboseCarbonTrayIcon}
    WriteLn('::[TCarbonWSCustomTrayIcon.Show]',
     ' AcurrentContext ', IntToHex(PtrUInt(Pointer(AcurrentContext)), 8),
     ' AcurrentContext.ClassID ', IntToHex(Int64(AcurrentContext.ClassID), 8),
     ' AcurrentContext.Handle ', IntToHex(Int64(AcurrentContext.Handle), 8),
     ' AcurrentContext.graphicsPort ', IntToHex(Int64(AcurrentContext.graphicsPort), 8)
     );
  {$endif VerboseCarbonTrayIcon}
  Result.unlockFocus;
end;

function TPrivateCocoaCarbonTrayIcon.ConvertTBitmapToNSImage(ABitmap: TBitmap): NSImage;
var
  ASize: NSSize;
  ACGRect: CGRect;
  AcurrentContext: NSGraphicsContext;
begin
  Result := nil;

  if (ABitmap = nil) or (ABitmap.Empty) then Exit;

  { Convert our CFImageRef to a NSImage }

  ASize.width := TCarbonBitmap(ABitmap.Handle).Width;
  ASize.height := TCarbonBitmap(ABitmap.Handle).Height;
  ACGRect.size.width := ASize.width;
  ACGRect.size.height := ASize.height;
  ACGRect.origin.x := 0;
  ACGRect.origin.y := 0;

  Result := NSImage.initWithSize(ASize);
  Result.setCacheMode(NSImageCacheNever);
  Result.lockFocus;
  AcurrentContext := NSGraphicsContext.currentContext();
  CGContextDrawImage(AcurrentContext.graphicsPort, ACGRect, TCarbonBitmap(ABitmap.Handle).CGImage);
  {$ifdef VerboseCarbonTrayIcon}
    WriteLn('::[TCarbonWSCustomTrayIcon.Show]',
     ' AcurrentContext ', IntToHex(PtrUInt(Pointer(AcurrentContext)), 8),
     ' AcurrentContext.ClassID ', IntToHex(Int64(AcurrentContext.ClassID), 8),
     ' AcurrentContext.Handle ', IntToHex(Int64(AcurrentContext.Handle), 8),
     ' AcurrentContext.graphicsPort ', IntToHex(Int64(AcurrentContext.graphicsPort), 8)
     );
  {$endif VerboseCarbonTrayIcon}
  Result.unlockFocus;
end;

// Using private APIs might cause a rejection in the Apple AppStore
// See: http://bugs.freepascal.org/view.php?id=19025
// But on the other hand there is no other way to check if the menu is visible
// http://www.cocoabuilder.com/archive/cocoa/100570-checking-if-menu-is-visible.html
{$ifdef CarbonUsePrivateAPIs}
function _NSGetCarbonMenu(AMenu: lobjc.id {NSMenu}): MenuRef; cdecl; external name '_NSGetCarbonMenu';
{$endif}

function TPrivateCocoaCarbonTrayIcon.IsMenuVisible: Boolean;
{$ifdef CarbonUsePrivateAPIs}
var
  CarbonMenu: MenuRef;
  theMenuTrackingData: MenuTrackingData;
begin
  Result := False;

  if menu = nil then Exit;

  CarbonMenu := _NSGetCarbonMenu(menu.Handle);
  if CarbonMenu = nil then Exit;

  Result :=  GetMenuTrackingData(CarbonMenu, theMenuTrackingData) = noErr;
end;
{$else}
begin
  Result := False;
end;
{$endif}

{ Here we try to get the LCL MenuItem from the Tag and then call
  it's OnClick method }
class procedure TPrivateCocoaCarbonTrayIcon.HandleMenuItemClick(_self: lobjc.id;
  _cmd: SEL; sender: lobjc.id); cdecl; //static;
var
  AMenuItem: NSMenuItem;
  LCLMenu: TMenuItem;
begin
  AMenuItem := NSMenuItem.CreateWithHandle(lobjc.id(_cmd));
  LCLMenu := TMenuItem(PtrInt(AMenuItem.Tag()));
  if (LCLMenu <> nil) then LCLMenu.Click;
end;

class procedure TPrivateCocoaCarbonTrayIcon.HandleMenuWillOpen(_self: lobjc.id;
  _cmd: SEL; sender: lobjc.id); cdecl; //static;
var
  AMenu: NSMenu;
  //LCLMenu: TPopUpMenu;
begin
  AMenu := NSMenu.CreateWithHandle(sender);
  if AMenu=nil then ;
//  LCLMenu := TPopUpMenu(PtrInt(AMenu.menuRepresentation()));
//  if (LCLMenu <> nil) and Assigned(LCLMenu.OnPopUp) then LCLMenu.OnPopUp(LCLMenu);
end;

class procedure TPrivateCocoaCarbonTrayIcon.HandleMenuDidClose(_self: lobjc.id;
  _cmd: SEL; sender: lobjc.id); cdecl; //static;
begin
  NSMenu.CreateWithHandle(sender);
//  LCLMenu := TPopUpMenu(PtrInt(AMenu.menuRepresentation()));
//  if (LCLMenu <> nil) and Assigned(LCLMenu.OnClose) then LCLMenu.OnClose(LCLMenu);
end;

{ TCarbonWSCustomTrayIcon }

class function TCarbonWSCustomTrayIcon.Hide(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  APrivateTrayIcon: TPrivateCocoaCarbonTrayIcon;
begin
  APrivateTrayIcon := TPrivateCocoaCarbonTrayIcon(ATrayIcon.Handle);

  APrivateTrayIcon.Free;

  Result := True;
end;

{
  Documentation for converting a CGImageRef to a NSImage can be found here:
  
  http://www.cocoadev.com/index.pl?CGImageRef
}
class function TCarbonWSCustomTrayIcon.Show(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  APrivateTrayIcon: TPrivateCocoaCarbonTrayIcon;
begin
  {$ifdef VerboseCarbonTrayIcon}
    WriteLn(':>[TCarbonWSCustomTrayIcon.Show]');
  {$endif VerboseCarbonTrayIcon}

  Result := False;

  { Creates the handle }
  
  APrivateTrayIcon := TPrivateCocoaCarbonTrayIcon.Create;
  
  APrivateTrayIcon.bar := NSStatusBar.systemStatusBar();
  APrivateTrayIcon.LCLTrayIcon := ATrayIcon;

  ATrayIcon.Handle := HWND(APrivateTrayIcon);

  { Converts the icon to NSImage }

  APrivateTrayIcon.image := APrivateTrayIcon.ConvertTIconToNSImage(ATrayIcon.Icon);

  { Shows the icon }

  if APrivateTrayIcon.item <> nil then Exit(True);

  APrivateTrayIcon.item := NSStatusItem.CreateWithHandle(APrivateTrayIcon.bar.statusItemWithLength(NSSquareStatusItemLength));
  APrivateTrayIcon.item.retain();
  if Assigned(APrivateTrayIcon.image) and Assigned(APrivateTrayIcon.Image.Handle) then
    APrivateTrayIcon.item.setImage(APrivateTrayIcon.image.Handle);
  APrivateTrayIcon.item.setHighlightMode(LongBool(YES));

  { Inserts the menu }

  if ATrayIcon.PopUpMenu <> nil then
  begin
    APrivateTrayIcon.menu := APrivateTrayIcon.CreateMenu(ATrayIcon.PopUpMenu);
    if APrivateTrayIcon.item <> nil then
      APrivateTrayIcon.item.setMenu(APrivateTrayIcon.menu.Handle);
  end;

  Result := True;
  
  {$ifdef VerboseCarbonTrayIcon}
    WriteLn(':<[TCarbonWSCustomTrayIcon.Show]',
     ' Handle: ', IntToHex(ATrayIcon.Handle, 8),
     ' ACGRect.size.width: ', ACGRect.size.width,
     ' ACGRect.size.height: ', ACGRect.size.height,
     ' ACGRect.origin.x: ', ACGRect.origin.x,
     ' ACGRect.origin.y: ', ACGRect.origin.y,
     ' TCarbonBitmap(ATrayIcon.Icon.Handle).CGImage ', IntToHex(Int64(TCarbonBitmap(ATrayIcon.Icon.Handle).CGImage), 8)
     );
  {$endif VerboseCarbonTrayIcon}
end;

class procedure TCarbonWSCustomTrayIcon.InternalUpdate(const ATrayIcon: TCustomTrayIcon);
var
  APrivateTrayIcon: TPrivateCocoaCarbonTrayIcon;
begin
  APrivateTrayIcon := TPrivateCocoaCarbonTrayIcon(ATrayIcon.Handle);

  if APrivateTrayIcon = nil then Exit;

  // The update is only necessary for a visible TTrayIcon
  if not ATrayIcon.Visible then Exit;

  { Updates the image }

  if Assigned(APrivateTrayIcon.Image) then
    APrivateTrayIcon.image.Free;

  if Assigned(ATrayIcon.Icon) then
  begin
    APrivateTrayIcon.image := APrivateTrayIcon.ConvertTIconToNSImage(ATrayIcon.Icon);
    APrivateTrayIcon.item.setImage(APrivateTrayIcon.image.Handle);
  end;

  { Inserts the menu }

  APrivateTrayIcon.ReleaseMenu();
  if ATrayIcon.PopUpMenu <> nil then
  begin
    APrivateTrayIcon.menu := APrivateTrayIcon.CreateMenu(ATrayIcon.PopUpMenu);
    if APrivateTrayIcon.item <> nil then
      APrivateTrayIcon.item.setMenu(APrivateTrayIcon.menu.Handle);
  end;
end;

class function TCarbonWSCustomTrayIcon.ShowBalloonHint(const ATrayIcon: TCustomTrayIcon): Boolean;
begin
  Result := False;
end;

class function TCarbonWSCustomTrayIcon.GetPosition(const ATrayIcon: TCustomTrayIcon): TPoint;
begin
  Result := Point(0, 0);
end;

class function TCarbonWSCustomTrayIcon.IsTrayIconMenuVisible(const ATrayIcon: TCustomTrayIcon): Boolean;
var
  APrivateTrayIcon: TPrivateCocoaCarbonTrayIcon;
begin
  Result := False;

  APrivateTrayIcon := TPrivateCocoaCarbonTrayIcon(ATrayIcon.Handle);

  if APrivateTrayIcon = nil then Exit;

  Result := APrivateTrayIcon.IsMenuVisible;
end;

{$endif CarbonUseCocoa}


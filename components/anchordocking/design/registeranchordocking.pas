{ Installs anchor docking manager in the Lazarus IDE.

  Copyright (C) 2018 Mattias Gaertner mattias@freepascal.org

  This library is free software; you can redistribute it and/or modify it
  under the terms of the GNU Library General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at your
  option) any later version with the following modification:

  As a special exception, the copyright holders of this library give you
  permission to link this library with independent modules to produce an
  executable, regardless of the license terms of these independent modules,and
  to copy and distribute the resulting executable under terms of your choice,
  provided that you also meet, for each linked independent module, the terms
  and conditions of the license of that module. An independent module is a
  module which is not derived from or based on this library. If you modify
  this library, you may extend this exception to your version of the library,
  but you are not obligated to do so. If you do not wish to do so, delete this
  exception statement from your version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
  for more details.

  You should have received a copy of the GNU Library General Public License
  along with this library; if not, write to the Free Software Foundation,
  Inc., 51 Franklin Street - Fifth Floor, Boston, MA 02110-1335, USA.
}
unit RegisterAnchorDocking;

{$mode objfpc}{$H+}

{ $DEFINE VerboseAnchorDocking}

interface

uses
  Math, Classes, SysUtils,
  // LCL
  LCLProc, Forms, Controls, Dialogs, StdCtrls,
  // LazUtils
  LazFileCache, LazFileUtils,
  // IdeIntf
  LCLIntf, IDEWindowIntf, IDEOptionsIntf, IDEOptEditorIntf, LazIDEIntf,
  // AnchorDocking
  AnchorDockStr, AnchorDocking, AnchorDesktopOptions, AnchorDockOptionsDlg;

type

  { TIDEAnchorDockMaster }

  TIDEAnchorDockMaster = class(TIDEDockMaster)
  private
    FChangeStamp: int64;
    FCmdLineLayoutFile: string;
    FSavedChangeStamp: int64;
    FSavedDMChangeStamp: int64;
    FUserLayoutLoaded: boolean;
    procedure DockMasterCreateControl(Sender: TObject; aName: string;
      var AControl: TControl; DoDisableAutoSizing: boolean);
    procedure GetDefaultBounds(AForm: TCustomForm; out Creator: TIDEWindowCreator;
      out NewBounds: TRect; out DockSiblingName: string; out DockAlign: TAlign);
    function GetModified: boolean;
    procedure SetModified(const AValue: boolean);
    procedure SetUserLayoutLoaded(const AValue: boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure IncreaseChangeStamp; inline;
    property ChangeStamp: int64 read FChangeStamp;
    property Modified: boolean read GetModified write SetModified;
    function DockedDesktopOptClass: TAbstractDesktopDockingOptClass; override;
    // layouts
    property UserLayoutLoaded: boolean read FUserLayoutLoaded write SetUserLayoutLoaded;
    property CmdLineLayoutFile: string read FCmdLineLayoutFile write FCmdLineLayoutFile;
    // events
    procedure MakeIDEWindowDockSite(AForm: TCustomForm; ASides: TDockSides = [alBottom]); override;
    procedure MakeIDEWindowDockable(AControl: TWinControl); override;
    function AddableInWindowMenu(AForm: TCustomForm): boolean; override;
    procedure ShowForm(AForm: TCustomForm; BringToFront: boolean); override;
    procedure AdjustMainIDEWindowHeight(const AIDEWindow: TCustomForm;
      const AAdjustHeight: Boolean; const ANewHeight: Integer); override;
    procedure CloseAll; override;
    procedure ResetSplitters; override;
    procedure SetMainDockWindow(AForm: TCustomForm); override;
  end;

  { TAnchorDockIDEFrame }

  TAnchorDockIDEFrame = class(TAbstractIDEOptionsEditor)
    NoteLabel: TLabel;
  private
    FSettings: TAnchorDockSettings;
  public
    OptionsFrame: TAnchorDockOptionsFrame;
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    function GetTitle: String; override;
    procedure Setup(ADialog: TAbstractOptionsEditorDialog); override;
    procedure ReadSettings(AOptions: TAbstractIDEOptions); override;
    procedure WriteSettings(AOptions: TAbstractIDEOptions); override;
    class function SupportedOptionsClass: TAbstractIDEOptionsClass; override;
  end;

var
  IDEAnchorDockMaster: TIDEAnchorDockMaster = nil;
  AnchorDockOptionsID: integer = 1000;

procedure Register;

implementation

{$R *.lfm}

procedure Register;
begin
  if not (IDEDockMaster is TIDEAnchorDockMaster) then exit;

  // add options frame
  AnchorDockOptionsID:=RegisterIDEOptionsEditor(GroupEnvironment,TAnchorDockIDEFrame,
                                                AnchorDockOptionsID)^.Index;
end;

{ TIDEAnchorDockMaster }

procedure TIDEAnchorDockMaster.DockMasterCreateControl(Sender: TObject;
  aName: string; var AControl: TControl; DoDisableAutoSizing: boolean);
begin
  //debugln(['TIDEAnchorDockMaster.DockMasterCreateControl CtrlName="',dbgstr(AName),'"']);
  AControl:=IDEWindowCreators.GetForm(aName,true,DoDisableAutoSizing);
  //debugln(['TIDEAnchorDockMaster.DockMasterCreateControl Result=',DbgSName(AControl)]);
end;

procedure TIDEAnchorDockMaster.GetDefaultBounds(AForm: TCustomForm; out
  Creator: TIDEWindowCreator; out NewBounds: TRect; out
  DockSiblingName: string; out DockAlign: TAlign);
var
  AControl: TControl;
begin
  NewBounds:=Rect(0,0,0,0);
  DockSiblingName:='';
  DockAlign:=alNone;

  // get the embedded control
  AControl:=DockMaster.GetControl(AForm);
  if not (AControl is TCustomForm) then exit;
  AForm:=TCustomForm(AControl);

  Creator:=IDEWindowCreators.FindWithName(AForm.Name);
  if Creator=nil then exit;
  if Creator.OnGetLayout<>nil then
    Creator.OnGetLayout(Self,AForm.Name,NewBounds,DockSiblingName,DockAlign)
  else begin
    Creator.GetDefaultBounds(AForm,NewBounds);
    DockSiblingName:=Creator.DockSibling;
    DockAlign:=Creator.DockAlign;
  end;
  {$IFDEF darwin}
  if (NewBounds.Top=0) and (NewBounds.Left=0) then
    NewBounds.Top:=30;
  {$ENDIF}
  NewBounds.Left:=Min(10000,Max(-10000,NewBounds.Left));
  NewBounds.Top:=Min(10000,Max(-10000,NewBounds.Top));
  NewBounds.Right:=Max(NewBounds.Left+100,NewBounds.Right);
  NewBounds.Bottom:=Max(NewBounds.Top+100,NewBounds.Bottom);
end;

function TIDEAnchorDockMaster.GetModified: boolean;
begin
  Result:=true;
  if FChangeStamp=FSavedChangeStamp then exit;
  if DockMaster.OptionsChangeStamp=FSavedDMChangeStamp then exit;
  Result:=false;
end;

procedure TIDEAnchorDockMaster.SetModified(const AValue: boolean);
begin
  if AValue then
    IncreaseChangeStamp
  else begin
    FSavedChangeStamp:=FChangeStamp;
    FSavedDMChangeStamp:=DockMaster.OptionsChangeStamp;
  end;
end;

procedure TIDEAnchorDockMaster.SetUserLayoutLoaded(const AValue: boolean);
begin
  if FUserLayoutLoaded=AValue then exit;
  FUserLayoutLoaded:=AValue;
end;

constructor TIDEAnchorDockMaster.Create;
begin
  inherited Create;
  DefaultAnchorDockOptionFlags:=[adofShow_ShowHeader,adofSpinEdits];

  IDEAnchorDockMaster:=Self;
  DockMaster.OnCreateControl:=@DockMasterCreateControl;
  DockMaster.OnShowOptions:=@ShowAnchorDockOptions;
  DockMaster.ShowMenuItemShowHeader:=true;
  fCmdLineLayoutFile:=TrimAndExpandFilename(Application.GetOptionValue('anchordocklayout'));
  if CmdLineLayoutFile<>'' then
    debugln(['Hint: anchordocking layout file: "',CmdLineLayoutFile,'"']);
end;

destructor TIDEAnchorDockMaster.Destroy;
begin
  IDEAnchorDockMaster:=nil;
  if IDEDockMaster=Self then
    IDEDockMaster:=nil;
  inherited Destroy;
end;

function TIDEAnchorDockMaster.DockedDesktopOptClass: TAbstractDesktopDockingOptClass;
begin
  Result := TAnchorDesktopOpt;
end;

procedure TIDEAnchorDockMaster.MakeIDEWindowDockSite(AForm: TCustomForm;
  ASides: TDockSides);
var
  aManager: TAnchorDockManager;
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TIDEAnchorDockMaster.MakeIDEWindowDockSite ',DbgSName(AForm)]);
  {$ENDIF}
  if ASides=[] then ;
  DockMaster.MakeDockSite(AForm,[akBottom],admrpChild);
  if AForm.DockManager is TAnchorDockManager then begin
    aManager:=TAnchorDockManager(AForm.DockManager);
    aManager.PreferredSiteSizeAsSiteMinimum:=false;
  end;
end;

procedure TIDEAnchorDockMaster.ResetSplitters;
begin
  DockMaster.ResetSplitters;
end;

procedure TIDEAnchorDockMaster.SetMainDockWindow(AForm: TCustomForm);
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TIDEAnchorDockMaster.SetMainDockWindow ',DbgSName(AForm)]);
  {$ENDIF}
  DockMaster.MainDockForm := AForm;
end;

procedure TIDEAnchorDockMaster.MakeIDEWindowDockable(AControl: TWinControl);
begin
  {$IFDEF VerboseAnchorDocking}
  debugln(['TIDEAnchorDockMaster.MakeIDEWindowDockable ',DbgSName(AControl)]);
  {$ENDIF}
  DockMaster.MakeDockable(AControl,false);
end;

function TIDEAnchorDockMaster.AddableInWindowMenu(AForm: TCustomForm): boolean;
begin
  Result:=false;
  if AForm is TAnchorDockHostSite then exit;
  if (DockMaster.FindControl(AForm.Name)=nil) and (AForm.Parent<>nil) then exit;
  Result := AForm.IsVisible
    or (
      Assigned(AForm.Parent)
      and Assigned(AForm.Parent.Parent)
      and (AForm.Parent.Parent is TAnchorDockPage)
    );
end;

procedure TIDEAnchorDockMaster.AdjustMainIDEWindowHeight(
  const AIDEWindow: TCustomForm; const AAdjustHeight: Boolean;
  const ANewHeight: Integer);
var
  Site: TAnchorDockHostSite;
  I: Integer;
  SiteNewHeight: Integer;
begin
  inherited AdjustMainIDEWindowHeight(AIDEWindow, AAdjustHeight, ANewHeight);

  Site := nil;
  for I := 0 to AIDEWindow.ControlCount-1 do
    if AIDEWindow.Controls[I] is TAnchorDockHostSite then
    begin
      Site := TAnchorDockHostSite(AIDEWindow.Controls[I]);
      if (Site.Parent<>nil) and (Site.Parent=LazarusIDE.GetMainBar) then
        Break // found
      else
        Site := nil;
    end;

  if (Site=nil) or (Site.BoundSplitter=nil) then
    Exit;

  Site.BoundSplitter.Enabled := not AAdjustHeight;
  Site.BoundSplitter.CustomWidth := not Site.BoundSplitter.Enabled;
  if Site.BoundSplitter.Enabled then
    Site.BoundSplitter.Height := DockMaster.SplitterWidth
  else
  begin
    Site.BoundSplitter.Constraints.MinHeight := 2;
    Site.BoundSplitter.Height := Site.BoundSplitter.Constraints.MinHeight;
  end;
  SiteNewHeight := Site.Parent.ClientHeight - ANewHeight - Site.BoundSplitter.Height;
  if AAdjustHeight and (Site.Height <> SiteNewHeight) then
    Site.Height := SiteNewHeight;
end;

procedure TIDEAnchorDockMaster.ShowForm(AForm: TCustomForm;
  BringToFront: boolean);
var
  Parent: TCustomForm;
  Creator: TIDEWindowCreator;
  NewBounds: TRect;
  DockSiblingName: string;
  DockAlign: TAlign;
  DockSibling: TCustomForm;
  NewDockSite: TCustomForm;
  Site: TAnchorDockHostSite;
  AControl: TControl;
  NeedPlacing: Boolean;
  SiteForm: TCustomForm;
  OldActiveControl: TWinControl;
begin
  //debugln(['TIDEAnchorDockMaster.ShowForm START ',DbgSName(AForm),' BringToFront=',BringToFront,' IsSite=',DockMaster.IsSite(AForm),' IsCustomSite=',DockMaster.IsCustomSite(AForm)]);
  try
    AForm.DisableAlign;

    NeedPlacing:=not AForm.IsVisible;
    if DockMaster.GetSite(AForm)=nil then begin
      // this form was not yet docked
      // => make it dockable
      DockMaster.MakeDockable(AForm,false);
      NeedPlacing:=true;
    end;
    AControl:=DockMaster.GetControl(AForm);

    {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
    if not AForm.IsVisible then
      debugln(['TIDEAnchorDockMaster.ShowForm AControl=',DbgSName(AControl),' NeedPlacing=',NeedPlacing,' Floating=',DockMaster.IsFloating(AForm)]);
    {$ENDIF}

    if (AControl<>nil) and NeedPlacing and DockMaster.IsFloating(AForm) then begin
      // this form is not yet on the screen and is not yet docked
      {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
      debugln(['TIDEAnchorDockMaster.ShowForm placing ',DbgSName(AControl),' ...']);
      {$ENDIF}

      // ToDo: use the restore layout

      // place it at a default position and/or dock it
      GetDefaultBounds(AForm,Creator,NewBounds,DockSiblingName,DockAlign);
      if Creator<>nil then begin
        SiteForm:=GetParentForm(AForm);
        SiteForm.BoundsRect:=NewBounds;
        SiteForm.UndockWidth:=NewBounds.Right-NewBounds.Left;
        SiteForm.UndockHeight:=NewBounds.Bottom-NewBounds.Top;
        {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
        debugln(['TIDEAnchorDockMaster.ShowForm creator for ',DbgSName(AControl),' found: Left=',Creator.Left,' Top=',Creator.Top,' Right=',Creator.Right,' Bottom=',Creator.Bottom,' DockSiblingName=',DockSiblingName,' DockAlign=',dbgs(DockAlign),' ',dbgs(SiteForm.BoundsRect)]);
        {$ENDIF}
        Site:=DockMaster.GetAnchorSite(SiteForm);
        if (Site<>nil) and (DockSiblingName<>'') then begin
          DockSibling:=Screen.FindForm(DockSiblingName);
          {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
          debugln(['TIDEAnchorDockMaster.ShowForm DockSiblingName="',DockSiblingName,'" DockSibling=',DbgSName(DockSibling)]);
          {$ENDIF}
          if DockSibling<>nil then begin
            NewDockSite:=DockMaster.GetSite(DockSibling);
            if NewDockSite<>nil then begin
              {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
              debugln(['TIDEAnchorDockMaster.ShowForm NewDockSite=',DbgSName(NewDockSite),'="',NewDockSite.Caption,'"']);
              {$ENDIF}
              DockMaster.ManualDock(Site,NewDockSite,DockAlign,NewDockSite);
              {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
              debugln(['TIDEAnchorDockMaster.ShowForm after docking: ',DbgSName(AControl),' Floating=',DockMaster.IsFloating(AControl)]);
              {$ENDIF}
            end;
          end;
        end;
      end;
    end;

  finally
    OldActiveControl:=AForm.LastActiveControl;
    {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
    if not AForm.IsVisible then
      debugln(['TIDEAnchorDockMaster.ShowForm MakeVisible ',DbgSName(AForm),' ',dbgs(AForm.BoundsRect),' Floating=',DockMaster.IsFloating(AForm)]);
    {$ENDIF}
    DockMaster.MakeVisible(AForm,BringToFront);
    AForm.EnableAlign;

    if BringToFront then begin
      if (OldActiveControl=nil)
      or (not OldActiveControl.HandleAllocated)
      or (FindControl(GetFocus)<>OldActiveControl) then begin
        Parent:=GetParentForm(AForm);
        Parent.ShowOnTop;
        if (OldActiveControl<>nil) and OldActiveControl.CanFocus then
        begin
          Parent.ActiveControl:=OldActiveControl;
          Parent.SetFocus;
        end;
        //debugln(['TIDEAnchorDockMaster.ShowForm AForm.ActiveControl=',dbgsname(AForm.ActiveControl),' ',DbgSName(Parent.ActiveControl),' ',DbgSName(FindControl(GetFocus))]);
      end;
    end;
  end;
  //debugln(['TIDEAnchorDockMaster.ShowForm END ',DbgSName(AForm),' ',dbgs(AForm.BoundsRect),' ',DbgSName(FindControl(GetFocus))]);
end;

procedure TIDEAnchorDockMaster.CloseAll;
begin
  DockMaster.CloseAll;
end;

procedure TIDEAnchorDockMaster.IncreaseChangeStamp;
begin
  LUIncreaseChangeStamp64(FChangeStamp);
end;

{ TAnchorDockIDEFrame }

constructor TAnchorDockIDEFrame.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);

  FSettings:=TAnchorDockSettings.Create;
  OptionsFrame:=TAnchorDockOptionsFrame.Create(Self);
  with OptionsFrame do begin
    Name:='OptionsFrame';
  end;
end;

destructor TAnchorDockIDEFrame.Destroy;
begin
  FreeAndNil(FSettings);
  inherited Destroy;
end;

function TAnchorDockIDEFrame.GetTitle: String;
begin
  Result:=adrsDockingAnchordocking;
end;

procedure TAnchorDockIDEFrame.Setup(ADialog: TAbstractOptionsEditorDialog);
begin
  if ADialog=nil then ;
  if IDEDockMaster=IDEAnchorDockMaster then begin
    NoteLabel.Visible:=false;
    OptionsFrame.Align:=alClient;
    OptionsFrame.Parent:=Self;
  end else begin
    NoteLabel.Visible:=true;
    NoteLabel.Caption:=Format(adrsToUseAnchordockingYouMustFirstUninstall, [
      DbgSName(IDEDockMaster)]);
    NoteLabel.Hint:=Format(
      adrsThereIsAnotherDockMasterInstalledOnlyOneDockingPac, [DbgSName(
      IDEDockMaster)]);
    OptionsFrame.Parent:=nil;
  end;
end;

procedure TAnchorDockIDEFrame.ReadSettings(AOptions: TAbstractIDEOptions);
begin
  if not (AOptions is SupportedOptionsClass) then exit;
  DockMaster.SaveSettings(FSettings);
  OptionsFrame.LoadFromSettings(FSettings);
end;

procedure TAnchorDockIDEFrame.WriteSettings(AOptions: TAbstractIDEOptions);
begin
  if not (AOptions is SupportedOptionsClass) then exit;
  OptionsFrame.SaveToSettings(FSettings);
  if (not DockMaster.SettingsAreEqual(FSettings))
  then begin
    DockMaster.LoadSettings(FSettings);
  end;
end;

class function TAnchorDockIDEFrame.
  SupportedOptionsClass: TAbstractIDEOptionsClass;
begin
  Result:=IDEEditorGroups.GetByIndex(GroupEnvironment)^.GroupClass;
end;

initialization
  // create the dockmaster in the initialization section, so that it is ready
  // when the Register procedures of the packages are called.
  if IDEDockMaster<>nil then begin
    debugln('WARNING: there is already another IDEDockMaster installed: ',DbgSName(IDEDockMaster));
    TIDEAnchorDockMaster.Create;
  end else
    IDEDockMaster:=TIDEAnchorDockMaster.Create;

finalization
  FreeAndNil(IDEAnchorDockMaster);

end.


{ For license see registeranchordocking.pas
}
unit AnchorDesktopOptions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  // LCL
  LCLProc, Forms, Controls, LCLType, LResources,
  // LazUtils
  LazFileUtils, LazConfigStorage, Laz2_XMLCfg, LazUTF8,
  // IdeIntf
  IDEOptionsIntf, LazIDEIntf, BaseIDEIntf,
  // AnchorDocking
  AnchorDocking, AnchorDockStorage;

const
  AnchorDockingFileVersion = 1;
  //1 added Settings node (FSettings: TAnchorDockSettings)

type

  { TAnchorDesktopOpt }

  TAnchorDesktopOpt = class(TAbstractDesktopDockingOpt)
  private
    FTree: TAnchorDockLayoutTree;
    FRestoreLayouts: TAnchorDockRestoreLayouts;
    FSettings: TAnchorDockSettings;
  public
    procedure LoadDefaultLayout;
    procedure LoadLegacyAnchorDockOptions;
    procedure LoadLayoutFromConfig(Path: string; aXMLCfg: TRttiXMLConfig);
    procedure LoadLayoutFromFile(FileName: string);
    procedure LoadLayoutFromRessource;

    procedure SaveMainLayoutToTree;
    procedure SaveLayoutToConfig(Path: string; aXMLCfg: TRttiXMLConfig);
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure LoadDefaults; override;
    procedure Load(Path: String; aXMLCfg: TRttiXMLConfig); override;
    procedure Save(Path: String; aXMLCfg: TRttiXMLConfig); override;
    procedure ImportSettingsFromIDE; override;
    procedure ExportSettingsToIDE; override;
    function RestoreDesktop: Boolean; override;
    procedure Assign(Source: TAbstractDesktopDockingOpt); override;
  end;

implementation

{ TAnchorDesktopOpt }

procedure TAnchorDesktopOpt.Assign(Source: TAbstractDesktopDockingOpt);
var
  ADOpts: TAnchorDesktopOpt;
begin
  if Source is TAnchorDesktopOpt then
  begin
    ADOpts := TAnchorDesktopOpt(Source);
    FTree.Assign(ADOpts.FTree);
    FRestoreLayouts.Assign(ADOpts.FRestoreLayouts);
    FSettings.Assign(ADOpts.FSettings);
  end;
end;

constructor TAnchorDesktopOpt.Create;
begin
  inherited Create;

  FTree := TAnchorDockLayoutTree.Create;
  FSettings := TAnchorDockSettings.Create;
  FRestoreLayouts := TAnchorDockRestoreLayouts.Create;
end;

destructor TAnchorDesktopOpt.Destroy;
begin
  FSettings.Free;
  FTree.Free;
  FRestoreLayouts.Free;
  inherited Destroy;
end;

procedure TAnchorDesktopOpt.ExportSettingsToIDE;
begin
  DockMaster.LoadSettings(FSettings);
  DockMaster.RestoreLayouts.Assign(FRestoreLayouts);
end;

procedure TAnchorDesktopOpt.Load(Path: String; aXMLCfg: TRttiXMLConfig);
begin
  Path := Path + 'AnchorDocking/';
  try
    {$IFDEF VerboseAnchorDocking}
    DebugLn(['TAnchorDesktopOpt.LoadUserLayout ',Path]);
    {$ENDIF}
    if aXMLCfg.GetValue(Path+'MainConfig/Nodes/ChildCount',0) > 0 then//config is not empty
    begin
      // loading last layout
      {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
      DebugLn(['TAnchorDesktopOpt.LoadUserLayout restoring ...']);
      {$ENDIF}
      LoadLayoutFromConfig(Path,aXMLCfg);
    end else begin
      // loading defaults
      {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
      DebugLn(['TAnchorDesktopOpt.LoadUserLayout loading default layout ...']);
      {$ENDIF}
      LoadLegacyAnchorDockOptions;
      LoadDefaultLayout;
    end;
  except
    on E: Exception do begin
      DebugLn(['TAnchorDesktopOpt.LoadUserLayout loading ',aXMLCfg.GetValue(Path+'Name', ''),' failed: ',E.Message]);
      Raise;
    end;
  end;
end;

procedure TAnchorDesktopOpt.LoadDefaultLayout;
var
  Filename: String;
begin
  Filename := AppendPathDelim(LazarusIDE.GetPrimaryConfigPath)+'anchordocklayout.xml';
  if FileExistsUTF8(Filename) then//first load from anchordocklayout.xml -- backwards compatibility
    LoadLayoutFromFile(Filename)
  else
    LoadLayoutFromRessource;
end;

procedure TAnchorDesktopOpt.LoadDefaults;
begin
  LoadLegacyAnchorDockOptions;
  LoadDefaultLayout;
end;

procedure TAnchorDesktopOpt.ImportSettingsFromIDE;
begin
  SaveMainLayoutToTree;
  DockMaster.SaveSettings(FSettings);
  FRestoreLayouts.Assign(DockMaster.RestoreLayouts);
end;

procedure TAnchorDesktopOpt.LoadLayoutFromConfig(Path: string;
  aXMLCfg: TRttiXMLConfig);
var
  FileVersion: Integer;
begin
  FileVersion:=aXMLCfg.GetValue(Path+'Version/Value',0);
  FTree.LoadFromConfig(Path+'MainConfig/', aXMLCfg);
  FRestoreLayouts.LoadFromConfig(Path+'Restores/', aXMLCfg);
  if (FileVersion = 0) then//backwards compatibility - read anchordockoptions.xml
    LoadLegacyAnchorDockOptions
  else
    FSettings.LoadFromConfig(Path+'Settings/', aXMLCfg);
end;

procedure TAnchorDesktopOpt.LoadLayoutFromFile(FileName: string);
var
  Config: TRttiXMLConfig;
begin
  Config := TRttiXMLConfig.Create(FileName);
  try
    LoadLayoutFromConfig('',Config);
  finally
    Config.Free;
  end;
end;

procedure TAnchorDesktopOpt.LoadLayoutFromRessource;
var
  Config: TRttiXMLConfig;
  LayoutResource: TLazarusResourceStream;
begin
  LayoutResource := TLazarusResourceStream.Create('ADLayoutDefault', nil);
  try
    Config := TRttiXMLConfig.Create(nil);
    try
      Config.ReadFromStream(LayoutResource);
      LoadLayoutFromConfig('',Config);
    finally
      Config.Free;
    end;
  finally
    LayoutResource.Free;
  end;
end;

procedure TAnchorDesktopOpt.LoadLegacyAnchorDockOptions;
var
  Config: TConfigStorage;
begin
  try
    Config:=GetIDEConfigStorage('anchordockoptions.xml',true);
    try
      FSettings.LoadFromConfig(Config);
    finally
      Config.Free;
    end;
  except
    on E: Exception do begin
      DebugLn(['TAnchorDesktopOpt.LoadLayoutFromConfig - LoadAnchorDockOptions failed: ',E.Message]);
    end;
  end;
end;

procedure TAnchorDesktopOpt.Save(Path: String; aXMLCfg: TRttiXMLConfig);
begin
  Path := Path + 'AnchorDocking/';
  try
    {$IF defined(VerboseAnchorDocking) or defined(VerboseAnchorDockRestore)}
    DebugLn(['TAnchorDesktopOpt.SaveDefaultLayout ',Path]);
    {$ENDIF}
    SaveLayoutToConfig(Path, aXMLCfg);
  except
    on E: Exception do begin
      DebugLn(['TAnchorDesktopOpt.SaveDefaultLayout saving ',aXMLCfg.GetValue(Path+'Name', ''),' failed: ',E.Message]);
      Raise;
    end;
  end;
end;

procedure TAnchorDesktopOpt.SaveLayoutToConfig(Path: string; aXMLCfg: TRttiXMLConfig);
begin
  aXMLCfg.SetValue(Path+'Version/Value',AnchorDockingFileVersion);
  FTree.SaveToConfig(Path+'MainConfig/', aXMLCfg);
  FRestoreLayouts.SaveToConfig(Path+'Restores/', aXMLCfg);
  FSettings.SaveToConfig(Path+'Settings/', aXMLCfg);
  {$IFDEF VerboseAnchorDocking}
  WriteDebugLayout('TAnchorDesktopOpt.SaveLayoutToConfig ',FTree.Root);
  {$ENDIF}
end;

procedure TAnchorDesktopOpt.SaveMainLayoutToTree;
var
  i: Integer;
  AControl: TControl;
  Site: TAnchorDockHostSite;
  SavedSites: TFPList;
  LayoutNode: TAnchorDockLayoutTreeNode;
  AForm: TCustomForm;
  VisibleControls: TStringListUTF8Fast;
begin
  FTree.Clear;
  SavedSites:=TFPList.Create;
  VisibleControls:=TStringListUTF8Fast.Create;
  with DockMaster do
  try
    for i:=0 to ControlCount-1 do begin
      AControl:=Controls[i];
      if not DockedControlIsVisible(AControl) then continue;
      VisibleControls.Add(AControl.Name);
      AForm:=GetParentForm(AControl);
      if AForm=nil then continue;
      if SavedSites.IndexOf(AForm)>=0 then continue;
      SavedSites.Add(AForm);
      {$IFDEF VerboseAnchorDocking}
      debugln(['TAnchorDesktopOpt.SaveMainLayoutToTree AForm=',DbgSName(AForm)]);
      DebugWriteChildAnchors(AForm,true,true);
      {$ENDIF}
      if (AForm is TAnchorDockHostSite) then begin
        Site:=TAnchorDockHostSite(AForm);
        LayoutNode:=FTree.NewNode(FTree.Root);
        Site.SaveLayout(FTree,LayoutNode);
      end else if IsCustomSite(AForm) then begin
        // custom dock site
        LayoutNode:=FTree.NewNode(FTree.Root);
        LayoutNode.NodeType:=adltnCustomSite;
        LayoutNode.Assign(AForm,false,false);
        // can have one normal dock site
        Site:=TAnchorDockManager(AForm.DockManager).GetChildSite;
        if Site<>nil then begin
          LayoutNode:=FTree.NewNode(LayoutNode);
          Site.SaveLayout(FTree,LayoutNode);
          {if Site.BoundSplitter<>nil then begin
            LayoutNode:=FTree.NewNode(LayoutNode);
            Site.BoundSplitter.SaveLayout(LayoutNode);
          end;}
        end;
      end else
        raise EAnchorDockLayoutError.Create('invalid root control for save: '+DbgSName(AControl));
    end;
    // remove invisible controls
    FTree.Root.Simplify(VisibleControls,false);
  finally
    VisibleControls.Free;
    SavedSites.Free;
  end;
end;

function TAnchorDesktopOpt.RestoreDesktop: Boolean;
begin
  Result := DockMaster.FullRestoreLayout(FTree,True);
end;

initialization

{$I ADLayoutDefault.lrs}

end.


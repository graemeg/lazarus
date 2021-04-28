{ For license see anchordocking.pas
}
Unit AnchorDockStorage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math,
  // LCL
  LCLProc, ExtCtrls, ComCtrls, Forms, Controls,
  // LazUtils
  AvgLvlTree, LazConfigStorage, Laz2_XMLCfg, LazLoggerBase, LazTracer,
  // AnchorDocking
  AnchorDockStr;

const
  AnchorDockSplitterName = 'AnchorDockSplitter';
  AnchorDockSiteName = 'AnchorDockSite';
type
  TADLTreeNodeType = (
    adltnNone,
    adltnLayout,
    adltnControl,
    adltnSplitterHorizontal,
    adltnSplitterVertical,
    adltnPages,
    adltnCustomSite
    );
  TADLTreeNodeTypes = set of TADLTreeNodeType;

  TADLHeaderPosition = (
    adlhpAuto,
    adlhpTop,
    adlhpLeft,
    adlhpRight,
    adlhpBottom
    );

  TADLControlLocation = (
    adlclWrongly,
    adlclCorrect
    );
  TADLHeaderPositions = set of TADLHeaderPosition;

  EAnchorDockLayoutError = class(Exception);

  { TAnchorDockLayoutTreeNode }

  TAnchorDockLayoutTreeNode = class
  private
    FAlign: TAlign;
    fAnchors: array[TAnchorKind] of string;
    FBoundSplitterPos: integer;
    FBoundsRect: TRect;
    FHeaderPosition: TADLHeaderPosition;
    FMonitor: integer;
    FName: string;
    FNodes: TFPList; // list of TAnchorDockLayoutTreeNode
    FNodeType: TADLTreeNodeType;
    FPageIndex: integer;
    FParent: TAnchorDockLayoutTreeNode;
    FPixelsPerInch: Integer;
    FWorkAreaRect: TRect;
    FTabPosition: TTabPosition;
    FWindowState: TWindowState;
    FControlLocation: TADLControlLocation;
    FMinimized: Boolean;
    function GetAnchors(Site: TAnchorKind): string;
    function GetBottom: integer;
    function GetHeight: integer;
    function GetLeft: integer;
    function GetNodes(Index: integer): TAnchorDockLayoutTreeNode;
    function GetRight: integer;
    function GetTop: integer;
    function GetWidth: integer;
    procedure SetAlign(const AValue: TAlign);
    procedure SetAnchors(Site: TAnchorKind; const AValue: string);
    procedure SetBottom(const AValue: integer);
    procedure SetBoundSplitterPos(const AValue: integer);
    procedure SetBoundsRect(const AValue: TRect);
    procedure SetHeaderPosition(const AValue: TADLHeaderPosition);
    procedure SetHeight(const AValue: integer);
    procedure SetLeft(const AValue: integer);
    procedure SetMonitor(const AValue: integer);
    procedure SetName(const AValue: string);
    procedure SetNodeType(const AValue: TADLTreeNodeType);
    procedure SetPageIndex(AValue: integer);
    procedure SetParent(const AValue: TAnchorDockLayoutTreeNode);
    procedure SetPixelsPerInch(AValue: Integer);
    procedure SetRight(const AValue: integer);
    procedure SetWorkAreaRect(const AValue: TRect);
    procedure SetTabPosition(const AValue: TTabPosition);
    procedure SetTop(const AValue: integer);
    procedure SetWidth(const AValue: integer);
    procedure SetWindowState(const AValue: TWindowState);
    procedure SetMinimized(const AValue: boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function IsEqual(Node: TAnchorDockLayoutTreeNode): boolean;
    procedure Assign(Node: TAnchorDockLayoutTreeNode); overload;
    procedure Assign(AControl: TControl; OverrideBoundsRect, AMinimized: boolean); overload;
    procedure LoadFromConfig(Config: TConfigStorage); overload;
    procedure LoadFromConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure SaveToConfig(Config: TConfigStorage); overload;
    procedure SaveToConfig(Path: string; Config: TRttiXMLConfig); overload;
    function FindChildNode(aName: string; Recursive: boolean): TAnchorDockLayoutTreeNode;
    function FindControlNode: TAnchorDockLayoutTreeNode;
    procedure CheckConsistency; virtual;

    // simplifying
    procedure Simplify(ExistingNames: TStrings; ParentMinimized: boolean);
    procedure DeleteNode(ChildNode: TAnchorDockLayoutTreeNode);
    function FindNodeBoundSplitter(ChildNode: TAnchorDockLayoutTreeNode;
                                   Side: TAnchorKind): TAnchorDockLayoutTreeNode;
    procedure DeleteNodeBoundSplitter(Splitter, ChildNode: TAnchorDockLayoutTreeNode;
                                      Side: TAnchorKind);
    procedure DeleteSpiralSplitter(ChildNode: TAnchorDockLayoutTreeNode);
    procedure ReplaceWithChildren(ChildNode: TAnchorDockLayoutTreeNode);

    // properties
    procedure IncreaseChangeStamp; virtual;
    property Name: string read FName write SetName;
    property NodeType: TADLTreeNodeType read FNodeType write SetNodeType;
    property Parent: TAnchorDockLayoutTreeNode read FParent write SetParent;
    property Left: integer read GetLeft write SetLeft;
    property Top: integer read GetTop write SetTop;
    property Width: integer read GetWidth write SetWidth;
    property Height: integer read GetHeight write SetHeight;
    property Right: integer read GetRight write SetRight;
    property Bottom: integer read GetBottom write SetBottom;
    property BoundsRect: TRect read FBoundsRect write SetBoundsRect;
    property BoundSplitterPos: integer read FBoundSplitterPos write SetBoundSplitterPos;
    property PixelsPerInch: Integer read FPixelsPerInch write SetPixelsPerInch;
    property WorkAreaRect: TRect read FWorkAreaRect write SetWorkAreaRect;
    property Anchors[Site: TAnchorKind]: string read GetAnchors write SetAnchors; // empty means default (parent)
    property Align: TAlign read FAlign write SetAlign;
    property WindowState: TWindowState read FWindowState write SetWindowState;
    property Monitor: integer read FMonitor write SetMonitor;
    property HeaderPosition: TADLHeaderPosition read FHeaderPosition write SetHeaderPosition;
    property TabPosition: TTabPosition read FTabPosition write SetTabPosition;
    property PageIndex: integer read FPageIndex write SetPageIndex;
    property Minimized: Boolean read FMinimized write SetMinimized;
    function Count: integer;
    function IsSplitter: boolean;
    function IsRootWindow: boolean;
    property Nodes[Index: integer]: TAnchorDockLayoutTreeNode read GetNodes; default;
    property ControlLocation: TADLControlLocation read FControlLocation write FControlLocation;
  end;

  TAnchorDockLayoutTree = class;

  { TAnchorDockLayoutTreeRootNode }

  TAnchorDockLayoutTreeRootNode = class(TAnchorDockLayoutTreeNode)
  private
    FTree: TAnchorDockLayoutTree;
  public
    procedure IncreaseChangeStamp; override;
    property Tree: TAnchorDockLayoutTree read FTree write FTree;
    procedure CheckConsistency; override;
  end;

  { TAnchorDockLayoutTree }

  TAnchorDockLayoutTree = class
  private
    FChangeStamp: int64;
    FSavedChangeStamp: int64;
    FRoot: TAnchorDockLayoutTreeRootNode;
    function GetModified: boolean;
    procedure SetModified(const AValue: boolean);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(Source: TObject);
    procedure LoadFromConfig(Config: TConfigStorage); overload;
    procedure LoadFromConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure SaveToConfig(Config: TConfigStorage); overload;
    procedure SaveToConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure IncreaseChangeStamp;
    property ChangeStamp: int64 read FChangeStamp;
    property Modified: boolean read GetModified write SetModified;
    property Root: TAnchorDockLayoutTreeRootNode read FRoot;
    function NewNode(aParent: TAnchorDockLayoutTreeNode): TAnchorDockLayoutTreeNode;
  end;

  { TAnchorDockRestoreLayout }

  TAnchorDockRestoreLayout = class
  private
    FControlNames: TStrings;
    FLayout: TAnchorDockLayoutTree;
    procedure SetControlNames(const AValue: TStrings);
  public
    constructor Create; overload;
    constructor Create(aLayout: TAnchorDockLayoutTree); overload;
    destructor Destroy; override;
    procedure Assign(Source: TAnchorDockRestoreLayout);
    function IndexOfControlName(AName: string): integer;
    function HasControlName(AName: string): boolean;
    procedure RemoveControlName(AName: string);
    procedure UpdateControlNames;
    procedure LoadFromConfig(Config: TConfigStorage); overload;
    procedure LoadFromConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure SaveToConfig(Config: TConfigStorage); overload;
    procedure SaveToConfig(Path: string; Config: TRttiXMLConfig); overload;
    property ControlNames: TStrings read FControlNames write SetControlNames;
    property Layout: TAnchorDockLayoutTree read FLayout;
  end;

  { TAnchorDockRestoreLayouts }

  TAnchorDockRestoreLayouts = class
  private
    fItems: TFPList;
    function GetItems(Index: integer): TAnchorDockRestoreLayout;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Assign(Source: TAnchorDockRestoreLayouts);
    procedure Delete(Index: integer);
    function IndexOfName(AControlName: string): integer;
    function FindByName(AControlName: string): TAnchorDockRestoreLayout;
    procedure Add(Layout: TAnchorDockRestoreLayout; RemoveOther: boolean);
    procedure RemoveByName(AControlName: string);
    procedure LoadFromConfig(Config: TConfigStorage); overload;
    procedure LoadFromConfig(Path: string; Config: TRttiXMLConfig); overload;
    procedure SaveToConfig(Config: TConfigStorage); overload;
    procedure SaveToConfig(Path: string; Config: TRttiXMLConfig); overload;
    function ConfigIsEmpty(Config: TConfigStorage): boolean;
    function Count: integer;
    property Items[Index: integer]: TAnchorDockRestoreLayout read GetItems; default;
  end;

  { TADNameToControl }

  TADNameToControl = class
  private
    fItems: TStringList;
    function IndexOfName(const aName: string): integer;
    function GetControl(const aName: string): TControl;
    procedure SetControl(const aName: string; const AValue: TControl);
  public
    constructor Create;
    destructor Destroy; override;
    function ControlToName(AControl: TControl): string;
    property Control[const aName: string]: TControl read GetControl write SetControl; default;
    procedure RemoveControl(AControl: TControl);
    procedure WriteDebugReport(Msg: string);
  end;

const
  ADLTreeNodeTypeNames: array[TADLTreeNodeType] of string = (
    'None',
    'Layout',
    'Control',
    'SplitterHorizontal',
    'SplitterVertical',
    'Pages',
    'CustomSite'
    );
  ADLWindowStateNames: array[TWindowState] of string = (
    'Normal',
    'Minimized',
    'Maximized',
    'Fullscreen'
    );
  ADLHeaderPositionNames: array[TADLHeaderPosition] of string = (
    'auto',
    'left',
    'top',
    'right',
    'bottom'
    );
  ADLTabPostionNames: array[TTabPosition] of string = (
    'Top',
    'Bottom',
    'Left',
    'Right'
    );
  ADLAlignNames: array[TAlign] of string = (
    'None',
    'Top',
    'Bottom',
    'Left',
    'Right',
    'Client',
    'Custom'
    );

function NameToADLTreeNodeType(s: string): TADLTreeNodeType;
function NameToADLWindowState(s: string): TWindowState;
function NameToADLHeaderPosition(s: string): TADLHeaderPosition;
function NameToADLTabPosition(s: string): TTabPosition;
function NameToADLAlign(s: string): TAlign;
function dbgs(const NodeType: TADLTreeNodeType): string; overload;

procedure WriteDebugLayout(Title: string; RootNode: TObject);
function DebugLayoutAsString(RootNode: TObject): string;
procedure DebugWriteChildAnchors(RootNode: TAnchorDockLayoutTreeNode); overload;
procedure DebugWriteChildAnchors(RootControl: TWinControl;
                                 OnlyWinControls, OnlyForms: boolean); overload;

implementation

function NameToADLTreeNodeType(s: string): TADLTreeNodeType;
begin
  for Result:=low(TADLTreeNodeType) to high(TADLTreeNodeType) do
    if s=ADLTreeNodeTypeNames[Result] then exit;
  Result:=adltnNone;
end;

function NameToADLWindowState(s: string): TWindowState;
begin
  for Result:=low(TWindowState) to high(TWindowState) do
    if s=ADLWindowStateNames[Result] then exit;
  Result:=wsNormal;
end;

function NameToADLHeaderPosition(s: string): TADLHeaderPosition;
begin
  for Result:=low(TADLHeaderPosition) to high(TADLHeaderPosition) do
    if s=ADLHeaderPositionNames[Result] then exit;
  Result:=adlhpAuto;
end;

function NameToADLTabPosition(s: string): TTabPosition;
begin
  for Result:=low(TTabPosition) to high(TTabPosition) do
    if s=ADLTabPostionNames[Result] then exit;
  Result:=tpTop;
end;

function NameToADLAlign(s: string): TAlign;
begin
  for Result:=low(TAlign) to high(TAlign) do
    if s=ADLAlignNames[Result] then exit;
  Result:=alNone;
end;

function dbgs(const NodeType: TADLTreeNodeType): string; overload;
begin
  Result:=ADLTreeNodeTypeNames[NodeType];
end;

procedure WriteDebugLayout(Title: string; RootNode: TObject);
begin
  debugln(['WriteDebugLayout ',Title,':']);
  debugln(DebugLayoutAsString(RootNode));
end;

function DebugLayoutAsString(RootNode: TObject): string;
type
  TNodeInfo = record
    MinSize: TPoint;
    MinSizeValid, MinSizeCalculating: boolean;
    MinLeft: integer;
    MinLeftValid, MinLeftCalculating: boolean;
    MinTop: Integer;
    MinTopValid, MinTopCalculating: boolean;
  end;
  PNodeInfo = ^TNodeInfo;
var
  Cols: LongInt;
  Rows: LongInt;
  LogCols: Integer;
  NodeInfos: TPointerToPointerTree;// TObject to PNodeInfo

  procedure InitNodeInfos;
  begin
    NodeInfos:=TPointerToPointerTree.Create;
  end;

  procedure FreeNodeInfos;
  var
    Item: PNodeInfo;
    NodePtr, InfoPtr: Pointer;
  begin
    NodeInfos.GetFirst(NodePtr,InfoPtr);
    repeat
      Item:=PNodeInfo(InfoPtr);
      if Item=nil then break;
      Dispose(Item);
    until not NodeInfos.GetNext(NodePtr,NodePtr,InfoPtr);
    NodeInfos.Free;
  end;

  function GetNodeInfo(Node: TObject): PNodeInfo;
  begin
    Result:=PNodeInfo(NodeInfos[Node]);
    if Result=nil then begin
      New(Result);
      FillChar(Result^,SizeOf(TNodeInfo),0);
      NodeInfos[Node]:=Result;
    end;
  end;

  procedure w(x,y: Integer; const s: string; MaxX: Integer = 0);
  var
    i: Integer;
  begin
    for i:=1 to length(s) do begin
      if (MaxX>0) and (x+i>MaxX) then exit;
      Result[LogCols*(y-1) + x + i-1]:=s[i];
    end;
  end;

  procedure wfillrect(const ARect: TRect; c: char);
  var
    x: LongInt;
    y: LongInt;
  begin
    for x:=ARect.Left to ARect.Right do
      for y:=ARect.Top to ARect.Bottom do
        w(x,y,c);
  end;

  procedure wrectangle(const ARect: TRect);
  begin
    w(ARect.Left,ARect.Top,'+');
    w(ARect.Right,ARect.Top,'+');
    w(ARect.Left,ARect.Bottom,'+');
    w(ARect.Right,ARect.Bottom,'+');
    if ARect.Left<ARect.Right then begin
      if ARect.Top<ARect.Bottom then begin
        wfillrect(Rect(ARect.Left+1,ARect.Top,ARect.Right-1,ARect.Top),'-');// top line
        wfillrect(Rect(ARect.Left+1,ARect.Bottom,ARect.Right-1,ARect.Bottom),'-');// bottom line
        wfillrect(Rect(ARect.Left,ARect.Top+1,ARect.Left,ARect.Bottom-1),'|');// left line
        wfillrect(Rect(ARect.Right,ARect.Top+1,ARect.Right,ARect.Bottom-1),'|');// right line
      end else begin
        wfillrect(Rect(ARect.Left+1,ARect.Top,ARect.Right-1,ARect.Top),'=');// horizontal line
      end;
    end else begin
      wfillrect(Rect(ARect.Left,ARect.Top+1,ARect.Left,ARect.Bottom-1),'#');// vertical line
    end;
  end;

  function MapRect(const OriginalRect, OldBounds, NewBounds: TRect): TRect;

    function MapX(i: Integer): Integer;
    begin
      Result:=NewBounds.Left+
        (((i-OldBounds.Left)*(NewBounds.Right-NewBounds.Left))
         div (OldBounds.Right-OldBounds.Left));
    end;

    function MapY(i: Integer): Integer;
    begin
      Result:=NewBounds.Top+
        (((i-OldBounds.Top)*(NewBounds.Bottom-NewBounds.Top))
         div (OldBounds.Bottom-OldBounds.Top));
    end;

  begin
    Result.Left:=MapX(OriginalRect.Left);
    Result.Top:=MapY(OriginalRect.Left);
    Result.Right:=MapX(OriginalRect.Left);
    Result.Bottom:=MapY(OriginalRect.Left);
  end;

  function GetParentNode(Node: TObject): TObject;
  begin
    if Node is TControl then
      Result:=TControl(Node).Parent
    else if Node is TAnchorDockLayoutTreeNode then
      Result:=TAnchorDockLayoutTreeNode(Node).Parent
    else
      Result:=nil;
  end;

  function GetSiblingNode(Node: TObject; Side: TAnchorKind): TObject;
  begin
    Result:=nil;
    if Node=nil then exit;
    if Node is TControl then begin
      if not (Side in TControl(Node).Anchors) then exit;
      Result:=TControl(Node).AnchorSide[Side].Control;
      if Result=TControl(Node).Parent then
        Result:=nil;
    end else if Node is TAnchorDockLayoutTreeNode then begin
      if TAnchorDockLayoutTreeNode(Node).Parent<>nil then
        Result:=TAnchorDockLayoutTreeNode(Node).Parent.FindChildNode(
          TAnchorDockLayoutTreeNode(Node).Anchors[Side],false);
    end;
  end;

  function GetAnchorNode(Node: TObject; Side: TAnchorKind): TObject;
  var
    ADLNode: TAnchorDockLayoutTreeNode;
  begin
    Result:=nil;
    if Node=nil then exit;
    if Node is TControl then begin
      if not (Side in TControl(Node).Anchors) then exit;
      Result:=TControl(Node).AnchorSide[Side].Control;
    end else if Node is TAnchorDockLayoutTreeNode then begin
      ADLNode:=TAnchorDockLayoutTreeNode(Node);
      if ((ADLNode.NodeType=adltnSplitterVertical)
          and (Side in [akLeft,akRight]))
      or ((ADLNode.NodeType=adltnSplitterHorizontal)
          and (Side in [akTop,akBottom]))
      then
        Result:=nil
      else if (ADLNode.Anchors[Side]<>'') then begin
        if ADLNode.Parent<>nil then
          Result:=ADLNode.Parent.FindChildNode(
            ADLNode.Anchors[Side],false);
      end else
        Result:=GetParentNode(Node);
    end;
  end;

  function IsSplitter(Node: TObject): boolean;
  begin
    Result:=(Node is TCustomSplitter)
      or ((Node is TAnchorDockLayoutTreeNode)
          and (TAnchorDockLayoutTreeNode(Node).IsSplitter));
  end;

  function IsPages(Node: TObject): boolean;
  begin
    Result:=(Node is TCustomTabControl)
      or ((Node is TAnchorDockLayoutTreeNode)
          and (TAnchorDockLayoutTreeNode(Node).NodeType in [adltnPages,adltnNone]));
  end;

  function GetName(Node: TObject): string;
  begin
    if Node is TControl then
      Result:=TControl(Node).Name
    else if Node is TAnchorDockLayoutTreeNode then
      Result:=TAnchorDockLayoutTreeNode(Node).Name
    else
      Result:=DbgSName(Node);
  end;

  function GetChildCount(Node: TObject): integer;
  begin
    if Node is TWinControl then
      Result:=TWinControl(Node).ControlCount
    else if Node is TAnchorDockLayoutTreeNode then
      Result:=TAnchorDockLayoutTreeNode(Node).Count
    else
      Result:=0;
  end;

  function GetChild(Node: TObject; Index: integer): TObject;
  begin
    if Node is TWinControl then
      Result:=TWinControl(Node).Controls[Index]
    else if Node is TAnchorDockLayoutTreeNode then
      Result:=TAnchorDockLayoutTreeNode(Node).Nodes[Index]
    else
      Result:=nil;
  end;

  function GetMinSize(Node: TObject): TPoint; forward;

  function GetMinPos(Node: TObject; Side: TAnchorKind): Integer;
  // calculates left or top position of Node

    function Compute(var MinPosValid, MinPosCalculating: boolean;
      var MinPos: Integer): Integer;

      procedure Improve(Neighbour: TObject);
      var
        NeighbourPos: LongInt;
        NeighbourSize: TPoint;
        NeighbourLength: LongInt;
      begin
        if Neighbour=nil then exit;
        if GetParentNode(Neighbour)<>GetParentNode(Node) then exit;
        NeighbourPos:=GetMinPos(Neighbour,Side);
        NeighbourSize:=GetMinSize(Neighbour);
        if Side=akLeft then
          NeighbourLength:=NeighbourSize.X
        else
          NeighbourLength:=NeighbourSize.Y;
        MinPos:=Max(MinPos,NeighbourPos+NeighbourLength);
      end;

    var
      Sibling: TObject;
      i: Integer;
      ParentNode: TObject;
    begin
      if MinPosCalculating then begin
        DebugLn(['DebugLayoutAsString.GetMinPos.Compute WARNING: anchor circle detected RootNode=',DbgSName(RootNode)]);
        if RootNode is TWinControl then
          DebugWriteChildAnchors(TWinControl(RootNode),true,true)
        else if RootNode is TAnchorDockLayoutTreeNode then
          DebugWriteChildAnchors(TAnchorDockLayoutTreeNode(RootNode));
        RaiseGDBException('circle detected');
      end;
      if (not MinPosValid) then begin
        MinPosValid:=true;
        MinPosCalculating:=true;
        Sibling:=GetSiblingNode(Node,Side);
        if Sibling<>nil then
          Improve(Sibling);
        ParentNode:=GetParentNode(Node);
        if ParentNode<>nil then begin
          for i:=0 to GetChildCount(ParentNode)-1 do begin
            Sibling:=GetChild(ParentNode,i);
            if Node=GetSiblingNode(Sibling,OppositeAnchor[Side]) then
              Improve(Sibling);
          end;
        end;
        MinPosCalculating:=false;
      end;
      Result:=MinPos;
    end;

  var
    Info: PNodeInfo;
  begin
    Info:=GetNodeInfo(Node);
    //DebugLn(['GetMinPos ',Node.Name,' ',DbgS(Side),' ',Info^.MinLeftCalculating]);
    if Side=akLeft then
      Result:=Compute(Info^.MinLeftValid,Info^.MinLeftCalculating,Info^.MinLeft)
    else
      Result:=Compute(Info^.MinTopValid,Info^.MinTopCalculating,Info^.MinTop);
  end;

  function GetChildsMinSize(Node: TObject): TPoint;
  // calculate the minimum size needed to draw the content of the node
  var
    i: Integer;
    Child: TObject;
    ChildMinSize: TPoint;
  begin
    //DebugLn(['GetChildsMinSize ',Node.name]);
    Result:=Point(0,0);
    if IsPages(Node) then begin
      // maximum size of all pages
      for i:=0 to GetChildCount(Node)-1 do begin
        ChildMinSize:=GetMinSize(GetChild(Node,i));
        Result.X:=Max(Result.X,ChildMinSize.X);
        Result.Y:=Max(Result.Y,ChildMinSize.Y);
      end;
    end else begin
      for i:=0 to GetChildCount(Node)-1 do begin
        Child:=GetChild(Node,i);
        ChildMinSize:=GetMinSize(Child);
        Result.X:=Max(Result.X,GetMinPos(Child,akLeft)+ChildMinSize.X);
        Result.Y:=Max(Result.Y,GetMinPos(Child,akTop)+ChildMinSize.Y);
      end;
    end;
  end;

  function GetMinSize(Node: TObject): TPoint;
  // calculate the minimum size needed to draw the node
  var
    ChildMinSize: TPoint;
    Info: PNodeInfo;
  begin
    //DebugLn(['GetMinSize ',Node.name]);
    Info:=GetNodeInfo(Node);
    if Info^.MinSizeValid then begin
      Result:=Info^.MinSize;
      exit;
    end;
    if Info^.MinSizeCalculating then begin
      DebugLn(['DebugLayoutAsString.GetMinSize WARNING: anchor circle detected']);
      DumpStack;
      Result:=Point(1,1);
      exit;
    end;
    Info^.MinSizeCalculating:=true;
    Result.X:=2+length(GetName(Node));// border plus name
    Result.Y:=2;  // border
    if GetChildCount(Node)=0 then begin
      if IsSplitter(Node) then
        Result:=Point(1,1); // splitters don't need captions
    end else begin
      ChildMinSize:=GetChildsMinSize(Node);
      Result.X:=Max(Result.X,ChildMinSize.X+2);
      Result.Y:=Max(Result.Y,ChildMinSize.Y+2);
    end;
    //debugln(['GetMinSize ',GetName(Node),' Splitter=',IsSplitter(Node),' MinSize=',dbgs(Result)]);
    Info^.MinSize:=Result;
    Info^.MinSizeValid:=true;
    Info^.MinSizeCalculating:=false;
  end;

  procedure DrawNode(Node: TObject; ARect: TRect);
  var
    i: Integer;
    Child: TObject;
    ChildSize: TPoint;
    ChildRect: TRect;
    AnchorNode: TObject;
  begin
    DebugLn(['DrawNode Node=',GetName(Node),' ARect=',dbgs(ARect)]);
    wrectangle(ARect);
    w(ARect.Left+1,ARect.Top,GetName(Node),ARect.Right);

    for i := 0 to GetChildCount(Node)-1 do begin
      Child:=GetChild(Node,i);
      ChildRect.Left:=ARect.Left+1+GetMinPos(Child,akLeft);
      ChildRect.Top:=ARect.Top+1+GetMinPos(Child,akTop);
      ChildSize:=GetMinSize(Child);
      ChildRect.Right:=ChildRect.Left+ChildSize.X-1;
      ChildRect.Bottom:=ChildRect.Top+ChildSize.Y-1;
      AnchorNode:=GetAnchorNode(Child,akRight);
      if AnchorNode<>nil then begin
        if AnchorNode=Node then
          ChildRect.Right:=ARect.Right-1
        else if GetParentNode(AnchorNode)=Node then
          ChildRect.Right:=ARect.Left+1+GetMinPos(AnchorNode,akLeft)-1;
      end;
      AnchorNode:=GetAnchorNode(Child,akBottom);
      if AnchorNode<>nil then begin
        if AnchorNode=Node then
          ChildRect.Bottom:=ARect.Bottom-1
        else if GetParentNode(AnchorNode)=Node then
          ChildRect.Bottom:=ARect.Top+1+GetMinPos(AnchorNode,akTop)-1;
      end;
      DrawNode(Child,ChildRect);
      if IsPages(Node) then begin
        // paint only one page
        break;
      end;
    end;
  end;

var
  e: string;
  y: Integer;
begin
  Cols:=StrToIntDef(Application.GetOptionValue('ldcn-colunms'),79);
  Rows:=StrToIntDef(Application.GetOptionValue('ldcn-rows'),20);

  InitNodeInfos;
  try
    e:=LineEnding;
    LogCols:=Cols+length(e);
    SetLength(Result,LogCols*Rows);
    // fill space
    FillChar(Result[1],length(Result),' ');
    // add line endings
    for y:=1 to Rows do
      w(Cols+1,y,e);
    // draw node
    DrawNode(RootNode,Rect(1,1,Cols,Rows));
  finally
    FreeNodeInfos;
  end;
end;

procedure DebugWriteChildAnchors(RootNode: TAnchorDockLayoutTreeNode);

  procedure WriteControl(Node: TAnchorDockLayoutTreeNode; Prefix: string);
  var
    i: Integer;
    a: TAnchorKind;
    AnchorControl: TAnchorDockLayoutTreeNode;
    AnchorName: String;
  begin
    DbgOut(Prefix);
    DbgOut('"'+Node.Name+'"');
    DbgOut(' Type='+dbgs(Node.NodeType));
    DbgOut(' Bounds=',dbgs(Node.BoundsRect)
              ,',w=',dbgs(Node.BoundsRect.Right-Node.BoundsRect.Left)
              ,',h=',dbgs(Node.BoundsRect.Bottom-Node.BoundsRect.Top));
    if Node.WindowState<>wsNormal then
      DbgOut(' WindowState=',dbgs(Node.WindowState));
    if Node.Monitor<>0 then
      DbgOut(' Monitor=',dbgs(Node.Monitor));
    if Node.BoundSplitterPos<>0 then
      DbgOut(' SplitterPos=',dbgs(Node.BoundSplitterPos));
    if Node.PixelsPerInch<>0 then
      DbgOut(' PixelsPerInch=',dbgs(Node.PixelsPerInch));
    if (Node.WorkAreaRect.Right>0) and (Node.WorkAreaRect.Bottom>0) then
      DbgOut(' WorkArea=',dbgs(Node.WorkAreaRect));
    debugln;
    for a:=low(TAnchorKind) to high(TAnchorKind) do begin
      if Node.Anchors[a]<>'' then
        AnchorControl:=Node.Parent.FindChildNode(Node.Anchors[a],False)
      else
        AnchorControl:=nil;
      if AnchorControl=nil then
        AnchorName:='Parent'
      else
        AnchorName:=AnchorControl.Name;
      debugln([Prefix,'  ',dbgs(a),'=',AnchorName]);
    end;
    for i:=0 to Node.Count-1 do
      WriteControl(Node[i],Prefix+'  ');
  end;

var
  i: Integer;
begin
  debugln(['DebugWriteChildAnchors RootNode="',RootNode.Name,'" Type=',dbgs(RootNode.NodeType)]);
  for i:=0 to RootNode.Count-1 do
    WriteControl(RootNode[i],'  ');
end;

procedure DebugWriteChildAnchors(RootControl: TWinControl;
  OnlyWinControls, OnlyForms: boolean); overload;

  procedure WriteControl(AControl: TControl; Prefix: string);
  var
    i: Integer;
    a: TAnchorKind;
    AnchorControl: TControl;
    AnchorName: String;
  begin
    if OnlyWinControls and (not (AControl is TWinControl)) then exit;
    if OnlyForms and (not (AControl is TCustomForm)) then exit;
    if not AControl.IsControlVisible then exit;

    debugln([Prefix,DbgSName(AControl),' Caption="',dbgstr(AControl.Caption),'" Align=',dbgs(AControl.Align),' Bounds=',dbgs(AControl.BoundsRect)]);
    for a:=low(TAnchorKind) to high(TAnchorKind) do begin
      AnchorControl:=AControl.AnchorSide[a].Control;
      if AnchorControl=AControl.Parent then
        AnchorName:='Parent'
      else if AnchorControl is TCustomForm then
        AnchorName:='"'+AnchorControl.Name+'"'
      else
        AnchorName:=DbgSName(AnchorControl);
      debugln([Prefix,'  ',dbgs(a),'=',a in AControl.Anchors,' ',AnchorName,' ',dbgs(a,AControl.AnchorSide[a].Side)]);
    end;
    if AControl is TWinControl then begin
      for i:=0 to TWinControl(AControl).ControlCount-1 do
        WriteControl(TWinControl(AControl).Controls[i],Prefix+'  ');
    end;
  end;

var
  i: Integer;
begin
  debugln(['WriteChildAnchors ',DbgSName(RootControl),' Caption="',RootControl.Caption,'" Align=',dbgs(RootControl.Align)]);
  for i:=0 to RootControl.ControlCount-1 do
    WriteControl(RootControl.Controls[i],'  ');
end;

{ TAnchorDockLayoutTreeNode }

function TAnchorDockLayoutTreeNode.GetNodes(Index: integer
  ): TAnchorDockLayoutTreeNode;
begin
  Result:=TAnchorDockLayoutTreeNode(FNodes[Index]);
end;

function TAnchorDockLayoutTreeNode.GetRight: integer;
begin
  Result:=FBoundsRect.Right;
end;

function TAnchorDockLayoutTreeNode.GetHeight: integer;
begin
  Result:=FBoundsRect.Bottom-FBoundsRect.Top;
end;

function TAnchorDockLayoutTreeNode.GetBottom: integer;
begin
  Result:=FBoundsRect.Bottom;
end;

function TAnchorDockLayoutTreeNode.GetAnchors(Site: TAnchorKind): string;
begin
  Result:=fAnchors[Site];
end;

function TAnchorDockLayoutTreeNode.GetLeft: integer;
begin
  Result:=FBoundsRect.Left;
end;

function TAnchorDockLayoutTreeNode.GetTop: integer;
begin
  Result:=FBoundsRect.Top;
end;

function TAnchorDockLayoutTreeNode.GetWidth: integer;
begin
  Result:=FBoundsRect.Right-FBoundsRect.Left;
end;

procedure TAnchorDockLayoutTreeNode.SetAlign(const AValue: TAlign);
begin
  if FAlign=AValue then exit;
  FAlign:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetAnchors(Site: TAnchorKind;
  const AValue: string);
begin
  if Anchors[Site]=AValue then exit;
  fAnchors[Site]:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetBottom(const AValue: integer);
begin
  if GetBottom=AValue then exit;
  FBoundsRect.Bottom:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetBoundSplitterPos(const AValue: integer);
begin
  if FBoundSplitterPos=AValue then exit;
  FBoundSplitterPos:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetBoundsRect(const AValue: TRect);
begin
  if CompareRect(@FBoundsRect,@AValue) then exit;
  FBoundsRect:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetHeaderPosition(
  const AValue: TADLHeaderPosition);
begin
  if FHeaderPosition=AValue then exit;
  FHeaderPosition:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetHeight(const AValue: integer);
begin
  if Height=AValue then exit;
  FBoundsRect.Bottom:=FBoundsRect.Top+AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetLeft(const AValue: integer);
begin
  if Left=AValue then exit;
  FBoundsRect.Left:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetMonitor(const AValue: integer);
begin
  if FMonitor=AValue then exit;
  FMonitor:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetName(const AValue: string);
begin
  if FName=AValue then exit;
  FName:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetNodeType(const AValue: TADLTreeNodeType);
begin
  if FNodeType=AValue then exit;
  FNodeType:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetPageIndex(AValue: integer);
begin
  if FPageIndex = AValue then Exit;
  FPageIndex := AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetParent(
  const AValue: TAnchorDockLayoutTreeNode);
begin
  if FParent=AValue then exit;
  if FParent<>nil then begin
    FParent.FNodes.Remove(Self);
    FParent.IncreaseChangeStamp;
  end;
  FParent:=AValue;
  if FParent<>nil then
    FParent.FNodes.Add(Self);
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetPixelsPerInch(AValue: Integer);
begin
  if FPixelsPerInch=AValue then Exit;
  FPixelsPerInch:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetRight(const AValue: integer);
begin
  if Right=AValue then exit;
  FBoundsRect.Right:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetWorkAreaRect(const AValue: TRect);
begin
  if CompareRect(@FWorkAreaRect,@AValue) then exit;
  FWorkAreaRect:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetTabPosition(const AValue: TTabPosition);
begin
  if FTabPosition=AValue then exit;
  FTabPosition:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetMinimized(const AValue: boolean);
begin
  if FMinimized=AValue then exit;
  FMinimized:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetTop(const AValue: integer);
begin
  if Top=AValue then exit;
  FBoundsRect.Top:=AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetWidth(const AValue: integer);
begin
  if Width=AValue then exit;
  FBoundsRect.Right:=FBoundsRect.Left+AValue;
  IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeNode.SetWindowState(const AValue: TWindowState);
begin
  if FWindowState=AValue then exit;
  FWindowState:=AValue;
  IncreaseChangeStamp;
end;

constructor TAnchorDockLayoutTreeNode.Create;
begin
  FNodes:=TFPList.Create;
  FControlLocation:=adlclwrongly;//control located wrongly by default
end;

destructor TAnchorDockLayoutTreeNode.Destroy;
begin
  Parent:=nil;
  Clear;
  FreeAndNil(FNodes);
  inherited Destroy;
end;

procedure TAnchorDockLayoutTreeNode.Clear;
var
  a: TAnchorKind;
begin
  Name:='';
  FillByte(FBoundsRect,sizeOf(FBoundsRect),0);
  while Count>0 do Nodes[Count-1].Free;
  NodeType:=adltnNone;
  WindowState:=wsNormal;
  Monitor:=0;
  Align:=alNone;
  HeaderPosition:=adlhpAuto;
  TabPosition:=tpTop;
  PageIndex:=0;
  BoundSplitterPos:=0;
  PixelsPerInch:=96;
  WorkAreaRect:=Rect(0,0,0,0);
  for a:=low(TAnchorKind) to high(TAnchorKind) do
    Anchors[a]:='';
end;

function TAnchorDockLayoutTreeNode.IsEqual(Node: TAnchorDockLayoutTreeNode
  ): boolean;
var
  i: Integer;
  a: TAnchorKind;
begin
  Result:=false;
  if (not CompareRect(@FBoundsRect,@Node.FBoundsRect))
  or (Count<>Node.Count)
  or (NodeType<>Node.NodeType)
  or (Name<>Node.Name)
  or (Align<>Node.Align)
  or (WindowState<>Node.WindowState)
  or (HeaderPosition<>Node.HeaderPosition)
  or (TabPosition<>Node.TabPosition)
  or (PageIndex<>Node.PageIndex)
  or (BoundSplitterPos<>Node.BoundSplitterPos)
  or (PixelsPerInch<>Node.PixelsPerInch)
  or (not CompareRect(@FWorkAreaRect,@Node.FWorkAreaRect))
  then
    exit;
  for a:=low(TAnchorKind) to high(TAnchorKind) do
    if Anchors[a]<>Node.Anchors[a] then exit;
  for i:=0 to Count-1 do
    if not Nodes[i].IsEqual(Node.Nodes[i]) then exit;
  Result:=true;
end;

procedure TAnchorDockLayoutTreeNode.Assign(Node: TAnchorDockLayoutTreeNode);
var
  i: Integer;
  Child: TAnchorDockLayoutTreeNode;
  a: TAnchorKind;
begin
  Name:=Node.Name;
  NodeType:=Node.NodeType;
  BoundsRect:=Node.BoundsRect;
  Align:=Node.Align;
  WindowState:=Node.WindowState;
  HeaderPosition:=Node.HeaderPosition;
  TabPosition:=Node.TabPosition;
  PageIndex:=Node.PageIndex;
  BoundSplitterPos:=Node.BoundSplitterPos;
  PixelsPerInch:=Node.PixelsPerInch;
  WorkAreaRect:=Node.WorkAreaRect;
  Monitor:=Node.Monitor;
  Minimized:=Node.Minimized;
  for a:=low(TAnchorKind) to high(TAnchorKind) do
    Anchors[a]:=Node.Anchors[a];
  while Count>Node.Count do Nodes[Count-1].Free;
  for i:=0 to Node.Count-1 do begin
    if i=Count then begin
      Child:=TAnchorDockLayoutTreeNode.Create;
      Child.Parent:=Self;
    end else begin
      Child:=Nodes[i];
    end;
    Child.Assign(Node.Nodes[i]);
  end;
end;

procedure TAnchorDockLayoutTreeNode.Assign(AControl: TControl; OverrideBoundsRect, AMinimized: boolean);
var
  AnchorControl: TControl;
  ParentForm: TCustomForm;
  a: TAnchorKind;
begin
  Name:=AControl.Name;
  if OverrideBoundsRect then
    BoundsRect:=GetParentForm(AControl).BoundsRect
  else
    BoundsRect:=AControl.BoundsRect;
  Align:=AControl.Align;
  Minimized:=AMinimized;
  if (AControl.Parent=nil) and (AControl is TCustomForm) then begin
    WindowState:=TCustomForm(AControl).WindowState;
    Monitor:=TCustomForm(AControl).Monitor.MonitorNum;
    PixelsPerInch:=TCustomForm(AControl).PixelsPerInch;
    WorkAreaRect:=TCustomForm(AControl).Monitor.WorkareaRect;
  end else begin
    ParentForm:=GetParentForm(AControl);
    if Assigned(ParentForm) then
      WindowState:=ParentForm.WindowState
    else
      WindowState:=wsNormal;
  end;
  if AControl is TCustomTabControl then begin
    TabPosition:=TCustomTabControl(AControl).TabPosition;
    PageIndex:=TCustomTabControl(AControl).PageIndex;
  end else begin
    TabPosition:=tpTop;
    PageIndex:=0;
  end;
  for a:=low(TAnchorKind) to high(TAnchorKind) do begin
    AnchorControl:=AControl.AnchorSide[a].Control;
    if (AnchorControl=nil) or (AnchorControl=AControl.Parent) then
      Anchors[a]:=''
    else if AnchorControl.Parent=AControl.Parent then
      Anchors[a]:=AnchorControl.Name;
  end;
end;

procedure TAnchorDockLayoutTreeNode.LoadFromConfig(Config: TConfigStorage);
var
  i: Integer;
  Child: TAnchorDockLayoutTreeNode;
  NewCount: longint;
begin
  Clear;
  Name:=Config.GetValue('Name','');
  NodeType:=NameToADLTreeNodeType(Config.GetValue('Type',ADLTreeNodeTypeNames[adltnNone]));
  Minimized:=Config.GetValue('Minimized',false);
  Left:=Config.GetValue('Bounds/Left',0);
  Top:=Config.GetValue('Bounds/Top',0);
  Width:=Config.GetValue('Bounds/Width',0);
  Height:=Config.GetValue('Bounds/Height',0);
  BoundSplitterPos:=Config.GetValue('Bounds/SplitterPos',0);
  Config.GetValue('Bounds/WorkArea/Rect/',FWorkAreaRect,Rect(0,0,0,0));
  Anchors[akLeft]:=Config.GetValue('Anchors/Left','');
  Anchors[akTop]:=Config.GetValue('Anchors/Top','');
  Anchors[akRight]:=Config.GetValue('Anchors/Right','');
  Anchors[akBottom]:=Config.GetValue('Anchors/Bottom','');
  Align:=NameToADLAlign(Config.GetValue('Anchors/Align',dbgs(alNone)));
  WindowState:=NameToADLWindowState(Config.GetValue('WindowState',ADLWindowStateNames[wsNormal]));
  HeaderPosition:=NameToADLHeaderPosition(Config.GetValue('Header/Position',ADLHeaderPositionNames[adlhpAuto]));
  TabPosition:=NameToADLTabPosition(Config.GetValue('Header/TabPosition',ADLTabPostionNames[tpTop]));
  PageIndex:=Config.GetValue('Header/PageIndex',0);
  Monitor:=Config.GetValue('Monitor',0);
  NewCount:=Config.GetValue('ChildCount',0);
  PixelsPerInch:=Config.GetValue('PixelsPerInch',96);
  for i:=1 to NewCount do begin
    Config.AppendBasePath('Item'+IntToStr(i)+'/');
    Child:=TAnchorDockLayoutTreeNode.Create;
    Child.Parent:=Self;
    Child.LoadFromConfig(Config);
    Config.UndoAppendBasePath;
  end;
end;

procedure TAnchorDockLayoutTreeNode.LoadFromConfig(Path: string; Config: TRttiXMLConfig);
var
  i: Integer;
  Child: TAnchorDockLayoutTreeNode;
  NewCount: longint;
begin
  Clear;
  Name:=Config.GetValue(Path+'Name','');
  NodeType:=NameToADLTreeNodeType(Config.GetValue(Path+'Type',ADLTreeNodeTypeNames[adltnNone]));
  Minimized:=Config.GetValue(Path+'Minimized',false);
  Left:=Config.GetValue(Path+'Bounds/Left',0);
  Top:=Config.GetValue(Path+'Bounds/Top',0);
  Width:=Config.GetValue(Path+'Bounds/Width',0);
  Height:=Config.GetValue(Path+'Bounds/Height',0);
  BoundSplitterPos:=Config.GetValue(Path+'Bounds/SplitterPos',0);
  Config.GetValue(Path+'Bounds/WorkArea/Rect/',FWorkAreaRect,Rect(0,0,0,0));
  Anchors[akLeft]:=Config.GetValue(Path+'Anchors/Left','');
  Anchors[akTop]:=Config.GetValue(Path+'Anchors/Top','');
  Anchors[akRight]:=Config.GetValue(Path+'Anchors/Right','');
  Anchors[akBottom]:=Config.GetValue(Path+'Anchors/Bottom','');
  Align:=NameToADLAlign(Config.GetValue(Path+'Anchors/Align',dbgs(alNone)));
  WindowState:=NameToADLWindowState(Config.GetValue(Path+'WindowState',ADLWindowStateNames[wsNormal]));
  HeaderPosition:=NameToADLHeaderPosition(Config.GetValue(Path+'Header/Position',ADLHeaderPositionNames[adlhpAuto]));
  TabPosition:=NameToADLTabPosition(Config.GetValue(Path+'Header/TabPosition',ADLTabPostionNames[tpTop]));
  PageIndex:=Config.GetValue(Path+'Header/PageIndex',0);
  Monitor:=Config.GetValue(Path+'Monitor',0);
  NewCount:=Config.GetValue(Path+'ChildCount',0);
  PixelsPerInch:=Config.GetValue(Path+'PixelsPerInch',96);
  for i:=1 to NewCount do
  begin
    Child:=TAnchorDockLayoutTreeNode.Create;
    Child.Parent:=Self;
    Child.LoadFromConfig(Path+'Item'+IntToStr(i)+'/', Config);
  end;
end;

procedure TAnchorDockLayoutTreeNode.SaveToConfig(Config: TConfigStorage);
var
  i: Integer;
begin
  Config.SetDeleteValue('Name',Name,'');
  Config.SetDeleteValue('Type',ADLTreeNodeTypeNames[NodeType],
                               ADLTreeNodeTypeNames[adltnNone]);
  Config.SetDeleteValue('Bounds/Left',Left,0);
  Config.SetDeleteValue('Bounds/Top',Top,0);
  Config.SetDeleteValue('Bounds/Width',Width,0);
  Config.SetDeleteValue('Bounds/Height',Height,0);
  Config.SetDeleteValue('Bounds/SplitterPos',BoundSplitterPos,0);
  Config.SetDeleteValue('Bounds/WorkArea/Rect/',FWorkAreaRect,Rect(0,0,0,0));
  Config.SetDeleteValue('Anchors/Left',Anchors[akLeft],'');
  Config.SetDeleteValue('Anchors/Top',Anchors[akTop],'');
  Config.SetDeleteValue('Anchors/Right',Anchors[akRight],'');
  Config.SetDeleteValue('Anchors/Bottom',Anchors[akBottom],'');
  Config.SetDeleteValue('Anchors/Align',ADLAlignNames[Align],ADLAlignNames[alNone]);
  Config.SetDeleteValue('WindowState',ADLWindowStateNames[WindowState],
                                      ADLWindowStateNames[wsNormal]);
  Config.SetDeleteValue('Header/Position',ADLHeaderPositionNames[HeaderPosition],
                                          ADLHeaderPositionNames[adlhpAuto]);
  Config.SetDeleteValue('Header/TabPosition',ADLTabPostionNames[TabPosition],
                                             ADLTabPostionNames[tpTop]);
  Config.SetDeleteValue('Header/PageIndex',PageIndex,0);
  Config.SetDeleteValue('Minimized',Minimized,False);
  Config.SetDeleteValue('Monitor',Monitor,0);
  Config.SetDeleteValue('ChildCount',Count,0);
  Config.SetDeleteValue('PixelsPerInch',PixelsPerInch,96);
  for i:=1 to Count do begin
    Config.AppendBasePath('Item'+IntToStr(i)+'/');
    Nodes[i-1].SaveToConfig(Config);
    Config.UndoAppendBasePath;
  end;
end;

procedure TAnchorDockLayoutTreeNode.SaveToConfig(Path: string; Config: TRttiXMLConfig);
var
  i: Integer;
begin
  Config.SetDeleteValue(Path+'Name',Name,'');
  Config.SetDeleteValue(Path+'Type',ADLTreeNodeTypeNames[NodeType],
                                    ADLTreeNodeTypeNames[adltnNone]);
  Config.SetDeleteValue(Path+'Bounds/Left',Left,0);
  Config.SetDeleteValue(Path+'Bounds/Top',Top,0);
  Config.SetDeleteValue(Path+'Bounds/Width',Width,0);
  Config.SetDeleteValue(Path+'Bounds/Height',Height,0);
  Config.SetDeleteValue(Path+'Bounds/SplitterPos',BoundSplitterPos,0);
  Config.SetDeleteValue(Path+'Bounds/WorkArea/Rect/',FWorkAreaRect,Rect(0,0,0,0));
  Config.SetDeleteValue(Path+'Anchors/Left',Anchors[akLeft],'');
  Config.SetDeleteValue(Path+'Anchors/Top',Anchors[akTop],'');
  Config.SetDeleteValue(Path+'Anchors/Right',Anchors[akRight],'');
  Config.SetDeleteValue(Path+'Anchors/Bottom',Anchors[akBottom],'');
  Config.SetDeleteValue(Path+'Anchors/Align',ADLAlignNames[Align],ADLAlignNames[alNone]);
  Config.SetDeleteValue(Path+'WindowState',ADLWindowStateNames[WindowState],
                                           ADLWindowStateNames[wsNormal]);
  Config.SetDeleteValue(Path+'Header/Position',ADLHeaderPositionNames[HeaderPosition],
                                               ADLHeaderPositionNames[adlhpAuto]);
  Config.SetDeleteValue(Path+'Header/TabPosition',ADLTabPostionNames[TabPosition],
                                                  ADLTabPostionNames[tpTop]);
  Config.SetDeleteValue(Path+'Header/PageIndex',PageIndex,0);
  Config.SetDeleteValue(Path+'Minimized',Minimized,False);
  Config.SetDeleteValue(Path+'Monitor',Monitor,0);
  Config.SetDeleteValue(Path+'ChildCount',Count,0);
  Config.SetDeleteValue(Path+'PixelsPerInch',PixelsPerInch,96);
  for i:=1 to Count do
    Nodes[i-1].SaveToConfig(Path+'Item'+IntToStr(i)+'/', Config);
end;

function TAnchorDockLayoutTreeNode.FindChildNode(aName: string;
  Recursive: boolean): TAnchorDockLayoutTreeNode;
var
  i: Integer;
begin
  for i:=0 to Count-1 do begin
    Result:=Nodes[i];
    if CompareText(aName,Result.Name)=0 then exit;
    if Recursive then begin
      Result:=Result.FindChildNode(aName,true);
      if Result<>nil then exit;
    end;
  end;
  Result:=nil;
end;

function TAnchorDockLayoutTreeNode.FindControlNode: TAnchorDockLayoutTreeNode;
var
  i: Integer;
begin
  if NodeType=adltnControl then
    Result:=Self
  else
    for i:=0 to Count-1 do begin
      Result:=Nodes[i].FindControlNode;
      if Result<>nil then exit;
    end;
end;

procedure TAnchorDockLayoutTreeNode.CheckConsistency;
{ ToDo: check for topological sort }

  procedure CheckCornerIsUnique(Side1: TAnchorKind; Side1AnchorName: string;
    Side2: TAnchorKind; Side2AnchorName: string);
  var
    i: Integer;
    Child, Found: TAnchorDockLayoutTreeNode;
  begin
    Found:=nil;
    for i:=0 to Count-1 do begin
      Child:=Nodes[i];
      if Child.IsSplitter then continue;
      if CompareText(Child.Anchors[Side1],Side1AnchorName)<>0 then continue;
      if CompareText(Child.Anchors[Side2],Side2AnchorName)<>0 then continue;
      if Found<>nil then
        raise EAnchorDockLayoutError.Create('overlapping controls found :'+Found.Name+','+Child.Name);
      Found:=Child;
    end;
    if Found=nil then
      raise EAnchorDockLayoutError.Create('empty space found :'+Name+' '+dbgs(Side1)+'='+Side1AnchorName+' '+dbgs(Side2)+'='+Side2AnchorName);
  end;

var
  i: Integer;
  Child: TAnchorDockLayoutTreeNode;
  Side: TAnchorKind;
  Sibling: TAnchorDockLayoutTreeNode;
begin
  // check parent
  if (NodeType=adltnNone) and (Parent<>nil) then
    raise EAnchorDockLayoutError.Create('invalid parent, root node');
  if (NodeType=adltnCustomSite) and (Parent<>nil) and (Parent.NodeType<>adltnNone) then
    raise EAnchorDockLayoutError.Create('invalid parent, custom sites parent must be nil');
  if (Parent<>nil) and IsSplitter and (Parent.NodeType<>adltnLayout) then
    raise EAnchorDockLayoutError.Create('invalid parent, splitter needs parent layout');

  // check sides
  for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
    if Anchors[Side]<>'' then begin
      // anchor must be a sibling
      Sibling:=nil;
      if Parent<>nil then
        Sibling:=Parent.FindChildNode(Anchors[Side],false);
      if (Sibling=nil) then
        raise EAnchorDockLayoutError.Create(
          Format(adrsAnchorNotFoundNodeAnchors, [Name, dbgs(Side), Anchors[Side]]));
      // only anchor to splitter
      if not Sibling.IsSplitter then
        raise EAnchorDockLayoutError.Create(
          Format(adrsAnchorIsNotSplitterNodeAnchors, [Name, dbgs(Side), Anchors[Side]]));
      // the free sides of a splitter must not be anchored
      if ((NodeType=adltnSplitterVertical) and (Side in [akLeft,akRight]))
      or ((NodeType=adltnSplitterHorizontal) and (Side in [akTop,akBottom]))
      then
        raise EAnchorDockLayoutError.Create(
          Format(adrsAFreeSideOfASplitterMustNotBeAnchoredNodeTypeAncho,
                 [Name, ADLTreeNodeTypeNames[NodeType], dbgs(Side), Anchors[Side]]));
      // a page must not be anchored
      if (Parent.NodeType=adltnPages) then
        raise EAnchorDockLayoutError.Create(
          Format(adrsAPageMustNotBeAnchoredNodeParentParentTypeAnchors,
            [Name, Parent.Name, ADLTreeNodeTypeNames[Parent.NodeType], dbgs(Side), Anchors[Side]]));
      // check if anchored to the wrong side of a splitter
      if ((Sibling.NodeType=adltnSplitterHorizontal) and (Side in [akLeft,akRight]))
      or ((Sibling.NodeType=adltnSplitterVertical) and (Side in [akTop,akBottom]))
      then
        raise EAnchorDockLayoutError.Create(
          Format(adrsAnchorToWrongSideOfSplitterNodeAnchors, [Name, dbgs(Side), Anchors[Side]]));
    end;
  end;

  // only the root node, pages, layouts and customsite can have children
  if (Parent<>nil) and (Count>0)
  and (not (NodeType in [adltnLayout,adltnPages,adltnCustomSite]))
  then
    raise EAnchorDockLayoutError.Create(
      Format(adrsNoChildrenAllowedForNodeType, [Name, ADLTreeNodeTypeNames[NodeType]]));
  if (NodeType=adltnCustomSite) then begin
    if (Count>1) then
      raise EAnchorDockLayoutError.Create(Format(adrsCustomDockSiteCanHaveOnlyOneSite, [Name]));
  end;

  // check if in each corner sits exactly one child
  if NodeType=adltnLayout then
    for Side:=low(TAnchorKind) to high(TAnchorKind) do
      CheckCornerIsUnique(Side,'',ClockwiseAnchor[Side],'');

  // check grandchild
  for i:=0 to Count-1 do begin
    Child:=Nodes[i];
    Child.CheckConsistency;

    if (Child.NodeType=adltnSplitterHorizontal) then begin
      // check if splitter corners have exactly one sibling
      CheckCornerIsUnique(akLeft,Child.Anchors[akLeft],akTop,Child.Name);
      CheckCornerIsUnique(akLeft,Child.Anchors[akLeft],akBottom,Child.Name);
      CheckCornerIsUnique(akRight,Child.Anchors[akRight],akTop,Child.Name);
      CheckCornerIsUnique(akRight,Child.Anchors[akRight],akBottom,Child.Name);
    end;
    if (Child.NodeType=adltnSplitterVertical) then begin
      // check if splitter corners have exactly one sibling
      CheckCornerIsUnique(akTop,Child.Anchors[akTop],akLeft,Child.Name);
      CheckCornerIsUnique(akTop,Child.Anchors[akTop],akRight,Child.Name);
      CheckCornerIsUnique(akBottom,Child.Anchors[akBottom],akLeft,Child.Name);
      CheckCornerIsUnique(akBottom,Child.Anchors[akBottom],akRight,Child.Name);
    end;
  end;
end;

procedure TAnchorDockLayoutTreeNode.Simplify(ExistingNames: TStrings; ParentMinimized: boolean);
{ Simplification rules:
   1. Control nodes without existing name are deleted.
   2. Empty layouts and pages are deleted
   3. pages and layouts with only one child are removed and its content moved up
}
var
  i: Integer;
  ChildNode: TAnchorDockLayoutTreeNode;
  NodeMinimized: Boolean;
begin
  // simplify children
  i:=Count-1;
  while i>=0 do begin
    ChildNode:=Nodes[i];
    NodeMinimized:=ParentMinimized or ChildNode.Minimized;
    ChildNode.Simplify(ExistingNames,NodeMinimized);

    if (ChildNode.NodeType=adltnControl) then begin
      // leaf node => check if there is a control
      if (ChildNode.Name='') or ((ExistingNames.IndexOf(ChildNode.Name)<0) and (not NodeMinimized)) then
        DeleteNode(ChildNode);
    end else if ChildNode.IsSplitter then begin
      // splitter
      // delete all children
      while ChildNode.Count>0 do
        ChildNode[0].Free;
    end else if ChildNode.NodeType=adltnCustomSite then begin
      // custom dock site
    end else if (ChildNode.Count=0) and (not NodeMinimized) then begin
      // inner node without child => delete
      DeleteNode(ChildNode);
    end else if (ChildNode.Count=1)
    and (ChildNode.NodeType in [adltnLayout,adltnPages]) then begin
      // layouts and pages with only one child
      // => move grandchildren up and delete childnode
      ReplaceWithChildren(ChildNode);
    end;

    i:=Min(i,Count)-1;
  end;
end;

procedure TAnchorDockLayoutTreeNode.DeleteNode(
  ChildNode: TAnchorDockLayoutTreeNode);
var
  i: Integer;
  Sibling: TAnchorDockLayoutTreeNode;
  Side: TAnchorKind;
  Splitter: TAnchorDockLayoutTreeNode;
begin
  {$IFDEF VerboseAnchorDocking}
  WriteDebugLayout('TAnchorDockLayoutTreeNode.DeleteNode BEFORE DELETE Self='+Name+' Child='+ChildNode.Name+' ',Self);
  {$ENDIF}
  ChildNode.Parent:=nil;
  try
    if not ChildNode.IsSplitter then begin
      // delete node bound splitter (= a splitter only anchored to this node)
      for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
        Splitter:=FindNodeBoundSplitter(ChildNode,Side);
        if Splitter<>nil then begin
          DeleteNodeBoundSplitter(Splitter,ChildNode,OppositeAnchor[Side]);
          exit;
        end;
      end;

      // delete spiral splitter
      for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
        Splitter:=FindChildNode(ChildNode.Anchors[Side],false);
        if (Splitter=nil) or (not Splitter.IsSplitter) then break;
        if Side=High(TAnchorKind) then begin
          DeleteSpiralSplitter(ChildNode);
          exit;
        end;
      end;
    end;
  finally
    // remove references
    for i:=0 to Count-1 do begin
      Sibling:=Nodes[i];
      for Side:=low(TAnchorKind) to high(TAnchorKind) do
        if Sibling.Anchors[Side]=ChildNode.Name then
          Sibling.Anchors[Side]:='';
    end;
    {$IFDEF VerboseAnchorDocking}
    WriteDebugLayout('TAnchorDockLayoutTreeNode.DeleteNode AFTER DELETE Self='+Name+' Child='+ChildNode.Name+' ',Self);
    {$ENDIF}
    // free node
    ChildNode.Free;
  end;
end;

function TAnchorDockLayoutTreeNode.FindNodeBoundSplitter(
  ChildNode: TAnchorDockLayoutTreeNode; Side: TAnchorKind
  ): TAnchorDockLayoutTreeNode;
var
  AnchorNode: TAnchorDockLayoutTreeNode;
  i: Integer;
  AnchorName: string;
begin
  Result:=nil;
  AnchorName:=ChildNode.Anchors[Side];
  if AnchorName='' then exit;
  AnchorNode:=FindChildNode(AnchorName,false);
  if (AnchorNode=nil) or (not AnchorNode.IsSplitter) then exit;
  for i:=0 to Count-1 do
    if (Nodes[i]<>ChildNode) and (Nodes[i].Anchors[Side]=AnchorName) then exit;
  Result:=AnchorNode;
end;

procedure TAnchorDockLayoutTreeNode.DeleteNodeBoundSplitter(Splitter,
  ChildNode: TAnchorDockLayoutTreeNode; Side: TAnchorKind);
{ delete node bound splitter (= a splitter only anchored to this node)

  Example: Side=akRight
                      #             #
    #####################     #########
       ---+S+--------+#         ---+#
       ---+S|AControl|#   --->  ---+#
       ---+S+--------+#         ---+#
    #####################     #########
}
var
  i: Integer;
  Sibling: TAnchorDockLayoutTreeNode;
begin
  for i:=0 to Count-1 do begin
    Sibling:=Nodes[i];
    if Sibling.Anchors[Side]=Splitter.Name then
      Sibling.Anchors[Side]:=ChildNode.Anchors[Side];
  end;
  DeleteNode(Splitter);
end;

procedure TAnchorDockLayoutTreeNode.DeleteSpiralSplitter(
  ChildNode: TAnchorDockLayoutTreeNode);
{ Merge two splitters and delete one of them.
  Prefer the pair with shortest distance between.

  For example:
               3            3
     11111111113            3
        2+----+3            3
        2|Node|3  --->  111111111
        2+----+3            2
        2444444444          2
        2                   2
   Everything anchored to 4 is now anchored to 1.
   And right side of 1 is now anchored to where the right side of 4 was anchored.
}
var
  Splitters: array[TAnchorKind] of TAnchorDockLayoutTreeNode;
  Side: TAnchorKind;
  i: Integer;
  Sibling: TAnchorDockLayoutTreeNode;
  Keep: TAnchorKind;
  DeleteSplitter: TAnchorDockLayoutTreeNode;
  NextSide: TAnchorKind;
begin
  // find the four splitters
  for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
    Splitters[Side]:=FindChildNode(ChildNode.Anchors[Side],false);
    if (Splitters[Side]=nil) or (not Splitters[Side].IsSplitter) then
      RaiseGDBException(''); // missing splitter
  end;
  for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
    // spiral splitters are connected to each other
    NextSide:=ClockwiseAnchor[Side];
    if Splitters[Side].Anchors[NextSide]<>Splitters[NextSide].Name then begin
      NextSide:=OppositeAnchor[NextSide];
      if Splitters[Side].Anchors[NextSide]<>Splitters[NextSide].Name then
        RaiseGDBException(''); // this is not a spiral splitter
    end;
  end;
  // Prefer the pair with shortest distance between
  if (Splitters[akRight].Left-Splitters[akLeft].Left)
    <(Splitters[akBottom].Top-Splitters[akTop].Top)
  then
    Keep:=akLeft
  else
    Keep:=akTop;
  DeleteSplitter:=Splitters[OppositeAnchor[Keep]];
  // transfer anchors from the deleting splitter to the kept splitter
  for i:=0 to Count-1 do begin
    Sibling:=Nodes[i];
    for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
      if FindChildNode(Sibling.Anchors[Side],false)=DeleteSplitter then
        Sibling.Anchors[Side]:=Splitters[Keep].Name;
    end;
  end;
  // longen kept splitter
  NextSide:=ClockwiseAnchor[Keep];
  if Splitters[Keep].Anchors[NextSide]<>Splitters[NextSide].Name then
    NextSide:=OppositeAnchor[NextSide];
  Splitters[Keep].Anchors[NextSide]:=DeleteSplitter.Anchors[NextSide];
  // delete the splitter
  DeleteNode(DeleteSplitter);
end;

procedure TAnchorDockLayoutTreeNode.ReplaceWithChildren(
  ChildNode: TAnchorDockLayoutTreeNode);
{ move all children of ChildNode up.
  All anchored to ChildNode (= their parent) use the anchors of ChildNode.
  ChildNode is freed.
}
var
  GrandChild: TAnchorDockLayoutTreeNode;
  Side: TAnchorKind;
begin
  {$IFDEF VerboseAnchorDocking}
  WriteDebugLayout('TAnchorDockLayoutTreeNode.ReplaceWithChildren BEFORE REPLACE Self='+Name+' Child='+ChildNode.Name+' ',Self);
  {$ENDIF}
  DebugWriteChildAnchors(Self);
  while ChildNode.Count>0 do begin
    GrandChild:=ChildNode[0];
    GrandChild.Parent:=Self;
    OffsetRect(GrandChild.FBoundsRect,ChildNode.Left,ChildNode.Top);
    for Side:=low(TAnchorKind) to high(TAnchorKind) do begin
      if GrandChild.Anchors[Side]='' then begin
        if ((GrandChild.NodeType=adltnSplitterHorizontal)
            and (Side in [akTop,akBottom]))
        or ((GrandChild.NodeType=adltnSplitterVertical)
            and (Side in [akLeft,akRight]))
        then
          continue; // a free splitter sides => don't anchor it
        GrandChild.Anchors[Side]:=ChildNode.Anchors[Side];
      end;
    end;
  end;
  {$IFDEF VerboseAnchorDocking}
  WriteDebugLayout('TAnchorDockLayoutTreeNode.ReplaceWithChildren AFTER REPLACE Self='+Name+' Child='+ChildNode.Name+' ',Self);
  {$ENDIF}
  ChildNode.Free;
  DebugWriteChildAnchors(Self);
end;

procedure TAnchorDockLayoutTreeNode.IncreaseChangeStamp;
begin
  if Parent<>nil then Parent.IncreaseChangeStamp;
end;

function TAnchorDockLayoutTreeNode.IsSplitter: boolean;
begin
  Result:=NodeType in [adltnSplitterHorizontal,adltnSplitterVertical];
end;

function TAnchorDockLayoutTreeNode.IsRootWindow: boolean;
begin
  Result:=(NodeType in [adltnLayout,adltnPages,adltnControl,adltnCustomSite])
          and ((Parent=nil) or (Parent.NodeType in [adltnNone]));
end;

function TAnchorDockLayoutTreeNode.Count: integer;
begin
  Result:=FNodes.Count;
end;

{ TAnchorDockLayoutTreeRootNode }

procedure TAnchorDockLayoutTreeRootNode.IncreaseChangeStamp;
begin
  Tree.IncreaseChangeStamp;
end;

procedure TAnchorDockLayoutTreeRootNode.CheckConsistency;
var
  Names: TStringList;

  procedure RaiseNodePath(const Msg: string; Node: TAnchorDockLayoutTreeNode);
  var
    s: String;
  begin
    s:='';
    while Node<>nil do begin
      if s<>'' then
        s:='/'+s;
      s:=Node.Name+s;
      Node:=Node.Parent;
    end;
    s:=Msg+s;
  end;

  procedure CheckNames(Node: TAnchorDockLayoutTreeNode);
  var
    i: Integer;
  begin
    if (Node.Name='') and (Node<>Self) then
      RaiseNodePath(adrsEmptyName, Node);
    for i:=0 to Names.Count-1 do
      if CompareText(Names[i],Node.Name)=0 then
        RaiseNodePath(adrsDuplicateName, Node);
    Names.Add(Node.Name);
    for i:=0 to Node.Count-1 do
      CheckNames(Node[i]);
  end;

begin
  // check that all names are unique
  Names:=TStringList.Create;
  try
    CheckNames(Self);
  finally
    Names.Free;
  end;
  inherited CheckConsistency;
end;

{ TAnchorDockLayoutTree }

procedure TAnchorDockLayoutTree.SetModified(const AValue: boolean);
begin
  if AValue then
    IncreaseChangeStamp
  else
    FSavedChangeStamp:=FChangeStamp;
end;

function TAnchorDockLayoutTree.GetModified: boolean;
begin
  Result:=FSavedChangeStamp<>FChangeStamp;
end;

constructor TAnchorDockLayoutTree.Create;
begin
  FSavedChangeStamp:=Low(FChangeStamp);
  FRoot:=TAnchorDockLayoutTreeRootNode.Create;
  Root.FTree:=Self;
end;

destructor TAnchorDockLayoutTree.Destroy;
begin
  FreeAndNil(FRoot);
  inherited Destroy;
end;

procedure TAnchorDockLayoutTree.Clear;
begin
  FRoot.Clear;
  Modified:=false;
end;

procedure TAnchorDockLayoutTree.LoadFromConfig(Config: TConfigStorage);
begin
  Config.AppendBasePath('Nodes/');
  FRoot.LoadFromConfig(Config);
  Config.UndoAppendBasePath;
  Root.CheckConsistency;
end;

procedure TAnchorDockLayoutTree.LoadFromConfig(Path: string; Config: TRttiXMLConfig);
begin
  FRoot.LoadFromConfig(Path+'Nodes/',Config);
  Root.CheckConsistency;
end;

procedure TAnchorDockLayoutTree.SaveToConfig(Config: TConfigStorage);
begin
  Config.AppendBasePath('Nodes/');
  FRoot.SaveToConfig(Config);
  Config.UndoAppendBasePath;
end;

procedure TAnchorDockLayoutTree.SaveToConfig(Path: string; Config: TRttiXMLConfig);
begin
  FRoot.SaveToConfig(Path+'Nodes/',Config);
end;

procedure TAnchorDockLayoutTree.IncreaseChangeStamp;
begin
  if FChangeStamp<High(FChangeStamp) then
    inc(FChangeStamp)
  else
    FChangeStamp:=Low(FChangeStamp)+1;
end;

function TAnchorDockLayoutTree.NewNode(aParent: TAnchorDockLayoutTreeNode
  ): TAnchorDockLayoutTreeNode;
begin
  Result:=TAnchorDockLayoutTreeNode.Create;
  Result.Parent:=aParent;
end;

procedure TAnchorDockLayoutTree.Assign(Source: TObject);
begin
  if Source is TAnchorDockLayoutTree then
    Root.Assign(TAnchorDockLayoutTree(Source).Root)
  else if Source is TAnchorDockLayoutTreeNode then
    Root.Assign(TAnchorDockLayoutTreeNode(Source))
  else
    raise Exception.Create('TAnchorDockLayoutTree.Assign not implemented '+DbgSName(Source));
end;

{ TADNameToControl }

function TADNameToControl.IndexOfName(const aName: string): integer;
begin
  Result:=fItems.Count-1;
  while (Result>=0) and (CompareText(aName,fItems[Result])<>0) do
    dec(Result);
end;

function TADNameToControl.GetControl(const aName: string): TControl;
var
  i: LongInt;
begin
  i:=IndexOfName(aName);
  if i>=0 then
    Result:=TControl(fItems.Objects[i])
  else
    Result:=nil;
end;

procedure TADNameToControl.SetControl(const aName: string;
  const AValue: TControl);
var
  i: LongInt;
begin
  i:=IndexOfName(aName);
  if i>=0 then begin
    fItems[i]:=aName;
    fItems.Objects[i]:=AValue;
  end else
    fItems.AddObject(aName,AValue);
end;

constructor TADNameToControl.Create;
begin
  fItems:=TStringList.Create;
end;

destructor TADNameToControl.Destroy;
begin
  FreeAndNil(fItems);
  inherited Destroy;
end;

function TADNameToControl.ControlToName(AControl: TControl): string;
var
  i: Integer;
begin
  i:=fItems.Count-1;
  while i>=0 do begin
    if fItems.Objects[i]=AControl then begin
      Result:=fItems[i];
      exit;
    end;
    dec(i);
  end;
  Result:='';
end;

procedure TADNameToControl.RemoveControl(AControl: TControl);
var
  i: Integer;
begin
  i:=fItems.Count-1;
  while i>=0 do begin
    if fItems.Objects[i]=AControl then
      fItems.Delete(i);
    dec(i);
  end;
end;

procedure TADNameToControl.WriteDebugReport(Msg: string);
var
  i: Integer;
begin
  debugln(['TADNameToControl.WriteDebugReport ',fItems.Count,' ',Msg]);
  for i:=0 to fItems.Count-1 do begin
    debugln(['  ',i,'/',fItems.Count,' "',dbgstr(fItems[i]),'" Control=',dbgsname(TControl(fItems.Objects[i]))]);
  end;
end;

{ TAnchorDockRestoreLayout }

procedure TAnchorDockRestoreLayout.SetControlNames(const AValue: TStrings);
begin
  if FControlNames=AValue then exit;
  FControlNames.Assign(AValue);
end;

constructor TAnchorDockRestoreLayout.Create;
begin
  FControlNames:=TStringList.Create;
  FLayout:=TAnchorDockLayoutTree.Create;
end;

constructor TAnchorDockRestoreLayout.Create(aLayout: TAnchorDockLayoutTree);
begin
  FControlNames:=TStringList.Create;
  FLayout:=aLayout;
  UpdateControlNames;
end;

destructor TAnchorDockRestoreLayout.Destroy;
begin
  FreeAndNil(FLayout);
  FreeAndNil(FControlNames);
  inherited Destroy;
end;

procedure TAnchorDockRestoreLayout.Assign(Source: TAnchorDockRestoreLayout);
begin
  FControlNames.Assign(Source.FControlNames);
  FLayout.Assign(Source.FLayout);
end;

function TAnchorDockRestoreLayout.IndexOfControlName(AName: string): integer;
begin
  Result:=fControlNames.Count-1;
  while (Result>=0) and (CompareText(AName,FControlNames[Result])<>0) do
    dec(Result);
end;

function TAnchorDockRestoreLayout.HasControlName(AName: string): boolean;
begin
  Result:=IndexOfControlName(AName)>=0;
end;

procedure TAnchorDockRestoreLayout.RemoveControlName(AName: string);
var
  i: Integer;
begin
  for i:=FControlNames.Count-1 downto 0 do
    if CompareText(AName,FControlNames[i])=0 then
      FControlNames.Delete(i);
end;

procedure TAnchorDockRestoreLayout.UpdateControlNames;

  procedure Check(Node: TAnchorDockLayoutTreeNode);
  var
    i: Integer;
  begin
    if (Node.Name<>'') and (Node.NodeType in [adltnControl,adltnCustomSite])
    and (not HasControlName(Node.Name)) then
      FControlNames.Add(Node.Name);
    for i:=0 to Node.Count-1 do
      Check(Node[i]);
  end;

begin
  FControlNames.Clear;
  Check(Layout.Root);
end;

procedure TAnchorDockRestoreLayout.LoadFromConfig(Config: TConfigStorage);
var
  i: Integer;
  AName: string;
  Node: TAnchorDockLayoutTreeNode;
begin
  FControlNames.Delimiter:=',';
  FControlNames.StrictDelimiter:=true;
  FControlNames.DelimitedText:=Config.GetValue('Names','');
  Layout.LoadFromConfig(Config);
  for i:=FControlNames.Count-1 downto 0 do begin
    AName:=FControlNames[i];
    if IsValidIdent(AName) and (Layout.Root<>nil) then begin
      Node:=Layout.Root.FindChildNode(AName,true);
      if (Node<>nil) and (Node.NodeType in [adltnControl,adltnCustomSite]) then
        continue;
    end;
    FControlNames.Delete(i);
  end;
end;

procedure TAnchorDockRestoreLayout.LoadFromConfig(Path: string; Config: TRttiXMLConfig);
var
  i: Integer;
  AName: string;
  Node: TAnchorDockLayoutTreeNode;
begin
  FControlNames.Delimiter:=',';
  FControlNames.StrictDelimiter:=true;
  FControlNames.DelimitedText:=Config.GetValue(Path+'Names','');
  Layout.LoadFromConfig(Path, Config);
  for i:=FControlNames.Count-1 downto 0 do begin
    AName:=FControlNames[i];
    if IsValidIdent(AName) and (Layout.Root<>nil) then begin
      Node:=Layout.Root.FindChildNode(AName,true);
      if (Node<>nil) and (Node.NodeType in [adltnControl,adltnCustomSite]) then
        continue;
    end;
    FControlNames.Delete(i);
  end;
end;

procedure TAnchorDockRestoreLayout.SaveToConfig(Config: TConfigStorage);
begin
  FControlNames.Delimiter:=',';
  FControlNames.StrictDelimiter:=true;
  Config.SetDeleteValue('Names',FControlNames.DelimitedText,'');
  Layout.SaveToConfig(Config);
end;

procedure TAnchorDockRestoreLayout.SaveToConfig(Path: string; Config: TRttiXMLConfig);
begin
  FControlNames.Delimiter:=',';
  FControlNames.StrictDelimiter:=true;
  Config.SetDeleteValue(Path+'Names',FControlNames.DelimitedText,'');
  Layout.SaveToConfig(Path, Config);
end;

{ TAnchorDockRestoreLayouts }

function TAnchorDockRestoreLayouts.GetItems(Index: integer): TAnchorDockRestoreLayout;
begin
  Result:=TAnchorDockRestoreLayout(fItems[Index]);
end;

constructor TAnchorDockRestoreLayouts.Create;
begin
  fItems:=TFPList.Create;
end;

destructor TAnchorDockRestoreLayouts.Destroy;
begin
  Clear;
  FreeAndNil(fItems);
  inherited Destroy;
end;

procedure TAnchorDockRestoreLayouts.Clear;
var
  i: Integer;
begin
  for i:=0 to fItems.Count-1 do
    TObject(fItems[i]).Free;
  fItems.Clear;
end;

procedure TAnchorDockRestoreLayouts.Assign(Source: TAnchorDockRestoreLayouts);
var
  i: Integer;
  xNew: TAnchorDockRestoreLayout;
begin
  Clear;
  for i := 0 to Source.Count-1 do
  begin
    xNew := TAnchorDockRestoreLayout.Create;
    Add(xNew, False);
    xNew.Assign(Source[i]);
  end;
end;

procedure TAnchorDockRestoreLayouts.Delete(Index: integer);
begin
  TObject(fItems[Index]).Free;
  fItems.Delete(Index);
end;

function TAnchorDockRestoreLayouts.IndexOfName(AControlName: string): integer;
begin
  Result:=Count-1;
  while (Result>=0) and not Items[Result].HasControlName(AControlName) do
    dec(Result);
end;

function TAnchorDockRestoreLayouts.FindByName(AControlName: string
  ): TAnchorDockRestoreLayout;
var
  i: LongInt;
begin
  i:=IndexOfName(AControlName);
  if i>=0 then
    Result:=Items[i]
  else
    Result:=nil;
end;

procedure TAnchorDockRestoreLayouts.Add(Layout: TAnchorDockRestoreLayout;
  RemoveOther: boolean);
var
  i: Integer;
begin
  if Layout=nil then exit;
  if RemoveOther then begin
    for i:=0 to Layout.ControlNames.Count-1 do
      RemoveByName(Layout.ControlNames[i]);
  end;
  fItems.Add(Layout);
end;

procedure TAnchorDockRestoreLayouts.RemoveByName(AControlName: string);
var
  i: Integer;
  Layout: TAnchorDockRestoreLayout;
begin
  for i:=Count-1 downto 0 do begin
    Layout:=Items[i];
    Layout.RemoveControlName(AControlName);
    if Layout.ControlNames.Count=0 then
      Delete(i);
  end;
end;

procedure TAnchorDockRestoreLayouts.LoadFromConfig(Config: TConfigStorage);
var
  NewCount: longint;
  NewItem: TAnchorDockRestoreLayout;
  i: Integer;
begin
  Clear;
  NewCount:=Config.GetValue('Count',0);
  for i:=1 to NewCount do begin
    NewItem:=TAnchorDockRestoreLayout.Create;
    Config.AppendBasePath('Item'+IntToStr(i+1)+'/');
    try
      NewItem.LoadFromConfig(Config);
    finally
      Config.UndoAppendBasePath;
    end;
    if NewItem.ControlNames.Count>0 then
      fItems.Add(NewItem)
    else
      NewItem.Free;
  end;
end;

procedure TAnchorDockRestoreLayouts.SaveToConfig(Config: TConfigStorage);
var
  i: Integer;
begin
  Config.SetDeleteValue('Count',Count,0);
  for i:=0 to Count-1 do begin
    Config.AppendBasePath('Item'+IntToStr(i+1)+'/');
    try
      Items[i].SaveToConfig(Config);
    finally
      Config.UndoAppendBasePath;
    end;
  end;
end;

procedure TAnchorDockRestoreLayouts.LoadFromConfig(Path: string; Config: TRttiXMLConfig);
var
  NewCount: longint;
  NewItem: TAnchorDockRestoreLayout;
  i: Integer;
begin
  Clear;
  NewCount:=Config.GetValue(Path+'Count',0);
  for i:=1 to NewCount do begin
    NewItem:=TAnchorDockRestoreLayout.Create;
    NewItem.LoadFromConfig(Path+'Item'+IntToStr(i+1)+'/', Config);
    if NewItem.ControlNames.Count>0 then
      fItems.Add(NewItem)
    else
      NewItem.Free;
  end;
end;

procedure TAnchorDockRestoreLayouts.SaveToConfig(Path: string; Config: TRttiXMLConfig);
var
  i: Integer;
begin
  Config.SetDeleteValue(Path+'Count',Count,0);
  for i:=0 to Count-1 do begin
    Items[i].SaveToConfig(Path+'Item'+IntToStr(i+1)+'/', Config);
  end;
end;

function TAnchorDockRestoreLayouts.ConfigIsEmpty(Config: TConfigStorage): boolean;
begin
  Result:=Config.GetValue('Count',0)<=0;
end;

function TAnchorDockRestoreLayouts.Count: integer;
begin
  Result:=fItems.Count;
end;

end.


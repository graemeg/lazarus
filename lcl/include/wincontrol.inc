{%MainUnit ../controls.pp}

{******************************************************************************
                                  TWinControl
 ******************************************************************************

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************
}

{$IFOPT C-}
// Uncomment for local trace
//  {$C+}
//  {$DEFINE ASSERT_IS_ON}
{$ENDIF}

{off $DEFINE VerboseAutoSizeCtrlData}
{off $DEFINE VerboseMouseBugfix}
{off $DEFINE VerboseCanAutoSize}
{off $DEFINE VerboseIntfSizing}
{off $DEFINE VerboseClientRectBugFix}
{$IFDEF VerboseClientRectBugFix}
const CheckClientRectName = 'LCLInterfaceRadioGroup';
{$ENDIF}

{off $DEFINE VerboseSizeMsg}
{off $DEFINE CHECK_POSITION}
{$IFDEF CHECK_POSITION}
const CheckPostionClassName = 'xxxTBreakPropertyDlg';
const CheckPostionName = 'FakeStatusBar';
const CheckPostionParentName = 'xxxEnvVarsPage';

function CheckPosition(AControl: TControl): boolean;
begin
  Result:=(CompareText(AControl.ClassName,CheckPostionClassName)=0)
           or (CompareText(AControl.Name,CheckPostionName)=0)
           or ((AControl.Parent<>nil)
               and (CompareText(AControl.Parent.Name,CheckPostionParentName)=0));
end;
{$ENDIF}

function IsNotAligned(AControl: TControl): boolean;
begin
  Result:=(AControl.Align=alNone)
      and (AControl.Anchors=[akLeft,akTop])
      and (AControl.AnchorSide[akLeft].Control=nil)
      and (AControl.AnchorSide[akTop].Control=nil);
end;

function IsNotAligned(AControl: TControl; ASide: TAnchorKind): boolean;
begin
  Result:=(AControl.Align=alNone);
  if not Result then Exit;
  if ASide in [akLeft, akRight] then
    Result:=(AControl.Anchors*[akLeft, akRight]=[akLeft])
        and (AControl.AnchorSide[akLeft].Control=nil)
  else
    Result:=(AControl.Anchors*[akTop, akBottom]=[akTop])
        and (AControl.AnchorSide[akBottom].Control=nil);
end;

{------------------------------------------------------------------------------
  Autosizing Helper classes
-------------------------------------------------------------------------------}
type
  TAutoSizeBoxOrientation = (asboHorizontal, asboVertical);

  PAutoSizeBox = ^TAutoSizeBox;

  { TAutoSizeBox
    A TAutoSizeBox is a node in a tree.
    A TAutoSizeBox can be a cell. Then it is a leaf in the tree and can have a
    Control.
    A TAutoSizeBox can be a row or column. Then it has only one Children array.
    A TAutoSizeBox can be a table. Then it has both Children arrays.
  }

  TAutoSizeBox = class
  public
    Control: TControl; // the Control of a leaf node
    MinimumSize: array[TAutoSizeBoxOrientation] of integer;
    MaximumSize: array[TAutoSizeBoxOrientation] of integer; // 0 means inifinte
    PreferredSize: array[TAutoSizeBoxOrientation] of integer;// without theme space
    LeftTop: array[TAutoSizeBoxOrientation] of integer;
    BorderLeftTop: array[TAutoSizeBoxOrientation] of integer;
    BorderRightBottom: array[TAutoSizeBoxOrientation] of integer;
    Parent: array[TAutoSizeBoxOrientation] of TAutoSizeBox;
    Index: array[TAutoSizeBoxOrientation] of Integer; // index in parent or grandparent
    ChildCount: array[TAutoSizeBoxOrientation] of Integer;
    Children: array[TAutoSizeBoxOrientation] of PAutoSizeBox;
    NewControlBounds: TRect;

    // for nodes
    destructor Destroy; override;
    procedure Clear;
    procedure SetControl(AControl: TControl);
    procedure ApplyChildSizingBorders(ChildSizing: TControlChildSizing);

    // for rows and columns
    procedure AllocateChildsArray(Orientation: TAutoSizeBoxOrientation;
                                  NewChildCount: Integer);
    procedure InitSums;
    procedure SumLine(Orientation: TAutoSizeBoxOrientation;
                      DoInit: boolean);
    procedure ResizeChildren(ChildSizing: TControlChildSizing;
                             Orientation: TAutoSizeBoxOrientation;
                             TargetSize: integer);
    procedure ComputeLeftTops(Orientation: TAutoSizeBoxOrientation);

    // for tables
    procedure AllocateTable(ColCount, RowCount: Integer);
    procedure SetTableControls(ListOfControls: TFPList;
                               ChildSizing: TControlChildSizing;
                               BiDiMode: TBiDiMode);
    procedure SumTable;
    procedure ResizeTable(ChildSizing: TControlChildSizing;
                          TargetWidth, TargetHeight: integer);
//    Michl: Commented procedure AlignToRight because of issue #28483, afaics
//           it isn't needed, I'll remove code, if there are no regressions.
//           Commented in revision 55209
//    procedure AlignToRight(TargetWidth: integer);
    procedure ComputeTableControlBounds(ChildSizing: TControlChildSizing;
                                        BiDiMode: TBiDiMode);
    function SetTableControlBounds(ChildSizing: TControlChildSizing
                                   ): boolean;// true if changed
    function AlignControlsInTable(ListOfControls: TFPList;
                                  ChildSizing: TControlChildSizing;
                                  BiDiMode: TBiDiMode;
                                  TargetWidth, TargetHeight: integer;
                                  Apply: boolean): boolean;// true if changed

    // debugging
    procedure WriteDebugReport(const Title: string);
  end;
  
  { TAutoSizeCtrlData
    This class is used by the auto size algorithm, to compute the preferred
      size of a control given the preferred sizes of its children.
    Hints about the algorithm:
      First it builds a graph of dependencies. That means, for every side
      (Left,Top,Right,Bottom) of each child control the anchor control and
      space is calculated. Anchor means here direct and indirect anchors.
      Indirect anchors are defined by the Align property.
      For example a control with Align=alTop is anchored left to the parent,
      right to the parent and top to either the parent or another alTop control.
      Then it searches for circles and other invalid combinations and repairs
      them.
    }
    
  TAutoSizeCtrlData = class;
  
  TAutoSizeSideDataState = (
    assdfInvalid,
    assdfComputing,
    assdfUncomputable,// e.g. if [akLeft,akRight]*Anchors = []
    assdfValid
    );
  TAutoSizeSideDistDirection = (
    assddLeftTop,
    assddRightBottom
    );

  TAutoSizeSideData = record
    CtrlData: TAutoSizeCtrlData;
    Side: TAnchorSideReference;
    Space: integer;
    Distance: array[TAutoSizeSideDistDirection] of integer;
    DistanceState: array[TAutoSizeSideDistDirection] of TAutoSizeSideDataState;
  end;
    
  TAutoSizeCtrlData = class
  private
    FChilds: TAvlTree;// tree of TAutoSizeCtrlData
    function GetChildren(AControl: TControl): TAutoSizeCtrlData;
    procedure DoMoveNonAlignedChildren(Side: TAnchorKind;
                                   var MoveDiff: integer; FindMinimum: boolean);
    procedure SetupNonAlignedChildren(MoveNonAlignedChildrenLeft,
                                      MoveNonAlignedChildrenTop: boolean);
    procedure AlignChildren;
    procedure SetupSpace;
    function ComputePositions: boolean;// false if recomputation is needed (a property changed)
  public
    Control: TControl; // the Control of a leaf node
    WinControl: TWinControl;// the Control as TWinControl (else nil)
    ChildCount: integer;
    Visible: boolean;//= Control.IsControlVisible
    PreferredSize: array[TAutoSizeBoxOrientation] of integer;// without theme space
    Borders: array[TAnchorKind] of integer;
    AdjustedClientBorders: array[TAnchorKind] of integer;// the borderspace created by WinControl.AdjustClientRect
    Sides: array[TAnchorKind] of TAutoSizeSideData;
    BaseBounds: TRect;
    BaseParentClientSize: TSize;
    constructor Create(AControl: TControl; IsParent: boolean = true);
    destructor Destroy; override;
    procedure Clear;
    procedure ComputePreferredClientArea(MoveNonAlignedChildrenLeft,
                      MoveNonAlignedChildrenTop: boolean;
                      out MoveNonAlignedToLeft, MoveNonAlignedToTop,
                      PreferredClientWidth, PreferredClientHeight: integer);
    procedure FixControlProperties(Child: TControl);
    procedure ClearSides;
    procedure SetFixedLeftTop(ChildData: TAutoSizeCtrlData; Side: TAnchorKind;
                              NewLeftTop: integer);
    property Children[AControl: TControl]: TAutoSizeCtrlData read GetChildren; default;
    procedure WriteDebugReport(const Title, Prefix: string; OnlyVisible: boolean = true);
  end;

const
  SizeBoxOrthogonal: array[TAutoSizeBoxOrientation] of TAutoSizeBoxOrientation
    = (asboVertical,asboHorizontal);
  {AutoSizeSideDataStateNames: array[TAutoSizeSideDataState] of shortstring = (
    'assdfInvalid',
    'assdfComputing',
    'assdfUncomputable',
    'assdfValid'
    );}
  {$IFNDEF DisableChecks}
  AutoSizeSideDistDirectionNames: array[TAutoSizeSideDistDirection] of shortstring = (
    'assddLeftTop',
    'assddRightBottom'
    );
  {$ENDIF}

function CompareAutoSizeCtrlDatas(Data1, Data2: Pointer): integer;
var
  Control1: TControl;
  Control2: TControl;
begin
  Control1:=TAutoSizeCtrlData(Data1).Control;
  Control2:=TAutoSizeCtrlData(Data2).Control;
  if Pointer(Control1)>Pointer(Control2) then
    Result:=1
  else if Pointer(Control1)<Pointer(Control2) then
    Result:=-1
  else
    Result:=0;
end;

function CompareControlWithAutoSizeCtrlData(AControl, AData: Pointer): integer;
var
  Control1: TControl;
  Control2: TControl;
begin
  Control1:=TControl(AControl);
  Control2:=TAutoSizeCtrlData(AData).Control;
  if Pointer(Control1)>Pointer(Control2) then
    Result:=1
  else if Pointer(Control1)<Pointer(Control2) then
    Result:=-1
  else
    Result:=0;
end;


{ TAutoSizeCtrlData }

function TAutoSizeCtrlData.GetChildren(AControl: TControl): TAutoSizeCtrlData;
var
  AVLNode: TAvlTreeNode;
begin
  if AControl=nil then exit(nil);
  if AControl=Control then RaiseGDBException('TAutoSizeCtrlData.GetChilds');
  if FChilds=nil then
    FChilds:=TAvlTree.Create(@CompareAutoSizeCtrlDatas);
  AVLNode:=FChilds.FindKey(AControl,@CompareControlWithAutoSizeCtrlData);
  if AVLNode<>nil then
    Result:=TAutoSizeCtrlData(AVLNode.Data)
  else begin
    Result:=TAutoSizeCtrlData.Create(AControl,false);
    FChilds.Add(Result);
  end;
end;

procedure TAutoSizeCtrlData.AlignChildren;
var
  AlignList: TFPList;
  AlignBoundaryControls: array[TAnchorKind] of TAutoSizeCtrlData;

  procedure DoAlign(TheAlign: TAlign);
  var
    Child: TControl;
    i: Integer;
    ChildData: TAutoSizeCtrlData;
    a: TAnchorKind;
  begin
    WinControl.CreateControlAlignList(TheAlign, AlignList, nil);
    for i := 0 to AlignList.Count - 1 do
    begin
      Child := TControl(AlignList[i]);
      ChildData := Children[Child];
      //DebugLn('DoAlign ',DbgSName(Child),' ',dbgs(Child.Align));

      for a := Low(TAnchorKind) to High(TAnchorKind) do
        if a in AnchorAlign[TheAlign] then
        begin
          ChildData.Sides[a].CtrlData := AlignBoundaryControls[a];
          if (a in [akLeft, akTop]) = (ChildData.Sides[a].CtrlData = Self) then
            ChildData.Sides[a].Side := asrLeft
          else
            ChildData.Sides[a].Side := asrRight;
          //DebugLn('DoAlign ',DbgSName(Child),' ',dbgs(a),' ',dbgs(a,ChildData.Sides[a].Side));
        end;

      case TheAlign of
        alTop: AlignBoundaryControls[akTop] := ChildData;
        alBottom: AlignBoundaryControls[akBottom] := ChildData;
        alLeft: AlignBoundaryControls[akLeft] := ChildData;
        alRight: AlignBoundaryControls[akRight] := ChildData;
        alClient: ; // Delphi compatibility: multiple alClient controls overlap
      end;
      {DebugLn(['DoAlign AlignBoundaryControls:',
        ' Left=',DbgSName(AlignBoundaryControls[akLeft].Control),
        ' Top=',DbgSName(AlignBoundaryControls[akTop].Control),
        ' Right=',DbgSName(AlignBoundaryControls[akRight].Control),
        ' Bottom=',DbgSName(AlignBoundaryControls[akBottom].Control)  ]);}
    end;
  end;
  
var
  a: TAnchorKind;
begin
  if ChildCount = 0 then exit;
  AlignList := TFPList.Create;
  try
    // align and anchor child controls
    for a := Low(TAnchorKind) to High(TAnchorKind) do
      AlignBoundaryControls[a] := Self;
    DoAlign(alTop);
    DoAlign(alBottom);
    DoAlign(alLeft);
    DoAlign(alRight);
    DoAlign(alClient);
  finally
    AlignList.Free;
  end;
end;

procedure TAutoSizeCtrlData.SetupSpace;
var
  i: Integer;
  Child: TControl;
  ChildData: TAutoSizeCtrlData;
  a: TAnchorKind;
  SiblingData: TAutoSizeCtrlData;
  NewSpace: LongInt;
begin
  for i:=0 to ChildCount-1 do begin
    Child:=WinControl.Controls[i];
    ChildData:=Children[Child];
    for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
      if ChildData.Sides[a].CtrlData=Self then begin
        // aligned or anchored to parent
        if a in [akLeft,akRight] then begin
          ChildData.Sides[a].Space:=Max(WinControl.ChildSizing.LeftRightSpacing,
                                        ChildData.Borders[a]);
        end else begin
          ChildData.Sides[a].Space:=Max(WinControl.ChildSizing.TopBottomSpacing,
                                        ChildData.Borders[a]);
        end;
        inc(ChildData.Sides[a].Space,AdjustedClientBorders[a]);
      end else if ChildData.Sides[a].CtrlData<>nil then begin
        SiblingData:=ChildData.Sides[a].CtrlData;
        // aligned or anchored to a sibling
        if a in [akLeft,akTop] then begin
          NewSpace:=ChildData.Borders[a];
          if ChildData.Sides[a].Side=asrRight then begin
            NewSpace:=Max(NewSpace,WinControl.ChildSizing.HorizontalSpacing);
            if a=akLeft then
              NewSpace:=Max(NewSpace,SiblingData.Borders[akRight])
            else
              NewSpace:=Max(NewSpace,SiblingData.Borders[akBottom]);
          end else if ChildData.Sides[a].Side=asrLeft then

          else if ChildData.Sides[a].Side=asrCenter then
            NewSpace:=0;
          ChildData.Sides[a].Space:=NewSpace;
        end else begin
          NewSpace:=ChildData.Borders[a];
          if ChildData.Sides[a].Side=asrTop then begin
            NewSpace:=Max(NewSpace,WinControl.ChildSizing.VerticalSpacing);
            if a=akRight then
              NewSpace:=Max(NewSpace,SiblingData.Borders[akLeft])
            else
              NewSpace:=Max(NewSpace,SiblingData.Borders[akTop]);
          end else if ChildData.Sides[a].Side=asrBottom then

          else if ChildData.Sides[a].Side=asrCenter then
            NewSpace:=0;
          ChildData.Sides[a].Space:=NewSpace;
        end;
      end else if a in Child.Anchors then begin
        // anchored to parent via BaseBounds
        if a in [akLeft,akTop] then begin
          ChildData.Sides[a].Side:=asrRight;
        end else begin
          ChildData.Sides[a].Side:=asrLeft;
        end;
        case a of
        akTop: ChildData.Sides[a].Space:=ChildData.BaseBounds.Top;
        akLeft: ChildData.Sides[a].Space:=ChildData.BaseBounds.Left;
        akRight: ChildData.Sides[a].Space:=
                   ChildData.BaseParentClientSize.cx-ChildData.BaseBounds.Right;
        akBottom: ChildData.Sides[a].Space:=
                  ChildData.BaseParentClientSize.cy-ChildData.BaseBounds.Bottom;
        end;
      end else begin
        // not anchored => use borderspacing
        if a in [akLeft,akTop] then
          ChildData.Sides[a].Side:=asrRight
        else
          ChildData.Sides[a].Side:=asrLeft;
        if a in [akLeft,akRight] then begin
          ChildData.Sides[a].Space:=
            Max(WinControl.ChildSizing.LeftRightSpacing,
                ChildData.Borders[a]);
        end else begin
          ChildData.Sides[a].Space:=
            Max(WinControl.ChildSizing.TopBottomSpacing,
                ChildData.Borders[a]);
        end;
        inc(ChildData.Sides[a].Space,AdjustedClientBorders[a]);
      end;
    end;
  end;
end;

function TAutoSizeCtrlData.ComputePositions: boolean;
type
  TComputeResult = (
    crSuccess,
    crCircle,
    crFixedCircled
    );

  function ComputePosition(ChildData: TAutoSizeCtrlData; Side: TAnchorKind;
    Direction: TAutoSizeSideDistDirection): TComputeResult;
  var
    OppositeSide: TAnchorKind;
    NewDist: LongInt;
    SiblingData: TAutoSizeCtrlData;
    NeededSiblingSides: TAnchors;
    a: TAnchorKind;
    Child: TControl;
    IsSideLeftTop, IsOutwards, IsParentInwards: boolean;
    CurAnchors: TAnchors;
    CurSize: LongInt;
    FoundSides: TAnchors;
    AddPreferredSize: Boolean;
  begin
    if ChildData.Sides[Side].DistanceState[Direction]
      in [assdfValid,assdfUncomputable]
    then
      exit(crSuccess); // already computed
    if ChildData.Sides[Side].DistanceState[Direction]=assdfComputing then begin
      {$IFNDEF DisableChecks}
      DebugLn(['TAutoSizeCtrlData.ComputePositions.ComputePosition CIRCLE detected ',DbgSName(ChildData.Control),' ',dbgs(Side),' ',AutoSizeSideDistDirectionNames[Direction]]);
      {$ENDIF}
      exit(crCircle); // there is a circle
    end;
    if ChildData.Sides[Side].DistanceState[Direction]<>assdfInvalid then
      raise Exception.Create('TAutoSizeCtrlData.ComputePositions.ComputePosition <>assdfInvalid');
      
    // mark as computing
    ChildData.Sides[Side].DistanceState[Direction]:=assdfComputing;
    OppositeSide:=OppositeAnchor[Side];
    
    // try to find good distances to the client area for this side
    Child:=ChildData.Control;
    CurAnchors:=Child.Anchors;
    if Child.Align in [alLeft,alTop,alRight,alBottom,alClient] then
      CurAnchors:=CurAnchors+AnchorAlign[Child.Align];
    if (Side in CurAnchors) then begin
      // this side is anchored
      SiblingData:=ChildData.Sides[Side].CtrlData;
      NewDist:=0;
      if (SiblingData=nil) or (SiblingData=Self) then begin
        // this side is anchored to parent
        // Note: SiblingData=nil can happen, if the reference control
        //       is not visible => use parent as default anchor
        case ChildData.Sides[Side].Side of
        asrLeft,asrRight: // asrTop=asrLeft,asrBottom=asrRight
          begin
            IsSideLeftTop:=(Side in [akLeft,akTop]);
            IsOutwards:=(Direction=assddLeftTop)=IsSideLeftTop;
            IsParentInwards:=(SiblingData=nil)
                          or ((ChildData.Sides[Side].Side=asrLeft)=IsSideLeftTop);
            if not IsParentInwards then begin
              // for example: left side is anchored to right side of parent
              //DebugLn(['ComputePosition ',DbgSName(Child),' Side=',dbgs(Side),' parent outside anchored, Direction=',AutoSizeSideDistDirectionNames[Direction],'  => assdfUncomputable']);
              ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
            end else if IsOutwards then begin
              // for example: left side is anchored to left side of parent
              //              and left distance is needed
              ChildData.Sides[Side].Distance[Direction]:=ChildData.Sides[Side].Space;
              ChildData.Sides[Side].DistanceState[Direction]:=assdfValid;
            end else begin
              // for example: left side is anchored to left side of parent,
              //              right distance is needed
              AddPreferredSize:=true;
              if OppositeSide in CurAnchors then begin
                // compute opposite side first
                Result:=ComputePosition(ChildData,OppositeSide,Direction);
                if Result<>crSuccess then begin
                  {$IFNDEF DisableChecks}
                  DebugLn(['ComputePosition FAILED opposite side: ',DbgSName(Child),' ',dbgs(Side),' ',AutoSizeSideDistDirectionNames[Direction]]);
                  {$ENDIF}
                  exit;
                end;
                if ChildData.Sides[OppositeSide].DistanceState[Direction]<>assdfValid
                then begin
                  ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
                  exit;
                end;
                NewDist:=ChildData.Sides[OppositeSide].Distance[Direction];
                if (ChildData.Sides[OppositeSide].CtrlData<>nil)
                and (ChildData.Sides[OppositeSide].CtrlData<>Self)
                then begin
                  // opposite side is anchored to a sibling
                  if ((OppositeSide in [akLeft,akTop])
                      and (ChildData.Sides[OppositeSide].Side<>asrRight))
                  or ((OppositeSide in [akRight,akBottom])
                      and (ChildData.Sides[OppositeSide].Side<>asrLeft))
                  then
                    AddPreferredSize:=false;
                end;
              end else begin
                NewDist:=ChildData.Sides[OppositeSide].Space;
              end;
              if AddPreferredSize then begin
                if Side in [akLeft,akRight] then
                  inc(NewDist,ChildData.PreferredSize[asboHorizontal])
                else
                  inc(NewDist,ChildData.PreferredSize[asboVertical]);
              end;
              ChildData.Sides[Side].Distance[Direction]:=NewDist;
              ChildData.Sides[Side].DistanceState[Direction]:=assdfValid;
            end;
          end;
        asrCenter:
          begin
            //DebugLn(['ComputePosition ',DbgSName(Child),' Side=',dbgs(Side),' parent anchored, Direction=',AutoSizeSideDistDirectionNames[Direction],'  => assdfUncomputable']);
            ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
          end;
        else
          RaiseGDBException('');
        end;
      end else begin
        // this side is anchored to a sibling
        // first compute needed sides of sibling
        NeededSiblingSides:=[];
        case ChildData.Sides[Side].Side of
        asrLeft: // Note: asrLeft=asrTop
          if Side in [akLeft,akRight] then begin
            Include(NeededSiblingSides,akLeft);
          end else begin
            Include(NeededSiblingSides,akTop);
          end;
        asrRight: // Note: asrRight=asrBottom
          if Side in [akLeft,akRight] then begin
            Include(NeededSiblingSides,akRight);
          end else begin
            Include(NeededSiblingSides,akBottom);
          end;
        asrCenter:
          if Side in [akLeft,akRight] then begin
            NeededSiblingSides:=NeededSiblingSides+[akLeft,akRight];
          end else begin
            NeededSiblingSides:=NeededSiblingSides+[akTop,akBottom];
          end;
        end;
        FoundSides:=[];
        for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
          if a in NeededSiblingSides then begin
            Result:=ComputePosition(SiblingData,a,Direction);
            if (Result=crCircle)
            and ((Child.Align in [alNone,alCustom])
              or (not (Side in AnchorAlign[Child.Align]))) then
            begin
              // there is a circle and it can be broken => break it
              {$IFNDEF DisableChecks}
              DebugLn(['ComputePosition breaking CIRCLE ',DbgSName(Child),' - ',DbgSName(SiblingData.Control),' ',dbgs(a),' ',AutoSizeSideDistDirectionNames[Direction]]);
              {$ENDIF}
              Child.Anchors:=Child.Anchors-[Side];
              Result:=crFixedCircled;
            end;
            if Result<>crSuccess then begin
              {$IFNDEF DisableChecks}
              DebugLn(['ComputePosition FAILED sibling dependency: ',DbgSName(Child),' - ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' a=',dbgs(a),' ',AutoSizeSideDistDirectionNames[Direction]]);
              {$ENDIF}
              exit;
            end;
            if SiblingData.Sides[a].DistanceState[Direction]=assdfValid then
              Include(FoundSides,a);
          end;
        end;
        if FoundSides=[] then begin
          ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
          exit(crSuccess);
        end;

        // this side is anchored to a sibling and some needed sibling sides are valid
        case ChildData.Sides[Side].Side of
        asrLeft,asrRight: // asrLeft=asrTop,asrRight=asrBottom
          begin
            if ChildData.Sides[Side].Side=asrLeft then begin
              if Side in [akLeft,akRight] then
                NewDist:=SiblingData.Sides[akLeft].Distance[Direction]
              else
                NewDist:=SiblingData.Sides[akTop].Distance[Direction];
            end else begin
              if Side in [akLeft,akRight] then
                NewDist:=SiblingData.Sides[akRight].Distance[Direction]
              else
                NewDist:=SiblingData.Sides[akBottom].Distance[Direction];
            end;
            if (Direction=assddLeftTop)=(Side in [akLeft,akTop]) then
              inc(NewDist,ChildData.Sides[Side].Space)
            else
              dec(NewDist,ChildData.Sides[Side].Space);
            //DebugLn(['ComputePosition ',DbgSName(Child),' - ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' ',AutoSizeSideDistDirectionNames[Direction],' NewDist=',NewDist]);
          end;
        asrCenter:
          if Side in [akLeft,akRight] then begin
            if FoundSides=[akLeft,akRight] then begin
              NewDist:=((SiblingData.Sides[akLeft].Distance[Direction]
                        +SiblingData.Sides[akRight].Distance[Direction]) div 2);
            end else if (FoundSides=[akLeft]) then begin
              NewDist:=SiblingData.Sides[akLeft].Distance[Direction]
                     +(SiblingData.PreferredSize[asboHorizontal] div 2);
            end else begin
              NewDist:=SiblingData.Sides[akRight].Distance[Direction]
                     -(SiblingData.PreferredSize[asboHorizontal] div 2);
            end;
            //DebugLn(['ComputePosition BEFORE ',DbgSName(Child),' center to ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' FoundSides=',dbgs(FoundSides),' NewDist=',NewDist,' Direction=',AutoSizeSideDistDirectionNames[Direction],' PreferredSize=',ChildData.PreferredSize[asboHorizontal]]);
            dec(NewDist,ChildData.PreferredSize[asboHorizontal] div 2);
            // use at least the size of the child
            if (Side=akLeft)=(Direction=assddRightBottom) then
              NewDist:=Max(NewDist,ChildData.PreferredSize[asboHorizontal]);
            //DebugLn(['ComputePosition AFTER ',DbgSName(Child),' center to ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' FoundSides=',dbgs(FoundSides),' NewDist=',NewDist,' Direction=',AutoSizeSideDistDirectionNames[Direction],' PreferredSize=',ChildData.PreferredSize[asboHorizontal]]);
          end else begin
            if FoundSides=[akTop,akBottom] then begin
              NewDist:=((SiblingData.Sides[akTop].Distance[Direction]
                        +SiblingData.Sides[akBottom].Distance[Direction]) div 2);
            end else if (FoundSides=[akTop]) then begin
              NewDist:=SiblingData.Sides[akTop].Distance[Direction]
                     +(SiblingData.PreferredSize[asboVertical] div 2);
            end else begin
              NewDist:=SiblingData.Sides[akBottom].Distance[Direction]
                     -(SiblingData.PreferredSize[asboVertical] div 2);
            end;
            dec(NewDist,ChildData.PreferredSize[asboVertical] div 2);
            // use at least the size of the child
            if (Side=akTop)=(Direction=assddRightBottom) then
              NewDist:=Max(NewDist,ChildData.PreferredSize[asboVertical]);
          end;
        end;
        ChildData.Sides[Side].Distance[Direction]:=NewDist;
        ChildData.Sides[Side].DistanceState[Direction]:=assdfValid;

        if (OppositeSide in CurAnchors)
        and ((Direction=assddLeftTop) <> (Side in [akLeft,akTop])) then begin
          // the opposite side is anchored too
          // use the maximum of both anchors
          Result:=ComputePosition(ChildData,OppositeSide,Direction);
          if Result<>crSuccess then begin
            //DebugLn(['ComputePosition (side anchored) FAILED computing opposite side: ',DbgSName(Child),' - ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' ',AutoSizeSideDistDirectionNames[Direction]]);
            exit;
          end;
          case ChildData.Sides[OppositeSide].DistanceState[Direction] of
          assdfValid:
            begin
              // opposite side +- preferred size
              NewDist:=ChildData.Sides[OppositeSide].Distance[Direction];
              CurSize:=0;
              if ((OppositeSide in [akLeft,akTop])
                  and (ChildData.Sides[OppositeSide].Side=asrRight))
              or ((OppositeSide in [akRight,akBottom])
                  and (ChildData.Sides[OppositeSide].Side=asrLeft))
              then begin
                if Side in [akLeft,akRight] then
                  CurSize:=ChildData.PreferredSize[asboHorizontal]
                else
                  CurSize:=ChildData.PreferredSize[asboVertical];
              end;
              inc(NewDist,CurSize);
              // check if opposite side needs a bigger distance
              if ChildData.Sides[Side].Distance[Direction]<NewDist then
                ChildData.Sides[Side].Distance[Direction]:=NewDist;
            end;
          assdfUncomputable: ; // no problem, there is already a value
          else
            raise Exception.Create('TAutoSizeCtrlData.ComputePositions.ComputePosition assdfValid,assdfUncomputable');
          end;
        end;
      end;
    end else if (OppositeSide in CurAnchors)
    and ((Direction=assddLeftTop) <> (Side in [akLeft,akTop])) then begin
      // this side is not anchored, but the opposite is
      // e.g. control is anchored to the right
      // => compute the opposite side first
      Result:=ComputePosition(ChildData,OppositeSide,Direction);
      if Result<>crSuccess then begin
        //DebugLn(['ComputePosition (side not anchored) FAILED computing opposite side: ',DbgSName(Child),' - ',DbgSName(SiblingData.Control),' Side=',dbgs(Side),' ',AutoSizeSideDistDirectionNames[Direction]]);
        exit;
      end;
      case ChildData.Sides[OppositeSide].DistanceState[Direction] of
      assdfValid:
        begin
          // opposite side +- preferred size
          NewDist:=ChildData.Sides[OppositeSide].Distance[Direction];
          if Side in [akLeft,akRight] then
            CurSize:=ChildData.PreferredSize[asboHorizontal]
          else
            CurSize:=ChildData.PreferredSize[asboVertical];
          inc(NewDist,CurSize);
          ChildData.Sides[Side].Distance[Direction]:=NewDist;
          ChildData.Sides[Side].DistanceState[Direction]:=assdfValid;
        end;
      assdfUncomputable:
        ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
      else
        raise Exception.Create('TAutoSizeCtrlData.ComputePositions.ComputePosition assdfValid,assdfUncomputable');
      end;
    end else begin
      // not anchored
      if (Direction=assddLeftTop) = (Side in [akLeft,akTop]) then begin
        NewDist:=ChildData.Sides[Side].Space;
        ChildData.Sides[Side].Distance[Direction]:=NewDist;
        ChildData.Sides[Side].DistanceState[Direction]:=assdfValid;
      end else begin
        //DebugLn(['ComputePosition ',DbgSName(Child),' Side=',dbgs(Side),' not anchored, Direction=',AutoSizeSideDistDirectionNames[Direction],'  => assdfUncomputable']);
        ChildData.Sides[Side].DistanceState[Direction]:=assdfUncomputable;
      end;
    end;
    if not (ChildData.Sides[Side].DistanceState[Direction]
            in [assdfUncomputable,assdfValid])
    then begin
      {$IFNDEF DisableChecks}
      DebugLn(['TAutoSizeCtrlData.ComputePositions.ComputePosition ',DbgSName(Child),' Side=',dbgs(Side),' Direction=',AutoSizeSideDistDirectionNames[Direction]]);
      {$ENDIF}
      raise Exception.Create('TAutoSizeCtrlData.ComputePositions.ComputePosition assdfValid,assdfUncomputable');
    end;
    Result:=crSuccess;
  end;

var
  i: Integer;
  Child: TControl;
  ChildData: TAutoSizeCtrlData;
  a: TAnchorKind;
begin
  Result:=false;
  // for every side try to find a good distance to the client area
  for i:=0 to ChildCount-1 do begin
    Child:=WinControl.Controls[i];
    ChildData:=Children[Child];
    if not ChildData.Visible then continue;
    for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
      if ComputePosition(ChildData,a,assddLeftTop)<>crSuccess then begin
        {$IFNDEF DisableChecks}
        DebugLn(['TAutoSizeCtrlData.ComputePositions Failed to compute LeftTop ',DbgSName(Child),' ',dbgs(a)]);
        {$ENDIF}
        exit;
      end;
      if ComputePosition(ChildData,a,assddRightBottom)<>crSuccess then begin
        {$IFNDEF DisableChecks}
        DebugLn(['TAutoSizeCtrlData.ComputePositions Failed to compute RightBottom ',DbgSName(Child),' ',dbgs(a)]);
        {$ENDIF}
        exit;
      end;
    end;
  end;
  //WriteDebugReport('ComputePositons','  ');
  Result:=true;
end;

constructor TAutoSizeCtrlData.Create(AControl: TControl; IsParent: boolean);
const
  BigInteger = High(Integer) div 4;
var
  CurBorders: TRect;
  a: TAnchorKind;
  AdjustedClientRect: TRect;
  r: TRect;
begin
  //DebugLn(['TAutoSizeCtrlData.Create ',DbgSName(AControl)]);
  Control:=AControl;
  if Control is TWinControl then begin
    WinControl:=TWinControl(Control);
    ChildCount:=WinControl.ControlCount;
  end else
    ChildCount:=0;
  Visible:=Control.IsControlVisible;
  Control.BorderSpacing.GetSpaceAround(CurBorders);
  Borders[akLeft]:=CurBorders.Left;
  Borders[akTop]:=CurBorders.Top;
  Borders[akRight]:=CurBorders.Right;
  Borders[akBottom]:=CurBorders.Bottom;
  BaseBounds:=Control.BaseBounds;
  if (BaseBounds.Left=BaseBounds.Right)
  and (BaseBounds.Top=BaseBounds.Bottom) then
    BaseBounds:=Control.BoundsRect;
  BaseParentClientSize:=Control.BaseParentClientSize;

  if (WinControl<>nil) and IsParent then begin
    AdjustedClientRect:=Rect(0,0,BigInteger,BigInteger);
    WinControl.AdjustClientRect(AdjustedClientRect);
    AdjustedClientBorders[akLeft]:=AdjustedClientRect.Left;
    AdjustedClientBorders[akTop]:=AdjustedClientRect.Top;
    AdjustedClientBorders[akRight]:=BigInteger-AdjustedClientRect.Right;
    AdjustedClientBorders[akBottom]:=BigInteger-AdjustedClientRect.Bottom;
  end else begin
    for a:=low(TAnchorKind) to high(TAnchorKind) do
      AdjustedClientBorders[a]:=0;
    if (BaseParentClientSize.cx=0) and (BaseParentClientSize.cy=0) then begin
      r:=Control.Parent.GetLogicalClientRect;
      BaseParentClientSize.cx:=r.Right;
      BaseParentClientSize.cy:=r.Bottom;
    end;
  end;
end;

destructor TAutoSizeCtrlData.Destroy;
begin
  Clear;
  FreeAndNil(FChilds);
  inherited Destroy;
end;

procedure TAutoSizeCtrlData.Clear;
begin
  ClearSides;
  if FChilds<>nil then
    FChilds.FreeAndClear;
end;

procedure TAutoSizeCtrlData.DoMoveNonAlignedChildren(Side: TAnchorKind;
  var MoveDiff: integer; FindMinimum: boolean);
var
  i: Integer;
  Child: TControl;
  MoveDiffValid: Boolean;
  ChildData: TAutoSizeCtrlData;
  AddSpace: LongInt;
  Position: Integer;
begin
  MoveDiffValid:=false;
  for i:=0 to ChildCount-1 do begin
    Child:=WinControl.Controls[i];
    ChildData:=Children[Child];
    if not ChildData.Visible then continue;
    if IsNotAligned(Child, Side) then begin
      // this is a non aligned control
      //DebugLn(['TAutoSizeCtrlData.DoMoveNonAlignedChilds Child=',DbgSName(Child),' Side=',dbgs(Side)]);
      if FindMinimum then begin
        AddSpace:=Child.BorderSpacing.GetSideSpace(Side);
        if Side=akLeft then
          AddSpace:=Max(AddSpace,WinControl.ChildSizing.LeftRightSpacing)
        else
          AddSpace:=Max(AddSpace,WinControl.ChildSizing.TopBottomSpacing);
        Position:=Child.GetSidePosition(Side)
                  -AddSpace
                  -AdjustedClientBorders[Side];
        if (not MoveDiffValid) or (MoveDiff>Position) then
        begin
          MoveDiff:=Position;
          MoveDiffValid:=true;
        end;
      end else begin
        SetFixedLeftTop(ChildData,Side,Child.GetSidePosition(Side)-MoveDiff);
      end;
    end else if (Child.Align=alCustom)
    and (Side in AnchorAlign[alCustom]) then begin
      if FindMinimum then begin
        // no auto move
      end else begin
        // don't move alCustom, but use them for bounds computation
        SetFixedLeftTop(ChildData,Side,Child.GetSidePosition(Side));
      end;
    end;
  end;
end;

procedure TAutoSizeCtrlData.SetupNonAlignedChildren(MoveNonAlignedChildrenLeft,
  MoveNonAlignedChildrenTop: boolean);
var
  ChildSizing: TControlChildSizing;
  Box: TAutoSizeBox;
  y: Integer;
  RowBox: TAutoSizeBox;
  x: Integer;
  ControlBox: TAutoSizeBox;
  Child: TControl;
  NewBounds: TRect;
  ChildData: TAutoSizeCtrlData;
  MoveDiff: Integer;
  AlignList: TFPList;
  r: TRect;
  i: Integer;
begin
  if ChildCount=0 then exit;
  if WinControl.ChildSizing.Layout=cclNone then begin
    // move the non-aligned controls (i.e. not aligned or fixed anchored)
    // Find the leftmost and topmost of those controls
    MoveDiff:=0;
    DoMoveNonAlignedChildren(akLeft,MoveDiff,true);
    //DebugLn(['TAutoSizeCtrlData.ComputePreferredClientArea akLeft MoveDiff=',MoveDiff]);
    if not MoveNonAlignedChildrenLeft then MoveDiff:=0;
    DoMoveNonAlignedChildren(akLeft,MoveDiff,false);
    MoveDiff:=0;
    DoMoveNonAlignedChildren(akTop,MoveDiff,true);
    //DebugLn(['TAutoSizeCtrlData.ComputePreferredClientArea akTop MoveDiff=',MoveDiff]);
    if not MoveNonAlignedChildrenTop then MoveDiff:=0;
    DoMoveNonAlignedChildren(akTop,MoveDiff,false);
  end else begin
    // there is an automatic layout for non aligned children
    // use the layout engine, but with static values
    ChildSizing:=nil;
    Box:=nil;
    AlignList:=TFPList.Create;
    try
      for i:=0 to WinControl.ControlCount-1 do begin
        Child:=WinControl.Controls[i];
        if Child.IsControlVisible and IsNotAligned(Child) then
          AlignList.Add(Child);
      end;
      if AlignList.Count=0 then exit;
      ChildSizing:=TControlChildSizing.Create(nil);
      Box:=TAutoSizeBox.Create;
      // copy current ChildSizing ...
      ChildSizing.Assign(WinControl.ChildSizing);
      // ... and change it to static layout (i.e. independent of parent size)
      ChildSizing.ShrinkHorizontal:=crsAnchorAligning;
      ChildSizing.EnlargeHorizontal:=crsAnchorAligning;
      ChildSizing.ShrinkVertical:=crsAnchorAligning;
      ChildSizing.EnlargeVertical:=crsAnchorAligning;
      // compute static layout
      r:=WinControl.GetLogicalClientRect;
      Box.AlignControlsInTable(AlignList,ChildSizing,WinControl.BiDiMode,
                               r.Right,r.Bottom,false);
      //Box.WriteDebugReport('TAutoSizeCtrlData.SetupNonAlignedChilds');
      // transfer the coords of the layout
      for y:=0 to Box.ChildCount[asboVertical]-1 do begin
        RowBox:=Box.Children[asboVertical][y];
        for x:=0 to RowBox.ChildCount[asboHorizontal]-1 do begin
          ControlBox:=RowBox.Children[asboHorizontal][x];
          Child:=ControlBox.Control;
          if Child=nil then continue;
          NewBounds:=ControlBox.NewControlBounds;
          //DebugLn(['TAutoSizeCtrlData.SetupNonAlignedChilds ',DbgSName(Child),' ',dbgs(NewBounds)]);
          ChildData:=Children[Child];
          // set left
          SetFixedLeftTop(ChildData,akLeft,NewBounds.Left);
          // set width
          ChildData.PreferredSize[asboHorizontal]:=NewBounds.Right-NewBounds.Left;
          // set top
          SetFixedLeftTop(ChildData,akTop,NewBounds.Top);
          // set height
          ChildData.PreferredSize[asboVertical]:=NewBounds.Bottom-NewBounds.Top;
        end;
      end;
    finally
      ChildSizing.Free;
      Box.Free;
      AlignList.Free;
    end;
  end;
end;

procedure TAutoSizeCtrlData.ComputePreferredClientArea(
  MoveNonAlignedChildrenLeft, MoveNonAlignedChildrenTop: boolean; out
  MoveNonAlignedToLeft, MoveNonAlignedToTop, PreferredClientWidth,
  PreferredClientHeight: integer);
{ if MoveNonAlignedChilds=true then all non-aligned children will be moved in
  parallel, so that at least one child is positioned left most and one child
  is positioned top most.

  Type of controls:
  1. layout: the left and top side of the control has only designed position
      and Parent.ChildSizing.Layout <> cclNone.
      That means: Align=alNone, Anchors=[akLeft,akTop],
      AnchorSide[akLeft/akTop].Control=nil, Parent.ChildSizing.Layout <> cclNone
  2. non-aligned: the left+top side of the control has only a designed position.
      That means: Align=alNone, akLeft is set, AnchorSide[akLeft].Control=nil
      and Parent.ChildSizing.Layout=cclNone
      Same for akTop.
  3. Aligned: Align<>alNone
      These are put consecutively into the remaining space.
      BorderSpacing and AdjustClientRect defines the space.
      The aligned sides automatically set the Anchors and the AnchorSide.Control
      to nil.
      alLeft,alRight,alTop,alBottom have one free side, which can be anchored.
  4. centered: akLeft and akRight are not set
  5. one side anchored: akLeft is set and akRight is not
                     OR akRight is set and akLeft is not
  5.1 anchored to a side (asrLeft,asrRight)
  5.2 anchored to a center (asrCenter)
  6. both sides anchored: akLeft and akRight not
     Note: asrCenter is not allowed here

  Circles and invalid combinations will be automatically fixed.
}

  procedure InitPreferredSizes;
  var
    i: Integer;
    Child: TControl;
    ChildData: TAutoSizeCtrlData;
    CurAnchors: TAnchors;
    CurPreferredWidth: integer;
    CurPreferredHeight: integer;
    UseCurrentWidth: Boolean;
    UseCurrentHeight: Boolean;
    NewWidth: LongInt;
    NewHeight: LongInt;
  begin
    for i:=0 to ChildCount-1 do begin
      Child:=WinControl.Controls[i];
      ChildData:=Children[Child];
      if ChildData.Visible then begin
        CurAnchors:=Child.Anchors;
        if Child.Align in [alLeft,alRight,alTop,alBottom,alClient] then
          CurAnchors:=CurAnchors+AnchorAlign[Child.Align];
        // check if the current Width and/or Height of the Child control can be
        // used. For example: The current Width can be used, if it is independent
        // of the parent's width.
        UseCurrentWidth:=true;
        if Child.AutoSize
        or ([akLeft,akRight]*CurAnchors=[akLeft,akRight]) then
          UseCurrentWidth:=false;
        UseCurrentHeight:=true;
        if Child.AutoSize
        or ([akTop,akBottom]*CurAnchors=[akTop,akBottom]) then
          UseCurrentHeight:=false;

        if (not UseCurrentWidth) or (not UseCurrentHeight) then
          Child.GetPreferredSize(CurPreferredWidth,CurPreferredHeight,true,true);

        //if Child.Name='OtherInfoGroupBox' then debugln(['InitPreferredSizes ',DbgSName(Child),' Bounds=',dbgs(Child.BoundsRect),' Anchors=',dbgs(Child.Anchors),' CurAnchors=',dbgs(CurAnchors),' UseW=',UseCurrentWidth,' UseH=',UseCurrentHeight,' Pref=',CurPreferredWidth,'x',CurPreferredHeight]);
        if UseCurrentWidth then
          NewWidth:=Child.Width
        else if (CurPreferredWidth>0)
        or ((CurPreferredWidth=0) and (csAutoSize0x0 in Child.ControlStyle)) then
          NewWidth:=CurPreferredWidth
        else
          NewWidth:=Max(1,Child.GetDefaultWidth);
        NewWidth:=Child.Constraints.MinMaxWidth(NewWidth);

        if UseCurrentHeight then
          NewHeight:=Child.Height
        else if (CurPreferredHeight>0)
        or ((CurPreferredHeight=0) and (csAutoSize0x0 in Child.ControlStyle)) then
          NewHeight:=CurPreferredHeight
        else
          NewHeight:=Max(1,Child.GetDefaultHeight);
        NewHeight:=Child.Constraints.MinMaxHeight(NewHeight);
      end else begin
        NewWidth:=0;
        NewHeight:=0;
      end;
        
      ChildData.PreferredSize[asboHorizontal]:=NewWidth;
      ChildData.PreferredSize[asboVertical]:=NewHeight;
      //DebugLn(['InitPreferredSizes Child=',DbgSName(Child),' PrefSize=',NewWidth,',',NewHeight]);
    end;
  end;
  
  procedure GetSideAnchor(ChildData: TAutoSizeCtrlData; a: TAnchorKind);
  var
    Child: TControl;
    ReferenceControl: TControl;
    ReferenceSide: TAnchorSideReference;
    Position: Integer;
  begin
    Child:=ChildData.Control;
    Child.AnchorSide[a].GetSidePosition(ReferenceControl,ReferenceSide,Position);
    //DebugLn(['GetSideAnchor Child=',DbgSName(Child),', a=',dbgs(a),' ReferenceControl=',DbgSName(ReferenceControl),' ReferenceSide=',dbgs(a,ReferenceSide)]);
    if ReferenceControl=nil then begin
      // invalid anchor
      // => anchor to parent
      ChildData.Sides[a].CtrlData:=Self;
      if a in [akLeft,akTop] then
        ChildData.Sides[a].Side:=asrLeft
      else
        ChildData.Sides[a].Side:=asrRight;
      exit;
    end;
    if ReferenceControl=Control then
      ChildData.Sides[a].CtrlData:=Self
    else if (ReferenceControl<>nil) and (ReferenceControl.Parent=Control) then
      ChildData.Sides[a].CtrlData:=Children[ReferenceControl];
    ChildData.Sides[a].Side:=ReferenceSide;
    //if ChildData.Sides[a].CtrlData<>nil then DebugLn(['GetSideAnchor Child=',DbgSName(Child),', a=',dbgs(a),' ReferenceControl=',DbgSName(ChildData.Sides[a].CtrlData.Control),' ReferenceSide=',dbgs(a,ChildData.Sides[a].Side)]);
  end;

var
  i: Integer;
  VisibleCount: Integer;
  Child: TControl;
  ChildData: TAutoSizeCtrlData;
  a: TAnchorKind;
  CurNeededClientWH: Integer;
begin
  PreferredClientWidth:=0;
  PreferredClientHeight:=0;
  MoveNonAlignedToLeft:=0;
  MoveNonAlignedToTop:=0;

  if ChildCount=0 then exit;

  // fix control properties
  // check if there are visible children
  VisibleCount:=0;
  for i:=0 to ChildCount-1 do begin
    Child:=WinControl.Controls[i];
    FixControlProperties(Child);
    ChildData:=Children[Child];
    if ChildData.Visible then
      inc(VisibleCount);
  end;
  //DebugLn(['TAutoSizeCtrlData.ComputePreferredClientArea ',DbgSName(Control),' VisibleCount=',VisibleCount]);
  if VisibleCount=0 then begin
    // nothing to do
    exit;
  end;
  
  InitPreferredSizes;

  repeat
    // init dependencies
    for i:=0 to ChildCount-1 do begin
      Child:=WinControl.Controls[i];
      ChildData:=Children[Child];
      ChildData.ClearSides;
      if not ChildData.Visible then continue;
      for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
        ChildData.Sides[a].Side:=asrLeft;
        if (Child.Align in [alLeft,alRight,alTop,alBottom,alClient])
        and (a in AnchorAlign[Child.Align]) then begin
          // this is an aligned side
          // => the dependencies will be setup later in AlignChilds
        end else if a in Child.Anchors then begin
          // this is an anchored side
          GetSideAnchor(ChildData,a);
        end else begin
          // this is a dangling side
        end;
      end;
    end;
    //WriteDebugReport('anchored','');

    SetupNonAlignedChildren(MoveNonAlignedChildrenLeft,MoveNonAlignedChildrenTop);
    //WriteDebugReport('nonaligned','');
    // setup the dependencies for Aligned controls
    AlignChildren;
    //WriteDebugReport('aligned','');

    // setup space for dependencies
    SetupSpace;
    {$IFDEF VerboseAutoSizeCtrlData}
    WriteDebugReport('Space completed','');
    {$ENDIF}

    // calculate the needed positions for all children
  until ComputePositions;
  
  {$IFDEF VerboseAutoSizeCtrlData}
  if WinControl.ClassName='TScrollBox' then
    WriteDebugReport('Positions completed','');
  {$ENDIF}
  
  // compute needed clientwidth/clientheight
  for i:=0 to ChildCount-1 do begin
    Child:=WinControl.Controls[i];
    ChildData:=Children[Child];
    if not ChildData.Visible then continue;
    for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
      if (ChildData.Sides[a].DistanceState[assddLeftTop]=assdfValid)
      and (ChildData.Sides[a].DistanceState[assddRightBottom]=assdfValid)
      then begin
        CurNeededClientWH:=ChildData.Sides[a].Distance[assddLeftTop]
                          +ChildData.Sides[a].Distance[assddRightBottom];
        if a in [akLeft,akRight] then begin
          if PreferredClientWidth<CurNeededClientWH then
            PreferredClientWidth:=CurNeededClientWH;
        end else begin
          if PreferredClientHeight<CurNeededClientWH then
            PreferredClientHeight:=CurNeededClientWH;
        end;
      end;
    end;
  end;

  // compute needed MoveNonAlignedToLeft,MoveNonAlignedToTop
  if MoveNonAlignedChildrenLeft or MoveNonAlignedChildrenTop then
  begin
    MoveNonAlignedToLeft:=Low(integer);
    MoveNonAlignedToTop:=Low(integer);
    for i:=0 to ChildCount-1 do
    begin
      Child:=WinControl.Controls[i];
      ChildData:=Children[Child];
      if not Child.IsControlVisible then continue;
      if IsNotAligned(Child, akLeft) then
      begin
        if MoveNonAlignedChildrenLeft
        and (ChildData.Sides[akLeft].DistanceState[assddLeftTop]=assdfValid) then
          MoveNonAlignedToLeft:=Max(MoveNonAlignedToLeft,
                     Child.Left-ChildData.Sides[akLeft].Distance[assddLeftTop]);
        { the below is only correct, if PreferredClientWidth is realized.
        if (ChildData.Sides[akLeft].DistanceState[assddRightBottom]=assdfValid) then
          MoveNonAlignedToLeft:=Min(MoveNonAlignedToLeft,
            Child.Left
            -(PreferredClientWidth
              -ChildData.Sides[akLeft].Distance[assddRightBottom]));}
      end;
      if IsNotAligned(Child, akTop) then
      begin
        if MoveNonAlignedChildrenTop
        and (ChildData.Sides[akTop].DistanceState[assddLeftTop]=assdfValid) then
          MoveNonAlignedToTop:=Max(MoveNonAlignedToTop,
                       Child.Top-ChildData.Sides[akTop].Distance[assddLeftTop]);
        { the below is only correct, if PreferredClientWidth is realized.
        if (ChildData.Sides[akTop].DistanceState[assddRightBottom]=assdfValid) then
          MoveNonAlignedToTop:=Min(MoveNonAlignedToTop,
            Child.Top
            -(PreferredClientHeight
              -ChildData.Sides[akTop].Distance[assddRightBottom]));}
      end;
    end;
    if MoveNonAlignedToLeft=Low(integer) then MoveNonAlignedToLeft:=0;
    if MoveNonAlignedToTop=Low(integer) then MoveNonAlignedToTop:=0;
  end;

  {$IFDEF VerboseAutoSizeCtrlData}
  //if WinControl.ClassName='TProjectVersionInfoOptionsFrame' then
  DebugLn(['TAutoSizeCtrlData.ComputePreferredClientArea END ',DbgSName(Control),' PreferredClientWidth/height=',PreferredClientWidth,',',PreferredClientHeight]);
  {$ENDIF}
end;

procedure TAutoSizeCtrlData.FixControlProperties(Child: TControl);
var
  a: TAnchorKind;
begin
  // check that all anchor-controls are siblings or the parent
  for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
    if Child.AnchorSide[a].Control=nil then continue;
    if Child.AnchorSide[a].Control=Control then continue;
    if (Child.AnchorSide[a].Control=Child)
    or (Child.AnchorSide[a].Control.Parent<>Control) then begin
      {$IFNDEF DisableChecks}
      DebugLn(['TAutoSizeCtrlData.FixControlProperties ',DbgSName(Child),' a=',dbgs(a),' old=',DbgSName(Child.AnchorSide[a].Control),' new=nil']);
      {$ENDIF}
      Child.AnchorSide[a].Control:=nil;
    end;
  end;

  if Child.Align in [alLeft,alRight,alTop,alBottom,alClient] then begin
    // the aligned sides must be anchored
    Child.Anchors:=Child.Anchors+AnchorAlign[Child.Align];
    for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
      if a in AnchorAlign[Child.Align] then begin
        // the aligned sides can not be anchored to a control
        {$IFNDEF DisableChecks}
        if Child.AnchorSide[a].Control<>nil then
          DebugLn(['TAutoSizeCtrlData.FixControlProperties aligned sides can not be anchored ',DbgSName(Child),' a=',dbgs(a),' old=',DbgSName(Child.AnchorSide[a].Control),' new=nil']);
        {$ENDIF}
        Child.AnchorSide[a].Control:=nil;
      end;
      if Child.AnchorSide[a].Side=asrCenter then begin
        // an aligned control can not be centered
        {$IFNDEF DisableChecks}
        DebugLn(['TAutoSizeCtrlData.FixControlProperties aligned control can not be centered ',DbgSName(Child),' a=',dbgs(a)]);
        {$ENDIF}
        Child.AnchorSide[a].Side:=asrLeft;
        if not (a in AnchorAlign[Child.Align]) then begin
          Child.Anchors:=Child.Anchors-[a];
          Child.AnchorSide[a].Control:=nil;
        end;
      end;
    end;
  end else begin
    for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
      if (a in Child.Anchors)
      and (Child.AnchorSide[a].Side=asrCenter) then begin
        if Child.AnchorSide[a].Control<>nil then begin
          // the control should be centered relative to another control
          if a in [akLeft,akTop] then begin
            // un-anchor the other side
            {$IFNDEF DisableChecks}
            if OppositeAnchor[a] in Child.Anchors then
              DebugLn(['TAutoSizeCtrlData.FixControlProperties control is center-anchored -> unanchor opposite side: ',DbgSName(Child),' a=',dbgs(a)]);
            {$ENDIF}
            Child.Anchors:=Child.Anchors-[OppositeAnchor[a]];
            Child.AnchorSide[OppositeAnchor[a]].Control:=nil;
          end else begin
            // the centering was setup via the right,bottom
            // => normalize it to center via the Left,Top
            DebugLn(['TAutoSizeCtrlData.FixControlProperties control is center-anchored -> normalize it to use Left,Top instead of Bottom,Right: ',DbgSName(Child),' a=',dbgs(a)]);
            Child.AnchorSide[OppositeAnchor[a]].Control:=Child.AnchorSide[a].Control;
            Child.AnchorSide[OppositeAnchor[a]].Side:=asrCenter;
            Child.AnchorSide[a].Control:=nil;
            Child.AnchorSide[a].Side:=asrLeft;
            Child.Anchors:=Child.Anchors+[OppositeAnchor[a]]-[a];
          end;
        end else begin
          // the asrCenter is not active => ok
        end;
      end;
    end;
  end;
end;

procedure TAutoSizeCtrlData.ClearSides;
var
  a: TAnchorKind;
  d: TAutoSizeSideDistDirection;
begin
  for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
    FillChar(Sides[a],SizeOf(TAutoSizeSideData),0);
    for d:=Low(TAutoSizeSideDistDirection) to High(TAutoSizeSideDistDirection) do
      Sides[a].DistanceState[d]:=assdfInvalid;
  end;
end;

procedure TAutoSizeCtrlData.SetFixedLeftTop(ChildData: TAutoSizeCtrlData;
  Side: TAnchorKind; NewLeftTop: integer);
begin
  ChildData.Sides[Side].CtrlData:=Self;
  ChildData.Sides[Side].Side:=asrLeft;
  ChildData.Sides[Side].Space:=NewLeftTop;
  ChildData.Sides[Side].Distance[assddLeftTop]:=NewLeftTop;
  ChildData.Sides[Side].DistanceState[assddLeftTop]:=assdfValid;
end;

procedure TAutoSizeCtrlData.WriteDebugReport(const Title, Prefix: string;
  OnlyVisible: boolean);

  function GetDistance(a: TAnchorKind; d: TAutoSizeSideDistDirection): string;
  begin
    case Sides[a].DistanceState[d] of
    assdfInvalid: Result:='invalid';
    assdfComputing: Result:='computing';
    assdfUncomputable: Result:='uncomputable';
    assdfValid: Result:=dbgs(Sides[a].Distance[d]);
    else Result:='???';
    end;
  end;
  
  function GetSideControl(a: TAnchorKind): string;
  begin
    if Sides[a].CtrlData<>nil then
      Result:=DbgSName(Sides[a].CtrlData.Control)
    else
      Result:='nil';
  end;

var
  a: TAnchorKind;
  i: Integer;
begin
  if Title<>'' then
    DebugLn([Prefix,'TAutoSizeCtrlData.WriteDebugReport ',Title]);
  DebugLn([Prefix,'  Control=',DbgSName(Control),' ChildCount=',ChildCount,' Visible=',Visible,' Anchors=',dbgs(Control.Anchors),' Align=',dbgs(Control.Align)]);
  Debugln([Prefix,'  PreferredSize=',PreferredSize[asboHorizontal],',',PreferredSize[asboVertical]]);
  DebugLn([Prefix,'  Borders=l=',Borders[akLeft],',t=',Borders[akTop],',r=',Borders[akRight],',b=',Borders[akBottom]]);
  DebugLn([Prefix,'  AdjustedClientBorders=l=',AdjustedClientBorders[akLeft],',t=',AdjustedClientBorders[akTop],',r=',AdjustedClientBorders[akRight],',b=',AdjustedClientBorders[akBottom]]);
  for a:=Low(TAnchorKind) to High(TAnchorKind) do begin
    DebugLn([Prefix,'  Side ',dbgs(a),' Control=',GetSideControl(a),
      ' RefSide=',dbgs(a,Sides[a].Side),
      ' Space=',Sides[a].Space,
      ' DistLT=',GetDistance(a,assddLeftTop),
      ' DistBR=',GetDistance(a,assddRightBottom)]);
  end;
  for i:=0 to ChildCount-1 do
    if WinControl.Controls[i].Visible or (not OnlyVisible) then
      Children[WinControl.Controls[i]].WriteDebugReport('',Prefix+dbgs(i)+': ');
end;

{ TAutoSizeBox }

procedure TAutoSizeBox.SetControl(AControl: TControl);
var
  Border: TRect;
  AutoSize0x0: Boolean;
  IsPrefWidthValid: Boolean;
  IsPrefHeightValid: Boolean;
begin
  Control:=AControl;
  MinimumSize[asboHorizontal]:=Control.Constraints.EffectiveMinWidth;
  MinimumSize[asboVertical]:=Control.Constraints.EffectiveMinHeight;
  MaximumSize[asboHorizontal]:=Control.Constraints.EffectiveMaxWidth;
  MaximumSize[asboVertical]:=Control.Constraints.EffectiveMaxHeight;
  Control.GetPreferredSize(PreferredSize[asboHorizontal],
                           PreferredSize[asboVertical],
                           true, // without constraints
                           true  // with theme space
                           );
  //DebugLn(['TAutoSizeBox.SetControl ',DbgSName(Control),' ',PreferredSize[asboHorizontal]]);
  AutoSize0x0:=csAutoSize0x0 in Control.ControlStyle;
  IsPrefWidthValid:=(PreferredSize[asboHorizontal]>0)
                    or (AutoSize0x0 and (PreferredSize[asboHorizontal]=0));
  IsPrefHeightValid:=(PreferredSize[asboVertical]>0)
                    or (AutoSize0x0 and (PreferredSize[asboVertical]=0));

  // apply constraints
  if IsPrefWidthValid then
    PreferredSize[asboHorizontal]:=
      Control.Constraints.MinMaxWidth(PreferredSize[asboHorizontal]);
  if IsPrefHeightValid then
    PreferredSize[asboVertical]:=
      Control.Constraints.MinMaxHeight(PreferredSize[asboVertical]);

  if IsPrefWidthValid
  and (Control.AutoSize or (Control.BorderSpacing.CellAlignHorizontal<>ccaFill))
  then begin
    // the control.width is fixed to its preferred width
    MaximumSize[asboHorizontal]:=PreferredSize[asboHorizontal];
  end;
  if IsPrefHeightValid
  and (Control.AutoSize or (Control.BorderSpacing.CellAlignVertical<>ccaFill))
  then begin
    // the control.height is fixed to its preferred height
    MaximumSize[asboVertical]:=PreferredSize[asboVertical];
  end;

  // if no preferred size is valid use the class defaults
  if not IsPrefWidthValid then
    PreferredSize[asboHorizontal]:=
      Control.Constraints.MinMaxWidth(Control.Scale96ToFont(Control.GetControlClassDefaultSize.CX));
  if not IsPrefHeightValid then
    PreferredSize[asboVertical]:=
      Control.Constraints.MinMaxHeight(Control.Scale96ToFont(Control.GetControlClassDefaultSize.CY));

  //DebugLn(['TAutoSizeBox.SetControl ',DbgSName(Control),' ',PreferredSize[asboHorizontal]]);
  Control.BorderSpacing.GetSpaceAround(Border);
  BorderLeftTop[asboHorizontal]:=Border.Left;
  BorderLeftTop[asboVertical]:=Border.Top;
  BorderRightBottom[asboHorizontal]:=Border.Right;
  BorderRightBottom[asboVertical]:=Border.Bottom;
end;

procedure TAutoSizeBox.AllocateChildsArray(Orientation: TAutoSizeBoxOrientation;
  NewChildCount: Integer);
var
  Size: Integer;
begin
  Size:=NewChildCount*SizeOf(Pointer);
  ReallocMem(Children[Orientation],Size);
  if Size>0 then
    FillChar(Children[Orientation][0],Size,0);
  ChildCount[Orientation]:=NewChildCount;
end;

procedure TAutoSizeBox.AllocateTable(ColCount, RowCount: Integer);
{ This creates a ColCount x RowCount number of cells,
  and a Row of Columns and a Column of Rows.
  
  +-++-++-++-+  +----------+
  | || || || |  |          |
  | || || || |  +----------+
  | || || || |  +----------+
  | || || || |  |          |
  | || || || |  +----------+
  | || || || |  +----------+
  | || || || |  |          |
  +-++-++-++-+  +----------+

}
var
  x, y: Integer;
  RowBox: TAutoSizeBox;
  ColBox: TAutoSizeBox;
  CellBox: TAutoSizeBox;
begin
  AllocateChildsArray(asboHorizontal,ColCount);
  AllocateChildsArray(asboVertical,RowCount);
  // create columns
  for x:=0 to ColCount-1 do begin
    ColBox:=TAutoSizeBox.Create;
    Children[asboHorizontal][x]:=ColBox;
    ColBox.AllocateChildsArray(asboVertical,RowCount);
    ColBox.Parent[asboHorizontal]:=Self;
    ColBox.Index[asboHorizontal]:=x;
    ColBox.Index[asboVertical]:=-1;
  end;
  // create rows
  for y:=0 to RowCount-1 do begin
    RowBox:=TAutoSizeBox.Create;
    Children[asboVertical][y]:=RowBox;
    RowBox.AllocateChildsArray(asboHorizontal,ColCount);
    RowBox.Parent[asboVertical]:=Self;
    RowBox.Index[asboHorizontal]:=-1;
    RowBox.Index[asboVertical]:=y;
  end;
  // create cells
  for y:=0 to RowCount-1 do begin
    RowBox:=Children[asboVertical][y];
    for x:=0 to ColCount-1 do begin
      ColBox:=Children[asboHorizontal][x];
      CellBox:=TAutoSizeBox.Create;
      RowBox.Children[asboHorizontal][x]:=CellBox;
      ColBox.Children[asboVertical][y]:=CellBox;
      CellBox.Parent[asboHorizontal]:=RowBox;
      CellBox.Parent[asboVertical]:=ColBox;
      CellBox.Index[asboHorizontal]:=x;
      CellBox.Index[asboVertical]:=y;
    end;
  end;
end;

procedure TAutoSizeBox.SetTableControls(ListOfControls: TFPList;
  ChildSizing: TControlChildSizing; BiDiMode: TBiDiMode);
var
  i: Integer;
  Row: LongInt;
  Col: LongInt;
  ChildControl: TControl;
  ChildBox: TAutoSizeBox;
  RowCount: LongInt;
  ColCount: Integer;
  LineMax: LongInt;
begin
  // allocate table
  case ChildSizing.Layout of
  cclLeftToRightThenTopToBottom:
    begin
      ColCount:=Max(1,Min(ChildSizing.ControlsPerLine,ListOfControls.Count));
      RowCount:=((ListOfControls.Count-1) div ColCount)+1;
    end;
  cclTopToBottomThenLeftToRight:
    begin
      RowCount:=Max(1,min(ChildSizing.ControlsPerLine,ListOfControls.Count));
      ColCount:=((ListOfControls.Count-1) div RowCount)+1;
    end;
  else
    raise Exception.Create('TAutoSizeBox.SetTableControls TODO');
  end;
  AllocateTable(ColCount,RowCount);

  // set controls
  for i:=0 to ListOfControls.Count-1 do begin
    ChildControl:=TControl(ListOfControls[i]);
    case ChildSizing.Layout of
    cclLeftToRightThenTopToBottom:
      begin
        LineMax:=ChildCount[asboHorizontal];
        Row:=i div LineMax;
        Col:=i mod LineMax;
        if (BiDiMode=bdRightToLeft) then
          Col:=LineMax-Col-1;
        ChildBox:=Children[asboHorizontal][Col].Children[asboVertical][Row];
        ChildBox.SetControl(ChildControl);
        ChildBox.ApplyChildsizingBorders(ChildSizing);
      end;
    cclTopToBottomThenLeftToRight:
      begin
        LineMax:=ChildCount[asboVertical];
        Col:=i div LineMax;
        Row:=i mod LineMax;
        if (BiDiMode=bdRightToLeft) then
          Col:=ChildCount[asboHorizontal]-Col-1;
        ChildBox:=Children[asboVertical][Row].Children[asboHorizontal][Col];
        ChildBox.SetControl(ChildControl);
        ChildBox.ApplyChildsizingBorders(ChildSizing);
      end;
    end;
  end;
end;

procedure TAutoSizeBox.ApplyChildSizingBorders(ChildSizing: TControlChildSizing);
var
  MinBorder: LongInt;
begin
  // left border
  if (Parent[asboHorizontal]=nil) or (Index[asboHorizontal]=0) then
    MinBorder:=ChildSizing.LeftRightSpacing
  else
    MinBorder:=ChildSizing.HorizontalSpacing;
  BorderLeftTop[asboHorizontal]:=Max(BorderLeftTop[asboHorizontal],MinBorder);
  
  // right border
  if (Parent[asboHorizontal]=nil)
  or (Index[asboHorizontal]=Parent[asboHorizontal].ChildCount[asboHorizontal]-1)
  then
    MinBorder:=ChildSizing.LeftRightSpacing
  else
    MinBorder:=ChildSizing.HorizontalSpacing;
  BorderRightBottom[asboHorizontal]:=Max(BorderRightBottom[asboHorizontal],
                                         MinBorder);

  // top border
  if (Parent[asboVertical]=nil) or (Index[asboVertical]=0) then
    MinBorder:=ChildSizing.TopBottomSpacing
  else
    MinBorder:=ChildSizing.VerticalSpacing;
  BorderLeftTop[asboVertical]:=Max(BorderLeftTop[asboVertical],MinBorder);

  // bottom border
  if (Parent[asboVertical]=nil)
  or (Index[asboVertical]=Parent[asboVertical].ChildCount[asboVertical]-1)
  then
    MinBorder:=ChildSizing.TopBottomSpacing
  else
    MinBorder:=ChildSizing.VerticalSpacing;
  BorderRightBottom[asboVertical]:=Max(BorderRightBottom[asboVertical],
                                       MinBorder);
end;

procedure TAutoSizeBox.InitSums;

  procedure Init(o: TAutoSizeBoxOrientation);
  var
    FirstChild: TAutoSizeBox;
  begin
    if ChildCount[o]>0 then begin
      FirstChild:=Children[o][0];
      MaximumSize[o]:=FirstChild.MaximumSize[o];
      MinimumSize[o]:=FirstChild.MinimumSize[o];
      PreferredSize[o]:=FirstChild.PreferredSize[o];
      BorderLeftTop[o]:=FirstChild.BorderLeftTop[o];
      BorderRightBottom[o]:=FirstChild.BorderRightBottom[o];
    end else begin
      MaximumSize[o]:=0;
      MinimumSize[o]:=0;
      PreferredSize[o]:=0;
      BorderLeftTop[o]:=0;
      BorderRightBottom[o]:=0;
    end;
  end;

begin
  Init(asboHorizontal);
  Init(asboVertical);
end;

procedure TAutoSizeBox.SumLine(Orientation: TAutoSizeBoxOrientation;
  DoInit: boolean);
// total orientated minimum is the sum of all minimums plus borders
// total orientated maximum is the sum of all maximums plus borders
// total orientated preferred is the sum of all preferred plus borders
// total orthogonal minimum is the maximum of all minimums
// total orthogonal maximum is the minimum of all maximums
// total orthogonal preferred is the maximum of all preferred
var
  i: Integer;
  Orthogonal: TAutoSizeBoxOrientation;
  CurChild: TAutoSizeBox;
  CurBorder: integer;
  LastChild: TAutoSizeBox;
begin
  if DoInit then InitSums;
  Orthogonal:=SizeBoxOrthogonal[Orientation];
  if ChildCount[Orientation]>0 then begin
    for i:=0 to ChildCount[Orientation]-1 do begin
      CurChild:=Children[Orientation][i];
      
      // add border in Orientation
      CurBorder:=CurChild.BorderLeftTop[Orientation];
      if i>0 then
        CurBorder:=Max(Children[Orientation][i-1].BorderRightBottom[Orientation],
                       CurBorder);
      if MaximumSize[Orientation]>0 then begin
        inc(MaximumSize[Orientation],CurBorder);
      end;
      inc(MinimumSize[Orientation],CurBorder);
      inc(PreferredSize[Orientation],CurBorder);
      // add item size in Orientation
      if MaximumSize[Orientation]>0 then begin
        if CurChild.MaximumSize[Orientation]>0 then
          inc(MaximumSize[Orientation],CurChild.MaximumSize[Orientation])
        else
          MaximumSize[Orientation]:=0;
      end;
      inc(MinimumSize[Orientation],CurChild.MinimumSize[Orientation]);
      inc(PreferredSize[Orientation],CurChild.PreferredSize[Orientation]);
      
      // maximize in Orthogonal
      if MaximumSize[Orthogonal]>0 then begin
        if CurChild.MaximumSize[Orthogonal]>0 then
          MaximumSize[Orthogonal]:=Max(MaximumSize[Orthogonal],
                                       CurChild.MaximumSize[Orthogonal])
        else
          MaximumSize[Orthogonal]:=0;
      end;
      MinimumSize[Orthogonal]:=Max(MinimumSize[Orthogonal],
                                   CurChild.MinimumSize[Orthogonal]);
      PreferredSize[Orthogonal]:=Max(PreferredSize[Orthogonal],
                                     CurChild.PreferredSize[Orthogonal]);
      BorderLeftTop[Orthogonal]:=Max(BorderLeftTop[Orthogonal],
                                     CurChild.BorderLeftTop[Orthogonal]);
      BorderRightBottom[Orthogonal]:=Max(BorderRightBottom[Orthogonal],
                                        CurChild.BorderRightBottom[Orthogonal]);
    end;

    // last border
    LastChild:=Children[Orientation][ChildCount[Orientation]-1];
    BorderRightBottom[Orientation]:=LastChild.BorderRightBottom[Orientation];
  end;
end;

procedure TAutoSizeBox.SumTable;
var
  x: Integer;
  ColBox: TAutoSizeBox;
  y: Integer;
  RowBox: TAutoSizeBox;
begin
  // sum items in rows
  for y:=0 to ChildCount[asboVertical]-1 do begin
    RowBox:=Children[asboVertical][y];
    RowBox.SumLine(asboHorizontal,true);
  end;
  // sum items in columns
  for x:=0 to ChildCount[asboHorizontal]-1 do begin
    ColBox:=Children[asboHorizontal][x];
    ColBox.SumLine(asboVertical,true);
  end;
  // sum rows
  SumLine(asboVertical,true);
  // sum columns
  SumLine(asboHorizontal,false);
end;

procedure TAutoSizeBox.ComputeLeftTops(Orientation: TAutoSizeBoxOrientation);
var
  i: Integer;
  Child: TAutoSizeBox;
  CurLeftTop: Integer;
  s: LongInt;
begin
  CurLeftTop:=0;
  for i:=0 to ChildCount[Orientation]-1 do begin
    Child:=Children[Orientation][i];
    if i=0 then
      inc(CurLeftTop,Child.BorderLeftTop[Orientation]);
    Child.LeftTop[Orientation]:=CurLeftTop;
    inc(CurLeftTop,Child.PreferredSize[Orientation]);
    s:=Child.BorderRightBottom[Orientation];
    if i<ChildCount[Orientation]-1 then
      s:=Max(s,Children[Orientation][i+1].BorderLeftTop[Orientation]);
    inc(CurLeftTop,s);
  end;
end;

procedure TAutoSizeBox.ResizeChildren(ChildSizing: TControlChildSizing;
  Orientation: TAutoSizeBoxOrientation; TargetSize: integer);
type
  TResizeFactor = record
    Scale: double;
    Offset: integer;
  end;
var
  EnlargeStyle: TChildControlResizeStyle;
  ShrinkStyle: TChildControlResizeStyle;
  CurSize: LongInt;

  function GetChildTotalSize: integer;
  // computes the total preferred size of all children of this Orientation
  var
    i: Integer;
    Child: TAutoSizeBox;
    s: LongInt;
  begin
    Result:=0;
    for i:=0 to ChildCount[Orientation]-1 do begin
      Child:=Children[Orientation][i];
      if i=0 then
        inc(Result,Child.BorderLeftTop[Orientation]);
      if Child.PreferredSize[Orientation]<1 then
        Child.PreferredSize[Orientation]:=1;
      inc(Result,Child.PreferredSize[Orientation]);
      s:=Child.BorderRightBottom[Orientation];
      if i<ChildCount[Orientation]-1 then
        s:=Max(s,Children[Orientation][i+1].BorderLeftTop[Orientation]);
      inc(Result,s);
    end;
  end;
  
  procedure GetChildMaxResize(out Factor: TResizeFactor;
    out ResizeableCount: integer);
  // returns the number of children/gaps, that can grow (ResizeableCount)
  // and the maximum factor, by which the children/gaps can grow (TResizeFactor)
  var
    i: Integer;
    CurScale: Double;
    CurOffset: LongInt;
    Child: TAutoSizeBox;
  begin
    Factor.Scale:=0;
    Factor.Offset:=0;
    ResizeableCount:=0;
    case EnlargeStyle of
    
    crsAnchorAligning:
      exit; // no resizing

    crsScaleChilds,crsHomogenousChildResize:
    
      for i:=0 to ChildCount[Orientation]-1 do begin
        Child:=Children[Orientation][i];
        if (Child.MaximumSize[Orientation]>0)
        and (Child.PreferredSize[Orientation]>=Child.MaximumSize[Orientation])
        then begin
          // this child can not be further enlarged
          continue;
        end;
        inc(ResizeableCount);

        case EnlargeStyle of

        crsScaleChilds, crsHomogenousChildResize:
          begin
            if Child.MaximumSize[Orientation]=0 then begin
              CurScale:=double(TargetSize);
              CurOffset:=TargetSize;
            end else begin
              CurScale:=double(Child.MaximumSize[Orientation])
                          /Child.PreferredSize[Orientation];
              CurOffset:=Child.MaximumSize[Orientation]
                         -Child.PreferredSize[Orientation];
            end;
            if (Factor.Offset=0) or (Factor.Offset>CurOffset) then begin
              Factor.Scale:=CurScale;
              Factor.Offset:=CurOffset;
            end;
          end;

        end;
      end;
      
    crsHomogenousSpaceResize:
      if ChildCount[Orientation]>0 then begin
        Factor.Scale:=double(TargetSize);
        Factor.Offset:=TargetSize;
        ResizeableCount:=ChildCount[Orientation]+1;
      end;

    else
      raise Exception.Create('TAutoSizeBox.ResizeChilds');
      
    end;
  end;
  
  procedure EnlargeChilds(const Factor: TResizeFactor);
  var
    i: Integer;
    Child: TAutoSizeBox;
    DiffSize: Integer;
    NewSize: LongInt;
    OldSize: LongInt;
  begin
    for i:=0 to ChildCount[Orientation]-1 do begin
      if TargetSize=CurSize then break;
    
      Child:=Children[Orientation][i];
      if (Child.MaximumSize[Orientation]<0)
      and (Child.PreferredSize[Orientation]>=Child.MaximumSize[Orientation])
      then begin
        // this child can not be further enlarged
        continue;
      end;

      case EnlargeStyle of
      
      crsScaleChilds:
        begin
          // scale PreferredSize
          DiffSize:=TargetSize-CurSize;
          OldSize:=Child.PreferredSize[Orientation];
          NewSize:=round(double(OldSize)*Factor.Scale);
          NewSize:=Min(OldSize+DiffSize,Max(OldSize+1,NewSize));
          inc(CurSize,NewSize-OldSize);
          Child.PreferredSize[Orientation]:=NewSize;
        end;
        
      crsHomogenousChildResize:
        begin
          // add to PreferredSize
          DiffSize:=TargetSize-CurSize;
          OldSize:=Child.PreferredSize[Orientation];
          NewSize:=Min(OldSize+Factor.Offset,OldSize+DiffSize);
          inc(CurSize,NewSize-OldSize);
          Child.PreferredSize[Orientation]:=NewSize;
        end;
        
      crsHomogenousSpaceResize:
        begin
          if i=0 then begin
            // add to left/top border
            DiffSize:=TargetSize-CurSize;
            OldSize:=Child.BorderLeftTop[Orientation];
            NewSize:=Min(OldSize+Factor.Offset,OldSize+DiffSize);
            inc(CurSize,NewSize-OldSize);
            Child.BorderLeftTop[Orientation]:=NewSize;
          end;
          // add to right/bottom border
          DiffSize:=TargetSize-CurSize;
          OldSize:=Child.BorderRightBottom[Orientation];
          NewSize:=Min(OldSize+Factor.Offset,OldSize+DiffSize);
          inc(CurSize,NewSize-OldSize);
          Child.BorderRightBottom[Orientation]:=NewSize;
          if i<ChildCount[Orientation]-1 then
            Child.BorderLeftTop[Orientation]:=NewSize;
        end;
      
      end;
    end;
  end;

  procedure GetChildMinResize(out Factor: TResizeFactor;
    out ResizeableCount: integer);
  // returns the number of children/gaps, that can shrink (ResizeableCount)
  // and the maximum factor, by which the children/gaps can shrink (TResizeFactor)
  var
    i: Integer;
    CurScale: Double;
    CurOffset: LongInt;
    Child: TAutoSizeBox;
  begin
    Factor.Scale:=0;
    Factor.Offset:=0;
    ResizeableCount:=0;
    case ShrinkStyle of

    crsAnchorAligning:
      exit; // no resizing

    crsScaleChilds,crsHomogenousChildResize:
      for i:=0 to ChildCount[Orientation]-1 do begin
        Child:=Children[Orientation][i];
        if (Child.PreferredSize[Orientation]<=Child.MinimumSize[Orientation])
        or (Child.PreferredSize[Orientation]<=1)
        then begin
          // this child can not be further shrinked
          continue;
        end;
        inc(ResizeableCount);

        case ShrinkStyle of

        crsScaleChilds:
          begin
            CurScale:=double(Child.MinimumSize[Orientation])
                      /Child.PreferredSize[Orientation];
            CurOffset:=Child.PreferredSize[Orientation]
                       -Child.MinimumSize[Orientation];
            if (Factor.Offset=0) or (Factor.Scale<CurScale) then begin
              Factor.Scale:=CurScale;
              Factor.Offset:=CurOffset;
            end;
          end;

        crsHomogenousChildResize:
          begin
            CurScale:=double(Child.MinimumSize[Orientation])
                      /Child.PreferredSize[Orientation];
            CurOffset:=Child.PreferredSize[Orientation]
                       -Child.MinimumSize[Orientation];
            if (Factor.Offset=0) or (Factor.Offset>CurOffset) then begin
              Factor.Scale:=CurScale;
              Factor.Offset:=CurOffset;
            end;
          end;

        end;
      end;

    crsHomogenousSpaceResize:
      for i:=0 to ChildCount[Orientation]-1 do begin
        Child:=Children[Orientation][i];
        if i=0 then begin
          CurScale:=double(TargetSize);
          CurOffset:=Child.BorderLeftTop[Orientation];
          if CurOffset>0 then begin
            inc(ResizeableCount);
            if (Factor.Offset=0) or (Factor.Offset>CurOffset) then begin
              Factor.Scale:=CurScale;
              Factor.Offset:=CurOffset;
            end;
          end;
        end;
        CurScale:=double(TargetSize);
        CurOffset:=Child.BorderRightBottom[Orientation];
        if CurOffset>0 then begin
          inc(ResizeableCount);
          if (Factor.Offset=0) or (Factor.Offset>CurOffset) then begin
            Factor.Scale:=CurScale;
            Factor.Offset:=CurOffset;
          end;
        end;
      end;

    else
      raise Exception.Create('TAutoSizeBox.ResizeChilds');

    end;
  end;

  procedure ShrinkChilds(const Factor: TResizeFactor);
  var
    i: Integer;
    Child: TAutoSizeBox;
    DiffSize: Integer;
    NewSize: LongInt;
    OldSize: LongInt;
  begin
    for i:=0 to ChildCount[Orientation]-1 do begin
      Child:=Children[Orientation][i];
      if (Child.PreferredSize[Orientation]<=1)
      or (Child.PreferredSize[Orientation]<=Child.MinimumSize[Orientation])
      then begin
        // this child can not be further shrinked
        continue;
      end;

      case ShrinkStyle of

      crsScaleChilds:
        begin
          // scale PreferredSize
          DiffSize:=CurSize-TargetSize;
          OldSize:=Child.PreferredSize[Orientation];
          NewSize:=Min(round(OldSize*Factor.Scale),OldSize-1);
          NewSize:=Max(Max(1,NewSize),OldSize-DiffSize);
          dec(CurSize,OldSize-NewSize);
          Child.PreferredSize[Orientation]:=NewSize;
        end;

      crsHomogenousChildResize:
        begin
          // add to PreferredSize
          DiffSize:=CurSize-TargetSize;
          OldSize:=Child.PreferredSize[Orientation];
          NewSize:=OldSize-Factor.Offset;
          NewSize:=Max(Max(NewSize,1),OldSize-DiffSize);
          dec(CurSize,OldSize-NewSize);
          Child.PreferredSize[Orientation]:=NewSize;
        end;

      crsHomogenousSpaceResize:
        begin
          if i=0 then begin
            // add to left/top border
            DiffSize:=CurSize-TargetSize;
            OldSize:=Child.BorderLeftTop[Orientation];
            NewSize:=Max(Max(0,OldSize-Factor.Offset),OldSize-DiffSize);
            dec(CurSize,OldSize-NewSize);
            Child.BorderLeftTop[Orientation]:=NewSize;
          end;
          // add to right/bottom border
          DiffSize:=CurSize-TargetSize;
          OldSize:=Child.BorderRightBottom[Orientation];
          NewSize:=Max(Max(0,OldSize-Factor.Offset),OldSize-DiffSize);
          dec(CurSize,OldSize-NewSize);
          Child.BorderRightBottom[Orientation]:=NewSize;
          if i<ChildCount[Orientation]-1 then
            Child.BorderLeftTop[Orientation]:=NewSize;
        end;

      end;
    end;
  end;

var
  MaxResizeFactorPerItem, MinResizeFactorPerItem, CurScale: TResizeFactor;
  ResizeableCount: integer;
  i: Integer;
begin
  CurSize:=GetChildTotalSize;
  //DebugLn('TAutoSizeBox.ResizeChilds CurSize=',dbgs(CurSize),' TargetSize=',dbgs(TargetSize));
  EnlargeStyle:=crsAnchorAligning;
  ShrinkStyle:=crsAnchorAligning;
  i:=0;
  if TargetSize>CurSize then begin
    // enlarge
    if Orientation=asboHorizontal then
      EnlargeStyle:=ChildSizing.EnlargeHorizontal
    else
      EnlargeStyle:=ChildSizing.EnlargeVertical;
    while TargetSize>CurSize do begin
      // shrink children
      GetChildMaxResize(MaxResizeFactorPerItem,ResizeableCount);
      if (ResizeableCount=0) or (MaxResizeFactorPerItem.Offset=0) then break;
      
      CurScale.Scale:=(double(TargetSize)/CurSize);
      if (MaxResizeFactorPerItem.Scale>0)
      and (MaxResizeFactorPerItem.Scale<CurScale.Scale) then
        CurScale.Scale:=MaxResizeFactorPerItem.Scale;
        
      CurScale.Offset:=((TargetSize-CurSize-1) div ResizeableCount)+1;
      // note: the above formula makes sure, that Offset>0
      if (MaxResizeFactorPerItem.Offset>0)
      and (MaxResizeFactorPerItem.Offset<CurScale.Offset) then
        CurScale.Offset:=MaxResizeFactorPerItem.Offset;
      
      EnlargeChilds(CurScale);
      inc(i);
      if i>1000 then RaiseGDBException('TAutoSizeBox.ResizeChilds consistency error');
    end;
  end else if TargetSize<CurSize then begin
    // shrink
    if Orientation=asboHorizontal then
      ShrinkStyle:=ChildSizing.ShrinkHorizontal
    else
      ShrinkStyle:=ChildSizing.ShrinkVertical;
    while TargetSize<CurSize do begin
      GetChildMinResize(MinResizeFactorPerItem,ResizeableCount);
      if (ResizeableCount=0) or (MinResizeFactorPerItem.Offset=0) then break;

      CurScale.Scale:=(double(TargetSize)/CurSize);
      if (MinResizeFactorPerItem.Scale>0)
      and (MinResizeFactorPerItem.Scale>CurScale.Scale) then
        CurScale.Scale:=MinResizeFactorPerItem.Scale;

      CurScale.Offset:=((CurSize-TargetSize-1) div ResizeableCount)+1;
      // note: the above formula makes sure, that Offset>0
      if (MinResizeFactorPerItem.Offset>0)
      and (MinResizeFactorPerItem.Offset>CurScale.Offset) then
        CurScale.Offset:=MinResizeFactorPerItem.Offset;

      ShrinkChilds(CurScale);
      inc(i);
      if i>1000 then RaiseGDBException('TAutoSizeBox.ResizeChilds consistency error');
    end;
  end;
end;

procedure TAutoSizeBox.ResizeTable(ChildSizing: TControlChildSizing;
  TargetWidth, TargetHeight: integer);
begin
  // resize rows and columns
  ResizeChildren(ChildSizing,asboHorizontal,TargetWidth);
  ComputeLeftTops(asboHorizontal);
  ResizeChildren(ChildSizing,asboVertical,TargetHeight);
  ComputeLeftTops(asboVertical);
end;

{procedure TAutoSizeBox.AlignToRight(TargetWidth: integer);

  function GetChildTotalSize(Orientation: TAutoSizeBoxOrientation): integer;
  // computes the total preferred size of all children of this Orientation
  var
    i: Integer;
    Child: TAutoSizeBox;
  begin
    Result:=0;
    for i:=0 to ChildCount[Orientation]-1 do begin
      Child:=Children[Orientation][i];
      if i=0 then
        inc(Result,Child.BorderLeftTop[Orientation]);
      if Child.PreferredSize[Orientation]<1 then
        Child.PreferredSize[Orientation]:=1;
      inc(Result,Child.PreferredSize[Orientation]);
      inc(Result,Child.BorderRightBottom[Orientation]);
    end;
  end;

var
  Orientation: TAutoSizeBoxOrientation;
  i: Integer;
  Child: TAutoSizeBox;
  dx: Integer;
begin
  Orientation:=asboHorizontal;
  dx:=TargetWidth-GetChildTotalSize(Orientation);

  for i:=ChildCount[Orientation]-1 downto 0 do begin
    Child:=Children[Orientation][i];
    inc(Child.LeftTop[Orientation],dx);
  end;
end;
}
procedure TAutoSizeBox.ComputeTableControlBounds(
  ChildSizing: TControlChildSizing; BiDiMode: TBiDiMode);
var
  y: Integer;
  RowBox: TAutoSizeBox;
  x: Integer;
  ColBox: TAutoSizeBox;
  ControlBox: TAutoSizeBox;
  CurControl: TControl;
  NewBounds: TRect;
  CellBounds: TRect;
  NewWidth: LongInt;
  NewHeight: LongInt;
begin
  //WriteDebugReport;
  for y:=0 to ChildCount[asboVertical]-1 do begin
    RowBox:=Children[asboVertical][y];
    for x:=0 to RowBox.ChildCount[asboHorizontal]-1 do begin
      ControlBox:=RowBox.Children[asboHorizontal][x];
      ColBox:=ControlBox.Parent[asboVertical];
      CurControl:=ControlBox.Control;
      if CurControl=nil then continue;
      CellBounds:=Bounds(ColBox.LeftTop[asboHorizontal],
                         RowBox.LeftTop[asboVertical],
                         ColBox.PreferredSize[asboHorizontal],
                         RowBox.PreferredSize[asboVertical]);
      NewBounds.Left:=CellBounds.Left;
      NewBounds.Top:=CellBounds.Top;
      NewWidth:=ControlBox.PreferredSize[asboHorizontal];
      NewHeight:=ControlBox.PreferredSize[asboVertical];
      if (NewWidth<ColBox.PreferredSize[asboHorizontal]) then begin
        // column is bigger than preferred width of the control
        //DebugLn('TAutoSizeBox.SetTableControlBounds ',DbgSName(CurControl),' ',dbgs(ord(CurControl.BorderSpacing.CellAlignHorizontal)));
        case CurControl.BorderSpacing.CellAlignHorizontal of
        ccaFill:        NewWidth:=CellBounds.Right-CellBounds.Left;
        ccaLeftTop,ccaRightBottom:
                   if (CurControl.BorderSpacing.CellAlignHorizontal=ccaRightBottom)
                     =(BidiMode=bdLeftToRight)
                   then
                     NewBounds.Left:=CellBounds.Right-NewWidth;
        ccaCenter:      NewBounds.Left:=NewBounds.Left
                             +(CellBounds.Right-CellBounds.Left-NewWidth) div 2;
        end;
      end else if (NewWidth>ColBox.PreferredSize[asboHorizontal]) then begin
        // column is smaller than preferred width of the control
        if ChildSizing.ShrinkHorizontal
        in [crsScaleChilds,crsHomogenousChildResize]
        then
          NewWidth:=CellBounds.Right-CellBounds.Left;
      end;
      if (NewHeight<ColBox.PreferredSize[asboVertical]) then begin
        // column is bigger than preferred height of the control
        case CurControl.BorderSpacing.CellAlignVertical of
        ccaFill:        NewHeight:=CellBounds.Bottom-CellBounds.Top;
        ccaLeftTop:     ;
        ccaRightBottom: NewBounds.Top:=CellBounds.Bottom-NewHeight;
        ccaCenter:      NewBounds.Top:=NewBounds.Top
                            +(CellBounds.Bottom-CellBounds.Top-NewHeight) div 2;
        end;
      end else if (NewHeight>ColBox.PreferredSize[asboVertical]) then begin
        // column is smaller than preferred height of the control
        if ChildSizing.ShrinkVertical
        in [crsScaleChilds,crsHomogenousChildResize]
        then
          NewHeight:=CellBounds.Bottom-CellBounds.Top;
      end;

      NewBounds.Right:=NewBounds.Left+NewWidth;
      NewBounds.Bottom:=NewBounds.Top+NewHeight;
      ControlBox.NewControlBounds:=NewBounds;
      {$IFDEF CHECK_POSITION}
      if CheckPosition(CurControl) then
        DebugLn(['TAutoSizeBox.ComputeTableControlBounds ',DbgSName(CurControl),
           ' CellBounds=',dbgs(CellBounds),
           ' Preferred=',ControlBox.PreferredSize[asboHorizontal],'x',ControlBox.PreferredSize[asboVertical],
           ' NewBounds=',dbgs(NewBounds)]);
      {$ENDIF}
    end;
  end;
end;

function TAutoSizeBox.SetTableControlBounds(ChildSizing: TControlChildSizing
  ): boolean;
var
  y: Integer;
  RowBox: TAutoSizeBox;
  x: Integer;
  ControlBox: TAutoSizeBox;
  CurControl: TControl;
  NewBounds: TRect;
  OldBounds: TRect;
begin
  Result:=false;
  //WriteDebugReport;
  for y:=0 to ChildCount[asboVertical]-1 do begin
    RowBox:=Children[asboVertical][y];
    for x:=0 to RowBox.ChildCount[asboHorizontal]-1 do begin
      ControlBox:=RowBox.Children[asboHorizontal][x];
      CurControl:=ControlBox.Control;
      if CurControl=nil then continue;
      NewBounds:=ControlBox.NewControlBounds;
      OldBounds:=CurControl.BoundsRect;
      if not CompareRect(@NewBounds,@OldBounds) then begin
        Result:=true;
        CurControl.SetBoundsKeepBase(NewBounds.Left,
                                     NewBounds.Top,
                                     NewBounds.Right-NewBounds.Left,
                                     NewBounds.Bottom-NewBounds.Top);
      end;
    end;
  end;
end;

function TAutoSizeBox.AlignControlsInTable(ListOfControls: TFPList;
  ChildSizing: TControlChildSizing; BiDiMode: TBiDiMode;
  TargetWidth, TargetHeight: integer;
  Apply: boolean): boolean;
// true if a control was modified
begin
  SetTableControls(ListOfControls,ChildSizing,BiDiMode);
  //WriteDebugReport('after SetTableControls');
  SumTable;
  //WriteDebugReport('after SumTable');
  ResizeTable(ChildSizing,TargetWidth,TargetHeight);
  //WriteDebugReport('after ResizeTable');

//  Michl: Commented procedure AlignToRight because of issue #28483, afaics
//         it isn't needed, I'll remove code, if there are no regressions.
//         Commented in revision 55209
//  if BiDiMode=bdRightToLeft then
//    AlignToRight(TargetWidth);

  //WriteDebugReport('after AlignToRight');
  ComputeTableControlBounds(ChildSizing,BiDiMode);
  //WriteDebugReport('after ComputeTableControlBounds');
  Result:=Apply and SetTableControlBounds(ChildSizing);
end;

procedure TAutoSizeBox.WriteDebugReport(const Title: string);
var
  y: Integer;
  RowBox: TAutoSizeBox;
  x: Integer;
  CellBox: TAutoSizeBox;
  ColBox: TAutoSizeBox;
begin
  DebugLn('TAutoSizeBox.WriteDebugReport '+Title
    +' ChildCounts=',dbgs(ChildCount[asboHorizontal]),'x',dbgs(ChildCount[asboVertical]));
  for y:=0 to ChildCount[asboVertical]-1 do begin
    RowBox:=Children[asboVertical][y];
    DbgOut('  Row='+dbgs(y),
            ' MinY='+dbgs(RowBox.MinimumSize[asboVertical]),
            ' MaxY='+dbgs(RowBox.MaximumSize[asboVertical]),
            ' PrefY='+dbgs(RowBox.PreferredSize[asboVertical]),
            ' BorderTop=',dbgs(RowBox.BorderLeftTop[asboVertical]),
            ' #Col='+dbgs(RowBox.ChildCount[asboHorizontal]));
    for x:=0 to RowBox.ChildCount[asboHorizontal]-1 do begin
      CellBox:=RowBox.Children[asboHorizontal][x];
      DbgOut(' CellControl=',DbgSName(CellBox.Control),
             ' Min='+dbgs(CellBox.MinimumSize[asboHorizontal])+'x'+dbgs(CellBox.MinimumSize[asboVertical]),
             ' Max='+dbgs(CellBox.MaximumSize[asboHorizontal])+'x'+dbgs(CellBox.MaximumSize[asboVertical]),
             ' BorderLeft=',dbgs(CellBox.BorderLeftTop[asboHorizontal]),
             ' Pref='+dbgs(CellBox.PreferredSize[asboHorizontal])+'x'+dbgs(CellBox.PreferredSize[asboVertical]),
             '');
    end;
    DebugLn;
  end;
  DbgOut(' Columns: ');
  for x:=0 to ChildCount[asboHorizontal]-1 do begin
    ColBox:=Children[asboHorizontal][x];
    DbgOut(' Col='+dbgs(ColBox.Index[asboHorizontal]),
           ' Min='+dbgs(ColBox.MinimumSize[asboHorizontal]),
           ' Max='+dbgs(ColBox.MaximumSize[asboHorizontal]),
           ' Pref='+dbgs(ColBox.PreferredSize[asboHorizontal]),
           '');
  end;
  DebugLn;
end;

destructor TAutoSizeBox.Destroy;
var
  o: TAutoSizeBoxOrientation;
begin
  // unlink from parent
  for o:=Low(TAutoSizeBoxOrientation) to high(TAutoSizeBoxOrientation) do
    if Parent[o]<>nil then
      Parent[o].Children[o][Index[o]]:=nil;
  Clear;
  inherited Destroy;
end;

procedure TAutoSizeBox.Clear;
var
  o: TAutoSizeBoxOrientation;
  i: Integer;
begin
  // free all children
  for o:=Low(TAutoSizeBoxOrientation) to high(TAutoSizeBoxOrientation) do
    for i:=0 to ChildCount[o]-1 do
      Children[o][i].Free;
  // free children arrays
  for o:=Low(TAutoSizeBoxOrientation) to high(TAutoSizeBoxOrientation) do
    ReallocMem(Children[o],0);
end;

{------------------------------------------------------------------------------
  function TWinControl.AutoSizePhases: TControlAutoSizePhases;
------------------------------------------------------------------------------}
function TWinControl.AutoSizePhases: TControlAutoSizePhases;
begin
  if Parent<>nil then
    Result:=Parent.AutoSizePhases
  else begin
    Result:=[];
    if ([wcfCreatingHandle,wcfCreatingChildHandles]*FWinControlFlags<>[]) then
      Include(Result,caspCreatingHandles);
    if fAutoSizingAll then
      Include(Result,caspComputingBounds);
    if wcfRealizingBounds in FWinControlFlags then
      Include(Result,caspRealizingBounds);
    if wcfUpdateShowing in FWinControlFlags then
      Include(Result,caspShowing);
    if FAutoSizingLockCount>0 then
      Include(Result,caspChangingProperties);
  end;
end;

{------------------------------------------------------------------------------
  function TWinControl.AutoSizeDelayed: boolean;
------------------------------------------------------------------------------}
function TWinControl.AutoSizeDelayed: boolean;
begin
  Result:=(csDestroyingHandle in ControlState)
          or (inherited AutoSizeDelayed);
  //if Result then debugln('TWinControl.AutoSizeDelayed A ',DbgSName(Self),' wcfCreatingChildHandles=',dbgs(wcfCreatingChildHandles in FWinControlFlags),' csLoading=',dbgs(csLoading in ComponentState));
  {$IFDEF VerboseCanAutoSize}
  if Result {and AutoSize} then begin
    if not HandleAllocated then
      debugln('TWinControl.AutoSizeDelayed Self='+DbgSName(Self)+' not HandleAllocated');
  end;
  {$ENDIF}
end;

function TWinControl.AutoSizeDelayedReport: string;
begin
  if csDestroyingHandle in ControlState then
    Result:='csDestroyingHandle'
  else
    Result:=inherited AutoSizeDelayedReport;
end;

{------------------------------------------------------------------------------
  TWinControl AutoSizeDelayedHandle

  Returns true if AutoSize should be skipped / delayed because of its handle.
  A TWinControl needs a parent handle.
------------------------------------------------------------------------------}
function TWinControl.AutoSizeDelayedHandle: Boolean;
begin
  Result := (Parent = nil) and (ParentWindow = 0);
end;

{------------------------------------------------------------------------------
  TWinControl AdjustClientRect
------------------------------------------------------------------------------}
procedure TWinControl.AdjustClientRect(var ARect: TRect);
begin
  // Can be overriden.
  // It's called often, so don't put expensive code here, or cache the result
end;

procedure TWinControl.GetAdjustedLogicalClientRect(out ARect: TRect);
begin
  if not (wcfAdjustedLogicalClientRectValid in FWinControlFlags) then begin
    FAdjustClientRect:=GetLogicalClientRect;
    AdjustClientRect(FAdjustClientRect);
    Include(FWinControlFlags,wcfAdjustedLogicalClientRectValid);
  end;
  ARect:=FAdjustClientRect;
end;

{------------------------------------------------------------------------------
  TWinControl CreateControlAlignList
  
  Creates a list of controls that need to be aligned via TheAlign.
------------------------------------------------------------------------------}
procedure TWinControl.CreateControlAlignList(TheAlign: TAlign;
  AlignList: TFPList; StartControl: TControl);

  function InsertBefore(Control1, Control2: TControl; AAlign: TAlign): Boolean;
  begin
    case AAlign of
      alTop: begin
        Result := (Control1.Top < Control2.Top)
               or ( (Control1.Top = Control2.Top)
                and (Control1.FBaseBounds.Top < Control2.FBaseBounds.Top));
      end;
      alLeft: begin
        Result := (Control1.Left < Control2.Left)
               or ( (Control1.Left = Control2.Left)
                and (Control1.FBaseBounds.Left < Control2.FBaseBounds.Left));
      end;
      // contrary to VCL, LCL uses > for alBottom, alRight
      // Maybe it is a bug in the VCL.
      // This results in first control is put rightmost/bottommost
      alBottom: begin
        Result := ((Control1.Top + Control1.Height) > (Control2.Top + Control2.Height))
               or ( ((Control1.Top + Control1.Height) = (Control2.Top + Control2.Height))
                and (Control1.FBaseBounds.Bottom > Control2.FBaseBounds.Bottom));
      end;
      alRight: begin
        Result := ((Control1.Left + Control1.Width) > (Control2.Left + Control2.Width))
               or ( ((Control1.Left + Control1.Width) = (Control2.Left + Control2.Width))
                and (Control1.FBaseBounds.Right > Control2.FBaseBounds.Right));
      end;
      alCustom: begin
        // CustomAlignInsertBefore returns true when Control2 is inserted before Control1
        // We return true when Control1 is inserted before Control2
        // So swap controls
        Result := CustomAlignInsertBefore(Control2, Control1);
      end;
    else
      Result := False;
    end;
  end;

var
  I, X: Integer;
  Control: TControl;
begin
  AlignList.Clear;

  // first add the current control
  if (StartControl <> nil) and (StartControl.Align = TheAlign) and
     ((TheAlign = alNone) or StartControl.IsControlVisible) then
    AlignList.Add(StartControl);

  // then add all other
  for I := 0 to FAlignOrder.Count - 1 do
  begin
    Control := TControl(FAlignOrder[I]);

    if (Control.Align = TheAlign) and Control.IsControlVisible then
    begin
      if Control = StartControl then Continue;

      X := 0;
      while (X < AlignList.Count) and
            not InsertBefore(Control, TControl(AlignList[X]), TheAlign) do
        Inc(X);
      AlignList.Insert(X, Control);
    end;
  end;
end;

procedure TWinControl.UpdateAlignIndex(aChild: TControl);
// Move child control to position 0 of FAlignOrder
var
  i: Integer;
begin
  if FAlignOrder=nil then
    FAlignOrder:=TFPList.Create;
  i:=FAlignOrder.IndexOf(aChild);
  if i<0 then
    FAlignOrder.Insert(0,aChild)
  else
    FAlignOrder.Move(i,0);
end;

{------------------------------------------------------------------------------
  TWinControl AlignControls

  Align child controls
------------------------------------------------------------------------------}
procedure TWinControl.AlignControls(AControl: TControl;
  var RemainingClientRect: TRect);
{ $DEFINE CHECK_POSITION}
var
  AlignList: TFPList;
  BoundsMutated: boolean;
  LastBoundsMutated: TControl;
  LastBoundsMutatedOld: TRect;
  ParentClientWidth: integer;
  ParentClientHeight: integer;
  RemainingBorderSpace: TRect; // borderspace around RemainingClientRect
                               // e.g. Right=3 means borderspace of 3

  function NeedAlignWork: Boolean;
  var
    I: Integer;
    CurControl: TControl;
  begin
    Result := True;
    for I := ControlCount - 1 downto 0 do
    begin
      CurControl:=Controls[I];
      if (CurControl.Align <> alNone)
      or (CurControl.Anchors <> [akLeft, akTop])
      or (CurControl.AnchorSide[akLeft].Control<>nil)
      or (CurControl.AnchorSide[akTop].Control<>nil)
      or (cfAutoSizeNeeded in CurControl.FControlFlags)
      or (ChildSizing.Layout<>cclNone)
      then Exit;
    end;
    Result := False;
  end;

  function Anchored(Align: TAlign; Anchors: TAnchors): Boolean;
  begin
    case Align of
      alLeft: Result := akLeft in Anchors;
      alTop: Result := akTop in Anchors;
      alRight: Result := akRight in Anchors;
      alBottom: Result := akBottom in Anchors;
      alClient: Result := Anchors = [akLeft, akTop, akRight, akBottom];
    else
      Result := False;
    end;
  end;
  
  procedure DoPosition(Control: TControl; AAlign: TAlign; AControlIndex: Integer);
  var
    NewLeft, NewTop, NewWidth, NewHeight: Integer;
    ParentBaseClientSize: TSize;
    CurBaseBounds: TRect;
    NewRight: Integer;// temp variable, not always valid, use with care !
    NewBottom: Integer;// temp variable, not always valid, use with care !

    MinWidth: Integer;
    MaxWidth: Integer;
    MinHeight: Integer;
    MaxHeight: Integer;
    CurRemainingClientRect: TRect;
    CurRemainingBorderSpace: TRect; // borderspace around RemainingClientRect
                                    // e.g. Right=3 means borderspace of 3
    ChildAroundSpace: TRect;
    AnchorSideCacheValid: array[TAnchorKind] of boolean;
    AnchorSideCache: array[TAnchorKind] of integer;
    CurAnchors: TAnchors;
    CurAlignAnchors: TAnchors;
    OldBounds: TRect;
    NewBounds: TRect;

    AlignInfo: TAlignInfo; // alCustom
    PrefWidth: integer;
    PrefHeight: integer;

    function ConstraintWidth(NewWidth: integer): Integer;
    begin
      Result:=NewWidth;
      if (MaxWidth>=MinWidth) and (Result>MaxWidth) and (MaxWidth>0) then
        Result:=MaxWidth;
      if Result<MinWidth then Result:=MinWidth;
    end;

    procedure ConstraintWidth(var NewLeft, NewWidth: integer);
    var
      ConWidth: LongInt;
    begin
      ConWidth:=ConstraintWidth(NewWidth);
      if ConWidth<>NewWidth then begin
        if [akLeft,akRight]*CurAnchors=[akRight] then
          // move left side, keep right
          inc(NewLeft,NewWidth-ConWidth);
        NewWidth:=ConWidth;
      end;
    end;

    function ConstraintHeight(NewHeight: integer): Integer;
    begin
      Result:=NewHeight;
      if (MaxHeight>=MinHeight) and (Result>MaxHeight) and (MaxHeight>0) then
        Result:=MaxHeight;
      if Result<MinHeight then Result:=MinHeight;
    end;

    procedure ConstraintHeight(var NewTop, NewHeight: integer);
    var
      ConHeight: LongInt;
    begin
      ConHeight:=ConstraintHeight(NewHeight);
      if ConHeight<>NewHeight then begin
        if [akTop,akBottom]*CurAnchors=[akBottom] then
          // move top side, keep bottom
          inc(NewTop,NewHeight-ConHeight);
        NewHeight:=ConHeight;
      end;
    end;
    
    procedure InitAnchorSideCache;
    var
      a: TAnchorKind;
    begin
      for a:=Low(TAnchorKind) to High(TAnchorKind) do
        AnchorSideCacheValid[a]:=false;
    end;
    
    function GetAnchorSidePosition(Kind: TAnchorKind;
      DefaultPosition: Integer): integer;
    // calculates the position in pixels of a side due to anchors
    // For example: if akLeft is set, it returns the coordinate for the left anchor
    var
      CurAnchorSide: TAnchorSide;
      ReferenceControl: TControl;
      ReferenceSide: TAnchorSideReference;
      Position: Integer;
    begin
      if AnchorSideCacheValid[Kind] then begin
        Result:=AnchorSideCache[Kind];
        exit;
      end;
      Result:=DefaultPosition;
      CurAnchorSide:=Control.AnchorSide[Kind];
      //if CheckPosition(Control) and (Kind=akLeft) then debugln(['GetAnchorSidePosition A Self=',DbgSName(Self),' Control=',DbgSName(Control),' CurAnchorSide.Control=',DbgSName(CurAnchorSide.Control),' Spacing=',Control.BorderSpacing.GetSpace(Kind)]);
      CurAnchorSide.GetSidePosition(ReferenceControl,ReferenceSide,Position);
      if ReferenceControl<>nil then begin
        //DebugLn(['GetAnchorSidePosition ',DbgSName(Control),' ReferenceControl=',DbgSName(ReferenceControl)]);
        Result:=Position;
      end;
      //if CheckPosition(Control) and (Kind=akRight) then begin
      //  debugln('GetAnchorSidePosition B Self=',DbgSName(Self),' Control=',DbgSName(Control),' Result=',dbgs(Result),' ReferenceControl=',dbgsName(ReferenceControl));
      //  if ReferenceControl<>nil then DebugLn(['GetAnchorSidePosition ReferenceControl.BoundsRect=',dbgs(ReferenceControl.BoundsRect)]);
      //end;
      AnchorSideCacheValid[Kind]:=true;
      AnchorSideCache[Kind]:=Result;
      if ReferenceSide=asrTop then ;
    end;
    
  begin
    {$IFDEF CHECK_POSITION}
    if CheckPosition(Control) then
    with Control do
      DebugLn('[TWinControl.AlignControls.DoPosition] A Control=',dbgsName(Control),' ',
              dbgs(Left),',',dbgs(Top),',',dbgs(Width),',',dbgs(Height),
              ' recalculate the anchors=',dbgs(Control.Anchors <> AnchorAlign[AAlign]),
              ' Align=',DbgS(AAlign));
    {$ENDIF}

    with Control do begin
      // get constraints
      MinWidth:=Constraints.EffectiveMinWidth;
      if MinWidth<0 then MinWidth:=0;
      MaxWidth:=Constraints.EffectiveMaxWidth;
      MinHeight:=Constraints.EffectiveMinHeight;
      if MinHeight<0 then MinHeight:=0;
      MaxHeight:=Constraints.EffectiveMaxHeight;
      
      // get anchors set by Align
      CurAlignAnchors:=[];
      if Align in [alLeft,alRight,alBottom,alTop,alClient] then
        CurAlignAnchors:=AnchorAlign[Align];
      CurAnchors:=Anchors+CurAlignAnchors;

      // get default bounds
      NewLeft:=Left;
      NewTop:=Top;
      NewWidth:=Width;
      NewHeight:=Height;
      if AutoSize then begin
        GetPreferredSize(PrefWidth,PrefHeight);
        if PrefWidth>0 then NewWidth:=PrefWidth;
        if PrefHeight>0 then NewHeight:=PrefHeight;
      end;
      ConstraintWidth(NewLeft,NewWidth);
      ConstraintHeight(NewTop,NewHeight);
    end;

    InitAnchorSideCache;
    
    { Recalculate the anchors

      Use Anchors to ensure that a control maintains its current position
      relative to an edge of its parent or another sibling.
      This is controlled with the AnchorSide properties.

      1. If AnchorSide[].Control is not set, the distance is kept relative to
      the edges of the client area of its parent.
      When its parent is resized, the control holds its position relative to the
      edges to which it is anchored.
      If a control is anchored to opposite edges of its parent, the control
      stretches when its parent is resized. For example, if a control has its
      Anchors property set to [akLeft,akRight], the control stretches when the
      width of its parent changes.
      Anchors is enforced only when the parent is resized. Thus, for example,
      if a control is anchored to opposite edges of a form at design time and
      the form is created in a maximized state, the control is not stretched
      because the form is not resized after the control is created.
      
      2. If AnchorSide[].Control is set, the BorderSpace properties defines the
      distance to another sibling (i.e. AnchorSide[].Control).
    }
    if (AAlign = alNone) or (Control.Anchors <> CurAlignAnchors)
    then begin
      // at least one side is anchored without align
    
      // Get the base bounds. The base bounds are the user defined bounds
      // without automatic aligning and/or anchoring

      // get base size of parents client area
      ParentBaseClientSize:=Control.FBaseParentClientSize;
      if (ParentBaseClientSize.cx=0)
      and (ParentBaseClientSize.cy=0) then
        ParentBaseClientSize:=Size(ParentClientWidth,ParentClientHeight);

      // get base bounds of Control
      CurBaseBounds:=Control.FBaseBounds;
      if not (cfBaseBoundsValid in FControlFlags) then
        CurBaseBounds:=Control.BoundsRect;

      {$IFDEF CHECK_POSITION}
      //if csDesigning in ComponentState then
      if CheckPosition(Control) then
       DebugLn('[TWinControl.AlignControls.DoPosition] Before Anchoring ',
        ' Self='+DbgSName(Self),' Control='+DbgSName(Control),
        ' CurBaseBounds='+dbgs(CurBaseBounds.Left)+','+dbgs(CurBaseBounds.Top)+','+dbgs(CurBaseBounds.Right-CurBaseBounds.Left)+','+dbgs(CurBaseBounds.Bottom-CurBaseBounds.Top),
        ' ParentBaseClientSize='+dbgs(ParentBaseClientSize.cx)+','+dbgs(ParentBaseClientSize.cy),
        ' ControlParent.Client='+dbgs(ParentClientWidth)+','+dbgs(ParentClientHeight),
        ' NewBounds='+dbgs(NewLeft)+','+dbgs(NewTop)+','+dbgs(NewWidth)+','+dbgs(NewHeight),
        '');
      {$ENDIF}

      if akLeft in CurAnchors then begin
        // keep distance to left side of parent or another sibling
        NewLeft:=GetAnchorSidePosition(akLeft,CurBaseBounds.Left);
        if akRight in CurAnchors then begin
          // keep distance to right side of parent or another sibling
          // -> change the width
          NewRight:=ParentClientWidth
                    -(ParentBaseClientSize.cx-CurBaseBounds.Right);
          if (not (akRight in CurAlignAnchors))
          and (akRight in Control.Anchors) then
            NewRight:=GetAnchorSidePosition(akRight,NewRight);
          NewWidth:=ConstraintWidth(NewRight-NewLeft);
        end else begin
          // do not anchor to the right
          // -> keep new width
        end;
      end else begin
        // do not anchor to the left
        if akRight in CurAnchors then begin
          // keep distance to right side of parent
          // and keep new width
          NewRight:=ParentClientWidth
                    -(ParentBaseClientSize.cx-CurBaseBounds.Right);
          if (not (akRight in CurAlignAnchors))
          and (akRight in Control.Anchors) then
            NewRight:=GetAnchorSidePosition(akRight,NewRight);
          NewLeft:=NewRight-NewWidth;
        end else begin
          // do not anchor to the right
          // -> keep new width and scale center position.
          NewLeft:=MulDiv(ParentClientWidth,
                          (CurBaseBounds.Left+CurBaseBounds.Right) div 2,
                          ParentBaseClientSize.cx)
                   -(NewWidth div 2);
        end;
      end;

      if akTop in CurAnchors then begin
        // keep distance to top side of parent
        NewTop:=GetAnchorSidePosition(akTop,CurBaseBounds.Top);
        if akBottom in CurAnchors then begin
          // keep distance to bottom side of parent
          // -> change the height
          NewBottom:=ParentClientHeight
                    -(ParentBaseClientSize.cy-CurBaseBounds.Bottom);
          if (not (akBottom in CurAlignAnchors))
          and (akBottom in Control.Anchors) then
            NewBottom:=GetAnchorSidePosition(akBottom,NewBottom);
          NewHeight:=ConstraintHeight(NewBottom-NewTop);
        end else begin
          // do not anchor to the bottom
          // -> keep new height
        end;
      end else begin
        // do not anchor to the top
        if akBottom in CurAnchors then begin
          // keep distance to bottom side of parent
          // and keep new height
          NewBottom:=ParentClientHeight
                    -(ParentBaseClientSize.cy-CurBaseBounds.Bottom);
          if (not (akBottom in CurAlignAnchors))
          and (akBottom in Control.Anchors) then
            NewBottom:=GetAnchorSidePosition(akBottom,NewBottom);
          NewTop:=NewBottom-NewHeight;
        end else begin
          // do not anchor to the bottom
          // -> keep new height and scale center position.
          NewTop:=MulDiv(ParentClientHeight,
                         (CurBaseBounds.Top+CurBaseBounds.Bottom) div 2,
                         ParentBaseClientSize.cy)
                  -(NewHeight div 2);
        end;
      end;
      {$IFDEF CHECK_POSITION}
      //if csDesigning in ComponentState then
      if CheckPosition(Control) then
      with Control do begin
        DebugLn(['[TWinControl.AlignControls.DoPosition] After Anchoring',
          ' Self=',DbgSName(Self),
          ' Align=',DbgS(AAlign),
          ' Control=',dbgsName(Control),
          ' Old= l=',Left,',t=',Top,',w=',Width,',h=',Height,
          ' New= l=',NewLeft,',t=',NewTop,',w=',NewWidth,',h=',NewHeight,
          '']);
        DebugLn(['DoPosition akRight=',akRight in CurAnchors,' ',GetAnchorSidePosition(akRight,NewLeft+NewWidth)]);
      end;
      {$ENDIF}
    end;

    // set min size to stop cycling (this should not be needed. But if someone
    // plays/fixes the above code, new bugs can enter and there are far too many
    // combinations to test, and so the LCL can loop for some applications.
    // Prevent this, so users can at least report a bug.)
    if NewWidth<0 then NewWidth:=0;
    if NewHeight<0 then NewHeight:=0;

    case AAlign of
      alLeft,alTop,alRight,alBottom,alClient: begin
        { Realign

          Use Align to align a control to the top, bottom, left, right of a
          form or panel and have it remain there even if the size of the form,
          panel, or component that contains the control changes. When the parent
          is resized, an aligned control also resizes so that it continues to span
          the top, bottom, left, or right edge of the parent (more exact:
          span the remaining client area of its parent).
        }
        NewRight:=NewLeft+NewWidth;
        NewBottom:=NewTop+NewHeight;

        // calculate current RemainingClientRect for the current Control
        CurRemainingClientRect:=RemainingClientRect;
        CurRemainingBorderSpace:=RemainingBorderSpace;
        Control.BorderSpacing.GetSpaceAround(ChildAroundSpace);
        AdjustBorderSpace(CurRemainingClientRect,CurRemainingBorderSpace,
                          ChildAroundSpace);
        {$IFDEF CHECK_POSITION}
        if CheckPosition(Control) then
          DebugLn('DoPosition Before aligning ',dbgsName(Control),' akRight in AnchorAlign[AAlign]=',DbgS(akRight in AnchorAlign[AAlign]),
                  ' akLeft in Control.Anchors=',DbgS(akLeft in Control.Anchors),
                  //' ARect=',ARect.Left,',',ARect.Top,',',ARect.Right,',',ARect.Bottom,
                  ' New=',DbgS(NewLeft,NewTop,NewRight,NewBottom));
        {$ENDIF}

        if akLeft in AnchorAlign[AAlign]
        then begin
          if (akRight in CurAnchors)
          then begin
            // left align and keep right border
            NewLeft:=CurRemainingClientRect.Left;
            NewRight:=NewLeft+ConstraintWidth(NewRight-NewLeft);
          end
          else begin
            // left align and right border free to move (-> keep width)
            dec(NewRight,NewLeft-CurRemainingClientRect.Left);
            NewLeft:=CurRemainingClientRect.Left;
          end;
        end;

        if akTop in AnchorAlign[AAlign]
        then begin
          if (akBottom in CurAnchors)
          then begin
            // top align and keep bottom border
            NewTop:=CurRemainingClientRect.Top;
            NewBottom:=NewTop+ConstraintHeight(NewBottom-NewTop);
          end
          else begin
            // top align and bottom border is free to move (-> keep height)
            dec(NewBottom,NewTop-CurRemainingClientRect.Top);
            NewTop:=CurRemainingClientRect.Top;
          end;
        end;

        if akRight in AnchorAlign[AAlign]
        then begin
          if (akLeft in CurAnchors)
          then begin
            // right align and keep left border
            NewWidth:=ConstraintWidth(CurRemainingClientRect.Right-NewLeft);
            if Align=alRight
            then begin
              // align to right (this overrides the keeping of left border)
              NewRight:=CurRemainingClientRect.Right;
              NewLeft:=NewRight-NewWidth;
            end
            else begin
              // keep left border overrides keeping right border
              NewRight:=NewLeft+NewWidth;
            end;
          end
          else begin
            // right align and left border free to move (-> keep width)
            inc(NewLeft,CurRemainingClientRect.Right-NewRight);
            NewRight:=CurRemainingClientRect.Right;
          end;
        end;

        if akBottom in AnchorAlign[AAlign]
        then begin
          if (akTop in CurAnchors)
          then begin
            // bottom align and keep top border
            NewHeight:=ConstraintHeight(CurRemainingClientRect.Bottom-NewTop);
            if AAlign=alBottom
            then begin
              // align to bottom (this overrides the keeping of top border)
              NewBottom:=CurRemainingClientRect.Bottom;
              NewTop:=NewBottom-NewHeight;
            end
            else begin
              // keeping top border overrides keeping bottom border
              NewBottom:=NewTop+NewHeight;
            end;
          end
          else begin
            // bottom align and top border free to move (-> keep height)
            inc(NewTop,CurRemainingClientRect.Bottom-NewBottom);
            NewBottom:=CurRemainingClientRect.Bottom;
          end;
        end;

        NewWidth:=Max(0,NewRight-NewLeft);
        NewHeight:=Max(0,NewBottom-NewTop);

        {$IFDEF CHECK_POSITION}
        //if csDesigning in Control.ComponentState then
        if CheckPosition(Control) then
          with Control do
            DebugLn('[TWinControl.AlignControls.DoPosition] After Aligning',
            ' ',Name,':',ClassName,
            ' Align=',DbgS(AAlign),
            ' Control=',Name,':',ClassName,
            ' Old=',DbgS(Left,Top,Width,Height),
            ' New=',DbgS(NewLeft,NewTop,NewWidth,NewHeight),
            //' ARect=',ARect.Left,',',ARect.Top,',',ARect.Right-ARect.Left,',',ARect.Bottom-ARect.Top,
            '');
        {$ENDIF}
      end;
      alCustom: begin
        AlignInfo.AlignList := AlignList;
        AlignInfo.Align := alCustom;
        AlignInfo.ControlIndex := AControlIndex;
        CustomAlignPosition(Control, NewLeft, NewTop, NewWidth, NewHeight, RemainingClientRect, AlignInfo);
      end;
    end;
    
    // apply the constraints
    NewWidth:=ConstraintWidth(NewWidth);
    NewHeight:=ConstraintHeight(NewHeight);
    NewRight:=NewLeft+NewWidth;
    NewBottom:=NewTop+NewHeight;

    // set the new bounds
    if (Control.Left <> NewLeft) or (Control.Top <> NewTop)
    or (Control.Width <> NewWidth) or (Control.Height <> NewHeight) then begin
      {$IFDEF CHECK_POSITION}
      //if csDesigning in Control.ComponentState then
      if CheckPosition(Control) then
      with Control do
        DebugLn('[TWinControl.AlignControls.DoPosition] NEW BOUNDS Control=',DbgSName(Control),
                ' New=l=',dbgs(NewLeft)+',t='+dbgs(NewTop)+',w='+dbgs(NewWidth)+',h='+dbgs(NewHeight));
      {$ENDIF}
      // lock the base bounds, so that the new automatic bounds do not override
      // the user settings
      OldBounds:=Control.BoundsRect;
      Control.SetBoundsKeepBase(NewLeft, NewTop, NewWidth, NewHeight);
      //DebugLn(['DoPosition ',DbgSName(Control),' ',cfAutoSizeNeeded in Control.FControlFlags]);
      NewBounds:=Control.BoundsRect;
      BoundsMutated:=not CompareRect(@OldBounds,@NewBounds);
      if BoundsMutated then begin
        LastBoundsMutated:=Control;
        LastBoundsMutatedOld:=OldBounds;
      end;
      // Sometimes SetBounds change the bounds. For example due to constraints.
      // update the new bounds
      with Control do
      begin
        NewLeft:=Left;
        NewTop:=Top;
        NewWidth:=Width;
        NewHeight:=Height;
      end;
      {$IFDEF CHECK_POSITION}
      //if csDesigning in Control.ComponentState then
      if CheckPosition(Control) then
      with Control do
        DebugLn('[TWinControl.AlignControls.DoPosition] AFTER SETBOUND Control=',DbgSName(Control),' Bounds=',DbgS(Control.BoundsRect));
      {$ENDIF}
    end;

    // adjust the remaining client area
    case AAlign of
      alTop:
        begin
          RemainingClientRect.Top:=Min(NewTop+NewHeight,RemainingClientRect.Bottom);
          RemainingBorderSpace.Top:=0;
          AdjustBorderSpace(RemainingClientRect,RemainingBorderSpace,
            0,Max(ChildSizing.VerticalSpacing,ChildAroundSpace.Bottom),0,0);
        end;
      alBottom:
        begin
          RemainingClientRect.Bottom:=Max(NewTop,RemainingClientRect.Top);
          RemainingBorderSpace.Bottom:=0;
          AdjustBorderSpace(RemainingClientRect,RemainingBorderSpace,
            0,0,0,Max(ChildSizing.VerticalSpacing,ChildAroundSpace.Top));
        end;
      alLeft:
        begin
          RemainingClientRect.Left:=Min(NewLeft+NewWidth,RemainingClientRect.Right);
          RemainingBorderSpace.Left:=0;
          AdjustBorderSpace(RemainingClientRect,RemainingBorderSpace,
            Max(ChildSizing.HorizontalSpacing,ChildAroundSpace.Right),0,0,0);
        end;
      alRight:
        begin
          RemainingClientRect.Right:=Max(NewLeft,RemainingClientRect.Left);
          RemainingBorderSpace.Right:=0;
          AdjustBorderSpace(RemainingClientRect,RemainingBorderSpace,
            0,0,Max(ChildSizing.HorizontalSpacing,ChildAroundSpace.Left),0);
        end;
      alClient:
        begin
          // For VCL compatibility alClient should *not* reduce the free space,
          // so that several alClient controls can overlap. This can be used
          // for example to simulate a two page control and edit both pages
          // at designtime with SendToBack.
          // At runtime programs should use Visible instead of BringToFront to
          // reduce overhead.
          // See bug 10380.
        end;
    end;

    {$IFDEF CHECK_POSITION}
    if CheckPosition(Control) then
    with Control do
      DebugLn('[TWinControl.AlignControls.DoPosition] END Control=',
        Name,':',ClassName,
        ' ',DbgS(Left,Top,Width,Height),
        ' Align=',DbgS(AAlign),
        //' ARect=',ARect.Left,',',ARect.Top,',',ARect.Right-ARect.Left,',',ARect.Bottom-ARect.Top,
        '');
    {$ENDIF}
  end;

  procedure DoAlign(AAlign: TAlign);
  var
    I: Integer;
    Control: TControl;
  begin
    //DebugLn(['DoAlign ',DbgSName(Self),' ',dbgs(AALign),' ClientRect=',dbgs(ClientRect),' ControlCount=',ControlCount]);
    CreateControlAlignList(AAlign,AlignList,AControl);
    {$IFDEF CHECK_POSITION}
    if CheckPosition(Self) then
      if AlignList.Count>0 then
      begin
        DbgOut('[TWinControl.AlignControls.DoAlign] Self=',DbgSName(Self),' Control=',dbgsName(AControl),
          ' current align=',DbgS(AAlign),' AlignList=[');
        for i:=0 to AlignList.Count-1 do
        begin
          if i>0 then DbgOut(',');
          DbgOut(DbgSName(TObject(AlignList[i])));
        end;
        DebugLn(']');
      end;
    {$ENDIF}

    // let override handle them
    if DoAlignChildControls(AAlign, AControl, AlignList, RemainingClientRect) then
      exit;
    // remove controls that are positioned by other means
    if (AAlign = alNone) and (AutoSize or (ChildSizing.Layout <> cclNone)) then
      for I := AlignList.Count - 1 downto 0 do
      begin
        Control := TControl(AlignList[I]);
        if IsNotAligned(Control) then AlignList.Delete(I);
      end;
    // anchor/align control
    for I := 0 to AlignList.Count - 1 do
      DoPosition(TControl(AlignList[I]), AAlign, I);
  end;
  
  procedure DoAlignNotAligned;
  // All controls, not aligned by their own properties, can be auto aligned.
  var
    i: Integer;
    Control: TControl;
  begin
    // check if ChildSizing aligning is enabled
    if (ChildSizing.Layout = cclNone) then
      exit;

    /// collect all 'not aligned' controls
    AlignList.Clear;
    for i := 0 to ControlCount - 1 do
    begin
      Control := Controls[i];
      if IsNotAligned(Control) and Control.IsControlVisible then
        AlignList.Add(Control);
    end;
    //debugln('DoAlignNotAligned ',DbgSName(Self),' AlignList.Count=',dbgs(AlignList.Count));
    if AlignList.Count = 0 then exit;

    LastBoundsMutated := nil;
    AlignNonAlignedControls(AlignList, BoundsMutated);
  end;
  
var
  i: Integer;
  OldRemainingClientRect: TRect;
  OldRemainingBorderSpace: TRect;
  MaxTries: LongInt;
  r: TRect;
begin
  //DebugLn(['TWinControl.AlignControls ',DbgSName(Self),' ',not (wcfAligningControls in FWinControlFlags)]);
  if wcfAligningControls in FWinControlFlags then exit;
  Include(FWinControlFlags,wcfAligningControls);
  try
    //if csDesigning in ComponentState then begin
      //DebugLn('[TWinControl.AlignControls] ',Name,':',Classname,' ',Left,',',Top,',',Width,',',Height,' AlignWork=',NeedAlignWork,' ControlCount=',ControlCount);
      //if AControl<>nil then DebugLn('  AControl=',AControl.Name,':',AControl.ClassName);
    //end;
    // first let the DockManager align controls
    if DockSite and UseDockManager and (DockManager<>nil) then
      DockManager.ResetBounds(false);
    AdjustClientRect(RemainingClientRect);
    r:=GetLogicalClientRect;
    ParentClientWidth:=r.Right;
    ParentClientHeight:=r.Bottom;

    if NeedAlignWork then
    begin
      //DebugLn(['TWinControl.AlignControls  ',DbgSName(Self),' RemainingClientRect=',dbgs(RemainingClientRect),' ',dbgs(ClientRect)]);
      RemainingBorderSpace:=Rect(0,0,0,0);
      // adjust RemainingClientRect by ChildSizing properties
      AdjustBorderSpace(RemainingClientRect,RemainingBorderSpace,
                     ChildSizing.LeftRightSpacing,ChildSizing.TopBottomSpacing,
                     ChildSizing.LeftRightSpacing,ChildSizing.TopBottomSpacing);
      //DebugLn('[TWinControl.AlignControls] ',Name,':',Classname,' ',Left,',',Top,',',Width,',',Height,' ClientRect=',RemainingClientRect.Left,',',RemainingClientRect.Top,',',RemainingClientRect.Right,',',RemainingClientRect.Bottom);
      AlignList := TFPList.Create;
      try
        // Auto aligning/anchoring can be very interdependent.
        // In worst case the n-2 depends on the n-1, the n-3 depends on n-2
        // and so forth. This is allowed, so do up to n loop step.
        // Do not more, to avoid endless loops, if there are circlular
        // dependencies.
        MaxTries:=ControlCount;
        {$IFDEF CHECK_POSITION}inc(MaxTries);{$ENDIF}
        for i:=1 to MaxTries do begin
          // align and anchor child controls
          BoundsMutated:=false;
          OldRemainingClientRect:=RemainingClientRect;
          OldRemainingBorderSpace:=RemainingBorderSpace;
          DoAlign(alTop);
          DoAlign(alBottom);
          DoAlign(alLeft);
          DoAlign(alRight);
          DoAlign(alClient);
          DoAlign(alCustom);
          DoAlign(alNone);
          DoAlignNotAligned;
          if not BoundsMutated then break;
          if (i=ControlCount+1) then begin
            DebugLn(['Warning: TWinControl.AlignControls ENDLESS LOOP STOPPED ',DbgSName(Self),' i=',i]);
            if LastBoundsMutated<>nil then
              DebugLn(['Warning: TWinControl.AlignControls LAST CHANGED: ',DbgSName(LastBoundsMutated),' Old=',dbgs(LastBoundsMutatedOld),' Now=',dbgs(LastBoundsMutated.BoundsRect)]);
          end;
          // update again
          RemainingClientRect:=OldRemainingClientRect;
          RemainingBorderSpace:=OldRemainingBorderSpace;
        end;
      finally
        AlignList.Free;
      end;
    end;
    ControlsAligned;
  finally
    Exclude(FWinControlFlags,wcfAligningControls);
  end;
end;

function TWinControl.CustomAlignInsertBefore(AControl1, AControl2: TControl): Boolean;
begin
  Result := Assigned(FOnAlignInsertBefore)
        and FOnAlignInsertBefore(Self, AControl1, AControl2);
end;

procedure TWinControl.CustomAlignPosition(AControl: TControl; var ANewLeft, ANewTop,
  ANewWidth, ANewHeight: Integer; var AlignRect: TRect; AlignInfo: TAlignInfo);
begin
  if Assigned(FOnAlignPosition)
  then FOnAlignPosition(Self, AControl, ANewLeft, ANewTop, ANewWidth, ANewHeight, AlignRect, AlignInfo);
end;

function TWinControl.DoAlignChildControls(TheAlign: TAlign; AControl: TControl;
  AControlList: TFPList; var ARect: TRect): Boolean;
begin
  Result:=false;
end;

procedure TWinControl.DoChildSizingChange(Sender: TObject);
begin
  //debugln('TWinControl.DoChildSizingChange ',DbgSName(Self));
  if ControlCount=0 then exit;
  InvalidatePreferredSize;
  ReAlign;
end;

procedure TWinControl.InvalidatePreferredChildSizes;
var
  AControl: TControl;
  i: Integer;
begin
  for i:=0 to ControlCount-1 do begin
    AControl:=Controls[i];
    Exclude(AControl.FControlFlags,cfPreferredSizeValid);
    Exclude(AControl.FControlFlags,cfPreferredMinSizeValid);
    if AControl is TWinControl then
      Exclude(TWinControl(AControl).FWinControlFlags,wcfAdjustedLogicalClientRectValid);
    if AControl is TWinControl then
      TWinControl(AControl).InvalidatePreferredChildSizes;
  end;
end;

{-------------------------------------------------------------------------------
  procedure TWinControl.DoAutoSize;

  Shrink or enlarge to fit children.
-------------------------------------------------------------------------------}
procedure TWinControl.DoAutoSize;
var
  HasVisibleChilds: boolean;

  procedure GetMoveDiffForNonAlignedChilds(const CurClientRect: TRect;
    out dx, dy: integer);
  // how much can non-aligned-children be moved up and left
  // non-aligned-children: no fixed anchoring or autosizing,
  //      (Align=alNone, visible, AnchorSide[].Control=nil)
  // borderspacing is used
  // e.g. dx=10 means all non-align-children should be moved 10 pixels to the left
  var
    NewClientWidth, NewClientHeight: integer;
    Layout: TAutoSizeCtrlData;
  begin
    if ChildSizing.Layout<>cclNone then begin
      dx:=0;
      dy:=0;
      exit;
    end;

    // get the move requirements for the child controls
    Layout:=nil;
    try
      Layout:=TAutoSizeCtrlData.Create(Self);
      Layout.ComputePreferredClientArea(
          not (csAutoSizeKeepChildLeft in ControlStyle),
          not (csAutoSizeKeepChildTop in ControlStyle),
          dx,dy,NewClientWidth,NewClientHeight);
      if (NewClientWidth<>0) or (NewClientHeight<>0) then ;
      //if (dx<>0) or (dy<>0) then DebugLn(['GetMoveDiffForNonAlignedChilds ',DbgSName(Self),' dx=',dx,' dy=',dy]);
    finally
      Layout.Free;
    end;
  end;
  
var
  I: Integer;
  AControl: TControl;
  PreferredWidth: LongInt;
  PreferredHeight: LongInt;
  CurClientRect: TRect;
  WidthIsFixed: boolean;
  HeightIsFixed: boolean;
  NewLeft: LongInt;
  NewTop: LongInt;
  CurAnchors: TAnchors;
  dx: Integer;
  dy: Integer;
  NewChildBounds: TRect;
  OldChildBounds: TRect;
begin
  {$IFDEF VerboseAllAutoSize}
  debugln('TWinControl.DoAutoSize ',DbgSName(Self));
  {$ENDIF}
  if not (caspComputingBounds in AutoSizePhases) then begin
    {$IFDEF VerboseAllAutoSize}
    DebugLn(['TWinControl.DoAutoSize DELAYED AutoSizePhases=',dbgs(AutoSizePhases)]);
    {$ENDIF}
    AdjustSize;
    exit;
  end;

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DoAutoSize'){$ENDIF};
  try
    // test if resizing is possible
    HasVisibleChilds:=false;
    for i:=0 to ControlCount-1 do
      if Controls[i].IsControlVisible then begin
        HasVisibleChilds:=true;
        break;
      end;

    CurAnchors:=Anchors;
    if Align<>alNone then CurAnchors:=CurAnchors+AnchorAlign[Align];
    WidthIsFixed:=WidthIsAnchored;
    HeightIsFixed:=HeightIsAnchored;

    // move free children as much as possible to left and top (all free children the same)
    if HasVisibleChilds then begin
      CurClientRect:=GetLogicalClientRect;
      AdjustClientRect(CurClientRect);
      // get minimum left, top of non aligned children
      GetMoveDiffForNonAlignedChilds(CurClientRect,dx,dy);
      //DebugLn(['TWinControl.DoAutoSize ',DbgSName(Self),' CurClientRect=',dbgs(CurClientRect)]);

      if (dx<>0) or (dy<>0) then begin
        // move all free children to left and top of client area
        //DebugLn(['TWinControl.DoAutoSize ',DbgSName(Self),' dx=',dbgs(dx),' dy=',dbgs(dy),' CurClientRect=',dbgs(CurClientRect),' CurAnchors=',dbgs(CurAnchors),' IsFixed: w=',WidthIsFixed,' h=',HeightIsFixed]);
        for I := 0 to ControlCount - 1 do begin
          AControl:=Controls[I];
          if not AControl.IsControlVisible then continue;
          if AControl.Align<>alNone then continue;
          //DebugLn(['TWinControl.DoAutoSize BEFORE ',DbgSName(AControl),' ',dbgs(AControl.BoundsRect)]);
          NewChildBounds:=AControl.BoundsRect;
          if (akLeft in AControl.Anchors)
          and (AControl.AnchorSide[akLeft].Control=nil) then begin
            dec(NewChildBounds.Left,dx);
            if not (akRight in AControl.Anchors) then
              dec(NewChildBounds.Right,dx);
          end;
          if (akTop in AControl.Anchors)
          and (AControl.AnchorSide[akTop].Control=nil) then begin
            dec(NewChildBounds.Top,dy);
            if not (akBottom in AControl.Anchors) then
              dec(NewChildBounds.Bottom,dy);
          end;
          // Important: change the BaseBounds too, otherwise the changes will be undone by AlignControls
          OldChildBounds:=AControl.BoundsRect;
          if not CompareRect(@OldChildBounds,@NewChildBounds) then begin
            //DebugLn(['TWinControl.DoAutoSize moving child: ',DbgSName(AControl),' Old=',dbgs(OldChildBounds),' New=',dbgs(NewChildBounds)]);
            AControl.BoundsRect:=NewChildBounds;
            //DebugLn(['TWinControl.DoAutoSize AFTER ',DbgSName(AControl),' ',dbgs(AControl.BoundsRect)]);
          end;
        end;
      end;
    end;

    // autosize control to preferred size
    if (not WidthIsFixed) or (not HeightIsFixed) then begin
      GetPreferredSize(PreferredWidth,PreferredHeight,
                       false,// with constraints
                       true // with theme space
                       );
      //if ControlCount>0 then DebugLn(['TWinControl.DoAutoSize ',DbgSName(Self),' PreferredWidth=',PreferredWidth,' PreferredHeight=',PreferredHeight,' ControlCount=',ControlCount]);
    end else begin
      PreferredWidth:=0;
      PreferredHeight:=0;
    end;
    if WidthIsFixed or (PreferredWidth<0)
    or ((PreferredWidth=0) and (not (csAutoSize0x0 in ControlStyle))) then
      PreferredWidth:=Constraints.MinMaxWidth(Width);
    if HeightIsFixed or (PreferredHeight<0)
    or ((PreferredHeight=0) and (not (csAutoSize0x0 in ControlStyle))) then
      PreferredHeight:=Constraints.MinMaxHeight(Height);

    // set new size
    {$IF defined(VerboseAutoSize) or defined(VerboseAllAutoSize)}
    debugln(['TWinControl.DoAutoSize A ',DbgSName(Self),' Cur=',Width,'x',Height,' Prefer=',PreferredWidth,'x',PreferredHeight,' WidgetClass=',WidgetSetClass.ClassName,' Fixed=',WidthIsFixed,'x',HeightIsFixed]);
    {$ENDIF}
    if (PreferredWidth<>Width) or (PreferredHeight<>Height) then begin
      // adjust Left/Top as well to reduce auto sizing overhead
      NewLeft:=Left;
      NewTop:=Top;
      if akRight in CurAnchors then
        inc(NewLeft,Width-PreferredWidth);
      if akBottom in CurAnchors then
        inc(NewTop,Height-PreferredHeight);
      //if CompareText(Name,'NewUnitOkButton')=0 then
        //debugln(['DoAutoSize Resize ',DbgSName(Self),' Old=',dbgs(BoundsRect),' New=',dbgs(Bounds(NewLeft,NewTop,PreferredWidth,PreferredHeight)),' WidthIsFixed=',WidthIsFixed,' HeightIsFixed=',HeightIsFixed,' Align=',dbgs(Align),' Anchors=',dbgs(Anchors)]);
      SetBoundsKeepBase(NewLeft,NewTop,PreferredWidth,PreferredHeight);
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DoAutoSize'){$ENDIF};
  end;
end;

procedure TWinControl.DoAllAutoSize;

  function CheckHandleAllocated(AWinControl: TWinControl): boolean;
  // true if a handle was missing
  var
    i: Integer;
    ChildWinControl: TWinControl;
  begin
    if AWinControl.HandleObjectShouldBeVisible and (not AWinControl.HandleAllocated) then
    begin
      {$IFDEF VerboseAllAutoSize}
      DebugLn(['TWinControl.DoAllAutoSize CREATE HANDLE ',DbgSName(AWinControl)]);
      {$ENDIF}
      AWinControl.HandleNeeded;
      Exit(True);
    end;
    Result := False;
    for i := 0 to AWinControl.ControlCount - 1 do
    begin
      ChildWinControl := TWinControl(AWinControl.Controls[i]);
      if (ChildWinControl is TWinControl) and CheckHandleAllocated(ChildWinControl) then
        Result:=true;
    end;
  end;

  procedure ClearRequests(AControl: TControl);
  var
    i: Integer;
  begin
    Exclude(AControl.FControlFlags,cfAutoSizeNeeded);
    if AControl is TWinControl then
      for i:=0 to TWinControl(AControl).ControlCount-1 do
        ClearRequests(TWinControl(AControl).Controls[i]);
  end;

  procedure UpdateShowingRecursive(AWinControl: TWinControl;
    OnlyChildren: boolean);
  var
    i: Integer;
  begin
    // first make the children visible
    if AWinControl.FControls<>nil then
      for i:=0 to AWinControl.FControls.Count-1 do
        if TObject(AWinControl.FControls[i]) is TWinControl then
          UpdateShowingRecursive(TWinControl(AWinControl.FControls[i]),false);
    // then make the control visible
    if not OnlyChildren and AWinControl.HandleObjectShouldBeVisible and not AWinControl.Showing then
      AWinControl.UpdateShowing;
  end;

var
  RealizeCounter: Integer;
  UpdateShowingCounter: Integer;
begin
  if wcfAllAutoSizing in FWinControlFlags then exit;
  if AutoSizeDelayed then exit;

  {$IFDEF VerboseAllAutoSize}
  DebugLn(['TWinControl.DoAllAutoSize START ',DbgSName(Self),' ',dbgs(BoundsRect)]);
  {$ENDIF}
  Include(FWinControlFlags,wcfAllAutoSizing);
  try
    // create needed handles
    if HandleObjectShouldBeVisible then begin
      if CheckHandleAllocated(Self) then begin
        // a new handle was created
      end;
    end else begin
      // no autosize possible => remove needed flags
      ClearRequests(Self);
      exit;
    end;

    RealizeCounter:=0;
    UpdateShowingCounter:=0;
    while (not AutoSizeDelayed) do
    begin
      // compute all sizes for LCL objects without touching the widgetset
      {$IFDEF VerboseAllAutoSize}
      DebugLn(['TWinControl.DoAllAutoSize COMPUTE BOUNDS ',DbgSName(Self),' old=',dbgs(BoundsRect)]);
      {$ENDIF}
      inherited DoAllAutoSize;
      if cfAutoSizeNeeded in FControlFlags then RaiseGDBException('');
      AllAutoSized;
      // send all new bounds to widgetset
      {$IFDEF VerboseAllAutoSize}
      DebugLn(['TWinControl.DoAllAutoSize REALIZE BOUNDS ',DbgSName(Self),' lclbounds=',dbgs(BoundsRect)]);
      {$ENDIF}
      inc(RealizeCounter);
      if RealizeCounter=100 then
        Include(FWinControlFlags,wcfKillIntfSetBounds);
      RealizeBoundsRecursive;
      if (cfAutoSizeNeeded in FControlFlags) then continue; // repeat computing bounds
      RealizeCounter:=0;
      inc(UpdateShowingCounter);
      // make child handles visible
      {$IFDEF VerboseAllAutoSize}
      DebugLn(['TWinControl.DoAllAutoSize UPDATESHOWING children ',DbgSName(Self),' lclbounds=',dbgs(BoundsRect)]);
      {$ENDIF}
      Include(FWinControlFlags,wcfUpdateShowing);
      try
        UpdateShowingRecursive(Self,true);
      finally
        Exclude(FWinControlFlags,wcfUpdateShowing);
      end;
      // check if another turn is needed
      if not (cfAutoSizeNeeded in FControlFlags) then break; // complete
    end;
    {$IFDEF VerboseAllAutoSize}
    DebugLn(['TWinControl.DoAllAutoSize END ',DbgSName(Self),' ',dbgs(BoundsRect)]);
    {$ENDIF}
  finally
    FWinControlFlags:=FWinControlFlags-[wcfAllAutoSizing,wcfKillIntfSetBounds];
  end;
  // make handle visible => this can trigger events like Form.OnShow where
  // application does arbitrary stuff
  {$IFDEF VerboseAllAutoSize}
  DebugLn(['TWinControl.DoAllAutoSize UPDATESHOWING self ',DbgSName(Self),' lclbounds=',dbgs(BoundsRect)]);
  {$ENDIF}
  if not (wcfUpdateShowing in FWinControlFlags) then
  begin
    Include(FWinControlFlags, wcfUpdateShowing);
    try
      if HandleObjectShouldBeVisible and not Showing then
        UpdateShowing
      else begin
        {$IFDEF VerboseAllAutoSize}
        DebugLn(['TWinControl.DoAllAutoSize not UPDATESHOWING self ',DbgSName(Self),' because HandleObjectShouldBeVisible=',HandleObjectShouldBeVisible,' Showing=',Showing]);
        {$ENDIF}
      end;
    finally
      Exclude(FWinControlFlags, wcfUpdateShowing);
    end;
  end;
end;

procedure TWinControl.AllAutoSized;
begin
  // see TCustomForm.AllAutoSized
end;

{------------------------------------------------------------------------------
  TWinControl BroadCast
------------------------------------------------------------------------------}
procedure TWinControl.BroadCast(var ToAllMessage);
var
  I: Integer;
begin
  for I := 0 to ControlCount - 1 do
  begin
    Controls[I].WindowProc(TLMessage(ToAllMessage));
    if TLMessage(ToAllMessage).Result <> 0 then Exit;
  end;
end;

procedure TWinControl.NotifyControls(Msg: Word);
var
  ToAllMessage: TLMessage;
begin
  ToAllMessage.Msg := Msg;
  ToAllMessage.WParam := 0;
  ToAllMessage.LParam := 0;
  ToAllMessage.Result := 0;
  Broadcast(ToAllMessage);
end;

procedure TWinControl.DefaultHandler(var AMessage);
begin
  TWSWinControlClass(WidgetSetClass).DefaultWndHandler(Self, AMessage);
end;


{------------------------------------------------------------------------------
  TWinControl CanFocus


------------------------------------------------------------------------------}
function TWinControl.CanFocus: Boolean;
var
  Control: TWinControl;
  Form: TCustomForm;
begin
  Result := False;
  //Verify that every parent is enabled and visible before returning true.
  Form := GetParentForm(Self);
  if Form <> nil then
  begin
    Control := Self;
    repeat
      if Control = Form then break;
      // test all except the Form if it is visible and enabled
      if not (Control.IsControlVisible and Control.Enabled) then Exit;
      Control := Control.Parent;
    until False;
    Result := True;
  end;
end;

{------------------------------------------------------------------------------
  TWinControl CanSetFocus

  CanSetFocus should be prefered over CanFocus if used in CanSetFocus/SetFocus
  combination

  if MyControl.CanSetFocus then
    MyControl.SetFocus;

  because it checks also if the parent form can receive focus and thus prevents
  the "cannot focus an invisible window" LCL exception.
------------------------------------------------------------------------------}
function TWinControl.CanSetFocus: Boolean;
var
  Control: TWinControl;
begin
  Control := Self;
  while True do
  begin
    // test if all are visible and enabled
    if not (Control.IsControlVisible and Control.Enabled) then
      Exit(False);
    if not Assigned(Control.Parent) then
      Break;
    Control := Control.Parent;
  end;
  Result := Control is TCustomForm;//the very top parent must be a form
end;

{------------------------------------------------------------------------------
  TWinControl CreateSubClass
------------------------------------------------------------------------------}
procedure TWinControl.CreateSubClass(var Params: TCreateParams;
  ControlClassName: PChar);
begin
  // TODO: Check if we need this method
end;

{------------------------------------------------------------------------------
  TWinControl DisableAlign
------------------------------------------------------------------------------}
procedure TWinControl.DisableAlign;
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DisableAlign'){$ENDIF};
end;

{-------------------------------------------------------------------------------
  TWinControl DoAdjustClientRectChange

  Asks the interface if clientrect has changed since last AlignControl
  and calls AdjustSize on change.
-------------------------------------------------------------------------------}
procedure TWinControl.DoAdjustClientRectChange(const InvalidateRect: Boolean = True);
var
  R: TRect;
begin
  if InvalidateRect then
    InvalidateClientRectCache(False);
  R := GetClientRect;
  AdjustClientRect(R);
  //if CheckPosition(Self) then
    //DebugLn(['TWinControl.DoAdjustClientRectChange ',DbgSName(Self),' new=',dbgs(r),' old=',dbgs(FAdjustClientRectRealized),' ',CompareRect(@r,@FAdjustClientRectRealized)]);
  if not CompareRect(@R, @FAdjustClientRectRealized) then
  begin
    // client rect changed since last AlignControl
    {$IF defined(VerboseAllAutoSize) or defined(VerboseClientRectBugFix) or defined(VerboseIntfSizing) or defined(VerboseOnResize)}
    DebugLn(['TWinControl.DoAdjustClientRectChange ClientRect changed ',DbgSName(Self),
      ' Old=',Dbgs(FAdjustClientRectRealized),' New=',DbgS(R)]);
    {$ENDIF}
    FAdjustClientRectRealized := R;
    AdjustSize;
    Resize;
  end;
end;

{-------------------------------------------------------------------------------
  TWinControl DoConstraintsChange
  Params: Sender : TObject

  Call inherited, then send the constraints to the interface
-------------------------------------------------------------------------------}
procedure TWinControl.DoConstraintsChange(Sender : TObject);
begin
  inherited DoConstraintsChange(Sender);
  //debugln('TWinControl.DoConstraintsChange ',DbgSName(Self),' HandleAllocated=',dbgs(HandleAllocated));
  if HandleAllocated then
    TWSWinControlClass(WidgetSetClass).ConstraintsChange(Self);
end;

{-------------------------------------------------------------------------------
  TWinControl InvalidateClientRectCache(WithChildControls: boolean)

  The clientrect is cached. Call this procedure to invalidate the cache, so that
  next time the clientrect is fetched from the interface.
-------------------------------------------------------------------------------}
procedure TWinControl.InvalidateClientRectCache(WithChildControls: boolean);
var
  I: Integer;
begin
  {$IFDEF VerboseClientRectBugFix}
  if Name=CheckClientRectName then begin
    DebugLn(['TWinControl.InvalidateClientRectCache ',DbgSName(Self)]);
    //DumpStack;
  end;
  {$ENDIF}
  Exclude(FWinControlFlags,wcfAdjustedLogicalClientRectValid);
  Include(FWinControlFlags,wcfClientRectNeedsUpdate);

  if WithChildControls then begin
    // invalidate clients too
    if Assigned(FControls) then
      for I := 0 to FControls.Count - 1 do
        if TObject(FControls.Items[I]) is TWinControl then
          TWinControl(FControls.Items[I]).InvalidateClientRectCache(true);
  end;
  InvalidatePreferredSize;
end;

{-------------------------------------------------------------------------------
  TWinControl ClientRectNeedsInterfaceUpdate

  The clientrect is cached. Check if cache is valid.
-------------------------------------------------------------------------------}
function TWinControl.ClientRectNeedsInterfaceUpdate: boolean;
var
  InterfaceWidth, InterfaceHeight: integer;
  IntfClientRect: TRect;
begin
  if (not HandleAllocated) or (csDestroyingHandle in ControlState)
  or (csDestroying in ComponentState)
  then
    exit(false);
  if wcfClientRectNeedsUpdate in FWinControlFlags then
    exit(true);
  // get the current interface bounds
  LCLIntf.GetWindowSize(Handle,InterfaceWidth,InterfaceHeight);
  LCLIntf.GetClientRect(Handle,IntfClientRect);
  // The LCL is not always in sync with the interface.
  // Add the difference between LCL size and interface size to the
  // interface clientrect
  inc(IntfClientRect.Right,Width-InterfaceWidth);
  inc(IntfClientRect.Bottom,Height-InterfaceHeight);
  Result:=(FClientWidth<>IntfClientRect.Right)
       or (FClientHeight<>IntfClientRect.Bottom);
  {$IFDEF VerboseClientRectBugFix}
  if (Name=CheckClientRectName) and Result then
    DebugLn(['TWinControl.ClientRectNeedsInterfaceUpdate ',DbgSName(Self),' ',dbgs(IntfClientRect)]);
  {$ENDIF}
end;

{-------------------------------------------------------------------------------
  TWinControl DoSetBounds
  Params: ALeft, ATop, AWidth, AHeight : integer

  Anticipate the new clientwidth/height and call inherited

  Normally the clientwidth/clientheight is adjusted automatically by the
  interface. But it is up to interface when this will be done. The gtk for
  example just puts resize requests into a queue. The LCL would resize the
  children just after this procedure due to the clientrect. On complex forms with
  lots of nested controls, this would result in thousands of resizes.
  Changing the clientrect in the LCL to the most probable size reduces
  unneccessary resizes.
-------------------------------------------------------------------------------}
procedure TWinControl.DoSetBounds(ALeft, ATop, AWidth, AHeight : integer);
var
  OldWidth: LongInt;
  OldHeight: LongInt;
begin
  //DbgOut('[TWinControl.DoSetBounds] ',Name,':',ClassName,' OldHeight=',DbgS(FHeight),' NewHeight=',DbgS(AHeight));
  OldWidth:=Width;
  OldHeight:=Height;
  inherited DoSetBounds(ALeft, ATop, AWidth, AHeight);
  // adapt Clientrect
  if not(cfLoading in FControlFlags)
  or (cfWidthLoaded in FControlFlags) then // adapt only if Width is valid
    inc(FClientWidth,Width-OldWidth);
  if not(cfLoading in FControlFlags)
  or (cfHeightLoaded in FControlFlags) then // adapt only if Height is valid
    inc(FClientHeight,Height-OldHeight);
  if FClientWidth<0 then FClientWidth:=0;
  if FClientHeight<0 then FClientHeight:=0;
  Exclude(FWinControlFlags,wcfAdjustedLogicalClientRectValid);
end;

function TWinControl.DoubleBufferedIsStored: Boolean;
begin
  Result := not FParentDoubleBuffered;
end;

{------------------------------------------------------------------------------
  TWinControl EnableAlign
------------------------------------------------------------------------------}
procedure TWinControl.EnableAlign;
begin
  EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DisableAlign'){$ENDIF};
end;

procedure TWinControl.WriteLayoutDebugReport(const Prefix: string);
var
  i: Integer;
begin
  inherited WriteLayoutDebugReport(Prefix);
  for i:=0 to ControlCount-1 do
    Controls[i].WriteLayoutDebugReport(Prefix+'  ');
end;

procedure TWinControl.AutoAdjustLayout(AMode: TLayoutAdjustmentPolicy;
  const AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth: Integer);
var
  i: Integer;
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.AutoAdjustLayout'){$ENDIF};
  try
    for i:=0 to ControlCount-1 do
      Controls[i].AutoAdjustLayout(AMode, AFromPPI, AToPPI, AOldFormWidth, ANewFormWidth);

    inherited;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.AutoAdjustLayout'){$ENDIF};
  end;
end;

{------------------------------------------------------------------------------
  TWinControl.CanTab
------------------------------------------------------------------------------}
function TWinControl.CanTab: Boolean;
begin
  Result := CanFocus and TWSWinControlClass(WidgetSetClass).CanFocus(Self);
end;

function TWinControl.DoDragMsg(ADragMessage: TDragMessage; APosition: TPoint; ADragObject: TDragObject; ATarget: TControl; ADocking: Boolean):LRESULT;
var
  TargetControl: TControl;
begin
  case ADragMessage of
    dmFindTarget:
      begin
        {$IFDEF VerboseDrag}
        DebugLn('TWinControl.DoDragMsg dmFindTarget ',Name,':',ClassName,' Start DragMsg.DragRec^.Pos=',IntToStr(APosition.X),',',IntToStr(APosition.Y));
        {$ENDIF}
        TargetControl := ControlAtPos(ScreentoClient(APosition),
                                      [capfAllowWinControls,capfRecursive]);
        if TargetControl = nil then TargetControl := Self;
        {$IFDEF VerboseDrag}
        DebugLn('TWinControl.DoDragMsg dmFindTarget ',Name,':',ClassName,' end Result=',TargetControl.Name,':',TargetControl.ClassName);
        {$ENDIF}
        Result := LRESULT(TargetControl);
      end;
    else
      Result := inherited;
  end;
end;

{------------------------------------------------------------------------------
  TWinControl GetChildren
------------------------------------------------------------------------------}
procedure TWinControl.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I : Integer;
  Control : TControl;
begin
  for I := 0 to ControlCount-1 do
  begin
    Control := Controls[i];
    if Control.Owner = Root then Proc(Control);
  end;
end;

{-------------------------------------------------------------------------------
  function TWinControl.ChildClassAllowed(ChildClass: TClass): boolean;

  Allow TControl as child.
-------------------------------------------------------------------------------}
function TWinControl.ChildClassAllowed(ChildClass: TClass): boolean;
begin
  Result:=(ChildClass<>nil) and ChildClass.InheritsFrom(TControl);
end;

{-------------------------------------------------------------------------------
  TWinControl GetClientOrigin
  Result:  TPoint

  returns the screen coordinate of the topleft coordinate 0,0 of the client area
  Note that this value is the position as stored in the interface and is not
  always in sync with the LCL. When a control is moved, the LCL sets the bounds
  to the wanted position and sends a move message to the interface. It is up to
  the interface to handle moves instantly or queued.
-------------------------------------------------------------------------------}
function TWinControl.GetClientOrigin: TPoint;
var
  AControl: TWinControl;
begin
  Result.X := 0;
  Result.Y := 0;
  if HandleAllocated then
  begin
    // get the interface idea where the client area is on the screen
    LCLIntf.ClientToScreen(Handle, Result);
    // adjust the result by all bounds, that are not yet sent to the interface
    AControl := Self;
    repeat
      inc(Result.X, AControl.Left - AControl.FBoundsRealized.Left);
      inc(Result.Y, AControl.Top - AControl.FBoundsRealized.Top);
      AControl := AControl.Parent;
    until AControl = nil;
  end else
  if Parent <> nil then
    Result := inherited GetClientOrigin;
end;

{-------------------------------------------------------------------------------
  TWinControl GetClientRect
  Result:  TRect

  returns the client area. Starting at 0,0.
-------------------------------------------------------------------------------}
function TWinControl.GetClientRect: TRect;

  procedure StoreClientRect(NewClientRect: TRect);
  var
    ClientSizeChanged: boolean;
  begin
    if wcfClientRectNeedsUpdate in FWinControlFlags then begin
      ClientSizeChanged:=(FClientWidth<>NewClientRect.Right)
                      or (FClientHeight<>NewClientRect.Bottom);
      if ClientSizeChanged then begin
        FClientWidth:=NewClientRect.Right;
        FClientHeight:=NewClientRect.Bottom;
        {$IF defined(VerboseNewAutoSize) or defined(CHECK_POSITION)}
        {$IFDEF CHECK_POSITION}
        if CheckPosition(Self) then
        {$ENDIF}
          DebugLn(['StoreClientRect ',Name,':',ClassName,' ',FClientWidth,',',FClientHeight,' HandleAllocated=',HandleAllocated]);
        {$ENDIF}
        {$IFDEF VerboseClientRectBugFix}
        DebugLn(['StoreClientRect ',DbgSName(Self),' ',FClientWidth,',',FClientHeight,' HandleAllocated=',HandleAllocated,' wcfBoundsRealized=',wcfBoundsRealized in FWinControlFlags]);
        {$ENDIF}
        Exclude(FWinControlFlags,wcfAdjustedLogicalClientRectValid);
      end;
      Exclude(FWinControlFlags,wcfClientRectNeedsUpdate);
    end;
  end;

  procedure GetDefaults(var r: TRect);
  begin
    r:=inherited GetClientRect;
    if csLoading in ComponentState then begin
      if cfClientWidthLoaded in FControlFlags then
        r.Right:=FLoadedClientSize.cx;
      if cfClientHeightLoaded in FControlFlags then
        r.Bottom:=FLoadedClientSize.cy;
    end;
  end;

var
  InterfaceWidth, InterfaceHeight: integer;
begin
  if wcfClientRectNeedsUpdate in FWinControlFlags then begin
    //DebugLn(['TWinControl.GetClientRect ',DbgSName(Self),' ',HandleAllocated,' ',wcfBoundsRealized in FWinControlFlags]);
    if TWSWinControlClass(WidgetSetClass).GetDefaultClientRect(Self,
      Left, Top, Width, Height, Result)
    then begin
      // the LCL interface provided a ClientRect
    end
    else if HandleAllocated then
    begin
      // update clientrect from interface
      LCLIntf.GetClientRect(Handle, Result);
      // the LCL is not always in sync with the interface
      // -> adjust client rect based on LCL bounds
      // for example: if the Width in LCL differ from the Width of the Interface
      // object, then adjust the clientwidth accordingly
      // this often anticipates later LM_SIZE messages from the interface
      // and reduces resizes
      LCLIntf.GetWindowSize(Handle, InterfaceWidth, InterfaceHeight);
      {$IF defined(VerboseNewAutoSize) or defined(CHECK_POSITION)}
      {$IFDEF CHECK_POSITION}
      if CheckPosition(Self) then
      {$ENDIF}
        debugln('TWinControl.GetClientRect ',DbgSName(Self),' Interface=',dbgs(InterfaceWidth),',',dbgs(InterfaceHeight),' Result=',dbgs(Result),' Bounds=',dbgs(BoundsRect));
      {$ENDIF}
      {$IFDEF VerboseClientRectBugFix}
      //if Name=CheckClientRectName then
        debugln('TWinControl.GetClientRect ',DbgSName(Self),' InterfaceSize=',dbgs(InterfaceWidth),',',dbgs(InterfaceHeight),' Result=',dbgs(Result),' Bounds=',dbgs(BoundsRect));
      {$ENDIF}
      if (Width<>InterfaceWidth)
      or (Height<>InterfaceHeight) then
      begin
        // the LCL is not in sync with the interface
        if wcfBoundsRealized in FWinControlFlags then
        begin
          // no bounds were sent yet to the interface and it didn't initialize
          // them on its own
          // => the client bounds from the interface are not yet ready
          // they will probably change
          // to avoid resizes it is better use the defaults
          GetDefaults(Result);
        end else begin
          // -> adjust client rect based on LCL bounds
          // for example: if the Width in LCL differ from the Width of the Interface
          // object, then adjust the clientwidth accordingly
          // this often anticipates later LM_SIZE messages from the interface
          // and reduces resizes
          inc(Result.Right,Width-InterfaceWidth);
          inc(Result.Bottom,Height-InterfaceHeight);
        end;
      end;
    end else begin
      // no handle and no interface help => use defaults
      GetDefaults(Result);
    end;
    Result.Right:=Max(Result.Left,Result.Right);
    Result.Bottom:=Max(Result.Top,Result.Bottom);
    StoreClientRect(Result);

    {r:=inherited GetClientRect;
    if (r.Left<>Result.Left)
    or (r.Top<>Result.Top)
    or (r.Right<>Result.Right)
    or (r.Bottom<>Result.Bottom) then begin
      //DebugLn(' TWinControl.GetClientRect ',Name,':',ClassName,
      //  ' Old=',r.Left,',',r.Top,',',r.Right,',',r.Bottom,
      //  ' New=',Result.Left,',',Result.Top,',',Result.Right,',',Result.Bottom
      //  );
    end;}

  end else begin
    Result:=Rect(0,0,FClientWidth,FClientHeight);
  end;
end;

{-------------------------------------------------------------------------------
  TWinControl GetControlOrigin
  Result:  TPoint

  Returns the screen coordinate of the topleft coordinate 0,0 of the control
  area. (The topleft pixel of the control on the screen)
  Note that this value is the position as stored in the interface and is not
  always in sync with the LCL. When a control is moved, the LCL sets the bounds
  to the wanted position and sends a move message to the interface. It is up to
  the interface to handle moves instantly or queued.
-------------------------------------------------------------------------------}
function TWinControl.GetControlOrigin: TPoint;
var
  AControl: TWinControl;
  IntfBounds: TRect;
begin
  if HandleAllocated then
  begin
    // get the interface idea where the client area is on the screen
    LCLIntf.GetWindowRect(Handle,IntfBounds);
    Result.X := IntfBounds.Left;
    Result.Y := IntfBounds.Top;
    // adjust the result by all bounds, that are not yet sent to the interface
    AControl := Self;
    repeat
      inc(Result.X, AControl.Left - AControl.FBoundsRealized.Left);
      inc(Result.Y, AControl.Top - AControl.FBoundsRealized.Top);
      AControl := AControl.Parent;
    until AControl = nil;
  end else
    Result:=inherited GetControlOrigin;
end;

{------------------------------------------------------------------------------
  function TWinControl.GetChildrenRect(Scrolled: boolean): TRect;

  Returns the Client rectangle relative to the controls left, top.
  If Scrolled is true, the rectangle is moved by the current scrolling values
  (for an example see TScrollingWincontrol).
------------------------------------------------------------------------------}
function TWinControl.GetChildrenRect(Scrolled: boolean): TRect;
var
  ScrolledOffset: TPoint;
begin
  if HandleAllocated then begin
    LCLIntf.GetClientBounds(Handle,Result);
    if Scrolled then begin
      ScrolledOffset:=GetClientScrollOffset;
      inc(Result.Left,ScrolledOffset.X);
      inc(Result.Top,ScrolledOffset.Y);
      inc(Result.Right,ScrolledOffset.X);
      inc(Result.Bottom,ScrolledOffset.Y);
    end;
  end else
    Result:=inherited GetChildrenRect(Scrolled);
end;

{------------------------------------------------------------------------------
  TWinControl SetBorderStyle
------------------------------------------------------------------------------}
procedure TWinControl.SetBorderStyle(NewStyle: TBorderStyle);
begin
  if FBorderStyle = NewStyle then Exit;
  FBorderStyle := NewStyle;
  if HandleAllocated then
    TWSWinControlClass(WidgetSetClass).SetBorderStyle(Self, NewStyle);
end;

{------------------------------------------------------------------------------
  TWinControl SetBorderWidth
------------------------------------------------------------------------------}
procedure TWinControl.SetBorderWidth(Value: TBorderWidth);
begin
  if FBorderWidth = Value then exit;
  FBorderWidth := Value;
  Perform(CM_BORDERCHANGED, 0, 0);
end;

procedure TWinControl.SetParentWindow(const AValue: HWND);
begin
  if (ParentWindow = AValue) or Assigned(Parent) then Exit;
  FParentWindow := AValue;
  if HandleAllocated then
    if (AValue <> 0) then
      LCLIntf.SetParent(Handle, AValue)
    else
      DestroyHandle;
  UpdateControlState;
end;

{------------------------------------------------------------------------------
  TWinControl.SetChildZPosition

  Set the position of the child control in the TWinControl(s)
------------------------------------------------------------------------------}
procedure TWinControl.SetChildZPosition(const AChild: TControl;
  const APosition: Integer);
var
  OldPos, NewPos: Integer;
  IsWinControl: boolean;
  i: Integer;
  WinControls: TFPList;
begin
  if AChild = nil
  then begin
    DebugLn('WARNING: TWinControl.SetChildZPosition: Child = nil');
    Exit;
  end;

  IsWinControl :=  AChild is TWincontrol;
  
  if FControls = nil then
  begin
    DebugLn('WARNING: TWinControl.SetChildZPosition: Unknown child');
    Exit;
  end;
  OldPos := FControls.IndexOf(AChild);
  if OldPos<0 then begin
    DebugLn('WARNING: TWinControl.SetChildZPosition: Not a child');
    Exit;
  end;

  NewPos := APosition;
  
  if NewPos < 0 then
    NewPos := 0;
  if NewPos >= FControls.Count then
    NewPos := FControls.Count - 1;
  
  if NewPos = OldPos then Exit;
  
  FControls.Move(OldPos, NewPos);
  
  if IsWinControl then
  begin
    if HandleAllocated and TWinControl(AChild).HandleAllocated then
    begin
      // ignore children without handle
      WinControls:=TFPList.Create;
      try
        for i:=FControls.Count-1 downto 0 do
        begin
          if (TObject(FControls[i]) is TWinControl) then
          begin
            WinControls.Add(FControls[i]);
          end else begin
            if i<OldPos then dec(OldPos);
            if i<NewPos then dec(NewPos);
          end;
        end;
        TWSWinControlClass(WidgetSetClass).SetChildZPosition(Self,
                              TWinControl(AChild), OldPos, NewPos, WinControls);
      finally
        WinControls.Free;
      end;
    end;
  end
  else begin
    AChild.InvalidateControl(AChild.IsVisible, True, True);
  end;
end;

{------------------------------------------------------------------------------
       TWinControl.SetTabOrder
------------------------------------------------------------------------------}
procedure TWinControl.SetTabOrder(NewTabOrder: TTabOrder);
begin
  if csLoading in ComponentState then
    FTabOrder := NewTabOrder
  else
    UpdateTabOrder(NewTabOrder);
end;

procedure TWinControl.SetTabStop(NewTabStop: Boolean);
begin
  if FTabStop = NewTabStop then
    Exit;
  FTabStop := NewTabStop;
  UpdateTabOrder(FTabOrder);
  Perform(CM_TABSTOPCHANGED, 0, 0);
end;

{------------------------------------------------------------------------------
  TControl UpdateTabOrder
------------------------------------------------------------------------------}
procedure TWinControl.UpdateTabOrder(NewTabOrder: TTabOrder);
var
  Count: Integer;
begin
  if FParent <> nil then
  begin
    FTabOrder := GetTabOrder;
    Count := ListCount(FParent.FTabList);
    if NewTabOrder < 0 then
      NewTabOrder := Count;
    if FTabOrder = -1 then
      Inc(Count);
    if NewTabOrder > Count then
      NewTabOrder := Count;
    if NewTabOrder <> FTabOrder then
    begin
      if FTabOrder <> - 1 then
        ListDelete(FParent.FTabList,FTabOrder);
      if NewTabOrder <> -1 then
      begin
        if NewTabOrder = Count then
          ListAdd(FParent.FTabList,Self)
        else
          ListInsert(FParent.FTabList,NewTabOrder,Self);
        FTabOrder := NewTabOrder;
      end;
    end;
  end;
end;

{-------------------------------------------------------------------------------
  procedure TWinControl.SendMoveSizeMessages(SizeChanged, PosChanged: boolean);
  
  Send Move and Size messages through the LCL message paths. This simulates the
  VCL behaviour and has no real effect.
-------------------------------------------------------------------------------}
procedure TWinControl.SendMoveSizeMessages(SizeChanged, PosChanged: boolean);
var
  SizeMsg : TLMSize;
  MoveMsg : TLMMove;
  //Flags: UINT;
begin
  if (not HandleAllocated)
  or ((not SizeChanged) and (not PosChanged)) then exit;

  if SizeChanged then
  begin
    with SizeMsg do
    begin
      Msg := LM_SIZE;
      SizeType := 6; // force realign
      if (FWidth  < Low(Word)) or (FWidth  > High(Word))
      or (FHeight < Low(Word)) or (FHeight > High(Word)) then
        raise ELayoutException.CreateFmt('Size range overflow in %s.SendMoveSizeMessages:'
                                 +' Width=%d, Height=%d.', [Name, FWidth, FHeight]);
      Width := FWidth;
      Height := FHeight;
      {$IFDEF CHECK_POSITION}
      if CheckPosition(Self) then
      DebugLn(' [TControl.SendMoveSizeMessages] ',Name,':',ClassName,' SizeMsg Width=',DbgS(Width),' Height=',DbgS(Height));
      {$ENDIF}
    end;
    WindowProc(TLMessage(SizeMsg));
  end;
  
  if PosChanged then
  begin
    with MoveMsg do
    begin
      Msg:= LM_MOVE;
      MoveType:= 1;
      if (FLeft < Low(Smallint)) or (FLeft > High(Smallint))
      or (FTop  < Low(Smallint)) or (FTop  > High(Smallint)) then
        raise ELayoutException.CreateFmt('Position range overflow in %s.SendMoveSizeMessages:'
                                 +' Left=%d, Top=%d.', [Name, FLeft, FTop]);
      XPos := FLeft;
      YPos := FTop;
      {$IFDEF CHECK_POSITION}
      if CheckPosition(Self) then
      DebugLn(' [TControl.SendMoveSizeMessages] ',Name,':',ClassName,' MoveMsg XPos=',Dbgs(XPos),' YPos=',Dbgs(YPos));
      {$ENDIF}
    end;
    WindowProc(TLMessage(MoveMsg));
  end;
end;

{------------------------------------------------------------------------------
  TWinControl UpdateShowing

  Check control's handle visibility.
  If handle should become visible the handle and child handles are created.
  The
------------------------------------------------------------------------------}
procedure TWinControl.UpdateShowing;

  procedure ChangeShowing(bShow: Boolean);
  begin
    if FShowing = bShow then Exit;
    FShowing := bShow;
    try
      {$IFDEF VerboseShowing}
      DebugLn(['ChangeShowing ',DbgSName(Self),' new FShowing=',FShowing]);
      {$ENDIF}
      Perform(CM_SHOWINGCHANGED, 0, 0); // see TWinControl.CMShowingChanged
    finally
      if FShowing<>(wcfHandleVisible in FWinControlFlags) then
      begin
        FShowing := wcfHandleVisible in FWinControlFlags;
        DebugLn(['TWinControl.UpdateShowing.ChangeShowing failed for ',DbgSName(Self),', Showing reset to ',FShowing]);
      end;
    end;
  end;

var
  bShow: Boolean;
  n: Integer;
begin
  bShow := HandleObjectShouldBeVisible;

  if bShow then
  begin
    if not HandleAllocated then CreateHandle;
    if Assigned(FControls) then
    begin
      for n := 0 to FControls.Count - 1 do
        if TObject(FControls[n]) is TWinControl then
          TWinControl(FControls[n]).UpdateShowing;
    end;
  end;
  if not HandleAllocated then
  begin
    {$IFDEF VerboseShowing}
    if bShow then
      DebugLn(['TWinControl.UpdateShowing ',DbgSName(Self),' handle not allocated']);
    {$ENDIF}
    Exit;
  end;

  if FShowing = bShow then Exit;
  //DebugLn(['TWinControl.UpdateShowing ',dbgsName(Self),' FShowing=',dbgs(FShowing),' bShow=',dbgs(bShow), ' IsWindowVisible=', IsWindowVisible(FHandle)]);
  if bShow then
  begin
    // the Handle should become visible
    // delay this until all other autosizing has been processed
    if AutoSizeDelayed or (not (caspShowing in AutoSizePhases)) then
    begin
      {$IFDEF VerboseShowing}
      if AutoSizeDelayed then DebugLn(['TWinControl.UpdateShowing ',DbgSName(Self),' SKIPPING because AutoSizeDelayed: ',AutoSizeDelayedReport]);
      if (not (caspShowing in AutoSizePhases)) then DebugLn(['TWinControl.UpdateShowing ',DbgSName(Self),' SKIPPING because wrong phase']);
      {$ENDIF}
      exit;
    end;
  end;
  ChangeShowing(bShow);
end;

procedure TWinControl.Update;
begin
  if HandleAllocated then UpdateWindow(Handle);
end;

{------------------------------------------------------------------------------
  TWinControl Focused
------------------------------------------------------------------------------}
function TWinControl.Focused: Boolean;
begin
  Result := CanTab and (HandleAllocated and (FindOwnerControl(GetFocus)=Self));
end;

function TWinControl.PerformTab(ForwardTab: boolean): boolean;
var
  NewFocus: TWinControl;
  ParentForm: TCustomForm;
begin
  Result := True;
  ParentForm := GetParentForm(Self);
  if ParentForm = nil then
    Exit;
  NewFocus := ParentForm.FindNextControl(Self, ForwardTab, True, False);
  if NewFocus = nil then
    Exit;

  NewFocus.SetFocus;
  Result := NewFocus.Focused;
end;

{------------------------------------------------------------------------------
  TWinControl SelectNext
  
  Find next control (Tab control or Child control).
  Like VCL the CurControl parameter is ignored.
------------------------------------------------------------------------------}
procedure TWinControl.SelectNext(CurControl: TWinControl; GoForward,
  CheckTabStop: Boolean);
begin
  CurControl := FindNextControl(CurControl, GoForward,
                                CheckTabStop, not CheckTabStop);
  if CurControl <> nil then CurControl.SetFocus;
end;

procedure TWinControl.SetTempCursor(Value: TCursor);
begin
  if not HandleAllocated then exit;
  TWSWinControlClass(WidgetSetClass).SetCursor(Self, Screen.Cursors[Value]);
end;

{------------------------------------------------------------------------------
  TWinControl FindChildControl
------------------------------------------------------------------------------}
function TWinControl.FindChildControl(const ControlName: String): TControl;
var
  I: Integer;
begin
  if FControls <> nil then
    for I := 0 to FControls.Count - 1 do begin
      Result:=TControl(FControls[I]);
      if CompareText(Result.Name, ControlName) = 0 then
        exit;
    end;
  Result := nil;
end;

procedure TWinControl.FlipChildren(AllLevels: Boolean);
var
  i: Integer;
  FlipControls: TFPList;
  CurControl: TControl;
begin
  if ControlCount = 0 then exit;
  FlipControls := TFPList.Create;
  
  DisableAlign;
  try
    // Collect all controls with Align Right and Left
    for i := 0 to ControlCount - 1 do begin
      CurControl:=Controls[i];
      if CurControl.Align in [alLeft,alRight] then
        FlipControls.Add(CurControl);
    end;
    // flip the rest
    DoFlipChildren;
    // reverse Right and Left alignments
    while FlipControls.Count > 0 do begin
      CurControl:=TControl(FlipControls[FlipControls.Count-1]);
      if CurControl.Align=alLeft then
        CurControl.Align:=alRight
      else if CurControl.Align=alRight then
        CurControl.Align:=alLeft;
      FlipControls.Delete(FlipControls.Count - 1);
    end;
  finally
    FlipControls.Free;
    EnableAlign;
  end;
  FFlipped := not FFlipped; // toggle FFlipped status
  // flip recursively
  if AllLevels then begin
    for i := 0 to ControlCount - 1 do begin
      CurControl:=Controls[i];
      if CurControl is TWinControl then
        TWinControl(CurControl).FlipChildren(true);
    end;
  end;
end;

procedure TWinControl.ScaleBy(Multiplier, Divider: Integer);
begin
  ChangeScale(Multiplier, Divider);
end;

{------------------------------------------------------------------------------}
{  TWinControl FindNextControl                                                 }
{------------------------------------------------------------------------------}
function TWinControl.FindNextControl(CurrentControl: TWinControl; GoForward,
  CheckTabStop, CheckParent: Boolean): TWinControl;
var
  List: TFPList;
  Next: TWinControl;
  I, J: Longint;
begin
  try
    Result := nil;
    List := TFPList.Create;
    GetTabOrderList(List);
    //for i:=0 to List.Count-1 do
    //  debugln(['TWinControl.FindNextControl TabOrderList ',dbgs(i),' ',DbgSName(TObject(List[i]))]);
    if List.Count > 0 then
    begin
      J := List.IndexOf(CurrentControl);
      if J < 0 then
      begin
        if GoForward then
          J := List.Count - 1
        else
          J := 0;
      end;
      //DebugLn(['TWinControl.FindNextControl A ',DbgSName(CurrentControl),' ',dbgs(J),
      //  ' GoForward='+dbgs(GoForward)+' CheckTabStop='+dbgs(CheckTabStop)+' CheckParent='+dbgs(CheckParent)]);
      I := J;
      repeat
        if GoForward then
        begin
          Inc(I);
          if I >= List.Count then
            I := 0;
        end else
        begin
          Dec(I);
          if I < 0 then
            I := List.Count - 1;
        end;

        Next := TWinControl(List[I]);
{        DebugLn(['TWinControl.FindNextControl B ',Next.Name,' ',dbgs(I),
          ' ChckTabStop='+dbgs(CheckTabStop)+' TabStop='+dbgs(Next.TabStop)
          +' ChckParent='+dbgs(CheckParent)+' Parent=Self='+dbgs(Next.Parent = Self)
          +' Enabled='+dbgs(Next.Enabled)
          +' TestTab='+dbgs(((Not CheckTabStop) or Next.TabStop))
          +' TestPar='+dbgs(((not CheckParent) or (Next.Parent = Self)))
          +' TestEnVi='+dbgs(Next.Enabled and Next.IsVisible)]);}
        if (((not CheckTabStop) or Next.TabStop)
        and ((not CheckParent) or (Next.Parent = Self)))
        and (Next.Enabled and Next.IsVisible) then
          Result := Next;

        // if we reached the start then exit because we traversed the loop and
        // did not find any control
        if I = J then
          break;
      until (Result <> nil);
      //DebugLn(['TWinControl.FindNextControl END ',DbgSName(Result),' I=',dbgs(I)]);
    end;
  finally
    List.Free;
  end;
end;

procedure TWinControl.FixDesignFontsPPIWithChildren(const ADesignTimePPI: Integer);
  procedure FixChildren(const AParent: TWinControl);
  var
    I: Integer;
  begin
    for I := 0 to AParent.ControlCount-1 do
    begin
      AParent.Controls[I].FixDesignFontsPPI(ADesignTimePPI);
      if AParent.Controls[I] is TWinControl then
        FixChildren(TWinControl(AParent.Controls[I]));
    end;
  end;
begin
  FixDesignFontsPPI(ADesignTimePPI);
  FixChildren(Self);
end;

procedure TWinControl.SelectFirst;
var
  Form : TCustomForm;
  Control : TWinControl;
begin
  Form := GetParentForm(Self);
  if Form <> nil then begin
    Control := FindNextControl(nil, true, true, false);
    if Control = nil then
      Control := FindNextControl(nil, true, false, false);
    if Control <> nil then
      Form.ActiveControl := Control;
  end;
end;

procedure TWinControl.FixupTabList;
var
  I, J: Integer;
  Control: TWinControl;
  List: TFPList;
  WinControls: TFPList;
begin
  if FControls <> nil then
  begin
    List := TFPList.Create;
    WinControls:=TFPList.Create;
    try
      for i:=0 to FControls.Count-1 do
        if TObject(FControls[i]) is TWinControl then
          WinControls.Add(FControls[i]);
      List.Count := WinControls.Count;
      for I := 0 to WinControls.Count - 1 do
      begin
        Control := TWinControl(WinControls[I]);
        J := Control.FTabOrder;
        if (J >= 0) and (J < WinControls.Count) then
          List[J] := Control;
      end;
      for I := 0 to List.Count - 1 do
      begin
        Control := TWinControl(List[I]);
        if Control <> nil then
          Control.UpdateTabOrder(TTabOrder(I));
      end;
    finally
      List.Free;
      WinControls.Free;
    end;
  end;
end;

{------------------------------------------------------------------------------
  TWinControl GetTabOrderList
------------------------------------------------------------------------------}
procedure TWinControl.GetTabOrderList(List: TFPList);
var
  I: Integer;
  lWinControl: TWinControl;
begin
  if FTabList <> nil then
    for I := 0 to FTabList.Count - 1 do
    begin
      lWinControl := TWinControl(FTabList[I]);
      // The tab order list should exclude injected LCL-CustomDrawn controls
      if lWinControl.CanFocus and (not LCLIntf.IsCDIntfControl(lWinControl)) then
        List.Add(lWinControl);
      lWinControl.GetTabOrderList(List);
    end;
end;

{------------------------------------------------------------------------------
  TWinControl IsControlMouseMsg
------------------------------------------------------------------------------}
function TWinControl.IsControlMouseMsg(var TheMessage): Boolean;
var
  MouseMessage: TLMMouse absolute TheMessage;
  MouseEventMessage: TLMMouseEvent;
  Control: TControl;
  ScrolledOffset, P: TPoint;
  ClientBounds: TRect;
begin
  { CaptureControl = nil means that widgetset has captured input, but it does
    not know anything about TControl controls }
  if (FindOwnerControl(GetCapture) = Self) and (CaptureControl <> nil) then
  begin
    Control := nil;
    //DebugLn(['TWinControl.IsControlMouseMsg A ', DbgSName(CaptureControl), ', ',DbgSName(CaptureControl.Parent),', Self: ', DbgSName(Self)]);
    if (CaptureControl.Parent = Self) then
      Control := CaptureControl;
  end
  else
  begin
    // do query wincontrol children, in case they overlap
    Control := ControlAtPos(SmallPointToPoint(MouseMessage.Pos), []);
  end;

  //DebugLn(['TWinControl.IsControlMouseMsg B ',DbgSName(Self),' Control=',DbgSName(Control),' Msg=',TheMessage.Msg]);
  Result := False;
  if Control <> nil then
  begin
    // map mouse coordinates to control
    ScrolledOffset := GetClientScrollOffset;

    P.X := MouseMessage.XPos - Control.Left + ScrolledOffset.X;
    P.Y := MouseMessage.YPos - Control.Top + ScrolledOffset.Y;
    if (Control is TWinControl) and TWinControl(Control).HandleAllocated then
    begin
      // map coordinates to client area of control
      LCLIntf.GetClientBounds(TWinControl(Control).Handle, ClientBounds);
      dec(P.X, ClientBounds.Left);
      dec(P.Y, ClientBounds.Top);
      {$IFDEF VerboseMouseBugfix}
      DebugLn(['TWinControl.IsControlMouseMsg ',Name,' -> ',Control.Name,
      ' MsgPos=',MouseMessage.Pos.X,',',MouseMessage.Pos.Y,
      ' Control=',Control.Left,',',Control.Top,
      ' ClientBounds=',ClientBounds.Left,',',ClientBounds.Top,
      ' Scrolled=',GetClientScrollOffset.X,',',GetClientScrollOffset.Y,
      ' P=',P.X,',',P.Y]
      );
      {$ENDIF}
    end;
    if (MouseMessage.Msg = LM_MOUSEWHEEL) or
      (MouseMessage.Msg = LM_MOUSEHWHEEL) then
    begin
      MouseEventMessage := TLMMouseEvent(TheMessage);
      {$PUSH}
      {$R-}{$Q-} // no range, no overflow checks
      MouseEventMessage.X := P.X;
      MouseEventMessage.Y := P.Y;
      {$POP}
      Control.Dispatch(MouseEventMessage);
      MouseMessage.Result := MouseEventMessage.Result;
      Result := (MouseMessage.Result <> 0);
    end
    else
    begin
      MouseMessage.Result := Control.Perform(MouseMessage.Msg, WParam(MouseMessage.Keys),
                             LParam(Integer(PointToSmallPointNoChecks(P))));
      Result := True;
    end;
  end;
end;

procedure TWinControl.FontChanged(Sender: TObject);
begin
  if HandleAllocated and ([csLoading, csDestroying] * ComponentState = []) then
  begin
    TWSWinControlClass(WidgetSetClass).SetFont(Self, TFont(Sender));
    Exclude(FWinControlFlags, wcfFontChanged);
  end
  else
    Include(FWinControlFlags, wcfFontChanged);
  inherited FontChanged(Sender);
  NotifyControls(CM_PARENTFONTCHANGED);
end;

procedure TWinControl.SetColor(Value: TColor);
begin
  if Value = Color then Exit;
  inherited SetColor(Value);
  if BrushCreated then
    if Color = clDefault then
      FBrush.Color := GetDefaultColor(dctBrush)
    else
      FBrush.Color := Color;
  if HandleAllocated and ([csLoading,csDestroying]*ComponentState=[]) then
  begin
    TWSWinControlClass(WidgetSetClass).SetColor(Self);
    Exclude(FWinControlFlags, wcfColorChanged);
  end
  else
    Include(FWinControlFlags, wcfColorChanged);
  NotifyControls(CM_PARENTCOLORCHANGED);
end;

procedure TWinControl.PaintHandler(var TheMessage: TLMPaint);

  function ControlMustBeClipped(AControl: TControl): boolean;
  begin
    Result := (csOpaque in AControl.ControlStyle) and AControl.IsVisible;
  end;

var
  I, Clip, SaveIndex: Integer;
  DC: HDC;
  PS: TPaintStruct; //defined in LCLIntf.pp
  ControlsNeedsClipping: boolean;
  CurControl: TControl;
begin
  //DebugLn('[TWinControl.PaintHandler] ',Name,':',ClassName,'  DC=',DbgS(TheMessage.DC,8));
  if (csDestroying in ComponentState) or (not HandleAllocated) then exit;

  {$IFDEF VerboseResizeFlicker}
  DebugLn('TWinControl.PaintHandler A ',Name,':',ClassName);
  {$ENDIF}
  {$IFDEF VerboseDsgnPaintMsg}
  if csDesigning in ComponentState then
    DebugLn('TWinControl.PaintHandler A ',Name,':',ClassName);
  {$ENDIF}

  //DebugLn(Format('Trace:> [TWinControl.PaintHandler] %s --> Msg.DC: 0x%x', [ClassName, TheMessage.DC]));
  DC := TheMessage.DC;
  if DC = 0 then
    DC := BeginPaint(Handle, PS);

  try
    // check if child controls need clipping
    //if Name='GroupBox1' then
      //DebugLn('[TWinControl.PaintHandler] ',DbgSName(Self),' B');
    ControlsNeedsClipping:=false;
    if FControls<>nil then
      for I := 0 to FControls.Count - 1 do
        if ControlMustBeClipped(TControl(FControls[I])) then begin
          ControlsNeedsClipping:=true;
          break;
        end;
    // exclude child controls and send new paint message
    //if Name='GroupBox1' then
      //debugln(['TWinControl.PaintHandler ControlsNeedsClipping=',ControlsNeedsClipping,' ControlCount=',ControlCount]);
    if not ControlsNeedsClipping then begin
      //DebugLn('[TWinControl.PaintHandler] ',DbgSName(Self),' no clipping ...');
      PaintWindow(DC)
    end else
    begin
      SaveIndex := SaveDC(DC);
      Clip := SimpleRegion;
      for I := 0 to FControls.Count - 1 do begin
        CurControl:=TControl(FControls[I]);
        if ControlMustBeClipped(CurControl) then
          with CurControl do begin
            //DebugLn('TWinControl.PaintHandler Exclude Child ',DbgSName(Self),' Control=',DbgSName(CurControl),'(',dbgs(CurControl.BoundsRect),')');
            Clip := ExcludeClipRect(DC, Left, Top, Left + Width, Top + Height);
            if Clip = NullRegion then Break;
          end;
      end;
      //DebugLn('[TWinControl.PaintHandler] ',DbgSName(Self),' with clipping ...');
      if Clip <> NullRegion then
        PaintWindow(DC);
      RestoreDC(DC, SaveIndex);
    end;
    // paint controls
    //DebugLn('[TWinControl.PaintHandler] ',DbgSName(Self),' PaintControls ...');
    if FDockSite and FUseDockManager and Assigned(DockManager) then
      DockManager.PaintSite(DC);
    PaintControls(DC, nil);
  finally
    if TheMessage.DC = 0 then
      EndPaint(Handle, PS);
  end;
  //DebugLn(Format('Trace:< [TWinControl.PaintHandler] %s', [ClassName]));
//DebugLn('[TWinControl.PaintHandler] END  ',Name,':',ClassName,'  DC=',DbgS(Message.DC,8));
end;

procedure TWinControl.PaintControls(DC: HDC; First: TControl);
var
  I, Count, SaveIndex: Integer;
//  FrameBrush: HBRUSH;
  TempControl : TControl;
  {off $Define VerboseControlDCOrigin}
  {$IFDEF VerboseControlDCOrigin}
  P: TPoint;
  {$ENDIF}
begin
  {$ifdef DEBUG_WINDOW_ORG}
  DebugLn(':> [TWinControl.PaintControls] A');
  {$endif}

  //DebugLn('[TWinControl.PaintControls] ',Name,':',ClassName,'  DC=',DbgS(DC,8));
  if (csDestroying in ComponentState)
  or ((DC=0) and (not HandleAllocated)) then
    exit;

  {$IFDEF VerboseDsgnPaintMsg}
  if csDesigning in ComponentState then
    DebugLn('TWinControl.PaintControls A ',Name,':',ClassName);
  {$ENDIF}

  // Controls that are not TWinControl, have no handle of their own, and so
  // they are repainted as part of the parent:
  if FControls <> nil then
  begin
    {$ifdef DEBUG_WINDOW_ORG}
    DebugLn(':> [TWinControl.PaintControls] B');
    {$endif}
    I := 0;
    if First <> nil then
    begin
      I := FControls.IndexOf(First);
      if I < 0 then I := 0;
    end;
    //debugln(['TWinControl.PaintControls ',DbgSName(Self),' ClientRect=',dbgs(ClientRect)]);
    Count := FControls.Count;
    while I < Count do
    begin
      TempControl := TControl(FControls.Items[I]);
      {$ifdef DEBUG_WINDOW_ORG}
      if Name='GroupBox1' then
        DebugLn(
        Format(':> [TWinControl.PaintControls] C  DC=%d TempControl=%s Left=%d Top=%d Width=%d Height=%d IsVisible=%s RectVisible=%s',
        [DC, DbgSName(TempControl),
          TempControl.Left, TempControl.Top, TempControl.Width, TempControl.Height,
          dbgs(IsVisible),
          dbgs(RectVisible(DC, TempControl.BoundsRect))
          ]));
      {$endif}
      if not (TempControl is TWinControl) then begin
        //DebugLn('TWinControl.PaintControls B Self=',Self.Name,':',Self.ClassName,' Control=',TempControl.Name,':',TempControl.ClassName,' ',TempControl.Left,',',TempControl.Top,',',TempControl.Width,',',TempControl.Height);
        with TempControl do
          if ((WidgetSet.GetLCLCapability(lcCanDrawHidden) = LCL_CAPABILITY_YES) and isControlVisible)
            or (IsVisible and RectVisible(DC, TempControl.BoundsRect))
          then
          begin
            if csPaintCopy in Self.ControlState then
              Include(FControlState, csPaintCopy);
            SaveIndex := SaveDC(DC);

            {$ifdef DEBUG_WINDOW_ORG}
            DebugLn(
              Format(':> [TWinControl.PaintControls] Control=%s Left=%d Top=%d Width=%d Height=%d',
              [Self.Name, Left, Top, Width, Height]));
            {$endif}

            MoveWindowOrg(DC, Left, Top);
            {$IFDEF VerboseControlDCOrigin}
            DebugLn('TWinControl.PaintControls B Self=',DbgSName(Self),' Control=',DbgSName(TempControl),' ',dbgs(Left),',',dbgs(Top),',',dbgs(Width),',',dbgs(Height));
            {$ENDIF}
            IntersectClipRect(DC, 0, 0, Width, Height);
            {$IFDEF VerboseControlDCOrigin}
            DebugLn('TWinControl.PaintControls C');
            P:=Point(-1,-1);
            GetWindowOrgEx(DC,@P);
            debugln('  DCOrigin=',dbgs(P));
            {$ENDIF}
            Perform(LM_PAINT, WParam(DC), 0);
            {$IFDEF VerboseControlDCOrigin}
            DebugLn('TWinControl.PaintControls D TempControl=',DbgSName(TempControl));
            {$ENDIF}
            RestoreDC(DC, SaveIndex);
            Exclude(FControlState, csPaintCopy);
          end;
      end;
      Inc(I);
    end;
  end;
  //DebugLn('[TWinControl.PaintControls] END ',Name,':',ClassName,'  DC=',DbgS(DC,8));
end;

procedure TWinControl.PaintWindow(DC: HDC);
var
  Message: TLMessage;
begin
  //DebugLn('[TWinControl.PaintWindow] ',Name,':',Classname,'  DC=',DbgS(DC));
  if (csDestroying in ComponentState)
  or ((DC=0) and (not HandleAllocated)) then
    exit;

  {$IFDEF VerboseDsgnPaintMsg}
  if csDesigning in ComponentState then
    DebugLn('TWinControl.PaintWindow A ',Name,':',ClassName);
  {$ENDIF}

  Message.Msg := LM_PAINT;
  Message.WParam := WParam(DC);
  Message.LParam := 0;
  Message.Result := 0;
  DefaultHandler(Message);
end;

procedure TWinControl.CreateBrush;
begin
  if BrushCreated then exit;
  FBrush := TBrush.Create;
  if Color = clDefault then
    FBrush.Color := GetDefaultColor(dctBrush)
  else
    FBrush.Color := Color;
end;

procedure TWinControl.ScaleControls(Multiplier, Divider: Integer);
var
  i: Integer;
begin
  for i := 0 to ControlCount - 1 do
    Controls[i].ChangeScale(Multiplier, Divider);
end;

procedure TWinControl.ChangeScale(Multiplier, Divider: Integer);
var
  i: Integer;
begin
  if Multiplier <> Divider then
  begin
    DisableAlign;
    try
      ScaleControls(Multiplier, Divider);
      inherited;
      for i := 0 to ControlCount - 1 do
        Controls[i].UpdateAnchorRules;
    finally
      EnableAlign;
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.EraseBackground;
------------------------------------------------------------------------------}
procedure TWinControl.EraseBackground(DC: HDC);
var
  ARect: TRect;
begin
  if DC = 0 then Exit;
  ARect := Rect(0, 0, Width, Height);
  FillRect(DC, ARect, HBRUSH(Brush.Reference.Handle));
end;

{------------------------------------------------------------------------------
  function TWinControl.IntfUTF8KeyPress(var UTF8Key: TUTF8Char;
    RepeatCount: integer; SystemKey: boolean): boolean;

  Called by the interface after the navigation and specials keys are handled
  (e.g. after KeyDown but before KeyPress).
------------------------------------------------------------------------------}
function TWinControl.IntfUTF8KeyPress(var UTF8Key: TUTF8Char;
  RepeatCount: integer; SystemKey: boolean): boolean;
begin
  IncLCLRefCount;
  try
    Result := (RepeatCount > 0) and not SystemKey and DoUTF8KeyPress(UTF8Key);
  finally
    DecLCLRefCount;
  end;
end;

function TWinControl.IntfGetDropFilesTarget: TWinControl;
begin
  Result:=Self;
  repeat
    Result:=GetFirstParentForm(Result);
    if Result=nil then exit;
    if TCustomForm(Result).AllowDropFiles then exit;
    Result:=Result.Parent;
  until Result=nil;
end;

procedure TWinControl.PaintTo(DC: HDC; X, Y: Integer);
begin
  if HandleAllocated then
    TWSWinControlClass(WidgetSetClass).PaintTo(Self, DC, X, Y);
end;

procedure TWinControl.PaintTo(ACanvas: TCanvas; X, Y: Integer);
begin
  PaintTo(ACanvas.Handle, X, Y);
  ACanvas.Changed;
end;

procedure TWinControl.SetShape(AShape: TBitmap);
begin
  if not HandleAllocated then
    Exit;

  if (AShape <> nil) and (AShape.Width = Width) and (AShape.Height = Height) then
    TWSWinControlClass(WidgetSetClass).SetShape(Self, AShape.Handle)
  else
  if AShape = nil then
    TWSWinControlClass(WidgetSetClass).SetShape(Self, 0)
end;

procedure TWinControl.SetShape(AShape: TRegion);
begin
  LCLIntf.SetWindowRgn(Handle, AShape.Reference.Handle, True);
end;

{------------------------------------------------------------------------------
  TWinControl ControlAtPos
  Params: const Pos : TPoint
          AllowDisabled: Boolean
  Results: TControl

  Searches a child (not grand child) control, which client area contains Pos.
  Pos is relative to the ClientOrigin.
------------------------------------------------------------------------------}
function TWinControl.ControlAtPos(const Pos: TPoint; AllowDisabled: Boolean): TControl;
begin
  Result := ControlAtPos(Pos, AllowDisabled, False);
end;

{------------------------------------------------------------------------------
  TWinControl ControlAtPos
  Params: const Pos : TPoint
          AllowDisabled, AllowWinControls: Boolean
  Results: TControl

  Searches a child (not grand child) control, which client area contains Pos.
  Pos is relative to the ClientOrigin.
------------------------------------------------------------------------------}
function TWinControl.ControlAtPos(const Pos: TPoint;
  AllowDisabled, AllowWinControls: Boolean): TControl;
var
  Flags: TControlAtPosFlags;
begin
  Flags := [capfOnlyClientAreas];
  if AllowDisabled then Include(Flags, capfAllowDisabled);
  if AllowWinControls then Include(Flags, capfAllowWinControls);
  Result := ControlAtPos(Pos, Flags);
end;

{------------------------------------------------------------------------------
  TWinControl ControlAtPos
  Params: const Pos : TPoint
          Flags: TControlAtPosFlags
  Results: TControl

  Searches a child (not grand child) control, which contains Pos.
  Pos is relative to the ClientOrigin.
------------------------------------------------------------------------------}
function TWinControl.ControlAtPos(const Pos: TPoint;
  Flags: TControlAtPosFlags): TControl;
var
  I: Integer;
  P: TPoint;
  LControl: TControl;
  ClientBounds: TRect;

  function GetControlAtPos(AControl: TControl): Boolean;
  var
    ControlPos: TPoint;
  begin
    with AControl do
    begin
      ControlPos := Point(P.X - Left, P.Y - Top);
      Result := (ControlPos.X >= 0) and (ControlPos.Y >= 0) and
                (ControlPos.X < Width) and (ControlPos.Y < Height);

      if Result and (capfOnlyClientAreas in Flags) then
        Result := PtInRect(ClientRect, ControlPos);

      Result := Result
        and (
             (
              (csDesigning in ComponentState)
               and not (csNoDesignVisible in ControlStyle)
               // Here was a VCL bug: VCL checks if control is Visible,
               // which should be ignored at designtime
             )
             or
             (
              (not (csDesigning in ComponentState))
              and
              (Visible)
              and
              (Enabled or (capfAllowDisabled in Flags))
              and
              (Perform(CM_HITTEST, 0,
                       LParam(Integer(PointToSmallPointNoChecks(ControlPos)))) <> 0)
             )
            );
      {$IFDEF VerboseMouseBugfix}
      //if Result then
      DebugLn(['GetControlAtPos ',Name,':',ClassName,
      ' Pos=',Pos.X,',',Pos.Y,
      ' P=',P.X,',',P.Y,
      ' ControlPos=',dbgs(ControlPos),
      ' ClientBounds=',ClientBounds.Left,',',ClientBounds.Top,',',ClientBounds.Right,',',ClientBounds.Bottom,
      // ' OnlyCl=',OnlyClientAreas,
      ' Result=',Result]);
      {$ENDIF}
      if Result then
        LControl := AControl;
    end;
  end;

var
  ScrolledOffset: TPoint;
  OldClientOrigin: TPoint;
  NewClientOrigin: TPoint;
  NewPos: TPoint;
begin
  //debugln(['TWinControl.ControlAtPos START ',DbgSName(Self),' P=',dbgs(Pos)]);

  // check if Pos in visible client area
  ClientBounds := GetClientRect;
  ScrolledOffset := GetClientScrollOffset;
  if capfHasScrollOffset in Flags then
  begin
    { ClientBounds do not include scrolling offset }
    inc(ClientBounds.Left, ScrolledOffset.x);
    inc(ClientBounds.Right, ScrolledOffset.x);
    inc(ClientBounds.Top, ScrolledOffset.y);
    inc(ClientBounds.Bottom, ScrolledOffset.y);
  end;

  if not PtInRect(ClientBounds, Pos) then
  begin
    //debugln(['TWinControl.ControlAtPos OUT OF CLIENTBOUNDS ',DbgSName(Self),' P=',dbgs(Pos),' ClientBounds=',dbgs(ClientBounds)]);
    Result := nil;
    exit;
  end;

  // map Pos to logical client area
  P := Pos;
  if not (capfHasScrollOffset in Flags) then
  begin
    inc(P.X, ScrolledOffset.X);
    inc(P.Y, ScrolledOffset.Y);
  end;

  LControl := nil;
  if FControls<>nil then
  begin
    // check wincontrols
    if (capfAllowWinControls in Flags) then
      for I := FControls.Count - 1 downto 0 do
        if (TObject(FControls[i]) is TWinControl)
        and GetControlAtPos(TControl(FControls[I])) then
          Break;
    // check controls
    if (LControl = nil) and not(capfOnlyWinControls in Flags) then
      for I := FControls.Count - 1 downto 0 do
        if (not (TObject(FControls[i]) is TWinControl))
        and GetControlAtPos(TControl(FControls[I])) then
          Break;
  end;
  Result := LControl;
  
  // check recursive sub children
  if (capfRecursive in Flags) and (Result is TWinControl) and
     (TWinControl(Result).ControlCount > 0) then
  begin
    // in LCL ClientOrigin contains the scroll offset. At least this is so
    // for win32 and gtk2
    OldClientOrigin := ClientOrigin;
    NewClientOrigin := TWinControl(Result).ClientOrigin;
    NewPos := Pos;
    NewPos.X := NewPos.X - NewClientOrigin.X + OldClientOrigin.X;
    NewPos.Y := NewPos.Y - NewClientOrigin.Y + OldClientOrigin.Y;
    LControl := TWinControl(Result).ControlAtPos(NewPos, Flags + [capfHasScrollOffset]);
    //debugln(['TWinControl.RECURSED ControlAtPos Result=',DbgSName(Result),' LControl=',DbgSName(LControl),' ',dbgs(NewPos),' AllowDisabled=',AllowDisabled,' OnlyClientAreas=',OnlyClientAreas]);
    if LControl <> nil then
      Result := LControl;
  end;
  //debugln(['TWinControl.ControlAtPos END ',DbgSName(Self),' P=',dbgs(Pos),' Result=',DbgSName(Result)]);
end;

{-------------------------------------------------------------------------------
  function TWinControl.GetControlIndex(AControl: TControl): integer;


-------------------------------------------------------------------------------}
function TWinControl.GetControlIndex(AControl: TControl): integer;
begin
  if FControls <> nil then
    Result := FControls.IndexOf(AControl)
  else
    Result := -1;
end;

{-------------------------------------------------------------------------------
  function TWinControl.GetControlIndex(AControl: TControl): integer;


-------------------------------------------------------------------------------}
procedure TWinControl.SetControlIndex(AControl: TControl; NewIndex: integer);
begin
  SetChildZPosition(AControl, NewIndex);
end;

{------------------------------------------------------------------------------
  TWinControl DestroyHandle
------------------------------------------------------------------------------}
procedure TWinControl.DestroyHandle;
var
  i: integer;
  AControl: TControl;
begin
  //DebugLn(['TWinControl.DestroyHandle START ',DbgSName(Self)]);
  if not HandleAllocated then begin
    DebugLn('Warning: TWinControl.DestroyHandle ',Name,':',ClassName,' Handle not Allocated');
    //RaiseGDBException('');
  end;

  // First destroy all children handles
  //DebugLn(['TWinControl.DestroyHandle DESTROY CHILDS ',DbgSName(Self)]);
  Include(FControlState, csDestroyingHandle);
  try
    if FControls <> nil then begin
      for i:= 0 to FControls.Count - 1 do begin
        //DebugLn(['  ',i,' ',DbgSName(TObject(FWinControls[i]))]);
        AControl:=TControl(FControls[i]);
        if (AControl is TWinControl) and TWinControl(AControl).HandleAllocated then
          TWinControl(AControl).DestroyHandle;
      end;
    end;
    //DebugLn(['TWinControl.DestroyHandle DESTROY SELF ',DbgSName(Self)]);
    DestroyWnd;
  finally
    Exclude(FControlState, csDestroyingHandle);
  end;
  //DebugLn(['TWinControl.DestroyHandle END ',DbgSName(Self)]);
end;

{------------------------------------------------------------------------------
  TWinControl WndPRoc
------------------------------------------------------------------------------}
procedure TWinControl.WndProc(var Message: TLMessage);
var
  Form: TCustomForm;
begin
  //debugln(['TWinControl.WndProc ',DbgSName(Self),' ',Message.Msg]);
  //DebugLn(Format('Trace:[TWinControl.WndPRoc] %s(%s) --> Message = %d', [ClassName, Name, Message.Msg]));
  case Message.Msg of
    LM_SETFOCUS:
      begin
        //DebugLn(Format('Trace:[TWinControl.WndPRoc] %s --> LM_SETFOCUS', [ClassName]));
        {$IFDEF VerboseFocus}
        DebugLn('TWinControl.WndProc LM_SetFocus ',DbgSName(Self));
        {$ENDIF}
        Form := GetParentForm(Self);
        if Assigned(Form) and not (csDestroyingHandle in ControlState) and not (csDestroying in ComponentState) then
        begin
          if not Form.SetFocusedControl(Self) then
          begin
            {$IFDEF VerboseFocus}
            DebugLn('TWinControl.WndProc LM_SetFocus ',DbgSName(Self),' form=',DbgSName(Form),' Form.SetFocusedControl FAILED');
            {$ENDIF}
            Exit;
          end;
          Message.Result := 0;
        end;
        {$IFDEF VerboseFocus}
        DebugLn('TWinControl.WndProc AFTER form LM_SetFocus ',DbgSName(Self));
        {$ENDIF}
      end;

    LM_KILLFOCUS:
      begin
        //DebugLn(Format('Trace:[TWinControl.WndPRoc] %s --> _KILLFOCUS', [ClassName]));
        if csFocusing in ControlState then
        begin
          {$IFDEF VerboseFocus}
          DebugLn('TWinControl.WndProc LM_KillFocus during focusing ',Name,':',ClassName);
          {$ENDIF}
          Exit;
        end;
        Message.Result:=0;
      end;

    // exclude only LM_MOUSEENTER, LM_MOUSELEAVE
    LM_MOUSEFIRST..LM_MOUSELAST,
    LM_MOUSEFIRST2..LM_RBUTTONQUADCLK,
    LM_XBUTTONTRIPLECLK..LM_MOUSELAST2:
       begin
         {$IFDEF VerboseMouseBugfix}
         DebugLn('TWinControl.WndPRoc A ',Name,':',ClassName);
         {$ENDIF}
         //if Message.Msg=LM_RBUTTONUP then begin DebugLn(['TWinControl.WndProc ',DbgSName(Self)]); DumpStack end;
         DoBeforeMouseMessage;
         if IsControlMouseMSG(Message) then
           Exit
         else
         begin
           if FDockSite and FUseDockManager and Assigned(DockManager) then
             DockManager.MessageHandler(Self, Message);
         end;
         {$IFDEF VerboseMouseBugfix}
         DebugLn('TWinControl.WndPRoc B ',Name,':',ClassName);
         {$ENDIF}
       end;

    LM_KEYFIRST..LM_KEYLAST:
      if Dragging then Exit;

    LM_CANCELMODE:
      if (FindOwnerControl(GetCapture) = Self)
      and (CaptureControl <> nil)
      and (CaptureControl.Parent = Self)
      then CaptureControl.Perform(LM_CANCELMODE,0,0);
    CM_MOUSEENTER,
    CM_MOUSELEAVE:
      begin
        if FDockSite and FUseDockManager and Assigned(DockManager) then
          DockManager.MessageHandler(Self, Message);
      end;
    CM_TEXTCHANGED, CM_VISIBLECHANGED, LM_SIZE, LM_MOVE:
      begin
        // forward message to the dock manager is we are docked
        if (HostDockSite <> nil) and (HostDockSite.UseDockManager) and
           Assigned(HostDockSite.DockManager) then
          HostDockSite.DockManager.MessageHandler(Self, Message);
      end;
  end;

  inherited WndProc(Message);
end;

procedure TWinControl.WSSetText(const AText: String);
begin
  TWSWinControlClass(WidgetSetClass).SetText(Self, AText);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DoAddDockClient(Client: TControl; const ARect: TRect);
  
  Default method for adding a dock client. Become the new parent and break
  old anchored controls.
 ------------------------------------------------------------------------------}
procedure TWinControl.DoAddDockClient(Client: TControl; const ARect: TRect);
begin
  //DebugLn(['TWinControl.DoAddDockClient ',DbgSName(Self),' Client=',DbgSName(Client),' OldParent=',DbgSName(Client.Parent),' Client.AnchoredControlCount=',Client.AnchoredControlCount]);
  Client.Parent := Self;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DockOver(Source: TDragDockObject; X, Y: Integer;
    State: TDragState; var Accept: Boolean);
    
  Called to check whether this control allows docking and where.
 ------------------------------------------------------------------------------}
procedure TWinControl.DockOver(Source: TDragDockObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  if State = dsDragMove then
    PositionDockRect(Source);
  DoDockOver(Source, X, Y, State, Accept);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DoDockOver(Source: TDragDockObject; X, Y: Integer;
    State: TDragState; var Accept: Boolean);
 ------------------------------------------------------------------------------}
procedure TWinControl.DoDockOver(Source: TDragDockObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
begin
  if Assigned(FOnDockOver) then
    FOnDockOver(Self, Source, X, Y, State, Accept);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DoRemoveDockClient(Client: TControl);

  Called to remove client from dock list.
  This method exists for descendent overrides.
 ------------------------------------------------------------------------------}
procedure TWinControl.DoRemoveDockClient(Client: TControl);
begin
  // empty (this method exists for descendent overrides)
  {$IFDEF VerboseDocking}
  DebugLn(['TWinControl.DoRemoveDockClient ',DbgSName(Self),' ',DbgSName(Client)]);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  function TWinControl.DoUnDock(NewTarget: TWinControl; Client: TControl
    ): Boolean;
 ------------------------------------------------------------------------------}
function TWinControl.DoUnDock(NewTarget: TWinControl; Client: TControl;
  KeepDockSiteSize: Boolean): Boolean;
var
  NewBounds: TRect;
begin
  {$IFDEF VerboseDocking}
  DebugLn('TWinControl.DoUnDock ',Name,' NewTarget=',DbgSName(NewTarget),' Client=',DbgSName(Client));
  {$ENDIF}
  Result := True;
  if Assigned(FOnUnDock) then
  begin
    FOnUnDock(Self, Client, NewTarget, Result);
    if not Result then
      Exit;
  end;

  if not KeepDockSiteSize then
  begin
    NewBounds := BoundsRect;
    case Client.Align of
      alLeft:
        inc(NewBounds.Left, Client.Width);
      alTop:
        inc(NewBounds.Top, Client.Height);
      alRight:
        dec(NewBounds.Right, Client.Width);
      alBottom:
        dec(NewBounds.Bottom, Client.Height);
    end;
    SetBoundsKeepBase(NewBounds.Left, NewBounds.Top,
                      NewBounds.Right - NewBounds.Left,
                      NewBounds.Bottom - NewBounds.Top);
  end;

  Result := Result and DoUndockClientMsg(NewTarget, Client);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.GetSiteInfo(Client: TControl; var InfluenceRect: TRect;
    MousePos: TPoint; var CanDock: Boolean);
 ------------------------------------------------------------------------------}
procedure TWinControl.GetSiteInfo(Client: TControl; var InfluenceRect: TRect;
  MousePos: TPoint; var CanDock: Boolean);
const
  ADockMargin = 10;
begin
  GetWindowRect(Handle, InfluenceRect);
  //Margins to test docking (enlarged surface for test)
  InfluenceRect.Left := InfluenceRect.Left-ADockMargin;
  InfluenceRect.Top := InfluenceRect.Top-ADockMargin;
  InfluenceRect.Right := InfluenceRect.Right+ADockMargin;
  InfluenceRect.Bottom := InfluenceRect.Bottom+ADockMargin;

  if UseDockManager then
    CanDock:=DockManager.IsEnabledControl(Client);

  if Assigned(FOnGetSiteInfo) then
    FOnGetSiteInfo(Self, Client, InfluenceRect, MousePos, CanDock);
end;

{------------------------------------------------------------------------------
  function TWinControl.GetParentHandle: HWND;
 ------------------------------------------------------------------------------}
function TWinControl.GetParentHandle: HWND;
begin
  if Parent <> nil then
    Result := Parent.Handle
  else
    Result := ParentWindow;
end;

{------------------------------------------------------------------------------
  function TWinControl.GetTopParentHandle: HWND;
 ------------------------------------------------------------------------------}
function TWinControl.GetTopParentHandle: HWND;
var
  AWinControl: TWinControl;
begin
  AWinControl := Self;
  while AWinControl.Parent <> nil do
    AWinControl := AWinControl.Parent;
  if AWinControl.ParentWindow = 0 then
    Result := AWinControl.Handle
  else
    Result := AWinControl.ParentWindow;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.ReloadDockedControl(const AControlName: string;
    var AControl: TControl);
 ------------------------------------------------------------------------------}
procedure TWinControl.ReloadDockedControl(const AControlName: string;
  var AControl: TControl);
begin
  AControl := Owner.FindComponent(AControlName) as TControl;
end;

{------------------------------------------------------------------------------
  function TWinControl.CreateDockManager: TDockManager;
 ------------------------------------------------------------------------------}
function TWinControl.CreateDockManager: TDockManager;
begin
  if (DockManager = nil) and DockSite and UseDockManager then
    // this control can dock other controls, so it needs a TDockManager
    Result := DefaultDockManagerClass.Create(Self)
  else
    Result := DockManager;
end;

procedure TWinControl.SetDockManager(AMgr: TDockManager);
begin
  //use FDockManager only here!
  if Assigned(DockManager) and (DockManager <> AMgr) then
    if FDockManager.AutoFreeByControl then
      FDockManager.Free;
  FDockManager := AMgr; //can be nil
end;

{------------------------------------------------------------------------------
  procedure TWinControl.SetUseDockManager(const AValue: Boolean);
 ------------------------------------------------------------------------------}
procedure TWinControl.SetUseDockManager(const AValue: Boolean);
begin
  if FUseDockManager=AValue then exit;
  FUseDockManager:=AValue;
  if FUseDockManager and ([csDesigning,csDestroying]*ComponentState=[])
  and (DockManager=nil) then
    DockManager := CreateDockManager;
end;

procedure TWinControl.DoFloatMsg(ADockSource: TDragDockObject);
var
  WasVisible: Boolean;
begin
  if FloatingDockSiteClass = ClassType then
  begin
    WasVisible := Visible;
    try
      Dock(nil, ADockSource.DockRect);
    finally
      if WasVisible then BringToFront;
    end;
  end
  else
    inherited DoFloatMsg(ADockSource);
end;

function TWinControl.GetDockCaption(AControl: TControl): String;
begin
  Result := AControl.GetDefaultDockCaption;
  DoGetDockCaption(AControl, Result);
end;

procedure TWinControl.UpdateDockCaption(Exclude: TControl);
begin
 { Called when this is a hostdocksite and either the list of docked clients have
   changed or one of their captions.
   Exclude an currently undocking control. }
end;

procedure TWinControl.DoGetDockCaption(AControl: TControl; var ACaption: String);
begin
  if Assigned(FOnGetDockCaption) then
    OnGetDockCaption(Self, AControl, ACaption);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.MainWndProc(var Message : TLMessage);

  The message handler of this wincontrol.
  Only needed by controls, which needs features not yet supported by the LCL.
 ------------------------------------------------------------------------------}
procedure TWinControl.MainWndProc(var Msg: TLMessage);
begin
  //DebugLn(Format('Trace:[TWinControl.MainWndPRoc] %s(%s) --> Message = %d', [ClassName, Name, Msg.Msg]));
end;

{------------------------------------------------------------------------------
  TWinControl SetFocus
------------------------------------------------------------------------------}
procedure TWinControl.SetFocus;
var
  Form: TCustomForm;
begin
  {$IFDEF VerboseFocus}
  DebugLn('[TWinControl.SetFocus] ',Name,':',ClassName,' Visible=',dbgs(Visible),' HandleAllocated=',dbgs(HandleAllocated));
  {$ENDIF}
  Form := GetParentForm(Self);
  if Form <> nil then
    Form.FocusControl(Self)
  else
  if IsVisible and HandleAllocated then
    LCLIntf.SetFocus(Handle);
end;

{------------------------------------------------------------------------------
  TWinControl KeyDown
------------------------------------------------------------------------------}
procedure TWinControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyDown) then FOnKeyDown(Self, Key, Shift);
  if Key <> 0 then
    DoCallKeyEventHandler(chtOnKeyDown, Key, Shift);
end;

{------------------------------------------------------------------------------
  TWinControl KeyDownBeforeInterface
------------------------------------------------------------------------------}
procedure TWinControl.KeyDownBeforeInterface(var Key: Word; Shift: TShiftState);
begin
  KeyDown(Key, Shift);
end;

{------------------------------------------------------------------------------
  TWinControl KeyDownAfterInterface
------------------------------------------------------------------------------}
procedure TWinControl.KeyDownAfterInterface(var Key: Word; Shift: TShiftState);
begin

end;

{------------------------------------------------------------------------------
  TWinControl KeyPress
------------------------------------------------------------------------------}
procedure TWinControl.KeyPress(var Key: char);
begin
  if Assigned(FOnKeyPress) then FOnKeyPress(Self, Key);
end;

{------------------------------------------------------------------------------
  TWinControl UTF8KeyPress
  
  Called before KeyPress.
------------------------------------------------------------------------------}
procedure TWinControl.UTF8KeyPress(var UTF8Key: TUTF8Char);
begin
  if Assigned(FOnUTF8KeyPress) then FOnUTF8KeyPress(Self, UTF8Key);
end;

{------------------------------------------------------------------------------
  TWinControl KeyUp
------------------------------------------------------------------------------}
procedure TWinControl.KeyUp(var Key: Word; Shift : TShiftState);
begin
  if Assigned(FOnKeyUp) then FOnKeyUp(Self, Key, Shift);
end;

procedure TWinControl.KeyUpBeforeInterface(var Key: Word; Shift: TShiftState);
begin
  //debugln('TWinControl.KeyUpBeforeInterface ',DbgSName(Self));
  KeyUp(Key,Shift);
end;

procedure TWinControl.KeyUpAfterInterface(var Key: Word; Shift: TShiftState);
begin
  //debugln('TWinControl.KeyUpAfterInterface ',DbgSName(Self));
end;

{------------------------------------------------------------------------------
  TWinControl DoKeyDownBeforeInterface
  
  returns true if handled
------------------------------------------------------------------------------}
function TWinControl.DoKeyDownBeforeInterface(var Message: TLMKey; IsRecurseCall: Boolean): Boolean;

  function IsShortCut: Boolean;
  var
    AParent: TWinControl;
    APopupMenu: TPopupMenu;
  begin
    Result := False;
    // check popup menu
    APopupMenu := PopupMenu;
    if Assigned(APopupMenu) and APopupMenu.IsShortCut(Message) then
      Exit(True);

    if IsRecurseCall then
      Exit;

    // let each parent form handle shortcuts
    AParent := Parent;
    while Assigned(AParent) do
    begin
      if (AParent is TCustomForm) and TCustomForm(AParent).IsShortcut(Message) then
        Exit(True);
      AParent := AParent.Parent;
    end;

    // let application handle shortcut
    if Assigned(Application) and Application.IsShortcut(Message) then
      Exit(True);
  end;

var
  F: TCustomForm;
  ShiftState: TShiftState;
  AParent: TWinControl;
begin
  //debugln('TWinControl.DoKeyDown ',DbgSName(Self),' ShiftState=',dbgs(KeyDataToShiftState(Message.KeyData)),' CharCode=',dbgs(Message.CharCode));
  Result := True;

  with Message do
  begin
    if CharCode = VK_UNKNOWN then Exit;
    ShiftState := KeyDataToShiftState(KeyData);

    if not IsRecurseCall then
    begin
      // let application handle the key
      if Assigned(Application) then
      begin
        Application.NotifyKeyDownBeforeHandler(Self, CharCode, ShiftState);
        if CharCode = VK_UNKNOWN then Exit;
      end;

      // let each parent form with keypreview handle the key
      AParent := Parent;
      while Assigned(AParent) do
      begin
        if (AParent is TCustomForm) then
        begin
          F := TCustomForm(AParent);
          if (F.KeyPreview) and (F.DoKeyDownBeforeInterface(Message, True)) then Exit;
        end;
        AParent := AParent.Parent;
      end;

      if CharCode = VK_UNKNOWN then Exit;
      ShiftState := KeyDataToShiftState(KeyData);

      // let drag object handle the key
      if DragManager.IsDragging then
      begin
        DragManager.KeyDown(CharCode, ShiftState);
        if CharCode = VK_UNKNOWN then Exit;
      end;
    end;

    // let user handle the key
    if not (csNoStdEvents in ControlStyle) then 
    begin
      KeyDownBeforeInterface(CharCode, ShiftState);
      if CharCode = VK_UNKNOWN then Exit;
    end;

    // check the shortcuts
    if IsShortCut then Exit;
  end;

  Result := False;
end;

function TWinControl.ChildKey(var Message: TLMKey): boolean;
begin
  if Assigned(Parent) then
    Result := Parent.ChildKey(Message)
  else
    Result := false;
end;

function TWinControl.DialogChar(var Message: TLMKey): boolean;
var
  I: integer;
begin
  // broadcast to children
  Result := False;
  for I := 0 to ControlCount - 1 do
  begin
    // for Delphi compatibility send it to all controls,
    // even those that can not focus or are disabled
    Result := Controls[I].DialogChar(Message);
    if Result then Exit;
  end;
end;

{------------------------------------------------------------------------------
  TWinControl DoRemainingKeyDown

  Returns True if key handled
------------------------------------------------------------------------------}
function TWinControl.DoRemainingKeyDown(var Message: TLMKeyDown): Boolean;
var
  ShiftState: TShiftState;
begin
  Result := True;
  
  ShiftState := KeyDataToShiftState(Message.KeyData);

  // let parent(s) handle key from child key
  if Assigned(Parent) and Parent.ChildKey(Message) then
    Exit;

  // handle LCL special keys
  ControlKeyDown(Message.CharCode, ShiftState);
  if Message.CharCode = VK_UNKNOWN then Exit;

  //DebugLn('TWinControl.WMKeyDown ',Name,':',ClassName);
  if not (csNoStdEvents in ControlStyle) then
  begin
    KeyDownAfterInterface(Message.CharCode, ShiftState);
    if Message.CharCode = VK_UNKNOWN then Exit;
    // Note: Message.CharCode can now be different or even 0
  end;

  // let application handle the remaining key
  if Assigned(Application) then
    Application.NotifyKeyDownHandler(Self, Message.CharCode, ShiftState);
  if Message.CharCode = VK_UNKNOWN then Exit;

  Result := False;
end;

{------------------------------------------------------------------------------
  TWinControl DoKeyPress
  
  Returns True if key handled
------------------------------------------------------------------------------}
function TWinControl.DoKeyPress(var Message : TLMKey): Boolean;
var
  F: TCustomForm;
  C: char;
  AParent: TWinControl;
begin
  Result := True;

  // let each parent form with keypreview handle the key
  AParent := Parent;
  while (AParent <> nil) do
  begin
    if (AParent is TCustomForm) then
    begin
      F := TCustomForm(AParent);
      if F.KeyPreview and F.DoKeyPress(Message) then Exit;
    end;
    AParent := AParent.Parent;
  end;

  if not (csNoStdEvents in ControlStyle) then
    with Message do
    begin
      C := Char(CharCode);
      KeyPress(C);
      CharCode := Ord(C);
      if Char(CharCode) = #0 then Exit;
    end;

  Result := False;
end;

{------------------------------------------------------------------------------
  TWinControl DoRemainingKeyPress
  
  Returns True if key handled
------------------------------------------------------------------------------}
function TWinControl.SendDialogChar(var Message : TLMKey): Boolean;
var
  ParentForm: TCustomForm;
begin
  Result := False;
  if WidgetSet.GetLCLCapability(lcAccelleratorKeys) = LCL_CAPABILITY_NO then Exit;
  ParentForm := GetParentForm(Self);
  if ParentForm <> nil then
  begin
    Result := ParentForm.DialogChar(Message);
    if Result then 
      Message.CharCode := VK_UNKNOWN;
  end;
end;

function TWinControl.DoRemainingKeyUp(var Message: TLMKeyDown): Boolean;
var
  ShiftState: TShiftState;
begin
  //debugln('TWinControl.DoRemainingKeyUp ',DbgSName(Self));
  Result := True;

  ShiftState := KeyDataToShiftState(Message.KeyData);

  // handle LCL special keys
  ControlKeyUp(Message.CharCode,ShiftState);
  if Message.CharCode=VK_UNKNOWN then exit;

  if not (csNoStdEvents in ControlStyle) then
  begin
    KeyUpAfterInterface(Message.CharCode, ShiftState);
    if Message.CharCode=VK_UNKNOWN then exit;
    // Note: Message.CharCode can now be different or even 0
  end;
  Result := False;
end;

{------------------------------------------------------------------------------
  TWinControl DoUTF8KeyPress

  Returns True if key handled
------------------------------------------------------------------------------}
function TWinControl.DoUTF8KeyPress(var UTF8Key: TUTF8Char): boolean;
var
  AParent: TWinControl;
  F: TCustomForm;
begin
  Result := True;
  
  // let each parent form with keypreview handle the key
  AParent := Parent;
  while Assigned(AParent) do
  begin
    if (AParent is TCustomForm) then
    begin
      F := TCustomForm(AParent);
      if (F.KeyPreview) and F.DoUTF8KeyPress(UTF8Key) then Exit;
    end;
    AParent := AParent.Parent;
  end;
  
  if not (csNoStdEvents in ControlStyle) then
  begin
    UTF8KeyPress(UTF8Key);
    if UTF8Key = '' then Exit;
  end;

  // redirect to designer
  if (csDesigning in ComponentState) then
  begin
    F := GetDesignerForm(Self);
    if Assigned(F) and Assigned(F.Designer) then
    begin
      F.Designer.UTF8KeyPress(UTF8Key);
      if UTF8Key = '' then Exit;
    end;
  end;

  Result := False;
end;

{------------------------------------------------------------------------------
  TWinControl DoKeyUpBeforeInterface

  Returns True if key handled
------------------------------------------------------------------------------}
function TWinControl.DoKeyUpBeforeInterface(var Message : TLMKey): Boolean;
var
  F: TCustomForm;
  ShiftState: TShiftState;
  AParent: TWinControl;
begin
  Result := True;

  // let each parent form with keypreview handle the key
  AParent:=Parent;
  while (AParent<>nil) do begin
    if (AParent is TCustomForm) then begin
      F := TCustomForm(AParent);
      if  (F.KeyPreview)
      and (F.DoKeyUpBeforeInterface(Message)) then Exit;
    end;
    AParent:=AParent.Parent;
  end;

  with Message do
  begin
    ShiftState := KeyDataToShiftState(KeyData);

    if DragManager.IsDragging then
    begin
      DragManager.KeyUp(CharCode, ShiftState);
      if CharCode = VK_UNKNOWN then Exit;
    end;
    
    if not (csNoStdEvents in ControlStyle)
    then begin
      KeyUpBeforeInterface(CharCode, ShiftState);
      if CharCode = VK_UNKNOWN then Exit;
    end;

    // TODO
    //if (CharCode = VK_APPS) and not (ssAlt in ShiftState) then
    //  CheckMenuPopup(SmallPoint(0, 0));
  end;
  Result := False;
end;

{------------------------------------------------------------------------------
  TWinControl ControlKeyDown
------------------------------------------------------------------------------}
procedure TWinControl.ControlKeyDown(var Key: Word; Shift: TShiftState);
begin
  Application.ControlKeyDown(Self,Key,Shift);
end;

procedure TWinControl.ControlKeyUp(var Key: Word; Shift: TShiftState);
begin
  //debugln('TWinControl.ControlKeyUp ',DbgSName(Self));
  Application.ControlKeyUp(Self,Key,Shift);
end;

{------------------------------------------------------------------------------
  TWinControl CreateParams
------------------------------------------------------------------------------}
procedure TWinControl.CreateParams(var Params : TCreateParams);
begin
  FillChar(Params, SizeOf(Params),0);
  Params.Caption := PChar(FCaption);
  Params.Style := WS_CHILD or WS_CLIPSIBLINGS or WS_CLIPCHILDREN;
  Params.ExStyle := 0;
  if csAcceptsControls in ControlStyle then
    Params.ExStyle := Params.ExStyle or WS_EX_CONTROLPARENT;
  if BorderStyle = bsSingle then
    Params.ExStyle := Params.ExStyle or WS_EX_CLIENTEDGE;
  if TabStop then
    Params.Style := Params.Style or WS_TABSTOP;

  if (Parent <> nil) then
    Params.WndParent := Parent.Handle
  else
    Params.WndParent := ParentWindow;

  Params.X := Left;
  Params.Y := Top;
  Params.Width := Width;
  Params.Height := Height;
end;

{------------------------------------------------------------------------------
  TWinControl Invalidate
------------------------------------------------------------------------------}
procedure TWinControl.Invalidate;
begin
  //DebugLn(['TWinControl.Invalidate ',DbgSName(Self),' HandleAllocated=',HandleAllocated]);
  if HandleAllocated and ([csDestroying,csLoading]*ComponentState=[]) then
    TWSWinControlClass(WidgetSetClass).Invalidate(Self);
end;

{------------------------------------------------------------------------------
  TWinControl AddControl

  Add Handle object to parents Handle object.
------------------------------------------------------------------------------}
procedure TWinControl.AddControl;
begin
  TWSControlClass(WidgetSetClass).AddControl(Self);
end;

{------------------------------------------------------------------------------
  TWinControl Repaint
------------------------------------------------------------------------------}
procedure TWinControl.Repaint;
begin
  if (not HandleAllocated) or (csDestroying in ComponentState) then exit;
  {$IFDEF VerboseDsgnPaintMsg}
  if csDesigning in ComponentState then
    DebugLn('TWinControl.Repaint A ',Name,':',ClassName);
  {$ENDIF}
  TWSWinControlClass(WidgetSetClass).Repaint(Self);
end;

{------------------------------------------------------------------------------
  TWinControl Insert
------------------------------------------------------------------------------}
procedure TWinControl.Insert(AControl : TControl);
begin
  Insert(AControl,ControlCount);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.Insert(AControl: TControl; Index: integer);
------------------------------------------------------------------------------}
procedure TWinControl.Insert(AControl: TControl; Index: integer);
begin
  if AControl = nil then exit;
  if AControl.FParent<>nil then
    raise EInvalidOperation.Create('control has already a parent');
  
  if AControl = Self then
    raise EInvalidOperation.Create(rsAControlCanNotHaveItselfAsParent);

  ListInsert(FControls, Index, AControl);
  if AControl is TWinControl then
  begin
    ListAdd(FTabList, AControl);

    if (csDesigning in ComponentState) and (not (csLoading in ComponentState))
    and AControl.CanTab then
      TWinControl(AControl).TabStop := true;
  end;

  AControl.FParent := Self;
  if AControl.FAutoSizingLockCount>0 then
  begin
    // the AControl has disabled autosizing => disable it for the parent=self too
    //DebugLn([Space(FAutoSizingLockCount*2+2),'TWinControl.Insert ',DbgSName(Self),' Control=',DbgSName(AControl),' disable Parent']);
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TControl.DisableAutoSizing'){$ENDIF};
  end;
end;

{------------------------------------------------------------------------------
  TWinControl ReAlign

  Realign all children
------------------------------------------------------------------------------}
procedure TWinControl.ReAlign;
begin
  AdjustSize;
end;

procedure TWinControl.ScrollBy_WS(DeltaX, DeltaY: Integer);
begin
  if HandleAllocated then
    TWSWinControlClass(WidgetSetClass).ScrollBy(Self, DeltaX, DeltaY)
  else
    raise Exception.Create('TWinControl.ScrollBy_WS: Handle not allocated');
end;

procedure TWinControl.ScrollBy(DeltaX, DeltaY: Integer);
var
  i: Integer;
begin
  // scroll inner controls
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.ScrollBy'){$ENDIF};
  try
    for i := 0 to ControlCount - 1 do
      with Controls[i] do
        SetBounds(Left + DeltaX, Top + DeltaY, Width, Height);
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.ScrollBy'){$ENDIF};
  end;
end;

{------------------------------------------------------------------------------
  TWinControl Remove
------------------------------------------------------------------------------}
procedure TWinControl.Remove(AControl : TControl);
begin
  if AControl <> nil then
  begin
    //DebugLn(Format('trace:[TWinControl.Remove] %s(%S) --> Remove: %s(%s)', [ClassName, Name, AControl.ClassName, AControl.Name]));
    if AControl is TWinControl then
      ListRemove(FTabList, AControl);
    ListRemove(FControls, AControl);
    ListRemove(FAlignOrder, AControl);
    AControl.FParent := nil;
    if AControl.FAutoSizingLockCount>0 then
    begin
      // AControl has disabled autosizing and thus for its parent=Self too
      // end disable autosize for parent=self
      //DebugLn([Space(FAutoSizingLockCount*2),'TWinControl.Remove ',DbgSName(Self),' Control=',DbgSName(AControl),' enable Parent']);
      EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TControl.DisableAutoSizing'){$ENDIF};
    end;
  end;
end;

procedure TWinControl.AlignNonAlignedControls(ListOfControls: TFPList;
  var BoundsModified: Boolean);
{ All controls, not aligned/anchored by their own properties, can be auto aligned.

  Example:
    cclLeftToRightThenTopToBottom

  +-----------------------------------+
  |+---------------------------------+|
  || Control1 | Control2 | Control 3 ||
  |+---------------------------------+|
  |+---------------------------------+|
  || Control4 | Control5 | Control 6 ||
  |+---------------------------------+|
  |+---------------------+            |
  || Control7 | Control8 |            |
  |+---------------------+            |
  +-----------------------------------+
}
var
  Box: TAutoSizeBox;
  r: TRect;
begin
  // check if ChildSizing aligning is enabled
  if (ChildSizing.Layout=cclNone) or (ListOfControls.Count=0) then
    exit;

  //debugln('TWinControl.AlignNonAlignedControls ',DbgSName(Self),' ListOfControls.Count=',dbgs(ListOfControls.Count),' ',dbgs(ord(ChildSizing.EnlargeHorizontal)));
  
  Box:=TAutoSizeBox.Create;
  try
    r:=GetLogicalClientRect;
    BoundsModified:=Box.AlignControlsInTable(ListOfControls,ChildSizing,BiDiMode,
                                             r.Right,r.Bottom,true);
  finally
    Box.Free;
  end;
end;

class procedure TWinControl.WSRegisterClass;
const
  Registered : boolean = False;
begin
  if Registered then
    Exit;
  inherited WSRegisterClass;
  RegisterWinControl;
  RegisterPropertyToSkip(TWinControl, 'ParentDoubleBuffered', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TWinControl, 'ImeMode', 'VCL compatibility property', '');
  RegisterPropertyToSkip(TWinControl, 'ImeName', 'VCL compatibility property', '');
  Registered := True;
end;

function TWinControl.IsClientHeightStored: boolean;
begin
  // The ClientHeight is needed to restore children anchored akBottom
  Result:=ControlCount>0;
end;

function TWinControl.IsClientWidthStored: boolean;
begin
  // The ClientWidth is needed to restore children anchored akRight
  Result:=ControlCount>0;
end;

{------------------------------------------------------------------------------
  TWinControl RemoveFocus
------------------------------------------------------------------------------}
procedure TWinControl.RemoveFocus(Removing : Boolean);
var
  Form: TCustomForm;
begin
  Form := GetParentForm(Self);
  if Form <> nil then Form.DefocusControl(Self, Removing);
end;

{------------------------------------------------------------------------------
  TWinControl UpdateControlState

  Called by: RecreateWnd, TCustomTabControl.ShowCurrentPage,
    TWinControl.SetParentWindow, TWinControl.InsertControl,
    TWinControl.CMVisibleChanged
------------------------------------------------------------------------------}
procedure TWinControl.UpdateControlState;
begin
  if HandleObjectShouldBeVisible then
    AdjustSize // this will trigger DoAllAutoSize, which calls UpdateShowing
  else
    UpdateShowing; // hide immediately
end;

{------------------------------------------------------------------------------
  TWinControl InsertControl
------------------------------------------------------------------------------}
procedure TWinControl.InsertControl(AControl: TControl);
begin
  InsertControl(AControl, ControlCount);
end;

procedure TWinControl.InsertControl(AControl: TControl; Index: integer);
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.InsertControl'){$ENDIF};
  try
    AControl.ValidateContainer(Self);
    Perform(CM_CONTROLLISTCHANGE, WParam(AControl), LParam(True));
    Insert(AControl,Index);
    Assert(AControl.Parent = Self, 'TWinControl.InsertControl: AControl.Parent <> Self');
    UpdateAlignIndex(AControl);
    if not (csReading in AControl.ComponentState) then
    begin
      AControl.Perform(CM_PARENTCOLORCHANGED, 0, 0);
      AControl.Perform(CM_PARENTSHOWHINTCHANGED, 0, 0);
      AControl.Perform(CM_PARENTBIDIMODECHANGED, 0, 0);
      AControl.Perform(CM_PARENTFONTCHANGED, 0, 0);
      AControl.Perform(CM_PARENTDOUBLEBUFFEREDCHANGED, 0, 0);
      AControl.UpdateBaseBounds(false,true,false);
      if AControl is TWinControl then
        TWinControl(AControl).UpdateControlState
      else
      if HandleAllocated then
        AControl.Invalidate;
      //DebugLn('TWinControl.InsertControl ',Name,':',ClassName);
    end;
    AdjustSize;
    Perform(CM_CONTROLCHANGE, WParam(AControl), LParam(True));
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.InsertControl'){$ENDIF};
  end;
  //debugln(['TWinControl.InsertControl ',DbgSName(Self),' ',csDesigning in ComponentState,' ',DbgSName(AControl),' ',csDesigning in AControl.ComponentState]);
end;

{------------------------------------------------------------------------------
  TWinControl removeControl
------------------------------------------------------------------------------}
procedure TWinControl.RemoveControl(AControl: TControl);
var
  AWinControl: TWinControl;
  AGrControl: TGraphicControl;
begin
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.RemoveControl'){$ENDIF};
  try
    Perform(CM_CONTROLCHANGE, WParam(AControl), LParam(False));
    if AControl is TWinControl then
    begin
      AWinControl := TWinControl(AControl);
      AWinControl.RemoveFocus(True);
      if AWinControl.HandleAllocated then
        AWinControl.DestroyHandle;
    end
    else
    begin
      if AControl is TGraphicControl then
      begin
        AGrControl := TGraphicControl(AControl);
        if (AGrControl.Canvas<>nil) then
          TControlCanvas(AGrControl.Canvas).FreeHandle;
      end;
      if HandleAllocated then
        AControl.InvalidateControl(AControl.IsVisible, False, True);
    end;
    Remove(AControl);
    Perform(CM_CONTROLLISTCHANGE, WParam(AControl), LParam(False));
    if not (csDestroying in ComponentState) then
    begin
      InvalidatePreferredSize;
      AdjustSize;
    end;
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.RemoveControl'){$ENDIF};
  end;
end;

function TWinControl.GetEnumeratorControls: TWinControlEnumerator;
begin
  Result:=TWinControlEnumerator.Create(Self,true);
end;

function TWinControl.GetEnumeratorControlsReverse: TWinControlEnumerator;
begin
  Result:=TWinControlEnumerator.Create(Self,false);
end;

{------------------------------------------------------------------------------
  TWinControl AlignControl
------------------------------------------------------------------------------}
procedure TWinControl.AlignControl(AControl: TControl);
var
  ARect: TRect;
  NewRect: TRect;
begin
  //if csDesigning in ComponentState then begin
  //  DbgOut('TWinControl.AlignControl ',Name,':',ClassName);
  //  if AControl<>nil then DebugLn(' AControl=',AControl.Name,':',AControl.ClassName) else DebugLn(' AControl=nil');;
  //end;
  if csDestroying in ComponentState then exit;

  // only called by DoAllAutoSize, so no check needed

  DisableAlign;
  try
    // store
    ARect := GetClientRect;
    AdjustClientRect(ARect);
    FAdjustClientRectRealized:=ARect;

    ARect:=GetLogicalClientRect;
    AlignControls(AControl, ARect);
    // some widgetsets updates their clientrect when the first child was moved
    // do a second pass if ClientRect changed
    NewRect:=GetLogicalClientRect;
    if not CompareRect(@ARect,@NewRect) then
      AlignControls(AControl, NewRect);
  finally
    EnableAlign;
  end;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.ContainsControl
  Params:  Control: the control to be checked
  Returns: Self is a (super)parent of Control

  Checks if Control is a child of Self
 ------------------------------------------------------------------------------}
function TWinControl.ContainsControl(Control: TControl): Boolean;
begin
  while (Control <> nil) and (Control <> Self) do Control := Control.Parent;
  Result := Control = Self;
end;

function TWinControl.GetBorderStyle: TBorderStyle;
begin
  Result := TBorderStyle(FBorderStyle);
end;

function TWinControl.GetBrush: TBrush;
begin
  if not BrushCreated then
    CreateBrush;
  Result := FBrush;
end;

function TWinControl.GetControl(const Index: Integer): TControl;
begin
  Result := TControl(FControls[Index]);
end;

function TWinControl.GetControlCount: Integer;
begin
  if FControls <> nil then
    Result := FControls.Count
  else
    Result := 0;
end;

function TWinControl.GetDockClientCount: Integer;
begin
  if FDockClients <> nil then
    Result := FDockClients.Count
  else
    Result := 0;
end;

function TWinControl.GetDockClients(Index: Integer): TControl;
begin
  if FDockClients <> nil then
    Result := TControl(FDockClients[Index])
  else
    Result := nil;
end;

function TWinControl.GetHandle: HWND;
begin
  //if not HandleAllocated then DebugLn('TWinControl.GetHandle Creating handle on the fly: ',DbgSName(Self));
  HandleNeeded;
  Result := FHandle;
end;

{------------------------------------------------------------------------------
  TWinControl SetHandle
  Params:  NewHandle
  Returns: Nothing
-------------------------------------------------------------------------------}
procedure TWinControl.SetHandle(NewHandle: HWND);
begin
  //if (NewHandle=0) and (AnsiCompareText(ClassName,'TPAGE')=0) then
  //  RaiseGDBException('TWincontrol.SetHandle');
  FHandle:=NewHandle;
  InvalidatePreferredSize;
end;

procedure TWinControl.SetParentBackground(const AParentBackground: Boolean);
begin
  if ParentBackground = AParentBackground then
    Exit;

  if AParentBackground then
    ControlStyle := ControlStyle + [csParentBackground]
  else
    ControlStyle := ControlStyle - [csParentBackground];
  Invalidate;
end;

procedure TWinControl.SetParentDoubleBuffered(Value: Boolean);
begin
  if FParentDoubleBuffered <> Value then
  begin
    FParentDoubleBuffered := Value;
    if Assigned(FParent) and not (csReading in ComponentState) then
      Perform(CM_PARENTDOUBLEBUFFEREDCHANGED, 0, 0);
  end;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.Create
  Params:  None
  Returns: Nothing

  Constructor for the class.
 ------------------------------------------------------------------------------}
constructor TWinControl.Create(TheOwner : TComponent);
begin
  // do not set borderstyle, because TCustomForm needs to set it before calling
  // inherited, to have it set before handle is created via streaming
  // use property that bsNone is zero
  //FBorderStyle := bsNone;
  inherited Create(TheOwner);
  FParentDoubleBuffered := True;
  FCompStyle := csWinControl;
  FChildSizing:=TControlChildSizing.Create(Self);
  FChildSizing.OnChange:=@DoChildSizingChange;
  FBrush := nil; // Brush will be created on demand. Only few controls need it.
  FTabOrder := -1;
  FTabStop := False;
  InvalidateClientRectCache(false);
end;

{------------------------------------------------------------------------------
  TWinControl CreateParented
------------------------------------------------------------------------------}
constructor TWinControl.CreateParented(AParentWindow: HWND);
begin
  FParentWindow := AParentWindow;
  Create(nil);
end;

{------------------------------------------------------------------------------
  TWinControl CreateParentedControl
------------------------------------------------------------------------------}
class function TWinControl.CreateParentedControl(AParentWindow: HWND
  ): TWinControl;
begin
  Result := CreateParented(AParentWindow);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.Destroy
  Params:  None
  Returns: Nothing

  Destructor for the class.
 ------------------------------------------------------------------------------}
destructor TWinControl.Destroy;
var
  n: Integer;
  Control: TControl;
begin
  //DebugLn('[TWinControl.Destroy] A  ',Name,':',ClassName);
  // prevent parent to try to focus a to be destroyed control
  if Parent <> nil then
    RemoveFocus(true);
  if HandleAllocated then
    DestroyHandle;
  //DebugLn('[TWinControl.Destroy] B  ',Name,':',ClassName);

  //for n:=0 to ComponentCount-1 do
  //  DebugLn('  n=',n,' ',Components[n].ClassName);

  n := ControlCount;

  while n > 0 do
  begin
    Control := Controls[n - 1];
    //DebugLn('[TWinControl.Destroy] C  ',Name,':',ClassName,' ',Control.Name,':',Control.ClassName);
    Remove(Control); // this sets Control.Parent to nil
    //DebugLn(['TWinControl.Destroy ',DbgSName(Control.HostDockSite)]);
    if Control.HostDockSite = Self then
      Control.HostDockSite := nil;
    // don't free the control, controls are freed by the owner
    n := ControlCount;
  end;

  // undock controls that use this as HostDockSite
  while DockClientCount>0 do begin
    Control:=DockClients[DockClientCount-1];
    //DebugLn(['TWinControl.Destroy ',DbgSName(Self),' undocking ',DbgSName(Control)]);
    Control.HostDockSite:=nil;
  end;

  FreeAndNil(FAlignOrder);
  FreeThenNil(FBrush);
  FreeThenNil(FChildSizing);
  if (FDockManager<>nil) then
    if FDockManager.AutoFreeByControl then
      FreeThenNil(FDockManager)
    else
      FDockManager:=nil;
  FreeThenNil(FDockClients);
  FreeThenNil(FTabList);
  //DebugLn('[TWinControl.Destroy] D  ',Name,':',ClassName);
  inherited Destroy;
  //DebugLn('[TWinControl.Destroy] END  ',Name,':',ClassName);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.DoEnter
  Params: none
  Returns: Nothing

  Call user's callback for OnEnter.
 ------------------------------------------------------------------------------}
procedure TWinControl.DoEnter;
begin
  if Assigned(FOnEnter) then FOnEnter(Self);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.DoExit
  Params: none
  Returns: Nothing

  Call user's callback for OnExit.
 ------------------------------------------------------------------------------}
procedure TWinControl.DoExit;
begin
  if Assigned(FOnExit) then FOnExit(Self);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DoFlipChildren;
  
  Flip children horizontally. That means mirroring the left position.
 ------------------------------------------------------------------------------}
procedure TWinControl.DoFlipChildren;
var
  i: Integer;
  CurControl: TControl;
  AWidth: Integer;
  SaveLeft: Integer;
begin
  AWidth:=GetLogicalClientRect.Right;
  DisableAlign;
  for i:=0 to ControlCount-1 do begin
    CurControl:=Controls[i];
    // flip BorderSpacing
    SaveLeft := CurControl.BorderSpacing.Left;
    CurControl.BorderSpacing.Left := CurControl.BorderSpacing.Right;
    CurControl.BorderSpacing.Right := SaveLeft;
    // flip control and anchors
    CurControl.Left:=AWidth-CurControl.Left-CurControl.Width;
    CurControl.Anchors := BidiFlipAnchors(CurControl, True);
  end;
  EnableAlign;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.CMEnabledChanged
  Params: Message
  Returns: Nothing

  Called when enabled is changed. Takes action to enable control
 ------------------------------------------------------------------------------}
procedure TWinControl.CMEnabledChanged(var Message: TLMessage);
begin
  if not Enabled and (Parent <> nil)
  then RemoveFocus(False);

  if HandleAllocated and not (csDesigning in ComponentState) then begin
    //if (not Enabled) then debugln('TWinControl.CMEnabledChanged disable ',Name,':',CLassName);
    EnableWindow(Handle, Enabled);
  end;
  inherited;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.CMShowHintChanged
  Params: Message
  Returns: Nothing

  Called when showhint is changed. Notifies children
 ------------------------------------------------------------------------------}
procedure TWinControl.CMShowHintChanged(var Message: TLMessage);
begin
  NotifyControls(CM_PARENTSHOWHINTCHANGED);
end;

procedure TWinControl.CMBiDiModeChanged(var Message: TLMessage);
begin
  inherited CMBiDiModeChanged(Message);
  NotifyControls(CM_PARENTBIDIMODECHANGED);
  if HandleAllocated and (Message.wParam = 0) then
    TWSWinControlClass(WidgetSetClass).SetBiDiMode(Self,
       UseRightToLeftAlignment, UseRightToLeftReading, UseRightToLeftScrollBar);
  AdjustSize;
end;

procedure TWinControl.CMBorderChanged(var Message: TLMessage);
begin
  DoAdjustClientRectChange;
  AdjustSize;
  Invalidate;
end;

procedure TWinControl.CMDoubleBufferedChanged(var Message: TLMessage);
begin
  NotifyControls(CM_PARENTDOUBLEBUFFEREDCHANGED);
  Invalidate;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMSetFocus
  Params: Message
  Returns: Nothing

  SetFocus event handler
 ------------------------------------------------------------------------------}
procedure TWinControl.WMSetFocus(var Message: TLMSetFocus);
begin
  {$IFDEF VerboseFocus}
  DebugLn('TWinControl.WMSetFocus A ',Name,':',ClassName);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method: TWinControl.LMKillFocus
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMKillFocus(var Message: TLMKillFocus);
var
  ParentForm: TCustomForm;
begin
  //DebugLn('TWinControl.WMKillFocus A ',Name,':',ClassName);
  //DebugLn(Format('Trace: %s', [ClassName]));
  if [csLoading,csDestroying,csDesigning]*ComponentState=[] then
  begin
    ParentForm := GetParentForm(Self);
    if Assigned(ParentForm) and ParentForm.Active then
      EditingDone;
  end;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMPaint
  Params:   Msg: The paint message
  Returns:  nothing

  Paint event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMPaint(var Msg: TLMPaint);
var
  DC,MemDC: HDC;
{$ifdef BUFFERED_WMPAINT}
  MemBitmap, OldBitmap : HBITMAP;
  MemWidth: Integer;
  MemHeight: Integer;
{$ENDIF}
  PS : TPaintStruct;
  ClientBoundRect: TRect;
begin
  //DebugLn('[TWinControl.WMPaint] ',DbgSName(Self),'  ',DbgS(Msg.DC));
  {$IFDEF VerboseResizeFlicker}
  DebugLn('[TWinControl.WMPaint] ',DbgSName(Self),'  Bounds=',dbgs(BoundsRect),' ClientRect=',dbgs(ClientRect));
  {$ENDIF}
  if ([csDestroying,csLoading]*ComponentState<>[]) or (not HandleAllocated) then
    exit;

  {$IFDEF VerboseDsgnPaintMsg}
  if csDesigning in ComponentState then
    DebugLn('TWinControl.WMPaint A ',Name,':',ClassName);
  {$ENDIF}

  //if Name='GroupBox1' then
  //  debugln(['TWinControl.WMPaint ',DbgSName(Self),' DoubleBuffered=',DoubleBuffered,' Msg.DC=',dbgs(Msg.DC),' csCustomPaint=',csCustomPaint in ControlState,' ControlCount=',ControlCount,' ClientRect=',dbgs(ClientRect)]);
  if (Msg.DC <> 0) or not TWSWinControlClass(WidgetSetClass).GetDoubleBuffered(Self) then
  begin
    if not (csCustomPaint in ControlState) and (ControlCount = 0) then
      begin
        DefaultHandler(Msg);
      end
    else
      PaintHandler(Msg);
  end
  else begin
    // NOTE: not every interface uses this part
    //DebugLn('TWinControl.WMPaint Painting doublebuffered ',Name,':',classname);
{$ifdef BUFFERED_WMPAINT}
    DC := GetDC(0);
    MemWidth:=Width;
    MemHeight:=Height;
    MemBitmap := CreateCompatibleBitmap(DC, MemWidth, MemHeight);
    ReleaseDC(0, DC);
    MemDC := CreateCompatibleDC(0);
    OldBitmap := SelectObject(MemDC, MemBitmap);
{$ENDIF}
    try
      // Fetch a DC of the whole Handle (including client area)
      DC := BeginPaint(Handle, PS);
      if DC=0 then exit;
{$ifNdef BUFFERED_WMPAINT}
      MemDC := DC;
{$ENDIF}
      // erase background
      Include(FWinControlFlags,wcfEraseBackground);
      Perform(LM_ERASEBKGND, WParam(MemDC), 0);
      Exclude(FWinControlFlags,wcfEraseBackground);
      // create a paint message to paint the child controls.
      // WMPaint expects the DC origin to be equal to the client origin of its
      // parent
      // -> Move the DC Origin to the client origin
      if not GetClientBounds(Handle,ClientBoundRect) then exit;
      MoveWindowOrgEx(MemDC,ClientBoundRect.Left,ClientBoundRect.Top);
      // handle the paint message
      Msg.DC := MemDC;
      Perform(LM_PAINT, WParam(MemDC), 0);
      Msg.DC := 0;
      // restore the DC origin
      MoveWindowOrgEx(MemDC,-ClientBoundRect.Left,-ClientBoundRect.Top);
{$ifdef BUFFERED_WMPAINT}
      BitBlt(DC, 0,0, MemWidth, MemHeight, MemDC, 0, 0, SRCCOPY);
{$ENDIF}
      EndPaint(Handle, PS);
    finally
      Exclude(FWinControlFlags,wcfEraseBackground);
{$ifdef BUFFERED_WMPAINT}
      SelectObject(MemDC, OldBitmap);
      DeleteDC(MemDC);
      DeleteObject(MemBitmap);
{$ENDIF}
    end;
  end;
  //DebugLn(Format('Trace:< [TWinControl.WMPaint] %s', [ClassName]));
//DebugLn('[TWinControl.WMPaint] END ',Name,':',ClassName);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMDestroy
  Params:   Msg: The destroy message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMDestroy(var Message: TLMDestroy);
begin
  //DebugLn(Format('Trace: [TWinControl.LMDestroy] %s', [ClassName]));
  //DebugLn('TWinControl.WMDestroy ',Name,':',ClassName);
  // Our widget/window doesn't exist anymore
  Handle := 0;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMMove
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMMove(var Message: TLMMove);
var
  NewWidth, NewHeight: Integer;
  NewBoundsRealized: TRect;
  TopParent: TControl;

  procedure RaiseLoop;
  begin
    raise ELayoutException.Create('TWinControl.WMMove loop detected: '+DbgSName(Self)+' BoundsRealized='+dbgs(FBoundsRealized)+' NewBoundsRealized='+dbgs(NewBoundsRealized));
  end;

begin
  {$IF defined (VerboseSizeMsg) or defined(VerboseIntfSizing)}
  if (Message.MoveType and Move_SourceIsInterface)>0 then
   DebugLn(['TWinControl.WMMove A ',DbgSName(Self),' Message=',Message.XPos,',',Message.YPos,
    ' BoundsRealized=',FBoundsRealized.Left,',',FBoundsRealized.Top,
    ' FromIntf=',Message.MoveType=Move_SourceIsInterface,
    ',',FBoundsRealized.Right-FBoundsRealized.Left,
    'x',FBoundsRealized.Bottom-FBoundsRealized.Top]);
  {$ENDIF}
  NewWidth := Width;
  NewHeight := Height;
  if (Message.MoveType and Move_SourceIsInterface)>0 then
  begin
    if not (wcfBoundsRealized in FWinControlFlags) then exit;
    // interface widget has moved
    // -> update size and realized bounds
    NewWidth := FBoundsRealized.Right - FBoundsRealized.Left;
    NewHeight := FBoundsRealized.Bottom - FBoundsRealized.Top;
    // skip size update when window is minimized
    if HandleAllocated and (not IsIconic(Handle)) then
      GetWindowSize(Handle, NewWidth, NewHeight);

    NewBoundsRealized:=Bounds(Message.XPos, Message.YPos, NewWidth, NewHeight);
    if CompareRect(@NewBoundsRealized,@FBoundsRealized) then exit;

    TopParent:=GetTopParent;
    if (TopParent is TWinControl)
    and (wcfKillIntfSetBounds in TWinControl(TopParent).FWinControlFlags) then
      RaiseLoop;

    FBoundsRealized := NewBoundsRealized;
    if ([caspCreatingHandles,caspComputingBounds]*AutoSizePhases<>[]) then
    begin
      // while the LCL is creating handles the widgetset may send default bounds
      // we have not yet told the widgetset the final bounds
      // => the InvalidatePreferredSize and the InvalidateClientRectCache
      //    (invoked by the widgetset) may trigger a further loop in the auto
      //    size algorithm to take care of the new bounds
      // => do not call SetBounds, as this will set the Bounds to the widgetset
      //    default values.
      //DebugLn(['TWinControl.WMMove from intf ignored, because phases=',dbgs(AutoSizePhases),' boundsrealized=',wcfBoundsRealized in FWinControlFlags]);
      exit;
    end;
  end;
  SetBounds(Message.XPos, Message.YPos, NewWidth, NewHeight);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMSize
  Params:   Message: TLMSize
  Returns:  nothing

  Event handler for size messages. This is called, whenever width, height,
  clientwidth or clientheight have changed.
  If the source of the message is the interface, the new size is stored
  in FBoundsRealized to avoid sending a size message back to the interface.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMSize(var Message: TLMSize);
var
  NewLeft, NewTop: integer;
  NewBoundsRealized: TRect;
  TopParent: TControl;
  OldClientSize: TSize;
  NewClientSize: TSize;

  procedure RaiseLoop;
  var
    s: String;
  begin
    s:='TWinControl.WMSize loop detected, the widgetset does not like the LCL bounds or sends unneeded wmsize messages: '+DbgSName(Self)+' BoundsRealized='+dbgs(FBoundsRealized)+' NewBoundsRealized='+dbgs(NewBoundsRealized);
    if (OldClientSize.cx<>NewClientSize.cx)
      or (OldClientSize.cy<>NewClientSize.cy)
    then
      s:=s+' OldClientSize='+dbgs(OldClientSize)+' NewClientSize='+dbgs(NewClientSize);
    raise ELayoutException.Create(s);
  end;

begin
  {$IF defined(VerboseSizeMsg) or defined(CHECK_POSITION) or defined(VerboseIntfSizing)}
  {$IFDEF CHECK_POSITION}
  if CheckPosition(Self) then
  {$ENDIF}
   if (Message.SizeType and Size_SourceIsInterface) > 0 then
    DebugLn(['TWinControl.WMSize A ',Name,':',ClassName,' Message=',Message.Width,',',Message.Height,
      ' BoundsRealized=',dbgs(FBoundsRealized),
      ' WChg=',FBoundsRealized.Right-FBoundsRealized.Left<>Message.Width,
      ' HChg=',FBoundsRealized.Bottom-FBoundsRealized.Top<>Message.Height,
      ' FromIntf=',(Message.SizeType and Size_SourceIsInterface)>0,' ClientRectInvalid=',ClientRectNeedsInterfaceUpdate]);
  {$ENDIF}

  NewLeft := Left;
  NewTop := Top;
  if ((Message.SizeType and Size_SourceIsInterface) > 0) then
  begin
    // interface widget has resized
    // -> update realized position and realized bounds
    {$IFDEF VerboseAllAutoSize}
    DebugLn(['TWinControl.WMSize FromIntf ',dbgsname(Self),' Message=',Message.Width,',',Message.Height,
      ' BoundsRealized=',dbgs(FBoundsRealized),
      ' wcfClientRectNeedsUpdate=',wcfClientRectNeedsUpdate in FWinControlFlags]);
    {$ENDIF}
    if not (wcfBoundsRealized in FWinControlFlags) then exit;
    {$IFDEF VerboseClientRectBugFix}
    //if Name=CheckClientRectName then
    DebugLn(['TWinControl.WMSize FromIntf ',dbgsname(Self),' Message=',Message.Width,',',Message.Height,
      ' BoundsRealized=',dbgs(FBoundsRealized),
      ' wcfClientRectNeedsUpdate=',wcfClientRectNeedsUpdate in FWinControlFlags]);
    {$ENDIF}

    //if CheckPosition(Self) then
      //DebugLn(['TWinControl.WMSize GetWindowRelativePosition: ',DbgSName(Self),' ',NewLeft,',',NewTop,' ClientRectNeedsInterfaceUpdate=',ClientRectNeedsInterfaceUpdate]);
    NewBoundsRealized := Bounds(NewLeft, NewTop, Message.Width, Message.Height);
    OldClientSize := Size(0, 0);
    NewClientSize := Size(0, 0);
    if CompareRect(@NewBoundsRealized, @FBoundsRealized) then
    begin
      if not (wcfClientRectNeedsUpdate in FWinControlFlags) then
      begin
        OldClientSize := Size(FClientWidth, FClientHeight);
        NewClientSize := Size(ClientWidth, ClientHeight);
        if (OldClientSize.cx = NewClientSize.cx) and
           (OldClientSize.cy = NewClientSize.cy) then
           Exit;
      end;
    end;
    {$IFDEF VerboseAllAutoSize}
    {$IFDEF CHECK_POSITION}
    if CheckPosition(Self) then
    {$ENDIF}
    DebugLn(['TWinControl.WMSize Changed From Intf ',dbgsname(Self),' Message=',Message.Width,',',Message.Height,
      ' BoundsRealized=',dbgs(FBoundsRealized),
      ' wcfClientRectNeedsUpdate=',wcfClientRectNeedsUpdate in FWinControlFlags,
      ' ClientRectNeedsInterfaceUpdate=',ClientRectNeedsInterfaceUpdate]);
    {$ENDIF}

    TopParent := GetTopParent;
    if (TopParent is TWinControl) and (wcfKillIntfSetBounds in TWinControl(TopParent).FWinControlFlags) then
      RaiseLoop;

    FBoundsRealized := NewBoundsRealized;
    //DebugLn(['TWinControl.WMSize ',DbgSName(Self),' phases=',dbgs(AutoSizePhases)]);
    if ([caspCreatingHandles, caspComputingBounds] * AutoSizePhases <> []) then
    begin
      // while the LCL is creating handles the widgetset may send default bounds
      // we have not yet told the widgetset the final bounds
      // => the InvalidatePreferredSize and the InvalidateClientRectCache
      //    (invoked by the widgetset) may trigger a further loop in the auto
      //    size algorithm to take care of the new bounds
      // => do not call SetBounds, as this will set the Bounds to the widgetset
      //    default values.
      {$IFDEF CHECK_POSITION}
      if CheckPosition(Self) then
      {$ENDIF}
      // DebugLn(['TWinControl.WMSize from intf ignored, because phases=',dbgs(AutoSizePhases),' boundsrealized=',wcfBoundsRealized in FWinControlFlags]);
      Exit;
    end;

    if Assigned(Parent) then
      InvalidatePreferredSize;
  end;

  if Assigned(Parent) and not (Self is TCustomForm) then
    SetBoundsKeepBase(NewLeft, NewTop, Message.Width, Message.Height)
  else
    SetBounds(NewLeft, NewTop, Message.Width, Message.Height);
  //if CheckPosition(Self) then
    //debugln(['TWinControl.WMSize ',DbgSName(Self),' ClientRectNeedsInterfaceUpdate=',ClientRectNeedsInterfaceUpdate]);
  if ((Message.SizeType and Size_SourceIsInterface) > 0) and ((Message.SizeType and SIZE_MINIMIZED) = 0)
  and ClientRectNeedsInterfaceUpdate then
    DoAdjustClientRectChange;
  {$IFDEF VerboseClientRectBugFix}
  {$IFDEF CHECK_POSITION}
  if CheckPosition(Self) then
  {$ENDIF}
  if ((Message.SizeType and Size_SourceIsInterface) > 0) then
  DebugLn(['TWinControl.WMSize END ',dbgsname(Self),' Message=',Message.Width,',',Message.Height,
    ' BoundsRealized=',dbgs(FBoundsRealized),' ClientRect=',dbgs(ClientRect),
    ' ']);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMWindowPosChanged
  Params:   Message: TLMWindowPosChanged
  Returns:  nothing

  Event handler for size/move messages. This is called, whenever left, top,
  width, height, clientwidth or clientheight have changed.
  If the source of the message is the interface, the new size is stored
  in FBoundsRealized to avoid sending a SetBounds back to the interface.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMWindowPosChanged(var Message: TLMWindowPosChanged);
var
  NewLeft, NewTop, NewWidth, NewHeight: integer;
  NewBoundsRealized: TRect;
  TopParent: TControl;

  procedure RaiseLoop;
  begin
    raise ELayoutException.Create('TWinControl.WMWindowPosChanged loop detected: '+DbgSName(Self)+' BoundsRealized='+dbgs(FBoundsRealized)+' NewBoundsRealized='+dbgs(NewBoundsRealized));
  end;

begin
  if not Assigned(Message.WindowPos) or
    ((Message.WindowPos^.flags and SWP_SourceIsInterface) = 0) then
  begin
    inherited WMWindowPosChanged(Message);
    Exit;
  end;

  {$IFDEF VerboseAllAutoSize}
  DebugLn(DbgSName(Self) + ' : ' + DbgSWindowPosFlags(Message.WindowPos^.flags));
  {$ENDIF}

  NewLeft := Message.WindowPos^.x;
  NewTop := Message.WindowPos^.y;
  NewWidth := Message.WindowPos^.cx;
  NewHeight := Message.WindowPos^.cy;

  {$IF defined(VerboseSizeMsg) or defined(CHECK_POSITION) or defined(VerboseIntfSizing)}
  {$IFDEF CHECK_POSITION}
  if CheckPosition(Self) then
  {$ENDIF}
  DebugLn(['TWinControl.WMWindowPosChanged START ',DbgSName(Self),' Message=',NewLeft,',',NewTop,',',NewWidth,'x',NewHeight,
    ' BoundsRealized=',dbgs(FBoundsRealized),' FromIntf=',(Message.WindowPos^.flags and SWP_SourceIsInterface)>0,' ClientRectInvalid=',ClientRectNeedsInterfaceUpdate]);
  {$ENDIF}

  // interface widget has moved/resized
  // -> update realized bounds
  {$IFDEF VerboseAllAutoSize}
  DebugLn(['TWinControl.WMWindowPosChanged FROM INTF ',dbgsname(Self),' Message=',NewLeft,',',NewTop,',',NewWidth,'x',NewHeight,
    ' BoundsRealized=',dbgs(FBoundsRealized),
    ' wcfClientRectNeedsUpdate=',wcfClientRectNeedsUpdate in FWinControlFlags]);
  {$ENDIF}
  //DebugLn('TWinControl.WMSize B ',Name,':',ClassName,' ',NewLeft,',',NewTop);
  NewBoundsRealized := Bounds(NewLeft, NewTop, NewWidth, NewHeight);
  if CompareRect(@NewBoundsRealized,@FBoundsRealized)
  and (not (wcfClientRectNeedsUpdate in FWinControlFlags)) then
    exit;

  {$IFDEF VerboseAllAutoSize}
  DebugLn(['TWinControl.WMWindowPosChanged CHANGED BY INTF ',dbgsname(Self),' Message=',NewLeft,',',NewTop,',',NewWidth,'x',NewHeight,
    ' BoundsRealized=',dbgs(FBoundsRealized),
    ' wcfClientRectNeedsUpdate=',wcfClientRectNeedsUpdate in FWinControlFlags]);
  {$ENDIF}

  TopParent:=GetTopParent;
  if (TopParent is TWinControl)
    and (wcfKillIntfSetBounds in TWinControl(TopParent).FWinControlFlags)
  then
    RaiseLoop;

  FBoundsRealized := NewBoundsRealized;
  //DebugLn(['TWinControl.WMSize ',DbgSName(Self),' phases=',dbgs(AutoSizePhases)]);
  if ([caspCreatingHandles,caspComputingBounds]*AutoSizePhases<>[])
  or (not (wcfBoundsRealized in FWinControlFlags))
  then begin
    // while the LCL is creating handles the widgetset may send default bounds
    // we have not yet told the widgetset the final bounds
    // => the InvalidatePreferredSize and the InvalidateClientRectCache
    //    (invoked by the widgetset) may trigger a further loop in the auto
    //    size algorithm to take care of the new bounds
    // => do not call SetBounds, as this will set the Bounds to the widgetset
    //    default values.
    //DebugLn(['TWinControl.WMSize from intf ignored, because phases=',dbgs(AutoSizePhases),' boundsrealized=',wcfBoundsRealized in FWinControlFlags]);
    exit;
  end;

  if Parent<>nil then
    InvalidatePreferredSize;

  if Parent<>nil then
    SetBoundsKeepBase(NewLeft, NewTop, NewWidth, NewHeight)
  else
    SetBounds(NewLeft, NewTop, NewWidth, NewHeight);
  if ((Message.WindowPos^.flags and SWP_SourceIsInterface) > 0)
  and ClientRectNeedsInterfaceUpdate then
    DoAdjustClientRectChange;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.CNKeyDown
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.CNKeyDown(var Message: TLMKeyDown);
begin
  //DebugLn('TWinControl.CNKeyDown ',Name,':',ClassName);
  if DoKeyDownBeforeInterface(Message, False) then
    Message.Result := 1
  else
    {inherited};  // there is nothing to inherit
end;

{------------------------------------------------------------------------------
  procedure TWinControl.CNSysKeyDown(var Message: TLMKeyDown);
 ------------------------------------------------------------------------------}
procedure TWinControl.CNSysKeyDown(var Message: TLMKeyDown);
begin
  if DoKeyDownBeforeInterface(Message, False) then
    Message.Result := 1
  else
    {inherited};  // there is nothing to inherit
end;

{------------------------------------------------------------------------------
  procedure TWinControl.CNSysKeyUp(var Message: TLMKeyUp);
 ------------------------------------------------------------------------------}
procedure TWinControl.CNSysKeyUp(var Message: TLMKeyUp);
begin
  if DoKeyUpBeforeInterface(Message) then 
    Message.Result := 1
  else
    {inherited}; // there is nothing to inherit
end;

{------------------------------------------------------------------------------
  Method: TWinControl.CNKeyUp
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.CNKeyUp(var Message: TLMKeyUp);
begin
  if DoKeyUpBeforeInterface(Message) then 
    Message.Result := 1
  else
    {inherited}; // there is nothing to inherit
end;

{------------------------------------------------------------------------------
  Method: TWinControl.CNChar
  Params:   Msg: The message
  Returns:  nothing

  event handler.
  CNChar is sent by the interface before it has handled the keypress itself.
 ------------------------------------------------------------------------------}
procedure TWinControl.CNChar(var Message: TLMKeyUp);
var
  c: TUTF8Char;
begin
  //debugln('TWinControl.CNChar B ',DbgSName(Self),' ',dbgs(Message.CharCode));
  if Widgetset.GetLCLCapability(lcSendsUTF8KeyPress) = LCL_CAPABILITY_NO then
  begin
    // current interface does not (yet) send UTF8 key press notifications -> emulate
    if (Message.CharCode < %11000000) then
    begin
      c:=chr(Message.CharCode);
      IntfUTF8KeyPress(c,1,false);
      if (length(c)<>1) or (c[1]<>chr(Message.CharCode)) then
      begin
        // character changed
        if length(c)=1 then
          Message.CharCode:=ord(c[1])
        else
          Message.CharCode:=0;
      end;
    end;
    if Message.CharCode=0 then 
    begin
      Message.Result := 1;
      exit;
    end;
  end;

  {$ifdef VerboseKeyboard}
    debugln('TWinControl.CNChar A ',DbgSName(Self),' ',dbgs(Message.CharCode));
  {$endif}

  if DoKeyPress(Message) then
    Message.Result := 1
  else
    {inherited}; // there is nothing to inherit
end;

procedure TWinControl.WMSysChar(var Message: TLMKeyUp);
begin
  if SendDialogChar(Message) then 
    Message.Result := 1
  else
    {inherited}; // there is nothing to inherit
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMNofity
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMNotify(var Message: TLMNotify);
begin
  if not DoControlMsg(Message.NMHdr^.hwndfrom, Message) then
    inherited;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMShowWindow
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMShowWindow(var Message: TLMShowWindow);
begin
  // DebugLn(['TWinControl.LMShowWindow ', dbgsName(self)]);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMEnter
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMEnter(var Message: TLMEnter);
begin
  //DebugLn(Format('Trace: TODO: [TWinControl.LMEnter] %s', [ClassName]));
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMEraseBkgnd
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMEraseBkgnd(var Message: TLMEraseBkgnd);
begin
  if (Message.DC <> 0) and (wcfEraseBackground in FWinControlFlags) then
  begin
    EraseBackground(Message.DC);
    Message.Result := 1;
  end;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMExit
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMExit(var Message: TLMExit);
begin
  //DebugLn(Format('Trace: TODO: [TWinControl.LMExit] %s', [ClassName]));
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMChar
  Params:   Msg: The message
  Returns:  nothing

  event handler.
  WMChar is sent by the interface after it has handled the keypress by itself.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMChar(var Message: TLMChar);
begin
  //debugln('TWinControl.WMChar ',DbgSName(Self),' ',dbgs(Message.CharCode));
  if SendDialogChar(Message) then
    Message.Result := 1;
  //DebugLn(Format('Trace:[TWinControl.WMChar] %s', [ClassName]));
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMKeyDown
  Params:   Msg: The message
  Returns:  nothing

  Event handler for keys not handled by the interface
 ------------------------------------------------------------------------------}
procedure TWinControl.WMKeyDown(var Message: TLMKeyDown);
begin
  if DoRemainingKeyDown(Message) then
    Message.Result := 1;
end;

procedure TWinControl.WMSysKeyDown(var Message: TLMKeyDown);
begin
  if DoRemainingKeyDown(Message) then
    Message.Result := 1;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.WMSysKeyUp(var Message: TLMKeyUp);
 ------------------------------------------------------------------------------}
procedure TWinControl.WMSysKeyUp(var Message: TLMKeyUp);
begin
  //debugln('TWinControl.WMSysKeyUp ',DbgSName(Self));
  if DoRemainingKeyUp(Message) then
    Message.Result := 1;
end;

{------------------------------------------------------------------------------
  Method: TWinControl.WMKeyUp
  Params:   Msg: The message
  Returns:  nothing

  event handler.
 ------------------------------------------------------------------------------}
procedure TWinControl.WMKeyUp(var Message: TLMKeyUp);
begin
  //debugln('TWinControl.WMKeyUp ',DbgSName(Self));
  if DoRemainingKeyUp(Message) then
    Message.Result := 1;
end;

{------------------------------------------------------------------------------
  function: TWinControl.HandleAllocated
  Params:   None
  Returns:  True is handle is allocated

  Checks if a handle is allocated. I.E. if the control is mapped
 ------------------------------------------------------------------------------}
function TWinControl.HandleAllocated : Boolean;
begin
  HandleAllocated := (FHandle <> 0);
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.CreateHandle
  Params:  None
  Returns: Nothing

  Creates the handle ( = object) if not already done.
 ------------------------------------------------------------------------------}
procedure TWinControl.CreateHandle;
begin
  if (not HandleAllocated) then CreateWnd;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.CreateWnd
  Params:  None
  Returns: Nothing

  Creates the interface object and assigns the handle
 ------------------------------------------------------------------------------}
procedure TWinControl.CreateWnd;
var
  Params: TCreateParams;
  i: Integer;
  AWinControl: TWinControl;

{  procedure WriteClientRect(const Prefix: string);
  var r: TRect;
  begin
    LCLIntf.GetClientRect(Handle,r);
    if csDesigning in ComponentState then
      DebugLn('WriteClientRect ',Prefix,' ',Name,':',ClassName,' r=',r.Right,',',r.Bottom);
  end;}

begin
  //DebugLn('[TWinControl.CreateWnd] START ',DbgSName(Self));
  if (csDestroying in ComponentState) or Assigned(Parent) and (csDestroying in Parent.ComponentState) then
  begin
    DebugLn('[TWinControl.CreateWnd] NOTE: csDestroying ',DbgSName(Self));
    RaiseGDBException('');
    exit;
  end;

  if wcfInitializing in FWinControlFlags then
  begin
    DebugLn('[WARNING] Recursive call to CreateWnd for ',DbgSName(Self), ' while initializing');
    RaiseGDBException('');
    Exit;
  end;

  if wcfCreatingHandle in FWinControlFlags then
  begin
    DebugLn('[WARNING] Recursive call to CreateWnd for ',DbgSName(Self), ' while creating handle');
    RaiseGDBException('');
    Exit;
  end;

  if wcfCreatingChildHandles in FWinControlFlags then
  begin
    DebugLn('[WARNING] Recursive call to CreateWnd for ',DbgSName(Self), ' while creating children');
    RaiseGDBException('');
    Exit;
  end;
  
  if [csLoading,csDesigning]*ComponentState=[csLoading] then
  begin
    DebugLn('[HINT] TWinControl.CreateWnd creating Handle during loading ',DbgSName(Self),' csDesigning=',dbgs(csDesigning in ComponentState));
    //DumpStack;
    //RaiseGDBException('');
  end;

  FBoundsRealized := Rect(0,0,0,0);
  Exclude(FWinControlFlags, wcfBoundsRealized);

  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.CreateWnd'){$ENDIF};
  try
    if Assigned(Parent) and not Parent.HandleAllocated then
    begin
      // first create the parent handle
      Parent.HandleNeeded;
      if HandleAllocated then exit;
      DebugLn(['WARNING: TWinControl.CreateWnd: parent created handles, but not ours']);
    end;
    // Control is not visible at this moment. It will be shown in UpdateShowing
    FShowing := False;
    Exclude(FWinControlFlags, wcfHandleVisible);

    Include(FWinControlFlags, wcfCreatingHandle);
    try
      CreateParams(Params);
      with Params do
      begin
        if (WndParent = 0) and (Style and WS_CHILD <> 0) then
        begin
          DebugLn(['TWinControl.CreateWnd ',DbgSName(Self),' Parent=',DbgSName(Parent),' ERROR WndParent=0']);
          raise EInvalidOperation.CreateFmt(rsControlHasNoParentWindow, [Name]);
        end;
      end;

      //DebugLn(['TWinControl.CreateWnd Creating handle ... ',DbgSName(WidgetSetClass),' ',DbgSName(Self)]);
      FHandle := TWSWinControlClass(WidgetSetClass).CreateHandle(Self, Params);
      if not HandleAllocated then
      begin
        if WidgetSet.LCLPlatform=lpNoGUI then
          RaiseGDBException('TWinControl.CreateWnd: The nogui widgetset does not support visual controls.')
        else
          RaiseGDBException('TWinControl.CreateWnd: Handle creation failed creating '+DbgSName(Self));
      end;
      //debugln('TWinControl.CreateWnd update constraints ... ',DbgSName(Self));
      TWSWinControlClass(WidgetSetClass).SetBiDiMode(Self,
         UseRightToLeftAlignment, UseRightToLeftReading, UseRightToLeftScrollBar);

      Constraints.UpdateInterfaceConstraints;
      InvalidateClientRectCache(False);
      TWSWinControlClass(WidgetSetClass).ConstraintsChange(Self);

      //WriteClientRect('A');
      if Assigned(Parent) and (Params.Style and WS_POPUP = 0) then
        AddControl
      else
      if ParentWindow <> 0 then
        LCLIntf.SetParent(FHandle, ParentWindow);
      //WriteClientRect('B');

      Include(FWinControlFlags, wcfInitializing);
      //DebugLn(['TWinControl.CreateWnd initializing window ...']);
      InitializeWnd;

    finally
      Exclude(FWinControlFlags, wcfInitializing);
      Exclude(FWinControlFlags, wcfCreatingHandle);
    end;

    Include(FWinControlFlags, wcfCreatingChildHandles);
    try
      //DebugLn('[TWinControl.CreateWnd] ',Name,':',ClassName,' ',Left,',',Top,',',Width,',',Height);
      //WriteClientRect('C');

      if FControls <> nil then
      begin
        for i := 0 to FControls.Count - 1 do
        begin
          AWinControl := TWinControl(FControls.Items[i]);
          //DebugLn(['TWinControl.CreateWnd create child handles self=',DbgSName(Self),' Child=',DbgSName(AWinControl)]);
          if (AWinControl is TWinControl) and AWinControl.IsControlVisible then
            AWinControl.HandleNeeded;
        end;
      end;

      ChildHandlesCreated;
    finally
      Exclude(FWinControlFlags, wcfCreatingChildHandles);
    end;

    InvalidatePreferredSize;
    if Assigned(FControls) then
      for i := 0 to FControls.Count - 1 do
        TControl(FControls[i]).InvalidatePreferredSize;
    // size this control
    AdjustSize;
  finally
    //DebugLn(['TWinControl.CreateWnd created ',DbgSName(Self),' enable autosizing ...']);
    (* If an error occurred and FHandle was not created,
       then EnableAutoSizing must not be called.
       EnableAutoSizing will need the Handle, and trigger another attempt to create it.
       This leads to an endless loop/recursion.
       As a side effect the current control will be left in autosize-disabled *)
    if FHandle <> 0 then
      EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.CreateWnd'){$ENDIF};
  end;

  //DebugLn('[TWinControl.CreateWnd] END ',Name,':',Classname);
  //WriteClientRect('D');
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.InitializeWnd
  Params:  none
  Returns: Nothing

  Gets called after the window is created, but before the child controls are
  created. Place cached property code here.
 ------------------------------------------------------------------------------}
procedure TWinControl.InitializeWnd;
var
  CachedText: string;
begin
  //DebugLn(Format('Trace:[TWinControl.InitializeWnd]  %s', [ClassName]));
  // set all cached properties

  //DebugLn('[TWinControl.InitializeWnd] ',Name,':',ClassName,':', FCaption,' ',dbgs(Left),',',dbgs(Top),',',dbgs(Width),',',dbgs(Height));

  // First set the WinControl property some interfaces depends on it
  SetProp(Handle,'WinControl',TWinControl(Self));
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.InitializeWnd'){$ENDIF};
  try
    {$IFDEF CHECK_POSITION}
    if CheckPosition(Self) then
      DebugLn('[TWinControl.InitializeWnd] A ',DbgSName(Self),
      ' OldRelBounds=',dbgs(FBoundsRealized),
      ' -> NewBounds=',dbgs(BoundsRect));
    {$ENDIF}

    if wcfColorChanged in FWinControlFlags then
    begin
      // replace by update style call
      TWSWinControlClass(WidgetSetClass).SetColor(Self);
      Exclude(FWinControlFlags, wcfColorChanged);
    end;
    if wcfFontChanged in FWinControlFlags then
    begin
      // replace by update style call
      TWSWinControlClass(WidgetSetClass).SetFont(Self,Font);
      Exclude(FWinControlFlags, wcfFontChanged);
    end;

    if not (csDesigning in ComponentState) then
      EnableWindow(Handle, Enabled);

    // Delay the setting of text until it is completely loaded
    if not (csLoading in ComponentState) then
    begin
      if GetCachedText(CachedText) then
        WSSetText(CachedText);
      InvalidatePreferredSize;
    end;

    if csDesigning in ComponentState then
      TWSWinControlClass(WidgetSetClass).SetCursor(Self, Screen.Cursors[crDefault])
    else
      TWSWinControlClass(WidgetSetClass).SetCursor(Self, Screen.Cursors[Cursor]);
  finally
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.InitializeWnd'){$ENDIF};
  end;
  // send pending OnResize
  {$IFDEF VerboseOnResize}
  debugln(['TWinControl.InitializeWnd ',DbgSName(Self),' calling Resize ...']);
  {$ENDIF}
  Resize;
end;

procedure TWinControl.FinalizeWnd;
var
  S: string;
begin
  if not HandleAllocated then
    RaiseGDBException('TWinControl.FinalizeWnd Handle already destroyed');
  // make sure our text is saved
  if TWSWinControlClass(WidgetSetClass).GetText(Self, S) then
    FCaption := S;
  // if color has changed make sure it will be restored
  if FColor <> {$ifdef UseCLDefault}clDefault{$else}clWindow{$endif} then
    Include(FWinControlFlags,wcfColorChanged);
  RemoveProp(Handle,'WinControl');
  FAdjustClientRectRealized := Rect(0,0,0,0);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.ParentFormHandleInitialized;

  Called after all children handles of the ParentForm are created.
 ------------------------------------------------------------------------------}
procedure TWinControl.ParentFormHandleInitialized;
var
  i: Integer;
begin
  inherited ParentFormHandleInitialized;
  // tell all controls about the final end of the handle creation phase
  if FControls<>nil then begin
    for i:=0 to FControls.Count-1 do
      TControl(FControls[i]).ParentFormHandleInitialized;
  end;
  //debugln('TWinControl.ParentFormHandleInitialized A ',DbgSName(Self));
end;

{------------------------------------------------------------------------------
  procedure TWinControl.ChildHandlesCreated;
  
  Called after all children handles are created.
 ------------------------------------------------------------------------------}
procedure TWinControl.ChildHandlesCreated;
begin
  Exclude(FWinControlFlags,wcfCreatingChildHandles);
end;

function TWinControl.GetMouseCapture: Boolean;
begin
  Result:=HandleAllocated and (GetCaptureControl=Self);
end;

function TWinControl.GetParentBackground: Boolean;
begin
  Result := csParentBackground in ControlStyle;
end;

{------------------------------------------------------------------------------
  function TWinControl.ParentHandlesAllocated: boolean;
  
  Checks if all Handles of all Parents are created.
 ------------------------------------------------------------------------------}
function TWinControl.ParentHandlesAllocated: boolean;
var
  CurControl: TWinControl;
begin
  Result:=false;
  CurControl:=Self;
  while CurControl<>nil do begin
    if (not CurControl.HandleAllocated)
    or (csDestroying in CurControl.ComponentState)
    or (csDestroyingHandle in CurControl.ControlState) then
      exit;
    CurControl:=CurControl.Parent;
  end;
  Result:=true;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.Loaded;
 ------------------------------------------------------------------------------}
procedure TWinControl.Loaded;
var
  CachedText: string;
  i: Integer;
  AChild: TControl;
  LoadedClientSize: TSize;
  CurControl: TWinControl;
begin
  //DebugLn(['TWinControl.Loaded START ',DbgSName(Self),' cfWidthLoaded=',cfWidthLoaded in FControlFlags,' cfHeightLoaded=',cfHeightLoaded in FControlFlags,' ']);
  DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.Loaded'){$ENDIF};
  try
    //DebugLn(['TWinControl.Loaded ',DbgSName(Self),' cfWidthLoaded=',cfWidthLoaded in FControlFlags,' cfHeightLoaded=',cfHeightLoaded in FControlFlags,' ']);
    if cfClientWidthLoaded in FControlFlags then
      LoadedClientSize.cx:=FLoadedClientSize.cx
    else begin
      CurControl:=Self;
      while CurControl<>nil do begin
        LoadedClientSize.cx:=CurControl.ClientWidth;
        if LoadedClientSize.cx>0 then break;
        LoadedClientSize.cx:=CurControl.Width;
        if LoadedClientSize.cx>0 then break;
        CurControl:=CurControl.Parent;
      end;
    end;
    if cfClientHeightLoaded in FControlFlags then
      LoadedClientSize.cy:=FLoadedClientSize.cy
    else begin
      CurControl:=Self;
      while CurControl<>nil do begin
        LoadedClientSize.cy:=CurControl.ClientHeight;
        if LoadedClientSize.cy>0 then break;
        LoadedClientSize.cy:=CurControl.Height;
        if LoadedClientSize.cy>0 then break;
        CurControl:=CurControl.Parent;
      end;
    end;
    for i:=0 to ControlCount-1 do begin
      AChild:=Controls[i];
      if AChild=nil then ;
      AChild.FBaseParentClientSize:=LoadedClientSize;
      //DebugLn(['TWinControl.Loaded Self=',DbgSName(Self),' AChild=',AChild,' AChild.FBaseParentClientSize=',dbgs(AChild.FBaseParentClientSize)]);
    end;
    if HandleAllocated then
    begin
      // Set cached caption
      if GetCachedText(CachedText) then
        WSSetText(CachedText);
      InvalidatePreferredSize;

      if wcfColorChanged in FWinControlFlags then
      begin
        TWSWinControlClass(WidgetSetClass).SetColor(Self);
        NotifyControls(CM_PARENTCOLORCHANGED);
        Exclude(FWinControlFlags, wcfColorChanged);
      end;
      if wcfFontChanged in FWinControlFlags then
      begin
        TWSWinControlClass(WidgetSetClass).SetFont(Self,Font);
        NotifyControls(CM_PARENTFONTCHANGED);
        FWinControlFlags:=FWinControlFlags-[wcfFontChanged];
      end;
    end;

    inherited Loaded;

    FixupTabList;

  finally
    //DebugLn(['TWinControl.Loaded enableautosizing ',DbgSName(Self),' ',dbgs(BoundsRect)]);
    EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.Loaded'){$ENDIF};
    //DebugLn(['TWinControl.Loaded END ',DbgSName(Self),' ',dbgs(BoundsRect)]);
  end;
end;

procedure TWinControl.FormEndUpdated;
var
  i: Integer;
begin
  inherited FormEndUpdated;
  for i:=0 to ControlCount-1 do
    Controls[i].FormEndUpdated;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.DestroyWnd
  Params:  None
  Returns: Nothing

  Destroys the interface object.
 ------------------------------------------------------------------------------}
procedure TWinControl.DestroyWnd;
var
  i: integer;
begin
  if HandleAllocated then
  begin
    //DebugLn(['TWinControl.DestroyWnd ',DbgSName(Self)]);
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DestroyWnd'){$ENDIF};
    try
      FinalizeWnd;

      if FControls <> nil then
        for i := 0 to FControls.Count - 1 do
          TControl(FControls[i]).DoOnParentHandleDestruction;

      TWSWinControlClass(WidgetSetClass).DestroyHandle(Self);
      Handle := 0;
      Exclude(FWinControlFlags,wcfBoundsRealized);
      // Maybe handle is not needed at moment but later it will be created once
      // again. To propely initialize control after we need to restore color
      // and font. Request update.
      FWinControlFlags := FWinControlFlags + [wcfColorChanged, wcfFontChanged];
      if (CaptureControl=Self) then
        SetCaptureControl(nil);
    finally
      EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.DestroyWnd'){$ENDIF};
    end;
  end;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.HandleNeeded
  Params:  None
  Returns: Nothing

  Description of the procedure for the class.
 ------------------------------------------------------------------------------}
procedure TWinControl.HandleNeeded;
begin
  if (not HandleAllocated) and (not (csDestroying in ComponentState)) then
  begin
    if Parent = Self
    then begin
      //DebugLn(Format('Trace:[TWinControl.HandleNeeded] Somebody set Parent := Self in %s. DONT DO THAT !!', [Classname]));
    end
    else begin
      if (Parent <> nil) then
      begin
        Parent.HandleNeeded;
        // has parent triggered us to create our handle ?
        if HandleAllocated then
          exit;
      end;
    end;
    CreateHandle;
  end;
end;

function TWinControl.BrushCreated: Boolean;
begin
  Result := Assigned(FBrush);
end;

{------------------------------------------------------------------------------
  Method: TWinControl.BeginUpdateBounds
  Params:  None
  Returns: Nothing

  increases the BoundsLockCount
 ------------------------------------------------------------------------------}
procedure TWinControl.BeginUpdateBounds;
begin
  inc(FBoundsLockCount);
end;

procedure TWinControl.InvalidateBoundsRealized;
begin
  FBoundsRealized := Rect(0, 0, 0, 0);
end;

{------------------------------------------------------------------------------
  Method: TControl.EndUpdateBounds
  Params:  None
  Returns: Nothing

  decreases the BoundsLockCount
 ------------------------------------------------------------------------------}
procedure TWinControl.EndUpdateBounds;
begin
  if FBoundsLockCount <= 0 then
    raise ELayoutException.CreateFmt('TWinControl.EndUpdateBounds %s too many calls.',
                                     [DbgSName(Self)]);
  dec(FBoundsLockCount);
  if FBoundsLockCount = 0 then
    SetBounds(Left, Top, Width, Height);
end;

procedure TWinControl.LockRealizeBounds;
begin
  inc(FRealizeBoundsLockCount);
end;

procedure TWinControl.UnlockRealizeBounds;
begin
  if FRealizeBoundsLockCount<=0 then
    RaiseGDBException('UnlockRealizeBounds');
  dec(FRealizeBoundsLockCount);
  if (FRealizeBoundsLockCount=0)
  and (not AutoSizeDelayed) and (caspRealizingBounds in AutoSizePhases)
  then
    RealizeBounds;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.DockDrop(DockObject: TDragDockObject; X, Y: Integer);
  
  Docks the DockObject.Control onto this control.
  X, Y are only default values. More important is the DockObject.DropAlign
  property, which defines how to align DockObject.Control.
 ------------------------------------------------------------------------------}
procedure TWinControl.DockDrop(DragDockObject: TDragDockObject; X, Y: Integer);
begin
  if DoDockClientMsg(DragDockObject, Point(X, Y)) and Assigned(FOnDockDrop) then
    FOnDockDrop(Self, DragDockObject, X, Y);
end;

{------------------------------------------------------------------------------
  Method: TControl.GetIsResizing
  Params:  None
  Returns: Nothing

  decreases the BoundsLockCount
 ------------------------------------------------------------------------------}
function TWinControl.GetIsResizing: boolean;
begin
  Result:=BoundsLockCount>0;
end;

function TWinControl.GetIsSpecialSubControl: Boolean;
begin
  Result := wcfSpecialSubControl in FWinControlFlags;
end;

function TWinControl.GetTabOrder: TTabOrder;
begin
  if FParent <> nil then
    Result := ListIndexOf(FParent.FTabList,Self)
  else
    Result := FTabOrder;
end;

function TWinControl.GetVisibleDockClientCount: Integer;
var
  i: integer;
begin
  Result := 0;
  if FDockClients=nil then exit;
  for i:=FDockClients.Count-1 downto 0 do
    if TControl(FDockClients[I]).Visible then inc(Result);
end;

procedure TWinControl.SetChildSizing(const AValue: TControlChildSizing);
begin
  if (FChildSizing=AValue) then exit;
  FChildSizing.Assign(AValue);
end;

procedure TWinControl.SetDesignerDeleting(AValue: Boolean);
begin
  if AValue then
    Include(FWinControlFlags, wcfDesignerDeleting)
  else
    Exclude(FWinControlFlags, wcfDesignerDeleting);
end;

{------------------------------------------------------------------------------
  procedure TWinControl.SetDockSite(const NewDockSite: Boolean);
  
  If NewDockSite=true it means, this control can dock other controls.
 ------------------------------------------------------------------------------}
procedure TWinControl.SetDockSite(const NewDockSite: Boolean);
begin
  if FDockSite=NewDockSite then exit;
  FDockSite := NewDockSite;
  if not (csDesigning in ComponentState) then begin
    DragManager.RegisterDockSite(Self,NewDockSite);
    if not NewDockSite then begin
      FreeAndNil(FDockClients);
      FDockClients := nil;
      DockManager := nil;
    end
    else begin
      if FDockClients = nil then FDockClients := TFPList.Create;
      DockManager := CreateDockManager;
    end;
  end;
end;

procedure TWinControl.SetDoubleBuffered(Value: Boolean);
var
  AChanged: Boolean;
begin
  AChanged := FDoubleBuffered <> Value;
  FDoubleBuffered := Value;
  FParentDoubleBuffered := False;
  if AChanged then
    Perform(CM_DOUBLEBUFFEREDCHANGED, 0, 0);
end;

function TWinControl.DoDockClientMsg(DragDockObject: TDragDockObject;
  aPosition: TPoint): boolean;
var
  DestRect: TRect;
  Form: TCustomForm;
begin
  with DragDockObject do begin
    DestRect := DockRect;
    DisableAlign;
    try
      {$IFDEF VerboseDocking}
      Debugln(['TWinControl.DoDockClientMsg ',DbgSName(Self),' Control=',DbgSName(DragDockObject.Control),' DestRect=',dbgs(DestRect)]);
      {$ENDIF}
      DragDockObject.Control.Dock(Self, DestRect);
      if FUseDockManager and (DockManager <> nil) then
        DockManager.InsertControl(DragDockObject);
    finally
      EnableAlign;
    end;
    Form := GetParentForm(Self);
    if Form <> nil then Form.BringToFront;
    Result := true;
  end;
end;

function TWinControl.DoUndockClientMsg(NewTarget, Client: TControl): boolean;
begin
  Result := True;
  {$IFDEF VerboseDocking}
  DebugLn(['TWinControl.DoUnDockClientMsg ',DbgSName(Self),' Client=',DbgSName(Client),' Client.Parent=',DbgSName(Client.Parent)]);
  {$ENDIF}
  if FUseDockManager and (DockManager <> nil) then
    DockManager.RemoveControl(Client);
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.SetBounds
  Params:  aLeft, aTop, aWidth, aHeight
  Returns: Nothing

  Sets the bounds of the control.
 ------------------------------------------------------------------------------}
procedure TWinControl.SetBounds(ALeft, ATop, AWidth, AHeight: integer);

  procedure CheckDesignBounds;
  begin
    if FRealizeBoundsLockCount > 0 then Exit;
    // the user changed the bounds
    if AWidth < 0 then
      raise ELayoutException.CreateFmt('TWinControl.SetBounds (%s): Negative width %d not allowed.',
                                       [DbgSName(Self), AWidth]);
    if AHeight < 0 then
      raise ELayoutException.CreateFmt('TWinControl.SetBounds (%s): Negative height %d not allowed.',
                                       [DbgSName(Self), AHeight]);
  end;

var
  NewBounds, OldBounds: TRect;
begin
  {$IFDEF CHECK_POSITION}
  //if csDesigning in ComponentState then
  if CheckPosition(Self) then
  DebugLn(['[TWinControl.SetBounds] START ',DbgSName(Self),
  ' Old=',dbgs(Bounds(Left,Top,Width,Height)),
  ' -> New=',dbgs(Bounds(ALeft,ATop,AWidth,AHeight)),
  ' Lock=',BoundsLockCount,
  ' Realized=',dbgs(FBoundsRealized)
  ]);
  {$ENDIF}
  if BoundsLockCount <> 0 then
    Exit;
  OldBounds := BoundsRect;
  NewBounds := Bounds(ALeft, ATop, AWidth, AHeight);

  if not CompareRect(@NewBounds, @OldBounds) then
  begin
    if [csDesigning,csDestroying,csLoading]*ComponentState=[csDesigning] then
      CheckDesignBounds;
    // LCL bounds are not up2date -> process new bounds
    DisableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.SetBounds'){$ENDIF};
    try
      {$IFDEF CHECK_POSITION}
      //if csDesigning in ComponentState then
      if CheckPosition(Self) then
      DebugLn(['[TWinControl.SetBounds] Set LCL Bounds ',DbgSName(Self),
      ' OldBounds=',Dbgs(Bounds(Left,Top,Width,Height)),
      ' -> New=',Dbgs(Bounds(ALeft,ATop,AWidth,AHeight))]);
      {$ENDIF}
      inherited SetBounds(ALeft, ATop, AWidth, AHeight);
      //DebugLn(['TWinControl.SetBounds ',DbgSName(Self),' FUseDockManager=',FUseDockManager,' ',DbgSName(DockManager)]);
    finally
      EnableAutoSizing{$IFDEF DebugDisableAutoSizing}('TWinControl.SetBounds'){$ENDIF};
    end;
  end;
end;

{------------------------------------------------------------------------------
  procedure TWinControl.CalculatePreferredSize(var PreferredWidth,
    PreferredHeight: integer; WithThemeSpace" Boolean);
    
  Calculates the default/preferred width and height for a TWinControl, which is
  used by the LCL autosizing algorithms as default size. Only positive values
  are valid. Negative or 0 are treated as undefined and the LCL uses other sizes
  instead (exception: csAutoSize0x0).
  TWinControl overrides this:
  If there are children, their total preferred size is calculated.
  If this value can not be computed (e.g. the children depend too much on their
  parent clientrect), then the interface is asked for the preferred size.
  For example the preferred size of a TButton is the size, where the label fits
  exactly. This depends heavily on the current theme and widgetset.
  
  This value is independent of constraints and siblings, only the inner parts
  are relevant.

  WithThemeSpace: If true, adds space for stacking. For example: TRadioButton
  has a minimum size. But for stacking multiple TRadioButtons there should be
  some space around. This space is theme dependent, so it passed parameter to
  the widgetset.
 ------------------------------------------------------------------------------}
procedure TWinControl.CalculatePreferredSize(var PreferredWidth,
  PreferredHeight: integer; WithThemeSpace: Boolean);

  {$IFDEF VerboseCalculatePreferredSize}
  procedure trav(aControl: TControl; Prefix: string);
  var
    w: integer;
    h: integer;
    i: Integer;
  begin
    if not aControl.IsVisible then exit;
    if aControl<>Self then begin
      aControl.GetPreferredSize(w,h,true,true);
      debugln([Prefix,'Child ',DbgSName(aControl),' ',dbgs(aControl.BoundsRect),' Pref=',w,'x',h]);
    end;
    if aControl is TWinControl then
      for i:=0 to TWinControl(aControl).ControlCount-1 do
        trav(TWinControl(aControl).Controls[i],Prefix+'  ');
  end;

  function IsVerbose: boolean;
  begin
    Result:=(Name='MainScrollBox');
  end;
  {$ENDIF}

var
  Layout: TAutoSizeCtrlData;
  NewClientWidth: Integer;
  NewClientHeight: Integer;
  NewMoveLeft, NewMoveRight: integer;
  FrameWidth: integer;
  FrameHeight: integer;
begin
  inherited CalculatePreferredSize(PreferredWidth,PreferredHeight,WithThemeSpace);
  
  if HandleAllocated then begin
    TWSWinControlClass(WidgetSetClass).GetPreferredSize(Self,
                               PreferredWidth, PreferredHeight, WithThemeSpace);
    {$IFDEF VerboseCalculatePreferredSize}
    if IsVerbose then debugln(['TWinControl.CalculatePreferredSize Widget ',DbgSName(Self),' ',DbgSName(WidgetSetClass),' Pref=',PreferredWidth,'x',PreferredHeight]);
    {$ENDIF}
  end;

  if ControlCount>0 then begin
    // Beware: ControlCount>0 does not mean that there are visible children

    // get the size requirements for the child controls
    Layout:=nil;
    try
      Layout:=TAutoSizeCtrlData.Create(Self);
      Layout.ComputePreferredClientArea(false,false,NewMoveLeft,NewMoveRight,
                                        NewClientWidth,NewClientHeight);
      //if (Name='OtherInfoGroupBox') or (Name='ProjectVersionInfoOptionsFrame') then
      //  debugln(['TWinControl.CalculatePreferredSize NewClientWidth=',NewClientWidth,' NewClientHeight=',NewClientHeight]);
      if (NewMoveLeft<>0) or (NewMoveRight<>0) then ;
    finally
      Layout.Free;
    end;

    // add clientarea frame
    GetPreferredSizeClientFrame(FrameWidth,FrameHeight);

    {$IF defined(VerboseAutoSize) or defined(VerboseAllAutoSize) or defined(VerboseCalculatePreferredSize)}
    {$IFDEF VerboseCalculatePreferredSize}
    if IsVerbose then
      trav(Self,'  ');
    if IsVerbose then
    {$ENDIF}
    //if (Name='OtherInfoGroupBox') or (Name='ProjectVersionInfoOptionsFrame') then
    debugln(['TWinControl.CalculatePreferredSize ',DbgSName(Self),
      ' HandleAllocated=',HandleAllocated,
      ' Cur=',Width,'x',Height,
      ' Client=',ClientWidth,'x',ClientHeight,
      ' PrefClient=',NewClientWidth,'x',NewClientHeight]);
    {$ENDIF}
    if NewClientWidth>0 then
      PreferredWidth:=Max(PreferredWidth,NewClientWidth+FrameWidth);
    if NewClientHeight>0 then
      PreferredHeight:=Max(PreferredHeight,NewClientHeight+FrameHeight);
  end;

  // add borderspacing
  if (PreferredWidth>0)
  or ((PreferredWidth=0) and (csAutoSize0x0 in ControlStyle)) then
    inc(PreferredWidth,BorderSpacing.InnerBorder*2);
  if (PreferredHeight>0)
  or ((PreferredHeight=0) and (csAutoSize0x0 in ControlStyle)) then
    inc(PreferredHeight,BorderSpacing.InnerBorder*2);
  {$IF defined(VerboseAutoSize) or defined(VerboseCalculatePreferredSize)}
  {$IFDEF VerboseCalculatePreferredSize}
  if IsVerbose then
  {$ENDIF}
  debugln(['TWinControl.CalculatePreferredSize ',DbgSName(Self),
    ' HandleAllocated=',dbgs(HandleAllocated),
    ' ClientFrame=',FrameWidth,'x',FrameHeight,
    ' Preferred=',dbgs(PreferredWidth),'x',dbgs(PreferredHeight)]);
  {$ENDIF}
end;

procedure TWinControl.GetPreferredSizeClientFrame(out aWidth, aHeight: integer);
begin
  aWidth:=Width-ClientWidth;
  aHeight:=Height-ClientHeight;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.RealGetText
  Params:  None
  Returns: The text

  Gets the text/caption of a control
 ------------------------------------------------------------------------------}
function TWinControl.RealGetText: TCaption;
begin
  Result := '';
  {$IFDEF VerboseTWinControlRealText}
  DebugLn(['TWinControl.RealGetText ',DbgSName(Self),' HandleAllocated=',HandleAllocated,' csLoading=',csLoading in ComponentState,' ']);
  if not HandleAllocated
  or (csLoading in ComponentState) then begin
    DebugLn(['TWinControl.RealGetText using inherited RealGetText']);
    Result := inherited RealGetText;
  end else begin
    DebugLn(['TWinControl.RealGetText using ',DbgSName(WidgetSetClass),' GetText']);
    if (not TWSWinControlClass(WidgetSetClass).GetText(Self, Result)) then begin
      DebugLn(['TWinControl.RealGetText FAILED, using RealGetText']);
      Result := inherited RealGetText;
    end;
  end;
  DebugLn(['TWinControl.RealGetText Result="',Result,'"']);
  {$ELSE}
  if not HandleAllocated 
  or (csLoading in ComponentState) 
  or (not TWSWinControlClass(WidgetSetClass).GetText(Self, Result))
  then Result := inherited RealGetText;
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.GetTextLen
  Params:  None
  Returns: The length of the text

  Gets the length of the text/caption of a control
 ------------------------------------------------------------------------------}
function TWinControl.GetTextLen: Integer;
begin
  Result := 0;
  if not HandleAllocated 
  or (csLoading in ComponentState) 
  or not TWSWinControlClass(WidgetSetClass).GetTextLen(Self, Result)
  then Result := inherited GetTextLen;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.RealSetText
  Params:  Value: the text to be set
  Returns: Nothing

  Sets the text/caption of a control
 ------------------------------------------------------------------------------}
procedure TWinControl.RealSetText(const AValue: TCaption);
begin
  {$IFDEF VerboseTWinControlRealText}
  DebugLn(['TWinControl.RealSetText ',DbgSName(Self),' AValue="',AValue,'" HandleAllocated=',HandleAllocated,' csLoading=',csLoading in ComponentState]);
  {$ENDIF}
  if HandleAllocated and (not (csLoading in ComponentState)) then
  begin
    WSSetText(AValue);
    InvalidatePreferredSize;
    inherited RealSetText(AValue);
    AdjustSize;
  end
  else inherited RealSetText(AValue);
  {$IFDEF VerboseTWinControlRealText}
  DebugLn(['TWinControl.RealSetText ',DbgSName(Self),' END']);
  {$ENDIF}
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.GetDeviceContext
  Params:  WindowHandle: the windowhandle of this control
  Returns: a Devicecontext

  Get the devicecontext for this WinControl.
 ------------------------------------------------------------------------------}
function TWinControl.GetDeviceContext(var WindowHandle: HWND): HDC;
begin
  Result := GetDC(Handle);
  //DebugLn('[TWinControl.GetDeviceContext] ',ClassName,' DC=',DbgS(Result,8),' Handle=',DbgS(FHandle));
  if Result = 0 then
     raise EOutOfResources.CreateFmt(rsErrorCreatingDeviceContext, [Name, ClassName]);

  WindowHandle := Handle;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.CMVisibleChanged
  Params:  Message : not used
  Returns: nothing

  Performs actions when visibility has changed
 ------------------------------------------------------------------------------}
procedure TWinControl.CMVisibleChanged(var Message : TLMessage);
begin
  if not FVisible and Assigned(Parent) then
    RemoveFocus(False);

  if not (csDesigning in ComponentState) or (csNoDesignVisible in ControlStyle) then
    UpdateControlState;
end;

procedure TWinControl.CMEnter(var Message: TLMessage);
begin
  DoEnter;
end;

procedure TWinControl.CMExit(var Message: TLMessage);
begin
  DoExit;
end;

procedure TWinControl.CMParentDoubleBufferedChanged(var Message: TLMessage);
begin
  if FParentDoubleBuffered then
  begin
    if Assigned(FParent) then
      DoubleBuffered := FParent.DoubleBuffered; // call CM_DOUBLEBUFFEREDCHANGED
    FParentDoubleBuffered := True;
  end;
end;

procedure TWinControl.WMContextMenu(var Message: TLMContextMenu);
var
  Child: TControl;
begin
  // Check if at the click place we have a control and if so then pass the
  // message to it.
  // Don't check csDesigning here - let a child control check it.
  if (Message.Result <> 0) then
    Exit;

  if Message.XPos <> -1 then
  begin
    // don't allow disabled and don't search wincontrols - they receive their
    // message themself
    Child := ControlAtPos(ScreenToClient(SmallPointToPoint(Message.Pos)), []);
    if Assigned(Child) then
      with Message do
      begin
        Result := Child.Perform(Msg, WParam(hWnd), LParam(Integer(Pos)));
        if (Result <> 0) then
          Exit;
      end;
  end;

  inherited;
end;

procedure TWinControl.DoSendShowHideToInterface;
var
  NewVisible: Boolean;
begin
  NewVisible := HandleObjectShouldBeVisible;
  if NewVisible <> (wcfHandleVisible in FWinControlFlags) then
  begin
    if NewVisible then
      Include(FWinControlFlags, wcfHandleVisible)
    else
      Exclude(FWinControlFlags, wcfHandleVisible);
    {$IF defined(VerboseNewAutoSize) or defined(VerboseIntfSizing) or defined(VerboseShowing)}
    DebugLn(['TWinControl.DoSendShowHideToInterface ',DbgSName(Self),' FBoundsRealized=',dbgs(FBoundsRealized),' New=',HandleObjectShouldBeVisible]);
    {$ENDIF}
    TWSWinControlClass(WidgetSetClass).ShowHide(Self);
  end;
end;

procedure TWinControl.ControlsAligned;
begin

end;

procedure TWinControl.DoSendBoundsToInterface;
var
  NewBounds: TRect;
  OldClientRect: TRect;
  NewClientRect: TRect;
  {$IF defined(VerboseResizeFlicker) or defined(VerboseSizeMsg)}
  OldBounds: TRect;
  {$ENDIF}
begin
  if (Parent = nil) and (not HandleObjectShouldBeVisible) then
  begin
    { do not move invisible forms
       Reason: It is common to do this:
            Form1:=TForm1.Create(nil);
            Form1.Top:=100;
            Form1.Left:=100;
            Form1.Show;
       This moves the form around and confuses some windowmanagers.
       Only send the last bounds. }
    Exit;
  end;
  NewBounds := Bounds(Left, Top, Width, Height);
  {$IF defined(VerboseResizeFlicker) or defined(VerboseSizeMsg)}
  if HandleAllocated then begin
    GetWindowRelativePosition(Handle,OldBounds.Left,OldBounds.Top);
    GetWindowSize(Handle,OldBounds.Right,OldBounds.Bottom);
    inc(OldBounds.Right,OldBounds.Left);
    inc(OldBounds.Bottom,OldBounds.Top);
  end else
    OldBounds:=NewBounds;
  DebugLn(['[TWinControl.DoSendBoundsToInterface] ',DbgSName(Self),
    ' Old=',dbgs(OldBounds),
    ' New=',dbgs(NewBounds),
    ' PosChanged=',(OldBounds.Left<>NewBounds.Left) or (OldBounds.Top<>NewBounds.Top),
    ' SizeChanged=w',(OldBounds.Right-OldBounds.Left<>NewBounds.Right-NewBounds.Left),
                 ',h', (OldBounds.Bottom-OldBounds.Top<>NewBounds.Bottom-NewBounds.Top),
    ' CurClient=',FClientWidth,'x',FClientHeight
    ]);
  {$ENDIF}
  {$IFDEF CHECK_POSITION}
  if CheckPosition(Self) then
    DebugLn('[TWinControl.DoSendBoundsToInterface] A ',DbgSName(Self),
    ' OldRelBounds=',dbgs(FBoundsRealized),
    ' -> NewBounds=',dbgs(NewBounds),
    ' ClientRect=',dbgs(ClientRect));
  {$ENDIF}

  {$IFDEF VerboseClientRectBugFix}
  //if Name=CheckClientRectName then
  DebugLn('[TWinControl.DoSendBoundsToInterface] A ',DbgSName(Self),
  ' OldRelBounds=',dbgs(FBoundsRealized),
  ' -> NewBounds=',dbgs(NewBounds)
  //,' Parent.Bounds=',dbgs(Parent.BoundsRect)
  //,' Parent.ClientRect=',dbgs(Parent.ClientRect)
  );
  {$ENDIF}

  {$IFDEF VerboseIntfSizing}
  if Visible then begin
    DebugLn('[TWinControl.DoSendBoundsToInterface] A ',DbgSName(Self),
    ' OldRelBounds=',dbgs(FBoundsRealized),
    ' -> NewBounds=',dbgs(NewBounds));
  end;
  {$ENDIF}
  FBoundsRealized := NewBounds;
  OldClientRect := ClientRect; // during a resize this is the anticipated new ClientRect
  Include(FWinControlFlags, wcfBoundsRealized); // Note: set before calling widgetset, because used in WMSize
  //if Parent=nil then DebugLn(['TWinControl.DoSendBoundsToInterface ',DbgSName(Self),' ',dbgs(BoundsRect)]);
  // this can trigger WMSize messages
  TWSWinControlClass(WidgetSetClass).SetBounds(Self, Left, Top, Width, Height);
  NewClientRect := ClientRect;
  if Visible and (not CompareRect(@OldClientRect,@NewClientRect)) then
  begin
    // the widgetset has changed the clientrect in an unexpected way
    {$IFDEF VerboseIntfSizing}
    debugln(['TWinControl.DoSendBoundsToInterface WS has changed ClientRect in an unexpected way: ',
      DbgSName(Self),' Bounds=',dbgs(BoundsRect),' ExpectedClientRect=',dbgs(OldClientRect),' New=',dbgs(NewClientRect)]);
    {$ENDIF}
    //DebugLn(['TWinControl.DoSendBoundsToInterface ',DbgSName(Self),' Bounds=',dbgs(BoundsRect),' OldClientRect=',dbgs(OldClientRect),' NewClientRect=',dbgs(NewClientRect)]);
    AdjustSize;
  end;
end;

procedure TWinControl.RealizeBounds;

  procedure Check;
  var
    c: TWinControl;
  begin
    c:=Self;
    while c<>nil do begin
      DebugLn(['Check ',DbgSName(c),' ',c.HandleAllocated,
        ' wcfCreatingHandle=',wcfCreatingHandle in FWinControlFlags,
        ' wcfInitializing=',wcfInitializing in FWinControlFlags,
        ' wcfCreatingChildHandles=',wcfCreatingChildHandles in FWinControlFlags,
        '']);
      c:=c.Parent;
    end;
    RaiseGDBException('');
  end;

var
  NewBounds: TRect;
begin
  NewBounds:=Bounds(Left, Top, Width, Height);
  if HandleAllocated
  and ([csLoading,csDestroying]*ComponentState=[])
  and (not (csDestroyingHandle in ControlState))
  and (not CompareRect(@NewBounds,@FBoundsRealized))
  then begin
    // the new bounds were not yet sent to the InterfaceObject -> send them
    {$IFDEF CHECK_POSITION}
    //if csDesigning in ComponentState then
    if CheckPosition(Self) then
    DebugLn('[TWinControl.RealizeBounds] A ',DbgSName(Self),
    ' OldRelBounds=',dbgs(FBoundsRealized),
    ' -> NewBounds=',dbgs(NewBounds));
    {$ENDIF}
    BeginUpdateBounds;
    try
      DoSendBoundsToInterface;
    finally
      EndUpdateBounds;
    end;
  end else begin
    {$IFDEF CHECK_POSITION}
    if CheckPosition(Self) then begin
      DbgOut('[TWinControl.RealizeBounds] NOT REALIZING ',DbgSName(Self),
      ' OldRelBounds=',dbgs(FBoundsRealized),
      ' -> NewBounds=',dbgs(NewBounds),
      ', because ');
      if not HandleAllocated then debugln('not HandleAllocated');
      if (csLoading in ComponentState) then debugln('csLoading');
      if (csDestroying in ComponentState) then debugln('csDestroying');
      if (CompareRect(@NewBounds,@FBoundsRealized)) then debugln('bounds not changed');
    end;
    {$ENDIF}
    if not HandleAllocated then Check;
  end;
end;

procedure TWinControl.RealizeBoundsRecursive;
var
  i: Integer;
  OldRealizing: boolean;
  AControl: TControl;
begin
  if not HandleAllocated then exit;
  OldRealizing:=wcfRealizingBounds in FWinControlFlags;
  Include(FWinControlFlags,wcfRealizingBounds);
  try
    if FControls<>nil then begin
      for i:=0 to FControls.Count-1 do begin
        AControl:=TControl(FControls[i]);
        if (AControl is TWinControl) then
          TWinControl(AControl).RealizeBoundsRecursive;
      end;
    end;
    RealizeBounds;
  finally
    if not OldRealizing then
      Exclude(FWinControlFlags,wcfRealizingBounds);
  end;
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.CMShowingChanged
  Params:  Message : not used
  Returns: nothing

  Shows or hides a control
  Called by UpdateShowing
 ------------------------------------------------------------------------------}
procedure TWinControl.CMShowingChanged(var Message: TLMessage);
begin
  {$IFDEF VerboseShowing}
  DebugLn(['TWinControl.CMShowingChanged ',DbgSName(Self),' HandleAllocated=',HandleAllocated,' ',dbgs(ComponentState)]);
  {$ENDIF}
  if HandleAllocated and ([csDestroying,csLoading]*ComponentState=[]) then
    DoSendShowHideToInterface
  else
    Exclude(FWinControlFlags, wcfHandleVisible);
end;

{------------------------------------------------------------------------------
  Method:  TWinControl.ShowControl
  Params:  AControl: Control to show
  Returns: nothing

  Called by a child control (in TControl.Show), before setting Visible=true.
  Asks to show the child control and recursively shows the parents.
 ------------------------------------------------------------------------------}
procedure TWinControl.ShowControl(AControl: TControl);
begin
  if Parent <> nil then Parent.ShowControl(Self);
end;

{ TWinControlEnumerator }

function TWinControlEnumerator.GetCurrent: TControl;
begin
  if (FIndex>=0) and (FIndex<FParent.ControlCount) then
    Result:=FParent.Controls[FIndex]
  else
    Result:=nil;
end;

constructor TWinControlEnumerator.Create(Parent: TWinControl;
  aLowToHigh: boolean);
begin
  FParent:=Parent;
  FLowToHigh:=aLowToHigh;
  if FLowToHigh then
    FIndex:=-1
  else
    FIndex:=FParent.ControlCount;
end;

function TWinControlEnumerator.GetEnumerator: TWinControlEnumerator;
begin
  Result:=Self;
end;

function TWinControlEnumerator.MoveNext: Boolean;
begin
  if FLowToHigh then
  begin
    inc(FIndex);
    Result:=FIndex<FParent.ControlCount;
  end
  else begin
    dec(FIndex);
    Result:=FIndex>=0
  end;
end;

{ $UNDEF CHECK_POSITION}

{$IFDEF ASSERT_IS_ON}
  {$UNDEF ASSERT_IS_ON}
  {$C-}
{$ENDIF}

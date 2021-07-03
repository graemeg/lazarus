{%MainUnit ../comctrls.pp}

{******************************************************************************
                                  TPageControl
 ******************************************************************************

  Author: Mattias Gaertner

 *****************************************************************************
  This file is part of the Lazarus Component Library (LCL)

  See the file COPYING.modifiedLGPL.txt, included in this distribution,
  for details about the license.
 *****************************************************************************

}

{ TPageControl }

function TPageControl.GetActivePageIndex: Integer;
begin
  Result:=inherited PageIndex;
end;

function TPageControl.GetActiveTabSheet: TTabSheet;
begin
  Result:=TTabSheet(inherited ActivePageComponent);
end;

function TPageControl.GetTabSheet(Index: Integer): TTabSheet;
begin
  Result:=TTabSheet(inherited Page[Index]);
end;

procedure TPageControl.SetActivePageIndex(const AValue: Integer);
begin
  inherited PageIndex:=AValue;
end;

procedure TPageControl.SetActiveTabSheet(const AValue: TTabSheet);
begin
  //debugln(['TPageControl.SetActiveTabSheet ',DbgSName(Self),' ',DbgSName(AValue)]);
  ActivePageComponent := AValue;
end;

function TPageControl.FindPageWithDockClient(Client: TControl): TTabSheet;
var
  i: integer;
begin
  for i := 0 to PageCount - 1 do
    if Pages[i] = Client.Parent then
    begin
      Result := Pages[i];
      exit;
    end;
  Result := nil;
end;

class procedure TPageControl.WSRegisterClass;
begin
  inherited WSRegisterClass;
  RegisterPageControl;
  RegisterPropertyToSkip(TPageControl, 'PageIndex', 'Needed when converting from VCL TabbedNotebook to TPageControl', '');
  RegisterPropertyToSkip(TPageControl, 'TabFont', 'Needed when converting from VCL TabbedNotebook to TPageControl', '');
end;

function TPageControl.GetPageClass: TCustomPageClass;
begin
  Result := TTabSheet;
end;

procedure TPageControl.DoAddDockClient(Client: TControl; const ARect: TRect);
var
  TabSheet: TTabSheet;
begin
  // Client cannot be added to TPageControl itself but new TabSheet should be
  // added and client placed onto it
  TabSheet := TTabSheet.Create(Self);
  TabSheet.Caption := GetDockCaption(Client);
  try
    TabSheet.PageControl := Self;
    Client.Parent := TabSheet;
    // delphi compatible behaviour => align to client
    Client.Align := alClient;
  except
    FreeAndNil(TabSheet);
  end;
end;

procedure TPageControl.DockOver(Source: TDragDockObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  P: TPoint;
begin
  P := Parent.ClientToScreen(Point(Left, Top));
  Source.DockRect := Rect(P.X, P.Y, P.X + Width, P.Y + Height);
  DoDockOver(Source, X, Y, State, Accept);
end;

procedure TPageControl.DoRemoveDockClient(Client: TControl);
begin
  // we cannot search for client page here since Client.Parent
  // is changed at moment => search for page before parent change and free here
  FreeAndNil(FPageToUndock);
end;

function TPageControl.DoUndockClientMsg(NewTarget, Client: TControl): boolean;
begin
  FPageToUndock := FindPageWithDockClient(Client);
  Result := inherited DoUndockClientMsg(NewTarget, Client);
end;

function TPageControl.ChildClassAllowed(ChildClass: TClass): boolean;
begin
  Result:=(ChildClass<>nil) and (ChildClass.InheritsFrom(GetPageClass));
  if Widgetset.GetLCLCapability(lcAllowChildControlsInNativeControls) = LCL_CAPABILITY_YES then Result := True;
end;

function TPageControl.FindNextPage(CurPage: TTabSheet; GoForward,
  CheckTabVisible: Boolean): TTabSheet;
var
  I, StartIndex: Integer;
begin
  Result := nil;
  if PageCount = 0 then
    exit;
  StartIndex := IndexOf(CurPage);
  if StartIndex < 0 then
    if GoForward then
      StartIndex := PageCount - 1
    else
      StartIndex := 0;
  i := StartIndex;
  repeat
    if GoForward then
    begin
      Inc(i);
      if i = PageCount then
        i := 0;
    end else
    begin
      if i = 0 then
        i := PageCount;
      Dec(I);
    end;
    if not CheckTabVisible or Pages[i].TabVisible then
    begin
      Result := Pages[i];
      exit;
    end;
  until i = StartIndex;
end;

procedure TPageControl.SelectNextPage(GoForward: Boolean);
begin
  SelectNextPage(GoForward,true);
end;

procedure TPageControl.SelectNextPage(GoForward: Boolean;
  CheckTabVisible: Boolean);
var
  NextPage: TTabSheet;
begin
  NextPage:=FindNextPage(ActivePage,GoForward,CheckTabVisible);
  if NextPage<>nil then ActivePage:=NextPage;
end;

function TPageControl.IndexOfTabAt(X, Y: Integer): Integer;
begin
  Result:=inherited IndexOfTabAt(X, Y);
end;

function TPageControl.IndexOfTabAt(P: TPoint): Integer;
begin
  Result:=inherited IndexOfTabAt(P);
end;

function TPageControl.IndexOfPageAt(X, Y: Integer): Integer;
begin
  Result:=inherited IndexOfPageAt(X, Y);
end;

function TPageControl.IndexOfPageAt(P: TPoint): Integer;
begin
  Result:=inherited IndexOfPageAt(P);
end;

// Convenience routine, to make the TPageControl more intuitive to use
// A Lazarus addition
function TPageControl.AddTabSheet: TTabSheet;
begin
  Result := GetPageClass.Create(Self) as TTabSheet;
  Result.PageControl := Self;
end;

procedure TPageControl.Clear;
begin
  Tabs.Clear;
end;

// included by comctrls.pp

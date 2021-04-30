{
  ./testcodetools --format=plain --suite=TestFindDeclaration_Generics_FindDeclaration
}
program fdt_generics_finddeclaration;

{$mode objfpc}{$H+}

type

  { TEnumerator }

  generic TEnumerator<T> = class abstract
  public
    property Current: T read DoGetCurrent;
  end;

  { TEnumerable }

  generic TEnumerable<T> = class abstract
  public
    function GetEnumerator: specialize TEnumerator<T>; virtual; abstract;
  end;

  { TEnumerableWithPointers }

  generic TEnumerableWithPointers<T> = class(specialize TEnumerable<T>)
  end;

  { TCustomList }

  generic TCustomList<T> = class abstract(specialize TEnumerableWithPointers<T>)
  end;

  { TCustomListEnumerator }

  generic TCustomListEnumerator<T> = class abstract(specialize TEnumerator<T>)
  protected
    function GetCurrent: T; virtual; abstract;
  end;

  { TCustomListWithPointers }

  generic TCustomListWithPointers<T> = class(specialize TCustomList<T>)
  end;

  { TListP1 }

  generic TListP1<B, B2, B3> = class(specialize TCustomListWithPointers<B>)
  private
    function GetItem(Index: SizeInt): B;
    procedure SetItem(Index: SizeInt; AValue: B);
  public
    type
      TEnumerator = class(specialize TCustomListEnumerator<B>);
    function GetEnumerator: TEnumerator; virtual; abstract;
    property Items[Index: SizeInt]: B read GetItem write SetItem; default;
  end;

  { TListP2 }

  generic TListP2<B2, B, B3> = class(specialize TCustomListWithPointers<B>)
  private
    function GetItem(Index: SizeInt): B;
    procedure SetItem(Index: SizeInt; AValue: B);
  public
    type
      TEnumerator = class(specialize TCustomListEnumerator<B>);
    function GetEnumerator: TEnumerator; virtual; abstract;
    property Items[Index: SizeInt]: B read GetItem write SetItem; default;
  end;

  { TListP3 }

  generic TListP3<B2, B3, B> = class(specialize TCustomListWithPointers<B>)
  private
    function GetItem(Index: SizeInt): B;
    procedure SetItem(Index: SizeInt; AValue: B);
  public
    type
      TEnumerator = class(specialize TCustomListEnumerator<B>);
    function GetEnumerator: TEnumerator; virtual; abstract;
    property Items[Index: SizeInt]: B read GetItem write SetItem; default;
  end;

  generic TObjectListP1_1<A: class; A2, A3> = class(specialize TListP1<A, A2, A3>)
  end;
  generic TObjectListP1_2<A: class; A2, A3> = class(specialize TListP2<A2, A, A3>)
  end;
  generic TObjectListP1_3<A: class; A2, A3> = class(specialize TListP3<A2, A3, A>)
  end;

  generic TObjectListP2_1<A2; A: class; A3> = class(specialize TListP1<A, A2, A3>)
  end;
  generic TObjectListP2_2<A2; A: class; A3> = class(specialize TListP2<A2, A, A3>)
  end;
  generic TObjectListP2_3<A2; A: class; A3> = class(specialize TListP3<A2, A3, A>)
  end;

  generic TObjectListP3_1<A2, A3; A: class> = class(specialize TListP1<A, A2, A3>)
  end;
  generic TObjectListP3_2<A2, A3; A: class> = class(specialize TListP2<A2, A, A3>)
  end;
  generic TObjectListP3_3<A2, A3; A: class> = class(specialize TListP3<A2, A3, A>)
  end;

  XYZ = Integer;

  TObj = class
    X: XYZ;
    Y: Integer;
    function Z: String;
  end;
  TObj1 = class
  end;
  TObj2 = class
  end;

  TOL_P1_1 = specialize TObjectListP1_1<TObj, TObj1, TObj2>;
  TOL_P1_2 = specialize TObjectListP1_2<TObj, TObj1, TObj2>;
  TOL_P1_3 = specialize TObjectListP1_3<TObj, TObj1, TObj2>;
  TOL_P2_1 = specialize TObjectListP2_1<TObj1, TObj, TObj2>;
  TOL_P2_2 = specialize TObjectListP2_2<TObj1, TObj, TObj2>;
  TOL_P2_3 = specialize TObjectListP2_3<TObj1, TObj, TObj2>;
  TOL_P3_1 = specialize TObjectListP3_1<TObj1, TObj2, TObj>;
  TOL_P3_2 = specialize TObjectListP3_2<TObj1, TObj2, TObj>;
  TOL_P3_3 = specialize TObjectListP3_3<TObj1, TObj2, TObj>;
  TOL_2 = class(specialize TObjectListP1_1<TObj, TObj1, TObj2>);
  TOL_3 = TOL_2;
  TOL_4 = class(TOL_2);

  generic TArray<T> = array of T;

var
  OL_P1_1: TOL_P1_1;
  OL_P1_2: TOL_P1_2;
  OL_P1_3: TOL_P2_3;
  OL_P2_1: TOL_P2_1;
  OL_P2_2: TOL_P2_2;
  OL_P2_3: TOL_P2_3;
  OL_P3_1: TOL_P3_1;
  OL_P3_2: TOL_P3_2;
  OL_P3_3: TOL_P3_3;
  OL2: TOL_2;
  OL3: TOL_3;
  OL4: TOL_4;
  A: specialize TArray<TObj>;

function TListP1.GetItem(Index: SizeInt): B;
begin
end;

procedure TListP1.SetItem(Index: SizeInt; AValue: B);
begin
end;

function TListP2.GetItem(Index: SizeInt): B;
begin
end;

procedure TListP2.SetItem(Index: SizeInt; AValue: B);
begin
end;

function TListP3.GetItem(Index: SizeInt): B;
begin
end;

procedure TListP3.SetItem(Index: SizeInt; AValue: B);
begin
end;

function TObj.Z: String;
begin
end;

begin
  o_p1_1_x := OL_P1_1[0].X{declaration:TObj.X};
  o_p1_1_y := OL_P1_1[0].Y{declaration:TObj.Y};
  o_p1_1_z := OL_P1_1[0].Z{declaration:TObj.Z};
  o_p1_2_x := OL_P1_2[0].X{declaration:TObj.X};
  o_p1_2_y := OL_P1_2[0].Y{declaration:TObj.Y};
  o_p1_2_z := OL_P1_2[0].Z{declaration:TObj.Z};
  o_p1_3_x := OL_P1_3[0].X{declaration:TObj.X};
  o_p1_3_y := OL_P1_3[0].Y{declaration:TObj.Y};
  o_p1_3_z := OL_P1_3[0].Z{declaration:TObj.Z};
  o_p2_1_x := OL_P2_1[0].X{declaration:TObj.X};
  o_p2_1_y := OL_P2_1[0].Y{declaration:TObj.Y};
  o_p2_1_z := OL_P2_1[0].Z{declaration:TObj.Z};
  o_p2_2_x := OL_P2_2[0].X{declaration:TObj.X};
  o_p2_2_y := OL_P2_2[0].Y{declaration:TObj.Y};
  o_p2_2_z := OL_P2_2[0].Z{declaration:TObj.Z};
  o_p2_3_x := OL_P2_3[0].X{declaration:TObj.X};
  o_p2_3_y := OL_P2_3[0].Y{declaration:TObj.Y};
  o_p2_3_z := OL_P2_3[0].Z{declaration:TObj.Z};
  o_p3_1_x := OL_P3_1[0].X{declaration:TObj.X};
  o_p3_1_y := OL_P3_1[0].Y{declaration:TObj.Y};
  o_p3_1_z := OL_P3_1[0].Z{declaration:TObj.Z};
  o_p3_2_x := OL_P3_2[0].X{declaration:TObj.X};
  o_p3_2_y := OL_P3_2[0].Y{declaration:TObj.Y};
  o_p3_2_z := OL_P3_2[0].Z{declaration:TObj.Z};
  o_p3_3_x := OL_P3_3[0].X{declaration:TObj.X};
  o_p3_3_y := OL_P3_3[0].Y{declaration:TObj.Y};
  o_p3_3_z := OL_P3_3[0].Z{declaration:TObj.Z};
  o2_x := OL2[0].X{declaration:TObj.X};
  o2_y := OL2[0].Y{declaration:TObj.Y};
  o2_z := OL2[0].Z{declaration:TObj.Z};
  o3_x := OL3[0].X{declaration:TObj.X};
  o3_y := OL3[0].Y{declaration:TObj.Y};
  o3_z := OL3[0].Z{declaration:TObj.Z};
  o4_x := OL4[0].X{declaration:TObj.X};
  o4_y := OL4[0].Y{declaration:TObj.Y};
  o4_z := OL4[0].Z{declaration:TObj.Z};
  o_x := A[0].X{declaration:TObj.X};
  o_y := A[0].Y{declaration:TObj.Y};
  o_z := A[0].Z{declaration:TObj.Z};
end.




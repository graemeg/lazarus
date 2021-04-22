unit ceImages;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, TAChartImageList;

type

  { TChartImagesDM }

  TChartImagesDM = class(TDataModule)
    ChartImages: TChartImageList;
  private

  public

  end;

var
  ChartImagesDM: TChartImagesDM;

implementation

{$R *.lfm}

end.


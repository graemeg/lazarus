unit Unit1; 

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Forms, DbCtrls, db, DBGrids, dbf, ExtCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    DataSource1: TDataSource;
    DataSource2: TDataSource;
    Dbf1: TDbf;
    Dbf1ID: TLongintField;
    Dbf1LANG: TStringField;
    Dbf1MTH_NAME: TStringField;
    Dbf1MTH_NO: TLongintField;
    Dbf2: TDbf;
    Dbf2MONTH_NA: TStringField;
    Dbf2ID: TLongintField;
    Dbf2ID_MONTH: TLongintField;
    Dbf2LANGUAGE: TStringField;
    Dbf2MONTH_NO: TLongintField;
    DBGrid1: TDBGrid;
    DBGrid2: TDBGrid;
    DBLookupComboBox1: TDBLookupComboBox;
    DBLookupComboBox2: TDBLookupComboBox;
    DBLookupListBox1: TDBLookupListBox;
    DBLookupListBox2: TDBLookupListBox;
    Panel1: TPanel;
    Splitter1: TSplitter;
    Splitter2: TSplitter;
    procedure FormShow(Sender: TObject);
  private

  public

  end; 

var
  Form1: TForm1; 

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormShow(Sender: TObject);
var
  S: string;
  I: Integer;
begin
  S := Application.ExeName;
  // hack for Mac
  I := Pos('.app/Contents/MacOS/', S);
  if (I > 0) then
    S := Copy(S,1, I+3);
  Dbf1.FilePath := ExtractFilePath(S)+'data'+PathDelim;
  Dbf1.Open;
  // Dbf1.InsertRecord([0,'GB',1,'January']);
  Dbf2.FilePath := Dbf1.FilePath;
  Dbf2.Open;
end;

end.


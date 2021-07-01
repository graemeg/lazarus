unit dbform;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, db, sqldb, Forms, Controls, Dialogs, DBGrids, dbloginform,
  mssqlconn; // mssqlconn was added to 2.6.1, you need a recent 2.6.1


type

  { TForm1 }

  TForm1 = class(TForm)
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    MSSQLConnection1: TMSSQLConnection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    SybaseConnection1: TSybaseConnection;
    procedure FormCreate(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }


procedure TForm1.FormCreate(Sender: TObject);
type
  DBType=(MSSQL,SybaseASE);
var
  ChosenDB: DBType;
  Connection: TSQLConnection;
  DBSelected: string;
  GoodConnection: boolean;
  LoginForm: dbloginform.TLoginForm;
  Password: string;
  UserCancel: boolean;
begin
  // Let user login.
  GoodConnection:=false;
  UserCancel:=false;
  LoginForm:=dbloginform.TLoginForm.Create(Nil);
  try
    while (GoodConnection=false) and (UserCancel=false) do
    begin
      if LoginForm.ShowModal=mrOK then
      begin
        DBSelected:=LoginForm.DatabaseType.Items[LoginForm.DatabaseType.ItemIndex];
        // Use the text in the databasetype combobox to see what db the user wants.
        // Then we point our Connection to the relevant TSQLConnection descendant.
        case UpperCase(DBSelected) of
        'MS SQL SERVER':
          begin
            ChosenDB:=MSSQL;
            Connection:=MSSQLConnection1;
          end;
        'SYBASE ASE':
          begin
            ChosenDB:=SybaseASE;
            Connection:=SybaseConnection1;
          end
        else
          begin
            showmessage('Unknown database type '+DBSelected+' chosen. Aborting. Pleae fix the code!');
            Application.Terminate;
          end;
        end;
        if LoginForm.OSAuthentication.Checked then
        begin
          // Use operating system credentials - mssqlconn
          // expectes empty username/password then.
          Connection.UserName:='';
          Connection.Password:='';
        end
        else
        begin
          // Use regular username/password
          Connection.UserName:=LoginForm.User.Text;
          Connection.Password:=LoginForm.Password.Text;
        end;
        if LoginForm.Port.Text<>'' then
        begin
          Connection.HostName:=LoginForm.Server.Text+':'+LoginForm.Port.Text;
        end
        else
        begin
          // Default/no port. Let the connector sort it out.
          Connection.HostName:=LoginForm.Server.Text;
        end;
        Connection.DatabaseName:=LoginForm.Database.Text;

        // Actually, this should work both on MS SQL and Sybase server, so no need to change it:
        //SQLQuery1.SQL.Text:='select * from sysservers';
        // Everything set up, now connect to database.
        // First make sure the other connection is switched off:
        if ChosenDB=MSSQL then
        begin
          SybaseConnection1.Connected:=false;
        end
        else
        begin
          MSSQLConnection1.Connected:=false;
        end;
        SQLTransaction1.DataBase:=Connection;
        SQLQuery1.DataBase:=Connection;
        try
          Connection.Connected:=true;
          GoodConnection:=true;
        except
          on E: Exception do
          begin
            GoodConnection:=false;
            showmessage('Error connecting to database. Technical details: '+E.ClassName+'/'+E.Message);
          end;
        end;
      end
      else
      begin
        showmessage('User cancelled login. Stopping.');
        UserCancel:=true; //Tell the loop to release us.
        Application.Terminate;
      end;
    end;
    if UserCancel=false then
    begin
      // Now activate the components "downstream" of the database connection to get the data
      // displayed to the user
      try
        SQLTransaction1.Active:=true;
        SQLQuery1.Active:=true;
        GoodConnection:=true;
      except
        on E: Exception do
        begin
          GoodConnection:=false;
          showmessage('Error connecting to database. Technical details: '+E.ClassName+'/'+E.Message);
        end;
      end;
    end;
  finally
    // Close the form and release memory
    LoginForm.Release;
  end;
end;

end.


{
������ ��� ���������� ����������
}
unit U2;

interface

uses
  SingletonTemplate, // ������, ���������� TSingleton �� Ins-�
  SyncObjs; // ������ ��� TEvent

type
  TSettings = class(TSingleton)
  protected
    constructor Create; override;
  public
    destructor Destroy; override;
  private
    //FSaveFolder: String;
    FNetName: string;
    FPDOUse: Boolean;
    FUserName: string;
    FCheckEvent: TEvent;
    FSecondStart : Boolean;
    FStopIniMessage: string;
    FStopIniPath:string;
    //FStopIniTime : Integer;
    FFullName: string;
    FViewType: Byte; // 0 blanks, 1 blank561, 2 blank562, 3 udal
    FOldGridTitle: string;
    function GetComputerNetName: string;
    function GetCurrentUserName: string;
    function GetStopIni:Integer;
    // ...
  public
    //property SaveFolder: String read FSaveFolder;
    property NetName: string read FNetName;
    property UserName: string read FUserName;
    property FullName: string read FFullName;
    property StopIni : Integer read GetStopIni;
    property StopIniMessage : string read FStopIniMessage;
    property StopIniPath : string read FStopIniPath write FStopIniPath;
    //property StopIniTime : Integer read FStopIniTime write FStopIniTime;
    property SecondStart: Boolean read FSecondStart;
    property OldViewType: Byte read FViewType write FViewType;
    property OldGridTitle: string read FOldGridTitle write FOldGridTitle;
    property PDOUse: Boolean read FPDOUse;
    // ...� ������ ��������� ���������
    // ����� �������� � ������ ��������/���������� ��������:
    // procedure Save;
    // procedure Load;
    // � ����� � �� ��������� - ����� �� �������� ��� � Create/Destroy ������� TSettings

    // ...� ������ ������ TSettings
  end;

function Settings: TSettings;

implementation
uses Windows,u1, SysUtils, IniFiles;

function Settings: TSettings;
begin
  Result := TSettings.GetInstance;
end;

{��������� �������� ����� ������� �������
@returns(������� ��� ��� ������)}

function TSettings.GetComputerNetName: string;
var
  buffer: array[0..255] of char;
  size: dword;
begin
  size := 256;
  if GetComputerName(buffer, size) then
    Result := buffer
  else
    Result := '';
end;

{��������� ����� ������������ ��
@returns(��� ������������ �� ��� ������)}

function TSettings.GetCurrentUserName: string;
var
  buffer: array[0..255] of char;
  size: dword;
begin
  size := 256;
  if GetUserName(buffer, size) then
    Result := buffer
  else
    Result := '';
end;

function TSettings.GetStopIni: Integer;
var t:Tinifile;
begin
t:=TIniFile.Create(FStopIniPath);
Result := t.ReadInteger('SERVICE','STOP',0);
FStopIniMessage:=t.ReadString('SERVICE','MES','������ ����������. ��� ������������ ���� ������. ��������� ��������� �����!');
FreeAndNil(t);
//FStopIniTime := t.ReadInteger('SERVICE','TIME',);
end;

constructor TSettings.Create;
begin
  inherited Create;
  // ���� ����� ��������� �������� �������� ���������
  FNetName := GetComputerNetName;
  FUserName := GetCurrentUserName;
  FFullName := '(' + FNetName + '\' + FUserName + ') ';
  FViewType := 3;
  FPDOUse:= not ((ParamCount < 2) or (ParamStr(2) <> '1'));
  FCheckEvent := TEvent.Create(nil, false, true, 'PR02PV02_');
  FSecondStart := (FCheckEvent.WaitFor(10) <> wrSignaled);
  FStopIniMessage:='';
  FOldGridTitle:='';
end;

destructor TSettings.Destroy;
begin
  // ���� ����� ��������� ���������� �������� ���������
  FreeAndNil(FCheckEvent);
  inherited Destroy;
end;
end.

{
Iz modulejj vizivaetsia cherez Setting
Naprimer:

Settings.StopIniPath := InitDBFTable('pr02.ini', '', '', False, False, False, False) + 'pr02.ini';
}
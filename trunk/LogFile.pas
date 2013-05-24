unit LogFile;

interface

uses Windows, SysUtils;

type
  TLogFile = class(TObject)
  private
    FhFile: Cardinal;
    FUserName: string;
    FBackUpCount: byte;
    function BackupData(SourceName: string; NumBack: Byte = 1): string;
    procedure SetBackUpCount(const Value: byte);
  public
    property BackUpCount: byte read FBackUpCount write SetBackUpCount;
    constructor Create(_FileName: string; MaxSize: integer = -1);
    destructor Destroy; override;
    procedure PutLine(const NewLine: string);
  end;

implementation

function fDateTimeToStr(const dDate: TDateTime): string;

var
  S: string;
begin
  DateTimeToString(S, 'dd.mm.yy hh:nn:ss', dDate);
  Result := S;
end;

{ TLogFile }

constructor TLogFile.Create(_FileName: string; MaxSize: integer = -1);
var
  nSize: Cardinal;
begin
  nSize := 255;
  SetLength(FUserName, 255);
  GetUserName(PChar(FUserName), nSize);
  SetLength(FUserName, nSize - 1);
  FhFile := CreateFile(PChar(_FileName), GENERIC_WRITE,
    FILE_SHARE_WRITE or FILE_SHARE_READ, nil,
    OPEN_ALWAYS, FILE_FLAG_WRITE_THROUGH, 0);
  if FhFile = INVALID_HANDLE_VALUE then
  begin
    raise Exception.Create('LogFile error: ' + SysErrorMessage(GetLastError));
  end;
  if (MaxSize <> -1) and (Integer(GetFileSize(FhFile, nil)) >= MaxSize) then
  begin
    BackupData(_FileName, FBackUpCount);
    SetFilePointer(FhFile, 0, nil, FILE_BEGIN);
    SetEndOfFile(FhFile);
    PutLine('Size of the log file exceeds ' + Format('%.2f', [MaxSize / 1024 /
      1024])
      + ' Mb. Log file updated.');
  end
  else
    SetFilePointer(FhFile, 0, nil, FILE_END);
end;

destructor TLogFile.Destroy;
begin
  CloseHandle(FhFile);
  inherited;
end;

function TLogFile.BackupData(SourceName: string; NumBack: Byte = 1): string;
  procedure fDeleteFile(FileName: string);
  begin
    if FileExists(FileName) then
      if not Windows.DeleteFile(PChar(FileName)) then
        raise Exception.Create('Ошибка при удалении файла ' + FileName + ': ' +
          SysErrorMessage(GetLastError))
  end;

var
  i, BAge: Integer;
  FName: string;
  Ages: array of Integer;
begin
  i := 0;
  BAge := FileAge(SourceName);
  SetLength(Ages, NumBack);
  repeat
    FName := SourceName;
    FName[Length(FName)] := IntToStr(i)[1];

    if FileExists(FName) then
      Ages[i] := FileAge(FName)
    else
      Break;
    if Ages[i] = BAge then
    begin

      fDeleteFile(FName);
      Break;
    end;
    Inc(i);
  until i = NumBack;
  if i = NumBack then
  begin
    i := 0;
    while i < NumBack - 1 do
    begin
      if Ages[i] < Ages[i + 1] then
        Break;
      Inc(i);
    end;
    if i = NumBack - 1 then
      i := 0
    else
      Inc(i);
    FName := SourceName;
    FName[Length(FName)] := IntToStr(i)[1];
    fDeleteFile(FName);
    SetLength(Ages, 0);
  end;
  CopyFile(PChar(SourceName), PChar(FName), False);
  Result := FName;
end;

procedure TLogFile.PutLine(const NewLine: string);
var
  S: ShortString;
  dwWritten: Cardinal;
begin
  if NewLine > '' then
  begin
    S := fDateTimeToStr(Now) + ';' + FUserName + ';' + NewLine + #13#10;
  end
  else
    S := #13#10;
  if not WriteFile(FhFile, S[1], Length(S), dwWritten, nil) then
    raise Exception.Create('LogFile error: ' + SysErrorMessage(GetLastError));
  FlushFileBuffers(FhFile);
end;

procedure TLogFile.SetBackUpCount(const Value: byte);
begin
  if Value < 1 then
    FBackUpCount := 1
  else
    FBackUpCount := Value;
end;

end.


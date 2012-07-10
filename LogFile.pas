unit LogFile;

interface

uses Windows, SysUtils;

type
	TLogFile = class(TObject)
	private
		hFile: Cardinal;
    UserName: String;
	public
		constructor Create(_FileName: string; MaxSize: integer = -1);
		destructor Destroy; override;
		procedure PutLine(const NewLine: string);
	end;

implementation

uses KoaUtils;

{ TLogFile }

constructor TLogFile.Create(_FileName: string; MaxSize: integer = -1);
var
	nSize: Cardinal;
begin
  nSize := 255;
  SetLength(UserName, 255);
  GetUserName(PChar(UserName), nSize);

  SetLength(UserName, nSize-1);
  hFile := CreateFile(PChar(_FileName), GENERIC_WRITE,
  	FILE_SHARE_WRITE OR FILE_SHARE_READ, Nil,
  	OPEN_ALWAYS, FILE_FLAG_WRITE_THROUGH, 0);
  if hFile = INVALID_HANDLE_VALUE then begin
  	raise Exception.Create('LogFile error: ' + SysErrorMessage(GetLastError));
  end;
 	if (MaxSize <> -1) AND (Integer(GetFileSize(hFile, Nil)) >= MaxSize) then begin
  	SetFilePointer(hFile, 0, Nil, FILE_BEGIN);
    SetEndOfFile(hFile);
    PutLine('Размер журнала превысил ' + Format('%.2f', [MaxSize/1024/1024]) + ' Мб. Журнал обновлен.');
  end
  else
   	SetFilePointer(hFile, 0, Nil, FILE_END);
end;

destructor TLogFile.Destroy;
begin
	CloseHandle(hFile);
  inherited;
end;

procedure TLogFile.PutLine(const NewLine: string);
var
	S: ShortString;
  dwWritten: Cardinal;
begin
  if NewLine > '' then begin
    S := fDateTimeToStr(Now()) +'  '+ UserName+ ' - ' +NewLine + #13#10;
  end
  else
    S := #13#10;

	if not WriteFile(hFile, S[1], Length(S), dwWritten, Nil) then
  	raise Exception.Create('LogFile error: ' + SysErrorMessage(GetLastError));

  FlushFileBuffers(hFile);
end;

end.

unit KoaUtils;

interface

uses Classes, ASU_DBF, LogFile, DBTables, BDE, Graphics, Math, Types;

type
  NetDisk = (G, H, H_PDO, K, L);
  TUpdInd = (GEN, FILETIME);

const
  Conn: array[NetDisk] of string = ('\\nevz\nevz\pdo\pdo1',
    '\\nevz\nevz\workshop',
    '\\nevz\nevz\pdo\pdo2',
    '\\admiral1\data1',
    '\\admiral1\data2');
const
  Let: array[NetDisk] of string = ('G:', 'H:', 'H:', 'K:', 'L:');

var
  DrawBitmap: TBitmap;

function ConvertSI(SourceDBF, Dest: string): Integer;
function GetSIfromDB(const FileName: string): ASU_SI;
function PutSItoDB(const FileName: string; const si: ASU_SI): Integer;

function GetPath(const Bases, TableName: string): string;
function GetArc(const Bases, TableName: string): string;

//procedure ErrorMessage(const ErrCode: Integer);
function KolToString(Value: string): string;
function StrToVal(const s: string): Double;
function Form(S: ShortString; N: integer): ShortString;
procedure fCreateDir(const DirName: string);
function fRemoveDir(const DirName: string):boolean;
procedure fCopyFile(const Source, Dest: string; Log: TLogFile = nil);
function UpdateFile(const FileName, SourceFileName: string; const ui: TUpdInd;
  const Prev: Integer;
  out NewVers: Integer; const Log: TLogFile = nil): Boolean;
procedure fCopyDir(Source, Dest: string);
function IsDigit(Sym: char): Boolean;
function ExcludeSymbol(const S: string; Ch: Char): string;
function DateToStrin(dDate: TDateTime): string;
function fDbiGetSysInfo(SysInfoList: TStringList): SYSInfo;
procedure fDbiGetSysConfig(var IdapiSysConfig: TStringList);
function fDateTimeToStr(const dDate: TDateTime): string;
function fDateToStr(dDate: TDateTime): string;
function fDbiGetSesInfo(): TStringList;
procedure Exec(const AppName, CommandLine: string; bWait: Boolean);
procedure SetLocalShare(Value: Boolean);
procedure SetBDEConfig(const NetDir: string; var PrivDir: string;
  const DBaseLang: string = 'DBWINUS0'; const PDoxLang: string = 'DBWINUS0');
procedure SetTableRussianLanguage(Table: TTable; const LDName: string =
  'ancyrr');
procedure SetDriver(const Driver, Param, Value: string; Ses: TSession);
function fAddNetDisk(nd: NetDisk): Boolean;
function fTryAddNetDisk(nd: NetDisk): Boolean;
procedure fDeleteFile(FileName: string);
function fSelectDir(var sStartDir: string): Boolean;
function BackupData(SourceName: string; NumBack: Byte = 1): string;
function fDateToMonth(const dDate: TDateTime): string;
procedure fDbiGetErrorInfo(ErrorCode: DbiResult; ErrorList: TStringList);
procedure fCreateIndex(t: TTable; FieldNames: ShortString);
procedure WriteText(ACanvas: TCanvas; ARect: TRect; DX, DY: Integer;
  const Text: string; Alignment: TAlignment);
function SetBit(Value: Integer; Bit: Integer): Integer;
function ResetBit(Value: Integer; Bit: Integer): Integer;
function Test(Value: Integer; Bit: Integer): Boolean;
function CheckUpdate(const FileName: string; const ui: TUpdInd; const Prev:
  Integer;
  out NewVers: Integer; const Log: TLogFile = nil): Boolean;

implementation

uses
  SysUtils, StrUtils, Windows, Dialogs, DateUtils, DB, ShlObj, ActiveX, Forms,
  CRCunit, Variants;

function IsDigit(Sym: char): Boolean;
begin
  Result := (Sym >= '0') and (Sym <= '9');
end;

function ConvertSI(SourceDBF, Dest: string): Integer;
var
  StrSI: string;
  si: ASU_SI;
  hFile, dwWritten: Cardinal;
begin
  try
    if not FileExists(SourceDBF) then
      raise Exception.Create('Файл "' + SourceDBF + '" не найден!');

    si := GetSI(SourceDBF);

    hFile := CreateFile(PChar(Dest), GENERIC_WRITE,
      FILE_SHARE_WRITE or FILE_SHARE_READ, nil,
      CREATE_ALWAYS, FILE_FLAG_WRITE_THROUGH, 0);
    if hFile = INVALID_HANDLE_VALUE then
      raise Exception.Create('Ошибка при создании файла ' + Dest + ': ' +
        SysErrorMessage(GetLastError));

    StrSI := Format('%s%.3u%9u', [si.si_date, si.si_np, si.si_countrec]);
    if si.si_countsi > 0 then
      StrSI := StrSI + Format('%3u', [si.si_countsi]) +
        Copy(si.si_text, 1, si.si_countsi);

    if not WriteFile(hFile, PChar(StrSI)^, Length(StrSI), dwWritten, nil) then
    begin
      raise Exception.Create('Ошибка при создании файла ' + Dest + ': ' +
        SysErrorMessage(GetLastError));
    end;
    CloseHandle(hFile);
  finally
    Result := Length(StrSI);
  end;
end;

procedure fDbiGetErrorInfo(ErrorCode: DbiResult; ErrorList: TStringList);
var
  ErrorInfo: DBIErrInfo;
  ErrorString: string;
begin
  if (ErrorCode <> dbiERR_NONE) then
  begin
    ErrorList.Clear;
    DbiGetErrorInfo(True, ErrorInfo);
    if (ErrorCode = ErrorInfo.iError) then
    begin
      ErrorList.Add('Error Number: ' + IntToStr(ErrorInfo.iError));
      ErrorList.Add('Error Code: ' + StrPas(ErrorInfo.szErrcode));
      if (StrLen(ErrorInfo.szContext[1]) <> 0) then

        ErrorList.Add('Error Context1: ' + StrPas(ErrorInfo.szContext[1]));
      if (StrLen(ErrorInfo.szContext[2]) <> 0) then
        ErrorList.Add('Error Context2: ' + StrPas(ErrorInfo.szContext[2]));
      if (StrLen(ErrorInfo.szContext[3]) <> 0) then
        ErrorList.Add('Error Context3: ' + StrPas(ErrorInfo.szContext[3]));
      if (StrLen(ErrorInfo.szContext[4]) <> 0) then
        ErrorList.Add('Error Context4: ' + StrPas(ErrorInfo.szContext[4]));
    end
    else
    begin
      SetLength(ErrorString, dbiMaxMsgLen + 1);
      Check(DbiGetErrorString(ErrorCode, PChar(ErrorString)));
      SetLength(ErrorString, StrLen(PChar(ErrorString)));
      ErrorList.Add(ErrorString);
    end;
  end;
end;

function PutSItoDB(const FileName: string; const si: ASU_SI): Integer;
var
  StrSI: string;
  DestSI: string;
  hFile, dwWritten: Cardinal;
begin
  try
    DestSI := ChangeFileExt(FileName, '.si');

    hFile := CreateFile(PChar(DestSI), GENERIC_WRITE,
      FILE_SHARE_WRITE or FILE_SHARE_READ, nil,
      CREATE_ALWAYS, FILE_FLAG_WRITE_THROUGH, 0);
    if hFile = INVALID_HANDLE_VALUE then
    begin
      raise Exception.Create('Ошибка при создании файла ' + DestSI + ': ' +
        SysErrorMessage(GetLastError));
    end;

    StrSI := Format('%s%.3u%9u', [si.si_date, si.si_np, si.si_countrec]);
    if si.si_countsi > 0 then
      StrSI := StrSI + Format('%3u', [si.si_countsi]) +
        Copy(si.si_text, 1, si.si_countsi);

    if not WriteFile(hFile, PChar(StrSI)^, Length(StrSI), dwWritten, nil) then
      raise Exception.Create('Ошибка при создании файла ' + DestSI + ': ' +
        SysErrorMessage(GetLastError));

    if hFile <> 0 then
      CloseHandle(hFile);
  finally
    Result := dwWritten;
  end;
end;

function GetSIfromDB(const FileName: string): ASU_SI;
var
  StrSI: string;
  si: ASU_SI;
  SourceSI: string;
  hFile, dwRead: Cardinal;
  iSize: Integer;
begin
  try
    SourceSI := ChangeFileExt(FileName, '.si');

    hFile := CreateFile(PChar(SourceSI), GENERIC_READ,
      FILE_SHARE_WRITE or FILE_SHARE_READ, nil,
      OPEN_EXISTING, FILE_FLAG_WRITE_THROUGH, 0);
    if hFile = INVALID_HANDLE_VALUE then
      raise Exception.Create('Ошибка при открытии файла ' + SourceSI + ': ' +
        SysErrorMessage(GetLastError));

    iSize := GetFileSize(hFile, nil);
    SetLength(StrSI, iSize);

    if not ReadFile(hFile, PChar(StrSI)^, iSize, dwRead, nil) then
      raise Exception.Create('Ошибка при чтении файла ' + SourceSI + ': ' +
        SysErrorMessage(GetLastError));
    CloseHandle(hFile);

    si.si_date := Copy(StrSI, 1, 8);
    si.si_np := StrToIntDef(Copy(StrSI, 9, 3), 0);
    si.si_countrec := StrToIntDef(Copy(StrSI, 12, 9), 0);
    si.si_countsi := StrToIntDef(Copy(StrSI, 21, 3), 0);

    if si.si_countsi > 0 then
      si.si_text := Copy(StrSI, 24, si.si_countsi);

  finally
    Result := si;
  end;
end;

function GetPath; //(const Bases, TableName: String) : String;
var
  Query: TQuery;
begin
  Query := TQuery.Create(nil);
  try
    Query.SQL.Text := 'select path from "' + Bases + '" where name="' +
      LowerCase(TableName) + '"';
    Query.Open;
    if Query['path'] = Null then
      raise Exception.Create('Путь к базе ' + TableName + ' не найден!');

    Result := CodASCII(Query.FieldByName('path').AsString);
  finally
    Query.Close;
    FreeAndNil(Query);
  end;
end;

function GetArc(const Bases, TableName: string): string;
var
  Query: TQuery;
begin
  Query := TQuery.Create(nil);
  try
    Query.SQL.Text := 'select arch from "' + Bases + '" where name="' +
      AnsiLowerCase(TableName) + '"';
    Query.Open;
    Result := CodASCII(Query.FieldByName('arch').AsString);
  finally
    Query.Close;
    FreeAndNil(Query);
  end;
end;

function SelectDirCB(Wnd: HWND; uMsg: UINT; lParam, lpData: LPARAM): Integer
  stdcall;
begin
  if (uMsg = BFFM_INITIALIZED) and (lpData <> 0) then
    SendMessage(Wnd, BFFM_SETSELECTION, Integer(True), lpdata);
  result := 0;
end;

function fSelectDir(var sStartDir: string): Boolean;
var
  bi: TBrowseInfo;
  ItemIDList: PItemIDList;
  ShellMalloc: IMalloc;
  szPath: array[0..MAX_PATH] of Char;
begin
  Result := False;
  if not DirectoryExists(sStartDir) then
    sStartDir := '';
  ZeroMemory(@bi, SizeOf(bi));

  if (ShGetMalloc(ShellMalloc) = S_OK) and (ShellMalloc <> nil) then
  begin
    bi.hwndOwner := Application.Handle;
    bi.pszDisplayName := szPath;
    bi.lpszTitle := 'Выберите каталог:';
    bi.ulFlags := BIF_RETURNONLYFSDIRS + BIF_NEWDIALOGSTYLE;
    if sStartDir <> '' then
    begin
      bi.lpfn := SelectDirCB;
      bi.lParam := Integer(PChar(sStartDir));
    end;
    ItemIDList := ShBrowseForFolder(bi);

    Result := ItemIDList <> nil;
    if Result then
    begin
      ShGetPathFromIDList(ItemIDList, szPath);
      ShellMalloc.Free(ItemIDList);
      sStartDir := szPath;
    end;
  end;
end;

procedure fCreateDir(const DirName: string);
var
  FullName, SearchPath: string;
  SlPos, OldSlPos: Integer;
  bRes: LongBool;
begin
  FullName := ExpandFileName(DirName);
  FullName := IncludeTrailingPathDelimiter(FullName);

  OldSlPos := PosEx('\', FullName);
  SlPos := PosEx('\', FullName, OldSlPos + 1);
  while (SlPos > 0) do
  begin
    SearchPath := Copy(FullName, 1, SlPos - 1);
    if not DirectoryExists(SearchPath) then
    begin
      bRes := CreateDir(SearchPath);
      if (not bRes) then
      begin
        raise Exception.Create('Ошибка при создании каталога ' + DirName + ': '
          +
          SysErrorMessage(GetLastError))

      end;
    end;
    OldSlPos := SlPos;
    Slpos := PosEx('\', FullName, OldSlPos + 1);
  end;
end;

procedure fCopyDir(Source, Dest: string);
var
  SR: TSearchRec;
begin
  Source := ExcludeTrailingPathDelimiter(Source);
  Dest := ExcludeTrailingPathDelimiter(Dest);
  if FindFirst(Source + '\*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name[1] <> '.') then
        if ((SR.Attr and faDirectory) <> 0) then
          fCopyDir(Source + '\' + SR.Name, Dest + '\' + SR.Name)
        else
          fCopyFile(Source + '\' + SR.Name, Dest + '\' + SR.Name);
    until FindNext(SR) <> 0;
    SysUtils.FindClose(SR);
  end;
end;

function fRemoveDir(const DirName: string):boolean;
var
  SR: TSearchRec;
  S: string;
begin
  S := ExcludeTrailingPathDelimiter(DirName);
  if (S = '') or (not(DirectoryExists(s))) then
   Result:=True
  else
  begin
    if FindFirst(S + '\*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name[1] <> '.') then
          if ((SR.Attr and faDirectory) <> 0) then
            fRemoveDir(S + '\' + SR.Name)
          else
          begin
            if not DeleteFile(PChar(S + '\' + SR.Name)) then
              raise Exception.Create('Ошибка при удалении каталога ' + DirName +
                ': ' +
                SysErrorMessage(GetLastError))
          end;
      until FindNext(SR) <> 0;
      SysUtils.FindClose(SR);
    end;
   // if not RemoveDirectory(PChar(DirName)) then
   //  if not (RemoveDir(DirName) then
   //   raise Exception.Create('Ошибка при удалении каталога ' + DirName + ': ' +
   //     SysErrorMessage(GetLastError))
   Result:=RemoveDirectory(PChar(S));
  end;
end;

procedure fCopyFile(const Source, Dest: string; Log: TLogFile = nil);
var
  DestDir: string;
begin
  if Dest[2] <> '\' then
  begin
    DestDir := ExtractFilePath(Dest);
    fCreateDir(DestDir);
  end;

  if Source = Dest then
    Exit;
  if not CopyFile(PChar(Source), PChar(Dest), False) then
    raise Exception.Create('Ошибка при копировании файла ' + Source + ': ' +
      SysErrorMessage(GetLastError))
  else if Log <> nil then
    Log.PutLine('Копируется файл: ' + ExpandUNCFileName(Source) + ' -> ' +
      Dest);
end;

function UpdateFile(const FileName, SourceFileName: string; const ui: TUpdInd;
  const Prev: Integer;
  out NewVers: Integer; const Log: TLogFile = nil): Boolean;
var
  Prev1: Integer;
begin
  Result := False;
  if Log <> nil then
    Log.PutLine('Обновление ' + FileName + '...');
  Assert(FileExists(SourceFileName), 'Исходный файл ' + SourceFileName +
    ' не существует!');

  try
    if ui = FileTime then
    begin
      NewVers := FileAge(SourceFileName);
      if Log <> nil then
        Log.PutLine('Исходный файл: ' + ExpandUNCFileName(SourceFileName) + ' ('
          +
          fDateTimeToStr(FileDateToDateTime(NewVers)) + ')')
    end
    else
    begin
      NewVers := GetSI(SourceFileName).si_np;
      if Log <> nil then
        Log.PutLine('Исходный файл: ' + ExpandUNCFileName(SourceFileName) +
          ' (НП - ' +
          Format('%.3d, ', [NewVers]) +
          fDateTimeToStr(FileDateToDateTime(FileAge(SourceFileName))) + ')');
    end;
  except
    if Log <> nil then
      Log.PutLine('Ошибка доступа к ' + SourceFileName + '!');
  end;

  if FileExists(FileName) then
  begin
    if ui = FileTime then
      Prev1 := FileAge(FileName)
    else
      Prev1 := GetSI(FileName).si_np;
  end
  else
    Prev1 := Prev;

  if NewVers <> Prev1 then
  begin
    fCopyFile(SourceFileName, FileName, Log);
    Result := True;
  end;
end;

function CheckUpdate(const FileName: string; const ui: TUpdInd; const Prev:
  Integer;
  out NewVers: Integer; const Log: TLogFile = nil): Boolean;
begin
  Result := False;
  if Log <> nil then
    Log.PutLine('Обновление ' + FileName + '...');
  Assert(FileExists(FileName), 'Файл ' + FileName + ' не существует!');

  try
    if ui = FileTime then
    begin
      NewVers := FileAge(FileName);
      if Log <> nil then
        Log.PutLine('Исходный файл: ' + ExpandUNCFileName(FileName) + ' (' +
          fDateTimeToStr(FileDateToDateTime(NewVers)) + ')')
    end
    else
    begin
      NewVers := GetSI(FileName).si_np;
      if Log <> nil then
        Log.PutLine('Исходный файл: ' + ExpandUNCFileName(FileName) + ' (НП - '
          +
          Format('%.3d, ', [NewVers]) +
          fDateTimeToStr(FileDateToDateTime(FileAge(FileName))) + ')');
    end;
  except
    if Log <> nil then
      Log.PutLine('Ошибка доступа к ' + FileName + '!');
  end;

  if NewVers <> Prev then
  begin
    if Log <> nil then
      Log.PutLine('Обнаружена новая версия файла ' +
        ExpandUNCFileName(FileName));
    Result := True;
  end;
end;

procedure Exec(const AppName, CommandLine: string; bWait: Boolean);
var
  si: TStartupInfo;
  pi: TProcessInformation;
  sd: TSecurityDescriptor;
  sa: TSecurityAttributes;
  AppName1: PChar;
begin
  InitializeSecurityDescriptor(@sd, SECURITY_DESCRIPTOR_REVISION);
  sa.nLength := SizeOf(TSecurityAttributes);
  sa.lpSecurityDescriptor := @sd;
  sa.bInheritHandle := True;
  ZeroMemory(@si, sizeof(si));

  if AppName = '' then
    AppName1 := nil
  else
    AppName1 := StrNew(PChar(AppName));

  if (not CreateProcess(AppName1, PChar(AppName1 + ' ' + CommandLine), @sa, @sa,
    False,
    NORMAL_PRIORITY_CLASS, nil, nil, si, pi)) then
    raise Exception.Create('Ошибка при запуске файла ' + AppName + ': ' +
      SysErrorMessage(GetLastError));
  if bWait then
  begin
    WaitForSingleObject(pi.hProcess, INFINITE);
  end;

end;

function StrToVal(const s: string): Double;
var
  code: Integer;
  sn: string;
begin
  sn := '';
  for code := 1 to Length(s) do
    if s[code] = '.' then
      sn := sn + ','
    else
      sn := sn + s[code];

  Result := StrToFloat(sn);
end;

function KolToString(Value: string): string;
var
  s, t: string;
  p, pp, i, k: integer;
const
  c: array[0..8, 0..9] of string = (
    ('', 'один ', 'два ', 'три ', 'четыре ', 'пять ', 'шесть ', 'семь ',
    'восемь ', 'девять '),
    ('', '', 'двадцать ', 'тридцать ', 'сорок ', 'пятьдесят ', 'шестьдесят ',
    'семьдесят ', 'восемьдесят ', 'девяносто '),
    ('', 'сто ', 'двести ', 'триста ', 'четыреста ', 'пятьсот ', 'шестьсот ',
    'семьсот ', 'восемьсот ', 'девятьсот '),
    ('тысяч ', 'одна тысяча ', 'две тысячи ', 'три тысячи ', 'четыре тысячи ',
    'пять тысяч ', 'шесть тысяч ', 'семь тысяч ', 'восемь тысяч ',
    'девять тысяч '),
    ('', '', 'двадцать ', 'тридцать ', 'сорок ', 'пятьдесят ', 'шестьдесят ',
    'семьдесят ', 'восемьдесят ', 'девяносто '),
    ('', 'сто ', 'двести ', 'триста ', 'четыреста ', 'пятьсот ', 'шестьсот ',
    'семьсот ', 'восемьсот ', 'девятьсот '),
    ('миллионов ', 'один миллион ', 'два миллиона ', 'три миллиона ',
    'четыре миллиона ', 'пять миллионов ', 'шесть миллионов ',
      'семь миллионов ',
    'восемь миллионов ', 'девять миллионов '),
    ('', '', 'двадцать ', 'тридцать ', 'сорок ', 'пятьдесят ', 'шестьдесят ',
    'семьдесят ', 'восемьдесят ', 'девяносто '),
    ('', 'сто ', 'двести ', 'триста ', 'четыреста ', 'пятьсот ', 'шестьсот ',
    'семьсот ', 'восемьсот ', 'девятьсот '));
  b: array[0..9] of string = ('десять ', 'одинадцать ', 'двенадцать ',
    'тринадцать ',
    'четырнадцать ', 'пятнадцать ', 'шестнадцать ', 'семнадцать ',
    'восемнадцать ',
    'девятнадцать ');
begin
  if Value = '' then
    Exit;
  try
    s := Value;
    if s = '0' then
      t := 'Ноль '
    else
    begin
      p := Length(s);
      pp := p;
      if p > 1 then
        if (s[p - 1] = '1') and (s[p] >= '0') then
        begin
          t := b[StrToInt(s[p])];
          Dec(pp, 2);
        end;
      i := pp;
      while i > 0 do
      begin
        if (i = p - 3) and (p > 4) then
          if s[p - 4] = '1' then
          begin
            t := b[strtoint(s[p - 3])] + 'тысяча ' + t;
            Dec(i, 2);
          end;
        if (i = p - 6) and (p > 7) then
          if s[p - 7] = '1' then
          begin
            t := b[strtoint(s[p - 6])] + 'миллионов ' + t;
            Dec(i, 2);
          end;
        if i > 0 then
        begin
          k := StrToInt(s[i]);
          t := c[p - i, k] + t;
          Dec(i);
        end;
      end;
    end;
    t[1] := AnsiUpperCase(Copy(t, 1, 1))[1];
    Result := t;
  except
    ShowMessage('Неверное число!');
  end;
end;

// вывод даты в виде "ХХ месяца"

function DateToStrin(dDate: TDateTime): string;
var
  sMonth, sDay: string;
begin
  DateTimeToString(sDay, 'd', dDate);

  DateTimeToString(sMonth, 'mmmmmm', dDate); // строка месяц
  sMonth := AnsiLowerCase(sMonth);
  if (MonthOf(dDate) = 3) or (MonthOf(dDate) = 8) then
    sMonth := sMonth + 'а'
  else
  begin
    sMonth := Copy(sMonth, 1, Length(sMonth) - 1);
    sMonth := sMonth + 'я';
  end;
  Result := sDay + ' ' + sMonth;
end;

// вывод даты в виде "месяц"

function fDateToMonth(const dDate: TDateTime): string;
var
  sMonth: string;
begin
  DateTimeToString(sMonth, 'mmmmmm', dDate); // строка месяц
  sMonth := AnsiLowerCase(sMonth);

  Result := sMonth;
end;

function fDateTimeToStr(const dDate: TDateTime): string;
var
  S: string;
begin
  DateTimeToString(S, 'dd.mm.yy hh:nn:ss', dDate);
  Result := S;
end;

function fDateToStr(dDate: TDateTime): string;
var
  S: string;
begin
  DateTimeToString(S, 'dd.mm.yy', dDate);
  Result := S;
end;
{
function Find(Ar : TIntArray; X : Integer) : Integer;
var
 i : Integer;
begin
 for i := 0 to Length(Ar)-1 do begin
   if (Ar[i] = X) then begin
     Result := i;
      Exit;
    end;
  end;
  Result := -1;
end;
}

function Form(S: ShortString; N: Integer): ShortString;
begin
  try
    Result := Format('%.' + IntToStr(N) + 'u', [Round(StrToVal(S))]);
  except
    on E: EConvertError do
      raise Exception.Create('Ошибка преобразования числа ' + S + ': ' +
        E.Message);
  end;
end;

function ExcludeSymbol(const S: string; Ch: Char): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
    if S[i] <> Ch then
      Result := Result + S[i];
end;

function fDbiGetSysInfo(SysInfoList: TStringList): SYSInfo;
begin
  Check(DbiGetSysInfo(Result));
  if (SysInfoList <> nil) then
  begin
    with SysInfoList do
    begin
      Clear;
      Add(Format('BUFFER SPACE=%d', [Result.iBufferSpace]));
      Add(Format('HEAP SPACE=%d', [Result.iHeapSpace]));
      Add(Format('DRIVERS=%d', [Result.iDrivers]));
      Add(Format('CLIENTS=%d', [Result.iClients]));
      Add(Format('SESSIONS=%d', [Result.iSessions]));
      Add(Format('DATABASES=%d', [Result.iDatabases]));
      Add(Format('CURSORS=%d', [Result.iCursors]));
    end;
  end;
end;

function fDbiGetSesInfo(): TStringList;
var
  SInfo: SESInfo;
  slRes: TStringList;
begin
  Check(DbiGetSesInfo(SInfo));
  slRes := TStringList.Create;
  with slRes do
  begin
    Clear;
    Add(Format('SESSION ID=%d', [SInfo.iSession]));
    Add(Format('SESSION NAME=%s', [SInfo.szName]));
    Add(Format('DATABASES=%d', [SInfo.iDatabases]));
    Add(Format('CURSORS=%d', [SInfo.iCursors]));
    Add(Format('LOCK WAIT=%d', [SInfo.iLockWait]));
    Add(Format('NET DIR=%s', [SInfo.szNetDir]));
    Add(Format('PRIVATE DIR=%s', [SInfo.szPrivDir]));
  end;
  Result := slRes;
  ShowMessage(Result.Text);
end;

procedure fDbiGetSysConfig(var IdapiSysConfig: TStringList);
var
  SysConfigInfo: SYSConfig;
begin
  Check(DbiGetSysConfig(SysConfigInfo));
  if SysConfigInfo.bLocalShare then
    IdapiSysConfig.Add('Local Share: ON')
  else
    IdapiSysConfig.Add('Local Share: OFF');
  IdapiSysConfig.Add('Network Type: ' + StrPas(SysConfigInfo.szNetType));
  IdapiSysConfig.Add('User Name: ' + StrPas(SysConfigInfo.szUserName));
  IdapiSysConfig.Add('Ini File: ' + StrPas(SysConfigInfo.szIniFile));
  IdapiSysConfig.Add('Language Driver: ' + StrPas(SysConfigInfo.szLangDriver));
end;

procedure SetDriver(const Driver, Param, Value: string; Ses: TSession);
var
  SL: TStringList;
begin
  SL := TStringList.Create;
  SL.Add(Param + '=' + Value);

  Ses.ModifyDriver(Driver, SL);
  FreeAndNil(SL);
end;

procedure SetBDEConfig(const NetDir: string; var PrivDir: string;
  const DBaseLang: string = 'DBWINUS0'; const PDoxLang: string = 'DBWINUS0');
var
  Temp: string;
  MyList: TStringList;
begin
  MyList := TStringList.Create;

  Session.ConfigMode := cmSession;
  Session.Active := False;
  Session.AutoSessionName := True;

  SetLength(Temp, 256);
  SetLength(Temp, GetTempPath(255, PChar(Temp)));

  MyList.Clear;
  MyList.Add('LANGDRIVER=' + DBaseLang);
  MyList.Add('LEVEL=4');
  Session.ModifyDriver('DBASE', MyList);

  MyList.Clear;
  MyList.Add('LANGDRIVER=' + PDoxLang);
  Session.ModifyDriver('PARADOX', MyList);
  FreeAndNil(MyList);
  Session.NetFileDir := NetDir;
  if PrivDir = '' then
  begin
    PrivDir := Temp + IntToStr(Round(Time() * 864000));
    fCreateDir(PrivDir);
    Session.PrivateDir := PrivDir;
  end;

  //  Session.Active := True;
end;

{ Устанавливает русский LANGDRIVER для таблицы BDE (Paradox или dBASE)}
{ Таблица должна уже существовать на диске
Если вы создаете таблицу динамически,
не забудьте вызвать Table.CreateTable }

procedure SetTableRussianLanguage(Table: TTable; const LDName: string =
  'ancyrr');
var
  Props: CURProps;
  hDb: hDBIDb;
  TableDesc: CRTblDesc;
  OptDesc: FLDDesc;
  OptData: array[0..250] of Char;
  S: string;
  // Define propertly table type & codepage from list below
    // LDName = 'ancyrr';   // Paradox ANSI Cyrillic
    // LDName = 'cyrr';  // Paradox Cyrr 866
    // LDName = 'DB866ru0'; // dBASE RUS cp866
begin
  // Get handle (if table still not opened)
  Table.Open;
  // Get the table properties to determine table type...
  Check(DbiGetCursorProps(Table.Handle, Props));

  // Blank out the structure...
  FillChar(TableDesc, sizeof(TableDesc), 0);
  FillChar(OptDesc, SizeOf(OptDesc), #0);
  // Get the database handle from the table's cursor handle...

  Check(DbiGetObjFromObj(hDBIObj(Table.Handle), objDATABASE, hDBIObj(hDb)));

  { If table name contain cyrillic or other native character, convert name to OEM }

  SetLength(S, Length(Table.TableName));
  CharToOEM(PChar(Table.TableName), @S[1]);

  // Put the table name in the table descriptor...
  StrPCopy(TableDesc.szTblName, S {Table.TableName});
  // Put the table type in the table descriptor...
  StrPCopy(TableDesc.szTblType, Props.szTableType);
  // Set the Pack option in the table descriptor to TRUE...

  StrCopy(OptDesc.szName, 'LANGDRIVER');
  OptDesc.iLen := Length(LDName) + 1;
  TableDesc.iOptParams := 1;
  TableDesc.pfldOptParams := @OptDesc;
  TableDesc.pOptData := @OptData;
  StrPCopy(OptData, LDName);

  // Close the table so the restructure can complete...
  Table.Close;
  // Call DbiDoRestructure...
  Check(DbiDoRestructure(hDb, 1, @TableDesc, nil, nil, nil, False));
end;

procedure UpdateCFGFile(path, item, value: string);
var
  h: hDbiCur;
  pCfgDes: pCFGDesc;
  pPath: array[0..127] of char;
begin
  StrPCopy(pPath, Path);
  Check(DbiOpenCfgInfoList(nil, dbiREADWRITE, cfgPersistent, pPath, h));
  GetMem(pCfgDes, sizeof(CFGDesc));
  try
    FillChar(pCfgDes^, sizeof(CFGDesc), #0);
    while (DbiGetNextRecord(h, dbiWRITELOCK, pCfgDes, nil) = DBIERR_NONE) do
    begin
      if StrPas(pCfgDes^.szNodeName) = item then
      begin
        StrPCopy(pCfgDes^.szValue, value);
        Check(DbiModifyRecord(h, pCfgDes, True));
      end;
    end;
  finally
    FreeMem(pCfgDes, sizeof(CFGDesc));
    if (h <> nil) then
      DbiCloseCursor(h);
  end;
end;

procedure BdeError(ResultCode: Word);
begin
  if ResultCode <> 0 then
    raise Exception.CreateFmt('BDE ошибка %x', [ResultCode]);
end;

procedure SetLocalShare(Value: Boolean);
var
  //	dbRes: DBIResult;
  //  sMes: String;
  Env: DbiEnv;
  szWorkDir: DBIPATH; // array[0..DBIMAXPATHLEN] of char;
begin
  //  UpdateCfgFile('\SYSTEM\INIT', 'LOCAL SHARE', BoolToStr(Value, True));
  GetCurrentDirectory(260, szWorkDir);
  lstrcpy(Env.szWorkDir, szWorkDir);
  Env.bForceLocalInit := False;
  BdeError(DbiInit(@Env));
  {  if dbRes <> DBIERR_NONE	then begin
      case dbRes of
        DBIERR_MULTIPLEINIT : sMes := 'Попытка повторной инициализации BDE';
        2	: sMes := 'Доступ запрещен, рабочий каталог создан во временной директории!';
        else
          sMes := 'Неизвестная ошибка BDE!';
      end;
    end; }
end;

function fAddNetDisk(nd: NetDisk): Boolean;
var
  nw: TNetResource;
  Err: DWORD;
begin
  ZeroMemory(@nw, SizeOf(nw));
  nw.dwType := RESOURCETYPE_DISK;
  nw.lpLocalName := PChar(Let[nd]);
  nw.lpRemoteName := PChar(Conn[nd]);

  Err := WNetAddConnection2(nw, nil, nil, 0);
  if Err <> NO_ERROR then
  begin
    raise Exception.Create('Ошибка при подключении сетевого диска ' +
      nw.lpRemoteName +
      ': ' + SysErrorMessage(GetLastError));
    Result := False;
  end
  else
    Result := True;
end;

function fTryAddNetDisk(nd: NetDisk): Boolean;
var
  nw: TNetResource;
  Err: DWORD;
begin
  ZeroMemory(@nw, SizeOf(nw));
  nw.dwType := RESOURCETYPE_DISK;
  nw.lpLocalName := PChar(Let[nd]);
  nw.lpRemoteName := PChar(Conn[nd]);

  Err := WNetAddConnection2(nw, nil, nil, 0);
  Result := (Err = NO_ERROR);
end;

procedure fCreateIndex(t: TTable; FieldNames: ShortString);
var
  bActive: Boolean;
begin
  with t do
  begin
    bActive := Active;
    if bActive then
      Close;
    Exclusive := True;
    Open;
    AddIndex('', FieldNames, [ixPrimary]);

    Close;
    Exclusive := False;
    if bActive then
      Open;
  end;
end;

procedure fDeleteFile(FileName: string);
begin
  if FileExists(FileName) then
    if not Windows.DeleteFile(PChar(FileName)) then
      raise Exception.Create('Ошибка при удалении файла ' + FileName + ': ' +
        SysErrorMessage(GetLastError))
end;

function BackupData(SourceName: string; NumBack: Byte = 1): string;
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

procedure WriteText(ACanvas: TCanvas; ARect: TRect; DX, DY: Integer;
  const Text: string; Alignment: TAlignment);
const
  AlignFlags: array[TAlignment] of Integer =
    (DT_LEFT or DT_WORDBREAK or DT_EXPANDTABS or DT_NOPREFIX,
    DT_RIGHT or DT_WORDBREAK or DT_EXPANDTABS or DT_NOPREFIX,
    DT_CENTER or DT_WORDBREAK or DT_EXPANDTABS or DT_NOPREFIX);
var
  B, R: TRect;
  Left: Integer;
  I: Word;
begin
  I := ColorToRGB(ACanvas.Brush.Color);
  if GetNearestColor(ACanvas.Handle, I) = I then
  begin { Use ExtTextOut for solid colors }
    case Alignment of
      taLeftJustify:
        Left := ARect.Left + DX;
      taRightJustify:
        Left := ARect.Right - ACanvas.TextWidth(Text) - 3;
    else { taCenter }
      Left := ARect.Left + (ARect.Right - ARect.Left) shr 1
        - (ACanvas.TextWidth(Text) shr 1);
    end;
    ExtTextOut(ACanvas.Handle, Left, ARect.Top + DY, ETO_OPAQUE or
      ETO_CLIPPED, @ARect, PChar(Text), Length(Text), nil);
  end
  else
  begin { Use FillRect and Drawtext for dithered colors }
    DrawBitmap.Canvas.Lock;
    try
      with DrawBitmap, ARect do { Use offscreen bitmap to eliminate flicker and }
      begin { brush origin tics in painting/scrolling.    }
        Width := Max(Width, Right - Left);
        Height := Max(Height, Bottom - Top);
        R := Rect(DX, DY, Right - Left - 1, Bottom - Top - 1);
        B := Rect(0, 0, Right - Left, Bottom - Top);
      end;
      with DrawBitmap.Canvas do
      begin
        Font := ACanvas.Font;
        Font.Color := ACanvas.Font.Color;
        Brush := ACanvas.Brush;
        Brush.Style := bsSolid;
        FillRect(B);
        SetBkMode(Handle, TRANSPARENT);
        DrawText(Handle, PChar(Text), Length(Text), R, AlignFlags[Alignment]);
      end;
      ACanvas.CopyRect(ARect, DrawBitmap.Canvas, B);
    finally
      DrawBitmap.Canvas.Unlock;
    end;
  end;
end;

function SetBit(Value: Integer; Bit: Integer): Integer;
begin
  Result := Value or (1 shl Bit);
end;

function ResetBit(Value: Integer; Bit: Integer): Integer;
begin
  Result := Value and (not (1 shl Bit));
end;

function Test(Value: Integer; Bit: Integer): Boolean;
begin
  Result := (Value and (1 shl Bit) <> 0);
end;

end.


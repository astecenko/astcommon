unit MsAD;

interface
uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls;
const
  netapi32lib = 'netapi32.dll';
  NERR_Success = NO_ERROR;

type
  // Структура для получения информации о рабочей станции
  PWkstaInfo100 = ^TWkstaInfo100;
  TWkstaInfo100 = record
    wki100_platform_id: DWORD;
    wki100_computername: PWideChar;
    wki100_langroup: PWideChar;
    wki100_ver_major: DWORD;
    wki100_ver_minor: DWORD;
  end;

  // Итруктура для определения DNS имени контролера домена
  TDomainControllerInfoA = record
    DomainControllerName: LPSTR;
    DomainControllerAddress: LPSTR;
    DomainControllerAddressType: ULONG;
    DomainGuid: TGUID;
    DomainName: LPSTR;
    DnsForestName: LPSTR;
    Flags: ULONG;
    DcSiteName: LPSTR;
    ClientSiteName: LPSTR;
  end;
  PDomainControllerInfoA = ^TDomainControllerInfoA;

  // Структура для отображения пользователей
  PNetDisplayUser = ^TNetDisplayUser;
  TNetDisplayUser = record
    usri1_name: LPWSTR;
    usri1_comment: LPWSTR;
    usri1_flags: DWORD;
    usri1_full_name: LPWSTR;
    usri1_user_id: DWORD;
    usri1_next_index: DWORD;
  end;

  // Структура для отображения рабочих станций
  PNetDisplayMachine = ^TNetDisplayMachine;
  TNetDisplayMachine = record
    usri2_name: LPWSTR;
    usri2_comment: LPWSTR;
    usri2_flags: DWORD;
    usri2_user_id: DWORD;
    usri2_next_index: DWORD;
  end;

  // Структура для отображения групп
  PNetDisplayGroup = ^TNetDisplayGroup;
  TNetDisplayGroup = record
    grpi3_name: LPWSTR;
    grpi3_comment: LPWSTR;
    grpi3_group_id: DWORD;
    grpi3_attributes: DWORD;
    grpi3_next_index: DWORD;
  end;

  // Структура для отображения пользователей принадлежащих группе
  // или групп в которые входит пользователь
  PGroupUsersInfo0 = ^TGroupUsersInfo0;
  TGroupUsersInfo0 = record
    grui0_name: LPWSTR;
  end;

var
  CurrentDomainName: string;

  // Функции которые предоставят нам возможность получения информации
function NetApiBufferFree(Buffer: Pointer): DWORD; stdcall;
external netapi32lib;
function NetWkstaGetInfo(ServerName: PWideChar; Level: DWORD;
  Bufptr: Pointer): DWORD; stdcall; external netapi32lib;
function NetGetDCName(ServerName: PWideChar; DomainName: PWideChar;
  var Bufptr: PWideChar): DWORD; stdcall; external netapi32lib;
function DsGetDcName(ComputerName, DomainName: PChar; DomainGuid: PGUID;
  SiteName: PChar; Flags: ULONG;
  var DomainControllerInfo: PDomainControllerInfoA): DWORD; stdcall;
external netapi32lib name 'DsGetDcNameA';
function NetQueryDisplayInformation(ServerName: PWideChar; Level: DWORD;
  Index: DWORD; EntriesRequested: DWORD; PreferredMaximumLength: DWORD;
  var ReturnedEntryCount: DWORD; SortedBuffer: Pointer): DWORD; stdcall;
external netapi32lib;
function NetGroupGetUsers(ServerName: PWideChar; GroupName: PWideChar; Level:
  DWORD;
  var Bufptr: Pointer; PrefMaxLen: DWORD; var EntriesRead: DWORD;
  var TotalEntries: DWORD; ResumeHandle: PDWORD): DWORD; stdcall;
external netapi32lib;
function NetUserGetGroups(ServerName: PWideChar; UserName: PWideChar; Level:
  DWORD;
  var Bufptr: Pointer; PrefMaxLen: DWORD; var EntriesRead: DWORD;
  var TotalEntries: DWORD): DWORD; stdcall; external netapi32lib;
function NetEnumerateTrustedDomains(ServerName: PWideChar;
  DomainNames: PWideChar): DWORD; stdcall; external netapi32lib;
procedure ConvertSidToStringSid(SID: PSID; var StringSid: LPSTR); stdcall;
external advapi32 name 'ConvertSidToStringSidA';

function GetCurrentUserName: string;
function GetCurrentComputerName: string;
function GetDomainController(const DomainName: string): string;
function GetDNSDomainName(const DomainName: string): string;
function EnumAllTrustedDomains(const ControllerName: string; List: TStrings):
  Boolean;
function EnumAllUsers(const ControllerName:string; lvUsers: TListView): Boolean;
function EnumAllGroups(lvGroups: TListView; ledControllerName: TLabeledEdit):
  Boolean;
function EnumAllWorkStation(const ControllerName:string; lvWorkStation:TListView): Boolean;
function GetSID(const SecureObject,DNSName: String): String;
function GetAllGroupUsers(const GroupName,ControllerName: String; List:TStrings): Boolean;
function GetAllUserGroups(const UserName,ControllerName: String; List:TStrings): Boolean;

(*
Вариант использования
// Просто вызываем все функции подряд (не делал проверок на результат функций)
  ledUserName.Text := GetCurrentUserName;
  ledCompName.Text := GetCurrentComputerName;
  ledDomainName.Text := CurrentDomainName;
  ledControllerName.Text := GetDomainController(CurrentDomainName);
  // Единственно, если нет контролера домена, то дальше определять бесполезно
  if ledControllerName.Text = '' then Exit;
  ledDNSName.Text := GetDNSDomainName(CurrentDomainName);
  EnumAllTrustedDomains;
  EnumAllUsers;
  EnumAllWorkStation;
  EnumAllGroups;
*)

implementation

//  Данная функция получает информацию о всех группах присутствующих в домене
// =============================================================================

function EnumAllGroups(lvGroups: TListView; ledControllerName: TLabeledEdit):
  Boolean;
var
  Tmp, Info: PNetDisplayGroup;
  I, CurrIndex, EntriesRequest,
    PreferredMaximumLength,
    ReturnedEntryCount: Cardinal;
  Error: DWORD;
begin
  CurrIndex := 0;
  repeat
    Info := nil;
    // NetQueryDisplayInformation возвращает информацию только о 100-а записях
    // для того чтобы получить всю информацию используется третий параметр,
    // передаваемый функции, который определяет с какой записи продолжать
    // вывод информации
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayGroup);
    ReturnedEntryCount := 0;
    // Для выполнения функции, в нее нужно передать DNS имя контролера домена
    // (или его IP адрес), с которого мы хочем получить информацию
    // Для получения информации о группах используется структура NetDisplayGroup
    // и ее идентификатор 3 (тройка) во втором параметре
    Error := NetQueryDisplayInformation(StringToOleStr(ledControllerName.Text),
      3, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // При безошибочном выполнении фунции будет результат либо
    // 1. NERR_Success - все записи возвращены
    // 2. ERROR_MORE_DATA - записи возвращены, но остались еще и нужно вызывать функцию повторно
    if Error in [NERR_Success, ERROR_MORE_DATA] then
      try
        Tmp := Info;
        // Выводим информацию которую вернула функция в структуру
        for I := 0 to ReturnedEntryCount - 1 do
        begin
          with lvGroups.Items.Add do
          begin
            Caption := Tmp^.grpi3_name; // Имя группы
            SubItems.Add(Tmp^.grpi3_comment); // Комментарий
        //    SubItems.Add(GetSID(Caption)); // SID группы
            // Запоминаем индекс с которым будем вызывать повторно функцию (если нужно)
            CurrIndex := Tmp^.grpi3_next_index;
          end;
          Inc(Tmp);
        end;
      finally
        // Чтобы небыло утечки ресурсов, освобождаем память занятую функцией под структуру
        NetApiBufferFree(Info);
      end;
    // Если результат выполнения функции ERROR_MORE_DATA - вызываем функцию повторно
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // Ну и возвращаем результат всего что мы тут накодили
  Result := Error = NERR_Success;
end;

//  Без комментариев
// =============================================================================

function GetCurrentUserName: string;
var
  Size: Cardinal;
begin
  Size := MAXCHAR;
  SetLength(Result, Size);
  GetUserName(PChar(Result), Size);
  SetLength(Result, Size);
end;

//  Получаем имя компьютера и имя домена
// =============================================================================

function GetCurrentComputerName: string;
var
  Info: PWkstaInfo100;
  Error: DWORD;
begin
  // А для этого мы воспользуемся следующей функцией
  Error := NetWkstaGetInfo(nil, 100, @Info);
  if Error <> 0 then
    raise Exception.Create(SysErrorMessage(Error));
  // Как видно, вызов который возвращает обычную структуру, из которой и прочитаем, все что нужно

  // А именно имя компьютера в сети
  Result := Info^.wki100_computername;
  // И где он находиться
  CurrentDomainName := info^.wki100_langroup;
end;

//  Ну тут без комментариев - просто получаем имя контроллера домена
// =============================================================================

function GetDomainController(const DomainName: string): string;
var
  Domain: WideString;
  Server: PWideChar;
begin
  Domain := StringToOleStr(DomainName);
  if NetGetDCName(nil, @Domain[1], Server) = NERR_Success then
    try
      Result := Server;
    finally
      NetApiBufferFree(Server);
    end;
end;

//  Получаем DNS имя контроллера домена
// =============================================================================

function GetDNSDomainName(const DomainName: string): string;
const
  DS_IS_FLAT_NAME = $00010000;
  DS_RETURN_DNS_NAME = $40000000;
var
  GUID: PGUID;
  DomainControllerInfo: PDomainControllerInfoA;
begin
  GUID := nil;
  // Для большинства операций нам потребуется IP адрес контроллера домена
  // или его DNS имя, которое мы получим вот так:
  if DsGetDcName(nil, PChar(CurrentDomainName), GUID, nil,
    DS_IS_FLAT_NAME or DS_RETURN_DNS_NAME, DomainControllerInfo) = NERR_Success
      then
    // Параметры которые мы передаем означают:
    // DS_IS_FLAT_NAME - передаем просто имя домена
    // DS_RETURN_DNS_NAME - ждем получения DNS имени
    try
      Result := DomainControllerInfo^.DomainControllerName;
        // Результат собсно тут...
    finally
      // Склероз это болезнь, ее нужно лечить...
      NetApiBufferFree(DomainControllerInfo);
    end;
end;

//  Данная функция получает информацию о всех доверенных доменах
// =============================================================================

function EnumAllTrustedDomains(const ControllerName: string; List: TStrings):
  Boolean;
var
  Tmp, DomainList: PWideChar;
begin
  // Используем недокументированную функцию NetEnumerateTrustedDomains
  // (только не пойму, с какого перепуга она не документирована?)
  // Тут все очень просто, на вход имя контролера домена, ны выход - список доверенных доменов
  Result := NetEnumerateTrustedDomains(StringToOleStr(ControllerName),
    @DomainList) = NERR_Success;
  // Если вызов функции успешен, то...
  if Result then
    try
      Tmp := DomainList;
      while Length(Tmp) > 0 do
      begin
        List.Add(Tmp); // Банально выводим список на экран
        Tmp := Tmp + Length(Tmp) + 1;
      end;
    finally
      // Не забываем про память
      NetApiBufferFree(DomainList);
    end;
end;

//  Данная функция получает информацию о всех пользователях присутствующих в домене
// =============================================================================
function EnumAllUsers(const ControllerName:string; lvUsers: TListView): Boolean;
var
  Tmp, Info: PNetDisplayUser;
  I, CurrIndex, EntriesRequest,
  PreferredMaximumLength,
  ReturnedEntryCount: Cardinal;
  Error: DWORD;
begin
  CurrIndex := 0;
  repeat
    Info := nil;
    // NetQueryDisplayInformation возвращает информацию только о 100-а записях
    // для того чтобы получить всю информацию используется третий параметр,
    // передаваемый функции, который определяет с какой записи продолжать
    // вывод информации
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayUser);
    ReturnedEntryCount := 0;
    // Для выполнения функции, в нее нужно передать DNS имя контролера домена
    // (или его IP адрес), с которого мы хочем получить информацию
    // Для получения информации о пользователях используется структура NetDisplayUser
    // и ее идентификатор 1 (единица) во втором параметре
    Error := NetQueryDisplayInformation(StringToOleStr(ControllerName), 1, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // При безошибочном выполнении фунции будет результат либо
    // 1. NERR_Success - все записи возвращены
    // 2. ERROR_MORE_DATA - записи возвращены, но остались еще и нужно вызывать функцию повторно
    if Error in [NERR_Success, ERROR_MORE_DATA] then
    try
      Tmp := Info;
      // Выводим информацию которую вернула функция в структуру
      for I := 0 to ReturnedEntryCount - 1 do
      begin
        with lvUsers.Items.Add do
        begin
          Caption := Tmp^.usri1_name;          // Имя пользователя
          SubItems.Add(Tmp^.usri1_comment);    // Комментарий
       //   SubItems.Add(GetSID(Caption));       // Его SID
          // Запоминаем индекс с которым будем вызывать повторно функцию (если нужно)
          CurrIndex := Tmp^.usri1_next_index;
        end;
        Inc(Tmp);
      end;
    finally
      // Грохаем выделенную при вызове NetQueryDisplayInformation память
      NetApiBufferFree(Info);
    end;
  // Если результат выполнения функции ERROR_MORE_DATA
  // (т.е. есть еще данные) - вызываем функцию повторно
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // Ну и возвращаем результат всего что мы тут накодили
  Result := Error = NERR_Success;
end;

//  Данная функция получает информацию о всех рабочих станциях присутствующих в домене
//  Вообщето так делать немного не верно, дело в том что рабочие станции могут
//  присутствовать в списке не только те, которые завел сисадмин (но для демки сойдет и так)
// =============================================================================
function EnumAllWorkStation(const ControllerName:string; lvWorkStation:TListView): Boolean;
var
  Tmp, Info: PNetDisplayMachine;
  I, CurrIndex, EntriesRequest,
  PreferredMaximumLength,
  ReturnedEntryCount: Cardinal;
  Error: DWORD;
begin
  CurrIndex := 0;
  repeat
    Info := nil;
    // NetQueryDisplayInformation возвращает информацию только о 100-а записях
    // для того чтобы получить всю информацию используется третий параметр,
    // передаваемый функции, который определяет с какой записи продолжать
    // вывод информации
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayMachine);
    ReturnedEntryCount := 0;
    // Для выполнения функции, в нее нужно передать DNS имя контролера домена
    // (или его IP адрес), с которого мы хочем получить информацию
    // Для получения информации о рабочих станциях используется структура NetDisplayMachine
    // и ее идентификатор 2 (двойка) во втором параметре
    Error := NetQueryDisplayInformation(StringToOleStr(ControllerName), 2, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // При безошибочном выполнении фунции будет результат либо
    // 1. NERR_Success - все записи возвращены
    // 2. ERROR_MORE_DATA - записи возвращены, но остались еще и нужно вызывать функцию повторно
    if Error in [NERR_Success, ERROR_MORE_DATA] then
    try
      Tmp := Info;
      // Выводим информацию которую вернула функция в структуру
      for I := 0 to ReturnedEntryCount - 1 do
      begin
        with lvWorkStation.Items.Add do
        begin
          Caption := Tmp^.usri2_name;          // Имя рабочей станции
          SubItems.Add(Tmp^.usri2_comment);    // Комментарий
     //     SubItems.Add(GetSID(Caption));       // Её SID
          // Запоминаем индекс с которым будем вызывать повторно функцию (если нужно)
          CurrIndex := Tmp^.usri2_next_index;
        end;
        Inc(Tmp);
      end;
    finally
      // Дабы небыло утечек
      NetApiBufferFree(Info);
    end;
  // Если результат выполнения функции ERROR_MORE_DATA
  // (т.е. есть еще данные) - вызываем функцию повторно
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // Ну и возвращаем результат всего что мы тут накодили
  Result := Error = NERR_Success;
end;

//  Не знаю зачем добавил это, ну раз добавил - получение SID объекта
//  Без комментариев...
// =============================================================================
function GetSID(const SecureObject,DNSName: String): String;
var
  SID: PSID;
  StringSid: PChar;
  ReferencedDomain: String;
  cbSid, cbReferencedDomain:DWORD;
  peUse: SID_NAME_USE;
begin
  cbSID := 128;
  cbReferencedDomain := 16;
  GetMem(SID, cbSid);
  try
    SetLength(ReferencedDomain, cbReferencedDomain);
    if LookupAccountName(PChar(DNSName),
      PChar(SecureObject), SID, cbSid,
      @ReferencedDomain[1], cbReferencedDomain, peUse) then
    begin
      ConvertSidToStringSid(SID, StringSid);
      Result := StringSid;
    end;
  finally
    FreeMem(SID);
  end;
end;

//  Довольно простая функция, возвращает только имена пользователей принадлезжащих группе
// =============================================================================
function GetAllGroupUsers(const GroupName,ControllerName: String; List:TStrings): Boolean;
var
  Tmp, Info: PGroupUsersInfo0;
  PrefMaxLen, EntriesRead,
  TotalEntries, ResumeHandle: DWORD;
  I: Integer;
begin
  // На вход подается список который мы будем заполнять
//  lbInfo.Items.Clear;
  // Обязательная инициализация
  ResumeHandle := 0;
  PrefMaxLen := DWORD(-1);
  // Выполняем
  Result := NetGroupGetUsers(StringToOleStr(ControllerName),
    StringToOleStr(GroupName), 0, Pointer(Info), PrefMaxLen,
    EntriesRead, TotalEntries, @ResumeHandle) = NERR_Success;
  // Смотрим результат...
  if Result then
  try
    Tmp := Info;
    for I := 0 to EntriesRead - 1 do
    begin
      List.Add(Tmp^.grui0_name); // Банально выводим результат из структуры
      Inc(Tmp);
    end;
  finally
    // Не забываем, ибо может быть склероз
    NetApiBufferFree(Info);
  end;
end;

//  Аналогично предыдущей функции (заметьте - структура таже)
// =============================================================================
function GetAllUserGroups(const UserName,ControllerName: String; List:TStrings): Boolean;
var
  Tmp, Info: PGroupUsersInfo0;
  PrefMaxLen, EntriesRead,
  TotalEntries: DWORD;
  I: Integer;
begin
  PrefMaxLen := DWORD(-1);
  Result := NetUserGetGroups(StringToOleStr(ControllerName),
    StringToOleStr(UserName), 0, Pointer(Info), PrefMaxLen,
    EntriesRead, TotalEntries) = NERR_Success;
  if Result then
  try
    Tmp := Info;
    for I := 0 to EntriesRead - 1 do
    begin
      List.Add(Tmp^.grui0_name);
      Inc(Tmp);
    end;
  finally
    NetApiBufferFree(Info);
  end;
end;

end.


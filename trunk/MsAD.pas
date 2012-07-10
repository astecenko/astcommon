unit MsAD;

interface
uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, ComCtrls;
const
  netapi32lib = 'netapi32.dll';
  NERR_Success = NO_ERROR;

type
  // ��������� ��� ��������� ���������� � ������� �������
  PWkstaInfo100 = ^TWkstaInfo100;
  TWkstaInfo100 = record
    wki100_platform_id: DWORD;
    wki100_computername: PWideChar;
    wki100_langroup: PWideChar;
    wki100_ver_major: DWORD;
    wki100_ver_minor: DWORD;
  end;

  // ��������� ��� ����������� DNS ����� ���������� ������
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

  // ��������� ��� ����������� �������������
  PNetDisplayUser = ^TNetDisplayUser;
  TNetDisplayUser = record
    usri1_name: LPWSTR;
    usri1_comment: LPWSTR;
    usri1_flags: DWORD;
    usri1_full_name: LPWSTR;
    usri1_user_id: DWORD;
    usri1_next_index: DWORD;
  end;

  // ��������� ��� ����������� ������� �������
  PNetDisplayMachine = ^TNetDisplayMachine;
  TNetDisplayMachine = record
    usri2_name: LPWSTR;
    usri2_comment: LPWSTR;
    usri2_flags: DWORD;
    usri2_user_id: DWORD;
    usri2_next_index: DWORD;
  end;

  // ��������� ��� ����������� �����
  PNetDisplayGroup = ^TNetDisplayGroup;
  TNetDisplayGroup = record
    grpi3_name: LPWSTR;
    grpi3_comment: LPWSTR;
    grpi3_group_id: DWORD;
    grpi3_attributes: DWORD;
    grpi3_next_index: DWORD;
  end;

  // ��������� ��� ����������� ������������� ������������� ������
  // ��� ����� � ������� ������ ������������
  PGroupUsersInfo0 = ^TGroupUsersInfo0;
  TGroupUsersInfo0 = record
    grui0_name: LPWSTR;
  end;

var
  CurrentDomainName: string;

  // ������� ������� ����������� ��� ����������� ��������� ����������
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
������� �������������
// ������ �������� ��� ������� ������ (�� ����� �������� �� ��������� �������)
  ledUserName.Text := GetCurrentUserName;
  ledCompName.Text := GetCurrentComputerName;
  ledDomainName.Text := CurrentDomainName;
  ledControllerName.Text := GetDomainController(CurrentDomainName);
  // �����������, ���� ��� ���������� ������, �� ������ ���������� ����������
  if ledControllerName.Text = '' then Exit;
  ledDNSName.Text := GetDNSDomainName(CurrentDomainName);
  EnumAllTrustedDomains;
  EnumAllUsers;
  EnumAllWorkStation;
  EnumAllGroups;
*)

implementation

//  ������ ������� �������� ���������� � ���� ������� �������������� � ������
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
    // NetQueryDisplayInformation ���������� ���������� ������ � 100-� �������
    // ��� ���� ����� �������� ��� ���������� ������������ ������ ��������,
    // ������������ �������, ������� ���������� � ����� ������ ����������
    // ����� ����������
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayGroup);
    ReturnedEntryCount := 0;
    // ��� ���������� �������, � ��� ����� �������� DNS ��� ���������� ������
    // (��� ��� IP �����), � �������� �� ����� �������� ����������
    // ��� ��������� ���������� � ������� ������������ ��������� NetDisplayGroup
    // � �� ������������� 3 (������) �� ������ ���������
    Error := NetQueryDisplayInformation(StringToOleStr(ledControllerName.Text),
      3, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // ��� ������������ ���������� ������ ����� ��������� ����
    // 1. NERR_Success - ��� ������ ����������
    // 2. ERROR_MORE_DATA - ������ ����������, �� �������� ��� � ����� �������� ������� ��������
    if Error in [NERR_Success, ERROR_MORE_DATA] then
      try
        Tmp := Info;
        // ������� ���������� ������� ������� ������� � ���������
        for I := 0 to ReturnedEntryCount - 1 do
        begin
          with lvGroups.Items.Add do
          begin
            Caption := Tmp^.grpi3_name; // ��� ������
            SubItems.Add(Tmp^.grpi3_comment); // �����������
        //    SubItems.Add(GetSID(Caption)); // SID ������
            // ���������� ������ � ������� ����� �������� �������� ������� (���� �����)
            CurrIndex := Tmp^.grpi3_next_index;
          end;
          Inc(Tmp);
        end;
      finally
        // ����� ������ ������ ��������, ����������� ������ ������� �������� ��� ���������
        NetApiBufferFree(Info);
      end;
    // ���� ��������� ���������� ������� ERROR_MORE_DATA - �������� ������� ��������
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // �� � ���������� ��������� ����� ��� �� ��� ��������
  Result := Error = NERR_Success;
end;

//  ��� ������������
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

//  �������� ��� ���������� � ��� ������
// =============================================================================

function GetCurrentComputerName: string;
var
  Info: PWkstaInfo100;
  Error: DWORD;
begin
  // � ��� ����� �� ������������� ��������� ��������
  Error := NetWkstaGetInfo(nil, 100, @Info);
  if Error <> 0 then
    raise Exception.Create(SysErrorMessage(Error));
  // ��� �����, ����� ������� ���������� ������� ���������, �� ������� � ���������, ��� ��� �����

  // � ������ ��� ���������� � ����
  Result := Info^.wki100_computername;
  // � ��� �� ����������
  CurrentDomainName := info^.wki100_langroup;
end;

//  �� ��� ��� ������������ - ������ �������� ��� ����������� ������
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

//  �������� DNS ��� ����������� ������
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
  // ��� ����������� �������� ��� ����������� IP ����� ����������� ������
  // ��� ��� DNS ���, ������� �� ������� ��� ���:
  if DsGetDcName(nil, PChar(CurrentDomainName), GUID, nil,
    DS_IS_FLAT_NAME or DS_RETURN_DNS_NAME, DomainControllerInfo) = NERR_Success
      then
    // ��������� ������� �� �������� ��������:
    // DS_IS_FLAT_NAME - �������� ������ ��� ������
    // DS_RETURN_DNS_NAME - ���� ��������� DNS �����
    try
      Result := DomainControllerInfo^.DomainControllerName;
        // ��������� ������ ���...
    finally
      // ������� ��� �������, �� ����� ������...
      NetApiBufferFree(DomainControllerInfo);
    end;
end;

//  ������ ������� �������� ���������� � ���� ���������� �������
// =============================================================================

function EnumAllTrustedDomains(const ControllerName: string; List: TStrings):
  Boolean;
var
  Tmp, DomainList: PWideChar;
begin
  // ���������� ������������������� ������� NetEnumerateTrustedDomains
  // (������ �� �����, � ������ �������� ��� �� ���������������?)
  // ��� ��� ����� ������, �� ���� ��� ���������� ������, �� ����� - ������ ���������� �������
  Result := NetEnumerateTrustedDomains(StringToOleStr(ControllerName),
    @DomainList) = NERR_Success;
  // ���� ����� ������� �������, ��...
  if Result then
    try
      Tmp := DomainList;
      while Length(Tmp) > 0 do
      begin
        List.Add(Tmp); // �������� ������� ������ �� �����
        Tmp := Tmp + Length(Tmp) + 1;
      end;
    finally
      // �� �������� ��� ������
      NetApiBufferFree(DomainList);
    end;
end;

//  ������ ������� �������� ���������� � ���� ������������� �������������� � ������
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
    // NetQueryDisplayInformation ���������� ���������� ������ � 100-� �������
    // ��� ���� ����� �������� ��� ���������� ������������ ������ ��������,
    // ������������ �������, ������� ���������� � ����� ������ ����������
    // ����� ����������
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayUser);
    ReturnedEntryCount := 0;
    // ��� ���������� �������, � ��� ����� �������� DNS ��� ���������� ������
    // (��� ��� IP �����), � �������� �� ����� �������� ����������
    // ��� ��������� ���������� � ������������� ������������ ��������� NetDisplayUser
    // � �� ������������� 1 (�������) �� ������ ���������
    Error := NetQueryDisplayInformation(StringToOleStr(ControllerName), 1, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // ��� ������������ ���������� ������ ����� ��������� ����
    // 1. NERR_Success - ��� ������ ����������
    // 2. ERROR_MORE_DATA - ������ ����������, �� �������� ��� � ����� �������� ������� ��������
    if Error in [NERR_Success, ERROR_MORE_DATA] then
    try
      Tmp := Info;
      // ������� ���������� ������� ������� ������� � ���������
      for I := 0 to ReturnedEntryCount - 1 do
      begin
        with lvUsers.Items.Add do
        begin
          Caption := Tmp^.usri1_name;          // ��� ������������
          SubItems.Add(Tmp^.usri1_comment);    // �����������
       //   SubItems.Add(GetSID(Caption));       // ��� SID
          // ���������� ������ � ������� ����� �������� �������� ������� (���� �����)
          CurrIndex := Tmp^.usri1_next_index;
        end;
        Inc(Tmp);
      end;
    finally
      // ������� ���������� ��� ������ NetQueryDisplayInformation ������
      NetApiBufferFree(Info);
    end;
  // ���� ��������� ���������� ������� ERROR_MORE_DATA
  // (�.�. ���� ��� ������) - �������� ������� ��������
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // �� � ���������� ��������� ����� ��� �� ��� ��������
  Result := Error = NERR_Success;
end;

//  ������ ������� �������� ���������� � ���� ������� �������� �������������� � ������
//  �������� ��� ������ ������� �� �����, ���� � ��� ��� ������� ������� �����
//  �������������� � ������ �� ������ ��, ������� ����� �������� (�� ��� ����� ������ � ���)
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
    // NetQueryDisplayInformation ���������� ���������� ������ � 100-� �������
    // ��� ���� ����� �������� ��� ���������� ������������ ������ ��������,
    // ������������ �������, ������� ���������� � ����� ������ ����������
    // ����� ����������
    EntriesRequest := 100;
    PreferredMaximumLength := EntriesRequest * SizeOf(TNetDisplayMachine);
    ReturnedEntryCount := 0;
    // ��� ���������� �������, � ��� ����� �������� DNS ��� ���������� ������
    // (��� ��� IP �����), � �������� �� ����� �������� ����������
    // ��� ��������� ���������� � ������� �������� ������������ ��������� NetDisplayMachine
    // � �� ������������� 2 (������) �� ������ ���������
    Error := NetQueryDisplayInformation(StringToOleStr(ControllerName), 2, CurrIndex,
      EntriesRequest, PreferredMaximumLength, ReturnedEntryCount, @Info);
    // ��� ������������ ���������� ������ ����� ��������� ����
    // 1. NERR_Success - ��� ������ ����������
    // 2. ERROR_MORE_DATA - ������ ����������, �� �������� ��� � ����� �������� ������� ��������
    if Error in [NERR_Success, ERROR_MORE_DATA] then
    try
      Tmp := Info;
      // ������� ���������� ������� ������� ������� � ���������
      for I := 0 to ReturnedEntryCount - 1 do
      begin
        with lvWorkStation.Items.Add do
        begin
          Caption := Tmp^.usri2_name;          // ��� ������� �������
          SubItems.Add(Tmp^.usri2_comment);    // �����������
     //     SubItems.Add(GetSID(Caption));       // Ÿ SID
          // ���������� ������ � ������� ����� �������� �������� ������� (���� �����)
          CurrIndex := Tmp^.usri2_next_index;
        end;
        Inc(Tmp);
      end;
    finally
      // ���� ������ ������
      NetApiBufferFree(Info);
    end;
  // ���� ��������� ���������� ������� ERROR_MORE_DATA
  // (�.�. ���� ��� ������) - �������� ������� ��������
  until Error in [NERR_Success, ERROR_ACCESS_DENIED];
  // �� � ���������� ��������� ����� ��� �� ��� ��������
  Result := Error = NERR_Success;
end;

//  �� ���� ����� ������� ���, �� ��� ������� - ��������� SID �������
//  ��� ������������...
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

//  �������� ������� �������, ���������� ������ ����� ������������� �������������� ������
// =============================================================================
function GetAllGroupUsers(const GroupName,ControllerName: String; List:TStrings): Boolean;
var
  Tmp, Info: PGroupUsersInfo0;
  PrefMaxLen, EntriesRead,
  TotalEntries, ResumeHandle: DWORD;
  I: Integer;
begin
  // �� ���� �������� ������ ������� �� ����� ���������
//  lbInfo.Items.Clear;
  // ������������ �������������
  ResumeHandle := 0;
  PrefMaxLen := DWORD(-1);
  // ���������
  Result := NetGroupGetUsers(StringToOleStr(ControllerName),
    StringToOleStr(GroupName), 0, Pointer(Info), PrefMaxLen,
    EntriesRead, TotalEntries, @ResumeHandle) = NERR_Success;
  // ������� ���������...
  if Result then
  try
    Tmp := Info;
    for I := 0 to EntriesRead - 1 do
    begin
      List.Add(Tmp^.grui0_name); // �������� ������� ��������� �� ���������
      Inc(Tmp);
    end;
  finally
    // �� ��������, ��� ����� ���� �������
    NetApiBufferFree(Info);
  end;
end;

//  ���������� ���������� ������� (�������� - ��������� ����)
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


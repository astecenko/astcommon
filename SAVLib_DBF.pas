unit SAVLib_DBF;

interface
uses VKDBFDataSet, VKDBFNTX, VKDBFIndex, VKDBFSorters;
procedure ClearStructDBF(Table1: TVKDBFNTX);
procedure InitOpenDBF(Table1: TVKDBFNTX; const FileName: string; const
  AccessMode: Integer =  64; VersionDBF: xBaseVersion = xClipper;
  LockProtokol: LockProtocolType = lpClipperLock;
  LobLockProtokol: LockProtocolType = lpClipperLock);
function Poisk(Table1: TVKDBFNTX; PoiskFields, PoiskKey: string; LowNo: Integer
  = 1; HighNo: Integer = 1): Boolean;

implementation

uses SysUtils, Classes, Controls, IniFiles, SAVLib, Math;

procedure ClearStructDBF(Table1: TVKDBFNTX);
begin
  Table1.Active := False;
  Table1.Indexes.CloseAll;
  Table1.DBFFieldDefs.Clear;
  Table1.FieldDefs.Clear;
  Table1.DBFIndexDefs.Clear;
  Table1.Indexes.Clear;
end;

procedure InitOpenDBF(Table1: TVKDBFNTX; const FileName: string; const
  AccessMode: Integer = 64; VersionDBF: xBaseVersion = xClipper;
  LockProtokol: LockProtocolType = lpClipperLock;
  LobLockProtokol: LockProtocolType = lpClipperLock);
begin
  Table1.AccessMode.AccessMode := AccessMode;
  Table1.DbfVersion := VersionDBF;
  Table1.LockProtocol := LockProtokol;
  Table1.LobLockProtocol := LobLockProtokol;
  Table1.OEM := True;
  Table1.TrimCType := True;
  Table1.DBFFileName := FileName;
end;

function Poisk(Table1: TVKDBFNTX; PoiskFields, PoiskKey: string; LowNo: Integer
  = 1; HighNo: Integer = 1): Boolean;
var
  LowNomer, HighNomer, mid, i: Integer;
  slist: TStringList;
  sKey: string;

  function GetFieldSumm: string;
  var
    i1: Byte;
  begin
    Result := '';
    for i1 := 0 to slist.Count - 1 do
      Result := Result + Table1.FieldByName(slist[i1]).AsString;
  end;

begin
  slist := TStringList.Create;
  slist.Text := stringReplace(PoiskFields, ';', #13#10, [rfReplaceAll]);
  HighNomer := IfThen(HighNo = 1, Table1.RecordCount, HighNo);
  LowNomer := LowNo;
  //функция AnsiCompareStr сравнивает 2 строки без учета регистра
  // возвращает значение -1 если S1<S2, 0 если S1=S2, 1 если S1>S2
  Table1.SetTmpRecord(LowNomer);
  sKey := GetFieldSumm;
  if AnsiCompareText(sKey, PoiskKey) > 0 then
    Result := False
  else
  begin
    Table1.SetTmpRecord(HighNomer);
    sKey := GetFieldSumm;
    if AnsiCompareText(sKey, PoiskKey) < 0 then
      Result := False
    else
    begin
      while (HighNomer - LowNomer) > 1 do
      begin
        mid := (LowNomer + HighNomer) div 2;
        Table1.SetTmpRecord(mid);
        sKey := GetFieldSumm;
        if AnsiCompareText(sKey, PoiskKey) >= 0 then
          HighNomer := mid
        else
          LowNomer := mid;
      end;
      Table1.SetTmpRecord(LowNomer);
      sKey := GetFieldSumm;
      i := LowNomer;
      if AnsiCompareText(sKey, PoiskKey) < 0 then
      begin
        Table1.SetTmpRecord(HighNomer);
        sKey := GetFieldSumm;
        i := HighNomer;
      end;
      Table1.CloseTmpRecord;
      if AnsiCompareText(sKey, PoiskKey) = 0 then
      begin
        Result := True;
        Table1.RecNo := i;
      end
      else
        Result := False;
    end;
  end;
  FreeAndNil(slist);
end;

end.


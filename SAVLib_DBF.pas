unit SAVLib_DBF;

interface
uses VKDBFDataSet, VKDBFNTX, VKDBFIndex, VKDBFSorters, Classes;
type
  TFieldIndexArray = array[1..25] of Integer;

  PDBFFielDefin = ^TDBFFielDefin;
  TDBFFielDefin = record
    FieldName: string;
    FieldType: AnsiChar;
    FieldLength: Word;
  end;

  TDBFFieldList = class(TList)
  private
    function Get(Index: Integer): PDBFFielDefin;
  public
    destructor Destroy; override;
    function Add(Value: PDBFFielDefin): Integer;
    function AddField(const FieldName: string; const FieldType: AnsiChar; const
      FieldLength: Word): Integer;
    function CreateTable(const DBFFileName: string): boolean;
    function SaveToFile(const FileName: string; const ItemDelimiter: string =
      ';'; const FieldDelimiter: string = #10#13): boolean;
    property Items[Index: Integer]: PDBFFielDefin read Get; default;
  end;

procedure ClearStructDBF(Table1: TVKDBFNTX);
procedure InitOpenDBF(Table1: TVKDBFNTX; const FileName: string; const
  AccessMode: Integer = 64; VersionDBF: xBaseVersion = xClipper;
  LockProtokol: LockProtocolType = lpClipperLock;
  LobLockProtokol: LockProtocolType = lpClipperLock);
function Poisk(Table1: TVKDBFNTX; const PoiskFields, PoiskKey: string; const
  LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;

function FastPoisk(Table1: TVKDBFNTX; FieldList: TStringList; const PoiskKey:
  string; const LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;
function QuickPoisk(Table1: TVKDBFNTX; const FieldList: TFieldIndexArray; const
  FieldCount: Integer; const PoiskKey: string; const LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;

implementation

uses SysUtils, Controls, IniFiles, Math;

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

function Poisk(Table1: TVKDBFNTX; const PoiskFields, PoiskKey: string; const
  LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;
var
  LowNomer, HighNomer, mid, i: Integer;
  slist: TStringList;
  sKey: string;
  t: Integer;

  function GetFieldSumm: string;
  var
    i1, n: Byte;
  begin
    Result := '';
    n := pred(slist.Count);
    for i1 := 0 to n do
      Result := Result + Table1.FieldByName(slist[i1]).AsString;
  end;

begin
  if Table1.RecordCount = 0 then
    Result := False
  else
  begin
    slist := TStringList.Create;
    slist.Text := stringReplace(PoiskFields, ';', #13#10, [rfReplaceAll]);
    HighNomer := IfThen(HighNo = 1, Table1.RecordCount, HighNo);
    LowNomer := LowNo;
    //функция AnsiCompareStr сравнивает 2 строки без учета регистра
    // возвращает значение -1 если S1<S2, 0 если S1=S2, 1 если S1>S2
    Table1.SetTmpRecord(LowNomer);
    sKey := GetFieldSumm;
    t := AnsiCompareText(sKey, PoiskKey);
    if t > 0 then
      Result := False
    else if t = 0 then
    begin
      Result := True;
      Table1.CloseTmpRecord;
      Table1.RecNo := LowNomer;
    end
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
end;

{
Более быстрая реализация поиска
ускорение за счет использования 1го передаваемого в функцию TStringList с полями в строках
и использования AnsiCompareStr вместо AnsiCompareText
}

function FastPoisk(Table1: TVKDBFNTX; FieldList: TStringList; const PoiskKey:
  string; const LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;
var
  LowNomer, HighNomer, mid, i: Integer;
  sKey: string;
  t: Integer;

  function GetFieldSumm: string;
  var
    i1, n: Byte;
  begin
    Result := '';
    n := pred(FieldList.Count);
    for i1 := 0 to n do
      Result := Result + Table1.FieldByName(FieldList[i1]).AsString;
  end;

begin
  if Table1.RecordCount = 0 then
    Result := False
  else
  begin
    HighNomer := IfThen(HighNo = 1, Table1.RecordCount, HighNo);
    LowNomer := LowNo;
    //функция AnsiCompareStr сравнивает 2 строки без учета регистра
    // возвращает значение -1 если S1<S2, 0 если S1=S2, 1 если S1>S2
    Table1.SetTmpRecord(LowNomer);
    sKey := GetFieldSumm;
    t := AnsiCompareStr(sKey, PoiskKey);
    if t > 0 then
      Result := False
    else if t = 0 then
    begin
      Result := True;
      Table1.CloseTmpRecord;
      Table1.RecNo := LowNomer;
    end
    else
    begin
      Table1.SetTmpRecord(HighNomer);
      sKey := GetFieldSumm;
      if AnsiCompareStr(sKey, PoiskKey) < 0 then
        Result := False
      else
      begin
        while (HighNomer - LowNomer) > 1 do
        begin
          mid := (LowNomer + HighNomer) div 2;
          Table1.SetTmpRecord(mid);
          sKey := GetFieldSumm;
          if AnsiCompareStr(sKey, PoiskKey) >= 0 then
            HighNomer := mid
          else
            LowNomer := mid;
        end;
        Table1.SetTmpRecord(LowNomer);
        sKey := GetFieldSumm;
        i := LowNomer;
        if AnsiCompareStr(sKey, PoiskKey) < 0 then
        begin
          Table1.SetTmpRecord(HighNomer);
          sKey := GetFieldSumm;
          i := HighNomer;
        end;
        Table1.CloseTmpRecord;
        if AnsiCompareStr(sKey, PoiskKey) = 0 then
        begin
          Result := True;
          Table1.RecNo := i;
        end
        else
          Result := False;
      end;
    end;
  end;
end;

{
Наиболее быстрая реализация поиска
}

function QuickPoisk(Table1: TVKDBFNTX; const FieldList: TFieldIndexArray; const
  FieldCount: Integer; const PoiskKey: string; const LowNo: Integer
  = 1; const HighNo: Integer = 1): Boolean;
var
  LowNomer, HighNomer, mid, i: Integer;
  sKey: string;
  t: Integer;

  function GetFieldSumm: string;
  var
    i1: Byte;
  begin
    Result := '';
    for i1 := 1 to FieldCount do
      Result := Result + Table1.Fields[FieldList[i1]].AsString;
  end;

begin
  if Table1.RecordCount = 0 then
    Result := False
  else
  begin
    if HighNo = 1 then
      HighNomer := Table1.RecordCount
    else
      HighNomer := HighNo;
    LowNomer := LowNo;
    //функция AnsiCompareStr сравнивает 2 строки без учета регистра
    // возвращает значение -1 если S1<S2, 0 если S1=S2, 1 если S1>S2
    Table1.SetTmpRecord(LowNomer);
    sKey := GetFieldSumm;
    t := AnsiCompareStr(sKey, PoiskKey);
    if t > 0 then
      Result := False
    else if t = 0 then
    begin
      Result := True;
      Table1.CloseTmpRecord;
      Table1.RecNo := LowNomer;
    end
    else
    begin
      Table1.SetTmpRecord(HighNomer);
      sKey := GetFieldSumm;
      if AnsiCompareStr(sKey, PoiskKey) < 0 then
        Result := False
      else
      begin
        while (HighNomer - LowNomer) > 1 do
        begin
          mid := (LowNomer + HighNomer) div 2;
          Table1.SetTmpRecord(mid);
          sKey := GetFieldSumm;
          if AnsiCompareStr(sKey, PoiskKey) >= 0 then
            HighNomer := mid
          else
            LowNomer := mid;
        end;
        Table1.SetTmpRecord(LowNomer);
        sKey := GetFieldSumm;
        i := LowNomer;
        if AnsiCompareStr(sKey, PoiskKey) < 0 then
        begin
          Table1.SetTmpRecord(HighNomer);
          sKey := GetFieldSumm;
          i := HighNomer;
        end;
        Table1.CloseTmpRecord;
        if AnsiCompareStr(sKey, PoiskKey) = 0 then
        begin
          Result := True;
          Table1.RecNo := i;
        end
        else
          Result := False;
      end;
    end;
  end;
end;

{ TDBFFieldList }

function TDBFFieldList.Add(Value: PDBFFielDefin): Integer;
begin
  Result := inherited Add(Value);
end;

function TDBFFieldList.AddField(const FieldName: string;
  const FieldType: AnsiChar; const FieldLength: Word): Integer;
var
  MyRec: PDBFFielDefin;
begin
  GetMem(MyRec, SizeOf(TDBFFielDefin));
  MyRec.FieldName := FieldName;
  MyRec.FieldType := FieldType;
  MyRec.FieldLength := FieldLength;
  Add(MyRec);
end;

function TDBFFieldList.CreateTable(const DBFFileName: string): boolean;
var
  Table0: TVKDBFNTX;
  i, n: integer;
begin
  Table0 := TVKDBFNTX.Create(nil);
  InitOpenDBF(Table0, DBFFileName, 18);
  n := Count - 1;
  for i := 0 to n do
    with Table0.DBFFieldDefs.Add as TVKDBFFieldDef do
    begin
      Name := Self[i].FieldName;
      field_type := Self[i].FieldType;
      len := Self[i].FieldLength;
    end;
  Result := True;
  try
    Table0.CreateTable;
  except
    Result := False;
  end;
  FreeAndNil(Table0);
end;

destructor TDBFFieldList.Destroy;
var
  i, n: Integer;
begin
  n := Count - 1;
  for i := 0 to n do
    FreeMem(Items[i]);
  inherited;
end;

function TDBFFieldList.Get(Index: Integer): PDBFFielDefin;
begin
  Result := PDBFFielDefin(inherited Get(Index));
end;

function TDBFFieldList.SaveToFile(const FileName, ItemDelimiter,
  FieldDelimiter: string): boolean;
var
  List1: TStringList;
  i, n: integer;
  s: string;
begin
  s := '';
  n := Count - 1;
  Result := True;
  List1 := TStringList.Create;
  for i := 0 to n do
    s := s + Self[i].FieldName + ItemDelimiter + Self[i].FieldType +
      ItemDelimiter + IntToStr(Self[i].FieldLength) + FieldDelimiter;
  List1.Text := s;
  try
    List1.SaveToFile(FileName);
  except
    Result := False;
  end;
  FreeAndNil(List1);
end;

end.


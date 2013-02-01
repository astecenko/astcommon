{���������� ������� ������� ��� ������ � ������� ������� DBF

  http://www.nevz.com/

  Copyright NEVZ 1936-2011

  @Author(�������� �.�.)
  @Version 2009/10/05}
unit ASU_DBF;

interface

{$WARN SYMBOL_PLATFORM OFF}

uses Windows, Forms;

type
  MyData = record
    luYear: byte;
    luMes: byte;
    luDay: byte;
  end;
  //��������� DBF
  DBF_HEAD = record
    //��� ����� 03 - ���� DBF
    dbf_id: char;
    //���� ���������� ��������� �� �� ��
    last_update: MyData;
    //����� ��������� ������
    last_rec: Longint;
    //��������, � �������� ���������� �������������� ������, ������� �� ����� �����
    data_offset: word;
    //������ ������ ������
    rec_size: word;
    //���������� �� 32 ���� #00
    filler: array[1..20] of char;
  end;
  //���� ������� DBF
  DBF_FIELD = record
    //��� ����
    field_name: array[1..11] of char;
    //���
    field_type: char;
    //��������
    dummy: array[1..4] of char;
    //���������� �������� ��� CHAR ��� ����� ������ ��� N
    len: byte;
    //���������� ���������� ��������
    dec: byte;
    //���������� �� 32 ���� #00
    filler: array[1..14] of char;
  end;
  //��� ��� ������ ������ ���������
  TMyNP = 0..999;
  //������ ���������� ��������� ����������
  ASU_SI = record
    //��� ������� �� �� ���
    si_name: string[6];
    //���� �������� �� �� ���
    si_date: string[8];
    //����� ��������� �������
    si_np: TMyNP;
    //����� ������������� ����������
    si_countsi: 0..255;
    //����� ��������� ���������� ������������ �������������
    si_text: string[255];
    //���������� ������� � �����
    si_countrec: integer;
  end;

  {������� ��������� DBF �����
   @returns(@true ���� �������, @false ���� �����)}
function ASU_DBF_ClearFields(): Boolean;

{���������� ���� � ������� DBF
@param(fn ��� ����)
@param(ft ��� ����)
@param(l ����� ����)
@param(d ���������� ����� � �������)}
procedure ASU_DBF_AddField(fn: string; ft: char; l, d: word);

{�������� ������� DBF �� ������ ����� ���������� �  DBF_Fields
@returns(@true ���� ������� ������� �������, @false �����)
@param(dir ��� ����� �������)
@seealso(DBF_Fields)}
function ASU_DBF_CreateTable(dir: string): Boolean;

{������ ��������� ���������� � ���� DBF
@returns(@true ���� �������)
@param(dir ��� �����)
@param(SI ��������� ���������� (SI))}
function PutSI(dir: string; SI: ASU_SI): Boolean;

{������ ��������� ���������� �� ����� DBF
@returns(��������� ����������)
@param(dir ��� �����)}
function GetSI(dir: string): ASU_SI; //������ ��������� ����������

{������� �� WIN � DOS ���������
@param(strWin ������ � ��������� WIN1251)
@returns(������ � ��������� OEM866)}
function CodDOS(strWin: string): string; //������� �� WIN � DOS ���������

{������� �� DOS � WIN ���������
@param(strWin ������ � ��������� OEM866)
@returns(������ � ��������� WIN1251)}
function CodASCII(strWin: string): string; //������� �� DOS � WIN  ���������

var

  //���������� ��� �������� �������� �����
  DBF_Fields: array of DBF_FIELD;

implementation

uses SysUtils, DateUtils, Math;

function ASU_DBF_ClearFields(): Boolean;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //������� ��������� �����
  ////////////////////////////////////////////////////////////////////////////////
  try
    DBF_Fields := nil;
    Result := True;
  except
    Result := False;
  end;
end;

procedure ASU_DBF_AddField(fn: string; ft: char; l, d: word);
var
  i: integer;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //���������� ����
  ////////////////////////////////////////////////////////////////////////////////
  SetLength(DBF_Fields, Length(DBF_Fields) + 1); //���������� �������

  //���������� �������� ����
  with DBF_Fields[High(DBF_Fields)] do
  begin
    for i := 1 to length(fn) do
      field_name[i] := fn[i];
    field_type := ft;
    for i := 1 to 4 do
      dummy[i] := #00;
    len := l;
    dec := d;
    for i := 1 to 14 do
      filler[i] := #00;
  end;
end;

function ASU_DBF_CreateTable(dir: string): Boolean;
var
  new_DBF_HEAD: DBF_HEAD;
  DBF_File: file;
  i: integer;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //�������� �������
  ////////////////////////////////////////////////////////////////////////////////
  FileMode := 2;
  try //��������� ���������� (���� ���������)
    AssignFile(DBF_File, dir); //������ ����� ����� � �������� ����������
    Rewrite(DBF_File, 32); //������� ����� ��� ������

    with new_DBF_HEAD do
    begin
      dbf_id := #03; //��������� ��� dbf �����
      last_update.luYear := YearOf(Date) - 2000;
        //��������� ���� � ����������� �������
      last_update.luMes := MonthOf(Date); //��������� ������
      last_update.luDay := DayOf(Date); //��������� ���
      last_rec := 0; //������� ��� ����� ����
      data_offset := 32 + 32 * Length(DBF_Fields) + 3;
        //�������� �� ������ = ��������� + 32*���-�� ����� + ������� ����� �������� ���������
      rec_size := 0; //���������
      for i := 0 to High(DBF_Fields) do
        rec_size := rec_size + DBF_Fields[i].len;
          //������ ������ = ����� �������� ����� + 1 (�������������� ����)
      rec_size := rec_size + 1;
      for i := 1 to 20 do
        filler[i] := #00;
    end;

    BlockWrite(DBF_File, new_DBF_HEAD, 1); // ���������� ���������
    for i := 0 to High(DBF_Fields) do
      BlockWrite(DBF_File, DBF_Fields[i], 1); // ���������� ����
    CloseFile(DBF_File);

    // ���������� ����� �����
    Reset(DBF_File, 1); //�������� ����� ��� ������
    Seek(DBF_File, new_DBF_HEAD.data_offset - 3);
    BlockWrite(DBF_File, #13#00#26, 3);
    Result := True;
  finally //��� ����� ��������� - ���� �������
    CloseFile(DBF_File);
  end;
end;

function PutSI(dir: string; SI: ASU_SI): boolean;
var
  blok: array[1..32] of char;
  DBF_File: file;
  j, i, rez: integer;
  ch: char;
  fStartSI: Boolean; //������� ������ ��������� ����������
  np1, countsi1: string;
begin
  ////////////////////////////////////////////////////////////////////////////////
  // ������ ��������� ����������
  ////////////////////////////////////////////////////////////////////////////////
  try
    SI.si_name := CodDOS(SI.si_name); //�������������� � DOS ���������
    SI.si_text := CodDOS(SI.si_text);

    FileMode := 2;
    AssignFile(DBF_File, dir); //������ ����� ����� � �������� ����������
    Reset(DBF_File, 1); //������� ����� ��� ������
    fStartSI := False;
    rez := 4;

    //���������� ������ ��������� ����������
    while (not fStartSI) and (rez = 4) do
      // 1 ������� ��� ����������� ������ ��. ���, ������ ��� ����������� ����� �����
    begin
      BlockRead(DBF_File, blok, 4, rez); //������� �� 4 ������� �� SIA#00
      if (blok[1] = 'S') and (blok[2] = 'I') and (blok[3] = 'A') and (blok[4] =
        #00) then
        fStartSI := True
      else
        for j := 1 to 7 do
          BlockRead(DBF_File, blok, 4, rez);
            //������� ��� 7 ���� �� 4 ������� - �� ������ ��������� 32 ����
    end;

    if fStartSI then //���� ������� ������ ��������� ����������
    begin
      // 0123456789ABCDEF
      // SIA?���-��??????       ���-�� ��� ���� ������
      // ??��������������       ��������-���� ��������  ���-���������  ���-������ ��������� ����������
      //������ ����� �����
      for j := 1 to 6 do
        BlockWrite(DBF_File, si.si_name[j], 1);

      BlockRead(DBF_File, blok, 4); //���������� 8 ��������
      BlockRead(DBF_File, blok, 4);

      //������ ����
      for j := 1 to 8 do
        BlockWrite(DBF_File, si.si_date[j], 1);

      //������ ������ ���������
      np1 := format('%3.3d', [si.si_np]);
      for j := 1 to 3 do
        BlockWrite(DBF_File, np1[j], 1);

      //������ ������ ������������� ����������
      countsi1 := format('%3.3d', [si.si_countsi]);
      for j := 1 to 3 do
        BlockWrite(DBF_File, countsi1[j], 1);
      // ������ ��������� ����������
      // 0123456789ABCDEF
      // SIB?kkkkkkk??kkk     k - ����� ��� ������ ��������� ����������
      // ??kkkkkkkkkkkkkk
      j := 1; //������� ����� �����
      i := 1; //������� ������� ������
      while (i <= si.si_countsi) and (i <= 255) do
      begin
        if (j - 32 * trunc(j / 32)) in [1, 2, 3, 4, 12, 13, 17, 18]
          {//33 - 32(33/32) =33-32*1=1} then
          BlockRead(DBF_File, ch, 1) //���������� �������� �������
        else
        begin
          BlockWrite(DBF_File, si.si_text[i], 1);
            //���������� ��������� ����������
          i := i + 1;
        end;
        j := j + 1;
      end; //while
      PutSI := True; //������ �� ������ �������
    end
    else
      PutSI := True;
        //������ �� ���������� �.�. �� ������� ���� ��������� ����������
  finally //��� ����� ��������� - ���� �������
    CloseFile(DBF_File);
  end;
end;

function GetSI(dir: string): ASU_SI;
var
  SI: ASU_SI;
  blok: array[1..32] of char;
  DBF_File: file;
  j, i, rez: integer;
  ch: char;
  fStartSI: Boolean; //������� ������ ��������� ����������
  HEAD: DBF_HEAD;
  np2, countsi2: string;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //������ ��������� ����������
  ////////////////////////////////////////////////////////////////////////////////
  try
    //������ ����������
    SI.si_name := '';
    SI.si_date := '';
    SI.si_np := 0;
    SI.si_countsi := 0;
    SI.si_text := '';

    FileMode := 0;
    AssignFile(DBF_File, dir); //������ ����� ����� � �������� ����������
    Reset(DBF_File, 1); //�������� �����
    fStartSI := False;

    //������ ���������
    BlockRead(DBF_File, HEAD, 32, rez); //������� �� 4 ������� �� SIA#00
    SI.si_CountRec := HEAD.last_rec; //����� ����� ��������� ������

    rez := 4;
    //���������� ������ ��������� ����������
    while (not fStartSI) and (rez = 4) do
      // 1 ������� ��� ����������� ������ ��. ���, ������ ��� ����������� ����� �����
    begin
      BlockRead(DBF_File, blok, 4, rez); //������� �� 4 ������� �� SIA#00
      if (blok[1] = 'S') and (blok[2] = 'I') and (blok[3] = 'A') and (blok[4] =
        #00) then
        fStartSI := True //������� ������ ��������� ����������
      else
        for j := 1 to 7 do
          BlockRead(DBF_File, blok, 4, rez);
            //������ ��� 7 ���� �� 4 ������� - �� ������ ��������� 32 ����
    end;

    if fStartSI then //���� ������� ������ ��������� ����������
    begin
      // 0123456789ABCDEF
      // SIA?���-��??????     ���-�� ��� ���� ������
      // ??��������������     ��������-���� ��������  ���-���������  ���-����� ��������� ����������

      //������ ����� �����
      for j := 1 to 6 do
      begin
        BlockRead(DBF_File, ch, 1);
        si.si_name := si.si_name + ch;
      end;

      BlockRead(DBF_File, blok, 4); //���������� 8 ��������
      BlockRead(DBF_File, blok, 4);

      //������ ����
      for j := 1 to 8 do
      begin
        BlockRead(DBF_File, ch, 1);
        si.si_date := si.si_date + ch;
      end;

      //������ ������ ���������
      for j := 1 to 3 do
      begin
        BlockRead(DBF_File, ch, 1);
        np2 := np2 + ch;
      end;
      si.si_np := StrToInt(np2);

      //������ ����� ������������� ����������
      for j := 1 to 3 do
      begin
        BlockRead(DBF_File, ch, 1);
        countsi2 := countsi2 + ch;
      end;

      si.si_countsi := StrToIntDef(countsi2, 0);
        //���� ��������������� �� �������, ����� ���. ���. ��������� � ����.

      // ������ ��������� ����������
      // 0123456789ABCDEF
      // SIB?kkkkkkk??kkk     k - ����� ��� ������ ��������� ����������
      // ??kkkkkkkkkkkkkk

      j := 1; //������� ����� �����
      i := 1; //������� ������� ������
      while (i <= si.si_countsi) and (i <= 255) do
      begin
        if (j - 32 * trunc(j / 32)) in [1, 2, 3, 4, 12, 13, 17, 18]
          {//33 - 32(33/32) =33-32*1=1} then
          BlockRead(DBF_File, ch, 1) //���������� �������� �������
        else
        begin
          BlockRead(DBF_File, ch, 1); //������ ��������� ����������
          if ch = #0 then
            ch := ' ';
          si.si_text := si.si_text + ch;
          Inc(i);
        end;
        Inc(j);
      end;

      //������������� �� dos � min
      SI.si_name := CodASCII(SI.si_name);
      SI.si_text := CodASCII(SI.si_text);
      GetSI := SI; //�������� ��������� �� ��� ��� ��������� �������
    end;
  finally //��� ����� ��������� - ���� �������
    CloseFile(DBF_File);
  end;
end;

function CodDOS(strWin: string): string;
var
  i, cod: Integer;
  strDOS: string;
begin
  strDOS := '';
  for i := 1 to Length(strWin) do
  begin
    cod := ord(strWin[i]);
    case cod of
      192..239: strDOS := strDOS + Chr(cod - 64); //'�..�'
      240..255: strDOS := strDOS + Chr(cod - 16); //'�..�'
      184: strDOS := strDOS + chr(241); //�
      168: strDOS := strDOS + chr(240) //�
    else
      strDOS := strDOS + copy(strWin, i, 1);
    end;
  end;
  CodDOS := strDOS;
end;

function CodASCII(strWin: string): string;
var
  i, cod: Integer;
  strASCII: string;
begin
  strASCII := '';
  for i := 1 to Length(strWin) do
  begin
    cod := ord(strWin[i]);
    case cod of
      128..175: strASCII := strASCII + Chr(cod + 64); //'�..�'
      224..239: strASCII := strASCII + Chr(cod + 16); //'�..�'
      241: strASCII := strASCII + chr(184); //�
      240: strASCII := strASCII + chr(168) //�
    else
      strASCII := strASCII + copy(strWin, i, 1);
    end;
  end;
  CodASCII := strASCII;
end;

end.


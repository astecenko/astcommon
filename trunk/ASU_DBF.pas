{Библиотека типовых функция для работы с файлами формата DBF

  http://www.nevz.com/

  Copyright NEVZ 1936-2011

  @Author(Макарова Н.А.)
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
  //заголовок DBF
  DBF_HEAD = record
    //тип файла 03 - файл DBF
    dbf_id: char;
    //дата последнего изменения гг мм дд
    last_update: MyData;
    //номер последней записи
    last_rec: Longint;
    //смещение, с которого начинаются информационные записи, зависит от числа полей
    data_offset: word;
    //размер каждой записи
    rec_size: word;
    //дополнение до 32 байт #00
    filler: array[1..20] of char;
  end;
  //поле таблицы DBF
  DBF_FIELD = record
    //имя поля
    field_name: array[1..11] of char;
    //тип
    field_type: char;
    //заглушка
    dummy: array[1..4] of char;
    //количество символов для CHAR или общая длинна для N
    len: byte;
    //количество десятичных символов
    dec: byte;
    //дополнение до 32 байт #00
    filler: array[1..14] of char;
  end;
  //тип для записи номера поколения
  TMyNP = 0..999;
  //формат переменной служебной информации
  ASU_SI = record
    //имя массива не ЕС ЭВМ
    si_name: string[6];
    //дата создания на ЕС ЭВМ
    si_date: string[8];
    //номер поколения массива
    si_np: TMyNP;
    //длина нижеследующей информации
    si_countsi: 0..255;
    //текст служебной информации определяемой пользователем
    si_text: string[255];
    //количество записей в файле
    si_countrec: integer;
  end;

  {очистка структуры DBF файла
   @returns(@true если успешно, @false если иначе)}
function ASU_DBF_ClearFields(): Boolean;

{добавление поля в таблицу DBF
@param(fn Имя поля)
@param(ft Тип поля)
@param(l Длина поля)
@param(d Десятичная часть у дробных)}
procedure ASU_DBF_AddField(fn: string; ft: char; l, d: word);

{Создание таблицы DBF на основе полей хранящихся в  DBF_Fields
@returns(@true если таблица успешно создана, @false иначе)
@param(dir Имя файла таблицы)
@seealso(DBF_Fields)}
function ASU_DBF_CreateTable(dir: string): Boolean;

{Запись служебной информации в файл DBF
@returns(@true если успешно)
@param(dir Имя файла)
@param(SI служебная информация (SI))}
function PutSI(dir: string; SI: ASU_SI): Boolean;

{Чтение служебной информации из файла DBF
@returns(Служебную информацию)
@param(dir Имя файла)}
function GetSI(dir: string): ASU_SI; //чтение служебной информации

{перевод из WIN в DOS кодировку
@param(strWin Строка в кодировке WIN1251)
@returns(Строка в кодировке OEM866)}
function CodDOS(strWin: string): string; //перевод из WIN в DOS кодировку

{перевод из DOS в WIN кодировку
@param(strWin Строка в кодировке OEM866)
@returns(Строка в кодировке WIN1251)}
function CodASCII(strWin: string): string; //перевод из DOS в WIN  кодировку

var

  //Переменная для хранения структур полей
  DBF_Fields: array of DBF_FIELD;

implementation

uses SysUtils, DateUtils, Math;

function ASU_DBF_ClearFields(): Boolean;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //очистка структуры файла
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
  //добавление поля
  ////////////////////////////////////////////////////////////////////////////////
  SetLength(DBF_Fields, Length(DBF_Fields) + 1); //увеличение массива

  //присвоение значений поля
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
  //создание таблицы
  ////////////////////////////////////////////////////////////////////////////////
  FileMode := 2;
  try //обработка исключений (если возникнут)
    AssignFile(DBF_File, dir); //связка имени файла с файловой переменной
    Rewrite(DBF_File, 32); //окрытие файла для записи

    with new_DBF_HEAD do
    begin
      dbf_id := #03; //константа для dbf файла
      last_update.luYear := YearOf(Date) - 2000;
        //получение года в двухзначном формате
      last_update.luMes := MonthOf(Date); //получение месяца
      last_update.luDay := DayOf(Date); //получение дня
      last_rec := 0; //записей нет пишем ноль
      data_offset := 32 + 32 * Length(DBF_Fields) + 3;
        //смещение до данных = заголовок + 32*кол-во полей + признак конца описания структуры
      rec_size := 0; //обнуление
      for i := 0 to High(DBF_Fields) do
        rec_size := rec_size + DBF_Fields[i].len;
          //размер записи = сумма размеров полей + 1 (разделительный байт)
      rec_size := rec_size + 1;
      for i := 1 to 20 do
        filler[i] := #00;
    end;

    BlockWrite(DBF_File, new_DBF_HEAD, 1); // Записываем заголовок
    for i := 0 to High(DBF_Fields) do
      BlockWrite(DBF_File, DBF_Fields[i], 1); // Записываем поля
    CloseFile(DBF_File);

    // Записываем конец файла
    Reset(DBF_File, 1); //открытие файла для записи
    Seek(DBF_File, new_DBF_HEAD.data_offset - 3);
    BlockWrite(DBF_File, #13#00#26, 3);
    Result := True;
  finally //при любых ситуациях - файл закрыть
    CloseFile(DBF_File);
  end;
end;

function PutSI(dir: string; SI: ASU_SI): boolean;
var
  blok: array[1..32] of char;
  DBF_File: file;
  j, i, rez: integer;
  ch: char;
  fStartSI: Boolean; //признак начала служебной информации
  np1, countsi1: string;
begin
  ////////////////////////////////////////////////////////////////////////////////
  // запись служебной информации
  ////////////////////////////////////////////////////////////////////////////////
  try
    SI.si_name := CodDOS(SI.si_name); //преобразование в DOS кодировку
    SI.si_text := CodDOS(SI.si_text);

    FileMode := 2;
    AssignFile(DBF_File, dir); //связка имени файла с файловой переменной
    Reset(DBF_File, 1); //окрытие файла для записи
    fStartSI := False;
    rez := 4;

    //определяем начало служебной информации
    while (not fStartSI) and (rez = 4) do
      // 1 условие для определения начала сл. инф, второе для определения конца файла
    begin
      BlockRead(DBF_File, blok, 4, rez); //читаенм по 4 символа да SIA#00
      if (blok[1] = 'S') and (blok[2] = 'I') and (blok[3] = 'A') and (blok[4] =
        #00) then
        fStartSI := True
      else
        for j := 1 to 7 do
          BlockRead(DBF_File, blok, 4, rez);
            //читаенм еще 7 раза по 4 символа - до начала чледующих 32 байт
    end;

    if fStartSI then //было найдено начало служебной информации
    begin
      // 0123456789ABCDEF
      // SIA?Имя-БД??????       Имя-БД имя базы данных
      // ??ДАТАСОЗДпокДСИ       ДАТАСОЗД-дата создания  пок-поколение  ДСИ-длинни служебной информации
      //запись имени файла
      for j := 1 to 6 do
        BlockWrite(DBF_File, si.si_name[j], 1);

      BlockRead(DBF_File, blok, 4); //пропускаем 8 символов
      BlockRead(DBF_File, blok, 4);

      //запись даты
      for j := 1 to 8 do
        BlockWrite(DBF_File, si.si_date[j], 1);

      //запись номера поколения
      np1 := format('%3.3d', [si.si_np]);
      for j := 1 to 3 do
        BlockWrite(DBF_File, np1[j], 1);

      //запись длинны нижеследующей информации
      countsi1 := format('%3.3d', [si.si_countsi]);
      for j := 1 to 3 do
        BlockWrite(DBF_File, countsi1[j], 1);
      // запись служебной информации
      // 0123456789ABCDEF
      // SIB?kkkkkkk??kkk     k - места для записи служебной информации
      // ??kkkkkkkkkkkkkk
      j := 1; //считает байты файла
      i := 1; //считает символы текста
      while (i <= si.si_countsi) and (i <= 255) do
      begin
        if (j - 32 * trunc(j / 32)) in [1, 2, 3, 4, 12, 13, 17, 18]
          {//33 - 32(33/32) =33-32*1=1} then
          BlockRead(DBF_File, ch, 1) //пропускаем ненужные позиции
        else
        begin
          BlockWrite(DBF_File, si.si_text[i], 1);
            //записываем служебную информацию
          i := i + 1;
        end;
        j := j + 1;
      end; //while
      PutSI := True; //записи СИ прошла успешно
    end
    else
      PutSI := True;
        //записи СИ невозможна т.к. не нашлись поля служебной информации
  finally //при любых ситуациях - файл закрыть
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
  fStartSI: Boolean; //признак начала служебной информации
  HEAD: DBF_HEAD;
  np2, countsi2: string;
begin
  ////////////////////////////////////////////////////////////////////////////////
  //чтение служебной информации
  ////////////////////////////////////////////////////////////////////////////////
  try
    //чистим переменную
    SI.si_name := '';
    SI.si_date := '';
    SI.si_np := 0;
    SI.si_countsi := 0;
    SI.si_text := '';

    FileMode := 0;
    AssignFile(DBF_File, dir); //связка имени файла с файловой переменной
    Reset(DBF_File, 1); //открытие файла
    fStartSI := False;

    //Чтение заголовка
    BlockRead(DBF_File, HEAD, 32, rez); //читаенм по 4 символа да SIA#00
    SI.si_CountRec := HEAD.last_rec; //берем номер последней записи

    rez := 4;
    //определяем начало служебной информации
    while (not fStartSI) and (rez = 4) do
      // 1 условие для определения начала сл. инф, второе для определения конца файла
    begin
      BlockRead(DBF_File, blok, 4, rez); //читаенм по 4 символа да SIA#00
      if (blok[1] = 'S') and (blok[2] = 'I') and (blok[3] = 'A') and (blok[4] =
        #00) then
        fStartSI := True //признак начала служебной информации
      else
        for j := 1 to 7 do
          BlockRead(DBF_File, blok, 4, rez);
            //читаем еще 7 раза по 4 символа - до начала чледующих 32 байт
    end;

    if fStartSI then //было найдено начало служебной информации
    begin
      // 0123456789ABCDEF
      // SIA?Имя-БД??????     Имя-БД имя базы данных
      // ??ДАТАСОЗДпокДСИ     ДАТАСОЗД-дата создания  пок-поколение  ДСИ-длина служебной информации

      //чтение имени файла
      for j := 1 to 6 do
      begin
        BlockRead(DBF_File, ch, 1);
        si.si_name := si.si_name + ch;
      end;

      BlockRead(DBF_File, blok, 4); //пропускаем 8 символов
      BlockRead(DBF_File, blok, 4);

      //чтение даты
      for j := 1 to 8 do
      begin
        BlockRead(DBF_File, ch, 1);
        si.si_date := si.si_date + ch;
      end;

      //чтение номера поколения
      for j := 1 to 3 do
      begin
        BlockRead(DBF_File, ch, 1);
        np2 := np2 + ch;
      end;
      si.si_np := StrToInt(np2);

      //чтение длины нижеследующей информации
      for j := 1 to 3 do
      begin
        BlockRead(DBF_File, ch, 1);
        countsi2 := countsi2 + ch;
      end;

      si.si_countsi := StrToIntDef(countsi2, 0);
        //если конвертирование не пройдет, длину ниж. инф. установим в ноль.

      // чтение служебной информации
      // 0123456789ABCDEF
      // SIB?kkkkkkk??kkk     k - места для записи служебной информации
      // ??kkkkkkkkkkkkkk

      j := 1; //считает байты файла
      i := 1; //считает символы текста
      while (i <= si.si_countsi) and (i <= 255) do
      begin
        if (j - 32 * trunc(j / 32)) in [1, 2, 3, 4, 12, 13, 17, 18]
          {//33 - 32(33/32) =33-32*1=1} then
          BlockRead(DBF_File, ch, 1) //пропускаем ненужные позиции
        else
        begin
          BlockRead(DBF_File, ch, 1); //читаем служебную информацию
          if ch = #0 then
            ch := ' ';
          si.si_text := si.si_text + ch;
          Inc(i);
        end;
        Inc(j);
      end;

      //перекодировка из dos в min
      SI.si_name := CodASCII(SI.si_name);
      SI.si_text := CodASCII(SI.si_text);
      GetSI := SI; //передаем считанную сл инф как результат функции
    end;
  finally //при любых ситуациях - файл закрыть
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
      192..239: strDOS := strDOS + Chr(cod - 64); //'А..п'
      240..255: strDOS := strDOS + Chr(cod - 16); //'р..я'
      184: strDOS := strDOS + chr(241); //ё
      168: strDOS := strDOS + chr(240) //Ё
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
      128..175: strASCII := strASCII + Chr(cod + 64); //'А..п'
      224..239: strASCII := strASCII + Chr(cod + 16); //'р..я'
      241: strASCII := strASCII + chr(184); //ё
      240: strASCII := strASCII + chr(168) //Ё
    else
      strASCII := strASCII + copy(strWin, i, 1);
    end;
  end;
  CodASCII := strASCII;
end;

end.


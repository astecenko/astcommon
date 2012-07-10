unit SAVLib_DB;

interface

uses DB, DBGrids;

// Выполняет в наборе данных Table фильтрацию (Search=False) или
// поиск с помощью Locate (Search=True) возвращает результат Locate,
// при фильтрации возвращает True при наличии условия фильтрации иначе False
//function DBLocateFilter(Table: TDataSet; FieldLists, FieldValues: TStrings; const Search: Boolean = True): Boolean;

//Копирование содержимого DBGrid в буфер обмена
procedure CopyDBGridToClipboardAsText(DBGrid: TDBGrid; const Selected: Boolean =
  False; const Entitled: Boolean = False; const Delimiter: string = #9);

function GridSelectAll(Grid: TDBGrid): Longint;

implementation

uses SysUtils, Classes, Controls, SAVLib;

(*function DBLocateFilter(Table: TDataSet; FieldLists, FieldValues: TStrings; const
  Search: Boolean = True): Boolean;
var
  i,n: Integer;
  s:string;
begin
  if FieldValues.Count < FieldLists.Count then
    n := FieldValues.Count
  else
    n := FieldLists.Count;
  if Search then
  begin
    //Locate

  end
  else
  begin
    //Filter
    s:='';
    for i:=0 to n-1 do
    begin
      if !!!!!!
    end;
    if medtCP.Text <> '  ' then
      Result := '(Cp=''' + medtCP.Text + '*'')';
    if medtShifr.Text <> '        ' then
    begin
      if Result <> '' then
        Result := Result + ' AND ';
      Result := Result + '(Shifr=''' + Trim(medtShifr.Text) + ''')';
    end;
    if medtKI.Text <> '    ' then
    begin
      if Result <> '' then
        Result := Result + ' AND ';
      Result := Result + '(KI=''' + Trim(medtKI.Text) + ''')';
    end;
    Result := True;
  end;
end;  *)

procedure CopyDBGridToClipboardAsText(DBGrid: TDBGrid; const Selected: Boolean =
  False; const Entitled: Boolean = False; const Delimiter: string = #9);
  function GetTitle: string;
  var
    i1: Integer;
  begin
    Result := '';
    for i1 := 0 to DBGrid.Columns.Count - 1 do
      if DBGrid.Columns[i1].Visible then
      begin
        if Result <> '' then
          Result := Result + Delimiter;
        Result := Result + DBGrid.Columns[i1].Title.Caption;
      end;
  end;

  function GetFieldsValue: string;
  var
    i1: Integer;
  begin
    Result := '';
    for i1 := 0 to DBGrid.Columns.Count - 1 do
      if DBGrid.Columns[i1].Visible then
      begin
        if Result <> '' then
          Result := Result + Delimiter;
        try
          Result := Result +
            DBGrid.DataSource.DataSet.FieldByName(DBGrid.Columns[i1].FieldName).AsString;
        except
          Result := Result + ' ';
        end;
      end;
  end;
var
  i: integer;
  list: TStringList;
  SavePlace: TBookmark;
begin
  list := TStringList.Create;
  SavePlace := DBGrid.DataSource.DataSet.GetBookmark;
  DBGrid.DataSource.DataSet.DisableControls;
  try
    if Entitled then
      list.Add(GetTitle);
    if Selected then
    begin
      if DBGrid.SelectedRows.Count > 0 then
        for i := 0 to DBGrid.SelectedRows.Count - 1 do
        begin
          DBGrid.DataSource.DataSet.GotoBookmark(pointer(DBGrid.SelectedRows.Items[i]));
          list.Add(GetFieldsValue);
        end;
    end
    else
    begin
      if DBGrid.DataSource.DataSet.RecordCount > 0 then
      begin
        DBGrid.DataSource.DataSet.First;
        while not (DBGrid.DataSource.DataSet.Eof) do
        begin
          list.Add(GetFieldsValue);
          DBGrid.DataSource.DataSet.Next;
        end;
      end;
    end;
    SAVLib.CopyTextToClipboard(list.Text);
  finally
    FreeAndNil(list);
    DBGrid.DataSource.DataSet.GotoBookmark(SavePlace);
    DBGrid.DataSource.DataSet.FreeBookmark(SavePlace);
    DBGrid.DataSource.DataSet.EnableControls;
  end;
end;

function GridSelectAll(Grid: TDBGrid): Longint;
begin
  Result := 0;
  Grid.SelectedRows.Clear;
  with Grid.Datasource.DataSet do
  begin
    First;
    DisableControls;
    try
      while not EOF do
      begin
        Grid.SelectedRows.CurrentRowSelected := True;
        inc(Result);
        Next;
      end;
    finally
      EnableControls;
    end;
  end;
end;

end.


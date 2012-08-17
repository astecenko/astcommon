{*******************************************************}
{                                                       }
{       SAVLib_INI  26-07-2012                          }
{                                                       }
{       Copyright (C) 2012 Stetsenko A.V.          }
{       e-mail: astecenko@gmail.com                     }
{       http://www.astecenko.net.ru/                    }
{*******************************************************}
unit SAVLib_INI;

interface

// Слияние INI
procedure MergeINI(const DestIniFile, SourceIniFile: string);

//чтение текстового ключа из ini-файла без учета регистра
function IniReadStringEx(const FileName, Section, Ident, Default:
  string): string;

implementation
uses Classes, SysUtils, IniFiles, SAVLib;

procedure MergeINI(const DestIniFile, SourceIniFile: string);
var
  DestIni, SourceIni: TMemIniFile;
  i, j: Integer;
  lSections, lValues: TStringList;
begin
  if FileExists(SourceIniFile) then
  begin
    DestIni := TMemIniFile.Create(DestIniFile);
    SourceIni := TMemIniFile.Create(SourceIniFile);
    lSections := TStringList.Create;
    lValues := TStringList.Create;
    SourceIni.ReadSections(lSections);
    for i := 0 to lSections.Count - 1 do
    begin
      SourceIni.ReadSection(lSections[i], lValues);
      for j := 0 to lValues.Count - 1 do
        DestIni.WriteString(lSections[i], lValues[j],
          SourceIni.ReadString(lSections[i], lValues[j], ''));
    end;
    DestIni.UpdateFile;
    FreeAndNil(lSections);
    FreeAndNil(lValues);
    FreeAndNil(DestIni);
    FreeAndNil(SourceIni);
  end;
end;

procedure DeleteFromINI(const DestIniFile, SourceIniFile: string);
var
  DestIni, SourceIni: TMemIniFile;
  i, j: Integer;
  lSections, lValues: TStringList;
begin
  DestIni := TMemIniFile(DestIniFile);
  SourceIni := TMemIniFile(SourceIni);
  lSections := TStringList.Create;
  lValues := TStringList.Create;
  SourceIni.ReadSections(lSections);
  for i := 0 to lSections.Count - 1 do
  begin
    SourceIni.ReadSection(lSections[i], lValues);
    for j := 0 to lValues.Count - 1 do
      DestIni.WriteString(lSections[i], lValues[j],
        SourceIni.ReadString(lSections[i], lValues[j], ''));
  end;
  DestIni.UpdateFile;
  FreeAndNil(DestIni);
  FreeAndNil(SourceIni);
end;

//Прочитать параметр из ini-файла, значения переводятся в нижний регистр

function IniReadStringEx(const FileName, Section, Ident, Default:
  string): string;
var
  param: TIniFile;
  s1: TStringList;
  sf: string;
begin
  sf := GetTempFile('.tmp');
  s1 := TStringList.Create;
  try
    s1.LoadFromFile(FileName);
  except
    Result := Default;
    Exit;
  end;
  s1.Text := AnsiLowerCase(s1.Text);
  try
    s1.SaveToFile(sf);
  except
    Result := Default;
    Exit;
  end;
  FreeAndNil(s1);
  param := TIniFile.Create(sf);
  Result := param.ReadString(Section, Ident, Default);
  FreeAndNil(param);
  DeleteFile(PAnsiChar(sf));
end;

end.


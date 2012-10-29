{ Very simple and light command-line parameter parsing tool }
{ (c) arseniiv 2009 }
unit CommandLine;
interface

uses
  SysUtils, Classes;

type
  TKeyChar = 'A'..'Z';

  PCmdKey = ^TCmdKey;
  TCmdKey = record
    Alias: String;
    ValueStr:  String;  
    Key: TKeyChar;
    BoolKey: Boolean; 
    ValueBool: Boolean;
  end;

  // Cmdline key syntax:                             
  // ( '-' | '/' ) NAME ( [ '+' | '-' ] | '=' ( '"' STR '"' | STR ) )  
  // because of std Windows cmdline parser, keys in form '/key=str'
  // are also valid. And all of this keys transform to '/key=str' form 
  // Key parsing disabler/enabler '--' also supported
  // Numbers are treated as strings

  ECmdLine = class(Exception);
  
  TCmdLine = class(TObject) 
  private
    FParsed: Boolean;
    FValidParsed: Boolean;
    FKeyList: TList;
    FMinPaths, FMaxPaths: Integer;
    
    FParsedKeyList: TList;
    FParsedPathsList: TStringList;

    function FindKey(Key: TKeyChar; InParsedKeys: Boolean): PCmdKey;

    function FindKeyAlias(const S: String): PCmdKey;
    
    function GetBoolKey(Key: TKeyChar): Boolean;
    function GetPath(Index: Word): String;
    function GetPathCount: Word;
    function GetStrKey(Key: TKeyChar): String;
  public
    procedure AddBoolKey(Key: TKeyChar; Default: Boolean;
      const Alias: String = '');
    procedure AddStrKey(Key: TKeyChar; Default: String;
      const Alias: String = '');
    procedure RequirePaths(MinCount: Word = 0; MaxCount: Word = 1);
    procedure Clear;
  
    procedure Parse;
    
    function IsValid: Boolean;
    property BoolKey[Key: TKeyChar]: Boolean read GetBoolKey;
    property StrKey[Key: TKeyChar]: String read GetStrKey;
    property PathCount: Word read GetPathCount;
    property Paths[Index: Word]: String read GetPath;
  
    constructor Create;
    destructor Destroy; override;
  end;

  
implementation

{ TCmdLine }

procedure TCmdLine.AddBoolKey(Key: TKeyChar; Default: Boolean;
  const Alias: String);
var
  P: PCmdKey;
begin
  FParsed := False;
  New(P);
  P^.Key := Key;
  P^.Alias := Alias;
  P^.BoolKey := True;
  P^.ValueBool := Default;
  FKeyList.Add(P);
end;

procedure TCmdLine.AddStrKey(Key: TKeyChar; Default: String;
  const Alias: String);
var
  P: PCmdKey;
begin
  FParsed := False;
  New(P);
  P^.Key := Key;
  P^.Alias := Alias;
  P^.BoolKey := False;
  P^.ValueStr := Default;
  FKeyList.Add(P);
end;

procedure TCmdLine.Clear;
var
  i: Integer;
begin
  for i := 0 to FKeyList.Count-1 do Dispose(PCmdKey(FKeyList[i]));
  FKeyList.Clear;
  for i := 0 to FParsedKeyList.Count-1 do Dispose(PCmdKey(FParsedKeyList[i]));
  FParsedKeyList.Clear;
  FParsedPathsList.Clear;
  FMinPaths := 0;
  FMaxPaths := -1;
  FValidParsed := True;
  FParsed := False;
end;

constructor TCmdLine.Create;
begin
  FKeyList := TList.Create;
  FParsedKeyList := TList.Create;
  FParsedPathsList := TStringList.Create;
  FMinPaths := 0;
  FMaxPaths := -1;
  FValidParsed := True;
  FParsed := False;
end;

destructor TCmdLine.Destroy;
begin
  Clear;
  FKeyList.Free;
  FParsedKeyList.Free;
  FParsedPathsList.Free;
  inherited;
end;

function TCmdLine.FindKey(Key: TKeyChar; InParsedKeys: Boolean): PCmdKey;
var
  i,n: Integer;
  L: TList;
begin
  if InParsedKeys then
    L := FParsedKeyList
  else L := FKeyList;
  n:=L.Count-1;
  for i := 0 to n do begin
    Result := PCmdKey(L[i]);
    if Result^.Key=Key then Exit;
  end;
  Result := nil;
end;

function TCmdLine.FindKeyAlias(const S: String): PCmdKey;
var
  i,n: Integer;
  Str: String;
begin
  Str := UpperCase(S);
  n:= FKeyList.Count-1;
  for i := 0 to n do begin
    Result := PCmdKey(FKeyList[i]);
    if (UpperCase(Result^.Alias)=Str) or (Result^.Key=Str) then Exit;
  end;
  Result := nil;
end;

function TCmdLine.GetBoolKey(Key: TKeyChar): Boolean;
var
  K: PCmdKey;
begin
  Result := False;
  if not FParsed then raise
    ECmdLine.Create('CmdLine need to be parsed before calling BoolKey');
  K := FindKey(Key,True);
  if Assigned(K) then begin
    if not K^.BoolKey then raise
      ECmdLine.CreateFmt('"%s" is not a boolean key',[Key]);
    Result := K^.ValueBool;
  end
  else begin
    K := FindKey(Key,False);
    if not Assigned(K) then Exit;
    if not K^.BoolKey then raise
      ECmdLine.CreateFmt('"%s" is not a boolean key',[Key]);
    Result := K^.ValueBool;
  end;
end;

function TCmdLine.GetPath(Index: Word): String;
begin
  if not FParsed then raise
    ECmdLine.Create('CmdLine need to be parsed before calling Path');
  Result := FParsedPathsList[Index];
end;

function TCmdLine.GetPathCount: Word;
begin
  if not FParsed then raise
    ECmdLine.Create('CmdLine need to be parsed before calling PathCount');
  Result := FParsedPathsList.Count;
end;

function TCmdLine.GetStrKey(Key: TKeyChar): String;
var
  K: PCmdKey;
begin
  Result := '';
  if not FParsed then raise
    ECmdLine.Create('CmdLine need to be parsed before calling StrKey');
  K := FindKey(Key,True);
  if Assigned(K) then begin
    if K^.BoolKey then raise
      ECmdLine.CreateFmt('"%s" is not a string key',[Key]);
    Result := K^.ValueStr;
  end
  else begin
    K := FindKey(Key,False);
    if not Assigned(K) then Exit;
    if K^.BoolKey then raise
      ECmdLine.CreateFmt('"%s" is not a string key',[Key]);
    Result := K^.ValueStr;
  end;
end;

function TCmdLine.IsValid: Boolean;
begin
  if not FParsed then raise
    ECmdLine.Create('CmdLine need to be parsed before calling IsValid');
  Result := FValidParsed;
end;

procedure TCmdLine.Parse;
var
  i: Integer;
  S: String;
  DoNotParseAsKeys: Boolean;

  function ParseKey(const Str: String): Boolean;
  var
    State: (sBegin, sKey, sBool, sStr, sError);
    i, NameL, n: Integer;
    Ch: Char;
    Name: String;
    K: TCmdKey;
    PK: PCmdKey;
  begin
    Result := False;
    State := sBegin;
    Name := '';
    NameL := 0;
    n:=Length(Str);
    for i := 2 to n do begin
      Ch := Str[i];
      case State of
        sBegin: begin
          if Ch in ['0'..'9','A'..'Z','a'..'z'] then begin
            Inc(NameL);
            SetLength(Name,NameL);
            Name[NameL] := Ch;
            State := sKey;
          end
          else State := sError;
        end;
        sKey: begin
          case Ch of
            '0'..'9', 'A'..'Z', 'a'..'z': begin
              Inc(NameL);
              SetLength(Name,NameL);
              Name[NameL] := Ch;
            end;
            '+', '-': begin
              if Name='' then Exit;
              PK := FindKeyAlias(Name);
              if PK=nil then Exit;
              K := PK^;
              Name := '';
              if Ch='+' then NameL := 1 else NameL := 0;
              State := sBool;
            end;
            '=': begin
              if Name='' then Exit;
              PK := FindKeyAlias(Name);
              if PK=nil then Exit;
              K := PK^;
              Name := '';
              NameL := 0;
              State := sStr;
            end;
            else State := sError;
          end;
        end;
        sBool: begin
          State := sError;
        end;
        sStr: begin
          Inc(NameL);
          SetLength(Name,NameL);
          Name[NameL] := Ch;
        end;
        sError: Exit;
      end;
    end;
    if State=sStr then begin
      if K.BoolKey then Exit;
      if (Name<>'') and (Name[1]='"') then
        K.ValueStr := AnsiDequotedStr(Name,'"')
      else K.ValueStr := Name;
    end
    else if State=sKey then begin
      if Name='' then Exit;
      PK := FindKeyAlias(Name);
      if PK=nil then Exit;
      K := PK^;
      if K.BoolKey then
        K.ValueBool := not K.ValueBool
      else K.ValueStr := '';
    end
    else if State=sBool then begin
      if not K.BoolKey then Exit;
      if NameL=1 then
        K.ValueBool := True
      else K.ValueBool := False;
    end
    else {sError & sBegin} Exit;
    New(PK);
    PK^ := K;
    FParsedKeyList.Add(PK);
    Result := True;
  end;

begin
  for i := 0 to FParsedKeyList.Count-1 do Dispose(PCmdKey(FParsedKeyList[i]));
  FParsedKeyList.Clear;
  FParsedPathsList.Clear;
  FParsed := True;
  FValidParsed := False;
  DoNotParseAsKeys := False;
  for i := 1 to ParamCount do begin
    S := ParamStr(i);
    if S='--' then begin
      DoNotParseAsKeys := not DoNotParseAsKeys;
      Continue;
    end;
    if (not DoNotParseAsKeys) and (S<>'') and (S[1] in ['-','/']) then begin
      if not ParseKey(S) then FParsedPathsList.Add(S);
    end
    else begin
      FParsedPathsList.Add(S);
    end;
  end;
  i := FParsedPathsList.Count;
  if (i<FMinPaths) or (i>FMaxPaths) then Exit;
  FValidParsed := True;
end;

procedure TCmdLine.RequirePaths(MinCount, MaxCount: Word);
begin
  FParsed := False;
  if MaxCount<MinCount then raise
    ECmdLine.Create('MinCount need to be less or equal to MaxCount');
  FMinPaths := MinCount;
  FMaxPaths := MaxCount;
end;



end.

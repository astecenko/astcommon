var
  Cmd: TCmdLine;
  B: Boolean;
begin
  Cmd := TCmdLine.Create;
  Cmd.AddBoolKey('R', False, 'RUN'); // ������������ ������� �� �����.
  Cmd.RequirePaths(1, 1); // ���������� ���� ����
  Cmd.Parse;
  if Cmd.IsValid then begin
    B := Cmd.BoolKey['R'];
      // ...
    end
  else Exit;
  Cmd.Free;
end;
var
  Cmd: TCmdLine;
  B: Boolean;
begin
  Cmd := TCmdLine.Create;
  Cmd.AddBoolKey('R', False, 'RUN'); // впоследствии регистр не важен.
  Cmd.RequirePaths(1, 1); // обязателен один путь
  Cmd.Parse;
  if Cmd.IsValid then begin
    B := Cmd.BoolKey['R'];
      // ...
    end
  else Exit;
  Cmd.Free;
end;
unit ShellLink;
interface

type
  ShortcutType = (_DESKTOP, _QUICKLAUNCH, _SENDTO, _STARTMENU, _OTHERFOLDER);

function CreateShortcut(const SourceFileName: string;
  // the file the shortcut points to
  Location: ShortcutType; // shortcut location
  const SubFolder, // subfolder of location
  WorkingDir, // working directory property of the shortcut
  Parameters,
  Description: string;
  const LinkFileName: string = ''): //  description property of the shortcut
string;

implementation
uses
  SysUtils,
  Windows,
  Registry,
  ActiveX,
  ComObj,
  ShlObj;

const
  SHELL_FOLDERS_ROOT = 'Software\MicroSoft\Windows\CurrentVersion\Explorer';
  QUICK_LAUNCH_ROOT = 'Software\MicroSoft\Windows\CurrentVersion\GrpConv';

function CreateShortcut(const SourceFileName: string;
  // the file the shortcut points to
  Location: ShortcutType; // shortcut location
  const SubFolder, // subfolder of location
  WorkingDir, // working directory property of the shortcut
  Parameters,
  Description: string;
  const LinkFileName: string = ''): //  description property of the shortcut
string;
var
  MyObject: IUnknown;
  MySLink: IShellLink;
  MyPFile: IPersistFile;
  Directory, LinkName: string;
  WFileName: WideString;
  Reg: TRegIniFile;
begin
  MyObject := CreateComObject(CLSID_ShellLink);
  MySLink := MyObject as IShellLink;
  MyPFile := MyObject as IPersistFile;
  MySLink.SetPath(PChar(SourceFileName));
  MySLink.SetArguments(PChar(Parameters));
  MySLink.SetDescription(PChar(Description));
  if LinkFileName = '' then
  begin
    LinkName := ChangeFileExt(SourceFileName, '.lnk');
    LinkName := ExtractFileName(LinkName);
  end
  else
    LinkName := LinkFileName;
  // Quicklauch
  if Location = _QUICKLAUNCH then
  begin
    Reg := TRegIniFile.Create(QUICK_LAUNCH_ROOT);
    try
      Directory := Reg.ReadString('MapGroups', 'Quick Launch', '');
    finally
      Reg.Free;
    end;
  end
  else
    // Other locations
  begin
    Reg := TRegIniFile.Create(SHELL_FOLDERS_ROOT);
    try
      case Location of
        _OTHERFOLDER: Directory := SubFolder;
        _DESKTOP: Directory := Reg.ReadString('Shell Folders', 'Desktop', '');
        _STARTMENU: Directory := Reg.ReadString('Shell Folders', 'Start Menu',
          '');
        _SENDTO: Directory := Reg.ReadString('Shell Folders', 'SendTo', '');
      end;
    finally
      Reg.Free;
    end;
  end;
  if Directory <> '' then
  begin
    if (SubFolder <> '') and (Location <> _OTHERFOLDER) then
      WFileName := Directory + '\' + SubFolder + '\' + LinkName
    else
      WFileName := Directory + '\' + LinkName;
    if WorkingDir = '' then
      MySLink.SetWorkingDirectory(PChar(ExtractFilePath(SourceFileName)))
    else
      MySLink.SetWorkingDirectory(PChar(WorkingDir));

    MyPFile.Save(PWChar(WFileName), False);
    Result := WFileName;
  end;
end;

// Some examples:
{procedure TForm1.Button1Click(Sender: TObject);
const
 PROGR = 'c:\YourProgram.exe';
var
  resPath: string;

  function GetProgramDir: string;
    var
      reg: TRegistry;
    begin
      reg := TRegistry.Create;
      try
        reg.RootKey := HKEY_CURRENT_USER;
        reg.OpenKey('Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders', False);
        Result := reg.ReadString('Programs');
        reg.CloseKey;
      finally
        reg.Free;
      end;
    end;
begin
  //Create a Shortcut in the Quckick launch toolbar
  CreateShortcut(PROGR, _QUICKLAUNCH, '','','','Description');
  //Create a Shortcut on the Desktop
  CreateShortcut(PROGR, _DESKTOP, '','','','Description');
  //Create a Shortcut in the Startmenu /"Programs"-Folder
  resPath := CreateShortcut(PROGR, _OTHERFOLDER, GetProgramDir,'','','Description');
  if resPath <> '' then
  begin
    ShowMessage('Shortcut Successfully created in: ' + resPath);
  end;
end;}
end.


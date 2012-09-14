{  ������ � HTML
  @author(�������� �.�. <avstecenko@ya.ru>)
  @lastmod(21.05.2012)}
unit SAVLib_HTML;

interface
resourcestring
  // ������� �������
  html_br = '<br>';

  { ���������� ������ �����
  @return ����������������� HTML �����
  @param tag ��� ������� ����� ��������� �����, �� ��������� @bold(P)
  @param txt ����� ��� ����������, �� ��������� "������" @bold(&nbsp;)
  @param halign ������������ ������������, �� ��������� �����
  @param css ����� ����, �� ��������� �����
  @param propert �������� ����, �� ��������� �����
  }
function Html(const tag: string = 'p'; const txt: string = '&nbsp;'; const
  halign: string = ''; const css: string = ''; const propert: string = ''):
  string;

{ ��������� ��������� HTML ���������
@return ��������� HTML ��������� (@italic(���������� ���� @bold(Head)))
@param Description ���������� ����-���� @bold(Description), �� ��������� �����
@param Title ���������� ���� @bold(Title), �� ��������� �����
@param Tags HTML ����� ��� ������ ������ ���� @bold(Head), ����� ���� @bold(Title) }
function Html_Head(const Description: string = ''; const Title: string = '';
  const Tags: string = ''): string;

implementation

uses SysUtils;

function Html(const tag: string = 'p'; const txt: string = '&nbsp;'; const
  halign: string = ''; const css: string = ''; const propert: string = ''):
  string;
var
  txt2: string;
begin
  if trim(txt) = '' then
    txt2 := '&nbsp;'
  else
    txt2 := txt;
  Result := '<' + tag;
  if halign <> '' then
    Result := Result + ' align="' + halign + '"';
  if css <> '' then
    Result := Result + ' style="' + css + '"';
  if propert <> '' then
    Result := Result + ' ' + propert;
  Result := Result + '>' + txt2 + '</' + tag + '>';
end;

function Html_Head(const Description: string = ''; const Title: string = '';
  const Tags: string = ''): string;
begin
  Result := html('head',
    '<meta name="content-type" http-equiv="Content-Type" content="text/html; charset=windows-1251" /><meta name="description" http-equiv="description" content="' + Description
    + '" />' + html('title', Title) + Tags);
end;

end.


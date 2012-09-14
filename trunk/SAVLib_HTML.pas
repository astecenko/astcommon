{  Работа с HTML
  @author(Стеценко А.В. <avstecenko@ya.ru>)
  @lastmod(21.05.2012)}
unit SAVLib_HTML;

interface
resourcestring
  // Перевод каретки
  html_br = '<br>';

  { Обрамление текста тэгом
  @return Отформатированный HTML текст
  @param tag Тэг которым нужно обромлять текст, по умолчанию @bold(P)
  @param txt Текст для обрамления, по умолчанию "пробел" @bold(&nbsp;)
  @param halign Вертикальное выравнивание, по умолчанию пусто
  @param css Стиль тэга, по умолчанию пусто
  @param propert Свойства тэга, по умолчанию пусто
  }
function Html(const tag: string = 'p'; const txt: string = '&nbsp;'; const
  halign: string = ''; const css: string = ''; const propert: string = ''):
  string;

{ Генерация заголовка HTML документа
@return Заголовок HTML документа (@italic(Сожержимое тэга @bold(Head)))
@param Description Содержимое мета-тэга @bold(Description), по умолчанию пусто
@param Title Содержимое тэга @bold(Title), по умолчанию пусто
@param Tags HTML текст для вывода внутри тэга @bold(Head), после тэга @bold(Title) }
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


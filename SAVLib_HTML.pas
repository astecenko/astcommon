{*******************************************************}
{                                                       }
{       SAVLib HTML     16-05-2012                      }
{                                                       }
{       Copyright (C) 2012 Stetsenko A.V.               }
{       e-mail: astecenko@gmail.com                     }
{       http://www.astecenko.net.ru/                    }
{*******************************************************}

unit SAVLib_HTML;

interface
resourcestring
  html_br = '<br>';

function Html(const tag: string = 'p'; const txt: string = '&nbsp;'; const
  halign: string = ''; const css: string = ''; const propert: string = ''):
  string;
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
  Result:=html('head',
    '<meta name="content-type" http-equiv="Content-Type" content="text/html; charset=windows-1251" /><meta name="description" http-equiv="description" content="' + Description
    + '" />' + html('title',Title)+Tags);
end;

end.


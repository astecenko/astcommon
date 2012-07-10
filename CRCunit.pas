unit CRCunit;

interface

function GetFileCRC(const FileName: String): Cardinal;

implementation

var
	CRCtable: array[0..255] of Cardinal;

function GetNewCRC(OldCRC: Cardinal; StPtr: Pointer; StLen: Integer): Cardinal;
  asm
    test edx,edx;
    jz @ret;
    neg ecx;
    jz @ret;
    sub edx,ecx; // Address after last element 
    push ebx;
    mov ebx,0; // Set ebx=0 & align @next
    @next:
    mov bl,al;
    xor bl,byte [edx+ecx];
    shr eax,8;
    xor eax,cardinal [CRCtable+ebx*4];
    inc ecx;
    jnz @next;
		pop ebx;
    @ret:
end;

function GetFileCRC(const FileName: string): Cardinal;
const
	BufSize = 64 * 1024;
var
  Fi: file;
  pBuf: PChar;
  Count: integer;
begin
  Assign(Fi, FileName);
  Reset(Fi, 1);
  GetMem(pBuf, BufSize);
  Result := $FFFFFFFF;
  repeat
  	BlockRead(Fi, pBuf^, BufSize, Count);
		if Count = 0 then Break;
    Result := GetNewCRC(Result, pBuf, Count);
  until False;
  Result := not Result;
  FreeMem(pBuf);
  CloseFile(Fi);
end;

procedure CRCInit;
var
  c: Cardinal;
  I, J: Integer;
begin
  for I := 0 to 255 do begin
  	c := I;
	for J := 1 to 8 do
		if Odd(c) then
			c := (c shr 1) xor $EDB88320
    else
    	c := (c shr 1);
    CRCtable[I] := c;
	end;
end;

initialization
	CRCinit;

end.


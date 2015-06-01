{
  Encoding conversion routines are taken from Lazarus:
    components/lazutils/lconvencoding.pas
}

{$MODE OBJFPC}
{$H+}

unit fontinfo_utils;

interface

uses
  classes,
  streamex,
  sysutils;

type
  TStreamHeplerEx = class helper (TStreamHelper) for TStream
    function ReadPChar: string;
  end;


function UCS2LEToUTF8(const s: string): string;
function UCS2BEToUTF8(const s: string): string;

implementation


function TStreamHeplerEx.ReadPChar: string;
var
  b: byte;
begin
  result := '';
  b := ReadByte;
  while b <> 0 do
    begin
      result := result + char(b);
      b := ReadByte;
    end;
end;



function UnicodeToUTF8Inline(CodePoint: cardinal; Buf: PChar): integer;
begin
  case CodePoint of
    0..$7f:
      begin
        Result:=1;
        Buf[0]:=char(byte(CodePoint));
      end;
    $80..$7ff:
      begin
        Result:=2;
        Buf[0]:=char(byte($c0 or (CodePoint shr 6)));
        Buf[1]:=char(byte($80 or (CodePoint and $3f)));
      end;
    $800..$ffff:
      begin
        Result:=3;
        Buf[0]:=char(byte($e0 or (CodePoint shr 12)));
        Buf[1]:=char(byte((CodePoint shr 6) and $3f) or $80);
        Buf[2]:=char(byte(CodePoint and $3f) or $80);
      end;
    $10000..$10ffff:
      begin
        Result:=4;
        Buf[0]:=char(byte($f0 or (CodePoint shr 18)));
        Buf[1]:=char(byte((CodePoint shr 12) and $3f) or $80);
        Buf[2]:=char(byte((CodePoint shr 6) and $3f) or $80);
        Buf[3]:=char(byte(CodePoint and $3f) or $80);
      end;
  else
    Result:=0;
  end;
end;


function UCS2LEToUTF8(const s: string): string;
var
  len: integer;
  src: PWord;
  dest: PChar;
  i: integer;
  c: word;
begin
  if s = '' then
    exit(s);

  len := Length(s) div 2;
  SetLength(result, len * 3);
  src := PWord(Pointer(s));
  dest := PChar(result);

  for i := 1 to len do
    begin
      c := LEtoN(src^);
      inc(src);

      if c < 128 then
        begin
          dest^ := chr(c);
          inc(dest);
        end
      else
        inc(dest, UnicodeToUTF8Inline(c, dest));
    end;

  len := PtrUInt(dest) - PtrUInt(result);
  if len > length(result) then
    len := length(result);
  SetLength(result, len);
end;


function UCS2BEToUTF8(const s: string): string;
var
  len: integer;
  src: PWord;
  dest: PChar;
  i: integer;
  c: word;
begin
  if s = '' then
    exit(s);

  len := Length(s) div 2;
  SetLength(result, len * 3);
  src := PWord(Pointer(s));
  dest := PChar(result);

  for i := 1 to len do
    begin
      c := BEtoN(src^);
      inc(src);
      if c < 128 then
        begin
          dest^ := chr(c);
          inc(dest);
        end
      else
        inc(dest, UnicodeToUTF8Inline(c, Dest));
    end;

  len := PtrUInt(dest) - PtrUInt(result);
  if len > length(result) then
    len := length(result);
  SetLength(result, len);
end;


end.

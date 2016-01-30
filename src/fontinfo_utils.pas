{$MODE OBJFPC}
{$H+}
{$INLINE ON}

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



function UnicodeCharToUTF8(CodePoint: longword; Buf: PChar): integer; inline;
begin
  case CodePoint of
    0..$7f:
      begin
        Buf[0] := char(CodePoint);
        Result := 1;
      end;
    $80..$7ff:
      begin
        Buf[0] := char($c0 or (CodePoint shr 6));
        Buf[1] := char($80 or (CodePoint and $3f));
        Result := 2;
      end;
    $800..$ffff:
      begin
        Buf[0] := char($e0 or (CodePoint shr 12));
        Buf[1] := char($80 or ((CodePoint shr 6) and $3f));
        Buf[2] := char($80 or (CodePoint and $3f));
        Result := 3;
      end;
    $10000..$10ffff:
      begin
        Buf[0] := char($f0 or (CodePoint shr 18));
        Buf[1] := char($80 or ((CodePoint shr 12) and $3f));
        Buf[2] := char($80 or ((CodePoint shr 6) and $3f));
        Buf[3] := char($80 or (CodePoint and $3f));
        Result := 4;
      end;
  else
    Result := 0;
  end;
end;


function UCS2LEToUTF8(const s: string): string;
var
  len: SizeInt;
  src: PWord;
  dest: PChar;
  i: SizeInt;
begin
  if s = '' then
    exit(s);

  len := Length(s) div 2;
  SetLength(result, len * 3);
  src := PWord(s);
  dest := PChar(result);

  for i := 1 to len do
    begin
      inc(dest, UnicodeCharToUTF8(LEtoN(src^), dest));
      inc(src);
    end;

  SetLength(result, PtrUInt(dest) - PtrUInt(result));
end;


function UCS2BEToUTF8(const s: string): string;
var
  len: SizeInt;
  src: PWord;
  dest: PChar;
  i: SizeInt;
begin
  if s = '' then
    exit(s);

  len := Length(s) div 2;
  SetLength(result, len * 3);
  src := PWord(s);
  dest := PChar(result);

  for i := 1 to len do
    begin
      inc(dest, UnicodeCharToUTF8(BEtoN(src^), Dest));
      inc(src);
    end;

  SetLength(result, PtrUInt(dest) - PtrUInt(result));
end;


end.

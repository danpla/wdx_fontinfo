{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_utils;

interface

uses
  classes,
  streamex,
  sysutils;

type
  TStreamHeplerEx = class helper (TStreamHelper) for TStream
    function ReadPChar: string;
  end;


procedure SwapUnicode(var s: UnicodeString);


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


procedure SwapUnicode(var s: UnicodeString);
var
  i: SizeInt;
begin
  for i := 1 to Length(s) do
    s[i] := WideChar(SwapEndian(Word(s[i])));
end;


end.

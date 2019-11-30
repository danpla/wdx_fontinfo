{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_utils;

interface

uses
  classes;

function ReadPChar(stream: TStream): string;

procedure SwapUnicode(var s: UnicodeString);


implementation


function ReadPChar(stream: TStream): string;
var
  b: byte;
begin
  result := '';
  while TRUE do
    begin
      b := stream.ReadByte;
      if b = 0 then
        break;

      result := result + char(b);
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

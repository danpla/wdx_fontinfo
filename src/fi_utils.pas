unit fi_utils;

interface

uses
  classes;

function ReadPChar(stream: TStream): string;

procedure SwapUnicode(var s: UnicodeString);

function MacOSRomanToUTF8(const s: string): string;


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


const
  MAX_ASCII = 127;

  // https://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/ROMAN.TXT
  MAC_OS_ROMAN_TO_UTF8: array [0..255 - (MAX_ASCII + 1)] of string = (
    #195#132,
    #195#133,
    #195#135,
    #195#137,
    #195#145,
    #195#150,
    #195#156,
    #195#161,
    #195#160,
    #195#162,
    #195#164,
    #195#163,
    #195#165,
    #195#167,
    #195#169,
    #195#168,
    #195#170,
    #195#171,
    #195#173,
    #195#172,
    #195#174,
    #195#175,
    #195#177,
    #195#179,
    #195#178,
    #195#180,
    #195#182,
    #195#181,
    #195#186,
    #195#185,
    #195#187,
    #195#188,
    #226#128#160,
    #194#176,
    #194#162,
    #194#163,
    #194#167,
    #226#128#162,
    #194#182,
    #195#159,
    #194#174,
    #194#169,
    #226#132#162,
    #194#180,
    #194#168,
    #226#137#160,
    #195#134,
    #195#152,
    #226#136#158,
    #194#177,
    #226#137#164,
    #226#137#165,
    #194#165,
    #194#181,
    #226#136#130,
    #226#136#145,
    #226#136#143,
    #207#128,
    #226#136#171,
    #194#170,
    #194#186,
    #206#169,
    #195#166,
    #195#184,
    #194#191,
    #194#161,
    #194#172,
    #226#136#154,
    #198#146,
    #226#137#136,
    #226#136#134,
    #194#171,
    #194#187,
    #226#128#166,
    #194#160,
    #195#128,
    #195#131,
    #195#149,
    #197#146,
    #197#147,
    #226#128#147,
    #226#128#148,
    #226#128#156,
    #226#128#157,
    #226#128#152,
    #226#128#153,
    #195#183,
    #226#151#138,
    #195#191,
    #197#184,
    #226#129#132,
    #226#130#172,
    #226#128#185,
    #226#128#186,
    #239#172#129,
    #239#172#130,
    #226#128#161,
    #194#183,
    #226#128#154,
    #226#128#158,
    #226#128#176,
    #195#130,
    #195#138,
    #195#129,
    #195#139,
    #195#136,
    #195#141,
    #195#142,
    #195#143,
    #195#140,
    #195#147,
    #195#148,
    #239#163#191,
    #195#146,
    #195#154,
    #195#155,
    #195#153,
    #196#177,
    #203#134,
    #203#156,
    #194#175,
    #203#152,
    #203#153,
    #203#154,
    #194#184,
    #203#157,
    #203#155,
    #203#135
  );


function MacOSRomanToUTF8(const s: string): string;
var
  c: char;
  b: byte;
begin
  result := '';

  for c in s do
  begin
    b := byte(c);
    if b <= MAX_ASCII then
      result := result + c
    else
      result := result + MAC_OS_ROMAN_TO_UTF8[b - (MAX_ASCII + 1)];
  end;
end;


end.

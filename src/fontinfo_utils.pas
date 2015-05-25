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


function MacintoshToUTF8(const s: string): string;
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



type
  TCharToUTF8Table = array[char] of PChar;

const
  ArrayMacintoshToUTF8: TCharToUTF8Table = (
      #0,            // #0
      #1,            // #1
      #2,            // #2
      #3,            // #3
      #4,            // #4
      #5,            // #5
      #6,            // #6
      #7,            // #7
      #8,            // #8
      #9,            // #9
      #10,           // #10
      #11,           // #11
      #12,           // #12
      #13,           // #13
      #14,           // #14
      #15,           // #15
      #16,           // #16
      #17,           // #17
      #18,           // #18
      #19,           // #19
      #20,           // #20
      #21,           // #21
      #22,           // #22
      #23,           // #23
      #24,           // #24
      #25,           // #25
      #26,           // #26
      #27,           // #27
      #28,           // #28
      #29,           // #29
      #30,           // #30
      #31,           // #31
      ' ',           // ' '
      '!',           // '!'
      '"',           // '"'
      '#',           // '#'
      '$',           // '$'
      '%',           // '%'
      '&',           // '&'
      '''',          // ''''
      '(',           // '('
      ')',           // ')'
      '*',           // '*'
      '+',           // '+'
      ',',           // ','
      '-',           // '-'
      '.',           // '.'
      '/',           // '/'
      '0',           // '0'
      '1',           // '1'
      '2',           // '2'
      '3',           // '3'
      '4',           // '4'
      '5',           // '5'
      '6',           // '6'
      '7',           // '7'
      '8',           // '8'
      '9',           // '9'
      ':',           // ':'
      ';',           // ';'
      '<',           // '<'
      '=',           // '='
      '>',           // '>'
      '?',           // '?'
      '@',           // '@'
      'A',           // 'A'
      'B',           // 'B'
      'C',           // 'C'
      'D',           // 'D'
      'E',           // 'E'
      'F',           // 'F'
      'G',           // 'G'
      'H',           // 'H'
      'I',           // 'I'
      'J',           // 'J'
      'K',           // 'K'
      'L',           // 'L'
      'M',           // 'M'
      'N',           // 'N'
      'O',           // 'O'
      'P',           // 'P'
      'Q',           // 'Q'
      'R',           // 'R'
      'S',           // 'S'
      'T',           // 'T'
      'U',           // 'U'
      'V',           // 'V'
      'W',           // 'W'
      'X',           // 'X'
      'Y',           // 'Y'
      'Z',           // 'Z'
      '[',           // '['
      '\',           // '\'
      ']',           // ']'
      '^',           // '^'
      '_',           // '_'
      '`',           // '`'
      'a',           // 'a'
      'b',           // 'b'
      'c',           // 'c'
      'd',           // 'd'
      'e',           // 'e'
      'f',           // 'f'
      'g',           // 'g'
      'h',           // 'h'
      'i',           // 'i'
      'j',           // 'j'
      'k',           // 'k'
      'l',           // 'l'
      'm',           // 'm'
      'n',           // 'n'
      'o',           // 'o'
      'p',           // 'p'
      'q',           // 'q'
      'r',           // 'r'
      's',           // 's'
      't',           // 't'
      'u',           // 'u'
      'v',           // 'v'
      'w',           // 'w'
      'x',           // 'x'
      'y',           // 'y'
      'z',           // 'z'
      '{',           // '{'
      '|',           // '|'
      '}',           // '}'
      '~',           // '~'
      #127,          // #127
      #195#132,      // #128
      #195#133,      // #129
      #195#135,      // #130
      #195#137,      // #131
      #195#145,      // #132
      #195#150,      // #133
      #195#156,      // #134
      #195#161,      // #135
      #195#160,      // #136
      #195#162,      // #137
      #195#164,      // #138
      #195#163,      // #139
      #195#165,      // #140
      #195#167,      // #141
      #195#169,      // #142
      #195#168,      // #143
      #195#170,      // #144
      #195#171,      // #145
      #195#173,      // #146
      #195#172,      // #147
      #195#174,      // #148
      #195#175,      // #149
      #195#177,      // #150
      #195#179,      // #151
      #195#178,      // #152
      #195#180,      // #153
      #195#182,      // #154
      #195#181,      // #155
      #195#186,      // #156
      #195#185,      // #157
      #195#187,      // #158
      #195#188,      // #159
      #226#128#160,  // #160
      #194#176,      // #161
      #194#162,      // #162
      #194#163,      // #163
      #194#167,      // #164
      #226#128#162,  // #165
      #194#182,      // #166
      #195#159,      // #167
      #194#174,      // #168
      #194#169,      // #169
      #226#132#162,  // #170
      #194#180,      // #171
      #194#168,      // #172
      #226#137#160,  // #173
      #195#134,      // #174
      #195#152,      // #175
      #226#136#158,  // #176
      #194#177,      // #177
      #226#137#164,  // #178
      #226#137#165,  // #179
      #194#165,      // #180
      #194#181,      // #181
      #226#136#130,  // #182
      #226#136#145,  // #183
      #226#136#143,  // #184
      #207#128,      // #185
      #226#136#171,  // #186
      #194#170,      // #187
      #194#186,      // #188
      #206#169,      // #189
      #195#166,      // #190
      #195#184,      // #191
      #194#191,      // #192
      #194#161,      // #193
      #194#172,      // #194
      #226#136#154,  // #195
      #198#146,      // #196
      #226#137#136,  // #197
      #206#148,      // #198
      #194#171,      // #199
      #194#187,      // #200
      #226#128#166,  // #201
      #194#160,      // #202
      #195#128,      // #203
      #195#131,      // #204
      #195#149,      // #205
      #197#146,      // #206
      #197#147,      // #207
      #226#128#147,  // #208
      #226#128#148,  // #209
      #226#128#156,  // #210
      #226#128#157,  // #211
      #226#128#152,  // #212
      #226#128#153,  // #213
      #195#183,      // #214
      #226#151#138,  // #215
      #195#191,      // #216
      #197#184,      // #217
      #226#129#132,  // #218
      #226#130#172,  // #219
      #226#128#185,  // #220
      #226#128#186,  // #221
      #239#172#129,  // #222
      #239#172#130,  // #223
      #226#128#161,  // #224
      #194#183,      // #225
      #226#128#154,  // #226
      #226#128#158,  // #227
      #226#128#176,  // #228
      #195#130,      // #229
      #195#138,      // #230
      #195#129,      // #231
      #195#139,      // #232
      #195#136,      // #233
      #195#141,      // #234
      #195#142,      // #235
      #195#143,      // #236
      #195#140,      // #237
      #195#147,      // #238
      #195#148,      // #239
      #238#128#158,  // #240
      #195#146,      // #241
      #195#154,      // #242
      #195#155,      // #243
      #195#153,      // #244
      #196#177,      // #245
      #203#134,      // #246
      #203#156,      // #247
      #194#175,      // #248
      #203#152,      // #249
      #203#153,      // #250
      #203#154,      // #251
      #194#184,      // #252
      #203#157,      // #253
      #203#155,      // #254
      #203#135       // #255
    );


function SingleByteToUTF8(const s: string;
                          const table: TCharToUTF8Table): string;
var
  len,
  i: integer;
  src,
  dest: PChar;
  p: PChar;
  c: Char;
begin
  if s = '' then
    exit(s);

  len := Length(s);
  SetLength(result, len * 4); // UTF-8 is at most 4 bytes
  src := PChar(s);
  dest := PChar(result);

  for i := 1 to len do
    begin
      c := src^;
      inc(src);

      if ord(c) < 128 then
        begin
          dest^ := c;
          inc(dest);
        end
      else
        begin
          p := table[c];
          if p <> nil then
            while p^ <> #0 do
              begin
                dest^ := p^;
                inc(p);
                inc(dest);
              end;
        end;
    end;

  SetLength(result, PtrUInt(dest) - PtrUInt(result));
end;


function MacintoshToUTF8(const s: string): string;
begin
  Result:=SingleByteToUTF8(s, ArrayMacintoshToUTF8);
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

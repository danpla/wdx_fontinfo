{
  PostScript-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_ps;

interface

uses
  fontinfo_common,
  strutils,
  sysutils;


procedure GetPSInfo(const FileName: string; var info: TFontInfo);


implementation

const
  BIN_MAGICK = $0180;

  PS_MAGICK1 = '%!PS-AdobeFont';
  PS_MAGICK2 = '%!FontType';
  PS_MAGICK3 = '%!PS-TrueTypeFont';

  MAX_LINES = 26;

type
  TBinHeader = packed record
    magick: word;
    ascii_length: longword;
  end;


{
  Unescape string in a single pass.
}
function UnEscape(s: string): string;
const
  MAX_OCTAL_DIGITS = 3;
var
  l,
  i,
  escpos,
  esclen: longint;
begin
  l := Length(s);
  i := 1;

  while i < l do
    begin
      if s[i] = '\' then
        begin
          escpos := i;
          esclen := 1;
          inc(i);

          case s[i] of
            'n': s[escpos] := #10;
            'r': s[escpos] := #13;
            't': s[escpos] := #9;
            'b': s[escpos] := #8;
            'f': s[escpos] := #12;
            '\': s[escpos] := '\';
            '(': s[escpos] := '(';
            ')': s[escpos] := ')';
            '0'..'9':
              begin
                s[escpos] := chr(0);
                esclen := 0;
                while (i <= l) and
                      (esclen <= MAX_OCTAL_DIGITS) and
                      (s[i] in ['0'..'9']) do
                  begin
                    s[escpos] := chr(
                      (ord(s[escpos]) shl 3) or (ord(s[i]) - ord('0')));
                    inc(i);
                    inc(esclen);
                  end;
              end
          else
            // Ignore "/".
            dec(escpos);
          end;

          delete(s, escpos + 1, esclen);
          dec(i, esclen);
          dec(l, esclen);
        end;

      inc(i);
    end;

  result := s;
end;


function ExtractPSNumber(const s: string; const start: longword): string; inline;
begin
  result := Copy(s, start, PosEx(' ', s, start) - start);
end;


function ExtractPSSLiteral(const s: string; const start: longword): string; inline;
begin
  result := Copy(s, start + 1, PosEx(' ', s, start) - (start + 1));
end;


function ExtractPSString(const s: string; const start: longword): string; inline;
begin
  result := UnEscape(Copy(s, start + 1, RPos(')', s) - (start + 1)))
end;


{
  Skip binary header of .pfb file (if any).
}
procedure SkipBinary(var t: text); inline;
var
  h: THandle;
  magick: word;
begin
  h := GetFileHandle(t);
  FileRead(h, magick, SizeOf(magick));

  if LEtoN(magick) = BIN_MAGICK then
    // Skip the rest (size of ASII data).
    FileSeek(h, SizeOf(longword), fsFromCurrent)
  else
    FileSeek(h, 0, fsFromBeginning);
end;


procedure GetPSInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  i: longint;
  p,
  val_start: SizeInt;
  s,
  key: string;
begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  SkipBinary(t);

  ReadLn(t, s);
  if (s = '') or
     (Pos(PS_MAGICK1, s) <> 1) and
     (Pos(PS_MAGICK2, s) <> 1) and
     (Pos(PS_MAGICK3, s) <> 1) then
    exit;

  i := 1;
  while (i < MAX_LINES) and (not EOF(t)) do
    begin
      ReadLn(t, s);
      s := TrimLeft(s);

      // Skip empty lines and comments.
      if (s = '') or (s[1] = '%') then
        continue;
      inc(i);

      p := Pos(' ', s);
      if p = 0 then
        break;

      key := Copy(s, 1, p - 1);
      val_start := p + 1;

      case key of
        '/FontType': info[IDX_FORMAT] := 'PS T ' + ExtractPSNumber(s, val_start);
        '/FontName': info[IDX_PS_NAME] := ExtractPSSLiteral(s, val_start);
        '/version': info[IDX_VERSION] := ExtractPSString(s, val_start);
        '/Notice': info[IDX_COPYRIGHT] := ExtractPSString(s, val_start);
        '/FullName': info[IDX_FULL_NAME] := ExtractPSString(s, val_start);
        '/FamilyName': info[IDX_FAMILY] := ExtractPSString(s, val_start);
        '/Weight': info[IDX_STYLE] := ExtractPSString(s, val_start);
        '/Encoding': break;
      end;
    end;

  Close(t);
end;


end.

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

  // Characters we need to skip to reach certain value.
  SKIP_CHARS = [' ', '(', '/'];
  // Number of fields we need to find.
  NFIELDS = 7;

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


{
  Extract literal or number.
}
function ExtractPSValue(const s: string; const start: longword): string; inline;
begin
  result := Copy(s, start, PosEx(' ', s, start) - start);
end;


function ExtractPSString(const s: string; const start: longword): string; inline;
begin
  result := UnEscape(Copy(s, start, RPos(')', s) - start))
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
    FileSeek(h, SizeOf(TBinHeader.ascii_length), fsFromCurrent)
  else
    FileSeek(h, 0, fsFromBeginning);
end;


procedure GetPSInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  p,
  val_start: SizeInt;
  s,
  key: string;
  idx: TFieldIndex;
  nfound: longint = 0;
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

  while (nfound < NFIELDS) and not EOF(t) do
    begin
      ReadLn(t, s);
      s := Trim(s);

      // Skip empty lines and comments.
      if (s = '') or (s[1] = '%') then
        continue;

      if s = 'currentdict end' then
        break;

      p := PosSetEx(SKIP_CHARS, s, 2);
      if p = 0 then
        continue;

      key := Copy(s, 1, p - 1);

      case key of
        '/FontType': idx := IDX_FORMAT;
        '/FontName': idx := IDX_PS_NAME;
        '/version': idx := IDX_VERSION;
        '/Notice': idx := IDX_COPYRIGHT;
        '/FullName': idx := IDX_FULL_NAME;
        '/FamilyName': idx := IDX_FAMILY;
        '/Weight': idx := IDX_STYLE;
      else
        continue;
      end;

      val_start := p;
      // Skip spaces.
      repeat
        inc(val_start);
      until not (s[val_start] in SKIP_CHARS);

      case idx of
        IDX_FORMAT: info[idx] := 'PS T ' + ExtractPSValue(s, val_start);
        IDX_PS_NAME: info[idx] := ExtractPSValue(s, val_start);
      else
        info[idx] := ExtractPSString(s, val_start);
      end;

      inc(nfound);
    end;

  Close(t);
end;


end.

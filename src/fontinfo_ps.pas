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
  NUM_FIELDS = 7;

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
  i,
  s_len,
  esc_pos,
  esc_len: longint;
begin
  i := 1;
  s_len := Length(s);

  while i < s_len do
    begin
      if s[i] = '\' then
        begin
          esc_pos := i;
          esc_len := 1;
          inc(i);

          case s[i] of
            'n': s[esc_pos] := #10;
            'r': s[esc_pos] := #13;
            't': s[esc_pos] := #9;
            'b': s[esc_pos] := #8;
            'f': s[esc_pos] := #12;
            '\': s[esc_pos] := '\';
            '(': s[esc_pos] := '(';
            ')': s[esc_pos] := ')';
            '0'..'9':
              begin
                s[esc_pos] := chr(0);
                esc_len := 0;
                while (i <= s_len) and
                      (esc_len <= MAX_OCTAL_DIGITS) and
                      (s[i] in ['0'..'9']) do
                  begin
                    s[esc_pos] := chr(
                      (ord(s[esc_pos]) shl 3) or (ord(s[i]) - ord('0')));
                    inc(i);
                    inc(esc_len);
                  end;
              end
          else
            // Ignore "/".
            dec(esc_pos);
          end;

          delete(s, esc_pos + 1, esc_len);
          dec(i, esc_len);
          dec(s_len, esc_len);
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
  result := UnEscape(Copy(s, start, RPos(')', s) - start));
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
  num_found: longint = 0;
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
    begin
      Close(t);
      exit;
    end;

  while (num_found < NUM_FIELDS) and not EOF(t) do
    begin
      ReadLn(t, s);
      s := Trim(s);

      // Skip empty lines and comments.
      if (s = '') or (s[1] = '%') then
        continue;

      if s = 'currentdict end' then
        break;

      p := PosSetEx(SKIP_CHARS, s, 3);
      if p = 0 then
        continue;

      key := Copy(s, 2, p - 2);

      case key of
        'FontType': idx := IDX_FORMAT;
        'FontName': idx := IDX_PS_NAME;
        'version': idx := IDX_VERSION;
        'Notice': idx := IDX_COPYRIGHT;
        'FullName': idx := IDX_FULL_NAME;
        'FamilyName': idx := IDX_FAMILY;
        'Weight': idx := IDX_STYLE;
      else
        continue;
      end;

      val_start := p;

      repeat
        inc(val_start);
      until not (s[val_start] in SKIP_CHARS);

      case idx of
        IDX_FORMAT: info[idx] := 'PS T ' + ExtractPSValue(s, val_start);
        IDX_PS_NAME: info[idx] := ExtractPSValue(s, val_start);
      else
        info[idx] := ExtractPSString(s, val_start);
      end;

      inc(num_found);
    end;

  info[IDX_NUM_FONTS] := '1';

  Close(t);
end;


end.

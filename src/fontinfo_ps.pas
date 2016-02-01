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
  classes,
  strutils,
  streamio,
  streamex,
  sysutils;


procedure GetPSInfo(stream: TStream; var info: TFontInfo);


implementation

const
  BIN_MAGICK = $0180;

  PS_MAGICK1 = '%!PS-AdobeFont';
  PS_MAGICK2 = '%!FontType';
  PS_MAGICK3 = '%!PS-TrueTypeFont';
  PS_MAGICK4 = '%!PS-Adobe-3.0 Resource-CIDFont';

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
  Unescape PostScript string
}
function UnEscape(s: string): string;
const
  MAX_OCTAL_DIGITS = 3;
var
  i,
  s_len,
  del_pos,
  del_len,
  num_pos: SizeInt;
  decimal: longword;
begin
  i := 1;
  s_len := Length(s);

  while i < s_len do
    begin
      if s[i] <> '\' then
        begin
          inc(i);
          continue;
        end;

      case s[i + 1] of
        'n', 'r', 't', 'b', 'f':
          begin
            del_pos := i;
            del_len := 2;
          end;
        '0'..'7':
          begin
            decimal := 0;
            del_len := 0;
            num_pos := i + 1;

            repeat
              decimal := (decimal shl 3) or (ord(s[num_pos]) - ord('0'));
              inc(num_pos);
              inc(del_len);
            until (del_len = MAX_OCTAL_DIGITS) or
                  (num_pos > s_len) or
                  not (s[num_pos] in ['0'..'7']);

            if (decimal < 32) or (decimal > 126) then
              // Ignore invisible and non-ASCII characters
              // TODO: Handle copyright sign especially
              begin
                del_pos := i;
                inc(del_len);
              end
            else
              begin
                s[i] := char(decimal);
                inc(i);
                del_pos := i;
              end;
          end
      else
        // Ignore backslash
        del_pos := i;
        del_len := 1;
      end;

      delete(s, del_pos, del_len);
      dec(s_len, del_len);
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


procedure GetPSInfo(stream: TStream; var info: TFontInfo);
var
  t: text;
  p,
  val_start: SizeInt;
  s,
  key: string;
  idx: TFieldIndex;
  num_found: longint = 0;
begin
  AssignStream(t, stream);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  // Skip header of .pfb file, if any.
  if stream.ReadWordLE = BIN_MAGICK then
    stream.Seek(SizeOf(TBinHeader.ascii_length), fsFromCurrent)
  else
    stream.Seek(0, fsFromBeginning);

  ReadLn(t, s);
  if not (
     (s <> '') and
     (AnsiStartsStr(PS_MAGICK1, s) or
      AnsiStartsStr(PS_MAGICK2, s) or
      AnsiStartsStr(PS_MAGICK3, s) or
      AnsiStartsStr(PS_MAGICK4, s))) then
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
        IDX_FORMAT: info[idx] := 'PS ' + ExtractPSValue(s, val_start);
        IDX_PS_NAME: info[idx] := ExtractPSValue(s, val_start);
      else
        info[idx] := ExtractPSString(s, val_start);
      end;

      inc(num_found);
    end;

  info[IDX_STYLE] := ExtractStyle(
    info[IDX_FULL_NAME], info[IDX_FAMILY], info[IDX_STYLE]);
  info[IDX_NUM_FONTS] := '1';

  Close(t);
end;


end.

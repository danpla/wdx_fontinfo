{
  PostScript-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_ps;

interface

uses
  fi_common,
  classes,
  strutils,
  streamio,
  streamex,
  sysutils;


procedure GetPSInfo(stream: TStream; var info: TFontInfo);


implementation

const
  BIN_MAGIC = $0180;

  PS_MAGIC1 = '%!PS-AdobeFont';
  PS_MAGIC2 = '%!FontType';
  PS_MAGIC3 = '%!PS-TrueTypeFont';
  PS_MAGIC4 = '%!PS-Adobe-3.0 Resource-CIDFont';

  // Number of fields we need to find.
  NUM_FIELDS = 7;

type
  TBinHeader = packed record
    magic: word;
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


procedure ReadPS(var t: text; var info: TFontInfo);
var
  p: SizeInt;
  s,
  key: string;
  idx: TFieldIndex;
  num_found: longint = 0;
begin
  repeat
    if EOF(t) then
      raise EStreamError.Create('PS font is empty');

    ReadLn(t, s);
    s := TrimLeft(s);
  until s <> '';

  if not (
     (AnsiStartsStr(PS_MAGIC1, s) or
      AnsiStartsStr(PS_MAGIC2, s) or
      AnsiStartsStr(PS_MAGIC3, s) or
      AnsiStartsStr(PS_MAGIC4, s))) then
    raise EStreamError.Create('Not a PostScript font');

  while (num_found < NUM_FIELDS) and not EOF(t) do
    begin
      ReadLn(t, s);
      s := Trim(s);

      if s = '' then
        continue;

      if s[1] <> '/' then
        if s = 'currentdict end' then
          break
        else
          continue;

      p := PosSetEx([' ', '(', '/'], s, 3);
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

      while s[p] = ' ' do
        inc(p);

      if s[p] = '(' then
        // String
        begin
          inc(p);
          info[idx] := UnEscape(Copy(s, p, RPos(')', s) - p));
        end
      else
        // Literal, number, etc.
        begin
          if s[p] = '/' then
            inc(p);
          info[idx] := Copy(s, p, PosEx(' ', s, p) - p);
        end;

      inc(num_found);
    end;

  if info[IDX_FORMAT] <> '' then
    info[IDX_FORMAT] := 'PS ' + info[IDX_FORMAT];

  info[IDX_STYLE] := ExtractStyle(
    info[IDX_FULL_NAME], info[IDX_FAMILY], info[IDX_STYLE]);
  info[IDX_NUM_FONTS] := '1';
end;


procedure GetPSInfo(stream: TStream; var info: TFontInfo);
var
  t: text;
begin
  try
    AssignStream(t, stream);
    Reset(t);
  except
    on E: EInOutError do
      raise EStreamError.CreateFmt(
        'PS IO error %d: %s',
        [E.ErrorCode, E.Message]);
  end;

  // Skip header of .pfb file, if any.
  if stream.ReadWordLE = BIN_MAGIC then
    stream.Seek(SizeOf(TBinHeader.ascii_length), fsFromCurrent)
  else
    stream.Seek(0, fsFromBeginning);

  try
    ReadPS(t, info);
  finally
    Close(t);
  end;
end;


end.

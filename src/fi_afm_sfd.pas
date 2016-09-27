{
  Adobe Font Metrics and FontForge's Spline Font Database
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_afm_sfd;

interface

uses
  fi_common,
  fi_info_reader,
  classes,
  streamio,
  sysutils;


implementation

type
  TFontFormat = (
    AFM,
    SFD
    );

const
  FONT_IDENT: array [TFontFormat] of record
    name,
    sign: string;
    extensions: array [0..0] of string;
  end = (
    (name: 'AFM';
     sign: 'StartFontMetrics';
     extensions: ('.afm')),
    (name: 'SFD';
     sign: 'SplineFontDB:';
     extensions: ('.sfd')));

  NUM_FIELDS = 6;
  MAX_LINES = 30;


procedure GetCommonInfo(
  var t: text; var info: TFontInfo; font_format: TFontFormat);
var
  i: longint;
  s: string;
  s_len: SizeInt;
  key: string;
  p: SizeInt;
  num_found: longint;
  idx: TFieldIndex;
begin
  repeat
    if EOF(t) then
      raise EStreamError.CreateFmt(
        '%s is empty', [FONT_IDENT[font_format].name]);

    ReadLn(t, s);
    s := Trim(s);
  until s <> '';

  p := Pos(' ', s);
  if (p = 0) or (Copy(s, 1, p - 1) <> FONT_IDENT[font_format].sign) then
    raise EStreamError.CreateFmt(
      'Not a %s font', [FONT_IDENT[font_format].name]);

  while s[p + 1] = ' ' do
    inc(p);

  info[IDX_FORMAT] := FONT_IDENT[font_format].name +
                      Copy(s, p, Length(s) - p + 1);

  i := 1;
  num_found := 0;
  while (num_found < NUM_FIELDS) and (i <= MAX_LINES) and not EOF(t) do
    begin
      ReadLn(t, s);
      s := Trim(s);
      if s = '' then
        continue;

      p := Pos(' ', s);
      if p = 0 then
        continue;

      inc(i);

      if font_format = SFD then
        key := Copy(s, 1, p - 2)  // Skip colon
      else
        key := Copy(s, 1, p - 1);

      case key of
        'FontName': idx := IDX_PS_NAME;
        'FullName': idx := IDX_FULL_NAME;
        'FamilyName': idx := IDX_FAMILY;
        'Weight': idx := IDX_STYLE;
        'Version': idx := IDX_VERSION;
        'Copyright': idx := IDX_COPYRIGHT;  // SFD
        'Notice': idx := IDX_COPYRIGHT;  // AFM
      else
        continue;
      end;

      repeat
        inc(p);
      until s[p] <> ' ';

      s_len := Length(s);
      if (idx = IDX_COPYRIGHT) and
         (font_format = AFM) and
         (s[p] = '(') and
         (s[s_len] = ')') then
        begin
          inc(p);
          dec(s_len);
        end;

      info[idx] := Copy(s, p, s_len - (p - 1));
      inc(num_found);
    end;

  info[IDX_STYLE] := ExtractStyle(
    info[IDX_FULL_NAME], info[IDX_FAMILY], info[IDX_STYLE]);
  info[IDX_NUM_FONTS] := '1';
end;


procedure GetCommonInfo(
  stream: TStream; var info: TFontInfo; font_format: TFontFormat);
var
  t: text;
begin
  try
    AssignStream(t, stream);
    Reset(t);
  except
    on E: EInOutError do
      raise EStreamError.CreateFmt(
        '%s IO error %d: %s',
        [FONT_IDENT[font_format].name, E.ErrorCode, E.Message]);
  end;

  try
    GetCommonInfo(t, info, font_format);
  finally
    Close(t);
  end;
end;


procedure GetAFMInfo(stream: TStream; var info: TFontInfo); inline;
begin
  GetCommonInfo(stream, info, AFM);
end;


procedure GetSFDInfo(stream: TStream; var info: TFontInfo); inline;
begin
  GetCommonInfo(stream, info, SFD);
end;


initialization
  RegisterReader(@GetAFMInfo, FONT_IDENT[AFM].extensions);
  RegisterReader(@GetSFDInfo, FONT_IDENT[SFD].extensions);

end.

// Adobe Font Metrics and FontForge's Spline Font Database

unit fi_afm_sfd;

interface

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
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
  end = (
    (name: 'AFM';
     sign: 'StartFontMetrics'),
    (name: 'SFD';
     sign: 'SplineFontDB:'));

  NUM_FIELDS = 6;
  MAX_LINES = 30;


procedure GetCommonInfo(
  line_reader: TLineReader; var info: TFontInfo; font_format: TFontFormat);
var
  i: longint;
  s: string;
  s_len: SizeInt;
  key: string;
  p: SizeInt;
  dst: pstring;
  num_found: longint;
begin
  repeat
    if not line_reader.ReadLine(s) then
      raise EStreamError.CreateFmt(
        '%s is empty', [FONT_IDENT[font_format].name]);

    s := Trim(s);
  until s <> '';

  p := Pos(' ', s);
  if (p = 0) or (Copy(s, 1, p - 1) <> FONT_IDENT[font_format].sign) then
    raise EStreamError.CreateFmt(
      'Not a %s font', [FONT_IDENT[font_format].name]);

  while s[p + 1] = ' ' do
    inc(p);

  info.format := FONT_IDENT[font_format].name +
    Copy(s, p, Length(s) - p + 1);

  i := 1;
  num_found := 0;
  while
    (num_found < NUM_FIELDS)
    and (i <= MAX_LINES)
    and line_reader.ReadLine(s) do
  begin
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
      'FontName': dst := @info.ps_name;
      'FullName': dst := @info.full_name;
      'FamilyName': dst := @info.family;
      'Weight': dst := @info.style;
      'Version': dst := @info.version;
      'Copyright': dst := @info.copyright;  // SFD
      'Notice': dst := @info.copyright;  // AFM
    else
      continue;
    end;

    repeat
      inc(p);
    until s[p] <> ' ';

    s_len := Length(s);
    if (dst = @info.copyright)
      and (font_format = AFM)
      and (s[p] = '(')
      and (s[s_len] = ')') then
    begin
      inc(p);
      dec(s_len);
    end;

    dst^ := Copy(s, p, s_len - (p - 1));
    inc(num_found);
  end;

  info.style := ExtractStyle(info.full_name, info.family, info.style);
end;


procedure GetCommonInfo(
  stream: TStream; var info: TFontInfo; font_format: TFontFormat);
var
  line_reader: TLineReader;
begin
  line_reader := TLineReader.Create(stream);
  try
    GetCommonInfo(line_reader, info, font_format);
  finally
    line_reader.Free;
  end;
end;


procedure GetAFMInfo(stream: TStream; var info: TFontInfo);
begin
  GetCommonInfo(stream, info, AFM);
end;


procedure GetSFDInfo(stream: TStream; var info: TFontInfo);
begin
  GetCommonInfo(stream, info, SFD);
end;


initialization
  RegisterReader(@GetAFMInfo, ['.afm']);
  RegisterReader(@GetSFDInfo, ['.sfd']);

end.

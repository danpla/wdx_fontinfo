// Adobe Font Metrics and FontForge's Spline Font Database

unit fi_afm_sfd;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
  sysutils;


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


procedure ReadCommonInfo(
  lineReader: TLineReader; var info: TFontInfo; fontFormat: TFontFormat);
var
  i: longint;
  s: string;
  sLen: SizeInt;
  key: string;
  p: SizeInt;
  dst: pstring;
  numFound: longint;
begin
  repeat
    if not lineReader.ReadLine(s) then
      raise EStreamError.CreateFmt(
        '%s is empty', [FONT_IDENT[fontFormat].name]);

    s := Trim(s);
  until s <> '';

  p := Pos(' ', s);
  if (p = 0) or (Copy(s, 1, p - 1) <> FONT_IDENT[fontFormat].sign) then
    raise EStreamError.CreateFmt(
      'Not a %s font', [FONT_IDENT[fontFormat].name]);

  while s[p + 1] = ' ' do
    inc(p);

  info.format := FONT_IDENT[fontFormat].name +
    Copy(s, p, Length(s) - p + 1);

  i := 1;
  numFound := 0;
  while
    (numFound < NUM_FIELDS)
    and (i <= MAX_LINES)
    and lineReader.ReadLine(s) do
  begin
    s := Trim(s);
    if s = '' then
      continue;

    p := Pos(' ', s);
    if p = 0 then
      continue;

    inc(i);

    if fontFormat = SFD then
      key := Copy(s, 1, p - 2)  // Skip colon
    else
      key := Copy(s, 1, p - 1);

    case key of
      'FontName': dst := @info.psName;
      'FullName': dst := @info.fullName;
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

    sLen := Length(s);
    if (dst = @info.copyright)
      and (fontFormat = AFM)
      and (s[p] = '(')
      and (s[sLen] = ')') then
    begin
      inc(p);
      dec(sLen);
    end;

    dst^ := Copy(s, p, sLen - (p - 1));
    inc(numFound);
  end;

  info.style := ExtractStyle(info.fullName, info.family, info.style);
end;


procedure ReadCommonInfo(
  stream: TStream; var info: TFontInfo; fontFormat: TFontFormat);
var
  lineReader: TLineReader;
begin
  lineReader := TLineReader.Create(stream);
  try
    ReadCommonInfo(lineReader, info, fontFormat);
  finally
    lineReader.Free;
  end;
end;


procedure ReadAFMInfo(stream: TStream; var info: TFontInfo);
begin
  ReadCommonInfo(stream, info, AFM);
end;


procedure ReadSFDInfo(stream: TStream; var info: TFontInfo);
begin
  ReadCommonInfo(stream, info, SFD);
end;


initialization
  RegisterReader(@ReadAFMInfo, ['.afm']);
  RegisterReader(@ReadSFDInfo, ['.sfd']);


end.

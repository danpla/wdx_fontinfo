//  Bitmap Distribution Format

unit fi_bdf;

interface

uses
  fi_common;


const
  BDF_COPYRIGHT = 'COPYRIGHT';
  BDF_FACE_NAME = 'FACE_NAME';
  BDF_FAMILY_NAME = 'FAMILY_NAME';
  BDF_FONT = 'FONT';
  BDF_FONT_VERSION = 'FONT_VERSION';
  BDF_FOUNDRY = 'FOUNDRY';
  BDF_FULL_NAME = 'FULL_NAME';
  BDF_WEIGHT_NAME = 'WEIGHT_NAME';

{
  Fill empty family, style, and fullName with information from existing fields.
}
procedure BDF_FillEmpty(var info: TFontInfo);


implementation

uses
  fi_info_reader,
  line_reader,
  classes,
  strutils,
  sysutils;


const
  BDF_SIGN = 'STARTFONT';

  NUM_FIELDS = 7;
  MAX_LINES = 30;


procedure BDF_FillEmpty(var info: TFontInfo);
begin
  if (info.family = '') and (info.psName <> '') then
    info.family := info.psName;

  if info.style = '' then
    info.style := 'Medium';

  if info.fullName = '' then
    if info.style = 'Medium' then
      info.fullName := info.family
    else
      info.fullName := info.family + ' ' + info.style;
end;


procedure ReadBDF(lineReader: TLineReader; var info: TFontInfo);
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
      raise EStreamError.Create('BDF is empty');

    s := Trim(s);
  until s <> '';

  p := Pos(' ', s);
  if (p = 0) or (Copy(s, 1, p - 1) <> BDF_SIGN) then
    raise EStreamError.Create('Not a BDF font');

  while s[p + 1] = ' ' do
    inc(p);

  info.format := 'BDF' + Copy(s, p, Length(s) - p + 1);

  i := 1;
  numFound := 0;
  while
    (numFound < NUM_FIELDS)
    and (i <= MAX_LINES)
    and lineReader.ReadLine(s) do
  begin
    s := Trim(s);

    case s of
      '': continue;
      'ENDPROPERTIES': break;
    end;

    if AnsiStartsStr('COMMENT', s) then
      continue;

    p := Pos(' ', s);
    if p = 0 then
      {
        Assuming that global info goes before glyphs, all lines
        (except comments, which can be empty) should be key-value
        pairs separated by spaces.
      }
      raise EStreamError.CreateFmt('BDF has no space in line "%s"', [s]);

    inc(i);

    key := Copy(s, 1, p - 1);
    case key of
      BDF_COPYRIGHT: dst := @info.copyright;
      BDF_FAMILY_NAME: dst := @info.family;
      BDF_FONT: dst := @info.psName;
      BDF_FONT_VERSION: dst := @info.version;
      BDF_FOUNDRY: dst := @info.manufacturer;
      BDF_FULL_NAME, BDF_FACE_NAME: dst := @info.fullName;
      BDF_WEIGHT_NAME: dst := @info.style;
      'CHARS': break;
    else
      continue;
    end;

    repeat
      inc(p);
    until s[p] <> ' ';

    sLen := Length(s);

    if (s[p] = '"') and (s[sLen] = '"') then
    begin
      inc(p);
      dec(sLen);
    end;

    dst^ := Copy(s, p, sLen - (p - 1));
    inc(numFound);
  end;

  BDF_FillEmpty(info);
end;


procedure ReadBDFInfo(stream: TStream; var info: TFontInfo);
var
  lineReader: TLineReader;
begin
  lineReader := TLineReader.Create(stream);
  try
    ReadBDF(lineReader, info);
  finally
    lineReader.Free;
  end;
end;


initialization
  RegisterReader(@ReadBDFInfo, ['.bdf']);


end.

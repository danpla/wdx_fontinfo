{
  Bitmap Distribution Format
}

{$MODE OBJFPC}
{$H+}

unit fi_bdf;

interface

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
  strutils,
  sysutils;


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
  Fill empty family, style, and full_name with information from existing fields.
}
procedure BDF_FillEmpty(var info: TFontInfo);


implementation

const
  BDF_SIGN = 'STARTFONT';

  NUM_FIELDS = 7;
  MAX_LINES = 30;


procedure BDF_FillEmpty(var info: TFontInfo);
begin
  if (info.family = '') and (info.ps_name <> '') then
    info.family := info.ps_name;

  if info.style = '' then
    info.style := 'Medium';

  if info.full_name = '' then
    if info.style = 'Medium' then
      info.full_name := info.family
    else
      info.full_name := info.family + ' ' + info.style;
end;


procedure ReadBDF(line_reader: TLineReader; var info: TFontInfo);
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
  num_found := 0;
  while
    (num_found < NUM_FIELDS)
    and (i <= MAX_LINES)
    and line_reader.ReadLine(s) do
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
      BDF_FONT: dst := @info.ps_name;
      BDF_FONT_VERSION: dst := @info.version;
      BDF_FOUNDRY: dst := @info.manufacturer;
      BDF_FULL_NAME, BDF_FACE_NAME: dst := @info.full_name;
      BDF_WEIGHT_NAME: dst := @info.style;
      'CHARS': break;
    else
      continue;
    end;

    repeat
      inc(p);
    until s[p] <> ' ';

    s_len := Length(s);

    if (s[p] = '"') and (s[s_len] = '"') then
    begin
      inc(p);
      dec(s_len);
    end;

    dst^ := Copy(s, p, s_len - (p - 1));
    inc(num_found);
  end;

  BDF_FillEmpty(info);
end;


procedure GetBDFInfo(stream: TStream; var info: TFontInfo);
var
  line_reader: TLineReader;
begin
  line_reader := TLineReader.Create(stream);
  try
    ReadBDF(line_reader, info);
  finally
    line_reader.Free;
  end;
end;


initialization
  RegisterReader(@GetBDFInfo, ['.bdf']);


end.

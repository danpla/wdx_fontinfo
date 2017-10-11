{
  BDF (Bitmap Distribution Format)
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

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
  BDF_FAMILY_NAME = 'FAMILY_NAME';
  BDF_FONT = 'FONT';
  BDF_FOUNDRY = 'FOUNDRY';
  BDF_FULL_NAME = 'FULL_NAME';
  BDF_FACE_NAME = 'FACE_NAME';
  BDF_WEIGHT_NAME = 'WEIGHT_NAME';

{
  Fill empty fields with information from existing ones:
    IDX_FAMILY
    IDX_STYLE
    IDX_FULL_NAME
}
procedure BDF_FillEmpty(var info: TFontInfo);


implementation

const
  BDF_EXTENSIONS: array [0..0] of string = ('.bdf');
  BDF_SIGN = 'STARTFONT';

  NUM_FIELDS = 6;
  MAX_LINES = 30;


procedure BDF_FillEmpty(var info: TFontInfo);
begin
  if (info[IDX_FAMILY] = '') and (info[IDX_PS_NAME] <> '') then
    info[IDX_FAMILY] := info[IDX_PS_NAME];

  if info[IDX_STYLE] = '' then
    info[IDX_STYLE] := 'Medium';

  if info[IDX_FULL_NAME] = '' then
    if info[IDX_STYLE] = 'Medium' then
      info[IDX_FULL_NAME] := info[IDX_FAMILY]
    else
      info[IDX_FULL_NAME] := info[IDX_FAMILY] + ' ' + info[IDX_STYLE];
end;


procedure ReadBDF(line_reader: TLineReader; var info: TFontInfo);
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
    if not line_reader.ReadLine(s) then
      raise EStreamError.Create('BDF is empty');

    s := Trim(s);
  until s <> '';

  p := Pos(' ', s);
  if (p = 0) or (Copy(s, 1, p - 1) <> BDF_SIGN) then
    raise EStreamError.Create('Not a BDF font');

  while s[p + 1] = ' ' do
    inc(p);

  info[IDX_FORMAT] := 'BDF' + Copy(s, p, Length(s) - p + 1);

  i := 1;
  num_found := 0;
  while (
      (num_found < NUM_FIELDS)
      and (i <= MAX_LINES)
      and line_reader.ReadLine(s)) do
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
        BDF_COPYRIGHT: idx := IDX_COPYRIGHT;
        BDF_FAMILY_NAME: idx := IDX_FAMILY;
        BDF_FONT: idx := IDX_PS_NAME;
        BDF_FOUNDRY: idx := IDX_MANUFACTURER;
        BDF_FULL_NAME, BDF_FACE_NAME: idx := IDX_FULL_NAME;
        BDF_WEIGHT_NAME: idx := IDX_STYLE;
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

      info[idx] := Copy(s, p, s_len - (p - 1));
      inc(num_found);
    end;

  BDF_FillEmpty(info);

  info[IDX_NUM_FONTS] := '1';
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
  RegisterReader(@GetBDFInfo, BDF_EXTENSIONS);


end.

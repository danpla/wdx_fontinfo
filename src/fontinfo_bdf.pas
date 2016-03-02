{
  BDF (Bitmap Distribution Format)
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_bdf;

interface

uses
  fontinfo_common,
  classes,
  streamio,
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

procedure GetBDFInfo(stream: TStream; var info: TFontInfo);

implementation

const
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


procedure ReadBDF(var t: text; var info: TFontInfo);
var
  sign: string[Length(BDF_SIGN)];
  version: string;
  i: longint;
  s: string;
  s_len: SizeInt;
  key: string;
  p: SizeInt;
  num_found: longint;
  idx: TFieldIndex;
begin
  ReadLn(t, sign, version);
  if sign <> BDF_SIGN then
    raise EStreamError.Create('Not a BDF font');

  info[IDX_FORMAT] := 'BDF ' + Trim(version);

  i := 1;
  num_found := 0;
  while (num_found < NUM_FIELDS) and (i <= MAX_LINES) and not EOF(t) do
    begin
      ReadLn(t, s);
      s := Trim(s);

      case s of
        '': continue;
        'ENDPROPERTIES': break;
      end;

      p := Pos(' ', s);
      if p = 0 then
        raise EStreamError.CreateFmt('BDF has no space in line "%s"', [s]);

      key := Copy(s, 1, p - 1);
      if key = 'COMMENT' then
        continue;

      inc(i);

      case key of
        BDF_COPYRIGHT: idx := IDX_COPYRIGHT;
        BDF_FAMILY_NAME: idx := IDX_FAMILY;
        BDF_FONT: idx := IDX_PS_NAME;
        BDF_FOUNDRY: idx := IDX_MANUFACTURER;
        BDF_FULL_NAME, BDF_FACE_NAME: idx := IDX_FULL_NAME;
        BDF_WEIGHT_NAME: idx := IDX_STYLE;
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
  t: text;
begin
  try
    AssignStream(t, stream);
    Reset(t);
  except
    on E: EInOutError do
      raise EStreamError.CreateFmt(
        'PCF IO error %d: %s',
        [E.ErrorCode, E.Message]);
  end;

  try
    ReadBDF(t, info);
  finally
    Close(t);
  end;
end;


end.

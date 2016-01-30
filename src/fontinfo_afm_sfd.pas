{
  Adobe Font Metrics and FontForge's Spline Font Database
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_afm_sfd;

interface

uses
  fontinfo_common,
  classes,
  streamio,
  sysutils;


procedure GetAFMInfo(stream: TStream; var info: TFontInfo); inline;
procedure GetSFDInfo(stream: TStream; var info: TFontInfo); inline;

implementation

type
  TFontFormat = (
    AFM,
    SFD
    );

const
  AFM_SIGN = 'StartFontMetrics';
  SFD_SIGN = 'SplineFontDB:';

  FONT_FORMAT_STR: array[TFontFormat] of string = (
    'AFM',
    'SFD'
    );

  NUM_FIELDS = 6; // Number of fields we need to find.
  MAX_LINES = 30;


procedure GetCommonInfo(stream: TStream; var info: TFontInfo);
var
  t: text;
  font_format: TFontFormat;
  i: longint;
  s: string;
  s_len: SizeInt;
  key: string;
  p: SizeInt;
  num_found: longint;
  idx: TFieldIndex;
begin
  AssignStream(t, stream);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  ReadLn(t, s);
  p := Pos(' ', s);
  if p = 0 then
    begin
      Close(t);
      exit;
    end;

  case Copy(s, 1, p - 1) of
    AFM_SIGN: font_format := AFM;
    SFD_SIGN: font_format := SFD;
  else
    Close(t);
    exit;
  end;

  info[IDX_FORMAT] := FONT_FORMAT_STR[font_format] +
                      Copy(s, p, Length(s) - p + 1);

  i := 1;
  num_found := 0;
  while (num_found < NUM_FIELDS) and (i <= MAX_LINES) and not EOF(t) do
    begin
      ReadLn(t, s);
      if s = '' then
        break;

      s_len := Length(s);
      p := Pos(' ', s);
      if (p < 2) or (p = s_len) then
        continue;

      inc(i);

      if font_format = SFD then
        // Skip colon in SFD.
        key := Copy(s, 1, p - 2)
      else
        key := Copy(s, 1, p - 1);

      case key of
        'FontName': idx := IDX_PS_NAME;
        'FullName': idx := IDX_FULL_NAME;
        'FamilyName': idx := IDX_FAMILY;
        'Weight': idx := IDX_STYLE;
        'Copyright': idx := IDX_COPYRIGHT;
        'Notice':
          begin
            if (font_format = SFD) and
               (s[p + 1] = '(') and (s[s_len] = ')') then
              begin
                inc(p);
                dec(s_len);
              end;

            idx := IDX_COPYRIGHT;
          end;
        'Version': idx := IDX_VERSION;
      else
        continue;
      end;

      info[idx] := Copy(s, p + 1, s_len - p);
      inc(num_found);
    end;

  info[IDX_STYLE] := ExtractStyle(
    info[IDX_FULL_NAME], info[IDX_FAMILY], info[IDX_STYLE]);
  info[IDX_NUM_FONTS] := '1';

  Close(t);
end;


procedure GetAFMInfo(stream: TStream; var info: TFontInfo); inline;
begin
  GetCommonInfo(stream, info);
end;

procedure GetSFDInfo(stream: TStream; var info: TFontInfo); inline;
begin
  GetCommonInfo(stream, info);
end;

end.

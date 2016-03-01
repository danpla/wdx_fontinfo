{
  INF (INFormation)
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_inf;

interface

uses
  fontinfo_common,
  classes,
  streamio,
  sysutils;


procedure GetINFInfo(stream: TStream; var info: TFontInfo);


implementation

const
  NUM_FIELDS = 4;
  MAX_LINES = 10;


procedure GetINFInfo(stream: TStream; var info: TFontInfo);
var
  t: text;
  i,
  num_found: longint;
  s: string;
  p: SizeInt;
  key: string;
  idx: TFieldIndex;
begin
  try
    AssignStream(t, stream);
    Reset(t);
  except
    on E: EInOutError do
      raise EStreamError.CreateFmt(
        'INF IO error %d: %s',
        [E.ErrorCode, E.Message]);
  end;

  try
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
          raise EStreamError.CreateFmt('INF has no space in line "%s"', [s]);

        inc(i);

        key := Copy(s, 1, p - 1);
        case key of
          'FontName': idx := IDX_PS_NAME;
          'FullName': idx := IDX_FULL_NAME;
          'FamilyName': idx := IDX_FAMILY;
          'Version': idx := IDX_VERSION;
        else
          continue;
        end;

        repeat
          inc(p);
        until s[p] <> ' ';

        info[idx] := Copy(s, p + 1, Length(s) - p - 1);  // Skipping brackets
        inc(num_found);
      end;

    if num_found = 0 then
      raise EStreamError.Create(
        'INF file does not have any known fields; ' +
        'probably not a font-related INF');

    info[IDX_STYLE] := ExtractStyle(info[IDX_FULL_NAME], info[IDX_FAMILY]);
    info[IDX_FORMAT] := 'INF';
    info[IDX_NUM_FONTS] := '1';
  finally
    Close(t);
  end;
end;


end.

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
  sysutils;


procedure GetINFInfo(const FileName: string; var info: TFontInfo);


implementation

const
  NUM_FIELDS = 4;
  MAX_LINES = 10;


procedure GetINFInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  p,
  i,
  num_found: longint;
  s: string;
  s_len: longint;
  key: string;
  idx: TFieldIndex;
begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

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
        break;

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

      info[idx] := Copy(s, p + 2, s_len - p - 2);  // Skipping brackets
      inc(num_found);
    end;

  info[IDX_STYLE] := ExtractStyle(info[IDX_FULL_NAME], info[IDX_FAMILY]);
  info[IDX_FORMAT] := 'INF';
  info[IDX_NUM_FONTS] := '1';

  Close(t);
end;


end.

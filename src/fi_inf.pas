{
  INF
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_inf;

interface

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
  sysutils;


implementation

const
  NUM_FIELDS = 4;
  MAX_LINES = 10;


procedure ReadINF(line_reader: TLineReader; var info: TFontInfo);
var
  i,
  num_found: longint;
  s: string;
  p: SizeInt;
  key: string;
  dst: pstring;
begin
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
      raise EStreamError.CreateFmt(
        'INF has no space in line "%s"', [s]);

    inc(i);

    key := Copy(s, 1, p - 1);
    case key of
      'FontName': dst := @info.ps_name;
      'FullName': dst := @info.full_name;
      'FamilyName': dst := @info.family;
      'Version': dst := @info.version;
    else
      continue;
    end;

    repeat
      inc(p);
    until s[p] <> ' ';

    dst^ := Copy(s, p + 1, Length(s) - p - 1);  // Skipping brackets
    inc(num_found);
  end;

  if num_found = 0 then
    raise EStreamError.Create(
      'INF file does not have any known fields; ' +
      'probably not a font-related INF');

  info.style := ExtractStyle(info.full_name, info.family);
  info.format := 'INF';
end;


procedure GetINFInfo(stream: TStream; var info: TFontInfo);
var
  line_reader: TLineReader;
begin
  line_reader := TLineReader.Create(stream);
  try
    ReadINF(line_reader, info);
  finally
    line_reader.Free;
  end;
end;


initialization
  RegisterReader(@GetINFInfo, ['.inf']);


end.

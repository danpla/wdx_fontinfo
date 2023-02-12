unit fi_inf;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
  sysutils;


const
  NUM_FIELDS = 4;
  MAX_LINES = 10;


procedure ReadINF(lineReader: TLineReader; var info: TFontInfo);
var
  i,
  numFound: longint;
  s: string;
  p: SizeInt;
  key: string;
  dst: pstring;
begin
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
      raise EStreamError.CreateFmt(
        'INF has no space in line "%s"', [s]);

    inc(i);

    key := Copy(s, 1, p - 1);
    case key of
      'FontName': dst := @info.psName;
      'FullName': dst := @info.fullName;
      'FamilyName': dst := @info.family;
      'Version': dst := @info.version;
    else
      continue;
    end;

    repeat
      inc(p);
    until s[p] <> ' ';

    dst^ := Copy(s, p + 1, Length(s) - p - 1);  // Skipping brackets
    inc(numFound);
  end;

  if numFound = 0 then
    raise EStreamError.Create(
      'INF file does not have any known fields; ' +
      'probably not a font-related INF');

  info.style := ExtractStyle(info.fullName, info.family);
  info.format := 'INF';
end;


procedure ReadINFInfo(stream: TStream; var info: TFontInfo);
var
  lineReader: TLineReader;
begin
  lineReader := TLineReader.Create(stream);
  try
    ReadINF(lineReader, info);
  finally
    lineReader.Free;
  end;
end;


initialization
  RegisterReader(@ReadINFInfo, ['.inf']);


end.

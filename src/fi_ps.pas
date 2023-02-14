// PostScript-based fonts

unit fi_ps;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  line_reader,
  classes,
  strutils,
  streamex,
  sysutils;


const
  PS_MAGIC1 = '%!PS-AdobeFont';
  PS_MAGIC2 = '%!FontType';
  PS_MAGIC3 = '%!PS-TrueTypeFont';
  PS_MAGIC4 = '%!PS-Adobe-3.0 Resource-CIDFont';

  // Number of fields we need to find.
  NUM_FIELDS = 7;


function UnEscape(s: String): String;
const
  OCTAL_DIGITS = ['0'..'7'];
  MAX_OCTAL_DIGITS = 3;

  MAX_ASCII = 127;
  PRINTABLE_ASCII = [32..126];

  COPYRIGHT = $a9;
  COPYRIGHT_UTF8: array [0..1] of Byte = ($c2, $a9);
  REPLACEMENT_UTF8: array [0..2] of Byte = ($ef, $bf, $bd);
var
  src: PChar;
  dst: PChar;
  octLen,
  decimal: LongWord;
begin
  if s = '' then
    exit(s);

  SetLength(result, Length(s));

  src := PChar(s);
  dst := PChar(result);
  while src^ <> #0 do
  begin
    // We skip non-printable Characters; non-ASCII values are not allowed
    // by the specification (they should always be escaped).
    if not (Byte(src^) in PRINTABLE_ASCII) then
    begin
      Inc(src);
      continue;
    end;

    if src^ <> '\' then
    begin
      dst^ := src^;
      Inc(src);
      Inc(dst);
      continue;
    end;

    // A backslash is always ignored
    Inc(src);

    if src^ in OCTAL_DIGITS then
    begin
      decimal := 0;
      octLen := 0;

      repeat
        decimal := (decimal shl 3) or (Byte(src^) - Byte('0'));
        Inc(src);
        Inc(octLen);
      until (octLen = MAX_OCTAL_DIGITS) or not (src^ in OCTAL_DIGITS);

      if decimal in PRINTABLE_ASCII then
      begin
        dst^ := Char(decimal);
        Inc(dst);
      end
      // If decimal value is >= 64, we guaranteed to have 4 free
      // Bytes in dst (skipped backslash + 3 octal digits) to insert
      // a UTF-8 encoded Character.
      else if decimal = COPYRIGHT then
      begin
        Move(COPYRIGHT_UTF8, dst^, SizeOf(COPYRIGHT_UTF8));
        Inc(dst, SizeOf(COPYRIGHT_UTF8));
      end
      // We don't handle any non-ASCII symbols except a copyright sign,
      // because they can be in any possible code page (although most
      // of the fonts I've seen used Mac OS Roman).
      else if decimal > MAX_ASCII then
      begin
        Move(REPLACEMENT_UTF8, dst^, SizeOf(REPLACEMENT_UTF8));
        Inc(dst, SizeOf(REPLACEMENT_UTF8));
      end;
    end
    else if Byte(src^) in PRINTABLE_ASCII then
    begin
      if src^ = 't' then
        dst^ := ' '
      else if not (src^ in ['b', 'f', 'n', 'r']) then
        dst^ := src^;

      Inc(src);
      Inc(dst);
    end;
  end;

  SetLength(result, dst - PChar(result));
end;


procedure ReadPS(lineReader: TLineReader; var info: TFontInfo);
var
  p: SizeInt;
  s,
  key: String;
  dst: PString;
  numFound: LongInt = 0;
begin
  repeat
    if not lineReader.ReadLine(s) then
      raise EStreamError.Create('PS font is empty');

    s := TrimLeft(s);
  until s <> '';

  if not (
      AnsiStartsStr(PS_MAGIC1, s)
      or AnsiStartsStr(PS_MAGIC2, s)
      or AnsiStartsStr(PS_MAGIC3, s)
      or AnsiStartsStr(PS_MAGIC4, s)) then
    raise EStreamError.Create('Not a PostScript font');

  while (numFound < NUM_FIELDS) and lineReader.ReadLine(s) do
  begin
    s := Trim(s);

    if s = '' then
      continue;

    if s[1] <> '/' then
      if s = 'currentdict end' then
        break
      else
        continue;

    p := PosSetEx([' ', '(', '/'], s, 3);
    if p = 0 then
      continue;

    key := Copy(s, 2, p - 2);
    case key of
      'FontType': dst := @info.format;
      'FontName': dst := @info.psName;
      'version': dst := @info.version;
      // CFF format allows "Copyright" in addition to "Notice".
      'Notice', 'Copyright': dst := @info.copyright;
      'FullName': dst := @info.fullName;
      'FamilyName': dst := @info.family;
      'Weight': dst := @info.style;
    else
      continue;
    end;

    while s[p] = ' ' do
      Inc(p);

    if s[p] = '(' then
    // String
    begin
      Inc(p);
      dst^ := UnEscape(Copy(s, p, RPos(')', s) - p));
    end
    else
    // Literal name, number, etc.
    begin
      if s[p] = '/' then
        Inc(p);
      dst^ := Copy(s, p, PosEx(' ', s, p) - p);
    end;

    Inc(numFound);
  end;

  if info.format <> '' then
    info.format := 'PS ' + info.format;

  info.style := ExtractStyle(info.fullName, info.family, info.style);
end;


procedure ReadPSInfo(stream: TStream; var info: TFontInfo);
const
  BIN_MAGIC = $0180;
var
  lineReader: TLineReader;
begin
  // Skip header of .pfb file, if any.
  if stream.ReadWordLE = BIN_MAGIC then
    // Skip ASCII length
    stream.Seek(SizeOf(LongWord), soCurrent)
  else
    stream.Seek(0, soBeginning);

  lineReader := TLineReader.Create(stream);
  try
    ReadPS(lineReader, info);
  finally
    lineReader.Free;
  end;
end;


initialization
  RegisterReader(
    @ReadPSInfo, ['.ps','.pfa','.pfb','.pt3','.t11','.t42']);


end.

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
  BIN_MAGIC = $0180;

  PS_MAGIC1 = '%!PS-AdobeFont';
  PS_MAGIC2 = '%!FontType';
  PS_MAGIC3 = '%!PS-TrueTypeFont';
  PS_MAGIC4 = '%!PS-Adobe-3.0 Resource-CIDFont';

  // Number of fields we need to find.
  NUM_FIELDS = 7;


type
  TBinHeader = packed record
    magic: word;
    asciiLen: longword;
  end;


function UnEscape(s: string): string;
const
  OCTAL_DIGITS = ['0'..'7'];
  MAX_OCTAL_DIGITS = 3;

  MAX_ASCII = 127;
  PRINTABLE_ASCII = [32..126];

  COPYRIGHT = $a9;
  COPYRIGHT_UTF8: array [0..1] of byte = ($c2, $a9);
  REPLACEMENT_UTF8: array [0..2] of byte = ($ef, $bf, $bd);
var
  src: PChar;
  dst: PChar;
  octLen,
  decimal: longword;
begin
  if s = '' then
    exit(s);

  SetLength(result, Length(s));

  src := PChar(s);
  dst := PChar(result);
  while src^ <> #0 do
  begin
    // We skip non-printable characters; non-ASCII values are not allowed
    // by the specification (they should always be escaped).
    if not (byte(src^) in PRINTABLE_ASCII) then
    begin
      inc(src);
      continue;
    end;

    if src^ <> '\' then
    begin
      dst^ := src^;
      inc(src);
      inc(dst);
      continue;
    end;

    // A backslash is always ignored
    inc(src);

    if src^ in OCTAL_DIGITS then
    begin
      decimal := 0;
      octLen := 0;

      repeat
        decimal := (decimal shl 3) or (byte(src^) - byte('0'));
        inc(src);
        inc(octLen);
      until (octLen = MAX_OCTAL_DIGITS) or not (src^ in OCTAL_DIGITS);

      if decimal in PRINTABLE_ASCII then
      begin
        dst^ := char(decimal);
        inc(dst);
      end
      // If decimal value is >= 64, we guaranteed to have 4 free
      // bytes in dst (skipped backslash + 3 octal digits) to insert
      // a UTF-8 encoded character.
      else if decimal = COPYRIGHT then
      begin
        Move(COPYRIGHT_UTF8, dst^, SizeOf(COPYRIGHT_UTF8));
        inc(dst, SizeOf(COPYRIGHT_UTF8));
      end
      // We don't handle any non-ASCII symbols except a copyright sign,
      // because they can be in any possible code page (although most
      // of the fonts I've seen used Mac OS Roman).
      else if decimal > MAX_ASCII then
      begin
        Move(REPLACEMENT_UTF8, dst^, SizeOf(REPLACEMENT_UTF8));
        inc(dst, SizeOf(REPLACEMENT_UTF8));
      end;
    end
    else if byte(src^) in PRINTABLE_ASCII then
    begin
      if src^ = 't' then
        dst^ := ' '
      else if not (src^ in ['b', 'f', 'n', 'r']) then
        dst^ := src^;

      inc(src);
      inc(dst);
    end;
  end;

  SetLength(result, dst - PChar(result));
end;


procedure ReadPS(lineReader: TLineReader; var info: TFontInfo);
var
  p: SizeInt;
  s,
  key: string;
  dst: pstring;
  numFound: longint = 0;
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
      inc(p);

    if s[p] = '(' then
    // String
    begin
      inc(p);
      dst^ := UnEscape(Copy(s, p, RPos(')', s) - p));
    end
    else
    // Literal name, number, etc.
    begin
      if s[p] = '/' then
        inc(p);
      dst^ := Copy(s, p, PosEx(' ', s, p) - p);
    end;

    inc(numFound);
  end;

  if info.format <> '' then
    info.format := 'PS ' + info.format;

  info.style := ExtractStyle(info.fullName, info.family, info.style);
end;


procedure GetPSInfo(stream: TStream; var info: TFontInfo);
var
  lineReader: TLineReader;
begin
  // Skip header of .pfb file, if any.
  if stream.ReadWordLE = BIN_MAGIC then
    stream.Seek(SizeOf(TBinHeader.asciiLen), soCurrent)
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
    @GetPSInfo, ['.ps','.pfa','.pfb','.pt3','.t11','.t42']);


end.

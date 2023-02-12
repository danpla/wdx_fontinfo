// Embedded OpenType

unit fi_eot;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes,
  streamex;


const
  EOT_MAGIC = $504c;

  // EOT flags
  TTEMBED_TTCOMPRESSED = $00000004;
  TTEMBED_XORENCRYPTDATA = $10000000;


type
  TEOTHeader = packed record
    eotSize,
    fontDataSize,
    version,
    flags: longword;
    panose: array [0..9] of byte;
    charset,
    italic: byte;
    weight: longword;
    fsType,
    magic: word;
    unicodeRange1,
    unicodeRange2,
    unicodeRange3,
    unicodeRange4,
    codePageRange1,
    codePageRange2,
    checksumAdjustment,
    reserved1,
    reserved2,
    reserved3,
    reserved4: longword;
  end;


function ReadField(stream: TStream; const fieldName: string): string;
var
  padding: word;
  s: UnicodeString;
  sLen: word;
begin
  padding := stream.ReadWordLE;
  if padding <> 0 then
    raise EStreamError.CreateFmt(
      'Non-zero (%u) padding for "%s" EOT field',
      [padding, fieldName]);

  sLen := stream.ReadWordLE;
  SetLength(s, sLen div SizeOf(WideChar));
  stream.ReadBuffer(s[1], sLen);
  {$IFDEF ENDIAN_BIG}
  SwapUnicodeEndian(s);
  {$ENDIF}

  result := UTF8Encode(s);
end;


procedure GetEOTInfo(stream: TStream; var info: TFontInfo);
var
  eotSize,
  fontDataSize,
  flags,
  magic,
  fontOffset: longword;
begin
  eotSize := stream.ReadDWordLE;
  if eotSize <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in EOT header (%u) does not match the file size (%d)',
      [eotSize, stream.Size]);

  fontDataSize := stream.ReadDWordLE;
  if fontDataSize >= eotSize - SizeOf(TEOTHeader) then
    raise EStreamError.CreateFmt(
      'Data size in EOT header (%u) is too big for the actual file size (%u)',
      [fontDataSize, eotSize]);

  stream.Seek(SizeOf(TEOTHeader.version), soCurrent);

  flags := stream.ReadDWordLE;

  stream.Seek(
    SizeOf(TEOTHeader.panose)
    + SizeOf(TEOTHeader.charset)
    + SizeOf(TEOTHeader.italic)
    + SizeOf(TEOTHeader.weight)
    + SizeOf(TEOTHeader.fsType),
    soCurrent);

  magic := stream.ReadWordLE;
  if magic <> EOT_MAGIC then
    raise EStreamError.Create('Not an EOT font');

  if (flags and TTEMBED_TTCOMPRESSED = 0)
    and (flags and TTEMBED_XORENCRYPTDATA = 0) then
  begin
    fontOffset := eotSize - fontDataSize;
    stream.Seek(fontOffset, soBeginning);

    SFNT_GetCommonInfo(stream, info, fontOffset);
    exit;
  end;

  stream.Seek(
    SizeOf(TEOTHeader.unicodeRange1)
    + SizeOf(TEOTHeader.unicodeRange2)
    + SizeOf(TEOTHeader.unicodeRange3)
    + SizeOf(TEOTHeader.unicodeRange4)
    + SizeOf(TEOTHeader.codePageRange1)
    + SizeOf(TEOTHeader.codePageRange2)
    + SizeOf(TEOTHeader.checksumAdjustment)
    + SizeOf(TEOTHeader.reserved1)
    + SizeOf(TEOTHeader.reserved2)
    + SizeOf(TEOTHeader.reserved3)
    + SizeOf(TEOTHeader.reserved4),
    soCurrent);

  info.family := ReadField(stream, 'FamilyName');
  info.style := ReadField(stream, 'StyleName');
  info.version := ReadField(stream, 'VersionName');
  info.fullName := ReadField(stream, 'FullName');

  // Currently we can't decompress EOT to determine SFNT format.
  info.format := 'EOT';
end;


initialization
  RegisterReader(@GetEOTInfo, ['.eot']);


end.

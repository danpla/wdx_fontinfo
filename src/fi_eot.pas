{
  Embedded OpenType
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_eot;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt_common,
  classes,
  streamex;


implementation


const
  EOT_MAGIC = $504c;

  // EOT flags
  TTEMBED_TTCOMPRESSED = $00000004;
  TTEMBED_XORENCRYPTDATA = $10000000;

type
  TEOTHeader = packed record
    eot_size,
    font_data_size,
    version,
    flags: longword;
    panose: array [0..9] of byte;
    charset,
    italic: byte;
    weight: longword;
    fs_type,
    magic: word;
    unicode_range1,
    unicode_range2,
    unicode_range3,
    unicode_range4,
    code_page_range1,
    code_page_range2,
    checksum_adjustment,
    reserved1,
    reserved2,
    reserved3,
    reserved4: longword;
  end;

function ReadField(stream: TStream; const field_name: string): string;
var
  padding: word;
  s: UnicodeString;
  s_len: word;
begin
  padding := stream.ReadWordLE;
  if padding <> 0 then
    raise EStreamError.CreateFmt(
      'Non-zero (%u) padding for "%s" EOT field',
      [padding, field_name]);

  s_len := stream.ReadWordLE;
  SetLength(s, s_len div SizeOf(WideChar));
  stream.ReadBuffer(s[1], s_len);
  {$IFDEF ENDIAN_BIG}
  SwapUnicode(s);
  {$ENDIF}

  result := UTF8Encode(s);
end;

procedure GetEOTInfo(stream: TStream; var info: TFontInfo);
var
  eot_size,
  font_data_size,
  flags,
  magic,
  font_offset: longword;
begin
  eot_size := stream.ReadDWordLE;
  if eot_size <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in EOT header (%u) does not match the file size (%d)',
      [eot_size, stream.Size]);

  font_data_size := stream.ReadDWordLE;
  if font_data_size >= eot_size - SizeOf(TEOTHeader) then
    raise EStreamError.CreateFmt(
      'Data size in EOT header (%u) is too big for the actual file size (%u)',
      [font_data_size, eot_size]);

  stream.Seek(SizeOf(TEOTHeader.version), soCurrent);

  flags := stream.ReadDWordLE;

  stream.Seek(
    SizeOf(TEOTHeader.panose)
    + SizeOf(TEOTHeader.charset)
    + SizeOf(TEOTHeader.italic)
    + SizeOf(TEOTHeader.weight)
    + SizeOf(TEOTHeader.fs_type),
    soCurrent);

  magic := stream.ReadWordLE;
  if magic <> EOT_MAGIC then
    raise EStreamError.Create('Not an EOT font');

  if (flags and TTEMBED_TTCOMPRESSED = 0)
    and (flags and TTEMBED_XORENCRYPTDATA = 0) then
  begin
    font_offset := eot_size - font_data_size;
    stream.Seek(font_offset, soBeginning);

    GetCommonInfo(stream, info, font_offset);
    exit;
  end;

  stream.Seek(
    SizeOf(TEOTHeader.unicode_range1)
    + SizeOf(TEOTHeader.unicode_range2)
    + SizeOf(TEOTHeader.unicode_range3)
    + SizeOf(TEOTHeader.unicode_range4)
    + SizeOf(TEOTHeader.code_page_range1)
    + SizeOf(TEOTHeader.code_page_range2)
    + SizeOf(TEOTHeader.checksum_adjustment)
    + SizeOf(TEOTHeader.reserved1)
    + SizeOf(TEOTHeader.reserved2)
    + SizeOf(TEOTHeader.reserved3)
    + SizeOf(TEOTHeader.reserved4),
    soCurrent);

  info.family := ReadField(stream, 'FamilyName');
  info.style := ReadField(stream, 'StyleName');
  info.version := ReadField(stream, 'VersionName');
  info.full_name := ReadField(stream, 'FullName');

  // Currently we can't uncompress EOT to determine SFNT format.
  info.format := 'EOT';
end;


initialization
  RegisterReader(@GetEOTInfo, ['.eot']);


end.

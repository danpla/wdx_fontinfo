{
  Web Open Font Format 2.0
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_woff2;

interface

uses
  brotli,
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes,
  streamex,
  sysutils;


implementation


function ReadUIntBase128(stream: TStream): longword;
var
  i: longint;
  b: byte;
begin
  result := 0;
  for i := 0 to 4 do
  begin
    b := stream.ReadByte;

    // Leading zeros are invalid.
    if (i = 0) and (b = $80) then
      raise EStreamError.Create('Base128 Leading zeros');

    // If any of the top seven bits are set then we're about to overflow.
    if result and $FE000000 <> 0 then
      raise EStreamError.Create('Base128 Overflow');

    result := (result shl 7) or (b and $7F);

    // Spin until the most significant bit of data byte is false.
    if b and $80 = 0 then
      exit(result);
  end;

  raise EStreamError.Create('Base128 exceeds 5 bytes');
end;


function Read255UShort(stream: TStream): word;
const
  WORD_CODE = 253;
  ONE_MORE_BYTE_CODE_1 = 254;
  ONE_MORE_BYTE_CODE_2 = 255;
  LOWEST_UCODE = 253;
var
  code: byte;
begin
  code := stream.ReadByte;
  case code of
    WORD_CODE:
      result := stream.ReadWordLE;
    ONE_MORE_BYTE_CODE_1:
      result := LOWEST_UCODE + stream.ReadByte;
    ONE_MORE_BYTE_CODE_2:
      result := LOWEST_UCODE * 2 + stream.ReadByte;
  else
    result := code;
  end;
end;


type
  TWOFF2TableDirEntry = record
    tag,
    offset,
    original_len,
    transformed_len: longword;
  end;

  TWOFF2TableDir = array of TWOFF2TableDirEntry;


function WOFF2TagIdxToTag(tag_idx: longword): longword;
begin
  case tag_idx of
    5:  result := TAG_NAME;
    10: result := TAG_GLYF;
    11: result := TAG_LOCA;
    25: result := TAG_BASE;
    26: result := TAG_GDEF;
    27: result := TAG_GPOS;
    28: result := TAG_GSUB;
    30: result := TAG_JSTF;
  else
    result := 0;
  end;
end;


function ReadWOFF2TableDir(
  stream: TStream; num_tables: longint): TWOFF2TableDir;
var
  i: longint;
  offset: longword;
  flags: byte;
  tag: longword;
  transform_version: byte;
begin
  SetLength(result, num_tables);
  if num_tables = 0 then
    exit(result);

  offset := 0;
  for i := 0 to num_tables - 1 do
  begin
    flags := stream.ReadByte;
    if flags and $3f = $3f then
      tag := stream.ReadDWordLE
    else
      tag := WOFF2TagIdxToTag(flags and $3f);

    result[i].tag := tag;
    result[i].offset := offset;
    result[i].original_len := ReadUIntBase128(stream);
    result[i].transformed_len := result[i].original_len;

    transform_version := (flags shr 6) and $03;
    if (tag = TAG_GLYF) or (tag = TAG_LOCA) then
    begin
      if transform_version = 0 then
        result[i].transformed_len := ReadUIntBase128(stream);
    end
    else if transform_version <> 0 then
      result[i].transformed_len := ReadUIntBase128(stream);

    inc(offset, result[i].transformed_len);
  end;
end;


type
  TWOFF2ColectionFontEntry = record
    flavor: longword;
    table_dir_indices: array of word;
  end;


function ReadWOFF2CollectionFontEntry(
  stream: TStream; num_tables: word): TWOFF2ColectionFontEntry;
var
  i: longint;
  index: word;
begin
  SetLength(result.table_dir_indices, Read255UShort(stream));
  result.flavor := stream.ReadDWordLE;

  for i := 0 to High(result.table_dir_indices) do
  begin
    index := Read255UShort(stream);
    if index >= num_tables then
      raise EStreamError.CreateFmt(
        'Table directory index %d at offset %d'
        + ' is out of bounds [0, %u)',
        [i, stream.Position, num_tables]);

    result.table_dir_indices[i] := index;
  end;
end;


function DecompressWOFF2Data(
  stream: TStream;
  compressed_size, uncompressed_size: longword): TBytes;
var
  compressed_data: TBytes;
  brotli_uncompressed_size: SizeUInt;
  brotli_decoder_result: TBrotliDecoderResult;
begin
  SetLength(compressed_data, compressed_size);
  stream.ReadBuffer(compressed_data[0], compressed_size);
  SetLength(result, uncompressed_size);

  brotli_uncompressed_size := uncompressed_size;
  brotli_decoder_result := BrotliDecoderDecompress(
    compressed_size,
    Pointer(compressed_data),
    @brotli_uncompressed_size,
    Pointer(result));

  if (brotli_decoder_result <> BROTLI_DECODER_RESULT_SUCCESS)
      or (brotli_uncompressed_size <> uncompressed_size) then
    raise EStreamError.Create('WOFF2 brotli decompression failure');
end;


const
  WOFF2_SIGNATURE = $774F4632; // 'wOF2'

type
  TWOFF2Header = packed record
    signature,
    flavor,
    length: longword;
    num_tables,
    reserved: word;
    total_sfnt_size,
    total_compressed_size: longword;
    // majorVersion,
    // minorVersion: word;
    // metaOffset,
    // metaLength,
    // metaOrigLength,
    // privOffset,
    // privLength: longword;
  end;


procedure GetWOFF2Info(stream: TStream; var info: TFontInfo);
var
  header: TWOFF2Header;
  table_dir: TWOFF2TableDir;
  uncompressed_size: longword;
  i: longint;
  has_layout_tables: boolean = FALSE;
  version: longword;
  collection_font_entry: TWOFF2ColectionFontEntry;
  table_dir_indices: array of word;
  decompressed_data: TBytes;
  decompressed_data_stream: TBytesStream;
begin
  stream.ReadBuffer(header, SizeOf(header));

  {$IFDEF ENDIAN_LITTLE}
  with header do
  begin
    signature := SwapEndian(signature);
    flavor := SwapEndian(flavor);
    length := SwapEndian(length);
    num_tables := SwapEndian(num_tables);
    reserved := SwapEndian(reserved);
    total_sfnt_size := SwapEndian(total_sfnt_size);
    total_compressed_size := SwapEndian(total_compressed_size);
  end;
  {$ENDIF}

  if header.signature <> WOFF2_SIGNATURE then
    raise EStreamError.Create('Not a WOFF2 font');

  if header.length <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in WOFF2 header (%u) does not match the file size (%d)',
      [header.length, stream.Size]);

  if header.num_tables = 0 then
    raise EStreamError.Create('WOFF2 has no tables');

  if header.reserved <> 0 then
    raise EStreamError.CreateFmt(
      'Reserved field in WOFF2 header is not 0 (%u)',
      [header.reserved]);

  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 5, soCurrent);

  table_dir := ReadWOFF2TableDir(stream, header.num_tables);
  with table_dir[header.num_tables - 1] do
    uncompressed_size := offset + transformed_len;

  if header.flavor = COLLECTION_SIGNATURE then
  begin
    stream.Seek(SizeOf(longword), soCurrent);  // TTC version
    info.num_fonts := Read255UShort(stream);
    if info.num_fonts = 0 then
      raise EStreamError.Create('WOFF2 collection has no fonts');

    collection_font_entry := ReadWOFF2CollectionFontEntry(
      stream, header.num_tables);

    version := collection_font_entry.flavor;
    table_dir_indices := collection_font_entry.table_dir_indices;

    // We only need the first font.
    for i := 1 to info.num_fonts - 1 do
      ReadWOFF2CollectionFontEntry(stream, header.num_tables);
  end
  else
  begin
    version := header.flavor;

    SetLength(table_dir_indices, Length(table_dir));
    for i := 0 to High(table_dir_indices) do
      table_dir_indices[i] := i;
  end;

  decompressed_data := DecompressWOFF2Data(
    stream, header.total_compressed_size, uncompressed_size);
  decompressed_data_stream := TBytesStream.Create(decompressed_data);

  try
    for i := 0 to High(table_dir_indices) do
    begin
      ReadTable(
        FindTableReader(table_dir[i].tag),
        decompressed_data_stream,
        info,
        table_dir[i].offset);

      has_layout_tables := (
        has_layout_tables or IsLayoutTable(table_dir[i].tag));
    end;
  finally
    decompressed_data_stream.Free;
  end;

  info.format := GetFormatSting(version, has_layout_tables);
end;


initialization
  RegisterReader(@GetWOFF2Info, ['.woff2']);


end.

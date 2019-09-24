{
  SFNT-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_sfnt;

interface

uses
  brotli,
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  zstream,
  strutils,
  sysutils;


implementation

const
  // SFNT table names
  TAG_BASE = $42415345;
  TAG_GDEF = $47444546;
  TAG_GPOS = $47504f53;
  TAG_GSUB = $47535542;
  TAG_JSTF = $4a535446;
  TAG_NAME = $6e616d65;
  TAG_GLYF = $676c7966;
  TAG_LOCA = $6c6f6361;

  TTF_MAGIC1 = $00010000;
  TTF_MAGIC2 = $00020000;
  TTF_MAGIC3 = $74727565; // 'true'
  TTF_MAGIC4 = $74797031; // 'typ1'
  OTF_MAGIC = $4f54544f; // 'OTTO'


function TableTagToString(tag: longword): string;
begin
  SetLength(result, SizeOf(tag));
  {$IFDEF ENDIAN_LITTLE}
  tag := SwapEndian(tag);
  {$ENDIF}
  Move(tag, result[1], SizeOf(tag));
  result := TrimRight(result);
end;


function GetFormatSting(sign: longword;
                        has_layout_tables: boolean): string; inline;
begin
  if sign = OTF_MAGIC then
    result := 'OT PS'
  else
    if has_layout_tables then
      result := 'OT TT'
    else
      result := 'TT';
end;



// Table reading


type
  TTableReader = procedure(stream: TStream; var info: TFontInfo);

  TTableCompression = (
    NO_COMPRESSION,
    ZLIB
    );

// uncompressed_size is ignored if compression is NO_COMPRESSION
procedure ReadTable(stream: TStream; var info: TFontInfo;
                    reader: TTableReader; offset: longword;
                    compression: TTableCompression;
                    uncompressed_size: longword = 0);
var
  start: int64;
  decompressed_data: TBytes;
  zs: TDecompressionStream;
  bs: TBytesStream;
begin
  start := stream.Position;
  stream.Seek(offset, soBeginning);

  case compression of
    NO_COMPRESSION:
      reader(stream, info);
    ZLIB:
      begin
        zs := TDecompressionStream.Create(stream);
        try
          SetLength(decompressed_data, uncompressed_size);
          zs.ReadBuffer(decompressed_data[0], uncompressed_size);
        finally
          zs.Free;
        end;

        bs := TBytesStream.Create(decompressed_data);
        try
          reader(bs, info);
        finally
          bs.Free;
        end;
      end;
  end;

  stream.Seek(start, soBeginning);
end;


// "name" table

const
  PLATFORM_ID_WIN = 3;
  LANGUAGE_ID_WIN_ENGLISH_US = $0409;
  ENCODING_ID_WIN_UCS2 = 1;

  VERSION_STR = 'Version ';

type
  TNamingTable = packed record
    format,
    count,
    string_offset: word;
  end;

  TNameRecord = packed record
    platform_id,
    encoding_id,
    language_id,
    name_id,
    length,
    offset: word;
  end;

procedure NameReader(stream: TStream; var info: TFontInfo);
var
  start: int64;
  naming_table: TNamingTable;
  storage_offset,
  offset: int64;
  i: longint;
  name_rec: TNameRecord;
  idx: TFieldIndex;
  name: UnicodeString;
  version: string;
begin
  start := stream.Position;
  stream.ReadBuffer(naming_table, SizeOf(naming_table));

  {$IFDEF ENDIAN_LITTLE}
  with naming_table do
    begin
      format := SwapEndian(format);
      count := SwapEndian(count);
      string_offset := SwapEndian(string_offset);
    end;
  {$ENDIF}

  if naming_table.count = 0 then
    raise EStreamError.Create('Naming table has no records');

  storage_offset := start + naming_table.string_offset;

  for i := 0 to naming_table.count - 1 do
    begin
      stream.ReadBuffer(name_rec, SizeOf(name_rec));

      {$IFDEF ENDIAN_LITTLE}
      with name_rec do
        begin
          platform_id := SwapEndian(platform_id);
          encoding_id := SwapEndian(encoding_id);
          language_id := SwapEndian(language_id);
          name_id := SwapEndian(name_id);
          length := SwapEndian(length);
          offset := SwapEndian(offset);
        end;
      {$ENDIF}

      // Entries in the Name Record are always sorted so that we can stop
      // parsing immediately after we finished reading the needed record.
      if (name_rec.platform_id < PLATFORM_ID_WIN) or
         (name_rec.language_id < LANGUAGE_ID_WIN_ENGLISH_US) then
        continue
      else
        if (name_rec.platform_id > PLATFORM_ID_WIN) or
           (name_rec.encoding_id > ENCODING_ID_WIN_UCS2) or
           (name_rec.language_id > LANGUAGE_ID_WIN_ENGLISH_US) then
          break;

      case name_rec.name_id of
        0:  idx := IDX_COPYRIGHT;
        1:  idx := IDX_FAMILY;
        2:  idx := IDX_STYLE;
        3:  idx := IDX_UNIQUE_ID;
        4:  idx := IDX_FULL_NAME;
        5:  idx := IDX_VERSION;
        6:  idx := IDX_PS_NAME;
        7:  idx := IDX_TRADEMARK;
        8:  idx := IDX_MANUFACTURER;
        9:  idx := IDX_DESIGNER;
        10: idx := IDX_DESCRIPTION;
        11: idx := IDX_VENDOR_URL;
        12: idx := IDX_DESIGNER_URL;
        13: idx := IDX_LICENSE;
        14: idx := IDX_LICENSE_URL;
        15: continue;  // Reserved
        16: idx := IDX_FAMILY;  // Typographic Family
        17: idx := IDX_STYLE;  // Typographic Subfamily
      else
        break;
      end;

      offset := stream.Position;
      stream.Seek(storage_offset + name_rec.offset, soBeginning);

      SetLength(name, name_rec.length div SizeOf(WideChar));
      stream.ReadBuffer(name[1], name_rec.length);
      {$IFDEF ENDIAN_LITTLE}
      SwapUnicode(name);
      {$ENDIF}
      info[idx] := UTF8Encode(name);

      stream.Seek(offset, soBeginning);
    end;

  // Strip "Version "
  version := info[IDX_VERSION];
  if (version <> '') and AnsiStartsStr(VERSION_STR, version) then
    begin
      info[IDX_VERSION] := Copy(
        version,
        Length(VERSION_STR) + 1,
        Length(version) - Length(VERSION_STR));
    end;
end;



// Format-specific stuff

type
  TOffsetTable = packed record
    version: longword;
    num_tables: word;
    //search_range,
    //entry_selector,
    //range_shift: word;
  end;

  TTableDirEntry = packed record
    tag,
    checksumm,
    offset,
    length: longword;
  end;

{
  Common parser for TTF, TTC, OTF, OTC, and EOT.
}
procedure GetCommonInfo(stream: TStream; var info: TFontInfo;
                        font_offset: longword = 0);
var
  offset_table: TOffsetTable;
  i: longint;
  dir: TTableDirEntry;
  has_layout_tables: boolean = FALSE;
begin
  stream.ReadBuffer(offset_table, SizeOf(offset_table));

  {$IFDEF ENDIAN_LITTLE}
  with offset_table do
    begin
      version := SwapEndian(version);
      num_tables := SwapEndian(num_tables);
    end;
  {$ENDIF}

  if (offset_table.version <> TTF_MAGIC1) and
     (offset_table.version <> TTF_MAGIC2) and
     (offset_table.version <> TTF_MAGIC3) and
     (offset_table.version <> TTF_MAGIC4) and
     (offset_table.version <> OTF_MAGIC) then
    raise EStreamError.Create('Not a SFNT-based font');

  if offset_table.num_tables = 0 then
    raise EStreamError.Create('Font has no tables');

  stream.Seek(SizeOf(word) * 3, soCurrent);

  for i := 0 to offset_table.num_tables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag := SwapEndian(tag);
          checksumm := SwapEndian(checksumm);
          offset := SwapEndian(offset);
          length := SwapEndian(length);
        end;
      {$ENDIF}

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          has_layout_tables := TRUE;
        TAG_NAME:
          ReadTable(
            stream, info, @NameReader, font_offset + dir.offset,
            NO_COMPRESSION);
      end;
    end;

  info[IDX_FORMAT] := GetFormatSting(offset_table.version, has_layout_tables);
end;


procedure GetOTFInfo(stream: TStream; var info: TFontInfo);
begin
  GetCommonInfo(stream, info);
  info[IDX_NUM_FONTS] := '1';
end;


const
  COLLECTION_SIGNATURE = $74746366; // 'ttcf'

type
  TCOllectionHeader = packed record
    signature,
    version,
    num_fonts,
    first_font_offset: longword;
  end;

procedure GetCollectionInfo(stream: TStream; var info: TFontInfo);
var
  header: TCOllectionHeader;
begin
  stream.ReadBuffer(header, SizeOf(header));

  {$IFDEF ENDIAN_LITTLE}
  with header do
    begin
      signature := SwapEndian(signature);
      version := SwapEndian(version);
      num_fonts := SwapEndian(num_fonts);
      first_font_offset := SwapEndian(first_font_offset);
    end;
  {$ENDIF}

  if header.signature <> COLLECTION_SIGNATURE then
    raise EStreamError.Create('Not a font collection');

  if header.num_fonts = 0 then
    raise EStreamError.Create('Collection has no fonts');

  stream.Seek(header.first_font_offset, soBeginning);
  GetCommonInfo(stream, info);

  info[IDX_NUM_FONTS] := IntToStr(header.num_fonts);
end;


const
  WOFF_SIGNATURE = $774f4646; // 'wOFF'

type
  TWOFFHeader = packed record
    signature,
    flavor,
    length: longword;
    num_tables,
    reserved: word;
    // totalSfntSize: longword;
    // majorVersion,
    // minorVersion: word;
    // metaOffset,
    // metaLength,
    // metaOrigLength,
    // privOffset,
    // privLength: longword;
  end;

  TWOFFTableDirEntry = packed record
    tag,
    offset,
    comp_length,
    orig_length: longword;
    // origChecksum: longword;
  end;

procedure GetWOFFInfo(stream: TStream; var info: TFontInfo);
var
  header: TWOFFHeader;
  i: longint;
  dir: TWOFFTableDirEntry;
  has_layout_tables: boolean = FALSE;
  compression: TTableCompression;
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
    end;
  {$ENDIF}

  if header.signature <> WOFF_SIGNATURE then
    raise EStreamError.Create('Not a WOFF font');

  if header.length <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in WOFF header (%u) does not match the file size (%u)',
      [header.length, stream.Size]);

  if header.num_tables = 0 then
    raise EStreamError.Create('WOFF has no tables');

  if header.reserved <> 0 then
    raise EStreamError.CreateFmt(
      'Reserved field in WOFF header is not 0 (%u)',
      [header.reserved]);

  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 6, soCurrent);

  for i := 0 to header.num_tables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));
      // Skip origChecksum.
      stream.Seek(SizeOf(longword), soCurrent);

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag := SwapEndian(tag);
          offset := SwapEndian(offset);
          comp_length := SwapEndian(comp_length);
          orig_length := SwapEndian(orig_length);
        end;
      {$ENDIF}

      if dir.comp_length < dir.orig_length then
        compression := ZLIB
      else if dir.comp_length = dir.orig_length then
        compression := NO_COMPRESSION
      else
        raise EStreamError.CreateFmt(
          'Compressed size (%u) of the "%s" WOFF table is greater than ' +
          'uncompressed size (%u)',
          [dir.comp_length, TableTagToString(dir.tag), dir.orig_length]);

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          has_layout_tables := TRUE;
        TAG_NAME:
          ReadTable(
            stream, info, @NameReader, dir.offset,
            compression, dir.orig_length);
      end;
    end;

  info[IDX_FORMAT] := GetFormatSting(header.flavor, has_layout_tables);
  info[IDX_NUM_FONTS] := '1';
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

      // Spin until most significant bit of data byte is false.
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


function Woff2TagIdxToTag(tag_idx: longword): longword;
begin
  case tag_idx of
    25: result := TAG_BASE;
    26: result := TAG_GDEF;
    27: result := TAG_GPOS;
    28: result := TAG_GSUB;
    30: result := TAG_JSTF;
    5:  result := TAG_NAME;
    10: result := TAG_GLYF;
    11: result := TAG_LOCA;
  else
    result := 0;
  end;
end;


function ReadWoff2TableDir(
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
        tag := Woff2TagIdxToTag(flags and $3f);

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


function ReadWoff2CollectionFontEntry(
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
        'Table directory index %d at offset %u'
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


procedure GetWOFF2Info(stream: TStream; var info: TFontInfo);
var
  header: TWOFF2Header;
  table_dir: TWOFF2TableDir;
  uncompressed_size: longword;
  i: longint;
  has_layout_tables: boolean = FALSE;
  version: longword;
  num_fonts: word;
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
      'Size in WOFF2 header (%u) does not match the file size (%u)',
      [header.length, stream.Size]);

  if header.num_tables = 0 then
    raise EStreamError.Create('WOFF2 has no tables');

  if header.reserved <> 0 then
    raise EStreamError.CreateFmt(
      'Reserved field in WOFF2 header is not 0 (%u)',
      [header.reserved]);

  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 5, soCurrent);

  table_dir := ReadWoff2TableDir(stream, header.num_tables);
  with table_dir[header.num_tables - 1] do
    uncompressed_size := offset + transformed_len;

  if header.flavor = COLLECTION_SIGNATURE then
    begin
      stream.Seek(SizeOf(longword), soCurrent);  // TTC version
      num_fonts := Read255UShort(stream);
      if num_fonts = 0 then
        raise EStreamError.Create('WOFF2 collection has no fonts');

      collection_font_entry := ReadWoff2CollectionFontEntry(
        stream, header.num_tables);

      version := collection_font_entry.flavor;
      table_dir_indices := collection_font_entry.table_dir_indices;

      // We only need the first font.
      for i := 1 to num_fonts - 1 do
        ReadWoff2CollectionFontEntry(stream, header.num_tables);
    end
  else
    begin
      version := header.flavor;
      num_fonts := 1;

      SetLength(table_dir_indices, Length(table_dir));
      for i := 0 to High(table_dir_indices) do
        table_dir_indices[i] := i;
    end;

  decompressed_data := DecompressWOFF2Data(
    stream, header.total_compressed_size, uncompressed_size);
  decompressed_data_stream := TBytesStream.Create(decompressed_data);

  try
    for i := 0 to High(table_dir_indices) do
      case table_dir[i].tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          has_layout_tables := TRUE;
        TAG_NAME:
          ReadTable(
            decompressed_data_stream, info, @NameReader,
            table_dir[i].offset, NO_COMPRESSION);
      end;
  finally
    decompressed_data_stream.Free;
  end;

  info[IDX_FORMAT] := GetFormatSting(version, has_layout_tables);
  info[IDX_NUM_FONTS] := IntToStr(num_fonts);
end;


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

procedure GetEOTInfo(stream: TStream; var info: TFontInfo);
var
  eot_size,
  font_data_size,
  flags: longword;
  magic,
  padding: word;
  font_offset: longword;
  idx: TFieldIndex;
  s: UnicodeString;
  s_len: word;
begin
  eot_size := stream.ReadDWordLE;
  if eot_size <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in EOT header (%u) does not match the file size (%u)',
      [eot_size, stream.Size]);

  font_data_size := stream.ReadDWordLE;
  if font_data_size >= eot_size - SizeOf(TEOTHeader) then
    raise EStreamError.CreateFmt(
      'Data size in EOT header (%u) is too big for the actual file size (%u)',
      [font_data_size, eot_size]);

  stream.Seek(SizeOf(TEOTHeader.version), soCurrent);

  flags := stream.ReadDWordLE;

  stream.Seek(
    SizeOf(TEOTHeader.panose) +
    SizeOf(TEOTHeader.charset) +
    SizeOf(TEOTHeader.italic) +
    SizeOf(TEOTHeader.weight) +
    SizeOf(TEOTHeader.fs_type),
    soCurrent);

  magic := stream.ReadWordLE;
  if magic <> EOT_MAGIC then
    raise EStreamError.Create('Not an EOT font');

  if (flags and TTEMBED_TTCOMPRESSED = 0) and
     (flags and TTEMBED_XORENCRYPTDATA = 0) then
    begin
      font_offset := eot_size - font_data_size;
      stream.Seek(font_offset, soBeginning);

      GetCommonInfo(stream, info, font_offset);
      info[IDX_NUM_FONTS] := '1';

      exit;
    end;

  stream.Seek(
    SizeOf(TEOTHeader.unicode_range1) +
    SizeOf(TEOTHeader.unicode_range2) +
    SizeOf(TEOTHeader.unicode_range3) +
    SizeOf(TEOTHeader.unicode_range4) +
    SizeOf(TEOTHeader.code_page_range1) +
    SizeOf(TEOTHeader.code_page_range2) +
    SizeOf(TEOTHeader.checksum_adjustment) +
    SizeOf(TEOTHeader.reserved1) +
    SizeOf(TEOTHeader.reserved2) +
    SizeOf(TEOTHeader.reserved3) +
    SizeOf(TEOTHeader.reserved4),
    soCurrent);

  for idx in [IDX_FAMILY, IDX_STYLE, IDX_VERSION, IDX_FULL_NAME] do
    begin
      padding := stream.ReadWordLE;
      if padding <> 0 then
        raise EStreamError.CreateFmt(
          'Non-zero (%u) padding for "%s" EOT field',
          [padding, TFieldNames[idx]]);

      s_len := stream.ReadWordLE;
      SetLength(s, s_len div SizeOf(WideChar));
      stream.ReadBuffer(s[1], s_len);
      {$IFDEF ENDIAN_BIG}
      SwapUnicode(s);
      {$ENDIF}
      info[idx] := UTF8Encode(s);
    end;

  // Currently we can't uncompress EOT to determine SFNT format.
  info[IDX_FORMAT] := 'EOT';
  info[IDX_NUM_FONTS] := '1';
end;


initialization
  RegisterReader(@GetOTFInfo, ['.ttf', '.otf']);
  RegisterReader(@GetCollectionInfo, ['.ttc', '.otc']);
  RegisterReader(@GetWOFFInfo, ['.woff']);
  RegisterReader(@GetWOFF2Info, ['.woff2']);
  RegisterReader(@GetEOTInfo, ['.eot']);


end.

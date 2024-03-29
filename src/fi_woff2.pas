// Web Open Font Format 2.0

unit fi_woff2;

interface

implementation

uses
  brotli,
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes,
  streamex,
  sysutils;


function ReadUIntBase128(stream: TStream): LongWord;
var
  i: LongInt;
  b: Byte;
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

    // Spin until the most significant bit of data Byte is false.
    if b and $80 = 0 then
      exit(result);
  end;

  raise EStreamError.Create('Base128 exceeds 5 Bytes');
end;


function Read255UShort(stream: TStream): Word;
const
  WORD_CODE = 253;
  ONE_MORE_BYTE_CODE1 = 254;
  ONE_MORE_BYTE_CODE2 = 255;
  LOWEST_UCODE = 253;
var
  code: Byte;
begin
  code := stream.ReadByte;
  case code of
    WORD_CODE:
      result := stream.ReadWordBE;
    ONE_MORE_BYTE_CODE1:
      result := LOWEST_UCODE + stream.ReadByte;
    ONE_MORE_BYTE_CODE2:
      result := LOWEST_UCODE * 2 + stream.ReadByte;
  else
    result := code;
  end;
end;


type
  TWOFF2TableDirEntry = record
    tag,
    offset,
    originalLen,
    transformedLen: LongWord;
  end;

  TWOFF2TableDir = array of TWOFF2TableDirEntry;


function WOFF2TagIdxToTag(tagIdx: LongWord): LongWord;
begin
  case tagIdx of
    5:  result := SFNT_TAG_NAME;
    10: result := SFNT_TAG_GLYF;
    11: result := SFNT_TAG_LOCA;
    25: result := SFNT_TAG_BASE;
    26: result := SFNT_TAG_GDEF;
    27: result := SFNT_TAG_GPOS;
    28: result := SFNT_TAG_GSUB;
    30: result := SFNT_TAG_JSTF;
    47: result := SFNT_TAG_FVAR;
  else
    result := 0;
  end;
end;


function ReadWOFF2TableDir(
  stream: TStream; numTables: LongInt): TWOFF2TableDir;
var
  i: LongInt;
  offset: LongWord;
  flags: Byte;
  tag: LongWord;
  transformVersion: Byte;
begin
  SetLength(result, numTables);
  if numTables = 0 then
    exit(result);

  offset := 0;
  for i := 0 to numTables - 1 do
  begin
    flags := stream.ReadByte;
    if flags and $3f = $3f then
      tag := stream.ReadDWordBE
    else
      tag := WOFF2TagIdxToTag(flags and $3f);

    result[i].tag := tag;
    result[i].offset := offset;
    result[i].originalLen := ReadUIntBase128(stream);
    result[i].transformedLen := result[i].originalLen;

    transformVersion := (flags shr 6) and $03;
    if (tag = SFNT_TAG_GLYF) or (tag = SFNT_TAG_LOCA) then
    begin
      if transformVersion = 0 then
        result[i].transformedLen := ReadUIntBase128(stream);
    end
    else if transformVersion <> 0 then
      result[i].transformedLen := ReadUIntBase128(stream);

    Inc(offset, result[i].transformedLen);
  end;
end;


type
  TWOFF2ColectionFontEntry = record
    flavor: LongWord;
    tableDirIndices: array of Word;
  end;


function ReadWOFF2CollectionFontEntry(
  stream: TStream; numTables: Word): TWOFF2ColectionFontEntry;
var
  i: LongInt;
  index: Word;
begin
  SetLength(result.tableDirIndices, Read255UShort(stream));
  result.flavor := stream.ReadDWordBE;

  for i := 0 to High(result.tableDirIndices) do
  begin
    index := Read255UShort(stream);
    if index >= numTables then
      raise EStreamError.CreateFmt(
        'Table directory index %d at offset %d'
        + ' is out of bounds [0, %u)',
        [i, stream.Position, numTables]);

    result.tableDirIndices[i] := index;
  end;
end;


function DecompressWOFF2Data(
  stream: TStream;
  compressedSize, decompressedSize: LongWord): TBytes;
var
  compressedData: TBytes;
begin
  SetLength(compressedData, compressedSize);
  stream.ReadBuffer(compressedData[0], compressedSize);
  SetLength(result, decompressedSize);

  if not BrotliDecompress(
      compressedData, decompressedSize, result) then
    raise EStreamError.Create('WOFF2 brotli decompression failure');
end;


const
  WOFF2_SIGN = $774F4632; // 'wOF2'


type
  TWOFF2Header = packed record
    signature,
    flavor,
    length: LongWord;
    numTables,
    reserved: Word;
    totalSfntSize,
    totalCompressedSize: LongWord;
    // majorVersion,
    // minorVersion: Word;
    // metaOffset,
    // metaLength,
    // metaOrigLength,
    // privOffset,
    // privLength: LongWord;
  end;


procedure ReadWOFF2Info(stream: TStream; var info: TFontInfo);
var
  header: TWOFF2Header;
  tableDir: TWOFF2TableDir;
  decompressedSize: LongWord;
  i: LongInt;
  hasLayoutTables: Boolean = FALSE;
  version: LongWord;
  collectionFontEntry: TWOFF2ColectionFontEntry;
  tableDirIndices: array of Word;
  decompressedData: TBytes;
  decompressedDataStream: TBytesStream;
begin
  stream.ReadBuffer(header, SizeOf(header));

  {$IFDEF ENDIAN_LITTLE}
  with header do
  begin
    signature := SwapEndian(signature);
    flavor := SwapEndian(flavor);
    length := SwapEndian(length);
    numTables := SwapEndian(numTables);
    reserved := SwapEndian(reserved);
    totalSfntSize := SwapEndian(totalSfntSize);
    totalCompressedSize := SwapEndian(totalCompressedSize);
  end;
  {$ENDIF}

  if header.signature <> WOFF2_SIGN then
    raise EStreamError.Create('Not a WOFF2 font');

  if header.length <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in WOFF2 header (%u) does not match the file size (%d)',
      [header.length, stream.Size]);

  if header.numTables = 0 then
    raise EStreamError.Create('WOFF2 has no tables');

  // The spec say that a non-zero reserved field is not an error.

  stream.Seek(SizeOf(Word) * 2 + SizeOf(LongWord) * 5, soCurrent);

  tableDir := ReadWOFF2TableDir(stream, header.numTables);
  with tableDir[header.numTables - 1] do
    // The spec says that totalSfntSize from the header is for
    // reference purposes only and should not be relied upon.
    decompressedSize := offset + transformedLen;

  if header.flavor = SFNT_COLLECTION_SIGN then
  begin
    stream.Seek(SizeOf(LongWord), soCurrent);  // TTC version
    info.numFonts := Read255UShort(stream);
    if info.numFonts = 0 then
      raise EStreamError.Create('WOFF2 collection has no fonts');

    collectionFontEntry := ReadWOFF2CollectionFontEntry(
      stream, header.numTables);

    version := collectionFontEntry.flavor;
    tableDirIndices := collectionFontEntry.tableDirIndices;

    // We only need the first font.
    for i := 1 to info.numFonts - 1 do
      ReadWOFF2CollectionFontEntry(stream, header.numTables);
  end
  else
  begin
    version := header.flavor;

    SetLength(tableDirIndices, Length(tableDir));
    for i := 0 to High(tableDirIndices) do
      tableDirIndices[i] := i;
  end;

  decompressedData := DecompressWOFF2Data(
    stream, header.totalCompressedSize, decompressedSize);
  decompressedDataStream := TBytesStream.Create(decompressedData);

  try
    for i := 0 to High(tableDirIndices) do
    begin
      if tableDir[i].tag = 0 then
        continue;

      SFNT_ReadTable(
        SFNT_FindTableReader(tableDir[i].tag),
        decompressedDataStream,
        info,
        tableDir[i].offset);

      hasLayoutTables := (
        hasLayoutTables or SFNT_IsLayoutTable(tableDir[i].tag));
    end;
  finally
    decompressedDataStream.Free;
  end;

  info.format := SFNT_GetFormatSting(version, hasLayoutTables);
end;


initialization
  RegisterReader(@ReadWOFF2Info, ['.woff2']);


end.

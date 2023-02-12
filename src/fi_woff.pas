// Web Open Font Format 1.0

unit fi_woff;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  fi_utils,
  classes,
  sysutils,
  zstream;


implementation


const
  WOFF_SIGN = $774f4646; // 'wOFF'

type
  TWOFFHeader = packed record
    signature,
    flavor,
    length: longword;
    numTables,
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
    compLength,
    origLength: longword;
    // origChecksum: longword;
  end;


procedure ReadWOFFTable(
  stream: TStream; var info: TFontInfo; dir: TWOFFTableDirEntry);
var
  reader: TSFNTTableReader;
  start: int64;
  zs: TDecompressionStream;
  decompressedData: TBytes;
  decompressedDataStream: TBytesStream;
begin
  reader := SFNT_FindTableReader(dir.tag);
  if reader = NIL then
    exit;

  if dir.compLength > dir.origLength then
    raise EStreamError.CreateFmt(
      'Compressed size (%u) of the "%s" WOFF table is greater than '
      + 'decompressed size (%u)',
      [dir.compLength, TagToString(dir.tag), dir.origLength]);

  if dir.compLength = dir.origLength then
  begin
    SFNT_ReadTable(reader, stream, info, dir.offset);
    exit;
  end;

  start := stream.Position;
  stream.Seek(dir.offset, soBeginning);

  zs := TDecompressionStream.Create(stream);
  try
    SetLength(decompressedData, dir.origLength);
    zs.ReadBuffer(decompressedData[0], dir.origLength);
  finally
    zs.Free;
  end;

  stream.Seek(start, soBeginning);

  decompressedDataStream := TBytesStream.Create(decompressedData);
  try
    SFNT_ReadTable(reader, decompressedDataStream, info, 0);
  finally
    decompressedDataStream.Free;
  end;
end;


procedure GetWOFFInfo(stream: TStream; var info: TFontInfo);
var
  header: TWOFFHeader;
  i: longint;
  dir: TWOFFTableDirEntry;
  hasLayoutTables: boolean = FALSE;
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
  end;
  {$ENDIF}

  if header.signature <> WOFF_SIGN then
    raise EStreamError.Create('Not a WOFF font');

  if header.length <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in WOFF header (%u) does not match the file size (%d)',
      [header.length, stream.Size]);

  if header.numTables = 0 then
    raise EStreamError.Create('WOFF has no tables');

  if header.reserved <> 0 then
    raise EStreamError.CreateFmt(
      'Reserved field in WOFF header is not 0 (%u)',
      [header.reserved]);

  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 6, soCurrent);

  for i := 0 to header.numTables - 1 do
  begin
    stream.ReadBuffer(dir, SizeOf(dir));
    // Skip origChecksum.
    stream.Seek(SizeOf(longword), soCurrent);

    {$IFDEF ENDIAN_LITTLE}
    with dir do
    begin
      tag := SwapEndian(tag);
      offset := SwapEndian(offset);
      compLength := SwapEndian(compLength);
      origLength := SwapEndian(origLength);
    end;
    {$ENDIF}

    ReadWOFFTable(stream, info, dir);

    hasLayoutTables := hasLayoutTables or SFNT_IsLayoutTable(dir.tag);
  end;

  info.format := SFNT_GetFormatSting(
    header.flavor, hasLayoutTables);
end;


initialization
  RegisterReader(@GetWOFFInfo, ['.woff']);


end.

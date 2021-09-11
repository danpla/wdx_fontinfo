{
  Web Open Font Format 1.0
}

{$MODE OBJFPC}
{$H+}

unit fi_woff;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
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


procedure ReadWOFFTable(
  stream: TStream; var info: TFontInfo; dir: TWOFFTableDirEntry);
var
  reader: TSFNTTableReader;
  start: int64;
  zs: TDecompressionStream;
  decompressed_data: TBytes;
  decompressed_data_stream: TBytesStream;
begin
  reader := SFNT_FindTableReader(dir.tag);
  if reader = NIL then
    exit;

  if dir.comp_length > dir.orig_length then
    raise EStreamError.CreateFmt(
      'Compressed size (%u) of the "%s" WOFF table is greater than '
      + 'uncompressed size (%u)',
      [dir.comp_length, SFNT_TagToString(dir.tag), dir.orig_length]);

  if dir.comp_length = dir.orig_length then
  begin
    SFNT_ReadTable(reader, stream, info, dir.offset);
    exit;
  end;

  start := stream.Position;
  stream.Seek(dir.offset, soBeginning);

  zs := TDecompressionStream.Create(stream);
  try
    SetLength(decompressed_data, dir.orig_length);
    zs.ReadBuffer(decompressed_data[0], dir.orig_length);
  finally
    zs.Free;
  end;

  stream.Seek(start, soBeginning);

  decompressed_data_stream := TBytesStream.Create(decompressed_data);
  try
    SFNT_ReadTable(reader, decompressed_data_stream, info, 0);
  finally
    decompressed_data_stream.Free;
  end;
end;


procedure GetWOFFInfo(stream: TStream; var info: TFontInfo);
var
  header: TWOFFHeader;
  i: longint;
  dir: TWOFFTableDirEntry;
  has_layout_tables: boolean = FALSE;
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

  if header.signature <> WOFF_SIGN then
    raise EStreamError.Create('Not a WOFF font');

  if header.length <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in WOFF header (%u) does not match the file size (%d)',
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

    ReadWOFFTable(stream, info, dir);

    has_layout_tables := (
      has_layout_tables or SFNT_IsLayoutTable(dir.tag));
  end;

  info.format := SFNT_GetFormatSting(
    header.flavor, has_layout_tables);
end;


initialization
  RegisterReader(@GetWOFFInfo, ['.woff']);


end.

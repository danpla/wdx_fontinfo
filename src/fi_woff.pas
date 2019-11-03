{
  Web Open Font Format 1.0
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_woff;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt_common,
  classes,
  sysutils;


implementation


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

      if dir.tag = TAG_NAME then
        ReadTable(
          stream, info, @NameReader, dir.offset,
          compression, dir.orig_length)
      else
        has_layout_tables := (
          has_layout_tables or IsLayoutTable(dir.tag));
    end;

  info.format := GetFormatSting(header.flavor, has_layout_tables);
end;


initialization
  RegisterReader(@GetWOFFInfo, ['.woff']);


end.

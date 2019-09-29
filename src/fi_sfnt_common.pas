{
  Common stuff for SFNT-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_sfnt_common;

interface

uses
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  zstream,
  strutils,
  sysutils;

const
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

  COLLECTION_SIGNATURE = $74746366; // 'ttcf'

function TableTagToString(tag: longword): string;
function IsLayoutTable(tag: longword): boolean;
function GetFormatSting(
    sign: longword; has_layout_tables: boolean): string;


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

procedure NameReader(stream: TStream; var info: TFontInfo);

{
  Common parser for TTF, TTC, OTF, OTC, and EOT.
}
procedure GetCommonInfo(stream: TStream; var info: TFontInfo);

implementation


function TableTagToString(tag: longword): string;
begin
  SetLength(result, SizeOf(tag));
  {$IFDEF ENDIAN_LITTLE}
  tag := SwapEndian(tag);
  {$ENDIF}
  Move(tag, result[1], SizeOf(tag));
  result := TrimRight(result);
end;


function IsLayoutTable(tag: longword): boolean;
begin
  case tag of
    TAG_BASE,
    TAG_GDEF,
    TAG_GPOS,
    TAG_GSUB,
    TAG_JSTF:
      result := TRUE;
  else
    result := FALSE;
  end;
end;


function GetFormatSting(
  sign: longword; has_layout_tables: boolean): string;
begin
  if sign = OTF_MAGIC then
    result := 'OT PS'
  else if has_layout_tables then
    result := 'OT TT'
  else
    result := 'TT';
end;


procedure ReadTable(stream: TStream; var info: TFontInfo;
                    reader: TTableReader; offset: longword;
                    compression: TTableCompression;
                    uncompressed_size: longword);
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
      else if (name_rec.platform_id > PLATFORM_ID_WIN) or
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

procedure GetCommonInfo(stream: TStream; var info: TFontInfo);
var
  start: int64;
  offset_table: TOffsetTable;
  i: longint;
  dir: TTableDirEntry;
  has_layout_tables: boolean = FALSE;
begin
  start := stream.Position;
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

      if dir.tag = TAG_NAME then
        ReadTable(
          stream, info, @NameReader, start + dir.offset,
          NO_COMPRESSION)
      else
        has_layout_tables := (
          has_layout_tables or IsLayoutTable(dir.tag));
    end;

  info[IDX_FORMAT] := GetFormatSting(offset_table.version, has_layout_tables);
end;


end.

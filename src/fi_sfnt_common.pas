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
  fi_panose,
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
  TAG_OS2  = $4F532F32;

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
  TTableCompression = (
    NO_COMPRESSION,
    ZLIB
    );

// uncompressed_size is ignored if compression is NO_COMPRESSION
procedure ReadTable(
  stream: TStream;
  var info: TFontInfo;
  tag: longword;
  offset: longword;
  compression: TTableCompression;
  uncompressed_size: longword = 0);

{
  Common parser for TTF, TTC, OTF, OTC, and EOT.

  font_offset is necessary for EOT since its EMBEDDEDFONT structure
  is not treated as part of the font data.
}
procedure GetCommonInfo(
  stream: TStream; var info: TFontInfo; font_offset: longword = 0);

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


type
  TTableReader = procedure(stream: TStream; var info: TFontInfo);


function FindTableReader(tag: longword): TTableReader; forward;


procedure ReadTable(
  stream: TStream;
  var info: TFontInfo;
  tag: longword;
  offset: longword;
  compression: TTableCompression;
  uncompressed_size: longword);
var
  reader: TTableReader;
  start: int64;
  decompressed_data: TBytes;
  zs: TDecompressionStream;
  bs: TBytesStream;
begin
  reader := FindTableReader(tag);
  if reader = NIL then
    exit;

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

  VERSION_PREFIX = 'Version ';

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

procedure ReadNameTable(stream: TStream; var info: TFontInfo);
var
  start: int64;
  naming_table: TNamingTable;
  storage_offset,
  offset: int64;
  i: longint;
  name_rec: TNameRecord;
  name: UnicodeString;
  dst: pstring;
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

      // Entries in the Name Record are always sorted so that we can
      // stop parsing immediately after we finished reading the needed
      // record.
      if (name_rec.platform_id < PLATFORM_ID_WIN) or
          (name_rec.language_id < LANGUAGE_ID_WIN_ENGLISH_US) then
        continue
      else if (name_rec.platform_id > PLATFORM_ID_WIN) or
          (name_rec.encoding_id > ENCODING_ID_WIN_UCS2) or
          (name_rec.language_id > LANGUAGE_ID_WIN_ENGLISH_US) then
        break;

      case name_rec.name_id of
        0:  dst := @info.copyright;
        1:  dst := @info.family;
        2:  dst := @info.style;
        3:  dst := @info.unique_id;
        4:  dst := @info.full_name;
        5:  dst := @info.version;
        6:  dst := @info.ps_name;
        7:  dst := @info.trademark;
        8:  dst := @info.manufacturer;
        9:  dst := @info.designer;
        10: dst := @info.description;
        11: dst := @info.vendor_url;
        12: dst := @info.designer_url;
        13: dst := @info.license;
        14: dst := @info.license_url;
        15: continue;  // Reserved
        16: dst := @info.family;  // Typographic Family
        17: dst := @info.style;  // Typographic Subfamily
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
      dst^ := UTF8Encode(name);

      stream.Seek(offset, soBeginning);
    end;

  // Strip "Version "
  if (info.version <> '')
      and AnsiStartsStr(VERSION_PREFIX, info.version) then
    begin
      info.version := Copy(
        info.version,
        Length(VERSION_PREFIX) + 1,
        Length(info.version) - Length(VERSION_PREFIX));
    end;
end;


procedure ReadOS2Table(stream: TStream; var info: TFontInfo);
const
  PANOSE_OFFSET = SizeOf(word) * 16;
var
  panose: TPanose;
begin
  stream.Seek(PANOSE_OFFSET, soCurrent);
  stream.ReadBuffer(panose, SizeOf(panose));

  GetPanoseInfo(@panose, info);
end;


const
  TABLE_READERS: array [0..1] of record
    tag: longword;
    reader: TTableReader;
  end = (
    (tag: TAG_NAME; reader: @ReadNameTable),
    (tag: TAG_OS2;  reader: @ReadOS2Table)
  );


function FindTableReader(tag: longword): TTableReader;
var
  i: SizeInt;
begin
  for i := 0 to High(TABLE_READERS) do
    if TABLE_READERS[i].tag = tag then
      exit(TABLE_READERS[i].reader);

  result := NIL;
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

procedure GetCommonInfo(
  stream: TStream; var info: TFontInfo; font_offset: longword);
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

      ReadTable(
        stream, info, dir.tag, font_offset + dir.offset,
        NO_COMPRESSION);

      has_layout_tables := (
        has_layout_tables or IsLayoutTable(dir.tag));
    end;

  info.format := GetFormatSting(
    offset_table.version, has_layout_tables);
end;


end.

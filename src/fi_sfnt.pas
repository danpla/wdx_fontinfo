{
  Common stuff for SFNT-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_sfnt;

interface

uses
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  sysutils;

const
  SFNT_TAG_BASE = $42415345;
  SFNT_TAG_GDEF = $47444546;
  SFNT_TAG_GPOS = $47504f53;
  SFNT_TAG_GSUB = $47535542;
  SFNT_TAG_JSTF = $4a535446;
  SFNT_TAG_NAME = $6e616d65;
  SFNT_TAG_GLYF = $676c7966;
  SFNT_TAG_LOCA = $6c6f6361;

  SFNT_TTF_SIGN1 = $00010000;
  SFNT_TTF_SIGN2 = $00020000;
  SFNT_TTF_SIGN3 = $74727565; // 'true'
  SFNT_TTF_SIGN4 = $74797031; // 'typ1'
  SFNT_OTF_SIGN = $4f54544f; // 'OTTO'

  SFNT_COLLECTION_SIGN = $74746366; // 'ttcf'

function SFNT_TagToString(tag: longword): string;
function SFNT_IsLayoutTable(tag: longword): boolean;
function SFNT_GetFormatSting(
  sign: longword; has_layout_tables: boolean): string;

type
  TSFNTTableReader = procedure(stream: TStream; var info: TFontInfo);

function SFNT_FindTableReader(tag: longword): TSFNTTableReader;

{
  Helper for TSFNTTableReader that restores the initial stream
  position after reading at the given offset. Does nothing if reader
  is NIL.
}
procedure SFNT_ReadTable(
  reader: TSFNTTableReader;
  stream: TStream;
  var info: TFontInfo;
  offset: longword);

{
  Common parser for TTF, TTC, OTF, OTC, and EOT.

  font_offset is necessary for EOT since its EMBEDDEDFONT structure
  is not treated as part of the font data.
}
procedure SFNT_GetCommonInfo(
  stream: TStream; var info: TFontInfo; font_offset: longword = 0);

implementation


function SFNT_TagToString(tag: longword): string;
begin
  SetLength(result, SizeOf(tag));
  {$IFDEF ENDIAN_LITTLE}
  tag := SwapEndian(tag);
  {$ENDIF}
  Move(tag, result[1], SizeOf(tag));
  result := TrimRight(result);
end;


function SFNT_IsLayoutTable(tag: longword): boolean;
begin
  case tag of
    SFNT_TAG_BASE,
    SFNT_TAG_GDEF,
    SFNT_TAG_GPOS,
    SFNT_TAG_GSUB,
    SFNT_TAG_JSTF:
      result := TRUE;
  else
    result := FALSE;
  end;
end;


function SFNT_GetFormatSting(
  sign: longword; has_layout_tables: boolean): string;
begin
  if sign = SFNT_OTF_SIGN then
    result := 'OT PS'
  else if has_layout_tables then
    result := 'OT TT'
  else
    result := 'TT';
end;


procedure SFNT_ReadTable(
  reader: TSFNTTableReader;
  stream: TStream;
  var info: TFontInfo;
  offset: longword);
var
  start: int64;
begin
  if reader = NIL then
    exit;

  start := stream.Position;
  stream.Seek(offset, soBeginning);
  reader(stream, info);
  stream.Seek(start, soBeginning);
end;


// "name" table

const
  PLATFORM_ID_MAC = 1;
  PLATFORM_ID_WIN = 3;

  LANGUAGE_ID_MAC_ENGLISH = 0;
  LANGUAGE_ID_WIN_ENGLISH_US = $0409;

  ENCODING_ID_MAC_ROMAN = 0;
  ENCODING_ID_WIN_UCS2 = 1;

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

    if name_rec.length = 0 then
      continue;

    case name_rec.platform_id of
      PLATFORM_ID_MAC:
        if (name_rec.encoding_id <> ENCODING_ID_MAC_ROMAN)
            or (name_rec.language_id <> LANGUAGE_ID_MAC_ENGLISH) then
          continue;
      PLATFORM_ID_WIN:
        // Entries in the Name Record are sorted by ids so we can
        // stop parsing after we finished reading all needed
        // records.
        if (name_rec.encoding_id > ENCODING_ID_WIN_UCS2)
            or (name_rec.language_id > LANGUAGE_ID_WIN_ENGLISH_US) then
          break
        else if (name_rec.encoding_id <> ENCODING_ID_WIN_UCS2)
            or (name_rec.language_id <> LANGUAGE_ID_WIN_ENGLISH_US) then
          continue;
      else
        // We don't break in case id > PLATFORM_ID_WIN so that we
        // can read old buggy TTFs produced by the AllType program.
        // The first record in such fonts has random number as id.
        continue;
    end;

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
      // We can only break early in case of Windows platform id.
      // There are fonts (like Trattatello.ttf) where mostly
      // non-standard Macintosh names (name id >= 256) are followed
      // by standard Windows names.
      if name_rec.platform_id >= PLATFORM_ID_WIN then
        break
      else
        continue;
    end;

    offset := stream.Position;
    stream.Seek(storage_offset + name_rec.offset, soBeginning);

    case name_rec.platform_id of
      PLATFORM_ID_MAC:
      begin
        SetLength(dst^, name_rec.length);
        stream.ReadBuffer(dst^[1], name_rec.length);
        dst^ := MacOSRomanToUTF8(dst^);
      end;
      PLATFORM_ID_WIN:
      begin
        SetLength(name, name_rec.length div SizeOf(WideChar));
        stream.ReadBuffer(name[1], name_rec.length);
        {$IFDEF ENDIAN_LITTLE}
        SwapUnicode(name);
        {$ENDIF}
        dst^ := UTF8Encode(name);
      end;
    end;

    stream.Seek(offset, soBeginning);
  end;
end;


const
  TABLE_READERS: array [0..0] of record
    tag: longword;
    reader: TSFNTTableReader;
  end = (
    (tag: SFNT_TAG_NAME; reader: @ReadNameTable)
  );


function SFNT_FindTableReader(tag: longword): TSFNTTableReader;
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

procedure SFNT_GetCommonInfo(
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

  if (offset_table.version <> SFNT_TTF_SIGN1)
      and (offset_table.version <> SFNT_TTF_SIGN2)
      and (offset_table.version <> SFNT_TTF_SIGN3)
      and (offset_table.version <> SFNT_TTF_SIGN4)
      and (offset_table.version <> SFNT_OTF_SIGN) then
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

    SFNT_ReadTable(
      SFNT_FindTableReader(dir.tag),
      stream,
      info,
      font_offset + dir.offset);

    has_layout_tables := (
      has_layout_tables or SFNT_IsLayoutTable(dir.tag));
  end;

  info.format := SFNT_GetFormatSting(
    offset_table.version, has_layout_tables);
end;


end.

// Common stuff for SFNT-based fonts

unit fi_sfnt;

interface

uses
  fi_common,
  classes;

const
  SFNT_TAG_BASE = $42415345;
  SFNT_TAG_FVAR = $66766172;
  SFNT_TAG_GDEF = $47444546;
  SFNT_TAG_GLYF = $676c7966;
  SFNT_TAG_GPOS = $47504f53;
  SFNT_TAG_GSUB = $47535542;
  SFNT_TAG_JSTF = $4a535446;
  SFNT_TAG_LOCA = $6c6f6361;
  SFNT_TAG_NAME = $6e616d65;

  SFNT_COLLECTION_SIGN = $74746366; // 'ttcf'

function SFNT_IsLayoutTable(tag: LongWord): Boolean;
function SFNT_GetFormatSting(
  sign: LongWord; hasLayoutTables: Boolean): String;

type
  TSFNTTableReader = procedure(stream: TStream; var info: TFontInfo);

function SFNT_FindTableReader(tag: LongWord): TSFNTTableReader;

{
  Helper for TSFNTTableReader that restores the initial stream
  position after reading at the given offset. Does nothing if reader
  is NIL.
}
procedure SFNT_ReadTable(
  reader: TSFNTTableReader;
  stream: TStream;
  var info: TFontInfo;
  offset: LongWord);

{
  Common parser for TTF, TTC, OTF, OTC, and EOT.

  fontOffset is necessary for EOT since its EMBEDDEDFONT structure
  is not treated as part of the font data.
}
procedure SFNT_ReadCommonInfo(
  stream: TStream; var info: TFontInfo; fontOffset: LongWord = 0);

implementation

uses
  fi_info_reader,
  fi_utils,
  streamex,
  sysutils;


const
  SFNT_TTF_SIGN1 = $00010000;
  SFNT_TTF_SIGN2 = $00020000;
  SFNT_TTF_SIGN3 = $74727565; // 'true'
  SFNT_TTF_SIGN4 = $74797031; // 'typ1'
  SFNT_OTF_SIGN = $4f54544f; // 'OTTO'


function SFNT_IsLayoutTable(tag: LongWord): Boolean;
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
  sign: LongWord; hasLayoutTables: Boolean): String;
begin
  if sign = SFNT_OTF_SIGN then
    result := 'OT PS'
  else if hasLayoutTables then
    result := 'OT TT'
  else
    result := 'TT';
end;


procedure SFNT_ReadTable(
  reader: TSFNTTableReader;
  stream: TStream;
  var info: TFontInfo;
  offset: LongWord);
var
  start: Int64;
begin
  if reader = NIL then
    exit;

  start := stream.Position;
  stream.Seek(offset, soBeginning);
  reader(stream, info);
  stream.Seek(start, soBeginning);
end;


procedure ReadNameTable(stream: TStream; var info: TFontInfo);
const
  PLATFORM_ID_MAC = 1;
  PLATFORM_ID_WIN = 3;

  LANGUAGE_ID_MAC_ENGLISH = 0;
  LANGUAGE_ID_WIN_ENGLISH_US = $0409;

  ENCODING_ID_MAC_ROMAN = 0;
  ENCODING_ID_WIN_UCS2 = 1;

type
  TNamingTable = packed record
    version,
    count,
    storageOffset: Word;
  end;

  TNameRecord = packed record
    platformId,
    encodingId,
    languageId,
    nameId,
    length,
    stringOffset: Word;
  end;

var
  start: Int64;
  namingTable: TNamingTable;
  storagePos,
  offset: Int64;
  i: LongInt;
  nameRec: TNameRecord;
  name: UnicodeString;
  dst: PString;
begin
  start := stream.Position;
  stream.ReadBuffer(namingTable, SizeOf(namingTable));

  {$IFDEF ENDIAN_LITTLE}
  with namingTable do
  begin
    version := SwapEndian(version);
    count := SwapEndian(count);
    storageOffset := SwapEndian(storageOffset);
  end;
  {$ENDIF}

  if namingTable.count = 0 then
    raise EStreamError.Create('Naming table has no records');

  storagePos := start + namingTable.storageOffset;

  for i := 0 to namingTable.count - 1 do
  begin
    stream.ReadBuffer(nameRec, SizeOf(nameRec));

    {$IFDEF ENDIAN_LITTLE}
    with nameRec do
    begin
      platformId := SwapEndian(platformId);
      encodingId := SwapEndian(encodingId);
      languageId := SwapEndian(languageId);
      nameId := SwapEndian(nameId);
      length := SwapEndian(length);
      stringOffset := SwapEndian(stringOffset);
    end;
    {$ENDIF}

    if nameRec.length = 0 then
      continue;

    case nameRec.platformId of
      PLATFORM_ID_MAC:
        if (nameRec.encodingId <> ENCODING_ID_MAC_ROMAN)
            or (nameRec.languageId <> LANGUAGE_ID_MAC_ENGLISH) then
          continue;
      PLATFORM_ID_WIN:
        // Entries in the Name Record are sorted by ids so we can
        // stop parsing after we finished reading all needed
        // records.
        if (nameRec.encodingId > ENCODING_ID_WIN_UCS2)
            or (nameRec.languageId > LANGUAGE_ID_WIN_ENGLISH_US) then
          break
        else if (nameRec.encodingId <> ENCODING_ID_WIN_UCS2)
            or (nameRec.languageId <> LANGUAGE_ID_WIN_ENGLISH_US) then
          continue;
      else
        // We don't break in case id > PLATFORM_ID_WIN so that we
        // can read old buggy TTFs produced by the AllType program.
        // The first record in such fonts has random number as id.
        continue;
    end;

    case nameRec.nameId of
      0:  dst := @info.copyright;
      1:  dst := @info.family;
      2:  dst := @info.style;
      3:  dst := @info.uniqueId;
      4:  dst := @info.fullName;
      5:  dst := @info.version;
      6:  dst := @info.psName;
      7:  dst := @info.trademark;
      8:  dst := @info.manufacturer;
      9:  dst := @info.designer;
      10: dst := @info.description;
      11: dst := @info.vendorUrl;
      12: dst := @info.designerUrl;
      13: dst := @info.license;
      14: dst := @info.licenseUrl;
      15: continue;  // Reserved
      16: dst := @info.family;  // Typographic Family
      17: dst := @info.style;  // Typographic Subfamily
    else
      // We can only break early in case of Windows platform id.
      // There are fonts (like Trattatello.ttf) where mostly
      // non-standard Macintosh names (name id >= 256) are followed
      // by standard Windows names.
      if nameRec.platformId >= PLATFORM_ID_WIN then
        break
      else
        continue;
    end;

    offset := stream.Position;
    stream.Seek(storagePos + nameRec.stringOffset, soBeginning);

    case nameRec.platformId of
      PLATFORM_ID_MAC:
      begin
        SetLength(dst^, nameRec.length);
        stream.ReadBuffer(dst^[1], nameRec.length);
        dst^ := MacOSRomanToUTF8(dst^);
      end;
      PLATFORM_ID_WIN:
      begin
        SetLength(name, nameRec.length div SizeOf(WideChar));
        stream.ReadBuffer(name[1], nameRec.length);
        {$IFDEF ENDIAN_LITTLE}
        SwapUnicodeEndian(name);
        {$ENDIF}
        dst^ := UTF8Encode(name);
      end;
    end;

    stream.Seek(offset, soBeginning);
  end;
end;


procedure ReadFvarTable(stream: TStream; var info: TFontInfo);
var
  start: Int64;
  axesArrayOffset,
  axisCount,
  axisSize: Word;
  i: LongInt;
begin
  start := stream.Position;

  // Skip majorVersion and minorVersion.
  stream.Seek(SizeOf(Word) * 2 , soCurrent);

  axesArrayOffset := stream.ReadWordBE;

  // Skip reserved.
  stream.Seek(SizeOf(Word) , soCurrent);

  axisCount := stream.ReadWordBE;

  // Specs say that the font must be treated as non-variable if
  // axisCount is zero.
  if axisCount = 0 then
    exit;

  axisSize := stream.ReadWordBE;

  SetLength(info.variationAxisTags, axisCount);

  for i := 0 to axisCount - 1 do
  begin
    stream.Seek(start + axesArrayOffset + axisSize * i, soBeginning);

    // Note that we don't check the variation axis record flags, since
    // we want to include even those axes that were marked as hidden
    // by the font designer.

    info.variationAxisTags[i] := stream.ReadDWordBE;
  end;

  // Variation axis records are not required to be sorted.
  specialize SortArray<LongWord>(info.variationAxisTags);
end;


const
  TABLE_READERS: array [0..1] of record
    tag: LongWord;
    reader: TSFNTTableReader;
  end = (
    (tag: SFNT_TAG_FVAR; reader: @ReadFvarTable),
    (tag: SFNT_TAG_NAME; reader: @ReadNameTable)
  );


function SFNT_FindTableReader(tag: LongWord): TSFNTTableReader;
var
  i: SizeInt;
begin
  for i := 0 to High(TABLE_READERS) do
    if TABLE_READERS[i].tag = tag then
      exit(TABLE_READERS[i].reader);

  result := NIL;
end;


procedure SFNT_ReadCommonInfo(
  stream: TStream; var info: TFontInfo; fontOffset: LongWord);
type
  TOffsetTable = packed record
    version: LongWord;
    numTables: Word;
    //searchRange,
    //entrySelector,
    //rangeShift: Word;
  end;

  TTableDirEntry = packed record
    tag,
    checksumm,
    offset,
    length: LongWord;
  end;

var
  offsetTable: TOffsetTable;
  i: LongInt;
  dir: TTableDirEntry;
  hasLayoutTables: Boolean = FALSE;
begin
  stream.ReadBuffer(offsetTable, SizeOf(offsetTable));

  {$IFDEF ENDIAN_LITTLE}
  with offsetTable do
  begin
    version := SwapEndian(version);
    numTables := SwapEndian(numTables);
  end;
  {$ENDIF}

  if (offsetTable.version <> SFNT_TTF_SIGN1)
      and (offsetTable.version <> SFNT_TTF_SIGN2)
      and (offsetTable.version <> SFNT_TTF_SIGN3)
      and (offsetTable.version <> SFNT_TTF_SIGN4)
      and (offsetTable.version <> SFNT_OTF_SIGN) then
    raise EStreamError.Create('Not a SFNT-based font');

  if offsetTable.numTables = 0 then
    raise EStreamError.Create('Font has no tables');

  stream.Seek(SizeOf(Word) * 3, soCurrent);

  for i := 0 to offsetTable.numTables - 1 do
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
      fontOffset + dir.offset);

    hasLayoutTables := (
      hasLayoutTables or SFNT_IsLayoutTable(dir.tag));
  end;

  info.format := SFNT_GetFormatSting(
    offsetTable.version, hasLayoutTables);
end;


end.

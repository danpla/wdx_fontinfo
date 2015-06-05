{
  SFNT-based fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_sfnt;

interface

uses
  fontinfo_common,
  fontinfo_utils,
  classes,
  zstream,
  sysutils;


procedure GetSFNTInfo(const FileName: string; var info: TFontInfo);

implementation

const
  TTF_MAGICK1 = $00010000;
  TTF_MAGICK2 = $00020000;
  TTF_MAGICK3 = $74727565; // 'true'
  TTF_MAGICK4 = $74797031; // 'typ1'

  TTC_OTC_MAGICK = $74746366; // 'ttcf'
  OTF_MAGICK = $4f54544f; // 'OTTO'
  WOFF_MAGICK = $774f4646; // 'wOFF'

  EOT_MAGICK = $504c;

  // SFNT table names.
  TAG_BASE = $42415345;
  TAG_GDEF = $47444546;
  TAG_GPOS = $47504f53;
  TAG_GSUB = $47535542;
  TAG_JSTF = $4a535446;
  TAG_NAME = $6e616d65;


  FORMAT_TT = 'TT';
  FORMAT_OT_PS = 'OT PS';
  FORMAT_OT_TT = 'OT TT';


type
  TTableDirEntry = packed record
    tag,
    checksumm,
    offset,
    length: longword;
  end;


  TWOFFHeader = packed record
    // signature, // Already checked.
    flavor,
    length: longword;
    numTables,
    reserved: word;
    // totalSfntSize: longword;
    // majorVersion: word;
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

  TEOTHeader = packed record
    EOTSize,
    FontDataSize,
    version,
    flags: longword;
    PANOSE: array [0..9] of byte;
    Charset,
    Italic: byte;
    Weight: longword;
    fsType,
    magick: word;
    UnicodeRange1,
    UnicodeRange2,
    UnicodeRange3,
    UnicodeRange4,
    CodePageRange1,
    CodePageRange2,
    CheckSumAdjustment,
    Reserved1,
    Reserved2,
    Reserved3,
    Reserved4: longword;
    Padding1: word;
  end;


function GetFormatSting(const sign: longword;
                        const opentype_tables: boolean): string; inline;
begin
  if sign = OTF_MAGICK then
    result := FORMAT_OT_PS
  else
    if opentype_tables then
      result := FORMAT_OT_TT
    else
      result := FORMAT_TT;
end;


{
 ===============
  Table reading
 ===============
}

type
  TTableReader = procedure(stream: TStream; var info: TFontInfo);

{
  origLength indicates size of uncompressed table (from WOFF). 0 means
    that table already uncompressed.
}
procedure ReadTable(stream: TStream; var info: TFontInfo;
                    reader: TTableReader; const offset: longword;
                    const origLength: longword = 0);
var
  start: int64;
  uncomp_data: TBytes;
  zs: TDecompressionStream = NIL;
  bs: TBytesStream = NIL;
begin
  start := stream.Position;
  stream.Seek(offset, soFromBeginning);

  if origLength = 0 then
    reader(stream, info)
  else
    try
      try
        zs := TDecompressionStream.Create(stream);
        SetLength(uncomp_data, origLength);
        zs.Read(uncomp_data[0], origLength);
        bs := TBytesStream.Create(uncomp_data);
        reader(bs, info);
      except
        on EStreamError do
          begin
          end;
      end;
    finally
      if Assigned(zs) then
        zs.Free;
      if Assigned(bs) then
        bs.Free;
    end;

  stream.Seek(start, soFromBeginning);
end;



// "name" table.

const
  PLATFORM_ID_WIN = 3;
  LANGUAGE_ID_WIN_ENGLISH_US = $0409;
  ENCODING_ID_WIN_UCS2 = 1;

type
  TNamingTable = packed record
    format,
    count,
    stringOffset: word;
  end;

  TNameRecord = packed record
    platformID,
    encodingID,
    languageID,
    nameID,
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
  name: string;
begin
  start := stream.Position;
  stream.ReadBuffer(naming_table, SizeOf(naming_table));

  {$IFDEF ENDIAN_LITTLE}
  with naming_table do
    begin
      format       := SwapEndian(format);
      count        := SwapEndian(count);
      stringOffset := SwapEndian(stringOffset);
    end;
  {$ENDIF}

  storage_offset := start + naming_table.stringOffset;

  for i := 0 to naming_table.count - 1 do
    begin
        stream.ReadBuffer(name_rec, SizeOf(name_rec));

        {$IFDEF ENDIAN_LITTLE}
        with name_rec do
          begin
            platformID := SwapEndian(platformID);
            encodingID := SwapEndian(encodingID);
            languageID := SwapEndian(languageID);
            nameID     := SwapEndian(nameID);
            length     := SwapEndian(length);
            offset     := SwapEndian(offset);
          end;
        {$ENDIF}

      // Entries in the Name Record are always sorted so that we can stop
      // parsing immediately after we finished reading the needed record.
      if (name_rec.platformID < PLATFORM_ID_WIN) or
         (name_rec.encodingID < ENCODING_ID_WIN_UCS2) or
         (name_rec.languageID < LANGUAGE_ID_WIN_ENGLISH_US) then
        continue
      else
        if (name_rec.platformID > PLATFORM_ID_WIN) or
           (name_rec.encodingID > ENCODING_ID_WIN_UCS2) or
           (name_rec.languageID > LANGUAGE_ID_WIN_ENGLISH_US) or
           (name_rec.nameID > 14) then
          break;

      offset := stream.Position;
      stream.Seek(longint(storage_offset + name_rec.offset), soFromBeginning);

      SetLength(name, name_rec.length);
      stream.Read(name[1], name_rec.length);
      name := UCS2BEToUTF8(name);

      case name_rec.nameID of
        0: info[IDX_COPYRIGHT] := name;
        1: info[IDX_FAMILY] := name;
        2: info[IDX_STYLE] := name;
        3: info[IDX_UNIQUE_ID] := name;
        4: info[IDX_FULL_NAME] := name;
        5: info[IDX_VERSION] := name;
        6: info[IDX_PS_NAME] := name;
        7: info[IDX_TRADEMARK] := name;
        8: info[IDX_MANUFACTURER] := name;
        9: info[IDX_DESIGNER] := name;
       10: info[IDX_DESCRIPTION] := name;
       11: info[IDX_VENDOR_URL] := name;
       12: info[IDX_DESIGNER_URL] := name;
       13: info[IDX_LICENSE] := name;
       14: info[IDX_LICENSE_URL] := name;
      end;

      stream.Seek(offset, soFromBeginning);
    end;
end;


{
  =======================
   Format-specific stuff
  =======================
}

{
  Common checker for TTF, TTC, OTF and OTC.

  Returns boolean indicating existence of OpenType-related tables.
}
function CheckCommon(stream: TStream; var info: TFontInfo): boolean;
var
  ntables: word;
  i: longint;
  dir: TTableDirEntry;
  opentype_tables: boolean = FALSE;
begin
  // Read offset table.
  ntables := stream.ReadWordBE;
  stream.Seek(SizeOf(word) * 3, soFromCurrent); // Skip all other fields.

  // Read all tables.
  for i := 0 to ntables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag       := SwapEndian(tag);
          checksumm := SwapEndian(checksumm);
          offset    := SwapEndian(offset);
          length    := SwapEndian(length);
        end;
      {$ENDIF}

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          opentype_tables := TRUE;
        TAG_NAME:
          ReadTable(stream, info, @NameReader, dir.offset);
      end;
    end;

  result := opentype_tables;
end;


{
  TTC or OTC.
}
procedure CheckCollection(stream: TStream; var info: TFontInfo);
var
  nfonts,
  offset,
  sign: longword;
  opentype_tables: boolean;
begin
  // Read collection header.
  stream.Seek(SizeOf(longword), soFromCurrent); // Skip version.
  nfonts := stream.ReadDWordBE;

  if nfonts = 0 then
    exit;

  // Read the first font.
  offset := stream.ReadDWordBE;
  stream.Seek(offset, soFromBeginning);

  sign := stream.ReadDWordBE;
  opentype_tables := CheckCommon(stream, info);

  info[IDX_FORMAT] := GetFormatSting(sign, opentype_tables);
  info[IDX_NFONTS] := IntToStr(nfonts);
end;


procedure CheckTTF(stream: TStream; var info: TFontInfo); inline;
var
  opentype_tables: boolean;
begin
  opentype_tables := CheckCommon(stream, info);

  if opentype_tables then
    info[IDX_FORMAT] := FORMAT_OT_TT
  else
    info[IDX_FORMAT] := FORMAT_TT;
  info[IDX_NFONTS] := '1';
end;


procedure CheckOTF(stream: TStream; var info: TFontInfo); inline;
begin
  CheckCommon(stream, info);
  info[IDX_FORMAT] := FORMAT_OT_PS;
  info[IDX_NFONTS] := '1';
end;


procedure CheckWOFF(stream: TStream; var info: TFontInfo);
var
  header: TWOFFHeader;
  i: longint;
  dir: TWOFFTableDirEntry;
  origLength: longword;
  opentype_tables: boolean = FALSE;
begin
  stream.ReadBuffer(header, SizeOf(header));
  // Skip unused.
  stream.Seek(SizeOf(word) * 2 + SizeOf(longword) * 6, soFromCurrent);

  {$IFDEF ENDIAN_LITTLE}
  with header do
    begin
      flavor    := SwapEndian(flavor);
      length    := SwapEndian(length);
      numTables := SwapEndian(numTables);
      reserved  := SwapEndian(reserved);
    end;
  {$ENDIF}

  if (header.length <> stream.Size) or
     (header.reserved <> 0) then
    exit;

  for i := 0 to header.numTables - 1 do
    begin
      stream.ReadBuffer(dir, SizeOf(dir));
      // Skip origChecksum.
      stream.Seek(SizeOf(longword), soFromCurrent);

      {$IFDEF ENDIAN_LITTLE}
      with dir do
        begin
          tag        := SwapEndian(tag);
          offset     := SwapEndian(offset);
          compLength := SwapEndian(compLength);
          origLength := SwapEndian(origLength);
        end;
      {$ENDIF}

      if dir.compLength > dir.origLength then
        exit;

      if dir.compLength < dir.origLength then
        origLength := dir.origLength
      else
        origLength := 0;

      case dir.tag of
        TAG_BASE,
        TAG_GDEF,
        TAG_GPOS,
        TAG_GSUB,
        TAG_JSTF:
          opentype_tables := TRUE;
        TAG_NAME:
          ReadTable(stream, info, @NameReader, dir.offset, origLength);
      end;
    end;

  info[IDX_FORMAT] := GetFormatSting(header.flavor, opentype_tables);
  info[IDX_NFONTS] := '1';
end;


procedure CheckEOT(stream: TStream; var info: TFontInfo);
var
  magick,
  padding: word;
  idx: TFieldIndex;
  s: string;
  s_len: word;
begin
  // Skip unused.
  stream.Seek(
    SizeOf(TEOTHeader.FontDataSize) +
    SizeOf(TEOTHeader.Version) +
    SizeOf(TEOTHeader.Flags) +
    SizeOf(TEOTHeader.PANOSE) +
    SizeOf(TEOTHeader.Charset) +
    SizeOf(TEOTHeader.Italic) +
    SizeOf(TEOTHeader.Weight) +
    SizeOf(TEOTHeader.fsType),
    soFromCurrent);

  magick := stream.ReadWordLE;
  if magick <> EOT_MAGICK then
    exit;

  // Skip unused.
  stream.Seek(
    SizeOf(TEOTHeader.UnicodeRange1) +
    SizeOf(TEOTHeader.UnicodeRange2) +
    SizeOf(TEOTHeader.UnicodeRange3) +
    SizeOf(TEOTHeader.UnicodeRange4) +
    SizeOf(TEOTHeader.CodePageRange1) +
    SizeOf(TEOTHeader.CodePageRange2) +
    SizeOf(TEOTHeader.CheckSumAdjustment)+
    SizeOf(TEOTHeader.Reserved1)+
    SizeOf(TEOTHeader.Reserved2)+
    SizeOf(TEOTHeader.Reserved3)+
    SizeOf(TEOTHeader.Reserved4),
    soFromCurrent);

  padding := stream.ReadWordLE;
  if padding <> 0 then
    exit;

  for idx in [IDX_FAMILY, IDX_STYLE, IDX_VERSION, IDX_FULL_NAME] do
    begin
      s_len := stream.ReadWordLE;
      SetLength(s, s_len);
      stream.ReadBuffer(s[1], s_len);
      info[idx] := UCS2LEToUTF8(s);

      padding := stream.ReadWordLE;
      if padding <> 0 then
        exit;
    end;

  // Currently we can't uncompress EOT to determine format.
  info[IDX_FORMAT] := 'EOT';
end;


procedure GetSFNTInfo(const FileName: string; var info: TFontInfo);
var
  f: TFileStream;
  sign: longword;
begin
  try
    f := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      sign := f.ReadDWordBE;
      case sign of
        TTF_MAGICK1,
        TTF_MAGICK2,
        TTF_MAGICK3,
        TTF_MAGICK4:
          CheckTTF(f, info);
        OTF_MAGICK:
          CheckOTF(f, info);
        WOFF_MAGICK:
          CheckWOFF(f, info);
        TTC_OTC_MAGICK:
          CheckCollection(f, info);
      else
        // Probably EOT.
        if SwapEndian(sign) = f.Size then
          CheckEOT(f, info);
      end;
    finally
      f.Free;
    end;
  except
    on Exception do
      begin
      end;
  end;
end;


end.

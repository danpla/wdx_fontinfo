// Windows' FNT/FON

unit fi_winfnt;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  streamex,
  sysutils;


const
  MZ_MAGIC = $5a4d;
  NE_MAGIC = $454e;  // New Executable
  PE_MAGIC = $4550;  // Portable Executable
  {
    Reading of PE executables is not implemented yet, since there are no
    such fonts to test: all FONs in C:\Windows\Fonts are in NE format,
    as well as everything I found on the Internet.
  }

  FNT_V1 = $100;
  FNT_V2 = $200;
  FNT_V3 = $300;

  MAX_COPYRIGHT_LEN = 60;


type
  TFNTHeader = packed record
    version: word;
    fileSize: longword;
    copyright: array [0..MAX_COPYRIGHT_LEN - 1] of char;
    fontType,
    pointSize,
    vres,
    hres,
    ascent,
    internalLeading,
    externalLeading: word;
    italic,
    underline,
    strikeout: byte;
    weight: word;
    charset: byte;
    pixWidth,
    pixHeight: word;
    pitchAndFamily: byte;
    avgWidth,
    maxWidth: word;
    firstChar,
    lastChar,
    defaultChar,
    breakChar: byte;
    bytesPerRow: word;
    deviceOffset,
    faceNameOffset,
    bitsPointer,
    bitsOffset: longword;
    reserved: byte;
    flags: longword;
    aSpace,
    bSpace,
    cSpace: word;
    colorTableOffset: longword;
    reserved1: array[0..15] of byte;
  end;

{$IF SIZEOF(TFNTHeader) <> 148}
  {$FATAL Unexpected size of TFNTHeader}
{$ENDIF}


procedure GetFNTInfo(stream: TStream; var info: TFontInfo);
var
  start: int64;
  version: word;
  copyright: string;
  italic: boolean;
  weight: word;
begin
  start := stream.Position;

  version := stream.ReadWordLE;
  if (version <> FNT_V1) and (version <> FNT_V2) and (version <> FNT_V3) then
    raise EStreamError.Create('Not a FNT file');

  stream.Seek(SizeOf(TFNTHeader.fileSize), soCurrent);

  SetLength(copyright, MAX_COPYRIGHT_LEN);
  stream.ReadBuffer(copyright[1], MAX_COPYRIGHT_LEN);
  info.copyright := TrimRight(copyright);

  stream.Seek(start + SizeUInt(@TFNTHeader(NIL^).italic), soBeginning);
  italic := stream.ReadByte = 1;

  stream.Seek(start + SizeUInt(@TFNTHeader(NIL^).weight), soBeginning);
  weight := stream.ReadWordLE;

  if italic then
  begin
    if weight = FONT_WEIGHT_REGULAR then
      info.style := 'Italic'
    else
      info.style := GetWeightName(weight) + ' Italic';
  end
  else
    info.style := GetWeightName(weight);

  stream.Seek(
    start + SizeUInt(@TFNTHeader(NIL^).faceNameOffset), soBeginning);
  stream.Seek(start + stream.ReadDWordLE, soBeginning);
  info.family := ReadPChar(stream);

  if (weight = FONT_WEIGHT_REGULAR) and not italic then
    info.fullName := info.family
  else
    info.fullName := info.family + ' ' + info.style;

  info.format := 'FNT ' + IntToStr(version shr 8);
end;


procedure ReadFNTFromNE(stream: TStream; var info: TFontInfo);
const
  // Position of the offset to the resource table
  RES_TABLE_OFFSET_POS = 36;
  END_TYPES = 0;
  // Size if the Reserved field in the TYPEINFO structure
  TYPEINFO_RESERVED_SIZE = SizeOf(longword);
  RT_FONT = $8008;
  // Total size of the NAMEINFO structure
  NAMEINFO_SIZE = 12;
var
  start: int64;
  resTableOffset: int64;
  sizeShift: word;
  typeId,
  itemCount: word;
  fontCount: word = 0;
begin
  start := stream.Position - SizeOf(word);

  stream.Seek(start + RES_TABLE_OFFSET_POS, soBeginning);
  resTableOffset := start + stream.ReadWordLE;

  stream.Seek(resTableOffset, soBeginning);

  sizeShift := stream.ReadWordLE;

  while TRUE do
  begin
    // Read TYPEINFO tables
    typeId := stream.ReadWordLE;
    if typeId = END_TYPES then
      break;

    itemCount := stream.ReadWordLE;
    if typeId = RT_FONT then
    begin
      if itemCount = 0 then
        raise EStreamError.Create('RT_FONT TYPEINFO is empty');

      fontCount := itemCount;
      stream.Seek(TYPEINFO_RESERVED_SIZE, soCurrent);
      break;
    end;

    stream.Seek(
      TYPEINFO_RESERVED_SIZE + itemCount * NAMEINFO_SIZE, soCurrent);
  end;

  if fontCount = 0 then
    raise EStreamError.Create('No RT_FONT entries in file');

  stream.Seek(stream.ReadWordLE shl sizeShift, soBeginning);
  GetFNTInfo(stream, info);

  // We don't set fontCount as TFontInfo.numFonts, since multiple
  // FNTs in FON are normally different sizes of the same font.
end;


procedure GetWinFNTInfo(stream: TStream; var info: TFontInfo);
const
  HEADER_OFFSET_POS = 60;
var
  magic: word;
  headerOffset: longword;
  exeFormat: word;
begin
  magic := stream.ReadWordLE;
  if magic = MZ_MAGIC then
  begin
    stream.Seek(HEADER_OFFSET_POS - SizeOf(magic), soCurrent);
    // This field named as eLfanew in some docs
    headerOffset := stream.ReadWordLE;

    stream.Seek(headerOffset, soBeginning);
    exeFormat := stream.ReadWordLE;
    if exeFormat = NE_MAGIC then
    begin
      ReadFNTFromNE(stream, info);
      exit;
    end;

    if exeFormat = PE_MAGIC then
      raise EStreamError.Create('PE executables are not supported yet');

    raise EStreamError.CreateFmt(
      'Unsupported executable format 0x%.2x', [exeFormat]);
  end;

  if (magic = FNT_V1) or (magic = FNT_V2) or (magic = FNT_V3) then
  begin
    stream.Seek(-SizeOf(magic), soCurrent);
    GetFNTInfo(stream, info);
    exit;
  end;

  raise EstreamError.Create('Not a Windows font');
end;


initialization
  RegisterReader(@GetWinFNTInfo, ['.fon', '.fnt']);


end.

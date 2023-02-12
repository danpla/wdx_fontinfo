// Portable Compiled Format

unit fi_pcf;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_bdf,
  classes,
  math,
  streamex,
  sysutils;


const
  PCF_FILE_VERSION = $70636601; // '\1pcf'

  PCF_PROPERTIES = 1 shl 0;

  PCF_FORMAT_MASK = $FFFFFF00;
  PCF_BYTE_MASK = 1 shl 2;

  PCF_DEFAULT_FORMAT = $00000000;


type
  TPCFTOC = packed record
    version,
    count: longword;
  end;

  TPCFTOCRec = packed record
    type_,
    format,
    size,
    offset: longword;
  end;

  TPCFPropertyRec = packed record
    nameOffset: longint;
    isString: byte;
    value: longint;
  end;


procedure ReadProperties(stream: TStream; var info: TFontInfo);
var
  format,
  numProperties,
  i: longint;
  bigEndian: boolean;
  readDw: function: longword of object;
  properties: array of TPCFPropertyRec;
  stringsLen: longint;
  strings: array of AnsiChar;
  dst: pstring;
begin
  format := stream.ReadDWordLE;
  if format and PCF_FORMAT_MASK <> PCF_DEFAULT_FORMAT then
    raise EStreamError.Create(
      'The PCF properties table has a non-default format');

  bigEndian := format and PCF_BYTE_MASK = PCF_BYTE_MASK;
  if bigEndian then
    readDw := @stream.ReadDWordBE
  else
    readDw := @stream.ReadDWordLE;

  numProperties := readDw();
  if numProperties <= 0 then
    raise EStreamError.CreateFmt(
      'The PCF properties table has a wrong number of properties (%d)',
      [numProperties]);

  SetLength(properties, numProperties);
  stream.ReadBuffer(properties[0], numProperties * SizeOf(TPCFPropertyRec));

  if numProperties and 3 <> 0 then
    stream.Seek(4 - numProperties and 3, soCurrent);

  stringsLen := readDw();
  if stringsLen <= 0 then
    raise EStreamError.CreateFmt(
      'The PCF properties table has a wrong size of strings (%d)',
      [stringsLen]);

  SetLength(strings, stringsLen);
  stream.ReadBuffer(strings[0], stringsLen);
  strings[stringsLen - 1] := #0;

  for i := 0 to numProperties - 1 do
  begin
    if properties[i].isString = 0 then
      continue;

    {$IFDEF ENDIAN_BIG}
    if not bigEndian then
    {$ELSE}
    if bigEndian then
    {$ENDIF}
      with properties[i] do
      begin
        nameOffset := SwapEndian(nameOffset);
        value := SwapEndian(value);
      end;

    if not InRange(properties[i].nameOffset, 0, stringsLen) then
      raise EStreamError.CreateFmt(
        'The PCF property %d name offset is out of bounds [0..%d]',
        [i + 1, stringsLen]);

    if not InRange(properties[i].value, 0, stringsLen) then
      raise EStreamError.CreateFmt(
        'The PCF property %d ("%s") value offset is out of bounds [0..%d]',
        [i + 1, PAnsiChar(@strings[properties[i].nameOffset]), stringsLen]);

    case String(PAnsiChar(@strings[properties[i].nameOffset])) of
      BDF_COPYRIGHT: dst := @info.copyright;
      BDF_FAMILY_NAME: dst := @info.family;
      BDF_FONT: dst := @info.psName;
      BDF_FONT_VERSION: dst := @info.version;
      BDF_FOUNDRY: dst := @info.manufacturer;
      BDF_FULL_NAME, BDF_FACE_NAME: dst := @info.fullName;
      BDF_WEIGHT_NAME: dst := @info.style;
    else
      continue;
    end;

    dst^ := String(PAnsiChar(@strings[properties[i].value]));
  end;
end;


procedure ReadPCFInfo(stream: TStream; var info: TFontInfo);
var
  toc: TPCFTOC;
  tocRec: TPCFTOCRec;
  i: longword;
begin
  stream.ReadBuffer(toc, SizeOf(toc));

  {$IFDEF ENDIAN_BIG}
  with toc do
  begin
    version := SwapEndian(version);
    count := SwapEndian(count);
  end;
  {$ENDIF}

  if toc.version <> PCF_FILE_VERSION then
    raise EStreamError.Create('Not a PCF file');

  if toc.count = 0 then
    raise EStreamError.Create('PCF has no tables');

  for i := 0 to toc.count - 1 do
  begin
    stream.ReadBuffer(tocRec, SizeOf(tocRec));

    {$IFDEF ENDIAN_BIG}
    with tocRec do
    begin
      type_ := SwapEndian(type_);
      format := SwapEndian(format);
      size := SwapEndian(size);
      ofset := SwapEndian(ofset);
    end;
    {$ENDIF}

    if tocRec.type_ = PCF_PROPERTIES then
    begin
      if tocRec.format and PCF_FORMAT_MASK <> PCF_DEFAULT_FORMAT then
        raise EStreamError.Create(
          'The PCF TOC has a non-default format for the properties table');

      stream.Seek(tocRec.offset, soBeginning);
      ReadProperties(stream, info);
      break;
    end;
  end;

  BDF_FillEmpty(info);

  info.format := 'PCF';
end;


initialization
  RegisterReader(@ReadPCFInfo, ['.pcf']);


end.

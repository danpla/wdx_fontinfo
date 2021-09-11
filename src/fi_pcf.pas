{
  Portable Compiled Format
}

{$MODE OBJFPC}
{$H+}

unit fi_pcf;

interface

uses
  fi_common,
  fi_info_reader,
  fi_bdf,
  classes,
  math,
  streamex,
  sysutils;


implementation

const
  PCF_FILE_VERSION = $70636601; // '\1pcf'

  PCF_PROPERTIES = 1 shl 0;

  PCF_FORMAT_MASK = $FFFFFF00;
  PCF_BYTE_MASK = 1 shl 2;

  PCF_DEFAULT_FORMAT = $00000000;


type
  TPCF_TOC = packed record
    version,
    count: longword;
  end;

  TPCF_TOCRec = packed record
    type_,
    format,
    size,
    offset: longword;
  end;

  TPCF_PropertyRec = packed record
    name_offset: longint;
    is_string: byte;
    value: longint;
  end;


procedure ReadProperties(stream: TStream; var info: TFontInfo);
var
  format,
  num_properties,
  i: longint;
  big_endian: boolean;
  read_dw: function: longword of object;
  properties: array of TPCF_PropertyRec;
  strings_len: longint;
  strings: array of AnsiChar;
  dst: pstring;
begin
  format := stream.ReadDWordLE;
  if format and PCF_FORMAT_MASK <> PCF_DEFAULT_FORMAT then
    raise EStreamError.Create(
      'The PCF properties table has a non-default format');

  big_endian := format and PCF_BYTE_MASK = PCF_BYTE_MASK;
  if big_endian then
    read_dw := @stream.ReadDWordBE
  else
    read_dw := @stream.ReadDWordLE;

  num_properties := read_dw();
  if num_properties <= 0 then
    raise EStreamError.CreateFmt(
      'The PCF properties table has a wrong number of properties (%d)',
      [num_properties]);

  SetLength(properties, num_properties);
  stream.ReadBuffer(properties[0], num_properties * SizeOf(TPCF_PropertyRec));

  if num_properties and 3 <> 0 then
    stream.Seek(4 - num_properties and 3, soCurrent);

  strings_len := read_dw();
  if strings_len <= 0 then
    raise EStreamError.CreateFmt(
      'The PCF properties table has a wrong size of strings (%d)',
      [strings_len]);

  SetLength(strings, strings_len);
  stream.ReadBuffer(strings[0], strings_len);
  strings[strings_len - 1] := #0;

  for i := 0 to num_properties - 1 do
  begin
    if properties[i].is_string = 0 then
      continue;

    {$IFDEF ENDIAN_BIG}
    if not big_endian then
    {$ELSE}
    if big_endian then
    {$ENDIF}
      with properties[i] do
      begin
        name_offset := SwapEndian(name_offset);
        value := SwapEndian(value);
      end;

    if not InRange(properties[i].name_offset, 0, strings_len) then
      raise EStreamError.CreateFmt(
        'The PCF property %d name offset is out of bounds [0..%d]',
        [i + 1, strings_len]);

    if not InRange(properties[i].value, 0, strings_len) then
      raise EStreamError.CreateFmt(
        'The PCF property %d ("%s") value offset is out of bounds [0..%d]',
        [i + 1, PAnsiChar(@strings[properties[i].name_offset]), strings_len]);

    case String(PAnsiChar(@strings[properties[i].name_offset])) of
      BDF_COPYRIGHT: dst := @info.copyright;
      BDF_FAMILY_NAME: dst := @info.family;
      BDF_FONT: dst := @info.ps_name;
      BDF_FOUNDRY: dst := @info.manufacturer;
      BDF_FULL_NAME, BDF_FACE_NAME: dst := @info.full_name;
      BDF_WEIGHT_NAME: dst := @info.style;
    else
      continue;
    end;

    dst^ := String(PAnsiChar(@strings[properties[i].value]));
  end;
end;


procedure GetPCFInfo(stream: TStream; var info: TFontInfo);
var
  toc: TPCF_TOC;
  toc_rec: TPCF_TOCRec;
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
    stream.ReadBuffer(toc_rec, SizeOf(toc_rec));

    {$IFDEF ENDIAN_BIG}
    with toc_rec do
    begin
      type_ := SwapEndian(type_);
      format := SwapEndian(format);
      size := SwapEndian(size);
      ofset := SwapEndian(ofset);
    end;
    {$ENDIF}

    if toc_rec.type_ = PCF_PROPERTIES then
    begin
      if toc_rec.format and PCF_FORMAT_MASK <> PCF_DEFAULT_FORMAT then
        raise EStreamError.Create(
          'The PCF TOC has a non-default format for the properties table');

      stream.Seek(toc_rec.offset, soBeginning);
      ReadProperties(stream, info);
      break;
    end;
  end;

  BDF_FillEmpty(info);

  info.format := 'PCF';
end;


initialization
  RegisterReader(@GetPCFInfo, ['.pcf']);


end.

{
  X11 PCF bitmap fonts
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_pcf;

interface

uses
  fontinfo_common,
  fontinfo_bdf,
  fontinfo_utils,
  classes,
  streamio,
  math,
  sysutils;


procedure GetPCFInfo(stream: TStream; var info: TFontInfo);

implementation

const
  PCF_MAGIC = $70636601; // '\1pcf'

  PCF_PROPERTIES = 1 shl 0;

  PCF_FORMAT_MASK = $FFFFFF00;
  PCF_BYTE_MASK = 1 shl 2;

  PCF_DEFAULT_FORMAT = $00000000;

type
  TPCF_TableRec = packed record
    type_,
    format,
    size,
    offset: longword;
  end;

  TPCF_PropertyRec = record
    name_offset: longint;
    is_string: byte;
    value: longint;
  end;


procedure ReadProperties(stream: TStream; var info: TFontInfo);
var
  format,
  num_properties,
  i: longint;
  read_dw: function: longword of object;
  properties: array of TPCF_PropertyRec;
  strings_len: longint;
  strings: array of AnsiChar;
  idx: TFieldIndex;
begin
  format := stream.ReadDWordLE;
  if format and PCF_FORMAT_MASK <> PCF_DEFAULT_FORMAT then
    exit;

  if format and PCF_BYTE_MASK = PCF_BYTE_MASK then
    read_dw := @stream.ReadDWordBE
  else
    read_dw := @stream.ReadDWordLE;

  num_properties := read_dw();
  SetLength(properties, num_properties);
  for i := 0 to num_properties - 1 do
    with properties[i] do
      begin
        name_offset := read_dw();
        is_string := stream.ReadByte;
        value := read_dw();
      end;

  if num_properties and 3 <> 0 then
    stream.Seek(4 - num_properties and 3, soFromCurrent);

  strings_len := read_dw();
  SetLength(strings, strings_len + 1);
  strings[strings_len] := #0;
  stream.ReadBuffer(strings[0], strings_len);

  for i := 0 to num_properties - 1 do
    begin
      if properties[i].is_string = 0 then
        continue;

      if not InRange(properties[i].value, 0, strings_len) or
         not InRange(properties[i].name_offset, 0, strings_len) then
        break;

      case String(PAnsiChar(@strings[properties[i].name_offset])) of
        BDF_COPYRIGHT: idx := IDX_COPYRIGHT;
        BDF_FAMILY_NAME: idx := IDX_FAMILY;
        BDF_FONT: idx := IDX_PS_NAME;
        BDF_FOUNDRY: idx := IDX_MANUFACTURER;
        BDF_FULL_NAME, BDF_FACE_NAME: idx := IDX_FULL_NAME;
        BDF_WEIGHT_NAME: idx := IDX_STYLE;
      else
        continue;
      end;

      info[idx] := String(PAnsiChar(@strings[properties[i].value]));
    end;
end;


procedure GetPCFInfo(stream: TStream; var info: TFontInfo);
var
  sign,
  num_tables: longword;
  i: longint;
  table_rec: TPCF_TableRec;
begin
  sign := stream.ReadDWordLE;
  if sign <> PCF_MAGIC then
    exit;

  num_tables := stream.ReadDWordLE;
  for i := 0 to num_tables - 1 do
    begin
      stream.ReadBuffer(table_rec, SizeOf(table_rec));

      {$IFDEF ENDIAN_BIG}
      with table_rec do
        begin
          type_ := SwapEndian(type_);
          format := SwapEndian(format);
          size := SwapEndian(size);
          ofset := SwapEndian(ofset);
        end;
      {$ENDIF}

      if (table_rec.type_ = PCF_PROPERTIES) and
         (table_rec.format and PCF_FORMAT_MASK = PCF_DEFAULT_FORMAT) then
        begin
          stream.Seek(table_rec.offset, soFromBeginning);
          ReadProperties(stream, info);
          break;
        end;
    end;

  BDF_FillEmpty(info);

  info[IDX_FORMAT] := 'PCF';
  info[IDX_NUM_FONTS] := '1';
end;


end.


{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_ttc_otc;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt_common,
  classes,
  sysutils;


implementation


type
  TCOllectionHeader = packed record
    signature,
    version,
    num_fonts,
    first_font_offset: longword;
  end;

procedure GetCollectionInfo(stream: TStream; var info: TFontInfo);
var
  header: TCOllectionHeader;
begin
  stream.ReadBuffer(header, SizeOf(header));

  {$IFDEF ENDIAN_LITTLE}
  with header do
    begin
      signature := SwapEndian(signature);
      version := SwapEndian(version);
      num_fonts := SwapEndian(num_fonts);
      first_font_offset := SwapEndian(first_font_offset);
    end;
  {$ENDIF}

  if header.signature <> COLLECTION_SIGNATURE then
    raise EStreamError.Create('Not a font collection');

  if header.num_fonts = 0 then
    raise EStreamError.Create('Collection has no fonts');

  stream.Seek(header.first_font_offset, soBeginning);
  GetCommonInfo(stream, info);

  info[IDX_NUM_FONTS] := IntToStr(header.num_fonts);
end;


initialization
  RegisterReader(@GetCollectionInfo, ['.ttc', '.otc']);


end.

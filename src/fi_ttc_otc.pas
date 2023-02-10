unit fi_ttc_otc;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes;


implementation


type
  TCOllectionHeader = packed record
    signature,
    version,
    numFonts,
    firstFontOffset: longword;
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
    numFonts := SwapEndian(numFonts);
    firstFontOffset := SwapEndian(firstFontOffset);
  end;
  {$ENDIF}

  if header.signature <> SFNT_COLLECTION_SIGN then
    raise EStreamError.Create('Not a font collection');

  if header.numFonts = 0 then
    raise EStreamError.Create('Collection has no fonts');

  stream.Seek(header.firstFontOffset, soBeginning);
  SFNT_GetCommonInfo(stream, info);

  info.numFonts := header.numFonts;
end;


initialization
  RegisterReader(@GetCollectionInfo, ['.ttc', '.otc']);


end.

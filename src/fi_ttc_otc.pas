unit fi_ttc_otc;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes;


type
  TCOllectionHeader = packed record
    signature,
    version,
    numFonts,
    firstFontOffset: LongWord;
  end;


procedure ReadCollectionInfo(stream: TStream; var info: TFontInfo);
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
  SFNT_ReadCommonInfo(stream, info);

  info.numFonts := header.numFonts;
end;


initialization
  RegisterReader(@ReadCollectionInfo, ['.ttc', '.otc']);


end.

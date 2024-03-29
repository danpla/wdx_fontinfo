// Printer Font Metrics

unit fi_pfm;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  strutils,
  streamex,
  sysutils;


const
  PFM_VERSION = 256;
  MAX_COPYRIGHT_LEN = 60;

  WEIGHT_POS = 83;
  FACE_OFFSET_POS = 105;
  DRIVER_INFO_OFFSET_POS = 139;


type
  TPFMHeader = packed record
    version: Word;
    size: LongWord;
  end;


procedure ReadPFMInfo(stream: TStream; var info: TFontInfo);
var
  header: TPFMHeader;
  copyright: String;
  p: SizeInt;
begin
  stream.ReadBuffer(header, SizeOf(header));
  {$IFDEF ENDIAN_BIG}
  with header do
  begin
    version := SwapEndian(version);
    size := SwapEndian(size);
  end;
  {$ENDIF}

  if header.version <> PFM_VERSION then
    raise EStreamError.Create('Not a PFM font');
  if header.size <> stream.Size then
    raise EStreamError.CreateFmt(
      'Size in PFM header (%u) does not match the file size (%d)',
      [header.size, stream.Size]);

  SetLength(copyright, MAX_COPYRIGHT_LEN);
  stream.ReadBuffer(copyright[1], MAX_COPYRIGHT_LEN);
  info.copyright := TrimRight(copyright);

  stream.Seek(WEIGHT_POS, soBeginning);
  info.style := GetWeightName(stream.ReadWordLE);

  stream.Seek(FACE_OFFSET_POS, soBeginning);
  stream.Seek(stream.ReadDWordLE, soBeginning);
  info.fullName := ReadCStr(stream);

  // Strip style if font uses PS name as a Full Name.
  p := RPos('-', info.fullName);
  if p <> 0 then
    info.family := Copy(info.fullName, 1, p - 1)
  else
    info.family := info.fullName;

  stream.Seek(DRIVER_INFO_OFFSET_POS, soBeginning);
  stream.Seek(stream.ReadDWordLE, soBeginning);
  info.psName := ReadCStr(stream);

  info.format := 'PFM';
end;


initialization
  RegisterReader(@ReadPFMInfo, ['.pfm']);


end.

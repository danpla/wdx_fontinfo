{
  Printer Font Metrics
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_pfm;

interface

uses
  fi_common,
  fi_info_reader,
  fi_utils,
  classes,
  strutils,
  streamex,
  sysutils;


implementation

const
  PFM_VERSION = 256;
  MAX_COPYRIGHT_LEN = 60;

  WEIGHT_POS = 83;
  FACE_OFFSET_POS = 105;
  DRIVER_INFO_OFFSET_POS = 139;


type
  TPFMHeader = packed record
    version: word;
    size: longword;
  end;


procedure GetPFMInfo(stream: TStream; var info: TFontInfo);
var
  header: TPFMHeader;
  copyright: string;
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
  info.full_name := ReadPChar(stream);

  // Strip style if font uses PS name as a Full Name.
  p := RPos('-', info.full_name);
  if p <> 0 then
    info.family := Copy(info.full_name, 1, p - 1)
  else
    info.family := info.full_name;

  stream.Seek(DRIVER_INFO_OFFSET_POS, soBeginning);
  stream.Seek(stream.ReadDWordLE, soBeginning);
  info.ps_name := ReadPChar(stream);

  info.format := 'PFM';
end;


initialization
  RegisterReader(@GetPFMInfo, ['.pfm']);


end.

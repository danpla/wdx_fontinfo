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
      'Size in PFM header (%u) does not match the file size (%u)',
      [header.size, stream.Size]);

  SetLength(copyright, MAX_COPYRIGHT_LEN);
  stream.ReadBuffer(copyright[1], MAX_COPYRIGHT_LEN);
  info[IDX_COPYRIGHT] := TrimRight(copyright);

  stream.Seek(WEIGHT_POS, soBeginning);
  info[IDX_STYLE] := GetWeightName(stream.ReadWordLE);

  stream.Seek(FACE_OFFSET_POS, soBeginning);
  stream.Seek(stream.ReadDWordLE, soBeginning);
  info[IDX_FULL_NAME] := stream.ReadPChar;

  // Strip style if font uses PS name as a Full Name.
  p := RPos('-', info[IDX_FULL_NAME]);
  if p <> 0 then
    info[IDX_FAMILY] := Copy(info[IDX_FULL_NAME], 1, p - 1)
  else
    info[IDX_FAMILY] := info[IDX_FULL_NAME];

  stream.Seek(DRIVER_INFO_OFFSET_POS, soBeginning);
  stream.Seek(stream.ReadDWordLE, soBeginning);
  info[IDX_PS_NAME] := stream.ReadPChar;

  info[IDX_FORMAT] := 'PFM';
  info[IDX_NUM_FONTS] := '1';
end;


initialization
  RegisterReader(@GetPFMInfo, ['.pfm']);


end.

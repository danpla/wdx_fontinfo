{
  Printer Font Metrics
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_pfm;

interface

uses
  fontinfo_common,
  fontinfo_utils,
  classes,
  strutils,
  sysutils;


procedure GetPFMInfo(stream: TStream; var info: TFontInfo);

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
  copyright: string[MAX_COPYRIGHT_LEN];
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

  if (header.version <> PFM_VERSION) or
     (header.size <> stream.Size) then
    exit;

  stream.ReadBuffer(copyright[1], MAX_COPYRIGHT_LEN);
  info[IDX_COPYRIGHT] := TrimRight(copyright);

  stream.Seek(WEIGHT_POS, soFromBeginning);
  info[IDX_STYLE] := GetWeightName(stream.ReadWordLE);

  stream.Seek(FACE_OFFSET_POS, soFromBeginning);
  stream.Seek(stream.ReadDWordLE, soFromBeginning);
  info[IDX_FULL_NAME] := stream.ReadPChar;

  // Strip style if font uses PS name as a Full Name.
  p := RPos('-', info[IDX_FULL_NAME]);
  if p <> 0 then
    info[IDX_FAMILY] := Copy(info[IDX_FULL_NAME], 1, p - 1)
  else
    info[IDX_FAMILY] := info[IDX_FULL_NAME];

  stream.Seek(DRIVER_INFO_OFFSET_POS, soFromBeginning);
  stream.Seek(stream.ReadDWordLE, soFromBeginning);
  info[IDX_PS_NAME] := stream.ReadPChar;

  info[IDX_FORMAT] := 'PFM';
  info[IDX_NUM_FONTS] := '1';
end;


end.

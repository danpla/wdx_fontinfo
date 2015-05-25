{
  Printer Font Metricks
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


procedure GetPFMInfo(const FileName: string; var info: TFontInfo);

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


procedure GetPFMInfo(const FileName: string; var info: TFontInfo);
var
  f: TFileStream;
  header: TPFMHeader;
  copyright: string[MAX_COPYRIGHT_LEN];
  full_name: string;
  p: longint;
begin
  try
    f := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      f.ReadBuffer(header, SizeOf(header));
      {$IFDEF ENDIAN_BIG}
      with header do
        begin
          version := SwapEndian(version);
          size := SwapEndian(size);
        end;
      {$ENDIF}

      if (header.version <> PFM_VERSION) or
         (header.size <> f.Size) then
        exit;

      f.ReadBuffer(copyright[1], MAX_COPYRIGHT_LEN);
      info[IDX_COPYRIGHT] := TrimRight(copyright);

      f.Seek(WEIGHT_POS, soFromBeginning);
      info[IDX_STYLE] := GetWeightName(f.ReadWordLE);

      f.Seek(FACE_OFFSET_POS, soFromBeginning);
      f.Seek(f.ReadDWordLE, soFromBeginning);
      full_name := f.ReadPChar;

      info[IDX_FULL_NAME] := full_name;

      // Strip style if font uses PS name as a Full Name.
      p := RPos('-', full_name);
      if p <> 0 then
        info[IDX_FAMILY] := Copy(full_name, 1, p - 1)
      else
        info[IDX_FAMILY] := info[IDX_FULL_NAME];

      f.Seek(DRIVER_INFO_OFFSET_POS, soFromBeginning);
      f.Seek(f.ReadDWordLE, soFromBeginning);
      info[IDX_PS_NAME] := f.ReadPChar;

      info[IDX_FORMAT] := 'PFM';
    finally
      f.Free;
    end;
  except
    on Exception do
      begin
      end;
  end;
end;



end.

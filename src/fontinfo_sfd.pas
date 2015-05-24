{
  FontForge's Spline Font Database

  Currently we don't parse whole file (for speed) — just few first lines,
  which is should be enough to get basic info from most of SFD files.
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_sfd;

interface

uses
  fontinfo_common,
  sysutils;


procedure GetSFDInfo(const FileName: string; var info: TFontInfo);


implementation

const
  SFD_SIGN = 'SplineFontDB:';
  NFIELDS = 6; // Number of fields we need to find.
  MAX_LINES = 30;


procedure GetSFDInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  sign: string[Length(SFD_SIGN)];
  version: string;
  i: longint;
  s,
  key: string;
  p,
  nfound: longint;
  idx: TFieldIndex;
begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  ReadLn(t, sign, version);
  if sign = SFD_SIGN then
    begin
      info[IDX_FORMAT] := 'SFD ' + TrimLeft(version);

      i := 1;
      nfound := 0;
      while (nfound < NFIELDS) and (i <= MAX_LINES) and not EOF(t) do
        begin
          ReadLn(t, s);
          if s = '' then
            break;

          p := Pos(' ', s);
          if p = 0 then
            continue;

          inc(i);

          key := Copy(s, 1, p - 1);
          case key of
            'FontName:': idx := IDX_PS_NAME;
            'FullName:': idx := IDX_FULL_NAME;
            'FamilyName:': idx := IDX_FAMILY;
            'Weight:': idx := IDX_STYLE;
            'Copyright:': idx := IDX_COPYRIGHT;
            'Version:': idx := IDX_VERSION;
          else
            continue;
          end;

          info[idx] := RightStr(s, Length(s) - p);
          inc(nfound);
        end;
    end;

  Close(t);
end;


end.

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
  idx,
  nfound: longint;
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
      idx := -1;
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
            'FontName:': idx := longint(IDX_PS_NAME);
            'FullName:': idx := longint(IDX_FULL_NAME);
            'FamilyName:': idx := longint(IDX_FAMILY);
            'Weight:': idx := longint(IDX_STYLE);
            'Copyright:': idx := longint(IDX_COPYRIGHT);
            'Version:': idx := longint(IDX_VERSION);
          else
            continue;
          end;

          info[TFieldIndex(idx)] := RightStr(s, Length(s) - p);
          inc(nfound);
          idx := -1;
        end;
    end;

  Close(t);
end;


end.

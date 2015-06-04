{
  Adobe Font Metricks and FontForge's Spline Font Database
}

{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fontinfo_afm_sfd;

interface

uses
  fontinfo_common,
  sysutils;


procedure GetSFDorAFMInfo(const FileName: string; var info: TFontInfo);


implementation

const
  AFM_SIGN = 'StartFontMetrics';
  SFD_SIGN = 'SplineFontDB:';

  NFIELDS = 6; // Number of fields we need to find.
  MAX_LINES = 30;


function ReadSign(var t: text; var info: TFontInfo): boolean; inline;
var
  s: string;
  p: longint;
begin
  ReadLn(t, s);
  if s = '' then
    exit(FALSE);

  p := Pos(' ', s);
  if p = 0 then
    exit(FALSE);

  case Copy(s, 1, p - 1) of
    AFM_SIGN: info[IDX_FORMAT] := 'AFM ';
    SFD_SIGN: info[IDX_FORMAT] := 'SFD ';
  else
    exit(FALSE);
  end;

  info[IDX_FORMAT] := info[IDX_FORMAT] + Copy(s, p + 1, Length(s) - p);
  result := TRUE;
end;


procedure GetSFDorAFMInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  i: longint;
  s,
  key: string;
  p,
  s_len,
  nfound: longint;
  idx: TFieldIndex;
begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if IOResult <> 0 then
    exit;

  if not ReadSign(t, info) then
    begin
      Close(t);
      exit;
    end;

  i := 1;
  nfound := 0;
  while (nfound < NFIELDS) and (i <= MAX_LINES) and not EOF(t) do
    begin
      ReadLn(t, s);
      if s = '' then
        break;

      s_len := Length(s);
      p := Pos(' ', s);
      if (p < 2) or not (p < s_len - 2) then
        continue;

      inc(i);

      // Skip colon in SFD.
      if s[p - 1] = ':' then
        key := Copy(s, 1, p - 2)
      else
        key := Copy(s, 1, p - 1);

      case key of
        'FontName': idx := IDX_PS_NAME;
        'FullName': idx := IDX_FULL_NAME;
        'FamilyName': idx := IDX_FAMILY;
        'Weight': idx := IDX_STYLE;
        'Copyright': idx := IDX_COPYRIGHT;
        'Notice':
          begin
            // Skip brackets that may have been added by FontForge.
            if (s[p + 1] = '(') and (s[s_len] = ')') then
              begin
                inc(p);
                dec(s_len);
              end;

            idx := IDX_COPYRIGHT;
          end;
        'Version': idx := IDX_VERSION;
      else
        continue;
      end;

      info[idx] := Copy(s, p + 1, s_len - p);
      inc(nfound);
    end;

  info[IDX_NFONTS] := '1';

  Close(t);
end;


end.

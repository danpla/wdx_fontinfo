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
  fontinfo_common;


procedure GetSFDInfo(const FileName: string; var info: TFontInfo);


implementation

const
  DELIM = ': ';
  MAX_LINES = 10;


procedure GetSFDInfo(const FileName: string; var info: TFontInfo);
var
  t: text;
  i: longint;
  key,
  val: string;

  function ReadLnAndSplit: boolean;
  var
    s: string;
    p,
    val_start: SizeInt;
  begin
    ReadLn(t, s);
    if s = '' then
      exit(FALSE);

    p := Pos(DELIM, s);
    if p = 0 then
      exit(FALSE);

    key := Copy(s, 1, p - 1);
    val_start := p + Length(DELIM);
    val := Copy(s, val_start, Length(s) - (val_start - 1));

    result := True;
  end;

begin
  Assign(t, FileName);
  {I-}
  Reset(t);
  {I+}
  if (IOResult <> 0) or
     (not ReadLnAndSplit) or
     (key <> 'SplineFontDB') then
    exit;

  info[IDX_FORMAT] := 'SFD ' + val;

  for i := 1 to MAX_LINES do
    if ReadlnAndSplit then
      case key of
        'FontName': info[IDX_PS_NAME] := val;
        'FullName': info[IDX_FULL_NAME] := val;
        'FamilyName': info[IDX_FAMILY] := val;
        'Weight': info[IDX_STYLE] := val;
        'Copyright': info[IDX_COPYRIGHT] := val;
        'Version': info[IDX_VERSION] := val;
      end
    else
      break;

  Close(t);
end;


end.

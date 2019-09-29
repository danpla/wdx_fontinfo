
{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_ttf_otf;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt_common,
  classes,
  sysutils;


implementation


procedure GetOTFInfo(stream: TStream; var info: TFontInfo);
begin
  GetCommonInfo(stream, info);
  info[IDX_NUM_FONTS] := '1';
end;


initialization
  RegisterReader(@GetOTFInfo, ['.ttf', '.otf']);


end.


{$MODE OBJFPC}
{$H+}
{$INLINE ON}

unit fi_ttf_otf;

interface

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes;


implementation


procedure GetOTFInfo(stream: TStream; var info: TFontInfo);
begin
  GetCommonInfo(stream, info);
end;


initialization
  RegisterReader(@GetOTFInfo, ['.ttf', '.otf', '.otb']);


end.

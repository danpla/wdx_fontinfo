unit fi_ttf_otf;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes;


procedure GetOTFInfo(stream: TStream; var info: TFontInfo);
begin
  SFNT_GetCommonInfo(stream, info);
end;


initialization
  RegisterReader(@GetOTFInfo, ['.ttf', '.otf', '.otb']);


end.

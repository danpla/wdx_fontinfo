unit fi_ttf_otf;

interface

implementation

uses
  fi_common,
  fi_info_reader,
  fi_sfnt,
  classes;


procedure ReadOTFInfo(stream: TStream; var info: TFontInfo);
begin
  SFNT_ReadCommonInfo(stream, info);
end;


initialization
  RegisterReader(@ReadOTFInfo, ['.ttf', '.otf', '.otb']);


end.

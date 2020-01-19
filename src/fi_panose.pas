{$MODE OBJFPC}
{$H+}

unit fi_panose;

interface

uses
  fi_common,
  classes;


type
  TPanose = packed record
    family_type,
    serif_style,
    weight,
    proportion,
    contrast,
    stroke_variation,
    arm_style,
    letterform,
    midline,
    x_height: byte;
  end;

  PPanose = ^TPanose;


procedure GetPanoseInfo(const panose: PPanose; var info: TFontInfo);


implementation


const
  FAMILY_TYPE_TEXT_AND_DISPLAY = 2;
  FAMILY_TYPE_SCRIPT = 3;
  FAMILY_TYPE_DECORATIVE = 4;
  FAMILY_TYPE_PICTORAL = 5;

  SERIF_STYLE_NORMAL_SANS = 11;

  PROPORTION_MONOSPACED = 9;


procedure GetPanoseInfo(const panose: PPanose; var info: TFontInfo);
begin
  Assert(panose <> NIL);

  if panose^.family_type = FAMILY_TYPE_TEXT_AND_DISPLAY then
    begin
      if panose^.proportion = PROPORTION_MONOSPACED then
        info.generic_family := GENERIC_FAMILY_MONO
      else if panose^.serif_style = SERIF_STYLE_NORMAL_SANS then
        info.generic_family := GENERIC_FAMILY_SANS
      else
        info.generic_family := GENERIC_FAMILY_SERIF;
    end
  else if panose^.family_type = FAMILY_TYPE_SCRIPT then
    info.generic_family := GENERIC_FAMILY_SCRIPT
  else if panose^.family_type = FAMILY_TYPE_DECORATIVE then
    info.generic_family := GENERIC_FAMILY_DISPLAY;
end;


end.

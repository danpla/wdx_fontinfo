unit fi_common;

interface

uses
  strutils;

type
  TFontInfo = record
    family,
    style,
    fullName,
    psName,
    version,
    copyright,
    uniqueId,
    trademark,
    manufacturer,
    designer,
    description,
    vendorUrl,
    designerUrl,
    license,
    licenseUrl,
    format: string;
    variationAxisTags: array of longword;
    numFonts: longint;
  end;


const
  FONT_WEIGHT_REGULAR = 400;

function GetWeightName(weight: word): string;

{
  Extract style from fullName using familyName.
}
function ExtractStyle(const fullName, familyName: string;
                      const fallback: string = 'Regular'): string;

implementation


function GetWeightName(weight: word): string;
const NAMES: array [0..9] of string = (
  'Thin',
  'ExtraLight',
  'Light',
  'Regular',
  'Medium',
  'SemiBold',
  'Bold',
  'ExtraBold',
  'Black',
  'ExtraBlack'
  );
begin
  if weight > 0 then
  begin
    if weight > 1000 then
      // Map to Regular
      weight := FONT_WEIGHT_REGULAR - 1
    else
      dec(weight);
  end;

  result := NAMES[weight div 100];
end;


function ExtractStyle(const fullName, familyName: string;
                      const fallback: string): string;
var
  styleStart,
  styleLen,
  fullNameLen: SizeInt;
begin
  result := fallback;

  if fullName = familyName then
    exit;

  if (fullName = '')
      or (familyName = '')
      or not AnsiStartsStr(familyName, fullName) then
    exit;

  styleStart := Length(familyName) + 1;
  fullNameLen := Length(fullName);
  if styleStart = fullNameLen then
    exit;

  if fullName[styleStart] in [' ', '-'] then
    inc(styleStart);

  styleLen := fullNameLen - styleStart + 1;
  if styleLen < 1 then
    exit;

  result := Copy(fullName, styleStart, styleLen);
end;

end.

unit fi_common;

interface

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
    format: String;
    variationAxisTags: array of LongWord;
    numFonts: LongInt;
  end;


const
  FONT_WEIGHT_REGULAR = 400;

function GetWeightName(weight: Word): String;

// Extract style from fullName using familyName.
function ExtractStyle(const fullName, familyName: String;
                      const fallback: String = 'Regular'): String;

implementation

uses
  strutils;


function GetWeightName(weight: Word): String;
const NAMES: array [0..9] of String = (
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
      Dec(weight);
  end;

  result := NAMES[weight div 100];
end;


function ExtractStyle(const fullName, familyName: String;
                      const fallback: String): String;
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
    Inc(styleStart);

  styleLen := fullNameLen - styleStart + 1;
  if styleLen < 1 then
    exit;

  result := Copy(fullName, styleStart, styleLen);
end;


end.

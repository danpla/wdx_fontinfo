{$MODE OBJFPC}
{$H+}

unit fi_common;

interface

uses
  strutils;

type
  TFieldIndex = (
    IDX_FAMILY,
    IDX_STYLE,
    IDX_FULL_NAME,
    IDX_PS_NAME,
    IDX_VERSION,
    IDX_COPYRIGHT,
    IDX_UNIQUE_ID,
    IDX_TRADEMARK,
    IDX_MANUFACTURER,
    IDX_DESIGNER,
    IDX_DESCRIPTION,
    IDX_VENDOR_URL,
    IDX_DESIGNER_URL,
    IDX_LICENSE,
    IDX_LICENSE_URL,
    IDX_FORMAT,
    IDX_NUM_FONTS
  );

  TFontInfo = array [TFieldIndex] of string;

const
  TFieldNames: array [TFieldIndex] of string = (
    'Family',
    'Style',
    'Full Name',
    'PostScript Name',
    'Version',
    'Copyright',
    'Unique ID',
    'Trademark',
    'Manufacturer',
    'Designer',
    'Description',
    'Vendor URL',
    'Designer URL',
    'License',
    'License URL',
    'Format',
    'Number of Fonts'
    );


function GetWeightName(weight: word): string;

{
  Extract style from FullName using FamilyName.
  On errors, falls back to "Regular" or to weight if it is not empty.
}
function ExtractStyle(const full_name, family_name: string;
                      const weight: string = ''): string;

implementation


function GetWeightName(weight: word): string;
begin
  case weight of
    100: result := 'Thin';
    200: result := 'ExtraLight';
    300: result := 'Light';
    500: result := 'Medium';
    600: result := 'SemiBold';
    700: result := 'Bold';
    800: result := 'ExtraBold';
    900: result := 'Black';
    950: result := 'ExtraBlack';
  else
    result := 'Regular';
  end;
end;


function ExtractStyle(const full_name, family_name: string;
                      const weight: string = ''): string;
var
  style_start,
  style_len,
  full_name_len: SizeInt;
begin
  result := 'Regular';

  if full_name = family_name then
    exit;

  if weight <> '' then
    result := weight;

  if (full_name = '') or
     (family_name = '') or
     not AnsiStartsStr(family_name, full_name) then
    exit;

  style_start := Length(family_name) + 1;
  full_name_len := Length(full_name);
  if style_start = full_name_len then
    exit;

  if full_name[style_start] in [' ', '-'] then
    inc(style_start);

  style_len := full_name_len - style_start + 1;
  if style_len < 1 then
    exit;

  result := Copy(full_name, style_start, style_len);
end;

end.

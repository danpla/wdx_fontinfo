{$MODE OBJFPC}
{$H+}

unit fi_common;

interface

uses
  strutils;

type
  TGenericFamily = (
    GENERIC_FAMILY_UNKNOWN,
    GENERIC_FAMILY_SANS,
    GENERIC_FAMILY_SERIF,
    GENERIC_FAMILY_MONO,
    GENERIC_FAMILY_SCRIPT,
    GENERIC_FAMILY_DISPLAY
  );

  TFontInfo = record
    generic_family: TGenericFamily;
    family,
    style,
    full_name,
    ps_name,
    version,
    copyright,
    unique_id,
    trademark,
    manufacturer,
    designer,
    description,
    vendor_url,
    designer_url,
    license,
    license_url,
    format: string;
    num_fonts: longint;
  end;

  PFontInfo = ^TFontInfo;


function GetWeightName(weight: word): string;

{
  Extract style from FullName using FamilyName.
  On errors, falls back to "Regular" or to weight if it is not empty.
}
function ExtractStyle(const full_name, family_name: string;
                      const weight: string = ''): string;

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
        weight := 399
      else
        dec(weight);
    end;

  result := NAMES[weight div 100];
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

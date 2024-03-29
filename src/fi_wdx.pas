{
  Font info WDX plugin.

  Copyright (c) 2015-2023 Daniel Plakhotich

  This software is provided 'as-is', without any express or implied
  warranty. In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
  claim that you wrote the original software. If you use this software
  in a product, an acknowledgement in the product documentation would be
  appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
  misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.
}

library fi_wdx;

{$INCLUDE calling.inc}

uses
  fi_common,
  fi_info_reader,
  fi_afm_sfd,
  fi_bdf,
  fi_eot,
  fi_inf,
  fi_pcf,
  fi_pfm,
  fi_ps,
  fi_ttc_otc,
  fi_ttf_otf,
  fi_utils,
  fi_winfnt,
  fi_woff,
  {$IFDEF ENABLE_WOFF2}
  fi_woff2,
  {$ENDIF}
  wdxplugin,
  classes,
  strutils,
  sysutils,
  zstream;


procedure ContentGetDetectString(
  detectString: PAnsiChar; maxLen: Integer); dcpcall;
var
  s,
  ext: String;
begin
  s := 'EXT="GZ"';

  for ext in GetSupportedExtensions do
    s := s + '|EXT="' + UpperCase(Copy(ext, 2, Length(ext) - 1)) + '"';

  StrPLCopy(detectString, s, maxLen - 1);
end;


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
    IDX_VARIATION_AXIS_TAGS,
    IDX_NUM_FONTS
  );

  TFieldInfo = record
    name: String;
    fieldType: Integer;
  end;


const
  FieldInfo: array [TFieldIndex] of TFieldInfo = (
    (name: 'Family';              fieldType: FT_STRING),
    (name: 'Style';               fieldType: FT_STRING),
    (name: 'Full Name';           fieldType: FT_STRING),
    (name: 'PostScript Name';     fieldType: FT_STRING),
    (name: 'Version';             fieldType: FT_STRING),
    (name: 'Copyright';           fieldType: FT_STRING),
    (name: 'Unique ID';           fieldType: FT_STRING),
    (name: 'Trademark';           fieldType: FT_STRING),
    (name: 'Manufacturer';        fieldType: FT_STRING),
    (name: 'Designer';            fieldType: FT_STRING),
    (name: 'Description';         fieldType: FT_STRING),
    (name: 'Vendor URL';          fieldType: FT_STRING),
    (name: 'Designer URL';        fieldType: FT_STRING),
    (name: 'License';             fieldType: FT_STRING),
    (name: 'License URL';         fieldType: FT_STRING),
    (name: 'Format';              fieldType: FT_STRING),
    (name: 'Variation Axis Tags'; fieldType: FT_STRING),
    (name: 'Number of Fonts';     fieldType: FT_NUMERIC_32)
  );


function ContentGetSupportedField(
  fieldIndex: Integer;
  fieldName: PAnsiChar;
  units: PAnsiChar;
  maxLen: Integer): Integer; dcpcall;
begin
  StrPCopy(units, EmptyStr);

  if fieldIndex > Ord(High(TfieldIndex)) then
    exit(FT_NOMOREFIELDS);

  StrPLCopy(
    fieldName, FieldInfo[TfieldIndex(fieldIndex)].name, maxLen - 1);
  result := FieldInfo[TfieldIndex(fieldIndex)].fieldType;
end;


function Put(
  const str: String; fieldValue: PByte; maxLen: Integer): Integer;
begin
  if str = '' then
    exit(FT_FIELDEMPTY);

  {$IFDEF WINDOWS}
  StrPLCopy(
    PWideChar(fieldValue),
    UTF8Decode(str),
    (maxLen - 1) div SizeOf(WideChar));
  result := FT_STRINGW;
  {$ELSE}
  StrPLCopy(PAnsiChar(fieldValue), str, maxLen - 1);
  result := FT_STRING;
  {$ENDIF}
end;


function TagsToString(const tags: array of LongWord): String;
var
  tag: LongWord;
begin
  result := '';

  for tag in tags do
  begin
    if result <> '' then
      result := result + ',';

    result := result + TagToString(tag);
  end;
end;


function Put(int: LongInt; fieldValue: PByte): Integer;
begin
  PLongint(fieldValue)^ := int;
  result := FT_NUMERIC_32;
end;


function Put(
  constref info: TFontInfo;
  fieldIndex: TFieldIndex;
  fieldValue: PByte;
  maxLen: Integer): Integer;
begin
  case fieldIndex of
    IDX_FAMILY:
      result := Put(info.family, fieldValue, maxLen);
    IDX_STYLE:
      result := Put(info.style, fieldValue, maxLen);
    IDX_FULL_NAME:
      result := Put(info.fullName, fieldValue, maxLen);
    IDX_PS_NAME:
      result := Put(info.psName, fieldValue, maxLen);
    IDX_VERSION:
      result := Put(info.version, fieldValue, maxLen);
    IDX_COPYRIGHT:
      result := Put(info.copyright, fieldValue, maxLen);
    IDX_UNIQUE_ID:
      result := Put(info.uniqueId, fieldValue, maxLen);
    IDX_TRADEMARK:
      result := Put(info.trademark, fieldValue, maxLen);
    IDX_MANUFACTURER:
      result := Put(info.manufacturer, fieldValue, maxLen);
    IDX_DESIGNER:
      result := Put(info.designer, fieldValue, maxLen);
    IDX_DESCRIPTION:
      result := Put(info.description, fieldValue, maxLen);
    IDX_VENDOR_URL:
      result := Put(info.vendorUrl, fieldValue, maxLen);
    IDX_DESIGNER_URL:
      result := Put(info.designerUrl, fieldValue, maxLen);
    IDX_LICENSE:
      result := Put(info.license, fieldValue, maxLen);
    IDX_LICENSE_URL:
      result := Put(info.licenseUrl, fieldValue, maxLen);
    IDX_FORMAT:
      result := Put(info.format, fieldValue, maxLen);
    IDX_VARIATION_AXIS_TAGS:
      result := Put(
        TagsToString(info.variationAxisTags), fieldValue, maxLen);
    IDX_NUM_FONTS:
      result := Put(info.numFonts, fieldValue);
  else
    result := FT_NOSUCHFIELD;
  end;
end;


procedure Reset(out info: TFontInfo);
begin
  info := Default(TFontInfo);
  info.numFonts := 1;
end;


function ReadFontInfo(const fileName: String; var info: TFontInfo): Boolean;
const
  VERSION_PREFIX = 'Version ';
var
  ext: String;
  gzipped: Boolean = FALSE;
  stream: TStream;
  reader: TInfoReader;
begin
  ext := LowerCase(ExtractFileExt(fileName));

  if ext = '.gz' then
  begin
    gzipped := TRUE;
    ext := LowerCase(ExtractFileExt(
      Copy(fileName, 1, Length(fileName) - Length(ext))));
  end;

  reader := FindReader(ext);
  if reader = NIL then
    exit(FALSE);

  try
    if gzipped then
      stream := TGZFileStream.Create(fileName, gzOpenRead)
    else
      stream := TFileStream.Create(
        fileName, fmOpenRead or fmShareDenyNone);

    Reset(info);

    try
      reader(stream, info);
    finally
      stream.Free;
    end;
  except
    on E: EStreamError do
    begin
      {$IFDEF DEBUG}
      WriteLn(StdErr, 'fontinfo "', fileName, '": ', E.Message);
      {$ENDIF}

      exit(FALSE);
    end;
  end;

  Assert(
    info.format <> '', 'Font format was not set for ' + fileName);

  if StartsText(VERSION_PREFIX, info.version) then
    info.version := Copy(
      info.version,
      Length(VERSION_PREFIX) + 1,
      Length(info.version) - Length(VERSION_PREFIX));

  result := TRUE;
end;


var
  lastFileName: String;
  infoCache: TFontInfo;
  // infoCacheValid is TRUE if TFontInfo was loaded without errors
  infoCacheValid: Boolean;


function ContentGetValue(
  fileName: PAnsiChar;
  fieldIndex,
  unitIndex: Integer;
  fieldValue: PByte;
  maxLen,
  flags: Integer): Integer; dcpcall;
var
  fileNameStr: String;
begin
  if fieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOSUCHFIELD);

  fileNameStr := String(fileName);

  if lastFileName <> fileNameStr then
  begin
    if flags and CONTENT_DELAYIFSLOW <> 0 then
      exit(FT_DELAYED);

    infoCacheValid := ReadFontInfo(fileNameStr, infoCache);
    lastFileName := fileNameStr;
  end;

  if not infoCacheValid then
    exit(FT_FILEERROR);

  result := Put(
    infoCache, TFieldIndex(fieldIndex), fieldValue, maxLen);
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;


end.

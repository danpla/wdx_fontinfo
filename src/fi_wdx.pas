{
  Font info WDX plugin.

  Copyright (c) 2015-2021 Daniel Plakhotich

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
  DetectString: PAnsiChar; MaxLen: Integer); dcpcall;
var
  s,
  ext: string;
begin
  s := 'EXT="GZ"';
  for ext in GetSupportedExtensions() do
    s := s + '|EXT="' + UpperCase(Copy(ext, 2, Length(ext) - 1)) + '"';

  StrPLCopy(DetectString, s, MaxLen);
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
    IDX_NUM_FONTS
  );

  TFieldInfo = record
    name: string;
    field_type: Integer;
  end;

const
  FieldInfo: array [TFieldIndex] of TFieldInfo = (
    (name: 'Family';          field_type: FT_STRING),
    (name: 'Style';           field_type: FT_STRING),
    (name: 'Full Name';       field_type: FT_STRING),
    (name: 'PostScript Name'; field_type: FT_STRING),
    (name: 'Version';         field_type: FT_STRING),
    (name: 'Copyright';       field_type: FT_STRING),
    (name: 'Unique ID';       field_type: FT_STRING),
    (name: 'Trademark';       field_type: FT_STRING),
    (name: 'Manufacturer';    field_type: FT_STRING),
    (name: 'Designer';        field_type: FT_STRING),
    (name: 'Description';     field_type: FT_STRING),
    (name: 'Vendor URL';      field_type: FT_STRING),
    (name: 'Designer URL';    field_type: FT_STRING),
    (name: 'License';         field_type: FT_STRING),
    (name: 'License URL';     field_type: FT_STRING),
    (name: 'Format';          field_type: FT_STRING),
    (name: 'Number of Fonts'; field_type: FT_NUMERIC_32)
  );


function ContentGetSupportedField(
  FieldIndex: Integer;
  FieldName: PAnsiChar;
  Units: PAnsiChar;
  MaxLen: Integer): Integer; dcpcall;
begin
  StrPCopy(Units, EmptyStr);

  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOMOREFIELDS);

  StrPLCopy(
    FieldName, FieldInfo[TFieldIndex(FieldIndex)].name, MaxLen);
  result := FieldInfo[TFieldIndex(FieldIndex)].field_type;
end;


function Put(
  const str: string; FieldValue: PByte; MaxLen: Integer): Integer;
begin
  if str = '' then
    exit(FT_FIELDEMPTY);

  {$IFDEF WINDOWS}
  StrPLCopy(
    PWideChar(FieldValue),
    UTF8Decode(str),
    MaxLen div SizeOf(WideChar));
  result := FT_STRINGW;
  {$ELSE}
  StrPLCopy(PAnsiChar(FieldValue), str, MaxLen);
  result := FT_STRING;
  {$ENDIF}
end;


function Put(int: longint; FieldValue: PByte): Integer;
begin
  PLongint(FieldValue)^ := int;
  result := FT_NUMERIC_32;
end;


function Put(
  constref info: TFontInfo;
  field_index: TFieldIndex;
  FieldValue: PByte;
  MaxLen: Integer): Integer;
begin
  case field_index of
    IDX_FAMILY:
      result := Put(info.family, FieldValue, MaxLen);
    IDX_STYLE:
      result := Put(info.style, FieldValue, MaxLen);
    IDX_FULL_NAME:
      result := Put(info.full_name, FieldValue, MaxLen);
    IDX_PS_NAME:
      result := Put(info.ps_name, FieldValue, MaxLen);
    IDX_VERSION:
      result := Put(info.version, FieldValue, MaxLen);
    IDX_COPYRIGHT:
      result := Put(info.copyright, FieldValue, MaxLen);
    IDX_UNIQUE_ID:
      result := Put(info.unique_id, FieldValue, MaxLen);
    IDX_TRADEMARK:
      result := Put(info.trademark, FieldValue, MaxLen);
    IDX_MANUFACTURER:
      result := Put(info.manufacturer, FieldValue, MaxLen);
    IDX_DESIGNER:
      result := Put(info.designer, FieldValue, MaxLen);
    IDX_DESCRIPTION:
      result := Put(info.description, FieldValue, MaxLen);
    IDX_VENDOR_URL:
      result := Put(info.vendor_url, FieldValue, MaxLen);
    IDX_DESIGNER_URL:
      result := Put(info.designer_url, FieldValue, MaxLen);
    IDX_LICENSE:
      result := Put(info.license, FieldValue, MaxLen);
    IDX_LICENSE_URL:
      result := Put(info.license_url, FieldValue, MaxLen);
    IDX_FORMAT:
      result := Put(info.format, FieldValue, MaxLen);
    IDX_NUM_FONTS:
      result := Put(info.num_fonts, FieldValue);
  else
    result := FT_NOSUCHFIELD;
  end;
end;


procedure Reset(out info: TFontInfo);
begin
  with info do
  begin
    family := '';
    style := '';
    full_name := '';
    ps_name := '';
    version := '';
    copyright := '';
    unique_id := '';
    trademark := '';
    manufacturer := '';
    designer := '';
    description := '';
    vendor_url := '';
    designer_url := '';
    license := '';
    license_url := '';
    format := '';
    num_fonts := 1;
  end;
end;


function ReadFontInfo(const file_name: string; var info: TFontInfo): boolean;
const
  VERSION_PREFIX = 'Version ';
var
  ext: string;
  gzipped: boolean = FALSE;
  stream: TStream;
  reader: TInfoReader;
begin
  ext := LowerCase(ExtractFileExt(file_name));

  if ext = '.gz' then
  begin
    gzipped := TRUE;
    ext := LowerCase(ExtractFileExt(
      Copy(file_name, 1, Length(file_name) - Length(ext))));
  end;

  reader := FindReader(ext);
  if reader = NIL then
    exit(FALSE);

  try
    if gzipped then
      stream := TGZFileStream.Create(file_name, gzOpenRead)
    else
      stream := TFileStream.Create(
        file_name, fmOpenRead or fmShareDenyNone);

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
      WriteLn(StdErr, 'fontinfo "', file_name, '": ', E.Message);
      {$ENDIF}

      exit(FALSE);
    end;
  end;

  if AnsiStartsText(VERSION_PREFIX, info.version) then
    info.version := Copy(
      info.version,
      Length(VERSION_PREFIX) + 1,
      Length(info.version) - Length(VERSION_PREFIX));

  result := TRUE;
end;


// Cache
var
  last_file_name: string;
  info_cache: TFontInfo;
  // info_cache_valid is TRUE if TFontInfo was loaded without errors
  info_cache_valid: boolean;


function ContentGetValue(
  FileName: PAnsiChar;
  FieldIndex,
  UnitIndex: Integer;
  FieldValue: PByte;
  MaxLen,
  Flags: Integer): Integer; dcpcall;
var
  FileName_str: string;
begin
  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOSUCHFIELD);

  FileName_str := string(FileName);

  if last_file_name <> FileName_str then
  begin
    if Flags and CONTENT_DELAYIFSLOW <> 0 then
      exit(FT_DELAYED);

    info_cache_valid := ReadFontInfo(FileName_str, info_cache);

    // Save the file name before returning a potential FT_FILEERROR so
    // that we don't query the same file again in case of the previous
    // attempt failed. It also avoids printing printing the same error
    // message several times (for each column) in DEBUG mode.
    last_file_name := FileName_str;
  end;

  if not info_cache_valid then
    exit(FT_FILEERROR);

  result := Put(
    info_cache, TFieldIndex(FieldIndex), FieldValue, MaxLen);
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

end.

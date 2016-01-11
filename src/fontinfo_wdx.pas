{
  Font info WDX plugin.

  Copyright (c) 2015, 2016 Daniel Plachotich

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

{$MODE OBJFPC}
{$H+}

library fontinfo_wdx;

{$INCLUDE calling.inc}

uses
  fontinfo_common,
  fontinfo_sfnt,
  fontinfo_ps,
  fontinfo_afm_sfd,
  fontinfo_pfm,
  fontinfo_inf,
  fontinfo_bdf,
  fontinfo_pcf,
  wdxplugin,
  classes,
  sysutils;

const
  ELLIPSIS = '…';

// Cache
var
  last_file_name: string;
  info_cache: TFontInfo;


function EnsureLength(const s: string; MaxLen: Integer): string;
begin
  if Length(s) < MaxLen then
    result := s
  else
    result := Copy(s, 1, MaxLen - Length(ELLIPSIS) + 1) + ELLIPSIS;
end;


procedure ContentGetDetectString(DetectString: PAnsiChar; MaxLen: Integer); dcpcall;
begin
  StrPLCopy(DetectString,
            '(EXT="TTF")|(EXT="TTC")|(EXT="OTF")|(EXT="OTC")|' +
            '(EXT="WOFF")|(EXT="EOT")|' +
            '(EXT="PS")|(EXT="PFA")|(EXT="PFB")|(EXT="PT3")|(EXT="T42")|' +
            '(EXT="AFM")|(EXT="PFM")|(EXT="INF")|' +
            '(EXT="BDF")|(EXT="PCF")|' +
            '(EXT="SFD")|' +
            '(EXT="GZ")',
            MaxLen);
end;


function ContentGetSupportedField(FieldIndex: Integer; FieldName: PAnsiChar;
                                  Units: PAnsiChar; MaxLen: Integer): Integer; dcpcall;
begin
  StrPCopy(Units, EmptyStr);

  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOMOREFIELDS);

  StrPLCopy(FieldName, TFieldNames[TFieldIndex(FieldIndex)], MaxLen);
  result := FT_STRING;
end;


function ContentGetValue(FileName: PAnsiChar; FieldIndex, UnitIndex: Integer;
                         FieldValue: PByte; MaxLen, Flags: Integer): Integer; dcpcall;
var
  FileName_s,
  ext: string;
  info: TFontInfo;
begin
  FileName_s := string(FileName);

  if not FileExists(FileName_s) then
    exit(FT_FILEERROR);

  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOSUCHFIELD);

  if last_file_name <> FileName_s then
    begin
      ext := LowerCase(ExtractFileExt(FileName_s));
      case ext of
        '.ttf', '.ttc', '.otf', '.otc', '.woff', '.eot':
          GetSFNTInfo(FileName_s, info);
        '.ps','.pfa','.pfb','.pt3','.t42':
          GetPSInfo(FileName_s, info);
        '.afm':
          GetAFMInfo(FileName_s, info);
        '.pfm':
          GetPFMInfo(FileName_s, info);
        '.inf':
          GetINFInfo(FileName_s, info);
        '.bdf':
          GetBDFInfo(FileName_s, info);
        '.pcf':
          GetPCFInfo(FileName_s, info, FALSE);
        '.sfd':
          GetSFDInfo(FileName_s, info);
        '.gz':
          begin
            ext := LowerCase(ExtractFileExt(
              Copy(FileName_s, 1, Length(FileName_s) - Length(ext))));
            case ext of
              '.pcf':
                GetPCFInfo(FileName_s, info, TRUE);
            end;
          end;
      end;

      info_cache := info;
      last_file_name := FileName_s;
    end;

  StrPLCopy(PAnsiChar(FieldValue),
            EnsureLength(info_cache[TFieldIndex(FieldIndex)], MaxLen),
            MaxLen);
  result := FT_STRING;
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

end.

{
  Font info WDX plugin.

  Copyright (c) 2015 Daniel Plachotich

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
  fontinfo_pfm,
  fontinfo_bdf,
  fontinfo_afm_sfd,
  wdxplugin,
  classes,
  sysutils;

const
  ELLIPSIS = '…';

// Cache.
var
  CurrentFileName: string;
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
            '(EXT="AFM")|(EXT="PFM")|' +
            '(EXT="BDF")|' +
            '(EXT="SFD")',
            MaxLen);
end;


function ContentGetSupportedField(FieldIndex: Integer; FieldName: PAnsiChar;
                                  Units: PAnsiChar; MaxLen: Integer): Integer; dcpcall;
begin
  StrPCopy(Units, EmptyStr);

  if FieldIndex > ord(High(TFieldIndex)) then
    exit(FT_NOMOREFIELDS);

  StrPLCopy(FieldName, TFieldNames[TFieldIndex(FieldIndex)], MaxLen);
  result := ft_string;
end;


function ContentGetValue(FileName: PAnsiChar; FieldIndex, UnitIndex: Integer;
                         FieldValue: PByte; MaxLen, Flags: Integer): Integer; dcpcall;
var
  FileName_s: string;
  info: TFontInfo;
begin
  FileName_s := string(FileName);

  if not FileExists(FileName_s) then
    exit(FT_FILEERROR);

  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOSUCHFIELD);

  if CurrentFileName <> FileName_s then
    begin
      case LowerCase(ExtractFileExt(FileName_s)) of
        '.ttf',
        '.ttc',
        '.otf',
        '.otc',
        '.woff',
        '.eot':
          GetSFNTInfo(FileName_s, info);
        '.ps',
        '.pfa',
        '.pfb',
        '.pt3',
        '.t42':
          GetPSInfo(FileName_s, info);
        '.pfm':
          GetPFMInfo(FileName_s, info);
        '.bdf':
          GetBDFInfo(FileName_s, info);
        '.afm',
        '.sfd':
          GetSFDorAFMInfo(FileName_s, info);
      end;

      info_cache := info;
      CurrentFileName := FileName_s;
    end;

  StrPLCopy(PAnsiChar(FieldValue),
            EnsureLength(info_cache[TFieldIndex(FieldIndex)], MaxLen),
            MaxLen);
  result := ft_string;
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

end.

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

library fi_wdx;

{$INCLUDE calling.inc}

uses
  fi_common,
  fi_sfnt,
  fi_ps,
  fi_afm_sfd,
  fi_pfm,
  fi_inf,
  fi_bdf,
  fi_pcf,
  wdxplugin,
  classes,
  zstream,
  sysutils;


// Cache
var
  last_file_name: string;
  info_cache: TFontInfo;


procedure ContentGetDetectString(DetectString: PAnsiChar; MaxLen: Integer); dcpcall;
begin
  StrPLCopy(DetectString,
            'EXT="TTF"|EXT="OTF"|EXT="TTC"|EXT="OTC"|' +
            'EXT="WOFF"|EXT="EOT"|' +
            'EXT="PS"|EXT="PFA"|EXT="PFB"|EXT="PT3"|'+
            'EXT="T11"|EXT="T42"|' +
            'EXT="AFM"|EXT="PFM"|EXT="INF"|' +
            'EXT="BDF"|EXT="PCF"|' +
            'EXT="SFD"|' +
            'EXT="GZ"',
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
  FileName_str,
  ext: string;
  gzipped: boolean = FALSE;
  default_file_mode: byte;
  stream: TStream;
  reader: procedure(stream: TStream; var info: TFontInfo);
  info: TFontInfo;
begin
  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOSUCHFIELD);

  FileName_str := string(FileName);

  if last_file_name <> FileName_str then
    begin
      if Flags and CONTENT_DELAYIFSLOW <> 0 then
        exit(FT_DELAYED);

      ext := LowerCase(ExtractFileExt(FileName_str));

      if ext = '.gz' then
        begin
          gzipped := TRUE;
          ext := LowerCase(ExtractFileExt(
            Copy(FileName_str, 1, Length(FileName_str) - Length(ext))))
        end;

      case ext of
        '.ttf', '.otf':
          reader := @GetOTFInfo;
        '.ttc', '.otc':
          reader := @GetCollectionInfo;
        '.woff':
          reader := @GetWOFFInfo;
        '.eot':
          reader := @GetEOTInfo;
        '.ps','.pfa','.pfb','.pt3', '.t11', '.t42':
          reader := @GetPSInfo;
        '.afm':
          reader := @GetAFMInfo;
        '.pfm':
          reader := @GetPFMInfo;
        '.inf':
          reader := @GetINFInfo;
        '.bdf':
          reader := @GetBDFInfo;
        '.pcf':
          reader := @GetPCFInfo;
        '.sfd':
          reader := @GetSFDInfo;
      else
        exit(FT_FILEERROR);
      end;

      try
        if gzipped then
          begin
            {
              TGZFileStream is wrapper for gzio from paszlib,
              which is uses Reset.
            }
            default_file_mode := FileMode;
            FileMode := fmOpenRead;
            stream := TGZFileStream.Create(FileName, gzopenread);
            FileMode := default_file_mode;
          end
        else
          stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);

        try
          reader(stream, info);
        finally
          stream.Free;
        end;
      except
        on EStreamError do
          exit(FT_FILEERROR);
      end;

      info_cache := info;
      last_file_name := FileName_str;
    end;

  if info_cache[TFieldIndex(FieldIndex)] = '' then
    exit(FT_FIELDEMPTY);

  {$IFDEF WINDOWS}
  StrPLCopy(
    PWideChar(FieldValue),
    UTF8Decode(info_cache[TFieldIndex(FieldIndex)]),
    MaxLen div SizeOf(WideChar));
  result := FT_STRINGW;
  {$ELSE}
  StrPLCopy(PAnsiChar(FieldValue), info_cache[TFieldIndex(FieldIndex)], MaxLen);
  result := FT_STRING;
  {$ENDIF}
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

end.

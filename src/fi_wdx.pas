{
  Font info WDX plugin.

  Copyright (c) 2015, 2016 Daniel Plakhotich

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
  fi_info_reader,
  fi_sfnt,
  fi_ps,
  fi_afm_sfd,
  fi_pfm,
  fi_inf,
  fi_bdf,
  fi_pcf,
  fi_winfnt,
  wdxplugin,
  classes,
  zstream,
  sysutils;


// Cache
var
  last_file_name: string;
  info_cache: TFontInfo;


procedure ContentGetDetectString(DetectString: PAnsiChar; MaxLen: Integer); dcpcall;
var
  s,
  ext: string;
begin
  s := 'EXT="GZ"';
  for ext in GetSupportedExtensions() do
    s:= s + '|EXT="' + UpperCase(Copy(ext, 2, Length(ext) - 1)) + '"';

  StrPLCopy(DetectString, s, MaxLen);
end;


function ContentGetSupportedField(FieldIndex: Integer; FieldName: PAnsiChar;
                                  Units: PAnsiChar; MaxLen: Integer): Integer; dcpcall;
begin
  StrPCopy(Units, EmptyStr);

  if FieldIndex > Ord(High(TFieldIndex)) then
    exit(FT_NOMOREFIELDS);

  StrPLCopy(FieldName, TFieldNames[TFieldIndex(FieldIndex)], MaxLen);

  if TFieldIndex(FieldIndex) = IDX_NUM_FONTS then
    result := FT_NUMERIC_32
  else
    result := FT_STRING;
end;


function ContentGetValue(FileName: PAnsiChar; FieldIndex, UnitIndex: Integer;
                         FieldValue: PByte; MaxLen, Flags: Integer): Integer; dcpcall;
var
  FileName_str,
  ext: string;
  gzipped: boolean = FALSE;
  last_file_mode: byte;
  stream: TStream;
  reader: TInfoReader;
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
            Copy(FileName_str, 1, Length(FileName_str) - Length(ext))));
        end;

      reader := FindReader(ext);
      if reader = NIL then
        exit(FT_FILEERROR);

      try
        if gzipped then
          begin
            {
              TGZFileStream is wrapper for gzio from paszlib, which uses
              Reset. With the default mode (fmOpenReadWrite) we will not
              be able to open files with read-only access on Unix-like
              systems, like gzipped PCFs from /usr/share/fonts/X11/misc/.

              The issue was fixed in FPC 3.1.1 (rev. 32490, bug 28917).
            }
            last_file_mode := FileMode;
            FileMode := fmOpenRead;
            stream := TGZFileStream.Create(FileName, gzOpenRead);
            FileMode := last_file_mode;
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

  if TFieldIndex(FieldIndex) = IDX_NUM_FONTS then
    begin
      PLongint(FieldValue)^ := StrToIntDef(
        info_cache[TFieldIndex(FieldIndex)], 1);
      result := FT_NUMERIC_32;
    end
  else
    begin
      {$IFDEF WINDOWS}
      StrPLCopy(
        PWideChar(FieldValue),
        UTF8Decode(info_cache[TFieldIndex(FieldIndex)]),
        MaxLen div SizeOf(WideChar));
      result := FT_STRINGW;
      {$ELSE}
      StrPLCopy(
        PAnsiChar(FieldValue), info_cache[TFieldIndex(FieldIndex)], MaxLen);
      result := FT_STRING;
      {$ENDIF}
    end;
end;


exports
  ContentGetDetectString,
  ContentGetSupportedField,
  ContentGetValue;

end.

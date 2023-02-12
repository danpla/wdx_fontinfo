unit fi_info_reader;

interface

uses
  fi_common,
  classes;


type
  TInfoReader = procedure(stream: TStream; var info: TFontInfo);
  TExtensions = array of string;


{
  Register font info reader.
  All extensions must be in lower case and contain leading periods.
}
procedure RegisterReader(
  reader: TInfoReader; const extensions: array of string);

{
  Return sorted list of all supported extensions.
  These are all extensions that were passed to RegisterReader.
}
function GetSupportedExtensions: TExtensions;

{
  Return info reader for the given extension.
  The extension must be in lower case and contain a leading period.
  If there is no reader for the extension, NIL is returned.
}
function FindReader(const extension: string): TInfoReader;


implementation

uses
  fi_utils;


type
  TReaderRec = record
    extensions: TExtensions;
    reader: TInfoReader;
  end;


var
  readers: array of TReaderRec;


function IsValidExtension(const extension: string): boolean;
var
  c: char;
begin
  if Length(extension) = 0 then
    exit(FALSE);

  if extension[1] <> '.' then
    exit(FALSE);

  for c in extension do
    if LowerCase(c) <> c then
      exit(FALSE);

  result := TRUE;
end;


procedure RegisterReader(
  reader: TInfoReader; const extensions: array of string);
var
  i, j: SizeInt;
begin
  Assert(reader <> NIL, 'Reader is NIL');
  Assert(Length(extensions) > 0, 'Extension list is empty');

  for i := 0 to High(readers) do
    if reader = readers[i].reader then
      Assert(FALSE, 'Reader is already registered');

  i := Length(readers);
  SetLength(readers, i + 1);

  SetLength(readers[i].extensions, Length(extensions));
  for j := 0 to High(extensions) do
  begin
    Assert(
      IsValidExtension(extensions[j]),
      'Invalid extension ' + extensions[j]);
    readers[i].extensions[j] := extensions[j];
  end;

  readers[i].reader := reader;
end;


function GetSupportedExtensions: TExtensions;
var
  i, j, k: SizeInt;
begin
  SetLength(result, 0);

  for i := 0 to High(readers) do
  begin
    j := Length(result);
    SetLength(result, j + Length(readers[i].extensions));

    for k := 0 to High(readers[i].extensions) do
      result[j + k] := readers[i].extensions[k];
  end;

  specialize SortArray<string>(result);
end;


function FindReader(const extension: string): TInfoReader;
var
  i, j: SizeInt;
begin
  Assert(IsValidExtension(extension), 'Invalid extension ' + extension);

  for i := 0 to High(readers) do
    for j := 0 to High(readers[i].extensions) do
      if extension = readers[i].extensions[j] then
        exit(readers[i].reader);

  result := NIL;
end;


end.

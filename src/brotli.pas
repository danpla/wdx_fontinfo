
unit brotli;

interface

uses
  sysutils;

// Returns FALSE on error.
function BrotliDecompress(
  const compressedData: TBytes;
  decompressedSize: SizeInt;
  out decompressedData: TBytes): Boolean;


implementation

{$LINKLIB brotlidec-static}
{$LINKLIB brotlicommon-static}

uses
  ctypes;


type
  // TBrotliDecoderResult is a enum in the C header.
  TBrotliDecoderResult = cint;


const
  // BrotliDecoderDecompress() returns either
  // BROTLI_DECODER_RESULT_SUCCESS or BROTLI_DECODER_RESULT_ERROR, so
  // we can't make a useful message for an exception. That's why our
  // BrotliDecompress() wrapper returns a boolean.
  BROTLI_DECODER_RESULT_SUCCESS = 1;


function BrotliDecoderDecompress(
  encodedSize: csize_t;
  const encodedBuffer: Pointer;
  decodedSize: pcsize_t;
  decodedBuffer: Pointer): TBrotliDecoderResult; cdecl; external;


function BrotliDecompress(
  const compressedData: TBytes;
  decompressedSize: SizeInt;
  out decompressedData: TBytes): Boolean;
var
  brotliDecompressedSize: csize_t;
  brotliDecoderResult: TBrotliDecoderResult;
begin
  if decompressedSize < 0 then
    exit(FALSE);

  SetLength(decompressedData, decompressedSize);

  brotliDecompressedSize := csize_t(decompressedSize);
  brotliDecoderResult := BrotliDecoderDecompress(
    Length(compressedData),
    Pointer(compressedData),
    @brotliDecompressedSize,
    Pointer(decompressedData));

  result := (brotliDecoderResult = BROTLI_DECODER_RESULT_SUCCESS)
    and (brotliDecompressedSize = csize_t(decompressedSize));
end;


end.


{$LINKLIB brotlidec-static}
{$LINKLIB brotlicommon-static}

unit brotli;

interface

type
  TBrotliDecoderResult = (
    BROTLI_DECODER_RESULT_ERROR,
    BROTLI_DECODER_RESULT_SUCCESS,
    BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT,
    BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
  );

function BrotliDecoderDecompress(
  encodedSize: SizeUInt;
  const encodedBuffer: Pointer;
  decodedSize: PSizeUint;
  decodedBuffer: Pointer): TBrotliDecoderResult; cdecl; external;

implementation

end.

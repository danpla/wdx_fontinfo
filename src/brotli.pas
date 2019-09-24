
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
  encoded_size: SizeUInt;
  const encoded_buffer: pointer;
  decoded_size: PSizeUint;
  decoded_buffer: pointer): TBrotliDecoderResult; cdecl; external;

implementation

end.

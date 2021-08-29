# wdx_fontinfo

Font info WDX plugin for [Total Commander] and [Double Commander].

Binaries for Windows, Linux, and macOS are available on the
[Releases](https://github.com/danpla/wdx_fontinfo/releases/latest)
page.

[Total Commander]: http://www.ghisler.com/
[Double Commander]: http://doublecmd.sourceforge.net/


## Supported formats

* TrueType and TrueType Collections
* OpenType and OpenType Collections
* Web Open Font Format 1 & 2 (WOFF, WOFF2)
* Embedded OpenType (EOT)
* PostScript Type 0, 1, 3, 11, etc., possibly with AFM, PFM, and INF
* Bitmap Distribution Format (BDF)
* Portable Compiled Format (PCF), possibly gzip-compressed (.pcf.gz)
* Windows’ FNT/FON
* FontForge’s Spline Font Database (SFD)


## Available fields

* Family
* Style
* Full Name
* PostScript Name
* Version
* Copyright
* Unique ID
* Trademark
* Manufacturer
* Designer
* Description
* Vendor URL
* Designer URL
* License
* License URL
* Format
    * "TT" — "plain" TrueType
    * "OT PS" — PostSript flavored OpenType
    * "OT TT" — TrueType flavored OpenType
    * "EOT" — compressed Embedded OpenType (the plugin can't
      decompress EOT)
    * "PS {type}" — PostScript Type {type}
    * "AFM {version}"
    * "PFM"
    * "INF"
    * "BDF {version}"
    * "PCF"
    * "FNT {version}" (both for FNT and FON)
    * "SFD {version}"
* Number of Fonts — number of fonts in TTC, OTC, or WOFF2. Always 1
  for other formats.


## Building

Get [FPC](https://www.freepascal.org/) version 2.6 or newer and run
`fpc src/fi_wdx.pas @compile.cfg`.

To build 64-bit version on Windows, add `-Px86_64` or invoke
`ppcrossx64` instead of `fpc`.

### Building with WOFF2 support

  * Download the latest stable source of the brotli library and
    follow its building instructions.

  * Put `libbrotlicommon-static` and `libbrotlidec-static` in a
    separate directory, for example `libs32` or `libs64`, depending on
    the target.

  * Compile in the usual way, but append `-dENABLE_WOFF2` and `-Fl`
    followed by the directory with libraries (`-Fllibs32` or
    `-Fllibs64`). For example:

        fpc src/fi_wdx.pas @compile.cfg -dENABLE_WOFF2 -Fllibs64

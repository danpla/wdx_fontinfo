# wdx_fontinfo

Font info WDX plugin for [Total Commander] and [Double Commander].

Downloads are available on the
[Releases](https://github.com/danpla/wdx_fontinfo/releases/latest)
page.

[Total Commander]: http://www.ghisler.com/
[Double Commander]: http://doublecmd.sourceforge.net/


## Supported formats

* TrueType, OpenType, and their collections
* Web Open Font Format 1 & 2 (WOFF, WOFF2)
* Embedded OpenType (EOT)
* PostScript Type 0, 1, 3, 11, etc., with AFM, PFM, and INF
* Bitmap Distribution Format (BDF)
* Portable Compiled Format (PCF)
* Windows’ FNT/FON
* FontForge’s Spline Font Database (SFD)

The plugin can read gzip-compressed BDF and PCF if the file extensions
are ".bdf.gz" and ".pcf.gz", respectively.


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
    * "TT" - "plain" TrueType
    * "OT PS" - PostSript flavored OpenType
    * "OT TT" - TrueType flavored OpenType
    * "EOT" - compressed Embedded OpenType (the plugin can't
      decompress EOT to detect its TrueType/OpenType format)
    * "PS {type}" - PostScript Type {type}
    * "AFM {version}"
    * "PFM"
    * "INF"
    * "BDF {version}"
    * "PCF"
    * "FNT {version}" (both for FNT and FON)
    * "SFD {version}"
* Variation Axes - a comma-separated list of 4-character tags
  identifying variation exes in a variable font. Common tags include:
    * `ital` - italic
    * `opsz` - optical size
    * `slnt` - slant
    * `wdht` - width
    * `wght` - weight
* Number of Fonts - number of fonts in TTC, OTC, or WOFF2. Always 1
  for other formats.


## Building

Get [FPC](https://www.freepascal.org/) version 3.1.1 or newer and run
`fpc src/fi_wdx.pas @compile.cfg`.

To build a 64-bit version of the plugin on Windows, add `-Px86_64`.

### Building with WOFF2 support

*   Download the latest stable source of the brotli library and
    follow its building instructions.

*   Put `libbrotlicommon-static` and `libbrotlidec-static` libraries
    in a separate directory, for example `libs32` or `libs64`,
    depending on the target.

*   Add `-dENABLE_WOFF2` and `-Fl` followed by the directory with
    the libraries (`-Fllibs32` or `-Fllibs64`) to the build command.
    For example:

        fpc src/fi_wdx.pas @compile.cfg -dENABLE_WOFF2 -Fllibs64

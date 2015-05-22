# wdx_fontinfo

Font info WDX plugin for [Total][Total Commander]
and [Double][Double Commander] Commanders.


## Currently supported formats

  * TrueType and TrueType Collections
  * OpenType and OpenType Collections
  * Web Open Font Format (WOFF)
  * Embedded OpenType (EOT)

PostScript fonts (and probably some other formats) will be supported in
future versions.


## Available fields

  * Name
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
  * Format — short string describing the format "under the hood" of the font
   file. For example, it can be used to determine what is actually
   your .ttf file: "plain" TrueType or TrueType flavored OpenType.
   Can be one of following:
    * "TT" — "plain" TrueType
    * "OT PS" — PostSript flavored OpenType
    * "OT TT" — TrueType flavored OpenType
    * "EOT" — Embedded OpenType (because currently plugin can't decompress EOT)
  * Number of Fonts — number of fonts in TTC or OTC. Always 1 for all
    other formats.


## Compilation

Ensure you have latest version of [FPC](http://www.freepascal.org/)
and then run `compile` script.


## Links

  * [OpenType Specification](https://www.microsoft.com/typography/otspec/)
  * [WOFF Specification](http://www.w3.org/TR/WOFF/)
  * [EOT Specification](http://www.w3.org/Submission/EOT/)
  * [Apple TrueType Reference Manual](https://developer.apple.com/fonts/TrueType-Reference-Manual/)


[Total Commander]: http://www.ghisler.com/
[Double Commander]: http://doublecmd.sourceforge.net/

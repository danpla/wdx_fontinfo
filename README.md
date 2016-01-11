# wdx_fontinfo

Font info WDX plugin for [Total][Total Commander]
and [Double][Double Commander] Commanders.


## Supported formats

  * TrueType and TrueType Collections
  * OpenType and OpenType Collections
  * Web Open Font Format (WOFF)
  * Embedded OpenType (EOT)
  * PostScript Type 0, 1, 3, 11, 42 etc., possibly with AFM, PFM, and INF
  * Bitmap Distribution Format (BDF)
  * X11 Portable Compiled Format (PCF), possibly GZip compressed (.pcf.gz)
  * FontForge’s Spline Font Database (SFD)


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
  * Format. Can be one of following:
    * "TT" — "plain" TrueType
    * "OT PS" — PostSript flavored OpenType
    * "OT TT" — TrueType flavored OpenType
    * "EOT" — compressed Embedded OpenType (currently, the plugin can't
      decompress EOT)
    * "PS {type}" — PostScript Type {type}
    * "AFM {version}"
    * "PFM" — Printer Font Metrics
    * "INF"
    * "BDF {version}""
    * "PCF"
    * "SFD {version}"
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
  * [PostScript fonts (Wikipedia)](http://en.wikipedia.org/wiki/PostScript_fonts)
  * [PostScript Specifications](http://partners.adobe.com/public/developer/ps/index_specs.html)
  * [AFM Specification (PDF)](https://partners.adobe.com/public/developer/en/font/5004.AFM_Spec.pdf)
  * [PFM Specification (PDF)](https://partners.adobe.com/public/developer/en/font/5178.PFM.pdf)
  * [BDF Specification (PDF)](https://partners.adobe.com/public/developer/en/font/5005.BDF_Spec.pdf)
  * [PCF Specification](http://fontforge.github.io/pcf-format.html)
  * [FontForge’s SDF Specification](http://fontforge.github.io/en-US/documentation/developers/sfdformat/)


[Total Commander]: http://www.ghisler.com/
[Double Commander]: http://doublecmd.sourceforge.net/

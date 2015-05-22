{$MODE OBJFPC}
{$H+}

unit fontinfo_common;

interface

type
  TFieldIndex = (
    IDX_FAMILY,
    IDX_STYLE,
    IDX_FULL_NAME,
    IDX_PS_NAME,
    IDX_VERSION,
    IDX_COPYRIGHT,
    IDX_UNIQUE_ID,
    IDX_TRADEMARK,
    IDX_MANUFACTURER,
    IDX_DESIGNER,
    IDX_DESCRIPTION,
    IDX_VENDOR_URL,
    IDX_DESIGNER_URL,
    IDX_LICENSE,
    IDX_LICENSE_URL,
    IDX_FORMAT,
    IDX_NFONTS
  );

  TFontInfo = array [TFieldIndex] of string;

const
  TFieldNames: array [TFieldIndex] of string = (
    'Family',
    'Style',
    'Full Name',
    'PostScript Name',
    'Version',
    'Copyright',
    'Unique ID',
    'Trademark',
    'Manufacturer',
    'Designer',
    'Description',
    'Vendor URL',
    'Designer URL',
    'License',
    'License URL',
    'Format',
    'Number of Fonts'
    );

implementation

end.

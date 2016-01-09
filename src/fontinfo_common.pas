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
    IDX_NUM_FONTS
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


function GetWeightName(const weight: word): string;

implementation


function GetWeightName(const weight: word): string;
begin
  case weight of
    100: result := 'Thin';
    200: result := 'ExtraLight';
    300: result := 'Light';
    500: result := 'Medium';
    600: result := 'SemiBold';
    700: result := 'Bold';
    800: result := 'ExtraBold';
    900: result := 'Black';
    950: result := 'ExtraBlack';
  else
    result := 'Regular';
  end;
end;

end.

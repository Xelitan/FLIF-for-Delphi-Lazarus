# FLIF-for-Delphi-Lazarus

Read and write FLIFC images in Delphi, Free Pascal and Lazarus

Requires .DLL files (included). For Linux and MacOS you need to download binaries from libflif project.

## Usage examples

### Using TImage / TPicture

    Image1.Picture.LoadFromFile('test.flif');

### Using classes directly

    var f: TFlifImage;
    begin
      f := TFlifImage.Create;
      f.Assign(Bitmap...);
      f.SAveToFile('test.flif');
      f.free;
    end;

# Tested under 64 bit/32 bit Lazarus and 64 bit Delphi 12

Should work under other 64 bit Delphis.
Needs tests under 32 bit Delphi.

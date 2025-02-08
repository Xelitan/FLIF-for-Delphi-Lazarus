unit FlifImage;

{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}

////////////////////////////////////////////////////////////////////////////////
//                                                                            //
// Description:	Reader for FLIF images                                        //
// Version:	0.1                                                           //
// Date:	08-FEB-2025                                                   //
// License:     MIT                                                           //
// Target:	Win64, Free Pascal, Delphi                                    //
// Copyright:	(c) 2025 Xelitan.com.                                         //
//		All rights reserved.                                          //
//                                                                            //
////////////////////////////////////////////////////////////////////////////////

interface

uses Classes, Graphics, SysUtils, Math, Types, Dialogs;

const LIBFLIF = 'libflif.dll';

type
  PFLIF_DECODER = Pointer;
  PFLIF_ENCODER = Pointer;
  PFLIF_IMAGE = Pointer;

  function flif_create_decoder: PFLIF_DECODER; cdecl; external LIBFLIF;
  procedure flif_destroy_decoder(decoder: PFLIF_DECODER); cdecl; external LIBFLIF;
  function flif_decoder_decode_file(decoder: PFLIF_DECODER; const filename: PAnsiChar): Integer; cdecl; external LIBFLIF;
  function flif_decoder_decode_memory(decoder: PFLIF_DECODER; buffer: PByte; buffer_size: Cardinal): Integer; cdecl; external LIBFLIF;
  function flif_decoder_get_image(decoder: PFLIF_DECODER; index: Cardinal): PFLIF_IMAGE; cdecl; external LIBFLIF;
  function flif_image_get_width(image: PFLIF_IMAGE): UInt32; cdecl; external LIBFLIF;
  function flif_image_get_height(image: PFLIF_IMAGE): UInt32; cdecl; external LIBFLIF;
  procedure flif_image_read_row_RGBA8(image: PFLIF_IMAGE; row: UInt32; buffer: Pointer; buffer_size_bytes: Cardinal); cdecl; external LIBFLIF;
  function flif_create_encoder: PFLIF_ENCODER; cdecl; external LIBFLIF;
  procedure flif_destroy_encoder(encoder: PFLIF_ENCODER); cdecl; external LIBFLIF;
  procedure flif_encoder_encode_file(encoder: PFLIF_ENCODER; const filename: PAnsiChar); cdecl; external LIBFLIF;
  function flif_encoder_encode_memory(encoder: PFLIF_ENCODER; buffer: Pointer; out buffer_size_bytes: Cardinal): Integer; cdecl; external LIBFLIF;
  procedure flif_encoder_add_image(encoder: PFLIF_ENCODER; image: PFLIF_IMAGE); cdecl; external LIBFLIF;
  function flif_create_image(width, height: UInt32): PFLIF_IMAGE; cdecl; external LIBFLIF;
  procedure flif_destroy_image(image: PFLIF_IMAGE); cdecl; external LIBFLIF;
  procedure flif_image_write_row_RGBA8(image: PFLIF_IMAGE; row: UInt32; const buffer: Pointer; buffer_size_bytes: NativeUInt); cdecl; external LIBFLIF;

  //set amount of quality loss, 0 for no loss, 100 for maximum loss, negative values indicate adaptive lossy (second image should be the saliency map)
  procedure flif_encoder_set_lossy(encoder: PFLIF_ENCODER; loss: Integer); cdecl; external LIBFLIF;

  { TFlifImage }
type
  TFlifImage = class(TGraphic)
  private
    FBmp: TBitmap;
    FCompression: Integer;
    procedure DecodeFromStream(Str: TStream);
    procedure EncodeToStream(Str: TStream);
  protected
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;
  //    function GetEmpty: Boolean; virtual; abstract;
    function GetHeight: Integer; override;
    function GetTransparent: Boolean; override;
    function GetWidth: Integer; override;
    procedure SetHeight(Value: Integer); override;
    procedure SetTransparent(Value: Boolean); override;
    procedure SetWidth(Value: Integer);override;
  public
    procedure SetLossyCompression(Value: Cardinal);
    procedure SetLosslessCompression;
    procedure Assign(Source: TPersistent); override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure SaveToStream(Stream: TStream); override;
    constructor Create; override;
    destructor Destroy; override;
  end;

implementation

{ TFlifImage }

procedure TFlifImage.DecodeFromStream(Str: TStream);
var Decoder: PFLIF_DECODER;
    Image: PFLIF_IMAGE;
    AWidth, AHeight: Integer;
    Data: array of Byte;
    P: PByteArray;
    x,y: Integer;
    Mem: array of Byte;
begin
  Decoder := flif_create_decoder;

  if not Assigned(Decoder) then
    raise Exception.Create('Failed to create FLIF decoder');

  try
    SetLength(Mem, Str.Size);
    Str.Read(Mem[0], Str.Size);
    flif_decoder_decode_memory(Decoder, @Mem[0], Str.Size);

    Image := flif_decoder_get_image(Decoder, 0);
    if not Assigned(Image) then
      raise Exception.Create('Failed to get FLIF image');

    AWidth := flif_image_get_width(Image);
    AHeight := flif_image_get_height(Image);

    if (AWidth = 0) or (AHeight = 0) then
      raise Exception.Create('Invalid FLIF image dimensions');

    FBmp.SetSize(AWidth, AHeight);
    SetLength(Data, AWidth * 4);

    for y:=0 to AHeight-1 do begin
      P := FBmp.Scanline[y];

      flif_image_read_row_RGBA8(Image, y, @Data[0], AWidth * 4);

      for x:=0 to AWidth-1 do begin
        P[4*x  ] := Data[4*x+2]; //B
        P[4*x+1] := Data[4*x+1]; //G
        P[4*x+2] := Data[4*x ];  //R
        P[4*x+3] := Data[4*x+3]; //A
        end;
      end;
  finally
    flif_destroy_decoder(Decoder);
  end;
end;

procedure TFlifImage.EncodeToStream(Str: TStream);
var Encoder: PFLIF_ENCODER;
    Image: PFLIF_IMAGE;
    AWidth, AHeight: Integer;
    Data: array of Byte;
    x,y: Integer;
    P: PByteArray;
    OutData: array of Byte;
    OutSize: Cardinal;
begin
  AWidth := FBmp.Width;
  AHeight := FBmp.Height;

  Encoder := flif_create_encoder;
  if not Assigned(Encoder) then Exit;

  try
    Image := flif_create_image(AWidth, AHeight);
    if not Assigned(Image) then Exit;

    try
      SetLength(Data, AWidth * 4);

      for y:=0 to AHeight-1 do begin
        P := Fbmp.ScanLine[y];

        for x:=0 to AWidth-1 do begin
          Data[4*x+2] := P[4*x  ]; //B
          Data[4*x+1] := P[4*x+1]; //G
          Data[4*x  ] := P[4*x+2]; //R
          Data[4*x+3] := P[4*x+3]; //A
        end;

        flif_image_write_row_RGBA8(Image, y, @Data[0], AWidth * 4);
      end;

      flif_encoder_add_image(Encoder, Image);
      flif_encoder_set_lossy(Encoder, FCompression);
      flif_encoder_encode_memory(Encoder, @OutData, OutSize);
      Str.Write(OutData[0], OutSize);
    finally
      flif_destroy_image(Image);
    end;
  finally
    flif_destroy_encoder(Encoder);
  end;
end;

procedure TFlifImage.Draw(ACanvas: TCanvas; const Rect: TRect);
begin
  ACanvas.StretchDraw(Rect, FBmp);
end;

function TFlifImage.GetHeight: Integer;
begin
  Result := FBmp.Height;
end;

function TFlifImage.GetTransparent: Boolean;
begin
  Result := False;
end;

function TFlifImage.GetWidth: Integer;
begin
  Result := FBmp.Width;
end;

procedure TFlifImage.SetHeight(Value: Integer);
begin
  FBmp.Height := Value;
end;

procedure TFlifImage.SetTransparent(Value: Boolean);
begin
  //
end;

procedure TFlifImage.SetWidth(Value: Integer);
begin
  FBmp.Width := Value;
end;

procedure TFlifImage.SetLossyCompression(Value: Cardinal);
begin
  FCompression := Value;
end;

procedure TFlifImage.SetLosslessCompression;
begin
  FCompression := 0;
end;

procedure TFlifImage.Assign(Source: TPersistent);
var Src: TGraphic;
begin
  if source is tgraphic then begin
    Src := Source as TGraphic;
    FBmp.SetSize(Src.Width, Src.Height);
    FBmp.Canvas.Draw(0,0, Src);
  end;
end;

procedure TFlifImage.LoadFromStream(Stream: TStream);
begin
  DecodeFromStream(Stream);
end;

procedure TFlifImage.SaveToStream(Stream: TStream);
begin
  EncodeToStream(Stream);
end;

constructor TFlifImage.Create;
begin
  inherited Create;

  FBmp := TBitmap.Create;
  FBmp.PixelFormat := pf32bit;
  FBmp.SetSize(1,1);
  FCompression := 0;
end;

destructor TFlifImage.Destroy;
begin
  FBmp.Free;
  inherited Destroy;
end;

initialization
  TPicture.RegisterFileFormat('Flif','Flif Image', TFlifImage);

finalization
  TPicture.UnregisterGraphicClass(TFlifImage);

end.

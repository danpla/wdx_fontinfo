unit line_reader;

interface

uses
  classes;


type
  TLineReader = class
  private
    FStream: TStream;
    FBuf: string;
    FBufFill,
    FBufPos: SizeInt;
  public
    constructor Create(Stream: TStream);
    function ReadLine(out s: string): boolean;
  end;


implementation

uses
  sysutils;


constructor TLineReader.Create(Stream: TStream);
begin
  inherited Create;

  if Stream = NIL then
    raise EArgumentException.Create('Stream is NIL');
  FStream := Stream;

  SetLength(FBuf, 1024);
  FBufFill := 0;
  FBufPos := 1;
end;


function TLineReader.ReadLine(out s: string): boolean;
const
  CR = #13;
  LF = #10;
var
  WasCr: boolean;
  i,
  PartEnd: SizeInt;
begin
  s := '';
  WasCr := (FBufPos > 1) and (FBuf[FBufPos - 1] = CR);

  while TRUE do
  begin
    Assert(FBufPos <= FBufFill + 1);
    if FBufPos = FBufFill + 1 then
    begin
      FBufFill := FStream.read(FBuf[1], Length(FBuf));
      FBufPos := 1;

      if FBufFill = 0 then
        break;
    end;

    if WasCr then
    begin
      WasCr := FALSE;
      if FBuf[FBufPos] = LF then
      begin
        inc(FBufPos);
        continue;
      end;
    end;

    PartEnd := FBufFill + 1;
    for i := FBufPos to FBufFill do
      if (FBuf[i] = CR) or (FBuf[i] = LF) then
      begin
        PartEnd := i;
        break;
      end;

    s := s + Copy(FBuf, FBufPos, PartEnd - FBufPos);
    FBufPos := PartEnd;

    if FBufPos < FBufFill + 1 then
    begin
      inc(FBufPos);
      break;
    end;
  end;

  result := (s <> '') or (FBufFill > 0);
end;


end.

{$MODE OBJFPC}
{$H+}

unit line_reader;

interface

uses
  classes,
  sysutils;

type
  TLineReader = class
  private
    FStream: TStream;
    FBuffer: string;
    FBufferFill,
    FBufferPos: SizeInt;
    FHitEof,
    FWasCr: boolean;

    procedure DoReadLine(var s: string);
  public
    constructor Create(Stream: TStream);
    function ReadLine(out s: string): boolean;
  end;


implementation


const
  BUFFER_SIZE = 1024;
  CR = #13;
  LF = #10;


procedure TLineReader.DoReadLine(var s: string);
var
  i,
  BreakPos: SizeInt;
  c: char;
begin
  Assert(not FHitEof);
  Assert(s = '');

  while (TRUE) do
    begin
      if FBufferPos > FBufferFill then
        begin
          FBufferFill := FStream.read(FBuffer[1], BUFFER_SIZE);
          if FBufferFill = 0 then
            begin
              FHitEof := TRUE;
              break;
            end;

          FBufferPos := 0;
        end;

      BreakPos := 0;
      for i := FBufferPos to FBufferFill do
        if FBuffer[i] in [LF, CR] then
          begin
            BreakPos := i;
            break;
          end;

      if BreakPos = 0 then
        begin
          FWasCr := FALSE;

          s := s + Copy(FBuffer, FBufferPos, FBufferFill - (FBufferPos - 1));
          FBufferPos := FBufferFill + 1;
        end
      else
        begin
          c := FBuffer[BreakPos];
          if (FWasCr and (c = LF)
              and ((BreakPos = 0) or (FBuffer[BreakPos - 1] = CR))) then
            begin
              // Ignore LF of CRLF sequence.
              FWasCr := FALSE;
              Assert(BreakPos = FBufferPos);
              inc(FBufferPos);
              continue;
            end;

          FWasCr := c = CR;

          s := s + Copy(FBuffer, FBufferPos, BreakPos - (FBufferPos - 1));
          FBufferPos := BreakPos + 1;
          break;
        end;
    end;
end;


constructor TLineReader.Create(Stream: TStream);
begin
  inherited Create;

  if Stream = NIL then
    raise EArgumentException.Create('Stream is NIL');
  FStream := Stream;

  SetLength(FBuffer, BUFFER_SIZE);
end;


function TLineReader.ReadLine(out s: string): boolean;
begin
  s := '';
  if FHitEof then
    exit(FALSE);

  DoReadLine(s);

  result := (s <> '') or not FHitEof;
end;


end.

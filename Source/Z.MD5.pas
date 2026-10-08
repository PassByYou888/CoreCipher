{ ******************************************************************************
  * Z.MD5 – Fast MD5 Message‑Digest Implementation
  *
  * This unit provides a high‑performance MD5 hash function, optimized for
  * Windows on both Delphi and Free Pascal using hand‑written assembly
  * (32‑bit and 64‑bit). On other platforms (Linux, macOS, FreeBSD, ARM,
  * AArch64, LoongArch, etc.) and non‑Windows builds, it falls back to a
  * pure Pascal implementation from the Z.UnicodeMixedLib unit.
  *
  * The MD5 algorithm produces a 128‑bit (16‑byte) hash, commonly represented
  * as a 32‑character hexadecimal string. This unit returns the digest as a
  * TMD5 record (an array of 16 bytes).
  *
  * The assembly versions are based on the work of Peter Sawatzki (32‑bit) and
  * Maxim Masiutin (64‑bit), and provide a significant speed boost over pure
  * Pascal on supported platforms.
  *
  * ===========================================================================
  * Platform support matrix (v2)
  * ===========================================================================
  *   Windows  x86  | Delphi ✓  FPC ✓  | Assembly (register convention)
  *   Windows  x64  | Delphi ✓  FPC ✓  | Assembly (Win64 convention)
  *   Linux    x86  | Delphi N/A FPC ✓ | Pure Pascal (umlMD5)
  *   Linux    x64  | Delphi N/A FPC ✓ | Pure Pascal (umlMD5)
  *   macOS    x64  | Delphi N/A FPC ✓ | Pure Pascal (umlMD5)
  *   macOS    arm64| Delphi N/A FPC ✓ | Pure Pascal (umlMD5)
  *   FreeBSD  x86/x64              FPC ✓ | Pure Pascal (umlMD5)
  *   Android  arm/arm64/x86/x64    FPC ✓ | Pure Pascal (umlMD5)
  *   LoongArch                     FPC ✓ | Pure Pascal (umlMD5)
  *
  * ===========================================================================
  * Symbol naming notes (Windows x86)
  * ===========================================================================
  *   The bundled Z.MD5_32.obj exports the symbol "MD5_Transform" WITHOUT
  *   a leading underscore. Delphi's `external` declaration accepts this
  *   directly. FPC, however, decorates external symbols with a leading
  *   underscore on Windows x86 by default, so we must use
  *   `external name 'MD5_Transform'` to bypass the decoration.
  *
  *   On Windows x64, neither Delphi nor FPC decorate symbols, so the
  *   plain `external` declaration works for both compilers.
  * ===========================================================================
  *
  * @Example (computing MD5 of a string):
  *   var
  *     s: RawByteString;
  *     digest: TMD5;
  *   begin
  *     s := 'Hello, world!';
  *     digest := FastMD5(@s[1], Length(s));
  *   end;
  *
  * @Example (computing MD5 of a file stream):
  *   var
  *     fs: TFileStream;
  *     digest: TMD5;
  *   begin
  *     fs := TFileStream.Create('myfile.dat', fmOpenRead);
  *     try
  *       digest := FastMD5(fs, 0, fs.Size);
  *     finally
  *       fs.Free;
  *     end;
  *   end;
  ****************************************************************************** }
unit Z.MD5;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses Z.Core, Z.UnicodeMixedLib;

{
  * MD5_Transform – internal low‑level function that processes a single 64‑byte
  * chunk of data. Implemented in assembly (Windows / Delphi / FPC).
  * Do not call directly; use FastMD5 instead.
}
{$IF Defined(MSWINDOWS) and (Defined(Delphi) or Defined(FPC))}
  {$IF Defined(WIN32)}
  procedure MD5_Transform(var Accu; const Buf); register;
  {$ELSEIF Defined(WIN64)}
  procedure MD5_Transform(var Accu; const Buf);
  {$ENDIF}
{$ENDIF Defined(MSWINDOWS) and (Defined(Delphi) or Defined(FPC))}

{
  * FastMD5 – computes the MD5 digest of a memory buffer.
  * @Param buffPtr: pointer to the first byte of the buffer (PByte).
  * @Param bufSiz: size of the buffer in bytes.
  * @Returns: a TMD5 record containing the 16‑byte digest.
}
function FastMD5(const buffPtr: PByte; bufSiz: nativeUInt): TMD5; overload;

{
  * FastMD5 – computes the MD5 digest of a portion of a stream.
  * @Param stream:   a TCore_Stream (or descendant) to read from.
  * @Param StartPos: starting position (byte offset) in the stream; if greater
  *                  than EndPos, the two values are swapped automatically.
  * @Param EndPos:   ending position (exclusive) in the stream; the hash is
  *                  computed over the range [StartPos, EndPos). Clamped to
  *                  the stream size.
  * @Returns: a TMD5 record containing the 16‑byte digest for the specified range.
}
function FastMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5; overload;

implementation

{$IF Defined(MSWINDOWS) and (Defined(Delphi) or Defined(FPC))}

uses Z.MemoryStream;

{ *************** Assembly‑linked MD5 core (Windows only) *************** }
(*
  fastMD5 algorithm by Maxim Masiutin
  https://github.com/maximmasiutin/MD5_Transform-x64

  Delphi imp by 600585@qq.com
  https://github.com/PassByYou888/FastMD5

  For 32‑bit Windows, the external object file Z.MD5_32.obj contains the
  386‑optimized MD5_Transform routine by Peter Sawatzki.
  For 64‑bit Windows, Z.MD5_64.obj contains the x64 version by Maxim Masiutin.

  Both object files are MS COFF format (produced by ml.exe / ml64.exe) and
  export the symbol "MD5_Transform" without any decoration.
*)

{$IF Defined(WIN32)}

  {$L Z.MD5_32.obj}

  {$IF Defined(FPC)}
    {
      FPC on Windows x86 automatically decorates external symbols with a
      leading underscore. Since the COFF object exports "MD5_Transform"
      (no underscore), we must use `external name` to bypass decoration.
    }
    procedure MD5_Transform(var Accu; const Buf); register;
      external name 'MD5_Transform';
  {$ELSE}
    {
      Delphi on Windows x86 uses the register calling convention without
      decorating the symbol name, so the plain `external` declaration works.
    }
    procedure MD5_Transform(var Accu; const Buf); register; external;
  {$ENDIF}

{$ELSEIF Defined(WIN64)}

  {$L Z.MD5_64.obj}

  {
    On Windows x64, neither Delphi nor FPC decorate external symbols,
    so the plain `external` declaration works for both compilers.
  }
  procedure MD5_Transform(var Accu; const Buf); external;

{$ENDIF}

{
  * FastMD5 – buffer version (Windows, assembly accelerated).
  *
  * The algorithm follows the standard MD5 padding and processing:
  *   - Initialize the four 32‑bit state variables with the MD5 constants.
  *   - Process the input in 64‑byte chunks using MD5_Transform.
  *   - After all full blocks, pad the remaining data with a single '1' bit,
  *     then zeros, then the 64‑bit length in bits (low word first).
  *   - Process the final padded block(s) if needed.
}
function FastMD5(const buffPtr: PByte; bufSiz: nativeUInt): TMD5;
var
  Digest: TMD5;
  Lo, Hi: Cardinal;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuff: array [0 .. 63] of Byte;
begin
  // Initialize MD5 state (magic constants)
  PCardinal(@Digest[0])^ := $67452301;
  PCardinal(@Digest[4])^ := $EFCDAB89;
  PCardinal(@Digest[8])^ := $98BADCFE;
  PCardinal(@Digest[12])^ := $10325476;

  // Compute length in bits: low 32 bits, high 32 bits (bits shifted by 29)
  Lo := bufSiz shl 3;
  Hi := bufSiz shr 29;

  p := buffPtr;

  // Process full 64‑byte chunks
  while bufSiz >= $40 do
    begin
      MD5_Transform(Digest, p^);
      inc(p, $40);
      dec(bufSiz, $40);
    end;

  // Copy any remaining bytes into the chunk buffer
  if bufSiz > 0 then
      CopyPtr(p, @ChunkBuff[0], bufSiz);

  // Copy the current accumulator to Result (will be finalized)
  Result := PMD5(@Digest[0])^;

  // Padding: append a single '1' bit (0x80) after the data
  ChunkBuff[bufSiz] := $80;
  ChunkIndex := bufSiz + 1;

  // If the padding exceeds the 56‑byte mark (0x38), we need to process this
  // chunk and create a new one for the length.
  if ChunkIndex > $38 then
    begin
      if ChunkIndex < $40 then
          FillPtrByte(@ChunkBuff[ChunkIndex], $40 - ChunkIndex, 0);
      MD5_Transform(Result, ChunkBuff);
      ChunkIndex := 0;
    end;

  // Fill the rest of the buffer (up to position 0x38) with zeros
  FillPtrByte(@ChunkBuff[ChunkIndex], $38 - ChunkIndex, 0);

  // Append the 64‑bit bit length (little‑endian)
  PCardinal(@ChunkBuff[$38])^ := Lo;
  PCardinal(@ChunkBuff[$3C])^ := Hi;

  // Final transformation
  MD5_Transform(Result, ChunkBuff);
end;

{
  * FastMD5 – stream version (Windows, assembly accelerated).
  *
  * This version reads the stream in chunks (default chunk size = 64 * 0xFFFF
  * bytes) to avoid allocating a huge buffer. It uses a temporary block buffer
  * (DeltaBuf) for reading. If the stream is a memory‑based stream, and the
  * define OptimizationMemoryStreamMD5 is active, it reads directly from
  * memory.
  *
  * The hash computation is otherwise identical to the buffer version.
}
function FastMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5;
const
  deltaSize: Cardinal = $40 * $FFFF; // 64 * 65535 = 4,194,240 bytes per read

var
  Digest: TMD5;
  Lo, Hi: Cardinal;
  DeltaBuf: Pointer;
  bufSiz: Int64;
  Rest: Cardinal;
  p: PByte;
  ChunkIndex: Byte;
  ChunkBuff: array [0 .. 63] of Byte;
begin
  // Ensure StartPos <= EndPos, swap if needed
  if StartPos > EndPos then
      TSwap<Int64>.Do_(StartPos, EndPos);

  // Clamp to valid stream range
  StartPos := umlClamp(StartPos, 0, stream.Size);
  EndPos := umlClamp(EndPos, 0, stream.Size);

  // If the range is empty, return hash of empty input
  if EndPos - StartPos <= 0 then
    begin
      Result := FastMD5(nil, 0);
      exit;
    end;

  // Optimization for memory streams: direct pointer access avoids reading
{$IFDEF OptimizationMemoryStreamMD5}
  if stream is TCore_MemoryStream then
    begin
      Result := FastMD5(Pointer(nativeUInt(TCore_MemoryStream(stream).Memory) + StartPos), EndPos - StartPos);
      exit;
    end;
  if stream is TMS64 then
    begin
      Result := FastMD5(TMS64(stream).PositionAsPtr(StartPos), EndPos - StartPos);
      exit;
    end;
{$ENDIF}

  // Initialize MD5 state
  PCardinal(@Digest[0])^ := $67452301;
  PCardinal(@Digest[4])^ := $EFCDAB89;
  PCardinal(@Digest[8])^ := $98BADCFE;
  PCardinal(@Digest[12])^ := $10325476;

  bufSiz := EndPos - StartPos;
  Rest := 0;
  Lo := bufSiz shl 3;
  Hi := bufSiz shr 29;

  // Allocate a buffer for reading chunks from the stream
  DeltaBuf := GetMemory(deltaSize);
  stream.Position := StartPos;

  // If the total size is less than one block, just read it directly
  if bufSiz < $40 then
    begin
      stream.read(DeltaBuf^, bufSiz);
      p := DeltaBuf;
    end
  else
    // Otherwise, process in blocks: fill DeltaBuf as needed
    while bufSiz >= $40 do
      begin
        if Rest = 0 then
          begin
            // Determine how much to read next: either deltaSize or remaining
            if bufSiz >= deltaSize then
                Rest := deltaSize
            else
                Rest := bufSiz;
            stream.ReadBuffer(DeltaBuf^, Rest);
            p := DeltaBuf;
          end;

        // Process one 64‑byte block
        MD5_Transform(Digest, p^);
        inc(p, $40);
        dec(bufSiz, $40);
        dec(Rest, $40);
      end;

  // Copy any remaining bytes into the chunk buffer
  if bufSiz > 0 then
      CopyPtr(p, @ChunkBuff[0], bufSiz);

  FreeMemory(DeltaBuf);

  // Finalize hash (same as buffer version)
  Result := PMD5(@Digest[0])^;
  ChunkBuff[bufSiz] := $80;
  ChunkIndex := bufSiz + 1;
  if ChunkIndex > $38 then
    begin
      if ChunkIndex < $40 then
          FillPtrByte(@ChunkBuff[ChunkIndex], $40 - ChunkIndex, 0);
      MD5_Transform(Result, ChunkBuff);
      ChunkIndex := 0;
    end;
  FillPtrByte(@ChunkBuff[ChunkIndex], $38 - ChunkIndex, 0);
  PCardinal(@ChunkBuff[$38])^ := Lo;
  PCardinal(@ChunkBuff[$3C])^ := Hi;
  MD5_Transform(Result, ChunkBuff);
end;

{$ELSE} // Not Windows, or not (Delphi or FPC): pure Pascal fallback

{
  * FastMD5 – buffer version (non‑Windows platforms: Linux, macOS, BSD,
  * Android, and non‑x86/x64 architectures: ARM, AArch64, LoongArch, …).
  * Uses the pure Pascal MD5 implementation from Z.UnicodeMixedLib.umlMD5.
}
function FastMD5(const buffPtr: PByte; bufSiz: nativeUInt): TMD5;
begin
  Result := umlMD5(buffPtr, bufSiz);
end;

{
  * FastMD5 – stream version (non‑Windows platforms).
  * Uses the pure Pascal stream MD5 from Z.UnicodeMixedLib.umlStreamMD5.
}
function FastMD5(stream: TCore_Stream; StartPos, EndPos: Int64): TMD5;
begin
  Result := umlStreamMD5(stream, StartPos, EndPos);
end;

{$ENDIF Defined(MSWINDOWS) and (Defined(Delphi) or Defined(FPC))}

end.
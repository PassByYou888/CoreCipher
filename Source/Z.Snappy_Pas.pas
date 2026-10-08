{ ******************************************************************************
  * Z.Snappy_Pas – Snappy Compression / Decompression for Pascal
  *
  * This unit provides a pure Pascal implementation of Google's Snappy
  * compression algorithm. It is designed for Delphi and Free Pascal,
  * offering fast compression with moderate ratios. The API is simple:
  * compress a byte buffer, then later decompress it back to the original.
  *
  * The implementation uses a hash table (64 KB) to find repeated sequences
  * and emits literals and copy commands according to the Snappy format.
  * It supports uncompressed sizes up to 4 GB (32‑bit Cardinal) and uses
  * 64‑bit variable‑length integers (varint) for the length header.
  *
  * @Example (Compress):
  *   var
  *     src, dst: TBytes;
  *     outSize: Int64;
  *     ok: Boolean;
  *   begin
  *     src := TEncoding.UTF8.GetBytes('Hello, world!');
  *     outSize := SnappyMaxCompressedLength64(Length(src)); // get max needed
  *     SetLength(dst, outSize);
  *     ok := SnappyCompress(@src[0], Length(src), @dst[0], outSize);
  *     if ok then SetLength(dst, outSize); // trim to actual size
  *   end;
  *
  * @Example (Decompress):
  *   var
  *     src, dst: TBytes;
  *     outSize: Int64;
  *     ok: Boolean;
  *   begin
  *     // src contains the compressed data
  *     outSize := 1024; // or any large enough buffer; the function will fail if too small
  *     SetLength(dst, outSize);
  *     ok := SnappyDecompress(@src[0], Length(src), @dst[0], outSize);
  *     if ok then SetLength(dst, outSize); // trim to actual size
  *   end;
  ****************************************************************************** }
unit Z.Snappy_Pas;

{$UNDEF FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

{
  * SnappyMaxCompressedLength64 – calculates the maximum possible size of the
  * compressed output for a given input length. This is guaranteed to be large
  * enough to hold the compressed data; the actual compressed size may be smaller.
  * @Param srcLen: length of the uncompressed input in bytes (32‑bit, up to 4 GB).
  * @Returns: the maximum compressed size in bytes (64‑bit integer).
  * @Example: see unit header.
}
function SnappyMaxCompressedLength64(srcLen: Cardinal): Int64;

{
  * SnappyCompress – compresses a block of data using the Snappy algorithm.
  * @Param Input: pointer to the first byte of the uncompressed data.
  * @Param InputSize: size of the input in bytes (must not exceed 4 GB).
  * @Param Output: pointer to the destination buffer where compressed data will be written.
  * @Param OutputSize: on input, the size of the output buffer (must be at least
  *        the value returned by SnappyMaxCompressedLength64 for this input).
  *        On output, it is updated to the actual number of bytes written.
  * @Returns: True on success, False if the buffer is too small or input is invalid.
  *
  * The compressed format begins with a varint‑encoded length of the original data,
  * followed by one or more fragments (literal or copy commands).
  * @Example: see unit header.
}
function SnappyCompress(const Input: PByte; InputSize: Int64;
  Output: PByte; var OutputSize: Int64): Boolean;

{
  * SnappyDecompress – decompresses data that was previously compressed with
  * SnappyCompress (or any Snappy‑compliant compressor).
  * @Param Compressed: pointer to the compressed data.
  * @Param CompressedSize: size of the compressed data in bytes.
  * @Param Output: pointer to the destination buffer for the decompressed data.
  * @Param OutputSize: on input, the size of the output buffer. On output,
  *        it is updated to the exact decompressed size (if successful).
  * @Returns: True on success, False if the buffer is too small, the compressed
  *          data is malformed, or the decompressed size exceeds 4 GB.
  *
  * The function validates the input and ensures that the decompressed output
  * matches the expected length stored in the header.
  * @Example: see unit header.
}
function SnappyDecompress(const Compressed: PByte; CompressedSize: Int64;
  Output: PByte; var OutputSize: Int64): Boolean;

implementation

uses Z.Core;

{ *************** Internal constants ****************************************** }
const
  kMaxHashTableBits = 14; // 2^14 = 16384 entries in hash table
  kHashTableSize = 1 shl kMaxHashTableBits; // 16384
  kMaxOffset = 65536; // maximum backward distance (64 KB)
  kMaxCopyLen = 64; // maximum length of a copy command (64 bytes)
  kMaxBlockSize = High(Cardinal); // maximum input size (4 GB - 1)

  { *************** Varint encoding/decoding helpers **************************** }
  {
    * PutVarint64 – writes a 64‑bit integer in base‑128 varint format to the buffer.
    * @Param op: pointer to the current position in the output buffer; will be advanced.
    * @Param Value: the integer to encode (non‑negative).
    * @Returns: number of bytes written (1‑10).
    * @Note: This is an inline helper used during compression.
  }
function PutVarint64(var op: PByte; Value: Int64): Integer; inline;
var Start: PByte; bCount: Integer;
begin
  Start := op; bCount := 0;
  repeat
    if Value < $80 then begin
        op^ := Byte(Value); Inc(op); Inc(bCount); Break;
      end
    else begin
        op^ := Byte(Value and $7F) or $80; Inc(op); Inc(bCount);
        Value := Value shr 7;
      end;
  until False;
  Result := bCount;
end;

{
  * GetVarint64 – reads a 64‑bit varint from a byte stream.
  * @Param sp: pointer to the current position in the input buffer; will be advanced.
  * @Param spEnd: pointer to the end of the input buffer (sentinel).
  * @Param Value: output variable to receive the decoded integer.
  * @Returns: True if decoding succeeded and sp did not exceed spEnd, otherwise False.
  * @Note: Used during decompression to read the original uncompressed length.
}
function GetVarint64(var sp: PByte; spEnd: PByte; out Value: Int64): Boolean; inline;
var Shift: Integer; b: Byte; bCount: Integer;
begin
  Value := 0; Shift := 0; bCount := 0;
  while True do begin
      if sp >= spEnd then
        begin
          Result := False;
          Exit;
        end;
      b := sp^; Inc(sp); Inc(bCount);
      Value := Value or ((b and $7F) shl Shift);
      if (b and $80) = 0 then
          Break;
      Inc(Shift, 7);
      if Shift >= 64 then
        begin
          Result := False;
          Exit;
        end;
    end;
  Result := True;
end;

{ *************** Hash function for 4‑byte values **************************** }
{
  * Hash32 – computes a hash of a 32‑bit value, mapping it to the range [0, 16383].
  * The multiplication and shift are chosen to give a good distribution.
  * @Param u: a 32‑bit unsigned integer (typically a 4‑byte chunk of input).
  * @Returns: a hash index (0..kHashTableSize‑1).
}
function Hash32(u: Cardinal): Integer; inline;
begin
  Result := Integer(Cardinal(u * Cardinal($1E35A7BD)) shr (32 - kMaxHashTableBits));
end;

{ *************** Emitting literals and copy commands ************************ }
{
  * EmitLiteral – writes a literal block to the output stream.
  * A literal is a sequence of bytes that are stored uncompressed.
  * The length is encoded in the tag byte (or following bytes) according to
  * the Snappy format (length‑1, with special cases for >60).
  * @Param op: pointer to the current output position; will be advanced.
  * @Param literal: pointer to the start of the literal data.
  * @Param len: number of bytes in the literal (must be >0).
}
procedure EmitLiteral(var op: PByte; const literal: PByte; len: Cardinal); inline;
var n: Cardinal; tagByte: Byte;
begin
  n := len - 1;
  if n < 60 then begin
      tagByte := (n shl 2); op^ := tagByte; Inc(op);
    end
  else if n <= 255 then begin
      tagByte := 60 shl 2; op^ := tagByte; Inc(op);
      op^ := Byte(n); Inc(op);
    end
  else if n <= 65535 then begin
      tagByte := 61 shl 2; op^ := tagByte; Inc(op);
      op^ := Byte(n);
      (op + 1)^ := Byte(n shr 8); Inc(op, 2);
    end
  else if n <= 16777215 then begin
      tagByte := 62 shl 2; op^ := tagByte; Inc(op);
      op^ := Byte(n);
      (op + 1)^ := Byte(n shr 8);
      (op + 2)^ := Byte(n shr 16); Inc(op, 3);
    end
  else begin
      tagByte := 63 shl 2; op^ := tagByte; Inc(op);
      op^ := Byte(n);
      (op + 1)^ := Byte(n shr 8);
      (op + 2)^ := Byte(n shr 16);
      (op + 3)^ := Byte(n shr 24);
      Inc(op, 4);
    end;
  CopyPtr(literal, op, len); Inc(op, len);
end;

{
  * EmitCopyLessThan64 – emits one or more copy commands for a repeated sequence.
  * The copy command references a previous position (offset) and copies a length
  * of bytes. To handle lengths > 11, this function splits the copy into chunks
  * of up to 11 bytes.
  * @Param op: pointer to current output position; will be advanced.
  * @Param offset: distance (in bytes) from the current output position to the
  *        already emitted data that we want to copy (1..65535).
  * @Param len: total number of bytes to copy.
  * @Note: len must be at least 4 and at most kMaxCopyLen (64), but the function
  *        is called with len <= 64; it handles splitting internally.
}
procedure EmitCopyLessThan64(var op: PByte; offset, len: Cardinal); inline;
var Remaining, chunk, lenMinus4: Cardinal; uoffset: Cardinal; tagByte: Byte;
begin
  uoffset := offset; Remaining := len;
  while Remaining >= 4 do begin
      if Remaining > 11 then begin
          chunk := 11;
          if Remaining - chunk < 4 then
              chunk := Remaining - 4;
        end
      else
          chunk := Remaining;
      lenMinus4 := chunk - 4;
      if uoffset < 256 then begin
          tagByte := (lenMinus4 shl 2) or $03;
          op^ := tagByte; Inc(op);
          op^ := Byte(uoffset); Inc(op);
        end
      else if uoffset < 65536 then begin
          tagByte := (lenMinus4 shl 2) or $01;
          op^ := tagByte; Inc(op);
          op^ := Byte(uoffset);
          (op + 1)^ := Byte(uoffset shr 8);
          Inc(op, 2);
        end
      else begin
          tagByte := (lenMinus4 shl 2) or $02;
          op^ := tagByte; Inc(op);
          op^ := Byte(uoffset);
          (op + 1)^ := Byte(uoffset shr 8);
          (op + 2)^ := Byte(uoffset shr 16);
          (op + 3)^ := Byte(uoffset shr 24);
          Inc(op, 4);
        end;
      Remaining := Remaining - chunk;
    end;
end;

{ *************** SnappyMaxCompressedLength64 ********************************* }
function SnappyMaxCompressedLength64(srcLen: Cardinal): Int64;
// Maximum compressed size formula: 32 bytes overhead + input length + 1/6th of input.
begin
  Result := 32 + Int64(srcLen) + Int64(srcLen) div 6;
end;

{ *************** Core compression (fragment compression) ******************** }
{
  * CompressFragment – compresses a single contiguous block of input.
  * This is the heart of the compression algorithm: it uses a hash table to find
  * repeated 4‑byte sequences, and emits literals or copy commands accordingly.
  * @Param input: pointer to the start of the uncompressed data.
  * @Param inputLen: length of the input (must be >0).
  * @Param op: pointer to the output buffer where compressed data will be appended.
  * @Returns: updated op pointer after all data has been written.
  * @Note: The hash table is allocated on the heap as a dynamic array to avoid
  *        stack overflow (64 KB). It is cleared before use.
}
function CompressFragment(const Input: PByte; inputLen: Cardinal; op: PByte): PByte;
var
  table: array of Integer; // dynamic array (heap) for hash table
  i: Integer;
  base, ip, ip_end, ip_limit, litStart, candidate: PByte;
  u, u2: Cardinal;
  hash: Integer;
  offset, matched, max_match: Cardinal;
  p, q: PByte;
begin
  if inputLen = 0 then begin Result := op; Exit;
    end;

  // Allocate and clear hash table (16384 entries, each 4 bytes = 64 KB)
  SetLength(table, kHashTableSize);
  for i := 0 to kHashTableSize - 1 do
      table[i] := -1;

  base := Input; ip := Input; ip_end := Input + inputLen;
  ip_limit := ip_end - 4; litStart := ip;

  while ip < ip_limit do begin
      u := PCardinal(ip)^; // read 4 bytes from current position
      hash := Hash32(u); // compute hash index
      if (hash < 0) or (hash >= kHashTableSize) then begin
          // Safety: if hash is out of bounds (should not happen), skip to next byte
          Inc(ip);
          Continue;
        end;
      candidate := base + table[hash]; // potential matching position from table
      table[hash] := ip - base; // store current position (as offset from base)

      // Check if candidate is valid (within range and not too far back)
      if (candidate >= base) and (candidate < ip) and
        (ip - candidate < kMaxOffset) then
        begin
          u2 := PCardinal(candidate)^; // read 4 bytes at candidate
          if u2 = u then // found a 4‑byte match
            begin
              offset := ip - candidate; // distance to copy from
              max_match := ip_end - ip; // maximum bytes we can copy from here
              if max_match > kMaxCopyLen then
                  max_match := kMaxCopyLen;
              if max_match > (ip_end - candidate) then
                  max_match := ip_end - candidate;

              // Extend match as far as possible (up to kMaxCopyLen)
              p := ip + 4; q := candidate + 4; matched := 4;
              while (matched < max_match) and (p^ = q^) do begin
                  Inc(matched); Inc(p); Inc(q);
                end;

              // Emit any pending literal before the match
              if ip > litStart then
                  EmitLiteral(op, litStart, ip - litStart);
              EmitCopyLessThan64(op, offset, matched);
              Inc(ip, matched); litStart := ip;
              Continue;
            end;
        end;
      Inc(ip);
    end;

  // Emit remaining bytes as a literal
  if litStart < ip_end then
      EmitLiteral(op, litStart, ip_end - litStart);
  Result := op;
end;

{ *************** Public compression API ************************************* }
function SnappyCompress(const Input: PByte; InputSize: Int64;
  Output: PByte; var OutputSize: Int64): Boolean;
var srcLen: Cardinal; maxLen: Int64; op, endPtr: PByte;
begin
  Result := False;
  if InputSize = 0 then begin
      // Empty input: output a single zero byte (valid Snappy stream)
      if OutputSize < 1 then
          Exit;
      Output^ := 0; OutputSize := 1; Result := True; Exit;
    end;
  if InputSize > kMaxBlockSize then begin Exit;
    end; // input too large
  srcLen := Cardinal(InputSize);
  maxLen := SnappyMaxCompressedLength64(srcLen);
  if OutputSize < maxLen then begin Exit;
    end; // buffer too small
  op := Output;
  PutVarint64(op, Int64(srcLen)); // write uncompressed length header
  endPtr := CompressFragment(Input, srcLen, op); // compress the data
  OutputSize := endPtr - Output; // actual compressed size
  Result := True;
end;

{ *************** Public decompression API *********************************** }
function SnappyDecompress(const Compressed: PByte; CompressedSize: Int64;
  Output: PByte; var OutputSize: Int64): Boolean;
var
  sp, spEnd, op, opEnd, srcPtr: PByte;
  expectedLen: Int64; destLen: Cardinal; tag: Byte; len, offset: Cardinal;
  litCnt, copyCnt: Integer;
begin
  Result := False; litCnt := 0; copyCnt := 0;
  if CompressedSize <= 0 then
      Exit;
  if CompressedSize > kMaxBlockSize then
      Exit;
  sp := Compressed; spEnd := sp + Cardinal(CompressedSize);

  // Read the varint‑encoded expected decompressed length
  if not GetVarint64(sp, spEnd, expectedLen) then
      Exit;
  if expectedLen > kMaxBlockSize then
      Exit;
  if OutputSize < expectedLen then begin
      Exit; // output buffer too small
    end;
  if expectedLen = 0 then begin OutputSize := 0; Result := True; Exit;
    end;

  destLen := Cardinal(expectedLen);
  op := Output; opEnd := op + destLen;

  while op < opEnd do begin
      if sp >= spEnd then begin Exit;
        end;
      tag := sp^; Inc(sp); // read tag byte

      // ---- Literal command (tag & 3 == 0) ----
      if (tag and $03) = 0 then begin
          len := (tag shr 2) + 1;
          if len >= 61 then begin
              // Long literal length: read extra bytes
              case len - 1 of
                60: begin
                    if sp >= spEnd then
                        Exit;
                    len := sp^ + 1; Inc(sp);
                  end;
                61: begin
                    if sp + 1 >= spEnd then
                        Exit;
                    len := sp^ + (PByte(sp + 1)^ shl 8) + 1; Inc(sp, 2);
                  end;
                62: begin
                    if sp + 2 >= spEnd then
                        Exit;
                    len := sp^ + (PByte(sp + 1)^ shl 8) + (PByte(sp + 2)^ shl 16) + 1; Inc(sp, 3);
                  end;
                63: begin
                    if sp + 3 >= spEnd then
                        Exit;
                    len := sp^ + (PByte(sp + 1)^ shl 8) + (PByte(sp + 2)^ shl 16) + (PByte(sp + 3)^ shl 24) + 1; Inc(sp, 4);
                  end;
                else Exit;
              end;
            end;
          Inc(litCnt);
          if (sp + len > spEnd) or (op + len > opEnd) then
              Exit;
          CopyPtr(sp, op, len); // copy literal bytes directly
          Inc(sp, len); Inc(op, len);
        end
        // ---- Copy command (tag & 3 != 0) ----
      else begin
          len := ((tag shr 2) and 7) + 4; // base length (4‑11)
          case tag and 3 of
            1: begin
                if sp + 1 >= spEnd then
                    Exit;
                offset := sp^ + (PByte(sp + 1)^ shl 8); Inc(sp, 2);
              end; // 16‑bit offset
            2: begin
                if sp + 3 >= spEnd then
                    Exit;
                offset := sp^ + (PByte(sp + 1)^ shl 8) + (PByte(sp + 2)^ shl 16) + (PByte(sp + 3)^ shl 24); Inc(sp, 4);
              end; // 32‑bit offset
            3: begin
                if sp >= spEnd then
                    Exit;
                offset := sp^; Inc(sp);
              end; // 8‑bit offset
            else Exit;
          end;
          Inc(copyCnt);
          if offset = 0 then
              Exit;
          if offset > Cardinal(op - Output) then begin Exit;
            end; // offset points before output start
          if op + len > opEnd then
              Exit;
          srcPtr := op - offset;
          // Copy the sequence byte‑by‑byte (handles overlapping source/destination)
          while len > 0 do begin op^ := srcPtr^; Inc(op); Inc(srcPtr); Dec(len);
            end;
        end;
    end;

  // After processing all output, we should have consumed exactly the compressed data
  if sp <> spEnd then begin Exit;
    end;
  OutputSize := expectedLen;
  Result := True;
end;

end.

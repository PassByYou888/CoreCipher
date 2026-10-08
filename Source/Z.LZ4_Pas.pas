{ ******************************************************************************
  * Z.LZ4_Pas – LZ4 Block Compression for Delphi / Free Pascal
  *
  * This unit provides a pure Pascal implementation of the LZ4 compression
  * algorithm, compatible with the official LZ4 block format. It offers both
  * 32‑bit and 64‑bit APIs to handle input sizes up to 2 GB (32‑bit) or beyond
  * (64‑bit). The code is designed for high performance and uses a hash table
  * (65536 entries) to find repeated sequences within a 64‑KB sliding window.
  *
  * LZ4 is a very fast lossless compression algorithm based on the LZ77
  * principle. It replaces repeated byte sequences with references (offset,
  * length) to earlier data, and outputs literal bytes otherwise. The compressed
  * format uses tokens that encode both literal and match lengths in a compact
  * variable‑length encoding.
  *
  * @Example (32‑bit compression):
  *   var
  *     src, dst: TBytes;
  *     srcSize, dstCapacity, compressedSize: Integer;
  *   begin
  *     src := TEncoding.UTF8.GetBytes('Hello, world! This is a test.');
  *     srcSize := Length(src);
  *     dstCapacity := LZ4_compressBound(srcSize); // get maximum needed size
  *     SetLength(dst, dstCapacity);
  *     compressedSize := LZ4_compress_default(src[0], srcSize, dst[0], dstCapacity);
  *     if compressedSize > 0 then SetLength(dst, compressedSize); // trim
  *   end;
  *
  * @Example (32‑bit decompression):
  *   var
  *     decompressed: TBytes;
  *     decompressedSize: Integer;
  *   begin
  *     // Assume 'dst' contains compressed data from previous example
  *     decompressedSize := 100; // or any large enough buffer; function returns actual size
  *     SetLength(decompressed, decompressedSize);
  *     decompressedSize := LZ4_decompress_safe(dst[0], compressedSize, decompressed[0], Length(decompressed));
  *     if decompressedSize > 0 then SetLength(decompressed, decompressedSize);
  *   end;
  *
  * For larger data (>2 GB), use the 64‑bit functions: LZ4_compressBound64,
  * LZ4_compress_default64, and LZ4_decompress_safe64.
  ****************************************************************************** }
unit Z.LZ4_Pas;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}
{$POINTERMATH ON} // Allow pointer arithmetic (e.g., PByte + offset)

interface

// ----- 32‑bit API (for inputs up to 2 GB) ------------------------------------

{
  * LZ4_compressBound – calculates the maximum size that the compressed output
  * can occupy for a given input size. This value is safe to use as the
  * destination buffer capacity when calling LZ4_compress_default.
  * @Param srcSize: size of the uncompressed input in bytes (0..2^31‑1).
  * @Returns: maximum compressed size in bytes.
  * @Example: see unit header.
}
function LZ4_compressBound(srcSize: Integer): Integer;

{
  * LZ4_compress_default – compresses a block of data using the LZ4 algorithm.
  * @Param Src: the source data (any variable, typically an array or buffer).
  * @Param srcSize: size of the source data in bytes.
  * @Param Dst: the destination buffer where compressed data will be written.
  * @Param DstCapacity: capacity of the destination buffer in bytes (should be
  *        at least the value returned by LZ4_compressBound for this srcSize).
  * @Returns: the actual number of bytes written to Dst, or 0 if the buffer is
  *          too small or an error occurred.
  * @Example: see unit header.
}
function LZ4_compress_default(const Src; srcSize: Integer; var Dst; DstCapacity: Integer): Integer;

{
  * LZ4_decompress_safe – decompresses data that was previously compressed with
  * LZ4_compress_default (or any LZ4‑compliant compressor).
  * @Param Src: the compressed data.
  * @Param CompressedSize: size of the compressed data in bytes.
  * @Param Dst: the destination buffer for the decompressed output.
  * @Param DstCapacity: the capacity of the destination buffer in bytes.
  * @Returns: the number of bytes written to Dst (i.e., the original uncompressed
  *          size) on success, or a negative error code on failure:
  *            -1  : generic error
  *            -2  : invalid input (reading varint failed)
  *            -3  : output buffer overflow
  *            -4  : input too short (not enough data for literal)
  *            -5  : invalid input (reading match varint failed)
  *            -6  : not enough input for offset
  *            -7  : invalid offset (zero)
  *            -8  : offset points before start of output
  *            -9  : output buffer overflow during match copy
  *            -10 : final decompressed size does not match DstCapacity
  * @Example: see unit header.
}
function LZ4_decompress_safe(const Src; CompressedSize: Integer; var Dst; DstCapacity: Integer): Integer;

// ----- 64‑bit API (for inputs > 2 GB) ----------------------------------------

{
  * LZ4_compressBound64 – same as LZ4_compressBound but for 64‑bit sizes.
  * @Param srcSize: size of the uncompressed input in bytes (up to 2^63‑1).
  * @Returns: maximum compressed size in bytes (64‑bit).
}
function LZ4_compressBound64(srcSize: Int64): Int64;

{
  * LZ4_compress_default64 – 64‑bit version of LZ4_compress_default.
  * Parameters and behavior are identical, but sizes are Int64.
}
function LZ4_compress_default64(const Src; srcSize: Int64; var Dst; DstCapacity: Int64): Int64;

{
  * LZ4_decompress_safe64 – 64‑bit version of LZ4_decompress_safe.
  * Parameters and behavior are identical, but sizes are Int64.
}
function LZ4_decompress_safe64(const Src; CompressedSize: Int64; var Dst; DstCapacity: Int64): Int64;

implementation

{ *************** Internal constants and types ******************************** }
const
  HASH_LOG = 16; // 2^16 = 65536 hash table entries
  HASH_SIZE = 1 shl HASH_LOG; // 65536
  MINMATCH = 4; // minimum match length
  MAX_DISTANCE = 65535; // maximum offset (64 KB)
  LAST_LITERALS = 5; // number of bytes to leave at end to simplify loop

type
  PByte = ^Byte;
  PCardinal = ^Cardinal;

  { *************** Public bound functions (simple formulas) ******************* }

function LZ4_compressBound(srcSize: Integer): Integer;
// Maximum compressed size = srcSize + srcSize/255 + 16 (overhead).
begin
  Result := srcSize + (srcSize div 255) + 16;
end;

function LZ4_compressBound64(srcSize: Int64): Int64;
begin
  Result := srcSize + (srcSize div 255) + 16;
end;

{ *************** Hash function ********************************************** }
{
  * LZ4_Hash – computes a 16‑bit hash from a 32‑bit value.
  * Uses the golden ratio multiplier to distribute values evenly.
  * @Param U4: a 4‑byte chunk (Cardinal) from the input.
  * @Returns: hash index in [0, HASH_SIZE‑1].
}
function LZ4_Hash(U4: Cardinal): Integer; inline;
begin
  Result := Integer(Cardinal(U4 * Cardinal(2654435761)) shr (32 - HASH_LOG));
end;

{ *************** Variable‑length integer encoding (Write) ****************** }
{
  * WriteVarLen – writes a variable‑length integer to the output buffer.
  * Values 0..254 are stored as a single byte; 255 indicates that another byte
  * follows, and the process repeats. This is used for extra literal/match lengths.
  * @Param op: pointer to the current output position; will be advanced.
  * @Param len: the integer to write (must be >= 0).
  * @Note: Overloaded for 32‑bit and 64‑bit lengths.
}
procedure WriteVarLen(var op: PByte; len: Integer); overload;
var
  b: Byte;
begin
  while len >= 255 do
    begin
      op^ := 255;
      Inc(op);
      Dec(len, 255);
    end;
  op^ := Byte(len);
  Inc(op);
end;

procedure WriteVarLen(var op: PByte; len: Int64); overload;
var
  b: Byte;
begin
  while len >= 255 do
    begin
      op^ := 255;
      Inc(op);
      Dec(len, 255);
    end;
  op^ := Byte(len);
  Inc(op);
end;

{ *************** Variable‑length integer decoding (Read) ******************* }
{
  * ReadVarLen – reads a variable‑length integer from the input buffer.
  * @Param ip: pointer to the current input position; will be advanced.
  * @Param len: output variable to accumulate the decoded value (initially should
  *        be zero, or the base value to add to).
  * @Param iend: pointer to the end of the input buffer (sentinel).
  * @Returns: True if decoding succeeded and ip did not exceed iend; otherwise False.
  * @Note: Overloaded for 32‑bit and 64‑bit lengths.
}
function ReadVarLen(var ip: PByte; var len: Integer; iend: PByte): Boolean; overload;
var
  b: Byte;
begin
  Result := False;
  repeat
    if ip >= iend then
        Exit;
    b := ip^;
    Inc(ip);
    Inc(len, b);
  until b < 255;
  Result := True;
end;

function ReadVarLen(var ip: PByte; var len: Int64; iend: PByte): Boolean; overload;
var
  b: Byte;
begin
  Result := False;
  repeat
    if ip >= iend then
        Exit;
    b := ip^;
    Inc(ip);
    Inc(len, b);
  until b < 255;
  Result := True;
end;

{ *************** 32‑bit Compression Core ************************************ }
{
  * LZ4_compress_default – compresses a block of data.
  *
  * Algorithm steps:
  *   1. If the input is smaller than MINMATCH (4 bytes), output the entire
  *      input as a single literal block (no match).
  *   2. Initialize the hash table (all entries set to -1, meaning "empty").
  *   3. Iterate through the input while there is enough room to search.
  *      - At each position, read 4 bytes, compute its hash.
  *      - Look up the hash table to see if we have seen this hash before.
  *      - If a previous occurrence exists within the MAX_DISTANCE window
  *        and the 4 bytes match, we found a match.
  *      - Extend the match as far as possible (up to the end of input).
  *      - Output the current literal run (bytes since the last match) as a
  *        literal sequence.
  *      - Output the match as a copy command (offset, length).
  *      - Advance the input pointer past the match and reset the anchor.
  *      - If no match, advance by 1 byte.
  *   4. After the loop, output any remaining bytes as a final literal sequence
  *      (with no offset).
  *   5. Return the size of the compressed data, or 0 if the output buffer is too small.
}
function LZ4_compress_default(const Src; srcSize: Integer; var Dst; DstCapacity: Integer): Integer;
var
  ip, iend, op, oend: PByte;
  hashTable: array [0 .. HASH_SIZE - 1] of Integer; // Stores offsets from the start of Src
  anchor: PByte; // Start of current literal run
  u: Cardinal;
  h, refOffset: Integer;
  candidate: PByte;
  matchLength, litLength: Integer;
  offset: Word;
  token: Byte;
  extraLit, extraMatch: Integer;
begin
  ip := @Src; // input pointer
  iend := ip + srcSize; // end of input
  op := @Dst; // output pointer
  oend := op + DstCapacity; // end of output buffer

  // ---- Very small input: just literals ----
  if srcSize < MINMATCH then
    begin
      op^ := (srcSize shl 4); // token: high nibble = literal length, low = 0 (no match)
      Inc(op);
      if srcSize >= 15 then
          WriteVarLen(op, srcSize - 15); // extra length if >=15
      Move(ip^, op^, srcSize); // copy literals
      Inc(op, srcSize);
      Result := op - PByte(@Dst); // return compressed size
      Exit;
    end;

  // ---- Initialize hash table with -1 (no previous occurrence) ----
  FillChar(hashTable, SizeOf(hashTable), $FF);
  anchor := ip;

  // ---- Main compression loop ----
  while ip < iend - LAST_LITERALS do
    begin
      u := PCardinal(ip)^; // read 4 bytes from current position
      h := LZ4_Hash(u); // compute hash
      refOffset := hashTable[h]; // previous position with same hash (offset from start)
      hashTable[h] := ip - PByte(@Src); // store current position as offset from Src

      // Check if this is a valid match:
      // - refOffset >= 0 (hash table entry was set)
      // - distance to the candidate is within MAX_DISTANCE
      // - the 4 bytes at candidate equal the current 4 bytes
      if (refOffset >= 0) and
        (ip - PByte(@Src) - refOffset <= MAX_DISTANCE) and
        (PCardinal(PByte(@Src) + refOffset)^ = u) then
        begin
          candidate := PByte(@Src) + refOffset;
          offset := Word(ip - PByte(@Src) - refOffset); // distance (offset) for copy

          // Extend match as far as possible
          matchLength := MINMATCH;
          while (matchLength < (iend - ip)) and (candidate[matchLength] = ip[matchLength]) do
              Inc(matchLength);

          // Determine literal length (bytes since last match)
          litLength := ip - anchor;

          // Build the token byte:
          // bits 7-4: literal length (15 if >=15, else exact)
          // bits 3-0: match length - 4 (15 if >=15, else exact)
          token := 0;
          if litLength >= 15 then
              token := $F0
          else
              token := litLength shl 4;
          extraMatch := matchLength - MINMATCH;
          if extraMatch >= 15 then
              token := token or $0F
          else
              token := token or extraMatch;

          // Write token
          op^ := token;
          Inc(op);

          // Write extra literal length if needed
          if litLength >= 15 then
            begin
              extraLit := litLength - 15;
              WriteVarLen(op, extraLit);
            end;

          // Write literal bytes
          if litLength > 0 then
            begin
              Move(anchor^, op^, litLength);
              Inc(op, litLength);
            end;

          // Write offset (2 bytes, little‑endian)
          PWord(op)^ := offset;
          Inc(op, 2);

          // Write extra match length if needed
          if extraMatch >= 15 then
            begin
              extraMatch := extraMatch - 15;
              WriteVarLen(op, extraMatch);
            end;

          // Advance ip past the match and reset anchor
          Inc(ip, matchLength);
          anchor := ip;
          Continue;
        end;

      // No match found: move forward by 1 byte
      Inc(ip);
    end;

  // ---- Emit final literal run (no match) ----
  litLength := iend - anchor;
  token := 0;
  if litLength >= 15 then
      token := $F0
  else
      token := litLength shl 4;

  op^ := token;
  Inc(op);
  if litLength >= 15 then
    begin
      extraLit := litLength - 15;
      WriteVarLen(op, extraLit);
    end;
  if litLength > 0 then
    begin
      Move(anchor^, op^, litLength);
      Inc(op, litLength);
    end;

  // Return compressed size, or 0 if it exceeds DstCapacity
  Result := op - PByte(@Dst);
  if Result > DstCapacity then
      Result := 0;
end;

{ *************** 32‑bit Decompression Core ********************************** }
{
  * LZ4_decompress_safe – decompresses an LZ4 compressed block.
  *
  * The decompressor reads the compressed stream sequentially:
  *   - For each sequence, it reads the token byte.
  *   - It decodes the literal length (from token and possibly extra bytes).
  *   - It copies the specified number of literal bytes directly to output.
  *   - If the end of block is not reached, it reads the 2‑byte offset.
  *   - It decodes the match length (from token and extra bytes).
  *   - It copies the match from the already decoded output using the offset.
  *   - It repeats until all output is produced.
  *
  * The function performs bounds checking at every step to ensure safety.
  * Returns the number of bytes decompressed, or a negative error code.
}
function LZ4_decompress_safe(const Src; CompressedSize: Integer; var Dst; DstCapacity: Integer): Integer;
var
  ip, iend, op, oend: PByte;
  token: Byte;
  litLength, matchLength: Integer;
  offset: Word;
  copyPos: PByte;
  i: Integer;
begin
  ip := @Src;
  iend := ip + CompressedSize;
  op := @Dst;
  oend := op + DstCapacity;

  while ip < iend do
    begin
      // ---- Read token ----
      token := ip^;
      Inc(ip);

      // ---- Decode literal length ----
      litLength := token shr 4;
      if litLength = 15 then
        begin
          if not ReadVarLen(ip, litLength, iend) then
            begin
              Result := -2; // invalid input
              Exit;
            end;
        end;

      // ---- Copy literals ----
      if litLength > 0 then
        begin
          if op + litLength > oend then
            begin
              Result := -3; // output overflow
              Exit;
            end;
          if ip + litLength > iend then
            begin
              Result := -4; // input too short
              Exit;
            end;
          Move(ip^, op^, litLength);
          Inc(ip, litLength);
          Inc(op, litLength);
        end;

      // ---- End of block? ----
      if op >= oend then
          Break;

      // ---- Read offset ----
      if ip + 2 > iend then
        begin
          Result := -6; // not enough input for offset
          Exit;
        end;
      offset := PWord(ip)^;
      Inc(ip, 2);

      if offset <= 0 then
        begin
          Result := -7; // invalid offset
          Exit;
        end;

      // ---- Decode match length ----
      matchLength := token and $0F;
      if matchLength = 15 then
        begin
          if not ReadVarLen(ip, matchLength, iend) then
            begin
              Result := -5; // invalid input
              Exit;
            end;
        end;
      Inc(matchLength, MINMATCH);

      // ---- Validate and copy match ----
      copyPos := op - offset; // source of match (within already output)
      if copyPos < PByte(@Dst) then
        begin
          Result := -8; // offset points before start
          Exit;
        end;

      if op + matchLength > oend then
        begin
          Result := -9; // output overflow
          Exit;
        end;

      // Copy match byte by byte to handle overlapping source/destination
      i := 0;
      while i < matchLength do  // fixed fpc-32bit compiler
        begin
          op^ := copyPos^;
          Inc(op);
          Inc(copyPos);
          Inc(i);
        end;
    end;

  // ---- Return decompressed size ----
  Result := op - PByte(@Dst);
  if Result <> DstCapacity then
    begin
      if Result < DstCapacity then
          Result := -10; // mismatch: output size differs from expected
    end;
end;

{ *************** 64‑bit Compression Core ************************************ }
{
  * LZ4_compress_default64 – 64‑bit version of the compression routine.
  * The algorithm is identical to the 32‑bit version, but uses Int64 for sizes
  * and stores 64‑bit offsets in the hash table.
}
function LZ4_compress_default64(const Src; srcSize: Int64; var Dst; DstCapacity: Int64): Int64;
var
  ip, iend, op, oend: PByte;
  hashTable: array [0 .. HASH_SIZE - 1] of Int64; // 64‑bit offsets
  anchor: PByte;
  u: Cardinal;
  h, refOffset: Int64;
  candidate: PByte;
  matchLength, litLength: Int64;
  offset: Word;
  token: Byte;
  extraLit, extraMatch: Int64;
begin
  ip := @Src;
  iend := ip + srcSize;
  op := @Dst;
  oend := op + DstCapacity;

  // ---- Very small input: just literals ----
  if srcSize < MINMATCH then
    begin
      op^ := (srcSize shl 4);
      Inc(op);
      if srcSize >= 15 then
          WriteVarLen(op, srcSize - 15);
      Move(ip^, op^, srcSize);
      Inc(op, srcSize);
      Result := op - PByte(@Dst);
      Exit;
    end;

  // ---- Initialize hash table ----
  FillChar(hashTable, SizeOf(hashTable), $FF);
  anchor := ip;

  // ---- Main compression loop ----
  while ip < iend - LAST_LITERALS do
    begin
      u := PCardinal(ip)^;
      h := LZ4_Hash(u);
      refOffset := hashTable[h];
      hashTable[h] := ip - PByte(@Src);

      if (refOffset >= 0) and
        (ip - PByte(@Src) - refOffset <= MAX_DISTANCE) and
        (PCardinal(PByte(@Src) + refOffset)^ = u) then
        begin
          candidate := PByte(@Src) + refOffset;
          offset := Word(ip - PByte(@Src) - refOffset);

          matchLength := MINMATCH;
          while (matchLength < (iend - ip)) and (candidate[matchLength] = ip[matchLength]) do
              Inc(matchLength);

          litLength := ip - anchor;
          token := 0;
          if litLength >= 15 then
              token := $F0
          else
              token := litLength shl 4;
          extraMatch := matchLength - MINMATCH;
          if extraMatch >= 15 then
              token := token or $0F
          else
              token := token or extraMatch;

          op^ := token;
          Inc(op);
          if litLength >= 15 then
            begin
              extraLit := litLength - 15;
              WriteVarLen(op, extraLit);
            end;
          if litLength > 0 then
            begin
              Move(anchor^, op^, litLength);
              Inc(op, litLength);
            end;
          PWord(op)^ := offset;
          Inc(op, 2);
          if extraMatch >= 15 then
            begin
              extraMatch := extraMatch - 15;
              WriteVarLen(op, extraMatch);
            end;

          Inc(ip, matchLength);
          anchor := ip;
          Continue;
        end;

      Inc(ip);
    end;

  // ---- Emit final literal run ----
  litLength := iend - anchor;
  token := 0;
  if litLength >= 15 then
      token := $F0
  else
      token := litLength shl 4;

  op^ := token;
  Inc(op);
  if litLength >= 15 then
    begin
      extraLit := litLength - 15;
      WriteVarLen(op, extraLit);
    end;
  if litLength > 0 then
    begin
      Move(anchor^, op^, litLength);
      Inc(op, litLength);
    end;

  Result := op - PByte(@Dst);
  if Result > DstCapacity then
      Result := 0;
end;

{ *************** 64‑bit Decompression Core ********************************** }
{
  * LZ4_decompress_safe64 – 64‑bit version of the decompression routine.
  * The algorithm is identical to the 32‑bit version, but uses Int64 for sizes.
}
function LZ4_decompress_safe64(const Src; CompressedSize: Int64; var Dst; DstCapacity: Int64): Int64;
var
  ip, iend, op, oend: PByte;
  token: Byte;
  litLength, matchLength: Int64;
  offset: Word;
  copyPos: PByte;
  i: Int64;
begin
  ip := @Src;
  iend := ip + CompressedSize;
  op := @Dst;
  oend := op + DstCapacity;

  while ip < iend do
    begin
      token := ip^;
      Inc(ip);

      litLength := token shr 4;
      if litLength = 15 then
        begin
          if not ReadVarLen(ip, litLength, iend) then
            begin
              Result := -2;
              Exit;
            end;
        end;

      if litLength > 0 then
        begin
          if op + litLength > oend then
            begin
              Result := -3;
              Exit;
            end;
          if ip + litLength > iend then
            begin
              Result := -4;
              Exit;
            end;
          Move(ip^, op^, litLength);
          Inc(ip, litLength);
          Inc(op, litLength);
        end;

      if op >= oend then
          Break;

      if ip + 2 > iend then
        begin
          Result := -6;
          Exit;
        end;
      offset := PWord(ip)^;
      Inc(ip, 2);

      if offset <= 0 then
        begin
          Result := -7;
          Exit;
        end;

      matchLength := token and $0F;
      if matchLength = 15 then
        begin
          if not ReadVarLen(ip, matchLength, iend) then
            begin
              Result := -5;
              Exit;
            end;
        end;
      Inc(matchLength, MINMATCH);

      copyPos := op - offset;
      if copyPos < PByte(@Dst) then
        begin
          Result := -8;
          Exit;
        end;

      if op + matchLength > oend then
        begin
          Result := -9;
          Exit;
        end;

      i := 0;
      while i < matchLength do  // fixed fpc-32bit compiler
        begin
          op^ := copyPos^;
          Inc(op);
          Inc(copyPos);
          Inc(i);
        end;
    end;

  Result := op - PByte(@Dst);
  if Result <> DstCapacity then
    begin
      if Result < DstCapacity then
          Result := -10;
    end;
end;

end.

{===============================================================================
 * Z.Cipher.imp_THashMD5.inc  ¡ª  MD5 message digest implementation
 *
 * Bug fixes applied (FPC O2 optimization safety):
 *   1. CRITICAL: GenerateMD5Key computed a local digest "d" but never copied
 *      it to the caller's "key" parameter, leaving "key" uninitialized
 *      (stack garbage). Every call produced a different derived key, which
 *      silently broke password-based encryption. FIXED: CopyPtr the digest
 *      into the TKey128 output.
 *   2. GenerateMD5Key: guard against Length(Bytes_) = 0 before using
 *      Bytes_[0] (previously an out-of-bounds access).
 *   3. FinalizeMD5: removed the no-op "CopyPtr(@Context, @Context, ...)".
 *      Under -O2 this self-copy may expand to a memmove-with-overlap check
 *      and generate warnings / undefined behaviour.
 *   4. UpdateMD5: the carry detection "if BufSize shl 3 < 0 then ..." was
 *      incorrect.
 *        - For BufSize in [2^28, 2^29), the shifted value has bit 31 set
 *          but no real 32-bit overflow occurs -> a spurious carry.
 *        - On 64-bit NativeInt, "BufSize shl 3" is a 64-bit operation, so
 *          the signed "< 0" test is essentially never true -> the carry is
 *          dropped entirely.
 *      FIXED with the canonical RFC 1321 pattern:
 *        OldLo := Count[0];
 *        AddLo := DWORD(BufSize) shl 3;
 *        inc(Count[0], AddLo);
 *        if Count[0] < OldLo then inc(Count[1]);
 *        inc(Count[1], DWORD(BufSize) shr 29);
 *   5. Loop counters widened from Word to Integer to avoid 16-bit register
 *      quirks under -O2.
 *
 * Conventions (project-wide):
 *   - No Move / no FillChar. Use CopyPtr / FillPtr from Z.Core.
 *   - English comments only.
===============================================================================}

class procedure THashMD5.GenerateMD5Key(var key: TKey128; const Bytes_: TBytes);
var
  d: TMD5Digest;
begin
  { FIX: handle empty input explicitly to avoid Bytes_[0] access. }
  if Length(Bytes_) = 0 then
    begin
      FillPtr(@key, SizeOf(TKey128), 0);
      Exit;
    end;

  HashMD5(d, Bytes_[0], Length(Bytes_));

  { FIX: original code computed "d" but never wrote it back to "key".
    Copy the 16-byte digest into the caller's TKey128 buffer. }
  CopyPtr(@d, @key, SizeOf(TKey128));
end;

class procedure THashMD5.HashMD5(var Digest: TMD5Digest; const Buf; BufSize: NativeInt);
var
  Context: TMD5Context;
begin
  FillPtr(@Context, SizeOf(Context), $00);
  InitMD5(Context);
  UpdateMD5(Context, Buf, BufSize);
  FinalizeMD5(Context, Digest);
end;

class procedure THashMD5.ByteBuffHashMD5(var Digest: TMD5Digest; const Bytes_: TBytes);
begin
  if Length(Bytes_) = 0 then
    begin
      FillPtr(@Digest, SizeOf(TMD5Digest), 0);
      Exit;
    end;
  HashMD5(Digest, Bytes_[0], Length(Bytes_));
end;

class procedure THashMD5.InitMD5(var Context: TMD5Context);
begin
  Context.Count[0] := 0;
  Context.Count[1] := 0;

  { Load magic initialization constants }
  Context.State[0] := $67452301;
  Context.State[1] := $EFCDAB89;
  Context.State[2] := $98BADCFE;
  Context.State[3] := $10325476;
end;

class procedure THashMD5.UpdateMD5(var Context: TMD5Context; const Buf; BufSize: NativeInt);
var
  InBuf: TTransformInput;
  BufOfs: NativeUInt;
  MDI: DWORD;
  i: Integer;
  OldLo, AddLo: DWORD;
begin
  { Number of bytes already buffered (mod 64) }
  MDI := (Context.Count[0] shr 3) and $3F;

  { FIX: canonical RFC 1321 carry detection.
    Compute the 64-bit bit-length counter (Count[1]:Count[0]).
      - AddLo is the low 32 bits of BufSize * 8.
      - High 3 bits of BufSize go into the high DWORD. }
  AddLo := DWORD(BufSize) shl 3;
  OldLo := Context.Count[0];
  inc(Context.Count[0], AddLo);
  if Context.Count[0] < OldLo then
      inc(Context.Count[1]);
  inc(Context.Count[1], DWORD(BufSize) shr 29);

  { Append the new bytes to the internal 64-byte block buffer. }
  BufOfs := 0;
  while BufSize > 0 do
    begin
      dec(BufSize);
      Context.Buf[MDI] := TCCByteArray(Buf)[BufOfs]; { !!.01 }
      inc(MDI);
      inc(BufOfs);
      if MDI = $40 then
        begin
          for i := 0 to 15 do
              InBuf[i] := PDWORD(@Context.Buf[i * 4])^;
          TMISC.Transform(Context.State, InBuf);
          MDI := 0;
        end;
    end;
end;

class procedure THashMD5.FinalizeMD5(var Context: TMD5Context; var Digest: TMD5Digest);
const
  Padding: array [0 .. 63] of Byte = (
  $80, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);
var
  InBuf: TTransformInput;
  MDI: Integer;
  i: Integer;
  II: Integer;
  PadLen: Integer;
begin
  { Save the original message bit-length BEFORE padding.
    These two DWORDs go into the final block at positions 56..63. }
  InBuf[14] := Context.Count[0];
  InBuf[15] := Context.Count[1];

  { Compute the current buffered byte count (mod 64). }
  MDI := (Context.Count[0] shr 3) and $3F;

  { Pad out to (56 mod 64): 1..64 bytes, beginning with 0x80. }
  if MDI < 56 then
      PadLen := 56 - MDI
  else
      PadLen := 120 - MDI;
  UpdateMD5(Context, Padding, PadLen);

  { FIX: the original code had a no-op CopyPtr(@Context, @Context, ...)
    here. Removed ¡ª under -O2 this self-copy may expand to a memmove with
    overlap detection and cause UB / warning noise. }

  { Rebuild the last 512-bit block as 16 little-endian DWORDs.
    Bytes 0..55 come from Context.Buf (message tail + 0x80 + zeros);
    bytes 56..63 are the original message bit-length saved above. }
  II := 0;
  for i := 0 to 13 do
    begin
      InBuf[i] := (DWORD(Context.Buf[II + 3]) shl 24) or
                  (DWORD(Context.Buf[II + 2]) shl 16) or
                  (DWORD(Context.Buf[II + 1]) shl 8)  or
                   DWORD(Context.Buf[II]);
      inc(II, 4);
    end;
  TMISC.Transform(Context.State, InBuf);

  { Store the final state in little-endian order. }
  II := 0;
  for i := 0 to 3 do
    begin
      Digest[II]     := Byte( Context.State[i]         and $FF);
      Digest[II + 1] := Byte((Context.State[i] shr  8) and $FF);
      Digest[II + 2] := Byte((Context.State[i] shr 16) and $FF);
      Digest[II + 3] := Byte((Context.State[i] shr 24) and $FF);
      inc(II, 4);
    end;

  { Wipe the transient block. }
  FillPtr(@InBuf, SizeOf(InBuf), $00);
end;

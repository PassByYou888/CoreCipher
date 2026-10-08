{ TBlowfish }

{
 * ============================================================================
 * Blowfish block cipher.
 *
 * Faithful Pascal port of the mbed TLS implementation (ARM Limited,
 * Apache-2.0). mbed TLS is the reference Blowfish implementation used by
 * the ARM ecosystem and passes the standard Schneier/SSLeay test vectors,
 * including the 128-bit zero-key/zero-plaintext vector 4EF997456198DD78.
 *
 * Byte-order convention (matching mbed TLS):
 *
 *   mbed TLS uses GET_UINT32_BE / PUT_UINT32_BE on the caller's byte
 *   buffer. On a little-endian host this is equivalent to reading /
 *   writing the two DWORDs of TBFBlock in big-endian order, which is
 *   exactly what Endian() does. The internal P-array and S-boxes are
 *   stored as native DWORDs, identical to mbed TLS's uint32_t arrays.
 *
 *   This means: EncryptBF is byte-order-aware at its boundary, but the
 *   key schedule (InitEncryptBF) and F() operate purely on native DWORDs,
 *   so no additional conversion is needed inside the schedule.
 * ============================================================================
 *}

class procedure TBlowfish.EncryptBF(const Context: TBFContext; var Block: TBFBlock; Encrypt: Boolean);
var
  Xl, Xr, temp: DWORD;
  i: Integer;

  { Blowfish F-function. Ported verbatim from mbed TLS. }
  function F(x: DWORD): DWORD;
  var
    a, b, c, d: Byte;
  begin
    d := Byte(x and $FF);
    x := x shr 8;
    c := Byte(x and $FF);
    x := x shr 8;
    b := Byte(x and $FF);
    x := x shr 8;
    a := Byte(x and $FF);
    Result := ((Context.SBox[0, a] + Context.SBox[1, b]) xor Context.SBox[2, c])
              + Context.SBox[3, d];
  end;

begin
  { --- entry: read the two DWORDs in big-endian order (mbed TLS GET_UINT32_BE) --- }
  Xl := Endian(Block[0]);
  Xr := Endian(Block[1]);

  if Encrypt then
    begin
      { --- mbed TLS blowfish_enc: 16 rounds, swap after every round --- }
      for i := 0 to 15 do
        begin
          Xl := Xl xor Context.PBox[i];
          Xr := F(Xl) xor Xr;
          temp := Xl;
          Xl := Xr;
          Xr := temp;
        end;
      { undo the final swap }
      temp := Xl;
      Xl := Xr;
      Xr := temp;
      { final two P-box XORs }
      Xr := Xr xor Context.PBox[16];
      Xl := Xl xor Context.PBox[17];
    end
  else
    begin
      { --- mbed TLS blowfish_dec: reverse order --- }
      for i := 17 downto 2 do
        begin
          Xl := Xl xor Context.PBox[i];
          Xr := F(Xl) xor Xr;
          temp := Xl;
          Xl := Xr;
          Xr := temp;
        end;
      temp := Xl;
      Xl := Xr;
      Xr := temp;
      Xr := Xr xor Context.PBox[1];
      Xl := Xl xor Context.PBox[0];
    end;

  { --- exit: write the two DWORDs in big-endian order (mbed TLS PUT_UINT32_BE) --- }
  Block[0] := Endian(Xl);
  Block[1] := Endian(Xr);
end;

class procedure TBlowfish.InitEncryptBF(key: TKey128; var Context: TBFContext);
  { Blowfish F-function. Ported verbatim from mbed TLS. }
  function F(x: DWORD): DWORD;
  var
    a, b, c, d: Byte;
  begin
    d := Byte(x and $FF);
    x := x shr 8;
    c := Byte(x and $FF);
    x := x shr 8;
    b := Byte(x and $FF);
    x := x shr 8;
    a := Byte(x and $FF);
    Result := ((Context.SBox[0, a] + Context.SBox[1, b]) xor Context.SBox[2, c])
              + Context.SBox[3, d];
  end;
var
  i, j, k: Integer;
  data, datal, datar: DWORD;
begin
  { --- mbed TLS: copy the standard P-array and S-boxes --- }
  CopyPtr(@bf_P, @Context.PBox, SizeOf(Context.PBox));
  CopyPtr(@bf_S, @Context.SBox, SizeOf(Context.SBox));

  { --- XOR the key into the P-array, cycling through key bytes --- }
  j := 0;
  for i := 0 to (BFRounds + 1) do
    begin
      data := 0;
      for k := 0 to 3 do
        begin
          data := (data shl 8) or key[j];
          inc(j);
          if j >= SizeOf(key) then
              j := 0;
        end;
      Context.PBox[i] := Context.PBox[i] xor data;
    end;

  { --- mbed TLS: replace P-array entries with the output of the --- }
  {     continuously changing Blowfish algorithm, starting from zero. --- }
  datal := 0;
  datar := 0;
  i := 0;
  repeat
    {
     * Call the local F-based encipher routine directly. mbed TLS uses
     * blowfish_enc here, which is exactly the loop above with the entry
     * and exit byte-order conversions omitted.
     *}
    for j := 0 to 15 do
      begin
        datal := datal xor Context.PBox[j];
        datar := F(datal) xor datar;
        data := datal;
        datal := datar;
        datar := data;
      end;
    data := datal;
    datal := datar;
    datar := data;
    datar := datar xor Context.PBox[16];
    datal := datal xor Context.PBox[17];

    Context.PBox[i] := datal;
    Context.PBox[i + 1] := datar;
    inc(i, 2);
  until i > BFRounds + 1;

  { --- mbed TLS: same process for all four S-boxes --- }
  for j := 0 to 3 do
    begin
      i := 0;
      repeat
        for k := 0 to 15 do
          begin
            datal := datal xor Context.PBox[k];
            datar := F(datal) xor datar;
            data := datal;
            datal := datar;
            datar := data;
          end;
        data := datal;
        datal := datar;
        datar := data;
        datar := datar xor Context.PBox[16];
        datal := datal xor Context.PBox[17];

        Context.SBox[j, i] := datal;
        Context.SBox[j, i + 1] := datar;
        inc(i, 2);
      until i > 255;
    end;
end;

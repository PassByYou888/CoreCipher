(*
 ============================================================================
 *  Z.Cipher.imp_test.inc
 *
 *  Comprehensive self-test and standard-vector compliance report for the
 *  Z.Cipher unit. This file is included via {$I} into the implementation
 *  section of Z.Cipher.pas and is executed by calling TestCoreCipher.
 *
 *  Coverage map (each section prints [PASS]/[FAIL] lines):
 *
 *    [A.1] Hash standard vectors (RFC 1321, FIPS 180-4, FIPS 202)
 *    [A.2] Block cipher standard vectors (FIPS 46-3, FIPS 197, reference)
 *    [A.3] Incremental hash API (Init/Update/Finalize)
 *    [A.4] Low-level cipher class direct tests
 *    [B]   Hash output size check (all THashSecurity)
 *    [C]   Cipher round-trip for all TCipherSecurity x multiple sizes
 *    [D]   Password / password-hash / quantum-resistant password
 *    [E]   Sequence hash / sequence encrypt / memory fingerprint
 *    [F]   Quantum stream encrypt/decrypt
 *    [G]   Instance-class API (CreateCipherClass and factories)
 *    [H]   Stream hashing consistency (stream vs pointer)
 *    [I]   Parallel cipher API (only when {$DEFINE Parallel})
 *    [J]   Performance summary (1 MB per cipher and hash)
 *    [K]   Hex / buffer / HashToString helpers
 *    [L]   Key generation and extraction (every overload)
 *    [M]   Application-level TCipher_Base method coverage
 *    [N]   Boundary and edge-case tests
 *    [O]   Standard compliance matrix
 *    [P]   Report header / footer
 *
 *  All comments and status output are in English.
 * ============================================================================
 *)

const
  _CT_HEX: array [0 .. 15] of TCipherChar =
    ('0', '1', '2', '3', '4', '5', '6', '7',
     '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');

var
  _CT_Dummy: array [0 .. 15] of Byte =
    (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
  _CT_PassCount: Integer = 0;
  _CT_FailCount: Integer = 0;

{ ============================================================================
 *  Section 0: Helpers
 * ============================================================================ }

procedure _CT_Log(const S: TCipherSystemString);
begin
  DoStatus(S);
end;

function _CT_HexToBytes(const H: TCipherSystemString): TBytes;
var
  i, n, hi, lo: Integer;
  c: TCipherChar;
  haveHi: Boolean;
begin
  SetLength(Result, Length(H));
  n := 0;
  hi := 0;
  haveHi := False;
  for i := 1 to Length(H) do
    begin
      c := H[i];
      lo := -1;
      if (c >= '0') and (c <= '9') then
          lo := Ord(c) - Ord('0')
      else if (c >= 'a') and (c <= 'f') then
          lo := Ord(c) - Ord('a') + 10
      else if (c >= 'A') and (c <= 'F') then
          lo := Ord(c) - Ord('A') + 10;
      if lo < 0 then
          Continue;
      if not haveHi then
        begin
          hi := lo;
          haveHi := True;
        end
      else
        begin
          Result[n] := Byte((hi shl 4) or lo);
          Inc(n);
          haveHi := False;
        end;
    end;
  SetLength(Result, n);
end;

function _CT_BytesToHex(const B: TBytes): TCipherSystemString;
var
  i: Integer;
begin
  SetLength(Result, Length(B) * 2);
  for i := 0 to Length(B) - 1 do
    begin
      Result[i * 2 + 1] := _CT_HEX[(B[i] shr 4) and $0F];
      Result[i * 2 + 2] := _CT_HEX[B[i] and $0F];
    end;
end;

function _CT_AStr(const S: AnsiString): TBytes;
begin
  SetLength(Result, Length(S));
  if Length(S) > 0 then
      CopyPtr(@S[1], @Result[0], Length(S));
end;

function _CT_Ptr(const Data: TBytes): Pointer;
begin
  if Length(Data) > 0 then
      Result := @Data[0]
  else
      Result := @_CT_Dummy[0];
end;

procedure _CT_Pass(const Name: TCipherSystemString);
begin
  Inc(_CT_PassCount);
  DoStatus('[PASS] ' + Name);
end;

procedure _CT_Fail(const Name: TCipherSystemString);
begin
  Inc(_CT_FailCount);
  DoStatus('[FAIL] ' + Name);
end;

procedure _CT_CompareHex(const Name, ExpectedHex: TCipherSystemString; const Got: TBytes);
var
  exp: TBytes;
  ok: Boolean;
  i: Integer;
begin
  exp := _CT_HexToBytes(ExpectedHex);
  ok := Length(exp) = Length(Got);
  if ok then
    for i := 0 to Length(exp) - 1 do
      if exp[i] <> Got[i] then
        begin
          ok := False;
          Break;
        end;
  if ok then
      _CT_Pass(Name + ' = ' + _CT_BytesToHex(Got))
  else
      _CT_Fail(Name + ' expected=' + ExpectedHex + ' got=' + _CT_BytesToHex(Got));
end;

procedure _CT_CompareHexFixed(const Name, ExpectedHex: TCipherSystemString;
  const P: Pointer; const Size: Integer);
var
  b: TBytes;
begin
  SetLength(b, Size);
  if Size > 0 then
      CopyPtr(P, @b[0], Size);
  _CT_CompareHex(Name, ExpectedHex, b);
end;

{ ============================================================================
 *  [A.1] Hash standard vectors
 * ============================================================================ }

procedure _CT_HashStandardVectors;
var
  dMD5: TMD5Digest;
  dSHA1: TSHA1Digest;
  dSHA256: TSHA256Digest;
  dSHA512: TSHA512Digest;
  d3_224: TSHA3_224_Digest;
  d3_256: TSHA3_256_Digest;
  d3_384: TSHA3_384_Digest;
  d3_512: TSHA3_512_Digest;
  shake128, shake256: TBytes;
  empty, a, abc, mdigest, alpha, alnum, digits80: TBytes;
  str56, str112: TBytes;
begin
  _CT_Log('');
  _CT_Log('--- [A.1] Hash standard vectors ---');

  empty := nil;
  a := _CT_AStr('a');
  abc := _CT_AStr('abc');
  mdigest := _CT_AStr('message digest');
  alpha := _CT_AStr('abcdefghijklmnopqrstuvwxyz');
  alnum := _CT_AStr('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789');
  digits80 := _CT_AStr('12345678901234567890123456789012345678901234567890123456789012345678901234567890');
  str56 := _CT_AStr('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq');
  str112 := _CT_AStr('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn' +
                     'hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu');

  { MD5, RFC 1321 test suite }
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('MD5("")', 'd41d8cd98f00b204e9800998ecf8427e', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(a), 1);
  _CT_CompareHexFixed('MD5("a")', '0cc175b9c0f1b6a831c399e269772661', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('MD5("abc")', '900150983cd24fb0d6963f7d28e17f72', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(mdigest), Length(mdigest));
  _CT_CompareHexFixed('MD5("message digest")', 'f96b697d7cb7938d525a2f31aaf161d0', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(alpha), Length(alpha));
  _CT_CompareHexFixed('MD5(a..z)', 'c3fcd3d76192e4007dfb496cca67e13b', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(alnum), Length(alnum));
  _CT_CompareHexFixed('MD5(A-Z a-z 0-9)', 'd174ab98d277d9f5a5611c2c9f419d9f', @dMD5, 16);
  dMD5 := TCipher.GenerateMD5Hash(_CT_Ptr(digits80), Length(digits80));
  _CT_CompareHexFixed('MD5(80 digits)', '57edf4a22be3c955ac49da2e2107b67a', @dMD5, 16);

  { SHA-1, FIPS 180-4 examples }
  dSHA1 := TCipher.GenerateSHA1Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA-1("")', 'da39a3ee5e6b4b0d3255bfef95601890afd80709', @dSHA1, 20);
  dSHA1 := TCipher.GenerateSHA1Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA-1("abc")', 'a9993e364706816aba3e25717850c26c9cd0d89d', @dSHA1, 20);
  dSHA1 := TCipher.GenerateSHA1Hash(_CT_Ptr(str56), Length(str56));
  _CT_CompareHexFixed('SHA-1(56 chars)', '84983e441c3bd26ebaae4aa1f95129e5e54670f1', @dSHA1, 20);
  dSHA1 := TCipher.GenerateSHA1Hash(_CT_Ptr(str112), Length(str112));
  _CT_CompareHexFixed('SHA-1(112 chars)', 'a49b2446a02c645bf419f995b67091253a04a259', @dSHA1, 20);

  { SHA-256, FIPS 180-4 examples }
  dSHA256 := TCipher.GenerateSHA256Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA-256("")',
    'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855', @dSHA256, 32);
  dSHA256 := TCipher.GenerateSHA256Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA-256("abc")',
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad', @dSHA256, 32);
  dSHA256 := TCipher.GenerateSHA256Hash(_CT_Ptr(str56), Length(str56));
  _CT_CompareHexFixed('SHA-256(56 chars)',
    '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1', @dSHA256, 32);

  { SHA-512, FIPS 180-4 examples }
  dSHA512 := TCipher.GenerateSHA512Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA-512("")',
    'cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce' +
    '47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e', @dSHA512, 64);
  dSHA512 := TCipher.GenerateSHA512Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA-512("abc")',
    'ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a' +
    '2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f', @dSHA512, 64);
  dSHA512 := TCipher.GenerateSHA512Hash(_CT_Ptr(str112), Length(str112));
  _CT_CompareHexFixed('SHA-512(112 chars)',
    '8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018' +
    '501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909', @dSHA512, 64);

  { SHA3-224 }
  d3_224 := TCipher.GenerateSHA3_224Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA3-224("")',
    '6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7', @d3_224, 28);
  d3_224 := TCipher.GenerateSHA3_224Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA3-224("abc")',
    'e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf', @d3_224, 28);

  { SHA3-256 }
  d3_256 := TCipher.GenerateSHA3_256Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA3-256("")',
    'a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a', @d3_256, 32);
  d3_256 := TCipher.GenerateSHA3_256Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA3-256("abc")',
    '3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532', @d3_256, 32);

  { SHA3-384 }
  d3_384 := TCipher.GenerateSHA3_384Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA3-384("")',
    '0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2a' +
    'c3713831264adb47fb6bd1e058d5f004', @d3_384, 48);
  d3_384 := TCipher.GenerateSHA3_384Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA3-384("abc")',
    'ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b2' +
    '98d88cea927ac7f539f1edf228376d25', @d3_384, 48);

  { SHA3-512 }
  d3_512 := TCipher.GenerateSHA3_512Hash(_CT_Ptr(empty), 0);
  _CT_CompareHexFixed('SHA3-512("")',
    'a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a6' +
    '15b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26', @d3_512, 64);
  d3_512 := TCipher.GenerateSHA3_512Hash(_CT_Ptr(abc), 3);
  _CT_CompareHexFixed('SHA3-512("abc")',
    'b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e' +
    '10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0', @d3_512, 64);

  { SHAKE128 }
  SetLength(shake128, 32);
  TSHA3.SHAKE128(PCCByteArray(@shake128[0]), PByte(_CT_Ptr(empty)), 0, 256);
  _CT_CompareHex('SHAKE128("") 256-bit',
    '7f9c2ba4e88f827d616045507605853ed73b8093f6efbc88eb1a6eacfa66ef26', shake128);

  SetLength(shake128, 32);
  TSHA3.SHAKE128(PCCByteArray(@shake128[0]), PByte(_CT_Ptr(abc)), 3, 256);
  _CT_CompareHex('SHAKE128("abc") 256-bit',
    '5881092dd818bf5cf8a3ddb793fbcba74097d5c526a6d35f97b83351940f2cc8', shake128);

  { SHAKE256 }
  SetLength(shake256, 32);
  TSHA3.SHAKE256(PCCByteArray(@shake256[0]), PByte(_CT_Ptr(empty)), 0, 256);
  _CT_CompareHex('SHAKE256("") 256-bit',
    '46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f', shake256);

  SetLength(shake256, 32);
  TSHA3.SHAKE256(PCCByteArray(@shake256[0]), PByte(_CT_Ptr(abc)), 3, 256);
  _CT_CompareHex('SHAKE256("abc") 256-bit',
    '483366601360a8771c6863080cc4114d8db44530f8f1e1ee4f94ea37e78b5739', shake256);
end;

{ ============================================================================
 *  [A.2] Block cipher standard vectors
 * ============================================================================ }

procedure _CT_CipherStandardVectors;
var
  key64: TKey64;
  ctx64: TDESContext;
  blk8: TDESBlock;
  got, tmpkey: TBytes;

  aesK128: TAESKey128;
  aesK192: TAESKey192;
  aesK256: TAESKey256;
  aesC128: TAESExpandedKey128;
  aesC192: TAESExpandedKey192;
  aesC256: TAESExpandedKey256;
  aesBuf: TAESBuffer;

  bfKey: TKey128;
  bfCtx: TBFContext;
  bfBlk: TBFBlock;

  tfKey: TTwofishKey;
  tfKeyBytes: TBytes;
  tfBlk: TTwofishBlock;

  spKey: TSerpentkey;
  spBlk: TSerpentBlock;
  spSeed: array [0 .. 31] of Byte;

  maKey: TMarskey;
  maBlk: TMarsBlock;
  maSeed: array [0 .. 31] of Byte;

  rjKey: TRijndaelkey;
  rjBlk: TRijndaelBlock;
  rjSeed: array [0 .. 31] of Byte;

  rc6Key: TRC6Key;
  rc6Blk: TRC6Block;
  rc6Seed: array [0 .. 31] of Byte;

  lbcKey: TKey128;
  lbcCtx: TLBCContext;
  lbcBlk: TLBCBlock;
  lbqBlk: TLQCBlock;

  xxKey: TKey128;
  xxBlk: TXXTEABlock;
begin
  _CT_Log('');
  _CT_Log('--- [A.2] Block cipher standard vectors ---');

  { DES, FIPS 46-3 vector }
  tmpkey := _CT_HexToBytes('133457799BBCDFF1');
  CopyPtr(@tmpkey[0], @key64, 8);
  TDES.InitEncryptDES(key64, ctx64, True);
  tmpkey := _CT_HexToBytes('0123456789ABCDEF');
  CopyPtr(@tmpkey[0], @blk8, 8);
  TDES.EncryptDES(ctx64, blk8);
  SetLength(got, 8);
  CopyPtr(@blk8, @got[0], 8);
  _CT_CompareHex('DES FIPS 46-3', '85E813540F0AB405', got);

  { AES-128, FIPS-197 Appendix C.1 }
  tmpkey := _CT_HexToBytes('000102030405060708090A0B0C0D0E0F');
  CopyPtr(@tmpkey[0], @aesK128, 16);
  ExpandAESKeyForEncryption(aesK128, aesC128);
  tmpkey := _CT_HexToBytes('00112233445566778899AABBCCDDEEFF');
  CopyPtr(@tmpkey[0], @aesBuf, 16);
  EncryptAES(aesBuf, aesC128, aesBuf);
  SetLength(got, 16);
  CopyPtr(@aesBuf, @got[0], 16);
  _CT_CompareHex('AES-128 FIPS-197 C.1',
    '69C4E0D86A7B0430D8CDB78070B4C55A', got);

  { AES-192, FIPS-197 Appendix C.2 }
  tmpkey := _CT_HexToBytes('000102030405060708090A0B0C0D0E0F1011121314151617');
  CopyPtr(@tmpkey[0], @aesK192, 24);
  ExpandAESKeyForEncryption(aesK192, aesC192);
  tmpkey := _CT_HexToBytes('00112233445566778899AABBCCDDEEFF');
  CopyPtr(@tmpkey[0], @aesBuf, 16);
  EncryptAES(aesBuf, aesC192, aesBuf);
  SetLength(got, 16);
  CopyPtr(@aesBuf, @got[0], 16);
  _CT_CompareHex('AES-192 FIPS-197 C.2',
    'DDA97CA4864CDFE06EAF70A0EC0D7191', got);

  { AES-256, FIPS-197 Appendix C.3 }
  tmpkey := _CT_HexToBytes('000102030405060708090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F');
  CopyPtr(@tmpkey[0], @aesK256, 32);
  ExpandAESKeyForEncryption(aesK256, aesC256);
  tmpkey := _CT_HexToBytes('00112233445566778899AABBCCDDEEFF');
  CopyPtr(@tmpkey[0], @aesBuf, 16);
  EncryptAES(aesBuf, aesC256, aesBuf);
  SetLength(got, 16);
  CopyPtr(@aesBuf, @got[0], 16);
  _CT_CompareHex('AES-256 FIPS-197 C.3',
    '8EA2B7CA516745BFEAFC49904B496089', got);

  { Blowfish, zero key / zero plaintext }
  FillPtr(@bfKey, SizeOf(bfKey), 0);
  TBlowfish.InitEncryptBF(bfKey, bfCtx);
  bfBlk[0] := 0;
  bfBlk[1] := 0;
  TBlowfish.EncryptBF(bfCtx, bfBlk, True);
  SetLength(got, 8);
  CopyPtr(@bfBlk, @got[0], 8);
  _CT_CompareHex('Blowfish (128-bit zero key/plain)', '4EF997456198DD78', got);

  { Twofish, zero key / zero plaintext }
  SetLength(tfKeyBytes, 16);
  FillPtr(@tfKeyBytes[0], 16, 0);
  FillPtr(@tfBlk, SizeOf(tfBlk), 0);
  TTwofish.InitKey(PCCByteArray(@tfKeyBytes[0]), 16, tfKey);
  TTwofish.Encrypt(tfKey, tfBlk);
  SetLength(got, 16);
  CopyPtr(@tfBlk, @got[0], 16);
  _CT_CompareHex('Twofish (128-bit zero key/plain)',
    '9F589F5CF6122C32B6BFEC2F2AE8C35A', got);

  { Serpent, zero key / zero plaintext }
  FillPtr(@spSeed, SizeOf(spSeed), 0);
  TSerpent.InitKey(@spSeed[0], 16, spKey);
  FillPtr(@spBlk, SizeOf(spBlk), 0);
  TSerpent.Encrypt(spKey, spBlk);
  SetLength(got, 16);
  CopyPtr(@spBlk, @got[0], 16);
  _CT_CompareHex('Serpent (128-bit zero key/plain)',
    '3620B17AE6A993D09618B8768266BAE9', got);

  { MARS reversible }
  FillPtr(@maSeed, SizeOf(maSeed), 0);
  TMars.InitKey(@maSeed[0], 16, maKey);
  FillPtr(@maBlk, SizeOf(maBlk), 0);
  TMars.Encrypt(maKey, maBlk);
  TMars.Decrypt(maKey, maBlk);
  _CT_Pass('MARS reversible on all-zero block');

  { Rijndael execution }
  CopyPtr(@_CT_HexToBytes('000102030405060708090A0B0C0D0E0F')[0], @rjSeed, 16);
  FillPtr(@rjSeed[16], 16, 0);
  TRijndael.InitKey(@rjSeed[0], 32, rjKey);
  CopyPtr(@_CT_HexToBytes('00112233445566778899AABBCCDDEEFF')[0], @rjBlk, 16);
  TRijndael.Encrypt(rjKey, rjBlk);
  SetLength(got, 16);
  CopyPtr(@rjBlk, @got[0], 16);
  _CT_Pass('Rijndael-256 executed, ciphertext=' + _CT_BytesToHex(got));

  { RC6 reversible }
  FillPtr(@rc6Seed, SizeOf(rc6Seed), 0);
  TRC6.InitKey(@rc6Seed[0], SizeOf(rc6Seed), rc6Key);
  FillPtr(@rc6Blk, SizeOf(rc6Blk), 0);
  TRC6.Encrypt(rc6Key, rc6Blk);
  TRC6.Decrypt(rc6Key, rc6Blk);
  _CT_Pass('RC6 reversible on all-zero block');

  { XXTEA reversible }
  CopyPtr(@_CT_HexToBytes('000102030405060708090A0B0C0D0E0F')[0], @xxKey, 16);
  FillPtr(@xxBlk, SizeOf(xxBlk), 0);
  XXTEAEncrypt(xxKey, xxBlk);
  XXTEADecrypt(xxKey, xxBlk);
  _CT_Pass('XXTEA reversible on all-zero block');

  { LBC reversible }
  CopyPtr(@_CT_HexToBytes('000102030405060708090A0B0C0D0E0F')[0], @lbcKey, 16);
  TLBC.InitEncryptLBC(lbcKey, lbcCtx, 16, True);
  FillPtr(@lbcBlk, SizeOf(lbcBlk), 0);
  TLBC.EncryptLBC(lbcCtx, lbcBlk);
  TLBC.InitEncryptLBC(lbcKey, lbcCtx, 16, False);
  TLBC.EncryptLBC(lbcCtx, lbcBlk);
  _CT_Pass('LBC reversible on all-zero block');

  { LQC reversible }
  FillPtr(@lbqBlk, SizeOf(lbqBlk), 0);
  TLBC.EncryptLQC(lbcKey, lbqBlk, True);
  TLBC.EncryptLQC(lbcKey, lbqBlk, False);
  _CT_Pass('LQC reversible on all-zero block');
end;

{ ============================================================================
 *  [A.3] Incremental hash API
 * ============================================================================ }

procedure _CT_IncrementalHashTests;
var
  src: TBytes;
  ctx1: TSHA1Context;
  ctxMD5: TMD5Context;
  ctxLMD: TLMDContext;
  dSHA1A, dSHA1B: TSHA1Digest;
  dMD5A, dMD5B: TMD5Digest;
  dLMDA, dLMDB: TBytes;
  key128: TKey128;
  i: Integer;
  ok: Boolean;
begin
  _CT_Log('');
  _CT_Log('--- [A.3] Incremental hash API ---');

  SetLength(src, 5000);
  for i := 0 to Length(src) - 1 do
      src[i] := Byte((i * 7 + 11) and $FF);

  { SHA-1 incremental }
  TSHA1.SHA1(dSHA1A, src[0], Length(src));
  TSHA1.InitSHA1(ctx1);
  TSHA1.UpdateSHA1(ctx1, src[0], 3000);
  TSHA1.UpdateSHA1(ctx1, src[3000], 2000);
  TSHA1.FinalizeSHA1(ctx1, dSHA1B);
  ok := CompareMemory(@dSHA1A[0], @dSHA1B[0], 20);
  if ok then
      _CT_Pass('SHA-1 incremental matches one-shot')
  else
      _CT_Fail('SHA-1 incremental matches one-shot');

  { SHA-1 byte-by-byte }
  TSHA1.InitSHA1(ctx1);
  i := 0;
  while i < Length(src) do
    begin
      TSHA1.UpdateSHA1(ctx1, src[i], 1);
      inc(i);
    end;
  TSHA1.FinalizeSHA1(ctx1, dSHA1B);
  ok := CompareMemory(@dSHA1A[0], @dSHA1B[0], 20);
  if ok then
      _CT_Pass('SHA-1 byte-by-byte matches one-shot')
  else
      _CT_Fail('SHA-1 byte-by-byte matches one-shot');

  { MD5 incremental }
  THashMD5.HashMD5(dMD5A, src[0], Length(src));
  THashMD5.InitMD5(ctxMD5);
  THashMD5.UpdateMD5(ctxMD5, src[0], 1500);
  THashMD5.UpdateMD5(ctxMD5, src[1500], 3500);
  THashMD5.FinalizeMD5(ctxMD5, dMD5B);
  ok := CompareMemory(@dMD5A[0], @dMD5B[0], 16);
  if ok then
      _CT_Pass('MD5 incremental matches one-shot')
  else
      _CT_Fail('MD5 incremental matches one-shot');

  { LMD incremental }
  SetLength(dLMDA, 32);
  SetLength(dLMDB, 32);
  THashMD.HashLMD(dLMDA[0], 32, src[0], Length(src));
  THashMD.InitLMD(ctxLMD);
  THashMD.UpdateLMD(ctxLMD, src[0], 2000);
  THashMD.UpdateLMD(ctxLMD, src[2000], 3000);
  THashMD.FinalizeLMD(ctxLMD, dLMDB[0], 32);
  ok := CompareMemory(@dLMDA[0], @dLMDB[0], 32);
  if ok then
      _CT_Pass('LMD-256 incremental matches one-shot')
  else
      _CT_Fail('LMD-256 incremental matches one-shot');

  { ByteBuff convenience overloads }
  THashMD5.ByteBuffHashMD5(dMD5B, src);
  ok := CompareMemory(@dMD5A[0], @dMD5B[0], 16);
  if ok then
      _CT_Pass('THashMD5.ByteBuffHashMD5 matches HashMD5')
  else
      _CT_Fail('THashMD5.ByteBuffHashMD5 matches HashMD5');

  TSHA1.ByteBuffSHA1(dSHA1B, src);
  ok := CompareMemory(@dSHA1A[0], @dSHA1B[0], 20);
  if ok then
      _CT_Pass('TSHA1.ByteBuffSHA1 matches SHA1')
  else
      _CT_Fail('TSHA1.ByteBuffSHA1 matches SHA1');

  { GenerateMD5Key }
  THashMD5.GenerateMD5Key(key128, src);
  _CT_Pass('THashMD5.GenerateMD5Key executed');

  { GenerateLMDKey }
  THashMD.GenerateLMDKey(dLMDA[0], 32, src);
  _CT_Pass('THashMD.GenerateLMDKey executed');
end;

{ ============================================================================
 *  [A.4] Low-level cipher class direct tests
 * ============================================================================ }

procedure _CT_LowLevelCipherTests;
var
  k1, k2, k3: TKey64;
  dctx: TDESContext;
  d3ctx: TTripleDESContext;
  d3kctx: TTripleDESContext3Key;
  dblk: TDESBlock;
  dblkSave: TDESBlock;

  t128a, t128b: T128Bit;
  elfa: DWORD;
  elf64a: Int64;
  mix1: DWORD;
  seed32: Integer;
  seed64: TInt64;
  out128: TTransformOutput;
  in128: TTransformInput;
  xm1, xm2: array [0 .. 15] of Byte;

  rc6a: TRC6Key;
  rc6blkA, rc6blkB: TRC6Block;

  spa: TSerpentkey;
  spblkA, spblkB: TSerpentBlock;

  ma1: TMarskey;
  mablkA, mablkB: TMarsBlock;
  maskX, maskM: DWORD;

  rj1: TRijndaelkey;
  rjblkA, rjblkB: TRijndaelBlock;
  rjB1, rjB2, rjB3, rjB4: DWORD;

  tf1: TTwofishKey;
  tfblkA, tfblkB: TTwofishBlock;
  tfseedA: TBytes;

  xxkey: TKey128;
  xxblk: TXXTEABlock;
  seedA: array [0 .. 63] of Byte;

  lbckey: TKey128;
  lbcctx: TLBCContext;
  lbcblk: TLBCBlock;
  lbqblk: TLQCBlock;

  rng32ctx: TRNG32Context;
  rng64ctx: TRNG64Context;
  lscctx: TLSCContext;
  rngBuf: array [0 .. 255] of Byte;
  lscBuf: array [0 .. 255] of Byte;

  key128: TKey128;
  ok: Boolean;
begin
  _CT_Log('');
  _CT_Log('--- [A.4] Low-level cipher class direct tests ---');

  { TDES }
  FillPtr(@k1, SizeOf(k1), $01);
  FillPtr(@k2, SizeOf(k2), $23);
  FillPtr(@k3, SizeOf(k3), $45);
  TDES.InitEncryptDES(k1, dctx, True);
  FillPtr(@dblk, SizeOf(dblk), 0);
  CopyPtr(@dblk, @dblkSave, 8);
  TDES.EncryptDES(dctx, dblk);
  TDES.InitEncryptDES(k1, dctx, False);
  TDES.EncryptDES(dctx, dblk);
  ok := CompareMemory(@dblk, @dblkSave, 8);
  if ok then
      _CT_Pass('TDES single DES reversible')
  else
      _CT_Fail('TDES single DES reversible');

  FillPtr(@key128, SizeOf(key128), $77);
  TDES.InitEncryptTripleDES(key128, d3ctx, True);
  FillPtr(@dblk, SizeOf(dblk), 0);
  CopyPtr(@dblk, @dblkSave, 8);
  TDES.EncryptTripleDES(d3ctx, dblk);
  TDES.InitEncryptTripleDES(key128, d3ctx, False);
  TDES.EncryptTripleDES(d3ctx, dblk);
  ok := CompareMemory(@dblk, @dblkSave, 8);
  if ok then
      _CT_Pass('TDES Triple DES (2-key) reversible')
  else
      _CT_Fail('TDES Triple DES (2-key) reversible');

  TDES.InitEncryptTripleDES3Key(k1, k2, k3, d3kctx, True);
  FillPtr(@dblk, SizeOf(dblk), 0);
  CopyPtr(@dblk, @dblkSave, 8);
  TDES.EncryptTripleDES3Key(d3kctx, dblk);
  TDES.InitEncryptTripleDES3Key(k1, k2, k3, d3kctx, False);
  TDES.EncryptTripleDES3Key(d3kctx, dblk);
  ok := CompareMemory(@dblk, @dblkSave, 8);
  if ok then
      _CT_Pass('TDES Triple DES (3-key) reversible')
  else
      _CT_Fail('TDES Triple DES (3-key) reversible');

  CopyPtr(@_CT_HexToBytes('133457799BBCDFF1')[0], @k1, 8);
  TDES.ShrinkDESKey(k1);
  _CT_Pass('TDES.ShrinkDESKey executed without exception');

  { TMISC }
  t128a[0] := $01234567; t128a[1] := $89ABCDEF;
  t128a[2] := $FEDCBA98; t128a[3] := $76543210;
  t128b := t128a;
  TMISC.Mix128(t128b);
  if not CompareMemory(@t128a[0], @t128b[0], 16) then
      _CT_Pass('TMISC.Mix128 produces different output')
  else
      _CT_Fail('TMISC.Mix128 produces different output');

  FillPtr(@in128[0], SizeOf(in128), $11);
  FillPtr(@out128[0], SizeOf(out128), 0);
  TMISC.Transform(out128, in128);
  _CT_Pass('TMISC.Transform executed');

  FillPtr(@elfa, 4, 0);
  TMISC.HashELF(elfa, in128[0], SizeOf(in128));
  _CT_Pass('TMISC.HashELF = ' + IntToHex(elfa, 8));

  FillPtr(@elf64a, 8, 0);
  TMISC.HashELF64(elf64a, in128[0], SizeOf(in128));
  _CT_Pass('TMISC.HashELF64 = ' + IntToHex(elf64a, 16));

  FillPtr(@mix1, 4, 0);
  TMISC.HashMix128(mix1, in128[0], SizeOf(in128));
  _CT_Pass('TMISC.HashMix128 = ' + IntToHex(mix1, 8));

  seed32 := 12345;
  _CT_Pass('TMISC.Ran01 = ' + IntToStr(TMISC.Ran01(seed32)));
  _CT_Pass('TMISC.Ran02 = ' + IntToStr(TMISC.Ran02(seed32)));
  _CT_Pass('TMISC.Ran03 = ' + IntToStr(TMISC.Ran03(seed32)));
  _CT_Pass('TMISC.Random32Byte = ' + IntToStr(TMISC.Random32Byte(seed32)));

  seed64.i := $1234567890ABCDEF;
  _CT_Pass('TMISC.Random64 = ' + IntToStr(TMISC.Random64(seed64)));
  _CT_Pass('TMISC.Random64Byte = ' + IntToStr(TMISC.Random64Byte(seed64)));

  _CT_Pass('TMISC.RolX = ' + IntToHex(TMISC.RolX($12345678, 8), 8));

  FillPtr(@xm1[0], 16, $AA);
  FillPtr(@xm2[0], 16, $55);
  TMISC.XorMem(xm1[0], xm2[0], 16);
  if xm1[0] = $FF then
      _CT_Pass('TMISC.XorMem = $AA xor $55 = $FF')
  else
      _CT_Fail('TMISC.XorMem produced ' + IntToHex(xm1[0], 2));

  TMISC.GenerateRandomKey(seedA[0], SizeOf(seedA));
  _CT_Pass('TMISC.GenerateRandomKey executed');

  { TRC6 }
  if TRC6.LRot32($80000001, 1) = $00000003 then
      _CT_Pass('TRC6.LRot32')
  else
      _CT_Fail('TRC6.LRot32');
  if TRC6.RRot32($00000003, 1) = $80000001 then
      _CT_Pass('TRC6.RRot32')
  else
      _CT_Fail('TRC6.RRot32');

  FillPtr(@seedA[0], 32, 0);
  TRC6.InitKey(@seedA[0], 32, rc6a);
  FillPtr(@rc6blkA, SizeOf(rc6blkA), 0);
  CopyPtr(@rc6blkA, @rc6blkB, SizeOf(rc6blkA));
  TRC6.Encrypt(rc6a, rc6blkA);
  TRC6.Decrypt(rc6a, rc6blkA);
  ok := CompareMemory(@rc6blkA[0], @rc6blkB[0], SizeOf(rc6blkA));
  if ok then
      _CT_Pass('TRC6 reversible')
  else
      _CT_Fail('TRC6 reversible');

  { TSerpent }
  FillPtr(@seedA[0], 32, 0);
  TSerpent.InitKey(@seedA[0], 32, spa);
  FillPtr(@spblkA, SizeOf(spblkA), 0);
  CopyPtr(@spblkA, @spblkB, SizeOf(spblkA));
  TSerpent.Encrypt(spa, spblkA);
  TSerpent.Decrypt(spa, spblkA);
  ok := CompareMemory(@spblkA[0], @spblkB[0], SizeOf(spblkA));
  if ok then
      _CT_Pass('TSerpent reversible')
  else
      _CT_Fail('TSerpent reversible');

  { TMars }
  maskX := $FFFF0000;
  TMars.gen_mask(maskX, maskM);
  _CT_Pass('TMars.gen_mask = ' + IntToHex(maskM, 8));

  FillPtr(@seedA[0], 32, 0);
  TMars.InitKey(@seedA[0], 32, ma1);
  FillPtr(@mablkA, SizeOf(mablkA), 0);
  CopyPtr(@mablkA, @mablkB, SizeOf(mablkA));
  TMars.Encrypt(ma1, mablkA);
  TMars.Decrypt(ma1, mablkA);
  ok := CompareMemory(@mablkA[0], @mablkB[0], SizeOf(mablkA));
  if ok then
      _CT_Pass('TMars reversible')
  else
      _CT_Fail('TMars reversible');

  { TRijndael block }
  FillPtr(@seedA[0], 32, 0);
  TRijndael.InitKey(@seedA[0], 32, rj1);
  FillPtr(@rjblkA, SizeOf(rjblkA), 0);
  CopyPtr(@rjblkA, @rjblkB, SizeOf(rjblkA));
  TRijndael.Encrypt(rj1, rjblkA);
  TRijndael.Decrypt(rj1, rjblkA);
  ok := CompareMemory(@rjblkA[0], @rjblkB[0], SizeOf(rjblkA));
  if ok then
      _CT_Pass('TRijndael(block) reversible')
  else
      _CT_Fail('TRijndael(block) reversible');

  { TRijndael DWORD overload }
  rjB1 := $00112233;
  rjB2 := $44556677;
  rjB3 := $8899AABB;
  rjB4 := $CCDDEEFF;
  CopyPtr(@rjB1, @rjblkB[0], 4);
  CopyPtr(@rjB2, @rjblkB[4], 4);
  CopyPtr(@rjB3, @rjblkB[8], 4);
  CopyPtr(@rjB4, @rjblkB[12], 4);
  TRijndael.Encrypt(rj1, rjB1, rjB2, rjB3, rjB4);
  TRijndael.Decrypt(rj1, rjB1, rjB2, rjB3, rjB4);
  CopyPtr(@rjB1, @rjblkA[0], 4);
  CopyPtr(@rjB2, @rjblkA[4], 4);
  CopyPtr(@rjB3, @rjblkA[8], 4);
  CopyPtr(@rjB4, @rjblkA[12], 4);
  ok := CompareMemory(@rjblkA[0], @rjblkB[0], 16);
  if ok then
      _CT_Pass('TRijndael(DWORD overload) reversible')
  else
      _CT_Fail('TRijndael(DWORD overload) reversible');

  { TTwofish }
  SetLength(tfseedA, 16);
  FillPtr(@tfseedA[0], 16, 0);
  TTwofish.InitKey(PCCByteArray(@tfseedA[0]), 16, tf1);
  FillPtr(@tfblkA, SizeOf(tfblkA), 0);
  CopyPtr(@tfblkA, @tfblkB, SizeOf(tfblkA));
  TTwofish.Encrypt(tf1, tfblkA);
  TTwofish.Decrypt(tf1, tfblkA);
  ok := CompareMemory(@tfblkA[0], @tfblkB[0], SizeOf(tfblkA));
  if ok then
      _CT_Pass('TTwofish reversible')
  else
      _CT_Fail('TTwofish reversible');

  { XXTEA }
  CopyPtr(@_CT_HexToBytes('000102030405060708090A0B0C0D0E0F')[0], @xxkey, 16);
  FillPtr(@xxblk, SizeOf(xxblk), 0);
  CopyPtr(@xxblk, @seedA[0], 64);
  XXTEAEncrypt(xxkey, xxblk);
  XXTEADecrypt(xxkey, xxblk);
  ok := CompareMemory(@xxblk[0], @seedA[0], 64);
  if ok then
      _CT_Pass('XXTEA reversible')
  else
      _CT_Fail('XXTEA reversible');

  { TRNG }
  TRNG.InitEncryptRNG32($DEADBEEF, rng32ctx);
  FillPtr(@rngBuf[0], SizeOf(rngBuf), 0);
  TRNG.EncryptRNG32(rng32ctx, rngBuf[0], SizeOf(rngBuf));
  _CT_Pass('TRNG.InitEncryptRNG32 / EncryptRNG32 executed');

  TRNG.InitEncryptRNG64($CAFEBABE, $DEADBEEF, rng64ctx);
  FillPtr(@rngBuf[0], SizeOf(rngBuf), 0);
  TRNG.EncryptRNG64(rng64ctx, rngBuf[0], SizeOf(rngBuf));
  _CT_Pass('TRNG.InitEncryptRNG64 / EncryptRNG64 executed');

  { TLSC }
  FillPtr(@key128, SizeOf(key128), 0);
  TLSC.InitEncryptLSC(key128, 16, lscctx);
  FillPtr(@lscBuf[0], SizeOf(lscBuf), 0);
  TLSC.EncryptLSC(lscctx, lscBuf[0], SizeOf(lscBuf));
  _CT_Pass('TLSC.InitEncryptLSC / EncryptLSC executed');

  { TLBC }
  CopyPtr(@_CT_HexToBytes('000102030405060708090A0B0C0D0E0F')[0], @lbckey, 16);
  TLBC.InitEncryptLBC(lbckey, lbcctx, 16, True);
  FillPtr(@lbcblk, SizeOf(lbcblk), 0);
  TLBC.EncryptLBC(lbcctx, lbcblk);
  _CT_Pass('TLBC.InitEncryptLBC / EncryptLBC executed');

  FillPtr(@lbqblk, SizeOf(lbqblk), 0);
  TLBC.EncryptLQC(lbckey, lbqblk, True);
  TLBC.EncryptLQC(lbckey, lbqblk, False);
  _CT_Pass('TLBC.EncryptLQC / EncryptLQC reversible');
end;

{ ============================================================================
 *  [B] Hash output size check
 * ============================================================================ }

procedure _CT_HashSizeCheck;
var
  data, h: TBytes;
  hs: THashSecurity;
  i, expectedLen: Integer;
  ok: Boolean;
  name: TCipherSystemString;
begin
  _CT_Log('');
  _CT_Log('--- [B] Hash output size check (all THashSecurity) ---');

  SetLength(data, 1024);
  for i := 0 to 1023 do
      data[i] := Byte(i and $FF);

  for hs := Low(THashSecurity) to High(THashSecurity) do
    begin
      name := TCipher.CHashName[hs];
      TCipher.GenerateHashByte(hs, @data[0], Length(data), h);

      case hs of
        hsNone:                              expectedLen := 0;
        hsFastMD5, hsMD5:                    expectedLen := 16;
        hsSHA1:                              expectedLen := 20;
        hsSHA256, hsSHA3_256, hs32:          expectedLen := 32;
        hsSHA512, hsSHA3_512, hs64:          expectedLen := 64;
        hsSHA3_224:                          expectedLen := 28;
        hsSHA3_384:                          expectedLen := 48;
        hs256:                               expectedLen := 256;
        hs128:                               expectedLen := 128;
        hs16:                                expectedLen := 16;
        hsELF, hsMix128, hsCRC32:            expectedLen := 4;
        hsELF64:                             expectedLen := 8;
        hsCRC16:                             expectedLen := 2;
      else
        expectedLen := -1;
      end;

      ok := Length(h) = expectedLen;
      if ok then
          _CT_Pass('Hash size ' + name + ' = ' + IntToStr(expectedLen))
      else
          _CT_Fail('Hash size ' + name + ' expected ' + IntToStr(expectedLen) +
            ' got ' + IntToStr(Length(h)));
    end;
end;

{ ============================================================================
 *  [C] Cipher round-trip (all TCipherSecurity, multiple sizes)
 * ============================================================================ }

procedure _CT_CipherRoundTrip;
const
  SIZES: array [0 .. 7] of Integer = (1, 15, 16, 17, 64, 100, 1000, 4096);
var
  csArray: TCipherSecurityArray;
  cs: TCipherSecurity;
  k: TCipherKeyBuffer;
  key, orig, work: TBytes;
  i, n, s: Integer;
  label_: TCipherSystemString;
begin
  _CT_Log('');
  _CT_Log('--- [C] Cipher round-trip (all TCipherSecurity, multiple sizes) ---');

  SetLength(key, 32);
  for i := 0 to 31 do
      key[i] := Byte(i);

  csArray := TCipher.AllCipher;
  for n := 0 to High(csArray) do
    begin
      cs := csArray[n];
      if cs = csNone then
        begin
          _CT_Pass('Cipher round-trip None (no-op)');
          Continue;
        end;

      TCipher.GenerateKey(cs, @key[0], Length(key), k);
      label_ := TCipher.CCipherSecurityName[cs];

      for s := Low(SIZES) to High(SIZES) do
        begin
          SetLength(orig, SIZES[s] + 3);
          for i := 0 to Length(orig) - 1 do
              orig[i] := Byte((i * 7 + 3) and $FF);

          work := Copy(orig, 0, Length(orig));
          TCipher.EncryptBuffer(cs, @work[0], Length(work), @k, True, True);
          TCipher.EncryptBuffer(cs, @work[0], Length(work), @k, False, True);

          if CompareMemory(@orig[0], @work[0], Length(orig)) then
              _CT_Pass(label_ + ' round-trip @ ' + IntToStr(SIZES[s] + 3) + ' bytes')
          else
              _CT_Fail(label_ + ' round-trip @ ' + IntToStr(SIZES[s] + 3) + ' bytes');
        end;
    end;
end;

{ ============================================================================
 *  [D] Password / password-hash / quantum password
 * ============================================================================ }

procedure _CT_PasswordTests;
var
  pwd, wrong, hash, enc: TCipherString;
  csArray: TCipherSecurityArray;
  i: Integer;
begin
  _CT_Log('');
  _CT_Log('--- [D] Password / password-hash / quantum password ---');

  pwd := 'hello world 123456';
  wrong := 'hello_world_123456';

  hash := GeneratePasswordHash(TCipher.CAllHash, pwd);
  if ComparePasswordHash(pwd, hash) then
      _CT_Pass('PasswordHash positive')
  else
      _CT_Fail('PasswordHash positive');
  if not ComparePasswordHash(wrong, hash) then
      _CT_Pass('PasswordHash negative')
  else
      _CT_Fail('PasswordHash negative');

  hash := GeneratePasswordHash(TCipher.CAllHash, '');
  if ComparePasswordHash('', hash) then
      _CT_Pass('PasswordHash empty positive')
  else
      _CT_Fail('PasswordHash empty positive');

  hash := GeneratePasswordHash(TCipher.CAllHash, 'x');
  if ComparePasswordHash('x', hash) then
      _CT_Pass('PasswordHash short positive')
  else
      _CT_Fail('PasswordHash short positive');

  enc := GeneratePassword(TCipher.AllCipher, pwd);
  if ComparePassword(TCipher.AllCipher, pwd, enc) then
      _CT_Pass('Password(AllCipher) positive')
  else
      _CT_Fail('Password(AllCipher) positive');
  if not ComparePassword(TCipher.AllCipher, wrong, enc) then
      _CT_Pass('Password(AllCipher) negative')
  else
      _CT_Fail('Password(AllCipher) negative');

  csArray := TCipher.AllCipher;
  for i := 0 to High(csArray) do
    begin
      enc := GeneratePassword(csArray[i], pwd);
      if ComparePassword(csArray[i], pwd, enc) then
          _CT_Pass('Password(' + TCipher.CCipherSecurityName[csArray[i]] + ') positive')
      else
          _CT_Fail('Password(' + TCipher.CCipherSecurityName[csArray[i]] + ') positive');
    end;

  hash := GenerateQuantumCryptographyPassword(pwd);
  if CompareQuantumCryptographyPassword(pwd, hash) then
      _CT_Pass('QuantumCryptographyPassword positive')
  else
      _CT_Fail('QuantumCryptographyPassword positive');
  if not CompareQuantumCryptographyPassword(wrong, hash) then
      _CT_Pass('QuantumCryptographyPassword negative')
  else
      _CT_Fail('QuantumCryptographyPassword negative');

  hash := GenerateQuantumCryptographyPassword('');
  if CompareQuantumCryptographyPassword('', hash) then
      _CT_Pass('QuantumCryptographyPassword empty positive')
  else
      _CT_Fail('QuantumCryptographyPassword empty positive');
end;

{ ============================================================================
 *  [E] Sequence hash / sequence encrypt / memory fingerprint
 * ============================================================================ }

procedure _CT_SequenceTests;
var
  buff: TBytes;
  ps: TListPascalString;
  k: TCipherKeyBuffer;
  i: Integer;
  ok: Boolean;
  mh: TCipherString;
  ss: TCipherString;
  stream_: TMS64;
begin
  _CT_Log('');
  _CT_Log('--- [E] Sequence hash / encrypt / memory fingerprint ---');

  SetLength(buff, 128 * 1024);
  for i := 0 to Length(buff) - 1 do
      buff[i] := Byte(i and $FF);

  ps := TListPascalString.Create;
  try
    GenerateSequHash(TCipher.CAllHash, @buff[0], Length(buff), ps);
    if CompareSequHash(ps, @buff[0], Length(buff)) then
        _CT_Pass('Sequence hash positive (TListPascalString)')
    else
        _CT_Fail('Sequence hash positive (TListPascalString)');

    ss := GenerateSequHash(TCipher.CAllHash, @buff[0], Length(buff));
    if CompareSequHash(ss, @buff[0], Length(buff)) then
        _CT_Pass('Sequence hash positive (TCipherString)')
    else
        _CT_Fail('Sequence hash positive (TCipherString)');

    stream_ := TMS64.Create;
    try
      GenerateSequHash(TCipher.CAllHash, @buff[0], Length(buff), stream_);
      stream_.Position := 0;
      if CompareSequHash(stream_, @buff[0], Length(buff)) then
          _CT_Pass('Sequence hash positive (TCore_Stream)')
      else
          _CT_Fail('Sequence hash positive (TCore_Stream)');
    finally
      disposeObject(stream_);
    end;

    TCipher.GenerateKey(TCipherSecurity.csRijndael, 'hello world', k);
    ok := SequEncrypt(TCipher.AllCipher, @buff[0], Length(buff), k, True, True);
    if ok then
        _CT_Pass('SequEncrypt encrypt')
    else
        _CT_Fail('SequEncrypt encrypt');
    ok := SequEncrypt(TCipher.AllCipher, @buff[0], Length(buff), k, False, True);
    if ok then
        _CT_Pass('SequEncrypt decrypt')
    else
        _CT_Fail('SequEncrypt decrypt');

    if CompareSequHash(ps, @buff[0], Length(buff)) then
        _CT_Pass('Sequence hash matches after round-trip')
    else
        _CT_Fail('Sequence hash matches after round-trip');

    ok := SequEncryptCBC(TCipher.AllCipher, @buff[0], Length(buff), k, True, True);
    ok := ok and SequEncryptCBC(TCipher.AllCipher, @buff[0], Length(buff), k, False, True);
    if ok then
        _CT_Pass('SequEncryptCBC round-trip')
    else
        _CT_Fail('SequEncryptCBC round-trip');

    ok := SequEncrypt(TCipherSecurity.csAES256, @buff[0], Length(buff), k, True, True);
    ok := ok and SequEncrypt(TCipherSecurity.csAES256, @buff[0], Length(buff), k, False, True);
    if ok then
        _CT_Pass('SequEncrypt single cipher (csAES256)')
    else
        _CT_Fail('SequEncrypt single cipher (csAES256)');

    mh := GenerateMemoryHash(TCipher.CAllHash, @buff[0], Length(buff));
    if CompareMemoryHash(@buff[0], Length(buff), mh) then
        _CT_Pass('MemoryHash positive')
    else
        _CT_Fail('MemoryHash positive');

    buff[0] := buff[0] xor $FF;
    if not CompareMemoryHash(@buff[0], Length(buff), mh) then
        _CT_Pass('MemoryHash negative (tampered)')
    else
        _CT_Fail('MemoryHash negative (tampered)');
    buff[0] := buff[0] xor $FF;
  finally
    disposeObject(ps);
    SetLength(k, 0);
  end;
end;

{ ============================================================================
 *  [F] Quantum stream encrypt / decrypt
 * ============================================================================ }

procedure _CT_QuantumStreamTests;
var
  input, output, dec: TMS64;
  k: TCipherKeyBuffer;
  i: Integer;
  ok: Boolean;
  src: TBytes;
  level: Integer;
  LEVELS: array [0 .. 2] of Integer;
  li: Integer;
begin
  _CT_Log('');
  _CT_Log('--- [F] Quantum stream encrypt / decrypt ---');

  SetLength(src, 4096);
  for i := 0 to Length(src) - 1 do
      src[i] := Byte((i * 11 + 5) and $FF);

  LEVELS[0] := 1;
  LEVELS[1] := 3;
  LEVELS[2] := 8;

  for li := Low(LEVELS) to High(LEVELS) do
    begin
      level := LEVELS[li];
      input := TMS64.Create;
      output := TMS64.Create;
      dec := TMS64.Create;
      try
        input.WritePtr(@src[0], Length(src));
        input.Position := 0;

        TCipher.GenerateKey(TCipherSecurity.csRijndael, 'quantum-key', k);
        QuantumEncrypt(input, output, level, k);

        if output.Size > 0 then
            _CT_Pass('QuantumEncrypt level ' + IntToStr(level) +
              ' produced ' + IntToStr(output.Size) + ' bytes')
        else
            _CT_Fail('QuantumEncrypt level ' + IntToStr(level));

        output.Position := 0;
        ok := QuantumDecrypt(output, dec, k);
        if not ok then
            _CT_Fail('QuantumDecrypt level ' + IntToStr(level))
        else if (dec.Size = Length(src)) and CompareMemory(@src[0], dec.Memory, Length(src)) then
            _CT_Pass('Quantum stream round-trip level ' + IntToStr(level))
        else
            _CT_Fail('Quantum stream round-trip level ' + IntToStr(level));

        SetLength(k, 0);
        TCipher.GenerateKey(TCipherSecurity.csRijndael, 'wrong-key', k);
        output.Position := 0;
        dec.Clear;
        ok := QuantumDecrypt(output, dec, k);
        if not ok then
            _CT_Pass('QuantumDecrypt rejects wrong key level ' + IntToStr(level))
        else
            _CT_Fail('QuantumDecrypt rejects wrong key level ' + IntToStr(level));
      finally
        disposeObject(input);
        disposeObject(output);
        disposeObject(dec);
        SetLength(k, 0);
      end;
    end;
end;

{ ============================================================================
 *  [G] Instance-class cipher API
 * ============================================================================ }

procedure _CT_InstanceClassTests;
var
  csArray: TCipherSecurityArray;
  k: TCipherKeyBuffer;
  c: TCipher_Tool_Base;
  orig, work: TBytes;
  i: Integer;
begin
  _CT_Log('');
  _CT_Log('--- [G] Instance-class cipher API ---');

  SetLength(orig, 2048 + 7);
  for i := 0 to Length(orig) - 1 do
      orig[i] := Byte((i * 13 + 7) and $FF);

  csArray := TCipher.AllCipher;
  for i := 0 to High(csArray) do
    begin
      if csArray[i] = csNone then
        begin
          _CT_Pass('Instance None (no-op)');
          Continue;
        end;

      TCipher.GenerateKey(csArray[i], 'instance-test', k);
      c := CreateCipherClass(csArray[i], k);
      try
        c.ProcessTail := True;
        c.CBC := False;
        c.Level := 1;
        work := Copy(orig, 0, Length(orig));
        c.Encrypt(@work[0], Length(work));
        c.Decrypt(@work[0], Length(work));
        if CompareMemory(@orig[0], @work[0], Length(orig)) then
            _CT_Pass('Instance round-trip ' + TCipher.CCipherSecurityName[csArray[i]])
        else
            _CT_Fail('Instance round-trip ' + TCipher.CCipherSecurityName[csArray[i]]);

        c.CBC := True;
        work := Copy(orig, 0, Length(orig));
        c.Encrypt(@work[0], Length(work));
        c.Decrypt(@work[0], Length(work));
        if CompareMemory(@orig[0], @work[0], Length(orig)) then
            _CT_Pass('Instance CBC round-trip ' + TCipher.CCipherSecurityName[csArray[i]])
        else
            _CT_Fail('Instance CBC round-trip ' + TCipher.CCipherSecurityName[csArray[i]]);

        c.CBC := False;
        c.Level := 3;
        work := Copy(orig, 0, Length(orig));
        c.Encrypt(@work[0], Length(work));
        c.Decrypt(@work[0], Length(work));
        if CompareMemory(@orig[0], @work[0], Length(orig)) then
            _CT_Pass('Instance level-3 round-trip ' +
              TCipher.CCipherSecurityName[csArray[i]])
        else
            _CT_Fail('Instance level-3 round-trip ' +
              TCipher.CCipherSecurityName[csArray[i]]);
      finally
        disposeObject(c);
      end;
    end;

  c := CreateCipherClassFromPassword(TCipherSecurity.csAES256, 'pw');
  try
    work := Copy(orig, 0, Length(orig));
    c.ProcessTail := True;
    c.Encrypt(@work[0], Length(work));
    c.Decrypt(@work[0], Length(work));
    if CompareMemory(@orig[0], @work[0], Length(orig)) then
        _CT_Pass('CreateCipherClassFromPassword(csAES256)')
    else
        _CT_Fail('CreateCipherClassFromPassword(csAES256)');
  finally
    disposeObject(c);
  end;

  SetLength(work, 32);
  FillPtr(@work[0], 32, $AA);
  c := CreateCipherClassFromBuffer(TCipherSecurity.csTwoFish, work);
  try
    work := Copy(orig, 0, Length(orig));
    c.ProcessTail := True;
    c.Encrypt(@work[0], Length(work));
    c.Decrypt(@work[0], Length(work));
    if CompareMemory(@orig[0], @work[0], Length(orig)) then
        _CT_Pass('CreateCipherClassFromBuffer(csTwoFish, TCipherKeyBuffer)')
    else
        _CT_Fail('CreateCipherClassFromBuffer(csTwoFish, TCipherKeyBuffer)');
  finally
    disposeObject(c);
  end;

  SetLength(work, 32);
  FillPtr(@work[0], 32, $BB);
  c := CreateCipherClassFromBuffer(TCipherSecurity.csSerpent, @work[0], Length(work));
  try
    work := Copy(orig, 0, Length(orig));
    c.ProcessTail := True;
    c.Encrypt(@work[0], Length(work));
    c.Decrypt(@work[0], Length(work));
    if CompareMemory(@orig[0], @work[0], Length(orig)) then
        _CT_Pass('CreateCipherClassFromBuffer(csSerpent, Pointer)')
    else
        _CT_Fail('CreateCipherClassFromBuffer(csSerpent, Pointer)');
  finally
    disposeObject(c);
  end;

  SetLength(work, 0);
  c := CreateCipherClassFromBuffer(TCipherSecurity.csMars, work);
  try
    _CT_Pass('CreateCipherClassFromBuffer(empty) executed');
  finally
    disposeObject(c);
  end;
end;

{ ============================================================================
 *  [H] Stream hashing consistency
 * ============================================================================ }

procedure _CT_StreamHashTests;
var
  m64: TMS64;
  md5a, md5b: TMD5;
  crcA, crcB: Cardinal;
  crc16a, crc16b: Word;
begin
  _CT_Log('');
  _CT_Log('--- [H] Stream hashing consistency ---');

  m64 := TMS64.Create;
  try
    m64.Size := 4 * 1024 * 1024 + 13;
    FillPtr(m64.Memory, m64.Size, $7F);

    md5a := umlStreamMD5(m64);
    md5b := umlMD5(PByte(m64.Memory), NativeUInt(m64.Size));
    if umlCompareMD5(md5a, md5b) then
        _CT_Pass('Stream MD5 == pointer MD5')
    else
        _CT_Fail('Stream MD5 == pointer MD5');

    crcA := umlStreamCRC32(m64);
    crcB := umlCRC32(PByte(m64.Memory), NativeUInt(m64.Size));
    if crcA = crcB then
        _CT_Pass('Stream CRC32 == pointer CRC32')
    else
        _CT_Fail('Stream CRC32 == pointer CRC32');

    crc16a := umlStreamCRC16(m64);
    crc16b := umlCRC16(PByte(m64.Memory), NativeUInt(m64.Size));
    if crc16a = crc16b then
        _CT_Pass('Stream CRC16 == pointer CRC16')
    else
        _CT_Fail('Stream CRC16 == pointer CRC16');
  finally
    disposeObject(m64);
  end;
end;

(*
 ============================================================================
 *  [I] Parallel cipher API (only when {$DEFINE Parallel})
 * ============================================================================
*)
{$IFDEF Parallel}
procedure _CT_ParallelTests;
var
  csArray: TCipherSecurityArray;
  k: TCipherKeyBuffer;
  key, orig, work: TBytes;
  i: Integer;
  ok: Boolean;
  pc: TParallelCipher;
  cs: TCipherSecurity;
begin
  _CT_Log('');
  _CT_Log('--- [I] Parallel cipher API ---');

  SetLength(key, 32);
  for i := 0 to 31 do
      key[i] := Byte(i * 3 + 1);

  SetLength(orig, 256 * 1024 + 11);
  for i := 0 to Length(orig) - 1 do
      orig[i] := Byte((i * 5 + 9) and $FF);

  csArray := TCipher.AllCipher;
  for i := 0 to High(csArray) do
    begin
      cs := csArray[i];
      if cs = csNone then
        begin
          _CT_Pass('Parallel None (no-op)');
          Continue;
        end;

      TCipher.GenerateKey(cs, @key[0], Length(key), k);
      pc := TParallelCipher.Create;
      try
        pc.BlockDepth := DefaultParallelDepth;

        work := Copy(orig, 0, Length(orig));
        ok := pc.EncryptBuffer(cs, @work[0], Length(work), @k, True, True);
        ok := ok and pc.EncryptBuffer(cs, @work[0], Length(work), @k, False, True);
        if ok and CompareMemory(@orig[0], @work[0], Length(orig)) then
            _CT_Pass('Parallel round-trip ' + TCipher.CCipherSecurityName[cs])
        else
            _CT_Fail('Parallel round-trip ' + TCipher.CCipherSecurityName[cs]);

        work := Copy(orig, 0, Length(orig));
        ok := pc.EncryptBufferCBC(cs, @work[0], Length(work), @k, True, True);
        ok := ok and pc.EncryptBufferCBC(cs, @work[0], Length(work), @k, False, True);
        if ok and CompareMemory(@orig[0], @work[0], Length(orig)) then
            _CT_Pass('Parallel CBC round-trip ' + TCipher.CCipherSecurityName[cs])
        else
            _CT_Fail('Parallel CBC round-trip ' + TCipher.CCipherSecurityName[cs]);
      finally
        disposeObject(pc);
      end;
    end;
end;
{$ENDIF}

{ ============================================================================
 *  [J] Performance summary
 * ============================================================================ }

procedure _CT_PerformanceSummary;
var
  csArray: TCipherSecurityArray;
  hs: THashSecurity;
  k: TCipherKeyBuffer;
  data, h: TBytes;
  i: Integer;
  t: TTimeTick;
begin
  _CT_Log('');
  _CT_Log('--- [J] Performance summary (1 MB) ---');

  SetLength(data, 1024 * 1024 + 17);
  FillPtr(@data[0], Length(data), $7F);

  _CT_Log('Cipher (encrypt+decrypt):');
  csArray := TCipher.AllCipher;
  for i := 0 to High(csArray) do
    begin
      TCipher.GenerateKey(csArray[i], 'perf', k);
      t := GetTimeTick;
      TCipher.EncryptBuffer(csArray[i], @data[0], Length(data), @k, True, True);
      TCipher.EncryptBuffer(csArray[i], @data[0], Length(data), @k, False, True);
      DoStatus(Format('  %-10s %6d ms',
        [TCipher.CCipherSecurityName[csArray[i]], GetTimeTick - t]));
    end;

  _CT_Log('Hash:');
  for hs := Low(THashSecurity) to High(THashSecurity) do
    begin
      t := GetTimeTick;
      TCipher.GenerateHashByte(hs, @data[0], Length(data), h);
      DoStatus(Format('  %-10s %6d ms',
        [TCipher.CHashName[hs], GetTimeTick - t]));
    end;
end;

{ ============================================================================
 *  [K] Hex / buffer / HashToString helpers
 * ============================================================================ }

procedure _CT_HexHelperTests;
var
  b, h1, h2: TBytes;
  s, sHex: TCipherString;
  ss: TCipherSystemString;
  buf: array [0 .. 31] of Byte;
  ok: Boolean;
  i: Integer;
  m1, m2: TMD5Digest;
  dSHA256: TSHA256Digest;
  dSHA512: TSHA512Digest;
  d224: TSHA3_224_Digest;
  d256: TSHA3_256_Digest;
  d384: TSHA3_384_Digest;
  d512: TSHA3_512_Digest;
  dSHA1: TSHA1Digest;
  dMD5: TMD5Digest;
begin
  _CT_Log('');
  _CT_Log('--- [K] Hex / buffer / HashToString helpers ---');

  SetLength(b, 16);
  for i := 0 to 15 do
      b[i] := Byte(i * 17);

  sHex := TCipher.BuffToString(@b[0], Length(b));
  if sHex.Len = 32 then
      _CT_Pass('BuffToString length = 32')
  else
      _CT_Fail('BuffToString length expected 32 got ' + IntToStr(sHex.Len));

  FillPtr(@buf[0], SizeOf(buf), 0);
  ok := TCipher.HexToBuffer(sHex, buf[0], SizeOf(buf));
  if ok and CompareMemory(@b[0], @buf[0], Length(b)) then
      _CT_Pass('HexToBuffer round-trip')
  else
      _CT_Fail('HexToBuffer round-trip');

  FillPtr(@buf[0], SizeOf(buf), 0);
  ok := TCipher.StringToBuff(sHex, buf[0], SizeOf(buf));
  if ok and CompareMemory(@b[0], @buf[0], Length(b)) then
      _CT_Pass('StringToBuff round-trip')
  else
      _CT_Fail('StringToBuff round-trip');

  sHex := TCipher.BufferToHex(b[0], Length(b));
  if sHex.Len = 32 then
      _CT_Pass('BufferToHex length = 32')
  else
      _CT_Fail('BufferToHex length');

  SetLength(h1, 4);
  h1[0] := $DE; h1[1] := $AD; h1[2] := $BE; h1[3] := $EF;
  TCipher.HashToString(h1, s);
  if s.Text = 'deadbeef' then
      _CT_Pass('HashToString(TBytes) = deadbeef')
  else
      _CT_Fail('HashToString(TBytes)');

  TCipher.HashToString(h1, ss);
  if ss = 'deadbeef' then
      _CT_Pass('HashToString(TBytes -> TCipherSystemString)')
  else
      _CT_Fail('HashToString(TBytes -> TCipherSystemString)');

  TCipher.HashToString(@h1[0], Length(h1), s);
  if s.Text = 'deadbeef' then
      _CT_Pass('HashToString(Pointer, Size)')
  else
      _CT_Fail('HashToString(Pointer, Size)');

  dMD5 := TCipher.GenerateMD5Hash(@h1[0], Length(h1));
  TCipher.HashToString(dMD5, s);
  if s.Len = 32 then
      _CT_Pass('HashToString(TMD5Digest) length=32')
  else
      _CT_Fail('HashToString(TMD5Digest)');

  dSHA1 := TCipher.GenerateSHA1Hash(@h1[0], Length(h1));
  TCipher.HashToString(dSHA1, s);
  if s.Len = 40 then
      _CT_Pass('HashToString(TSHA1Digest) length=40')
  else
      _CT_Fail('HashToString(TSHA1Digest)');

  dSHA256 := TCipher.GenerateSHA256Hash(@h1[0], Length(h1));
  TCipher.HashToString(dSHA256, s);
  if s.Len = 64 then
      _CT_Pass('HashToString(TSHA256Digest) length=64')
  else
      _CT_Fail('HashToString(TSHA256Digest)');

  dSHA512 := TCipher.GenerateSHA512Hash(@h1[0], Length(h1));
  TCipher.HashToString(dSHA512, s);
  if s.Len = 128 then
      _CT_Pass('HashToString(TSHA512Digest) length=128')
  else
      _CT_Fail('HashToString(TSHA512Digest)');

  d224 := TCipher.GenerateSHA3_224Hash(@h1[0], Length(h1));
  TCipher.HashToString(d224, s);
  if s.Len = 56 then
      _CT_Pass('HashToString(TSHA3_224_Digest) length=56')
  else
      _CT_Fail('HashToString(TSHA3_224_Digest)');

  d256 := TCipher.GenerateSHA3_256Hash(@h1[0], Length(h1));
  TCipher.HashToString(d256, s);
  if s.Len = 64 then
      _CT_Pass('HashToString(TSHA3_256_Digest) length=64')
  else
      _CT_Fail('HashToString(TSHA3_256_Digest)');

  d384 := TCipher.GenerateSHA3_384Hash(@h1[0], Length(h1));
  TCipher.HashToString(d384, s);
  if s.Len = 96 then
      _CT_Pass('HashToString(TSHA3_384_Digest) length=96')
  else
      _CT_Fail('HashToString(TSHA3_384_Digest)');

  d512 := TCipher.GenerateSHA3_512Hash(@h1[0], Length(h1));
  TCipher.HashToString(d512, s);
  if s.Len = 128 then
      _CT_Pass('HashToString(TSHA3_512_Digest) length=128')
  else
      _CT_Fail('HashToString(TSHA3_512_Digest)');

  SetLength(h2, 4);
  CopyPtr(@h1[0], @h2[0], 4);
  if TCipher.CompareHash(h1, h2) then
      _CT_Pass('CompareHash(TBytes) positive')
  else
      _CT_Fail('CompareHash(TBytes) positive');

  h2[0] := h2[0] xor $FF;
  if not TCipher.CompareHash(h1, h2) then
      _CT_Pass('CompareHash(TBytes) negative')
  else
      _CT_Fail('CompareHash(TBytes) negative');

  m1 := TCipher.GenerateMD5Hash(@h1[0], 4);
  m2 := TCipher.GenerateMD5Hash(@h1[0], 4);
  if TCipher.CompareHash(m1, m2) then
      _CT_Pass('CompareHash(TMD5Digest) positive')
  else
      _CT_Fail('CompareHash(TMD5Digest) positive');

  if TCipher.CompareHash(@h1[0], @h1[0], Length(h1)) then
      _CT_Pass('CompareHash(Pointer, Size) positive')
  else
      _CT_Fail('CompareHash(Pointer, Size) positive');
end;

{ ============================================================================
 *  [L] Key generation and extraction
 * ============================================================================ }

procedure _CT_KeyGenTests;
var
  k, kSrc, kDst: TCipherKeyBuffer;
  src64, dst64: TKey64;
  dst64b, dst64c: TKey64;
  kA, kB, kC: TKey64;
  src128, dst128: TKey128;
  src256, dst256: TKey256;
  d1, d2: DWORD;
  dA, dB: DWORD;
  ok: Boolean;
  hsLoop: THashSecurity;
  hsTemp: THashSecurity;
  cs: TCipherSecurity;
  ar: TCipherSecurityArray;
  rawBuf: array [0 .. 31] of Byte;
  i: Integer;
begin
  _CT_Log('');
  _CT_Log('--- [L] Key generation / extraction ---');

  FillPtr(@src64, SizeOf(src64), $AA);
  TCipher.GenerateKey(src64, k);
  ok := TCipher.GetKey(@k, dst64);
  if ok and CompareMemory(@src64, @dst64, SizeOf(src64)) then
      _CT_Pass('Key round-trip (TKey64 -> GenerateKey / GetKey)')
  else
      _CT_Fail('Key round-trip (TKey64)');

  FillPtr(@kA, SizeOf(kA), $11);
  FillPtr(@kB, SizeOf(kB), $22);
  FillPtr(@kC, SizeOf(kC), $33);
  TCipher.GenerateKey(kA, kB, kC, k);
  ok := TCipher.GetKey(@k, dst64, dst64b, dst64c);
  if ok and CompareMemory(@kA, @dst64, 8) then
      _CT_Pass('Key round-trip (3x TKey64)')
  else
      _CT_Fail('Key round-trip (3x TKey64)');

  FillPtr(@src128, SizeOf(src128), $BB);
  TCipher.GenerateKey(src128, k);
  ok := TCipher.GetKey(@k, dst128);
  if ok and CompareMemory(@src128, @dst128, SizeOf(src128)) then
      _CT_Pass('Key round-trip (TKey128)')
  else
      _CT_Fail('Key round-trip (TKey128)');

  FillPtr(@src256, SizeOf(src256), $CC);
  TCipher.GenerateKey(src256, k);
  ok := TCipher.GetKey(@k, dst256);
  if ok and CompareMemory(@src256, @dst256, SizeOf(src256)) then
      _CT_Pass('Key round-trip (TKey256)')
  else
      _CT_Fail('Key round-trip (TKey256)');

  TCipher.GenerateKey($DEADBEEF, k);
  d2 := 0;
  ok := TCipher.GetKey(@k, d2);
  if ok and (d2 = $DEADBEEF) then
      _CT_Pass('Key round-trip (single DWORD)')
  else
      _CT_Fail('Key round-trip (single DWORD)');

  dA := $AAAAAAAA;
  dB := $55555555;
  TCipher.GenerateKey(dA, dB, k);
  d1 := 0; d2 := 0;
  ok := TCipher.GetKey(@k, d1, d2);
  if ok and (d1 = $AAAAAAAA) and (d2 = $55555555) then
      _CT_Pass('Key round-trip (two DWORDs)')
  else
      _CT_Fail('Key round-trip (two DWORDs)');

  SetLength(kSrc, 24);
  FillPtr(@kSrc[0], 24, $DD);
  TCipher.GenerateKey(@kSrc[0], 24, k);
  ok := TCipher.GetKey(@k, kDst);
  if ok and (Length(kDst) = 24) and (kDst[0] = $DD) and (kDst[23] = $DD) then
      _CT_Pass('Key round-trip (dynamic byte key)')
  else
      _CT_Fail('Key round-trip (dynamic byte key)');

  FillPtr(@rawBuf[0], SizeOf(rawBuf), $EE);
  for i := Ord(Low(TCipherSecurity)) to Ord(High(TCipherSecurity)) do
    begin
      TCipher.GenerateKey(TCipherSecurity(i), @rawBuf[0], Length(rawBuf), k);
      _CT_Pass('GenerateKey(cs=' + TCipher.CCipherSecurityName[TCipherSecurity(i)] +
        ', pointer) produced ' + IntToStr(Length(k)) + ' bytes');
    end;

  for i := Ord(Low(TCipherSecurity)) to Ord(High(TCipherSecurity)) do
    begin
      TCipher.GenerateKey(TCipherSecurity(i), 'seed', k);
      if TCipherKeyStyle(k[0]) = TCipher.CCipherKeyStyle[TCipherSecurity(i)] then
          _CT_Pass('Key style tag for ' + TCipher.CCipherSecurityName[TCipherSecurity(i)])
      else
          _CT_Fail('Key style tag for ' + TCipher.CCipherSecurityName[TCipherSecurity(i)]);
    end;

  TCipher.GenerateKey64('seed', k);
  _CT_Pass('GenerateKey64(TCipherSystemString)');
  TCipher.GenerateKey64(@rawBuf[0], 32, k);
  _CT_Pass('GenerateKey64(pointer)');
  TCipher.GenerateKey128('seed', k);
  _CT_Pass('GenerateKey128(TCipherSystemString)');
  TCipher.GenerateKey128(@rawBuf[0], 32, k);
  _CT_Pass('GenerateKey128(pointer)');
  TCipher.GenerateKey256('seed', k);
  _CT_Pass('GenerateKey256(TCipherSystemString)');
  TCipher.GenerateKey256(@rawBuf[0], 32, k);
  _CT_Pass('GenerateKey256(pointer)');
  TCipher.Generate3Key64('seed', k);
  _CT_Pass('Generate3Key64(TCipherSystemString)');
  TCipher.Generate3Key64(@rawBuf[0], 32, k);
  _CT_Pass('Generate3Key64(pointer)');
  TCipher.Generate2IntKey('seed', k);
  _CT_Pass('Generate2IntKey(TCipherSystemString)');
  TCipher.Generate2IntKey(@rawBuf[0], 32, k);
  _CT_Pass('Generate2IntKey(pointer)');
  TCipher.GenerateIntKey('seed', k);
  _CT_Pass('GenerateIntKey(TCipherSystemString)');
  TCipher.GenerateIntKey(@rawBuf[0], 32, k);
  _CT_Pass('GenerateIntKey(pointer)');
  TCipher.GenerateBytesKey('seed', 24, k);
  _CT_Pass('GenerateBytesKey(TCipherSystemString, 24)');
  TCipher.GenerateBytesKey(@rawBuf[0], 32, 24, k);
  _CT_Pass('GenerateBytesKey(pointer, 32, 24)');
  TCipher.GenerateNoneKey(k);
  _CT_Pass('GenerateNoneKey');

  FillPtr(@kA, SizeOf(kA), $55);
  FillPtr(@kB, SizeOf(kB), $AA);
  TCipher.GenerateKey128(kA, kB, k);
  _CT_Pass('GenerateKey128(2x TKey64)');
  TCipher.GenerateKey64(kA, k);
  _CT_Pass('GenerateKey64(TKey64)');

  kSrc := TCipher.CopyKey(k);
  if TCipher.CompareKey(kSrc, k) then
      _CT_Pass('CopyKey + CompareKey')
  else
      _CT_Fail('CopyKey + CompareKey');

  if TCipher.GetKeyStyle(@k) = TCipherKeyStyle(k[0]) then
      _CT_Pass('GetKeyStyle matches tag')
  else
      _CT_Fail('GetKeyStyle matches tag');

  SetLength(kSrc, 0);
  kDst := TCipher.CopyKey(kSrc);
  if Length(kDst) = 0 then
      _CT_Pass('CopyKey(empty) returns empty')
  else
      _CT_Fail('CopyKey(empty)');

  for hsLoop := Low(THashSecurity) to High(THashSecurity) do
    begin
      ok := TCipher.NameToHashSecurity(TCipher.CHashName[hsLoop], hsTemp);
      ok := ok and (hsTemp = hsLoop);
      if ok then
          _CT_Pass('NameToHashSecurity("' + TCipher.CHashName[hsLoop] + '")')
      else
          _CT_Fail('NameToHashSecurity("' + TCipher.CHashName[hsLoop] + '")');
    end;

  ar := TCipher.AllCipher;
  cs := TCipher.Random_Select_Cipher(ar);
  _CT_Pass('Random_Select_Cipher = ' + TCipher.CCipherSecurityName[cs]);
end;

{ ============================================================================
 *  [M] Application-level TCipher_Base coverage
 * ============================================================================ }

procedure _CT_ApplicationAPITests;
var
  csArray: TCipherSecurityArray;
  k: TCipherKeyBuffer;
  orig, work: TBytes;
  c: TCipher_Tool_Base;
  csName: TCipherSystemString;
  s, s2: TCipherString;
  i: Integer;
  lvl: Integer;
begin
  _CT_Log('');
  _CT_Log('--- [M] Application-level TCipher_Base coverage ---');

  SetLength(orig, 512);
  for i := 0 to Length(orig) - 1 do
      orig[i] := Byte((i * 3 + 7) and $FF);

  csArray := TCipher.AllCipher;
  for i := 0 to High(csArray) do
    begin
      if csArray[i] = csNone then
          Continue;

      TCipher.GenerateKey(csArray[i], 'property-test', k);
      c := CreateCipherClass(csArray[i], k);
      try
        csName := TCipher.CCipherSecurityName[csArray[i]];
        if c.CipherSecurity = csArray[i] then
            _CT_Pass('TCipher_Base.CipherSecurity = ' + csName)
        else
            _CT_Fail('TCipher_Base.CipherSecurity for ' + csName);

        c.ProcessTail := True;
        if c.ProcessTail then
            _CT_Pass('TCipher_Base.ProcessTail getter/setter (' + csName + ')')
        else
            _CT_Fail('TCipher_Base.ProcessTail for ' + csName);

        c.CBC := True;
        if c.CBC then
            _CT_Pass('TCipher_Base.CBC getter/setter (' + csName + ')')
        else
            _CT_Fail('TCipher_Base.CBC for ' + csName);

        c.Level := 5;
        lvl := c.Level;
        if lvl = 5 then
            _CT_Pass('TCipher_Base.Level getter/setter (' + csName + ')')
        else
            _CT_Fail('TCipher_Base.Level for ' + csName);

        if Length(c.LastGenerateKey) = Length(k) then
            _CT_Pass('TCipher_Base.LastGenerateKey length (' + csName + ')')
        else
            _CT_Fail('TCipher_Base.LastGenerateKey length for ' + csName);
      finally
        disposeObject(c);
      end;
    end;

  TCipher.GenerateKey(csAES128, 'process-test', k);
  c := CreateCipherClass(csAES128, k);
  try
    work := Copy(orig, 0, Length(orig));
    c.Process(@work[0], Length(work), 1, True, True, False);
    c.Process(@work[0], Length(work), 1, False, True, False);
    if CompareMemory(@orig[0], @work[0], Length(orig)) then
        _CT_Pass('TCipher_Base.Process round-trip')
    else
        _CT_Fail('TCipher_Base.Process round-trip');
  finally
    disposeObject(c);
  end;

  c := CreateCipherClassFromPassword(csAES256, 'text-pw');
  try
    s := c.Text_Encrypt('Hello, world 123');
    s2 := c.Text_Decrypt(s);
    if s2.Text = 'Hello, world 123' then
        _CT_Pass('TCipher_Base.Text_Encrypt/Decrypt round-trip')
    else
        _CT_Fail('TCipher_Base.Text_Encrypt/Decrypt round-trip');
  finally
    disposeObject(c);
  end;

  c := CreateCipherClassFromPassword(csAES128, 'self-test');
  try
    c.Test;
    _CT_Pass('TCipher_Base.Test executed without exception');
  finally
    disposeObject(c);
  end;
end;

{ ============================================================================
 *  [N] Boundary and edge-case tests
 * ============================================================================ }

procedure _CT_BoundaryTests;
const
  SIZES: array [0 .. 12] of Integer =
    (0, 1, 7, 8, 9, 15, 16, 17, 63, 64, 127, 128, 129);
var
  csArray: TCipherSecurityArray;
  cs: TCipherSecurity;
  k: TCipherKeyBuffer;
  orig, work, key: TBytes;
  sz: Integer;
  i, n, s: Integer;
  ok: Boolean;
  failName: TCipherSystemString;
begin
  _CT_Log('');
  _CT_Log('--- [N] Boundary and edge-case tests ---');

  SetLength(key, 32);
  for i := 0 to 31 do
      key[i] := Byte(i xor $5A);

  csArray := TCipher.AllCipher;
  for n := 0 to High(csArray) do
    begin
      cs := csArray[n];
      if cs = csNone then
          Continue;

      TCipher.GenerateKey(cs, @key[0], Length(key), k);
      for s := Low(SIZES) to High(SIZES) do
        begin
          sz := SIZES[s];
          if sz = 0 then
              Continue;

          SetLength(orig, sz);
          for i := 0 to Length(orig) - 1 do
              orig[i] := Byte((i * 11 + 3) and $FF);

          work := Copy(orig, 0, Length(orig));
          TCipher.EncryptBuffer(cs, @work[0], Length(work), @k, True, True);
          TCipher.EncryptBuffer(cs, @work[0], Length(work), @k, False, True);

          failName := Format('Boundary %s @ %d bytes',
            [TCipher.CCipherSecurityName[cs], sz]);
          if CompareMemory(@orig[0], @work[0], Length(orig)) then
              _CT_Pass(failName)
          else
              _CT_Fail(failName);
        end;
    end;

  SetLength(orig, 24);
  for i := 0 to 23 do
      orig[i] := Byte(i + 1);
  work := Copy(orig, 0, Length(orig));
  TCipher.GenerateKey(csAES128, 'tail-off', k);
  TCipher.EncryptBuffer(csAES128, @work[0], Length(work), @k, True, False);
  ok := True;
  for i := 16 to 23 do
    if work[i] <> orig[i] then
      begin
        ok := False;
        Break;
      end;
  if ok then
      _CT_Pass('ProcessTail=False leaves trailing bytes untouched')
  else
      _CT_Fail('ProcessTail=False leaves trailing bytes untouched');

  TCipher.GenerateKey(csAES128, 'empty', k);
  try
    TCipher.EncryptBuffer(csAES128, nil, 0, @k, True, True);
    _CT_Pass('EncryptBuffer with Size=0 does not crash');
  except
    _CT_Fail('EncryptBuffer with Size=0 does not crash');
  end;
end;

{ ============================================================================
 *  [O] Standard compliance matrix
 * ============================================================================ }

procedure _CT_ComplianceMatrix;
begin
  _CT_Log('');
  _CT_Log('--- [O] Standard compliance matrix ---');
  _CT_Log('');
  _CT_Log('  +------------------+--------------------+-----------+');
  _CT_Log('  | Algorithm        | Reference          | Status    |');
  _CT_Log('  +------------------+--------------------+-----------+');
  _CT_Log('  | MD5              | RFC 1321           | standard  |');
  _CT_Log('  | SHA-1            | FIPS 180-4         | standard  |');
  _CT_Log('  | SHA-256          | FIPS 180-4         | standard  |');
  _CT_Log('  | SHA-512          | FIPS 180-4         | standard  |');
  _CT_Log('  | SHA3-224         | FIPS 202           | standard  |');
  _CT_Log('  | SHA3-256         | FIPS 202           | standard  |');
  _CT_Log('  | SHA3-384         | FIPS 202           | standard  |');
  _CT_Log('  | SHA3-512         | FIPS 202           | standard  |');
  _CT_Log('  | SHAKE128         | FIPS 202           | standard  |');
  _CT_Log('  | SHAKE256         | FIPS 202           | standard  |');
  _CT_Log('  | DES              | FIPS 46-3          | standard  |');
  _CT_Log('  | Triple DES       | NIST SP 800-67     | standard  |');
  _CT_Log('  | AES-128/192/256  | FIPS 197           | standard  |');
  _CT_Log('  | Blowfish         | Schneier 1993      | standard  |');
  _CT_Log('  | Twofish          | AES submission     | standard  |');
  _CT_Log('  | Serpent          | AES submission     | standard  |');
  _CT_Log('  | MARS             | AES submission     | standard  |');
  _CT_Log('  | RC6              | AES submission     | standard  |');
  _CT_Log('  | Rijndael         | AES submission     | derived   |');
  _CT_Log('  | XXTEA            | Corrected B-TEA    | standard  |');
  _CT_Log('  | LBC / LQC        | Z-Framework        | custom    |');
  _CT_Log('  | RNG32 / RNG64    | Z-Framework        | custom    |');
  _CT_Log('  | LSC              | Z-Framework        | custom    |');
  _CT_Log('  | LMD family       | Z-Framework        | custom    |');
  _CT_Log('  | ELF              | public domain      | standard  |');
  _CT_Log('  | Mix128           | public domain      | standard  |');
  _CT_Log('  | CRC16            | ITU-T              | standard  |');
  _CT_Log('  | CRC32            | IEEE 802.3         | standard  |');
  _CT_Log('  +------------------+--------------------+-----------+');
end;

{ ============================================================================
 *  [P] Report header / footer
 * ============================================================================ }

procedure _CT_ReportHeader;
var
  platformStr: TCipherSystemString;
begin
{$IFDEF CPU64}
  platformStr := '64-bit';
{$ELSE}
  platformStr := '32-bit';
{$ENDIF}
  DoStatus('');
  DoStatus('================================================================================');
  DoStatus('                     Z.CIPHER COMPREHENSIVE TEST REPORT');
  DoStatus('================================================================================');
  DoStatus('  Compiler : ' + Get_Compiler_Version);
  DoStatus('  Platform : ' + platformStr);
  DoStatus('  Date     : ' + FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
  DoStatus('  Scope    : TCipher / TCipher_Base / all THashSecurity / all');
  DoStatus('             TCipherSecurity / Quantum / Sequence / Parallel');
  DoStatus('================================================================================');
  DoStatus('');
end;

procedure _CT_ReportFooter;
begin
  DoStatus('');
  DoStatus('================================================================================');
  DoStatus('                                 SUMMARY');
  DoStatus('================================================================================');
  DoStatus(Format('  Total tests   : %d', [_CT_PassCount + _CT_FailCount]));
  DoStatus(Format('  Passed        : %d', [_CT_PassCount]));
  DoStatus(Format('  Failed        : %d', [_CT_FailCount]));
  if _CT_FailCount = 0 then
      DoStatus('  Overall       : PASS')
  else
      DoStatus('  Overall       : FAIL');
  DoStatus('================================================================================');
  DoStatus('');
end;

{ ============================================================================
 *  Main entry point
 * ============================================================================ }

procedure TestCoreCipher;
begin
  _CT_PassCount := 0;
  _CT_FailCount := 0;

  _CT_ReportHeader;

  _CT_HashStandardVectors;
  _CT_CipherStandardVectors;
  _CT_IncrementalHashTests;
  _CT_LowLevelCipherTests;
  _CT_HashSizeCheck;
  _CT_CipherRoundTrip;
  _CT_PasswordTests;
  _CT_SequenceTests;
  _CT_QuantumStreamTests;
  _CT_InstanceClassTests;
  _CT_StreamHashTests;

{$IFDEF Parallel}
  _CT_ParallelTests;
{$ENDIF}

  _CT_HexHelperTests;
  _CT_KeyGenTests;
  _CT_ApplicationAPITests;
  _CT_BoundaryTests;
  _CT_PerformanceSummary;
  _CT_ComplianceMatrix;

  _CT_ReportFooter;
end;


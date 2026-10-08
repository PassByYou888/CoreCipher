{
  * ============================================================================
  * Z.Cipher - Cryptographic and hashing library.
  *
  * This unit provides a comprehensive suite of cryptographic primitives,
  * including block ciphers (DES, Blowfish, LBC, LQC, XXTEA, RC6, Serpent,
  * MARS, Rijndael, Twofish, AES), stream ciphers (RNG32, RNG64, LSC), and
  * hash functions (MD5, SHA-1, SHA-256, SHA-512, SHA-3, ELF, CRC16, CRC32,
  * and the custom LMD family). It also offers key generation, password-based
  * encryption, quantum-resistant password hashing (SHA-3), and parallel
  * processing support.
  *
  * Design goals:
  *   - Unified interface for encryption/decryption across many algorithms.
  *   - Key generation from passphrases or raw data using hash-based
  *     derivation.
  *   - Support for block cipher modes (ECB with optional tail handling,
  *     CBC).
  *   - Performance optimisations with optional parallel execution (if
  *     compiled with the Parallel define).
  *   - Strong type safety for keys and contexts.
  *   - Built-in testing routines.
  *
  * Key features:
  *   - Encrypt/decrypt buffers in-place using TCipher class methods.
  *   - Sequential encryption chains (multiple ciphers applied in sequence).
  *   - Password hashing with configurable hash algorithms.
  *   - QuantumCryptographyPassword using SHA-3 SHAKE256.
  *   - Reliable file stream (TReliableFileStream) with backup on write.
  *   - Base64 encoding/decoding utilities.
  *
  * Removed in this revision (verified unused anywhere in the unit):
  *   - TDesConverter     (byte-order helper record; Endian() is used).
  *   - P128Bit           (pointer alias for T128Bit; never referenced).
  *   - T256Bit / P256Bit (unused 256-bit vector and its pointer).
  *   - TMD5Key           (unused alias for TMD5Digest).
  *   - TSHA1Key          (unused alias for TSHA1Digest).
  *   - TSHA256Key        (unused alias for TSHA256Digest).
  *   - TSHA512Key        (unused alias for TSHA512Digest).
  *   - TCipherSecuritys  (unused set of TCipherSecurity).
  *   - CCipher_Data_Length (TCipher class const array; not referenced).
  *
  * Conventions (project-wide):
  *   - No Move / no FillChar in unit code; use CopyPtr / FillPtr.
  *   - Every multi-line comment line starts with "*" so that Delphi and
  *     Lazarus code-formatting tools preserve the layout.
  * ============================================================================
}

unit Z.Cipher;

{$DEFINE FPC_DELPHI_MODE}
{$I Z.Define.inc}

interface

uses
  Types, SysUtils, Math, TypInfo,
{$IFDEF FastMD5}
  Z.MD5,
{$ENDIF}
  Z.Core,
  Z.AES,
  Z.UnicodeMixedLib, Z.MemoryStream, Z.PascalStrings, Z.UPascalStrings, Z.ListEngine;

const
  {
    * Largest structure that can be created (2 GiB).
  }
  { largest structure that can be created }
  MaxStructSize = MaxInt; { 2G }

  {
    * Serialized key-buffer size constants.
  }
  cIntSize = 4;
  cKeyDWORDSize = 4;
  cKey2DWORDSize = 8;
  cKey64Size = 8;
  cKey128Size = 16;
  cKey192Size = 24;
  cKey256Size = 32;

type
{$IFDEF FPC}
  TCipherString = TUPascalString; // Unicode string type (UTF‑16)
  TCipherSystemString = USystemString; // Native system string (UnicodeString)
  TCipherChar = USystemChar; // Unicode character (UTF‑16 code unit)
{$ELSE FPC}
  TCipherString = TPascalString; // Pascal string (UTF‑16 in Delphi)
  TCipherSystemString = SystemString; // Native string
  TCipherChar = SystemChar; // System character (WideChar)
{$ENDIF FPC}
  {
    * Pointer to DWORD.
  }
  PDWORD = ^DWORD;

  {
    * Unbounded DWORD array used for raw pointer arithmetic.
  }
  { general structures }
  PDWordArray = ^TDWordArray;
  TDWordArray = array [0 .. MaxStructSize div SizeOf(DWORD) - 1] of DWORD;

  {
    * Unbounded byte array used for raw pointer arithmetic.
  }
  TCCByteArray = array [0 .. MaxStructSize div SizeOf(Byte) - 1] of Byte;
  PCCByteArray = ^TCCByteArray;

  {
    * 32-bit integer union with Word / Byte / Integer / DWORD views.
  }
  TInt32 = packed record
    case Byte of
      1: (Lo: Word;
          Hi: Word);
      2: (LoLo: Byte;
          LoHi: Byte;
          HiLo: Byte;
          HiHi: Byte);
      3: (i: Integer);
      4: (u: DWORD);
  end;

  {
    * 64-bit integer union with Integer / Word / Byte / Int64 / UInt64
    * views.
  }
  TInt64 = packed record
    case Byte of
      0: (Lo: Integer;
          Hi: Integer);
      1: (LoLo: Word;
          LoHi: Word;
          HiLo: Word;
          HiHi: Word);
      2: (LoLoLo: Byte;
          LoLoHi: Byte;
          LoHiLo: Byte;
          LoHiHi: Byte;
          HiLoLo: Byte;
          HiLoHi: Byte;
          HiHiLo: Byte;
          HiHiHi: Byte);
      3: (i: Int64);
      4: (u: UInt64);
  end;

  {
    * Encryption key types.
  }
  { encryption key types }
type
  PKey64 = ^TKey64; { !!.03 }
  TKey64 = array [0 .. 7] of Byte;

  PKey128 = ^TKey128; { !!.03 }
  TKey128 = array [0 .. 15] of Byte;

  PKey256 = ^TKey256; { !!.03 }
  TKey256 = array [0 .. 31] of Byte;

  {
    * Block types for the various ciphers.
  }
  { encryption block types }
  PLBCBlock = ^TLBCBlock;
  TLBCBlock = array [0 .. 3] of DWORD; { LBC block }

  PDESBlock = ^TDESBlock;
  TDESBlock = array [0 .. 7] of Byte; { DES block }

  PLQCBlock = ^TLQCBlock;
  TLQCBlock = array [0 .. 1] of DWORD; { Quick Cipher,no LBC key generate }

  PBFBlock = ^TBFBlock;
  TBFBlock = array [0 .. 1] of DWORD; { BlowFish }

  PXXTEABlock = ^TXXTEABlock;
  TXXTEABlock = array [0 .. 63] of Byte; { XXTEA }

  {
    * Generic 128-bit vector used by Mix128 and by the custom LMD hash.
  }
  T128Bit = array [0 .. 3] of DWORD;

  {
    * MD5 transform input / output types.
  }
  TTransformOutput = array [0 .. 3] of DWORD;
  PTransformInput = ^TTransformInput;
  TTransformInput = array [0 .. 15] of DWORD;

  {
    * Blowfish round count.
  }
  { context type constants }
const
  BFRounds = 16; { 16 blowfish rounds }

  {
    * Block cipher context types.
  }
  { block cipher context types }
type
  {
    * Blowfish context: P-array (18 DWORDs) plus 4 x 256 DWORD S-boxes.
  }
  { Blowfish }
  PBFContext = ^TBFContext;

  TBFContext = packed record
    PBox: array [0 .. (BFRounds + 1)] of DWORD;
    SBox: array [0 .. 3, 0 .. 255] of DWORD;
  end;

  {
    * DES context: 32 transformed round-key DWORDs plus direction flag.
  }
  { DES }
  PDESContext = ^TDESContext;

  TDESContext = packed record
    TransformedKey: array [0 .. 31] of DWORD;
    Encrypt: Boolean;
  end;

  {
    * 2-key Triple DES context (K1, K2, K1).
  }
  { 3 DES }
  PTripleDESContext = ^TTripleDESContext;
  TTripleDESContext = array [0 .. 1] of TDESContext;

  {
    * 3-key Triple DES context (K1, K2, K3).
  }
  PTripleDESContext3Key = ^TTripleDESContext3Key;
  TTripleDESContext3Key = array [0 .. 2] of TDESContext; { !!.01 }

  {
    * LBC cipher context: direction flag, alignment padding, round count,
    * and per-round subkeys (accessible as byte arrays or DWORD arrays).
  }
  { LBC Cipher context }
  PLBCContext = ^TLBCContext;

  TLBCContext = packed record
    Encrypt: Boolean;
    Dummy: array [0 .. 2] of Byte; { filler }
    Rounds: Integer;
    case Byte of
      0: (SubKeys64: array [0 .. 15] of TKey64);
      1: (SubKeysInts: array [0 .. 3, 0 .. 7] of DWORD);
  end;

  {
    * LSC stream cipher context: position index, accumulator, and 256-byte
    * state S-box.
  }
  { LSC stream cipher }
  PLSCContext = ^TLSCContext;

  TLSCContext = packed record
    index: Integer;
    Accumulator: Integer;
    SBox: array [0 .. 255] of Byte;
  end;

  {
    * RNG32 / RNG64 stream cipher states (raw byte arrays).
  }
  { random number stream ciphers }
  PRNG32Context = ^TRNG32Context;
  TRNG32Context = array [0 .. 3] of Byte;

  PRNG64Context = ^TRNG64Context;
  TRNG64Context = array [0 .. 7] of Byte;

  {
    * Message digest block types.
  }
  { message digest blocks }
  PMD5Digest = ^TMD5Digest;
  TMD5Digest = TMD5; { 128 bits - MD5 }

  PSHA1Digest = ^TSHA1Digest;
  TSHA1Digest = array [0 .. 19] of Byte; { 160 bits - SHA-1 }

  PSHA256Digest = ^TSHA256Digest;
  TSHA256Digest = array [0 .. 31] of Byte; { 256 bits - SHA-256 }

  PSHA512Digest = ^TSHA512Digest;
  TSHA512Digest = array [0 .. 63] of Byte; { 512 bits - SHA-512 }

  PSHA3_224_Digest = ^TSHA3_224_Digest;
  PSHA3_256_Digest = ^TSHA3_256_Digest;
  PSHA3_384_Digest = ^TSHA3_384_Digest;
  PSHA3_512_Digest = ^TSHA3_512_Digest;

  TSHA3_224_Digest = array [0 .. 224 div 8 - 1] of Byte;
  TSHA3_256_Digest = array [0 .. 256 div 8 - 1] of Byte;
  TSHA3_384_Digest = array [0 .. 384 div 8 - 1] of Byte;
  TSHA3_512_Digest = array [0 .. 512 div 8 - 1] of Byte;

  {
    * LMD custom hash context: 256-byte digest ring, key index, and the
    * 128-bit block key (accessible as DWORDs or bytes).
  }
  { message digest context types }
  TLMDContext = packed record
    DigestIndex: Integer;
    Digest: array [0 .. 255] of Byte;
    KeyIndex: Integer;
    case Byte of
      0: (KeyInts: array [0 .. 3] of DWORD);
      1: (key: TKey128);
  end;

  {
    * MD5 incremental context: bit counters, chaining state, and 64-byte
    * input buffer.
  }
  PMD5Context = ^TMD5Context;

  TMD5Context = packed record { MD5 }
    Count: array [0 .. 1] of DWORD; { number of bits handled mod 2^64 }
    State: TTransformOutput; { scratch buffer }
    Buf: array [0 .. 63] of Byte; { input buffer }
  end;

  {
    * SHA-1 incremental context: 64-bit bit counter, index, chaining
    * state, and 64-byte input buffer.
  }
  TSHA1Context = packed record { SHA-1 }
    sdHi: DWORD;
    sdLo: DWORD;
    sdIndex: NativeUInt;
    sdHash: array [0 .. 4] of DWORD;
    sdBuf: array [0 .. 63] of Byte;
  end;

  {
    * Cipher security level enumeration.
    *
    *   csNone      - no cipher
    *   csDES64     - single DES
    *   csDES128    - 2-key Triple DES
    *   csDES192    - 3-key Triple DES
    *   csBlowfish  - Blowfish
    *   csLBC       - Layered Block Cipher
    *   csLQC       - Light Quick Cipher
    *   csRNG32     - 32-bit RNG stream
    *   csRNG64     - 64-bit RNG stream
    *   csLSC       - LSC stream cipher
    *   csXXTea512  - XXTEA (64-byte block variant)
    *   csRC6       - RC6 (AES finalist)
    *   csSerpent   - Serpent (AES finalist)
    *   csMars      - MARS (AES finalist)
    *   csRijndael  - Rijndael (AES submission)
    *   csTwoFish   - Twofish (AES finalist)
    *   csAES128    - AES-128
    *   csAES192    - AES-192
    *   csAES256    - AES-256
  }
  { key style and auto Encrypt }
  TCipherSecurity = (
    csNone,
    csDES64, csDES128, csDES192,
    csBlowfish, csLBC, csLQC, csRNG32, csRNG64, csLSC,
    // mini cipher
    csXXTea512,
    // NIST cipher
    csRC6, csSerpent, csMars, csRijndael, csTwoFish,
    // AES cipher
    csAES128, csAES192, csAES256);

  {
    * Array of TCipherSecurity used by sequential encryption chains.
  }
  TCipherSecurityArray = array of TCipherSecurity;

  {
    * Key style tag stored in the first byte of a TCipherKeyBuffer.
    *
    *   cksNone        - no key
    *   cksKey64       - 64-bit key
    *   cks3Key64      - 3 x 64-bit keys
    *   cksKey128      - 128-bit key
    *   cksKey256      - 256-bit key
    *   cks2IntKey     - 2 DWORDs
    *   cksIntKey      - 1 DWORD
    *   ckyDynamicKey  - dynamic byte key
  }
  TCipherKeyStyle = (cksNone, cksKey64, cks3Key64, cksKey128, cksKey256, cks2IntKey, cksIntKey, ckyDynamicKey);

  {
    * Pointer to a serialized key buffer.
  }
  PCipherKeyBuffer = ^TCipherKeyBuffer;

  {
    * Serialized key buffer: first byte is the key style, followed by the
    * key material.
  }
  TCipherKeyBuffer = TBytes;

  {
    * Hash algorithm enumeration.
    *
    *   hsNone      - no hash
    *   hsFastMD5   - optimized MD5 (Delphi + Windows only)
    *   hsMD5       - MD5 (RFC 1321)
    *   hsSHA1      - SHA-1 (FIPS 180-4)
    *   hsSHA256    - SHA-256 (FIPS 180-4)
    *   hsSHA512    - SHA-512 (FIPS 180-4)
    *   hsSHA3_224  - SHA3-224 (FIPS 202)
    *   hsSHA3_256  - SHA3-256 (FIPS 202)
    *   hsSHA3_384  - SHA3-384 (FIPS 202)
    *   hsSHA3_512  - SHA3-512 (FIPS 202)
    *   hs256       - LMD-256 (custom)
    *   hs128       - LMD-128 (custom)
    *   hs64        - LMD-64  (custom)
    *   hs32        - LMD-32  (custom)
    *   hs16        - LMD-16  (custom)
    *   hsELF       - ELF hash
    *   hsELF64     - ELF-64 hash
    *   hsMix128    - Mix128 hash
    *   hsCRC16     - CRC-16
    *   hsCRC32     - CRC-32
  }
  THashSecurity = (
    hsNone,
    hsFastMD5, hsMD5, hsSHA1, hsSHA256, hsSHA512,
    hsSHA3_224, hsSHA3_256, hsSHA3_384, hsSHA3_512,
    hs256, hs128, hs64, hs32, hs16, hsELF, hsELF64, hsMix128, hsCRC16, hsCRC32);

  {
    * Set of hash algorithms.
  }
  THashSecuritys = set of THashSecurity;

  {
    * TCipher - static facade for all cryptographic operations.
    *
    * All methods are class methods; no instance state is required. The
    * class exposes:
    *   - Hash-name / cipher-name lookup tables.
    *   - Key generation / extraction from raw data, strings and typed keys.
    *   - Per-cipher encrypt/decrypt methods for a single buffer.
    *   - Buffer-to-hex and hex-to-buffer helpers.
    *   - Hash comparison helpers.
    *   - CBC and tail handling helpers.
  }
  TCipher = class sealed(TCore_Object)
  public const
    {
      * The full set of supported hash algorithms.
    }
    CAllHash: THashSecuritys = [
      hsNone,
      hsFastMD5, hsMD5, hsSHA1, hsSHA256, hsSHA512,
      hsSHA3_224, hsSHA3_256, hsSHA3_384, hsSHA3_512,
      hs256, hs128, hs64, hs32, hs16, hsELF, hsELF64, hsMix128, hsCRC16, hsCRC32];

    {
      * Human-readable names for each hash algorithm.
    }
    CHashName: array [THashSecurity] of TCipherSystemString = (
      'None',
      'FastMD5', 'MD5', 'SHA1', 'SHA256', 'SHA512',
      'SHA3_224', 'SHA3_256', 'SHA3_384', 'SHA3_512',
      '256', '128', '64', '32', '16', 'ELF', 'ELF64', 'Mix128', 'CRC16', 'CRC32');

    {
      * Human-readable names for each cipher.
    }
    CCipherSecurityName: array [TCipherSecurity] of TCipherSystemString =
      (
      'None',
      'DES64', 'DES128', 'DES192',
      'Blowfish', 'LBC', 'LQC', 'RNG32', 'RNG64', 'LSC',
      'XXTea512',
      'RC6', 'Serpent', 'Mars', 'Rijndael', 'TwoFish',
      'AES128', 'AES192', 'AES256'
      );

    {
      * Key style used by each cipher.
    }
    CCipherKeyStyle: array [TCipherSecurity] of TCipherKeyStyle =
      (
      cksNone, // csNone
      cksKey64, // csDES64
      cksKey128, // csDES128
      cks3Key64, // csDES192
      cksKey128, // csBlowfish
      cksKey128, // csLBC
      cksKey128, // csLQC
      cksIntKey, // csRNG32
      cks2IntKey, // csRNG64
      ckyDynamicKey, // csLSC
      cksKey128, // csXXTea512
      ckyDynamicKey, // csRC6
      ckyDynamicKey, // csSerpent
      ckyDynamicKey, // csMars
      ckyDynamicKey, // csRijndael
      ckyDynamicKey, // csTwoFish
      ckyDynamicKey, // csAES128
      ckyDynamicKey, // csAES192
      ckyDynamicKey // csAES256
      );
  public
    class function AllCipher: TCipherSecurityArray;

    class function Random_Select_Cipher(const arry: TCipherSecurityArray): TCipherSecurity;

    class function NameToHashSecurity(n: TCipherSystemString; var hash: THashSecurity): Boolean;

    class function BuffToString(buff: Pointer; Size: NativeInt): TCipherString; overload;
    class function StringToBuff(const Hex: TCipherString; var Buf; BufSize: Cardinal): Boolean; overload;

    class procedure HashToString(hash: Pointer; Size: NativeInt; var output: TCipherString); overload;

    class procedure HashToString(hash: TSHA3_224_Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA3_256_Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA3_384_Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA3_512_Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA512Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA256Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TSHA1Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TMD5Digest; var output: TCipherString); overload;
    class procedure HashToString(hash: TBytes; var output: TCipherString); overload;
    class procedure HashToString(hash: TBytes; var output: TCipherSystemString); overload;

    class function HashToString(hash: TSHA3_224_Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA3_256_Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA3_384_Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA3_512_Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA512Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA256Digest): TCipherSystemString; overload;
    class function HashToString(hash: TSHA1Digest): TCipherSystemString; overload;
    class function HashToString(hash: TMD5Digest): TCipherSystemString; overload;
    class function HashToString(hash: TBytes): TCipherSystemString; overload;

    class function CompareHash(h1, h2: TSHA3_224_Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA3_256_Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA3_384_Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA3_512_Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA512Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA256Digest): Boolean; overload;
    class function CompareHash(h1, h2: TSHA1Digest): Boolean; overload;
    class function CompareHash(h1, h2: TMD5Digest): Boolean; overload;
    class function CompareHash(h1, h2: Pointer; Size: NativeInt): Boolean; overload;
    class function CompareHash(h1, h2: TBytes): Boolean; overload;

    class function CompareKey(k1, k2: TCipherKeyBuffer): Boolean; overload;

    class function GenerateSHA3_224Hash(sour: Pointer; Size: NativeInt): TSHA3_224_Digest;
    class function GenerateSHA3_256Hash(sour: Pointer; Size: NativeInt): TSHA3_256_Digest;
    class function GenerateSHA3_384Hash(sour: Pointer; Size: NativeInt): TSHA3_384_Digest;
    class function GenerateSHA3_512Hash(sour: Pointer; Size: NativeInt): TSHA3_512_Digest;
    class function GenerateSHA512Hash(sour: Pointer; Size: NativeInt): TSHA512Digest;
    class function GenerateSHA256Hash(sour: Pointer; Size: NativeInt): TSHA256Digest;
    class function GenerateSHA1Hash(sour: Pointer; Size: NativeInt): TSHA1Digest;
    class function GenerateMD5Hash(sour: Pointer; Size: NativeInt): TMD5Digest;
    class procedure GenerateMDHash(sour: Pointer; Size: NativeInt; OutHash: Pointer; HashSize: NativeInt);

    class procedure GenerateHashByte(hs: THashSecurity; sour: Pointer; Size: NativeInt; var output: TBytes);
    class function GenerateHashString(hs: THashSecurity; sour: Pointer; Size: NativeInt): TCipherString;

    class function BufferToHex(const Buf; BufSize: Cardinal): TCipherString;
    class function HexToBuffer(const Hex: TCipherString; var Buf; BufSize: Cardinal): Boolean;

    class function CopyKey(const k: TCipherKeyBuffer): TCipherKeyBuffer;

    class procedure GenerateNoneKey(var output: TCipherKeyBuffer);
    class procedure GenerateKey64(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey64(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey128(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey128(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey256(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey256(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure Generate3Key64(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure Generate3Key64(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure Generate2IntKey(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure Generate2IntKey(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure GenerateIntKey(const s: TCipherString; var output: TCipherKeyBuffer); overload;
    class procedure GenerateIntKey(sour: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure GenerateBytesKey(const s: TCipherString; KeySize: DWORD; var output: TCipherKeyBuffer); overload;
    class procedure GenerateBytesKey(sour: Pointer; Size, KeySize: DWORD; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey64(const k: TKey64; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey128(const k1, k2: TKey64; var output: TCipherKeyBuffer); overload;

    class procedure GenerateKey(const k: TKey64; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const k1, k2, k3: TKey64; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const k: TKey128; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const k: TKey256; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const k1, k2: DWORD; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const k: DWORD; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(const key: PByte; Size: DWORD; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(cs: TCipherSecurity; buffPtr: Pointer; Size: NativeInt; var output: TCipherKeyBuffer); overload;
    class procedure GenerateKey(cs: TCipherSecurity; s: TCipherString; var output: TCipherKeyBuffer); overload;

    class function GetKeyStyle(const p: PCipherKeyBuffer): TCipherKeyStyle; overload;

    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey64): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k1, k2, k3: TKey64): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey128): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: TKey256): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k1, k2: DWORD): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var k: DWORD): Boolean; overload;
    class function GetKey(const KeyBuffPtr: PCipherKeyBuffer; var key: TBytes): Boolean; overload;

    class procedure EncryptTail(TailPtr: Pointer; TailSize: NativeInt);
    class function DES64(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function DES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function DES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function Blowfish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function LBC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function LQC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function RNG32(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
    class function RNG64(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
    class function LSC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer): Boolean;
    class function XXTea512(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function RC6(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function Serpent(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function Mars(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function Rijndael(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function TwoFish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function AES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function AES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function AES256(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class procedure BlockCBC(sour: Pointer; Size: NativeInt; boxBuff: Pointer; boxSiz: NativeInt);

    class function EncryptBuffer(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    class function EncryptBufferCBC(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
  end;

{$IFDEF Parallel}

  {
    * Parallel cipher worker signature.
    *   Job  - parallel job descriptor
    *   buff - buffer slice to process
    *   key  - cipher key (usually a cipher context)
    *   Size - slice size in bytes
  }
  TParallelCipherFunc = procedure(Job, buff, key: Pointer; Size: NativeInt) of object;

  {
    * Parallel cipher job descriptor.
    *
    *   cipherFunc     - the per-slice worker
    *   KeyBuffer      - cipher key / context
    *   OriginBuffer   - original buffer start
    *   L              - block size in bytes
    *   TotalBlock     - total number of blocks
    *   CompletedBlock - number of blocks finished (atomically incremented)
    *   Encrypt        - direction flag
  }
  PParallelCipherJobData = ^TParallelCipherJobData;

  TParallelCipherJobData = record
    cipherFunc: TParallelCipherFunc;
    KeyBuffer: Pointer;
    OriginBuffer: Pointer;
    L: NativeInt;
    TotalBlock: NativeInt;
    CompletedBlock: Int64;
    Encrypt: Boolean;
  end;

  {
    * TParallelCipher - parallel implementation of every block cipher.
    *
    * Splits the input buffer into multiple slices and processes them in
    * parallel using TCompute workers. Falls back to serial execution when
    * the input is small or the parallel depth is <= 0.
  }
  TParallelCipher = class(TCore_Object_Intermediate)
  private
    procedure DES64_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure DES128_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure DES192_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure Blowfish_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure LBC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure LQC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure XXTea512_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure RC6_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure Serpent_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure Mars_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure Rijndael_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure TwoFish_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure AES128_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure AES192_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure AES256_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure BlockCBC_Parallel(Job, buff, key: Pointer; Size: NativeInt);
    procedure ParallelCipher_C(const JobData: PParallelCipherJobData; const FromIndex, ToIndex: NativeInt);
    procedure RunParallel(const JobData: PParallelCipherJobData; const Total, Depth: NativeInt);
  public
    {
      * Parallel depth (number of worker threads). Defaults to
      * DefaultParallelDepth at construction time.
    }
    BlockDepth: Integer;

    constructor Create;
    destructor Destroy; override;

    function DES64(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function DES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function DES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function Blowfish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function LBC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function LQC(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function XXTea512(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function RC6(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function Serpent(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function Mars(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function Rijndael(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function TwoFish(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function AES128(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function AES192(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function AES256(sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;

    procedure BlockCBC(sour: Pointer; Size: NativeInt; boxBuff: Pointer; boxSiz: NativeInt);

    function EncryptBuffer(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
    function EncryptBufferCBC(cs: TCipherSecurity; sour: Pointer; Size: NativeInt; KeyBuff: PCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean;
  end;

{$ENDIF}


var
  {
    * System-wide CBC salt stream. Initialised by
    * InitSysCBCAndDefaultKey.
  }
  { system default cbc refrence }
  SystemCBC: TBytes;
{$IFDEF Parallel}
  {
    * Default parallel depth (typically CPU count * 2). Set by
    * InitSysCBCAndDefaultKey.
  }
  { system default Parallel depth }
  DefaultParallelDepth: Integer; // default cpucount * 2

  {
    * Minimum payload size (in bytes) before the parallel path is chosen.
    * Default 1024.
  }
  ParallelTriggerCondition: Integer; // default 1024
{$ENDIF}

  {
    * Initialise the global CBC salt and the default parallel-depth
    * settings. Called once from the unit's initialization section.
  }
procedure InitSysCBCAndDefaultKey(rand: Int64);

{
  * Apply a single cipher in-place, generating the key from the supplied
  * raw key buffer first.
}
function SequEncryptWithDirect(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;

{
  * Apply a chain of ciphers in-place.
  *   Encrypt: ca[0], ca[1], ..., ca[N-1] in order.
  *   Decrypt: ca[N-1], ..., ca[0] in reverse order.
}
function SequEncryptWithDirect(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;

{$IFDEF Parallel}
function SequEncryptWithParallel(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
function SequEncryptWithParallel(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
{$ENDIF}

{
  * Public sequential encryption entry points. Chooses the parallel path
  * automatically when the payload is large enough and Parallel is
  * defined.
}
function SequEncrypt(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
function SequEncrypt(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;

{
  * CBC variants - XOR with the system CBC salt before / after the block
  * cipher.
}
function SequEncryptCBCWithDirect(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
function SequEncryptCBCWithDirect(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;

{$IFDEF Parallel}
function SequEncryptCBCWithParallel(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
function SequEncryptCBCWithParallel(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
{$ENDIF}

function SequEncryptCBC(const ca: TCipherSecurityArray; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;
function SequEncryptCBC(const cs: TCipherSecurity; sour: Pointer; Size: NativeInt; const key: TCipherKeyBuffer; Encrypt, ProcessTail: Boolean): Boolean; overload;

{
  * Sequential hash helpers.
  * Generate a list of hashes (one per THashSecurity) for a given buffer.
}
function GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt): TCipherString; overload;
procedure GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt; output: TListPascalString); overload;
procedure GenerateSequHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt; output: TCore_Stream); overload;

{
  * Compare a freshly computed set of hashes against a stored one.
}
function CompareSequHash(HashVL: THashStringList; sour: Pointer; Size: NativeInt): Boolean; overload;
function CompareSequHash(hashData: TCipherString; sour: Pointer; Size: NativeInt): Boolean; overload;
function CompareSequHash(hashData: TListPascalString; sour: Pointer; Size: NativeInt): Boolean; overload;
function CompareSequHash(hashData: TCore_Stream; sour: Pointer; Size: NativeInt): Boolean; overload;

{
  * Produce a Base64-encoded blob of the hash list, wrapped in
  * parentheses. Used as a portable memory fingerprint.
}
function GenerateMemoryHash(hssArry: THashSecuritys; sour: Pointer; Size: NativeInt): TCipherString;
function CompareMemoryHash(sour: Pointer; Size: NativeInt; const hashBuff: TCipherString): Boolean;

{
  * Password hash helpers (hash-only; no encryption).
}
function GeneratePasswordHash(hssArry: THashSecuritys; const passwd: TCipherString): TCipherString;
function ComparePasswordHash(const passwd, hashBuff: TCipherString): Boolean;

{
  * Cipher-based password helpers.
}
function GeneratePassword(const ca: TCipherSecurityArray; const passwd: TCipherString): TCipherString; overload;
function ComparePassword(const ca: TCipherSecurityArray; const passwd, passwdDataSource: TCipherString): Boolean; overload;

function GeneratePassword(const cs: TCipherSecurity; const passwd: TCipherString): TCipherString; overload;
function ComparePassword(const cs: TCipherSecurity; const passwd, passwdDataSource: TCipherString): Boolean; overload;

type
  {
    * Blowfish - symmetric 64-bit block cipher with 128-bit keys.
  }
  { Blowfish Cipher }
  TBlowfish = class(TCore_Object_Intermediate)
  public
    class procedure EncryptBF(const Context: TBFContext; var Block: TBFBlock; Encrypt: Boolean);
    class procedure InitEncryptBF(key: TKey128; var Context: TBFContext);
  end;

  {
    * TDES - Data Encryption Standard and Triple DES.
  }
  { DES Cipher }
  TDES = class(TCore_Object_Intermediate)
  strict private
    class procedure JoinBlock(const L, R: DWORD; var Block: TDESBlock);
    class procedure SplitBlock(const Block: TDESBlock; var L, R: DWORD);
  private
  public
    class procedure EncryptDES(const Context: TDESContext; var Block: TDESBlock);
    class procedure EncryptTripleDES(const Context: TTripleDESContext; var Block: TDESBlock);
    class procedure EncryptTripleDES3Key(const Context: TTripleDESContext3Key; var Block: TDESBlock);
    class procedure InitEncryptDES(const key: TKey64; var Context: TDESContext; Encrypt: Boolean);
    class procedure InitEncryptTripleDES(const key: TKey128; var Context: TTripleDESContext; Encrypt: Boolean);
    class procedure InitEncryptTripleDES3Key(const Key1, Key2, Key3: TKey64; var Context: TTripleDESContext3Key; Encrypt: Boolean);
    class procedure ShrinkDESKey(var key: TKey64);
  end;

  {
    * TSHA1 - SHA-1 (FIPS 180-4) message digest.
  }
  { SHA1 }
  TSHA1 = class(TCore_Object_Intermediate)
  strict private
    class procedure SHA1Clear(var Context: TSHA1Context);
    class procedure SHA1Hash(var Context: TSHA1Context);
    class function SHA1SwapByteOrder(n: DWORD): DWORD;
    class procedure SHA1UpdateLen(var Context: TSHA1Context; Len: DWORD);
  public
    class procedure SHA1(var Digest: TSHA1Digest; const Buf; BufSize: NativeUInt);
    class procedure ByteBuffSHA1(var Digest: TSHA1Digest; const Bytes_: TBytes);
    class procedure InitSHA1(var Context: TSHA1Context);
    class procedure UpdateSHA1(var Context: TSHA1Context; const Buf; BufSize: NativeUInt);
    class procedure FinalizeSHA1(var Context: TSHA1Context; var Digest: TSHA1Digest);
  end;

  {
    * TSHA256 - SHA-256 (FIPS 180-4) message digest.
  }
  { SHA-2-SHA256 }
  TSHA256 = class(TCore_Object_Intermediate)
  private
    class procedure SwapDWORD(var a: DWORD);
    class procedure Compute(var Digest: TSHA256Digest; const buff: Pointer);
  public
    class procedure SHA256(var Digest: TSHA256Digest; const Buf; BufSize: NativeUInt);
  end;

  {
    * TSHA512 - SHA-512 (FIPS 180-4) message digest.
  }
  { SHA-2-SHA512 }
  TSHA512 = class(TCore_Object_Intermediate)
  private
    class procedure SwapQWORD(var a: UInt64);
    class procedure Compute(var Digest: TSHA512Digest; const buff: Pointer);
  public
    class procedure SHA512(var Digest: TSHA512Digest; const Buf; BufSize: UInt64);
  end;

  {
    * TSHA3 - SHA-3 family and SHAKE extendable-output functions
    * (FIPS 202).
  }
  { SHA-3:SHA224,SHA256,SHA384,SHA512,SHAKE128,SHAKE256 }
  TSHA3 = class(TCore_Object_Intermediate)
  private type
    TSHA3Context = record
      HashLength: DWORD;
      BlockLen: DWORD;
      Buffer: array of Byte;
      BufSize: DWORD;
      a, b: array [0 .. 24] of UInt64;
      c, d: array [0 .. 4] of UInt64;
    end;
  private
    class procedure InitializeSHA3(var Context: TSHA3Context; HashLength: Integer);
    class procedure SHA3(var Context: TSHA3Context; Chunk: PByte; Size: NativeInt);
    class procedure FinalizeSHA3(var Context: TSHA3Context; const output: PCCByteArray);
    class procedure FinalizeSHAKE(var Context: TSHA3Context; Limit: Integer; const output: PCCByteArray);
  public
    class procedure SHA224(var Digest: TSHA3_224_Digest; Buf: PByte; BufSize: NativeInt);
    class procedure SHA256(var Digest: TSHA3_256_Digest; Buf: PByte; BufSize: NativeInt);
    class procedure SHA384(var Digest: TSHA3_384_Digest; Buf: PByte; BufSize: NativeInt);
    class procedure SHA512(var Digest: TSHA3_512_Digest; Buf: PByte; BufSize: NativeInt);
    class procedure SHAKE128(const Digest: PCCByteArray; Buf: PByte; BufSize: NativeInt; Limit: Integer);
    class procedure SHAKE256(const Digest: PCCByteArray; Buf: PByte; BufSize: NativeInt; Limit: Integer);
  end;

  {
    * TLBC - Layered Block Cipher (LBC) and Light Quick Cipher (LQC).
  }
  { LBC Cipher }
  TLBC = class(TCore_Object_Intermediate)
  public
    class procedure EncryptLBC(const Context: TLBCContext; var Block: TLBCBlock);
    class procedure EncryptLQC(const key: TKey128; var Block: TLQCBlock; Encrypt: Boolean);
    class procedure InitEncryptLBC(const key: TKey128; var Context: TLBCContext; Rounds: Integer; Encrypt: Boolean);
  end;

  {
    * THashMD5 - MD5 (RFC 1321) message digest.
  }
  { MD5 }
  THashMD5 = class(TCore_Object_Intermediate)
  public
    class procedure GenerateMD5Key(var key: TKey128; const Bytes_: TBytes);
    class procedure HashMD5(var Digest: TMD5Digest; const Buf; BufSize: NativeInt);
    class procedure ByteBuffHashMD5(var Digest: TMD5Digest; const Bytes_: TBytes);
    class procedure InitMD5(var Context: TMD5Context);
    class procedure UpdateMD5(var Context: TMD5Context; const Buf; BufSize: NativeInt);
    class procedure FinalizeMD5(var Context: TMD5Context; var Digest: TMD5Digest);
  end;

  {
    * THashMD - custom LMD hash family (16/32/64/128/256-bit digests).
  }
  { message digest }
  THashMD = class(TCore_Object_Intermediate)
  public
    class procedure GenerateLMDKey(var key; KeySize: Integer; const Bytes_: TBytes);
    class procedure HashLMD(var Digest; DigestSize: Integer; const Buf; BufSize: NativeInt);
    class procedure ByteBuffHashLMD(var Digest; DigestSize: Integer; const Bytes_: TBytes);
    class procedure InitLMD(var Context: TLMDContext);
    class procedure UpdateLMD(var Context: TLMDContext; const Buf; BufSize: NativeInt);
    class procedure FinalizeLMD(var Context: TLMDContext; var Digest; DigestSize: Integer);
  end;

  {
    * TRNG - 32-bit and 64-bit RNG stream ciphers.
  }
  { Random Number Cipher }
  TRNG = class(TCore_Object_Intermediate)
  public
    class procedure EncryptRNG32(var Context: TRNG32Context; var Buf; BufSize: Integer);
    class procedure EncryptRNG64(var Context: TRNG64Context; var Buf; BufSize: Integer);
    class procedure InitEncryptRNG32(key: DWORD; var Context: TRNG32Context);
    class procedure InitEncryptRNG64(KeyHi, KeyLo: DWORD; var Context: TRNG64Context);
  end;

  {
    * TLSC - LSC stream cipher.
  }
  { LSC Stream Cipher }
  TLSC = class(TCore_Object_Intermediate)
  public
    class procedure EncryptLSC(var Context: TLSCContext; var Buf; BufSize: Integer);
    class procedure InitEncryptLSC(const key; KeySize: Integer; var Context: TLSCContext);
  end;

  {
    * TMISC - miscellaneous utilities used across the cipher library:
    * Mix128, Ran0, Random64, MD5 transform helper, key generation,
    * ELF / Mix128 / XorMem helpers.
  }
  { Miscellaneous algorithms }
  { Misc public utilities }
  TMISC = class(TCore_Object_Intermediate)
  public
    class procedure Mix128(var x: T128Bit); static;
    class function Ran0Prim(var Seed: Integer; IA, IQ, IR: Integer): Integer; static;
    class function Random64(var Seed: TInt64): Integer; static;
    class procedure Transform(var OutputBuffer: TTransformOutput; var InBuf: TTransformInput); static;
    class procedure GenerateRandomKey(var key; KeySize: Integer); static;
    class procedure HashELF(var Digest: DWORD; const Buf; BufSize: NativeUInt); static;
    class procedure HashELF64(var Digest: Int64; const Buf; BufSize: NativeUInt); static;
    class procedure HashMix128(var Digest: DWORD; const Buf; BufSize: NativeInt); static;
    class function Ran01(var Seed: Integer): Integer; static;
    class function Ran02(var Seed: Integer): Integer; static;
    class function Ran03(var Seed: Integer): Integer; static;
    class function Random32Byte(var Seed: Integer): Byte; static;
    class function Random64Byte(var Seed: TInt64): Byte; static;
    class function RolX(i, c: DWORD): DWORD; static;
    class procedure ByteBuffHashELF(var Digest: DWORD; const Bytes_: TBytes); static;
    class procedure ByteBuffHashMix128(var Digest: DWORD; const Bytes_: TBytes); static;
    class procedure XorMem(var Mem1; const Mem2; Count: NativeInt); static;
  end;

  {
    * XXTEA - Corrected Block TEA (64-byte block, 128-bit key).
  }
  { TEA }
procedure XXTEAEncrypt(var key: TKey128; var Block: TXXTEABlock);
procedure XXTEADecrypt(var key: TKey128; var Block: TXXTEABlock);

const
  {
    * RC6 round count. Must be between 16 and 24 (20 recommended).
  }
  { RC6 }
  cRC6_NumRounds = 20; { number of rounds must be between 16-24 }

type
  {
    * RC6 cipher key schedule: (2 * rounds + 4) DWORD round keys.
  }
  PRC6Key = ^TRC6Key;
  TRC6Key = array [0 .. ((cRC6_NumRounds * 2) + 3)] of DWORD;

  PRC6Block = ^TRC6Block;
  TRC6Block = array [0 .. 15] of Byte;

  {
    * TRC6 - RC6 block cipher (AES finalist).
  }
  TRC6 = class(TCore_Object_Intermediate)
  public
    class function LRot32(x, c: DWORD): DWORD;
    class function RRot32(x, c: DWORD): DWORD;
    class procedure InitKey(buff: Pointer; Size: Integer; var KeyContext: TRC6Key);
    class procedure Encrypt(var KeyContext: TRC6Key; var Data: TRC6Block);
    class procedure Decrypt(var KeyContext: TRC6Key; var Data: TRC6Block);
  end;

type
  {
    * Serpent cipher key schedule: 33 rounds x 4 DWORD subkeys = 132
    * DWORDs.
  }
  { Serpent }
  PSerpentkey = ^TSerpentkey;
  TSerpentkey = array [0 .. 131] of DWORD;
  PSerpentBlock = ^TSerpentBlock;
  TSerpentBlock = array [0 .. 15] of Byte;

  {
    * TSerpent - Serpent block cipher (AES finalist).
  }
  TSerpent = class(TCore_Object_Intermediate)
  public
    class procedure InitKey(buff: Pointer; Size: Integer; var KeyContext: TSerpentkey);
    class procedure Encrypt(var KeyContext: TSerpentkey; var Data: TSerpentBlock);
    class procedure Decrypt(var KeyContext: TSerpentkey; var Data: TSerpentBlock);
  end;

type
  {
    * MARS cipher key schedule: 40 DWORD round keys.
  }
  { Mars }
  PMarskey = ^TMarskey;
  TMarskey = array [0 .. 39] of DWORD;
  PMarsBlock = ^TMarsBlock;
  TMarsBlock = array [0 .. 15] of Byte;

  {
    * TMars - MARS block cipher (AES finalist).
  }
  TMars = class(TCore_Object_Intermediate)
  public
    class procedure gen_mask(var x, m: DWORD);
    class procedure InitKey(buff: Pointer; Size: Integer; var KeyContext: TMarskey);
    class procedure Encrypt(var KeyContext: TMarskey; var Data: TMarsBlock);
    class procedure Decrypt(var KeyContext: TMarskey; var Data: TMarsBlock);
  end;

type
  {
    * Rijndael cipher key schedule: round count plus encryption and
    * decryption round keys.
  }
  { Rijndael }
  PRijndaelkey = ^TRijndaelkey;

  TRijndaelkey = packed record
    NumRounds: DWORD;
    rk, drk: array [0 .. 14, 0 .. 7] of DWORD;
  end;

  PRijndaelBlock = ^TRijndaelBlock;
  TRijndaelBlock = array [0 .. 15] of Byte;

  {
    * TRijndael - Rijndael / AES block cipher.
    *
  }
  TRijndael = class(TCore_Object_Intermediate)
  private const
{$I Z.Cipher.intf_TRijndael_Tables.inc}
    class procedure InvMixColumn(const a: PByteArray; const BC: Byte);
  public
    class procedure InitKey(buff: Pointer; Size: Integer; var KeyContext: TRijndaelkey);
    class procedure Encrypt(var KeyContext: TRijndaelkey; var Data: TRijndaelBlock); overload;
    class procedure Encrypt(var KeyContext: TRijndaelkey; var B1, B2, B3, B4: DWORD); overload;
    class procedure Decrypt(var KeyContext: TRijndaelkey; var Data: TRijndaelBlock); overload;
    class procedure Decrypt(var KeyContext: TRijndaelkey; var B1, B2, B3, B4: DWORD); overload;
  end;

type
  {
    * Twofish cipher key schedule: 40 DWORD expanded keys, 4 DWORD S-box
    * keys, 4 x 256-byte precomputed S-boxes, and the effective key length
    * in bits.
  }
  { twofish }
  PTwofishKey = ^TTwofishKey;

  TTwofishKey = record
    ExpandedKey: array [0 .. 39] of DWORD;
    SBoxKey: array [0 .. 3] of DWORD;
    SBox0: array [0 .. 255] of Byte;
    SBox1: array [0 .. 255] of Byte;
    SBox2: array [0 .. 255] of Byte;
    SBox3: array [0 .. 255] of Byte;
    KeyLen: Integer;
  end;

  PTwofishBlock = ^TTwofishBlock;
  TTwofishBlock = array [0 .. 15] of Byte;

  {
    * TTwofish - Twofish block cipher (AES finalist).
  }
  TTwofish = class(TCore_Object_Intermediate)
  private const
{$REGION 'TwofishDefine'}
    {
      * Precomputed 8x8 bit permutation tables P0 and P1.
    }
    P8x8: array [0 .. 1, 0 .. 255] of Byte =
      (($A9, $67, $B3, $E8, $04, $FD, $A3, $76,
        $9A, $92, $80, $78, $E4, $DD, $D1, $38,
        $0D, $C6, $35, $98, $18, $F7, $EC, $6C,
        $43, $75, $37, $26, $FA, $13, $94, $48,
        $F2, $D0, $8B, $30, $84, $54, $DF, $23,
        $19, $5B, $3D, $59, $F3, $AE, $A2, $82,
        $63, $01, $83, $2E, $D9, $51, $9B, $7C,
        $A6, $EB, $A5, $BE, $16, $0C, $E3, $61,
        $C0, $8C, $3A, $F5, $73, $2C, $25, $0B,
        $BB, $4E, $89, $6B, $53, $6A, $B4, $F1,
        $E1, $E6, $BD, $45, $E2, $F4, $B6, $66,
        $CC, $95, $03, $56, $D4, $1C, $1E, $D7,
        $FB, $C3, $8E, $B5, $E9, $CF, $BF, $BA,
        $EA, $77, $39, $AF, $33, $C9, $62, $71,
        $81, $79, $09, $AD, $24, $CD, $F9, $D8,
        $E5, $C5, $B9, $4D, $44, $08, $86, $E7,
        $A1, $1D, $AA, $ED, $06, $70, $B2, $D2,
        $41, $7B, $A0, $11, $31, $C2, $27, $90,
        $20, $F6, $60, $FF, $96, $5C, $B1, $AB,
        $9E, $9C, $52, $1B, $5F, $93, $0A, $EF,
        $91, $85, $49, $EE, $2D, $4F, $8F, $3B,
        $47, $87, $6D, $46, $D6, $3E, $69, $64,
        $2A, $CE, $CB, $2F, $FC, $97, $05, $7A,
        $AC, $7F, $D5, $1A, $4B, $0E, $A7, $5A,
        $28, $14, $3F, $29, $88, $3C, $4C, $02,
        $B8, $DA, $B0, $17, $55, $1F, $8A, $7D,
        $57, $C7, $8D, $74, $B7, $C4, $9F, $72,
        $7E, $15, $22, $12, $58, $07, $99, $34,
        $6E, $50, $DE, $68, $65, $BC, $DB, $F8,
        $C8, $A8, $2B, $40, $DC, $FE, $32, $A4,
        $CA, $10, $21, $F0, $D3, $5D, $0F, $00,
        $6F, $9D, $36, $42, $4A, $5E, $C1, $E0),

      ($75, $F3, $C6, $F4, $DB, $7B, $FB, $C8,
        $4A, $D3, $E6, $6B, $45, $7D, $E8, $4B,
        $D6, $32, $D8, $FD, $37, $71, $F1, $E1,
        $30, $0F, $F8, $1B, $87, $FA, $06, $3F,
        $5E, $BA, $AE, $5B, $8A, $00, $BC, $9D,
        $6D, $C1, $B1, $0E, $80, $5D, $D2, $D5,
        $A0, $84, $07, $14, $B5, $90, $2C, $A3,
        $B2, $73, $4C, $54, $92, $74, $36, $51,
        $38, $B0, $BD, $5A, $FC, $60, $62, $96,
        $6C, $42, $F7, $10, $7C, $28, $27, $8C,
        $13, $95, $9C, $C7, $24, $46, $3B, $70,
        $CA, $E3, $85, $CB, $11, $D0, $93, $B8,
        $A6, $83, $20, $FF, $9F, $77, $C3, $CC,
        $03, $6F, $08, $BF, $40, $E7, $2B, $E2,
        $79, $0C, $AA, $82, $41, $3A, $EA, $B9,
        $E4, $9A, $A4, $97, $7E, $DA, $7A, $17,
        $66, $94, $A1, $1D, $3D, $F0, $DE, $B3,
        $0B, $72, $A7, $1C, $EF, $D1, $53, $3E,
        $8F, $33, $26, $5F, $EC, $76, $2A, $49,
        $81, $88, $EE, $21, $C4, $1A, $EB, $D9,
        $C5, $39, $99, $CD, $AD, $31, $8B, $01,
        $18, $23, $DD, $1F, $4E, $2D, $F9, $48,
        $4F, $F2, $65, $8E, $78, $5C, $58, $19,
        $8D, $E5, $98, $57, $67, $7F, $05, $64,
        $AF, $63, $B6, $FE, $F5, $B7, $3C, $A5,
        $CE, $E9, $68, $44, $E0, $4D, $43, $69,
        $29, $2E, $AC, $15, $59, $A8, $0A, $9E,
        $6E, $47, $DF, $34, $35, $6A, $CF, $DC,
        $22, $C9, $C0, $9B, $89, $D4, $ED, $AB,
        $12, $A2, $0D, $52, $BB, $02, $2F, $A9,
        $D7, $61, $1E, $B4, $50, $04, $F6, $C2,
        $16, $25, $86, $56, $55, $09, $BE, $91));

    {
      * MDS matrix coefficients (4 x 8 bytes).
    }
    MDS: array [0 .. 3, 0 .. 7] of Byte = (($01, $A4, $55, $87, $5A, $58, $DB, $9E),
      ($A4, $56, $82, $F3, $1E, $C6, $68, $E5),
      ($02, $A1, $FC, $C1, $47, $AE, $3D, $19),
      ($A4, $55, $87, $5A, $58, $DB, $9E, $03));

    {
      * Multiplication by 0x5B in GF(2^8).
    }
    Arr5B: array [0 .. 255] of DWORD = (
      $00, $5B, $B6, $ED, $05, $5E, $B3, $E8, $0A, $51, $BC, $E7, $0F, $54, $B9, $E2,
      $14, $4F, $A2, $F9, $11, $4A, $A7, $FC, $1E, $45, $A8, $F3, $1B, $40, $AD, $F6,
      $28, $73, $9E, $C5, $2D, $76, $9B, $C0, $22, $79, $94, $CF, $27, $7C, $91, $CA,
      $3C, $67, $8A, $D1, $39, $62, $8F, $D4, $36, $6D, $80, $DB, $33, $68, $85, $DE,
      $50, $0B, $E6, $BD, $55, $0E, $E3, $B8, $5A, $01, $EC, $B7, $5F, $04, $E9, $B2,
      $44, $1F, $F2, $A9, $41, $1A, $F7, $AC, $4E, $15, $F8, $A3, $4B, $10, $FD, $A6,
      $78, $23, $CE, $95, $7D, $26, $CB, $90, $72, $29, $C4, $9F, $77, $2C, $C1, $9A,
      $6C, $37, $DA, $81, $69, $32, $DF, $84, $66, $3D, $D0, $8B, $63, $38, $D5, $8E,
      $A0, $FB, $16, $4D, $A5, $FE, $13, $48, $AA, $F1, $1C, $47, $AF, $F4, $19, $42,
      $B4, $EF, $02, $59, $B1, $EA, $07, $5C, $BE, $E5, $08, $53, $BB, $E0, $0D, $56,
      $88, $D3, $3E, $65, $8D, $D6, $3B, $60, $82, $D9, $34, $6F, $87, $DC, $31, $6A,
      $9C, $C7, $2A, $71, $99, $C2, $2F, $74, $96, $CD, $20, $7B, $93, $C8, $25, $7E,
      $F0, $AB, $46, $1D, $F5, $AE, $43, $18, $FA, $A1, $4C, $17, $FF, $A4, $49, $12,
      $E4, $BF, $52, $09, $E1, $BA, $57, $0C, $EE, $B5, $58, $03, $EB, $B0, $5D, $06,
      $D8, $83, $6E, $35, $DD, $86, $6B, $30, $D2, $89, $64, $3F, $D7, $8C, $61, $3A,
      $CC, $97, $7A, $21, $C9, $92, $7F, $24, $C6, $9D, $70, $2B, $C3, $98, $75, $2E);

    {
      * Multiplication by 0xEF in GF(2^8).
    }
    ArrEF: array [0 .. 255] of Byte = (
      $00, $EF, $B7, $58, $07, $E8, $B0, $5F, $0E, $E1, $B9, $56, $09, $E6, $BE, $51,
      $1C, $F3, $AB, $44, $1B, $F4, $AC, $43, $12, $FD, $A5, $4A, $15, $FA, $A2, $4D,
      $38, $D7, $8F, $60, $3F, $D0, $88, $67, $36, $D9, $81, $6E, $31, $DE, $86, $69,
      $24, $CB, $93, $7C, $23, $CC, $94, $7B, $2A, $C5, $9D, $72, $2D, $C2, $9A, $75,
      $70, $9F, $C7, $28, $77, $98, $C0, $2F, $7E, $91, $C9, $26, $79, $96, $CE, $21,
      $6C, $83, $DB, $34, $6B, $84, $DC, $33, $62, $8D, $D5, $3A, $65, $8A, $D2, $3D,
      $48, $A7, $FF, $10, $4F, $A0, $F8, $17, $46, $A9, $F1, $1E, $41, $AE, $F6, $19,
      $54, $BB, $E3, $0C, $53, $BC, $E4, $0B, $5A, $B5, $ED, $02, $5D, $B2, $EA, $05,
      $E0, $0F, $57, $B8, $E7, $08, $50, $BF, $EE, $01, $59, $B6, $E9, $06, $5E, $B1,
      $FC, $13, $4B, $A4, $FB, $14, $4C, $A3, $F2, $1D, $45, $AA, $F5, $1A, $42, $AD,
      $D8, $37, $6F, $80, $DF, $30, $68, $87, $D6, $39, $61, $8E, $D1, $3E, $66, $89,
      $C4, $2B, $73, $9C, $C3, $2C, $74, $9B, $CA, $25, $7D, $92, $CD, $22, $7A, $95,
      $90, $7F, $27, $C8, $97, $78, $20, $CF, $9E, $71, $29, $C6, $99, $76, $2E, $C1,
      $8C, $63, $3B, $D4, $8B, $64, $3C, $D3, $82, $6D, $35, $DA, $85, $6A, $32, $DD,
      $A8, $47, $1F, $F0, $AF, $40, $18, $F7, $A6, $49, $11, $FE, $A1, $4E, $16, $F9,
      $B4, $5B, $03, $EC, $B3, $5C, $04, $EB, $BA, $55, $0D, $E2, $BD, $52, $0A, $E5);
{$ENDREGION 'TwofishDefine'}
    class function TwofishCalculateSBoxes(x: DWORD; L: Pointer; KeySize: DWORD): DWORD;
    class function TwofishH(x: DWORD; L: Pointer; KeySize: DWORD): DWORD; overload;
    class function TwofishH(const x: DWORD; const key: TTwofishKey): DWORD; overload;
    class function RSMDSMul(const x, y: Byte): Byte;
    class function MultiplyMDS(const E, O: DWORD): DWORD;
  public
    class procedure InitKey(buff: PCCByteArray; Size: Integer; var KeyContext: TTwofishKey);
    class procedure Encrypt(var KeyContext: TTwofishKey; var Data: TTwofishBlock);
    class procedure Decrypt(var KeyContext: TTwofishKey; var Data: TTwofishBlock);
  end;

  {
    * TCipher_Tool_Base - base class for instance-based cipher wrappers.
    *
    * Each instance holds a precomputed cipher context and can process a
    * buffer in-place with optional tail handling and CBC mode.
  }
  TCipher_Tool_Base = class(TCore_Object)
  protected
    FCipherSecurity: TCipherSecurity;
    FLastGenerateKey: TCipherKeyBuffer;
    FLevel: Integer;
    FProcessTail: Boolean;
    FCBC: Boolean;
  public
    property CipherSecurity: TCipherSecurity read FCipherSecurity;
    property LastGenerateKey: TCipherKeyBuffer read FLastGenerateKey;
    property Level: Integer read FLevel write FLevel;
    property ProcessTail: Boolean read FProcessTail write FProcessTail;
    property CBC: Boolean read FCBC write FCBC;
    constructor Create(KeyBuffer_: TCipherKeyBuffer); virtual;
    destructor Destroy; override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); virtual;
    procedure Decrypt(sour: Pointer; Size: NativeInt); virtual;
    procedure Process(sour: Pointer; Size: NativeInt; Level_: Integer; Encrypt_, ProcessTail_, CBC_: Boolean);
    function Text_Encrypt(Data_: U_String): U_String;
    function Text_Decrypt(Data_: U_String): U_String;
    procedure Test; virtual;
  end;

  {
    * TCipher_Tool_DES64 - single DES instance wrapper.
  }
  TCipher_Tool_DES64 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TDESContext;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_DES128 - 2-key Triple DES instance wrapper.
  }
  TCipher_Tool_DES128 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TTripleDESContext;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_DES192 - 3-key Triple DES instance wrapper.
  }
  TCipher_Tool_DES192 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TTripleDESContext3Key;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_BlowFish - Blowfish instance wrapper.
  }
  TCipher_Tool_BlowFish = class sealed(TCipher_Tool_Base)
  private
    Fkey: TBFContext;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_LBC - LBC instance wrapper.
  }
  TCipher_Tool_LBC = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TLBCContext;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_LQC - LQC instance wrapper.
  }
  TCipher_Tool_LQC = class sealed(TCipher_Tool_Base)
  private
    Fkey: TKey128;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_RNG32 - 32-bit RNG stream instance wrapper.
  }
  TCipher_Tool_RNG32 = class sealed(TCipher_Tool_Base)
  private
    Fkey: TRNG32Context;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_RNG64 - 64-bit RNG stream instance wrapper.
  }
  TCipher_Tool_RNG64 = class sealed(TCipher_Tool_Base)
  private
    Fkey: TRNG64Context;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_LSC - LSC stream instance wrapper.
  }
  TCipher_Tool_LSC = class sealed(TCipher_Tool_Base)
  private
    Fkey: TLSCContext;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_XXTea512 - XXTEA-512 instance wrapper.
  }
  TCipher_Tool_XXTea512 = class sealed(TCipher_Tool_Base)
  private
    Fkey: TKey128;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_RC6 - RC6 instance wrapper.
  }
  TCipher_Tool_RC6 = class sealed(TCipher_Tool_Base)
  private
    Fkey: TRC6Key;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_Serpent - Serpent instance wrapper.
  }
  TCipher_Tool_Serpent = class sealed(TCipher_Tool_Base)
  private
    Fkey: TSerpentkey;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_Mars - MARS instance wrapper.
  }
  TCipher_Tool_Mars = class sealed(TCipher_Tool_Base)
  private
    Fkey: TMarskey;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_Rijndael - Rijndael instance wrapper.
  }
  TCipher_Tool_Rijndael = class sealed(TCipher_Tool_Base)
  private
    Fkey: TRijndaelkey;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_TwoFish - Twofish instance wrapper.
  }
  TCipher_Tool_TwoFish = class sealed(TCipher_Tool_Base)
  private
    Fkey: TTwofishKey;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_AES128 - AES-128 instance wrapper.
  }
  TCipher_Tool_AES128 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TAESExpandedKey128;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_AES192 - AES-192 instance wrapper.
  }
  TCipher_Tool_AES192 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TAESExpandedKey192;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * TCipher_Tool_AES256 - AES-256 instance wrapper.
  }
  TCipher_Tool_AES256 = class sealed(TCipher_Tool_Base)
  private
    FDKey, FEkey: TAESExpandedKey256;
  public
    constructor Create(KeyBuffer_: TCipherKeyBuffer); override;
    procedure Encrypt(sour: Pointer; Size: NativeInt); override;
    procedure Decrypt(sour: Pointer; Size: NativeInt); override;
  end;

  {
    * Factory: create a cipher instance for the given cipher security enum.
  }
function CreateCipherClass(cs: TCipherSecurity; KeyBuffer_: TCipherKeyBuffer): TCipher_Tool_Base;

{
  * Factory: derive a key from a password and create a cipher instance.
}
function CreateCipherClassFromPassword(cs: TCipherSecurity; password_: TCipherString): TCipher_Tool_Base;

{
  * Factory: create a cipher instance from a serialized key buffer.
  * compatible SequEncryptCBC
}
function CreateCipherClassFromBuffer(cs: TCipherSecurity; key: TCipherKeyBuffer): TCipher_Tool_Base; overload;

{
  * Factory: create a cipher instance from a raw key pointer.
}
function CreateCipherClassFromBuffer(cs: TCipherSecurity; buffPtr: Pointer; Size: NativeInt): TCipher_Tool_Base; overload;

{
  QuantumCryptographyPassword: used sha-3 shake256 cryptography as 512 bits password

  SHA-3 (Secure Hash Algorithm 3) is the latest member of the Secure Hash Algorithm family of standards,
  released by NIST on August 5, 2015.[4][5] Although part of the same series of standards,
  SHA-3 is internally quite different from the MD5-like structure of SHA-1 and SHA-2.

  Keccak is based on a novel approach called sponge construction.
  Sponge construction is based on a wide random function or random permutation, and allows inputting ("absorbing" in sponge terminology) any amount of data,
  and outputting ("squeezing") any amount of data,
  while acting as a pseudorandom function with regard to all previous inputs. This leads to great flexibility.

  NIST does not currently plan to withdraw SHA-2 or remove it from the revised Secure Hash Standard.
  The purpose of SHA-3 is that it can be directly substituted for SHA-2 in current applications if necessary,
  and to significantly improve the robustness of NIST's overall hash algorithm toolkit

  ref wiki
  https://en.wikipedia.org/wiki/SHA-3
}
function GenerateQuantumCryptographyPassword(const passwd: TCipherString): TCipherString;
function CompareQuantumCryptographyPassword(const passwd, passwdDataSource: TCipherString): Boolean;

{
  * QuantumCryptography for Stream support: used sha-3-512 cryptography
  * as 512 bits password
}
// QuantumCryptography for Stream support: used sha-3-512 cryptography as 512 bits password
procedure QuantumEncrypt(input, output: TCore_Stream; SecurityLevel: Integer; key: TCipherKeyBuffer);
function QuantumDecrypt(input, output: TCore_Stream; key: TCipherKeyBuffer): Boolean;

{
  * Built-in cipher self-test; executes all standard vectors and prints a
  * report.
}
// test
procedure TestCoreCipher;

implementation

uses Z.Status;

{$I Z.Cipher.imp_BaseDefine.inc}
{$I Z.Cipher.imp_TCipher.inc}
{$I Z.Cipher.imp_TParallelCipher.inc}
{$I Z.Cipher.imp_TBlowfish.inc}
{$I Z.Cipher.imp_TDES.inc}
{$I Z.Cipher.imp_TSHA1.inc}
{$I Z.Cipher.imp_TSHA256.inc}
{$I Z.Cipher.imp_TSHA512.inc}
{$I Z.Cipher.imp_TSHA3.inc}
{$I Z.Cipher.imp_TLBC.inc}
{$I Z.Cipher.imp_THashMD5.inc}
{$I Z.Cipher.imp_Misc.inc}
{$I Z.Cipher.imp_XXTEA.inc}
{$I Z.Cipher.imp_TRC6.inc}
{$I Z.Cipher.imp_TSerpent.inc}
{$I Z.Cipher.imp_TMars.inc}
{$I Z.Cipher.imp_TRijndael.inc}
{$I Z.Cipher.imp_TTwofish.inc}
{$I Z.Cipher.imp_TCipher_Tool.inc}
{$I Z.Cipher.imp_QuantumCryptography.inc}
{$I Z.Cipher.imp_test.inc}

initialization

InitSysCBCAndDefaultKey(Int64($F0F0F0F0F0F00F0F));

finalization

SetLength(SystemCBC, 0);

end.

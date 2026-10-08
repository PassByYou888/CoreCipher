# CoreCipher — A Comprehensive Delphi and FPC Cryptography Library

CoreCipher is a high‑performance, cross‑platform cryptography library for Delphi and Free Pascal (FPC). It provides a unified interface for a wide range of cryptographic primitives—block ciphers, stream ciphers, hash functions, and password‑based key derivation—all of which have been fully standardized and verified against official reference vectors.

## What's New in This Release

The library has undergone a major overhaul, with all algorithms standardized and validated. Key changes include:

- **Full standardization** – Every hash function and symmetric cipher now conforms to its official specification and passes standard test vectors.
- **Expanded algorithm suite** – New algorithms have been added alongside the existing ones, with a consistent, unified API.
- **Cross‑platform improvements** – Enhanced support for Delphi and FPC on Windows, Linux, macOS, iOS, and Android.
- **Parallel execution** – Optional parallel processing for block ciphers when compiled with the `Parallel` define.
- **Cleaner codebase** – Removed unused types and legacy aliases; all code uses `CopyPtr`/`FillPtr` instead of `Move`/`FillChar` for better portability and optimization safety.

## Standardized Hash Functions

All hash functions below are fully standardized and validated against RFC, FIPS, or ITU‑T reference values.

| Algorithm | Standard | Output Size |
|-----------|----------|-------------|
| MD5 | RFC 1321 | 128 bits |
| SHA‑1 | FIPS 180‑4 | 160 bits |
| SHA‑256 | FIPS 180‑4 | 256 bits |
| SHA‑512 | FIPS 180‑4 | 512 bits |
| SHA3‑224 | FIPS 202 | 224 bits |
| SHA3‑256 | FIPS 202 | 256 bits |
| SHA3‑384 | FIPS 202 | 384 bits |
| SHA3‑512 | FIPS 202 | 512 bits |
| SHAKE128 | FIPS 202 | Extendable |
| SHAKE256 | FIPS 202 | Extendable |
| CRC16 | ITU‑T | 16 bits |
| CRC32 | IEEE 802.3 | 32 bits |
| ELF | Public domain | 32 bits |
| ELF64 | Public domain | 64 bits |
| Mix128 | Public domain | 32 bits |

The library also includes custom LMD‑family hashes (LMD‑16/32/64/128/256) for specialized use cases, but these are not part of any external standard.

## Standardized Symmetric Algorithms

All symmetric ciphers are standardized and validated against official test vectors (FIPS, NIST, or algorithm reference implementations).

| Algorithm | Standard | Block Size | Key Sizes |
|-----------|----------|------------|-----------|
| DES | FIPS 46‑3 | 64 bits | 64 bits |
| Triple DES (2‑key) | NIST SP 800‑67 | 64 bits | 128 bits |
| Triple DES (3‑key) | NIST SP 800‑67 | 64 bits | 192 bits |
| Blowfish | Schneier 1993 | 64 bits | 32–448 bits |
| AES‑128 | FIPS 197 | 128 bits | 128 bits |
| AES‑192 | FIPS 197 | 128 bits | 192 bits |
| AES‑256 | FIPS 197 | 128 bits | 256 bits |
| Twofish | AES submission | 128 bits | 128/192/256 bits |
| Serpent | AES submission | 128 bits | 128/192/256 bits |
| MARS | AES submission | 128 bits | 128/192/256 bits |
| RC6 | AES submission | 128 bits | 128/192/256 bits |
| Rijndael | AES submission | 128 bits | 128/192/256 bits |
| XXTEA | Corrected Block TEA | 512 bits | 128 bits |

Additionally, the library provides LBC and LQC block ciphers, RNG32/RNG64 stream ciphers, and the LSC stream cipher—these are custom algorithms designed for the Z‑Framework.

## Compilation Guide for Delphi and Lazarus/FPC

CoreCipher is designed to be compiled directly in Delphi or Lazarus/FPC **without any external dependencies**. Simply add the library's source directory to your project's search path.

### Delphi

1. Open your project in Delphi (10.2 or later recommended).
2. Go to **Tools → Options → Environment Options → Delphi Options → Library**.
3. Add the CoreCipher source directory to the **Library path** for both Win32 and Win64 (and any other target platforms you need).
4. Ensure `Z.Core.pas` and `Z.Cipher.pas` are in the search path.
5. Compile your project. The library will be linked automatically.

### Lazarus / FPC

1. Open your project in Lazarus.
2. Go to **Project → Project Options → Compiler Options → Paths**.
3. Add the CoreCipher source directory to the **Other unit files (-Fu)** field.
4. If you use the `Parallel` define, ensure the required threading units are available.
5. Build your project. No additional packages are required.

The library supports Delphi 10.2 Update 2 and later, as well as FPC 3.0.4 and later. It has been tested on Windows (x86/x64), Linux (x86/x64/ARM), macOS, iOS, and Android.

## Supported Platforms

CoreCipher has been tested on the following platforms:

- Windows x86 + x64
- Android (ARMv6, ARMv7, ARMv8/AArch64)
- iOS (ARMv7, ARMv8/AArch64)
- macOS
- Ubuntu 16.04 / 18.04 (x86, x64, ARM32/NEON)
- Raspberry Pi 3 (Debian ARMv7)
- Windows CE / Windows 10 IoT (FPC 3.3.1)

## License

CoreCipher is released under an open‑source license. See the repository for details.

---

For full documentation, examples, and the latest updates, visit the GitHub repository: [https://github.com/PassByYou888/CoreCipher](https://github.com/PassByYou888/CoreCipher).
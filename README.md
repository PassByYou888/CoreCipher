# CoreCipher

CoreCipher is a Delphi and FPC library for cryptography.  It provides support for RC6,TwoFish,AES, DES, 3DES, Blowfish, MD5,SHA1,MixFunctions,LSC,LQC, all work in parallel and mobile platform!

** supports parallel encryption/decryption **

## multi platform supported:，test with Delphi 10.2 upate 1 Tokyo and FPC 3.0.4 with Lazarus1.8

- Windows: delphi-CrossSocket(C/S OK), delphi-DIOCP(C/S OK), delphi-ICS(C/S OK), delphi-Indy(C/S OK),delphi+fpc Synapse(C/S OK)
- Android:Indy(C/S OK), CrossSocket(Only Client)
- IOS Device: Indy(C/S OK), CrossSocket(Only Client)
- IOS Simulaor: n/a
- OSX: Indy(C/S OK)，ICS(no test), CrossSocket(C/S OK)
- Ubuntu16.04 x64 server: Indy(C/S OK), CrossSocket(C/S OK)
- Ubuntu18.04 x86+x64 Desktop:only fpc3.0.4 Synapse(C/S OK)
- Ubuntu18.04 x86+x64 Server:only fpc3.0.4 Synapse(C/S OK) 
- Ubuntu18.04 arm32+arm neon Server:only fpc3.0.4 Synapse(C/S OK)
- Ubuntu18.04 arm32+arm neon desktop:only fpc3.0.4 compile ok,no test on run.  
- Ubuntu16.04 Mate arm32 desktop:only fpc3.0.4 compile ok, test passed  
- Raspberry Pi 3 Debian linux armv7 desktop,only fpc 3.0.4,test passed.
- wince(x86),windows 10 IOT,only fpc 3.3.1,test passed.
- wince(arm eabi hard flaot),windows 10 IOT,only fpc 3.3.1,test passed.

## multi cpu architectures supported，test with Delphi 10.2 upate 1 Tokyo and FPC 3.0.4 with Lazarus1.8

- MIPS(fpc-little endian), soft float, test pass on QEMU 
- intel X86(fpc-x86), soft float
- intel X86(delphi+fpc), hard float,ATHLON64,COREI,COREAVX,COREAVX2
- intel X64(fpc-x86_64), soft float
- intel X64(delphi+fpc), hard float,ATHLON64,COREI,COREAVX,COREAVX2
- ARM(fpc-arm32-eabi, hard float):ARMV3,ARMV4,ARMV4T,ARMV5,ARMV5T,ARMV5TE,ARMV5TEJ,ARMV6,ARMV6K,ARMV6T2,ARMV6Z,ARMV6M,ARMV7,ARMV7A,ARMV7R,ARMV7M,ARMV7EM
- ARM(fpc-arm64-eabi, hard float):ARMV8，aarch64



enjoy.~

# update history

### 2018-9-29

- fixed rc6 on freepascal for IOT
- IOT power on FPC support 

### 2018-7-6

- update the name rules of the Library
- Support for fpc/86/64 platform, all base libraries support for Linux.
- power support for the FPC compiler 3.1.1
- newed Big/Little Endian order support
- fixing the problem of using 32 bit FPC compiler to for with Int64
- fixed string the FPC compiler runs on Linux.

### 2018-5-21

- fixed twofish on memory leak
- update Parallel core(fpc required package:MultiThreadProcsLaz)
- added UPascalStrings.pas(fpc on unicode)


### 2018-3-1

newed Smith–Waterman algorithm

The Smith–Waterman algorithm performs local sequence alignment; that is, for determining similar regions between two strings of nucleic acid sequences or protein sequences. Instead of looking at the entire sequence, the Smith–Waterman algorithm compares segments of all possible lengths and optimizes the similarity measure.

The algorithm was first proposed by Temple F. Smith and Michael S. Waterman in 1981.[1] Like the Needleman–Wunsch algorithm, of which it is a variation, Smith–Waterman is a dynamic programming algorithm. As such, it has the desirable property that it is guaranteed to find the optimal local alignment with respect to the scoring system being used (which includes the substitution matrix and the gap-scoring scheme). The main difference to the Needleman–Wunsch algorithm is that negative scoring matrix cells are set to zero, which renders the (thus positively scoring) local alignments visible. Traceback procedure starts at the highest scoring matrix cell and proceeds until a cell with score zero is encountered, yielding the highest scoring local alignment. Because of its cubic computational complexity in time and quadratic complexity in space, it often cannot be practically applied to large-scale problems and is replaced in favor of less general but computationally more efficient alternatives such as (Gotoh, 1982),[2] (Altschul and Erickson, 1986),[3] and (Myers and Miller 1988).

https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm


create by QQ 600585@qq.com

2017-11-15

# CoreCipher

CoreCipher is a Delphi and FPC library for cryptography.  It provides support for RC6,TwoFish,AES, DES, 3DES, Blowfish, MD5,SHA1,MixFunctions,LSC,LQC, all work in parallel and mobile platform!

supports platform Win32, Win64, OSX, iOS and Android.

supports parallel encryption/decryption,(little modify and copy PasMP.pas)

PasMP.pas parallel library from https://github.com/BeRo1985/pasmp


enjoy.~

# update history

### 2018-3-1

newed Smith–Waterman algorithm

The Smith–Waterman algorithm performs local sequence alignment; that is, for determining similar regions between two strings of nucleic acid sequences or protein sequences. Instead of looking at the entire sequence, the Smith–Waterman algorithm compares segments of all possible lengths and optimizes the similarity measure.

The algorithm was first proposed by Temple F. Smith and Michael S. Waterman in 1981.[1] Like the Needleman–Wunsch algorithm, of which it is a variation, Smith–Waterman is a dynamic programming algorithm. As such, it has the desirable property that it is guaranteed to find the optimal local alignment with respect to the scoring system being used (which includes the substitution matrix and the gap-scoring scheme). The main difference to the Needleman–Wunsch algorithm is that negative scoring matrix cells are set to zero, which renders the (thus positively scoring) local alignments visible. Traceback procedure starts at the highest scoring matrix cell and proceeds until a cell with score zero is encountered, yielding the highest scoring local alignment. Because of its cubic computational complexity in time and quadratic complexity in space, it often cannot be practically applied to large-scale problems and is replaced in favor of less general but computationally more efficient alternatives such as (Gotoh, 1982),[2] (Altschul and Erickson, 1986),[3] and (Myers and Miller 1988).

https://en.wikipedia.org/wiki/Smith%E2%80%93Waterman_algorithm


create by QQ 600585@qq.com

2017-11-15

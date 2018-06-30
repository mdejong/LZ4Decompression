LZ4 decompression compared
=============================

This package contains an example iOS app that runs a decompression max MB throughput test with different decompressors.

__LZ4__ : High Comp -9 option compiled from bundled source code. [LZ4](https://github.com/lz4/lz4)

__LZ4A__ : Normal Comp -1 option in Apple's lib compression. [libcompression](https://developer.apple.com/documentation/compression/data_compression)

__FSE__ : compiled from bundled source code. [FiniteStateEntropy](https://github.com/Cyan4973/FiniteStateEntropy)

__HUFF0__ : compiled from bundled source code. [FiniteStateEntropy](https://github.com/Cyan4973/FiniteStateEntropy)

__LIZARD__ : compiled from bundled source code. [Lizard](https://github.com/inikep/lizard)

Benchmarks
-------------------------

These results are for an Apple A9 processor (iPhone SE device) compiled with optimizations on. The original input file is a grayscale image processed with a simple SUB operation from one byte to the next with an uncompressed size 3145728 or 3.1 MB. This decompression MB rate indicates the maximum amount of data that can be decompressed per second at full CPU usage.

| Codec  | Comp   | Decompression |
| ------ |:------:| -------------:|
|        |        |               |
| LZ4    |  1.40  |  1500 MB/s    |
| LZ4A   |  1.16  |  1200 MB/s    |
| FSE    |  1.76  |   300 MB/s    |
| FSET   |  1.76  |   540 MB/s    |
| HUFF0  |  1.74  |   510 MB/s    |
| HUFF0T |  1.74  |   920 MB/s    |
| LIZARD |  1.73  |   360 MB/s    |
| LIZARDT|  1.73  |   610 MB/s    |

The LZ4 HC option produces the fastest decompression time. The default lz4 compression available via the Apple provided API produced significantly worse compression in terms of size and it decompressed slower. Note that Apple also provides LZFSE and zlib compression options which produce about the same compression ratio. Apple's LZFSE is slightly faster while the zlib option is significantly slower. The FSE codec produced very effective compression results. FSE decompression was a little slow when single threaded, but the FSET target with multiple threads improves things.

The HUFF0 codec produces slightly less effective compression compared to FSE, but it is fast. When multiple threads are used for decoding (HUFF0T), things become very interesting. Because HUFF0 decoding is split up block by block, the decoding process can be run on multiple threads. Since all 64 bit iOS devices have multiple CPU cores, this results in a very nice speedup, not quite 2x, but close. The combination of high compression ratio and fast multiple CPU core performance indicates that huff0 is a strong choice.

The LIZARD results are interesting because lizard adapts lz4 to use huffman codes when encoding literals. These specific results made use of a 1 MB backward search size and GCD threading and the max compression level of 49. While LIZARD decode result is not as fast as HUFF0, this lz codec could still be optimal for input data that contains a lot of runs and backward matches since HUFF0 does entropy encoding only.


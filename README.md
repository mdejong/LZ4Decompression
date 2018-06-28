LZ4 decompression compared
=============================

This package contains an example iOS app that runs a decompression max MB throughput test with different decompressors.

__LZ4__, High Comp option compiled from bundled source code. [LZ4](https://github.com/lz4/lz4)

__LZ4 Apple__ included in Apple's lib compression. [libcompression](https://developer.apple.com/documentation/compression/data_compression)

__FSE__, compiled from bundled source code. [FiniteStateEntropy](https://github.com/Cyan4973/FiniteStateEntropy)

Benchmarks
-------------------------

These results are for an Apple A9 processor in an iPhone SE device. Compiled with optimizations on. The original input file is a grayscale image processed with a simple SUB operation from one byte to the next with uncompressed size 3145728 or 3.1 MB. This decompression MB rate indicates the maximum amount of data that can be decompressed per second at full CPU usage.

| Codec | Comp   | Decompression |
| ----- |:------:| -------------:|
|       |        |               |
| LZ4   |  1.38  |__1500 MB/s__  |
| LZ4A  |__1.16__|  1200 MB/s    |
| FSE   |  1.64  |   300 MB/s    |

The LZ4 HC option produces the fastest decompression time. The default lz4 compression available via the Apple provided API produced significantly worse compression in terms of size and it decompressed slower. The FSE codec produced very effective compression results but decompression speed was a little slow. Note that apple also provides a LZFSE and zlib compression option which produce about the same compression ratio except that Apple's LZFSE is slightly faster while the zlib is significantly slower.

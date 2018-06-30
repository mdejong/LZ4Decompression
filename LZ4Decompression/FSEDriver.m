//
//  FSEDriver.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CompressionDriver.h"

#import "FSEDriver.h"

#include "fse.h"

#define FSE_BLOCK_SIZE_SYMBOL_MAX (128 * 1024)

//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX * 2) // 460 MB
//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX * 4) // 460 MB
//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX * 8) // 360 MB

//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX/2) // 440 MB
//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX/4) // 430 MB
//#define FSE_BLOCK_SIZE_SYMBOL (FSE_BLOCK_SIZE_SYMBOL_MAX/8)   // 360 MB

// This size seems to be optimal for both compression performance and decoding time.

#define FSE_BLOCK_SIZE_SYMBOL FSE_BLOCK_SIZE_SYMBOL_MAX // 540 MB

// FSEDriver

@interface FSEDriver ()

@end

@implementation FSEDriver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  int numBlocks = (int)unencodedData.length / FSE_BLOCK_SIZE_SYMBOL;
  if ((unencodedData.length % FSE_BLOCK_SIZE_SYMBOL) != 0) {
    numBlocks += 1;
  }
  
  NSMutableData *allCompressedBytes = [NSMutableData data];
  
  NSMutableArray *mArrOfSizes = [NSMutableArray array];
  
  for ( int blocki = 0; blocki < numBlocks; blocki++ ) {
    // Allocate a dst location as large as the src to handle a worst case, it should not be close.
    
    int blockSizeInBits = FSE_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      blockSizeInBits = (int)unencodedData.length - (FSE_BLOCK_SIZE_SYMBOL * blocki);
    }
    
    uint8_t *inBytesPtr = (uint8_t *) unencodedData.bytes;
    inBytesPtr += (FSE_BLOCK_SIZE_SYMBOL * blocki);
    
    size_t worstCompressedCaseSizeInBytes = FSE_compressBound(blockSizeInBits);
    
    NSMutableData *compressedBytes = [NSMutableData dataWithLength:worstCompressedCaseSizeInBytes];
    
    //NSLog(@"compress from %d to %d (%d bytes)", (FSE_BLOCK_SIZE_SYMBOL * blocki), (FSE_BLOCK_SIZE_SYMBOL * blocki)+blockSizeInBits, blockSizeInBits);
    
    size_t compSize = FSE_compress((void*) compressedBytes.mutableBytes, (size_t)compressedBytes.length,
                                   (const void*) inBytesPtr, blockSizeInBits);
    
    if (FSE_isError(compSize)) {
      printf("FSE error : %s\n", FSE_getErrorName(compSize));
      assert(0);
    }
    
    [compressedBytes setLength:compSize];
    
    [allCompressedBytes appendData:compressedBytes];
    
    //NSLog(@"compress block to %d bytes", (int)compSize);
    
    [mArrOfSizes addObject:@(compSize)];
  }
  
  // Finally append N block sizes to the binary data, the decoder can figure out how many
  // there are from the input size
  
  for ( NSNumber *sizeNum in mArrOfSizes ) {
    uint32_t blockSize = [sizeNum unsignedIntValue];
    [allCompressedBytes appendBytes:&blockSize length:sizeof(uint32_t)];
  }
  
  return allCompressedBytes;
}

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(uint8_t*)buffer length:(int)length
{
  // Break into blocks of compressed data using a table at the end of the input data.
  
  int numBlocks = length / FSE_BLOCK_SIZE_SYMBOL;
  if ((length % FSE_BLOCK_SIZE_SYMBOL) != 0) {
    numBlocks += 1;
  }
  
  uint8_t *encodedDataPtr = (uint8_t *) encodedData.bytes;
  
  int headerNumBytes = numBlocks * sizeof(uint32_t);
  
  uint32_t header[numBlocks];
  memcpy(&header[0], encodedDataPtr + (int)encodedData.length - headerNumBytes, headerNumBytes);
  
  int blockStartOffset = 0;
  
  uint8_t *outBufferPtr = buffer;
  
#define DISPATCH_BLOCKS_GCD
  
#if defined(DISPATCH_BLOCKS_GCD)
  dispatch_group_t group = dispatch_group_create();
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
#endif // DISPATCH_BLOCKS_GCD
  
  for (int blocki = 0; blocki < numBlocks; blocki++ ) {
    int blockNumBytes = header[blocki];
    
    int decompressedBlockSize = FSE_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      decompressedBlockSize = length - (blocki * FSE_BLOCK_SIZE_SYMBOL);
    }
    
    const void * encodedBlock = encodedDataPtr + blockStartOffset;
    
    // Block capture pointers that will be decoded
    
    void (^DecompressBlock)(void) = ^void (void)
    {
      size_t result = FSE_decompress(outBufferPtr, decompressedBlockSize,
                                     encodedBlock, (size_t)blockNumBytes);
      
      if (FSE_isError(result)) {
        printf("FSE error : %s\n", FSE_getErrorName(result));
        assert(0);
      }
      
#if defined(DEBUG)
      assert(result == decompressedBlockSize);
#endif // DEBUG
    };
    
#if defined(DISPATCH_BLOCKS_GCD)
    dispatch_group_async(group, queue, ^{
      DecompressBlock();
    });
#else // DISPATCH_BLOCKS_GCD
    DecompressBlock();
#endif // DISPATCH_BLOCKS_GCD
    
    blockStartOffset += blockNumBytes;
    outBufferPtr += decompressedBlockSize;
  }
  
#if defined(DISPATCH_BLOCKS_GCD)
  dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
  //dispatch_release(group);
#endif // DISPATCH_BLOCKS_GCD
  
#if defined(DEBUG)
  assert((int)(outBufferPtr - buffer) == length);
#endif // DEBUG
  
  return TRUE;
}


/*

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
//   FSE_compress() :
//   Compress content of buffer 'src', of size 'srcSize', into destination buffer 'dst'.
//   'dst' buffer must be already allocated. Compression runs faster is dstCapacity >= FSE_compressBound(srcSize).
//   return : size of compressed data (<= dstCapacity).
//   Special values : if return == 0, srcData is not compressible => Nothing is stored within dst !!!
//   if return == 1, srcData is a single byte symbol * srcSize times. Use RLE compression instead.
//   if FSE_isError(return), compression failed (more details using FSE_getErrorName())
  
  // Allocate a dst location as large as the src to handle a worst case, it should not be close.
  
  NSMutableData *compressedBytes = [NSMutableData dataWithLength:unencodedData.length];
  
   size_t compSize = FSE_compress((void*) compressedBytes.mutableBytes, (size_t)compressedBytes.length,
                                     (const void*) unencodedData.bytes, (size_t)unencodedData.length);
  
  assert(compSize < compressedBytes.length);
  
  [compressedBytes setLength:compSize];
  
  return compressedBytes;
}

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(uint8_t*)buffer length:(int)length
{
  size_t result = FSE_decompress(buffer, length,
                                       (const void*)encodedData.bytes, (size_t)encodedData.length);
  
  result = result;
  
  // FSE_isError(result)
  
//  assert(numDecompressed == (int)encodedData.length);
  
  return TRUE;
}
 
*/

@end

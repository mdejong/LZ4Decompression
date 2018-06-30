//
//  Huff0Driver.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CompressionDriver.h"

#import "Huff0Driver.h"

#include "huf.h"

#define HUFF_BLOCK_SIZE_SYMBOL HUF_BLOCKSIZE_MAX // best decode performance
//#define HUFF_BLOCK_SIZE_SYMBOL (HUF_BLOCKSIZE_MAX/2)
//#define HUFF_BLOCK_SIZE_SYMBOL (HUF_BLOCKSIZE_MAX/4)
//#define HUFF_BLOCK_SIZE_SYMBOL (HUF_BLOCKSIZE_MAX/8)
//#define HUFF_BLOCK_SIZE_SYMBOL (HUF_BLOCKSIZE_MAX/16) // best comp 1.75, but peer decode performance
//#define HUFF_BLOCK_SIZE_SYMBOL (HUF_BLOCKSIZE_MAX/32)

// Huff0Driver

@interface Huff0Driver ()

@end

@implementation Huff0Driver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  int numBlocks = (int)unencodedData.length / HUFF_BLOCK_SIZE_SYMBOL;
  if ((unencodedData.length % HUFF_BLOCK_SIZE_SYMBOL) != 0) {
    numBlocks += 1;
  }
  
  NSMutableData *allCompressedBytes = [NSMutableData data];
  
  NSMutableArray *mArrOfSizes = [NSMutableArray array];
  
  for ( int blocki = 0; blocki < numBlocks; blocki++ ) {
    // Allocate a dst location as large as the src to handle a worst case, it should not be close.
    
    int blockSizeInBits = HUFF_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      blockSizeInBits = (int)unencodedData.length - (HUFF_BLOCK_SIZE_SYMBOL * blocki);
    }
    
    uint8_t *inBytesPtr = (uint8_t *) unencodedData.bytes;
    inBytesPtr += (HUFF_BLOCK_SIZE_SYMBOL * blocki);
    
    size_t worstCompressedCaseSizeInBytes = HUF_compressBound(blockSizeInBits);
    
    NSMutableData *compressedBytes = [NSMutableData dataWithLength:worstCompressedCaseSizeInBytes];
    
    //NSLog(@"compress from %d to %d (%d bytes)", (HUFF_BLOCK_SIZE_SYMBOL * blocki), (HUFF_BLOCK_SIZE_SYMBOL * blocki)+blockSizeInBits, blockSizeInBits);
    
    size_t compSize = HUF_compress((void*) compressedBytes.mutableBytes, (size_t)compressedBytes.length,
                                   (const void*) inBytesPtr, blockSizeInBits);
    
    if (HUF_isError(compSize)) {
      printf("Huff0 error : %s\n", HUF_getErrorName(compSize));
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
 
  int numBlocks = length / HUFF_BLOCK_SIZE_SYMBOL;
  if ((length % HUFF_BLOCK_SIZE_SYMBOL) != 0) {
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
    
    int decompressedBlockSize = HUFF_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      decompressedBlockSize = length - (blocki * HUFF_BLOCK_SIZE_SYMBOL);
    }
    
    const void * encodedBlock = encodedDataPtr + blockStartOffset;

    // Block capture pointers that will be decoded
    
    void (^DecompressBlock)(void) = ^void (void)
    {
      size_t result = HUF_decompress(outBufferPtr, decompressedBlockSize,
                                     encodedBlock, (size_t)blockNumBytes);
      
      if (HUF_isError(result)) {
        printf("Huff0 error : %s\n", HUF_getErrorName(result));
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

@end

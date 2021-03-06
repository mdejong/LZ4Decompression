//
//  LizardDriver.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CompressionDriver.h"

#import "LizardDriver.h"

#include "lizard_compress.h"
#include "lizard_decompress.h"

//#define LIZARD_BLOCK_SIZE_SYMBOL LIZARD_BLOCK64K_SIZE // 64 KB = 0xFFFF
//#define LIZARD_BLOCK_SIZE_SYMBOL LIZARD_BLOCK_SIZE    // 128 KB

// 2   MB buffer : encoded 1818345 : 1.73 : 730 MB decode speed
// 1   MB buffer : encoded 1820560 : 1.73 : 620 MB decode speed
// 1/2 MB buffer : encoded 1824727 : 1.72 : 745 MB decode speed
// 1/4 MB buffer : encoded 1833097 : 1.72 : 720 MB decode speed
// 1/8 MB buffer : encoded 1849761 : 1.70 : 675 MB decode speed

//#define LIZARD_BLOCK_SIZE_SYMBOL ((1024 * 1024) * 2)
//#define LIZARD_BLOCK_SIZE_SYMBOL (1024 * 1024)
#define LIZARD_BLOCK_SIZE_SYMBOL ((1024 * 1024) / 2)
//#define LIZARD_BLOCK_SIZE_SYMBOL ((1024 * 1024) / 4)
//#define LIZARD_BLOCK_SIZE_SYMBOL ((1024 * 1024) / 8)

//#define LIZARD_BLOCK_SIZE_SYMBOL LIZARD_MAX_INPUT_SIZE // no threading when this large

// LizardDriver

@interface LizardDriver ()

@end

@implementation LizardDriver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  int numBlocks = (int)unencodedData.length / LIZARD_BLOCK_SIZE_SYMBOL;
  if ((unencodedData.length % LIZARD_BLOCK_SIZE_SYMBOL) != 0) {
    numBlocks += 1;
  }
  
  NSMutableData *allCompressedBytes = [NSMutableData data];
  
  NSMutableArray *mArrOfSizes = [NSMutableArray array];
  
  for ( int blocki = 0; blocki < numBlocks; blocki++ ) {
    // Allocate a dst location as large as the src to handle a worst case, it should not be close.
    
    int blockSizeInBits = LIZARD_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      blockSizeInBits = (int)unencodedData.length - (LIZARD_BLOCK_SIZE_SYMBOL * blocki);
    }
    
    uint8_t *inBytesPtr = (uint8_t *) unencodedData.bytes;
    inBytesPtr += (LIZARD_BLOCK_SIZE_SYMBOL * blocki);
    
    size_t worstCompressedCaseSizeInBytes = Lizard_compressBound(blockSizeInBits);
    
    NSMutableData *compressedBytes = [NSMutableData dataWithLength:worstCompressedCaseSizeInBytes];
    
    //NSLog(@"compress from %d to %d (%d bytes)", (LIZARD_BLOCK_SIZE_SYMBOL * blocki), (LIZARD_BLOCK_SIZE_SYMBOL * blocki)+blockSizeInBits, blockSizeInBits);
    
    // Max huffman encoding setting
    
    // 29 : 18% CPU : 1.39
    // 30 : 37% CPU : 1.46 (like lz4)
    // 35 : 46% CPU : 1.66
    // 36 : 39% CPU : 1.64
    // 39 : 31% CPU : 1.64 (fast enough on A9)
    
    size_t compSize = Lizard_compress((const void*) inBytesPtr, (void*) compressedBytes.mutableBytes, blockSizeInBits,
                                      (int)compressedBytes.length, 49);
    
    if (compSize == 0) {
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
 
  int numBlocks = length / LIZARD_BLOCK_SIZE_SYMBOL;
  if ((length % LIZARD_BLOCK_SIZE_SYMBOL) != 0) {
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
    
    int decompressedBlockSize = LIZARD_BLOCK_SIZE_SYMBOL;
    if (blocki == (numBlocks - 1)) {
      decompressedBlockSize = length - (blocki * LIZARD_BLOCK_SIZE_SYMBOL);
    }
    
    const void * encodedBlock = encodedDataPtr + blockStartOffset;

    // Block capture pointers that will be decoded
    
    void (^DecompressBlock)(void) = ^void (void)
    {
      int result = Lizard_decompress_safe((const char*)encodedBlock, (char*)outBufferPtr, blockNumBytes, decompressedBlockSize);
      
      if (result == 0) {
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

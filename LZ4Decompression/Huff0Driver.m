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

// Huff0Driver

@interface Huff0Driver ()

@end

@implementation Huff0Driver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  int numBlocks = (int)unencodedData.length / HUF_BLOCKSIZE_MAX;
  if ((unencodedData.length % HUF_BLOCKSIZE_MAX) != 0) {
    numBlocks += 1;
  }
  
  NSMutableData *allCompressedBytes = [NSMutableData data];
  
  NSMutableArray *mArrOfSizes = [NSMutableArray array];
  
  for ( int blocki = 0; blocki < numBlocks; blocki++ ) {
    // Allocate a dst location as large as the src to handle a worst case, it should not be close.
    
    int blockSizeInBits = HUF_BLOCKSIZE_MAX;
    if (blocki == (numBlocks - 1)) {
      blockSizeInBits = (int)unencodedData.length - (HUF_BLOCKSIZE_MAX * blocki);
    }
    
    uint8_t *inBytesPtr = (uint8_t *) unencodedData.bytes;
    inBytesPtr += (HUF_BLOCKSIZE_MAX * blocki);
    
    size_t worstCompressedCaseSizeInBytes = HUF_compressBound(blockSizeInBits);
    
    NSMutableData *compressedBytes = [NSMutableData dataWithLength:worstCompressedCaseSizeInBytes];
    
    //NSLog(@"compress from %d to %d (%d bytes)", (HUF_BLOCKSIZE_MAX * blocki), (HUF_BLOCKSIZE_MAX * blocki)+blockSizeInBits, blockSizeInBits);
    
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
 
  int numBlocks = length / HUF_BLOCKSIZE_MAX;
  if ((length % HUF_BLOCKSIZE_MAX) != 0) {
    numBlocks += 1;
  }
  
  uint8_t *encodedDataPtr = (uint8_t *) encodedData.bytes;
  
  int headerNumBytes = numBlocks * sizeof(uint32_t);
  
  uint32_t header[numBlocks];
  memcpy(&header[0], encodedDataPtr + (int)encodedData.length - headerNumBytes, headerNumBytes);
  
  int blockStartOffset = 0;
  
  uint8_t *outBufferPtr = buffer;
  
  for (int blocki = 0; blocki < numBlocks; blocki++ ) {
    int blockNumBytes = header[blocki];
    
    int decompressedBlockSize = HUF_BLOCKSIZE_MAX;
    if (blocki == (numBlocks - 1)) {
      decompressedBlockSize = length - (blocki * HUF_BLOCKSIZE_MAX);
    }
    
    size_t result = HUF_decompress(outBufferPtr, decompressedBlockSize,
                                   (const void*)encodedDataPtr+blockStartOffset, (size_t)blockNumBytes);
    
    if (HUF_isError(result)) {
      printf("Huff0 error : %s\n", HUF_getErrorName(result));
      assert(0);
    }
    
    assert(result == decompressedBlockSize);
    
    blockStartOffset += blockNumBytes;
    outBufferPtr += decompressedBlockSize;
  }
  
  return TRUE;
}

@end

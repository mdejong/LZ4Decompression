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
  // FIXME: break into blocks of HUF_BLOCKSIZE_MAX = 128 KB
  
  int numBlocks = (int)unencodedData.length / HUF_BLOCKSIZE_MAX;
  if ((unencodedData.length % HUF_BLOCKSIZE_MAX) > 0) {
    numBlocks += 1;
  }
  
  // Allocate a dst location as large as the src to handle a worst case, it should not be close.
  
  size_t worstCompressedCaseSizeInBytes = HUF_compressBound(unencodedData.length);
  
  NSMutableData *compressedBytes = [NSMutableData dataWithLength:worstCompressedCaseSizeInBytes];
  
  size_t compSize = HUF_compress((void*) compressedBytes.mutableBytes, (size_t)compressedBytes.length,
                                     (const void*) unencodedData.bytes, (size_t)unencodedData.length);
  
  if (HUF_isError(compSize)) {
    printf("Huff0 error : %s\n", HUF_getErrorName(compSize));
    assert(0);
  }
  assert(compSize < compressedBytes.length);
  
  [compressedBytes setLength:compSize];
  
  return compressedBytes;
}

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(uint8_t*)buffer length:(int)length
{
  size_t result = HUF_decompress(buffer, length,
                                       (const void*)encodedData.bytes, (size_t)encodedData.length);
  
  result = result;
  
  // HUF_isError(result)
  
//  assert(numDecompressed == (int)encodedData.length);
  
  return TRUE;
}

@end

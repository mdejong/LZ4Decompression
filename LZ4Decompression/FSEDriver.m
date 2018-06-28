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

// FSEDriver

@interface FSEDriver ()

@end

@implementation FSEDriver

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

@end

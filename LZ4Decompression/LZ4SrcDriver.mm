//
//  LZ4SrcDriver.mm
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CompressionDriver.h"

#import "LZ4SrcDriver.h"

#include <vector>

#define LZ4_DISABLE_DEPRECATE_WARNINGS

#include "lz4.h"
#include "lz4hc.h"

using namespace std;


// Compress vector with lz4 HC and return a vector that contains
// the compressed bytes

static inline
vector<uint8_t> compressedWithLZ4HC(const vector<uint8_t> & inBytes) {
  void *inDataPtr = (void *) inBytes.data();
  size_t srcSize = inBytes.size();
  
  size_t decompressionBufferSize = srcSize;
  
  if (decompressionBufferSize < (4096*4)) {
    decompressionBufferSize = (4096*4);
  }
  
  vector<uint8_t> compressedVec;
  compressedVec.resize(decompressionBufferSize);
  
  void *dst = (void*) compressedVec.data();
  size_t dstCapacity = compressedVec.size();
  
  clock_t startTime = clock();
  
  int comp = 9;
  
  // int LZ4_compress_HC(const char* src, char* dst, int srcSize, int dstCapacity, int compressionLevel)
  
  size_t compressedSize = LZ4_compress_HC((const char*) inDataPtr, (char*)dst, (int)srcSize, (int)dstCapacity, comp);
  
  if (compressedSize == 0) {
    printf("compression error in LZ4_compressHC\n");
    return vector<uint8_t>();
  }
  
  clock_t endTime = clock();
  clock_t deltaTime = endTime - startTime;
  
  float deltaSecs = ((float)deltaTime)/CLOCKS_PER_SEC;
  
  printf("LZ4 compression seconds %0.4f\n", deltaSecs);
  
  compressedVec.resize(compressedSize);
  
  return compressedVec;
}

// LZ4SrcDriver

@interface LZ4SrcDriver ()

@end

@implementation LZ4SrcDriver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  vector<uint8_t> inBytes;
  inBytes.resize((int)unencodedData.length);
  memcpy(inBytes.data(), unencodedData.bytes, unencodedData.length);
  
  vector<uint8_t> compressedVec = compressedWithLZ4HC(inBytes);
  
  NSData *compressedBytes = [NSData dataWithBytes:compressedVec.data() length:(int)compressedVec.size()];  
  return compressedBytes;
}

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(uint8_t*)buffer length:(int)length
{
  int numDecompressed = LZ4_decompress_fast((const char*)encodedData.bytes, (char*)buffer, (int)length);
  
  assert(numDecompressed == (int)encodedData.length);
  
  return TRUE;
}

@end

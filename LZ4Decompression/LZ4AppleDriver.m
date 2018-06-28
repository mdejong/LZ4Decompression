//
//  LZ4AppleDriver.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "CompressionDriver.h"

#import "LZ4AppleDriver.h"

#import "NSData+LAMCompression.h"

// LZ4AppleDriver

@interface LZ4AppleDriver ()

@end

@implementation LZ4AppleDriver

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData
{
  return [unencodedData lam_compressedDataUsingCompression:LAMCompressionLZ4];
}

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(char*)buffer length:(int)length
{
  /*
  NSData *decoded = [encodedData lam_uncompressedDataUsingCompression:LAMCompressionLZ4];
  memcpy(buffer, decoded.bytes, length);
  return TRUE;
   */
  
  // Optimized no alloc and no second copy
  
  BOOL worked = [encodedData lam_decompressionOneCall:LAMCompressionLZ4 buffer:buffer length:length];
  return worked;
}

@end

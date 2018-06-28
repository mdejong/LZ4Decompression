//
//  CompressionDriver.h
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/27/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol CompressionDriver <NSObject>

// Compress unencodedData and return compressed data in a buffer

- (NSData*) compressData:(NSData*)unencodedData;

// Decompress encodedData into buffer, returns TRUE on success and FALSE on failure

- (BOOL) decompressData:(NSData*)encodedData buffer:(uint8_t*)buffer length:(int)length;

@end

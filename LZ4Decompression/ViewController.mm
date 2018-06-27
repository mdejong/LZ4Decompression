//
//  ViewController.mm
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/26/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import "ViewController.h"

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
  
  return std::move(compressedVec);
}

@interface ViewController ()

@property (nonatomic, copy) NSData *lz4CompressedData;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  // Kick off callback timer
  
  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(benchmarkTimer)
                                 userInfo:nil
                                  repeats:NO];
}


- (void) benchmarkTimer {
  NSLog(@"running benchmarkTimer");
  
  // Compress

  NSString *resFilename = @"DumpDeltaInputToHuffman.bytes";
  NSString *resPath = [[NSBundle mainBundle] pathForResource:resFilename ofType:nil];;
  NSAssert(resPath, @"resource not found \"%@\"", resFilename);
  
  NSData *unencodedData = [NSData dataWithContentsOfFile:resPath];
  NSAssert(unencodedData, @"data");
  
  vector<uint8_t> inBytes;
  inBytes.resize((int)unencodedData.length);
  memcpy(inBytes.data(), unencodedData.bytes, unencodedData.length);
  
  vector<uint8_t> compressedVec = compressedWithLZ4HC(inBytes);
  
  if ((1)) {
      NSLog(@"uncomp num bytes %8d", (int)inBytes.size());
      NSLog(@"  comp num bytes %8d", (int)compressedVec.size());
  }
  
  self.lz4CompressedData = [NSData dataWithBytes:compressedVec.data() length:compressedVec.size()];
  
  return;
}

@end

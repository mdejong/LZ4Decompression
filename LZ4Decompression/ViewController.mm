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
  
  return compressedVec;
}

@interface ViewController ()

@property (nonatomic, retain) NSTimer *intervalTimer;

@property (nonatomic, copy) NSData *lz4CompressedData;

@property (nonatomic, retain) NSMutableData *lz4DecompressedData;

@property (nonatomic, assign) int secondByteCounter;

@property (nonatomic, assign) int numerator;
@property (nonatomic, assign) int denominator;

@property (nonatomic, retain) IBOutlet UILabel *fpsLabel;

@property (nonatomic, retain) IBOutlet UILabel *mbLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Do any additional setup after loading the view, typically from a nib.
  
  // Kick off callback timer
  
  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(benchmarkInitTimer)
                                 userInfo:nil
                                  repeats:NO];
  
  NSAssert(self.fpsLabel, @"fpsLabel");
  NSAssert(self.mbLabel, @"mbLabel");
}


- (void) benchmarkInitTimer {
  NSLog(@"running benchmarkInitTimer");
  
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
  
  self.lz4DecompressedData = [NSMutableData dataWithLength:unencodedData.length];
  
  // Schedule callback at 30 FPS
  
//  float interval = 1.0/30.0;
//  float interval = 1.0/45.0;
//  float interval = 1.0/59.0;
//  float interval = 1.0/60.0;
  
//  float interval = 1.0/120.0;
//  float interval = 1.0/240.0;
  
//  float interval = 1.0/400.0;
//  float interval = 1.0/800.0;
  
//  float interval = 1.0/1300.0; // 1293 at 85% CPU
//  float interval = 1.0/2000.0; // 1350 at 90% CPU
  //float interval = 1.0/2500.0; // 1404 at 90% CPU
  
  //float interval = 1.0/3000.0; // 1404 at 93% CPU
  
  //float interval = 1.0/5000.0; // 1404 at 93% CPU
  
  //float interval = 1.0/35000.0; // 1425 at 98% CPU
  
//  float interval = 1.0/50000.0; // 1491 at 98% CPU
  
//  float interval = 1.0/100000.0; // 1500 at 98% CPU on A9

//  self.numerator = 1;
//  self.denominator = 30;
  
  self.numerator = 1;
  self.denominator = 100000;
  
  float interval = (float)self.numerator/(float)self.denominator;
  
  self.intervalTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                   target:self
                                 selector:@selector(benchmarkTimer)
                                 userInfo:nil
                                  repeats:YES];

  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(secondElapsedTimer)
                                 userInfo:nil
                                  repeats:YES];
  
  return;
}

- (void) secondElapsedTimer {
  NSLog(@"secondElapsedTimer : %8d bytes : aka %d MB", self.secondByteCounter, self.secondByteCounter/(1024*1024));
  
  int megabytes = self.secondByteCounter/(1024*1024);
  
  self.fpsLabel.text = [NSString stringWithFormat:@"%d", self.denominator];
  self.mbLabel.text = [NSString stringWithFormat:@"%d", megabytes];
  
  if ((0)) {
    // Reschedule
    [self.intervalTimer invalidate];
    
    self.numerator = 1;
    self.denominator = 60;
    
    float interval = (float)self.numerator/(float)self.denominator;
    
    self.intervalTimer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                          target:self
                                                        selector:@selector(benchmarkTimer)
                                                        userInfo:nil
                                                         repeats:YES];
  }

  self.secondByteCounter = 0;
}

- (void) benchmarkTimer {
  //NSLog(@"benchmarkTimer");

  int numDecompressed = LZ4_decompress_fast((const char*)self.lz4CompressedData.bytes, (char*)self.lz4DecompressedData.mutableBytes, (int)self.lz4DecompressedData.length);

  assert(numDecompressed == (int)self.lz4CompressedData.length);
  
  self.secondByteCounter += (int)self.lz4DecompressedData.length;
  
  return;
}

@end


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
@property (nonatomic, assign) int step;

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
  
//  self.numerator = 1;
//  self.denominator = 30;

  self.numerator = 1;
  self.denominator = 60;
  
//  self.numerator = 1;
//  self.denominator = 100000;
  
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
  NSLog(@"secondElapsedTimer : Denom %8d : %12d bytes : aka %4d MB", self.denominator, self.secondByteCounter, self.secondByteCounter/(1024*1024));
  
  int megabytes = self.secondByteCounter/(1024*1024);
  
  self.fpsLabel.text = [NSString stringWithFormat:@"%d", self.denominator];
  self.mbLabel.text = [NSString stringWithFormat:@"%d", megabytes];
  
  if ((1)) {
    // Reschedule each second
    [self.intervalTimer invalidate];
    
    self.numerator = 1;
    
    NSArray *stepDenom = @[@(30), @(60), @(120), @(240), @(800), @(1400), @(2500), @(5000), @(20000), @(50000), @(70000), @(100000)];
    
    self.step = (self.step + 1) % [stepDenom count];
    
    NSNumber *denomNum = stepDenom[self.step];
    
    self.denominator = [denomNum intValue];
    
    // A9
    
//    Denom       30 :   91226112 bytes : aka   90 MB (12% CPU)
//    Denom       60 :  185597952 bytes : aka  177 MB (17% CPU)
//    Denom      120 :  374341632 bytes : aka  357 MB
//    Denom      240 :  748683264 bytes : aka  714 MB
//    Denom      800 : 1198522368 bytes : aka 1143 MB
//    Denom     1400 : 1431306240 bytes : aka 1365 MB
//    Denom     2500 : 1453326336 bytes : aka 1386 MB
//    Denom     5000 : 1519386624 bytes : aka 1449 MB
//    Denom    20000 : 1550843904 bytes : aka 1479 MB (90% CPU)
//    Denom    50000 : 1560281088 bytes : aka 1488 MB
//    Denom    70000 : 1560281088 bytes : aka 1488 MB
//    Denom   100000 : 1560281088 bytes : aka 1488 MB
    
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


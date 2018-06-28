//
//  ViewController.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/26/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import "ViewController.h"

#import "CompressionDriver.h"
#import "LZ4SrcDriver.h"
#import "LZ4AppleDriver.h"
#import "FSEDriver.h"

@interface ViewController ()

@property (nonatomic, retain) id<CompressionDriver> driver;

@property (nonatomic, retain) NSTimer *intervalTimer;

@property (nonatomic, copy) NSData *unencodedData;
@property (nonatomic, copy) NSData *compressedData;
@property (nonatomic, retain) NSMutableData *decompressedData;

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
  
  self.unencodedData = unencodedData;
  
  if ((0)) {
    self.driver = [[LZ4SrcDriver alloc] init];
  } else if ((0)) {
    self.driver = [[LZ4AppleDriver alloc] init];
  } else {
    self.driver = [[FSEDriver alloc] init];
  }

  self.compressedData = [self.driver compressData:unencodedData];
  
  if ((1)) {
      NSLog(@"uncomp num bytes %8d", (int)unencodedData.length);
      NSLog(@"  comp num bytes %8d", (int)self.compressedData.length);
  }
  
  self.decompressedData = [NSMutableData dataWithLength:unencodedData.length];
  
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
    //
//    Denom       30 :   91226112 bytes : aka   90 MB (12% CPU)
//    Denom       60 :  185597952 bytes : aka  177 MB (17% CPU)
//    Denom      120 :  374341632 bytes : aka  357 MB
//    Denom      240 :  748683264 bytes : aka  714 MB
//    Denom      800 : 1198522368 bytes : aka 1143 MB
//    Denom     1400 : 1431306240 bytes : aka 1365 MB
//    Denom     2500 : 1453326336 bytes : aka 1386 MB
//    Denom     5000 : 1519386624 bytes : aka 1449 MB
//    Denom    20000 : 1550843904 bytes : aka 1479 MB (90% CPU)
//    Denom    50000 : 1560281088 bytes : aka 1488 MB (98% CPU)
//    Denom    70000 : 1560281088 bytes : aka 1488 MB
//    Denom   100000 : 1560281088 bytes : aka 1488 MB
    
    // A9 : Apple LZ4 in libcompression
    
    // Denom    70000 :   1258291200 bytes : aka 1200 MB (98% CPU)
    
    // --------------
    
    // A9 with LZFSE
    //
    //
    // uncomp num bytes  3145728
    //   comp num bytes  1932854
    //
    // Denom      800 :    314572800 bytes : aka  300 MB
    // Denom    50000 :    336592896 bytes : aka  321 MB

    // A9 with zlib
    //
    // uncomp num bytes  3145728
    //   comp num bytes  1938194
    //
    // Denom    50000 :    141557760 bytes : aka  135 MB
    
    // A9 with FSE src
    //
    // uncomp num bytes  3145728
    //   comp num bytes  1920119
    
    // Denom     5000 :    317718528 bytes : aka  303 MB
    
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
  
#if defined(DEBUG)
  memset(self.decompressedData.mutableBytes, 0, (int)self.decompressedData.length);
#endif // DEBUG

  BOOL worked = [self.driver decompressData:self.compressedData buffer:(char*)self.decompressedData.mutableBytes length:(int)self.decompressedData.length];
  
  assert(worked == TRUE);
  
#if defined(DEBUG)
  // Compare decoded bytes to original input bytes
  int cmp = memcmp(self.unencodedData.bytes, self.decompressedData.mutableBytes, (int)self.decompressedData.length);
  assert(cmp == 0);
#endif // DEBUG
  
  self.secondByteCounter += (int)self.decompressedData.length;
  
  return;
}

@end


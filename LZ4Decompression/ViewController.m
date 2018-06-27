//
//  ViewController.m
//  LZ4Decompression
//
//  Created by Mo DeJong on 6/26/18.
//  Copyright © 2018 HelpURock. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

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
  
  return;
}

@end

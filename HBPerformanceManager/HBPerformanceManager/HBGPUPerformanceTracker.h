//
//  HBGPUPerformanceTracker.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HBPerformanceMonitor.h"
#import "HBWeakPairObject.h"

@interface HBGPUPerformanceTracker : NSObject
@property (nonatomic, weak) id<HBPerformanceMonitorDegegate> delegate;

+ (HBGPUPerformanceTracker *)shareInstance;

- (void)start;
- (void)stop;
- (void)addVCPairs:(HBWeakPairObject *)vcObject forKey:(NSString *)key;
- (NSString *)markGPUExhaustedLayer:(NSString *)key;


@end

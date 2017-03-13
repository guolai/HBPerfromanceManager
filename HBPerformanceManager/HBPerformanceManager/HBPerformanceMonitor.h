//
//  HBPerformanceMonitor.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol HBPerformanceMonitorDegegate;

@interface HBPerformanceMonitor : NSObject

@property (nonatomic, weak) id<HBPerformanceMonitorDegegate> delegate;

+ (HBPerformanceMonitor *)shareInstance;

- (void)start;
- (void)stop;


@end

@protocol HBPerformanceMonitorDegegate <NSObject>

@optional
- (void)reportStackTrace:(NSString *)strStack;
- (void)reportGPUUseWaring:(NSString *)strMessage;
- (void)enableTracking:(BOOL)bValue;

@end

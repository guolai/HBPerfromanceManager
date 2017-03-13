//
//  HBPerformanceManager.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/7.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HBPerformanceManager : NSObject

+ (HBPerformanceManager *)shareInstance;

- (void)startPerformance;
- (void)stopPerformance;
//- (void)start;
//
//- (void)stop;

- (void)showWarningMessage:(NSString *)warningMessage;
@end

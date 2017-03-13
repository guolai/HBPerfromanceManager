//
//  HBPerformanceWarningPannel.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HBPerformanceMonitor.h"

@interface HBPerformanceWarningPannel : UIView

@property (nonatomic, assign, readonly) BOOL bCaptureWaringMessage;
@property (nonatomic, weak) id<HBPerformanceMonitorDegegate> delegate;

+ (HBPerformanceWarningPannel *)shareInstance;
- (void)showWaringMessage:(NSString *)strMessage;
- (void)showFPS:(NSInteger)nFps;
- (void)start;
- (void)stop;
- (void)appEnterBackground;
- (void)appEnterForground;

@end

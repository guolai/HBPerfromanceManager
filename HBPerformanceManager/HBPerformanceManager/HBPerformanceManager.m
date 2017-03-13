//
//  HBPerformanceManager.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/7.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "HBPerformanceManager.h"
#import "HBPerformanceMonitor.h"
#import "HBPerformanceWarningPannel.h"
#import "HBGPUPerformanceTracker.h"

@interface HBPerformanceManager ()<HBPerformanceMonitorDegegate>
@property (nonatomic, assign) BOOL bStarted;
@property (nonatomic, assign) BOOL bShouldStartPerformance;

@end

@implementation HBPerformanceManager

+ (HBPerformanceManager *)shareInstance
{
    static HBPerformanceManager *_manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [[HBPerformanceManager alloc] init];
    });
    return _manager;
}


- (instancetype)init
{
    if(self = [super init])
    {
       
    }
    return self;
}

- (void)startPerformance
{
    if(!self.bShouldStartPerformance)
    {
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(appEnterForeground)
                                                     name: UIApplicationDidBecomeActiveNotification
                                                   object: nil];
        
        [[NSNotificationCenter defaultCenter] addObserver: self
                                                 selector: @selector(appEnterBackground)
                                                     name: UIApplicationWillResignActiveNotification
                                                   object: nil];
        [self start];
    }
}

- (void)stopPerformance
{
    if(self.bShouldStartPerformance)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [self stop];
    }
}

- (void)start
{
    if (self.bStarted)
    {
        return;
    }
    [HBPerformanceMonitor shareInstance].delegate = self;
    
    [HBGPUPerformanceTracker shareInstance].delegate = self;
    
    [HBPerformanceWarningPannel shareInstance].delegate = self;
    [[HBPerformanceMonitor shareInstance] start];
    [[HBPerformanceWarningPannel shareInstance] start];
    
    [[HBGPUPerformanceTracker shareInstance] start];
    self.bStarted = YES;
}

- (void)stop
{
    if (!self.bStarted)
    {
        return;
    }
    [[HBPerformanceMonitor shareInstance] stop];
    [[HBGPUPerformanceTracker shareInstance] stop];
    [[HBPerformanceWarningPannel shareInstance] stop];
    self.bStarted = NO;
}

- (void)appEnterBackground
{
    [[HBPerformanceWarningPannel shareInstance] appEnterBackground];
}

- (void)appEnterForeground
{
    [[HBPerformanceWarningPannel shareInstance] appEnterForground];
}

- (void)showWarningMessage:(NSString *)warningMessage
{
    if (self.bStarted)
    {
        [[HBPerformanceWarningPannel shareInstance] showWaringMessage:warningMessage];
    }
}

#pragma mark -- KSPerformanceMonitorDelegate --
- (void)reportStackTrace:(NSString *)stack
{
    if (![HBPerformanceWarningPannel shareInstance].bCaptureWaringMessage)
    {
        NSString *gpuMes;
        /*
         可以把最上层vc layer 检查一下，但是这样不适合放入组件了
         */
        [[HBPerformanceWarningPannel shareInstance] showWaringMessage:[NSString stringWithFormat:@"%@ \n %@", stack, (gpuMes ? gpuMes : @"")]];
    }
}

- (void)reportGPUPerformanceWarning:(NSString *)message
{
    [[HBPerformanceWarningPannel shareInstance] showWaringMessage:message];
}

- (void)enableTracking:(BOOL)enable
{
    if (enable)
    {
        [self start];
    }
    else
    {
        [self stop];
    }
}



#pragma mark - private

@end

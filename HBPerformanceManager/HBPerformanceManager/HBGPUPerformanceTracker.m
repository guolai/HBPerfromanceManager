//
//  HBGPUPerformanceTracker.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "HBGPUPerformanceTracker.h"
#import "NSTimer+BlocksKit.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

@interface HBGPUPerformanceTracker()

@property(nonatomic, strong) NSMutableDictionary *viewsDic;
@property(nonatomic, strong) NSTimer *checkTimer;
@property(nonatomic, assign) BOOL bStarted;

@end

@implementation HBGPUPerformanceTracker
+ (HBGPUPerformanceTracker *)shareInstance
{
    static HBGPUPerformanceTracker *_gpuTracker = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _gpuTracker = [[HBGPUPerformanceTracker alloc] init];
    });
    return _gpuTracker;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _viewsDic = [[NSMutableDictionary alloc] init];
        _bStarted = NO;
    }
    return self;
}

- (void)start
{
    if (!self.checkTimer)
    {
        _checkTimer = [NSTimer scheduledTimerWithTimeInterval:3 block:^(NSTimer *timer) {
            [self checkWarningLevel];
        } repeats:YES];
        _bStarted = YES;
    }
}

- (void)stop
{
    if (self.checkTimer)
    {
        [self.checkTimer invalidate];
        self.checkTimer = nil;
        _bStarted = NO;
    }
}

- (void)addVCPairs:(HBWeakPairObject *)vcObject forKey:(NSString *)key
{
    if (vcObject && key)
    {
        [self.viewsDic setObject:vcObject forKey:key];
    }
    
}


- (NSString *)markGPUExhaustedLayer:(NSString *)key
{
    if (!key)
    {
        return nil;
    }
    
    HBWeakPairObject *pair = [self.viewsDic objectForKey:key];
    NSUInteger subviewCount = 0;
    NSUInteger translucentSubviewCount = 0;
    NSUInteger offScreenDrawingSubviewCount = 0;
    [self travelSubViews:pair.weakView subviewCount:&subviewCount translucentSubviewCount:&translucentSubviewCount screenDrawingSubviewCount:&offScreenDrawingSubviewCount shouldMarkBackgroundColor:YES];
    
    NSString *message = [NSString stringWithFormat:@"当前页面总的layer数：%ld, 半透明的layer数：%ld, 离屏幕绘制的layer数：%ld", subviewCount, translucentSubviewCount, offScreenDrawingSubviewCount];
    return message;
}

- (void)checkWarningLevel
{
    NSMutableString *warningMessage = [NSMutableString string];
    BOOL shouldReport = NO;
    for (NSString *key in [self.viewsDic allKeys])
    {
        [warningMessage appendString:[NSString stringWithFormat:@"%@:\n", key]];
        HBWeakPairObject *object = [self.viewsDic objectForKey:key];
        if ((!object.weakVC) && (object.weakView))
        {
            object.eWaringLevel |= HBWarningLevel_DeadView;
            shouldReport = YES;
            [warningMessage appendString:@"VC释放了，但是view没释放"];
        }
        NSUInteger subviewCount = 0;
        NSUInteger translucentSubviewCount = 0;
        NSUInteger offScreenDrawingSubviewCount = 0;
        [self travelSubViews:object.weakView subviewCount:&subviewCount translucentSubviewCount:&translucentSubviewCount screenDrawingSubviewCount:&offScreenDrawingSubviewCount shouldMarkBackgroundColor:NO];
        if (subviewCount > 0)
        {
            if (subviewCount > 200)
            {
                object.eWaringLevel |= HBWarningLevel_ManyLayer;
                [warningMessage appendString:[NSString stringWithFormat:@"太多layer:%ld \n",subviewCount]];
            }
            if (((CGFloat)translucentSubviewCount) / subviewCount > 0.5)
            {
                object.eWaringLevel |= HBWarningLevel_ManyTranslucentLayer;
                [warningMessage appendString:[NSString stringWithFormat:@"太多半透明layer:%ld -- %ld \n",subviewCount, translucentSubviewCount]];
            }
            if (((CGFloat)offScreenDrawingSubviewCount) / subviewCount > 0.5)
            {
                object.eWaringLevel = object.eWaringLevel | HBWarningLevel_ManyOffScreenDrawing;
                [warningMessage appendString:[NSString stringWithFormat:@"太多离屏绘制layer:%ld -- %ld \n",subviewCount, offScreenDrawingSubviewCount]];
            }
            
            if (subviewCount > object.nSubView)
            {
                object.nContinueIncreasing++;
            }
            else
            {
                object.nContinueIncreasing--;
            }
            object.nContinueIncreasing = MAX(object.nContinueIncreasing, 0);
            if (object.nContinueIncreasing > 10)
            {
                object.eWaringLevel |= HBWarningLevel_LayerIncreasing;
                [warningMessage appendString:[NSString stringWithFormat:@"layer在持续增长:%ld \n",subviewCount]];
                //TODO: 还没找到合适的方式去检测layer的持续增长，这里先不告警了
                //                shouldReport = YES;
            }
        }
    }
    if (shouldReport)
    {
        if ([self.delegate respondsToSelector:@selector(reportGPUUseWaring:)])
        {
            [self.delegate reportGPUUseWaring:warningMessage];
        }
        
    }
}

- (void)travelSubViews:(UIView *)view
          subviewCount:(NSUInteger *)subviewCount
translucentSubviewCount:(NSUInteger *)translucentSubviewCount
screenDrawingSubviewCount:(NSUInteger *)screenDrawingSubviewCount
shouldMarkBackgroundColor:(BOOL)shouldMarkBackgroundColor
{
    for (UIView *subview in [view subviews])
    {
        BOOL isTranslucent = NO;
        (*subviewCount)++;
        if (subview.alpha < 1.0)
        {
            (*translucentSubviewCount)++;
            if (shouldMarkBackgroundColor)
            {
                subview.backgroundColor = [UIColor redColor];
                isTranslucent = YES;
            }
        }
        //TODO:如何检测离屏绘制
        //常见的离屏绘制的情况
        /*
         shouldRasterize（光栅化）
         masks（遮罩）
         shadows（阴影）
         edge antialiasing（抗锯齿）
         cornerRadius (设置圆角)
         drawRect
         */
        BOOL cornerRadius = subview.layer.cornerRadius > 0.0f;
        BOOL shouldRasterize = subview.layer.shouldRasterize;
        BOOL masks = (subview.layer.mask != nil);
        BOOL shadows = (subview.layer.shadowOpacity > 0.0f);
        BOOL drawRect = [self checkIfObject:[subview class] overridesSelector:@selector(drawRect:) fromSuperObject:[UIView class]];
        if (cornerRadius || shouldRasterize || masks || shadows || drawRect)
        {
            (*screenDrawingSubviewCount)++;
            if (shouldMarkBackgroundColor)
            {
                if (isTranslucent)
                {
                    subview.backgroundColor = [UIColor blueColor];
                }
                else
                {
                    subview.backgroundColor = [UIColor yellowColor];
                }
            }
        }
        [self travelSubViews:subview subviewCount:subviewCount translucentSubviewCount:translucentSubviewCount screenDrawingSubviewCount:screenDrawingSubviewCount shouldMarkBackgroundColor:shouldMarkBackgroundColor];
    }
}

- (BOOL)checkIfObject:(Class)object overridesSelector:(SEL)selector fromSuperObject:(Class)superObject
{
    if (method_getImplementation(class_getInstanceMethod(object, selector)) ==
        method_getImplementation(class_getInstanceMethod(superObject, selector)))
    {
        return NO;
    }
    else
    {
        return YES;
    }
    
}


@end

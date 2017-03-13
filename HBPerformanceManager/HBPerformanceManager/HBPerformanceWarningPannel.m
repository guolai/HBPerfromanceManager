//
//  HBPerformanceWarningPannel.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "HBPerformanceWarningPannel.h"

#import "NSString+HBStringSize.h"

#define SCREEN_WIDTH  CGRectGetWidth([[UIScreen mainScreen] bounds])
#define SCREEN_HEIGHT CGRectGetHeight([[UIScreen mainScreen] bounds])

@protocol PerformanceWarningDisplayDelegate <NSObject>

- (void)displayWindowDidPressed;

@end

@interface HBDisplayWindow : UIWindow
@property(nonatomic, weak) id<PerformanceWarningDisplayDelegate> displayDelegate;

@end

@implementation HBDisplayWindow

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    if ([self.displayDelegate respondsToSelector:@selector(displayWindowDidPressed)])
    {
        [self.displayDelegate displayWindowDidPressed];
    }
}

@end

@interface HBPerformanceWarningPannel()<PerformanceWarningDisplayDelegate>

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) UILabel *mesLabel;
@property(nonatomic, strong) UILabel *meterLabel;
@property(nonatomic, strong) HBDisplayWindow *window;
@property(nonatomic, assign) BOOL bShowingMessage;
@property(nonatomic, assign) BOOL bStarted;
@property(nonatomic, assign, readwrite) BOOL bCaptureWaringMessage;

@end


@implementation HBPerformanceWarningPannel

+ (HBPerformanceWarningPannel *)shareInstance
{
    static HBPerformanceWarningPannel *_pannel = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _pannel = [[HBPerformanceWarningPannel alloc] init];
    });
    return _pannel;
}
- (void)showWaringMessage:(NSString *)strMessage
{
    
}

- (void)showFPS:(NSInteger)nFps
{
    if (self.bStarted) {
        if (nFps > 58) {
            [self.meterLabel setBackgroundColor:[UIColor greenColor]];
        }
        else if(nFps > 50)
        {
            [self.meterLabel setBackgroundColor:[UIColor orangeColor]];
        }
        else
        {
            [self.meterLabel setBackgroundColor:[UIColor redColor]];
        }
        self.meterLabel.text = [NSString stringWithFormat:@"%ld", nFps];
    }
}


- (void)start
{
    if (!self.bStarted)
    {
        self.bShowingMessage = NO;
        self.bCaptureWaringMessage= NO;
        self.bStarted = YES;
        self.window.hidden = NO;
    }
}

- (void)stop
{
    if (self.bStarted)
    {
        [self.scrollView removeFromSuperview];
        self.bShowingMessage = NO;
        self.bCaptureWaringMessage = NO;
        self.bStarted = NO;
        self.meterLabel.text = @" ";
    }
}

- (void)appEnterBackground
{
    self.window.hidden = YES;
}

- (void)appEnterForground
{
    self.window.hidden = NO;
}

- (void)enable
{
    if ([self.delegate respondsToSelector:@selector(enableTracking:)])
    {
        [self.delegate enableTracking:!self.bStarted];
    }
}


#pragma mark -- private
- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configureView];
        _bShowingMessage = NO;
        _bCaptureWaringMessage = NO;
    }
    return self;
}

- (void)configureView
{
    _window = [[HBDisplayWindow alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 20)];
    _window.windowLevel = UIWindowLevelStatusBar + 10.0;
    _window.userInteractionEnabled = YES;
    _window.displayDelegate = self;
    
    
    CGFloat const kMeterWidth = 30.0;
    CGFloat xOrigin = SCREEN_WIDTH - kMeterWidth - 36;
    _meterLabel = [[UILabel alloc] initWithFrame:CGRectMake(xOrigin, 0.0, kMeterWidth, 20)];
    _meterLabel.font = [UIFont boldSystemFontOfSize:12.0];
    _meterLabel.backgroundColor = [UIColor greenColor];
    _meterLabel.textColor = [UIColor blackColor];
    _meterLabel.textAlignment = NSTextAlignmentCenter;
    [_window addSubview:_meterLabel];
    
    
    //create the scrollview to display the warning message
    _mesLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    _mesLabel.backgroundColor = [UIColor clearColor];
    _mesLabel.font = [UIFont boldSystemFontOfSize:15.0];
    _mesLabel.textColor = [UIColor blackColor];
    _mesLabel.textAlignment = NSTextAlignmentLeft;
    _mesLabel.backgroundColor = [UIColor grayColor];
    _mesLabel.numberOfLines = 0;
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)];
    [_scrollView setContentSize:CGSizeMake(SCREEN_WIDTH, SCREEN_HEIGHT)];
    [_scrollView addSubview:_mesLabel];
    
    _window.hidden = NO;
}

- (void)showWarningMessage:(NSString *)message
{
    if ((!self.bCaptureWaringMessage) && self.bStarted)
    {
        [[UIApplication sharedApplication].keyWindow addSubview:self.scrollView];
        self.mesLabel.text = message;
        CGSize size = [message hbSizeWithFont:self.mesLabel.font constrainedToSize:CGSizeMake(SCREEN_WIDTH, 10 * SCREEN_HEIGHT) lineBreakMode:NSLineBreakByWordWrapping];
        CGRect frame = self.mesLabel.frame;
        frame.size.width = fmax(SCREEN_WIDTH, size.width);
        frame.size.height = fmax(SCREEN_HEIGHT, size.height);
        self.mesLabel.frame = frame;
        self.scrollView.contentSize = CGSizeMake(self.mesLabel.frame.size.width, self.mesLabel.frame.size.height);
        self.bShowingMessage = YES;
        self.bCaptureWaringMessage = YES;
    }
}



#pragma mark -- PerformanceWarningDisplayDelegate --
- (void)displayWindowDidPressed
{
    if (self.bShowingMessage)
    {
        [self.scrollView removeFromSuperview];
        self.bShowingMessage = NO;
    }
    else
    {
        if (self.bCaptureWaringMessage)
        {
            [[UIApplication sharedApplication].keyWindow addSubview:self.scrollView];
            self.bShowingMessage = YES;
        }
    }
}


@end

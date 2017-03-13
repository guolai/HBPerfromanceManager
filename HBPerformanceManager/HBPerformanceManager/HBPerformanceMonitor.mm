//
//  HBPerformanceMonitor.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "HBPerformanceMonitor.h"
#import "HBOpenGLView.h"
#import "HBPerformanceWarningPannel.h"
#import <dlfcn.h>
#import <map>
#import <pthread.h>
#import <QuartzCore/CADisplayLink.h>
#import <mach-o/dyld.h>
#import "execinfo.h"
#include <mach/mach_time.h>
#include <sys/sysctl.h>

#define SCREEN_WIDTH  CGRectGetWidth([[UIScreen mainScreen] bounds])
#define SCREEN_HEIGHT CGRectGetHeight([[UIScreen mainScreen] bounds])

static BOOL _signalSetup;
static pthread_t _mainThread;
static NSThread *_trackerThread;

static std::map<void *, NSString *, std::greater<void *> > _imageNames;

#ifdef __LP64__
typedef mach_header_64 ks_mach_header;
typedef segment_command_64 ks_mach_segment_command;
#define LC_SEGMENT_ARCH LC_SEGMENT_64
#else
typedef mach_header ks_mach_header;
typedef segment_command ks_mach_segment_command;
#define LC_SEGMENT_ARCH LC_SEGMENT
#endif

static volatile BOOL _shouldTracking;
pthread_mutex_t _scrollingMutex;
pthread_cond_t _scrollingCondVariable;
dispatch_queue_t _symbolicationQueue;

// We record at most 16 frames since I cap the number of frames dropped measured at 15.
// Past 15, something went very wrong (massive contention, priority inversion, rpc call going wrong...) .
// It will only pollute the data to get more.
static const int callstack_max_number = 16;

static int callstack_i;
static bool callstack_dirty;
static bool isCopyingStack = false;
static int callstack_size[callstack_max_number];
static void *callstacks[callstack_max_number][128];
uint64_t callstack_time_capture;

#define kHardwareFramesPerSecond 60

static void _callstack_signal_handler(int signr, siginfo_t *info, void *secret)
{
    if (isCopyingStack)
    {
        return;
    }
    // This is run on the main thread every 16 ms or so during tracking.
    
    // Signals are run one by one so there is no risk of concurrency of a signal
    // by the same signal.
    
    // The backtrace call is technically signal-safe on Unix-based system
    // See: http://www.unix.com/man-page/all/3c/walkcontext/
    
    // WARNING: this is signal handler, no memory allocation is safe.
    // Essentially nothing is safe unless specified it is.
    callstack_size[callstack_i] = backtrace(callstacks[callstack_i], 128);
    callstack_i = (callstack_i + 1) & (callstack_max_number - 1); // & is a cheap modulo (only works for power of 2)
    callstack_dirty = true;
}

@interface HBCallstack : NSObject

@property (nonatomic, readonly, assign) int size;
@property (nonatomic, readonly, assign) void **callstack;

- (instancetype)initWithSize:(int)size callstack:(void *)callstack;
@end

@implementation HBCallstack
- (instancetype)initWithSize:(int)size callstack:(void *)callstack
{
    if (self = [super init]) {
        _size = size;
        _callstack = (void **)malloc(size * sizeof(void *));
        memcpy(_callstack, callstack, size * sizeof(void *));
    }
    return self;
}

- (void)dealloc
{
    free(_callstack);
}

@end

typedef struct HBPerformanceMonitorConfig
{
    // Number of frame drop that defines a "small" drop event. By default, 1.
    NSInteger smallDropEventFrameNumber;
    // Number of frame drop that defines a "large" drop event. By default, 4.
    NSInteger largeDropEventFrameNumber;
    // Number of maximum frame drops to which the drop will be trimmed down to. Currently 15.
    NSInteger maxFrameDropAccount;
    // if YES, capture stack traces
    BOOL shouldCaptureStackTraces;
} HBPerformanceMonitorConfig_T;

@interface HBPerformanceMonitor()
{
    // numbers used to track the performance metrics
    double _durationTotal;
    double _droppedTime;
    double _maxFrameTime;
    double _smallDrops;
    double _largeDrops;
    CFTimeInterval _lastSecondOfFrameTimes[kHardwareFramesPerSecond];
}
@property(nonatomic, assign) HBPerformanceMonitorConfig_T config;
@property(nonatomic, assign) BOOL tracking;
@property(nonatomic, assign) BOOL firstUpdate;
@property(nonatomic, assign) NSTimeInterval previousFrameTimestamp;
@property(nonatomic, assign) NSTimeInterval trackingScrollingBeginTimesStamp;
@property(nonatomic, strong) CADisplayLink *displayLink;
@property(nonatomic, assign) BOOL prepared;
@property(nonatomic, strong) HBOpenGLView *openGLView;
@property(nonatomic, strong) UILabel *meterLabel;
@property(nonatomic, assign) NSInteger frameNumber;

@end


@implementation HBPerformanceMonitor
+ (HBPerformanceMonitor *)shareInstance
{
    static HBPerformanceMonitor *_monitor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _monitor = [[HBPerformanceMonitor alloc] init];
    });
    return _monitor;
}

- (instancetype)init
{
    if(self = [super init])
    {
        self.config = [HBPerformanceMonitor  standardConfig];
        if (self.config.shouldCaptureStackTraces)
        {
            [self setupSignal];
        }
        [self setupOpenglView];
    }
    return self;
    
}

+ (HBPerformanceMonitorConfig_T)standardConfig
{
    HBPerformanceMonitorConfig_T config = {
        .smallDropEventFrameNumber = 1,
        .largeDropEventFrameNumber = 4,
        .maxFrameDropAccount = 15,
        .shouldCaptureStackTraces = [self isDebuggerAttached] ? NO : YES,
//        .shouldCaptureStackTraces = YES,
    };
    return config;
}

- (void)setupOpenglView
{
    _openGLView = [[HBOpenGLView alloc] initWithFrame:CGRectMake(SCREEN_WIDTH - 30, SCREEN_HEIGHT - 30, 1, 1)];
    [[UIApplication sharedApplication].keyWindow addSubview:_openGLView];
}

- (void)setupSignal
{
    //called in the main thread
    if (!_signalSetup) {
        // The signal hook should be setup once and only once
        _signalSetup = YES;
        
        // I actually don't know if the main thread can die. If it does, well,
        // this is not going to work.
        // UPDATE 4/2015: on iOS8, it looks like the main-thread never dies, and this pointer is correct
        _mainThread = pthread_self();
        
        callstack_i = 0;
        
        // Setup the signal
        struct sigaction sa;
        sigfillset(&sa.sa_mask);
        sa.sa_flags = SA_SIGINFO;
        sa.sa_sigaction = _callstack_signal_handler;
        sigaction(SIGPROF, &sa, NULL);
        
        pthread_mutex_init(&_scrollingMutex, NULL);
        pthread_cond_init (&_scrollingCondVariable, NULL);
        
        // Setup the signal firing loop
        _trackerThread = [[NSThread alloc] initWithTarget:[self class] selector:@selector(trackerLoop) object:nil];
        // We wanna be higher priority than the main thread
        // On iOS8 : this will roughly stick us at priority 61, while the main thread oscillates between 20 and 47
        _trackerThread.threadPriority = 1.0;
        [_trackerThread start];
        
        _symbolicationQueue = dispatch_queue_create("com.hb.symbolication", DISPATCH_QUEUE_SERIAL);
        dispatch_async(_symbolicationQueue, ^(void) {[self setupSymbolication];});
    }
}


+ (void)trackerLoop
{
    while (true) {
        // If you are confused by this part,
        // Check out https://computing.llnl.gov/tutorials/pthreads/#ConditionVariables
        
        // Lock the mutex
        pthread_mutex_lock(&_scrollingMutex);
        while (!_shouldTracking)
        {
            // Unlock the mutex and sleep until the conditional variable is signaled
            pthread_cond_wait(&_scrollingCondVariable, &_scrollingMutex);
            // The conditional variable was signaled, but we need to check _shouldTracking
            // As nothing guarantees that it is still true
        }
        // _shouldTracking is true, go ahead and capture traces for a while.
        pthread_mutex_unlock(&_scrollingMutex);
        
        // We are going to tracking, yay, capture traces
        while (_shouldTracking) {
            usleep(16000);
            
            // Here I use SIGPROF which is a signal supposed to be used for profiling
            // I haven't stumbled upon any collision so far.
            // There is no guarantee that it won't impact the system in unpredicted ways.
            // Use wisely.
            
            // not kill the thead, just send the singal
            pthread_kill(_mainThread, SIGPROF);
        }
    }
}

- (void)setupSymbolication
{
    // This extract the starting slide of every module in the app
    // This is used to know which module an instruction pointer belongs to.
    
    // These operations is NOT thread-safe according to Apple docs
    // Do not call this multiple times
    int images = _dyld_image_count();
    
    for (int i = 0; i < images; i ++) {
        intptr_t imageSlide = _dyld_get_image_vmaddr_slide(i);
        
        // Here we extract the module name from the full path
        // Typically it looks something like: /path/to/lib/UIKit
        // And I just extract UIKit
        NSString *fullName = [NSString stringWithUTF8String:_dyld_get_image_name(i)];
        NSRange range = [fullName rangeOfString:@"/" options:NSBackwardsSearch];
        NSUInteger startP = (range.location != NSNotFound) ? range.location + 1 : 0;
        NSString *imageName = [fullName substringFromIndex:startP];
        
        // This is parsing the mach header in order to extract the slide.
        // See https://developer.apple.com/library/mac/documentation/DeveloperTools/Conceptual/MachORuntime/index.html
        // For the structure of mach headers
        ks_mach_header *header = (ks_mach_header*)_dyld_get_image_header(i);
        if (!header)
        {
            continue;
        }
        
        const struct load_command *cmd =
        reinterpret_cast<const struct load_command *>(header + 1);
        
        for (unsigned int c = 0; cmd && (c < header->ncmds); c++)
        {
            if (cmd->cmd == LC_SEGMENT_ARCH) {
                const ks_mach_segment_command *seg =
                reinterpret_cast<const ks_mach_segment_command *>(cmd);
                
                if (!strcmp(seg->segname, "__TEXT")) {
                    _imageNames[(void *)(seg->vmaddr + imageSlide)] = imageName;
                    break;
                }
            }
            cmd = reinterpret_cast<struct load_command*>((char *)cmd + cmd->cmdsize);
        }
    }
}

- (void)dealloc
{
    if (self.prepared) {
        [self tearDownCADisplayLink];
    }
}

#pragma mark - Tracking

- (void)start
{
    if (!self.tracking) {
        if ([self prepare]) {
            [self.openGLView setupContext];
            self.displayLink.paused = NO;
            [self clearLastSecondOfFrameTimes];
            self.tracking = YES;
            [self reset];
            
            if (self.config.shouldCaptureStackTraces)
            {
                pthread_mutex_lock(&_scrollingMutex);
                _shouldTracking = YES;
                // Signal the tracker thread to start firing the signals
                pthread_cond_signal(&_scrollingCondVariable);
                pthread_mutex_unlock(&_scrollingMutex);
            }
        }
    }
}

- (void)stop
{
    if (self.tracking) {
        self.tracking = NO;
        self.displayLink.paused = YES;
        if (self.config.shouldCaptureStackTraces)
        {
            pthread_mutex_lock(&_scrollingMutex);
            _shouldTracking = NO;
            pthread_mutex_unlock(&_scrollingMutex);
        }
    }
}

- (BOOL)prepare
{
    if (self.prepared) {
        return YES;
    }
    
    [self setUpCADisplayLink];
    self.prepared = YES;
    return YES;
}

- (void)setUpCADisplayLink
{
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(update)];
    [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    _displayLink.paused = YES;
}

- (void)tearDownCADisplayLink
{
    [_displayLink invalidate];
    _displayLink = nil;
}

- (void)reset
{
    _firstUpdate = YES;
    _previousFrameTimestamp = 0.0;
    _durationTotal = 0;
    _maxFrameTime = 0;
    _largeDrops = 0;
    _smallDrops = 0;
}

- (void)update
{
    if (!_tracking) {
        return;
    }
    //in order to force the dipalylink sync with drawing time
    [self.openGLView render];
    
    if (_firstUpdate) {
        _firstUpdate = NO;
        _previousFrameTimestamp = _displayLink.timestamp;
        _trackingScrollingBeginTimesStamp = _displayLink.timestamp;
        return;
    }
    
    NSTimeInterval currentTimestamp = _displayLink.timestamp;
    NSTimeInterval frameTime = currentTimestamp - _previousFrameTimestamp;
    [self recordFrameTime:currentTimestamp];
    NSInteger frameDrawn = [self addFrameTime:frameTime singleFrameTime:_displayLink.duration currentTimestamp:currentTimestamp];
    [self updateMeterLabel:frameDrawn];
    _previousFrameTimestamp = currentTimestamp;
}

- (NSInteger)addFrameTime:(NSTimeInterval)actualFrameTime singleFrameTime:(NSTimeInterval)singleFrameTime currentTimestamp:(NSTimeInterval)currentTimestamp
{
    _maxFrameTime = MAX(actualFrameTime, _maxFrameTime);
    
    NSInteger frameDropped = round(actualFrameTime / singleFrameTime) - 1;
    frameDropped = MAX(frameDropped, 0);
    // This is to reduce noise. Massive frame drops will just add noise to your data.
    frameDropped = MIN(_config.maxFrameDropAccount, frameDropped);
    
    _durationTotal += (frameDropped + 1) * singleFrameTime;
    _droppedTime += frameDropped * singleFrameTime;
    // We account 2 frame drops as 2 small events. This way the metric correlates perfectly with Time at X fps.
    _smallDrops += (frameDropped >= _config.smallDropEventFrameNumber) ? ((double) frameDropped) / (double)_config.smallDropEventFrameNumber : 0.0;
    _largeDrops += (frameDropped >= _config.largeDropEventFrameNumber) ? ((double) frameDropped) / (double)_config.largeDropEventFrameNumber : 0.0;
    static NSInteger frameDroppedThreshold = 15;
    NSInteger drawnFrameNumInLastSecond = self.drawnFrameCountInLastSecond;
    static NSInteger totalCount = 0;
    static NSInteger stackCount = 0;
    if ((currentTimestamp - _trackingScrollingBeginTimesStamp) < 2.0)
    {
        /*
         double averageDroppedTime = _droppedTime / (currentTimestamp - _trackingScrollingBeginTimesStamp);
         if (averageDroppedTime > 0.166)
         {
         frameDroppedThreshold = 1;
         }
         */
        totalCount++;
        if (drawnFrameNumInLastSecond < 50)
        {
            stackCount++;
        }
        
    }
    else
    {
        if (((CGFloat)stackCount) / totalCount > 0.8)
        {
            frameDroppedThreshold = 3;
        }
        _trackingScrollingBeginTimesStamp = currentTimestamp;
        _droppedTime = 0;
        totalCount = 0;
        stackCount = 0;
    }
    if (frameDropped >= frameDroppedThreshold)
    {
        frameDroppedThreshold = 15;
        if (_config.shouldCaptureStackTraces)
        {
            callstack_dirty = false;
            isCopyingStack = true;
            int ci = (int)(frameDropped / 2);
            // This is computing the previous indexes
            // callstack - 1 - ci takes us back ci frames
            // I want a positive number so I add callstack_max_number
            // And then just modulo it, with & (callstack_max_number - 1)
            int callstackPreviousIndex = ((callstack_i - 1 - ci) + callstack_max_number) & (callstack_max_number - 1);
            HBCallstack *callstackCopy = [[HBCallstack  alloc] initWithSize:callstack_size[callstackPreviousIndex] callstack:callstacks[callstackPreviousIndex]];
            // Check that in between the beginning and the end of the copy the signal did not fire
            if (!callstack_dirty) {
                // The copy has been made. We are now fine, let's punt the rest off main-thread.
                __weak HBPerformanceMonitor *weakSelf = self;
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [weakSelf reportStackTrace:callstackCopy droppedFrame:frameDropped];
                });
            }
            
            isCopyingStack = false;
        }
    }
    return drawnFrameNumInLastSecond;
}

- (void)recordFrameTime:(CFTimeInterval)frameTime
{
    ++self.frameNumber;
    _lastSecondOfFrameTimes[self.frameNumber % kHardwareFramesPerSecond] = frameTime;
}

- (void)clearLastSecondOfFrameTimes
{
    CFTimeInterval initialFrameTime = CACurrentMediaTime();
    for (NSInteger i = 0; i < kHardwareFramesPerSecond; ++i) {
        _lastSecondOfFrameTimes[i] = initialFrameTime;
    }
    self.frameNumber = 0;
}

- (NSInteger)droppedFrameCountInLastSecond
{
    NSInteger droppedFrameCount = 0;
    
    CFTimeInterval lastFrameTime = CACurrentMediaTime() - (1.0f / kHardwareFramesPerSecond);
    for (NSInteger i = 0; i < kHardwareFramesPerSecond; ++i) {
        if (1.0 <= lastFrameTime - _lastSecondOfFrameTimes[i]) {
            ++droppedFrameCount;
        }
    }
    
    return droppedFrameCount;
}

- (NSInteger)drawnFrameCountInLastSecond
{
    if (!self.tracking || self.frameNumber < kHardwareFramesPerSecond) {
        return -1;
    }
    
    return kHardwareFramesPerSecond - self.droppedFrameCountInLastSecond;
}

- (void)updateMeterLabel:(NSInteger)drawnFrame
{
    [[HBPerformanceWarningPannel shareInstance] showFPS:drawnFrame];
}


- (void)reportStackTrace:(HBCallstack *)callstack droppedFrame:(NSInteger)droppedFrame
{
    static NSString *slide;
    static void *slideL;
    static dispatch_once_t slide_predicate;
    const char* name = _dyld_get_image_name(0);
    const char* tmp = strrchr(name, '/');
    if (tmp) {
        name = tmp + 1;
    }
    
    dispatch_once(&slide_predicate, ^{
        slide = [NSString stringWithFormat:@"%p", (void *)_dyld_get_image_header(0)];
        slideL = (void *)_dyld_get_image_header(0);
    });
    
    @autoreleasepool {
        NSMutableString *stack = [NSMutableString string];
        [stack appendString:[NSString stringWithFormat:@"掉了%ld帧\n", droppedFrame]];
        char **symbols = backtrace_symbols(callstack.callstack, callstack.size);
        for (int j = 0; j < callstack.size; j ++)
        {
            [stack appendString:[NSString stringWithFormat:@"%s\n", symbols[j]]];
        }
        [stack appendString:[NSString stringWithFormat:@"以下列出来的是应用栈的偏移地址，在xcode下用im list看APP的基地址加上这个偏移地址就能知道具体是哪个函数\n"]];
        for (int j = 2; j < callstack.size; j ++) {
            void *instructionPointer = callstack.callstack[j];
            auto it = _imageNames.lower_bound(instructionPointer);
            
            NSString *imageName = (it != _imageNames.end()) ? it->second : @"???";
            if ([imageName isEqualToString:[NSString stringWithCString:name encoding:NSUTF8StringEncoding]]) {
                [stack appendString:[NSString stringWithFormat:@"%d :",j]];
                [stack appendString:imageName];
                [stack appendString:@":"];
                [stack appendString:[NSString stringWithFormat:@"%p", (void *)(reinterpret_cast<char *>(instructionPointer) - reinterpret_cast<char *>(slideL))]];
                [stack appendString:@"|"];
                [stack appendString:@"\n"];
            }
        }
        NSLog(@"--bobzhu %@", stack);
        if ([self.delegate respondsToSelector:@selector(reportStackTrace:)])
        {
            [self.delegate reportStackTrace:stack];
        }
    }
}

/**
 * Check if the debugger is attached
 *
 * Taken from https://github.com/plausiblelabs/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
 *
 * @return `YES` if the debugger is attached to the current process, `NO` otherwise
 */
+ (BOOL)isDebuggerAttached {
    static BOOL debuggerIsAttached = NO;
    
    static dispatch_once_t debuggerPredicate;
    dispatch_once(&debuggerPredicate, ^{
        struct kinfo_proc info;
        size_t info_size = sizeof(info);
        int name[4];
        
        name[0] = CTL_KERN;
        name[1] = KERN_PROC;
        name[2] = KERN_PROC_PID;
        name[3] = getpid();
        
        if (sysctl(name, 4, &info, &info_size, NULL, 0) == -1) {
            NSLog(@" ERROR: Checking for a running debugger via sysctl() failed: %s", strerror(errno));
            debuggerIsAttached = false;
        }
        
        if (!debuggerIsAttached && (info.kp_proc.p_flag & P_TRACED) != 0)
            debuggerIsAttached = true;
    });
    
    return debuggerIsAttached;
}

@end

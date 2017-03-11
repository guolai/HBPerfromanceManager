//
//  NSTimer+BlocksKit.m
//  BlocksKit
//

#import "NSTimer+BlocksKit.h"

@interface NSTimer (BlocksKitPrivate)

+ (void)executeBlockFromTimer:(NSTimer *)aTimer;

@end

@implementation NSTimer (BlocksKit)

+ (id)scheduledTimerWithTimeInterval:(NSTimeInterval)inTimeInterval block:(void (^)(NSTimer *timer))block repeats:(BOOL)inRepeats
{
	NSParameterAssert(block != nil);
	return [self scheduledTimerWithTimeInterval:inTimeInterval target:self selector:@selector(executeBlockFromTimer:) userInfo:[block copy] repeats:inRepeats];
}

+ (id)timerWithTimeInterval:(NSTimeInterval)inTimeInterval block:(void (^)(NSTimer *timer))block repeats:(BOOL)inRepeats
{
	NSParameterAssert(block != nil);
	return [self timerWithTimeInterval:inTimeInterval target:self selector:@selector(executeBlockFromTimer:) userInfo:[block copy] repeats:inRepeats];
}

+ (void)executeBlockFromTimer:(NSTimer *)aTimer {
	void (^block)(NSTimer *) = [aTimer userInfo];
	if (block) block(aTimer);
}

@end

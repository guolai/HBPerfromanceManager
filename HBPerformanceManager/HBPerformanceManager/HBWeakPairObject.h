//
//  HBWeakPairObject.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HBWaringLevel) {
    // low risk
    HBWarningLevel_None = 0,
    HBWarningLevel_ManyLayer = 1<<0,
    HBWarningLevel_ManyTranslucentLayer = 1<<1,
    HBWarningLevel_ManyOffScreenDrawing = 1<<2,
    
    
    //high risk
    HBWarningLevel_LayerIncreasing = 1<<3,
    HBWarningLevel_DeadView = 1<<4,
};


@interface HBWeakPairObject : NSObject

@property (nonatomic, weak) id weakVC;
@property (nonatomic, weak) id weakView;
@property (nonatomic, assign) HBWaringLevel eWaringLevel;
@property (nonatomic, assign) NSUInteger nContinueIncreasing;
@property (nonatomic, assign) NSUInteger nSubView;

@end

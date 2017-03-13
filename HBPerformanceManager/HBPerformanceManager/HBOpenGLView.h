//
//  HBOpenGLView.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HBOpenGLView : UIView
- (void)setupContext;
- (id)initWithFrame:(CGRect)frame;
- (void)render;
@end

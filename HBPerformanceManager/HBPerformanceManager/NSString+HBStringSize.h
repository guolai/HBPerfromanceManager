//
//  NSString+HBStringSize.h
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NSString (HBStringSize)
- (CGSize)hbSizeWithFont:(UIFont*)font;
- (CGSize)hbSizeWithFont:(UIFont*)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode;
- (CGSize)hbSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)size lineBreakMode:(NSLineBreakMode)lineBreakMode;

- (void)hbDrawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment;
@end

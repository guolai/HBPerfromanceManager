//
//  NSString+HBStringSize.m
//  HBPerformanceManager
//
//  Created by bobo on 17/2/8.
//  Copyright © 2017年 bob. All rights reserved.
//

#import "NSString+HBStringSize.h"

#define IS_OS_7_OR_LATER    ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0)

@implementation NSString (HBStringSize)

- (CGSize)makesureSizeIsValid:(CGSize)size
{
    if(size.width == NAN)
    {
        size.width = 0;
    }
    
    if(size.height == NAN)
    {
        size.height = 0;
    }
    
    return CGSizeMake(ceilf(size.width), ceilf(size.height));
}


- (CGSize)hbSizeWithFont:(UIFont*)font{
    NSCParameterAssert(font);
    CGSize size = CGSizeZero;
    
    if (IS_OS_7_OR_LATER) {
        size = [self sizeWithAttributes:@{NSFontAttributeName: font}];
    }else{
        size = [self sizeWithAttributes:@{NSFontAttributeName:font}];
    }
    
    return [self makesureSizeIsValid:size];
}
- (CGSize)hbSizeWithFont:(UIFont*)font forWidth:(CGFloat)width lineBreakMode:(NSLineBreakMode)lineBreakMode
{
    NSCParameterAssert(font);
    CGSize size = CGSizeZero;
    if (IS_OS_7_OR_LATER) {
        size = [ self boundingRectWithSize:CGSizeMake(width, 0)
                                   options:(NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                attributes:@{NSFontAttributeName:font}
                                   context:nil].size;
    }else{
        NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
        paraStyle.lineBreakMode = lineBreakMode;
        
        size = [self boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:paraStyle}
                                  context:nil].size;
    }
    
    return [self makesureSizeIsValid:size];
}
- (CGSize)hbSizeWithFont:(UIFont *)font constrainedToSize:(CGSize)maxSize lineBreakMode:(NSLineBreakMode)lineBreakMode
{
    NSCParameterAssert(font);
    CGSize size = CGSizeZero;
    if (IS_OS_7_OR_LATER) {
        size = [ self boundingRectWithSize:CGSizeMake(maxSize.width, 0)
                                   options:(NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading)
                                attributes:@{NSFontAttributeName:font}
                                   context:nil].size;
    }else{
        NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
        paraStyle.lineBreakMode = lineBreakMode;
        
        size = [self boundingRectWithSize:maxSize
                                  options:NSStringDrawingUsesLineFragmentOrigin
                               attributes:@{NSFontAttributeName:font, NSParagraphStyleAttributeName:paraStyle}
                                  context:nil].size;
        
    }
    
    return [self makesureSizeIsValid:size];
}

- (void)hbDrawInRect:(CGRect)rect withFont:(UIFont *)font lineBreakMode:(NSLineBreakMode)lineBreakMode alignment:(NSTextAlignment)alignment
{
    NSCParameterAssert(font);
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setAlignment:alignment];
    [paragraphStyle setLineBreakMode:lineBreakMode];
    NSDictionary *dictionary = @{ NSFontAttributeName:font,
                                  NSParagraphStyleAttributeName : paragraphStyle
                                  };
    if (IS_OS_7_OR_LATER)
    {
        [ self drawInRect:rect withAttributes:dictionary];
    }
    else
    {
        [self drawInRect:rect withFont:font lineBreakMode:lineBreakMode];
    }
}

@end

//
//  TOPasscodeCircleImage.m
//
//  Copyright 2017 Timothy Oliver. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
//  IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "TOPasscodeCircleImage.h"

@implementation TOPasscodeCircleImage

+ (UIImage *)circleImageOfSize:(CGFloat)size inset:(CGFloat)inset padding:(CGFloat)padding antialias:(BOOL)antialias
{
    UIImage *image = nil;
    CGSize imageSize = (CGSize){size + (padding * 2), size + (padding * 2)};

    UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0.0f);
    {
        CGContextRef context = UIGraphicsGetCurrentContext();

        if (!antialias) {
            CGContextSetShouldAntialias(context, NO);
        }

        CGRect rect = (CGRect){padding + inset, padding + inset, size - (inset * 2), size - (inset * 2)};
        UIBezierPath* ovalPath = [UIBezierPath bezierPathWithOvalInRect:rect];
        [[UIColor blackColor] setFill];
        [ovalPath fill];

        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();

    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

+ (UIImage *)hollowCircleImageOfSize:(CGFloat)size strokeWidth:(CGFloat)strokeWidth padding:(CGFloat)padding
{
    UIImage *image = nil;
    CGSize canvasSize = (CGSize){size + (padding * 2), size + (padding * 2)};
    CGSize circleSize = (CGSize){size, size};

    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, 0.0f);
    {
        CGRect circleRect = (CGRect){{padding, padding}, circleSize};
        circleRect = CGRectInset(circleRect, (strokeWidth * 0.5f), (strokeWidth * 0.5f));

        UIBezierPath *path = [UIBezierPath bezierPathWithOvalInRect:circleRect];
        [[UIColor blackColor] setStroke];
        path.lineWidth = strokeWidth;
        [path stroke];
        
        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();

    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

@end

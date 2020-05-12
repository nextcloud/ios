//
//  TOSettingsKeypadImage.m
//  TOPasscodeViewControllerExample
//
//  Created by Tim Oliver on 6/20/17.
//  Copyright © 2017 Timothy Oliver. All rights reserved.
//

#import "TOSettingsKeypadImage.h"

#define TOP_LEFT(X, Y) CGPointMake(rect.origin.x + X * limitedRadius, rect.origin.y + Y * limitedRadius)
#define TOP_RIGHT(X, Y) CGPointMake(rect.origin.x + rect.size.width - X * limitedRadius, rect.origin.y + Y * limitedRadius)
#define BOTTOM_RIGHT(X, Y) CGPointMake(rect.origin.x + rect.size.width - X * limitedRadius, rect.origin.y + rect.size.height - Y * limitedRadius)
#define BOTTOM_LEFT(X, Y) CGPointMake(rect.origin.x + X * limitedRadius, rect.origin.y + rect.size.height - Y * limitedRadius)

@implementation TOSettingsKeypadImage

+ (UIImage *)buttonImageWithCornerRadius:(CGFloat)radius
                         foregroundColor:(UIColor *)foregroundColor
                               edgeColor:(UIColor *)edgeColor
                           edgeThickness:(CGFloat)thickness
{
    CGFloat width = (radius * 2.0f) + 1.0f;
    CGFloat height = width + thickness;

    CGRect frame = (CGRect){CGPointZero, {width, height}};

    UIImage *image = nil;
    UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0.0f);
    {
        CGContextRef context = UIGraphicsGetCurrentContext();

        NSShadow* shadow = [[NSShadow alloc] init];
        shadow.shadowColor  = edgeColor;
        shadow.shadowOffset = CGSizeMake(0, thickness);
        shadow.shadowBlurRadius = 0;

        CGRect buttonFrame = frame;
        buttonFrame.size.height -= thickness;

        CGContextSaveGState(context);
        {
            CGContextSetShadowWithColor(context, shadow.shadowOffset, shadow.shadowBlurRadius, [shadow.shadowColor CGColor]);
            UIBezierPath *buttonPath = [[self class] bezierPathWithContinuousRoundedRect:buttonFrame cornerRadius:radius];//bezierPathWithRoundedRect:buttonFrame cornerRadius:radius];
            [foregroundColor setFill];
            [buttonPath fill];
        }
        CGContextRestoreGState(context);

        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();

    UIEdgeInsets insets = UIEdgeInsetsMake(radius, radius, radius + thickness, radius);
    image = [image resizableImageWithCapInsets:insets];

    return image;
}

+ (UIImage *)deleteIcon
{
    UIImage *image = nil;

    CGRect frame = CGRectMake(0, 0, 40.0f, 21.0f);
    UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0.0f);
    {
        //// DeleteIcon
        {
            //// Border Drawing
            UIBezierPath* borderPath = [UIBezierPath bezierPath];
            [borderPath moveToPoint: CGPointMake(25.73, 1.5)];
            [borderPath addLineToPoint: CGPointMake(25.9, 1.53)];
            [borderPath addCurveToPoint: CGPointMake(28.34, 3.46) controlPoint1: CGPointMake(27.03, 1.86) controlPoint2: CGPointMake(27.93, 2.56)];
            [borderPath addCurveToPoint: CGPointMake(28.67, 6.56) controlPoint1: CGPointMake(28.67, 4.28) controlPoint2: CGPointMake(28.67, 5.04)];
            [borderPath addLineToPoint: CGPointMake(28.64, 14.23)];
            [borderPath addCurveToPoint: CGPointMake(28.35, 17.05) controlPoint1: CGPointMake(28.64, 15.76) controlPoint2: CGPointMake(28.64, 16.37)];
            [borderPath addLineToPoint: CGPointMake(28.31, 17.19)];
            [borderPath addCurveToPoint: CGPointMake(25.86, 19.11) controlPoint1: CGPointMake(27.89, 18.08) controlPoint2: CGPointMake(27, 18.79)];
            [borderPath addCurveToPoint: CGPointMake(21.4, 19.37) controlPoint1: CGPointMake(24.82, 19.37) controlPoint2: CGPointMake(23.34, 19.37)];
            [borderPath addLineToPoint: CGPointMake(11.51, 19.37)];
            [borderPath addCurveToPoint: CGPointMake(9.9, 19.07) controlPoint1: CGPointMake(11.51, 19.37) controlPoint2: CGPointMake(10.41, 19.3)];
            [borderPath addCurveToPoint: CGPointMake(7.38, 17.06) controlPoint1: CGPointMake(9.09, 18.68) controlPoint2: CGPointMake(8.52, 18.14)];
            [borderPath addLineToPoint: CGPointMake(3.92, 13.81)];
            [borderPath addCurveToPoint: CGPointMake(1.87, 11.55) controlPoint1: CGPointMake(2.78, 12.73) controlPoint2: CGPointMake(2.21, 12.19)];
            [borderPath addLineToPoint: CGPointMake(1.79, 11.43)];
            [borderPath addCurveToPoint: CGPointMake(1.82, 9.06) controlPoint1: CGPointMake(1.36, 10.57) controlPoint2: CGPointMake(1.4, 9.92)];
            [borderPath addCurveToPoint: CGPointMake(3.96, 6.68) controlPoint1: CGPointMake(2.25, 8.29) controlPoint2: CGPointMake(2.82, 7.76)];
            [borderPath addLineToPoint: CGPointMake(7.21, 3.61)];
            [borderPath addCurveToPoint: CGPointMake(9.61, 1.67) controlPoint1: CGPointMake(8.35, 2.54) controlPoint2: CGPointMake(8.92, 2)];
            [borderPath addLineToPoint: CGPointMake(9.73, 1.6)];
            [borderPath addCurveToPoint: CGPointMake(11.41, 1.31) controlPoint1: CGPointMake(10.26, 1.37) controlPoint2: CGPointMake(10.84, 1.27)];
            [borderPath addLineToPoint: CGPointMake(21.44, 1.27)];
            [borderPath addCurveToPoint: CGPointMake(25.73, 1.5) controlPoint1: CGPointMake(23.38, 1.27) controlPoint2: CGPointMake(24.85, 1.27)];
            [borderPath closePath];
            [UIColor.blackColor setStroke];
            borderPath.lineWidth = 2.5;
            [borderPath stroke];


            //// Cross Drawing
            UIBezierPath* crossPath = [UIBezierPath bezierPath];
            [crossPath moveToPoint: CGPointMake(15.22, 5.9)];
            [crossPath addCurveToPoint: CGPointMake(15.21, 5.88) controlPoint1: CGPointMake(15.27, 5.95) controlPoint2: CGPointMake(15.21, 5.88)];
            [crossPath addLineToPoint: CGPointMake(15.22, 5.9)];
            [crossPath closePath];
            [crossPath moveToPoint: CGPointMake(16.18, 10.28)];
            [crossPath addCurveToPoint: CGPointMake(16.19, 10.26) controlPoint1: CGPointMake(16.22, 10.29) controlPoint2: CGPointMake(16.2, 10.28)];
            [crossPath addLineToPoint: CGPointMake(16.18, 10.28)];
            [crossPath closePath];
            [crossPath moveToPoint: CGPointMake(14.52, 5.35)];
            [crossPath addCurveToPoint: CGPointMake(15.21, 5.88) controlPoint1: CGPointMake(14.75, 5.46) controlPoint2: CGPointMake(14.93, 5.62)];
            [crossPath addCurveToPoint: CGPointMake(15.38, 6.05) controlPoint1: CGPointMake(15.26, 5.94) controlPoint2: CGPointMake(15.32, 5.99)];
            [crossPath addCurveToPoint: CGPointMake(15.43, 6.09) controlPoint1: CGPointMake(15.42, 6.09) controlPoint2: CGPointMake(15.43, 6.09)];
            [crossPath addCurveToPoint: CGPointMake(15.38, 6.05) controlPoint1: CGPointMake(15.21, 5.88) controlPoint2: CGPointMake(15.27, 5.95)];
            [crossPath addCurveToPoint: CGPointMake(17.97, 8.55) controlPoint1: CGPointMake(15.94, 6.59) controlPoint2: CGPointMake(17.66, 8.25)];
            [crossPath addCurveToPoint: CGPointMake(17.97, 8.55) controlPoint1: CGPointMake(17.91, 8.61) controlPoint2: CGPointMake(17.94, 8.58)];
            [crossPath addCurveToPoint: CGPointMake(21.36, 5.39) controlPoint1: CGPointMake(20.95, 5.68) controlPoint2: CGPointMake(21.14, 5.5)];
            [crossPath addCurveToPoint: CGPointMake(22.67, 5.58) controlPoint1: CGPointMake(21.83, 5.17) controlPoint2: CGPointMake(22.34, 5.26)];
            [crossPath addCurveToPoint: CGPointMake(22.98, 6.89) controlPoint1: CGPointMake(23.09, 5.99) controlPoint2: CGPointMake(23.18, 6.47)];
            [crossPath addCurveToPoint: CGPointMake(22.28, 7.68) controlPoint1: CGPointMake(22.84, 7.14) controlPoint2: CGPointMake(22.65, 7.32)];
            [crossPath addCurveToPoint: CGPointMake(19.68, 10.19) controlPoint1: CGPointMake(22.28, 7.68) controlPoint2: CGPointMake(20.88, 9.03)];
            [crossPath addCurveToPoint: CGPointMake(22.97, 13.47) controlPoint1: CGPointMake(22.66, 13.06) controlPoint2: CGPointMake(22.85, 13.25)];
            [crossPath addCurveToPoint: CGPointMake(22.76, 14.79) controlPoint1: CGPointMake(23.21, 13.95) controlPoint2: CGPointMake(23.11, 14.46)];
            [crossPath addCurveToPoint: CGPointMake(21.35, 15.1) controlPoint1: CGPointMake(22.33, 15.22) controlPoint2: CGPointMake(21.8, 15.31)];
            [crossPath addCurveToPoint: CGPointMake(20.48, 14.4) controlPoint1: CGPointMake(21.07, 14.97) controlPoint2: CGPointMake(20.87, 14.78)];
            [crossPath addCurveToPoint: CGPointMake(17.89, 11.91) controlPoint1: CGPointMake(20.48, 14.4) controlPoint2: CGPointMake(19.08, 13.05)];
            [crossPath addCurveToPoint: CGPointMake(14.5, 15.06) controlPoint1: CGPointMake(14.91, 14.78) controlPoint2: CGPointMake(14.73, 14.95)];
            [crossPath addCurveToPoint: CGPointMake(13.2, 14.87) controlPoint1: CGPointMake(14.04, 15.28) controlPoint2: CGPointMake(13.53, 15.19)];
            [crossPath addCurveToPoint: CGPointMake(12.89, 13.57) controlPoint1: CGPointMake(12.78, 14.47) controlPoint2: CGPointMake(12.69, 13.98)];
            [crossPath addCurveToPoint: CGPointMake(13.42, 12.93) controlPoint1: CGPointMake(13, 13.35) controlPoint2: CGPointMake(13.15, 13.19)];
            [crossPath addCurveToPoint: CGPointMake(13.59, 12.77) controlPoint1: CGPointMake(13.47, 12.88) controlPoint2: CGPointMake(13.53, 12.83)];
            [crossPath addCurveToPoint: CGPointMake(16.19, 10.26) controlPoint1: CGPointMake(14.12, 12.25) controlPoint2: CGPointMake(15.78, 10.66)];
            [crossPath addCurveToPoint: CGPointMake(12.89, 6.98) controlPoint1: CGPointMake(13.21, 7.39) controlPoint2: CGPointMake(13.01, 7.2)];
            [crossPath addCurveToPoint: CGPointMake(12.77, 6.63) controlPoint1: CGPointMake(12.82, 6.84) controlPoint2: CGPointMake(12.79, 6.73)];
            [crossPath addCurveToPoint: CGPointMake(13.1, 5.66) controlPoint1: CGPointMake(12.72, 6.28) controlPoint2: CGPointMake(12.83, 5.92)];
            [crossPath addCurveToPoint: CGPointMake(14.52, 5.35) controlPoint1: CGPointMake(13.54, 5.24) controlPoint2: CGPointMake(14.07, 5.15)];
            [crossPath closePath];
            [UIColor.blackColor setFill];
            [crossPath fill];
        }

        image = UIGraphicsGetImageFromCurrentImageContext();
    }
    UIGraphicsEndImageContext();

    return [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

/**
 Creates a bezier path with the iOS 7 squircle shape.

 A HUGE thanks to the folks at PaintCode for open-sourcing this
 https://www.paintcodeapp.com/news/code-for-ios-7-rounded-rectangles
 */
+ (UIBezierPath *)bezierPathWithContinuousRoundedRect:(CGRect)rect cornerRadius:(CGFloat)radius
{
    UIBezierPath* path = UIBezierPath.bezierPath;
    CGFloat limit = MIN(rect.size.width, rect.size.height) / 2 / 1.52866483;
    CGFloat limitedRadius = MIN(radius, limit);

    [path moveToPoint: TOP_LEFT(1.52866483, 0.00000000)];
    [path addLineToPoint: TOP_RIGHT(1.52866471, 0.00000000)];
    [path addCurveToPoint: TOP_RIGHT(0.66993427, 0.06549600) controlPoint1: TOP_RIGHT(1.08849323, 0.00000000) controlPoint2: TOP_RIGHT(0.86840689, 0.00000000)];
    [path addLineToPoint: TOP_RIGHT(0.63149399, 0.07491100)];
    [path addCurveToPoint: TOP_RIGHT(0.07491176, 0.63149399) controlPoint1: TOP_RIGHT(0.37282392, 0.16905899) controlPoint2: TOP_RIGHT(0.16906013, 0.37282401)];
    [path addCurveToPoint: TOP_RIGHT(0.00000000, 1.52866483) controlPoint1: TOP_RIGHT(0.00000000, 0.86840701) controlPoint2: TOP_RIGHT(0.00000000, 1.08849299)];
    [path addLineToPoint: BOTTOM_RIGHT(0.00000000, 1.52866471)];
    [path addCurveToPoint: BOTTOM_RIGHT(0.06549569, 0.66993493) controlPoint1: BOTTOM_RIGHT(0.00000000, 1.08849323) controlPoint2: BOTTOM_RIGHT(0.00000000, 0.86840689)];
    [path addLineToPoint: BOTTOM_RIGHT(0.07491111, 0.63149399)];
    [path addCurveToPoint: BOTTOM_RIGHT(0.63149399, 0.07491111) controlPoint1: BOTTOM_RIGHT(0.16905883, 0.37282392) controlPoint2: BOTTOM_RIGHT(0.37282392, 0.16905883)];
    [path addCurveToPoint: BOTTOM_RIGHT(1.52866471, 0.00000000) controlPoint1: BOTTOM_RIGHT(0.86840689, 0.00000000) controlPoint2: BOTTOM_RIGHT(1.08849323, 0.00000000)];
    [path addLineToPoint: BOTTOM_LEFT(1.52866483, 0.00000000)];
    [path addCurveToPoint: BOTTOM_LEFT(0.66993397, 0.06549569) controlPoint1: BOTTOM_LEFT(1.08849299, 0.00000000) controlPoint2: BOTTOM_LEFT(0.86840701, 0.00000000)];
    [path addLineToPoint: BOTTOM_LEFT(0.63149399, 0.07491111)];
    [path addCurveToPoint: BOTTOM_LEFT(0.07491100, 0.63149399) controlPoint1: BOTTOM_LEFT(0.37282401, 0.16905883) controlPoint2: BOTTOM_LEFT(0.16906001, 0.37282392)];
    [path addCurveToPoint: BOTTOM_LEFT(0.00000000, 1.52866471) controlPoint1: BOTTOM_LEFT(0.00000000, 0.86840689) controlPoint2: BOTTOM_LEFT(0.00000000, 1.08849323)];
    [path addLineToPoint: TOP_LEFT(0.00000000, 1.52866483)];
    [path addCurveToPoint: TOP_LEFT(0.06549600, 0.66993397) controlPoint1: TOP_LEFT(0.00000000, 1.08849299) controlPoint2: TOP_LEFT(0.00000000, 0.86840701)];
    [path addLineToPoint: TOP_LEFT(0.07491100, 0.63149399)];
    [path addCurveToPoint: TOP_LEFT(0.63149399, 0.07491100) controlPoint1: TOP_LEFT(0.16906001, 0.37282401) controlPoint2: TOP_LEFT(0.37282401, 0.16906001)];
    [path addCurveToPoint: TOP_LEFT(1.52866483, 0.00000000) controlPoint1: TOP_LEFT(0.86840701, 0.00000000) controlPoint2: TOP_LEFT(1.08849299, 0.00000000)];
    [path closePath];
    return path;
}

@end

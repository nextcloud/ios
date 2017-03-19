//
//  UINavigationController+SGProgress.h
//  NavigationProgress
//
//  Created by Shawn Gryschuk on 2013-09-19.
//  Copyright (c) 2013 Shawn Gryschuk. All rights reserved.
//
//  Modify Marino Faggiana

#import <UIKit/UIKit.h>

#define kSGProgressTitleChanged @"kCCProgressTitleChanged"
#define kSGProgressOldTitle @"kCCProgressOldTitle"

@interface UINavigationController (CCProgress)

- (void)showCCProgress;
- (void)showCCProgressWithDuration:(float)duration;
- (void)showCCProgressWithDuration:(float)duration andTintColor:(UIColor *)tintColor;
- (void)showCCProgressWithDuration:(float)duration andTintColor:(UIColor *)tintColor andTitle:(NSString *)title;
- (void)showCCProgressWithMaskAndDuration:(float)duration;
- (void)showCCProgressWithMaskAndDuration:(float)duration andTitle:(NSString *)title;

- (void)finishCCProgress;
- (void)cancelCCProgress;

- (void)setCCProgressPercentage:(float)percentage;
- (void)setCCProgressPercentage:(float)percentage andTitle:(NSString *)title;
- (void)setCCProgressPercentage:(float)percentage andTintColor:(UIColor *)tintColor;
- (void)setCCProgressMaskWithPercentage:(float)percentage;
- (void)setCCProgressMaskWithPercentage:(float)percentage andTitle:(NSString *)title;

@end

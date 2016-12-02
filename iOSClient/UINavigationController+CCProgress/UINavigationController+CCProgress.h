//
//  UINavigationController+CCProgress.h
//  NavigationProgress
//
//  Created by Marino Faggiana on 22/06/16.
//  Copyright (c) 2016 TWS. All rights reserved.
//

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

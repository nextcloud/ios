//
//  TOPasscodeViewControllerAnimatedTransitioning.h
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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class TOPasscodeViewController;

NS_ASSUME_NONNULL_BEGIN

/**
 An class conforming to `UIViewControllerAnimatedTransitioning` that handles the custom animation
 that plays when the passcode view controller is presented on the user's screen.
 */
@interface TOPasscodeViewControllerAnimatedTransitioning : NSObject <UIViewControllerAnimatedTransitioning>

/** The parent passcode view controller that this object will be controlling */
@property (nonatomic, weak, readonly) TOPasscodeViewController *passcodeViewController;

/** Whether the controller is being presented or dismissed. The animation is played in reverse when dismissing. */
@property (nonatomic, assign) BOOL dismissing;

/** If the correct passcode was successfully entered, this property can be set to YES. When the view controller
 is dismissing, the keypad view will also play a zooming out animation to give added context to the dismissal. */
@property (nonatomic, assign) BOOL success;

/**
 Creates a new instanc of `TOPasscodeViewControllerAnimatedTransitioning` that will control the provided passcode
 view controller.

 @param passcodeViewController The passcode view controller in which this object will coordinate the animation upon.
 @param dismissing Whether the animation is played to present the view controller, or dismiss it.
 @param success Whether the object needs to play an additional zooming animation denoting the passcode was successfully entered.
 */
- (instancetype)initWithPasscodeViewController:(TOPasscodeViewController *)passcodeViewController
                                    dismissing:(BOOL)dismissing
                                       success:(BOOL)success;

@end

NS_ASSUME_NONNULL_END

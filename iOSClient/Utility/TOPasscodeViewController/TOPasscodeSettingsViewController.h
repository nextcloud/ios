//
//  TOPasscodeSettingsViewController.h
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

#import <UIKit/UIKit.h>
#import "TOPasscodeViewControllerConstants.h"

@class TOPasscodeSettingsViewController;

typedef NS_ENUM(NSInteger, TOPasscodeSettingsViewState) {
    TOPasscodeSettingsViewStateEnterCurrentPasscode,
    TOPasscodeSettingsViewStateEnterNewPasscode,
    TOPasscodeSettingsViewStateConfirmNewPasscode
};

NS_ASSUME_NONNULL_BEGIN

/**
 A delegate object in charge of validating and recording the passcodes entered by the user.
 */
@protocol TOPasscodeSettingsViewControllerDelegate <NSObject>

@optional

/** Called when the user was prompted to input their current passcode.
 Return YES if passcode was right and NO otherwise.

 Returning NO will cause a warning label to appear
 */
- (BOOL)passcodeSettingsViewController:(TOPasscodeSettingsViewController *)passcodeSettingsViewController
             didAttemptCurrentPasscode:(NSString *)passcode;

/** Called when the user has successfully set a new passcode. At this point, you should save over
    the old passcode with the new one. */
- (void)passcodeSettingsViewController:(TOPasscodeSettingsViewController *)passcodeSettingsViewController
                didChangeToNewPasscode:(NSString *)passcode ofType:(TOPasscodeType)type;

@end

// ----------------------------------------------------------------------

/**
 A standard system-styled view controller that users can use to change the passcode
 that they will need to enter for the main passcode view controller.

 This controller allows requiring the user to enter their previous passcode in first,
 and has passcode validation by requiring them to enter the new passcode twice.
 */

@interface TOPasscodeSettingsViewController : UIViewController

/** Delegate event for controlling and responding to the behavior of this controller */
@property (nonatomic, weak, nullable) id<TOPasscodeSettingsViewControllerDelegate> delegate;

/** The current state of the controller (confirming old passcode or creating a new one) */
@property (nonatomic, assign) TOPasscodeSettingsViewState state;

/** The input type of the passcode */
@property (nonatomic, assign) TOPasscodeType passcodeType;

/** The number of incorrect passcode attempts the user has made. Use this property to decide when to disable input. */
@property (nonatomic, assign) NSInteger failedPasscodeAttemptCount;

/** Before setting a new passcode, show a UI to validate the existing passcode. (Default is NO) */
@property (nonatomic, assign) BOOL requireCurrentPasscode;

/** If set, the view controller will disable input until this date time has been reached */
@property (nonatomic, strong, nullable) NSDate *disabledInputDate;

/** Hide the button Options (Default is NO) */
@property (nonatomic, assign) BOOL hideOptionsButton;

/*
 Create a new instance with the desird light or dark style

 @param style The visual style of the view controller
 */
- (instancetype)init;

/*
 Changes the passcode type and animates if required

 @param passcodeType Change the type of passcode to enter.
 @param animated Play a crossfade animation.
 */
- (void)setPasscodeType:(TOPasscodeType)passcodeType animated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

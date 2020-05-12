//
//  TOPasscodeInputField.h
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

#import "TOPasscodeFixedInputView.h"
#import "TOPasscodeVariableInputView.h"


NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, TOPasscodeInputFieldStyle) {
    TOPasscodeInputFieldStyleFixed,    // The passcode explicitly requires a specific number of characters (Shows hollow circles)
    TOPasscodeInputFieldStyleVariable  // The passcode can be any arbitrary number of characters (Shows an empty rectangle)
};

/**
 An abstract input view capable of receiving different types of passcodes.
 When a fixed character passcode is specified, the view shows a row of circles.
 When a variable passcode is specified, a rounded rectangle is shown.
 */
@interface TOPasscodeInputField : UIView <UIKeyInput>

/* The visual effects view used to control the vibrancy of the input field */
@property (nonatomic, strong, readonly) UIVisualEffectView *visualEffectView;

/* The input style of this control */
@property (nonatomic, assign) TOPasscodeInputFieldStyle style;

/* A row of hollow circles at a preset length. Valid only when `style` is set to `fixed` */
@property (nonatomic, readonly, nullable) TOPasscodeFixedInputView *fixedInputView;

/* A rounded rectangle representing a passcode of arbitrary length. Valid only when `style` is set to `variable`. */
@property (nonatomic, readonly, nullable) TOPasscodeVariableInputView *variableInputView;

/* The 'submit' button shown when `showSubmitButton` is true. */
@property (nonatomic, readonly, nullable) UIButton *submitButton;

/* Shows an 'OK' button next to the view when characters have been added. */
@property (nonatomic, assign) BOOL showSubmitButton;

/* The amount of spacing between the 'OK' button and the passcode field */
@property (nonatomic, assign) CGFloat submitButtonSpacing;

/* The amount of spacing between the 'OK' button and the passcode field */
@property (nonatomic, assign) CGFloat submitButtonVerticalSpacing;

/* The font size of the submit button */
@property (nonatomic, assign) CGFloat submitButtonFontSize;

/* The current passcode entered into this view */
@property (nonatomic, copy, nullable) NSString *passcode;

/* If this view is directly receiving input, this can change the `UIKeyboard` appearance. */
@property (nonatomic, assign) UIKeyboardAppearance keyboardAppearance;

/* The type of button used for the 'Done' button in the keyboard */
@property(nonatomic, assign) UIReturnKeyType returnKeyType;

/* The alpha value of the views in this view (For tranclucent styling) */
@property (nonatomic, assign) CGFloat contentAlpha;

/* Whether the view may be tapped to enable character input (Default is NO) */
@property (nonatomic, assign) BOOL enabled;

/** Called when the number of digits has been entered, or the user tapped 'Done' on the keyboard */
@property (nonatomic, copy) void (^passcodeCompletedHandler)(NSString *code);

/** Horizontal layout. The 'OK' button will be placed under the text field */
@property (nonatomic, assign) BOOL horizontalLayout;

/* Init with the target length needed for this passcode */
- (instancetype)initWithStyle:(TOPasscodeInputFieldStyle)style;

/* Replace the passcode with this one, and animate the transition. */
- (void)setPasscode:(nullable NSString *)passcode animated:(BOOL)animated;

/* Add additional characters to the end of the passcode, and animate if desired. */
- (void)appendPasscodeCharacters:(NSString *)characters animated:(BOOL)animated;

/* Delete a number of characters from the end, animated if desired. */
- (void)deletePasscodeCharactersOfCount:(NSInteger)deleteCount animated:(BOOL)animated;

/* Plays a shaking animation and resets the passcode back to empty */
- (void)resetPasscodeAnimated:(BOOL)animated playImpact:(BOOL)impact;

/* Animates the OK button changing location. */
- (void)setHorizontalLayout:(BOOL)horizontalLayout animated:(BOOL)animated duration:(CGFloat)duration;

@end

NS_ASSUME_NONNULL_END

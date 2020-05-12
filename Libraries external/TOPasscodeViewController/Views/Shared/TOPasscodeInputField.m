//
//  TOPasscodeInputField.m
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

#import "TOPasscodeInputField.h"

#import "TOPasscodeVariableInputView.h"
#import "TOPasscodeFixedInputView.h"

#import <AudioToolbox/AudioToolbox.h>

@interface TOPasscodeInputField ()

// Convenience getters
@property (nonatomic, readonly) UIView *inputField; // Returns whichever input field is currently visible
@property (nonatomic, readonly) NSInteger maximumPasscodeLength; // The mamximum number of characters allowed (0 if uncapped)

@property (nonatomic, strong, readwrite) TOPasscodeFixedInputView *fixedInputView;
@property (nonatomic, strong, readwrite) TOPasscodeVariableInputView *variableInputView;
@property (nonatomic, strong, readwrite) UIButton *submitButton;
@property (nonatomic, strong, readwrite) UIVisualEffectView *visualEffectView;

@end

@implementation TOPasscodeInputField

#pragma mark - View Set-up -

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setUp];
        [self setUpForStyle:TOPasscodeInputFieldStyleFixed];
    }

    return self;
}

- (instancetype)initWithStyle:(TOPasscodeInputFieldStyle)style
{
    if (self = [self initWithFrame:CGRectZero]) {
        _style = style;
        [self setUp];
        [self setUpForStyle:style];
    }

    return self;
}

- (void)setUp
{
    self.backgroundColor = [UIColor clearColor];
    _submitButtonSpacing = 4.0f;
    _submitButtonVerticalSpacing = 5.0f;

    _visualEffectView = [[UIVisualEffectView alloc] initWithEffect:nil];
    [self addSubview:_visualEffectView];
}

- (void)setUpForStyle:(TOPasscodeInputFieldStyle)style
{
    if (self.inputField) {
        [self.inputField removeFromSuperview];
        self.variableInputView = nil;
        self.fixedInputView = nil;
    }

    if (style == TOPasscodeInputFieldStyleVariable) {
        self.variableInputView = [[TOPasscodeVariableInputView alloc] init];
        [self.visualEffectView.contentView addSubview:self.variableInputView];
    }
    else {
        self.fixedInputView = [[TOPasscodeFixedInputView alloc] init];
        [self.visualEffectView.contentView addSubview:self.fixedInputView];
    }

    // Set the frame for the currently visible input view
    [self.inputField sizeToFit];

    // Size this view to match
    [self sizeToFit];
}

#pragma mark - View Layout -
- (void)sizeToFit
{
    // Resize the view to encompass the current input view
    CGRect frame = self.frame;
    [self.inputField sizeToFit];
    frame.size = self.inputField.frame.size;
    if (self.horizontalLayout) {
        frame.size.height += self.submitButtonVerticalSpacing + CGRectGetHeight(self.submitButton.frame);
    }
    self.frame = CGRectIntegral(frame);
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    self.visualEffectView.frame = self.inputField.bounds;

    if (!self.submitButton) { return; }

    [self.submitButton sizeToFit];
    [self bringSubviewToFront:self.submitButton];

    CGRect frame = self.submitButton.frame;
    if (!self.horizontalLayout) {
        frame.origin.x = CGRectGetMaxX(self.bounds) + self.submitButtonSpacing;
        frame.origin.y = (CGRectGetHeight(self.bounds) - CGRectGetHeight(frame)) * 0.5f;
    }
    else {
        frame.origin.x = (CGRectGetWidth(self.frame) - frame.size.width) * 0.5f;
        frame.origin.y = CGRectGetMaxY(self.inputField.frame) + self.submitButtonVerticalSpacing;
    }
    self.submitButton.frame = CGRectIntegral(frame);
}

#pragma mark - Interaction -
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    if (!self.enabled) { return; }
    self.contentAlpha = 0.5f;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesCancelled:touches withEvent:event];
    if (!self.enabled) { return; }
    [UIView animateWithDuration:0.3f animations:^{
        self.contentAlpha = 1.0f;
    }];
    [self becomeFirstResponder];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGRect frame = self.bounds;
    frame.size.width += self.submitButton.frame.size.width + (self.submitButtonSpacing * 2.0f);
    frame.size.height += self.submitButtonVerticalSpacing;

    if (CGRectContainsPoint(frame, point)) {
        return YES;
    }
    return NO;
}

- (id)hitTest:(CGPoint)point withEvent:(UIEvent *)event {

    if ([[super hitTest:point withEvent:event] isEqual:self.submitButton]) {
        if (CGRectContainsPoint(self.submitButton.frame, point)) {
            return self.submitButton;
        } else {
            return self;
        }
    }

    return [super hitTest:point withEvent:event];
}

#pragma mark - Text Input Protocol -
- (BOOL)canBecomeFirstResponder { return self.enabled; }

- (BOOL)hasText { return self.passcode.length > 0; }

- (void)insertText:(NSString *)text
{
    if ([text isEqualToString:@"\n"]) {
        if (self.passcodeCompletedHandler) { self.passcodeCompletedHandler(self.passcode); }
        return;
    }

    [self appendPasscodeCharacters:text animated:NO];
}
- (void)deleteBackward
{
    [self deletePasscodeCharactersOfCount:1 animated:YES];
}

- (UIKeyboardType)keyboardType { return UIKeyboardTypeASCIICapable; }

- (UITextAutocorrectionType)autocorrectionType { return UITextAutocorrectionTypeNo; }

- (UIReturnKeyType)returnKeyType { return UIReturnKeyGo; }

- (BOOL)enablesReturnKeyAutomatically { return YES; }

#pragma mark - Text Input -
- (void)setPasscode:(NSString *)passcode animated:(BOOL)animated
{
    if (passcode == self.passcode) { return; }
    _passcode = passcode;

    BOOL passcodeIsComplete = NO;
    if (self.fixedInputView) {
        [self.fixedInputView setHighlightedLength:_passcode.length animated:animated];
        passcodeIsComplete = _passcode.length >= self.maximumPasscodeLength;
    }
    else {
        [self.variableInputView setLength:_passcode.length animated:animated];
    }

    if (self.submitButton) {
        self.submitButton.hidden = (_passcode.length == 0);
        [self bringSubviewToFront:self.submitButton];
    }

    if (passcodeIsComplete && self.passcodeCompletedHandler) {
        self.passcodeCompletedHandler(_passcode);
    }

    [self reloadInputViews];
}

- (void)appendPasscodeCharacters:(NSString *)characters animated:(BOOL)animated
{
    if (characters == nil) { return; }
    if (self.maximumPasscodeLength > 0 && self.passcode.length >= self.maximumPasscodeLength) { return; }

    if (_passcode == nil) { _passcode = @""; }
    [self setPasscode:[_passcode stringByAppendingString:characters] animated:animated];
}

- (void)deletePasscodeCharactersOfCount:(NSInteger)deleteCount animated:(BOOL)animated
{
    if (deleteCount <= 0 || self.passcode.length <= 0) { return; }
    [self setPasscode:[self.passcode substringToIndex:(self.passcode.length - 1)] animated:animated];
}

- (void)resetPasscodeAnimated:(BOOL)animated playImpact:(BOOL)impact
{
    [self setPasscode:nil animated:animated];

    // Play a negative impact effect
    if (@available(iOS 9.0, *)) {
        // https://stackoverflow.com/questions/41444274/how-to-check-if-haptic-engine-uifeedbackgenerator-is-supported
        if (impact) { AudioServicesPlaySystemSoundWithCompletion(1521, nil); }
    }

    if (!animated) { return; }

    CGPoint center = self.center;
    CGPoint offset = center;
    offset.x -= self.frame.size.width * 0.3f;

    // Play the view sliding out and then springing back in
    id completionBlock = ^(BOOL finished) {
        [UIView animateWithDuration:1.0f
                              delay:0.0f
             usingSpringWithDamping:0.15f
              initialSpringVelocity:10.0f
                            options:0 animations:^{
                                self.center = center;
                            }completion:nil];
    };

    [UIView animateWithDuration:0.05f animations:^{
        self.center = offset;
    }completion:completionBlock];

    if (!self.submitButton) { return; }

    [UIView animateWithDuration:0.7f animations:^{
        self.submitButton.alpha = 0.0f;
    } completion:^(BOOL complete) {
        self.submitButton.alpha = 1.0f;
        self.submitButton.hidden = YES;
    }];
}

#pragma mark - Button Callbacks -
- (void)submitButtonTapped:(id)sender
{
    if (self.passcodeCompletedHandler) {
        self.passcodeCompletedHandler(self.passcode);
    }
}

#pragma mark - Private Accessors -
- (UIView *)inputField
{
    if (self.fixedInputView) {
        return (UIView *)self.fixedInputView;
    }

    return (UIView *)self.variableInputView;
}

- (NSInteger)maximumPasscodeLength
{
    if (self.style == TOPasscodeInputFieldStyleFixed) {
        return self.fixedInputView.length;
    }

    return 0;
}

#pragma mark - Public Accessors -

- (void)setShowSubmitButton:(BOOL)showSubmitButton
{
    if (_showSubmitButton == showSubmitButton) {
        return;
    }

    _showSubmitButton = showSubmitButton;

    if (!_showSubmitButton) {
        [self.submitButton removeFromSuperview];
        self.submitButton = nil;
        return;
    }

    self.submitButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.submitButton setTitle:@"OK" forState:UIControlStateNormal];
    [self.submitButton addTarget:self action:@selector(submitButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.submitButton.titleLabel setFont:[UIFont systemFontOfSize:18.0f]];
    self.submitButton.hidden = YES;
    [self addSubview:self.submitButton];

    [self setNeedsLayout];
}

- (void)setSubmitButtonSpacing:(CGFloat)submitButtonSpacing
{
    if (submitButtonSpacing == _submitButtonSpacing) { return; }
    _submitButtonSpacing = submitButtonSpacing;
    [self setNeedsLayout];
}

- (void)setSubmitButtonFontSize:(CGFloat)submitButtonFontSize
{
    if (submitButtonFontSize == _submitButtonFontSize) { return; }
    _submitButtonFontSize = submitButtonFontSize;
    self.submitButton.titleLabel.font = [UIFont systemFontOfSize:_submitButtonFontSize];
    [self.submitButton sizeToFit];
    [self setNeedsLayout];
}

- (void)setStyle:(TOPasscodeInputFieldStyle)style
{
    if (style == _style) { return; }
    _style = style;
    [self setUpForStyle:_style];
}

- (void)setPasscode:(NSString *)passcode
{
    [self setPasscode:passcode animated:NO];
}

- (void)setContentAlpha:(CGFloat)contentAlpha
{
    _contentAlpha = contentAlpha;
    self.inputField.alpha = contentAlpha;
    self.submitButton.alpha = contentAlpha;
}

- (void)setHorizontalLayout:(BOOL)horizontalLayout
{
    [self setHorizontalLayout:horizontalLayout animated:NO duration:0.0f];
}

- (void)setHorizontalLayout:(BOOL)horizontalLayout animated:(BOOL)animated duration:(CGFloat)duration
{
    if (_horizontalLayout == horizontalLayout) {
        return;
    }

    UIView *snapshotView = nil;

    if (self.submitButton && self.submitButton.hidden == NO && animated) {
        snapshotView = [self.submitButton snapshotViewAfterScreenUpdates:NO];
        snapshotView.frame = self.submitButton.frame;
        [self addSubview:snapshotView];
    }

    _horizontalLayout = horizontalLayout;

    if (!animated || !self.submitButton) {
        [self sizeToFit];
        [self setNeedsLayout];
        return;
    }

    self.submitButton.alpha = 0.0f;
    [self setNeedsLayout];
    [self layoutIfNeeded];

    id animationBlock = ^{
        self.submitButton.alpha = 1.0f;
        snapshotView.alpha = 0.0f;
    };

    id completionBlock = ^(BOOL complete) {
        [snapshotView removeFromSuperview];
        [self bringSubviewToFront:self.submitButton];
    };

    [UIView animateWithDuration:duration animations:animationBlock completion:completionBlock];
}

@end

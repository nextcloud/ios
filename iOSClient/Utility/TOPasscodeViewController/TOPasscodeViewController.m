//
//  TOPasscodeViewController.m
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

#import "TOPasscodeViewController.h"
#import "TOPasscodeView.h"
#import "TOPasscodeViewControllerAnimatedTransitioning.h"
#import "TOPasscodeKeypadView.h"
#import "TOPasscodeInputField.h"

@interface TOPasscodeViewController () <UIViewControllerTransitioningDelegate>

/* State */
@property (nonatomic, assign, readwrite) TOPasscodeType passcodeType;
@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, assign) BOOL passcodeSuccess;
@property (nonatomic, readonly) UIView *leftButton;
@property (nonatomic, readonly) UIView *rightButton;

/* Views */
@property (nonatomic, strong, readwrite) UIVisualEffectView *backgroundEffectView;
@property (nonatomic, strong, readwrite) UIView *backgroundView;
@property (nonatomic, strong, readwrite) TOPasscodeView *passcodeView;
@property (nonatomic, strong, readwrite) UIButton *biometricButton;
@property (nonatomic, strong, readwrite) UIButton *cancelButton;

/* Style */
@property (nonatomic, assign) TOPasscodeViewStyle style;
@property (nonatomic, assign) BOOL allowCancel;

@end

@implementation TOPasscodeViewController

#pragma mark - Instance Creation -

- (instancetype)initPasscodeType:(TOPasscodeType)type allowCancel:(BOOL)cancel
{
    if (self = [super initWithNibName:nil bundle:nil]) {
        _passcodeType = type;
        _allowCancel = cancel;
        [self setUp];
    }

    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [self setUp];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - View Setup -

- (void)setUp
{
    self.transitioningDelegate = self;
    self.automaticallyPromptForBiometricValidation = NO;
    self.handleDeletePress = YES;

    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
            self.style = TOPasscodeViewStyleTranslucentDark;
        } else {
            self.style = TOPasscodeViewStyleTranslucentLight;
        }
    } else {
        self.style = TOPasscodeViewStyleTranslucentLight;
    }
    
    if (TOPasscodeViewStyleIsTranslucent(self.style)) {
        self.modalPresentationStyle = UIModalPresentationOverFullScreen;
    }
    else {
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:)
                                                     name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)setUpBackgroundEffectViewForStyle:(TOPasscodeViewStyle)style
{
    BOOL translucent = TOPasscodeViewStyleIsTranslucent(style);

    // Return if it already exists when it should
    if (translucent && self.backgroundEffectView) { return; }

    // Return if it doesn't exist when it shouldn't
    if (!translucent && !self.backgroundEffectView) { return; }

    // Remove it if we're now opaque
    if (!translucent) {
        [self.backgroundEffectView removeFromSuperview];
        self.backgroundEffectView = nil;
        return;
    }

    // Create it otherwise
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:[self blurEffectStyleForStyle:style]];
    self.backgroundEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.backgroundEffectView.frame = self.view.bounds;
    self.backgroundEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.backgroundEffectView atIndex:0];
}

- (void)setUpBackgroundViewForStyle:(TOPasscodeViewStyle)style
{
    BOOL translucent = TOPasscodeViewStyleIsTranslucent(style);

    if (!translucent && self.backgroundView) { return; }

    if (translucent && !self.backgroundView) { return; }

    if (translucent) {
        [self.backgroundView removeFromSuperview];
        self.backgroundView = nil;
        return;
    }

    self.backgroundView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.backgroundView atIndex:0];
}

- (UIBlurEffectStyle)blurEffectStyleForStyle:(TOPasscodeViewStyle)style
{
    switch (self.style) {
        case TOPasscodeViewStyleTranslucentDark: return UIBlurEffectStyleDark;
        case TOPasscodeViewStyleTranslucentLight: return UIBlurEffectStyleExtraLight;
        default: return 0;
    }

    return 0;
}

- (void)setUpAccessoryButtons
{
    UIFont *buttonFont = [UIFont systemFontOfSize:16.0f];
    BOOL isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;

    if (!self.leftAccessoryButton && self.allowBiometricValidation && !self.biometricButton) {
        self.biometricButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.biometricButton setTitle:TOPasscodeBiometryTitleForType(self.biometryType) forState:UIControlStateNormal];
        [self.biometricButton addTarget:self action:@selector(accessoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];

        if (isPad) {
            self.passcodeView.leftButton = self.biometricButton;
        }
        else {
            [self.view addSubview:self.biometricButton];
        }
    }
    else {
        if (self.leftAccessoryButton) {
            [self.biometricButton removeFromSuperview];
            self.biometricButton = nil;
        }
    }

    if (!self.rightAccessoryButton && !self.cancelButton) {
        self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [self.cancelButton setTitle:NSLocalizedString(@"Cancel", @"Cancel") forState:UIControlStateNormal];
        self.cancelButton.titleLabel.font = buttonFont;
        [self.cancelButton addTarget:self action:@selector(accessoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        // If cancelling is disabled, we hide the cancel button but we still create it, because it can
        // transition to backspace after user input.
        self.cancelButton.hidden = !self.allowCancel;
        if (isPad) {
            self.passcodeView.rightButton = self.cancelButton;
        }
        else {
            [self.view addSubview:self.cancelButton];
        }
    }
    else {
        if (self.rightAccessoryButton) {
            [self.cancelButton removeFromSuperview];
            self.cancelButton = nil;
        }
    }

    [self updateAccessoryButtonFontsForSize:self.view.bounds.size];
}

#pragma mark - View Management -
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.view.layer.allowsGroupOpacity = NO;
    [self setUpBackgroundEffectViewForStyle:self.style];
    [self setUpBackgroundViewForStyle:self.style];
    [self setUpAccessoryButtons];
    [self applyThemeForStyle:self.style];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Automatically trigger biometric validation if available
    if (self.allowBiometricValidation && self.automaticallyPromptForBiometricValidation) {
        [self accessoryButtonTapped:self.biometricButton];
    }
}

- (void)viewDidLayoutSubviews
{
    CGSize bounds = self.view.bounds.size;
    CGSize maxSize = bounds;
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeAreaInsets = self.view.safeAreaInsets;
        if (safeAreaInsets.bottom > 0) {
            maxSize.height -= safeAreaInsets.bottom;
        }
        if (safeAreaInsets.left > 0) {
            maxSize.width -= safeAreaInsets.left;
        }
        if (safeAreaInsets.right > 0) {
            maxSize.width -= safeAreaInsets.right;
        }
    }
    
    // Resize the pin view to scale to the new size
    [self.passcodeView sizeToFitSize:maxSize];
    
    // Re-center the pin view
    CGRect frame = self.passcodeView.frame;
    frame.origin.x = (bounds.width - frame.size.width) * 0.5f;
    frame.origin.y = ((bounds.height - self.keyboardHeight) - frame.size.height) * 0.5f;
    self.passcodeView.frame = CGRectIntegral(frame);

    // --------------------------------------------------

    // Update the accessory button sizes
    [self updateAccessoryButtonFontsForSize:maxSize];

    // Re-layout the accessory buttons
    [self layoutAccessoryButtonsForSize:maxSize];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self setNeedsStatusBarAppearanceUpdate];

    // Force an initial layout if the view hasn't been presented yet
    [UIView performWithoutAnimation:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    }];

    // Show the keyboard if we're entering alphanumeric characters
    if (self.passcodeType == TOPasscodeTypeCustomAlphanumeric) {
        [self.passcodeView.inputField becomeFirstResponder];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    // Dismiss the keyboard if it is visible
    if (self.passcodeView.inputField.isFirstResponder) {
        [self.passcodeView.inputField resignFirstResponder];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return TOPasscodeViewStyleIsDark(self.style) ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

#pragma mark - View Rotations -
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    // We don't need to do anything special on iPad or if we're using character input
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad || self.passcodeType == TOPasscodeTypeCustomAlphanumeric) { return; }

    // Work out if we need to transition to horizontal
    BOOL horizontalLayout = size.height < size.width;

    // Perform layout animation
    [self.passcodeView setHorizontalLayout:horizontalLayout animated:coordinator.animated duration:coordinator.transitionDuration];
}

#pragma mark - View Styling -
- (void)applyThemeForStyle:(TOPasscodeViewStyle)style
{
    BOOL isDark = TOPasscodeViewStyleIsDark(style);

    // Apply the tint color to the accessory buttons
    UIColor *accessoryTintColor = self.accessoryButtonTintColor;
    if (!accessoryTintColor) {
        accessoryTintColor = isDark ? [UIColor whiteColor] : nil;
    }

    self.biometricButton.tintColor = accessoryTintColor;
    self.cancelButton.tintColor = accessoryTintColor;
    self.leftAccessoryButton.tintColor = accessoryTintColor;
    self.rightAccessoryButton.tintColor = accessoryTintColor;

    self.backgroundView.backgroundColor = isDark ? [UIColor colorWithWhite:0.1f alpha:1.0f] : [UIColor whiteColor];
}

- (void)updateAccessoryButtonFontsForSize:(CGSize)size
{
    CGFloat width = size.width;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        width = MIN(size.width, size.height);
    }

    CGFloat pointSize = 17.0f;
    if (width < TOPasscodeViewContentSizeMedium) {
        pointSize = 14.0f;
    }
    else if (width < TOPasscodeViewContentSizeDefault) {
        pointSize = 16.0f;
    }

    UIFont *accessoryFont = [UIFont systemFontOfSize:pointSize];

    self.biometricButton.titleLabel.font = accessoryFont;
    self.cancelButton.titleLabel.font = accessoryFont;
    self.leftAccessoryButton.titleLabel.font = accessoryFont;
    self.rightAccessoryButton.titleLabel.font = accessoryFont;
}

- (void)verticalLayoutAccessoryButtonsForSize:(CGSize)size
{
    CGFloat width = MIN(size.width, size.height);

    CGFloat verticalInset = 44.0f;
    if (width < TOPasscodeViewContentSizeMedium) {
        verticalInset = 20.0f;
    }
    else if (width < TOPasscodeViewContentSizeDefault) {
        verticalInset = 30.0f;
    }
    
    if (self.accessoryButtonsVerticalInset > 0) {
        verticalInset = self.accessoryButtonsVerticalInset;
    }

    CGFloat inset = self.passcodeView.keypadButtonInset;
    CGPoint point = (CGPoint){0.0f, (self.view.bounds.size.height - self.keyboardHeight) - verticalInset};
    if (@available(iOS 11.0, *)) {
        UIEdgeInsets safeAreaInsets = self.view.safeAreaInsets;
        if (safeAreaInsets.bottom > 0) {
            point.y -= safeAreaInsets.bottom;
        }
    }

    if (self.leftButton) {
        [self.leftButton sizeToFit];
        point.x = self.passcodeView.frame.origin.x + inset;
        self.leftButton.center = point;
    }

    if (self.rightButton) {
        [self.rightButton sizeToFit];
        point.x = CGRectGetMaxX(self.passcodeView.frame) - inset;
        self.rightButton.center = point;
    }
}

- (void)horizontalLayoutAccessoryButtonsForSize:(CGSize)size
{
    CGRect passcodeViewFrame = self.passcodeView.frame;
    CGFloat buttonInset = self.passcodeView.keypadButtonInset;
    CGFloat width = MIN(size.width, size.height);
    CGFloat verticalInset = 35.0f;
    if (width < TOPasscodeViewContentSizeMedium) {
        verticalInset = 30.0f;
    }
    else if (width < TOPasscodeViewContentSizeDefault) {
        verticalInset = 35.0f;
    }

    if (self.leftButton) {
        [self.leftButton sizeToFit];
        CGRect frame = self.leftButton.frame;
        frame.origin.y = (self.view.bounds.size.height - verticalInset) - (frame.size.height * 0.5f);
        frame.origin.x = (CGRectGetMaxX(passcodeViewFrame) - buttonInset) - (frame.size.width * 0.5f);
        self.leftButton.frame = CGRectIntegral(frame);
    }

    if (self.rightButton) {
        [self.rightButton sizeToFit];
        CGRect frame = self.rightButton.frame;
        frame.origin.y = verticalInset - (frame.size.height * 0.5f);
        frame.origin.x = (CGRectGetMaxX(passcodeViewFrame) - buttonInset) - (frame.size.width * 0.5f);
        self.rightButton.frame = CGRectIntegral(frame);
    }

    [self.view bringSubviewToFront:self.rightButton];
    [self.view bringSubviewToFront:self.leftButton];
}

- (void)layoutAccessoryButtonsForSize:(CGSize)size
{
    // The buttons are always embedded in the keypad view on iPad
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPhone) { return; }

    if (self.passcodeView.horizontalLayout && self.passcodeType != TOPasscodeTypeCustomAlphanumeric) {
        [self horizontalLayoutAccessoryButtonsForSize:size];
    }
    else {
        [self verticalLayoutAccessoryButtonsForSize:size];
    }
}

#pragma mark - Interactions -
- (void)accessoryButtonTapped:(id)sender
{
    if (sender == self.cancelButton) {
        // When entering keyboard input, just leave the button as 'cancel'
        if (self.handleDeletePress && self.passcodeType != TOPasscodeTypeCustomAlphanumeric && self.passcodeView.passcode.length > 0) {
            [self.passcodeView deleteLastPasscodeCharacterAnimated:YES];
            [self keypadButtonTapped];
            return;
        }

        if ([self.delegate respondsToSelector:@selector(didTapCancelInPasscodeViewController:)]) {
            [self.delegate didTapCancelInPasscodeViewController:self];
        }
    }
    else if (sender == self.biometricButton) {
        if ([self.delegate respondsToSelector:@selector(didPerformBiometricValidationRequestInPasscodeViewController:)]) {
            [self.delegate didPerformBiometricValidationRequestInPasscodeViewController:self];
        }
    }
}

- (void)keypadButtonTapped
{
    NSString *title = nil;
    if (self.passcodeView.passcode.length > 0) {
        title = NSLocalizedString(@"Delete", @"Delete");
    } else if (self.allowCancel) {
        title = NSLocalizedString(@"Cancel", @"Cancel");
    }
    [UIView performWithoutAnimation:^{
        if (title != nil) {
            [self.cancelButton setTitle:title forState:UIControlStateNormal];
            [self.cancelButton layoutIfNeeded];
        }
        self.cancelButton.hidden = (title == nil);
    }];
}

- (void)didCompleteEnteringPasscode:(NSString *)passcode
{
    if (![self.delegate respondsToSelector:@selector(passcodeViewController:isCorrectCode:)]) {
        return;
    }

    // Validate the code
    BOOL isCorrect = [self.delegate passcodeViewController:self isCorrectCode:passcode];
    if (!isCorrect) {
        [self.passcodeView resetPasscodeAnimated:YES playImpact:YES];
        return;
    }

    // Hang onto the fact the passcode was successful to play a nicer dismissal animation
    self.passcodeSuccess = YES;

    // Perform handler if correctly entered
    if ([self.delegate respondsToSelector:@selector(didInputCorrectPasscodeInPasscodeViewController:)]) {
        [self.delegate didInputCorrectPasscodeInPasscodeViewController:self];
    }
    else {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - Keyboard Handling -
- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    // Extract the keyboard information we need from the notification
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat animationDuration = [notification.userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    UIViewAnimationOptions animationCurve = [notification.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];

    // Work out the on-screen height of the keyboard
    self.keyboardHeight = self.view.bounds.size.height - keyboardFrame.origin.y;
    self.keyboardHeight = MAX(self.keyboardHeight, 0.0f);

    // Set that the view needs to be laid out
    [self.view setNeedsLayout];

    if (animationDuration < FLT_EPSILON) {
        return;
    }

    // Animate the content sliding up and down with the keyboard
    [UIView animateWithDuration:animationDuration
                          delay:0.0f
                        options:animationCurve
                     animations:^{ [self.view layoutIfNeeded]; }
                     completion:nil];
}

#pragma mark - Transitioning Delegate -
- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented
                                                                            presentingController:(UIViewController *)presenting
                                                                                sourceController:(UIViewController *)source
{
    return [[TOPasscodeViewControllerAnimatedTransitioning alloc] initWithPasscodeViewController:self dismissing:NO success:NO];
}

- (nullable id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    return [[TOPasscodeViewControllerAnimatedTransitioning alloc] initWithPasscodeViewController:self dismissing:YES success:self.passcodeSuccess];
}

#pragma mark - Convenience Accessors -
- (UIView *)leftButton
{
    return self.leftAccessoryButton ? self.leftAccessoryButton : self.biometricButton;
}

- (UIView *)rightButton
{
    return self.rightAccessoryButton ? self.rightAccessoryButton : self.cancelButton;
}

#pragma mark - Public Accessors -
- (TOPasscodeView *)passcodeView
{
    if (_passcodeView) { return _passcodeView; }

    _passcodeView = [[TOPasscodeView alloc] initWithStyle:self.style passcodeType:self.passcodeType];
    _passcodeView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin |
                                    UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_passcodeView sizeToFit];
    _passcodeView.center = self.view.center;
    [self.view addSubview:_passcodeView];

    __weak typeof(self) weakSelf = self;
    _passcodeView.passcodeCompletedHandler = ^(NSString *passcode) {
        [weakSelf didCompleteEnteringPasscode:passcode];
    };

    _passcodeView.passcodeDigitEnteredHandler = ^{
        [weakSelf keypadButtonTapped];
    };

    // Set initial layout to horizontal if we're rotated on an iPhone
    if (self.passcodeType != TOPasscodeTypeCustomAlphanumeric && UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        CGSize boundsSize = self.view.bounds.size;
        _passcodeView.horizontalLayout = boundsSize.width > boundsSize.height;
    }

    return _passcodeView;
}

- (void)setStyle:(TOPasscodeViewStyle)style
{
    if (style == _style) { return; }
    _style = style;

    self.passcodeView.style = style;
    [self setUpBackgroundEffectViewForStyle:style];
}

- (void)setAllowBiometricValidation:(BOOL)allowBiometricValidation
{
    if (_allowBiometricValidation == allowBiometricValidation) {
        return;
    }

    _allowBiometricValidation = allowBiometricValidation;
    [self setUpAccessoryButtons];
    [self applyThemeForStyle:self.style];
}

- (void)setTitleLabelColor:(UIColor *)titleLabelColor
{
    self.passcodeView.titleLabelColor = titleLabelColor;
}

- (void)setSubtitleLabelColor:(UIColor *)subtitleLabelColor
{
    self.passcodeView.subtitleLabelColor = subtitleLabelColor;
}

- (UIColor *)titleLabelColor { return self.passcodeView.titleLabelColor; }

- (void)setInputProgressViewTintColor:(UIColor *)inputProgressViewTintColor
{
    self.passcodeView.inputProgressViewTintColor = inputProgressViewTintColor;
}

- (UIColor *)inputProgressViewTintColor { return self.passcodeView.inputProgressViewTintColor; }

- (void)setKeypadButtonBackgroundTintColor:(UIColor *)keypadButtonBackgroundTintColor
{
    self.passcodeView.keypadButtonBackgroundColor = keypadButtonBackgroundTintColor;
}

- (void)setKeypadButtonShowLettering:(BOOL)keypadButtonShowLettering
{
    self.passcodeView.keypadView.showLettering = keypadButtonShowLettering;
}

- (UIColor *)keypadButtonBackgroundTintColor { return self.passcodeView.keypadButtonBackgroundColor; }

- (void)setKeypadButtonTextColor:(UIColor *)keypadButtonTextColor
{
    self.passcodeView.keypadButtonTextColor = keypadButtonTextColor;
}

- (UIColor *)keypadButtonTextColor { return self.passcodeView.keypadButtonTextColor; }

- (void)setKeypadButtonHighlightedTextColor:(UIColor *)keypadButtonHighlightedTextColor
{
    self.passcodeView.keypadButtonHighlightedTextColor = keypadButtonHighlightedTextColor;
}

- (UIColor *)keypadButtonHighlightedTextColor { return self.passcodeView.keypadButtonHighlightedTextColor; }

- (void)setAccessoryButtonTintColor:(UIColor *)accessoryButtonTintColor
{
    if (accessoryButtonTintColor == _accessoryButtonTintColor) { return; }
    _accessoryButtonTintColor = accessoryButtonTintColor;
    [self applyThemeForStyle:self.style];
}

- (void)setBiometryType:(TOPasscodeBiometryType)biometryType
{
    if (_biometryType == biometryType) { return; }
    
    _biometryType = biometryType;
    
    if (self.biometricButton) {
        [self.biometricButton setTitle:TOPasscodeBiometryTitleForType(_biometryType) forState:UIControlStateNormal];
    }
}

- (void)setContentHidden:(BOOL)contentHidden
{
    [self setContentHidden:contentHidden animated:NO];
}

- (void)setContentHidden:(BOOL)hidden animated:(BOOL)animated
{
    if (hidden == _contentHidden) { return; }
    _contentHidden = hidden;

    void (^setViewsHiddenBlock)(BOOL) = ^(BOOL hidden) {
        self.passcodeView.hidden = hidden;
        self.leftButton.hidden = hidden;
        self.rightButton.hidden = hidden;
    };

    void (^completionBlock)(BOOL) = ^(BOOL complete) {
        setViewsHiddenBlock(hidden);
    };

    if (!animated) {
        completionBlock(YES);
        return;
    }

    // Make sure the views are visible before the animation
    setViewsHiddenBlock(NO);

    void (^animationBlock)(void) = ^{
        CGFloat alpha = hidden ? 0.0f : 1.0f;
        self.passcodeView.contentAlpha = alpha;
        self.leftButton.alpha = alpha;
        self.rightButton.alpha = alpha;
    };

    // Animate
    [UIView animateWithDuration:0.4f animations:animationBlock completion:completionBlock];
}

@end

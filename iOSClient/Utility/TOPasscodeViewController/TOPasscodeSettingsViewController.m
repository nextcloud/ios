//
//  TOPasscodeSettingsViewController.m
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

#import "TOPasscodeSettingsViewController.h"
#import "TOPasscodeInputField.h"
#import "TOPasscodeSettingsKeypadView.h"
#import "TOPasscodeSettingsWarningLabel.h"

const CGFloat kTOPasscodeSettingsLabelInputSpacing = 15.0f;
const CGFloat kTOPasscodeSettingsOptionsButtonOffset = 15.0f;
const CGFloat kTOPasscodeKeypadMaxSizeRatio = 0.40f;
const CGFloat kTOPasscodeKeypadMinHeight = 185.0f; // was 165
const CGFloat kTOPasscodeKeypadMaxHeight = 330.0f;

@interface TOPasscodeSettingsViewController ()

@property (nonatomic, copy) NSString *potentialPasscode;

/* Layout Calculations */
@property (nonatomic, assign) CGFloat verticalMidPoint;
@property (nonatomic, assign) CGRect keyboardFrame;
@property (nonatomic, readonly) CGRect contentOverlapFrame; // Either the keypad or the system keyboard

/* Views */
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *optionsButton;
@property (nonatomic, strong) TOPasscodeInputField *inputField;
@property (nonatomic, strong) TOPasscodeSettingsKeypadView *keypadView;
@property (nonatomic, strong) TOPasscodeSettingsWarningLabel *warningLabel;

/* Bar Items */
@property (nonatomic, strong) UIBarButtonItem *nextBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *doneBarButtonItem;

/* Style */
@property (nonatomic, assign) TOPasscodeSettingsViewStyle style;

@end

@implementation TOPasscodeSettingsViewController

#pragma mark - Object Creation -

- (instancetype)init
{
    if (self = [self initWithNibName:nil bundle:nil]) {
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

- (void)setUp
{
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection userInterfaceStyle] == UIUserInterfaceStyleDark) {
            self.style = TOPasscodeSettingsViewStyleDark;
        } else {
            self.style = TOPasscodeSettingsViewStyleLight;
        }
    } else {
        self.style = TOPasscodeSettingsViewStyleLight;
    }
    
    [self applyThemeForStyle:_style];

    _failedPasscodeAttemptCount = 0;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillChangeFrame:) name:UIKeyboardWillChangeFrameNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillChangeFrameNotification object:nil];
}

#pragma mark - View Set-up -

- (void)viewDidLoad {
    [super viewDidLoad];

    __weak typeof(self) weakSelf = self;

    self.title = NSLocalizedString(@"Enter Passcode", @"");

    // Create container view
    self.containerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.containerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin
                                            | UIViewAutoresizingFlexibleBottomMargin;
    [self.view addSubview:self.containerView];

    // Create title label
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.font = [UIFont systemFontOfSize:17.0f];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.textColor = [UIColor blackColor];
    self.titleLabel.text = @"Enter your passcode";
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.titleLabel sizeToFit];
    [self.containerView addSubview:self.titleLabel];

    // Create number view
    self.inputField = [[TOPasscodeInputField alloc] init];
    self.inputField.tintColor = [UIColor blackColor];
    self.inputField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.inputField.passcodeCompletedHandler = ^(NSString *passcode) { [weakSelf inputViewDidCompletePasscode:passcode]; };
    [self.inputField sizeToFit];
    [self.containerView addSubview:self.inputField];

    // Create keypad view
    self.keypadView = [[TOPasscodeSettingsKeypadView alloc] initWithFrame:CGRectZero];
    self.keypadView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    [self.view addSubview:self.keypadView];

    // Create warning label view
    self.warningLabel = [[TOPasscodeSettingsWarningLabel alloc] initWithFrame:CGRectZero];
    self.warningLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    self.warningLabel.hidden = YES;
    [self.warningLabel sizeToFit];
    [self.containerView addSubview:self.warningLabel];

    // Create error label view
    self.errorLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.errorLabel.text = NSLocalizedString(@"Passcodes didn't match. Try again.", @"");
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.font = [UIFont systemFontOfSize:15.0f];
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.hidden = YES;
    [self.errorLabel sizeToFit];
    [self.containerView addSubview:self.errorLabel];

    // Create Options button
    self.optionsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.optionsButton setTitle:NSLocalizedString(@"Passcode Options", @"") forState:UIControlStateNormal];
    self.optionsButton.titleLabel.font = [UIFont systemFontOfSize:15.0f];
    [self.optionsButton sizeToFit];
    self.optionsButton.hidden = _hideOptionsButton;
    [self.optionsButton addTarget:self action:@selector(optionsCodeButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.optionsButton];

    // Add callbacks for the keypad view
    self.keypadView.numberButtonTappedHandler = ^(NSInteger number) {
        NSString *numberString = [NSString stringWithFormat:@"%ld", (long)number];
        [weakSelf.inputField appendPasscodeCharacters:numberString animated:NO];
    };

    self.keypadView.deleteButtonTappedHandler = ^{ [weakSelf.inputField deletePasscodeCharactersOfCount:1 animated:NO]; };

    // Set height of the container view (This will never change)
    CGRect frame = self.containerView.frame;
    frame.size.width = self.view.bounds.size.width;
    frame.size.height = CGRectGetHeight(self.titleLabel.frame) + CGRectGetHeight(self.inputField.frame)
                            + CGRectGetHeight(self.warningLabel.frame) + (kTOPasscodeSettingsLabelInputSpacing * 2.0f);
    self.containerView.frame = CGRectIntegral(frame);

    //Work out the vertical offset of the container view assuming the warning label doesn't count
    self.verticalMidPoint = CGRectGetHeight(self.titleLabel.frame) + CGRectGetHeight(self.inputField.frame)
                            + kTOPasscodeSettingsLabelInputSpacing;
    self.verticalMidPoint *= 0.5f;

    // Bar button items
    self.nextBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Next", @"") style:UIBarButtonItemStylePlain target:self action:@selector(nextButtonTapped:)];
    self.doneBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneButtonTapped:)];

    // Apply light/dark mode
    [self applyThemeForStyle:self.style];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.state = self.requireCurrentPasscode ? TOPasscodeSettingsViewStateEnterCurrentPasscode : TOPasscodeSettingsViewStateEnterNewPasscode;
    [self updateContentForState:self.state type:self.passcodeType animated:NO];
}

#pragma mark - View Update -

- (void)updateContentForState:(TOPasscodeSettingsViewState)state type:(TOPasscodeType)type animated:(BOOL)animated
{
    BOOL variableSizePasscode = (type >= TOPasscodeTypeCustomNumeric);

    // Update the visibility of the options button
    if (_hideOptionsButton) {
        self.optionsButton.hidden = YES;
    } else {
        self.optionsButton.hidden = !(state == TOPasscodeSettingsViewStateEnterNewPasscode);
    }
    
    // Clear the input view
    self.inputField.passcode = nil;

    // Disable the input view
    self.inputField.enabled = NO;

    //Update the warning label
    [self updateWarningLabelForState:state];

    // Change the input view if needed
    if (!variableSizePasscode) {
        self.inputField.style = TOPasscodeInputFieldStyleFixed;
        self.inputField.fixedInputView.length = (self.passcodeType == TOPasscodeTypeSixDigits) ? 6 : 4;
    }
    else {
        self.inputField.style = TOPasscodeInputFieldStyleVariable;
    }

    // Update text depending on state
    switch (state) {
        case TOPasscodeSettingsViewStateEnterCurrentPasscode:
            self.titleLabel.text = NSLocalizedString(@"Enter your passcode", @"");
            self.navigationItem.rightBarButtonItem = variableSizePasscode ? self.nextBarButtonItem : nil;
            if (@available(iOS 9.0, *)) {
                self.inputField.returnKeyType = UIReturnKeyContinue;
            }
            else {
                self.inputField.returnKeyType = UIReturnKeyNext;
            }
            break;
        case TOPasscodeSettingsViewStateEnterNewPasscode:
            self.titleLabel.text = NSLocalizedString(@"Enter a new passcode", @"");
            self.navigationItem.rightBarButtonItem = variableSizePasscode ? self.nextBarButtonItem : nil;
            if (@available(iOS 9.0, *)) {
                self.inputField.returnKeyType = UIReturnKeyContinue;
            }
            else {
                self.inputField.returnKeyType = UIReturnKeyNext;
            }
            break;
        case TOPasscodeSettingsViewStateConfirmNewPasscode:
            self.titleLabel.text = NSLocalizedString(@"Confirm new passcode", @"");
            self.navigationItem.rightBarButtonItem = variableSizePasscode ? self.doneBarButtonItem : nil;
            self.inputField.returnKeyType = UIReturnKeyDone;
            break;
    }

    CGRect frame = CGRectZero;

    // Reload the 'Done' button
    [self.inputField reloadInputViews];

    // Resize text label to fit new text
    [self.titleLabel sizeToFit];
    frame = self.titleLabel.frame;
    frame.origin.x = (CGRectGetWidth(self.containerView.frame) - CGRectGetWidth(frame)) * 0.5f;
    self.titleLabel.frame = CGRectIntegral(frame);

    // Resize passcode view
    [self.inputField sizeToFit];
    frame = self.inputField.frame;
    frame.origin.x = (CGRectGetWidth(self.containerView.frame) - CGRectGetWidth(frame)) * 0.5f;
    self.inputField.frame = CGRectIntegral(frame);

    // If we're the alphanumeric type, present the keyboard
    if (type == TOPasscodeTypeCustomAlphanumeric) {
        self.inputField.enabled = YES;
        [self.inputField becomeFirstResponder];
    }
    else {
        if (self.inputField.isFirstResponder) {
            [self.inputField resignFirstResponder];
        }
    }

    // If not animated, force a blanket re-layout
    if (!animated) {
        [self viewDidLayoutSubviews];
        return;
    }

    // If animated, perform the animation
    [UIView animateWithDuration:0.3f animations:^{
        [self viewDidLayoutSubviews];
    }];
}

- (void)updateWarningLabelForState:(TOPasscodeSettingsViewState)state
{
    BOOL confirmingPasscode = state == TOPasscodeSettingsViewStateEnterCurrentPasscode;

    // Update the warning label
    self.warningLabel.hidden = !(confirmingPasscode && self.failedPasscodeAttemptCount > 0);
    self.warningLabel.numberOfWarnings = self.failedPasscodeAttemptCount;

    CGRect frame = self.warningLabel.frame;
    frame.origin.x = (CGRectGetWidth(self.view.frame) - frame.size.width) * 0.5f;
    self.warningLabel.frame = frame;
}

- (void)transitionToState:(TOPasscodeSettingsViewState)state animated:(BOOL)animated
{
    // Preserve the current view state
    UIView *snapshot = nil;

    BOOL reverseDirection = state < self.state;

    // If animated, take a snapshot of the current container view
    if (animated) {
        snapshot = [self.containerView snapshotViewAfterScreenUpdates:NO];
        snapshot.frame = self.containerView.frame;
        [self.view addSubview:snapshot];
    }

    self.errorLabel.hidden = YES;

    // Update the layout for the new state
    self.state = state;

    // Cancel out now if we're not animating
    if (!animated) {
        return;
    }

    // Place the live container off screen to the right
    CGFloat multiplier = reverseDirection ? -1.0f : 1.0f;
    self.containerView.frame = CGRectOffset(self.containerView.frame, self.view.frame.size.width * multiplier, 0.0f);

    // Update the options button alpha depending on transition state
    self.optionsButton.hidden = _hideOptionsButton;
    self.optionsButton.alpha = (state == TOPasscodeSettingsViewStateEnterNewPasscode) ? 0.0f : 1.0f;

    // Perform an animation where the snapshot slides off, and the new container slides in
    id animationBlock = ^{
        snapshot.frame = CGRectOffset(snapshot.frame, -self.view.frame.size.width * multiplier, 0.0f);
        self.containerView.frame = CGRectOffset(self.containerView.frame, -self.view.frame.size.width * multiplier, 0.0f);
        self.optionsButton.alpha = (state == TOPasscodeSettingsViewStateEnterNewPasscode) ? 1.0f : 0.0f;
    };

    // Clean up by removing the snapshot view
    id completionBlock = ^(BOOL complete) {
        [snapshot removeFromSuperview];
    };

    // Perform the animation
    [UIView animateWithDuration:0.4f
                          delay:0.0f
         usingSpringWithDamping:1.0f
          initialSpringVelocity:0.7f
                        options:0
                     animations:animationBlock
                     completion:completionBlock];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];

    CGSize viewSize = self.view.bounds.size;

    // Layout the keypad view
    CGRect frame = self.keypadView.frame;
    frame.size.height = viewSize.height * kTOPasscodeKeypadMaxSizeRatio;
    frame.size.height = MAX(frame.size.height, kTOPasscodeKeypadMinHeight);
    frame.size.height = MIN(frame.size.height, kTOPasscodeKeypadMaxHeight);
    frame.size.width = viewSize.width;
    frame.origin.y = viewSize.height;
    if (self.passcodeType != TOPasscodeTypeCustomAlphanumeric) {
        frame.origin.y -= frame.size.height;
    }

    self.keypadView.frame = CGRectIntegral(frame);

    BOOL horizontalLayout = frame.size.height < kTOPasscodeKeypadMinHeight + FLT_EPSILON;
    BOOL animated = ([self.view.layer animationForKey:@"bounds.size"] != nil);
    [self.keypadView setButtonLabelHorizontalLayout:horizontalLayout animated:animated];

    CGFloat topContentHeight = self.topLayoutGuide.length;

    // Layout the container view
    frame = self.containerView.frame;
    frame.origin.y = (((viewSize.height - (topContentHeight + self.contentOverlapFrame.size.height))) * 0.5f) - self.verticalMidPoint;
    frame.origin.y += topContentHeight;
    self.containerView.frame = CGRectIntegral(frame);

    // Layout the passcode options button
    frame = self.optionsButton.frame;
    frame.origin.y = CGRectGetMinY(self.contentOverlapFrame) - kTOPasscodeSettingsOptionsButtonOffset - CGRectGetHeight(frame);
    frame.origin.x = (CGRectGetWidth(self.view.frame) - CGRectGetWidth(frame)) * 0.5f;
    self.optionsButton.frame = frame;

    // Set frame of title label
    frame = self.titleLabel.frame;
    frame.origin.x = (CGRectGetWidth(self.view.frame) - CGRectGetWidth(frame)) * 0.5f;
    self.titleLabel.frame = CGRectIntegral(frame);

    // Set frame of number pad
    frame = self.inputField.frame;
    frame.origin.x = (CGRectGetWidth(self.view.frame) - CGRectGetWidth(frame)) * 0.5f;
    frame.origin.y = (CGRectGetHeight(self.titleLabel.frame) + kTOPasscodeSettingsLabelInputSpacing);
    self.inputField.frame = CGRectIntegral(frame);

    // Set the frame for the warning view
    frame = self.warningLabel.frame;
    frame.origin.x = (CGRectGetWidth(self.view.frame) - CGRectGetWidth(frame)) * 0.5f;
    frame.origin.y = CGRectGetMaxY(self.inputField.frame) + kTOPasscodeSettingsLabelInputSpacing;
    self.warningLabel.frame = CGRectIntegral(frame);

    // Set the frame of the error view
    frame = self.errorLabel.frame;
    frame.size = [self.errorLabel sizeThatFits:CGSizeMake(300.0f, CGFLOAT_MAX)];
    frame.origin.y = CGRectGetMaxY(self.inputField.frame) + kTOPasscodeSettingsLabelInputSpacing;
    frame.origin.x = (CGRectGetWidth(self.containerView.frame) - CGRectGetWidth(frame)) * 0.5f;
    self.errorLabel.frame = CGRectIntegral(frame);
}

- (void)applyThemeForStyle:(TOPasscodeSettingsViewStyle)style
{
    BOOL isDark = (style == TOPasscodeSettingsViewStyleDark);

    // Set background color
    UIColor *backgroundColor;
    if (isDark) {
        backgroundColor = [UIColor colorWithWhite:0.15f alpha:1.0f];
    }
    else {
        backgroundColor = [UIColor colorWithRed:235.0f/255.0f green:235.0f/255.0f blue:241.0f/255.0f alpha:1.0f];
    }
    self.view.backgroundColor = backgroundColor;

    // Set the style of the keypad view
    self.keypadView.style = style;

    // Set the color for the input content
    UIColor *inputColor = isDark ? [UIColor whiteColor] : [UIColor blackColor];

    // Set the label style
    self.titleLabel.textColor = inputColor;

    // Set the number input tint
    self.inputField.tintColor = inputColor;

    // Set the tint color of the incorrect warning label
    UIColor *warningColor = nil;
    if (isDark) {
        warningColor = [UIColor colorWithRed:214.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    }
    else {
        warningColor = [UIColor colorWithRed:214.0f/255.0f green:63.0f/255.0f blue:63.0f/255.0f alpha:1.0f];
    }
}

#pragma mark - Data Management -
- (void)inputViewDidCompletePasscode:(NSString *)passcode
{
    switch (self.state) {
        case TOPasscodeSettingsViewStateEnterCurrentPasscode:
            [self validateCurrentPasscodeAttemptWithPasscode:passcode];
            break;
        case TOPasscodeSettingsViewStateEnterNewPasscode:
            [self didReceiveNewPasscode:passcode];
            break;
        case TOPasscodeSettingsViewStateConfirmNewPasscode:
            [self confirmNewPasscode:passcode];
            break;
    }
}

- (void)validateCurrentPasscodeAttemptWithPasscode:(NSString *)passcode
{
    if (![self.delegate respondsToSelector:@selector(passcodeSettingsViewController:didAttemptCurrentPasscode:)]) {
        return;
    }

    BOOL correct = [self.delegate passcodeSettingsViewController:self didAttemptCurrentPasscode:passcode];
    if (!correct) {
        [self.inputField resetPasscodeAnimated:YES playImpact:YES];
        self.failedPasscodeAttemptCount++;
    }
    else {
        [self transitionToState:TOPasscodeSettingsViewStateEnterNewPasscode animated:YES];
    }
}

- (void)didReceiveNewPasscode:(NSString *)passcode
{
    self.potentialPasscode = passcode;
    [self transitionToState:TOPasscodeSettingsViewStateConfirmNewPasscode animated:YES];
}

- (void)confirmNewPasscode:(NSString *)passcode
{
    if (![passcode isEqualToString:self.potentialPasscode]) {
        [self transitionToState:TOPasscodeSettingsViewStateEnterNewPasscode animated:YES];
        self.errorLabel.hidden = NO;
        return;
    }

    if (![self.delegate respondsToSelector:@selector(passcodeSettingsViewController:didChangeToNewPasscode:ofType:)]) {
        return;
    }

    [self.delegate passcodeSettingsViewController:self didChangeToNewPasscode:self.potentialPasscode ofType:self.passcodeType];
}

#pragma mark - System Keyboard Handling -
- (void)keyboardWillChangeFrame:(NSNotification *)notification
{
    self.keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    [self viewDidLayoutSubviews];
}

- (CGRect)contentOverlapFrame
{
    if (self.passcodeType < TOPasscodeTypeCustomAlphanumeric) {
        return self.keypadView.frame;
    }

    // Work out where our view is in relation to the screen
    UIWindow *window = self.view.window;
    CGRect viewFrame = [self.view.superview convertRect:self.view.frame toView:window];

    CGFloat overlap = CGRectGetMaxY(viewFrame) - CGRectGetMinY(self.keyboardFrame);

    CGRect overlapFrame = self.keyboardFrame;
    overlapFrame.origin.y = MIN(viewFrame.size.height - overlap, viewFrame.size.height);
    overlapFrame.size.height = MAX(overlap, 0.0f);
    return overlapFrame;
}

#pragma mark - Button Callbacks -

- (void)optionsCodeButtonTapped:(id)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertActionStyle style = UIAlertActionStyleDefault;

    __weak typeof(self) weakSelf = self;

    NSArray *types = @[@(TOPasscodeTypeFourDigits),
                       @(TOPasscodeTypeSixDigits),
                       @(TOPasscodeTypeCustomNumeric),
                       @(TOPasscodeTypeCustomAlphanumeric)
                      ];


    NSArray *titles = @[NSLocalizedString(@"4-Digit Numeric Code", @""),
                        NSLocalizedString(@"6-Digit Numeric Code", @""),
                        NSLocalizedString(@"Custom Numeric Code", @""),
                        NSLocalizedString(@"Custom Alphanumeric Code", @"")];

    // Add all the buttons
    for (NSInteger i = 0; i < types.count; i++) {
        TOPasscodeType type = [types[i] integerValue];
        if (type == self.passcodeType) { continue; }

        id handler = ^(UIAlertAction *action) {
            [weakSelf setPasscodeType:type];
        };
        [alertController addAction:[UIAlertAction actionWithTitle:titles[i] style:style handler:handler]];
    }

    // Cancel button 
    [alertController addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil]];

    alertController.modalPresentationStyle = UIModalPresentationPopover;
    alertController.popoverPresentationController.sourceView = self.optionsButton;
    alertController.popoverPresentationController.sourceRect = self.optionsButton.bounds;
    alertController.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionDown | UIPopoverArrowDirectionUp;
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)nextButtonTapped:(id)sender
{
    [self inputViewDidCompletePasscode:self.inputField.passcode];
}

- (void)doneButtonTapped:(id)sender
{
    [self inputViewDidCompletePasscode:self.inputField.passcode];
}

#pragma mark - Accessors -
- (void)setPasscodeType:(TOPasscodeType)passcodeType
{
    [self setPasscodeType:passcodeType animated:NO];
}

- (void)setPasscodeType:(TOPasscodeType)passcodeType animated:(BOOL)animated
{
    if (_passcodeType == passcodeType) { return; }
    _passcodeType = passcodeType;

    [self updateContentForState:self.state type:_passcodeType animated:animated];
}

- (void)setState:(TOPasscodeSettingsViewState)state
{
    if (_state == state) { return; }
    _state = state;

    [self updateContentForState:_state type:self.passcodeType animated:NO];
}

- (void)setFailedPasscodeAttemptCount:(NSInteger)failedPasscodeAttemptCount
{
    if (_failedPasscodeAttemptCount == failedPasscodeAttemptCount) { return; }
    _failedPasscodeAttemptCount = failedPasscodeAttemptCount;
    [self updateWarningLabelForState:self.state];
}

@end

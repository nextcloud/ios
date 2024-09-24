//
//  TOPasscodeSettingsKeypadView.m
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

#import "TOPasscodeSettingsKeypadView.h"
#import "TOPasscodeSettingsKeypadButton.h"
#import "TOPasscodeButtonLabel.h"
#import "TOSettingsKeypadImage.h"

const CGFloat kTOPasscodeSettingsKeypadButtonInnerSpacing = 7.0f;
const CGFloat kTOPasscodeSettingsKeypadButtonOuterSpacing = 7.0f;
const CGFloat kTOPasscodeSettingsKeypadCornderRadius = 12.0f;

@interface TOPasscodeSettingsKeypadView ()

@property (nonatomic, strong) UIView *separatorView;
@property (nonatomic, strong) NSArray<TOPasscodeSettingsKeypadButton *> *keypadButtons;
@property (nonatomic, strong) UIButton *deleteButton;

@property (nonatomic, strong) UIImage *buttonBackgroundImage;
@property (nonatomic, strong) UIImage *buttonTappedBackgroundImage;

@end

@implementation TOPasscodeSettingsKeypadView

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setUp];
    }

    return self;
}

- (void)setUp
{
    /* Button label styling */
    _keypadButtonNumberFont = [UIFont systemFontOfSize:32.0f weight:UIFontWeightRegular];
    _keypadButtonLetteringFont = [UIFont systemFontOfSize:11.0f weight:UIFontWeightRegular];
    _keypadButtonVerticalSpacing = 2.0f;
    _keypadButtonHorizontalSpacing = 3.0f;
    _keypadButtonLetteringSpacing = 2.0f;

    CGSize viewSize = self.frame.size;
    CGFloat height = 1.0f / [[UIScreen mainScreen] scale];
    self.separatorView = [[UIView alloc] initWithFrame:(CGRect){CGPointZero,{viewSize.width, height}}];
    self.separatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self addSubview:self.separatorView];

    [self setUpKeypadButtons];
    [self setUpDeleteButton];

    [self setUpDefaultValuesForStye:_style];
    [self applyTheme];
}

- (void)setUpKeypadButtons
{
    NSInteger numberOfButtons = 10;
    NSArray *letteredTitles = @[@"ABC", @"DEF", @"GHI", @"JKL",
                                @"MNO", @"PQRS", @"TUV", @"WXYZ"];

    NSMutableArray *buttons = [NSMutableArray arrayWithCapacity:10];
    for (NSInteger i = 0; i < numberOfButtons; i++) {
        NSInteger number = (i+1) % 10; // Wrap around 0 at the end
        TOPasscodeSettingsKeypadButton *button = [TOPasscodeSettingsKeypadButton button];
        button.buttonLabel.numberString = [NSString stringWithFormat:@"%ld", (long)number];
        button.bottomInset = 2.0f;
        button.tag = number;

        if (i > 0) {
            NSInteger j = i - 1;
            if (j < letteredTitles.count) {
                button.buttonLabel.letteringString = letteredTitles[j];
            }
        }

        [button addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchDown];

        [self addSubview:button];
        [buttons addObject:button];
    }

    self.keypadButtons = [NSArray arrayWithArray:buttons];
}

- (void)setUpDeleteButton
{
    UIImage *deleteIcon = [TOSettingsKeypadImage deleteIcon];
    self.deleteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.deleteButton setImage:deleteIcon forState:UIControlStateNormal];
    self.deleteButton.contentMode = UIViewContentModeCenter;
    self.deleteButton.frame = (CGRect){CGPointZero, deleteIcon.size};
    self.deleteButton.tintColor = [UIColor blackColor];
    [self.deleteButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:self.deleteButton];
}

- (void)setUpDefaultValuesForStye:(TOPasscodeSettingsViewStyle)style
{
    BOOL isDark = style == TOPasscodeSettingsViewStyleDark;

    // Keypad label
    self.keypadButtonLabelTextColor = isDark ? [UIColor whiteColor] : [UIColor blackColor];

    self.keypadButtonForegroundColor = isDark ? [UIColor colorWithWhite:0.35f alpha:1.0f] : [UIColor whiteColor];
    self.keypadButtonTappedForegroundColor = isDark ? [UIColor colorWithWhite:0.45f alpha:1.0f] : [UIColor colorWithWhite:0.85f alpha:1.0f];

    // Button border color
    UIColor *borderColor = nil;
    if (isDark) {
        borderColor = [UIColor colorWithWhite:0.15f alpha:1.0f];
    }
    else {
        borderColor = [UIColor colorWithRed:166.0f/255.0f green:174.0f/255.0f blue:186.0f/255.0f alpha:1.0f];
    }
    self.keypadButtonBorderColor = borderColor;

    // Background Color
    UIColor *backgroundColor = nil;
    if (isDark) {
        backgroundColor = [UIColor colorWithWhite:0.18f alpha:1.0f];
    }
    else {
        backgroundColor = [UIColor colorWithRed:220.0f/255.0f green:225.0f/255.0f blue:232.0f/255.0f alpha:1.0f];
    }
    self.backgroundColor = backgroundColor;

    // Separator lines
    UIColor *separatorColor = nil;
    if (isDark) {
        separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
    }
    else {
        separatorColor = [UIColor colorWithWhite:0.7f alpha:1.0f];
    }
    self.separatorView.backgroundColor = separatorColor;

    self.deleteButton.tintColor = isDark ? [UIColor whiteColor] : [UIColor blackColor];
}

- (void)setUpImagesIfNeeded
{
    if (self.buttonBackgroundImage && self.buttonTappedBackgroundImage) {
        return;
    }

    if (self.buttonBackgroundImage == nil) {
        self.buttonBackgroundImage = [TOSettingsKeypadImage buttonImageWithCornerRadius:kTOPasscodeSettingsKeypadCornderRadius
                                                                              foregroundColor:self.keypadButtonForegroundColor
                                                                                    edgeColor:self.keypadButtonBorderColor
                                                                                edgeThickness:2.0f];
    }

    if (self.buttonTappedBackgroundImage == nil) {
        self.buttonTappedBackgroundImage = [TOSettingsKeypadImage buttonImageWithCornerRadius:kTOPasscodeSettingsKeypadCornderRadius
                                                                              foregroundColor:self.keypadButtonTappedForegroundColor
                                                                                    edgeColor:self.keypadButtonBorderColor
                                                                                edgeThickness:2.0f];
    }

    for (TOPasscodeSettingsKeypadButton *button in self.keypadButtons) {
        button.buttonBackgroundImage = self.buttonBackgroundImage;
        button.buttonTappedBackgroundImage = self.buttonTappedBackgroundImage;
    }
}

- (void)applyTheme
{
    for (TOPasscodeSettingsKeypadButton *button in self.keypadButtons) {
        button.buttonLabel.textColor = self.keypadButtonLabelTextColor;
        button.buttonLabel.letteringCharacterSpacing = self.keypadButtonLetteringSpacing;
        button.buttonLabel.letteringVerticalSpacing = self.keypadButtonVerticalSpacing;
        button.buttonLabel.letteringHorizontalSpacing = self.keypadButtonHorizontalSpacing;
        button.buttonLabel.numberLabelFont = self.keypadButtonNumberFont;
        button.buttonLabel.letteringLabelFont = self.keypadButtonLetteringFont;
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self setUpImagesIfNeeded];

    CGFloat outerSpacing = kTOPasscodeSettingsKeypadButtonOuterSpacing;
    CGFloat innerSpacing = kTOPasscodeSettingsKeypadButtonInnerSpacing;

    CGSize viewSize = self.bounds.size;
    CGSize buttonSize = CGSizeZero;

    viewSize.width -= (outerSpacing * 2.0f);
    viewSize.height -= (outerSpacing * 2.0f);
    
    // Pull the buttons up to avoid overlapping the home indicator on iPhone X
    if (@available(iOS 11.0, *)) {
        viewSize.height -= self.safeAreaInsets.bottom;
    }

    // Four rows of three buttons
    buttonSize.width = floorf((viewSize.width - (innerSpacing * 2.0f)) / 3.0f);
    buttonSize.height = floorf((viewSize.height - (innerSpacing * 3.0f)) / 4.0f);

    CGPoint point = CGPointMake(outerSpacing, outerSpacing);
    CGRect buttonFrame = (CGRect){point, buttonSize};

    NSInteger i = 0;
    for (TOPasscodeSettingsKeypadButton *button in self.keypadButtons) {
        button.frame = buttonFrame;
        buttonFrame.origin.x += buttonFrame.size.width + innerSpacing;

        if (++i % 3 == 0) {
            buttonFrame.origin.x = outerSpacing;
            buttonFrame.origin.y += buttonFrame.size.height + innerSpacing;
        }

        if (button == self.keypadButtons.lastObject) {
            button.frame = buttonFrame;
        }
    }

    //Layout delete button
    CGSize boundsSize = self.bounds.size;
    
    // Adjust for home indicator on iPhone X
    if (@available(iOS 11.0, *)) {
        boundsSize.height -= self.safeAreaInsets.bottom;
    }
    
    CGRect frame = self.deleteButton.frame;
    frame.size = buttonSize;
    frame.origin.x = boundsSize.width - (outerSpacing + buttonSize.width * 0.5f);
    frame.origin.x -= (CGRectGetWidth(frame) * 0.5f);
    frame.origin.y = boundsSize.height - (outerSpacing + buttonSize.height * 0.5f);
    frame.origin.y -= (CGRectGetHeight(frame) * 0.5f);
    self.deleteButton.frame = frame;
}

#pragma mark - Interaction -
- (void)buttonTapped:(id)sender
{
    // Handler for the delete button
    if (sender == self.deleteButton) {
        if (self.deleteButtonTappedHandler) {
            self.deleteButtonTappedHandler();
        }
        return;
    }

    // Handler for the keypad buttons
    UIButton *button = (UIButton *)sender;
    NSInteger number = button.tag;

    [[UIDevice currentDevice] playInputClick];

    if (self.numberButtonTappedHandler) {
        self.numberButtonTappedHandler(number);
    }
}

#pragma mark - Accessors -

- (void)setStyle:(TOPasscodeSettingsViewStyle)style
{
    if (style == _style) {
        return;
    }

    _style = style;
    [self setUpDefaultValuesForStye:_style];
    [self applyTheme];
}

#pragma mark - Label Layout -
- (void)setButtonLabelHorizontalLayout:(BOOL)buttonLabelHorizontalLayout
{
    [self setButtonLabelHorizontalLayout:buttonLabelHorizontalLayout animated:NO];
}

- (void)setButtonLabelHorizontalLayout:(BOOL)horizontal animated:(BOOL)animated
{
    if (horizontal == _buttonLabelHorizontalLayout) { return; }

    _buttonLabelHorizontalLayout = horizontal;

    for (TOPasscodeSettingsKeypadButton *button in self.keypadButtons) {
        if (!animated) {
            button.buttonLabel.horizontalLayout = horizontal;
            continue;
        }

        UIView *snapshotView = [button.buttonLabel snapshotViewAfterScreenUpdates:NO];
        snapshotView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [button addSubview:snapshotView];

        button.buttonLabel.horizontalLayout = horizontal;
        [button.buttonLabel setNeedsLayout];
        [button.buttonLabel layoutIfNeeded];

        [button.buttonLabel.layer removeAllAnimations];
        for (CALayer *sublayer in button.buttonLabel.layer.sublayers) {
            [sublayer removeAllAnimations];
        }

        button.buttonLabel.alpha = 0.0f;
        [UIView animateWithDuration:0.4f animations:^{
            button.buttonLabel.alpha = 1.0f;
            snapshotView.alpha = 0.0f;
            snapshotView.center = button.buttonLabel.center;
        } completion:^(BOOL complete) {
            [snapshotView removeFromSuperview];
        }];
    }
}

#pragma mark - Null Resettable Accessors -
- (void)setKeypadButtonForegroundColor:(nullable UIColor *)keypadButtonForegroundColor
{
    if (keypadButtonForegroundColor == _keypadButtonForegroundColor) { return; }
    _keypadButtonForegroundColor = keypadButtonForegroundColor;

    if (_keypadButtonForegroundColor == nil) {
        BOOL isDark = self.style == TOPasscodeSettingsViewStyleDark;
        _keypadButtonForegroundColor = isDark ? [UIColor colorWithWhite:0.3f alpha:1.0f] : [UIColor whiteColor];
    }

    self.buttonBackgroundImage = nil;
    [self setNeedsLayout];
}

- (void)setKeypadButtonBorderColor:(nullable UIColor *)keypadButtonBorderColor
{
    if (keypadButtonBorderColor == _keypadButtonBorderColor) { return; }
    _keypadButtonBorderColor = keypadButtonBorderColor;

    if (_keypadButtonBorderColor == nil) {
        BOOL isDark = self.style == TOPasscodeSettingsViewStyleDark;
        UIColor *borderColor = nil;
        if (isDark) {
            borderColor = [UIColor colorWithWhite:0.2 alpha:1.0f];
        }
        else {
            borderColor = [UIColor colorWithRed:166.0f/255.0f green:174.0f/255.0f blue:186.0f/255.0f alpha:1.0f];
        }
        _keypadButtonBorderColor = borderColor;
    }

    self.buttonBackgroundImage = nil;
    [self setNeedsLayout];
}

- (void)setKeypadButtonTappedForegroundColor:(nullable UIColor *)keypadButtonTappedForegroundColor
{
    if (keypadButtonTappedForegroundColor == _keypadButtonTappedForegroundColor) { return; }
    _keypadButtonTappedForegroundColor = keypadButtonTappedForegroundColor;

    if (_keypadButtonTappedForegroundColor == nil) {
        BOOL isDark = self.style == TOPasscodeSettingsViewStyleDark;
        _keypadButtonTappedForegroundColor = isDark ? [UIColor colorWithWhite:0.4f alpha:1.0f] : [UIColor colorWithWhite:0.85f alpha:1.0f];
    }

    self.buttonTappedBackgroundImage = nil;
    [self setNeedsLayout];
}

- (void)setEnabled:(BOOL)enabled
{
    _enabled = enabled;

    for (TOPasscodeSettingsKeypadButton *button in self.keypadButtons) {
        button.enabled = enabled;
    }

    self.deleteButton.enabled = enabled;
}

@end

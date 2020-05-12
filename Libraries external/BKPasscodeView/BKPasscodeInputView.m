//
//  BKPasscodeInputView.m
//  BKPasscodeViewDemo
//
//  Created by Byungkook Jang on 2014. 4. 20..
//  Copyright (c) 2014년 Byungkook Jang. All rights reserved.
//

#import "BKPasscodeInputView.h"

#define kLabelPasscodeSpacePortrait         (30.0f)
#define kLabelPasscodeSpaceLandscape        (10.0f)

#define kTextLeftRightSpace                 (20.0f)

#define kErrorMessageLeftRightPadding       (10.0f)
#define kErrorMessageTopBottomPadding       (5.0f)

#define kDefaultNumericPasscodeMaximumLength        (4)
#define kDefaultNormalPasscodeMaximumLength         (20)

@interface BKPasscodeInputView () {
    BOOL _isKeyboardTypeSet;
}

@property (nonatomic, strong) UILabel           *titleLabel;
@property (nonatomic, strong) UILabel           *messageLabel;
@property (nonatomic, strong) UILabel           *errorMessageLabel;
@property (nonatomic, strong) UIControl         *passcodeField;

@end

@implementation BKPasscodeInputView

@synthesize maximumLength = _maximumLength;
@synthesize keyboardType = _keyboardType;
@synthesize passcodeField = _passcodeField;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self _initialize];
    }
    return self;
}

- (void)_initialize
{
    self.backgroundColor = [UIColor clearColor];
    
    _enabled = YES;
    _passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
    _keyboardType = UIKeyboardTypeNumberPad;
    _maximumLength = 0;
    
    _titleLabel = [[UILabel alloc] init];
    [[self class] configureTitleLabel:_titleLabel];
    [self addSubview:_titleLabel];
    
    _messageLabel = [[UILabel alloc] init];
    [[self class] configureMessageLabel:_messageLabel];
    [self addSubview:_messageLabel];
    
    _errorMessageLabel = [[UILabel alloc] init];
    [[self class] configureErrorMessageLabel:_errorMessageLabel];
    _errorMessageLabel.hidden = YES;
    [self addSubview:_errorMessageLabel];
}

+ (void)configureTitleLabel:(UILabel *)aLabel
{
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.numberOfLines = 1;
    aLabel.textAlignment = NSTextAlignmentCenter;
    aLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    aLabel.font = [UIFont boldSystemFontOfSize:15.0f];
}

+ (void)configureMessageLabel:(UILabel *)aLabel
{
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.numberOfLines = 0;
    aLabel.textAlignment = NSTextAlignmentCenter;
    aLabel.lineBreakMode = NSLineBreakByWordWrapping;
    aLabel.font = [UIFont systemFontOfSize:15.0f];
}

+ (void)configureErrorMessageLabel:(UILabel *)aLabel
{
    aLabel.backgroundColor = [UIColor clearColor];
    aLabel.numberOfLines = 0;
    aLabel.textAlignment = NSTextAlignmentCenter;
    aLabel.lineBreakMode = NSLineBreakByWordWrapping;
    aLabel.backgroundColor = [UIColor colorWithRed:0.63 green:0.2 blue:0.13 alpha:1];
    aLabel.textColor = [UIColor whiteColor];
    aLabel.font = [UIFont systemFontOfSize:15.0f];
    
    aLabel.layer.cornerRadius = 10.0f;
    aLabel.layer.masksToBounds = YES;
}

- (void)setPasscodeStyle:(BKPasscodeInputViewPasscodeStyle)passcodeStyle
{
    if (_passcodeStyle != passcodeStyle) {
        _passcodeStyle = passcodeStyle;

        if (_passcodeField) {
            _passcodeField = nil;
            [self passcodeField];       // load passcode field immediately if already exists before.
        }
    }
}

- (UIControl *)passcodeField
{
    if (nil == _passcodeField) {
        
        switch (_passcodeStyle) {
            case BKPasscodeInputViewNumericPasscodeStyle:
            {
                if (_maximumLength == 0) {
                    _maximumLength = kDefaultNumericPasscodeMaximumLength;
                }
                
                if (NO == _isKeyboardTypeSet) {
                    _keyboardType = UIKeyboardTypeNumberPad;
                }
                
                BKPasscodeField *passcodeField = [[BKPasscodeField alloc] init];
                passcodeField.delegate = self;
                passcodeField.keyboardType = _keyboardType;
                passcodeField.maximumLength = _maximumLength;
                [passcodeField addTarget:self action:@selector(passcodeControlEditingChanged:) forControlEvents:UIControlEventEditingChanged];
                
                [self setPasscodeField:passcodeField];
                break;
            }
                
            case BKPasscodeInputViewNormalPasscodeStyle:
            {
                if (_maximumLength == 0) {
                    _maximumLength = kDefaultNormalPasscodeMaximumLength;
                }
                
                if (NO == _isKeyboardTypeSet) {
                    _keyboardType = UIKeyboardTypeASCIICapable;
                }
                
                UITextField *textField = [[UITextField alloc] init];
                textField.delegate = self;
                textField.borderStyle = UITextBorderStyleRoundedRect;
                textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
                textField.autocorrectionType = UITextAutocorrectionTypeNo;
                textField.spellCheckingType = UITextSpellCheckingTypeNo;
                textField.enablesReturnKeyAutomatically = YES;
                textField.keyboardType = _keyboardType;
                textField.secureTextEntry = YES;
                textField.font = [UIFont systemFontOfSize:25.0f];
                textField.clearButtonMode = UITextFieldViewModeWhileEditing;
                textField.returnKeyType = UIReturnKeyDone;
                
                [self setPasscodeField:textField];
                break;
            }
        }
    }
    
    return _passcodeField;
}

- (void)setPasscodeField:(UIControl *)passcodeField
{
    if (_passcodeField != passcodeField) {
        
        [_passcodeField removeFromSuperview];
        _passcodeField = passcodeField;
        if (_passcodeField) {
            [self addSubview:_passcodeField];
        }
        [self setNeedsLayout];
    }
}

- (void)setMaximumLength:(NSUInteger)maximumLength
{
    _maximumLength = maximumLength;
    
    if ([_passcodeField isKindOfClass:[BKPasscodeField class]]) {
        [(BKPasscodeField *)_passcodeField setMaximumLength:maximumLength];
    }
}

- (void)setKeyboardType:(UIKeyboardType)keyboardType
{
    _isKeyboardTypeSet = YES;
    _keyboardType = keyboardType;
    [(id<UITextInputTraits>)_passcodeField setKeyboardType:keyboardType];
}

- (void)setTitle:(NSString *)title
{
    self.titleLabel.text = title;
    [self setNeedsLayout];
}

- (NSString *)title
{
    return self.titleLabel.text;
}

- (void)setMessage:(NSString *)message
{
    self.messageLabel.text = message;
    self.messageLabel.hidden = NO;
    
    self.errorMessageLabel.text = nil;
    self.errorMessageLabel.hidden = YES;
    
    [self setNeedsLayout];
}

- (NSString *)message
{
    return self.messageLabel.text;
}

- (void)setErrorMessage:(NSString *)errorMessage
{
    self.errorMessageLabel.text = errorMessage;
    self.errorMessageLabel.hidden = NO;
    
    self.messageLabel.text = nil;
    self.messageLabel.hidden = YES;
    
    [self setNeedsLayout];
}

- (NSString *)errorMessage
{
    return self.errorMessageLabel.text;
}

- (NSString *)passcode
{
    switch (self.passcodeStyle) {
        case BKPasscodeInputViewNumericPasscodeStyle:
            return [(BKPasscodeField *)self.passcodeField passcode];
        case BKPasscodeInputViewNormalPasscodeStyle:
            return [(UITextField *)self.passcodeField text];
    }
}

- (void)setPasscode:(NSString *)passcode
{
    switch (self.passcodeStyle) {
        case BKPasscodeInputViewNumericPasscodeStyle:
            [(BKPasscodeField *)self.passcodeField setPasscode:passcode];
            break;
        case BKPasscodeInputViewNormalPasscodeStyle:
             [(UITextField *)self.passcodeField setText:passcode];
             break;
    }
}

#pragma mark - UIView

- (CGFloat)labelPasscodeSpace
{
#ifdef EXTENSION
    return (self.frame.size.width < self.frame.size.height) ? kLabelPasscodeSpacePortrait : kLabelPasscodeSpaceLandscape;
#else
    return UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? kLabelPasscodeSpacePortrait : kLabelPasscodeSpaceLandscape;
#endif
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // layout passcode control to center
    [self.passcodeField sizeToFit];
    
    if ([self.passcodeField isKindOfClass:[UITextField class]]) {
        self.passcodeField.frame = CGRectMake(0, 0, self.frame.size.width - kTextLeftRightSpace * 2.0f, CGRectGetHeight(self.passcodeField.frame) + 10.0f);
    }

    self.passcodeField.center = CGPointMake(CGRectGetWidth(self.frame) * 0.5f, CGRectGetHeight(self.frame) * 0.5f);
    
    CGFloat maxTextWidth = self.frame.size.width - (kTextLeftRightSpace * 2.0f);
    CGFloat labelPasscodeSpace = [self labelPasscodeSpace];
    
    // layout title label
    _titleLabel.frame = CGRectMake(kTextLeftRightSpace, 0, maxTextWidth, self.frame.size.height);
    [_titleLabel sizeToFit];
    
    CGRect rect = _titleLabel.frame;
    rect.origin.x = floorf((self.frame.size.width - CGRectGetWidth(rect)) * 0.5f);
    rect.origin.y = CGRectGetMinY(self.passcodeField.frame) - labelPasscodeSpace - CGRectGetHeight(_titleLabel.frame);

    _titleLabel.frame = rect;
    
    // layout message label
    if (!_messageLabel.hidden) {
        _messageLabel.frame = CGRectMake(kTextLeftRightSpace, CGRectGetMaxY(self.passcodeField.frame) + labelPasscodeSpace, maxTextWidth, self.frame.size.height);
        [_messageLabel sizeToFit];
        
        rect = _messageLabel.frame;
        rect.origin.x = floorf((self.frame.size.width - CGRectGetWidth(rect)) * 0.5f);
        _messageLabel.frame = rect;
    }
    
    // layout error message label
    if (!_errorMessageLabel.hidden) {
        _errorMessageLabel.frame = CGRectMake(0, CGRectGetMaxY(self.passcodeField.frame) + labelPasscodeSpace,
                                              maxTextWidth - kErrorMessageLeftRightPadding * 2.0f,
                                              self.frame.size.height);
        [_errorMessageLabel sizeToFit];
        
        rect = _errorMessageLabel.frame;
        rect.size.width += (kErrorMessageLeftRightPadding * 2.0f);
        rect.size.height += (kErrorMessageTopBottomPadding * 2.0f);
        rect.origin.x = floorf((self.frame.size.width - rect.size.width) * 0.5f);
        
        _errorMessageLabel.frame = rect;
    }
}

#pragma mark - UIResponder

- (BOOL)canBecomeFirstResponder
{
    return [self.passcodeField canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder
{
    return [self.passcodeField becomeFirstResponder];
}

- (BOOL)canResignFirstResponder
{
    return [self.passcodeField canResignFirstResponder];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self.passcodeField becomeFirstResponder];
}

#pragma mark - Actions

- (void)passcodeControlEditingChanged:(id)sender
{
    if (![self.passcodeField isKindOfClass:[BKPasscodeField class]]) {
        return;
    }
    
    BKPasscodeField *passcodeField = (BKPasscodeField *)self.passcodeField;
    
    if (passcodeField.passcode.length == passcodeField.maximumLength) {
        if ([self.delegate respondsToSelector:@selector(passcodeInputViewDidFinish:)]) {
            [self.delegate passcodeInputViewDidFinish:self];
        }
    }
}

#pragma mark - BKPasscodeFieldDelegate

- (BOOL)passcodeField:(BKPasscodeField *)aPasscodeField shouldInsertText:(NSString *)aText
{
    return self.isEnabled;
}

- (BOOL)passcodeFieldShouldDeleteBackward:(BKPasscodeField *)aPasscodeField
{
    return self.isEnabled;
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    if (self.isEnabled == NO) {
        return NO;
    }
    
    NSUInteger length = textField.text.length - range.length + string.length;
    if (length > self.maximumLength) {
        return NO;
    }
    
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (self.isEnabled == NO) {
        return NO;
    }
    
    if ([self.delegate respondsToSelector:@selector(passcodeInputViewDidFinish:)]) {
        [self.delegate passcodeInputViewDidFinish:self];
        return NO;
    } else {
        return YES; // default behavior
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    BKPasscodeInputView *view = [[[self class] alloc] initWithFrame:self.bounds];
    view.delegate = self.delegate;
    view.autoresizingMask = self.autoresizingMask;
    view.passcodeStyle = self.passcodeStyle;
    view.keyboardType = self.keyboardType;
    view.maximumLength = self.maximumLength;
    
    return view;
}

@end

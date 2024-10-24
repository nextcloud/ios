//
//  TOPasscodeViewControllerConstants.h
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

/* The visual style of the asscode view controller */
typedef NS_ENUM(NSInteger, TOPasscodeViewStyle) {
    TOPasscodeViewStyleTranslucentDark,
    TOPasscodeViewStyleTranslucentLight,
    TOPasscodeViewStyleOpaqueDark,
    TOPasscodeViewStyleOpaqueLight
};

/* The visual style of the passcode settings view controller. */
typedef NS_ENUM(NSInteger, TOPasscodeSettingsViewStyle) {
    TOPasscodeSettingsViewStyleLight,
    TOPasscodeSettingsViewStyleDark
};

/* Depending on the amount of horizontal space, the sizing of the elements */
typedef NS_ENUM(NSInteger, TOPasscodeViewContentSize) {
    TOPasscodeViewContentSizeDefault = 414, // Default, 414 points and above (6 Plus, all remaining iPad sizes)
    TOPasscodeViewContentSizeMedium = 375, // Greater or equal to 375 points: iPhone 6 / iPad Pro 1/4 split mode
    TOPasscodeViewContentSizeSmall  = 320  // Greater or equal to 320 points: iPhone SE / iPad 1/4 split mode
};

/* The types of passcodes that may be used. */
typedef NS_ENUM(NSInteger, TOPasscodeType) {
    TOPasscodeTypeFourDigits,           // 4 Numbers
    TOPasscodeTypeSixDigits,            // 6 Numbers
    TOPasscodeTypeCustomNumeric,        // Any length of numbers
    TOPasscodeTypeCustomAlphanumeric    // Any length of characters
};

/* The type of biometrics this controller can handle */
typedef NS_ENUM(NSInteger, TOPasscodeBiometryType) {
    TOPasscodeBiometryTypeTouchID,
    TOPasscodeBiometryTypeFaceID
};

static inline BOOL TOPasscodeViewStyleIsTranslucent(TOPasscodeViewStyle style) {
    return style <= TOPasscodeViewStyleTranslucentLight;
}

static inline BOOL TOPasscodeViewStyleIsDark(TOPasscodeViewStyle style) {
    return style < TOPasscodeViewStyleTranslucentLight || style == TOPasscodeViewStyleOpaqueDark;
}

static inline NSString *TOPasscodeBiometryTitleForType(TOPasscodeBiometryType type) {
    switch (type) {
        case TOPasscodeBiometryTypeFaceID: return NSLocalizedString(@"Face ID", @"");
        default: return NSLocalizedString(@"Touch ID", @"");
    }
}

//
//  CCBKPasscode.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 07/11/14.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCBKPasscode.h"

@implementation CCBKPasscode

- (id)init
{
    self =[super init];
    if (self) {
        self.numberInstance = 0;
    }
    return self;
}

+(id)sharedInstance
{
    static dispatch_once_t onceToken = 0;
    
    __strong static id _sharedManager = nil;
    
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    
    ((CCBKPasscode*)_sharedManager).numberInstance++;
    
    return _sharedManager;
}

- (void) viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    [super viewWillAppear:animated];
}

- (void)customizePasscodeInputView:(BKPasscodeInputView *)aPasscodeInputView
{
    [super customizePasscodeInputView:aPasscodeInputView];
    
    if ([aPasscodeInputView.passcodeField isKindOfClass:[BKPasscodeField class]]) {
        BKPasscodeField *passcodeField = (BKPasscodeField *)aPasscodeInputView.passcodeField;
        passcodeField.imageSource = self;
        passcodeField.dotSize = CGSizeMake(32, 32);
    }
}

- (UIImage *)passcodeField:(BKPasscodeField *)aPasscodeField dotImageAtIndex:(NSInteger)aIndex filled:(BOOL)aFilled
{
    if (aFilled) {
        return [UIImage imageNamed:@"bkfull"];
    } else {
        return [UIImage imageNamed:@"bkempty"];
    }
}

@end

//
//  CCLogin.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 11/09/14.
//  Copyright (c) 2014 TWS. All rights reserved.
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#import "CCIntro.h"
#import "CCUtility.h"
#import "CCLoginNCOC.h"
#import "CCBKPasscode.h"
#import "CCSecurityOptions.h"

@interface CCLogin : UIViewController <BKPasscodeViewControllerDelegate, CCIntroDelegate, CCSecurityOptionsDelegate>

@property NSUInteger failedAttempts;
@property (nonatomic, strong) NSDate *lockUntilDate;

@property (nonatomic, weak) IBOutlet UIImageView *brand;
@property (nonatomic, weak) IBOutlet UIButton *nextcloud;

@property (nonatomic, strong) CCIntro *intro;

@end

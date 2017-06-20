//
//  CCIntro.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 05/11/15.
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

#import <UIKit/UIKit.h>

#import "EAIntroView.h"
#import "CCUtility.h"

@protocol CCIntroDelegate;

@interface CCIntro : NSObject <EAIntroDelegate>

- (id)initWithDelegate:(id <CCIntroDelegate>)delegate delegateView:(UIView *)delegateView;

@property (nonatomic, weak) id <CCIntroDelegate> delegate;
@property (nonatomic, strong) UIView *rootView;

- (void)showIntroCryptoCloud:(CGFloat)duration;

@end

@protocol CCIntroDelegate <NSObject>

@optional - (void)introWillFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped;
@optional - (void)introDidFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped;

@end

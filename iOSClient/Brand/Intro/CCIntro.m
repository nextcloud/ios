//
//  CCIntro.m
//  Nextcloud iOS
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

#import "CCIntro.h"

#import "NCBridgeSwift.h"

@interface CCIntro ()
{
    int titlePositionY;
    int descPositionY;
    int titleIconPositionY;
    int buttonPosition;
    
    int selector;
}
@end

@implementation CCIntro

- (id)initWithDelegate:(id <CCIntroDelegate>)delegate delegateView:(UIView *)delegateView
{
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        self.rootView = delegateView;
    }

    return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (void)introWillFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped
{
    [self.delegate introFinishSelector:selector];
}

- (void)introDidFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped
{
}

- (void)login:(id)sender
{
    selector = k_intro_login;
    [self.intro hideWithFadeOutDuration:0.7];
}

- (void)signUp:(id)sender
{
    selector = k_intro_signup;
    [self.intro hideWithFadeOutDuration:0.7];
}

- (void)show
{
    [self showIntro];
}

- (void)showIntro
{
    //NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    CGFloat height = self.rootView.bounds.size.height;
    CGFloat width = self.rootView.bounds.size.width;
    
    if (height <= 568) {
        titleIconPositionY = 20;
    } else {
        titleIconPositionY = 100;
    }
    
    titlePositionY = height / 2 + 40.0;
    descPositionY  = height / 2;
    buttonPosition = height / 2 + 120.0;
    
    // Button
    
    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0,0, self.rootView.bounds.size.width, 100.0)];
    buttonView.userInteractionEnabled = YES ;
    
    UIButton *buttonLogin = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    buttonLogin.frame = CGRectMake(50.0, 0.0, width - 100.0, 40.0);
    buttonLogin.layer.cornerRadius = 3;
    buttonLogin.clipsToBounds = YES;
    [buttonLogin setTitle:[NSLocalizedStringFromTable(@"_log_in_", @"Intro", nil) uppercaseString] forState:UIControlStateNormal];
    buttonLogin.titleLabel.font = [UIFont systemFontOfSize:14];
    [buttonLogin setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    buttonLogin.backgroundColor = [[NCBrandColor sharedInstance] customerText];
    [buttonLogin addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchDown];
    
    UIButton *buttonSignUp = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    buttonSignUp.frame = CGRectMake(50.0, 60.0, width - 100.0, 40.0);
    buttonSignUp.layer.cornerRadius = 3;
    buttonSignUp.clipsToBounds = YES;
    [buttonSignUp setTitle:[NSLocalizedStringFromTable(@"_sign_up_", @"Intro", nil) uppercaseString] forState:UIControlStateNormal];
    buttonSignUp.titleLabel.font = [UIFont systemFontOfSize:14];
    [buttonSignUp setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    buttonSignUp.backgroundColor = [UIColor colorWithRed:25.0/255.0 green:89.0/255.0 blue:141.0/255.0 alpha:1.000];
    [buttonSignUp addTarget:self action:@selector(signUp:) forControlEvents:UIControlEventTouchDown];
    
    [buttonView addSubview:buttonLogin];
    [buttonView addSubview:buttonSignUp];
    
    // Pages
    
    EAIntroPage *page1 = [EAIntroPage page];

    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1"]];
    page1.titleIconPositionY = titleIconPositionY;

    page1.title = NSLocalizedStringFromTable(@"_intro_1_title_", @"Intro", nil);
    page1.titlePositionY = titlePositionY;
    page1.titleColor = [[NCBrandColor sharedInstance] customerText];
    page1.titleFont = [UIFont systemFontOfSize:20];
    
    page1.desc = NSLocalizedStringFromTable(@"_intro_1_text_",  @"Intro", nil);
    page1.descPositionY = descPositionY;
    page1.descColor = [[NCBrandColor sharedInstance] customerText];
    page1.descFont = [UIFont systemFontOfSize:14];
    
    page1.bgColor = [[NCBrandColor sharedInstance] customer];
    page1.showTitleView = YES;

    EAIntroPage *page2 = [EAIntroPage page];

    page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro2"]];
    page2.titleIconPositionY = titleIconPositionY;

    page2.title = NSLocalizedStringFromTable(@"_intro_2_title_",  @"Intro", nil);
    page2.titlePositionY = titlePositionY;
    page2.titleColor = [[NCBrandColor sharedInstance] customerText];
    page2.titleFont = [UIFont systemFontOfSize:20];
    
    page2.desc = NSLocalizedStringFromTable(@"_intro_2_text_",  @"Intro", nil);
    page2.descPositionY = descPositionY;
    page2.descColor = [[NCBrandColor sharedInstance] customerText];
    page2.descFont = [UIFont systemFontOfSize:14];
    
    page2.bgColor = [[NCBrandColor sharedInstance] customer];
    page2.showTitleView = YES;

    EAIntroPage *page3 = [EAIntroPage page];
    
    page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro3"]];
    page3.titleIconPositionY = titleIconPositionY;

    page3.title = NSLocalizedStringFromTable(@"_intro_3_title_",  @"Intro", nil);
    page3.titlePositionY = titlePositionY;
    page3.titleColor = [[NCBrandColor sharedInstance] customerText];
    page3.titleFont = [UIFont systemFontOfSize:20];
    
    page3.desc = NSLocalizedStringFromTable(@"_intro_3_text_",  @"Intro", nil);
    page3.descPositionY = descPositionY;
    page3.descColor = [[NCBrandColor sharedInstance] customerText];
    page3.descFont = [UIFont systemFontOfSize:14];
    
    page3.bgColor = [[NCBrandColor sharedInstance] customer];
    page3.showTitleView = YES;

    // INTRO
    
    self.intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1,page2,page3]];

    self.intro.tapToNext = NO;
    self.intro.pageControl.pageIndicatorTintColor = [UIColor whiteColor];
    self.intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
    self.intro.pageControl.backgroundColor = [[NCBrandColor sharedInstance] customer];
//    [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
//    intro.skipButton.enabled = NO;
    self.intro.swipeToExit = NO ;
    self.intro.skipButton = nil ;
    self.intro.titleView = buttonView;
    self.intro.titleViewY = buttonPosition;
    self.intro.swipeToExit = NO;
    
    /*
    page1.onPageDidAppear = ^{
        intro.skipButton.enabled = YES;
        [UIView animateWithDuration:0.3f animations:^{
            intro.skipButton.alpha = 1.f;
        }];
    };
    page2.onPageDidDisappear = ^{
        intro.skipButton.enabled = NO;
        [UIView animateWithDuration:0.3f animations:^{
            intro.skipButton.alpha = 0.f;
        }];
    };
    */
    
    [self.intro setDelegate:self];
    [self.intro showInView:self.rootView animateDuration:0];
}

@end

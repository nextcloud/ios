//
//  CCIntro.m
//  Nextcloud
//
//  Created by Marino Faggiana on 05/11/15.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@class NCBrowserWeb;

@interface CCIntro ()
{
    int titlePositionY;
    int titleIconPositionY;
    int buttonPosition;
    int safeAreaBottom;
    
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

- (void)show
{
    [self showIntro];
}

- (void)showIntro
{
    //NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];
    CGFloat height = self.rootView.bounds.size.height;
    CGFloat width = self.rootView.bounds.size.width;
    
    if (height <= 568) { // iPhone 5
        titleIconPositionY = 20;
        titlePositionY = height / 2 + 40.0;
        buttonPosition = height / 2 + 70.0;
    } else {
        titleIconPositionY = 40;
        titlePositionY = height / 2 + 40.0;
        buttonPosition = height / 2 + 120.0;
    }
    
    // SafeArea
    if (@available(iOS 11, *)) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
            safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.right;
        } else {
            safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
        }
    }
    
    // Button
    
    UIView *buttonView = [[UIView alloc] initWithFrame:CGRectMake(0,0,self.rootView.bounds.size.width, height - buttonPosition)];
    buttonView.userInteractionEnabled = YES ;
    
    UIButton *buttonLogin = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    buttonLogin.frame = CGRectMake(50.0, 0.0, width - 100.0, 40.0);
    buttonLogin.layer.cornerRadius = 20;
    buttonLogin.clipsToBounds = YES;
    [buttonLogin setTitle:NSLocalizedString(@"_log_in_", nil) forState:UIControlStateNormal];
    buttonLogin.titleLabel.font = [UIFont systemFontOfSize:14];
    [buttonLogin setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    buttonLogin.backgroundColor = [[NCBrandColor sharedInstance] customerText];
    [buttonLogin addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchDown];
    
    [buttonView addSubview:buttonLogin];
    
    UIButton *buttonSignUp = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    buttonSignUp.frame = CGRectMake(50.0, 60.0, width - 100.0, 40.0);
    buttonSignUp.layer.cornerRadius = 20;
    buttonSignUp.clipsToBounds = YES;
    [buttonSignUp setTitle:NSLocalizedString(@"_sign_up_", nil) forState:UIControlStateNormal];
    buttonSignUp.titleLabel.font = [UIFont systemFontOfSize:14];
    [buttonSignUp setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    buttonSignUp.backgroundColor = [UIColor colorWithRed:25.0/255.0 green:89.0/255.0 blue:141.0/255.0 alpha:1.000];
    [buttonSignUp addTarget:self action:@selector(signUp:) forControlEvents:UIControlEventTouchDown];
        
    [buttonView addSubview:buttonSignUp];
    
    UIButton *buttonHost = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    buttonHost.frame = CGRectMake(50.0, height - buttonPosition - 30.0 - safeAreaBottom, width - 100.0, 20.0);
    buttonHost.layer.cornerRadius = 20;
    buttonHost.clipsToBounds = YES;
    [buttonHost setTitle:NSLocalizedString(@"_host_your_own_server", nil) forState:UIControlStateNormal];
    buttonHost.titleLabel.font = [UIFont systemFontOfSize:14];
    [buttonHost setTitleColor:[UIColor colorWithRed:255.0/255.0 green:255.0/255.0 blue:255.0/255.0 alpha:0.7] forState:UIControlStateNormal];
    buttonHost.backgroundColor = [UIColor clearColor];
    [buttonHost addTarget:self action:@selector(host:) forControlEvents:UIControlEventTouchDown];
    
    [buttonView addSubview:buttonHost];
    
    // Pages
    
    /*
    EAIntroPage *page1 = [EAIntroPage pageWithCustomViewFromNibNamed:@"NCIntroPage1"];
    page1.customView.backgroundColor = [[NCBrandColor sharedInstance] customer];
    UILabel *titlePage1 = (UILabel *)[page1.customView viewWithTag:1];
    titlePage1.text = NSLocalizedString(@"_intro_1_title_", nil);
    */
    
    EAIntroPage *page1 = [EAIntroPage page];

    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1"]];
    page1.titleIconPositionY = titleIconPositionY;

    page1.title = NSLocalizedString(@"_intro_1_title_", nil);
    page1.titlePositionY = titlePositionY;
    page1.titleColor = [[NCBrandColor sharedInstance] customerText];
    page1.titleFont = [UIFont systemFontOfSize:23];

    page1.bgColor = [[NCBrandColor sharedInstance] customer];
    page1.showTitleView = YES;

    EAIntroPage *page2 = [EAIntroPage page];

    page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro2"]];
    page2.titleIconPositionY = titleIconPositionY;

    page2.title = NSLocalizedString(@"_intro_2_title_", nil);
    page2.titlePositionY = titlePositionY;
    page2.titleColor = [[NCBrandColor sharedInstance] customerText];
    page2.titleFont = [UIFont systemFontOfSize:23];
    
    page2.bgColor = [[NCBrandColor sharedInstance] customer];
    page2.showTitleView = YES;

    EAIntroPage *page3 = [EAIntroPage page];
    
    page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro3"]];
    page3.titleIconPositionY = titleIconPositionY;

    page3.title = NSLocalizedString(@"_intro_3_title_", nil);
    page3.titlePositionY = titlePositionY;
    page3.titleColor = [[NCBrandColor sharedInstance] customerText];
    page3.titleFont = [UIFont systemFontOfSize:23];
    
    page3.bgColor = [[NCBrandColor sharedInstance] customer];
    page3.showTitleView = YES;

    EAIntroPage *page4 = [EAIntroPage page];
    
    page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro4"]];
    page4.titleIconPositionY = titleIconPositionY;
    
    page4.title = NSLocalizedString(@"_intro_4_title_", nil);
    page4.titlePositionY = titlePositionY;
    page4.titleColor = [[NCBrandColor sharedInstance] customerText];
    page4.titleFont = [UIFont systemFontOfSize:23];
    
    page4.bgColor = [[NCBrandColor sharedInstance] customer];
    page4.showTitleView = YES;
    
    // INTRO
    
    self.intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1,page2,page3,page4]];

    self.intro.tapToNext = NO;
    self.intro.pageControlY = height - buttonPosition + 50;
    self.intro.pageControl.pageIndicatorTintColor = [[NCBrandColor sharedInstance] nextcloudSoft];
    self.intro.pageControl.currentPageIndicatorTintColor = [UIColor whiteColor];
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Action =====
#pragma --------------------------------------------------------------------------------------------

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

- (void)host:(id)sender
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    NCBrowserWeb *browserWebVC = [[UIStoryboard storyboardWithName:@"NCBrowserWeb" bundle:nil] instantiateInitialViewController];
    
    browserWebVC.urlBase = [NCBrandOptions sharedInstance].linkLoginHost;
    
    [appDelegate.window.rootViewController presentViewController:browserWebVC animated:YES completion:nil];
}

@end

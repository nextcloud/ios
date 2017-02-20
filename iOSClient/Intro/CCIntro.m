//
//  CCIntro.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 05/11/15.
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

#import "CCIntro.h"

@interface CCIntro ()
{
    int titlePositionY;
    int descPositionY;
    int titleIconPositionY;
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

- (void)introDidFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(introDidFinish:wasSkipped:)])
        [self.delegate introDidFinish:introView wasSkipped:wasSkipped];
}

- (void)showIntroCryptoCloud:(CGFloat)duration
{
    CGFloat height = self.rootView.bounds.size.height;
    
    if (height <= 480) { titleIconPositionY = 20; titlePositionY = 260; descPositionY = 230; }
    if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
    if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
    
    EAIntroPage *page1 = [EAIntroPage page];
    page1.title = [CCUtility localizableBrand:@"_intro_01_" table:@"Intro"];
    page1.titlePositionY = titlePositionY;
    page1.titleColor = COLOR_TEXT_ANTHRACITE;
    page1.titleFont = [UIFont systemFontOfSize:20];
    page1.desc = [CCUtility localizableBrand:@"_intro_02_" table:@"Intro"];
    page1.descPositionY = descPositionY;
    page1.descColor = COLOR_TEXT_ANTHRACITE;
    page1.descFont = [UIFont systemFontOfSize:14];
    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1Nextcloud"]];
    page1.bgImage = [UIImage imageNamed:@"bgbianco"];
    page1.titleIconPositionY = titleIconPositionY;
    page1.showTitleView = NO;
    
    
    EAIntroView *intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1]];
    //intro.backgroundColor = [UIColor whiteColor];
    intro.tapToNext = YES;
    intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
    intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
    intro.pageControl.backgroundColor = [UIColor clearColor];
    [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    [intro setDelegate:self];
    [intro showInView:self.rootView animateDuration:duration];
}

@end

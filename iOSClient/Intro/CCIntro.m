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
    page1.title = [CCUtility localizableBrand:@"_intro_01_" table:@"Intro"]; // "BENVENUTO"
    page1.titlePositionY = titlePositionY;
    page1.titleColor = COLOR_GRAY;
    page1.titleFont = [UIFont systemFontOfSize:20];
    page1.desc = [CCUtility localizableBrand:@"_intro_02_" table:@"Intro"];
    page1.descPositionY = descPositionY;
    page1.descColor = COLOR_GRAY;
    page1.descFont = [UIFont systemFontOfSize:14];
    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1Nextcloud"]];
    page1.bgImage = [UIImage imageNamed:@"bgbianco"];
    page1.titleIconPositionY = titleIconPositionY;
    page1.showTitleView = NO;
    
    EAIntroPage *page2 = [EAIntroPage page];
    page2.title = [CCUtility localizableBrand:@"_intro_03_" table:@"Intro"]; // "CHIAVE DI CRIPTAZIONE"
    page2.titlePositionY = titlePositionY;
    page2.titleFont = [UIFont systemFontOfSize:20];
    page2.desc = [CCUtility localizableBrand:@"_intro_04_" table:@"Intro"];
    page2.descPositionY = descPositionY;
    page2.descFont = [UIFont systemFontOfSize:14];
    page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro2Nextcloud"]];
    page2.bgImage = [UIImage imageNamed:@"bgbianco"];
    page2.titleColor = COLOR_GRAY;
    page2.descColor = COLOR_GRAY;
    page2.titleIconPositionY = titleIconPositionY;
    page2.showTitleView = NO;
    
    EAIntroPage *page3 = [EAIntroPage page];
    page3.title = [CCUtility localizableBrand:@"_intro_05_" table:@"Intro"]; // ACCEDI
    page3.titlePositionY = titlePositionY;
    page3.titleFont = [UIFont systemFontOfSize:20];
    page3.descPositionY = descPositionY;
    page3.descFont = [UIFont systemFontOfSize:14];
    page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro3Nextcloud"]];
    page3.bgImage = [UIImage imageNamed:@"bgbianco"];
    page3.titleColor = COLOR_GRAY;
    page3.descColor = COLOR_GRAY;
    page3.desc = [CCUtility localizableBrand:@"_intro_06_" table:@"Intro"];
    page3.titleIconPositionY = titleIconPositionY;
    page3.showTitleView = NO;
    
    EAIntroPage *page4 = [EAIntroPage page];
    page4.title = [[CCUtility localizableBrand:@"_intro_07_" table:@"Intro"] uppercaseString]; // "CRYPTO CLOUD" - "NEXTCLOUD"
    page4.titlePositionY = titlePositionY;
    page4.titleColor = COLOR_GRAY;
    page4.titleFont = [UIFont systemFontOfSize:20];
    page4.desc = [CCUtility localizableBrand:@"_intro_08_" table:@"Intro"];
    page4.descPositionY = descPositionY;
    page4.descColor = COLOR_GRAY;
    page4.descFont = [UIFont systemFontOfSize:14];
    page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro4Nextcloud"]];
    page4.bgImage = [UIImage imageNamed:@"bgbianco"];
    page4.titleIconPositionY = titleIconPositionY;
    page4.showTitleView = NO;
    
    EAIntroPage *page5 = [EAIntroPage page];
    page5.title = [CCUtility localizableBrand:@"_intro_09_" table:@"Intro"]; // "OFFLINE & LOCAL"
    page5.titlePositionY = titlePositionY;
    page5.titleFont = [UIFont systemFontOfSize:20];
    page5.desc = [CCUtility localizableBrand:@"_intro_10_" table:@"Intro"];
    page5.descPositionY = descPositionY;
    page5.descFont = [UIFont systemFontOfSize:14];
    page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro5Nextcloud"]];
    page5.bgImage = [UIImage imageNamed:@"bgbianco"];
    page5.titleColor = COLOR_GRAY;
    page5.descColor = COLOR_GRAY;
    page5.titleIconPositionY = titleIconPositionY;
    page5.showTitleView = NO;
    
    EAIntroPage *page6 = [EAIntroPage page];
    page6.title = [CCUtility localizableBrand:@"_intro_11_" table:@"Intro"]; // "CRIPTA / DECRIPTA"
    page6.titlePositionY = titlePositionY;
    page6.titleFont = [UIFont systemFontOfSize:20];
    page6.desc = [CCUtility localizableBrand:@"_intro_12_" table:@"Intro"];
    page6.descPositionY = descPositionY;
    page6.descFont = [UIFont systemFontOfSize:14];
    page6.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro6Nextcloud"]];
    page6.bgImage = [UIImage imageNamed:@"bgbianco"];
    page6.titleColor = COLOR_GRAY;
    page6.descColor = COLOR_GRAY;
    page6.titleIconPositionY = titleIconPositionY;
    page6.showTitleView = NO;
    
    EAIntroPage *page7 = [EAIntroPage page];
    page7.title = [CCUtility localizableBrand:@"_intro_13_" table:@"Intro"]; // "AGGIUNGI"
    page7.titlePositionY = titlePositionY;
    page7.titleColor = COLOR_GRAY;
    page7.titleFont = [UIFont systemFontOfSize:20];
    page7.desc = [CCUtility localizableBrand:@"_intro_14_" table:@"Intro"];
    page7.descPositionY = descPositionY;
    page7.descColor = COLOR_GRAY;
    page7.descFont = [UIFont systemFontOfSize:14];
    page7.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro7Nextcloud"]];
    page7.bgImage = [UIImage imageNamed:@"bgbianco"];
    page7.titleIconPositionY = titleIconPositionY;
    page7.showTitleView = NO;
    
    EAIntroPage *page8 = [EAIntroPage page];
    page8.title = [CCUtility localizableBrand:@"_intro_15_" table:@"Intro"]; // "TEMPLATES"
    page8.titlePositionY = titlePositionY;
    page8.titleFont = [UIFont systemFontOfSize:20];
    page8.desc = [CCUtility localizableBrand:@"_intro_16_" table:@"Intro"];
    page8.descPositionY = descPositionY;
    page8.descFont = [UIFont systemFontOfSize:14];
    page8.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro8Nextcloud"]];
    page8.bgImage = [UIImage imageNamed:@"bgbianco"];
    page8.titleColor = COLOR_GRAY;
    page8.descColor = COLOR_GRAY;
    page8.titleIconPositionY = titleIconPositionY;
    page8.showTitleView = NO;
    
    EAIntroPage *page9 = [EAIntroPage page];
    page9.title = [CCUtility localizableBrand:@"_intro_17_" table:@"Intro"]; // "BLOCCO PASSCODE"
    page9.titlePositionY = titlePositionY;
    page9.titleFont = [UIFont systemFontOfSize:20];
    page9.desc = [CCUtility localizableBrand:@"_intro_18_" table:@"Intro"];
    page9.descPositionY = descPositionY;
    page9.descFont = [UIFont systemFontOfSize:14];
    page9.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro9Nextcloud"]];
    page9.bgImage = [UIImage imageNamed:@"bgbianco"];
    page9.titleColor = COLOR_GRAY;
    page9.descColor = COLOR_GRAY;
    page9.titleIconPositionY = titleIconPositionY;
    page9.showTitleView = NO;
    
    EAIntroPage *page10 = [EAIntroPage page];
    page10.title = [CCUtility localizableBrand:@"_intro_19_" table:@"Intro"]; // "INIZIO"
    page10.titlePositionY = titlePositionY;
    page10.titleColor = COLOR_GRAY;
    page10.titleFont = [UIFont systemFontOfSize:20];
    page10.descPositionY = descPositionY;
    page10.descColor = COLOR_GRAY;
    page10.descFont = [UIFont systemFontOfSize:14];
    page10.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro10Nextcloud"]];
    page10.bgImage = [UIImage imageNamed:@"bgbianco"];
    page10.desc = [CCUtility localizableBrand:@"_intro_20_" table:@"Intro"];
    page10.titleIconPositionY = titleIconPositionY;
    page10.showTitleView = NO;
    
    EAIntroView *intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4, page5, page6, page7, page8, page9, page10]];
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

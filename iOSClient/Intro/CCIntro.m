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
    page1.titleFont = RalewayMedium(20.0f);
    page1.desc = [CCUtility localizableBrand:@"_intro_02_" table:@"Intro"];
    page1.descPositionY = descPositionY;
    page1.descColor = COLOR_GRAY;
    page1.descFont = RalewayLight(14.0f);
#ifdef CC
    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1"]];
    page1.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
#ifdef NC
    page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro1Nextcloud"]];
    page1.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
    page1.titleIconPositionY = titleIconPositionY;
    page1.showTitleView = NO;
    
    EAIntroPage *page2 = [EAIntroPage page];
    page2.title = [CCUtility localizableBrand:@"_intro_03_" table:@"Intro"]; // "CHIAVE DI CRIPTAZIONE"
    page2.titlePositionY = titlePositionY;
    page2.titleFont = RalewayMedium(20.0f);
    page2.desc = [CCUtility localizableBrand:@"_intro_04_" table:@"Intro"];
    page2.descPositionY = descPositionY;
    page2.descFont = RalewayLight(14.0f);
#ifdef CC
    page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro2"]];
    page2.bgImage = [UIImage imageNamed:@"bggrigio"];
    page2.titleColor = [UIColor whiteColor];
    page2.descColor = [UIColor whiteColor];
#endif
#ifdef NC
    page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro2Nextcloud"]];
    page2.bgImage = [UIImage imageNamed:@"bgbianco"];
    page2.titleColor = COLOR_GRAY;
    page2.descColor = COLOR_GRAY;
#endif
    page2.titleIconPositionY = titleIconPositionY;
    page2.showTitleView = NO;
    
    EAIntroPage *page3 = [EAIntroPage page];
    page3.title = [CCUtility localizableBrand:@"_intro_05_" table:@"Intro"]; // ACCEDI
    page3.titlePositionY = titlePositionY;
    page3.titleFont = RalewayMedium(20.0f);
    page3.descPositionY = descPositionY;
    page3.descFont = RalewayLight(14.0f);
#ifdef CC
    page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro3"]];
    page3.bgImage = [UIImage imageNamed:@"bgarancio"];
    page3.titleColor = [UIColor whiteColor];
    page3.descColor = [UIColor whiteColor];
    page3.desc = [CCUtility localizableBrand:@"_intro_06_" table:@"Intro"];
#endif
#ifdef NC
    page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro3Nextcloud"]];
    page3.bgImage = [UIImage imageNamed:@"bgbianco"];
    page3.titleColor = COLOR_GRAY;
    page3.descColor = COLOR_GRAY;
    page3.desc = [CCUtility localizableBrand:@"_intro_06_Nextcloud_" table:@"Intro"];
#endif
    page3.titleIconPositionY = titleIconPositionY;
    page3.showTitleView = NO;
    
    EAIntroPage *page4 = [EAIntroPage page];
    page4.title = [[CCUtility localizableBrand:@"_intro_07_" table:@"Intro"] uppercaseString]; // "CRYPTO CLOUD" - "NEXTCLOUD"
    page4.titlePositionY = titlePositionY;
    page4.titleColor = COLOR_GRAY;
    page4.titleFont = RalewayMedium(20.0f);
    page4.desc = [CCUtility localizableBrand:@"_intro_08_" table:@"Intro"];
    page4.descPositionY = descPositionY;
    page4.descColor = COLOR_GRAY;
    page4.descFont = RalewayLight(14.0f);
#ifdef CC
    page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro4"]];
    page4.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
#ifdef NC
    page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro4Nextcloud"]];
    page4.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
    page4.titleIconPositionY = titleIconPositionY;
    page4.showTitleView = NO;
    
    EAIntroPage *page5 = [EAIntroPage page];
    page5.title = [CCUtility localizableBrand:@"_intro_09_" table:@"Intro"]; // "PREFERITI & ARCHIVIO LOCALE"
    page5.titlePositionY = titlePositionY;
    page5.titleFont = RalewayMedium(20.0f);
    page5.desc = [CCUtility localizableBrand:@"_intro_10_" table:@"Intro"];
    page5.descPositionY = descPositionY;
    page5.descFont = RalewayLight(14.0f);
#ifdef CC
    page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro5"]];
    page5.bgImage = [UIImage imageNamed:@"bgarancio"];
    page5.titleColor = [UIColor whiteColor];
    page5.descColor = [UIColor whiteColor];
#endif
#ifdef NC
    page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro5Nextcloud"]];
    page5.bgImage = [UIImage imageNamed:@"bgbianco"];
    page5.titleColor = COLOR_GRAY;
    page5.descColor = COLOR_GRAY;
#endif
    page5.titleIconPositionY = titleIconPositionY;
    page5.showTitleView = NO;
    
    EAIntroPage *page6 = [EAIntroPage page];
    page6.title = [CCUtility localizableBrand:@"_intro_11_" table:@"Intro"]; // "CRIPTA / DECRIPTA"
    page6.titlePositionY = titlePositionY;
    page6.titleFont = RalewayMedium(20.0f);
    page6.desc = [CCUtility localizableBrand:@"_intro_12_" table:@"Intro"];
    page6.descPositionY = descPositionY;
    page6.descFont = RalewayLight(14.0f);
#ifdef CC
    page6.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro6"]];
    page6.bgImage = [UIImage imageNamed:@"bggrigio"];
    page6.titleColor = [UIColor whiteColor];
    page6.descColor = [UIColor whiteColor];
#endif
#ifdef NC
    page6.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro6Nextcloud"]];
    page6.bgImage = [UIImage imageNamed:@"bgbianco"];
    page6.titleColor = COLOR_GRAY;
    page6.descColor = COLOR_GRAY;
#endif
    page6.titleIconPositionY = titleIconPositionY;
    page6.showTitleView = NO;
    
    EAIntroPage *page7 = [EAIntroPage page];
    page7.title = [CCUtility localizableBrand:@"_intro_13_" table:@"Intro"]; // "AGGIUNGI"
    page7.titlePositionY = titlePositionY;
    page7.titleColor = COLOR_GRAY;
    page7.titleFont = RalewayMedium(20.0f);
    page7.desc = [CCUtility localizableBrand:@"_intro_14_" table:@"Intro"];
    page7.descPositionY = descPositionY;
    page7.descColor = COLOR_GRAY;
    page7.descFont = RalewayLight(14.0f);
#ifdef CC
    page7.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro7"]];
    page7.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
#ifdef NC
    page7.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro7Nextcloud"]];
    page7.bgImage = [UIImage imageNamed:@"bgbianco"];
#endif
    page7.titleIconPositionY = titleIconPositionY;
    page7.showTitleView = NO;
    
    EAIntroPage *page8 = [EAIntroPage page];
    page8.title = [CCUtility localizableBrand:@"_intro_15_" table:@"Intro"]; // "TEMPLATES"
    page8.titlePositionY = titlePositionY;
    page8.titleFont = RalewayMedium(20.0f);
    page8.desc = [CCUtility localizableBrand:@"_intro_16_" table:@"Intro"];
    page8.descPositionY = descPositionY;
    page8.descFont = RalewayLight(14.0f);
#ifdef CC
    page8.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro8"]];
    page8.bgImage = [UIImage imageNamed:@"bgarancio"];
    page8.titleColor = [UIColor whiteColor];
    page8.descColor = [UIColor whiteColor];
#endif
#ifdef NC
    page8.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro8Nextcloud"]];
    page8.bgImage = [UIImage imageNamed:@"bgbianco"];
    page8.titleColor = COLOR_GRAY;
    page8.descColor = COLOR_GRAY;
#endif
    page8.titleIconPositionY = titleIconPositionY;
    page8.showTitleView = NO;
    
    EAIntroPage *page9 = [EAIntroPage page];
    page9.title = [CCUtility localizableBrand:@"_intro_17_" table:@"Intro"]; // "BLOCCO PASSCODE"
    page9.titlePositionY = titlePositionY;
    page9.titleFont = RalewayMedium(20.0f);
    page9.desc = [CCUtility localizableBrand:@"_intro_18_" table:@"Intro"];
    page9.descPositionY = descPositionY;
    page9.descFont = RalewayLight(14.0f);
#ifdef CC
    page9.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro9"]];
    page9.bgImage = [UIImage imageNamed:@"bggrigio"];
    page9.titleColor = [UIColor whiteColor];
    page9.descColor = [UIColor whiteColor];
#endif
#ifdef NC
    page9.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro9Nextcloud"]];
    page9.bgImage = [UIImage imageNamed:@"bgbianco"];
    page9.titleColor = COLOR_GRAY;
    page9.descColor = COLOR_GRAY;
#endif
    page9.titleIconPositionY = titleIconPositionY;
    page9.showTitleView = NO;
    
    EAIntroPage *page10 = [EAIntroPage page];
    page10.title = [CCUtility localizableBrand:@"_intro_19_" table:@"Intro"]; // "INIZIO"
    page10.titlePositionY = titlePositionY;
    page10.titleColor = COLOR_GRAY;
    page10.titleFont = RalewayMedium(20.0f);
    page10.descPositionY = descPositionY;
    page10.descColor = COLOR_GRAY;
    page10.descFont = RalewayLight(14.0f);
#ifdef CC
    page10.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro10"]];
    page10.bgImage = [UIImage imageNamed:@"bgbianco"];
    page10.desc = [CCUtility localizableBrand:@"_intro_20_" table:@"Intro"];
#endif
#ifdef NC
    page10.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro10Nextcloud"]];
    page10.bgImage = [UIImage imageNamed:@"bgbianco"];
    page10.desc = [CCUtility localizableBrand:@"_intro_20_Nextcloud_" table:@"Intro"];
#endif
    page10.titleIconPositionY = titleIconPositionY;
    page10.showTitleView = NO;
    
    EAIntroView *intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4, page5, page6, page7, page8, page9, page10]];
    //intro.backgroundColor = [UIColor whiteColor];
    intro.tapToNext = YES;
    intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
    intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
    [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    [intro setDelegate:self];
    [intro showInView:self.rootView animateDuration:duration];
}

- (void)showIntroVersion:(NSString *)version duration:(CGFloat)duration review:(BOOL)review
{
    CGFloat height = self.rootView.bounds.size.height;
    EAIntroView *intro;
    
    if ([version isEqualToString:@"1.90"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_190_00_" table:@"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_190_01_" table:@"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_190_02_" table:@"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_190_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_190_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;

        EAIntroPage *page3 = [EAIntroPage page];
        page3.title = [CCUtility localizableBrand:@"_intro_190_05_" table: @"Intro"]; //
        page3.titlePositionY = titlePositionY;
        page3.titleColor = COLOR_GRAY;
        page3.titleFont = RalewayMedium(20.0f);
        page3.desc = [CCUtility localizableBrand:@"_intro_190_06_" table: @"Intro"];
        page3.descPositionY = descPositionY;
        page3.descColor = COLOR_GRAY;
        page3.descFont = RalewayLight(14.0f);
        page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-3"]];
        page3.bgImage = [UIImage imageNamed:@"bgbianco"];
        page3.titleIconPositionY = titleIconPositionY;
        page3.showTitleView = NO;

        EAIntroPage *page4 = [EAIntroPage page];
        page4.title = [CCUtility localizableBrand:@"_intro_190_07_" table: @"Intro"]; //
        page4.titlePositionY = titlePositionY;
        page4.titleColor = COLOR_GRAY;
        page4.titleFont = RalewayMedium(20.0f);
        page4.desc = [CCUtility localizableBrand:@"_intro_190_08_" table: @"Intro"];
        page4.descPositionY = descPositionY;
        page4.descColor = COLOR_GRAY;
        page4.descFont = RalewayLight(14.0f);
        page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-4"]];
        page4.bgImage = [UIImage imageNamed:@"bgbianco"];
        page4.titleIconPositionY = titleIconPositionY;
        page4.showTitleView = NO;

        EAIntroPage *page5 = [EAIntroPage page];
        page5.title = [CCUtility localizableBrand:@"_intro_190_09_" table: @"Intro"]; //
        page5.titlePositionY = titlePositionY;
        page5.titleColor = COLOR_GRAY;
        page5.titleFont = RalewayMedium(20.0f);
        page5.desc = [CCUtility localizableBrand:@"_intro_190_10_" table: @"Intro"];
        page5.descPositionY = descPositionY;
        page5.descColor = COLOR_GRAY;
        page5.descFont = RalewayLight(14.0f);
        page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-5"]];
        page5.bgImage = [UIImage imageNamed:@"bgbianco"];
        page5.titleIconPositionY = titleIconPositionY;
        page5.showTitleView = NO;

        EAIntroPage *page6 = [EAIntroPage page];
        page6.title = [CCUtility localizableBrand:@"_intro_190_11_" table: @"Intro"]; //
        page6.titlePositionY = titlePositionY;
        page6.titleColor = COLOR_GRAY;
        page6.titleFont = RalewayMedium(20.0f);
        page6.desc = [CCUtility localizableBrand:@"_intro_190_12_" table: @"Intro"];
        page6.descPositionY = descPositionY;
        page6.descColor = COLOR_GRAY;
        page6.descFont = RalewayLight(14.0f);
        page6.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro190-6"]];
        page6.bgImage = [UIImage imageNamed:@"bgbianco"];
        page6.titleIconPositionY = titleIconPositionY;
        page6.showTitleView = NO;

        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4, page5, page6]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, page3, page4, page5, page6, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }
    
    else if ([version isEqualToString:@"1.91"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_191_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_191_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_191_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro191-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_191_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_191_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro191-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;
        
        EAIntroPage *page3 = [EAIntroPage page];
        page3.title = [CCUtility localizableBrand:@"_intro_191_05_" table: @"Intro"]; //
        page3.titlePositionY = titlePositionY;
        page3.titleColor = COLOR_GRAY;
        page3.titleFont = RalewayMedium(20.0f);
        page3.desc = [CCUtility localizableBrand:@"_intro_191_06_" table: @"Intro"];
        page3.descPositionY = descPositionY;
        page3.descColor = COLOR_GRAY;
        page3.descFont = RalewayLight(14.0f);
        page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro191-3"]];
        page3.bgImage = [UIImage imageNamed:@"bgbianco"];
        page3.titleIconPositionY = titleIconPositionY;
        page3.showTitleView = NO;
        
        EAIntroPage *page4 = [EAIntroPage page];
        page4.title = [CCUtility localizableBrand:@"_intro_191_07_" table:@"Intro"]; //
        page4.titlePositionY = titlePositionY;
        page4.titleColor = COLOR_GRAY;
        page4.titleFont = RalewayMedium(20.0f);
        page4.desc = [CCUtility localizableBrand:@"_intro_191_08_" table: @"Intro"];
        page4.descPositionY = descPositionY;
        page4.descColor = COLOR_GRAY;
        page4.descFont = RalewayLight(14.0f);
        page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro191-4"]];
        page4.bgImage = [UIImage imageNamed:@"bgbianco"];
        page4.titleIconPositionY = titleIconPositionY;
        page4.showTitleView = NO;
        
        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, page3, page4, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }

    else if ([version isEqualToString:@"1.94"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_194_00_"table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_194_01_" table:@"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_194_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro194-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_194_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_194_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro194-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;
        
        EAIntroPage *page3 = [EAIntroPage page];
        page3.title = [CCUtility localizableBrand:@"_intro_194_05_" table: @"Intro"]; //
        page3.titlePositionY = titlePositionY;
        page3.titleColor = COLOR_GRAY;
        page3.titleFont = RalewayMedium(20.0f);
        page3.desc = [CCUtility localizableBrand:@"_intro_194_06_" table: @"Intro"];
        page3.descPositionY = descPositionY;
        page3.descColor = COLOR_GRAY;
        page3.descFont = RalewayLight(14.0f);
        page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro194-3"]];
        page3.bgImage = [UIImage imageNamed:@"bgbianco"];
        page3.titleIconPositionY = titleIconPositionY;
        page3.showTitleView = NO;
        
        EAIntroPage *page4 = [EAIntroPage page];
        page4.title = [CCUtility localizableBrand:@"_intro_194_07_" table: @"Intro"]; //
        page4.titlePositionY = titlePositionY;
        page4.titleColor = COLOR_GRAY;
        page4.titleFont = RalewayMedium(20.0f);
        page4.desc = [CCUtility localizableBrand:@"_intro_194_08_" table: @"Intro"];
        page4.descPositionY = descPositionY;
        page4.descColor = COLOR_GRAY;
        page4.descFont = RalewayLight(14.0f);
        page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro194-4"]];
        page4.bgImage = [UIImage imageNamed:@"bgbianco"];
        page4.titleIconPositionY = titleIconPositionY;
        page4.showTitleView = NO;

        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, page3, page4, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }
    
    else if ([version isEqualToString:@"1.96"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_196_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_196_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_196_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_196_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_196_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;
        
        EAIntroPage *page3 = [EAIntroPage page];
        page3.title = [CCUtility localizableBrand:@"_intro_196_05_" table: @"Intro"]; //
        page3.titlePositionY = titlePositionY;
        page3.titleColor = COLOR_GRAY;
        page3.titleFont = RalewayMedium(20.0f);
        page3.desc = [CCUtility localizableBrand:@"_intro_196_06_" table: @"Intro"];
        page3.descPositionY = descPositionY;
        page3.descColor = COLOR_GRAY;
        page3.descFont = RalewayLight(14.0f);
        page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-3"]];
        page3.bgImage = [UIImage imageNamed:@"bgbianco"];
        page3.titleIconPositionY = titleIconPositionY;
        page3.showTitleView = NO;
        
        EAIntroPage *page4 = [EAIntroPage page];
        page4.title = [CCUtility localizableBrand:@"_intro_196_07_" table: @"Intro"]; //
        page4.titlePositionY = titlePositionY;
        page4.titleColor = COLOR_GRAY;
        page4.titleFont = RalewayMedium(20.0f);
        page4.desc = [CCUtility localizableBrand:@"_intro_196_08_" table: @"Intro"];
        page4.descPositionY = descPositionY;
        page4.descColor = COLOR_GRAY;
        page4.descFont = RalewayLight(14.0f);
        page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-4"]];
        page4.bgImage = [UIImage imageNamed:@"bgbianco"];
        page4.titleIconPositionY = titleIconPositionY;
        page4.showTitleView = NO;
        
        EAIntroPage *page5 = [EAIntroPage page];
        page5.title = [CCUtility localizableBrand:@"_intro_196_09_" table: @"Intro"]; //
        page5.titlePositionY = titlePositionY;
        page5.titleColor = COLOR_GRAY;
        page5.titleFont = RalewayMedium(20.0f);
        page5.desc = [CCUtility localizableBrand:@"_intro_196_10_" table: @"Intro"];
        page5.descPositionY = descPositionY;
        page5.descColor = COLOR_GRAY;
        page5.descFont = RalewayLight(14.0f);
        page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-5"]];
        page5.bgImage = [UIImage imageNamed:@"bgbianco"];
        page5.titleIconPositionY = titleIconPositionY;
        page5.showTitleView = NO;
        
        EAIntroPage *page6 = [EAIntroPage page];
        page6.title = [CCUtility localizableBrand:@"_intro_196_11_" table: @"Intro"]; //
        page6.titlePositionY = titlePositionY;
        page6.titleColor = COLOR_GRAY;
        page6.titleFont = RalewayMedium(20.0f);
        page6.desc = [CCUtility localizableBrand:@"_intro_196_12_" table: @"Intro"];
        page6.descPositionY = descPositionY;
        page6.descColor = COLOR_GRAY;
        page6.descFont = RalewayLight(14.0f);
        page6.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-6"]];
        page6.bgImage = [UIImage imageNamed:@"bgbianco"];
        page6.titleIconPositionY = titleIconPositionY;
        page6.showTitleView = NO;
        
        EAIntroPage *page7 = [EAIntroPage page];
        page7.title = [CCUtility localizableBrand:@"_intro_196_13_" table: @"Intro"]; //
        page7.titlePositionY = titlePositionY;
        page7.titleColor = COLOR_GRAY;
        page7.titleFont = RalewayMedium(20.0f);
        page7.desc = [CCUtility localizableBrand:@"_intro_196_14_" table: @"Intro"];
        page7.descPositionY = descPositionY;
        page7.descColor = COLOR_GRAY;
        page7.descFont = RalewayLight(14.0f);
        page7.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-7"]];
        page7.bgImage = [UIImage imageNamed:@"bgbianco"];
        page7.titleIconPositionY = titleIconPositionY;
        page7.showTitleView = NO;

        EAIntroPage *page8 = [EAIntroPage page];
        page8.title = [CCUtility localizableBrand:@"_intro_196_17_" table: @"Intro"]; //
        page8.titlePositionY = titlePositionY;
        page8.titleColor = COLOR_GRAY;
        page8.titleFont = RalewayMedium(20.0f);
        page8.desc = [CCUtility localizableBrand:@"_intro_196_18_" table: @"Intro"];
        page8.descPositionY = descPositionY;
        page8.descColor = COLOR_GRAY;
        page8.descFont = RalewayLight(14.0f);
        page8.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-9"]];
        page8.bgImage = [UIImage imageNamed:@"bgbianco"];
        page8.titleIconPositionY = titleIconPositionY;
        page8.showTitleView = NO;

        EAIntroPage *page9 = [EAIntroPage page];
        page9.title = [CCUtility localizableBrand:@"_intro_196_19_" table: @"Intro"]; //
        page9.titlePositionY = titlePositionY;
        page9.titleColor = COLOR_GRAY;
        page9.titleFont = RalewayMedium(20.0f);
        page9.desc = [CCUtility localizableBrand:@"_intro_196_20_" table: @"Intro"];
        page9.descPositionY = descPositionY;
        page9.descColor = COLOR_GRAY;
        page9.descFont = RalewayLight(14.0f);
        page9.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-10"]];
        page9.bgImage = [UIImage imageNamed:@"bgbianco"];
        page9.titleIconPositionY = titleIconPositionY;
        page9.showTitleView = NO;

        EAIntroPage *page10 = [EAIntroPage page];
        page10.title = [CCUtility localizableBrand:@"_intro_196_21_" table: @"Intro"]; //
        page10.titlePositionY = titlePositionY;
        page10.titleColor = COLOR_GRAY;
        page10.titleFont = RalewayMedium(20.0f);
        page10.desc = [CCUtility localizableBrand:@"_intro_196_22_" table: @"Intro"];
        page10.descPositionY = descPositionY;
        page10.descColor = COLOR_GRAY;
        page10.descFont = RalewayLight(14.0f);
        page10.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro196-11"]];
        page10.bgImage = [UIImage imageNamed:@"bgbianco"];
        page10.titleIconPositionY = titleIconPositionY;
        page10.showTitleView = NO;

        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4, page5, page6, page7, page8, page9, page10]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, page3, page4, page5, page6, page7, page8, page9, page10, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }

    else if ([version isEqualToString:@"1.97"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_197_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_197_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_197_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro197-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }

    else if ([version isEqualToString:@"1.99"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_199_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_199_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_199_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
#ifdef CC
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro199-1"]];
#endif
#ifdef NC
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro199-1_Nextcloud"]];
#endif
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }

    else if ([version isEqualToString:@"2.0"]) {
        
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
        
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_200_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
        
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_200_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_200_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro200-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_200_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_200_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro200-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;

        EAIntroPage *page3 = [EAIntroPage page];
        page3.title = [CCUtility localizableBrand:@"_intro_200_05_" table: @"Intro"]; //
        page3.titlePositionY = titlePositionY;
        page3.titleColor = COLOR_GRAY;
        page3.titleFont = RalewayMedium(20.0f);
        page3.desc = [CCUtility localizableBrand:@"_intro_200_06_" table: @"Intro"];
        page3.descPositionY = descPositionY;
        page3.descColor = COLOR_GRAY;
        page3.descFont = RalewayLight(14.0f);
        page3.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro200-3"]];
        page3.bgImage = [UIImage imageNamed:@"bgbianco"];
        page3.titleIconPositionY = titleIconPositionY;
        page3.showTitleView = NO;

        EAIntroPage *page4 = [EAIntroPage page];
        page4.title = [CCUtility localizableBrand:@"_intro_200_07_" table: @"Intro"]; //
        page4.titlePositionY = titlePositionY;
        page4.titleColor = COLOR_GRAY;
        page4.titleFont = RalewayMedium(20.0f);
        page4.desc = [CCUtility localizableBrand:@"_intro_200_08_" table: @"Intro"];
        page4.descPositionY = descPositionY;
        page4.descColor = COLOR_GRAY;
        page4.descFont = RalewayLight(14.0f);
        page4.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro200-4"]];
        page4.bgImage = [UIImage imageNamed:@"bgbianco"];
        page4.titleIconPositionY = titleIconPositionY;
        page4.showTitleView = NO;

        EAIntroPage *page5 = [EAIntroPage page];
        page5.title = [CCUtility localizableBrand:@"_intro_200_09_" table: @"Intro"]; //
        page5.titlePositionY = titlePositionY;
        page5.titleColor = COLOR_GRAY;
        page5.titleFont = RalewayMedium(20.0f);
        page5.desc = [CCUtility localizableBrand:@"_intro_200_10_" table: @"Intro"];
        page5.descPositionY = descPositionY;
        page5.descColor = COLOR_GRAY;
        page5.descFont = RalewayLight(14.0f);
        page5.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro200-5"]];
        page5.bgImage = [UIImage imageNamed:@"bgbianco"];
        page5.titleIconPositionY = titleIconPositionY;
        page5.showTitleView = NO;

        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
        
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2, page3, page4, page5]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, page3, page4, page5, pageEnd]];
        
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];
    }
    
    else if ([version isEqualToString:@"2.10"]) {
            
        if (height <= 480) { titleIconPositionY = 20; titlePositionY = 230; descPositionY = 180; }
        if (height >= 500 && height <= 800) { titleIconPositionY = 50; titlePositionY = height / 2; descPositionY = height / 2 - 40 ; }
        if (height >= 1024) { titleIconPositionY = 100; titlePositionY = 290; descPositionY = 250; }
            
        EAIntroPage *page0 = [EAIntroPage page];
        page0.title = [@"Version " stringByAppendingString:version];
        page0.titlePositionY = titlePositionY;
        page0.titleColor = COLOR_GRAY;
        page0.titleFont = RalewayMedium(20.0f);
        page0.desc = [CCUtility localizableBrand:@"_intro_210_00_" table: @"Intro"];
        page0.descPositionY = descPositionY;
        page0.descColor = COLOR_GRAY;
        page0.descFont = RalewayLight(14.0f);
#ifdef CC
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStart"]];
#endif
#ifdef NC
        page0.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introStartNextcloud"]];
#endif
        page0.bgImage = [UIImage imageNamed:@"bgbianco"];
        page0.titleIconPositionY = titleIconPositionY;
        page0.showTitleView = NO;
            
        EAIntroPage *page1 = [EAIntroPage page];
        page1.title = [CCUtility localizableBrand:@"_intro_210_01_" table: @"Intro"]; //
        page1.titlePositionY = titlePositionY;
        page1.titleColor = COLOR_GRAY;
        page1.titleFont = RalewayMedium(20.0f);
        page1.desc = [CCUtility localizableBrand:@"_intro_210_02_" table: @"Intro"];
        page1.descPositionY = descPositionY;
        page1.descColor = COLOR_GRAY;
        page1.descFont = RalewayLight(14.0f);
        page1.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro210-1"]];
        page1.bgImage = [UIImage imageNamed:@"bgbianco"];
        page1.titleIconPositionY = titleIconPositionY;
        page1.showTitleView = NO;
        
        EAIntroPage *page2 = [EAIntroPage page];
        page2.title = [CCUtility localizableBrand:@"_intro_210_03_" table: @"Intro"]; //
        page2.titlePositionY = titlePositionY;
        page2.titleColor = COLOR_GRAY;
        page2.titleFont = RalewayMedium(20.0f);
        page2.desc = [CCUtility localizableBrand:@"_intro_210_04_" table: @"Intro"];
        page2.descPositionY = descPositionY;
        page2.descColor = COLOR_GRAY;
        page2.descFont = RalewayLight(14.0f);
        page2.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"intro210-2"]];
        page2.bgImage = [UIImage imageNamed:@"bgbianco"];
        page2.titleIconPositionY = titleIconPositionY;
        page2.showTitleView = NO;

        EAIntroPage *pageEnd = [EAIntroPage page];
        pageEnd.title = [CCUtility localizableBrand:@"_intro_END_01_" table: @"Intro"]; //
        pageEnd.titlePositionY = titlePositionY;
        pageEnd.titleColor = COLOR_GRAY;
        pageEnd.titleFont = RalewayMedium(20.0f);
        pageEnd.descPositionY = descPositionY;
        pageEnd.descColor = COLOR_GRAY;
        pageEnd.descFont = RalewayLight(14.0f);
#ifdef CC
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEnd"]];
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_" table: @"Intro"];
#endif
#ifdef NC
        pageEnd.titleIconView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"introEndNextcloud"]];
        pageEnd.desc = [CCUtility localizableBrand:@"_intro_END_02_Nextcloud_" table: @"Intro"];
#endif
        pageEnd.bgImage = [UIImage imageNamed:@"bgbianco"];
        pageEnd.titleIconPositionY = titleIconPositionY;
        pageEnd.showTitleView = NO;
            
        if (review) intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1, page2]];
        else intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page0, page1, page2, pageEnd]];
            
        //intro.backgroundColor = [UIColor whiteColor];
        intro.tapToNext = YES;
        intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
        intro.pageControl.currentPageIndicatorTintColor = [UIColor blackColor];
        [intro.skipButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            
        [intro setDelegate:self];
        [intro showInView:self.rootView animateDuration:duration];

    } else {
        
        [self.delegate introDidFinish:intro wasSkipped:NO];
    }

}

@end

//
//  CCIntro.m
//  Nextcloud iOS
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
#import <QuartzCore/QuartzCore.h>

@interface CCIntro ()
{
    int safeAreaBottom;
    int selector;
    
    NSMutableArray *professions;
    EAIntroPage *page4;
}
@end

@implementation CCIntro

- (id)initWithDelegate:(id <CCIntroDelegate>)delegate delegateView:(UIView *)delegateView
{
    self = [super init];
    
    if (self) {
        self.delegate = delegate;
        self.rootView = delegateView;
        
        professions = [NSMutableArray new];
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
    NSString *language = [[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0];

    // SafeArea
    
    if (@available(iOS 11, *)) {
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (orientation == UIInterfaceOrientationLandscapeLeft || orientation == UIInterfaceOrientationLandscapeRight) {
            safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.right;
        } else {
            safeAreaBottom = [UIApplication sharedApplication].delegate.window.safeAreaInsets.bottom;
        }
    }
    
    // Pages
    
    EAIntroPage *page1 = [EAIntroPage pageWithCustomViewFromNibNamed:@"HCIntroPage1"];
    UILabel *titlePage1 = (UILabel *)[page1.customView viewWithTag:1];
    UILabel *label1Page1 = (UILabel *)[page1.customView viewWithTag:2];
    UILabel *label2Page1 = (UILabel *)[page1.customView viewWithTag:3];
    UILabel *label3Page1 = (UILabel *)[page1.customView viewWithTag:4];
    UILabel *label4Page1 = (UILabel *)[page1.customView viewWithTag:5];

    if ([language isEqualToString:@"de"]) {
        titlePage1.text = @"HERZLICH WILLKOMMEN ZU IHRER PERSÖNLICHEN HANDWERKCLOUD!";
        label1Page1.text = @"Sparen Sie effektiv Zeit in der Verwaltung und Organisation";
        label2Page1.text = @"Die Daten in Ihrer Cloud sind immer und überall erreichbar";
        label3Page1.text = @"Ihr Verwaltungsaufwand sinkt, während Ihre Effizienz steigt";
        label4Page1.text = @"Bei Fragen unterstützen wir Sie jederzeit gerne";
    } else if ([language isEqualToString:@"it"]) {
        titlePage1.text = @"BENVENUTO SU HANDWERKCLOUD!";
        label1Page1.text = @"Risparmia tempo in amministrazione e organizzazione";
        label2Page1.text = @"I tuoi dati cloud sono disponibili ovunque e in qualsiasi momento";
        label3Page1.text = @"Riduci le abbondanti attività amministrative e aumenta la produttività";
        label4Page1.text = @"In caso di domande, saremo lieti di supportarti in qualsiasi momento";
    } else {
        titlePage1.text = @"WELCOME TO HANDWERKCLOUD!";
        label1Page1.text = @"Save time in administration and organization";
        label2Page1.text = @"Your cloud data is available anywhere and anytime";
        label3Page1.text = @"Reduce abundant administrative tasks and increase your productivity";
        label4Page1.text = @"If you have any questions, we‘ll be happy to support you at any time";
    }
    
    EAIntroPage *page2 = [EAIntroPage pageWithCustomViewFromNibNamed:@"HCIntroPage2"];
    UILabel *titlePage2 = (UILabel *)[page2.customView viewWithTag:1];
    UILabel *label1Page2 = (UILabel *)[page2.customView viewWithTag:2];
    UILabel *label2Page2 = (UILabel *)[page2.customView viewWithTag:3];
    UILabel *label3Page2 = (UILabel *)[page2.customView viewWithTag:4];
    UILabel *label4Page2 = (UILabel *)[page2.customView viewWithTag:5];
    UILabel *label5Page2 = (UILabel *)[page2.customView viewWithTag:6];
    UILabel *label6Page2 = (UILabel *)[page2.customView viewWithTag:7];

    if ([language isEqualToString:@"de"]) {
        titlePage2.text = @"DIE APP, DIE IHR HANDWERK VERSTEHT";
        label1Page2.text = @"Zeitmanagement, Projektmanagement";
        label2Page2.text = @"Digitales Aufmass";
        label3Page2.text = @"Bestandswesen";
        label4Page2.text = @"Datenverwaltung, Belegerfassung & -erkennung";
        label5Page2.text = @"Kalender, Einsatzplanung";
        label6Page2.text = @"Und vieles mehr";
    } else if ([language isEqualToString:@"it"]) {
        titlePage2.text = @"L' APP PER IL TUO ARTIGIANATO";
        label1Page2.text = @"Gestione del tempo, gestione del progetto";
        label2Page2.text = @"Misurazione fotometrica";
        label3Page2.text = @"Gestione delle scorte";
        label4Page2.text = @"Gestione dei dati";
        label5Page2.text = @"Calendario, pianificazione delle risorse";
        label6Page2.text = @"E molto di più";
    } else {
        titlePage2.text = @"THE APP FOR YOUR CRAFTSMANSHIP";
        label1Page2.text = @"Time management, project management";
        label2Page2.text = @"Photometric measurement";
        label3Page2.text = @"Inventory management";
        label4Page2.text = @"Data management";
        label5Page2.text = @"Calendar, resource planning";
        label6Page2.text = @"And a lot more";
    }
    
    EAIntroPage *page3 = [EAIntroPage pageWithCustomViewFromNibNamed:@"HCIntroPage3"];
    UILabel *titlePage3 = (UILabel *)[page3.customView viewWithTag:1];
    UIView *viewPage3 = (UIView *)[page3.customView viewWithTag:2];
    UILabel *label1Page3 = (UILabel *)[page3.customView viewWithTag:3];

    viewPage3.backgroundColor = [[NCBrandColor sharedInstance] customer];
    if ([language isEqualToString:@"de"]) {
        titlePage3.text = @"FÜR ALLE GENAU DIE PASSENDE LÖSUNG";
        label1Page3.text = @"Wählen Sie im nächsten Schritt Ihren Beruf aus, damit wir Ihnen personalisierte und genau auf Ihre Branche abgestimmte Inhalte zur Verfügung stellen können";
    } else if ([language isEqualToString:@"it"]) {
        titlePage3.text = @"LA SOLUZIONE PERFETTA PER TE";
        label1Page3.text = @"Nella pagina successiva, scegli la tua professione in modo che possiamo fornirti contenuti personalizzati per il tuo settore";
    } else {
        titlePage3.text = @"THE PERFECT SOLUTION FOR YOU";
        label1Page3.text = @"On the next page, please choose your profession so that we can provide you with personalised content for your industry";
    }

    page4 = [EAIntroPage pageWithCustomViewFromNibNamed:@"HCIntroPage4"];
    
    UILabel *titlePage4 = (UILabel *)[page4.customView viewWithTag:1];
    if ([language isEqualToString:@"de"]) {
        titlePage4.text = @"Wählen Sie Ihren Beruf";
    } else if ([language isEqualToString:@"it"]) {
        titlePage4.text = @"Scegli la tua professione";
    } else {
        titlePage4.text = @"Choose your profession";
    }
    
    UIButton *buttonLogin = (UIButton *)[page4.customView viewWithTag:2];
    buttonLogin.layer.cornerRadius = 20;
    buttonLogin.clipsToBounds = YES;
    [buttonLogin setTitle:NSLocalizedString(@"_ok_", nil) forState:UIControlStateNormal];
    buttonLogin.backgroundColor = [[NCBrandColor sharedInstance] customer];
    [buttonLogin addTarget:self action:@selector(login:) forControlEvents:UIControlEventTouchUpInside];

    for(int tag = 100; tag < 1300; tag = tag + 100) {
        
        UIView *view = (UIView *)[page4.customView viewWithTag:tag];
        view.layer.borderWidth = 1.0f;
        view.layer.borderColor = [[NCBrandColor sharedInstance] brand].CGColor;
        view.layer.cornerRadius = 10;
        UILabel *label = (UILabel *)[page4.customView viewWithTag:tag+2];
        label.text = [self returnProfession:tag language:language];
        UIButton *button = (UIButton *)[page4.customView viewWithTag:tag+3];
        [button addTarget:self action:@selector(selectProfession:) forControlEvents:UIControlEventTouchUpInside];
    }
    
    // INTRO
    
    self.intro = [[EAIntroView alloc] initWithFrame:self.rootView.bounds andPages:@[page1,page2,page3,page4]];
    //self.intro.bgImage = [UIImage imageNamed:@"introBackground"];
    
    self.intro.tapToNext = NO;
    self.intro.pageControlY = safeAreaBottom + 40;
    self.intro.pageControl.pageIndicatorTintColor = [UIColor lightGrayColor];
    self.intro.pageControl.currentPageIndicatorTintColor = [[NCBrandColor sharedInstance] brand];
    self.intro.pageControl.backgroundColor = [UIColor whiteColor];
    self.intro.swipeToExit = NO ;
    self.intro.skipButton = nil ;
    self.intro.swipeToExit = NO;
    
    [self.intro setDelegate:self];
    [self.intro showInView:self.rootView animateDuration:0];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Action =====
#pragma --------------------------------------------------------------------------------------------

- (IBAction)selectProfession:(UIButton *)sender
{
    NSInteger tag = sender.tag-3;
    NSString *imageColor;
    NSString *profession = [self returnProfession:tag language:@"en"];
    
    UIView *view = (UIView *)[page4.customView viewWithTag:tag];
    UIImageView *imageView = (UIImageView *)[page4.customView viewWithTag:tag+1];
    UILabel *label = (UILabel *)[page4.customView viewWithTag:tag+2];
    
    switch (tag) {
        case 100:
            imageColor = @"introCarpenter";
            break;
        case 200:
            imageColor = @"introStovebuilder";
            break;
        case 300:
            imageColor = @"introWindowbuilder";
            break;
        case 400:
            imageColor = @"introInstaller";
            break;
        case 500:
            imageColor = @"introElectrician";
            break;
        case 600:
            imageColor = @"introPainter";
            break;
        case 700:
            imageColor = @"introFlasher";
            break;
        case 800:
            imageColor = @"introBricklayer";
            break;
        case 900:
            imageColor = @"introRoofer";
            break;
        case 1000:
            imageColor = @"introStuccoer";
            break;
        case 1100:
            imageColor = @"introArchitect";
            break;
        case 1200:
            imageColor = @"introOther";
            break;
        default:
            break;
    }
    
    if ([professions containsObject:profession]) {
        [professions removeObject:profession];
        view.backgroundColor = [UIColor clearColor];
        label.textColor = [UIColor blackColor];
        imageView.image = [UIImage imageNamed:imageColor];
    } else {
        [professions addObject:profession];
        view.backgroundColor = [[NCBrandColor sharedInstance] brand];
        label.textColor = [UIColor whiteColor];
        imageView.image = [UIImage imageNamed:[imageColor stringByAppendingString:@"White"]];
    }
}

- (IBAction)login:(UIButton *)sender
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    if (professions.count > 0) {
        NSString *professionsString = [[professions componentsJoinedByString:@","] stringByReplacingOccurrencesOfString:@" " withString:@""];
        [CCUtility setHCBusinessType:professionsString];
        selector = k_intro_login;
        [self.intro hideWithFadeOutDuration:0.7];
    } else {
        UILabel *titlePage4 = (UILabel *)[page4.customView viewWithTag:1];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_", nil) message:titlePage4.text preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { }];
        
        [alertController addAction:okAction];
        [appDelegate.window.rootViewController presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)host:(id)sender
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    NCBrowserWeb *browserWebVC = [[UIStoryboard storyboardWithName:@"NCBrowserWeb" bundle:nil] instantiateInitialViewController];
    
    browserWebVC.urlBase = [NCBrandOptions sharedInstance].linkLoginHost;
    
    [appDelegate.window.rootViewController presentViewController:browserWebVC animated:YES completion:nil];
}

- (NSString *)returnProfession:(NSInteger)tag language:(NSString *)language
{
    if ([language isEqualToString:@"de"]) {
        if (tag == 100) return @"SCHREINER";
        if (tag == 200) return @"OFENBAUER";
        if (tag == 300) return @"FENSTERBAUER";
        if (tag == 400) return @"INSTALLATEUR";
        if (tag == 500) return @"ELEKTRIKER";
        if (tag == 600) return @"MALER";
        if (tag == 700) return @"FLASCHNER";
        if (tag == 800) return @"MAURER";
        if (tag == 900) return @"DACHDECKER";
        if (tag == 1000) return @"STUCKATEUR";
        if (tag == 1100) return @"ARCHITEKT";
        if (tag == 1200) return @"SONSTIGES";
    } else if ([language isEqualToString:@"it"]) {
        if (tag == 100) return @"FALEGNAME";
        if (tag == 200) return @"CAMINETTI";
        if (tag == 300) return @"SERRAMENTI";
        if (tag == 400) return @"INSTALLATORE";
        if (tag == 500) return @"ELETTRICISTA";
        if (tag == 600) return @"PITTORE";
        if (tag == 700) return @"IDRAULICO";
        if (tag == 800) return @"MURATORE";
        if (tag == 900) return @"RIPARA TETTI";
        if (tag == 1000) return @"STUCCATORE";
        if (tag == 1100) return @"ARCHITETTO";
        if (tag == 1200) return @"ALTRO";
    } else {
        if (tag == 100) return @"CARPENTER";
        if (tag == 200) return @"STOVE BUILDER";
        if (tag == 300) return @"WINDOW BUILDER";
        if (tag == 400) return @"INSTALLER";
        if (tag == 500) return @"ELECTRICIAN";
        if (tag == 600) return @"PAINTER";
        if (tag == 700) return @"PLUMBER";
        if (tag == 800) return @"BRICK LAYER";
        if (tag == 900) return @"ROOFER";
        if (tag == 1000) return @"STUCCOER";
        if (tag == 1100) return @"ARCHITECT";
        if (tag == 1200) return @"OTHER";
    }

    return nil;
}

- (void)didStartLoading
{
}

- (void)didReceiveServerRedirectForProvisionalNavigationWithUrl:(NSURL *)url
{
}

- (void)didFinishLoadingWithSuccess:(BOOL)success url:(NSURL *)url
{
}

- (void)webDismiss
{
}

@end

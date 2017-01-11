//
//  CCLogin.m
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

#import "CCLogin.h"

#import "AppDelegate.h"

@implementation CCLogin

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginCorrect) name:@"messageLoginCorrect" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loginIncorrect) name:@"messageLoginIncorrect" object:nil];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.brand.image = [UIImage imageNamed:image_launchscreen];
    
    _owncloud.hidden = YES;
    _dropbox.hidden = YES;
    
    [_nextcloud setTitle:[NSString stringWithFormat:@"     %@", NSLocalizedString(@"_add_your_nextcloud_", nil)] forState:UIControlStateNormal];
    [_owncloud setTitle:[NSString stringWithFormat:@"     %@", NSLocalizedString(@"_add_your_owncloud_", nil)] forState:UIControlStateNormal];
    [_dropbox setTitle:[NSString stringWithFormat:@"     %@", NSLocalizedString(@"_add_your_dropbox_", nil)] forState:UIControlStateNormal];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self selectFunction];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == select Function ==
#pragma --------------------------------------------------------------------------------------------

- (void)selectFunction
{
    // Show Intro
    if ([CCUtility getIntro:@"1.0"] == NO) {
        
        self.intro = [[CCIntro alloc] initWithDelegate:self delegateView:self.view];
        [self.intro showIntroCryptoCloud:2.0];
    }
    
    // Request : Passcode
    if ([CCUtility getIntro:@"1.0"] == YES && [[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
        
        [self passcodeVC];
    }
    
    // Request : Send Passcode email
    if ([CCUtility getIntro:@"1.0"] == YES && [[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] > 0 && [CCUtility getEmail] == nil && [app.activeAccount length] == 0) {
        
        CCSecurityOptions *viewController = [[CCSecurityOptions alloc] initWithDelegate:self];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
    // OK all - Close
    if ([CCUtility getIntro:@"1.0"] == YES && [[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] > 0 && [app.activeAccount length] > 0) {
        
        [self loginCorrect];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == IBAction ==
#pragma --------------------------------------------------------------------------------------------

- (IBAction)handleNextcloud:(id)sender
{
    if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
        
        [self passcodeVC];
        return;
    }
    
    self.owncloud.enabled = NO;
    self.dropbox.enabled = NO;
    
    CCLoginNCOC *loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
    
    [loginVC setModifyOnlyPassword:NO];
    [loginVC setTypeCloud:typeCloudNextcloud];
    
    [self presentViewController:loginVC animated:YES completion:NULL];
}

- (IBAction)handleOwnCloud:(id)sender
{
    if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
        
        [self passcodeVC];
        return;
    }
    
    self.owncloud.enabled = NO;
    self.dropbox.enabled = NO;
    
    CCLoginNCOC *loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginOwnCloud"];
    
    [loginVC setModifyOnlyPassword:NO];
    [loginVC setTypeCloud:typeCloudOwnCloud];
    
    [self presentViewController:loginVC animated:YES completion:NULL];
}

#ifdef CC
- (IBAction)handleDropBox:(id)sender
{
    if ([[CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]] length] == 0) {
        
        [self passcodeVC];
        return;
    }
    
    self.owncloud.enabled = NO;
    self.dropbox.enabled = NO;
    
    [[DBSession sharedSession] linkFromController:self];
}
#endif

#pragma --------------------------------------------------------------------------------------------
#pragma mark == BKPasscodeViewController ==
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    switch (aViewController.type) {
        case BKPasscodeViewControllerNewPasscodeType:
        case BKPasscodeViewControllerCheckPasscodeType: {
            
                // min passcode 4 chars
                if ([aPasscode length] >= 4) {
            
                    [CCUtility setKeyChainPasscodeForUUID:[CCUtility getUUID] conPasscode:aPasscode];
                    
                    // verify
                    NSString *pwd = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
                    
                    if ([pwd isEqualToString:aPasscode] == NO || pwd == nil) {
                        
                        UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:@"Fatal error writing key" delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                        [alertView show];
                    }
                    
                } else {
                    
                    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:NSLocalizedString(@"_passcode_too_short_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView show];
                }
            
                [aViewController dismissViewControllerAnimated:YES completion:nil];
            }
            break;
        case BKPasscodeViewControllerChangePasscodeType:
            if ([aPasscode length]) {
                
                // [CCUtility WriteDatiLogin:@"" ConNomeUtente:@"" ConPassword:@"" ConPassCode:aPasscode];
                // [aViewController dismissViewControllerAnimated:YES completion:nil];
            }

            self.failedAttempts = 0;
            self.lockUntilDate = nil;
            break;
        default:
            break;
    }
}

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode length]) {
        
        self.lockUntilDate = nil;
        self.failedAttempts = 0;
        aResultHandler(YES);
        
     } else {
         
        aResultHandler(NO);
     }
}

- (void)passcodeViewControllerDidFailAttempt:(BKPasscodeViewController *)aViewController
{
    self.failedAttempts++;
    
    if (self.failedAttempts > 5) {
        
        NSTimeInterval timeInterval = 60;
        
        if (self.failedAttempts > 6) {
            
            NSUInteger multiplier = self.failedAttempts - 6;
            
            timeInterval = (5 * 60) * multiplier;
            
            if (timeInterval > 3600 * 24) {
                timeInterval = 3600 * 24;
            }
        }
        
        self.lockUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    }
}

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(BKPasscodeViewController *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(BKPasscodeViewController *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Intro Delegate ==
#pragma --------------------------------------------------------------------------------------------

- (void)introDidFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped
{
    [CCUtility setIntro:@"1.0"];
    
    [self selectFunction];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == navigation ==
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeVC
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    viewController.type = BKPasscodeViewControllerNewPasscodeType;
    
    viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
    viewController.passcodeInputView.maximumLength = 64;
    
    viewController.title = NSLocalizedString(@"_key_aes_256_", nil);
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)loginCorrect
{    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"initializeMain" object:nil];
    
    // close
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
        [self dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)loginIncorrect
{
    NSLog(@"[LOG] Incorrect login");
    
    self.owncloud.enabled = YES;
    self.dropbox.enabled = YES;
}

@end

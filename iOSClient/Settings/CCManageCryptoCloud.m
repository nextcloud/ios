//
//  CCManageCryptoCloud.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 13/02/17.
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

#import "CCManageCryptoCloud.h"
#import "AppDelegate.h"

@implementation CCManageCryptoCloud

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        [self initializeForm];
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"Crypto Cloud", nil)];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Activation Crypto Cloud Mode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"activatecryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_activation_crypto_cloud_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCryptoCloud] forKey:@"imageView.image"];
    row.action.formSelector = @selector(activateCryptoCloud:);
    [section addFormRow:row];
    
    // Send aes-256 password via mail
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmailencryptpass" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_encryptpass_by_email_", nil)];
    [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:COLOR_ENCRYPTED forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsKeyMail] forKey:@"imageView.image"];
    row.action.formSelector = @selector(checkEncryptPass:);
    [section addFormRow:row];

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self reloadForm];
}

- (void)activateCryptoCloud:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    
    viewController.type = BKPasscodeViewControllerNewPasscodeType;
    viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
    
    viewController.passcodeInputView.maximumLength = 64;
    viewController.title = NSLocalizedString(@"_key_aes_256_", nil);
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)checkEncryptPass:(XLFormRowDescriptor *)sender
{
    
}

- (void)closeSecurityOptions
{
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_OK_", nil) message:@"Attivazione avvenuta correttamente, ora potrai usufruire di tutte le funzionalità aggiuntive. Ti ricordiamo che i file cifrati possono essere decifrati sono sui dispositivi iOS" delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
    [alertView show];
}

- (void)activateSecurityOptions
{
    CCSecurityOptions *securityOptionsVC = [[CCSecurityOptions alloc] initWithDelegate:self];
    UINavigationController *securityOptionsNC = [[UINavigationController alloc] initWithRootViewController:securityOptionsVC];
    
    [securityOptionsNC setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:securityOptionsNC animated:YES completion:nil];
}

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
                        
                    } else {
                
                        // ok !!
                        app.isCryptoCloudMode = YES;
                        
                        // reload
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"initializeMain" object:nil];
                        
                        // Request : Send Passcode email
                        [self performSelector:@selector(activateSecurityOptions) withObject:nil afterDelay:0.1];

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
#pragma mark === Reload Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)reloadForm
{
    XLFormRowDescriptor *rowActivateCryptoCloud = [self.form formRowWithTag:@"activatecryptocloud"];
    
    if (app.isCryptoCloudMode)
        rowActivateCryptoCloud.hidden = @(YES);
        
    [self.tableView reloadData];
}


@end

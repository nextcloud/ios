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
#import "NCBridgeSwift.h"

@implementation CCManageCryptoCloud

-(id)init
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_crypto_cloud_system_", nil)];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_footer_crypto_cloud_", nil);
    
    // Activation Crypto Cloud Mode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"activatecryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_activation_crypto_cloud_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsCryptoCloud"] forKey:@"imageView.image"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(activateCryptoCloud:);
    row.hidden = @(YES);
    [section addFormRow:row];
    
    // Deactivation Crypto Cloud Mode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deactivatecryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_deactivation_crypto_cloud_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsRemoveCryptoCloud"] forKey:@"imageView.image"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[NCBrandColor sharedInstance].brand forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(disactivateCryptoCloud:);
    row.hidden = @(YES);
    [section addFormRow:row];

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    return [super initWithForm:form];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;
    
    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self reloadForm];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
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
    viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)disactivateCryptoCloud:(XLFormRowDescriptor *)sender
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    
    viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
    viewController.passcodeInputView.maximumLength = 64;
    
    viewController.title = NSLocalizedString(@"_check_key_aes_256_", nil);
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)closeCryptoCloudSecurity
{
    // @"Attivazione avvenuta correttamente, ora potrai usufruire di tutte le funzionalità aggiuntive. Ti ricordiamo che i file cifrati possono essere decifrati sono sui dispositivi iOS"
    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_alert_activation_crypto_cloud_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
    [alertView show];
}

- (void)activateSecurityOptions
{
    CCManageCryptoCloudSecurity *vc = [[CCManageCryptoCloudSecurity alloc] initWithDelegate:self];
    UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:vc];
    
    [nc setModalPresentationStyle:UIModalPresentationFormSheet];
    [self presentViewController:nc animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == BKPasscodeViewController ==
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    switch (aViewController.type) {
            
        case BKPasscodeViewControllerNewPasscodeType: {
            
            // min passcode 4 chars
            if ([aPasscode length] >= 4) {
                
                [CCUtility setKeyChainPasscodeForUUID:[CCUtility getUUID] conPasscode:aPasscode];
                
                // verify
                NSString *pwd = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
                
                if ([pwd isEqualToString:aPasscode] == NO || pwd == nil) {
                    
                    UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:@"Fatal error writing key" delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView show];
                        
                } else {
                
                    // Crypto Cloud Mode : Activated
                    app.isCryptoCloudMode = YES;
                        
                    // force reload all directory for all users
                    [CCCoreData clearAllDateReadDirectory];
                    
                    // 3D Touch
                    [app configDynamicShortcutItems];

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
        
        case BKPasscodeViewControllerCheckPasscodeType: {
            
            // Crypto Cloud Mode : Deactivated
            [CCUtility adminRemovePasscode];
            app.isCryptoCloudMode = NO;
            
            // 3D touch
            [app configDynamicShortcutItems];

            // force reload all directory for all users and all metadata cryptated
            [CCCoreData clearAllDateReadDirectory];
            [CCCoreData deleteMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(cryptated == 1)"]];
            
            UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_info_", nil) message:NSLocalizedString(@"_alert_deactivation_crypto_cloud_", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
            
            [aViewController dismissViewControllerAnimated:YES completion:nil];
        }
        break;
            
        default:
            
        break;
    }
}

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if (aViewController.type == BKPasscodeViewControllerCheckPasscodeType) {
        
        NSString *key = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
        
        if ([aPasscode isEqualToString:key]) {
            
            self.lockUntilDate = nil;
            self.failedAttempts = 0;
            aResultHandler(YES);
            
        } else {
            
            aResultHandler(NO);
        }
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
    XLFormRowDescriptor *rowDeactivateCryptoCloud = [self.form formRowWithTag:@"deactivatecryptocloud"];
    XLFormRowDescriptor *rowSendMailEncryptPass = [self.form formRowWithTag:@"sendmailencryptpass"];

    if (app.isCryptoCloudMode) {
        
        rowActivateCryptoCloud.hidden = @(YES);
        rowDeactivateCryptoCloud.hidden = @(NO);
        rowSendMailEncryptPass.hidden = @(NO);
        
    } else {
        
        rowActivateCryptoCloud.hidden = @(NO);
        rowDeactivateCryptoCloud.hidden = @(YES);
        rowSendMailEncryptPass.hidden = @(YES);
    }

    [self.tableView reloadData];
}

@end

//
//  CCSettings.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 24/11/14.
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

#import "CCSettings.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "OCCapabilities.h"
#import "CCSynchronize.h"
#import "CCAdvanced.h"
#import "CCManageCryptoCloud.h"
#import "CCManageAccount.h"
#import "NCBridgeSwift.h"

#define alertViewEsci 1
#define alertViewAzzeraCache 2

@implementation CCSettings

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        [self initializeForm];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
        
        app.activeSettings = self;
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_settings_", nil)];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    // Section AUTO UPLOAD OF CAMERA IMAGES ----------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUpload" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_settings_autoupload_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsCameraUpload"] forKey:@"imageView.image"];
    row.action.formSegueIdentifier = @"CCManageAutoUploadSegue";
    [section addFormRow:row];

    // Section FOLDERS FAVORITES OFFLINE ------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"favoriteoffline" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_favorite_offline_", nil)];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsFavoriteOffline"] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Section : PASSWORD --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_passcode_", nil)];
    [form addFormSection:section];
    
    // Passcode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"bloccopasscode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_lock_not_active_", nil)];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsPasscodeNO"] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formSelector = @selector(bloccoPassword);
    [section addFormRow:row];
    
    // Passcode simply
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"simplypasscode" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_lock_protection_simply_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Passcode only directory
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"onlylockdir" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_lock_protection_folder_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Section CRYPTO CLOUD SYSTEM ------------------------------------------
    
    // Brand
    if ([NCBrandOptions sharedInstance].disable_cryptocloudsystem == NO) {
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
    
        // Crypto Cloud
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"cryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_crypto_cloud_system_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:@"settingsCryptoCloud"] forKey:@"imageView.image"];
        row.action.viewControllerClass = [CCManageCryptoCloud class];
        [section addFormRow:row];
    }
    
    // Section Advanced -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Advanced
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"advanced" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_advanced_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsAdvanced"] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCAdvanced class];
    [section addFormRow:row];

    // Section : INFORMATION ------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_information_", nil)];
    [form addFormSection:section];
    
    // Acknowledgements
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"buttonLeftAligned" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_acknowledgements_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsAcknowledgements"] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender){
        [self performSegueWithIdentifier:@"AcknowledgementsSegue" sender:sender];
        [self deselectFormRow:sender];
    };
    [section addFormRow:row];
    
    // Contact us mail
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmail" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_contact_by_email_", nil)];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:@"settingsMail"] forKey:@"imageView.image"];
    row.action.formSelector = @selector(sendMail:);
    [section addFormRow:row];
   
    self.form = form;
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Chiamate dal Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)reloadForm
{
    self.form.delegate = nil;
    
    // ----------------------
    
    XLFormRowDescriptor *rowBloccoPasscode = [self.form formRowWithTag:@"bloccopasscode"];
    XLFormRowDescriptor *rowSimplyPasscode = [self.form formRowWithTag:@"simplypasscode"];
    XLFormRowDescriptor *rowOnlyLockDir = [self.form formRowWithTag:@"onlylockdir"];
    XLFormRowDescriptor *rowFavoriteOffline = [self.form formRowWithTag:@"favoriteoffline"];

    // ------------------------------------------------------------------
    
    if ([[CCUtility getBlockCode] length]) {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:@"settingsPasscodeYES"] forKey:@"imageView.image"];
    } else {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_not_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:@"settingsPasscodeNO"] forKey:@"imageView.image"];
    }
    
    if ([CCUtility getSimplyBlockCode]) [rowSimplyPasscode setValue:@1]; else [rowSimplyPasscode setValue:@0];
    if ([CCUtility getOnlyLockDir]) [rowOnlyLockDir setValue:@1]; else [rowOnlyLockDir setValue:@0];
    if ([CCUtility getFavoriteOffline]) [rowFavoriteOffline setValue:@1]; else [rowFavoriteOffline setValue:@0];
    
    // -----------------------------------------------------------------
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"onlylockdir"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setOnlyLockDir:true];
        } else {
            [CCUtility setOnlyLockDir:false];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"simplypasscode"]) {
        
        if ([[CCUtility getBlockCode] length] == 0)
            [CCUtility setSimplyBlockCode:[[rowDescriptor.value valueData] boolValue]];
        else
            [self changeSimplyPassword];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"favoriteoffline"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_continue_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
            
            [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                [CCUtility setFavoriteOffline:true];
                [self synchronizeFavorites];
            }]];
            
            [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self reloadForm];
            }]];
            
            //if iPhone
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                
                [self presentViewController:alertController animated:YES completion:nil];
            }
            //if iPad
            else {
                
                // Change Rect to position Popover
                UIPopoverController *popup = [[UIPopoverController alloc] initWithContentViewController:alertController];
                [popup presentPopoverFromRect:[self.tableView rectForRowAtIndexPath:[self.form indexPathOfFormRow:rowDescriptor]] inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
            }
            
        } else {
            
            [CCUtility setFavoriteOffline:false];
        }
    }
}

- (void)checkEncryptPass:(XLFormRowDescriptor *)sender
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    viewController.fromType = CCBKPasscodeFromCheckCryptoKey;
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    
    viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
    viewController.passcodeInputView.maximumLength = 64;
    
    viewController.title = NSLocalizedString(@"_check_key_aes_256_", nil);
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)changeSimplyPassword
{
    CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
    viewController.delegate = self;
    viewController.type = BKPasscodeViewControllerCheckPasscodeType;
    viewController.fromType = CCBKPasscodeFromSimply;
    viewController.title = NSLocalizedString(@"_change_simply_passcode_", nil);
    viewController.inputViewTitlePassword = YES;
    
    if ([CCUtility getSimplyBlockCode]) {
        
        viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 6;
        
    } else {
        
        viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
        viewController.passcodeInputView.maximumLength = 64;
    }
    
    BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
    touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
    viewController.touchIDManager = touchIDManager;
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)bloccoPassword
{
    // ATTIVAZIONE LOCK PASSWORD
    if ([[CCUtility getBlockCode] length] == 0) {
        
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.type = BKPasscodeViewControllerNewPasscodeType;
        viewController.fromType = CCBKPasscodeFromSettingsPasscode;
        viewController.inputViewTitlePassword = YES;
        
        if ([CCUtility getSimplyBlockCode]) {
            
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
            
        } else {
            
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;

        viewController.title = NSLocalizedString(@"_passcode_activate_", nil);
        
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
               
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
            
        // OFF LOCK PASSWORD
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
        viewController.fromType = CCBKPasscodeFromSettingsPasscode;
        viewController.inputViewTitlePassword = YES;
        
        if ([CCUtility getSimplyBlockCode]) {
            
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
            
        } else {
            
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;
        
        viewController.title = NSLocalizedString(@"_disabling_passcode_", nil);
            
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [NCBrandColor sharedInstance].cryptocloud;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
}

- (void)synchronizeFavorites
{    
    NSArray *metadatas = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND favorite = true", app.activeAccount]  sorted:nil ascending:NO];
    
    for (tableMetadata *metadata in metadatas) {
        
        if (metadata.directory) {
        
            NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:metadata.directoryID];
            serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:metadata.fileNamePrint];

            NSString *serverUrlBeginWith = serverUrl;
            
            if (![serverUrl hasSuffix:@"/"])
                serverUrlBeginWith = [serverUrl stringByAppendingString:@"/"];

            NSArray *directories = [[NCManageDatabase sharedInstance] getTablesDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND (serverUrl = %@ OR serverUrl BEGINSWITH %@)", app.activeAccount, serverUrl, serverUrlBeginWith] sorted:@"serverUrl" ascending:true];
            
            for (tableDirectory *directory in directories)
                [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:nil directoryID:directory.directoryID];
        } 
    }
    
    [app.activeFavorites readListingFavorites];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Table View ===
#pragma --------------------------------------------------------------------------------------------

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *sectionName;
    
    switch (section)
    {
        case 1: {
            sectionName = NSLocalizedString(@"_favorite_offline_footer_", nil);
        }
        break;
        case 5: {
            
            tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];
            
            NSString *versionServer = capabilities.versionString;
            
            NSString *versionApp = [NSString stringWithFormat:@"%@.%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
            
            NSString *versionNextcloud = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudServer, versionServer];
            NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudiOS, versionApp];
            
            sectionName = [NSString stringWithFormat:@"%@\n%@", versionNextcloudiOS, versionNextcloud];
        }
        break;
    }
    return sectionName;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Mail ===
#pragma --------------------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController *)vc didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            [app messageNotification:@"_info_" description:@"_mail_deleted_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:error.code];
            break;
        case MFMailComposeResultSaved:
            [app messageNotification:@"_info_" description:@"_mail_saved_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:error.code];
            break;
        case MFMailComposeResultSent:
            [app messageNotification:@"_info_" description:@"_mail_sent_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess errorCode:error.code];
            break;
        case MFMailComposeResultFailed: {
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_mail_failure_", nil), [error localizedDescription]];
            [app messageNotification:@"_error_" description:msg visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:error.code];
        }
            break;
        default:
            break;
    }
    
    // Close the Mail Interface
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)sendMail:(XLFormRowDescriptor *)sender
{
    // Email Subject
    NSString *emailTitle = NSLocalizedString(@"_information_req_", nil);
    // Email Content
    NSString *messageBody;
    // Email Recipents
    NSArray *toRecipents;
    
    messageBody = [NSString stringWithFormat:@"\n\n\n%@ Version %@ (%@)", [NCBrandOptions sharedInstance].brand, [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    toRecipents = [NSArray arrayWithObject:[NCBrandOptions sharedInstance].mailMe];
    
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:emailTitle];
    [mc setMessageBody:messageBody isHTML:NO];
    [mc setToRecipients:toRecipents];
    
    // Present mail view controller on screen
    [self presentViewController:mc animated:YES completion:NULL];
}

- (void)sendMailEncryptPass
{
    [CCUtility sendMailEncryptPass:[CCUtility getEmail] validateEmail:NO form:self nameImage:@"backgroundDetail"];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === BKPasscodeViewController ===
#pragma --------------------------------------------------------------------------------------------

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    switch (aViewController.type) {
            
        case BKPasscodeViewControllerNewPasscodeType: {
            
            // enable passcode
            [CCUtility setBlockCode:aPasscode];
        }
        break;
            
        case BKPasscodeViewControllerCheckPasscodeType: {
            
            // disable passcode
            if (aViewController.fromType == CCBKPasscodeFromSettingsPasscode) {
                
                [CCUtility setBlockCode:@""];
                [[NCManageDatabase sharedInstance] setAllDirectoryUnLock];
                [app.activeMain.tableView reloadData];
            }
            
            // email Key EAS-256
            if (aViewController.fromType == CCBKPasscodeFromCheckCryptoKey)
                [self sendMailEncryptPass];
            
            // change simply
            if (aViewController.fromType == CCBKPasscodeFromSimply) {
                
                // disable passcode
                [CCUtility setBlockCode:@""];
                [[NCManageDatabase sharedInstance] setAllDirectoryUnLock];
                [app.activeMain.tableView reloadData];
                
                [CCUtility setSimplyBlockCode:![CCUtility getSimplyBlockCode]];
                
                //  Call new passcode
                [self bloccoPassword];
            }
        }
        break;
            
        default:
        break;
    }
    
    [self reloadForm];
}

- (void)passcodeViewController:(CCBKPasscode *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if (aViewController.fromType == CCBKPasscodeFromCheckCryptoKey) {
        
        NSString *key = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
        
        if ([aPasscode isEqualToString:key]) {
            self.lockUntilDate = nil;
            self.failedAttempts = 0;
            aResultHandler(YES);
        } else aResultHandler(NO);
        
    }
    
    if (aViewController.fromType == CCBKPasscodeFromSettingsPasscode || aViewController.fromType == CCBKPasscodeFromSimply) {
        
        if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
            self.lockUntilDate = nil;
            self.failedAttempts = 0;
            aResultHandler(YES);
        } else aResultHandler(NO);
        
    }
}

- (void)passcodeViewControllerDidFailAttempt:(CCBKPasscode *)aViewController
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

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(CCBKPasscode *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(CCBKPasscode *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end

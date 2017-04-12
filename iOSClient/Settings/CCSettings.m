//
//  CCSettings.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 24/11/14.
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

#import "CCSettings.h"
#import "AppDelegate.h"
#import "CCMain.h"
#import "OCCapabilities.h"
#import "CCSynchronize.h"
#import "CCAdvanced.h"
#import "CCManageCryptoCloud.h"
#import "CCManageAccount.h"

#define alertViewEsci 1
#define alertViewAzzeraCache 2

@implementation CCSettings

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        
        [self initializeForm];
        
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
    
    // Section : PASSWORD --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_passcode_", nil)];
    [form addFormSection:section];
    
    // Passcode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"bloccopasscode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_lock_not_active_", nil)];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsPasscodeNO] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
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

    // Section : CLOUD ACCOUNT --------------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_cloud_account_", nil)];
    [form addFormSection:section];
    
    // version
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"versionserver" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_version_server_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // Url
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"urlcloud" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_url_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // username
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usernamecloud" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_username_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // Change Account
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"changecredentials" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_change_credentials_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCredentials] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCManageAccount class];
    [section addFormRow:row];
    
    // Section : USER INFORMATION -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_user_information_", nil)];
    [form addFormSection:section];
    
    // Full Name
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userfullname" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_full_name_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // Address
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useraddress" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_address_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    // Phone
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userphone" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_phone_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    // Email
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useremail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_email_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    // Web
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userweb" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_web_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // Twitter
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usertwitter" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_twitter_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    // Section AUTOMATIC UPLOAD OF CAMERA IMAGES ----------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"cameraupload" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_uploading_from_camera_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCameraUpload] forKey:@"imageView.image"];
    row.action.formSegueIdentifier = @"CCManageCameraUploadSegue";
    [section addFormRow:row];

    // Section FOLDERS FAVORITES OFFLINE ------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_favorite_offline_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"favoriteoffline" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_favorite_offline_", nil)];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsFavoriteOffline] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];

#ifndef OPTION_CRYPTO_CLOUD_SYSTEM_DISABLE
    // Section CRYPTO CLOUD SYSTEM ------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Crypto Cloud
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"cryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_crypto_cloud_system_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCryptoCloud] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCManageCryptoCloud class];
    [section addFormRow:row];
#endif
    
    // Section : INFORMATION ------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_information_", nil)];
    [form addFormSection:section];
    
    NSString *versionApp = [NSString stringWithFormat:@"%@.%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    section.footerTitle = [NSString stringWithFormat:k_textCopyright, versionApp];
    
    // Acknowledgements
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"buttonLeftAligned" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_acknowledgements_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAcknowledgements] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender){
        [self performSegueWithIdentifier:@"AcknowledgementsSegue" sender:sender];
        [self deselectFormRow:sender];
    };
    [section addFormRow:row];
    
    // Contact us mail
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmail" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_contact_by_email_", nil)];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsMail] forKey:@"imageView.image"];
    row.action.formSelector = @selector(sendMail:);
    [section addFormRow:row];
   
    // Section Advanced -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Advanced
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"advanced" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_advanced_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdvanced] forKey:@"imageView.image"];
    row.action.viewControllerClass = [CCAdvanced class];
    [section addFormRow:row];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_settings_", nil);
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self reloadForm];
}

// E' apparsa
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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

    XLFormRowDescriptor *rowVersionServer = [self.form formRowWithTag:@"versionserver"];
    XLFormRowDescriptor *rowUrlCloud = [self.form formRowWithTag:@"urlcloud"];
    XLFormRowDescriptor *rowUserNameCloud = [self.form formRowWithTag:@"usernamecloud"];

    XLFormRowDescriptor *rowUserFullName = [self.form formRowWithTag:@"userfullname"];
    XLFormRowDescriptor *rowUserAddress = [self.form formRowWithTag:@"useraddress"];
    XLFormRowDescriptor *rowUserPhone = [self.form formRowWithTag:@"userphone"];
    XLFormRowDescriptor *rowUserEmail = [self.form formRowWithTag:@"useremail"];
    XLFormRowDescriptor *rowUserWeb = [self.form formRowWithTag:@"userweb"];
    XLFormRowDescriptor *rowUserTwitter = [self.form formRowWithTag:@"usertwitter"];

    
    //XLFormRowDescriptor *rowChangeCredentials = [self.form formRowWithTag:@"changecredentials"];

    // ------------------------------------------------------------------
    
    if ([[CCUtility getBlockCode] length]) {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:image_settingsPasscodeYES] forKey:@"imageView.image"];
    } else {
        rowBloccoPasscode.title = NSLocalizedString(@"_lock_not_active_", nil);
        [rowBloccoPasscode.cellConfig setObject:[UIImage imageNamed:image_settingsPasscodeNO] forKey:@"imageView.image"];
    }
    
    if ([CCUtility getSimplyBlockCode]) [rowSimplyPasscode setValue:@1]; else [rowSimplyPasscode setValue:@0];
    if ([CCUtility getOnlyLockDir]) [rowOnlyLockDir setValue:@1]; else [rowOnlyLockDir setValue:@0];
    if ([CCUtility getFavoriteOffline]) [rowFavoriteOffline setValue:@1]; else [rowFavoriteOffline setValue:@0];
    
    _tableAccount = [CCCoreData getActiveAccount];
    
    rowVersionServer.value = [NSString stringWithFormat:@"%lu.%lu.%lu",(unsigned long)[_tableAccount.versionMajor integerValue], (unsigned long)[_tableAccount.versionMinor integerValue], (unsigned long)[_tableAccount.versionMicro integerValue]];
    rowUrlCloud.value = app.activeUrl;
    rowUserNameCloud.value = app.activeUser;
    
    rowUserFullName.value = _tableAccount.displayName;
    if ([_tableAccount.displayName isEqualToString:@""]) rowUserFullName.hidden = @YES;
    
    rowUserAddress.value = _tableAccount.address;
    if ([_tableAccount.address isEqualToString:@""]) rowUserAddress.hidden = @YES;
    
    rowUserPhone.value = _tableAccount.phone;
    if ([_tableAccount.phone isEqualToString:@""]) rowUserPhone.hidden = @YES;
    
    rowUserEmail.value = _tableAccount.email;
    if ([_tableAccount.email isEqualToString:@""]) rowUserEmail.hidden = @YES;
    
    rowUserWeb.value = _tableAccount.webpage;
    if ([_tableAccount.webpage isEqualToString:@""]) rowUserWeb.hidden = @YES;
    
    rowUserTwitter.value = _tableAccount.twitter;
    if ([_tableAccount.twitter isEqualToString:@""]) rowUserTwitter.hidden = @YES;
    
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
    viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_CRYPTOCLOUD;
    
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
    viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_CRYPTOCLOUD;
    
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
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_CRYPTOCLOUD;
               
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
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_CRYPTOCLOUD;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
}

- (void)synchronizeFavorites
{
    NSArray *recordsTableMetadata = [CCCoreData  getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (favorite == 1)", app.activeAccount] context:nil];
    
    for (TableMetadata *tableMetadata in recordsTableMetadata) {
        
        if ([tableMetadata.directory boolValue]) {
        
            NSString *serverUrl = [CCCoreData getServerUrlFromDirectoryID:tableMetadata.directoryID activeAccount:app.activeAccount];
            serverUrl = [CCUtility stringAppendServerUrl:serverUrl addFileName:tableMetadata.fileNamePrint];
        
            NSArray *TableDirectories = [CCCoreData getDirectoryIDsFromBeginsWithServerUrl:serverUrl activeAccount:app.activeAccount];
        
            for (TableDirectory *tableDirecory in TableDirectories)
                [CCCoreData clearDateReadAccount:app.activeAccount serverUrl:nil directoryID:tableDirecory.directoryID];
            
        } 
    }
    
    [[CCSynchronize sharedSynchronize] readListingFavorites];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Mail ===
#pragma --------------------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController *)vc didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            [app messageNotification:@"_info_" description:@"_mail_deleted_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSaved:
            [app messageNotification:@"_info_" description:@"_mail_saved_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSent:
            [app messageNotification:@"_info_" description:@"_mail_sent_" visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultFailed: {
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_mail_failure_", nil), [error localizedDescription]];
            [app messageNotification:@"_error_" description:msg visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError];
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
    
    messageBody = [NSString stringWithFormat:@"\n\n\n%@ Version %@ (%@)", k_brand,[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    toRecipents = [NSArray arrayWithObject:k_mailMe];
    
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
    [CCUtility sendMailEncryptPass:[CCUtility getEmail] validateEmail:NO form:self];
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
                [CCCoreData setAllDirectoryUnLockForAccount:app.activeAccount];
                [app.activeMain.tableView reloadData];
            }
            
            // email Key EAS-256
            if (aViewController.fromType == CCBKPasscodeFromCheckCryptoKey)
                [self sendMailEncryptPass];
            
            // change simply
            if (aViewController.fromType == CCBKPasscodeFromSimply) {
                
                // disable passcode
                [CCUtility setBlockCode:@""];
                [CCCoreData setAllDirectoryUnLockForAccount:app.activeAccount];
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

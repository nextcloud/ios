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
    
    // Section : Settings
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_settings_", nil)];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_passcode_", nil)];
    [form addFormSection:section];
    
    // Passcode
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"bloccopasscode" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_lock_not_active_", nil)];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsPasscodeNO] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
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

    // Send aes-256 password via mail
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmailencryptpass" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_encryptpass_by_email_", nil)];
    [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:COLOR_ENCRYPTED forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsKeyMail] forKey:@"imageView.image"];
    row.action.formSelector = @selector(checkEncryptPass:);
    [section addFormRow:row];
    
    
    // Section : data Cloud
    
    section = [XLFormSectionDescriptor formSectionWithTitle:@"Cloud account"];
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
    
    // quota
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"quota" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_quota_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];

    
    // Change Account
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"changecredentials" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_change_credentials_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCredentials] forKey:@"imageView.image"];
    row.action.formSegueIdenfifier = @"CCManageAccountSegue";
    [section addFormRow:row];
    
    // Section : Camera Upload
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_uploading_from_camera_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"cameraupload" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_uploading_from_camera_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsCameraUpload] forKey:@"imageView.image"];
    row.action.formSegueIdenfifier = @"CCManageCameraUploadSegue";
    [section addFormRow:row];

    // Section : Photos
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_photo_camera_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"managephotos" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_photo_camera_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsManagePhotos] forKey:@"imageView.image"];
    row.action.formSegueIdenfifier = @"CCManagePhotosSegue";
    [section addFormRow:row];

    // Section : Optimizations
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_optimizations_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"optimizations" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_optimizations_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsOptimizations] forKey:@"imageView.image"];
    row.action.formSegueIdenfifier = @"CCManageOptimizationsSegue";
    [section addFormRow:row];

    // Section : Acknowledgements

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    section.footerTitle = @"Nextcloud © 2016 T.W.S. Inc.";
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"buttonLeftAligned" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_acknowledgements_", nil)];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAcknowledgements] forKey:@"imageView.image"];
    [row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender){
        [self performSegueWithIdentifier:@"AcknowledgementsSegue" sender:sender];
        [self deselectFormRow:sender];
    };
    [section addFormRow:row];
    
    // Version
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"versioneapplicazione" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_app_version_", nil)];
    row.value = [NSString stringWithFormat:@"%@ (%@)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
    [section addFormRow:row];
    
    // Section : help
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_help_", nil)];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"help" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_help_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsHelp] forKey:@"imageView.image"];
    row.action.formSegueIdenfifier = @"CCManageHelpSegue";
    [section addFormRow:row];
    
    // Section : mail
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Contact us mail
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmail" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_contact_by_email_", nil)];
    [row.cellConfig setObject:COLOR_BRAND forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsMail] forKey:@"imageView.image"];
    row.action.formSelector = @selector(sendMail:);
    [section addFormRow:row];

    // Section : cache
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Clear cache
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"azzeracache" rowType:XLFormRowDescriptorTypeButton title:@""];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsClearCache] forKey:@"imageView.image"];
    row.action.formSelector = @selector(azzeraCache:);
    [section addFormRow:row];

    // Section : debug
    
#ifdef DEBUG
    section = [XLFormSectionDescriptor formSectionWithTitle:@"Debug"];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"adminRemoveVersionIntro" rowType:XLFormRowDescriptorTypeButton title:@"Remove self-Version Intro"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(adminRemoveVersionIntro:);
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"adminRemovePasscode" rowType:XLFormRowDescriptorTypeButton title:@"Remove Passcode"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(adminRemovePasscode:);
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"adminRemoveVersion" rowType:XLFormRowDescriptorTypeButton title:@"Remove Version"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(adminRemoveVersion:);
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"copyGroupLocal" rowType:XLFormRowDescriptorTypeButton title:@"Copy Group to Local"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(copyDirGroupToLocal:);
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"quickActionOffline" rowType:XLFormRowDescriptorTypeButton title:@"Quick Action Offline"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(quickActionOffline:);
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"quickActionPhotos" rowType:XLFormRowDescriptorTypeButton title:@"Quick Action Photos"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAdmin] forKey:@"imageView.image"];
    row.action.formSelector = @selector(quickActionPhotos:);
    [section addFormRow:row];

#endif

    // Section : quit
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Exit
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"esci" rowType:XLFormRowDescriptorTypeButton title:[CCUtility localizableBrand:@"_exit_" table:nil]];
    
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsExit] forKey:@"imageView.image"];
    row.action.formSelector = @selector(esci:);
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    self.title = NSLocalizedString(@"_settings_", nil);
    
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
    [self recalculateSize];
}

// E' apparsa
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Admin ===
#pragma --------------------------------------------------------------------------------------------

- (void)adminRemoveVersionIntro:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [CCUtility adminRemoveIntro];
    
    exit(0);
}

- (void)adminRemovePasscode:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [CCUtility adminRemovePasscode];
    
    exit(0);
}

- (void)adminRemoveVersion:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [CCUtility adminRemoveVersion];
    
    exit(0);
}

- (void)quickActionOffline:(XLFormRowDescriptor *)sender
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
    UIApplicationShortcutItem *shortcutOffline = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.offline", bundleId] localizedTitle:@"" localizedSubtitle:nil icon:nil userInfo:nil];
    
    [app handleShortCutItem:shortcutOffline];
}

- (void)quickActionPhotos:(XLFormRowDescriptor *)sender
{
    NSString *bundleId = [NSBundle mainBundle].bundleIdentifier;
    
     UIApplicationShortcutItem *shortcutPhotos = [[UIApplicationShortcutItem alloc] initWithType:[NSString stringWithFormat:@"%@.photos", bundleId] localizedTitle:@"" localizedSubtitle:nil icon:nil userInfo:nil];
    
    [app handleShortCutItem:shortcutPhotos];
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
    
    XLFormRowDescriptor *rowVersionServer = [self.form formRowWithTag:@"versionserver"];
    
    XLFormRowDescriptor *rowUrlCloud = [self.form formRowWithTag:@"urlcloud"];
    XLFormRowDescriptor *rowUserNameCloud = [self.form formRowWithTag:@"usernamecloud"];
    XLFormRowDescriptor *rowQuota = [self.form formRowWithTag:@"quota"];
    
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
    
    if ([app.typeCloud isEqualToString:typeCloudOwnCloud] || [app.typeCloud isEqualToString:typeCloudNextcloud])
        rowVersionServer.value =  [CCNetworking sharedNetworking].sharedOCCommunication.getCurrentServerVersion;
    
    rowUrlCloud.value = app.activeUrl;
    rowUserNameCloud.value = app.activeUser;
    
    NSString *quota = [CCUtility transformedSize:(app.quotaAvailable + app.quotaUsed)];
    NSString *quotaAvailable = [CCUtility transformedSize:(app.quotaAvailable)];
    
    rowQuota.value = [NSString stringWithFormat:@"%@ / %@ %@", quota, quotaAvailable, NSLocalizedString(@"_available_", nil)];
        
    // -----------------------------------------------------------------
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

- (void)recalculateSize
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{

        self.form.delegate = nil;

        XLFormRowDescriptor *rowAzzeraCache = [self.form formRowWithTag:@"azzeracache"];

        NSString *size = [CCUtility transformedSize:[[self getUserDirectorySize] longValue]];
        rowAzzeraCache.title = [NSString stringWithFormat:NSLocalizedString(@"_clear_cache_", nil), size];
        
        [self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:NO];

        self.form.delegate = self;
    });
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
    viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
    
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
    
    BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
    touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
    viewController.touchIDManager = touchIDManager;
    
    viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
    viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
    
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
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;

        viewController.title = NSLocalizedString(@"_passcode_activate_", nil);
        
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
               
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
        
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:BKPasscodeKeychainServiceName];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;
        
        viewController.title = NSLocalizedString(@"_disabling_passcode_", nil);
            
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = COLOR_ENCRYPTED;
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navigationController animated:YES completion:nil];
    }
    
}

- (void)esci:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    UIAlertView * alertView =[[UIAlertView alloc ] initWithTitle:[CCUtility localizableBrand:@"_exit_" table:nil]
                                                         message:[CCUtility localizableBrand:@"_want_exit_" table:nil]
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"_cancel_", nil)
                                               otherButtonTitles: nil];
    alertView.tag = alertViewEsci;
    [alertView addButtonWithTitle:NSLocalizedString(@"_proceed_", nil)];
    [alertView show];
}

- (void)azzeraCache:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    UIAlertView * alertView =[[UIAlertView alloc ] initWithTitle:NSLocalizedString(@"_delete_cache_",nil)
                                                         message:NSLocalizedString(@"_want_delete_cache_", nil)
                                                        delegate:self
                                               cancelButtonTitle:NSLocalizedString(@"_cancel_", nil)
                                               otherButtonTitles: nil];
    alertView.tag = alertViewAzzeraCache;
    [alertView addButtonWithTitle:NSLocalizedString(@"_proceed_", nil)];
    [alertView show];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Mail ===
#pragma --------------------------------------------------------------------------------------------

- (void) mailComposeController:(MFMailComposeViewController *)vc didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
    switch (result)
    {
        case MFMailComposeResultCancelled:
            [app messageNotification:@"_info_" description:@"_mail_deleted_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSaved:
            [app messageNotification:@"_info_" description:@"_mail_saved_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultSent:
            [app messageNotification:@"_info_" description:@"_mail_sent_" visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeSuccess];
            break;
        case MFMailComposeResultFailed: {
            NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_mail_failure_", nil), [error localizedDescription]];
            [app messageNotification:@"_error_" description:msg visible:YES delay:dismissAfterSecond type:TWMessageBarMessageTypeError];
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
    
    messageBody = [NSString stringWithFormat:@"\n\n\nNextcloud Version %@ (%@)", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
    toRecipents = [NSArray arrayWithObject:_mail_me_];
    
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
#pragma mark === AlertView ===
#pragma --------------------------------------------------------------------------------------------

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // Remove ALL
    if (buttonIndex == 1 && alertView.tag == alertViewEsci)
    {
        [self.hud visibleIndeterminateHud];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

            [app cancelAllOperations];
            [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
        
            [[NSURLCache sharedURLCache] setMemoryCapacity:0];
            [[NSURLCache sharedURLCache] setDiskCapacity:0];
            
            [[CCNetworking sharedNetworking] invalidateAndCancelAllSession];
        
            [CCCoreData flushAllDatabase];
        
            [CCUtility deleteAllChainStore];
            
            [self emptyDocumentsDirectory];
        
            [self emptyLibraryDirectory];
        
            [self emptyGroupApplicationSupport];
            
            NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
            for (NSString *file in tmpDirectory)
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
            
            [self.hud hideHud];
            
            exit(0);
        });
    }
    
    // Clear Cache
    if (buttonIndex == 1 && alertView.tag == alertViewAzzeraCache)
    {
        [self.hud visibleHudTitle:NSLocalizedString(@"_remove_cache_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            
            [app cancelAllOperations];
            [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];

            [[NSURLCache sharedURLCache] setMemoryCapacity:0];
            [[NSURLCache sharedURLCache] setDiskCapacity:0];
            
            [CCCoreData flushTableAutomaticUploadAccount:app.activeAccount selector:nil];
            [CCCoreData flushTableDirectoryAccount:app.activeAccount];
            [CCCoreData flushTableLocalFileAccount:app.activeAccount];
            [CCCoreData flushTableMetadataAccount:app.activeAccount];
            
            [self emptyUserDirectoryUser:app.activeUser url:app.activeUrl];
        
            [self emptyLocalDirectory];
            
            NSArray* tmpDirectory = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:NULL];
            for (NSString *file in tmpDirectory) 
                [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:NULL];
                
            [self recalculateSize];
                
            // Inizialized home
            [[NSNotificationCenter defaultCenter] postNotificationName:@"initializeMain" object:nil];
                                
            [self.hud hideHud];
        });
    }
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
                CCMain *mainVC = [app.listMainVC objectForKey:app.serverUrl];
                if (mainVC)
                    [mainVC.tableView reloadData];
            }
            
            // email Key EAS-256
            if (aViewController.fromType == CCBKPasscodeFromCheckCryptoKey)
                [self sendMailEncryptPass];
            
            // change simply
            if (aViewController.fromType == CCBKPasscodeFromSimply) {
                
                // disable passcode
                [CCUtility setBlockCode:@""];
                [CCCoreData setAllDirectoryUnLockForAccount:app.activeAccount];
                CCMain *mainVC = [app.listMainVC objectForKey:app.serverUrl];
                if (mainVC)
                    [mainVC.tableView reloadData];
                
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

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Utility ==
#pragma --------------------------------------------------------------------------------------------

- (void)emptyGroupApplicationSupport
{
    NSString *file;
    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:capabilitiesGroups];
    NSString *dirIniziale = [[dirGroup URLByAppendingPathComponent:appApplicationSupport] path];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
    
    while (file = [enumerator nextObject])
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
}

- (void)emptyLibraryDirectory
{
    NSString *file;
    NSString *dirIniziale;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    dirIniziale = [paths objectAtIndex:0];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
    
    while (file = [enumerator nextObject])
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
}

- (void)emptyDocumentsDirectory
{
    NSString *file;
    NSString *dirIniziale;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    dirIniziale = [paths objectAtIndex:0];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
    
    while (file = [enumerator nextObject])
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
}

- (void)emptyUserDirectoryUser:(NSString *)user url:(NSString *)url
{
    NSString *file;
    NSString *dirIniziale;
    
    dirIniziale = [CCUtility getDirectoryActiveUser:user activeUrl:url];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
    
    while (file = [enumerator nextObject]) {
        
        /*
        if (removeICO == NO) {
            
            NSString *ext = [[file pathExtension] lowercaseString];
            
            if ([ext isEqualToString:@"ico"] && [file rangeOfString:@"ID_UPLOAD_"].location == NSNotFound) continue;
        }
        */
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
    }
}

- (void)emptyLocalDirectory
{
    NSString *file;
    NSString *dirIniziale;
    
    dirIniziale = [CCUtility getDirectoryLocal];
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:dirIniziale];
    
    while (file = [enumerator nextObject])
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", dirIniziale, file] error:nil];
}

- (NSNumber *)getUserDirectorySize
{
    NSString *directoryUser = [CCUtility getDirectoryActiveUser:app.activeUser activeUrl:app.activeUrl];
    NSURL *directoryURL = [NSURL fileURLWithPath:directoryUser];
    unsigned long long count = 0;
    NSNumber *value = nil;
    
    if (! directoryURL) return 0;
    
    // Get dimension Document
    for (NSURL *url in [[NSFileManager defaultManager] enumeratorAtURL:directoryURL includingPropertiesForKeys:@[NSURLFileSizeKey] options:0 errorHandler:NULL]) {
        if ([url getResourceValue:&value forKey:NSURLFileSizeKey error:nil]) {
            count += [value longLongValue];
        } else {
            return nil;
        }
    }
    
    return @(count);
}

- (void)copyDirGroupToLocal:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];

    NSURL *dirGroup = [[NSFileManager defaultManager] containerURLForSecurityApplicationGroupIdentifier:capabilitiesGroups];
    dirGroup = [dirGroup URLByAppendingPathComponent:@"Library"];
    dirGroup = [dirGroup URLByAppendingPathComponent:@"Application Support"];
    dirGroup = [dirGroup URLByAppendingPathComponent:@"Crypto Cloud"];

    NSArray *paths = [[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask];
    NSURL *destination = [[paths lastObject] URLByAppendingPathComponent:@"group"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"hh:mm:ss";
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    
    NSLog(@"[LOG] Open HUD %@",[dateFormatter stringFromDate:[NSDate date]]);
    
    [self.hud visibleIndeterminateHud];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
    
        NSLog(@"[LOG] Init copy %@",[dateFormatter stringFromDate:[NSDate date]]);
        
        [[NSFileManager defaultManager] removeItemAtURL:destination error:nil];
    
        NSError *copyError = nil;
        if (![[NSFileManager defaultManager] copyItemAtURL:dirGroup toURL:destination error:&copyError]) {
            NSLog(@"[LOG] Error copying files: %@", [copyError localizedDescription]);
        }
        
        NSLog(@"[LOG] Fine copy %@",[dateFormatter stringFromDate:[NSDate date]]);
        [self.hud hideHud];
    });
}

@end

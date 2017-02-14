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
    
    if (!app.isCryptoCloudMode) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"activate_cryptocloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_activation_crypto_cloud_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:image_settingsCryptoCloud] forKey:@"imageView.image"];
        row.action.formSelector = @selector(activateCryptoCloud:);
        [section addFormRow:row];
    }
    
    if (app.isCryptoCloudMode) {
        
        // Send aes-256 password via mail
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"sendmailencryptpass" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_encryptpass_by_email_", nil)];
        [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:COLOR_ENCRYPTED forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:image_settingsKeyMail] forKey:@"imageView.image"];
        row.action.formSelector = @selector(checkEncryptPass:);
        [section addFormRow:row];
    }

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
}

- (void)activateCryptoCloud:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
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

@end

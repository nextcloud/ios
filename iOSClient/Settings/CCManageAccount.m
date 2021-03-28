//
//  CCManageAccount.m
//  Nextcloud
//
//  Created by Marino Faggiana on 12/03/15.
//  Copyright (c) 2015 Marino Faggiana. All rights reserved.
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

#import "CCManageAccount.h"
#import "NSNotificationCenter+MainThread.h"
#import "NCBridgeSwift.h"
#import "CCUtility.h"

#define actionSheetCancellaAccount 1

@interface CCManageAccount ()
{
    AppDelegate *appDelegate;
}
@end

@implementation CCManageAccount

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
        
    NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
    tableAccount *accountActive = [[NCManageDatabase shared] getAccountActive];

    // Section : ACCOUNTS -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_accounts_", nil)];
    [form addFormSection:section];
    
    for (tableAccount *account in accounts) {
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", account.user, [NSURL URLWithString:account.urlBase].host];
        row = [XLFormRowDescriptor formRowDescriptorWithTag:account.account rowType:XLFormRowDescriptorTypeBooleanCheck title:title];
        
        // Avatar
        NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@-%@.png", [CCUtility getDirectoryUserData], [CCUtility getStringUser:account.user urlBase:account.urlBase], account.user];
        UIImage *avatar = [UIImage imageWithContentsOfFile:fileNamePath];
        if (avatar) {
            avatar = [[NCUtility shared] createAvatarWithImage:avatar size:30];
        } else {
            avatar = [[UIImage imageNamed:@"avatar"] imageWithColor:NCBrandColor.shared.icon size:30];
        }
        
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:13.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:avatar forKey:@"imageView.image"];
        if (account.active) {
            row.value = @"YES";
        }
        [section addFormRow:row];
    }

    // Section : ALIAS --------------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_alias_", nil)];
    section.footerTitle = NSLocalizedString(@"_alias_footer_", nil);
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"alias" rowType:XLFormRowDescriptorTypeAccount];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textField.font"];
    [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textField.textColor"];
    row.value = accountActive.alias;
    [section addFormRow:row];
    
    // Section : REQUEST ACCOUNT -------------------------------------------
    
    if (NCBrandOptions.shared.disable_request_account == NO) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_account_request_", nil)];
        [form addFormSection:section];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"accountRequest" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_settings_account_request_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[[UIImage imageNamed:@"users"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        if ([CCUtility getAccountRequest]) row.value = @1;
        else row.value = @0;
        [section addFormRow:row];
    }
    
    // Section : MANAGE ACCOUNT -------------------------------------------
    
    if ([NCBrandOptions shared].disable_manage_account == NO) {
        
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_manage_account_", nil)];
        [form addFormSection:section];
        
        // Brand
        if ([NCBrandOptions shared].disable_multiaccount == NO) {
            
            // New Account nextcloud
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_add_account_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[[UIImage imageNamed:@"plus"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(addAccount:);
            [section addFormRow:row];
        }
        
        // remove Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_delete_account_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"trash"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(deleteAccount:);
        if (accounts.count == 0) row.disabled = @YES;
        [section addFormRow:row];
        
#if TARGET_OS_SIMULATOR
        // Set user status
        if (@available(iOS 13.0, *)) {
            BOOL userStatus = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:accountActive.account elements:NCElementsJSON.shared.capabilitiesUserStatusEnabled exists:false];
            if (userStatus) {
                row = [XLFormRowDescriptor formRowDescriptorWithTag:@"setUserStatus" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_set_user_status_", nil)];
                row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
                [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
                [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
                [row.cellConfig setObject:[[UIImage imageNamed:@"userStatusAway"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
                [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
                row.action.formSelector = @selector(setUserStatus:);
                if (accounts.count == 0) row.disabled = @YES;
                [section addFormRow:row];
            }
        }
#endif
    }
    
    // Section : USER INFORMATION -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_personal_information_", nil)];
    [form addFormSection:section];
    
    // Full Name
    if ([accountActive.displayName length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userfullname" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_full_name_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"user"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.displayName;
        [section addFormRow:row];
    }
    
    // Address
    if ([accountActive.address length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useraddress" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_address_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"address"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.address;
        [section addFormRow:row];
    }
    
    // City + zip
    if ([accountActive.city length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercity" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_city_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"city"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.city;
        if ([accountActive.zip length] > 0) {
            row.value = [NSString stringWithFormat:@"%@ %@", row.value, accountActive.zip];
        }
        [section addFormRow:row];
    }
    
    // Country
    if ([accountActive.country length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercountry" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_country_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"country"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = [[NSLocale systemLocale] displayNameForKey:NSLocaleCountryCode value:accountActive.country];
        //NSArray *countryCodes = [NSLocale ISOCountryCodes];
        [section addFormRow:row];
    }
    
    // Phone
    if ([accountActive.phone length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userphone" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_phone_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"phone"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.phone;
        [section addFormRow:row];
    }
    
    // Email
    if ([accountActive.email length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useremail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_email_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"email"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.email;
        [section addFormRow:row];
    }
    
    // Web
    if ([accountActive.webpage length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userweb" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_web_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"network"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.webpage;
        [section addFormRow:row];
    }
    
    // Twitter
    if ([accountActive.twitter length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usertwitter" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_twitter_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"twitter"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.twitter;
        [section addFormRow:row];
    }
    
    // Section : THIRT PART -------------------------------------------
    BOOL isHandwerkcloudEnabled = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:accountActive.account elements:NCElementsJSON.shared.capabilitiesHWCEnabled exists:false];
    if (isHandwerkcloudEnabled) {

        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_user_job_", nil)];
        [form addFormSection:section];
        
        // Business Type
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesstype" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesstype_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"businesstype"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.businessType;
        [section addFormRow:row];
        
        // Business Size
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesssize" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesssize_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"users"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.businessSize;
        [section addFormRow:row];
        
        // Role
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userrole" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_role_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"role"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        if ([accountActive.role isEqualToString:@"owner"]) row.value = NSLocalizedString(@"_user_owner_", nil);
        else if ([accountActive.role isEqualToString:@"employee"]) row.value = NSLocalizedString(@"_user_employee_", nil);
        else if ([accountActive.role isEqualToString:@"contractor"]) row.value = NSLocalizedString(@"_user_contractor_", nil);
        else row.value = @"";
        [section addFormRow:row];
        
        // Company
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercompany" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_company_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"company"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        row.value = accountActive.company;
        [section addFormRow:row];
    
        if (accountActive.hcIsTrial) {
        
            section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_trial_", nil)];
            [form addFormSection:section];
            
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"trial" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_trial_expired_day_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"detailTextLabel.textColor"];
            [row.cellConfig setObject:[[UIImage imageNamed:@"timer"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
            NSInteger numberOfDays = accountActive.hcTrialRemainingSec / (24*3600);
            row.value = [@(numberOfDays) stringValue];
            [section addFormRow:row];
        }
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Edit profile
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"editUserProfile" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_user_editprofile_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundView;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"editUserProfile"] imageWithColor:NCBrandColor.shared.icon size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        #if defined(HC)
        row.action.viewControllerClass = [HCEditProfile class];
        #endif
        if (accounts.count == 0) row.disabled = @YES;
        [section addFormRow:row];
    }
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
    
    // Open Login
    if (accounts.count == 0) {
        [appDelegate openLoginWithViewController:self selector:NCGlobal.shared.introLogin openLoginWeb:false];
    }
}

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_credentials_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:NCGlobal.shared.notificationCenterChangeTheming object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain) name:NCGlobal.shared.notificationCenterInitializeMain object:nil];
    
    [self changeTheming];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    appDelegate.activeViewController = self;
    
    [self initializeForm];
    [self.tableView reloadData];
}

#pragma mark - NotificationCenter

- (void)changeTheming
{
    self.view.backgroundColor = NCBrandColor.shared.backgroundForm;
    self.tableView.backgroundColor = NCBrandColor.shared.backgroundForm;
    [self.tableView reloadData];
    [self initializeForm];
}

- (void)initializeMain
{
    [self initializeForm];
    [self.tableView reloadData];
}

#pragma mark -

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
    tableAccount *accountActive = [[NCManageDatabase shared] getAccountActive];

    for (tableAccount *account in accounts) {
        if ([rowDescriptor.tag isEqualToString:account.account]) {
            if (![account.account isEqualToString:accountActive.account]) {
                [self ChangeDefaultAccount:account.account];
                [self initializeForm];
            }
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"accountRequest"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setAccountRequest:true];
        } else {
            [CCUtility setAccountRequest:false];
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"alias"]) {
        if ([newValue isEqual:[NSNull null]]) {
            [[NCManageDatabase shared] setAccountAlias:@""];
        } else {
            [[NCManageDatabase shared] setAccountAlias:newValue];
        }
    }
}

#pragma mark -

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [appDelegate openLoginWithViewController:self selector:NCGlobal.shared.introLogin openLoginWeb:false];
}

#pragma mark -

- (void)deleteAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_want_delete_",nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        tableAccount *accountActive = [[NCManageDatabase shared] getAccountActive];
        NSString *account = accountActive.account;
        
        if (account) {
            [appDelegate deleteAccount:account wipe:false];
        }
        
        NSArray *listAccount = [[NCManageDatabase shared] getAccounts];
        if ([listAccount count] > 0) {
            [self ChangeDefaultAccount:listAccount[0]];
        } else {
            [self initializeForm];
        }
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
        
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark -

- (void)setUserStatus:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    if (@available(iOS 13.0, *)) {
        UIViewController *userStatusViewController = [[NCUserStatusViewController new] makeUserStatusUI];
        [self presentViewController:userStatusViewController animated:YES completion:nil];
    }
}

#pragma mark -

- (void)ChangeDefaultAccount:(NSString *)account
{
    tableAccount *tableAccount = [[NCManageDatabase shared] setAccountActive:account];
    if (tableAccount) {
        
        [[NCOperationQueue shared] cancelAllQueue];
        [[NCNetworking shared] cancelAllTask];
        
        [appDelegate settingAccount:tableAccount.account urlBase:tableAccount.urlBase user:tableAccount.user userId:tableAccount.userId password:[CCUtility getPassword:tableAccount.account]];
 
        // Init home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCGlobal.shared.notificationCenterInitializeMain object:nil userInfo:nil];
    }
}

@end

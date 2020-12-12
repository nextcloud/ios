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
#import "AppDelegate.h"
#import "CCLogin.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"

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
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:account.account rowType:XLFormRowDescriptorTypeBooleanCheck title:account.account];
        // Avatar
        NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@-%@.png", [CCUtility getDirectoryUserData], [CCUtility getStringUser:account.user urlBase:account.urlBase], account.user];
        UIImage *avatar = [UIImage imageWithContentsOfFile:fileNamePath];
        if (avatar) {
            
            avatar = [CCGraphics scaleImage:avatar toSize:CGSizeMake(35, 35) isAspectRation:YES];
            NCAvatar *avatarImageView = [[NCAvatar alloc] initWithImage:avatar borderColor:[UIColor lightGrayColor] borderWidth:0.5];
                        
            CGSize imageSize = avatarImageView.bounds.size;
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, UIScreen.mainScreen.scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [avatarImageView.layer renderInContext:context];
            avatar = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
        } else {
            avatar = [CCGraphics scaleImage:[UIImage imageNamed:@"avatarBN"] toSize:CGSizeMake(35, 35) isAspectRation:YES];
        }
        
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:13.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:avatar forKey:@"imageView.image"];
        if (account.active) {
            row.value = @"YES";
        }
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
            row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"add"] multiplier:2 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(addAccount:);
            [section addFormRow:row];
        }
        
        // remove Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_delete_account_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color: NCBrandColor.shared.icon] forKey:@"imageView.image"];
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
                row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
                [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
                [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
                [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"userStatusAway"] width:50 height:50 color: NCBrandColor.shared.icon] forKey:@"imageView.image"];
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
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"user"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.displayName;
        [section addFormRow:row];
    }
    
    // Address
    if ([accountActive.address length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useraddress" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_address_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"address"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.address;
        [section addFormRow:row];
    }
    
    // City + zip
    if ([accountActive.city length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercity" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_city_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"city"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.city;
        if ([accountActive.zip length] > 0) {
            row.value = [NSString stringWithFormat:@"%@ %@", row.value, accountActive.zip];
        }
        [section addFormRow:row];
    }
    
    // Country
    if ([accountActive.country length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercountry" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_country_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"country"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = [[NSLocale systemLocale] displayNameForKey:NSLocaleCountryCode value:accountActive.country];
        //NSArray *countryCodes = [NSLocale ISOCountryCodes];
        [section addFormRow:row];
    }
    
    // Phone
    if ([accountActive.phone length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userphone" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_phone_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"phone"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.phone;
        [section addFormRow:row];
    }
    
    // Email
    if ([accountActive.email length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useremail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_email_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"email"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.email;
        [section addFormRow:row];
    }
    
    // Web
    if ([accountActive.webpage length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userweb" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_web_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"web"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.webpage;
        [section addFormRow:row];
    }
    
    // Twitter
    if ([accountActive.twitter length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usertwitter" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_twitter_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"twitter"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
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
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"businesstype"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.businessType;
        [section addFormRow:row];
        
        // Business Size
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesssize" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesssize_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"users"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.businessSize;
        [section addFormRow:row];
        
        // Role
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userrole" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_role_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"role"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        if ([accountActive.role isEqualToString:@"owner"]) row.value = NSLocalizedString(@"_user_owner_", nil);
        else if ([accountActive.role isEqualToString:@"employee"]) row.value = NSLocalizedString(@"_user_employee_", nil);
        else if ([accountActive.role isEqualToString:@"contractor"]) row.value = NSLocalizedString(@"_user_contractor_", nil);
        else row.value = @"";
        [section addFormRow:row];
        
        // Company
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercompany" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_company_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:NCBrandColor.shared.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"company"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
        row.value = accountActive.company;
        [section addFormRow:row];
    
        if (accountActive.hcIsTrial) {
        
            section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_trial_", nil)];
            [form addFormSection:section];
            
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"trial" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_trial_expired_day_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"detailTextLabel.textColor"];
            [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"timer"] width:50 height:50 color:[UIColor redColor]] forKey:@"imageView.image"];
            NSInteger numberOfDays = accountActive.hcTrialRemainingSec / (24*3600);
            row.value = [@(numberOfDays) stringValue];
            [section addFormRow:row];
        }
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Edit profile
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"editUserProfile" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_user_editprofile_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.shared.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"editUserProfile"] width:50 height:50 color:NCBrandColor.shared.icon] forKey:@"imageView.image"];
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
        [appDelegate openLoginView:self selector:NCBrandGlobal.shared.introLogin openLoginWeb:false];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_credentials_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // changeTheming
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:NCBrandGlobal.shared.notificationCenterChangeTheming object:nil];
    
    [self changeTheming];
}

- (void)changeTheming
{
    self.view.backgroundColor = NCBrandColor.shared.backgroundForm;
    self.tableView.backgroundColor = NCBrandColor.shared.backgroundForm;
    [self.tableView reloadData];
    [self initializeForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate ===
#pragma --------------------------------------------------------------------------------------------

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
    tableAccount *accountActive = [[NCManageDatabase shared] getAccountActive];

    for (tableAccount *account in accounts) {
        if ([rowDescriptor.tag isEqualToString:account.account]) {
            if (![account.account isEqualToString:accountActive.account]) {
                [self ChangeDefaultAccount:account.account];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Add Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [appDelegate openLoginView:self selector:NCBrandGlobal.shared.introLogin openLoginWeb:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delete Account  ===
#pragma --------------------------------------------------------------------------------------------

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

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Set User Status  ===
#pragma --------------------------------------------------------------------------------------------

- (void)setUserStatus:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    if (@available(iOS 13.0, *)) {
        UIViewController *userStatusViewController = [[NCUserStatusViewController new] makeUserStatusUI];
        [self presentViewController:userStatusViewController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Change Default Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)ChangeDefaultAccount:(NSString *)account
{
    tableAccount *tableAccount = [[NCManageDatabase shared] setAccountActive:account];
    if (tableAccount) {
        
        [appDelegate settingAccount:tableAccount.account urlBase:tableAccount.urlBase user:tableAccount.user userID:tableAccount.userID password:[CCUtility getPassword:tableAccount.account]];
 
        // Init home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:NCBrandGlobal.shared.notificationCenterInitializeMain object:nil userInfo:nil];
    }
    
    [self initializeForm];
}

@end

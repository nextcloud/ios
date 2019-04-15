//
//  CCManageAccount.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 12/03/15.
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

#import <JDStatusBarNotification/JDStatusBarNotification.h>
#import "CCManageAccount.h"
#import "AppDelegate.h"
#import "CCLogin.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"

#define actionSheetCancellaAccount 1

@interface CCManageAccount () <CCLoginDelegate, CCLoginDelegateWeb>
{
    AppDelegate *appDelegate;
}
@end

@implementation CCManageAccount

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    if (self) {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_credentials_", nil)];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
        
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];

    // Section : ACCOUNTS -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_accounts_", nil)];
    [form addFormSection:section];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"pickerAccount" rowType:XLFormRowDescriptorTypePicker];
    row.height = 100;
    if (listAccount.count > 0) {
        row.selectorOptions = listAccount;
        row.value = tableAccount.account;
    } else {
        row.selectorOptions = [[NSArray alloc] initWithObjects:@"", nil];
    }
    
    // Avatar
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@-%@.png", [CCUtility getDirectoryUserData], [CCUtility getStringUser:appDelegate.activeUser activeUrl:appDelegate.activeUrl], appDelegate.activeUser];
    
    UIImage *avatar = [UIImage imageWithContentsOfFile:fileNamePath];
    if (avatar) {
        
        avatar = [CCGraphics scaleImage:avatar toSize:CGSizeMake(40, 40) isAspectRation:YES];
        
        CCAvatar *avatarImageView = [[CCAvatar alloc] initWithImage:avatar borderColor:[UIColor lightGrayColor] borderWidth:0.5];
        
        CGSize imageSize = avatarImageView.bounds.size;
        UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [avatarImageView.layer renderInContext:context];
        avatar = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
    } else {
        avatar = [UIImage imageNamed:@"avatarBN"];
    }
    
    [row.cellConfig setObject:avatar forKey:@"imageView.image"];
    [section addFormRow:row];

    // Section : USER INFORMATION -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_personal_information_", nil)];
    [form addFormSection:section];
    
    // Full Name
    if ([tableAccount.displayName length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userfullname" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_full_name_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.displayName;
        [section addFormRow:row];
    }
    
    // Address
    if ([tableAccount.address length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useraddress" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_address_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.address;
        [section addFormRow:row];
    }
    
    // City
    if ([tableAccount.city length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercity" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_city_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.city;
        [section addFormRow:row];
    }
    
    // Country
    if ([tableAccount.country length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercity" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_country_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.country;
        [section addFormRow:row];
    }
    
    // Zip
    if ([tableAccount.zip length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userzip" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_zip_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.zip;
        [section addFormRow:row];
    }
    
    // Phone
    if ([tableAccount.phone length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userphone" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_phone_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.phone;
        [section addFormRow:row];
    }
    
    // Email
    if ([tableAccount.email length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useremail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_email_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.email;
        [section addFormRow:row];
    }
    
    // Web
    if ([tableAccount.webpage length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userweb" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_web_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.webpage;
        [section addFormRow:row];
    }
    
    // Twitter
    if ([tableAccount.twitter length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usertwitter" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_twitter_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.twitter;
        [section addFormRow:row];
    }
    
    // Section : THIRT PART -------------------------------------------

    if ([NCBrandOptions.sharedInstance.brandInitials isEqualToString:@"hc"]) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_user_job_", nil)];
        [form addFormSection:section];
        
        // Business Type
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesstype" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesstype_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.businessType;
        [section addFormRow:row];
        
        // Business Size
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesssize" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesssize_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        switch ((int)tableAccount.businessSize) {
            case 1:
                row.value = @"1-4";
                break;
            case 5:
                row.value = @"5-9";
                break;
            case 10:
                row.value = @"10-19";
                break;
            case 20:
                row.value = @"20-49";
                break;
            case 50:
                row.value = @"50-99";
                break;
            case 100:
                row.value = @"100-249";
                break;
            case 250:
                row.value = @"250-499";
                break;
            case 500:
                row.value = @"500-999";
                break;
            case 1000:
                row.value = @"1000+";
                break;
            default:
                row.value = @"";
        }
        [section addFormRow:row];
        
        // Role
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userrole" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_role_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        if ([tableAccount.role isEqualToString:@"owner"]) row.value = NSLocalizedString(@"_user_owner_", nil);
        else if ([tableAccount.role isEqualToString:@"employee"]) row.value = NSLocalizedString(@"_user_employee_", nil);
        else if ([tableAccount.role isEqualToString:@"contractor"]) row.value = NSLocalizedString(@"_user_contractor_", nil);
        else row.value = @"";
        [section addFormRow:row];
        
        // Company
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercompany" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_company_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"detailTextLabel.font"];
        row.value = tableAccount.company;
        [section addFormRow:row];
    }
    
    // Section : MANAGE ACCOUNT -------------------------------------------
    
    if ([NCBrandOptions sharedInstance].disable_manage_account == NO) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_manage_account_", nil)];
        [form addFormSection:section];
    
        // Modify Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"changePassword" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_change_password_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"rename"] multiplier:2 color:[NCBrandColor sharedInstance].icon] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
        row.action.formSelector = @selector(changePassword:);
        if (listAccount.count == 0) row.disabled = @YES;
        [section addFormRow:row];

        // Brand
        if ([NCBrandOptions sharedInstance].disable_multiaccount == NO) {
    
            // New Account nextcloud
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_add_account_", nil)];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
            [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"add"] multiplier:2 color:[NCBrandColor sharedInstance].icon] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(addAccount:);
            [section addFormRow:row];
        }
    
        // delete Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_delete_account_", nil)];
        [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:[UIColor redColor]] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(deleteAccount:);
        if (listAccount.count == 0) row.disabled = @YES;
        [section addFormRow:row];
    }
    
    self.form = form;
    
    // Open Login
    if (listAccount.count == 0) {
        [appDelegate openLoginView:self delegate:self loginType:k_login_Add_Forced selector:k_intro_login];
    }
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
 
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].backgroundView;
    self.tableView.showsVerticalScrollIndicator = NO;

    // Color
    [appDelegate aspectNavigationControllerBar:self.navigationController.navigationBar online:[appDelegate.reachability isReachable] hidden:NO];
    [appDelegate aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self initializeForm];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate ===
#pragma --------------------------------------------------------------------------------------------

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"pickerAccount"] && oldValue && newValue) {
        
        if (![newValue isEqualToString:oldValue] && ![newValue isEqualToString:@""] && ![newValue isEqualToString:appDelegate.activeAccount]) {
            [self ChangeDefaultAccount:newValue];
        }
        
        if ([newValue isEqualToString:@""]) {
            NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
            if ([listAccount count] > 0) {
                [self ChangeDefaultAccount:listAccount[0]];
            }
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate Login ===
#pragma --------------------------------------------------------------------------------------------

- (void)loginSuccess:(NSInteger)loginType
{
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Add Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [appDelegate openLoginView:self delegate:self loginType:k_login_Add selector:k_intro_login];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Modify Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)changePassword:(XLFormRowDescriptor *)sender
{    
    [self deselectFormRow:sender];
    
    [appDelegate openLoginView:self delegate:self loginType:k_login_Modify_Password selector:k_intro_login];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delete Account  ===
#pragma --------------------------------------------------------------------------------------------

- (void)deleteAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_want_delete_",nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
        
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", pickerAccount.rowDescriptor.value]];
        
        if (tableAccount) {
            
            [appDelegate unsubscribingNextcloudServerPushNotification:tableAccount.account url:tableAccount.url withSubscribing:false];
        
            [[NCManageDatabase sharedInstance] clearTable:[tableAccount class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableActivity class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableActivitySubjectRich class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableCapabilities class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableDirectory class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableE2eEncryption class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableExternalSites class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableLocalFile class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableMetadata class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableMedia class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:tableAccount.account];
            [[NCManageDatabase sharedInstance] clearTable:[tableShare class] account:tableAccount.account];
        
            // Clear active user
            [appDelegate settingActiveAccount:nil activeUrl:nil activeUser:nil activeUserID:nil activePassword:nil];
        }
        
        NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
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
#pragma mark === Change Default Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)ChangeDefaultAccount:(NSString *)account
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:account];
    if (tableAccount) {
        
        [appDelegate settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:[CCUtility getPassword:tableAccount.account]];
 
        // Init home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
    }
    
    [self initializeForm];
}

@end

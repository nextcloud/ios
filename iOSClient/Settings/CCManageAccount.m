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
    tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];

    // Section : ACCOUNTS -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_accounts_", nil) sectionOptions:XLFormSectionOptionCanDelete];
    [form addFormSection:section];
    
    for (tableAccount *account in accounts) {
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", account.user, [NSURL URLWithString:account.urlBase].host];
        row = [XLFormRowDescriptor formRowDescriptorWithTag:account.account rowType:XLFormRowDescriptorTypeBooleanCheck title:title];
        
        // Avatar
        UIImage *avatar = [[NCUtility shared] loadUserImageFor:account.user displayName:account.displayName userBaseUrl:account];
        
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
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
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"alias" rowType:XLFormRowDescriptorTypeText];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[[UIImage imageNamed:@"form-textbox"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textField.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textField.textColor"];
    row.value = activeAccount.alias;
    [section addFormRow:row];
    
    // Section : MANAGE ACCOUNT -------------------------------------------
    
    if ([NCBrandOptions shared].disable_manage_account == NO) {
        
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_manage_account_", nil)];
        [form addFormSection:section];
        
        if ([NCBrandOptions shared].disable_multiaccount == NO) {
            
            // New Account nextcloud
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_add_account_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[[UIImage imageNamed:@"plus"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(addAccount:);
            [section addFormRow:row];
        }
        
        // Set user status
        
        BOOL userStatus = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:activeAccount.account elements:NCElementsJSON.shared.capabilitiesUserStatusEnabled exists:false];
        if (userStatus) {
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"setUserStatus" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_set_user_status_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
            [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[[UIImage imageNamed:@"userStatusAway"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            row.action.formSelector = @selector(setUserStatus:);
            if (accounts.count == 0) row.disabled = @YES;
            [section addFormRow:row];
        }
        
        if ([NCBrandOptions shared].disable_multiaccount == NO) {
            
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"accountRequest" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_settings_account_request_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
            [row.cellConfig setObject:[[UIImage imageNamed:@"users"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
            if ([CCUtility getAccountRequest]) row.value = @1;
            else row.value = @0;
            [section addFormRow:row];
        }
    }
    
    // Section : CERIFICATES -------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_certificates_", nil)];
    [form addFormSection:section];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"certificateDetails" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_certificate_details_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"lock"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(certificateDetails:);
    [section addFormRow:row];
        
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"certificatePNDetails" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_certificate_pn_details_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"lock"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    row.action.formSelector = @selector(certificatePNDetails:);
    [section addFormRow:row];
    
    // Section : USER INFORMATION -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_personal_information_", nil)];
    [form addFormSection:section];
    
    // Full Name
    if ([activeAccount.displayName length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userfullname" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_full_name_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"user"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.displayName;
        [section addFormRow:row];
    }
    
    // Address
    if ([activeAccount.address length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useraddress" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_address_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"address"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.address;
        [section addFormRow:row];
    }
    
    // City + zip
    if ([activeAccount.city length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercity" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_city_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"city"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.city;
        if ([activeAccount.zip length] > 0) {
            row.value = [NSString stringWithFormat:@"%@ %@", row.value, activeAccount.zip];
        }
        [section addFormRow:row];
    }
    
    // Country
    if ([activeAccount.country length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercountry" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_country_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"country"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = [[NSLocale systemLocale] displayNameForKey:NSLocaleCountryCode value:activeAccount.country];
        //NSArray *countryCodes = [NSLocale ISOCountryCodes];
        [section addFormRow:row];
    }
    
    // Phone
    if ([activeAccount.phone length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userphone" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_phone_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"phone"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.phone;
        [section addFormRow:row];
    }
    
    // Email
    if ([activeAccount.email length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"useremail" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_email_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"email"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.email;
        [section addFormRow:row];
    }
    
    // Web
    if ([activeAccount.website length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userweb" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_web_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"network"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.website;
        [section addFormRow:row];
    }
    
    // Twitter
    if ([activeAccount.twitter length] > 0) {
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usertwitter" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_twitter_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"twitter"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.twitter;
        [section addFormRow:row];
    }
    
    // Section : THIRT PART -------------------------------------------
    BOOL isHandwerkcloudEnabled = [[NCManageDatabase shared] getCapabilitiesServerBoolWithAccount:activeAccount.account elements:NCElementsJSON.shared.capabilitiesHWCEnabled exists:false];
    if (isHandwerkcloudEnabled) {

        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_user_job_", nil)];
        [form addFormSection:section];
        
        // Business Type
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesstype" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesstype_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"businesstype"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.businessType;
        [section addFormRow:row];
        
        // Business Size
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userbusinesssize" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_businesssize_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"users"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.businessSize;
        [section addFormRow:row];
        
        // Role
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"userrole" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_role_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"role"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        if ([activeAccount.role isEqualToString:@"owner"]) row.value = NSLocalizedString(@"_user_owner_", nil);
        else if ([activeAccount.role isEqualToString:@"employee"]) row.value = NSLocalizedString(@"_user_employee_", nil);
        else if ([activeAccount.role isEqualToString:@"contractor"]) row.value = NSLocalizedString(@"_user_contractor_", nil);
        else row.value = @"";
        [section addFormRow:row];
        
        // Company
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"usercompany" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_user_company_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"company"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        row.value = activeAccount.organisation;
        [section addFormRow:row];
    
        if (activeAccount.hcIsTrial) {
        
            section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_trial_", nil)];
            [form addFormSection:section];
            
            row = [XLFormRowDescriptor formRowDescriptorWithTag:@"trial" rowType:XLFormRowDescriptorTypeInfo title:NSLocalizedString(@"_trial_expired_day_", nil)];
            row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
            [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"detailTextLabel.font"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
            [row.cellConfig setObject:[UIColor redColor] forKey:@"detailTextLabel.textColor"];
            [row.cellConfig setObject:[[UIImage imageNamed:@"timer"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
            NSInteger numberOfDays = activeAccount.hcTrialRemainingSec / (24*3600);
            row.value = [@(numberOfDays) stringValue];
            [section addFormRow:row];
        }
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        
        // Edit profile
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"editUserProfile" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_user_editprofile_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"editUserProfile"] imageWithColor:UIColor.systemGrayColor size:25] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
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

// MARK: - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_credentials_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initialize) name:NCGlobal.shared.notificationCenterInitialize object:nil];
    
    [self initializeForm];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    appDelegate.activeViewController = self;
}

#pragma mark - NotificationCenter

- (void)initialize
{
    [self initializeForm];
}

#pragma mark -

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"accountRequest"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            [CCUtility setAccountRequest:true];
        } else {
            [CCUtility setAccountRequest:false];
        }
    }
    
    else if ([rowDescriptor.tag isEqualToString:@"alias"]) {
        
        if ([newValue isEqual:[NSNull null]]) {
            [[NCManageDatabase shared] setAccountAlias:@""];
        } else {
            [[NCManageDatabase shared] setAccountAlias:newValue];
        }
    }
    
    else {
        
        NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
        tableAccount *activeAccount = [[NCManageDatabase shared] getActiveAccount];

        for (tableAccount *account in accounts) {
            if ([rowDescriptor.tag isEqualToString:account.account]) {
                if (![account.account isEqualToString:activeAccount.account]) {
                    [appDelegate changeAccount:account.account];
                }
            }
        }
        
        [self initializeForm];
    }
}

-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    [super tableView:tableView commitEditingStyle:editingStyle forRowAtIndexPath:indexPath];
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
    
        [self initializeForm];
        
        NSArray *accounts = [[NCManageDatabase shared] getAllAccount];
        tableAccount *tableAccountForDelete = accounts[indexPath.row];
        tableAccount *tableActiveAccount = [[NCManageDatabase shared] getActiveAccount];
        
        NSString *accountForDelete = tableAccountForDelete.account;
        NSString *activeAccount = tableActiveAccount.account;

        NSString *title = [NSString stringWithFormat:NSLocalizedString(@"_want_delete_account_",nil), accountForDelete];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
                        
            if (accountForDelete) {
                [appDelegate deleteAccount:accountForDelete wipe:false];
            }
            
            NSArray *listAccount = [[NCManageDatabase shared] getAccounts];
            if ([listAccount count] > 0) {
                if ([accountForDelete isEqualToString:activeAccount]) {
                    [appDelegate changeAccount:listAccount[0]];
                }
            }
            
            [self initializeForm];
        }]];
        
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
        
        alertController.popoverPresentationController.sourceView = self.view;
        alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
            
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 60;
    } else {
        return NCGlobal.shared.heightCellSettings;
    }
}

#pragma mark -

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [appDelegate openLoginWithViewController:self selector:NCGlobal.shared.introLogin openLoginWeb:false];
}

#pragma mark -

- (void)setUserStatus:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCUserStatus" bundle:nil] instantiateInitialViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark -

- (void)certificateDetails:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCViewCertificateDetails" bundle:nil] instantiateInitialViewController];
    NCViewCertificateDetails *viewController = (NCViewCertificateDetails *)navigationController.topViewController;

    NSURL *url = [NSURL URLWithString:appDelegate.urlBase];
    viewController.host = [url host];
        
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)certificatePNDetails:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCViewCertificateDetails" bundle:nil] instantiateInitialViewController];
    NCViewCertificateDetails *viewController = (NCViewCertificateDetails *)navigationController.topViewController;
        
    NSURL *url = [NSURL URLWithString: NCBrandOptions.shared.pushNotificationServerProxy];
    viewController.host = [url host];

    [self presentViewController:navigationController animated:YES completion:nil];
}

@end

//
//  CCManageAccount.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 12/03/15.
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

#import "CCManageAccount.h"
#import "AppDelegate.h"
#import "JDStatusBarNotification.h"
#import "CCLogin.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"

#define actionSheetCancellaAccount 1

@interface CCManageAccount () <CCLoginDelegate, CCLoginDelegateWeb>
{
    AppDelegate *appDelegate;
    tableAccount *_tableAccount;
}
@end

@implementation CCManageAccount

-(id)init
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_credentials_", nil)];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];

    // Section : CLOUD ACCOUNT -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:@"cloud account"];
    [form addFormSection:section];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"pickerAccount" rowType:XLFormRowDescriptorTypePicker];
    row.height = 100;
    row.selectorOptions = listAccount;
    row.value = appDelegate.activeAccount;
    [section addFormRow:row];

    // Section : USER INFORMATION -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_personal_information_", nil)];
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
    
    // Section : MANAGE ACCOUNT -------------------------------------------
    
    if ([NCBrandOptions sharedInstance].disable_manage_account == NO) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_manage_account_", nil)];
        [form addFormSection:section];
    
        // Modify Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"changePassword" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_change_password_", nil)];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:@"settingsAccountModify"] forKey:@"imageView.image"];
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
            [row.cellConfig setObject:[UIImage imageNamed:@"settingsAccountNextcloud"] forKey:@"imageView.image"];
            [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
            [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
            row.action.formSelector = @selector(addAccount:);
            [section addFormRow:row];
        }
    
        // delete Account
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_delete_account_", nil)];
        if (listAccount.count > 0)
            [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [row.cellConfig setObject:[UIImage imageNamed:@"settingsAccountDelete"] forKey:@"imageView.image"];
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        row.action.formSelector = @selector(answerDelAccount:);
        if (listAccount.count == 0) row.disabled = @YES;
        [section addFormRow:row];
    }
    
    return [super initWithForm:form];
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
    
    [self UpdateForm];
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
        
        XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
        NSString *accountNow = pickerAccount.rowDescriptor.value;

        if (![newValue isEqualToString:oldValue] && ![newValue isEqualToString:@""] && ![newValue isEqualToString:appDelegate.activeAccount])
            [self ChangeDefaultAccount:newValue];
        
        if ([newValue isEqualToString:@""]) {
            
            NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];

            if ([listAccount count] > 0)
                [self ChangeDefaultAccount:listAccount[0]];
        }
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate Login ===
#pragma --------------------------------------------------------------------------------------------

- (void)loginSuccess:(NSInteger)loginType
{
    if (loginType == loginAddForced) {
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
    }
}

- (void)loginClose
{
    appDelegate.activeLogin = nil;
}

- (void)loginWebClose
{
    appDelegate.activeLoginWeb = nil;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Add Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    // Verify session in progress
    if ([[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionTaskIdentifier > 0", appDelegate.activeAccount] sorted:nil ascending:NO] count] > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [appDelegate openLoginView:self loginType:loginAdd];
    });
}

- (void)addAccountForced
{
    [appDelegate openLoginView:self loginType:loginAddForced];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Modify Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)changePassword:(XLFormRowDescriptor *)sender
{    
    [self deselectFormRow:sender];
    
    // Verify session in progress
    if ([[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionTaskIdentifier > 0", appDelegate.activeAccount] sorted:nil ascending:NO] count] > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [appDelegate openLoginView:self loginType:loginModifyPasswordUser];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delete Account  ===
#pragma --------------------------------------------------------------------------------------------

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
    
    [actionSheet dismissWithClickedButtonIndex:buttonIndex animated:YES];
    
    if (buttonIndex == 0 && actionSheet.tag == actionSheetCancellaAccount) {
        
        NSString *accountNow = pickerAccount.rowDescriptor.value;
        
        [self deleteAccount:accountNow];
        
        NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
        if ([listAccount count] > 0)
            [self ChangeDefaultAccount:listAccount[0]];
        else {
            [self addAccountForced];
        }
    }
}

- (void)deleteAccount:(NSString *)account
{
    // Verify session in progress
    if ([[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionTaskIdentifier > 0", appDelegate.activeAccount] sorted:nil ascending:NO] count] > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        [[NCManageDatabase sharedInstance] clearTable:[tableAccount class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableActivity class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableCapabilities class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableDirectory class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableE2eEncryption class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableExternalSites class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableLocalFile class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableMetadata class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tablePhotoLibrary class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableQueueDownload class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableQueueUpload class] account:account];
        [[NCManageDatabase sharedInstance] clearTable:[tableShare class] account:account];
    
        // Clear active user
        [appDelegate settingActiveAccount:nil activeUrl:nil activeUser:nil activeUserID:nil activePassword:nil];        
    });
}

- (void)answerDelAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIActionSheet *actionSheet1 = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"_want_delete_",nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"_no_delete_",nil)
                                                destructiveButtonTitle:NSLocalizedString(@"_yes_delete_",nil)
                                                     otherButtonTitles:nil];
    
    actionSheet1.tag = actionSheetCancellaAccount;
    [actionSheet1 showInView:self.view.window.rootViewController.view];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Change Default Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)ChangeDefaultAccount:(NSString *)account
{
    // Verify session in progress
    if ([[[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND sessionTaskIdentifier > 0", appDelegate.activeAccount] sorted:nil ascending:NO] count] > 0) {
        [JDStatusBarNotification showWithStatus:NSLocalizedString(@"_transfers_in_queue_", nil) dismissAfter:k_dismissAfterSecond styleName:JDStatusBarStyleDefault];
        return;
    }
    
    [appDelegate.netQueue cancelAllOperations];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{

        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:account];
        if (tableAccount) {
        
            [appDelegate settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:tableAccount.password];
 
            // Init home
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
            
            [self UpdateForm];
        }
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Update Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)UpdateForm
{
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    
    if (listAccount == nil) {
        [self addAccountForced];
        return;
    }
    
    XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
    
    pickerAccount.rowDescriptor.selectorOptions = listAccount;
    pickerAccount.rowDescriptor.value = appDelegate.activeAccount;
    
    UIImage *avatar = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/avatar.png", appDelegate.directoryUser]];
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
    
    
    [pickerAccount.rowDescriptor.cellConfig setObject:avatar forKey:@"imageView.image"];

    // --
    
    _tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    XLFormRowDescriptor *rowUserFullName = [self.form formRowWithTag:@"userfullname"];
    XLFormRowDescriptor *rowUserAddress = [self.form formRowWithTag:@"useraddress"];
    XLFormRowDescriptor *rowUserPhone = [self.form formRowWithTag:@"userphone"];
    XLFormRowDescriptor *rowUserEmail = [self.form formRowWithTag:@"useremail"];
    XLFormRowDescriptor *rowUserWeb = [self.form formRowWithTag:@"userweb"];
    XLFormRowDescriptor *rowUserTwitter = [self.form formRowWithTag:@"usertwitter"];

    rowUserFullName.value = _tableAccount.displayName;
    if ([_tableAccount.displayName isEqualToString:@""] || _tableAccount.displayName == nil) rowUserFullName.hidden = @YES;
    else rowUserFullName.hidden = @NO;
    
    rowUserAddress.value = _tableAccount.address;
    if ([_tableAccount.address isEqualToString:@""] || _tableAccount.address == nil) rowUserAddress.hidden = @YES;
    else rowUserAddress.hidden = @NO;
    
    rowUserPhone.value = _tableAccount.phone;
    if ([_tableAccount.phone isEqualToString:@""] || _tableAccount.phone == nil) rowUserPhone.hidden = @YES;
    else rowUserPhone.hidden = @NO;
    
    rowUserEmail.value = _tableAccount.email;
    if ([_tableAccount.email isEqualToString:@""] || _tableAccount.email == nil) rowUserEmail.hidden = @YES;
    else rowUserEmail.hidden = @NO;
    
    rowUserWeb.value = _tableAccount.webpage;
    if ([_tableAccount.webpage isEqualToString:@""] || _tableAccount.webpage == nil) rowUserWeb.hidden = @YES;
    else rowUserWeb.hidden = @NO;
    
    rowUserTwitter.value = _tableAccount.twitter;
    if ([_tableAccount.twitter isEqualToString:@""] || _tableAccount.twitter == nil) rowUserTwitter.hidden = @YES;
    else rowUserTwitter.hidden = @NO;

    [self.tableView reloadData];
    
    [self performSelector:@selector(reloadData) withObject:nil afterDelay:1];
}

- (void)reloadData
{
    [self.tableView reloadData];
}

@end

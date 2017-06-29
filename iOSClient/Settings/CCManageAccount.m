//
//  CCManageAccount.m
//  Crypto Cloud Technology Nextcloud
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
#import "CCLogin.h"
#import "NCBridgeSwift.h"

#define actionSheetCancellaAccount 1

@interface CCManageAccount () <CCLoginDelegate, CCLoginDelegateWeb>
{
    tableAccount *_tableAccount;

    CCLoginWeb *_loginWeb;
    CCLogin *_loginVC;
}
@end

@implementation CCManageAccount

-(id)init
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_credentials_", nil)];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];

    // Section : CLOUD ACCOUNT -------------------------------------------
    
    section = [XLFormSectionDescriptor formSectionWithTitle:@"cloud account"];
    [form addFormSection:section];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"pickerAccount" rowType:XLFormRowDescriptorTypePicker];
    row.height = 100;
    row.selectorOptions = listAccount;
    row.value = app.activeAccount;
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
 
    self.tableView.backgroundColor = [NCBrandColor sharedInstance].tableBackground;

    // Color
    [app aspectNavigationControllerBar:self.navigationController.navigationBar encrypted:NO online:[app.reachability isReachable] hidden:NO];
    [app aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    [self UpdateForm];
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [app changeTheming:self];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate ===
#pragma --------------------------------------------------------------------------------------------

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"pickerAccount"]){
        
        // cambiamo default account se oldvalue != newValue
        if (![newValue isEqualToString:oldValue]) [self ChangeDefaultAccount:newValue];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delegate Login ===
#pragma --------------------------------------------------------------------------------------------

- (void)loginSuccess:(NSInteger)loginType
{
    if (loginType == loginAddForced)
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Add Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)addAccount:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    // Brand
    if ([NCBrandOptions sharedInstance].use_login_web) {
    
        _loginWeb = [CCLoginWeb new];
        _loginWeb.delegate = self;
        _loginWeb.loginType = loginAdd;
    
        [_loginWeb presentModalWithDefaultTheme:self];
        
    } else {
  
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
        _loginVC.delegate = self;
        _loginVC.loginType = loginAdd;
    
        [self presentViewController:_loginVC animated:YES completion:nil];
    }
}

- (void)addAccountFoced
{
    // Brand
    if ([NCBrandOptions sharedInstance].use_login_web) {
    
        _loginWeb = [CCLoginWeb new];
        _loginWeb.delegate = self;
        _loginWeb.loginType = loginAddForced;
    
        dispatch_async(dispatch_get_main_queue(), ^ {
            [_loginWeb presentModalWithDefaultTheme:self];
        });
        
    } else {
        
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
        _loginVC.delegate = self;
        _loginVC.loginType = loginAddForced;
        
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self presentViewController:_loginVC animated:YES completion:nil];
        });
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Modify Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)changePassword:(XLFormRowDescriptor *)sender
{    
    [self deselectFormRow:sender];
    
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    // Brand
    if ([NCBrandOptions sharedInstance].use_login_web) {
    
        _loginWeb = [CCLoginWeb new];
        _loginWeb.delegate = self;
        _loginWeb.loginType = loginModifyPasswordUser;
    
        dispatch_async(dispatch_get_main_queue(), ^ {
            [_loginWeb presentModalWithDefaultTheme:self];
        });

    } else {
        
        _loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
        _loginVC.delegate = self;
        _loginVC.loginType = loginModifyPasswordUser;
    
        dispatch_async(dispatch_get_main_queue(), ^ {
            [self presentViewController:_loginVC animated:YES completion:nil];
        });
    }
    
    [self UpdateForm];
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
        if ([listAccount count] > 0) [self ChangeDefaultAccount:listAccount[0]];
        else {
            [self addAccountFoced];
        }
    }
}

- (void)deleteAccount:(NSString *)account
{
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    [[NCManageDatabase sharedInstance] clearTable:[tableAccount class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableActivity class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableAutoUpload class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableCapabilities class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableDirectory class] account:app.activeAccount];
    [[NCManageDatabase sharedInstance] clearTable:[tableExternalSites class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableLocalFile class] account:app.activeAccount];
    [[NCManageDatabase sharedInstance] clearTable:[tableMetadata class] account:account];
    [[NCManageDatabase sharedInstance] clearTable:[tableShare class] account:account];
    
    // Clear active user
    [app settingActiveAccount:nil activeUrl:nil activeUser:nil activePassword:nil];
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
    if ([app.netQueue operationCount] > 0 || [app.netQueueDownload operationCount] > 0 || [app.netQueueDownloadWWan operationCount] > 0 || [app.netQueueUpload operationCount] > 0 || [app.netQueueUploadWWan operationCount] > 0 || [[NCManageDatabase sharedInstance] countAutoUploadWithSession:nil] > 0) {
        
        [app messageNotification:@"_transfers_in_queue_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo errorCode:0];
        [self UpdateForm];
        return;
    }

    // removed  this -> ?????
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    // removed  this -> ?????
    
    // change account
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:account];
    if (tableAccount)
        [app settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password];
 
    // Init home
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil];
        
    [self UpdateForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Update Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)UpdateForm
{
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    
    if (listAccount == nil) {
        [self addAccountFoced];
        return;
    }
    
    XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
    
    pickerAccount.rowDescriptor.selectorOptions = listAccount;
    pickerAccount.rowDescriptor.value = app.activeAccount;
    
    UIImage *avatar = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/avatar.png", app.directoryUser]];
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

/*
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    XLFormRowDescriptor *row = [self.form formRowAtIndex:indexPath];
    
    if ([row.tag isEqualToString:@"pickerAccount"]) {
        // set background color in here
        
    }
}
*/

@end

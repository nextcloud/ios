//
//  CCManageAccount.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 12/03/15.
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

#import "CCManageAccount.h"
#import "AppDelegate.h"
#import "CCLogin.h"

#define actionSheetCancellaAccount 1

@implementation CCManageAccount

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(UpdateForm) name:@"updateFormManageAccount" object:nil];
        
        [self initializeForm];
    }
    
    return self;
}

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_credentials_", nil)];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    NSArray *listAccount = [CCCoreData getAllAccount];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:@"cloud account"];
    [form addFormSection:section];
    form.rowNavigationOptions = XLFormRowNavigationOptionNone;
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"pickerAccount" rowType:XLFormRowDescriptorTypePicker];
        
    row.selectorOptions = listAccount;
    row.value = app.activeAccount;
    [section addFormRow:row];
    
    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_manage_account_", nil)];
    [form addFormSection:section];
    
    // Modify Account
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"modifyAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_modify_account_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAccountModify] forKey:@"imageView.image"];
    row.action.formSelector = @selector(modifyAccount:);
    if (listAccount.count == 0) row.disabled = @YES;
    [section addFormRow:row];

    // New Account nextcloud
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"addAccountNextcloud" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_add_nextcloud_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAccountNextcloud] forKey:@"imageView.image"];
    row.action.formSelector = @selector(addAccountNextcloud:);
    [section addFormRow:row];
    
    // delete Account
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"delAccount" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_delete_account_", nil)];
    if (listAccount.count > 0) [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIImage imageNamed:image_settingsAccountDelete] forKey:@"imageView.image"];
    row.action.formSelector = @selector(answerDelAccount:);
    if (listAccount.count == 0) row.disabled = @YES;
    [section addFormRow:row];
    
    self.form = form;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];    
}

// E' apparsa
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self UpdateForm];
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
#pragma mark === Aggiungi Account ===
#pragma --------------------------------------------------------------------------------------------

/*** NEXTCLOUD ***/

- (void)addAccountNextcloud:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    CCLogin *loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
    
    [loginVC setModifyOnlyPassword:NO];
    [loginVC setTypeCloud:typeCloudNextcloud];
    
    [self presentViewController:loginVC animated:YES completion:nil];
}

- (void)openLoginSetupVC
{    
    // remove any message
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    CCLogin *viewController = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier:@"CCLoginNextcloud"];
    
    dispatch_async(dispatch_get_main_queue(), ^ {
        [self presentViewController:viewController animated:YES completion:nil];
    });
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Modify Account ===
#pragma --------------------------------------------------------------------------------------------

- (void)modifyAccount:(XLFormRowDescriptor *)sender
{
    NSString *vcName;
    
    [self deselectFormRow:sender];
    
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    
    if ([app.typeCloud isEqualToString:typeCloudNextcloud] || [app.typeCloud isEqualToString:typeCloudOwnCloud]) {
        
        CCLogin *loginVC = [[UIStoryboard storyboardWithName:@"CCLogin" bundle:nil] instantiateViewControllerWithIdentifier: @"CCLoginNextcloud"];
        
        [loginVC setModifyOnlyPassword:YES];
        [loginVC setTypeCloud:app.typeCloud];
        
        [self presentViewController:loginVC animated:YES completion:nil];
    }
    
    [self UpdateForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Delete Account  ===
#pragma --------------------------------------------------------------------------------------------

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
    
    NSString *accountNow = pickerAccount.rowDescriptor.value;
    NSArray *listAccount = [CCCoreData getAllAccount];
    
    [actionSheet dismissWithClickedButtonIndex:buttonIndex animated:YES];
    
    if (buttonIndex == 0 && actionSheet.tag == actionSheetCancellaAccount) {
        
        [app cancelAllOperations];
        
        [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];

        [self deleteAccount:accountNow];
        
        // Clear active user
        [app settingActiveAccount:nil activeUrl:nil activeUser:nil activePassword:nil activeUID:nil activeAccessToken:nil typeCloud:nil];
        
        listAccount = [CCCoreData getAllAccount];
        
        if ([listAccount count] > 0) [self ChangeDefaultAccount:listAccount[0]];
        else {
            [self openLoginSetupVC];
            return;
        }
    }
}

- (void)deleteAccount:(NSString *)account
{
    [CCCoreData deleteAccount:account];
        
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(account == %@)", account];
    
    [CCCoreData deleteMetadataWithPredicate:predicate];
    [CCCoreData deleteLocalFileWithPredicate:predicate];
    [CCCoreData deleteDirectoryFromPredicate:predicate];
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
    if ([app.netQueue operationCount] > 0 || [app.netQueueDownload operationCount] > 0 || [app.netQueueDownloadWWan operationCount] > 0 || [app.netQueueUpload operationCount] > 0 || [app.netQueueUploadWWan operationCount] > 0 || [CCCoreData countTableAutomaticUploadForAccount:app.activeAccount selector:nil] > 0) {
        
        [app messageNotification:@"_transfers_in_queue_" description:nil visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeInfo];
        [self UpdateForm];
        return;
    }

    // removed  this -> ?????
    [app cancelAllOperations];
    [[CCNetworking sharedNetworking] settingSessionsDownload:YES upload:YES taskStatus:k_taskStatusCancel activeAccount:app.activeAccount activeUser:app.activeUser activeUrl:app.activeUrl];
    // removed  this -> ?????
    
    // change account
    TableAccount *tableAccount = [CCCoreData setActiveAccount:account];
    if (tableAccount)
        [app settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password activeUID:tableAccount.uid activeAccessToken:tableAccount.token typeCloud:tableAccount.typeCloud];
 
    // Init home
    [[NSNotificationCenter defaultCenter] postNotificationName:@"initializeMain" object:nil];
        
    [self UpdateForm];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Update Form ===
#pragma --------------------------------------------------------------------------------------------

- (void)UpdateForm
{
    NSArray *listAccount = [CCCoreData getAllAccount];
    
    if (listAccount == nil) {
        [self openLoginSetupVC];
        return;
    }
    
    XLFormPickerCell *pickerAccount = (XLFormPickerCell *)[[self.form formRowWithTag:@"pickerAccount"] cellForFormController:self];
    
    pickerAccount.rowDescriptor.selectorOptions = listAccount;
    pickerAccount.rowDescriptor.value = app.activeAccount;
    
    [self.tableView reloadData];
    
    [self performSelector:@selector(reloadData) withObject:nil afterDelay:1];
}

- (void)reloadData
{
    [self.tableView reloadData];
}

@end

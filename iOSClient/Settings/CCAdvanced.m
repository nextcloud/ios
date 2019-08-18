//
//  CCManageHelp.m
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/15.
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

#import "CCAdvanced.h"
#import "CCUtility.h"
#import "AppDelegate.h"
#import <KTVHTTPCache/KTVHTTPCache.h>
#import "NCBridgeSwift.h"

@interface CCAdvanced ()
{
    AppDelegate *appDelegate;
}
@end

@implementation CCAdvanced

- (id)init
{
    XLFormDescriptor *form ;
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];
    
    form = [XLFormDescriptor formDescriptorWithTitle:NSLocalizedString(@"_advanced_", nil)];
    
    // Section HIDDEN FILES -------------------------------------------------

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"showHiddenFiles" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_show_hidden_files_", nil)];
    if ([CCUtility getShowHiddenFiles]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Format Compatibility
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_format_compatibility_footer_", nil);

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"formatCompatibility" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_format_compatibility_", nil)];
    if ([CCUtility getFormatCompatibility]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Disable Local Cache After Upload
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_disableLocalCacheAfterUpload_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"disableLocalCacheAfterUpload" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_disableLocalCacheAfterUpload_", nil)];
    if ([CCUtility getDisableLocalCacheAfterUpload]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [section addFormRow:row];
    
    // Section : Files App --------------------------------------------------------------
    
    if (![NCBrandOptions sharedInstance].disable_openin_file) {
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        section.footerTitle = NSLocalizedString(@"_disable_files_app_footer_", nil);

        // Disable Files App
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"disablefilesapp" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_disable_files_app_", nil)];
        if ([CCUtility getDisableFilesApp]) row.value = @"1";
        else row.value = @"0";
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
        [section addFormRow:row];
    }
    
    // Section : Privacy --------------------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_privacy_", nil)];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_privacy_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"crashservice" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_crashservice_title_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"crashservice"] width:50 height:50 color:[NCBrandColor sharedInstance].icon] forKey:@"imageView.image"];
    if ([CCUtility getDisableCrashservice]) row.value = @"1";
    else row.value = @"0";
    [section addFormRow:row];
    
    // Section CLEAR CACHE -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_clear_cache_footer_", nil);

    // Clear cache
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"azzeracache" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_clear_cache_", nil)];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[UIColor blackColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:[NCBrandColor sharedInstance].icon] forKey:@"imageView.image"];
    row.action.formSelector = @selector(clearCacheRequest:);
    [section addFormRow:row];

    // Section EXIT --------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_exit_footer_", nil);
    
    // Exit
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"esci" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_exit_", nil)];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0]forKey:@"textLabel.font"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"exit"] width:50 height:50 color:[UIColor redColor]] forKey:@"imageView.image"];
    row.action.formSelector = @selector(exitNextcloud:);
    [section addFormRow:row];

    return [super initWithForm:form];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
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
}

- (void)changeTheming
{
    if (self.isViewLoaded && self.view.window)
        [appDelegate changeTheming:self];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"showHiddenFiles"]) {
        
        [CCUtility setShowHiddenFiles:[[rowDescriptor.value valueData] boolValue]];
        
        // force reload
        [[NCManageDatabase sharedInstance] setClearAllDateReadDirectory];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"formatCompatibility"]) {
        
        [CCUtility setFormatCompatibility:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"disableLocalCacheAfterUpload"]) {
        
        [CCUtility setDisableLocalCacheAfterUpload:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"disablefilesapp"]) {
        
        [CCUtility setDisableFilesApp:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"crashservice"]) {
        
        [CCUtility setDisableCrashservice:[[rowDescriptor.value valueData] boolValue]];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_crashservice_title_", nil) message:NSLocalizedString(@"_crashservice_alert_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            exit(0);
        }];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Clear Cache ===
#pragma --------------------------------------------------------------------------------------------

- (void)clearCache
{
    [appDelegate maintenanceMode:YES];
    
    [self.hud visibleHudTitle:NSLocalizedString(@"_remove_cache_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC),dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [[NCMainCommon sharedInstance] cancelAllTransfer];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

            [[NSURLCache sharedURLCache] setMemoryCapacity:0];
            [[NSURLCache sharedURLCache] setDiskCapacity:0];
            [KTVHTTPCache cacheDeleteAllCaches];
            
            [[NCManageDatabase sharedInstance] clearDatabaseWithAccount:appDelegate.activeAccount removeUser:false];
            
            [CCUtility emptyGroupDirectoryProviderStorage];
            [CCUtility emptyGroupLibraryDirectory];
            
            [CCUtility emptyDocumentsDirectory];
            [CCUtility emptyTemporaryDirectory];
            
            [CCUtility createDirectoryStandard];

            [[NCAutoUpload sharedInstance] alignPhotoLibrary];
            [appDelegate.filterocId removeAllObjects];

            [appDelegate maintenanceMode:NO];
        
            // Close HUD
            [self.hud hideHud];
            // Inizialized home
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:@"initializeMain" object:nil userInfo:nil];
        });
    });
}

- (void)clearCacheRequest:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_want_delete_cache_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil)
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
                                                           [self clearCache];
                                                       }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    alertController.popoverPresentationController.sourceRect = CGRectOffset(cellRect, -self.tableView.contentOffset.x, -self.tableView.contentOffset.y);
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Exit Nextcloud ==
#pragma --------------------------------------------------------------------------------------------

- (void)exitNextcloud:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_want_exit_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        
        [[CCNetworking sharedNetworking] invalidateAndCancelAllSession];
        
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [KTVHTTPCache cacheDeleteAllCaches];

        [CCUtility emptyGroupDirectoryProviderStorage];
        [CCUtility emptyGroupApplicationSupport];
        
        [CCUtility emptyDocumentsDirectory];
        [CCUtility emptyTemporaryDirectory];
        
        [CCUtility deleteAllChainStore];
        
        [[NCManageDatabase sharedInstance] removeDB];
        
        exit(0);
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    alertController.popoverPresentationController.sourceRect = CGRectOffset(cellRect, -self.tableView.contentOffset.x, -self.tableView.contentOffset.y);
    
    [self presentViewController:alertController animated:YES completion:nil];
}

@end

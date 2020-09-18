//
//  CCManageHelp.m
//  Nextcloud
//
//  Created by Marino Faggiana on 06/11/15.
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

#import "CCAdvanced.h"
#import "CCUtility.h"
#import "AppDelegate.h"
#import <KTVHTTPCache/KTVHTTPCache.h>
#import "NCBridgeSwift.h"

@interface CCAdvanced ()
{
    AppDelegate *appDelegate;
    CCHud *_hud;
}
@end

@implementation CCAdvanced

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
    
    // Section HIDDEN FILES -------------------------------------------------

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"showHiddenFiles" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_show_hidden_files_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    if ([CCUtility getShowHiddenFiles]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Format Compatibility + Live Photo
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = [NSString stringWithFormat:@"%@\n%@", NSLocalizedString(@"_format_compatibility_footer_", nil), NSLocalizedString(@"_upload_mov_livephoto_footer_", nil)];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"formatCompatibility" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_format_compatibility_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    if ([CCUtility getFormatCompatibility]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"livePhoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_upload_mov_livephoto_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    if ([CCUtility getLivePhoto]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Disable Local Cache After Upload
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_disableLocalCacheAfterUpload_footer_", nil);
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"disableLocalCacheAfterUpload" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_disableLocalCacheAfterUpload_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    if ([CCUtility getDisableLocalCacheAfterUpload]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Section : Files App --------------------------------------------------------------
    
    if (![NCBrandOptions sharedInstance].disable_openin_file) {
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        section.footerTitle = NSLocalizedString(@"_disable_files_app_footer_", nil);

        // Disable Files App
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"disablefilesapp" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_disable_files_app_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        if ([CCUtility getDisableFilesApp]) row.value = @"1";
        else row.value = @"0";
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [section addFormRow:row];
    }
    
    // Section : Privacy --------------------------------------------------------------

    if (!NCBrandOptions.sharedInstance.disable_crash_service) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_privacy_", nil)];
        [form addFormSection:section];
        section.footerTitle = NSLocalizedString(@"_privacy_footer_", nil);
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"crashservice" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_crashservice_title_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"crashservice"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        if ([CCUtility getDisableCrashservice]) row.value = @"1";
        else row.value = @"0";
        [section addFormRow:row];
    }
    
    // Section DIAGNOSTICS -------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_diagnostics_", nil)];
    [form addFormSection:section];
    
    NSString *fileNameLog = [[NCCommunicationCommon shared] getFileNameLog];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNameLog]) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"log" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_view_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"log"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                    
            [self deselectFormRow:sender];
            
            NCViewerQuickLook *viewerQuickLook = [NCViewerQuickLook new];
            [viewerQuickLook quickLookWithUrl:[NSURL fileURLWithPath:fileNameLog] viewController:self];
        };
        [section addFormRow:row];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"clearlog" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_clear_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"clear"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
        row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                    
            [self deselectFormRow:sender];

            [[NCCommunicationCommon shared] clearFileLog];
            
            NSInteger logLevel = [CCUtility getLogLevel];
            BOOL isSimulatorOrTestFlight = [[NCUtility shared] isSimulatorOrTestFlight];
            NSString *versionApp = [NSString stringWithFormat:@"%@.%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"], [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
            NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions sharedInstance].textCopyrightNextcloudiOS, versionApp];
            
            if (isSimulatorOrTestFlight) {
                [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Clear log with level %lu %@ (Simulator / TestFlight)", (unsigned long)logLevel, versionNextcloudiOS]];
            } else {
                [[NCCommunicationCommon shared] writeLog:[NSString stringWithFormat:@"Clear log with level %lu %@", (unsigned long)logLevel, versionNextcloudiOS]];
            }
        };
        [section addFormRow:row];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"logLevel" rowType:XLFormRowDescriptorTypeSlider title:NSLocalizedString(@"_level_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
        [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        NSInteger logLevel = [CCUtility getLogLevel];
        row.value = @(logLevel);
        [row.cellConfigAtConfigure setObject:@(2) forKey:@"slider.maximumValue"];
        [row.cellConfigAtConfigure setObject:@(0) forKey:@"slider.minimumValue"];
        [row.cellConfigAtConfigure setObject:@(2) forKey:@"steps"];
        [section addFormRow:row];
    }
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"capabilities" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_capabilities_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"capabilities"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                
        [self deselectFormRow:sender];
        
        NCCapabilitiesViewController *capabilities = [[UIStoryboard storyboardWithName:@"NCCapabilitiesViewController" bundle:nil] instantiateInitialViewController];        
        [self presentViewController:capabilities animated:YES completion:nil];
    };
    [section addFormRow:row];

    // Section CLEAR CACHE -------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_clear_cache_footer_", nil);

    // Clear cache
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"azzeracache" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_clear_cache_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    row.action.formSelector = @selector(clearCacheRequest:);
    [section addFormRow:row];

    // Section EXIT --------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_exit_footer_", nil);
    
    // Exit
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"esci" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_exit_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"exit"] width:50 height:50 color:[UIColor redColor]] forKey:@"imageView.image"];
    row.action.formSelector = @selector(exitNextcloud:);
    [section addFormRow:row];

    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    self.title = NSLocalizedString(@"_advanced_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    [self changeTheming];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:true];
    [self initializeForm];
}

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"showHiddenFiles"]) {
        
        [CCUtility setShowHiddenFiles:[[rowDescriptor.value valueData] boolValue]];        
    }
    
    if ([rowDescriptor.tag isEqualToString:@"formatCompatibility"]) {
        
        [CCUtility setFormatCompatibility:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"livePhoto"]) {
        
        [CCUtility setLivePhoto:[[rowDescriptor.value valueData] boolValue]];
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
    
    if ([rowDescriptor.tag isEqualToString:@"logLevel"]) {
        
        NSInteger logLevel = [[rowDescriptor.value valueData] intValue];
        [CCUtility setLogLevel:logLevel];
        [[NCCommunicationCommon shared] setFileLogWithLevel:logLevel echo:true];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark === Clear Cache ===
#pragma --------------------------------------------------------------------------------------------

- (void)clearCache
{
    [appDelegate maintenanceMode:YES];
    
    [[NCNetworking shared] cancelAllTransferWithAccount:appDelegate.account completion:^{ }];
    [[NCOperationQueue shared] cancelAllQueue];

    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
    [KTVHTTPCache cacheDeleteAllCaches];
    
    [[NCManageDatabase sharedInstance] clearDatabaseWithAccount:appDelegate.account removeAccount:false];
    
    [CCUtility removeGroupDirectoryProviderStorage];
    [CCUtility removeGroupLibraryDirectory];
    
    [CCUtility removeDocumentsDirectory];
    [CCUtility removeTemporaryDirectory];
    
    [CCUtility createDirectoryStandard];

    [[NCAutoUpload sharedInstance] alignPhotoLibrary];

    [appDelegate maintenanceMode:NO];

    // Inizialized home
    [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
    
    // Clear Media
    [appDelegate.activeMedia reloadDataSource];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
       [_hud hideHud];
    });
}

- (void)clearCacheRequest:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_want_delete_cache_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [_hud visibleHudTitle:NSLocalizedString(@"_wait_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            [self clearCache];
        });
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
                
        [[NSURLCache sharedURLCache] setMemoryCapacity:0];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];
        [KTVHTTPCache cacheDeleteAllCaches];

        [CCUtility removeGroupDirectoryProviderStorage];
        [CCUtility removeGroupApplicationSupport];
        
        [CCUtility removeDocumentsDirectory];
        [CCUtility removeTemporaryDirectory];
        
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

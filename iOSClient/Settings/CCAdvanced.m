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
#import "NCBridgeSwift.h"

@interface CCAdvanced ()
{
    AppDelegate *appDelegate;
    XLFormSectionDescriptor *sectionSize;
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
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    if ([[[NCKeychain alloc] init] showHiddenFiles]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Format Compatibility + Live Photo + Delete asset
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = [NSString stringWithFormat:@"%@\n%@\n%@", NSLocalizedString(@"_format_compatibility_footer_", nil), NSLocalizedString(@"_upload_mov_livephoto_footer_", nil), NSLocalizedString(@"_remove_photo_CameraRoll_desc_", nil)];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"formatCompatibility" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_format_compatibility_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    if ([[[NCKeychain alloc] init] formatCompatibility]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"livePhoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_upload_mov_livephoto_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    if ([[[NCKeychain alloc] init] livePhoto]) row.value = @"1";
    else row.value = @"0";
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"removePhotoCameraRoll" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_remove_photo_CameraRoll_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    if ([[[NCKeychain alloc] init] removePhotoCameraRoll]) row.value = @"1";
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Section : Files App --------------------------------------------------------------
    
    if (![NCBrandOptions shared].disable_openin_file) {
    
        section = [XLFormSectionDescriptor formSection];
        [form addFormSection:section];
        section.footerTitle = NSLocalizedString(@"_disable_files_app_footer_", nil);

        // Disable Files App
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"disablefilesapp" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_disable_files_app_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        if ([[NCKeychain alloc] init].disableFilesApp) row.value = @"1";
        else row.value = @"0";
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [section addFormRow:row];
    }

    // Section : Privacy --------------------------------------------------------------

    if (!NCBrandOptions.shared.disable_crash_service) {
    
        section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_privacy_", nil)];
        [form addFormSection:section];
        section.footerTitle = NSLocalizedString(@"_privacy_footer_", nil);
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"crashservice" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_crashservice_title_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"crashservice"] imageWithColor:[NCBrandColor shared].iconImageColor size:25] forKey:@"imageView.image"];
        if ([[[NCKeychain alloc] init] disableCrashservice]) row.value = @"1";
        else row.value = @"0";
        [section addFormRow:row];
    }
    
    // Section DIAGNOSTICS -------------------------------------------------

    section = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_diagnostics_", nil)];
    [form addFormSection:section];
        
    if ([[NSFileManager defaultManager] fileExistsAtPath:NextcloudKit.shared.nkCommonInstance.filenamePathLog] && NCBrandOptions.shared.disable_log == false) {
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"log" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_view_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"log"] imageWithColor:[NCBrandColor shared].iconImageColor size:25] forKey:@"imageView.image"];
        row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                    
            [self deselectFormRow:sender];
            NCViewerQuickLook *viewerQuickLook = [[NCViewerQuickLook alloc] initWith:[NSURL fileURLWithPath:NextcloudKit.shared.nkCommonInstance.filenamePathLog] isEditingEnabled:false metadata:nil];
            [self presentViewController:viewerQuickLook animated:YES completion:nil];
        };
        [section addFormRow:row];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"clearlog" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_clear_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        [row.cellConfig setObject:[[UIImage imageNamed:@"clear"] imageWithColor:[NCBrandColor shared].iconImageColor size:25] forKey:@"imageView.image"];
        row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                    
            [self deselectFormRow:sender];

            [[[NextcloudKit shared] nkCommonInstance] clearFileLog];
            
            NSInteger logLevel = [[NCKeychain alloc] init].logLevel;
            BOOL isSimulatorOrTestFlight = [[[NCUtility alloc] init] isSimulatorOrTestFlight];
            NSString *versionNextcloudiOS = [NSString stringWithFormat:[NCBrandOptions shared].textCopyrightNextcloudiOS, [[[NCUtility alloc] init] getVersionAppWithBuild:true]];
            if (isSimulatorOrTestFlight) {
                [[[NextcloudKit shared] nkCommonInstance] writeLog:[NSString stringWithFormat:@"[INFO] Clear log with level %lu %@ (Simulator / TestFlight)", (unsigned long)logLevel, versionNextcloudiOS]];
            } else {
                [[[NextcloudKit shared] nkCommonInstance] writeLog:[NSString stringWithFormat:@"[INFO] Clear log with level %lu %@", (unsigned long)logLevel, versionNextcloudiOS]];
            }
        };
        [section addFormRow:row];
        
        row = [XLFormRowDescriptor formRowDescriptorWithTag:@"logLevel" rowType:XLFormRowDescriptorTypeSlider title:NSLocalizedString(@"_level_log_", nil)];
        row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
        [row.cellConfig setObject:@(NSTextAlignmentCenter) forKey:@"textLabel.textAlignment"];
        [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
        [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
        NSInteger logLevel = [[NCKeychain alloc] init].logLevel;
        row.value = @(logLevel);
        [row.cellConfigAtConfigure setObject:@(2) forKey:@"slider.maximumValue"];
        [row.cellConfigAtConfigure setObject:@(0) forKey:@"slider.minimumValue"];
        [row.cellConfigAtConfigure setObject:@(2) forKey:@"steps"];
        [section addFormRow:row];
    }
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"capabilities" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_capabilities_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"capabilities"] imageWithColor:[NCBrandColor shared].iconImageColor size:25] forKey:@"imageView.image"];
    row.action.formBlock = ^(XLFormRowDescriptor * sender) {
                
        [self deselectFormRow:sender];

        UIViewController *vc = [[NCHostingCapabilitiesView alloc] makeShipDetailsUI];
        [self.navigationController pushViewController:vc animated:YES];
    };
    [section addFormRow:row];
    
    // Section : Delete files / Clear cache --------------------------------------------------------------

    sectionSize = [XLFormSectionDescriptor formSectionWithTitle:NSLocalizedString(@"_delete_files_desc_", nil)];
    [form addFormSection:sectionSize];
    sectionSize.footerTitle = NSLocalizedString(@"_clear_cache_footer_", nil);

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"deleteoldfiles" rowType:XLFormRowDescriptorTypeSelectorPush title:NSLocalizedString(@"_delete_old_files_", nil)];
    
    switch ([[NCKeychain alloc] init].cleanUpDay) {
        case 0:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(0) displayText:NSLocalizedString(@"_never_", nil)];
            break;
        case 365:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(365) displayText:NSLocalizedString(@"_1_year_", nil)];
            break;
        case 180:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(180) displayText:NSLocalizedString(@"_6_months_", nil)];
            break;
        case 90:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(90) displayText:NSLocalizedString(@"_3_months_", nil)];
            break;
        case 30:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(30) displayText:NSLocalizedString(@"_1_month_", nil)];
            break;
        case 7:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(7) displayText:NSLocalizedString(@"_1_week_", nil)];
            break;
        case 1:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(1) displayText:NSLocalizedString(@"_1_day_", nil)];
            break;
        default:
            row.value = [XLFormOptionsObject formOptionsObjectWithValue:@(0) displayText:NSLocalizedString(@"_never_", nil)];
            break;
    }
    
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    row.selectorTitle = NSLocalizedString(@"_delete_old_files_", nil);
    row.selectorOptions = @[[XLFormOptionsObject formOptionsObjectWithValue:@(0) displayText:NSLocalizedString(@"_never_", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@(365) displayText:NSLocalizedString(@"_1_year_", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@(180) displayText:NSLocalizedString(@"_6_months_", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@(90) displayText:NSLocalizedString(@"_3_months_", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@(30) displayText:NSLocalizedString(@"_1_month_", nil)],
                            [XLFormOptionsObject formOptionsObjectWithValue:@(7) displayText:NSLocalizedString(@"_1_week_", nil)],
                            ];
    [sectionSize addFormRow:row];
    
    // Clear cache
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"azzeracache" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_clear_cache_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:UIColor.labelColor forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"trash"] imageWithColor:[NCBrandColor shared].iconImageColor size:25] forKey:@"imageView.image"];
    row.action.formSelector = @selector(clearCacheRequest:);
    [sectionSize addFormRow:row];

    // Section EXIT --------------------------------------------------------
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_exit_footer_", nil);
    
    // Exit
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"esci" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_exit_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = UIColor.secondarySystemGroupedBackgroundColor;
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    [row.cellConfig setObject:[UIColor redColor] forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:[[UIImage imageNamed:@"xmark"] imageWithColor:[UIColor redColor] size:25] forKey:@"imageView.image"];
    row.action.formSelector = @selector(exitNextcloud:);
    [section addFormRow:row];

    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

// MARK: - View Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    self.title = NSLocalizedString(@"_advanced_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    self.tableView.backgroundColor = UIColor.systemGroupedBackgroundColor;
    
    [self initializeForm];
    [self calculateSize];
}

#pragma mark -

- (void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    if ([rowDescriptor.tag isEqualToString:@"showHiddenFiles"]) {
        
        [[NCKeychain alloc] init].showHiddenFiles = [[rowDescriptor.value valueData] boolValue];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"formatCompatibility"]) {
        
        [[NCKeychain alloc] init].formatCompatibility = [[rowDescriptor.value valueData] boolValue];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"livePhoto"]) {
        
        [[NCKeychain alloc] init].livePhoto = [[rowDescriptor.value valueData] boolValue];
    }

    if ([rowDescriptor.tag isEqualToString:@"removePhotoCameraRoll"]) {

        [[NCKeychain alloc] init].removePhotoCameraRoll = [[rowDescriptor.value valueData] boolValue];
    }

    if ([rowDescriptor.tag isEqualToString:@"disablefilesapp"]) {
        
        [[NCKeychain alloc] init].disableFilesApp = [[rowDescriptor.value valueData] boolValue];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"crashservice"]) {
        
        [[NCKeychain alloc] init].disableCrashservice = [[rowDescriptor.value valueData] boolValue];

        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_crashservice_title_", nil) message:NSLocalizedString(@"_crashservice_alert_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            exit(0);
        }];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"logLevel"]) {
        
        NSInteger levelLog = [[rowDescriptor.value valueData] intValue];
        [[NCKeychain alloc] init].logLevel = levelLog;
        [[[NextcloudKit shared] nkCommonInstance] setLevelLog:levelLog];
    }

    if ([rowDescriptor.tag isEqualToString:@"deleteoldfiles"]) {
        
        NSInteger days = [[rowDescriptor.value valueData] intValue];
        [[NCKeychain alloc] init].cleanUpDay = days;
    }
}

#pragma mark - Clear Cache

- (void)clearCache:(NSString *)account
{
    [[NCNetworking shared] cancelAllTask];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {

        NCUtilityFileSystem *ufs = [[NCUtilityFileSystem alloc] init];

        [[NSURLCache sharedURLCache] setMemoryCapacity:0];
        [[NSURLCache sharedURLCache] setDiskCapacity:0];

        [[NCManageDatabase shared] clearDatabaseWithAccount:account removeAccount:false];

        [ufs removeGroupDirectoryProviderStorage];
        [ufs removeGroupLibraryDirectory];

        [ufs removeDocumentsDirectory];
        [ufs removeTemporaryDirectory];

        [ufs createDirectoryStandard];

        [[NCAutoUpload shared] alignPhotoLibraryWithViewController:self];

        [[NCImageCache shared] createMediaCacheWithAccount:appDelegate.account withCacheSize:true];

        [[NCActivityIndicator shared] stop];
        [self calculateSize];
    });
}

- (void)clearCacheRequest:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_want_delete_cache_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_yes_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [[NCActivityIndicator shared] startActivityWithBackgroundView:nil style: UIActivityIndicatorViewStyleLarge blurEffect:true];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            [self clearCache:appDelegate.account];
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

- (void)calculateSize
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NCUtilityFileSystem *ufs = [[NCUtilityFileSystem alloc] init];
        NSString *directory =  [ufs directoryProviderStorage];
        int64_t totalSize = [ufs getDirectorySizeWithDirectory:directory];
        sectionSize.footerTitle = [NSString stringWithFormat:@"%@. (%@ %@)", NSLocalizedString(@"_clear_cache_footer_", nil), NSLocalizedString(@"_used_space_", nil), [ufs transformedSize:totalSize]];

        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    });
}

#pragma mark - Exit Nextcloud

- (void)exitNextcloud:(XLFormRowDescriptor *)sender
{
    [self deselectFormRow:sender];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:NSLocalizedString(@"_want_exit_", nil) preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [appDelegate resetApplication];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.view;
    NSIndexPath *indexPath = [self.form indexPathOfFormRow:sender];
    CGRect cellRect = [self.tableView rectForRowAtIndexPath:indexPath];
    alertController.popoverPresentationController.sourceRect = CGRectOffset(cellRect, -self.tableView.contentOffset.x, -self.tableView.contentOffset.y);
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (indexPath.section == 4 && indexPath.row == 2) {
        return 80;
    } else {
        return NCGlobal.shared.heightCellSettings;
    }
}

@end

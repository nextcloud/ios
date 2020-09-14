//
//  CCManageAutoUpload.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/09/15.
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

#import "CCManageAutoUpload.h"
#import "NCAutoUpload.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCManageAutoUpload () <NCSelectDelegate>
{
    AppDelegate *appDelegate;
}
@end

@implementation CCManageAutoUpload

- (void)initializeForm
{
    XLFormDescriptor *form = [XLFormDescriptor formDescriptor];
    XLFormSectionDescriptor *section;
    XLFormRowDescriptor *row;
 
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    // Auto Upload
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    section.footerTitle = NSLocalizedString(@"_autoupload_description_", nil);

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUpload" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    if (tableAccount.autoUpload) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];

    // Auto Upload Directory
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    // Lock active YES/NO
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadDirectory" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_autoupload_select_folder_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    [row.cellConfig setObject:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderAutomaticUpload"] width:50 height:50 color:NCBrandColor.sharedInstance.icon] forKey:@"imageView.image"];
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [row.cellConfig setObject:@(NSTextAlignmentLeft) forKey:@"textLabel.textAlignment"];
    //[row.cellConfig setObject:@(UITableViewCellAccessoryDisclosureIndicator) forKey:@"accessoryType"];
    row.action.formSelector = @selector(selectAutomaticUploadFolder);
    [section addFormRow:row];
    
    // Auto Upload Photo
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadImage" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_photos_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadImage) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadWWAnPhoto" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_wifi_only_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadWWAnPhoto) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Video
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadVideo" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_videos_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadVideo) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadWWAnVideo" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_wifi_only_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadWWAnVideo) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Delete asset
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"removePhotoCameraRoll" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_remove_photo_CameraRoll_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadDeleteAssetLocalIdentifier) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Background
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];

    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadBackground" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_background_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadBackground) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload Full
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    NSString *title = NSLocalizedString(@"_autoupload_fullphotos_", nil);
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadFull" rowType:XLFormRowDescriptorTypeBooleanSwitch title:title];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    row.value = 0;
    if (tableAccount.autoUploadFull) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload create subfolder

    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadCreateSubfolder" rowType:XLFormRowDescriptorTypeBooleanSwitch title:NSLocalizedString(@"_autoupload_create_subfolder_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    row.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    if (tableAccount.autoUploadCreateSubfolder) row.value = @1;
    else row.value = @0;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    [section addFormRow:row];
    
    // Auto Upload file name
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    row = [XLFormRowDescriptor formRowDescriptorWithTag:@"autoUploadFileName" rowType:XLFormRowDescriptorTypeButton title:NSLocalizedString(@"_autoupload_filenamemask_", nil)];
    row.cellConfigAtConfigure[@"backgroundColor"] = NCBrandColor.sharedInstance.backgroundCell;
    [row.cellConfig setObject:[UIFont systemFontOfSize:15.0] forKey:@"textLabel.font"];
    [row.cellConfig setObject:NCBrandColor.sharedInstance.textView forKey:@"textLabel.textColor"];
    row.action.viewControllerClass = [NCManageAutoUploadFileName class];
    [section addFormRow:row];
    
    // end
    
    section = [XLFormSectionDescriptor formSection];
    [form addFormSection:section];
    
    self.tableView.showsVerticalScrollIndicator = NO;
    self.form = form;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = NSLocalizedString(@"_settings_autoupload_", nil);
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    
    // changeTheming
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    
    [self changeTheming];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Request permission for camera roll access
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        switch (status) {
            case PHAuthorizationStatusRestricted:
                NSLog(@"[LOG] user can't grant access to camera roll");
                break;
            case PHAuthorizationStatusDenied:
                NSLog(@"[LOG] user denied access to camera roll");
                break;
            default:
                break;
        }
    }];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:true];
    [self initializeForm];
    [self reloadForm];
}

-(void)formRowDescriptorValueHasChanged:(XLFormRowDescriptor *)rowDescriptor oldValue:(id)oldValue newValue:(id)newValue
{
    [super formRowDescriptorValueHasChanged:rowDescriptor oldValue:oldValue newValue:newValue];
    
    tableAccount *account = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if ([rowDescriptor.tag isEqualToString:@"autoUpload"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
                        
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUpload" state:YES];
            
            // Default
            [[NCManageDatabase sharedInstance] setAccountAutoUploadFileName:nil];
            [[NCManageDatabase sharedInstance] setAccountAutoUploadDirectory:nil urlBase:appDelegate.urlBase account:appDelegate.account];
            
            // verifichiamo che almeno uno dei servizi (foto video) siano attivi, in caso contrario attiviamo le foto
            if (account.autoUploadImage == NO && account.autoUploadVideo == NO) {
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadImage" state:YES];
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadVideo" state:YES];
            }
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [[NCAutoUpload sharedInstance] alignPhotoLibrary];
            });
            
        } else {
            
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUpload" state:NO];
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadFull" state:NO];

            // remove
            [[NCManageDatabase sharedInstance] clearMetadatasUploadWithAccount:appDelegate.account];
        }
        
        [self reloadForm];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"removePhotoCameraRoll"]) {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadDeleteAssetLocalIdentifier" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadBackground"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            BOOL isLocationIsEnabled = NO;
            
            [[NCAutoUpload sharedInstance] checkIfLocationIsEnabled];
                            
            if(isLocationIsEnabled == YES) {
                
                UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_autoupload_background_title_", nil) message:NSLocalizedString(@"_autoupload_background_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
                UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
                
                [alertController addAction:okAction];
                [self presentViewController:alertController animated:YES completion:nil];
                
                [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:YES];
                    
            } else {
                 
                [self reloadForm];
            }
            
        } else {
            
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadBackground" state:NO];
            [[CCManageLocation sharedInstance] stopSignificantChangeUpdates];
        }
    }

    if ([rowDescriptor.tag isEqualToString:@"autoUploadFull"]) {
        
        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            
            [[NCAutoUpload sharedInstance] setupAutoUploadFull];
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadFull" state:YES];
            
        } else {
            
            [[NCManageDatabase sharedInstance] clearMetadatasUploadWithAccount:appDelegate.account];
            [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadFull" state:NO];
        }
    }

    if ([rowDescriptor.tag isEqualToString:@"autoUploadImage"]) {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadImage" state:[[rowDescriptor.value valueData] boolValue]];

        if ([[rowDescriptor.value valueData] boolValue] == YES) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [[NCAutoUpload sharedInstance] alignPhotoLibrary];
            });
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadWWAnPhoto"]) {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadWWAnPhoto" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadVideo"]) {
    
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadVideo" state:[[rowDescriptor.value valueData] boolValue]];

        if ([[rowDescriptor.value valueData] boolValue] == YES){
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                [[NCAutoUpload sharedInstance] alignPhotoLibrary];
            });
        }
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadWWAnVideo"]) {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadWWAnVideo" state:[[rowDescriptor.value valueData] boolValue]];
    }
    
    if ([rowDescriptor.tag isEqualToString:@"autoUploadCreateSubfolder"]) {
        
        [[NCManageDatabase sharedInstance] setAccountAutoUploadProperty:@"autoUploadCreateSubfolder" state:[[rowDescriptor.value valueData] boolValue]];
    }
}

- (void)done:(XLFormRowDescriptor *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)reloadForm
{
    self.form.delegate = nil;
    
    XLFormRowDescriptor *rowAutoUpload = [self.form formRowWithTag:@"autoUpload"];
    
    XLFormRowDescriptor *rowAutoUploadImage = [self.form formRowWithTag:@"autoUploadImage"];
    XLFormRowDescriptor *rowAutoUploadWWAnPhoto = [self.form formRowWithTag:@"autoUploadWWAnPhoto"];
    
    XLFormRowDescriptor *rowAutoUploadVideo = [self.form formRowWithTag:@"autoUploadVideo"];
    XLFormRowDescriptor *rowAutoUploadWWAnVideo = [self.form formRowWithTag:@"autoUploadWWAnVideo"];
    
    XLFormRowDescriptor *rowRemovePhotoCameraRoll = [self.form formRowWithTag:@"removePhotoCameraRoll"];

    XLFormRowDescriptor *rowAutoUploadBackground = [self.form formRowWithTag:@"autoUploadBackground"];
    
    XLFormRowDescriptor *rowAutoUploadFull = [self.form formRowWithTag:@"autoUploadFull"];
    
    XLFormRowDescriptor *rowAutoUploadCreateSubfolder = [self.form formRowWithTag:@"autoUploadCreateSubfolder"];
    
    XLFormRowDescriptor *rowAutoUploadFileName = [self.form formRowWithTag:@"autoUploadFileName"];
        
    // - STATUS ---------------------
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (tableAccount.autoUpload)
        [rowAutoUpload setValue:@1]; else [rowAutoUpload setValue:@0];
    
    if (tableAccount.autoUploadImage)
        [rowAutoUploadImage setValue:@1]; else [rowAutoUploadImage setValue:@0];
    
    if (tableAccount.autoUploadWWAnPhoto)
        [rowAutoUploadWWAnPhoto setValue:@1]; else [rowAutoUploadWWAnPhoto setValue:@0];
    
    if (tableAccount.autoUploadVideo)
        [rowAutoUploadVideo setValue:@1]; else [rowAutoUploadVideo setValue:@0];
    
    if (tableAccount.autoUploadWWAnVideo)
        [rowAutoUploadWWAnVideo setValue:@1]; else [rowAutoUploadWWAnVideo setValue:@0];
    
    if (tableAccount.autoUploadDeleteAssetLocalIdentifier)
           [rowRemovePhotoCameraRoll setValue:@1]; else [rowRemovePhotoCameraRoll setValue:@0];
    
    if (tableAccount.autoUploadBackground)
        [rowAutoUploadBackground setValue:@1]; else [rowAutoUploadBackground setValue:@0];
    
    if (tableAccount.autoUploadFull)
        [rowAutoUploadFull setValue:@1]; else [rowAutoUploadFull setValue:@0];
    
    if (tableAccount.autoUploadCreateSubfolder)
        [rowAutoUploadCreateSubfolder setValue:@1]; else [rowAutoUploadCreateSubfolder setValue:@0];

    // - HIDDEN --------------------------------------------------------------------------
    
    rowAutoUploadImage.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    rowAutoUploadWWAnPhoto.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadVideo.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    rowAutoUploadWWAnVideo.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowRemovePhotoCameraRoll.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];

    rowAutoUploadBackground.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadFull.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadCreateSubfolder.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
    
    rowAutoUploadFileName.hidden = [NSString stringWithFormat:@"$%@==0", @"autoUpload"];
        
    // -----------------------------------------------------------------------------------
    
    [self.tableView reloadData];
    
    self.form.delegate = self;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    NSString *sectionName;
    NSString *autoUploadPath = [NSString stringWithFormat:@"%@/%@", [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectoryWithUrlBase:appDelegate.urlBase account:appDelegate.account], [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName]];

    switch (section)
    {
        case 0:
            sectionName = NSLocalizedString(@"_autoupload_description_", nil);
            break;
        case 1:
            if (tableAccount.autoUpload) sectionName = [NSString stringWithFormat:@"%@: %@", NSLocalizedString(@"_autoupload_current_folder_", nil), [CCUtility returnPathfromServerUrl:autoUploadPath urlBase:appDelegate.urlBase account:appDelegate.account]];
            else sectionName = @"";
            break;
        case 4:
            if (tableAccount.autoUpload) sectionName = NSLocalizedString(@"_remove_photo_CameraRoll_desc_", nil);
            else sectionName = @"";
            break;
        case 5:
            if (tableAccount.autoUpload) sectionName = NSLocalizedString(@"_autoupload_description_background_", nil);
            else sectionName = @"";
            break;
        case 6:
            if (tableAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_fullphotos_footer_", nil);
            else sectionName = @"";
            break;
        case 7:
            if (tableAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_create_subfolder_footer_", nil);
            else sectionName = @"";
            break;
        case 8:
            if (tableAccount.autoUpload) sectionName =  NSLocalizedString(@"_autoupload_filenamemask_footer_", nil);
            else sectionName = @"";
            break;
    }
    return sectionName;
}

- (void)dismissSelectWithServerUrl:(NSString *)serverUrl metadata:(tableMetadata *)metadata type:(NSString *)type array:(NSArray *)array buttonType:(NSString *)buttonType overwrite:(BOOL)overwrite
{
    if (serverUrl != nil) {
        
        if ([serverUrl isEqualToString:[[NCUtility shared] getHomeServerWithUrlBase:appDelegate.urlBase account:appDelegate.account]]) {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:@"_autoupload_error_select_folder_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError forced:true];
            return;
        }
        
        // Settings new folder Automatatic upload
        [[NCManageDatabase sharedInstance] setAccountAutoUploadFileName:[CCUtility getLastPathFromServerUrl:serverUrl urlBase:appDelegate.urlBase]];
        [[NCManageDatabase sharedInstance] setAccountAutoUploadDirectory:[CCUtility deletingLastPathComponentFromServerUrl:serverUrl] urlBase:appDelegate.urlBase account:appDelegate.account];
    }
}

- (void)selectAutomaticUploadFolder
 {
     UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCSelect" bundle:nil] instantiateInitialViewController];
     NCSelect *viewController = (NCSelect *)navigationController.topViewController;
     
     viewController.delegate = self;
     viewController.hideButtonCreateFolder = false;
     viewController.selectFile = false;
     viewController.includeDirectoryE2EEncryption = false;
     viewController.includeImages = false;
     viewController.type = @"";
     viewController.titleButtonDone = NSLocalizedString(@"_select_", nil);
     viewController.keyLayout = k_layout_view_move;
     
     [navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
     [self presentViewController:navigationController animated:YES completion:^{
         [self.tableView reloadData];
     }];
 }

@end

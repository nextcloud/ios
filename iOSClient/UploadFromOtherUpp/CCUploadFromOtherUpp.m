//
//  CCUploadFromOtherUpp.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/12/14.
//  Copyright (c) 2014 Marino Faggiana. All rights reserved.
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

#import "CCUploadFromOtherUpp.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCUploadFromOtherUpp() <NCSelectDelegate>
{
    AppDelegate *appDelegate;

    NSString *serverUrlLocal;
    NSString *destinationTitle;
}
@end

@implementation CCUploadFromOtherUpp

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];

    self.title = NSLocalizedString(@"_upload_", nil);
    
    serverUrlLocal= [[NCUtility shared] getHomeServerWithUrlBase:appDelegate.urlBase account:appDelegate.account];
    destinationTitle = @"/";
    
    // changeTheming
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    [self changeTheming];
    
    [self.tableView reloadData];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:true];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == tableView ==
#pragma --------------------------------------------------------------------------------------------

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0) return NSLocalizedString(@"_file_to_upload_", nil);
    else if (section == 2) return NSLocalizedString(@"_destination_", nil);
    
    return @"";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    UILabel *nameLabel;
    
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    
    switch (section)
    {
        case 0:
            if (row == 0) {
                                
                NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[NSTemporaryDirectory() stringByAppendingString:appDelegate.fileNameUpload] error:nil];
                NSString *fileSize = [CCUtility transformedSize:[[fileAttributes objectForKey:NSFileSize] longValue]];
                self.fileNameTextfield.text = appDelegate.fileNameUpload;
                self.fileSizeLabel.text = fileSize;
            }
            break;
        case 2:
            if (row == 0) {
    
                self.destinationLabel.text = destinationTitle;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                UIImageView *img = (UIImageView *)[cell viewWithTag:201];
                img.image = [UIImage imageNamed:@"folder"];
            }
            break;
        case 4:
            
            if (row == 0) {
                nameLabel = (UILabel *)[cell viewWithTag:102];
                nameLabel.text = NSLocalizedString(@"_upload_file_", nil);
            }
            
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSUInteger section = [indexPath section];
    NSUInteger row = [indexPath row];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    switch (section) {
        case 2:
            if (row == 0) {
                [self changeFolder];
            }
            break;
        case 4:
            if (row == 0) {
                [self upload];
            }
            break;
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == IBAction ==
#pragma --------------------------------------------------------------------------------------------

- (void)dismissSelectWithServerUrl:(NSString *)serverUrl metadata:(tableMetadata *)metadata type:(NSString *)type array:(NSArray *)array buttonType:(NSString *)buttonType overwrite:(BOOL)overwrite
{
    if (serverUrl) {
        serverUrlLocal = serverUrl;
        if ([serverUrl isEqualToString:appDelegate.urlBase]) {
            destinationTitle =  @"/";
        } else {
            destinationTitle = [CCUtility returnPathfromServerUrl:serverUrl urlBase:appDelegate.urlBase account:appDelegate.account];
        }
        self.destinationLabel.text = destinationTitle;
    }
}

- (void)changeFolder
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
    [self presentViewController:navigationController animated:YES completion:nil];
}

-(void)upload
{
    NSString *fileName = [[NCUtility shared] createFileName:self.fileNameTextfield.text serverUrl:serverUrlLocal account:appDelegate.account];
    
    tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.account fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrlLocal urlBase:appDelegate.urlBase url:@"" contentType:@"" livePhoto:false];
    
    metadataForUpload.session = NCNetworking.shared.sessionIdentifierBackground;
    metadataForUpload.sessionSelector = selectorUploadFile;
    metadataForUpload.status = k_metadataStatusWaitUpload;
    
    // Prepare file and directory
    [CCUtility copyFileAtPath:[NSTemporaryDirectory() stringByAppendingString:appDelegate.fileNameUpload] toPath:[CCUtility getDirectoryProviderStorageOcId:metadataForUpload.ocId fileNameView:fileName]];
    
    // Add Medtadata for upload
    [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];

    [[appDelegate networkingAutoUpload] startProcess];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)cancelUpload:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

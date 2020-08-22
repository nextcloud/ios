//
//  CCMove.m
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "NCSelectDestination.h"
#import "NCBridgeSwift.h"

@interface NCSelectDestination ()
{    
    NSString *account;
    NSString *urlBase;
  
    BOOL _loadingFolder;
    
    // Automatic Upload Folder
    NSString *_autoUploadFileName;
    NSString *_autoUploadDirectory;
    
    NSPredicate *predicateDataSource;
}
@end

@implementation NCSelectDestination

// MARK: - View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (tableAccount) {
        
        account = tableAccount.account;
        urlBase = tableAccount.urlBase;
                
    } else {
        
        UIAlertController * alert= [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"_no_active_account_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* ok = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            [alert dismissViewControllerAnimated:YES completion:nil];
        }];
        [alert addAction:ok];
        [self presentViewController:alert animated:YES completion:nil];
    }
    
    [self.cancel setTitle:NSLocalizedString(@"_cancel_", nil)];
    [self.create setTitle:NSLocalizedString(@"_create_folder_", nil)];
    
    if (![_serverUrl length]) {
                
        _serverUrl = [[NCUtility shared] getHomeServerWithUrlBase:urlBase account:account];
        
        [self.navigationController.navigationBar.topItem setTitleView:[[UIImageView alloc] initWithImage: [UIImage imageNamed:@"themingLogo"]]];
        self.title = @"Home";
        
    } else {
        
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0,0, self.navigationItem.titleView.frame.size.width, 40)];
        label.text = self.passMetadata.fileNameView;
        
        label.textColor = NCBrandColor.sharedInstance.brandText;
        
        label.backgroundColor =[UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        self.navigationItem.titleView=label;
    }
    
    // TableView : at the end of rows nothing
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor =  NCBrandColor.sharedInstance.separator;

    // get auto upload folder
    _autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    _autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectoryWithUrlBase:urlBase account:account];
    
    [self readFolder];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.brandElement;
    self.navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText;
    
    self.navigationController.toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar;
    self.navigationController.toolbar.tintColor = [UIColor grayColor];
    
    if (self.hideCreateFolder) {
        [self.create setEnabled:NO];
        [self.create setTintColor: [UIColor clearColor]];
    }
    
    if (self.hideMoveutton) {
        [self.move setEnabled:NO];
        [self.move setTintColor: [UIColor clearColor]];
    }
    
    self.view.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    self.tableView.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
}

// MARK: - IBAction

- (IBAction)cancel:(UIBarButtonItem *)sender
{
    if ([self.delegate respondsToSelector:@selector(dismissMove)])
        [self.delegate dismissMove];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)move:(UIBarButtonItem *)sender
{
    if ([self.delegate respondsToSelector:@selector(dismissMove)])
        [self.delegate dismissMove];
    
    [self.delegate moveServerUrlTo:_serverUrl title:self.passMetadata.fileNameView type:self.type];
        
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)create:(UIBarButtonItem *)sender
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_",nil) message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        //textField.placeholder = NSLocalizedString(@"LoginPlaceholder", @"Login");
        textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    }];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_save_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self createFolder:alertController.textFields.firstObject.text];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

// MARK: - Read Folder

- (void)readFolder
{
    [[NCNetworking shared] readFolderWithServerUrl:_serverUrl account:account completion:^(NSString *account, tableMetadata *metadataFolder, NSArray *metadatas, NSArray *metadatasUpdate, NSArray *metadatasLocalUpdate, NSInteger errorCode, NSString *errorDescription) {
        
        if (errorCode == 0) {
            self.move.enabled = true;
        } else {
            self.move.enabled = false;
        }
        
        _loadingFolder = NO;
        [self.tableView reloadData];
    }];
    
    _loadingFolder = YES;
    [self.tableView reloadData];
}

    
// MARK: - Create Folder

- (void)createFolder:(NSString *)fileNameFolder
{
    NSString *serverUrlFileName = [NSString stringWithFormat:@"%@/%@", _serverUrl, fileNameFolder];
     
    [[NCCommunication shared] createFolder:serverUrlFileName customUserAgent:nil addCustomHeaders:nil completionHandler:^(NSString *account, NSString *ocID, NSDate *date, NSInteger errorCode, NSString *errorDecription) {
        if (errorCode == 0) {
           [self readFolder];
        } else {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_",nil) message:errorDecription preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { }]];
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }];
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.includeDirectoryE2EEncryption) {
        
        if (self.includeImages) {
            predicateDataSource = [NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND (directory == true OR typeFile == 'image')", account, _serverUrl];
        } else {
            predicateDataSource = [NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND directory == true", account, _serverUrl];
        }
        
    } else {
        
        if (self.includeImages) {
            predicateDataSource = [NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND (directory == true OR typeFile == 'image')", account, _serverUrl];
        } else {
            predicateDataSource = [NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND e2eEncrypted == false AND directory == true", account, _serverUrl];
        }
    }
    
    NSArray *result = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicateDataSource page:0 limit:0 sorted:@"fileName" ascending:NO];
    
    if (result)
        return [result count];
    else
        return 0;    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"MyCustomCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicateDataSource sorted:@"fileName" ascending:YES index:indexPath.row];
    
    // Create Directory Provider Storage ocId
    [CCUtility getDirectoryProviderStorageOcId:metadata.ocId];
    
    // colors
    cell.textLabel.textColor = NCBrandColor.sharedInstance.textView;
    
    cell.detailTextLabel.text = @"";
    
    if (metadata.directory) {
    
        if (metadata.e2eEncrypted)
            cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderEncrypted"] multiplier:2 color:NCBrandColor.sharedInstance.brandElement];
        else if ([metadata.fileName isEqualToString:_autoUploadFileName] && [self.serverUrl isEqualToString:_autoUploadDirectory])
            cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderAutomaticUpload"] multiplier:2 color:NCBrandColor.sharedInstance.brandElement];
        else
            cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] multiplier:2 color:NCBrandColor.sharedInstance.brandElement];
        
    } else {
        
        UIImage *thumb = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId etag:metadata.etag]];
        
        if (thumb) {
            cell.imageView.image = thumb;
        } else {
            if (metadata.iconName.length > 0) {
                cell.imageView.image = [UIImage imageNamed:metadata.iconName];
            } else {
                cell.imageView.image = [UIImage imageNamed:@"file"];
            }
        }
    }

    cell.textLabel.text = metadata.fileNameView;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicateDataSource sorted:@"fileName" ascending:YES index:indexPath.row ];
    
    if (metadata.directory) {
        
        UINavigationController* navigationController = [[UIStoryboard storyboardWithName:@"NCSelectDestination" bundle:nil] instantiateInitialViewController];
        NCSelectDestination *viewController = (NCSelectDestination *)navigationController.topViewController;
        
        viewController.delegate = self.delegate;
        viewController.includeDirectoryE2EEncryption = self.includeDirectoryE2EEncryption;
        viewController.includeImages = self.includeImages;
        viewController.move.title = self.move.title;
        viewController.hideCreateFolder = self.hideCreateFolder;
        viewController.hideMoveutton = self.hideMoveutton;
        viewController.selectFile = self.selectFile;
        viewController.type = self.type;
        viewController.passMetadata = metadata;
        viewController.serverUrl = [CCUtility stringAppendServerUrl:_serverUrl addFileName:metadata.fileName];
        
        [self.navigationController pushViewController:viewController animated:YES];
        
    } else {
        
        if (self.selectFile) {
            
            if ([self.delegate respondsToSelector:@selector(dismissMove)])
                [self.delegate dismissMove];
            
            if ([self.delegate respondsToSelector:@selector(selectMetadata:serverUrl:)])
                [self.delegate selectMetadata:metadata serverUrl:_serverUrl];
            
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }
}

@end

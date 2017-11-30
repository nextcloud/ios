//
//  CCMove.m
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "CCMove.h"
#import "NCBridgeSwift.h"

@interface CCMove ()
{    
    NSString *activeAccount;
    NSString *activePassword;
    NSString *activeUrl;
    NSString *activeUser;
    NSString *activeUserID;
    NSString *directoryUser;
    
    BOOL _loadingFolder;
    
    // Automatic Upload Folder
    NSString *_autoUploadFileName;
    NSString *_autoUploadDirectory;
}
@end

@implementation CCMove

// MARK: - View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    tableAccount *recordAccount = [[NCManageDatabase sharedInstance] getAccountActive];
    
    if (recordAccount) {
        
        activeAccount = recordAccount.account;
        activePassword = recordAccount.password;
        activeUrl = recordAccount.url;
        activeUser = recordAccount.user;
        activeUserID = recordAccount.userID;
        directoryUser = [CCUtility getDirectoryActiveUser:activeUser activeUrl:activeUrl];
        
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
        
        UIImageView *image;
        
        _serverUrl = [CCUtility getHomeServerUrlActiveUrl:activeUrl];
        
        tableCapabilities *capabilities = [[NCManageDatabase sharedInstance] getCapabilites];
        if ([capabilities.themingColor isEqualToString:@"#FFFFFF"])
            image = [[UIImageView alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"navigationLogo"] color:[UIColor blackColor]]];
        else
            image = [[UIImageView alloc] initWithImage:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"navigationLogo"] color:[UIColor whiteColor]]];

        [self.navigationController.navigationBar.topItem setTitleView:image];
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
    self.tableView.separatorColor =  NCBrandColor.sharedInstance.seperator;
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;

    // read file->folder
    [self readFileReloadFolder];
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.barTintColor = NCBrandColor.sharedInstance.brand;
    self.navigationController.navigationBar.tintColor = NCBrandColor.sharedInstance.brandText;
    
    self.navigationController.toolbar.barTintColor = NCBrandColor.sharedInstance.tabBar;
    self.navigationController.toolbar.tintColor = NCBrandColor.sharedInstance.brandElement;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    if (_loadingFolder)
        return YES;
    else
        return NO;
}

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    return NO;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_loadingFolder) {
        
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
        activityView.color = [NCBrandColor sharedInstance].brandElement;
        [activityView startAnimating];
        
        return activityView;
    }
    
    return nil;
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
    [_networkingOperationQueue cancelAllOperations];
 
    if ([self.delegate respondsToSelector:@selector(dismissMove)])
        [self.delegate dismissMove];
    
    [self.delegate moveServerUrlTo:_serverUrl title:self.passMetadata.fileNameView];
        
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

// MARK: - BKPasscodeViewController

- (void)passcodeViewController:(CCBKPasscode *)aViewController didFinishWithPasscode:(NSString *)aPasscode
{
    [aViewController dismissViewControllerAnimated:YES completion:nil];
    
    [self performSegueDirectoryWithControlPasscode:false];
}

- (void)passcodeViewController:(BKPasscodeViewController *)aViewController authenticatePasscode:(NSString *)aPasscode resultHandler:(void (^)(BOOL))aResultHandler
{
    if ([aPasscode isEqualToString:[CCUtility getBlockCode]]) {
        
        self.lockUntilDate = nil;
        self.failedAttempts = 0;
        aResultHandler(YES);
        
    } else {
        
        aResultHandler(NO);
    }
}

- (void)passcodeViewControllerDidFailAttempt:(BKPasscodeViewController *)aViewController
{
    self.failedAttempts++;
    
    if (self.failedAttempts > 5) {
        
        NSTimeInterval timeInterval = 60;
        
        if (self.failedAttempts > 6) {
            
            NSUInteger multiplier = self.failedAttempts - 6;
            
            timeInterval = (5 * 60) * multiplier;
            
            if (timeInterval > 3600 * 24) {
                timeInterval = 3600 * 24;
            }
        }
        
        self.lockUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeInterval];
    }
}

- (NSUInteger)passcodeViewControllerNumberOfFailedAttempts:(BKPasscodeViewController *)aViewController
{
    return self.failedAttempts;
}

- (NSDate *)passcodeViewControllerLockUntilDate:(BKPasscodeViewController *)aViewController
{
    return self.lockUntilDate;
}

- (void)passcodeViewCloseButtonPressed:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

// MARK: - NetWorking

- (void)addNetworkingQueue:(CCMetadataNet *)metadataNet
{
    OCnetworking *operation = [[OCnetworking alloc] initWithDelegate:self metadataNet:metadataNet withUser:activeUser withUserID:activeUserID withPassword:activePassword withUrl:activeUrl];
        
    _networkingOperationQueue.maxConcurrentOperationCount = k_maxConcurrentOperation;
    [_networkingOperationQueue addOperation:operation];
}

// MARK: - Read Folder

- (void)readFileFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    [self readFolder];
}

- (void)readFileSuccess:(CCMetadataNet *)metadataNet metadata:(tableMetadata *)metadata
{
    if ([metadataNet.selector isEqualToString:selectorReadFileReloadFolder]) {
        
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", metadataNet.account, metadataNet.serverUrl]];
        
        if ([metadata.etag isEqualToString:directory.etag] == NO) {
            
            [self readFolder];
        }
    }
}

- (void)readFileReloadFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    metadataNet.action = actionReadFile;
    metadataNet.priority = NSOperationQueuePriorityHigh;
    metadataNet.selector = selectorReadFileReloadFolder;
    metadataNet.serverUrl = _serverUrl;
    
    [self addNetworkingQueue:metadataNet];
}

// MARK: - Read Folder

- (void)readFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    _loadingFolder = NO;
    self.move.enabled = NO;
    
    [self.tableView reloadData];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)readFolderSuccess:(CCMetadataNet *)metadataNet metadataFolder:(tableMetadata *)metadataFolder metadatas:(NSArray *)metadatas
{
    NSMutableArray *metadatasToInsertInDB = [NSMutableArray new];
 
    // Update directory etag
    [[NCManageDatabase sharedInstance] setDirectoryWithServerUrl:metadataNet.serverUrl serverUrlTo:nil etag:metadataFolder.etag fileID:metadataFolder.fileID encrypted:metadataFolder.e2eEncrypted];
    
    for (tableMetadata *metadata in metadatas) {
        
        // Insert in Array
        [metadatasToInsertInDB addObject:metadata];
    }

    // insert in Database
    metadatas = [[NCManageDatabase sharedInstance] addMetadatas:metadatasToInsertInDB serverUrl:metadataNet.serverUrl];

    // get auto upload folder
    _autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    _autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:activeUrl];
    
    _loadingFolder = NO;
    
    [self.tableView reloadData];
}

- (void)readFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    metadataNet.action = actionReadFolder;
    metadataNet.date = nil;
    metadataNet.depth = @"1";
    metadataNet.selector = selectorReadFolder;
    metadataNet.serverUrl = _serverUrl;
    
    [self addNetworkingQueue:metadataNet];
    
    //
    _loadingFolder = YES;
    [self.tableView reloadData];
}

// MARK: - Create Folder

- (void)createFolderFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_error_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    }]];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)createFolderSuccess:(CCMetadataNet *)metadataNet
{
    (void)[[NCManageDatabase sharedInstance] addDirectoryWithServerUrl:[NSString stringWithFormat:@"%@/%@", metadataNet.serverUrl, metadataNet.fileName] permissions:nil encrypted:false];
    
    // Load Folder or the Datasource
    [self readFolder];
}

- (void)createFolder:(NSString *)fileNameFolder
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:activeAccount];
    
    fileNameFolder = [CCUtility removeForbiddenCharactersServer:fileNameFolder];
    if (![fileNameFolder length]) return;
    
    metadataNet.action = actionCreateFolder;
    metadataNet.fileName = fileNameFolder;
    metadataNet.selector = selectorCreateFolder;
    metadataNet.selectorPost = selectorReadFolderForced;
    metadataNet.serverUrl = _serverUrl;
    
    [self addNetworkingQueue:metadataNet];
}

// MARK: - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    if (!directoryID) return 0;
    NSPredicate *predicate;
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account == %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    
    NSArray *result = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:predicate sorted:nil ascending:NO];
    
    if (result)
        return [result count];
    else
        return 0;    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSPredicate *predicate;
    
    static NSString *CellIdentifier = @"MyCustomCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    if (!directoryID)
        return cell;
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicate sorted:@"fileName" ascending:YES index:indexPath.row];
    
    // colors
    cell.textLabel.textColor = [UIColor blackColor];
    
    cell.detailTextLabel.text = @"";
    
    if (metadata.e2eEncrypted)
        cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderEncrypted"] color:[NCBrandColor sharedInstance].brandElement];
    else if ([metadata.fileName isEqualToString:_autoUploadFileName] && [self.serverUrl isEqualToString:_autoUploadDirectory])
        cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folderphotocamera"] color:[NCBrandColor sharedInstance].brandElement];
    else
        cell.imageView.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] color:[NCBrandColor sharedInstance].brandElement];
    
    cell.textLabel.text = metadata.fileNameView;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self performSegueDirectoryWithControlPasscode:YES];
}

// MARK: - Navigation

- (void)performSegueDirectoryWithControlPasscode:(BOOL)controlPasscode
{
    NSString *nomeDir;
    NSPredicate *predicate;

    NSIndexPath *index = [self.tableView indexPathForSelectedRow];
    NSString *directoryID = [[NCManageDatabase sharedInstance] getDirectoryID:_serverUrl];
    if (!directoryID) return;
    
    if (self.onlyClearDirectory) predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID = %@ AND directory = true", activeAccount, directoryID];
    else predicate = [NSPredicate predicateWithFormat:@"account = %@ AND directoryID == %@ AND directory = true", activeAccount, directoryID];
    
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataAtIndexWithPredicate:predicate sorted:@"fileName" ascending:YES index:index.row];
    
    // lockServerUrl
    NSString *lockServerUrl = [CCUtility stringAppendServerUrl:_serverUrl addFileName:metadata.fileName];
        
    // Se siamo in presenza di una directory bloccata E è attivo il block E la sessione PASSWORD Lock è senza data ALLORA chiediamo la password per procedere
        
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account = %@ AND serverUrl = %@", activeAccount, lockServerUrl]];
        
    if (directory.lock && [[CCUtility getBlockCode] length] && controlPasscode) {
            
        CCBKPasscode *viewController = [[CCBKPasscode alloc] initWithNibName:nil bundle:nil];
        viewController.delegate = self;
        //viewController.fromType = CCBKPasscodeFromLockDirectory;
        viewController.type = BKPasscodeViewControllerCheckPasscodeType;
        viewController.inputViewTitlePassword = YES;
            
        if ([CCUtility getSimplyBlockCode]) {
                
            viewController.passcodeStyle = BKPasscodeInputViewNumericPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 6;
                
        } else {
                
            viewController.passcodeStyle = BKPasscodeInputViewNormalPasscodeStyle;
            viewController.passcodeInputView.maximumLength = 64;
        }
            
        BKTouchIDManager *touchIDManager = [[BKTouchIDManager alloc] initWithKeychainServiceName:k_serviceShareKeyChain];
        touchIDManager.promptText = NSLocalizedString(@"_scan_fingerprint_", nil);
        viewController.touchIDManager = touchIDManager;
        
        viewController.title = NSLocalizedString(@"_folder_blocked_", nil);
        viewController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(passcodeViewCloseButtonPressed:)];
        viewController.navigationItem.leftBarButtonItem.tintColor = [UIColor blackColor];
        
        UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:viewController];
        [self presentViewController:navController animated:YES completion:nil];
            
        return;
    }
        
    nomeDir = metadata.fileName;
    
    CCMove *viewController = [[UIStoryboard storyboardWithName:@"CCMove" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMoveVC"];
    
    viewController.delegate = self.delegate;
    viewController.onlyClearDirectory = self.onlyClearDirectory;
    viewController.move.title = self.move.title;
    viewController.networkingOperationQueue = _networkingOperationQueue;

    viewController.passMetadata = metadata;
    viewController.serverUrl = [CCUtility stringAppendServerUrl:_serverUrl addFileName:nomeDir];
    
    [self.navigationController pushViewController:viewController animated:YES];
}

@end

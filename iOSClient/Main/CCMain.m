//
//  CCMain.m
//  Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "CCMain.h"
#import "AppDelegate.h"
#import "CCSynchronize.h"
#import "OCActivity.h"
#import "OCNotifications.h"
#import "OCNotificationsAction.h"
#import "OCFrameworkConstants.h"
#import "OCCapabilities.h"
#import "NCAutoUpload.h"
#import "NCBridgeSwift.h"
#import "NCNetworkingEndToEnd.h"
#import "PKDownloadButton.h"

@interface CCMain () <UITextViewDelegate, createFormUploadAssetsDelegate, MGSwipeTableCellDelegate, NCSelectDelegate, UITextFieldDelegate, UIAdaptivePresentationControllerDelegate>
{
    AppDelegate *appDelegate;
        
    BOOL _isRoot;
    BOOL _isViewDidLoad;
    
    NSMutableDictionary *_selectedocIdsMetadatas;
    
    UIImageView *_imageTitleHome;
    
    NSUInteger _failedAttempts;
    NSDate *_lockUntilDate;

    UIRefreshControl *refreshControl;

    CCHud *_hud;
    
    // Datasource
    CCSectionDataSourceMetadata *sectionDataSource;
    NSDate *_dateReadDataSource;
    
    // Search
    NSString *_searchFileName;
    NSMutableArray *_searchResultMetadatas;
    NSString *_noFilesSearchTitle;
    NSString *_noFilesSearchDescription;
    NSTimer *_timerWaitInput;

    // Automatic Upload Folder
    NSString *_autoUploadFileName;
    NSString *_autoUploadDirectory;
    
    // Folder
    BOOL _loadingFolder;
    tableMetadata *_metadataFolder;
    
    CGFloat heightRichWorkspace;
    CGFloat heightSearchBar;
}
@end

@implementation CCMain

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{    
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        appDelegate.activeMain = self;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initializeMain:) name:k_notificationCenter_initializeMain object:nil];
    }
    
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // init object
    self.metadata = [tableMetadata new];
    _hud = [[CCHud alloc] initWithView:[[[UIApplication sharedApplication] delegate] window]];
    _selectedocIdsMetadatas = [NSMutableDictionary new];
    _isViewDidLoad = YES;
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchResultMetadatas = [NSMutableArray new];
    _searchFileName = @"";
    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = @"";
    _cellFavouriteImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"favorite"] width:50 height:50 color:[UIColor whiteColor]];
    _cellTrashImage = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"trash"] width:50 height:50 color:[UIColor whiteColor]];
    
    // delegate
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.searchController.delegate = self;
    self.searchController.searchBar.delegate = self;
    
    // Notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clearDateReadDataSource:) name:k_notificationCenter_clearDateReadDataSource object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setTitle) name:k_notificationCenter_setTitleMain object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(triggerProgressTask:) name:k_notificationCenter_progressTask object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(deleteFile:) name:k_notificationCenter_deleteFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(favoriteFile:) name:k_notificationCenter_favoriteFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(renameFile:) name:k_notificationCenter_renameFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(moveFile:) name:k_notificationCenter_moveFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(copyFile:) name:k_notificationCenter_copyFile object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createFolder:) name:k_notificationCenter_createFolder object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:k_notificationCenter_changeTheming object:nil];
    
    // Search
    self.definesPresentationContext = YES;
    self.searchController.searchResultsUpdater = self;
    self.searchController.dimsBackgroundDuringPresentation = NO;
    UIButton *searchButton = self.searchController.searchBar.subviews.firstObject.subviews.lastObject;
    if (searchButton && [searchButton isKindOfClass:[UIButton class]]) {
        [searchButton setTitleColor:NCBrandColor.sharedInstance.brand forState:UIControlStateNormal];
    }
    UITextField *searchTextField = [self.searchController.searchBar valueForKey:@"searchField"];
    if (searchTextField && [searchTextField isKindOfClass:[UITextField class]]) {
        searchTextField.textColor = NCBrandColor.sharedInstance.textView;
    }
            
    // Load Rich Workspace
    self.viewRichWorkspace = [[[NSBundle mainBundle] loadNibNamed:@"NCRichWorkspace" owner:self options:nil] firstObject];
    UITapGestureRecognizer *viewRichWorkspaceTapped = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(viewRichWorkspaceTapAction:)];
    viewRichWorkspaceTapped.numberOfTapsRequired = 1;
    viewRichWorkspaceTapped.delegate = self;
    [self.viewRichWorkspace.richView addGestureRecognizer:viewRichWorkspaceTapped];
    
    self.sortButton = self.viewRichWorkspace.sortButton;
    heightSearchBar = self.viewRichWorkspace.topView.frame.size.height;

    [self.sortButton setTitleColor:NCBrandColor.sharedInstance.brand forState:UIControlStateNormal];
    [self.sortButton addTarget:self action:@selector(toggleReMainMenu) forControlEvents:UIControlEventTouchUpInside];
    
    heightRichWorkspace = UIScreen.mainScreen.bounds.size.height / 4 + heightSearchBar;
    [self.viewRichWorkspace setFrame:CGRectMake(0, 0, self.tableView.frame.size.width, heightRichWorkspace)];
    self.navigationItem.searchController = self.searchController;
    self.searchController.hidesNavigationBarDuringPresentation = true;
    self.navigationController.navigationBar.prefersLargeTitles = true;
    self.navigationItem.hidesSearchBarWhenScrolling = true;
    [self.navigationController.navigationBar sizeToFit];

    // Table Header View
    [self.tableView setTableHeaderView:self.viewRichWorkspace];

    // Register cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMain" bundle:nil] forCellReuseIdentifier:@"CellMain"];
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellMainTransfer" bundle:nil] forCellReuseIdentifier:@"CellMainTransfer"];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, 35, 0);

    // long press recognizer TableView
    UILongPressGestureRecognizer* longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPressTableView:)];
    [self.tableView addGestureRecognizer:longPressRecognizer];
    
    // Pull-to-Refresh
    [self createRefreshControl];
    
    // Register for 3D Touch Previewing if available
    if ([self.traitCollection respondsToSelector:@selector(forceTouchCapability)] && (self.traitCollection.forceTouchCapability == UIForceTouchCapabilityAvailable)) {
        [self registerForPreviewingWithDelegate:self sourceView:self.view];
    }

    // if this is not Main (the Main uses inizializeMain)
    if (_isRoot == NO && appDelegate.activeAccount.length > 0) {
        // Read (File) Folder
        [self readFileReloadFolder];
    }
    
    // Title
    [self setTitle];
    // changeTheming
    [self changeTheming];
}

- (void)willDismissSearchController:(UISearchController *)searchController
{
    [self.tableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)willPresentSearchController:(UISearchController *)searchController
{
    [self updateNavBarShadow:self.tableView force:true];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateNavBarShadow:self.tableView force:false];
    if(_isViewDidLoad) {
        self.navigationItem.hidesSearchBarWhenScrolling = false;
    }
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    if (_isSelectedMode)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    // If not editing mode remove _selectedocIds
    if (!self.tableView.editing)
        [_selectedocIdsMetadatas removeAllObjects];

    // Check server URL "/"
    if (self.navigationController.viewControllers.firstObject == self && self.serverUrl == nil) {
        self.serverUrl = [CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl];
    }
    
    // Query data source
    if (self.searchController.isActive == false) {
        [self queryDatasourceWithReloadData:YES serverUrl:self.serverUrl];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if(_isViewDidLoad) {
        self.navigationItem.hidesSearchBarWhenScrolling = true;
    }
    // Active Main
    appDelegate.activeMain = self;
    
    // Test viewDidLoad
    if (_isViewDidLoad) {
        
        _isViewDidLoad = NO;
        
    } else {
        
        if (appDelegate.activeAccount.length > 0 && [_selectedocIdsMetadatas count] == 0) {
            // Read (file) Folder
            [self readFileReloadFolder];
        }
    }

    if (appDelegate.activeAccount.length > 0 && self.serverUrl != nil) {
        
        // Get Shares
        appDelegate.shares = [[NCManageDatabase sharedInstance] getTableSharesWithAccount:appDelegate.activeAccount serverUrl:self.serverUrl];
        
        // Get RichWorkspace
        tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, self.serverUrl]];
        self.richWorkspaceText = directory.richWorkspace;
    }
    
    // Title
    [self setTitle];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void) viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self setTableViewHeader];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self setTableViewHeader];
    } completion:nil];
}

- (void)presentationControllerWillDismiss:(UIPresentationController *)presentationController
{
    [self viewDidAppear:true];
}

- (BOOL)prefersStatusBarHidden
{
    return NO;
}

// detect scroll for remove keyboard in search mode
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    if (self.searchController.isActive && scrollView == self.tableView) {
        
        [self.searchController.searchBar endEditing:YES];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self updateNavBarShadow:self.tableView force:false];
}

- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:self.tableView collectionView:nil form:false];
    
    // createImagesThemingColor
    [[NCMainCommon sharedInstance] createImagesThemingColor];
    
    // Refresh control
    refreshControl.tintColor = UIColor.lightGrayColor;
    refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView;

    [self.sortButton setTitleColor:NCBrandColor.sharedInstance.brand forState:UIControlStateNormal];
    // color searchbar
    self.searchController.searchBar.tintColor = NCBrandColor.sharedInstance.brand;
    // color searchbbar button text (cancel)
    UIButton *searchButton = self.searchController.searchBar.subviews.firstObject.subviews.lastObject;
    if (searchButton && [searchButton isKindOfClass:[UIButton class]]) {
        [searchButton setTitleColor:NCBrandColor.sharedInstance.brand forState:UIControlStateNormal];
    }
    // color textview searchbbar
    UITextField *searchTextView = [self.searchController.searchBar valueForKey:@"searchField"];
    if (searchTextView && [searchTextView isKindOfClass:[UITextField class]]) {
        searchTextView.textColor = NCBrandColor.sharedInstance.textView;
    }
    
    // Rich Workspace
    [self.viewRichWorkspace loadWithRichWorkspaceText:self.richWorkspaceText];
    
    // Title
    [self setTitle];
    
    // Reload Table View
    [self tableViewReloadData];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Initialization =====
#pragma --------------------------------------------------------------------------------------------

//
// Callers :
//
// ChangeDefaultAccount (delegate)
// Split : inizialize
// Settings Advanced : removeAllFiles
//
- (void)initializeMain:(NSNotification *)notification
{
    _dateReadDataSource = nil;
    
    // test
    if (appDelegate.activeAccount.length == 0)
        return;
    
    if ([appDelegate.listMainVC count] == 0 || _isRoot) {
        
        // This is Root home main add list
        appDelegate.homeMain = self;
        _isRoot = YES;
        _serverUrl = [CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl];
        [appDelegate.listMainVC setObject:self forKey:_serverUrl];
        
        // go Home
        [self.navigationController popToRootViewControllerAnimated:NO];
                
        // Remove search mode
        [self cancelSearchBar];
        
        // Clear error certificate
        [CCUtility setCertificateError:appDelegate.activeAccount error:NO];
        
        // Setting Theming
        [appDelegate settingThemingColorBrand];
        
        // Detail
        // If AVPlayer in play -> Stop
        if (appDelegate.player != nil && appDelegate.player.rate != 0) {
            [appDelegate.player pause];
        }
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_menuDetailClose object:nil];
                        
        // Not Photos Video in library ? then align and Init Auto Upload
        NSArray *recordsPhotoLibrary = [[NCManageDatabase sharedInstance] getPhotoLibraryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@", appDelegate.activeAccount]];
        if ([recordsPhotoLibrary count] == 0) {
            [[NCAutoUpload sharedInstance] alignPhotoLibrary];
        }
        [[NCAutoUpload sharedInstance] initStateAutoUpload];
        
        NSLog(@"[LOG] Request Service Server Nextcloud");
        [[NCService sharedInstance] startRequestServicesServer];
        
        // Clear datasorce
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:_serverUrl ocId:nil action:k_action_NULL];
        
        // Read this folder
        [self readFileReloadFolder];
                
    } else {
        
        // reload datasource
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:_serverUrl ocId:nil action:k_action_NULL];
    }
    
    // Registeration push notification
    [appDelegate pushNotification];
    
    // Registeration domain File Provider
    if (k_fileProvider_domain) {
        [FileProviderDomain.sharedInstance registerDomain];
    } else {
        [FileProviderDomain.sharedInstance removeAllDomain];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== NotificationCenter ====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteFile:(NSNotification *)notification
{
    if (self.view.window == nil) { return; }
    
    NSDictionary *userInfo = notification.userInfo;
    tableMetadata *metadata = userInfo[@"metadata"];
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    
    if (errorCode == 0 && metadata) {
        if ([metadata.serverUrl isEqualToString:self.serverUrl]) {
            if ([metadata.fileNameView.lowercaseString isEqualToString:k_fileNameRichWorkspace.lowercaseString]) {
                [self readFileReloadFolder];
            } else {
                if (self.searchController.isActive) {
                    [self readFolder:self.serverUrl];
                } else {
                    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
                }
            }
        }
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

- (void)moveFile:(NSNotification *)notification
{
    if (self.view.window == nil) { return; }
    
    NSDictionary *userInfo = notification.userInfo;
    tableMetadata *metadata = userInfo[@"metadata"];
    tableMetadata *metadataNew = userInfo[@"metadataNew"];
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    
    if (errorCode == 0) {
        if ([metadata.serverUrl isEqualToString:self.serverUrl] || [metadataNew.serverUrl isEqualToString:self.serverUrl]) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
        }
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

- (void)copyFile:(NSNotification *)notification
{
    if (self.view.window == nil) { return; }
    
    NSDictionary *userInfo = notification.userInfo;
    tableMetadata *metadata = userInfo[@"metadata"];
    NSString *serverUrlTo = userInfo[@"serverUrlTo"];
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    
    if (errorCode == 0) {
        if ([metadata.serverUrl isEqualToString:self.serverUrl] || [serverUrlTo isEqualToString:self.serverUrl]) {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
        }
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

- (void)favoriteFile:(NSNotification *)notification
{
    if (self.view.window == nil) { return; }
    
    NSDictionary *userInfo = notification.userInfo;
    tableMetadata *metadata = userInfo[@"metadata"];
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    BOOL favorite = [userInfo[@"favorite"] boolValue];
    
    if (errorCode == 0) {
        _dateReadDataSource = nil;
        if (self.searchController.isActive) {
            [self readFolder:self.serverUrl];
        } else {
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:metadata.ocId action:k_action_MOD];
        }
        
        if (metadata.directory && favorite) {
                       
            NSString *selector;
                       
            if ([CCUtility getFavoriteOffline])
                selector = selectorReadFolderWithDownload;
            else
                selector = selectorReadFolder;
                       
            [[CCSynchronize sharedSynchronize] readFolder:[CCUtility stringAppendServerUrl:self.serverUrl addFileName:metadata.fileName] selector:selector account:appDelegate.activeAccount];
        }
                   
        if (!metadata.directory && favorite && [CCUtility getFavoriteOffline]) {
                       
            metadata.favorite = favorite;
            metadata.session = k_download_session;
            metadata.sessionError = @"";
            metadata.sessionSelector = selectorDownloadSynchronize;
            metadata.status = k_metadataStatusWaitDownload;
                           
            // Add Metadata for Download
            [[NCManageDatabase sharedInstance] addMetadata:metadata];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:metadata.ocId action:k_action_MOD];
                    
            [appDelegate startLoadAutoDownloadUpload];
        }
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

- (void)renameFile:(NSNotification *)notification {
    if (self.view.window == nil) { return; }

    NSDictionary *userInfo = notification.userInfo;
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    
    if (errorCode == 0) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

- (void)createFolder:(NSNotification *)notification {
    if (self.view.window == nil) { return; }
    
    NSDictionary *userInfo = notification.userInfo;
    NSInteger errorCode = [userInfo[@"errorCode"] integerValue];
    NSString *errorDescription = userInfo[@"errorDescription"];
    
    if (errorCode == 0) {
        [self reloadDatasource:self.serverUrl ocId:nil action:k_action_NULL];
    } else {
        [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldAllowScroll:(UIScrollView *)scrollView
{
    if (_loadingFolder)
        return NO;
    else
        return YES;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return NCBrandColor.sharedInstance.backgroundView;
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    if (self.searchController.isActive)
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"search"] width:300 height:300 color:NCBrandColor.sharedInstance.brandElement];
    else
        return [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"folder"] width:300 height:300 color:NCBrandColor.sharedInstance.brandElement];
}

- (UIView *)customViewForEmptyDataSet:(UIScrollView *)scrollView
{
    if (_loadingFolder && refreshControl.isRefreshing == NO) {
    
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        activityView.transform = CGAffineTransformMakeScale(1.5f, 1.5f);
        activityView.color = NCBrandColor.sharedInstance.brandElement;
        [activityView startAnimating];
        
        return activityView;
    }
    
    return nil;
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (self.searchController.isActive) {
        
        text = _noFilesSearchTitle;
        
    } else {
        
        text = [NSString stringWithFormat:@"%@", NSLocalizedString(@"_files_no_files_", nil)];
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:[UIColor lightGrayColor]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if (self.searchController.isActive) {
        
        text = _noFilesSearchDescription;
        
    } else {
        
        text = [NSString stringWithFormat:@"\n%@", NSLocalizedString(@"_no_file_pull_down_", nil)];
    }
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Text Field =====
#pragma --------------------------------------------------------------------------------------------

- (void)minCharTextFieldDidChange:(UITextField *)sender
{
    UIAlertController *alertController = (UIAlertController *)self.presentedViewController;
    
    if (alertController)
    {
        UITextField *fileName = alertController.textFields.firstObject;
        UIAlertAction *okAction = alertController.actions.lastObject;
        okAction.enabled = fileName.text.length > 0;
    }
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    [CCUtility selectFileNameFrom:textField];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Graphic Window =====
#pragma --------------------------------------------------------------------------------------------

- (void)createRefreshControl
{
    refreshControl = [NCMainRefreshControl new];
    
    self.tableView.refreshControl = refreshControl;
    
    refreshControl.tintColor = UIColor.lightGrayColor;
    refreshControl.backgroundColor = NCBrandColor.sharedInstance.backgroundView;
    [refreshControl addTarget:self action:@selector(refreshControlTarget) forControlEvents:UIControlEventValueChanged];
}

- (void)deleteRefreshControl
{
    [refreshControl endRefreshing];
    
    for (UIView *subview in [_tableView subviews]) {
        if (subview == refreshControl)
            [subview removeFromSuperview];
    }
    
    refreshControl = nil;
}

- (void)refreshControlTarget
{
    [self readFolder:_serverUrl];
    
    // Actuate `Peek` feedback (weak boom)
    AudioServicesPlaySystemSound(1519);
}

- (void)setTitle
{
    if (_isSelectedMode) {
        
        NSUInteger totali = [sectionDataSource.allRecordsDataSource count];
        NSUInteger selezionati = [[self.tableView indexPathsForSelectedRows] count];
        
        self.navigationItem.titleView = nil;
        self.navigationItem.title = [NSString stringWithFormat:@"%@ : %lu / %lu", NSLocalizedString(@"_selected_", nil), (unsigned long)selezionati, (unsigned long)totali];

    } else {
       
        self.navigationController.navigationBar.prefersLargeTitles = true;
        
        if (_isRoot) {
            self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAlways;
            self.navigationItem.title = NCBrandOptions.sharedInstance.brand;
        } else {
            self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
            self.navigationItem.title = _titleMain;
        }
    }
    
    [self SetSortButtonText];
}

- (void)setUINavigationBarDefault
{
    UIBarButtonItem *buttonSelect = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_select_", @"") style:UIBarButtonItemStylePlain target:self action:@selector(tableViewToggle)];
    
    self.navigationController.navigationBar.hidden = NO;

    self.navigationItem.rightBarButtonItem = buttonSelect;
    self.navigationItem.leftBarButtonItem = nil;
}

- (void)setUINavigationBarSelected
{    
    UIBarButtonItem *buttonMore = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"navigationMore"] style:UIBarButtonItemStylePlain target:self action:@selector(toggleReSelectMenu)];
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIBarButtonItemStylePlain target:self action:@selector(cancelSelect)];
    
    self.navigationItem.leftBarButtonItem = leftButton;
    self.navigationItem.rightBarButtonItem = buttonMore; //[[NSArray alloc] initWithObjects:buttonMore, nil];
}

- (void)cancelSelect
{
    [self tableViewSelect:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Document Picker =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentMenuWasCancelled:(UIDocumentMenuViewController *)documentMenu
{
    NSLog(@"[LOG] Cancelled");
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
    NSLog(@"[LOG] Cancelled");
}

- (void)documentMenu:(UIDocumentMenuViewController *)documentMenu didPickDocumentPicker:(UIDocumentPickerViewController *)documentPicker
{
    documentPicker.delegate = self;
    [self presentViewController:documentPicker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
    if (controller.documentPickerMode == UIDocumentPickerModeImport) {
        
        NSFileCoordinator *coordinator = [[NSFileCoordinator alloc] initWithFilePresenter:nil];
        __block NSError *error;
        
        [coordinator coordinateReadingItemAtURL:url options:NSFileCoordinatorReadingForUploading error:&error byAccessor:^(NSURL *newURL) {
            
            NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
            NSString *fileName =  [url lastPathComponent];
            NSString *ocId = [[NSUUID UUID] UUIDString];
            NSData *data = [NSData dataWithContentsOfURL:newURL];
            
            if (data && error == nil) {
                
                if ([data writeToFile:[CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileName] options:NSDataWritingAtomic error:&error]) {
                    
                    tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.activeAccount fileName:fileName ocId:ocId serverUrl:serverUrl url:@"" contentType:@""];
                    
                    metadataForUpload.session = k_upload_session;
                    metadataForUpload.sessionSelector = selectorUploadFile;
                    metadataForUpload.size = data.length;
                    metadataForUpload.status = k_metadataStatusWaitUpload;
                    
                    if ([[NCUtility sharedInstance] getMetadataConflictWithAccount:appDelegate.activeAccount serverUrl:serverUrl fileName:fileName] != nil) {
                       
                        NCCreateFormUploadConflict *conflict = [[UIStoryboard storyboardWithName:@"NCCreateFormUploadConflict" bundle:nil] instantiateInitialViewController];
                        conflict.serverUrl = self.serverUrl;
                        conflict.metadatasUploadInConflict = @[metadataForUpload];
                        
                        [self presentViewController:conflict animated:YES completion:nil];
                        
                    } else {
                        
                        [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
                            
                        [appDelegate startLoadAutoDownloadUpload];
                    }

                } else {
                                        
                    [[NCContentPresenter shared] messageNotification:@"_error_" description:error.description delay:k_dismissAfterSecond type:messageTypeError errorCode:error.code];
                }
                
            } else {
                
                [[NCContentPresenter shared] messageNotification:@"_error_" description:@"_read_file_error_" delay:k_dismissAfterSecond type:messageTypeError errorCode:error.code];
            }
        }];
    }
}

- (void)openImportDocumentPicker
{
    UIDocumentMenuViewController *documentProviderMenu = [[UIDocumentMenuViewController alloc] initWithDocumentTypes:@[@"public.data"] inMode:UIDocumentPickerModeImport];
    
    documentProviderMenu.modalPresentationStyle = UIModalPresentationFormSheet;
    documentProviderMenu.popoverPresentationController.sourceView = self.tabBarController.tabBar;
    documentProviderMenu.popoverPresentationController.sourceRect = self.tabBarController.tabBar.bounds;
    documentProviderMenu.delegate = self;
    
    [self presentViewController:documentProviderMenu animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Assets Picker =====
#pragma --------------------------------------------------------------------------------------------

-(void)dismissFormUploadAssets
{
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
}

- (void)openAssetsPickerController
{
    NCPhotosPickerViewController *viewController = [[NCPhotosPickerViewController alloc] init:self maxSelectedAssets:100 singleSelectedMode:false];
    
    [viewController openPhotosPickerViewControllerWithPhAssets:^(NSArray<PHAsset *> * _Nullable assets, NSArray<NSURL *> * urls) {
        if (assets.count > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
                
                NCCreateFormUploadAssets *form = [[NCCreateFormUploadAssets alloc] initWithServerUrl:serverUrl assets:(NSMutableArray *)assets urls:(NSMutableArray *)urls cryptated:NO session:k_upload_session delegate:self];
                
                UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:form];
                [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
                
                [self presentViewController:navigationController animated:YES completion:nil];
            });
        }
    }];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Save selected File =====
#pragma --------------------------------------------------------------------------------------------

- (void)saveToPhotoAlbum:(tableMetadata *)metadata
{
    NSString *fileNamePath = [CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView];
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] && status == PHAuthorizationStatusAuthorized) {
        
        UIImage *image = [UIImage imageWithContentsOfFile:fileNamePath];
        
        if (image)
            UIImageWriteToSavedPhotosAlbum(image, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
        else
            [[NCContentPresenter shared] messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError];
    }
    
    if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video] && status == PHAuthorizationStatusAuthorized) {
        
        if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(fileNamePath)) {
            
            UISaveVideoAtPathToSavedPhotosAlbum(fileNamePath, self, @selector(saveSelectedFilesSelector: didFinishSavingWithError: contextInfo:), nil);
        } else {
            [[NCContentPresenter shared] messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" delay:k_dismissAfterSecond type:messageTypeError errorCode:k_CCErrorInternalError];
        }
    }
    
    if (status != PHAuthorizationStatusAuthorized) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_access_photo_not_enabled_", nil) message:NSLocalizedString(@"_access_photo_not_enabled_msg_", nil) preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
        
        [alertController addAction:okAction];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)saveSelectedFilesSelector:(NSString *)path didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if (error) {
        [[NCContentPresenter shared] messageNotification:@"_save_selected_files_" description:@"_file_not_saved_cameraroll_" delay:k_dismissAfterSecond type:messageTypeError errorCode:error.code];
    }
}

- (void)saveSelectedFiles
{
    if (_isSelectedMode && [_selectedocIdsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected files ...");
    
    [_hud visibleHudTitle:@"" mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *metadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in metadatas) {
            
            if (metadata.directory == NO && ([metadata.typeFile isEqualToString: k_metadataTypeFile_image] || [metadata.typeFile isEqualToString: k_metadataTypeFile_video])) {
                
                metadata.session = k_download_session;
                metadata.sessionError = @"";
                metadata.sessionSelector = selectorSave;
                metadata.status = k_metadataStatusWaitDownload;
                    
                // Add Metadata for Download
                [[NCManageDatabase sharedInstance] addMetadata:metadata];
                
                [appDelegate startLoadAutoDownloadUpload];
            }
        }
        
        [_hud hideHud];
        
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    });
    
    [self tableViewSelect:false];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Peek & Pop  =====
#pragma --------------------------------------------------------------------------------------------

- (UIViewController *)previewingContext:(id<UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location
{
    CGPoint convertedLocation = [self.view convertPoint:location toView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:convertedLocation];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        
    if (cell) {
        previewingContext.sourceRect = cell.frame;
        CCPeekPop *viewController = [[UIStoryboard storyboardWithName:@"CCPeekPop" bundle:nil] instantiateViewControllerWithIdentifier:@"PeekPopImagePreview"];
            
        viewController.metadata = metadata;
        viewController.imageFile = cell.file.image;
        viewController.showOpenIn = true;
        viewController.showShare = true;
        viewController.showOpenQuickLook = [[NCUtility sharedInstance] isQuickLookDisplayableWithMetadata:metadata];
        
        return viewController;
    }
    
    return nil;
}

- (void)previewingContext:(id<UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit
{
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:previewingContext.sourceRect.origin];
    
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadSelectedFilesFolders
{
    if (_isSelectedMode && [_selectedocIdsMetadatas count] == 0)
        return;

    NSLog(@"[LOG] Start download selected ...");
    
    [_hud visibleHudTitle:NSLocalizedString(@"_downloading_progress_", nil) mode:MBProgressHUDModeIndeterminate color:nil];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        
        for (tableMetadata *metadata in selectedMetadatas) {
            
            if (metadata.directory) {
                
                [[CCSynchronize sharedSynchronize] readFolder:[CCUtility stringAppendServerUrl:metadata.serverUrl addFileName:metadata.fileName] selector:selectorReadFolderWithDownload account:appDelegate.activeAccount];
                    
            } else {
                
                [[CCSynchronize sharedSynchronize] readFile:metadata.ocId fileName:metadata.fileName serverUrl:metadata.serverUrl selector:selectorReadFileWithDownload account:appDelegate.activeAccount];
            }
        }
        
        [_hud hideHud];
    });
    
    [self tableViewSelect:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Upload new Photos/Videos =====
#pragma --------------------------------------------------------------------------------------------

//
// This procedure with performSelectorOnMainThread it's necessary after (Bridge) for use the function "Sync" in OCNetworking
//
- (void)uploadFileAsset:(NSMutableArray *)assets urls:(NSMutableArray *)urls serverUrl:(NSString *)serverUrl useSubFolder:(BOOL)useSubFolder session:(NSString *)session
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
 
        NSString *autoUploadPath = [[NCManageDatabase sharedInstance] getAccountAutoUploadPath:appDelegate.activeUrl];

        // if request create the folder for Auto Upload & the subfolders
        if ([autoUploadPath isEqualToString:serverUrl])
            if (![[NCAutoUpload sharedInstance] createAutoUploadFolderWithSubFolder:useSubFolder assets:(PHFetchResult *)assets selector:selectorUploadFile])
                return;
    
        dispatch_async(dispatch_get_main_queue(), ^{
            [self uploadFileAsset:assets urls:urls serverUrl:serverUrl autoUploadPath:autoUploadPath useSubFolder:useSubFolder session:session];
        });
    });
}

- (void)uploadFileAsset:(NSArray *)assets urls:(NSArray *)urls serverUrl:(NSString *)serverUrl autoUploadPath:(NSString *)autoUploadPath useSubFolder:(BOOL)useSubFolder session:(NSString *)session
{
    NSMutableArray *metadatasNOConflict = [NSMutableArray new];
    NSMutableArray *metadatasMOV = [NSMutableArray new];
    NSMutableArray *metadatasUploadInConflict = [NSMutableArray new];

    for (PHAsset *asset in assets) {
        
        NSString *fileName = [CCUtility createFileName:[asset valueForKey:@"filename"] fileDate:asset.creationDate fileType:asset.mediaType keyFileName:k_keyFileNameMask keyFileNameType:k_keyFileNameType keyFileNameOriginal:k_keyFileNameOriginal];
        
        NSDate *assetDate = asset.creationDate;
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        
        // Create serverUrl if use sub folder
        if (useSubFolder) {
            
            [formatter setDateFormat:@"yyyy"];
            NSString *yearString = [formatter stringFromDate:assetDate];
        
            [formatter setDateFormat:@"MM"];
            NSString *monthString = [formatter stringFromDate:assetDate];
            
            serverUrl = [NSString stringWithFormat:@"%@/%@/%@", autoUploadPath, yearString, monthString];
        }
        
        // Check if is in upload
        NSArray *isRecordInSessions = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileName == %@ AND session != ''", appDelegate.activeAccount, serverUrl, fileName] sorted:nil ascending:NO];
        if ([isRecordInSessions count] > 0)
            continue;
        
        // Prepare record metadata
        tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.activeAccount fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl url:@"" contentType:@""];
        
        metadataForUpload.assetLocalIdentifier = asset.localIdentifier;
        metadataForUpload.session = session;
        metadataForUpload.sessionSelector = selectorUploadFile;
        metadataForUpload.size = [[NCUtility sharedInstance] getFileSizeWithAsset:asset];
        metadataForUpload.status = k_metadataStatusWaitUpload;
                        
        if ([[NCUtility sharedInstance] getMetadataConflictWithAccount:appDelegate.activeAccount serverUrl:serverUrl fileName:fileName] != nil) {
            [metadatasUploadInConflict addObject:metadataForUpload];
        } else {
            [metadatasNOConflict addObject:metadataForUpload];
        }
        
        // Add Medtadata MOV LIVE PHOTO for upload
        if ((asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive || asset.mediaSubtypes == PHAssetMediaSubtypePhotoLive+PHAssetMediaSubtypePhotoHDR) && CCUtility.getLivePhoto && urls.count == assets.count) {
                
            NSUInteger index = [assets indexOfObject:asset];
            NSURL *url = [urls objectAtIndex:index];
            NSString *fileNameNoExt = [fileName stringByDeletingPathExtension];
            NSString *fileName = [NSString stringWithFormat:@"%@.mov", fileNameNoExt];
            unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil] fileSize];

            tableMetadata *metadataMOVForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.activeAccount fileName:fileName ocId:[[NSUUID UUID] UUIDString] serverUrl:serverUrl url:@"" contentType:@""];
            
            metadataMOVForUpload.session = session;
            metadataMOVForUpload.sessionSelector = selectorUploadFile;
            metadataMOVForUpload.size = fileSize;
            metadataMOVForUpload.status = k_metadataStatusWaitUpload;
            
            // Prepare file and directory
            [CCUtility moveFileAtPath:url.path toPath:[CCUtility getDirectoryProviderStorageOcId:metadataMOVForUpload.ocId fileNameView:fileName]];
            
            [metadatasMOV addObject:metadataMOVForUpload];
        }
    }
    
    // Verify if file(s) exists
    if (metadatasUploadInConflict.count > 0) {
        
        NCCreateFormUploadConflict *conflict = [[UIStoryboard storyboardWithName:@"NCCreateFormUploadConflict" bundle:nil] instantiateInitialViewController];
        conflict.serverUrl = self.serverUrl;
        conflict.metadatasNOConflict = metadatasNOConflict;
        conflict.metadatasMOV = metadatasMOV;
        conflict.metadatasUploadInConflict = metadatasUploadInConflict;
        
        [self presentViewController:conflict animated:YES completion:nil];
        
    } else {
        
        [[NCManageDatabase sharedInstance] addMetadatas:metadatasNOConflict];
        [[NCManageDatabase sharedInstance] addMetadatas:metadatasMOV];
        
        [appDelegate startLoadAutoDownloadUpload];
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    }
}


#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Read Folder ====
#pragma --------------------------------------------------------------------------------------------

- (void)readFolder:(NSString *)serverUrl
{
    // init control
    if (!serverUrl || !appDelegate.activeAccount || appDelegate.maintenanceMode) {
        [refreshControl endRefreshing];
        return;
    }
    
    // Search Mode
    if (self.searchController.isActive) {
        
        [[NCManageDatabase sharedInstance] clearDateReadWithServerUrl:serverUrl account:appDelegate.activeAccount];
        _searchFileName = @""; // forced reload searchg
        [self updateSearchResultsForSearchController:self.searchController];
        
        return;
    }
    
    _loadingFolder = YES;

    [self tableViewReloadData];
    
    [[NCNetworking sharedInstance] readFolderWithServerUrl:serverUrl account:appDelegate.activeAccount completion:^(NSString *account, tableMetadata *metadataFolder, NSArray *metadatas, NSInteger errorCode, NSString *errorDescription) {
        
        [refreshControl endRefreshing];

        if (errorCode == 0 ) {
            
            _metadataFolder = metadataFolder;
            BOOL isFolderEncrypted = [CCUtility isFolderEncrypted:serverUrl e2eEncrypted:_metadataFolder.e2eEncrypted account:appDelegate.activeAccount];
            [self setTitle];
            

            // File is changed ??
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                [[CCSynchronize sharedSynchronize] verifyChangeMedatas:metadatas serverUrl:serverUrl account:account withDownload:NO];
            });
            
            // E2EE Is encrypted folder get metadata
            if (isFolderEncrypted) {
                NSString *metadataFolderFileId = metadataFolder.fileId;
                // Read Metadata
                if ([CCUtility isEndToEndEnabled:account]) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
                        NSString *metadata;
                        NSError *error = [[NCNetworkingEndToEnd sharedManager] getEndToEndMetadata:&metadata fileId:metadataFolderFileId user:appDelegate.activeUser userID:appDelegate.activeUserID password:[CCUtility getPassword:appDelegate.activeAccount] url:appDelegate.activeUrl];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (error) {
                                if (error.code != kOCErrorServerPathNotFound)
                                    [[NCContentPresenter shared] messageNotification:@"_e2e_error_get_metadata_" description:error.localizedDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:error.code];
                            } else {
                                if ([[NCEndToEndMetadata sharedInstance] decoderMetadata:metadata privateKey:[CCUtility getEndToEndPrivateKey:account] serverUrl:self.serverUrl account:account url:appDelegate.activeUrl] == false)
                                    [[NCContentPresenter shared] messageNotification:@"_error_e2ee_" description:@"_e2e_error_decode_metadata_" delay:k_dismissAfterSecond type:messageTypeError errorCode:error.code];
                                else
                                    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
                            }
                        });
                    });
                    
                } else {
                    [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
                }
            }
            
            if ([serverUrl isEqualToString:_serverUrl]) {
                [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:serverUrl ocId:nil action:k_action_NULL];
                [self tableViewReloadData];
            }
        
        } else {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        }
        
        _loadingFolder = NO;
    }];
}

- (void)readFileReloadFolder
{
    if (!_serverUrl || !appDelegate.activeAccount || appDelegate.maintenanceMode)
        return;
    
    // RichWorkspace
    tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, self.serverUrl]];
    self.richWorkspaceText = directory.richWorkspace;
    [self setTableViewHeader];
    
    // Load Datasource
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.001 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    });
    
    [[NCNetworking sharedInstance] readFileWithServerUrlFileName:self.serverUrl account:appDelegate.activeAccount completion:^(NSString *account, tableMetadata *metadata, NSInteger errorCode, NSString *errorDescription) {
        
        if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
            
            // Rich Workspace
            [[NCManageDatabase sharedInstance] setDirectoryWithOcId:metadata.ocId serverUrl:self.serverUrl richWorkspace:metadata.richWorkspace account:account];
            self.richWorkspaceText = metadata.richWorkspace;
            [self setTableViewHeader];
            
            tableDirectory *directory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", account, self.serverUrl]];
            
            // Read folder: No record, Change etag or BLINK
            if ([sectionDataSource.allRecordsDataSource count] == 0 || [metadata.etag isEqualToString:directory.etag] == NO || self.blinkFileNamePath != nil) {
                [self readFolder:self.serverUrl];
            }
            
        } else if (errorCode != 0) {
            [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        }
    }];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Search =====
#pragma --------------------------------------------------------------------------------------------

- (void)searchStartTimer
{
    if (self.searchController.isActive == false) {
        return;
    }
        
    [[NCCommunication sharedInstance] searchLiteralWithServerUrl:appDelegate.activeUrl depth:@"infinity" literal:_searchFileName showHiddenFiles:[CCUtility getShowHiddenFiles] customUserAgent:nil addCustomHeaders:nil user:appDelegate.activeUser account:appDelegate.activeAccount completionHandler:^(NSString *account, NSArray *files, NSInteger errorCode, NSString *errorDescription) {
        
         if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount] && files != nil) {
             
             [[NCManageDatabase sharedInstance] convertNCFilesToMetadatas:files useMetadataFolder:false account:account completion:^(tableMetadata *metadataFolder, NSArray<tableMetadata *> *metadatasFolder, NSArray<tableMetadata *> *metadatas) {
                 
                 NSMutableArray *metadatasDB = (NSMutableArray *)[[NCManageDatabase sharedInstance] addMetadatas:metadatas];
                 _searchResultMetadatas = [[NSMutableArray alloc] initWithArray:metadatasDB];
                 _metadataFolder = nil;
                 
                 [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:_serverUrl ocId:nil action:k_action_NULL];
                 [self tableViewReloadData];
                 [self setTitle];
             }];
                          
         } else {
             
             if (errorCode != 0) {
                 [[NCContentPresenter shared] messageNotification:@"_error_" description:errorDescription delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
             }
             
             _searchFileName = @"";
         }
        
    }];
    
    _noFilesSearchTitle = @"";
    _noFilesSearchDescription = NSLocalizedString(@"_search_in_progress_", nil);
    
    [self.tableView reloadEmptyDataSet];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    // Color text "Cancel"
    [[UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UISearchBar class]]] setTintColor:NCBrandColor.sharedInstance.brand];
    
    if (searchController.isActive) {
        [self deleteRefreshControl];
        
        NSString *fileName = [CCUtility removeForbiddenCharactersServer:searchController.searchBar.text];
        
        if (fileName.length >= k_minCharsSearch && [fileName isEqualToString:_searchFileName] == NO) {
            
            _searchFileName = fileName;
            _metadataFolder = nil;
            
            // First : filter
                
            NSArray *records = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileNameView CONTAINS[cd] %@", appDelegate.activeAccount, _serverUrl, fileName] sorted:nil ascending:NO];
                
            [_searchResultMetadatas removeAllObjects];
            for (tableMetadata *record in records) {
                [_searchResultMetadatas addObject:record];
            }
            
            // Version >= 12
            if ([[NCManageDatabase sharedInstance] getCapabilitiesServerVersionWithAccount:appDelegate.activeAccount element:@"major"] >= 12) {
                
                [_timerWaitInput invalidate];
                _timerWaitInput = [NSTimer scheduledTimerWithTimeInterval:1.5 target:self selector:@selector(searchStartTimer) userInfo:nil repeats:NO];
            }
            
            [self setTitle];
        }
        
        if (_searchResultMetadatas.count == 0 && fileName.length == 0) {

            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
        }
        
    } else {
        
        [self createRefreshControl];

        [self reloadDatasource:self.serverUrl ocId:nil action:k_action_NULL];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self cancelSearchBar];
}

- (void)cancelSearchBar
{
    if (self.searchController.active) {
        
        [self.searchController setActive:NO];
    
        _searchFileName = @"";
        _dateReadDataSource = nil;
        _searchResultMetadatas = [NSMutableArray new];
        
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    }

}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Delete File or Folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)deleteMetadatas
{
    if (_isSelectedMode && [_selectedocIdsMetadatas count] == 0)
        return;
     
    if ([_selectedocIdsMetadatas count] > 0) {
        [appDelegate.arrayDeleteMetadata addObjectsFromArray:[_selectedocIdsMetadatas allValues]];
    } else {
        [appDelegate.arrayDeleteMetadata addObject:self.metadata];
    }
    
    [[NCNetworking sharedInstance] deleteMetadata:appDelegate.arrayDeleteMetadata.firstObject account:appDelegate.activeAccount user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl completion:^(NSInteger errorCode, NSString *errorDescription) { }];
    [appDelegate.arrayDeleteMetadata removeObjectAtIndex:0];
        
    // End Select Table View
    [self tableViewSelect:false];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Move / Copy =====
#pragma --------------------------------------------------------------------------------------------

- (void)moveCopyFileOrFolderMetadata:(tableMetadata *)metadata serverUrlTo:(NSString *)serverUrlTo move:(BOOL)move overwrite:(BOOL)overwrite
{
    if (_isSelectedMode && [_selectedocIdsMetadatas count] == 0)
        return;
    
    NSMutableArray *arrayMetadata, *arrayServerUrlTo;
    
    if (move) {
        arrayMetadata = appDelegate.arrayMoveMetadata;
        arrayServerUrlTo = appDelegate.arrayMoveServerUrlTo;
    } else {
        arrayMetadata = appDelegate.arrayCopyMetadata;
        arrayServerUrlTo = appDelegate.arrayCopyServerUrlTo;
    }
    
    if ([_selectedocIdsMetadatas count] > 0) {
        for (NSString *key in _selectedocIdsMetadatas) {
            tableMetadata *metadata = [_selectedocIdsMetadatas objectForKey:key];
            [arrayMetadata addObject:metadata];
            [arrayServerUrlTo addObject:serverUrlTo];
        }
    } else {
        [arrayMetadata addObject:metadata];
        [arrayServerUrlTo addObject:serverUrlTo];
    }
    
    if (move) {
        [[NCNetworking sharedInstance] moveMetadata:arrayMetadata.firstObject serverUrlTo:arrayServerUrlTo.firstObject overwrite:overwrite completion:^(NSInteger errorCode, NSString * errorDesctiption) { }];
    } else {
        [[NCNetworking sharedInstance] copyMetadata:arrayMetadata.firstObject serverUrlTo:arrayServerUrlTo.firstObject overwrite:overwrite completion:^(NSInteger errorCode, NSString * errorDesctiption) { }];
    }
    
    [arrayMetadata removeObjectAtIndex:0];
    [arrayServerUrlTo removeObjectAtIndex:0];
    
    // End Select Table View
    [self tableViewSelect:false];
}

// DELEGATE : Select
- (void)dismissSelectWithServerUrl:(NSString *)serverUrl metadata:(tableMetadata *)metadata type:(NSString *)type buttonType:(NSString *)buttonType overwrite:(BOOL)overwrite
{
    if (serverUrl == nil) {
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    } else {
        
        // E2EE DENIED
        if ([CCUtility isFolderEncrypted:serverUrl e2eEncrypted:metadata.e2eEncrypted account:appDelegate.activeAccount]) {
            
            [[NCContentPresenter shared] messageNotification:@"_move_" description:@"Not possible move files to encrypted directory" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
            return;
        }
        
        BOOL move = true;
        if ([buttonType isEqualToString:@"done1"]) { move = false; }
        
        if ([_selectedocIdsMetadatas count] > 0) {
            NSArray *metadatas = [_selectedocIdsMetadatas allValues];
            [self moveCopyFileOrFolderMetadata:[metadatas objectAtIndex:0] serverUrlTo:serverUrl move:move overwrite:overwrite];
        } else {
            [self moveCopyFileOrFolderMetadata:self.metadata serverUrlTo:serverUrl move:move overwrite:overwrite];
        }
    }
}

- (void)moveOpenWindow:(NSArray *)indexPaths
{
    if (_isSelectedMode && [_selectedocIdsMetadatas count] == 0)
        return;
    
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCSelect" bundle:nil] instantiateInitialViewController];
    NCSelect *viewController = (NCSelect *)navigationController.topViewController;
    
    viewController.delegate = self;
    viewController.hideButtonCreateFolder = false;
    viewController.selectFile = false;
    viewController.includeDirectoryE2EEncryption = false;
    viewController.includeImages = false;
    viewController.type = @"";
    viewController.titleButtonDone = NSLocalizedString(@"_move_", nil);
    viewController.titleButtonDone1 = NSLocalizedString(@"_copy_", nil);
    viewController.isButtonDone1Hide = false;
    viewController.isOverwriteHide = false;
    viewController.layoutViewSelect = k_layout_view_move;
    
    [navigationController setModalPresentationStyle:UIModalPresentationFullScreen];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Create folder =====
#pragma --------------------------------------------------------------------------------------------

- (void)createFolder
{
    NSString *serverUrl = [appDelegate getTabBarControllerActiveServerUrl];
    NSString *message;
    UIAlertController *alertController;
    
    if ([serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]]) {
        message = @"/";
    } else {
        message = [serverUrl lastPathComponent];
    }
    
    alertController = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"_create_folder_on_",nil) message:message preferredStyle:UIAlertControllerStyleAlert];
    
    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        [textField addTarget:self action:@selector(minCharTextFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        textField.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        NSLog(@"[LOG] Cancel action");
    }];
    
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"_ok_", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        UITextField *fileName = alertController.textFields.firstObject;
        
        [[NCNetworking sharedInstance] createFolderWithFileName:fileName.text serverUrl:serverUrl account:appDelegate.activeAccount user:appDelegate.activeUser userID:appDelegate.activeUserID password:appDelegate.activePassword url:appDelegate.activeUrl completion:^(NSInteger errorCode, NSString *errorDescription) { }];
    }];
    
    okAction.enabled = NO;
    
    [alertController addAction:cancelAction];
    [alertController addAction:okAction];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Progress & Task Button =====
#pragma --------------------------------------------------------------------------------------------

- (void)triggerProgressTask:(NSNotification *)notification
{
    if (sectionDataSource.ocIdIndexPath != nil) {
        [[NCMainCommon sharedInstance] triggerProgressTask:notification sectionDataSourceocIdIndexPath:sectionDataSource.ocIdIndexPath tableView:self.tableView viewController:self serverUrlViewController:self.serverUrl];
    }
}

- (void)cancelTaskButton:(id)sender withEvent:(UIEvent *)event
{
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    if ([self indexPathIsValid:indexPath]) {
        
        tableMetadata *metadataSection = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        if (metadataSection) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadataSection.ocId]];
            if (metadata)
                [[NCMainCommon sharedInstance] cancelTransferMetadata:metadata reloadDatasource:true uploadStatusForcedStart:false];
        }
    }
}

- (void)cancelAllTask:(id)sender
{
    CGPoint location = [sender locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_all_task_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [NCUtility.sharedInstance startActivityIndicatorWithView:self.view bottom:0];
        [[NCMainCommon sharedInstance] cancelAllTransfer];
        [NCUtility.sharedInstance stopActivityIndicator];
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:nil ocId:nil action:k_action_NULL];
    }]];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) { }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Tap =====
#pragma --------------------------------------------------------------------------------------------

- (void)tapActionComment:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata && ![CCUtility isFolderEncrypted:self.serverUrl e2eEncrypted:metadata.e2eEncrypted account:appDelegate.activeAccount]) {
        [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:1];
    }
}

- (void)tapActionShared:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata && ![CCUtility isFolderEncrypted:self.serverUrl e2eEncrypted:metadata.e2eEncrypted account:appDelegate.activeAccount]) {
        [[NCMainCommon sharedInstance] openShareWithViewController:self metadata:metadata indexPage:2];
    }
}

- (void)tapActionConnectionMounted:(UITapGestureRecognizer *)tapGesture
{
    CGPoint location = [tapGesture locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (metadata) {
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Rich Workspace =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewRichWorkspaceTapAction:(UITapGestureRecognizer *)tapGesture
{
    [UIView animateWithDuration:0.5 animations:^{
       
        [self.tableView setContentOffset:CGPointMake(0, heightSearchBar)];
        
    } completion:^(BOOL finished) {
        
        UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"NCViewerRichWorkspace" bundle:nil] instantiateInitialViewController];
        NCViewerRichWorkspace *viewerRichWorkspace = (NCViewerRichWorkspace *)[navigationController topViewController];
        viewerRichWorkspace.richWorkspaceText = self.richWorkspaceText;
        viewerRichWorkspace.serverUrl = self.serverUrl;
        
        navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        
        [self presentViewController:navigationController animated:NO completion:NULL];
    }];
}

- (void)createRichWorkspace
{
    NCRichWorkspaceCommon *richWorkspaceCommon = [NCRichWorkspaceCommon new];
    tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@ AND fileNameView LIKE[c] %@", appDelegate.activeAccount, self.serverUrl, k_fileNameRichWorkspace.lowercaseString]];
    
    if (metadata) {
        [richWorkspaceCommon openViewerNextcloudTextWithServerUrl:self.serverUrl viewController:self];
    } else {
        [richWorkspaceCommon createViewerNextcloudTextWithServerUrl:self.serverUrl viewController:self];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Menu LOGO ====
#pragma --------------------------------------------------------------------------------------------

- (void)menuLogo:(UIGestureRecognizer *)theGestureRecognizer
{
    
    // Brand
    if ([NCBrandOptions sharedInstance].disable_multiaccount)
        return;
    
    NSArray *listAccount = [[NCManageDatabase sharedInstance] getAccounts];
    
    NSMutableArray *menuArray = [NSMutableArray new];
    
    for (NSString *account in listAccount) {
    
        CCMenuItem *item = [[CCMenuItem alloc] init];
        
        item.title = [account stringByTruncatingToWidth:self.view.bounds.size.width - 100 withFont:[UIFont systemFontOfSize:12.0] atEnd:YES];
        item.argument = account;
        
        tableAccount *tableAccount = [[NCManageDatabase sharedInstance] getAccountWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ ", account]];
        
        NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@-%@.png", [CCUtility getDirectoryUserData], [CCUtility getStringUser:tableAccount.user activeUrl:tableAccount.url], tableAccount.user];
        UIImage *avatar = [UIImage imageWithContentsOfFile:fileNamePath];
        if (avatar) {
            
            avatar = [CCGraphics scaleImage:avatar toSize:CGSizeMake(25, 25) isAspectRation:YES];
            CCAvatar *avatarImageView = [[CCAvatar alloc] initWithImage:avatar borderColor:[UIColor lightGrayColor] borderWidth:0.5];
            CGSize imageSize = avatarImageView.bounds.size;
            UIGraphicsBeginImageContextWithOptions(imageSize, NO, 0);
            CGContextRef context = UIGraphicsGetCurrentContext();
            [avatarImageView.layer renderInContext:context];
            avatar = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            
        } else {
            
            avatar = [UIImage imageNamed:@"menuLogoUser"];
        }
        
        item.image = avatar;
        item.target = self;
        
        if ([account isEqualToString:appDelegate.activeAccount]) {
            
            item.action = nil;
            [menuArray insertObject:item atIndex:0];
            
        } else {
        
            item.action = @selector(changeDefaultAccount:);
            [menuArray addObject:item];
        }
    }
    
    // Add + new account
    CCMenuItem *item = [[CCMenuItem alloc] init];
    
    item.title = NSLocalizedString(@"_add_account_", nil);
    item.argument = @"";
    item.image = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"add"] width:50 height:50 color:NCBrandColor.sharedInstance.textView];
    item.target = self;
    item.action = @selector(addNewAccount:);
    
    [menuArray addObject:item];
    
    OptionalConfiguration options;
    Color backgroundColor;
    
    const CGFloat *componentsBackgroundColor = CGColorGetComponents(NCBrandColor.sharedInstance.backgroundForm.CGColor);
    backgroundColor.R = componentsBackgroundColor[0];
    backgroundColor.G = componentsBackgroundColor[1];
    backgroundColor.B = componentsBackgroundColor[2];
    
    options.arrowSize = 9;
    options.marginXSpacing = 7;
    options.marginYSpacing = 10;
    options.intervalSpacing = 20;
    options.menuCornerRadius = 6.5;
    options.maskToBackground = NO;
    options.shadowOfMenu = YES;
    options.hasSeperatorLine = YES;
    options.seperatorLineHasInsets = YES;
    options.textColor = NCBrandColor.sharedInstance.textView;
    options.menuBackgroundColor = backgroundColor;
    options.separatorColor = NCBrandColor.sharedInstance.separator;
    
    CGRect rect = self.view.frame;
    CGFloat locationY = [theGestureRecognizer locationInView: self.navigationController.navigationBar].y;
    CGFloat safeAreaTop = 0;
    CGFloat offsetY = 35;
    safeAreaTop = [UIApplication sharedApplication].delegate.window.safeAreaInsets.top / 2;
    rect.origin.y = locationY + safeAreaTop + offsetY;
    rect.size.height = rect.size.height - locationY - safeAreaTop - offsetY;
    
    [CCMenuAccount setTitleFont:[UIFont systemFontOfSize:12.0]];
    [CCMenuAccount showMenuInView:self.navigationController.view fromRect:rect menuItems:menuArray withOptions:options];    
}

- (void)changeDefaultAccount:(CCMenuItem *)sender
{
    // LOGOUT
    
    tableAccount *tableAccount = [[NCManageDatabase sharedInstance] setAccountActive:[sender argument]];
    if (tableAccount) {
            
        // LOGIN
        [appDelegate settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activeUserID:tableAccount.userID activePassword:[CCUtility getPassword:tableAccount.account]];
    
        // go to home sweet home
        [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_initializeMain object:nil userInfo:nil];
    }
}

- (void)addNewAccount:(CCMenuItem *)sender
{
    [appDelegate openLoginView:self selector:k_intro_login openLoginWeb:false];
}

- (void)toggleReMainMenu
{
    [self toggleMenuWithViewController:self.navigationController];
}

- (void)toggleReSelectMenu
{
    [self toggleSelectMenuWithViewController:self.navigationController];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Long Press Recognized Table View / Menu Controller =====
#pragma --------------------------------------------------------------------------------------------

- (void)onLongPressTableView:(UILongPressGestureRecognizer*)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint touchPoint = [recognizer locationInView:self.tableView];
        NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touchPoint];
        NSMutableArray *items = [NSMutableArray new];
        
        if ([self indexPathIsValid:indexPath])
            self.metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
       
        [self becomeFirstResponder];
        
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        
        [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_file_", nil) action:@selector(copyTouchFile:)]];
        [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_copy_files_", nil) action:@selector(copyTouchFiles:)]];
        if ([NCBrandOptions sharedInstance].disable_openin_file == false) {
            [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_open_in_", nil) action:@selector(openinTouchFile:)]];
        }
        if ([[NCUtility sharedInstance] isQuickLookDisplayableWithMetadata:self.metadata]) {
            [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_open_quicklook_", nil) action:@selector(openQuickLookTouch:)]];
        }
        [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_file_", nil) action:@selector(pasteTouchFile:)]];
        [items addObject:[[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"_paste_files_", nil) action:@selector(pasteTouchFiles:)]];

        [menuController setMenuItems:items];
        [menuController setTargetRect:CGRectMake(touchPoint.x, touchPoint.y, 0.0f, 0.0f) inView:self.tableView];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    // For copy file, copy files, Open in ... :
    //
    // NO Directory
    // NO Error Passcode
    // NO In Session mode (download/upload)
    // NO Template
    
    if (@selector(copyTouchFile:) == action || @selector(openinTouchFile:) == action || @selector(openQuickLookTouch:) == action) {
        
        if (_isSelectedMode == NO && self.metadata && !self.metadata.directory && self.metadata.status == k_metadataStatusNormal) return YES;
        else return NO;
    }
    
    if (@selector(copyTouchFiles:) == action) {
        
        if (_isSelectedMode) {
            
            NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
            
            for (tableMetadata *metadata in selectedMetadatas) {
                
                if (!metadata.directory && metadata.status == k_metadataStatusNormal)
                    return YES;
            }
        }
        return NO;
    }

    if (@selector(pasteTouchFile:) == action) {
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] == 1) {
            
            // Value : (NSData) ocId
            
            NSDictionary *dic = [items objectAtIndex:0];
            
            NSData *dataocId = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *ocId = [NSKeyedUnarchiver unarchiveObjectWithData:dataocId];
            
            if (ocId) {
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
                if (metadata) {
                    return [CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView];
                } else {
                    return NO;
                }
            }
        }
            
        return NO;
    }
    
    if (@selector(pasteTouchFiles:) == action) {
        
        BOOL isValid = NO;
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        NSArray *items = [pasteboard items];
        
        if ([items count] <= 1) return NO;
        
        for (NSDictionary *dic in items) {
            
            // Value : (NSData) ocId
            
            NSData *dataocId = [dic objectForKey: k_metadataKeyedUnarchiver];
            NSString *ocId = [NSKeyedUnarchiver unarchiveObjectWithData:dataocId];

            if (ocId) {
                tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
                if (metadata) {
                    if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                        isValid = YES;
                    } else {
                        isValid = NO;
                        break;
                    }
                } else {
                    isValid = NO;
                    break;
                }
            } else {
                isValid = NO;
                break;
            }
        }
        
        return isValid;
    }
    
    return NO;
}

/************************************ COPY ************************************/

- (void)copyTouchFile:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    if ([CCUtility fileProviderStorageExists:self.metadata.ocId fileNameView:self.metadata.fileNameView]) {
        
        [self copyFileToPasteboard:self.metadata];
        
    } else {
        
        self.metadata.session = k_download_session;
        self.metadata.sessionError = @"";
        self.metadata.sessionSelector = selectorLoadCopy;
        self.metadata.status = k_metadataStatusWaitDownload;
            
        // Add Metadata for Download
        [[NCManageDatabase sharedInstance] addMetadata:self.metadata];
        [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:self.metadata.ocId action:k_action_MOD];
        
        [appDelegate startLoadAutoDownloadUpload];
    }
}

- (void)copyTouchFiles:(id)sender
{
    // Remove all item
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.items = [[NSArray alloc] init];
    
    NSArray *selectedMetadatas = [self getMetadatasFromSelectedRows:[self.tableView indexPathsForSelectedRows]];
    
    for (tableMetadata *metadata in selectedMetadatas) {
        
        if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
            
            [self copyFileToPasteboard:metadata];
            
        } else {

            metadata.session = k_download_session;
            metadata.sessionError = @"";
            metadata.sessionSelector = selectorLoadCopy;
            metadata.status = k_metadataStatusWaitDownload;
                
            // Add Metadata for Download
            [[NCManageDatabase sharedInstance] addMetadata:metadata];
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:metadata.ocId action:k_action_MOD];
            
            [appDelegate startLoadAutoDownloadUpload];
        }
    }
    
    [self tableViewSelect:false];
}

- (void)copyFileToPasteboard:(tableMetadata *)metadata
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    NSMutableArray *items = [[NSMutableArray alloc] initWithArray:pasteboard.items];
    
    // Value : (NSData) ocId
    
    NSDictionary *item = [NSDictionary dictionaryWithObjectsAndKeys:[NSKeyedArchiver archivedDataWithRootObject:metadata.ocId], k_metadataKeyedUnarchiver,nil];
    [items addObject:item];
    
    [pasteboard setItems:items];
}

/************************************ OPEN IN ... ******************************/

- (void)openinTouchFile:(id)sender
{
    [[NCMainCommon sharedInstance] downloadOpenWithMetadata:self.metadata selector:selectorOpenIn];
}

/************************************ OPEN QUICK LOOK ******************************/

- (void)openQuickLookTouch:(id)sender
{
    [[NCMainCommon sharedInstance] downloadOpenWithMetadata:self.metadata selector:selectorLoadFileQuickLook];
}

/************************************ PASTE ************************************/

- (void)pasteTouchFile:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items]];
}

- (void)pasteTouchFiles:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    [self uploadFilePasteArray:[pasteboard items]];
}

- (void)uploadFilePasteArray:(NSArray *)items
{
    for (NSDictionary *dic in items) {
        
        // Value : (NSData) ocId
        
        NSData *dataocId = [dic objectForKey: k_metadataKeyedUnarchiver];
        NSString *ocId = [NSKeyedUnarchiver unarchiveObjectWithData:dataocId];

        tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
        
        if (metadata) {
            
            if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                
                NSString *fileName = [[NCUtility sharedInstance] createFileName:metadata.fileNameView serverUrl:self.serverUrl account:appDelegate.activeAccount];
                NSString *ocId = [[NSUUID UUID] UUIDString];
                
                [CCUtility copyFileAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView] toPath:[CCUtility getDirectoryProviderStorageOcId:ocId fileNameView:fileName]];
                    
                // Prepare record metadata
                tableMetadata *metadataForUpload = [[NCManageDatabase sharedInstance] createMetadataWithAccount:appDelegate.activeAccount fileName:fileName ocId:ocId serverUrl:self.serverUrl url:@"" contentType:@""];
            
                metadataForUpload.session = k_upload_session;
                metadataForUpload.sessionSelector = selectorUploadFile;
                metadataForUpload.size = metadata.size;
                metadataForUpload.status = k_metadataStatusWaitUpload;
                            
                // Add Medtadata for upload
                [[NCManageDatabase sharedInstance] addMetadata:metadataForUpload];
                
                [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
            }
        }
    }
    
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
    
    [appDelegate startLoadAutoDownloadUpload];
}

#pragma mark -
#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== menu action : Favorite, More, Delete [swipe] =====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)canOpenMenuAction:(tableMetadata *)metadata
{
    if (metadata == nil || _metadataFolder == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata] || metadata.status != k_metadataStatusNormal || [[NCManageDatabase sharedInstance] isTableInvalidated:_metadataFolder])
        return NO;
    
    // E2EE
    if (_metadataFolder.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount] == NO)
        return NO;
    
    return YES;
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell canSwipe:(MGSwipeDirection)direction
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    return [self canOpenMenuAction:metadata];
}

-(void)swipeTableCell:(nonnull MGSwipeTableCell *)cell didChangeSwipeState:(MGSwipeState)state gestureIsActive:(BOOL)gestureIsActive
{
}

- (BOOL)swipeTableCell:(MGSwipeTableCell *)cell tappedButtonAtIndex:(NSInteger)index direction:(MGSwipeDirection)direction fromExpansion:(BOOL)fromExpansion
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    self.metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (direction == MGSwipeDirectionRightToLeft) {
        [self actionDelete:indexPath];
    }
    
    if (direction == MGSwipeDirectionLeftToRight) {
        [[NCNetworking sharedInstance] favoriteMetadata:self.metadata url:appDelegate.activeUrl completion:^(NSInteger errorCode, NSString *errorDescription) { }];
    }
    
    return YES;
}

- (void)actionDelete:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    tableLocalFile *localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_delete_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self performSelector:@selector(deleteMetadatas) withObject:nil];
    }]];
    
    if (localFile) {
        [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_remove_local_file_", nil) style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            tableMetadata *metadataLivePhoto = [[NCUtility sharedInstance] isLivePhotoWithMetadata:metadata];
            
            [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
            [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId] error:nil];
            
            if (metadataLivePhoto) {
                [[NCManageDatabase sharedInstance] deleteLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadataLivePhoto.ocId]];
                [[NSFileManager defaultManager] removeItemAtPath:[CCUtility getDirectoryProviderStorageOcId:metadataLivePhoto.ocId] error:nil];
            }
            
            [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
        }]];
    }
    
    [alertController addAction: [UIAlertAction actionWithTitle:NSLocalizedString(@"_cancel_", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    }]];
    
    alertController.popoverPresentationController.sourceView = self.tableView;
    alertController.popoverPresentationController.sourceRect = [self.tableView rectForRowAtIndexPath:indexPath];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [alertController.view layoutIfNeeded];
    
    [self presentViewController:alertController animated:YES completion:nil];
}

- (void)actionMore:(UITapGestureRecognizer *)gestureRecognizer
{
    CGPoint touch = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:touch];
    
    self.metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    [self toggleMoreMenuWithViewController:self.tabBarController indexPath:indexPath metadata:self.metadata metadataFolder:_metadataFolder];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Datasource ====
#pragma --------------------------------------------------------------------------------------------

- (void)clearDateReadDataSource:(NSNotification *)notification
{
    _dateReadDataSource = Nil;
    
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:nil action:k_action_NULL];
}

- (void)reloadDatasource:(NSString *)serverUrl ocId:(NSString *)ocId action:(NSInteger)action
{
    // test
    if (appDelegate.activeAccount.length == 0 || serverUrl.length == 0 || serverUrl == nil || self.view.window == nil)
        return;
    
    // Search Mode
    if (self.searchController.isActive) {
        
        // Create metadatas
        NSMutableArray *metadatas = [NSMutableArray new];
        for (tableMetadata *resultMetadata in _searchResultMetadatas) {
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", resultMetadata.ocId]];
            if (metadata) {
                [metadatas addObject:metadata];
            }
        }
        
        // [CCUtility getGroupBySettings]
        sectionDataSource = [CCSectionMetadata creataDataSourseSectionMetadata:metadatas listProgressMetadata:nil groupByField:nil filterTypeFileImage:NO filterTypeFileVideo:NO sorted:@"fileName" ascending:NO activeAccount:appDelegate.activeAccount];

        [self tableViewReloadData];
        
        if ([sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] >= k_minCharsSearch) {
            
            _noFilesSearchTitle = NSLocalizedString(@"_search_no_record_found_", nil);
            _noFilesSearchDescription = @"";
        }
        
        if ([sectionDataSource.allRecordsDataSource count] == 0 && [_searchFileName length] < k_minCharsSearch) {
            
            _noFilesSearchTitle = @"";
            _noFilesSearchDescription = NSLocalizedString(@"_search_instruction_", nil);
        }
    
        [self.tableView reloadEmptyDataSet];
        
        return;
    }
    
    // Se non siamo nella dir appropriata esci
    if ([serverUrl isEqualToString:self.serverUrl] == NO || self.serverUrl == nil) {
        return;
    }
    
    // Controllo data lettura Data Source
    tableDirectory *tableDirectory = [[NCManageDatabase sharedInstance] getTableDirectoryWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, serverUrl]];
    if (tableDirectory == nil) {
        return;
    }
    
    // Get MetadataFolder
    if ([serverUrl isEqualToString:[CCUtility getHomeServerUrlActiveUrl:appDelegate.activeUrl]])
        _metadataFolder = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, k_serverUrl_root]];
    else
        _metadataFolder = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", tableDirectory.ocId]];
    
    // Remove optimization for encrypted directory
    if (_metadataFolder.e2eEncrypted)
        _dateReadDataSource = nil;

    NSDate *dateDateRecordDirectory = tableDirectory.dateReadDirectory;
    
    if ([dateDateRecordDirectory compare:_dateReadDataSource] == NSOrderedDescending || dateDateRecordDirectory == nil || _dateReadDataSource == nil) {
        
        NSLog(@"[LOG] Rebuild Data Source File : %@", _serverUrl);

        _dateReadDataSource = [NSDate date];
    
        // Data Source
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                
            CCSectionDataSourceMetadata *sectionDataSourceTemp = [self queryDatasourceWithReloadData:NO serverUrl:serverUrl];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                sectionDataSource = sectionDataSourceTemp;
                [self tableViewReloadData];
            });
        });
        
    } else {
        
        [self tableViewReloadData];

         NSLog(@"[LOG] [OPTIMIZATION] Rebuild Data Source File : %@ - %@", _serverUrl, _dateReadDataSource);
    }
    
    // BLINK
    if (self.blinkFileNamePath != nil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
            for (NSString *key in sectionDataSource.allRecordsDataSource) {
                tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:key];
                NSString *metadataFileNamePath = [NSString stringWithFormat:@"%@/%@", metadata.serverUrl, metadata.fileName];
                if ([metadataFileNamePath isEqualToString:self.blinkFileNamePath]) {
                    for (NSString *key in sectionDataSource.ocIdIndexPath) {
                        if ([key isEqualToString:metadata.ocId]) {
                            NSIndexPath *indexPath = [sectionDataSource.ocIdIndexPath objectForKey:key];
                            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void) {
                                CCCellMain *cell = [self.tableView cellForRowAtIndexPath:indexPath];
                                if (cell) {
                                    self.blinkFileNamePath = nil;
                                    [[NCUtility sharedInstance] blinkWithCell:cell];
                                }
                            });
                        }
                    }
                }
            }
        });
    }
}

- (CCSectionDataSourceMetadata *)queryDatasourceWithReloadData:(BOOL)withReloadData serverUrl:(NSString *)serverUrl
{
    // test
    if (appDelegate.activeAccount.length == 0 || serverUrl == nil) {
        return nil;
    }
    
    // get auto upload folder
    _autoUploadFileName = [[NCManageDatabase sharedInstance] getAccountAutoUploadFileName];
    _autoUploadDirectory = [[NCManageDatabase sharedInstance] getAccountAutoUploadDirectory:appDelegate.activeUrl];
    
    CCSectionDataSourceMetadata *sectionDataSourceTemp = [CCSectionDataSourceMetadata new];

    NSArray *recordsTableMetadata = [[NCManageDatabase sharedInstance] getMetadatasWithPredicate:[NSPredicate predicateWithFormat:@"account == %@ AND serverUrl == %@", appDelegate.activeAccount, serverUrl] sorted:nil ascending:NO];
    
    // [CCUtility getGroupBySettings]
    sectionDataSourceTemp = [CCSectionMetadata creataDataSourseSectionMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:nil filterTypeFileImage:NO filterTypeFileVideo:NO sorted:[CCUtility getOrderSettings] ascending:[CCUtility getAscendingSettings] activeAccount:appDelegate.activeAccount];
    
    if (withReloadData) {
        sectionDataSource = sectionDataSourceTemp;
        [self tableViewReloadData];
    }
    
    return sectionDataSourceTemp;
}

- (NSArray *)getMetadatasFromSelectedRows:(NSArray *)selectedRows
{
    NSMutableArray *metadatas = [[NSMutableArray alloc] init];
    
    if (selectedRows.count > 0) {
    
        for (NSIndexPath *selectionIndex in selectedRows) {
            
            NSString *ocId = [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:selectionIndex.section]] objectAtIndex:selectionIndex.row];
            tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:ocId];

            [metadatas addObject:metadata];
        }
    }
    
    return metadatas;
}

- (NSArray *)getMetadatasFromSectionDataSource:(NSInteger)section
{
    NSInteger totSections =[sectionDataSource.sections count] ;
    
    if ((totSections < (section + 1)) || ((section + 1) > totSections)) {
        return nil;
    }
    
    id valueSection = [sectionDataSource.sections objectAtIndex:section];
    
    return [sectionDataSource.sectionArrayRow objectForKey:valueSection];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark - ==== Table ==== 
#pragma --------------------------------------------------------------------------------------------

- (void)tableViewToggle
{
    [self tableViewSelect:!_isSelectedMode];
}

- (void)tableViewSelect:(BOOL)toggle
{
    _isSelectedMode = toggle;
    // chiudiamo eventuali swipe aperti
    if (_isSelectedMode)
        [self.tableView setEditing:NO animated:NO];
    
    [self.tableView setAllowsMultipleSelectionDuringEditing:_isSelectedMode];
    [self.tableView setEditing:_isSelectedMode animated:YES];
    
    if (_isSelectedMode)
        [self setUINavigationBarSelected];
    else
        [self setUINavigationBarDefault];
    
    [_selectedocIdsMetadatas removeAllObjects];
    
    [self setTitle];
}

- (void)tableViewReloadData
{
    // store selected cells before relod
    NSArray *indexPaths = [self.tableView indexPathsForSelectedRows];
    
    // reload table view
    [self.tableView reloadData];
    
    // selected cells stored
    for (NSIndexPath *path in indexPaths)
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    
    [self setTableViewHeader];
    [self setTableViewFooter];
    
    if (self.tableView.editing)
        [self setTitle];
    
    [self.tableView reloadEmptyDataSet];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{    
    if (tableView.editing == 1) {
        
        tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
        
        if (!metadata || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata])
            return NO;
        
        if (metadata == nil || metadata.status != k_metadataStatusNormal)
            return NO;
        else
            return YES;
        
    } else {
        
        [_selectedocIdsMetadatas removeAllObjects];
    }
    
    return YES;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[sectionDataSource.sectionArrayRow allKeys] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[sectionDataSource.sectionArrayRow objectForKey:[sectionDataSource.sections objectAtIndex:section]] count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSArray *sections = [sectionDataSource.sectionArrayRow allKeys];
    NSString *sectionTitle = [sections objectAtIndex:section];
    
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"download"].location != NSNotFound) return 18.f;
    if ([sectionTitle isKindOfClass:[NSString class]] && [sectionTitle rangeOfString:@"upload"].location != NSNotFound) return 18.f;
    
    if ([[CCUtility getGroupBySettings] isEqualToString:@"none"] && [sections count] <= 1) return 0.0f;
    
    return 20.f;
}

-(UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    float shift;
    UIVisualEffectView *visualEffectView;
    
    NSString *titleSection;
    
    if (![self indexPathIsValid:[NSIndexPath indexPathForRow:0 inSection:section]])
        return nil;
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSString class]])
        titleSection = [sectionDataSource.sections objectAtIndex:section];
    
    if ([[sectionDataSource.sections objectAtIndex:section] isKindOfClass:[NSDate class]])
        titleSection = [CCUtility getTitleSectionDate:[sectionDataSource.sections objectAtIndex:section]];
    
    if ([titleSection isEqualToString:@"_none_"]) titleSection = @"";
    else if ([titleSection rangeOfString:@"download"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_download_",nil);
    else if ([titleSection rangeOfString:@"upload"].location != NSNotFound) titleSection = NSLocalizedString(@"_title_section_upload_",nil);
    else titleSection = NSLocalizedString(titleSection,nil);
    
    // Format title
    UIVisualEffect *blurEffect;
    blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    visualEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    visualEffectView.backgroundColor = [NCBrandColor.sharedInstance.brand colorWithAlphaComponent:0.2];
    
    if ([[CCUtility getGroupBySettings] isEqualToString:@"alphabetic"]) {
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            shift = - 35;
        else
            shift =  - 20;
        
    } else shift = - 10;
    
    // Title
    UILabel *titleLabel = [[UILabel alloc]initWithFrame:CGRectMake(10, -12, 0, 44)];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.textColor = NCBrandColor.sharedInstance.textView;
    titleLabel.font = [UIFont systemFontOfSize:12];
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.text = titleSection;
    titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    [visualEffectView.contentView addSubview:titleLabel];
    
    // Elements
    UILabel *elementLabel= [[UILabel alloc]initWithFrame:CGRectMake(shift, -12, 0, 44)];
    elementLabel.backgroundColor = [UIColor clearColor];
    elementLabel.textColor = NCBrandColor.sharedInstance.textView;
    elementLabel.font = [UIFont systemFontOfSize:12];
    elementLabel.textAlignment = NSTextAlignmentRight;
    elementLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    NSArray *metadatas = [self getMetadatasFromSectionDataSource:section];
    NSUInteger rowsCount = [metadatas count];
    
    if (rowsCount == 0) return nil;
    if (rowsCount == 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_element_",nil)];
    if (rowsCount > 1) elementLabel.text = [NSString stringWithFormat:@"%lu %@", (unsigned long)rowsCount,  NSLocalizedString(@"_elements_",nil)];
    
    [visualEffectView.contentView addSubview:elementLabel];
    
    return visualEffectView;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return [sectionDataSource.sections indexOfObject:title];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    if ([[CCUtility getGroupBySettings] isEqualToString:@"alphabetic"])
        return [[UILocalizedIndexedCollation currentCollation] sectionIndexTitles];
    else
        return nil;
}

/*
-(void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if([indexPath row] == ((NSIndexPath*)[[tableView indexPathsForVisibleRows] lastObject]).row){
        
    }
}
*/

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    tableShare *shareCell;
   
    if (metadata == nil || [[NCManageDatabase sharedInstance] isTableInvalidated:metadata] || (_metadataFolder != nil && [[NCManageDatabase sharedInstance] isTableInvalidated:_metadataFolder])) {
        return [CCCellMain new];
    }
    
    for (tableShare *share in appDelegate.shares) {
        if ([share.serverUrl isEqualToString:metadata.serverUrl] && [share.fileName isEqualToString:metadata.fileName]) {
            shareCell = share;
            break;
        }
    }

    UITableViewCell *cell = [[NCMainCommon sharedInstance] cellForRowAtIndexPath:indexPath tableView:tableView metadata:metadata metadataFolder:_metadataFolder serverUrl:self.serverUrl autoUploadFileName:_autoUploadFileName autoUploadDirectory:_autoUploadDirectory tableShare:shareCell];
    
    // NORMAL - > MAIN
    
    if ([cell isKindOfClass:[CCCellMain class]]) {
        
        // Comment tap
        if (metadata.commentsUnread) {
            UITapGestureRecognizer *tapComment = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionComment:)];
            [tapComment setNumberOfTapsRequired:1];
            ((CCCellMain *)cell).comment.userInteractionEnabled = YES;
            [((CCCellMain *)cell).comment addGestureRecognizer:tapComment];
        }
        
        // Share add Tap
        UITapGestureRecognizer *tapShare = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapActionShared:)];
        [tapShare setNumberOfTapsRequired:1];
        ((CCCellMain *)cell).viewShared.userInteractionEnabled = YES;
        [((CCCellMain *)cell).viewShared addGestureRecognizer:tapShare];
        
        // More
        if ([self canOpenMenuAction:metadata]) {
            UITapGestureRecognizer *tapMore = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionMore:)];
            [tapMore setNumberOfTapsRequired:1];
            ((CCCellMain *)cell).more.userInteractionEnabled = YES;
            [((CCCellMain *)cell).more addGestureRecognizer:tapMore];
        }
        
        // MGSwipeButton
        ((CCCellMain *)cell).delegate = self;

        // LEFT
        ((CCCellMain *)cell).leftButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:self.cellFavouriteImage backgroundColor:NCBrandColor.sharedInstance.yellowFavorite padding:25]];
        
        ((CCCellMain *)cell).leftExpansion.buttonIndex = 0;
        ((CCCellMain *)cell).leftExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *favoriteButton = (MGSwipeButton *)[((CCCellMain *)cell).leftButtons objectAtIndex:0];
        [favoriteButton centerIconOverText];
        
        // RIGHT
        ((CCCellMain *)cell).rightButtons = @[[MGSwipeButton buttonWithTitle:@"" icon:self.cellTrashImage backgroundColor:[UIColor redColor] padding:25]];
        
        ((CCCellMain *)cell).rightExpansion.buttonIndex = 0;
        ((CCCellMain *)cell).rightExpansion.fillOnTrigger = NO;
        
        //centerIconOverText
        MGSwipeButton *deleteButton = (MGSwipeButton *)[((CCCellMain *)cell).rightButtons objectAtIndex:0];
        [deleteButton centerIconOverText];
    }
    
    // TRANSFER
    
    if ([cell isKindOfClass:[CCCellMainTransfer class]]) {
        
        // gesture Transfer
        [((CCCellMainTransfer *)cell).transferButton.stopButton addTarget:self action:@selector(cancelTaskButton:withEvent:) forControlEvents:UIControlEventTouchUpInside];
        
        UILongPressGestureRecognizer *stopLongGesture = [UILongPressGestureRecognizer new];
        [stopLongGesture addTarget:self action:@selector(cancelAllTask:)];
        [((CCCellMainTransfer *)cell).transferButton.stopButton addGestureRecognizer:stopLongGesture];
    }
    
    return cell;
    
}

- (void)setTableViewHeader
{
    NSInteger versionMajor = [[NCManageDatabase sharedInstance] getCapabilitiesServerVersionWithAccount:appDelegate.activeAccount element:@"major"];

    NSString *trimmedRichWorkspaceText = [self.richWorkspaceText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (versionMajor < k_nextcloud_version_18_0 || trimmedRichWorkspaceText.length == 0 ) {
                
        [self.tableView.tableHeaderView setFrame:CGRectMake(self.tableView.tableHeaderView.frame.origin.x, self.tableView.tableHeaderView.frame.origin.y, self.tableView.frame.size.width, heightSearchBar)];
        
    } else {
        
        [self.viewRichWorkspace setFrame:CGRectMake(self.tableView.tableHeaderView.frame.origin.x, self.tableView.tableHeaderView.frame.origin.y, self.tableView.frame.size.width, heightRichWorkspace)];
    }
    
    if (self.searchController.isActive == true) {
        [self.tableView.tableHeaderView setFrame:CGRectMake(self.tableView.tableHeaderView.frame.origin.x, self.tableView.tableHeaderView.frame.origin.y, self.tableView.frame.size.width, 0)];
    }
    
    [self.viewRichWorkspace setNeedsLayout];
    [self.viewRichWorkspace loadWithRichWorkspaceText:self.richWorkspaceText];
}

- (void)setTableViewFooter
{
    UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UILabel *footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 40)];
    [footerLabel setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin];
    
    UIFont *appFont = [UIFont systemFontOfSize:12];
    
    footerLabel.font = appFont;
    footerLabel.textColor = [UIColor grayColor];
    footerLabel.backgroundColor = [UIColor clearColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    
    NSString *folders;
    NSString *files;
    NSString *footerText;
    
    if (sectionDataSource.directories > 1) {
        folders = [NSString stringWithFormat:@"%ld %@", (long)sectionDataSource.directories, NSLocalizedString(@"_folders_", nil)];
    } else if (sectionDataSource.directories == 1){
        folders = [NSString stringWithFormat:@"%ld %@", (long)sectionDataSource.directories, NSLocalizedString(@"_folder_", nil)];
    } else {
        folders = @"";
    }
    
    if (sectionDataSource.files > 1) {
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)sectionDataSource.files, NSLocalizedString(@"_files_", nil), [CCUtility transformedSize:sectionDataSource.totalSize]];
    } else if (sectionDataSource.files == 1){
        files = [NSString stringWithFormat:@"%ld %@ %@", (long)sectionDataSource.files, NSLocalizedString(@"_file_", nil), [CCUtility transformedSize:sectionDataSource.totalSize]];
    } else {
        files = @"";
    }
    
    if ([folders isEqualToString:@""]) {
        footerText = files;
    } else if ([files isEqualToString:@""]) {
        footerText = folders;
    } else {
        footerText = [NSString stringWithFormat:@"%@, %@", folders, files];
    }
    
    footerLabel.text = footerText;
    
    [footerView addSubview:footerLabel];
    [self.tableView setTableFooterView:footerView];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{    
    CCCellMain *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // settiamo il record file.
    self.metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    if (!self.metadata)
        return;
    
    // se non può essere selezionata deseleziona
    if ([cell isEditing] == NO)
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // se siamo in modalità editing impostiamo il titolo dei selezioati e usciamo subito
    if (self.tableView.editing) {
        
        [_selectedocIdsMetadatas setObject:self.metadata forKey:self.metadata.ocId];
        [self setTitle];
        return;
    }
    
    // se è in corso una sessione
    if (self.metadata.status != k_metadataStatusNormal)
        return;
    
    // file
    if (self.metadata.directory == NO) {
        
        // se il file esiste andiamo direttamente al delegato altrimenti carichiamolo
        if ([CCUtility fileProviderStorageExists:self.metadata.ocId fileNameView:self.metadata.fileNameView]) {
            
            [[NSNotificationCenter defaultCenter] postNotificationOnMainThreadName:k_notificationCenter_downloadedFile object:nil userInfo:@{@"metadata": self.metadata, @"selector": selectorLoadFileView, @"errorCode": @(0), @"errorDescription": @""}];
                        
        } else {
            
            if (_metadataFolder.e2eEncrypted && ![CCUtility isEndToEndEnabled:appDelegate.activeAccount]) {
                
                [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
                
            } else {
            
                if (([self.metadata.typeFile isEqualToString: k_metadataTypeFile_video] || [self.metadata.typeFile isEqualToString: k_metadataTypeFile_audio]) && _metadataFolder.e2eEncrypted == NO) {
                    
                    [self shouldPerformSegue:self.metadata selector:@""];
                    
                } else if ([self.metadata.typeFile isEqualToString: k_metadataTypeFile_document] && [[NCUtility sharedInstance] isDirectEditing:self.metadata] != nil) {
                    
                    if (appDelegate.reachability.isReachable) {
                        [self shouldPerformSegue:self.metadata selector:@""];
                    } else {
                        [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_go_online_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
                    }
                    
                } else if ([self.metadata.typeFile isEqualToString: k_metadataTypeFile_document] && [[NCUtility sharedInstance] isRichDocument:self.metadata]) {
                    
                    if (appDelegate.reachability.isReachable) {
                        [self shouldPerformSegue:self.metadata selector:@""];
                    } else {
                        [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_go_online_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
                    }
                    
                } else {
                    
                    if ([self.metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                        [self shouldPerformSegue:self.metadata selector:selectorLoadFileView];
                    }
                   
                    self.metadata.session = k_download_session;
                    self.metadata.sessionError = @"";
                    self.metadata.sessionSelector = selectorLoadFileView;
                    self.metadata.status = k_metadataStatusWaitDownload;
                    
                    // Add Metadata for Download
                    [[NCManageDatabase sharedInstance] addMetadata:self.metadata];
                    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:self.serverUrl ocId:self.metadata.ocId action:k_action_MOD];
                    
                    [appDelegate startLoadAutoDownloadUpload];
                }
            }
        }
    }
    
    if (self.metadata.directory) {
        
        [self performSegueDirectoryWithMetadata:self.metadata blinkFileNamePath:self.blinkFileNamePath];
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
    
    [_selectedocIdsMetadatas removeObjectForKey:metadata.ocId];
    
    [self setTitle];
}

- (void)didSelectAll
{
    for (int i = 0; i < self.tableView.numberOfSections; i++) {
        for (int j = 0; j < [self.tableView numberOfRowsInSection:i]; j++) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:j inSection:i];
            tableMetadata *metadata = [[NCMainCommon sharedInstance] getMetadataFromSectionDataSourceIndexPath:indexPath sectionDataSource:sectionDataSource];
            [_selectedocIdsMetadatas setObject:metadata forKey:metadata.ocId];
            [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        }
    }
    [self setTitle];
}

- (BOOL)indexPathIsValid:(NSIndexPath *)indexPath
{
    if (!indexPath)
        return NO;
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    NSInteger lastSectionIndex = [self numberOfSectionsInTableView:self.tableView] - 1;
    
    if (section > lastSectionIndex || lastSectionIndex < 0)
        return NO;
    
    NSInteger rowCount = [self.tableView numberOfRowsInSection:indexPath.section] - 1;
    
    if (rowCount < 0)
        return NO;
    
    return row <= rowCount;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (void)shouldPerformSegue:(tableMetadata *)metadata selector:(NSString *)selector
{
    // if background return
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return;
    
    if (self.view.window == NO)
        return;
    
    // Collapsed ma siamo già in detail esci
    if (self.splitViewController.isCollapsed) {
        if (appDelegate.activeDetail.isViewLoaded && appDelegate.activeDetail.view.window) return;
    }
    
    // Metadata for push detail
    self.metadataForPushDetail = metadata;
    self.selectorForPushDetail = selector;
    
    [self performSegueWithIdentifier:@"segueDetail" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    tableMetadata *metadata;
    NSMutableArray *photoDataSource = [NSMutableArray new];

    UINavigationController *navigationController = segue.destinationViewController;
    NCDetailViewController *detailViewController = (NCDetailViewController *)navigationController.topViewController;
    
    if ([sender isKindOfClass:[tableMetadata class]]) {
    
        metadata = sender;
        [photoDataSource addObject:sender];
        
    } else {
        
        metadata = self.metadataForPushDetail;
        
        for (NSString *ocId in sectionDataSource.allOcId) {
            tableMetadata *metadata = [sectionDataSource.allRecordsDataSource objectForKey:ocId];
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image])
                [photoDataSource addObject:metadata];
        }
    }
    
    detailViewController.metadata = metadata;
    detailViewController.selector = self.selectorForPushDetail;
    
    [detailViewController setTitle:metadata.fileNameView];
}

// can i go to next viewcontroller
- (void)performSegueDirectoryWithMetadata:(tableMetadata *)metadata blinkFileNamePath:(NSString *)blinkFileNamePath
{
    NSString *nomeDir;
    
    if (self.tableView.editing == NO) {
        
        // E2EE Check enable
        if (metadata.e2eEncrypted && [CCUtility isEndToEndEnabled:appDelegate.activeAccount] == NO) {
            
            [[NCContentPresenter shared] messageNotification:@"_info_" description:@"_e2e_goto_settings_for_enable_" delay:k_dismissAfterSecond type:messageTypeInfo errorCode:0];
            return;
        }
        
        nomeDir = metadata.fileName;
        
        NSString *serverUrlPush = [CCUtility stringAppendServerUrl:metadata.serverUrl addFileName:nomeDir];
    
        CCMain *viewController = [appDelegate.listMainVC objectForKey:serverUrlPush];
        
        if (!viewController) {
            
            viewController = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"CCMain"];
            
            viewController.serverUrl = serverUrlPush;
            viewController.titleMain = metadata.fileNameView;
            viewController.blinkFileNamePath = blinkFileNamePath;
            
            // save self
            [appDelegate.listMainVC setObject:viewController forKey:serverUrlPush];
            
            [self.navigationController pushViewController:viewController animated:YES];
        
        } else {
           
            if (viewController.isViewLoaded) {
                
                viewController.titleMain = metadata.fileNameView;
                viewController.blinkFileNamePath = blinkFileNamePath;
                
                // Fix : Application tried to present modally an active controller
                if ([self.navigationController isBeingPresented]) {
                    // being presented
                } else if ([self.navigationController isMovingToParentViewController]) {
                    // being pushed
                } else {
                    [self.navigationController pushViewController:viewController animated:YES];
                }
            }
        }
    }
}

@end

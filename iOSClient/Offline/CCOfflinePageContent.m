//
//  CCOfflinePageContent.m
//  Nextcloud
//
//  Created by Marino Faggiana on 01/02/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import "CCOfflinePageContent.h"

#import "AppDelegate.h"

@interface CCOfflinePageContent ()
{
    NSMutableArray *dataSource;
}
@end

@implementation CCOfflinePageContent

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    // Custom Cell
    [self.tableView registerNib:[UINib nibWithNibName:@"CCCellOffline" bundle:nil] forCellReuseIdentifier:@"OfflineCell"];

    // dataSource
    dataSource = [NSMutableArray new];
    
    // Metadata
    _metadata = [CCMetadata new];
    
    self.tableView.emptyDataSetDelegate = self;
    self.tableView.emptyDataSetSource = self;
    self.tableView.tableFooterView = [UIView new];
    self.tableView.separatorColor = COLOR_SEPARATOR_TABLE;
    
    // calculate _localServerUrl
    if ([self.pageType isEqualToString:pageOfflineOffline] && !_localServerUrl) {
        _localServerUrl = nil;
    }
    
    if ([self.pageType isEqualToString:pageOfflineLocal] && !_localServerUrl) {
        _localServerUrl = [CCUtility getDirectoryLocal];
    }
    
    // Title
    self.title = _titleViewControl;
}

// Apparirà
- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Color
    [CCAspect aspectNavigationControllerBar:self.navigationController.navigationBar hidden:NO];
    [CCAspect aspectTabBar:self.tabBarController.tabBar hidden:NO];
    
    // Plus Button
    [app plusButtonVisibile:true];
    
    [self reloadTable];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== DZNEmptyDataSetSource Methods ====
#pragma --------------------------------------------------------------------------------------------

- (BOOL)emptyDataSetShouldDisplay:(UIScrollView *)scrollView
{
    // only for root
    if (!_localServerUrl || [_localServerUrl isEqualToString:[CCUtility getDirectoryLocal]])
        return YES;
    else
        return NO;
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView
{
    return 0.0f;
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView
{
    return - self.navigationController.navigationBar.frame.size.height;
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView
{
    return [UIColor whiteColor];
}

- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView
{
    if ([self.pageType isEqualToString:pageOfflineOffline])
        return [UIImage imageNamed:image_brandOffline];
    
    if ([self.pageType isEqualToString:pageOfflineLocal])
        return [UIImage imageNamed:image_brandLocal];
    
    return nil;
}

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if ([self.pageType isEqualToString:pageOfflineOffline])
        text = NSLocalizedString(@"_no_files_uploaded_", nil);
    
    if ([self.pageType isEqualToString:pageOfflineLocal])
        text = NSLocalizedString(@"_no_files_uploaded_", nil);
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont boldSystemFontOfSize:20.0f], NSForegroundColorAttributeName:COLOR_BRAND};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (NSAttributedString *)descriptionForEmptyDataSet:(UIScrollView *)scrollView
{
    NSString *text;
    
    if ([self.pageType isEqualToString:pageOfflineOffline])
        text = NSLocalizedString(@"_tutorial_offline_view_", nil);
        
    if ([self.pageType isEqualToString:pageOfflineLocal])
        text = NSLocalizedString(@"_tutorial_local_view_", nil);
    
    NSMutableParagraphStyle *paragraph = [NSMutableParagraphStyle new];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    
    NSDictionary *attributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0], NSForegroundColorAttributeName: [UIColor lightGrayColor], NSParagraphStyleAttributeName: paragraph};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== UIDocumentInteractionControllerDelegate =====
#pragma --------------------------------------------------------------------------------------------

- (void)documentInteractionControllerDidDismissOptionsMenu:(UIDocumentInteractionController *)controller
{
    // evitiamo il rimando della eventuale photo e/o video
    if ([CCCoreData getCameraUploadActiveAccount:app.activeAccount]) {
        
        [CCCoreData setCameraUploadDatePhoto:[NSDate date]];
        [CCCoreData setCameraUploadDateVideo:[NSDate date]];
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Table ====
#pragma --------------------------------------------------------------------------------------------

- (void)reloadTable
{
    [dataSource removeAllObjects];
    
    if ([_pageType isEqualToString:pageOfflineOffline]) {
        
        if (!_localServerUrl) {
            
            dataSource = (NSMutableArray*)[CCCoreData getHomeOfflineActiveAccount:app.activeAccount directoryUser:app.directoryUser];
            
        } else {
            
            NSString *directoryID = [CCCoreData getDirectoryIDFromServerUrl:_localServerUrl activeAccount:app.activeAccount];
            NSArray *recordsTableMetadata = [CCCoreData getTableMetadataWithPredicate:[NSPredicate predicateWithFormat:@"(account == %@) AND (directoryID == %@)", app.activeAccount, directoryID] fieldOrder:[CCUtility getOrderSettings] ascending:[CCUtility getAscendingSettings]];
            
            CCSectionDataSource *sectionDataSource = [CCSection creataDataSourseSectionTableMetadata:recordsTableMetadata listProgressMetadata:nil groupByField:nil replaceDateToExifDate:NO activeAccount:app.activeAccount];
            
            for (NSString *key in sectionDataSource.allRecordsDataSource)
                [dataSource  insertObject:[sectionDataSource.allRecordsDataSource objectForKey:key] atIndex:0 ];
        }
    }
    
    if ([_pageType isEqualToString:pageOfflineLocal]) {
        
        NSArray *subpaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_localServerUrl error:nil];
        
        for (NSString *subpath in subpaths)
            if (![[subpath lastPathComponent] hasPrefix:@"."])
                [dataSource addObject:subpath];
    }
    
    [self.tableView reloadData];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [dataSource count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CCCellOffline *cell = (CCCellOffline *)[tableView dequeueReusableCellWithIdentifier:@"OfflineCell" forIndexPath:indexPath];
    CCMetadata *metadata;
    
    // Initialize
    cell.statusImageView.image = nil;
    cell.offlineImageView.image = nil;
    
    // change color selection
    UIView *selectionColor = [[UIView alloc] init];
    selectionColor.backgroundColor = COLOR_SELECT_BACKGROUND;
    cell.selectedBackgroundView = selectionColor;
    
    // i am in Offline
    if ([_pageType isEqualToString:pageOfflineOffline]) {
        
        metadata = [dataSource objectAtIndex:indexPath.row];
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.ico", app.directoryUser, metadata.fileID]];
        
        if (metadata.cryptated)
            cell.offlineImageView.image = [UIImage imageNamed:image_offlinecrypto];
        else
            cell.offlineImageView.image = [UIImage imageNamed:image_offline];
    }
    
    // i am in local
    if ([_pageType isEqualToString:pageOfflineLocal]) {
        
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:_localServerUrl activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
        
        cell.fileImageView.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/.%@.ico", _localServerUrl, metadata.fileNamePrint]];
        
        if (!cell.fileImageView.image) {
            
            UIImage *icon = [CCGraphics createNewImageFrom:metadata.fileID directoryUser:_localServerUrl fileNameTo:metadata.fileID fileNamePrint:metadata.fileNamePrint size:@"m" imageForUpload:NO typeFile:metadata.typeFile writePreview:NO optimizedFileName:[CCUtility getOptimizedPhoto]];
            
            if (icon) {
                [CCGraphics saveIcoWithFileID:metadata.fileNamePrint image:icon writeToFile:[NSString stringWithFormat:@"%@/.%@.ico", _localServerUrl, metadata.fileNamePrint] copy:NO move:NO fromPath:nil toPath:nil];
                cell.fileImageView.image = icon;
            }
        }
    }
    
    // color and font
    if (metadata.cryptated) {
        cell.labelTitle.textColor = COLOR_ENCRYPTED;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    } else {
        cell.labelTitle.textColor = COLOR_CLEAR;
        //nameLabel.font = RalewayLight(13.0f);
        cell.labelInfoFile.textColor = [UIColor blackColor];
        //detailLabel.font = RalewayLight(9.0f);
    }
    
    if (metadata.directory) {
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    // File name
    cell.labelTitle.text = metadata.fileNamePrint;
    cell.labelInfoFile.text = @"";
    
    // Immagine del file, se non c'è l'anteprima mettiamo quella standard
    if (cell.fileImageView.image == nil)
        cell.fileImageView.image = [UIImage imageNamed:metadata.iconName];
    
    // it's encrypted ???
    if (metadata.cryptated && [metadata.type isEqualToString:metadataType_model] == NO)
        cell.statusImageView.image = [UIImage imageNamed:image_lock];
    
    // it's in download mode
    if ([metadata.session length] > 0 && [metadata.session rangeOfString:@"download"].location != NSNotFound)
        cell.statusImageView.image = [UIImage imageNamed:image_attention];
    
    // text and length
    if (metadata.directory) {
        
        cell.labelInfoFile.text = [CCUtility dateDiff:metadata.date];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
    } else {
        
        NSString *date = [CCUtility dateDiff:metadata.date];
        NSString *length = [CCUtility transformedSize:metadata.size];
        
        if ([metadata.type isEqualToString:metadataType_model])
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@", date];
        
        if ([metadata.type isEqualToString:metadataType_file] || [metadata.type isEqualToString:metadataType_local])
            cell.labelInfoFile.text = [NSString stringWithFormat:@"%@, %@", date, length];
        
        cell.accessoryType = UITableViewCellAccessoryNone;
        
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // deselect row
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if ([_pageType isEqualToString:pageOfflineOffline]) {
        
        NSManagedObject *record = [dataSource objectAtIndex:indexPath.row];
        _metadata = [CCCoreData getMetadataWithPreficate:[NSPredicate predicateWithFormat:@"(fileID == %@) AND (account == %@)", [record valueForKey:@"fileID"], app.activeAccount] context:nil];
    }
    
    if ([_pageType isEqualToString:pageOfflineLocal]) {
        
        NSString *cameraFolderName = [CCCoreData getCameraUploadFolderNameActiveAccount:app.activeAccount];
        NSString *cameraFolderPath = [CCCoreData getCameraUploadFolderPathActiveAccount:app.activeAccount activeUrl:app.activeUrl typeCloud:app.typeCloud];
        
        _metadata = [CCUtility insertFileSystemInMetadata:[dataSource objectAtIndex:indexPath.row] directory:_localServerUrl activeAccount:app.activeAccount cameraFolderName:cameraFolderName cameraFolderPath:cameraFolderPath];
    }
    
    // if is in download [do not touch]
    if ([_metadata.session length] > 0 && [_metadata.session rangeOfString:@"download"].location != NSNotFound) return;
    
    if (([_metadata.type isEqualToString:metadataType_file] || [_metadata.type isEqualToString:metadataType_local]) && _metadata.directory == NO) {
        
        if ([self shouldPerformSegue])
            [self performSegueWithIdentifier:@"segueDetail" sender:self];
    }
    
    if ([self.metadata.type isEqualToString:metadataType_model])
        [self openModel:self.metadata];
    
    if (_metadata.directory)
        [self performSegueDirectoryWithControlPasscode];
}

-(void)performSegueDirectoryWithControlPasscode
{
    CCOfflinePageContent *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil] instantiateViewControllerWithIdentifier:@"OfflinePageContentViewController"];
    
    NSString *serverUrl;
    
    if ([_pageType isEqualToString:pageOfflineOffline] && !_localServerUrl) {
    
        serverUrl = [CCCoreData getServerUrlFromDirectoryID:_metadata.directoryID activeAccount:app.activeAccount];
        
    } else {
        
        serverUrl = _localServerUrl;
    }
        
    vc.localServerUrl = [CCUtility stringAppendServerUrl:serverUrl addServerUrl:_metadata.fileNameData];
    vc.pageType = _pageType;
    vc.titleViewControl = _metadata.fileNamePrint;
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Navigation ====
#pragma --------------------------------------------------------------------------------------------

- (void)openModel:(CCMetadata *)metadata
{
    UIViewController *viewController;
    BOOL isLocal = NO;
    
    if ([self.pageType isEqualToString:pageOfflineLocal])
        isLocal = YES;
    
    if ([metadata.model isEqualToString:@"cartadicredito"])
        viewController = [[CCCartaDiCredito alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"bancomat"])
        viewController = [[CCBancomat alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"contocorrente"])
        viewController = [[CCContoCorrente alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"accountweb"])
        viewController = [[CCAccountWeb alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"patenteguida"])
        viewController = [[CCPatenteGuida alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"cartaidentita"])
        viewController = [[CCCartaIdentita alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"passaporto"])
        viewController = [[CCPassaporto alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
    
    if ([metadata.model isEqualToString:@"note"]) {
        
        viewController = [[CCNote alloc] initWithDelegate:self fileName:metadata.fileName uuid:metadata.uuid rev:metadata.rev fileID:metadata.fileID modelReadOnly:true isLocal:isLocal];
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [self presentViewController:navigationController animated:YES completion:nil];
        
    } else {
        
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        [navigationController setModalPresentationStyle:UIModalPresentationFormSheet];
        
        [self presentViewController:navigationController animated:YES completion:nil];
    }
}

- (BOOL)shouldPerformSegue
{
    // if i am in background -> exit
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground) return NO;
    
    // if i am not window -> exit
    if (self.view.window == NO)
        return NO;
    
    // Collapsed but i am in detail -> exit
    if (self.splitViewController.isCollapsed)
        if (self.detailViewController.isViewLoaded && self.detailViewController.view.window) return NO;
    
    // Video in run -> exit
    if (self.detailViewController.photoBrowser.currentVideoPlayerViewController.isViewLoaded && self.detailViewController.photoBrowser.currentVideoPlayerViewController.view.window) return NO;
    
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id viewController = segue.destinationViewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = viewController;
        self.detailViewController = (CCDetail *)nav.topViewController;
    } else {
        self.detailViewController = segue.destinationViewController;
    }
    
    self.detailViewController.metadataDetail = _metadata;
    
    if ([self.pageType isEqualToString:pageOfflineOffline])
        self.detailViewController.sourceDirectory = sorceDirectoryOffline;
    
    if ([self.pageType isEqualToString:pageOfflineLocal])
        self.detailViewController.sourceDirectory = sorceDirectoryLocal;
    
    self.detailViewController.dateFilterQuery = nil;
    self.detailViewController.isCameraUpload = NO;
    
    [self.detailViewController setTitle:_metadata.fileNamePrint];
}

@end

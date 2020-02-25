//
//  CCDetail.m
//  Nextcloud
//
//  Created by Marino Faggiana on 16/01/15.
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

#import "CCViewerImage.h"
#import "AppDelegate.h"

#import "CCMain.h"
#import "NCUchardet.h"
#import "NCBridgeSwift.h"


@interface CCViewerImage ()
{
    AppDelegate *appDelegate;
    NSInteger indexNowVisible;
    NSString *ocIdNowVisible;
    
    NSString *fileNameExtension;
}
@end

@implementation CCViewerImage

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== init =====
#pragma --------------------------------------------------------------------------------------------

-  (id)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])  {
        
        appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(changeTheming) name:@"changeTheming" object:nil];

        self.metadataDetail = [tableMetadata new];
        self.photos = [[NSMutableArray alloc] init];
        self.photoDataSource = [NSMutableArray new];
        indexNowVisible = -1;
        ocIdNowVisible = nil;
    }
    return self;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(insertGeocoderLocation:) name:@"insertGeocoderLocation" object:nil];
        
    [self changeTheming];
}


- (void)changeTheming
{
    [appDelegate changeTheming:self tableView:nil collectionView:nil form:false];
    
    self.edgesForExtendedLayout = UIRectEdgeAll;
    [self viewImage];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== View Image =====
#pragma --------------------------------------------------------------------------------------------

- (void)viewImage
{
    self.photoBrowser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    indexNowVisible = -1;
    ocIdNowVisible = nil;
    
    [self.photos removeAllObjects];
    
    // if not images, exit
    if ([self.photoDataSource count] == 0)
        return;

    NSUInteger index = 0;
    for (tableMetadata *metadata in self.photoDataSource) {
        
        // start from here ?
        if (self.metadataDetail.ocId && [metadata.ocId isEqualToString:self.metadataDetail.ocId])
            [self.photoBrowser setCurrentPhotoIndex:index];
        
        [self.photos addObject:[MWPhoto photoWithImage:nil]];
        
        // add directory
        index++;
    }
    
    // PhotoBrowser
    if ([NCBrandOptions sharedInstance].disable_openin_file) {
        self.photoBrowser.displayActionButton = NO;
    } else {
        self.photoBrowser.displayActionButton = YES;
    }
    self.photoBrowser.displayDeleteButton = YES;
    if ([CCUtility isFolderEncrypted:_metadataDetail.serverUrl account:appDelegate.activeAccount]) // E2EE
        self.photoBrowser.displayShareButton = NO;
    else
        self.photoBrowser.displayShareButton = YES;
    self.photoBrowser.displayNavArrows = YES;
    self.photoBrowser.displaySelectionButtons = NO;
    self.photoBrowser.alwaysShowControls = NO;
    self.photoBrowser.zoomPhotosToFill = NO;
    self.photoBrowser.autoPlayOnAppear = NO;
    self.photoBrowser.delayToHideElements = 15;
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        self.photoBrowser.enableSwipeToDismiss = NO;
    
    if (self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact) {
        
        [self addChildViewController:self.photoBrowser];
        [self.view addSubview:self.photoBrowser.view];
        [self.photoBrowser didMoveToParentViewController:self];
        
    } else {
        
        [self.navigationController pushViewController:self.photoBrowser animated:NO];
    }
    
    self.navigationController.navigationBar.topItem.title = _metadataDetail.fileNameView;
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    return [self.photoDataSource count];
}

- (NSString *)photoBrowser:(MWPhotoBrowser *)photoBrowser titleForPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    NSString *titleDir = metadata.fileNameView;
    self.title = titleDir;
    
    return titleDir;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index
{
    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    indexNowVisible = index;
    ocIdNowVisible = metadata.ocId;
    
    photoBrowser.toolbar.hidden = NO;
    
    // Download image ?
    if (metadata) {
        
        NSInteger status;
        tableMetadata *metadataDB = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", metadata.ocId]];
        if (metadataDB) {
            status = metadataDB.status;
        } else {
            status = k_metadataStatusNormal;
        }
        
        if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView] == NO && status == k_metadataStatusNormal) {
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]] == NO && metadata.hasPreview) {
                
                [CCGraphics addImageToTitle:NSLocalizedString(@"_...loading..._", nil) colorTitle:NCBrandColor.sharedInstance.brandText imageTitle:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] multiplier:2 color:NCBrandColor.sharedInstance.brandText] imageRight:NO navigationItem:self.navigationItem];
                
                CGFloat width = [[NCUtility sharedInstance] getScreenWidthForPreview];
                CGFloat height = [[NCUtility sharedInstance] getScreenHeightForPreview];

                [[OCNetworking sharedManager] downloadPreviewWithAccount:appDelegate.activeAccount metadata:metadata withWidth:width andHeight:height completion:^(NSString *account, UIImage *image, NSString *message, NSInteger errorCode) {

                    self.navigationItem.titleView = nil;
                    self.title = metadata.fileNameView;
                    
                    if (errorCode == 0 && [account isEqualToString:appDelegate.activeAccount]) {
                        [self.photoBrowser reloadData];
                    }
                }];
            } else {
                [self downloadPhotoBrowser:metadata];
            }
        }
    }
    
    // Title
    if (metadata)
        self.title = metadata.fileNameView;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index
{
    UIImage *image;

    tableMetadata *metadata = [self.photoDataSource objectAtIndex:index];
    
    if (index < self.photos.count) {
        
        if (metadata.ocId) {
            
            UIImage *imagePreview = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]];
//            if (!imagePreview) imagePreview = [CCGraphics changeThemingColorImage:[UIImage imageNamed:@"file_photo"] multiplier:3 color:[NCBrandColor.sharedInstance icon]];
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_image]) {
                
                NSString *fileImage = [CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView];
                NSString *ext = [CCUtility getExtension:metadata.fileNameView];
                
                if ([ext isEqualToString:@"GIF"]) image = [UIImage animatedImageWithAnimatedGIFURL:[NSURL fileURLWithPath:fileImage]];
                else image = [UIImage imageWithContentsOfFile:fileImage];
                
                if (image) {
                    
                    MWPhoto *photo = [MWPhoto photoWithImage:image];
                    
                    // Location ??
                    [self setLocationCaptionPhoto:photo ocId:metadata.ocId];
                    
                    [self.photos replaceObjectAtIndex:index withObject:photo];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_video]) {
                
                if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    
                    MWPhoto *video = [MWPhoto photoWithImage:[CCGraphics thumbnailImageForVideo:url atTime:1.0]];
                    video.videoURL = url;
                    
                    [self.photos replaceObjectAtIndex:index withObject:video];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
            
            if ([metadata.typeFile isEqualToString: k_metadataTypeFile_audio]) {
                
                if ([CCUtility fileProviderStorageExists:metadata.ocId fileNameView:metadata.fileNameView]) {
                    
                    MWPhoto *audio;
                    UIImage *audioImage;
                    
                    NSURL *url = [NSURL fileURLWithPath:[CCUtility getDirectoryProviderStorageOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    
                    if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]]) {
                        audioImage = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]];
                    } else {
                        audioImage = [UIImage imageNamed:@"notaMusic"]; //[CCGraphics scaleImage:[UIImage imageNamed:@"notaMusic"] toSize:CGSizeMake(200, 200) isAspectRation:YES];
                    }
                    
                    audio = [MWPhoto photoWithImage:audioImage];
                    audio.videoURL = url;
                    [self.photos replaceObjectAtIndex:index withObject:audio];
                    
                } else {
                    
                    if (metadata.status == k_metadataStatusDownloadError) {
                        
                        [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:[UIImage imageNamed:@"filePreviewError"]]];
                        
                    } else {
                        
                        if (imagePreview)
                            [self.photos replaceObjectAtIndex:index withObject:[MWPhoto photoWithImage:imagePreview]];
                    }
                }
            }
        }
        
        // energy saving memory
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            int iPrev = (int)index - 2;
            if (iPrev >= 0) {
                if ([self.photos objectAtIndex:iPrev] != nil)
                    [self.photos replaceObjectAtIndex:iPrev withObject:[MWPhoto photoWithImage:nil]];
            }
        
            int iNext = (int)index + 2;
            if (iNext < _photos.count) {
                if ([self.photos objectAtIndex:iNext] != nil)
                    [self.photos replaceObjectAtIndex:iNext withObject:[MWPhoto photoWithImage:nil]];
            }
        });
        
        return [self.photos objectAtIndex:index];
    }
    
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index
{
   
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser shareButtonPressedForPhotoAtIndex:(NSUInteger)index
{
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser deleteButtonPressedForPhotoAtIndex:(NSUInteger)index deleteButton:(UIBarButtonItem *)deleteButton
{
}

- (void)photoBrowserDidFinishPresentation:(MWPhotoBrowser *)photoBrowser
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)downloadPhotoBrowserSuccessFailure:(tableMetadata *)metadata selector:(NSString *)selector errorCode:(NSInteger)errorCode
{
    // if a message for a directory of these
    if (![metadata.ocId isEqualToString:ocIdNowVisible])
        return;
 
    // Title
    self.navigationItem.titleView = nil;
    self.title = metadata.fileNameView;
    
    if (errorCode == 0) {
        
        // verifico se esiste l'icona e se la posso creare
        if ([[NSFileManager defaultManager] fileExistsAtPath:[CCUtility getDirectoryProviderStorageIconOcId:metadata.ocId fileNameView:metadata.fileNameView]] == NO) {
            [CCGraphics createNewImageFrom:metadata.fileNameView ocId:metadata.ocId extension:[metadata.fileNameView pathExtension] filterGrayScale:NO typeFile:metadata.typeFile writeImage:YES];
        }
        
        [self.photoBrowser reloadData];

    } else {
        [[NCContentPresenter shared] messageNotification:@"_download_selected_files_" description:@"_error_download_photobrowser_" delay:k_dismissAfterSecond type:messageTypeError errorCode:errorCode];
        
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)downloadPhotoBrowser:(tableMetadata *)metadata
{
    tableMetadata *metadataForDownload = [[NCManageDatabase sharedInstance] initNewMetadata:metadata];
    
    metadataForDownload.session = k_download_session;
    metadataForDownload.sessionError = @"";
    metadataForDownload.sessionSelector = selectorLoadViewImage;
    metadataForDownload.status = k_metadataStatusWaitDownload;
        
    // Add Metadata for Download
    (void)[[NCManageDatabase sharedInstance] addMetadata:metadataForDownload];
    [[NCMainCommon sharedInstance] reloadDatasourceWithServerUrl:metadata.serverUrl ocId:metadataForDownload.ocId action:k_action_MOD];
    
    [appDelegate startLoadAutoDownloadUpload];

    [CCGraphics addImageToTitle:NSLocalizedString(@"_...loading..._", nil) colorTitle:NCBrandColor.sharedInstance.brandText imageTitle:[CCGraphics changeThemingColorImage:[UIImage imageNamed:@"load"] multiplier:2 color:NCBrandColor.sharedInstance.brandText] imageRight:NO navigationItem:self.navigationItem];
}

- (void)insertGeocoderLocation:(NSNotification *)notification
{
    if (notification.userInfo.count == 0)
        return;
    
    NSString *ocId = [[notification.userInfo allKeys] objectAtIndex:0];
    //NSDate *date = [[notification.userInfo allValues] objectAtIndex:0];
 
    // test [Chrash V 1.14,15]
    if (indexNowVisible >= [self.photos count])
        return;
    
    if ([ocId isEqualToString:ocIdNowVisible]) {
            
        MWPhoto *photo = [self.photos objectAtIndex:indexNowVisible];
            
        [self setLocationCaptionPhoto:photo ocId:ocId];
        
        [self.photoBrowser reloadData];
    }
}

- (void)setLocationCaptionPhoto:(MWPhoto *)photo ocId:(NSString *)ocId
{
    tableLocalFile *localFile;

    // read Geocoder
    localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
    
    if ([localFile.exifLatitude doubleValue] != 0 || [localFile.exifLongitude doubleValue] != 0) {
        
        // Fix BUG Geo latitude & longitude
        if ([localFile.exifLatitude doubleValue] == 9999 || [localFile.exifLongitude doubleValue] == 9999) {
            
            tableMetadata *metadata = [[NCManageDatabase sharedInstance] getMetadataWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
            if (metadata) {
                [[CCExifGeo sharedInstance] setExifLocalTableEtag:metadata];
            }
        }
        
        [[CCExifGeo sharedInstance] setGeocoderEtag:ocId exifDate:localFile.exifDate latitude:localFile.exifLatitude longitude:localFile.exifLongitude];
        
        localFile = [[NCManageDatabase sharedInstance] getTableLocalFileWithPredicate:[NSPredicate predicateWithFormat:@"ocId == %@", ocId]];
        
        if ([localFile.exifLatitude floatValue] != 0 || [localFile.exifLongitude floatValue] != 0) {
                        
            NSString *location = [[NCManageDatabase sharedInstance] getLocationFromGeoLatitude:localFile.exifLatitude longitude:localFile.exifLongitude];
            
            if ([localFile.exifDate isEqualToDate:[NSDate distantPast]] == NO && location) {
                
                NSString *localizedDateTime = [NSDateFormatter localizedStringFromDate:localFile.exifDate dateStyle:NSDateFormatterFullStyle timeStyle:NSDateFormatterMediumStyle];
                
                photo.caption = [NSString stringWithFormat:NSLocalizedString(@"%@\n%@", nil), localizedDateTime, location];
            }
        }
    }
}

@end

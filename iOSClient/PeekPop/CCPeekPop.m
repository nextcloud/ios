//
//  CCPeekPop.m
//  Nextcloud
//
//  Created by Marino Faggiana on 26/08/16.
//  Copyright (c) 2016 Marino Faggiana. All rights reserved.
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

#import "CCPeekPop.h"
#import "AppDelegate.h"
#import "NCBridgeSwift.h"

@interface CCPeekPop ()
{
    AppDelegate *appDelegate;
    NSInteger highLabelFileName;
}
@end

@implementation CCPeekPop

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    UIImage *image = self.imageFile;

    self.fileName.text = self.metadata.fileNameView;
    self.fileName.textColor = NCBrandColor.shared.textView;
    highLabelFileName = self.fileName.bounds.size.height + 5;
    
    if (self.metadata.hasPreview) {
        
        if ([CCUtility fileProviderStoragePreviewIconExists:self.metadata.ocId etag:self.metadata.etag]) {
            
            UIImage *fullImage = [UIImage imageWithContentsOfFile:[CCUtility getDirectoryProviderStorageOcId:self.metadata.ocId fileNameView:self.metadata.fileNameView]];
            if (fullImage != nil) {
                image = fullImage;
            }
            
        } else {
            
            [self downloadThumbnail];
        }
    }
    
    self.view.backgroundColor = NCBrandColor.shared.backgroundForm;
    self.imagePreview.image = [image resizeImageWithSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
    self.preferredContentSize = CGSizeMake(self.imagePreview.image.size.width,  self.imagePreview.image.size.height + highLabelFileName);
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    NSMutableArray *items = [NSMutableArray new];
 
    if (self.showOpenIn && !self.metadata.directory) {
        UIPreviewAction *item = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_open_in_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController) {
            [[NCNetworkingNotificationCenter shared] downloadOpenWithMetadata:self.metadata selector:NCBrandGlobal.shared.selectorOpenIn];
        }];
        [items addObject:item];
    }
    
    if (self.showOpenQuickLook) {
        UIPreviewAction *item = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_open_quicklook_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController) {
            [[NCNetworkingNotificationCenter shared] downloadOpenWithMetadata:self.metadata selector:NCBrandGlobal.shared.selectorLoadFileQuickLook];
        }];
        [items addObject:item];
    }
    
    if (self.showShare) {
        UIPreviewAction *item = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_share_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController) {
            [[NCNetworkingNotificationCenter shared] openShareWithViewController:appDelegate.activeFiles metadata:self.metadata indexPage:2];
        }];
        [items addObject:item];
    }
    
    return items;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnail
{
    NSString *fileNamePath = [CCUtility returnFileNamePathFromFileName:self.metadata.fileName serverUrl:self.metadata.serverUrl urlBase:appDelegate.urlBase account:appDelegate.account];
    NSString *fileNamePreviewLocalPath = [CCUtility getDirectoryProviderStoragePreviewOcId:self.metadata.ocId etag:self.metadata.etag];
    NSString *fileNameIconLocalPath = [CCUtility getDirectoryProviderStorageIconOcId:self.metadata.ocId etag:self.metadata.etag];
    
    [[NCCommunication shared] downloadPreviewWithFileNamePathOrFileId:fileNamePath fileNamePreviewLocalPath:fileNamePreviewLocalPath widthPreview:NCBrandGlobal.shared.sizePreview heightPreview:NCBrandGlobal.shared.sizePreview fileNameIconLocalPath:fileNameIconLocalPath sizeIcon:NCBrandGlobal.shared.sizeIcon customUserAgent:nil addCustomHeaders:nil endpointTrashbin:false useInternalEndpoint:true completionHandler:^(NSString *account, UIImage *imagePreview, UIImage *imageIcon, NSInteger errorCode,  NSString *errorDescription) {
        
        if (errorCode == 0 && imagePreview != nil) {
            self.imagePreview.image = [imagePreview resizeImageWithSize:CGSizeMake(self.view.bounds.size.width, self.view.bounds.size.height)];
            self.preferredContentSize = CGSizeMake(self.imagePreview.image.size.width, self.imagePreview.image.size.height + highLabelFileName);
        }
    }];
}

@end

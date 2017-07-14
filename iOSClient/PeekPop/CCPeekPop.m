//
//  CCPeekPop.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 26/08/16.
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

#import "CCPeekPop.h"

#import "AppDelegate.h"
#import "CCGraphics.h"
#import "NCBridgeSwift.h"

@interface CCPeekPop ()


@end

@implementation CCPeekPop

- (void)setMetadata:(tableMetadata *)newMetadata
{
    if (_metadata != newMetadata)
        _metadata = newMetadata;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.preferredContentSize = CGSizeMake(640, 640);
    //detailVC?.preferredContentSize = CGSize(width: 0, height: 380)
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"loading" withExtension:@"gif"];
    
    _imagePreview.image = [UIImage animatedImageWithAnimatedGIFURL:url];
    
    _imagePreview.contentMode = UIViewContentModeCenter;

    [self downloadThumbnail:_metadata];
}

// E' apparso

-(void) viewDidAppear:(BOOL)animated{
    
    [super viewDidAppear:animated];    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (NSArray<id<UIPreviewActionItem>> *)previewActionItems
{
    //__weak typeof(self) weakSelf = self;
    
    UIPreviewAction *previewAction1 = [UIPreviewAction actionWithTitle:NSLocalizedString(@"_open_in_", nil) style:UIPreviewActionStyleDefault handler:^(UIPreviewAction *action,  UIViewController *previewViewController){
        
        NSString *serverUrl = [[NCManageDatabase sharedInstance] getServerUrl:_metadata.directoryID];
        
        [[CCNetworking sharedNetworking] downloadFile:_metadata.fileID serverUrl:serverUrl downloadData:YES downloadPlist:NO selector:selectorOpenIn selectorPost:nil session:k_download_session taskStatus:k_taskStatusResume delegate:self.delegate];
    }];
    
    return @[previewAction1];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ==== Download Thumbnail ====
#pragma --------------------------------------------------------------------------------------------

- (void)downloadThumbnailSuccess:(CCMetadataNet *)metadataNet
{
    UIImage *image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.pvw",app.directoryUser, _metadata.fileID]];
    
    _imagePreview.image = image;
    
    _imagePreview.contentMode = UIViewContentModeScaleToFill;
    
    self.preferredContentSize = CGSizeMake(image.size.width, image.size.height);
}

- (void)downloadThumbnailFailure:(CCMetadataNet *)metadataNet message:(NSString *)message errorCode:(NSInteger)errorCode
{    
    [app messageNotification:@"_error_" description:message visible:YES delay:k_dismissAfterSecond type:TWMessageBarMessageTypeError errorCode:errorCode];
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)downloadThumbnail:(tableMetadata *)metadata
{
    CCMetadataNet *metadataNet = [[CCMetadataNet alloc] initWithAccount:app.activeAccount];
    
    NSString *serverUrl = app.activeMain.serverUrl;
    
    metadataNet.action = actionDownloadThumbnail;
    metadataNet.fileID = metadata.fileID;
    metadataNet.fileName = [self returnFileNamePathFromFileName:metadata.fileName serverUrl:serverUrl];
    metadataNet.fileNameLocal = metadata.fileID;
    metadataNet.fileNamePrint = metadata.fileNamePrint;
    metadataNet.options = @"l";
    metadataNet.priority = NSOperationQueuePriorityLow;
    metadataNet.selector = selectorDownloadThumbnail;
    metadataNet.serverUrl = serverUrl;
    
    [app addNetworkingOperationQueue:app.netQueue delegate:self metadataNet:metadataNet];
}

- (NSString *)returnFileNamePathFromFileName:(NSString *)metadataFileName serverUrl:(NSString *)serverUrl
{
    NSString *fileName = [NSString stringWithFormat:@"%@/%@", [serverUrl stringByReplacingOccurrencesOfString:[CCUtility getHomeServerUrlActiveUrl:app.activeUrl] withString:@""], metadataFileName];
    
    if ([fileName hasPrefix:@"/"]) fileName = [fileName substringFromIndex:1];
    
    return fileName;
}

@end

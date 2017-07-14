//
//  CCDetail.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 16/01/15.
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

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "UIImage+animatedGIF.h"
#import "LMMediaPlayerView.h"
#import "TWMessageBarManager.h"
#import "MWPhotoBrowser.h"
#import "ReaderViewController.h"
#import "UINavigationController+CCProgress.h"
#import "CCGraphics.h"

@class tableMetadata;

@interface CCDetail : UIViewController <UIDocumentInteractionControllerDelegate, MWPhotoBrowserDelegate, ReaderViewControllerDelegate>

@property (nonatomic, strong) tableMetadata *metadataDetail;
@property BOOL sourceDirectoryLocal;
@property (nonatomic, strong) NSDate *dateFilterQuery;

// Document
@property (nonatomic, strong) WKWebView *webView;

// Photo-Video
@property (nonatomic, strong) NSMutableArray *dataSourceImagesVideos;

@property (nonatomic, strong) MWPhotoBrowser *photoBrowser;
@property (nonatomic, strong) NSMutableArray *photos;
@property (nonatomic, strong) NSMutableArray *thumbs;

// PDF
@property (nonatomic, strong) ReaderViewController *readerPDFViewController;
@property (nonatomic, strong) NSString *passwordPDF;

// Action
@property (nonatomic, strong) UIDocumentInteractionController *docController;

@property(nonatomic, weak) IBOutlet UIImageView *imageBackground;

- (void)removeAllView;

- (void)changeToDisplayMode;

- (void)downloadPhotoBrowserFailure:(NSInteger)errorCode;
- (void)downloadPhotoBrowserSuccess:(tableMetadata *)metadataVar selector:(NSString *)selector;

@end




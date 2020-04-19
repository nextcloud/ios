//
//  CCNetworking.h
//  Nextcloud
//
//  Created by Marino Faggiana on 01/06/15.
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

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>
#import "OCCommunication.h"
#import "OCFrameworkConstants.h"
#import "PHAsset+Utility.h"
#import "CCExifGeo.h"
#import "CCGraphics.h"
#import "CCError.h"

@class tableMetadata;

@protocol CCNetworkingDelegate;

@interface CCNetworking : NSObject <NSURLSessionTaskDelegate, NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, weak) id <CCNetworkingDelegate> delegate;

+ (CCNetworking *)sharedNetworking;

#pragma mark ===== Session =====

- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription;
- (void)invalidateAndCancelAllSession;

#pragma mark ===== Download =====

- (void)downloadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus;

#pragma mark ===== Upload =====

- (void)uploadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus;

@end

@protocol CCNetworkingDelegate <NSObject>

#pragma mark ===== Download delegate =====

@optional - (void)downloadStart:(NSString *)ocId account:(NSString *)account task:(NSURLSessionDownloadTask *)task serverUrl:(NSString *)serverUrl;
@optional  - (void)downloadFileSuccessFailure:(NSString *)fileName ocId:(NSString *)ocId serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode;

@end

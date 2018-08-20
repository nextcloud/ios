//
//  CCNetworking.h
//  Nextcloud iOS
//
//  Created by Marino Faggiana on 01/06/15.
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

#import <Foundation/Foundation.h>
#import <Photos/Photos.h>

#import "OCCommunication.h"
#import "OCFrameworkConstants.h"
#import "AFURLSessionManager.h"
#import "TWMessageBarManager.h"
#import "PHAsset+Utility.h"
#import "CCExifGeo.h"
#import "CCGraphics.h"
#import "CCError.h"

@class tableMetadata;
@class CCMetadataNet;

@protocol CCNetworkingDelegate;

@interface CCNetworking : NSObject <NSURLSessionTaskDelegate, NSURLSessionDelegate, NSURLSessionDownloadDelegate>

@property (nonatomic, weak) id <CCNetworkingDelegate> delegate;

+ (CCNetworking *)sharedNetworking;

- (void)settingAccount;

// Sessions
- (OCCommunication *)sharedOCCommunication;
- (OCCommunication *)sharedOCCommunicationExtensionDownload;

- (NSURLSession *)getSessionfromSessionDescription:(NSString *)sessionDescription;
- (NSArray *)getUploadTasksExtensionSession;

- (void)invalidateAndCancelAllSession;

// Download
- (void)downloadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus;

// Upload
- (void)uploadFile:(tableMetadata *)metadata taskStatus:(NSInteger)taskStatus;

@end

@protocol CCNetworkingDelegate <NSObject>

@optional - (void)downloadStart:(NSString *)fileID account:(NSString *)account task:(NSURLSessionDownloadTask *)task serverUrl:(NSString *)serverUrl;
@optional  - (void)downloadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode;

@optional - (void)uploadStart:(NSString *)fileID account:(NSString *)account task:(NSURLSessionUploadTask *)task serverUrl:(NSString *)serverUrl;
@optional - (void)uploadFileSuccessFailure:(NSString *)fileName fileID:(NSString *)fileID assetLocalIdentifier:(NSString *)assetLocalIdentifier serverUrl:(NSString *)serverUrl selector:(NSString *)selector errorMessage:(NSString *)errorMessage errorCode:(NSInteger)errorCode;

@end

#pragma --------------------------------------------------------------------------------------------
#pragma mark =====  CCMetadataNet =====
#pragma --------------------------------------------------------------------------------------------

@interface CCMetadataNet : NSObject <NSCopying>

@property (nonatomic, strong) NSString *account;
@property (nonatomic, strong) NSString *action;
@property (nonatomic, strong) NSArray *contentType;
@property (nonatomic, strong) NSDate *date;
@property (nonatomic, weak) id delegate;
@property (nonatomic, strong) NSString *depth;
@property BOOL directory;
@property (nonatomic, strong) NSString *directoryID;
@property (nonatomic, strong) NSString *directoryIDTo;
@property (nonatomic, strong) NSString *encryptedMetadata;
@property (nonatomic, strong) NSString *etag;
@property (nonatomic, strong) NSString *expirationTime;
@property (nonatomic, strong) NSString *fileID;
@property (nonatomic, strong) NSString *fileName;
@property (nonatomic, strong) NSString *fileNameTo;
@property (nonatomic, strong) NSString *fileNameView;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) NSString *keyCipher;
@property (nonatomic, strong) id optionAny;
@property (nonatomic, strong) NSString *optionString;
@property (nonatomic, strong) NSString *password;
@property NSInteger priority;
@property (nonatomic, strong) NSString *serverUrl;
@property (nonatomic, strong) NSString *serverUrlTo;
@property (nonatomic, strong) NSString *selector;
@property (nonatomic, strong) NSString *share;
@property NSInteger shareeType;
@property NSInteger sharePermission;
@property double size;

- (id)initWithAccount:(NSString *)withAccount;
- (id)copyWithZone:(NSZone *)zone;

@end

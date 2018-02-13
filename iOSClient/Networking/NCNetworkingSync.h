//
//  NCNetworkingSync.h
//  Nextcloud
//
//  Created by Marino Faggiana on 29/10/17.
//  Copyright © 2017 TWS. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "CCNetworking.h"

@interface NCNetworkingSync : NSObject

+ (NCNetworkingSync *)sharedManager;

- (NSError *)uploadFile:(NSString *)localFilePathName remoteFilePathName:(NSString *)remoteFilePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password;
- (NSError *)checkServer:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password;
- (NSError *)readFile:(NSString *)filePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password items:(NSArray **)items;
- (NSError *)readFolder:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password items:(NSArray **)items;
- (NSError *)createFolderAutomaticUpload:(NSString *)folderPathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password encrypted:(BOOL)encrypted;

// ===== End-to-End Encryption =====

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token;
- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token;

- (NSError *)getEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString **)metadata;
- (NSError *)deleteEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID;
- (NSError *)storeEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token;
- (NSError *)updateEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token;

- (NSError *)lockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString **)token;
- (NSError *)unlockEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID token:(NSString  *)token;

- (NSError *)sendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileNameRename:(NSString *)fileName fileNameNewRename:(NSString *)fileNameNew token:(NSString **)token;
- (NSError *)rebuildAndSendEndToEndMetadataOnServerUrl:(NSString *)serverUrl account:(NSString *)account user:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url token:(NSString  **)token;

@end

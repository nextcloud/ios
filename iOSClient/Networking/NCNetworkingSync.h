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
- (NSError *)readFile:(NSString *)filePathName user:(NSString *)user userID:(NSString *)userID password:(NSString *)password;
- (NSError *)readFolder:(NSString *)serverUrl user:(NSString *)user userID:(NSString *)userID password:(NSString *)password items:(NSArray  **)items;

// ===== End-to-End Encryption =====

- (NSError *)markEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token;
- (NSError *)deletemarkEndToEndFolderEncrypted:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID serverUrl:(NSString *)serverUrl token:(NSString  **)token;
- (NSError *)getEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString **)metadata;
- (NSError *)storeEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token;
- (NSError *)updateEndToEndMetadata:(NSString *)user userID:(NSString *)userID password:(NSString *)password url:(NSString *)url fileID:(NSString *)fileID metadata:(NSString *)metadata token:(NSString  **)token;

@end

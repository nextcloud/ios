//
//  CCCrypto.h
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 10/08/16.
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
#include <CommonCrypto/CommonDigest.h>

#import "AESCrypt.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"
#import "CCMetadata.h"
#import "CCUtility.h"

@interface CCCrypto : NSObject

+ (id)sharedManager;

- (NSString *)getKeyPasscode:(NSString *)uuid;

- (void)autoInsertPasscodeUUID:(NSString *)uuid text:(NSString *)text;

- (BOOL)verifyPasscode:(NSString *)passcode uuid:(NSString*)uuid text:(NSString *)text;

- (BOOL)createFilePlist:(NSString *)fileNamePath title:(NSString *)title len:(NSUInteger)len directory:(BOOL)directory uuid:(NSString *)uuid nameCurrentDevice:(NSString *)nameCurrentDevice icon:(NSString *)icon;

- (void)addPlistImage:(NSString *)fileNamePath fileNamePathImage:(NSString *)fileNamePathImage;

- (BOOL)updateTitleFilePlist:(NSString *)fileName title:(NSString *)title directoryUser:(NSString *)directoryUser;

- (NSString *)createFileDirectoryPlist:(CCMetadata *)metadata;

- (BOOL)createTemplatesPlist:(NSString *)nameFile title:(NSString *)title uuid:(NSString *)uuid icon:(NSString *)icon model:(NSString *)model dictionary:(NSMutableDictionary*)dictionary;

- (NSMutableDictionary *)getDictionaryEncrypted:(NSString *)fileName uuid:(NSString *)uuid isLocal:(BOOL)isLocal directoryUser:(NSString *)directoryUser;

- (NSString *)getHintFromFile:(NSString *)fileName isLocal:(BOOL)isLocal directoryUser:(NSString *)directoryUser;

- (NSString *)createFilenameEncryptor:(NSString *)fileName uuid:(NSString *)uuid;

- (NSString *)encryptWithCreatePlist:(NSString *)fileName fileNameEncrypted:(NSString*)fileNameEncrypted passcode:(NSString *)passcode directoryUser:(NSString *)directoryUser;

- (NSUInteger)decrypt:(NSString *)fileName fileNameDecrypted:(NSString*)fileNameDecrypted fileNamePrint:(NSString *)fileNamePrint password:(NSString *)password directoryUser:(NSString *)directoryUser;

- (NSString *)createSHA512:(NSString *)string;

@end

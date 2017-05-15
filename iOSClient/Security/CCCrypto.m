//
//  CCCrypto.m
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

#import "CCCrypto.h"

@implementation CCCrypto

//Singleton
+ (id)sharedManager {
    static CCCrypto *CCCrypto = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CCCrypto = [[self alloc] init];
    });
    return CCCrypto;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Encryption function =====
#pragma --------------------------------------------------------------------------------------------

// return password
- (NSString *)getKeyPasscode:(NSString *)uuid
{
    NSString *key;
    NSString *passcode = [CCUtility getKeyChainPasscodeForUUID:uuid];
    
    if (passcode) key = [AESCrypt encrypt:uuid password:passcode];

    return key;
}

- (void)autoInsertPasscodeUUID:(NSString *)uuid text:(NSString *)text
{
    NSString *key;
    NSString *passcode;
    
    // if return the passcode the UUID it has already entered
    if ([[CCUtility getKeyChainPasscodeForUUID:uuid] length] > 0)
        return;
    
    // verify if the password of the UUID insert is good (OPTIMIZATION)
    passcode = [CCUtility getKeyChainPasscodeForUUID:[CCUtility getUUID]];
    key = [AESCrypt encrypt:uuid password:passcode];
        
    // if the decryption it's ok insert UUID with Passcode in KeyChain
    if([AESCrypt decrypt:text password:key])
        [CCUtility setKeyChainPasscodeForUUID:uuid conPasscode:passcode];
}

- (BOOL)verifyPasscode:(NSString *)passcode uuid:(NSString*)uuid text:(NSString *)text
{
    NSString *key;
    
    key = [AESCrypt encrypt:uuid password:passcode];
    NSString *textDecrypted = [AESCrypt decrypt:text password:key];
    
    if([textDecrypted length]) return true;
    else return false;
}

- (BOOL)createFilePlist:(NSString *)fileNamePath title:(NSString *)title len:(NSUInteger)len directory:(BOOL)directory uuid:(NSString *)uuid nameCurrentDevice:(NSString *)nameCurrentDevice icon:(NSString *)icon
{
    NSMutableDictionary *data;
    NSString *hint = [CCUtility getHint];
    
    // se non ha già l'estensione plist aggiungila
    if([fileNamePath rangeOfString:@".plist"].location == NSNotFound) fileNamePath = [fileNamePath stringByAppendingString:@".plist"];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNamePath])
        data = [[NSMutableDictionary alloc] initWithContentsOfFile:fileNamePath];
    else
        data = [[NSMutableDictionary alloc] init];
    
    [data setObject: [NSNumber numberWithBool:directory] forKey:@"dir"];
    if ([hint length] > 0) [data setObject:[AESCrypt encrypt:hint password:k_UUID_SIM] forKey:@"hint"];
    if ([icon length] > 0) [data setObject:icon forKey:@"icon"];
    [data setObject: [NSString stringWithFormat:@"%li", (unsigned long)len] forKey:@"len"];
    [data setObject: nameCurrentDevice forKey:@"namecurrentdevice"];
    [data setObject: k_versionProtocolPlist forKey:@"protocol"];
    [data setObject: title forKey:@"title"];
    [data setObject: k_metadataType_file forKey:@"type"];
    [data setObject: uuid forKey:@"uuid"];
    [data setObject: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"version"];
    
    return [data writeToFile:fileNamePath atomically:YES];
}

- (void)addPlistImage:(NSString *)fileNamePath fileNamePathImage:(NSString *)fileNamePathImage
{
    NSMutableDictionary *plist = [[NSMutableDictionary alloc] initWithContentsOfFile:fileNamePath];
    
    if (plist) {
    
        UIImage *image = [UIImage imageWithContentsOfFile:fileNamePathImage];
        
        if (image) {
            
            NSData *dataImage = UIImagePNGRepresentation(image);
        
            NSError *error;
            NSString *passcode = [self getKeyPasscode:[CCUtility getUUID]];
            if (passcode) dataImage = [RNEncryptor encryptData:dataImage withSettings:kRNCryptorAES256Settings password:passcode error:&error];
            else dataImage = nil;
        
            if (dataImage && error == nil) {
            
                [plist setObject:dataImage forKey:@"image"];
                [plist writeToFile:fileNamePath atomically:YES];
            }
        }
    }
}

- (BOOL)updateTitleFilePlist:(NSString *)fileName title:(NSString *)title directoryUser:(NSString *)directoryUser
{
    // if not plist extension add it
    if([fileName rangeOfString:@".plist"].location == NSNotFound) fileName = [fileName stringByAppendingString:@".plist"];
    
    // open file plist
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]];
    
    if (data) {
        
        [data setObject:title forKey:@"title"];
        [data writeToFile:[NSTemporaryDirectory() stringByAppendingString:fileName] atomically:YES];
        
        return YES;
    }

    return NO;
}

- (NSString *)createFileDirectoryPlist:(CCMetadata *)metadata
{
    NSMutableDictionary *data;
    
    NSString *fileName = [self createFilenameEncryptor:metadata.fileNamePrint uuid:metadata.uuid];
    NSString *title = [AESCrypt encrypt:metadata.fileNamePrint password:[self getKeyPasscode:metadata.uuid]];
    NSString *fileNamePath = [NSString stringWithFormat:@"%@%@.plist", NSTemporaryDirectory(), fileName];
    NSString *hint = [CCUtility getHint];
        
    if ([[NSFileManager defaultManager] fileExistsAtPath:fileNamePath])
        data = [[NSMutableDictionary alloc] initWithContentsOfFile:fileNamePath];
    else
        data = [[NSMutableDictionary alloc] init];
    
    [data setObject: [NSNumber numberWithBool:true] forKey:@"dir"];
    if ([hint length] > 0) [data setObject: [AESCrypt encrypt:hint password:k_UUID_SIM] forKey:@"hint"];
    [data setObject: @"0" forKey:@"len"];
    [data setObject: metadata.nameCurrentDevice forKey:@"namecurrentdevice"];
    [data setObject: k_versionProtocolPlist forKey:@"protocol"];
    [data setObject: title forKey:@"title"];
    [data setObject: k_metadataType_file forKey:@"type"];
    [data setObject: metadata.uuid forKey:@"uuid"];
    [data setObject: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"version"];
    
    if ([data writeToFile:fileNamePath atomically:YES]) return fileName;
    else return nil;
}

- (BOOL)createTemplatesPlist:(NSString *)nameFile title:(NSString *)title uuid:(NSString *)uuid icon:(NSString *)icon model:(NSString *)model dictionary:(NSMutableDictionary*)dictionary
{
    NSString *encrypted;
    NSString *passcode = [self getKeyPasscode:uuid];
    NSString *fileNamePath = [NSTemporaryDirectory() stringByAppendingString:nameFile];
    NSString *fileCryptoPath = [NSTemporaryDirectory() stringByAppendingString:[CCUtility trasformedFileNamePlistInCrypto:nameFile]];
    NSString *hint = [CCUtility getHint];
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    
    for (NSString *key in [dictionary allKeys]) {
        encrypted = [CCUtility stringValueForKey:key conDictionary:dictionary];
        if ([encrypted length] == 0) encrypted = @"";
        else encrypted = [AESCrypt encrypt:encrypted password:passcode];
        [dictionary setObject:encrypted forKey:key];
    }
    
    [data setObject: dictionary forKey:@"field"];
    if ([hint length] > 0) [data setObject: [AESCrypt encrypt:hint password:k_UUID_SIM] forKey:@"hint"];
    [data setObject: icon forKey:@"icon"];
    [data setObject: model forKey:@"model"];
    [data setObject: [CCUtility getNameCurrentDevice] forKey:@"namecurrentdevice"];
    [data setObject: k_versionProtocolPlist forKey:@"protocol"];
    [data setObject: title forKey:@"title"];
    [data setObject: k_metadataType_template forKey:@"type"];
    [data setObject: uuid forKey:@"uuid"];
    [data setObject: [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"] forKey:@"version"];

    BOOL ritorno = [data writeToFile:fileNamePath atomically:YES];
    
    if (ritorno)
        [CCUtility copyFileAtPath:fileNamePath toPath:fileCryptoPath];
    
    return ritorno;
}

- (NSMutableDictionary *)getDictionaryEncrypted:(NSString *)fileName uuid:(NSString *)uuid isLocal:(BOOL)isLocal directoryUser:(NSString *)directoryUser
{
    NSMutableDictionary *data;
    NSString *clearText;
    NSString *passcode = [self getKeyPasscode:uuid];
    NSString *serverUrl;
    
    if (isLocal) serverUrl = [CCUtility getDirectoryLocal];
    else serverUrl = directoryUser;
    
    NSString *fileNamePath = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:fileNamePath])
        return nil;
    
    data = [[NSMutableDictionary alloc] initWithContentsOfFile:fileNamePath];
    
    if (!data)
        return nil;
    
    NSMutableDictionary *dictionary = [data objectForKey:@"field"];
    
    for (NSString *key in [dictionary allKeys]) {
        NSString *valore = [dictionary objectForKey:key];
        if ([valore length]) clearText = [AESCrypt decrypt:valore password:passcode];
        else clearText = @"";
        if ([clearText length]) [dictionary setObject:clearText forKey:key];
    }
    
    return dictionary;
}

- (NSString *)getHintFromFile:(NSString *)fileName isLocal:(BOOL)isLocal directoryUser:(NSString *)directoryUser
{
    NSString *serverUrl;
    
    if (isLocal) serverUrl = [CCUtility getDirectoryLocal];
    else serverUrl = directoryUser;
    
    NSString *filePath = [NSString stringWithFormat:@"%@/%@", serverUrl, fileName];
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
        return nil;
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
    
    if (!data)
        return nil;
    
    NSString *hintCryptated = [data objectForKey:@"hint"];
    
    if ([hintCryptated length] > 0) return [AESCrypt decrypt:hintCryptated password:k_UUID_SIM];
    else return nil;
}

- (NSString *)createFilenameEncryptor:(NSString *)fileName uuid:(NSString *)uuid
{
    NSMutableString *cryptoString = [NSMutableString stringWithCapacity: 64];
    NSString *letters = @"0J7pfXHaCPTasxQDFsUDcSDiHJmVjgzsqDUUQU75IPYrT13YKNJpvvEq0hH2uDD06mhNxvb8";
    
    NSString *temp = [NSString stringWithFormat:@"%@|%@|%@", fileName, uuid, uuid];
    
    temp = [temp substringToIndex:64];
    for (int i=0; i<64; i++){
        NSString *numero = [temp substringWithRange:NSMakeRange(i, 1)];
        NSInteger index = [numero integerValue];
        if (index > 0) [cryptoString appendFormat: @"%C", [letters characterAtIndex:index]];
        else [cryptoString appendFormat: @"%C", [letters characterAtIndex:i]];
    }

    return [NSString stringWithFormat:@"%@crypto", cryptoString];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Encypt =====
#pragma---------------------------------------------------------------------------------------------

- (NSString *)encryptWithCreatePlist:(NSString *)fileName fileNameEncrypted:(NSString*)fileNameEncrypted passcode:(NSString *)passcode directoryUser:(NSString *)directoryUser
{
    NSString *uuid = [CCUtility getUUID];
    NSString *nameCurrentDevice = [CCUtility getNameCurrentDevice];
    NSString *title = [AESCrypt encrypt:fileName password:passcode];
    NSString *fileNameCrypto = [self createFilenameEncryptor:fileNameEncrypted uuid:uuid];
    
    NSError *error;
    NSUInteger lenData = (NSUInteger)[[[NSFileManager defaultManager] attributesOfItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName] error:nil] fileSize];
    NSUInteger lenEncryptedData;

    @autoreleasepool {
        
        NSData *encryptedData = [RNEncryptor encryptData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileName]] withSettings:kRNCryptorAES256Settings password:passcode error:&error];
        
        lenEncryptedData = encryptedData.length;
        
       if (!error && lenEncryptedData > 0)
           [encryptedData writeToFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameCrypto] atomically:YES];
    }
    
    if (error || lenEncryptedData == 0 || lenData == 0) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameEncrypted] error:nil];
        
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_encrypt_error_", nil), fileName, [error localizedDescription]];
        
        NSLog(@"[LOG] Error encrypt file %@ Err. %@", fileName, msg);
        
        return nil;
    }
    
    [self createFilePlist:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameCrypto] title:title len:lenData directory:NO uuid:uuid nameCurrentDevice:nameCurrentDevice icon:nil];
    
    return fileNameCrypto;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Decrypt =====
#pragma---------------------------------------------------------------------------------------------

- (NSUInteger)decrypt:(NSString *)fileName fileNameDecrypted:(NSString*)fileNameDecrypted fileNamePrint:(NSString *)fileNamePrint password:(NSString *)password directoryUser:(NSString *)directoryUser
{
    NSError *error;
    NSUInteger len;
    
    @autoreleasepool {
        
        NSData *decryptedData = [RNDecryptor decryptData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.crypt", directoryUser, fileName]] withSettings:kRNCryptorAES256Settings password:password error:&error];
        
        len = decryptedData.length;
        
        if (!error && decryptedData > 0)
            [decryptedData writeToFile:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameDecrypted] atomically:YES];
    }

    if (error || len == 0) {
        
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/%@", directoryUser, fileNameDecrypted] error:nil];
        
        NSString *msg = [NSString stringWithFormat:NSLocalizedString(@"_decrypt_error_", nil), fileNamePrint, [error localizedDescription]];
        
        NSLog(@"[LOG] Error decrypt file %@ Err. %@", fileName, msg);
        
        return 0;
    }

    return len;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== SHA512 =====
#pragma---------------------------------------------------------------------------------------------

- (NSString *)createSHA512:(NSString *)string
{
    const char *cstr = [string cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:string.length];
    uint8_t digest[CC_SHA512_DIGEST_LENGTH];
    CC_SHA512(data.bytes, (unsigned int)data.length, digest);
    NSMutableString* output = [NSMutableString  stringWithCapacity:CC_SHA512_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA512_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    return output;
}

@end

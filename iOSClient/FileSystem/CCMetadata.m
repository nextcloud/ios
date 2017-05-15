//
//  CCMetadata.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/09/14.
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

#import "CCMetadata.h"

@implementation CCMetadata

// override del metodo init
//
- (id)init {
    self = [super init];
    return self;
}

- (id)initWithCCMetadata:(CCMetadata *)metadata {
    self = [self init];
    return [metadata copy];
}

- (id)copyWithZone: (NSZone *) zone
{
    CCMetadata *metadata = [[CCMetadata allocWithZone: zone] init];
    
    [metadata setAccount: self.account];
    [metadata setCryptated: self.cryptated];
    [metadata setDate: self.date];
    [metadata setDirectory: self.directory];
    [metadata setDirectoryID: self.directoryID];
    [metadata setErrorPasscode: self.errorPasscode];
    [metadata setFavorite: self.favorite];
    [metadata setFileID: self.fileID];
    [metadata setFileName: self.fileName];
    [metadata setFileNameData: self.fileNameData];
    [metadata setFileNamePrint: self.fileNamePrint];
    [metadata setIconName: self.iconName];
    [metadata setAssetLocalIdentifier: self.assetLocalIdentifier];
    [metadata setModel: self.model];
    [metadata setNameCurrentDevice: self.nameCurrentDevice];
    [metadata setPermissions: self.permissions];
    [metadata setProtocol: self.protocol];
    [metadata setRev: self.rev];
    [metadata setSession: self.session];
    [metadata setSessionError: self.sessionError];
    [metadata setSessionID: self.sessionID];
    [metadata setSessionSelector: self.sessionSelector];
    [metadata setSessionSelectorPost: self.sessionSelectorPost];
    [metadata setSessionTaskIdentifier: self.sessionTaskIdentifier];
    [metadata setSessionTaskIdentifierPlist: self.sessionTaskIdentifierPlist];
    [metadata setSize: self.size];
    [metadata setThumbnailExists: self.thumbnailExists];
    [metadata setTitle: self.title];
    [metadata setType: self.type];
    [metadata setTypeFile: self.typeFile];
    [metadata setUuid: self.uuid];
    
    return metadata;
}

/** Implentation of the NSCoding protocol. */

-(id)initWithCoder:(NSCoder *)decoder
{
    if (self = [self init]) {
        
        _account = [decoder decodeObjectForKey:@"account"];
        _cryptated = [decoder decodeBoolForKey:@"cryptated"];
        _date = [decoder decodeObjectForKey:@"date"];
        _directory = [decoder decodeBoolForKey:@"directory"];
        _directoryID = [decoder decodeObjectForKey:@"directoryID"];
        _errorPasscode = [decoder decodeBoolForKey:@"errorPasscode"];
        _favorite = [decoder decodeBoolForKey:@"favorite"];
        _fileID = [decoder decodeObjectForKey:@"fileID"];
        _fileName = [decoder decodeObjectForKey:@"fileName"];
        _fileNameData = [decoder decodeObjectForKey:@"fileNameData"];
        _fileNamePrint = [decoder decodeObjectForKey:@"fileNamePrint"];
        _iconName = [decoder decodeObjectForKey:@"iconName"];
        _assetLocalIdentifier = [decoder decodeObjectForKey:@"assetLocalIdentifier"];
        _model = [decoder decodeObjectForKey:@"model"];
        _nameCurrentDevice = [decoder decodeObjectForKey:@"nameCurrentDevice"];
        _permissions = [decoder decodeObjectForKey:@"permissions"];
        _protocol = [decoder decodeObjectForKey:@"protocol"];
        _rev = [decoder decodeObjectForKey:@"rev"];
        _session = [decoder decodeObjectForKey:@"session"];
        _sessionError = [decoder decodeObjectForKey:@"sessionError"];
        _sessionID = [decoder decodeObjectForKey:@"sessionID"];
        _sessionSelector = [decoder decodeObjectForKey:@"sessionSelector"];
        _sessionSelectorPost = [decoder decodeObjectForKey:@"sessionSelectorPost"];
        _sessionTaskIdentifier = [decoder decodeInt32ForKey:@"sessionTaskIdentifier"];
        _sessionTaskIdentifierPlist = [decoder decodeInt32ForKey:@"sessionTaskIdentifierPlist"];
        _size = [decoder decodeDoubleForKey:@"size"];
        _thumbnailExists = [decoder decodeBoolForKey:@"thumbnailExists"];
        _title = [decoder decodeObjectForKey:@"title"];
        _type = [decoder decodeObjectForKey:@"type"];
        _typeFile = [decoder decodeObjectForKey:@"typeFile"];
        _uuid = [decoder decodeObjectForKey:@"uuid"];
    };
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:_account forKey:@"account"];
    [encoder encodeBool:_cryptated forKey:@"cryptated"];
    [encoder encodeObject:_date forKey:@"date"];
    [encoder encodeBool:_directory forKey:@"directory"];
    [encoder encodeObject:_directoryID forKey:@"directoryID"];
    [encoder encodeBool:_errorPasscode forKey:@"errorPasscode"];
    [encoder encodeBool:_directory forKey:@"favorite"];
    [encoder encodeObject:_fileID forKey:@"fileID"];
    [encoder encodeObject:_fileName forKey:@"fileName"];
    [encoder encodeObject:_fileNameData forKey:@"fileNameData"];
    [encoder encodeObject:_fileNamePrint forKey:@"fileNamePrint"];
    [encoder encodeObject:_iconName forKey:@"iconName"];
    [encoder encodeObject:_assetLocalIdentifier forKey:@"assetLocalIdentifier"];
    [encoder encodeObject:_model forKey:@"model"];
    [encoder encodeObject:_nameCurrentDevice forKey:@"nameCurrentDevice"];
    [encoder encodeObject:_permissions forKey:@"permissions"];
    [encoder encodeObject:_protocol forKey:@"protocol"];
    [encoder encodeObject:_rev forKey:@"rev"];
    [encoder encodeObject:_session forKey:@"session"];
    [encoder encodeObject:_sessionError forKey:@"sessionError"];
    [encoder encodeObject:_sessionID forKey:@"sessionID"];
    [encoder encodeObject:_sessionSelector forKey:@"sessionSelector"];
    [encoder encodeObject:_sessionSelectorPost forKey:@"sessionSelectorPost"];
    [encoder encodeInt32:_sessionTaskIdentifier forKey:@"sessionTaskIdentifier"];
    [encoder encodeInt32:_sessionTaskIdentifierPlist forKey:@"sessionTaskIdentifierPlist"];
    [encoder encodeDouble:_size forKey:@"size"];
    [encoder encodeBool:_thumbnailExists forKey:@"thumbnailExists"];
    [encoder encodeObject:_title forKey:@"title"];
    [encoder encodeObject:_type forKey:@"type"];
    [encoder encodeObject:_typeFile forKey:@"typeFile"];
    [encoder encodeObject:_uuid forKey:@"uuid"];
}

@end


@implementation CCMetadataNet

- (id)init
{
    self = [super init];
    self.priority = NSOperationQueuePriorityNormal;
    return self;
}

- (id)initWithAccount:(NSString *)withAccount
{
    self = [super init];
    
    if (self) {
        
        _account = withAccount;
        _priority = NSOperationQueuePriorityNormal;
    }
    
    return self;
}

- (id)copyWithZone: (NSZone *) zone
{
    CCMetadataNet *metadataNet = [[CCMetadataNet allocWithZone: zone] init];
    
    [metadataNet setAccount: self.account];
    [metadataNet setAction: self.action];
    [metadataNet setAssetLocalIdentifier: self.assetLocalIdentifier];
    [metadataNet setCryptated: self.cryptated];
    [metadataNet setDate: self.date];
    [metadataNet setDelegate: self.delegate];
    [metadataNet setDirectory: self.directory];
    [metadataNet setDirectoryID: self.directoryID];
    [metadataNet setDirectoryIDTo: self.directoryIDTo];
    [metadataNet setDownloadData: self.downloadData];
    [metadataNet setDownloadPlist: self.downloadPlist];
    [metadataNet setErrorCode: self.errorCode];
    [metadataNet setErrorRetry: self.errorRetry];
    [metadataNet setExpirationTime: self.expirationTime];
    [metadataNet setFileID: self.fileID];
    [metadataNet setFileName: self.fileName];
    [metadataNet setFileNameTo: self.fileNameTo];
    [metadataNet setFileNameLocal: self.fileNameLocal];
    [metadataNet setFileNamePrint: self.fileNamePrint];
    [metadataNet setMetadata: self.metadata];
    [metadataNet setOptions: self.options];
    [metadataNet setPassword: self.password];
    [metadataNet setPathFolder: self.pathFolder];
    [metadataNet setPriority: self.priority];
    [metadataNet setQueue: self.queue];
    [metadataNet setRev:self.rev];
    [metadataNet setServerUrl: self.serverUrl];
    [metadataNet setServerUrlTo: self.serverUrlTo];
    [metadataNet setSelector: self.selector];
    [metadataNet setSelectorPost: self.selectorPost];
    [metadataNet setSession: self.session];
    [metadataNet setSessionID: self.sessionID];
    [metadataNet setShare: self.share];
    [metadataNet setShareeType: self.shareeType];
    [metadataNet setSharePermission: self.sharePermission];
    [metadataNet setSize: self.size];
    [metadataNet setTaskStatus: self.taskStatus];
    
    return metadataNet;
}

@end

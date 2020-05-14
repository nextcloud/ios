//
//  OCFileDto.h
//  Owncloud iOs Client
//
// Copyright (C) 2016, ownCloud GmbH. ( http://www.owncloud.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//
//

//
//  Add Support for Quota
//  quotaUsed and quotaAvailable
//
//  Add Support for Favorite
//  isFavorite
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//

#import <Foundation/Foundation.h>

@interface OCFileDto : NSObject

@property (nonatomic, copy) NSString *filePath;
@property (nonatomic, copy) NSString *fileName;
@property BOOL isDirectory;
@property long size;
@property long date;
@property long creationDate;
@property (nonatomic, copy) NSString *etag;
@property (nonatomic, copy) NSString *permissions;
@property (nonatomic, copy) NSString *ocId;
@property (nonatomic, copy) NSString *fileId;
@property BOOL isFavorite;
@property BOOL isEncrypted;
@property (nonatomic, copy) NSString *trashbinFileName;
@property (nonatomic, copy) NSString *trashbinOriginalLocation;
@property long trashbinDeletionTime;
@property BOOL hasPreview;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) NSString *contentType;
@property (nonatomic, copy) NSString *resourceType;
@property long quotaUsedBytes;
@property long quotaAvailableBytes;
@property (nonatomic, copy) NSString *mountType;
@property (nonatomic, copy) NSString *ownerId;
@property (nonatomic, copy) NSString *ownerDisplayName;
@property BOOL commentsUnread;

@end

//
//  OCSharedDto.h
//  OCCommunicationLib
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

#import <Foundation/Foundation.h>

@interface OCSharedDto : NSObject

typedef enum {
    shareTypeUser = 0,
    shareTypeGroup = 1,
    shareTypeLink = 3,
    shareTypeEmail = 4,
    shareTypeContact = 5,
    shareTypeRemote = 6
} enumShareType;

@property NSInteger idRemoteShared;
@property BOOL isDirectory;
@property NSInteger itemSource;
@property NSInteger parent;
@property NSInteger shareType;
@property (nonatomic, copy) NSString *shareWith;
@property NSInteger fileSource;
@property (nonatomic, copy) NSString *path;
@property NSInteger permissions;
@property long sharedDate;
@property long expirationDate;
@property (nonatomic, copy) NSString *token;
@property NSInteger storage;
@property NSInteger mailSend;
@property (nonatomic, copy) NSString *uidOwner;
@property (nonatomic, copy) NSString *shareWithDisplayName;
@property (nonatomic, copy) NSString *displayNameOwner;
@property (nonatomic, copy) NSString *uidFileOwner;
@property (nonatomic, copy) NSString *fileTarget;


@end

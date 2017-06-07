//
//  OCCommunication.m
//  Owncloud iOs Client
//
// Copyright (C) 2016, ownCloud GmbH.  ( http://www.owncloud.org/ )
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
//  Add : getNotificationServer & setNotificationServer
//  Add : getUserProfileServer
//  Add : Support for Favorite
//  Add : getActivityServer
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//  Copyright (c) 2017 TWS. All rights reserved.
//


#import "OCCommunication.h"
#import "OCHTTPRequestOperation.h"
#import "UtilsFramework.h"
#import "OCXMLParser.h"
#import "OCXMLSharedParser.h"
#import "OCXMLServerErrorsParser.h"
#import "OCXMLListParser.h"
#import "NSString+Encode.h"
#import "OCFrameworkConstants.h"
#import "OCWebDAVClient.h"
#import "OCXMLShareByLinkParser.h"
#import "OCErrorMsg.h"
#import "AFURLSessionManager.h"
#import "OCShareUser.h"
#import "OCActivity.h"
#import "OCExternalSites.h"
#import "OCCapabilities.h"
#import "OCNotifications.h"
#import "OCNotificationsAction.h"
#import "OCRichObjectStrings.h"
#import "OCUserProfile.h"

@interface OCCommunication ()

@property (nonatomic, strong) NSString *currentServerVersion;

@end

@implementation OCCommunication


-(id) init {
    
    self = [super init];
    
    if (self) {
        
        //Init the Donwload queue array
        self.downloadTaskNetworkQueueArray = [NSMutableArray new];
        
        //Credentials not set yet
        self.kindOfCredential = credentialNotSet;
        
        [self setSecurityPolicyManagers:[self createSecurityPolicy]];
        
        self.isCookiesAvailable = YES;
        self.isForbiddenCharactersAvailable = NO;
        
#ifdef UNIT_TEST
        
        self.uploadSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        self.downloadSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        self.networkSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        self.networkSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
#else
        //Network Upload queue for NSURLSession (iOS 7)
        NSURLSessionConfiguration *uploadConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_session_name];
        uploadConfiguration.HTTPShouldUsePipelining = YES;
        uploadConfiguration.HTTPMaximumConnectionsPerHost = 1;
        uploadConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        self.uploadSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:uploadConfiguration];
        [self.uploadSessionManager.operationQueue setMaxConcurrentOperationCount:1];
        
        //Network Download queue for NSURLSession (iOS 7)
        NSURLSessionConfiguration *downConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:k_download_session_name];
        downConfiguration.HTTPShouldUsePipelining = YES;
        downConfiguration.HTTPMaximumConnectionsPerHost = 1;
        downConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        self.downloadSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:downConfiguration];
        [self.downloadSessionManager.operationQueue setMaxConcurrentOperationCount:1];
        
        //Network Download queue for NSURLSession (iOS 7)
        NSURLSessionConfiguration *networkConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        networkConfiguration.HTTPShouldUsePipelining = YES;
        networkConfiguration.HTTPMaximumConnectionsPerHost = 1;
        networkConfiguration.requestCachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        self.networkSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:networkConfiguration];
        [self.networkSessionManager.operationQueue setMaxConcurrentOperationCount:1];
        self.networkSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
#endif
        
    }
    
    return self;
}

-(id) initWithUploadSessionManager:(AFURLSessionManager *) uploadSessionManager {
    
    self = [super init];
    
    if (self) {
        
        //Init the Donwload queue array
        self.downloadTaskNetworkQueueArray = [NSMutableArray new];
        
        self.isCookiesAvailable = YES;
        self.isForbiddenCharactersAvailable = NO;
        
        //Credentials not set yet
        self.kindOfCredential = credentialNotSet;
        
        [self setSecurityPolicyManagers:[self createSecurityPolicy]];
        
        self.uploadSessionManager = uploadSessionManager;
    }
    
    return self;
}

-(id) initWithUploadSessionManager:(AFURLSessionManager *) uploadSessionManager andDownloadSessionManager:(AFURLSessionManager *) downloadSessionManager andNetworkSessionManager:(AFURLSessionManager *) networkSessionManager {
    
    self = [super init];
    
    if (self) {
    
        //Init the Donwload queue array
        self.downloadTaskNetworkQueueArray = [NSMutableArray new];
        
        //Credentials not set yet
        self.kindOfCredential = credentialNotSet;
        
        [self setSecurityPolicyManagers:[self createSecurityPolicy]];
        
        self.uploadSessionManager = uploadSessionManager;
        self.downloadSessionManager = downloadSessionManager;
        self.networkSessionManager = networkSessionManager;
    }
    
    return self;
}

- (AFSecurityPolicy *) createSecurityPolicy {
    return [AFSecurityPolicy defaultPolicy];
}

- (void)setSecurityPolicyManagers:(AFSecurityPolicy *)securityPolicy {
    self.securityPolicy = securityPolicy;
    self.uploadSessionManager.securityPolicy = securityPolicy;
    self.downloadSessionManager.securityPolicy = securityPolicy;
}

#pragma mark - Setting Credentials

- (void) setCredentialsWithUser:(NSString*) user andPassword:(NSString*) password  {
    self.kindOfCredential = credentialNormal;
    self.user = user;
    self.password = password;
}

- (void) setCredentialsWithCookie:(NSString*) cookie {
    self.kindOfCredential = credentialCookie;
    self.password = cookie;
}

- (void) setCredentialsOauthWithToken:(NSString*) token {
    self.kindOfCredential = credentialOauth;
    self.password = token;
}

///-----------------------------------
/// @name getRequestWithCredentials
///-----------------------------------

/**
 * Method to return the request with the right credential
 *
 * @param OCWebDAVClient like a dinamic typed
 *
 * @return OCWebDAVClient like a dinamic typed
 *
 */
- (id) getRequestWithCredentials:(id) request {
    
    if ([request isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest *myRequest = (NSMutableURLRequest *)request;
        
        switch (self.kindOfCredential) {
            case credentialNotSet:
                //Without credentials
                break;
            case credentialNormal:
            {
                NSString *basicAuthCredentials = [NSString stringWithFormat:@"%@:%@", self.user, self.password];
                [myRequest addValue:[NSString stringWithFormat:@"Basic %@", [UtilsFramework AFBase64EncodedStringFromString:basicAuthCredentials]] forHTTPHeaderField:@"Authorization"];
                break;
            }
            case credentialCookie:
                NSLog(@"Cookie: %@", self.password);
                [myRequest addValue:self.password forHTTPHeaderField:@"Cookie"];
                break;
            case credentialOauth:
                [myRequest addValue:[NSString stringWithFormat:@"Bearer %@", self.password] forHTTPHeaderField:@"Authorization"];
                break;
            default:
                break;
        }
        
        if (self.userAgent) {
            [myRequest addValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
        }
        
        return myRequest;
        
    } else if([request isKindOfClass:[OCWebDAVClient class]]) {
        OCWebDAVClient *myRequest = (OCWebDAVClient *)request;
        
        switch (self.kindOfCredential) {
            case credentialNotSet:
                //Without credentials
                break;
            case credentialNormal:
                [myRequest setAuthorizationHeaderWithUsername:self.user password:self.password];
                break;
            case credentialCookie:
                [myRequest setAuthorizationHeaderWithCookie:self.password];
                break;
            case credentialOauth:
                [myRequest setAuthorizationHeaderWithToken:[NSString stringWithFormat:@"Bearer %@", self.password]];
                break;
            default:
                break;
        }
        
        if (self.userAgent) {
           [myRequest setUserAgent:self.userAgent];
        }
    
        return request;
        
    } else {
        NSLog(@"We do not know witch kind of object is");
        return  request;
    }
}


#pragma mark - WebDav network Operations

///-----------------------------------
/// @name Check Server
///-----------------------------------
- (void) checkServer: (NSString *) path
     onCommunication:(OCCommunication *)sharedOCCommunication
      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    if (self.userAgent) {
        [request setUserAgent:self.userAgent];
    }
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    [request checkServer:path onCommunication:sharedOCCommunication
                 success:^(NSHTTPURLResponse *response, id responseObject) {
                     if (successRequest) {
                         successRequest(response, request.redirectedServer);
                     }
                 } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
                     failureRequest(response, error, request.redirectedServer);
                 }];
}

///-----------------------------------
/// @name Create a folder
///-----------------------------------
- (void) createFolder: (NSString *) path
      onCommunication:(OCCommunication *)sharedOCCommunication withForbiddenCharactersSupported:(BOOL)isFCSupported
       successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
       failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest
   errorBeforeRequest:(void(^)(NSError *error)) errorBeforeRequest {
    
    
    if ([UtilsFramework isForbiddenCharactersInFileName:[UtilsFramework getFileNameOrFolderByPath:path] withForbiddenCharactersSupported:isFCSupported]) {
        NSError *error = [UtilsFramework getErrorByCodeId:OCErrorForbidenCharacters];
        errorBeforeRequest(error);
    } else {
        OCWebDAVClient *request = [OCWebDAVClient new];
        request = [self getRequestWithCredentials:request];
        
        
        path = [path encodeString:NSUTF8StringEncoding];
        
        [request makeCollection:path onCommunication:sharedOCCommunication
                        success:^(NSHTTPURLResponse *response, id responseObject) {
                            if (successRequest) {
                                successRequest(response, request.redirectedServer);
                            }
                        } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
                            
                            OCXMLServerErrorsParser *serverErrorParser = [OCXMLServerErrorsParser new];
                            
                            [serverErrorParser startToParseWithData:responseData withCompleteBlock:^(NSError *err) {
                                
                                if (err) {
                                    failureRequest(response, err, request.redirectedServer);
                                }else{
                                    failureRequest(response, error, request.redirectedServer);
                                }
                                
                                
                            }];
                            
                        }];
    }
}

///-----------------------------------
/// @name Move a file or a folder
///-----------------------------------
- (void) moveFileOrFolder:(NSString *)sourcePath
                toDestiny:(NSString *)destinyPath
          onCommunication:(OCCommunication *)sharedOCCommunication withForbiddenCharactersSupported:(BOOL)isFCSupported
           successRequest:(void (^)(NSHTTPURLResponse *response, NSString *redirectServer))successRequest
           failureRequest:(void (^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failureRequest
       errorBeforeRequest:(void (^)(NSError *error))errorBeforeRequest {
    
    if ([UtilsFramework isTheSameFileOrFolderByNewURLString:destinyPath andOriginURLString:sourcePath]) {
        //We check that we are not trying to move the file to the same place
        NSError *error = [UtilsFramework getErrorByCodeId:OCErrorMovingTheDestinyAndOriginAreTheSame];
        errorBeforeRequest(error);
    } else if ([UtilsFramework isAFolderUnderItByNewURLString:destinyPath andOriginURLString:sourcePath]) {
        //We check we are not trying to move a folder inside himself
        NSError *error = [UtilsFramework getErrorByCodeId:OCErrorMovingFolderInsideHimself];
        errorBeforeRequest(error);
    } else if ([UtilsFramework isForbiddenCharactersInFileName:[UtilsFramework getFileNameOrFolderByPath:destinyPath] withForbiddenCharactersSupported:isFCSupported]) {
        //We check that we are making a move not a rename to prevent special characters problems
        NSError *error = [UtilsFramework getErrorByCodeId:OCErrorMovingDestinyNameHaveForbiddenCharacters];
        errorBeforeRequest(error);
    } else {
        
        sourcePath = [sourcePath encodeString:NSUTF8StringEncoding];
        destinyPath = [destinyPath encodeString:NSUTF8StringEncoding];
        
        OCWebDAVClient *request = [OCWebDAVClient new];
        request = [self getRequestWithCredentials:request];
        
        
        [request movePath:sourcePath toPath:destinyPath onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
            if (successRequest) {
                successRequest(response, request.redirectedServer);
            }
        } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
            
            OCXMLServerErrorsParser *serverErrorParser = [OCXMLServerErrorsParser new];
            
            [serverErrorParser startToParseWithData:responseData withCompleteBlock:^(NSError *err) {
                
                if (err) {
                    failureRequest(response, err, request.redirectedServer);
                }else{
                    failureRequest(response, error, request.redirectedServer);
                }
                
            }];
            
        }];
    }
}


///-----------------------------------
/// @name Delete a file or a folder
///-----------------------------------
- (void) deleteFileOrFolder:(NSString *)path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void (^)(NSHTTPURLResponse *response, NSString *redirectedServer))successRequest
              failureRquest:(void (^)(NSHTTPURLResponse *resposne, NSError *error, NSString *redirectedServer))failureRequest {
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request deletePath:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        if (successRequest) {
            successRequest(response, request.redirectedServer);
        }
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}


///-----------------------------------
/// @name Read folder
///-----------------------------------
- (void) readFolder: (NSString *) path withUserSessionToken:(NSString *)token
    onCommunication:(OCCommunication *)sharedOCCommunication
     successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest
     failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest{
    
    if (!token){
        token = @"no token";
    }
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request listPath:path onCommunication:sharedOCCommunication withUserSessionToken:token success:^(NSHTTPURLResponse *response, id responseObject, NSString *token) {
        if (successRequest) {
            NSData *responseData = (NSData*) responseObject;
            
//            NSString* newStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//            NSLog(@"newStrReadFolder: %@", newStr);
            
            OCXMLParser *parser = [[OCXMLParser alloc]init];
            [parser initParserWithData:responseData];
            NSMutableArray *directoryList = [parser.directoryList mutableCopy];
            
            //Return success
            successRequest(response, directoryList, request.redirectedServer, token);
        }
        
    } failure:^(NSHTTPURLResponse *response, id responseData, NSError *error, NSString *token) {
        NSLog(@"Failure");
        failureRequest(response, error, token, request.redirectedServer);
    }];
}

///-----------------------------------
/// @name Download File Session
///-----------------------------------



- (NSURLSessionDownloadTask *) downloadFileSession:(NSString *)remotePath toDestiny:(NSString *)localPath defaultPriority:(BOOL)defaultPriority onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))downloadProgress successRequest:(void(^)(NSURLResponse *response, NSURL *filePath)) successRequest failureRequest:(void(^)(NSURLResponse *response, NSError *error)) failureRequest {
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    remotePath = [remotePath encodeString:NSUTF8StringEncoding];
    
    NSURLSessionDownloadTask *downloadTask = [request downloadWithSessionPath:remotePath toPath:localPath defaultPriority:defaultPriority onCommunication:sharedOCCommunication progress:^(NSProgress *progress) {
        downloadProgress(progress);
    } success:^(NSURLResponse *response, NSURL *filePath) {
        
        [UtilsFramework addCookiesToStorageFromResponse:(NSURLResponse *) response andPath:[NSURL URLWithString:remotePath]];
        successRequest(response,filePath);
        
    } failure:^(NSURLResponse *response, NSError *error) {
        [UtilsFramework addCookiesToStorageFromResponse:(NSURLResponse *) response andPath:[NSURL URLWithString:remotePath]];
        failureRequest(response,error);
    }];
    
    return downloadTask;
}


///-----------------------------------
/// @name Set Download Task Complete Block
///-----------------------------------


- (void)setDownloadTaskComleteBlock: (NSURL * (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location))block{
    
    [self.downloadSessionManager setDownloadTaskDidFinishDownloadingBlock:block];

    
}


///-----------------------------------
/// @name Set Download Task Did Get Body Data Block
///-----------------------------------


- (void) setDownloadTaskDidGetBodyDataBlock: (void(^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)) block{
    
    [self.downloadSessionManager setDownloadTaskDidWriteDataBlock:^(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite) {
        block(session,downloadTask,bytesWritten,totalBytesWritten,totalBytesExpectedToWrite);
    }];
    
}

///-----------------------------------
/// @name Upload File Session
///-----------------------------------

- (NSURLSessionUploadTask *) uploadFileSession:(NSString *) localPath toDestiny:(NSString *) remotePath onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))uploadProgress successRequest:(void(^)(NSURLResponse *response, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSURLResponse *response, NSString *redirectedServer, NSError *error)) failureRequest failureBeforeRequest:(void(^)(NSError *error)) failureBeforeRequest {
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    remotePath = [remotePath encodeString:NSUTF8StringEncoding];
    
    NSURLSessionUploadTask *uploadTask = [request putWithSessionLocalPath:localPath atRemotePath:remotePath onCommunication:sharedOCCommunication progress:^(NSProgress *progress) {
            uploadProgress(progress);
        } success:^(NSURLResponse *response, id responseObjec){
            [UtilsFramework addCookiesToStorageFromResponse:(NSURLResponse *) response andPath:[NSURL URLWithString:remotePath]];
            //TODO: The second parameter is the redirected server
            successRequest(response, @"");
        } failure:^(NSURLResponse *response, id responseObject, NSError *error) {
            [UtilsFramework addCookiesToStorageFromResponse:(NSURLResponse *) response andPath:[NSURL URLWithString:remotePath]];
            //TODO: The second parameter is the redirected server

            NSData *responseData = (NSData*) responseObject;
            
            OCXMLServerErrorsParser *serverErrorParser = [OCXMLServerErrorsParser new];
            
            [serverErrorParser startToParseWithData:responseData withCompleteBlock:^(NSError *err) {
                
                if (err) {
                    failureRequest(response, @"", err);
                }else{
                    failureRequest(response, @"", error);
                }
                
            }];
            
        } failureBeforeRequest:^(NSError *error) {
            failureBeforeRequest(error);
        }];
    
    return uploadTask;
}

///-----------------------------------
/// @name Set Task Did Complete Block
///-----------------------------------

- (void) setTaskDidCompleteBlock: (void(^)(NSURLSession *session, NSURLSessionTask *task, NSError *error)) block{
    
    [self.uploadSessionManager setTaskDidCompleteBlock:^(NSURLSession *session, NSURLSessionTask *task, NSError *error) {

        block(session, task, error);
    }];
    
}


///-----------------------------------
/// @name Set Task Did Send Body Data Block
///-----------------------------------


- (void) setTaskDidSendBodyDataBlock: (void(^)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend)) block{
    
   [self.uploadSessionManager setTaskDidSendBodyDataBlock:^(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend) {
       block(session, task, bytesSent, totalBytesSent, totalBytesExpectedToSend);
   }];
}


///-----------------------------------
/// @name Read File
///-----------------------------------
- (void) readFile: (NSString *) path
  onCommunication:(OCCommunication *)sharedOCCommunication
   successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer)) successRequest
   failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request propertiesOfPath:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        if (successRequest) {
            NSData *responseData = (NSData*) responseObject;
            
//            NSString* newStr = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//            NSLog(@"newStrReadFile: %@", newStr);

            OCXMLParser *parser = [[OCXMLParser alloc]init];
            [parser initParserWithData:responseData];
            NSMutableArray *directoryList = [parser.directoryList mutableCopy];
            
            //Return success
            successRequest(response, directoryList, request.redirectedServer);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
        
    }];
    
}

///-----------------------------------
/// @name search
///-----------------------------------
- (void)search:(NSString *)path folder:(NSString *)folder fileName:(NSString *)fileName depth:(NSString *)depth dateLastModified:(NSString *)dateLastModified withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest{
    
    if (!token){
        token = @"no token";
    }
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request search:path folder:folder fileName:fileName depth:depth dateLastModified:dateLastModified user:_user onCommunication:sharedOCCommunication withUserSessionToken:token success:^(NSHTTPURLResponse *response, id responseObject, NSString *token) {
        
        if (successRequest) {
            
            NSData *responseData = (NSData*) responseObject;
            
            OCXMLListParser *parser = [OCXMLListParser new];
            [parser initParserWithData:responseData];
            NSMutableArray *searchList = [parser.searchList mutableCopy];
            
            //Return success
            successRequest(response, searchList, request.redirectedServer, token);
        }
        
    } failure:^(NSHTTPURLResponse *response, id responseData, NSError *error, NSString *token) {
        
        failureRequest(response, error, token, request.redirectedServer);
    }];
}

///-----------------------------------
/// @name Setting favorite
///-----------------------------------
- (void)settingFavoriteServer:(NSString *)path andFileOrFolderPath:(NSString *)filePath favorite:(BOOL)favorite withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest {
    
    if (!token){
        token = @"no token";
    }
    
    path = [NSString stringWithFormat:@"%@/files/%@/%@", path, _user, filePath];
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request settingFavorite:path favorite:favorite onCommunication:sharedOCCommunication withUserSessionToken:token success:^(NSHTTPURLResponse *response, id responseObject, NSString *token) {
        
        if (successRequest) {
            //Return success
            successRequest(response, request.redirectedServer, token);
        }
        
    } failure:^(NSHTTPURLResponse *response, id responseData, NSError *error, NSString *token) {
        
        NSLog(@"Failure");
        failureRequest(response, error, token, request.redirectedServer);
    }];
}

///-----------------------------------
/// @name Listing favorites
///-----------------------------------
- (void)listingFavorites:(NSString *)path folder:(NSString *)folder withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest{
    
    if (!token){
        token = @"no token";
    }
    
    path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request listingFavorites:path folder:folder user:_user onCommunication:sharedOCCommunication withUserSessionToken:token success:^(NSHTTPURLResponse *response, id responseObject, NSString *token) {
        
        if (successRequest) {
            
            NSData *responseData = (NSData*) responseObject;
            
            OCXMLListParser *parser = [OCXMLListParser new];
            [parser initParserWithData:responseData];
            NSMutableArray *searchList = [parser.searchList mutableCopy];
            
            //Return success
            successRequest(response, searchList, request.redirectedServer, token);
        }
        
    } failure:^(NSHTTPURLResponse *response, id responseData, NSError *error, NSString *token) {
        
        failureRequest(response, error, token, request.redirectedServer);
    }];
}

#pragma mark - OC API Calls

- (NSString *) getCurrentServerVersion {
    return self.currentServerVersion;
}

- (void) getServerVersionWithPath:(NSString*) path onCommunication:(OCCommunication *)sharedOCCommunication
                   successRequest:(void(^)(NSHTTPURLResponse *response, NSString *serverVersion, NSString *redirectedServer)) success
                   failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failure{
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    
    if (self.userAgent) {
        [request setUserAgent:self.userAgent];
    }
    
    [request getStatusOfTheServer:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *data = (NSData*) responseObject;
        NSString *versionString = [NSString new];
        NSError* error=nil;
        
        if (data) {
            NSMutableDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &error];
            if(error) {
                NSLog(@"Error parsing JSON: %@", error);
            } else {
                //Obtain the server version from the version field
                versionString = [jsonArray valueForKey:@"version"];
                self.currentServerVersion = versionString;
            }
        } else {
            NSLog(@"Error parsing JSON: data is null");
        }
        success(response, versionString, request.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failure(response, error, request.redirectedServer);
    }];
    
}

///-----------------------------------
/// @name Get UserName by cookie
///-----------------------------------

- (void) getUserNameByCookie:(NSString *) cookieString ofServerPath:(NSString *)path onCommunication:
(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *response, NSData *responseData, NSString *redirectedServer))success
                     failure:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failure{
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request requestUserNameOfServer: path byCookie:cookieString onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        success(response, responseObject, request.redirectedServer);
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failure(response, error, request.redirectedServer);
    }];
}

- (void) getFeaturesSupportedByServer:(NSString*) path onCommunication:(OCCommunication *)sharedOCCommunication
                     successRequest:(void(^)(NSHTTPURLResponse *response, BOOL hasShareSupport, BOOL hasShareeSupport, BOOL hasCookiesSupport, BOOL hasForbiddenCharactersSupport, BOOL hasCapabilitiesSupport, BOOL hasFedSharesOptionShareSupport, NSString *redirectedServer)) success
                     failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failure{
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    
    if (self.userAgent) {
        [request setUserAgent:self.userAgent];
    }
    
    [request getStatusOfTheServer:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        if (responseObject) {
            
            NSError* error = nil;
            NSMutableDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData: (NSData*) responseObject options: NSJSONReadingMutableContainers error: &error];
            
            if(error) {
                // NSLog(@"Error parsing JSON: %@", error);
                failure(response, error, request.redirectedServer);
            }else{
                
                self.currentServerVersion = [jsonArray valueForKey:@"version"];
                
                BOOL hasShareSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_shared];
                BOOL hasShareeSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_sharee_api];
                BOOL hasCookiesSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_cookies];
                BOOL hasForbiddenCharactersSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_forbidden_characters];
                BOOL hasCapabilitiesSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_capabilities];
                BOOL hasFedSharesOptionShareSupport = [UtilsFramework isServerVersion:self.currentServerVersion higherThanLimitVersion:k_version_support_share_option_fed_share];

                success(response, hasShareSupport, hasShareeSupport, hasCookiesSupport, hasForbiddenCharactersSupport, hasCapabilitiesSupport, hasFedSharesOptionShareSupport, request.redirectedServer);
            }
            
        } else {
            // NSLog(@"Error parsing JSON: data is null");
            failure(response, nil, request.redirectedServer);
        }
        
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failure(response, error, request.redirectedServer);
    }];

    
    
    
}


- (void) readSharedByServer: (NSString *) path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfShared, NSString *redirectedServer)) successRequest
             failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    path = [path encodeString:NSUTF8StringEncoding];
    path = [path stringByAppendingString:k_url_acces_shared_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request listSharedByServer:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        if (successRequest) {
            NSData *responseData = (NSData*) responseObject;
            OCXMLSharedParser *parser = [[OCXMLSharedParser alloc]init];
            
          //NSLog(@"response: %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
            
            [parser initParserWithData:responseData];
            NSMutableArray *sharedList = [parser.shareList mutableCopy];
            
            //Return success
            successRequest(response, sharedList, request.redirectedServer);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void) readSharedByServer: (NSString *) serverPath andPath: (NSString *) path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfShared, NSString *redirectedServer)) successRequest
             failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
   serverPath = [serverPath encodeString:NSUTF8StringEncoding];
   serverPath = [serverPath stringByAppendingString:k_url_acces_shared_api];
    
   path = [path encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request listSharedByServer:serverPath andPath:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        if (successRequest) {
            NSData *responseData = (NSData*) responseObject;
            OCXMLSharedParser *parser = [[OCXMLSharedParser alloc]init];
            
//            NSString *str = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//            NSLog(@"responseDataReadSharedByServer:andPath: %@", str);
//            NSLog(@"pathFolders: %@", path);
//            NSLog(@"serverPath: %@", serverPath);
            
            [parser initParserWithData:responseData];
            NSMutableArray *sharedList = [parser.shareList mutableCopy];
            
            //Return success
            successRequest(response, sharedList, request.redirectedServer);
        }
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void) shareFileOrFolderByServer: (NSString *) serverPath andFileOrFolderPath: (NSString *) filePath andPassword:(NSString *)password
                   onCommunication:(OCCommunication *)sharedOCCommunication
                    successRequest:(void(^)(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer)) successRequest
                    failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_shared_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request shareByLinkFileOrFolderByServer:serverPath andPath:filePath andPassword:password onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        OCXMLShareByLinkParser *parser = [[OCXMLShareByLinkParser alloc]init];
        
      //  NSLog(@"response: %@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        
        [parser initParserWithData:responseData];
        
        switch (parser.statusCode) {
            case kOCSharedAPISuccessful:
            {
                NSString *url = parser.url;
                NSString *token = parser.token;
                
                if (url != nil) {
                    
                    successRequest(response, url, request.redirectedServer);
                    
                }else if (token != nil){
                    //We remove the \n and the empty spaces " "
                    token = [token stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
                    
                    successRequest(response, token, request.redirectedServer);
                    
                }else{
                    
                    NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                    failureRequest(response, error, request.redirectedServer);
                }
                
                break;
            }
                
            default:
            {
                NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                failureRequest(response, error, request.redirectedServer);
            }
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}


- (void) shareFileOrFolderByServer: (NSString *) serverPath andFileOrFolderPath: (NSString *) filePath
                   onCommunication:(OCCommunication *)sharedOCCommunication
                    successRequest:(void(^)(NSHTTPURLResponse *response, NSString *shareLink, NSString *redirectedServer)) successRequest
                    failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_shared_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request shareByLinkFileOrFolderByServer:serverPath andPath:filePath onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        OCXMLShareByLinkParser *parser = [[OCXMLShareByLinkParser alloc]init];
        
      //  NSLog(@"response: %@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        
        [parser initParserWithData:responseData];
        
        switch (parser.statusCode) {
            case kOCSharedAPISuccessful:
            {
                NSString *url = parser.url;
                NSString *token = parser.token;
                
                if (url != nil) {
                    
                    successRequest(response, url, request.redirectedServer);
                    
                }else if (token != nil){
                    //We remove the \n and the empty spaces " "
                    token = [token stringByReplacingOccurrencesOfString:@"\n" withString:@""];
                    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
                    
                    successRequest(response, token, request.redirectedServer);
                    
                }else{
                    
                    NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                    failureRequest(response, error, request.redirectedServer);
                }

                break;
            }
                
            default:
            {
                NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                failureRequest(response, error, request.redirectedServer);
            }
        }

    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void)shareWith:(NSString *)userOrGroup shareeType:(NSInteger)shareeType inServer:(NSString *) serverPath andFileOrFolderPath:(NSString *) filePath andPermissions:(NSInteger) permissions onCommunication:(OCCommunication *)sharedOCCommunication
          successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer))successRequest
          failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failureRequest{
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_shared_api];
    userOrGroup = [userOrGroup encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request shareWith:userOrGroup shareeType:shareeType inServer:serverPath andPath:filePath andPermissions:permissions onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        NSData *responseData = (NSData*) responseObject;
        
        OCXMLShareByLinkParser *parser = [[OCXMLShareByLinkParser alloc]init];
        
        //  NSLog(@"response: %@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        
        [parser initParserWithData:responseData];
        
        switch (parser.statusCode) {
            case kOCSharedAPISuccessful:
            {
                successRequest(response, request.redirectedServer);
                break;
            }
                
            default:
            {
                NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                failureRequest(response, error, request.redirectedServer);
            }
        }
        
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
    
}

- (void) unShareFileOrFolderByServer: (NSString *) path andIdRemoteShared: (NSInteger) idRemoteShared
                     onCommunication:(OCCommunication *)sharedOCCommunication
                      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
                      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest{
    
    path = [path encodeString:NSUTF8StringEncoding];
    path = [path stringByAppendingString:k_url_acces_shared_api];
    path = [path stringByAppendingString:[NSString stringWithFormat:@"/%ld",(long)idRemoteShared]];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request unShareFileOrFolderByServer:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        if (successRequest) {
            //Return success
            successRequest(response, request.redirectedServer);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void) isShareFileOrFolderByServer: (NSString *) path andIdRemoteShared: (NSInteger) idRemoteShared
                     onCommunication:(OCCommunication *)sharedOCCommunication
                      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer, BOOL isShared, id shareDto)) successRequest
                      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    path = [path encodeString:NSUTF8StringEncoding];
    path = [path stringByAppendingString:k_url_acces_shared_api];
    path = [path stringByAppendingString:[NSString stringWithFormat:@"/%ld",(long)idRemoteShared]];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request isShareFileOrFolderByServer:path onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        if (successRequest) {
        
            NSData *responseData = (NSData*) responseObject;
            OCXMLSharedParser *parser = [[OCXMLSharedParser alloc]init];
            
            // NSLog(@"response: %@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
            
            [parser initParserWithData:responseData];
            
             BOOL isShared = NO;
            
             OCSharedDto *shareDto = nil;
            
            if (parser.shareList) {
                
                NSMutableArray *sharedList = [parser.shareList mutableCopy];
                
                if ([sharedList count] > 0) {
                    isShared = YES;
                    shareDto = [sharedList objectAtIndex:0];
                }
                
            }
     
            //Return success
            successRequest(response, request.redirectedServer, isShared, shareDto);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void) updateShare:(NSInteger)shareId ofServerPath:(NSString *)serverPath withPasswordProtect:(NSString*)password andExpirationTime:(NSString*)expirationTime andPermissions:(NSInteger)permissions
                   onCommunication:(OCCommunication *)sharedOCCommunication
                    successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest{
    
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_shared_api];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"/%ld",(long)shareId]];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    [request updateShareItem:shareId ofServerPath:serverPath withPasswordProtect:password andExpirationTime:expirationTime andPermissions:permissions onCommunication:sharedOCCommunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        OCXMLShareByLinkParser *parser = [[OCXMLShareByLinkParser alloc]init];
        
     //   NSLog(@"response: %@", [[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding]);
        
        [parser initParserWithData:responseData];
        
        
        switch (parser.statusCode) {
            case kOCSharedAPISuccessful:
            {
                successRequest(response, request.redirectedServer);
                break;
            }
            
            default:
            {
                NSError *error = [UtilsFramework getErrorWithCode:parser.statusCode andCustomMessageFromTheServer:parser.message];
                failureRequest(response, error, request.redirectedServer);
            }
        }

    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
         failureRequest(response, error, request.redirectedServer);
    }];
    
}

- (void) searchUsersAndGroupsWith:(NSString *)searchString forPage:(NSInteger)page with:(NSInteger)resultsPerPage ofServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest{
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_access_sharee_api];
    
    searchString = [searchString encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    
    [request searchUsersAndGroupsWith:searchString forPage:page with:resultsPerPage ofServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        NSMutableArray *itemList = [NSMutableArray new];
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        
        if (error == nil) {
            
            NSDictionary *ocsDict = [jsongParsed valueForKey:@"ocs"];
            
            NSDictionary *metaDict = [ocsDict valueForKey:@"meta"];
            NSInteger statusCode = [[metaDict valueForKey:@"statuscode"] integerValue];
            
            if (statusCode == kOCShareeAPISuccessful || statusCode == kOCSharedAPISuccessful) {
                
                NSDictionary *dataDict = [ocsDict valueForKey:@"data"];
                NSArray *exactDict = [dataDict valueForKey:@"exact"];
                NSArray *usersFounded = [dataDict valueForKey:@"users"];
                NSArray *groupsFounded = [dataDict valueForKey:@"groups"];
                NSArray *usersRemote = [dataDict valueForKey:@"remotes"];
                NSArray *usersExact = [exactDict valueForKey:@"users"];
                NSArray *groupsExact = [exactDict valueForKey:@"groups"];
                NSArray *remotesExact = [exactDict valueForKey:@"remotes"];
                
                [self addUserItemOfType:shareTypeUser fromArray:usersFounded ToList:itemList];
                [self addUserItemOfType:shareTypeUser fromArray:usersExact ToList:itemList];
                [self addUserItemOfType:shareTypeRemote fromArray:usersRemote ToList:itemList];
                [self addUserItemOfType:shareTypeRemote fromArray:remotesExact ToList:itemList];
                [self addGroupItemFromArray:groupsFounded ToList:itemList];
                [self addGroupItemFromArray:groupsExact ToList:itemList];
            
            }else{
                
                NSString *message = (NSString*)[metaDict objectForKey:@"message"];
                
                if ([message isKindOfClass:[NSNull class]]) {
                    message = @"";
                }
                
                NSError *error = [UtilsFramework getErrorWithCode:statusCode andCustomMessageFromTheServer:message];
                failureRequest(response, error, request.redirectedServer);
                
            }
            
            //Return success
            successRequest(response, itemList, request.redirectedServer);
            
        }
        
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void) getCapabilitiesOfServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest{
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_capabilities];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request getCapabilitiesOfServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"dic: %@",jsongParsed);
        
        OCCapabilities *capabilities = [OCCapabilities new];
        
        if (jsongParsed.allKeys > 0) {
            
            NSDictionary *ocs = [jsongParsed valueForKey:@"ocs"];
            NSDictionary *data = [ocs valueForKey:@"data"];
            NSDictionary *version = [data valueForKey:@"version"];
            
            if (ocs.count > 0 && data.count > 0 && version.count > 0) {
            
                //VERSION
            
                NSNumber *versionMajorNumber = (NSNumber*) [version valueForKey:@"major"];
                NSNumber *versionMinorNumber = (NSNumber*) [version valueForKey:@"minor"];
                NSNumber *versionMicroNumber = (NSNumber*) [version valueForKey:@"micro"];
            
                capabilities.versionMajor = versionMajorNumber.integerValue;
                capabilities.versionMinor = versionMinorNumber.integerValue;
                capabilities.versionMicro = versionMicroNumber.integerValue;
            
                capabilities.versionString = (NSString*)[version valueForKey:@"string"];
                capabilities.versionEdition = (NSString*)[version valueForKey:@"edition"];
            
                NSDictionary *capabilitiesDict = [data valueForKey:@"capabilities"];
                NSDictionary *core = [capabilitiesDict valueForKey:@"core"];
            
                //CORE
            
                NSNumber *corePollIntervalNumber = (NSNumber*)[core valueForKey:@"pollinterval"];
                capabilities.corePollInterval = corePollIntervalNumber.integerValue;
            
                NSDictionary *fileSharing = [capabilitiesDict valueForKey:@"files_sharing"];
            
                //FILE SHARING
            
                NSNumber *fileSharingAPIEnabledNumber = (NSNumber*)[fileSharing valueForKey:@"api_enabled"];
                NSNumber *filesSharingReSharingEnabledNumber = (NSNumber*)[fileSharing valueForKey:@"resharing"];
            
                capabilities.isFilesSharingAPIEnabled = fileSharingAPIEnabledNumber.boolValue;
                capabilities.isFilesSharingReSharingEnabled = filesSharingReSharingEnabledNumber.boolValue;
            
                NSDictionary *fileSharingPublic = [fileSharing valueForKey:@"public"];
            
                NSNumber *filesSharingShareLinkEnabledNumber = (NSNumber*)[fileSharingPublic valueForKey:@"enabled"];
                NSNumber *filesSharingAllowPublicUploadsEnabledNumber = (NSNumber*)[fileSharingPublic valueForKey:@"upload"];
                NSNumber *filesSharingAllowUserSendMailNotificationAboutShareLinkEnabledNumber = (NSNumber*)[fileSharingPublic valueForKey:@"send_mail"];
            
                capabilities.isFilesSharingShareLinkEnabled = filesSharingShareLinkEnabledNumber.boolValue;
                capabilities.isFilesSharingAllowPublicUploadsEnabled = filesSharingAllowPublicUploadsEnabledNumber.boolValue;
                capabilities.isFilesSharingAllowUserSendMailNotificationAboutShareLinkEnabled = filesSharingAllowUserSendMailNotificationAboutShareLinkEnabledNumber.boolValue;
            
                NSDictionary *fileSharingPublicExpireDate = [fileSharingPublic valueForKey:@"expire_date"];
            
                NSNumber *filesSharingExpireDateByDefaultEnabledNumber = (NSNumber*)[fileSharingPublicExpireDate valueForKey:@"enabled"];
                NSNumber *filesSharingExpireDateEnforceEnabledNumber = (NSNumber*)[fileSharingPublicExpireDate valueForKey:@"enforced"];
                NSNumber *filesSharingExpireDateDaysNumber = (NSNumber*)[fileSharingPublicExpireDate valueForKey:@"days"];
            
    
                capabilities.isFilesSharingExpireDateByDefaultEnabled = filesSharingExpireDateByDefaultEnabledNumber.boolValue;
                capabilities.isFilesSharingExpireDateEnforceEnabled = filesSharingExpireDateEnforceEnabledNumber.boolValue;
                capabilities.filesSharingExpireDateDaysNumber = filesSharingExpireDateDaysNumber.integerValue;
            
                NSDictionary *fileSharingPublicPassword = [fileSharingPublic valueForKey:@"password"];
            
                NSNumber *filesSharingPasswordEnforcedEnabledNumber = (NSNumber*)[fileSharingPublicPassword valueForKey:@"enforced"];
            
                capabilities.isFilesSharingPasswordEnforcedEnabled = filesSharingPasswordEnforcedEnabledNumber.boolValue;;
            
                NSDictionary *fileSharingUser = [fileSharing valueForKey:@"user"];
            
                NSNumber *filesSharingAllowUserSendMailNotificationAboutOtherUsersEnabledNumber = (NSNumber*)[fileSharingUser valueForKey:@"send_mail"];
            
                capabilities.isFilesSharingAllowUserSendMailNotificationAboutOtherUsersEnabled = filesSharingAllowUserSendMailNotificationAboutOtherUsersEnabledNumber.boolValue;
            
                //FEDERATION
            
                NSDictionary *fileSharingFederation = [fileSharing valueForKey:@"federation"];
            
                NSNumber *filesSharingAllowUserSendSharesToOtherServersEnabledNumber = (NSNumber*)[fileSharingFederation valueForKey:@"outgoing"];
                NSNumber *filesSharingAllowUserReceiveSharesToOtherServersEnabledNumber = (NSNumber*)[fileSharingFederation valueForKey:@"incoming"];
            
                capabilities.isFilesSharingAllowUserSendSharesToOtherServersEnabled = filesSharingAllowUserSendSharesToOtherServersEnabledNumber.boolValue;
                capabilities.isFilesSharingAllowUserReceiveSharesToOtherServersEnabled = filesSharingAllowUserReceiveSharesToOtherServersEnabledNumber.boolValue;
            
                // EXTERNAL SITES
            
                NSDictionary *externalSitesDic = [capabilitiesDict valueForKey:@"external"];
                if (externalSitesDic) {
                    NSArray *externalSitesArray = [externalSitesDic valueForKey:@"v1"];
                    if (externalSitesArray)
                        if ([[externalSitesArray objectAtIndex:0] isEqualToString:@"sites"])
                            capabilities.isExternalSitesServerEnabled = YES;
                }
                
                //FILES
            
                NSDictionary *files = [capabilitiesDict valueForKey:@"files"];
            
                NSNumber *fileBigFileChunkingEnabledNumber = (NSNumber*)[files valueForKey:@"bigfilechunking"];
                NSNumber *fileUndeleteEnabledNumber = (NSNumber*)[files valueForKey:@"undelete"];
                NSNumber *fileVersioningEnabledNumber = (NSNumber*)[files valueForKey:@"versioning"];
            
                capabilities.isFileBigFileChunkingEnabled = fileBigFileChunkingEnabledNumber.boolValue;
                capabilities.isFileUndeleteEnabled = fileUndeleteEnabledNumber.boolValue;
                capabilities.isFileVersioningEnabled = fileVersioningEnabledNumber.boolValue;
            
                //THEMING
            
                NSDictionary *theming = [capabilitiesDict valueForKey:@"theming"];
            
                if ([theming count] > 0) {
                
                    if ([theming valueForKey:@"background"] && ![[theming valueForKey:@"background"] isEqual:[NSNull null]])
                        capabilities.themingBackground = [theming valueForKey:@"background"];
                
                    if ([theming valueForKey:@"color"] && ![[theming valueForKey:@"color"] isEqual:[NSNull null]])
                        capabilities.themingColor = [theming valueForKey:@"color"];
                
                    if ([theming valueForKey:@"logo"] && ![[theming valueForKey:@"logo"] isEqual:[NSNull null]])
                        capabilities.themingLogo = [theming valueForKey:@"logo"];
                
                    if ([theming valueForKey:@"name"] && ![[theming valueForKey:@"name"] isEqual:[NSNull null]])
                        capabilities.themingName = [theming valueForKey:@"name"];
                
                    if ([theming valueForKey:@"slogan"] && ![[theming valueForKey:@"slogan"] isEqual:[NSNull null]])
                        capabilities.themingSlogan = [theming valueForKey:@"slogan"];
                
                    if ([theming valueForKey:@"url"] && ![[theming valueForKey:@"url"] isEqual:[NSNull null]])
                        capabilities.themingUrl = [theming valueForKey:@"url"];
                }
            }
        
            successRequest(response, capabilities, request.redirectedServer);
            
        } else {
            
            failureRequest(response, error, request.redirectedServer);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}


#pragma mark - Remote thumbnails

- (NSURLSessionTask *) getRemoteThumbnailByServer:(NSString*)serverPath ofFilePath:(NSString *)filePath withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight onCommunication:(OCCommunication *)sharedOCComunication
                     successRequest:(void(^)(NSHTTPURLResponse *response, NSData *thumbnail, NSString *redirectedServer)) successRequest
                     failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_thumbnails];
    filePath = [filePath encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    
    OCHTTPRequestOperation *operation = [request getRemoteThumbnailByServer:serverPath ofFilePath:filePath withWidth:fileWidth andHeight:fileHeight onCommunication:sharedOCComunication
            success:^(NSHTTPURLResponse *response, id responseObject) {
                NSData *responseData = (NSData*) responseObject;
                
                successRequest(response, responseData, request.redirectedServer);
                                    
            } failure:^(NSHTTPURLResponse *response, id  _Nullable responseObject, NSError * _Nonnull error) {
                failureRequest(response, error, request.redirectedServer);
            }];
    
    [operation resume];

    return operation;
}

#pragma mark - Notification Server

- (void)getNotificationServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_remote_notification_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request getNotificationServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"[LOG] Notifications : %@",jsongParsed);
        
        NSMutableArray *listOfNotifications = [NSMutableArray new];

        if (jsongParsed.allKeys > 0) {
        
            NSDictionary *ocs = [jsongParsed valueForKey:@"ocs"];
            NSDictionary *meta = [ocs valueForKey:@"meta"];
            NSDictionary *datas = [ocs valueForKey:@"data"];
        
            NSInteger statusCode = [[meta valueForKey:@"statuscode"] integerValue];
                        
            if (statusCode == kOCNotificationAPINoContent || statusCode == kOCNotificationAPISuccessful) {
                
                for (NSDictionary *data in datas) {
                
                    OCNotifications *notification = [OCNotifications new];
                    
                    if ([data valueForKey:@"notification_id"] && ![[data valueForKey:@"notification_id"] isEqual:[NSNull null]])
                        notification.idNotification = [[data valueForKey:@"notification_id"] integerValue];
                    
                    if ([data valueForKey:@"app"] && ![[data valueForKey:@"app"] isEqual:[NSNull null]])
                        notification.application = [data valueForKey:@"app"];
                    
                    if ([data valueForKey:@"user"] && ![[data valueForKey:@"user"] isEqual:[NSNull null]])
                        notification.user = [data valueForKey:@"user"];
                    
                    if ([data valueForKey:@"datetime"] && ![[data valueForKey:@"datetime"] isEqual:[NSNull null]]) {
                        
                        NSString *dateString = [data valueForKey:@"datetime"];
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                        [dateFormatter setLocale:enUSPOSIXLocale];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                        
                        notification.date = [dateFormatter dateFromString:dateString];
                    }
                    
                    if ([data valueForKey:@"object_type"] && ![[data valueForKey:@"object_type"] isEqual:[NSNull null]])
                        notification.typeObject = [data valueForKey:@"object_type"];
                    
                    if ([data valueForKey:@"object_id"] && ![[data valueForKey:@"object_id"] isEqual:[NSNull null]])
                        notification.idObject = [data valueForKey:@"object_id"];
                    
                    if ([data valueForKey:@"subject"] && ![[data valueForKey:@"subject"] isEqual:[NSNull null]])
                        notification.subject = [data valueForKey:@"subject"];
                    
                    if ([data valueForKey:@"subjectRich"] && ![[data valueForKey:@"subjectRich"] isEqual:[NSNull null]])
                        notification.subjectRich = [data valueForKey:@"subjectRich"];
                    
                    if ([data valueForKey:@"subjectRichParameters"] && ![[data valueForKey:@"subjectRichParameters"] isEqual:[NSNull null]])
                        notification.subjectRichParameters = [data valueForKey:@"subjectRichParameters"];
                    
                    if ([data valueForKey:@"message"] && ![[data valueForKey:@"message"] isEqual:[NSNull null]])
                        notification.message = [data valueForKey:@"message"];
                    
                    if ([data valueForKey:@"messageRich"] && ![[data valueForKey:@"messageRich"] isEqual:[NSNull null]])
                        notification.messageRich = [data valueForKey:@"messageRich"];
                    
                    if ([data valueForKey:@"messageRichParameters"] && ![[data valueForKey:@"messageRichParameters"] isEqual:[NSNull null]])
                        notification.messageRichParameters = [data valueForKey:@"messageRichParameters"];
                    
                    if ([data valueForKey:@"link"] && ![[data valueForKey:@"link"] isEqual:[NSNull null]])
                        notification.link = [data valueForKey:@"link"];
                    
                    if ([data valueForKey:@"icon"] && ![[data valueForKey:@"icon"] isEqual:[NSNull null]])
                        notification.icon = [data valueForKey:@"icon"];
                    
                    /* ACTION */
                    
                    NSMutableArray *actionsArr = [NSMutableArray new];
                    NSDictionary *actions = [data valueForKey:@"actions"];
                    
                    for (NSDictionary *action in actions) {
                        
                        OCNotificationsAction *notificationAction = [OCNotificationsAction new];
                        
                        if ([action valueForKey:@"label"] && ![[action valueForKey:@"label"] isEqual:[NSNull null]])
                            notificationAction.label = [action valueForKey:@"label"];
                        
                        if ([action valueForKey:@"link"] && ![[action valueForKey:@"link"] isEqual:[NSNull null]])
                            notificationAction.link = [action valueForKey:@"link"];
                        
                        if ([action valueForKey:@"primary"] && ![[action valueForKey:@"primary"] isEqual:[NSNull null]])
                            notificationAction.primary = [[action valueForKey:@"primary"] boolValue];
                        
                        if ([action valueForKey:@"type"] && ![[action valueForKey:@"type"] isEqual:[NSNull null]])
                            notificationAction.type = [action valueForKey:@"type"];

                        [actionsArr addObject:notificationAction];
                    }
                    
                    notification.actions = [[NSArray alloc] initWithArray:actionsArr];
                    [listOfNotifications addObject:notification];
                }
                
            } else {
                
                NSString *message = (NSString*)[meta objectForKey:@"message"];
                
                if ([message isKindOfClass:[NSNull class]]) {
                    message = @"";
                }
                
                NSError *error = [UtilsFramework getErrorWithCode:statusCode andCustomMessageFromTheServer:message];
                failureRequest(response, error, request.redirectedServer);
            }
        }
    
        //Return success
        successRequest(response, listOfNotifications, request.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void)setNotificationServer:(NSString*)serverPath type:(NSString *)type onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void (^)(NSHTTPURLResponse *, NSString *))successRequest failureRequest:(void (^)(NSHTTPURLResponse *, NSError *, NSString *))failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    __weak OCWebDAVClient *wrequest = request;
    
    [request setNotificationServer:serverPath type:type onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        successRequest(response, wrequest.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        
        failureRequest(response, error, wrequest.redirectedServer);
    }];
}

- (void)subscribingNextcloudServerPush:(NSString *)serverPath pushTokenHash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey proxyServerPath:(NSString *)proxyServerPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer)) successRequest failureRequest:(void (^)(NSHTTPURLResponse *, NSError *, NSString *))failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_remote_subscribing_nextcloud_server_api];

    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request subscribingNextcloudServerPush:serverPath authorizationToken:_password pushTokenHash:pushTokenHash devicePublicKey:devicePublicKey proxyServerPath:proxyServerPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"[LOG] Subscribing at the Nextcloud server : %@",jsongParsed);
        
        NSString *publicKey = [jsongParsed objectForKey:@"publicKey"];
        NSString *deviceIdentifier = [jsongParsed objectForKey:@"deviceIdentifier"];
        NSString *signature = [jsongParsed objectForKey:@"signature"];
        
        successRequest(response, publicKey, deviceIdentifier, signature, request.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
                
        failureRequest(response, error, request.redirectedServer);
    }];
}

- (void)subscribingPushProxy:(NSString *)serverPath pushToken:(NSString *)pushToken deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature userPublicKey:(NSString *)userPublicKey onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void (^)(NSHTTPURLResponse *, NSString *redirectedServer))successRequest failureRequest:(void (^)(NSHTTPURLResponse *, NSError *, NSString *))failureRequest {
    
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:@"/devices"];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request subscribingPushProxy:serverPath authorizationToken:_password pushToken:pushToken deviceIdentifier:deviceIdentifier deviceIdentifierSignature:deviceIdentifierSignature userPublicKey:userPublicKey onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        if (successRequest) {
            //Return success
            successRequest(response, request.redirectedServer);
        }
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        
        failureRequest(response, error, request.redirectedServer);
    }];
}

#pragma mark - Activity

- (void) getActivityServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfActivity, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {

    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_remote_activity_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request getActivityServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"[LOG] Activity : %@",jsongParsed);
        
        NSMutableArray *listOfActivity = [NSMutableArray new];
        
        if (jsongParsed.allKeys > 0) {
            
            NSDictionary *ocs = [jsongParsed valueForKey:@"ocs"];
            NSDictionary *meta = [ocs valueForKey:@"meta"];
            NSDictionary *datas = [ocs valueForKey:@"data"];
            
            NSInteger statusCode = [[meta valueForKey:@"statuscode"] integerValue];

            if (statusCode == kOCNotificationAPINoContent || statusCode == kOCNotificationAPISuccessful) {
                
                for (NSDictionary *data in datas) {
                    
                    OCActivity *activity = [OCActivity new];
                    
                    if ([data valueForKey:@"id"] && ![[data valueForKey:@"id"] isEqual:[NSNull null]])
                        activity.idActivity = [[data valueForKey:@"id"] integerValue];
                    
                    if ([data valueForKey:@"date"] && ![[data valueForKey:@"date"] isEqual:[NSNull null]]) {
                        
                        NSString *dateString = [data valueForKey:@"date"];
                        
                        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
                        [dateFormatter setLocale:enUSPOSIXLocale];
                        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
                        
                        activity.date = [dateFormatter dateFromString:dateString];
                    }
                    
                    if ([data valueForKey:@"file"] && ![[data valueForKey:@"file"] isEqual:[NSNull null]])
                        activity.file = [data valueForKey:@"file"];
                    
                    if ([data valueForKey:@"link"] && ![[data valueForKey:@"link"] isEqual:[NSNull null]])
                        activity.link = [data valueForKey:@"link"];
                    
                    if ([data valueForKey:@"message"] && ![[data valueForKey:@"message"] isEqual:[NSNull null]])
                        activity.message = [data valueForKey:@"message"];
                    
                    if ([data valueForKey:@"subject"] && ![[data valueForKey:@"subject"] isEqual:[NSNull null]])
                        activity.subject = [data valueForKey:@"subject"];
                    
                    [listOfActivity addObject:activity];
                }
                
            } else {
                
                NSString *message = (NSString*)[meta objectForKey:@"message"];
                
                if ([message isKindOfClass:[NSNull class]]) {
                    message = @"";
                }
                
                NSError *error = [UtilsFramework getErrorWithCode:statusCode andCustomMessageFromTheServer:message];
                failureRequest(response, error, request.redirectedServer);
            }
        }

        //Return success
        successRequest(response, listOfActivity, request.redirectedServer);

    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}


#pragma mark - External sites

- (void) getExternalSitesServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];
    serverPath = [serverPath stringByAppendingString:k_url_acces_external_sites_api];
    
    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request getExternalSitesServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
        
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"[LOG] External Sites : %@",jsongParsed);
        
        NSMutableArray *listOfExternalSites = [NSMutableArray new];
        
        if (jsongParsed.allKeys > 0) {
            
            NSDictionary *ocs = [jsongParsed valueForKey:@"ocs"];
            NSDictionary *meta = [ocs valueForKey:@"meta"];
            NSDictionary *datas = [ocs valueForKey:@"data"];
            
            NSInteger statusCode = [[meta valueForKey:@"statuscode"] integerValue];
            
            if (statusCode == kOCNotificationAPINoContent || statusCode == kOCNotificationAPISuccessful) {
                
                for (NSDictionary *data in datas) {
                    
                    OCExternalSites *externalSites = [OCExternalSites new];
                    
                    externalSites.idExternalSite = [[data valueForKey:@"id"] integerValue];
    
                    if ([data valueForKey:@"icon"] && ![[data valueForKey:@"icon"] isEqual:[NSNull null]])
                        externalSites.icon = [data valueForKey:@"icon"];
                    
                    if ([data valueForKey:@"lang"] && ![[data valueForKey:@"lang"] isEqual:[NSNull null]])
                        externalSites.lang = [data valueForKey:@"lang"];
                    
                    if ([data valueForKey:@"name"] && ![[data valueForKey:@"name"] isEqual:[NSNull null]])
                        externalSites.name = [data valueForKey:@"name"];
                    
                    if ([data valueForKey:@"url"]  && ![[data valueForKey:@"url"]  isEqual:[NSNull null]])
                        externalSites.url  = [data valueForKey:@"url"];
                    
                    if ([data valueForKey:@"type"] && ![[data valueForKey:@"type"] isEqual:[NSNull null]])
                        externalSites.type = [data valueForKey:@"type"];
                    
                    [listOfExternalSites addObject:externalSites];
                }
                
            } else {
                
                NSString *message = (NSString*)[meta objectForKey:@"message"];
                
                if ([message isKindOfClass:[NSNull class]]) {
                    message = @"";
                }
                
                NSError *error = [UtilsFramework getErrorWithCode:statusCode andCustomMessageFromTheServer:message];
                failureRequest(response, error, request.redirectedServer);
            }
        }
        
        //Return success
        successRequest(response, listOfExternalSites, request.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
        failureRequest(response, error, request.redirectedServer);
    }];
}



#pragma mark - User Profile

- (void) getUserProfileServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest {
    
    serverPath = [serverPath stringByAppendingString:k_url_acces_remote_userprofile_api];
    serverPath = [serverPath stringByAppendingString:self.user];
    serverPath = [serverPath encodeString:NSUTF8StringEncoding];

    OCWebDAVClient *request = [OCWebDAVClient new];
    request = [self getRequestWithCredentials:request];
    
    [request getUserProfileServer:serverPath onCommunication:sharedOCComunication success:^(NSHTTPURLResponse *response, id responseObject) {
    
        NSData *responseData = (NSData*) responseObject;
        
        //Parse
        NSError *error;
        NSDictionary *jsongParsed = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"[LOG] User Profile : %@",jsongParsed);
        
        OCUserProfile *userProfile = [OCUserProfile new];
        
        if (jsongParsed.allKeys > 0) {

            NSDictionary *ocs = [jsongParsed valueForKey:@"ocs"];
            NSDictionary *meta = [ocs valueForKey:@"meta"];
            NSDictionary *data = [ocs valueForKey:@"data"];
            
            NSInteger statusCode = [[meta valueForKey:@"statuscode"] integerValue];
            
            if (statusCode == kOCUserProfileAPISuccessful) {
                
                if ([data valueForKey:@"address"] && ![[data valueForKey:@"address"] isKindOfClass:[NSNull class]])
                    userProfile.address = [data valueForKey:@"address"];
                
                if ([data valueForKey:@"displayname"] && ![[data valueForKey:@"displayname"] isKindOfClass:[NSNull class]])
                    userProfile.displayName = [data valueForKey:@"displayname"];
              
                if ([data valueForKey:@"email"] && ![[data valueForKey:@"email"] isKindOfClass:[NSNull class]])
                    userProfile.email = [data valueForKey:@"email"];
                
                if ([data valueForKey:@"enabled"] && ![[data valueForKey:@"enabled"] isKindOfClass:[NSNull class]])
                    userProfile.enabled = [[data valueForKey:@"enabled"] boolValue];
                
                if ([data valueForKey:@"id"] && ![[data valueForKey:@"id"] isKindOfClass:[NSNull class]])
                    userProfile.id = [data valueForKey:@"id"];
                
                if ([data valueForKey:@"phone"] && ![[data valueForKey:@"phone"] isKindOfClass:[NSNull class]])
                    userProfile.phone = [data valueForKey:@"phone"];
                
                if ([data valueForKey:@"twitter"] && ![[data valueForKey:@"twitter"] isKindOfClass:[NSNull class]])
                    userProfile.twitter = [data valueForKey:@"twitter"];
                
                if ([data valueForKey:@"webpage"] && ![[data valueForKey:@"webpage"] isKindOfClass:[NSNull class]])
                    userProfile.webpage = [data valueForKey:@"webpage"];

                /* QUOTA */
                    
                NSDictionary *quota = [data valueForKey:@"quota"];
                
                if ([quota count] > 0) {
                    
                    if ([quota valueForKey:@"free"] && ![[quota valueForKey:@"free"] isKindOfClass:[NSNull class]])
                        userProfile.quotaFree = [[quota valueForKey:@"free"] doubleValue];
                    
                    if ([quota valueForKey:@"quota"] && ![[quota valueForKey:@"quota"] isKindOfClass:[NSNull class]])
                        userProfile.quota = [[quota valueForKey:@"quota"] doubleValue];

                    if ([quota valueForKey:@"relative"] && ![[quota valueForKey:@"relative"] isKindOfClass:[NSNull class]])
                        userProfile.quotaRelative = [[quota valueForKey:@"relative"] doubleValue];
                        
                    if ([quota valueForKey:@"total"] && ![[quota valueForKey:@"total"] isKindOfClass:[NSNull class]])
                        userProfile.quotaTotal = [[quota valueForKey:@"total"] doubleValue];
                        
                    if ([quota valueForKey:@"used"] && ![[quota valueForKey:@"used"] isKindOfClass:[NSNull class]])
                        userProfile.quotaUsed = [[quota valueForKey:@"used"] doubleValue];
                }
                
            } else {
                
                NSString *message = (NSString*)[meta objectForKey:@"message"];
                
                if ([message isKindOfClass:[NSNull class]]) {
                    message = @"";
                }
                
                NSError *error = [UtilsFramework getErrorWithCode:statusCode andCustomMessageFromTheServer:message];
                failureRequest(response, error, request.redirectedServer);
            }
        }
        
        //Return success
        successRequest(response, userProfile, request.redirectedServer);
        
    } failure:^(NSHTTPURLResponse *response, NSData *responseData, NSError *error) {
    
        failureRequest(response, error, request.redirectedServer);
    }];
}

#pragma mark - Clear Cache

- (void)eraseURLCache
{
    [[NSURLCache sharedURLCache] setMemoryCapacity:0];
    [[NSURLCache sharedURLCache] setDiskCapacity:0];
}


#pragma mark - Utils

- (void) addUserItemOfType:(NSInteger) shareeType fromArray:(NSArray*) usersArray ToList: (NSMutableArray *) itemList
{

    for (NSDictionary *userFound in usersArray) {
        OCShareUser *user = [OCShareUser new];
        
        if ([[userFound valueForKey:@"label"] isKindOfClass:[NSNumber class]]) {
            NSNumber *number = [userFound valueForKey:@"label"];
            user.displayName = [NSString stringWithFormat:@"%ld", number.longValue];
        }else{
            user.displayName = [userFound valueForKey:@"label"];
        }
        
        NSDictionary *userValues = [userFound valueForKey:@"value"];
        
        if ([[userValues valueForKey:@"shareWith"] isKindOfClass:[NSNumber class]]) {
            NSNumber *number = [userValues valueForKey:@"shareWith"];
            user.name = [NSString stringWithFormat:@"%ld", number.longValue];
        }else{
            user.name = [userValues valueForKey:@"shareWith"];
        }
        user.shareeType = shareeType;
        user.server = [userValues valueForKey:@"server"];
        
        [itemList addObject:user];
    }
}

- (void) addGroupItemFromArray:(NSArray*) groupsArray ToList: (NSMutableArray *) itemList
{
    for (NSDictionary *groupFound in groupsArray) {
        
        OCShareUser *group = [OCShareUser new];
        
        NSDictionary *groupValues = [groupFound valueForKey:@"value"];
        if ([[groupValues valueForKey:@"shareWith"] isKindOfClass:[NSNumber class]]) {
            NSNumber *number = [groupValues valueForKey:@"shareWith"];
            group.name = [NSString stringWithFormat:@"%ld", number.longValue];
        }else{
            group.name = [groupValues valueForKey:@"shareWith"];
        }
        group.shareeType = shareTypeGroup;
        
        [itemList addObject:group];
        
    }
}

@end

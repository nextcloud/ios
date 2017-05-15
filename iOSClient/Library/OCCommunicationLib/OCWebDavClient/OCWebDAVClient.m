
//
//  OCWebDAVClient.m
//  OCWebDAVClient
//
//  This class is based in https://github.com/zwaldowski/DZWebDAVClient. Copyright (c) 2012 Zachary Waldowski, Troy Brant, Marcus Rohrmoser, and Sam Soffes.
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
//  Add : getNotificationServer & setNotificationServer
//  Add : getUserProfileServer
//  Add : Support for Favorite
//  Add : getActivityServer
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//  Copyright (c) 2017 TWS. All rights reserved.
//

#import "OCWebDAVClient.h"
#import "OCFrameworkConstants.h"
#import "OCCommunication.h"
#import "UtilsFramework.h"
#import "AFURLSessionManager.h"
#import "NSString+Encode.h"
#import "OCConstants.h"

#define k_api_user_url_xml @"index.php/ocs/cloud/user"
#define k_api_user_url_json @"index.php/ocs/cloud/user?format=json"
#define k_server_information_json @"status.php"
#define k_api_header_request @"OCS-APIREQUEST"
#define k_group_sharee_type 1


NSString const *OCWebDAVContentTypeKey		= @"getcontenttype";
NSString const *OCWebDAVETagKey				= @"getetag";
NSString const *OCWebDAVCTagKey				= @"getctag";
NSString const *OCWebDAVCreationDateKey		= @"creationdate";
NSString const *OCWebDAVModificationDateKey	= @"modificationdate";

@interface OCWebDAVClient()

- (void)mr_listPath:(NSString *)path depth:(NSUInteger)depth onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *, id))success
            failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure;

@end

@implementation OCWebDAVClient

- (id) init {
    
    self = [super init];
    
    if (self != nil) {
        self.defaultHeaders = [NSMutableDictionary new];
    }
    
    return self;
}

- (void)setAuthorizationHeaderWithUsername:(NSString *)username password:(NSString *)password {
	NSString *basicAuthCredentials = [NSString stringWithFormat:@"%@:%@", username, password];

    [self.defaultHeaders setObject:[NSString stringWithFormat:@"Basic %@", [UtilsFramework AFBase64EncodedStringFromString: basicAuthCredentials]] forKey:@"Authorization"];
}

- (void)setAuthorizationHeaderWithCookie:(NSString *) cookieString {
    [self.defaultHeaders setObject:cookieString forKey:@"Cookie"];
}

- (void)setAuthorizationHeaderWithToken:(NSString *)token {
    [self.defaultHeaders setObject:token forKey:@"Authorization"];
}

- (void)setDefaultHeader:(NSString *)header value:(NSString *)value {
    [self.defaultHeaders setObject:value forKey:header];
}

- (void)setUserAgent:(NSString *)userAgent{
    [self.defaultHeaders setObject:userAgent forKey:@"User-Agent"];
}

- (OCHTTPRequestOperation *)mr_operationWithRequest:(NSMutableURLRequest *)request onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString*)token success:(void(^)(NSHTTPURLResponse *operation, id response, NSString *token))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error, NSString *token))failure {
    
    //If is not nil is a redirection so we keep the original url server
    if (!self.originalUrlServer) {
        self.originalUrlServer = [request.URL absoluteString];
    }
    
    if (sharedOCCommunication.isCookiesAvailable) {
        //We add the cookies of that URL
        request = [UtilsFramework getRequestWithCookiesByRequest:request andOriginalUrlServer:self.originalUrlServer];
    } else {
        [UtilsFramework deleteAllCookies];
    }
    
    OCHTTPRequestOperation *operation = (OCHTTPRequestOperation*) [sharedOCCommunication.networkSessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
        if (!error) {
            success((NSHTTPURLResponse*)response,responseObject, token);
        } else {
            failure((NSHTTPURLResponse*)response, responseObject, error, token);
        }
    }];
    
    return operation;
}

- (OCHTTPRequestOperation *)mr_operationWithRequest:(NSMutableURLRequest *)request onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    //If is not nil is a redirection so we keep the original url server
    if (!self.originalUrlServer) {
        self.originalUrlServer = [request.URL absoluteString];
    }
    
    if (sharedOCCommunication.isCookiesAvailable) {
        //We add the cookies of that URL
        request = [UtilsFramework getRequestWithCookiesByRequest:request andOriginalUrlServer:self.originalUrlServer];
    } else {
        [UtilsFramework deleteAllCookies];
    }
    
    OCHTTPRequestOperation *operation = (OCHTTPRequestOperation*) [sharedOCCommunication.networkSessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
         if (!error) {
            success((NSHTTPURLResponse*)response,responseObject);
        } else {
            failure((NSHTTPURLResponse*)response, responseObject, error);
        }
    }];
    
    return operation;
    
}

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer new] requestWithMethod:method URLString:path parameters:nil error:nil];
    [request setAllHTTPHeaderFields:self.defaultHeaders];
    
    [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
    [request setTimeoutInterval: k_timeout_webdav];
    
    return request;
}

- (NSMutableURLRequest *)sharedRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters {
    
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer new] requestWithMethod:method URLString:path parameters:nil error:nil];
    
    [request setAllHTTPHeaderFields:self.defaultHeaders];
    
    //NSMutableURLRequest *request = [super requestWithMethod:method path:path parameters:parameters];
    [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
    [request setTimeoutInterval: k_timeout_webdav];
    //Header for use the OC API CALL
    NSString *ocs_apiquests = @"true";
    [request setValue:ocs_apiquests forHTTPHeaderField:k_api_header_request];
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    [request addValue:@"gzip, deflate" forHTTPHeaderField:@"Accept-Encoding"];
    
    return request;
}


- (void)movePath:(NSString *)source toPath:(NSString *)destination
 onCommunication:(OCCommunication *)sharedOCCommunication
         success:(void(^)(NSHTTPURLResponse *, id))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    _requestMethod = @"MOVE";
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:source parameters:nil];
    [request setValue:destination forHTTPHeaderField:@"Destination"];
	[request setValue:@"T" forHTTPHeaderField:@"Overwrite"];
	OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)deletePath:(NSString *)path
   onCommunication:(OCCommunication *)sharedOCCommunication
           success:(void(^)(NSHTTPURLResponse *, id))success
           failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    _requestMethod = @"DELETE";
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
	OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}


- (void)mr_listPath:(NSString *)path depth:(NSUInteger)depth onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *, id))success
            failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";
	NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
	NSString *depthHeader = nil;
	if (depth <= 0)
		depthHeader = @"0";
	else if (depth == 1)
		depthHeader = @"1";
	else
		depthHeader = @"infinity";
    [request setValue: depthHeader forHTTPHeaderField: @"Depth"];
    
    [request setHTTPBody:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><D:propfind xmlns:D=\"DAV:\"><D:prop><D:resourcetype/><D:getlastmodified/><size xmlns=\"http://owncloud.org/ns\"/><favorite xmlns=\"http://owncloud.org/ns\"/><D:creationdate/><id xmlns=\"http://owncloud.org/ns\"/><D:getcontentlength/><D:displayname/><D:quota-available-bytes/><D:getetag/><permissions xmlns=\"http://owncloud.org/ns\"/><D:quota-used-bytes/><D:getcontenttype/></D:prop></D:propfind>" dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)mr_listPath:(NSString *)path depth:(NSUInteger)depth withUserSessionToken:(NSString*)token onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *operation, id response, NSString *token))success
            failure:(void(^)(NSHTTPURLResponse *response, id  _Nullable responseObject, NSError *, NSString *token))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    NSString *depthHeader = nil;
    if (depth <= 0)
        depthHeader = @"0";
    else if (depth == 1)
        depthHeader = @"1";
    else
        depthHeader = @"infinity";
    [request setValue: depthHeader forHTTPHeaderField: @"Depth"];
    
    [request setHTTPBody:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><D:propfind xmlns:D=\"DAV:\"><D:prop><D:resourcetype/><D:getlastmodified/><size xmlns=\"http://owncloud.org/ns\"/><favorite xmlns=\"http://owncloud.org/ns\"/><D:creationdate/><id xmlns=\"http://owncloud.org/ns\"/><D:getcontentlength/><D:displayname/><D:quota-available-bytes/><D:getetag/><permissions xmlns=\"http://owncloud.org/ns\"/><D:quota-used-bytes/><D:getcontenttype/></D:prop></D:propfind>" dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)propertiesOfPath:(NSString *)path
         onCommunication: (OCCommunication *)sharedOCCommunication
                 success:(void(^)(NSHTTPURLResponse *, id ))success
                 failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	[self mr_listPath:path depth:0 onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)listPath:(NSString *)path
 onCommunication:(OCCommunication *)sharedOCCommunication
         success:(void(^)(NSHTTPURLResponse *, id))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	[self mr_listPath:path depth:1 onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)listPath:(NSString *)path
 onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token
         success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    [self mr_listPath:path depth:1 withUserSessionToken:token onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)search:(NSString *)path folder:(NSString *)folder fileName:(NSString *)fileName depth:(NSString *)depth user:(NSString *)user onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSString *body;
    
    NSParameterAssert(success);
    
    _requestMethod = @"SEARCH";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    
    body = @"<?xml version=\"1.0\"?><d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\"><d:basicsearch><d:select><d:prop>";
    
    
    // OCFileDto
    body = [body stringByAppendingString:@"<d:resourcetype/><oc:fileid/><d:getcontenttype/><d:getetag/><d:creationdate/><oc:size/><d:getcontentlength/><d:getlastmodified/><oc:id/><oc:permissions/><d:quota-available-bytes/><d:quota-used-bytes/><oc:favorite/>"];
    
    
    body = [NSString stringWithFormat:@"%@</d:prop></d:select><d:from><d:scope><d:href>/files/%@%@</d:href><d:depth>infinity</d:depth></d:scope></d:from><d:where><d:like><d:prop><d:displayname/></d:prop><d:literal>%%%@%%</d:literal></d:like></d:where><d:orderby/></d:basicsearch></d:searchrequest>", body, user, folder, fileName];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)settingFavorite:(NSString * _Nonnull)path favorite:(BOOL)favorite onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"PROPPATCH";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    
    NSString *body = [NSString stringWithFormat:@"<?xml version=\"1.0\"?><d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\"><d:set><d:prop><oc:favorite>%i</oc:favorite></d:prop></d:set></d:propertyupdate>", (favorite ? 1 : 0)];
                      
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)listingFavorites:(NSString *)path folder:(NSString *)folder user:(NSString *)user onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSString *body;
    
    NSParameterAssert(success);
    
    _requestMethod = @"REPORT";
    
    //REPORT remote.php/dav/files/user/path/to/folder

    path = [NSString stringWithFormat:@"%@/files/%@%@", path, user, folder];
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    
    body = @"<?xml version=\"1.0\"?><oc:filter-files xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><oc:filter-rules><oc:favorite>1</oc:favorite></oc:filter-rules><d:prop>"; //<oc:id/></d:prop></oc:filter-files>";
    
    // OCFileDto
    body = [body stringByAppendingString:@"<d:resourcetype/><oc:fileid/><d:getcontenttype/><d:getetag/><d:creationdate/><oc:size/><d:getcontentlength/><d:getlastmodified/><oc:id/><oc:permissions/><d:quota-available-bytes/><d:quota-used-bytes/><oc:favorite/>"];
    
    body = [NSString stringWithFormat:@"%@</d:prop></oc:filter-files>", body];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (NSURLSessionDownloadTask *)downloadWithSessionPath:(NSString *)remoteSource toPath:(NSString *)localDestination defaultPriority:(BOOL)defaultPriority onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))downloadProgress success:(void(^)(NSURLResponse *response, NSURL *filePath))success failure:(void(^)(NSURLResponse *response, NSError *error))failure{
    
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" path:remoteSource parameters:nil];
    
    //If is not nil is a redirection so we keep the original url server
    if (!self.originalUrlServer) {
        self.originalUrlServer = [request.URL absoluteString];
    }
    
    //We add the cookies of that URL
    request = [UtilsFramework getRequestWithCookiesByRequest:request andOriginalUrlServer:self.originalUrlServer];
    
    NSURL *localDestinationUrl = [NSURL fileURLWithPath:localDestination];
    
    NSURLSessionDownloadTask *downloadTask = [sharedOCCommunication.downloadSessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull progress) {
        downloadProgress(progress);
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        return localDestinationUrl;
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        if (error) {
            failure(response, error);
        } else {
            success(response,filePath);
        }
    }];
    
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.downloadSessionManager];
    
    
    if (defaultPriority) {
         [downloadTask resume];
    }
    
    return downloadTask;


}

- (void)checkServer:(NSString *)path onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *, id))success
            failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    _requestMethod = @"HEAD";
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    request.HTTPShouldHandleCookies = false;
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)makeCollection:(NSString *)path onCommunication:
(OCCommunication *)sharedOCCommunication
               success:(void(^)(NSHTTPURLResponse *, id))success
               failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    _requestMethod = @"MKCOL";
	NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil];
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (NSURLSessionUploadTask *)putWithSessionLocalPath:(NSString *)localSource atRemotePath:(NSString *)remoteDestination onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))uploadProgress success:(void(^)(NSURLResponse *, NSString *))success failure:(void(^)(NSURLResponse *, id, NSError *))failure failureBeforeRequest:(void(^)(NSError *)) failureBeforeRequest {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if (localSource == nil || ![fileManager fileExistsAtPath:localSource]) {
        NSMutableDictionary* details = [NSMutableDictionary dictionary];
        [details setValue:@"You are trying upload a file that does not exist" forKey:NSLocalizedDescriptionKey];
        
        NSError *error = [NSError errorWithDomain:k_domain_error_code code:OCErrorFileToUploadDoesNotExist userInfo:details];
        
        failureBeforeRequest(error);
        
        return nil;
    } else {
    
        NSMutableURLRequest *request = [self requestWithMethod:@"PUT" path:remoteDestination parameters:nil];
        [request setTimeoutInterval:k_timeout_upload];
        [request setValue:[NSString stringWithFormat:@"%lld", [UtilsFramework getSizeInBytesByPath:localSource]] forHTTPHeaderField:@"Content-Length"];
        [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        
        //If is not nil is a redirection so we keep the original url server
        if (!self.originalUrlServer) {
            self.originalUrlServer = [request.URL absoluteString];
        }
        
        if (sharedOCCommunication.isCookiesAvailable) {
            //We add the cookies of that URL
            request = [UtilsFramework getRequestWithCookiesByRequest:request andOriginalUrlServer:self.originalUrlServer];
        } else {
            [UtilsFramework deleteAllCookies];
        }
        
        NSURL *file = [NSURL fileURLWithPath:localSource];
        
        sharedOCCommunication.uploadSessionManager.responseSerializer = [AFHTTPResponseSerializer serializer];
        
        NSURLSessionUploadTask *uploadTask = [sharedOCCommunication.uploadSessionManager uploadTaskWithRequest:request fromFile:file progress:^(NSProgress * _Nonnull progress) {
            uploadProgress(progress);
        } completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
                if (error) {
                    failure(response, responseObject, error);
                } else {
                    success(response,responseObject);
                }
        }];
        
        [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.uploadSessionManager];
        [uploadTask resume];
        return uploadTask;
    }
}

- (void) requestUserNameOfServer:(NSString * _Nonnull) path byCookie:(NSString * _Nonnull) cookieString onCommunication:
(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure {
    
    NSString *apiUserUrl = nil;
    apiUserUrl = [NSString stringWithFormat:@"%@%@", path, k_api_user_url_json];
    
    NSLog(@"api user name call: %@", apiUserUrl);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path: apiUserUrl parameters: nil];
	[request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) getStatusOfTheServer:(NSString *)serverPath onCommunication:
(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id responseObject))success
                      failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure  {
    
    NSString *urlString = [NSString stringWithFormat:@"%@%@", serverPath, k_server_information_json];
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path: urlString parameters: nil];
    
    request.HTTPShouldHandleCookies = false;
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)listSharedByServer:(NSString *)serverPath
 onCommunication:(OCCommunication *)sharedOCCommunication
         success:(void(^)(NSHTTPURLResponse *, id))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)listSharedByServer:(NSString *)serverPath andPath:(NSString *) path
           onCommunication:(OCCommunication *)sharedOCCommunication
                   success:(void(^)(NSHTTPURLResponse *, id))success
                   failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
	
    NSString *postString = [NSString stringWithFormat: @"?path=%@&subfiles=true",path];
    serverPath = [serverPath stringByAppendingString:postString];
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)shareByLinkFileOrFolderByServer:(NSString *)serverPath andPath:(NSString *) filePath andPassword:(NSString *)password
                        onCommunication:(OCCommunication *)sharedOCCommunication
                                success:(void(^)(NSHTTPURLResponse *, id))success
                                failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    _postStringForShare = [NSString stringWithFormat: @"path=%@&shareType=3&password=%@",filePath,password];
    [request setHTTPBody:[_postStringForShare dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)shareByLinkFileOrFolderByServer:(NSString *)serverPath andPath:(NSString *) filePath
                  onCommunication:(OCCommunication *)sharedOCCommunication
                          success:(void(^)(NSHTTPURLResponse *, id))success
                          failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    _postStringForShare = [NSString stringWithFormat: @"path=%@&shareType=3",filePath];
    [request setHTTPBody:[_postStringForShare dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)shareWith:(NSString *)userOrGroup shareeType:(NSInteger)shareeType inServer:(NSString *) serverPath andPath:(NSString *) filePath andPermissions:(NSInteger) permissions onCommunication:(OCCommunication *)sharedOCCommunication
                                success:(void(^)(NSHTTPURLResponse *, id))success
                                failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    self.postStringForShare = [NSString stringWithFormat: @"path=%@&shareType=%ld&shareWith=%@&permissions=%ld",filePath, (long)shareeType, userOrGroup, (long)permissions];
    [request setHTTPBody:[_postStringForShare dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}


- (void)unShareFileOrFolderByServer:(NSString *)serverPath
                        onCommunication:(OCCommunication *)sharedOCCommunication
                                success:(void(^)(NSHTTPURLResponse *, id))success
                                failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}


- (void)isShareFileOrFolderByServer:(NSString *)serverPath
                    onCommunication:(OCCommunication *)sharedOCCommunication
                            success:(void(^)(NSHTTPURLResponse *, id))success
                            failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) updateShareItem:(NSInteger)shareId ofServerPath:(NSString*)serverPath withPasswordProtect:(NSString*)password andExpirationTime:(NSString*)expirationTime andPermissions:(NSInteger)permissions
         onCommunication:(OCCommunication *)sharedOCCommunication
                 success:(void(^)(NSHTTPURLResponse *, id response))success
                 failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"PUT";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    if (password) {
        self.postStringForShare = [NSString stringWithFormat:@"password=%@",password];
    } else if (expirationTime) {
        self.postStringForShare = [NSString stringWithFormat:@"expireDate=%@",expirationTime];
    }else if (permissions > 0) {
        self.postStringForShare = [NSString stringWithFormat:@"permissions=%ld",(long)permissions];
    }
    
    [request setHTTPBody:[_postStringForShare dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) searchUsersAndGroupsWith:(NSString *)searchString forPage:(NSInteger)page with:(NSInteger)resultsPerPage ofServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
    failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSString *searchQuery = [NSString stringWithFormat: @"&search=%@",searchString];
    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];
    NSString *queryType = [NSString stringWithFormat:@"&itemType=file"];
    NSString *pagination = [NSString stringWithFormat:@"&page=%ld&perPage=%ld", (long)page, (long)resultsPerPage];
    serverPath = [serverPath stringByAppendingString:jsonQuery];
    serverPath = [serverPath stringByAppendingString:queryType];
    serverPath = [serverPath stringByAppendingString:searchQuery];
    serverPath = [serverPath stringByAppendingString:pagination];

    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) getCapabilitiesOfServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
                         failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    _requestMethod = @"GET";
    
    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];
    serverPath = [serverPath stringByAppendingString:jsonQuery];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];

    
}


#pragma mark - Remote thumbnails

- (OCHTTPRequestOperation *) getRemoteThumbnailByServer:(NSString*)serverPath ofFilePath:(NSString*)filePath  withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight onCommunication:(OCCommunication *)sharedOCCommunication
                            success:(void(^)(NSHTTPURLResponse *operation, id response))success
                            failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    _requestMethod = @"GET";
    
    NSString *query = [NSString stringWithFormat:@"/%i/%i/%@", (int)fileWidth, (int)fileHeight, filePath];
    serverPath = [serverPath stringByAppendingString:query];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    return operation;
}

#pragma mark - Get Notification

- (void)getNotificationServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
                          failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";

    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];
    serverPath = [serverPath stringByAppendingString:jsonQuery];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)setNotificationServer:(NSString *)serverPath type:(NSString *)type onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = type;
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)subscribingNextcloudServerPush:(NSString *)serverPath authorizationToken:(NSString *)authorizationToken pushTokenHash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey proxyServerPath:(NSString *)proxyServerPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSString *pushTokenHashParam = [NSString stringWithFormat:@"?pushTokenHash=%@",pushTokenHash];
    NSString *devicePublicKeyParam = [NSString stringWithFormat:@"&devicePublicKey=%@",devicePublicKey];
    NSString *proxyServerPathParam = [NSString stringWithFormat:@"&proxyServer=%@",proxyServerPath];
    
    serverPath = [serverPath stringByAppendingString:pushTokenHashParam];
    serverPath = [serverPath stringByAppendingString:devicePublicKeyParam];
    serverPath = [serverPath stringByAppendingString:proxyServerPathParam];

    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    [request setValue:[NSString stringWithFormat:@"token %@", authorizationToken] forHTTPHeaderField:@"Authorization"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)subscribingPushProxy:(NSString *)serverPath authorizationToken:(NSString *)authorizationToken pushToken:(NSString *)pushToken deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature userPublicKey:(NSString *)userPublicKey onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    pushToken = [NSString stringWithFormat:@"?pushToken=%@",pushToken];
    deviceIdentifier = [NSString stringWithFormat:@"&deviceIdentifier=%@",deviceIdentifier];
    deviceIdentifierSignature = [NSString stringWithFormat:@"&deviceIdentifierSignature=%@",deviceIdentifierSignature];
    userPublicKey = [NSString stringWithFormat:@"&userPublicKey=%@",userPublicKey];
    
    serverPath = [serverPath stringByAppendingString:pushToken];
    serverPath = [serverPath stringByAppendingString:deviceIdentifier];
    serverPath = [serverPath stringByAppendingString:deviceIdentifierSignature];
    serverPath = [serverPath stringByAppendingString:userPublicKey];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get Activity

- (void) getActivityServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
                       failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];
    //NSString *startParamater = [NSString stringWithFormat:@"&start=%@", start];

    serverPath = [serverPath stringByAppendingString:jsonQuery];
    //serverPath = [serverPath stringByAppendingString:startParamater];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get External sites

- (void) getExternalSitesServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
                   failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];    
    serverPath = [serverPath stringByAppendingString:jsonQuery];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get User Profile

- (void) getUserProfileServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success
                          failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    NSString *jsonQuery = [NSString stringWithFormat:@"?format=json"];
    serverPath = [serverPath stringByAppendingString:jsonQuery];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Manage Redirections

- (void) setRedirectionBlockOnDatataskWithOCCommunication: (OCCommunication *) sharedOCCommunication andSessionManager:(AFURLSessionManager *) sessionManager{
    
    [sessionManager setTaskWillPerformHTTPRedirectionBlock:^NSURLRequest * _Nonnull(NSURLSession * _Nonnull session, NSURLSessionTask * _Nonnull task, NSURLResponse * _Nonnull response, NSURLRequest * _Nonnull request) {
        
        if (response == nil) {
            // needed to handle fake redirects to canonical addresses, as explained in https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/URLLoadingSystem/Articles/RequestChanges.html
            return request;
        }
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        NSDictionary *dict = [httpResponse allHeaderFields];
        //Server path of redirected server
        NSString *responseURLString = [dict objectForKey:@"Location"];
        
        if (responseURLString) {
            
            if ([UtilsFramework isURLWithSamlFragment:responseURLString] || httpResponse.statusCode == k_redirected_code_1) {
                //We set the redirectedServer in case SAML or is a permanent redirection
                self.redirectedServer = responseURLString;
                
                if ([UtilsFramework isURLWithSamlFragment:responseURLString]) {
                    // if SAML request, we don't want to follow it; WebView takes care, not here -> nil to NO FOLLOW
                    return nil;
                }
            }
            
            NSMutableURLRequest *requestRedirect = [request mutableCopy];
            [requestRedirect setURL: [NSURL URLWithString:responseURLString]];
            
            requestRedirect = [sharedOCCommunication getRequestWithCredentials:requestRedirect];
            requestRedirect.HTTPMethod = _requestMethod;
            
            if (_postStringForShare) {
                //It is a request to share a file by link
                requestRedirect = [self sharedRequestWithMethod:_requestMethod path:responseURLString parameters:nil];
                [requestRedirect setHTTPBody:[_postStringForShare dataUsingEncoding:NSUTF8StringEncoding]];
            }
            
            return requestRedirect;
            
        } else {
            // no location to redirect -> nil to NO FOLLOW
            return nil;
        }
        
    }];
}

@end

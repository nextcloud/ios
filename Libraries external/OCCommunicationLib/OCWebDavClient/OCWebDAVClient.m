
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
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//

#import "OCWebDAVClient.h"
#import "OCFrameworkConstants.h"
#import "OCCommunication.h"
#import "UtilsFramework.h"
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

NSString *const NCResource = @"<d:displayname/>"
                              "<d:getcontenttype/>"
                              "<d:resourcetype/>"
                              "<d:getcontentlength/>"
                              "<d:getlastmodified/>"
                              "<d:creationdate/>"
                              "<d:getetag/>"
                              "<d:quota-used-bytes/>"
                              "<d:quota-available-bytes/>"
                              "<permissions xmlns=\"http://owncloud.org/ns\"/>"
                              "<id xmlns=\"http://owncloud.org/ns\"/>"
                              "<fileid xmlns=\"http://owncloud.org/ns\"/>"
                              "<size xmlns=\"http://owncloud.org/ns\"/>"
                              "<favorite xmlns=\"http://owncloud.org/ns\"/>"
                              "<is-encrypted xmlns=\"http://nextcloud.org/ns\"/>"
                              "<mount-type xmlns=\"http://nextcloud.org/ns\"/>"
                              "<owner-id xmlns=\"http://owncloud.org/ns\"/>"
                              "<owner-display-name xmlns=\"http://owncloud.org/ns\"/>"
                              "<comments-unread xmlns=\"http://owncloud.org/ns\"/>"
                              "<has-preview xmlns=\"http://nextcloud.org/ns\"/>"
                              "<trashbin-filename xmlns=\"http://nextcloud.org/ns\"/>"
                              "<trashbin-original-location xmlns=\"http://nextcloud.org/ns\"/>"
                              "<trashbin-deletion-time xmlns=\"http://nextcloud.org/ns\"/>";

@interface OCWebDAVClient()

- (void)mr_listPath:(NSString *)path depth:(NSString *)depth onCommunication:
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

- (NSMutableURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters timeout:(NSTimeInterval)timeout {
    
    NSMutableURLRequest *request = [[AFHTTPRequestSerializer new] requestWithMethod:method URLString:path parameters:nil error:nil];
    [request setAllHTTPHeaderFields:self.defaultHeaders];
    
    [request setCachePolicy: NSURLRequestReloadIgnoringLocalCacheData];
    [request setTimeoutInterval: timeout];
    
    return request;
}

- (NSMutableURLRequest *)sharedRequestWithMethod:(NSString *)method path:(NSString *)path parameters:(NSDictionary *)parameters timeout:(NSTimeInterval)timeout {
    
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
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:source parameters:nil timeout:k_timeout_webdav];
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
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
	OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}


- (void)mr_listPath:(NSString *)path depth:(NSString *)depth onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *, id))success
            failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";
	NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
    
    [request setValue: depth forHTTPHeaderField: @"Depth"];
    NSString *body = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>";
    body = [body stringByAppendingString:NCResource];
    body = [body stringByAppendingString:@"</d:prop></d:propfind>"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)mr_listPath:(NSString *)path depth:(NSString *)depth withUserSessionToken:(NSString*)token onCommunication:
(OCCommunication *)sharedOCCommunication
            success:(void(^)(NSHTTPURLResponse *operation, id response, NSString *token))success
            failure:(void(^)(NSHTTPURLResponse *response, id  _Nullable responseObject, NSError *, NSString *token))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
    
    [request setValue: depth forHTTPHeaderField: @"Depth"];
    NSString *body = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>";
    body = [body stringByAppendingString:NCResource];
    body = [body stringByAppendingString:@"</d:prop></d:propfind>"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)propertiesOfPath:(NSString *)path
         onCommunication: (OCCommunication *)sharedOCCommunication
                 success:(void(^)(NSHTTPURLResponse *, id ))success
                 failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	[self mr_listPath:path depth:@"0" onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)listPath:(NSString *)path depth:(NSString *)depth
 onCommunication:(OCCommunication *)sharedOCCommunication
         success:(void(^)(NSHTTPURLResponse *, id))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
	[self mr_listPath:path depth:depth onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)listPath:(NSString *)path depth:(NSString *)depth
 onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token
         success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success
         failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    [self mr_listPath:path depth:depth withUserSessionToken:token onCommunication:sharedOCCommunication success:success failure:failure];
}

- (void)search:(NSString *)path folder:(NSString *)folder fileName:(NSString *)fileName depth:(NSString *)depth lteDateLastModified:(NSString *)lteDateLastModified gteDateLastModified:(NSString *)gteDateLastModified contentType:(NSArray *)contentType user:(NSString *)user userID:(NSString *)userID onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSString *body = @"";
    NSString *whereType = @"";
    NSString *whereDate = @"";
    
    NSParameterAssert(success);
    
    _requestMethod = @"SEARCH";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_search];
    
    if (contentType && lteDateLastModified && gteDateLastModified) {
        
        body = [NSString stringWithFormat: @""
        "<?xml version=\"1.0\"?>"
        "<d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
            "<d:basicsearch>"
                "<d:select>"
                    "<d:prop>"
                        "%@"
                    "</d:prop>"
                "</d:select>"
                "<d:from>"
                    "<d:scope>"
                        "<d:href>/files/%@%@</d:href>"
                        "<d:depth>infinity</d:depth>"
                    "</d:scope>"
                "</d:from>"
                "<d:orderby>"
                    "<d:order>"
                        "<d:prop><d:getlastmodified/></d:prop>"
                        "<d:descending/>"
                    "</d:order>"
                    "<d:order>"
                        "<d:prop><d:displayname/></d:prop>"
                        "<d:descending/>"
                    "</d:order>"
                "</d:orderby>"
                "<d:where><d:and><d:or>", NCResource, userID, folder];
        
        for (NSString *type in contentType) {
            whereType = [NSString stringWithFormat: @"%@<d:like><d:prop><d:getcontenttype/></d:prop><d:literal>%@</d:literal></d:like>", whereType, type];
        }
        
        body = [NSString stringWithFormat: @"%@%@</d:or><d:or>", body, whereType];
        
        whereDate = [NSString stringWithFormat: @"%@<d:and><d:lte><d:prop><d:getlastmodified/></d:prop><d:literal>%@</d:literal></d:lte><d:gte><d:prop><d:getlastmodified/></d:prop><d:literal>%@</d:literal></d:gte></d:and>", whereDate, lteDateLastModified, gteDateLastModified];
        
        /*
        if (gteDateLastModified != nil && lteDateLastModified == nil) {
            whereDate = [NSString stringWithFormat: @"%@<d:gte><d:prop><d:getlastmodified/></d:prop><d:literal>%@</d:literal></d:gte>", whereDate, gteDateLastModified];
        } else if (gteDateLastModified != nil && lteDateLastModified != nil) {
            whereDate = [NSString stringWithFormat: @"%@<d:and><d:lte><d:prop><d:getlastmodified/></d:prop><d:literal>%@</d:literal></d:lte><d:gte><d:prop><d:getlastmodified/></d:prop><d:literal>%@</d:literal></d:gte></d:and>", whereDate, lteDateLastModified, gteDateLastModified];
        }
        */
        
        body = [NSString stringWithFormat: @"%@%@</d:or></d:and></d:where></d:basicsearch></d:searchrequest>", body, whereDate];
        
    } else {
        
        body = [NSString stringWithFormat: @""
        "<?xml version=\"1.0\"?>"
        "<d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
            "<d:basicsearch>"
                "<d:select>"
                    "<d:prop>"
                        "%@"
                    "</d:prop>"
                "</d:select>"
                "<d:from>"
                    "<d:scope>"
                        "<d:href>/files/%@%@</d:href>"
                        "<d:depth>infinity</d:depth>"
                    "</d:scope>"
                "</d:from>"
                "<d:where>"
                    "<d:like>"
                        "<d:prop><d:displayname/></d:prop>"
                        "<d:literal>%@</d:literal>"
                    "</d:like>"
                "</d:where>"
            "</d:basicsearch>"
        "</d:searchrequest>", NCResource, userID, folder, fileName];
    }
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)search:(NSString *)path folder:(NSString *)folder fileName:(NSString *)fileName dateLastModified:(NSString *)dateLastModified numberOfItem:(NSInteger)numberOfItem userID:(NSString *)userID onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSString *body = @"";
    
    NSParameterAssert(success);
    
    _requestMethod = @"SEARCH";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_search];
    
    body = [NSString stringWithFormat: @""
            "<?xml version=\"1.0\"?>"
                "<d:searchrequest xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
                    "<d:basicsearch>"
                        "<d:select>"
                            "<d:prop>"
                                "%@"
                            "</d:prop>"
                        "</d:select>"
            
                        "<d:from>"
                            "<d:scope>"
                                "<d:href>/files/%@%@</d:href>"
                                "<d:depth>1</d:depth>"
                            "</d:scope>"
                        "</d:from>"
            
                        /*
                        "<d:orderby>"
                            "<d:order>"
                                "<d:prop><d:displayname/></d:prop>"
                                "<d:descending/>"
                            "</d:order>"
                            "<d:order>"
                                "<d:prop><d:getlastmodified/></d:prop>"
                                "<d:descending/>"
                            "</d:order>"
                        "</d:orderby>"
                        */
            
                        "<d:where>"
                            "<d:like>"
                                "<d:prop><d:displayname/></d:prop>"
                                "<d:literal>%@</d:literal>"
                            "</d:like>"
                        "</d:where>"
                /*
                        "<d:where><d:and><d:or>"
                            "<d:gte>"
                                "<d:prop><d:getlastmodified/></d:prop>"
                                "<d:literal>%@</d:literal>"
                            "</d:gte>"
                        "</d:or></d:and></d:where>"
               
                        "<d:limit>"
                            "<d:nresults>%@</d:nresults>"
                        "</d:limit>"
                 */
                    "</d:basicsearch>"
                "</d:searchrequest>", NCResource, userID, folder, fileName]; //, [@(numberOfItem) stringValue]];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}
- (void)settingFavorite:(NSString * _Nonnull)path favorite:(BOOL)favorite onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"PROPPATCH";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
    
    NSString *body;
    body = [NSString stringWithFormat: @""
            "<?xml version=\"1.0\"?>"
            "<d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
                "<d:set>"
                    "<d:prop>"
                        "<oc:favorite>%i</oc:favorite>"
                    "</d:prop>"
                "</d:set>"
            "</d:propertyupdate>", (favorite ? 1 : 0)];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)listingFavorites:(NSString *)path folder:(NSString *)folder user:(NSString *)user userID:(NSString *)userID onCommunication:(OCCommunication *)sharedOCCommunication withUserSessionToken:(NSString *)token success:(void(^)(NSHTTPURLResponse *, id, NSString *token))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *, NSString *token))failure {

    NSParameterAssert(success);
    
    _requestMethod = @"REPORT";
    
    userID = [userID stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLFragmentAllowedCharacterSet]];
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:[NSString stringWithFormat:@"%@/files/%@%@", path, userID, folder] parameters:nil timeout:k_timeout_webdav];
    
    NSString *body = @"<?xml version=\"1.0\"?><oc:filter-files xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>";
    body = [body stringByAppendingString:NCResource];
    body = [body stringByAppendingString:@"</d:prop><oc:filter-rules><oc:favorite>1</oc:favorite></oc:filter-rules></oc:filter-files>"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"text/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication withUserSessionToken:token success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (NSURLSessionDownloadTask *)downloadWithSessionPath:(NSString *)remoteSource toPath:(NSString *)localDestination defaultPriority:(BOOL)defaultPriority onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))downloadProgress success:(void(^)(NSURLResponse *response, NSURL *filePath))success failure:(void(^)(NSURLResponse *response, NSError *error))failure{
    
    NSMutableURLRequest *request = [self requestWithMethod:@"GET" path:remoteSource parameters:nil timeout:k_timeout_webdav];
    
    //If is not nil is a redirection so we keep the original url server
    if (!self.originalUrlServer) {
        self.originalUrlServer = [request.URL absoluteString];
    }
    
    //We add the cookies of that URL
    request = [UtilsFramework getRequestWithCookiesByRequest:request andOriginalUrlServer:self.originalUrlServer];
        
    NSURLSessionDownloadTask *downloadTask = [sharedOCCommunication.downloadSessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull progress) {
        downloadProgress(progress);
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        [[NSFileManager defaultManager] removeItemAtURL:[NSURL fileURLWithPath:localDestination] error:nil];
        return [NSURL fileURLWithPath:localDestination];
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
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
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
	NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
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
    
        NSMutableURLRequest *request = [self requestWithMethod:@"PUT" path:remoteDestination parameters:nil timeout:k_timeout_webdav];
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path: apiUserUrl parameters: nil timeout:k_timeout_webdav];
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path: urlString parameters: nil timeout:k_timeout_webdav];
    
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)listSharedByServer:(NSString *)serverPath andPath:(NSString *) path
           onCommunication:(OCCommunication *)sharedOCCommunication
                   success:(void(^)(NSHTTPURLResponse *, id))success
                   failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
	
    NSString *postString = [NSString stringWithFormat: @"?path=%@&reshares=true",path];
    serverPath = [serverPath stringByAppendingString:postString];
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)shareByLinkFileOrFolderByServer:(NSString *)serverPath andPath:(NSString *) filePath andPassword:(NSString *)password andPermission:(NSInteger)permission andHideDownload:(BOOL)hideDownload
                        onCommunication:(OCCommunication *)sharedOCCommunication
                                success:(void(^)(NSHTTPURLResponse *, id))success
                                failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    _postStringForShare = [NSString stringWithFormat: @"path=%@&shareType=3&permissions=%ld&password=%@&hidedownload=%i", filePath, (long)permission, password, hideDownload];
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
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
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) updateShareItem:(NSInteger)shareId ofServerPath:(NSString*)serverPath withPasswordProtect:(NSString*)password andNote:(NSString *)note andExpirationTime:(NSString*)expirationTime andPermissions:(NSInteger)permissions andHideDownload:(BOOL)hideDownload
         onCommunication:(OCCommunication *)sharedOCCommunication
                 success:(void(^)(NSHTTPURLResponse *, id response))success
                 failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"PUT";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    if (password) {
        self.postStringForShare = [NSString stringWithFormat:@"password=%@&",password];
    } else if (note) {
        self.postStringForShare = [NSString stringWithFormat:@"note=%@",note];
    } else if (expirationTime) {
        self.postStringForShare = [NSString stringWithFormat:@"expireDate=%@",expirationTime];
    } else if (permissions > 0) {
        self.postStringForShare = [NSString stringWithFormat:@"permissions=%ld",(long)permissions];
    } else {
        if (hideDownload) self.postStringForShare = [NSString stringWithFormat:@"hideDownload=true"];
        else self.postStringForShare = [NSString stringWithFormat:@"hideDownload=false"];
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

    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void) getCapabilitiesOfServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    _requestMethod = @"GET";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}


#pragma mark - Remote thumbnails

- (OCHTTPRequestOperation *) getRemoteThumbnailByServer:(NSString*)serverPath ofFilePath:(NSString*)filePath withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    _requestMethod = @"GET";
    
    NSString *query = [NSString stringWithFormat:@"/index.php/apps/files/api/v1/thumbnail/%i/%i/%@", (int)fileWidth, (int)fileHeight, filePath];
    serverPath = [serverPath stringByAppendingString:query];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    return operation;
}

- (OCHTTPRequestOperation *) getRemotePreviewByServer:(NSString *)serverPath ofFilePath:(NSString *)filePath withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight andA:(NSInteger)a andMode:(NSString *)mode path:(NSString *)path onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    _requestMethod = @"GET";
    
    if (path.length > 0) {
        serverPath = path;
    } else {
        NSString *query = [NSString stringWithFormat:@"/index.php/core/preview.png?file=%@&x=%d&y=%d&a=%d&mode=%@", filePath, (int)fileWidth, (int)fileHeight, (int)a, mode];
        serverPath = [serverPath stringByAppendingString:query];
    }
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    return operation;
}

- (OCHTTPRequestOperation *) getRemotePreviewTrashByServer:(NSString *)serverPath ofFileId:(NSString*)fileId size:(NSString *)size onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    _requestMethod = @"GET";
    
    NSString *query = [NSString stringWithFormat:@"/index.php/apps/files_trashbin/preview?fileId=%@&x=%@&y=%@", fileId, size, size];
    serverPath = [serverPath stringByAppendingString:query];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    return operation;
}

#pragma mark - Get Notification

- (void)getNotificationServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";

    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)setNotificationServer:(NSString *)serverPath type:(NSString *)type onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = type;
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)subscribingNextcloudServerPush:(NSString *)serverPath pushTokenHash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey proxyServerPath:(NSString *)proxyServerPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&pushTokenHash=%@",pushTokenHash]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&devicePublicKey=%@",devicePublicKey]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&proxyServer=%@",proxyServerPath]];

    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)unsubscribingNextcloudServerPush:(NSString *)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)subscribingPushProxy:(NSString *)serverPath pushToken:(NSString *)pushToken deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
        
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&pushToken=%@",pushToken]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&deviceIdentifier=%@",deviceIdentifier]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&deviceIdentifierSignature=%@",deviceIdentifierSignature]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&userPublicKey=%@",publicKey]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    NSString *userAgent = [request valueForHTTPHeaderField:@"User-Agent"];
    //[request setValue:[userAgent stringByAppendingString:@" (SilentPush)"] forHTTPHeaderField:@"User-Agent"];
    [request setValue:[userAgent stringByAppendingString:@" (Strict VoIP)"] forHTTPHeaderField:@"User-Agent"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)unsubscribingPushProxy:(NSString *)serverPath deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature publicKey:(NSString *)publicKey onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *, id))success failure:(void(^)(NSHTTPURLResponse *, id  _Nullable responseObject, NSError *))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&deviceIdentifier=%@",deviceIdentifier]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&deviceIdentifierSignature=%@",deviceIdentifierSignature]];
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&userPublicKey=%@",publicKey]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    [request setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get Activity

- (void) getActivityServer:(NSString*)serverPath since:(NSInteger)since limit:(NSInteger)limit objectId:(NSString *)objectId objectType:(NSString *)objectType previews:(BOOL)previews link:(NSString *)link onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    if (objectId.length == 0) {
        serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"/all?format=json&since=%ld&limit=%ld", (long)since, (long)limit]];
    } else {
        serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"/filter?format=json&since=%ld&limit=%ld&object_id=%@&object_type=%@",(long)since, (long)limit, objectId, objectType]];
    }
    if (previews) {
        serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"&previews=true"]];
    }
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get External sites

- (void) getExternalSitesServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

#pragma mark - Get User Profile

- (void) getUserProfileServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

#pragma mark - End-to-End Encryption

- (void)getEndToEndPublicKeys:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)getEndToEndPrivateKeyCipher:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)getEndToEndServerPublicKey:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"GET";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)signEndToEndPublicKey:(NSString*)serverPath key:(NSString *)key onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    _postStringKey = [NSString stringWithFormat: @"csr=%@",key];
    [request setHTTPBody:[_postStringKey dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)storeEndToEndPrivateKeyCipher:(NSString*)serverPath key:(NSString *)key onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    _postStringKey = [NSString stringWithFormat: @"privateKey=%@",key];
    [request setHTTPBody:[_postStringKey dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)deleteEndToEndPublicKey:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"DELETE";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)deleteEndToEndPrivateKey:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"DELETE";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)markEndToEndFolderEncrypted:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"PUT";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)deletemarkEndToEndFolderEncrypted:(NSString*)serverPath e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"DELETE";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)lockEndToEndFolderEncrypted:(NSString*)serverPath e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"POST";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)unlockEndToEndFolderEncrypted:(NSString*)serverPath e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    _requestMethod = @"DELETE";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    NSLog(@"%@", [request allHTTPHeaderFields]);
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];

    [operation resume];
}

- (void)getEndToEndMetadata:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)storeEndToEndMetadata:(NSString*)serverPath metadata:(NSString *)metadata e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    _postStringMetadata = [NSString stringWithFormat: @"metaData=%@",metadata];
    [request setHTTPBody:[_postStringMetadata dataUsingEncoding:NSUTF8StringEncoding]];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)updateEndToEndMetadata:(NSString*)serverPath metadata:(NSString *)metadata e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure{
    
    NSParameterAssert(success);
    
    _requestMethod = @"PUT";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    _postStringMetadata = [NSString stringWithFormat: @"metaData=%@",metadata];
    [request setHTTPBody:[_postStringMetadata dataUsingEncoding:NSUTF8StringEncoding]];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)deleteEndToEndMetadata:(NSString*)serverPath e2eToken:(NSString *)e2eToken onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
        
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil  timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setValue:e2eToken forHTTPHeaderField:@"e2e-token"];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Manage Mobile Editor OCS API

- (void)createLinkRichdocuments:(NSString *)serverPath fileId:(NSString *)fileId onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPBody:[[NSString stringWithFormat: @"fileId=%@",fileId] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)getTemplatesRichdocuments:(NSString *)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)createNewRichdocuments:(NSString *)serverPath path:(NSString *)path templateID:(NSString *)templateID onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPBody:[[NSString stringWithFormat: @"path=%@&template=%@", path, templateID] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)createAssetRichdocuments:(NSString *)serverPath path:(NSString *)path onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {

    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPBody:[[NSString stringWithFormat: @"path=%@",path] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Fulltextsearch

- (void)fullTextSearch:(NSString *)serverPath data:(NSString *)data onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"GET";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    //[request setHTTPBody:[data dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPBody:[[NSString stringWithFormat:@"request=%@",data] dataUsingEncoding:NSUTF8StringEncoding]];

    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Remore wipe

- (void)getSetRemoteWipe:(NSString *)serverPath token:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPBody:[[NSString stringWithFormat:@"token=%@",token] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Trash

- (void)listTrash:(NSString *)path depth:(NSString *)depth onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *response, id  _Nullable responseObject, NSError *error))failure
{
    NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";
    
    NSMutableURLRequest *request = [self requestWithMethod:_requestMethod path:path parameters:nil timeout:k_timeout_webdav];
    
    [request setValue: depth forHTTPHeaderField: @"Depth"];
    
    NSString *body = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?><d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\"><d:prop>";
    body = [body stringByAppendingString:NCResource];
    body = [body stringByAppendingString:@"</d:prop></d:propfind>"];
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    [operation resume];
}

- (void)emptyTrash:(NSString*)path onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:path parameters:nil  timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Messages

- (void)getComments:(NSString *)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id  _Nullable responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"PROPFIND";

    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
                          
    [request setHTTPBody:[@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
                          "<d:propfind xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
                          "<d:prop>"
                          "<oc:id/>"
                          "<oc:verb/>"
                          "<oc:actorType/>"
                          "<oc:actorId/>"
                          "<oc:creationDateTime/>"
                          "<oc:objectType/>"
                          "<oc:objectId/>"
                          "<oc:isUnread/>"
                          "<oc:message/>"
                          "<oc:actorDisplayName/>"
                          "</d:prop>"
                          "</d:propfind>" dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)putComments:(NSString*)serverPath message:(NSString *)message onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[[NSString stringWithFormat: @"{\"actorType\":\"users\",\"verb\":\"comment\",\"message\":\"%@\"}",message] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)updateComments:(NSString*)serverPath message:(NSString *)message onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"PROPPATCH";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];

    NSString *body;
    body = [NSString stringWithFormat: @""
            "<?xml version=\"1.0\"?>"
            "<d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
            "<d:set>"
            "<d:prop>"
            "<oc:message>%@</oc:message>"
            "</d:prop>"
            "</d:set>"
            "</d:propertyupdate>", message];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)readMarkComments:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"PROPPATCH";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    NSString *body;
    body = [NSString stringWithFormat: @""
            "<?xml version=\"1.0\"?>"
            "<d:propertyupdate xmlns:d=\"DAV:\" xmlns:oc=\"http://owncloud.org/ns\" xmlns:nc=\"http://nextcloud.org/ns\">"
            "<d:set>"
            "<d:prop>"
            "<readMarker xmlns=\"http://owncloud.org/ns\"/>"
            "</d:prop>"
            "</d:set>"
            "</d:propertyupdate>"];
    
    [request setHTTPBody:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request setValue:@"application/xml" forHTTPHeaderField:@"Content-Type"];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)deleteComments:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"DELETE";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Third Parts

- (void)getHCUserProfile:(NSString *)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    _requestMethod = @"GET";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)putHCUserProfile:(NSString*)serverPath data:(NSString *)data onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    NSParameterAssert(success);
    
    _requestMethod = @"POST";
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    [request setValue:@"true" forHTTPHeaderField:@"OCS-APIRequest"];
    [request setHTTPBody:[[NSString stringWithFormat: @"data=%@",data] dataUsingEncoding:NSUTF8StringEncoding]];
    
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

- (void)getHCFeatures:(NSString *)serverPath onCommunication:(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *operation, id response))success failure:(void(^)(NSHTTPURLResponse *operation, id responseObject, NSError *error))failure {
    
    _requestMethod = @"GET";
    
    serverPath = [serverPath stringByAppendingString:[NSString stringWithFormat:@"?format=json"]];
    
    NSMutableURLRequest *request = [self sharedRequestWithMethod:_requestMethod path:serverPath parameters:nil timeout:k_timeout_webdav];
    OCHTTPRequestOperation *operation = [self mr_operationWithRequest:request onCommunication:sharedOCCommunication success:success failure:failure];
    [self setRedirectionBlockOnDatataskWithOCCommunication:sharedOCCommunication andSessionManager:sharedOCCommunication.networkSessionManager];
    
    [operation resume];
}

#pragma mark - Manage Redirections

- (void)setRedirectionBlockOnDatataskWithOCCommunication: (OCCommunication *) sharedOCCommunication andSessionManager:(AFURLSessionManager *) sessionManager{
    
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
                requestRedirect = [self sharedRequestWithMethod:_requestMethod path:responseURLString parameters:nil  timeout:k_timeout_webdav];
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

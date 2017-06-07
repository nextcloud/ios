//
//  OCWebDAVClient.h
//  OCWebDAVClient
//
// This class is based in https://github.com/zwaldowski/DZWebDAVClient. Copyright (c) 2012 Zachary Waldowski, Troy Brant, Marcus Rohrmoser, and Sam Soffes.
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


#import "AFHTTPSessionManager.h"
#import "OCHTTPRequestOperation.h"

@class OCCommunication;
@class OCChunkDto;

/** The key for a uniform (MIME) type identifier returned from the property request methods. */
extern NSString * _Nullable OCWebDAVContentTypeKey;

/** The key for a unique entity identifier returned from the property request methods. */
extern NSString * _Nullable OCWebDAVETagKey;

/** The key for a content identifier tag returned from the property request methods. This is only supported on some servers, and usually defines whether the contents of a collection (folder) have changed. */
extern NSString * _Nullable OCWebDAVCTagKey;

/** The key for the creation date of an entity. */
extern NSString * _Nullable OCWebDAVCreationDateKey;

/** The key for last modification date of an entity. */
extern NSString * _Nullable OCWebDAVModificationDateKey;

@interface OCWebDAVClient : NSObject

@property (readwrite, nonatomic, strong) NSMutableDictionary * _Nullable defaultHeaders;
//On redirections AFNetworking lose the request method on iOS6 and set a GET, we use this as workarround
@property (nonatomic, strong) NSString * _Nullable requestMethod;
//We use this variable to return the url of a redirected server to detect if we receive any sesion expired on SSO server
@property (nonatomic, strong) NSString * _Nullable redirectedServer;
//We use this variable to get the Cookies from the storage provider
@property (nonatomic, strong) NSString * _Nullable originalUrlServer;

@property (nonatomic, strong) NSString * _Nullable postStringForShare;

/**
 Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a basic authentication value with Base64-encoded username and password. This overwrites any existing value for this header.
 
 @param username The HTTP basic auth username
 @param password The HTTP basic auth password
 */
- (void)setAuthorizationHeaderWithUsername:(NSString * _Nonnull)username
                                  password:(NSString * _Nonnull)password;

/**
 Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a basic authentication value with Base64-encoded username and password. This overwrites any existing value for this header.
 
 @param cookieString The HTTP token to login on SSO Servers
 */
- (void)setAuthorizationHeaderWithCookie:(NSString * _Nonnull) cookieString;

/**
 Sets the "Authorization" HTTP header set in request objects made by the HTTP client to a token-based authentication value, such as an OAuth access token. This overwrites any existing value for this header.
 
 @param token The authentication token
 */
- (void)setAuthorizationHeaderWithToken:(NSString * _Nonnull)token;


/**
 Sets the "User-Agent" HTTP header
 
 @param userAgent -> String that indentifies the client app. Ex: "iOS-ownCloud"
 */
- (void)setUserAgent:(NSString * _Nonnull)userAgent;


/**
 Enqueues an operation to move the object at a path to another path using a `MOVE` request.
 
 @param source The path to move.
 @param destination The path to move the item to.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with no arguments.
 @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and the network error that occurred.
 */
- (void)movePath:(NSString * _Nonnull)source toPath:(NSString * _Nonnull)destination
 onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
         success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

/**
 Enqueues an operation to delete the object at a path using a `DELETE` request.
 
 @param path The path for which to create a directory.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with no arguments.
 @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and the network error that occurred.
 */
- (void)deletePath:(NSString * _Nonnull)path
   onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
           success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
           failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;



/**
 Enqueues a request to list the properties of a single entity using a `PROPFIND` request for the specified path.
 
 @param path The path for which to list the properties.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a dictionary with the properties of the entity.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 
 @see listPath:success:failure:
 @see recursiveListPath:success:failure:
 */
- (void)propertiesOfPath:(NSString * _Nonnull)path
         onCommunication: (OCCommunication * _Nonnull)sharedOCCommunication
                 success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nonnull))success
                 failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

/**
 Enqueues a request to list the contents of a single collection and
 the properties of each object, including the properties of the
 collection itself, using a `PROPFIND` request.
 
 @param path The directory for which to list the contents.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a dictionary with the properties of the directory and its contents.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 
 @see propertiesOfPath:success:failure:
 @see recursiveListPath:success:failure:
 */
- (void)listPath:(NSString * _Nonnull)path
 onCommunication: (OCCommunication * _Nonnull)sharedOCCommunication
         success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nullable responseObject))success
         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;


/**
 Enqueues a request to list the contents of a single collection and
 the properties of each object, including the properties of the
 collection itself, using a `PROPFIND` request.
 
 @param path The directory for which to list the contents.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param token User Session token
 @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a dictionary with the properties of the directory and its contents.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 
 @see propertiesOfPath:success:failure:
 @see recursiveListPath:success:failure:
 */
- (void)listPath:(NSString * _Nonnull)path
 onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication withUserSessionToken:(NSString * _Nonnull)token
         success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nonnull, NSString * _Nonnull token))success
         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull, NSString * _Nonnull token))failure;

/**
 
*/ 

- (void)search:(NSString * _Nonnull)path folder:(NSString * _Nonnull)folder fileName:(NSString * _Nonnull)fileName depth:(NSString * _Nonnull)depth dateLastModified:(NSString * _Nonnull)dateLastModified user:(NSString * _Nonnull)user onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication withUserSessionToken:(NSString * _Nonnull)token success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nonnull, NSString * _Nonnull token))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull, NSString * _Nonnull token))failure;

/**
 
 */

- (void)settingFavorite:(NSString * _Nonnull)path favorite:(BOOL)favorite onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication withUserSessionToken:(NSString * _Nonnull)token success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nonnull, NSString * _Nonnull token))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull, NSString * _Nonnull token))failure;

/**
 
 */

- (void)listingFavorites:(NSString * _Nonnull)path folder:(NSString * _Nonnull)folder user:(NSString * _Nonnull)user onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication withUserSessionToken:(NSString * _Nonnull)token success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nonnull, NSString * _Nonnull token))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull, NSString * _Nonnull token))failure;



/**
 Creates an `NSURLSessionDownloadTask` with the specified request for a local file.
 
 @param remoteSource is a string with the path of the file in the server 
 @param localDestination is a string with the local device path for store the file
 @param defaultPriority is a bool with a flag to indicate if the download must be download inmediately of not.
 @param progress A progress object monitoring the current upload progress.
 @param success A block callback, to be fired upon successful completion, with NSURLResponse and string of URL of the filePath
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 *
 @warning NSURLSession and NSRULSessionUploadTask only can be supported in iOS 7.
 */
- (NSURLSessionDownloadTask * _Nonnull)downloadWithSessionPath:(NSString * _Nonnull)remoteSource toPath:(NSString * _Nonnull)localDestination defaultPriority:(BOOL)defaultPriority onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication progress:(void(^ _Nonnull)(NSProgress * _Nonnull progress))downloadProgress success:(void(^ _Nonnull)(NSURLResponse * _Nonnull response, NSURL * _Nonnull filePath))success failure:(void(^ _Nonnull)(NSURLResponse * _Nonnull response, NSError * _Nonnull error))failure;

/**
 Enqueues a request to check the server to know the kind of authentication needed.
 
 @param path The path of the server.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with no arguments.
 @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and the network error that occurred.
 */
- (void)checkServer:(NSString * _Nonnull)path onCommunication:
(OCCommunication * _Nonnull)sharedOCCommunication
            success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
            failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

/**
 Enqueues a request to creates a directory using a `MKCOL` request for the specified path.
 
 @param path The path for which to create a directory.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with no arguments.
 @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and the network error that occurred.
 */
- (void)makeCollection:(NSString * _Nonnull)path
       onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
               success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
               failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

/**
 Creates an `NSURLSessionUploadTask` with the specified request for a local file.
 
 @param localSource is a string with the path of the file to upload
 @param remoteDestination A remote path, relative to the HTTP client's base URL, to write the data to.
 @param progress A progress object monitoring the current upload progress.
 @param success A block callback, to be fired upon successful completion, with NSURLResponse and string of redirected server.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 *
 @warning NSURLSession and NSRULSessionUploadTask only can be supported in iOS 7.
 */
- (NSURLSessionUploadTask * _Nonnull)putWithSessionLocalPath:(NSString * _Nonnull)localSource atRemotePath:(NSString * _Nonnull)remoteDestination onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication progress:(void(^ _Nonnull)(NSProgress * _Nonnull progress))uploadProgress success:(void(^ _Nonnull)(NSURLResponse * _Nonnull, NSString * _Nonnull))success failure:(void(^ _Nonnull)(NSURLResponse * _Nonnull, id _Nonnull, NSError * _Nonnull))failure failureBeforeRequest:(void(^ _Nonnull)(NSError * _Nonnull)) failureBeforeRequest;

///-----------------------------------
/// @name requestForUserNameByCookie
///-----------------------------------

/**
 * Method to obtain the User name by the cookie of the session
 *
 * @param NSString the cookie of the session
 *
 */
- (void) requestUserNameOfServer:(NSString * _Nonnull) path byCookie:(NSString * _Nonnull) cookieString onCommunication:
(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;


///-----------------------------------
/// @name Get status of the server
///-----------------------------------

/**
 * Method to get the json of the status.php common in the ownCloud servers
 *
 * @param serverPath -> url of the server
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 *
 */
- (void) getStatusOfTheServer:(NSString * _Nonnull)serverPath onCommunication:
(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull responseObject))success
                      failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name Get All the shared files and folders of a server
///-----------------------------------

/**
 Method to get all the shared files fo an account by the server path and api
 
 @param serverPath -> The url of the server including the path of the Share API.
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a dictionary with the properties of the directory and its contents.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 */
- (void)listSharedByServer:(NSString * _Nonnull)serverPath
 onCommunication: (OCCommunication * _Nonnull)sharedOCCommunication
         success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull responseObject))success
         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;


///-----------------------------------
/// @name Get All the shared files and folders of concrete folder
///-----------------------------------

/**
 Method to get all the shared files fo an account by the server path and api
 
 @param serverPath -> The url of the server including the path of the Share API.
 @param path -> The path of the folder that we want to know the shared
 @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a dictionary with the properties of the directory and its contents.
 @param failure A block callback, to be fired upon the failure of either the request or the parsing of the request's data, with two arguments: the request operation and the network or parsing error that occurred.
 */
- (void)listSharedByServer:(NSString * _Nonnull)serverPath andPath:(NSString * _Nonnull) path
           onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                   success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                   failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name shareFileOrFolderByServer 
///-----------------------------------

/**
 * Method to share a file or folder with password
 *
 * @param serverPath -> NSString: Server path where we want to share a file or folder. Ex: http://10.40.40.20/owncloud/ocs/v1.php/apps/files_sharing/api/v1/shares
 * @param filePath -> NSString: Path of the server where is the file. Ex: /File.pdf
 * @param password -> NSString: Password
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 *
 */
- (void)shareByLinkFileOrFolderByServer:(NSString * _Nonnull)serverPath andPath:(NSString * _Nonnull) filePath andPassword:(NSString * _Nonnull)password
                        onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                                success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                                failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name shareFileOrFolderByServer
///-----------------------------------

/**
 * Method to share a file or folder
 *
 * @param serverPath -> NSString: Server path where we want to share a file or folder. Ex: http://10.40.40.20/owncloud/ocs/v1.php/apps/files_sharing/api/v1/shares
 * @param filePath -> NSString: Path of the server where is the file. Ex: /File.pdf
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 *
 */
- (void)shareByLinkFileOrFolderByServer:(NSString * _Nonnull)serverPath andPath:(NSString * _Nonnull) filePath
                  onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                          success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                          failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;


///-----------------------------------
/// @name shareWith
///-----------------------------------

/**
 * Method to share a file or folder with user and group
 *
 * @param userOrGroup -> NSString: user or group (You can get the shares id in the calls searchUsersAndGroupsWith....)
 * @param shareeType -> NSInteger: to set the type of sharee (user/group/federated)
 * @param serverPath -> NSString: Server path where we want to share a file or folder. Ex: http://10.40.40.20/owncloud/ocs/v2.php/apps/files_sharing/api/v1/sharees?format=json
 * @param filePath -> NSString: Path of the server where is the file. Ex: /File.pdf
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 *
 */
- (void)shareWith:(NSString * _Nonnull)userOrGroup shareeType:(NSInteger)shareeType inServer:(NSString * _Nonnull) serverPath andPath:(NSString * _Nonnull) filePath andPermissions:(NSInteger) permissions onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
          success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
          failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name unShareFileOrFolderByServer
///-----------------------------------

/**
 * Method to unshare a file or folder
 *
 * @param serverPath -> NSString: Server path with the id of the file or folder that we want to unshare Ex: http://10.40.40.20/owncloud/ocs/v1.php/apps/files_sharing/api/v1/shares/44
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 */
- (void)unShareFileOrFolderByServer:(NSString * _Nonnull)serverPath
                    onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                            success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                            failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name isShareFileOrFolderByServer
///-----------------------------------

/**
 * Method to know if a share item still shared
 *
 * @param serverPath -> NSString: Server path with the id of the file or folder that we want know if is shared Ex: http://10.40.40.20/owncloud/ocs/v1.php/apps/files_sharing/api/v1/shares/44
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 */
- (void)isShareFileOrFolderByServer:(NSString * _Nonnull)serverPath
                    onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                            success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success
                            failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name updateShareItem
///-----------------------------------

/**
 * Method to update a share link
 *
 * @param shareId -> NSInterger: Share id (You can get the shares id in the calls listSharedByServer....)
 * @param serverPath -> NSString: Server path with the id of the file or folder that we want know if is shared Ex: http://10.40.40.20/owncloud/ocs/v1.php/apps/files_sharing/api/v1/shares/44
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 */
- (void) updateShareItem:(NSInteger)shareId ofServerPath:(NSString * _Nonnull)serverPath withPasswordProtect:(NSString * _Nonnull)password andExpirationTime:(NSString * _Nonnull)expirationTime andPermissions:(NSInteger)permissions
         onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication
                 success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success
                 failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name searchUsersAndGroupsWith
///-----------------------------------

/**
 * Method to search users or groups
 *
 * @param searchString -> NSString: Search string
 * @param serverPath -> NSString: Server path with the id of the file or folder that we want know if is shared Ex: http://10.40.40.20/owncloud/ocs/v2.php/apps/files_sharing/api/v1/sharees?format=json
 * @param page -> NSInteger: Number of page of the results (pagination support)
 * @param resultsPerPage -> NSInteger: Number of results per page (pagination support)
 * @param sharedOCCommunication Singleton of communication to add the operation on the queue.
 * @param success A block callback, to be fired upon successful completion, with two arguments: the request operation and a data with the json file.
 * @param failure A block callback, to be fired upon the failure of the request, with two arguments: the request operation and error.
 */
- (void) searchUsersAndGroupsWith:(NSString * _Nonnull)searchString forPage:(NSInteger)page with:(NSInteger)resultsPerPage ofServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication
                          success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success
                          failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name Get the server capabilities
///-----------------------------------

/**
 * Method read the capabilities of the server
 *
 * @param serverPath  -> NSString server
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return capabilities -> OCCapabilities
 *
 */
- (void) getCapabilitiesOfServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success
                         failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;


#pragma mark - Remote thumbnails

///-----------------------------------
/// @name Get the thumbnail for a file
///-----------------------------------

/**
 * Method to get the remote thumbnail for a file
 *
 * @param serverPath   -> NSString server
 * @param filePath     -> NSString file path
 * @param fileWidth    -> NSInteger with the width size
 * @param fileHeight   -> NSInteger with the height size
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return nsData -> thumbnail of the file with the size requested
 *
 */
- (OCHTTPRequestOperation * _Nonnull) getRemoteThumbnailByServer:(NSString * _Nonnull)serverPath ofFilePath:(NSString * _Nonnull)filePath  withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight onCommunication:(OCCommunication * _Nonnull)sharedOCComunication
                            success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success
                            failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

#pragma mark - Notification

///-----------------------------------
/// @name Get the server Notification
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return listOfNotifications  -> OCNotification
 *
 */

- (void) getNotificationServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name set server Notification
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param type                  -> NSString "POST" "DELETE"
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */

- (void)setNotificationServer:(NSString * _Nonnull)serverPath type:(NSString * _Nonnull)type onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name Subscribing at the Nextcloud server
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param type                  -> NSString "POST" "DELETE"
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */

- (void)subscribingNextcloudServerPush:(NSString * _Nonnull)serverPath authorizationToken:(NSString * _Nonnull)authorizationToken pushTokenHash:(NSString * _Nonnull)pushTokenHash devicePublicKey:(NSString * _Nonnull)devicePublicKey proxyServerPath:(NSString * _Nonnull)proxyServerPath onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;


- (void)subscribingPushProxy:(NSString * _Nonnull)serverPath authorizationToken:(NSString * _Nonnull)authorizationToken pushToken:(NSString * _Nonnull)pushToken deviceIdentifier:(NSString * _Nonnull)deviceIdentifier deviceIdentifierSignature:(NSString * _Nonnull)deviceIdentifierSignature userPublicKey:(NSString * _Nonnull)userPublicKey onCommunication:(OCCommunication * _Nonnull)sharedOCCommunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id _Nonnull))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull, id  _Nullable responseObject, NSError * _Nonnull))failure;

///-----------------------------------
/// @name Get the server Notification
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return listOfActivity       -> OCActivity
 *
 */

- (void) getActivityServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name Get the list of External sites
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return listOfExternalSites  -> OCExternalSites
 *
 */

- (void) getExternalSitesServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

///-----------------------------------
/// @name Get User Profile
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return userProfile          -> OCUserProfile
 *
 */

- (void) getUserProfileServer:(NSString * _Nonnull)serverPath onCommunication:(OCCommunication * _Nonnull)sharedOCComunication success:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id _Nonnull response))success failure:(void(^ _Nonnull)(NSHTTPURLResponse * _Nonnull operation, id  _Nullable responseObject, NSError * _Nonnull error))failure;

@end

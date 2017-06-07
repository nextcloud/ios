//
//  OCCommunication.h
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

#import <Foundation/Foundation.h>

@class OCHTTPRequestOperation;
@class AFURLSessionManager;
@class AFSecurityPolicy;
@class OCCapabilities;
@class OCUserProfile;

@interface OCCommunication : NSObject

//Type of credential
typedef enum {
    credentialNotSet = -1,
    credentialNormal = 0, //user, password
    credentialCookie = 1,
    credentialOauth = 2
} kindOfCredentialEnum;


typedef enum {
    OCErrorUnknow = 90, //On all errors
    OCErrorForbidenCharacters = 100, //On create folder and rename
    OCErrorMovingDestinyNameHaveForbiddenCharacters = 110,//On move file or folder
    OCErrorMovingTheDestinyAndOriginAreTheSame = 111, //On move file or folder
    OCErrorMovingFolderInsideHimself = 112, //On move file or folder
    OCErrorFileToUploadDoesNotExist = 120 //The file that we want upload does not exist
} OCErrorEnum;

//Private properties
@property NSInteger kindOfCredential;
@property (nonatomic, strong) NSString *user;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, strong) NSString *userAgent;

//Public properties
@property (nonatomic, strong) NSMutableArray *downloadTaskNetworkQueueArray;

@property (nonatomic, strong) AFURLSessionManager *uploadSessionManager;
@property (nonatomic, strong) AFURLSessionManager *downloadSessionManager;
@property (nonatomic, strong) AFURLSessionManager *networkSessionManager;
@property (nonatomic, strong) AFSecurityPolicy * securityPolicy;

/*This flag control the use of cookies on the requests.
 -On OC6 the use of cookies limit to one request at the same time. So if we want to do several requests at the same time you should set this as NO (by default).
 -On OC7 we can do several requests at the same time with the same session so you can set this flag to YES.
 */
@property BOOL isCookiesAvailable;

/* This flag indicate if the server handling forbidden characters */
@property BOOL isForbiddenCharactersAvailable;



///-----------------------------------
/// @name Init with Upload Session Manager
///-----------------------------------

/**
 * Method to init the OCCommunication with a AFURLSessionManager (upload session) to receive the SSL callbacks to support Self Signed servers
 *
 * @param uploadSessionManager -> AFURLSessionManager
 */
-(id) initWithUploadSessionManager:(AFURLSessionManager *) uploadSessionManager;


/**
 * Method to init the OCCommunication with a AFURLSessionManager (uploads and downloads sessions) to receive the SSL callbacks to support Self Signed servers
 *
 * @param uploadSessionManager -> AFURLSessionManager
 * @param downloadSessionManager -> AFURLSessionManager
 *
 */
-(id) initWithUploadSessionManager:(AFURLSessionManager *) uploadSessionManager andDownloadSessionManager:(AFURLSessionManager *) downloadSessionManager andNetworkSessionManager:(AFURLSessionManager *) networkSessionManager;


- (AFSecurityPolicy *) createSecurityPolicy;
- (void)setSecurityPolicyManagers:(AFSecurityPolicy *)securityPolicy;


#pragma mark - Credentials

///-----------------------------------
/// @name Set Credential With User
///-----------------------------------

/**
 * Method to set credentials with user and password
 *
 * @param user -> NSString username
 * @param password -> NSString password
 */
- (void) setCredentialsWithUser:(NSString*) user andPassword:(NSString*) password;


///-----------------------------------
/// @name Set Credential with cookie
///-----------------------------------

/**
 * Method that set credentials with cookie.
 * Used for SAML servers.
 *
 * @param cookie -> NSString cookie string
 */
- (void) setCredentialsWithCookie:(NSString*) cookie;


///-----------------------------------
/// @name Set Credential with OAuth
///-----------------------------------

/**
 * Method to set credentials for OAuth with token
 *
 * @param token -> NSString token
 */
- (void) setCredentialsOauthWithToken:(NSString*) token;

/**
 * @optional
 *
 * Method to set the user agent, in order to identify the client app to the server.
 *
 * @param userAgent -> String with the user agent. Ex. "iOS-ownCloud"
 */
- (void) setUserAgent:(NSString *)userAgent;


/*
 * Method to update the a request with the current credentials
 */
- (id) getRequestWithCredentials:(id) request;


#pragma mark - Network operations

///-----------------------------------
/// @name Check Server
///-----------------------------------

/**
 * Method to check if on the path exist a ownCloud server
 *
 * @param path -> NSString with the url of the server with
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @warning this method do not need set the Credentials before because with this method we can know the kind of authentication needed.
 *
 * @warning the "path" must not be on URL Encoding.
 * Ex:
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/
 *
 */
- (void) checkServer: (NSString *) path
     onCommunication:(OCCommunication *)sharedOCCommunication
      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name createFolder
///-----------------------------------

/**
 * Method to create a folder giving the full address where we want put the folder
 *
 * @param path -> NSString with the url where we want put the folder.
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @param isFCSupported -> From Owncloud 8.1 the forbidden characters are controller by the server except the '/'. With this flag
 * we controller if the server support forbbiden characters. To know that you can use "hasServerForbiddenCharactersSupport ..." request in this class.
 *
 * @warning remember that you must to set the Credentials before call this method or any other.
 *
 * @warning the "path" must not be on URL Encoding.
 * Ex:
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Pop Music/
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Pop%20Music/
 *
 * @warning the folder name must not contain the next forbidden characers: "\", "/","<",">",":",""","|","?","*"
 */

- (void) createFolder: (NSString *) path
      onCommunication:(OCCommunication *)sharedOCCommunication withForbiddenCharactersSupported:(BOOL)isFCSupported
       successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
       failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest
   errorBeforeRequest:(void(^)(NSError *error)) errorBeforeRequest;


///-----------------------------------
/// @name moveFileOrFolder
///-----------------------------------

/**
 * Method to move or rename a file/folder
 *
 * MOVE
 * @param sourcePath -> NSString with the url of the file or folder that you want move
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 * @param destinyPath -> NSString with the new url where we cant move the file or folder
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other Folder/Music
 *
 * RENAME
 * @param sourcePath -> NSString with the url of the file or folder that you want move
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 * @param destinyPath -> NSString with the new url where we cant move the file or folder
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Movies
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @param isFCSupported -> From Owncloud 8.1 the forbidden characters are controller by the server except the '/'. With this flag
 * we controller if the server support forbbiden characters. To know that you can use "hasServerForbiddenCharactersSupport ..." request in this class.
 *
 * @warning the move will overwritte an existing file on the destiny.
 *
 * @warning remember that you must to set the Credentials before call this method or any other.
 *
 * @warning the "sourcePath" and "destinyPath" must not be on URL Encoding.
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other Folder/Music
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other%20Folder/Music
 *
 * @warning: to move a folder the "sourcePath" and "destinyPath" must end on "/" character
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music/
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 *
 * @warning: to move a file the "sourcePath" and "destinyPath" must not end on "/" character
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music.mp3
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music.mp3/
 */

- (void) moveFileOrFolder:(NSString *)sourcePath
                toDestiny:(NSString *)destinyPath
          onCommunication:(OCCommunication *)sharedOCCommunication withForbiddenCharactersSupported:(BOOL)isFCSupported
           successRequest:(void (^)(NSHTTPURLResponse *response, NSString *redirectServer))successRequest
           failureRequest:(void (^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failureRequest
       errorBeforeRequest:(void (^)(NSError *error))errorBeforeRequest;



///-----------------------------------
/// @name Read Folder
///-----------------------------------

/**
 * Block to get the list of files/folders for a path
 *
 * @param path -> NSString with the url of the path
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 *
 * @param token -> User Session token. To get this token you should be use "getUserSessionToken" method of UtilsFramework class
 *  We use this token to be sure that the callbacks of the request are for the correct user. We need that when we use multiaccount.
 *  if not you can leave as nil.
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @warning the "path" must not be on URL Encoding.
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other Folder/Music
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other%20Folder/Music
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */
- (void) readFolder: (NSString *) path withUserSessionToken:(NSString *)token
    onCommunication:(OCCommunication *)sharedOCCommunication
     successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest
     failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest;



///-----------------------------------
/// @name Read File
///-----------------------------------

/**
 * Block to get the unique file/folder of a path. Used to get the properties of the file.
 *
 * @param path -> NSString with the url of the path
 * Ex: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Music
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @warning the "path" must not be on URL Encoding.
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other Folder/Music
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other%20Folder/Music
 *
 */
- (void) readFile: (NSString *) path
  onCommunication:(OCCommunication *)sharedOCCommunication
   successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer)) successRequest
   failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;


///-----------------------------------
/// @name Delete a file or a folder
///-----------------------------------

/**
 * This method delete a file or a folder
 *
 * @param path -> NSString with the url of the file or the folder that the user want to delete
 * Ex:http://www.myowncloudserver.com/owncloud/remote.php/webdav/Folder
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @warning the "path" must not be on URL Encoding.
 * Correct path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other Folder/Music
 * Wrong path: http://www.myowncloudserver.com/owncloud/remote.php/webdav/Other%20Folder/Music
 *
 * @warning remember that you must to set the Credentials before call this method or any other.
 *
 */
- (void) deleteFileOrFolder:(NSString *)path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void (^)(NSHTTPURLResponse *response, NSString *redirectedServer))successRequest
              failureRquest:(void (^)(NSHTTPURLResponse *resposne, NSError *error, NSString *redirectedServer))failureRequest;

///-----------------------------------
/// @name Download File Session
///-----------------------------------

/**
 * Method to download a file. All the files will be download one by one in a queue. The files download also in background when the system close the app.
 *
 * This method download a file of a path and returns blocks
 *
 * progress: get the download inputs about the progress of the download
 * successRequest: the download it's complete
 * failureRequest: the download fail
 *
 * @param NSString -> remotePath the path of the file
 * @param NSString -> localPath the  local path where we want store the file
 * @param BOOL -> defaultPriority define if the priority is defined by the library (default) or not. It used to manage multiple downloads from the app.
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return NSURLSessionDownloadTask -> You can cancel the download using this object
 * Ex: [downloadTask cancel]
 *
 * @warning remember that you must to set the Credentials before call this method or any other.
 *
 * @warning this method use NSURLSession only supported in iOS 7, with iOS 6 use the previous method
 *
 */

- (NSURLSessionDownloadTask *) downloadFileSession:(NSString *)remotePath toDestiny:(NSString *)localPath defaultPriority:(BOOL)defaultPriority onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))downloadProgress successRequest:(void(^)(NSURLResponse *response, NSURL *filePath)) successRequest failureRequest:(void(^)(NSURLResponse *response, NSError *error)) failureRequest;

///-----------------------------------
/// @name Set Download Task Complete Block
///-----------------------------------

/**
 *
 * Method to set the callbak block of the pending download background tasks.
 *
 * @param block A block object to be executed when a session task is completed. The block should be return the location where the download must be stored, and takes three arguments: the session, the download task, and location where is stored the file.
 *
 */

- (void)setDownloadTaskComleteBlock: (NSURL * (^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, NSURL *location))block;


///-----------------------------------
/// @name Set Download Task Did Get Body Data Block
///-----------------------------------

/**
 * Sets a block that get callbacks of the NSURLDownloadSessionTask progress
 *
 * @param block A block object to be called when an undetermined number of bytes have been downloaded from the server. This block has no return value and takes four arguments: the session, the download task, the number of the bytes read, the total bytes expected to read. This block may be called multiple times, and will execute on the main thread.
 */

- (void) setDownloadTaskDidGetBodyDataBlock: (void(^)(NSURLSession *session, NSURLSessionDownloadTask *downloadTask, int64_t bytesWritten, int64_t totalBytesWritten, int64_t totalBytesExpectedToWrite)) block;

///-----------------------------------
/// @name Upload File
///-----------------------------------

/**
 * Method to upload a file. All the files will be upload one by one in a queue. The files upload also in background when the system close the app.
 *
 * This method download a file of a path and returns blocks
 *
 * progress: get the download inputs about the progress of the download
 * successRequest: the download it's complete
 * failureRequest: the download fail
 * failureBeforeRequest: the download fail
 *
 * @param NSString -> localPath the path where is the file that we want upload
 * @param NSString -> remotePath the path where we want upload the file
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return NSURLSessionUploadTask -> You can cancel the upload using this object
 * Ex: [uploadTask cancel]
 *
 * @warning remember that you must to set the Credentials before call this method or any other.
 *
 * @warning this method use NSURLSession only supported in iOS 7, with iOS 6 use the previous method
 *
 */

- (NSURLSessionUploadTask *) uploadFileSession:(NSString *) localPath toDestiny:(NSString *) remotePath onCommunication:(OCCommunication *)sharedOCCommunication progress:(void(^)(NSProgress *progress))uploadProgress successRequest:(void(^)(NSURLResponse *response, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSURLResponse *response, NSString *redirectedServer, NSError *error)) failureRequest failureBeforeRequest:(void(^)(NSError *error)) failureBeforeRequest;


///-----------------------------------
/// @name Set Task Did Complete Block
///-----------------------------------


/**
 *
 * Method to set the callbaks block of the pending background tasks.
 *
 * @param block A block object to be executed when a session task is completed. The blockhas not return value, and takes three arguments: the session, the task, and any error that occurred in the process of executing the task.
 *
 */

- (void) setTaskDidCompleteBlock: (void(^)(NSURLSession *session, NSURLSessionTask *task, NSError *error)) block;


///-----------------------------------
/// @name Set Task Did Send Body Data Block
///-----------------------------------

/**
 * Sets a block that get callbacks of the NSURLSessionTask progress
 *
 * @param block A block object to be called when an undetermined number of bytes have been uploaded to the server. This block has no return value and takes five arguments: the session, the task, the number of bytes written since the last time the upload progress block was called, the total bytes written, and the total bytes expected to be written during the request, as initially determined by the length of the HTTP body. This block may be called multiple times, and will execute on the main thread.
 */
- (void) setTaskDidSendBodyDataBlock: (void(^)(NSURLSession *session, NSURLSessionTask *task, int64_t bytesSent, int64_t totalBytesSent, int64_t totalBytesExpectedToSend)) block;


///-----------------------------------
/// @name Search
///-----------------------------------

- (void)search:(NSString *)path folder:(NSString *)folder fileName:(NSString *)fileName depth:(NSString *)depth dateLastModified:(NSString *)dateLastModified withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name Setting favorite
///-----------------------------------

- (void)settingFavoriteServer:(NSString *)path andFileOrFolderPath:(NSString *)filePath favorite:(BOOL)favorite withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name Listing favorites
///-----------------------------------

- (void)listingFavorites:(NSString *)path folder:(NSString *)folder withUserSessionToken:(NSString *)token onCommunication:(OCCommunication *)sharedOCCommunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer)) failureRequest;


#pragma mark - OC API Calls

///-----------------------------------
/// @name getCurrentServerVersion
///-----------------------------------

/**
 * Method to get the current version without request if this feature has been checked by other request as: getServerVersionWithPath,
 * hasServerShareSupport, hasServerCookiesSupport and hasServerForbiddenCharactersSupport methods
 *
 * @return serverVersion as NSString.
 */

- (NSString *) getCurrentServerVersion;

///-----------------------------------
/// @name getServerVersionWithPath
///-----------------------------------

/**
 * Method to get the current version of a server. This method update the currentServerVersion property of the class
 *
 *
 * @param path -> NSString server path
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return serverVersion as NSString.
 */

- (void) getServerVersionWithPath:(NSString*) path onCommunication:(OCCommunication *)sharedOCCommunication
                   successRequest:(void(^)(NSHTTPURLResponse *response, NSString *serverVersion, NSString *redirectedServer)) success
                   failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failure;

///-----------------------------------
/// @name requestForUserNameByCookie
///-----------------------------------

/**
 * Method to get the User name by the cookie of the session. Used with SAML servers.
 *
 * @param cookieString -> NSString The cookie of the session
 *
 * @param path -> NSString server path
 *
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 */


- (void) getUserNameByCookie:(NSString *) cookieString ofServerPath:(NSString *)path onCommunication:
(OCCommunication *)sharedOCCommunication success:(void(^)(NSHTTPURLResponse *response, NSData *responseData, NSString *redirectedServer))success
                     failure:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failure;

///-----------------------------------
/// @name Get Features Supported By Server
///-----------------------------------

/**
 * Method get the features supported by the path server using the version string.
 *
 * Right now support:
 * - Share API
 * - Sharee API
 * - Cookies
 * - Forbidden character manage by the server side
 * - Capabilities
 *
 * @param path -> NSString server path
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return BOOL in the success about the support of Share (hasShareSupport) ,Sharee (hasShareeSupport) APIs,
 * Cookies (hasCookiesSupport), Forbidden character (hasForbiddenCharactersSupport) and Capabilities (hasCapabilitiesSupport)
 *
 */

- (void) getFeaturesSupportedByServer:(NSString*) path onCommunication:(OCCommunication *)sharedOCCommunication
                       successRequest:(void(^)(NSHTTPURLResponse *response, BOOL hasShareSupport, BOOL hasShareeSupport, BOOL hasCookiesSupport, BOOL hasForbiddenCharactersSupport, BOOL hasCapabilitiesSupport, BOOL hasFedSharesOptionShareSupport, NSString *redirectedServer)) success
                       failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failure;



///-----------------------------------
/// @name readSharedByServer
///-----------------------------------

/**
 * Method to return all the files and folders shareds on the server by the current user
 *
 * @param path -> NSString server path
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return NSArray with all the OCSharedDto of shareds files
 *
 */
- (void) readSharedByServer: (NSString *) path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfShared, NSString *redirectedServer)) successRequest
             failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name readSharedByServer
///-----------------------------------

/**
 * Method to return the files and folders shareds on a concrete path by the current user
 *
 * @param serverPath -> NSString server path
 * @param path -> Path of the folder that we want to know that shareds that contain
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return NSArray with all the OCSharedDto of shareds files
 *
 */
- (void) readSharedByServer: (NSString *) serverPath andPath: (NSString *) path
            onCommunication:(OCCommunication *)sharedOCCommunication
             successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfShared, NSString *redirectedServer)) successRequest
             failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name shareFileOrFolderByServer 
///-----------------------------------

/**
 * Method to share a file or folder with password
 *
 * @param serverPath -> NSString server path
 * @param filePath -> path of the file that we want to share. Ex: /file.pdf <- If the file is on the root folder
 * @param password -> password
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return shareLink or token of the file that we shared. URL or Ex:572d48de3814c90117fbca6442f2f3b2
 *
 * @warning to create the full URL to share the file on a link we have to atatch the token to: http://www.myowncloudserver.com/public.php?service=files&t=572d48de3814c90117fbca6442f2f3b2
 */
- (void) shareFileOrFolderByServer: (NSString *) serverPath andFileOrFolderPath: (NSString *) filePath andPassword:(NSString *)password
                   onCommunication:(OCCommunication *)sharedOCCommunication
                    successRequest:(void(^)(NSHTTPURLResponse *response, NSString *token, NSString *redirectedServer)) successRequest
                    failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;



///-----------------------------------
/// @name shareFileOrFolderByServer
///-----------------------------------

/**
 * Method to share a file or folder
 *
 * @param serverPath -> NSString server path
 * @param filePath -> path of the file that we want to share. Ex: /file.pdf <- If the file is on the root folder
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return shareLink or token of the file that we shared. URL or Ex:572d48de3814c90117fbca6442f2f3b2
 *
 * @warning to create the full URL to share the file on a link we have to atatch the token to: http://www.myowncloudserver.com/public.php?service=files&t=572d48de3814c90117fbca6442f2f3b2
 */
- (void) shareFileOrFolderByServer: (NSString *) serverPath andFileOrFolderPath: (NSString *) filePath
                   onCommunication:(OCCommunication *)sharedOCCommunication
                    successRequest:(void(^)(NSHTTPURLResponse *response, NSString *shareLink, NSString *redirectedServer)) successRequest
                    failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest ;



///-----------------------------------
/// @name shareWith
///-----------------------------------

/**
 * Method to share a file or folder with user or group
 *
 * @param userOrGroup -> NSString user or group name
 * @param shareeType -> NSInteger: to set the type of sharee (user/group/federated)
 * @param serverPath -> NSString server path
 * @param filePath -> path of the file that we want to share. Ex: /file.pdf <- If the file is on the root folder
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return request response, error if exists and redirected server if exist.
 *
 * @warning to create the full URL to share the file on a link we have to atatch the token to: http://www.myowncloudserver.com/public.php?service=files&t=572d48de3814c90117fbca6442f2f3b2
 */
- (void)shareWith:(NSString *)userOrGroup shareeType:(NSInteger)shareeType inServer:(NSString *) serverPath andFileOrFolderPath:(NSString *) filePath andPermissions:(NSInteger) permissions onCommunication:(OCCommunication *)sharedOCCommunication
   successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer))successRequest
   failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer))failureRequest;

///-----------------------------------
/// @name unShareFileOrFolderByServer
///-----------------------------------

/**
 * Method to share a file or folder
 *
 * @param path -> NSString server path
 * @param idRemoteShared -> id number of the shared. Value obtained on the idRemoteSHared of OCSharedDto
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */
- (void) unShareFileOrFolderByServer: (NSString *) path andIdRemoteShared: (NSInteger) idRemoteShared
                     onCommunication:(OCCommunication *)sharedOCCommunication
                      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
                      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name isShareFileOrFolderByServer
///-----------------------------------

/**
 * Method to know if a share item still shared
 *
 * @param path -> NSString server path
 * @param idRemoteShared -> id number of the shared. Value obtained on the idRemoteSHared of OCSharedDto
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */
- (void) isShareFileOrFolderByServer: (NSString *) path andIdRemoteShared: (NSInteger) idRemoteShared
                     onCommunication:(OCCommunication *)sharedOCCommunication
                      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer, BOOL isShared, id shareDto)) successRequest
                      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name UpdteShared
///-----------------------------------

/**
 * Method to update a shared file with password and expiration time
 *
 * @param shareID -> NSInteger share id, you can get this data of these calls (readSharedByServer...)
 * @param serverPath -> NSString server path
 * @param filePath -> path of the file that we want to share. Ex: /file.pdf <- If the file is on the root folder
 * @param password -> password
 * @param permissions -> NSInteger 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all (default: 31, for public shares: 1)
 * @param expirationTime -> expirationTime in format "YYYY-MM-dd"
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return token of the file that we shared. Ex:572d48de3814c90117fbca6442f2f3b2
 *
 * @warning it only can be updated one parameter for each request so if you want to update the password the date must be nil and the permission 0
 * @warning to create the full URL to share the file on a link we have to atatch the token to: http://www.myowncloudserver.com/public.php?service=files&t=572d48de3814c90117fbca6442f2f3b2
 */
- (void) updateShare:(NSInteger)shareId ofServerPath:(NSString *)serverPath withPasswordProtect:(NSString*)password andExpirationTime:(NSString*)expirationTime andPermissions:(NSInteger)permissions
     onCommunication:(OCCommunication *)sharedOCCommunication
      successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest
      failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;


///-----------------------------------
/// @name Search Users And Groups
///-----------------------------------

/**
 * Method to get users and groups using a search string
 *
 * @param searchString -> NSString search string
 * @param page -> NInsteger: Number of page (pagination support)
 * @param resultsPerPage -> NSInteger: Number of results per page (pagination support)
 * @param serverPath -> NSString server path
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return itemList -> list of OCShareUser objects and default -> request response, error if exists and redirected server if exist
 *
 * @warning to create the full URL to share the file on a link we have to atatch the token to: http://www.myowncloudserver.com/public.php?service=files&t=572d48de3814c90117fbca6442f2f3b2
 */
- (void) searchUsersAndGroupsWith:(NSString *)searchString forPage:(NSInteger)page with:(NSInteger)resultsPerPage ofServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *itemList, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

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
- (void) getCapabilitiesOfServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;


#pragma mark - Remote thumbnails

///-----------------------------------
/// @name Get the thumbnail for a file
///-----------------------------------

/**
 * Method to get the remote thumbnail for a file
 *
 * In order to support thumbnails for videos it is necessary to install video package on the server 
 * and add the following lines in the config.php files
 *the following types on the config.php file
 *   'enabledPreviewProviders' => array(
 *      'OC\Preview\Movie'
 *      )
 *
 * @param serverPath   -> NSString server, without encoding
 * @param filePath     -> NSString file path, without encoding
 * @param fileWidth    -> NSInteger with the width size
 * @param fileHeight   -> NSInteger with the height size
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 * @return nsData -> thumbnail of the file with the size requested
 * @return NSURLSessionTask -> You can cancel the download using this object
 *
 */
- (NSURLSessionTask *) getRemoteThumbnailByServer:(NSString*)serverPath ofFilePath:(NSString *)filePath withWidth:(NSInteger)fileWidth andHeight:(NSInteger)fileHeight onCommunication:(OCCommunication *)sharedOCComunication
                     successRequest:(void(^)(NSHTTPURLResponse *response, NSData *thumbnail, NSString *redirectedServer)) successRequest
                     failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;


#pragma mark -  Server Notification

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

- (void) getNotificationServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfNotifications, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;


///-----------------------------------
/// @name Set the server Notification
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param type                  -> NSString "POST" "DELETE"
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */

- (void) setNotificationServer:(NSString*)serverPath type:(NSString *)type onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

///-----------------------------------
/// @name Subscribing at the Nextcloud server
///-----------------------------------

/**
 * Method subscribing at the Nextcloud server for the push
 *
 * @param serverPath            -> NSString server
 * @param pushTokenHash         -> NSString sha512 hash of the PushToken for Apple Push Notification Service
 * @param devicePublicKey       -> NSString devicePublicKey
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */

- (void)subscribingNextcloudServerPush:(NSString *)serverPath pushTokenHash:(NSString *)pushTokenHash devicePublicKey:(NSString *)devicePublicKey proxyServerPath:(NSString *)proxyServerPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void (^)(NSHTTPURLResponse *response, NSString *publicKey, NSString *deviceIdentifier, NSString *signature, NSString *redirectedServer))successRequest failureRequest:(void (^)(NSHTTPURLResponse *, NSError *, NSString *))failureRequest;

- (void)subscribingPushProxy:(NSString *)serverPath pushToken:(NSString *)pushToken deviceIdentifier:(NSString *)deviceIdentifier deviceIdentifierSignature:(NSString *)deviceIdentifierSignature userPublicKey:(NSString *)userPublicKey onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void (^)(NSHTTPURLResponse *response, NSString *redirectedServer)) successRequest failureRequest:(void (^)(NSHTTPURLResponse *, NSError *, NSString *))failureRequest;

#pragma mark -  Server Activity

///-----------------------------------
/// @name Get the server Activity
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

- (void) getActivityServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfActivity, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

#pragma mark -  External Sites

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

- (void) getExternalSitesServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, NSArray *listOfExternalSites, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

#pragma mark -  User Profile

///-----------------------------------
/// @name Get User Profile
///-----------------------------------

/**
 * Method read the notification of the server
 *
 * @param serverPath            -> NSString server
 * @param type                  -> NSString "GET"
 * @param sharedOCCommunication -> OCCommunication Singleton of communication to add the operation on the queue.
 *
 */

- (void) getUserProfileServer:(NSString*)serverPath onCommunication:(OCCommunication *)sharedOCComunication successRequest:(void(^)(NSHTTPURLResponse *response, OCUserProfile *userProfile, NSString *redirectedServer)) successRequest failureRequest:(void(^)(NSHTTPURLResponse *response, NSError *error, NSString *redirectedServer)) failureRequest;

@end




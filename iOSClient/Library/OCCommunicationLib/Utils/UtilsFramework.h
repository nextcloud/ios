//
//  UtilsFramework.h
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

#import <Foundation/Foundation.h>

@interface UtilsFramework : NSObject


/*
 * Method that return a unique Id. 
 * The global ID for the process includes the host name, process ID, and a time stamp, 
 * which ensures that the ID is unique for the network
 * @return -> Unique Id (token)
 */
+ (NSString *) getUserSessionToken;


/*
 * Method that check the file name or folder name to find forbidden characters
 * This is the forbidden characters in server: "\", "/","<",">",":",""","|","?","*"
 * @fileName -> file name
 *
 * @isFCSupported -> From ownCloud 8.1 the forbidden characters are controller by the server except the '/'
 */
+ (BOOL) isForbiddenCharactersInFileName:(NSString*)fileName withForbiddenCharactersSupported:(BOOL)isFCSupported;

/*
 * Get error code with the errorCode and message of the server
 *
 */

+ (NSError *) getErrorWithCode:(NSInteger)errorCode andCustomMessageFromTheServer:(NSString *)message;


/*
 * Get error for the same errors in the share api
 *
 * Statuscodes:
 * 100 - successful
 * 400 - wrong or no update parameter given
 * 403 - public upload disabled by the admin
 * 404 - couldn’t update share
 *
 */

+ (NSError *) getShareAPIErrorByCode:(NSInteger)errorCode;

///-----------------------------------
/// @name getErrorByCodeId
///-----------------------------------

/**
 * Method to return a NSError based on the Error Code Enum
 *
 * @param int errorCode to Enum to identify the error code
 *
 * @return NSError
 */
+ (NSError *) getErrorByCodeId:(int) errorCode;

///-----------------------------------
/// @name getFileNameOrFolderByPath
///-----------------------------------

/**
 * Method that return a filename from a path
 *
 * @param NSString -> path of the file (including the file)
 *
 * @return NSString -> fileName
 *
 */
+ (NSString *) getFileNameOrFolderByPath:(NSString *) path;

/*
 * Method that return a boolean that indicate if is the same url
 */
+ (BOOL) isTheSameFileOrFolderByNewURLString:(NSString *) newURLString andOriginURLString:(NSString *)  originalURLString;

/*
 * Method that return a boolean that indicate if newUrl is under the original Url
 */
+ (BOOL) isAFolderUnderItByNewURLString:(NSString *) newURLString andOriginURLString:(NSString *)  originalURLString;

/**
 * Method to return the size of a file by a path
 *
 * @param NSString -> path of the file
 *
 * @return long long -> size of the file in the path
 */
+ (long long) getSizeInBytesByPath:(NSString *) path;


///-----------------------------------
/// @name isURLWithSamlFragment:
///-----------------------------------

/**
 * Method to check a url string to looking for a SAML fragment
 *
 * @param urlString -> url from redirect server
 *
 * @return BOOL -> the result about if exist the SAML fragment or not
 */
+ (BOOL) isURLWithSamlFragment:(NSString*)urlString;

///-----------------------------------
/// @name AFBase64EncodedStringFromString:
///-----------------------------------

/**
 * Method encode a string to base64 in order to set the credentials
 *
 * @param string -> string to be encoding
 *
 * @return NSString -> the result of the encoded string
 */
+ (NSString *) AFBase64EncodedStringFromString:(NSString *) string;

//-----------------------------------
/// @name addCookiesToStorageFromResponse
///-----------------------------------

#pragma mark - Manage Cookies

/**
 * Method to storage all the cookies from a response in order to use them in future requests
 *
 * @param NSHTTPURLResponse -> response
 * @param NSURL -> url
 *
 */
+ (void) addCookiesToStorageFromResponse: (NSURLResponse *) response andPath:(NSURL *) url;
//-----------------------------------
/// @name getRequestWithCookiesByRequest
///-----------------------------------

/**
 * Method to return a request with all the necessary cookies of the original url without redirection
 *
 * @param NSMutableURLRequest -> request
 * @param NSString -> originalUrlServer
 *
 * @return request
 *
 */
+ (NSMutableURLRequest *) getRequestWithCookiesByRequest: (NSMutableURLRequest *) request andOriginalUrlServer:(NSString *) originalUrlServer;

//-----------------------------------
/// @name deleteAllCookies
///-----------------------------------

/**
 * Method to clean the CookiesStorage
 *
 */
+ (void) deleteAllCookies;

//-----------------------------------
/// @name isServerVersionHigherThanLimitVersion
///-----------------------------------

/**
 * Method to detect if a server version is higher than a limit version.
 * This method is used for example to know if the server have share API or support Cookies
 *
 * @param NSString -> serverVersion
 * @param NSArray -> limitVersion
 *
 * @return BOOL
 *
 */
+ (BOOL) isServerVersion:(NSString *) serverVersionString higherThanLimitVersion:(NSArray *) limitVersion;

//-----------------------------------
/// @name getPermissionsValueByCanCreate
///-----------------------------------

/**
 * Method know the value of the permissions of a share file or folder.
 * This method is used to calculate the value of a permission parameter to share a file or document
 *
 * @param BOOL -> canEdit
 * @param BOOL -> canCreate
 * @param BOOL -> canChange
 * @param BOOL -> canDelete
 * @param BOOL -> canShare
 * @param BOOL -> isFolder
 *
 * @return NSInteger
 *
 */
+ (NSInteger) getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder;


//-----------------------------------
/// @name isPermissionToCanCreate
///-----------------------------------

/**
 * Method know if we have permission to create by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isPermissionToCanCreate:(NSInteger) permissionValue;

//-----------------------------------
/// @name isPermissionToCanChange
///-----------------------------------

/**
 * Method know if we have permission to Change by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isPermissionToCanChange:(NSInteger) permissionValue;

//-----------------------------------
/// @name isPermissionToCanDelete
///-----------------------------------

/**
 * Method know if we have permission to Delete by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isPermissionToCanDelete:(NSInteger) permissionValue;

//-----------------------------------
/// @name isPermissionToCanShare
///-----------------------------------

/**
 * Method know if we have permission to Share by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isPermissionToCanShare:(NSInteger) permissionValue;

//-----------------------------------
/// @name isAnyPermissionToEdit
///-----------------------------------

/**
 * Method to know if any permission related to edit (canCreate, canChange and canDelete) is active by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isAnyPermissionToEdit:(NSInteger) permissionValue;

//-----------------------------------
/// @name isPermissionToRead
///-----------------------------------

/**
 * Method to know if we have permission to Read by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */

+ (BOOL) isPermissionToRead:(NSInteger) permissionValue;

//---------------------------------------------------
/// @name isPermissionToReadCreateUpdate
///--------------------------------------------------

/**
 * Method to know if we have permissions to read,create and update by the permissionValue of the OCShareDto
 *
 * @param NSInteger -> permissionValue
 *
 * @return BOOL
 *
 */
+ (BOOL) isPermissionToReadCreateUpdate:(NSInteger) permissionValue;

@end

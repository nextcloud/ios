//
//  UtilsFramework.m
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


#import "UtilsFramework.h"
#import "OCCommunication.h"
#import "OCFrameworkConstants.h"
#import "OCErrorMsg.h"
#import "OCConstants.h"

#define kSAMLFragmentArray [NSArray arrayWithObjects: @"wayf", @"saml", @"sso_orig_uri", nil]

@implementation UtilsFramework

/*
 * Method that return a unique Id.
 * The global ID for the process includes the host name, process ID, and a time stamp,
 * which ensures that the ID is unique for the network
 * @return -> Unique Id (token)
 */
+ (NSString *) getUserSessionToken{
    
    return [[NSProcessInfo processInfo] globallyUniqueString];
}

/*
 * Method that check the file name or folder name to find forbidden characters
 * This is the forbidden characters in server: "\", "/","<",">",":",""","|","?","*"
 * @fileName -> file name
 *
 * @isFCSupported -> From ownCloud 8.1 the forbidden characters are controller by the server except the '/'
 */
+ (BOOL) isForbiddenCharactersInFileName:(NSString*)fileName withForbiddenCharactersSupported:(BOOL)isFCSupported{
    BOOL thereAreForbidenCharacters = NO;
    
    //Check the filename
    for(NSInteger i = 0 ;i<[fileName length]; i++) {
        
        if ([fileName characterAtIndex:i]=='/'){
            thereAreForbidenCharacters = YES;
        }
        
        if (!isFCSupported) {
            
            if ([fileName characterAtIndex:i] == '\\'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '<'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '>'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '"'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == ','){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == ':'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '|'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '?'){
                thereAreForbidenCharacters = YES;
            }
            if ([fileName characterAtIndex:i] == '*'){
                thereAreForbidenCharacters = YES;
            }
        }
 
    }
    
    return thereAreForbidenCharacters;
}

+ (NSError *) getErrorWithCode:(NSInteger)errorCode andCustomMessageFromTheServer:(NSString *)message {
    NSError *error = nil;
    
    NSMutableDictionary* details = [NSMutableDictionary dictionary];
    [details setValue:message forKey:NSLocalizedDescriptionKey];
    
    error = [NSError errorWithDomain:k_domain_error_code code:errorCode userInfo:details];

    return error;
}

/*
 * Get error for the same errors in the share api
 *
 * Statuscodes:
 * 100 - successful
 * 400 - wrong or no update parameter given
 * 403 - public upload disabled by the admin (or is neccesary put a password)
 * 404 - couldn’t update share
 *
 */

+ (NSError *) getShareAPIErrorByCode:(NSInteger)errorCode {
    NSError *error = nil;
    
    switch (errorCode) {
        case kOCErrorSharedAPIWrong:
        
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Wrong or no update parameter given" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:kOCErrorSharedAPIWrong userInfo:details];
            break;
        }
            
        case kOCErrorServerForbidden:
            
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Public upload disabled by the admin" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:kOCErrorServerForbidden userInfo:details];
            break;
        }
            
        case kOCErrorServerPathNotFound:
            
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Couldn't update share" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:kOCErrorServerPathNotFound userInfo:details];
            break;
        }
            
          
        default:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Unknow error" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorUnknow userInfo:details];
            break;
        }
    }
    
    return error;
    
}

///-----------------------------------
/// @name getErrorByCodeId
///-----------------------------------

/**
 * Method to return a Error with description from a OC Error code
 *
 * @param int -> errorCode number to identify the OC Error
 *
 * @return NSError
 *
 */
+ (NSError *) getErrorByCodeId:(int) errorCode {
    NSError *error = nil;
    
    switch (errorCode) {
        case OCErrorForbidenCharacters:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"You have entered forbbiden characters" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorForbidenCharacters userInfo:details];
            break;
        }
            
        case OCErrorMovingDestinyNameHaveForbiddenCharacters:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"The file or folder that you are moving have forbidden characters" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorMovingDestinyNameHaveForbiddenCharacters userInfo:details];
            break;
        }
            
        case OCErrorMovingTheDestinyAndOriginAreTheSame:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"You are trying to move the file to the same folder" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorMovingTheDestinyAndOriginAreTheSame userInfo:details];
            break;
        }
            
        case OCErrorMovingFolderInsideHimself:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"You are trying to move a folder inside himself" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorMovingFolderInsideHimself userInfo:details];
            break;
        }
            
        case kOCErrorServerPathNotFound:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"You are trying to access to a file that does not exist" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:kOCErrorServerPathNotFound userInfo:details];
            break;
        }
            
        case kOCErrorServerForbidden:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"You are trying to do a forbbiden operation" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:kOCErrorServerForbidden userInfo:details];
            break;
        }
            
        case OCServerErrorForbiddenCharacters:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Server said: File name contains at least one invalid character" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCServerErrorForbiddenCharacters userInfo:details];
            break;
        }
            
            
        default:
        {
            NSMutableDictionary* details = [NSMutableDictionary dictionary];
            [details setValue:@"Unknow error" forKey:NSLocalizedDescriptionKey];
            
            error = [NSError errorWithDomain:k_domain_error_code code:OCErrorUnknow userInfo:details];
            break;
        }
    }
    
    return error;
}

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
+ (NSString *) getFileNameOrFolderByPath:(NSString *) path {
    
    NSString *output;
    
    if (path && [path length] > 0) {
        NSArray *listItems = [path componentsSeparatedByString:@"/"];
        
        output = [listItems objectAtIndex:[listItems count]-1];
        
        if ([output length] <= 0) {
            output = [listItems objectAtIndex:[listItems count]-2];
        }
        
        //If is a folder we set the last character in order to compare folders with folders and files with files
        /*if([path hasSuffix:@"/"]) {
         output = [NSString stringWithFormat:@"%@/", output];
         }*/
    }
    
    return  output;
}

/*
 * Method that return a boolean that indicate if is the same url
 */
+ (BOOL) isTheSameFileOrFolderByNewURLString:(NSString *) newURLString andOriginURLString:(NSString *)  originalURLString{
    
    
    if ([originalURLString isEqualToString:newURLString]) {
        return YES;
    }
    
    return NO;
    
}

/*
 * Method that return a boolean that indicate if newUrl is under the original Url
 */
+ (BOOL) isAFolderUnderItByNewURLString:(NSString *) newURLString andOriginURLString:(NSString *)  originalURLString{
    
    if([originalURLString length] < [newURLString length]) {
        
        NSString *subString = [newURLString substringToIndex: [originalURLString length]];
        
        if([originalURLString isEqualToString: subString]){
            
            newURLString = [newURLString substringFromIndex:[subString length]];
            
            if ([newURLString rangeOfString:@"/"].location == NSNotFound) {
                //Is a rename of the last part of the file or folder
                return NO;
            } else {
                //Is a move inside himself
                return YES;
            }
        }
    }
    return NO;
    
}

///-----------------------------------
/// @name getSizeInBytesByPath
///-----------------------------------

/**
 * Method to return the size of a file by a path
 *
 * @param NSString -> path of the file
 *
 * @return long long -> size of the file in the path
 */
+ (long long) getSizeInBytesByPath:(NSString *)path {
    long long fileLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
    
    return fileLength;
}





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
+ (BOOL) isURLWithSamlFragment:(NSString*)urlString {
    
    urlString = [urlString lowercaseString];
    
    if (urlString) {
        for (NSString* samlFragment in kSAMLFragmentArray) {
            if ([urlString rangeOfString:samlFragment options:NSCaseInsensitiveSearch].location != NSNotFound) {
                NSLog(@"A SAML fragment is in the request url");
                return YES;
            }
        }
    }
    return NO;
}

+ (NSString *) AFBase64EncodedStringFromString:(NSString *) string {
    NSData *data = [NSData dataWithBytes:[string UTF8String] length:[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding]];
    NSUInteger length = [data length];
    NSMutableData *mutableData = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    
    uint8_t *input = (uint8_t *)[data bytes];
    uint8_t *output = (uint8_t *)[mutableData mutableBytes];
    
    for (NSUInteger i = 0; i < length; i += 3) {
        NSUInteger value = 0;
        for (NSUInteger j = i; j < (i + 3); j++) {
            value <<= 8;
            if (j < length) {
                value |= (0xFF & input[j]);
            }
        }
        
        static uint8_t const kAFBase64EncodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        
        NSUInteger idx = (i / 3) * 4;
        output[idx + 0] = kAFBase64EncodingTable[(value >> 18) & 0x3F];
        output[idx + 1] = kAFBase64EncodingTable[(value >> 12) & 0x3F];
        output[idx + 2] = (i + 1) < length ? kAFBase64EncodingTable[(value >> 6)  & 0x3F] : '=';
        output[idx + 3] = (i + 2) < length ? kAFBase64EncodingTable[(value >> 0)  & 0x3F] : '=';
    }
    
    return [[NSString alloc] initWithData:mutableData encoding:NSASCIIStringEncoding];
}

#pragma mark - Manage Cookies

//-----------------------------------
/// @name addCookiesToStorageFromResponse
///-----------------------------------

/**
 * Method to storage all the cookies from a response in order to use them in future requests
 *
 * @param NSHTTPURLResponse -> response
 * @param NSURL -> url
 *
 */
+ (void) addCookiesToStorageFromResponse: (NSURLResponse *) response andPath:(NSURL *) url {
    //TODO: Using NSURLSession this should not be necessary
    /*NSArray* cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[response allHeaderFields] forURL:url];
    
    for (NSHTTPCookie *current in cookies) {
        [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookie:current];
    }*/
}

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
+ (NSMutableURLRequest *) getRequestWithCookiesByRequest: (NSMutableURLRequest *) request andOriginalUrlServer:(NSString *) originalUrlServer {
    //We add the cookies of that URL
    NSArray *cookieStorage = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookiesForURL:[NSURL URLWithString:originalUrlServer]];
    NSDictionary *cookieHeaders = [NSHTTPCookie requestHeaderFieldsWithCookies:cookieStorage];
    
    for (NSString *key in cookieHeaders) {
        [request addValue:cookieHeaders[key] forHTTPHeaderField:key];
    }
    
    return request;
}

//-----------------------------------
/// @name deleteAllCookies
///-----------------------------------

/**
 * Method to clean the CookiesStorage
 *
 */
+ (void) deleteAllCookies {
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *each in cookieStorage.cookies) {
        [cookieStorage deleteCookie:each];
    }
}

//-----------------------------------
/// @name isServerVersionHigherThanLimitVersion
///-----------------------------------

/**
 * Method to detect if a server version is higher than a limit version.
 * This methos is used for example to know if the server have share API or support Cookies
 *
 * @param NSString -> serverVersion
 * @param NSArray -> limitVersion
 *
 * @return BOOL
 *
 */
+ (BOOL) isServerVersion:(NSString *) serverVersionString higherThanLimitVersion:(NSArray *) limitVersion {
    
    //Split the strings - Type 5.0.13
    NSArray *spliteVersion = [serverVersionString componentsSeparatedByString:@"."];
    
    
    NSMutableArray *serverVersion = [NSMutableArray new];
    for (NSString *string in spliteVersion) {
        [serverVersion addObject:string];
    }

    __block BOOL isSupported = NO;
    
    //Loop of compare
    [limitVersion enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *firstVersionString = obj;
        NSString *currentVersionString;
        if ([serverVersion count] > idx) {
            currentVersionString = [serverVersion objectAtIndex:idx];
            
            int firstVersionInt = [firstVersionString intValue];
            int currentVersionInt = [currentVersionString intValue];
            
            //NSLog(@"firstVersion item %d item is: %d", idx, firstVersionInt);
            //NSLog(@"currentVersion item %d item is: %d", idx, currentVersionInt);
            
            //Comparation secure
            switch (idx) {
                case 0:
                    //if the first number is higher
                    if (currentVersionInt > firstVersionInt) {
                        isSupported = YES;
                        *stop=YES;
                    }
                    //if the first number is lower
                    if (currentVersionInt < firstVersionInt) {
                        isSupported = NO;
                        *stop=YES;
                    }
                    
                    break;
                    
                case 1:
                    //if the seccond number is higger
                    if (currentVersionInt > firstVersionInt) {
                        isSupported = YES;
                        *stop=YES;
                    }
                    //if the second number is lower
                    if (currentVersionInt < firstVersionInt) {
                        isSupported = NO;
                        *stop=YES;
                    }
                    break;
                    
                case 2:
                    //if the third number is higger or equal
                    if (currentVersionInt >= firstVersionInt) {
                        isSupported = YES;
                        *stop=YES;
                    } else {
                        //if the third number is lower
                        isSupported = NO;
                        *stop=YES;
                    }
                    break;
                    
                default:
                    break;
            }
        } else {
            isSupported = NO;
            *stop=YES;
        }
        
    }];
    
    return isSupported;
}

#pragma mark - Share Permissions

+ (NSInteger) getPermissionsValueByCanEdit:(BOOL)canEdit andCanCreate:(BOOL)canCreate andCanChange:(BOOL)canChange andCanDelete:(BOOL)canDelete andCanShare:(BOOL)canShare andIsFolder:(BOOL) isFolder {
    
    NSInteger permissionsValue = k_read_share_permission;
    
    if (canEdit && !isFolder) {
        permissionsValue = permissionsValue + k_update_share_permission;
    }
    if (canCreate & isFolder) {
        permissionsValue = permissionsValue + k_create_share_permission;
    }
    if (canChange && isFolder) {
        permissionsValue = permissionsValue + k_update_share_permission;
    }
    if (canDelete & isFolder) {
        permissionsValue = permissionsValue + k_delete_share_permission;
    }
    if (canShare) {
        permissionsValue = permissionsValue + k_share_share_permission;
    }
    
    return permissionsValue;
}

+ (BOOL) isPermissionToCanCreate:(NSInteger) permissionValue {
    BOOL canCreate = ((permissionValue & k_create_share_permission) > 0);
    return canCreate;
}

+ (BOOL) isPermissionToCanChange:(NSInteger) permissionValue {
    BOOL canChange = ((permissionValue & k_update_share_permission) > 0);
    return canChange;
}

+ (BOOL) isPermissionToCanDelete:(NSInteger) permissionValue {
    BOOL canDelete = ((permissionValue & k_delete_share_permission) > 0);
    return canDelete;
}

+ (BOOL) isPermissionToCanShare:(NSInteger) permissionValue {
    BOOL canShare = ((permissionValue & k_share_share_permission) > 0);
    return canShare;
}

+ (BOOL) isAnyPermissionToEdit:(NSInteger) permissionValue {
    
    BOOL canCreate = [self isPermissionToCanCreate:permissionValue];
    BOOL canChange = [self isPermissionToCanChange:permissionValue];
    BOOL canDelete = [self isPermissionToCanDelete:permissionValue];
    
    
    BOOL canEdit = (canCreate || canChange || canDelete);
    
    return canEdit;
    
}

+ (BOOL) isPermissionToRead:(NSInteger) permissionValue {
    BOOL canRead = ((permissionValue & k_read_share_permission) > 0);
    return canRead;
}

+ (BOOL) isPermissionToReadCreateUpdate:(NSInteger) permissionValue {
    
    BOOL canRead   = [self isPermissionToRead:permissionValue];
    BOOL canCreate = [self isPermissionToCanCreate:permissionValue];
    BOOL canChange = [self isPermissionToCanChange:permissionValue];
    
    
    BOOL canEdit = (canCreate && canChange && canRead);
    
    return canEdit;
    
}
@end

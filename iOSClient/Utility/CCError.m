//
//  CCError.m
//  Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2017 Marino Faggiana. All rights reserved.
//
//  Author Marino Faggiana <marino.faggiana@nextcloud.com>
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

#import "CCError.h"

@implementation CCError

+ (NSString *)manageErrorKCF:(NSInteger)errorCode withNumberError:(BOOL)withNumberError
{
    switch (errorCode) {
            
        case kCFURLErrorCancelled:                      // -999
            return NSLocalizedString(@"_cancelled_by_user", nil);
            break;
        case kCFURLErrorTimedOut:                       // -1001
            return NSLocalizedString(@"_time_out_", nil);
            break;
        case kCFURLErrorCannotConnectToHost:            // -1004
            return NSLocalizedString(@"_server_down_", nil);
            break;
        case kCFURLErrorNetworkConnectionLost:          // -1005
            return NSLocalizedString(@"_not_possible_connect_to_server_", nil);
            break;
        case kCFURLErrorNotConnectedToInternet:         // -1009
            return NSLocalizedString(@"_not_connected_internet_", nil);
            break;
        case kCFURLErrorBadServerResponse:              // -1011
            return NSLocalizedString(@"_error_", nil);
            break;
        case kCFURLErrorUserCancelledAuthentication:    // -1012
            return NSLocalizedString(@"_not_possible_connect_to_server_", nil);
            break;
        case kCFURLErrorUserAuthenticationRequired:     // -1013
            return NSLocalizedString(@"_user_authentication_required_", nil);
            break;
        case kCFURLErrorSecureConnectionFailed:         // -1200
            return NSLocalizedString(@"_ssl_connection_error_", nil);
            break;
        case kCFURLErrorServerCertificateUntrusted:     // -1202
            return NSLocalizedString(@"_ssl_certificate_untrusted_", nil);
            break;
        case 101:                                       // 101
            return NSLocalizedString(@"_forbidden_characters_from_server_", nil);
            break;
        case 400:                                       // 400
            return NSLocalizedString(@"_bad_request_", nil);
            break;
        case 403:                                       // 403
            return NSLocalizedString(@"_error_not_permission_", nil);
            break;
        case 404:                                       // 404 Not Found. When for example we try to access a path that now not exist
            return NSLocalizedString(@"_error_path_", nil);
            break;
        case 423:                                       // 423 WebDAV Locked : The resource that is being accessed is locked
            return NSLocalizedString(@"_webdav_locked_", nil);
            break;
        case 500:
            return NSLocalizedString(@"_internal_server_", nil);
            break;
        case 503:
            return NSLocalizedString(@"_server_error_retry_", nil);
            break;
        case 507:
            return NSLocalizedString(@"_user_over_quota_", nil);
            break;
        default:
            if (withNumberError) return [NSString stringWithFormat:@"%ld", (long)errorCode];
            else return [NSString stringWithFormat:@"Error code %ld", (long)errorCode];;
            break;
    }
}

+ (NSString *)manageErrorDB:(NSInteger)errorCode
{
    //DDLogError(@"Error code : %ld", (long)errorCode);
    
    NSString *errorKCF = [self manageErrorKCF:errorCode withNumberError:NO];
    if ([errorKCF length] > 0) return errorKCF;
    
    switch (errorCode) {
        case 304:
            return NSLocalizedString(@"_folder_contents_nochanged_", nil);
            break;
        case 400:
            return NSLocalizedString(@"_error_",nil);
            break;
        case 401:
            return NSLocalizedString(@"_reauthenticate_user_", nil);
            break;
        case 403:
            return NSLocalizedString(@"_file_already_exists_", nil);
            break;
        case 404:
            return NSLocalizedString(@"_file_folder_not_exists_", nil);
            break;
        case 405:
            return NSLocalizedString(@"_method_not_expected_", nil);
            break;
        case 406:
            return NSLocalizedString(@"_too_many_files_", nil);
            break;
        case 409:
            return NSLocalizedString(@"_file_already_exists_", nil);
            break;
        case 411:
            return NSLocalizedString(@"_too_many_files_", nil);
            break;
        case 415:
            return NSLocalizedString(@"_images_invalid_converted_", nil);
            break;
        case 429:
            return NSLocalizedString(@"_too_many_request_", nil);
            break;
        case 500:
            return NSLocalizedString(@"_internal_server_", nil);
            break;
        case 503:
            return NSLocalizedString(@"_server_error_retry_", nil);
            break;
        case 507:
            return NSLocalizedString(@"_user_over_quota_", nil);
            break;
        default:
            return [NSString stringWithFormat:@"Error code %ld", (long)errorCode];
            break;
    }
}

+ (NSString *)manageErrorOC:(NSInteger)errorCode error:(NSError *)error
{
    //DDLogError(@"Error code : %ld", (long)error.code);
    //DDLogError(@"Error http : %ld", (long)errorCode);
    
    NSString *errorHTTP;
    NSString *errorKCF = [self manageErrorKCF:error.code withNumberError:NO];
    
    switch (errorCode) {
        case 0 :
            errorHTTP = @"";
            break;
        case kOCErrorSharedAPIWrong:            // 400
            errorHTTP = NSLocalizedString(@"_api_wrong_", nil);
            break;
        case kOCErrorServerUnauthorized:        // 401
            errorHTTP = NSLocalizedString(@"_bad_username_password_", nil);
            break;
        case kOCErrorServerForbidden:           // 403 Forbidden
            errorHTTP = NSLocalizedString(@"_error_not_permission_", nil);
            break;
        case kOCErrorServerPathNotFound:        // 404 Not Found. When for example we try to access a path that now not exist
            errorHTTP = NSLocalizedString(@"_error_path_", nil);
            break;
        case kOCErrorServerMethodNotPermitted:  // 405 Method not permitted
            errorHTTP = NSLocalizedString(@"_not_possible_create_folder_", nil);
            break;
        case kOCErrorProxyAuth:                 // 407 Error credential
            errorHTTP = NSLocalizedString(@"_error_proxy_auth_", nil);
            break;
        case kOCErrorServerTimeout:             // 408 timeout
            errorHTTP = NSLocalizedString(@"_not_possible_connect_to_server_", nil);
            break;
        case 423:                               // 423 Locked
            errorHTTP = NSLocalizedString(@"_file_directory_locked_", nil);
            break;
        default:                                // Default
            errorHTTP = [NSString stringWithFormat:@"Error code %ld", (long)errorCode];
            break;
    }
    
    if (error.code == 0 && error.code == 0)
        return NSLocalizedString(@"_error_",nil);
    else if (error.code == errorCode)
        return [NSString stringWithFormat:@"%@", errorHTTP];
    else
        return [NSString stringWithFormat:@"%@ %@", errorKCF, errorHTTP];
}

@end

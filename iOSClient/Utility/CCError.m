//
//  CCError.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 04/02/16.
//  Copyright (c) 2017 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
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
            return NSLocalizedStringFromTable(@"_cancelled_by_user", @"Error", nil);
            break;
        case kCFURLErrorTimedOut:                       // -1001
            return NSLocalizedStringFromTable(@"_time_out_", @"Error", nil);
            break;
        case kCFURLErrorCannotConnectToHost:            // -1004
            return NSLocalizedStringFromTable(@"_server_down_", @"Error", nil);
            break;
        case kCFURLErrorNetworkConnectionLost:          // -1005
            return NSLocalizedStringFromTable(@"_not_possible_connect_to_server_", @"Error", nil);
            break;
        case kCFURLErrorNotConnectedToInternet:         // -1009
            return NSLocalizedStringFromTable(@"_not_connected_internet_", @"Error", nil);
            break;
        case kCFURLErrorBadServerResponse:              // -1011
            return NSLocalizedString(@"_error_",nil);
            break;
        case kCFURLErrorUserCancelledAuthentication:    // -1012
            return NSLocalizedStringFromTable(@"_not_possible_connect_to_server_", @"Error", nil);
            break;
        case kCFURLErrorUserAuthenticationRequired:     // -1013
            return NSLocalizedStringFromTable(@"_user_autentication_required_", @"Error", nil);
            break;
        case kCFURLErrorSecureConnectionFailed:         // -1200
            return NSLocalizedStringFromTable(@"_ssl_connection_error_", @"Error", nil);
            break;
        case kCFURLErrorServerCertificateUntrusted:     // -1202
            return NSLocalizedStringFromTable(@"_ssl_certificate_untrusted_", @"Error", nil);
            break;
        case 101:                                       // 101
            return NSLocalizedStringFromTable(@"_forbidden_characters_from_server_", @"Error", nil);
            break;
        case 400:                                       // 400
            return NSLocalizedStringFromTable(@"Bad request", @"Error", nil);
            break;
        case 403:                                       // 403
            return NSLocalizedStringFromTable(@"_error_not_permission_", @"Error", nil);
            break;
        case 404:                                       // 404 Not Found. When for example we try to access a path that now not exist
            return NSLocalizedStringFromTable(@"_error_path_", @"Error", nil);
            break;
        case 423:                                       // 423 WebDAV Locked : The resource that is being accessed is locked
            return NSLocalizedStringFromTable(@"WebDAV Locked : The resource that is being accessed is locked", @"Error", nil);
            break;
        case 500:
            return NSLocalizedStringFromTable(@"_internal_server_", @"Error", nil);
            break;
        case 503:
            return NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil);
            break;
        case 507:
            return NSLocalizedStringFromTable(@"_user_over_quota_", @"Error", nil);
            break;
        default:
            if (withNumberError) return [NSString stringWithFormat:@"%ld", (long)errorCode];
            else return @"";
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
            return NSLocalizedStringFromTable(@"_folder_contents_nochanged_", @"Error", nil);
            break;
        case 400:
            return NSLocalizedString(@"_error_",nil);
            break;
        case 401:
            return NSLocalizedStringFromTable(@"_reauthenticate_user_", @"Error", nil);
            break;
        case 403:
            return NSLocalizedStringFromTable(@"_file_already_exists_", @"Error", nil);
            break;
        case 404:
            return NSLocalizedStringFromTable(@"_file_folder_not_exists_", @"Error", nil);
            break;
        case 405:
            return NSLocalizedStringFromTable(@"_method_not_expected_", @"Error", nil);
            break;
        case 406:
            return NSLocalizedStringFromTable(@"_too_many_files_", @"Error", nil);
            break;
        case 409:
            return NSLocalizedStringFromTable(@"_file_already_exists_", @"Error", nil);
            break;
        case 411:
            return NSLocalizedStringFromTable(@"_too_many_files_", @"Error", nil);
            break;
        case 415:
            return NSLocalizedStringFromTable(@"_images_invalid_converted_", @"Error", nil);
            break;
        case 429:
            return NSLocalizedStringFromTable(@"_too_many_request_", @"Error", nil);
            break;
        case 500:
            return NSLocalizedStringFromTable(@"_internal_server_", @"Error", nil);
            break;
        case 503:
            return NSLocalizedStringFromTable(@"_server_error_retry_", @"Error", nil);
            break;
        case 507:
            return NSLocalizedStringFromTable(@"_user_over_quota_", @"Error", nil);
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
            errorHTTP = NSLocalizedStringFromTable(@"_api_wrong_", @"Error", nil);
            break;
        case kOCErrorServerUnauthorized:        // 401
            errorHTTP = NSLocalizedStringFromTable(@"_bad_username_password_", @"Error", nil);
            break;
        case kOCErrorServerForbidden:           // 403 Forbidden
            errorHTTP = NSLocalizedStringFromTable(@"_error_not_permission_", @"Error", nil);
            break;
        case kOCErrorServerPathNotFound:        // 404 Not Found. When for example we try to access a path that now not exist
            errorHTTP = NSLocalizedStringFromTable(@"_error_path_", @"Error", nil);
            break;
        case kOCErrorServerMethodNotPermitted:  // 405 Method not permitted
            errorHTTP = NSLocalizedStringFromTable(@"_not_possible_create_folder_", @"Error", nil);
            break;
        case kOCErrorProxyAuth:                 // 407 Error credential
            errorHTTP = NSLocalizedStringFromTable(@"_error_proxy_auth_", @"Error", nil);
            break;
        case kOCErrorServerTimeout:             // 408 timeout
            errorHTTP = NSLocalizedStringFromTable(@"_not_possible_connect_to_server_", @"Error", nil);
            break;
        case 423:                               // 423 Locked
            errorHTTP = NSLocalizedStringFromTable(@"_file_directory_locked_", @"Error", nil);
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

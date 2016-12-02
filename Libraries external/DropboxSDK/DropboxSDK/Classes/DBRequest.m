//
//  DBRestRequest.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBRequest.h"
#import "DBLog.h"
#import "DBError.h"
#import "JSON.h"
#import "DBBase64Transcoder.h"

// These constants come back from the API, but aren't defined as constants anywhere
static NSString * const DBURLAuthenticationMethodOAuth = @"NSURLAuthenticationMethodOAuth";
static NSString * const DBURLAuthenticationMethodOAuth2 = @"NSURLAuthenticationMethodOAuth2";

id<DBNetworkRequestDelegate> dbNetworkRequestDelegate = nil;


@interface DBRequest ()

- (void)setError:(NSError *)error;

@property (nonatomic, retain) NSFileManager *fileManager;

@end


@implementation DBRequest

+ (void)setNetworkRequestDelegate:(id<DBNetworkRequestDelegate>)delegate {
    dbNetworkRequestDelegate = delegate;
}

- (id)initWithURLRequest:(NSURLRequest *)aRequest andInformTarget:(id)aTarget selector:(SEL)aSelector {
    if ((self = [super init])) {
        request = [aRequest retain];
        target = aTarget;
        selector = aSelector;
        
        fileManager = [NSFileManager new];
        urlConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [dbNetworkRequestDelegate networkRequestStarted];
    }
    return self;
}

- (void) dealloc {
    [urlConnection cancel];
    
    [request release];
    [urlConnection release];
    [fileHandle release];
    [fileManager release];
    [userInfo release];
    [sourcePath release];
    [response release];
    [xDropboxMetadataJSON release];
    [resultFilename release];
    [tempFilename release];
    [resultData release];
    [error release];
    [super dealloc];
}

@synthesize failureSelector;
@synthesize fileManager;
@synthesize downloadProgressSelector;
@synthesize uploadProgressSelector;
@synthesize userInfo;
@synthesize sourcePath;
@synthesize request;
@synthesize response;
@synthesize xDropboxMetadataJSON;
@synthesize downloadProgress;
@synthesize uploadProgress;
@synthesize resultData;
@synthesize resultFilename;
@synthesize error;

- (NSString *)resultString {
    return [[[NSString alloc] 
             initWithData:resultData encoding:NSUTF8StringEncoding]
            autorelease];
}

- (NSObject *)resultJSON {
    return [[self resultString] JSONValue];
} 

- (NSInteger)statusCode {
    return [response statusCode];
}

- (long long)responseBodySize {
    // Use the content-length header, if available.
    long long contentLength = [[[response allHeaderFields] objectForKey:@"Content-Length"] longLongValue];
    if (contentLength > 0) return contentLength;

    // Fall back on the bytes field in the metadata x-header, if available.
    if (xDropboxMetadataJSON != nil) {
        id bytes = [xDropboxMetadataJSON objectForKey:@"bytes"];
        if (bytes != nil) {
            return [bytes longLongValue];
        }
    }

    return 0;
}

- (void)cancel {
    [urlConnection cancel];
    target = nil;
    
    if (tempFilename) {
        [fileHandle closeFile];
        NSError *rmError;
        if (![fileManager removeItemAtPath:tempFilename error:&rmError]) {
            DBLogError(@"DBRequest#cancel Error removing temp file: %@", rmError);
        }
    }
    
    [dbNetworkRequestDelegate networkRequestStopped];
}

- (id)parseResponseAsType:(Class)cls {
    if (error) return nil;
    NSObject *res = [self resultJSON];
    if (![res isKindOfClass:cls]) {
        [self setError:[NSError errorWithDomain:DBErrorDomain code:DBErrorInvalidResponse userInfo:userInfo]];
        return nil;
    }
    return res;
}

#pragma mark NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)aResponse {
    response = [(NSHTTPURLResponse *)aResponse retain];

    // Parse out the x-response-metadata as JSON.
    xDropboxMetadataJSON = [[[[response allHeaderFields] objectForKey:@"X-Dropbox-Metadata"] JSONValue] retain];

    if (resultFilename && [self statusCode] == 200) {
        // Create the file here so it's created in case it's zero length
        // File is downloaded into a temporary file and then moved over when completed successfully
        NSString *filename = [[NSProcessInfo processInfo] globallyUniqueString];
        tempFilename = [[NSTemporaryDirectory() stringByAppendingPathComponent:filename] retain];
        
        BOOL success = [fileManager createFileAtPath:tempFilename contents:nil attributes:nil];
        if (!success) {
            DBLogError(@"DBRequest#connection:didReceiveData: Error creating temp file: (%d) %s",
                       errno, strerror(errno));
        }

        fileHandle = [[NSFileHandle fileHandleForWritingAtPath:tempFilename] retain];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (resultFilename && [self statusCode] == 200) {
        @try {
            [fileHandle writeData:data];
        } @catch (NSException *e) {
            // In case we run out of disk space
            [urlConnection cancel];
            [fileHandle closeFile];
            [fileManager removeItemAtPath:tempFilename error:nil];
            [self setError:[NSError errorWithDomain:DBErrorDomain code:DBErrorInsufficientDiskSpace userInfo:userInfo]];
            
            SEL sel = failureSelector ? failureSelector : selector;
            [target performSelector:sel withObject:self];
            
            [dbNetworkRequestDelegate networkRequestStopped];
            
            return;
        }
    } else {
        if (resultData == nil) {
            resultData = [NSMutableData new];
        }
        [resultData appendData:data];
    }

    bytesDownloaded += [data length];

    long long responseBodySize = [self responseBodySize];
    if (responseBodySize > 0) {
        downloadProgress = (CGFloat)bytesDownloaded / (CGFloat)responseBodySize;
        if (downloadProgressSelector) {
            [target performSelector:downloadProgressSelector withObject:self];
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [fileHandle closeFile];
    [fileHandle release];
    fileHandle = nil;
    
    if (self.statusCode != 200) {
        NSMutableDictionary *errorUserInfo = [NSMutableDictionary dictionaryWithDictionary:userInfo];
        // To get error userInfo, first try and make sense of the response as JSON, if that
        // fails then send back the string as an error message
        NSString *resultString = [self resultString];
        if ([resultString length] > 0) {
            @try {
                DBJsonParser *jsonParser = [DBJsonParser new];
                NSObject *resultJSON = [jsonParser objectWithString:resultString];
                [jsonParser release];
                
                if ([resultJSON isKindOfClass:[NSDictionary class]]) {
                    [errorUserInfo addEntriesFromDictionary:(NSDictionary *)resultJSON];
                }
            } @catch (NSException *e) {
                [errorUserInfo setObject:resultString forKey:@"errorMessage"];
            }
        }
        [self setError:[NSError errorWithDomain:DBErrorDomain code:self.statusCode userInfo:errorUserInfo]];
    } else if (tempFilename) {
        NSError *moveError;
        
        // Check that the file size is the same as the Content-Length
        NSDictionary *fileAttrs = [fileManager attributesOfItemAtPath:tempFilename error:&moveError];
        
        if (!fileAttrs) {
            DBLogError(@"DBRequest#connectionDidFinishLoading: error getting file attrs: %@", moveError);
            [fileManager removeItemAtPath:tempFilename error:nil];
            [self setError:[NSError errorWithDomain:moveError.domain code:moveError.code userInfo:self.userInfo]];
        } else if ([self responseBodySize] != 0 && [self responseBodySize] != [fileAttrs fileSize]) {
            // This happens in iOS 4.0 when the network connection changes while loading
            [fileManager removeItemAtPath:tempFilename error:nil];
            [self setError:[NSError errorWithDomain:DBErrorDomain code:DBErrorGenericError userInfo:self.userInfo]];
        } else {        
            // Everything's OK, move temp file over to desired file
            [fileManager removeItemAtPath:resultFilename error:nil];
            
            BOOL success = [fileManager moveItemAtPath:tempFilename toPath:resultFilename error:&moveError];
            if (!success) {
                DBLogError(@"DBRequest#connectionDidFinishLoading: error moving temp file to desired location: %@",
                    [moveError localizedDescription]);
                [self setError:[NSError errorWithDomain:moveError.domain code:moveError.code userInfo:self.userInfo]];
            }
        }
        
        [tempFilename release];
        tempFilename = nil;
    }
    
    SEL sel = (error && failureSelector) ? failureSelector : selector;
    [target performSelector:sel withObject:self];
    
    [dbNetworkRequestDelegate networkRequestStopped];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)anError {
    [fileHandle closeFile];
    [self setError:[NSError errorWithDomain:anError.domain code:anError.code userInfo:self.userInfo]];
    bytesDownloaded = 0;
    downloadProgress = 0;
    uploadProgress = 0;
    
    if (tempFilename) {
        NSError *removeError;
        BOOL success = [fileManager removeItemAtPath:tempFilename error:&removeError];
        if (!success) {
            DBLogError(@"DBRequest#connection:didFailWithError: error removing temporary file: %@", 
                    [removeError localizedDescription]);
        }
        [tempFilename release];
        tempFilename = nil;
    }
    
    SEL sel = failureSelector ? failureSelector : selector;
    [target performSelector:sel withObject:self];

    [dbNetworkRequestDelegate networkRequestStopped];
}

- (void)connection:(NSURLConnection *)connection didSendBodyData:(NSInteger)bytesWritten
    totalBytesWritten:(NSInteger)totalBytesWritten 
    totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite {
    
    uploadProgress = (CGFloat)totalBytesWritten / (CGFloat)totalBytesExpectedToWrite;
    if (uploadProgressSelector) {
        [target performSelector:uploadProgressSelector withObject:self];
    }
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)response {
    return nil;
}

- (NSInputStream *)connection:(NSURLConnection *)connection needNewBodyStream:(NSURLRequest *)req {
    if (!sourcePath) {
        DBLogWarning(@"DropboxSDK: need new body stream, but none available");
        return nil;
    }
    return [NSInputStream inputStreamWithFileAtPath:sourcePath];
}

#pragma mark private methods

- (void)setError:(NSError *)theError {
    if (theError == error) return;
    [error release];
    error = [theError retain];

    NSString *errorStr = [error.userInfo objectForKey:@"error"];
    if (!errorStr) {
        errorStr = [error description];
    }

    if (!([error.domain isEqual:DBErrorDomain] && error.code == 304)) {
        // Log errors unless they're 304's
        DBLogWarning(@"DropboxSDK: error making request to %@ - (%ld) %@",
                       [[request URL] path], (long)error.code, errorStr);
    }
}

#pragma mark SSL Security Configuration

//
// Called on SSL handshake
// Performs SSL certificate pinning
// Follows Dropbox SSL Guidelines:
// https://docs.google.com/a/dropbox.com/document/d/1NZ-82u_HxtM8J6IR1YSh-klHFfjqiIE8iTN1GL72a7E
//
- (void)connection:(NSURLConnection *)connection willSendRequestForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {

    NSString *host = [[challenge protectionSpace] host];

    // Check the authentication method for connection: only SSL/TLS is allowed
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {

        // Validate host's certificates against Dropbox certificate authorities
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)[DBRequest rootCertificates]);
        SecTrustResultType trustResult = kSecTrustResultInvalid;
        SecTrustEvaluate(serverTrust, &trustResult);
        if (trustResult == kSecTrustResultUnspecified) {
            // Certificate validation succeeded.
            // Next, check if the sertificate is not revoked
            // Note: certificate is a reference into an existing object, and doesn't need a CFRelease.
            SecCertificateRef certificate = SecTrustGetCertificateAtIndex(serverTrust, 0);
            if ([DBRequest isRevokedCertificate: certificate]){
                DBLogError(@"DropboxSDK: SSL Error. Revoked certificate for the host: %@", host);
                [[challenge sender] cancelAuthenticationChallenge: challenge];
            } else {
                // Continue the connection
                [challenge.sender
                 useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]
                 forAuthenticationChallenge:challenge];
            }
        } else {
            // Certificate validation failed. Terminate the connection
            DBLogError(@"DropboxSDK: SSL Error. Cannot validate a certificate for the host: %@", host);
            [[challenge sender] cancelAuthenticationChallenge: challenge];
        }
    } else if ([challenge.protectionSpace.authenticationMethod isEqualToString:DBURLAuthenticationMethodOAuth]
               || [challenge.protectionSpace.authenticationMethod isEqualToString:DBURLAuthenticationMethodOAuth2]) {
        // Don't respond to an OAuth challenge, allowing the server to fail with a 401.
        // Note that we assume that in order to get this challenge we got an HTTP-layer
        // response, so SSL handshake already succeeded, and we can trust the server's
        // answer as genuine.
        [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
    } else {
        // Disallowed authentication method. Terminate the connection.  Assuming an
        // SSL failure is the safest option here, rather than trying to continue past
        // the error as we do for OAuth.
        DBLogError(@"DropboxSDK: SSL Error. Unknown authentication method %@ for Dropbox host: %@",
                   challenge.protectionSpace.authenticationMethod, host);
        [[challenge sender] cancelAuthenticationChallenge: challenge];
    }
}

//
// List of revoked certificates' serial numbers
//
static const char *kRevokedCertificateSNs[] = {
    "\x02\x75\xc7\x6c\x1e\x64\x3c\x26\x49\x88\x6b\x0e\x76\x3a\xc3\xe9",  // digicert star.dropboxusercontent.com-20170419
    "\x27\xab\x71\xba\x41\x86\x5c",                     // godaddy star.dropbox.com
    "\x2b\x73\x47\x79\xdb\x80\x12"                      // godaddy dropbox.com-gd_bundle
};
static const size_t kMaxCertSNLen = 1000;

#ifdef TARGET_OS_IPHONE
/*  Helper function parse length octets from ASN.1 decoding
 Only available on iPhone.
 Input is a buf and the max length of the buffer (for safety checks) is in bufLen
 idx is a pointer to the current index, at which we start parsing the length.
 idx is changed as we move forward parsing octets according to the format indicators
 length is a pointer to a length value that is set to the actual length of the value.
 At the end of the function, idx will be at the start of the value and the length of the value,
 after which a new tag starts, will be in the length argument.

 Returns 0 on success or non zero values otherwise */

+ (int)readLength:(uint32_t *)length fromBuffer:(const uint8_t *)buf ofLength:(const uint32_t)bufLen atIndex:(uint32_t *)idx {

    if (*idx >= bufLen) {
        DBLogWarning(@"readLength: idx:%d >= buflen:%d", *idx, bufLen);
        return -2;
    }

    if (buf[*idx] == 0x80) {
        //this is unlimited encoding and this can't happen
        DBLogWarning(@"readLength: Invalid DER (unlimited length encoding)");
        return -1;
    }

    uint8_t firstbit = (uint8_t) (buf[*idx] & 0x80);
    //short form encoding
    //first bit is 0 and the remaining bits
    //is the length
    //we save that and move the idx one step, where the value will start
    if (firstbit == 0) {
        *length = (uint32_t) (buf[*idx] & 0x7F);
        *idx = *idx+1;
        return 0;
    }

    //This is long form encoding
    //The first bit is 1 and remaining bits are length of length

    uint8_t len_of_len = (uint8_t) (buf[*idx] & 0x7f);
    if (len_of_len > 4) {
        //This is crazy -- more than 4bytes means that this is more than 4GB
        DBLogWarning(@"readLength: length of any TLV can't be more than 32bit");
        return -1;
    }

    if (*idx + len_of_len >= bufLen) {
        DBLogWarning(@"readLength: idx:%d + len_of_len: %d >= bufLen:%d", *idx, len_of_len, bufLen);
        return -2;
    }

    *idx = *idx + 1;
    //now *idx is start of length integer value.
    uint32_t len=0;
    while (len_of_len) {
        len = len << 8;
        len = len + buf[*idx];
        len_of_len--;
        *idx = *idx+1;
    }
    *length = len;
    return 0;
}

/*  Get serial number by parsing ASN.1 data from the certificate
 This function only exists on iPhone because the system does not provide
 a function to extract a serial number from a certificate.

 The input is a buffer (derdata) with a DER encoded ASN.1 certificate (
 a series of octets) and the length of the buffer. Returns a CFDataRef to
 a newly allocated buffer that has the serial number octets.

 While this code has been written with extreme paranoia, we are actually working on
 only the initial few bytes of a certificate signed and verified by a root CA that
 we have pinned. This data can be malicious only if the CA is compromised, which
 means we have bigger problems for all our clients.

 None the less, please talk to team-security before using this function.
 */

+ (CFDataRef) copySerialFromCertificate:(const uint8_t *)derdata certificateLength:(const CFIndex)certlen {

    /* High Level notes:
     By the X.509 standard, serial number is
     SEQ{
     SEQ{
     Version
     Serial
     }
     }

     So we go down two sequences and then look for Serial after jumping past version.

     ASN.1 is a simple format: TAG, LENGTH, VALUE. We look for tag, get the length,
     and then do what we want with the value (either ignoring it or reading it).

     Best reference I found is http://www.oss.com/asn1/resources/books-whitepapers-pubs/larmouth-asn1-book.pdf
     Start at Page 252 for encoding
     */

    static const uint8_t TAG_SEQ = 0x30;
    static const uint8_t TAG_INT = 0x02;

    if (certlen < 0 || certlen > (CFIndex) INT32_MAX) {
        DBLogWarning(@"Certlen negative or too high: %ld. Paranoidly failing.", certlen);
        return NULL;
    }

    uint32_t derlen = (uint32_t) certlen;
    uint32_t idx = 0;

    //first byte has to be for sequence
    if (idx >= derlen) {
        DBLogWarning(@"Error trying to read first TAG_SEQ. idx:%d >= certlen:%ld", idx, certlen);
        return NULL;
    }

    if (derdata[idx] != TAG_SEQ) {
        DBLogWarning(@"DER data does not start with TAG_SEQ. idx:%d octet:%X", idx, derdata[idx]);
        return NULL;
    }

    idx++;

    uint32_t len = 0;
    if ([DBRequest readLength:&len fromBuffer:derdata ofLength:derlen atIndex:&idx] != 0) {
        DBLogWarning(@"Failed to parse length from first TAG_SEQ.");
        return NULL;
    }

    if (idx >= derlen) {
        DBLogWarning(@"Error trying to read 2nd TAG_SEQ. idx:%d >= certlen:%ld", idx, certlen);
        return NULL;
    }

    //now we are beyond the length and this is another sequence
    if (derdata[idx] != TAG_SEQ) {
        DBLogWarning(@"Error: first tag inside the TAG_SEQ is not a TAG_SEQ. idx:%d octet:%X", idx, derdata[idx]);
        return NULL;
    }

    idx++;


    if ([DBRequest readLength:&len fromBuffer:derdata ofLength:derlen atIndex:&idx] != 0) {
        DBLogWarning(@"Failed to parse length from second TAG_SEQ");
        return NULL;
    }

    //now we are at start of actual stuff.
    //Semantically, this is the CERT_VERSION.
    //We don't actually care what tag this is, but we need to jump past it.

    if (idx >= derlen) {
        DBLogWarning(@"Reached end of buffer while reading Version from first TLV inside TAG_SEQ. idx:%d >= certlen:%ld", idx, certlen);
        return NULL;
    }

    //last five bits cant be all 1s, otherwise this is more than 1 byte tag
    //which shouldn't happen for SSL certs
    if ((derdata[idx] & 0x1F) == 0x1F) {
        DBLogWarning(@"Invalid CERT Version tag inside 2nd SEQ");
        return NULL;
    }

    idx++;

    if ([DBRequest readLength:&len fromBuffer:derdata ofLength:derlen atIndex:&idx] != 0) {
        DBLogWarning(@"Failed to parse length of CERT Version tag");
        return NULL;
    }

    //we don't care about this so we only need to jump past it

    idx+=len;


    if (idx >= derlen) {
        DBLogWarning(@"Reached end of buffer while reading Version from first TLV inside TAG_SEQ. idx:%d >= certlen:%ld", idx, certlen);
        return NULL;
    }

    //ok now comes the serial number TLV
    if (derdata[idx] != TAG_INT) {
        DBLogWarning(@"Reached serial number, but it is not marked with TAG_INT. Failing");
        return NULL;
    }

    idx++;

    if ([DBRequest readLength:&len fromBuffer:derdata ofLength:derlen atIndex:&idx] != 0) {
        DBLogWarning(@"Failed to parse length of serial number TLV");
        return NULL;
    }


    if (idx+len >= derlen) {
        DBLogWarning(@"Serial length goes beyond end of buffer. idx:%d >= certlen:%ld", idx, certlen);
        return NULL;
    }

    // Now derdata+idx is start of serial of len
    // CFDataCreate makes a copy by default
    CFDataRef serial = CFDataCreate(NULL, derdata+idx, len);
    return serial;
}
#endif

+ (bool)isRevokedCertificate:(SecCertificateRef)certificate {

#ifdef TARGET_OS_IPHONE
    const CFDataRef cfder = SecCertificateCopyData(certificate);
    const CFDataRef serial = [DBRequest copySerialFromCertificate:CFDataGetBytePtr(cfder) certificateLength:CFDataGetLength(cfder)];
    CFRelease(cfder);
#else
    const CFDataRef serial = SecCertificateCopySerialNumber(certificate, NULL);
#endif

    if (serial == NULL) {
        // Sanity check, should never happen. Fail if we cannot get a serial number
        DBLogError(@"DropboxSDK: SSL Error. Cannot read a serial number of the certificate");
        return true;
    }
    bool isRevoked = false;
    for (int i=0; i < sizeof(kRevokedCertificateSNs)/sizeof(kRevokedCertificateSNs[0]); i++) {
        CFDataRef revoked_serial = CFDataCreateWithBytesNoCopy(NULL,
                                                          (const UInt8*)kRevokedCertificateSNs[i],
                                                          strnlen(kRevokedCertificateSNs[i], kMaxCertSNLen),
                                                          kCFAllocatorNull);
        if(CFEqual(serial, revoked_serial)) {
            isRevoked = true;
        }
        CFRelease(revoked_serial);
    }
    CFRelease(serial);
    return isRevoked;
}

//
// Base64-encoded root certificates in DER format
//
// Dropbox official root certificates as of Nov 2013
// https://docs.google.com/a/dropbox.com/document/d/1rRpdaZODYatEO5c9VMu6ACaunE_xZT2oJlbyP457U_I
//
// Contains the following root certificates:
// DigiCert Assured ID Root CA
// DigiCert Global Root CA
// DigiCert High Assurance EV Root CA
// Entrust Root Certification Authority - EC1
// Entrust Root Certification Authority - G2
// Entrust Root Certification Authority
// Entrust.net Certification Authority (2048)
// GeoTrust Global CA
// GeoTrust Primary Certification Authority - G2
// GeoTrust Primary Certification Authority - G3
// GeoTrust Primary Certification Authority
// Go Daddy Class 2 Certification Authority
// Go Daddy Root Certificate Authority - G2
// Go Daddy Secure Certification Authority serialNumber=07969287
// Go Daddy Secure Server Certificate (Cross Intermediate Certificate)
// Thawte Premium Server CA
// Thawte Primary Root CA - G2
// Thawte Primary Root CA - G3
// Thawte Primary Root CA
//
static const char *kBase64RootCerts[] = {
    //DigiCert Assured ID Root CA
    "MIIDtzCCAp+gAwIBAgIQDOfg5RfYRv6P5WD8G/AwOTANBgkqhkiG9w0BAQUFADBlMQswCQYDVQQGEwJV\
    UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQD\
    ExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwHhcNMDYxMTEwMDAwMDAwWhcNMzExMTEwMDAwMDAw\
    WjBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl\
    cnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEB\
    AQUAA4IBDwAwggEKAoIBAQCtDhXO5EOAXLGH87dg+XESpa7cJpSIqvTO9SA5KFhgDPiA2qkVlTJhPLWx\
    KISKityfCgyDF3qPkKyK53lTXDGEKvYPmDI2dsze3Tyoou9q+yHyUmHfnyDXH+Kx2f4YZNISW1/5WBg1\
    vEfNoTb5a3/UsDg+wRvDjDPZ2C8Y/igPs6eD1sNuRMBhNZYW/lmci3Zt1/GiSw0r/wty2p5g0I6QNcZ4\
    VYcgoc/lbQrISXwxmDNsIumH0DJaoroTghHtORedmTpyoeb6pNnVFzF1roV9Iq4/AUaG9ih5yLHa5FcX\
    xH4cDrC0kqZWs72yl+2qp/C3xag/lRbQ/6GW6whfGHdPAgMBAAGjYzBhMA4GA1UdDwEB/wQEAwIBhjAP\
    BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBRF66Kv9JLLgjEtUYunpyGd823IDzAfBgNVHSMEGDAWgBRF\
    66Kv9JLLgjEtUYunpyGd823IDzANBgkqhkiG9w0BAQUFAAOCAQEAog683+Lt8ONyc3pklL/3cmbYMuRC\
    dWKuh+vy1dneVrOfzM4UKLkNl2BcEkxY5NM9g0lFWJc1aRqoR+pWxnmrEthngYTffwk8lOa4JiwgvT2z\
    KIn3X/8i4peEH+ll74fg38FnSbNd67IJKusm7Xi+fT8r87cmNW1fiQG2SVufAQWbqz0lwcy2f8Lxb4bG\
    +mRo64EtlOtCt/qMHt1i8b5QZ7dsvfPxH2sMNgcWfzd8qVttevESRmCD1ycEvkvOl77DZypoEd+A5wwz\
    Zr8TDRRu838fYxAe+o0bJW1sj6W3YQGx0qMmoRBxna3iw/nDmVG3KwcIzi7mULKn+gpFL6Lw8g==",
    //DigiCert Global Root CA
    "MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBhMQswCQYDVQQGEwJV\
    UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQD\
    ExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBDQTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGEx\
    CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j\
    b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A\
    MIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsBCSDMAZOnTjC3U/dDxGkAV53ijSLdhwZA\
    AIEJzs4bg7/fzTtxRuLWZscFs3YnFo97nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmF\
    aG5cIzJLv07A6Fpt43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P\
    T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4gdW7jVg/tRvoSSii\
    cNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/\
    BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbRTLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm\
    8KPiGxvDl7I90VUwDQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr\
    hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg06O/nVsJ8dWO41P0\
    jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJFPnlUkiaY4IBIqDfv8NZ5YBberOgOzW6s\
    RBc4L0na4UU+Krk2U886UAb3LujEV0lsYSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDA\
    GySj4dzp30d8tbQkCAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=",
    //DigiCert High Assurance EV Root CA
    "MIIDxTCCAq2gAwIBAgIQAqxcJmoLQJuPC3nyrkYldzANBgkqhkiG9w0BAQUFADBsMQswCQYDVQQGEwJV\
    UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSswKQYDVQQD\
    EyJEaWdpQ2VydCBIaWdoIEFzc3VyYW5jZSBFViBSb290IENBMB4XDTA2MTExMDAwMDAwMFoXDTMxMTEx\
    MDAwMDAwMFowbDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3\
    LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNlcnQgSGlnaCBBc3N1cmFuY2UgRVYgUm9vdCBDQTCC\
    ASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMbM5XPm+9S75S0tMqbf5YE/yc0lSbZxKsPVlDRn\
    ogocsF9ppkCxxLeyj9CYpKlBWTrT3JTWPNt0OKRKzE0lgvdKpVMSOO7zSW1xkX5jtqumX8OkhPhPYlG+\
    +MXs2ziS4wblCJEMxChBVfvLWokVfnHoNb9Ncgk9vjo4UFt3MRuNs8ckRZqnrG0AFFoEt7oT61EKmEFB\
    Ik5lYYeBQVCmeVyJ3hlKV9Uu5l0cUyx+mM0aBhakaHPQNAQTXKFx01p8VdteZOE3hzBWBOURtCmAEvF5\
    OYiiAhF8J2a3iLd48soKqDirCmTCv2ZdlYTBoSUeh10aUAsgEsxBu24LUTi4S8sCAwEAAaNjMGEwDgYD\
    VR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLE+w2kD+L9HAdSYJhoIAu9jZCvD\
    MB8GA1UdIwQYMBaAFLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQAcGgaX3Nec\
    nzyIZgYIVyHbIUf4KmeqvxgydkAQV8GK83rZEWWONfqe/EW1ntlMMUu4kehDLI6zeM7b41N5cdblIZQB\
    2lWHmiRk9opmzN6cN82oNLFpmyPInngiK3BD41VHMWEZ71jFhS9OMPagMRYjyOfiZRYzy78aG6A9+Mpe\
    izGLYAiJLQwGXFK3xPkKmNEVX58Svnw2Yzi9RKR/5CYrCsSXaQ3pjOLAEFe4yHYSkVXySGnYvCoCWw9E\
    1CAx2/S6cCZdkGCevEsXCS+0yx5DaMkHJ8HSXPfqIbloEpw8nL+e/IBcm2PN7EeqJSdnoDfzAIJ9VNep\
    +OkuE6N36B9K",
    //Entrust Root Certification Authority - EC1
    "MIIC+TCCAoCgAwIBAgINAKaLeSkAAAAAUNCR+TAKBggqhkjOPQQDAzCBvzELMAkGA1UEBhMCVVMxFjAU\
    BgNVBAoTDUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVy\
    bXMxOTA3BgNVBAsTMChjKSAyMDEyIEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ugb25s\
    eTEzMDEGA1UEAxMqRW50cnVzdCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRUMxMB4XDTEy\
    MTIxODE1MjUzNloXDTM3MTIxODE1NTUzNlowgb8xCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0\
    LCBJbmMuMSgwJgYDVQQLEx9TZWUgd3d3LmVudHJ1c3QubmV0L2xlZ2FsLXRlcm1zMTkwNwYDVQQLEzAo\
    YykgMjAxMiBFbnRydXN0LCBJbmMuIC0gZm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxMzAxBgNVBAMTKkVu\
    dHJ1c3QgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eSAtIEVDMTB2MBAGByqGSM49AgEGBSuBBAAi\
    A2IABIQTydC6bUF74mzQ61VfZgIaJPRbiWlH47jCffHyAsWfoPZb1YsGGYZPUxBtByQnoaD41UcZYUx9\
    ypMn6nQM72+WCf5j7HBdNq1nd67JnXxVRDqiY1Ef9eNi1KlHBz7MIKNCMEAwDgYDVR0PAQH/BAQDAgEG\
    MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFLdj5xrdjekIplWDpOBqUEFlEUJJMAoGCCqGSM49BAMD\
    A2cAMGQCMGF52OVCR98crlOZF7ZvHH3hvxGU0QOIdeSNiaSKd0bebWHvAvX7td/M/k7//qnmpwIwW5nX\
    hTcGtXsI/esni0qU+eH6p44mCOh8kmhtc9hvJqwhAriZtyZBWyVgrtBIGu4G",
    //Entrust Root Certification Authority - G2
    "MIIEPjCCAyagAwIBAgIESlOMKDANBgkqhkiG9w0BAQsFADCBvjELMAkGA1UEBhMCVVMxFjAUBgNVBAoT\
    DUVudHJ1c3QsIEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVybXMxOTA3\
    BgNVBAsTMChjKSAyMDA5IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ugb25seTEyMDAG\
    A1UEAxMpRW50cnVzdCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzIwHhcNMDkwNzA3MTcy\
    NTU0WhcNMzAxMjA3MTc1NTU0WjCBvjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVudHJ1c3QsIEluYy4x\
    KDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVybXMxOTA3BgNVBAsTMChjKSAyMDA5\
    IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9yaXplZCB1c2Ugb25seTEyMDAGA1UEAxMpRW50cnVzdCBS\
    b290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5IC0gRzIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK\
    AoIBAQC6hLZy254Ma+KZ6TABp3bqMriVQRrJ2mFOWHLP/vaCeb9zYQYKpSfYs1/TRU4cctZOMvJyig/3\
    gxnQaoCAAEUesMfnmr8SVycco2gvCoe9amsOXmXzHHfV1IWNcCG0szLni6LVhjkCsbjSR87kyUnEO6fe\
    +1R9V77w6G7CebI6C1XiUJgWMhNcL3hWwcKUs/Ja5CeanyTXxuzQmyWC48zCxEXFjJd6BmsqEZ+pCm5I\
    O2/b1BEZQvePB7/1U1+cPvQXLOZprE4yTGJ36rfo5bs0vBmLrpxR57d+tVOxMyLlbc9wPBr64ptntoP0\
    jaWvYkxN4FisZDQSA/i2jZRjJKRxAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNVHRMBAf8EBTAD\
    AQH/MB0GA1UdDgQWBBRqciZ60B7vfec7aVHUbI2fkBJmqzANBgkqhkiG9w0BAQsFAAOCAQEAeZ8dlsa2\
    eT8ijYfThwMEYGprmi5ZiXMRrEPR9RP/jTkrwPK9T3CMqS/qF8QLVJ7UG5aYMzyorWKiAHarWWluBh1+\
    xLlEjZivEtRh2woZRkfz6/djwUAFQKXSt/S1mja/qYh2iARVBCuch38aNzx+LaUa2NSJXsq9rD1s2G2v\
    1fN2D807iDginWyTmsQ9v4IbZT+mD12q/OWyFcq1rca8PdCE6OoGcrBNOTJ4vz4RnAuknZoh8/CbCzB4\
    28Hch0P+vGOaysXCHMnHjf87ElgI5rY97HosTvuDls4MPGmHVHOkc8KT/1EQrBVUAdj8BbGJoX90g5pJ\
    19xOe4pIb4tF9g==",
    //Entrust Root Certification Authority
    "MIIEkTCCA3mgAwIBAgIERWtQVDANBgkqhkiG9w0BAQUFADCBsDELMAkGA1UEBhMCVVMxFjAUBgNVBAoT\
    DUVudHJ1c3QsIEluYy4xOTA3BgNVBAsTMHd3dy5lbnRydXN0Lm5ldC9DUFMgaXMgaW5jb3Jwb3JhdGVk\
    IGJ5IHJlZmVyZW5jZTEfMB0GA1UECxMWKGMpIDIwMDYgRW50cnVzdCwgSW5jLjEtMCsGA1UEAxMkRW50\
    cnVzdCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTA2MTEyNzIwMjM0MloXDTI2MTEyNzIw\
    NTM0MlowgbAxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1FbnRydXN0LCBJbmMuMTkwNwYDVQQLEzB3d3cu\
    ZW50cnVzdC5uZXQvQ1BTIGlzIGluY29ycG9yYXRlZCBieSByZWZlcmVuY2UxHzAdBgNVBAsTFihjKSAy\
    MDA2IEVudHJ1c3QsIEluYy4xLTArBgNVBAMTJEVudHJ1c3QgUm9vdCBDZXJ0aWZpY2F0aW9uIEF1dGhv\
    cml0eTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALaVtkNC+sZtKm9I35RMOVcF7sN5EUFo\
    Nu3s/poBj6E4KPz3EEZmLk0eGrEaTsbRwJWIsMn/MYszA9u3g3s+IIRe7bJWKKf44LlAcTfFy0cOlypo\
    wCKVYhXbR9n10Cv/gkvJrT7eTNuQgFA/CYqEAOwwCj0Yzfv9KlmaI5UXLEWeH25DeW0MXJj+SKfFI0dc\
    Xv1u5x609mhF0YaDW6KKjbHjKYD+JXGIrb68j6xSlkuqUY3kEzEZ6E5Nn9uss2rVvDlUccp6en+Q3X0d\
    gNmBu1kmwhH+5pPi94DkZfs0Nw4pgHBNrziGLp5/V6+eF67rHMsoIV+2HNjnogQi+dPa2MsCAwEAAaOB\
    sDCBrTAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zArBgNVHRAEJDAigA8yMDA2MTEyNzIw\
    MjM0MlqBDzIwMjYxMTI3MjA1MzQyWjAfBgNVHSMEGDAWgBRokORnpKZTgMeGZqTx90tD+4S9bTAdBgNV\
    HQ4EFgQUaJDkZ6SmU4DHhmak8fdLQ/uEvW0wHQYJKoZIhvZ9B0EABBAwDhsIVjcuMTo0LjADAgSQMA0G\
    CSqGSIb3DQEBBQUAA4IBAQCT1DCw1wMgKtD5Y+iRDAUgqV8ZyntyTtSx29CW+1RaGSwMCPeyvIWonX9t\
    O1KzKtvn1ISMY/YPyyYBkVBs9F8U4pN0wBOeMDpQ47RgxRzwIkSNcUesyBrJ6ZuaAGAT/3B+XxFNSRuz\
    FVJ7yVTav52Vr2ua2J7p8eRDjeIRRDq/r72DQnNSi6q7pynP9WQcCk3RvKqsnyrQ/39/2n3qse0wJcGE\
    2jTSW3iDVuycNsMm4hH2Z0kdkquM++v/eu6FSqdQgPCnXEqULl8FmTxSQeDNtGPPAUO6nIPcj2A781q0\
    tHuu2guQOHXvgR1m0vdXcDazv/wor3ElhVsT/h5/WrQ8",
    //Entrust.net Certification Authority (2048)
    "MIIEKjCCAxKgAwIBAgIEOGPe+DANBgkqhkiG9w0BAQUFADCBtDEUMBIGA1UEChMLRW50cnVzdC5uZXQx\
    QDA+BgNVBAsUN3d3dy5lbnRydXN0Lm5ldC9DUFNfMjA0OCBpbmNvcnAuIGJ5IHJlZi4gKGxpbWl0cyBs\
    aWFiLikxJTAjBgNVBAsTHChjKSAxOTk5IEVudHJ1c3QubmV0IExpbWl0ZWQxMzAxBgNVBAMTKkVudHJ1\
    c3QubmV0IENlcnRpZmljYXRpb24gQXV0aG9yaXR5ICgyMDQ4KTAeFw05OTEyMjQxNzUwNTFaFw0yOTA3\
    MjQxNDE1MTJaMIG0MRQwEgYDVQQKEwtFbnRydXN0Lm5ldDFAMD4GA1UECxQ3d3d3LmVudHJ1c3QubmV0\
    L0NQU18yMDQ4IGluY29ycC4gYnkgcmVmLiAobGltaXRzIGxpYWIuKTElMCMGA1UECxMcKGMpIDE5OTkg\
    RW50cnVzdC5uZXQgTGltaXRlZDEzMDEGA1UEAxMqRW50cnVzdC5uZXQgQ2VydGlmaWNhdGlvbiBBdXRo\
    b3JpdHkgKDIwNDgpMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArU1LqRKGsuqjIAcVFmQq\
    K0vRvwtKTY7tgHalZ7d4QMBzQshowNtTK91euHaYNZOLGp18EzoOH1u3Hs/lJBQesYGpjX24zGtLA/EC\
    DNyrpUAkAH90lKGdCCmziAv1h3edVc3kw37XamSrhRSGlVuXMlBvPci6Zgzj/L24ScF2iUkZ/cCovYmj\
    Zy/Gn7xxGWC4LeksyZB2ZnuU4q941mVTXTzWnLLPKQP5L6RQstRIzgUyVYr9smRMDuSYB3Xbf9+5CFVg\
    hTAp+XtIpGmG4zU/HoZdenoVve8AjhUiVBcAkCaTvA5JaJG/+EfTnZVCwQ5N328mz8MYIWJmQ3DW1cAH\
    4QIDAQABo0IwQDAOBgNVHQ8BAf8EBAMCAQYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUVeSB0RGA\
    vtiJuQijMfmhJAkWuXAwDQYJKoZIhvcNAQEFBQADggEBADubj1abMOdTmXx6eadNl9cZlZD7Bh/KM3xG\
    Y4+WZiT6QBshJ8rmcnPyT/4xmf3IDExoU8aAghOY+rat2l098c5u9hURlIIM7j+VrxGrD9cv3h8Dj1cs\
    Hsm7mhpElesYT6YfzX1XEC+bBAlahLVu2B064dae0Wx5XnkcFMXj0EyTO2U87d89vqbllRrDtRnDvV5b\
    u/8j72gZyxKTJ1wDLW8w0B62GqzeWvfRqqgnpv55gcR5mTNXuhKwqeBCbJPKVt7+bYQLCIt+jerXmCHG\
    8+c8eS9enNFMFY3h7CI3zJpDC5fcgJCNs2ebb0gIFVbPv/ErfF6adulZkMV8gzURZVE=",
    //GeoTrust Global CA
    "MIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1H\
    ZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9iYWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcN\
    MjIwNTIxMDQwMDAwWjBCMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UE\
    AxMSR2VvVHJ1c3QgR2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9\
    9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdqfnGk5sRgprDvgOSJ\
    KA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDviS2Aelet8u5fa9IAjbkU+BQVNdnARqN7\
    csiRv8lVK83Qlz6cJmTM386DGXHKTubU1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmR\
    Cw7+OC7RHQWa9k0+bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW\
    MPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTAephojYn7qwVkDBF9\
    qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1luMrMTjANBgkqhkiG9w0BAQUFAAOCAQEA\
    NeMpauUvXVSOKVCUn5kaFOSPeCpilKInZ57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz\
    /Tt1kL/6cdjHPTfStQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF\
    PseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Unhw4EbNX/3aBd7YdS\
    tysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV5fEWCRE11azbJHFwLJhWC9kXtNHjUSte\
    dejV0NxPNO3CBWaAocvmMw==",
    //GeoTrust Primary Certification Authority - G2
    "MIICrjCCAjWgAwIBAgIQPLL0SAoA4v7rJDteYD7DazAKBggqhkjOPQQDAzCBmDELMAkGA1UEBhMCVVMx\
    FjAUBgNVBAoTDUdlb1RydXN0IEluYy4xOTA3BgNVBAsTMChjKSAyMDA3IEdlb1RydXN0IEluYy4gLSBG\
    b3IgYXV0aG9yaXplZCB1c2Ugb25seTE2MDQGA1UEAxMtR2VvVHJ1c3QgUHJpbWFyeSBDZXJ0aWZpY2F0\
    aW9uIEF1dGhvcml0eSAtIEcyMB4XDTA3MTEwNTAwMDAwMFoXDTM4MDExODIzNTk1OVowgZgxCzAJBgNV\
    BAYTAlVTMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMTkwNwYDVQQLEzAoYykgMjAwNyBHZW9UcnVzdCBJ\
    bmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxNjA0BgNVBAMTLUdlb1RydXN0IFByaW1hcnkgQ2Vy\
    dGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHMjB2MBAGByqGSM49AgEGBSuBBAAiA2IABBWx6P0DFUPlrOuH\
    NxFi79KDNlJ9RVcLSo17VDs6bl8VAsBQps8lL33KSLjHUGMcKiEIfJo22Av+0SbFWDEwKCXzXV2juLal\
    tJLtbCyf691DiaI8S0iRHVDsJt/WYC69IaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC\
    AQYwHQYDVR0OBBYEFBVfNVdRVfslsq0DafwBo/q+EVXVMAoGCCqGSM49BAMDA2cAMGQCMGSWWaboCd6L\
    uvpaiIjwH5HTRqjySkwCY/tsXzjbLkGTqQ7mndwxHLKgpxgceeHHNgIwOlavmnRs9vuD4DPTCF+hnMJb\
    n0bWtsuRBmOiBuczrD6ogRLQy7rQkgu2npaqBA+K",
    //GeoTrust Primary Certification Authority - G3
    "MIID/jCCAuagAwIBAgIQFaxulBmyeUtB9iepwxgPHzANBgkqhkiG9w0BAQsFADCBmDELMAkGA1UEBhMC\
    VVMxFjAUBgNVBAoTDUdlb1RydXN0IEluYy4xOTA3BgNVBAsTMChjKSAyMDA4IEdlb1RydXN0IEluYy4g\
    LSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTE2MDQGA1UEAxMtR2VvVHJ1c3QgUHJpbWFyeSBDZXJ0aWZp\
    Y2F0aW9uIEF1dGhvcml0eSAtIEczMB4XDTA4MDQwMjAwMDAwMFoXDTM3MTIwMTIzNTk1OVowgZgxCzAJ\
    BgNVBAYTAlVTMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMTkwNwYDVQQLEzAoYykgMjAwOCBHZW9UcnVz\
    dCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxNjA0BgNVBAMTLUdlb1RydXN0IFByaW1hcnkg\
    Q2VydGlmaWNhdGlvbiBBdXRob3JpdHkgLSBHMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB\
    ANziXmJYHTNXOTIz+uvLh4yn1ErdBojqZI4xmKU4kB6Yzy5jK/BGvESyiaHAKAxJcCGVn2TAppMSAmUm\
    hsalifD614SgcK9PGpc/BkTVyetyEH3kMSj7HGHmKAdEc5IiaacDiGydY8hS2pgn5whMcD60yRLBxWeD\
    XTPzAxHsatBT4tG6NmCUgLthY2xbF37fQJQeqw3CIShwiP/WJmxsYAQlTlV+fe+/lEjetx3dcI0FX4il\
    m/LC7urRQEFtYjgdVgbFA0dRIBn8exALDmKudlW/X3e+PkkBUz2YJQN2JFodtNuJ6nnltrM7P7pMKEF/\
    BqxqjsHQ9gUdfeZChuOl1UcCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYw\
    HQYDVR0OBBYEFMR5yo6hTgMdHNxr2zFblD4/MH8tMA0GCSqGSIb3DQEBCwUAA4IBAQAtxRPPVoB7eni9\
    n64smefv2t+UXglpp+duaIy9cr5HqQ6XErhK8WTTOd8lNNTBzU6B8A8ExCSzNJbGpqow32hhc9f5joWJ\
    7w5elShKKiePEI4ufIbEAp7aDHdlDkQNkv39sxY2+hENHYwOB4lqKVb3cvTdFZx3NWZXqxNT2I7BQMXX\
    ExZacse3aQHEerGDAWh9jUGhlBjBJVz88P6DAod8DQ3PLghcSkANPuyBYeYk28rgDi0Hsj5W3I31QYUH\
    SJsMC8tJP33st/3LjWeJGqvtux6jAAgIFyqCXDFdRootD4abdNlF+9RAsXqqaC2Gspki4cErx5z481+o\
    ghLrGREt",
    //GeoTrust Primary Certification Authority
    "MIIDfDCCAmSgAwIBAgIQGKy1av1pthU6Y2yv2vrEoTANBgkqhkiG9w0BAQUFADBYMQswCQYDVQQGEwJV\
    UzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjExMC8GA1UEAxMoR2VvVHJ1c3QgUHJpbWFyeSBDZXJ0aWZp\
    Y2F0aW9uIEF1dGhvcml0eTAeFw0wNjExMjcwMDAwMDBaFw0zNjA3MTYyMzU5NTlaMFgxCzAJBgNVBAYT\
    AlVTMRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMTEwLwYDVQQDEyhHZW9UcnVzdCBQcmltYXJ5IENlcnRp\
    ZmljYXRpb24gQXV0aG9yaXR5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvrgVe//UfH1n\
    rYNke8hCUy3f9oQIIGHWAVlqnEQRr+92/ZV+zmEwu3qDXwK9AWbK7hWNb6EwnL2hhZ6UOvNWiAAxz9ju\
    apYC2e0DjPt1befquFUWBRaa9OBesYjAZIVcFU2Ix7e64HXprQU9nceJSOC7KMgD4TCTZF5SwFlwIjVX\
    iIrxlQqD17wxcwE07e9GceBrAqg1cmuXm2bgyxx5X9gaBGgeRwLmnWDiNpcB3841kt++Z8dtd1k7j53W\
    kBWUvEI0EME5+bEnPn7WinXFsq+W06Lem+SYvn3h6YGttm/81w7a4DSwDRp35+MImO9Y+pyEtzavwt+s\
    0vQQBnBxNQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQU\
    LNVQQZcVi/CPNmFbSvtr2ZnJM5IwDQYJKoZIhvcNAQEFBQADggEBAFpwfyzdtzRP9YZRqSa+S7iq8XEN\
    3GHHoOo0Hnp3DwQ16CePbJC/kRYkRj5KTs4rFtULUh38H2eiAkUxT87z+gOneZ1TatnaYzr4gNfTmeGl\
    4b7UVXGYNTq+k+qurUKykG/g/CFNNWMziUnWm07Kx+dOCQD32sfvmWKZd7aVIl6KoKv0uHiYyjgZmcly\
    nnjNS6yvGaBzEi38wkG6gZHaFloxt/m0cYASSJlyc1pZU8FjUjPtp8nSOQJw+uCxQmYpqptR7TBUIhRf\
    2asdweSU8Pj1K/fqynhG1riR/aYNKxoUAT6A8EKglQdebc3MS6RFjasS6LPeWuWgfOgPIh1a6Vk=",
    //Go Daddy Class 2 Certification Authority
    "MIIEADCCAuigAwIBAgIBADANBgkqhkiG9w0BAQUFADBjMQswCQYDVQQGEwJVUzEhMB8GA1UEChMYVGhl\
    IEdvIERhZGR5IEdyb3VwLCBJbmMuMTEwLwYDVQQLEyhHbyBEYWRkeSBDbGFzcyAyIENlcnRpZmljYXRp\
    b24gQXV0aG9yaXR5MB4XDTA0MDYyOTE3MDYyMFoXDTM0MDYyOTE3MDYyMFowYzELMAkGA1UEBhMCVVMx\
    ITAfBgNVBAoTGFRoZSBHbyBEYWRkeSBHcm91cCwgSW5jLjExMC8GA1UECxMoR28gRGFkZHkgQ2xhc3Mg\
    MiBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASAwDQYJKoZIhvcNAQEBBQADggENADCCAQgCggEBAN6d\
    1+pXGEmhW+vXX0iG6r7d/+TvZxz0ZWizV3GgXne77ZtJ6XCAPVYYYwhv2vLM0D9/AlQiVBDYsoHUwHU9\
    S3/Hd8M+eKsaA7Ugay9qK7HFiH7Eux6wwdhFJ2+qN1j3hybX2C32qRe3H3I2TqYXP2WYktsqbl2i/ojg\
    C95/5Y0V4evLOtXiEqITLdiOr18SPaAIBQi2XKVlOARFmR6jYGB0xUGlcmIbYsUfb18aQr4CUWWoriMY\
    avx4A6lNf4DD+qta/KFApMoZFv6yyO9ecw3ud72a9nmYvLEHZ6IVDd2gWMZEewo+YihfukEHU1jPEX44\
    dMX4/7VpkI+EdOqXG68CAQOjgcAwgb0wHQYDVR0OBBYEFNLEsNKR1EwRcbNhyz2h/t2oatTjMIGNBgNV\
    HSMEgYUwgYKAFNLEsNKR1EwRcbNhyz2h/t2oatTjoWekZTBjMQswCQYDVQQGEwJVUzEhMB8GA1UEChMY\
    VGhlIEdvIERhZGR5IEdyb3VwLCBJbmMuMTEwLwYDVQQLEyhHbyBEYWRkeSBDbGFzcyAyIENlcnRpZmlj\
    YXRpb24gQXV0aG9yaXR5ggEAMAwGA1UdEwQFMAMBAf8wDQYJKoZIhvcNAQEFBQADggEBADJL87LKPpH8\
    EsahB4yOd6AzBhRckB4Y9wimPQoZ+YeAEW5p5JYXMP80kWNyOO7MHAGjHZQopDH2esRU1/blMVgDoszO\
    YtuURXO1v0XJJLXVggKtI3lpjbi2Tc7PTMozI+gciKqdi0FuFskg5YmezTvacPd+mSYgFFQlq25zheab\
    IZ0KbIIOqPjCDPoQHmyW74cNxA9hi63ugyuV+I6ShHI56yDqg+2DzZduCLzrTia2cyvk0/ZM/iZx4mER\
    dEr/VxqHD3VILs9RaRegAhJhldXRQLIQTO7ErBBDpqWeCtWVYpoNz4iCxTIM5CufReYNnyicsbkqWlet\
    Nw+vHX/bvZ8=",
    //Go Daddy Root Certificate Authority - G2
    "MIIDxTCCAq2gAwIBAgIBADANBgkqhkiG9w0BAQsFADCBgzELMAkGA1UEBhMCVVMxEDAOBgNVBAgTB0Fy\
    aXpvbmExEzARBgNVBAcTClNjb3R0c2RhbGUxGjAYBgNVBAoTEUdvRGFkZHkuY29tLCBJbmMuMTEwLwYD\
    VQQDEyhHbyBEYWRkeSBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAtIEcyMB4XDTA5MDkwMTAwMDAw\
    MFoXDTM3MTIzMTIzNTk1OVowgYMxCzAJBgNVBAYTAlVTMRAwDgYDVQQIEwdBcml6b25hMRMwEQYDVQQH\
    EwpTY290dHNkYWxlMRowGAYDVQQKExFHb0RhZGR5LmNvbSwgSW5jLjExMC8GA1UEAxMoR28gRGFkZHkg\
    Um9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgLSBHMjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC\
    ggEBAL9xYgjx+lk09xvJGKP3gElY6SKDE6bFIEMBO4Tx5oVJnyfq9oQbTqC023CYxzIBsQU+B07u9PpP\
    L1kwIuerGVZr4oAH/PMWdYA5UXvl+TW2dE6pjYIT5LY/qQOD+qK+ihVqf94Lw7YZFAXK6sOoBJQ7Rnwy\
    DfMAZiLIjWltNowRGLfTshxgtDj6AozO091GB94KPutdfMh8+7ArU6SSYmlRJQVhGkSBjCypQ5Yj36w6\
    gZoOKcUcqeldHraenjAKOc7xiID7S13MMuyFYkMlNAJWJwGRtDtwKj9useiciAF9n9T521NtYJ2/LOdY\
    q7hfRvzOxBsDPAnrSTFcaUaz4EcCAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMC\
    AQYwHQYDVR0OBBYEFDqahQcQZyi27/a9BUFuIMGU2g/eMA0GCSqGSIb3DQEBCwUAA4IBAQCZ21151fmX\
    WWcDYfF+OwYxdS2hII5PZYe096acvNjpL9DbWu7PdIxztDhC2gV7+AJ1uP2lsdeu9tfeE8tTEH6KRtGX\
    +rcuKxGrkLAngPnon1rpN5+r5N9ss4UXnT3ZJE95kTXWXwTrgIOrmgIttRD02JDHBHNA7XIloKmf7J6r\
    aBKZV8aPEjoJpL1E/QYVN8Gb5DKj7Tjo2GTzLH4U/ALqn83/B2gX2yKQOC16jdFU8WnjXzPKej17CuPK\
    f1855eJ1usV2GDPOLPAvTK33sefOT6jEm0pUBsV/fdUID+Ic/n4XuKxe9tQWskMJDE32p2u0mYRlynqI\
    4uJEvlz36hz1",
    //Go Daddy Secure Certification Authority serialNumber=07969287
    "MIIE3jCCA8agAwIBAgICAwEwDQYJKoZIhvcNAQEFBQAwYzELMAkGA1UEBhMCVVMxITAfBgNVBAoTGFRo\
    ZSBHbyBEYWRkeSBHcm91cCwgSW5jLjExMC8GA1UECxMoR28gRGFkZHkgQ2xhc3MgMiBDZXJ0aWZpY2F0\
    aW9uIEF1dGhvcml0eTAeFw0wNjExMTYwMTU0MzdaFw0yNjExMTYwMTU0MzdaMIHKMQswCQYDVQQGEwJV\
    UzEQMA4GA1UECBMHQXJpem9uYTETMBEGA1UEBxMKU2NvdHRzZGFsZTEaMBgGA1UEChMRR29EYWRkeS5j\
    b20sIEluYy4xMzAxBgNVBAsTKmh0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9y\
    eTEwMC4GA1UEAxMnR28gRGFkZHkgU2VjdXJlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MREwDwYDVQQF\
    EwgwNzk2OTI4NzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMQt1RWMnCZM7DI161+4WQFa\
    pmGBWTtwY6vj3D3HKrjJM9N55DrtPDAjhI6zMBS2sofDPZVUBJ7fmd0LJR4h3mUpfjWoqVTr9vcyOdQm\
    VZWt7/v+WIbXnvQAjYwqDL1CBM6nPwT27oDyqu9SoWlm2r4arV3aLGbqGmu75RpRSgAvSMeYddi5Kcju\
    +GZtCpyz8/x4fKL4o/K1w/O5epHBp+YlLpyo7RJlbmr2EkRTcDCVw5wrWCs9CHRK8r5RsL+H0EwnWGu1\
    NcWdrxcx+AuP7q2BNgWJCJjPOq8lh8BJ6qf9Z/dFjpfMFDniNoW1fho3/Rb2cRGadDAW/hOUoz+EDU8C\
    AwEAAaOCATIwggEuMB0GA1UdDgQWBBT9rGEyk2xF1uLuhV+auud2mWjM5zAfBgNVHSMEGDAWgBTSxLDS\
    kdRMEXGzYcs9of7dqGrU4zASBgNVHRMBAf8ECDAGAQH/AgEAMDMGCCsGAQUFBwEBBCcwJTAjBggrBgEF\
    BQcwAYYXaHR0cDovL29jc3AuZ29kYWRkeS5jb20wRgYDVR0fBD8wPTA7oDmgN4Y1aHR0cDovL2NlcnRp\
    ZmljYXRlcy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5L2dkcm9vdC5jcmwwSwYDVR0gBEQwQjBABgRVHSAA\
    MDgwNgYIKwYBBQUHAgEWKmh0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20vcmVwb3NpdG9yeTAO\
    BgNVHQ8BAf8EBAMCAQYwDQYJKoZIhvcNAQEFBQADggEBANKGwOy9+aG2Z+5mC6IGOgRQjhVyrEp0lVPL\
    N8tESe8HkGsz2ZbwlFalEzAFPIUyIXvJxwqoJKSQ3kbTJSMUA2fCENZvD117esyfxVgqwcSeIaha86yk\
    RvOe5GPLL5CkKSkB2XIsKd83ASe8T+5o0yGPwLPk9Qnt0hCqU7S+8MxZC9Y7lhyVJEnfzuz9p0iRFEUO\
    OjZv2kWzRaJBydTXRE4+uXR21aITVSzGh6O1mawGhId/dQb8vxRMDsxuxN89txJx9OjxUUAiKEngHUuH\
    qDTMBqLdElrRhjZkAzVvb3du6/KFUJheqwNTrZEjYx8WnM25sgVjOuH0aBsXBTWVU+4=",
    //Go Daddy Secure Server Certificate (Cross Intermediate Certificate)
    "MIIE+zCCBGSgAwIBAgICAQ0wDQYJKoZIhvcNAQEFBQAwgbsxJDAiBgNVBAcTG1ZhbGlDZXJ0IFZhbGlk\
    YXRpb24gTmV0d29yazEXMBUGA1UEChMOVmFsaUNlcnQsIEluYy4xNTAzBgNVBAsTLFZhbGlDZXJ0IENs\
    YXNzIDIgUG9saWN5IFZhbGlkYXRpb24gQXV0aG9yaXR5MSEwHwYDVQQDExhodHRwOi8vd3d3LnZhbGlj\
    ZXJ0LmNvbS8xIDAeBgkqhkiG9w0BCQEWEWluZm9AdmFsaWNlcnQuY29tMB4XDTA0MDYyOTE3MDYyMFoX\
    DTI0MDYyOTE3MDYyMFowYzELMAkGA1UEBhMCVVMxITAfBgNVBAoTGFRoZSBHbyBEYWRkeSBHcm91cCwg\
    SW5jLjExMC8GA1UECxMoR28gRGFkZHkgQ2xhc3MgMiBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTCCASAw\
    DQYJKoZIhvcNAQEBBQADggENADCCAQgCggEBAN6d1+pXGEmhW+vXX0iG6r7d/+TvZxz0ZWizV3GgXne7\
    7ZtJ6XCAPVYYYwhv2vLM0D9/AlQiVBDYsoHUwHU9S3/Hd8M+eKsaA7Ugay9qK7HFiH7Eux6wwdhFJ2+q\
    N1j3hybX2C32qRe3H3I2TqYXP2WYktsqbl2i/ojgC95/5Y0V4evLOtXiEqITLdiOr18SPaAIBQi2XKVl\
    OARFmR6jYGB0xUGlcmIbYsUfb18aQr4CUWWoriMYavx4A6lNf4DD+qta/KFApMoZFv6yyO9ecw3ud72a\
    9nmYvLEHZ6IVDd2gWMZEewo+YihfukEHU1jPEX44dMX4/7VpkI+EdOqXG68CAQOjggHhMIIB3TAdBgNV\
    HQ4EFgQU0sSw0pHUTBFxs2HLPaH+3ahq1OMwgdIGA1UdIwSByjCBx6GBwaSBvjCBuzEkMCIGA1UEBxMb\
    VmFsaUNlcnQgVmFsaWRhdGlvbiBOZXR3b3JrMRcwFQYDVQQKEw5WYWxpQ2VydCwgSW5jLjE1MDMGA1UE\
    CxMsVmFsaUNlcnQgQ2xhc3MgMiBQb2xpY3kgVmFsaWRhdGlvbiBBdXRob3JpdHkxITAfBgNVBAMTGGh0\
    dHA6Ly93d3cudmFsaWNlcnQuY29tLzEgMB4GCSqGSIb3DQEJARYRaW5mb0B2YWxpY2VydC5jb22CAQEw\
    DwYDVR0TAQH/BAUwAwEB/zAzBggrBgEFBQcBAQQnMCUwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLmdv\
    ZGFkZHkuY29tMEQGA1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jZXJ0aWZpY2F0ZXMuZ29kYWRkeS5jb20v\
    cmVwb3NpdG9yeS9yb290LmNybDBLBgNVHSAERDBCMEAGBFUdIAAwODA2BggrBgEFBQcCARYqaHR0cDov\
    L2NlcnRpZmljYXRlcy5nb2RhZGR5LmNvbS9yZXBvc2l0b3J5MA4GA1UdDwEB/wQEAwIBBjANBgkqhkiG\
    9w0BAQUFAAOBgQC1QPmnHfbq/qQaQlpE9xXUhUaJwL6e4+PrxeNYiY+Sn1eocSxI0YGyeR+sBjUZsE4O\
    WBsUs5iB0QQeyAfJg594RAoYC5jcdnplDQ1tgMQLARzLrUc+cb53S8wGd9D0VmsfSxOaFIqII6hR8INM\
    qzW/Rn453HWkrugp++85j09VZw==",
    //Thawte Premium Server CA
    "MIIDJzCCApCgAwIBAgIBATANBgkqhkiG9w0BAQQFADCBzjELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdl\
    c3Rlcm4gQ2FwZTESMBAGA1UEBxMJQ2FwZSBUb3duMR0wGwYDVQQKExRUaGF3dGUgQ29uc3VsdGluZyBj\
    YzEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBEaXZpc2lvbjEhMB8GA1UEAxMYVGhhd3Rl\
    IFByZW1pdW0gU2VydmVyIENBMSgwJgYJKoZIhvcNAQkBFhlwcmVtaXVtLXNlcnZlckB0aGF3dGUuY29t\
    MB4XDTk2MDgwMTAwMDAwMFoXDTIwMTIzMTIzNTk1OVowgc4xCzAJBgNVBAYTAlpBMRUwEwYDVQQIEwxX\
    ZXN0ZXJuIENhcGUxEjAQBgNVBAcTCUNhcGUgVG93bjEdMBsGA1UEChMUVGhhd3RlIENvbnN1bHRpbmcg\
    Y2MxKDAmBgNVBAsTH0NlcnRpZmljYXRpb24gU2VydmljZXMgRGl2aXNpb24xITAfBgNVBAMTGFRoYXd0\
    ZSBQcmVtaXVtIFNlcnZlciBDQTEoMCYGCSqGSIb3DQEJARYZcHJlbWl1bS1zZXJ2ZXJAdGhhd3RlLmNv\
    bTCBnzANBgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA0jY2aovXwlue2oFBYo847kkEVdbQ7xwblRZH7xhI\
    NTpS9CtqBo87L+pW46+GjZ4X9560ZXUCTe/LCaIhUdib0GfQug2SBhRz1JPLlyoAnFxODLz6FVL88kRu\
    2hFKbgifLy3j+ao6hnO2RlNYyIkFvYMRuHM/qgeN9EJN50CdHDcCAwEAAaMTMBEwDwYDVR0TAQH/BAUw\
    AwEB/zANBgkqhkiG9w0BAQQFAAOBgQAmSCwWwlj66BZ0DKqqX1Q/8tfJeGBeXm43YyJ3Nn6yF8Q0ufUI\
    hfzJATj/Tb7yFkJD57taRvvBxhEf8UqwKEbJw8RCfbz6q1lu1bdRiBHjpIUZa4JMpAwSremkrj/xw0ll\
    mozFyD4lt5SZu5IycQfwhl7tUCemDaYj+bvLpgcUQg==",
    //Thawte Primary Root CA - G2
    "MIICiDCCAg2gAwIBAgIQNfwmXNmET8k9Jj1Xm67XVjAKBggqhkjOPQQDAzCBhDELMAkGA1UEBhMCVVMx\
    FTATBgNVBAoTDHRoYXd0ZSwgSW5jLjE4MDYGA1UECxMvKGMpIDIwMDcgdGhhd3RlLCBJbmMuIC0gRm9y\
    IGF1dGhvcml6ZWQgdXNlIG9ubHkxJDAiBgNVBAMTG3RoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EgLSBHMjAe\
    Fw0wNzExMDUwMDAwMDBaFw0zODAxMTgyMzU5NTlaMIGEMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMdGhh\
    d3RlLCBJbmMuMTgwNgYDVQQLEy8oYykgMjAwNyB0aGF3dGUsIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1\
    c2Ugb25seTEkMCIGA1UEAxMbdGhhd3RlIFByaW1hcnkgUm9vdCBDQSAtIEcyMHYwEAYHKoZIzj0CAQYF\
    K4EEACIDYgAEotWcgnuVnfFSeIf+iha/BebfowJPDQfGAFG6DAJSLSKkQjnE/o/qycG+1E3/n3qe4rF8\
    mq2nhglzh9HnmuN6papu+7qzcMBniKI11KOasf2twu8x+qi58/sIxpHR+ymVo0IwQDAPBgNVHRMBAf8E\
    BTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUmtgAMADna3+FGO6Lts6KDPgR4bswCgYIKoZI\
    zj0EAwMDaQAwZgIxAN344FdHW6fmCsO99YCKlzUNG4k8VIZ3KMqh9HneteY4sPBlcIx/AlTCv//YoT7Z\
    zwIxAMSNlPzcU9LcnXgWHxUzI1NS41oxXZ3Krr0TKUQNJ1uo52icEvdYPy5yAlejj6EULg==",
    //Thawte Primary Root CA - G3
    "MIIEKjCCAxKgAwIBAgIQYAGXt0an6rS0mtZLL/eQ+zANBgkqhkiG9w0BAQsFADCBrjELMAkGA1UEBhMC\
    VVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBE\
    aXZpc2lvbjE4MDYGA1UECxMvKGMpIDIwMDggdGhhd3RlLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNl\
    IG9ubHkxJDAiBgNVBAMTG3RoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EgLSBHMzAeFw0wODA0MDIwMDAwMDBa\
    Fw0zNzEyMDEyMzU5NTlaMIGuMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMdGhhd3RlLCBJbmMuMSgwJgYD\
    VQQLEx9DZXJ0aWZpY2F0aW9uIFNlcnZpY2VzIERpdmlzaW9uMTgwNgYDVQQLEy8oYykgMjAwOCB0aGF3\
    dGUsIEluYy4gLSBGb3IgYXV0aG9yaXplZCB1c2Ugb25seTEkMCIGA1UEAxMbdGhhd3RlIFByaW1hcnkg\
    Um9vdCBDQSAtIEczMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAsr8nLPvb2FvdeHsbnndm\
    gcs+vHyu86YnmjSjaDFxODNi5PNxZnmxqWWjpYvVj2AtP0LMqmsywCPLLEHd5N/8YZzic7IilRFDGF/E\
    th9XbAoFWCLINkw6fKXRz4aviKdEAhN0cXMKQlkC+BsUa0Lfb1+6a4KinVvnSr0eAXLbS3ToO39/fR8E\
    tCab4LRarEc9VbjXsCZSKAExQGbY2SS99irY7CFJXJv2eul/VTV+lmuNk5Mny5K76qxAwJ/C+IDPXfRa\
    3M50hqY+bAtTyr2SzhkGcuYMXDhpxwTWvGzOW/b3aJzcJRVIiKHpqfiYnODz1TEoYRFsZ5aNOZnLwkUk\
    OQIDAQABo0IwQDAPBgNVHRMBAf8EBTADAQH/MA4GA1UdDwEB/wQEAwIBBjAdBgNVHQ4EFgQUrWyqlGCc\
    7eT/+j4KdCtjA/e2Wb8wDQYJKoZIhvcNAQELBQADggEBABpA2JVlrAmSicY59BDlqQ5mU1143vokkbvn\
    RFHfxhY0Cu9qRFHqKweKA3rD6z8KLFIWoCtDuSWQP3CpMyVtRRooOyfPqsMpQhvfO0zAMzRbQYi/aytl\
    ryjvsvXDqmbOe1but8jLZ8HJnBoYuMTDSQPxYA5QzUbF83d597YV4Djbxy8ooAw/dyZ02SUS2jHaGh7c\
    KUGRIjxpp7sC8rZcJwOJ9Abqm+RyguOhCcHpABnTPtRwa7pxpqpYrvS76Wy274fMm7v/OeZWYdMKp8Rc\
    TGB7BXcmer/YB1IsYvdwY9k5vG8cwnncdimvzsUsZAReiDZuMdRAGmI0Nj81Aa6sY6A=",
    //Thawte Primary Root CA
    "MIIEIDCCAwigAwIBAgIQNE7VVyDV7exJ9C/ON9srbTANBgkqhkiG9w0BAQUFADCBqTELMAkGA1UEBhMC\
    VVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYGA1UECxMfQ2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBE\
    aXZpc2lvbjE4MDYGA1UECxMvKGMpIDIwMDYgdGhhd3RlLCBJbmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNl\
    IG9ubHkxHzAdBgNVBAMTFnRoYXd0ZSBQcmltYXJ5IFJvb3QgQ0EwHhcNMDYxMTE3MDAwMDAwWhcNMzYw\
    NzE2MjM1OTU5WjCBqTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDHRoYXd0ZSwgSW5jLjEoMCYGA1UECxMf\
    Q2VydGlmaWNhdGlvbiBTZXJ2aWNlcyBEaXZpc2lvbjE4MDYGA1UECxMvKGMpIDIwMDYgdGhhd3RlLCBJ\
    bmMuIC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxHzAdBgNVBAMTFnRoYXd0ZSBQcmltYXJ5IFJvb3Qg\
    Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCsoPD7gFnUnMekz52hWXMJEEUMDSxuaPFs\
    W0hoSVk3/AszGcJ3f8wQLZU0HObrTQmnHNK4yZc2AreJ1CRfBsDMRJSUjQJib+ta3RGNKJpchJAQeg29\
    dGYvajig4tVUROsdB58Hum/u6f1OCyn1PoSgAfGcq/gcfomk6KHYcWUNo1F77rzSImANuVud37r8UVsL\
    r5iy6S7pBOhih94ryNdOwUxkHt3Ph1i6Sk/KaAcdHJ1KxtUvkcx8cXIcxcBn6zL9yZJclNqFwJu/U30r\
    CfSMnZEfl2pSy94JNqR32HuHUETVPm4pafs5SSYeCaWAe0At6+gnhcn+Yf1+5nyXHdWdAgMBAAGjQjBA\
    MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMB0GA1UdDgQWBBR7W0XPr87Lev0xkhpqtvNG\
    61dIUDANBgkqhkiG9w0BAQUFAAOCAQEAeRHAS7ORtvzw6WfUDW5FvlXok9LOAz/t2iWwHVfLHjp2oEzs\
    UHboZHIMpKnxuIvW1oeEuzLlQRHAd9mzYJ3rG9XRbkREqaYB7FViHXe4XI5ISXycO1cRrK1zN44veFyQ\
    aEfZYGDm/Ac9IiAXxPcW6cTYcvnIc3zfFi8VqT79aie2oetaupgf1eNNZAqdE8hhuvU5HIe6uL17In/2\
    /qxAeeWsEG89jxt5dovEN7MhGITlNgDrYyCZuen+MwS7QcjBAvlEYyCegc5C09Y/LHbTY5xZ3Y+m4Q6g\
    LkH3LpVHz7z9M/P2C2F+fpErgUfCJzDupxBdN49cOSvkBPB7jVaMaA=="
};
static const size_t kMaxCertLen = 10000;
static NSMutableArray * volatile sRootCerts = NULL;

// Static method returning NSArray with Dropbox root certificates
+ (NSArray *)rootCertificates {
    if (sRootCerts != NULL)
        return sRootCerts;
    @synchronized ([DBRequest class]) {
        if (sRootCerts == NULL) {
            NSMutableArray *certs = [NSMutableArray array];
            for (int i=0; i < sizeof(kBase64RootCerts)/sizeof(kBase64RootCerts[0]); i++) {
                size_t base64CertLen = strnlen(kBase64RootCerts[i], kMaxCertLen);
                size_t derCertLen = DBEstimateBas64DecodedDataSize(base64CertLen);
                char derCert[derCertLen];
                bool success = DBBase64DecodeData(kBase64RootCerts[i], base64CertLen, derCert, &derCertLen);
                if (!success) {
                    DBLogError(@"Root certificate base64 decoding failed!");
                    continue;
                }
                CFDataRef rawCert = CFDataCreate(kCFAllocatorDefault, (const UInt8 *)derCert, derCertLen);
                SecCertificateRef cert = SecCertificateCreateWithData (kCFAllocatorDefault, rawCert);
                if (cert == NULL) {
                    DBLogError(@"Invalid root certificate!");
                    CFRelease(rawCert);
                    continue;
                }
                CFRelease(rawCert);
                [certs addObject:(id)cert];
                CFRelease(cert);
            }
            sRootCerts = [certs retain];
        }
    }
    return sRootCerts;
}
@end


//
//  DBRestClient.m
//  DropboxSDK
//
//  Created by Brian Smith on 4/9/10.
//  Copyright 2010 Dropbox, Inc. All rights reserved.
//

#import "DBRestClient.h"

#import "DBAccountInfo.h"
#import "DBError.h"
#import "DBDeltaEntry.h"
#import "DBLog.h"
#import "DBMetadata.h"
#import "DBRequest.h"
#import "MPOAuthURLRequest.h"
#import "MPURLRequestParameter.h"
#import "MPOAuthSignatureParameter.h"
#import "NSString+URLEscapingAdditions.h"


@interface DBRestClient ()

// This method escapes all URI escape characters except /
+ (NSString*)escapePath:(NSString*)path;

+ (NSString *)bestLanguage;

+ (NSString *)userAgent;

- (NSMutableURLRequest*)requestWithHost:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params;

- (NSMutableURLRequest*)requestWithHost:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params method:(NSString*)method;

- (void)checkForAuthenticationFailure:(DBRequest*)request;

@property (nonatomic, readonly) MPOAuthCredentialConcreteStore *credentialStore;

@end


@interface DBMetadata ()

+ (NSDateFormatter *)dateFormatter;

@end


@implementation DBRestClient

- (id)initWithSession:(DBSession*)aSession userId:(NSString *)theUserId {
    if (!aSession) {
        DBLogError(@"DropboxSDK: cannot initialize a DBRestClient with a nil session");
        return nil;
    }

    if ((self = [super init])) {
        session = [aSession retain];
        userId = [theUserId retain];
        root = [aSession.root retain];
        requests = [[NSMutableSet alloc] init];
        loadRequests = [[NSMutableDictionary alloc] init];
        imageLoadRequests = [[NSMutableDictionary alloc] init];
        uploadRequests = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)initWithSession:(DBSession *)aSession {
    NSString *uid = [aSession.userIds count] > 0 ? [aSession.userIds objectAtIndex:0] : nil;
    return [self initWithSession:aSession userId:uid];
}


- (void)cancelAllRequests {
    for (DBRequest* request in requests) {
        [request cancel];
    }
    [requests removeAllObjects];

    for (DBRequest* request in [loadRequests allValues]) {
        [request cancel];
    }
    [loadRequests removeAllObjects];

    for (DBRequest* request in [imageLoadRequests allValues]) {
        [request cancel];
    }
    [imageLoadRequests removeAllObjects];

    for (DBRequest* request in [uploadRequests allValues]) {
        [request cancel];
    }
    [uploadRequests removeAllObjects];
}


- (void)dealloc {
    [self cancelAllRequests];
    [requests release];
    [loadRequests release];
    [imageLoadRequests release];
    [uploadRequests release];
    [session release];
    [userId release];
    [root release];
    [super dealloc];
}



@synthesize delegate;


- (void)loadMetadata:(NSString*)path withParams:(NSDictionary *)params
{
    NSString* fullPath = [NSString stringWithFormat:@"/metadata/%@%@", root, path];
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadMetadata:)]
         autorelease];
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:path forKey:@"path"];
    if (params) {
        [userInfo addEntriesFromDictionary:params];
    }
    request.userInfo = userInfo;

    [requests addObject:request];
}

- (void)loadMetadata:(NSString*)path
{
    [self loadMetadata:path withParams:nil];
}

- (void)loadMetadata:(NSString*)path withHash:(NSString*)hash {
    NSDictionary *params = nil;
    if (hash) {
        params = [NSDictionary dictionaryWithObject:hash forKey:@"hash"];
    }

    [self loadMetadata:path withParams:params];
}

- (void)loadMetadata:(NSString *)path atRev:(NSString *)rev {
    NSDictionary *params = nil;
    if (rev) {
        params = [NSDictionary dictionaryWithObject:rev forKey:@"rev"];
    }

    [self loadMetadata:path withParams:params];
}

- (void)requestDidLoadMetadata:(DBRequest*)request
{ 
    [[self retain] autorelease];

    if (request.statusCode == 304) {
        if ([delegate respondsToSelector:@selector(restClient:metadataUnchangedAtPath:)]) {
            NSString* path = [request.userInfo objectForKey:@"path"];
            [delegate restClient:self metadataUnchangedAtPath:path];
        }
    } else if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadMetadataFailedWithError:)]) {
            [delegate restClient:self loadMetadataFailedWithError:request.error];
        }
    } else {
        SEL sel = @selector(parseMetadataWithRequest:resultThread:);
        NSMethodSignature *sig = [self methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:self];
        [inv setSelector:sel];
        [inv setArgument:&request atIndex:2];
        NSThread *currentThread = [NSThread currentThread];
        [inv setArgument:&currentThread atIndex:3];
        [inv retainArguments];
        [inv performSelectorInBackground:@selector(invoke) withObject:nil];
    }

    [requests removeObject:request];
}


- (void)parseMetadataWithRequest:(DBRequest*)request resultThread:(NSThread *)thread {
    NSAutoreleasePool* pool = [NSAutoreleasePool new];
    
    NSDictionary* result = (NSDictionary*)[request resultJSON];
    DBMetadata* metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];
    if (metadata) {
        [self performSelector:@selector(didParseMetadata:) onThread:thread withObject:metadata waitUntilDone:NO];
    } else {
        [self performSelector:@selector(parseMetadataFailedForRequest:) onThread:thread
                   withObject:request waitUntilDone:NO];
    }
    
    [pool drain];
}


- (void)didParseMetadata:(DBMetadata*)metadata {
    if ([delegate respondsToSelector:@selector(restClient:loadedMetadata:)]) {
        [delegate restClient:self loadedMetadata:metadata];
    }
}

- (void)parseMetadataFailedForRequest:(DBRequest *)request {
    NSError *error = 
        [NSError errorWithDomain:DBErrorDomain code:DBErrorInvalidResponse userInfo:request.userInfo];
    DBLogWarning(@"DropboxSDK: error parsing metadata");
    if ([delegate respondsToSelector:@selector(restClient:loadMetadataFailedWithError:)]) {
        [delegate restClient:self loadMetadataFailedWithError:error];
    }
}


- (void)loadDelta:(NSString *)cursor {
    NSDictionary *params = nil;
    if (cursor) {
        params = [NSDictionary dictionaryWithObject:cursor forKey:@"cursor"];
    }

    NSString *fullPath = [NSString stringWithFormat:@"/delta"];
    NSMutableURLRequest* urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params method:@"POST"];

    DBRequest* request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadDelta:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}

- (void)requestDidLoadDelta:(DBRequest *)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadDeltaFailedWithError:)]) {
            [delegate restClient:self loadDeltaFailedWithError:request.error];
        }
    } else {
        SEL sel = @selector(parseDeltaWithRequest:resultThread:);
        NSMethodSignature *sig = [self methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:self];
        [inv setSelector:sel];
        [inv setArgument:&request atIndex:2];
        NSThread *currentThread = [NSThread currentThread];
        [inv setArgument:&currentThread atIndex:3];
        [inv retainArguments];
        [inv performSelectorInBackground:@selector(invoke) withObject:nil];
    }

    [requests removeObject:request];
}

- (void)parseDeltaWithRequest:(DBRequest *)request resultThread:(NSThread *)thread {
    NSAutoreleasePool* pool = [NSAutoreleasePool new];

    NSDictionary* result = [request parseResponseAsType:[NSDictionary class]];
    if (result) {
        NSArray *entryArrays = [result objectForKey:@"entries"];
        NSMutableArray *entries = [NSMutableArray arrayWithCapacity:[entryArrays count]];
        for (NSArray *entryArray in entryArrays) {
            DBDeltaEntry *entry = [[DBDeltaEntry alloc] initWithArray:entryArray];
            [entries addObject:entry];
            [entry release];
        }
        BOOL reset = [[result objectForKey:@"reset"] boolValue];
        NSString *cursor = [result objectForKey:@"cursor"];
        BOOL hasMore = [[result objectForKey:@"has_more"] boolValue];

        SEL sel = @selector(restClient:loadedDeltaEntries:reset:cursor:hasMore:);
        if ([delegate respondsToSelector:sel]) {
            NSMethodSignature *sig = [(NSObject *)delegate methodSignatureForSelector:sel];
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
            [inv setTarget:delegate];
            [inv setSelector:sel];
            [inv setArgument:&self atIndex:2];
            [inv setArgument:&entries atIndex:3];
            [inv setArgument:&reset atIndex:4];
            [inv setArgument:&cursor atIndex:5];
            [inv setArgument:&hasMore atIndex:6];
            [inv retainArguments];
            [inv performSelector:@selector(invoke) onThread:thread withObject:nil waitUntilDone:NO];
        }
    } else {
        [self performSelector:@selector(parseDeltaFailedForRequest:) onThread:thread
                   withObject:request waitUntilDone:NO];
    }

    [pool drain];
}

- (void)parseDeltaFailedForRequest:(DBRequest *)request {
    NSError *error =
        [NSError errorWithDomain:DBErrorDomain code:DBErrorInvalidResponse userInfo:request.userInfo];
    DBLogWarning(@"DropboxSDK: error parsing metadata");
    if ([delegate respondsToSelector:@selector(restClient:loadDeltaFailedWithError:)]) {
        [delegate restClient:self loadDeltaFailedWithError:error];
    }
}


- (void)loadFile:(NSString *)path atRev:(NSString *)rev intoPath:(NSString *)destPath
{
    NSString* fullPath = [NSString stringWithFormat:@"/files/%@%@", root, path];

    NSDictionary *params = nil;
    if (rev) {
        params = [NSDictionary dictionaryWithObject:rev forKey:@"rev"];
    }
    
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIContentHost path:fullPath parameters:params];
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadFile:)]
         autorelease];
    request.resultFilename = destPath;
    request.downloadProgressSelector = @selector(requestLoadProgress:);
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            path, @"path", 
            destPath, @"destinationPath", 
            rev, @"rev", nil];
    [loadRequests setObject:request forKey:path];
}

- (void)loadFile:(NSString *)path intoPath:(NSString *)destPath {
    [self loadFile:path atRev:nil intoPath:destPath];
}

- (void)cancelFileLoad:(NSString*)path {
    DBRequest* outstandingRequest = [loadRequests objectForKey:path];
    if (outstandingRequest) {
        [outstandingRequest cancel];
        [loadRequests removeObjectForKey:path];
    }
}


- (void)requestLoadProgress:(DBRequest*)request {
    if ([delegate respondsToSelector:@selector(restClient:loadProgress:forFile:)]) {
        [delegate restClient:self loadProgress:request.downloadProgress forFile:request.resultFilename];
    }
}


- (void)restClient:(DBRestClient*)restClient loadedFile:(NSString*)destPath
contentType:(NSString*)contentType eTag:(NSString*)eTag {
    // Empty selector to get the signature from
}

- (void)requestDidLoadFile:(DBRequest*)request {
    [[self retain] autorelease];

    NSString* path = [request.userInfo objectForKey:@"path"];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadFileFailedWithError:)]) {
            [delegate restClient:self loadFileFailedWithError:request.error];
        }
    } else {
        NSString* filename = request.resultFilename;
        NSDictionary* headers = [request.response allHeaderFields];
        NSString* contentType = [headers objectForKey:@"Content-Type"];
        NSDictionary* metadataDict = [request xDropboxMetadataJSON];
        NSString* eTag = [headers objectForKey:@"Etag"];
        if ([delegate respondsToSelector:@selector(restClient:loadedFile:)]) {
            [delegate restClient:self loadedFile:filename];
        } else if ([delegate respondsToSelector:@selector(restClient:loadedFile:contentType:metadata:)]) {
            DBMetadata* metadata = [[[DBMetadata alloc] initWithDictionary:metadataDict] autorelease];
            [delegate restClient:self loadedFile:filename contentType:contentType metadata:metadata];
        } else if ([delegate respondsToSelector:@selector(restClient:loadedFile:contentType:)]) {
            // This callback is deprecated and this block exists only for backwards compatibility.
            [delegate restClient:self loadedFile:filename contentType:contentType];
        } else if ([delegate respondsToSelector:@selector(restClient:loadedFile:contentType:eTag:)]) {
            // This code is for the official Dropbox client to get eTag information from the server
            NSMethodSignature* signature = 
                [self methodSignatureForSelector:@selector(restClient:loadedFile:contentType:eTag:)];
            NSInvocation* invocation = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:delegate];
            [invocation setSelector:@selector(restClient:loadedFile:contentType:eTag:)];
            [invocation setArgument:&self atIndex:2];
            [invocation setArgument:&filename atIndex:3];
            [invocation setArgument:&contentType atIndex:4];
            [invocation setArgument:&eTag atIndex:5];
            [invocation invoke];
        }
    }

    [loadRequests removeObjectForKey:path];
}


- (NSString*)thumbnailKeyForPath:(NSString*)path size:(NSString*)size {
    return [NSString stringWithFormat:@"%@##%@", path, size];
}


- (void)loadThumbnail:(NSString *)path ofSize:(NSString *)size intoPath:(NSString *)destinationPath 
{
    NSString* fullPath = [NSString stringWithFormat:@"/thumbnails/%@%@", root, path];
    
    NSString* format = @"JPEG";
    if ([path length] > 4) {
        NSString* extension = [[path substringFromIndex:[path length] - 4] uppercaseString];
        if ([[NSSet setWithObjects:@".PNG", @".GIF", nil] containsObject:extension]) {
            format = @"PNG";
        }
    }
    
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObject:format forKey:@"format"];
    if(size) {
        [params setObject:size forKey:@"size"];
    }
    
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIContentHost path:fullPath parameters:params];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadThumbnail:)]
         autorelease];

    request.resultFilename = destinationPath;
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root", 
            path, @"path", 
            destinationPath, @"destinationPath", 
            size, @"size", nil];
    [imageLoadRequests setObject:request forKey:[self thumbnailKeyForPath:path size:size]];
}



- (void)requestDidLoadThumbnail:(DBRequest*)request
{
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadThumbnailFailedWithError:)]) {
            [delegate restClient:self loadThumbnailFailedWithError:request.error];
        }
    } else {
        NSString* filename = request.resultFilename;
        NSDictionary* metadataDict = [request xDropboxMetadataJSON];
        if ([delegate respondsToSelector:@selector(restClient:loadedThumbnail:metadata:)]) {
            DBMetadata* metadata = [[[DBMetadata alloc] initWithDictionary:metadataDict] autorelease];
            [delegate restClient:self loadedThumbnail:filename metadata:metadata];
        } else if ([delegate respondsToSelector:@selector(restClient:loadedThumbnail:)]) {
            // This callback is deprecated and this block exists only for backwards compatibility.
            [delegate restClient:self loadedThumbnail:filename];
        }
    }

    NSString* path = [request.userInfo objectForKey:@"path"];
    NSString* size = [request.userInfo objectForKey:@"size"];
    [imageLoadRequests removeObjectForKey:[self thumbnailKeyForPath:path size:size]];
}


- (void)cancelThumbnailLoad:(NSString*)path size:(NSString*)size {
    NSString* key = [self thumbnailKeyForPath:path size:size];
    DBRequest* request = [imageLoadRequests objectForKey:key];
    if (request) {
        [request cancel];
        [imageLoadRequests removeObjectForKey:key];
    }
}

- (NSString *)signatureForParams:(NSArray *)params url:(NSURL *)baseUrl {
    NSMutableArray* paramList = [NSMutableArray arrayWithArray:params];
    [paramList sortUsingSelector:@selector(compare:)];
    NSString* paramString = [MPURLRequestParameter parameterStringForParameters:paramList];
    
    MPOAuthURLRequest* oauthRequest = 
        [[[MPOAuthURLRequest alloc] initWithURL:baseUrl andParameters:paramList] autorelease];
    oauthRequest.HTTPMethod = @"POST";
    MPOAuthSignatureParameter *signatureParameter = 
        [[[MPOAuthSignatureParameter alloc] 
                initWithText:paramString andSecret:self.credentialStore.signingKey 
                forRequest:oauthRequest usingMethod:self.credentialStore.signatureMethod]
          autorelease];

    return [signatureParameter URLEncodedParameterString];
}

- (NSMutableURLRequest *)requestForParams:(NSArray *)params urlString:(NSString *)urlString 
signature:(NSString *)sig {

    NSMutableArray *paramList = [NSMutableArray arrayWithArray:params];
    // Then rebuild request using that signature
    [paramList sortUsingSelector:@selector(compare:)];
    NSMutableString* realParamString = [[[NSMutableString alloc] initWithString:
            [MPURLRequestParameter parameterStringForParameters:paramList]]
            autorelease];
    [realParamString appendFormat:@"&%@", sig];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", urlString, realParamString]];
    NSMutableURLRequest* urlRequest = [NSMutableURLRequest requestWithURL:url];
    urlRequest.HTTPMethod = @"POST";

    return urlRequest;
}

- (void)uploadFile:(NSString*)filename toPath:(NSString*)path fromPath:(NSString *)sourcePath
params:(NSDictionary *)params
{
    BOOL isDir = NO;
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:sourcePath isDirectory:&isDir];
    NSDictionary *fileAttrs = 
        [[NSFileManager defaultManager] attributesOfItemAtPath:sourcePath error:nil];

    if (!fileExists || isDir || !fileAttrs) {
        NSString* destPath = [path stringByAppendingPathComponent:filename];
        NSDictionary* userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                sourcePath, @"sourcePath",
                destPath, @"destinationPath", nil];
        NSInteger errorCode = isDir ? DBErrorIllegalFileType : DBErrorFileNotFound;
        NSError* error = 
            [NSError errorWithDomain:DBErrorDomain code:errorCode userInfo:userInfo];
        NSString *errorMsg = isDir ? @"Unable to upload folders" : @"File does not exist";
        DBLogWarning(@"DropboxSDK: %@ (%@)", errorMsg, sourcePath);
        if ([delegate respondsToSelector:@selector(restClient:uploadFileFailedWithError:)]) {
            [delegate restClient:self uploadFileFailedWithError:error];
        }
        return;
    }

    NSString *destPath = [path stringByAppendingPathComponent:filename];
    NSString *urlString =
        [NSString stringWithFormat:@"%@://%@/%@/files_put/%@%@", 
                kDBProtocolHTTPS, kDBDropboxAPIContentHost, kDBDropboxAPIVersion, root, 
                [DBRestClient escapePath:destPath]];

#if !TARGET_OS_IPHONE
    // Set appropriate parameters to disable notification of updates.
    NSMutableDictionary * mutableParams = [[params mutableCopy] autorelease];
    [mutableParams setObject:@"1" forKey:@"mute"];
	params = mutableParams;
#endif

	NSArray *paramList =
		[[self.credentialStore oauthParameters]
		 arrayByAddingObjectsFromArray:[MPURLRequestParameter parametersFromDictionary:params]];

    NSString *sig = [self signatureForParams:paramList url:[NSURL URLWithString:urlString]];
    NSMutableURLRequest *urlRequest = [self requestForParams:paramList urlString:urlString signature:sig];
    
    NSString* contentLength = [NSString stringWithFormat: @"%qu", [fileAttrs fileSize]];
    [urlRequest addValue:contentLength forHTTPHeaderField: @"Content-Length"];
    [urlRequest addValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
    
    [urlRequest setHTTPBodyStream:[NSInputStream inputStreamWithFileAtPath:sourcePath]];

    DBRequest *request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidUploadFile:)]
         autorelease];
    request.uploadProgressSelector = @selector(requestUploadProgress:);
    request.userInfo = 
        [NSDictionary dictionaryWithObjectsAndKeys:sourcePath, @"sourcePath", destPath, @"destinationPath", nil];
	request.sourcePath = sourcePath;
    
    [uploadRequests setObject:request forKey:destPath];
}

- (void)uploadFile:(NSString*)filename toPath:(NSString*)path fromPath:(NSString *)sourcePath
{
    [self uploadFile:filename toPath:path fromPath:sourcePath params:nil];
}

- (void)uploadFile:(NSString *)filename toPath:(NSString *)path withParentRev:(NSString *)parentRev
    fromPath:(NSString *)sourcePath {

    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObject:@"false" forKey:@"overwrite"];
    if (parentRev) {
        [params setObject:parentRev forKey:@"parent_rev"];
    }
    [self uploadFile:filename toPath:path fromPath:sourcePath params:params];
}


- (void)requestUploadProgress:(DBRequest*)request {
    NSString* sourcePath = [(NSDictionary*)request.userInfo objectForKey:@"sourcePath"];
    NSString* destPath = [request.userInfo objectForKey:@"destinationPath"];

    if ([delegate respondsToSelector:@selector(restClient:uploadProgress:forFile:from:)]) {
        [delegate restClient:self uploadProgress:request.uploadProgress
                    forFile:destPath from:sourcePath];
    }
}


- (void)requestDidUploadFile:(DBRequest*)request {
    [[self retain] autorelease];

    NSDictionary *result = [request parseResponseAsType:[NSDictionary class]];

    if (!result) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:uploadFileFailedWithError:)]) {
            [delegate restClient:self uploadFileFailedWithError:request.error];
        }
    } else {
        DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];

        NSString* sourcePath = [request.userInfo objectForKey:@"sourcePath"];
        NSString* destPath = [request.userInfo objectForKey:@"destinationPath"];
        
        if ([delegate respondsToSelector:@selector(restClient:uploadedFile:from:metadata:)]) {
            [delegate restClient:self uploadedFile:destPath from:sourcePath metadata:metadata];
        } else if ([delegate respondsToSelector:@selector(restClient:uploadedFile:from:)]) {
            [delegate restClient:self uploadedFile:destPath from:sourcePath];
        }
    }

    [uploadRequests removeObjectForKey:[request.userInfo objectForKey:@"destinationPath"]];
}

- (void)cancelFileUpload:(NSString *)path {
    DBRequest *request = [uploadRequests objectForKey:path];
    if (request) {
        [request cancel];
        [uploadRequests removeObjectForKey:path];
    }
}

- (void)uploadFileChunk:(NSString *)uploadId offset:(unsigned long long)offset fromPath:(NSString *)localPath {

	NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:localPath];
	if (!file) {
		if ([delegate respondsToSelector:@selector(restClient:uploadFileChunkFailedWithError:)]) {
			NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
									  localPath, @"fromPath",
									  [NSNumber numberWithLongLong:offset], @"offset",
									  uploadId, @"upload_id", nil];
			NSError *error = [NSError errorWithDomain:DBErrorDomain code:DBErrorFileNotFound userInfo:userInfo];
			[delegate restClient:self uploadFileChunkFailedWithError:error];
		} else {
			DBLogWarning(@"DropboxSDK: unable to read file in -[DBRestClient uploadFileChunk:offset:fromPath:] (fromPath=%@)", localPath);
		}
		return;
	}
	[file seekToFileOffset:offset];
	NSData *data = [file readDataOfLength:2*1024*1024];

	if (![data length]) {
		DBLogWarning(@"DropboxSDK: did not read any data from file (fromPath=%@)", localPath);
	}

	NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
							[NSString stringWithFormat:@"%qu", offset], @"offset",
							uploadId, @"upload_id",
							nil];

	NSString *urlStr = [NSString stringWithFormat:@"%@://%@/%@/chunked_upload",
						kDBProtocolHTTPS, kDBDropboxAPIContentHost, kDBDropboxAPIVersion];
	NSArray *paramList = [[self.credentialStore oauthParameters]
						   arrayByAddingObjectsFromArray:[MPURLRequestParameter parametersFromDictionary:params]];
	NSString *sig = [self signatureForParams:paramList url:[NSURL URLWithString:urlStr]];
	NSMutableURLRequest *urlRequest = [self requestForParams:paramList urlString:urlStr signature:sig];

	NSString *contentLength = [NSString stringWithFormat:@"%lu", (unsigned long)[data length]];
	[urlRequest addValue:contentLength forHTTPHeaderField:@"Content-Length"];
	[urlRequest addValue:@"application/octet-stream" forHTTPHeaderField:@"Content-Type"];
	[urlRequest setHTTPBody:data];

	DBRequest *request =
		[[[DBRequest alloc]
		  initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidUploadChunk:)]
		 autorelease];
	request.uploadProgressSelector = @selector(requestChunkedUploadProgress:);
	NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							  [NSNumber numberWithLongLong:offset], @"offset",
							  localPath, @"fromPath",
							  uploadId, @"upload_id", nil];
	request.userInfo = userInfo;
	request.sourcePath = localPath;
	[requests addObject:request];
}

- (void)requestChunkedUploadProgress:(DBRequest*)request {
	NSString *uploadId = [request.userInfo objectForKey:@"upload_id"];
	unsigned long long offset = [[request.userInfo objectForKey:@"offset"] longLongValue];
	NSString *fromPath = [request.userInfo objectForKey:@"fromPath"];

    if ([delegate respondsToSelector:@selector(restClient:uploadFileChunkProgress:forFile:offset:fromPath:)]) {
		[delegate restClient:self uploadFileChunkProgress:request.uploadProgress
				forFile:uploadId offset:offset fromPath:fromPath];
    }
}

- (void)requestDidUploadChunk:(DBRequest *)request {
    [[self retain] autorelease];

	NSDictionary *resp = [request parseResponseAsType:[NSDictionary class]];

	if (!resp) {
		if ([delegate respondsToSelector:@selector(restClient:uploadFileChunkFailedWithError:)]) {
			[delegate restClient:self uploadFileChunkFailedWithError:request.error];
		}
	} else {
		NSString *uploadId = [resp objectForKey:@"upload_id"];
		unsigned long long newOffset = [[resp objectForKey:@"offset"] longLongValue];
		NSString *localPath = [request.userInfo objectForKey:@"fromPath"];
		NSDateFormatter *dateFormatter = [DBMetadata dateFormatter];
		NSDate *expires = [dateFormatter dateFromString:[resp objectForKey:@"expires"]];
		if ([delegate respondsToSelector:@selector(restClient:uploadedFileChunk:newOffset:fromFile:expires:)]) {
			[delegate restClient:self uploadedFileChunk:uploadId newOffset:newOffset fromFile:localPath expires:expires];
		}
	}

    [requests removeObject:request];
}


- (void)uploadFile:(NSString *)filename toPath:(NSString *)parentFolder withParentRev:(NSString *)parentRev
	fromUploadId:(NSString *)uploadId {

	NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								   uploadId, @"upload_id",
								   @"false", @"overwrite", nil];
	if (parentRev) {
		[params setObject:parentRev forKey:@"parent_rev"];
	}

#if !TARGET_OS_IPHONE
	[params setObject:@"1" forKey:@"mute"];
#endif

	if (![parentFolder hasSuffix:@"/"]) {
		parentFolder = [NSString stringWithFormat:@"%@/", parentFolder];
	}
	NSString *destPath = [NSString stringWithFormat:@"%@%@", parentFolder, filename];
	NSString *urlPath = [NSString stringWithFormat:@"/commit_chunked_upload/%@%@", root, destPath];
	NSURLRequest *urlRequest = [self requestWithHost:kDBDropboxAPIContentHost path:urlPath parameters:params method:@"POST"];

	DBRequest *request = [[[DBRequest alloc]
						   initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidUploadFromUploadId:)]
						  autorelease];
	request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						uploadId, @"uploadId",
						destPath, @"destPath",
						parentRev, @"parentRev",
						nil];
	[requests addObject:request];
}

- (void)requestDidUploadFromUploadId:(DBRequest *)request {
    [[self retain] autorelease];

	NSDictionary *resp = [request parseResponseAsType:[NSDictionary class]];

	if (!resp) {
		if ([delegate respondsToSelector:@selector(restClient:uploadFromUploadIdFailedWithError:)]) {
			[delegate restClient:self uploadFromUploadIdFailedWithError:request.error];
		}
	} else {
		NSString *destPath = [request.userInfo objectForKey:@"destPath"];
		NSString *uploadId = [request.userInfo objectForKey:@"uploadId"];
		DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:resp] autorelease];

		if ([delegate respondsToSelector:@selector(restClient:uploadedFile:fromUploadId:metadata:)]) {
			[delegate restClient:self uploadedFile:destPath fromUploadId:uploadId metadata:metadata];
		}
	}

	[requests removeObject:request];
}


- (void)loadRevisionsForFile:(NSString *)path {
    [self loadRevisionsForFile:path limit:10];
}

- (void)loadRevisionsForFile:(NSString *)path limit:(NSInteger)limit {
    NSString *fullPath = [NSString stringWithFormat:@"/revisions/%@%@", root, path];
    NSString *limitStr = [NSString stringWithFormat:@"%ld", (long)limit];
    NSDictionary *params = [NSDictionary dictionaryWithObject:limitStr forKey:@"rev_limit"];
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadRevisions:)]
         autorelease];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            path, @"path",
                            [NSNumber numberWithInteger:limit], @"limit", nil];

    [requests addObject:request];
}

- (void)requestDidLoadRevisions:(DBRequest *)request {
    [[self retain] autorelease];

    NSArray *resp = [request parseResponseAsType:[NSArray class]];
    
    if (!resp) {
        if ([delegate respondsToSelector:@selector(restClient:loadRevisionsFailedWithError:)]) {
            [delegate restClient:self loadRevisionsFailedWithError:request.error];
        }
    } else {
        NSMutableArray *revisions = [NSMutableArray arrayWithCapacity:[resp count]];
        for (NSDictionary *dict in resp) {
            DBMetadata *metadata = [[DBMetadata alloc] initWithDictionary:dict];
            [revisions addObject:metadata];
            [metadata release];
        }
        NSString *path = [request.userInfo objectForKey:@"path"];

        if ([delegate respondsToSelector:@selector(restClient:loadedRevisions:forFile:)]) {
            [delegate restClient:self loadedRevisions:revisions forFile:path];
        }
    }

    [requests removeObject:request];
}

- (void)restoreFile:(NSString *)path toRev:(NSString *)rev {
    NSString *fullPath = [NSString stringWithFormat:@"/restore/%@%@", root, path];
    NSDictionary *params = [NSDictionary dictionaryWithObject:rev forKey:@"rev"];
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidRestoreFile:)]
         autorelease];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                            path, @"path",
                            rev, @"rev", nil];

    [requests addObject:request];
}

- (void)requestDidRestoreFile:(DBRequest *)request {
    [[self retain] autorelease];

    NSDictionary *dict = [request parseResponseAsType:[NSDictionary class]];

    if (!dict) {
        if ([delegate respondsToSelector:@selector(restClient:restoreFileFailedWithError:)]) {
            [delegate restClient:self restoreFileFailedWithError:request.error];
        }
    } else {
        DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:dict] autorelease];
        if ([delegate respondsToSelector:@selector(restClient:restoredFile:)]) {
            [delegate restClient:self restoredFile:metadata];
        }
    }

    [requests removeObject:request];
}


- (void)moveFrom:(NSString*)from_path toPath:(NSString *)to_path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            from_path, @"from_path",
            to_path, @"to_path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:@"/fileops/move"
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidMovePath:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidMovePath:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:movePathFailedWithError:)]) {
            [delegate restClient:self movePathFailedWithError:request.error];
        }
    } else {
        NSDictionary *params = (NSDictionary *)request.userInfo;
        NSDictionary *result = [request parseResponseAsType:[NSDictionary class]];
        DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];

        if ([delegate respondsToSelector:@selector(restClient:movedPath:to:)]) {
            [delegate restClient:self movedPath:[params valueForKey:@"from_path"] to:metadata];
        }
    }

    [requests removeObject:request];
}


- (void)copyFrom:(NSString*)from_path toPath:(NSString *)to_path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            from_path, @"from_path",
            to_path, @"to_path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:@"/fileops/copy"
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCopyPath:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidCopyPath:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:copyPathFailedWithError:)]) {
            [delegate restClient:self copyPathFailedWithError:request.error];
        }
    } else {
        NSDictionary *params = (NSDictionary *)request.userInfo;
        NSDictionary *result = [request parseResponseAsType:[NSDictionary class]];
        DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];

        if ([delegate respondsToSelector:@selector(restClient:copiedPath:to:)]) {
            [delegate restClient:self copiedPath:[params valueForKey:@"from_path"] to:metadata];
        }
    }

    [requests removeObject:request];
}


- (void)createCopyRef:(NSString *)path {
    NSDictionary* userInfo = [NSDictionary dictionaryWithObject:path forKey:@"path"];
    NSString *fullPath = [NSString stringWithFormat:@"/copy_ref/%@%@", root, path];
    NSMutableURLRequest* urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:nil method:@"POST"];

    DBRequest* request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCreateCopyRef:)]
         autorelease];

    request.userInfo = userInfo;
    [requests addObject:request];
}

- (void)requestDidCreateCopyRef:(DBRequest *)request {
    [[self retain] autorelease];

    NSDictionary *result = [request parseResponseAsType:[NSDictionary class]];
    if (!result) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:createCopyRefFailedWithError:)]) {
            [delegate restClient:self createCopyRefFailedWithError:request.error];
        }
    } else {
        NSString *copyRef = [result objectForKey:@"copy_ref"];
		NSString *path = [request.userInfo objectForKey:@"path"];
		if ([delegate respondsToSelector:@selector(restClient:createdCopyRef:forPath:)]) {
			[delegate restClient:self createdCopyRef:copyRef forPath:path];
		} else if ([delegate respondsToSelector:@selector(restClient:createdCopyRef:)]) {
            [delegate restClient:self createdCopyRef:copyRef];
        }
    }

    [requests removeObject:request];
}


- (void)copyFromRef:(NSString*)copyRef toPath:(NSString *)toPath {
    NSDictionary *params =
        [NSDictionary dictionaryWithObjectsAndKeys:
         copyRef, @"from_copy_ref",
         root, @"root",
         toPath, @"to_path", nil];

    NSString *fullPath = [NSString stringWithFormat:@"/fileops/copy/"];
    NSMutableURLRequest* urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params method:@"POST"];

    DBRequest* request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCopyFromRef:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}

- (void)requestDidCopyFromRef:(DBRequest *)request {
    [[self retain] autorelease];

    NSDictionary *result = [request parseResponseAsType:[NSDictionary class]];
    if (!result) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:copyFromRefFailedWithError:)]) {
            [delegate restClient:self copyFromRefFailedWithError:request.error];
        }
    } else {
        NSString *copyRef = [request.userInfo objectForKey:@"from_copy_ref"];
        DBMetadata *metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];
        if ([delegate respondsToSelector:@selector(restClient:copiedRef:to:)]) {
            [delegate restClient:self copiedRef:copyRef to:metadata];
        }
    }

    [requests removeObject:request];
}


- (void)deletePath:(NSString*)path {
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            path, @"path", nil];
            
    NSMutableURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:@"/fileops/delete" 
                parameters:params method:@"POST"];

    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidDeletePath:)]
         autorelease];

    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidDeletePath:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:deletePathFailedWithError:)]) {
            [delegate restClient:self deletePathFailedWithError:request.error];
        }
    } else {
        if ([delegate respondsToSelector:@selector(restClient:deletedPath:)]) {
            NSString* path = [request.userInfo objectForKey:@"path"];
            [delegate restClient:self deletedPath:path];
        }
    }

    [requests removeObject:request];
}




- (void)createFolder:(NSString*)path
{
    NSDictionary* params = [NSDictionary dictionaryWithObjectsAndKeys:
            root, @"root",
            path, @"path", nil];
            
    NSString* fullPath = @"/fileops/create_folder";
    NSMutableURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:fullPath 
                parameters:params method:@"POST"];
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidCreateDirectory:)]
         autorelease];
    request.userInfo = params;
    [requests addObject:request];
}



- (void)requestDidCreateDirectory:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:createFolderFailedWithError:)]) {
            [delegate restClient:self createFolderFailedWithError:request.error];
        }
    } else {
        NSDictionary* result = (NSDictionary*)[request resultJSON];
        DBMetadata* metadata = [[[DBMetadata alloc] initWithDictionary:result] autorelease];
        if ([delegate respondsToSelector:@selector(restClient:createdFolder:)]) {
            [delegate restClient:self createdFolder:metadata];
        }
    }

    [requests removeObject:request];
}



- (void)loadAccountInfo
{
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:@"/account/info" parameters:nil];
    
    DBRequest* request = 
        [[[DBRequest alloc] 
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadAccountInfo:)]
         autorelease];
    
    request.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:root, @"root", nil];

    [requests addObject:request];
}


- (void)requestDidLoadAccountInfo:(DBRequest*)request
{
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadAccountInfoFailedWithError:)]) {
            [delegate restClient:self loadAccountInfoFailedWithError:request.error];
        }
    } else {
        NSDictionary* result = (NSDictionary*)[request resultJSON];
        DBAccountInfo* accountInfo = [[[DBAccountInfo alloc] initWithDictionary:result] autorelease];
        if ([delegate respondsToSelector:@selector(restClient:loadedAccountInfo:)]) {
            [delegate restClient:self loadedAccountInfo:accountInfo];
        }
    }

    [requests removeObject:request];
}

- (void)searchPath:(NSString*)path forKeyword:(NSString*)keyword {
    NSDictionary* params = [NSDictionary dictionaryWithObject:keyword forKey:@"query"];
    NSString* fullPath = [NSString stringWithFormat:@"/search/%@%@", root, path];
    
    NSURLRequest* urlRequest = 
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params];
    DBRequest* request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidSearchPath:)]
         autorelease];
    request.userInfo = 
        [NSDictionary dictionaryWithObjectsAndKeys:path, @"path", keyword, @"keyword", nil];
    [requests addObject:request];
}


- (void)requestDidSearchPath:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:searchFailedWithError:)]) {
            [delegate restClient:self searchFailedWithError:request.error];
        }
    } else {
        NSMutableArray* results = nil;
        if ([[request resultJSON] isKindOfClass:[NSArray class]]) {
            NSArray* response = (NSArray*)[request resultJSON];
            results = [NSMutableArray arrayWithCapacity:[response count]];
            for (NSDictionary* dict in response) {
                DBMetadata* metadata = [[DBMetadata alloc] initWithDictionary:dict];
                [results addObject:metadata];
                [metadata release];
            }
        }
        NSString* path = [request.userInfo objectForKey:@"path"];
        NSString* keyword = [request.userInfo objectForKey:@"keyword"];
        
        if ([delegate respondsToSelector:@selector(restClient:loadedSearchResults:forPath:keyword:)]) {
            [delegate restClient:self loadedSearchResults:results forPath:path keyword:keyword];
        }
    }
    [requests removeObject:request];
}


- (void)loadSharableLinkForFile:(NSString *)path {
	[self loadSharableLinkForFile:path shortUrl:YES];
}

- (void)loadSharableLinkForFile:(NSString*)path shortUrl:(BOOL)createShortUrl {
    NSString* fullPath = [NSString stringWithFormat:@"/shares/%@%@", root, path];

	NSString *shortUrlVal = createShortUrl ? @"true" : @"false";
	NSDictionary *params = [NSDictionary dictionaryWithObject:shortUrlVal forKey:@"short_url"];

    NSURLRequest* urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:params];

    DBRequest* request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadSharableLink:)]
         autorelease];

    request.userInfo =  [NSDictionary dictionaryWithObject:path forKey:@"path"];
    [requests addObject:request];
}

- (void)requestDidLoadSharableLink:(DBRequest*)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadSharableLinkFailedWithError:)]) {
            [delegate restClient:self loadSharableLinkFailedWithError:request.error];
        }
    } else {
        NSString* sharableLink = [(NSDictionary*)request.resultJSON objectForKey:@"url"];
        NSString* path = [request.userInfo objectForKey:@"path"];
        if ([delegate respondsToSelector:@selector(restClient:loadedSharableLink:forFile:)]) {
            [delegate restClient:self loadedSharableLink:sharableLink forFile:path];
        }
    }
    [requests removeObject:request];
}


- (void)loadStreamableURLForFile:(NSString *)path {
    NSString* fullPath = [NSString stringWithFormat:@"/media/%@%@", root, path];
    NSURLRequest* urlRequest =
        [self requestWithHost:kDBDropboxAPIHost path:fullPath parameters:nil];

    DBRequest *request =
        [[[DBRequest alloc]
          initWithURLRequest:urlRequest andInformTarget:self selector:@selector(requestDidLoadStreamableURL:)]
         autorelease];
    request.userInfo = [NSDictionary dictionaryWithObject:path forKey:@"path"];
    [requests addObject:request];
}

- (void)requestDidLoadStreamableURL:(DBRequest *)request {
    [[self retain] autorelease];

    if (request.error) {
        [self checkForAuthenticationFailure:request];
        if ([delegate respondsToSelector:@selector(restClient:loadStreamableURLFailedWithError:)]) {
            [delegate restClient:self loadStreamableURLFailedWithError:request.error];
        }
    } else {
        NSDictionary *response = [request parseResponseAsType:[NSDictionary class]];
        NSURL *url = [NSURL URLWithString:[response objectForKey:@"url"]];
        NSString *path = [request.userInfo objectForKey:@"path"];
        if ([delegate respondsToSelector:@selector(restClient:loadedStreamableURL:forFile:)]) {
            [delegate restClient:self loadedStreamableURL:url forFile:path];
        }
    }

    [requests removeObject:request];
}


- (NSUInteger)requestCount {
    return [requests count] + [loadRequests count] + [imageLoadRequests count] + [uploadRequests count];
}


#pragma mark private methods

+ (NSString*)escapePath:(NSString*)path {
    CFStringEncoding encoding = CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding);
    NSString *escapedPath = 
        (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                            (CFStringRef)path,
                                                            NULL,
                                                            (CFStringRef)@":?=,!$&'()*+;[]@#~",
                                                            encoding);
    
    return [escapedPath autorelease];
}

+ (NSString *)bestLanguage {
    static NSString *preferredLang = nil;
    if (!preferredLang) {
        NSString *lang = [[NSLocale preferredLanguages] objectAtIndex:0];
        if ([[[NSBundle mainBundle] localizations] containsObject:lang])
            preferredLang = [lang copy];
        else
            preferredLang =  @"en";
    }
    return preferredLang;
}

+ (NSString *)userAgent {
    static NSString *userAgent;
    if (!userAgent) {
        NSBundle *bundle = [NSBundle mainBundle];
        NSString *appName = [[bundle objectForInfoDictionaryKey:@"CFBundleDisplayName"]
                              stringByReplacingOccurrencesOfString:@" " withString:@""];
        NSString *appVersion = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        userAgent =
            [[NSString alloc] initWithFormat:@"%@/%@ OfficialDropboxIosSdk/%@", appName, appVersion, kDBSDKVersion];
    }
    return userAgent;
}

- (NSMutableURLRequest*)requestWithHost:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params {
    
    return [self requestWithHost:host path:path parameters:params method:nil];
}


- (NSMutableURLRequest*)requestWithHost:(NSString*)host path:(NSString*)path 
    parameters:(NSDictionary*)params method:(NSString*)method {
    
    NSString* escapedPath = [DBRestClient escapePath:path];
    NSString* urlString = [NSString stringWithFormat:@"%@://%@/%@%@", 
                                        kDBProtocolHTTPS, host, kDBDropboxAPIVersion, escapedPath];
    NSURL* url = [NSURL URLWithString:urlString];

    NSMutableDictionary *allParams = 
        [NSMutableDictionary dictionaryWithObject:[DBRestClient bestLanguage] forKey:@"locale"];
    if (params) {
        [allParams addEntriesFromDictionary:params];
    }

    NSArray *extraParams = [MPURLRequestParameter parametersFromDictionary:allParams];
    NSArray *paramList = 
    [[self.credentialStore oauthParameters] arrayByAddingObjectsFromArray:extraParams];

    MPOAuthURLRequest* oauthRequest = 
        [[[MPOAuthURLRequest alloc] initWithURL:url andParameters:paramList] autorelease];
    if (method) {
        oauthRequest.HTTPMethod = method;
    }

    NSMutableURLRequest* urlRequest = [oauthRequest 
            urlRequestSignedWithSecret:self.credentialStore.signingKey 
            usingMethod:self.credentialStore.signatureMethod];
    [urlRequest setTimeoutInterval:20];
    [urlRequest setValue:[DBRestClient userAgent] forHTTPHeaderField:@"User-Agent"];
    return urlRequest;
}


- (void)checkForAuthenticationFailure:(DBRequest*)request {
    if (request.error && request.error.code == 401 && [request.error.domain isEqual:DBErrorDomain]) {
        [session.delegate sessionDidReceiveAuthorizationFailure:session userId:userId];
    }
}

- (MPOAuthCredentialConcreteStore *)credentialStore {
    return [session credentialStoreForUserId:userId];
}

@end

//
//  Owncloud_iOs_ClientTests.m
//  Owncloud iOs ClientTests
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


#import "OCCommunicationLibTests.h"
#import "ConfigTests.h"
#import "OCCommunication.h"
#import "OCFrameworkConstants.h"
#import "OCFileDto.h"
#import "OCSharedDto.h"
#import "ConfigTests.h"
#import "AFURLSessionManager.h"
#import "OCConstants.h"

#import <UIKit/UIKit.h>

/*
 *  With this implementation we allow the connection with any HTTPS server
 */
#if DEBUG
@implementation NSURLRequest (NSURLRequestWithIgnoreSSL)

+ (BOOL)allowsAnyHTTPSCertificateForHost:(NSString *)host {
    return YES;
}

@end
#endif

@implementation OCCommunicationLibTests

//You must enter this information of your server in order that the unit test works




///-----------------------------------
/// @name setUp
///-----------------------------------

/**
 * Method to get ready the tests
 */
- (void)setUp
{
    [super setUp];
    
    _sharedOCCommunication = [[OCCommunication alloc] init];
    [_sharedOCCommunication setCredentialsWithUser:k_user andPassword:k_password];
    [_sharedOCCommunication setSecurityPolicyManagers:[_sharedOCCommunication  createSecurityPolicy]];
    
    //Create Tests folder
    [self createFolderWithName:k_path_test_folder];
    
}

- (void)tearDown
{
    
    //Delete Test folder
    [self deleteFolderWithName:k_path_test_folder];
    
    [super tearDown];
    
}

#pragma mark - Util Methods to Set Up the Tests

///-----------------------------------
/// @name Create Folder With Name
///-----------------------------------

/**
 * This method create a new folder with the name passed in the server
 *
 * @param NSString -> path
 */
- (void) createFolderWithName:(NSString*)path{
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSString *folder = [NSString stringWithFormat:@"%@%@",k_webdav_base_url,path];
     folder = [folder stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [_sharedOCCommunication createFolder:folder onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        //Folder created
        NSLog(@"Folder created");
        dispatch_semaphore_signal(semaphore);

    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        NSLog(@"Error created folder");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        NSLog(@"Error created folder");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];

}

///-----------------------------------
/// @name Delete folder With Name
///-----------------------------------

/**
 * This method delete a folder with the name passed
 *
 * @param NSString -> path
 */

- (void) deleteFolderWithName:(NSString *)path{
    
    NSString *folder = [NSString stringWithFormat:@"%@%@",k_webdav_base_url,path];
    folder = [folder stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication deleteFileOrFolder:folder onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse * response, NSString *redirectedServer) {
        //Folder deleted
        NSLog(@"Folder deleted");
        dispatch_semaphore_signal(semaphore);
    } failureRquest:^(NSURLResponse * response, NSError * error, NSString *redirectedServer) {
        //Error
        NSLog(@"Error deleted folder");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

///-----------------------------------
/// @name Upload File
///-----------------------------------

/**
 * This method upload a file from local path to remote path
 *
 * @param NSString -> localPath
 *
 * @param NSString -> remotePath
 */

- (void) uploadFilePath:(NSString*)localPath inRemotePath:(NSString*)remotePath{
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create the complete url
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@",k_webdav_base_url,remotePath];
    
    //Path of server file file
    remotePath = [remotePath stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    
    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        NSLog(@"File: %@ uploaded", localPath);
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        NSLog(@"Failed uploading: %@", localPath);
        NSLog(@"Error uploading");
        dispatch_semaphore_signal(semaphore);
    } failureBeforeRequest:^(NSError *error) {
        NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

#pragma mark - Tests


///-----------------------------------
/// @name testCreateFolder
///-----------------------------------

/**
 * Method to test if we can create a folder
 */
- (void)testCreateFolder
{
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSString *folder = [NSString stringWithFormat:@"%@%@/%@",k_webdav_base_url,k_path_test_folder,[NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]]];
    
    [_sharedOCCommunication createFolder:folder onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        //Folder created
        NSLog(@"Folder created");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error testCreateFolder failureRequest");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        XCTFail(@"Error testCreateFolder beforeRequest");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testCreateFolderWithForbiddenCharacters
///-----------------------------------

/**
 * Method to check if we check the forbidden characters when we try to create a folder
 *
 * @warning The special characters are: "\","<",">",":",""","|","?","*"
 */

- (void)testCreateFolderWithForbiddenCharacters {
    NSArray* arrayForbiddenCharacters = [NSArray arrayWithObjects:@"\\",@"<",@">",@":",@"\"",@"|",@"?",@"*", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        NSString *folder = [NSString stringWithFormat:@"%@%@/%@",k_webdav_base_url,k_path_test_folder,[NSString stringWithFormat:@"%f%@-folder", [NSDate timeIntervalSinceReferenceDate], currentCharacter]];
        
        //We create a semaphore to wait until we recive the responses from Async calls
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication createFolder:folder onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
            //Folder created
            NSLog(@"Folder created");
            XCTFail(@"Error testCreateFolderWithSpecialCharacters problem on: %@", currentCharacter);
            dispatch_semaphore_signal(semaphore);

        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error testCreateFolderWithSpecialCharacters problem on: %@", currentCharacter);
            // Signal that block has completed
            dispatch_semaphore_signal(semaphore);
        } errorBeforeRequest:^(NSError *error) {
            NSLog(@"Forbbiden character detected: %@", currentCharacter);
            // Signal that block has completed
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    }
}

///-----------------------------------
/// @name testMoveFileOnSameFolder
///-----------------------------------

/**
 * Method to test move file on the same folder
 */
- (void)testMoveFileOnSameFolder {
    
    //Create Folder A for the Test
    NSString *testPath = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPath];
    
    //Upload file /Tests/Folder A/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *remotePath = [NSString stringWithFormat:@"%@/Folder A/Test.jpg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:remotePath];

    
    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder A/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder A/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        XCTFail(@"File Moved on the same folder");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error moving file on the same folder and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        if (error.code == OCErrorMovingTheDestinyAndOriginAreTheSame) {
            NSLog(@"File on the same folder not moved");
        } else {
            XCTFail(@"Error moving file on same folder");
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testMoveFile
///-----------------------------------

/**
 * Method to try move a file
 */
- (void)testMoveFile {
    
    //Create Folder A for the Test
    NSString *testPathA = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPathA];
    
    //Create Folder B for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    //Upload file /Tests/Folder A/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Folder A/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];

    
    
    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder A/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        NSLog(@"File moved");
        dispatch_semaphore_signal(semaphore);

    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error moving file and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        XCTFail(@"Error moving file");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testMoveFileForbiddenCharacters
///-----------------------------------

/**
 * Method to try to move a file with destiny name have forbidden characters
 */
- (void)testMoveFileForbiddenCharacters {
    
    //Create Folder A for the Test
    NSString *testPathA = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPathA];
    
    //Create Folder C for the Test
    NSString *testPathC = [NSString stringWithFormat:@"%@/Folder C", k_path_test_folder];
    [self createFolderWithName:testPathC];
    
    //Upload file /Tests/Folder A/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Folder A/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];
    
    
    NSArray *arrayForbiddenCharacters = [NSArray arrayWithObjects:@"\\",@"<",@">",@":",@"\"",@"|",@"?",@"*", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        NSString *origin = [NSString stringWithFormat:@"%@%@/Folder A/Test.jpeg", k_webdav_base_url, k_path_test_folder];
        NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder C/Test%@.jpeg", k_webdav_base_url,k_path_test_folder, currentCharacter];
        
        //We create a semaphore to wait until we recive the responses from Async calls
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
            XCTFail(@"File Moved and renamed");
            dispatch_semaphore_signal(semaphore);
        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error moving file and renamed and Error");
            dispatch_semaphore_signal(semaphore);
        } errorBeforeRequest:^(NSError *error) {
            if (error.code == OCErrorMovingDestinyNameHaveForbiddenCharacters) {
                NSLog(@"File with forbidden characters not moved");
            } else {
                XCTFail(@"Error moving and renaming file");
            }
            
            dispatch_semaphore_signal(semaphore);
        }];
        
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    }
}

///-----------------------------------
/// @name testMoveFolderInsideHimself
///-----------------------------------

/**
 * Method to try to move a folder inside himself
 */
- (void)testMoveFolderInsideHimself {
    
    //Create Folder A for the Test
    NSString *testPathA = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPathA];

    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder A/", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder A/Folder A/", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        XCTFail(@"Folder Moved inside himself");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error moving folder inside himself and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        if (error.code == OCErrorMovingFolderInsideHimself) {
            NSLog(@"File renamed not moved");
        } else {
            XCTFail(@"Error moving folder inside himself");
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testMoveFolder
///-----------------------------------

/**
 * Method to try to move a folder
 */
- (void)testMoveFolder {
    
    //Create Folder A for the Test
    NSString *testPathA = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPathA];
    
    //Create Folder C for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder A/", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B/Folder A/", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        NSLog(@"Folder Moved");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error moving folder and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        XCTFail(@"Error moving folder");
        dispatch_semaphore_signal(semaphore);
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testRenameFileWithForbiddenCharacters
///-----------------------------------

/**
 * Method  try to rename a file with forbidden characters
 *
 */
- (void)testRenameFileWithForbiddenCharacters {
    
    //Create Folder B for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    //Upload file /Tests/Folder B/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Folder B/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];

    NSArray *arrayForbiddenCharacters = [NSArray arrayWithObjects:@"\\",@"<",@">",@":",@"\"",@"|",@"?",@"*", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        
        NSString *origin = [NSString stringWithFormat:@"%@%@/Folder B/Test.jpeg", k_webdav_base_url, k_path_test_folder];
        NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B/Test-%@.jpeg", k_webdav_base_url, k_path_test_folder, currentCharacter];
        
        //We create a semaphore to wait until we recive the responses from Async calls
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
            XCTFail(@"File renamed with forbidden characters");
            dispatch_semaphore_signal(semaphore);
        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error renaming file with forbidden characters and Error");
            dispatch_semaphore_signal(semaphore);
        } errorBeforeRequest:^(NSError *error) {
            if (error.code == OCErrorMovingDestinyNameHaveForbiddenCharacters) {
                NSLog(@"File not renamed with forbidden characters");
                dispatch_semaphore_signal(semaphore);
            } else {
                XCTFail(@"Error renaming file with forbidden characters");
                dispatch_semaphore_signal(semaphore);
            }
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    }
}

///-----------------------------------
/// @name testRenameFile
///-----------------------------------

/**
 * Method  try to rename a file
 *
 */
- (void)testRenameFile {
    
    //Create Folder B for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    //Upload file /Tests/Folder B/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Folder B/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];

    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder B/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B/Test Renamed.jpeg", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        NSLog(@"File Renamed");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error renaming file and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        XCTFail(@"Error renaming file");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name testRenameFolderWithForbiddenCharacters
///-----------------------------------

/**
 * Method  try to rename a folder with forbidden characters
 *
 */
- (void)testRenameFolderWithForbiddenCharacters {
    
    //Create Folder A for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    NSArray *arrayForbiddenCharacters = [NSArray arrayWithObjects:@"\\",@"<",@">",@":",@"\"",@"|",@"?",@"*", nil];
    
    for (NSString *currentCharacter in arrayForbiddenCharacters) {
        NSString *origin = [NSString stringWithFormat:@"%@%@/Folder B/", k_webdav_base_url, k_path_test_folder];
        NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B-%@/", k_webdav_base_url, k_path_test_folder, currentCharacter];
        
        //We create a semaphore to wait until we recive the responses from Async calls
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
            XCTFail(@"Folder renamed with forbidden characters");
            dispatch_semaphore_signal(semaphore);
        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error renaming folder with forbidden characters and Error");
            dispatch_semaphore_signal(semaphore);
        } errorBeforeRequest:^(NSError *error) {
            if (error.code == OCErrorMovingDestinyNameHaveForbiddenCharacters) {
                NSLog(@"Folder not renamed with forbidden characters");
                dispatch_semaphore_signal(semaphore);
            } else {
                XCTFail(@"Error renaming folder with forbidden characters");
                dispatch_semaphore_signal(semaphore);
            }
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    }
}

///-----------------------------------
/// @name testRenameFolder
///-----------------------------------

/**
 * Method  try to rename a folder
 *
 */
- (void)testRenameFolder {
    
    //Create Folder A for the Test
    NSString *testPathB = [NSString stringWithFormat:@"%@/Folder B", k_path_test_folder];
    [self createFolderWithName:testPathB];
    
    NSString *origin = [NSString stringWithFormat:@"%@%@/Folder B/", k_webdav_base_url, k_path_test_folder];
    NSString *destiny = [NSString stringWithFormat:@"%@%@/Folder B Renamed/", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication moveFileOrFolder:origin toDestiny:destiny onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectServer) {
        NSLog(@"Folder Renamed");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error renaming folder and Error");
        dispatch_semaphore_signal(semaphore);
    } errorBeforeRequest:^(NSError *error) {
        XCTFail(@"Error renaming folder");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}


///-----------------------------------
/// @name testToDeleteAFolder
///-----------------------------------

/**
 * Method to test if we can create a folder
 */
- (void)testDeleteAFolder
{
    //Create Tests/DeleteFolder
    NSString *testPathDelete = [NSString stringWithFormat:@"%@/DeleteFolder", k_path_test_folder];
    [self createFolderWithName:testPathDelete];
    
    NSString *folder = [NSString stringWithFormat:@"%@%@/DeleteFolder", k_webdav_base_url, k_path_test_folder];

    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    
    [_sharedOCCommunication deleteFileOrFolder:folder onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse * response, NSString *redirectedServer) {
        //Folder deleted
        NSLog(@"Folder deleted");
        dispatch_semaphore_signal(semaphore);
    } failureRquest:^(NSURLResponse * response, NSError * error, NSString *redirectedServer) {
        //Error
        XCTFail(@"Error testDeleteFolder");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}



///-----------------------------------
/// @name test to Delete a File
///-----------------------------------

/**
 * Method to test if we can delete a folder
 */
- (void)testDeleteFile
{
    //Create Tests/DeleteFolder
    NSString *testPathDelete = [NSString stringWithFormat:@"%@/DeleteFolder", k_path_test_folder];
    [self createFolderWithName:testPathDelete];
    
    //Upload a file
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    
    //Upload file Tests/Test Read Folder/File1
    NSString *uploadPath = [NSString stringWithFormat:@"%@/DeleteFolder/File1.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];
    
    NSString *filePath = [NSString stringWithFormat:@"%@%@/DeleteFolder/File1.jpeg", k_webdav_base_url, k_path_test_folder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    
    [_sharedOCCommunication deleteFileOrFolder:filePath onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse * response, NSString *redirectedServer) {
        //File deleted
        NSLog(@"File deleted");
        dispatch_semaphore_signal(semaphore);
    } failureRquest:^(NSURLResponse * response, NSError * error, NSString *redirectedServer) {
        //Error
        XCTFail(@"Error test delete file");
        // Signal that block has completed
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}


///-----------------------------------
/// @name Test Read Folder
///-----------------------------------

/**
 * In this test we check many things:
 * 1.- The read folder method works, conected with server and get the answer
 * 2.- Check the parser checking a specific number of items in the selected path
 * 3.- Check the parser checking a specific number of files and folders
 *
 */
- (void)testReadFolder{
    
    //Create Tests/Test Read Folder
    NSString *testPathReadFolder = [NSString stringWithFormat:@"%@/Test Read Folder", k_path_test_folder];
    [self createFolderWithName:testPathReadFolder];
    
    //Create Tests/Test Read Folder/Folder1
    NSString *testPathReadFolder1 = [NSString stringWithFormat:@"%@/Test Read Folder/Folder1", k_path_test_folder];
    [self createFolderWithName:testPathReadFolder1];
    
    //Create Tests/Test Read Folder/Folder2
    NSString *testPathReadFolder2 = [NSString stringWithFormat:@"%@/Test Read Folder/Folder2", k_path_test_folder];
    [self createFolderWithName:testPathReadFolder2];
    
    //Create Tests/Test Read Folder/Folder3
    NSString *testPathReadFolder3 = [NSString stringWithFormat:@"%@/Test Read Folder/Folder3", k_path_test_folder];
    [self createFolderWithName:testPathReadFolder3];
    
    
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    
    //Upload file Tests/Test Read Folder/File1
    NSString *uploadPath1 = [NSString stringWithFormat:@"%@/Test Read Folder/File1.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath1];
    
    //Upload file Tests/Test Read Folder/File2
    NSString *uploadPath2 = [NSString stringWithFormat:@"%@/Test Read Folder/File2.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath2];
    
    //Upload file Tests/Test Read Folder/File3
    NSString *uploadPath3 = [NSString stringWithFormat:@"%@/Test Read Folder/File3.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath3];
    
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);


    //Path with 7 elements: {3 files, 3 folders and the parent folder}
    NSString *path = [NSString stringWithFormat:@"%@%@/Test Read Folder/", k_webdav_base_url, k_path_test_folder];
    
    path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
     [_sharedOCCommunication readFolder:path withUserSessionToken:nil onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *items, NSString *redirectedServer, NSString *token) {
        
        //Counters
        NSInteger foldersCount = 0;
        NSInteger filesCount = 0;
        //Remove the parent folder item
        NSInteger realItemsCount = items.count - 1;
        
        //Constants
        const int k_items = 6;
        const int k_files = 3;
        const int k_folders = 3;
        
        //Loop the items
        for (OCFileDto *itemDto in items) {
            //Check parser
            NSLog(@"Item file name: %@", itemDto.fileName);
            NSLog(@"Item file path: %@", itemDto.filePath);
            
            //Not include the root folder
            if (itemDto.fileName !=nil) {
                //File or folder
                if (itemDto.isDirectory) {
                    foldersCount++;
                } else {
                    filesCount++;
                }
            }
        }
        
        if (realItemsCount ==  k_items) {
            
            //Check account of files and folders
            if (foldersCount == k_folders && filesCount == k_files) {
                NSLog(@"Read Folder Test OK");
            } else {
                XCTFail(@"Error reading a folder - There are: %ld folders and %ld files insead of %d folders and %d files", (long)foldersCount, (long)filesCount, k_folders, k_files);
            }
            
        } else {
            XCTFail(@"Error reading a folder - There are: %ld elements insead of 6 elements", (long)realItemsCount);
        }
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *token, NSString *redirectedServer) {
        XCTFail(@"Error reading a folder - and Error");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test Read File
///-----------------------------------

/**
 * In this test we check the etag of a specific folder
 * we do changes in the folder in order to know the etag changed
 *
 */
-(void)testReadFile{
    
    //Create Tests/Test Read File
    NSString *testReadFilePath = [NSString stringWithFormat:@"%@/Test Read File", k_path_test_folder];
    [self createFolderWithName:testReadFilePath];
    
    
    //1.- Get and Store the etag of a specific folder
    
    //2.- Create a new folder with a specific name
    
    //3.- Delete the folder created
    
    //4.- Get and Compare the etag of the same folder with the preview, if is different the TEST is OK
    
    //Block Store Attributes
    __block NSString *etag = @"";
    
    
    //Path of new folder
    NSString *newFolder = [NSString stringWithFormat:@"%@%@/Test Read File/DeletedFolder/", k_webdav_base_url, k_path_test_folder];
    newFolder = [newFolder stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Path to the test
    NSString *path = [NSString stringWithFormat:@"%@%@/Test Read File/", k_webdav_base_url, k_path_test_folder];
    path = [path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    [_sharedOCCommunication readFile:path onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *items, NSString *redirectedServer) {
        
        for (OCFileDto *itemDto in items) {
            //Check parser
            NSLog(@"Item file path: %@", itemDto.filePath);
            NSLog(@"Item etag: %@", itemDto.etag);
            
            if (itemDto.etag) {
                etag = itemDto.etag;
            } else {
                XCTFail(@"Error getting the etag");
            }
        }
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error reading the folder properties - and Error");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    //Check if etag exists
    if (etag) {
        
        //Create Folder
        //We create a semaphore to wait until we recive the responses from Async calls
        semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication createFolder:newFolder onCommunication:_sharedOCCommunication withForbiddenCharactersSupported:NO successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
            //Folder created
            NSLog(@"Folder created");
            dispatch_semaphore_signal(semaphore);
        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error testCreateFolder");
            // Signal that block has completed
            dispatch_semaphore_signal(semaphore);
        } errorBeforeRequest:^(NSError *error) {
            XCTFail(@"Error testCreateFolder");
            // Signal that block has completed
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
        
        
        //Delete Folder
        //We create a semaphore to wait until we recive the responses from Async calls
        semaphore = dispatch_semaphore_create(0);
        
        
        [_sharedOCCommunication deleteFileOrFolder:newFolder onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse * response, NSString *redirectedServer) {
            //Folder deleted
            NSLog(@"Folder deleted");
            dispatch_semaphore_signal(semaphore);
        } failureRquest:^(NSURLResponse * response, NSError * error, NSString *redirectedServer) {
            //Error
            XCTFail(@"Error testDeleteFolder");
            // Signal that block has completed
            dispatch_semaphore_signal(semaphore);
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
        
        
        
        //Get the folder etag again
        //We create a semaphore to wait until we recive the responses from Async calls
        semaphore = dispatch_semaphore_create(0);
        
        [_sharedOCCommunication readFile:path onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *items, NSString *redirectedServer) {
            
            for (OCFileDto *itemDto in items) {
                //Check parser
                NSLog(@"Item file path: %@", itemDto.filePath);
                NSLog(@"Item etag: %@", itemDto.etag);
                
                if (itemDto.etag) {
                    
                    if ([etag isEqual:itemDto.etag]) {
                        XCTFail(@"The same etag after the changes");
                    }else{
                        NSLog(@"Test OK");
                    }
                    
                    
                } else {
                    XCTFail(@"Error getting the etag");
                }
            }
            
            dispatch_semaphore_signal(semaphore);
            
        } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
            XCTFail(@"Error reading the folder properties - and Error");
            dispatch_semaphore_signal(semaphore);
            
        }];
        
        // Run loop
        while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
        
    }
    
}


///-----------------------------------
/// @name Test Download File
///-----------------------------------

/**
 * This test try to download a specific file
 * It the file download the test is ok
 *
 */

- (void) testDownloadFile {
    
    //Create Tests/Test Download Folder
    NSString *downloadPath = [NSString stringWithFormat:@"%@/Test Download", k_path_test_folder];
    [self createFolderWithName:downloadPath];
    
    //Upload test file
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    
    //Upload file /Tests/Test Download/test.jpeg
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Download/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create Folder in File Sytem to test
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    //Documents/Test Download/
    NSString *localPath = documentsDirectory;
    
    //Make the path if not exists
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:localPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    //Documents/Test Download/image.png
    localPath = [localPath stringByAppendingString:@"/image.jpeg"];
    
    //Path of server file file
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Download/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionTask *downloadTask = nil;
    
    downloadTask = [_sharedOCCommunication downloadFileSession:serverUrl toDestiny:localPath defaultPriority:YES onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        NSLog(@"File Downloaded ok");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        XCTFail(@"Error download a file - Response - Error");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
    
}
 
///-----------------------------------
/// @name Test download not existing file
///-----------------------------------

/**
 * This test try to download a unexisting file
 * The test works fine if the file is not download
 *
 */
- (void) testDownloadNotExistingFile {
    
    //Create Tests/Test Download
    NSString *downloadPath = [NSString stringWithFormat:@"%@/Test Download", k_path_test_folder];
    [self createFolderWithName:downloadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create Folder in File Sytem to test
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    //Documents/Test Download/
    NSString *localPath = [documentsDirectory stringByAppendingPathComponent:@"Test Download"];
    
    //Make the path if not exists
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsDirectory])
        [[NSFileManager defaultManager] createDirectoryAtPath:documentsDirectory withIntermediateDirectories:NO attributes:nil error:&error];
    
    
    //Documents/Test Download/image.png
    localPath = [localPath stringByAppendingString:@"/image.png"];
    
    //Path of server file that not exist
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Download/test image not exist.PNG", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDownloadTask *downloadTask = nil;
   
    downloadTask = [_sharedOCCommunication downloadFileSession:serverUrl toDestiny:localPath defaultPriority:YES onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        XCTFail(@"Download file ok, not possible");
        
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}



///-----------------------------------
/// @name Test Download File With Session
///-----------------------------------

/**
 * This test try to download a specific file using NSURLSession
 * If the file is downloaded the test is ok
 *
 */
- (void) testDownloadFileWithSession {

    //Create Tests/Test Download Folder
    NSString *downloadPath = [NSString stringWithFormat:@"%@/Test Download", k_path_test_folder];
    [self createFolderWithName:downloadPath];
    
    //Upload test file
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    
    //Upload file /Tests/Test Download/test.jpeg
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Download/Test.jpeg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create Folder in File Sytem to test
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    //Documents/Test Download/
    NSString *localPath = documentsDirectory;
    
    //Make the path if not exists
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:localPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    //Documents/Test Download/image.png
    localPath = [localPath stringByAppendingString:@"/image.jpeg"];
    
    //Path of server file file
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Download/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDownloadTask *downloadTask = nil;
    
    downloadTask = [_sharedOCCommunication downloadFileSession:serverUrl toDestiny:localPath defaultPriority:YES onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        NSLog(@"File Downloaded ok");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        XCTFail(@"Error download a file - Error");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}



///-----------------------------------
/// @name Test Download With Session A File that does not exist
///-----------------------------------

/**
 * This test try to download a file that does not exist using NSURLSession
 * If the file is not downloaded, the test is ok
 *
 */
- (void) testDownloadWithSessionAFileThatDoesNotExist {
    
    //Create Tests/Test Download Folder
    NSString *downloadPath = [NSString stringWithFormat:@"%@/Test Download", k_path_test_folder];
    [self createFolderWithName:downloadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create Folder in File Sytem to test
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents folder
    //Documents/Test Download/
    NSString *localPath = documentsDirectory;
    
    //Make the path if not exists
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:localPath])
        [[NSFileManager defaultManager] createDirectoryAtPath:localPath withIntermediateDirectories:NO attributes:nil error:&error];
    
    //Documents/Test Download/image.png
    localPath = [localPath stringByAppendingString:@"/image.jpeg"];
    
    //Path of server file file
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Download/Test.jpeg", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionDownloadTask *downloadTask = nil;
    
    downloadTask = [_sharedOCCommunication downloadFileSession:serverUrl toDestiny:localPath defaultPriority:YES onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSURL *filePath) {
        
        XCTFail(@"Download file ok, not possible");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error) {
        
        NSLog(@"Error downloading a file - Error");
        //Delete the file
        NSError *theError = nil;
        [[NSFileManager defaultManager] removeItemAtPath:localPath error:&theError];
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test to upload a file that does not exist
///-----------------------------------

/**
 * This test try to upload that does not exist on the filesystem
 * This test is passed if we detect that the file does not exist
 *
 */
- (void) testUploadAFileThatDoesNotExist {
    
    //Create Tests/Test Upload
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Upload", k_path_test_folder];
    [self createFolderWithName:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Create Folder in File Sytem to test
    NSString *localPath = [NSString stringWithFormat:@"%@/Name of the file that does not exist.png", [[NSBundle mainBundle] resourcePath]];
    
    //Path of server file file
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Upload/Name of the file that does not exist.png", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        
        XCTFail(@"Error We upload a file that does not exist");
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
        XCTFail(@"Error. File do not uploaded");
        dispatch_semaphore_signal(semaphore);
        
    } failureBeforeRequest:^(NSError *error) {
        NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test to upload a file with Forbbiden Characters
///-----------------------------------

/**
 * This test try to uplad with special characters in destiny name
 */
- (void) testUploadAFileWithSpecialCharacters {
    
    //Create Tests/Test Upload
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Upload", k_path_test_folder];
    [self createFolderWithName:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Upload test file
    NSString *localPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"video" ofType:@"MOV"];
    
    //Path of server file file (Special character added in file name)
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Upload/video@.mov", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        NSLog(@"File Uploaded with Special Characters");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        XCTFail(@"Error. File do not uploaded");
        dispatch_semaphore_signal(semaphore);
    } failureBeforeRequest:^(NSError *error) {
        XCTFail(@"Error File does not exist");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test to upload with session
///-----------------------------------

/**
 * This test try to uplad a file using NSURLSession
 *
 */
- (void) testUploadFileWithSession {
    
    //Create Tests/Test Upload
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Upload", k_path_test_folder];
    [self createFolderWithName:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Upload test file
    NSString *localPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    
    //Path of server file file
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Upload/CompanyLogo.png", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        
        NSLog(@"File Uploaded");
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
        XCTFail(@"Error. File do not uploaded");
        dispatch_semaphore_signal(semaphore);
        
    } failureBeforeRequest:^(NSError *error) {
        NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

//-----------------------------------
/// @name Test to upload with session and special characters
///-----------------------------------

/**
 * This test try to uplad a file using NSURLSession
 *
 */
- (void) testUploadFileWithSessionAndSpecialCharacters {
    
    //Create Tests/Test Upload
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Upload", k_path_test_folder];
    [self createFolderWithName:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Upload test file
    NSString *localPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"video" ofType:@"MOV"];
    
    //Path of server file file (Special character added in file name)
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Upload/video@.mov", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        
        NSLog(@"File Uploaded");
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
        XCTFail(@"Error. File do not uploaded");
        dispatch_semaphore_signal(semaphore);
        
    } failureBeforeRequest:^(NSError *error) {
        NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test to upload with session file that does not exists
///-----------------------------------

/**
 * This test try to uplad a file using NSURLSession
 *
 */
- (void) testUploadWithSessionAFileThatDoesNotExist {
    
    //Create Tests/Test Upload
    NSString *uploadPath = [NSString stringWithFormat:@"%@/Test Upload", k_path_test_folder];
    [self createFolderWithName:uploadPath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //Upload test file
    NSString *localPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"videoA" ofType:@"MOV"];
    
    //Path of server file file (Special character added in file name)
    NSString *serverUrl = [NSString stringWithFormat:@"%@%@/Test Upload/video@.mov", k_webdav_base_url, k_path_test_folder];
    serverUrl = [serverUrl stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURLSessionUploadTask *uploadTask = nil;
    
    uploadTask = [_sharedOCCommunication uploadFileSession:localPath toDestiny:serverUrl onCommunication:_sharedOCCommunication progress:^(NSProgress *progress) {
        NSLog(@"File: %lld bytes", progress.completedUnitCount);
    } successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        
        XCTFail(@"Error We upload a file that does not exist");
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSString *redirectedServer, NSError *error) {
        
         NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
        
    } failureBeforeRequest:^(NSError *error) {
        NSLog(@"File that do not exist does not upload");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test the share a folder
///-----------------------------------

/**
 * This test try to share a folder
 */

- (void) testShareAFolder {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication shareFileOrFolderByServer:k_base_url andFileOrFolderPath:[NSString stringWithFormat:@"/%@", k_path_test_folder] onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *listOfShared, NSString *redirectedServer) {
        NSLog(@"Folder shared");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error sharing folder");
        dispatch_semaphore_signal(semaphore);
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test read shares items
///-----------------------------------

/**
 * This test try to check if a shared folder is shared and obtain his information
 */
- (void) testReadShared {
    
    //1. create the folder and share it
    [self testShareAFolder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //2. Check if the folder is shared
    [_sharedOCCommunication readSharedByServer:k_base_url onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        BOOL isFolderShared = NO;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]) {
                isFolderShared = YES;
            }
        }
        
        if (!isFolderShared) {
            XCTFail(@"Folder not shared");
            dispatch_semaphore_signal(semaphore);
        }
        
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test unshare items
///-----------------------------------

/**
 * This test try unshare a item
 */
- (void) testUnShareAFolder {
    
    //1. create the folder and share it
    [self testShareAFolder];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //2. read the folder to obtain the info of OCSharedDto
    [_sharedOCCommunication readSharedByServer:k_base_url onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        OCSharedDto *shared;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]) {
                shared = current;
            }
        }
        
        if (shared) {
            
            //3. Unshare the folder
            [_sharedOCCommunication unShareFileOrFolderByServer:k_base_url andIdRemoteShared:shared.idRemoteShared onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
                NSLog(@"File unshared");
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
                XCTFail(@"Error unsharing folder");
                dispatch_semaphore_signal(semaphore);
            }];
            
            
            
        } else {
            XCTFail(@"Folder not shared on testUnShareAFolder");
            dispatch_semaphore_signal(semaphore);
        }
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares on testUnShareAFolder");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}


///-----------------------------------
/// @name Test read capabilities
///-----------------------------------

/**
 * This test try to check if a shared folder is shared and obtain his information
 */
- (void) testGetCapabilitiesOfServer {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication getCapabilitiesOfServer:k_base_url onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, OCCapabilities *capabilities, NSString *redirectedServer) {
        NSLog(@"Get capabilities ok");
        XCTAssertNotNil(capabilities,  @"Error get capabilites of server");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error get capabilites of server");
        dispatch_semaphore_signal(semaphore);
    }];
     
     // Run loop
     while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
     [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                              beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}


///-----------------------------------
/// @name Test read capabilities
///-----------------------------------

/**
 * This test check get capabilities
 */
- (void) testShareLinkWithPassword {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication shareFileOrFolderByServer:k_base_url andFileOrFolderPath:[NSString stringWithFormat:@"/%@", k_path_test_folder] andPassword:@"testing" onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *shareLink, NSString *redirectedServer) {
        NSLog(@"Folder shared by link with password");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error sharing folder by link with password");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test share link with expiration date and password
///-----------------------------------

/**
 * This test check the creation of a link with expiration date
 */
- (void) testShareLinkWithExpirationDateAndPassword {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //1. Share a folder
    [self testShareAFolder];
    
    //2. Read the shared
    [_sharedOCCommunication readSharedByServer:k_base_url onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        BOOL isFolderShared = NO;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]) {
                isFolderShared = YES;
                
                NSDateFormatter *dateFormatter = [NSDateFormatter new];
                [dateFormatter setDateFormat:@"YYYY-MM-dd"];
                NSDate *tomorrow = [NSDate dateWithTimeInterval:(24*60*60) sinceDate:[NSDate date]];
                NSString *foarmatedDate = [dateFormatter stringFromDate:tomorrow];
                
                //3. Update the share with password and expiration date
                [_sharedOCCommunication updateShare:current.idRemoteShared ofServerPath:k_base_url withPasswordProtect:@"testing" andExpirationTime:foarmatedDate andPermissions:k_read_share_permission onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
                    
                    NSLog(@"Updated shared by link with expiration date and password");
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    XCTFail(@"Error updating shared by link with expiration date and password");
                    dispatch_semaphore_signal(semaphore);
                    
                }];
            }
        }
        
        if (!isFolderShared) {
            XCTFail(@"Folder not shared");
            dispatch_semaphore_signal(semaphore);
        }
        
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}



///-----------------------------------
/// @name Tests search users and groups
///-----------------------------------

/**
 * This test search for first 30 users or groups on server that match the pattern "aa"
 */
- (void) testSearchUsersAndGroups {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication searchUsersAndGroupsWith:@"aa" forPage:1 with:30 ofServer:k_base_url onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        NSLog(@"Search users and groups");
        XCTAssertNotNil(itemList,  @"Error search users and groups");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error get capabilites of server");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

/**
 * This test search for first 30 users or groups with special characters on server that match the pattern "user@"
 */
- (void) testSearchUsersAndGroupsWithSpecialCharacters {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication searchUsersAndGroupsWith:@"user@" forPage:1 with:30 ofServer:k_base_url onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *itemList, NSString *redirectedServer) {
        NSLog(@"Search users and groups");
        XCTAssertNotNil(itemList,  @"Error search users and groups");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error get capabilites of server");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}



///-----------------------------------
/// @name Test share with user with special character
///-----------------------------------

/**
 * This test share with a userToShare the folder pathTestFolder
 */
- (void) testShareWithUser {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication shareWith:k_user_to_share shareeType:shareTypeUser inServer:k_base_url andFileOrFolderPath:[NSString stringWithFormat:@"/%@", k_path_test_folder] andPermissions:k_read_share_permission onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        NSLog(@"Share with user");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error share with user");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}


///-----------------------------------
/// @name Test share with group with special character
///-----------------------------------

/**
 * This test share with groupToShare the folder pathTestFolder
 */
- (void) testShareWithGroup {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication shareWith:k_group_to_share shareeType:shareTypeGroup inServer:k_base_url andFileOrFolderPath:[NSString stringWithFormat:@"/%@", k_path_test_folder] andPermissions:k_read_share_permission onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        NSLog(@"Share with group");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error share with group");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test unshare with user with special character
///-----------------------------------

/**
 * This test unShare with user the folder pathTestFolder
 */
- (void) testUnShareWithUser {
    
    //1. create the folder and share it with user
    [self testShareWithUser];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //2. read the folder to obtain the info of OCSharedDto
    [_sharedOCCommunication readSharedByServer:k_base_url
                               onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
                                   
        OCSharedDto *shared;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]
                 && [current.shareWith isEqualToString:k_user_to_share]) {
                shared = current;
            }
        }
        
        if (shared) {
            
            //3. Unshare the folder
            [_sharedOCCommunication unShareFileOrFolderByServer:k_base_url andIdRemoteShared:shared.idRemoteShared onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
                NSLog(@"File unshared with user");
                dispatch_semaphore_signal(semaphore);
                
            } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
                XCTFail(@"Error unsharing folder with user");
                dispatch_semaphore_signal(semaphore);
            }];
            
            
            
        } else {
            XCTFail(@"Folder not shared on testUnShareWithUser");
            dispatch_semaphore_signal(semaphore);
        }
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares on testUnShareWithUser");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];}

///-----------------------------------
/// @name Test is share by server
///-----------------------------------

/**
 * This test check if a shared file is shared
 */
- (void) testIsShareByServer {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //1. Share a folder
    [self testShareAFolder];
    
    //2. Read the shared
    [_sharedOCCommunication readSharedByServer:k_base_url onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        BOOL isFolderShared = NO;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]) {
                isFolderShared = YES;
               
                
                //3. Check if the share folder is shared by the id
                [_sharedOCCommunication isShareFileOrFolderByServer:k_base_url andIdRemoteShared:current.idRemoteShared onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer, BOOL isShared, id shareDto) {
                    
                    NSLog(@"File is shared");
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    XCTFail(@"Error checking if a share is shared by id share");
                    dispatch_semaphore_signal(semaphore);
                    
                }];
            }
        }
        
        if (!isFolderShared) {
            XCTFail(@"Folder not shared before check");
            dispatch_semaphore_signal(semaphore);
        }
        
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test unshare file or folder
///-----------------------------------

/**
 * This test check if we can unshare a file or folder
 */
- (void) testUnShareByServer {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    //1. Share a folder
    [self testShareAFolder];
    
    //2. Read the shared
    [_sharedOCCommunication readSharedByServer:k_base_url onCommunication: _sharedOCCommunication successRequest:^(NSURLResponse *response, NSArray *listOfShared, NSString *redirectedServer) {
        
        BOOL isFolderShared = NO;
        
        for (OCSharedDto *current in listOfShared) {
            if ([current.path isEqualToString:[NSString stringWithFormat:@"/%@/", k_path_test_folder]]) {
                isFolderShared = YES;
                
                //3. Unshare the share folder by the id
                [_sharedOCCommunication unShareFileOrFolderByServer:k_base_url andIdRemoteShared:current.idRemoteShared onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
                    
                    NSLog(@"Share unshared correctly");
                    dispatch_semaphore_signal(semaphore);
                    
                } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
                    
                    XCTFail(@"Error unsharing file by id share");
                    dispatch_semaphore_signal(semaphore);
                    
                }];
                
            }
        }
        
        if (!isFolderShared) {
            XCTFail(@"Folder not shared before check");
            dispatch_semaphore_signal(semaphore);
        }
        
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading shares");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name testGetFeaturesSupportedByServer
///-----------------------------------

/**
 * This test check if we can get all the features supported by the server
 */
- (void) testGetFeaturesSupportedByServer {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication getFeaturesSupportedByServer:k_base_url onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, BOOL hasShareSupport, BOOL hasShareeSupport, BOOL hasCookiesSupport, BOOL hasForbiddenCharactersSupport, BOOL hasCapabilitiesSupport, BOOL hasFedSharesOptionShareSupport, NSString *redirectedServer) {
        
        NSLog(@"Server features correctly read");
        NSLog(@"hasShareSupport: %d", hasShareSupport);
        NSLog(@"hasShareeSupport: %d", hasShareeSupport);
        NSLog(@"hasCookiesSupport: %d", hasCookiesSupport);
        NSLog(@"hasForbiddenCharactersSupport: %d", hasForbiddenCharactersSupport);
        NSLog(@"hasCapabilitiesSupport: %d", hasCapabilitiesSupport);
        NSLog(@"hasFedSharesOptionShareSupport: %d", hasFedSharesOptionShareSupport);
        
        dispatch_semaphore_signal(semaphore);
        
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        
        XCTFail(@"Error reading server features");
        dispatch_semaphore_signal(semaphore);
        
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

///-----------------------------------
/// @name Test share with remote user federated sharing
///-----------------------------------

/**
 * This test share with a userToShare the folder pathTestFolder
 */
- (void) testShareWithRemoteUser {
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication shareWith:k_remote_user_to_share shareeType:shareTypeRemote inServer:k_base_url andFileOrFolderPath:[NSString stringWithFormat:@"/%@", k_path_test_folder] andPermissions:k_max_folder_share_permission onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSString *redirectedServer) {
        NSLog(@"Share with remote user");
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error share with remote user");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
}

///-----------------------------------
/// @name Test to get a remote thumbnail
///-----------------------------------

/**
 * This test try get a thumbnail of an image using the Thumbnail API
 *
 */
- (void) testGetRemoteThumbnail {
    
    
    //Create Folder A for the Test
    NSString *testPath = [NSString stringWithFormat:@"%@/Folder A", k_path_test_folder];
    [self createFolderWithName:testPath];
    
    //Upload file /Tests/Folder A/test.jpeg
    NSString *bundlePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"test" ofType:@"jpeg"];
    NSString *remotePath = [NSString stringWithFormat:@"%@/Folder A/Test.jpg", k_path_test_folder];
    [self uploadFilePath:bundlePath inRemotePath:remotePath];
    
    //We create a semaphore to wait until we recive the responses from Async calls
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [_sharedOCCommunication getRemoteThumbnailByServer:k_base_url ofFilePath:remotePath withWidth:64 andHeight:64 onCommunication:_sharedOCCommunication successRequest:^(NSURLResponse *response, NSData *thumbnail, NSString *redirectedServer) {
        if ([UIImage imageWithData:thumbnail]) {
            NSLog(@"Thumbnail getted");
        } else {
            XCTFail(@"Thumbnail getted but it is not an image");
        }
        dispatch_semaphore_signal(semaphore);
    } failureRequest:^(NSURLResponse *response, NSError *error, NSString *redirectedServer) {
        XCTFail(@"Error getting thumbnail");
        dispatch_semaphore_signal(semaphore);
    }];
    
    // Run loop
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:k_timeout_webdav]];
    
}

@end

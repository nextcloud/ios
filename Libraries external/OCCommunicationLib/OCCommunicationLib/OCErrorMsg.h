//
//  OCErrorMsg.h
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


#define kOCErrorServerUnauthorized 401
//In the server we received a 403 also when the server is enforce to set a password.
#define kOCErrorServerForbidden 403
#define kOCErrorServerPathNotFound 404
#define kOCErrorServerMethodNotPermitted 405
#define kOCErrorProxyAuth 407
#define kOCErrorServerTimeout 408
#define kOCErrorServerInternalError 500

#define kOCErrorSharedAPIWrong 400
#define kOCSharedAPISuccessful 100
#define kOCShareeAPISuccessful 200

#define kOCNotificationAPINoContent  204
#define kOCNotificationAPISuccessful 200

#define kOCUserProfileAPISuccessful 100

typedef enum {
    OCServerErrorForbiddenCharacters = 101,
} OCServerErrorEnum;

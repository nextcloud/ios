//
//  OCConstants.h
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

#define k_redirected_code_1 301
#define k_redirected_code_2 302
#define k_redirected_code_3 307

//The result of the sum of those values means the permissions that have a share file
//permissions - (int) 1 = read; 2 = update; 4 = create; 8 = delete; 16 = share; 31 = all (default: 31, for public shares: 1)
#define k_read_share_permission 1
#define k_update_share_permission 2
#define k_create_share_permission 4
#define k_delete_share_permission 8
#define k_share_share_permission 16

#define k_min_file_share_permission 1
#define k_max_file_share_permission 19
#define k_min_folder_share_permission 1
#define k_max_folder_share_permission 31
#define k_default_file_remote_share_permission_no_support_share_option 3
#define k_default_folder_remote_share_permission_no_support_share_option 15

#define k_max_redirections_allow 5

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]
### [2.20.3] - 2018-xx-xx
- See https://github.com/nextcloud/ios/milestone/24

## [2.20.2] - 2018-02-18
### Changed
- No information available

## [2.20.1] - 2018-02-15
### Changed
- See https://github.com/nextcloud/ios/milestone/23

## [2.20.0] - 2018-02-09
### Changed
- See https://github.com/nextcloud/ios/milestone/22

## [2.19.3] - 2018-02-06
### Changed
- See https://github.com/nextcloud/ios/milestone/21

## [2.19.2] - 2018-02-03
### Fixed
- Icons and labels overlap on iPad Pro. See [Details](https://github.com/nextcloud/ios/issues/476)
- Not showing correct data usage. See [Details](https://github.com/nextcloud/ios/issues/451)
- Negative file size. See [Details](https://github.com/nextcloud/ios/issues/448)

### Changed
- Replace icon for shared folders. See See [Details](https://github.com/nextcloud/ios/issues/458)
- See https://github.com/nextcloud/ios/milestone/20

## [2.19.1] - 2017-12-22
### Fixed
- Bugfix manual Upload

## [2.19.0] - 2017-12-21
### Added
- End-to-end encryption is now supported
- iPad : support for multitask Slide Over

### Fixed
- Folders on top #408
- Theming 2.0 now works with light colors (only for Nextcloud 13) #427
- Search bar is showing again like expected #413
- Different „Blue“-tone in Status and search bar on iPhone X #418
- Fix Upload Video
- Fix UI for iOS 11 and iPhone X

### Changed
- UI for setting up multiple accounts has been improved #420
- Settings : “Most Compatible” option move from “Auto Upload” to “Advanced”

## [2.18.2] - 2017-11-07
### Fixed
- upload and save photo / video on camera roll

## [2.18.1] - 2017-11-06
### Fixed
- iPhone X UI
- Crash when save selected images/videos without permission
- Microsoft Excel sheets with multiple "pages" now works

## [2.18.0] - 2017-10-27
### Added
- More compatibility with iOS 11 and with iPhone X
- Added on AutoUpload "More compatibility" for save image in JPEG instead of HEIF

### Fixed
- File Provider: Crashes #382
- File Provider: Saving File O365 not working and still not downloading file each time. #397

### Changed
- Removed Crypto Cloud System, for decrypt your files download the App : Crypto Cloud for Nextcloud (it's free)
- Removed grid view on Photo/Video reader
- Removed cache on Document Provider

## [2.17.8] - 2017-09-08
### Fixed
- Login with LDAP is now working again / App show the login page all the time #365
- Dowload File Connection Failed #364

## [2.17.7] - 2017-09-04
### Added
- Added slovakian language (SK)
- Added new Activity Client for verbose high : https://github.com/nextcloud/ios/commit/abaeae6d44ef0945cd1d013339daf4bb0e01ecd0

### Fixed
- Bug fix https://github.com/nextcloud/ios/commit/24d56394cc0655f5d3ae89791f7be54a43997a95 

### Changed
- Added 2 pt. dimension font on Notification view : https://github.com/nextcloud/ios/commit/909ab9e3637d70bc594154325a346adde455f5be

## [2.17.6] - 2017-08-31
### Added
- Hide Hidden Files #102
- Now is possible create/modify file txt
- Now is possible the login with your email
- Added the auto-detect for non-UTF-8 text on view txt file

### Fixed
- App crashes instantly after start up #314
- 401 responses are ignored #334
- Fix used/stored user ID (authentication manager with LDAP) #331
- Upload menu is at wrong position on iPad at landscape mode #155
- Theming issue
- Fixed share information (share/mont with you)
- Fixed Notification view (now with variable high)
- Fixed tab More
- Fixed re-send images/videos modify (auto upload), now send only new images/videos
- Correct several minor bug and improved stability

### Changed
- Office 365 and NextCloud IOS app not saving modification to document #311
- Improved the upload (now no limit number for select images/videos for upload)
- Improved the download for entire directory and favorites directory
- Improved the menu (+) now detect the actual folder on Favorite tab and Photo tab

## [2.17.5] - 2017-07-28
### Added
- Feature: Set your own name of filename for uploads #297

### Fixed
- Fixes for automatic upload
- Fix: "Photos" folder created at Photo upload while should not #303

### Changed
- See https://github.com/nextcloud/ios/releases/tag/2.17.5

## [2.17.4] - 2017-07-17
### Added
- Improvements on Auto Upload
- Show "Shares" list in "More" tab
- Use gestures on Files tab to reach options quickly
- Improved badges for favorites and offline available

### Fixed
- Fix: Battery bar visible as only icon of system bar during first use
- Fix: Favorite folders are not being downloaded

### Changed 
- Improvements on UI (many small things)
- Improvements on performance and stability
- See https://github.com/nextcloud/ios/releases/tag/2.17.4

## [2.17.3] - 2017-05-23
### Changed 
- See https://github.com/nextcloud/ios/milestone/7?closed=1

## [2.17.2] - 2017-05-05
### Changed 
- See https://github.com/nextcloud/ios/milestone/6?closed=1

## [2.17.1] - 2017-04-26
### Changed 
- See https://github.com/nextcloud/ios/milestone/5?closed=1

## [2.17] - 2017-04-21
### Changed 
- See https://github.com/nextcloud/ios/milestone/6?closed=1
### Added
- Improvement: Use milestone information

## [2.16] - 2017-01-06
### Changed 
- Build: 00012

### Added
- Improvement: Upload all camera photos/videos. (Marino Faggiana)

## [2.15] - 2016-12-12
### Changed 
- Build: 00301

### Added
- Improvement system for managed Synchronized. (Marino Faggiana)
- Improvement Control Center. (Marino Faggiana)
- Improvement system I/O for upload/download file, thumbnails and command to cloud. (Marino Faggiana)
- Improvement Automatic upload and full upload photos/videos. (Marino Faggiana)
- Remove limit to manual  upload. (Marino Faggiana)

### Fixed
- Bugfix detect geolocation image. (Marino Faggiana)

## [2.14] - 2016-11-01
### Changed 
- Build: 00015

### Added
- Control if file exists in 'manual' upload. (Marino Faggiana)
- Add main-menu item : Folders on top.  (Marino Faggiana)

### Fixed
- Bugfix detect geolocation image. (Marino Faggiana)
- Improved (create new class) Synchronization folders. (Marino Faggiana)
- Improved 'Upload all camera photos/videos' bugfix if error block all, automatic default overwrite file if exists. (marino Faggiana)
- Detect Wi-Fi on automatic upload, problem database context. (Marino Faggiana)
- View on Control Center. (Marino Faggiana)
- Compatibility for iOS10

#Change Log

## [v2.1](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/2.1) (2017/09/21)
### Updated
- Update project to xcode9 and swift4 (#79)

### Fixed
- Cleanup (#77)

Special thanks!!  **wesbillman** , **russellbstephens**


## [v2.0.1](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/2.0.1) (2016/09/19)
Minor bug fix
### Fixed
- Fix generate as Data issue using `PDFGenerator.generated(by:)` #54


## [v2.0.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/2.0.0) (2016/09/15)
Major update :point_up::point_up:
### Improvement
- Support Swift3.0


## [v1.4.2](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.4.0) (2016/09/08)
### Fixed
- Fix minor bugs #40

## [v1.4.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.4.0) (2016/07/23)
### Added
- FilePathConvertible : `outputPath` is allowed both `String` and `NSURL`.  #38
- CHANGELOG.md
- codecov #37

### Updated
- Add more UnitTest : codecov percentage increase to 92%. #39

## Swift3.0 support (beta)
- compatible to Swift 3.0 #29 #31 #32

## [v1.3.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.3.0) (2016/07/12)
### Implemented
- Password Protection #34


## [v1.2.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.2.0) (2016/06/22)
### Implemented
- DPI suppoert #27

## [v1.1.4](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.1.4) (2016/06/22)
### Updated
- Update for Xcode7.3(swift2.2) #21

## 1.1.3~1.1.1
### Fixed
- Fix minor bugs #18, #13

## [v1.1.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.1.0) (2016/02/20)
### Added
- support Binary,ImageRef render. #11

## [v1.0.0](https://github.com/sgr-ksmt/PDFGenerator/releases/tag/1.0.0) (2016/02/11)
### Stable Version Release!!
- Support multiple pages.
- Also generate PDF from imagePath that can load image with UIImage(contentsOfFile:)
- Type safe.
- Good memory management.
- Generate PDF from mixed-pages.
- If view is UIScrollView , drawn whole content.
- Outputs as NSData or writes to Disk(in given file path) directly.
- Corresponding to Error-Handling. Strange PDF has never been generated!!

## 0.2.0 ~ 0.1.0
- beta release
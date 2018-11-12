Pod::Spec.new do |s|
  s.name                = "KTVCocoaHTTPServer"
  s.version             = "1.0.0"
  s.summary             = "CocoaHTTPServer for KTV."
  s.homepage            = "https://github.com/ChangbaDevs/KTVCocoaHTTPServer"
  s.license             = { :type => "MIT", :file => "LICENSE" }
  s.author              = { "Single" => "libobjc@gmail.com" }
  s.social_media_url    = "https://weibo.com/3118550737"
  s.platform            = :ios, "8.0"
  s.source              = { :git => "https://github.com/ChangbaDevs/KTVCocoaHTTPServer.git", :tag => "#{s.version}" }
  s.source_files        = "KTVCocoaHTTPServer", "KTVCocoaHTTPServer/**/*.{h,m}"
  s.public_header_files = "KTVCocoaHTTPServer/**/*.h"
  s.frameworks          = "Foundation"
  s.requires_arc        = true
  s.dependency 'CocoaAsyncSocket'
end

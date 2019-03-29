Pod::Spec.new do |s|
  s.name                = "KTVHTTPCache"
  s.version             = "1.1.7"
  s.summary             = "A media cache framework from Changba iOS Team."
  s.homepage            = "https://github.com/ChangbaDevs/KTVHTTPCache"
  s.license             = { :type => "MIT", :file => "LICENSE" }
  s.author              = { "Single" => "libobjc@gmail.com" }
  s.social_media_url    = "https://weibo.com/3118550737"
  s.platform            = :ios, "8.0"
  s.source              = { :git => "https://github.com/ChangbaDevs/KTVHTTPCache.git", :tag => "#{s.version}" }
  s.source_files        = "KTVHTTPCache", "KTVHTTPCache/**/*.{h,m}"
  s.public_header_files = "KTVHTTPCache/**/*.h"
  s.frameworks          = "UIKit", "Foundation"
  s.requires_arc        = true
  s.dependency 'KTVCocoaHTTPServer'
end

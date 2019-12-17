# Run `pod lib lint Sheeeeeeeeet.podspec' to ensure this is a valid spec.

Pod::Spec.new do |s|
  s.name             = 'Sheeeeeeeeet'
  s.version          = '3.0.9'
  s.swift_versions   = ['5.1']
  s.summary          = 'Sheeeeeeeeet is a Swift library for custom iOS action sheets.'

  s.description      = <<-DESC
Sheeeeeeeeet is a Swift library for adding custom action sheets to your iOS apps.
It comes with many built-in item action sheet item types, and can be extended by
custom types are more specific to your app or domain.
                       DESC

  s.homepage         = 'https://github.com/danielsaidi/Sheeeeeeeeet'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Daniel Saidi' => 'daniel.saidi@gmail.com' }
  s.source           = { :git => 'https://github.com/danielsaidi/Sheeeeeeeeet.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/danielsaidi'

  s.swift_version = '5.1'
  s.ios.deployment_target = '9.0'
  s.source_files = 'Sources/Sheeeeeeeeet/**/*.swift'
end

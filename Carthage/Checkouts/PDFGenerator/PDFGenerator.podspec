Pod::Spec.new do |s|
  s.name             = "PDFGenerator"
  s.version          = "2.1.1"
  s.summary          = "A simple PDF generator."
  s.homepage         = "https://github.com/sgr-ksmt/PDFGenerator"
  # s.screenshots     = ""
  s.license          = 'MIT'
  s.author           = { "Suguru Kishimoto" => "melodydance.k.s@gmail.com" }
  s.source           = { :git => "https://github.com/sgr-ksmt/PDFGenerator.git", :tag => s.version.to_s }
  s.platform         = :ios, '8.0'
  s.requires_arc     = true
  s.source_files     = "PDFGenerator/**/*.swift"
  s.frameworks   = 'WebKit'
end

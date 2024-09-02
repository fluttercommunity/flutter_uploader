#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_uploader'
  s.version          = '1.2.0'
  s.summary          = 'background upload plugin for flutter'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.dependency 'Alamofire', '5.9.1'
  s.ios.deployment_target = '14.0'
  s.swift_version = '5.2'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end


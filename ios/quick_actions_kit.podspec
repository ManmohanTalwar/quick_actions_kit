Pod::Spec.new do |s|
  s.name             = 'quick_actions_kit'
  s.version          = '0.1.0'
  s.summary          = 'Native home-screen quick actions for DartNative.'
  s.description      = 'Dynamic shortcuts and cold/warm activation delivery through FFI.'
  s.homepage         = 'https://github.com/ManmohanTalwar/quick_actions_kit'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = 'quick_actions_kit contributors'
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*.swift'
  s.swift_version    = '5.9'
  s.platform = :ios, '15.0'
  s.frameworks       = 'Foundation', 'UIKit'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end

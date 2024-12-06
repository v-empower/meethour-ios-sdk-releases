Pod::Spec.new do |s|
  s.name             = 'MeetHourSDK'
  s.version          = '4.5.0'
  s.summary          = 'Meet Hour iOS SDK'
  s.description      = 'Meet Hour is HD Quality video conference solution with End to End Encrypted and many other features such as lobby mode, Donor box & Click&Pledge Connect for fundraising, Video call recording, Youtube Live Stream etc. For more details visit www.meethour.io.'
  s.homepage         = 'https://github.com/v-empower/meethour-ios-sdk-releases'
  s.license          = 'Meet Hour, LLC'
  s.authors          = 'Meet Hour, LLC'
  s.source           = { :git => 'https://github.com/v-empower/meethour-ios-sdk-releases.git', :tag => s.version }

  s.platform         = :ios, '12.0'
  s.swift_version    = '5'

  s.vendored_frameworks = 'Frameworks/MeetHourSDK.xcframework', 'Frameworks/WebRTC.xcframework'
  s.vendored_frameworks = 'Frameworks/hermes.xcframework'
  s.dependency 'Giphy', '2.2.4'
  
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
end

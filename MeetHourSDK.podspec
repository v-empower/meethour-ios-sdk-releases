Pod::Spec.new do |s|
  s.name             = 'MeetHourSDK'
  s.version          = '5.0.31'
  s.summary          = 'Meet Hour iOS SDK'
  s.description      = 'Meet Hour is HD Quality video conference solution with End to End Encrypted and many other features such as lobby mode, Donor box & Click&Pledge Connect for fundraising, Video call recording, Youtube Live Stream etc. For more details visit www.meethour.io.'
  s.homepage         = 'https://github.com/v-empower/meethour-ios-sdk-releases'
  s.license          = 'Meet Hour, LLC'
  s.authors          = 'Meet Hour, LLC'
  s.source           = { :git => 'https://github.com/v-empower/meethour-ios-sdk-releases.git', :tag => s.version }

  s.platform         = :ios, '13.1'
  s.swift_version    = '5'

  s.frameworks = [ 'JavaScriptCore', 'AVFoundation', 'UIKit', 'Foundation']
  s.default_subspecs = 'Native'

  s.subspec 'Native' do |ss|
    ss.vendored_frameworks = 'Frameworks/MeetHourSDK.xcframework', 'Frameworks/MeetHourSDKModules.xcframework', 'Frameworks/WebRTC.xcframework', 'Frameworks/hermesvm.xcframework', 'Frameworks/React.xcframework', 'Frameworks/ReactNativeDependencies.xcframework'
    ss.dependency 'Giphy', '2.2.12'
  end

  s.subspec 'ReactNative' do |ss|
    ss.vendored_frameworks = 'Frameworks/MeetHourSDK.xcframework', 'Frameworks/WebRTC.xcframework'
    ss.dependency 'Giphy', '2.2.12'
  end

  # iOS screen sharing: the whole Broadcast Upload Extension. Add it to the
  # extension target only (not the app):
  #
  #   target 'MyBroadcastExtension' do
  #     pod 'MeetHourSDK/BroadcastExtension', 'VERSION'
  #   end
  #
  # No code is needed in the extension. In its Info.plist set
  # NSExtension > NSExtensionPrincipalClass = MHBroadcastSampleHandler and
  # RTCAppGroupIdentifier = the app's app group.
  s.subspec 'BroadcastExtension' do |ss|
    ss.source_files = 'BroadcastExtension/**/*.{h,m}'
    ss.public_header_files = 'BroadcastExtension/include/*.h'
    ss.frameworks = 'ReplayKit', 'CoreMedia', 'AudioToolbox'
  end
end
